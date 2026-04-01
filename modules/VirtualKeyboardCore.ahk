; VirtualKeyboard 核心（供 CursorHelper #Include 或独立 VirtualKeyboard.ahk #Include）
; 依赖：调用方已 #Include lib\WebView2.ahk 与 lib\Jxon.ahk
; 嵌入 CursorHelper 时：#Include modules\VirtualKeyboardExecCmd.ahk 须在本文件之前

global g_VK_Embedded := false
global g_JsonPath := ""
global g_Commands := Map()
global g_Bindings := Map()
global g_InverseBindings := Map()
global g_HotkeyBound := Map()
global g_VK_Gui := 0
global g_VK_WV2 := 0
global g_VK_Ctrl := 0
global g_VK_Ready := false
global g_ModState := Map("ctrl", false, "alt", false, "shift", false)
global g_RecordCtx := Map("active", false, "commandId", "")
global g_RecordHook := 0
global g_PendingConflict := Map()
global g_UseScanCode := false
global g_VK_PreviewHook := 0
global g_VK_TitleH := 44

VK_EnsureInit(embedded := true) {
    global g_VK_Gui
    if g_VK_Gui
        return
    VK_Init(embedded)
}

VK_OnHostExit(*) {
    _StopKeyPreviewHook()
    _EndRecord(false)
}

VK_Init(embedded := false) {
    global g_VK_Gui, g_VK_Embedded, g_JsonPath

    if g_VK_Gui
        return

    g_VK_Embedded := embedded
    g_JsonPath := A_ScriptDir "\Commands.json"

    _LoadCommands()
    _VK_RefreshPromptTemplateCommands()
    if !embedded
        _ApplyAllBindings()

    ScreenW := SysGet(0)
    ScreenH := SysGet(1)
    WinW := Max(1100, Min(Round(ScreenW * 0.94), 2100))
    WinH := Max(720, Min(Round(ScreenH * 0.90), 1260))
    TitleH := g_VK_TitleH
    BtnW := 32
    BtnPad := 8
    TitleBtnY := Max(8, (TitleH - 22) // 2)

    guiOpts := "+AlwaysOnTop -Caption +Resize -DPIScale"
    g_VK_Gui := Gui(guiOpts, "VK KeyBinder")
    g_VK_Gui.BackColor := "0a0a0a"
    g_VK_Gui.MarginX := 0
    g_VK_Gui.MarginY := 0

    TitleBg := g_VK_Gui.Add("Text",
        "x0 y0 w" . (WinW - BtnW * 2 - BtnPad * 3) . " h" . TitleH . " Background1a1a1a", "")
    TitleBg.OnEvent("Click", _TitleDrag)

    TitleLbl := g_VK_Gui.Add("Text",
        "x16 y" . TitleBtnY . " w400 h22 ce67e22 Background1a1a1a", "[ VK KEYBINDER ]")
    TitleLbl.SetFont("s11 Bold", "Consolas")
    TitleLbl.OnEvent("Click", _TitleDrag)

    MinX := WinW - BtnW * 2 - BtnPad * 2
    MinBtn := g_VK_Gui.Add("Text",
        "x" . MinX . " y" . TitleBtnY . " w" . BtnW . " h22 Center cf5f5f5 Background1a1a1a", "─")
    MinBtn.SetFont("s11", "Segoe UI")
    MinBtn.OnEvent("Click", (*) => WinMinimize(g_VK_Gui.Hwnd))

    CloseX := WinW - BtnW - BtnPad
    CloseBtn := g_VK_Gui.Add("Text",
        "x" . CloseX . " y" . TitleBtnY . " w" . BtnW . " h22 Center cf5f5f5 Background1a1a1a", "✕")
    CloseBtn.SetFont("s11", "Segoe UI")
    CloseBtn.OnEvent("Click", (*) => VK_Hide())

    showOpt := "w" . WinW . " h" . WinH . (embedded ? " Hide" : " NoActivate")
    g_VK_Gui.Show(showOpt)
    g_VK_Gui.OnEvent("Close", (*) => VK_Hide())
    g_VK_Gui.OnEvent("Size", _OnGuiResize)

    WebView2.create(g_VK_Gui.Hwnd, _OnWV2Created)

    if !embedded {
        A_TrayMenu.Delete()
        A_TrayMenu.Add("显示键盘", (*) => VK_Show())
        A_TrayMenu.Add("隐藏键盘", (*) => VK_Hide())
        A_TrayMenu.Add()
        A_TrayMenu.Add("退出", (*) => ExitApp())
        A_TrayMenu.Default := "显示键盘"
    }
}

_LoadCommands() {
    global g_Commands, g_Bindings, g_InverseBindings, g_JsonPath

    g_Bindings := Map()
    g_InverseBindings := Map()

    if !FileExist(g_JsonPath) {
        OutputDebug("[VK] Commands.json not found: " . g_JsonPath)
        return
    }

    try {
        raw := FileRead(g_JsonPath, "UTF-8")
        g_Commands := Jxon_Load(raw)
    } catch as e {
        OutputDebug("[VK] JSON parse error: " . e.Message)
        return
    }

    if !(g_Commands is Map) || !g_Commands.Has("Bindings")
        return

    _VK_MergeSuggestedBindings()

    bindings := g_Commands["Bindings"]
    if bindings is Map {
        for ahkKey, cmdId in bindings {
            g_Bindings[ahkKey] := cmdId
            g_InverseBindings[cmdId] := ahkKey
        }
    }
    OutputDebug("[VK] Loaded " . g_Bindings.Count . " binding(s)")
}

; 将 SuggestedBindings 合并进 Bindings（不覆盖用户已有绑定）
; 目的：首次使用时不再只显示 Escape 一项，内置 ch_* 能直接体现为已绑定
_VK_MergeSuggestedBindings() {
    global g_Commands
    if !g_Commands.Has("Bindings") || !(g_Commands["Bindings"] is Map)
        g_Commands["Bindings"] := Map()
    if !g_Commands.Has("SuggestedBindings") || !(g_Commands["SuggestedBindings"] is Map)
        return
    if !g_Commands.Has("CommandList") || !(g_Commands["CommandList"] is Map)
        return

    bindings := g_Commands["Bindings"]
    suggest := g_Commands["SuggestedBindings"]
    cmdList := g_Commands["CommandList"]

    usedKeys := Map()
    boundCmd := Map()
    for ahkKey, cmdId in bindings {
        usedKeys[ahkKey] := true
        boundCmd[cmdId] := true
    }

    changed := false
    for cmdId, key in suggest {
        if !cmdList.Has(cmdId)
            continue
        if (cmdId = "sys_exit")
            continue
        if boundCmd.Has(cmdId)
            continue
        if usedKeys.Has(key)
            continue
        bindings[key] := cmdId
        usedKeys[key] := true
        boundCmd[cmdId] := true
        changed := true
    }
    if changed
        OutputDebug("[VK] merged SuggestedBindings into Bindings")
}

_VK_StripDynamicPromptCommands() {
    global g_Commands
    if !g_Commands.Has("Categories")
        return
    cats := g_Commands["Categories"]
    if !(cats is Array)
        return
    newCats := []
    for cat in cats {
        if cat is Map && cat.Has("id") {
            cid := cat["id"]
            if (cid = "prompt_templates" || SubStr(cid, 1, 11) = "prompt_tpl_")
                continue
        }
        newCats.Push(cat)
    }
    g_Commands["Categories"] := newCats

    if g_Commands.Has("CommandList") && g_Commands["CommandList"] is Map {
        toDel := []
        for k, v in g_Commands["CommandList"] {
            if (SubStr(k, 1, 3) = "pt_")
                toDel.Push(k)
        }
        for k in toDel
            g_Commands["CommandList"].Delete(k)
    }
}

_VK_MergePromptTemplateCommands() {
    global g_Commands, PromptTemplates

    if !g_Commands.Has("CommandList")
        g_Commands["CommandList"] := Map()
    if !g_Commands.Has("Categories")
        g_Commands["Categories"] := []

    if !IsSet(PromptTemplates) || !IsObject(PromptTemplates) || PromptTemplates.Length = 0
        return

    cmdIds := []
    seenTpl := Map()
    for Template in PromptTemplates {
        if !IsObject(Template)
            continue
        tplId := ""
        tplTitle := ""
        tplCat := ""
        tplSeries := ""
        if (Template is Map) {
            tplId := Template.Get("ID", "")
            tplTitle := Template.Get("Title", "")
            tplCat := Template.Get("Category", "")
            tplSeries := Template.Get("Series", "")
        } else {
            if (Template.HasProp("ID"))
                tplId := Template.ID
            if (Template.HasProp("Title"))
                tplTitle := Template.Title
            if (Template.HasProp("Category"))
                tplCat := Template.Category
            if (Template.HasProp("Series"))
                tplSeries := Template.Series
        }
        if (tplId = "")
            continue
        if seenTpl.Has(tplId)
            continue
        seenTpl[tplId] := true
        cmdId := "pt_" . tplId
        name := (tplTitle != "") ? tplTitle : tplId
        desc := "发送到 Cursor 聊天（可在虚拟键盘中绑定快捷键）"
        ptCategory := "基础"
        tcat := Trim(tplCat)
        tseries := Trim(tplSeries)
        switch tcat {
            case "专业":
                ptCategory := "专业"
            case "改错":
                ptCategory := "改错"
            case "优化":
                ptCategory := "优化"
            case "解释":
                ptCategory := "解释"
            case "重构":
                ptCategory := "重构"
            default:
                switch tseries {
                    case "Professional":
                        ptCategory := "专业"
                    case "BugFix":
                        ptCategory := "改错"
                    case "Basic":
                        ptCategory := "基础"
                    default:
                        ptCategory := "基础"
                }
        }
        g_Commands["CommandList"][cmdId] := Map("name", name, "desc", desc, "fn", "PT_RUN", "ptCategory", ptCategory)
        cmdIds.Push(cmdId)
    }
    g_Commands["Categories"].Push(Map("id", "prompt_templates", "name", "提示词", "commands", cmdIds))
}

_VK_RefreshPromptTemplateCommands() {
    global g_Commands
    if !(g_Commands is Map) || !g_Commands.Has("CommandList")
        return
    _VK_StripDynamicPromptCommands()
    _VK_MergePromptTemplateCommands()
}

VK_OnPromptTemplatesSaved(*) {
    global g_VK_Gui, g_VK_Ready, g_VK_Embedded
    if !g_VK_Gui
        return
    _VK_RefreshPromptTemplateCommands()
    if g_VK_Ready
        _PushInit()
    if !g_VK_Embedded
        _ApplyAllBindings()
}

_SaveBindings() {
    global g_Commands, g_Bindings, g_JsonPath, g_VK_Embedded

    newBindings := Map()
    for ahkKey, cmdId in g_Bindings
        newBindings[ahkKey] := cmdId
    g_Commands["Bindings"] := newBindings

    json := _SerializeCommands()
    try FileDelete(g_JsonPath)
    try FileAppend(json, g_JsonPath, "UTF-8")
    OutputDebug("[VK] Commands.json saved")
    if !g_VK_Embedded
        NotifyScript("CursorHelper", '{"type":"bindingsReloaded"}')
}

_SerializeCommands() {
    global g_Commands

    catArr := g_Commands["Categories"]
    catJson := "["
    sep1 := ""
    loop catArr.Length {
        cat := catArr[A_Index]
        if cat is Map && cat.Has("id") && cat["id"] = "prompt_templates"
            continue
        catId := _JsonStr(cat["id"])
        catNm := _JsonStr(cat["name"])
        cmds := cat["commands"]
        cmdArr := "["
        sep2 := ""
        loop cmds.Length {
            cmdArr .= sep2 . _JsonStr(cmds[A_Index])
            sep2 := ","
        }
        cmdArr .= "]"
        catJson .= sep1 . '{"id":' . catId . ',"name":' . catNm . ',"commands":' . cmdArr . '}'
        sep1 := ","
    }
    catJson .= "]"

    cmdList := g_Commands["CommandList"]
    clJson := "{"
    sep3 := ""
    for cmdId, v in cmdList {
        if (SubStr(cmdId, 1, 3) = "pt_")
            continue
        nm := _JsonStr(v["name"])
        desc := _JsonStr(v["desc"])
        fn := _JsonStr(v["fn"])
        clJson .= sep3 . _JsonStr(cmdId) . ':{"name":' . nm . ',"desc":' . desc . ',"fn":' . fn . '}'
        sep3 := ","
    }
    clJson .= "}"

    bJson := "{"
    sep4 := ""
    for ahkKey, cmdId in g_Commands["Bindings"] {
        bJson .= sep4 . _JsonStr(ahkKey) . ":" . _JsonStr(cmdId)
        sep4 := ","
    }
    bJson .= "}"

    sbJson := "{"
    sepS := ""
    if g_Commands.Has("SuggestedBindings") {
        sbMap := g_Commands["SuggestedBindings"]
        if sbMap is Map {
            for cmdId, key in sbMap {
                sbJson .= sepS . _JsonStr(cmdId) . ":" . _JsonStr(key)
                sepS := ","
            }
        }
    }
    sbJson .= "}"

    return '{"Categories":' . catJson . ',"CommandList":' . clJson . ',"Bindings":' . bJson
        . ',"SuggestedBindings":' . sbJson . '}'
}

_JsonStr(s) {
    s := StrReplace(s, "\", "\\")
    s := StrReplace(s, '"', '\"')
    s := StrReplace(s, "`n", "\n")
    s := StrReplace(s, "`r", "\r")
    s := StrReplace(s, "`t", "\t")
    return '"' . s . '"'
}

_BindKey(ahkKey, cmdId) {
    global g_HotkeyBound
    if g_HotkeyBound.Has(ahkKey)
        try Hotkey(ahkKey, "Off")
    fn := _MakeCmdFn(cmdId)
    try {
        Hotkey(ahkKey, fn, "On")
        g_HotkeyBound[ahkKey] := 1
        OutputDebug("[VK] Bound: " . ahkKey . " -> " . cmdId)
    } catch as e {
        OutputDebug("[VK] Hotkey error (" . ahkKey . "): " . e.Message)
    }
}

_MakeCmdFn(cmdId) {
    return (*) => _ExecuteCommand(cmdId)
}

_UnbindKey(ahkKey) {
    global g_HotkeyBound
    if g_HotkeyBound.Has(ahkKey) {
        try Hotkey(ahkKey, "Off")
        g_HotkeyBound.Delete(ahkKey)
        OutputDebug("[VK] Unbound: " . ahkKey)
    }
}

_ApplyAllBindings() {
    global g_Bindings
    for ahkKey, cmdId in g_Bindings
        _BindKey(ahkKey, cmdId)
}

_VkRunPromptTemplate(cmdId) {
    if (SubStr(cmdId, 1, 3) != "pt_")
        return
    tid := SubStr(cmdId, 4)
    run := Func("ExecutePromptByTemplateId")
    if run
        run.Call(tid)
    else
        OutputDebug("[VK] PT_RUN: ExecutePromptByTemplateId 不可用（需 CursorHelper）")
}

_ExecuteCommand(cmdId) {
    global g_Commands, g_VK_Embedded
    if !g_Commands.Has("CommandList") || !g_Commands["CommandList"].Has(cmdId) {
        OutputDebug("[VK] Unknown command: " . cmdId)
        return
    }
    fn := g_Commands["CommandList"][cmdId]["fn"]
    switch fn {
        case "EXIT_APP":
            if g_VK_Embedded
                VK_Hide()
            else
                ExitApp()
        case "SHOW_VK":
            VK_Show()
        case "HIDE_VK":
            VK_Hide()
        case "RESET_VK":
            VK_SendToWeb('{"type":"reset"}')
        case "WIN_MIN":
            try WinMinimize("A")
        case "WIN_CLOSE":
            try WinClose("A")
        case "CURSOR_OPEN":
            OutputDebug("[VK] CURSOR_OPEN: hook here")
        case "CURSOR_CLOSE":
            OutputDebug("[VK] CURSOR_CLOSE: hook here")
        case "CH_RUN":
            if g_VK_Embedded {
                ; 定义在 VirtualKeyboardExecCmd.ahk；用 Func 避免静态分析把标识符当成未赋值局部变量
                chRun := Func("VK_ExecCursorHelperCmd")
                if chRun
                    chRun.Call(cmdId)
                else
                    OutputDebug("[VK] CH_RUN embedded but VK_ExecCursorHelperCmd not included")
            } else if !NotifyScript("CursorHelper", '{"type":"vkExec","cmdId":"' . cmdId . '"}')
                OutputDebug("[VK] CH_RUN " . cmdId . " — CursorHelper 未运行或未处理 vkExec")
        case "PT_RUN":
            _VkRunPromptTemplate(cmdId)
        default:
            OutputDebug("[VK] Unhandled fn: " . fn)
    }
}

_OnWV2Created(ctrl) {
    global g_VK_WV2, g_VK_Ctrl

    g_VK_Ctrl := ctrl
    g_VK_WV2 := ctrl.CoreWebView2

    try g_VK_Ctrl.DefaultBackgroundColor := 0xFF0A0A0A

    _ApplyWV2Bounds()

    s := g_VK_WV2.Settings
    s.AreDefaultContextMenusEnabled := false
    s.IsStatusBarEnabled := false
    s.AreDevToolsEnabled := true

    g_VK_WV2.add_WebMessageReceived(_OnWebMessage)

    htmlPath := A_ScriptDir "\VirtualKeyboard.html"
    if FileExist(htmlPath)
        g_VK_WV2.Navigate("file:///" . StrReplace(htmlPath, "\", "/"))
    else
        g_VK_WV2.NavigateToString(_FallbackHtml())
}

_ApplyWV2Bounds() {
    global g_VK_Gui, g_VK_Ctrl, g_VK_TitleH
    if !g_VK_Ctrl
        return
    WinGetClientPos(, , &cw, &ch, g_VK_Gui.Hwnd)
    rc := WebView2.RECT()
    rc.left := 0
    rc.top := g_VK_TitleH
    rc.right := cw
    rc.bottom := ch
    g_VK_Ctrl.Bounds := rc
}

_OnGuiResize(GuiObj, MinMax, Width, Height) {
    if MinMax = -1
        return
    _ApplyWV2Bounds()
}

_TitleDrag(*) {
    global g_VK_Gui
    PostMessage(0x00A1, 2, 0, , g_VK_Gui.Hwnd)
}

_OnWebMessage(sender, args) {
    global g_VK_Ready

    jsonStr := args.WebMessageAsJson
    try {
        msg := Jxon_Load(jsonStr)
    } catch {
        OutputDebug("[VK] JSON parse error: " . jsonStr)
        return
    }
    if !(msg is Map) || !msg.Has("type")
        return

    switch msg["type"] {
        case "ready":
            g_VK_Ready := true
            OutputDebug("[VK] WebView ready")
            _PushInit()
            _PushModifierState()
            _StartKeyPreviewHook()

        case "bindKey":
            if !msg.Has("commandId") || !msg.Has("ahkKey")
                return
            cmdId := msg["commandId"]
            ahkKey := msg["ahkKey"]
            displayKey := msg.Has("displayKey") ? msg["displayKey"] : ahkKey
            _DoBindKey(cmdId, ahkKey, displayKey)

        case "startRecord":
            if msg.Has("commandId")
                _BeginRecord(msg["commandId"])

        case "cancelRecord":
            _EndRecord()

        case "clearBinding":
            if msg.Has("commandId")
                _DoClearBinding(msg["commandId"])

        case "executeCommand":
            if msg.Has("commandId")
                _ExecuteCommand(msg["commandId"])

        case "resolveConflict":
            if g_PendingConflict.Has("cmdId") {
                if msg.Has("confirm") && msg["confirm"]
                    _DoBindKey(g_PendingConflict["cmdId"],
                        g_PendingConflict["ahkKey"],
                        g_PendingConflict["displayKey"])
                g_PendingConflict := Map()
            }
            VK_SendToWeb('{"type":"recordHint","active":false}')

        case "setLayoutMode":
            g_UseScanCode := msg.Has("native") && msg["native"]
            VK_SendToWeb('{"type":"layoutMode","native":' . (g_UseScanCode ? "true" : "false") . '}')
            OutputDebug("[VK] ScanCode mode: " . (g_UseScanCode ? "on" : "off"))

        default:
            OutputDebug("[VK] Unknown msg: " . msg["type"])
    }
}

_DoBindKey(cmdId, ahkKey, displayKey) {
    global g_Bindings, g_InverseBindings, g_VK_Embedded

    if g_InverseBindings.Has(cmdId) {
        oldKey := g_InverseBindings[cmdId]
        if oldKey != ahkKey {
            if !g_VK_Embedded
                _UnbindKey(oldKey)
            g_Bindings.Delete(oldKey)
        }
    }
    if g_Bindings.Has(ahkKey) {
        oldCmd := g_Bindings[ahkKey]
        if oldCmd != cmdId
            g_InverseBindings.Delete(oldCmd)
    }

    g_Bindings[ahkKey] := cmdId
    g_InverseBindings[cmdId] := ahkKey
    if !g_VK_Embedded
        _BindKey(ahkKey, cmdId)
    _SaveBindings()

    escaped := StrReplace(StrReplace(displayKey, "\", "\\"), '"', '\"')
    VK_SendToWeb('{"type":"bindingUpdated","commandId":"' . cmdId
        . '","ahkKey":"' . ahkKey
        . '","displayKey":"' . escaped . '"}')
    OutputDebug("[VK] bindKey: " . cmdId . " = " . ahkKey)
}

_DoClearBinding(cmdId) {
    global g_Bindings, g_InverseBindings, g_VK_Embedded

    if !g_InverseBindings.Has(cmdId)
        return
    ahkKey := g_InverseBindings[cmdId]
    if !g_VK_Embedded
        _UnbindKey(ahkKey)
    g_Bindings.Delete(ahkKey)
    g_InverseBindings.Delete(cmdId)
    _SaveBindings()

    VK_SendToWeb('{"type":"bindingUpdated","commandId":"' . cmdId
        . '","ahkKey":"","displayKey":""}')
    OutputDebug("[VK] clearBinding: " . cmdId)
}

_VkJsonStr(s) {
    s := StrReplace(s, "\", "\\")
    s := StrReplace(s, '"', '\"')
    return s
}

_VkScToDataAhkBase(vk, sc) {
    global g_UseScanCode
    if g_UseScanCode {
        kn := _GetKeyFromSC(sc)
        if kn = ""
            kn := GetKeyName(Format("vk{:x}sc{:x}", vk, sc))
    } else {
        kn := GetKeyName(Format("vk{:x}sc{:x}", vk, sc))
    }
    if kn = "" || _IsModifierOnlyKey(kn)
        return ""
    base := _KeyNameToAhkBase(kn)
    if base = ""
        return ""
    if (base = "``")
        base := "````"
    return base
}

_OnVkPreviewKeyDown(ih, vk, sc) {
    global g_VK_Ready
    if !g_VK_Ready
        return
    base := _VkScToDataAhkBase(vk, sc)
    if base = ""
        return
    VK_SendToWeb('{"type":"keyPreview","phase":"down","base":"' . _VkJsonStr(base) . '"}')
}

_OnVkPreviewKeyUp(ih, vk, sc) {
    global g_VK_Ready
    if !g_VK_Ready
        return
    base := _VkScToDataAhkBase(vk, sc)
    if base = ""
        return
    VK_SendToWeb('{"type":"keyPreview","phase":"up","base":"' . _VkJsonStr(base) . '"}')
}

_StartKeyPreviewHook() {
    global g_VK_PreviewHook
    if IsObject(g_VK_PreviewHook)
        return
    ih := InputHook("V L0")
    ih.KeyOpt("{All}", "N")
    ih.OnKeyDown := _OnVkPreviewKeyDown
    ih.OnKeyUp := _OnVkPreviewKeyUp
    g_VK_PreviewHook := ih
    ih.Start()
    OutputDebug("[VK] key preview hook on")
}

_StopKeyPreviewHook() {
    global g_VK_PreviewHook
    if IsObject(g_VK_PreviewHook) {
        try g_VK_PreviewHook.Stop()
        g_VK_PreviewHook := 0
        OutputDebug("[VK] key preview hook off")
    }
}

_UpdateModifierState() {
    global g_ModState
    g_ModState["ctrl"] := GetKeyState("Ctrl", "P")
    g_ModState["alt"] := GetKeyState("Alt", "P")
    g_ModState["shift"] := GetKeyState("Shift", "P")
    _PushModifierState()
}

_PushModifierState() {
    global g_ModState
    VK_SendToWeb(
        '{"type":"modifierState","ctrl":' . (g_ModState["ctrl"] ? "true" : "false")
            . ',"alt":' . (g_ModState["alt"] ? "true" : "false")
            . ',"shift":' . (g_ModState["shift"] ? "true" : "false")
            . '}'
    )
}

_BeginRecord(commandId) {
    global g_RecordHook, g_RecordCtx

    try _EndRecord(false)

    g_RecordCtx["active"] := true
    g_RecordCtx["commandId"] := commandId

    _StopKeyPreviewHook()

    ih := InputHook("V L0")
    ih.KeyOpt("{All}", "NV")
    ih.NotifyNonText := true
    ih.OnKeyDown := _OnRecordKeyDown
    g_RecordHook := ih
    try ih.Start()
    catch as e
        TrayTip("录制钩子启动失败: " . e.Message, "VirtualKeyboard", "Iconx 2")

    VK_SendToWeb('{"type":"recordHint","active":true,"commandId":"' . commandId . '"}')
    OutputDebug("[VK] record start: " . commandId)
}

_EndRecord(restartPreview := true) {
    global g_RecordHook, g_RecordCtx, g_VK_Ready
    if IsObject(g_RecordHook) {
        try g_RecordHook.Stop()
    }
    g_RecordHook := 0
    g_RecordCtx["active"] := false
    g_RecordCtx["commandId"] := ""
    if restartPreview && g_VK_Ready
        _StartKeyPreviewHook()
}

_OnRecordKeyDown(ih, vk, sc) {
    global g_RecordCtx, g_Bindings, g_Commands, g_PendingConflict, g_UseScanCode
    if !g_RecordCtx["active"]
        return

    if g_UseScanCode {
        keyName := _GetKeyFromSC(sc)
        if !keyName
            keyName := GetKeyName(Format("vk{:x}sc{:x}", vk, sc))
    } else {
        keyName := GetKeyName(Format("vk{:x}sc{:x}", vk, sc))
    }

    if !keyName || _IsModifierOnlyKey(keyName)
        return

    isCtrl := GetKeyState("Ctrl", "P")
    isAlt := GetKeyState("Alt", "P")
    isShift := GetKeyState("Shift", "P")
    ahkKey := _NormalizeToAhkHotkey(keyName, isCtrl, isAlt, isShift)
    if !ahkKey
        return

    cmdId := g_RecordCtx["commandId"]
    displayKey := _ToDisplayKey(ahkKey)

    if g_Bindings.Has(ahkKey) {
        conflictId := g_Bindings[ahkKey]
        if conflictId != cmdId {
            g_PendingConflict["cmdId"] := cmdId
            g_PendingConflict["ahkKey"] := ahkKey
            g_PendingConflict["displayKey"] := displayKey
            g_PendingConflict["conflictId"] := conflictId
            _EndRecord()
            conflictName := (g_Commands.Has("CommandList") && g_Commands["CommandList"].Has(conflictId))
                ? g_Commands["CommandList"][conflictId]["name"] : conflictId
            escDk := StrReplace(StrReplace(displayKey, "\", "\\"), '"', '\"')
            escName := StrReplace(StrReplace(conflictName, "\", "\\"), '"', '\"')
            VK_SendToWeb('{"type":"confirmConflict","commandId":"' . cmdId
                . '","ahkKey":"' . ahkKey
                . '","displayKey":"' . escDk
                . '","conflictCmdId":"' . conflictId
                . '","conflictCmdName":"' . escName . '"}')
            OutputDebug("[VK] conflict: " . ahkKey . " -> " . conflictId . " vs " . cmdId)
            return
        }
    }

    _EndRecord()
    _DoBindKey(cmdId, ahkKey, displayKey)
    VK_SendToWeb('{"type":"recordHint","active":false,"commandId":"' . cmdId . '"}')
    OutputDebug("[VK] record captured: " . cmdId . " => " . ahkKey)
}

_IsModifierOnlyKey(keyName) {
    return keyName = "Ctrl"
        || keyName = "Alt"
        || keyName = "Shift"
        || keyName = "LControl"
        || keyName = "RControl"
        || keyName = "LAlt"
        || keyName = "RAlt"
        || keyName = "LShift"
        || keyName = "RShift"
}

_NormalizeToAhkHotkey(keyName, isCtrl, isAlt, isShift) {
    mods := (isCtrl ? "^" : "") . (isAlt ? "!" : "") . (isShift ? "+" : "")
    base := _KeyNameToAhkBase(keyName)
    if !base
        return ""
    return mods . base
}

_KeyNameToAhkBase(keyName) {
    if StrLen(keyName) = 1 {
        if RegExMatch(keyName, "^[A-Z]$")
            return Format("{:L}", keyName)
        return keyName
    }
    static keyNameMap := Map(
        "Escape", "Escape", "Esc", "Escape",
        "Enter", "Enter", "Tab", "Tab", "Space", "Space",
        "Backspace", "Backspace", "CapsLock", "CapsLock",
        "Delete", "Delete", "Del", "Delete", "Insert", "Insert", "Ins", "Insert",
        "Home", "Home", "End", "End", "PgUp", "PgUp", "PgDn", "PgDn",
        "Up", "Up", "Down", "Down", "Left", "Left", "Right", "Right",
        "PrintScreen", "PrintScreen", "ScrollLock", "ScrollLock", "Pause", "Pause",
        "AppsKey", "AppsKey", "LWin", "LWin", "RWin", "RWin",
        "NumpadDiv", "NumpadDiv", "NumpadMult", "NumpadMult", "NumpadSub", "NumpadSub", "NumpadAdd", "NumpadAdd", "NumpadEnter", "NumpadEnter",
        "NumpadDot", "NumpadDot", "NumpadIns", "Numpad0", "NumpadEnd", "Numpad1", "NumpadDown", "Numpad2", "NumpadPgDn", "Numpad3",
        "NumpadLeft", "Numpad4", "NumpadClear", "Numpad5", "NumpadRight", "Numpad6", "NumpadHome", "Numpad7", "NumpadUp", "Numpad8", "NumpadPgUp", "Numpad9"
    )
    if RegExMatch(keyName, "^F([1-9]|1[0-2])$")
        return keyName
    if keyNameMap.Has(keyName)
        return keyNameMap[keyName]
    return ""
}

_ToDisplayKey(ahkKey) {
    return _AhkKeyToDisplay(ahkKey)
}

_GetKeyFromSC(sc) {
    static scMap := Map(
        0x01, "Escape",
        0x3B, "F1", 0x3C, "F2", 0x3D, "F3", 0x3E, "F4",
        0x3F, "F5", 0x40, "F6", 0x41, "F7", 0x42, "F8",
        0x43, "F9", 0x44, "F10", 0x57, "F11", 0x58, "F12",
        0x29, "``", 0x02, "1", 0x03, "2", 0x04, "3", 0x05, "4",
        0x06, "5", 0x07, "6", 0x08, "7", 0x09, "8", 0x0A, "9",
        0x0B, "0", 0x0C, "-", 0x0D, "=", 0x0E, "Backspace",
        0x0F, "Tab",
        0x10, "q", 0x11, "w", 0x12, "e", 0x13, "r", 0x14, "t",
        0x15, "y", 0x16, "u", 0x17, "i", 0x18, "o", 0x19, "p",
        0x1A, "[", 0x1B, "]", 0x2B, "\",
        0x3A, "CapsLock",
        0x1E, "a", 0x1F, "s", 0x20, "d", 0x21, "f", 0x22, "g",
        0x23, "h", 0x24, "j", 0x25, "k", 0x26, "l",
        0x27, ";", 0x28, "'", 0x1C, "Enter",
        0x2A, "LShift",
        0x2C, "z", 0x2D, "x", 0x2E, "c", 0x2F, "v", 0x30, "b",
        0x31, "n", 0x32, "m", 0x33, ",", 0x34, ".", 0x35, "/",
        0x36, "RShift",
        0x1D, "LCtrl", 0x38, "LAlt", 0x39, "Space",
        0x37, "PrintScreen", 0x46, "ScrollLock", 0x45, "Pause"
    )
    return scMap.Has(sc) ? scMap[sc] : ""
}

_PushInit() {
    global g_Commands, g_InverseBindings

    if !g_Commands.Has("Categories") {
        OutputDebug("[VK] Commands not loaded")
        return
    }

    catArr := g_Commands["Categories"]
    catJson := "["
    sep := ""
    loop catArr.Length {
        cat := catArr[A_Index]
        cmds := cat["commands"]
        cArr := "["
        cs := ""
        loop cmds.Length {
            cArr .= cs . _JsonStr(cmds[A_Index])
            cs := ","
        }
        cArr .= "]"
        catJson .= sep . '{"id":' . _JsonStr(cat["id"]) . ',"name":' . _JsonStr(cat["name"]) . ',"commands":' . cArr . '}'
        sep := ","
    }
    catJson .= "]"

    cmdList := g_Commands["CommandList"]
    clJson := "{"
    sep2 := ""
    for cmdId, v in cmdList {
        nm := _JsonStr(v["name"])
        desc := _JsonStr(v["desc"])
        fn := v.Has("fn") ? _JsonStr(v["fn"]) : '""'
        ptCategory := v.Has("ptCategory") ? _JsonStr(v["ptCategory"]) : '""'
        clJson .= sep2 . _JsonStr(cmdId) . ':{"name":' . nm . ',"desc":' . desc . ',"fn":' . fn . ',"ptCategory":' . ptCategory . '}'
        sep2 := ","
    }
    clJson .= "}"

    sbJson := "{"
    sepSb := ""
    if g_Commands.Has("SuggestedBindings") {
        sbMap := g_Commands["SuggestedBindings"]
        if sbMap is Map {
            for sid, skey in sbMap {
                sbJson .= sepSb . _JsonStr(sid) . ":" . _JsonStr(skey)
                sepSb := ","
            }
        }
    }
    sbJson .= "}"

    bJson := "{"
    sep3 := ""
    for cmdId, ahkKey in g_InverseBindings {
        dk := _AhkKeyToDisplay(ahkKey)
        esc := StrReplace(StrReplace(dk, "\", "\\"), '"', '\"')
        bJson .= sep3 . _JsonStr(cmdId) . ':{"ahkKey":' . _JsonStr(ahkKey) . ',"displayKey":"' . esc . '"}'
        sep3 := ","
    }
    bJson .= "}"

    payload := '{"type":"init","categories":' . catJson
        . ',"commands":' . clJson
        . ',"bindings":' . bJson
        . ',"suggestedBindings":' . sbJson . '}'
    VK_SendToWeb(payload)
    OutputDebug("[VK] init pushed")
}

_AhkKeyToDisplay(ahkKey) {
    display := ""
    key := ahkKey
    if InStr(key, "^") {
        display .= "Ctrl+"
        key := StrReplace(key, "^", "")
    }
    if InStr(key, "!") {
        display .= "Alt+"
        key := StrReplace(key, "!", "")
    }
    if InStr(key, "+") {
        display .= "Shift+"
        key := StrReplace(key, "+", "")
    }
    if StrLen(key) = 1
        key := Format("{:U}", key)
    static specialMap := Map(
        "Escape", "Esc", "Enter", "Enter", "Space", "Space", "Tab", "Tab",
        "Backspace", "Bks", "Delete", "Del", "Insert", "Ins",
        "Home", "Home", "End", "End", "PgUp", "PgUp", "PgDn", "PgDn",
        "Up", "↑", "Down", "↓", "Left", "←", "Right", "→",
        "LShift", "LShift", "RShift", "RShift",
        "LCtrl", "LCtrl", "RCtrl", "RCtrl",
        "LAlt", "LAlt", "RAlt", "RAlt",
        "LWin", "Win", "RWin", "Win", "AppsKey", "Menu",
        "PrintScreen", "PrtSc", "ScrollLock", "ScrLk", "Pause", "Pause"
    )
    if specialMap.Has(key)
        key := specialMap[key]
    return display . key
}

VK_Show() {
    global g_VK_Gui
    if g_VK_Gui {
        g_VK_Gui.Show("NoActivate")
        _StartKeyPreviewHook()
        VK_SendToWeb('{"type":"keyPreviewClear"}')
    }
}

VK_Hide() {
    global g_VK_Gui
    VK_SendToWeb('{"type":"keyPreviewClear"}')
    _StopKeyPreviewHook()
    if g_VK_Gui
        g_VK_Gui.Hide()
}

; CursorHelper 悬浮条：同进程内切换显示（首次调用会懒加载）
VK_ToggleEmbedded() {
    VK_EnsureInit(true)
    global g_VK_Gui
    if !g_VK_Gui
        return
    if WinExist("ahk_id " . g_VK_Gui.Hwnd) && (WinGetStyle("ahk_id " . g_VK_Gui.Hwnd) & 0x10000000)
        VK_Hide()
    else
        VK_Show()
}

VK_SendToWeb(jsonStr) {
    global g_VK_WV2, g_VK_Ready
    if g_VK_WV2 && g_VK_Ready
        g_VK_WV2.PostWebMessageAsJson(jsonStr)
}

NotifyScript(targetTitle, payload) {
    hwnd := WinExist(targetTitle . " ahk_class AutoHotkey")
    if !hwnd
        return false
    strBuf := Buffer(StrPut(payload, "UTF-8"))
    StrPut(payload, strBuf, "UTF-8")
    cds := Buffer(4 + 4 + A_PtrSize, 0)
    NumPut("UInt", 1, cds, 0)
    NumPut("UInt", strBuf.Size, cds, 4)
    NumPut("Ptr", strBuf.Ptr, cds, 8)
    try {
        SendMessage(0x4A, 0, cds.Ptr, , "ahk_id " . hwnd)
        OutputDebug("[VK] NotifyScript -> " . targetTitle)
        return true
    } catch {
        return false
    }
}

_FallbackHtml() {
    return (
        '<!DOCTYPE html><html><head><meta charset="UTF-8"></head>'
            . '<body style="background:#0a0a0a;color:#e67e22;font-family:Consolas,monospace;'
            . 'display:flex;align-items:center;justify-content:center;height:100vh;margin:0;">'
            . '<div style="text-align:center;"><div style="font-size:28px;margin-bottom:16px;'
            . 'text-shadow:0 0 10px #e67e22;">[ VK KEYBINDER ]</div>'
            . '<div style="color:#888;font-size:13px;">VirtualKeyboard.html not found</div>'
            . '</div></body></html>'
    )
}
