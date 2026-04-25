package main

import (
	"io/fs"
	"os"
	"path/filepath"
	"strings"
)

var launcherExtAllow = map[string]struct{}{
	".exe":       {},
	".lnk":       {},
	".cpl":       {},
	".app":       {},
	".appref-ms": {},
}

func searchAppLaunchers(keyword string, maxResults int) []map[string]any {
	kw := strings.ToLower(strings.TrimSpace(keyword))
	if kw == "" || maxResults <= 0 {
		return nil
	}

	roots := []string{
		os.Getenv("ProgramFiles"),
		os.Getenv("ProgramFiles(x86)"),
		filepath.Join(os.Getenv("LOCALAPPDATA"), "Programs"),
		filepath.Join(os.Getenv("APPDATA"), "Microsoft", "Windows", "Start Menu", "Programs"),
		filepath.Join(os.Getenv("ProgramData"), "Microsoft", "Windows", "Start Menu", "Programs"),
	}

	out := make([]map[string]any, 0, maxResults)
	seen := map[string]struct{}{}
	for _, root := range roots {
		root = strings.TrimSpace(root)
		if root == "" {
			continue
		}
		if st, err := os.Stat(root); err != nil || !st.IsDir() {
			continue
		}
		_ = filepath.WalkDir(root, func(path string, d fs.DirEntry, err error) error {
			if err != nil {
				return nil
			}
			if path == "" {
				return nil
			}
			if d.IsDir() {
				rel, relErr := filepath.Rel(root, path)
				if relErr == nil && rel != "." {
					depth := strings.Count(filepath.Clean(rel), string(os.PathSeparator)) + 1
					if depth > 6 {
						return filepath.SkipDir
					}
				}
				return nil
			}
			if len(out) >= maxResults {
				return fs.SkipAll
			}
			ext := strings.ToLower(filepath.Ext(path))
			if _, ok := launcherExtAllow[ext]; !ok {
				return nil
			}
			base := strings.ToLower(filepath.Base(path))
			stem := strings.TrimSuffix(base, ext)
			if !strings.Contains(base, kw) && !strings.Contains(stem, kw) {
				return nil
			}
			clean := filepath.Clean(path)
			key := strings.ToLower(clean)
			if _, ok := seen[key]; ok {
				return nil
			}
			seen[key] = struct{}{}
			out = append(out, buildEverythingFileItem(clean, false, 0, 0))
			return nil
		})
		if len(out) >= maxResults {
			break
		}
	}
	return out
}
