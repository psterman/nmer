//go:build windows

package main

import (
	"os"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
	"time"
)

func mergeAndRankFullTextItems(keyword string, limit int, groups ...[]map[string]any) []map[string]any {
	seen := map[string]struct{}{}
	all := make([]map[string]any, 0, limit)
	for _, g := range groups {
		for _, it := range g {
			k := itemDedupKey(it)
			if k == "" {
				continue
			}
			if _, ok := seen[k]; ok {
				continue
			}
			seen[k] = struct{}{}
			p := itemFilePath(it)
			score := scoreByPathAndContent(p, itemPreview(it), keyword, itemScore(it))
			setItemScore(it, score)
			all = append(all, it)
		}
	}

	sort.SliceStable(all, func(i, j int) bool {
		si := itemScore(all[i])
		sj := itemScore(all[j])
		if si == sj {
			return strings.ToLower(itemFilePath(all[i])) < strings.ToLower(itemFilePath(all[j]))
		}
		return si > sj
	})

	if limit > 0 && len(all) > limit {
		return all[:limit]
	}
	return all
}

func itemDedupKey(it map[string]any) string {
	if it == nil {
		return ""
	}
	if id, ok := it["ID"].(string); ok && strings.TrimSpace(id) != "" {
		return strings.ToLower(strings.TrimSpace(id))
	}
	p := itemFilePath(it)
	if p == "" {
		return ""
	}
	line := 0
	if m, ok := it["Metadata"].(map[string]any); ok && m != nil {
		switch v := m["LineNumber"].(type) {
		case int:
			line = v
		case int32:
			line = int(v)
		case int64:
			line = int(v)
		case float64:
			line = int(v)
		}
	}
	if line > 0 {
		return normalizePathKey(p) + ":" + strconv.Itoa(line)
	}
	return normalizePathKey(p)
}

func scoreByPathAndContent(path, content, keyword string, base float64) float64 {
	score := base
	if score <= 0 {
		score = 1
	}
	kw := strings.ToLower(strings.TrimSpace(keyword))
	if kw == "" {
		return score
	}
	name := strings.ToLower(filepath.Base(path))
	full := strings.ToLower(path)
	body := strings.ToLower(content)

	// 字段加权：文件名 > 路径 > 正文（对标 AnyTXT 文件名优先）
	if strings.Contains(name, kw) {
		if name == kw {
			score += 320
		} else if strings.HasPrefix(name, kw) {
			score += 260
		} else {
			score += 200
		}
	}
	if strings.Contains(full, kw) {
		score += 75
	}
	if strings.Contains(body, kw) {
		score += 25
	}
	return applyRecencyBoost(path, score)
}

func applyRecencyBoost(path string, score float64) float64 {
	st, err := os.Stat(path)
	if err != nil {
		return score
	}
	age := time.Since(st.ModTime())
	switch {
	case age <= 7*24*time.Hour:
		return score * 1.10
	case age <= 30*24*time.Hour:
		return score * 1.07
	case age <= 90*24*time.Hour:
		return score * 1.05
	default:
		return score
	}
}

func itemFilePath(it map[string]any) string {
	if it == nil {
		return ""
	}
	if v, ok := it["Content"].(string); ok && strings.TrimSpace(v) != "" {
		return v
	}
	if m, ok := it["Metadata"].(map[string]any); ok {
		if v, ok := m["FilePath"].(string); ok {
			return v
		}
	}
	return ""
}

func itemPreview(it map[string]any) string {
	if it == nil {
		return ""
	}
	if v, ok := it["Preview"].(string); ok {
		return v
	}
	if m, ok := it["Metadata"].(map[string]any); ok {
		if v, ok := m["MatchedLine"].(string); ok {
			return v
		}
	}
	return ""
}

func itemScore(it map[string]any) float64 {
	if it == nil {
		return 0
	}
	if m, ok := it["Metadata"].(map[string]any); ok {
		switch v := m["SearchScore"].(type) {
		case float64:
			return v
		case float32:
			return float64(v)
		case int:
			return float64(v)
		case int64:
			return float64(v)
		}
	}
	return 0
}

func setItemScore(it map[string]any, score float64) {
	if it == nil {
		return
	}
	m, _ := it["Metadata"].(map[string]any)
	if m == nil {
		m = map[string]any{}
		it["Metadata"] = m
	}
	m["SearchScore"] = score
}
