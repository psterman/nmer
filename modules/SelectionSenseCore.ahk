#Requires AutoHotkey v2.0
; 选区感应：~LButton Up + IBeam + Ctrl+C，联动工具栏 WebView 与选区菜单（依赖主脚本的 WebView2 / Jxon / BuildAppLocalUrl 等）
; 默认忽略「整段为 Windows 路径/多行路径」的剪贴板（资源管理器选文件），见 [SelectionSense] ReactToFilePaths

global g_SelSense_Enabled := true
global g_SelSense_ShowMenu := true
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
global g_SelSense_OutsidePrevLBtn := false
global g_SelSense_OutsidePrevRBtn := false
global g_SelSense_ReactToFilePaths := false

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
    global g_SelSense_Enabled, g_SelSense_ShowMenu, g_SelSense_CopyDelayMs, g_SelSense_RequireIBeam
    global g_SelSense_ReactToFilePaths
    cfg := (IsSet(ConfigFile) && ConfigFile != "") ? ConfigFile : (A_ScriptDir "\CursorShortcut.ini")
    try {
        g_SelSense_Enabled := (IniRead(cfg, "SelectionSense", "Enable", "1") != "0")
        g_SelSense_ShowMenu := (IniRead(cfg, "SelectionSense", "ShowMenu", "1") != "0")
        g_SelSense_CopyDelayMs := Integer(IniRead(cfg, "SelectionSense", "CopyDelayMs", "40"))
        ; Cursor/VS Code/Electron 常用自定义文本光标，GetCursor 往往不等于系统 IDC_IBEAM，默认不要求 I 形光标
        g_SelSense_RequireIBeam := (IniRead(cfg, "SelectionSense", "RequireIBeam", "0") = "1")
        ; 0=在资源管理器等选中文件得到的路径文本时不弹窗、不联动工具栏；1=与普通选中文本相同
        g_SelSense_ReactToFilePaths := (IniRead(cfg, "SelectionSense", "ReactToFilePaths", "0") = "1")
    } catch {
        g_SelSense_Enabled := true
        g_SelSense_ShowMenu := true
        g_SelSense_CopyDelayMs := 40
        g_SelSense_RequireIBeam := false
        g_SelSense_ReactToFilePaths := false
    }
    if (g_SelSense_CopyDelayMs < 20)
        g_SelSense_CopyDelayMs := 20
    if (g_SelSense_CopyDelayMs > 200)
        g_SelSense_CopyDelayMs := 200
}

SelectionSense_IsKnownGuiRoot(hwnd) {
    if !hwnd
        return false
    global FloatingToolbarGUI, g_SCWV_Gui, g_CP_Gui, g_VK_Gui, g_PQP_Gui, g_SelSense_MenuGui
    global AIListPanelGUI, GuiID_ConfigGUI, GuiID_SearchCenter
    if (IsSet(FloatingToolbarGUI) && FloatingToolbarGUI && hwnd = FloatingToolbarGUI.Hwnd)
        return true
    if (IsSet(g_SCWV_Gui) && g_SCWV_Gui && hwnd = g_SCWV_Gui.Hwnd)
        return true
    if (IsSet(g_CP_Gui) && g_CP_Gui && hwnd = g_CP_Gui.Hwnd)
        return true
    if (IsSet(g_VK_Gui) && g_VK_Gui && hwnd = g_VK_Gui.Hwnd)
        return true
    if (IsSet(g_PQP_Gui) && g_PQP_Gui && hwnd = g_PQP_Gui.Hwnd)
        return true
    if (IsSet(g_SelSense_MenuGui) && g_SelSense_MenuGui && hwnd = g_SelSense_MenuGui.Hwnd)
        return true
    if (IsSet(AIListPanelGUI) && AIListPanelGUI && hwnd = AIListPanelGUI.Hwnd)
        return true
    if (IsSet(GuiID_ConfigGUI) && GuiID_ConfigGUI && hwnd = GuiID_ConfigGUI.Hwnd)
        return true
    if (IsSet(GuiID_SearchCenter) && GuiID_SearchCenter && hwnd = GuiID_SearchCenter.Hwnd)
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

SelectionSense_LineLooksLikeWindowsPath(line) {
    L := Trim(line)
    if (L = "")
        return false
    if (SubStr(L, 1, 1) = '"' && SubStr(L, -1) = '"') && (StrLen(L) >= 2)
        L := Trim(SubStr(L, 2, StrLen(L) - 2))
    if RegExMatch(L, "i)^[A-Za-z]:[/\\]")
        return true
    if RegExMatch(L, "^\\\\[^\\]+\\")
        return true
    if RegExMatch(L, "i)^file:///[A-Za-z]:[/\\]")
        return true
    if RegExMatch(L, "i)^file://[^/\\s]+[/\\]")
        return true
    return false
}

; 剪贴板为多行时：仅当每一非空行都像路径时视为「文件路径选区」（资源管理器复制多文件等）
SelectionSense_TextLooksLikeWindowsPaths(text) {
    nonempty := 0
    for line in StrSplit(text, "`n", "`r") {
        L := Trim(line)
        if (L = "")
            continue
        nonempty++
        if !SelectionSense_LineLooksLikeWindowsPath(L)
            return false
    }
    return (nonempty >= 1)
}

SelectionSense_OnLButtonUp(*) {
    global g_SelSense_Enabled, g_SelSense_RequireIBeam
    if !g_SelSense_Enabled
        return
    if SelectionSense_CursorOverOurUi()
        return
    if g_SelSense_RequireIBeam && !SelectionSense_IsIBeamCursor()
        return
    SetTimer(SelectionSense_ProcessDeferred, -1)
}

SelectionSense_ProcessDeferred(*) {
    global g_SelSense_Enabled, g_SelSense_CopyDelayMs, g_SelSense_LastClipSig, g_SelSense_LastFireTick
    global g_SelSense_LastFullText, g_SelSense_LastTick, g_SelSense_ShowMenu, g_SelSense_PendingText
    global g_SelSense_ReactToFilePaths

    if !g_SelSense_Enabled
        return
    if SelectionSense_CursorOverOurUi()
        return

    clipSaved := ""
    try clipSaved := ClipboardAll()

    try Send("^c")
    catch as e {
        try {
            if (clipSaved != "")
                Clipboard := clipSaved
        } catch {
        }
        return
    }

    Sleep(g_SelSense_CopyDelayMs)
    got := ""
    try got := A_Clipboard
    catch {
        got := ""
    }

    try {
        if (clipSaved != "")
            Clipboard := clipSaved
    } catch {
    }

    text := ""
    try text := String(got)
    catch {
        text := ""
    }
    text := Trim(text, " `t`r`n")
    if (text = "")
        return

    if !g_SelSense_ReactToFilePaths && SelectionSense_TextLooksLikeWindowsPaths(text)
        return

    sig := StrLen(text) . ":" . SubStr(text, 1, 24)
    if (sig = g_SelSense_LastClipSig && (A_TickCount - g_SelSense_LastFireTick < 400))
        return
    g_SelSense_LastClipSig := sig
    g_SelSense_LastFireTick := A_TickCount

    g_SelSense_LastFullText := text
    g_SelSense_LastTick := A_TickCount

    FloatingToolbar_NotifySelectionChange(text)

    if g_SelSense_ShowMenu {
        g_SelSense_PendingText := text
        CoordMode("Mouse", "Screen")
        global g_SelSense_MenuAnchorX, g_SelSense_MenuAnchorY
        MouseGetPos(&g_SelSense_MenuAnchorX, &g_SelSense_MenuAnchorY)
        SelectionSense_ShowMenuNearCursor()
    }
}

SelectionSense_EnsureMenuHost() {
    global g_SelSense_MenuGui, g_SelSense_MenuCtrl, g_SelSense_MenuWV2, g_SelSense_MenuReady

    if g_SelSense_MenuGui
        return

    g_SelSense_MenuGui := Gui("+AlwaysOnTop -Caption +ToolWindow -DPIScale", "SelectionMenuHost")
    g_SelSense_MenuGui.MarginX := 0
    g_SelSense_MenuGui.MarginY := 0
    g_SelSense_MenuGui.Show("w220 h200 Hide")
    g_SelSense_MenuGui.OnEvent("Close", (*) => SelectionSense_HideMenu())

    WebView2.create(g_SelSense_MenuGui.Hwnd, SelectionSense_OnMenuWebViewCreated)
}

SelectionSense_OnMenuWebViewCreated(ctrl) {
    global g_SelSense_MenuCtrl, g_SelSense_MenuWV2, g_SelSense_MenuReady

    g_SelSense_MenuCtrl := ctrl
    g_SelSense_MenuWV2 := ctrl.CoreWebView2
    g_SelSense_MenuReady := false

    try ctrl.DefaultBackgroundColor := 0xFF0A0A0A
    try ctrl.IsVisible := true

    SelectionSense_ApplyMenuBounds()

    s := g_SelSense_MenuWV2.Settings
    s.AreDefaultContextMenusEnabled := false
    s.IsStatusBarEnabled := false
    s.AreDevToolsEnabled := false

    g_SelSense_MenuWV2.add_WebMessageReceived(SelectionSense_OnMenuWebMessage)
    try ApplyUnifiedWebViewAssets(g_SelSense_MenuWV2)
    g_SelSense_MenuWV2.Navigate(BuildAppLocalUrl("SelectionMenu.html"))
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
    try g_SelSense_MenuCtrl.Bounds := rc
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
        global g_SelSense_MenuReady, g_SelSense_MenuVisible, g_SelSense_PendingText
        g_SelSense_MenuReady := true
        if g_SelSense_MenuVisible
            SelectionSense_PushMenuText(g_SelSense_PendingText)
        return
    }
    txt := msg.Has("text") ? String(msg["text"]) : ""

    if (typ = "selection_menu_search") {
        SelectionSense_HideMenu()
        if (Trim(txt) != "")
            SearchCenter_SetInputText(txt)
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
    }
}

SelectionSense_PushMenuText(text) {
    global g_SelSense_MenuWV2, g_SelSense_MenuReady
    if !(g_SelSense_MenuWV2 && g_SelSense_MenuReady)
        return
    WebView_QueuePayload(g_SelSense_MenuWV2, Map("type", "selection_menu_init", "text", String(text)))
}

SelectionSense_ShowMenuNearCursor() {
    static menuShowRetries := 0
    global g_SelSense_MenuGui, g_SelSense_MenuVisible, g_SelSense_PendingText
    global g_SelSense_MenuAnchorX, g_SelSense_MenuAnchorY, g_SelSense_MenuCtrl
    global g_SelSense_OutsidePrevLBtn, g_SelSense_OutsidePrevRBtn

    SelectionSense_EnsureMenuHost()
    if !g_SelSense_MenuGui
        return

    ; WebView2.create 异步：控件未就绪时延迟重试，避免空白菜单
    if !g_SelSense_MenuCtrl {
        menuShowRetries++
        if (menuShowRetries < 50)
            SetTimer(SelectionSense_ShowMenuNearCursor, -70)
        else
            menuShowRetries := 0
        return
    }
    menuShowRetries := 0

    w := 220
    h := 200
    CoordMode("Mouse", "Screen")
    mx := g_SelSense_MenuAnchorX
    my := g_SelSense_MenuAnchorY
    x := mx + 8
    y := my + 8
    ScreenW := SysGet(0)
    ScreenH := SysGet(1)
    if (x + w > ScreenW - 4)
        x := ScreenW - w - 4
    if (y + h > ScreenH - 4)
        y := ScreenH - h - 4
    if (x < 4)
        x := 4
    if (y < 4)
        y := 4

    try g_SelSense_MenuGui.Show("x" . x . " y" . y . " w" . w . " h" . h . " NoActivate")
    g_SelSense_MenuVisible := true
    g_SelSense_OutsidePrevLBtn := GetKeyState("LButton", "P")
    g_SelSense_OutsidePrevRBtn := GetKeyState("RButton", "P")
    SelectionSense_ApplyMenuBounds()
    try g_SelSense_MenuCtrl.NotifyParentWindowPositionChanged()

    SetTimer(SelectionSense_DeferredPushMenuText, -80)
    SetTimer(SelectionSense_CheckClickOutside, 25)
}

SelectionSense_DeferredPushMenuText(*) {
    global g_SelSense_PendingText, g_SelSense_MenuReady, g_SelSense_MenuWV2
    if !g_SelSense_MenuWV2
        return
    if g_SelSense_MenuReady
        SelectionSense_PushMenuText(g_SelSense_PendingText)
    else
        SetTimer(SelectionSense_DeferredPushMenuText, -100)
}

SelectionSense_CheckClickOutside(*) {
    global g_SelSense_MenuGui, g_SelSense_MenuVisible
    global g_SelSense_OutsidePrevLBtn, g_SelSense_OutsidePrevRBtn

    if !g_SelSense_MenuVisible {
        SetTimer(SelectionSense_CheckClickOutside, 0)
        return
    }

    if !g_SelSense_MenuGui {
        SetTimer(SelectionSense_CheckClickOutside, 0)
        return
    }

    lDown := GetKeyState("LButton", "P")
    rDown := GetKeyState("RButton", "P")
    CoordMode("Mouse", "Screen")
    MouseGetPos(&mx, &my)
    try {
        WinGetPos(&wx, &wy, &ww, &wh, "ahk_id " . g_SelSense_MenuGui.Hwnd)
        outside := (mx < wx || mx > wx + ww || my < wy || my > wy + wh)
        ; 用「刚按下」边沿检测，避免 25~50ms 轮询错过极短的左键点击
        if (outside && ((lDown && !g_SelSense_OutsidePrevLBtn) || (rDown && !g_SelSense_OutsidePrevRBtn))) {
            SelectionSense_HideMenu()
            return
        }
    } catch {
    }
    g_SelSense_OutsidePrevLBtn := lDown
    g_SelSense_OutsidePrevRBtn := rDown
}

SelectionSense_HideMenu() {
    global g_SelSense_MenuGui, g_SelSense_MenuVisible
    global g_SelSense_OutsidePrevLBtn, g_SelSense_OutsidePrevRBtn
    SetTimer(SelectionSense_CheckClickOutside, 0)
    g_SelSense_MenuVisible := false
    g_SelSense_OutsidePrevLBtn := false
    g_SelSense_OutsidePrevRBtn := false
    try FloatingToolbar_NotifySelectionClear()
    catch {
    }
    if g_SelSense_MenuGui {
        try g_SelSense_MenuGui.Hide()
    }
}

; 与剪贴板/搜索中心等一并预热，首次选区弹出不必再等 WebView2 创建
SelectionSense_WarmupMenuHost(*) {
    SelectionSense_EnsureMenuHost()
}

SelectionSense_Init() {
    SelectionSense_LoadIni()
    global g_SelSense_Enabled
    if g_SelSense_Enabled
        Hotkey("~*LButton Up", SelectionSense_OnLButtonUp, "On")
    else
        Hotkey("~*LButton Up", SelectionSense_OnLButtonUp, "Off")
}
