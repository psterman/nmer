; ===========================================================================
; VirtualKeyboard.ahk
; 橙+黑极客风 WebView2 虚拟键盘宿主脚本
; AHK v2 | 依赖: lib\WebView2.ahk, lib\Jxon.ahk
; ===========================================================================
#Requires AutoHotkey v2.0
#SingleInstance Force

#Include lib\WebView2.ahk
#Include lib\Jxon.ahk

; ---------------------------------------------------------------------------
; 全局句柄
; ---------------------------------------------------------------------------
global g_VK_Gui      := 0       ; Gui 对象
global g_VK_WV2      := 0       ; WebView2.Core 对象
global g_VK_Ctrl     := 0       ; WebView2.Controller 对象
global g_VK_Ready    := false    ; WebView 就绪标志

; ---------------------------------------------------------------------------
; 按键映射表
; ---------------------------------------------------------------------------
global g_KeyMap      := Map()   ; code -> Map("label","...","command","...")
global g_HotkeyBound := Map()   ; code -> 1，记录已动态绑定的 Hotkey

; ---------------------------------------------------------------------------
; 入口：直接运行时启动键盘
; ---------------------------------------------------------------------------
VK_Init()

VK_Init() {
    global g_VK_Gui

    ; ── 无边框主窗口 ────────────────────────────────────────────────────
    g_VK_Gui := Gui("+AlwaysOnTop -Caption +Resize -DPIScale", "VirtualKeyboard")
    g_VK_Gui.BackColor := "0a0a0a"
    g_VK_Gui.MarginX := 0
    g_VK_Gui.MarginY := 0

    ; ── 自制标题栏（30px 高，可拖动） ──────────────────────────────────
    TitleH    := 30
    WinW      := 900
    BtnW      := 24
    BtnPad    := 4

    ; 标题栏背景（透明占位 Text，充当拖动热区）
    TitleBg := g_VK_Gui.Add("Text",
        "x0 y0 w" . (WinW - BtnW*2 - BtnPad*3) . " h" . TitleH . " Background1a1a1a", "")
    TitleBg.OnEvent("Click", _TitleDrag)

    ; 标题文字
    TitleLbl := g_VK_Gui.Add("Text",
        "x12 y7 w280 h18 ce67e22 Background1a1a1a", "[ VIRTUAL KEYBOARD ]")
    TitleLbl.SetFont("s9 Bold", "Consolas")
    TitleLbl.OnEvent("Click", _TitleDrag)

    ; 最小化按钮
    MinX := WinW - BtnW*2 - BtnPad*2
    MinBtn := g_VK_Gui.Add("Text",
        "x" . MinX . " y7 w" . BtnW . " h18 Center cf5f5f5 Background1a1a1a", "─")
    MinBtn.SetFont("s10", "Segoe UI")
    MinBtn.OnEvent("Click", (*) => WinMinimize(g_VK_Gui.Hwnd))

    ; 关闭按钮
    CloseX := WinW - BtnW - BtnPad
    CloseBtn := g_VK_Gui.Add("Text",
        "x" . CloseX . " y7 w" . BtnW . " h18 Center cf5f5f5 Background1a1a1a", "✕")
    CloseBtn.SetFont("s10", "Segoe UI")
    CloseBtn.OnEvent("Click", (*) => VK_Hide())

    ; ── 显示窗口 ────────────────────────────────────────────────────────
    g_VK_Gui.Show("w" . WinW . " h340 NoActivate")
    g_VK_Gui.OnEvent("Close", (*) => VK_Hide())
    g_VK_Gui.OnEvent("Size",  _OnGuiResize)

    ; ── 初始化 WebView2（异步回调） ─────────────────────────────────────
    WebView2.create(g_VK_Gui.Hwnd, _OnWV2Created)

    ; ── 系统托盘 ────────────────────────────────────────────────────────
    A_TrayMenu.Delete()
    A_TrayMenu.Add("显示键盘",  (*) => VK_Show())
    A_TrayMenu.Add("隐藏键盘",  (*) => VK_Hide())
    A_TrayMenu.Add("重置键盘",  (*) => VK_Reset())
    A_TrayMenu.Add()
    A_TrayMenu.Add("退出",      (*) => ExitApp())
    A_TrayMenu.Default := "显示键盘"

    ; 初始化默认键映射（加载 WebView 后会通过 ready 消息推送给 JS）
    _InitDefaultKeyMap()
}

; ---------------------------------------------------------------------------
; 默认映射初始化（在 VK_Init 末尾调用）
; ---------------------------------------------------------------------------
_InitDefaultKeyMap() {
    global g_KeyMap
    g_KeyMap["Escape"] := Map("label", "退出", "command", "EXIT_APP")
    _BindAllHotkeys()
}

; ---------------------------------------------------------------------------
; WebView2 Controller 就绪回调
; ---------------------------------------------------------------------------
_OnWV2Created(ctrl) {
    global g_VK_WV2, g_VK_Ctrl

    g_VK_Ctrl := ctrl
    g_VK_WV2  := ctrl.CoreWebView2

    ; 某些 WebView2 Runtime/接口组合上，设置 DefaultBackgroundColor 会报 0x80070057
    ; 这里做兼容性保护：失败时忽略，不影响主流程。
    try g_VK_Ctrl.DefaultBackgroundColor := 0xFF0A0A0A

    ; 设置 WebView 区域偏移标题栏
    _ApplyWV2Bounds()

    ; 配置 Settings
    s := g_VK_WV2.Settings
    s.AreDefaultContextMenusEnabled := false
    s.IsStatusBarEnabled            := false
    s.AreDevToolsEnabled            := true   ; 开发阶段保留，上线可改为 false

    ; 注册 JS→AHK 消息监听
    g_VK_WV2.add_WebMessageReceived(_OnWebMessage)

    ; 加载 HTML（优先使用外部文件，便于修改；文件不存在则内嵌备用页）
    htmlPath := A_ScriptDir "\VirtualKeyboard.html"
    if FileExist(htmlPath) {
        g_VK_WV2.Navigate("file:///" . StrReplace(htmlPath, "\", "/"))
    } else {
        g_VK_WV2.NavigateToString(_GetFallbackHtml())
    }
}

; ---------------------------------------------------------------------------
; 设置 WebView2 控件区域（标题栏以下）
; ---------------------------------------------------------------------------
_ApplyWV2Bounds() {
    global g_VK_Gui, g_VK_Ctrl
    if !g_VK_Ctrl
        return
    TitleH := 30
    WinGetClientPos(, , &cw, &ch, g_VK_Gui.Hwnd)
    rc := WebView2.RECT()
    rc.left   := 0
    rc.top    := TitleH
    rc.right  := cw
    rc.bottom := ch
    g_VK_Ctrl.Bounds := rc
}

; ---------------------------------------------------------------------------
; 窗口大小变化 → 同步 WebView2 区域
; ---------------------------------------------------------------------------
_OnGuiResize(GuiObj, MinMax, Width, Height) {
    if MinMax = -1  ; 最小化时不处理
        return
    _ApplyWV2Bounds()
}

; ---------------------------------------------------------------------------
; 标题栏拖动（发送 WM_NCLBUTTONDOWN / HTCAPTION）
; ---------------------------------------------------------------------------
_TitleDrag(*) {
    global g_VK_Gui
    PostMessage(0x00A1, 2, 0, , g_VK_Gui.Hwnd)
}

; ---------------------------------------------------------------------------
; JS → AHK 消息处理
; ---------------------------------------------------------------------------
_OnWebMessage(sender, args) {
    global g_VK_Ready

    ; WebMessageAsJson 直接返回 JS postMessage(obj) 序列化后的 JSON 字符串
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
            VK_SendToWeb('{"type":"setStatus","connected":true,"text":"AHK connected"}')
            ; 推送当前键映射给 JS
            _PushKeyMap()

        case "keyPress":
            ; exec 模式：如果该键有映射则执行命令，否则走原始处理
            key  := msg.Has("key")  ? msg["key"]  : ""
            code := msg.Has("code") ? msg["code"] : ""
            OutputDebug("[VK] keyPress  key=" . key . "  code=" . code)
            if g_KeyMap.Has(code)
                _ExecuteCommand(g_KeyMap[code]["command"])
            else
                _HandleVirtualKey(key, code, msg)

        case "keyDown":
            OutputDebug("[VK] keyDown  code=" . (msg.Has("code") ? msg["code"] : "?"))

        case "keyUp":
            OutputDebug("[VK] keyUp  code=" . (msg.Has("code") ? msg["code"] : "?"))

        case "saveMapping":
            ; 保存/更新绑定（含冲突解除）
            if !msg.Has("code") || !msg.Has("label") || !msg.Has("command")
                return
            _SaveMapping(msg["code"], msg["label"], msg["command"])

        case "clearMapping":
            ; 解除绑定
            if msg.Has("code")
                _ClearMapping(msg["code"])

        default:
            OutputDebug("[VK] Unknown msg type: " . msg["type"])
    }
}

; ---------------------------------------------------------------------------
; 虚拟按键处理（无映射时的默认行为）
; ---------------------------------------------------------------------------
_HandleVirtualKey(key, code, msgObj) {
    VK_SetHudMessage("AHK recv: " . code)
    ; 取消注释让虚拟键盘真正发送按键：
    ; if (StrLen(key) = 1)
    ;     SendInput("{" . key . "}")
}

; ---------------------------------------------------------------------------
; 命令执行器
; ---------------------------------------------------------------------------
_ExecuteCommand(command) {
    switch command {
        case "EXIT_APP":  ExitApp()
        case "SHOW_VK":   VK_Show()
        case "HIDE_VK":   VK_Hide()
        case "RESET_VK":  VK_Reset()
        default:
            OutputDebug("[VK] Unknown command: " . command)
    }
}

; ---------------------------------------------------------------------------
; KeyboardEvent.code → AHK Hotkey 键名
; ---------------------------------------------------------------------------
_CodeToAhkKey(code) {
    static tbl := Map(
        "Escape",       "Escape",
        "Enter",        "Enter",
        "Space",        "Space",
        "Tab",          "Tab",
        "Backspace",    "Backspace",
        "CapsLock",     "CapsLock",
        "Delete",       "Delete",
        "Insert",       "Insert",
        "Home",         "Home",
        "End",          "End",
        "PageUp",       "PgUp",
        "PageDown",     "PgDn",
        "PrintScreen",  "PrintScreen",
        "ScrollLock",   "ScrollLock",
        "Pause",        "Pause",
        "ShiftLeft",    "LShift",
        "ShiftRight",   "RShift",
        "ControlLeft",  "LCtrl",
        "ControlRight", "RCtrl",
        "AltLeft",      "LAlt",
        "AltRight",     "RAlt",
        "MetaLeft",     "LWin",
        "MetaRight",    "RWin",
        "ContextMenu",  "AppsKey",
        "ArrowUp",      "Up",
        "ArrowDown",    "Down",
        "ArrowLeft",    "Left",
        "ArrowRight",   "Right",
        "F1","F1",  "F2","F2",  "F3","F3",  "F4","F4",
        "F5","F5",  "F6","F6",  "F7","F7",  "F8","F8",
        "F9","F9",  "F10","F10","F11","F11","F12","F12",
        "KeyA","a", "KeyB","b", "KeyC","c", "KeyD","d",
        "KeyE","e", "KeyF","f", "KeyG","g", "KeyH","h",
        "KeyI","i", "KeyJ","j", "KeyK","k", "KeyL","l",
        "KeyM","m", "KeyN","n", "KeyO","o", "KeyP","p",
        "KeyQ","q", "KeyR","r", "KeyS","s", "KeyT","t",
        "KeyU","u", "KeyV","v", "KeyW","w", "KeyX","x",
        "KeyY","y", "KeyZ","z",
        "Digit0","0","Digit1","1","Digit2","2","Digit3","3",
        "Digit4","4","Digit5","5","Digit6","6","Digit7","7",
        "Digit8","8","Digit9","9",
        "Minus",        "-",
        "Equal",        "=",
        "BracketLeft",  "[",
        "BracketRight", "]",
        "Backslash",    "\",
        "Semicolon",    ";",
        "Quote",        "'",
        "Backquote",    "``",
        "Comma",        ",",
        "Period",       ".",
        "Slash",        "/"
    )
    return tbl.Has(code) ? tbl[code] : ""
}

; ---------------------------------------------------------------------------
; 热键绑定辅助
; ---------------------------------------------------------------------------
_BindHotkey(code) {
    global g_KeyMap, g_HotkeyBound
    ahkKey := _CodeToAhkKey(code)
    if !ahkKey || !g_KeyMap.Has(code)
        return
    cmd := g_KeyMap[code]["command"]
    ; 用闭包固定 cmd 值
    fn := _MakeCmdFn(cmd)
    try Hotkey(ahkKey, fn, "On")
    g_HotkeyBound[code] := 1
    OutputDebug("[VK] Hotkey bound: " . ahkKey . " -> " . cmd)
}

_MakeCmdFn(cmd) {
    return (*) => _ExecuteCommand(cmd)
}

_UnbindHotkey(code) {
    global g_HotkeyBound
    ahkKey := _CodeToAhkKey(code)
    if ahkKey && g_HotkeyBound.Has(code) {
        try Hotkey(ahkKey, "Off")
        OutputDebug("[VK] Hotkey unbound: " . ahkKey)
    }
    g_HotkeyBound.Delete(code)
}

_BindAllHotkeys() {
    global g_KeyMap
    for code in g_KeyMap
        _BindHotkey(code)
}

; ---------------------------------------------------------------------------
; 映射保存 / 清除（含冲突处理）
; ---------------------------------------------------------------------------
_SaveMapping(code, label, command) {
    global g_KeyMap
    ; 冲突解除：同一 command 已绑定其他 code → 先清除
    toDelete := []
    for k, v in g_KeyMap {
        if (k != code && v["command"] = command)
            toDelete.Push(k)
    }
    for k in toDelete {
        g_KeyMap.Delete(k)
        _UnbindHotkey(k)
    }
    g_KeyMap[code] := Map("label", label, "command", command)
    _BindHotkey(code)
    _PushKeyMap()
    OutputDebug("[VK] Mapping saved: " . code . " -> " . command)
}

_ClearMapping(code) {
    global g_KeyMap
    g_KeyMap.Delete(code)
    _UnbindHotkey(code)
    _PushKeyMap()
    OutputDebug("[VK] Mapping cleared: " . code)
}

; ---------------------------------------------------------------------------
; 将 g_KeyMap 序列化为 JSON 并推送到 WebView
; ---------------------------------------------------------------------------
_PushKeyMap() {
    global g_KeyMap
    json := '{"type":"loadMap","map":{'
    sep  := ""
    for code, v in g_KeyMap {
        lbl := StrReplace(StrReplace(v["label"], "\", "\\"), '"', '\"')
        cmd := StrReplace(v["command"], '"', '\"')
        json .= sep . '"' . code . '":{"label":"' . lbl . '","command":"' . cmd . '"}'
        sep := ","
    }
    json .= "}}"
    VK_SendToWeb(json)
}

; ===========================================================================
; ── 公共 API（可供其他模块 #Include 后调用）─────────────────────────────────
; ===========================================================================

/**
 * 显示虚拟键盘窗口
 */
VK_Show() {
    global g_VK_Gui
    if g_VK_Gui
        g_VK_Gui.Show("NoActivate")
}

/**
 * 隐藏虚拟键盘窗口
 */
VK_Hide() {
    global g_VK_Gui
    if g_VK_Gui
        g_VK_Gui.Hide()
}

/**
 * 向 WebView 发送任意 JSON 字符串（AHK → JS）
 * JS 侧通过 window.chrome.webview.addEventListener('message', e => e.data) 接收，
 * e.data 是已反序列化的对象（非字符串）。
 *
 * @param {String} jsonStr  合法的 JSON 字符串，例如 '{"type":"highlight","code":"KeyA"}'
 */
VK_SendToWeb(jsonStr) {
    global g_VK_WV2, g_VK_Ready
    if g_VK_WV2 && g_VK_Ready
        g_VK_WV2.PostWebMessageAsJson(jsonStr)
}

/**
 * 高亮键盘上指定按键
 * @param {String} keyCode   KeyboardEvent.code，如 "KeyA"、"Space"、"Enter"
 * @param {Integer} durationMs  高亮持续时间（毫秒），默认 400
 */
VK_HighlightKey(keyCode, durationMs := 400) {
    VK_SendToWeb('{"type":"highlight","code":"' . keyCode . '","duration":' . durationMs . '}')
}

/**
 * 设置键盘 HUD 消息文字
 * @param {String} text  要显示的消息
 */
VK_SetHudMessage(text) {
    escaped := StrReplace(StrReplace(text, "\", "\\"), '"', '\"')
    VK_SendToWeb('{"type":"setHud","message":"' . escaped . '"}')
}

/**
 * 重置键盘视觉状态（清除所有高亮 & CapsLock 指示灯）
 */
VK_Reset() {
    VK_SendToWeb('{"type":"reset"}')
}

/**
 * 同步 CapsLock 状态指示灯
 * @param {Integer} isOn  1 = 亮灯，0 = 熄灯
 */
VK_SetCapsLock(isOn) {
    VK_SendToWeb('{"type":"setCapsLock","value":' . (isOn ? "true" : "false") . '}')
}

; ---------------------------------------------------------------------------
; 快捷键
; ---------------------------------------------------------------------------
; Ctrl+Shift+K  切换显示/隐藏
^+k:: {
    global g_VK_Gui
    if !g_VK_Gui
        return
    if WinExist("ahk_id " . g_VK_Gui.Hwnd) && WinGetStyle("ahk_id " . g_VK_Gui.Hwnd) & 0x10000000
        VK_Hide()
    else
        VK_Show()
}

; Ctrl+Shift+H  演示：高亮 H 键
^+h:: VK_HighlightKey("KeyH", 800)

; Ctrl+Shift+R  演示：重置键盘
^+r:: VK_Reset()

; ---------------------------------------------------------------------------
; 备用内嵌 HTML（VirtualKeyboard.html 文件丢失时使用）
; ---------------------------------------------------------------------------
_GetFallbackHtml() {
    return (
        '<!DOCTYPE html><html><head><meta charset="UTF-8"></head>'
        '<body style="background:#0a0a0a;color:#e67e22;font-family:Consolas,monospace;'
        'display:flex;align-items:center;justify-content:center;height:100vh;margin:0;">'
        '<div style="text-align:center;">'
        '<div style="font-size:28px;margin-bottom:16px;'
        'text-shadow:0 0 10px #e67e22;">[ VK ]</div>'
        '<div style="font-size:13px;color:#888;">VirtualKeyboard.html not found</div>'
        '<div style="font-size:11px;color:#555;margin-top:8px;">'
        'Place VirtualKeyboard.html next to this script</div>'
        '</div></body></html>'
    )
}
