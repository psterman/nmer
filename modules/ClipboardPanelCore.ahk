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
global g_CP_TimeRange := "all"  ; all | day | week | month | date:YYYY-MM-DD
global g_CP_TitleH := 0
global g_CP_FocusPending := false
global g_CP_WM_ActivateHideCallback := 0
global g_CP_PeekGui := 0

_CP_ClipCacheRoot() {
    return (IsSet(MainScriptDir) ? MainScriptDir : A_ScriptDir) "\Cache"
}

; SQLite / Map 中空串或非数字不可直接 Integer()（v2 会抛错）
_CP_SafeInt(val, default := 0) {
    if (Type(val) = "Integer")
        return val
    s := Trim(String(val))
    if (s = "")
        return default
    try {
        return Integer(s)
    } catch as err {
        return default
    }
}

_CP_ThumbPathToVirtualUrl(thumbPath) {
    p := Trim(String(thumbPath))
    if (p = "" || !FileExist(p))
        return ""
    root := _CP_ClipCacheRoot()
    if (StrLen(p) < StrLen(root) + 2)
        return ""
    if (StrLower(SubStr(p, 1, StrLen(root))) != StrLower(root))
        return ""
    rel := SubStr(p, StrLen(root) + 2)
    return "https://clip.local/" . StrReplace(rel, "\", "/")
}

_CP_SetClipboardFileDrop(filePath) {
    p := Trim(String(filePath))
    if (p = "" || !FileExist(p))
        return false
    cfHDrop := 15
    sizeDf := 20
    nChars := StrPut(p, "UTF-16")
    if (nChars < 2)
        return false
    total := sizeDf + nChars * 2 + 2
    hMem := DllCall("GlobalAlloc", "UInt", 0x42, "Ptr", total, "Ptr")
    if !hMem
        return false
    ptr := DllCall("GlobalLock", "Ptr", hMem, "Ptr")
    if !ptr {
        DllCall("GlobalFree", "Ptr", hMem)
        return false
    }
    NumPut("UInt", sizeDf, ptr, 0)
    NumPut("Int64", 0, ptr, 4)
    NumPut("UInt", 0, ptr, 12)
    NumPut("UInt", 1, ptr, 16)
    cw := StrPut(p, ptr + sizeDf, "UTF-16")
    NumPut("UShort", 0, ptr, sizeDf + cw * 2)
    DllCall("GlobalUnlock", "Ptr", hMem)
    if !DllCall("OpenClipboard", "Ptr", 0) {
        DllCall("GlobalFree", "Ptr", hMem)
        return false
    }
    DllCall("EmptyClipboard", "Ptr")
    if !DllCall("SetClipboardData", "UInt", cfHDrop, "Ptr", hMem, "Ptr") {
        DllCall("CloseClipboard", "Ptr")
        DllCall("GlobalFree", "Ptr", hMem)
        return false
    }
    DllCall("CloseClipboard", "Ptr")
    return true
}

_CP_ImagePeekHide(*) {
    global g_CP_PeekGui
    if g_CP_PeekGui {
        try g_CP_PeekGui.Destroy()
        g_CP_PeekGui := 0
    }
}

_CP_ImagePeekShow(imagePath) {
    global g_CP_PeekGui
    p := Trim(String(imagePath))
    if (p = "" || !FileExist(p))
        return
    _CP_ImagePeekHide()
    info := _CP_GetImageInfo(p)
    iw := info["width"]
    ih := info["height"]
    if (iw < 1 || ih < 1)
        return
    sw := SysGet(0)
    sh := SysGet(1)
    maxW := Floor(sw * 0.92)
    maxH := Floor(sh * 0.92)
    scale := Min(1, Min(maxW / iw, maxH / ih))
    dw := Max(1, Round(iw * scale))
    dh := Max(1, Round(ih * scale))
    g_CP_PeekGui := Gui("+AlwaysOnTop -Caption +ToolWindow", "ClipboardPeek")
    g_CP_PeekGui.MarginX := 0
    g_CP_PeekGui.MarginY := 0
    g_CP_PeekGui.BackColor := "000000"
    g_CP_PeekGui.Add("Picture", "w" . dw . " h" . dh, p)
    g_CP_PeekGui.OnEvent("Close", _CP_ImagePeekHide)
    x := (sw - dw) // 2
    y := (sh - dh) // 2
    g_CP_PeekGui.Show("x" . x . " y" . y . " NoActivate")
}

_CP_ImagePeekShowById(id) {
    row := _CP_GetClipRow(id)
    path := Trim(row["imagePath"] . "")
    dt := StrLower(row["dataType"] . "")
    if (dt != "image" && dt != "screenshot")
        return
    if (path = "" || RegExMatch(path, "i)^https?://"))
        return
    _CP_ImagePeekShow(path)
}

_CP_HasClipMainColumn(colName) {
    global ClipboardFTS5DB
    if !ClipboardFTS5DB || ClipboardFTS5DB = 0
        return false
    try {
        table := ""
        if ClipboardFTS5DB.GetTable("PRAGMA table_info(ClipMain)", &table) {
            if table.HasRows && table.Rows.Length > 0 {
                Loop table.Rows.Length {
                    if (table.Rows[A_Index][2] = colName)
                        return true
                }
            }
        }
    } catch {
    }
    return false
}

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

    g_CP_Gui := Gui("+AlwaysOnTop +Resize +MinimizeBox +MaximizeBox -DPIScale +Owner", "剪贴板")
    g_CP_Gui.BackColor := "0a0a0a"
    g_CP_Gui.MarginX := 0
    g_CP_Gui.MarginY := 0

    g_CP_Gui.Show("w" . WinW . " h" . WinH . " Hide")
    g_CP_Gui.OnEvent("Close", (*) => CP_Hide())
    g_CP_Gui.OnEvent("Size", _CP_OnGuiResize)

    WebView2.create(g_CP_Gui.Hwnd, _CP_OnWV2Created)
}

; ===================== 显示 / 隐藏 =====================
CP_IsForeground() {
    global g_CP_Gui, g_CP_Visible
    if !g_CP_Visible || !g_CP_Gui
        return false
    try {
        h := g_CP_Gui.Hwnd
        return WinExist("ahk_id " . h) && WinActive("ahk_id " . h)
    } catch as e {
        return false
    }
}

CP_Show() {
    global g_CP_Gui, g_CP_Visible, g_CP_Ready, g_CP_Ctrl

    if !g_CP_Gui
        CP_Init()

    if g_CP_Visible {
        try WinActivate(g_CP_Gui.Hwnd)
        WebView2_MoveFocusProgrammatic(g_CP_Ctrl)
        SetTimer(_CP_DeferredMoveFocus100, -100)
        return
    }

    _CP_CenterWindow()
    g_CP_Gui.Show()
    try WinMaximize("ahk_id " . g_CP_Gui.Hwnd)
    g_CP_Visible := true
    try WinActivate("ahk_id " . g_CP_Gui.Hwnd)

    WMActivateChain_Register(_CP_WM_ACTIVATE)

    ; 缓解 WebView2 在「先 Hide 再 Show」宿主上的黑屏：显示后立即刷新合成层
    _CP_RefreshWebViewComposition()
    SetTimer(_CP_RefreshWebViewComposition, -120)
    SetTimer(_CP_RefreshWebViewComposition, -380)

    if g_CP_Ready
        _CP_PushInitialData()

    WebView2_MoveFocusProgrammatic(g_CP_Ctrl)
    SetTimer(_CP_DeferredMoveFocus100, -100)
    SetTimer(_CP_FocusDeferred, -80)
    CP_RequestFocusInput()
}

_CP_DeferredMoveFocus100(*) {
    global g_CP_Gui, g_CP_Visible, g_CP_Ctrl
    if g_CP_Visible && g_CP_Gui
        WebView2_MoveFocusProgrammatic(g_CP_Ctrl)
}

_CP_FocusDeferred() {
    global g_CP_Gui, g_CP_Visible, g_CP_Ctrl
    if g_CP_Visible && g_CP_Gui {
        try WinActivate(g_CP_Gui.Hwnd)
        WebView2_MoveFocusProgrammatic(g_CP_Ctrl)
    }
}

CP_Hide() {
    global g_CP_Gui, g_CP_Visible, g_CP_SearchTimer, g_CP_WM_ActivateHideCallback

    if g_CP_WM_ActivateHideCallback {
        SetTimer(g_CP_WM_ActivateHideCallback, 0)
        g_CP_WM_ActivateHideCallback := 0
    }

    if g_CP_SearchTimer {
        SetTimer(g_CP_SearchTimer, 0)
        g_CP_SearchTimer := 0
    }

    _CP_ImagePeekHide()

    WMActivateChain_Unregister(_CP_WM_ACTIVATE)

    g_CP_Visible := false
    if g_CP_Gui
        g_CP_Gui.Hide()
}

CP_RequestFocusInput() {
    global g_CP_WV2, g_CP_Ready, g_CP_FocusPending
    if g_CP_WV2 && g_CP_Ready {
        WebView_QueueJson(g_CP_WV2, '{"type":"focus_input"}')
        g_CP_FocusPending := false
        return
    }
    g_CP_FocusPending := true
}

CP_Toggle() {
    global g_CP_Visible
    if g_CP_Visible
        CP_Hide()
    else
        CP_Show()
}

; ===================== WM_ACTIVATE 自动隐藏 =====================
; WebView2 将焦点移入编辑区时，宿主可能短暂收到 WA_INACTIVE，短定时器会误关面板。
_CP_WM_ACTIVATE(wParam, lParam, msg, hwnd) {
    global g_CP_Gui, g_CP_Visible, g_CP_WM_ActivateHideCallback

    if !g_CP_Visible || !g_CP_Gui
        return
    if (hwnd != g_CP_Gui.Hwnd)
        return

    if g_CP_WM_ActivateHideCallback {
        SetTimer(g_CP_WM_ActivateHideCallback, 0)
        g_CP_WM_ActivateHideCallback := 0
    }

    wp := wParam & 0xFFFF
    if (wp = 0) {
        g_CP_WM_ActivateHideCallback := _CP_DeferredHideIfStillInactive.Bind()
        SetTimer(g_CP_WM_ActivateHideCallback, -380)
    }
}

_CP_DeferredHideIfStillInactive(*) {
    global g_CP_Gui, g_CP_Visible, g_CP_WM_ActivateHideCallback
    g_CP_WM_ActivateHideCallback := 0
    if !g_CP_Visible || !g_CP_Gui
        return
    try {
        if WinActive("ahk_id " . g_CP_Gui.Hwnd)
            return
    } catch as e {
        return
    }
    CP_Hide()
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

    try ApplyUnifiedWebViewAssets(g_CP_WV2)
    cacheRoot := _CP_ClipCacheRoot()
    if !DirExist(cacheRoot)
        DirCreate(cacheRoot)
    try g_CP_WV2.SetVirtualHostNameToFolderMapping("clip.local", cacheRoot, WebView2.HOST_RESOURCE_ACCESS_KIND.ALLOW)
    g_CP_WV2.Navigate(BuildAppLocalUrl("ClipboardPanel.html"))
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
    if g_CP_WV2 && g_CP_Ready {
        if (IsObject(jsonStr))
            WebView_QueuePayload(g_CP_WV2, jsonStr)
        else
            WebView_QueueJson(g_CP_WV2, jsonStr)
    }
}

_CP_BeginHostDrag(*) {
    global g_CP_Gui
    if !g_CP_Gui
        return
    try PostMessage(0xA1, 2,,, "ahk_id " . g_CP_Gui.Hwnd)  ; WM_NCLBUTTONDOWN HTCAPTION
    catch as e {
    }
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
    if !(msg is Map)
        return
    action := msg.Has("type") ? msg["type"] : (msg.Has("action") ? msg["action"] : "")
    if (action = "")
        return

    switch action {
        case "dragHost":
            _CP_BeginHostDrag()

        case "ready":
            g_CP_Ready := true
            OutputDebug("[CP] WebView ready")
            if g_CP_Visible
                _CP_PushInitialData()
            if g_CP_FocusPending
                CP_RequestFocusInput()

        case "search":
            keyword := msg.Has("keyword") ? msg["keyword"] : ""
            filterType := msg.Has("filterType") ? msg["filterType"] : "all"
            timeRange := msg.Has("timeRange") ? msg["timeRange"] : "all"
            global g_CP_TimeRange
            g_CP_TimeRange := _CP_NormalizeTimeRange(timeRange)
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

        case "ocrImage":
            if msg.Has("id")
                _CP_DoOcrImage(msg["id"], _CP_MsgKeepOpen(msg))
        case "screenshotToOcr":
            _CP_DoScreenshotToOcr(_CP_MsgKeepOpen(msg))

        case "loadMore":
            offset := msg.Has("offset") ? Integer(msg["offset"]) : 0
            _CP_DoLoadMore(offset)

        case "getPreview":
            if msg.Has("id")
                _CP_DoGetPreview(msg["id"])

        case "imagePeek":
            show := msg.Has("show") && (msg["show"] = true || msg["show"] = 1 || msg["show"] = "true")
            if show {
                if msg.Has("id")
                    _CP_ImagePeekShowById(msg["id"])
            } else
                _CP_ImagePeekHide()

        case "setClipboardFileDrop":
            if msg.Has("path")
                _CP_SetClipboardFileDrop(msg["path"])

        case "requestHide":
            CP_Hide()

        case "cpScCtxCmd":
            cmdSc := msg.Has("cmdId") ? String(msg["cmdId"]) : ""
            idSc := msg.Has("id") ? Integer(msg["id"]) : 0
            if (cmdSc = "" || idSc < 1)
                return
            m := _CP_BuildClipScCtxMap(idSc)
            if !(m is Map) || !m.Has("Source")
                return
            try SC_ExecuteContextCommand(cmdSc, 0, m)
            catch as err {
                OutputDebug("[CP] cpScCtxCmd: " . err.Message)
            }

        case "openWindowsRecycleBin":
            SCWV_OpenWindowsRecycleBinFolder()

        default:
            OutputDebug("[CP] Unknown msg type: " . action)
    }
}

; ===================== 数据推送 =====================
_CP_PushInitialData() {
    global g_CP_LastKeyword, g_CP_FilterType, g_CP_TimeRange
    g_CP_LastKeyword := ""
    g_CP_FilterType := "all"
    g_CP_TimeRange := "all"
    items := _CP_LoadItems("", g_CP_FilterType, 0, 30)
    total := _CP_GetTotalCount("", g_CP_FilterType)
    hasMore := (items.Length < total)
    json := _CP_BuildItemsJson("init", items, total, hasMore)
    CP_SendToWeb(json)
}

; 外部 OnClipboardChange 写入 ClipMain 后调用：面板已显示时刷新列表（保留当前搜索词与筛选）
CP_NotifyClipboardUpdated() {
    global g_CP_Visible, g_CP_Ready, g_CP_LastKeyword, g_CP_FilterType
    if !g_CP_Visible || !g_CP_Ready
        return
    try {
        kw := g_CP_LastKeyword
        ft := g_CP_FilterType
        items := _CP_LoadItems(kw, ft, 0, 30)
        total := _CP_GetTotalCount(kw, ft)
        hasMore := (items.Length < total)
        json := _CP_BuildItemsJson("init", items, total, hasMore)
        CP_SendToWeb(json)
    } catch as err {
        OutputDebug("[CP] NotifyClipboardUpdated: " . err.Message)
    }
}

_CP_DoLoadMore(offset) {
    global g_CP_LastKeyword, g_CP_FilterType
    offset := Integer(offset)
    if offset < 0
        offset := 0
    items := _CP_LoadItems(g_CP_LastKeyword, g_CP_FilterType, offset, 30)
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
    items := _CP_LoadItems(keyword, filterType, 0, 30)
    total := _CP_GetTotalCount(keyword, filterType)
    hasMore := (items.Length < total)
    json := _CP_BuildItemsJson("searchResult", items, total, hasMore)
    CP_SendToWeb(json)
}

; ===================== 数据库查询 =====================
_CP_LoadItems(keyword := "", filterType := "all", offset := 0, limit := 30) {
    global ClipboardFTS5DB

    if !ClipboardFTS5DB || ClipboardFTS5DB = 0
        return []

    offset := Integer(offset)
    limit := Integer(limit)
    if offset < 0
        offset := 0
    if limit < 1
        limit := 30

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
    hasThumbnailData := false
    hasSourceUrl := false
    hasImageFormat := false
    hasImageWidth := false
    hasImageHeight := false
    hasFileSize := false
    hasThumbPath := false

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
                    if colName = "ThumbnailData"
                        hasThumbnailData := true
                    if colName = "SourceUrl"
                        hasSourceUrl := true
                    if colName = "ImageFormat"
                        hasImageFormat := true
                    if colName = "ImageWidth"
                        hasImageWidth := true
                    if colName = "ImageHeight"
                        hasImageHeight := true
                    if colName = "FileSize"
                        hasFileSize := true
                    if colName = "ThumbPath"
                        hasThumbPath := true
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
    if hasThumbnailData
        fields .= ", ThumbnailData"
    else
        fields .= ", '' AS ThumbnailData"
    if hasSourceUrl
        fields .= ", SourceUrl"
    else
        fields .= ", '' AS SourceUrl"
    if hasImageFormat
        fields .= ", ImageFormat"
    else
        fields .= ", '' AS ImageFormat"
    if hasImageWidth
        fields .= ", ImageWidth"
    else
        fields .= ", 0 AS ImageWidth"
    if hasImageHeight
        fields .= ", ImageHeight"
    else
        fields .= ", 0 AS ImageHeight"
    if hasFileSize
        fields .= ", FileSize"
    else
        fields .= ", 0 AS FileSize"
    if hasThumbPath
        fields .= ", ThumbPath"
    else
        fields .= ", '' AS ThumbPath"

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

_CP_NormalizeTimeRange(tr) {
    tr := StrLower(Trim(String(tr)))
    if (tr = "" || tr = "all")
        return "all"
    if (tr = "day" || tr = "week" || tr = "month")
        return tr
    if (SubStr(tr, 1, 5) = "date:") {
        ds := SubStr(tr, 6)
        if RegExMatch(ds, "^\d{4}-\d{2}-\d{2}$")
            return "date:" . ds
    }
    return "all"
}

_CP_AppendTimeConditions(&conditions) {
    global g_CP_TimeRange
    tr := _CP_NormalizeTimeRange(g_CP_TimeRange)
    if (tr = "all")
        return
    col := "datetime(COALESCE(LastCopyTime, Timestamp))"
    if (tr = "day")
        conditions.Push(col . " >= datetime('now', '-1 day', 'localtime')")
    else if (tr = "week")
        conditions.Push(col . " >= datetime('now', '-7 day', 'localtime')")
    else if (tr = "month")
        conditions.Push(col . " >= datetime('now', '-30 day', 'localtime')")
    else if (SubStr(tr, 1, 5) = "date:") {
        ds := SubStr(tr, 6)
        if RegExMatch(ds, "^\d{4}-\d{2}-\d{2}$")
            conditions.Push("date(COALESCE(LastCopyTime, Timestamp)) = '" . StrReplace(ds, "'", "''") . "'")
    }
}

_CP_BuildWhereClause(keyword, filterType := "all") {
    global ClipboardFTS5DB
    keyword := Trim(keyword)
    filterType := _CP_NormalizeFilterType(filterType)

    conditions := []
    if filterType = "favorite"
        conditions.Push("IsFavorite = 1")
    else if filterType = "image"
        conditions.Push("(LOWER(DataType) = 'image' OR LOWER(DataType) = 'screenshot')")
    else if filterType = "clipboard"
        conditions.Push("(LOWER(DataType) <> 'image' AND LOWER(DataType) <> 'screenshot')")
    else if filterType = "url"
        ; 纯链接 +「图片地址」类（DataType 为 Image 且 ImagePath 为 http(s)）
        conditions.Push("(LOWER(DataType) = 'link' OR (LOWER(DataType) = 'image' AND LOWER(IFNULL(ImagePath, '')) LIKE 'http%'))")
    else if filterType != "all"
        conditions.Push("LOWER(DataType) = '" . filterType . "'")

    _CP_AppendTimeConditions(&conditions)

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
    if filterType = "all" || filterType = "text" || filterType = "image" || filterType = "clipboard" || filterType = "url" || filterType = "code" || filterType = "favorite"
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
    for key in ["ID", "Content", "SourceApp", "DataType", "CharCount", "Timestamp", "ImagePath", "IsFavorite", "LastCopyTime", "IconPath", "SourcePath", "ThumbnailData", "SourceUrl", "ImageFormat", "ImageWidth", "ImageHeight", "FileSize", "ThumbPath"] {
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

    spec := "[]"
    try {
        if IsSet(_VK_SceneCtxMenuItemsJson)
            spec := _VK_SceneCtxMenuItemsJson("clipboard")
    } catch {
    }
    json .= '],"total":' . total . ',"hasMore":' . (hasMore ? "true" : "false") . ',"ctxMenuSpec":' . spec . "}"
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
    thumbnailData := item.Has("ThumbnailData") ? item["ThumbnailData"] : ""
    thumbDataUrl := _CP_ThumbnailToDataUrl(thumbnailData)
    thumbPath := item.Has("ThumbPath") ? item["ThumbPath"] : ""
    thumbVirtualUrl := _CP_ThumbPathToVirtualUrl(thumbPath)
    imageDataUrl := ""
    ip := Trim(String(imagePath))
    dtLower := StrLower(String(dataType))
    if ((dtLower = "image" || dtLower = "screenshot") && ip != "") {
        if !RegExMatch(ip, "i)^https?://") {
            if FileExist(ip)
                imageDataUrl := _CP_ImagePathToDataUrl(ip)
        }
    }
    imgW := item.Has("ImageWidth") ? _CP_SafeInt(item["ImageWidth"]) : 0
    imgH := item.Has("ImageHeight") ? _CP_SafeInt(item["ImageHeight"]) : 0
    fSize := item.Has("FileSize") ? _CP_SafeInt(item["FileSize"]) : 0

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
    json .= ',"imageDataUrl":' . _CP_JsonStr(imageDataUrl)
    json .= ',"thumbDataUrl":' . _CP_JsonStr(thumbDataUrl)
    json .= ',"thumbVirtualUrl":' . _CP_JsonStr(thumbVirtualUrl)
    json .= ',"imageWidth":' . imgW
    json .= ',"imageHeight":' . imgH
    json .= ',"fileSize":' . fSize
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
    row := Map("content", "", "dataType", "", "imagePath", "", "sourcePath", "", "thumbnailData", "")
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
                row["thumbnailData"] := item.Has("ThumbnailData") ? item["ThumbnailData"] : ""
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

; 供搜索中心同款右键命令：合成与结果行一致的 Map 供 SC_ExecuteContextCommand 使用
_CP_BuildClipScCtxMap(clipId) {
    id := Integer(clipId)
    if id < 1
        return Map()
    row := _CP_GetClipRow(id)
    content := row["content"]
    dtRaw := row["dataType"]
    dt := StrLower(dtRaw)
    ip := Trim(String(row["imagePath"]))
    sp := Trim(String(row["sourcePath"]))
    pathForFile := _CP_ResolvePastePath(content, sp)
    if (pathForFile = "" && ip != "")
        pathForFile := ip
    contentOut := content
    dataTypeOut := dtRaw
    if (pathForFile != "" && FileExist(pathForFile)) {
        contentOut := pathForFile
        if (dt = "image" || dt = "screenshot")
            dataTypeOut := "Image"
        else
            dataTypeOut := "file"
    } else if ((dt = "image" || dt = "screenshot") && ip != "" && FileExist(ip)) {
        contentOut := ip
        dataTypeOut := "Image"
    }
    title := SubStr(content, 1, 120)
    if (title = "")
        title := "clip #" . id
    return Map(
        "Title", title,
        "Content", contentOut,
        "DataType", dataTypeOut,
        "OriginalDataType", dtRaw,
        "Source", "clipboard",
        "ClipboardId", id,
        "HubSegIndex", -1,
        "PromptMergedIndex", 0
    )
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
        thumbnailData := row["thumbnailData"]
        if content = "" && imagePath = ""
            if Trim(thumbnailData . "") = ""
                return

        _CP_MaybeHide(keepOpen)
        Sleep(keepOpen ? 30 : 50)

        dt := StrLower(dataType)
        if (dt = "image" || dt = "screenshot") {
            if _CP_SetClipboardImageFromRow(row) {
                Sleep(50)
                Send("^v")
                return
            }
            if (content = "")
                return
            A_Clipboard := content
            Sleep(30)
            Send("^v")
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

_CP_SetClipboardImageFromRow(row) {
    try {
        imagePath := Trim(row["imagePath"] . "")
        if (imagePath != "" && FileExist(imagePath)) {
            pBitmap := (%"Gdip_CreateBitmapFromFile"%).Call(imagePath)
            if (!pBitmap || pBitmap = 0) {
                pBitmap := (%"ImagePut"%).Call("Bitmap", imagePath)
                if (!pBitmap || pBitmap = "") {
                    OutputDebug("[CP] SetClipboardImageFromRow: cannot load image file")
                    return false
                }
                (%"Gdip_SetBitmapToClipboard"%).Call(pBitmap)
                (%"ImageDestroy"%).Call(pBitmap)
            } else {
                (%"Gdip_SetBitmapToClipboard"%).Call(pBitmap)
                (%"Gdip_DisposeImage"%).Call(pBitmap)
            }
            return true
        }

        b64 := Trim(row["thumbnailData"] . "")
        if (b64 = "")
            return false

        pBitmap := (%"ImagePut"%).Call("Bitmap", b64)
        if (!pBitmap || pBitmap = "") {
            pBitmap := (%"ImagePut"%).Call("Bitmap", "data:image/jpeg;base64," . b64)
        }
        if (!pBitmap || pBitmap = "") {
            OutputDebug("[CP] SetClipboardImageFromRow: cannot decode base64 image")
            return false
        }
        (%"Gdip_SetBitmapToClipboard"%).Call(pBitmap)
        (%"ImageDestroy"%).Call(pBitmap)
        return true
    } catch as err {
        OutputDebug("[CP] SetClipboardImageFromRow error: " . err.Message)
        return false
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
        thumbnailData := row["thumbnailData"]
        if content = "" && imagePath = ""
            if Trim(thumbnailData . "") = ""
                return
        dt := StrLower(dataType)
        if (dt = "image" || dt = "screenshot") {
            if !_CP_SetClipboardImageFromRow(row) {
                if (content = "")
                    return
                A_Clipboard := content
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
_CP_MimeFromImageExt(ext) {
    ext := StrLower(Trim(String(ext), "."))
    switch ext {
        case "jpg", "jpeg":
            return "image/jpeg"
        case "png":
            return "image/png"
        case "gif":
            return "image/gif"
        case "webp":
            return "image/webp"
        case "bmp":
            return "image/bmp"
        default:
            return "application/octet-stream"
    }
}

; WebView2 常拦截 file:// 本地图，用 data: 最稳；ImagePut 失败时再读文件原始字节
_CP_LocalFileRawBase64DataUrl(path) {
    p := Trim(String(path))
    if (p = "" || !FileExist(p))
        return ""
    try {
        SplitPath(p, , , &ext)
        mime := _CP_MimeFromImageExt(ext)
        buf := FileRead(p, "RAW")
        if !IsObject(buf) || buf.Size = 0
            return ""
        b64 := Base64Encode(buf)
        if (b64 = "")
            return ""
        return "data:" . mime . ";base64," . b64
    } catch as err {
        OutputDebug("[CP] LocalFileRawBase64DataUrl error: " . err.Message)
        return ""
    }
}

_CP_ImagePathToDataUrl(imagePath) {
    p := Trim(String(imagePath))
    if (p = "" || !FileExist(p))
        return ""
    try {
        u := (%"ImagePut"%).Call("URI", p, "png")
        if (u != "" && SubStr(u, 1, 5) = "data:")
            return u
    } catch as err {
        OutputDebug("[CP] ImagePathToDataUrl ImagePut: " . err.Message)
    }
    return _CP_LocalFileRawBase64DataUrl(p)
}

_CP_ThumbnailToDataUrl(thumbnailData) {
    if !thumbnailData || thumbnailData = ""
        return ""
    return "data:image/jpeg;base64," . thumbnailData
}

_CP_GetImageInfo(imagePath) {
    info := Map("width", 0, "height", 0, "fileSize", 0, "fileName", "")
    p := Trim(String(imagePath))
    if (p = "" || !FileExist(p))
        return info
    try SplitPath(p, &fileName)
    catch
        fileName := ""
    info["fileName"] := fileName
    try info["fileSize"] := FileGetSize(p)
    catch
        info["fileSize"] := 0
    try {
        pBitmap := (%"Gdip_CreateBitmapFromFile"%).Call(p)
        if pBitmap {
            imgWidth := 0
            imgHeight := 0
            (%"Gdip_GetImageDimensions"%).Call(pBitmap, &imgWidth, &imgHeight)
            info["width"] := imgWidth
            info["height"] := imgHeight
            (%"Gdip_DisposeImage"%).Call(pBitmap)
        }
    } catch as err {
        OutputDebug("[CP] GetImageInfo error: " . err.Message)
    }
    return info
}

_CP_FormatBytes(bytes) {
    if !IsNumber(bytes)
        return ""
    if (bytes < 1024)
        return bytes . " B"
    if (bytes < 1048576)
        return Round(bytes / 1024, 2) . " KB"
    if (bytes < 1073741824)
        return Round(bytes / 1048576, 2) . " MB"
    return Round(bytes / 1073741824, 2) . " GB"
}

_CP_DoOcrImage(id, keepOpen := false) {
    row := _CP_GetClipRow(id)
    dt := StrLower(row["dataType"] . "")
    imagePath := row["imagePath"] . ""
    if ((dt != "image" && dt != "screenshot") || imagePath = "" || !FileExist(imagePath)) {
        TrayTip("OCR", "当前项目不是有效图片", "Iconx 1")
        return
    }
    try {
        result := OCR.FromFile(imagePath)
        text := ""
        try text := result.Text
        catch {
            text := ""
        }
        text := Trim(text)
        if (text = "") {
            TrayTip("OCR", "未识别到文本", "Iconi 1")
            return
        }
        A_Clipboard := text
        try ShowExtractedTextWindow(text)
        catch {
            MsgBox(text, "图片 OCR")
        }
        _CP_MaybeHide(keepOpen)
    } catch as err {
        TrayTip("OCR", "识别失败: " . err.Message, "Iconx 1")
    }
}

_CP_DoScreenshotToOcr(keepOpen := false) {
    try {
        ; 复用现有截图智能流程（含 OCR 能力入口）
        ExecuteScreenshotWithMenu()
        _CP_MaybeHide(keepOpen)
    } catch as err {
        TrayTip("OCR", "截图 OCR 失败: " . err.Message, "Iconx 1")
    }
}

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
                thumbnailData := item.Has("ThumbnailData") ? item["ThumbnailData"] : ""
                thumbDataUrl := _CP_ThumbnailToDataUrl(thumbnailData)
                imageDataUrl := ""
                ip := Trim(String(imagePath))
                if ((StrLower(dataType) = "image" || StrLower(dataType) = "screenshot") && ip != "") {
                    if RegExMatch(ip, "i)^https?://") {
                        ; 网页图片：由前端直接用 URL 加载，不转 data:
                        imageDataUrl := ""
                    } else if FileExist(ip) {
                        imageDataUrl := _CP_ImagePathToDataUrl(ip)
                        if (imageDataUrl = "" && thumbDataUrl != "")
                            imageDataUrl := thumbDataUrl
                    }
                }
                imageInfo := _CP_GetImageInfo(imagePath)

                ; 获取新字段
                sourceUrl := item.Has("SourceUrl") ? item["SourceUrl"] : ""
                imageFormat := item.Has("ImageFormat") ? item["ImageFormat"] : ""
                dbImageWidth := item.Has("ImageWidth") ? item["ImageWidth"] : 0
                dbImageHeight := item.Has("ImageHeight") ? item["ImageHeight"] : 0
                dbFileSize := item.Has("FileSize") ? item["FileSize"] : 0

                ; 优先使用数据库中的元信息，fallback 到动态获取
                finalWidth := dbImageWidth ? dbImageWidth : imageInfo["width"]
                finalHeight := dbImageHeight ? dbImageHeight : imageInfo["height"]
                finalFileSize := dbFileSize ? dbFileSize : imageInfo["fileSize"]

                ; 图片格式：优先数据库，否则从文件扩展名推断
                if (imageFormat = "" && imagePath != "") {
                    SplitPath(imagePath, , , &ext)
                    imageFormat := StrLower(ext)
                }

                json := '{"type":"preview","id":' . id
                json .= ',"content":' . _CP_JsonStr(content)
                json .= ',"dataType":' . _CP_JsonStr(dataType)
                json .= ',"imagePath":' . _CP_JsonStr(imagePath)
                json .= ',"imageDataUrl":' . _CP_JsonStr(imageDataUrl)
                json .= ',"thumbDataUrl":' . _CP_JsonStr(thumbDataUrl)
                json .= ',"sourceUrl":' . _CP_JsonStr(sourceUrl)
                json .= ',"imageFormat":' . _CP_JsonStr(imageFormat)
                json .= ',"meta":{'
                json .= '"charCount":' . (charCount ? charCount : StrLen(content))
                json .= ',"sourceApp":' . _CP_JsonStr(sourceApp)
                json .= ',"time":' . _CP_JsonStr(sortTime)
                json .= ',"dataType":' . _CP_JsonStr(dataType)
                json .= ',"imageWidth":' . finalWidth
                json .= ',"imageHeight":' . finalHeight
                json .= ',"fileSize":' . finalFileSize
                json .= ',"fileSizeText":' . _CP_JsonStr(_CP_FormatBytes(finalFileSize))
                json .= ',"fileName":' . _CP_JsonStr(imageInfo["fileName"])
                json .= ',"sourceUrl":' . _CP_JsonStr(sourceUrl)
                json .= ',"imageFormat":' . _CP_JsonStr(imageFormat)
                json .= '}}'

                CP_SendToWeb(json)
            }
        }
    } catch as err {
        OutputDebug("[CP] DoGetPreview error: " . err.Message)
    }
}
