//go:build windows

package main

import (
	"os"
	"path/filepath"
	"sort"
	"strings"
	"time"
)

func mergeAndRankFullTextItems(keyword string, limit int, groups ...[]map[string]any) []map[string]any {
	seen := map[string]struct{}{}
	all := make([]map[string]any, 0, limit)
	for _, g := range groups {
		for _, it := range g {
			p := itemFilePath(it)
			if p == "" {
				continue
			}
			k := normalizePathKey(p)
			if _, ok := seen[k]; ok {
				continue
			}
			seen[k] = struct{}{}
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

	if strings.Contains(name, kw) {
		score += 120
	}
	if strings.Contains(full, kw) {
		score += 35
	}
	if strings.Contains(body, kw) {
		score += 10
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
