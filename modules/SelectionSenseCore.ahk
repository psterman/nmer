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
global g_SelSense_HubCopyTriggerMode := "capslock"
; HubCapsule：堆叠选择/推送（供 CapsLock+C/V）
global g_HubCapsule_SelectedText := ""
global g_SelSense_PendingHubSegments := []  ; Hub 未 ready 时暂存待 push 的文本段
; 与主脚本 CapsLockCopy 共用：Send(^c) 期间为 true，~^c 须跳过以免读到恢复后的旧剪贴板
global CapsLockCopyInProgress := false

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

; 保存的左上角 + 当前窗口尺寸是否仍落在虚拟屏幕内（避免多显示器/分辨率变化后窗口“在屏外”）
SelectionSense_HubSavedRectIsOnScreen(sx, sy, ww, hh) {
    if (ww < 1 || hh < 1)
        return false
    ScreenVirtual_GetBounds(&vl, &vt, &vw, &vh)
    vr := vl + vw
    vb := vt + vh
    if (sx >= vr || sx + ww <= vl)
        return false
    if (sy >= vb || sy + hh <= vt)
        return false
    return true
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
    global g_SelSense_Enabled, g_SelSense_CopyDelayMs, g_SelSense_RequireIBeam, g_SelSense_ClipWaitSec, g_SelSense_HubCopyTriggerMode
    cfg := (IsSet(ConfigFile) && ConfigFile != "") ? ConfigFile : (A_ScriptDir "\CursorShortcut.ini")
    try {
        g_SelSense_Enabled := (IniRead(cfg, "SelectionSense", "Enable", "1") != "0")
        g_SelSense_CopyDelayMs := Integer(IniRead(cfg, "SelectionSense", "CopyDelayMs", "55"))
        ; Cursor/VS Code/Electron 常用自定义文本光标，GetCursor 往往不等于系统 IDC_IBEAM，默认不要求 I 形光标
        g_SelSense_RequireIBeam := (IniRead(cfg, "SelectionSense", "RequireIBeam", "0") = "1")
        mode := Trim(StrLower(IniRead(cfg, "SelectionSense", "HubCopyTriggerMode", "capslock")))
        ; 兼容旧值 single：迁移到 capslock
        g_SelSense_HubCopyTriggerMode := (mode = "double") ? "double" : "capslock"
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
        g_SelSense_HubCopyTriggerMode := "capslock"
    }
    if (g_SelSense_CopyDelayMs < 20)
        g_SelSense_CopyDelayMs := 20
    if (g_SelSense_CopyDelayMs > 200)
        g_SelSense_CopyDelayMs := 200
}

SelectionSense_SetHubCopyTriggerMode(mode) {
    global g_SelSense_HubCopyTriggerMode
    m := Trim(StrLower(String(mode)))
    g_SelSense_HubCopyTriggerMode := (m = "double") ? "double" : "capslock"
    cfg := (IsSet(ConfigFile) && ConfigFile != "") ? ConfigFile : (A_ScriptDir "\CursorShortcut.ini")
    try IniWrite(g_SelSense_HubCopyTriggerMode, cfg, "SelectionSense", "HubCopyTriggerMode")
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

global g_SelSense_LButtonDownX := 0
global g_SelSense_LButtonDownY := 0
global g_SelSense_LButtonDownTick := 0
global g_SelSense_LButtonClicks := 0

SelectionSense_OnLButtonDown(*) {
    global g_SelSense_LButtonDownX, g_SelSense_LButtonDownY, g_SelSense_LButtonDownTick, g_SelSense_LButtonClicks
    CoordMode("Mouse", "Screen")
    MouseGetPos(&g_SelSense_LButtonDownX, &g_SelSense_LButtonDownY)
    if (A_TickCount - g_SelSense_LButtonDownTick < 400) {
        g_SelSense_LButtonClicks += 1
    } else {
        g_SelSense_LButtonClicks := 1
    }
    g_SelSense_LButtonDownTick := A_TickCount
}

SelectionSense_OnLButtonUp(*) {
    global g_SelSense_Enabled, g_SelSense_RequireIBeam
    global g_SelSense_LButtonDownX, g_SelSense_LButtonDownY, g_SelSense_LButtonClicks, g_SelSense_LButtonDownTick
    if !g_SelSense_Enabled
        return
    if SelectionSense_CursorOverOurUi()
        return
    if g_SelSense_RequireIBeam && !SelectionSense_IsIBeamCursor()
        return
        
    CoordMode("Mouse", "Screen")
    MouseGetPos(&upX, &upY)
    distX := Abs(upX - g_SelSense_LButtonDownX)
    distY := Abs(upY - g_SelSense_LButtonDownY)
    
    isDrag := (distX > 3 || distY > 3)
    isMultiClick := (g_SelSense_LButtonClicks >= 2 && (A_TickCount - g_SelSense_LButtonDownTick < 400))
    
    if !(isDrag || isMultiClick) {
        try FloatingToolbar_NotifySelectionClear()
        return
    }

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

    ; 关闭选区自动复制：不再模拟 ^c，也不干预剪贴板
    SelectionSense_ClearLastSelected()
    try FloatingToolbar_NotifySelectionClear()
    catch as _e {
    }
    return
}

/*
    clipSaved := ""
    try clipSaved := ClipboardAll()

    A_Clipboard := ""
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
*/

SelectionSense_EnsureMenuHost() {
    global g_SelSense_MenuGui, g_SelSense_MenuCtrl, g_SelSense_MenuWV2, g_SelSense_MenuReady

    if g_SelSense_MenuGui
        return

    global g_SelSense_MenuW, g_SelSense_MenuH
    ; +Resize：HubCapsule 右下角拖条依赖 AHK 同步宿主宽高（hub_resize_move / hub_resize_end）
    ; 勿用 +E0x80000：未调用 SetLayeredWindowAttributes 时 WS_EX_LAYERED 会导致 WebView2 无法命中鼠标
    g_SelSense_MenuGui := Gui("+AlwaysOnTop +Resize +MinSize200x160 +MinimizeBox +MaximizeBox -DPIScale", "SelectionMenuHost")
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
        global g_SelSense_MenuReady, g_SelSense_MenuVisible, g_SelSense_PendingText, g_SelSense_HubCopyTriggerMode, g_SelSense_MenuWV2
        global g_SelSense_PendingHubSegments, g_SelSense_MenuShowingHub
        g_SelSense_MenuReady := true
        try WebView_QueuePayload(g_SelSense_MenuWV2, Map("type", "hub_preview_state", "copyTriggerMode", g_SelSense_HubCopyTriggerMode))
        ; 注意：SelectionMenu / HubCapsule 都会发 selection_menu_ready。
        ; 只有当前页为 HubCapsule 时，才允许 flush 待推送段落，否则会“发到错误页面”导致丢失。
        if g_SelSense_MenuShowingHub
            SelectionSense_HubCapsule_FlushPendingSegments()
        if g_SelSense_MenuVisible {
            SelectionSense_PushMenuText(g_SelSense_PendingText)
            ; HubCapsule：再发 hub_preview，避免仅 selection_menu_init 在竞态下未命中
            if g_SelSense_MenuShowingHub && Trim(String(g_SelSense_PendingText)) != ""
                SelectionSense_PushHubPreviewText(g_SelSense_PendingText)
        }
        return
    }
    if (typ = "hub_ready") {
        ; HubCapsule 明确就绪：补发待推送段落
        SelectionSense_HubCapsule_FlushPendingSegments()
        return
    }

    txt := msg.Has("text") ? String(msg["text"]) : ""

    if (typ = "hub_stack_selected") {
        global g_HubCapsule_SelectedText
        t2 := msg.Has("text") ? String(msg["text"]) : ""
        g_HubCapsule_SelectedText := t2
        return
    }

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
    if (typ = "hub_set_copy_trigger_mode") {
        global g_SelSense_HubCopyTriggerMode, g_SelSense_MenuWV2
        mode := msg.Has("mode") ? String(msg["mode"]) : "capslock"
        SelectionSense_SetHubCopyTriggerMode(mode)
        try WebView_QueuePayload(g_SelSense_MenuWV2, Map("type", "hub_preview_state", "copyTriggerMode", g_SelSense_HubCopyTriggerMode))
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

SelectionSense_HubCapsule_FlushPendingSegments() {
    global g_SelSense_MenuWV2, g_SelSense_MenuReady, g_SelSense_MenuShowingHub, g_SelSense_PendingHubSegments
    if !(g_SelSense_MenuWV2 && g_SelSense_MenuReady && g_SelSense_MenuShowingHub)
        return
    try {
        if (g_SelSense_PendingHubSegments is Array) && (g_SelSense_PendingHubSegments.Length > 0) {
            for _, seg in g_SelSense_PendingHubSegments {
                if (Trim(String(seg)) != "")
                    WebView_QueuePayload(g_SelSense_MenuWV2, Map("type", "push_segment", "text", String(seg)))
            }
            g_SelSense_PendingHubSegments := []
        }
    } catch as _e {
    }
}

; ===================== HubCapsule：从外部推送一段文本入栈 =====================
; 设计：HubCapsule 可能被预热但未 ready，先缓存，待 selection_menu_ready 再补发。
SelectionSense_HubCapsule_PushSegmentText(text) {
    global g_SelSense_MenuGui, g_SelSense_MenuWV2, g_SelSense_MenuReady, g_SelSense_MenuShowingHub
    global g_SelSense_PendingHubSegments, g_SelSense_NextNavPage

    t := Trim(String(text), " `t`r`n")
    if (t = "")
        return false

    ; 需求：CapsLock+C 复制后要“看得见”——确保 HubCapsule 宿主窗口会被拉起显示（WebView 未就绪会自动重试）
    try {
        global g_SelSense_MenuW, g_SelSense_MenuH, g_SelSense_MenuActivateOnShow, g_SelSense_MenuAnchorX, g_SelSense_MenuAnchorY
        g_SelSense_MenuW := 420
        g_SelSense_MenuH := 560
        g_SelSense_MenuActivateOnShow := true
        CoordMode("Mouse", "Screen")
        MouseGetPos(&g_SelSense_MenuAnchorX, &g_SelSense_MenuAnchorY)
    } catch as _e {
    }

    ; 确保 WebView/页面至少存在且导航到 HubCapsule
    try {
        if !(g_SelSense_MenuGui && g_SelSense_MenuWV2) {
            g_SelSense_NextNavPage := "HubCapsule.html"
            SelectionSense_EnsureMenuHost()
        } else if !g_SelSense_MenuShowingHub {
            g_SelSense_MenuReady := false
            g_SelSense_NextNavPage := ""
            try g_SelSense_MenuWV2.Navigate(BuildAppLocalUrl("HubCapsule.html"))
            g_SelSense_MenuShowingHub := true
        }
    } catch as _e {
    }

    ; 只有「ready 且当前页确实是 HubCapsule」才允许直接推送。
    ; 否则消息可能发到 SelectionMenu.html 被忽略，从而表现为“只进剪贴板，不进 Hub”。
    try {
        if (g_SelSense_MenuWV2 && g_SelSense_MenuReady && g_SelSense_MenuShowingHub) {
            WebView_QueuePayload(g_SelSense_MenuWV2, Map("type", "push_segment", "text", t))
            ; 确保窗口可见（若控件未就绪，该函数内部会 SetTimer 重试）
            try SelectionSense_ShowMenuNearCursor()
            return true
        }
    } catch as _e {
    }

    try {
        if !(g_SelSense_PendingHubSegments is Array)
            g_SelSense_PendingHubSegments := []
        g_SelSense_PendingHubSegments.Push(t)
        ; 先把窗口拉出来；待 hub_ready/selection_menu_ready 时 flush 入栈
        try SelectionSense_ShowMenuNearCursor()
    } catch as _e {
    }
    ; WebView 未 ready 时仅入队，返回 false 便于调用方再补发预览/二次 Show
    return false
}

SelectionSense_PushMenuText(text) {
    global g_SelSense_MenuWV2, g_SelSense_MenuReady
    if !(g_SelSense_MenuWV2 && g_SelSense_MenuReady)
        return
    WebView_QueuePayload(g_SelSense_MenuWV2, Map("type", "selection_menu_init", "text", String(text)))
}

SelectionSense_PushHubPreviewText(text) {
    global g_SelSense_MenuWV2, g_SelSense_MenuReady, g_SelSense_PendingText
    t := Trim(String(text), " `t`r`n")
    if (t = "")
        return
    g_SelSense_PendingText := t
    if !(g_SelSense_MenuWV2 && g_SelSense_MenuReady)
        return
    WebView_QueuePayload(g_SelSense_MenuWV2, Map("type", "hub_preview_selection", "text", t))
}

; CapsLock+C 等：页面/WebView 可能晚于 Show，延迟再推一次预览并确保窗口在前台
SelectionSense_HubCapsule_ResyncAfterCapsLockCopy(text) {
    t := Trim(String(text), " `t`r`n")
    if (t = "")
        return
    global g_SelSense_PendingText
    g_SelSense_PendingText := t
    SelectionSense_PushHubPreviewText(t)
    try SelectionSense_ShowMenuNearCursor()
    catch as _e {
    }
}

SelectionSense_RefreshHubPreviewAfterCopyTick(*) {
    global g_SelSense_LastFullText, g_SelSense_LastTick, g_SelSense_LastClipSig, g_SelSense_LastFireTick
    if !SelectionSense_HubCapsuleHostIsOpen()
        return
    text := ""
    try text := Trim(String(A_Clipboard), " `t`r`n")
    if (text = "")
        return
    g_SelSense_LastFullText := text
    g_SelSense_LastTick := A_TickCount
    g_SelSense_LastClipSig := StrLen(text) . ":" . SubStr(text, 1, 24)
    g_SelSense_LastFireTick := A_TickCount
    SelectionSense_PushHubPreviewText(text)
}

SelectionSense_ShowMenuNearCursor() {
    static menuShowRetries := 0
    static hubWvWarned := false
    global g_SelSense_MenuGui, g_SelSense_MenuVisible, g_SelSense_PendingText
    global g_SelSense_MenuAnchorX, g_SelSense_MenuAnchorY, g_SelSense_MenuCtrl

    SelectionSense_EnsureMenuHost()
    if !g_SelSense_MenuGui
        return

    ; WebView2.create 异步：控件未就绪时延迟重试，避免空白菜单（冷启动可能 >3s）
    if !g_SelSense_MenuCtrl {
        menuShowRetries++
        if (menuShowRetries < 180)
            SetTimer(SelectionSense_ShowMenuNearCursor, -55)
        else {
            menuShowRetries := 0
            if !hubWvWarned {
                hubWvWarned := true
                try TrayTip("HubCapsule 未能创建 WebView2 控件`n请确认已安装 WebView2 Runtime，并重启脚本。", "SelectionMenuHost", "Iconx 2")
            }
        }
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
    if savedOk && !SelectionSense_HubSavedRectIsOnScreen(sx, sy, w, h)
        savedOk := false
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
    try WinShow("ahk_id " . g_SelSense_MenuGui.Hwnd)
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

; 与 ~^c 打开的 Hub 完全一致：可传 overrideText（CapsLock+C 用），空则从 A_Clipboard 读
; alsoPushSegment：仅 CapsLock+C 需要把内容压入堆叠卡片时再为 true
SelectionSense_SyncHubFromUserCopyChannel(overrideText := "", alsoPushSegment := false) {
    global g_SelSense_LastFullText, g_SelSense_LastTick, g_SelSense_LastClipSig, g_SelSense_LastFireTick
    text := Trim(String(overrideText), " `t`r`n")
    if (text = "") {
        try text := Trim(String(A_Clipboard), " `t`r`n")
    }
    if (text = "")
        return

    g_SelSense_LastFullText := text
    g_SelSense_LastTick := A_TickCount
    g_SelSense_LastClipSig := StrLen(text) . ":" . SubStr(text, 1, 24)
    g_SelSense_LastFireTick := A_TickCount
    try FloatingToolbar_NotifySelectionChange(text)
    catch as _e {
    }
    SelectionSense_OpenHubCapsuleFromToolbar(false, text)
    SelectionSense_PushHubPreviewText(text)
    if (alsoPushSegment)
        SelectionSense_HubCapsule_PushSegmentText(text)
    SetTimer(SelectionSense_HubCapsule_ResyncAfterCapsLockCopy.Bind(text), -250)
    SetTimer(SelectionSense_HubCapsule_ResyncAfterCapsLockCopy.Bind(text), -850)
}

SelectionSense_OpenHubAfterDoubleCopyTick(*) {
    SelectionSense_SyncHubFromUserCopyChannel("", false)
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
        if !g_SelSense_MenuShowingHub {
            g_SelSense_MenuReady := false
            g_SelSense_NextNavPage := ""
            try g_SelSense_MenuWV2.Navigate(BuildAppLocalUrl("HubCapsule.html"))
            g_SelSense_MenuShowingHub := true
        }
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

SelectionSense_PrewarmHubCapsule() {
    global g_SelSense_MenuGui, g_SelSense_MenuWV2, g_SelSense_MenuReady
    global g_SelSense_NextNavPage, g_SelSense_MenuShowingHub

    if (g_SelSense_MenuGui && g_SelSense_MenuWV2) {
        g_SelSense_MenuReady := false
        g_SelSense_NextNavPage := ""
        try g_SelSense_MenuWV2.Navigate(BuildAppLocalUrl("HubCapsule.html"))
        g_SelSense_MenuShowingHub := true
    } else {
        g_SelSense_NextNavPage := "HubCapsule.html"
        SelectionSense_EnsureMenuHost()
    }
}

SelectionSense_OnUserCopy(*) {
    global g_SelSense_UserCopyInProgress, g_SelSense_UserCopyEndTick, g_SelSense_DoubleCopyHub_LastTick, g_SelSense_HubCopyTriggerMode

    ; CapsLock+C 内部 Send(^c) 会触发本钩子：此时剪贴板稍后会被恢复，不能排队 OpenHub（否则会读到旧剪贴板）
    global CapsLockCopyInProgress
    if (CapsLockCopyInProgress)
        return

    g_SelSense_UserCopyInProgress := true
    g_SelSense_UserCopyEndTick := A_TickCount
    SetTimer(SelectionSense_ClearUserCopyFlag, -780)

    ; Hub 已打开时，新复制内容直接替换预览区，而不是沿用首次打开时的旧内容
    if !SelectionSense_IsCursorEditorActive()
        return
    if SelectionSense_HubCapsuleHostIsOpen() {
        SetTimer(SelectionSense_RefreshHubPreviewAfterCopyTick, -140)
        return
    }

    ; 触发模式为 CapsLock+C 时，普通 Ctrl+C 不负责“打开”Hub（Hub 已打开时仍允许刷新预览）
    if (g_SelSense_HubCopyTriggerMode != "double") {
        g_SelSense_DoubleCopyHub_LastTick := 0
        return
    }

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
        Hotkey("~*LButton", SelectionSense_OnLButtonDown, "On")
        Hotkey("~*LButton Up", SelectionSense_OnLButtonUp, "On")
        Hotkey("~^c", SelectionSense_OnUserCopy, "On")
    } else {
        Hotkey("~*LButton", SelectionSense_OnLButtonDown, "Off")
        Hotkey("~*LButton Up", SelectionSense_OnLButtonUp, "Off")
        Hotkey("~^c", SelectionSense_OnUserCopy, "Off")
    }
    try SelectionSense_PrewarmHubCapsule()
}
