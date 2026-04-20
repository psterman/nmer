package main

import (
	"database/sql"
	"encoding/json"
	"log"
	"net/http"
	"strconv"
	"strings"
	"sync"
)

func handleSearchWithDB(w http.ResponseWriter, r *http.Request, db *sql.DB, baseDir string) {
	if r.Method != http.MethodGet {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	q := strings.TrimSpace(r.URL.Query().Get("q"))
	typeStr := normalizeSearchType(strings.TrimSpace(r.URL.Query().Get("type")))
	limit := 30
	if v := r.URL.Query().Get("limit"); v != "" {
		if n, err := strconv.Atoi(v); err == nil && n > 0 {
			limit = n
		}
	}
	offset := 0
	if v := r.URL.Query().Get("offset"); v != "" {
		if n, err := strconv.Atoi(v); err == nil && n >= 0 {
			offset = n
		}
	}

	w.Header().Set("Content-Type", "application/json; charset=utf-8")

	if q == "" {
		_ = json.NewEncoder(w).Encode(searchResponse{
			Items:   []map[string]any{},
			HasMore: false,
			Offset:  offset,
			Limit:   limit,
			Query:   q,
			Type:    typeStr,
		})
		return
	}

	tokens := splitQueryTokens(q)
	if len(tokens) == 0 {
		_ = json.NewEncoder(w).Encode(searchResponse{
			Items:   []map[string]any{},
			HasMore: false,
			Offset:  offset,
			Limit:   limit,
			Query:   q,
			Type:    typeStr,
		})
		return
	}

	fetchCap := offset + limit + 200
	if fetchCap > 2000 {
		fetchCap = 2000
	}

	var merged []map[string]any
	var errMu sync.Mutex
	var firstErr error
	var wg sync.WaitGroup

	run := func(fn func() ([]map[string]any, error)) {
		wg.Add(1)
		go func() {
			defer wg.Done()
			items, err := fn()
			if err != nil {
				errMu.Lock()
				if firstErr == nil {
					firstErr = err
				}
				errMu.Unlock()
				return
			}
			errMu.Lock()
			merged = append(merged, items...)
			errMu.Unlock()
		}()
	}

	switch typeStr {
	case "all":
		run(func() ([]map[string]any, error) {
			items, _, err := searchClipboard(db, q, tokens, fetchCap, 0)
			return items, err
		})
		run(func() ([]map[string]any, error) {
			ev, err := everythingQuery(baseDir, q, fetchCap, true)
			if err != nil {
				log.Printf("[search] Everything 未返回文件结果: %v", err)
				return nil, nil
			}
			return ev, nil
		})
		run(func() ([]map[string]any, error) {
			return searchFilePathsSupplementDB(db, q, fetchCap), nil
		})
		run(func() ([]map[string]any, error) {
			return searchTemplates(baseDir, q, fetchCap, 0), nil
		})
		run(func() ([]map[string]any, error) {
			return searchConfigItems(baseDir, q, fetchCap, 0), nil
		})
		run(func() ([]map[string]any, error) {
			return searchHotkeys(baseDir, q, fetchCap, 0), nil
		})
		run(func() ([]map[string]any, error) {
			return searchFunctions(q, fetchCap, 0), nil
		})
		run(func() ([]map[string]any, error) {
			return searchUI(q, fetchCap, 0), nil
		})
	case "clipboard":
		run(func() ([]map[string]any, error) {
			items, _, err := searchClipboard(db, q, tokens, fetchCap, 0)
			return items, err
		})
	case "file":
		run(func() ([]map[string]any, error) {
			ev, err := everythingQuery(baseDir, q, fetchCap, true)
			if err != nil {
				return nil, err
			}
			return ev, nil
		})
		run(func() ([]map[string]any, error) {
			return searchFilePathsSupplementDB(db, q, fetchCap), nil
		})
	case "fulltext":
		run(func() ([]map[string]any, error) {
			return searchFullTextWithBackend(baseDir, q, fetchCap)
		})
	case "template":
		run(func() ([]map[string]any, error) {
			return searchTemplates(baseDir, q, fetchCap, 0), nil
		})
	case "config":
		run(func() ([]map[string]any, error) {
			return searchConfigItems(baseDir, q, fetchCap, 0), nil
		})
	case "hotkey":
		run(func() ([]map[string]any, error) {
			return searchHotkeys(baseDir, q, fetchCap, 0), nil
		})
	case "function":
		run(func() ([]map[string]any, error) {
			return searchFunctions(q, fetchCap, 0), nil
		})
	case "ui":
		run(func() ([]map[string]any, error) {
			return searchUI(q, fetchCap, 0), nil
		})
	default:
		_ = json.NewEncoder(w).Encode(searchResponse{
			Items:   []map[string]any{},
			HasMore: false,
			Offset:  offset,
			Limit:   limit,
			Query:   q,
			Type:    typeStr,
		})
		return
	}

	wg.Wait()

	if firstErr != nil && len(merged) == 0 {
		if typeStr == "clipboard" || typeStr == "file" || typeStr == "fulltext" {
			http.Error(w, firstErr.Error(), http.StatusInternalServerError)
			return
		}
	}

	files, others := splitFileAndOther(merged)
	sorted := sortSearchCenterMerged(files, others, q)

	// 与 AHK SearchAllDataSources 对齐：标准模式对每个数据源各取 MaxResults 再合并，条数约为「每类上限之和」；
	// 极速模式原先全局混排后只取一页 limit，易表现为「约少一半」。type=all 时放宽为每页最多 2*limit。
	pageLimit := limit
	if typeStr == "all" {
		pageLimit = limit * 2
	}

	total := len(sorted)
	end := offset + pageLimit
	if end > total {
		end = total
	}
	var page []map[string]any
	if offset < total {
		page = sorted[offset:end]
	} else {
		page = []map[string]any{}
	}
	hasMore := total > offset+pageLimit

	resp := searchResponse{
		Items:   page,
		HasMore: hasMore,
		Offset:  offset,
		Limit:   pageLimit,
		Query:   q,
		Type:    typeStr,
		Hints:   buildSearchResultHints(baseDir, len(page), q),
	}
	_ = json.NewEncoder(w).Encode(resp)
}

func normalizeSearchType(t string) string {
	t = strings.ToLower(strings.TrimSpace(t))
	if t == "" {
		return "all"
	}
	if t == "clip" {
		return "clipboard"
	}
	if t == "content" || t == "全文" || t == "全文搜索" {
		return "fulltext"
	}
	return t
}
