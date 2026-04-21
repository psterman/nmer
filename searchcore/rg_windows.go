//go:build windows

package main

import (
	"bufio"
	"bytes"
	"context"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
	"time"
)

const (
	rgDefaultTimeout  = 12 * time.Second
	rgScannerMaxBytes = 4 * 1024 * 1024
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

func trimPreview(s string, maxRunes int) string {
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
	preview := trimPreview(lineText, 180)
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
	}

	id := fullPath
	if lineNo > 0 {
		id = fullPath + ":" + strconv.Itoa(lineNo)
	}
	return map[string]any{
		"originalDataType": "fulltext",
		"DataType":         "file",
		"DataTypeName":     "全文搜索",
		"ID":               id,
		"Title":            fileName,
		"SubTitle":         subTitle,
		"Content":          fullPath,
		"Preview":          preview,
		"Source":           "文件",
		"Metadata":         meta,
		"Action":           "open_file",
		"ActionParams":     map[string]any{"FilePath": fullPath},
	}
}

func searchFullTextWithRg(baseDir, keyword string, maxResults int) ([]map[string]any, error) {
	kw := strings.TrimSpace(keyword)
	if kw == "" || maxResults <= 0 {
		return []map[string]any{}, nil
	}
	var out []map[string]any
	err := streamFullTextWithRg(baseDir, kw, maxResults, func(item map[string]any) bool {
		out = append(out, item)
		return len(out) < maxResults
	})
	if err != nil {
		return nil, err
	}
	return out, nil
}

func streamFullTextWithRg(baseDir, keyword string, maxResults int, emit func(map[string]any) bool) error {
	kw := strings.TrimSpace(keyword)
	if kw == "" || maxResults <= 0 {
		return nil
	}
	rgExe := resolveRgExe(baseDir)
	if rgExe == "" {
		return fmt.Errorf("rg.exe not found; place it in tools\\rg.exe or install ripgrep")
	}

	filterCfg := loadFullTextFilterConfig(baseDir)
	roots := fullTextRoots(baseDir)
	seen := map[string]struct{}{}
	for _, root := range roots {
		remain := maxResults - len(seen)
		if remain <= 0 {
			break
		}
		count, err := streamFullTextRoot(rgExe, root, kw, remain, seen, filterCfg, emit)
		if err != nil && len(seen) == 0 {
			return err
		}
		if count <= 0 && err != nil {
			continue
		}
	}
	return nil
}

func streamFullTextRoot(rgExe, root, keyword string, maxResults int, seen map[string]struct{}, cfg fullTextFilterResolved, emit func(map[string]any) bool) (int, error) {
	if maxResults <= 0 {
		return 0, nil
	}
	ctx, cancel := context.WithTimeout(context.Background(), rgDefaultTimeout)
	defer cancel()

	args := []string{
		"--json",
		"--line-number",
		"--max-count", "1",
		"--fixed-strings",
		"--ignore-case",
		"--hidden",
		"--no-messages",
		"--max-filesize", fmt.Sprintf("%d", cfg.MaxScanSizeBytes),
	}

	for _, g := range rgExcludeGlobs() {
		args = append(args, "--glob", g)
	}
	for _, ext := range sortedExts(cfg.HotExts) {
		args = append(args, "--glob", "**/*."+ext)
	}
	args = append(args, keyword, root)

	cmd := exec.CommandContext(ctx, rgExe, args...)
	cmd.Dir = root
	stdout, err := cmd.StdoutPipe()
	if err != nil {
		return 0, err
	}
	var stderrBuf bytes.Buffer
	cmd.Stderr = &stderrBuf
	if err := cmd.Start(); err != nil {
		return 0, err
	}

	count := 0
	sc := bufio.NewScanner(stdout)
	sc.Buffer(make([]byte, 0, 128*1024), rgScannerMaxBytes)
	for sc.Scan() {
		line := sc.Bytes()
		var ev rgJSONEvent
		if err := json.Unmarshal(line, &ev); err != nil {
			continue
		}
		if ev.Type != "match" {
			continue
		}
		p := strings.TrimSpace(rgTextValue(ev.Data.Path))
		if p == "" {
			continue
		}
		if !filepath.IsAbs(p) {
			p = filepath.Join(root, p)
		}
		p = filepath.Clean(p)
		if isExcludedByFilter(p, cfg) {
			continue
		}
		if !isHotExt(pathExtLower(p), cfg) {
			continue
		}
		key := strings.ToLower(p)
		if _, ok := seen[key]; ok {
			continue
		}
		seen[key] = struct{}{}

		score := scoreByPathAndContent(p, rgTextValue(ev.Data.Lines), keyword, 50)
		item := buildFullTextFileItem(p, rgTextValue(ev.Data.Lines), ev.Data.LineNumber, score, "hot-rg")
		count++
		if emit != nil {
			if !emit(item) {
				cancel()
				break
			}
		}
		if count >= maxResults {
			cancel()
			break
		}
	}

	_ = sc.Err()
	waitErr := cmd.Wait()
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

func isHotExt(ext string, cfg fullTextFilterResolved) bool {
	if ext == "" {
		return false
	}
	_, ok := cfg.HotExts[ext]
	return ok
}

func rgExcludeGlobs() []string {
	return []string{
		"!**/.git/**",
		"!**/node_modules/**",
		"!**/AppData/**",
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
