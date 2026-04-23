; ======================================================================================================================
; 鎮诞宸ュ叿鏍?- WebView2 鍏ㄩ噺閲嶆瀯鐗?; 鐗堟湰: 2.0.0
; 鍔熻兘:
;   - 鏁存潯宸ュ叿鏍忕敱鍗曚釜 WebView2 娓叉煋锛岀粺涓€璧涘崥缁?姗欓厤鑹?;   - 宸﹂敭鎷栧姩鏁寸獥銆佹粴杞缉鏀俱€佸彸閿彍鍗?;   - 7 涓姛鑳芥寜閽細鎼滅储銆佽褰曘€佹彁绀鸿瘝銆佹柊鎻愮ず璇嶃€佹埅鍥俱€佽缃€侀敭鐩?;   - 鎼滅储鎸夐挳鏀寔閫夊尯鎰熷簲鍛煎惛鍔ㄧ敾鍜屾嫋鏀炬悳绱?; ======================================================================================================================

#Requires AutoHotkey v2.0

; 澶氭樉绀哄櫒铏氭嫙妗岄潰鍖呭洿鐩掞紙SM_XVIRTUALSCREEN 76鈥?9锛?
ScreenVirtual_GetBounds(&outL, &outT, &outW, &outH) {
    outL := SysGet(76)
    outT := SysGet(77)
    outW := SysGet(78)
    outH := SysGet(79)
}

; ===================== 鍏ㄥ眬鍙橀噺 =====================
global FloatingToolbarGUI := 0
global FloatingToolbarIsVisible := false
global FloatingToolbarWindowX := 0
global FloatingToolbarWindowY := 0
global FloatingToolbarScale := 1.0
global FloatingToolbarMinScale := 0.7
global FloatingToolbarMaxScale := 1.5
global FloatingToolbarCompactDiameter := 52
global FloatingToolbarDragging := false
global FloatingToolbar_DragOriginScreenX := 0
global FloatingToolbar_DragOriginScreenY := 0
global FloatingToolbar_DragOriginWinX := 0
global FloatingToolbar_DragOriginWinY := 0
global FloatingToolbarIsMinimized := false
global FloatingToolbarChatDrawerOpen := false
global FloatingToolbarChatDrawerWidth := 620
global FloatingToolbarChatDrawerHeight := 720
global FloatingToolbarCmdVisibleCount := 7
global FloatingToolbarLastClosedX := 0
global FloatingToolbarLastClosedY := 0
global g_FTB_BlockedCmdIds := Map("ch_t", true, "pqp_capture", true, "ss_menu", true)
global g_FTB_AllowedCmdIds := Map(
    "sc_activate_search", true,
    "qa_clipboard", true,
    "ch_b", true,
    "ftb_scratchpad", true,
    "ftb_screenshot", true,
    "qa_config", true,
    "sys_show_vk", true,
    "ftb_cursor_menu", true
)

global g_FTB_WV2_Ctrl := 0
global g_FTB_WV2 := 0
global g_FTB_WV2_Ready := false
global g_FTB_WV2_FrameReady := false
global g_FTB_PendingSelection := ""
global g_FTB_PendingNiumaCompose := []
global g_FTB_UI_Ready := false
global g_FTB_WaitingUiFinishedReveal := false
global g_FTB_ScreenshotDeferLastTick := 0  ; 防抖：WebView 短时双发 postMessage 会排队两次 Deferred，避免第二次再跑完整截图助手流程
global g_FTB_WV2_CreateRetry := 0
global g_FTB_DebugOverlayEnabled := true

FTB_Debug(msg, level := "ok") {
    global g_FTB_DebugOverlayEnabled, g_FTB_WV2
    if !g_FTB_DebugOverlayEnabled
        return
    try OutputDebug("[FTBDBG] " . msg)
    catch {
    }
    if !g_FTB_WV2
        return
    try WebView_QueuePayload(g_FTB_WV2, Map("type", "ftb_debug", "msg", String(msg), "level", level, "tick", A_TickCount))
    catch {
    }
}

; ===================== 鏄剧ず/闅愯棌鎮诞绐?=====================
; 首次/重建 WebView 后：先全透明占位，等页面 post UI_FINISHED 再不透明显示，避免未渲染完就露出黑白底。
; 隐藏后再打开且 WebView 仍在：直接显示，不再等待。
FloatingToolbar_FinishReveal() {
    global FloatingToolbarGUI, FloatingToolbarIsVisible, FloatingToolbarWindowX, FloatingToolbarWindowY
    global g_FTB_WaitingUiFinishedReveal, g_FTB_WV2

    if !FloatingToolbarGUI
        return

    g_FTB_WaitingUiFinishedReveal := false
    SetTimer(FloatingToolbar_ForceRevealIfStuck, 0)

    tw := FloatingToolbarCalculateWidth()
    th := FloatingToolbarCalculateHeight()
    try FloatingToolbarGUI.Move(FloatingToolbarWindowX, FloatingToolbarWindowY, tw, th)
    catch {
    }
    try WinSetTransparent(255, "ahk_id " . FloatingToolbarGUI.Hwnd)
    catch {
    }
    try FloatingToolbarGUI.Show("x" . FloatingToolbarWindowX . " y" . FloatingToolbarWindowY . " w" . tw . " h" . th . " NoActivate")
    catch {
    }

    FloatingToolbarIsVisible := true
    try WebView2_NotifyShown(g_FTB_WV2)
    FloatingToolbarApplyRoundedCorners()
    FloatingToolbar_ApplyWebViewBounds()
    SetTimer(FloatingToolbarCheckWindowPosition, 100)
}

FloatingToolbar_ForceRevealIfStuck() {
    global g_FTB_WaitingUiFinishedReveal
    if !g_FTB_WaitingUiFinishedReveal
        return
    OutputDebug("[FTB] UI_FINISHED timeout: force reveal")
    FloatingToolbar_FinishReveal()
}

ShowFloatingToolbar() {
    global FloatingToolbarGUI, FloatingToolbarIsVisible, FloatingToolbarWindowX, FloatingToolbarWindowY
    global g_FTB_UI_Ready, g_FTB_WaitingUiFinishedReveal, g_FTB_WV2_Ready

    if (FloatingToolbarIsVisible && FloatingToolbarGUI != 0) {
        return
    }
    ; 若上次仍在「等 UI_FINISHED」，先取消超时定时器，避免重复 reveal
    if (FloatingToolbarGUI != 0 && g_FTB_WaitingUiFinishedReveal) {
        g_FTB_WaitingUiFinishedReveal := false
        SetTimer(FloatingToolbar_ForceRevealIfStuck, 0)
    }

    FloatingToolbarLoadScale()

    if (FloatingToolbarGUI = 0) {
        CreateFloatingToolbarGUI()
    }

    LoadFloatingToolbarPosition()

    if (FloatingToolbarWindowX = 0 && FloatingToolbarWindowY = 0) {
        ScreenVirtual_GetBounds(&vl, &vt, &vw, &vh)
        ToolbarWidth := FloatingToolbarCalculateWidth()
        ToolbarHeight := FloatingToolbarCalculateHeight()
        FloatingToolbarWindowX := vl + vw - ToolbarWidth
        FloatingToolbarWindowY := vt + vh - ToolbarHeight
    }

    ToolbarWidth := FloatingToolbarCalculateWidth()
    ToolbarHeight := FloatingToolbarCalculateHeight()

    FloatingToolbarGUI.Show("x" . FloatingToolbarWindowX . " y" . FloatingToolbarWindowY . " w" . ToolbarWidth . " h" . ToolbarHeight . " NoActivate")

    ; WebView 已就绪且页面至少完成过一次 UI_FINISHED：直接显示（避免隐藏后再开仍等一帧）
    if (g_FTB_WV2_Ready && g_FTB_UI_Ready) {
        try WinSetTransparent(255, "ahk_id " . FloatingToolbarGUI.Hwnd)
        catch {
        }
        FloatingToolbar_FinishReveal()
        return
    }

    ; 首次加载或重建：全透明直到 HTML 发 UI_FINISHED（去掉 AnimateWindow 淡入，避免黑白闪动）
    try WinSetTransparent(0, "ahk_id " . FloatingToolbarGUI.Hwnd)
    catch {
    }
    g_FTB_WaitingUiFinishedReveal := true
    FloatingToolbarIsVisible := false
    FloatingToolbarApplyRoundedCorners()
    FloatingToolbar_ApplyWebViewBounds()
    SetTimer(FloatingToolbar_ForceRevealIfStuck, 0)
    SetTimer(FloatingToolbar_ForceRevealIfStuck, -4500)
}

HideFloatingToolbar() {
    global FloatingToolbarGUI, FloatingToolbarIsVisible, g_FTB_WaitingUiFinishedReveal, g_FTB_WV2

    if (FloatingToolbarGUI != 0) {
        SaveFloatingToolbarPosition()
        g_FTB_WaitingUiFinishedReveal := false
        SetTimer(FloatingToolbar_ForceRevealIfStuck, 0)
        try WinSetTransparent(255, "ahk_id " . FloatingToolbarGUI.Hwnd)
        catch {
        }
        try WebView2_NotifyHidden(g_FTB_WV2)
        try FloatingToolbarGUI.Hide()
        FloatingToolbarIsVisible := false
        SetTimer(FloatingToolbarCheckWindowPosition, 0)
    }
}

ToggleFloatingToolbar() {
    global FloatingToolbarIsVisible, AppearanceActivationMode, FloatingBubbleIsVisible

    mode := NormalizeAppearanceActivationMode(AppearanceActivationMode)
    if (mode = "bubble") {
        if (FloatingBubbleIsVisible) {
            HideFloatingBubble()
        } else {
            ShowFloatingBubble()
        }
        return
    }
    if (mode = "tray") {
        return
    }

    if (FloatingToolbarIsVisible) {
        HideFloatingToolbar()
    } else {
        ShowFloatingToolbar()
    }
}

; ===================== 鍒涘缓GUI =====================
CreateFloatingToolbarGUI() {
    global FloatingToolbarGUI, g_FTB_WV2_Ctrl, g_FTB_WV2, g_FTB_WV2_Ready, g_FTB_PendingSelection
    global g_FTB_UI_Ready, g_FTB_WaitingUiFinishedReveal, g_FTB_WV2_CreateRetry
    global WebView2
    g_FTB_WV2_CreateRetry := 0

    if (FloatingToolbarGUI != 0) {
        g_FTB_WV2_Ctrl := 0
        g_FTB_WV2 := 0
        g_FTB_WV2_Ready := false
        g_FTB_WV2_FrameReady := false
        g_FTB_PendingSelection := ""
        g_FTB_UI_Ready := false
        g_FTB_WaitingUiFinishedReveal := false
        g_FTB_WV2_CreateRetry := 0
        try FloatingToolbarGUI.Destroy()
        catch as _e {
        }
    }

    FloatingToolbarGUI := Gui("+AlwaysOnTop -Caption +ToolWindow -DPIScale +E0x02000000", "Floating Toolbar")
    ; 与 FloatingToolbarStrip 工具栏底色 #0a0a0a 一致，避免圆角外缘露色
    FloatingToolbarGUI.BackColor := "0a0a0a"
    FloatingToolbarGUI.OnEvent("Close", OnFloatingToolbarClose)
    FloatingToolbarGUI.OnEvent("ContextMenu", OnFloatingToolbarContextMenu)

    OnMessage(0x020A, FloatingToolbarWM_MOUSEWHEEL)

    WebView2.create(FloatingToolbarGUI.Hwnd, FloatingToolbar_OnWebViewCreated, WebView2_EnsureSharedEnvBlocking())
}

FloatingToolbar_FlushPendingSelectionIfReady() {
    global g_FTB_WV2, g_FTB_WV2_Ready, g_FTB_WV2_FrameReady, g_FTB_PendingSelection
    if !(g_FTB_WV2 && g_FTB_WV2_Ready && g_FTB_WV2_FrameReady)
        return
    if (g_FTB_PendingSelection = "")
        return
    pv := SubStr(String(g_FTB_PendingSelection), 1, 220)
    try WebView_QueuePayload(g_FTB_WV2, Map("type", "SELECTION_CHANGE", "preview", pv))
    catch as _e {
        return
    }
    g_FTB_PendingSelection := ""
}

FloatingToolbar_FlushPendingNiumaComposeIfReady() {
    global g_FTB_WV2, g_FTB_WV2_Ready, g_FTB_WV2_FrameReady, g_FTB_PendingNiumaCompose
    if !(g_FTB_WV2 && g_FTB_WV2_Ready && g_FTB_WV2_FrameReady)
        return
    if !(g_FTB_PendingNiumaCompose is Array) || (g_FTB_PendingNiumaCompose.Length = 0)
        return
    try {
        for _, payload in g_FTB_PendingNiumaCompose {
            WebView_QueuePayload(g_FTB_WV2, payload)
        }
        g_FTB_PendingNiumaCompose := []
    } catch as _e {
    }
}

FloatingToolbar_OnNavigationStarting(sender, args) {
    global g_FTB_WV2_FrameReady
    g_FTB_WV2_FrameReady := false
}

FloatingToolbar_OnNavigationCompleted(sender, args) {
    global g_FTB_WV2_FrameReady
    ok := false
    try ok := args.IsSuccess
    catch as _e {
        ok := false
    }
    g_FTB_WV2_FrameReady := !!ok
    FloatingToolbar_FlushPendingSelectionIfReady()
    FloatingToolbar_FlushPendingNiumaComposeIfReady()
}

; ===================== 鍦嗚杈规澶勭悊 =====================
; 不再使用 GDI CreateRoundRectRgn 裁剪宿主窗口：整数像素圆角易产生锯齿，
; 圆角与描边由 WebView 内 SVG/CSS 抗锯齿绘制；宿主保持矩形窗口，BackColor 与工具栏底同色即可。
FloatingToolbarApplyRoundedCorners() {
    global FloatingToolbarGUI

    if (FloatingToolbarGUI = 0) {
        return
    }

    try DllCall("SetWindowRgn", "Ptr", FloatingToolbarGUI.Hwnd, "Ptr", 0, "Int", 1)
    catch {
    }
}

; ===================== WebView2 鍥炶皟 =====================
FloatingToolbar_OnWebViewCreated(ctrl) {
    global g_FTB_WV2_Ctrl, g_FTB_WV2, g_FTB_WV2_Ready, g_FTB_WV2_FrameReady, g_FTB_WV2_CreateRetry

    if !IsObject(ctrl) || !ctrl.HasProp("CoreWebView2") {
        OutputDebug("[FTB] WebView2 create failed: invalid controller")
        FloatingToolbar_RetryCreateWebView()
        return
    }
    g_FTB_WV2_CreateRetry := 0
    g_FTB_WV2_Ctrl := ctrl
    g_FTB_WV2 := ctrl.CoreWebView2
    g_FTB_WV2_Ready := false
    g_FTB_WV2_FrameReady := false

    ; 与工具栏底色 #0a0a0a 一致，避免透明时透出异色再闪内容
    try ctrl.DefaultBackgroundColor := 0xFF0A0A0A
    try ctrl.IsVisible := true

    FloatingToolbar_ApplyWebViewBounds()

    s := g_FTB_WV2.Settings
    s.AreDefaultContextMenusEnabled := false
    s.AreDevToolsEnabled := false
    ; 避免 Ctrl+1/2/W 等被浏览器加速键先消费，确保 Niuma Chat 内部快捷键优先生效
    try s.AreBrowserAcceleratorKeysEnabled := false
    ApplyWebView2PerformanceSettings(g_FTB_WV2)
    WebView2_RegisterHostBridge(g_FTB_WV2)

    g_FTB_WV2.add_NavigationStarting(FloatingToolbar_OnNavigationStarting)
    g_FTB_WV2.add_NavigationCompleted(FloatingToolbar_OnNavigationCompleted)
    g_FTB_WV2.add_WebMessageReceived(FloatingToolbar_OnWebMessage)
    try ApplyUnifiedWebViewAssets(g_FTB_WV2)
    g_FTB_WV2.Navigate(BuildAppLocalUrl("FloatingToolbarStrip.html"))
}

FloatingToolbar_ApplyWebViewBounds() {
    global FloatingToolbarGUI, g_FTB_WV2_Ctrl

    if !(FloatingToolbarGUI && g_FTB_WV2_Ctrl)
        return

    WinGetClientPos(, , &cw, &ch, FloatingToolbarGUI.Hwnd)
    rc := WebView2.RECT()
    rc.left := 0
    rc.top := 0
    rc.right := cw
    rc.bottom := ch
    try {
        g_FTB_WV2_Ctrl.Bounds := rc
        g_FTB_WV2_Ctrl.NotifyParentWindowPositionChanged()
    } catch {
    }
}

FloatingToolbar_RetryCreateWebView() {
    global FloatingToolbarGUI, g_FTB_WV2_CreateRetry
    if !FloatingToolbarGUI
        return
    if (g_FTB_WV2_CreateRetry >= 3)
        return
    g_FTB_WV2_CreateRetry += 1
    SetTimer((*) => WebView2.create(FloatingToolbarGUI.Hwnd, FloatingToolbar_OnWebViewCreated, WebView2_EnsureSharedEnvBlocking()), -200)
}

FloatingToolbar_GetLogoAppUrl() {
    if !IsSet(BuildAppLocalUrl)
        return ""
    candidates := [
        "牛马.png",
        "logo.png",
        "images\logo.png",
        "images\nimabu.png",
        "favicon.ico"
    ]
    for rel in candidates {
        full := A_ScriptDir . "\" . rel
        if FileExist(full) {
            u := StrReplace(rel, "\", "/")
            try return BuildAppLocalUrl(u)
            catch {
                return ""
            }
        }
    }
    return ""
}

FloatingToolbar_PushLogoToWeb(*) {
    global g_FTB_WV2
    if !g_FTB_WV2
        return
    url := FloatingToolbar_GetLogoAppUrl()
    if (url = "")
        return
    try WebView_QueuePayload(g_FTB_WV2, Map("type", "set_logo", "url", url))
    catch as _e {
    }
}

FloatingToolbar_PushThemeToWeb(*) {
    global g_FTB_WV2
    if !g_FTB_WV2
        return
    tm := FloatingToolbar_GetThemeMode()
    try WebView_QueuePayload(g_FTB_WV2, Map("type", "set_theme", "themeMode", tm))
    catch as _e {
    }
}

FloatingToolbar_NormalizeThemeToken(raw, fallback := "dark") {
    s := StrLower(Trim(String(raw)))
    if (s = "light" || s = "lite")
        return "light"
    if (s = "dark")
        return "dark"
    return (fallback = "light") ? "light" : "dark"
}

FloatingToolbar_GetThemeMode() {
    ; Prefer direct INI read so theme stays correct even if global state is stale.
    try {
        global ConfigFile
        if (IsSet(ConfigFile) && ConfigFile != "") {
            raw := IniRead(ConfigFile, "Settings", "ThemeMode", "")
            if (Trim(String(raw)) = "")
                raw := IniRead(ConfigFile, "Appearance", "ThemeMode", "")
            if (Trim(String(raw)) != "")
                return FloatingToolbar_NormalizeThemeToken(raw, "dark")
        }
    } catch {
    }
    try {
        fn := Func("ReadPersistedThemeMode")
        if IsObject(fn)
            return FloatingToolbar_NormalizeThemeToken(fn.Call(), "dark")
    } catch {
    }
    try {
        global ThemeMode
        return FloatingToolbar_NormalizeThemeToken(ThemeMode, "dark")
    } catch {
    }
    return "dark"
}

FloatingToolbar_OnWebMessage(sender, args) {
    global g_FTB_WV2, g_FTB_WV2_Ready, g_FTB_WV2_FrameReady, g_FTB_PendingSelection, FloatingToolbarGUI, FloatingToolbarScale

    msg := FloatingToolbar_ParseWebMessage(args)
    if !(msg is Map)
        return

    typ := msg.Has("type") ? String(msg["type"]) : ""
    if (typ != "")
        FTB_Debug("recv " . typ)

    if (typ = "toolbar_ready") {
        g_FTB_WV2_Ready := true
        FloatingToolbar_ApplyWebViewBounds()
        SetTimer(FloatingToolbar_PushLogoToWeb, -10)
        SetTimer(FloatingToolbar_PushThemeToWeb, -10)
        FloatingToolbarPushScaleStateToWeb(FloatingToolbarScale)
        FloatingToolbarPushButtonConfigToWeb()
        FloatingToolbar_FlushPendingSelectionIfReady()
        FloatingToolbar_FlushPendingNiumaComposeIfReady()
        return
    }

    if (typ = "UI_FINISHED") {
        global FloatingToolbarIsVisible, FloatingToolbarWindowX, FloatingToolbarWindowY
        global g_FTB_UI_Ready, g_FTB_WaitingUiFinishedReveal

        if !FloatingToolbarGUI
            return

        g_FTB_UI_Ready := true

        if !g_FTB_WaitingUiFinishedReveal
            return

        ; 不再使用 AnimateWindow(AW_BLEND)，避免黑白渐变闪屏；由 FloatingToolbar_FinishReveal 一次性不透明显示
        FloatingToolbar_FinishReveal()
        FloatingToolbar_FlushPendingNiumaComposeIfReady()
        return
    }

    if (typ = "toolbar_action") {
        action := msg.Has("action") ? String(msg["action"]) : ""
        if (action != "")
            FloatingToolbarExecuteButtonAction(action, 0)
        return
    }

    if (typ = "toolbar_cmd") {
        cid := msg.Has("cmdId") ? Trim(String(msg["cmdId"])) : ""
        if (cid != "")
            SetTimer(FloatingToolbar_DeferredToolbarCmd.Bind(cid), -1)
        return
    }

    if (typ = "toolbar_toggle_action") {
        action := msg.Has("action") ? String(msg["action"]) : ""
        FTB_Debug("toggle " . action)
        if (action != "")
            FloatingToolbarToggleButtonAction(action)
        return
    }

    if (typ = "toolbar_search_click") {
        FloatingToolbar_ActivateSearchCenter()
        return
    }

    if (typ = "drop_search") {
        t := msg.Has("text") ? Trim(String(msg["text"])) : ""
        if (t != "") {
            try SearchCenter_RunQueryWithKeyword(t)
            catch {
            }
        }
        if g_FTB_WV2 {
            try {
                WebView_QueuePayload(g_FTB_WV2, Map("type", "drop_done"))
                WebView_QueuePayload(g_FTB_WV2, Map("type", "SELECTION_CLEAR"))
            } catch {
            }
        }
        return
    }

    if (typ = "drop_action") {
        action := msg.Has("action") ? Trim(String(msg["action"])) : "Search"
        t := msg.Has("text") ? Trim(String(msg["text"])) : ""
        if (t != "") {
            try {
                switch action {
                    case "Search":
                        SearchCenter_RunQueryWithKeyword(t)
                    case "Prompt", "NewPrompt", "Record":
                        PromptQuickPad_OpenCaptureDraft(t, true)
                    default:
                        ; 未定义输入面板的图标统一回退到搜索中心
                        SearchCenter_RunQueryWithKeyword(t)
                }
            } catch {
            }
        }
        if g_FTB_WV2 {
            try {
                WebView_QueuePayload(g_FTB_WV2, Map("type", "drop_done"))
                WebView_QueuePayload(g_FTB_WV2, Map("type", "SELECTION_CLEAR"))
            } catch {
            }
        }
        return
    }

    if (typ = "drag_host") {
        global FloatingToolbarGUI, FloatingToolbarDragging
        global FloatingToolbar_DragOriginScreenX, FloatingToolbar_DragOriginScreenY
        global FloatingToolbar_DragOriginWinX, FloatingToolbar_DragOriginWinY
        if !FloatingToolbarGUI || FloatingToolbarDragging
            return
        try FloatingToolbarGUI.GetPos(&FloatingToolbar_DragOriginWinX, &FloatingToolbar_DragOriginWinY)
        catch as _e {
            return
        }
        CoordMode("Mouse", "Screen")
        MouseGetPos(&FloatingToolbar_DragOriginScreenX, &FloatingToolbar_DragOriginScreenY)
        FloatingToolbarDragging := true
        SetTimer(FloatingToolbar_DragRun, -1)
        return
    }

    if (typ = "wheel") {
        delta := msg.Has("delta") ? Integer(msg["delta"]) : 0
        if (delta != 0)
            FloatingToolbarApplyWheelDelta(delta)
        return
    }

    if (typ = "exit_compact") {
        FloatingToolbarExitCompactMode()
        return
    }

    if (typ = "context_menu") {
        x := msg.Has("x") ? Integer(msg["x"]) : 0
        y := msg.Has("y") ? Integer(msg["y"]) : 0
        FTB_Debug("context_menu x=" . x . " y=" . y)
        SetTimer(FloatingToolbar_ShowContextMenuDeferred.Bind(x, y), -1)
        return
    }

    if (typ = "toolbar_cmd_context") {
        cid := msg.Has("cmdId") ? Trim(String(msg["cmdId"])) : ""
        if (cid = "ftb_cursor_menu") {
            try FloatingToolbar_ShowCursorQuickMenu()
            catch {
            }
            return
        }
        x := msg.Has("x") ? Integer(msg["x"]) : 0
        y := msg.Has("y") ? Integer(msg["y"]) : 0
        FTB_Debug("toolbar_cmd_context x=" . x . " y=" . y)
        SetTimer(FloatingToolbar_ShowContextMenuDeferred.Bind(x, y), -1)
        return
    }

    if (typ = "drawer_state") {
        open := msg.Has("open") && !!msg["open"]
        FTB_Debug("drawer_state open=" . open)
        FloatingToolbarSetChatDrawerState(open)
        return
    }

    if (typ = "drawer_resize") {
        w := msg.Has("width") ? Integer(msg["width"]) : 0
        if (w > 0)
            FloatingToolbar_ApplyDrawerClientWidth(w)
        return
    }

    if (typ = "drawer_resize_done") {
        FloatingToolbarSaveDrawerWidth()
        SaveFloatingToolbarPosition()
        return
    }
}

; 按 WebView 客户区 CSS 像素宽度调整抽屉（保持窗口右缘不动）
FloatingToolbar_ApplyDrawerClientWidth(clientW) {
    global FloatingToolbarGUI, FloatingToolbarChatDrawerOpen, FloatingToolbarChatDrawerWidth
    global FloatingToolbarScale, FloatingToolbarWindowX, FloatingToolbarWindowY

    if (!FloatingToolbarGUI || !FloatingToolbarChatDrawerOpen)
        return
    sc := FloatingToolbarScale
    if (sc < 0.01)
        sc := 1.0
    logical := Round(clientW / sc)
    if (logical < 380)
        logical := 380
    if (logical > 1200)
        logical := 1200
    FloatingToolbarChatDrawerWidth := logical
    newW := FloatingToolbarCalculateWidth()
    newH := FloatingToolbarCalculateHeight()
    try FloatingToolbarGUI.GetPos(&gx, &gy, &gw, &gh)
    catch as _e {
        gx := FloatingToolbarWindowX
        gy := FloatingToolbarWindowY
        gw := newW
        gh := newH
    }
    rightEdge := gx + gw
    newX := rightEdge - newW
    ScreenVirtual_GetBounds(&vl, &vt, &vw, &vh)
    vr := vl + vw
    if (newX < vl)
        newX := vl
    if (newX + newW > vr)
        newX := vr - newW
    FloatingToolbarWindowX := newX
    try FloatingToolbarGUI.Move(newX, gy, newW, newH)
    catch as _e2 {
    }
    FloatingToolbarApplyRoundedCorners()
    FloatingToolbar_ApplyWebViewBounds()
}

FloatingToolbarSaveDrawerWidth() {
    global FloatingToolbarChatDrawerWidth, ConfigFile
    try {
        if !IsSet(ConfigFile) || ConfigFile = ""
            ConfigFile := A_ScriptDir . "\CursorShortcut.ini"
        IniWrite(String(FloatingToolbarChatDrawerWidth), ConfigFile, "FloatingToolbar", "ChatDrawerWidth")
    } catch as _e {
    }
}

FloatingToolbarLoadDrawerWidth() {
    global FloatingToolbarChatDrawerWidth, ConfigFile
    try {
        if !IsSet(ConfigFile) || ConfigFile = ""
            ConfigFile := A_ScriptDir . "\CursorShortcut.ini"
        v := IniRead(ConfigFile, "FloatingToolbar", "ChatDrawerWidth", "620")
        iv := Integer(v)
        if (iv >= 380 && iv <= 1200)
            FloatingToolbarChatDrawerWidth := iv
    } catch as _e {
    }
}

FloatingToolbarSetChatDrawerState(open) {
    global FloatingToolbarGUI, FloatingToolbarChatDrawerOpen
    global FloatingToolbarWindowX, FloatingToolbarWindowY, FloatingToolbarIsVisible
    global FloatingToolbarLastClosedX, FloatingToolbarLastClosedY

    open := !!open
    ; Do not gate by FloatingToolbarIsVisible: this state flag can lag behind
    ; WebView UI transitions and would block drawer open/close resize.
    if (!FloatingToolbarGUI)
        return

    try FloatingToolbarGUI.GetPos(&oldX, &oldY, &oldW, &oldH)
    catch {
        oldX := FloatingToolbarWindowX
        oldY := FloatingToolbarWindowY
        oldW := FloatingToolbarCalculateWidth()
        oldH := FloatingToolbarCalculateHeight()
    }

    if (open && !FloatingToolbarChatDrawerOpen) {
        FloatingToolbarLastClosedX := oldX
        FloatingToolbarLastClosedY := oldY
    }

    FloatingToolbarChatDrawerOpen := open
    newW := FloatingToolbarCalculateWidth()
    newH := FloatingToolbarCalculateHeight()

    ScreenVirtual_GetBounds(&vl, &vt, &vw, &vh)
    vr := vl + vw
    vb := vt + vh
    rightEdge := oldX + oldW

    if (open) {
        newX := rightEdge - newW
        newY := vt
    } else {
        if (FloatingToolbarLastClosedX != 0 || FloatingToolbarLastClosedY != 0) {
            newX := FloatingToolbarLastClosedX
            newY := FloatingToolbarLastClosedY
        } else {
            newX := rightEdge - newW
            newY := vb - newH
        }
    }

    if (newX < vl)
        newX := vl
    if (newY < vt)
        newY := vt
    if (newX + newW > vr)
        newX := vr - newW
    if (newY + newH > vb)
        newY := vb - newH

    FloatingToolbarWindowX := newX
    FloatingToolbarWindowY := newY
    FloatingToolbarGUI.Move(newX, newY, newW, newH)
    FloatingToolbarApplyRoundedCorners()
    FloatingToolbar_ApplyWebViewBounds()
    FloatingToolbarPushScaleStateToWeb(FloatingToolbarScale)
    SaveFloatingToolbarPosition()
}

FloatingToolbarCollapseTransientUi(forceResize := true) {
    global g_FTB_WV2, FloatingToolbarGUI, FloatingToolbarChatDrawerOpen

    if (FloatingToolbarChatDrawerOpen) {
        try FloatingToolbarSetChatDrawerState(false)
    } else if (forceResize && IsObject(FloatingToolbarGUI)) {
        try {
            newW := FloatingToolbarCalculateWidth()
            newH := FloatingToolbarCalculateHeight()
            FloatingToolbarGUI.GetPos(&gx, &gy, &gw, &gh)
            FloatingToolbarGUI.Move(gx, gy, newW, newH)
            FloatingToolbarApplyRoundedCorners()
            FloatingToolbar_ApplyWebViewBounds()
        } catch {
        }
    }

    if g_FTB_WV2 {
        try WebView_QueuePayload(g_FTB_WV2, Map("type", "host_force_toolbar_home"))
        catch {
        }
    }
}

; ===================== 鎵ц鎸夐挳鍔ㄤ綔 =====================
; WebView2 WebMessageReceived 须尽快返回；ExecuteScreenshotWithMenu 含长 Sleep 与剪贴板轮询，
; 在回调内同步调用会阻塞 WebView 消息泵，导致工具栏卡死且截图助手无法弹出。
FloatingToolbar_DeferredScreenshot(*) {
    global FloatingToolbarIsVisible, FloatingToolbar_ScheduleRestoreAfterScreenshot, g_ExecuteScreenshotWithMenuBusy
    global g_FTB_ScreenshotDeferLastTick

    ; 防抖：同一操作 1500ms 内只接受一次（截图流程耗时长，完成后也需阻止重复触发）
    if (g_FTB_ScreenshotDeferLastTick && (A_TickCount - g_FTB_ScreenshotDeferLastTick < 1500))
        return
    g_FTB_ScreenshotDeferLastTick := A_TickCount

    prevCrit := Critical("On")
    if (g_ExecuteScreenshotWithMenuBusy) {
        Critical(prevCrit)
        return
    }
    g_ExecuteScreenshotWithMenuBusy := true
    Critical(prevCrit)

    wasVisible := !!FloatingToolbarIsVisible
    FloatingToolbar_ScheduleRestoreAfterScreenshot := wasVisible

    try {
        if (wasVisible) {
            HideFloatingToolbar()
            Sleep(120)
        }
        ExecuteScreenshotWithMenu(true)
        ; 截图流程完成后刷新防抖时间戳，阻止后续 1.5 秒内的重复触发
        g_FTB_ScreenshotDeferLastTick := A_TickCount
    } catch as err {
        ; Hide/Sleep 在 ExecuteScreenshotWithMenu 之前失败时，预占的 busy 不会由后者 finally 清除
        g_ExecuteScreenshotWithMenuBusy := false
        try OutputDebug("[FloatingToolbar] DeferredScreenshot: " . err.Message)
        catch {
        }
    }
    ; 悬浮条在 ExecuteScreenshotWithMenu 内剪贴板就绪后、ShowScreenshotEditor 前统一恢复，避免 finally 再延迟 Show 造成双重显示与位置偏移
}

FloatingToolbar_EnsureSearchCenterFocused(*) {
    global GuiID_SearchCenter

    try {
        hwnd := 0
        if (IsSet(SCWV_GetGuiHwnd))
            hwnd := SCWV_GetGuiHwnd()
        if (!hwnd && GuiID_SearchCenter && IsObject(GuiID_SearchCenter) && GuiID_SearchCenter.HasProp("Hwnd"))
            hwnd := GuiID_SearchCenter.Hwnd
        if !hwnd
            return
        WinActivate("ahk_id " . hwnd)
    } catch {
    }

    try {
        if (IsSet(SCWV_RequestFocusInput))
            SCWV_RequestFocusInput()
    } catch {
    }
}

FloatingToolbar_ActivateSearchCenter() {
    selectedText := ""
    opened := false
    usedWebView := false

    try usedWebView := SearchCenter_ShouldUseWebView()
    try FloatingToolbarCollapseTransientUi()

    ; 与 CapsLock+F/拖放入口统一：有选中文本时直接带词打开，否则强制走搜索中心显示链路。
    try selectedText := Trim(String(SelectionSense_GetLastSelectedText()))
    catch {
        selectedText := ""
    }

    try {
        if (selectedText != "")
            SearchCenter_RunQueryWithKeyword(selectedText)
        else if (usedWebView) {
            SCWV_Init()
            SCWV_Show()
        } else
            ShowSearchCenter()
        opened := true
    } catch {
    }

    ; 兜底重建：避免 g_SCWV_Visible / 宿主句柄残留导致“判定已开但面板没出来”。
    if (!opened && usedWebView) {
        try {
            SCWV_ResetHostState()
            SCWV_Init()
            SCWV_Show()
            opened := true
        } catch {
        }
    }

    if (!opened) {
        try ShowSearchCenter()
        catch {
        }
    }

    ; 不论入口来自图标还是右键菜单，最后都再强制一次可见与输入焦点。
    if (usedWebView) {
        try {
            if (!SCWV_IsVisible())
                SCWV_Show()
        } catch {
            try {
                SCWV_ResetHostState()
                SCWV_Init()
                SCWV_Show()
            } catch {
            }
        }
        try SCWV_RequestFocusInput()
        catch {
        }
    }

    ; 工具栏点击后前台可能仍短暂停在工具栏 WebView，上一个激活链会吞掉焦点；补几次确保搜索中心真正拿到输入焦点。
    SetTimer(FloatingToolbar_EnsureSearchCenterFocused, -20)
    SetTimer(FloatingToolbar_EnsureSearchCenterFocused, -120)
    SetTimer(FloatingToolbar_EnsureSearchCenterFocused, -320)
}

FloatingToolbarExecuteButtonAction(action, buttonHwnd) {
    switch action {
        case "Search":
            FloatingToolbar_ActivateSearchCenter()
        case "Record":
            ; 浠呮墦寮€鏂板壀璐存澘锛圵ebView2 + ClipMain/FTS5锛夛紝涓嶅洖閫€鏃?ListView 闈㈡澘
            try CP_Show()
            catch as err {
                try TrayTip("鏂板壀璐存澘", "鏃犳硶鎵撳紑 WebView 鍓创鏉? " . err.Message, "Iconx 1")
                catch {
                    OutputDebug("[FloatingToolbar] CP_Show failed: " . err.Message)
                }
            }
        case "AIAssistant", "Prompt":
            try ShowPromptQuickPadListOnly()
            catch as err {
                TrayTip("AI閫夋嫨闈㈡澘鍔犺浇澶辫触: " . err.Message, "閿欒", "Iconx 2")
            }
        case "PromptNew", "NewPrompt":
            try SelectionSense_OpenHubCapsuleFromToolbar()
            catch as err {
                try TrayTip("Unable to open HubCapsule (SelectionSenseCore.ahk is required): " . err.Message, "Error", "Iconx 2")
                catch {
                }
            }
        case "Screenshot":
            ; 不可在 WebView2 WebMessageReceived 回调里同步执行：ExecuteScreenshotWithMenu
            ; 含长时间 Sleep/剪贴板轮询，会阻塞 WebView 消息泵，导致工具栏卡死且截图窗体无法显示。
            SetTimer(FloatingToolbar_DeferredScreenshot, -1)
        case "Settings":
            FloatingToolbarOpenSettings()
        case "VirtualKeyboard":
            FloatingToolbarActivateVirtualKeyboard()
    }
}

; 延后一帧处理搜索切换：让 WM_ACTIVATE / 延迟 Hide 与 postMessage 顺序稳定，避免「先关后立即又打开」
FloatingToolbar_SearchToggleDeferred(*) {
    global GuiID_SearchCenter
    try {
        h := SCWV_GetGuiHwnd()
        if (h && WinExist("ahk_id " . h) && (WinGetStyle("ahk_id " . h) & 0x10000000)) {
            SCWV_Hide(true)
            return
        }
    } catch {
    }
    try {
        if (SCWV_IsVisible()) {
            SCWV_Hide(true)
            return
        }
    } catch {
    }
    try {
        if (GuiID_SearchCenter != 0 && (!IsSet(SearchCenter_ShouldUseWebView) || !SearchCenter_ShouldUseWebView())) {
            SearchCenterCloseHandler()
            return
        }
    } catch {
    }
    FloatingToolbarExecuteButtonAction("Search", 0)
}

FloatingToolbar_PromptToggleDeferred(*) {
    global g_PQP_Gui
    try {
        if (g_PQP_Gui && WinExist("ahk_id " . g_PQP_Gui.Hwnd) && (WinGetStyle("ahk_id " . g_PQP_Gui.Hwnd) & 0x10000000)) {
            PQP_Hide()
            return
        }
    } catch {
    }
    try {
        if (PQP_IsVisible()) {
            PQP_Hide()
            return
        }
    } catch {
    }
    FloatingToolbarExecuteButtonAction("Prompt", 0)
}

FloatingToolbarToggleButtonAction(action) {
    global GuiID_SearchCenter, GuiID_ConfigGUI, ConfigWebViewMode, GuiID_ScreenshotEditor, g_PQP_Gui
    switch action {
        case "Search":
            SetTimer(FloatingToolbar_ActivateSearchCenter, -1)
            return
        case "Record":
            try {
                if (IsSet(g_CP_Visible) && g_CP_Visible) {
                    CP_Hide()
                    return
                }
            } catch {
            }
            FloatingToolbarExecuteButtonAction(action, 0)
        case "AIAssistant", "Prompt":
            ; 延后一帧：与 WM_ACTIVATE 延迟 Hide、postMessage 顺序对齐，减少「有时关不掉 / 关掉又弹回」
            SetTimer(FloatingToolbar_PromptToggleDeferred, -1)
            return
        case "Settings":
            ; WebView 设置：关闭时仅 Hide，GuiID_ConfigGUI 仍非 0，必须按「是否可见」切换，否则会无法再次打开
            try {
                if (GuiID_ConfigGUI != 0) {
                    cfgVisible := false
                    if (ConfigWebViewMode) {
                        try cfgVisible := ConfigWebView_HostWindowVisible()
                        catch {
                            cfgVisible := false
                        }
                    } else {
                        try {
                            cfgVisible := WinExist("ahk_id " . GuiID_ConfigGUI.Hwnd)
                                && (WinGetStyle("ahk_id " . GuiID_ConfigGUI.Hwnd) & 0x10000000)
                        } catch {
                            cfgVisible := false
                        }
                    }
                    if (cfgVisible) {
                        CloseConfigGUI()
                        return
                    }
                }
            } catch {
            }
            FloatingToolbarExecuteButtonAction(action, 0)
        case "NewPrompt":
            try {
                if (IsSet(SelectionSense_HubCapsuleHostIsOpen) && SelectionSense_HubCapsuleHostIsOpen()) {
                    SelectionSense_HideMenu()
                    return
                }
            } catch {
            }
            FloatingToolbarExecuteButtonAction(action, 0)
        case "Screenshot":
            try {
                if (IsObject(GuiID_ScreenshotEditor)) {
                    CloseScreenshotEditor()
                    return
                }
            } catch {
            }
            FloatingToolbarExecuteButtonAction(action, 0)
        case "VirtualKeyboard":
            ; VK_ToggleEmbedded 依赖可见性；失焦自动 Hide 后需与 VK_IsHostVisible 一致，见 VirtualKeyboardCore 宽限期
            try {
                if (VK_IsHostVisible()) {
                    VK_Hide()
                    return
                }
            } catch {
            }
            try {
                VK_ToggleEmbedded()
            } catch as err {
                try TrayTip("虚拟键盘不可用: " . err.Message, "虚拟键盘", "Iconx 2")
                catch {
                }
            }
        default:
            FloatingToolbarExecuteButtonAction(action, 0)
    }
}

; 前台 HWND 是否为悬浮工具栏或其子窗口（点击工具栏内 WebView 时 WinGetID("A") 常不是宿主 Hwnd）
FloatingToolbar_IsForegroundToolbarOrChild() {
    global FloatingToolbarGUI
    if !FloatingToolbarGUI
        return false
    fg := 0
    try fg := WinGetID("A")
    catch {
        return false
    }
    tb := FloatingToolbarGUI.Hwnd
    hw := fg
    Loop 40 {
        if (hw = tb)
            return true
        np := DllCall("user32\GetParent", "Ptr", hw, "Ptr")
        if !np
            break
        hw := np
    }
    return false
}

FloatingToolbarActivateVirtualKeyboard() {
    try VK_ToggleEmbedded()
    catch as err {
        try TrayTip("铏氭嫙閿洏涓嶅彲鐢? " . err.Message, "铏氭嫙閿洏", "Iconx 2")
        catch {
        }
    }
}

FloatingToolbarOpenSettings() {
    try {
        if IsSet(ShowConfigWebViewGUI) {
            ShowConfigWebViewGUI()
            return
        }
    } catch {
    }
    try {
        if IsSet(ShowConfigGUI) {
            ShowConfigGUI()
            return
        }
    } catch {
    }
    try {
        SetCapsLockState("AlwaysOff")
        Send("{CapsLock down}")
        Sleep(30)
        Send("q")
        Sleep(30)
        Send("{CapsLock up}")
        SetCapsLockState("Off")
    } catch {
    }
}

; ===================== 婊氳疆缂╂斁澶勭悊 =====================
FloatingToolbarWM_MOUSEWHEEL(wParam, lParam, msg, hwnd) {
    global FloatingToolbarGUI, FloatingToolbarIsVisible, FloatingToolbarChatDrawerOpen

    if (!FloatingToolbarIsVisible || !IsObject(FloatingToolbarGUI) || !(FloatingToolbarGUI is Gui))
        return
    ; 抽屉展开时由页面内滚动，不在此用滚轮缩放整窗
    if (FloatingToolbarChatDrawerOpen)
        return

    MouseGetPos(&mx, &my)
    try FloatingToolbarGUI.GetPos(&wx, &wy, &ww, &wh)
    catch {
        return
    }
    if (mx < wx || mx > wx + ww || my < wy || my > wy + wh)
        return

    wheelDelta := (wParam >> 16) & 0xFFFF
    if (wheelDelta > 0x7FFF)
        wheelDelta := wheelDelta - 0x10000

    delta := wheelDelta > 0 ? 1 : -1
    FloatingToolbarApplyWheelDelta(delta)

    return 0
}

FloatingToolbarApplyWheelDelta(delta) {
    global FloatingToolbarGUI, FloatingToolbarScale, FloatingToolbarMinScale, FloatingToolbarMaxScale
    global FloatingToolbarWindowX, FloatingToolbarWindowY, g_FTB_WV2

    ; 必须与 modules\FloatingToolbar.ahk 中 CreateFloatingToolbarGUI 创建的 Gui 一致；
    ; VirtualKeyboardCore 曾误用同名全局，会导致此处为 Integer 而非 Gui。
    if !IsObject(FloatingToolbarGUI) || !(FloatingToolbarGUI is Gui)
        return

    scaleStep := 0.15
    newScale := FloatingToolbarScale

    if (delta > 0) {
        newScale := FloatingToolbarScale + scaleStep
        if (newScale > FloatingToolbarMaxScale)
            newScale := FloatingToolbarMaxScale
    } else {
        newScale := FloatingToolbarScale - scaleStep
        if (newScale < FloatingToolbarMinScale)
            newScale := FloatingToolbarMinScale
    }

    if (newScale != FloatingToolbarScale) {
        FloatingToolbarGUI.GetPos(&oldX, &oldY, &oldWidth, &oldHeight)
        MouseGetPos(&mouseScreenX, &mouseScreenY)
        mouseRelX := mouseScreenX - oldX
        mouseRelY := mouseScreenY - oldY
        mouseRatioX := oldWidth > 0 ? mouseRelX / oldWidth : 0.5
        mouseRatioY := oldHeight > 0 ? mouseRelY / oldHeight : 0.5

        FloatingToolbarScale := newScale

        ToolbarWidth := FloatingToolbarCalculateWidth()
        ToolbarHeight := FloatingToolbarCalculateHeight()

        newX := mouseScreenX - Round(mouseRatioX * ToolbarWidth)
        newY := mouseScreenY - Round(mouseRatioY * ToolbarHeight)

        ScreenVirtual_GetBounds(&vl, &vt, &vw, &vh)
        vr := vl + vw
        vb := vt + vh
        if (newX < vl)
            newX := vl
        if (newY < vt)
            newY := vt
        if (newX + ToolbarWidth > vr)
            newX := vr - ToolbarWidth
        if (newY + ToolbarHeight > vb)
            newY := vb - ToolbarHeight

        FloatingToolbarWindowX := newX
        FloatingToolbarWindowY := newY

        FloatingToolbarGUI.Move(newX, newY, ToolbarWidth, ToolbarHeight)
        FloatingToolbarApplyRoundedCorners()
        FloatingToolbar_ApplyWebViewBounds()

        FloatingToolbarPushScaleStateToWeb(newScale)

        FloatingToolbarSaveScale()
        SaveFloatingToolbarPosition()
    }
}

; ===================== 拖动（WebView2 内 PostMessage HTCAPTION 不可靠，用手动 Move；同步循环比 1ms 定时器更跟手）====================
FloatingToolbar_DragRun(*) {
    global FloatingToolbarGUI, FloatingToolbarDragging, FloatingToolbarWindowX, FloatingToolbarWindowY
    global FloatingToolbar_DragOriginScreenX, FloatingToolbar_DragOriginScreenY
    global FloatingToolbar_DragOriginWinX, FloatingToolbar_DragOriginWinY

    if !(FloatingToolbarGUI && FloatingToolbarDragging)
        return
    try {
        ToolbarWidth := FloatingToolbarCalculateWidth()
        ToolbarHeight := FloatingToolbarCalculateHeight()
        ScreenVirtual_GetBounds(&vl, &vt, &vw, &vh)
        vr := vl + vw
        vb := vt + vh
        lastX := FloatingToolbarWindowX
        lastY := FloatingToolbarWindowY
        while GetKeyState("LButton", "P") {
            CoordMode("Mouse", "Screen")
            MouseGetPos(&mx, &my)
            newX := FloatingToolbar_DragOriginWinX + (mx - FloatingToolbar_DragOriginScreenX)
            newY := FloatingToolbar_DragOriginWinY + (my - FloatingToolbar_DragOriginScreenY)
            if (newX < vl)
                newX := vl
            if (newY < vt)
                newY := vt
            if (newX + ToolbarWidth > vr)
                newX := vr - ToolbarWidth
            if (newY + ToolbarHeight > vb)
                newY := vb - ToolbarHeight
            if (newX != lastX || newY != lastY) {
                try FloatingToolbarGUI.Move(newX, newY)
                lastX := newX
                lastY := newY
                FloatingToolbarWindowX := newX
                FloatingToolbarWindowY := newY
            }
        }
    } catch {
    }
    FloatingToolbarDragging := false
    FloatingToolbarCheckWindowPosition()
    SaveFloatingToolbarPosition()
}

; ===================== 绐楀彛浣嶇疆妫€鏌ヤ笌纾佸惛 =====================
FloatingToolbarCheckWindowPosition() {
    global FloatingToolbarGUI, FloatingToolbarWindowX, FloatingToolbarWindowY, FloatingToolbarDragging, FloatingToolbarIsVisible

    if (!FloatingToolbarIsVisible || FloatingToolbarGUI = 0)
        return

    if (FloatingToolbarDragging)
        return

    if (!GetKeyState("LButton", "P")) {
        try {
            FloatingToolbarGUI.GetPos(&newX, &newY)
            FloatingToolbarWindowX := newX
            FloatingToolbarWindowY := newY

            ScreenVirtual_GetBounds(&vl, &vt, &vw, &vh)
            vr := vl + vw
            vb := vt + vh
            adjustedX := newX
            adjustedY := newY

            snapDistance := 30
            windowWidth := FloatingToolbarCalculateWidth()
            windowHeight := FloatingToolbarCalculateHeight()

            if (adjustedX < vl + snapDistance)
                adjustedX := vl
            else if (adjustedX + windowWidth > vr - snapDistance)
                adjustedX := vr - windowWidth

            if (adjustedY < vt + snapDistance)
                adjustedY := vt
            else if (adjustedY + windowHeight > vb - snapDistance)
                adjustedY := vb - windowHeight

            if (adjustedX < vl)
                adjustedX := vl
            if (adjustedY < vt)
                adjustedY := vt
            if (adjustedX + windowWidth > vr)
                adjustedX := vr - windowWidth
            if (adjustedY + windowHeight > vb)
                adjustedY := vb - windowHeight

            if (adjustedX != newX || adjustedY != newY) {
                FloatingToolbarGUI.Move(adjustedX, adjustedY)
                FloatingToolbarWindowX := adjustedX
                FloatingToolbarWindowY := adjustedY
            }

            SaveFloatingToolbarPosition()
            FloatingToolbar_ApplyWebViewBounds()
        } catch {
        }
    }
}

; 鍙抽敭鑿滃崟鐢变富鑴氭湰 ShowFloatingToolbarUnifiedContextMenu 鎻愪緵锛堟繁鑹插脊绐楁牱寮忥級锛岄伩鍏嶄笌 #Include 鍐茬獊銆?
FloatingToolbarResetScale() {
    global FloatingToolbarScale, FloatingToolbarGUI, FloatingToolbarWindowX, FloatingToolbarWindowY, g_FTB_WV2

    FloatingToolbarScale := 1.0
    ToolbarWidth := FloatingToolbarCalculateWidth()
    ToolbarHeight := FloatingToolbarCalculateHeight()

    FloatingToolbarGUI.Move(FloatingToolbarWindowX, FloatingToolbarWindowY, ToolbarWidth, ToolbarHeight)
    FloatingToolbarApplyRoundedCorners()
    FloatingToolbar_ApplyWebViewBounds()

    FloatingToolbarPushScaleStateToWeb(1.0)

    FloatingToolbarSaveScale()
    SaveFloatingToolbarPosition()
}

OnFloatingToolbarContextMenu(*) {
    CoordMode("Mouse", "Screen")
    MouseGetPos(&mx, &my)
    SetTimer(FloatingToolbar_ShowContextMenuDeferred.Bind(mx, my), -1)
}

FloatingToolbar_ParseWebMessage(args) {
    ; 1) Preferred path for postMessage(string): raw payload without extra JSON wrapper.
    try {
        raw := args.TryGetWebMessageAsString()
        if (raw != "") {
            try {
                m := Jxon_Load(raw)
                if (m is Map)
                    return m
            } catch {
            }
        }
    } catch {
    }

    ; 2) Fallback path for postMessage(object): JSON value from WebMessageAsJson.
    try {
        jsonStr := args.WebMessageAsJson
        m := Jxon_Load(jsonStr)
        if (m is String)
            m := Jxon_Load(m)
        if (m is Map)
            return m
    } catch {
    }

    FTB_Debug("web message parse failed", "err")
    return 0
}

FloatingToolbar_ShowContextMenuDeferred(anchorX := 0, anchorY := 0) {
    if (anchorX <= 0 || anchorY <= 0) {
        CoordMode("Mouse", "Screen")
        MouseGetPos(&anchorX, &anchorY)
    }
    FTB_Debug("show menu @" . anchorX . "," . anchorY)
    try ShowFloatingToolbarUnifiedContextMenu(anchorX, anchorY)
    catch as err {
        FTB_Debug("show menu failed: " . err.Message, "err")
    }
}

; ===================== 绐楀彛鍏抽棴浜嬩欢 =====================
OnFloatingToolbarClose(*) {
    HideFloatingToolbar()
}

; ===================== 浣嶇疆淇濆瓨鍜屽姞杞?=====================
SaveFloatingToolbarPosition() {
    global FloatingToolbarGUI, FloatingToolbarWindowX, FloatingToolbarWindowY
    global FloatingToolbarChatDrawerOpen, FloatingToolbarLastClosedX, FloatingToolbarLastClosedY

    if (FloatingToolbarGUI = 0)
        return

    try {
        if (FloatingToolbarChatDrawerOpen && (FloatingToolbarLastClosedX != 0 || FloatingToolbarLastClosedY != 0)) {
            x := FloatingToolbarLastClosedX
            y := FloatingToolbarLastClosedY
        } else {
            FloatingToolbarGUI.GetPos(&x, &y)
        }
        FloatingToolbarWindowX := x
        FloatingToolbarWindowY := y

        ConfigFile := A_ScriptDir . "\CursorShortcut.ini"
        IniWrite(String(x), ConfigFile, "WindowPositions", "FloatingToolbar_X")
        IniWrite(String(y), ConfigFile, "WindowPositions", "FloatingToolbar_Y")
    } catch {
    }
}

LoadFloatingToolbarPosition() {
    global FloatingToolbarWindowX, FloatingToolbarWindowY

    try {
        ConfigFile := A_ScriptDir . "\CursorShortcut.ini"
        savedX := IniRead(ConfigFile, "WindowPositions", "FloatingToolbar_X", "")
        savedY := IniRead(ConfigFile, "WindowPositions", "FloatingToolbar_Y", "")

        if (savedX != "" && savedY != "" && savedX != "ERROR" && savedY != "ERROR") {
            FloatingToolbarWindowX := Integer(savedX)
            FloatingToolbarWindowY := Integer(savedY)

            ScreenVirtual_GetBounds(&vl, &vt, &vw, &vh)
            vr := vl + vw
            vb := vt + vh
            ToolbarWidth := FloatingToolbarCalculateWidth()
            ToolbarHeight := FloatingToolbarCalculateHeight()

            if (FloatingToolbarWindowX < vl || FloatingToolbarWindowX > vr - ToolbarWidth)
                FloatingToolbarWindowX := vl
            if (FloatingToolbarWindowY < vt || FloatingToolbarWindowY > vb - ToolbarHeight)
                FloatingToolbarWindowY := vt
        }
    } catch {
        FloatingToolbarWindowX := 0
        FloatingToolbarWindowY := 0
    }
}

; ===================== 缂╂斁淇濆瓨鍜屽姞杞?=====================
FloatingToolbarSaveScale() {
    global FloatingToolbarScale
    try {
        ConfigFile := A_ScriptDir . "\CursorShortcut.ini"
        IniWrite(String(FloatingToolbarScale), ConfigFile, "FloatingToolbar", "Scale")
    } catch {
    }
}

FloatingToolbarLoadScale() {
    global FloatingToolbarScale, FloatingToolbarMinScale, FloatingToolbarMaxScale
    try {
        ConfigFile := A_ScriptDir . "\CursorShortcut.ini"
        savedScale := IniRead(ConfigFile, "FloatingToolbar", "Scale", "1.0")
        if (savedScale != "" && savedScale != "ERROR") {
            scaleValue := Float(savedScale)
            if (scaleValue >= FloatingToolbarMinScale && scaleValue <= FloatingToolbarMaxScale)
                FloatingToolbarScale := scaleValue
        }
    } catch {
    }
    FloatingToolbarLoadDrawerWidth()
}

FloatingToolbarIsCompactMode(scaleValue := "") {
    global FloatingToolbarScale, FloatingToolbarMinScale, FloatingToolbarChatDrawerOpen
    sc := (scaleValue = "") ? FloatingToolbarScale : Float(scaleValue)
    if FloatingToolbarChatDrawerOpen
        return false
    return (sc <= (FloatingToolbarMinScale + 0.0001))
}

FloatingToolbarPushScaleStateToWeb(scaleValue := "") {
    global g_FTB_WV2, FloatingToolbarScale
    if !g_FTB_WV2
        return
    sc := (scaleValue = "") ? FloatingToolbarScale : Float(scaleValue)
    compact := FloatingToolbarIsCompactMode(sc)
    try WebView_QueuePayload(g_FTB_WV2, Map("type", "set_scale", "scale", sc, "compact", compact))
    catch as _e {
    }
}

FloatingToolbar_DeferredToolbarCmd(cmdId) {
    c := String(cmdId)
    ; 命令工具栏中的面板类入口统一走 toggle，确保“点击同一按钮可显示/隐藏”。
    if (c = "sc_activate_search") {
        FloatingToolbarToggleButtonAction("Search")
        return
    }
    if (c = "qa_clipboard") {
        FloatingToolbarToggleButtonAction("Record")
        return
    }
    if (c = "ch_b" || c = "qa_batch") {
        FloatingToolbarToggleButtonAction("Prompt")
        return
    }
    if (c = "ftb_scratchpad" || c = "hub_capsule") {
        FloatingToolbarToggleButtonAction("NewPrompt")
        return
    }
    if (c = "ftb_screenshot" || c = "ch_t") {
        FloatingToolbarToggleButtonAction("Screenshot")
        return
    }
    if (c = "qa_config") {
        FloatingToolbarToggleButtonAction("Settings")
        return
    }
    if (c = "sys_show_vk") {
        FloatingToolbarToggleButtonAction("VirtualKeyboard")
        return
    }
    if (c = "ftb_cursor_menu") {
        FloatingToolbar_ShowCursorQuickMenu()
        return
    }
    try {
        _ExecuteCommand(c)
    } catch as e {
        try OutputDebug("[FloatingToolbar] toolbar_cmd: " . e.Message)
        catch {
        }
    }
}

FloatingToolbarPushCmdLayoutToWeb() {
    global g_FTB_WV2, g_Commands, FloatingToolbarCmdVisibleCount, FloatingToolbarChatDrawerOpen, g_FTB_BlockedCmdIds, g_FTB_AllowedCmdIds
    if !g_FTB_WV2
        return
    try {
        if (!IsSet(g_Commands) || !(g_Commands is Map) || !g_Commands.Has("CommandList") || !(g_Commands["CommandList"] is Map)
            || g_Commands["CommandList"].Count = 0)
            _LoadCommands()
    } catch {
    }
    try {
        if (IsSet(_VK_EnsureToolbarLayout) && IsSet(g_Commands) && g_Commands is Map && g_Commands.Has("CommandList"))
            _VK_EnsureToolbarLayout()
    } catch {
    }
    if !(IsSet(g_Commands) && g_Commands is Map && g_Commands.Has("ToolbarLayout") && g_Commands["ToolbarLayout"] is Array
        && g_Commands.Has("CommandList") && g_Commands["CommandList"] is Map)
        return
    cmdList := g_Commands["CommandList"]
    items := []
    rows := []
    for row in g_Commands["ToolbarLayout"]
        rows.Push(row)
    if rows.Length > 1
        rows := _VK_SortRowsByNumericKey(rows, "order_bar")
    for row in rows {
        if !(row is Map) || !row.Has("cmdId")
            continue
        if !row.Has("visible_in_bar") || !row["visible_in_bar"]
            continue
        cid := Trim(String(row["cmdId"]))
        if (cid = "" || !cmdList.Has(cid))
            continue
        if g_FTB_BlockedCmdIds.Has(cid)
            continue
        if !g_FTB_AllowedCmdIds.Has(cid)
            continue
        ent := cmdList[cid]
        nm := ent.Has("name") ? String(ent["name"]) : cid
        ic := "fa-circle"
        if (ent is Map) && ent.Has("iconClass") && ent["iconClass"] != "" {
            ic := Trim(String(ent["iconClass"]))
            if (SubStr(ic, 1, 3) != "fa-")
                ic := "fa-solid " . ic
            else if !InStr(ic, "fa-solid") && !InStr(ic, "fa-brands") && !InStr(ic, "fa-regular")
                ic := "fa-solid " . ic
        }
        rowPayload := Map("cmdId", cid, "name", nm, "iconClass", ic)
        if (cid = "ftb_cursor_menu")
            rowPayload["iconPath"] := "images/cursor.png"
        items.Push(rowPayload)
    }
    hasCursorMenu := false
    for _, it in items {
        if ((it is Map) && it.Has("cmdId") && String(it["cmdId"]) = "ftb_cursor_menu") {
            hasCursorMenu := true
            break
        }
    }
    if (!hasCursorMenu && g_FTB_AllowedCmdIds.Has("ftb_cursor_menu")) {
        cursorName := "Cursor 快捷菜单"
        if (cmdList.Has("ftb_cursor_menu")) {
            cent := cmdList["ftb_cursor_menu"]
            if (cent is Map) && cent.Has("name") && cent["name"] != ""
                cursorName := String(cent["name"])
        }
        items.Push(Map(
            "cmdId", "ftb_cursor_menu",
            "name", cursorName,
            "iconClass", "fa-solid fa-bolt",
            "iconPath", "images/cursor.png"
        ))
    }
    FloatingToolbarCmdVisibleCount := items.Length
    try WebView_QueuePayload(g_FTB_WV2, Map("type", "set_toolbar_cmds", "items", items))
    catch as _e {
    }
    if !FloatingToolbarChatDrawerOpen && !FloatingToolbarIsCompactMode()
        FloatingToolbar_ResizeForToolbarCount()
}

FloatingToolbarReloadFromToolbarLayout() {
    FloatingToolbarPushCmdLayoutToWeb()
}

FloatingToolbarPushButtonConfigToWeb() {
    FloatingToolbarPushCmdLayoutToWeb()
}

FloatingToolbarExitCompactMode() {
    global FloatingToolbarGUI, FloatingToolbarScale, FloatingToolbarMinScale, FloatingToolbarMaxScale
    global FloatingToolbarWindowX, FloatingToolbarWindowY

    if !IsObject(FloatingToolbarGUI) || !(FloatingToolbarGUI is Gui)
        return
    if !FloatingToolbarIsCompactMode()
        return

    targetScale := FloatingToolbarMinScale + 0.15
    if (targetScale > FloatingToolbarMaxScale)
        targetScale := FloatingToolbarMaxScale

    try FloatingToolbarGUI.GetPos(&oldX, &oldY, &oldW, &oldH)
    catch {
        oldX := FloatingToolbarWindowX
        oldY := FloatingToolbarWindowY
        oldW := FloatingToolbarCalculateWidth()
        oldH := FloatingToolbarCalculateHeight()
    }

    centerX := oldX + (oldW / 2.0)
    centerY := oldY + (oldH / 2.0)
    FloatingToolbarScale := targetScale
    newW := FloatingToolbarCalculateWidth()
    newH := FloatingToolbarCalculateHeight()
    newX := Round(centerX - (newW / 2.0))
    newY := Round(centerY - (newH / 2.0))

    ScreenVirtual_GetBounds(&vl, &vt, &vw, &vh)
    vr := vl + vw
    vb := vt + vh
    if (newX < vl)
        newX := vl
    if (newY < vt)
        newY := vt
    if (newX + newW > vr)
        newX := vr - newW
    if (newY + newH > vb)
        newY := vb - newH

    FloatingToolbarWindowX := newX
    FloatingToolbarWindowY := newY
    FloatingToolbarGUI.Move(newX, newY, newW, newH)
    FloatingToolbarApplyRoundedCorners()
    FloatingToolbar_ApplyWebViewBounds()
    FloatingToolbarPushScaleStateToWeb(targetScale)
    FloatingToolbarSaveScale()
    SaveFloatingToolbarPosition()
}

; ===================== 璁＄畻宸ュ叿鏍忓搴﹀拰楂樺害 =====================
FloatingToolbarCalculateWidth() {
    global FloatingToolbarScale, FloatingToolbarChatDrawerOpen, FloatingToolbarChatDrawerWidth, FloatingToolbarCompactDiameter, FloatingToolbarCmdVisibleCount
    iconCount := (FloatingToolbarCmdVisibleCount > 0) ? FloatingToolbarCmdVisibleCount : 7
    BaseWidth := Max(220, 56 + iconCount * 46)
    if (FloatingToolbarChatDrawerOpen)
        return Round(Max(BaseWidth, FloatingToolbarChatDrawerWidth) * FloatingToolbarScale)
    if FloatingToolbarIsCompactMode()
        return Round(FloatingToolbarCompactDiameter)
    return Round(BaseWidth * FloatingToolbarScale)
}

FloatingToolbar_ShowCursorQuickMenu() {
    menuItems := [
        { Text: "命令面板  (Ctrl+Shift+P)", Icon: "▸", Action: (*) => _ExecuteCommand("qa_command_palette") },
        { Text: "全局搜索  (Ctrl+Shift+F)", Icon: "▸", Action: (*) => _ExecuteCommand("qa_global_search") },
        { Text: "资源管理器  (Ctrl+Shift+E)", Icon: "▸", Action: (*) => _ExecuteCommand("qa_explorer") },
        { Text: "源代码管理  (Ctrl+Shift+G)", Icon: "▸", Action: (*) => _ExecuteCommand("qa_source_control") },
        { Text: "扩展  (Ctrl+Shift+X)", Icon: "▸", Action: (*) => _ExecuteCommand("qa_extensions") },
        { Text: "终端  (Ctrl+Shift+``)", Icon: "▸", Action: (*) => _ExecuteCommand("qa_terminal") },
        { Text: "Cursor 设置  (Ctrl+,)", Icon: "▸", Action: (*) => _ExecuteCommand("qa_cursor_settings") }
    ]
    try {
        MouseGetPos &mx, &my
        ShowDarkStylePopupMenuAt(menuItems, mx + 2, my + 2)
    } catch {
    }
}

FloatingToolbar_ResizeForToolbarCount() {
    global FloatingToolbarGUI, FloatingToolbarWindowX, FloatingToolbarWindowY, FloatingToolbarChatDrawerOpen
    if !IsObject(FloatingToolbarGUI) || FloatingToolbarChatDrawerOpen || FloatingToolbarIsCompactMode()
        return
    newW := FloatingToolbarCalculateWidth()
    newH := FloatingToolbarCalculateHeight()
    try FloatingToolbarGUI.GetPos(&gx, &gy, &gw, &gh)
    catch {
        gx := FloatingToolbarWindowX
        gy := FloatingToolbarWindowY
        gw := newW
    }
    rightEdge := gx + gw
    newX := rightEdge - newW
    ScreenVirtual_GetBounds(&vl, &vt, &vw, &vh)
    vr := vl + vw
    if (newX < vl)
        newX := vl
    if (newX + newW > vr)
        newX := vr - newW
    FloatingToolbarWindowX := newX
    FloatingToolbarWindowY := gy
    try FloatingToolbarGUI.Move(newX, gy, newW, newH)
    catch {
    }
    FloatingToolbar_ApplyWebViewBounds()
}

FloatingToolbarCalculateHeight() {
    global FloatingToolbarScale, FloatingToolbarChatDrawerOpen, FloatingToolbarChatDrawerHeight, FloatingToolbarCompactDiameter
    ; HTML 缁撴瀯涓?52px logo + 涓婁笅鍚?6px padding锛屽洜姝ゅ熀鍑嗛珮搴﹀繀椤绘槸 64
    BaseHeight := 64
    if FloatingToolbarChatDrawerOpen {
        ScreenVirtual_GetBounds(&vl, &vt, &vw, &vh)
        return vh
    }
    if FloatingToolbarIsCompactMode()
        return Round(FloatingToolbarCompactDiameter)
    return Round(BaseHeight * FloatingToolbarScale)
}

; ===================== 鏈€灏忓寲鍒板睆骞曡竟缂?=====================
MinimizeFloatingToolbarToEdge() {
    global FloatingToolbarGUI, FloatingToolbarIsVisible, FloatingToolbarIsMinimized
    global FloatingToolbarWindowX, FloatingToolbarWindowY

    if (!FloatingToolbarIsVisible || FloatingToolbarGUI = 0)
        return

    FloatingToolbarGUI.GetPos(&currentX, &currentY, &currentW, &currentH)

    ScreenVirtual_GetBounds(&vl, &vt, &vw, &vh)
    vr := vl + vw
    vb := vt + vh

    distLeft := currentX - vl
    distRight := vr - (currentX + currentW)
    distTop := currentY - vt
    distBottom := vb - (currentY + currentH)

    minDist := distLeft
    targetX := vl
    targetY := currentY

    if (distRight < minDist) {
        minDist := distRight
        targetX := vr - currentW
        targetY := currentY
    }
    if (distTop < minDist) {
        minDist := distTop
        targetX := currentX
        targetY := vt
    }
    if (distBottom < minDist) {
        minDist := distBottom
        targetX := currentX
        targetY := vb - currentH
    }

    FloatingToolbarGUI.Move(targetX, targetY)
    FloatingToolbarWindowX := targetX
    FloatingToolbarWindowY := targetY
    FloatingToolbarIsMinimized := true

    SaveFloatingToolbarPosition()
}

RestoreFloatingToolbar() {
    global FloatingToolbarIsMinimized
    FloatingToolbarIsMinimized := false
}

; ===================== 閫夊尯鎰熷簲鑱斿姩 =====================
FloatingToolbar_NotifySelectionChange(fullText) {
    global g_FTB_WV2, g_FTB_WV2_Ready, g_FTB_WV2_FrameReady, g_FTB_PendingSelection

    if !g_FTB_WV2 {
        g_FTB_PendingSelection := String(fullText)
        return
    }
    if !(g_FTB_WV2_Ready && g_FTB_WV2_FrameReady) {
        g_FTB_PendingSelection := String(fullText)
        return
    }
    pv := SubStr(String(fullText), 1, 220)
    try WebView_QueuePayload(g_FTB_WV2, Map("type", "SELECTION_CHANGE", "preview", pv))
    catch as _e {
        g_FTB_PendingSelection := String(fullText)
        return
    }
}

FloatingToolbar_NotifySelectionClear() {
    global g_FTB_WV2, g_FTB_WV2_Ready, g_FTB_WV2_FrameReady, g_FTB_PendingSelection

    g_FTB_PendingSelection := ""
    if !(g_FTB_WV2 && g_FTB_WV2_Ready && g_FTB_WV2_FrameReady)
        return
    try WebView_QueuePayload(g_FTB_WV2, Map("type", "SELECTION_CLEAR"))
    catch as _e {
    }
}

FloatingToolbar_SendTextToNiumaChat(text, sendNow := true, appendMode := true, openDrawer := true) {
    global g_FTB_WV2, g_FTB_WV2_Ready, g_FTB_WV2_FrameReady, g_FTB_PendingNiumaCompose

    t := Trim(String(text), " `t`r`n")
    if (t = "")
        return false
    if !g_FTB_WV2
        return false

    if openDrawer {
        try FloatingToolbarSetChatDrawerState(true)
    }

    payload := Map(
        "type", "niuma_compose_send",
        "text", t,
        "send", !!sendNow,
        "append", !!appendMode,
        "openDrawer", !!openDrawer
    )
    if !(g_FTB_WV2_Ready && g_FTB_WV2_FrameReady) {
        try {
            if !(g_FTB_PendingNiumaCompose is Array)
                g_FTB_PendingNiumaCompose := []
            g_FTB_PendingNiumaCompose.Push(payload)
            return true
        } catch as _ePending {
            return false
        }
    }
    try {
        WebView_QueuePayload(g_FTB_WV2, payload)
        return true
    } catch as _e {
        return false
    }
}

; ===================== 鍒濆鍖?=====================
InitFloatingToolbar() {
}

; ===================== 鏍规嵁鎸夐挳action鑾峰彇鎻愮ず鏂囧瓧 =====================
GetButtonTip(action) {
    switch action {
        case "Search":
            return "搜索记录 (CapsLock + F)"
        case "Record":
            return "新剪贴板 (WebView2 · FTS5)"
        case "AIAssistant":
            return "AI 助手 (Ctrl+Shift+B)"
        case "PromptNew":
            return "Hub 草稿 · 运行 hub_capsule · 采集 CapsLock+C"
        case "Screenshot":
            return "屏幕截图 (CapsLock + T)"
        case "Settings":
            return "系统设置 (CapsLock + Q)"
        case "VirtualKeyboard":
            return "虚拟键盘 (Ctrl+Shift+K)"
        default:
            return ""
    }
}
