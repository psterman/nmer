//go:build !windows

package main

import (
	"encoding/json"
	"net/http"
	"time"
)

const fullTextIndexVersion = "stub"

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
	ProgressText       string   `json:"progressText"`
	ProgressDetail     string   `json:"progressDetail"`
	EfficiencyText     string   `json:"efficiencyText"`
	ScanPhase          string   `json:"scanPhase"`
	IndexingFile       string   `json:"indexing_file"`
	IndexedFiles       int64    `json:"indexedFiles"`
	DiscoveredFiles    int64    `json:"discoveredFiles"`
	ProcessedFiles     int64    `json:"processedFiles"`
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
	FilesPerSec        float64  `json:"filesPerSec"`
	ETASeconds         int64    `json:"etaSeconds"`
	LastError          string   `json:"lastError,omitempty"`
	Alerts             []string `json:"alerts,omitempty"`
	LastUpdatedRFC3339 string   `json:"lastUpdated"`
	ScanMode           string   `json:"scan_mode,omitempty"`
	IndexEpoch         uint64   `json:"indexEpoch,omitempty"`
	IndexVersion       string   `json:"indexVersion,omitempty"`
}

type fullTextProgressPayload struct {
	Progress       float64  `json:"progress"`
	ProgressText   string   `json:"progressText"`
	ProgressDetail string   `json:"progressDetail"`
	EfficiencyText string   `json:"efficiencyText"`
	ScanPhase      string   `json:"scanPhase"`
	IndexingFile   string   `json:"indexing_file"`
	Ready          bool     `json:"ready"`
	Running        bool     `json:"running"`
	LowDisk        bool     `json:"lowDisk"`
	FilesPerSec    float64  `json:"filesPerSec"`
	ETASeconds     int64    `json:"etaSeconds"`
	EngineLights   []string `json:"engine_lights"`
	Alerts         []string `json:"alerts,omitempty"`
	ScanMode       string   `json:"scan_mode,omitempty"`
	IndexEpoch     uint64   `json:"indexEpoch,omitempty"`
	IndexVersion   string   `json:"indexVersion,omitempty"`
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
		ProgressText:       "0.0%",
		ProgressDetail:     "未开始扫描",
		EfficiencyText:     "0 文件/秒",
		ScanPhase:          "idle",
		IndexVersion:       fullTextIndexVersion,
		LastUpdatedRFC3339: time.Now().Format(time.RFC3339),
	}
}

func GetProgressPayload() fullTextProgressPayload {
	st := GetStatus()
	return fullTextProgressPayload{
		Progress:       st.Progress,
		ProgressText:   st.ProgressText,
		ProgressDetail: st.ProgressDetail,
		EfficiencyText: st.EfficiencyText,
		ScanPhase:      st.ScanPhase,
		IndexingFile:   st.IndexingFile,
		Ready:          st.Ready,
		Running:        st.Running,
		LowDisk:        st.LowDisk,
		FilesPerSec:    st.FilesPerSec,
		ETASeconds:     st.ETASeconds,
		EngineLights:   []string{"off", "off", "off", "off"},
		Alerts:         st.Alerts,
		ScanMode:       st.ScanMode,
		IndexEpoch:     st.IndexEpoch,
		IndexVersion:   st.IndexVersion,
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
