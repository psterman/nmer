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
global g_PQP_SearchTimer := 0
global g_PQP_LastKeyword := ""
global g_PQP_LastCategory := "全部"

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
    WV2.create(g_PQP_Gui.Hwnd, _PQP_OnWV2Created)
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
    s.IsStatusBarEnabled := false
    s.AreDevToolsEnabled := false

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
PQP_SendToWeb(jsonStr) {
    global g_PQP_WV2, g_PQP_Ready
    if g_PQP_WV2 && g_PQP_Ready
        g_PQP_WV2.PostWebMessageAsJson(jsonStr)
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
    if !(msg is Map) || !msg.Has("type")
        return

    switch msg["type"] {
        case "ready":
            global g_PQP_Ready
            g_PQP_Ready := true
            if PQP_IsVisible()
                _PQP_CallExternal("PromptQuickPad_PushDataToWeb", "init")

        case "search":
            keyword := msg.Has("keyword") ? msg["keyword"] : ""
            category := msg.Has("category") ? msg["category"] : "全部"
            _PQP_DebouncedSearch(keyword, category)

        default:
            _PQP_CallExternal("PromptQuickPad_ProcessWebMessage", msg)
    }
}

; ===================== 防抖搜索 =====================
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
    global g_PQP_Gui, g_PQP_Visible, g_PQP_Ready
    global AIListPanelWindowX, AIListPanelWindowY, AIListPanelWindowW, AIListPanelWindowH

    if !g_PQP_Gui
        PQP_Init()

    if g_PQP_Visible {
        try WinActivate(g_PQP_Gui.Hwnd)
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
    OnMessage(0x0006, _PQP_WM_ACTIVATE)

    _PQP_RefreshWebViewComposition()
    SetTimer(_PQP_RefreshWebViewComposition, -120)
    SetTimer(_PQP_RefreshWebViewComposition, -380)

    if g_PQP_Ready
        _PQP_CallExternal("PromptQuickPad_PushDataToWeb", "init")
    else
        SetTimer(_PQP_DeferredShowPush, -400)

    SetTimer(_PQP_FocusDeferred, -80)
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
    global g_PQP_Gui, g_PQP_Visible
    if g_PQP_Visible && g_PQP_Gui {
        try WinActivate(g_PQP_Gui.Hwnd)
    }
}

PQP_Hide() {
    global g_PQP_Gui, g_PQP_Visible, g_PQP_SearchTimer

    if g_PQP_SearchTimer {
        SetTimer(g_PQP_SearchTimer, 0)
        g_PQP_SearchTimer := 0
    }

    g_PQP_Visible := false
    OnMessage(0x0006, _PQP_WM_ACTIVATE, 0)
    if g_PQP_Gui {
        try g_PQP_Gui.Hide()
    }
}

_PQP_WM_ACTIVATE(wParam, lParam, msg, hwnd) {
    global g_PQP_Gui, g_PQP_Visible
    if !g_PQP_Visible || !g_PQP_Gui
        return
    if (hwnd = g_PQP_Gui.Hwnd && (wParam & 0xFFFF) = 0)
        SetTimer(PQP_Hide, -50)
}

PQP_ApplyPinTopFromIni() {
    global g_PQP_Gui, PromptQuickPad_PinTop
    if !g_PQP_Gui
        return
    try g_PQP_Gui.Opt(PromptQuickPad_PinTop ? "+AlwaysOnTop" : "-AlwaysOnTop")
}
