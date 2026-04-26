package main

import (
	"database/sql"
	"log"
	"strconv"
	"strings"
	"unicode"
	"unicode/utf8"
)

func detectClipboardFTS(db *sql.DB) (table string, useFTS bool) {
	var name string
	err := db.QueryRow(`SELECT name FROM sqlite_master WHERE type='table' AND name='ClipboardHistory'`).Scan(&name)
	if err != nil || name == "" {
		return "", false
	}
	var sql string
	_ = db.QueryRow(`SELECT sql FROM sqlite_master WHERE type='table' AND name='ClipboardHistory'`).Scan(&sql)
	if strings.Contains(strings.ToUpper(sql), "USING FTS5") {
		return "ClipboardHistory", true
	}
	return "ClipboardHistory", false
}

func detectClipMain(db *sql.DB) bool {
	var n string
	err := db.QueryRow(`SELECT name FROM sqlite_master WHERE type='table' AND name='ClipMain'`).Scan(&n)
	return err == nil && n != ""
}

// 与 AHK ClipboardPanelCore：关键词长度 <=2 或含非「单词」字符时走 LIKE，避免 FTS5 对短词/数字不友好。
func clipboardUseLikeInsteadOfFTS(rawQuery string) bool {
	s := strings.TrimSpace(rawQuery)
	if s == "" {
		return true
	}
	if utf8.RuneCountInString(s) <= 2 {
		return true
	}
	for _, r := range s {
		if r > unicode.MaxASCII || strings.ContainsRune(`"'():-^*%_`, r) {
			return true
		}
	}
	return false
}

// searchClipboardAfterClipMain：主库 ClipboardHistory（FTS/LIKE）+ cur.ClipboardHistory（legacy），与 AHK 在 ClipMain 无命中后的路径一致。
func searchClipboardAfterClipMain(db *sql.DB, rawQuery string, tokens []string, limit, offset int) ([]map[string]any, bool, error) {
	_, fts := detectClipboardFTS(db)
	useLike := clipboardUseLikeInsteadOfFTS(rawQuery)
	if fts && !useLike {
		return searchClipboardFTS5(db, tokens, limit, offset)
	}
	items, hasMore, err := searchLegacyOnly(db, tokens, limit, offset)
	if err != nil {
		return nil, false, err
	}
	if len(items) > 0 || !fts || !useLike {
		return items, hasMore, nil
	}
	// Some deployments keep ClipboardHistory as FTS virtual table where LIKE can be ineffective.
	// For short queries (<=2) align with AHK's fuzzy expectation by falling back to FTS prefix match.
	return searchClipboardFTS5Prefix(db, tokens, limit, offset)
}

func searchClipboard(db *sql.DB, rawQuery string, tokens []string, limit, offset int) ([]map[string]any, bool, error) {
	// 与 AHK SearchClipboardHistory：主库 ClipMain 先搜；无命中再搜 ATTACH 的 cur.ClipMain（真实数据常在 Data\CursorData.db）
	if detectClipMain(db) {
		items, hm, err := searchClipMainLikeOn(db, "ClipMain", tokens, limit, offset)
		if err != nil {
			return nil, false, err
		}
		if len(items) > 0 {
			return items, hm, nil
		}
	}
	if curDatabaseAttached && tableExistsInAttached(db, "cur", "ClipMain") {
		items, hm, err := searchClipMainLikeOn(db, "cur.ClipMain", tokens, limit, offset)
		if err != nil {
			return nil, false, err
		}
		if len(items) > 0 {
			log.Printf("[search] ClipMain 命中 %s（%d 条）", "cur.ClipMain", len(items))
			return items, hm, nil
		}
	}
	return searchClipboardAfterClipMain(db, rawQuery, tokens, limit, offset)
}

func searchClipboardFTS5(db *sql.DB, tokens []string, limit, offset int) ([]map[string]any, bool, error) {
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

func ftsPrefixMatchQuery(tokens []string) string {
	var parts []string
	for _, t := range tokens {
		esc := strings.ReplaceAll(t, `"`, `""`)
		if needsFtsQuote(t) {
			parts = append(parts, `"`+esc+`"*`)
		} else {
			parts = append(parts, esc+"*")
		}
	}
	return strings.Join(parts, " AND ")
}

func searchClipboardFTS5Prefix(db *sql.DB, tokens []string, limit, offset int) ([]map[string]any, bool, error) {
	match := ftsPrefixMatchQuery(tokens)
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
		return nil, false, err
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
	if err := rows.Err(); err != nil {
		return nil, false, err
	}
	hasMore := len(items) > limit
	if hasMore {
		items = items[:limit]
	}
	return items, hasMore, nil
}

// clipMainLikeWhere 与 legacyWhereClause 一致：每个关键词一段 (Content OR SourceApp [OR SourcePath] OR 时间列)，多词之间 AND。
func clipMainLikeWhere(tokens []string, hasSP, hasLCT bool) (string, []any) {
	if len(tokens) == 0 {
		return "", nil
	}
	var parts []string
	var args []any
	for _, tok := range tokens {
		pat := "%" + strings.ToLower(tok) + "%"
		seg := `(LOWER(COALESCE(Content,'')) LIKE ? OR LOWER(COALESCE(SourceApp,'')) LIKE ?`
		args = append(args, pat, pat)
		if hasSP {
			seg += ` OR LOWER(COALESCE(SourcePath,'')) LIKE ?`
			args = append(args, pat)
		}
		seg += ` OR LOWER(COALESCE(Timestamp,'')) LIKE ?`
		args = append(args, pat)
		if hasLCT {
			seg += ` OR LOWER(COALESCE(LastCopyTime,'')) LIKE ?`
			args = append(args, pat)
		}
		seg += ")"
		parts = append(parts, seg)
	}
	return strings.Join(parts, " AND "), args
}

// tableExistsInAttached 查询 ATTACH 库（如 cur）内是否存在某表；用于在 cur 上搜 ClipMain，避免只查主库导致永远 0 条。
func tableExistsInAttached(db *sql.DB, alias, baseName string) bool {
	var n string
	q := `SELECT name FROM ` + alias + `.sqlite_master WHERE type IN ('table','view') AND name=? LIMIT 1`
	err := db.QueryRow(q, baseName).Scan(&n)
	return err == nil && n != ""
}

func searchClipMainLikeOn(db *sql.DB, fromTable string, tokens []string, limit, offset int) ([]map[string]any, bool, error) {
	if len(tokens) == 0 {
		return nil, false, nil
	}
	fetch := limit + 1

	hasLCT, hasCC, hasSP := clipMainColumnsForTable(db, fromTable)
	selectFields := "ID, Content, SourceApp, DataType, CharCount, Timestamp"
	if hasSP {
		selectFields += ", SourcePath"
	} else {
		selectFields += ", '' AS SourcePath"
	}
	if hasLCT {
		selectFields += ", LastCopyTime"
	} else {
		selectFields += ", Timestamp AS LastCopyTime"
	}
	if hasCC {
		selectFields += ", CopyCount"
	} else {
		selectFields += ", 1 AS CopyCount"
	}
	orderCol := "LastCopyTime"
	if !hasLCT {
		orderCol = "Timestamp"
	}
	whereSQL, whereArgs := clipMainLikeWhere(tokens, hasSP, hasLCT)
	if whereSQL == "" {
		return nil, false, nil
	}
	q := `SELECT ` + selectFields + ` FROM ` + fromTable + ` WHERE ` + whereSQL + ` ORDER BY ` + orderCol + ` DESC LIMIT ? OFFSET ?`
	args := append(whereArgs, fetch, offset)
	rows, err := db.Query(q, args...)
	if err != nil {
		return searchClipboardFTS5(db, tokens, limit, offset)
	}
	defer rows.Close()
	var items []map[string]any
	for rows.Next() {
		cols, _ := rows.Columns()
		vals := make([]any, len(cols))
		ptrs := make([]any, len(cols))
		for i := range vals {
			ptrs[i] = &vals[i]
		}
		if err := rows.Scan(ptrs...); err != nil {
			continue
		}
		m := map[string]any{}
		for i, c := range cols {
			m[c] = vals[i]
		}
		id := toInt64(m["ID"])
		content := nullStr(m["Content"])
		sourceApp := nullStr(m["SourceApp"])
		dt := nullStr(m["DataType"])
		ts := nullStr(m["Timestamp"])
		sp := nullStr(m["SourcePath"])
		lct := nullStr(m["LastCopyTime"])
		cc := toInt(m["CharCount"])
		cp := toInt(m["CopyCount"])
		items = append(items, buildClipItemFromStrings(id, content, sourceApp, dt, lct, sp, cc, ts, cp))
	}
	hasMore := len(items) > limit
	if hasMore {
		items = items[:limit]
	}
	return items, hasMore, nil
}

func clipMainPragmaSQL(fromTable string) string {
	schema, base := splitSchemaTable(fromTable)
	if schema == "" {
		return `PRAGMA table_info(` + base + `)`
	}
	return `PRAGMA ` + schema + `.table_info(` + base + `)`
}

func splitSchemaTable(fromTable string) (schema, base string) {
	i := strings.Index(fromTable, ".")
	if i <= 0 {
		return "", fromTable
	}
	return fromTable[:i], fromTable[i+1:]
}

func clipMainColumnsForTable(db *sql.DB, fromTable string) (hasLCT, hasCC, hasSP bool) {
	rows, err := db.Query(clipMainPragmaSQL(fromTable))
	if err != nil {
		return false, false, false
	}
	defer rows.Close()
	for rows.Next() {
		var cid int
		var name, ctype string
		var notnull, pk int
		var dflt sql.NullString
		if err := rows.Scan(&cid, &name, &ctype, &notnull, &dflt, &pk); err != nil {
			continue
		}
		switch strings.ToLower(name) {
		case "lastcopytime":
			hasLCT = true
		case "copycount":
			hasCC = true
		case "sourcepath":
			hasSP = true
		}
	}
	return
}

func nullStr(v any) string {
	if v == nil {
		return ""
	}
	switch t := v.(type) {
	case string:
		return t
	case []byte:
		return string(t)
	default:
		return ""
	}
}

func toInt64(v any) int64 {
	switch t := v.(type) {
	case int64:
		return t
	case int:
		return int64(t)
	case float64:
		return int64(t)
	case []byte:
		i, _ := strconv.ParseInt(string(t), 10, 64)
		return i
	default:
		return 0
	}
}

func toInt(v any) int {
	return int(toInt64(v))
}

func buildClipItemFromStrings(id int64, content, sourceApp, dataType, lastCopyTime, sourcePath string, charCount int, timestamp string, copyCount int) map[string]any {
	c := content
	sa := sourceApp
	dt := dataType
	sp := sourcePath
	ts := timestamp
	lct := lastCopyTime
	if lct == "" {
		lct = ts
	}
	cc := charCount
	cp := copyCount
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
		"originalDataType": "clipboard",
		"DataType":         "clipboard",
		"DataTypeName":     displayName,
		"ID":               id,
		"Title":            displayTitle,
		"SubTitle":         subTitle,
		"Content":          c,
		"Preview":          preview,
		"Time":             timeFormatted,
		"TimeFormatted":    timeFormatted,
		"Timestamp":        lct,
		"Source":           displayName,
		"Metadata":         meta,
	}
}

func buildClipItem(id int64, content, sourceApp, dataType sql.NullString, lastCopyTime, sourcePath sql.NullString, charCount sql.NullInt64, timestamp sql.NullString, copyCount sql.NullInt64) map[string]any {
	return buildClipItemFromStrings(id, nv(content), nv(sourceApp), nv(dataType), nv(lastCopyTime), nv(sourcePath), intFromNull(charCount), nv(timestamp), intFromNull(copyCount))
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
		"originalDataType": "clipboard",
		"DataType":         "clipboard",
		"DataTypeName":     displayName,
		"ID":               id,
		"Title":            displayTitle,
		"SubTitle":         subTitle,
		"Content":          c,
		"Preview":          preview,
		"Time":             timeFormatted,
		"TimeFormatted":    timeFormatted,
		"Timestamp":        ts,
		"Source":           displayName,
		"Metadata":         meta,
		"Action":           "copy_to_clipboard",
		"ActionParams":     map[string]any{"ID": id, "Content": c},
	}
}

// ftsMatchQuery / needsFtsQuote 保留在 SearchCenterCore.go 或移入 — 已在主文件定义，此处复用包内同名函数

func needsFtsQuoteLocal(s string) bool {
	for _, r := range s {
		if unicode.IsSpace(r) || strings.ContainsRune(`"'():-^*`, r) {
			return true
		}
	}
	return false
}
