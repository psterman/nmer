package main

import (
	"bytes"
	"database/sql"
	"encoding/json"
	"fmt"
	"image"
	"image/jpeg"
	"image/png"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
	"sync"
	"time"
	"unicode"
	"unicode/utf8"

	"github.com/eringen/gowebper"
	"github.com/mozillazg/go-pinyin"
	"golang.org/x/image/draw"
	xwebp "golang.org/x/image/webp"
)

// clipHTTPBase 由 main 设置，用于 items 内 previewUrl（如 http://127.0.0.1:8080）
var clipHTTPBase string

func clipHTTPBaseFromAddr(addr string) string {
	addr = strings.TrimSpace(addr)
	if addr == "" {
		addr = "127.0.0.1:8080"
	}
	if strings.HasPrefix(addr, ":") {
		addr = "127.0.0.1" + addr
	}
	return "http://" + addr
}

var (
	clipPinyinOnce sync.Once
	pinyinColumnOnce sync.Map
)

type clipPanelResponse struct {
	Type        string          `json:"type"`
	Items       []clipPanelItem `json:"items"`
	Total       int             `json:"total"`
	HasMore     bool            `json:"hasMore"`
	EngineMode  string          `json:"engineMode"`
	Offset      int             `json:"offset,omitempty"`
	Limit       int             `json:"limit,omitempty"`
}

type clipPanelItem struct {
	ID              int64  `json:"id"`
	Content         string `json:"content"`
	SourceApp       string `json:"sourceApp"`
	DataType        string `json:"dataType"`
	CharCount       int    `json:"charCount"`
	SortTime        string `json:"sortTime"`
	Timestamp       string `json:"timestamp"`
	ImagePath       string `json:"imagePath"`
	IsFavorite      int    `json:"isFavorite"`
	IconPath        string `json:"iconPath"`
	SourcePath      string `json:"sourcePath"`
	ImageDataURL    string `json:"imageDataUrl"`
	ThumbDataURL    string `json:"thumbDataUrl"`
	ThumbVirtualURL string `json:"thumbVirtualUrl"`
	ImageWidth      int    `json:"imageWidth"`
	ImageHeight     int    `json:"imageHeight"`
	FileSize        int    `json:"fileSize"`
	PreviewURL      string `json:"previewUrl,omitempty"`
	dbSrc           string `json:"-"`
}

func handleClipSearch(w http.ResponseWriter, r *http.Request, db *sql.DB) {
	if r.Method != http.MethodGet {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	q := strings.TrimSpace(r.URL.Query().Get("keyword"))
	if q == "" {
		q = strings.TrimSpace(r.URL.Query().Get("q"))
	}
	filterType := strings.ToLower(strings.TrimSpace(r.URL.Query().Get("type")))
	if filterType == "" {
		filterType = "all"
	}
	timeRange := normalizeClipTimeRange(r.URL.Query().Get("timeRange"))
	msgType := strings.TrimSpace(r.URL.Query().Get("msgType"))
	if msgType == "" {
		msgType = "searchResult"
	}
	limit := 30
	if v := r.URL.Query().Get("limit"); v != "" {
		if n, err := strconv.Atoi(v); err == nil && n > 0 && n <= 5000 {
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

	if !tableNameExists(db, "ClipMain") && !(curDatabaseAttached && tableExistsInAttached(db, "cur", "ClipMain")) {
		_ = json.NewEncoder(w).Encode(clipPanelResponse{Type: msgType, Items: nil, Total: 0, HasMore: false, EngineMode: "go", Offset: offset, Limit: limit})
		return
	}

	ensureClipPinyinColumns(db)

	items, total, err := clipPanelSearch(db, q, filterType, timeRange, offset, limit)
	if err != nil {
		log.Printf("[clip/search] %v", err)
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	hasMore := offset+len(items) < total
	for i := range items {
		dt := strings.ToLower(items[i].DataType)
		ip := strings.TrimSpace(items[i].ImagePath)
		if dt == "image" || dt == "screenshot" || (ip != "" && !strings.HasPrefix(strings.ToLower(ip), "http")) {
			items[i].PreviewURL = clipPreviewURL(items[i].ID, items[i].dbSrc)
		}
		items[i].dbSrc = ""
	}

	resp := clipPanelResponse{
		Type:       msgType,
		Items:      items,
		Total:      total,
		HasMore:    hasMore,
		EngineMode: "go",
		Offset:     offset,
		Limit:      limit,
	}
	enc := json.NewEncoder(w)
	enc.SetEscapeHTML(true)
	_ = enc.Encode(resp)
}

func clipPreviewURL(id int64, dbSrc string) string {
	if id < 1 || clipHTTPBase == "" {
		return ""
	}
	u := fmt.Sprintf("%s/clip/preview?id=%d", strings.TrimRight(clipHTTPBase, "/"), id)
	if dbSrc == "c" {
		u += "&src=c"
	}
	return u
}

func normalizeClipTimeRange(s string) string {
	s = strings.TrimSpace(strings.ToLower(s))
	if s == "" {
		return "all"
	}
	if s == "all" || s == "day" || s == "week" || s == "month" {
		return s
	}
	if strings.HasPrefix(s, "date:") {
		ds := strings.TrimPrefix(s, "date:")
		if matched, _ := regexp.MatchString(`^\d{4}-\d{2}-\d{2}$`, ds); matched {
			return "date:" + ds
		}
	}
	return "all"
}

func ensureClipPinyinColumns(db *sql.DB) {
	clipPinyinOnce.Do(func() {
		for _, tbl := range []string{"ClipMain", "cur.ClipMain"} {
			if tbl == "cur.ClipMain" && !curDatabaseAttached {
				continue
			}
			if !tableExistsForClip(db, tbl) {
				continue
			}
			if _, loaded := pinyinColumnOnce.LoadOrStore(tbl, true); loaded {
				continue
			}
			if !clipMainHasColumn(db, tbl, "PinyinAbbr") {
				_, err := db.Exec(fmt.Sprintf(`ALTER TABLE %s ADD COLUMN PinyinAbbr TEXT`, tbl))
				if err != nil {
					log.Printf("[clip] ALTER PinyinAbbr %s: %v", tbl, err)
				}
			}
		}
		go clipBackfillPinyinLoop(db)
	})
}

func tableExistsForClip(db *sql.DB, fromTable string) bool {
	if strings.HasPrefix(fromTable, "cur.") {
		base := strings.TrimPrefix(fromTable, "cur.")
		return tableExistsInAttached(db, "cur", base)
	}
	return tableNameExists(db, fromTable)
}

func clipMainHasColumn(db *sql.DB, fromTable, col string) bool {
	rows, err := db.Query(clipMainPragmaSQL(fromTable))
	if err != nil {
		return false
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
		if strings.EqualFold(name, col) {
			return true
		}
	}
	return false
}

func clipBackfillPinyinLoop(db *sql.DB) {
	ticker := time.NewTicker(2 * time.Second)
	defer ticker.Stop()
	n := 0
	for range ticker.C {
		if n > 50 {
			return
		}
		did := 0
		for _, tbl := range []string{"ClipMain", "cur.ClipMain"} {
			if tbl == "cur.ClipMain" && !curDatabaseAttached {
				continue
			}
			if !tableExistsForClip(db, tbl) || !clipMainHasColumn(db, tbl, "PinyinAbbr") {
				continue
			}
			rows, err := db.Query(fmt.Sprintf(
				`SELECT ID, COALESCE(Content,''), COALESCE(SourceApp,'') FROM %s WHERE PinyinAbbr IS NULL OR PinyinAbbr = '' LIMIT 80`, tbl))
			if err != nil {
				continue
			}
			for rows.Next() {
				var id int64
				var content, sourceApp string
				if err := rows.Scan(&id, &content, &sourceApp); err != nil {
					continue
				}
				abbr := computePinyinAbbr(content, sourceApp)
				_, _ = db.Exec(fmt.Sprintf(`UPDATE %s SET PinyinAbbr = ? WHERE ID = ?`, tbl), abbr, id)
				did++
			}
			_ = rows.Close()
		}
		if did == 0 {
			return
		}
		n++
	}
}

func computePinyinAbbr(content, sourceApp string) string {
	a := pinyin.NewArgs()
	a.Style = pinyin.FirstLetter
	var b strings.Builder
	writePinyin := func(s string) {
		for _, xs := range pinyin.Pinyin(s, a) {
			for _, t := range xs {
				if t != "" {
					b.WriteString(strings.ToLower(t))
				}
			}
		}
	}
	for _, r := range content {
		if r < unicode.MaxASCII && (unicode.IsLetter(r) || unicode.IsDigit(r)) {
			b.WriteRune(unicode.ToLower(r))
		} else if unicode.Is(unicode.Han, r) {
			writePinyin(string(r))
		}
	}
	for _, r := range sourceApp {
		if r < unicode.MaxASCII && (unicode.IsLetter(r) || unicode.IsDigit(r)) {
			b.WriteRune(unicode.ToLower(r))
		} else if unicode.Is(unicode.Han, r) {
			writePinyin(string(r))
		}
	}
	s := b.String()
	if len(s) > 2048 {
		return s[:2048]
	}
	return s
}

func clipPanelSearch(db *sql.DB, keyword, filterType, timeRange string, offset, limit int) ([]clipPanelItem, int, error) {
	hasMain := tableNameExists(db, "ClipMain")
	hasCur := curDatabaseAttached && tableExistsInAttached(db, "cur", "ClipMain")
	if !hasMain && !hasCur {
		return nil, 0, nil
	}

	hasFTS := false
	if tableNameExists(db, "ClipboardHistory") {
		var sqldef sql.NullString
		_ = db.QueryRow(`SELECT sql FROM sqlite_master WHERE name='ClipboardHistory'`).Scan(&sqldef)
		hasFTS = sqldef.Valid && strings.Contains(strings.ToUpper(sqldef.String), "FTS5")
	}

	whereSQL, whereArgs := clipPanelBuildWhere(db, keyword, filterType, timeRange, hasFTS)

	count := 0
	countOne := func(tbl string) {
		q := "SELECT COUNT(*) FROM " + tbl
		if whereSQL != "" {
			q += " WHERE " + whereSQL
		}
		var n int
		if err := db.QueryRow(q, whereArgs...).Scan(&n); err == nil {
			count += n
		}
	}
	if hasMain {
		countOne("ClipMain")
	}
	if hasCur {
		countOne("cur.ClipMain")
	}

	fetch := limit + 1
	if !hasCur {
		cols := clipPanelListColumns(db, "ClipMain")
		q := "SELECT " + cols + " FROM ClipMain"
		if whereSQL != "" {
			q += " WHERE " + whereSQL
		}
		q += " ORDER BY IsFavorite DESC, LastCopyTime DESC, ID DESC LIMIT ? OFFSET ?"
		args := append(append([]any{}, whereArgs...), fetch, offset)
		rows, qerr := db.Query(q, args...)
		items, err := clipPanelScan(rows, qerr, false)
		if err != nil {
			return nil, 0, err
		}
		if len(items) > limit {
			items = items[:limit]
		}
		return items, count, nil
	}

	colsMain := clipPanelListColumns(db, "ClipMain")
	colsCur := clipPanelListColumns(db, "cur.ClipMain")
	q := fmt.Sprintf(`
SELECT * FROM (
  SELECT %s, 'm' AS _dbsrc FROM ClipMain %s
  UNION ALL
  SELECT %s, 'c' AS _dbsrc FROM cur.ClipMain %s
) AS u
ORDER BY u.IsFavorite DESC, u.LastCopyTime DESC, u.ID DESC
LIMIT ? OFFSET ?`,
		colsMain, ternary(whereSQL != "", "WHERE "+whereSQL, ""),
		colsCur, ternary(whereSQL != "", "WHERE "+whereSQL, ""))
	args := append([]any{}, whereArgs...)
	args = append(args, whereArgs...)
	args = append(args, fetch, offset)
	rows, qerr := db.Query(q, args...)
	items, err := clipPanelScan(rows, qerr, true)
	if err != nil {
		return nil, 0, err
	}
	if len(items) > limit {
		items = items[:limit]
	}
	return items, count, nil
}

func ternary(cond bool, a, b string) string {
	if cond {
		return a
	}
	return b
}

func clipPanelListColumns(db *sql.DB, table string) string {
	hasLCT := clipMainHasColumn(db, table, "LastCopyTime")
	hasIcon := clipMainHasColumn(db, table, "IconPath")
	hasSP := clipMainHasColumn(db, table, "SourcePath")
	hasIW := clipMainHasColumn(db, table, "ImageWidth")
	hasIH := clipMainHasColumn(db, table, "ImageHeight")
	hasFS := clipMainHasColumn(db, table, "FileSize")

	lc := "COALESCE(LastCopyTime, Timestamp)"
	if !hasLCT {
		lc = "Timestamp"
	}
	lc += " AS LastCopyTime"

	icon := "'' AS IconPath"
	if hasIcon {
		icon = "IconPath"
	}
	sp := "'' AS SourcePath"
	if hasSP {
		sp = "SourcePath"
	}
	iw := "0 AS ImageWidth"
	if hasIW {
		iw = "ImageWidth"
	}
	ih := "0 AS ImageHeight"
	if hasIH {
		ih = "ImageHeight"
	}
	fs := "0 AS FileSize"
	if hasFS {
		fs = "FileSize"
	}

	return fmt.Sprintf(
		`ID, Content, SourceApp, DataType, CharCount, Timestamp, ImagePath, IsFavorite, %s, %s, %s, %s, %s, %s`,
		lc, icon, sp, iw, ih, fs,
	)
}

func clipPanelBuildWhere(db *sql.DB, keyword, filterType, timeRange string, hasFTS bool) (where string, args []any) {
	var parts []string
	var allArgs []any

	fp, fa := clipPanelFilterParts(filterType, timeRange)
	parts = append(parts, fp...)
	allArgs = append(allArgs, fa...)

	kw := strings.TrimSpace(keyword)
	if kw != "" {
		kp, ka := clipPanelKeywordParts(kw, hasFTS)
		if kp != "" {
			parts = append(parts, "("+kp+")")
			allArgs = append(allArgs, ka...)
		}
	}

	return strings.Join(parts, " AND "), allArgs
}

func clipPanelFilterParts(filterType, timeRange string) ([]string, []any) {
	var parts []string
	var args []any
	ft := strings.ToLower(strings.TrimSpace(filterType))
	switch ft {
	case "favorite":
		parts = append(parts, "IsFavorite = 1")
	case "image":
		parts = append(parts, "(LOWER(DataType) = 'image' OR LOWER(DataType) = 'screenshot')")
	case "clipboard":
		parts = append(parts, "(LOWER(DataType) <> 'image' AND LOWER(DataType) <> 'screenshot')")
	case "url":
		parts = append(parts, "(LOWER(DataType) = 'link' OR (LOWER(DataType) = 'image' AND LOWER(COALESCE(ImagePath,'')) LIKE 'http%'))")
	case "text", "code", "color":
		parts = append(parts, "LOWER(DataType) = ?")
		args = append(args, ft)
	case "all":
	default:
	}

	tr := normalizeClipTimeRange(timeRange)
	col := "datetime(COALESCE(LastCopyTime, Timestamp))"
	switch tr {
	case "day":
		parts = append(parts, col+` >= datetime('now', '-1 day', 'localtime')`)
	case "week":
		parts = append(parts, col+` >= datetime('now', '-7 day', 'localtime')`)
	case "month":
		parts = append(parts, col+` >= datetime('now', '-30 day', 'localtime')`)
	default:
		if strings.HasPrefix(tr, "date:") {
			ds := strings.TrimPrefix(tr, "date:")
			parts = append(parts, `date(COALESCE(LastCopyTime, Timestamp)) = ?`)
			args = append(args, ds)
		}
	}
	return parts, args
}

func clipPanelKeywordParts(keyword string, hasFTS bool) (clause string, args []any) {
	kw := strings.TrimSpace(keyword)
	if kw == "" {
		return "", nil
	}

	if hasFTS && utf8.RuneCountInString(kw) == 1 {
		r, _ := utf8.DecodeRuneInString(kw)
		match := clipFtsSingleRuneMatch(r, kw)
		return `ID IN (SELECT rowid FROM ClipboardHistory WHERE ClipboardHistory MATCH ?)`, []any{match}
	}

	if hasFTS && !panelUseLikeInsteadOfFTS(kw) {
		m := ftsMatchQuery(splitQueryTokens(kw))
		return `ID IN (SELECT rowid FROM ClipboardHistory WHERE ClipboardHistory MATCH ?)`, []any{m}
	}

	escapedLike := escapeLikePattern(kw)
	pat := "%" + strings.ToLower(escapedLike) + "%"
	return `(LOWER(COALESCE(Content,'')) LIKE ? ESCAPE '\\' OR LOWER(COALESCE(SourceApp,'')) LIKE ? ESCAPE '\\' OR LOWER(COALESCE(PinyinAbbr,'')) LIKE ? ESCAPE '\\')`,
		[]any{pat, pat, pat}
}

func clipFtsSingleRuneMatch(r rune, original string) string {
	if r == utf8.RuneError {
		return original + "*"
	}
	if r < unicode.MaxASCII && (unicode.IsLetter(r) || unicode.IsDigit(r)) {
		return strings.ToLower(string(r)) + "*"
	}
	esc := strings.ReplaceAll(original, `"`, `""`)
	return `"` + esc + `"`
}

func panelUseLikeInsteadOfFTS(kw string) bool {
	s := strings.TrimSpace(kw)
	if s == "" {
		return true
	}
	if utf8.RuneCountInString(s) <= 2 {
		return true
	}
	for _, r := range s {
		if r > unicode.MaxASCII {
			continue
		}
		if unicode.IsLetter(r) || unicode.IsDigit(r) || unicode.IsSpace(r) {
			continue
		}
		return true
	}
	return false
}

func escapeLikePattern(s string) string {
	s = strings.ReplaceAll(s, `\`, `\\`)
	s = strings.ReplaceAll(s, `%`, `\%`)
	s = strings.ReplaceAll(s, `_`, `\_`)
	return s
}

func clipPanelScan(rows *sql.Rows, err error, withSrc bool) ([]clipPanelItem, error) {
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []clipPanelItem
	for rows.Next() {
		var it clipPanelItem
		var content, sourceApp, dataType, ts, imagePath sql.NullString
		var iconPath, sourcePath sql.NullString
		var lastCopy sql.NullString
		var charCount, isFav, imgW, imgH, fsize sql.NullInt64
		var dbsrc sql.NullString

		if withSrc {
			err = rows.Scan(
				&it.ID, &content, &sourceApp, &dataType, &charCount, &ts, &imagePath, &isFav,
				&lastCopy, &iconPath, &sourcePath, &imgW, &imgH, &fsize, &dbsrc,
			)
		} else {
			err = rows.Scan(
				&it.ID, &content, &sourceApp, &dataType, &charCount, &ts, &imagePath, &isFav,
				&lastCopy, &iconPath, &sourcePath, &imgW, &imgH, &fsize,
			)
		}
		if err != nil {
			return nil, err
		}
		it.Content = content.String
		it.SourceApp = sourceApp.String
		it.DataType = dataType.String
		it.CharCount = int(intFromNull(charCount))
		it.Timestamp = ts.String
		sort := lastCopy.String
		if sort == "" {
			sort = ts.String
		}
		it.SortTime = sort
		it.ImagePath = imagePath.String
		if isFav.Valid {
			it.IsFavorite = int(isFav.Int64)
		}
		it.IconPath = iconPath.String
		it.SourcePath = sourcePath.String
		it.ImageWidth = int(intFromNull(imgW))
		it.ImageHeight = int(intFromNull(imgH))
		it.FileSize = int(intFromNull(fsize))
		if dbsrc.Valid {
			it.dbSrc = dbsrc.String
		}
		out = append(out, it)
	}
	return out, rows.Err()
}

func handleClipPreview(w http.ResponseWriter, r *http.Request, db *sql.DB, absBase string) {
	if r.Method != http.MethodGet {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	idStr := strings.TrimSpace(r.URL.Query().Get("id"))
	id, err := strconv.ParseInt(idStr, 10, 64)
	if err != nil || id < 1 {
		http.Error(w, "bad id", http.StatusBadRequest)
		return
	}
	src := strings.TrimSpace(r.URL.Query().Get("src"))
	table := "ClipMain"
	if src == "c" && curDatabaseAttached && tableExistsInAttached(db, "cur", "ClipMain") {
		table = "cur.ClipMain"
	}

	row := db.QueryRow(fmt.Sprintf(
		`SELECT COALESCE(ImagePath,''), ThumbnailData, COALESCE(ThumbPath,''), COALESCE(DataType,'') FROM %s WHERE ID = ?`, table), id)

	var imagePath string
	var thumbBlob []byte
	var thumbPath, dataType string
	if err := row.Scan(&imagePath, &thumbBlob, &thumbPath, &dataType); err != nil {
		if err == sql.ErrNoRows {
			http.Error(w, "not found", http.StatusNotFound)
			return
		}
		http.Error(w, "db error", http.StatusInternalServerError)
		return
	}

	var img image.Image

	if imagePath != "" && !strings.HasPrefix(strings.ToLower(imagePath), "http") {
		p := imagePath
		if !filepath.IsAbs(p) {
			p = filepath.Join(absBase, p)
		}
		raw, err := os.ReadFile(p)
		if err == nil {
			img, _ = decodeImageBytes(raw)
		}
	}
	if img == nil && len(thumbBlob) > 0 {
		img, _ = decodeImageBytes(thumbBlob)
	}
	if img == nil && thumbPath != "" {
		p := thumbPath
		if !filepath.IsAbs(p) {
			p = filepath.Join(absBase, p)
		}
		raw, err := os.ReadFile(p)
		if err == nil {
			img, _ = decodeImageBytes(raw)
		}
	}

	if img == nil {
		http.Error(w, "no image data", http.StatusNotFound)
		return
	}

	const maxSide = 512
	img = resizeToMax(img, maxSide)

	// 纯 Go WebP（VP8L / near-lossless），无需 CGO
	var buf bytes.Buffer
	if err := gowebper.Encode(&buf, img, &gowebper.Options{Level: gowebper.LevelDefault, Quality: 82}); err != nil {
		http.Error(w, "encode error", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "image/webp")
	w.Header().Set("Cache-Control", "public, max-age=3600")
	http.ServeContent(w, r, "preview.webp", time.Now(), bytes.NewReader(buf.Bytes()))
}

func resizeToMax(img image.Image, max int) image.Image {
	b := img.Bounds()
	w, h := b.Dx(), b.Dy()
	if w <= max && h <= max {
		return img
	}
	var nw, nh int
	if w >= h {
		nw = max
		nh = max * h / w
		if nh < 1 {
			nh = 1
		}
	} else {
		nh = max
		nw = max * w / h
		if nw < 1 {
			nw = 1
		}
	}
	dst := image.NewRGBA(image.Rect(0, 0, nw, nh))
	draw.CatmullRom.Scale(dst, dst.Bounds(), img, b, draw.Over, nil)
	return dst
}

func decodeImageBytes(raw []byte) (image.Image, error) {
	img, err := xwebp.Decode(bytes.NewReader(raw))
	if err == nil {
		return img, nil
	}
	img, err = jpeg.Decode(bytes.NewReader(raw))
	if err == nil {
		return img, nil
	}
	return png.Decode(bytes.NewReader(raw))
}
