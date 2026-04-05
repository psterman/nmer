; ======================================================================================================================
; 悬浮工具栏 - WebView2 全量重构版
; 版本: 2.0.0
; 功能:
;   - 整条工具栏由单个 WebView2 渲染，统一赛博绿/橙配色
;   - 左键拖动整窗、滚轮缩放、右键菜单
;   - 7 个功能按钮：搜索、记录、提示词、新提示词、截图、设置、键盘
;   - 搜索按钮支持选区感应呼吸动画和拖放搜索
; ======================================================================================================================

#Requires AutoHotkey v2.0

; ===================== 全局变量 =====================
global FloatingToolbarGUI := 0
global FloatingToolbarIsVisible := false
global FloatingToolbarWindowX := 0
global FloatingToolbarWindowY := 0
global FloatingToolbarScale := 1.0
global FloatingToolbarMinScale := 0.7
global FloatingToolbarMaxScale := 1.5
global FloatingToolbarDragging := false
global FloatingToolbarIsMinimized := false

global g_FTB_WV2_Ctrl := 0
global g_FTB_WV2 := 0
global g_FTB_WV2_Ready := false
global g_FTB_PendingSelection := ""

; ===================== 显示/隐藏悬浮窗 =====================
ShowFloatingToolbar() {
    global FloatingToolbarGUI, FloatingToolbarIsVisible, FloatingToolbarWindowX, FloatingToolbarWindowY

    if (FloatingToolbarIsVisible && FloatingToolbarGUI != 0) {
        return
    }

    FloatingToolbarLoadScale()
    CreateFloatingToolbarGUI()
    LoadFloatingToolbarPosition()

    if (FloatingToolbarWindowX = 0 && FloatingToolbarWindowY = 0) {
        ScreenWidth := SysGet(0)
        ScreenHeight := SysGet(1)
        ToolbarWidth := FloatingToolbarCalculateWidth()
        ToolbarHeight := FloatingToolbarCalculateHeight()
        FloatingToolbarWindowX := ScreenWidth - ToolbarWidth
        FloatingToolbarWindowY := ScreenHeight - ToolbarHeight
    }

    ToolbarWidth := FloatingToolbarCalculateWidth()
    ToolbarHeight := FloatingToolbarCalculateHeight()
    FloatingToolbarGUI.Show("x" . FloatingToolbarWindowX . " y" . FloatingToolbarWindowY . " w" . ToolbarWidth . " h" . ToolbarHeight)
    FloatingToolbarIsVisible := true

    FloatingToolbarApplyRoundedCorners()
    FloatingToolbar_ApplyWebViewBounds()

    SetTimer(FloatingToolbarCheckWindowPosition, 100)
}

HideFloatingToolbar() {
    global FloatingToolbarGUI, FloatingToolbarIsVisible

    if (FloatingToolbarGUI != 0) {
        SaveFloatingToolbarPosition()
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

; ===================== 创建GUI =====================
CreateFloatingToolbarGUI() {
    global FloatingToolbarGUI, g_FTB_WV2_Ctrl, g_FTB_WV2, g_FTB_WV2_Ready, g_FTB_PendingSelection

    if (FloatingToolbarGUI != 0) {
        g_FTB_WV2_Ctrl := 0
        g_FTB_WV2 := 0
        g_FTB_WV2_Ready := false
        g_FTB_PendingSelection := ""
        try FloatingToolbarGUI.Destroy()
        catch {
        }
    }

    FloatingToolbarGUI := Gui("+AlwaysOnTop -Caption +ToolWindow -DPIScale", "悬浮工具栏")
    FloatingToolbarGUI.BackColor := "0a0a0a"
    FloatingToolbarGUI.OnEvent("Close", OnFloatingToolbarClose)

    OnMessage(0x020A, FloatingToolbarWM_MOUSEWHEEL)

    WebView2.create(FloatingToolbarGUI.Hwnd, FloatingToolbar_OnWebViewCreated)
}

; ===================== 圆角边框处理 =====================
FloatingToolbarApplyRoundedCorners() {
    global FloatingToolbarGUI, FloatingToolbarScale

    if (FloatingToolbarGUI = 0) {
        return
    }

    try {
        FloatingToolbarGUI.GetPos(, , &winWidth, &winHeight)
        radius := Round(10 * FloatingToolbarScale)
        hRgn := DllCall("CreateRoundRectRgn"
            , "Int", 0
            , "Int", 0
            , "Int", winWidth
            , "Int", winHeight
            , "Int", radius * 2
            , "Int", radius * 2
            , "Ptr")
        if (hRgn) {
            DllCall("SetWindowRgn"
                , "Ptr", FloatingToolbarGUI.Hwnd
                , "Ptr", hRgn
                , "Int", 1)
        }
    } catch {
    }
}

; ===================== WebView2 回调 =====================
FloatingToolbar_OnWebViewCreated(ctrl) {
    global g_FTB_WV2_Ctrl, g_FTB_WV2, g_FTB_WV2_Ready

    g_FTB_WV2_Ctrl := ctrl
    g_FTB_WV2 := ctrl.CoreWebView2
    g_FTB_WV2_Ready := false

    try ctrl.DefaultBackgroundColor := 0xFF0A0A0A
    try ctrl.IsVisible := true

    FloatingToolbar_ApplyWebViewBounds()

    s := g_FTB_WV2.Settings
    s.AreDefaultContextMenusEnabled := false
    s.IsStatusBarEnabled := false
    s.AreDevToolsEnabled := false

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
    global g_FTB_WV2, g_FTB_WV2_Ready, g_FTB_PendingSelection, FloatingToolbarGUI, FloatingToolbarScale

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
        if (g_FTB_PendingSelection != "") {
            pv := SubStr(String(g_FTB_PendingSelection), 1, 220)
            try WebView_QueuePayload(g_FTB_WV2, Map("type", "SELECTION_CHANGE", "preview", pv))
            g_FTB_PendingSelection := ""
        }
        return
    }

    if (typ = "toolbar_action") {
        action := msg.Has("action") ? String(msg["action"]) : ""
        if (action != "")
            FloatingToolbarExecuteButtonAction(action, 0)
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
        if FloatingToolbarGUI {
            global FloatingToolbarDragging
            FloatingToolbarDragging := true
            PostMessage(0x00A1, 2, 0, FloatingToolbarGUI.Hwnd)
            SetTimer(FloatingToolbarCheckDragEnd, 50)
        }
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
}

; ===================== 执行按钮动作 =====================
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
            try ShowClipboardHistoryPanel()
            catch as err {
                SetCapsLockState("AlwaysOff")
                Sleep(30)
                Send("{CapsLock down}")
                Sleep(30)
                Send("x")
                Sleep(30)
                Send("{CapsLock up}")
                Sleep(30)
                SetCapsLockState("Off")
            }
        case "AIAssistant":
            try ShowPromptQuickPadListOnly()
            catch as err {
                TrayTip("AI选择面板加载失败: " . err.Message, "错误", "Iconx 2")
            }
        case "PromptNew":
            try SelectionSense_OpenHubCapsuleFromToolbar()
            catch as err {
                try TrayTip("无法打开 HubCapsule（需包含 SelectionSenseCore.ahk）: " . err.Message, "新", "Iconx 2")
                catch {
                }
            }
        case "Screenshot":
            try ExecuteScreenshotWithMenu()
            catch as err {
                SetCapsLockState("AlwaysOff")
                Send("{CapsLock down}")
                Sleep(30)
                Send("t")
                Sleep(30)
                Send("{CapsLock up}")
                SetCapsLockState("Off")
            }
        case "Settings":
            FloatingToolbarOpenSettings()
        case "VirtualKeyboard":
            FloatingToolbarActivateVirtualKeyboard()
    }
}

FloatingToolbarActivateVirtualKeyboard() {
    try VK_ToggleEmbedded()
    catch as err {
        try TrayTip("虚拟键盘不可用: " . err.Message, "虚拟键盘", "Iconx 2")
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

; ===================== 滚轮缩放处理 =====================
FloatingToolbarWM_MOUSEWHEEL(wParam, lParam, msg, hwnd) {
    global FloatingToolbarGUI, FloatingToolbarIsVisible

    if (!FloatingToolbarIsVisible || !FloatingToolbarGUI)
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

        ScreenWidth := SysGet(0)
        ScreenHeight := SysGet(1)
        if (newX < 0)
            newX := 0
        if (newY < 0)
            newY := 0
        if (newX + ToolbarWidth > ScreenWidth)
            newX := ScreenWidth - ToolbarWidth
        if (newY + ToolbarHeight > ScreenHeight)
            newY := ScreenHeight - ToolbarHeight

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

; ===================== 拖动检测 =====================
FloatingToolbarCheckDragEnd() {
    global FloatingToolbarDragging, FloatingToolbarWindowX, FloatingToolbarWindowY

    if (!GetKeyState("LButton", "P")) {
        FloatingToolbarDragging := false
        SetTimer(FloatingToolbarCheckDragEnd, 0)
        FloatingToolbarCheckWindowPosition()
    }
}

; ===================== 窗口位置检查与磁吸 =====================
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

            ScreenWidth := SysGet(0)
            ScreenHeight := SysGet(1)
            adjustedX := newX
            adjustedY := newY

            snapDistance := 30
            windowWidth := FloatingToolbarCalculateWidth()
            windowHeight := FloatingToolbarCalculateHeight()

            if (adjustedX < snapDistance)
                adjustedX := 0
            else if (adjustedX + windowWidth > ScreenWidth - snapDistance)
                adjustedX := ScreenWidth - windowWidth

            if (adjustedY < snapDistance)
                adjustedY := 0
            else if (adjustedY + windowHeight > ScreenHeight - snapDistance)
                adjustedY := ScreenHeight - windowHeight

            if (adjustedX < 0)
                adjustedX := 0
            if (adjustedY < 0)
                adjustedY := 0
            if (adjustedX + windowWidth > ScreenWidth)
                adjustedX := ScreenWidth - windowWidth
            if (adjustedY + windowHeight > ScreenHeight)
                adjustedY := ScreenHeight - windowHeight

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

; 右键菜单由主脚本 ShowFloatingToolbarUnifiedContextMenu 提供（深色弹窗样式），避免与 #Include 冲突。

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

; ===================== 窗口关闭事件 =====================
OnFloatingToolbarClose(*) {
    HideFloatingToolbar()
}

; ===================== 位置保存和加载 =====================
SaveFloatingToolbarPosition() {
    global FloatingToolbarGUI, FloatingToolbarWindowX, FloatingToolbarWindowY

    if (FloatingToolbarGUI = 0)
        return

    try {
        FloatingToolbarGUI.GetPos(&x, &y)
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

            ScreenWidth := SysGet(0)
            ScreenHeight := SysGet(1)
            ToolbarWidth := FloatingToolbarCalculateWidth()
            ToolbarHeight := FloatingToolbarCalculateHeight()

            if (FloatingToolbarWindowX < 0 || FloatingToolbarWindowX > ScreenWidth - ToolbarWidth)
                FloatingToolbarWindowX := 0
            if (FloatingToolbarWindowY < 0 || FloatingToolbarWindowY > ScreenHeight - ToolbarHeight)
                FloatingToolbarWindowY := 0
        }
    } catch {
        FloatingToolbarWindowX := 0
        FloatingToolbarWindowY := 0
    }
}

; ===================== 缩放保存和加载 =====================
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
}

; ===================== 计算工具栏宽度和高度 =====================
FloatingToolbarCalculateWidth() {
    global FloatingToolbarScale
    BaseWidth := 380
    return Round(BaseWidth * FloatingToolbarScale)
}

FloatingToolbarCalculateHeight() {
    global FloatingToolbarScale
    BaseHeight := 52
    return Round(BaseHeight * FloatingToolbarScale)
}

; ===================== 最小化到屏幕边缘 =====================
MinimizeFloatingToolbarToEdge() {
    global FloatingToolbarGUI, FloatingToolbarIsVisible, FloatingToolbarIsMinimized
    global FloatingToolbarWindowX, FloatingToolbarWindowY

    if (!FloatingToolbarIsVisible || FloatingToolbarGUI = 0)
        return

    FloatingToolbarGUI.GetPos(&currentX, &currentY, &currentW, &currentH)

    ScreenWidth := SysGet(0)
    ScreenHeight := SysGet(1)

    distLeft := currentX
    distRight := ScreenWidth - (currentX + currentW)
    distTop := currentY
    distBottom := ScreenHeight - (currentY + currentH)

    minDist := distLeft
    targetX := 0
    targetY := currentY

    if (distRight < minDist) {
        minDist := distRight
        targetX := ScreenWidth - currentW
        targetY := currentY
    }
    if (distTop < minDist) {
        minDist := distTop
        targetX := currentX
        targetY := 0
    }
    if (distBottom < minDist) {
        minDist := distBottom
        targetX := currentX
        targetY := ScreenHeight - currentH
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

; ===================== 选区感应联动 =====================
FloatingToolbar_NotifySelectionChange(fullText) {
    global g_FTB_WV2, g_FTB_WV2_Ready, g_FTB_PendingSelection

    pv := SubStr(String(fullText), 1, 220)
    if !(g_FTB_WV2 && g_FTB_WV2_Ready) {
        g_FTB_PendingSelection := String(fullText)
        return
    }
    try WebView_QueuePayload(g_FTB_WV2, Map("type", "SELECTION_CHANGE", "preview", pv))
    catch {
    }
}

FloatingToolbar_NotifySelectionClear() {
    global g_FTB_WV2, g_FTB_WV2_Ready

    if !(g_FTB_WV2 && g_FTB_WV2_Ready)
        return
    try WebView_QueuePayload(g_FTB_WV2, Map("type", "SELECTION_CLEAR"))
    catch {
    }
}

; ===================== 初始化 =====================
InitFloatingToolbar() {
}

; ===================== 根据按钮action获取提示文字 =====================
GetButtonTip(action) {
    switch action {
        case "Search":
            return "搜索记录 (Caps + F)"
        case "Record":
            return "剪贴板历史 (Caps + X)"
        case "AIAssistant":
            return "AI助手 (Ctrl+Shift+B)"
        case "PromptNew":
            return "HubCapsule 摘录 / 新提示词"
        case "Screenshot":
            return "屏幕截图 (Caps + T)"
        case "Settings":
            return "系统设置 (Caps + Q)"
        case "VirtualKeyboard":
            return "虚拟键盘 (Ctrl+Shift+K)"
        default:
            return ""
    }
}
