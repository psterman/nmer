#Requires AutoHotkey v2.0
; 閫夊尯鎰熷簲锛殈LButton Up + IBeam + Ctrl+C锛岃仈鍔ㄥ伐鍏锋爮 WebView 涓庨€夊尯鑿滃崟锛堜緷璧栦富鑴氭湰鐨?WebView2 / Jxon / BuildAppLocalUrl 绛夛級
; 榛樿蹇界暐銆屾暣娈典负 Windows 璺緞/澶氳璺緞銆嶇殑鍓创鏉匡紙璧勬簮绠＄悊鍣ㄩ€夋枃浠讹級锛岃 [SelectionSense] ReactToFilePaths
; SuperHub 妯″紡锛氭敮鎸佸娈垫枃鏈爢鍙犮€佹嫋鎷借瀺鍚堛€佽竟缂樻敹绾?
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
; Outside-dismiss: same click's LButton Up still runs SelectionSense; skip ProcessDeferred ~520ms.
global g_SelSense_LastOutsideDismissTick := 0

; ==================== SuperHub 鎵╁睍鍙橀噺 ====================
global g_Hub_UseHubCapsule := true
global g_Hub_Segments := []
global g_Hub_IsDragging := false
global g_Hub_DragTimer := 0
global g_Hub_DockState := "visible"
global g_Hub_DockEdge := ""
global g_Hub_GravityTarget := ""
global g_Hub_GravityDist := 9999
global g_Hub_LastCollisionBtn := ""
global g_Hub_DragStartMouseX := 0
global g_Hub_DragStartMouseY := 0
global g_Hub_DragStartWinX := 0
global g_Hub_DragStartWinY := 0
global g_Hub_StartWidth := 340
global g_Hub_StartHeight := 300
global g_FTB_ButtonRects := Map()
global g_Hub_GravityThreshold := 100
global g_Hub_CollisionThreshold := 30
global g_Hub_SavedValid := false
global g_Hub_SavedX := 0
global g_Hub_SavedY := 0
global g_Hub_SavedW := 340
global g_Hub_SavedH := 300

Hub_GeometryConfigPath() {
    return (IsSet(ConfigFile) && ConfigFile != "") ? ConfigFile : (A_ScriptDir "\CursorShortcut.ini")
}

Hub_LoadGeometryFromIni() {
    global g_Hub_SavedValid, g_Hub_SavedX, g_Hub_SavedY, g_Hub_SavedW, g_Hub_SavedH
    cfg := Hub_GeometryConfigPath()
    try {
        sx := IniRead(cfg, "SelectionSense", "HubWinX", "")
        sy := IniRead(cfg, "SelectionSense", "HubWinY", "")
        sw := IniRead(cfg, "SelectionSense", "HubWinW", "")
        sh := IniRead(cfg, "SelectionSense", "HubWinH", "")
        if (sx = "" || sy = "" || sw = "" || sh = "") {
            g_Hub_SavedValid := false
            return
        }
        ix := Integer(sx)
        iy := Integer(sy)
        iw := Integer(sw)
        ih := Integer(sh)
        if (iw < 280 || ih < 220) {
            g_Hub_SavedValid := false
            return
        }
        g_Hub_SavedX := ix
        g_Hub_SavedY := iy
        g_Hub_SavedW := iw
        g_Hub_SavedH := ih
        g_Hub_SavedValid := true
    } catch as e {
        g_Hub_SavedValid := false
    }
}

Hub_ClampHubWindowToWorkArea(&x, &y, &w, &h) {
    w := Max(280, w)
    h := Max(220, h)
    idx := MonitorGetPrimary()
    if !idx
        return
    MonitorGetWorkArea(idx, &wl, &wt, &wr, &wb)
    if (x + w > wr)
        x := wr - w
    if (y + h > wb)
        y := wb - h
    if (x < wl)
        x := wl
    if (y < wt)
        y := wt
    if (x + w > wr)
        x := Max(wl, wr - w)
    if (y + h > wb)
        y := Max(wt, wb - h)
}

Hub_SaveGeometry() {
    global g_SelSense_MenuGui, g_Hub_UseHubCapsule
    global g_Hub_SavedValid, g_Hub_SavedX, g_Hub_SavedY, g_Hub_SavedW, g_Hub_SavedH
    if !g_Hub_UseHubCapsule || !g_SelSense_MenuGui
        return
    hwnd := 0
    try hwnd := g_SelSense_MenuGui.Hwnd
    catch as e {
        return
    }
    if !hwnd || !WinExist("ahk_id " . hwnd)
        return
    try {
        WinGetPos(&wx, &wy, &ww, &wh, "ahk_id " . hwnd)
        cfg := Hub_GeometryConfigPath()
        IniWrite(String(wx), cfg, "SelectionSense", "HubWinX")
        IniWrite(String(wy), cfg, "SelectionSense", "HubWinY")
        IniWrite(String(ww), cfg, "SelectionSense", "HubWinW")
        IniWrite(String(wh), cfg, "SelectionSense", "HubWinH")
        g_Hub_SavedX := wx
        g_Hub_SavedY := wy
        g_Hub_SavedW := ww
        g_Hub_SavedH := wh
        g_Hub_SavedValid := true
    } catch as e {
    }
}

Hub_DebouncedSaveGeometry(*) {
    global g_SelSense_MenuVisible, g_Hub_UseHubCapsule
    if (g_SelSense_MenuVisible && g_Hub_UseHubCapsule)
        Hub_SaveGeometry()
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
    global g_SelSense_Enabled, g_SelSense_ShowMenu, g_SelSense_CopyDelayMs, g_SelSense_RequireIBeam
    global g_SelSense_ReactToFilePaths, g_Hub_UseHubCapsule
    cfg := (IsSet(ConfigFile) && ConfigFile != "") ? ConfigFile : (A_ScriptDir "\CursorShortcut.ini")
    try {
        g_SelSense_Enabled := (IniRead(cfg, "SelectionSense", "Enable", "1") != "0")
        g_SelSense_ShowMenu := (IniRead(cfg, "SelectionSense", "ShowMenu", "1") != "0")
        g_SelSense_CopyDelayMs := Integer(IniRead(cfg, "SelectionSense", "CopyDelayMs", "40"))
        g_SelSense_RequireIBeam := (IniRead(cfg, "SelectionSense", "RequireIBeam", "0") = "1")
        g_SelSense_ReactToFilePaths := (IniRead(cfg, "SelectionSense", "ReactToFilePaths", "0") = "1")
        g_Hub_UseHubCapsule := (IniRead(cfg, "SelectionSense", "UseHubCapsule", "1") = "1")
    } catch {
        g_SelSense_Enabled := true
        g_SelSense_ShowMenu := true
        g_SelSense_CopyDelayMs := 40
        g_SelSense_RequireIBeam := false
        g_SelSense_ReactToFilePaths := false
        g_Hub_UseHubCapsule := true
    }
    if (g_SelSense_CopyDelayMs < 20)
        g_SelSense_CopyDelayMs := 20
    if (g_SelSense_CopyDelayMs > 200)
        g_SelSense_CopyDelayMs := 200
    Hub_LoadGeometryFromIni()
}

SelectionSense_IsKnownGuiRoot(hwnd) {
    if !hwnd
        return false
    global FloatingToolbarGUI, g_SCWV_Gui, g_CP_Gui, g_VK_Gui, g_PQP_Gui, g_SelSense_MenuGui
    global AIListPanelGUI, GuiID_ConfigGUI, GuiID_SearchCenter
    if (IsSet(FloatingToolbarGUI) && SelectionSense_SafeGuiHwnd(FloatingToolbarGUI) = hwnd)
        return true
    if (IsSet(g_SCWV_Gui) && SelectionSense_SafeGuiHwnd(g_SCWV_Gui) = hwnd)
        return true
    if (IsSet(g_CP_Gui) && SelectionSense_SafeGuiHwnd(g_CP_Gui) = hwnd)
        return true
    if (IsSet(g_VK_Gui) && SelectionSense_SafeGuiHwnd(g_VK_Gui) = hwnd)
        return true
    if (IsSet(g_PQP_Gui) && SelectionSense_SafeGuiHwnd(g_PQP_Gui) = hwnd)
        return true
    if (IsSet(g_SelSense_MenuGui) && SelectionSense_SafeGuiHwnd(g_SelSense_MenuGui) = hwnd)
        return true
    if (IsSet(AIListPanelGUI) && SelectionSense_SafeGuiHwnd(AIListPanelGUI) = hwnd)
        return true
    if (IsSet(GuiID_ConfigGUI) && SelectionSense_SafeGuiHwnd(GuiID_ConfigGUI) = hwnd)
        return true
    if (IsSet(GuiID_SearchCenter) && SelectionSense_SafeGuiHwnd(GuiID_SearchCenter) = hwnd)
        return true
    return false
}

SelectionSense_SafeGuiHwnd(guiObj) {
    if !guiObj
        return 0
    try return guiObj.Hwnd
    catch
        return 0
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

; 鍓创鏉夸负澶氳鏃讹細浠呭綋姣忎竴闈炵┖琛岄兘鍍忚矾寰勬椂瑙嗕负銆屾枃浠惰矾寰勯€夊尯銆嶏紙璧勬簮绠＄悊鍣ㄥ鍒跺鏂囦欢绛夛級
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
    global g_SelSense_LastOutsideDismissTick
    if (g_SelSense_LastOutsideDismissTick && (A_TickCount - g_SelSense_LastOutsideDismissTick) < 520)
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

    ; Avoid over-aggressive dedupe: keep a longer signature and shorter window.
    sig := StrLen(text) . ":" . SubStr(text, 1, 120)
    if (sig = g_SelSense_LastClipSig && (A_TickCount - g_SelSense_LastFireTick < 120))
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

SelectionSense_OnMenuGuiSize(*) {
    global g_SelSense_MenuCtrl, g_Hub_UseHubCapsule, g_SelSense_MenuVisible
    SelectionSense_ApplyMenuBounds()
    if g_SelSense_MenuCtrl {
        try g_SelSense_MenuCtrl.NotifyParentWindowPositionChanged()
        catch {
        }
    }
    if (g_Hub_UseHubCapsule && g_SelSense_MenuVisible)
        SetTimer(Hub_DebouncedSaveGeometry, -250)
}

SelectionSense_EnsureMenuHost() {
    global g_SelSense_MenuGui, g_SelSense_MenuCtrl, g_SelSense_MenuWV2, g_SelSense_MenuReady
    global g_Hub_UseHubCapsule

    if g_SelSense_MenuGui
        return

    opt := "+AlwaysOnTop -Caption +ToolWindow -DPIScale"
    if g_Hub_UseHubCapsule
        opt .= " +Resize +MinSize280x220"
    g_SelSense_MenuGui := Gui(opt, "SelectionMenuHost")
    g_SelSense_MenuGui.MarginX := 0
    g_SelSense_MenuGui.MarginY := 0
    ; 涓嶄娇鐢?WinSetTransColor锛氫笌 WebView2 閫忔槑鑳屾櫙鍙犲姞鍚庯紝瀹㈡埛鍖哄煙浼氬彉涓虹┛閫忥紝鐐瑰嚮銆佹寜閽叏閮ㄥけ鏁堛€?
    g_SelSense_MenuGui.BackColor := "1A1A1A"
    g_SelSense_MenuGui.OnEvent("Close", (*) => SelectionSense_HideMenu())
    g_SelSense_MenuGui.OnEvent("Size", SelectionSense_OnMenuGuiSize)

    if g_Hub_UseHubCapsule
        g_SelSense_MenuGui.Show("w340 h300 Hide")
    else
        g_SelSense_MenuGui.Show("w220 h200 Hide")

    WebView2.create(g_SelSense_MenuGui.Hwnd, SelectionSense_OnMenuWebViewCreated)
}

SelectionSense_OnMenuWebViewCreated(ctrl) {
    global g_SelSense_MenuCtrl, g_SelSense_MenuWV2, g_SelSense_MenuReady

    g_SelSense_MenuCtrl := ctrl
    g_SelSense_MenuWV2 := ctrl.CoreWebView2
    g_SelSense_MenuReady := false
    ; 不透明背景，与宿主一致，避免透明叠色键导致穿透
    try ctrl.DefaultBackgroundColor := 0xFF1A1A1A
    try ctrl.IsVisible := true

    SelectionSense_ApplyMenuBounds()

    s := g_SelSense_MenuWV2.Settings
    s.AreDefaultContextMenusEnabled := false
    s.IsStatusBarEnabled := false
    s.AreDevToolsEnabled := false

    g_SelSense_MenuWV2.add_WebMessageReceived(SelectionSense_OnMenuWebMessage)
    try ApplyUnifiedWebViewAssets(g_SelSense_MenuWV2)
    
    global g_Hub_UseHubCapsule
    if g_Hub_UseHubCapsule {
        try ctrl.AllowExternalDrop := true
        catch {
        }
        g_SelSense_MenuWV2.Navigate(BuildAppLocalUrl("HubCapsule.html?v=" . A_TickCount))
    } else
        g_SelSense_MenuWV2.Navigate(BuildAppLocalUrl("SelectionMenu.html?v=" . A_TickCount))
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
    txt := msg.Has("text") ? String(msg["text"]) : ""
    
    ; ==================== 鏃х増 SelectionMenu 鍏煎 ====================
    if (typ = "selection_menu_ready") {
        global g_SelSense_MenuReady, g_SelSense_MenuVisible, g_SelSense_PendingText
        g_SelSense_MenuReady := true
        if g_SelSense_MenuVisible
            SetTimer(SelectionSense_DeferredPushMenuText, -1)
        return
    }
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
        SelectionSense_HideMenu(true)
        return
    }
    
    ; ==================== SuperHub 鏂版秷鎭鐞?====================
    if (typ = "hub_ready") {
        global g_SelSense_MenuReady, g_Hub_Segments
        g_SelSense_MenuReady := true
        if (g_Hub_Segments.Length > 0)
            WebView_QueuePayload(g_SelSense_MenuWV2, Map("type", "hub_restore_segments", "segments", g_Hub_Segments))
        ; 入栈仅由 selection_menu_ready 触发 DeferredPush，避免与 hub_ready 重复调度
        return
    }

    if (typ = "hub_mousedown") {
        sx := msg.Has("x") ? Integer(msg["x"]) : 0
        sy := msg.Has("y") ? Integer(msg["y"]) : 0
        Hub_OnMouseDown(sx, sy)
        return
    }
    
    if (typ = "hub_drag_start") {
        Hub_OnDragStart()
        return
    }
    
    if (typ = "hub_drag_move") {
        mx := msg.Has("x") ? Integer(msg["x"]) : 0
        my := msg.Has("y") ? Integer(msg["y"]) : 0
        offsetX := msg.Has("offsetX") ? Integer(msg["offsetX"]) : 0
        offsetY := msg.Has("offsetY") ? Integer(msg["offsetY"]) : 0
        Hub_OnDragMove(mx, my, offsetX, offsetY)
        return
    }
    
    if (typ = "hub_drag_end") {
        mx := msg.Has("x") ? Integer(msg["x"]) : 0
        my := msg.Has("y") ? Integer(msg["y"]) : 0
        Hub_OnDragEnd(mx, my)
        return
    }

    if (typ = "hub_resize_start") {
        w := msg.Has("width") ? Integer(msg["width"]) : 340
        h := msg.Has("height") ? Integer(msg["height"]) : 300
        Hub_OnResizeStart(w, h)
        return
    }

    if (typ = "hub_resize_move") {
        w := msg.Has("width") ? Integer(msg["width"]) : 340
        h := msg.Has("height") ? Integer(msg["height"]) : 300
        Hub_OnResizeMove(w, h)
        return
    }

    if (typ = "hub_resize_end") {
        w := msg.Has("width") ? Integer(msg["width"]) : 340
        h := msg.Has("height") ? Integer(msg["height"]) : 300
        Hub_OnResizeMove(w, h)
        Hub_SaveGeometry()
        return
    }
    
    if (typ = "hub_search") {
        SelectionSense_HideMenu()
        if (Trim(txt) != "")
            try SearchCenter_SetInputText(txt)
            catch {
            }
        return
    }
    
    if (typ = "hub_ai") {
        SelectionSense_HideMenu()
        try PromptQuickPad_OpenCaptureDraft(txt, true)
        catch {
        }
        return
    }
    
    if (typ = "hub_cleared") {
        global g_Hub_Segments
        g_Hub_Segments := []
        return
    }
    
    if (typ = "hub_fusion_complete") {
        action := msg.Has("action") ? String(msg["action"]) : ""
        Hub_ExecuteFusion(action, txt)
        return
    }
    
    if (typ = "hub_request_dock") {
        Hub_DockToNearestEdge()
        return
    }

    if (typ = "hub_copy") {
        t := msg.Has("text") ? String(msg["text"]) : ""
        if (Trim(t) != "") {
            try A_Clipboard := t
            catch {
            }
        }
        return
    }

    if (typ = "hub_segments_sync") {
        global g_Hub_Segments
        g_Hub_Segments := []
        if msg.Has("segments") {
            segs := msg["segments"]
            if (segs is Array) {
                for s in segs
                    g_Hub_Segments.Push(String(s))
            }
        }
        return
    }
}

SelectionSense_PushMenuText(text) {
    global g_SelSense_MenuWV2, g_SelSense_MenuReady, g_Hub_UseHubCapsule
    if !(g_SelSense_MenuWV2 && g_SelSense_MenuReady)
        return
    
    if g_Hub_UseHubCapsule
        Hub_PushSegment(text)
    else
        WebView_QueuePayload(g_SelSense_MenuWV2, Map("type", "selection_menu_init", "text", String(text)))
}

SelectionSense_PreviewMenuText(text) {
    global g_SelSense_MenuWV2, g_SelSense_MenuReady, g_Hub_UseHubCapsule
    if !(g_SelSense_MenuWV2 && g_SelSense_MenuReady)
        return
    if g_Hub_UseHubCapsule
        WebView_QueuePayload(g_SelSense_MenuWV2, Map("type", "hub_preview_selection", "text", String(text)))
    else
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

    ; WebView2.create 寮傛锛氭帶浠舵湭灏辩华鏃跺欢杩熼噸璇曪紝閬垮厤绌虹櫧鑿滃崟
    if !g_SelSense_MenuCtrl {
        menuShowRetries++
        if (menuShowRetries < 50)
            SetTimer(SelectionSense_ShowMenuNearCursor, -70)
        else
            menuShowRetries := 0
        return
    }
    menuShowRetries := 0

    global g_Hub_UseHubCapsule, g_Hub_SavedValid, g_Hub_SavedX, g_Hub_SavedY, g_Hub_SavedW, g_Hub_SavedH
    w := g_Hub_UseHubCapsule ? 340 : 220
    h := g_Hub_UseHubCapsule ? 300 : 200
    CoordMode("Mouse", "Screen")
    mx := g_SelSense_MenuAnchorX
    my := g_SelSense_MenuAnchorY
    x := mx + 8
    y := my + 8
    if (g_Hub_UseHubCapsule && g_Hub_SavedValid) {
        x := g_Hub_SavedX
        y := g_Hub_SavedY
        w := g_Hub_SavedW
        h := g_Hub_SavedH
        Hub_ClampHubWindowToWorkArea(&x, &y, &w, &h)
    } else {
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
    }

    try g_SelSense_MenuGui.Show("x" . x . " y" . y . " w" . w . " h" . h . " NoActivate")
    g_SelSense_MenuVisible := true
    g_SelSense_OutsidePrevLBtn := GetKeyState("LButton", "P")
    g_SelSense_OutsidePrevRBtn := GetKeyState("RButton", "P")
    SelectionSense_ApplyMenuBounds()
    try g_SelSense_MenuCtrl.NotifyParentWindowPositionChanged()

    SetTimer(SelectionSense_DeferredPushMenuText, -80)
    SetTimer(SelectionSense_CheckClickOutside, g_Hub_UseHubCapsule ? 10 : 25)
}

SelectionSense_DeferredPushMenuText(*) {
    global g_SelSense_PendingText, g_SelSense_MenuReady, g_SelSense_MenuWV2, g_Hub_UseHubCapsule
    if !g_SelSense_MenuWV2
        return
    if g_SelSense_MenuReady {
        if (Trim(String(g_SelSense_PendingText)) != "") {
            ; Hub锛氫粎棰勮锛堢獥鍙?20%锛夛紝鍏ュ崱鐗囬渶鍦ㄧ綉椤甸〉鍐呮嫋鍔ㄧ‘璁わ紱鏃ц彍鍗曚粛涓€姝ュ叆鏍?
            if g_Hub_UseHubCapsule {
                SelectionSense_PreviewMenuText(g_SelSense_PendingText)
            } else {
                SelectionSense_PushMenuText(g_SelSense_PendingText)
            }
            g_SelSense_PendingText := ""
        }
    } else
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
    hwndPt := 0
    MouseGetPos(&mx, &my, &hwndPt)
    try {
        WinGetPos(&wx, &wy, &ww, &wh, "ahk_id " . g_SelSense_MenuGui.Hwnd)
        rectOutside := (mx < wx || mx > wx + ww || my < wy || my > wy + wh)
        menuHwnd := g_SelSense_MenuGui.Hwnd
        menuRoot := DllCall("user32\GetAncestor", "ptr", menuHwnd, "uint", 2, "ptr")
        underRoot := 0
        if hwndPt
            underRoot := DllCall("user32\GetAncestor", "ptr", hwndPt, "uint", 2, "ptr")
        foreignWin := (underRoot && underRoot != menuRoot)
        outside := rectOutside || foreignWin
        lPress := lDown && !g_SelSense_OutsidePrevLBtn
        lRelease := !lDown && g_SelSense_OutsidePrevLBtn
        rPress := rDown && !g_SelSense_OutsidePrevRBtn
        rRelease := !rDown && g_SelSense_OutsidePrevRBtn
        if (outside && (lPress || rPress || lRelease || rRelease)) {
            SelectionSense_HideMenu(true)
            return
        }
    } catch {
    }
    g_SelSense_OutsidePrevLBtn := lDown
    g_SelSense_OutsidePrevRBtn := rDown
}

SelectionSense_HideMenu(fromOutside := false) {
    global g_SelSense_MenuGui, g_SelSense_MenuVisible
    global g_SelSense_OutsidePrevLBtn, g_SelSense_OutsidePrevRBtn
    global g_Hub_UseHubCapsule, g_SelSense_MenuWV2
    global g_SelSense_LastOutsideDismissTick
    if (fromOutside && g_SelSense_MenuVisible)
        g_SelSense_LastOutsideDismissTick := A_TickCount
    SetTimer(SelectionSense_CheckClickOutside, 0)
    SetTimer(Hub_DebouncedSaveGeometry, 0)
    if (g_SelSense_MenuVisible && g_Hub_UseHubCapsule && g_SelSense_MenuWV2) {
        try WebView_QueuePayload(g_SelSense_MenuWV2, Map("type", "hub_dismiss_reset"))
        catch as e {
        }
    }
    if (g_SelSense_MenuVisible && g_Hub_UseHubCapsule)
        Hub_SaveGeometry()
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

; 涓庡壀璐存澘/鎼滅储涓績绛変竴骞堕鐑紝棣栨閫夊尯寮瑰嚭涓嶅繀鍐嶇瓑 WebView2 鍒涘缓
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

; ==================== SuperHub 鍑芥暟 ====================

Hub_PushSegment(text) {
    global g_SelSense_MenuWV2, g_SelSense_MenuReady, g_Hub_Segments
    
    text := Trim(String(text))
    if (text = "")
        return
    
    g_Hub_Segments.Push(text)
    
    if (g_SelSense_MenuWV2 && g_SelSense_MenuReady)
        WebView_QueuePayload(g_SelSense_MenuWV2, Map("type", "push_segment", "text", text))
}

Hub_ClearSegments() {
    global g_SelSense_MenuWV2, g_SelSense_MenuReady, g_Hub_Segments
    
    g_Hub_Segments := []
    
    if (g_SelSense_MenuWV2 && g_SelSense_MenuReady)
        WebView_QueuePayload(g_SelSense_MenuWV2, Map("type", "clear_segments"))
}

Hub_GetMergedText() {
    global g_Hub_Segments
    merged := ""
    for seg in g_Hub_Segments
        merged .= (merged != "" ? "`n`n" : "") . seg
    return merged
}

Hub_OnMouseDown(mx, my) {
    global g_SelSense_MenuGui
    global g_Hub_DragStartMouseX, g_Hub_DragStartMouseY, g_Hub_DragStartWinX, g_Hub_DragStartWinY

    g_Hub_DragStartMouseX := mx
    g_Hub_DragStartMouseY := my
    if g_SelSense_MenuGui {
        try WinGetPos(&wx, &wy, , , "ahk_id " . g_SelSense_MenuGui.Hwnd)
        catch {
            wx := 0
            wy := 0
        }
        g_Hub_DragStartWinX := wx
        g_Hub_DragStartWinY := wy
    }
}

Hub_OnResizeStart(width, height) {
    global g_Hub_StartWidth, g_Hub_StartHeight
    g_Hub_StartWidth := Max(280, width)
    g_Hub_StartHeight := Max(220, height)
}

Hub_OnDragStart() {
    global g_Hub_IsDragging, g_Hub_DragTimer, g_Hub_DockState
    
    g_Hub_IsDragging := true
    g_Hub_DockState := "visible"
    
    FloatingToolbar_RequestButtonRects()
}

Hub_OnResizeMove(width, height) {
    global g_SelSense_MenuGui
    if !g_SelSense_MenuGui
        return
    try {
        WinGetPos(&wx, &wy, , , "ahk_id " . g_SelSense_MenuGui.Hwnd)
        g_SelSense_MenuGui.Show("x" . wx . " y" . wy . " w" . Max(280, width) . " h" . Max(220, height) . " NoActivate")
        SelectionSense_ApplyMenuBounds()
    } catch {
    }
}

Hub_OnDragMove(mx, my, offsetX, offsetY) {
    global g_SelSense_MenuGui, g_Hub_IsDragging
    global g_FTB_ButtonRects, g_Hub_GravityThreshold, g_Hub_GravityTarget, g_Hub_GravityDist
    global g_Hub_DragStartMouseX, g_Hub_DragStartMouseY, g_Hub_DragStartWinX, g_Hub_DragStartWinY
    
    if !g_Hub_IsDragging || !g_SelSense_MenuGui
        return
    
    curX := mx
    curY := my
    try {
        if (g_Hub_DragStartMouseX = 0 && g_Hub_DragStartMouseY = 0) {
            Hub_OnMouseDown(mx, my)
        }
        dx := curX - g_Hub_DragStartMouseX
        dy := curY - g_Hub_DragStartMouseY
        newX := g_Hub_DragStartWinX + dx
        newY := g_Hub_DragStartWinY + dy
        g_SelSense_MenuGui.Move(newX, newY)
    } catch {
    }
    
    Hub_CheckGravity(curX, curY)
    Hub_BroadcastCollisionState(curX, curY)
}

Hub_OnDragEnd(mx, my) {
    global g_Hub_IsDragging, g_Hub_GravityTarget, g_Hub_GravityDist
    global g_Hub_DragStartMouseX, g_Hub_DragStartMouseY
    global g_Hub_CollisionThreshold, g_SelSense_MenuWV2, g_SelSense_MenuReady
    
    g_Hub_IsDragging := false
    
    collidedBtn := Hub_CheckCollision(mx, my)
    
    if (collidedBtn != "") {
        if (g_SelSense_MenuWV2 && g_SelSense_MenuReady) {
            action := ""
            switch collidedBtn {
                case "btn-search": action := "search"
                case "btn-ai": action := "ai"
            }
            if (action != "") {
                WebView_QueuePayload(g_SelSense_MenuWV2, Map("type", "fusion_trigger", "action", action))
                FloatingToolbar_TriggerFusion(collidedBtn)
            }
        }
    } else {
        Hub_ClearGravity()
    }

    ; 拖拽结束后清除碰撞高亮
    Hub_SendCollisionFeedback("", false)
    g_Hub_DragStartMouseX := 0
    g_Hub_DragStartMouseY := 0
    
    g_Hub_GravityTarget := ""
    g_Hub_GravityDist := 9999
    Hub_SaveGeometry()
}

Hub_CheckGravity(mx, my) {
    global g_FTB_ButtonRects, g_Hub_GravityThreshold, g_Hub_GravityTarget, g_Hub_GravityDist
    global g_SelSense_MenuWV2, g_SelSense_MenuReady
    
    closestBtn := ""
    closestDist := 9999
    
    for btnId, rect in g_FTB_ButtonRects {
        if (btnId != "btn-search" && btnId != "btn-ai")
            continue
        
        centerX := rect["x"] + rect["w"] / 2
        centerY := rect["y"] + rect["h"] / 2
        
        dist := Sqrt((mx - centerX) ** 2 + (my - centerY) ** 2)
        
        if (dist < closestDist) {
            closestDist := dist
            closestBtn := btnId
        }
    }
    
    g_Hub_GravityDist := closestDist
    
    if (closestDist <= g_Hub_GravityThreshold && closestBtn != "") {
        if (g_Hub_GravityTarget != closestBtn) {
            g_Hub_GravityTarget := closestBtn
            
            targetName := (closestBtn = "btn-search") ? "鎼滅储" : "AI"
            
            if (g_SelSense_MenuWV2 && g_SelSense_MenuReady)
                WebView_QueuePayload(g_SelSense_MenuWV2, Map("type", "gravity_update", "active", true, "targetName", targetName))
            
            FloatingToolbar_SetGravity(closestBtn, closestDist)
        }
    } else if (g_Hub_GravityTarget != "") {
        Hub_ClearGravity()
    }
}

Hub_ClearGravity() {
    global g_Hub_GravityTarget, g_SelSense_MenuWV2, g_SelSense_MenuReady
    
    g_Hub_GravityTarget := ""
    
    if (g_SelSense_MenuWV2 && g_SelSense_MenuReady)
        WebView_QueuePayload(g_SelSense_MenuWV2, Map("type", "gravity_update", "active", false, "targetName", ""))
    
    FloatingToolbar_ClearGravity()
}

Hub_CheckCollision(mx, my) {
    global g_FTB_ButtonRects, g_Hub_CollisionThreshold
    
    for btnId, rect in g_FTB_ButtonRects {
        if (btnId != "btn-search" && btnId != "btn-ai")
            continue
        
        centerX := rect["x"] + rect["w"] / 2
        centerY := rect["y"] + rect["h"] / 2
        
        dist := Sqrt((mx - centerX) ** 2 + (my - centerY) ** 2)
        
        if (dist <= g_Hub_CollisionThreshold)
            return btnId
    }
    return ""
}

Hub_BroadcastCollisionState(mx, my) {
    collidedBtn := Hub_CheckCollision(mx, my)
    if (collidedBtn != "")
        Hub_SendCollisionFeedback(collidedBtn, true)
    else
        Hub_SendCollisionFeedback("", false)
}

Hub_SendCollisionFeedback(buttonId, active := true) {
    global g_Hub_LastCollisionBtn, g_SelSense_MenuWV2, g_SelSense_MenuReady

    nextBtn := active ? String(buttonId) : ""
    if (g_Hub_LastCollisionBtn = nextBtn)
        return
    g_Hub_LastCollisionBtn := nextBtn

    if (g_SelSense_MenuWV2 && g_SelSense_MenuReady) {
        WebView_QueuePayload(g_SelSense_MenuWV2, Map(
            "type", "hub_collision_feedback",
            "active", active && nextBtn != "",
            "buttonId", nextBtn
        ))
    }
}

Hub_ExecuteFusion(action, text) {
    global g_Hub_Segments
    
    SelectionSense_HideMenu()
    g_Hub_Segments := []
    
    text := Trim(text)
    if (text = "")
        return
    
    switch action {
        case "search":
            try SearchCenter_RunQueryWithKeyword(text)
            catch {
            }
        case "ai":
            try PromptQuickPad_OpenCaptureDraft(text, true)
            catch {
            }
    }
}

Hub_DockToNearestEdge() {
    global g_SelSense_MenuGui, g_Hub_DockState, g_Hub_DockEdge
    global g_SelSense_MenuWV2, g_SelSense_MenuReady
    
    if !g_SelSense_MenuGui
        return
    
    try {
        WinGetPos(&wx, &wy, &ww, &wh, "ahk_id " . g_SelSense_MenuGui.Hwnd)
    } catch {
        return
    }
    
    ScreenW := SysGet(0)
    ScreenH := SysGet(1)
    
    centerX := wx + ww / 2
    centerY := wy + wh / 2
    
    distLeft := centerX
    distRight := ScreenW - centerX
    distTop := centerY
    distBottom := ScreenH - centerY
    
    minDist := Min(distLeft, distRight, distTop, distBottom)
    
    if (minDist = distLeft)
        edge := "left"
    else if (minDist = distRight)
        edge := "right"
    else if (minDist = distTop)
        edge := "top"
    else
        edge := "bottom"
    
    g_Hub_DockState := "docked"
    g_Hub_DockEdge := edge
    
    if (g_SelSense_MenuWV2 && g_SelSense_MenuReady)
        WebView_QueuePayload(g_SelSense_MenuWV2, Map("type", "set_dock", "edge", edge))
}

Hub_Undock() {
    global g_Hub_DockState, g_Hub_DockEdge
    global g_SelSense_MenuWV2, g_SelSense_MenuReady
    
    g_Hub_DockState := "visible"
    g_Hub_DockEdge := ""
    
    if (g_SelSense_MenuWV2 && g_SelSense_MenuReady)
        WebView_QueuePayload(g_SelSense_MenuWV2, Map("type", "undock"))
}

Hub_UpdateButtonRects(rects) {
    global g_FTB_ButtonRects
    g_FTB_ButtonRects := rects
}

