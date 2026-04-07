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
global FloatingToolbarDragging := false
global FloatingToolbar_DragOriginScreenX := 0
global FloatingToolbar_DragOriginScreenY := 0
global FloatingToolbar_DragOriginWinX := 0
global FloatingToolbar_DragOriginWinY := 0
global FloatingToolbarIsMinimized := false
global FloatingToolbarChatDrawerOpen := false
global FloatingToolbarChatDrawerWidth := 620
global FloatingToolbarChatDrawerHeight := 720
global FloatingToolbarLastClosedX := 0
global FloatingToolbarLastClosedY := 0

global g_FTB_WV2_Ctrl := 0
global g_FTB_WV2 := 0
global g_FTB_WV2_Ready := false
global g_FTB_WV2_FrameReady := false
global g_FTB_PendingSelection := ""
global g_FTB_UI_Ready := false
global g_FTB_WaitingUiFinishedReveal := false

; ===================== 鏄剧ず/闅愯棌鎮诞绐?=====================
ShowFloatingToolbar() {
    global FloatingToolbarGUI, FloatingToolbarIsVisible, FloatingToolbarWindowX, FloatingToolbarWindowY
    global g_FTB_UI_Ready, g_FTB_WaitingUiFinishedReveal

    if (FloatingToolbarIsVisible && FloatingToolbarGUI != 0) {
        return
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

    if (g_FTB_UI_Ready) {
        FloatingToolbarGUI.Show("x" . FloatingToolbarWindowX . " y" . FloatingToolbarWindowY . " w" . ToolbarWidth . " h" . ToolbarHeight)
        FloatingToolbarIsVisible := true
        FloatingToolbarApplyRoundedCorners()
        FloatingToolbar_ApplyWebViewBounds()
        SetTimer(FloatingToolbarCheckWindowPosition, 100)
        return
    }

    FloatingToolbarGUI.Show("x" . FloatingToolbarWindowX . " y" . FloatingToolbarWindowY . " w" . ToolbarWidth . " h" . ToolbarHeight . " Hide")
    g_FTB_WaitingUiFinishedReveal := true
    FloatingToolbarApplyRoundedCorners()
    FloatingToolbar_ApplyWebViewBounds()

    SetTimer(FloatingToolbarCheckWindowPosition, 100)
}

HideFloatingToolbar() {
    global FloatingToolbarGUI, FloatingToolbarIsVisible, g_FTB_WaitingUiFinishedReveal

    if (FloatingToolbarGUI != 0) {
        SaveFloatingToolbarPosition()
        g_FTB_WaitingUiFinishedReveal := false
        FloatingToolbarGUI.Hide()
        FloatingToolbarIsVisible := false
        SetTimer(FloatingToolbarCheckWindowPosition, 0)
    }
}

ToggleFloatingToolbar() {
    global FloatingToolbarIsVisible

    if (FloatingToolbarIsVisible) {
        HideFloatingToolbar()
    } else {
        ShowFloatingToolbar()
    }
}

; ===================== 鍒涘缓GUI =====================
CreateFloatingToolbarGUI() {
    global FloatingToolbarGUI, g_FTB_WV2_Ctrl, g_FTB_WV2, g_FTB_WV2_Ready, g_FTB_PendingSelection
    global g_FTB_UI_Ready, g_FTB_WaitingUiFinishedReveal
    global WebView2

    if (FloatingToolbarGUI != 0) {
        g_FTB_WV2_Ctrl := 0
        g_FTB_WV2 := 0
        g_FTB_WV2_Ready := false
        g_FTB_WV2_FrameReady := false
        g_FTB_PendingSelection := ""
        g_FTB_UI_Ready := false
        g_FTB_WaitingUiFinishedReveal := false
        try FloatingToolbarGUI.Destroy()
        catch as _e {
        }
    }

    FloatingToolbarGUI := Gui("+AlwaysOnTop -Caption +ToolWindow -DPIScale +E0x02000000", "Floating Toolbar")
    ; 与 FloatingToolbarStrip 工具栏底色 #0a0a0a 一致，避免圆角外缘露色
    FloatingToolbarGUI.BackColor := "0a0a0a"
    FloatingToolbarGUI.OnEvent("Close", OnFloatingToolbarClose)

    OnMessage(0x020A, FloatingToolbarWM_MOUSEWHEEL)

    WebView2.create(FloatingToolbarGUI.Hwnd, FloatingToolbar_OnWebViewCreated)
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
    global g_FTB_WV2_Ctrl, g_FTB_WV2, g_FTB_WV2_Ready, g_FTB_WV2_FrameReady

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
    s.IsStatusBarEnabled := false
    s.AreDevToolsEnabled := false

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

FloatingToolbar_OnWebMessage(sender, args) {
    global g_FTB_WV2, g_FTB_WV2_Ready, g_FTB_WV2_FrameReady, g_FTB_PendingSelection, FloatingToolbarGUI, FloatingToolbarScale

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

    if (typ = "toolbar_ready") {
        g_FTB_WV2_Ready := true
        FloatingToolbar_ApplyWebViewBounds()
        SetTimer(FloatingToolbar_PushLogoToWeb, -10)
        try WebView_QueuePayload(g_FTB_WV2, Map("type", "set_scale", "scale", FloatingToolbarScale))
        FloatingToolbar_FlushPendingSelectionIfReady()
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

        g_FTB_WaitingUiFinishedReveal := false

        tw := FloatingToolbarCalculateWidth()
        th := FloatingToolbarCalculateHeight()
        try FloatingToolbarGUI.Move(FloatingToolbarWindowX, FloatingToolbarWindowY, tw, th)
        catch as _e {
        }

        okAnim := false
        try okAnim := DllCall("user32\AnimateWindow", "Ptr", FloatingToolbarGUI.Hwnd, "UInt", 200, "UInt", 0x20010, "Int")
        catch as _e2 {
            okAnim := false
        }
        if !okAnim {
            try FloatingToolbarGUI.Show("x" . FloatingToolbarWindowX . " y" . FloatingToolbarWindowY . " w" . tw . " h" . th)
            catch as _e3 {
            }
        }

        FloatingToolbarIsVisible := true
        FloatingToolbarApplyRoundedCorners()
        FloatingToolbar_ApplyWebViewBounds()
        return
    }

    if (typ = "toolbar_action") {
        action := msg.Has("action") ? String(msg["action"]) : ""
        if (action != "")
            FloatingToolbarExecuteButtonAction(action, 0)
        return
    }

    if (typ = "toolbar_toggle_action") {
        action := msg.Has("action") ? String(msg["action"]) : ""
        if (action != "")
            FloatingToolbarToggleButtonAction(action)
        return
    }

    if (typ = "toolbar_search_click") {
        try Func("SelectionSense_OnToolbarSearchClick").Call()
        catch {
            try ShowSearchCenter()
            catch {
            }
        }
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

    if (typ = "drag_host") {
        global FloatingToolbarGUI, FloatingToolbarDragging
        global FloatingToolbar_DragOriginScreenX, FloatingToolbar_DragOriginScreenY
        global FloatingToolbar_DragOriginWinX, FloatingToolbar_DragOriginWinY
        if !FloatingToolbarGUI
            return
        try FloatingToolbarGUI.GetPos(&FloatingToolbar_DragOriginWinX, &FloatingToolbar_DragOriginWinY)
        catch as _e {
            return
        }
        CoordMode("Mouse", "Screen")
        MouseGetPos(&FloatingToolbar_DragOriginScreenX, &FloatingToolbar_DragOriginScreenY)
        FloatingToolbarDragging := true
        ; 更高频率轮询鼠标，拖动更跟手（WebView2 内拖动依赖宿主轮询）
        SetTimer(FloatingToolbar_DoDrag, 1)
        return
    }

    if (typ = "wheel") {
        delta := msg.Has("delta") ? Integer(msg["delta"]) : 0
        if (delta != 0)
            FloatingToolbarApplyWheelDelta(delta)
        return
    }

    if (typ = "context_menu") {
        x := msg.Has("x") ? Integer(msg["x"]) : 0
        y := msg.Has("y") ? Integer(msg["y"]) : 0
        ShowFloatingToolbarUnifiedContextMenu(x, y)
        return
    }

    if (typ = "drawer_state") {
        open := msg.Has("open") && !!msg["open"]
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
    if (!FloatingToolbarGUI || !FloatingToolbarIsVisible)
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
    SaveFloatingToolbarPosition()
}

; ===================== 鎵ц鎸夐挳鍔ㄤ綔 =====================
; WebView2 WebMessageReceived 须尽快返回；ExecuteScreenshotWithMenu 含长 Sleep 与剪贴板轮询，
; 在回调内同步调用会阻塞 WebView 消息泵，导致工具栏卡死且截图助手无法弹出。
FloatingToolbar_DeferredScreenshot(*) {
    global FloatingToolbarIsVisible

    wasVisible := !!FloatingToolbarIsVisible

    try {
        if (wasVisible) {
            HideFloatingToolbar()
            Sleep(120)
        }
        ExecuteScreenshotWithMenu()
    } catch as err {
        SetCapsLockState("AlwaysOff")
        Send("{CapsLock down}")
        Sleep(30)
        Send("t")
        Sleep(30)
        Send("{CapsLock up}")
        SetCapsLockState("Off")
    } finally {
        if (wasVisible)
            SetTimer(ShowFloatingToolbar, -120)
    }
}

FloatingToolbarExecuteButtonAction(action, buttonHwnd) {
    switch action {
        case "Search":
            try ShowSearchCenter()
            catch as err {
                SetCapsLockState("AlwaysOff")
                Send("{CapsLock down}")
                Sleep(30)
                Send("f")
                Sleep(30)
                Send("{CapsLock up}")
                SetCapsLockState("Off")
            }
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

FloatingToolbarToggleButtonAction(action) {
    global GuiID_SearchCenter, GuiID_ConfigGUI
    switch action {
        case "Search":
            try {
                if (IsSet(SCWV_IsVisible) && SCWV_IsVisible()) {
                    SCWV_Hide(true)
                    return
                }
            } catch {
            }
            try {
                if (GuiID_SearchCenter != 0) {
                    SearchCenterCloseHandler()
                    return
                }
            } catch {
            }
            FloatingToolbarExecuteButtonAction(action, 0)
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
            try {
                if (PQP_IsVisible()) {
                    PQP_Hide()
                    return
                }
            } catch {
            }
            FloatingToolbarExecuteButtonAction(action, 0)
        case "Settings":
            try {
                if (GuiID_ConfigGUI != 0) {
                    CloseConfigGUI()
                    return
                }
            } catch {
            }
            FloatingToolbarExecuteButtonAction(action, 0)
        default:
            ; 其他动作维持原行为（如 Screenshot、VirtualKeyboard 自身已有切换语义）
            FloatingToolbarExecuteButtonAction(action, 0)
    }
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

    if (!FloatingToolbarIsVisible || !FloatingToolbarGUI)
        return
    ; 抽屉展开时由页面内滚动，不在此用滚轮缩放整窗
    if (FloatingToolbarChatDrawerOpen)
        return

    MouseGetPos(&mx, &my)
    FloatingToolbarGUI.GetPos(&wx, &wy, &ww, &wh)
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

        if g_FTB_WV2 {
            try WebView_QueuePayload(g_FTB_WV2, Map("type", "set_scale", "scale", newScale))
        }

        FloatingToolbarSaveScale()
        SaveFloatingToolbarPosition()
    }
}

; ===================== 鎷栧姩锛圵ebView2 瀹㈡埛鍖?PostMessage HTCAPTION 涓嶅彲闈狅紝鐢ㄦ墜鍔?Move锛?====================
FloatingToolbar_DoDrag(*) {
    global FloatingToolbarGUI, FloatingToolbarDragging, FloatingToolbarWindowX, FloatingToolbarWindowY
    global FloatingToolbar_DragOriginScreenX, FloatingToolbar_DragOriginScreenY
    global FloatingToolbar_DragOriginWinX, FloatingToolbar_DragOriginWinY

    if !(FloatingToolbarDragging && FloatingToolbarGUI) {
        SetTimer(FloatingToolbar_DoDrag, 0)
        return
    }
    if !GetKeyState("LButton", "P") {
        FloatingToolbarDragging := false
        SetTimer(FloatingToolbar_DoDrag, 0)
        FloatingToolbarCheckWindowPosition()
        SaveFloatingToolbarPosition()
        return
    }
    CoordMode("Mouse", "Screen")
    MouseGetPos(&mx, &my)
    newX := FloatingToolbar_DragOriginWinX + (mx - FloatingToolbar_DragOriginScreenX)
    newY := FloatingToolbar_DragOriginWinY + (my - FloatingToolbar_DragOriginScreenY)
    ToolbarWidth := FloatingToolbarCalculateWidth()
    ToolbarHeight := FloatingToolbarCalculateHeight()
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
    try FloatingToolbarGUI.Move(newX, newY)
    FloatingToolbarWindowX := newX
    FloatingToolbarWindowY := newY
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

    if g_FTB_WV2 {
        try WebView_QueuePayload(g_FTB_WV2, Map("type", "set_scale", "scale", 1.0))
    }

    FloatingToolbarSaveScale()
    SaveFloatingToolbarPosition()
}

OnFloatingToolbarContextMenu(*) {
    CoordMode("Mouse", "Screen")
    MouseGetPos(&mx, &my)
    ShowFloatingToolbarUnifiedContextMenu(mx, my)
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

; ===================== 璁＄畻宸ュ叿鏍忓搴﹀拰楂樺害 =====================
FloatingToolbarCalculateWidth() {
    global FloatingToolbarScale, FloatingToolbarChatDrawerOpen, FloatingToolbarChatDrawerWidth
    BaseWidth := 380
    if (FloatingToolbarChatDrawerOpen)
        return Round(Max(BaseWidth, FloatingToolbarChatDrawerWidth) * FloatingToolbarScale)
    return Round(BaseWidth * FloatingToolbarScale)
}

FloatingToolbarCalculateHeight() {
    global FloatingToolbarScale, FloatingToolbarChatDrawerOpen, FloatingToolbarChatDrawerHeight
    ; HTML 缁撴瀯涓?52px logo + 涓婁笅鍚?6px padding锛屽洜姝ゅ熀鍑嗛珮搴﹀繀椤绘槸 64
    BaseHeight := 64
    if FloatingToolbarChatDrawerOpen {
        ScreenVirtual_GetBounds(&vl, &vt, &vw, &vh)
        return vh
    }
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

; ===================== 鍒濆鍖?=====================
InitFloatingToolbar() {
}

; ===================== 鏍规嵁鎸夐挳action鑾峰彇鎻愮ず鏂囧瓧 =====================
GetButtonTip(action) {
    switch action {
        case "Search":
            return "鎼滅储璁板綍 (Caps + F)"
        case "Record":
            return "鏂板壀璐存澘 (WebView2 路 FTS5)"
        case "AIAssistant":
            return "AI鍔╂墜 (Ctrl+Shift+B)"
        case "PromptNew":
            return "HubCapsule 鎽樺綍 / 鏂版彁绀鸿瘝"
        case "Screenshot":
            return "灞忓箷鎴浘 (Caps + T)"
        case "Settings":
            return "绯荤粺璁剧疆 (Caps + Q)"
        case "VirtualKeyboard":
            return "铏氭嫙閿洏 (Ctrl+Shift+K)"
        default:
            return ""
    }
}


