//go:build !windows

package main

type everythingFileEntry struct {
	Path    string
	Size    int64
	ModNano int64
}

func everythingQuery(baseDir, keyword string, maxResults int, includeFolders bool) ([]map[string]any, error) {
	return nil, nil
}

func resolveEverythingExe(baseDir string) string {
	return ""
}

func everythingListFilesForIndex(baseDir string, roots []string, whitelistExt map[string]struct{}) ([]everythingFileEntry, error) {
	return nil, nil
}
