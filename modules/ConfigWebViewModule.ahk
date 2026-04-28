; ConfigWebViewModule.ahk — 设置中心 WebView 宿主与消息桥（由主脚本 #Include）
; 依赖：WebView2、WMActivateChain、Jxon、主脚本全局与 BuildAppLocalUrl / WebView_DumpJson 等。

ConfigWebView_CreateHost() {
    global GuiID_ConfigGUI, ConfigWebViewMode, ConfigWV2Ready, ConfigWebViewPreloaded
    global ConfigWV2Ctrl, ConfigWV2

    if (GuiID_ConfigGUI != 0)
        return

    ConfigGUI := Gui("+Resize +MinimizeBox +MaximizeBox +Owner", GetText("config_title"))
    ConfigGUI.BackColor := "0a0a0a"

    GuiID_ConfigGUI := ConfigGUI
    ConfigWebViewMode := true
    ConfigWV2Ready := false
    ConfigWV2Ctrl := 0
    ConfigWV2 := 0
    ConfigWebViewPreloaded := false

    ConfigGUI.OnEvent("Close", (*) => CloseConfigGUI())
    ConfigGUI.OnEvent("Escape", (*) => CloseConfigGUI())
    ConfigGUI.OnEvent("Size", ConfigWebView_OnSize)
    ConfigGUI.Show("w980 h680 Hide")

    WebView2.create(ConfigGUI.Hwnd, ConfigWebView_OnCreated, WebView2_EnsureSharedEnvBlocking())
}

; 延后一帧推送 initData，避免从悬浮工具栏等 WebView 的 WebMessageReceived 内同步调用时重入/队列顺序异常导致主题错为深色
ConfigWebView_SendInitDataIfReady(*) {
    global ConfigWV2Ready
    try {
        if IsSet(ConfigWV2Ready) && ConfigWV2Ready
            ConfigWebView_Send(Map("type", "initData", "payload", ConfigWebView_BuildInitDataSafe()))
    }
}

ShowConfigWebViewGUI() {
    global GuiID_ConfigGUI, GuiID_ClipboardManager, ConfigPanelScreenIndex, g_ConfigWebView_LastShown
    ; 单例
    ConfigWebView_CreateHost()
    if !GuiID_ConfigGUI
        return
    HideClipboardPanelsForConfigConflict()

    ScreenInfo := GetScreenInfo(ConfigPanelScreenIndex)
    WinW := Max(980, Round(ScreenInfo.Width * 0.80))
    WinH := Max(680, Round(ScreenInfo.Height * 0.80))
    PosX := ScreenInfo.Left + Round((ScreenInfo.Width - WinW) / 2)
    PosY := ScreenInfo.Top + Round((ScreenInfo.Height - WinH) / 2)

    GuiID_ConfigGUI.Show("w" . WinW . " h" . WinH . " x" . PosX . " y" . PosY)
    g_ConfigWebView_LastShown := A_TickCount
    WMActivateChain_Register(ConfigWebView_WM_ACTIVATE)
    ConfigWebView_ApplyBounds()
    ConfigWebView_RefreshWebViewComposition()
    SetTimer(ConfigWebView_RefreshWebViewComposition, -30)
    SetTimer(ConfigWebView_RefreshWebViewComposition, -120)
    SetTimer(ConfigWebView_RefreshWebViewComposition, -380)
    SetTimer(ConfigWebView_RefreshRasterizationScale, -50)
    SetTimer(ConfigWebView_RefreshRasterizationScale, -150)
    SetTimer(ConfigWebView_FocusDeferred, -80)
    global ConfigWV2, ConfigWV2Ready
    try WebView2_NotifyShown(ConfigWV2)
    ; 每次打开都重新推送 initData（延后一帧），确保主题等与 INI 一致且避开 WebView 回调重入
    SetTimer(ConfigWebView_SendInitDataIfReady, -1)
}

ConfigWebView_OnCreated(ctrl) {
    global ConfigWV2Ctrl, ConfigWV2, GuiID_ConfigGUI, ConfigWebViewPreloaded
    ConfigWV2Ctrl := ctrl
    ConfigWV2 := ctrl.CoreWebView2
    try ConfigWV2Ctrl.DefaultBackgroundColor := 0xFF0A0A0A
    s := ConfigWV2.Settings
    s.AreDefaultContextMenusEnabled := false
    s.AreDevToolsEnabled := true
    ApplyWebView2PerformanceSettings(ConfigWV2)
    WebView2_RegisterHostBridge(ConfigWV2)
    ConfigWV2.add_WebMessageReceived(ConfigWebView_OnMessage)
    try ConfigWV2.add_NavigationCompleted(ConfigWebView_OnNavigationCompleted)
    ConfigWebView_ApplyBounds()
    try ApplyUnifiedWebViewAssets(ConfigWV2)
    try ConfigWV2Ctrl.IsVisible := true
    htmlPath := A_ScriptDir "\SettingsPanel.html"
    try {
        ConfigWV2.Navigate(BuildAppLocalUrl("SettingsPanel.html"))
    } catch as e {
        OutputDebug("[ConfigWV2] Navigate app.local: " . e.Message)
        if FileExist(htmlPath) {
            try ConfigWV2.NavigateToString(FileRead(htmlPath, "UTF-8"))
            catch as e2 {
                OutputDebug("[ConfigWV2] NavigateToString fallback: " . e2.Message)
            }
        }
    }
    ConfigWebViewPreloaded := true
}

ConfigWebView_OnNavigationCompleted(sender, args) {
    try ok := args.IsSuccess
    catch as e
        ok := true
    if ok {
        if ConfigWebView_HostWindowVisible()
            ConfigWebView_RefreshWebViewComposition()
        return
    }
    try {
        sender.NavigateToString("<!doctype html><html><body style='background:#111;color:#eee;font-family:Segoe UI;padding:16px'>设置面板页面加载失败。请重启脚本后重试。</body></html>")
    } catch as e {
        OutputDebug("[ConfigWV2] error page failed: " . e.Message)
    }
}

ConfigWebView_OnSize(*) {
    ConfigWebView_ApplyBounds()
}

ConfigWebView_ApplyBounds() {
    global GuiID_ConfigGUI, ConfigWV2Ctrl
    if !GuiID_ConfigGUI || !ConfigWV2Ctrl
        return
    WinGetClientPos(, , &cw, &ch, GuiID_ConfigGUI.Hwnd)
    rc := WebView2.RECT()
    rc.left := 0
    rc.top := 0
    rc.right := cw
    rc.bottom := ch
    ConfigWV2Ctrl.Bounds := rc
}

; WebView2：先 Hide 再 Show 的宿主可能黑屏，需刷新合成（与 ClipboardPanel / VK 一致）
ConfigWebView_RefreshWebViewComposition(*) {
    global GuiID_ConfigGUI, ConfigWV2Ctrl
    if !GuiID_ConfigGUI || !ConfigWV2Ctrl
        return
    try {
        ConfigWebView_ApplyBounds()
        ConfigWV2Ctrl.NotifyParentWindowPositionChanged()
    } catch as e {
        OutputDebug("[ConfigWV2] RefreshWebViewComposition: " . e.Message)
    }
}

; 触发 RasterizationScale 写回，缓解高 DPI / -DPIScale 下偶发模糊
ConfigWebView_RefreshRasterizationScale(*) {
    global ConfigWV2Ctrl
    if !ConfigWV2Ctrl
        return
    try {
        sc := ConfigWV2Ctrl.RasterizationScale
        ConfigWV2Ctrl.RasterizationScale := sc
    } catch as e {
        OutputDebug("[ConfigWV2] RefreshRasterizationScale: " . e.Message)
    }
}

ConfigWebView_HostWindowVisible() {
    global GuiID_ConfigGUI
    if !GuiID_ConfigGUI
        return false
    return WinExist("ahk_id " . GuiID_ConfigGUI.Hwnd) && (WinGetStyle("ahk_id " . GuiID_ConfigGUI.Hwnd) & 0x10000000)
}

ConfigWebView_FocusDeferred(*) {
    global GuiID_ConfigGUI, ConfigWV2Ctrl
    if GuiID_ConfigGUI {
        try WinActivate(GuiID_ConfigGUI.Hwnd)
        WebView2_MoveFocusProgrammatic(ConfigWV2Ctrl)
    }
}

ConfigWebView_WM_ACTIVATE(wParam, lParam, msg, hwnd) {
    global GuiID_ConfigGUI, ConfigWebViewMode, g_ConfigWebView_LastShown
    if !ConfigWebViewMode || !GuiID_ConfigGUI
        return
    if (hwnd = GuiID_ConfigGUI.Hwnd && (wParam & 0xFFFF) = 0) {
        try {
            if (FloatingToolbar_IsForegroundToolbarOrChild())
                return
        } catch {
        }
        ; 刚 Show 后短时间内可能收到失焦（与置顶悬浮条抢焦点），勿立即关闭
        if (g_ConfigWebView_LastShown && (A_TickCount - g_ConfigWebView_LastShown < 500))
            return
        SetTimer(CloseConfigGUI, -50)
    }
}

ConfigWebView_Send(msgMap) {
    global ConfigWV2, ConfigWV2Ready
    if !ConfigWV2 || !ConfigWV2Ready
        return
    WebView_QueuePayload(ConfigWV2, msgMap)
}

ConfigWebView_EnsureSearchCoreRunning() {
    try {
        whr := ComObject("WinHttp.WinHttpRequest.5.1")
        whr.Open("GET", "http://127.0.0.1:8080/health", false)
        whr.SetTimeouts(1500, 1500, 1500, 1500)
        whr.Send()
        if (whr.Status = 200)
            return true
    } catch {
    }
    exe := ConfigWebView_SearchCoreExePath()
    if !FileExist(exe)
        return false
    try ProcessClose("SearchCenterCore.exe")
    catch {
    }
    Sleep(120)
    try {
        Run('"' exe '" -base "' A_ScriptDir '"', A_ScriptDir, "Hide")
        Loop 40 {
            Sleep(80)
            try {
                whr2 := ComObject("WinHttp.WinHttpRequest.5.1")
                whr2.Open("GET", "http://127.0.0.1:8080/health", false)
                whr2.SetTimeouts(1000, 1000, 1000, 1000)
                whr2.Send()
                if (whr2.Status = 200)
                    return true
            } catch {
            }
        }
    } catch {
    }
    return false
}

ConfigWebView_SearchCoreExePath() {
    preferred := A_ScriptDir "\searchcore\SearchCenterCore.exe"
    if FileExist(preferred)
        return preferred
    fallback := A_ScriptDir "\SearchCenterCore.exe"
    if FileExist(fallback)
        return fallback
    return ""
}

ConfigWebView_HttpSearchCoreJsonRaw(method, path, body := "") {
    try {
        whr := ComObject("WinHttp.WinHttpRequest.5.1")
        url := "http://127.0.0.1:8080" . path
        whr.Open(method, url, false)
        whr.SetTimeouts(3000, 3000, 10000, 10000)
        if (method = "POST" || method = "PUT" || method = "PATCH") {
            whr.SetRequestHeader("Content-Type", "application/json; charset=utf-8")
            payload := (Trim(String(body)) = "") ? "{}" : body
            whr.Send(payload)
        } else {
            whr.Send()
        }
        st := Integer(whr.Status)
        txt := whr.ResponseText
        obj := 0
        if (Trim(String(txt)) != "") {
            try obj := Jxon_Load(txt)
        }
        return Map("status", st, "text", txt, "json", obj)
    } catch as err {
        return Map("status", 0, "text", "", "json", 0, "error", err.Message)
    }
}

ConfigWebView_HttpSearchCoreJson(method, path, body := "") {
    resp := ConfigWebView_HttpSearchCoreJsonRaw(method, path, body)
    if (resp.Has("status") && Integer(resp["status"]) = 404 && InStr(path, "/v1/fulltext/") = 1) {
        if ConfigWebView_EnsureSearchCoreRunning()
            resp := ConfigWebView_HttpSearchCoreJsonRaw(method, path, body)
    }
    return resp
}

ConfigWebView_MergeMap(target, source) {
    if !(target is Map) || !(source is Map)
        return target
    for k, v in source
        target[k] := v
    return target
}

ConfigWebView_DefaultFullTextStatusPayload() {
    return Map(
        "running", false,
        "ready", false,
        "progress", 0,
        "progressText", "0.0%",
        "indexing_file", "",
        "indexVersion", "",
        "engine_lights", ["off", "off", "off", "off"],
        "workerCount", 0,
        "scanSpeed", "normal",
        "includeLargeText", false,
        "maxFileSizeMB", 2,
        "indexDir", "",
        "lastError", ""
    )
}

ConfigWebView_PostFullTextStatus(withConfig := true) {
    payload := ConfigWebView_DefaultFullTextStatusPayload()
    if !ConfigWebView_EnsureSearchCoreRunning() {
        ConfigWebView_Send(Map("type", "fulltextStatus", "payload", payload))
        return
    }
    stResp := ConfigWebView_HttpSearchCoreJson("GET", "/v1/fulltext/status")
    if (stResp.Has("status") && Integer(stResp["status"]) = 200 && stResp.Has("json") && (stResp["json"] is Map))
        payload := ConfigWebView_MergeMap(payload, stResp["json"])

    pgResp := ConfigWebView_HttpSearchCoreJson("GET", "/v1/fulltext/progress")
    if (pgResp.Has("status") && Integer(pgResp["status"]) = 200 && pgResp.Has("json") && (pgResp["json"] is Map))
        payload := ConfigWebView_MergeMap(payload, pgResp["json"])

    if withConfig {
        cfgResp := ConfigWebView_HttpSearchCoreJson("GET", "/v1/fulltext/config")
        if (cfgResp.Has("status") && Integer(cfgResp["status"]) = 200 && cfgResp.Has("json") && (cfgResp["json"] is Map)) {
            root := cfgResp["json"]
            if (root.Has("config"))
                payload["config"] := root["config"]
            if (root.Has("status") && (root["status"] is Map))
                payload := ConfigWebView_MergeMap(payload, root["status"])
            if (root.Has("progress") && (root["progress"] is Map))
                payload := ConfigWebView_MergeMap(payload, root["progress"])
        }
    }
    ConfigWebView_Send(Map("type", "fulltextStatus", "payload", payload))
}

ConfigWebView_FullTextControl(action) {
    act := StrLower(Trim(String(action)))
    if (act = "")
        act := "start"
    if !ConfigWebView_EnsureSearchCoreRunning() {
        ConfigWebView_Send(Map("type", "fulltextActionResult", "ok", false, "action", act, "error", "SearchCenterCore 未启动"))
        ConfigWebView_PostFullTextStatus(true)
        return
    }
    resp := ConfigWebView_HttpSearchCoreJson("POST", "/v1/fulltext/control", Jxon_Dump(Map("action", act)))
    ok := (resp.Has("status") && Integer(resp["status"]) = 200)
    err := ""
    if !ok
        err := resp.Has("text") ? String(resp["text"]) : ("HTTP " . (resp.Has("status") ? String(resp["status"]) : "0"))
    ConfigWebView_Send(Map("type", "fulltextActionResult", "ok", ok, "action", act, "error", err))
    ConfigWebView_PostFullTextStatus(true)
}

ConfigWebView_FullTextUpdateConfig(payload) {
    if !(payload is Map) {
        ConfigWebView_Send(Map("type", "fulltextConfigResult", "ok", false, "error", "配置参数无效"))
        return
    }
    if !ConfigWebView_EnsureSearchCoreRunning() {
        ConfigWebView_Send(Map("type", "fulltextConfigResult", "ok", false, "error", "SearchCenterCore 未启动"))
        ConfigWebView_PostFullTextStatus(true)
        return
    }
    resp := ConfigWebView_HttpSearchCoreJson("POST", "/v1/fulltext/config", Jxon_Dump(payload))
    ok := (resp.Has("status") && Integer(resp["status"]) = 200)
    err := ""
    if !ok
        err := resp.Has("text") ? String(resp["text"]) : ("HTTP " . (resp.Has("status") ? String(resp["status"]) : "0"))
    ConfigWebView_Send(Map("type", "fulltextConfigResult", "ok", ok, "error", err))
    ConfigWebView_PostFullTextStatus(true)
}

ConfigWebView_FullTextProbe() {
    if !ConfigWebView_EnsureSearchCoreRunning() {
        ConfigWebView_Send(Map("type", "fulltextProbeResult", "ok", false, "error", "SearchCenterCore 未启动", "probe", 0))
        return
    }
    resp := ConfigWebView_HttpSearchCoreJson("GET", "/v1/fulltext/probe")
    ok := (resp.Has("status") && Integer(resp["status"]) = 200 && resp.Has("json") && (resp["json"] is Map))
    if !ok {
        errMsg := resp.Has("text") ? String(resp["text"]) : ("HTTP " . (resp.Has("status") ? String(resp["status"]) : "0"))
        ConfigWebView_Send(Map("type", "fulltextProbeResult", "ok", false, "error", errMsg, "probe", 0))
        return
    }
    root := resp["json"]
    probe := (root.Has("probe") && (root["probe"] is Map)) ? root["probe"] : root
    ConfigWebView_Send(Map("type", "fulltextProbeResult", "ok", true, "error", "", "probe", probe))
}

JoinArray(arr, sep := ",") {
    if !(arr is Array) || arr.Length = 0
        return ""
    out := ""
    for idx, item in arr {
        if (idx > 1)
            out .= sep
        out .= item
    }
    return out
}

; 供 SettingsPanel「高级设置」悬浮条 1:1 操作台：与 Commands.json 中 ToolbarLayout / CommandList 同步
ConfigWebView_GetKeybinderToolbarSnapshot() {
    global g_Commands
    tl := []
    cmds := []
    try {
        _LoadCommands()
    } catch {
    }
    if !(IsSet(g_Commands) && g_Commands is Map)
        return Map("toolbarLayout", tl, "commands", cmds)
    if g_Commands.Has("ToolbarLayout") && g_Commands["ToolbarLayout"] is Array {
        for row in g_Commands["ToolbarLayout"] {
            if !(row is Map) || !row.Has("cmdId")
                continue
            cid := Trim(String(row["cmdId"]))
            if (cid = "")
                continue
            te := false
            if row.Has("toolbarEligible")
                te := !!row["toolbarEligible"]
            else
                te := (row.Has("visible_in_bar") && row["visible_in_bar"]) || (row.Has("visible_in_menu") && row["visible_in_menu"])
            tl.Push(Map(
                "cmdId", cid,
                "visible_in_bar", row.Has("visible_in_bar") ? !!row["visible_in_bar"] : (row.Has("in_bar") ? !!row["in_bar"] : false),
                "visible_in_menu", row.Has("visible_in_menu") ? !!row["visible_in_menu"] : (row.Has("in_context_menu") ? !!row["in_context_menu"] : false),
                "order_bar", row.Has("order_bar") ? Integer(row["order_bar"]) : -1,
                "order_menu", row.Has("order_menu") ? Integer(row["order_menu"]) : -1,
                "toolbarEligible", te
            ))
        }
    }
    if g_Commands.Has("CommandList") && g_Commands["CommandList"] is Map {
        for cid, ent in g_Commands["CommandList"] {
            if (SubStr(cid, 1, 3) = "pt_")
                continue
            nm := (ent is Map && ent.Has("name")) ? String(ent["name"]) : cid
            desc := (ent is Map && ent.Has("desc")) ? String(ent["desc"]) : ""
            fn := (ent is Map && ent.Has("fn")) ? String(ent["fn"]) : ""
            ic := (ent is Map && ent.Has("iconClass")) ? String(ent["iconClass"]) : ""
            cmds.Push(Map("id", cid, "name", nm, "desc", desc, "fn", fn, "iconClass", ic))
        }
    }
    cml := []
    if (g_Commands.Has("ContextMenuLayout") && g_Commands["ContextMenuLayout"] is Array) {
        for item in g_Commands["ContextMenuLayout"]
            cml.Push(String(item))
    }
    return Map("toolbarLayout", tl, "commands", cmds, "contextMenuLayout", cml)
}

ConfigWebView_BuildInitData() {
    global CursorPath, CapsLockHoldTimeSeconds, CapsLockHoldVkEnabled, AutoStart, DefaultStartTab
    global ThemeMode, FunctionPanelPos, ConfigPanelScreenIndex, ConfigPanelPos, ClipboardPanelPos, PanelScreenIndex
    global Prompt_Explain, Prompt_Refactor, Prompt_Optimize
    global HotkeyESC, HotkeyC, HotkeyV, HotkeyX, HotkeyE, HotkeyR, HotkeyO, HotkeyQ, HotkeyZ, SplitHotkey, BatchHotkey, HotkeyT, HotkeyF, HotkeyP
    global PromptQuickCaptureHotkey, QuickActionButtons
    global Language, AISleepTime, LaunchDelaySeconds, MsgBoxScreenIndex, VoiceInputScreenIndex, CursorPanelScreenIndex, ClipboardPanelScreenIndex
    global SearchEngine, AutoLoadSelectedText, AutoUpdateVoiceInput, VoiceSearchEnabledCategories, VoiceSearchSelectedEngines
    global ConfigFile, DefaultTemplateIDs, PromptTemplates
    global FloatingToolbarButtonItems, FloatingToolbarMenuItems, FloatingToolbarButtonOptions, FloatingToolbarMenuOptions
    global AppearanceActivationMode
    monitorCount := 1
    try monitorCount := MonitorGetCount()
    catch
        monitorCount := 1
    popupScreenIndex := PanelScreenIndex
    if (popupScreenIndex < 1)
        popupScreenIndex := 1
    if (popupScreenIndex > monitorCount)
        popupScreenIndex := monitorCount
    hotkeys := Map(
        "ESC", HotkeyESC, "C", HotkeyC, "V", HotkeyV, "X", HotkeyX, "E", HotkeyE, "R", HotkeyR, "O", HotkeyO,
        "Q", HotkeyQ, "Z", HotkeyZ, "S", SplitHotkey, "B", BatchHotkey, "T", HotkeyT, "F", HotkeyF, "P", HotkeyP
    )
    qa := []
    for item in QuickActionButtons {
        qaType := "Explain"
        qaHotkey := "e"
        if (item is Map) {
            qaType := item.Get("Type", qaType)
            qaHotkey := item.Get("Hotkey", qaHotkey)
        } else if (IsObject(item)) {
            if item.HasProp("Type")
                qaType := item.Type
            if item.HasProp("Hotkey")
                qaHotkey := item.Hotkey
        }
        qa.Push(Map("type", qaType, "hotkey", qaHotkey))
    }
    cats := []
    for c in VoiceSearchEnabledCategories
        cats.Push(c)
    toolbarButtons := FTB_SanitizeToolbarButtonItems(FloatingToolbarButtonItems)
    toolbarMenus := FTB_SanitizeToolbarMenuItems(FloatingToolbarMenuItems)
    selectedCsv := ""
    if (IsSet(VoiceSearchSelectedEngines) && VoiceSearchSelectedEngines.Length > 0)
        selectedCsv := JoinArray(VoiceSearchSelectedEngines, ",")
    promptTemplateSummary := []
    if (IsSet(PromptTemplates) && PromptTemplates is Array) {
        for t in PromptTemplates {
            tid := ""
            ttitle := ""
            tcat := ""
            if (t is Map) {
                tid := t.Get("ID", "")
                ttitle := t.Get("Title", "")
                tcat := t.Get("Category", t.Get("FunctionCategory", ""))
            } else if (IsObject(t)) {
                if t.HasProp("ID")
                    tid := t.ID
                if t.HasProp("Title")
                    ttitle := t.Title
                if t.HasProp("Category")
                    tcat := t.Category
                else if t.HasProp("FunctionCategory")
                    tcat := t.FunctionCategory
            }
            tcontent := ""
            if (t is Map)
                tcontent := t.Get("Content", "")
            else if (IsObject(t) && t.HasProp("Content"))
                tcontent := t.Content
            promptTemplateSummary.Push(Map("id", tid, "title", ttitle, "category", tcat, "content", tcontent))
        }
    }
    templateIds := (IsSet(DefaultTemplateIDs) && DefaultTemplateIDs is Map) ? DefaultTemplateIDs : Map()
    defaultTemplates := Map(
        "Explain", templateIds.Has("Explain") ? templateIds["Explain"] : "",
        "Refactor", templateIds.Has("Refactor") ? templateIds["Refactor"] : "",
        "Optimize", templateIds.Has("Optimize") ? templateIds["Optimize"] : ""
    )
    cursorRules := Map(
        "general", IniRead(ConfigFile, "CursorRules", "general", ""),
        "web", IniRead(ConfigFile, "CursorRules", "web", ""),
        "miniprogram", IniRead(ConfigFile, "CursorRules", "miniprogram", ""),
        "android", IniRead(ConfigFile, "CursorRules", "android", ""),
        "ios", IniRead(ConfigFile, "CursorRules", "ios", ""),
        "python", IniRead(ConfigFile, "CursorRules", "python", "")
    )
    cfgPayload := Map(
        "cursorPath", CursorPath,
        "capslockHoldTimeSeconds", CapsLockHoldTimeSeconds,
        "capsLockHoldVkEnabled", CapsLockHoldVkEnabled,
        "autoStart", AutoStart,
        "defaultStartTab", DefaultStartTab,
        ; 必须以 INI 为准：内存中 ThemeMode 可能与磁盘不一致（例如从 WebView 回调打开设置时）
        "themeMode", ReadPersistedThemeMode(),
        "popupScreenIndex", popupScreenIndex,
        "monitorCount", monitorCount,
        "functionPanelPos", FunctionPanelPos,
        "configPanelScreenIndex", ConfigPanelScreenIndex,
        "configPanelPos", ConfigPanelPos,
        "clipboardPanelPos", ClipboardPanelPos,
        "panelScreenIndex", PanelScreenIndex,
        "promptExplain", Prompt_Explain,
        "promptRefactor", Prompt_Refactor,
        "promptOptimize", Prompt_Optimize,
        "cursorRules", cursorRules,
        "promptTemplateSummary", promptTemplateSummary,
        "defaultTemplates", defaultTemplates,
        "hotkeys", hotkeys,
        "promptQuickCaptureHotkey", PromptQuickCaptureHotkey,
        "quickActions", qa,
        "language", Language,
        "aiSleepTime", AISleepTime,
        "launchDelaySeconds", LaunchDelaySeconds,
        "msgBoxScreenIndex", MsgBoxScreenIndex,
        "voiceInputScreenIndex", VoiceInputScreenIndex,
        "cursorPanelScreenIndex", CursorPanelScreenIndex,
        "clipboardPanelScreenIndex", ClipboardPanelScreenIndex,
        "searchEngine", SearchEngine,
        "autoLoadSelectedText", AutoLoadSelectedText,
        "autoUpdateVoiceInput", AutoUpdateVoiceInput,
        "voiceSearchEnabledCategories", cats,
        "voiceSearchSelectedEnginesCsv", selectedCsv,
        "floatingToolbarButtons", toolbarButtons,
        "floatingToolbarMenuItems", toolbarMenus,
        "floatingToolbarButtonOptions", FloatingToolbarButtonOptions,
        "floatingToolbarMenuOptions", FloatingToolbarMenuOptions,
        "appearanceActivationMode", NormalizeAppearanceActivationMode(AppearanceActivationMode)
    )
    kbSnap := ConfigWebView_GetKeybinderToolbarSnapshot()
    cfgPayload["keybinderToolbarLayout"] := kbSnap["toolbarLayout"]
    cfgPayload["keybinderCommands"] := kbSnap["commands"]
    cfgPayload["keybinderContextMenuLayout"] := kbSnap.Has("contextMenuLayout") ? kbSnap["contextMenuLayout"] : []
    return cfgPayload
}

ConfigWebView_BuildInitDataSafe() {
    global ThemeMode
    try {
        return ConfigWebView_BuildInitData()
    } catch as err {
        OutputDebug("[ConfigWebView] BuildInitData failed: " . err.Message)
        _tm := ReadPersistedThemeMode()
        return Map(
            "cursorPath", "",
            "capslockHoldTimeSeconds", 0.5,
            "capsLockHoldVkEnabled", true,
            "autoStart", false,
            "defaultStartTab", "general",
            "themeMode", _tm,
            "popupScreenIndex", 1,
            "monitorCount", 1,
            "functionPanelPos", "center",
            "configPanelScreenIndex", 1,
            "configPanelPos", "center",
            "clipboardPanelPos", "center",
            "panelScreenIndex", 1,
            "promptExplain", "",
            "promptRefactor", "",
            "promptOptimize", "",
            "cursorRules", Map("general","", "web","", "miniprogram","", "android","", "ios","", "python",""),
            "promptTemplateSummary", [],
            "defaultTemplates", Map("Explain","", "Refactor","", "Optimize",""),
            "hotkeys", Map("ESC","", "C","", "V","", "X","", "E","", "R","", "O","", "Q","", "Z","", "S","", "B","", "T","", "F","", "P",""),
            "promptQuickCaptureHotkey", "",
            "quickActions", [Map("type","Explain","hotkey","e"), Map("type","Refactor","hotkey","r"), Map("type","Optimize","hotkey","o"), Map("type","Config","hotkey","q"), Map("type","Explain","hotkey","e")],
            "language", "zh",
            "aiSleepTime", 200,
            "launchDelaySeconds", 3.0,
            "msgBoxScreenIndex", 1,
            "voiceInputScreenIndex", 1,
            "cursorPanelScreenIndex", 1,
            "clipboardPanelScreenIndex", 1,
            "searchEngine", "deepseek",
            "autoLoadSelectedText", false,
            "autoUpdateVoiceInput", true,
            "voiceSearchEnabledCategories", ["ai","cli","academic","baidu","image","audio","video","book","price","medical","cloud"],
            "voiceSearchSelectedEnginesCsv", "deepseek",
            "floatingToolbarButtons", ["Search","Record","Prompt","NewPrompt","Screenshot","Settings","VirtualKeyboard"],
            "floatingToolbarMenuItems", ["ToggleToolbar","MinimizeToEdge","ResetScale","SearchCenter","Clipboard","OpenConfig","HideToolbar","ReloadScript","ExitApp"],
            "floatingToolbarButtonOptions", [
                Map("id","Search","name","搜索"),
                Map("id","Record","name","记录"),
                Map("id","Prompt","name","提示词"),
                Map("id","NewPrompt","name","草稿本"),
                Map("id","Screenshot","name","截图"),
                Map("id","Settings","name","设置"),
                Map("id","VirtualKeyboard","name","虚拟键盘")
            ],
            "floatingToolbarMenuOptions", [
                Map("id","ToggleToolbar","name","显示/隐藏工具栏"),
                Map("id","MinimizeToEdge","name","最小化到边缘"),
                Map("id","ResetScale","name","重置大小"),
                Map("id","SearchCenter","name","搜索中心"),
                Map("id","Clipboard","name","剪贴板"),
                Map("id","OpenConfig","name","打开设置"),
                Map("id","HideToolbar","name","关闭工具栏"),
                Map("id","ReloadScript","name","重启脚本"),
                Map("id","ExitApp","name","退出程序")
            ],
            "appearanceActivationMode", "toolbar",
            "keybinderToolbarLayout", [],
            "keybinderCommands", [],
            "keybinderContextMenuLayout", []
        )
    }
}

ConfigWebView_SendDockConfig() {
    arr := []
    try {
        if IsSet(_LoadCommands)
            _LoadCommands()
        global g_Commands
        if (g_Commands is Map && g_Commands.Has("SceneToolbarLayout") && g_Commands["SceneToolbarLayout"] is Array) {
            for row in g_Commands["SceneToolbarLayout"] {
                if !(row is Map) || !row.Has("sceneId")
                    continue
                sid := Trim(String(row["sceneId"]))
                if (sid = "")
                    continue
                arr.Push(Map(
                    "sceneId", sid,
                    "visible_in_bar", row.Has("visible_in_bar") ? (row["visible_in_bar"] ? true : false) : true,
                    "order_bar", row.Has("order_bar") ? Integer(row["order_bar"]) : -1
                ))
            }
        }
    } catch {
    }
    ConfigWebView_Send(Map("type", "nmDockConfig", "sceneToolbarLayout", arr))
}

ConfigWebView_ExecuteDockCmd(msg) {
    cmdId0 := msg.Has("cmdId") ? String(msg["cmdId"]) : ""
    if (cmdId0 = "")
        return
    if (cmdId0 = "open_cloudplayer") {
        try ShowCloudPlayer()
        return
    }
    m0 := Map(
        "Title", "dock",
        "Content", "",
        "DataType", "text",
        "OriginalDataType", "text",
        "Source", "dock",
        "ClipboardId", 0,
        "PromptMergedIndex", 0,
        "HubSegIndex", -1
    )
    try SC_ExecuteContextCommand(cmdId0, 0, m0)
    catch as err {
        OutputDebug("[ConfigWebView] nmDockCmd: " . err.Message)
    }
}

ConfigWebView_ValidateAndApply(payload, &errorMsg := "") {
    global CursorPath, CapsLockHoldTimeSeconds, CapsLockHoldVkEnabled, AutoStart, DefaultStartTab
    global ThemeMode, FunctionPanelPos, ConfigPanelScreenIndex, ConfigPanelPos, ClipboardPanelPos, PanelScreenIndex
    global Prompt_Explain, Prompt_Refactor, Prompt_Optimize
    global HotkeyESC, HotkeyC, HotkeyV, HotkeyX, HotkeyE, HotkeyR, HotkeyO, HotkeyQ, HotkeyZ, SplitHotkey, BatchHotkey, HotkeyT, HotkeyF, HotkeyP
    global PromptQuickCaptureHotkey, QuickActionButtons
    global Language, AISleepTime, LaunchDelaySeconds, MsgBoxScreenIndex, VoiceInputScreenIndex, CursorPanelScreenIndex, ClipboardPanelScreenIndex
    global SearchEngine, AutoLoadSelectedText, AutoUpdateVoiceInput, VoiceSearchEnabledCategories, VoiceSearchSelectedEngines
    global FloatingToolbarButtonItems
    global AppearanceActivationMode
    global ConfigFile

    try {
        if !(payload is Map) {
            errorMsg := "payload 无效"
            return false
        }
        NewCursorPath := NormalizeWindowsPath(payload.Get("cursorPath", ""))
        if (NewCursorPath = "") {
            errorMsg := "Cursor Path 不能为空"
            return false
        }
        NewHold := Float(payload.Get("capslockHoldTimeSeconds", 0.5))
        if (NewHold < 0.1 || NewHold > 5.0) {
            errorMsg := "CapsLock Hold Time 超出范围"
            return false
        }
        NewAutoStart := payload.Get("autoStart", false) ? true : false
        NewCapsLockHoldVk := CapsLockHoldVkEnabled
        if (payload.Has("capsLockHoldVkEnabled"))
            NewCapsLockHoldVk := payload["capsLockHoldVkEnabled"] ? true : false
        NewDefaultTab := payload.Get("defaultStartTab", "general")
        validTabs := Map("general",1, "appearance",1, "prompts",1, "hotkeys",1, "advanced",1, "search",1)
        if !validTabs.Has(NewDefaultTab)
            NewDefaultTab := "general"
        NewTheme := ThemeMode
        if (payload.Has("themeMode"))
            NewTheme := payload["themeMode"]
        else if (payload.Has("ThemeMode"))
            NewTheme := payload["ThemeMode"]
        NewTheme := NormalizeIniThemeMode(NewTheme, NormalizeIniThemeMode(ThemeMode, "dark"))
        NewPanelPos := payload.Get("functionPanelPos", "center")
        validPos := Map("center",1, "top-left",1, "top-right",1, "bottom-left",1, "bottom-right",1)
        if !validPos.Has(NewPanelPos)
            NewPanelPos := "center"
        monitorCount := 1
        try monitorCount := MonitorGetCount()
        catch
            monitorCount := 1
        NewPopupScreen := Integer(payload.Get("popupScreenIndex", payload.Get("panelScreenIndex", 1)))
        if (NewPopupScreen < 1)
            NewPopupScreen := 1
        if (NewPopupScreen > monitorCount)
            NewPopupScreen := monitorCount
        NewConfigPanelPos := payload.Get("configPanelPos", "center")
        if !validPos.Has(NewConfigPanelPos)
            NewConfigPanelPos := "center"
        NewClipboardPanelPos := payload.Get("clipboardPanelPos", "center")
        if !validPos.Has(NewClipboardPanelPos)
            NewClipboardPanelPos := "center"
        NewPromptExplain := payload.Get("promptExplain", "")
        NewPromptRefactor := payload.Get("promptRefactor", "")
        NewPromptOptimize := payload.Get("promptOptimize", "")
        NewCursorRules := Map(
            "general", IniRead(ConfigFile, "CursorRules", "general", ""),
            "web", IniRead(ConfigFile, "CursorRules", "web", ""),
            "miniprogram", IniRead(ConfigFile, "CursorRules", "miniprogram", ""),
            "android", IniRead(ConfigFile, "CursorRules", "android", ""),
            "ios", IniRead(ConfigFile, "CursorRules", "ios", ""),
            "python", IniRead(ConfigFile, "CursorRules", "python", "")
        )
        if (payload.Has("cursorRules") && payload["cursorRules"] is Map) {
            crPayload := payload["cursorRules"]
            for k in ["general","web","miniprogram","android","ios","python"] {
                if crPayload.Has(k)
                    NewCursorRules[k] := crPayload.Get(k, "")
            }
        }
        NewLanguage := payload.Get("language", "zh")
        if (NewLanguage != "zh" && NewLanguage != "en")
            NewLanguage := "zh"
        NewAiSleepTime := Integer(payload.Get("aiSleepTime", 200))
        if (NewAiSleepTime < 50)
            NewAiSleepTime := 50
        NewLaunchDelay := Float(payload.Get("launchDelaySeconds", 3.0))
        if (NewLaunchDelay < 0.5)
            NewLaunchDelay := 0.5
        if (NewLaunchDelay > 10.0)
            NewLaunchDelay := 10.0
        NewSearchEngine := Trim(payload.Get("searchEngine", "deepseek"))
        if (NewSearchEngine = "")
            NewSearchEngine := "deepseek"
        NewAutoLoad := payload.Get("autoLoadSelectedText", false) ? true : false
        NewAutoUpdate := payload.Get("autoUpdateVoiceInput", true) ? true : false
        NewCaptureHotkey := Trim(payload.Get("promptQuickCaptureHotkey", ""))
        NewVoiceEngineCsv := Trim(payload.Get("voiceSearchSelectedEnginesCsv", ""))
        NewVoiceCats := []
        if (payload.Has("voiceSearchEnabledCategories") && payload["voiceSearchEnabledCategories"] is Array) {
            for c in payload["voiceSearchEnabledCategories"] {
                if (c != "")
                    NewVoiceCats.Push(c)
            }
        }
        if (NewVoiceCats.Length = 0)
            NewVoiceCats := ["ai","cli","academic","baidu","image","audio","video","book","price","medical","cloud"]
        _amRaw := ""
        if (payload is Map) {
            if payload.Has("appearanceActivationMode")
                _amRaw := payload["appearanceActivationMode"]
            else if payload.Has("AppearanceActivationMode")
                _amRaw := payload["AppearanceActivationMode"]
        }
        if (_amRaw = "" && payload is Map)
            _amRaw := payload.Get("appearanceActivationMode", "toolbar")
        if (_amRaw = "")
            _amRaw := "toolbar"
        NewAppearanceActivationMode := NormalizeAppearanceActivationMode(_amRaw)
        NewFloatingToolbarButtons := FTB_SanitizeToolbarButtonItems(FloatingToolbarButtonItems)
        if (payload.Has("floatingToolbarButtons") && payload["floatingToolbarButtons"] is Array)
            NewFloatingToolbarButtons := FTB_SanitizeToolbarButtonItems(payload["floatingToolbarButtons"])
        NewQuickActions := []
        if (payload.Has("quickActions") && payload["quickActions"] is Array) {
            for item in payload["quickActions"] {
                if (item is Map) {
                    qaType := item.Get("type", "Explain")
                    qaHotkey := item.Get("hotkey", "")
                    NewQuickActions.Push(Map("Type", qaType, "Hotkey", qaHotkey))
                }
            }
        }
        while (NewQuickActions.Length < 5)
            NewQuickActions.Push(Map("Type", "Explain", "Hotkey", "e"))
        while (NewQuickActions.Length > 5)
            NewQuickActions.Pop()
        hkMap := payload.Get("hotkeys", Map())
        hkGet(Key, Def) {
            if (hkMap is Map && hkMap.Has(Key))
                return Trim(hkMap[Key])
            return Def
        }
        NewHotkeyESC := hkGet("ESC", HotkeyESC)
        NewHotkeyC := hkGet("C", HotkeyC)
        NewHotkeyV := hkGet("V", HotkeyV)
        NewHotkeyX := hkGet("X", HotkeyX)
        NewHotkeyE := hkGet("E", HotkeyE)
        NewHotkeyR := hkGet("R", HotkeyR)
        NewHotkeyO := hkGet("O", HotkeyO)
        NewHotkeyQ := hkGet("Q", HotkeyQ)
        NewHotkeyZ := hkGet("Z", HotkeyZ)
        NewSplitHotkey := hkGet("S", SplitHotkey)
        NewBatchHotkey := hkGet("B", BatchHotkey)
        NewHotkeyT := hkGet("T", HotkeyT)
        NewHotkeyF := hkGet("F", HotkeyF)
        NewHotkeyP := hkGet("P", HotkeyP)

        CursorPath := NewCursorPath
        CapsLockHoldTimeSeconds := NewHold
        CapsLockHoldVkEnabled := NewCapsLockHoldVk
        AutoStart := NewAutoStart
        DefaultStartTab := NewDefaultTab
        ThemeMode := NewTheme
        FunctionPanelPos := NewPanelPos
        ConfigPanelPos := NewConfigPanelPos
        ClipboardPanelPos := NewClipboardPanelPos
        PanelScreenIndex := NewPopupScreen
        ConfigPanelScreenIndex := NewPopupScreen
        Prompt_Explain := NewPromptExplain
        Prompt_Refactor := NewPromptRefactor
        Prompt_Optimize := NewPromptOptimize
        HotkeyESC := NewHotkeyESC
        HotkeyC := NewHotkeyC
        HotkeyV := NewHotkeyV
        HotkeyX := NewHotkeyX
        HotkeyE := NewHotkeyE
        HotkeyR := NewHotkeyR
        HotkeyO := NewHotkeyO
        HotkeyQ := NewHotkeyQ
        HotkeyZ := NewHotkeyZ
        SplitHotkey := NewSplitHotkey
        BatchHotkey := NewBatchHotkey
        HotkeyT := NewHotkeyT
        HotkeyF := NewHotkeyF
        HotkeyP := NewHotkeyP
        PromptQuickCaptureHotkey := NewCaptureHotkey
        QuickActionButtons := NewQuickActions
        Language := NewLanguage
        AISleepTime := NewAiSleepTime
        LaunchDelaySeconds := NewLaunchDelay
        MsgBoxScreenIndex := NewPopupScreen
        VoiceInputScreenIndex := NewPopupScreen
        CursorPanelScreenIndex := NewPopupScreen
        ClipboardPanelScreenIndex := NewPopupScreen
        SearchEngine := NewSearchEngine
        AutoLoadSelectedText := NewAutoLoad
        AutoUpdateVoiceInput := NewAutoUpdate
        VoiceSearchEnabledCategories := NewVoiceCats
        FloatingToolbarButtonItems := NewFloatingToolbarButtons
        AppearanceActivationMode := NewAppearanceActivationMode
        VoiceSearchSelectedEngines := []
        if (NewVoiceEngineCsv != "") {
            for item in StrSplit(NewVoiceEngineCsv, ",") {
                v := Trim(item)
                if (v != "")
                    VoiceSearchSelectedEngines.Push(v)
            }
        }
        if (VoiceSearchSelectedEngines.Length = 0)
            VoiceSearchSelectedEngines.Push("deepseek")
        ; 先持久化主题再 ApplyTheme，避免 FloatingToolbar 等从 INI 读到旧值；ApplyTheme 内也会显式传入 Mode
        IniWrite(NewTheme, ConfigFile, "Settings", "ThemeMode")
        IniWrite(NewTheme, ConfigFile, "Appearance", "ThemeMode")
        ApplyTheme(NewTheme)

        IniWrite(CursorPath, ConfigFile, "Settings", "CursorPath")
        IniWrite(String(AISleepTime), ConfigFile, "Settings", "AISleepTime")
        IniWrite(String(CapsLockHoldTimeSeconds), ConfigFile, "Settings", "CapsLockHoldTimeSeconds")
        IniWrite(CapsLockHoldVkEnabled ? "1" : "0", ConfigFile, "Settings", "CapsLockHoldVkEnabled")
        IniWrite(String(LaunchDelaySeconds), ConfigFile, "Settings", "LaunchDelaySeconds")
        IniWrite(Language, ConfigFile, "Settings", "Language")
        IniWrite(Prompt_Explain, ConfigFile, "Settings", "Prompt_Explain")
        IniWrite(Prompt_Refactor, ConfigFile, "Settings", "Prompt_Refactor")
        IniWrite(Prompt_Optimize, ConfigFile, "Settings", "Prompt_Optimize")
        IniWrite(AutoStart ? "1" : "0", ConfigFile, "Settings", "AutoStart")
        IniWrite(DefaultStartTab, ConfigFile, "Settings", "DefaultStartTab")
        IniWrite(PromptQuickCaptureHotkey, ConfigFile, "Settings", "PromptQuickCaptureHotkey")
        IniWrite(SearchEngine, ConfigFile, "Settings", "SearchEngine")
        IniWrite(AutoLoadSelectedText ? "1" : "0", ConfigFile, "Settings", "AutoLoadSelectedText")
        IniWrite(AutoUpdateVoiceInput ? "1" : "0", ConfigFile, "Settings", "AutoUpdateVoiceInput")
        IniWrite(JoinArray(VoiceSearchEnabledCategories, ","), ConfigFile, "Settings", "VoiceSearchEnabledCategories")
        IniWrite(JoinArray(VoiceSearchSelectedEngines, ","), ConfigFile, "Settings", "VoiceSearchSelectedEngines")
        IniWrite(FTB_ItemsToCsv(FloatingToolbarButtonItems), ConfigFile, "Settings", "FloatingToolbarButtonItems")
        IniWrite(NewCursorRules["general"], ConfigFile, "CursorRules", "general")
        IniWrite(NewCursorRules["web"], ConfigFile, "CursorRules", "web")
        IniWrite(NewCursorRules["miniprogram"], ConfigFile, "CursorRules", "miniprogram")
        IniWrite(NewCursorRules["android"], ConfigFile, "CursorRules", "android")
        IniWrite(NewCursorRules["ios"], ConfigFile, "CursorRules", "ios")
        IniWrite(NewCursorRules["python"], ConfigFile, "CursorRules", "python")
        IniWrite(HotkeyESC, ConfigFile, "Hotkeys", "ESC")
        IniWrite(HotkeyC, ConfigFile, "Hotkeys", "C")
        IniWrite(HotkeyV, ConfigFile, "Hotkeys", "V")
        IniWrite(HotkeyX, ConfigFile, "Hotkeys", "X")
        IniWrite(HotkeyE, ConfigFile, "Hotkeys", "E")
        IniWrite(HotkeyR, ConfigFile, "Hotkeys", "R")
        IniWrite(HotkeyO, ConfigFile, "Hotkeys", "O")
        IniWrite(HotkeyQ, ConfigFile, "Hotkeys", "Q")
        IniWrite(HotkeyZ, ConfigFile, "Hotkeys", "Z")
        IniWrite(SplitHotkey, ConfigFile, "Hotkeys", "Split")
        IniWrite(BatchHotkey, ConfigFile, "Hotkeys", "Batch")
        IniWrite(HotkeyT, ConfigFile, "Hotkeys", "T")
        IniWrite(HotkeyF, ConfigFile, "Hotkeys", "F")
        IniWrite(HotkeyP, ConfigFile, "Hotkeys", "P")
        IniWrite("5", ConfigFile, "QuickActions", "ButtonCount")
        Loop 5 {
            idx := A_Index
            btnType := "Explain"
            btnHotkey := "e"
            btn := QuickActionButtons[idx]
            if (btn is Map) {
                btnType := btn.Get("Type", btnType)
                btnHotkey := btn.Get("Hotkey", btnHotkey)
            } else if (IsObject(btn)) {
                if btn.HasProp("Type")
                    btnType := btn.Type
                if btn.HasProp("Hotkey")
                    btnHotkey := btn.Hotkey
            }
            IniWrite(btnType, ConfigFile, "QuickActions", "Button" . idx . "Type")
            IniWrite(btnHotkey, ConfigFile, "QuickActions", "Button" . idx . "Hotkey")
        }
        IniWrite(PanelScreenIndex, ConfigFile, "Appearance", "ScreenIndex")
        IniWrite(PanelScreenIndex, ConfigFile, "Appearance", "PopupScreenIndex")
        IniWrite(AppearanceActivationMode, ConfigFile, "Appearance", "ActivationMode")
        IniWrite(FunctionPanelPos, ConfigFile, "Appearance", "FunctionPanelPos")
        IniWrite(ConfigPanelPos, ConfigFile, "Appearance", "ConfigPanelPos")
        IniWrite(ClipboardPanelPos, ConfigFile, "Appearance", "ClipboardPanelPos")
        IniWrite(ConfigPanelScreenIndex, ConfigFile, "Advanced", "ConfigPanelScreenIndex")
        IniWrite(MsgBoxScreenIndex, ConfigFile, "Advanced", "MsgBoxScreenIndex")
        IniWrite(VoiceInputScreenIndex, ConfigFile, "Advanced", "VoiceInputScreenIndex")
        IniWrite(CursorPanelScreenIndex, ConfigFile, "Advanced", "CursorPanelScreenIndex")
        IniWrite(ClipboardPanelScreenIndex, ConfigFile, "Advanced", "ClipboardPanelScreenIndex")
        SetAutoStart(AutoStart)
        PromptQuickPad_RegisterCaptureHotkey()
        try FloatingToolbarPushButtonConfigToWeb()
        try ApplyAppearanceActivationMode()
        catch {
        }
        return true
    } catch as err {
        errorMsg := "保存失败: " . err.Message
        return false
    }
}

ConfigWebView_OnMessage(sender, args) {
    global ConfigWV2Ready, UseWebViewSettings
    jsonStr := args.WebMessageAsJson
    try {
        msg := Jxon_Load(jsonStr)
    } catch {
        return
    }
    if !(msg is Map)
        return
    action := msg.Has("type") ? msg["type"] : (msg.Has("action") ? msg["action"] : "")
    if (action = "")
        return
    switch action {
        case "ready":
            ConfigWV2Ready := true
            ConfigWebView_Send(Map("type", "initData", "payload", ConfigWebView_BuildInitDataSafe()))
            ConfigWebView_PostFullTextStatus(true)
            ConfigWebView_SendDockConfig()
        case "nmDockReady":
            ConfigWebView_SendDockConfig()
        case "nmDockCmd":
            ConfigWebView_ExecuteDockCmd(msg)
        case "fulltextStatusRequest":
            withCfg := msg.Has("withConfig") ? (msg["withConfig"] ? true : false) : true
            ConfigWebView_PostFullTextStatus(withCfg)
        case "fulltextControl":
            act := msg.Has("control") ? String(msg["control"]) : "start"
            ConfigWebView_FullTextControl(act)
        case "fulltextConfigUpdate":
            pl := msg.Has("payload") && (msg["payload"] is Map) ? msg["payload"] : Map()
            ConfigWebView_FullTextUpdateConfig(pl)
        case "fulltextPickIndexDir":
            selectedDir := ""
            try selectedDir := FileSelect("D", A_ScriptDir, "选择索引目录")
            if (selectedDir = "")
                selectedDir := ""
            ConfigWebView_Send(Map("type", "fulltextBrowseResult", "path", selectedDir))
        case "fulltextProbeRequest":
            ConfigWebView_FullTextProbe()
        case "browseCursorPath":
            selected := FileSelect("1", A_ScriptDir, "选择 Cursor.exe", "Executable (*.exe)")
            if (selected = "")
                selected := ""
            ConfigWebView_Send(Map("type", "browseCursorPathResult", "path", selected))
        case "saveSettings":
            payload := msg.Get("payload", Map())
            if (payload is String && payload != "") {
                try payload := Jxon_Load(payload)
                catch {
                    payload := Map()
                }
            }
            if !(payload is Map)
                payload := Map()
            err := ""
            ok := ConfigWebView_ValidateAndApply(payload, &err)
            ConfigWebView_Send(Map("type", "saveResult", "ok", ok, "error", err))
        case "saveKeybinderToolbarLayout":
            tl := msg.Has("toolbarLayout") && msg["toolbarLayout"] is Array ? msg["toolbarLayout"] : []
            cml := msg.Has("contextMenuLayout") && msg["contextMenuLayout"] is Array ? msg["contextMenuLayout"] : []
            ok := false
            err := ""
            try {
                try {
                    _LoadCommands()
                } catch {
                }
                if _VK_ApplyToolbarLayoutFromWeb(Map("toolbarLayout", tl)) {
                    _VK_ApplyContextMenuLayoutFromWeb(cml)
                    _SaveBindings()
                    try FloatingToolbarReloadFromToolbarLayout()
                    catch as e
                        OutputDebug("[ConfigWebView] FloatingToolbarReloadFromToolbarLayout: " . e.Message)
                    if (IsSet(g_VK_Ready) && g_VK_Ready)
                        _PushInit()
                    ok := true
                } else
                    err := "工具栏布局无效或未加载命令表"
            } catch as e {
                err := e.Message
            }
            ConfigWebView_Send(Map("type", "saveKeybinderToolbarLayoutResult", "ok", ok, "error", err))
        case "invokeAction":
            op := msg.Get("op", msg.Get("action", ""))
            payload := msg.Get("payload", Map())
            ok := true
            err := ""
            try {
                switch op {
                    case "installCursorChinese":
                        InstallCursorChinese()
                    case "exportConfig":
                        ExportConfig()
                    case "importConfig":
                        ImportConfig()
                    case "resetToDefaults":
                        ResetToDefaults()
                    case "importPromptTemplates":
                        ImportPromptTemplates()
                    case "exportPromptTemplates":
                        ExportPromptTemplates()
                    case "reloadPromptTemplates":
                        LoadPromptTemplates()
                    case "promptTemplateUpsert":
                        WebViewPromptTemplateUpsert(payload)
                    case "promptTemplateDelete":
                        WebViewPromptTemplateDelete(payload)
                    case "promptTemplateSetDefault":
                        WebViewPromptTemplateSetDefault(payload)
                    case "openLegacySettings":
                        try {
                            CloseConfigGUI()
                        } catch {
                        }
                        OpenLegacyConfigGUI()
                    case "openLegacyTab":
                        targetTab := msg.Get("tab", "general")
                        try {
                            CloseConfigGUI()
                        } catch {
                        }
                        OpenLegacyConfigGUI(targetTab)
                    case "openCompareSettings":
                        ; 保留当前 WebView，同时再打开一份原版设置页用于对照
                        OpenLegacyConfigGUI()
                    default:
                        ok := false
                        err := "未知操作: " . op
                }
            } catch as e {
                ok := false
                err := e.Message
            }
            ConfigWebView_Send(Map("type", "actionResult", "ok", ok, "error", err, "op", op))
            if ok
                ConfigWebView_Send(Map("type", "initData", "payload", ConfigWebView_BuildInitDataSafe()))
        case "cancel":
            CloseConfigGUI()
    }
}


WebViewPromptTemplateUpsert(payload) {
    global PromptTemplates, TemplateIndexByArrayIndex
    if !(payload is Map)
        throw Error("模板数据无效")
    tId := Trim(payload.Get("id", ""))
    tTitle := Trim(payload.Get("title", ""))
    tCategory := Trim(payload.Get("category", ""))
    tContent := payload.Get("content", "")
    if (tTitle = "" || tContent = "")
        throw Error("模板标题和内容不能为空")
    if (tCategory = "")
        tCategory := "自定义"
    if (tId != "" && TemplateIndexByArrayIndex.Has(tId)) {
        idx := TemplateIndexByArrayIndex[tId]
        old := PromptTemplates[idx]
        old.Title := tTitle
        old.Category := tCategory
        old.Content := tContent
        PromptTemplates[idx] := old
    } else {
        if (tId = "")
            tId := "template_" . A_TickCount
        newTpl := { ID: tId, Title: tTitle, Content: tContent, Icon: "", Category: tCategory }
        PromptTemplates.Push(newTpl)
    }
    InvalidateTemplateCache()
    SavePromptTemplates()
}

WebViewPromptTemplateDelete(payload) {
    global PromptTemplates, DefaultTemplateIDs, TemplateIndexByArrayIndex
    if !(payload is Map)
        throw Error("模板数据无效")
    tId := Trim(payload.Get("id", ""))
    if (tId = "")
        throw Error("模板ID不能为空")
    for _, did in DefaultTemplateIDs {
        if (did = tId)
            throw Error("默认模板不能删除")
    }
    if !TemplateIndexByArrayIndex.Has(tId)
        throw Error("模板不存在")
    idx := TemplateIndexByArrayIndex[tId]
    PromptTemplates.RemoveAt(idx)
    InvalidateTemplateCache()
    SavePromptTemplates()
}

WebViewPromptTemplateSetDefault(payload) {
    global DefaultTemplateIDs, TemplateIndexByID
    if !(payload is Map)
        throw Error("默认模板参数无效")
    tId := Trim(payload.Get("id", ""))
    tType := Trim(payload.Get("type", ""))
    if (tId = "" || tType = "")
        throw Error("默认模板参数不完整")
    if !TemplateIndexByID.Has(tId)
        throw Error("模板不存在")
    if (tType != "Explain" && tType != "Refactor" && tType != "Optimize")
        throw Error("默认模板类型无效")
    DefaultTemplateIDs[tType] := tId
    SavePromptTemplates()
}


; ===================== 保存配置窗口位置 =====================
SaveConfigGUIPosition(ConfigGUI) {
    global GuiID_ConfigGUI
    try {
        ; 检查窗口是否还存在
        if (!ConfigGUI || !GuiID_ConfigGUI || GuiID_ConfigGUI = 0) {
            ; 窗口已关闭，停止定时器并立即保存所有待保存的位置
            SetTimer(() => SaveConfigGUIPosition(ConfigGUI), 0)
            FlushPendingWindowPositions()
            return
        }
        
        ; 获取窗口位置和大小
        WinGetPos(&WinX, &WinY, &WinW, &WinH, ConfigGUI.Hwnd)
        WindowName := GetText("config_title")
        ; 使用延迟保存，统一管理
        QueueWindowPositionSave(WindowName, WinX, WinY, WinW, WinH)
    } catch as err {
        ; 忽略错误（窗口可能已关闭）
    }
}

; WebView 设置页关闭（由 CloseConfigGUI 在 ConfigWebViewMode 下调用）
ConfigWebView_Close() {
    global GuiID_ConfigGUI, ConfigWV2Ctrl, ConfigWV2
    try {
        WMActivateChain_Unregister(ConfigWebView_WM_ACTIVATE)
        try WebView2_NotifyHidden(ConfigWV2)
        GuiID_ConfigGUI.Hide()
    } catch {
    }
}
