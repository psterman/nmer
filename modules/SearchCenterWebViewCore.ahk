#Requires AutoHotkey v2.0

global g_SCWV_Gui := 0
global g_SCWV_Ctrl := 0
global g_SCWV_WV2 := 0
global g_SCWV_Ready := false
global g_SCWV_Visible := false
global g_SCWV_LastShown := 0  ; SCWV_Show 鍚庡闄愭湡锛岄伩鍏嶇偣鍑绘偓娴潯澶辩劍绔嬪埢 Hide 涓庝簩娆＄偣鍑绘姠璺?
global g_SCWV_SearchTimer := 0
global g_SCWV_FocusPending := false
global SearchCenterWebKeyword := ""
global SearchCenterSearchResults := []
global SearchCenterHasMoreData := false
global SearchCenterFilterType := ""
global SearchCenterCurrentLimit := 30
global g_SCWV_PendingJsonQueue := []  ; WebView 鏈?ready 鏃舵殏瀛橈紝ready 鍚庣敱 SCWV_FlushPendingJsonQueue 鍙戝嚭
global g_SCWV_RowCtxMenu := 0  ; 鍏煎鍗犱綅锛堟繁鑹茶彍鍗曚笉鍐嶄娇鐢ㄥ師鐢?Menu锛?
global g_SCWV_MenuActionRow := 0  ; 褰撳墠鑿滃崟瀵瑰簲鐨勫彲瑙佺粨鏋滆鍙凤紙1-based锛?
global g_SCWV_DarkCtxGui := 0  ; 鎼滅储缁撴灉琛屾繁鑹插彸閿彍鍗?GUI
global g_SCWV_DarkCtxHoverIdx := 0
global g_SCWV_DarkCtxCmdByIdx := Map()  ; 1-based琛屽彿 -> cmdId
global g_SCWV_DarkCtxSubSpecByIdx := Map()  ; 涓昏彍鍗曡鍙?-> 瀛愯彍鍗?children 鏁扮粍
global g_SCWV_DarkSubGui := 0
global g_SCWV_DarkSubCmdByIdx := Map()
global g_SCWV_DarkSubHoverIdx := 0
global g_SCWV_DarkSubMenuHoverTimer := 0
global g_SCWV_DarkMenuHoverTimer := 0  ; 鎮仠涓よ娓愬彉
global g_SCWV_DarkCtxItemCount := 0  ; 涓诲彸閿彍鍗曡鏁帮紙閬垮厤鐢?Gui.HasProp 妫€娴嬫帶浠讹紝閮ㄥ垎鐗堟湰浼氭姏閿欏鑷存案涓嶉珮浜級
global g_SCWV_DarkSubItemCount := 0
global g_SCWV_PinnedKeys := Map()  ; 缃《閿?id:xxx 鎴?c:鍐呭鍝堝笇
global g_SCWV_RecycleBin := []  ; 鍒犻櫎椤瑰揩鐓?{title,content,id}
global g_SCWV_PreviewCapabilityCache := Map() ; extDot -> {state, ts, ...}

SCWV_HostAlive() {
    global g_SCWV_Gui
    try {
        if !(IsObject(g_SCWV_Gui) && g_SCWV_Gui)
            return false
        hwnd := g_SCWV_Gui.Hwnd
        if !hwnd
            return false
        return !!WinExist("ahk_id " . hwnd)
    } catch {
        return false
    }
}

SCWV_ResetHostState() {
    global g_SCWV_Gui, g_SCWV_Ctrl, g_SCWV_WV2, g_SCWV_Ready, g_SCWV_Visible
    global g_SCWV_FocusPending, g_SCWV_PendingJsonQueue, GuiID_SearchCenter

    g_SCWV_Gui := 0
    g_SCWV_Ctrl := 0
    g_SCWV_WV2 := 0
    g_SCWV_Ready := false
    g_SCWV_Visible := false
    g_SCWV_FocusPending := false
    g_SCWV_PendingJsonQueue := []
    GuiID_SearchCenter := 0
    global g_SCWV_RowCtxMenu
    g_SCWV_RowCtxMenu := 0
    _SCWV_DestroyDarkRowMenus()
    try SCWV_Preview_UnloadNative()
    catch {
    }
}

SearchCenter_ShouldUseWebView() {
    return true
}

SCWV_IsVisible() {
    global g_SCWV_Visible
    return g_SCWV_Visible
}

SCWV_GetGui() {
    global g_SCWV_Gui
    return g_SCWV_Gui
}

SCWV_GetGuiHwnd() {
    global g_SCWV_Gui
    if g_SCWV_Gui {
        try return g_SCWV_Gui.Hwnd
    }
    return 0
}

; 打开 Windows 系统回收站（剪贴板 / Hub / PQP 等面板共用消息 type: openWindowsRecycleBin）
SCWV_OpenWindowsRecycleBinFolder() {
    try Run("explorer.exe shell:RecycleBinFolder")
    catch as err {
        try TrayTip("系统回收站", err.Message, "Iconx 2")
        catch as e2 {
        }
    }
}

_SCWV_IsDarkCtxMenuOpen() {
    global g_SCWV_DarkCtxGui
    if !IsObject(g_SCWV_DarkCtxGui) || !g_SCWV_DarkCtxGui
        return false
    try {
        h := g_SCWV_DarkCtxGui.Hwnd
        return h && WinExist("ahk_id " . h)
    } catch {
        return false
    }
}

SCWV_Init() {
    global g_SCWV_Gui

    if g_SCWV_Gui && SCWV_HostAlive()
        return
    if g_SCWV_Gui && !SCWV_HostAlive()
        SCWV_ResetHostState()

    ; 浣跨敤 Windows 鍘熺敓鏍囬鏍忎笌绯荤粺绐楀彛鎸夐挳锛堟渶灏忓寲/鏈€澶у寲/鍏抽棴锛?
    g_SCWV_Gui := Gui("+AlwaysOnTop +Resize +MinSize760x540 +MinimizeBox +MaximizeBox -DPIScale +Owner", "搜索中心")
    g_SCWV_Gui.BackColor := "1b1b1d"
    g_SCWV_Gui.MarginX := 0
    g_SCWV_Gui.MarginY := 0
    g_SCWV_Gui.OnEvent("Close", SCWV_OnGuiClose)
    g_SCWV_Gui.OnEvent("Size", SCWV_OnGuiResize)
    g_SCWV_Gui.Show("w1180 h760 Hide")

    WebView2.create(g_SCWV_Gui.Hwnd, SCWV_OnCreated)

    _SCWV_EnsureCurrentCategoryState()
    _SCWV_EnsureSearchDataReady()
}

SCWV_OnCreated(ctrl) {
    global g_SCWV_Ctrl, g_SCWV_WV2

    g_SCWV_Ctrl := ctrl
    g_SCWV_WV2 := ctrl.CoreWebView2

    try g_SCWV_Ctrl.DefaultBackgroundColor := 0xFF1B1B1D
    try g_SCWV_Ctrl.IsVisible := true

    SCWV_ApplyBounds()

    s := g_SCWV_WV2.Settings
    s.AreDefaultContextMenusEnabled := true
    s.IsStatusBarEnabled := false
    s.AreDevToolsEnabled := true

    g_SCWV_WV2.add_WebMessageReceived(SCWV_OnWebMessage)
    try g_SCWV_WV2.add_NavigationCompleted(SCWV_OnNavigationCompleted)

     try ApplyUnifiedWebViewAssets(g_SCWV_WV2)

    
    ; 映射物理驱动器到虚拟域名，允许 WebView2 播放本地媒体
    ; 1 = COREWEBVIEW2_HOST_RESOURCE_ACCESS_KIND_ALLOW
    try {
        g_SCWV_WV2.SetVirtualHostNameToFolderMapping("c.local", "C:\", 1)
        g_SCWV_WV2.SetVirtualHostNameToFolderMapping("d.local", "D:\", 1)
        g_SCWV_WV2.SetVirtualHostNameToFolderMapping("e.local", "E:\", 1)
    }
    catch {
    }
    
    g_SCWV_WV2.Navigate(BuildAppLocalUrl("SearchCenter.html"))
}

SCWV_OnGuiClose(*) {
    SCWV_Hide(true)
}

SCWV_OnGuiResize(GuiObj, MinMax, Width, Height) {
    if (MinMax = -1)
        return
    SCWV_ApplyBounds()
    try SCWV_Preview_OnHostLayoutChanged()
    catch {
    }
}

SCWV_OnNavigationCompleted(sender, args) {
    global g_SCWV_Visible

    if !g_SCWV_Visible
        return

    try ok := args.IsSuccess
    catch {
        ok := true
    }
    if !ok
        return

    SCWV_RefreshComposition()
}

SCWV_ApplyBounds() {
    global g_SCWV_Gui, g_SCWV_Ctrl

    if !g_SCWV_Gui || !g_SCWV_Ctrl
        return

    WinGetClientPos(, , &cw, &ch, g_SCWV_Gui.Hwnd)
    rc := WebView2.RECT()
    rc.left := 0
    rc.top := 0
    rc.right := cw
    rc.bottom := ch
    g_SCWV_Ctrl.Bounds := rc
}

; WebView 鍐呰仈杈撳叆渚濊禆瀹夸富婵€娲?+ WebView 鍙栫劍锛孖MM/TSF 鎵嶈兘绋冲畾闄勭潃锛堝惁鍒欒〃鐜颁负鏈夋椂涓枃銆佹湁鏃惰嫳鏂囧皬鍐欙級
SCWV_FocusForIME(*) {
    global g_SCWV_Gui, g_SCWV_Visible, g_SCWV_Ctrl, g_SCWV_WV2, g_SCWV_Ready
    if !g_SCWV_Visible || !g_SCWV_Gui || !g_SCWV_Ctrl
        return
    try {
        WinActivate("ahk_id " . g_SCWV_Gui.Hwnd)
        WebView2_MoveFocusProgrammatic(g_SCWV_Ctrl)
        if g_SCWV_Ready && g_SCWV_WV2
            WebView_QueueJson(g_SCWV_WV2, '{"type":"focus_input"}')
    } catch {
    }
}

SCWV_RefreshComposition(*) {
    global g_SCWV_Gui, g_SCWV_Ctrl, g_SCWV_Visible

    if !g_SCWV_Visible || !g_SCWV_Gui || !g_SCWV_Ctrl
        return

    try {
        SCWV_ApplyBounds()
        g_SCWV_Ctrl.NotifyParentWindowPositionChanged()
        SCWV_Preview_OnHostLayoutChanged()
    } catch {
    }
}

SCWV_Show() {
    global g_SCWV_Gui, g_SCWV_Visible, g_SCWV_Ready, g_SCWV_Ctrl, GuiID_SearchCenter, g_SCWV_LastShown, SearchCenterWebKeyword

    if !SCWV_HostAlive() {
        SCWV_ResetHostState()
        SCWV_Init()
    }
    if !g_SCWV_Gui
        SCWV_Init()

    GuiID_SearchCenter := g_SCWV_Gui

    if g_SCWV_Visible {
        try WinActivate("ahk_id " . g_SCWV_Gui.Hwnd)
        try WebView2_MoveFocusProgrammatic(g_SCWV_Ctrl)
        SetTimer(_SCWV_DeferredMoveFocus100, -100)
        try CapsLock_ScheduleNormalizeAfterChord()
        try SearchCenter_ScheduleIMEStabilize()
        return
    }

    try {
        g_SCWV_Gui.Show("w1180 h760 Center")
        try WinMaximize("ahk_id " . g_SCWV_Gui.Hwnd)
    } catch {
        ; 鍏滃簳锛氱獥鍙ｅ璞″瓨鍦ㄤ絾鍙ユ焺澶辨晥鏃堕噸寤轰竴娆★紝閬垮厤 鈥淕ui has no window鈥?        SCWV_ResetHostState()
        SCWV_Init()
        if !g_SCWV_Gui
            return
        g_SCWV_Gui.Show("w1180 h760 Center")
        try WinMaximize("ahk_id " . g_SCWV_Gui.Hwnd)
    }
    g_SCWV_Visible := true
    g_SCWV_LastShown := A_TickCount
    WMActivateChain_Register(SCWV_WM_ACTIVATE)

    SCWV_RefreshComposition()
    SetTimer(SCWV_RefreshComposition, -120)
    SetTimer(SCWV_RefreshComposition, -380)

    ; 窗口显示后，强制执行当前关键词搜索（若为空则自动触发 _SCWV_LoadSearchHistory）
    try {
        _SCWV_PerformSearch(SearchCenterWebKeyword)
    } catch {
        _SCWV_LoadSearchHistory() ; 降级处理：尝试直接载入历史，避开复杂搜索链路
    }

    if g_SCWV_Ready
        SCWV_PushState("init")
    else
        SetTimer(SCWV_DeferredPush, -250)

    try WebView2_MoveFocusProgrammatic(g_SCWV_Ctrl)
    SetTimer(_SCWV_DeferredMoveFocus100, -100)
    SetTimer(SCWV_FocusDeferred, -80)
    SCWV_RequestFocusInput()
    try CapsLock_ScheduleNormalizeAfterChord()
    try SearchCenter_ScheduleIMEStabilize()
}

_SCWV_DeferredMoveFocus100(*) {
    global g_SCWV_Gui, g_SCWV_Visible, g_SCWV_Ctrl
    if g_SCWV_Visible && g_SCWV_Gui
        WebView2_MoveFocusProgrammatic(g_SCWV_Ctrl)
}

SCWV_DeferredPush(*) {
    global g_SCWV_Visible, g_SCWV_Ready

    if !g_SCWV_Visible
        return

    if g_SCWV_Ready {
        SCWV_PushState("init")
    } else {
        SetTimer(SCWV_DeferredPush, -350)
    }
}

SCWV_FocusDeferred(*) {
    global g_SCWV_Gui, g_SCWV_Visible, g_SCWV_Ctrl

    if g_SCWV_Visible && g_SCWV_Gui {
        try WinActivate("ahk_id " . g_SCWV_Gui.Hwnd)
        WebView2_MoveFocusProgrammatic(g_SCWV_Ctrl)
    }
}

SCWV_RequestFocusInput() {
    global g_SCWV_WV2, g_SCWV_Ready, g_SCWV_FocusPending
    if g_SCWV_WV2 && g_SCWV_Ready {
        WebView_QueueJson(g_SCWV_WV2, '{"type":"focus_input"}')
        g_SCWV_FocusPending := false
        return
    }
    g_SCWV_FocusPending := true
}

SCWV_Hide(PersistSelection := true) {
    global g_SCWV_Gui, g_SCWV_Visible, g_SCWV_SearchTimer, GuiID_SearchCenter, g_SCWV_PendingJsonQueue

    if !SCWV_HostAlive() {
        SCWV_ResetHostState()
        return
    }

    ; 鍙栨秷 WM_ACTIVATE 寤惰繜鍏抽棴锛岄伩鍏嶇敤鎴峰凡鍦ㄥ伐鍏锋爮鍚屾 Hide 鍚?50ms 鍙堟墽琛屼竴娆?Hide/鍓綔鐢?    SetTimer(SCWV_WMDeactivateHideTick, 0)
    SetTimer(SCWV_DeferredPush, 0)
    SetTimer(SCWV_RefreshComposition, 0)
    SetTimer(_SCWV_DeferredMoveFocus100, 0)
    SetTimer(SCWV_FocusDeferred, 0)
    SetTimer(SCWV_FlushPendingJsonQueue, 0)
    g_SCWV_PendingJsonQueue := []

    if PersistSelection
        _SCWV_SaveCurrentCategorySelection()

    if g_SCWV_SearchTimer {
        SetTimer(g_SCWV_SearchTimer, 0)
        g_SCWV_SearchTimer := 0
    }

    g_SCWV_Visible := false
    WMActivateChain_Unregister(SCWV_WM_ACTIVATE)
    GuiID_SearchCenter := 0
    SearchCenterInvalidateGuiControlRefs()

    if g_SCWV_Gui {
        try g_SCWV_Gui.Hide()
    }
    try SCWV_Preview_UnloadNative()
    catch {
    }
}

; 澶辩劍鍚庡欢杩熷叧闂紙鍛藉悕瀹氭椂鍣紝渚夸簬 SCWV_Hide 鍙栨秷锛岄伩鍏嶄笌宸ュ叿鏍忎簩娆＄偣鍑荤珵鎬侊級
SCWV_WMDeactivateHideTick(*) {
    global g_SCWV_Visible, g_SCWV_Gui
    if !g_SCWV_Visible || !g_SCWV_Gui
        return
    if _SCWV_IsDarkCtxMenuOpen()
        return
    try {
        if (FloatingToolbar_IsForegroundToolbarOrChild())
            return
    } catch {
    }
    ; 长按 CapsLock 打开的 VK 会抢 WebView 焦点；若仍自动 Hide 搜索中心，会引发焦点风暴
    try {
        if VK_IsHostVisible()
            return
    } catch {
    }
    SCWV_Hide(true)
}

SCWV_WM_ACTIVATE(wParam, lParam, msg, hwnd) {
    global g_SCWV_Gui, g_SCWV_Visible, g_SCWV_LastShown

    if !g_SCWV_Visible || !g_SCWV_Gui
        return

    if (hwnd = g_SCWV_Gui.Hwnd && (wParam & 0xFFFF) = 0) {
        ; 鐢ㄦ埛鐐瑰嚮鍚岃繘绋嬫偓娴伐鍏锋爮鍒囨崲鍏抽棴鏃讹紝鍓嶅彴甯稿湪 WebView 瀛?HWND 涓婏紝椤昏瘑鍒涓婚摼锛屽嬁鎶㈠厛 Hide
        try {
            if (FloatingToolbar_IsForegroundToolbarOrChild())
                return
        } catch {
        }
        ; 虚拟键盘已显示时，失焦常因焦点进入 VK 的 WebView2，勿关闭搜索中心
        try {
            if VK_IsHostVisible()
                return
        } catch {
        }
        if _SCWV_IsDarkCtxMenuOpen()
            return
        if (g_SCWV_LastShown && (A_TickCount - g_SCWV_LastShown < 500))
            return
        SetTimer(SCWV_WMDeactivateHideTick, -50)
    }
}

SCWV_FlushPendingJsonQueue(*) {
    global g_SCWV_WV2, g_SCWV_Ready, g_SCWV_PendingJsonQueue
    if !g_SCWV_WV2 {
        return
    }
    if !g_SCWV_Ready {
        if (g_SCWV_PendingJsonQueue.Length)
            SetTimer(SCWV_FlushPendingJsonQueue, -80)
        return
    }
    while g_SCWV_PendingJsonQueue.Length {
        item := g_SCWV_PendingJsonQueue.RemoveAt(1)
        if (item is Map) && item.Has("obj")
            WebView_QueuePayload(g_SCWV_WV2, item["obj"])
        else if (item is Map) && item.Has("str")
            WebView_QueueJson(g_SCWV_WV2, item["str"])
    }
}

SCWV_PostJson(jsonStr) {
    global g_SCWV_WV2, g_SCWV_Ready, g_SCWV_PendingJsonQueue

    if !g_SCWV_WV2
        return
    if !g_SCWV_Ready {
        if (g_SCWV_PendingJsonQueue.Length >= 64)
            g_SCWV_PendingJsonQueue.RemoveAt(1)
        if (IsObject(jsonStr))
            g_SCWV_PendingJsonQueue.Push(Map("obj", jsonStr))
        else
            g_SCWV_PendingJsonQueue.Push(Map("str", String(jsonStr)))
        SetTimer(SCWV_FlushPendingJsonQueue, -50)
        return
    }
    if (IsObject(jsonStr))
        WebView_QueuePayload(g_SCWV_WV2, jsonStr)
    else
        WebView_QueueJson(g_SCWV_WV2, jsonStr)
}

SCWV_BeginHostDrag(*) {
    global g_SCWV_Gui
    if !g_SCWV_Gui
        return
    try PostMessage(0xA1, 2,,, "ahk_id " . g_SCWV_Gui.Hwnd)  ; WM_NCLBUTTONDOWN HTCAPTION
}

SCWV_MinimizeHost(*) {
    global g_SCWV_Gui
    if !g_SCWV_Gui
        return
    try WinMinimize("ahk_id " . g_SCWV_Gui.Hwnd)
}

SCWV_ToggleMaximizeHost(*) {
    global g_SCWV_Gui
    if !g_SCWV_Gui
        return
    hwndExpr := "ahk_id " . g_SCWV_Gui.Hwnd
    try {
        state := WinGetMinMax(hwndExpr)
        if (state = 1) {
            WinRestore(hwndExpr)
        } else {
            WinMaximize(hwndExpr)
        }
    }
}

SCWV_OnWebMessage(sender, args) {
    jsonStr := args.WebMessageAsJson
    try {
        msg := Jxon_Load(jsonStr)
    } catch {
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

    action := msg.Has("type") ? msg["type"] : (msg.Has("action") ? msg["action"] : "")
    if (action = "")
        return

    switch action {
        case "ready":
            global g_SCWV_Ready
            g_SCWV_Ready := true
            SCWV_PushState("init")
            try SCWV_FlushPendingJsonQueue()
            if g_SCWV_FocusPending
                SCWV_RequestFocusInput()
        case "search":
            keyword := msg.Has("keyword") ? String(msg["keyword"]) : ""
            _SCWV_PerformSearch(keyword)
            SCWV_PushState("state")
        case "setCategory":
            if msg.Has("category")
                _SCWV_SetCategoryByKey(String(msg["category"]))
            SCWV_PushState("state")
        case "setFilter":
            global SearchCenterFilterType
            nextFilter := msg.Has("filterType") ? String(msg["filterType"]) : ""
            SearchCenterFilterType := (SearchCenterFilterType = nextFilter) ? "" : nextFilter
            SCWV_PushState("state")
        case "setLimit":
            global SearchCenterCurrentLimit, SearchCenterEverythingLimit
            val := msg.Has("limit") ? Integer(msg["limit"]) : 50
            if (val <= 0)
                val := 50
            SearchCenterCurrentLimit := val
            SearchCenterEverythingLimit := val
            _SCWV_PerformSearch(SearchCenterWebKeyword)
            SCWV_PushState("state")
        case "loadMore":
            offset := msg.Has("offset") ? Integer(msg["offset"]) : 0
            if (offset < 0)
                offset := 0
            _SCWV_PerformSearch(SearchCenterWebKeyword, offset)
            SCWV_PushState("state")
        case "toggleEngine":
            if msg.Has("engine")
                _SCWV_ToggleEngine(String(msg["engine"]))
            SCWV_PushState("state")
        case "batchSearch":
            _SCWV_BatchSearch()
        case "webSearch":
            _SCWV_BatchSearch()
        case "cliSend":
            prompt := msg.Has("prompt") ? String(msg["prompt"]) : ""
            _SCWV_SendToCLI(prompt)
        case "cliOpen":
            OpenSelectedCLIAgents()
        case "activateResult":
            row := msg.Has("row") ? Integer(msg["row"]) : 0
            _SCWV_ActivateResultRow(row)
        case "searchCenterContextMenu":
            row := msg.Has("row") ? Integer(msg["row"]) : 0
            sx := msg.Has("screenX") ? Integer(msg["screenX"]) : 0
            sy := msg.Has("screenY") ? Integer(msg["screenY"]) : 0
            _SCWV_ShowSearchCenterRowMenu(row, sx, sy)
        case "close":
            SCWV_Hide(true)
        case "dragHost":
            SCWV_BeginHostDrag()
        case "windowMinimize":
            SCWV_MinimizeHost()
        case "windowToggleMaximize":
            SCWV_ToggleMaximizeHost()
        case "searchCenterRestoreRecycle":
            idx := msg.Has("index") ? Integer(msg["index"]) : 0
            SC_SearchCenterRestoreRecycleAt(idx)
        case "searchCenterEmptyRecycle":
            SC_SearchCenterEmptyRecycleBin()
        case "openWindowsRecycleBin":
            SCWV_OpenWindowsRecycleBinFolder()
        case "WEB_PREVIEW_TEXT":
            p := msg.Has("path") ? String(msg["path"]) : ""
            sq := msg.Has("seq") ? Integer(msg["seq"]) : 0
            SCWV_Preview_OnWebText(p, sq)
        case "WEB_PREVIEW_IMAGE":
            p := msg.Has("path") ? String(msg["path"]) : ""
            sq := msg.Has("seq") ? Integer(msg["seq"]) : 0
            SCWV_Preview_OnWebImage(p, sq)
        case "NATIVE_PREVIEW":
            p := msg.Has("path") ? String(msg["path"]) : ""
            sq := msg.Has("seq") ? Integer(msg["seq"]) : 0
            bmap := msg.Has("bounds") && (msg["bounds"] is Map) ? msg["bounds"] : 0
            SCWV_Preview_OnNative(p, sq, bmap)
        case "PREVIEW_NATIVE_STOP":
            SCWV_Preview_UnloadNative()
        case "QUICKLOOK":
            p := msg.Has("path") ? String(msg["path"]) : ""
            SCWV_Preview_TryQuickLook(p)
        case "INVOKE_IPREVIEW":
            p := msg.Has("path") ? String(msg["path"]) : ""
            sq := msg.Has("seq") ? Integer(msg["seq"]) : 0
            bmap := msg.Has("bounds") && (msg["bounds"] is Map) ? msg["bounds"] : 0
            try SCWV_Preview_Get().InvokeNative(p, sq, bmap)
            catch as err {
                SCWV_PostJson(Map("type", "NATIVE_PREVIEW_FAILED", "message", err.Message))
            }
        case "INVOKE_WEB_MEDIA":
            p := msg.Has("path") ? String(msg["path"]) : ""
            sq := msg.Has("seq") ? Integer(msg["seq"]) : 0
            u := _SCWV_PathToWebAssetUrl(p)
            try SCWV_Preview_Get()._PostDetailMeta(p, sq)
            SCWV_PostJson(Map("type", "WEB_PREVIEW_MEDIA_RESULT", "url", u, "seq", sq))
        case "INVOKE_PDFIUM":
            p := msg.Has("path") ? String(msg["path"]) : ""
            sq := msg.Has("seq") ? Integer(msg["seq"]) : 0
            SCWV_Preview_OnPdfium(p, sq)
    }
}

SCWV_QueueSearch(keyword) {
    global g_SCWV_SearchTimer, SearchCenterWebKeyword

    SearchCenterWebKeyword := keyword

    if g_SCWV_SearchTimer {
        SetTimer(g_SCWV_SearchTimer, 0)
        g_SCWV_SearchTimer := 0
    }

    fn := _SCWV_FireSearch.Bind()
    g_SCWV_SearchTimer := fn
    SetTimer(fn, -150)
}

_SCWV_FireSearch(*) {
    global g_SCWV_SearchTimer, SearchCenterWebKeyword

    g_SCWV_SearchTimer := 0
    _SCWV_PerformSearch(SearchCenterWebKeyword)
    SCWV_PushState("state")
}

_SCWV_PerformSearch(keyword, offset := 0) {
    global SearchCenterSearchResults, SearchCenterCurrentLimit, SearchCenterHasMoreData, SearchCenterFilterType, SearchCenterWebKeyword

    keyword := Trim(String(keyword))
    ; 鍓嶇 debounce 鍚庡彂 {type:search} 鏃跺彧浼?keyword 杩涙湰鍑芥暟锛屾湭鍐欏洖 SearchCenterWebKeyword锛?    ; SCWV_PushState 浠嶇敤鏃у叏灞€锛堝父涓虹┖锛夛紝applyState 浼氭妸 #search 璁炬垚绌轰覆 鈫?杈撳叆琚竻绌恒€侀€夊尯涓㈠け鏃犳硶澶嶅埗銆?    if (offset = 0)
        SearchCenterWebKeyword := keyword

    if (offset = 0)
        SearchCenterSearchResults := []

    if (offset = 0 && keyword != "")
        _SCWV_RecordSearchHistory(keyword)

    if (keyword = "") {
        SearchCenterHasMoreData := false
        _SCWV_LoadSearchHistory()
        return
    }

    NewResults := []
    SearchCenterHasMoreData := false

    try {
        FilterDataTypes := GetSearchCenterDataTypesForFilter(SearchCenterFilterType)
        if (FilterDataTypes.Length > 0) {
            hasFileType := false
            for _, dt in FilterDataTypes {
                if (dt = "file") {
                    hasFileType := true
                    break
                }
            }
            if !hasFileType
                FilterDataTypes.Push("file")
        }

        AllDataResults := SearchAllDataSources(keyword, FilterDataTypes, SearchCenterCurrentLimit, offset)
        for _, TypeData in AllDataResults {
            if (IsObject(TypeData) && TypeData.HasProp("HasMore") && TypeData.HasMore) {
                SearchCenterHasMoreData := true
                break
            }
        }

        for DataType, TypeData in AllDataResults {
            if !(IsObject(TypeData) && TypeData.HasProp("Items"))
                continue

            for _, Item in TypeData.Items {
                TimeDisplay := ""
                if (Item.HasProp("TimeFormatted")) {
                    TimeDisplay := Item.TimeFormatted
                } else if (Item.HasProp("Timestamp")) {
                    try {
                        TimeDisplay := FormatTime(Item.Timestamp, "yyyy-MM-dd HH:mm:ss")
                    } catch {
                        TimeDisplay := Item.Timestamp
                    }
                }

                TitleText := ""
                if (Item.HasProp("DisplayTitle") && Item.DisplayTitle != "") {
                    TitleText := Item.DisplayTitle
                } else if (Item.HasProp("Title") && Item.Title != "") {
                    TitleText := Item.Title
                } else if (Item.HasProp("Content") && Item.Content != "") {
                    TitleText := SubStr(Item.Content, 1, 50)
                    if (StrLen(Item.Content) > 50)
                        TitleText .= "..."
                }

                ItemDataType := ""
                if (Item.HasProp("Metadata") && IsObject(Item.Metadata) && Item.Metadata.Has("DataType") && Item.Metadata["DataType"] != "") {
                    ItemDataType := Item.Metadata["DataType"]
                } else if (Item.HasProp("DataType") && Item.DataType != "") {
                    if (Item.DataType != "clipboard" && Item.DataType != "template" && Item.DataType != "config" && Item.DataType != "file" && Item.DataType != "hotkey" && Item.DataType != "function" && Item.DataType != "ui")
                        ItemDataType := Item.DataType
                }

                if (ItemDataType = "" && DataType = "clipboard") {
                    if (Item.HasProp("DataTypeName") && Item.DataTypeName != "") {
                        DataTypeName := Item.DataTypeName
                        if (DataTypeName = "代码片段" || DataTypeName = "代码")
                            ItemDataType := "Code"
                        else if (DataTypeName = "链接")
                            ItemDataType := "Link"
                        else if (DataTypeName = "邮箱" || DataTypeName = "邮件")
                            ItemDataType := "Email"
                        else if (DataTypeName = "图片")
                            ItemDataType := "Image"
                        else if (DataTypeName = "颜色")
                            ItemDataType := "Color"
                        else if (DataTypeName = "文本" || DataTypeName = "剪贴板历史")
                            ItemDataType := "Text"
                    }
                }

                if (ItemDataType = "" && DataType != "clipboard") {
                    if (DataType = "template")
                        ItemDataType := "Template"
                    else if (DataType = "config")
                        ItemDataType := "Config"
                    else if (DataType = "file")
                        ItemDataType := "File"
                    else if (DataType = "hotkey")
                        ItemDataType := "Hotkey"
                    else if (DataType = "function")
                        ItemDataType := "Function"
                    else if (DataType = "ui")
                        ItemDataType := "UI"
                }

                if (ItemDataType = "")
                    ItemDataType := (DataType = "clipboard") ? "Text" : DataType

                ResultItem := {
                    Title: TitleText,
                    Source: TypeData.HasProp("DataTypeName") ? TypeData.DataTypeName : DataType,
                    DataType: ItemDataType,
                    Time: TimeDisplay,
                    Content: Item.HasProp("Content") ? Item.Content : TitleText,
                    ID: Item.HasProp("ID") ? Item.ID : "",
                    OriginalDataType: DataType
                }
                if (Item.HasProp("Metadata") && IsObject(Item.Metadata))
                    ResultItem.Metadata := Item.Metadata
                if (Item.HasProp("DisplayTitle") && Item.DisplayTitle != "")
                    ResultItem.DisplayTitle := Item.DisplayTitle
                if (Item.HasProp("Category") && Item.Category != "")
                    ResultItem.Category := Item.Category
                if (Item.HasProp("TypeHint") && Item.TypeHint != "")
                    ResultItem.TypeHint := Item.TypeHint
                if (Item.HasProp("FzyCategoryBonus"))
                    ResultItem.FzyCategoryBonus := Item.FzyCategoryBonus
                if (Item.HasProp("DisplayPath") && Item.DisplayPath != "")
                    ResultItem.DisplayPath := Item.DisplayPath
                if (Item.HasProp("DisplaySubtitle") && Item.DisplaySubtitle != "")
                    ResultItem.DisplaySubtitle := Item.DisplaySubtitle
                if (Item.HasProp("SubCategory") && Item.SubCategory != "")
                    ResultItem.SubCategory := Item.SubCategory
                if (Item.HasProp("CategoryColor") && Item.CategoryColor != "")
                    ResultItem.CategoryColor := Item.CategoryColor
                if (Item.HasProp("PathTrust"))
                    ResultItem.PathTrust := Item.PathTrust
                if (Item.HasProp("BonusTotal"))
                    ResultItem.BonusTotal := Item.BonusTotal
                if (Item.HasProp("PenaltyTotal"))
                    ResultItem.PenaltyTotal := Item.PenaltyTotal
                if (Item.HasProp("FzyBase"))
                    ResultItem.FzyBase := Item.FzyBase
                if (Item.HasProp("FinalScore"))
                    ResultItem.FinalScore := Item.FinalScore
                if (Item.HasProp("QuotaCategory"))
                    ResultItem.QuotaCategory := Item.QuotaCategory

                if (offset = 0)
                    SearchCenterSearchResults.Push(ResultItem)
                else
                    NewResults.Push(ResultItem)
            }
        }
    } catch as err {
        OutputDebug("SCWV search error: " . err.Message)
    }

    if (offset > 0 && NewResults.Length > 0) {
        for _, item in NewResults
            SearchCenterSearchResults.Push(item)
    }

    if (offset = 0 && SearchCenterSearchResults.Length > 0 && StrLen(keyword) > 0) {
        try {
            Loop SearchCenterSearchResults.Length {
                scItem := SearchCenterSearchResults[A_Index]
                SyncIdentityToResultItem(&scItem, keyword)
            }
        } catch {
        }
    }

    if (offset = 0 && SearchCenterSearchResults.Length > 0) {
        try SortSearchCenterMergedResults(&SearchCenterSearchResults, keyword)
        try _SCWV_SortPinnedFirst(SearchCenterSearchResults)
    }
}

_SCWV_ResultPinKey(Item) {
    if !IsObject(Item)
        return ""
    id := Item.HasProp("ID") ? Trim(String(Item.ID)) : ""
    if (id != "")
        return "id:" . id
    c := Item.HasProp("Content") ? Item.Content : (Item.HasProp("Title") ? Item.Title : "")
    return "c:" . StrLen(c) . ":" . SubStr(c, 1, 200)
}

_SCWV_SortPinnedFirst(arr) {
    global g_SCWV_PinnedKeys
    if !(arr is Array) || arr.Length = 0
        return
    pinned := []
    rest := []
    for it in arr {
        k := _SCWV_ResultPinKey(it)
        if (k != "" && g_SCWV_PinnedKeys.Has(k) && g_SCWV_PinnedKeys[k])
            pinned.Push(it)
        else
            rest.Push(it)
    }
    arr.Length := 0
    for it in pinned
        arr.Push(it)
    for it in rest
        arr.Push(it)
}

_SCWV_LoadDefaultTemplatesData() {
    global SearchCenterSearchResults, PromptTemplates

    SearchCenterSearchResults := []
    if !PromptTemplates
        LoadPromptTemplates()

    for template in PromptTemplates {
        SearchCenterSearchResults.Push({
            Title: template.Title,
            Content: template.Content,
            Source: "模板",
            DataType: "template",
            Time: "",
            OriginalDataType: "template"
        })
    }
}

_SCWV_GetFilteredResults() {
    global SearchCenterSearchResults, SearchCenterVisibleResults, SearchCenterFilterType, g_SCWV_PinnedKeys

    FilteredResults := []
    for _, res in SearchCenterSearchResults {
        ShouldInclude := false
        if (SearchCenterFilterType = "") {
            ShouldInclude := true
        } else if (SearchCenterFilterType = "clipboard") {
            ShouldInclude := (res.HasProp("OriginalDataType") && res.OriginalDataType = "clipboard") || (res.HasProp("Source") && InStr(res.Source, "剪贴板") > 0)
        } else if (SearchCenterFilterType = "template") {
            ShouldInclude := (res.HasProp("OriginalDataType") && res.OriginalDataType = "template") || (res.HasProp("Source") && (InStr(res.Source, "模板") > 0 || InStr(res.Source, "提示词") > 0))
        } else if (SearchCenterFilterType = "config") {
            ShouldInclude := (res.HasProp("OriginalDataType") && res.OriginalDataType = "config") || (res.HasProp("Source") && InStr(res.Source, "配置") > 0)
        } else if (SearchCenterFilterType = "hotkey") {
            ShouldInclude := (res.HasProp("OriginalDataType") && res.OriginalDataType = "hotkey") || (res.HasProp("Source") && InStr(res.Source, "快捷键") > 0)
        } else if (SearchCenterFilterType = "function") {
            ShouldInclude := (res.HasProp("OriginalDataType") && res.OriginalDataType = "function") || (res.HasProp("Source") && InStr(res.Source, "功能") > 0)
        } else if (SearchCenterFilterType = "File") {
            ShouldInclude := (res.HasProp("OriginalDataType") && res.OriginalDataType = "file") || (res.HasProp("DataType") && res.DataType = "File") || (res.HasProp("Source") && InStr(res.Source, "文件") > 0)
        } else if (SearchCenterFilterType = "pinned") {
            pk := _SCWV_ResultPinKey(res)
            ShouldInclude := (pk != "" && g_SCWV_PinnedKeys.Has(pk) && g_SCWV_PinnedKeys[pk])
        }

        if ShouldInclude
            FilteredResults.Push(res)
    }

    SearchCenterVisibleResults := FilteredResults
    return FilteredResults
}

SCWV_PushState(msgType := "state") {
    global SearchCenterWebKeyword, SearchCenterCurrentLimit, SearchCenterSelectedEngines, SearchCenterFilterType
    global SearchCenterHasMoreData
    global g_SCWV_RecycleBin, g_SCWV_PinnedKeys

    if !SearchCenter_ShouldUseWebView()
        return

    visible := _SCWV_GetFilteredResults()
    results := []
    for index, item in visible {
        rowTitle := (item.HasProp("DisplayTitle") && item.DisplayTitle != "") ? item.DisplayTitle : item.Title
        rowSubtitle := (item.HasProp("DisplaySubtitle") && item.DisplaySubtitle != "") ? item.DisplaySubtitle : item.Source
        typeDisplay := item.HasProp("DataType") ? item.DataType : ""
        if (item.HasProp("OriginalDataType") && item.OriginalDataType = "file" && item.HasProp("Category") && item.Category != "") {
            try typeDisplay := FileClassifier.GetCategoryDisplayName(item.Category)
        } else if (typeDisplay != "") {
            try typeDisplay := GetContentTypeDisplayName(typeDisplay)
        }
        pkRow := _SCWV_ResultPinKey(item)
        isPinned := (pkRow != "" && g_SCWV_PinnedKeys.Has(pkRow) && g_SCWV_PinnedKeys[pkRow])
        filePath := ""
        if (item.HasProp("OriginalDataType") && item.OriginalDataType = "file") || (item.HasProp("DataType") && (item.DataType = "File" || item.DataType = "Folder")) {
            cand := item.HasProp("Content") ? Trim(String(item.Content)) : ""
            if (cand != "" && FileExist(cand))
                filePath := cand
        }
        results.Push(Map(
            "row", index,
            "title", rowTitle,
            "subtitle", rowSubtitle,
            "type", typeDisplay,
            "time", item.HasProp("Time") ? item.Time : "",
            "preview", item.HasProp("Content") ? SubStr(item.Content, 1, 180) : rowTitle,
            "previewText", BuildSearchCenterPreviewText(item),
            "dataType", item.HasProp("DataType") ? item.DataType : "",
            "source", item.HasProp("Source") ? item.Source : "",
            "content", item.HasProp("Content") ? item.Content : rowTitle,
            "path", filePath,
            "pinned", isPinned ? true : false
        ))
    }

    recycleBin := []
    Loop g_SCWV_RecycleBin.Length {
        i := A_Index
        ent := g_SCWV_RecycleBin[i]
        if !(ent is Map)
            continue
        recycleBin.Push(Map(
            "index", i,
            "title", ent.Has("title") ? String(ent["title"]) : "",
            "preview", SubStr(ent.Has("content") ? String(ent["content"]) : "", 1, 140)
        ))
    }

    currentCategoryKey := GetSearchCenterCurrentCategoryKey()
    status := "本地结果 " . results.Length . " 条"
    status .= " · 已选引擎 " . (IsObject(SearchCenterSelectedEngines) ? SearchCenterSelectedEngines.Length : 0) . " 个"
    status .= " 路 褰撳墠闄愬埗 " . SearchCenterCurrentLimit

    payload := Map(
        "type", msgType,
        "keyword", SearchCenterWebKeyword,
        "limit", SearchCenterCurrentLimit,
        "categories", _SCWV_BuildCategoryPayload(),
        "currentCategoryKey", currentCategoryKey,
        "engines", _SCWV_BuildEnginePayload(currentCategoryKey),
        "selectedEngines", _SCWV_CopyArray(SearchCenterSelectedEngines),
        "filters", _SCWV_BuildFilterPayload(),
        "filterType", SearchCenterFilterType,
        "results", results,
        "statusLine", status,
        "isCliCategory", (currentCategoryKey = "cli") ? true : false,
        "canRun", Trim(SearchCenterWebKeyword) != "",
        "canOpenCli", (currentCategoryKey = "cli") ? true : false,
        "hasMore", SearchCenterHasMoreData ? true : false,
        "total", results.Length,
        "recycleBin", recycleBin,
        "recycleCount", recycleBin.Length
    )

    try SCWV_PostJson(payload)
}

_SCWV_BuildFilterPayload() {
    return [
        Map("key", "", "text", "全部"),
        Map("key", "File", "text", "文件"),
        Map("key", "clipboard", "text", "剪贴板"),
        Map("key", "template", "text", "提示词"),
        Map("key", "config", "text", "配置"),
        Map("key", "hotkey", "text", "快捷键"),
        Map("key", "function", "text", "功能"),
        Map("key", "pinned", "text", "置顶")
    ]
}

_SCWV_BuildCategoryPayload() {
    Categories := GetSearchCenterCategories()
    payload := []
    for _, Category in Categories {
        engines := _SCWV_LoadSelectedEngines(Category.Key)
        payload.Push(Map(
            "key", Category.Key,
            "text", Category.Text,
            "selectedCount", engines.Length
        ))
    }
    return payload
}

_SCWV_BuildEnginePayload(CategoryKey) {
    engines := GetSortedSearchEngines(CategoryKey)
    payload := []
    for _, engine in engines {
        iconPath := GetSearchEngineIcon(engine.Value)
        payload.Push(Map(
            "name", engine.Name,
            "value", engine.Value,
            "iconUrl", _SCWV_PathToWebAssetUrl(iconPath)
        ))
    }
    return payload
}

_SCWV_PathToWebAssetUrl(path) {
    p := Trim(path)
    if (p = "" || !FileExist(p))
        return ""

    ; 浼樺厛妫€鏌ユ槸鍚﹀湪鑴氭湰鐩綍鍐咃紙璧勪骇鐩綍锛?
    scriptRoot := StrReplace(A_ScriptDir, "\", "/")
    normalized := StrReplace(p, "\", "/")
    
    resUrl := ""
    if (SubStr(normalized, 1, 1) != "/" && SubStr(normalized, 2, 1) != ":") {
        ; 鐩稿璺緞
    } else {
        scriptRootWithSlash := scriptRoot . "/"
        if (SubStr(normalized, 1, StrLen(scriptRootWithSlash)) = scriptRootWithSlash) {
            relativePath := SubStr(normalized, StrLen(scriptRootWithSlash) + 1)
            resUrl := BuildAppAssetUrl(relativePath)
        }
    }

    if (resUrl = "" && RegExMatch(p, "^([a-zA-Z]):\\", &m)) {
        drive := StrLower(m[1])
        relativePath := SubStr(p, 4)
        encodedSegs := []
        for _, seg in StrSplit(relativePath, "\") {
            if (seg = "")
                continue
            encodedSegs.Push(_SCWV_UrlEncode(seg))
        }
        resUrl := "https://" . drive . ".local/" . _SCWV_JoinArray(encodedSegs, "/")
    }

    return resUrl
}

_SCWV_JoinArray(arr, sep := ",") {
    out := ""
    for i, v in arr {
        if (i > 1)
            out .= sep
        out .= String(v)
    }
    return out
}

_SCWV_UrlEncode(str) {
    fEscaped := ""
    Loop Parse, str {
        if RegExMatch(A_LoopField, "[0-9a-zA-Z\-\.\_\~\/]")
            fEscaped .= A_LoopField
        else {
            buf := Buffer(4, 0)
            len := StrPut(A_LoopField, buf, "UTF-8")
            Loop len - 1 {
                fEscaped .= "%" . Format("{:02X}", NumGet(buf, A_Index - 1, "UChar"))
            }
        }
    }
    return fEscaped
}

_SCWV_UrlDecode(str) {
    res := ""
    i := 1
    while i <= StrLen(str) {
        c := SubStr(str, i, 1)
        if (c = "%") {
            buf := Buffer(StrLen(str) // 3 + 1, 0)
            count := 0
            while i <= StrLen(str) && SubStr(str, i, 1) = "%" {
                hex := SubStr(str, i + 1, 2)
                NumPut("char", "0x" . hex, buf, count++)
                i += 3
            }
            res .= StrGet(buf, count, "UTF-8")
        } else {
            res .= c
            i += 1
        }
    }
    return res
}

_SCWV_CopyArray(arr) {
    out := []
    if !IsObject(arr)
        return out
    for _, v in arr
        out.Push(v)
    return out
}

_SCWV_EnsureCurrentCategoryState() {
    global SearchCenterSelectedEngines

    Categories := GetSearchCenterCategories()
    if (Categories.Length = 0)
        return

    currentKey := GetSearchCenterCurrentCategoryKey()
    SearchCenterSelectedEngines := _SCWV_LoadSelectedEngines(currentKey)
}

_SCWV_SaveCurrentCategorySelection() {
    global SearchCenterSelectedEngines

    CategoryKey := GetSearchCenterCurrentCategoryKey()
    _SCWV_SaveSelectedEngines(CategoryKey, SearchCenterSelectedEngines)
}

_SCWV_SetCategoryByKey(CategoryKey) {
    global SearchCenterCurrentCategory, SearchCenterSelectedEngines

    _SCWV_SaveCurrentCategorySelection()

    Categories := GetSearchCenterCategories()
    for index, Category in Categories {
        if (Category.Key = CategoryKey) {
            SearchCenterCurrentCategory := index - 1
            break
        }
    }
    SearchCenterSelectedEngines := _SCWV_LoadSelectedEngines(CategoryKey)
}

_SCWV_LoadSelectedEngines(CategoryKey) {
    global SearchCenterSelectedEnginesByCategory, ConfigFile

    if (!IsSet(SearchCenterSelectedEnginesByCategory) || !IsObject(SearchCenterSelectedEnginesByCategory))
        SearchCenterSelectedEnginesByCategory := Map()

    if (SearchCenterSelectedEnginesByCategory.Has(CategoryKey))
        return _SCWV_CopyArray(SearchCenterSelectedEnginesByCategory[CategoryKey])

    Engines := []
    try {
        CategoryEnginesStr := IniRead(ConfigFile, "Settings", "SearchCenterSelectedEngines_" . CategoryKey, "")
        if (CategoryEnginesStr != "") {
            if (InStr(CategoryEnginesStr, ":") > 0)
                CategoryEnginesStr := SubStr(CategoryEnginesStr, InStr(CategoryEnginesStr, ":") + 1)
            for _, Engine in StrSplit(CategoryEnginesStr, ",") {
                Engine := Trim(Engine)
                if (Engine != "")
                    Engines.Push(Engine)
            }
        }
    } catch {
    }

    ; 鍏煎鏃х増鏈細娓呴櫎鍘嗗彶榛樿椤癸紙鍚?openclaw/codex_cli锛夛紝閬垮厤鑷姩閫変腑
    if (Engines.Length = 1) {
        legacy := StrLower(Trim(Engines[1]))
        if (legacy = "codex_cli" || legacy = "openclaw" || legacy = "openclaw_cli")
            Engines := []
    }

    ; 浠呬繚鐣欏綋鍓嶅垎绫讳腑鏈夋晥鐨勫紩鎿庡€硷紝闃叉璺ㄥ垎绫绘畫鐣欏鑷磋鏁板紓甯革紙渚嬪 AI 鏄剧ず 1锛?
    valid := Map()
    try {
        for _, engine in GetSortedSearchEngines(CategoryKey) {
            ev := engine.HasProp("Value") ? String(engine.Value) : ""
            if (ev != "")
                valid[ev] := true
        }
    } catch {
    }
    filtered := []
    for _, ev in Engines {
        v := String(ev)
        if (v != "" && valid.Has(v))
            filtered.Push(v)
    }
    Engines := filtered

    ; CLI 鍒嗙被涓嶅啀璁剧疆榛樿寮曟搸锛屽繀椤荤敱鐢ㄦ埛鎵嬪姩閫夋嫨鍚庢墠鐢熸晥

    SearchCenterSelectedEnginesByCategory[CategoryKey] := _SCWV_CopyArray(Engines)
    return Engines
}

_SCWV_SaveSelectedEngines(CategoryKey, Engines) {
    global SearchCenterSelectedEnginesByCategory, ConfigFile

    if (!IsSet(SearchCenterSelectedEnginesByCategory) || !IsObject(SearchCenterSelectedEnginesByCategory))
        SearchCenterSelectedEnginesByCategory := Map()

    SearchCenterSelectedEnginesByCategory[CategoryKey] := _SCWV_CopyArray(Engines)

    EnginesStr := ""
    if IsObject(Engines) {
        for index, Engine in Engines {
            if (index > 1)
                EnginesStr .= ","
            EnginesStr .= Engine
        }
    }
    try IniWrite(CategoryKey . ":" . EnginesStr, ConfigFile, "Settings", "SearchCenterSelectedEngines_" . CategoryKey)
}

_SCWV_ToggleEngine(EngineValue) {
    global SearchCenterSelectedEngines

    CategoryKey := GetSearchCenterCurrentCategoryKey()
    if !IsObject(SearchCenterSelectedEngines)
        SearchCenterSelectedEngines := []

    idx := ArrayContainsValue(SearchCenterSelectedEngines, EngineValue)
    if (CategoryKey = "cli") {
        if (idx > 0)
            SearchCenterSelectedEngines.RemoveAt(idx)
        else
            SearchCenterSelectedEngines := [EngineValue]
    } else if (idx > 0) {
        SearchCenterSelectedEngines.RemoveAt(idx)
    } else {
        SearchCenterSelectedEngines.Push(EngineValue)
    }

    _SCWV_SaveSelectedEngines(CategoryKey, SearchCenterSelectedEngines)
}

_SCWV_EnsureSearchDataReady() {
    global SearchCenterSearchResults, SearchCenterWebKeyword

    if (Trim(SearchCenterWebKeyword) = "") {
        if !IsObject(SearchCenterSearchResults) || SearchCenterSearchResults.Length = 0
            _SCWV_LoadDefaultTemplatesData()
        return
    }

    if !IsObject(SearchCenterSearchResults) || SearchCenterSearchResults.Length = 0
        _SCWV_PerformSearch(SearchCenterWebKeyword)
}

_SCWV_BatchSearch() {
    global SearchCenterSelectedEngines, SearchCenterWebKeyword

    Keyword := Trim(SearchCenterWebKeyword)
    if (Keyword = "") {
        TrayTip("请输入搜索关键词", "提示", "Icon! 2")
        return
    }
    if (!IsObject(SearchCenterSelectedEngines) || SearchCenterSelectedEngines.Length = 0) {
        TrayTip("请至少选择一个搜索引擎", "提示", "Icon! 2")
        return
    }
    
    _SCWV_RecordSearchHistory(Keyword)

    for index, Engine in SearchCenterSelectedEngines {
        if (Engine = "")
            continue
        SendVoiceSearchToBrowser(Keyword, Engine)
        if (index < SearchCenterSelectedEngines.Length)
            Sleep(300)
    }
}

_SCWV_SendToCLI(prompt) {
    global SearchCenterWebKeyword

    if (Trim(prompt) = "")
        prompt := Trim(SearchCenterWebKeyword)

    if (prompt = "") {
        TrayTip("请输入要发送给 AI 的内容", "提示", "Icon! 2")
        return
    }
    
    _SCWV_RecordSearchHistory(prompt)

    LaunchSelectedCLIAgents(prompt)
}

; 搜索中心结果执行：smartTextSearch=true 时，在有关键词且非文件/链接情况下用内容二次搜索（右键“立即执行”）；双击仍为粘贴
SC_ActivateSearchResultItem(Item, doHide := true, smartTextSearch := false) {
    if !IsObject(Item)
        return

    Content := Item.HasProp("Content") ? Item.Content : Item.Title
    DataType := ""
    if (Item.HasProp("DataType") && Item.DataType != "") {
        DataType := Item.DataType
    } else if (Item.HasProp("Metadata") && IsObject(Item.Metadata) && Item.Metadata.Has("DataType")) {
        DataType := Item.Metadata["DataType"]
    }

    origDt := Item.HasProp("OriginalDataType") ? Item.OriginalDataType : ""
    isFileLike := (DataType = "file" || DataType = "File" || DataType = "Folder" || origDt = "file")

    if doHide {
        SCWV_Hide(true)
        Sleep(60)
    }

    if (isFileLike) {
        try {
            if (FileExist(Content) || DirExist(Content))
                Run(Content)
            else
                TrayTip("路径不存在", Content, "Iconx 2")
        } catch as err {
            TrayTip("打开失败", err.Message, "Iconx 2")
        }
        return
    }

    if (DataType = "Link") {
        try Run(Content)
        catch as err {
            TrayTip("打开链接失败", err.Message, "Iconx 2")
        }
        return
    }

    if (DataType = "Image") {
        try {
            if FileExist(Content)
                Run(Content)
            else
                TrayTip("图片文件不存在", Content, "Iconx 2")
        } catch as err {
            TrayTip("打开图片失败", err.Message, "Iconx 2")
        }
        return
    }

    kw := Trim(SearchCenterWebKeyword)
    if (smartTextSearch && kw != "" && !isFileLike && DataType != "Link" && DataType != "Image") {
        SearchCenter_RunQueryWithKeyword(Content)
        return
    }

    try {
        A_Clipboard := Content
        Sleep(80)
        Send("^v")
    } catch as err {
        TrayTip("粘贴失败", err.Message, "Iconx 2")
    }
}

_SCWV_ActivateResultRow(Row) {
    global SearchCenterWebKeyword
    Item := GetSearchCenterResultItemByRow(Row)
    if (SearchCenterWebKeyword != "")
        _SCWV_RecordSearchHistory(SearchCenterWebKeyword)
    SC_ActivateSearchResultItem(Item, true, false)
}

; 选区感应 / 拖放：写入关键词、打开搜索中心并执行搜索（供工具栏 WebView、SelectionSense）
SearchCenter_RunQueryWithKeyword(keyword) {
    global SearchCenterWebKeyword, g_SCWV_SearchTimer

    keyword := Trim(String(keyword))
    if (keyword = "")
        return

    SearchCenterWebKeyword := keyword

    if g_SCWV_SearchTimer {
        SetTimer(g_SCWV_SearchTimer, 0)
        g_SCWV_SearchTimer := 0
    }

    try {
        SCWV_Init()
        SCWV_Show()
        _SCWV_PerformSearch(SearchCenterWebKeyword)
        SCWV_PushState("state")
        SCWV_RequestFocusInput()
    } catch {
        ; 鍏滃簳閲嶈瘯锛氳閬挎棫鍙ユ焺澶辨晥瀵艰嚧鐨勫伓鍙戞墦寮€澶辫触
        SCWV_ResetHostState()
        SCWV_Init()
        SCWV_Show()
        _SCWV_PerformSearch(SearchCenterWebKeyword)
        SCWV_PushState("state")
        SCWV_RequestFocusInput()
    }
}

_SCWV_CommandExists(cmdId) {
    global g_Commands
    c := Trim(String(cmdId))
    if (c = "")
        return false
    if !(IsSet(g_Commands) && g_Commands is Map && g_Commands.Has("CommandList"))
        return false
    cl := g_Commands["CommandList"]
    return (cl is Map) && cl.Has(c)
}

_SCWV_CmdDisplayName(cmdId) {
    global g_Commands
    c := Trim(String(cmdId))
    if !(IsSet(g_Commands) && g_Commands is Map && g_Commands.Has("CommandList"))
        return c
    cl := g_Commands["CommandList"]
    if !(cl is Map) || !cl.Has(c)
        return c
    ent := cl[c]
    if ent is Map && ent.Has("name")
        return String(ent["name"])
    return c
}

_SCWV_AniMenuShow(hwnd) {
    if !hwnd
        return
    try DllCall("user32\AnimateWindow", "ptr", hwnd, "uint", 100, "uint", 0x80000)
    catch {
    }
}

; 涓庡壀璐存澘鍙抽敭锛?px 姗欒壊鎻忚竟 + 8px 鍐呰竟璺濓紱琛岄珮 34
_SCWV_DarkMenuLayout(&frm, &itemPad, &itemH, &innerTop) {
    frm := 1
    itemPad := 8
    itemH := 34
    innerTop := frm + itemPad
}

; Win11 DWM 圆角（失败则忽略）
_SCWV_DarkMenuRoundCorners(hwnd) {
    if !hwnd
        return
    attr := Buffer(4, 0)
    NumPut("uint", 2, attr)
    try DllCall("dwmapi\DwmSetWindowAttribute", "ptr", hwnd, "uint", 33, "ptr", attr, "uint", 4)
    catch {
    }
}

_SCWV_FilterCtxChildrenByToolbar(childTemplates, specIdSet) {
    out := []
    if !(childTemplates is Array) || !(specIdSet is Map)
        return out
    for ch in childTemplates {
        if !(ch is Map)
            continue
        cid := ch.Has("id") ? Trim(String(ch["id"])) : ""
        if (cid != "" && specIdSet.Has(cid))
            out.Push(ch)
    }
    return out
}

_SCWV_SearchCtxPasteToChildren() {
    return [
        Map("id", "cp_ctx_pastePlain", "t", "粘贴纯文本"),
        Map("id", "cp_ctx_pasteWithNewline", "t", "粘贴并换行"),
        Map("id", "cp_ctx_pastePath", "t", "粘贴路径"),
        Map("id", "cp_ctx_copyToClipboard", "t", "复制到剪贴板")
    ]
}

_SCWV_SearchCtxCopyToChildren() {
    return [
        Map("id", "sc_copy_path", "t", "复制路径"),
        Map("id", "sc_copy_url", "t", "复制链接"),
        Map("id", "sc_copy_link", "t", "复制路径/链接（兼容）"),
        Map("id", "sc_copy_digit", "t", "复制数字"),
        Map("id", "sc_copy_chinese", "t", "复制中文"),
        Map("id", "sc_copy_md", "t", "复制 Markdown")
    ]
}

_SCWV_SearchCtxSendChildren() {
    return [
        Map("id", "sc_to_draft", "t", "发送到草稿本"),
        Map("id", "sc_to_prompt", "t", "发送到提示词中心"),
        Map("id", "sc_to_openclaw", "t", "发送到 OpenClaw"),
        Map("id", "sc_send_desktop", "t", "发送到桌面（复制文件）"),
        Map("id", "sc_send_documents", "t", "发送到文档（复制文件）"),
        Map("id", "sc_open_sendto_folder", "t", "打开“发送到”文件夹")
    ]
}

_SCWV_AppendSearchCtxStandardBlock(&out, specIds) {
    ; 绮樿创绫讳笌宸ュ叿鏍忔Ы浣嶆棤鍏筹細鎼滅储涓績缁熶竴鎻愪緵鍥涢」锛堥潪鍓创鏉跨粨鏋滄墽琛屾椂浼氭彁绀猴級
    pCh := _SCWV_SearchCtxPasteToChildren()
    if pCh.Length
        out.Push(Map("k", "sub", "t", "粘贴到 ▶", "children", pCh))
    out.Push(Map("k", "cmd", "id", "sc_copy", "t", "复制"))
    cCh := _SCWV_FilterCtxChildrenByToolbar(_SCWV_SearchCtxCopyToChildren(), specIds)
    if cCh.Length
        out.Push(Map("k", "sub", "t", "复制到 ▶", "children", cCh))
    sCh := _SCWV_FilterCtxChildrenByToolbar(_SCWV_SearchCtxSendChildren(), specIds)
    if sCh.Length
        out.Push(Map("k", "sub", "t", "发送到 ▶", "children", sCh))
}

_SCWV_RegroupSearchCtxSpec(baseSpec, Item) {
    global g_SCWV_PinnedKeys
    specIds := Map()
    for ent0 in baseSpec {
        if ent0 is Map && ent0.Has("id") {
            id0 := Trim(String(ent0["id"]))
            if (id0 != "")
                specIds[id0] := true
        }
    }
    pasteToIds := Map()
    for s in ["cp_ctx_pastePlain", "cp_ctx_pasteWithNewline", "cp_ctx_pastePath", "cp_ctx_copyToClipboard"]
        pasteToIds[s] := true
    copyTopIds := Map()
    copyTopIds["sc_copy"] := true
    copyTopIds["sc_copy_plain"] := true
    copyToIds := Map()
    for s in ["sc_copy_path", "sc_copy_url", "sc_copy_link", "sc_copy_digit", "sc_copy_chinese", "sc_copy_md"]
        copyToIds[s] := true
    sendIds := Map()
    for s in ["sc_to_draft", "sc_to_prompt", "sc_to_openclaw", "sc_send_desktop", "sc_send_documents", "sc_open_sendto_folder"]
        sendIds[s] := true
    blockIns := false
    out := []
    for ent in baseSpec {
        if !(ent is Map)
            continue
        cid := ent.Has("id") ? Trim(String(ent["id"])) : ""
        if (cid = "sc_pin_item") {
            pk := _SCWV_ResultPinKey(Item)
            pinned := (pk != "" && g_SCWV_PinnedKeys.Has(pk) && g_SCWV_PinnedKeys[pk])
            out.Push(Map("k", "cmd", "id", cid, "t", pinned ? "取消置顶" : "置顶"))
            continue
        }
        if pasteToIds.Has(cid) || copyTopIds.Has(cid) || copyToIds.Has(cid) || sendIds.Has(cid) {
            if !blockIns {
                _SCWV_AppendSearchCtxStandardBlock(&out, specIds)
                blockIns := true
            }
            continue
        }
        out.Push(ent)
    }
    if !blockIns
        _SCWV_AppendSearchCtxStandardBlock(&out, specIds)
    return out
}

; 涓昏彍鍗曢」鍙充晶瀵归綈瀛愯彍鍗曞乏涓婅锛堜笌鐐瑰嚮灞曞紑浣跨敤鍚屼竴濂楀潗鏍囷級
_SCWV_DarkCtxComputeSubXY(idx, &subX, &subY) {
    global g_SCWV_DarkCtxGui
    subX := A_ScreenWidth // 2
    subY := A_ScreenHeight // 2
    if !g_SCWV_DarkCtxGui
        return
    _SCWV_DarkMenuLayout(&Df, &Pad, &itemH, &innerTop)
    try {
        WinGetPos(&WX, &WY, &WW, &WH, "ahk_id " . g_SCWV_DarkCtxGui.Hwnd)
        subX := WX + WW - 4
        subY := WY + innerTop + (idx - 1) * itemH
    } catch {
    }
}

_SCWV_DarkMenuHoverPhase2(idx, *) {
    global g_SCWV_DarkCtxGui, g_SCWV_DarkCtxHoverIdx, g_SCWV_DarkMenuHoverTimer
    g_SCWV_DarkMenuHoverTimer := 0
    if !g_SCWV_DarkCtxGui || g_SCWV_DarkCtxHoverIdx != idx
        return
    try {
        g_SCWV_DarkCtxGui["ScCtxBg" . idx].BackColor := "ff6600"
        g_SCWV_DarkCtxGui["ScCtxTx" . idx].Opt("cFFFFFF")
    } catch {
    }
}

_SCWV_DarkSubMenuHoverPhase2(idx, *) {
    global g_SCWV_DarkSubGui, g_SCWV_DarkSubHoverIdx, g_SCWV_DarkSubMenuHoverTimer
    g_SCWV_DarkSubMenuHoverTimer := 0
    if !g_SCWV_DarkSubGui || g_SCWV_DarkSubHoverIdx != idx
        return
    try {
        g_SCWV_DarkSubGui["ScSubBg" . idx].BackColor := "ff6600"
        g_SCWV_DarkSubGui["ScSubTx" . idx].Opt("cFFFFFF")
    } catch {
    }
}

_SCWV_DestroyDarkSubMenus(*) {
    global g_SCWV_DarkSubGui, g_SCWV_DarkSubCmdByIdx, g_SCWV_DarkSubHoverIdx, g_SCWV_DarkSubMenuHoverTimer
    SetTimer(_SCWV_CheckDarkSubCtxMouse, 0)
    if g_SCWV_DarkSubMenuHoverTimer {
        SetTimer(g_SCWV_DarkSubMenuHoverTimer, 0)
        g_SCWV_DarkSubMenuHoverTimer := 0
    }
    g_SCWV_DarkSubCmdByIdx := Map()
    g_SCWV_DarkSubHoverIdx := 0
    global g_SCWV_DarkSubItemCount
    g_SCWV_DarkSubItemCount := 0
    if IsSet(g_SCWV_DarkSubGui) && g_SCWV_DarkSubGui {
        try g_SCWV_DarkSubGui.Destroy()
        catch {
        }
        g_SCWV_DarkSubGui := 0
    }
}

_SCWV_DestroyDarkRowMenus(*) {
    global g_SCWV_DarkCtxGui, g_SCWV_DarkCtxHoverIdx, g_SCWV_DarkCtxCmdByIdx, g_SCWV_RowCtxMenu
    global g_SCWV_DarkCtxSubSpecByIdx, g_SCWV_DarkMenuHoverTimer
    SetTimer(_SCWV_CheckDarkSearchCtxMouse, 0)
    SetTimer(_SCWV_CloseDarkSearchCtxIfOutside, 0)
    if g_SCWV_DarkMenuHoverTimer {
        SetTimer(g_SCWV_DarkMenuHoverTimer, 0)
        g_SCWV_DarkMenuHoverTimer := 0
    }
    _SCWV_DestroyDarkSubMenus()
    g_SCWV_DarkCtxSubSpecByIdx := Map()
    g_SCWV_DarkCtxHoverIdx := 0
    g_SCWV_DarkCtxCmdByIdx := Map()
    global g_SCWV_DarkCtxItemCount
    g_SCWV_DarkCtxItemCount := 0
    if IsSet(g_SCWV_DarkCtxGui) && g_SCWV_DarkCtxGui {
        try g_SCWV_DarkCtxGui.Destroy()
        catch {
        }
        g_SCWV_DarkCtxGui := 0
    }
    g_SCWV_RowCtxMenu := 0
}

; 会弹出资源管理器 / 系统属性 / UAC 的命令：勿立刻把焦点抢回搜索中心
_SCWV_ShouldRefocusSearchAfterCmd(cmdId) {
    c := Trim(String(cmdId))
    if (c = "sc_open_path" || c = "sc_run_as_admin")
        return false
    return true
}

_SCWV_DarkSearchItemApplyHover(idx) {
    global g_SCWV_DarkCtxGui, g_SCWV_DarkCtxHoverIdx, g_SCWV_DarkMenuHoverTimer, g_SCWV_DarkCtxSubSpecByIdx
    if g_SCWV_DarkCtxHoverIdx = idx
        return
    if g_SCWV_DarkMenuHoverTimer {
        SetTimer(g_SCWV_DarkMenuHoverTimer, 0)
        g_SCWV_DarkMenuHoverTimer := 0
    }
    if g_SCWV_DarkCtxHoverIdx > 0 {
        try {
            g_SCWV_DarkCtxGui["ScCtxBg" . g_SCWV_DarkCtxHoverIdx].BackColor := "1a1a1a"
            g_SCWV_DarkCtxGui["ScCtxTx" . g_SCWV_DarkCtxHoverIdx].Opt("cff6600")
        } catch {
        }
    }
    g_SCWV_DarkCtxHoverIdx := idx
    if idx > 0 {
        try {
            g_SCWV_DarkCtxGui["ScCtxBg" . idx].BackColor := "2a2622"
            g_SCWV_DarkCtxGui["ScCtxTx" . idx].Opt("cffb366")
        } catch {
        }
        if g_SCWV_DarkCtxSubSpecByIdx.Has(idx) {
            try {
                ch := g_SCWV_DarkCtxSubSpecByIdx[idx]
                _SCWV_DarkCtxComputeSubXY(idx, &sx, &sy)
                _SCWV_ShowDarkSubMenuAt(ch, sx, sy)
            } catch {
            }
        } else
            _SCWV_DestroyDarkSubMenus()
        fn := _SCWV_DarkMenuHoverPhase2.Bind(idx)
        g_SCWV_DarkMenuHoverTimer := fn
        SetTimer(fn, -50)
    }
}

_SCWV_CheckDarkSearchCtxMouse(*) {
    global g_SCWV_DarkCtxGui, g_SCWV_DarkCtxHoverIdx, g_SCWV_DarkSubGui, g_SCWV_DarkCtxItemCount
    if !g_SCWV_DarkCtxGui
        return
    try {
        if !g_SCWV_DarkCtxGui.Hwnd || !WinExist("ahk_id " . g_SCWV_DarkCtxGui.Hwnd) {
            _SCWV_DestroyDarkRowMenus()
            return
        }
    } catch {
        _SCWV_DestroyDarkRowMenus()
        return
    }
    try {
        MouseGetPos(&MX, &MY)
        if g_SCWV_DarkSubGui {
            try {
                WinGetPos(&SX, &SY, &SW, &SH, "ahk_id " . g_SCWV_DarkSubGui.Hwnd)
                if (MX >= SX && MX <= SX + SW && MY >= SY && MY <= SY + SH) {
                    if g_SCWV_DarkCtxHoverIdx > 0
                        _SCWV_DarkSearchItemApplyHover(0)
                    return
                }
            } catch {
            }
        }
        WinGetPos(&WX, &WY, &WW, &WH, "ahk_id " . g_SCWV_DarkCtxGui.Hwnd)
    } catch {
        return
    }
    if MX < WX || MX > WX + WW || MY < WY || MY > WY + WH {
        if g_SCWV_DarkCtxHoverIdx > 0
            _SCWV_DarkSearchItemApplyHover(0)
        return
    }
    _SCWV_DarkMenuLayout(&Df, &Pad, &MenuItemHeight, &innerTop)
    RelX := MX - WX
    RelY := MY - WY
    if RelY < innerTop || RelX < innerTop {
        if g_SCWV_DarkCtxHoverIdx > 0
            _SCWV_DarkSearchItemApplyHover(0)
        return
    }
    ItemIndex := Floor((RelY - innerTop) / MenuItemHeight) + 1
    if (ItemIndex < 1 || ItemIndex > g_SCWV_DarkCtxItemCount) {
        if g_SCWV_DarkCtxHoverIdx > 0
            _SCWV_DarkSearchItemApplyHover(0)
        return
    }
    ItemY := innerTop + (ItemIndex - 1) * MenuItemHeight
    if RelY >= ItemY && RelY < ItemY + MenuItemHeight && RelX >= innerTop && RelX < WW - innerTop
        _SCWV_DarkSearchItemApplyHover(ItemIndex)
    else if g_SCWV_DarkCtxHoverIdx > 0
        _SCWV_DarkSearchItemApplyHover(0)
}

_SCWV_CloseDarkSearchCtxIfOutside(*) {
    global g_SCWV_DarkCtxGui, g_SCWV_DarkSubGui
    if !g_SCWV_DarkCtxGui
        return
    try {
        MouseGetPos(&MX, &MY)
        WinGetPos(&WX, &WY, &WW, &WH, "ahk_id " . g_SCWV_DarkCtxGui.Hwnd)
        inMain := (MX >= WX && MX <= WX + WW && MY >= WY && MY <= WY + WH)
        inSub := false
        if g_SCWV_DarkSubGui {
            try {
                WinGetPos(&SX, &SY, &SW, &SH, "ahk_id " . g_SCWV_DarkSubGui.Hwnd)
                inSub := (MX >= SX && MX <= SX + SW && MY >= SY && MY <= SY + SH)
            } catch {
            }
        }
        if inMain || inSub
            return
        if GetKeyState("LButton", "P") || GetKeyState("RButton", "P")
            _SCWV_DestroyDarkRowMenus()
    } catch {
        _SCWV_DestroyDarkRowMenus()
    }
}

_SCWV_OnDarkSubMenuClick(idx, *) {
    global g_SCWV_DarkSubCmdByIdx, g_SCWV_MenuActionRow, g_SCWV_Gui
    c := g_SCWV_DarkSubCmdByIdx.Has(idx) ? g_SCWV_DarkSubCmdByIdx[idx] : ""
    row := g_SCWV_MenuActionRow
    if (c != "") {
        global g_SCWV_DarkSubGui
        try {
            if g_SCWV_DarkSubGui {
                g_SCWV_DarkSubGui["ScSubBg" . idx].BackColor := "ffc48a"
                g_SCWV_DarkSubGui["ScSubTx" . idx].Opt("c1a1a1a")
            }
        } catch {
        }
        Sleep(42)
    }
    _SCWV_DestroyDarkRowMenus()
    SetTimer(SCWV_WMDeactivateHideTick, 0)
    if (c != "")
        SC_ExecuteContextCommand(c, row)
    if _SCWV_ShouldRefocusSearchAfterCmd(c) && g_SCWV_Gui {
        try WinActivate("ahk_id " . g_SCWV_Gui.Hwnd)
        catch as _ea {
        }
    }
    if _SCWV_ShouldRefocusSearchAfterCmd(c) {
        try SCWV_RequestFocusInput()
        catch as _eb {
        }
    }
}

_SCWV_CheckDarkSubCtxMouse(*) {
    global g_SCWV_DarkSubGui, g_SCWV_DarkSubHoverIdx, g_SCWV_DarkSubMenuHoverTimer, g_SCWV_DarkSubItemCount
    if !g_SCWV_DarkSubGui
        return
    try {
        if !g_SCWV_DarkSubGui.Hwnd || !WinExist("ahk_id " . g_SCWV_DarkSubGui.Hwnd) {
            _SCWV_DestroyDarkSubMenus()
            return
        }
    } catch {
        _SCWV_DestroyDarkSubMenus()
        return
    }
    _SCWV_DarkMenuLayout(&Df, &Pad, &MenuItemHeight, &innerTop)
    try {
        MouseGetPos(&MX, &MY)
        WinGetPos(&WX, &WY, &WW, &WH, "ahk_id " . g_SCWV_DarkSubGui.Hwnd)
    } catch {
        return
    }
    if MX < WX || MX > WX + WW || MY < WY || MY > WY + WH {
        if g_SCWV_DarkSubMenuHoverTimer {
            SetTimer(g_SCWV_DarkSubMenuHoverTimer, 0)
            g_SCWV_DarkSubMenuHoverTimer := 0
        }
        if g_SCWV_DarkSubHoverIdx > 0 {
            try {
                g_SCWV_DarkSubGui["ScSubBg" . g_SCWV_DarkSubHoverIdx].BackColor := "1a1a1a"
                g_SCWV_DarkSubGui["ScSubTx" . g_SCWV_DarkSubHoverIdx].Opt("cff6600")
            } catch {
            }
            g_SCWV_DarkSubHoverIdx := 0
        }
        return
    }
    RelY := MY - WY
    if RelY < innerTop {
        if g_SCWV_DarkSubMenuHoverTimer {
            SetTimer(g_SCWV_DarkSubMenuHoverTimer, 0)
            g_SCWV_DarkSubMenuHoverTimer := 0
        }
        if g_SCWV_DarkSubHoverIdx > 0 {
            try {
                g_SCWV_DarkSubGui["ScSubBg" . g_SCWV_DarkSubHoverIdx].BackColor := "1a1a1a"
                g_SCWV_DarkSubGui["ScSubTx" . g_SCWV_DarkSubHoverIdx].Opt("cff6600")
            } catch {
            }
            g_SCWV_DarkSubHoverIdx := 0
        }
        return
    }
    ItemIndex := Floor((RelY - innerTop) / MenuItemHeight) + 1
    if (ItemIndex < 1 || ItemIndex > g_SCWV_DarkSubItemCount)
        return
    ItemY := innerTop + (ItemIndex - 1) * MenuItemHeight
    if RelY < ItemY || RelY >= ItemY + MenuItemHeight {
        return
    }
    if g_SCWV_DarkSubHoverIdx = ItemIndex
        return
    if g_SCWV_DarkSubMenuHoverTimer {
        SetTimer(g_SCWV_DarkSubMenuHoverTimer, 0)
        g_SCWV_DarkSubMenuHoverTimer := 0
    }
    if g_SCWV_DarkSubHoverIdx > 0 {
        try {
            g_SCWV_DarkSubGui["ScSubBg" . g_SCWV_DarkSubHoverIdx].BackColor := "1a1a1a"
            g_SCWV_DarkSubGui["ScSubTx" . g_SCWV_DarkSubHoverIdx].Opt("cff6600")
        } catch {
        }
    }
    g_SCWV_DarkSubHoverIdx := ItemIndex
    try {
        g_SCWV_DarkSubGui["ScSubBg" . ItemIndex].BackColor := "2a2622"
        g_SCWV_DarkSubGui["ScSubTx" . ItemIndex].Opt("cffb366")
    } catch {
    }
    fn := _SCWV_DarkSubMenuHoverPhase2.Bind(ItemIndex)
    g_SCWV_DarkSubMenuHoverTimer := fn
    SetTimer(fn, -50)
}

_SCWV_ShowDarkSubMenuAt(children, posX, posY) {
    global g_SCWV_DarkSubGui, g_SCWV_DarkSubCmdByIdx, g_SCWV_DarkCtxGui, g_SCWV_Gui, g_SCWV_DarkSubItemCount
    _SCWV_DestroyDarkSubMenus()
    if !(children is Array) || children.Length = 0
        return
    _SCWV_DarkMenuLayout(&Df, &Pad, &MenuItemHeight, &innerTop)
    MenuWidth := 220
    n := children.Length
    MenuHeight := 2 * Df + n * MenuItemHeight + 2 * Pad
    ScreenWidth := SysGet(78)
    ScreenHeight := SysGet(79)
    posX := Integer(posX)
    posY := Integer(posY)
    if posX < 8
        posX := 8
    else if posX + MenuWidth > ScreenWidth - 8
        posX := ScreenWidth - MenuWidth - 8
    if posY < 8
        posY := 8
    else if posY + MenuHeight > ScreenHeight - 8
        posY := ScreenHeight - MenuHeight - 8
    ownOpt := ""
    ownerHwnd := 0
    if IsObject(g_SCWV_DarkCtxGui) && g_SCWV_DarkCtxGui {
        try ownerHwnd := g_SCWV_DarkCtxGui.Hwnd
        catch {
        }
    }
    if !ownerHwnd && IsObject(g_SCWV_Gui) && g_SCWV_Gui {
        try ownerHwnd := g_SCWV_Gui.Hwnd
        catch {
        }
    }
    if ownerHwnd
        ownOpt := " +Owner" . ownerHwnd
    g_SCWV_DarkSubGui := Gui("+AlwaysOnTop +ToolWindow -Caption -DPIScale" . ownOpt, "SearchCtxSub")
    g_SCWV_DarkSubGui.BackColor := "59341c"
    g_SCWV_DarkSubGui.MarginX := 0
    g_SCWV_DarkSubGui.MarginY := 0
    g_SCWV_DarkSubGui.Add("Text", "x" . Df . " y" . Df . " w" . (MenuWidth - 2 * Df) . " h" . (MenuHeight - 2 * Df) . " Background1a1a1a", "")
    g_SCWV_DarkSubCmdByIdx := Map()
    g_SCWV_DarkSubItemCount := n
    Loop children.Length {
        i := A_Index
        it := children[i]
        t := it.Has("t") ? String(it["t"]) : ""
        id := it.Has("id") ? Trim(String(it["id"])) : ""
        iy := innerTop + (i - 1) * MenuItemHeight
        ItemBg := g_SCWV_DarkSubGui.Add("Text", "x" . innerTop . " y" . iy . " w" . (MenuWidth - 2 * innerTop) . " h" . MenuItemHeight . " Background1a1a1a vScSubBg" . i, "")
        ItemBg.OnEvent("Click", _SCWV_OnDarkSubMenuClick.Bind(i))
        ItemTxt := g_SCWV_DarkSubGui.Add("Text", "x" . (innerTop + 10) . " y" . iy . " w" . (MenuWidth - 2 * innerTop - 14) . " h" . MenuItemHeight . " Left 0x200 cff6600 BackgroundTrans vScSubTx" . i, t)
        ItemTxt.SetFont("s11", "Segoe UI")
        ItemTxt.OnEvent("Click", _SCWV_OnDarkSubMenuClick.Bind(i))
        if (id != "")
            g_SCWV_DarkSubCmdByIdx[i] := id
    }
    g_SCWV_DarkSubGui.Show("x" . posX . " y" . posY . " w" . MenuWidth . " h" . MenuHeight)
    try _SCWV_AniMenuShow(g_SCWV_DarkSubGui.Hwnd)
    catch {
    }
    _SCWV_DarkMenuRoundCorners(g_SCWV_DarkSubGui.Hwnd)
    try WinActivate("ahk_id " . g_SCWV_DarkSubGui.Hwnd)
    catch {
    }
    SetTimer(_SCWV_CheckDarkSubCtxMouse, 45)
}

_SCWV_OnDarkSearchMenuClick(idx, *) {
    global g_SCWV_DarkCtxCmdByIdx, g_SCWV_DarkCtxSubSpecByIdx, g_SCWV_MenuActionRow, g_SCWV_Gui, g_SCWV_DarkCtxGui
    if g_SCWV_DarkCtxSubSpecByIdx.Has(idx) {
        ch := g_SCWV_DarkCtxSubSpecByIdx[idx]
        try {
            if g_SCWV_DarkCtxGui {
                g_SCWV_DarkCtxGui["ScCtxBg" . idx].BackColor := "ffc48a"
                g_SCWV_DarkCtxGui["ScCtxTx" . idx].Opt("c1a1a1a")
            }
        } catch {
        }
        Sleep(32)
        try {
            _SCWV_DarkCtxComputeSubXY(idx, &subX, &subY)
            _SCWV_ShowDarkSubMenuAt(ch, subX, subY)
        } catch {
            _SCWV_ShowDarkSubMenuAt(ch, A_ScreenWidth // 2, A_ScreenHeight // 2)
        }
        return
    }
    c := g_SCWV_DarkCtxCmdByIdx.Has(idx) ? g_SCWV_DarkCtxCmdByIdx[idx] : ""
    row := g_SCWV_MenuActionRow
    if (c != "") {
        try {
            if g_SCWV_DarkCtxGui {
                g_SCWV_DarkCtxGui["ScCtxBg" . idx].BackColor := "ffc48a"
                g_SCWV_DarkCtxGui["ScCtxTx" . idx].Opt("c1a1a1a")
            }
        } catch {
        }
        Sleep(38)
    }
    _SCWV_DestroyDarkRowMenus()
    SetTimer(SCWV_WMDeactivateHideTick, 0)
    if (c != "")
        SC_ExecuteContextCommand(c, row)
    if _SCWV_ShouldRefocusSearchAfterCmd(c) && g_SCWV_Gui {
        try WinActivate("ahk_id " . g_SCWV_Gui.Hwnd)
        catch as _ea {
        }
    }
    if _SCWV_ShouldRefocusSearchAfterCmd(c) {
        try SCWV_RequestFocusInput()
        catch as _eb {
        }
    }
}

_SCWV_ShowDarkSearchRowMenuAt(spec, posX, posY) {
    global g_SCWV_DarkCtxGui, g_SCWV_DarkCtxCmdByIdx, g_SCWV_DarkCtxHoverIdx, g_SCWV_DarkCtxSubSpecByIdx, g_SCWV_DarkCtxItemCount
    _SCWV_DestroyDarkRowMenus()
    if !(spec is Array) || spec.Length = 0
        spec := [Map("k", "cmd", "id", "", "t", "（未配置菜单）")]
    _SCWV_DarkMenuLayout(&Df, &Pad, &MenuItemHeight, &innerTop)
    n := spec.Length
    g_SCWV_DarkCtxItemCount := n
    MenuWidth := 220
    MenuHeight := 2 * Df + n * MenuItemHeight + 2 * Pad
    cellW := MenuWidth - 2 * innerTop
    ScreenWidth := SysGet(78)
    ScreenHeight := SysGet(79)
    posX := Integer(posX)
    posY := Integer(posY)
    if posX < 8
        posX := 8
    else if posX + MenuWidth > ScreenWidth - 8
        posX := ScreenWidth - MenuWidth - 8
    if posY < 8
        posY := 8
    else if posY + MenuHeight > ScreenHeight - 8
        posY := ScreenHeight - MenuHeight - 8

    ownOpt := ""
    global g_SCWV_Gui
    if IsObject(g_SCWV_Gui) && g_SCWV_Gui {
        try {
            oh := g_SCWV_Gui.Hwnd
            if oh
                ownOpt := " +Owner" . oh
        } catch {
        }
    }
    g_SCWV_DarkCtxGui := Gui("+AlwaysOnTop +ToolWindow -Caption -DPIScale" . ownOpt, "SearchCtx")
    g_SCWV_DarkCtxGui.BackColor := "59341c"
    g_SCWV_DarkCtxGui.MarginX := 0
    g_SCWV_DarkCtxGui.MarginY := 0
    g_SCWV_DarkCtxGui.Add("Text", "x" . Df . " y" . Df . " w" . (MenuWidth - 2 * Df) . " h" . (MenuHeight - 2 * Df) . " Background1a1a1a", "")
    g_SCWV_DarkCtxCmdByIdx := Map()
    g_SCWV_DarkCtxSubSpecByIdx := Map()
    g_SCWV_DarkCtxHoverIdx := 0
    Loop spec.Length {
        i := A_Index
        it := spec[i]
        t := it.Has("t") ? String(it["t"]) : ""
        isSub := it.Has("k") && String(it["k"]) = "sub"
        id := isSub ? "" : (it.Has("id") ? Trim(String(it["id"])) : "")
        iy := innerTop + (i - 1) * MenuItemHeight
        ItemBg := g_SCWV_DarkCtxGui.Add("Text", "x" . innerTop . " y" . iy . " w" . cellW . " h" . MenuItemHeight . " Background1a1a1a vScCtxBg" . i, "")
        ItemBg.OnEvent("Click", _SCWV_OnDarkSearchMenuClick.Bind(i))
        ItemTxt := g_SCWV_DarkCtxGui.Add("Text", "x" . (innerTop + 10) . " y" . iy . " w" . (cellW - 14) . " h" . MenuItemHeight . " Left 0x200 cff6600 BackgroundTrans vScCtxTx" . i, t)
        ItemTxt.SetFont("s11", "Segoe UI")
        ItemTxt.OnEvent("Click", _SCWV_OnDarkSearchMenuClick.Bind(i))
        if (isSub && it.Has("children"))
            g_SCWV_DarkCtxSubSpecByIdx[i] := it["children"]
        else if (id != "")
            g_SCWV_DarkCtxCmdByIdx[i] := id
    }
    g_SCWV_DarkCtxGui.Show("x" . posX . " y" . posY . " w" . MenuWidth . " h" . MenuHeight)
    try _SCWV_AniMenuShow(g_SCWV_DarkCtxGui.Hwnd)
    catch {
    }
    _SCWV_DarkMenuRoundCorners(g_SCWV_DarkCtxGui.Hwnd)
    try WinActivate("ahk_id " . g_SCWV_DarkCtxGui.Hwnd)
    catch {
    }
    SetTimer(_SCWV_CheckDarkSearchCtxMouse, 45)
    SetTimer(_SCWV_CloseDarkSearchCtxIfOutside, 80)
}

_SCWV_BuildSearchCtxMenuSpec(layoutRows) {
    spec := []
    if !(layoutRows is Array)
        return spec
    for r in layoutRows {
        if !(r is Map) || !r.Has("cmdId")
            continue
        cid := Trim(String(r["cmdId"]))
        if (SubStr(cid, 1, 12) = "sc_menu_sep_")
            continue
        if (cid = "sc_copy_sub" || cid = "sc_send_sub")
            continue
        if !_VK_IsSearchCenterGridCmd(cid)
            continue
        spec.Push(Map("k", "cmd", "id", cid, "t", _SCWV_CmdDisplayName(cid)))
    }
    return spec
}

_SCWV_FilterToolbarSearchRows() {
    global g_Commands
    out := []
    if !(IsSet(g_Commands) && g_Commands is Map && g_Commands.Has("ToolbarLayout"))
        return out
    raw := g_Commands["ToolbarLayout"]
    rows := []
    for r in raw
        rows.Push(r)
    if rows.Length > 1
        rows := _VK_SortRowsByNumericKey(rows, "order_search_row")
    for r in rows {
        if !(r is Map) || !r.Has("cmdId")
            continue
        if !r.Has("visible_in_search_row") || !r["visible_in_search_row"]
            continue
        if !_VK_ItemHasMenuScene(r, "search_center")
            continue
        cid := Trim(String(r["cmdId"]))
        if !_VK_IsSearchCenterGridCmd(cid)
            continue
        out.Push(r)
    }
    return out
}

_SCWV_ShowSearchCenterRowMenu(row, sx, sy) {
    global g_SCWV_MenuActionRow

    r := Integer(row)
    if (r < 1)
        return
    Item := GetSearchCenterResultItemByRow(r)
    if !IsObject(Item)
        return

    g_SCWV_MenuActionRow := r
    posX := Integer(sx)
    posY := Integer(sy)
    if (posX < 1 || posY < 1) {
        try DllCall("GetCursorPos", "int*", &cx := 0, "int*", &cy := 0)
        catch {
            cx := 0, cy := 0
        }
        posX := cx
        posY := cy
    }

    layoutRows := _SCWV_FilterToolbarSearchRows()
    spec := _SCWV_BuildSearchCtxMenuSpec(layoutRows)
    spec := _SCWV_RegroupSearchCtxSpec(spec, Item)
    try _SCWV_ShowDarkSearchRowMenuAt(spec, posX, posY)
    catch as err {
        try TrayTip("菜单显示失败", err.Message, "Iconx 2")
        catch {
        }
    }
}

SC_SearchCenterTogglePinByItem(Item) {
    global g_SCWV_PinnedKeys, SearchCenterWebKeyword

    k := _SCWV_ResultPinKey(Item)
    if (k = "")
        return
    if g_SCWV_PinnedKeys.Has(k) && g_SCWV_PinnedKeys[k]
        g_SCWV_PinnedKeys.Delete(k)
    else
        g_SCWV_PinnedKeys[k] := true
    _SCWV_PerformSearch(SearchCenterWebKeyword)
    SCWV_PushState("state")
}

SC_SearchCenterRestoreRecycleAt(binIndex) {
    global g_SCWV_RecycleBin, SearchCenterSearchResults

    i := Integer(binIndex)
    if i < 1 || i > g_SCWV_RecycleBin.Length
        return
    snap := g_SCWV_RecycleBin[i]
    g_SCWV_RecycleBin.RemoveAt(i)
    c := snap.Has("content") ? String(snap["content"]) : ""
    t := snap.Has("title") ? String(snap["title"]) : SubStr(c, 1, 80)
    id := snap.Has("id") ? snap["id"] : ""
    origDt := "text"
    dt := "text"
    ct := Trim(c)
    if (ct != "" && (FileExist(ct) || DirExist(ct))) {
        origDt := "file"
        dt := "File"
    }
    SearchCenterSearchResults.InsertAt(1, {
        Title: t,
        Content: c,
        Source: "回收站",
        DataType: dt,
        Time: "",
        OriginalDataType: origDt,
        ID: id
    })
    SCWV_PushState("state")
}

SC_SearchCenterEmptyRecycleBin() {
    global g_SCWV_RecycleBin
    g_SCWV_RecycleBin := []
    try TrayTip("已清空", "搜索中心回收站已清空", "Iconi 1")
    catch as _e {
    }
    try SCWV_PushState("state")
    catch as _e2 {
    }
}

SC_SearchCenterRemoveVisibleRowFromList(visibleRow) {
    global SearchCenterSearchResults, g_SCWV_PinnedKeys

    r := Integer(visibleRow)
    if (r < 1)
        return
    visItem := GetSearchCenterResultItemByRow(r)
    if !IsObject(visItem)
        return

    tgtKey := _SCWV_ResultPinKey(visItem)
    idx := 0
    Loop SearchCenterSearchResults.Length {
        it := SearchCenterSearchResults[A_Index]
        if (_SCWV_ResultPinKey(it) = tgtKey) {
            idx := A_Index
            break
        }
    }
    if (idx > 0) {
        SearchCenterSearchResults.RemoveAt(idx)
        if g_SCWV_PinnedKeys.Has(tgtKey)
            g_SCWV_PinnedKeys.Delete(tgtKey)
    }
    SCWV_PushState("state")
}

SC_SearchCenterRecycleVisibleRow(visibleRow) {
    global SearchCenterSearchResults, g_SCWV_RecycleBin

    r := Integer(visibleRow)
    if (r < 1)
        return
    visItem := GetSearchCenterResultItemByRow(r)
    if !IsObject(visItem)
        return

    Content := visItem.HasProp("Content") ? visItem.Content : visItem.Title
    DataType := visItem.HasProp("DataType") ? visItem.DataType : ""
    origDt := visItem.HasProp("OriginalDataType") ? visItem.OriginalDataType : ""
    isFileLike := (DataType = "file" || DataType = "File" || DataType = "Folder" || origDt = "file")

    if isFileLike && Content != "" && FileExist(Content) {
        try FileRecycle(Content)
        catch as err {
            try TrayTip("回收失败", err.Message, "Iconx 2")
            catch {
            }
            return
        }
    }

    try g_SCWV_RecycleBin.Push(Map(
        "title", visItem.HasProp("Title") ? visItem.Title : "",
        "content", Content,
        "id", visItem.HasProp("ID") ? visItem.ID : ""
    ))
    catch {
    }

    SC_SearchCenterRemoveVisibleRowFromList(r)
}

SC_SearchCenterDeleteVisibleRow(visibleRow) {
    SC_SearchCenterRecycleVisibleRow(visibleRow)
}

; 鈹€鈹€ SearchCenter 鏂囦欢棰勮锛歐eb 璇荤洏鍥炰紶 / IPreviewHandler 鍘熺敓 / QuickLook 鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€
global g_SCWV_PreviewSingleton := 0
global g_SCWV_QLRaiseTimer := 0

SCWV_Preview_Get() {
    global g_SCWV_PreviewSingleton
    ; 涓嶅彲瀵?/"" 浣跨敤 "is PreviewManager"锛屽惁鍒?v2 浼氭姏閿欙紙Resize 鏃跺嵆瑙﹀彂 鈫?鎼滅储涓績闂€€锛?    if !IsObject(g_SCWV_PreviewSingleton)
        g_SCWV_PreviewSingleton := PreviewManager()
    return g_SCWV_PreviewSingleton
}

SCWV_Preview_UnloadNative() {
    try SCWV_Preview_Get().Unload()
    catch {
    }
}

SCWV_Preview_OnHostLayoutChanged() {
    try SCWV_Preview_Get().OnHostLayoutChanged()
    catch {
    }
}

SCWV_Preview_OnWebText(path, seq) {
    try SCWV_Preview_Get().OnWebText(path, seq)
    catch as err {
        _SCWV_Preview_PostTextErr(seq, err.Message)
    }
}

SCWV_Preview_OnWebImage(path, seq) {
    try SCWV_Preview_Get().OnWebImage(path, seq)
    catch as err {
        SCWV_PostJson(Map("type", "WEB_PREVIEW_IMAGE_RESULT", "seq", seq, "dataUrl", "", "error", err.Message))
    }
}

SCWV_Preview_OnPdfium(path, seq) {
    try SCWV_Preview_Get().OnPdfium(path, seq)
    catch as err {
        SCWV_PostJson(Map("type", "WEB_PREVIEW_PDFIUM_RESULT", "seq", seq, "dataUrl", "", "error", err.Message))
    }
}

SCWV_Preview_OnNative(path, seq, boundsMap) {
    try SCWV_Preview_Get().ScheduleNative(path, seq, boundsMap)
    catch as err {
        SCWV_PostJson(Map("type", "NATIVE_PREVIEW_FAILED", "message", err.Message))
    }
}

SCWV_Preview_TryQuickLook(path) {
    try SCWV_Preview_Get().TryQuickLook(path)
    catch {
    }
}

_SCWV_Preview_PostTextErr(seq, msg) {
    SCWV_PostJson(Map("type", "WEB_PREVIEW_TEXT_RESULT", "seq", seq, "text", "", "truncated", false, "sizeBytes", 0, "error", msg))
}

_SCWV_QuickLookRaiseOnce(*) {
    global g_SCWV_QLRaiseTimer
    g_SCWV_QLRaiseTimer := 0
    lst := WinGetList("ahk_exe QuickLook.exe")
    if !(IsObject(lst) && lst.Length)
        return
    best := 0
    bestArea := 0
    for _, hwnd in lst {
        expr := "ahk_id " hwnd
        try {
            if !WinExist(expr)
                continue
            if (WinGetMinMax(expr) = 1)
                continue
            WinGetPos(, , &w, &h, expr)
            a := w * h
            if (a > bestArea) {
                bestArea := a
                best := hwnd
            }
        } catch {
        }
    }
    if !best
        return
    expr := "ahk_id " best
    try {
        WinActivate(expr)
        WinSetAlwaysOnTop 1, expr
    } catch {
    }
}

_SCWV_B64EncodeBuf(buf) {
    if !(buf is Buffer) || buf.Size <= 0
        return ""
    encSz := 0
    DllCall("crypt32\CryptBinaryToStringW", "Ptr", buf.Ptr, "UInt", buf.Size, "UInt", 0x40000001, "Ptr", 0, "UInt*", &encSz)
    if (encSz <= 1)
        return ""
    out := Buffer(encSz * 2, 0)
    if !DllCall("crypt32\CryptBinaryToStringW", "Ptr", buf.Ptr, "UInt", buf.Size, "UInt", 0x40000001, "Ptr", out.Ptr, "UInt*", &encSz)
        return ""
    return StrGet(out.Ptr, encSz - 1, "UTF-16")
}

_SCWV_CountReplacementChar(s) {
    c := 0
    try StrReplace(String(s), "�", "", &c)
    catch {
        c := 0
    }
    return c
}

_SCWV_DecodeTextBuffer(buf, sizeBytes) {
    if !(buf is Buffer) || sizeBytes <= 0
        return ""
    if (sizeBytes >= 3) {
        b0 := NumGet(buf, 0, "UChar"), b1 := NumGet(buf, 1, "UChar"), b2 := NumGet(buf, 2, "UChar")
        if (b0 = 0xEF && b1 = 0xBB && b2 = 0xBF)
            return StrGet(buf.Ptr + 3, sizeBytes - 3, "UTF-8")
    }
    if (sizeBytes >= 2) {
        b0 := NumGet(buf, 0, "UChar"), b1 := NumGet(buf, 1, "UChar")
        if (b0 = 0xFF && b1 = 0xFE)
            return StrGet(buf.Ptr + 2, Floor((sizeBytes - 2) / 2), "UTF-16")
        if (b0 = 0xFE && b1 = 0xFF)
            return StrGet(buf.Ptr + 2, Floor((sizeBytes - 2) / 2), "UTF-16")
    }
    txtUtf8 := StrGet(buf, sizeBytes, "UTF-8")
    badUtf8 := _SCWV_CountReplacementChar(txtUtf8)
    if (badUtf8 = 0)
        return txtUtf8
    txt936 := StrGet(buf, sizeBytes, "CP936")
    bad936 := _SCWV_CountReplacementChar(txt936)
    return (bad936 < badUtf8) ? txt936 : txtUtf8
}

_SCWV_RegReadDefault(path) {
    try {
        v := RegRead(path, "")
        v := Trim(String(v))
        if (v != "")
            return v
    } catch {
    }
    return ""
}

_SCWV_ErrToText(err) {
    txt := ""
    try txt := String(err.Message)
    catch {
        txt := "unknown error"
    }
    try {
        if (err.What != "")
            txt .= " | what=" . String(err.What)
    } catch {
    }
    try {
        if (err.Extra != "")
            txt .= " | extra=" . String(err.Extra)
    } catch {
    }
    try txt .= " | line=" . String(err.Line)
    catch {
    }
    return txt
}

_SCWV_ReadProgIdForExt(extDot, &fromKey := "") {
    fromKey := ""
    roots := [
        "HKCU\Software\Classes\",
        "HKCR\"
    ]
    for _, r in roots {
        k := r . extDot
        v := _SCWV_RegReadDefault(k)
        if (v != "") {
            fromKey := k
            return v
        }
    }
    return ""
}

_SCWV_RegPreviewClsidForExt(extDot, &hitPath := "", &hitSource := "", &trace := 0) {
    guid := "{8895b1c6-b41f-4c1c-a562-0d564d35d9c5}"
    extDot := "." . LTrim(StrLower(String(extDot)), ".")
    shellex := "\shellex\" . guid
    hitPath := ""
    hitSource := ""
    progid := _SCWV_ReadProgIdForExt(extDot, &progidFrom)
    attempts := []

    directPaths := [
        "HKCU\Software\Classes\" . extDot . shellex,
        "HKCR\" . extDot . shellex
    ]
    for _, p in directPaths {
        attempts.Push(p)
        v := _SCWV_RegReadDefault(p)
        if (v != "") {
            hitPath := p
            hitSource := "ext_direct"
            trace := Map("attempts", attempts, "progid", progid, "progidFrom", progidFrom)
            return v
        }
    }

    if (progid != "") {
        progidPaths := [
            "HKCU\Software\Classes\" . progid . shellex,
            "HKCR\" . progid . shellex
        ]
        for _, p in progidPaths {
            attempts.Push(p)
            v := _SCWV_RegReadDefault(p)
            if (v != "") {
                hitPath := p
                hitSource := "progid"
                trace := Map("attempts", attempts, "progid", progid, "progidFrom", progidFrom)
                return v
            }
        }
    }

    sfaPaths := [
        "HKCU\Software\Classes\SystemFileAssociations\" . extDot . shellex,
        "HKCR\SystemFileAssociations\" . extDot . shellex
    ]
    for _, p in sfaPaths {
        attempts.Push(p)
        v := _SCWV_RegReadDefault(p)
        if (v != "") {
            hitPath := p
            hitSource := "system_file_assoc"
            trace := Map("attempts", attempts, "progid", progid, "progidFrom", progidFrom)
            return v
        }
    }

    trace := Map("attempts", attempts, "progid", progid, "progidFrom", progidFrom)
    return ""
}

_SCWV_WebViewClientScreenOrigin(&sx, &sy) {
    global g_SCWV_Gui, g_SCWV_Ctrl
    sx := 0, sy := 0
    if !g_SCWV_Gui || !g_SCWV_Ctrl
        return false
    ph := 0
    try ph := g_SCWV_Ctrl.ParentWindow
    catch {
        return false
    }
    if !ph
        return false
    try {
        pt := Buffer(8, 0)
        DllCall("user32\ClientToScreen", "Ptr", ph, "Ptr", pt)
        sx := NumGet(pt, 0, "Int")
        sy := NumGet(pt, 4, "Int")
    } catch {
        return false
    }
    return true
}

_SCWV_WebViewRasterScale() {
    global g_SCWV_Ctrl
    if !g_SCWV_Ctrl
        return 1
    try {
        sc := g_SCWV_Ctrl.RasterizationScale
        if (sc > 0.1 && sc < 10)
            return sc
    } catch {
    }
    return 1
}

_SCWV_BoundsMapToScreen(boundsMap, &rx, &ry, &rw, &rh) {
    global g_SCWV_Ctrl
    rx := 0, ry := 0, rw := 400, rh := 300
    if !g_SCWV_Ctrl
        return false
    rc := g_SCWV_Ctrl.Bounds
    bw := 800
    bh := 600
    bl := 0
    bt := 0
    try {
        bw := rc.right - rc.left
        bh := rc.bottom - rc.top
        bl := rc.left
        bt := rc.top
    } catch {
    }
    sc := _SCWV_WebViewRasterScale()
    cl := 0.0
    ct := 0.0
    cw := bw / Max(sc, 0.01)
    ch := bh / Max(sc, 0.01)
    if (boundsMap is Map) && boundsMap.Has("left") {
        cl := Float(boundsMap["left"])
        ct := Float(boundsMap["top"])
        cw := Float(boundsMap["width"])
        ch := Float(boundsMap["height"])
        if (boundsMap.Has("dpr")) {
            dpr := Float(boundsMap["dpr"])
            if (dpr > 0.1 && dpr < 10)
                sc := dpr
        }
    }
    if !(_SCWV_WebViewClientScreenOrigin(&psx, &psy))
        return false
    rx := psx + bl + Round(cl * sc)
    ry := psy + bt + Round(ct * sc)
    rw := Max(Round(cw * sc), 80)
    rh := Max(Round(ch * sc), 60)
    return true
}

class PreviewManager {
    NativeGui := 0
    PreviewHandler := 0
    InitObj := 0
    RootObj := 0
    CurrentPath := ""
    BoundsCss := 0
    NativeTimer := 0
    PendingPath := ""
    PendingSeq := 0
    PendingBounds := 0
    NativeLastDiag := 0

    Unload() {
        if this.PreviewHandler {
            try ComCall(9, this.PreviewHandler, "hresult") ; IPreviewHandler::Unload
            catch {
            }
            this.PreviewHandler := 0
        }
        this.InitObj := 0
        this.RootObj := 0
        if this.NativeGui {
            try this.NativeGui.Hide()
            catch {
            }
        }
        this.CurrentPath := ""
        this.BoundsCss := 0
        if this.NativeTimer {
            SetTimer(this.NativeTimer, 0)
            this.NativeTimer := 0
        }
        this.PendingPath := ""
        this.PendingSeq := 0
        this.PendingBounds := 0
    }

    _PostNativeFail(path, userMsg, reason := "", detail := "") {
        SplitPath path, , , &ext
        payload := Map(
            "type", "NATIVE_PREVIEW_FAILED",
            "message", userMsg,
            "path", path,
            "ext", StrLower(ext),
            "reason", reason,
            "detail", detail,
            "processArch", (A_PtrSize = 8 ? "x64" : "x86")
        )
        if (this.NativeLastDiag is Map)
            payload["diag"] := this.NativeLastDiag
        SCWV_PostJson(payload)
    }

    TryQuickLook(path) {
        path := Trim(String(path))
        if (path = "" || !FileExist(path))
            return
        ql := A_ScriptDir "\lib\QuickLook\QuickLook.exe"
        if !FileExist(ql)
            return
        global g_SCWV_QLRaiseTimer
        SCWV_Preview_UnloadNative()
        if g_SCWV_QLRaiseTimer {
            SetTimer(g_SCWV_QLRaiseTimer, 0)
            g_SCWV_QLRaiseTimer := 0
        }
        if !ProcessExist("QuickLook.exe") {
            try Run('"' ql '"', A_ScriptDir)
            catch {
            }
            Sleep 450
        }
        try Run('"' ql '" "' path '"',, "UseErrorLevel")
        catch {
        }
        g_SCWV_QLRaiseTimer := _SCWV_QuickLookRaiseOnce
        SetTimer(_SCWV_QuickLookRaiseOnce, -380)
    }

    OnWebText(path, seq) {
        path := Trim(String(path))
        this._PostDetailMeta(path, seq)
        if (path = "" || !FileExist(path)) {
            _SCWV_Preview_PostTextErr(seq, "鏃犳晥璺緞")
            return
        }
        sz := FileGetSize(path)
        truncated := false
        maxB := 1048576
        n := Min(sz, maxB)
        if (sz > maxB)
            truncated := true
        f := FileOpen(path, "r")
        buf := Buffer(n, 0)
        f.RawRead(buf, n)
        f.Close()
        text := _SCWV_DecodeTextBuffer(buf, n)
        lineTrunc := false
        if truncated {
            cnt := 0
            out := ""
            Loop Parse text, "`n", "`r" {
                cnt += 1
                if (cnt > 1000) {
                    lineTrunc := true
                    break
                }
                out .= (cnt > 1 ? "`n" : "") A_LoopField
            }
            text := out
        }
        SCWV_PostJson(Map(
            "type", "WEB_PREVIEW_TEXT_RESULT",
            "seq", seq,
            "text", text,
            "truncated", truncated || lineTrunc,
            "sizeBytes", sz
        ))
    }

    OnWebImage(path, seq) {
        path := Trim(String(path))
        this._PostDetailMeta(path, seq)
        if (path = "" || !FileExist(path)) {
            SCWV_PostJson(Map("type", "WEB_PREVIEW_IMAGE_RESULT", "seq", seq, "dataUrl", ""))
            return
        }
        sz := FileGetSize(path)
        if (sz > 12582912) {
            SCWV_PostJson(Map("type", "WEB_PREVIEW_IMAGE_RESULT", "seq", seq, "dataUrl", "", "error", "鍥剧墖杩囧ぇ"))
            return
        }
        f := FileOpen(path, "r")
        buf := Buffer(sz)
        f.RawRead(buf, sz)
        f.Close()
        b64 := _SCWV_B64EncodeBuf(buf)
        SplitPath path, , , &ext
        ext := StrLower(ext)
        mime := "application/octet-stream"
        if (ext = "png")
            mime := "image/png"
        else if (ext = "jpg" || ext = "jpeg")
            mime := "image/jpeg"
        else if (ext = "gif")
            mime := "image/gif"
        else if (ext = "svg")
            mime := "image/svg+xml"
        dataUrl := "data:" mime ";base64," b64
        SCWV_PostJson(Map("type", "WEB_PREVIEW_IMAGE_RESULT", "seq", seq, "dataUrl", dataUrl))
    }

    OnPdfium(path, seq) {
        path := Trim(String(path))
        this._PostDetailMeta(path, seq)
        if (path = "" || !FileExist(path)) {
            SCWV_PostJson(Map("type", "WEB_PREVIEW_PDFIUM_RESULT", "seq", seq, "dataUrl", "", "error", "invalid_path"))
            return
        }

        pdfiumDll := A_ScriptDir "\lib\pdfium.dll"
        icuDat := A_ScriptDir "\lib\icudtl.dat"
        diag := Map(
            "engine", "imageput_pdf_channel",
            "pdfiumDllPresent", !!FileExist(pdfiumDll),
            "icuDatPresent", !!FileExist(icuDat)
        )
        try {
            ; ImagePut 对 pdf 输入会走其 PDF 渲染通道，输出首图 Base64
            b64 := ImagePut("Base64", path, "jpg", 70)
            if (b64 = "")
                throw Error("empty_base64")
            SCWV_PostJson(Map(
                "type", "WEB_PREVIEW_PDFIUM_RESULT",
                "seq", seq,
                "dataUrl", "data:image/jpeg;base64," . b64,
                "diag", diag
            ))
        } catch as err {
            diag["error"] := _SCWV_ErrToText(err)
            SCWV_PostJson(Map(
                "type", "WEB_PREVIEW_PDFIUM_RESULT",
                "seq", seq,
                "dataUrl", "",
                "error", err.Message,
                "diag", diag
            ))
        }
    }

    ScheduleNative(path, seq, boundsMap) {
        path := Trim(String(path))
        this._PostDetailMeta(path, seq)
        if (path = "" || !FileExist(path)) {
            this.NativeLastDiag := Map("step", "precheck", "error", "invalid_path")
            this._PostNativeFail(path, "无效路径", "invalid_path")
            return
        }

        ; 濡傛灉璺緞娌″彉涓旂獥鍙ｅ凡瀛樺湪锛屼粎瑙﹀彂甯冨眬鍒锋柊 (Resize)锛屼笉閲嶆柊鍔犺浇 COM
        if (this.CurrentPath = path && this.PreviewHandler && this.NativeGui) {
            this.BoundsCss := boundsMap
            this.OnHostLayoutChanged()
            return
        }

        this.PendingPath := path
        this.PendingSeq := seq
        this.PendingBounds := boundsMap
        if this.NativeTimer
            SetTimer(this.NativeTimer, 0)
        this.NativeTimer := ObjBindMethod(this, "_FireNativeDebounced")
        SetTimer(this.NativeTimer, -150)
    }

    _FireNativeDebounced() {
        this.NativeTimer := 0
        p := this.PendingPath
        sq := this.PendingSeq
        bm := this.PendingBounds
        if (p = "")
            return

        ; 鍗充娇鏄噸鏂板姞杞戒篃鍙渶娓呯悊 COM锛屼笉閿€姣?GUI
        if this.PreviewHandler {
            try ComCall(9, this.PreviewHandler, "hresult")
            catch {
            }
            this.PreviewHandler := 0
        }
        this.InitObj := 0
        this.RootObj := 0
        
        this.CurrentPath := p
        this.BoundsCss := bm
        
        global g_SCWV_Gui
        if !g_SCWV_Gui {
            this.NativeLastDiag := Map("step", "precheck", "error", "host_not_ready")
            this._PostNativeFail(p, "窗口未就绪", "host_not_ready")
            return
        }
        
        if !_SCWV_BoundsMapToScreen(bm, &rx, &ry, &rw, &rh) {
            this.NativeLastDiag := Map("step", "precheck", "error", "bounds_invalid")
            this._PostNativeFail(p, "无法计算预览区域", "bounds_invalid")
            return
        }

        if !this.NativeGui {
            ownerHwnd := g_SCWV_Gui.Hwnd
            this.NativeGui := Gui("+Owner" . ownerHwnd . " -Caption +ToolWindow +Border", "SCNativePreview")
            this.NativeGui.BackColor := "1b1b1d"
        }
        
        this.NativeGui.Show("x" rx " y" ry " w" rw " h" rh " NoActivate")
        try WinSetAlwaysOnTop true, "ahk_id " . this.NativeGui.Hwnd
        catch {
        }
        
        hostHwnd := this.NativeGui.Hwnd
        if !this._AttachPreviewHandler(p, hostHwnd, rw, rh) {
            this.Unload()
            this._PostNativeFail(p, "系统预览组件不可用（可尝试 QuickLook）", "attach_failed")
        }
    }

    OnHostLayoutChanged() {
        if !this.PreviewHandler || !this.NativeGui || !this.BoundsCss
            return
        if !_SCWV_BoundsMapToScreen(this.BoundsCss, &rx, &ry, &rw, &rh)
            return
        try this.NativeGui.Move(rx, ry, rw, rh)
        catch {
        }
        rect := Buffer(16, 0)
        NumPut("int", 0, rect, 0)
        NumPut("int", 0, rect, 4)
        NumPut("int", rw, rect, 8)
        NumPut("int", rh, rect, 12)
        try ComCall(7, this.PreviewHandler, "ptr", rect.Ptr, "hresult")
        catch {
        }
    }

    _AttachPreviewHandler(path, hostHwnd, w, h) {
        global g_SCWV_PreviewCapabilityCache
        SplitPath path, , , &ext
        extDot := "." StrLower(ext)
        nowTick := A_TickCount

        if g_SCWV_PreviewCapabilityCache.Has(extDot) {
            cacheEntry := g_SCWV_PreviewCapabilityCache[extDot]
            if (cacheEntry is Map) {
                st := cacheEntry.Has("state") ? String(cacheEntry["state"]) : ""
                ts := cacheEntry.Has("ts") ? Integer(cacheEntry["ts"]) : 0
                if (st = "no_handler" && (nowTick - ts) < 300000) {
                    this.NativeLastDiag := Map(
                        "step", "resolve_clsid",
                        "ext", extDot,
                        "state", st,
                        "cacheHit", true,
                        "cacheAgeMs", nowTick - ts,
                        "error", "cached_no_handler"
                    )
                    return false
                }
            }
        }

        clsid := _SCWV_RegPreviewClsidForExt(extDot, &regPath, &regSource, &regTrace)
        if (clsid = "") {
            g_SCWV_PreviewCapabilityCache[extDot] := Map(
                "state", "no_handler",
                "ts", nowTick,
                "ext", extDot
            )
            this.NativeLastDiag := Map(
                "step", "resolve_clsid",
                "ext", extDot,
                "state", "no_handler",
                "cacheHit", false,
                "regSource", "",
                "regPath", "",
                "trace", regTrace
            )
            return false
        }

        g_SCWV_PreviewCapabilityCache[extDot] := Map(
            "state", "has_handler",
            "ts", nowTick,
            "ext", extDot,
            "clsid", clsid,
            "regPath", regPath,
            "regSource", regSource
        )

        try this.RootObj := Func("ComObjCreate").Call(clsid)
        catch as err {
            this.NativeLastDiag := Map(
                "step", "ComObjCreate",
                "ext", extDot,
                "clsid", clsid,
                "regPath", regPath,
                "regSource", regSource,
                "trace", regTrace,
                "error", _SCWV_ErrToText(err)
            )
            return false
        }
        try this.InitObj := Func("ComObjQuery").Call(this.RootObj, "{219a5d78-a9ef-443a-9271-1e392d5d1b1e}")
        catch as err {
            this.InitObj := 0
            this.NativeLastDiag := Map(
                "step", "ComObjQuery_IInitializeWithFile",
                "ext", extDot,
                "clsid", clsid,
                "regPath", regPath,
                "regSource", regSource,
                "trace", regTrace,
                "error", _SCWV_ErrToText(err)
            )
            return false
        }
        try ComCall(3, this.InitObj, "wstr", path, "uint", 0, "hresult")
        catch as err {
            this.NativeLastDiag := Map(
                "step", "IInitializeWithFile::Initialize",
                "ext", extDot,
                "clsid", clsid,
                "path", path,
                "regPath", regPath,
                "regSource", regSource,
                "trace", regTrace,
                "error", _SCWV_ErrToText(err)
            )
            return false
        }
        try this.PreviewHandler := Func("ComObjQuery").Call(this.RootObj, "{8895b1c6-b41f-4c1c-a562-0d564d35d9c5}")
        catch as err {
            this.NativeLastDiag := Map(
                "step", "ComObjQuery_IPreviewHandler",
                "ext", extDot,
                "clsid", clsid,
                "regPath", regPath,
                "regSource", regSource,
                "trace", regTrace,
                "error", _SCWV_ErrToText(err)
            )
            return false
        }
        rect := Buffer(16, 0)
        NumPut("int", 0, rect, 0)
        NumPut("int", 0, rect, 4)
        NumPut("int", w, rect, 8)
        NumPut("int", h, rect, 12)
        try ComCall(3, this.PreviewHandler, "ptr", hostHwnd, "ptr", rect.Ptr, "hresult")
        catch as err {
            this.NativeLastDiag := Map(
                "step", "IPreviewHandler::SetWindow",
                "ext", extDot,
                "clsid", clsid,
                "regPath", regPath,
                "regSource", regSource,
                "trace", regTrace,
                "error", _SCWV_ErrToText(err)
            )
            return false
        }
        try ComCall(7, this.PreviewHandler, "ptr", rect.Ptr, "hresult")
        catch {
        }
        try ComCall(8, this.PreviewHandler, "hresult")
        catch as err {
            this.NativeLastDiag := Map(
                "step", "IPreviewHandler::DoPreview",
                "ext", extDot,
                "clsid", clsid,
                "regPath", regPath,
                "regSource", regSource,
                "trace", regTrace,
                "error", _SCWV_ErrToText(err)
            )
            return false
        }
        this.NativeLastDiag := Map(
            "step", "success",
            "ext", extDot,
            "clsid", clsid,
            "regPath", regPath,
            "regSource", regSource,
            "trace", regTrace
        )
        return true
    }

    InvokeNative(path, seq, boundsMap) {
        this.Unload()
        this.ScheduleNative(path, seq, boundsMap)
    }
    _PostDetailMeta(path, seq) {
        if (path = "" || !FileExist(path))
            return
        try {
            sz := FileGetSize(path)
            if (sz > 1048576)
                szStr := Round(sz / 1048576, 2) . " MB"
            else if (sz > 1024)
                szStr := Round(sz / 1024, 1) . " KB"
            else
                szStr := sz . " B"
                
            modTime := FileGetTime(path, "M")
            creTime := FileGetTime(path, "C")
            fmtMod := FormatTime(modTime, "yyyy-MM-dd HH:mm")
            fmtCre := FormatTime(creTime, "yyyy-MM-dd HH:mm")
            
            SplitPath path, , , &ext
            
            SCWV_PostJson(Map(
                "type", "PREVIEW_META_UPDATE",
                "seq", seq,
                "path", path,
                "meta", Map(
                    "Size", szStr,
                    "Modified", fmtMod,
                    "Created", fmtCre,
                    "Ext", StrUpper(ext),
                    "Path", path
                )
            ))
        } catch {
        }
    }
}

_SCWV_RecordSearchHistory(keyword) {
    global SearchCenterCurrentLimit
    k := Trim(String(keyword))
    if (k == "")
        return
        
    historyFile := A_ScriptDir . "\Data\SearchCenterHistory.json"
    historyArr := []
    
    ; 璇诲彇鐜版湁璁板綍
    if FileExist(historyFile) {
        try {
            content := FileRead(historyFile, "UTF-8")
            if (content != "")
                historyArr := Jxon_Load(content)
        } catch {
            historyArr := []
        }
    }
    if (Type(historyArr) != "Array")
        historyArr := []
        
    ; 鍘婚噸骞舵斁鑷抽槦棣?
    newArr := [k]
    for _, item in historyArr {
        if (String(item) != k)
            newArr.Push(String(item))
    }
    
    ; 铏界劧鍓嶇鍙互閫夋嫨 LIMIT锛屼絾鎴戜滑鍦ㄦ湰鍦版渶澶氫繚鐣?1000 鏉★紝璇诲彇鏃跺啀鎴柇銆?
    if (newArr.Length > 1000)
        newArr.Length := 1000
        
    if !DirExist(A_ScriptDir . "\Data")
        DirCreate(A_ScriptDir . "\Data")
        
    try {
        f := FileOpen(historyFile, "w", "UTF-8")
        if (f) {
            f.Write(Jxon_Dump(newArr))
            f.Close()
        }
    }
}

_SCWV_LoadSearchHistory() {
    global SearchCenterCurrentLimit, SearchCenterSearchResults, SearchCenterHasMoreData
    historyFile := A_ScriptDir "\Data\SearchCenterHistory.json"
    historyArr := []
    
    ; 1. 缁勮鏂版墜鎸囧崡鍗＄墖 (Master Guide Card)
    SearchCenterSearchResults := []
    tutorialContent := "快速上手（30秒）`n"
                     . "1. 输入关键词：支持文件名、路径片段、剪贴板内容、模板名。`n"
                     . "2. 用方向键选择结果，按 Enter 执行。`n"
                     . "3. 通过分类和筛选缩小范围（文本、剪贴板、模板、配置等）。`n`n"
                     . "常见场景`n"
                     . "- 找文件：输入文件名关键词，可配合文件筛选。`n"
                     . "- 找复制过的内容：输入片段后切到剪贴板筛选。`n"
                     . "- 找提示词或配置：输入关键词后切到对应筛选。`n`n"
                     . "高效操作`n"
                     . "- 双击或 Enter：执行当前结果。`n"
                     . "- 右键结果：复制、发送到、置顶、删除。`n"
                     . "- 空格：对文件尝试 QuickLook 预览。`n`n"
                     . "建议`n"
                     . "- 首次使用先从文件和剪贴板两个筛选开始。`n"
                     . "- 关键词尽量短而准，必要时加第二个词缩小范围。"

    SearchCenterSearchResults.Push({
        Title: "搜索中心新手指南（从入门到高效）",
        Subtitle: tutorialContent,
        Content: tutorialContent,
        DataType: "tutorial",
        Source: "新手引导",
        Time: "快速开始"
    })
    ; 2. 璇诲彇骞舵坊鍔犵敤鎴风湡瀹炲巻鍙?(User History)
    if FileExist(historyFile) {
        try {
            content := FileRead(historyFile, "UTF-8")
            if (content != "")
                historyArr := Jxon_Load(content)
        }
    }
    
    if (Type(historyArr) == "Array") {
        limit := (SearchCenterCurrentLimit && SearchCenterCurrentLimit > 0) ? SearchCenterCurrentLimit : 30
        for _, item in historyArr {
            SearchCenterSearchResults.Push({
                Title: String(item),
                Source: "用户搜索记录",
                DataType: "history",
                Time: "",
                Path: String(item),
                OriginalDataType: "history"
            })
            ; 5 是教程占位数量
            if (SearchCenterSearchResults.Length >= (limit + 5))
                break
        }
    }
    
    SearchCenterHasMoreData := false
    SCWV_PushState("state")
}

