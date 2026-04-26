//go:build !windows

package main

func searchFullTextWithRg(baseDir, keyword string, maxResults int) ([]map[string]any, error) {
	return []map[string]any{}, nil
}
