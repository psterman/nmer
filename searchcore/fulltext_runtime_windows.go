//go:build windows

package main

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"runtime"
	"strconv"
	"strings"
	"sync"
	"time"
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
	return FullTextRuntimeConfig{
		AutoStart:        parseBoolEnv("SEARCHCENTER_FT_AUTOSTART", true),
		Workers:          resolveWorkerCount(),
		IndexDir:         idxDir,
		IncludeLargeText: parseBoolEnv("SEARCHCENTER_FT_INCLUDE_LARGE", false),
		MaxFileSizeMB:    parseInt64Env("SEARCHCENTER_FT_MAX_FILE_MB", 2),
		InitialDelaySec:  parseInt64Env("SEARCHCENTER_FT_INITIAL_DELAY_SEC", 15),
		PauseMS:          parseInt64Env("SEARCHCENTER_FT_PAUSE_MS", -1),
		ScanSpeed:        resolveScanSpeed(),
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

	if cfg.MaxFileSizeMB <= 0 {
		cfg.MaxFileSizeMB = 2
	}
	if cfg.InitialDelaySec <= 0 {
		cfg.InitialDelaySec = 15
	}
	if cfg.PauseMS < -1 {
		cfg.PauseMS = -1
	}

	idx := strings.TrimSpace(cfg.IndexDir)
	if idx == "" {
		def, _ := resolveIndexDir(baseDir)
		idx = def
	}
	if !filepath.IsAbs(idx) {
		idx = filepath.Join(baseDir, idx)
	}
	cfg.IndexDir = filepath.Clean(idx)

	return cfg
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
	*cfg = normalizeFullTextRuntimeConfig(baseDir, *cfg)
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
	var closeErr error
	if b.writer != nil {
		closeErr = b.writer.Close()
	}
	b.mu.Lock()
	b.status.Running = false
	b.status.Ready = false
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
		if err := json.NewDecoder(r.Body).Decode(&patch); err != nil && err != io.EOF {
			http.Error(w, "invalid json body", http.StatusBadRequest)
			return
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

func writeFullTextJSON(w http.ResponseWriter, status int, payload any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(payload)
}
