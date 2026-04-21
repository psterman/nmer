//go:build windows

package main

import (
	"os"
	"strings"
)

func buildHitContextForFile(path, query string, maxBlocks int) []map[string]any {
	q := strings.TrimSpace(query)
	if q == "" || maxBlocks <= 0 {
		return nil
	}
	st, err := os.Stat(path)
	if err != nil || st.IsDir() || st.Size() <= 0 {
		return nil
	}
	if st.Size() > 8*1024*1024 {
		return nil
	}
	raw, err := mmapReadFileUpTo(path, st.Size())
	if err != nil || len(raw) == 0 {
		return nil
	}
	text, err := decodeBestEffortText(raw)
	if err != nil || text == "" {
		return nil
	}
	return hitContextFromText(text, q, maxBlocks)
}

func hitContextFromText(text, query string, maxBlocks int) []map[string]any {
	ql := strings.ToLower(query)
	lines := strings.Split(text, "\n")
	var out []map[string]any
	for i, ln := range lines {
		if !strings.Contains(strings.ToLower(ln), ql) {
			continue
		}
		start := i - 1
		if start < 0 {
			start = 0
		}
		end := i + 2
		if end > len(lines) {
			end = len(lines)
		}
		var b strings.Builder
		for j := start; j < end; j++ {
			prefix := " "
			if j == i {
				prefix = ">"
			}
			b.WriteString(prefix)
			b.WriteString(strings.TrimRight(lines[j], "\r"))
			if j < end-1 {
				b.WriteByte('\n')
			}
		}
		out = append(out, map[string]any{
			"line":    i + 1,
			"snippet": strings.TrimSpace(b.String()),
		})
		if len(out) >= maxBlocks {
			break
		}
	}
	return out
}
