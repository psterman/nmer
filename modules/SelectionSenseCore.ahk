#Requires AutoHotkey v2.0
; 閫夊尯鎰熷簲锛殈LButton Up 鍚庯紝鑻?Hub 宸插紑涓旂劍鐐瑰湪 Cursor锛屽垯鏉′欢妯℃嫙 ^c 鈫?preview_update锛涘惁鍒欐竻閫夊尯缂撳瓨銆?; HubCapsule锛氬伐鍏锋爮銆屾柊銆嶃€丆ursor 鍐呭弻鍑?Ctrl+C锛坉raft_collect锛夈€丆apsLock+C銆佹樉寮忓瓨鍏ワ紱棰勮涓庤崏绋挎秷鎭垎娴併€?
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
; 宸ュ叿鏍忔墦寮€ Hub 鍚?WebView 鍋滃湪 HubCapsule锛涢€変腑鏂囨湰搴斿洖鍒?SelectionMenu锛屽惁鍒欎細璇敤澶х獥鍙ｉ〉
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
; HubCapsule锛氬爢鍙犻€夋嫨/鎺ㄩ€侊紙渚?CapsLock+C/V锛?global g_HubCapsule_SelectedText := ""
global g_SelSense_PendingHubSegments := []  ; Hub 鏈?ready 鏃舵殏瀛樺緟 push 鐨勬枃鏈
; 涓庝富鑴氭湰 CapsLockCopy 鍏辩敤锛歋end(^c) 鏈熼棿涓?true锛寏^c 椤昏烦杩囦互鍏嶈鍒版仮澶嶅悗鐨勬棫鍓创鏉?global CapsLockCopyInProgress := false
; 鏈€杩戜竴娆″彂寰€ Hub 鐨勩€屽叆鑽夌銆嶆槸鍚︽潵鑷樉寮忛噰闆嗭紙棰勮鏇存柊浼氱疆 false锛?global g_SelSense_IsManualCollected := false
global g_SelSense_HubDictReady := false

SelectionSense_HubDict_EscapeSql(s) {
    return StrReplace(String(s), "'", "''")
}

SelectionSense_HubDict_Ensure() {
    global ClipboardDB, g_SelSense_HubDictReady
    if g_SelSense_HubDictReady
        return true
    if !(IsSet(ClipboardDB) && IsObject(ClipboardDB))
        return false
    try {
        ClipboardDB.Exec("CREATE TABLE IF NOT EXISTS HubLocalDict (Dir TEXT NOT NULL, K TEXT NOT NULL COLLATE NOCASE, V TEXT NOT NULL, PRIMARY KEY (Dir, K))")
        ClipboardDB.Exec("CREATE INDEX IF NOT EXISTS idx_HubLocalDict_DirK ON HubLocalDict (Dir, K)")
        rowCount := 0
        if (ClipboardDB.GetTable("SELECT COUNT(*) FROM HubLocalDict", &t) && t && t.HasProp("Rows") && t.Rows.Length > 0 && t.Rows[1].Length > 0)
            rowCount := Integer(t.Rows[1][1])
        if (rowCount <= 0)
            SelectionSense_HubDict_LoadSeedFromFile()
        g_SelSense_HubDictReady := true
        return true
    } catch as _e {
        return false
    }
}

SelectionSense_HubDict_LoadSeedFromFile() {
    global ClipboardDB
    if !(IsSet(ClipboardDB) && IsObject(ClipboardDB))
        return false
    p := A_ScriptDir "\assets\dict\hubcapsule_base_dict.tsv"
    if !FileExist(p)
        return false
    try raw := FileRead(p, "UTF-8")
    catch {
        return false
    }
    ClipboardDB.Exec("BEGIN IMMEDIATE")
    try {
        for line in StrSplit(raw, "`n", "`r") {
            ln := Trim(String(line), " `t`r`n")
            if (ln = "" || SubStr(ln, 1, 1) = "#")
                continue
            parts := StrSplit(ln, "`t")
            if (parts.Length < 2)
                continue
            src := Trim(String(parts[1]))
            dst := Trim(String(parts[2]))
            if (src = "" || dst = "")
                continue
            dir := ""
            k := ""
            v := dst
            if RegExMatch(src, "[\x{4E00}-\x{9FFF}]") {
                dir := "zh2en"
                k := src
            } else if RegExMatch(dst, "[\x{4E00}-\x{9FFF}]") {
                dir := "en2zh"
                k := StrLower(src)
            } else {
                continue
            }
            sql := "INSERT OR REPLACE INTO HubLocalDict (Dir, K, V) VALUES ('"
                . SelectionSense_HubDict_EscapeSql(dir) . "','"
                . SelectionSense_HubDict_EscapeSql(k) . "','"
                . SelectionSense_HubDict_EscapeSql(v) . "')"
            ClipboardDB.Exec(sql)
        }
        ClipboardDB.Exec("COMMIT")
        return true
    } catch as _e {
        try ClipboardDB.Exec("ROLLBACK")
        return false
    }
}

SelectionSense_HubDict_Lookup(dir, key) {
    global ClipboardDB
    if !SelectionSense_HubDict_Ensure()
        return ""
    d := Trim(String(dir))
    k := Trim(String(key))
    if (d = "en2zh")
        k := StrLower(k)
    if (k = "")
        return ""
    sql := "SELECT V FROM HubLocalDict WHERE Dir='" . SelectionSense_HubDict_EscapeSql(d) . "' AND K='" . SelectionSense_HubDict_EscapeSql(k) . "' LIMIT 1"
    try {
        if (ClipboardDB.GetTable(sql, &t) && t && t.HasProp("Rows") && t.Rows.Length > 0 && t.Rows[1].Length > 0)
            return String(t.Rows[1][1])
    } catch as _e {
    }
    return ""
}

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

SelectionSense_GetHubCapsuleDefaultSize(&outW, &outH) {
    outW := 420
    outH := 560
    try {
        CoordMode("Mouse", "Screen")
        MouseGetPos(&mx, &my)
        mon := SelectionSense_MonitorFromPoint(mx, my)
        MonitorGetWorkArea(mon, &l, &t, &r, &b)
        workW := r - l
        workH := b - t
        outW := Min(Max(420, Floor(workW * 0.34)), 560)
        outH := Min(Max(560, Floor(workH * 0.82)), 980)
    } catch as _e {
        outW := 420
        outH := Max(560, Floor(A_ScreenHeight * 0.78))
    }
}

SelectionSense_MonitorFromPoint(x, y) {
    count := 1
    try count := MonitorGetCount()
    Loop count {
        idx := A_Index
        try {
            MonitorGet(idx, &l, &t, &r, &b)
            if (x >= l && x < r && y >= t && y < b)
                return idx
        } catch as _e {
        }
    }
    return 1
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

; 淇濆瓨鐨勫乏涓婅 + 褰撳墠绐楀彛灏哄鏄惁浠嶈惤鍦ㄨ櫄鎷熷睆骞曞唴锛堥伩鍏嶅鏄剧ず鍣?鍒嗚鲸鐜囧彉鍖栧悗绐楀彛鈥滃湪灞忓鈥濓級
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
        ; Cursor/VS Code/Electron may use custom cursors; default does not require IBeam.
        g_SelSense_RequireIBeam := (IniRead(cfg, "SelectionSense", "RequireIBeam", "0") = "1")
        mode := Trim(StrLower(IniRead(cfg, "SelectionSense", "HubCopyTriggerMode", "capslock")))
        ; 鍏煎鏃у€?single锛氳縼绉诲埌 capslock
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

; Gui object may throw before show; guard hwnd compare with try/catch.
SelectionSense_GuiHwndMatches(guiObj, hwnd) {
    if !hwnd || !IsObject(guiObj)
        return false
    try return (hwnd = guiObj.Hwnd)
    catch as _e {
        return false
    }
}

SelectionSense_IsKnownGuiRoot(hwnd) {
    if !hwnd
        return false
    global FloatingToolbarGUI, g_SCWV_Gui, g_CP_Gui, g_VK_Gui, g_PQP_Gui, g_SelSense_MenuGui
    global AIListPanelGUI, GuiID_ConfigGUI, GuiID_SearchCenter
    if (IsSet(FloatingToolbarGUI) && FloatingToolbarGUI && SelectionSense_GuiHwndMatches(FloatingToolbarGUI, hwnd))
        return true
    if (IsSet(g_SCWV_Gui) && g_SCWV_Gui && SelectionSense_GuiHwndMatches(g_SCWV_Gui, hwnd))
        return true
    if (IsSet(g_CP_Gui) && g_CP_Gui && SelectionSense_GuiHwndMatches(g_CP_Gui, hwnd))
        return true
    if (IsSet(g_VK_Gui) && g_VK_Gui && SelectionSense_GuiHwndMatches(g_VK_Gui, hwnd))
        return true
    if (IsSet(g_PQP_Gui) && g_PQP_Gui && SelectionSense_GuiHwndMatches(g_PQP_Gui, hwnd))
        return true
    if (IsSet(g_SelSense_MenuGui) && g_SelSense_MenuGui && SelectionSense_GuiHwndMatches(g_SelSense_MenuGui, hwnd))
        return true
    if (IsSet(AIListPanelGUI) && AIListPanelGUI && SelectionSense_GuiHwndMatches(AIListPanelGUI, hwnd))
        return true
    if (IsSet(GuiID_ConfigGUI) && GuiID_ConfigGUI && SelectionSense_GuiHwndMatches(GuiID_ConfigGUI, hwnd))
        return true
    if (IsSet(GuiID_SearchCenter) && GuiID_SearchCenter && SelectionSense_GuiHwndMatches(GuiID_SearchCenter, hwnd))
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
    global g_SelSense_Enabled, g_SelSense_LastClipSig, g_SelSense_LastFireTick
    global g_SelSense_LastFullText, g_SelSense_LastTick, g_SelSense_UserCopyInProgress, g_SelSense_UserCopyEndTick
    global g_SelSense_ClipWaitSec, CapsLockCopyInProgress

    if !g_SelSense_Enabled
        return
    if SelectionSense_CursorOverOurUi()
        return
    ; 鐢ㄦ埛涓诲姩 Ctrl+C 鍚庝竴娈垫椂闂村唴璺宠繃妯℃嫙 ^c锛岄伩鍏嶄笌缂栬緫鍣ㄥ唴澶嶅埗/绮樿创鎶㈠壀璐存澘
    if (g_SelSense_UserCopyInProgress || (A_TickCount - g_SelSense_UserCopyEndTick < 950))
        return
    if (CapsLockCopyInProgress)
        return

    ; Only when Hub is open and Cursor editor has focus do we simulate ^c for preview refresh.
    if !(SelectionSense_HubCapsuleHostIsOpen() && SelectionSense_IsCursorEditorActive()) {
        SelectionSense_ClearLastSelected()
        try FloatingToolbar_NotifySelectionClear()
        catch as _e {
        }
        return
    }

    clipSaved := ""
    try clipSaved := ClipboardAll()
    catch as _e {
        clipSaved := ""
    }

    A_Clipboard := ""
    try Send("^c")
    catch as _sendErr {
        try {
            if (clipSaved != "")
                A_Clipboard := clipSaved
        } catch as _e2 {
        }
        return
    }

    Sleep(SelectionSense_CopyDelayMsEffective())
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

    sig := StrLen(text) . ":" . SubStr(text, 1, 24)
    if (sig = g_SelSense_LastClipSig && (A_TickCount - g_SelSense_LastFireTick < 400))
        return
    g_SelSense_LastClipSig := sig
    g_SelSense_LastFireTick := A_TickCount

    g_SelSense_LastFullText := text
    g_SelSense_LastTick := A_TickCount

    try FloatingToolbar_NotifySelectionChange(text)
    catch as _e {
    }
    SelectionSense_QueueHubPreviewUpdate(text)
}

SelectionSense_EnsureMenuHost() {
    global g_SelSense_MenuGui, g_SelSense_MenuCtrl, g_SelSense_MenuWV2, g_SelSense_MenuReady

    if g_SelSense_MenuGui
        return

    global g_SelSense_MenuW, g_SelSense_MenuH
    ; +Resize锛欻ubCapsule 鍙充笅瑙掓嫋鏉′緷璧?AHK 鍚屾瀹夸富瀹介珮锛坔ub_resize_move / hub_resize_end锛?    ; 鍕跨敤 +E0x80000锛氭湭璋冪敤 SetLayeredWindowAttributes 鏃?WS_EX_LAYERED 浼氬鑷?WebView2 鏃犳硶鍛戒腑榧犳爣
    g_SelSense_MenuGui := Gui("+AlwaysOnTop +Resize +MinSize200x160 +MinimizeBox +MaximizeBox -DPIScale", "SelectionMenuHost")
    g_SelSense_MenuGui.BackColor := "1a1a1a"
    g_SelSense_MenuGui.MarginX := 0
    g_SelSense_MenuGui.MarginY := 0
    g_SelSense_MenuGui.Show("w" . g_SelSense_MenuW . " h" . g_SelSense_MenuH . " Hide")
    g_SelSense_MenuGui.OnEvent("Close", (*) => SelectionSense_HideMenu())
    g_SelSense_MenuGui.OnEvent("Size", SelectionSense_OnMenuHostSize)

    WebView2.create(g_SelSense_MenuGui.Hwnd, SelectionSense_OnMenuWebViewCreated)
}

SelectionSense_OnMenuHostSize(*) {
    SelectionSense_ApplyMenuBounds()
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
        ; Both SelectionMenu and HubCapsule emit selection_menu_ready.
        ; Flush pending segments only when current page is HubCapsule.
        if g_SelSense_MenuShowingHub
            SelectionSense_HubCapsule_FlushPendingSegments()
        if g_SelSense_MenuVisible {
            SelectionSense_PushMenuText(g_SelSense_PendingText)
            ; HubCapsule: send hub_preview again to avoid init race misses.
            if g_SelSense_MenuShowingHub && Trim(String(g_SelSense_PendingText)) != ""
                SelectionSense_PushHubPreviewText(g_SelSense_PendingText)
        }
        if g_SelSense_MenuShowingHub
            SelectionSense_PushHubCtxMenuSpec()
        return
    }
    if (typ = "hub_ready") {
        ; HubCapsule 鏄庣‘灏辩华锛氳ˉ鍙戝緟鎺ㄩ€佹钀?        SelectionSense_HubCapsule_FlushPendingSegments()
        SelectionSense_PushHubCtxMenuSpec()
        return
    }
    if (typ = "openWindowsRecycleBin") {
        SCWV_OpenWindowsRecycleBinFolder()
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
        ; 浜屾湡鍙€夛細澶栭摼 AI锛堢墰椹?PQP锛夊畬鎴愬悗鐢卞涓?WebView_QueuePayload draft_collect 鍥?Hub锛屽苟閰嶅悎鐢ㄦ埛寮€鍏宠嚜鍔ㄥ叆鑽夌
        SelectionSense_HideMenu()
        t2 := msg.Has("text") ? Trim(String(msg["text"])) : ""
        if (t2 != "") {
            sent := false
            try sent := SelectionSense_SendToNiumaChatAndSubmit(t2)
            catch as _e {
                sent := false
            }
            if !sent {
                try PromptQuickPad_OpenCaptureDraft(t2, true)
                catch as _e {
                }
            }
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
    if (typ = "hub_copy") {
        t2 := msg.Has("text") ? String(msg["text"]) : ""
        if (Trim(t2, " `t`r`n") != "")
            A_Clipboard := t2
        return
    }
    if (typ = "hub_copy_image") {
        p := msg.Has("imagePath") ? Trim(String(msg["imagePath"])) : ""
        if (p != "" && FileExist(p)) {
            try {
                pBitmap := Gdip_CreateBitmapFromFile(p)
                if (pBitmap) {
                    A_Clipboard := ""
                    Sleep(30)
                    Gdip_SetBitmapToClipboard(pBitmap)
                    Gdip_DisposeImage(pBitmap)
                }
            } catch as _e {
                try A_Clipboard := p
                catch {
                }
            }
        }
        return
    }
    if (typ = "hub_open_external_url") {
        u := msg.Has("url") ? Trim(String(msg["url"])) : ""
        if (u != "" && RegExMatch(u, "i)^https?://")) {
            try Run(u)
            catch as _e {
            }
        }
        return
    }
    if (typ = "hub_translate_sqlite_lookup") {
        global g_SelSense_MenuWV2
        rid := msg.Has("requestId") ? String(msg["requestId"]) : ""
        dir0 := msg.Has("dir") ? String(msg["dir"]) : "en2zh"
        txt0 := msg.Has("text") ? String(msg["text"]) : ""
        if (rid = "")
            return
        out := SelectionSense_HubDict_Lookup(dir0, txt0)
        try WebView_QueuePayload(g_SelSense_MenuWV2, Map(
            "type", "hub_translate_sqlite_result",
            "requestId", rid,
            "ok", (out != ""),
            "text", out,
            "reason", (out != "") ? "ok" : "no_match"
        ))
        return
    }
    if (typ = "hubScCtxCmd") {
        cmdId0 := msg.Has("cmdId") ? String(msg["cmdId"]) : ""
        idx0 := msg.Has("segmentIndex") ? Integer(msg["segmentIndex"]) : -1
        if (cmdId0 = "" || idx0 < 0)
            return
        txt0 := msg.Has("text") ? String(msg["text"]) : ""
        path0 := msg.Has("imagePath") ? Trim(String(msg["imagePath"])) : ""
        kind0 := msg.Has("kind") ? String(msg["kind"]) : "text"
        contentOut := txt0
        dataTypeOut := "text"
        if (kind0 = "image" && path0 != "" && FileExist(path0)) {
            contentOut := path0
            dataTypeOut := "file"
        } else if (kind0 = "image" && path0 != "") {
            contentOut := path0
            dataTypeOut := "Image"
        }
        title0 := SubStr(contentOut, 1, 120)
        if (title0 = "")
            title0 := "hub #" . (idx0 + 1)
        m0 := Map(
            "Title", title0,
            "Content", contentOut,
            "DataType", dataTypeOut,
            "OriginalDataType", kind0,
            "Source", "hub",
            "HubSegIndex", idx0,
            "ClipboardId", 0,
            "PromptMergedIndex", 0
        )
        try SC_ExecuteContextCommand(cmdId0, 0, m0)
        catch as err {
            OutputDebug("[Hub] hubScCtxCmd: " . err.Message)
        }
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
                    SelectionSense_InternalQueueDraftCollect(String(seg), "pending_flush")
            }
            g_SelSense_PendingHubSegments := []
        }
    } catch as _e {
    }
}

SelectionSense_SendToNiumaChatAndSubmit(text) {
    t := Trim(String(text), " `t`r`n")
    if (t = "")
        return false

    try ShowFloatingToolbar()
    catch as _e {
    }

    sent := false
    Loop 8 {
        try sent := FloatingToolbar_SendTextToNiumaChat(t, true, true, true)
        catch as _e {
            sent := false
        }
        if sent
            return true
        Sleep(120)
    }
    return false
}

; HubCapsule: preview-only update (does not push into segments).
SelectionSense_QueueHubPreviewUpdate(text, imagePath := "", imageDataUrl := "") {
    global g_SelSense_MenuWV2, g_SelSense_MenuReady, g_SelSense_PendingText, g_SelSense_IsManualCollected
    t := Trim(String(text), " `t`r`n")
    p := Trim(String(imagePath))
    d := Trim(String(imageDataUrl))
    if (t = "" && p = "" && d = "")
        return
    g_SelSense_IsManualCollected := false
    if (t != "")
        g_SelSense_PendingText := t
    if !(g_SelSense_MenuWV2 && g_SelSense_MenuReady)
        return
    m := Map("type", "preview_update")
    if (t != "")
        m["text"] := t
    if (p != "")
        m["imagePath"] := p
    if (d != "")
        m["imageDataUrl"] := d
    try WebView_QueuePayload(g_SelSense_MenuWV2, m)
    catch as _e {
    }
}

SelectionSense_InternalQueueDraftCollect(text, source := "") {
    global g_SelSense_MenuWV2, g_SelSense_MenuReady, g_SelSense_IsManualCollected
    if !(g_SelSense_MenuWV2 && g_SelSense_MenuReady)
        return
    g_SelSense_IsManualCollected := true
    m := Map("type", "draft_collect", "text", String(text))
    src := Trim(String(source))
    if (src != "")
        m["source"] := src
    try WebView_QueuePayload(g_SelSense_MenuWV2, m)
    catch as _e {
    }
}

; ===================== HubCapsule锛氫粠澶栭儴鎺ㄩ€佷竴娈垫枃鏈叆鏍?=====================
; Design: if HubCapsule is not ready yet, buffer and flush on selection_menu_ready.
SelectionSense_HubCapsule_PushSegmentText(text, draftSource := "capslock_copy") {
    global g_SelSense_MenuGui, g_SelSense_MenuWV2, g_SelSense_MenuReady, g_SelSense_MenuShowingHub
    global g_SelSense_PendingHubSegments, g_SelSense_NextNavPage

    t := Trim(String(text), " `t`r`n")
    if (t = "")
        return false

    ; Ensure HubCapsule host window is visible after CapsLock+C and retry if WebView isn't ready.
    try {
        global g_SelSense_MenuW, g_SelSense_MenuH, g_SelSense_MenuActivateOnShow, g_SelSense_MenuAnchorX, g_SelSense_MenuAnchorY
        SelectionSense_GetHubCapsuleDefaultSize(&defW, &defH)
        g_SelSense_MenuW := defW
        g_SelSense_MenuH := defH
        g_SelSense_MenuActivateOnShow := true
        CoordMode("Mouse", "Screen")
        MouseGetPos(&g_SelSense_MenuAnchorX, &g_SelSense_MenuAnchorY)
    } catch as _e {
    }

    ; 纭繚 WebView/椤甸潰鑷冲皯瀛樺湪涓斿鑸埌 HubCapsule
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

    ; Only push directly when current page is ready and truly HubCapsule.
    ; Otherwise message may land on SelectionMenu and be dropped.
    try {
        if (g_SelSense_MenuWV2 && g_SelSense_MenuReady && g_SelSense_MenuShowingHub) {
            SelectionSense_InternalQueueDraftCollect(t, draftSource)
            ; Ensure host window is visible (ShowMenu has its own retry timer).
            try SelectionSense_ShowMenuNearCursor()
            return true
        }
    } catch as _e {
    }

    try {
        if !(g_SelSense_PendingHubSegments is Array)
            g_SelSense_PendingHubSegments := []
        g_SelSense_PendingHubSegments.Push(t)
        ; 鍏堟妸绐楀彛鎷夊嚭鏉ワ紱寰?hub_ready/selection_menu_ready 鏃?flush 鍏ユ爤
        try SelectionSense_ShowMenuNearCursor()
    } catch as _e {
    }
    ; WebView 鏈?ready 鏃朵粎鍏ラ槦锛岃繑鍥?false 渚夸簬璋冪敤鏂瑰啀琛ュ彂棰勮/浜屾 Show
    return false
}

SelectionSense_PushHubCtxMenuSpec() {
    global g_SelSense_MenuWV2, g_SelSense_MenuReady, g_SelSense_MenuShowingHub
    if !(g_SelSense_MenuWV2 && g_SelSense_MenuReady && g_SelSense_MenuShowingHub)
        return
    spec := "[]"
    try {
        if IsSet(_VK_SceneCtxMenuItemsJson)
            spec := _VK_SceneCtxMenuItemsJson("scratchpad")
    } catch {
    }
    items := []
    try items := Jxon_Load(spec)
    catch {
    }
    try WebView_QueuePayload(g_SelSense_MenuWV2, Map("type", "hub_ctx_menu_spec", "items", items))
    catch {
    }
}

SelectionSense_PushMenuText(text) {
    global g_SelSense_MenuWV2, g_SelSense_MenuReady
    if !(g_SelSense_MenuWV2 && g_SelSense_MenuReady)
        return
    WebView_QueuePayload(g_SelSense_MenuWV2, Map("type", "selection_menu_init", "text", String(text)))
}

SelectionSense_PushHubPreviewText(text) {
    SelectionSense_QueueHubPreviewUpdate(text)
}

; For CapsLock+C: page/WebView may lag behind Show, so retry preview push once.
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

    ; WebView2.create is async; retry briefly until control is ready.
    if !g_SelSense_MenuCtrl {
        menuShowRetries++
        if (menuShowRetries < 180)
            SetTimer(SelectionSense_ShowMenuNearCursor, -55)
        else {
            menuShowRetries := 0
            if !hubWvWarned {
                hubWvWarned := true
                try TrayTip("HubCapsule failed to create WebView2 control.`nPlease install WebView2 Runtime and restart script.", "SelectionMenuHost", "Iconx 2")
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

; If Hub is visible and current page is HubCapsule, avoid duplicate Navigate/focus grab.
SelectionSense_HubCapsuleHostIsOpen() {
    global g_SelSense_MenuVisible, g_SelSense_MenuShowingHub
    return !!(g_SelSense_MenuVisible && g_SelSense_MenuShowingHub)
}

; 涓?~^c 鎵撳紑鐨?Hub 瀹屽叏涓€鑷达細鍙紶 overrideText锛圕apsLock+C 鐢級锛岀┖鍒欎粠 A_Clipboard 璇?; alsoPushSegment锛氫粎 CapsLock+C 闇€瑕佹妸鍐呭鍘嬪叆鍫嗗彔鍗＄墖鏃跺啀涓?true
SelectionSense_SyncHubFromUserCopyChannel(overrideText := "", alsoPushSegment := false, draftSource := "") {
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
    if (alsoPushSegment) {
        ds := Trim(String(draftSource))
        if (ds = "")
            ds := "capslock_copy"
        SelectionSense_HubCapsule_PushSegmentText(text, ds)
    }
    SetTimer(SelectionSense_HubCapsule_ResyncAfterCapsLockCopy.Bind(text), -250)
    SetTimer(SelectionSense_HubCapsule_ResyncAfterCapsLockCopy.Bind(text), -850)
}

SelectionSense_OpenHubAfterDoubleCopyTick(*) {
    SelectionSense_SyncHubFromUserCopyChannel("", true, "double_ctrl")
}

; 鎮诞宸ュ叿鏍忋€屾柊銆嶏細鎵撳紑 HubCapsule锛堣嫢鏈夎繎鏈熼€夊尯鍒欏甫鍏ラ瑙堬級
; useToolbarAnchor=true anchors near toolbar; false anchors near mouse.
; pendingTextOverride: direct preview payload (e.g. double Ctrl+C path).
SelectionSense_OpenHubCapsuleFromToolbar(useToolbarAnchor := true, pendingTextOverride := "") {
    global g_SelSense_MenuW, g_SelSense_MenuH, g_SelSense_MenuGui, g_SelSense_MenuWV2, g_SelSense_MenuCtrl
    global g_SelSense_MenuReady, g_SelSense_PendingText, g_SelSense_MenuAnchorX, g_SelSense_MenuAnchorY
    global g_SelSense_NextNavPage, g_SelSense_MenuActivateOnShow, FloatingToolbarGUI, g_SelSense_MenuShowingHub
    global g_SelSense_DoubleCopyHub_LastTick

    g_SelSense_DoubleCopyHub_LastTick := 0
    SelectionSense_GetHubCapsuleDefaultSize(&defW, &defH)
    g_SelSense_MenuW := defW
    g_SelSense_MenuH := defH
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
    global g_SelSense_MenuWV2, g_SelSense_MenuReady, g_SelSense_PendingText
    if (g_SelSense_MenuGui && g_SelSense_MenuVisible && g_SelSense_MenuShowingHub) {
        SelectionSense_HubCapsule_WriteSavedPos()
        try {
            if (g_SelSense_MenuWV2 && g_SelSense_MenuReady)
                WebView_QueuePayload(g_SelSense_MenuWV2, Map("type", "hub_dismiss_reset"))
        } catch as _e {
        }
    }
    g_SelSense_PendingText := ""
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

    ; CapsLock+C internal Send(^c) also triggers this hook.
    global CapsLockCopyInProgress
    if (CapsLockCopyInProgress)
        return

    g_SelSense_UserCopyInProgress := true
    g_SelSense_UserCopyEndTick := A_TickCount
    SetTimer(SelectionSense_ClearUserCopyFlag, -780)

    ; If not in Cursor editor, skip Hub-specific preview logic.
    if !SelectionSense_IsCursorEditorActive()
        return
    if SelectionSense_HubCapsuleHostIsOpen() {
        SetTimer(SelectionSense_RefreshHubPreviewAfterCopyTick, -140)
        return
    }

    ; Double Ctrl+C opens Hub entry flow; single Ctrl+C does not.
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

