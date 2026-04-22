//go:build windows

package main

import (
	"bufio"
	"bytes"
	"context"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
	"syscall"
	"time"
)

const (
	rgDefaultTimeout  = 4500 * time.Millisecond
	rgScannerMaxBytes = 1 * 1024 * 1024
	rgOutputWindow    = 100 * time.Millisecond
	rgOutputBurst     = 80
	rgHardResultLimit = 400
)

type rgJSONText struct {
	Text  string `json:"text"`
	Bytes string `json:"bytes"`
}

type rgJSONMatchData struct {
	Path       rgJSONText `json:"path"`
	Lines      rgJSONText `json:"lines"`
	LineNumber int        `json:"line_number"`
}

type rgJSONEvent struct {
	Type string          `json:"type"`
	Data rgJSONMatchData `json:"data"`
}

func terminateExistingRgProcesses() {
	ctx, cancel := context.WithTimeout(context.Background(), 300*time.Millisecond)
	defer cancel()
	cmd := exec.CommandContext(ctx, "taskkill", "/F", "/IM", "rg.exe", "/T")
	out, err := cmd.CombinedOutput()
	if err != nil {
		if ctx.Err() == context.DeadlineExceeded {
			return
		}
		msg := strings.ToLower(string(out))
		// No running rg.exe is not an error in practice.
		if strings.Contains(msg, "not found") || strings.Contains(msg, "no running instance") || strings.Contains(msg, "没有运行的任务") || strings.Contains(msg, "没有找到") {
			return
		}
		log.Printf("[rg] taskkill rg.exe failed: %v (%s)", err, strings.TrimSpace(string(out)))
		return
	}
	if s := strings.TrimSpace(string(out)); s != "" {
		log.Printf("[rg] terminated stale rg.exe processes: %s", s)
	}
}

func resolveRgExe(baseDir string) string {
	candidates := []string{
		filepath.Join(baseDir, "tools", "rg.exe"),
		filepath.Join(baseDir, "lib", "rg.exe"),
		filepath.Join(baseDir, "rg.exe"),
	}
	for _, p := range candidates {
		if p == "" {
			continue
		}
		if st, err := os.Stat(p); err == nil && !st.IsDir() {
			return p
		}
	}
	if p, err := exec.LookPath("rg.exe"); err == nil && p != "" {
		return p
	}
	if p, err := exec.LookPath("rg"); err == nil && p != "" {
		return p
	}
	return ""
}

func rgTextValue(v rgJSONText) string {
	if v.Text != "" {
		return v.Text
	}
	if v.Bytes == "" {
		return ""
	}
	b, err := base64.StdEncoding.DecodeString(v.Bytes)
	if err != nil {
		return ""
	}
	return string(b)
}

func compactLinePreview(s string, maxRunes int) string {
	s = strings.TrimSpace(strings.ReplaceAll(strings.ReplaceAll(s, "\r", " "), "\n", " "))
	if s == "" {
		return ""
	}
	r := []rune(s)
	if len(r) <= maxRunes {
		return s
	}
	return string(r[:maxRunes]) + "..."
}

func buildFullTextFileItem(fullPath, lineText string, lineNo int, score float64, hitSource string) map[string]any {
	dirPath, fileName, ext := splitPathParts(fullPath)
	preview := compactLinePreview(lineText, 180)
	subParts := []string{}
	if dirPath != "" {
		subParts = append(subParts, dirPath)
	}
	if lineNo > 0 {
		subParts = append(subParts, "line "+strconv.Itoa(lineNo))
	}
	var ts string
	if st, err := os.Stat(fullPath); err == nil {
		ts = st.ModTime().Format("2006-01-02 15:04")
	}
	if ts != "" {
		subParts = append(subParts, ts)
	}
	subTitle := strings.Join(subParts, " | ")

	meta := map[string]any{
		"FilePath":     fullPath,
		"FileName":     fileName,
		"DirPath":      dirPath,
		"Ext":          ext,
		"IsDirectory":  false,
		"LineNumber":   lineNo,
		"MatchedLine":  preview,
		"FullTextHit":  true,
		"DateModified": ts,
		"SearchScore":  score,
		"HitSource":    hitSource,
		"HitCount":     1,
		"HitLines":     []int{lineNo},
	}

	id := fullPath
	if lineNo > 0 {
		id = fullPath + ":" + strconv.Itoa(lineNo)
	}
	return map[string]any{
		"originalDataType": "fulltext",
		"DataType":         "file",
		"DataTypeName":     "鍏ㄦ枃鎼滅储",
		"ID":               id,
		"Title":            fileName,
		"SubTitle":         subTitle,
		"Content":          fullPath,
		"Preview":          preview,
		"Source":           "鏂囦欢",
		"Metadata":         meta,
		"Action":           "open_file",
		"ActionParams":     map[string]any{"FilePath": fullPath},
	}
}

func searchFullTextWithRg(baseDir, keyword string, maxResults int) ([]map[string]any, error) {
	return searchFullTextWithRgContext(context.Background(), baseDir, keyword, maxResults)
}

func searchFullTextWithRgContext(ctx context.Context, baseDir, keyword string, maxResults int) ([]map[string]any, error) {
	kw := strings.TrimSpace(keyword)
	if kw == "" || maxResults <= 0 {
		return []map[string]any{}, nil
	}
	terminateExistingRgProcesses()
	var out []map[string]any
	err := streamFullTextWithRgContext(ctx, baseDir, kw, maxResults, func(item map[string]any) bool {
		out = append(out, item)
		return len(out) < maxResults
	})
	if err != nil {
		return nil, err
	}
	return out, nil
}

func streamFullTextWithRg(baseDir, keyword string, maxResults int, emit func(map[string]any) bool) error {
	return streamFullTextWithRgContext(context.Background(), baseDir, keyword, maxResults, emit)
}

func streamFullTextWithRgContext(parent context.Context, baseDir, keyword string, maxResults int, emit func(map[string]any) bool) error {
	kw := strings.TrimSpace(keyword)
	if kw == "" || maxResults <= 0 {
		return nil
	}
	if maxResults > rgHardResultLimit {
		maxResults = rgHardResultLimit
	}
	if parent == nil {
		parent = context.Background()
	}
	rgExe := resolveRgExe(baseDir)
	if rgExe == "" {
		return fmt.Errorf("rg.exe not found; place it in tools\\rg.exe or install ripgrep")
	}

	filterCfg := loadFullTextFilterConfig(baseDir)
	roots := limitHotSearchRoots(fullTextRoots(baseDir))
	seen := map[string]int{}
	totalOut := 0
	var lastErr error
	for _, root := range roots {
		remain := maxResults - totalOut
		if remain <= 0 {
			break
		}
		rootCtx, cancel := context.WithTimeout(parent, rgDefaultTimeout)
		count, err := streamFullTextRoot(rootCtx, rgExe, root, kw, remain, seen, filterCfg, emit)
		cancel()
		totalOut += count
		if err != nil {
			lastErr = err
		}
		if count <= 0 && err != nil {
			continue
		}
	}
	if totalOut == 0 && lastErr != nil {
		return lastErr
	}
	if err := parent.Err(); err != nil {
		return err
	}
	return nil
}

func limitHotSearchRoots(roots []string) []string {
	if len(roots) <= 1 {
		return roots
	}
	maxRoots := int(parseInt64Env("SEARCHCENTER_RG_MAX_ROOTS", 3))
	if maxRoots < 1 {
		maxRoots = 1
	}
	if maxRoots >= len(roots) {
		return roots
	}
	return append([]string{}, roots[:maxRoots]...)
}

type rgRateLimiter struct {
	windowStart time.Time
	emitted     int
	dropped     int
}

func (l *rgRateLimiter) allow(now time.Time) bool {
	if l.windowStart.IsZero() || now.Sub(l.windowStart) >= rgOutputWindow {
		if l.dropped > 0 {
			log.Printf("[rg] throttled %d hits in %s window", l.dropped, rgOutputWindow)
		}
		l.windowStart = now
		l.emitted = 0
		l.dropped = 0
	}
	if l.emitted < rgOutputBurst {
		l.emitted++
		return true
	}
	l.dropped++
	return false
}

func (l *rgRateLimiter) flush() {
	if l.dropped > 0 {
		log.Printf("[rg] throttled %d hits in %s window", l.dropped, rgOutputWindow)
	}
}

func makeRGJSONLineSplit(maxToken int, onDrop func()) bufio.SplitFunc {
	dropping := false
	return func(data []byte, atEOF bool) (advance int, token []byte, err error) {
		if len(data) == 0 {
			return 0, nil, nil
		}
		if i := bytes.IndexByte(data, '\n'); i >= 0 {
			line := data[:i]
			advance = i + 1
			if dropping || len(line) > maxToken {
				dropping = false
				if onDrop != nil {
					onDrop()
				}
				return advance, nil, nil
			}
			return advance, bytes.TrimRight(line, "\r"), nil
		}
		if len(data) > maxToken {
			dropping = true
			return maxToken, nil, nil
		}
		if atEOF {
			if dropping || len(data) > maxToken {
				dropping = false
				if onDrop != nil {
					onDrop()
				}
				return len(data), nil, nil
			}
			return len(data), bytes.TrimRight(data, "\r"), nil
		}
		return 0, nil, nil
	}
}

func streamFullTextRoot(ctx context.Context, rgExe, root, keyword string, maxResults int, seen map[string]int, cfg fullTextFilterResolved, emit func(map[string]any) bool) (int, error) {
	if maxResults <= 0 {
		return 0, nil
	}

	args := []string{
		"--json",
		"--line-number",
		"--max-count", "500",
		"-j", "2",
		"--fixed-strings",
		"--ignore-case",
		"--hidden",
		"--no-messages",
		"--max-columns", "2000",
		"--max-filesize", "8M",
	}

	for _, g := range rgExcludeGlobs() {
		args = append(args, "--glob", g)
	}
	for _, ext := range sortedExts(rgSearchExts(cfg)) {
		args = append(args, "--glob", "**/*."+ext)
	}
	args = append(args, keyword, root)

	cmd := exec.Command(rgExe, args...)
	cmd.Dir = root
	cmd.SysProcAttr = &syscall.SysProcAttr{
		CreationFlags: 0x08000000 | 0x00000040,
	}
	stdout, err := cmd.StdoutPipe()
	if err != nil {
		return 0, err
	}
	var stderrBuf bytes.Buffer
	cmd.Stderr = &stderrBuf
	if err := cmd.Start(); err != nil {
		return 0, err
	}

	waitCh := make(chan error, 1)
	go func() {
		waitCh <- cmd.Wait()
	}()

	stopKillWatch := make(chan struct{})
	go func() {
		select {
		case <-ctx.Done():
			if cmd.Process != nil {
				if err := cmd.Process.Kill(); err == nil {
					log.Printf("[rg] killed pid=%d due to cancel", cmd.Process.Pid)
				}
			}
		case <-stopKillWatch:
		}
	}()
	defer close(stopKillWatch)

	count := 0
	oversizeLines := 0
	limiter := &rgRateLimiter{}
	sc := bufio.NewScanner(stdout)
	sc.Buffer(make([]byte, 64*1024), rgScannerMaxBytes)
	sc.Split(makeRGJSONLineSplit(rgScannerMaxBytes, func() {
		oversizeLines++
	}))

	for sc.Scan() {
		if ctx.Err() != nil {
			break
		}
		line := sc.Bytes()
		if len(line) == 0 {
			continue
		}
		p, matchedLine, lineNo, ok := parseRGMatchLine(line)
		if !ok {
			continue
		}
		if !filepath.IsAbs(p) {
			p = filepath.Join(root, p)
		}
		p = filepath.Clean(p)
		if isExcludedByFilter(p, cfg) {
			continue
		}
		if !isAllowedRgExt(pathExtLower(p), cfg) {
			continue
		}
		key := strings.ToLower(p)
		if seen[key] >= 10 {
			continue
		}
		seen[key]++

		score := scoreByPathAndContent(p, matchedLine, keyword, 50)
		item := buildFullTextFileItem(p, matchedLine, lineNo, score, "hot-rg")
		if !limiter.allow(time.Now()) {
			continue
		}
		count++
		if emit != nil {
			if !emit(item) {
				if cmd.Process != nil {
					_ = cmd.Process.Kill()
				}
				break
			}
		}
		if count >= maxResults {
			if cmd.Process != nil {
				_ = cmd.Process.Kill()
			}
			break
		}
	}

	if oversizeLines > 0 {
		log.Printf("[rg] dropped %d oversized JSON lines (> %d bytes)", oversizeLines, rgScannerMaxBytes)
	}
	limiter.flush()

	scanErr := sc.Err()
	if scanErr != nil {
		log.Printf("[rg] scanner error: %v", scanErr)
	}
	if ctx.Err() != nil {
		if cmd.Process != nil {
			_ = cmd.Process.Kill()
		}
		return count, nil
	}
	waitErr := <-waitCh
	if count > 0 {
		return count, nil
	}
	if ctx.Err() == context.DeadlineExceeded {
		return 0, fmt.Errorf("fulltext hot scan timeout (%s)", rgDefaultTimeout)
	}
	if waitErr != nil {
		msg := strings.TrimSpace(stderrBuf.String())
		if msg == "" {
			msg = waitErr.Error()
		}
		return 0, fmt.Errorf("rg execution failed: %s", msg)
	}
	return 0, nil
}

func pathExtLower(path string) string {
	return strings.TrimPrefix(strings.ToLower(filepath.Ext(path)), ".")
}

func isAllowedRgExt(ext string, cfg fullTextFilterResolved) bool {
	if ext == "" {
		return false
	}
	if _, ok := cfg.HotExts[ext]; ok {
		return true
	}
	_, ok := cfg.ColdExts[ext]
	return ok
}

func rgSearchExts(cfg fullTextFilterResolved) map[string]struct{} {
	out := make(map[string]struct{}, len(cfg.HotExts)+len(cfg.ColdExts))
	for ext := range cfg.HotExts {
		out[ext] = struct{}{}
	}
	for ext := range cfg.ColdExts {
		out[ext] = struct{}{}
	}
	return out
}

func rgExcludeGlobs() []string {
	return []string{
		"!**/.git/**",
		"!**/node_modules/**",
		"!**/$Recycle.Bin/**",
		"!**/Windows/**",
		"!**/*.exe",
		"!**/*.dll",
		"!**/*.db",
		"!**/*.wal",
		"!**/*.shm",
	}
}

func sortedExts(m map[string]struct{}) []string {
	out := make([]string, 0, len(m))
	for k := range m {
		out = append(out, k)
	}
	sort.Strings(out)
	return out
}

func parseRGMatchLine(line []byte) (path string, matchedLine string, lineNo int, ok bool) {
	dec := json.NewDecoder(bytes.NewReader(line))
	dec.UseNumber()
	tok, err := dec.Token()
	if err != nil {
		return "", "", 0, false
	}
	d, okDelim := tok.(json.Delim)
	if !okDelim || d != '{' {
		return "", "", 0, false
	}

	matchType := false
	for dec.More() {
		keyTok, err := dec.Token()
		if err != nil {
			return "", "", 0, false
		}
		key, okKey := keyTok.(string)
		if !okKey {
			return "", "", 0, false
		}
		switch key {
		case "type":
			var t string
			if err := dec.Decode(&t); err != nil {
				return "", "", 0, false
			}
			matchType = (t == "match")
		case "data":
			p, ln, n, okData := parseRGDataObject(dec)
			if !okData {
				return "", "", 0, false
			}
			path, matchedLine, lineNo = p, ln, n
		default:
			if err := discardJSONValue(dec); err != nil {
				return "", "", 0, false
			}
		}
	}
	if _, err := dec.Token(); err != nil {
		return "", "", 0, false
	}
	if !matchType {
		return "", "", 0, false
	}
	path = strings.TrimSpace(path)
	if path == "" {
		return "", "", 0, false
	}
	return path, matchedLine, lineNo, true
}

func parseRGDataObject(dec *json.Decoder) (path string, matchedLine string, lineNo int, ok bool) {
	tok, err := dec.Token()
	if err != nil {
		return "", "", 0, false
	}
	d, okDelim := tok.(json.Delim)
	if !okDelim || d != '{' {
		return "", "", 0, false
	}
	for dec.More() {
		keyTok, err := dec.Token()
		if err != nil {
			return "", "", 0, false
		}
		key, okKey := keyTok.(string)
		if !okKey {
			return "", "", 0, false
		}
		switch key {
		case "path":
			text, bytesVal, okText := parseRGTextObject(dec)
			if !okText {
				return "", "", 0, false
			}
			path = rgTextValue(rgJSONText{Text: text, Bytes: bytesVal})
		case "lines":
			text, bytesVal, okText := parseRGTextObject(dec)
			if !okText {
				return "", "", 0, false
			}
			matchedLine = rgTextValue(rgJSONText{Text: text, Bytes: bytesVal})
		case "line_number":
			var n json.Number
			if err := dec.Decode(&n); err != nil {
				return "", "", 0, false
			}
			if i, err := n.Int64(); err == nil {
				lineNo = int(i)
			}
		default:
			if err := discardJSONValue(dec); err != nil {
				return "", "", 0, false
			}
		}
	}
	if _, err := dec.Token(); err != nil {
		return "", "", 0, false
	}
	return path, matchedLine, lineNo, true
}

func parseRGTextObject(dec *json.Decoder) (text string, bytesVal string, ok bool) {
	tok, err := dec.Token()
	if err != nil {
		return "", "", false
	}
	d, okDelim := tok.(json.Delim)
	if !okDelim || d != '{' {
		return "", "", false
	}
	for dec.More() {
		keyTok, err := dec.Token()
		if err != nil {
			return "", "", false
		}
		key, okKey := keyTok.(string)
		if !okKey {
			return "", "", false
		}
		switch key {
		case "text":
			if err := dec.Decode(&text); err != nil {
				return "", "", false
			}
		case "bytes":
			if err := dec.Decode(&bytesVal); err != nil {
				return "", "", false
			}
		default:
			if err := discardJSONValue(dec); err != nil {
				return "", "", false
			}
		}
	}
	if _, err := dec.Token(); err != nil {
		return "", "", false
	}
	return text, bytesVal, true
}

func discardJSONValue(dec *json.Decoder) error {
	tok, err := dec.Token()
	if err != nil {
		return err
	}
	d, ok := tok.(json.Delim)
	if !ok {
		return nil
	}
	switch d {
	case '{':
		for dec.More() {
			if _, err := dec.Token(); err != nil {
				return err
			}
			if err := discardJSONValue(dec); err != nil {
				return err
			}
		}
		_, err = dec.Token()
		return err
	case '[':
		for dec.More() {
			if err := discardJSONValue(dec); err != nil {
				return err
			}
		}
		_, err = dec.Token()
		return err
	default:
		return nil
	}
}
