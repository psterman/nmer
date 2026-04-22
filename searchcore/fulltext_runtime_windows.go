//go:build windows

package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"runtime"
	"strconv"
	"strings"
	"sync"
	"syscall"
	"time"
	"unicode/utf16"

	"golang.org/x/sys/windows"
)

const fullTextRuntimeConfigFile = "fulltext_settings.json"

type FullTextRuntimeConfig struct {
	AutoStart        bool   `json:"autoStart"`
	Workers          int    `json:"workers"`
	IndexDir         string `json:"indexDir"`
	IncludeLargeText bool   `json:"includeLargeText"`
	MaxFileSizeMB    int64  `json:"maxFileSizeMB"`
	InitialDelaySec  int64  `json:"initialDelaySec"`
	PauseMS          int64  `json:"pauseMS"`
	ScanSpeed        string `json:"scanSpeed"`
	ScanScheme       string `json:"scanScheme"`
	UseUSN           bool   `json:"useUSN"`
}

type fullTextRuntimeConfigPatch struct {
	AutoStart        *bool   `json:"autoStart"`
	Workers          *int    `json:"workers"`
	IndexDir         *string `json:"indexDir"`
	IncludeLargeText *bool   `json:"includeLargeText"`
	MaxFileSizeMB    *int64  `json:"maxFileSizeMB"`
	InitialDelaySec  *int64  `json:"initialDelaySec"`
	PauseMS          *int64  `json:"pauseMS"`
	ScanSpeed        *string `json:"scanSpeed"`
	ScanScheme       *string `json:"scanScheme"`
	UseUSN           *bool   `json:"useUSN"`
}

type fullTextControlRequest struct {
	Action string `json:"action"`
}

var (
	fullTextRuntimeMu             sync.RWMutex
	fullTextRuntimeLoaded         bool
	fullTextRuntimeBaseDir        string
	fullTextRuntimeConfigSnapshot FullTextRuntimeConfig
	fullTextStartSuppressed       bool
)

func InitFullTextRuntime(baseDir string) {
	ensureFullTextRuntime(baseDir)
}

func ShouldAutoStartIndexer(baseDir string) bool {
	ensureFullTextRuntime(baseDir)
	fullTextRuntimeMu.RLock()
	defer fullTextRuntimeMu.RUnlock()
	return fullTextRuntimeConfigSnapshot.AutoStart && !fullTextStartSuppressed
}

func ensureFullTextRuntime(baseDir string) {
	cleanBase := filepath.Clean(strings.TrimSpace(baseDir))
	if cleanBase == "" {
		return
	}

	fullTextRuntimeMu.Lock()
	defer fullTextRuntimeMu.Unlock()

	if fullTextRuntimeLoaded && strings.EqualFold(fullTextRuntimeBaseDir, cleanBase) {
		return
	}

	cfg := defaultFullTextRuntimeConfig(cleanBase)
	cfg = loadFullTextRuntimeConfigFromDisk(cleanBase, cfg)
	cfg = normalizeFullTextRuntimeConfig(cleanBase, cfg)

	fullTextRuntimeLoaded = true
	fullTextRuntimeBaseDir = cleanBase
	fullTextRuntimeConfigSnapshot = cfg
	fullTextStartSuppressed = !cfg.AutoStart

	applyFullTextRuntimeEnv(cfg)
}

func defaultFullTextRuntimeConfig(baseDir string) FullTextRuntimeConfig {
	idxDir, _ := resolveIndexDir(baseDir)
	useMFT := parseBoolEnv("SEARCHCENTER_FT_USE_MFT", true)
	useEverything := parseBoolEnv("SEARCHCENTER_FT_USE_EVERYTHING", false)
	return FullTextRuntimeConfig{
		AutoStart:        parseBoolEnv("SEARCHCENTER_FT_AUTOSTART", true),
		Workers:          resolveWorkerCount(),
		IndexDir:         idxDir,
		IncludeLargeText: parseBoolEnv("SEARCHCENTER_FT_INCLUDE_LARGE", false),
		MaxFileSizeMB:    parseInt64Env("SEARCHCENTER_FT_MAX_FILE_MB", 8),
		InitialDelaySec:  parseInt64Env("SEARCHCENTER_FT_INITIAL_DELAY_SEC", 1),
		PauseMS:          parseInt64Env("SEARCHCENTER_FT_PAUSE_MS", -1),
		ScanSpeed:        resolveScanSpeed(),
		ScanScheme:       scanSchemeFromFlags(useMFT, useEverything),
		UseUSN:           parseBoolEnv("SEARCHCENTER_FT_USE_USN", true),
	}
}

func normalizeFullTextRuntimeConfig(baseDir string, cfg FullTextRuntimeConfig) FullTextRuntimeConfig {
	maxWorkers := runtime.NumCPU() * 2
	if maxWorkers < 2 {
		maxWorkers = 2
	}
	if cfg.Workers < 1 {
		cfg.Workers = resolveWorkerCount()
	}
	if cfg.Workers > maxWorkers {
		cfg.Workers = maxWorkers
	}

	cfg.ScanSpeed = strings.ToLower(strings.TrimSpace(cfg.ScanSpeed))
	switch cfg.ScanSpeed {
	case "slow", "normal", "fast":
	default:
		cfg.ScanSpeed = "normal"
	}
	cfg.ScanScheme = normalizeScanScheme(cfg.ScanScheme)

	if cfg.MaxFileSizeMB <= 0 {
		cfg.MaxFileSizeMB = 8
	}
	if cfg.InitialDelaySec <= 0 {
		cfg.InitialDelaySec = 1
	}
	if cfg.PauseMS < -1 {
		cfg.PauseMS = -1
	}

	idx := strings.TrimSpace(cfg.IndexDir)
	if idx == "" {
		def, _ := resolveIndexDir(baseDir)
		idx = def
	}
	// 兼容旧版本：历史配置可能固定使用共享目录
	// LOCALAPPDATA\\SearchCenter\\bluge_index，容易与其他实例发生锁冲突。
	// 若检测到该旧路径，自动迁移到当前工作区的专属索引目录。
	if legacy := legacySharedIndexDir(); legacy != "" {
		if strings.EqualFold(normalizePathKey(idx), normalizePathKey(legacy)) {
			def, _ := resolveIndexDir(baseDir)
			idx = def
		}
	}
	if !filepath.IsAbs(idx) {
		idx = filepath.Join(baseDir, idx)
	}
	cfg.IndexDir = filepath.Clean(idx)

	return cfg
}

func legacySharedIndexDir() string {
	local := strings.TrimSpace(os.Getenv("LOCALAPPDATA"))
	if local == "" {
		local = strings.TrimSpace(os.Getenv("APPDATA"))
	}
	if local == "" {
		local = os.TempDir()
	}
	return filepath.Join(local, "SearchCenter", "bluge_index")
}

func normalizeScanScheme(s string) string {
	switch strings.ToLower(strings.TrimSpace(s)) {
	case "auto", "mft", "everything", "walk":
		return strings.ToLower(strings.TrimSpace(s))
	default:
		return "auto"
	}
}

func scanSchemeFromFlags(useMFT, useEverything bool) string {
	if useMFT && useEverything {
		return "auto"
	}
	if useMFT {
		return "mft"
	}
	if useEverything {
		return "everything"
	}
	return "walk"
}

func scanSchemeToFlags(scheme string) (useMFT bool, useEverything bool) {
	switch normalizeScanScheme(scheme) {
	case "mft":
		return true, false
	case "everything":
		return false, true
	case "walk":
		return false, false
	default:
		return true, true
	}
}

func loadFullTextRuntimeConfigFromDisk(baseDir string, def FullTextRuntimeConfig) FullTextRuntimeConfig {
	path := fullTextRuntimeConfigPath(baseDir)
	buf, err := os.ReadFile(path)
	if err != nil {
		return def
	}
	var patch fullTextRuntimeConfigPatch
	if err := json.Unmarshal(buf, &patch); err != nil {
		return def
	}
	cfg := def
	mergeFullTextRuntimePatch(baseDir, &cfg, patch)
	return cfg
}

func saveFullTextRuntimeConfig(baseDir string, cfg FullTextRuntimeConfig) error {
	path := fullTextRuntimeConfigPath(baseDir)
	if err := os.MkdirAll(filepath.Dir(path), 0o755); err != nil {
		return err
	}
	buf, err := json.MarshalIndent(cfg, "", "  ")
	if err != nil {
		return err
	}
	return os.WriteFile(path, buf, 0o644)
}

func fullTextRuntimeConfigPath(baseDir string) string {
	return filepath.Join(baseDir, "Data", fullTextRuntimeConfigFile)
}

func fullTextRuntimeConfig(baseDir string) FullTextRuntimeConfig {
	ensureFullTextRuntime(baseDir)
	fullTextRuntimeMu.RLock()
	defer fullTextRuntimeMu.RUnlock()
	return fullTextRuntimeConfigSnapshot
}

func fullTextBaseDir() string {
	fullTextRuntimeMu.RLock()
	defer fullTextRuntimeMu.RUnlock()
	return fullTextRuntimeBaseDir
}

func applyFullTextRuntimeEnv(cfg FullTextRuntimeConfig) {
	_ = os.Setenv("SEARCHCENTER_FT_WORKERS", strconv.Itoa(cfg.Workers))
	_ = os.Setenv("SEARCHCENTER_FT_INDEX_DIR", cfg.IndexDir)
	_ = os.Setenv("SEARCHCENTER_FT_INCLUDE_LARGE", strconv.FormatBool(cfg.IncludeLargeText))
	_ = os.Setenv("SEARCHCENTER_FT_MAX_FILE_MB", strconv.FormatInt(cfg.MaxFileSizeMB, 10))
	_ = os.Setenv("SEARCHCENTER_FT_SCAN_SPEED", cfg.ScanSpeed)
	useMFT, useEverything := scanSchemeToFlags(cfg.ScanScheme)
	_ = os.Setenv("SEARCHCENTER_FT_USE_MFT", strconv.FormatBool(useMFT))
	_ = os.Setenv("SEARCHCENTER_FT_USE_EVERYTHING", strconv.FormatBool(useEverything))
	_ = os.Setenv("SEARCHCENTER_FT_USE_USN", strconv.FormatBool(cfg.UseUSN))
	_ = os.Setenv("SEARCHCENTER_FT_INITIAL_DELAY_SEC", strconv.FormatInt(cfg.InitialDelaySec, 10))
	if cfg.PauseMS >= 0 {
		_ = os.Setenv("SEARCHCENTER_FT_PAUSE_MS", strconv.FormatInt(cfg.PauseMS, 10))
	} else {
		_ = os.Unsetenv("SEARCHCENTER_FT_PAUSE_MS")
	}
	_ = os.Setenv("SEARCHCENTER_FT_AUTOSTART", strconv.FormatBool(cfg.AutoStart))
}

func mergeFullTextRuntimePatch(baseDir string, cfg *FullTextRuntimeConfig, patch fullTextRuntimeConfigPatch) {
	if cfg == nil {
		return
	}
	if patch.AutoStart != nil {
		cfg.AutoStart = *patch.AutoStart
	}
	if patch.Workers != nil {
		cfg.Workers = *patch.Workers
	}
	if patch.IndexDir != nil {
		dir := strings.TrimSpace(*patch.IndexDir)
		if dir != "" && !filepath.IsAbs(dir) {
			dir = filepath.Join(baseDir, dir)
		}
		cfg.IndexDir = dir
	}
	if patch.IncludeLargeText != nil {
		cfg.IncludeLargeText = *patch.IncludeLargeText
	}
	if patch.MaxFileSizeMB != nil {
		cfg.MaxFileSizeMB = *patch.MaxFileSizeMB
	}
	if patch.InitialDelaySec != nil {
		cfg.InitialDelaySec = *patch.InitialDelaySec
	}
	if patch.PauseMS != nil {
		cfg.PauseMS = *patch.PauseMS
	}
	if patch.ScanSpeed != nil {
		cfg.ScanSpeed = strings.TrimSpace(*patch.ScanSpeed)
	}
	if patch.ScanScheme != nil {
		cfg.ScanScheme = strings.TrimSpace(*patch.ScanScheme)
	}
	if patch.UseUSN != nil {
		cfg.UseUSN = *patch.UseUSN
	}
	*cfg = normalizeFullTextRuntimeConfig(baseDir, *cfg)
}

func probeMFTOnce(drive byte) error {
	h, err := openNTFSVolumeHandle(drive)
	if err != nil {
		return err
	}
	defer windows.CloseHandle(h)

	inBuf := make([]byte, 24)
	outBuf := make([]byte, 1024*1024)
	var br uint32
	return windows.DeviceIoControl(h, fsctlEnumUsnData, &inBuf[0], uint32(len(inBuf)), &outBuf[0], uint32(len(outBuf)), &br, nil)
}

func probeWithTimeout(timeout time.Duration, fn func() error) error {
	if timeout <= 0 {
		return fn()
	}
	ch := make(chan error, 1)
	go func() {
		ch <- fn()
	}()
	select {
	case err := <-ch:
		return err
	case <-time.After(timeout):
		return fmt.Errorf("timeout after %s", timeout)
	}
}

func probeEverythingIPC(baseDir string) (bool, string) {
	if _, err := os.Stat(everythingDLLPath(baseDir)); err != nil {
		return false, "everything64.dll not found"
	}
	if findEverythingPID() == 0 && !tryStartEverything(baseDir) {
		return false, "Everything process is not running"
	}

	dll, err := syscall.LoadDLL(everythingDLLPath(baseDir))
	if err != nil {
		return false, "load everything64.dll failed: " + err.Error()
	}
	defer dll.Release()

	getMajor, err := dll.FindProc("Everything_GetMajorVersion")
	if err != nil {
		return false, "Everything_GetMajorVersion not found"
	}
	major, _, _ := getMajor.Call()
	if major == 0 {
		return false, "Everything IPC unavailable (permission mismatch or sdk disabled)"
	}
	return true, "ok"
}

func probeFullTextFeasibility(baseDir string) map[string]any {
	cfg := fullTextRuntimeConfig(baseDir)
	roots := fullTextRoots(baseDir)

	everythingOK, everythingReason := probeEverythingIPC(baseDir)
	rootChecks := make([]map[string]any, 0, len(roots))
	mftOKCount := 0
	usnOKCount := 0

	for _, root := range roots {
		item := map[string]any{
			"root":         root,
			"isVolumeRoot": isVolumeRootPath(root),
			"mftOk":        false,
			"mftReason":    "",
			"usnOk":        false,
			"usnReason":    "",
		}
		if !isVolumeRootPath(root) {
			item["mftReason"] = "root is not a drive root"
			item["usnReason"] = "root is not a drive root"
			rootChecks = append(rootChecks, item)
			continue
		}
		drive, derr := driveLetterFromRoot(root)
		if derr != nil {
			item["mftReason"] = derr.Error()
			item["usnReason"] = derr.Error()
			rootChecks = append(rootChecks, item)
			continue
		}
		if err := probeWithTimeout(2*time.Second, func() error { return probeMFTOnce(drive) }); err != nil {
			item["mftReason"] = err.Error()
		} else {
			item["mftOk"] = true
			item["mftReason"] = "ok"
			mftOKCount++
		}

		usnErr := probeWithTimeout(2*time.Second, func() error {
			h, err := openNTFSVolumeHandle(drive)
			if err != nil {
				return err
			}
			defer windows.CloseHandle(h)
			_, _, _, qerr := queryUSNJournalInfo(h)
			return qerr
		})
		if usnErr != nil {
			item["usnReason"] = usnErr.Error()
		} else {
			item["usnOk"] = true
			item["usnReason"] = "ok"
			usnOKCount++
		}
		rootChecks = append(rootChecks, item)
	}

	recommended := "walk"
	if len(roots) > 0 && mftOKCount == len(roots) {
		recommended = "mft"
	} else if everythingOK {
		recommended = "everything"
	}

	return map[string]any{
		"time":              time.Now().Format(time.RFC3339),
		"currentConfig":     cfg,
		"roots":             roots,
		"rootChecks":        rootChecks,
		"everythingOk":      everythingOK,
		"everythingReason":  everythingReason,
		"mftOkCount":        mftOKCount,
		"usnOkCount":        usnOKCount,
		"recommendedScheme": recommended,
	}
}

func isFullTextStartSuppressed() bool {
	fullTextRuntimeMu.RLock()
	defer fullTextRuntimeMu.RUnlock()
	return fullTextStartSuppressed
}

func setFullTextStartSuppressed(v bool) {
	fullTextRuntimeMu.Lock()
	fullTextStartSuppressed = v
	fullTextRuntimeMu.Unlock()
}

func isFullTextIndexerRunning() bool {
	fullTextGlobalMu.RLock()
	defer fullTextGlobalMu.RUnlock()
	return fullTextGlobal != nil
}

func (b *blugeIndexer) Stop() error {
	if b == nil {
		return nil
	}
	b.cancel()
	if b.watcher != nil {
		_ = b.watcher.Close()
	}
	if err := b.drainPendingBatches(); err != nil {
		log.Printf("[fulltext] drain pending batches: %v", err)
	}
	b.closeCachedReaderOnStop()
	var closeErr error
	if b.writer != nil {
		closeErr = b.writer.Close()
	}
	if b.meta != nil {
		if err := b.meta.Close(); closeErr == nil {
			closeErr = err
		}
	}
	b.mu.Lock()
	b.status.Running = false
	b.status.Ready = false
	b.status.ScanPhase = "idle"
	b.status.ProgressDetail = "索引已停止"
	b.status.EfficiencyText = "0 文件/秒"
	b.status.IndexingFile = ""
	b.status.PendingTasks = 0
	b.status.LastUpdatedRFC3339 = time.Now().Format(time.RFC3339)
	b.mu.Unlock()
	return closeErr
}

func StopIndexer() error {
	fullTextGlobalMu.Lock()
	idx := fullTextGlobal
	fullTextGlobal = nil
	fullTextGlobalMu.Unlock()
	if idx == nil {
		return nil
	}
	return idx.Stop()
}

func applyFullTextRuntimePatch(baseDir string, patch fullTextRuntimeConfigPatch) (FullTextRuntimeConfig, error) {
	cfg := fullTextRuntimeConfig(baseDir)
	mergeFullTextRuntimePatch(baseDir, &cfg, patch)

	fullTextRuntimeMu.Lock()
	fullTextRuntimeConfigSnapshot = cfg
	if patch.AutoStart != nil {
		fullTextStartSuppressed = !cfg.AutoStart
	}
	suppressed := fullTextStartSuppressed
	fullTextRuntimeMu.Unlock()

	if err := os.MkdirAll(cfg.IndexDir, 0o755); err != nil {
		return cfg, fmt.Errorf("create index dir failed: %w", err)
	}
	if err := saveFullTextRuntimeConfig(baseDir, cfg); err != nil {
		return cfg, err
	}
	applyFullTextRuntimeEnv(cfg)

	if isFullTextIndexerRunning() {
		_ = StopIndexer()
		if !suppressed {
			if err := StartIndexer(baseDir); err != nil {
				return cfg, err
			}
		}
	} else if !suppressed && patch.AutoStart != nil && *patch.AutoStart {
		if err := StartIndexer(baseDir); err != nil {
			return cfg, err
		}
	}

	return cfg, nil
}

func handleFullTextConfig(w http.ResponseWriter, r *http.Request) {
	baseDir := fullTextBaseDir()
	if baseDir == "" {
		http.Error(w, "base dir not initialized", http.StatusInternalServerError)
		return
	}
	ensureFullTextRuntime(baseDir)

	switch r.Method {
	case http.MethodGet:
		writeFullTextJSON(w, http.StatusOK, map[string]any{
			"config":   fullTextRuntimeConfig(baseDir),
			"status":   GetStatus(),
			"progress": GetProgressPayload(),
		})
	case http.MethodPost:
		var patch fullTextRuntimeConfigPatch
		if buf, err := io.ReadAll(r.Body); err != nil {
			http.Error(w, "invalid json body", http.StatusBadRequest)
			return
		} else if len(bytes.TrimSpace(buf)) > 0 {
			if err := decodeJSONRelaxed(buf, &patch); err != nil {
				var wrap struct {
					Payload json.RawMessage `json:"payload"`
				}
				if err2 := decodeJSONRelaxed(buf, &wrap); err2 != nil || len(bytes.TrimSpace(wrap.Payload)) == 0 {
					http.Error(w, "invalid json body", http.StatusBadRequest)
					return
				}
				if err3 := decodeJSONRelaxed(wrap.Payload, &patch); err3 != nil {
					http.Error(w, "invalid json body", http.StatusBadRequest)
					return
				}
			}
		}
		cfg, err := applyFullTextRuntimePatch(baseDir, patch)
		if err != nil {
			http.Error(w, err.Error(), http.StatusBadRequest)
			return
		}
		writeFullTextJSON(w, http.StatusOK, map[string]any{
			"ok":       true,
			"config":   cfg,
			"status":   GetStatus(),
			"progress": GetProgressPayload(),
		})
	default:
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
	}
}

func decodeJSONRelaxed(data []byte, out any) error {
	d := bytes.TrimSpace(data)
	if len(d) == 0 {
		return io.EOF
	}
	if len(d) >= 3 && d[0] == 0xEF && d[1] == 0xBB && d[2] == 0xBF {
		d = bytes.TrimSpace(d[3:])
	}
	if err := json.Unmarshal(d, out); err == nil {
		return nil
	}

	// 兼容 UTF-16LE 请求体（某些 WinHTTP/BSTR 场景会出现）
	if utf16Text, ok := decodeUTF16LEText(d); ok {
		ud := []byte(strings.TrimSpace(utf16Text))
		if len(ud) == 0 {
			return io.EOF
		}
		return json.Unmarshal(ud, out)
	}
	return fmt.Errorf("invalid json")
}

func decodeUTF16LEText(data []byte) (string, bool) {
	if len(data) < 2 {
		return "", false
	}
	d := data
	if len(d) >= 2 && d[0] == 0xFF && d[1] == 0xFE {
		d = d[2:]
	}
	if len(d)%2 != 0 {
		return "", false
	}
	zeroOdd := 0
	sample := len(d)
	if sample > 64 {
		sample = 64
	}
	for i := 1; i < sample; i += 2 {
		if d[i] == 0 {
			zeroOdd++
		}
	}
	// 没有明显 UTF-16LE 特征时不做误判转换
	if zeroOdd < sample/4 {
		return "", false
	}
	u16 := make([]uint16, 0, len(d)/2)
	for i := 0; i < len(d); i += 2 {
		u16 = append(u16, uint16(d[i])|uint16(d[i+1])<<8)
	}
	return string(utf16.Decode(u16)), true
}

func handleFullTextControl(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	baseDir := fullTextBaseDir()
	if baseDir == "" {
		http.Error(w, "base dir not initialized", http.StatusInternalServerError)
		return
	}
	ensureFullTextRuntime(baseDir)

	var req fullTextControlRequest
	_ = json.NewDecoder(r.Body).Decode(&req)
	action := strings.ToLower(strings.TrimSpace(req.Action))
	if action == "" {
		action = "start"
	}

	var err error
	switch action {
	case "start":
		setFullTextStartSuppressed(false)
		err = StartIndexer(baseDir)
	case "stop":
		setFullTextStartSuppressed(true)
		err = StopIndexer()
	case "restart", "rescan":
		setFullTextStartSuppressed(false)
		_ = StopIndexer()
		err = StartIndexer(baseDir)
	default:
		http.Error(w, "invalid action", http.StatusBadRequest)
		return
	}
	if err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	writeFullTextJSON(w, http.StatusOK, map[string]any{
		"ok":       true,
		"action":   action,
		"config":   fullTextRuntimeConfig(baseDir),
		"status":   GetStatus(),
		"progress": GetProgressPayload(),
	})
}

func handleFullTextProbe(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	baseDir := fullTextBaseDir()
	if baseDir == "" {
		http.Error(w, "base dir not initialized", http.StatusInternalServerError)
		return
	}
	ensureFullTextRuntime(baseDir)
	payload := probeFullTextFeasibility(baseDir)
	writeFullTextJSON(w, http.StatusOK, map[string]any{
		"ok":    true,
		"probe": payload,
	})
}

func writeFullTextJSON(w http.ResponseWriter, status int, payload any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(payload)
}
