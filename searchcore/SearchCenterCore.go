// SearchCenterCore — 搜索中心极速模式（Go HTTP 聚合）
package main

import (
	"database/sql"
	"flag"
	"fmt"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"unicode"

	_ "modernc.org/sqlite"
)

const defaultAddr = "127.0.0.1:8080"

func main() {
	baseDir := flag.String("base", "", "主脚本目录（含 Clipboard.db、Data/CursorData.db）")
	addr := flag.String("addr", defaultAddr, "监听地址")
	flag.Parse()
	b := strings.TrimSpace(*baseDir)
	if b == "" {
		b = strings.TrimSpace(os.Getenv("CURSORHELPER_DIR"))
	}
	if b == "" {
		log.Fatal("必须指定 -base 或环境变量 CURSORHELPER_DIR")
	}
	absBase, err := filepath.Abs(b)
	if err != nil {
		log.Fatal(err)
	}

	db, err := openDatabases(absBase)
	if err != nil {
		log.Fatal(err)
	}
	defer db.Close()

	if err := StartIndexer(absBase); err != nil {
		log.Printf("[fulltext] StartIndexer failed: %v", err)
	}

	clipHTTPBase = clipHTTPBaseFromAddr(*addr)

	http.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "text/plain; charset=utf-8")
		w.Header().Set("X-SearchCenterCore", "1")
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("ok"))
	})
	http.HandleFunc("/search", func(w http.ResponseWriter, r *http.Request) {
		handleSearchWithDB(w, r, db, absBase)
	})
	statusH := func(w http.ResponseWriter, r *http.Request) {
		handleStatus(w, r, db, absBase)
	}
	http.HandleFunc("/v1/status", statusH)
	http.HandleFunc("/status", statusH)
	// 浏览器或代理若自动加了尾部斜杠，默认 ServeMux 不会匹配 /v1/status
	http.HandleFunc("/v1/status/", func(w http.ResponseWriter, r *http.Request) {
		http.Redirect(w, r, "/v1/status", http.StatusTemporaryRedirect)
	})
	http.HandleFunc("/v1/fulltext/status", handleFullTextStatus)
	http.HandleFunc("/v1/fulltext/progress", handleFullTextProgress)
	http.HandleFunc("/v1/fulltext/progress/stream", handleFullTextProgressStream)
	http.HandleFunc("/clip/search", func(w http.ResponseWriter, r *http.Request) {
		handleClipSearch(w, r, db)
	})
	http.HandleFunc("/clip/preview", func(w http.ResponseWriter, r *http.Request) {
		handleClipPreview(w, r, db, absBase)
	})

	log.Printf("SearchCenterCore listening on http://%s (base=%s) routes: /health /search /clip/search /clip/preview /v1/status /status /v1/fulltext/status /v1/fulltext/progress /v1/fulltext/progress/stream\n", *addr, absBase)
	if err := http.ListenAndServe(*addr, nil); err != nil {
		log.Fatal(err)
	}
}

// pickPrimaryClipboardPath 与 AHK 一致：ClipboardDB 实际使用 Data\CursorData.db；
// 若根目录 Clipboard.db 缺失或 0 字节（曾被误建空库），必须以 CursorData.db 为主连接，否则会搜不到任何行。
func pickPrimaryClipboardPath(absBase string) (mainPath string, attachCurPath string, err error) {
	clipPath := filepath.Join(absBase, "Clipboard.db")
	curPath := filepath.Join(absBase, "Data", "CursorData.db")
	stClip, errClip := os.Stat(clipPath)
	stCur, errCur := os.Stat(curPath)
	clipOK := errClip == nil && !stClip.IsDir() && stClip.Size() > 0
	curOK := errCur == nil && !stCur.IsDir() && stCur.Size() > 0
	if !clipOK && !curOK {
		return "", "", fmt.Errorf("未找到有效剪贴板库：需要非空 Clipboard.db 或 Data\\CursorData.db（base=%s）", absBase)
	}
	if clipOK {
		mainPath = clipPath
		if curOK {
			attachCurPath = curPath
		}
		return mainPath, attachCurPath, nil
	}
	mainPath = curPath
	log.Printf("[db] Clipboard.db 不存在或为空文件，主库改为 Data\\CursorData.db（与 AHK ClipboardDB 路径一致）")
	return mainPath, "", nil
}

func openDatabases(absBase string) (*sql.DB, error) {
	mainPath, attachCur, err := pickPrimaryClipboardPath(absBase)
	if err != nil {
		return nil, err
	}
	mainSlash := filepath.ToSlash(mainPath)
	dsn := "file:" + mainSlash + "?_pragma=busy_timeout(5000)&_pragma=journal_mode(WAL)"
	db, err := sql.Open("sqlite", dsn)
	if err != nil {
		return nil, err
	}
	if err := db.Ping(); err != nil {
		_ = db.Close()
		return nil, fmt.Errorf("open clipboard db %s: %w", mainPath, err)
	}

	clipboardMainIsCursorData = strings.EqualFold(filepath.Base(mainPath), "CursorData.db")
	curDatabaseAttached = false
	if attachCur != "" {
		curSlash := filepath.ToSlash(attachCur)
		attachSQL := fmt.Sprintf(`ATTACH DATABASE '%s' AS cur`, escapeSQLString(curSlash))
		if _, err := db.Exec(attachSQL); err != nil {
			log.Printf("[db] ATTACH CursorData.db 失败: %v", err)
		} else {
			curDatabaseAttached = true
			log.Printf("[db] ATTACH CursorData.db 成功")
		}
	} else if filepath.Base(mainPath) == "Clipboard.db" {
		log.Printf("[db] 未同时存在可用的 Data\\CursorData.db，legacy 仅查主库 ClipboardHistory")
	}
	return db, nil
}

func escapeSQLString(s string) string {
	return strings.ReplaceAll(s, "'", "''")
}

type searchResponse struct {
	Items   []map[string]any `json:"items"`
	HasMore bool             `json:"hasMore"`
	Offset  int              `json:"offset"`
	Limit   int              `json:"limit"`
	Query   string           `json:"query"`
	Type    string           `json:"type"`
	Hints   []string         `json:"hints,omitempty"`
}

func splitQueryTokens(q string) []string {
	var out []string
	for _, f := range strings.Fields(q) {
		t := strings.TrimSpace(f)
		if t != "" {
			out = append(out, t)
		}
	}
	return out
}

func ftsMatchQuery(tokens []string) string {
	var parts []string
	for _, t := range tokens {
		esc := strings.ReplaceAll(t, `"`, `""`)
		if needsFtsQuote(t) {
			parts = append(parts, `"`+esc+`"`)
		} else {
			parts = append(parts, esc)
		}
	}
	return strings.Join(parts, " AND ")
}

func needsFtsQuote(s string) bool {
	for _, r := range s {
		if unicode.IsSpace(r) || strings.ContainsRune(`"'():-^*`, r) {
			return true
		}
	}
	return false
}

func scanLegacyClipboardRows(rows *sql.Rows) ([]map[string]any, error) {
	var items []map[string]any
	for rows.Next() {
		var id int64
		var content, sourceApp, sourceTitle, sourcePath, dataType, timestamp sql.NullString
		var charCount, wordCount sql.NullInt64
		if err := rows.Scan(&id, &content, &sourceApp, &sourceTitle, &sourcePath, &dataType, &timestamp, &charCount, &wordCount); err != nil {
			continue
		}
		items = append(items, buildLegacyClipItem(id, content, sourceApp, sourceTitle, sourcePath, dataType, timestamp, charCount, wordCount))
	}
	return items, rows.Err()
}

// legacyClipboardSelectSQLs 生成多组 SQL：主库 ClipboardHistory 可能是普通表或 FTS5 影子表，列名/主键与 AHK 不完全一致时单列失败会导致「永远 0 条」。
func legacyClipboardSelectSQLs(tbl, where string) []string {
	// tbl 仅来自白名单：cur.ClipboardHistory 或 ClipboardHistory
	orderVariants := []string{
		"ORDER BY Timestamp DESC",
		"ORDER BY COALESCE(LastCopyTime, Timestamp) DESC",
	}
	selVariants := []string{
		"SELECT ID, Content, SourceApp, SourceTitle, SourcePath, DataType, Timestamp, CharCount, WordCount",
		"SELECT rowid AS ID, Content, SourceApp, SourceTitle, SourcePath, DataType, Timestamp, CharCount, 0 AS WordCount",
		"SELECT rowid AS ID, Content, IFNULL(SourceApp,'') AS SourceApp, IFNULL(SourceTitle,'') AS SourceTitle, IFNULL(SourcePath,'') AS SourcePath, DataType, Timestamp, IFNULL(CharCount,0) AS CharCount, 0 AS WordCount",
	}
	var out []string
	for _, sel := range selVariants {
		for _, ob := range orderVariants {
			out = append(out, fmt.Sprintf("%s FROM %s WHERE %s %s LIMIT ? OFFSET ?", sel, tbl, where, ob))
		}
	}
	return out
}

// searchLegacyOnly 依次尝试 cur.ClipboardHistory（若已 ATTACH）与主库 ClipboardHistory，与 AHK 多库场景对齐。
func searchLegacyOnly(db *sql.DB, tokens []string, limit, offset int) ([]map[string]any, bool, error) {
	fetch := limit + 1
	where, baseArgs := legacyWhereClause(tokens)
	if where == "" {
		return nil, false, nil
	}
	var candidates []string
	if curDatabaseAttached {
		candidates = append(candidates, "cur.ClipboardHistory")
	}
	if tableNameExists(db, "ClipboardHistory") {
		candidates = append(candidates, "ClipboardHistory")
	}
	for _, tbl := range candidates {
		for _, q := range legacyClipboardSelectSQLs(tbl, where) {
			args := append(append([]any{}, baseArgs...), fetch, offset)
			rows, err := db.Query(q, args...)
			if err != nil {
				continue
			}
			items, scanErr := scanLegacyClipboardRows(rows)
			_ = rows.Close()
			if scanErr != nil {
				continue
			}
			if len(items) == 0 {
				continue
			}
			hasMore := len(items) > limit
			if hasMore {
				items = items[:limit]
			}
			log.Printf("[search] legacy 命中表 %s（%d 条）", tbl, len(items))
			return items, hasMore, nil
		}
		log.Printf("[search] legacy 表 %s 全部 SQL 变体失败或 0 行", tbl)
	}
	return nil, false, nil
}

func legacyWhereClause(tokens []string) (string, []any) {
	if len(tokens) == 0 {
		return "", nil
	}
	var parts []string
	var args []any
	for _, tok := range tokens {
		pat := "%" + strings.ToLower(tok) + "%"
		// 日期时间串（如 2024-04-13）含数字，需可搜；与 AHK 短词走 LIKE 的行为对齐
		part := `(LOWER(COALESCE(Content,'')) LIKE ? OR LOWER(COALESCE(SourceApp,'')) LIKE ? OR ` +
			`LOWER(COALESCE(SourceTitle,'')) LIKE ? OR LOWER(COALESCE(SourcePath,'')) LIKE ? OR ` +
			`LOWER(COALESCE(DataType,'')) LIKE ? OR LOWER(COALESCE(Timestamp,'')) LIKE ?)`
		parts = append(parts, part)
		for range 6 {
			args = append(args, pat)
		}
	}
	return strings.Join(parts, " AND "), args
}

func nv(s sql.NullString) string {
	if s.Valid {
		return s.String
	}
	return ""
}

func intFromNull(n sql.NullInt64) int {
	if n.Valid {
		return int(n.Int64)
	}
	return 0
}

func formatTimeDisplay(primary, fallback string) string {
	s := primary
	if s == "" {
		s = fallback
	}
	return s
}

func buildSubTitle(sourceApp string, charCount int, timeFormatted string) string {
	sub := ""
	if sourceApp != "" {
		sub = "来自: " + sourceApp
	}
	if charCount > 0 {
		if sub != "" {
			sub += " | 字数: " + fmt.Sprintf("%d", charCount)
		} else {
			sub = "字数: " + fmt.Sprintf("%d", charCount)
		}
	}
	if sub != "" {
		sub += " · " + timeFormatted
	} else {
		sub = timeFormatted
	}
	return sub
}

func emojiAndName(dataType string) (prefix string, displayName string) {
	switch dataType {
	case "Code":
		return "💻 [代码] ", "代码片段"
	case "Link":
		return "🔗 [链接] ", "链接"
	case "Email":
		return "📧 [邮件] ", "邮箱"
	case "Image":
		return "🖼️ [图片] ", "图片"
	case "Color":
		return "🎨 [颜色] ", "颜色"
	case "Text":
		return "📝 [文本] ", "文本"
	case "File":
		return "📄 [文件] ", "文件"
	default:
		return "📝 [文本] ", "剪贴板历史"
	}
}
