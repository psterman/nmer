; ======================================================================================================================
; ClipboardPanelCore.ahk — WebView2 剪贴板管理器核心
; 须由父脚本按序 #Include（WebView2.ahk / Jxon.ahk / Gdip_All.ahk / ImagePut.ahk / ClipboardFTS5.ahk 均已在前）
; ======================================================================================================================

#Requires AutoHotkey v2.0

global g_CP_Gui := 0
global g_CP_WV2 := 0
global g_CP_Ctrl := 0
global g_CP_Ready := false
global g_CP_Visible := false
global g_CP_SearchTimer := 0
global g_CP_LastKeyword := ""
global g_CP_FilterType := "all"
global g_CP_TitleH := 0

; ══════════════════════════════════════════════════════════════════════════
; _CP_LSP_Hints — 永远不被调用；仅让语言服务器看到外部符号的赋值语句，
;                 从而消除 "never assigned" 静态分析警告。
;                 父脚本 CursorHelper.ahk 已在本模块之前 #Include 了
;                 WebView2.ahk / Jxon.ahk / Gdip_All.ahk / ImagePut.ahk /
;                 ClipboardFTS5.ahk，运行时这些符号均已定义，此函数从不执行。
; ══════════════════════════════════════════════════════════════════════════
_CP_LSP_Hints() {
    ; AHK v2 中 class / func 名均为只读，不能出现在赋值左侧。
    ; 只对普通全局变量做虚拟赋值，让 LSP 看到"已赋值"。
    ; WebView2 / Jxon_Load / Gdip_* / ImagePut / ImageDestroy
    ; 均通过 (%"Name"%) 动态引用，彻底绕开 LSP 的变量检查。
    global ClipboardFTS5DB
    ClipboardFTS5DB := 0
}

; ===================== 初始化 =====================
CP_Init() {
    global g_CP_Gui, WebView2

    if g_CP_Gui
        return

    ScreenW := SysGet(0)
    ScreenH := SysGet(1)
    WinW := Max(820, Min(Round(ScreenW * 0.48), 1100))
    WinH := Max(500, Min(Round(ScreenH * 0.55), 720))

    g_CP_Gui := Gui("+AlwaysOnTop -Caption -DPIScale +ToolWindow", "ClipboardPanel")
    g_CP_Gui.BackColor := "0a0a0a"
    g_CP_Gui.MarginX := 0
    g_CP_Gui.MarginY := 0

    g_CP_Gui.Show("w" . WinW . " h" . WinH . " Hide")
    g_CP_Gui.OnEvent("Close", (*) => CP_Hide())
    g_CP_Gui.OnEvent("Size", _CP_OnGuiResize)

    WebView2.create(g_CP_Gui.Hwnd, _CP_OnWV2Created)
}

; ===================== 显示 / 隐藏 =====================
CP_Show() {
    global g_CP_Gui, g_CP_Visible, g_CP_Ready

    if !g_CP_Gui
        CP_Init()

    if g_CP_Visible {
        try WinActivate(g_CP_Gui.Hwnd)
        return
    }

    _CP_CenterWindow()
    g_CP_Gui.Show("NoActivate")
    g_CP_Visible := true

    OnMessage(0x0006, _CP_WM_ACTIVATE)

    ; 缓解 WebView2 在「先 Hide 再 Show」宿主上的黑屏：显示后立即刷新合成层
    _CP_RefreshWebViewComposition()
    SetTimer(_CP_RefreshWebViewComposition, -120)
    SetTimer(_CP_RefreshWebViewComposition, -380)

    if g_CP_Ready
        _CP_PushInitialData()

    SetTimer(_CP_FocusDeferred, -80)
}

_CP_FocusDeferred() {
    global g_CP_Gui, g_CP_Visible
    if g_CP_Visible && g_CP_Gui {
        try WinActivate(g_CP_Gui.Hwnd)
    }
}

CP_Hide() {
    global g_CP_Gui, g_CP_Visible, g_CP_SearchTimer

    if g_CP_SearchTimer {
        SetTimer(g_CP_SearchTimer, 0)
        g_CP_SearchTimer := 0
    }

    OnMessage(0x0006, _CP_WM_ACTIVATE, 0)

    g_CP_Visible := false
    if g_CP_Gui
        g_CP_Gui.Hide()
}

CP_Toggle() {
    global g_CP_Visible
    if g_CP_Visible
        CP_Hide()
    else
        CP_Show()
}

; ===================== WM_ACTIVATE 自动隐藏 =====================
_CP_WM_ACTIVATE(wParam, lParam, msg, hwnd) {
    global g_CP_Gui, g_CP_Visible

    if !g_CP_Visible || !g_CP_Gui
        return

    if (hwnd = g_CP_Gui.Hwnd && (wParam & 0xFFFF) = 0)
        SetTimer(CP_Hide, -50)
}

; ===================== 窗口居中 =====================
_CP_CenterWindow() {
    global g_CP_Gui
    if !g_CP_Gui
        return
    try {
        WinGetPos(, , &w, &h, g_CP_Gui.Hwnd)
        ScreenW := SysGet(0)
        ScreenH := SysGet(1)
        x := (ScreenW - w) // 2
        y := (ScreenH - h) // 2
        g_CP_Gui.Move(x, y)
    }
}

; ===================== WebView2 回调 =====================
_CP_OnWV2Created(ctrl) {
    global g_CP_WV2, g_CP_Ctrl

    g_CP_Ctrl := ctrl
    g_CP_WV2 := ctrl.CoreWebView2

    try g_CP_Ctrl.DefaultBackgroundColor := 0xFF0A0A0A
    try g_CP_Ctrl.IsVisible := true

    _CP_ApplyBounds()

    s := g_CP_WV2.Settings
    s.AreDefaultContextMenusEnabled := false
    s.IsStatusBarEnabled := false
    s.AreDevToolsEnabled := true

    g_CP_WV2.add_WebMessageReceived(_CP_OnWebMessage)
    try g_CP_WV2.add_NavigationCompleted(_CP_OnNavigationCompleted)

    htmlPath := A_ScriptDir "\ClipboardPanel.html"
    if FileExist(htmlPath)
        g_CP_WV2.Navigate("file:///" . StrReplace(htmlPath, "\", "/"))
    else
        OutputDebug("[CP] ClipboardPanel.html not found: " . htmlPath)
}

_CP_ApplyBounds() {
    global g_CP_Gui, g_CP_Ctrl, g_CP_TitleH, WebView2
    if !g_CP_Ctrl
        return
    WinGetClientPos(, , &cw, &ch, g_CP_Gui.Hwnd)
    rc := WebView2.RECT()
    rc.left := 0
    rc.top := g_CP_TitleH
    rc.right := cw
    rc.bottom := ch
    g_CP_Ctrl.Bounds := rc
}

; WebView2 已知问题：父窗口在隐藏状态下创建 Controller 时，首次显示可能黑屏/不合成。
; 参考: https://github.com/MicrosoftEdge/WebView2Feedback/issues/1077
; 在面板 Show 后及导航完成后重新应用 Bounds 并 NotifyParentWindowPositionChanged。
_CP_RefreshWebViewComposition(*) {
    global g_CP_Ctrl, g_CP_Gui, g_CP_Visible
    if !g_CP_Visible || !g_CP_Ctrl || !g_CP_Gui
        return
    try {
        _CP_ApplyBounds()
        g_CP_Ctrl.NotifyParentWindowPositionChanged()
    } catch as err {
        OutputDebug("[CP] RefreshWebViewComposition: " . err.Message)
    }
}

_CP_OnNavigationCompleted(sender, args) {
    global g_CP_Visible
    if !g_CP_Visible
        return
    try ok := args.IsSuccess
    catch {
        ok := true
    }
    if !ok
        return
    _CP_RefreshWebViewComposition()
}

_CP_OnGuiResize(GuiObj, MinMax, Width, Height) {
    if MinMax = -1
        return
    _CP_ApplyBounds()
}

; ===================== AHK ↔ JS 通信 =====================
CP_SendToWeb(jsonStr) {
    global g_CP_WV2, g_CP_Ready
    if g_CP_WV2 && g_CP_Ready
        g_CP_WV2.PostWebMessageAsJson(jsonStr)
}

_CP_OnWebMessage(sender, args) {
    global g_CP_Ready, g_CP_Visible

    jsonStr := args.WebMessageAsJson
    try {
        msg := (%"Jxon_Load"%).Call(jsonStr)
    } catch {
        OutputDebug("[CP] JSON parse error: " . jsonStr)
        return
    }
    if !(msg is Map) || !msg.Has("type")
        return

    switch msg["type"] {
        case "ready":
            g_CP_Ready := true
            OutputDebug("[CP] WebView ready")
            if g_CP_Visible
                _CP_PushInitialData()

        case "search":
            keyword := msg.Has("keyword") ? msg["keyword"] : ""
            filterType := msg.Has("filterType") ? msg["filterType"] : "all"
            _CP_DebouncedSearch(keyword, filterType)

        case "paste":
            if msg.Has("id")
                _CP_DoPaste(msg["id"], _CP_MsgKeepOpen(msg))

        case "pasteByIndex":
            if msg.Has("index")
                _CP_DoPasteByIndex(msg["index"], _CP_MsgKeepOpen(msg))

        case "delete":
            if msg.Has("id")
                _CP_DoDelete(msg["id"])

        case "pin":
            if msg.Has("id")
                _CP_DoPin(msg["id"])

        case "copyPlain":
            if msg.Has("id")
                _CP_DoCopyPlain(msg["id"], _CP_MsgKeepOpen(msg))

        case "copyToClipboard":
            if msg.Has("id")
                _CP_DoCopyToClipboard(msg["id"], _CP_MsgKeepOpen(msg))

        case "pastePlain":
            if msg.Has("id")
                _CP_DoPastePlain(msg["id"], _CP_MsgKeepOpen(msg))

        case "pasteWithNewline":
            if msg.Has("id")
                _CP_DoPasteWithNewline(msg["id"], _CP_MsgKeepOpen(msg))

        case "pastePath":
            if msg.Has("id")
                _CP_DoPastePath(msg["id"], _CP_MsgKeepOpen(msg))

        case "loadMore":
            offset := msg.Has("offset") ? Integer(msg["offset"]) : 0
            _CP_DoLoadMore(offset)

        case "getPreview":
            if msg.Has("id")
                _CP_DoGetPreview(msg["id"])

        case "requestHide":
            CP_Hide()

        default:
            OutputDebug("[CP] Unknown msg type: " . msg["type"])
    }
}

; ===================== 数据推送 =====================
_CP_PushInitialData() {
    global g_CP_LastKeyword, g_CP_FilterType
    g_CP_LastKeyword := ""
    g_CP_FilterType := "all"
    items := _CP_LoadItems("", g_CP_FilterType, 0, 20)
    total := _CP_GetTotalCount("", g_CP_FilterType)
    hasMore := (items.Length < total)
    json := _CP_BuildItemsJson("init", items, total, hasMore)
    CP_SendToWeb(json)
}

_CP_DoLoadMore(offset) {
    global g_CP_LastKeyword, g_CP_FilterType
    offset := Integer(offset)
    if offset < 0
        offset := 0
    items := _CP_LoadItems(g_CP_LastKeyword, g_CP_FilterType, offset, 20)
    total := _CP_GetTotalCount(g_CP_LastKeyword, g_CP_FilterType)
    hasMore := (offset + items.Length) < total
    json := _CP_BuildItemsJson("moreItems", items, total, hasMore)
    CP_SendToWeb(json)
}

; ===================== 防抖搜索 =====================
_CP_DebouncedSearch(keyword, filterType := "all") {
    global g_CP_SearchTimer, g_CP_LastKeyword, g_CP_FilterType
    g_CP_LastKeyword := keyword
    g_CP_FilterType := _CP_NormalizeFilterType(filterType)

    if g_CP_SearchTimer {
        SetTimer(g_CP_SearchTimer, 0)
        g_CP_SearchTimer := 0
    }

    fn := _CP_ExecuteSearch.Bind(keyword, g_CP_FilterType)
    g_CP_SearchTimer := fn
    SetTimer(fn, -150)
}

_CP_ExecuteSearch(keyword, filterType := "all") {
    global g_CP_SearchTimer
    g_CP_SearchTimer := 0
    filterType := _CP_NormalizeFilterType(filterType)
    items := _CP_LoadItems(keyword, filterType, 0, 20)
    total := _CP_GetTotalCount(keyword, filterType)
    hasMore := (items.Length < total)
    json := _CP_BuildItemsJson("searchResult", items, total, hasMore)
    CP_SendToWeb(json)
}

; ===================== 数据库查询 =====================
_CP_LoadItems(keyword := "", filterType := "all", offset := 0, limit := 20) {
    global ClipboardFTS5DB

    if !ClipboardFTS5DB || ClipboardFTS5DB = 0
        return []

    offset := Integer(offset)
    limit := Integer(limit)
    if offset < 0
        offset := 0
    if limit < 1
        limit := 20

    results := []
    try {
        selectFields := _CP_BuildSelectFields()
        whereClause := _CP_BuildWhereClause(keyword, filterType)
        orderBy := _CP_GetOrderField()

        SQL := "SELECT " . selectFields . " FROM ClipMain"
        if whereClause != ""
            SQL .= " WHERE " . whereClause
        ; ID DESC 作为稳定 tie-breaker，避免相同时间戳下 OFFSET 分页漏行/重复
        SQL .= " ORDER BY IsFavorite DESC, " . orderBy . " DESC, ID DESC LIMIT " . limit . " OFFSET " . offset

        table := ""
        if ClipboardFTS5DB.GetTable(SQL, &table) {
            if table.HasRows && table.Rows.Length > 0 {
                columnIndexMap := Map()
                if table.HasNames && table.ColumnNames.Length > 0 {
                    Loop table.ColumnNames.Length {
                        columnIndexMap[table.ColumnNames[A_Index]] := A_Index
                    }
                }

                Loop table.Rows.Length {
                    row := table.Rows[A_Index]
                    item := _CP_RowToMap(row, columnIndexMap)
                    results.Push(item)
                }
            }
        }
    } catch as err {
        OutputDebug("[CP] LoadItems error: " . err.Message)
    }

    return results
}

_CP_GetTotalCount(keyword := "", filterType := "all") {
    global ClipboardFTS5DB

    if !ClipboardFTS5DB || ClipboardFTS5DB = 0
        return 0

    try {
        whereClause := _CP_BuildWhereClause(keyword, filterType)
        SQL := "SELECT COUNT(*) FROM ClipMain"
        if whereClause != ""
            SQL .= " WHERE " . whereClause

        table := ""
        if ClipboardFTS5DB.GetTable(SQL, &table) {
            if table.HasRows && table.Rows.Length > 0
                return Integer(table.Rows[1][1])
        }
    } catch {
    }
    return 0
}

_CP_BuildSelectFields() {
    global ClipboardFTS5DB
    hasLastCopyTime := false
    hasIconPath := false
    hasSourcePath := false

    try {
        table := ""
        if ClipboardFTS5DB.GetTable("PRAGMA table_info(ClipMain)", &table) {
            if table.HasRows && table.Rows.Length > 0 {
                Loop table.Rows.Length {
                    colName := table.Rows[A_Index][2]
                    if colName = "LastCopyTime"
                        hasLastCopyTime := true
                    if colName = "IconPath"
                        hasIconPath := true
                    if colName = "SourcePath"
                        hasSourcePath := true
                }
            }
        }
    } catch {
    }

    fields := "ID, Content, SourceApp, DataType, CharCount, Timestamp, ImagePath, IsFavorite"
    if hasLastCopyTime
        fields .= ", LastCopyTime"
    else
        fields .= ", Timestamp AS LastCopyTime"
    if hasIconPath
        fields .= ", IconPath"
    else
        fields .= ", '' AS IconPath"
    if hasSourcePath
        fields .= ", SourcePath"
    else
        fields .= ", '' AS SourcePath"

    return fields
}

_CP_GetOrderField() {
    global ClipboardFTS5DB
    try {
        table := ""
        if ClipboardFTS5DB.GetTable("PRAGMA table_info(ClipMain)", &table) {
            if table.HasRows && table.Rows.Length > 0 {
                Loop table.Rows.Length {
                    if table.Rows[A_Index][2] = "LastCopyTime"
                        return "COALESCE(LastCopyTime, Timestamp)"
                }
            }
        }
    } catch {
    }
    return "Timestamp"
}

_CP_BuildWhereClause(keyword, filterType := "all") {
    global ClipboardFTS5DB
    keyword := Trim(keyword)
    filterType := _CP_NormalizeFilterType(filterType)

    conditions := []
    if filterType = "favorite"
        conditions.Push("IsFavorite = 1")
    else if filterType != "all"
        conditions.Push("LOWER(DataType) = '" . filterType . "'")

    if keyword = ""
        return conditions.Length > 0 ? _CP_JoinConditions(conditions) : ""

    escapedKeyword := StrReplace(keyword, "'", "''")
    escapedKeyword := StrReplace(escapedKeyword, "\", "\\")
    escapedLike := StrReplace(escapedKeyword, "%", "\%")
    escapedLike := StrReplace(escapedLike, "_", "\_")

    keywordLen := StrLen(keyword)
    useLike := (keywordLen <= 2) || !RegExMatch(keyword, "^[\w\s]+$")

    hasFTS5 := false
    try {
        table := ""
        if ClipboardFTS5DB.GetTable("SELECT name FROM sqlite_master WHERE type='table' AND name='ClipboardHistory'", &table) {
            if table.HasRows && table.Rows.Length > 0
                hasFTS5 := true
        }
    } catch {
    }

    if hasFTS5 && !useLike {
        ftsKeyword := StrReplace(keyword, "'", "''")
        ftsKeyword := StrReplace(ftsKeyword, '"', '""')
        if InStr(ftsKeyword, " ")
            ftsQuery := '"' . ftsKeyword . '"'
        else
            ftsQuery := ftsKeyword . '*'
        conditions.Push("ID IN (SELECT rowid FROM ClipboardHistory WHERE ClipboardHistory MATCH '" . ftsQuery . "')")
        return _CP_JoinConditions(conditions)
    }

    conditions.Push("(LOWER(Content) LIKE '%" . escapedLike . "%' OR LOWER(SourceApp) LIKE '%" . escapedLike . "%')")
    return _CP_JoinConditions(conditions)
}

_CP_NormalizeFilterType(filterType) {
    filterType := StrLower(Trim(filterType))
    if filterType = ""
        return "all"
    if filterType = "all" || filterType = "text" || filterType = "image" || filterType = "url" || filterType = "code" || filterType = "favorite"
        return filterType
    return "all"
}

_CP_JoinConditions(conditions) {
    if conditions.Length = 0
        return ""
    sql := conditions[1]
    if conditions.Length > 1 {
        Loop (conditions.Length - 1)
            sql .= " AND " . conditions[A_Index + 1]
    }
    return sql
}

_CP_RowToMap(row, columnIndexMap) {
    item := Map()
    for key in ["ID", "Content", "SourceApp", "DataType", "CharCount", "Timestamp", "ImagePath", "IsFavorite", "LastCopyTime", "IconPath", "SourcePath"] {
        item[key] := columnIndexMap.Has(key) ? row[columnIndexMap[key]] : ""
    }
    return item
}

; ===================== JSON 构建 =====================
_CP_BuildItemsJson(msgType, items, total := 0, hasMore := false) {
    json := '{"type":"' . msgType . '","items":['

    Loop items.Length {
        if A_Index > 1
            json .= ","
        json .= _CP_ItemToJson(items[A_Index])
    }

    json .= '],"total":' . total . ',"hasMore":' . (hasMore ? "true" : "false") . '}'
    return json
}

_CP_ItemToJson(item) {
    id := item.Has("ID") ? item["ID"] : 0
    content := item.Has("Content") ? item["Content"] : ""
    sourceApp := item.Has("SourceApp") ? item["SourceApp"] : ""
    dataType := item.Has("DataType") ? item["DataType"] : ""
    charCount := item.Has("CharCount") ? item["CharCount"] : 0
    sortTime := item.Has("LastCopyTime") ? item["LastCopyTime"] : (item.Has("Timestamp") ? item["Timestamp"] : "")
    imagePath := item.Has("ImagePath") ? item["ImagePath"] : ""
    isFavorite := item.Has("IsFavorite") ? item["IsFavorite"] : 0
    iconPath := item.Has("IconPath") ? item["IconPath"] : ""
    sourcePath := item.Has("SourcePath") ? item["SourcePath"] : ""

    json := '{"id":' . id
    json .= ',"content":' . _CP_JsonStr(content)
    json .= ',"sourceApp":' . _CP_JsonStr(sourceApp)
    json .= ',"dataType":' . _CP_JsonStr(dataType)
    json .= ',"charCount":' . (charCount ? charCount : 0)
    json .= ',"sortTime":' . _CP_JsonStr(sortTime)
    json .= ',"imagePath":' . _CP_JsonStr(imagePath)
    json .= ',"isFavorite":' . (isFavorite ? 1 : 0)
    json .= ',"iconPath":' . _CP_JsonStr(iconPath)
    json .= ',"sourcePath":' . _CP_JsonStr(sourcePath)
    json .= '}'
    return json
}

_CP_JsonStr(val) {
    if !val || val = ""
        return '""'
    val := StrReplace(val, "\", "\\")
    val := StrReplace(val, '"', '\"')
    val := StrReplace(val, "`n", "\n")
    val := StrReplace(val, "`r", "\r")
    val := StrReplace(val, "`t", "\t")
    return '"' . val . '"'
}

_CP_MsgKeepOpen(msg) {
    if !(msg is Map) || !msg.Has("keepOpen")
        return false
    v := msg["keepOpen"]
    return v = true || v = 1 || v = "true"
}

_CP_MaybeHide(keepOpen) {
    if !keepOpen
        CP_Hide()
}

_CP_GetClipRow(id) {
    global ClipboardFTS5DB
    row := Map("content", "", "dataType", "", "imagePath", "", "sourcePath", "")
    if !ClipboardFTS5DB || ClipboardFTS5DB = 0
        return row
    try {
        selectFields := _CP_BuildSelectFields()
        SQL := "SELECT " . selectFields . " FROM ClipMain WHERE ID = " . id
        table := ""
        if ClipboardFTS5DB.GetTable(SQL, &table) {
            if table.HasRows && table.Rows.Length > 0 {
                columnIndexMap := Map()
                if table.HasNames && table.ColumnNames.Length > 0 {
                    Loop table.ColumnNames.Length
                        columnIndexMap[table.ColumnNames[A_Index]] := A_Index
                }
                item := _CP_RowToMap(table.Rows[1], columnIndexMap)
                row["content"] := item.Has("Content") ? item["Content"] : ""
                row["dataType"] := item.Has("DataType") ? item["DataType"] : ""
                row["imagePath"] := item.Has("ImagePath") ? item["ImagePath"] : ""
                row["sourcePath"] := item.Has("SourcePath") ? item["SourcePath"] : ""
            }
        }
    } catch as err {
        OutputDebug("[CP] GetClipRow error: " . err.Message)
    }
    return row
}

_CP_StripHtml(s) {
    if s = ""
        return ""
    r := RegExReplace(s, "<[^>]+>", "")
    r := StrReplace(r, "&nbsp;", " ")
    r := StrReplace(r, "&amp;", "&")
    r := StrReplace(r, "&lt;", "<")
    r := StrReplace(r, "&gt;", ">")
    r := StrReplace(r, "&quot;", '"')
    r := StrReplace(r, "&#39;", "'")
    return Trim(r)
}

_CP_ResolvePastePath(content, sourcePath) {
    sourcePath := Trim(sourcePath)
    if sourcePath != "" && FileExist(sourcePath)
        return sourcePath
    c := Trim(content)
    if c = ""
        return ""
    if InStr(c, "`n") || InStr(c, "`r")
        return ""
    if FileExist(c)
        return c
    return ""
}

; ===================== 操作：粘贴 =====================
_CP_DoPaste(id, keepOpen := false) {
    global ClipboardFTS5DB

    if !ClipboardFTS5DB || ClipboardFTS5DB = 0
        return

    try {
        row := _CP_GetClipRow(id)
        content := row["content"]
        dataType := row["dataType"]
        imagePath := row["imagePath"]
        if content = "" && imagePath = ""
            return

        _CP_MaybeHide(keepOpen)
        Sleep(keepOpen ? 30 : 50)

        dt := StrLower(dataType)
        if (dt = "image" || dt = "screenshot") && imagePath != "" && FileExist(imagePath) {
            _CP_PasteImage(imagePath)
        } else {
            A_Clipboard := content
            Sleep(30)
            Send("^v")
        }
    } catch as err {
        OutputDebug("[CP] DoPaste error: " . err.Message)
    }
}

_CP_DoPasteByIndex(index, keepOpen := false) {
    global g_CP_LastKeyword, g_CP_FilterType
    items := _CP_LoadItems(g_CP_LastKeyword, g_CP_FilterType, 0, 20)
    idx := index + 1
    if idx > items.Length
        return
    id := items[idx].Has("ID") ? items[idx]["ID"] : 0
    if id > 0
        _CP_DoPaste(id, keepOpen)
}

_CP_PasteImage(imagePath) {
    try {
        if !FileExist(imagePath)
            return
        pBitmap := (%"Gdip_CreateBitmapFromFile"%).Call(imagePath)
        if (!pBitmap || pBitmap = 0) {
            pBitmap := (%"ImagePut"%).Call("Bitmap", imagePath)
            if (!pBitmap || pBitmap = "") {
                OutputDebug("[CP] PasteImage: cannot load " . imagePath)
                return
            }
            (%"Gdip_SetBitmapToClipboard"%).Call(pBitmap)
            (%"ImageDestroy"%).Call(pBitmap)
        } else {
            (%"Gdip_SetBitmapToClipboard"%).Call(pBitmap)
            (%"Gdip_DisposeImage"%).Call(pBitmap)
        }
        Sleep(50)
        Send("^v")
    } catch as err {
        OutputDebug("[CP] PasteImage error: " . err.Message)
    }
}

; ===================== 操作：删除 =====================
_CP_DoDelete(id) {
    global ClipboardFTS5DB

    if !ClipboardFTS5DB || ClipboardFTS5DB = 0
        return

    try {
        SQL := "DELETE FROM ClipMain WHERE ID = " . id
        if ClipboardFTS5DB.Exec(SQL) {
            CP_SendToWeb('{"type":"deleted","id":' . id . '}')
        }
    } catch as err {
        OutputDebug("[CP] DoDelete error: " . err.Message)
    }
}

; ===================== 操作：置顶 =====================
_CP_DoPin(id) {
    global ClipboardFTS5DB

    if !ClipboardFTS5DB || ClipboardFTS5DB = 0
        return

    try {
        SQL := "SELECT IsFavorite FROM ClipMain WHERE ID = " . id
        table := ""
        currentState := 0
        if ClipboardFTS5DB.GetTable(SQL, &table) {
            if table.HasRows && table.Rows.Length > 0
                currentState := Integer(table.Rows[1][1])
        }

        newState := currentState ? 0 : 1
        SQL := "UPDATE ClipMain SET IsFavorite = " . newState . " WHERE ID = " . id
        if ClipboardFTS5DB.Exec(SQL) {
            CP_SendToWeb('{"type":"pinned","id":' . id . ',"state":' . newState . '}')
        }
    } catch as err {
        OutputDebug("[CP] DoPin error: " . err.Message)
    }
}

; ===================== 操作：纯文本复制 =====================
_CP_DoCopyPlain(id, keepOpen := false) {
    global ClipboardFTS5DB

    if !ClipboardFTS5DB || ClipboardFTS5DB = 0
        return

    try {
        row := _CP_GetClipRow(id)
        if row["content"] != ""
            A_Clipboard := row["content"]
        _CP_MaybeHide(keepOpen)
    } catch as err {
        OutputDebug("[CP] DoCopyPlain error: " . err.Message)
    }
}

; ===================== 操作：复制到剪贴板（不发送粘贴） =====================
_CP_DoCopyToClipboard(id, keepOpen := false) {
    global ClipboardFTS5DB
    if !ClipboardFTS5DB || ClipboardFTS5DB = 0
        return
    try {
        row := _CP_GetClipRow(id)
        content := row["content"]
        dataType := row["dataType"]
        imagePath := row["imagePath"]
        if content = "" && imagePath = ""
            return
        dt := StrLower(dataType)
        if (dt = "image" || dt = "screenshot") && imagePath != "" && FileExist(imagePath) {
            pBitmap := (%"Gdip_CreateBitmapFromFile"%).Call(imagePath)
            if (!pBitmap || pBitmap = 0) {
                pBitmap := (%"ImagePut"%).Call("Bitmap", imagePath)
                if (!pBitmap || pBitmap = "") {
                    OutputDebug("[CP] CopyToClipboard: cannot load image")
                    return
                }
                (%"Gdip_SetBitmapToClipboard"%).Call(pBitmap)
                (%"ImageDestroy"%).Call(pBitmap)
            } else {
                (%"Gdip_SetBitmapToClipboard"%).Call(pBitmap)
                (%"Gdip_DisposeImage"%).Call(pBitmap)
            }
        } else {
            A_Clipboard := content
        }
        _CP_MaybeHide(keepOpen)
    } catch as err {
        OutputDebug("[CP] DoCopyToClipboard error: " . err.Message)
    }
}

; ===================== 操作：粘贴纯文本（去 HTML 标签） =====================
_CP_DoPastePlain(id, keepOpen := false) {
    global ClipboardFTS5DB
    if !ClipboardFTS5DB || ClipboardFTS5DB = 0
        return
    try {
        row := _CP_GetClipRow(id)
        dt := StrLower(row["dataType"] . "")
        if dt = "image" || dt = "screenshot" {
            _CP_DoPaste(id, keepOpen)
            return
        }
        plain := _CP_StripHtml(row["content"] . "")
        if plain = ""
            return
        _CP_MaybeHide(keepOpen)
        Sleep(keepOpen ? 30 : 50)
        A_Clipboard := plain
        Sleep(30)
        Send("^v")
    } catch as err {
        OutputDebug("[CP] DoPastePlain error: " . err.Message)
    }
}

; ===================== 操作：粘贴并换行 =====================
_CP_DoPasteWithNewline(id, keepOpen := false) {
    global ClipboardFTS5DB
    if !ClipboardFTS5DB || ClipboardFTS5DB = 0
        return
    try {
        row := _CP_GetClipRow(id)
        dt := StrLower(row["dataType"] . "")
        if dt = "image" || dt = "screenshot" {
            _CP_DoPaste(id, keepOpen)
            return
        }
        content := row["content"] . ""
        if content = ""
            return
        txt := RTrim(content, "`r`n") . "`r`n"
        _CP_MaybeHide(keepOpen)
        Sleep(keepOpen ? 30 : 50)
        A_Clipboard := txt
        Sleep(30)
        Send("^v")
    } catch as err {
        OutputDebug("[CP] DoPasteWithNewline error: " . err.Message)
    }
}

; ===================== 操作：粘贴路径 =====================
_CP_DoPastePath(id, keepOpen := false) {
    global ClipboardFTS5DB
    if !ClipboardFTS5DB || ClipboardFTS5DB = 0
        return
    try {
        row := _CP_GetClipRow(id)
        path := _CP_ResolvePastePath(row["content"] . "", row["sourcePath"] . "")
        if path = ""
            return
        _CP_MaybeHide(keepOpen)
        Sleep(keepOpen ? 30 : 50)
        A_Clipboard := path
        Sleep(30)
        Send("^v")
    } catch as err {
        OutputDebug("[CP] DoPastePath error: " . err.Message)
    }
}

; ===================== 操作：获取预览 =====================
_CP_DoGetPreview(id) {
    global ClipboardFTS5DB

    if !ClipboardFTS5DB || ClipboardFTS5DB = 0
        return

    try {
        selectFields := _CP_BuildSelectFields()
        SQL := "SELECT " . selectFields . " FROM ClipMain WHERE ID = " . id
        table := ""
        if ClipboardFTS5DB.GetTable(SQL, &table) {
            if table.HasRows && table.Rows.Length > 0 {
                columnIndexMap := Map()
                if table.HasNames && table.ColumnNames.Length > 0 {
                    Loop table.ColumnNames.Length {
                        columnIndexMap[table.ColumnNames[A_Index]] := A_Index
                    }
                }
                item := _CP_RowToMap(table.Rows[1], columnIndexMap)

                content := item.Has("Content") ? item["Content"] : ""
                sourceApp := item.Has("SourceApp") ? item["SourceApp"] : ""
                dataType := item.Has("DataType") ? item["DataType"] : ""
                charCount := item.Has("CharCount") ? item["CharCount"] : 0
                sortTime := item.Has("LastCopyTime") ? item["LastCopyTime"] : ""
                imagePath := item.Has("ImagePath") ? item["ImagePath"] : ""

                json := '{"type":"preview","id":' . id
                json .= ',"content":' . _CP_JsonStr(content)
                json .= ',"dataType":' . _CP_JsonStr(dataType)
                json .= ',"imagePath":' . _CP_JsonStr(imagePath)
                json .= ',"meta":{'
                json .= '"charCount":' . (charCount ? charCount : StrLen(content))
                json .= ',"sourceApp":' . _CP_JsonStr(sourceApp)
                json .= ',"time":' . _CP_JsonStr(sortTime)
                json .= ',"dataType":' . _CP_JsonStr(dataType)
                json .= '}}'

                CP_SendToWeb(json)
            }
        }
    } catch as err {
        OutputDebug("[CP] DoGetPreview error: " . err.Message)
    }
}
