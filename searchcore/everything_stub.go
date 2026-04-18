//go:build !windows

package main

func everythingQuery(baseDir, keyword string, maxResults int, includeFolders bool) ([]map[string]any, error) {
	return nil, nil
}

func resolveEverythingExe(baseDir string) string {
	return ""
}
