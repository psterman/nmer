#Requires AutoHotkey v2.0
; 选区感应：~LButton Up + ^c 更新选区与工具栏；不再弹出 SelectionMenu。
; HubCapsule 仅：工具栏「新」或「左键按住并拖动超过阈值」且当前确有选区时打开。

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
; 工具栏打开 Hub 后 WebView 停在 HubCapsule；选中文本应回到 SelectionMenu，否则会误用大窗口页
global g_SelSense_MenuShowingHub := false
global g_SelSense_DragArmed := false
global g_SelSense_DragSX := 0
global g_SelSense_DragSY := 0
global g_SelSense_DragMaxAgeMs := 10000
global g_SelSense_DragThresholdPx := 12

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
    global g_SelSense_Enabled, g_SelSense_CopyDelayMs, g_SelSense_RequireIBeam
    cfg := (IsSet(ConfigFile) && ConfigFile != "") ? ConfigFile : (A_ScriptDir "\CursorShortcut.ini")
    try {
        g_SelSense_Enabled := (IniRead(cfg, "SelectionSense", "Enable", "1") != "0")
        g_SelSense_CopyDelayMs := Integer(IniRead(cfg, "SelectionSense", "CopyDelayMs", "55"))
        ; Cursor/VS Code/Electron 常用自定义文本光标，GetCursor 往往不等于系统 IDC_IBEAM，默认不要求 I 形光标
        g_SelSense_RequireIBeam := (IniRead(cfg, "SelectionSense", "RequireIBeam", "0") = "1")
    } catch as _e {
        g_SelSense_Enabled := true
        g_SelSense_CopyDelayMs := 55
        g_SelSense_RequireIBeam := false
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

SelectionSense_OnLButtonUp(*) {
    SelectionSense_StopDragPoll()
    global g_SelSense_Enabled, g_SelSense_RequireIBeam
    if !g_SelSense_Enabled
        return
    if SelectionSense_CursorOverOurUi()
        return
    if g_SelSense_RequireIBeam && !SelectionSense_IsIBeamCursor()
        return
    SetTimer(SelectionSense_ProcessDeferred, -1)
}

SelectionSense_StopDragPoll(*) {
    global g_SelSense_DragArmed
    g_SelSense_DragArmed := false
    SetTimer(SelectionSense_DragPoll, 0)
}

SelectionSense_OnLButtonDownDragArm(*) {
    global g_SelSense_Enabled, g_SelSense_DragArmed, g_SelSense_DragSX, g_SelSense_DragSY
    global g_SelSense_MenuVisible, g_SelSense_LastTick, g_SelSense_DragMaxAgeMs
    if !g_SelSense_Enabled
        return
    if g_SelSense_MenuVisible
        return
    if SelectionSense_CursorOverOurUi()
        return
    if (Trim(SelectionSense_GetLastSelectedText()) = "")
        return
    if (g_SelSense_LastTick = 0 || (A_TickCount - g_SelSense_LastTick > g_SelSense_DragMaxAgeMs))
        return
    CoordMode("Mouse", "Screen")
    MouseGetPos(&g_SelSense_DragSX, &g_SelSense_DragSY)
    g_SelSense_DragArmed := true
    SetTimer(SelectionSense_DragPoll, 15)
}

SelectionSense_DragPoll(*) {
    global g_SelSense_DragArmed, g_SelSense_DragSX, g_SelSense_DragSY, g_SelSense_DragThresholdPx
    if !g_SelSense_DragArmed {
        SetTimer(SelectionSense_DragPoll, 0)
        return
    }
    if !GetKeyState("LButton", "P") {
        SelectionSense_StopDragPoll()
        return
    }
    if SelectionSense_CursorOverOurUi() {
        SelectionSense_StopDragPoll()
        return
    }
    CoordMode("Mouse", "Screen")
    MouseGetPos(&x, &y)
    dx := x - g_SelSense_DragSX
    dy := y - g_SelSense_DragSY
    thr := g_SelSense_DragThresholdPx
    if (dx * dx + dy * dy < thr * thr)
        return
    g_SelSense_DragArmed := false
    SetTimer(SelectionSense_DragPoll, 0)
    SelectionSense_VerifySelectionAndOpenHubFromDrag()
}

SelectionSense_VerifySelectionAndOpenHubFromDrag() {
    global g_SelSense_Enabled, g_SelSense_CopyDelayMs, g_SelSense_MenuVisible
    global g_SelSense_LastFullText, g_SelSense_LastTick, g_SelSense_LastClipSig, g_SelSense_LastFireTick
    if !g_SelSense_Enabled || g_SelSense_MenuVisible
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
        } catch as _e {
        }
        return
    }
    Sleep(g_SelSense_CopyDelayMs)
    got := ""
    try got := A_Clipboard
    catch as _e {
        got := ""
    }
    try {
        if (clipSaved != "")
            Clipboard := clipSaved
    } catch as _e {
    }
    text := ""
    try text := String(got)
    catch as _e {
        text := ""
    }
    text := Trim(text, " `t`r`n")
    if (text = "")
        return
    g_SelSense_LastFullText := text
    g_SelSense_LastTick := A_TickCount
    g_SelSense_LastClipSig := StrLen(text) . ":" . SubStr(text, 1, 24)
    g_SelSense_LastFireTick := A_TickCount
    FloatingToolbar_NotifySelectionChange(text)
    SelectionSense_OpenHubCapsuleFromToolbar(false)
}

SelectionSense_ProcessDeferred(*) {
    global g_SelSense_Enabled, g_SelSense_CopyDelayMs, g_SelSense_LastClipSig, g_SelSense_LastFireTick
    global g_SelSense_LastFullText, g_SelSense_LastTick

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
    if (text = "") {
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

    FloatingToolbar_NotifySelectionChange(text)
}

SelectionSense_EnsureMenuHost() {
    global g_SelSense_MenuGui, g_SelSense_MenuCtrl, g_SelSense_MenuWV2, g_SelSense_MenuReady

    if g_SelSense_MenuGui
        return

    global g_SelSense_MenuW, g_SelSense_MenuH
    ; +Resize：HubCapsule 右下角拖条依赖 AHK 同步宿主宽高（hub_resize_move / hub_resize_end）
    g_SelSense_MenuGui := Gui("+AlwaysOnTop -Caption +ToolWindow +Resize +MinSize200x160 -DPIScale", "SelectionMenuHost")
    g_SelSense_MenuGui.MarginX := 0
    g_SelSense_MenuGui.MarginY := 0
    g_SelSense_MenuGui.Show("w" . g_SelSense_MenuW . " h" . g_SelSense_MenuH . " Hide")
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
        SelectionSense_HideMenu()
        t2 := msg.Has("text") ? Trim(String(msg["text"])) : ""
        try PromptQuickPad_OpenCaptureDraft(t2, true)
        catch {
        }
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

    SelectionSense_EnsureMenuHost()
    if !g_SelSense_MenuGui
        return

    ; WebView2.create 异步：控件未就绪时延迟重试，避免空白菜单
    if !g_SelSense_MenuCtrl {
        menuShowRetries++
        if (menuShowRetries < 50)
            SetTimer(SelectionSense_ShowMenuNearCursor, -120)
        else
            menuShowRetries := 0
        return
    }
    menuShowRetries := 0

    global g_SelSense_MenuW, g_SelSense_MenuH, g_SelSense_MenuActivateOnShow
    w := g_SelSense_MenuW
    h := g_SelSense_MenuH
    if (w < 200)
        w := 220
    if (h < 160)
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

    showOpt := g_SelSense_MenuActivateOnShow ? "" : " NoActivate"
    try g_SelSense_MenuGui.Show("x" . x . " y" . y . " w" . w . " h" . h . showOpt)
    g_SelSense_MenuVisible := true
    g_SelSense_MenuActivateOnShow := false
    SelectionSense_ApplyMenuBounds()
    try g_SelSense_MenuCtrl.NotifyParentWindowPositionChanged()
    if showOpt = ""
        try WinActivate("ahk_id " . g_SelSense_MenuGui.Hwnd)

    SetTimer(SelectionSense_DeferredPushMenuText, -120)
}

; 悬浮工具栏「新」：打开 HubCapsule（若有近期选区则带入预览）
; useToolbarAnchor：true 时优先锚在工具栏上方；false 为划词拖动打开，锚在鼠标位置
SelectionSense_OpenHubCapsuleFromToolbar(useToolbarAnchor := true) {
    global g_SelSense_MenuW, g_SelSense_MenuH, g_SelSense_MenuGui, g_SelSense_MenuWV2, g_SelSense_MenuCtrl
    global g_SelSense_MenuReady, g_SelSense_PendingText, g_SelSense_MenuAnchorX, g_SelSense_MenuAnchorY
    global g_SelSense_NextNavPage, g_SelSense_MenuActivateOnShow, FloatingToolbarGUI, g_SelSense_MenuShowingHub

    g_SelSense_MenuW := 420
    g_SelSense_MenuH := 560
    g_SelSense_MenuActivateOnShow := true
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
        g_SelSense_MenuReady := false
        g_SelSense_NextNavPage := ""
        try g_SelSense_MenuWV2.Navigate(BuildAppLocalUrl("HubCapsule.html"))
        g_SelSense_MenuShowingHub := true
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
        SetTimer(SelectionSense_DeferredPushMenuText, -160)
}

SelectionSense_HideMenu() {
    global g_SelSense_MenuGui, g_SelSense_MenuVisible
    g_SelSense_MenuVisible := false
    try FloatingToolbar_NotifySelectionClear()
    catch {
    }
    if g_SelSense_MenuGui {
        try g_SelSense_MenuGui.Hide()
    }
}

SelectionSense_Init() {
    SelectionSense_LoadIni()
    global g_SelSense_Enabled
    if g_SelSense_Enabled {
        Hotkey("~*LButton Up", SelectionSense_OnLButtonUp, "On")
        Hotkey("~*LButton", SelectionSense_OnLButtonDownDragArm, "On")
    } else {
        Hotkey("~*LButton Up", SelectionSense_OnLButtonUp, "Off")
        Hotkey("~*LButton", SelectionSense_OnLButtonDownDragArm, "Off")
    }
}
