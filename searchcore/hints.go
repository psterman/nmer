package main

import (
	"os"
	"path/filepath"
)

// buildSearchResultHints 在无命中时给出可操作的诊断提示（微型搜索服务可观测性）
func buildSearchResultHints(baseDir string, itemCount int, query string) []string {
	if itemCount > 0 || query == "" {
		return nil
	}
	var h []string
	if !curDatabaseAttached && !clipboardMainIsCursorData {
		h = append(h, "未挂载 Data/CursorData.db：无法使用 cur.ClipboardHistory（主库已为 Clipboard.db 时）")
	}
	dll := filepath.Join(baseDir, "lib", "everything64.dll")
	if _, err := os.Stat(dll); err != nil {
		h = append(h, "未找到 lib/everything64.dll，Everything 文件索引不可用")
	} else if resolveEverythingExe(baseDir) == "" {
		h = append(h, "未检测到 Everything.exe，请安装 voidtools Everything 或将 Everything64.exe 放在脚本目录")
	}
	h = append(h, "诊断：浏览器或命令行访问 GET http://127.0.0.1:8080/v1/status")
	return h
}
