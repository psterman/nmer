; ===========================================================================
; VirtualKeyboard.ahk  —  Premiere 风格快捷键绑定工具
; AHK v2 | 依赖: lib\WebView2.ahk, lib\Jxon.ahk
; ===========================================================================
#Requires AutoHotkey v2.0
#SingleInstance Force

#Include lib\WebView2.ahk
#Include lib\Jxon.ahk

; ===========================================================================
; 全局变量
; ===========================================================================
global g_JsonPath        := A_ScriptDir "\Commands.json"
global g_Commands        := Map()   ; 完整 JSON：Categories / CommandList / Bindings
global g_Bindings        := Map()   ; ahkKey -> commandId
global g_InverseBindings := Map()   ; commandId -> ahkKey
global g_HotkeyBound     := Map()   ; ahkKey -> 1（已绑定标记）
global g_VK_Gui          := 0
global g_VK_WV2          := 0
global g_VK_Ctrl         := 0
global g_VK_Ready        := false
global g_ModState        := Map("ctrl", false, "alt", false, "shift", false)
global g_RecordCtx       := Map("active", false, "commandId", "")
global g_RecordHook      := 0
global g_PendingConflict := Map()   ; 待确认的冲突绑定
global g_UseScanCode     := false   ; 是否使用 ScanCode 物理键模式
global g_VK_PreviewHook  := 0       ; 全局按键预览 InputHook（不拦截按键）

; ===========================================================================
; 入口
; ===========================================================================
VK_Init()

VK_Init() {
    global g_VK_Gui

    ; ── 读取数据 & 绑定热键 ──────────────────────────────────────────────
    _LoadCommands()
    _ApplyAllBindings()

    ; ── 无边框主窗口 ─────────────────────────────────────────────────────
    g_VK_Gui := Gui("+AlwaysOnTop -Caption +Resize -DPIScale", "VK KeyBinder")
    g_VK_Gui.BackColor := "0a0a0a"
    g_VK_Gui.MarginX := 0
    g_VK_Gui.MarginY := 0

    ; ── 自制标题栏（30px 高，可拖动） ──────────────────────────────────
    WinW   := 1100
    TitleH := 30
    BtnW   := 24
    BtnPad := 4

    TitleBg := g_VK_Gui.Add("Text",
        "x0 y0 w" . (WinW - BtnW*2 - BtnPad*3) . " h" . TitleH . " Background1a1a1a", "")
    TitleBg.OnEvent("Click", _TitleDrag)

    TitleLbl := g_VK_Gui.Add("Text",
        "x12 y7 w320 h18 ce67e22 Background1a1a1a", "[ VK KEYBINDER ]")
    TitleLbl.SetFont("s9 Bold", "Consolas")
    TitleLbl.OnEvent("Click", _TitleDrag)

    MinX   := WinW - BtnW*2 - BtnPad*2
    MinBtn := g_VK_Gui.Add("Text",
        "x" . MinX . " y7 w" . BtnW . " h18 Center cf5f5f5 Background1a1a1a", "─")
    MinBtn.SetFont("s10", "Segoe UI")
    MinBtn.OnEvent("Click", (*) => WinMinimize(g_VK_Gui.Hwnd))

    CloseX   := WinW - BtnW - BtnPad
    CloseBtn := g_VK_Gui.Add("Text",
        "x" . CloseX . " y7 w" . BtnW . " h18 Center cf5f5f5 Background1a1a1a", "✕")
    CloseBtn.SetFont("s10", "Segoe UI")
    CloseBtn.OnEvent("Click", (*) => VK_Hide())

    ; ── 显示窗口 ─────────────────────────────────────────────────────────
    g_VK_Gui.Show("w" . WinW . " h700 NoActivate")
    g_VK_Gui.OnEvent("Close", (*) => VK_Hide())
    g_VK_Gui.OnEvent("Size",  _OnGuiResize)

    ; ── 初始化 WebView2 ─────────────────────────────────────────────────
    WebView2.create(g_VK_Gui.Hwnd, _OnWV2Created)

    ; ── 系统托盘 ─────────────────────────────────────────────────────────
    A_TrayMenu.Delete()
    A_TrayMenu.Add("显示键盘",  (*) => VK_Show())
    A_TrayMenu.Add("隐藏键盘",  (*) => VK_Hide())
    A_TrayMenu.Add()
    A_TrayMenu.Add("退出",      (*) => ExitApp())
    A_TrayMenu.Default := "显示键盘"
}

; ===========================================================================
; 数据层：读取 / 保存 Commands.json
; ===========================================================================

; ---------------------------------------------------------------------------
; 从 Commands.json 读取并填充 g_Commands / g_Bindings / g_InverseBindings
; ---------------------------------------------------------------------------
_LoadCommands() {
    global g_Commands, g_Bindings, g_InverseBindings, g_JsonPath

    g_Bindings        := Map()
    g_InverseBindings := Map()

    if !FileExist(g_JsonPath) {
        OutputDebug("[VK] Commands.json not found: " . g_JsonPath)
        return
    }

    try {
        raw      := FileRead(g_JsonPath, "UTF-8")
        g_Commands := Jxon_Load(raw)
    } catch as e {
        OutputDebug("[VK] JSON parse error: " . e.Message)
        return
    }

    if !(g_Commands is Map) || !g_Commands.Has("Bindings")
        return

    bindings := g_Commands["Bindings"]
    if bindings is Map {
        for ahkKey, cmdId in bindings {
            g_Bindings[ahkKey]        := cmdId
            g_InverseBindings[cmdId]  := ahkKey
        }
    }
    OutputDebug("[VK] Loaded " . g_Bindings.Count . " binding(s)")
}

; ---------------------------------------------------------------------------
; 将 g_Bindings 写回 Commands.json（覆盖 Bindings 字段）
; ---------------------------------------------------------------------------
_SaveBindings() {
    global g_Commands, g_Bindings, g_JsonPath

    ; 更新内存结构中的 Bindings 字段
    newBindings := Map()
    for ahkKey, cmdId in g_Bindings
        newBindings[ahkKey] := cmdId
    g_Commands["Bindings"] := newBindings

    ; 手工序列化（Jxon_Dump 不支持深度嵌套 Map，这里自行构造）
    json := _SerializeCommands()
    try FileDelete(g_JsonPath)
    try FileAppend(json, g_JsonPath, "UTF-8")
    OutputDebug("[VK] Commands.json saved")
    ; 通知其他脚本（如 CursorHelper）重载配置
    NotifyScript("CursorHelper", '{"type":"bindingsReloaded"}')
}

; ---------------------------------------------------------------------------
; 将 g_Commands 序列化回 JSON 字符串
; ---------------------------------------------------------------------------
_SerializeCommands() {
    global g_Commands

    ; ── Categories ───────────────────────────────────────────────────────
    catArr  := g_Commands["Categories"]
    catJson := "["
    sep1    := ""
    loop catArr.Length {
        cat    := catArr[A_Index]
        catId  := _JsonStr(cat["id"])
        catNm  := _JsonStr(cat["name"])
        cmds   := cat["commands"]
        cmdArr := "["
        sep2   := ""
        loop cmds.Length {
            cmdArr .= sep2 . _JsonStr(cmds[A_Index])
            sep2   := ","
        }
        cmdArr .= "]"
        catJson .= sep1 . '{"id":' . catId . ',"name":' . catNm . ',"commands":' . cmdArr . '}'
        sep1    := ","
    }
    catJson .= "]"

    ; ── CommandList ──────────────────────────────────────────────────────
    cmdList := g_Commands["CommandList"]
    clJson  := "{"
    sep3    := ""
    for cmdId, v in cmdList {
        nm   := _JsonStr(v["name"])
        desc := _JsonStr(v["desc"])
        fn   := _JsonStr(v["fn"])
        clJson .= sep3 . _JsonStr(cmdId) . ':{"name":' . nm . ',"desc":' . desc . ',"fn":' . fn . '}'
        sep3   := ","
    }
    clJson .= "}"

    ; ── Bindings ─────────────────────────────────────────────────────────
    bJson := "{"
    sep4  := ""
    for ahkKey, cmdId in g_Commands["Bindings"] {
        bJson .= sep4 . _JsonStr(ahkKey) . ":" . _JsonStr(cmdId)
        sep4  := ","
    }
    bJson .= "}"

    return '{"Categories":' . catJson . ',"CommandList":' . clJson . ',"Bindings":' . bJson . '}'
}

; ---------------------------------------------------------------------------
; JSON 字符串转义辅助
; ---------------------------------------------------------------------------
_JsonStr(s) {
    s := StrReplace(s, "\",  "\\")
    s := StrReplace(s, '"',  '\"')
    s := StrReplace(s, "`n", "\n")
    s := StrReplace(s, "`r", "\r")
    s := StrReplace(s, "`t", "\t")
    return '"' . s . '"'
}

; ===========================================================================
; 热键层：绑定 / 解绑 / 执行
; ===========================================================================

_BindKey(ahkKey, cmdId) {
    global g_HotkeyBound
    ; 先解绑旧的（如果存在）
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

_ExecuteCommand(cmdId) {
    global g_Commands
    if !g_Commands.Has("CommandList") || !g_Commands["CommandList"].Has(cmdId) {
        OutputDebug("[VK] Unknown command: " . cmdId)
        return
    }
    fn := g_Commands["CommandList"][cmdId]["fn"]
    switch fn {
        case "EXIT_APP":     ExitApp()
        case "SHOW_VK":      VK_Show()
        case "HIDE_VK":      VK_Hide()
        case "RESET_VK":     VK_SendToWeb('{"type":"reset"}')
        case "WIN_MIN":      try WinMinimize("A")
        case "WIN_CLOSE":    try WinClose("A")
        case "CURSOR_OPEN":  OutputDebug("[VK] CURSOR_OPEN: hook here")
        case "CURSOR_CLOSE": OutputDebug("[VK] CURSOR_CLOSE: hook here")
        default:             OutputDebug("[VK] Unhandled fn: " . fn)
    }
}

; ===========================================================================
; WebView2 初始化
; ===========================================================================

_OnWV2Created(ctrl) {
    global g_VK_WV2, g_VK_Ctrl

    g_VK_Ctrl := ctrl
    g_VK_WV2  := ctrl.CoreWebView2

    try g_VK_Ctrl.DefaultBackgroundColor := 0xFF0A0A0A

    _ApplyWV2Bounds()

    s := g_VK_WV2.Settings
    s.AreDefaultContextMenusEnabled := false
    s.IsStatusBarEnabled            := false
    s.AreDevToolsEnabled            := true

    g_VK_WV2.add_WebMessageReceived(_OnWebMessage)

    htmlPath := A_ScriptDir "\VirtualKeyboard.html"
    if FileExist(htmlPath)
        g_VK_WV2.Navigate("file:///" . StrReplace(htmlPath, "\", "/"))
    else
        g_VK_WV2.NavigateToString(_FallbackHtml())
}

_ApplyWV2Bounds() {
    global g_VK_Gui, g_VK_Ctrl
    if !g_VK_Ctrl
        return
    TitleH := 30
    WinGetClientPos(, , &cw, &ch, g_VK_Gui.Hwnd)
    rc        := WebView2.RECT()
    rc.left   := 0
    rc.top    := TitleH
    rc.right  := cw
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

; ===========================================================================
; 消息分发：JS → AHK
; ===========================================================================

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
        ; ── 页面就绪：推送初始化数据 ───────────────────────────────────
        case "ready":
            g_VK_Ready := true
            OutputDebug("[VK] WebView ready")
            _PushInit()
            _PushModifierState()
            _StartKeyPreviewHook()

        ; ── JS 录制到新按键，要求保存绑定 ─────────────────────────────
        case "bindKey":
            if !msg.Has("commandId") || !msg.Has("ahkKey")
                return
            cmdId      := msg["commandId"]
            ahkKey     := msg["ahkKey"]
            displayKey := msg.Has("displayKey") ? msg["displayKey"] : ahkKey
            _DoBindKey(cmdId, ahkKey, displayKey)

        ; ── 前端请求开始录制：由 AHK InputHook 捕获组合键 ─────────────────
        case "startRecord":
            if msg.Has("commandId")
                _BeginRecord(msg["commandId"])

        ; ── 清除某命令的绑定 ────────────────────────────────────────────
        case "clearBinding":
            if msg.Has("commandId")
                _DoClearBinding(msg["commandId"])

        ; ── 前端发起测试执行 ────────────────────────────────────────────
        case "executeCommand":
            if msg.Has("commandId")
                _ExecuteCommand(msg["commandId"])

        ; ── 冲突确认响应 ─────────────────────────────────────────────
        case "resolveConflict":
            if g_PendingConflict.Has("cmdId") {
                if msg.Has("confirm") && msg["confirm"]
                    _DoBindKey(g_PendingConflict["cmdId"],
                               g_PendingConflict["ahkKey"],
                               g_PendingConflict["displayKey"])
                g_PendingConflict := Map()
            }
            VK_SendToWeb('{"type":"recordHint","active":false}')

        ; ── 键位适配模式切换 ─────────────────────────────────────────
        case "setLayoutMode":
            g_UseScanCode := msg.Has("native") && msg["native"]
            VK_SendToWeb('{"type":"layoutMode","native":' . (g_UseScanCode ? "true" : "false") . '}')
            OutputDebug("[VK] ScanCode mode: " . (g_UseScanCode ? "on" : "off"))

        default:
            OutputDebug("[VK] Unknown msg: " . msg["type"])
    }
}

; ---------------------------------------------------------------------------
; 绑定处理（含冲突解除）
; ---------------------------------------------------------------------------
_DoBindKey(cmdId, ahkKey, displayKey) {
    global g_Bindings, g_InverseBindings

    ; 1. 如果该 cmdId 已绑定其他键，先解除
    if g_InverseBindings.Has(cmdId) {
        oldKey := g_InverseBindings[cmdId]
        if oldKey != ahkKey {
            _UnbindKey(oldKey)
            g_Bindings.Delete(oldKey)
        }
    }
    ; 2. 如果该 ahkKey 已被其他 cmdId 占用，先解除
    if g_Bindings.Has(ahkKey) {
        oldCmd := g_Bindings[ahkKey]
        if oldCmd != cmdId
            g_InverseBindings.Delete(oldCmd)
    }

    ; 3. 写入新绑定
    g_Bindings[ahkKey]        := cmdId
    g_InverseBindings[cmdId]  := ahkKey
    _BindKey(ahkKey, cmdId)
    _SaveBindings()

    ; 4. 推送更新给 JS
    escaped := StrReplace(StrReplace(displayKey, "\", "\\"), '"', '\"')
    VK_SendToWeb('{"type":"bindingUpdated","commandId":"' . cmdId
        . '","ahkKey":"'     . ahkKey
        . '","displayKey":"' . escaped . '"}')
    OutputDebug("[VK] bindKey: " . cmdId . " = " . ahkKey)
}

; ---------------------------------------------------------------------------
; 清除绑定
; ---------------------------------------------------------------------------
_DoClearBinding(cmdId) {
    global g_Bindings, g_InverseBindings

    if !g_InverseBindings.Has(cmdId)
        return
    ahkKey := g_InverseBindings[cmdId]
    _UnbindKey(ahkKey)
    g_Bindings.Delete(ahkKey)
    g_InverseBindings.Delete(cmdId)
    _SaveBindings()

    VK_SendToWeb('{"type":"bindingUpdated","commandId":"' . cmdId
        . '","ahkKey":"","displayKey":""}')
    OutputDebug("[VK] clearBinding: " . cmdId)
}

; ===========================================================================
; 全局按键预览（任意焦点下高亮键帽，不拦截输入）
; ===========================================================================

_VkJsonStr(s) {
    s := StrReplace(s, "\", "\\")
    s := StrReplace(s, '"', '\"')
    return s
}

; 将 vk/sc 映射为与 VirtualKeyboard.html 中 data-ahkkey 一致的字符串
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
    ; HTML 中反引号键使用 data-ahkkey="``"（双引号内成对 `` 表示字面 `）
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
    ; V: 透传按键到前台；L0: 不收集文本缓冲区
    ; 必须 KeyOpt {All} N：否则 OnKeyDown/OnKeyUp 不会对「产生文本」的键触发（仅 NotifyNonText 对非文本键有效）
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

; ===========================================================================
; 修饰键实时同步
; ===========================================================================

_UpdateModifierState() {
    global g_ModState
    g_ModState["ctrl"]  := GetKeyState("Ctrl", "P")
    g_ModState["alt"]   := GetKeyState("Alt", "P")
    g_ModState["shift"] := GetKeyState("Shift", "P")
    _PushModifierState()
}

_PushModifierState() {
    global g_ModState
    VK_SendToWeb(
        '{"type":"modifierState","ctrl":'  . (g_ModState["ctrl"]  ? "true" : "false")
      . ',"alt":'                           . (g_ModState["alt"]   ? "true" : "false")
      . ',"shift":'                         . (g_ModState["shift"] ? "true" : "false")
      . '}'
    )
}

; ===========================================================================
; InputHook 录制链路
; ===========================================================================

_BeginRecord(commandId) {
    global g_RecordHook, g_RecordCtx

    ; 先停止旧录制
    try _EndRecord()

    g_RecordCtx["active"]    := true
    g_RecordCtx["commandId"] := commandId

    ih := InputHook("V")
    ih.KeyOpt("{All}", "E")
    ih.OnKeyDown := _OnRecordKeyDown
    g_RecordHook := ih
    ih.Start()

    VK_SendToWeb('{"type":"recordHint","active":true,"commandId":"' . commandId . '"}')
    OutputDebug("[VK] record start: " . commandId)
}

_EndRecord() {
    global g_RecordHook, g_RecordCtx
    if IsObject(g_RecordHook) {
        try g_RecordHook.Stop()
    }
    g_RecordHook := 0
    g_RecordCtx["active"]    := false
    g_RecordCtx["commandId"] := ""
}

_OnRecordKeyDown(ih, vk, sc) {
    global g_RecordCtx, g_Bindings, g_Commands, g_PendingConflict, g_UseScanCode
    if !g_RecordCtx["active"]
        return

    ; ScanCode 模式：通过物理键位映射，绕过 IME 干扰
    if g_UseScanCode {
        keyName := _GetKeyFromSC(sc)
        if !keyName
            keyName := GetKeyName(Format("vk{:x}sc{:x}", vk, sc))
    } else {
        keyName := GetKeyName(Format("vk{:x}sc{:x}", vk, sc))
    }

    if !keyName || _IsModifierOnlyKey(keyName)
        return

    isCtrl  := GetKeyState("Ctrl", "P")
    isAlt   := GetKeyState("Alt", "P")
    isShift := GetKeyState("Shift", "P")
    ahkKey  := _NormalizeToAhkHotkey(keyName, isCtrl, isAlt, isShift)
    if !ahkKey
        return

    cmdId      := g_RecordCtx["commandId"]
    displayKey := _ToDisplayKey(ahkKey)

    ; 冲突检测：该 ahkKey 已被另一命令占用
    if g_Bindings.Has(ahkKey) {
        conflictId := g_Bindings[ahkKey]
        if conflictId != cmdId {
            g_PendingConflict["cmdId"]      := cmdId
            g_PendingConflict["ahkKey"]     := ahkKey
            g_PendingConflict["displayKey"] := displayKey
            g_PendingConflict["conflictId"] := conflictId
            _EndRecord()
            conflictName := (g_Commands.Has("CommandList") && g_Commands["CommandList"].Has(conflictId))
                ? g_Commands["CommandList"][conflictId]["name"] : conflictId
            escDk   := StrReplace(StrReplace(displayKey,   "\", "\\"), '"', '\"')
            escName := StrReplace(StrReplace(conflictName, "\", "\\"), '"', '\"')
            VK_SendToWeb('{"type":"confirmConflict","commandId":"'   . cmdId
                . '","ahkKey":"'          . ahkKey
                . '","displayKey":"'      . escDk
                . '","conflictCmdId":"'   . conflictId
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
    ; 单字符
    if StrLen(keyName) = 1 {
        if RegExMatch(keyName, "^[A-Z]$")
            return Format("{:L}", keyName)
        return keyName
    }
    static keyNameMap := Map(
        "Escape","Escape","Esc","Escape",
        "Enter","Enter","Tab","Tab","Space","Space",
        "Backspace","Backspace","CapsLock","CapsLock",
        "Delete","Delete","Del","Delete","Insert","Insert","Ins","Insert",
        "Home","Home","End","End","PgUp","PgUp","PgDn","PgDn",
        "Up","Up","Down","Down","Left","Left","Right","Right",
        "PrintScreen","PrintScreen","ScrollLock","ScrollLock","Pause","Pause",
        "AppsKey","AppsKey","LWin","LWin","RWin","RWin",
        "NumpadDiv","NumpadDiv","NumpadMult","NumpadMult","NumpadSub","NumpadSub","NumpadAdd","NumpadAdd","NumpadEnter","NumpadEnter",
        "NumpadDot","NumpadDot","NumpadIns","Numpad0","NumpadEnd","Numpad1","NumpadDown","Numpad2","NumpadPgDn","Numpad3",
        "NumpadLeft","Numpad4","NumpadClear","Numpad5","NumpadRight","Numpad6","NumpadHome","Numpad7","NumpadUp","Numpad8","NumpadPgUp","Numpad9"
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

; ---------------------------------------------------------------------------
; ScanCode → 标准 AHK 键名（物理键位，IME 无关）
; 覆盖主键盘区 + F 键区；扩展键（方向/导航）回落到 GetKeyName
; ---------------------------------------------------------------------------
_GetKeyFromSC(sc) {
    static scMap := Map(
        ; Esc + F 行
        0x01,"Escape",
        0x3B,"F1",  0x3C,"F2",  0x3D,"F3",  0x3E,"F4",
        0x3F,"F5",  0x40,"F6",  0x41,"F7",  0x42,"F8",
        0x43,"F9",  0x44,"F10", 0x57,"F11", 0x58,"F12",
        ; 数字行
        0x29,"``",  0x02,"1", 0x03,"2", 0x04,"3", 0x05,"4",
        0x06,"5",   0x07,"6", 0x08,"7", 0x09,"8", 0x0A,"9",
        0x0B,"0",   0x0C,"-", 0x0D,"=", 0x0E,"Backspace",
        ; QWERTY 行
        0x0F,"Tab",
        0x10,"q", 0x11,"w", 0x12,"e", 0x13,"r", 0x14,"t",
        0x15,"y", 0x16,"u", 0x17,"i", 0x18,"o", 0x19,"p",
        0x1A,"[", 0x1B,"]", 0x2B,"\",
        ; ASDF 行
        0x3A,"CapsLock",
        0x1E,"a", 0x1F,"s", 0x20,"d", 0x21,"f", 0x22,"g",
        0x23,"h", 0x24,"j", 0x25,"k", 0x26,"l",
        0x27,";", 0x28,"'", 0x1C,"Enter",
        ; ZXCV 行
        0x2A,"LShift",
        0x2C,"z", 0x2D,"x", 0x2E,"c", 0x2F,"v", 0x30,"b",
        0x31,"n", 0x32,"m", 0x33,",", 0x34,".", 0x35,"/",
        0x36,"RShift",
        ; 底行
        0x1D,"LCtrl", 0x38,"LAlt", 0x39,"Space",
        ; 其他
        0x37,"PrintScreen", 0x46,"ScrollLock", 0x45,"Pause"
    )
    return scMap.Has(sc) ? scMap[sc] : ""
}

; ===========================================================================
; _PushInit：构造初始化消息发给 JS
; ===========================================================================

_PushInit() {
    global g_Commands, g_InverseBindings

    if !g_Commands.Has("Categories") {
        OutputDebug("[VK] Commands not loaded")
        return
    }

    ; ── categories ────────────────────────────────────────────────────────
    catArr  := g_Commands["Categories"]
    catJson := "["
    sep     := ""
    loop catArr.Length {
        cat  := catArr[A_Index]
        cmds := cat["commands"]
        cArr := "["
        cs   := ""
        loop cmds.Length {
            cArr .= cs . _JsonStr(cmds[A_Index])
            cs   := ","
        }
        cArr   .= "]"
        catJson .= sep . '{"id":' . _JsonStr(cat["id"]) . ',"name":' . _JsonStr(cat["name"]) . ',"commands":' . cArr . '}'
        sep     := ","
    }
    catJson .= "]"

    ; ── commands ──────────────────────────────────────────────────────────
    cmdList := g_Commands["CommandList"]
    clJson  := "{"
    sep2    := ""
    for cmdId, v in cmdList {
        nm   := _JsonStr(v["name"])
        desc := _JsonStr(v["desc"])
        clJson .= sep2 . _JsonStr(cmdId) . ':{"name":' . nm . ',"desc":' . desc . '}'
        sep2   := ","
    }
    clJson .= "}"

    ; ── bindings (commandId -> {ahkKey, displayKey}) ──────────────────────
    bJson := "{"
    sep3  := ""
    for cmdId, ahkKey in g_InverseBindings {
        dk    := _AhkKeyToDisplay(ahkKey)
        esc   := StrReplace(StrReplace(dk, "\", "\\"), '"', '\"')
        bJson .= sep3 . _JsonStr(cmdId) . ':{"ahkKey":' . _JsonStr(ahkKey) . ',"displayKey":"' . esc . '"}'
        sep3  := ","
    }
    bJson .= "}"

    payload := '{"type":"init","categories":' . catJson
            . ',"commands":'  . clJson
            . ',"bindings":'  . bJson . '}'
    VK_SendToWeb(payload)
    OutputDebug("[VK] init pushed")
}

; ---------------------------------------------------------------------------
; AHK hotkey 字符串 → 人类可读（"^+k" → "Ctrl+Shift+K"）
; ---------------------------------------------------------------------------
_AhkKeyToDisplay(ahkKey) {
    display := ""
    key     := ahkKey
    if InStr(key, "^") {
        display .= "Ctrl+"
        key     := StrReplace(key, "^", "")
    }
    if InStr(key, "!") {
        display .= "Alt+"
        key     := StrReplace(key, "!", "")
    }
    if InStr(key, "+") {
        display .= "Shift+"
        key     := StrReplace(key, "+", "")
    }
    ; 首字母大写
    if StrLen(key) = 1
        key := Format("{:U}", key)
    static specialMap := Map(
        "Escape","Esc","Enter","Enter","Space","Space","Tab","Tab",
        "Backspace","Bks","Delete","Del","Insert","Ins",
        "Home","Home","End","End","PgUp","PgUp","PgDn","PgDn",
        "Up","↑","Down","↓","Left","←","Right","→",
        "LShift","LShift","RShift","RShift",
        "LCtrl","LCtrl","RCtrl","RCtrl",
        "LAlt","LAlt","RAlt","RAlt",
        "LWin","Win","RWin","Win","AppsKey","Menu",
        "PrintScreen","PrtSc","ScrollLock","ScrLk","Pause","Pause"
    )
    if specialMap.Has(key)
        key := specialMap[key]
    return display . key
}

; ===========================================================================
; 公共 API
; ===========================================================================

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

VK_SendToWeb(jsonStr) {
    global g_VK_WV2, g_VK_Ready
    if g_VK_WV2 && g_VK_Ready
        g_VK_WV2.PostWebMessageAsJson(jsonStr)
}

; ---------------------------------------------------------------------------
; 跨脚本通知：向目标 AHK 窗口发送 WM_COPYDATA JSON 消息
; 对方需注册 OnMessage(0x4A, handler) 来接收
; 接收示例（在 CursorHelper.ahk 中添加）：
;   OnMessage(0x4A, _OnVkCopyData)
;   _OnVkCopyData(wParam, lParam, *) {
;       sz  := NumGet(lParam+4, "UInt")
;       ptr := NumGet(lParam+8, "Ptr")
;       json := StrGet(ptr, sz, "UTF-8")
;       ; 解析 json 并处理 bindingsReloaded 等事件
;   }
; ---------------------------------------------------------------------------
NotifyScript(targetTitle, payload) {
    hwnd := WinExist(targetTitle . " ahk_class AutoHotkey")
    if !hwnd
        return false
    strBuf := Buffer(StrPut(payload, "UTF-8"))
    StrPut(payload, strBuf, "UTF-8")
    ; COPYDATASTRUCT: dwData(4) + cbData(4) + lpData(ptr)
    cds := Buffer(4 + 4 + A_PtrSize, 0)
    NumPut("UInt", 1,           cds, 0)   ; dwData
    NumPut("UInt", strBuf.Size, cds, 4)   ; cbData
    NumPut("Ptr",  strBuf.Ptr,  cds, 8)   ; lpData
    try {
        SendMessage(0x4A, 0, cds.Ptr, , "ahk_id " . hwnd)
        OutputDebug("[VK] NotifyScript -> " . targetTitle)
        return true
    } catch {
        return false
    }
}

; ===========================================================================
; 快捷键（全局控制）
; ===========================================================================

OnExit (*) => _VkOnAppExit()

_VkOnAppExit(*) {
    _StopKeyPreviewHook()
    _EndRecord()
}

; Ctrl+Shift+K  切换显示/隐藏（保持不硬编码业务逻辑，仅控制窗口本身）
^+k:: {
    global g_VK_Gui
    if !g_VK_Gui
        return
    if WinExist("ahk_id " . g_VK_Gui.Hwnd) && WinGetStyle("ahk_id " . g_VK_Gui.Hwnd) & 0x10000000
        VK_Hide()
    else
        VK_Show()
}

; 修饰键实时状态监听（不拦截按键）
~Ctrl::    _UpdateModifierState()
~Ctrl Up:: _UpdateModifierState()
~Alt::     _UpdateModifierState()
~Alt Up::  _UpdateModifierState()
~Shift::   _UpdateModifierState()
~Shift Up::_UpdateModifierState()

; ===========================================================================
; 备用 HTML
; ===========================================================================

_FallbackHtml() {
    return (
        '<!DOCTYPE html><html><head><meta charset="UTF-8"></head>'
        '<body style="background:#0a0a0a;color:#e67e22;font-family:Consolas,monospace;'
        'display:flex;align-items:center;justify-content:center;height:100vh;margin:0;">'
        '<div style="text-align:center;"><div style="font-size:28px;margin-bottom:16px;'
        'text-shadow:0 0 10px #e67e22;">[ VK KEYBINDER ]</div>'
        '<div style="color:#888;font-size:13px;">VirtualKeyboard.html not found</div>'
        '</div></body></html>'
    )
}
