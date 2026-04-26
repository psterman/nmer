package main

import (
	"os"
	"path/filepath"
)

// buildSearchResultHints gives actionable diagnostics when no result is returned.
func buildSearchResultHints(baseDir string, itemCount int, query string) []string {
	if itemCount > 0 || query == "" {
		return nil
	}

	var h []string
	if !curDatabaseAttached && !clipboardMainIsCursorData {
		h = append(h, "未挂载 Data/CursorData.db：无法查询 cur.ClipboardHistory")
	}

	dll := filepath.Join(baseDir, "lib", "everything64.dll")
	if _, err := os.Stat(dll); err != nil {
		h = append(h, "未找到 lib/everything64.dll，Everything 文件索引不可用")
	} else if resolveEverythingExe(baseDir) == "" {
		h = append(h, "未检测到 Everything.exe，请安装 voidtools Everything")
	}

	ft := GetStatus()
	if ft.Running && !ft.Ready {
		h = append(h, "全文索引构建中，可访问 /v1/fulltext/status 查看进度")
	}
	if ft.NeedUserIndexDir {
		h = append(h, "建议设置 SEARCHCENTER_FT_INDEX_DIR 到独立目录")
	}
	if ft.LowDisk {
		h = append(h, "磁盘可用空间低于 500MB，全文索引写入已暂停")
	}

	h = append(h, "诊断：GET http://127.0.0.1:8080/v1/status")
	return h
}
