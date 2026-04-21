//go:build !windows

package main

import (
	"encoding/json"
	"net/http"
	"time"
)

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

type FullTextStatus struct {
	Engine             string   `json:"engine"`
	Running            bool     `json:"running"`
	Ready              bool     `json:"ready"`
	InitialScanDone    bool     `json:"initialScanDone"`
	Progress           float64  `json:"progress"`
	IndexingFile       string   `json:"indexing_file"`
	IndexedFiles       int64    `json:"indexedFiles"`
	PendingTasks       int      `json:"pendingTasks"`
	WorkerCount        int      `json:"workerCount"`
	ScanSpeed          string   `json:"scanSpeed"`
	IncludeLargeText   bool     `json:"includeLargeText"`
	MaxFileSizeMB      int64    `json:"maxFileSizeMB"`
	IndexDir           string   `json:"indexDir"`
	NeedUserIndexDir   bool     `json:"needUserIndexDir"`
	Roots              []string `json:"roots"`
	LowDisk            bool     `json:"lowDisk"`
	FreeDiskMB         int64    `json:"freeDiskMB"`
	WritesPaused       bool     `json:"writesPaused"`
	LastError          string   `json:"lastError,omitempty"`
	Alerts             []string `json:"alerts,omitempty"`
	LastUpdatedRFC3339 string   `json:"lastUpdated"`
}

type fullTextProgressPayload struct {
	Progress     float64  `json:"progress"`
	ProgressText string   `json:"progressText"`
	IndexingFile string   `json:"indexing_file"`
	Ready        bool     `json:"ready"`
	Running      bool     `json:"running"`
	LowDisk      bool     `json:"lowDisk"`
	EngineLights []string `json:"engine_lights"`
	Alerts       []string `json:"alerts,omitempty"`
}

func InitFullTextRuntime(baseDir string) {}

func ShouldAutoStartIndexer(baseDir string) bool { return false }

func StartIndexer(baseDir string) error {
	return nil
}

func Search(query string, limit int) ([]map[string]any, error) {
	return []map[string]any{}, nil
}

func GetStatus() FullTextStatus {
	return FullTextStatus{
		Engine:             "bluge",
		Running:            false,
		Ready:              false,
		InitialScanDone:    false,
		Progress:           0,
		LastUpdatedRFC3339: time.Now().Format(time.RFC3339),
	}
}

func GetProgressPayload() fullTextProgressPayload {
	st := GetStatus()
	return fullTextProgressPayload{
		Progress:     st.Progress,
		ProgressText: "0.0%",
		IndexingFile: st.IndexingFile,
		Ready:        st.Ready,
		Running:      st.Running,
		LowDisk:      st.LowDisk,
		EngineLights: []string{"off", "off", "off", "off"},
		Alerts:       st.Alerts,
	}
}

func searchFullTextWithBackend(baseDir, keyword string, maxResults int) ([]map[string]any, error) {
	return searchFullTextWithRg(baseDir, keyword, maxResults)
}

func handleFullTextStatus(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	_ = json.NewEncoder(w).Encode(GetStatus())
}

func handleFullTextProgress(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	_ = json.NewEncoder(w).Encode(GetProgressPayload())
}

func handleFullTextProgressStream(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	_ = json.NewEncoder(w).Encode(GetProgressPayload())
}

func handleFullTextConfig(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet && r.Method != http.MethodPost {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	_ = json.NewEncoder(w).Encode(map[string]any{
		"config": FullTextRuntimeConfig{
			AutoStart:        false,
			Workers:          0,
			IndexDir:         "",
			IncludeLargeText: false,
			MaxFileSizeMB:    2,
			InitialDelaySec:  15,
			PauseMS:          5,
			ScanSpeed:        "normal",
		},
		"status":   GetStatus(),
		"progress": GetProgressPayload(),
	})
}

func handleFullTextControl(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	_ = json.NewEncoder(w).Encode(map[string]any{
		"ok":       true,
		"action":   "noop",
		"config":   FullTextRuntimeConfig{},
		"status":   GetStatus(),
		"progress": GetProgressPayload(),
	})
}

func handleFullTextSearchStream(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodGet {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	_ = json.NewEncoder(w).Encode(map[string]any{
		"type": "done",
		"done": true,
	})
}
