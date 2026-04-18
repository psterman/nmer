#Requires AutoHotkey v2.0
; 閫夊尯鎰熷簲锛殈LButton Up 鍚庯紝鑻?Hub 宸插紑涓旂劍鐐瑰湪 Cursor锛屽垯鏉′欢妯℃嫙 ^c 鈫?preview_update锛涘惁鍒欐竻閫夊尯缂撳瓨銆?; HubCapsule锛氬伐鍏锋爮銆屾柊銆嶃€丆ursor 鍐呭弻鍑?Ctrl+C锛坉raft_collect锛夈€丆apsLock+C銆佹樉寮忓瓨鍏ワ紱棰勮涓庤崏绋挎秷鎭垎娴併€?
global g_SelSense_Enabled := true
global g_SelSense_CopyDelayMs := 55
global g_SelSense_RequireIBeam := false
global g_SelSense_MenuAnchorX := 0
global g_SelSense_MenuAnchorY := 0
global g_SelSense_LastFullText := ""
global g_SelSense_LastTick := 0
global g_SelSense_LastClipSig := ""
global g_SelSense_LastFireTick := 0
global g_SelSense_MenuGui := 0
global g_SelSense_MenuCtrl := 0
global g_SelSense_MenuWV2 := 0
global g_SelSense_MenuReady := false
global g_SelSense_MenuVisible := false
global g_SelSense_PendingText := ""
global g_SelSense_MenuW := 220
global g_SelSense_MenuH := 200
global g_SelSense_NextNavPage := ""
global g_SelSense_MenuActivateOnShow := false
; 宸ュ叿鏍忔墦寮€ Hub 鍚?WebView 鍋滃湪 HubCapsule锛涢€変腑鏂囨湰搴斿洖鍒?SelectionMenu锛屽惁鍒欎細璇敤澶х獥鍙ｉ〉
global g_SelSense_MenuShowingHub := false
global g_SelSense_ClipWaitSec := 0.45
global g_SelSense_HubMousedownX := 0
global g_SelSense_HubMousedownY := 0
global g_SelSense_HubDragActive := false
global g_SelSense_HubDragRefPtrX := 0
global g_SelSense_HubDragRefPtrY := 0
global g_SelSense_HubDragRefWinX := 0
global g_SelSense_HubDragRefWinY := 0
global g_SelSense_UserCopyInProgress := false
global g_SelSense_UserCopyEndTick := 0
global g_SelSense_DoubleCopyHub_LastTick := 0
global g_SelSense_HubCopyTriggerMode := "capslock"
; HubCapsule锛氬爢鍙犻€夋嫨/鎺ㄩ€侊紙渚?CapsLock+C/V锛?global g_HubCapsule_SelectedText := ""
global g_SelSense_PendingHubSegments := []  ; Hub 鏈?ready 鏃舵殏瀛樺緟 push 鐨勬枃鏈
; 涓庝富鑴氭湰 CapsLockCopy 鍏辩敤锛歋end(^c) 鏈熼棿涓?true锛寏^c 椤昏烦杩囦互鍏嶈鍒版仮澶嶅悗鐨勬棫鍓创鏉?global CapsLockCopyInProgress := false
; 鏈€杩戜竴娆″彂寰€ Hub 鐨勩€屽叆鑽夌銆嶆槸鍚︽潵鑷樉寮忛噰闆嗭紙棰勮鏇存柊浼氱疆 false锛?global g_SelSense_IsManualCollected := false
global g_SelSense_HubDictReady := false
global g_SelSense_HubDictActiveSource := "builtin_default"
global g_SelSense_HubDictInstallBusy := false
global g_SelSense_HubDictInstallQueued := false

SelectionSense_HubDict_EscapeSql(s) {
    return StrReplace(String(s), "'", "''")
}

SelectionSense_HubDict_QuoteIdent(name) {
    q := Chr(34)
    return q . StrReplace(String(name), q, q . q) . q
}

SelectionSense_HubDict_NormalizeSourceId(sourceId) {
    raw := Trim(String(sourceId))
    if (raw = "")
        return ""
    normalized := RegExReplace(StrLower(raw), "[^a-z0-9_]+", "_")
    normalized := Trim(normalized, "_")
    if (normalized = "")
        normalized := "sqlite_dict"
    return SubStr(normalized, 1, 56)
}

SelectionSense_HubDict_GetTableColumns(dbAlias, tableName) {
    global ClipboardDB
    cols := []
    if !(IsSet(ClipboardDB) && IsObject(ClipboardDB))
        return cols
    alias0 := Trim(String(dbAlias))
    if (alias0 = "")
        alias0 := "main"
    sql := "PRAGMA " . alias0 . ".table_info('" . SelectionSense_HubDict_EscapeSql(tableName) . "')"
    try {
        if (ClipboardDB.GetTable(sql, &t) && t && t.HasProp("Rows")) {
            for _, row in t.Rows {
                if (row.Length >= 2)
                    cols.Push(String(row[2]))
            }
        }
    } catch as _e {
    }
    return cols
}

SelectionSense_HubDict_FindColumn(cols, candidates) {
    if !(cols is Array)
        return ""
    byLower := Map()
    for _, col in cols {
        c := String(col)
        if (c != "")
            byLower[StrLower(c)] := c
    }
    for _, want in candidates {
        w := StrLower(String(want))
        if byLower.Has(w)
            return byLower[w]
    }
    return ""
}

SelectionSense_HubDict_DetectKvColumns(dbAlias, tableName) {
    cols := SelectionSense_HubDict_GetTableColumns(dbAlias, tableName)
    if (cols.Length < 2)
        return 0
    keyCandidates := ["k", "key", "src", "source", "word", "term", "token", "entry", "en", "english", "zh", "chinese", "cn", "text"]
    valCandidates := ["v", "value", "dst", "target", "translation", "meaning", "mean", "result", "zh", "chinese", "cn", "en", "english", "text"]
    keyCol := SelectionSense_HubDict_FindColumn(cols, keyCandidates)
    valCol := SelectionSense_HubDict_FindColumn(cols, valCandidates)
    if (keyCol = "")
        keyCol := String(cols[1])
    if (valCol = "")
        valCol := (cols.Length >= 2) ? String(cols[2]) : ""
    if (valCol = keyCol && cols.Length >= 2) {
        for _, col in cols {
            if (col != keyCol) {
                valCol := col
                break
            }
        }
    }
    if (keyCol = "" || valCol = "" || keyCol = valCol)
        return 0
    return Map("keyCol", keyCol, "valCol", valCol)
}

SelectionSense_HubDict_DetectEnZhColumns(dbAlias, tableName) {
    cols := SelectionSense_HubDict_GetTableColumns(dbAlias, tableName)
    if (cols.Length < 2)
        return 0
    enCandidates := ["en", "english", "eng", "src_en", "source_en", "word_en", "term_en"]
    zhCandidates := ["zh", "chinese", "cn", "han", "src_zh", "source_zh", "word_zh", "term_zh"]
    enCol := SelectionSense_HubDict_FindColumn(cols, enCandidates)
    zhCol := SelectionSense_HubDict_FindColumn(cols, zhCandidates)
    if (enCol = "" || zhCol = "" || enCol = zhCol)
        return 0
    return Map("enCol", enCol, "zhCol", zhCol)
}

SelectionSense_HubDict_SourceExists(sourceId) {
    global ClipboardDB
    sid := Trim(String(sourceId))
    if (sid = "")
        return false
    sql := "SELECT COUNT(*) FROM HubLocalDictSource WHERE SourceId='" . SelectionSense_HubDict_EscapeSql(sid) . "'"
    try {
        if (ClipboardDB.GetTable(sql, &t) && t && t.HasProp("Rows") && t.Rows.Length > 0 && t.Rows[1].Length > 0)
            return (Integer(t.Rows[1][1]) > 0)
    } catch as _e {
    }
    return false
}

SelectionSense_HubDict_GetActiveSource() {
    global g_SelSense_HubDictActiveSource
    sid := Trim(String(g_SelSense_HubDictActiveSource))
    if (sid = "")
        sid := "builtin_default"
    if !SelectionSense_HubDict_SourceExists(sid)
        sid := "builtin_default"
    g_SelSense_HubDictActiveSource := sid
    return sid
}

SelectionSense_HubDict_SaveActiveSource(sourceId) {
    global g_SelSense_HubDictActiveSource
    sid := Trim(String(sourceId))
    if (sid = "")
        sid := "builtin_default"
    g_SelSense_HubDictActiveSource := sid
    cfg := SelectionSense_HubCapsule_IniPath()
    try IniWrite(sid, cfg, "HubCapsule", "TranslateSqliteActiveDict")
}

SelectionSense_HubDict_Ensure() {
    global ClipboardDB, g_SelSense_HubDictReady
    if g_SelSense_HubDictReady
        return true
    if !(IsSet(ClipboardDB) && IsObject(ClipboardDB))
        return false
    try {
        hasLegacy := false
        legacyHasSourceId := false
        if (ClipboardDB.GetTable("SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='HubLocalDict'", &tb)
            && tb && tb.HasProp("Rows") && tb.Rows.Length > 0 && tb.Rows[1].Length > 0)
            hasLegacy := Integer(tb.Rows[1][1]) > 0
        if hasLegacy {
            cols := SelectionSense_HubDict_GetTableColumns("main", "HubLocalDict")
            for _, col in cols {
                if (StrLower(String(col)) = "sourceid") {
                    legacyHasSourceId := true
                    break
                }
            }
        }
        if (hasLegacy && !legacyHasSourceId) {
            ClipboardDB.Exec("BEGIN IMMEDIATE")
            try {
                ClipboardDB.Exec("ALTER TABLE HubLocalDict RENAME TO HubLocalDict_legacy")
                ClipboardDB.Exec("CREATE TABLE HubLocalDict (SourceId TEXT NOT NULL, Dir TEXT NOT NULL, K TEXT NOT NULL COLLATE NOCASE, V TEXT NOT NULL, PRIMARY KEY (SourceId, Dir, K))")
                ClipboardDB.Exec("INSERT OR REPLACE INTO HubLocalDict (SourceId, Dir, K, V) SELECT 'builtin_default', LOWER(TRIM(Dir)), K, V FROM HubLocalDict_legacy")
                ClipboardDB.Exec("DROP TABLE HubLocalDict_legacy")
                ClipboardDB.Exec("COMMIT")
            } catch as _e {
                try ClipboardDB.Exec("ROLLBACK")
                return false
            }
        }
        ClipboardDB.Exec("CREATE TABLE IF NOT EXISTS HubLocalDict (SourceId TEXT NOT NULL, Dir TEXT NOT NULL, K TEXT NOT NULL COLLATE NOCASE, V TEXT NOT NULL, PRIMARY KEY (SourceId, Dir, K))")
        ClipboardDB.Exec("CREATE INDEX IF NOT EXISTS idx_HubLocalDict_SourceDirK ON HubLocalDict (SourceId, Dir, K)")
        ClipboardDB.Exec("CREATE TABLE IF NOT EXISTS HubLocalDictSource (SourceId TEXT PRIMARY KEY, Name TEXT NOT NULL, DbPath TEXT NOT NULL, Kind TEXT NOT NULL DEFAULT 'sqlite_import', CreatedAt TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP, UpdatedAt TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP)")
        ClipboardDB.Exec("INSERT OR IGNORE INTO HubLocalDictSource (SourceId, Name, DbPath, Kind) VALUES ('builtin_default', '内置词典', '[builtin]', 'builtin')")
        rowCount := 0
        if (ClipboardDB.GetTable("SELECT COUNT(*) FROM HubLocalDict WHERE SourceId='builtin_default'", &t) && t && t.HasProp("Rows") && t.Rows.Length > 0 && t.Rows[1].Length > 0)
            rowCount := Integer(t.Rows[1][1])
        if (rowCount <= 0)
            SelectionSense_HubDict_LoadSeedFromFile("builtin_default")
        cfg := SelectionSense_HubCapsule_IniPath()
        active0 := "builtin_default"
        try active0 := Trim(String(IniRead(cfg, "HubCapsule", "TranslateSqliteActiveDict", "builtin_default")))
        if (active0 = "")
            active0 := "builtin_default"
        if !SelectionSense_HubDict_SourceExists(active0)
            active0 := "builtin_default"
        SelectionSense_HubDict_SaveActiveSource(active0)
        g_SelSense_HubDictReady := true
        return true
    } catch as _e {
        return false
    }
}

SelectionSense_HubDict_LoadSeedFromFile(sourceId := "builtin_default") {
    global ClipboardDB
    if !(IsSet(ClipboardDB) && IsObject(ClipboardDB))
        return false
    sid := Trim(String(sourceId))
    if (sid = "")
        sid := "builtin_default"
    p := A_ScriptDir "\assets\dict\hubcapsule_base_dict.tsv"
    if !FileExist(p)
        return false
    try raw := FileRead(p, "UTF-8")
    catch {
        return false
    }
    ClipboardDB.Exec("BEGIN IMMEDIATE")
    try {
        for line in StrSplit(raw, "`n", "`r") {
            ln := Trim(String(line), " `t`r`n")
            if (ln = "" || SubStr(ln, 1, 1) = "#")
                continue
            parts := StrSplit(ln, "`t")
            if (parts.Length < 2)
                continue
            src := Trim(String(parts[1]))
            dst := Trim(String(parts[2]))
            if (src = "" || dst = "")
                continue
            dir := ""
            k := ""
            v := dst
            if RegExMatch(src, "[\x{4E00}-\x{9FFF}]") {
                dir := "zh2en"
                k := src
            } else if RegExMatch(dst, "[\x{4E00}-\x{9FFF}]") {
                dir := "en2zh"
                k := StrLower(src)
            } else {
                continue
            }
            sql := "INSERT OR REPLACE INTO HubLocalDict (SourceId, Dir, K, V) VALUES ('"
                . SelectionSense_HubDict_EscapeSql(sid) . "','"
                . SelectionSense_HubDict_EscapeSql(dir) . "','"
                . SelectionSense_HubDict_EscapeSql(k) . "','"
                . SelectionSense_HubDict_EscapeSql(v) . "')"
            ClipboardDB.Exec(sql)
        }
        ClipboardDB.Exec("COMMIT")
        return true
    } catch as _e {
        try ClipboardDB.Exec("ROLLBACK")
        return false
    }
}

SelectionSense_HubDict_ListSources() {
    global ClipboardDB
    out := []
    if !SelectionSense_HubDict_Ensure()
        return out
    sql := "SELECT SourceId, Name, DbPath, Kind FROM HubLocalDictSource ORDER BY CASE WHEN SourceId='builtin_default' THEN 0 ELSE 1 END, UpdatedAt DESC, Name ASC"
    try {
        if (ClipboardDB.GetTable(sql, &t) && t && t.HasProp("Rows")) {
            for _, row in t.Rows {
                sid := (row.Length >= 1) ? String(row[1]) : ""
                if (sid = "")
                    continue
                name := (row.Length >= 2) ? String(row[2]) : sid
                dbPath := (row.Length >= 3) ? String(row[3]) : ""
                kind := (row.Length >= 4) ? String(row[4]) : ""
                out.Push(Map(
                    "sourceId", sid,
                    "name", name,
                    "dbPath", dbPath,
                    "kind", kind,
                    "entryCount", 0,
                    "isBuiltin", (sid = "builtin_default")
                ))
            }
        }
    } catch as _e {
    }
    if (out.Length = 0)
        out.Push(Map("sourceId", "builtin_default", "name", "内置词典", "dbPath", "[builtin]", "kind", "builtin", "entryCount", 0, "isBuiltin", true))
    return out
}

SelectionSense_HubDict_SetActiveSource(sourceId) {
    sid := Trim(String(sourceId))
    if (sid = "")
        sid := "builtin_default"
    if !SelectionSense_HubDict_Ensure()
        return false
    if !SelectionSense_HubDict_SourceExists(sid)
        sid := "builtin_default"
    SelectionSense_HubDict_SaveActiveSource(sid)
    return true
}

SelectionSense_HubDict_DeleteSource(sourceId) {
    global ClipboardDB
    sid := Trim(String(sourceId))
    if (sid = "" || sid = "builtin_default")
        return false
    if !SelectionSense_HubDict_Ensure()
        return false
    if !SelectionSense_HubDict_SourceExists(sid)
        return false
    ClipboardDB.Exec("BEGIN IMMEDIATE")
    try {
        ClipboardDB.Exec("DELETE FROM HubLocalDict WHERE SourceId='" . SelectionSense_HubDict_EscapeSql(sid) . "'")
        ClipboardDB.Exec("DELETE FROM HubLocalDictSource WHERE SourceId='" . SelectionSense_HubDict_EscapeSql(sid) . "'")
        ClipboardDB.Exec("COMMIT")
    } catch as _e {
        try ClipboardDB.Exec("ROLLBACK")
        return false
    }
    if (SelectionSense_HubDict_GetActiveSource() = sid)
        SelectionSense_HubDict_SetActiveSource("builtin_default")
    return true
}

SelectionSense_HubDict_ImportSqlite(sourcePath) {
    global ClipboardDB
    p := Trim(String(sourcePath))
    if (p = "")
        return Map("ok", false, "message", "未选择文件")
    if !FileExist(p)
        return Map("ok", false, "message", "文件不存在")
    if !SelectionSense_HubDict_Ensure()
        return Map("ok", false, "message", "词典未初始化")

    SplitPath(p, &nameOnly, , , &nameNoExt)
    baseName := Trim(String(nameNoExt))
    if (baseName = "")
        baseName := Trim(String(nameOnly))
    normalized := SelectionSense_HubDict_NormalizeSourceId(baseName)
    if (normalized = "")
        normalized := "sqlite_dict"
    sid := "sqlite_" . normalized . "_" . A_Now . "_" . Random(100, 999)
    sid := SubStr(sid, 1, 90)
    alias0 := "extdict"
    attached := false
    mode := ""
    importedCount := 0

    try {
        ClipboardDB.Exec("ATTACH DATABASE '" . SelectionSense_HubDict_EscapeSql(p) . "' AS " . alias0)
        attached := true
        tables := Map()
        if (ClipboardDB.GetTable("SELECT name FROM " . alias0 . ".sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'", &tt)
            && tt && tt.HasProp("Rows")) {
            for _, row in tt.Rows {
                if (row.Length < 1)
                    continue
                tn := String(row[1])
                if (tn != "")
                    tables[StrLower(tn)] := tn
            }
        }
        if (tables.Count = 0)
            throw Error("未识别到可用数据表")

        hasHub := tables.Has("hublocaldict")
        hubTable := hasHub ? tables["hublocaldict"] : ""
        hubDir := "", hubK := "", hubV := ""
        if hasHub {
            hubCols := SelectionSense_HubDict_GetTableColumns(alias0, hubTable)
            hubDir := SelectionSense_HubDict_FindColumn(hubCols, ["dir"])
            hubK := SelectionSense_HubDict_FindColumn(hubCols, ["k", "key"])
            hubV := SelectionSense_HubDict_FindColumn(hubCols, ["v", "value"])
            if (hubDir != "" && hubK != "" && hubV != "")
                mode := "hub"
        }
        if (mode = "") {
            hasEn2Zh := tables.Has("en2zh")
            hasZh2En := tables.Has("zh2en")
            if (hasEn2Zh && hasZh2En) {
                kvEn := SelectionSense_HubDict_DetectKvColumns(alias0, tables["en2zh"])
                kvZh := SelectionSense_HubDict_DetectKvColumns(alias0, tables["zh2en"])
                if (IsObject(kvEn) && IsObject(kvZh)) {
                    mode := "pair_tables"
                    pairEnTable := tables["en2zh"]
                    pairZhTable := tables["zh2en"]
                }
            }
        }
        if (mode = "") {
            hasStardict := tables.Has("stardict")
            if hasStardict {
                stardictTable := tables["stardict"]
                sdCols := SelectionSense_HubDict_GetTableColumns(alias0, stardictTable)
                sdWordCol := SelectionSense_HubDict_FindColumn(sdCols, ["word", "sw", "term", "entry"])
                sdTransCol := SelectionSense_HubDict_FindColumn(sdCols, ["translation", "trans", "meaning", "mean", "definition"])
                if (sdWordCol != "" && sdTransCol != "") {
                    mode := "stardict"
                    pairTable := stardictTable
                    pairEnCol := sdWordCol
                    pairZhCol := sdTransCol
                }
            }
        }
        if (mode = "") {
            for _, actualTable in tables {
                pairCols := SelectionSense_HubDict_DetectEnZhColumns(alias0, actualTable)
                if IsObject(pairCols) {
                    mode := "pair_cols"
                    pairTable := actualTable
                    pairEnCol := String(pairCols["enCol"])
                    pairZhCol := String(pairCols["zhCol"])
                    break
                }
            }
        }
        if (mode = "")
            throw Error("未识别支持的词典结构")

        ClipboardDB.Exec("BEGIN IMMEDIATE")
        try {
            ClipboardDB.Exec("DELETE FROM HubLocalDict WHERE SourceId='" . SelectionSense_HubDict_EscapeSql(sid) . "'")
            if (mode = "hub") {
                qTable := alias0 . "." . SelectionSense_HubDict_QuoteIdent(hubTable)
                qDir := SelectionSense_HubDict_QuoteIdent(hubDir)
                qK := SelectionSense_HubDict_QuoteIdent(hubK)
                qV := SelectionSense_HubDict_QuoteIdent(hubV)
                insertHub := "INSERT OR REPLACE INTO HubLocalDict (SourceId, Dir, K, V) "
                    . "SELECT '" . SelectionSense_HubDict_EscapeSql(sid) . "', "
                    . "CASE LOWER(TRIM(" . qDir . ")) WHEN 'zh2en' THEN 'zh2en' ELSE 'en2zh' END, "
                    . "CASE WHEN LOWER(TRIM(" . qDir . "))='zh2en' THEN TRIM(" . qK . ") ELSE LOWER(TRIM(" . qK . ")) END, "
                    . "TRIM(" . qV . ") "
                    . "FROM " . qTable . " "
                    . "WHERE TRIM(IFNULL(" . qK . ",''))<>'' AND TRIM(IFNULL(" . qV . ",''))<>''"
                ClipboardDB.Exec(insertHub)
            } else if (mode = "pair_tables") {
                kvEn := SelectionSense_HubDict_DetectKvColumns(alias0, pairEnTable)
                kvZh := SelectionSense_HubDict_DetectKvColumns(alias0, pairZhTable)
                qEnTable := alias0 . "." . SelectionSense_HubDict_QuoteIdent(pairEnTable)
                qZhTable := alias0 . "." . SelectionSense_HubDict_QuoteIdent(pairZhTable)
                qEnK := SelectionSense_HubDict_QuoteIdent(String(kvEn["keyCol"]))
                qEnV := SelectionSense_HubDict_QuoteIdent(String(kvEn["valCol"]))
                qZhK := SelectionSense_HubDict_QuoteIdent(String(kvZh["keyCol"]))
                qZhV := SelectionSense_HubDict_QuoteIdent(String(kvZh["valCol"]))
                insertEn := "INSERT OR REPLACE INTO HubLocalDict (SourceId, Dir, K, V) "
                    . "SELECT '" . SelectionSense_HubDict_EscapeSql(sid) . "', 'en2zh', LOWER(TRIM(" . qEnK . ")), TRIM(" . qEnV . ") "
                    . "FROM " . qEnTable . " "
                    . "WHERE TRIM(IFNULL(" . qEnK . ",''))<>'' AND TRIM(IFNULL(" . qEnV . ",''))<>''"
                insertZh := "INSERT OR REPLACE INTO HubLocalDict (SourceId, Dir, K, V) "
                    . "SELECT '" . SelectionSense_HubDict_EscapeSql(sid) . "', 'zh2en', TRIM(" . qZhK . "), TRIM(" . qZhV . ") "
                    . "FROM " . qZhTable . " "
                    . "WHERE TRIM(IFNULL(" . qZhK . ",''))<>'' AND TRIM(IFNULL(" . qZhV . ",''))<>''"
                ClipboardDB.Exec(insertEn)
                ClipboardDB.Exec(insertZh)
            } else if (mode = "pair_cols") {
                qPairTable := alias0 . "." . SelectionSense_HubDict_QuoteIdent(pairTable)
                qEnCol := SelectionSense_HubDict_QuoteIdent(pairEnCol)
                qZhCol := SelectionSense_HubDict_QuoteIdent(pairZhCol)
                insertEnZh := "INSERT OR REPLACE INTO HubLocalDict (SourceId, Dir, K, V) "
                    . "SELECT '" . SelectionSense_HubDict_EscapeSql(sid) . "', 'en2zh', LOWER(TRIM(" . qEnCol . ")), TRIM(" . qZhCol . ") "
                    . "FROM " . qPairTable . " "
                    . "WHERE TRIM(IFNULL(" . qEnCol . ",''))<>'' AND TRIM(IFNULL(" . qZhCol . ",''))<>''"
                insertZhEn := "INSERT OR REPLACE INTO HubLocalDict (SourceId, Dir, K, V) "
                    . "SELECT '" . SelectionSense_HubDict_EscapeSql(sid) . "', 'zh2en', TRIM(" . qZhCol . "), TRIM(" . qEnCol . ") "
                    . "FROM " . qPairTable . " "
                    . "WHERE TRIM(IFNULL(" . qEnCol . ",''))<>'' AND TRIM(IFNULL(" . qZhCol . ",''))<>''"
                ClipboardDB.Exec(insertEnZh)
                ClipboardDB.Exec(insertZhEn)
            } else if (mode = "stardict") {
                qPairTable := alias0 . "." . SelectionSense_HubDict_QuoteIdent(pairTable)
                qEnCol := SelectionSense_HubDict_QuoteIdent(pairEnCol)
                qZhCol := SelectionSense_HubDict_QuoteIdent(pairZhCol)
                cleanZhExpr := "TRIM(CASE "
                    . "WHEN INSTR(REPLACE(IFNULL(" . qZhCol . ",''), CHAR(13), ''), CHAR(10))>0 "
                    . "THEN SUBSTR(REPLACE(IFNULL(" . qZhCol . ",''), CHAR(13), ''), 1, INSTR(REPLACE(IFNULL(" . qZhCol . ",''), CHAR(13), ''), CHAR(10)) - 1) "
                    . "ELSE REPLACE(IFNULL(" . qZhCol . ",''), CHAR(13), '') END)"
                insertStardict := "INSERT OR REPLACE INTO HubLocalDict (SourceId, Dir, K, V) "
                    . "SELECT '" . SelectionSense_HubDict_EscapeSql(sid) . "', 'en2zh', LOWER(TRIM(" . qEnCol . ")), " . cleanZhExpr . " "
                    . "FROM " . qPairTable . " "
                    . "WHERE TRIM(IFNULL(" . qEnCol . ",''))<>'' AND " . cleanZhExpr . "<>''"
                ClipboardDB.Exec(insertStardict)
            }
            countSql := "SELECT COUNT(*) FROM HubLocalDict WHERE SourceId='" . SelectionSense_HubDict_EscapeSql(sid) . "'"
            if (ClipboardDB.GetTable(countSql, &ct) && ct && ct.HasProp("Rows") && ct.Rows.Length > 0 && ct.Rows[1].Length > 0)
                importedCount := Integer(ct.Rows[1][1])
            if (importedCount <= 0)
                throw Error("没有可导入条目")
            ClipboardDB.Exec("INSERT OR REPLACE INTO HubLocalDictSource (SourceId, Name, DbPath, Kind, UpdatedAt) VALUES ('"
                . SelectionSense_HubDict_EscapeSql(sid) . "','"
                . SelectionSense_HubDict_EscapeSql(baseName) . "','"
                . SelectionSense_HubDict_EscapeSql(p) . "','sqlite_import', CURRENT_TIMESTAMP)")
            ClipboardDB.Exec("COMMIT")
        } catch as _e {
            try ClipboardDB.Exec("ROLLBACK")
            throw
        }
        try ClipboardDB.Exec("DETACH DATABASE " . alias0)
        attached := false
    } catch as e {
        if attached {
            try ClipboardDB.Exec("DETACH DATABASE " . alias0)
        }
        return Map("ok", false, "message", "导入失败: " . e.Message)
    }
    SelectionSense_HubDict_SetActiveSource(sid)
    return Map("ok", true, "message", "导入成功，共 " . importedCount . " 条", "sourceId", sid, "entryCount", importedCount)
}

SelectionSense_HubDict_Lookup(dir, key, sourceId := "") {
    global ClipboardDB
    if !SelectionSense_HubDict_Ensure()
        return ""
    d := StrLower(Trim(String(dir)))
    k := Trim(String(key))
    sid := Trim(String(sourceId))
    if (sid = "")
        sid := SelectionSense_HubDict_GetActiveSource()
    if !SelectionSense_HubDict_SourceExists(sid)
        sid := "builtin_default"
    if (d = "en2zh")
        k := StrLower(k)
    if (k = "")
        return ""
    sql := "SELECT V FROM HubLocalDict WHERE SourceId='" . SelectionSense_HubDict_EscapeSql(sid) . "' AND Dir='" . SelectionSense_HubDict_EscapeSql(d) . "' AND K='" . SelectionSense_HubDict_EscapeSql(k) . "' LIMIT 1"
    try {
        if (ClipboardDB.GetTable(sql, &t) && t && t.HasProp("Rows") && t.Rows.Length > 0 && t.Rows[1].Length > 0)
            return String(t.Rows[1][1])
    } catch as _e {
    }
    if (sid != "builtin_default") {
        sql2 := "SELECT V FROM HubLocalDict WHERE SourceId='builtin_default' AND Dir='" . SelectionSense_HubDict_EscapeSql(d) . "' AND K='" . SelectionSense_HubDict_EscapeSql(k) . "' LIMIT 1"
        try {
            if (ClipboardDB.GetTable(sql2, &t2) && t2 && t2.HasProp("Rows") && t2.Rows.Length > 0 && t2.Rows[1].Length > 0)
                return String(t2.Rows[1][1])
        } catch as _e {
        }
    }
    return ""
}

SelectionSense_HubDictInstall_RunJs(percent, statusText := "") {
    global g_SelSense_MenuWV2
    if !g_SelSense_MenuWV2
        return
    pct := Integer(percent)
    if (pct < 0)
        pct := 0
    if (pct > 100)
        pct := 100
    st := String(statusText)
    try stJson := Jxon_Dump(st)
    catch {
        esc := StrReplace(st, "\", "\\")
        esc := StrReplace(esc, "`r", "")
        esc := StrReplace(esc, "`n", "\n")
        esc := StrReplace(esc, "'", "\'")
        stJson := "'" . esc . "'"
    }
    js := "try{if(window.hubDictInstallUpdate){window.hubDictInstallUpdate(" . pct . "," . stJson . ");}}catch(e){}"
    try g_SelSense_MenuWV2.ExecuteScript(js)
}

SelectionSense_HubDictInstall_FindDb(rootDir) {
    root := Trim(String(rootDir))
    if (root = "")
        return ""
    direct := root "\ultimate.db"
    if FileExist(direct)
        return direct
    direct2 := root "\ecdict.db"
    if FileExist(direct2)
        return direct2
    direct3 := root "\stardict.db"
    if FileExist(direct3)
        return direct3
    direct4 := root "\ecdict.sqlite"
    if FileExist(direct4)
        return direct4
    direct5 := root "\ecdict.sqlite3"
    if FileExist(direct5)
        return direct5
    loop files root "\*.db", "R" {
        nm := StrLower(A_LoopFileName)
        if (nm = "ultimate.db")
            return A_LoopFileFullPath
        if (nm = "ecdict.db")
            return A_LoopFileFullPath
    }
    loop files root "\*.sqlite", "R" {
        nm := StrLower(A_LoopFileName)
        if InStr(nm, "ecdict") || InStr(nm, "stardict") || InStr(nm, "ultimate")
            return A_LoopFileFullPath
    }
    loop files root "\*.sqlite3", "R" {
        nm := StrLower(A_LoopFileName)
        if InStr(nm, "ecdict") || InStr(nm, "stardict") || InStr(nm, "ultimate")
            return A_LoopFileFullPath
    }
    loop files root "\*.db3", "R" {
        nm := StrLower(A_LoopFileName)
        if InStr(nm, "ecdict") || InStr(nm, "stardict") || InStr(nm, "ultimate")
            return A_LoopFileFullPath
    }
    loop files root "\*.db", "R" {
        nm := StrLower(A_LoopFileName)
        if InStr(nm, "stardict")
            return A_LoopFileFullPath
        if InStr(nm, "ecdict")
            return A_LoopFileFullPath
        if InStr(nm, "ultimate")
            return A_LoopFileFullPath
    }
    return ""
}

SelectionSense_HubDictInstall_CallSQ3Open(dbPath := "") {
    try {
        fn := Func("SQ3_Open")
    } catch {
        return false
    }
    dbName := "ultimate.db"
    p0 := Trim(String(dbPath))
    if (p0 != "") {
        SplitPath(p0, &name0)
        if (name0 != "")
            dbName := name0
    }
    oldWd := A_WorkingDir
    try {
        SetWorkingDir(A_ScriptDir)
        fn.Call(dbName)
        return true
    } catch {
        return false
    } finally {
        try SetWorkingDir(oldWd)
    }
}

SelectionSense_HubDictInstall_DownloadByWinHttp(url, savePath, progressCb := 0, statusCb := 0) {
    u := Trim(String(url))
    outPath := Trim(String(savePath))
    if (u = "")
        return Map("ok", false, "message", "下载地址为空")
    if (outPath = "")
        return Map("ok", false, "message", "下载目标路径为空")
    if !RegExMatch(u, "i)^https?://([^/:]+)(?::(\d+))?(/.*)?$", &m)
        return Map("ok", false, "message", "下载地址格式错误")
    if IsObject(statusCb)
        statusCb.Call("正在解析下载地址...")
    host := m[1]
    port := (m[2] != "") ? Integer(m[2]) : (InStr(StrLower(u), "https://") = 1 ? 443 : 80)
    path := (m[3] != "") ? m[3] : "/"
    secure := InStr(StrLower(u), "https://") = 1
    total := 0
    try {
        req := ComObject("WinHttp.WinHttpRequest.5.1")
        req.SetTimeouts(4000, 5000, 12000, 12000)
        req.Open("HEAD", u, false)
        req.SetRequestHeader("User-Agent", "AHK-HubDict/1.0")
        req.Send()
        cl := Trim(String(req.GetResponseHeader("Content-Length")))
        if (cl != "")
            total := Integer(cl)
    } catch {
        total := 0
    }
    f := 0, hSession := 0, hConnect := 0, hRequest := 0
    written := 0
    try {
        SplitPath(outPath, , &outDir)
        if (outDir != "" && !DirExist(outDir))
            DirCreate(outDir)
        if FileExist(outPath)
            FileDelete(outPath)
        f := FileOpen(outPath, "w")
        if !f
            throw Error("无法创建下载文件")
        hSession := DllCall("winhttp\WinHttpOpen", "WStr", "AHK-HubDict/1.0", "UInt", 0, "Ptr", 0, "Ptr", 0, "UInt", 0, "Ptr")
        if !hSession
            throw Error("WinHttpOpen 失败，错误码: " . A_LastError)
        DllCall("winhttp\WinHttpSetTimeouts", "Ptr", hSession, "Int", 5000, "Int", 6000, "Int", 15000, "Int", 15000)
        hConnect := DllCall("winhttp\WinHttpConnect", "Ptr", hSession, "WStr", host, "UShort", port, "UInt", 0, "Ptr")
        if !hConnect
            throw Error("WinHttpConnect 失败，错误码: " . A_LastError)
        flags := secure ? 0x00800000 : 0
        hRequest := DllCall("winhttp\WinHttpOpenRequest", "Ptr", hConnect, "WStr", "GET", "WStr", path, "Ptr", 0, "Ptr", 0, "Ptr", 0, "UInt", flags, "Ptr")
        if !hRequest
            throw Error("WinHttpOpenRequest 失败，错误码: " . A_LastError)
        if IsObject(statusCb)
            statusCb.Call("正在连接远程服务器...")
        if !DllCall("winhttp\WinHttpSendRequest", "Ptr", hRequest, "Ptr", 0, "UInt", 0, "Ptr", 0, "UInt", 0, "UInt", 0, "Ptr", 0)
            throw Error("WinHttpSendRequest 失败，错误码: " . A_LastError)
        if !DllCall("winhttp\WinHttpReceiveResponse", "Ptr", hRequest, "Ptr", 0)
            throw Error("WinHttpReceiveResponse 失败，错误码: " . A_LastError)
        if IsObject(statusCb)
            statusCb.Call("连接成功，开始下载...")
        buf := Buffer(128 * 1024, 0)
        lastTick := A_TickCount
        Loop {
            avail := 0
            if !DllCall("winhttp\WinHttpQueryDataAvailable", "Ptr", hRequest, "UIntP", avail)
                throw Error("WinHttpQueryDataAvailable 失败")
            if (avail <= 0)
                break
            toRead := (avail > buf.Size) ? buf.Size : avail
            readNow := 0
            if !DllCall("winhttp\WinHttpReadData", "Ptr", hRequest, "Ptr", buf.Ptr, "UInt", toRead, "UIntP", readNow)
                throw Error("WinHttpReadData 失败")
            if (readNow <= 0)
                break
            f.RawWrite(buf, readNow)
            written += readNow
            if IsObject(progressCb) && (A_TickCount - lastTick >= 200) {
                pct := (total > 0) ? Floor((written * 100) / total) : Min(95, 3 + Floor(written / (1024 * 1024)))
                progressCb.Call(pct, written, total)
                lastTick := A_TickCount
                Sleep(0)
            }
        }
        if IsObject(progressCb)
            progressCb.Call(100, written, total)
        fileSize := 0
        try fileSize := FileGetSize(outPath)
        catch {
            fileSize := 0
        }
        if (written <= 0 || fileSize <= 0)
            return Map("ok", false, "message", "下载结果为空（0字节）", "bytes", written, "total", total, "path", outPath)
        ; 防止拿到代理错误页/重定向空壳：压缩包通常至少数 MB。
        if (fileSize < 256 * 1024)
            return Map("ok", false, "message", "下载文件过小，疑似网络受限或返回错误页（" . Round(fileSize / 1024, 1) . "KB）", "bytes", written, "total", total, "path", outPath)
        return Map("ok", true, "bytes", written, "total", total, "path", outPath)
    } catch as e {
        return Map("ok", false, "message", "下载失败: " . e.Message)
    } finally {
        try (f ? f.Close() : 0)
        try (hRequest ? DllCall("winhttp\WinHttpCloseHandle", "Ptr", hRequest) : 0)
        try (hConnect ? DllCall("winhttp\WinHttpCloseHandle", "Ptr", hConnect) : 0)
        try (hSession ? DllCall("winhttp\WinHttpCloseHandle", "Ptr", hSession) : 0)
    }
}

SelectionSense_HubDictInstall_DownloadByBuiltin(url, savePath, statusCb := 0) {
    u := Trim(String(url))
    outPath := Trim(String(savePath))
    if (u = "")
        return Map("ok", false, "message", "下载地址为空")
    if (outPath = "")
        return Map("ok", false, "message", "下载目标路径为空")
    try {
        SplitPath(outPath, , &outDir)
        if (outDir != "" && !DirExist(outDir))
            DirCreate(outDir)
        if FileExist(outPath)
            FileDelete(outPath)
        if IsObject(statusCb)
            statusCb.Call("正在下载词典包（内置通道）...")
        Download(u, outPath)
        sz := 0
        try sz := FileGetSize(outPath)
        catch {
            sz := 0
        }
        if (sz <= 0)
            return Map("ok", false, "message", "内置下载结果为空（0字节）")
        if (sz < 256 * 1024)
            return Map("ok", false, "message", "内置下载文件过小，疑似错误页（" . Round(sz / 1024, 1) . "KB）")
        return Map("ok", true, "bytes", sz, "total", sz, "path", outPath)
    } catch as e {
        return Map("ok", false, "message", "内置下载失败: " . e.Message)
    }
}

SelectionSense_HubDictInstall_InspectArchive(zipPath) {
    z := Trim(String(zipPath))
    if (z = "" || !FileExist(z))
        return Map("ok", false, "message", "压缩包不存在")
    sevenZip := A_ScriptDir "\lib\7z.exe"
    if !FileExist(sevenZip)
        return Map("ok", false, "message", "未找到 7z.exe")
    workDir := A_ScriptDir "\cache\dict_install"
    if !DirExist(workDir)
        DirCreate(workDir)
    listLog := workDir "\7z_list.log"
    try FileDelete(listLog)
    catch {
    }
    cmd := '"' . sevenZip . '" l -slt -ba -- "' . z . '" > "' . listLog . '" 2>&1'
    rc := RunWait(A_ComSpec . " /c " . cmd, , "Hide")
    txt := ""
    try txt := FileRead(listLog, "UTF-8")
    catch {
        txt := ""
    }
    if (rc > 1)
        return Map("ok", false, "message", "压缩包列表失败(7z退出码:" . rc . ")", "list", txt, "hasDb", false, "isStardictRaw", false)
    hasDb := RegExMatch(txt, "im)^Path\s*=\s*.+\.(db|sqlite|sqlite3|db3)\s*$") ? true : false
    hasIfo := RegExMatch(txt, "im)^Path\s*=\s*.+\.ifo\s*$") ? true : false
    hasIdx := RegExMatch(txt, "im)^Path\s*=\s*.+\.idx\s*$") ? true : false
    hasDict := RegExMatch(txt, "im)^Path\s*=\s*.+\.dict(\.dz)?\s*$") ? true : false
    isStardictRaw := (!hasDb && hasIfo && hasIdx && hasDict)
    return Map("ok", true, "message", "", "list", txt, "hasDb", hasDb, "isStardictRaw", isStardictRaw)
}

SelectionSense_HubDictInstall_ReportLine(reportPath, text) {
    rp := Trim(String(reportPath))
    if (rp = "")
        return
    line := "[" . A_Now . "] " . String(text) . "`r`n"
    try FileAppend(line, rp, "UTF-8")
}

SelectionSense_HubDictInstall_FindFallbackExistingDb() {
    candidates := []
    root1 := A_ScriptDir "\cache\dict_install"
    if DirExist(root1)
        candidates.Push(root1)
    up := EnvGet("USERPROFILE")
    if (Trim(String(up)) != "") {
        dl := up "\Downloads"
        if DirExist(dl)
            candidates.Push(dl)
        desk := up "\Desktop"
        if DirExist(desk)
            candidates.Push(desk)
    }
    bestPath := ""
    bestTs := ""
    for _, root in candidates {
        Loop Files, root "\*.db", "R" {
            nm := StrLower(A_LoopFileName)
            if !(InStr(nm, "ultimate") || InStr(nm, "ecdict") || InStr(nm, "stardict"))
                continue
            if (bestTs = "" || A_LoopFileTimeModified > bestTs) {
                bestTs := A_LoopFileTimeModified
                bestPath := A_LoopFileFullPath
            }
        }
        Loop Files, root "\*.sqlite", "R" {
            nm := StrLower(A_LoopFileName)
            if !(InStr(nm, "ultimate") || InStr(nm, "ecdict") || InStr(nm, "stardict"))
                continue
            if (bestTs = "" || A_LoopFileTimeModified > bestTs) {
                bestTs := A_LoopFileTimeModified
                bestPath := A_LoopFileFullPath
            }
        }
        Loop Files, root "\*.sqlite3", "R" {
            nm := StrLower(A_LoopFileName)
            if !(InStr(nm, "ultimate") || InStr(nm, "ecdict") || InStr(nm, "stardict"))
                continue
            if (bestTs = "" || A_LoopFileTimeModified > bestTs) {
                bestTs := A_LoopFileTimeModified
                bestPath := A_LoopFileFullPath
            }
        }
        Loop Files, root "\*.db3", "R" {
            nm := StrLower(A_LoopFileName)
            if !(InStr(nm, "ultimate") || InStr(nm, "ecdict") || InStr(nm, "stardict"))
                continue
            if (bestTs = "" || A_LoopFileTimeModified > bestTs) {
                bestTs := A_LoopFileTimeModified
                bestPath := A_LoopFileFullPath
            }
        }
    }
    return bestPath
}

SelectionSense_HubDict_InstallEcdictOneClick() {
    global g_SelSense_HubDictInstallBusy
    if g_SelSense_HubDictInstallBusy
        return Map("ok", false, "message", "安装任务正在执行中")
    g_SelSense_HubDictInstallBusy := true
    try {
        ; 优先使用 SQLite 镜像包；stardict 原始包不含 sqlite db。
        urls := [
            "https://ghproxy.net/https://github.com/skywind3000/ECDICT-ultimate/releases/download/1.0.0/ecdict-ultimate-sqlite.zip",
            "https://github.com/skywind3000/ECDICT/releases/download/1.0.28/ecdict-sqlite-28.zip",
            "https://github.com/skywind3000/ECDICT/releases/download/1.0.28/ecdict-stardict-28.zip"
        ]
        workDir := A_ScriptDir "\cache\dict_install"
        zipPath := workDir "\ecdict-package.zip"
        extractDir := workDir "\dict-package"
        finalDb := A_ScriptDir "\ultimate.db"
        reportPath := workDir "\install_report.txt"

        if !DirExist(workDir)
            DirCreate(workDir)
        try FileDelete(reportPath)
        catch {
        }
        SelectionSense_HubDictInstall_ReportLine(reportPath, "启动一键安装流程")
        SelectionSense_HubDictInstall_ReportLine(reportPath, "工作目录: " . workDir)
        SelectionSense_HubDictInstall_ReportLine(reportPath, "压缩包路径: " . zipPath)
        SelectionSense_HubDictInstall_ReportLine(reportPath, "解压目录: " . extractDir)
        SelectionSense_HubDictInstall_ReportLine(reportPath, "最终数据库路径: " . finalDb)
        if !DirExist(extractDir)
            DirCreate(extractDir)

        SelectionSense_HubDictInstall_RunJs(5, "准备下载词典...")
        statusCb := (msg) => SelectionSense_HubDictInstall_RunJs(15, msg)
        dl := 0
        downloadErrors := []
        packageReady := false
        selectedUrl := ""
        for idx, url in urls {
            SelectionSense_HubDictInstall_RunJs(15, "正在下载词典包...")
            SelectionSense_HubDictInstall_ReportLine(reportPath, "尝试源" . idx . ": " . url)
            dl := SelectionSense_HubDictInstall_DownloadByBuiltin(url, zipPath, statusCb)
            if (dl.Has("ok") && dl["ok"]) {
                SelectionSense_HubDictInstall_RunJs(55, "下载完成，正在校验文件...")
                SelectionSense_HubDictInstall_ReportLine(reportPath, "源" . idx . "下载成功，大小: " . (dl.Has("bytes") ? String(dl["bytes"]) : "?") . " bytes")
                info := SelectionSense_HubDictInstall_InspectArchive(zipPath)
                if !(info.Has("ok") && info["ok"]) {
                    errMsg := info.Has("message") ? String(info["message"]) : "压缩包检测失败"
                    downloadErrors.Push("源" . idx . ": " . errMsg)
                    SelectionSense_HubDictInstall_ReportLine(reportPath, "源" . idx . "包体检测失败: " . errMsg)
                } else {
                    SelectionSense_HubDictInstall_ReportLine(reportPath, "源" . idx . "包体检测: hasDb=" . (info["hasDb"] ? "true" : "false") . ", isStardictRaw=" . (info["isStardictRaw"] ? "true" : "false"))
                }
                packageReady := true
                selectedUrl := url
                SelectionSense_HubDictInstall_ReportLine(reportPath, "选定下载源: " . selectedUrl)
                break
            }
            errMsg := dl.Has("message") ? String(dl["message"]) : "下载失败"
            downloadErrors.Push("源" . idx . ": " . errMsg)
            SelectionSense_HubDictInstall_ReportLine(reportPath, "源" . idx . "下载失败: " . errMsg)
            Sleep(120)
        }
        if !packageReady {
            mergedErr := "下载词典失败，请稍后重试"
            SelectionSense_HubDictInstall_ReportLine(reportPath, "终止: 没有任何下载源提供可用 sqlite 包")
            return Map("ok", false, "message", mergedErr)
        }

        SelectionSense_HubDictInstall_RunJs(72, "正在解压词典...")
        sevenZip := A_ScriptDir "\lib\7z.exe"
        if !FileExist(sevenZip)
            return Map("ok", false, "message", "缺少解压组件，无法安装词典")
        if !FileExist(zipPath)
            return Map("ok", false, "message", "下载包不存在，安装失败")
        ; 先清理旧解压目录，避免因覆盖/同名导致 7z 返回 warning(1)。
        try DirDelete(extractDir, 1)
        catch {
        }
        if !DirExist(extractDir)
            DirCreate(extractDir)

        ; 定向提取数据库文件，避免目录结构/警告导致“已解压但未命中”。
        cmdDb := '"' . sevenZip . '" e -y -aoa -o"' . extractDir . '" -- "' . zipPath . '" "ultimate.db" "*.sqlite" "*.sqlite3" "*.db3" "*.db"'
        rc := RunWait(cmdDb, , "Hide")
        SelectionSense_HubDictInstall_ReportLine(reportPath, "7z 定向提取(db)退出码: " . rc)

        foundDb := SelectionSense_HubDictInstall_FindDb(extractDir)
        if (foundDb = "") {
            ; 回退到完整解压，再次探测。
            cmdAll := '"' . sevenZip . '" x -y -aoa -o"' . extractDir . '" -- "' . zipPath . '"'
            rcAll := RunWait(cmdAll, , "Hide")
            SelectionSense_HubDictInstall_ReportLine(reportPath, "7z 全量解压退出码: " . rcAll)
            foundDb := SelectionSense_HubDictInstall_FindDb(extractDir)
            rc := rcAll
        }
        SelectionSense_HubDictInstall_ReportLine(reportPath, "数据库探测结果: " . (foundDb != "" ? foundDb : "[未命中]"))
        if (foundDb = "") {
            try {
                listing := ""
                Loop Files, extractDir "\*.*", "R" {
                    listing .= A_LoopFileFullPath . "`r`n"
                    if (StrLen(listing) > 2000)
                        break
                }
                if (listing != "")
                    SelectionSense_HubDictInstall_ReportLine(reportPath, "解压目录文件样本:`r`n" . listing)
            } catch {
            }
            return Map("ok", false, "message", "词典包解压失败，请稍后重试")
        }
        SelectionSense_HubDictInstall_RunJs(84, "正在写入词典...")
        try FileCopy(foundDb, finalDb, 1)
        catch as e {
            SelectionSense_HubDictInstall_ReportLine(reportPath, "写入 ultimate.db 失败: " . e.Message)
            return Map("ok", false, "message", "写入词典失败")
        }
        SelectionSense_HubDictInstall_ReportLine(reportPath, "数据库复制成功: " . finalDb)

        SelectionSense_HubDictInstall_RunJs(90, "正在导入词典...")
        importRet := SelectionSense_HubDict_ImportSqlite(finalDb)
        if !(importRet.Has("ok") && importRet["ok"]) {
            SelectionSense_HubDictInstall_ReportLine(reportPath, "导入失败: " . (importRet.Has("message") ? String(importRet["message"]) : "导入失败"))
            return Map("ok", false, "message", "词典导入失败")
        }
        SelectionSense_HubDictInstall_ReportLine(reportPath, "导入成功")

        SelectionSense_HubDictInstall_RunJs(96, "正在激活词典...")
        SelectionSense_HubDictInstall_CallSQ3Open(finalDb)
        SelectionSense_HubDictInstall_ReportLine(reportPath, "调用 SQ3_Open 完成")
        return Map("ok", true, "message", "本地词库已激活")
    } finally {
        g_SelSense_HubDictInstallBusy := false
    }
}

SelectionSense_HubDict_InstallEcdictOneClick_AsyncStart() {
    global g_SelSense_HubDictInstallBusy, g_SelSense_HubDictInstallQueued
    if g_SelSense_HubDictInstallBusy || g_SelSense_HubDictInstallQueued
        return false
    g_SelSense_HubDictInstallQueued := true
    SetTimer(SelectionSense_HubDict_InstallEcdictOneClick_AsyncWorker, -10)
    return true
}

SelectionSense_HubDict_InstallEcdictOneClick_AsyncWorker(*) {
    global g_SelSense_HubDictInstallQueued, g_SelSense_MenuWV2
    g_SelSense_HubDictInstallQueued := false
    ret0 := SelectionSense_HubDict_InstallEcdictOneClick()
    ok0 := ret0.Has("ok") ? !!ret0["ok"] : false
    msg0 := ret0.Has("message") ? String(ret0["message"]) : (ok0 ? "本地词库已激活" : "安装失败")
    if ok0
        SelectionSense_HubDictInstall_RunJs(100, "本地词库已激活")
    else
        SelectionSense_HubDictInstall_RunJs(100, "安装失败: " . msg0)
    try WebView_QueuePayload(g_SelSense_MenuWV2, Map(
        "type", "hub_translate_sqlite_dict_state",
        "ok", ok0,
        "message", msg0,
        "activeSourceId", SelectionSense_HubDict_GetActiveSource(),
        "sources", SelectionSense_HubDict_ListSources()
    ))
}

SelectionSense_HubDragClampToVirtual(&nx, &ny, ww, hh) {
    ScreenVirtual_GetBounds(&vl, &vt, &vw, &vh)
    vr := vl + vw
    vb := vt + vh
    if (nx < vl)
        nx := vl
    if (ny < vt)
        ny := vt
    if (nx + ww > vr)
        nx := vr - ww
    if (ny + hh > vb)
        ny := vb - hh
}

SelectionSense_HubDragApplyBoundsNotify() {
    global g_SelSense_MenuCtrl
    SelectionSense_ApplyMenuBounds()
    try g_SelSense_MenuCtrl.NotifyParentWindowPositionChanged()
    catch as _e {
    }
}

SelectionSense_HubCapsule_IniPath() {
    return (IsSet(ConfigFile) && ConfigFile != "") ? ConfigFile : (A_ScriptDir "\CursorShortcut.ini")
}

SelectionSense_GetHubCapsuleDefaultSize(&outW, &outH) {
    outW := 420
    outH := 560
    try {
        CoordMode("Mouse", "Screen")
        MouseGetPos(&mx, &my)
        mon := SelectionSense_MonitorFromPoint(mx, my)
        MonitorGetWorkArea(mon, &l, &t, &r, &b)
        workW := r - l
        workH := b - t
        outW := Min(Max(420, Floor(workW * 0.34)), 560)
        outH := Min(Max(560, Floor(workH * 0.82)), 980)
    } catch as _e {
        outW := 420
        outH := Max(560, Floor(A_ScreenHeight * 0.78))
    }
}

SelectionSense_MonitorFromPoint(x, y) {
    count := 1
    try count := MonitorGetCount()
    Loop count {
        idx := A_Index
        try {
            MonitorGet(idx, &l, &t, &r, &b)
            if (x >= l && x < r && y >= t && y < b)
                return idx
        } catch as _e {
        }
    }
    return 1
}

SelectionSense_HubCapsule_ReadSavedPos(&outX, &outY, &outOk) {
    outOk := false
    outX := 0
    outY := 0
    cfg := SelectionSense_HubCapsule_IniPath()
    try {
        xs := IniRead(cfg, "WindowPositions", "HubCapsule_X", "")
        ys := IniRead(cfg, "WindowPositions", "HubCapsule_Y", "")
        if (xs = "" || xs = "ERROR" || ys = "" || ys = "ERROR")
            return
        xi := Integer(xs)
        yi := Integer(ys)
        if (Abs(xi) > 40000 || Abs(yi) > 40000)
            return
        outX := xi
        outY := yi
        outOk := true
    } catch as _e {
        outOk := false
    }
}

; 淇濆瓨鐨勫乏涓婅 + 褰撳墠绐楀彛灏哄鏄惁浠嶈惤鍦ㄨ櫄鎷熷睆骞曞唴锛堥伩鍏嶅鏄剧ず鍣?鍒嗚鲸鐜囧彉鍖栧悗绐楀彛鈥滃湪灞忓鈥濓級
SelectionSense_HubSavedRectIsOnScreen(sx, sy, ww, hh) {
    if (ww < 1 || hh < 1)
        return false
    ScreenVirtual_GetBounds(&vl, &vt, &vw, &vh)
    vr := vl + vw
    vb := vt + vh
    if (sx >= vr || sx + ww <= vl)
        return false
    if (sy >= vb || sy + hh <= vt)
        return false
    return true
}

SelectionSense_HubCapsule_WriteSavedPos() {
    global g_SelSense_MenuGui, g_SelSense_MenuShowingHub
    if !(g_SelSense_MenuGui && g_SelSense_MenuShowingHub)
        return
    try {
        g_SelSense_MenuGui.GetPos(&px, &py)
        cfg := SelectionSense_HubCapsule_IniPath()
        IniWrite(px, cfg, "WindowPositions", "HubCapsule_X")
        IniWrite(py, cfg, "WindowPositions", "HubCapsule_Y")
    } catch as _e {
    }
}

SelectionSense_CopyDelayMsEffective() {
    global g_SelSense_CopyDelayMs
    base := g_SelSense_CopyDelayMs
    extra := 0
    try {
        exe := StrLower(WinGetProcessName("A"))
        if InStr(exe, "cursor") || InStr(exe, "code") || InStr(exe, "electron")
            extra := 35
    } catch as _e {
    }
    return base + extra
}

SelectionSense_GetLastSelectedText() {
    global g_SelSense_LastFullText, g_SelSense_LastTick
    if (g_SelSense_LastTick = 0 || (A_TickCount - g_SelSense_LastTick > 120000))
        return ""
    return g_SelSense_LastFullText
}

SelectionSense_ClearLastSelected(*) {
    global g_SelSense_LastFullText, g_SelSense_LastTick
    g_SelSense_LastFullText := ""
    g_SelSense_LastTick := 0
}

SelectionSense_OnToolbarSearchClick() {
    t := Trim(SelectionSense_GetLastSelectedText())
    if (t != "")
        SearchCenter_RunQueryWithKeyword(t)
    else
        ShowSearchCenter()
}

SelectionSense_LoadIni() {
    global g_SelSense_Enabled, g_SelSense_CopyDelayMs, g_SelSense_RequireIBeam, g_SelSense_ClipWaitSec, g_SelSense_HubCopyTriggerMode
    cfg := (IsSet(ConfigFile) && ConfigFile != "") ? ConfigFile : (A_ScriptDir "\CursorShortcut.ini")
    try {
        g_SelSense_Enabled := (IniRead(cfg, "SelectionSense", "Enable", "1") != "0")
        g_SelSense_CopyDelayMs := Integer(IniRead(cfg, "SelectionSense", "CopyDelayMs", "55"))
        ; Cursor/VS Code/Electron may use custom cursors; default does not require IBeam.
        g_SelSense_RequireIBeam := (IniRead(cfg, "SelectionSense", "RequireIBeam", "0") = "1")
        mode := Trim(StrLower(IniRead(cfg, "SelectionSense", "HubCopyTriggerMode", "capslock")))
        ; 鍏煎鏃у€?single锛氳縼绉诲埌 capslock
        g_SelSense_HubCopyTriggerMode := (mode = "double") ? "double" : "capslock"
        w := IniRead(cfg, "SelectionSense", "ClipWaitSec", "")
        if (w != "" && w != "ERROR") {
            f := Float(w)
            if (f >= 0.1 && f <= 2.0)
                g_SelSense_ClipWaitSec := f
        }
    } catch as _e {
        g_SelSense_Enabled := true
        g_SelSense_CopyDelayMs := 55
        g_SelSense_RequireIBeam := false
        g_SelSense_HubCopyTriggerMode := "capslock"
    }
    if (g_SelSense_CopyDelayMs < 20)
        g_SelSense_CopyDelayMs := 20
    if (g_SelSense_CopyDelayMs > 200)
        g_SelSense_CopyDelayMs := 200
}

SelectionSense_SetHubCopyTriggerMode(mode) {
    global g_SelSense_HubCopyTriggerMode
    m := Trim(StrLower(String(mode)))
    g_SelSense_HubCopyTriggerMode := (m = "double") ? "double" : "capslock"
    cfg := (IsSet(ConfigFile) && ConfigFile != "") ? ConfigFile : (A_ScriptDir "\CursorShortcut.ini")
    try IniWrite(g_SelSense_HubCopyTriggerMode, cfg, "SelectionSense", "HubCopyTriggerMode")
}

; Gui object may throw before show; guard hwnd compare with try/catch.
SelectionSense_GuiHwndMatches(guiObj, hwnd) {
    if !hwnd || !IsObject(guiObj)
        return false
    try return (hwnd = guiObj.Hwnd)
    catch as _e {
        return false
    }
}

SelectionSense_IsKnownGuiRoot(hwnd) {
    if !hwnd
        return false
    global FloatingToolbarGUI, g_SCWV_Gui, g_CP_Gui, g_VK_Gui, g_PQP_Gui, g_SelSense_MenuGui
    global AIListPanelGUI, GuiID_ConfigGUI, GuiID_SearchCenter
    if (IsSet(FloatingToolbarGUI) && FloatingToolbarGUI && SelectionSense_GuiHwndMatches(FloatingToolbarGUI, hwnd))
        return true
    if (IsSet(g_SCWV_Gui) && g_SCWV_Gui && SelectionSense_GuiHwndMatches(g_SCWV_Gui, hwnd))
        return true
    if (IsSet(g_CP_Gui) && g_CP_Gui && SelectionSense_GuiHwndMatches(g_CP_Gui, hwnd))
        return true
    if (IsSet(g_VK_Gui) && g_VK_Gui && SelectionSense_GuiHwndMatches(g_VK_Gui, hwnd))
        return true
    if (IsSet(g_PQP_Gui) && g_PQP_Gui && SelectionSense_GuiHwndMatches(g_PQP_Gui, hwnd))
        return true
    if (IsSet(g_SelSense_MenuGui) && g_SelSense_MenuGui && SelectionSense_GuiHwndMatches(g_SelSense_MenuGui, hwnd))
        return true
    if (IsSet(AIListPanelGUI) && AIListPanelGUI && SelectionSense_GuiHwndMatches(AIListPanelGUI, hwnd))
        return true
    if (IsSet(GuiID_ConfigGUI) && GuiID_ConfigGUI && SelectionSense_GuiHwndMatches(GuiID_ConfigGUI, hwnd))
        return true
    if (IsSet(GuiID_SearchCenter) && GuiID_SearchCenter && SelectionSense_GuiHwndMatches(GuiID_SearchCenter, hwnd))
        return true
    return false
}

SelectionSense_CursorOverOurUi() {
    MouseGetPos(, , &hWin)
    cur := hWin
    loop 14 {
        if SelectionSense_IsKnownGuiRoot(cur)
            return true
        cur := DllCall("GetParent", "ptr", cur, "ptr")
        if !cur
            break
    }
    return false
}

SelectionSense_IsIBeamCursor() {
    h := DllCall("user32\GetCursor", "ptr")
    if !h
        return false
    ibeam := DllCall("user32\LoadCursorW", "ptr", 0, "ptr", 32513, "ptr")
    return (h = ibeam)
}

global g_SelSense_LButtonDownX := 0
global g_SelSense_LButtonDownY := 0
global g_SelSense_LButtonDownTick := 0
global g_SelSense_LButtonClicks := 0

SelectionSense_OnLButtonDown(*) {
    global g_SelSense_LButtonDownX, g_SelSense_LButtonDownY, g_SelSense_LButtonDownTick, g_SelSense_LButtonClicks
    CoordMode("Mouse", "Screen")
    MouseGetPos(&g_SelSense_LButtonDownX, &g_SelSense_LButtonDownY)
    if (A_TickCount - g_SelSense_LButtonDownTick < 400) {
        g_SelSense_LButtonClicks += 1
    } else {
        g_SelSense_LButtonClicks := 1
    }
    g_SelSense_LButtonDownTick := A_TickCount
}

SelectionSense_OnLButtonUp(*) {
    global g_SelSense_Enabled, g_SelSense_RequireIBeam
    global g_SelSense_LButtonDownX, g_SelSense_LButtonDownY, g_SelSense_LButtonClicks, g_SelSense_LButtonDownTick
    if !g_SelSense_Enabled
        return
    if SelectionSense_CursorOverOurUi()
        return
    if g_SelSense_RequireIBeam && !SelectionSense_IsIBeamCursor()
        return
        
    CoordMode("Mouse", "Screen")
    MouseGetPos(&upX, &upY)
    distX := Abs(upX - g_SelSense_LButtonDownX)
    distY := Abs(upY - g_SelSense_LButtonDownY)
    
    isDrag := (distX > 3 || distY > 3)
    isMultiClick := (g_SelSense_LButtonClicks >= 2 && (A_TickCount - g_SelSense_LButtonDownTick < 400))
    
    if !(isDrag || isMultiClick) {
        try FloatingToolbar_NotifySelectionClear()
        return
    }

    SetTimer(SelectionSense_ProcessDeferred, -1)
}

SelectionSense_ProcessDeferred(*) {
    global g_SelSense_Enabled, g_SelSense_LastClipSig, g_SelSense_LastFireTick
    global g_SelSense_LastFullText, g_SelSense_LastTick, g_SelSense_UserCopyInProgress, g_SelSense_UserCopyEndTick
    global g_SelSense_ClipWaitSec, CapsLockCopyInProgress

    if !g_SelSense_Enabled
        return
    if SelectionSense_CursorOverOurUi()
        return
    ; 鐢ㄦ埛涓诲姩 Ctrl+C 鍚庝竴娈垫椂闂村唴璺宠繃妯℃嫙 ^c锛岄伩鍏嶄笌缂栬緫鍣ㄥ唴澶嶅埗/绮樿创鎶㈠壀璐存澘
    if (g_SelSense_UserCopyInProgress || (A_TickCount - g_SelSense_UserCopyEndTick < 950))
        return
    if (CapsLockCopyInProgress)
        return

    ; Only when Hub is open and Cursor editor has focus do we simulate ^c for preview refresh.
    if !(SelectionSense_HubCapsuleHostIsOpen() && SelectionSense_IsCursorEditorActive()) {
        SelectionSense_ClearLastSelected()
        try FloatingToolbar_NotifySelectionClear()
        catch as _e {
        }
        return
    }

    clipSaved := ""
    try clipSaved := ClipboardAll()
    catch as _e {
        clipSaved := ""
    }

    A_Clipboard := ""
    try Send("^c")
    catch as _sendErr {
        try {
            if (clipSaved != "")
                A_Clipboard := clipSaved
        } catch as _e2 {
        }
        return
    }

    Sleep(SelectionSense_CopyDelayMsEffective())
    try ClipWait(g_SelSense_ClipWaitSec)
    catch as _e {
    }
    got := ""
    try got := A_Clipboard
    catch as _e {
        got := ""
    }

    text := ""
    try text := String(got)
    catch as _e {
        text := ""
    }
    text := Trim(text, " `t`r`n")
    if (text = "") {
        try {
            if (clipSaved != "")
                A_Clipboard := clipSaved
        } catch as _e {
        }
        SelectionSense_ClearLastSelected()
        try FloatingToolbar_NotifySelectionClear()
        catch as _e {
        }
        return
    }

    sig := StrLen(text) . ":" . SubStr(text, 1, 24)
    if (sig = g_SelSense_LastClipSig && (A_TickCount - g_SelSense_LastFireTick < 400))
        return
    g_SelSense_LastClipSig := sig
    g_SelSense_LastFireTick := A_TickCount

    g_SelSense_LastFullText := text
    g_SelSense_LastTick := A_TickCount

    try FloatingToolbar_NotifySelectionChange(text)
    catch as _e {
    }
    SelectionSense_QueueHubPreviewUpdate(text)
}

SelectionSense_EnsureMenuHost() {
    global g_SelSense_MenuGui, g_SelSense_MenuCtrl, g_SelSense_MenuWV2, g_SelSense_MenuReady

    if g_SelSense_MenuGui
        return

    global g_SelSense_MenuW, g_SelSense_MenuH
    ; +Resize锛欻ubCapsule 鍙充笅瑙掓嫋鏉′緷璧?AHK 鍚屾瀹夸富瀹介珮锛坔ub_resize_move / hub_resize_end锛?    ; 鍕跨敤 +E0x80000锛氭湭璋冪敤 SetLayeredWindowAttributes 鏃?WS_EX_LAYERED 浼氬鑷?WebView2 鏃犳硶鍛戒腑榧犳爣
    g_SelSense_MenuGui := Gui("+AlwaysOnTop +Resize +MinSize200x160 +MinimizeBox +MaximizeBox -DPIScale", "SelectionMenuHost")
    g_SelSense_MenuGui.BackColor := "1a1a1a"
    g_SelSense_MenuGui.MarginX := 0
    g_SelSense_MenuGui.MarginY := 0
    g_SelSense_MenuGui.Show("w" . g_SelSense_MenuW . " h" . g_SelSense_MenuH . " Hide")
    g_SelSense_MenuGui.OnEvent("Close", (*) => SelectionSense_HideMenu())
    g_SelSense_MenuGui.OnEvent("Size", SelectionSense_OnMenuHostSize)

    WebView2.create(g_SelSense_MenuGui.Hwnd, SelectionSense_OnMenuWebViewCreated)
}

SelectionSense_OnMenuHostSize(*) {
    SelectionSense_ApplyMenuBounds()
}

SelectionSense_OnMenuWebViewCreated(ctrl) {
    global g_SelSense_MenuCtrl, g_SelSense_MenuWV2, g_SelSense_MenuReady

    g_SelSense_MenuCtrl := ctrl
    g_SelSense_MenuWV2 := ctrl.CoreWebView2
    g_SelSense_MenuReady := false

    try ctrl.DefaultBackgroundColor := 0
    try ctrl.IsVisible := true

    SelectionSense_ApplyMenuBounds()

    s := g_SelSense_MenuWV2.Settings
    s.AreDefaultContextMenusEnabled := false
    s.IsStatusBarEnabled := false
    s.AreDevToolsEnabled := false

    g_SelSense_MenuWV2.add_WebMessageReceived(SelectionSense_OnMenuWebMessage)
    try ApplyUnifiedWebViewAssets(g_SelSense_MenuWV2)
    global g_SelSense_NextNavPage, g_SelSense_MenuShowingHub
    page := (g_SelSense_NextNavPage != "") ? g_SelSense_NextNavPage : "SelectionMenu.html"
    g_SelSense_NextNavPage := ""
    g_SelSense_MenuShowingHub := (page = "HubCapsule.html")
    g_SelSense_MenuWV2.Navigate(BuildAppLocalUrl(page))
}

SelectionSense_ApplyMenuBounds() {
    global g_SelSense_MenuGui, g_SelSense_MenuCtrl
    if !g_SelSense_MenuGui || !g_SelSense_MenuCtrl
        return
    WinGetClientPos(, , &cw, &ch, g_SelSense_MenuGui.Hwnd)
    rc := WebView2.RECT()
    rc.left := 0
    rc.top := 0
    rc.right := cw
    rc.bottom := ch
    try {
        g_SelSense_MenuCtrl.Bounds := rc
        g_SelSense_MenuCtrl.NotifyParentWindowPositionChanged()
    } catch as _e {
    }
}

SelectionSense_ApplyMenuOuterSize(nw, nh) {
    global g_SelSense_MenuGui, g_SelSense_MenuCtrl, g_SelSense_MenuW, g_SelSense_MenuH
    if (nw < 200)
        nw := 200
    if (nh < 160)
        nh := 160
    g_SelSense_MenuW := nw
    g_SelSense_MenuH := nh
    if !g_SelSense_MenuGui
        return
    g_SelSense_MenuGui.GetPos(&x, &y)
    try g_SelSense_MenuGui.Move(x, y, nw, nh)
    SelectionSense_ApplyMenuBounds()
}

SelectionSense_OnMenuWebMessage(sender, args) {
    jsonStr := args.WebMessageAsJson
    try msg := Jxon_Load(jsonStr)
    catch {
        return
    }
    if (msg is String) {
        try msg := Jxon_Load(msg)
        catch {
            return
        }
    }
    if !(msg is Map)
        return

    typ := msg.Has("type") ? String(msg["type"]) : ""
    if (typ = "selection_menu_ready") {
        global g_SelSense_MenuReady, g_SelSense_MenuVisible, g_SelSense_PendingText, g_SelSense_HubCopyTriggerMode, g_SelSense_MenuWV2
        global g_SelSense_PendingHubSegments, g_SelSense_MenuShowingHub
        g_SelSense_MenuReady := true
        try WebView_QueuePayload(g_SelSense_MenuWV2, Map("type", "hub_preview_state", "copyTriggerMode", g_SelSense_HubCopyTriggerMode))
        ; Both SelectionMenu and HubCapsule emit selection_menu_ready.
        ; Flush pending segments only when current page is HubCapsule.
        if g_SelSense_MenuShowingHub
            SelectionSense_HubCapsule_FlushPendingSegments()
        if g_SelSense_MenuVisible {
            SelectionSense_PushMenuText(g_SelSense_PendingText)
            ; HubCapsule: send hub_preview again to avoid init race misses.
            if g_SelSense_MenuShowingHub && Trim(String(g_SelSense_PendingText)) != ""
                SelectionSense_PushHubPreviewText(g_SelSense_PendingText)
        }
        if g_SelSense_MenuShowingHub
            SelectionSense_PushHubCtxMenuSpec()
        return
    }
    if (typ = "hub_ready") {
        ; HubCapsule 鏄庣‘灏辩华锛氳ˉ鍙戝緟鎺ㄩ€佹钀?        SelectionSense_HubCapsule_FlushPendingSegments()
        SelectionSense_PushHubCtxMenuSpec()
        return
    }
    if (typ = "openWindowsRecycleBin") {
        SCWV_OpenWindowsRecycleBinFolder()
        return
    }

    txt := msg.Has("text") ? String(msg["text"]) : ""

    if (typ = "hub_stack_selected") {
        global g_HubCapsule_SelectedText
        t2 := msg.Has("text") ? String(msg["text"]) : ""
        g_HubCapsule_SelectedText := t2
        return
    }

    if (typ = "selection_menu_search") {
        SelectionSense_HideMenu()
        if (Trim(txt) != "")
            SearchCenter_RunQueryWithKeyword(txt)
        return
    }
    if (typ = "selection_menu_ai") {
        SelectionSense_HideMenu()
        try PromptQuickPad_OpenCaptureDraft(txt, true)
        catch {
        }
        return
    }
    if (typ = "selection_menu_dismiss") {
        SelectionSense_HideMenu()
        return
    }
    if (typ = "hub_search") {
        SelectionSense_HideMenu()
        t2 := msg.Has("text") ? Trim(String(msg["text"])) : ""
        if (t2 != "")
            SearchCenter_RunQueryWithKeyword(t2)
        return
    }
    if (typ = "hub_ai") {
        ; 浜屾湡鍙€夛細澶栭摼 AI锛堢墰椹?PQP锛夊畬鎴愬悗鐢卞涓?WebView_QueuePayload draft_collect 鍥?Hub锛屽苟閰嶅悎鐢ㄦ埛寮€鍏宠嚜鍔ㄥ叆鑽夌
        SelectionSense_HideMenu()
        t2 := msg.Has("text") ? Trim(String(msg["text"])) : ""
        if (t2 != "") {
            sent := false
            try sent := SelectionSense_SendToNiumaChatAndSubmit(t2)
            catch as _e {
                sent := false
            }
            if !sent {
                try PromptQuickPad_OpenCaptureDraft(t2, true)
                catch as _e {
                }
            }
        }
        return
    }
    if (typ = "hub_set_copy_trigger_mode") {
        global g_SelSense_HubCopyTriggerMode, g_SelSense_MenuWV2
        mode := msg.Has("mode") ? String(msg["mode"]) : "capslock"
        SelectionSense_SetHubCopyTriggerMode(mode)
        try WebView_QueuePayload(g_SelSense_MenuWV2, Map("type", "hub_preview_state", "copyTriggerMode", g_SelSense_HubCopyTriggerMode))
        return
    }
    if (typ = "hub_resize_start") {
        return
    }
    if (typ = "hub_resize_move") || (typ = "hub_resize_end") {
        nw := msg.Has("width") ? Integer(msg["width"]) : 0
        nh := msg.Has("height") ? Integer(msg["height"]) : 0
        if (nw > 0 && nh > 0)
            SelectionSense_ApplyMenuOuterSize(nw, nh)
        return
    }
    if (typ = "hub_mousedown") {
        global g_SelSense_HubMousedownX, g_SelSense_HubMousedownY
        g_SelSense_HubMousedownX := msg.Has("x") ? Integer(msg["x"]) : 0
        g_SelSense_HubMousedownY := msg.Has("y") ? Integer(msg["y"]) : 0
        return
    }
    if (typ = "hub_drag_start") {
        global g_SelSense_MenuGui, g_SelSense_MenuCtrl, g_SelSense_HubDragActive
        global g_SelSense_HubDragRefPtrX, g_SelSense_HubDragRefPtrY, g_SelSense_HubDragRefWinX, g_SelSense_HubDragRefWinY
        global g_SelSense_HubMousedownX, g_SelSense_HubMousedownY
        if !g_SelSense_MenuGui
            return
        px := msg.Has("x") ? Integer(msg["x"]) : 0
        py := msg.Has("y") ? Integer(msg["y"]) : 0
        if (px = 0 && py = 0) {
            px := g_SelSense_HubMousedownX
            py := g_SelSense_HubMousedownY
        }
        if (px = 0 && py = 0) {
            CoordMode("Mouse", "Screen")
            MouseGetPos(&px, &py)
        }
        g_SelSense_MenuGui.GetPos(&wx, &wy, &ww, &hh)
        g_SelSense_HubDragRefPtrX := px
        g_SelSense_HubDragRefPtrY := py
        g_SelSense_HubDragRefWinX := wx
        g_SelSense_HubDragRefWinY := wy
        g_SelSense_HubDragActive := true
        return
    }
    if (typ = "hub_drag_move") {
        global g_SelSense_MenuGui, g_SelSense_MenuCtrl, g_SelSense_HubDragActive
        global g_SelSense_HubDragRefPtrX, g_SelSense_HubDragRefPtrY, g_SelSense_HubDragRefWinX, g_SelSense_HubDragRefWinY
        if !g_SelSense_HubDragActive || !g_SelSense_MenuGui
            return
        px := msg.Has("x") ? Integer(msg["x"]) : 0
        py := msg.Has("y") ? Integer(msg["y"]) : 0
        if (px = 0 && py = 0)
            return
        nx := g_SelSense_HubDragRefWinX + (px - g_SelSense_HubDragRefPtrX)
        ny := g_SelSense_HubDragRefWinY + (py - g_SelSense_HubDragRefPtrY)
        g_SelSense_MenuGui.GetPos(, , &ww, &hh)
        SelectionSense_HubDragClampToVirtual(&nx, &ny, ww, hh)
        try g_SelSense_MenuGui.Move(nx, ny)
        SelectionSense_HubDragApplyBoundsNotify()
        return
    }
    if (typ = "hub_drag_end") {
        global g_SelSense_HubDragActive
        g_SelSense_HubDragActive := false
        SelectionSense_HubDragApplyBoundsNotify()
        SelectionSense_HubCapsule_WriteSavedPos()
        return
    }
    if (typ = "hub_copy") {
        t2 := msg.Has("text") ? String(msg["text"]) : ""
        if (Trim(t2, " `t`r`n") != "")
            A_Clipboard := t2
        return
    }
    if (typ = "hub_copy_image") {
        p := msg.Has("imagePath") ? Trim(String(msg["imagePath"])) : ""
        if (p != "" && FileExist(p)) {
            try {
                pBitmap := Gdip_CreateBitmapFromFile(p)
                if (pBitmap) {
                    A_Clipboard := ""
                    Sleep(30)
                    Gdip_SetBitmapToClipboard(pBitmap)
                    Gdip_DisposeImage(pBitmap)
                }
            } catch as _e {
                try A_Clipboard := p
                catch {
                }
            }
        }
        return
    }
    if (typ = "hub_open_external_url") {
        u := msg.Has("url") ? Trim(String(msg["url"])) : ""
        if (u != "" && RegExMatch(u, "i)^https?://")) {
            try Run(u)
            catch as _e {
            }
        }
        return
    }
    if (typ = "hub_translate_ecdict_install") {
        if !SelectionSense_HubDict_InstallEcdictOneClick_AsyncStart()
            SelectionSense_HubDictInstall_RunJs(2, "安装任务正在执行中，请稍候...")
        return
    }
    if (typ = "hub_translate_sqlite_dict_list") {
        global g_SelSense_MenuWV2
        if !SelectionSense_HubDict_Ensure() {
            try WebView_QueuePayload(g_SelSense_MenuWV2, Map(
                "type", "hub_translate_sqlite_dict_state",
                "ok", false,
                "message", "词典初始化失败",
                "activeSourceId", "builtin_default",
                "sources", []
            ))
            return
        }
        try WebView_QueuePayload(g_SelSense_MenuWV2, Map(
            "type", "hub_translate_sqlite_dict_state",
            "ok", true,
            "message", "",
            "activeSourceId", SelectionSense_HubDict_GetActiveSource(),
            "sources", SelectionSense_HubDict_ListSources()
        ))
        return
    }
    if (typ = "hub_translate_sqlite_dict_import_pick") {
        global g_SelSense_MenuWV2
        picked := ""
        try picked := FileSelect(1, A_ScriptDir, "选择 SQLite 词典文件", "SQLite Files (*.db;*.sqlite;*.sqlite3;*.db3)")
        if (Trim(String(picked)) = "") {
            try WebView_QueuePayload(g_SelSense_MenuWV2, Map(
                "type", "hub_translate_sqlite_dict_state",
                "ok", false,
                "message", "已取消导入",
                "activeSourceId", SelectionSense_HubDict_GetActiveSource(),
                "sources", SelectionSense_HubDict_ListSources()
            ))
            return
        }
        ret := SelectionSense_HubDict_ImportSqlite(picked)
        ok0 := ret.Has("ok") ? !!ret["ok"] : false
        msg0 := ret.Has("message") ? String(ret["message"]) : (ok0 ? "导入完成" : "导入失败")
        try WebView_QueuePayload(g_SelSense_MenuWV2, Map(
            "type", "hub_translate_sqlite_dict_state",
            "ok", ok0,
            "message", msg0,
            "activeSourceId", SelectionSense_HubDict_GetActiveSource(),
            "sources", SelectionSense_HubDict_ListSources()
        ))
        return
    }
    if (typ = "hub_translate_sqlite_dict_delete") {
        global g_SelSense_MenuWV2
        sid0 := msg.Has("sourceId") ? String(msg["sourceId"]) : ""
        ok0 := SelectionSense_HubDict_DeleteSource(sid0)
        msg0 := ok0 ? "词典已删除" : "删除失败（内置词典不可删除）"
        try WebView_QueuePayload(g_SelSense_MenuWV2, Map(
            "type", "hub_translate_sqlite_dict_state",
            "ok", ok0,
            "message", msg0,
            "activeSourceId", SelectionSense_HubDict_GetActiveSource(),
            "sources", SelectionSense_HubDict_ListSources()
        ))
        return
    }
    if (typ = "hub_translate_sqlite_dict_set_active") {
        global g_SelSense_MenuWV2
        sid0 := msg.Has("sourceId") ? String(msg["sourceId"]) : ""
        ok0 := SelectionSense_HubDict_SetActiveSource(sid0)
        msg0 := ok0 ? "已切换词典" : "切换失败"
        try WebView_QueuePayload(g_SelSense_MenuWV2, Map(
            "type", "hub_translate_sqlite_dict_state",
            "ok", ok0,
            "message", msg0,
            "activeSourceId", SelectionSense_HubDict_GetActiveSource(),
            "sources", SelectionSense_HubDict_ListSources()
        ))
        return
    }
    if (typ = "hub_translate_sqlite_lookup") {
        global g_SelSense_MenuWV2
        rid := msg.Has("requestId") ? String(msg["requestId"]) : ""
        dir0 := msg.Has("dir") ? String(msg["dir"]) : "en2zh"
        txt0 := msg.Has("text") ? String(msg["text"]) : ""
        sid0 := msg.Has("sourceId") ? String(msg["sourceId"]) : ""
        if (rid = "")
            return
        out := SelectionSense_HubDict_Lookup(dir0, txt0, sid0)
        try WebView_QueuePayload(g_SelSense_MenuWV2, Map(
            "type", "hub_translate_sqlite_result",
            "requestId", rid,
            "ok", (out != ""),
            "text", out,
            "reason", (out != "") ? "ok" : "no_match"
        ))
        return
    }
    if (typ = "hubScCtxCmd") {
        cmdId0 := msg.Has("cmdId") ? String(msg["cmdId"]) : ""
        idx0 := msg.Has("segmentIndex") ? Integer(msg["segmentIndex"]) : -1
        if (cmdId0 = "" || idx0 < 0)
            return
        txt0 := msg.Has("text") ? String(msg["text"]) : ""
        path0 := msg.Has("imagePath") ? Trim(String(msg["imagePath"])) : ""
        kind0 := msg.Has("kind") ? String(msg["kind"]) : "text"
        contentOut := txt0
        dataTypeOut := "text"
        if (kind0 = "image" && path0 != "" && FileExist(path0)) {
            contentOut := path0
            dataTypeOut := "file"
        } else if (kind0 = "image" && path0 != "") {
            contentOut := path0
            dataTypeOut := "Image"
        }
        title0 := SubStr(contentOut, 1, 120)
        if (title0 = "")
            title0 := "hub #" . (idx0 + 1)
        m0 := Map(
            "Title", title0,
            "Content", contentOut,
            "DataType", dataTypeOut,
            "OriginalDataType", kind0,
            "Source", "hub",
            "HubSegIndex", idx0,
            "ClipboardId", 0,
            "PromptMergedIndex", 0
        )
        try SC_ExecuteContextCommand(cmdId0, 0, m0)
        catch as err {
            OutputDebug("[Hub] hubScCtxCmd: " . err.Message)
        }
        return
    }
}

SelectionSense_HubCapsule_FlushPendingSegments() {
    global g_SelSense_MenuWV2, g_SelSense_MenuReady, g_SelSense_MenuShowingHub, g_SelSense_PendingHubSegments
    if !(g_SelSense_MenuWV2 && g_SelSense_MenuReady && g_SelSense_MenuShowingHub)
        return
    try {
        if (g_SelSense_PendingHubSegments is Array) && (g_SelSense_PendingHubSegments.Length > 0) {
            for _, seg in g_SelSense_PendingHubSegments {
                if (Trim(String(seg)) != "")
                    SelectionSense_InternalQueueDraftCollect(String(seg), "pending_flush")
            }
            g_SelSense_PendingHubSegments := []
        }
    } catch as _e {
    }
}

SelectionSense_SendToNiumaChatAndSubmit(text) {
    t := Trim(String(text), " `t`r`n")
    if (t = "")
        return false

    try EnsureFloatingSurfaceVisible()
    catch as _e {
    }

    sent := false
    Loop 8 {
        try sent := FloatingToolbar_SendTextToNiumaChat(t, true, true, true)
        catch as _e {
            sent := false
        }
        if sent
            return true
        Sleep(120)
    }
    return false
}

; HubCapsule: preview-only update (does not push into segments).
SelectionSense_QueueHubPreviewUpdate(text, imagePath := "", imageDataUrl := "") {
    global g_SelSense_MenuWV2, g_SelSense_MenuReady, g_SelSense_PendingText, g_SelSense_IsManualCollected
    t := Trim(String(text), " `t`r`n")
    p := Trim(String(imagePath))
    d := Trim(String(imageDataUrl))
    if (t = "" && p = "" && d = "")
        return
    g_SelSense_IsManualCollected := false
    if (t != "")
        g_SelSense_PendingText := t
    if !(g_SelSense_MenuWV2 && g_SelSense_MenuReady)
        return
    m := Map("type", "preview_update")
    if (t != "")
        m["text"] := t
    if (p != "")
        m["imagePath"] := p
    if (d != "")
        m["imageDataUrl"] := d
    try WebView_QueuePayload(g_SelSense_MenuWV2, m)
    catch as _e {
    }
}

SelectionSense_InternalQueueDraftCollect(text, source := "") {
    global g_SelSense_MenuWV2, g_SelSense_MenuReady, g_SelSense_IsManualCollected
    if !(g_SelSense_MenuWV2 && g_SelSense_MenuReady)
        return
    g_SelSense_IsManualCollected := true
    m := Map("type", "draft_collect", "text", String(text))
    src := Trim(String(source))
    if (src != "")
        m["source"] := src
    try WebView_QueuePayload(g_SelSense_MenuWV2, m)
    catch as _e {
    }
}

; ===================== HubCapsule锛氫粠澶栭儴鎺ㄩ€佷竴娈垫枃鏈叆鏍?=====================
; Design: if HubCapsule is not ready yet, buffer and flush on selection_menu_ready.
SelectionSense_HubCapsule_PushSegmentText(text, draftSource := "capslock_copy") {
    global g_SelSense_MenuGui, g_SelSense_MenuWV2, g_SelSense_MenuReady, g_SelSense_MenuShowingHub
    global g_SelSense_PendingHubSegments, g_SelSense_NextNavPage

    t := Trim(String(text), " `t`r`n")
    if (t = "")
        return false

    ; Ensure HubCapsule host window is visible after CapsLock+C and retry if WebView isn't ready.
    try {
        global g_SelSense_MenuW, g_SelSense_MenuH, g_SelSense_MenuActivateOnShow, g_SelSense_MenuAnchorX, g_SelSense_MenuAnchorY
        SelectionSense_GetHubCapsuleDefaultSize(&defW, &defH)
        g_SelSense_MenuW := defW
        g_SelSense_MenuH := defH
        g_SelSense_MenuActivateOnShow := true
        CoordMode("Mouse", "Screen")
        MouseGetPos(&g_SelSense_MenuAnchorX, &g_SelSense_MenuAnchorY)
    } catch as _e {
    }

    ; 纭繚 WebView/椤甸潰鑷冲皯瀛樺湪涓斿鑸埌 HubCapsule
    try {
        if !(g_SelSense_MenuGui && g_SelSense_MenuWV2) {
            g_SelSense_NextNavPage := "HubCapsule.html"
            SelectionSense_EnsureMenuHost()
        } else if !g_SelSense_MenuShowingHub {
            g_SelSense_MenuReady := false
            g_SelSense_NextNavPage := ""
            try g_SelSense_MenuWV2.Navigate(BuildAppLocalUrl("HubCapsule.html"))
            g_SelSense_MenuShowingHub := true
        }
    } catch as _e {
    }

    ; Only push directly when current page is ready and truly HubCapsule.
    ; Otherwise message may land on SelectionMenu and be dropped.
    try {
        if (g_SelSense_MenuWV2 && g_SelSense_MenuReady && g_SelSense_MenuShowingHub) {
            SelectionSense_InternalQueueDraftCollect(t, draftSource)
            ; Ensure host window is visible (ShowMenu has its own retry timer).
            try SelectionSense_ShowMenuNearCursor()
            return true
        }
    } catch as _e {
    }

    try {
        if !(g_SelSense_PendingHubSegments is Array)
            g_SelSense_PendingHubSegments := []
        g_SelSense_PendingHubSegments.Push(t)
        ; 鍏堟妸绐楀彛鎷夊嚭鏉ワ紱寰?hub_ready/selection_menu_ready 鏃?flush 鍏ユ爤
        try SelectionSense_ShowMenuNearCursor()
    } catch as _e {
    }
    ; WebView 鏈?ready 鏃朵粎鍏ラ槦锛岃繑鍥?false 渚夸簬璋冪敤鏂瑰啀琛ュ彂棰勮/浜屾 Show
    return false
}

SelectionSense_PushHubCtxMenuSpec() {
    global g_SelSense_MenuWV2, g_SelSense_MenuReady, g_SelSense_MenuShowingHub
    if !(g_SelSense_MenuWV2 && g_SelSense_MenuReady && g_SelSense_MenuShowingHub)
        return
    spec := "[]"
    try {
        if IsSet(_VK_SceneCtxMenuItemsJson)
            spec := _VK_SceneCtxMenuItemsJson("scratchpad")
    } catch {
    }
    items := []
    try items := Jxon_Load(spec)
    catch {
    }
    try WebView_QueuePayload(g_SelSense_MenuWV2, Map("type", "hub_ctx_menu_spec", "items", items))
    catch {
    }
}

SelectionSense_PushMenuText(text) {
    global g_SelSense_MenuWV2, g_SelSense_MenuReady
    if !(g_SelSense_MenuWV2 && g_SelSense_MenuReady)
        return
    WebView_QueuePayload(g_SelSense_MenuWV2, Map("type", "selection_menu_init", "text", String(text)))
}

SelectionSense_PushHubPreviewText(text) {
    SelectionSense_QueueHubPreviewUpdate(text)
}

; For CapsLock+C: page/WebView may lag behind Show, so retry preview push once.
SelectionSense_HubCapsule_ResyncAfterCapsLockCopy(text) {
    t := Trim(String(text), " `t`r`n")
    if (t = "")
        return
    global g_SelSense_PendingText
    g_SelSense_PendingText := t
    SelectionSense_PushHubPreviewText(t)
    try SelectionSense_ShowMenuNearCursor()
    catch as _e {
    }
}

SelectionSense_RefreshHubPreviewAfterCopyTick(*) {
    global g_SelSense_LastFullText, g_SelSense_LastTick, g_SelSense_LastClipSig, g_SelSense_LastFireTick
    if !SelectionSense_HubCapsuleHostIsOpen()
        return
    text := ""
    try text := Trim(String(A_Clipboard), " `t`r`n")
    if (text = "")
        return
    g_SelSense_LastFullText := text
    g_SelSense_LastTick := A_TickCount
    g_SelSense_LastClipSig := StrLen(text) . ":" . SubStr(text, 1, 24)
    g_SelSense_LastFireTick := A_TickCount
    SelectionSense_PushHubPreviewText(text)
}

SelectionSense_ShowMenuNearCursor() {
    static menuShowRetries := 0
    static hubWvWarned := false
    global g_SelSense_MenuGui, g_SelSense_MenuVisible, g_SelSense_PendingText
    global g_SelSense_MenuAnchorX, g_SelSense_MenuAnchorY, g_SelSense_MenuCtrl

    SelectionSense_EnsureMenuHost()
    if !g_SelSense_MenuGui
        return

    ; WebView2.create is async; retry briefly until control is ready.
    if !g_SelSense_MenuCtrl {
        menuShowRetries++
        if (menuShowRetries < 180)
            SetTimer(SelectionSense_ShowMenuNearCursor, -55)
        else {
            menuShowRetries := 0
            if !hubWvWarned {
                hubWvWarned := true
                try TrayTip("HubCapsule failed to create WebView2 control.`nPlease install WebView2 Runtime and restart script.", "SelectionMenuHost", "Iconx 2")
            }
        }
        return
    }
    menuShowRetries := 0

    global g_SelSense_MenuW, g_SelSense_MenuH, g_SelSense_MenuActivateOnShow, g_SelSense_MenuShowingHub
    w := g_SelSense_MenuW
    h := g_SelSense_MenuH
    if (w < 200)
        w := 220
    if (h < 160)
        h := 200
    CoordMode("Mouse", "Screen")
    sx := sy := 0
    savedOk := false
    if (g_SelSense_MenuShowingHub && w >= 350)
        SelectionSense_HubCapsule_ReadSavedPos(&sx, &sy, &savedOk)
    if savedOk && !SelectionSense_HubSavedRectIsOnScreen(sx, sy, w, h)
        savedOk := false
    if savedOk {
        x := sx
        y := sy
    } else {
        mx := g_SelSense_MenuAnchorX
        my := g_SelSense_MenuAnchorY
        x := mx + 8
        y := my + 8
    }
    ScreenVirtual_GetBounds(&vl, &vt, &vw, &vh)
    vr := vl + vw
    vb := vt + vh
    if (x + w > vr - 4)
        x := vr - w - 4
    if (y + h > vb - 4)
        y := vb - h - 4
    if (x < vl + 4)
        x := vl + 4
    if (y < vt + 4)
        y := vt + 4

    doActivate := g_SelSense_MenuActivateOnShow
    showOpt := doActivate ? "" : " NoActivate"
    try g_SelSense_MenuGui.Show("x" . x . " y" . y . " w" . w . " h" . h . showOpt)
    try WinShow("ahk_id " . g_SelSense_MenuGui.Hwnd)
    g_SelSense_MenuVisible := true
    g_SelSense_MenuActivateOnShow := false
    SelectionSense_ApplyMenuBounds()
    try g_SelSense_MenuCtrl.NotifyParentWindowPositionChanged()
    if doActivate {
        try WinActivate("ahk_id " . g_SelSense_MenuGui.Hwnd)
        try g_SelSense_MenuCtrl.MoveFocus(WebView2.MOVE_FOCUS_REASON.PROGRAMMATIC)
        SetTimer(SelectionSense_MenuNudgeWebViewFocus, -180)
    }

    SetTimer(SelectionSense_DeferredPushMenuText, -45)
}

SelectionSense_MenuNudgeWebViewFocus(*) {
    global g_SelSense_MenuVisible, g_SelSense_MenuGui, g_SelSense_MenuCtrl
    if !(g_SelSense_MenuVisible && g_SelSense_MenuGui && g_SelSense_MenuCtrl)
        return
    try WinActivate("ahk_id " . g_SelSense_MenuGui.Hwnd)
    try g_SelSense_MenuCtrl.MoveFocus(WebView2.MOVE_FOCUS_REASON.PROGRAMMATIC)
    catch as _e {
    }
}

SelectionSense_IsCursorEditorActive() {
    try {
        return StrLower(WinGetProcessName("A")) = "cursor.exe"
    } catch as _e {
        return false
    }
}

; If Hub is visible and current page is HubCapsule, avoid duplicate Navigate/focus grab.
SelectionSense_HubCapsuleHostIsOpen() {
    global g_SelSense_MenuVisible, g_SelSense_MenuShowingHub
    return !!(g_SelSense_MenuVisible && g_SelSense_MenuShowingHub)
}

; 涓?~^c 鎵撳紑鐨?Hub 瀹屽叏涓€鑷达細鍙紶 overrideText锛圕apsLock+C 鐢級锛岀┖鍒欎粠 A_Clipboard 璇?; alsoPushSegment锛氫粎 CapsLock+C 闇€瑕佹妸鍐呭鍘嬪叆鍫嗗彔鍗＄墖鏃跺啀涓?true
SelectionSense_SyncHubFromUserCopyChannel(overrideText := "", alsoPushSegment := false, draftSource := "") {
    global g_SelSense_LastFullText, g_SelSense_LastTick, g_SelSense_LastClipSig, g_SelSense_LastFireTick
    text := Trim(String(overrideText), " `t`r`n")
    if (text = "") {
        try text := Trim(String(A_Clipboard), " `t`r`n")
    }
    if (text = "")
        return

    g_SelSense_LastFullText := text
    g_SelSense_LastTick := A_TickCount
    g_SelSense_LastClipSig := StrLen(text) . ":" . SubStr(text, 1, 24)
    g_SelSense_LastFireTick := A_TickCount
    try FloatingToolbar_NotifySelectionChange(text)
    catch as _e {
    }
    SelectionSense_OpenHubCapsuleFromToolbar(false, text)
    SelectionSense_PushHubPreviewText(text)
    if (alsoPushSegment) {
        ds := Trim(String(draftSource))
        if (ds = "")
            ds := "capslock_copy"
        SelectionSense_HubCapsule_PushSegmentText(text, ds)
    }
    SetTimer(SelectionSense_HubCapsule_ResyncAfterCapsLockCopy.Bind(text), -250)
    SetTimer(SelectionSense_HubCapsule_ResyncAfterCapsLockCopy.Bind(text), -850)
}

SelectionSense_OpenHubAfterDoubleCopyTick(*) {
    SelectionSense_SyncHubFromUserCopyChannel("", true, "double_ctrl")
}

; 鎮诞宸ュ叿鏍忋€屾柊銆嶏細鎵撳紑 HubCapsule锛堣嫢鏈夎繎鏈熼€夊尯鍒欏甫鍏ラ瑙堬級
; useToolbarAnchor=true anchors near toolbar; false anchors near mouse.
; pendingTextOverride: direct preview payload (e.g. double Ctrl+C path).
SelectionSense_OpenHubCapsuleFromToolbar(useToolbarAnchor := true, pendingTextOverride := "") {
    global g_SelSense_MenuW, g_SelSense_MenuH, g_SelSense_MenuGui, g_SelSense_MenuWV2, g_SelSense_MenuCtrl
    global g_SelSense_MenuReady, g_SelSense_PendingText, g_SelSense_MenuAnchorX, g_SelSense_MenuAnchorY
    global g_SelSense_NextNavPage, g_SelSense_MenuActivateOnShow, FloatingToolbarGUI, g_SelSense_MenuShowingHub
    global g_SelSense_DoubleCopyHub_LastTick

    g_SelSense_DoubleCopyHub_LastTick := 0
    SelectionSense_GetHubCapsuleDefaultSize(&defW, &defH)
    g_SelSense_MenuW := defW
    g_SelSense_MenuH := defH
    g_SelSense_MenuActivateOnShow := true
    ov := Trim(String(pendingTextOverride))
    if (ov != "")
        g_SelSense_PendingText := ov
    else
        g_SelSense_PendingText := Trim(SelectionSense_GetLastSelectedText())

    anchored := false
    if (useToolbarAnchor && IsSet(FloatingToolbarGUI) && FloatingToolbarGUI) {
        try {
            FloatingToolbarGUI.GetPos(&fx, &fy, &fw, &fh)
            if (fw > 0) {
                g_SelSense_MenuAnchorX := fx + fw // 2
                g_SelSense_MenuAnchorY := fy
                anchored := true
            }
        } catch as _e {
        }
    }
    if !anchored {
        CoordMode("Mouse", "Screen")
        MouseGetPos(&g_SelSense_MenuAnchorX, &g_SelSense_MenuAnchorY)
    }

    if (g_SelSense_MenuGui && g_SelSense_MenuWV2) {
        if !g_SelSense_MenuShowingHub {
            g_SelSense_MenuReady := false
            g_SelSense_NextNavPage := ""
            try g_SelSense_MenuWV2.Navigate(BuildAppLocalUrl("HubCapsule.html"))
            g_SelSense_MenuShowingHub := true
        }
    } else {
        g_SelSense_NextNavPage := "HubCapsule.html"
        SelectionSense_EnsureMenuHost()
    }
    SelectionSense_ShowMenuNearCursor()
}

SelectionSense_DeferredPushMenuText(*) {
    global g_SelSense_PendingText, g_SelSense_MenuReady, g_SelSense_MenuWV2
    if !g_SelSense_MenuWV2
        return
    if g_SelSense_MenuReady
        SelectionSense_PushMenuText(g_SelSense_PendingText)
    else
        SetTimer(SelectionSense_DeferredPushMenuText, -80)
}

SelectionSense_HideMenu() {
    global g_SelSense_MenuGui, g_SelSense_MenuVisible, g_SelSense_MenuShowingHub, g_SelSense_DoubleCopyHub_LastTick
    global g_SelSense_MenuWV2, g_SelSense_MenuReady, g_SelSense_PendingText
    if (g_SelSense_MenuGui && g_SelSense_MenuVisible && g_SelSense_MenuShowingHub) {
        SelectionSense_HubCapsule_WriteSavedPos()
        try {
            if (g_SelSense_MenuWV2 && g_SelSense_MenuReady)
                WebView_QueuePayload(g_SelSense_MenuWV2, Map("type", "hub_dismiss_reset"))
        } catch as _e {
        }
    }
    g_SelSense_PendingText := ""
    g_SelSense_DoubleCopyHub_LastTick := 0
    g_SelSense_MenuVisible := false
    try FloatingToolbar_NotifySelectionClear()
    catch as _e {
    }
    if g_SelSense_MenuGui {
        try g_SelSense_MenuGui.Hide()
    }
}

SelectionSense_PrewarmHubCapsule() {
    global g_SelSense_MenuGui, g_SelSense_MenuWV2, g_SelSense_MenuReady
    global g_SelSense_NextNavPage, g_SelSense_MenuShowingHub

    if (g_SelSense_MenuGui && g_SelSense_MenuWV2) {
        g_SelSense_MenuReady := false
        g_SelSense_NextNavPage := ""
        try g_SelSense_MenuWV2.Navigate(BuildAppLocalUrl("HubCapsule.html"))
        g_SelSense_MenuShowingHub := true
    } else {
        g_SelSense_NextNavPage := "HubCapsule.html"
        SelectionSense_EnsureMenuHost()
    }
}

SelectionSense_OnUserCopy(*) {
    global g_SelSense_UserCopyInProgress, g_SelSense_UserCopyEndTick, g_SelSense_DoubleCopyHub_LastTick, g_SelSense_HubCopyTriggerMode

    ; CapsLock+C internal Send(^c) also triggers this hook.
    global CapsLockCopyInProgress
    if (CapsLockCopyInProgress)
        return

    g_SelSense_UserCopyInProgress := true
    g_SelSense_UserCopyEndTick := A_TickCount
    SetTimer(SelectionSense_ClearUserCopyFlag, -780)

    ; If not in Cursor editor, skip Hub-specific preview logic.
    if !SelectionSense_IsCursorEditorActive()
        return
    if SelectionSense_HubCapsuleHostIsOpen() {
        SetTimer(SelectionSense_RefreshHubPreviewAfterCopyTick, -140)
        return
    }

    ; Double Ctrl+C opens Hub entry flow; single Ctrl+C does not.
    now := A_TickCount
    winMs := 520
    if (g_SelSense_DoubleCopyHub_LastTick > 0 && (now - g_SelSense_DoubleCopyHub_LastTick) <= winMs) {
        g_SelSense_DoubleCopyHub_LastTick := 0
        SetTimer(SelectionSense_OpenHubAfterDoubleCopyTick, -140)
    } else {
        g_SelSense_DoubleCopyHub_LastTick := now
    }
}

SelectionSense_ClearUserCopyFlag(*) {
    global g_SelSense_UserCopyInProgress
    g_SelSense_UserCopyInProgress := false
}

SelectionSense_Init() {
    SelectionSense_LoadIni()
    global g_SelSense_Enabled
    if g_SelSense_Enabled {
        Hotkey("~*LButton", SelectionSense_OnLButtonDown, "On")
        Hotkey("~*LButton Up", SelectionSense_OnLButtonUp, "On")
        Hotkey("~^c", SelectionSense_OnUserCopy, "On")
    } else {
        Hotkey("~*LButton", SelectionSense_OnLButtonDown, "Off")
        Hotkey("~*LButton Up", SelectionSense_OnLButtonUp, "Off")
        Hotkey("~^c", SelectionSense_OnUserCopy, "Off")
    }
    try SelectionSense_PrewarmHubCapsule()
}

