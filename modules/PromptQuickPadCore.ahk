; ======================================================================================================================
; PromptQuickPadCore.ahk — Prompt Quick-Pad WebView2 宿主（须 #Include 在 AIListPanel.ahk 之后）
; 依赖：lib\WebView2.ahk、Jxon（父脚本已 #Include）
; ======================================================================================================================

#Requires AutoHotkey v2.0

global g_PQP_Gui := 0
global g_PQP_WV2 := 0
global g_PQP_Ctrl := 0
global g_PQP_Ready := false
global g_PQP_Visible := false
global g_PQP_LastShown := 0
global g_PQP_SearchTimer := 0
global g_PQP_LastKeyword := ""
global g_PQP_LastCategory := "全部"
global g_PQP_FocusPending := false

; 依赖的外部符号（来自 AIListPanel.ahk / 主脚本，运行时已加载）
global PromptQuickPad_PinTop := true
global PromptQuickPad_WebSearchKeyword := ""
global PromptQuickPadSelectedCategory := "全部"
global AIListPanelWindowX := 0
global AIListPanelWindowY := 0
global AIListPanelWindowW := 560
global AIListPanelWindowH := 620

; 外部函数依赖（来自 AIListPanel.ahk，运行时由 #Include 顺序保证可用）：
;   PromptQuickPad_LoadPinFromIni, PromptQuickPad_PushDataToWeb,
;   PromptQuickPad_ProcessWebMessage, HideAIListPanel
; LSP 对跨文件函数的 "never assigned" 警告可忽略。

; AHK v2 动态函数调用：(%name%)(args) 按函数名查找并调用，而非变量解引用。
_PQP_CallExternal(funcName, args*) {
    try {
        return (%funcName%)(args*)
    } catch as err {
        OutputDebug("[PQP] external call failed: " . funcName . " - " . err.Message)
    }
}

_PQP_GetWebView2Class() {
    try {
        return (%"WebView2"%)
    } catch as err {
        OutputDebug("[PQP] WebView2 class not found: " . err.Message)
    }
    return 0
}

; ===================== 对外：宿主句柄 =====================
PQP_GetGui() {
    global g_PQP_Gui
    return g_PQP_Gui
}

PQP_GetGuiHwnd() {
    global g_PQP_Gui
    if g_PQP_Gui
        try return g_PQP_Gui.Hwnd
    return 0
}

PQP_IsReady() {
    global g_PQP_Ready
    return g_PQP_Ready
}

PQP_IsVisible() {
    global g_PQP_Visible
    return g_PQP_Visible
}

; ===================== 初始化 =====================
PQP_Init() {
    global g_PQP_Gui

    if g_PQP_Gui
        return

    _PQP_CallExternal("PromptQuickPad_LoadPinFromIni")
    global PromptQuickPad_PinTop
    topOpt := PromptQuickPad_PinTop ? "+AlwaysOnTop" : "-AlwaysOnTop"

    g_PQP_Gui := Gui(topOpt . " +Resize +MinSize440x460 +MinimizeBox +MaximizeBox +Caption -DPIScale +Owner", "Prompt Quick-Pad")
    g_PQP_Gui.BackColor := "1e1e1e"
    g_PQP_Gui.MarginX := 0
    g_PQP_Gui.MarginY := 0
    g_PQP_Gui.OnEvent("Close", (*) => _PQP_CallExternal("HideAIListPanel"))
    g_PQP_Gui.OnEvent("Size", _PQP_OnGuiResize)

    g_PQP_Gui.Show("w560 h620 Hide")
    WV2 := _PQP_GetWebView2Class()
    if !WV2
        return
    WV2.create(g_PQP_Gui.Hwnd, _PQP_OnWV2Created, WebView2_EnsureSharedEnvBlocking())
}

_PQP_OnWV2Created(ctrl) {
    global g_PQP_WV2, g_PQP_Ctrl

    g_PQP_Ctrl := ctrl
    g_PQP_WV2 := ctrl.CoreWebView2

    try g_PQP_Ctrl.DefaultBackgroundColor := 0xFF1E1E1E
    try g_PQP_Ctrl.IsVisible := true

    _PQP_ApplyBounds()

    s := g_PQP_WV2.Settings
    s.AreDefaultContextMenusEnabled := false
    s.AreDevToolsEnabled := false
    ApplyWebView2PerformanceSettings(g_PQP_WV2)
    WebView2_RegisterHostBridge(g_PQP_WV2)

    g_PQP_WV2.add_WebMessageReceived(_PQP_OnWebMessage)
    try g_PQP_WV2.add_NavigationCompleted(_PQP_OnNavigationCompleted)

    try ApplyUnifiedWebViewAssets(g_PQP_WV2)
    g_PQP_WV2.Navigate(BuildAppLocalUrl("PromptQuickPad.html"))
}

_PQP_ApplyBounds() {
    global g_PQP_Gui, g_PQP_Ctrl
    if !g_PQP_Ctrl || !g_PQP_Gui
        return
    WinGetClientPos(, , &cw, &ch, g_PQP_Gui.Hwnd)
    WV2 := _PQP_GetWebView2Class()
    if !WV2
        return
    rc := WV2.RECT()
    rc.left := 0
    rc.top := 0
    rc.right := cw
    rc.bottom := ch
    g_PQP_Ctrl.Bounds := rc
}

_PQP_OnGuiResize(GuiObj, MinMax, Width, Height) {
    if MinMax = -1
        return
    _PQP_ApplyBounds()
}

_PQP_OnNavigationCompleted(sender, args) {
    global g_PQP_Visible
    if !g_PQP_Visible
        return
    try ok := args.IsSuccess
    catch {
        ok := true
    }
    if !ok
        return
    _PQP_RefreshWebViewComposition()
}

_PQP_RefreshWebViewComposition(*) {
    global g_PQP_Ctrl, g_PQP_Gui, g_PQP_Visible
    if !g_PQP_Visible || !g_PQP_Ctrl || !g_PQP_Gui
        return
    try {
        _PQP_ApplyBounds()
        g_PQP_Ctrl.NotifyParentWindowPositionChanged()
    } catch as err {
        OutputDebug("[PQP] RefreshWebViewComposition: " . err.Message)
    }
}

; ===================== AHK ↔ JS =====================
_PQP_PushTheme() {
    tm := _PQP_GetThemeMode()
    PQP_SendToWeb(Map("type", "set_theme", "themeMode", tm))
}

_PQP_NormalizeThemeToken(raw, fallback := "dark") {
    s := StrLower(Trim(String(raw)))
    if (s = "light" || s = "lite")
        return "light"
    if (s = "dark")
        return "dark"
    return (fallback = "light") ? "light" : "dark"
}

_PQP_GetThemeMode() {
    ; Prefer direct INI read so theme stays correct even if global state is stale.
    try {
        global ConfigFile
        if (IsSet(ConfigFile) && ConfigFile != "") {
            raw := IniRead(ConfigFile, "Settings", "ThemeMode", "")
            if (Trim(String(raw)) = "")
                raw := IniRead(ConfigFile, "Appearance", "ThemeMode", "")
            if (Trim(String(raw)) != "")
                return _PQP_NormalizeThemeToken(raw, "dark")
        }
    } catch {
    }
    try {
        fn := Func("ReadPersistedThemeMode")
        if IsObject(fn)
            return _PQP_NormalizeThemeToken(fn.Call(), "dark")
    } catch {
    }
    try {
        global ThemeMode
        return _PQP_NormalizeThemeToken(ThemeMode, "dark")
    } catch {
    }
    return "dark"
}

PQP_SendToWeb(jsonStr) {
    global g_PQP_WV2, g_PQP_Ready
    if g_PQP_WV2 && g_PQP_Ready {
        if (IsObject(jsonStr))
            WebView_QueuePayload(g_PQP_WV2, jsonStr)
        else
            WebView_QueueJson(g_PQP_WV2, jsonStr)
    }
}

_PQP_OnWebMessage(sender, args) {
    jsonStr := args.WebMessageAsJson
    try {
        msg := Jxon_Load(jsonStr)
    } catch {
        OutputDebug("[PQP] JSON parse error: " . jsonStr)
        return
    }
    if (msg is String) {
        try msg := Jxon_Load(msg)
        catch {
            OutputDebug("[PQP] nested JSON parse error: " . msg)
            return
        }
    }
    if !(msg is Map)
        return
    action := msg.Has("type") ? msg["type"] : (msg.Has("action") ? msg["action"] : "")
    if (action = "")
        return

    switch action {
        case "ready":
            global g_PQP_Ready
            g_PQP_Ready := true
            _PQP_PushTheme()
            _PQP_SendDockConfig()
            if PQP_IsVisible()
                _PQP_CallExternal("PromptQuickPad_PushDataToWeb", "init")
            if g_PQP_FocusPending
                PQP_RequestFocusInput()
        case "nmDockReady":
            _PQP_SendDockConfig()
        case "nmDockLeave":
            ; lifecycle handled by PQP_Show/PQP_Hide
        case "nmDockCmd":
            _PQP_ExecuteDockCmd(msg)

        case "search":
            keyword := msg.Has("keyword") ? msg["keyword"] : ""
            category := msg.Has("category") ? msg["category"] : "全部"
            _PQP_DebouncedSearch(keyword, category)

        default:
            _PQP_CallExternal("PromptQuickPad_ProcessWebMessage", msg)
    }
}

; ===================== 防抖搜索 =====================
_PQP_SendDockConfig() {
    arr := []
    try {
        if IsSet(_LoadCommands)
            _LoadCommands()
        global g_Commands
        if (g_Commands is Map && g_Commands.Has("SceneToolbarLayout") && g_Commands["SceneToolbarLayout"] is Array) {
            for row in g_Commands["SceneToolbarLayout"] {
                if !(row is Map) || !row.Has("sceneId")
                    continue
                sid := Trim(String(row["sceneId"]))
                if (sid = "")
                    continue
                arr.Push(Map(
                    "sceneId", sid,
                    "visible_in_bar", row.Has("visible_in_bar") ? (row["visible_in_bar"] ? true : false) : true,
                    "order_bar", row.Has("order_bar") ? Integer(row["order_bar"]) : -1
                ))
            }
        }
    } catch {
    }
    PQP_SendToWeb(Map("type", "nmDockConfig", "sceneToolbarLayout", arr))
}

_PQP_ExecuteDockCmd(msg) {
    cmdId0 := msg.Has("cmdId") ? String(msg["cmdId"]) : ""
    if (cmdId0 = "")
        return
    if (cmdId0 = "open_cloudplayer") {
        try ShowCloudPlayer()
        return
    }
    m0 := Map(
        "Title", "dock",
        "Content", "",
        "DataType", "text",
        "OriginalDataType", "text",
        "Source", "dock",
        "ClipboardId", 0,
        "PromptMergedIndex", 0,
        "HubSegIndex", -1
    )
    try SC_ExecuteContextCommand(cmdId0, 0, m0)
    catch as err {
        OutputDebug("[PQP] nmDockCmd: " . err.Message)
    }
}

_PQP_DebouncedSearch(keyword, category := "全部") {
    global g_PQP_SearchTimer, g_PQP_LastKeyword, g_PQP_LastCategory
    g_PQP_LastKeyword := keyword
    g_PQP_LastCategory := category

    if g_PQP_SearchTimer {
        SetTimer(g_PQP_SearchTimer, 0)
        g_PQP_SearchTimer := 0
    }

    fn := _PQP_ExecuteSearch.Bind()
    g_PQP_SearchTimer := fn
    SetTimer(fn, -150)
}

_PQP_ExecuteSearch(*) {
    global g_PQP_SearchTimer, g_PQP_LastKeyword, g_PQP_LastCategory
    global PromptQuickPad_WebSearchKeyword, PromptQuickPadSelectedCategory
    g_PQP_SearchTimer := 0
    PromptQuickPad_WebSearchKeyword := g_PQP_LastKeyword
    PromptQuickPadSelectedCategory := g_PQP_LastCategory
    _PQP_CallExternal("PromptQuickPad_PushDataToWeb", "searchResult")
}

; ===================== 显示 / 隐藏 =====================
PQP_Show() {
    global g_PQP_Gui, g_PQP_Visible, g_PQP_Ready, g_PQP_Ctrl, g_PQP_LastShown
    global AIListPanelWindowX, AIListPanelWindowY, AIListPanelWindowW, AIListPanelWindowH
    try FloatingToolbar_PageDockEnter("prompts")

    if !g_PQP_Gui
        PQP_Init()

    if g_PQP_Visible {
        try WinActivate(g_PQP_Gui.Hwnd)
        WebView2_MoveFocusProgrammatic(g_PQP_Ctrl)
        SetTimer(_PQP_DeferredMoveFocus100, -100)
        return
    }

    panelX := AIListPanelWindowX
    panelY := AIListPanelWindowY
    panelW := AIListPanelWindowW > 0 ? AIListPanelWindowW : 560
    panelH := AIListPanelWindowH > 0 ? AIListPanelWindowH : 620
    if panelX = 0 && panelY = 0 {
        ScreenW := SysGet(0)
        ScreenH := SysGet(1)
        panelX := (ScreenW - panelW) // 2
        panelY := (ScreenH - panelH) // 2
    }

    try g_PQP_Gui.Show("x" . panelX . " y" . panelY . " w" . panelW . " h" . panelH . " NoActivate")
    g_PQP_Visible := true
    g_PQP_LastShown := A_TickCount
    try WebView2_NotifyShown(g_PQP_WV2)
    WMActivateChain_Register(_PQP_WM_ACTIVATE)

    _PQP_RefreshWebViewComposition()
    SetTimer(_PQP_RefreshWebViewComposition, -120)
    SetTimer(_PQP_RefreshWebViewComposition, -380)

    if g_PQP_Ready
        _PQP_PushTheme()
    if g_PQP_Ready
        _PQP_CallExternal("PromptQuickPad_PushDataToWeb", "init")
    else
        SetTimer(_PQP_DeferredShowPush, -400)

    WebView2_MoveFocusProgrammatic(g_PQP_Ctrl)
    SetTimer(_PQP_DeferredMoveFocus100, -100)
    SetTimer(_PQP_FocusDeferred, -80)
    PQP_RequestFocusInput()
}

_PQP_DeferredMoveFocus100(*) {
    global g_PQP_Gui, g_PQP_Visible, g_PQP_Ctrl
    if g_PQP_Visible && g_PQP_Gui
        WebView2_MoveFocusProgrammatic(g_PQP_Ctrl)
}

global _PQP_ShowPushRetries := 0
_PQP_DeferredShowPush(*) {
    global g_PQP_Ready, g_PQP_Visible, _PQP_ShowPushRetries
    if !g_PQP_Visible
        return
    if g_PQP_Ready {
        _PQP_ShowPushRetries := 0
        _PQP_CallExternal("PromptQuickPad_PushDataToWeb", "init")
    } else {
        _PQP_ShowPushRetries++
        if _PQP_ShowPushRetries < 8
            SetTimer(_PQP_DeferredShowPush, -500)
    }
}

_PQP_FocusDeferred(*) {
    global g_PQP_Gui, g_PQP_Visible, g_PQP_Ctrl
    if g_PQP_Visible && g_PQP_Gui {
        try WinActivate(g_PQP_Gui.Hwnd)
        WebView2_MoveFocusProgrammatic(g_PQP_Ctrl)
    }
}

; WM_ACTIVATE 延迟关闭（命名定时器，PQP_Hide 内取消，避免与工具栏二次点击竞态）
_PQP_WMDeactivateHideTick(*) {
    global g_PQP_Gui, g_PQP_Visible
    if !g_PQP_Visible || !g_PQP_Gui
        return
    try {
        if (FloatingToolbar_IsForegroundToolbarOrChild())
            return
    } catch {
    }
    PQP_Hide()
}

PQP_Hide() {
    global g_PQP_Gui, g_PQP_Visible, g_PQP_SearchTimer
    try FloatingToolbar_PageDockLeave("prompts")

    SetTimer(_PQP_WMDeactivateHideTick, 0)
    SetTimer(_PQP_RefreshWebViewComposition, 0)
    SetTimer(_PQP_DeferredMoveFocus100, 0)
    SetTimer(_PQP_FocusDeferred, 0)
    SetTimer(_PQP_DeferredShowPush, 0)

    if g_PQP_SearchTimer {
        SetTimer(g_PQP_SearchTimer, 0)
        g_PQP_SearchTimer := 0
    }

    g_PQP_Visible := false
    WMActivateChain_Unregister(_PQP_WM_ACTIVATE)
    try WebView2_NotifyHidden(g_PQP_WV2)
    if g_PQP_Gui {
        try g_PQP_Gui.Hide()
    }
}

PQP_RequestFocusInput() {
    global g_PQP_WV2, g_PQP_Ready, g_PQP_FocusPending
    if g_PQP_WV2 && g_PQP_Ready {
        WebView_QueueJson(g_PQP_WV2, '{"type":"focus_input"}')
        g_PQP_FocusPending := false
        return
    }
    g_PQP_FocusPending := true
}

_PQP_WM_ACTIVATE(wParam, lParam, msg, hwnd) {
    global g_PQP_Gui, g_PQP_Visible, g_PQP_LastShown
    if !g_PQP_Visible || !g_PQP_Gui
        return
    if (hwnd = g_PQP_Gui.Hwnd && (wParam & 0xFFFF) = 0) {
        try {
            if (FloatingToolbar_IsForegroundToolbarOrChild())
                return
        } catch {
        }
        if (g_PQP_LastShown && (A_TickCount - g_PQP_LastShown < 500))
            return
        SetTimer(_PQP_WMDeactivateHideTick, -50)
    }
}

PQP_ApplyPinTopFromIni() {
    global g_PQP_Gui, PromptQuickPad_PinTop
    if !g_PQP_Gui
        return
    try g_PQP_Gui.Opt(PromptQuickPad_PinTop ? "+AlwaysOnTop" : "-AlwaysOnTop")
}
