//go:build windows

package main

import (
	"encoding/json"
	"os"
	"path/filepath"
	"sort"
	"strings"
	"sync"
	"unsafe"

	"golang.org/x/sys/windows"
)

const fullTextFilterConfigFile = "fulltext_config.json"

type fullTextFilterConfig struct {
	MaxScanSizeBytes  int64               `json:"maxScanSizeBytes"`
	Presets           map[string][]string `json:"presets"`
	HotPresetNames    []string            `json:"hotPresetNames"`
	ColdPresetNames   []string            `json:"coldPresetNames"`
	ExcludePaths      []string            `json:"excludePaths"`
	KnowledgeRoots    []string            `json:"knowledgeRoots"`
	PDFToTextPath     string              `json:"pdftotextPath"`
	AutoDiscoverRoots bool                `json:"autoDiscoverRoots"`
	IdleIndexAfterSec int64               `json:"idleIndexAfterSec"`
}

type fullTextFilterResolved struct {
	Raw               fullTextFilterConfig
	MaxScanSizeBytes  int64
	HotExts           map[string]struct{}
	ColdExts          map[string]struct{}
	ExcludePrefixes   []string
	KnowledgeRoots    []string
	PDFToTextPath     string
	AutoDiscoverRoots bool
	IdleIndexAfter    int64
}

var (
	fullTextFilterCacheMu   sync.RWMutex
	fullTextFilterCacheBase string
	fullTextFilterCache     fullTextFilterResolved
)

func fullTextFilterConfigPath(baseDir string) string {
	return filepath.Join(baseDir, "Data", fullTextFilterConfigFile)
}

func defaultFullTextFilterConfig(baseDir string) fullTextFilterConfig {
	return fullTextFilterConfig{
		MaxScanSizeBytes: 2 * 1024 * 1024,
		Presets: map[string][]string{
			"Document":      {"pdf", "docx"},
			"Spreadsheet":   {"xlsx"},
			"KnowledgeText": {"txt", "md", "log", "csv", "json"},
			"Code":          {"go", "ahk", "js", "ts", "tsx", "jsx", "py", "java", "c", "cpp", "h", "hpp", "rs", "json", "yaml", "yml", "xml", "ini"},
			"Note":          {"md", "txt", "log", "csv"},
		},
		HotPresetNames:  []string{"Code", "Note"},
		ColdPresetNames: []string{"Document", "Spreadsheet", "KnowledgeText"},
		ExcludePaths: []string{
			"node_modules",
			".git",
			"C:\\Windows",
			"C:\\Program Files",
			"C:\\Program Files (x86)",
			"C:\\ProgramData",
			"$Recycle.Bin",
			"System Volume Information",
		},
		KnowledgeRoots:    []string{},
		PDFToTextPath:     "",
		AutoDiscoverRoots: true,
		IdleIndexAfterSec: 0,
	}
}

func loadFullTextFilterConfig(baseDir string) fullTextFilterResolved {
	cleanBase := filepath.Clean(strings.TrimSpace(baseDir))
	fullTextFilterCacheMu.RLock()
	if cleanBase != "" && strings.EqualFold(fullTextFilterCacheBase, cleanBase) {
		cfg := fullTextFilterCache
		fullTextFilterCacheMu.RUnlock()
		return cfg
	}
	fullTextFilterCacheMu.RUnlock()

	cfg := readAndNormalizeFullTextFilterConfig(cleanBase)

	fullTextFilterCacheMu.Lock()
	fullTextFilterCacheBase = cleanBase
	fullTextFilterCache = cfg
	fullTextFilterCacheMu.Unlock()
	return cfg
}

func readAndNormalizeFullTextFilterConfig(baseDir string) fullTextFilterResolved {
	raw := defaultFullTextFilterConfig(baseDir)
	path := fullTextFilterConfigPath(baseDir)
	if buf, err := os.ReadFile(path); err == nil {
		var loaded fullTextFilterConfig
		if json.Unmarshal(buf, &loaded) == nil {
			raw = mergeFullTextFilterConfig(raw, loaded)
		}
	} else {
		_ = os.MkdirAll(filepath.Dir(path), 0o755)
		if out, jerr := json.MarshalIndent(raw, "", "  "); jerr == nil {
			_ = os.WriteFile(path, out, 0o644)
		}
	}

	if raw.MaxScanSizeBytes <= 0 {
		raw.MaxScanSizeBytes = 2 * 1024 * 1024
	}
	if raw.IdleIndexAfterSec < 0 {
		raw.IdleIndexAfterSec = 0
	}

	hotExts := presetExtSet(raw.Presets, raw.HotPresetNames)
	coldExts := presetExtSet(raw.Presets, raw.ColdPresetNames)
	if len(hotExts) == 0 {
		hotExts = presetExtSet(defaultFullTextFilterConfig(baseDir).Presets, []string{"Code", "Note"})
	}
	if len(coldExts) == 0 {
		coldExts = presetExtSet(defaultFullTextFilterConfig(baseDir).Presets, []string{"Document"})
	}

	excludes := make([]string, 0, len(raw.ExcludePaths))
	for _, p := range raw.ExcludePaths {
		s := strings.TrimSpace(p)
		if s == "" {
			continue
		}
		if !filepath.IsAbs(s) && strings.ContainsAny(s, `:/\\`) {
			s = filepath.Join(baseDir, s)
		}
		excludes = append(excludes, normalizePathKey(s))
	}
	sort.Strings(excludes)

	roots := make([]string, 0, len(raw.KnowledgeRoots))
	for _, r := range raw.KnowledgeRoots {
		s := strings.TrimSpace(r)
		if s == "" {
			continue
		}
		if !filepath.IsAbs(s) {
			s = filepath.Join(baseDir, s)
		}
		s = filepath.Clean(s)
		if st, err := os.Stat(s); err == nil && st.IsDir() {
			roots = append(roots, s)
		}
	}

	pdfTool := strings.TrimSpace(raw.PDFToTextPath)
	if pdfTool != "" && !filepath.IsAbs(pdfTool) {
		pdfTool = filepath.Join(baseDir, pdfTool)
	}

	return fullTextFilterResolved{
		Raw:               raw,
		MaxScanSizeBytes:  raw.MaxScanSizeBytes,
		HotExts:           hotExts,
		ColdExts:          coldExts,
		ExcludePrefixes:   excludes,
		KnowledgeRoots:    roots,
		PDFToTextPath:     strings.TrimSpace(pdfTool),
		AutoDiscoverRoots: raw.AutoDiscoverRoots,
		IdleIndexAfter:    raw.IdleIndexAfterSec,
	}
}

func mergeFullTextFilterConfig(base, override fullTextFilterConfig) fullTextFilterConfig {
	out := base
	if override.MaxScanSizeBytes > 0 {
		out.MaxScanSizeBytes = override.MaxScanSizeBytes
	}
	if len(override.Presets) > 0 {
		out.Presets = override.Presets
	}
	if len(override.HotPresetNames) > 0 {
		out.HotPresetNames = override.HotPresetNames
	}
	if len(override.ColdPresetNames) > 0 {
		out.ColdPresetNames = override.ColdPresetNames
	}
	if len(override.ExcludePaths) > 0 {
		out.ExcludePaths = override.ExcludePaths
	}
	if len(override.KnowledgeRoots) > 0 {
		out.KnowledgeRoots = override.KnowledgeRoots
	}
	if strings.TrimSpace(override.PDFToTextPath) != "" {
		out.PDFToTextPath = strings.TrimSpace(override.PDFToTextPath)
	}
	out.AutoDiscoverRoots = override.AutoDiscoverRoots || out.AutoDiscoverRoots
	if override.IdleIndexAfterSec > 0 {
		out.IdleIndexAfterSec = override.IdleIndexAfterSec
	}
	return out
}

func presetExtSet(presets map[string][]string, names []string) map[string]struct{} {
	out := map[string]struct{}{}
	for _, name := range names {
		items := presets[name]
		for _, ext := range items {
			e := normalizeExt(ext)
			if e != "" {
				out[e] = struct{}{}
			}
		}
	}
	return out
}

func normalizeExt(ext string) string {
	e := strings.TrimSpace(strings.ToLower(ext))
	e = strings.TrimPrefix(e, ".")
	return e
}

func isExcludedByFilter(path string, cfg fullTextFilterResolved) bool {
	n := normalizePathKey(path)
	for _, ex := range cfg.ExcludePrefixes {
		if ex == "" {
			continue
		}
		if strings.Contains(ex, `\\`) || strings.Contains(ex, `:`) || strings.HasPrefix(ex, `\`) {
			if n == ex || strings.HasPrefix(n+"\\", ex+"\\") {
				return true
			}
			continue
		}
		parts := strings.Split(n, "\\")
		for _, p := range parts {
			if p == ex {
				return true
			}
		}
	}
	return false
}

func fullTextRoots(baseDir string) []string {
	cfg := loadFullTextFilterConfig(baseDir)
	if len(cfg.KnowledgeRoots) > 0 {
		return append([]string{}, cfg.KnowledgeRoots...)
	}

	env := strings.TrimSpace(os.Getenv("SEARCHCENTER_FULLTEXT_ROOTS"))
	if env != "" {
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
		if len(out) > 0 {
			return out
		}
	}

	if cfg.AutoDiscoverRoots {
		if roots := discoverSearchRoots(); len(roots) > 0 {
			return roots
		}
	}
	return []string{baseDir}
}

func discoverSearchRoots() []string {
	out := make([]string, 0, 8)
	for drive := 'C'; drive <= 'Z'; drive++ {
		root := string(drive) + ":\\"
		ptr, err := windows.UTF16PtrFromString(root)
		if err != nil {
			continue
		}
		dt, _, _ := procGetDriveTypeW.Call(uintptr(unsafe.Pointer(ptr)))
		switch uint32(dt) {
		case 2, 3:
			if st, err := os.Stat(root); err == nil && st.IsDir() {
				out = append(out, root)
			}
		}
	}
	sort.Strings(out)
	return out
}
