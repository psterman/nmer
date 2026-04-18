// SearchCenterCore — 搜索中心极速模式：Clipboard.db FTS5 + CursorData.db 回退
package main

import (
	"database/sql"
	"encoding/json"
	"flag"
	"fmt"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"strconv"
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

	http.HandleFunc("/health", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "text/plain; charset=utf-8")
		w.WriteHeader(http.StatusOK)
		_, _ = w.Write([]byte("ok"))
	})
	http.HandleFunc("/search", func(w http.ResponseWriter, r *http.Request) {
		handleSearchWithDB(w, r, db)
	})

	log.Printf("SearchCenterCore listening on http://%s (base=%s)\n", *addr, absBase)
	if err := http.ListenAndServe(*addr, nil); err != nil {
		log.Fatal(err)
	}
}

func openDatabases(absBase string) (*sql.DB, error) {
	clipPath := filepath.Join(absBase, "Clipboard.db")
	clipSlash := filepath.ToSlash(clipPath)
	dsn := "file:" + clipSlash + "?_pragma=busy_timeout(5000)&_pragma=journal_mode(WAL)"
	db, err := sql.Open("sqlite", dsn)
	if err != nil {
		return nil, err
	}
	if err := db.Ping(); err != nil {
		_ = db.Close()
		return nil, fmt.Errorf("open Clipboard.db: %w", err)
	}

	curPath := filepath.Join(absBase, "Data", "CursorData.db")
	curPath = filepath.ToSlash(curPath)
	attachSQL := fmt.Sprintf(`ATTACH DATABASE '%s' AS cur`, escapeSQLString(curPath))
	if _, err := db.Exec(attachSQL); err != nil {
		_ = db.Close()
		return nil, fmt.Errorf("attach CursorData.db: %w", err)
	}
	return db, nil
}

func escapeSQLString(s string) string {
	return strings.ReplaceAll(s, "'", "''")
}

func handleSearchWithDB(w http.ResponseWriter, r *http.Request, db *sql.DB) {
	if r.Method != http.MethodGet {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	q := strings.TrimSpace(r.URL.Query().Get("q"))
	typeStr := strings.TrimSpace(r.URL.Query().Get("type"))
	if typeStr == "" {
		typeStr = "all"
	}
	limit := 30
	if v := r.URL.Query().Get("limit"); v != "" {
		if n, err := strconv.Atoi(v); err == nil && n > 0 {
			limit = n
		}
	}
	offset := 0
	if v := r.URL.Query().Get("offset"); v != "" {
		if n, err := strconv.Atoi(v); err == nil && n >= 0 {
			offset = n
		}
	}

	w.Header().Set("Content-Type", "application/json; charset=utf-8")

	if typeStr != "all" && typeStr != "clipboard" {
		_ = json.NewEncoder(w).Encode(searchResponse{
			Items:   []map[string]any{},
			HasMore: false,
			Offset:  offset,
			Limit:   limit,
			Query:   q,
			Type:    typeStr,
		})
		return
	}

	if q == "" {
		_ = json.NewEncoder(w).Encode(searchResponse{
			Items:   []map[string]any{},
			HasMore: false,
			Offset:  offset,
			Limit:   limit,
			Query:   q,
			Type:    typeStr,
		})
		return
	}

	tokens := splitQueryTokens(q)
	if len(tokens) == 0 {
		_ = json.NewEncoder(w).Encode(searchResponse{
			Items:   []map[string]any{},
			HasMore: false,
			Offset:  offset,
			Limit:   limit,
			Query:   q,
			Type:    typeStr,
		})
		return
	}

	items, hasMore, err := searchClipboard(db, tokens, limit, offset)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	_ = json.NewEncoder(w).Encode(searchResponse{
		Items:   items,
		HasMore: hasMore,
		Offset:  offset,
		Limit:   limit,
		Query:   q,
		Type:    typeStr,
	})
}

type searchResponse struct {
	Items   []map[string]any `json:"items"`
	HasMore bool             `json:"hasMore"`
	Offset  int              `json:"offset"`
	Limit   int              `json:"limit"`
	Query   string           `json:"query"`
	Type    string           `json:"type"`
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

// FTS5 MATCH：空格分词 AND；token 转义双引号
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

func searchClipboard(db *sql.DB, tokens []string, limit, offset int) ([]map[string]any, bool, error) {
	match := ftsMatchQuery(tokens)
	fetch := limit + 1

	sqlFTS := `
SELECT rowid AS id, Content, SourceApp, DataType, LastCopyTime, SourcePath,
       CharCount, Timestamp, CopyCount
FROM ClipboardHistory
WHERE ClipboardHistory MATCH ?
ORDER BY COALESCE(LastCopyTime, Timestamp) DESC
LIMIT ? OFFSET ?`

	rows, err := db.Query(sqlFTS, match, fetch, offset)
	if err != nil {
		// FTS 不可用或表不存在时回退仅 legacy
		return searchLegacyOnly(db, tokens, limit, offset)
	}
	defer rows.Close()

	var items []map[string]any
	for rows.Next() {
		var id int64
		var content, sourceApp, dataType sql.NullString
		var lastCopyTime, timestamp sql.NullString
		var sourcePath sql.NullString
		var charCount, copyCount sql.NullInt64

		if err := rows.Scan(&id, &content, &sourceApp, &dataType, &lastCopyTime, &sourcePath, &charCount, &timestamp, &copyCount); err != nil {
			continue
		}
		items = append(items, buildClipItem(id, content, sourceApp, dataType, lastCopyTime, sourcePath, charCount, timestamp, copyCount))
	}
	_ = rows.Err()

	if len(items) == 0 {
		return searchLegacyOnly(db, tokens, limit, offset)
	}

	hasMore := len(items) > limit
	if hasMore {
		items = items[:limit]
	}
	return items, hasMore, nil
}

func searchLegacyOnly(db *sql.DB, tokens []string, limit, offset int) ([]map[string]any, bool, error) {
	fetch := limit + 1
	where, args := legacyWhereClause(tokens)
	if where == "" {
		return nil, false, nil
	}
	q := `
SELECT ID, Content, SourceApp, SourceTitle, SourcePath, DataType, Timestamp, CharCount, WordCount
FROM cur.ClipboardHistory
WHERE ` + where + `
ORDER BY Timestamp DESC
LIMIT ? OFFSET ?`
	args = append(args, fetch, offset)

	rows, err := db.Query(q, args...)
	if err != nil {
		return nil, false, err
	}
	defer rows.Close()

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
	hasMore := len(items) > limit
	if hasMore {
		items = items[:limit]
	}
	return items, hasMore, rows.Err()
}

func legacyWhereClause(tokens []string) (string, []any) {
	if len(tokens) == 0 {
		return "", nil
	}
	var parts []string
	var args []any
	for _, tok := range tokens {
		pat := "%" + strings.ToLower(tok) + "%"
		part := `(LOWER(COALESCE(Content,'')) LIKE ? OR LOWER(COALESCE(SourceApp,'')) LIKE ? OR ` +
			`LOWER(COALESCE(SourceTitle,'')) LIKE ? OR LOWER(COALESCE(SourcePath,'')) LIKE ? OR ` +
			`LOWER(COALESCE(DataType,'')) LIKE ?)`
		parts = append(parts, part)
		for range 5 {
			args = append(args, pat)
		}
	}
	return strings.Join(parts, " AND "), args
}

func buildClipItem(id int64, content, sourceApp, dataType sql.NullString, lastCopyTime, sourcePath sql.NullString, charCount sql.NullInt64, timestamp sql.NullString, copyCount sql.NullInt64) map[string]any {
	c := nv(content)
	sa := nv(sourceApp)
	dt := nv(dataType)
	sp := nv(sourcePath)
	ts := nv(timestamp)
	lct := nv(lastCopyTime)
	if lct == "" {
		lct = ts
	}
	cc := intFromNull(charCount)
	cp := intFromNull(copyCount)
	if cp <= 0 {
		cp = 1
	}

	preview := c
	runes := []rune(preview)
	if len(runes) > 100 {
		preview = string(runes[:100]) + "..."
	}

	timeFormatted := formatTimeDisplay(lct, ts)

	titlePrefix, displayName := emojiAndName(dt)
	displayTitle := titlePrefix + preview

	subTitle := buildSubTitle(sa, cc, timeFormatted)

	meta := map[string]any{
		"SourceApp":     sa,
		"SourcePath":    sp,
		"DataType":      dt,
		"Timestamp":     ts,
		"TimeFormatted": timeFormatted,
		"CharCount":     cc,
		"CopyCount":     cp,
	}

	return map[string]any{
		"DataType":     "clipboard",
		"DataTypeName": displayName,
		"ID":           id,
		"Title":        displayTitle,
		"SubTitle":     subTitle,
		"Content":      c,
		"Preview":      preview,
		"Time":         timeFormatted,
		"TimeFormatted": timeFormatted,
		"Timestamp":    lct,
		"Source":       displayName,
		"Metadata":     meta,
	}
}

func buildLegacyClipItem(id int64, content, sourceApp, sourceTitle, sourcePath, dataType, timestamp sql.NullString, charCount, wordCount sql.NullInt64) map[string]any {
	c := nv(content)
	sa := nv(sourceApp)
	st := nv(sourceTitle)
	sp := nv(sourcePath)
	dt := nv(dataType)
	ts := nv(timestamp)
	cc := intFromNull(charCount)
	wc := intFromNull(wordCount)

	preview := c
	runes := []rune(preview)
	if len(runes) > 100 {
		preview = string(runes[:100]) + "..."
	}
	timeFormatted := formatTimeDisplay(ts, ts)

	titlePrefix, displayName := emojiAndName(dt)
	displayTitle := titlePrefix + preview

	subTitle := ""
	if sa != "" {
		subTitle = "来自: " + sa
	}
	if cc > 0 {
		if subTitle != "" {
			subTitle += " | 字数: " + strconv.Itoa(cc)
		} else {
			subTitle = "字数: " + strconv.Itoa(cc)
		}
	}
	if subTitle != "" {
		subTitle += " · " + timeFormatted
	} else {
		subTitle = timeFormatted
	}

	meta := map[string]any{
		"SourceApp":     sa,
		"SourceTitle":   st,
		"SourcePath":    sp,
		"DataType":      dt,
		"Timestamp":     ts,
		"TimeFormatted": timeFormatted,
		"CharCount":     cc,
		"WordCount":     wc,
	}

	return map[string]any{
		"DataType":     "clipboard",
		"DataTypeName": displayName,
		"ID":           id,
		"Title":        displayTitle,
		"SubTitle":     subTitle,
		"Content":      c,
		"Preview":      preview,
		"Time":         timeFormatted,
		"TimeFormatted": timeFormatted,
		"Timestamp":    ts,
		"Source":       displayName,
		"Metadata":     meta,
		"Action":       "copy_to_clipboard",
		"ActionParams": map[string]any{"ID": id, "Content": c},
	}
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
			sub += " | 字数: " + strconv.Itoa(charCount)
		} else {
			sub = "字数: " + strconv.Itoa(charCount)
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
