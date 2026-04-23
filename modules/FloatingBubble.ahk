; 悬浮球：仅牛马图标 WebView2，右键菜单与悬浮条一致，长按左键拖动（由页面发 drag_host）
#Requires AutoHotkey v2.0

global FloatingBubbleGUI := 0
global g_FB_WV2_Ctrl := 0
global g_FB_WV2 := 0
global g_FB_WV2_Ready := false
global g_FB_WV2_FrameReady := false
global FloatingBubbleWindowX := 0
global FloatingBubbleWindowY := 0
global FloatingBubbleIsVisible := false
global FloatingBubbleDragging := false
global FloatingBubble_DragOriginScreenX := 0
global FloatingBubble_DragOriginScreenY := 0
global FloatingBubble_DragOriginWinX := 0
global FloatingBubble_DragOriginWinY := 0
global FloatingBubbleSize := 45
global g_FB_WV2_CreateRetry := 0

FloatingBubble_GetSize() {
    return FloatingBubbleSize
}

; 正方形客户区裁成圆形（CreateEllipticRgn）；页面用 border-radius:50% 由 Chromium 做边缘抗锯齿
FloatingBubble_ApplyWindowShape(hwnd) {
    global FloatingBubbleGUI
    if !hwnd && FloatingBubbleGUI
        hwnd := FloatingBubbleGUI.Hwnd
    if !hwnd
        return
    WinGetClientPos(, , &cw, &ch, hwnd)
    if (cw < 4 || ch < 4)
        return
    ; 外接矩形 (0,0)-(cw,ch)，宽=高 时为正圆
    hrgn := DllCall("gdi32\CreateEllipticRgn", "int", 0, "int", 0, "int", cw, "int", ch, "ptr")
    if !hrgn
        return
    if !DllCall("user32\SetWindowRgn", "ptr", hwnd, "ptr", hrgn, "int", 1)
        DllCall("gdi32\DeleteObject", "ptr", hrgn)
}

FloatingBubble_DestroyCompletely() {
    global FloatingBubbleGUI, g_FB_WV2_Ctrl, g_FB_WV2, g_FB_WV2_Ready, g_FB_WV2_FrameReady
    global FloatingBubbleIsVisible, FloatingBubbleDragging
    FloatingBubbleDragging := false
    if (FloatingBubbleGUI = 0) {
        g_FB_WV2_Ctrl := 0
        g_FB_WV2 := 0
        g_FB_WV2_Ready := false
        g_FB_WV2_FrameReady := false
        return
    }
    try SaveFloatingBubblePosition()
    catch {
    }
    g_FB_WV2_Ctrl := 0
    g_FB_WV2 := 0
    g_FB_WV2_Ready := false
    g_FB_WV2_FrameReady := false
    try FloatingBubbleGUI.Destroy()
    catch {
    }
    FloatingBubbleGUI := 0
    FloatingBubbleIsVisible := false
}

FloatingBubble_OnNavigationStarting(sender, args) {
    global g_FB_WV2_FrameReady
    g_FB_WV2_FrameReady := false
}

FloatingBubble_OnNavigationCompleted(sender, args) {
    global g_FB_WV2_FrameReady
    ok := false
    try ok := args.IsSuccess
    catch {
        ok := false
    }
    g_FB_WV2_FrameReady := !!ok
}

FloatingBubble_OnWebMessage(sender, args) {
    global g_FB_WV2, g_FB_WV2_Ready, FloatingBubbleGUI, FloatingBubbleDragging
    msg := FloatingToolbar_ParseWebMessage(args)
    if !(msg is Map)
        return
    typ := msg.Has("type") ? String(msg["type"]) : ""
    if (typ = "bubble_ready") {
        g_FB_WV2_Ready := true
        FloatingBubble_ApplyWebViewBounds()
        FloatingBubble_PushLogoToWeb()
        FloatingBubble_PushThemeToWeb()
        return
    }
    if (typ = "context_menu") {
        x := msg.Has("x") ? Integer(msg["x"]) : 0
        y := msg.Has("y") ? Integer(msg["y"]) : 0
        SetTimer(FloatingBubble_ShowContextMenuDeferred.Bind(x, y), -1)
        return
    }
    if (typ = "drag_host") {
        if !FloatingBubbleGUI || FloatingBubbleDragging
            return
        try FloatingBubbleGUI.GetPos(&FloatingBubble_DragOriginWinX, &FloatingBubble_DragOriginWinY)
        catch {
            return
        }
        CoordMode("Mouse", "Screen")
        MouseGetPos(&FloatingBubble_DragOriginScreenX, &FloatingBubble_DragOriginScreenY)
        FloatingBubbleDragging := true
        SetTimer(FloatingBubble_DragRun, -1)
        return
    }
    if (typ = "bubble_mode_menu") {
        x := msg.Has("x") ? Integer(msg["x"]) : 0
        y := msg.Has("y") ? Integer(msg["y"]) : 0
        SetTimer(FloatingBubble_ShowModeMenuDeferred.Bind(x, y), -1)
        return
    }
}

FloatingBubble_ShowModeMenuDeferred(x := 0, y := 0, *) {
    FloatingBubble_ShowModeMenuAt(x, y)
}

; 悬浮球：关闭 / 切换悬浮栏 / 仅托盘（与外观设置写入同一键）
FloatingBubble_PersistModeAndApply(mode) {
    global AppearanceActivationMode
    AppearanceActivationMode := NormalizeAppearanceActivationMode(mode)
    cfg := A_ScriptDir . "\CursorShortcut.ini"
    try IniWrite(AppearanceActivationMode, cfg, "Appearance", "ActivationMode")
    catch {
    }
    ; 延后应用，让暗色菜单与 WebView 消息泵收尾，减少切换模式时异步回调与销毁竞态
    SetTimer((*) => ApplyAppearanceActivationMode(), -200)
}

FloatingBubble_MenuClose(*) {
    try HideFloatingBubble()
    catch {
    }
}

FloatingBubble_MenuToolbarMode(*) {
    FloatingBubble_PersistModeAndApply("toolbar")
}

FloatingBubble_MenuTrayOnly(*) {
    FloatingBubble_PersistModeAndApply("tray")
}

FloatingBubble_ShowModeMenuAt(anchorX := 0, anchorY := 0) {
    static LastBubbleMenuTick := 0
    if (LastBubbleMenuTick != 0 && (A_TickCount - LastBubbleMenuTick < 450))
        return
    LastBubbleMenuTick := A_TickCount
    if (anchorX <= 0 || anchorY <= 0) {
        CoordMode("Mouse", "Screen")
        MouseGetPos(&anchorX, &anchorY)
    }
    MenuItems := []
    MenuItems.Push({ Text: "关闭悬浮球", Icon: "◻", Action: FloatingBubble_MenuClose })
    MenuItems.Push({ Text: "切换到悬浮栏模式", Icon: "▤", Action: FloatingBubble_MenuToolbarMode })
    MenuItems.Push({ Text: "永久关闭（仅托盘）", Icon: "⊡", Action: FloatingBubble_MenuTrayOnly })
    try ShowDarkStylePopupMenuAt(MenuItems, anchorX, anchorY)
    catch {
    }
}

FloatingBubble_ShowContextMenuDeferred(anchorX := 0, anchorY := 0) {
    if (anchorX <= 0 || anchorY <= 0) {
        CoordMode("Mouse", "Screen")
        MouseGetPos(&anchorX, &anchorY)
    }
    try ShowFloatingToolbarUnifiedContextMenu(anchorX, anchorY)
    catch {
    }
}

FloatingBubble_PushLogoToWeb(*) {
    global g_FB_WV2
    if !g_FB_WV2
        return
    url := FloatingToolbar_GetLogoAppUrl()
    if (url = "")
        return
    try WebView_QueuePayload(g_FB_WV2, Map("type", "set_logo", "url", url))
    catch {
    }
}

FloatingBubble_PushThemeToWeb(*) {
    global g_FB_WV2, ThemeMode
    if !g_FB_WV2
        return
    tm := StrLower(Trim(String(ThemeMode)))
    if (tm != "light")
        tm := "dark"
    try WebView_QueuePayload(g_FB_WV2, Map("type", "set_theme", "themeMode", tm))
    catch {
    }
}

FloatingBubble_ApplyWebViewBounds() {
    global FloatingBubbleGUI, g_FB_WV2_Ctrl
    ; 无 WebView 时也要更新宿主外形（首次 Show 在异步创建完成前）
    if FloatingBubbleGUI
        try FloatingBubble_ApplyWindowShape(FloatingBubbleGUI.Hwnd)
    if !(FloatingBubbleGUI && g_FB_WV2_Ctrl)
        return
    WinGetClientPos(, , &cw, &ch, FloatingBubbleGUI.Hwnd)
    rc := WebView2.RECT()
    rc.left := 0
    rc.top := 0
    rc.right := cw
    rc.bottom := ch
    try {
        g_FB_WV2_Ctrl.Bounds := rc
        g_FB_WV2_Ctrl.NotifyParentWindowPositionChanged()
    } catch {
    }
}

FloatingBubble_RetryCreateWebView() {
    global FloatingBubbleGUI, g_FB_WV2_CreateRetry
    if !FloatingBubbleGUI
        return
    if (g_FB_WV2_CreateRetry >= 3)
        return
    g_FB_WV2_CreateRetry += 1
    SetTimer((*) => WebView2.create(FloatingBubbleGUI.Hwnd, FloatingBubble_OnWebViewCreated, WebView2_EnsureSharedEnvBlocking()), -200)
}

FloatingBubble_OnWebViewCreated(ctrl) {
    global g_FB_WV2_Ctrl, g_FB_WV2, g_FB_WV2_Ready, g_FB_WV2_FrameReady, g_FB_WV2_CreateRetry

    if !IsObject(ctrl) || !ctrl.HasProp("CoreWebView2") {
        FloatingBubble_RetryCreateWebView()
        return
    }
    g_FB_WV2_CreateRetry := 0
    g_FB_WV2_Ctrl := ctrl
    g_FB_WV2 := ctrl.CoreWebView2
    g_FB_WV2_Ready := false
    g_FB_WV2_FrameReady := false

    ; 与 Gui / HTML #121212 一致，抗锯齿边缘与底色同色才不会有外圈假「黑环」
    try ctrl.DefaultBackgroundColor := 0xFF121212
    try ctrl.IsVisible := true

    FloatingBubble_ApplyWebViewBounds()

    s := g_FB_WV2.Settings
    s.AreDefaultContextMenusEnabled := false
    s.AreDevToolsEnabled := false
    try s.AreBrowserAcceleratorKeysEnabled := false
    ApplyWebView2PerformanceSettings(g_FB_WV2)
    WebView2_RegisterHostBridge(g_FB_WV2)

    g_FB_WV2.add_NavigationStarting(FloatingBubble_OnNavigationStarting)
    g_FB_WV2.add_NavigationCompleted(FloatingBubble_OnNavigationCompleted)
    g_FB_WV2.add_WebMessageReceived(FloatingBubble_OnWebMessage)
    try ApplyUnifiedWebViewAssets(g_FB_WV2)
    g_FB_WV2.Navigate(BuildAppLocalUrl("FloatingBubble.html"))
}

CreateFloatingBubbleGUI() {
    global FloatingBubbleGUI, g_FB_WV2_Ctrl, g_FB_WV2, g_FB_WV2_Ready, g_FB_WV2_FrameReady
    global WebView2, g_FB_WV2_CreateRetry
    g_FB_WV2_CreateRetry := 0

    if (FloatingBubbleGUI != 0) {
        g_FB_WV2_Ctrl := 0
        g_FB_WV2 := 0
        g_FB_WV2_Ready := false
        g_FB_WV2_FrameReady := false
        try FloatingBubbleGUI.Destroy()
        catch {
        }
    }

    FloatingBubbleGUI := Gui("+AlwaysOnTop -Caption +ToolWindow -DPIScale +E0x02000000", "Floating Bubble")
    FloatingBubbleGUI.BackColor := "121212"
    WebView2.create(FloatingBubbleGUI.Hwnd, FloatingBubble_OnWebViewCreated, WebView2_EnsureSharedEnvBlocking())
}

SaveFloatingBubblePosition() {
    global FloatingBubbleGUI, FloatingBubbleWindowX, FloatingBubbleWindowY
    if (FloatingBubbleGUI = 0)
        return
    try {
        FloatingBubbleGUI.GetPos(&x, &y)
        FloatingBubbleWindowX := x
        FloatingBubbleWindowY := y
        ConfigFile := A_ScriptDir . "\CursorShortcut.ini"
        IniWrite(String(x), ConfigFile, "WindowPositions", "FloatingBubble_X")
        IniWrite(String(y), ConfigFile, "WindowPositions", "FloatingBubble_Y")
    } catch {
    }
}

LoadFloatingBubblePosition() {
    global FloatingBubbleWindowX, FloatingBubbleWindowY
    try {
        ConfigFile := A_ScriptDir . "\CursorShortcut.ini"
        savedX := IniRead(ConfigFile, "WindowPositions", "FloatingBubble_X", "")
        savedY := IniRead(ConfigFile, "WindowPositions", "FloatingBubble_Y", "")
        if (savedX != "" && savedY != "" && savedX != "ERROR" && savedY != "ERROR") {
            FloatingBubbleWindowX := Integer(savedX)
            FloatingBubbleWindowY := Integer(savedY)
            sz := FloatingBubble_GetSize()
            ScreenVirtual_GetBounds(&vl, &vt, &vw, &vh)
            vr := vl + vw
            vb := vt + vh
            if (FloatingBubbleWindowX < vl || FloatingBubbleWindowX > vr - sz)
                FloatingBubbleWindowX := vl
            if (FloatingBubbleWindowY < vt || FloatingBubbleWindowY > vb - sz)
                FloatingBubbleWindowY := vt
        }
    } catch {
        FloatingBubbleWindowX := 0
        FloatingBubbleWindowY := 0
    }
}

; 同步拖动循环（比 1ms 定时器更跟手，避免 WebView 消息泵与计时器合帧延迟）
FloatingBubble_DragRun(*) {
    global FloatingBubbleGUI, FloatingBubbleDragging, FloatingBubbleWindowX, FloatingBubbleWindowY
    global FloatingBubble_DragOriginScreenX, FloatingBubble_DragOriginScreenY
    global FloatingBubble_DragOriginWinX, FloatingBubble_DragOriginWinY

    if !(FloatingBubbleGUI && FloatingBubbleDragging)
        return
    try {
        while GetKeyState("LButton", "P") {
            CoordMode("Mouse", "Screen")
            MouseGetPos(&mx, &my)
            newX := FloatingBubble_DragOriginWinX + (mx - FloatingBubble_DragOriginScreenX)
            newY := FloatingBubble_DragOriginWinY + (my - FloatingBubble_DragOriginScreenY)
            sz := FloatingBubble_GetSize()
            ScreenVirtual_GetBounds(&vl, &vt, &vw, &vh)
            vr := vl + vw
            vb := vt + vh
            if (newX < vl)
                newX := vl
            if (newY < vt)
                newY := vt
            if (newX + sz > vr)
                newX := vr - sz
            if (newY + sz > vb)
                newY := vb - sz
            try FloatingBubbleGUI.Move(newX, newY)
            FloatingBubbleWindowX := newX
            FloatingBubbleWindowY := newY
        }
    } catch {
    }
    FloatingBubbleDragging := false
    SaveFloatingBubblePosition()
    try FloatingBubble_ApplyWebViewBounds()
    catch {
    }
}

InitFloatingBubble() {
}

ShowFloatingBubble() {
    global FloatingBubbleGUI, FloatingBubbleIsVisible, FloatingBubbleWindowX, FloatingBubbleWindowY

    if (FloatingBubbleGUI = 0)
        CreateFloatingBubbleGUI()

    LoadFloatingBubblePosition()
    sz := FloatingBubble_GetSize()
    if (FloatingBubbleWindowX = 0 && FloatingBubbleWindowY = 0) {
        ScreenVirtual_GetBounds(&vl, &vt, &vw, &vh)
        FloatingBubbleWindowX := vl + vw - sz - 16
        FloatingBubbleWindowY := vt + vh - sz - 16
    }

    try FloatingBubbleGUI.Show("x" . FloatingBubbleWindowX . " y" . FloatingBubbleWindowY . " w" . sz . " h" . sz . " NoActivate")
    catch {
    }
    FloatingBubble_ApplyWebViewBounds()
    FloatingBubbleIsVisible := true
    try WebView2_NotifyShown(g_FB_WV2)
    SetTimer(FloatingBubble_PushLogoToWeb, -50)
}

HideFloatingBubble() {
    global FloatingBubbleGUI, FloatingBubbleIsVisible, FloatingBubbleDragging

    if (FloatingBubbleGUI = 0)
        return
    FloatingBubbleDragging := false
    SaveFloatingBubblePosition()
    try WebView2_NotifyHidden(g_FB_WV2)
    try FloatingBubbleGUI.Hide()
    catch {
    }
    FloatingBubbleIsVisible := false
}
