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

func fullTextRoots(baseDir string) []string {
	env := strings.TrimSpace(os.Getenv("SEARCHCENTER_FULLTEXT_ROOTS"))
	if env == "" {
		return []string{baseDir}
	}
	parts := strings.Split(env, ";")
	out := make([]string, 0, len(parts))
	for _, p := range parts {
		s := strings.TrimSpace(p)
		if s == "" {
			continue
		}
		if !filepath.IsAbs(s) {
			s = filepath.Join(baseDir, s)
		}
		if st, err := os.Stat(s); err == nil && st.IsDir() {
			out = append(out, s)
		}
	}
	if len(out) == 0 {
		return []string{baseDir}
	}
	return out
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

func buildFullTextFileItem(fullPath, lineText string, lineNo int) map[string]any {
	dirPath, fileName, ext := splitPathParts(fullPath)
	preview := trimPreview(lineText, 180)
	subParts := []string{}
	if dirPath != "" {
		subParts = append(subParts, dirPath)
	}
	if lineNo > 0 {
		subParts = append(subParts, "第 "+strconv.Itoa(lineNo)+" 行")
	}
	var ts string
	if st, err := os.Stat(fullPath); err == nil {
		ts = st.ModTime().Format("2006-01-02 15:04")
	}
	if ts != "" {
		subParts = append(subParts, ts)
	}
	subTitle := strings.Join(subParts, " · ")

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
	rgExe := resolveRgExe(baseDir)
	if rgExe == "" {
		return nil, fmt.Errorf("未找到 rg.exe，可放到 tools\\rg.exe 或安装 ripgrep")
	}

	roots := fullTextRoots(baseDir)
	seen := map[string]struct{}{}
	out := make([]map[string]any, 0, maxResults)
	for _, root := range roots {
		items, err := searchFullTextRoot(rgExe, root, kw, maxResults-len(out), seen)
		if err != nil && len(out) == 0 {
			return nil, err
		}
		out = append(out, items...)
		if len(out) >= maxResults {
			break
		}
	}
	return out, nil
}

func searchFullTextRoot(rgExe, root, keyword string, maxResults int, seen map[string]struct{}) ([]map[string]any, error) {
	if maxResults <= 0 {
		return nil, nil
	}
	ctx, cancel := context.WithTimeout(context.Background(), rgDefaultTimeout)
	defer cancel()

	args := []string{
		"--json",
		"--line-number",
		"--max-count", "1",
		"--fixed-strings",
		"--ignore-case",
		"--glob", "!**/.git/**",
		"--glob", "!**/node_modules/**",
		"--glob", "!**/cache/**",
		"--glob", "!**/Data/**",
		"--glob", "!**/*.exe",
		"--glob", "!**/*.dll",
		"--glob", "!**/*.db",
		"--glob", "!**/*.wal",
		"--glob", "!**/*.shm",
		"--max-filesize", "2M",
		keyword,
		root,
	}
	cmd := exec.CommandContext(ctx, rgExe, args...)
	cmd.Dir = root
	stdout, err := cmd.StdoutPipe()
	if err != nil {
		return nil, err
	}
	var stderrBuf bytes.Buffer
	cmd.Stderr = &stderrBuf
	if err := cmd.Start(); err != nil {
		return nil, err
	}

	out := make([]map[string]any, 0, maxResults)
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
		key := strings.ToLower(p)
		if _, ok := seen[key]; ok {
			continue
		}
		seen[key] = struct{}{}
		mt := rgTextValue(ev.Data.Lines)
		out = append(out, buildFullTextFileItem(p, mt, ev.Data.LineNumber))
		if len(out) >= maxResults {
			cancel()
			break
		}
	}

	_ = sc.Err()
	waitErr := cmd.Wait()
	if len(out) > 0 {
		return out, nil
	}
	if ctx.Err() == context.DeadlineExceeded {
		return nil, fmt.Errorf("全文搜索超时（%s）", rgDefaultTimeout)
	}
	if waitErr != nil {
		msg := strings.TrimSpace(stderrBuf.String())
		if msg == "" {
			msg = waitErr.Error()
		}
		return nil, fmt.Errorf("rg 执行失败: %s", msg)
	}
	return out, nil
}
