package main

import (
	"context"
	"database/sql"
	"encoding/json"
	"log"
	"net/http"
	"strconv"
	"strings"
	"sync"
	"time"
)

func runQueryWithTimeout(timeout time.Duration, fn func() ([]map[string]any, error)) ([]map[string]any, error) {
	ch := make(chan struct {
		items []map[string]any
		err   error
	}, 1)
	go func() {
		items, err := fn()
		ch <- struct {
			items []map[string]any
			err   error
		}{items: items, err: err}
	}()
	select {
	case r := <-ch:
		return r.items, r.err
	case <-time.After(timeout):
		return nil, context.DeadlineExceeded
	}
}

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
	if typeStr == "file" && fetchCap > 80 {
		fetchCap = 80
	}
	if typeStr == "all" && fetchCap > 120 {
		fetchCap = 120
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
			ev, err := runQueryWithTimeout(1200*time.Millisecond, func() ([]map[string]any, error) {
				return everythingQuery(baseDir, q, fetchCap, true)
			})
			if err != nil {
				log.Printf("[search] Everything degraded (type=all): %v", err)
				return nil, nil
			}
			return ev, nil
		})
		run(func() ([]map[string]any, error) {
			items, err := runQueryWithTimeout(1200*time.Millisecond, func() ([]map[string]any, error) {
				return searchFilePathsSupplementDB(db, q, fetchCap), nil
			})
			if err != nil {
				log.Printf("[search] file supplement degraded (type=all): %v", err)
				return nil, nil
			}
			return items, nil
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
			ev, err := runQueryWithTimeout(1500*time.Millisecond, func() ([]map[string]any, error) {
				return everythingQuery(baseDir, q, fetchCap, true)
			})
			if err != nil {
				log.Printf("[search] Everything degraded (type=file): %v", err)
				return []map[string]any{}, nil
			}
			return ev, nil
		})
		run(func() ([]map[string]any, error) {
			items, err := runQueryWithTimeout(1200*time.Millisecond, func() ([]map[string]any, error) {
				return searchFilePathsSupplementDB(db, q, fetchCap), nil
			})
			if err != nil {
				log.Printf("[search] file supplement degraded (type=file): %v", err)
				return []map[string]any{}, nil
			}
			return items, nil
		})
	case "fulltext":
		run(func() ([]map[string]any, error) {
			ctx, cancel := context.WithTimeout(r.Context(), 5500*time.Millisecond)
			defer cancel()
			return searchFullTextWithBackendContext(ctx, baseDir, q, fetchCap)
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
		if typeStr == "clipboard" || typeStr == "file" {
			http.Error(w, firstErr.Error(), http.StatusInternalServerError)
			return
		}
		if typeStr == "fulltext" {
			log.Printf("[search] fulltext degraded: %v", firstErr)
		}
	}
	if typeStr == "file" && len(merged) > 120 {
		merged = merged[:120]
	}
	if typeStr == "all" && len(merged) > 180 {
		merged = merged[:180]
	}

	files, others := splitFileAndOther(merged)
	sorted := sortSearchCenterMerged(files, others, q)

	// 涓?AHK SearchAllDataSources 瀵归綈锛氭爣鍑嗘ā寮忓姣忎釜鏁版嵁婧愬悇鍙?MaxResults 鍐嶅悎骞讹紝鏉℃暟绾︿负銆屾瘡绫讳笂闄愪箣鍜屻€嶏紱
	// 鏋侀€熸ā寮忓師鍏堝叏灞€娣锋帓鍚庡彧鍙栦竴椤?limit锛屾槗琛ㄧ幇涓恒€岀害灏戜竴鍗娿€嶃€倀ype=all 鏃舵斁瀹戒负姣忛〉鏈€澶?2*limit銆?
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
	if t == "content" || t == "鍏ㄦ枃" || t == "鍏ㄦ枃鎼滅储" {
		return "fulltext"
	}
	return t
}
