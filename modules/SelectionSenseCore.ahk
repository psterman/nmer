#Requires AutoHotkey v2.0
; 选区感应：~LButton Up 后模拟 ^c 仅更新工具栏（FloatingToolbar_NotifySelectionChange），不打开 Hub。
; HubCapsule：工具栏「新」、Cursor 内双击 Ctrl+C（全局 ~^c）、或 Hub 页内快捷键；选中文本不再拖选自动弹出。

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
global g_SelSense_ClipWaitSec := 0.45
global g_SelSense_HubMousedownX := 0
global g_SelSense_HubMousedownY := 0
global g_SelSense_HubDragActive := false
global g_SelSense_HubDragRefPtrX := 0
global g_SelSense_HubDragRefPtrY := 0
global g_SelSense_HubDragRefWinX := 0
global g_SelSense_HubDragRefWinY := 0
global g_SelSense_UserCopyInProgress := false
global g_SelSense_UserCopyEndTick := 0
global g_SelSense_DoubleCopyHub_LastTick := 0

SelectionSense_HubDragClampToVirtual(&nx, &ny, ww, hh) {
    ScreenVirtual_GetBounds(&vl, &vt, &vw, &vh)
    vr := vl + vw
    vb := vt + vh
    if (nx < vl)
        nx := vl
    if (ny < vt)
        ny := vt
    if (nx + ww > vr)
        nx := vr - ww
    if (ny + hh > vb)
        ny := vb - hh
}

SelectionSense_HubDragApplyBoundsNotify() {
    global g_SelSense_MenuCtrl
    SelectionSense_ApplyMenuBounds()
    try g_SelSense_MenuCtrl.NotifyParentWindowPositionChanged()
    catch as _e {
    }
}

SelectionSense_HubCapsule_IniPath() {
    return (IsSet(ConfigFile) && ConfigFile != "") ? ConfigFile : (A_ScriptDir "\CursorShortcut.ini")
}

SelectionSense_HubCapsule_ReadSavedPos(&outX, &outY, &outOk) {
    outOk := false
    outX := 0
    outY := 0
    cfg := SelectionSense_HubCapsule_IniPath()
    try {
        xs := IniRead(cfg, "WindowPositions", "HubCapsule_X", "")
        ys := IniRead(cfg, "WindowPositions", "HubCapsule_Y", "")
        if (xs = "" || xs = "ERROR" || ys = "" || ys = "ERROR")
            return
        xi := Integer(xs)
        yi := Integer(ys)
        if (Abs(xi) > 40000 || Abs(yi) > 40000)
            return
        outX := xi
        outY := yi
        outOk := true
    } catch as _e {
        outOk := false
    }
}

SelectionSense_HubCapsule_WriteSavedPos() {
    global g_SelSense_MenuGui, g_SelSense_MenuShowingHub
    if !(g_SelSense_MenuGui && g_SelSense_MenuShowingHub)
        return
    try {
        g_SelSense_MenuGui.GetPos(&px, &py)
        cfg := SelectionSense_HubCapsule_IniPath()
        IniWrite(px, cfg, "WindowPositions", "HubCapsule_X")
        IniWrite(py, cfg, "WindowPositions", "HubCapsule_Y")
    } catch as _e {
    }
}

SelectionSense_CopyDelayMsEffective() {
    global g_SelSense_CopyDelayMs
    base := g_SelSense_CopyDelayMs
    extra := 0
    try {
        exe := StrLower(WinGetProcessName("A"))
        if InStr(exe, "cursor") || InStr(exe, "code") || InStr(exe, "electron")
            extra := 35
    } catch as _e {
    }
    return base + extra
}

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
    global g_SelSense_Enabled, g_SelSense_CopyDelayMs, g_SelSense_RequireIBeam, g_SelSense_ClipWaitSec
    cfg := (IsSet(ConfigFile) && ConfigFile != "") ? ConfigFile : (A_ScriptDir "\CursorShortcut.ini")
    try {
        g_SelSense_Enabled := (IniRead(cfg, "SelectionSense", "Enable", "1") != "0")
        g_SelSense_CopyDelayMs := Integer(IniRead(cfg, "SelectionSense", "CopyDelayMs", "55"))
        ; Cursor/VS Code/Electron 常用自定义文本光标，GetCursor 往往不等于系统 IDC_IBEAM，默认不要求 I 形光标
        g_SelSense_RequireIBeam := (IniRead(cfg, "SelectionSense", "RequireIBeam", "0") = "1")
        w := IniRead(cfg, "SelectionSense", "ClipWaitSec", "")
        if (w != "" && w != "ERROR") {
            f := Float(w)
            if (f >= 0.1 && f <= 2.0)
                g_SelSense_ClipWaitSec := f
        }
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
    global g_SelSense_LastFullText, g_SelSense_LastTick, g_SelSense_UserCopyInProgress, g_SelSense_UserCopyEndTick

    if !g_SelSense_Enabled
        return
    if SelectionSense_CursorOverOurUi()
        return
    ; 用户主动 Ctrl+C 后一段时间内跳过模拟 ^c，避免与编辑器内复制/粘贴抢剪贴板
    if (g_SelSense_UserCopyInProgress || (A_TickCount - g_SelSense_UserCopyEndTick < 950))
        return

    clipSaved := ""
    try clipSaved := ClipboardAll()

    try Send("^c")
    catch as e {
        try {
            if (clipSaved != "")
                A_Clipboard := clipSaved
        } catch as _e {
        }
        return
    }

    Sleep(SelectionSense_CopyDelayMsEffective())
    global g_SelSense_ClipWaitSec
    try ClipWait(g_SelSense_ClipWaitSec)
    catch as _e {
    }
    got := ""
    try got := A_Clipboard
    catch as _e {
        got := ""
    }

    text := ""
    try text := String(got)
    catch as _e {
        text := ""
    }
    text := Trim(text, " `t`r`n")
    if (text = "") {
        ; 未读到选区：尽量恢复复制前的剪贴板，避免一次失败的 ^c 污染
        try {
            if (clipSaved != "")
                A_Clipboard := clipSaved
        } catch as _e {
        }
        SelectionSense_ClearLastSelected()
        try FloatingToolbar_NotifySelectionClear()
        catch as _e {
        }
        return
    }

    ; 成功读到选区时：保留当前剪贴板（即本次 ^c 的内容），勿还原 clipSaved。
    ; 否则用户无法在 Cursor 等编辑器里粘贴刚选中的文本，且 Electron 下易表现为剪贴板被清空/异常。

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
    ; 勿用 +E0x80000：未调用 SetLayeredWindowAttributes 时 WS_EX_LAYERED 会导致 WebView2 无法命中鼠标
    g_SelSense_MenuGui := Gui("+AlwaysOnTop -Caption +ToolWindow +Resize +MinSize200x160 -DPIScale", "SelectionMenuHost")
    g_SelSense_MenuGui.BackColor := "1a1a1a"
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

    try ctrl.DefaultBackgroundColor := 0
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
    if (typ = "hub_mousedown") {
        global g_SelSense_HubMousedownX, g_SelSense_HubMousedownY
        g_SelSense_HubMousedownX := msg.Has("x") ? Integer(msg["x"]) : 0
        g_SelSense_HubMousedownY := msg.Has("y") ? Integer(msg["y"]) : 0
        return
    }
    if (typ = "hub_drag_start") {
        global g_SelSense_MenuGui, g_SelSense_MenuCtrl, g_SelSense_HubDragActive
        global g_SelSense_HubDragRefPtrX, g_SelSense_HubDragRefPtrY, g_SelSense_HubDragRefWinX, g_SelSense_HubDragRefWinY
        global g_SelSense_HubMousedownX, g_SelSense_HubMousedownY
        if !g_SelSense_MenuGui
            return
        px := msg.Has("x") ? Integer(msg["x"]) : 0
        py := msg.Has("y") ? Integer(msg["y"]) : 0
        if (px = 0 && py = 0) {
            px := g_SelSense_HubMousedownX
            py := g_SelSense_HubMousedownY
        }
        if (px = 0 && py = 0) {
            CoordMode("Mouse", "Screen")
            MouseGetPos(&px, &py)
        }
        g_SelSense_MenuGui.GetPos(&wx, &wy, &ww, &hh)
        g_SelSense_HubDragRefPtrX := px
        g_SelSense_HubDragRefPtrY := py
        g_SelSense_HubDragRefWinX := wx
        g_SelSense_HubDragRefWinY := wy
        g_SelSense_HubDragActive := true
        return
    }
    if (typ = "hub_drag_move") {
        global g_SelSense_MenuGui, g_SelSense_MenuCtrl, g_SelSense_HubDragActive
        global g_SelSense_HubDragRefPtrX, g_SelSense_HubDragRefPtrY, g_SelSense_HubDragRefWinX, g_SelSense_HubDragRefWinY
        if !g_SelSense_HubDragActive || !g_SelSense_MenuGui
            return
        px := msg.Has("x") ? Integer(msg["x"]) : 0
        py := msg.Has("y") ? Integer(msg["y"]) : 0
        if (px = 0 && py = 0)
            return
        nx := g_SelSense_HubDragRefWinX + (px - g_SelSense_HubDragRefPtrX)
        ny := g_SelSense_HubDragRefWinY + (py - g_SelSense_HubDragRefPtrY)
        g_SelSense_MenuGui.GetPos(, , &ww, &hh)
        SelectionSense_HubDragClampToVirtual(&nx, &ny, ww, hh)
        try g_SelSense_MenuGui.Move(nx, ny)
        SelectionSense_HubDragApplyBoundsNotify()
        return
    }
    if (typ = "hub_drag_end") {
        global g_SelSense_HubDragActive
        g_SelSense_HubDragActive := false
        SelectionSense_HubDragApplyBoundsNotify()
        SelectionSense_HubCapsule_WriteSavedPos()
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
            SetTimer(SelectionSense_ShowMenuNearCursor, -55)
        else
            menuShowRetries := 0
        return
    }
    menuShowRetries := 0

    global g_SelSense_MenuW, g_SelSense_MenuH, g_SelSense_MenuActivateOnShow, g_SelSense_MenuShowingHub
    w := g_SelSense_MenuW
    h := g_SelSense_MenuH
    if (w < 200)
        w := 220
    if (h < 160)
        h := 200
    CoordMode("Mouse", "Screen")
    sx := sy := 0
    savedOk := false
    if (g_SelSense_MenuShowingHub && w >= 350)
        SelectionSense_HubCapsule_ReadSavedPos(&sx, &sy, &savedOk)
    if savedOk {
        x := sx
        y := sy
    } else {
        mx := g_SelSense_MenuAnchorX
        my := g_SelSense_MenuAnchorY
        x := mx + 8
        y := my + 8
    }
    ScreenVirtual_GetBounds(&vl, &vt, &vw, &vh)
    vr := vl + vw
    vb := vt + vh
    if (x + w > vr - 4)
        x := vr - w - 4
    if (y + h > vb - 4)
        y := vb - h - 4
    if (x < vl + 4)
        x := vl + 4
    if (y < vt + 4)
        y := vt + 4

    doActivate := g_SelSense_MenuActivateOnShow
    showOpt := doActivate ? "" : " NoActivate"
    try g_SelSense_MenuGui.Show("x" . x . " y" . y . " w" . w . " h" . h . showOpt)
    g_SelSense_MenuVisible := true
    g_SelSense_MenuActivateOnShow := false
    SelectionSense_ApplyMenuBounds()
    try g_SelSense_MenuCtrl.NotifyParentWindowPositionChanged()
    if doActivate {
        try WinActivate("ahk_id " . g_SelSense_MenuGui.Hwnd)
        try g_SelSense_MenuCtrl.MoveFocus(WebView2.MOVE_FOCUS_REASON.PROGRAMMATIC)
        SetTimer(SelectionSense_MenuNudgeWebViewFocus, -180)
    }

    SetTimer(SelectionSense_DeferredPushMenuText, -45)
}

SelectionSense_MenuNudgeWebViewFocus(*) {
    global g_SelSense_MenuVisible, g_SelSense_MenuGui, g_SelSense_MenuCtrl
    if !(g_SelSense_MenuVisible && g_SelSense_MenuGui && g_SelSense_MenuCtrl)
        return
    try WinActivate("ahk_id " . g_SelSense_MenuGui.Hwnd)
    try g_SelSense_MenuCtrl.MoveFocus(WebView2.MOVE_FOCUS_REASON.PROGRAMMATIC)
    catch as _e {
    }
}

SelectionSense_IsCursorEditorActive() {
    try {
        return StrLower(WinGetProcessName("A")) = "cursor.exe"
    } catch as _e {
        return false
    }
}

; Hub 已显示且当前为 HubCapsule 页时，双击 Ctrl+C 不再重复 Navigate/抢焦点
SelectionSense_HubCapsuleHostIsOpen() {
    global g_SelSense_MenuVisible, g_SelSense_MenuShowingHub
    return !!(g_SelSense_MenuVisible && g_SelSense_MenuShowingHub)
}

SelectionSense_OpenHubAfterDoubleCopyTick(*) {
    global g_SelSense_LastFullText, g_SelSense_LastTick, g_SelSense_LastClipSig, g_SelSense_LastFireTick
    text := ""
    try text := Trim(String(A_Clipboard), " `t`r`n")
    if (text != "") {
        g_SelSense_LastFullText := text
        g_SelSense_LastTick := A_TickCount
        g_SelSense_LastClipSig := StrLen(text) . ":" . SubStr(text, 1, 24)
        g_SelSense_LastFireTick := A_TickCount
        try FloatingToolbar_NotifySelectionChange(text)
        catch as _e {
        }
    }
    SelectionSense_OpenHubCapsuleFromToolbar(false, text)
}

; 悬浮工具栏「新」：打开 HubCapsule（若有近期选区则带入预览）
; useToolbarAnchor：true 时优先锚在工具栏上方；false 时锚在鼠标（供热键等）
; pendingTextOverride：非空时直接作为待推送预览（双击 Ctrl+C 时用剪贴板，避免仅依赖 LButton 选区缓存）
SelectionSense_OpenHubCapsuleFromToolbar(useToolbarAnchor := true, pendingTextOverride := "") {
    global g_SelSense_MenuW, g_SelSense_MenuH, g_SelSense_MenuGui, g_SelSense_MenuWV2, g_SelSense_MenuCtrl
    global g_SelSense_MenuReady, g_SelSense_PendingText, g_SelSense_MenuAnchorX, g_SelSense_MenuAnchorY
    global g_SelSense_NextNavPage, g_SelSense_MenuActivateOnShow, FloatingToolbarGUI, g_SelSense_MenuShowingHub
    global g_SelSense_DoubleCopyHub_LastTick

    g_SelSense_DoubleCopyHub_LastTick := 0
    g_SelSense_MenuW := 420
    g_SelSense_MenuH := 560
    g_SelSense_MenuActivateOnShow := true
    ov := Trim(String(pendingTextOverride))
    if (ov != "")
        g_SelSense_PendingText := ov
    else
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
        SetTimer(SelectionSense_DeferredPushMenuText, -80)
}

SelectionSense_HideMenu() {
    global g_SelSense_MenuGui, g_SelSense_MenuVisible, g_SelSense_MenuShowingHub, g_SelSense_DoubleCopyHub_LastTick
    if (g_SelSense_MenuGui && g_SelSense_MenuVisible && g_SelSense_MenuShowingHub)
        SelectionSense_HubCapsule_WriteSavedPos()
    g_SelSense_DoubleCopyHub_LastTick := 0
    g_SelSense_MenuVisible := false
    try FloatingToolbar_NotifySelectionClear()
    catch as _e {
    }
    if g_SelSense_MenuGui {
        try g_SelSense_MenuGui.Hide()
    }
}

SelectionSense_OnUserCopy(*) {
    global g_SelSense_UserCopyInProgress, g_SelSense_UserCopyEndTick, g_SelSense_DoubleCopyHub_LastTick

    g_SelSense_UserCopyInProgress := true
    g_SelSense_UserCopyEndTick := A_TickCount
    SetTimer(SelectionSense_ClearUserCopyFlag, -780)

    ; Cursor 内双击 Ctrl+C：打开 Hub（已打开且为 HubCapsule 时不处理）
    if !SelectionSense_IsCursorEditorActive()
        return
    if SelectionSense_HubCapsuleHostIsOpen()
        return

    now := A_TickCount
    winMs := 520
    if (g_SelSense_DoubleCopyHub_LastTick > 0 && (now - g_SelSense_DoubleCopyHub_LastTick) <= winMs) {
        g_SelSense_DoubleCopyHub_LastTick := 0
        SetTimer(SelectionSense_OpenHubAfterDoubleCopyTick, -140)
    } else {
        g_SelSense_DoubleCopyHub_LastTick := now
    }
}

SelectionSense_ClearUserCopyFlag(*) {
    global g_SelSense_UserCopyInProgress
    g_SelSense_UserCopyInProgress := false
}

SelectionSense_Init() {
    SelectionSense_LoadIni()
    global g_SelSense_Enabled
    if g_SelSense_Enabled {
        Hotkey("~*LButton Up", SelectionSense_OnLButtonUp, "On")
        Hotkey("~^c", SelectionSense_OnUserCopy, "On")
    } else {
        Hotkey("~*LButton Up", SelectionSense_OnLButtonUp, "Off")
        Hotkey("~^c", SelectionSense_OnUserCopy, "Off")
    }
}
