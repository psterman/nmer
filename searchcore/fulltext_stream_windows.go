//go:build windows

package main

import (
	"encoding/json"
	"fmt"
	"net/http"
	"strconv"
	"strings"
)

type fullTextStreamEvent struct {
	Type  string         `json:"type"`
	Phase string         `json:"phase,omitempty"`
	Item  map[string]any `json:"item,omitempty"`
	Done  bool           `json:"done,omitempty"`
	Err   string         `json:"err,omitempty"`
}

func handleFullTextSearchStream(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	baseDir := fullTextBaseDir()
	if baseDir == "" {
		http.Error(w, "base dir not initialized", http.StatusInternalServerError)
		return
	}
	q := strings.TrimSpace(r.URL.Query().Get("q"))
	if q == "" {
		http.Error(w, "missing q", http.StatusBadRequest)
		return
	}
	limit := 30
	if v := strings.TrimSpace(r.URL.Query().Get("limit")); v != "" {
		if n, err := strconv.Atoi(v); err == nil && n > 0 {
			limit = n
		}
	}

	flusher, ok := w.(http.Flusher)
	if !ok {
		http.Error(w, "stream unsupported", http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", "text/event-stream")
	w.Header().Set("Cache-Control", "no-cache")
	w.Header().Set("Connection", "keep-alive")

	emit := func(ev fullTextStreamEvent) {
		b, _ := json.Marshal(ev)
		_, _ = fmt.Fprintf(w, "data: %s\n\n", b)
		flusher.Flush()
	}

	seen := map[string]struct{}{}
	count := 0
	sendItem := func(phase string, it map[string]any) bool {
		p := itemFilePath(it)
		if p == "" {
			return true
		}
		k := normalizePathKey(p)
		if _, ok := seen[k]; ok {
			return true
		}
		seen[k] = struct{}{}
		setItemScore(it, scoreByPathAndContent(p, itemPreview(it), q, itemScore(it)))
		if m, ok := it["Metadata"].(map[string]any); ok {
			m["StreamPhase"] = phase
		} else {
			it["Metadata"] = map[string]any{"StreamPhase": phase}
		}
		emit(fullTextStreamEvent{Type: "item", Phase: phase, Item: it})
		count++
		return count < limit
	}

	emit(fullTextStreamEvent{Type: "phase", Phase: "filename"})
	if ev, err := everythingQuery(baseDir, q, limit*2, false); err == nil {
		for _, it := range ev {
			if !sendItem("filename", it) {
				break
			}
		}
	}

	emit(fullTextStreamEvent{Type: "phase", Phase: "content"})
	_ = StartIndexer(baseDir)
	if err := streamFullTextWithRg(baseDir, q, limit, func(it map[string]any) bool {
		return sendItem("content-hot", it)
	}); err != nil {
		emit(fullTextStreamEvent{Type: "warn", Err: err.Error()})
	}
	if cold, err := Search(q, limit*2); err == nil {
		for _, it := range mergeAndRankFullTextItems(q, limit*2, cold) {
			if !sendItem("content-cold", it) {
				break
			}
		}
	} else {
		emit(fullTextStreamEvent{Type: "warn", Err: err.Error()})
	}

	emit(fullTextStreamEvent{Type: "done", Phase: "done", Done: true})
}
