; VirtualKeyboard 核心（供 CursorHelper #Include 或独立 VirtualKeyboard.ahk #Include）
; 依赖：调用方已 #Include lib\WebView2.ahk 与 lib\Jxon.ahk
; 嵌入 CursorHelper 时：#Include modules\VirtualKeyboardExecCmd.ahk 须在本文件之前
#Include *i CursorShortcutMapper.ahk

global g_VK_Embedded := false
global g_JsonPath := ""
global g_Commands := Map()
global g_Bindings := Map()
global g_InverseBindings := Map()
; Bindings persistence (Commands.json):
; - g_Commands["Bindings"] = Map(cmdId -> ahkKey | "NONE")
; Runtime effective bindings (for Hotkey registration):
; - g_Bindings = Map(effectiveAhkKey -> cmdId)
; - g_InverseBindings = Map(cmdId -> effectiveAhkKey)
global g_HotkeyBound := Map()
; 嵌入模式：CapsLock 下由 HotIf(GetCapsLockState)+Hotkey() 动态挂载的键（重载前须 Off）
global g_VK_CapsLockDynHotkeys := []
; 嵌入模式：仅在 Cursor 窗口激活时生效的动态热键（qa_* 原生命令映射）
global g_VK_EmbeddedScopedHotkeys := []
global g_VK_Gui := 0
global g_VK_WV2 := 0
global g_VK_Ctrl := 0
global g_VK_Ready := false
global g_VK_FocusPending := false
global g_VK_LastShown := 0
global g_ModState := Map("ctrl", false, "alt", false, "shift", false)
global g_RecordCtx := Map("active", false, "commandId", "")
global g_RecordHook := 0
global g_PendingConflict := Map()
global g_UseScanCode := false
global g_VK_PreviewHook := 0
global g_LastExecutedCmdId := ""
global g_VK_QuickBindHook := 0
global g_VK_QuickBindArmed := false
global g_VK_QuickBindConsumed := false
global g_VK_NextShowFromCapsLockHold := false
global g_VK_TitleH := 44
global g_VK_IsAdmin := A_IsAdmin
global g_VK_AdminWarning := ""
; 双击修饰键：^^ / ++ / !!（与 Hotkey() 不兼容，由专用 InputHook 处理）
global g_VK_DblModIH := 0
global g_VK_DblModLast := Map("ctrl", 0, "shift", 0, "alt", 0)
global g_VK_RecordDblModLast := Map("ctrl", 0, "shift", 0, "alt", 0)
global g_VK_DblModIntervalMs := 400
global g_VK_SeqIH := 0
global g_VK_SeqLast := Map("key", "", "tick", 0)
global g_VK_SequenceIntervalMs := 400
global g_RecordPendingKey := ""
global g_RecordPendingTick := 0
global g_RecordFinalizeToken := 0
global g_VK_FloatGui := 0
global g_VK_FloatPinned := []
; app.local 导航：Navigate 常不抛错，失败在 NavigationCompleted；用于触发一次磁盘 NavigateToString 回退
global g_VK_ExpectAppLocalNavigationResult := false
global g_VK_TriedDiskAfterAppLocalFail := false

VK_EnsureInit(embedded := true) {
    global g_VK_Gui
    if g_VK_Gui
        return
    VK_Init(embedded)
}

VK_OnHostExit(*) {
    _StopKeyPreviewHook()
    _VK_StopQuickBindHook()
    _StopDoubleModifierHook()
    _StopSequenceHook()
    _EndRecord(false)
    _VK_UnregisterEmbeddedScopedHotkeys()
    global g_VK_FloatGui
    if IsObject(g_VK_FloatGui)
        try g_VK_FloatGui.Destroy()
}

VK_Init(embedded := false) {
    global g_VK_Gui, g_VK_Embedded, g_JsonPath, g_VK_IsAdmin, g_VK_AdminWarning

    if g_VK_Gui
        return

    g_VK_Embedded := embedded
    g_JsonPath := A_ScriptDir "\Commands.json"
    g_VK_IsAdmin := !!A_IsAdmin
    g_VK_AdminWarning := g_VK_IsAdmin ? "" : "Warning: running without admin privileges. Hotkeys may not work in elevated windows (e.g. Task Manager)."

    _LoadCommands()
    _VK_RefreshPromptTemplateCommands()
    if !embedded
        _ApplyAllBindings()
    _EnsureDoubleModifierHook()

    ScreenW := SysGet(0)
    ScreenH := SysGet(1)
    WinW := Max(1100, Min(Round(ScreenW * 0.94), 2100))
    WinH := Max(720, Min(Round(ScreenH * 0.90), 1260))
    TitleH := g_VK_TitleH
    BtnW := 32
    BtnPad := 8
    TitleBtnY := Max(8, (TitleH - 22) // 2)

    guiOpts := "+AlwaysOnTop -Caption +Resize -DPIScale +ToolWindow" . _VK_OwnerGuiOpt()
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

; 悬浮工具栏已创建时挂 Owner，减少任务栏独立图标（无工具栏则仅 ToolWindow）
_VK_OwnerGuiOpt() {
    ownerOpt := ""
    try {
        global FloatingToolbarGUI
        if IsSet(FloatingToolbarGUI) && IsObject(FloatingToolbarGUI) {
            oh := FloatingToolbarGUI.Hwnd
            if oh
                ownerOpt := " +Owner" . oh
        }
    } catch as e {
        OutputDebug("[VK] OwnerGuiOpt: " . e.Message)
    }
    return ownerOpt
}

; 嵌入：优先 https://app.local/VirtualKeyboard.html；独立进程：仅 FileRead / file://
_VK_NavigateMainHtml(htmlPath) {
    global g_VK_WV2, g_VK_Embedded, g_VK_ExpectAppLocalNavigationResult
    if !g_VK_WV2 || !FileExist(htmlPath)
        return
    if g_VK_Embedded {
        try {
            g_VK_WV2.Navigate(BuildAppLocalUrl("VirtualKeyboard.html"))
            g_VK_ExpectAppLocalNavigationResult := true
            return
        } catch as e {
            OutputDebug("[VK] Navigate app.local failed, fallback: " . e.Message)
        }
    }
    _VK_NavigateToStringFromDisk(htmlPath)
}

_VK_ReadVirtualKeyboardHtml(htmlPath) {
    try return FileRead(htmlPath, "UTF-8")
    catch as e {
        OutputDebug("[VK] FileRead html: " . e.Message)
        return ""
    }
}

_VK_NavigateToStringFromDisk(htmlPath) {
    global g_VK_WV2
    if !g_VK_WV2 || !FileExist(htmlPath)
        return
    html := _VK_ReadVirtualKeyboardHtml(htmlPath)
    if html = ""
        return
    try g_VK_WV2.NavigateToString(html)
    catch as e {
        OutputDebug("[VK] NavigateToString disk: " . e.Message)
        try g_VK_WV2.Navigate("file:///" . StrReplace(htmlPath, "\", "/"))
        catch as e2 {
            OutputDebug("[VK] file:// navigate failed: " . e2.Message)
        }
    }
}

_VK_BuiltinCommandCatalog() {
    return [
        Map("id", "ai_msg", "name", "💬 消息", "commands", [
            Map("id", "send", "name", "发送消息", "desc", "直接发送", "fn", "CH_RUN", "suggested", "Enter"),
            Map("id", "newline", "name", "强制换行", "desc", "插入新行", "fn", "CH_RUN", "suggested", "^Enter"),
            Map("id", "new_chat", "name", "新建对话", "desc", "清空并开始", "fn", "CH_RUN", "suggested", "^n"),
            Map("id", "clear_input", "name", "清空输入框", "desc", "删除当前内容", "fn", "CH_RUN", "suggested", "^Delete"),
            Map("id", "close_tab", "name", "关闭标签页", "desc", "关闭当前 Tab", "fn", "CH_RUN", "suggested", "^w"),
            Map("id", "exit_ai", "name", "退出隐藏", "desc", "收起 AI 抽屉", "fn", "CH_RUN", "suggested", "Escape")
        ]),
        Map("id", "ai_switch", "name", "🔄 切换", "commands", [
            Map("id", "tab1", "name", "切换至 图标1", "desc", "快速跳转界面", "fn", "CH_RUN", "suggested", "^1"),
            Map("id", "tab2", "name", "切换至 图标2", "desc", "快速跳转界面", "fn", "CH_RUN", "suggested", "^2"),
            Map("id", "tab3", "name", "切换至 图标3", "desc", "快速跳转界面", "fn", "CH_RUN", "suggested", "^3"),
            Map("id", "tab4", "name", "切换至 图标4", "desc", "快速跳转界面", "fn", "CH_RUN", "suggested", "^4"),
            Map("id", "tab5", "name", "切换至 图标5", "desc", "快速跳转界面", "fn", "CH_RUN", "suggested", "^5"),
            Map("id", "tab6", "name", "切换至 图标6", "desc", "快速跳转界面", "fn", "CH_RUN", "suggested", "^6"),
            Map("id", "tab7", "name", "切换至 图标7", "desc", "快速跳转界面", "fn", "CH_RUN", "suggested", "^7"),
            Map("id", "tab8", "name", "切换至 图标8", "desc", "快速跳转界面", "fn", "CH_RUN", "suggested", "^8")
        ]),
        Map("id", "ai_prompts", "name", "💡 提示词", "commands", [
            Map("id", "ai_exp", "name", "AI 解释", "desc", "解析选中文段", "fn", "CH_RUN"),
            Map("id", "ai_opt", "name", "AI 优化", "desc", "润色内容逻辑", "fn", "CH_RUN"),
            Map("id", "ai_ref", "name", "AI 重构", "desc", "代码结构改写", "fn", "CH_RUN"),
            Map("id", "ai_act", "name", "快捷动作", "desc", "执行预设脚本", "fn", "CH_RUN")
        ]),
        Map("id", "search", "name", "🔍 搜索中心", "commands", [
            Map("id", "ch_q", "name", "引擎切换 / AI", "desc", "CapsLock+Q：切换到 AI 引擎分类", "fn", "CH_RUN", "suggested", "q"),
            Map("id", "ch_w", "name", "引擎切换 / CLI", "desc", "CapsLock+W：切换到 CLI 引擎分类", "fn", "CH_RUN", "suggested", "w"),
            Map("id", "ch_e", "name", "引擎切换 / 学术", "desc", "CapsLock+E：切换到学术引擎分类", "fn", "CH_RUN", "suggested", "e"),
            Map("id", "ch_r", "name", "引擎切换 / 百度", "desc", "CapsLock+R：切换到百度引擎分类", "fn", "CH_RUN", "suggested", "r"),
            Map("id", "ch_a", "name", "AI筛选 / DeepSeek", "desc", "CapsLock+A：切换 DeepSeek 筛选", "fn", "CH_RUN", "suggested", "a"),
            Map("id", "ch_s", "name", "AI筛选 / 元宝", "desc", "CapsLock+S：切换元宝筛选", "fn", "CH_RUN", "suggested", "s"),
            Map("id", "ch_d", "name", "AI筛选 / 豆包", "desc", "CapsLock+D：切换豆包筛选", "fn", "CH_RUN", "suggested", "d"),
            Map("id", "ch_z", "name", "结果过滤 / 文本", "desc", "CapsLock+Z：只看文本结果", "fn", "CH_RUN", "suggested", "z"),
            Map("id", "ch_x", "name", "结果过滤 / 剪贴板", "desc", "CapsLock+X：只看剪贴板结果", "fn", "CH_RUN", "suggested", "x"),
            Map("id", "ch_c", "name", "结果过滤 / 提示词", "desc", "CapsLock+C：只看提示词结果", "fn", "CH_RUN", "suggested", "c"),
            Map("id", "ch_v", "name", "结果过滤 / 配置", "desc", "CapsLock+V：只看配置结果", "fn", "CH_RUN", "suggested", "v"),
            Map("id", "ch_f", "name", "搜索中心 / 语音搜索", "desc", "CapsLock+F：打开搜索中心或语音搜索", "fn", "CH_RUN", "suggested", "f"),
            Map("id", "ch_g", "name", "语音搜索面板", "desc", "CapsLock+G：直接启动语音搜索面板", "fn", "CH_RUN", "suggested", "g"),
            Map("id", "sc_activate_search", "name", "激活搜索中心", "desc", "打开并激活搜索中心", "fn", "CH_RUN"),
            Map("id", "sc_cat_ai", "name", "分类 / AI", "desc", "切换到 AI 分类", "fn", "CH_RUN"),
            Map("id", "sc_cat_cli", "name", "分类 / CLI", "desc", "切换到 CLI 分类", "fn", "CH_RUN"),
            Map("id", "sc_cat_academic", "name", "分类 / 学术", "desc", "切换到学术分类", "fn", "CH_RUN"),
            Map("id", "sc_cat_baidu", "name", "分类 / 百度", "desc", "切换到百度分类", "fn", "CH_RUN"),
            Map("id", "sc_cat_image", "name", "分类 / 图片", "desc", "切换到图片分类", "fn", "CH_RUN"),
            Map("id", "sc_cat_audio", "name", "分类 / 音频", "desc", "切换到音频分类", "fn", "CH_RUN"),
            Map("id", "sc_cat_video", "name", "分类 / 视频", "desc", "切换到视频分类", "fn", "CH_RUN"),
            Map("id", "sc_cat_book", "name", "分类 / 图书", "desc", "切换到图书分类", "fn", "CH_RUN"),
            Map("id", "sc_cat_price", "name", "分类 / 比价", "desc", "切换到比价分类", "fn", "CH_RUN"),
            Map("id", "sc_cat_medical", "name", "分类 / 医疗", "desc", "切换到医疗分类", "fn", "CH_RUN"),
            Map("id", "sc_cat_cloud", "name", "分类 / 网盘", "desc", "切换到网盘分类", "fn", "CH_RUN"),
            Map("id", "sc_eng_deepseek", "name", "引擎 / DeepSeek", "desc", "切换 DeepSeek 选中状态", "fn", "CH_RUN"),
            Map("id", "sc_eng_yuanbao", "name", "引擎 / 元宝", "desc", "切换元宝选中状态", "fn", "CH_RUN"),
            Map("id", "sc_eng_doubao", "name", "引擎 / 豆包", "desc", "切换豆包选中状态", "fn", "CH_RUN"),
            Map("id", "sc_eng_zhipu", "name", "引擎 / 智谱", "desc", "切换智谱选中状态", "fn", "CH_RUN"),
            Map("id", "sc_eng_mita", "name", "引擎 / 秘塔", "desc", "切换秘塔选中状态", "fn", "CH_RUN"),
            Map("id", "sc_eng_wenxin", "name", "引擎 / 文心一言", "desc", "切换文心一言选中状态", "fn", "CH_RUN"),
            Map("id", "sc_eng_qianwen", "name", "引擎 / 千问", "desc", "切换千问选中状态", "fn", "CH_RUN"),
            Map("id", "sc_eng_kimi", "name", "引擎 / Kimi", "desc", "切换 Kimi 选中状态", "fn", "CH_RUN"),
            Map("id", "sc_eng_perplexity", "name", "引擎 / Perplexity", "desc", "切换 Perplexity 选中状态", "fn", "CH_RUN"),
            Map("id", "sc_eng_copilot", "name", "引擎 / Copilot", "desc", "切换 Copilot 选中状态", "fn", "CH_RUN"),
            Map("id", "sc_eng_chatgpt", "name", "引擎 / ChatGPT", "desc", "切换 ChatGPT 选中状态", "fn", "CH_RUN"),
            Map("id", "sc_eng_grok", "name", "引擎 / Grok", "desc", "切换 Grok 选中状态", "fn", "CH_RUN"),
            Map("id", "sc_eng_you", "name", "引擎 / You", "desc", "切换 You 选中状态", "fn", "CH_RUN"),
            Map("id", "sc_eng_claude", "name", "引擎 / Claude", "desc", "切换 Claude 选中状态", "fn", "CH_RUN"),
            Map("id", "sc_eng_monica", "name", "引擎 / Monica", "desc", "切换 Monica 选中状态", "fn", "CH_RUN"),
            Map("id", "sc_eng_webpilot", "name", "引擎 / WebPilot", "desc", "切换 WebPilot 选中状态", "fn", "CH_RUN"),
            Map("id", "sc_eng_wepilot", "name", "引擎 / wepilot", "desc", "切换 wepilot 选中状态（兼容别名）", "fn", "CH_RUN"),
            Map("id", "sc_filter_text", "name", "过滤 / 文本", "desc", "只看文本结果", "fn", "CH_RUN"),
            Map("id", "sc_filter_clipboard", "name", "过滤 / 剪贴板", "desc", "只看剪贴板结果", "fn", "CH_RUN"),
            Map("id", "sc_filter_prompt", "name", "过滤 / 提示词", "desc", "只看提示词结果", "fn", "CH_RUN"),
            Map("id", "sc_filter_config", "name", "过滤 / 配置", "desc", "只看配置结果", "fn", "CH_RUN"),
            Map("id", "sc_filter_hotkey", "name", "过滤 / 快捷键", "desc", "只看快捷键结果", "fn", "CH_RUN"),
            Map("id", "sc_filter_function", "name", "过滤 / 功能", "desc", "只看功能结果", "fn", "CH_RUN"),
            Map("id", "qa_global_search", "name", "全局搜索", "desc", "Cursor: Ctrl+Shift+F", "fn", "CH_RUN"),
            Map("id", "qa_browser", "name", "简单浏览器", "desc", "Cursor: Ctrl+Shift+B", "fn", "CH_RUN")
        ]),
        Map("id", "clipboard", "name", "📋 剪贴板", "commands", [
            Map("id", "ch_c", "name", "连续复制", "desc", "CapsLock+C：连续复制选区", "fn", "CH_RUN", "suggested", "c"),
            Map("id", "ch_v", "name", "合并粘贴", "desc", "CapsLock+V：合并并粘贴已复制内容", "fn", "CH_RUN", "suggested", "v"),
            Map("id", "ch_x", "name", "剪贴板管理", "desc", "CapsLock+X：打开剪贴板管理面板", "fn", "CH_RUN", "suggested", "x"),
            Map("id", "cp_search", "name", "搜索", "desc", "Ctrl+Enter：立即执行搜索", "fn", "CH_RUN", "suggested", "^Enter"),
            Map("id", "cp_clear_search", "name", "清空搜索框", "desc", "Ctrl+Backspace：清空搜索框", "fn", "CH_RUN", "suggested", "^Backspace"),
            Map("id", "cp_show_shortcuts", "name", "快捷键展示", "desc", "Ctrl+K：打开快捷键面板", "fn", "CH_RUN", "suggested", "^k"),
            Map("id", "qa_copy", "name", "快捷动作 / 连续复制", "desc", "执行 Quick Action: Copy", "fn", "CH_RUN"),
            Map("id", "qa_paste", "name", "快捷动作 / 合并粘贴", "desc", "执行 Quick Action: Paste", "fn", "CH_RUN"),
            Map("id", "qa_clipboard", "name", "快捷动作 / 剪贴板管理", "desc", "执行 Quick Action: Clipboard", "fn", "CH_RUN")
        ]),
        Map("id", "prompts", "name", "💡 提示词", "commands", [
            Map("id", "ch_b", "name", "Prompt / 批量入口", "desc", "CapsLock+B：Prompt Quick-Pad 或批量操作入口", "fn", "CH_RUN", "suggested", "b"),
            Map("id", "pqp_capture", "name", "选区快速采集", "desc", "执行 Prompt Quick-Pad 的选区采集动作", "fn", "CH_RUN"),
            Map("id", "qa_batch", "name", "快捷动作 / 批量操作", "desc", "执行 Quick Action: Batch", "fn", "CH_RUN")
        ]),
        Map("id", "scratchpad", "name", "📝 草稿本", "commands", [
            Map("id", "ch_f", "name", "草稿本 / 搜索", "desc", "CapsLock+F：在 HubCapsule 中执行搜索", "fn", "CH_RUN", "suggested", "f"),
            Map("id", "ch_a", "name", "草稿本 / AI", "desc", "CapsLock+A：在 HubCapsule 中执行 AI 动作", "fn", "CH_RUN", "suggested", "a"),
            Map("id", "ch_backspace", "name", "草稿本 / 清空", "desc", "CapsLock+Backspace：清空 HubCapsule 内容", "fn", "CH_RUN", "suggested", "Backspace"),
            Map("id", "ch_g", "name", "草稿本 / 关闭", "desc", "CapsLock+G：关闭 HubCapsule 面板", "fn", "CH_RUN", "suggested", "g"),
            Map("id", "ch_c", "name", "草稿本 / 触发模式Caps", "desc", "CapsLock+C：切到 CapsLock 触发模式", "fn", "CH_RUN", "suggested", "c"),
            Map("id", "ch_x", "name", "草稿本 / 触发模式双击", "desc", "CapsLock+X：切到双击 Ctrl+C 触发模式", "fn", "CH_RUN", "suggested", "x"),
            Map("id", "ch_v", "name", "草稿本 / 复制图片预览", "desc", "CapsLock+V：复制当前图片预览", "fn", "CH_RUN", "suggested", "v"),
            Map("id", "qa_split", "name", "快捷动作 / 分割代码", "desc", "执行 Quick Action: Split", "fn", "CH_RUN"),
            Map("id", "ch_1", "name", "快捷槽位 1", "desc", "CapsLock+1：选中草稿本第 1 条文本", "fn", "CH_RUN", "suggested", "1"),
            Map("id", "ch_2", "name", "快捷槽位 2", "desc", "CapsLock+2：选中草稿本第 2 条文本", "fn", "CH_RUN", "suggested", "2"),
            Map("id", "ch_3", "name", "快捷槽位 3", "desc", "CapsLock+3：选中草稿本第 3 条文本", "fn", "CH_RUN", "suggested", "3"),
            Map("id", "ch_4", "name", "快捷槽位 4", "desc", "CapsLock+4：选中草稿本第 4 条文本", "fn", "CH_RUN", "suggested", "4"),
            Map("id", "ch_5", "name", "快捷槽位 5", "desc", "CapsLock+5：选中草稿本第 5 条文本", "fn", "CH_RUN", "suggested", "5")
        ]),
        Map("id", "screenshot", "name", "📸 智能截图", "commands", [
            Map("id", "ch_t", "name", "截图智能菜单", "desc", "CapsLock+T：截图后弹出智能菜单", "fn", "CH_RUN", "suggested", "t"),
            Map("id", "ch_p", "name", "区域截图粘贴", "desc", "CapsLock+P：区域截图并粘贴到 Cursor", "fn", "CH_RUN", "suggested", "p")
        ]),
        Map("id", "settings", "name", "⚙️ 设置中心", "commands", [
            Map("id", "sys_show_vk", "name", "显示虚拟键盘", "desc", "打开 VK KeyBinder 窗口", "fn", "SHOW_VK"),
            Map("id", "sys_hide_vk", "name", "隐藏虚拟键盘", "desc", "关闭 VK KeyBinder 窗口", "fn", "HIDE_VK"),
            Map("id", "sys_reset_vk", "name", "重置键盘高亮", "desc", "清除虚拟键盘上的高亮状态", "fn", "RESET_VK"),
            Map("id", "win_min", "name", "最小化窗口", "desc", "最小化当前活动窗口", "fn", "WIN_MIN"),
            Map("id", "win_close", "name", "关闭窗口", "desc", "关闭当前活动窗口", "fn", "WIN_CLOSE"),
            Map("id", "qa_config", "name", "快捷动作 / 设置", "desc", "执行 Quick Action: Config", "fn", "CH_RUN"),
            Map("id", "qa_settings", "name", "VS Code 设置", "desc", "Cursor: Ctrl+Shift+J", "fn", "CH_RUN"),
            Map("id", "qa_cursor_settings", "name", "Cursor 设置", "desc", "Cursor: Ctrl+,", "fn", "CH_RUN"),
            Map("id", "qa_explorer", "name", "资源管理器", "desc", "Cursor: Ctrl+Shift+E", "fn", "CH_RUN"),
            Map("id", "qa_source_control", "name", "源代码管理", "desc", "Cursor: Ctrl+Shift+G", "fn", "CH_RUN"),
            Map("id", "qa_extensions", "name", "扩展", "desc", "Cursor: Ctrl+Shift+X", "fn", "CH_RUN"),
            Map("id", "qa_terminal", "name", "终端", "desc", "Cursor: Ctrl+Shift+``", "fn", "CH_RUN"),
            Map("id", "cursor_open", "name", "打开光标面板", "desc", "显示光标助手面板", "fn", "CURSOR_OPEN"),
            Map("id", "cursor_close", "name", "关闭光标面板", "desc", "隐藏光标助手面板", "fn", "CURSOR_CLOSE")
        ]),
        Map("id", "hotkeys", "name", "⌨️ 快捷键", "commands", [
            Map("id", "sys_exit", "name", "退出程序", "desc", "退出 VirtualKeyboard / 宿主脚本", "fn", "EXIT_APP", "suggested", "Escape"),
            Map("id", "ch_q", "name", "打开配置", "desc", "CapsLock+Q：打开设置面板", "fn", "CH_RUN", "suggested", "q"),
            Map("id", "ch_w", "name", "方向上", "desc", "CapsLock+W：发送方向上", "fn", "CH_RUN", "suggested", "w"),
            Map("id", "ch_s", "name", "方向下", "desc", "CapsLock+S：发送方向下", "fn", "CH_RUN", "suggested", "s"),
            Map("id", "ch_a", "name", "方向左", "desc", "CapsLock+A：发送方向左", "fn", "CH_RUN", "suggested", "a"),
            Map("id", "ch_d", "name", "方向右", "desc", "CapsLock+D：发送方向右", "fn", "CH_RUN", "suggested", "d"),
            Map("id", "qa_command_palette", "name", "命令面板", "desc", "Cursor: Ctrl+Shift+P", "fn", "CH_RUN"),
            Map("id", "qa_voice", "name", "快捷动作 / 语音输入", "desc", "执行 Quick Action: Voice", "fn", "CH_RUN"),
            Map("id", "ch_z", "name", "语音输入", "desc", "CapsLock+Z：开始或停止语音输入", "fn", "CH_RUN", "suggested", "z")
        ])
    ]
}

_VK_SyncBuiltinCommands() {
    global g_Commands
    if !(g_Commands is Map)
        g_Commands := Map()
    if !g_Commands.Has("Bindings") || !(g_Commands["Bindings"] is Map)
        g_Commands["Bindings"] := Map()

    catalog := _VK_BuiltinCommandCatalog()
    cmdList := Map()
    cats := []
    suggested := Map()

    for cat in catalog {
        defs := cat["commands"]
        cmdIds := []
        for def in defs {
            cmdId := def["id"]
            cmdIds.Push(cmdId)
            cmdList[cmdId] := Map(
                "name", def["name"],
                "desc", def["desc"],
                "fn", def["fn"]
            )
            if def.Has("suggested") && def["suggested"] != ""
                suggested[cmdId] := def["suggested"]
        }
        cats.Push(Map("id", cat["id"], "name", cat["name"], "commands", cmdIds))
    }

    g_Commands["CommandList"] := cmdList
    g_Commands["Categories"] := cats
    g_Commands["SuggestedBindings"] := suggested
}

_LoadCommands() {
    global g_Commands, g_Bindings, g_InverseBindings, g_JsonPath, g_VK_Embedded

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

    if !(g_Commands is Map)
        return

    _VK_SyncBuiltinCommands()
    ; Sync cursor-native mapping layer (catalog + user_keymap) into runtime bindings.
    try CursorShortcutMapper_SyncUserKeymapToCommands(g_Commands)

    _VK_MigrateBindingsFormatIfNeeded()
    _VK_NormalizeBindingsOverrides()
    _VK_RebuildEffectiveBindings()
    _VK_EnsureDashboardStorage()
    _VK_SyncFloatPinnedFromStorage()
    _VK_RenderGlobalFloatPanel()
    if g_VK_Embedded
        _VK_SyncEmbeddedCapslockHotkeys()
    OutputDebug("[VK] Loaded " . g_Bindings.Count . " binding(s)")
}

; Detect and migrate old Bindings format:
; - Old: Bindings = Map(ahkKey -> cmdId)
; - New: Bindings = Map(cmdId -> ahkKey | "NONE")
_VK_MigrateBindingsFormatIfNeeded() {
    global g_Commands
    if !(g_Commands is Map)
        return
    if !g_Commands.Has("Bindings") || !(g_Commands["Bindings"] is Map) {
        g_Commands["Bindings"] := Map()
        return
    }
    if !g_Commands.Has("CommandList") || !(g_Commands["CommandList"] is Map)
        return

    cmdList := g_Commands["CommandList"]
    b := g_Commands["Bindings"]

    keyIsCmd := 0
    valIsCmd := 0
    sampled := 0
    for k, v in b {
        sampled += 1
        if cmdList.Has(k)
            keyIsCmd += 1
        if cmdList.Has(v)
            valIsCmd += 1
        if sampled >= 20
            break
    }
    ; Heuristic: if values look like cmdId more than keys, it's old format.
    if (valIsCmd > keyIsCmd) {
        newB := Map()
        for ahkKey, cmdId in b {
            if (cmdId = "" || !cmdList.Has(cmdId))
                continue
            newB[cmdId] := ahkKey
        }
        g_Commands["Bindings"] := newB
        OutputDebug("[VK] Migrated Bindings format (ahkKey->cmdId) -> (cmdId->ahkKey)")
    }
}

; Normalize user overrides:
; - Remove overrides that are identical to SuggestedBindings (treat as "never set" so UI shows as suggested).
; - Drop empty-string overrides.
_VK_NormalizeBindingsOverrides() {
    global g_Commands
    if !(g_Commands is Map)
        return
    if !g_Commands.Has("Bindings") || !(g_Commands["Bindings"] is Map)
        return
    if !g_Commands.Has("SuggestedBindings") || !(g_Commands["SuggestedBindings"] is Map)
        return

    b := g_Commands["Bindings"]
    s := g_Commands["SuggestedBindings"]

    toDel := []
    for cmdId, v in b {
        if (v = "NONE")
            continue
        key := Trim(v)
        if (key = "") {
            toDel.Push(cmdId)
            continue
        }
        if s.Has(cmdId) && s[cmdId] = key {
            toDel.Push(cmdId)
            continue
        }
    }
    for cmdId in toDel
        b.Delete(cmdId)
}

; Rebuild effective runtime bindings from overrides + SuggestedBindings.
; Rules:
; - overrides[cmdId] == "NONE": disabled
; - overrides[cmdId] exists and non-empty: user custom
; - overrides[cmdId] missing: fallback to SuggestedBindings[cmdId]
; - Custom wins; suggested only fills when cmdId not in overrides and key not already used.
_VK_RebuildEffectiveBindings(overrides := 0) {
    global g_Commands, g_Bindings, g_InverseBindings
    g_Bindings := Map()
    g_InverseBindings := Map()

    if !(g_Commands is Map)
        return
    if !g_Commands.Has("CommandList") || !(g_Commands["CommandList"] is Map)
        return

    cmdList := g_Commands["CommandList"]
    suggest := (g_Commands.Has("SuggestedBindings") && g_Commands["SuggestedBindings"] is Map) ? g_Commands["SuggestedBindings"] : Map()
    if !(overrides is Map)
        overrides := (g_Commands.Has("Bindings") && g_Commands["Bindings"] is Map) ? g_Commands["Bindings"] : Map()

    used := Map()

    ; Pass 1: user overrides
    for cmdId, v in overrides {
        if !cmdList.Has(cmdId)
            continue
        if (v = "NONE")
            continue
        key := Trim(v)
        if (key = "")
            continue
        if used.Has(key)
            continue
        g_Bindings[key] := cmdId
        g_InverseBindings[cmdId] := key
        used[key] := cmdId
    }

    ; Pass 2: suggested defaults for commands without overrides (and not disabled)
    for cmdId, key in suggest {
        if !cmdList.Has(cmdId)
            continue
        if overrides.Has(cmdId)
            continue
        sk := Trim(key)
        if (sk = "")
            continue
        if used.Has(sk)
            continue
        g_Bindings[sk] := cmdId
        g_InverseBindings[cmdId] := sk
        used[sk] := cmdId
    }
}

; 将 SuggestedBindings 合并进 Bindings（不覆盖用户已有绑定）
; 目的：首次使用时不再只显示 Escape 一项，内置 ch_* 能直接体现为已绑定
_VK_MergeSuggestedBindings() {
    ; Legacy function (kept for backward compatibility of older calls).
    ; Bindings are now stored as cmdId -> (ahkKey|"NONE"), and SuggestedBindings are applied at runtime
    ; by _VK_RebuildEffectiveBindings().
    return
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
    global g_Commands, g_JsonPath, g_VK_Embedded
    if !(g_Commands is Map)
        return
    if !g_Commands.Has("Bindings") || !(g_Commands["Bindings"] is Map)
        g_Commands["Bindings"] := Map()

    json := _SerializeCommands()
    try FileDelete(g_JsonPath)
    try FileAppend(json, g_JsonPath, "UTF-8")
    try CursorShortcutMapper_CompileAndPersist()
    OutputDebug("[VK] Commands.json saved")
    if !g_VK_Embedded
        NotifyScript("CursorHelper", '{"type":"bindingsReloaded"}')
}

_VK_EnsureDashboardStorage() {
    global g_Commands
    if !(g_Commands is Map)
        return

    if !g_Commands.Has("DashboardLayout") || g_Commands["DashboardLayout"] = ""
        g_Commands["DashboardLayout"] := "multi"

    rawCfg := (g_Commands.Has("DashboardConfig") && g_Commands["DashboardConfig"] is Array)
        ? g_Commands["DashboardConfig"]
        : []
    cmdList := (g_Commands.Has("CommandList") && g_Commands["CommandList"] is Map)
        ? g_Commands["CommandList"]
        : 0

    normalized := []
    for item in rawCfg {
        if (item is Map) && item.Has("commandId") {
            cmdId := item["commandId"]
            if (cmdId != "" && (!cmdList || cmdList.Has(cmdId))) {
                normalized.Push(Map(
                    "commandId", cmdId,
                    "sourceAhkKey", item.Has("sourceAhkKey") ? item["sourceAhkKey"] : "",
                    "sourceDisplayKey", item.Has("sourceDisplayKey") ? item["sourceDisplayKey"] : "",
                    "customTitle", item.Has("customTitle") ? item["customTitle"] : "",
                    "customNote", item.Has("customNote") ? item["customNote"] : "",
                    "customShortcut", item.Has("customShortcut") ? item["customShortcut"] : ""
                ))
                continue
            }
        }
        normalized.Push("")
    }
    g_Commands["DashboardConfig"] := normalized

    rawPinned := (g_Commands.Has("DashboardPinned") && g_Commands["DashboardPinned"] is Array)
        ? g_Commands["DashboardPinned"]
        : []
    pinned := []
    seen := Map()
    for cmdId in rawPinned {
        if (cmdId = "")
            continue
        if cmdList && !cmdList.Has(cmdId)
            continue
        if seen.Has(cmdId)
            continue
        seen[cmdId] := true
        pinned.Push(cmdId)
    }
    g_Commands["DashboardPinned"] := pinned
}

_VK_DashboardConfigJson() {
    global g_Commands
    _VK_EnsureDashboardStorage()
    cfg := g_Commands["DashboardConfig"]
    json := "["
    sep := ""
    for item in cfg {
        if (item is Map) && item.Has("commandId") && item["commandId"] != "" {
            json .= sep . '{"commandId":' . _JsonStr(item["commandId"])
                . ',"sourceAhkKey":' . _JsonStr(item.Has("sourceAhkKey") ? item["sourceAhkKey"] : "")
                . ',"sourceDisplayKey":' . _JsonStr(item.Has("sourceDisplayKey") ? item["sourceDisplayKey"] : "")
                . ',"customTitle":' . _JsonStr(item.Has("customTitle") ? item["customTitle"] : "")
                . ',"customNote":' . _JsonStr(item.Has("customNote") ? item["customNote"] : "")
                . ',"customShortcut":' . _JsonStr(item.Has("customShortcut") ? item["customShortcut"] : "") . '}'
        } else {
            json .= sep . "null"
        }
        sep := ","
    }
    json .= "]"
    return json
}

_VK_StoreDashboardFromWeb(msg) {
    global g_Commands
    if !(msg is Map)
        return

    _VK_EnsureDashboardStorage()

    if msg.Has("layout") && msg["layout"] != ""
        g_Commands["DashboardLayout"] := msg["layout"]
    if msg.Has("dashboardLayout") && msg["dashboardLayout"] != ""
        g_Commands["DashboardLayout"] := msg["dashboardLayout"]

    if msg.Has("dashboardConfig") && (msg["dashboardConfig"] is Array) {
        cfg := []
        cmdList := (g_Commands.Has("CommandList") && g_Commands["CommandList"] is Map)
            ? g_Commands["CommandList"]
            : 0
        for item in msg["dashboardConfig"] {
            if (item is Map) && item.Has("commandId") {
                cmdId := item["commandId"]
                if (cmdId != "" && (!cmdList || cmdList.Has(cmdId))) {
                    cfg.Push(Map(
                        "commandId", cmdId,
                        "sourceAhkKey", item.Has("sourceAhkKey") ? item["sourceAhkKey"] : "",
                        "sourceDisplayKey", item.Has("sourceDisplayKey") ? item["sourceDisplayKey"] : "",
                        "customTitle", item.Has("customTitle") ? item["customTitle"] : "",
                        "customNote", item.Has("customNote") ? item["customNote"] : "",
                        "customShortcut", item.Has("customShortcut") ? item["customShortcut"] : ""
                    ))
                    continue
                }
            }
            cfg.Push("")
        }
        g_Commands["DashboardConfig"] := cfg
    }

    _SaveBindings()
}

_VK_DashboardPinnedJson() {
    global g_Commands
    _VK_EnsureDashboardStorage()
    arr := g_Commands["DashboardPinned"]
    json := "["
    sep := ""
    for cmdId in arr {
        json .= sep . _JsonStr(cmdId)
        sep := ","
    }
    json .= "]"
    return json
}

_VK_HasPinnedCommand(cmdId) {
    global g_VK_FloatPinned
    for v in g_VK_FloatPinned {
        if (v = cmdId)
            return true
    }
    return false
}

_VK_SyncFloatPinnedFromStorage() {
    global g_Commands, g_VK_FloatPinned
    _VK_EnsureDashboardStorage()
    g_VK_FloatPinned := []
    for cmdId in g_Commands["DashboardPinned"]
        g_VK_FloatPinned.Push(cmdId)
}

_VK_SaveFloatPinnedToStorage() {
    global g_Commands, g_VK_FloatPinned
    g_Commands["DashboardPinned"] := []
    for cmdId in g_VK_FloatPinned
        g_Commands["DashboardPinned"].Push(cmdId)
    _SaveBindings()
}

_VK_FloatDrag(*) {
    global g_VK_FloatGui
    if !IsObject(g_VK_FloatGui)
        return
    PostMessage(0x00A1, 2, 0, , "ahk_id " . g_VK_FloatGui.Hwnd)
}

_VK_MakeFloatExecFn(cmdId) {
    return (*) => _ExecuteCommand(cmdId)
}

_VK_MakeFloatRemoveFn(cmdId) {
    return (*) => _VK_UnpinCommand(cmdId)
}

_VK_RenderGlobalFloatPanel() {
    global g_VK_FloatGui, g_VK_FloatPinned, g_Commands

    if !(g_VK_FloatPinned is Array) || g_VK_FloatPinned.Length = 0 {
        if IsObject(g_VK_FloatGui)
            try g_VK_FloatGui.Hide()
        return
    }

    if IsObject(g_VK_FloatGui) {
        try g_VK_FloatGui.Destroy()
        g_VK_FloatGui := 0
    }

    g_VK_FloatGui := Gui("+AlwaysOnTop -Caption +ToolWindow +Border", "VK Global Float")
    g_VK_FloatGui.BackColor := "111111"
    g_VK_FloatGui.MarginX := 8
    g_VK_FloatGui.MarginY := 8

    header := g_VK_FloatGui.Add("Text", "x8 y8 w184 h20 cE67E22 BackgroundTrans", "GLOBAL FLOAT")
    header.SetFont("s9 Bold", "Consolas")
    header.OnEvent("Click", _VK_FloatDrag)

    y := 32
    for cmdId in g_VK_FloatPinned {
        if !g_Commands.Has("CommandList") || !g_Commands["CommandList"].Has(cmdId)
            continue
        name := g_Commands["CommandList"][cmdId]["name"]
        btn := g_VK_FloatGui.Add("Button", "x8 y" . y . " w160 h28", name)
        btn.SetFont("s9", "Microsoft YaHei UI")
        btn.OnEvent("Click", _VK_MakeFloatExecFn(cmdId))

        rm := g_VK_FloatGui.Add("Text", "x172 y" . (y + 4) . " w16 h20 Center cFFB680 BackgroundTrans", "x")
        rm.SetFont("s10 Bold", "Consolas")
        rm.OnEvent("Click", _VK_MakeFloatRemoveFn(cmdId))
        y += 32
    }

    sw := SysGet(0)
    x := Max(8, sw - 210)
    g_VK_FloatGui.Show("NoActivate AutoSize x" . x . " y120")
}

_VK_PinCommand(cmdId) {
    global g_Commands, g_VK_FloatPinned
    if (cmdId = "")
        return
    if !g_Commands.Has("CommandList") || !g_Commands["CommandList"].Has(cmdId)
        return
    if _VK_HasPinnedCommand(cmdId)
        return
    g_VK_FloatPinned.Push(cmdId)
    _VK_SaveFloatPinnedToStorage()
    _VK_RenderGlobalFloatPanel()
}

_VK_UnpinCommand(cmdId) {
    global g_VK_FloatPinned
    if !(g_VK_FloatPinned is Array) || g_VK_FloatPinned.Length = 0
        return
    next := []
    for v in g_VK_FloatPinned {
        if (v != cmdId)
            next.Push(v)
    }
    g_VK_FloatPinned := next
    _VK_SaveFloatPinnedToStorage()
    _VK_RenderGlobalFloatPanel()
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
    ; Bindings: cmdId -> ahkKey | "NONE"
    if g_Commands.Has("Bindings") && g_Commands["Bindings"] is Map {
        for cmdId, v in g_Commands["Bindings"] {
            bJson .= sep4 . _JsonStr(cmdId) . ":" . _JsonStr(v)
            sep4 := ","
        }
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

    _VK_EnsureDashboardStorage()
    dashLayoutJson := _JsonStr(g_Commands["DashboardLayout"])
    dashCfgJson := _VK_DashboardConfigJson()
    dashPinnedJson := _VK_DashboardPinnedJson()

    return '{"Categories":' . catJson . ',"CommandList":' . clJson . ',"Bindings":' . bJson
        . ',"SuggestedBindings":' . sbJson
        . ',"DashboardLayout":' . dashLayoutJson
        . ',"DashboardConfig":' . dashCfgJson
        . ',"DashboardPinned":' . dashPinnedJson . '}'
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
    if _VkIsRuntimeHookKey(ahkKey)
        return true
    if g_HotkeyBound.Has(ahkKey)
        _VK_ReleaseBoundHotkey(ahkKey)
    fn := _MakeCmdFn(cmdId)
    try {
        Hotkey(ahkKey, fn, "On")
        g_HotkeyBound[ahkKey] := 1
        OutputDebug("[VK] Bound: " . ahkKey . " -> " . cmdId)
        return true
    } catch as e {
        OutputDebug("[VK] Hotkey error (" . ahkKey . "): " . e.Message)
        VK_SendToWeb('{"type":"bind_error","commandId":' . _JsonStr(cmdId)
            . ',"ahkKey":' . _JsonStr(ahkKey)
            . ',"message":' . _JsonStr(e.Message) . '}')
        return false
    }
}

_MakeCmdFn(cmdId) {
    return (*) => _ExecuteCommand(cmdId)
}

_UnbindKey(ahkKey) {
    global g_HotkeyBound
    if _VkIsRuntimeHookKey(ahkKey)
        return
    hadBound := g_HotkeyBound.Has(ahkKey)
    _VK_ReleaseBoundHotkey(ahkKey)
    if hadBound
        OutputDebug("[VK] Unbound: " . ahkKey)
}

_VK_ReleaseBoundHotkey(ahkKey) {
    global g_HotkeyBound
    if (ahkKey = "" || _VkIsRuntimeHookKey(ahkKey))
        return
    try Hotkey(ahkKey, "Off")
    if g_HotkeyBound.Has(ahkKey)
        g_HotkeyBound.Delete(ahkKey)
}

_ApplyAllBindings() {
    global g_Bindings
    for ahkKey, cmdId in g_Bindings
        _BindKey(ahkKey, cmdId)
    _EnsureDoubleModifierHook()
    _EnsureSequenceHook()
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
    global g_Commands, g_VK_Embedded, g_LastExecutedCmdId
    if !g_Commands.Has("CommandList") || !g_Commands["CommandList"].Has(cmdId) {
        OutputDebug("[VK] Unknown command: " . cmdId)
        return
    }
    executed := false
    fn := g_Commands["CommandList"][cmdId]["fn"]
    switch fn {
        case "EXIT_APP":
            executed := true
            if g_VK_Embedded
                VK_Hide()
            else
                ExitApp()
        case "SHOW_VK":
            VK_Show()
            executed := true
        case "HIDE_VK":
            VK_Hide()
            executed := true
        case "RESET_VK":
            VK_SendToWeb('{"type":"reset"}')
            executed := true
        case "WIN_MIN":
            try WinMinimize("A")
            executed := true
        case "WIN_CLOSE":
            try WinClose("A")
            executed := true
        case "CURSOR_OPEN":
            OutputDebug("[VK] CURSOR_OPEN: hook here")
            executed := true
        case "CURSOR_CLOSE":
            OutputDebug("[VK] CURSOR_CLOSE: hook here")
            executed := true
        case "CH_RUN":
            if g_VK_Embedded {
                ; 实现由 VirtualKeyboardExecCmd.ahk（CursorHelper）或 VirtualKeyboard.ahk 内 stub 提供；勿用 Func("…")（未定义时会抛 TargetError）
                VK_ExecCursorHelperCmd(cmdId)
                executed := true
            } else if !NotifyScript("CursorHelper", '{"type":"vkExec","cmdId":"' . cmdId . '"}')
                OutputDebug("[VK] CH_RUN " . cmdId . " — CursorHelper 未运行或未处理 vkExec")
            else
                executed := true
        case "PT_RUN":
            _VkRunPromptTemplate(cmdId)
            executed := true
        default:
            OutputDebug("[VK] Unhandled fn: " . fn)
    }
    if executed {
        g_LastExecutedCmdId := cmdId
        _VK_PushQuickBindState()
    }
}

_VK_PushCandUnique(arr, v) {
    if v = ""
        return
    for x in arr {
        if (x = v)
            return
    }
    arr.Push(v)
}

; 与 g_Bindings 键名对齐：尝试多种写法（Esc/Escape、分号名等）
_VK_BindingLookupCandidates(physKey) {
    c := []
    _VK_PushCandUnique(c, physKey)
    if (StrLen(physKey) = 1)
        _VK_PushCandUnique(c, StrLower(physKey))
    lk := StrLower(physKey)
    switch lk {
        case "esc":
            _VK_PushCandUnique(c, "Escape")
            _VK_PushCandUnique(c, "Esc")
        case "escape":
            _VK_PushCandUnique(c, "Esc")
            _VK_PushCandUnique(c, "Escape")
        case "semicolon":
            _VK_PushCandUnique(c, ";")
        case ";":
            _VK_PushCandUnique(c, "Semicolon")
        case "slash":
            _VK_PushCandUnique(c, "/")
        case "/":
            _VK_PushCandUnique(c, "Slash")
    }
    return c
}

; 供 VirtualKeyboard_HandleKey、VK_NoteLastChFromCapsLockKey 共用
VK_LookupBindingCmdForPhys(physKey) {
    global g_Bindings
    for cand in _VK_BindingLookupCandidates(physKey) {
        if g_Bindings.Has(cand)
            return g_Bindings[cand]
    }
    return ""
}

; 搜索中心 CapsLock+第二键：g_Bindings 上 q/a/z 等往往指向 ch_*（如打开设置），与内置「搜索中心」说明不一致。
; 若用户已为该键绑定任意 sc_* 则优先；否则回退到与内置搜索类说明一致的 sc_*（def 表为宿主内建 CH_RUN，不依赖 CommandList 是否同步）。
VK_SearchCenterResolveCapsChordCmd(physKey) {
    global g_Commands
    k := StrLower(Trim(String(physKey)))
    if (k = "")
        return ""
    cmdId := VK_LookupBindingCmdForPhys(k)
    if (cmdId != "" && SubStr(cmdId, 1, 3) = "sc_")
        return cmdId
    static def := Map(
        "q", "sc_cat_ai",
        "w", "sc_cat_cli",
        "e", "sc_cat_academic",
        "r", "sc_cat_baidu",
        "a", "sc_eng_deepseek",
        "s", "sc_eng_yuanbao",
        "d", "sc_eng_doubao",
        "z", "sc_filter_text",
        "x", "sc_filter_clipboard",
        "c", "sc_filter_prompt",
        "v", "sc_filter_config"
    )
    if !def.Has(k)
        return ""
    sc := def[k]
    ; 内建 def 与 VirtualKeyboardExecCmd 中 sc_* 分支一致；若 CommandList 异常缺失，仍返回 sc 以便 VK_ExecCursorHelperCmd 执行
    if (g_Commands is Map) && g_Commands.Has("CommandList") {
        cl := g_Commands["CommandList"]
        if (cl is Map) && !cl.Has(sc)
            OutputDebug("[VK] SC chord: CommandList missing " . sc . " (fallback still used)")
    }
    return sc
}

; 嵌入 CursorHelper：若当前物理键在 g_Bindings 中有命令则执行并返回 true（截断宿主默认）
VirtualKeyboard_HandleKey(physKey) {
    global g_VK_Embedded
    if !g_VK_Embedded || physKey = ""
        return false
    cmdId := VK_LookupBindingCmdForPhys(physKey)
    if cmdId = ""
        return false
    _ExecuteCommand(cmdId)
    return true
}

_VkCapsLockHotIfCb(*) {
    return GetCapsLockState()
}

_VkCursorWinHotIfCb(*) {
    global FloatingToolbarGUI
    if WinActive("ahk_exe Cursor.exe")
        return true
    ; Niuma Chat 输入发生在 FloatingToolbar 的 WebView2 中，也要允许 VK 自定义组合键生效
    try {
        if (IsSet(FloatingToolbarGUI) && IsObject(FloatingToolbarGUI) && FloatingToolbarGUI.Hwnd) {
            if WinActive("ahk_id " . FloatingToolbarGUI.Hwnd)
                return true
        }
    }
    return false
}

; 宿主 #HotIf GetCapsLockState() 下已静态定义的键，避免与动态 Hotkey 重复 variant
_VK_IsHostStaticCapsHotkeyKey(ahkKey) {
    if ahkKey = ""
        return true
    if _VkIsRuntimeHookKey(ahkKey)
        return true
    if (InStr(ahkKey, "^") || InStr(ahkKey, "!") || InStr(ahkKey, "+"))
        return true
    static norm := Map(
        "c", 1, "v", 1, "x", 1, "e", 1, "r", 1, "o", 1, "q", 1, "z", 1, "t", 1, "f", 1, "g", 1, "b", 1,
        "w", 1, "s", 1, "a", 1, "d", 1, "p", 1,
        "1", 1, "2", 1, "3", 1, "4", 1, "5", 1
    )
    k := StrLower(ahkKey)
    if (k = "esc" || k = "escape")
        return true
    if norm.Has(k)
        return true
    return false
}

_VK_UnregisterCapsLockDispatchHotkeys() {
    global g_VK_CapsLockDynHotkeys
    for hk in g_VK_CapsLockDynHotkeys {
        try Hotkey(hk, "Off")
        catch as e
            OutputDebug("[VK] CapsLock dyn off " . hk . ": " . e.Message)
    }
    g_VK_CapsLockDynHotkeys := []
}

_VK_UnregisterEmbeddedScopedHotkeys() {
    global g_VK_EmbeddedScopedHotkeys
    for hk in g_VK_EmbeddedScopedHotkeys {
        try Hotkey(hk, "Off")
        catch as e
            OutputDebug("[VK] Embedded scoped off " . hk . ": " . e.Message)
    }
    g_VK_EmbeddedScopedHotkeys := []
}

_VK_IsEmbeddedScopedCommand(cmdId) {
    if (cmdId = "")
        return false
    ; Cursor 原生命令（来自映射目录）
    if CursorShortcutMapper_IsCursorVkCommand(cmdId)
        return true
    ; 牛马 AI 专用命令：允许在嵌入模式下注册 Ctrl/组合键
    static allow := Map(
        "send", 1, "newline", 1, "new_chat", 1, "clear_input", 1, "close_tab", 1, "exit_ai", 1,
        "tab1", 1, "tab2", 1, "tab3", 1, "tab4", 1, "tab5", 1, "tab6", 1, "tab7", 1, "tab8", 1,
        "ai_exp", 1, "ai_opt", 1, "ai_ref", 1, "ai_act", 1
    )
    return allow.Has(cmdId)
}

_VK_RegisterEmbeddedScopedHotkeys() {
    global g_VK_Embedded, g_Bindings, g_VK_EmbeddedScopedHotkeys
    _VK_UnregisterEmbeddedScopedHotkeys()
    if !g_VK_Embedded
        return

    try {
        HotIf(_VkCursorWinHotIfCb)
        for ahkKey, cmdId in g_Bindings {
            if _VkIsRuntimeHookKey(ahkKey)
                continue
            if !_VK_IsEmbeddedScopedCommand(cmdId)
                continue
            ; Scoped mapping is for user-defined combo keys; avoid stealing plain typing keys.
            if !(InStr(ahkKey, "^") || InStr(ahkKey, "!") || InStr(ahkKey, "+") || InStr(ahkKey, "#"))
                continue
            try {
                Hotkey(ahkKey, VkEmbeddedScopedHotkeyHandler, "On")
                g_VK_EmbeddedScopedHotkeys.Push(ahkKey)
            } catch as e
                OutputDebug("[VK] Embedded scoped on " . ahkKey . ": " . e.Message)
        }
    } finally {
        HotIf()
    }
}

VkEmbeddedScopedHotkeyHandler(*) {
    th := A_ThisHotkey
    if th = ""
        return
    VirtualKeyboard_HandleKey(th)
}

_VK_RegisterCapsLockDispatchHotkeys() {
    global g_VK_Embedded, g_Bindings, g_VK_CapsLockDynHotkeys
    if !g_VK_Embedded {
        _VK_UnregisterCapsLockDispatchHotkeys()
        return
    }
    _VK_UnregisterCapsLockDispatchHotkeys()
    try {
        HotIf(_VkCapsLockHotIfCb)
        for ahkKey, cmdId in g_Bindings {
            if _VK_IsHostStaticCapsHotkeyKey(ahkKey)
                continue
            try {
                Hotkey(ahkKey, VkDynCapsLockHandler, "On")
                g_VK_CapsLockDynHotkeys.Push(ahkKey)
            } catch as e
                OutputDebug("[VK] CapsLock dyn on " . ahkKey . ": " . e.Message)
        }
    } finally {
        HotIf()
    }
}

VkDynCapsLockHandler(*) {
    if VirtualKeyboard_HandleKey(A_ThisHotkey)
        return
    th := A_ThisHotkey
    if (StrLen(th) = 1) {
        try SendText(th)
        catch as e
            OutputDebug("[VK] VkDynCapsLockHandler passthrough: " . e.Message)
    } else
        OutputDebug("[VK] VkDynCapsLockHandler: unhandled " . th)
}

_OnWV2Created(ctrl) {
    global g_VK_WV2, g_VK_Ctrl, g_VK_ExpectAppLocalNavigationResult, g_VK_TriedDiskAfterAppLocalFail

    g_VK_Ctrl := ctrl
    g_VK_WV2 := ctrl.CoreWebView2
    g_VK_ExpectAppLocalNavigationResult := false
    g_VK_TriedDiskAfterAppLocalFail := false

    try g_VK_Ctrl.DefaultBackgroundColor := 0xFF0A0A0A
    try g_VK_Ctrl.IsVisible := true

    _ApplyWV2Bounds()

    s := g_VK_WV2.Settings
    s.AreDefaultContextMenusEnabled := false
    s.IsStatusBarEnabled := false
    s.AreDevToolsEnabled := true
    ; 避免 Alt 与浏览器快捷键/菜单栏逻辑抢焦点，否则虚拟键上 Alt 双击常收不到 dblclick
    try s.AreBrowserAcceleratorKeysEnabled := false

    g_VK_WV2.add_WebMessageReceived(_OnWebMessage)
    try g_VK_WV2.add_NavigationCompleted(_VK_OnNavigationCompleted)

    htmlPath := A_ScriptDir "\VirtualKeyboard.html"
    try ApplyUnifiedWebViewAssets(g_VK_WV2)
    if FileExist(htmlPath)
        _VK_NavigateMainHtml(htmlPath)
    else
        g_VK_WV2.NavigateToString(_FallbackHtml())
}

_VK_OnNavigationCompleted(sender, args) {
    global g_VK_ExpectAppLocalNavigationResult, g_VK_TriedDiskAfterAppLocalFail
    try ok := args.IsSuccess
    catch as e
        ok := true
    if ok {
        g_VK_ExpectAppLocalNavigationResult := false
        ; WebView2：宿主曾隐藏时导航完成后可能仍黑屏，需刷新合成（与 ClipboardPanel 一致）
        if _VK_HostWindowVisible()
            _VK_RefreshWebViewComposition()
        return
    }
    htmlPath := A_ScriptDir "\VirtualKeyboard.html"
    if g_VK_ExpectAppLocalNavigationResult && !g_VK_TriedDiskAfterAppLocalFail && FileExist(htmlPath) {
        g_VK_ExpectAppLocalNavigationResult := false
        g_VK_TriedDiskAfterAppLocalFail := true
        OutputDebug("[VK] app.local navigation failed (IsSuccess=0), falling back to disk HTML")
        try {
            diskHtml := _VK_ReadVirtualKeyboardHtml(htmlPath)
            if diskHtml != ""
                sender.NavigateToString(diskHtml)
            else
                throw Error("empty disk html")
        } catch as e {
            OutputDebug("[VK] disk fallback failed: " . e.Message)
            try {
                sender.NavigateToString("<!doctype html><html><body style='background:#111;color:#eee;font-family:Segoe UI;padding:16px'>VK 页面加载失败。请重启脚本后重试。</body></html>")
            } catch as e2 {
                OutputDebug("[VK] fallback NavigateToString failed: " . e2.Message)
            }
        }
        return
    }
    g_VK_ExpectAppLocalNavigationResult := false
    try {
        sender.NavigateToString("<!doctype html><html><body style='background:#111;color:#eee;font-family:Segoe UI;padding:16px'>VK 页面加载失败。请重启脚本后重试。</body></html>")
    } catch as e {
        OutputDebug("[VK] fallback NavigateToString failed: " . e.Message)
    }
}

_ApplyWV2Bounds() {
    global g_VK_Gui, g_VK_Ctrl, g_VK_TitleH
    if !g_VK_Ctrl
        return
    cw := 0
    ch := 0
    try g_VK_Gui.GetClientPos(, , &cw, &ch)
    catch
        try WinGetClientPos(, , &cw, &ch, g_VK_Gui.Hwnd)
    ; 隐藏预加载阶段可能拿到 0 尺寸，回退到窗口尺寸兜底
    if (cw <= 0 || ch <= g_VK_TitleH) {
        try WinGetPos(, , &ww, &wh, "ahk_id " . g_VK_Gui.Hwnd)
        if (ww > 0 && wh > 0) {
            cw := ww
            ch := wh
        }
    }
    if (cw <= 0 || ch <= g_VK_TitleH)
        return
    rc := WebView2.RECT()
    rc.left := 0
    rc.top := g_VK_TitleH
    rc.right := cw
    rc.bottom := ch
    g_VK_Ctrl.Bounds := rc
}

; WebView2 已知问题：父窗口在隐藏状态下创建 Controller 时，首次 Show 可能黑屏/不合成。
; 参考: https://github.com/MicrosoftEdge/WebView2Feedback/issues/1077
_VK_RefreshWebViewComposition(*) {
    global g_VK_Ctrl, g_VK_Gui
    if !g_VK_Ctrl || !g_VK_Gui
        return
    try {
        _ApplyWV2Bounds()
        g_VK_Ctrl.NotifyParentWindowPositionChanged()
    } catch as e {
        OutputDebug("[VK] RefreshWebViewComposition: " . e.Message)
    }
}

_VK_HostWindowVisible() {
    global g_VK_Gui
    if !g_VK_Gui
        return false
    return WinExist("ahk_id " . g_VK_Gui.Hwnd) && (WinGetStyle("ahk_id " . g_VK_Gui.Hwnd) & 0x10000000)
}

_VK_DeferredMoveFocus(*) {
    global g_VK_Ctrl
    WebView2_MoveFocusProgrammatic(g_VK_Ctrl)
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
    global g_VK_Ready, g_PendingConflict, g_UseScanCode

    jsonStr := args.WebMessageAsJson
    try {
        msg := Jxon_Load(jsonStr)
    } catch {
        OutputDebug("[VK] JSON parse error: " . jsonStr)
        return
    }
    if !(msg is Map)
        return
    action := msg.Has("type") ? msg["type"] : (msg.Has("action") ? msg["action"] : "")
    if (action = "")
        return

    switch action {
        case "ready":
            g_VK_Ready := true
            OutputDebug("[VK] WebView ready")
            _PushInit()
            _PushModifierState()
            _StartKeyPreviewHook()
            if g_VK_FocusPending
                _VK_RequestFocusInput()

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

        case "reset_single":
            if msg.Has("commandId")
                _DoResetSingle(msg["commandId"])

        case "reset_all":
            _DoResetAll()

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

        case "dashboardAdd", "dashboardMove", "dashboardRemove", "dashboardConfig":
            _VK_StoreDashboardFromWeb(msg)
            OutputDebug("[VK] Dashboard sync: " . action)
        case "dashboardPin":
            if msg.Has("commandId")
                _VK_PinCommand(msg["commandId"])
            OutputDebug("[VK] Dashboard pin: " . (msg.Has("commandId") ? msg["commandId"] : ""))
        case "dashboardUnpin":
            if msg.Has("commandId")
                _VK_UnpinCommand(msg["commandId"])
            OutputDebug("[VK] Dashboard unpin: " . (msg.Has("commandId") ? msg["commandId"] : ""))

        default:
            OutputDebug("[VK] Unknown msg: " . msg["type"])
    }
}

_DoBindKey(cmdId, ahkKey, displayKey) {
    global g_Commands
    if !(g_Commands is Map)
        return false
    if !g_Commands.Has("Bindings") || !(g_Commands["Bindings"] is Map)
        g_Commands["Bindings"] := Map()

    oldOverrides := g_Commands["Bindings"]
    newOverrides := Map()
    for k, v in oldOverrides
        newOverrides[k] := v

    ; Ensure uniqueness among user overrides: steal the key from any other cmd that used it.
    removed := []
    for otherCmd, v in newOverrides {
        if (otherCmd != cmdId && v = ahkKey) {
            newOverrides.Delete(otherCmd)
            removed.Push(otherCmd)
        }
    }
    newOverrides[cmdId] := ahkKey

    if !_VK_ApplyOverrides(newOverrides)
        return false

    escaped := StrReplace(StrReplace(displayKey, "\", "\\"), '"', '\"')
    VK_SendToWeb('{"type":"bindingUpdated","commandId":"' . cmdId
        . '","ahkKey":"' . ahkKey
        . '","displayKey":"' . escaped . '"}')
    for otherCmd in removed {
        VK_SendToWeb('{"type":"bindingUpdated","commandId":"' . otherCmd
            . '","deleted":true}')
    }
    try CursorShortcutMapper_UpdateUserByVkCommand(cmdId, ahkKey, true, true)
    OutputDebug("[VK] bindKey: " . cmdId . " = " . ahkKey)
    return true
}

_DoClearBinding(cmdId) {
    global g_Commands
    if !(g_Commands is Map)
        return
    if !g_Commands.Has("Bindings") || !(g_Commands["Bindings"] is Map)
        g_Commands["Bindings"] := Map()
    oldOverrides := g_Commands["Bindings"]
    newOverrides := Map()
    for k, v in oldOverrides
        newOverrides[k] := v
    newOverrides[cmdId] := "NONE"

    if !_VK_ApplyOverrides(newOverrides)
        return

    VK_SendToWeb('{"type":"bindingUpdated","commandId":"' . cmdId
        . '","ahkKey":"","displayKey":"","explicitNone":true}')
    try CursorShortcutMapper_UpdateUserByVkCommand(cmdId, "", false, true)
    OutputDebug("[VK] clearBinding(NONE): " . cmdId)
}

_DoResetSingle(cmdId) {
    global g_Commands
    if !(g_Commands is Map)
        return
    if !g_Commands.Has("Bindings") || !(g_Commands["Bindings"] is Map)
        g_Commands["Bindings"] := Map()
    oldOverrides := g_Commands["Bindings"]
    if !oldOverrides.Has(cmdId)
        return

    newOverrides := Map()
    for k, v in oldOverrides
        newOverrides[k] := v
    newOverrides.Delete(cmdId)

    if !_VK_ApplyOverrides(newOverrides)
        return

    VK_SendToWeb('{"type":"bindingUpdated","commandId":"' . cmdId . '","deleted":true}')
    try CursorShortcutMapper_UpdateUserByVkCommand(cmdId, "", false, true)
    OutputDebug("[VK] reset_single: " . cmdId)
}

_DoResetAll() {
    newOverrides := Map()
    if !_VK_ApplyOverrides(newOverrides)
        return
    try CursorShortcutMapper_ResetAllUserShortcuts()
    ; Full refresh to make UI consistent after a bulk reset.
    _PushInit()
    OutputDebug("[VK] reset_all")
}

; Apply new overrides with hotkey rebind. If any physical hotkey bind fails, roll back.
_VK_ApplyOverrides(newOverrides) {
    global g_Commands, g_Bindings, g_InverseBindings, g_HotkeyBound, g_VK_Embedded

    if !(g_Commands is Map)
        return false
    if !(newOverrides is Map)
        newOverrides := Map()

    ; Snapshot old runtime bindings
    oldEffective := Map()
    for k, v in g_Bindings
        oldEffective[k] := v
    oldInverse := Map()
    for k, v in g_InverseBindings
        oldInverse[k] := v

    ; Snapshot old overrides (for rollback)
    oldOverrides := (g_Commands.Has("Bindings") && g_Commands["Bindings"] is Map) ? g_Commands["Bindings"] : Map()
    snapOldOverrides := Map()
    for k, v in oldOverrides
        snapOldOverrides[k] := v

    ; Build new effective (do not commit yet)
    _VK_RebuildEffectiveBindings(newOverrides)
    newEffective := Map()
    for k, v in g_Bindings
        newEffective[k] := v
    newInverse := Map()
    for k, v in g_InverseBindings
        newInverse[k] := v

    ; Restore old runtime maps before hotkey ops
    g_Bindings := oldEffective
    g_InverseBindings := oldInverse

    if !g_VK_Embedded {
        ; Before registering new keys, always try to turn off old keys.
        keys := []
        for k, _ in g_HotkeyBound
            keys.Push(k)
        for k in keys
            _VK_ReleaseBoundHotkey(k)

        ok := true
        for ahkKey, cmdId in newEffective {
            if !_BindKey(ahkKey, cmdId) {
                ok := false
                break
            }
        }
        if !ok {
            ; Rollback: unbind newly bound keys, rebind old effective set.
            keys2 := []
            for k, _ in g_HotkeyBound
                keys2.Push(k)
            for k in keys2
                _VK_ReleaseBoundHotkey(k)
            for ahkKey, cmdId in oldEffective
                _BindKey(ahkKey, cmdId)

            ; Restore old overrides + effective maps
            g_Commands["Bindings"] := snapOldOverrides
            _VK_RebuildEffectiveBindings(snapOldOverrides)
            return false
        }
    }

    ; Commit overrides + runtime maps
    g_Commands["Bindings"] := newOverrides
    g_Bindings := newEffective
    g_InverseBindings := newInverse

    if g_VK_Embedded
        _VK_SyncEmbeddedCapslockHotkeys()
    _SaveBindings()
    _EnsureDoubleModifierHook()
    _EnsureSequenceHook()
    return true
}

_VK_ToEmbeddedHotkeyValue(ahkKey, isEsc := false) {
    if (ahkKey = "" || _VkIsRuntimeHookKey(ahkKey))
        return ""
    ; HandleDynamicHotkey 目前只支持无修饰单键；带 ^ ! + 的绑定不映射到 CapsLock+ 变量
    if (InStr(ahkKey, "^") || InStr(ahkKey, "!") || InStr(ahkKey, "+"))
        return ""
    base := ahkKey
    if isEsc {
        if (base = "Escape" || base = "Esc")
            return "Esc"
        return ""
    }
    if (StrLen(base) = 1)
        return StrLower(base)
    return ""
}

_VK_SyncEmbeddedCapslockHotkeys() {
    global g_InverseBindings
    global HotkeyESC, HotkeyC, HotkeyV, HotkeyX, HotkeyE, HotkeyR, HotkeyO, HotkeyQ, HotkeyZ, HotkeyT, HotkeyF, HotkeyP

    escVal := g_InverseBindings.Has("sys_exit") ? _VK_ToEmbeddedHotkeyValue(g_InverseBindings["sys_exit"], true) : ""
    cVal := g_InverseBindings.Has("ch_c") ? _VK_ToEmbeddedHotkeyValue(g_InverseBindings["ch_c"]) : ""
    vVal := g_InverseBindings.Has("ch_v") ? _VK_ToEmbeddedHotkeyValue(g_InverseBindings["ch_v"]) : ""
    xVal := g_InverseBindings.Has("ch_x") ? _VK_ToEmbeddedHotkeyValue(g_InverseBindings["ch_x"]) : ""
    eVal := g_InverseBindings.Has("ch_e") ? _VK_ToEmbeddedHotkeyValue(g_InverseBindings["ch_e"]) : ""
    rVal := g_InverseBindings.Has("ch_r") ? _VK_ToEmbeddedHotkeyValue(g_InverseBindings["ch_r"]) : ""
    oVal := g_InverseBindings.Has("ch_o") ? _VK_ToEmbeddedHotkeyValue(g_InverseBindings["ch_o"]) : ""
    qVal := g_InverseBindings.Has("ch_q") ? _VK_ToEmbeddedHotkeyValue(g_InverseBindings["ch_q"]) : ""
    zVal := g_InverseBindings.Has("ch_z") ? _VK_ToEmbeddedHotkeyValue(g_InverseBindings["ch_z"]) : ""
    tVal := g_InverseBindings.Has("ch_t") ? _VK_ToEmbeddedHotkeyValue(g_InverseBindings["ch_t"]) : ""
    fVal := g_InverseBindings.Has("ch_f") ? _VK_ToEmbeddedHotkeyValue(g_InverseBindings["ch_f"]) : ""
    pVal := g_InverseBindings.Has("ch_p") ? _VK_ToEmbeddedHotkeyValue(g_InverseBindings["ch_p"]) : ""

    HotkeyESC := escVal
    HotkeyC := cVal
    HotkeyV := vVal
    HotkeyX := xVal
    HotkeyE := eVal
    HotkeyR := rVal
    HotkeyO := oVal
    HotkeyQ := qVal
    HotkeyZ := zVal
    HotkeyT := tVal
    HotkeyF := fVal
    HotkeyP := pVal
    _VK_RegisterCapsLockDispatchHotkeys()
    _VK_RegisterEmbeddedScopedHotkeys()
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

_VK_GetCommandName(cmdId) {
    global g_Commands
    if (cmdId = "")
        return ""
    if !g_Commands.Has("CommandList") || !(g_Commands["CommandList"] is Map)
        return cmdId
    cmdList := g_Commands["CommandList"]
    if !cmdList.Has(cmdId)
        return cmdId
    cmd := cmdList[cmdId]
    if (cmd is Map) && cmd.Has("name") && cmd["name"] != ""
        return cmd["name"]
    return cmdId
}

_VK_IsQuickBindAllowedWindow() {
    global g_VK_Gui
    if !g_VK_Gui
        return false
    try {
        if !WinExist("ahk_id " . g_VK_Gui.Hwnd)
            return false
        if !(WinGetStyle("ahk_id " . g_VK_Gui.Hwnd) & 0x10000000)
            return false
        fg := WinExist("A")
        if !fg
            return false
        if (fg = g_VK_Gui.Hwnd)
            return true
        ; 焦点在 WebView2 子 HWND 时，前台不是 Gui 本身，用根窗口比对
        root := DllCall("user32\GetAncestor", "ptr", fg, "uint", 2, "ptr")
        return (root = g_VK_Gui.Hwnd)
    } catch {
        return false
    }
}

_VK_PushQuickBindState() {
    global g_LastExecutedCmdId, g_VK_QuickBindArmed, g_VK_QuickBindConsumed, g_InverseBindings
    cmdId := g_LastExecutedCmdId
    cmdName := _VK_GetCommandName(cmdId)
    escName := StrReplace(StrReplace(cmdName, "\", "\\"), '"', '\"')
    escId := StrReplace(StrReplace(cmdId, "\", "\\"), '"', '\"')
    active := (g_VK_QuickBindArmed && !g_VK_QuickBindConsumed) ? "true" : "false"
    curDisp := ""
    if (cmdId != "" && g_InverseBindings.Has(cmdId))
        curDisp := _AhkKeyToDisplay(g_InverseBindings[cmdId])
    escCur := StrReplace(StrReplace(curDisp, "\", "\\"), '"', '\"')
    VK_SendToWeb('{"type":"quickBindState","lastActionId":"' . escId . '","lastActionName":"' . escName
        . '","quickBindActive":' . active . ',"lastActionCurrentKey":"' . escCur . '"}')
}

_VK_OnQuickBindKeyDown(ih, vk, sc) {
    global g_VK_QuickBindArmed, g_VK_QuickBindConsumed, g_LastExecutedCmdId, g_RecordCtx
    if !g_VK_QuickBindArmed || g_VK_QuickBindConsumed
        return
    if (g_RecordCtx.Has("active") && g_RecordCtx["active"])
        return
    ; 长按 CapsLock 打开 VK 时 CapsLock 一直处于按下；Hook 启动后会立刻收到其 KeyDown。
    ; 若此时已有「上一动作」会误走即时绑定并 VK_Hide，表现为「一闪就关」。
    if (vk = 0x14)
        return
    if !_VK_IsQuickBindAllowedWindow()
        return
    ahkKey := _VkNormalizePressedHotkey(vk, sc)
    if ahkKey = ""
        return
    if (g_LastExecutedCmdId = "") {
        VK_SendToWeb('{"type":"setHud","message":"无可绑定动作：请先触发一个功能"}')
        return
    }
    if !_VK_GetCommandName(g_LastExecutedCmdId)
        return
    displayKey := _ToDisplayKey(ahkKey)
    g_VK_QuickBindConsumed := true
    if !_DoBindKey(g_LastExecutedCmdId, ahkKey, displayKey) {
        g_VK_QuickBindConsumed := false
        return
    }
    cmdName := _VK_GetCommandName(g_LastExecutedCmdId)
    escName := StrReplace(StrReplace(cmdName, "\", "\\"), '"', '\"')
    escDisp := StrReplace(StrReplace(displayKey, "\", "\\"), '"', '\"')
    escCmdId := StrReplace(StrReplace(g_LastExecutedCmdId, "\", "\\"), '"', '\"')
    escAhk := StrReplace(StrReplace(ahkKey, "\", "\\"), '"', '\"')
    VK_SendToWeb('{"type":"bind_success","commandId":"' . escCmdId . '","commandName":"' . escName . '","ahkKey":"' . escAhk . '","displayKey":"' . escDisp . '"}')
    _VK_StopQuickBindHook()
    SetTimer(VK_Hide, -50)
}

_VK_StartQuickBindHook() {
    global g_VK_QuickBindHook, g_VK_QuickBindArmed, g_VK_QuickBindConsumed
    _VK_StopQuickBindHook()
    ih := InputHook("V L0")
    ih.KeyOpt("{All}", "N")
    ih.OnKeyDown := _VK_OnQuickBindKeyDown
    g_VK_QuickBindHook := ih
    g_VK_QuickBindConsumed := false
    g_VK_QuickBindArmed := true
    try ih.Start()
    catch as e {
        g_VK_QuickBindArmed := false
        g_VK_QuickBindHook := 0
        OutputDebug("[VK] quick bind hook start failed: " . e.Message)
    }
    _VK_PushQuickBindState()
}

_VK_StopQuickBindHook() {
    global g_VK_QuickBindHook, g_VK_QuickBindArmed, g_VK_QuickBindConsumed
    if IsObject(g_VK_QuickBindHook) {
        try g_VK_QuickBindHook.Stop()
        g_VK_QuickBindHook := 0
    }
    g_VK_QuickBindArmed := false
    g_VK_QuickBindConsumed := false
}

_VkIsSequenceKey(ahkKey) {
    return (SubStr(ahkKey, 1, 4) = "seq:")
}

_VkIsRuntimeHookKey(ahkKey) {
    return (ahkKey = "^^" || ahkKey = "++" || ahkKey = "!!" || _VkIsSequenceKey(ahkKey))
}

_VkBuildSequenceKey(firstKey, secondKey) {
    return "seq:" . firstKey . "||" . secondKey
}

_VkParseSequenceKey(ahkKey) {
    if !_VkIsSequenceKey(ahkKey)
        return []
    body := SubStr(ahkKey, 5)
    pos := InStr(body, "||")
    if (pos <= 0)
        return []
    return [SubStr(body, 1, pos - 1), SubStr(body, pos + 2)]
}

_EnsureSequenceHook(force := false) {
    global g_Bindings, g_VK_SeqIH, g_VK_SeqLast
    need := false
    for ahkKey, cmdId in g_Bindings {
        if _VkIsSequenceKey(ahkKey) {
            need := true
            break
        }
    }
    if !need {
        _StopSequenceHook()
        return
    }
    if force
        _StopSequenceHook()
    if IsObject(g_VK_SeqIH)
        return
    ih := InputHook("V L0")
    ih.KeyOpt("{All}", "N")
    ih.OnKeyDown := _OnVkSequenceKeyDown
    g_VK_SeqIH := ih
    try ih.Start()
    catch as e
        OutputDebug("[VK] sequence hook start failed: " . e.Message)
    g_VK_SeqLast["key"] := ""
    g_VK_SeqLast["tick"] := 0
    OutputDebug("[VK] sequence hook on")
}

_StopSequenceHook() {
    global g_VK_SeqIH, g_VK_SeqLast
    if IsObject(g_VK_SeqIH) {
        try g_VK_SeqIH.Stop()
        g_VK_SeqIH := 0
        OutputDebug("[VK] sequence hook off")
    }
    g_VK_SeqLast["key"] := ""
    g_VK_SeqLast["tick"] := 0
}

_EnsureDoubleModifierHook(force := false) {
    global g_Bindings, g_VK_DblModIH, g_VK_DblModLast
    need := g_Bindings.Has("^^") || g_Bindings.Has("++") || g_Bindings.Has("!!")
    if !need {
        _StopDoubleModifierHook()
        return
    }
    if force
        _StopDoubleModifierHook()
    if IsObject(g_VK_DblModIH)
        return
    ih := InputHook("V L0")
    ih.KeyOpt("{All}", "N")
    ih.OnKeyUp := _OnVkDblModUp
    g_VK_DblModIH := ih
    try ih.Start()
    catch as e
        OutputDebug("[VK] double modifier hook start failed: " . e.Message)
    g_VK_DblModLast["ctrl"] := 0
    g_VK_DblModLast["shift"] := 0
    g_VK_DblModLast["alt"] := 0
    OutputDebug("[VK] double modifier hook on")
}

_StopDoubleModifierHook() {
    global g_VK_DblModIH, g_VK_DblModLast
    if IsObject(g_VK_DblModIH) {
        try g_VK_DblModIH.Stop()
        g_VK_DblModIH := 0
        OutputDebug("[VK] double modifier hook off")
    }
    g_VK_DblModLast["ctrl"] := 0
    g_VK_DblModLast["shift"] := 0
    g_VK_DblModLast["alt"] := 0
}

_VkModifierGroupFromKeyName(keyName) {
    if keyName = "LControl" || keyName = "RControl" || keyName = "Ctrl"
        || keyName = "LCtrl" || keyName = "RCtrl"
        return "ctrl"
    if keyName = "LShift" || keyName = "RShift" || keyName = "Shift"
        return "shift"
    if keyName = "LAlt" || keyName = "RAlt" || keyName = "Alt"
        return "alt"
    return ""
}

_OnVkDblModUp(ih, vk, sc) {
    global g_Bindings, g_VK_DblModLast, g_VK_DblModIntervalMs, g_UseScanCode, g_RecordCtx
    if g_RecordCtx.Has("active") && g_RecordCtx["active"]
        return
    if g_UseScanCode {
        keyName := _GetKeyFromSC(sc)
        if !keyName
            keyName := GetKeyName(Format("vk{:x}sc{:x}", vk, sc))
    } else {
        keyName := GetKeyName(Format("vk{:x}sc{:x}", vk, sc))
    }
    if keyName = ""
        return
    grp := _VkModifierGroupFromKeyName(keyName)
    if grp = ""
        return
    now := A_TickCount
    prev := g_VK_DblModLast[grp]
    if (prev > 0 && now - prev < g_VK_DblModIntervalMs) {
        g_VK_DblModLast[grp] := 0
        dblKey := grp = "ctrl" ? "^^" : grp = "shift" ? "++" : "!!"
        if g_Bindings.Has(dblKey)
            _ExecuteCommand(g_Bindings[dblKey])
    } else
        g_VK_DblModLast[grp] := now
}

_VkNormalizePressedHotkey(vk, sc) {
    global g_UseScanCode
    if g_UseScanCode {
        keyName := _GetKeyFromSC(sc)
        if !keyName
            keyName := GetKeyName(Format("vk{:x}sc{:x}", vk, sc))
    } else {
        keyName := GetKeyName(Format("vk{:x}sc{:x}", vk, sc))
    }
    if (keyName = "" || _IsModifierOnlyKey(keyName))
        return ""
    isCtrl := GetKeyState("Ctrl", "P")
    isAlt := GetKeyState("Alt", "P")
    isShift := GetKeyState("Shift", "P")
    return _NormalizeToAhkHotkey(keyName, isCtrl, isAlt, isShift)
}

_OnVkSequenceKeyDown(ih, vk, sc) {
    global g_Bindings, g_VK_SeqLast, g_VK_SequenceIntervalMs, g_RecordCtx
    if g_RecordCtx.Has("active") && g_RecordCtx["active"]
        return
    ahkKey := _VkNormalizePressedHotkey(vk, sc)
    if ahkKey = ""
        return
    now := A_TickCount
    prevKey := g_VK_SeqLast["key"]
    prevTick := g_VK_SeqLast["tick"]
    if (prevKey != "" && prevTick > 0 && now - prevTick < g_VK_SequenceIntervalMs) {
        seqKey := _VkBuildSequenceKey(prevKey, ahkKey)
        g_VK_SeqLast["key"] := ""
        g_VK_SeqLast["tick"] := 0
        if g_Bindings.Has(seqKey)
            _ExecuteCommand(g_Bindings[seqKey])
        return
    }
    g_VK_SeqLast["key"] := ahkKey
    g_VK_SeqLast["tick"] := now
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
    global g_RecordHook, g_RecordCtx, g_VK_RecordDblModLast
    global g_RecordPendingKey, g_RecordPendingTick, g_RecordFinalizeToken

    try _EndRecord(false)

    g_RecordCtx["active"] := true
    g_RecordCtx["commandId"] := commandId
    g_VK_RecordDblModLast["ctrl"] := 0
    g_VK_RecordDblModLast["shift"] := 0
    g_VK_RecordDblModLast["alt"] := 0
    g_RecordPendingKey := ""
    g_RecordPendingTick := 0
    g_RecordFinalizeToken += 1

    _StopKeyPreviewHook()

    ih := InputHook("V L0")
    ih.KeyOpt("{All}", "N")
    ih.NotifyNonText := true
    ih.OnKeyDown := _OnRecordKeyDown
    ih.OnKeyUp := _OnRecordKeyUp
    g_RecordHook := ih
    try ih.Start()
    catch as e
        TrayTip("录制钩子启动失败: " . e.Message, "VirtualKeyboard", "Iconx 2")

    VK_SendToWeb('{"type":"recordHint","active":true,"commandId":"' . commandId . '"}')
    OutputDebug("[VK] record start: " . commandId)
}

_OnRecordKeyUp(ih, vk, sc) {
    global g_RecordCtx, g_UseScanCode
    global g_VK_RecordDblModLast, g_VK_DblModIntervalMs
    if !g_RecordCtx["active"]
        return

    if g_UseScanCode {
        keyName := _GetKeyFromSC(sc)
        if !keyName
            keyName := GetKeyName(Format("vk{:x}sc{:x}", vk, sc))
    } else {
        keyName := GetKeyName(Format("vk{:x}sc{:x}", vk, sc))
    }

    if keyName = ""
        return

    if !_IsModifierOnlyKey(keyName)
        return

    grp := _VkModifierGroupFromKeyName(keyName)
    if grp = ""
        return

    now := A_TickCount
    prev := g_VK_RecordDblModLast[grp]
    if (prev > 0 && now - prev < g_VK_DblModIntervalMs) {
        g_VK_RecordDblModLast[grp] := 0
        dbl := grp = "ctrl" ? "^^" : grp = "shift" ? "++" : "!!"
        dblDisp := grp = "ctrl" ? "双按 Ctrl" : grp = "shift" ? "双按 Shift" : "双按 Alt"
        VK_SendToWeb('{"type":"recordPending","displayKey":"' . _VkJsonStr(dblDisp) . '","kind":"dblMod"}')
        _VkFinalizeRecordedHotkey(dbl)
        return
    }
    g_VK_RecordDblModLast[grp] := now
}

_EndRecord(restartPreview := true) {
    global g_RecordHook, g_RecordCtx, g_VK_Ready
    global g_RecordPendingKey, g_RecordPendingTick, g_RecordFinalizeToken
    if IsObject(g_RecordHook) {
        try g_RecordHook.Stop()
    }
    g_RecordHook := 0
    g_RecordCtx["active"] := false
    g_RecordCtx["commandId"] := ""
    g_RecordPendingKey := ""
    g_RecordPendingTick := 0
    g_RecordFinalizeToken += 1
    if restartPreview && g_VK_Ready
        _StartKeyPreviewHook()
}

_OnRecordKeyDown(ih, vk, sc) {
    global g_RecordCtx, g_UseScanCode, g_RecordPendingKey, g_RecordPendingTick
    global g_RecordFinalizeToken, g_VK_RecordDblModLast, g_VK_SequenceIntervalMs
    if !g_RecordCtx["active"]
        return

    if g_UseScanCode {
        keyName := _GetKeyFromSC(sc)
        if !keyName
            keyName := GetKeyName(Format("vk{:x}sc{:x}", vk, sc))
    } else {
        keyName := GetKeyName(Format("vk{:x}sc{:x}", vk, sc))
    }

    if keyName = ""
        return

    if !_IsModifierOnlyKey(keyName) {
        g_VK_RecordDblModLast["ctrl"] := 0
        g_VK_RecordDblModLast["shift"] := 0
        g_VK_RecordDblModLast["alt"] := 0
    } else {
        ; 修饰键按下时不处理，等待 KeyUp；这里只需确保非修饰键清零时间戳
        return
    }

    isCtrl := GetKeyState("Ctrl", "P")
    isAlt := GetKeyState("Alt", "P")
    isShift := GetKeyState("Shift", "P")
    ahkKey := _NormalizeToAhkHotkey(keyName, isCtrl, isAlt, isShift)
    if !ahkKey
        return

    now := A_TickCount
    if (g_RecordPendingKey != "" && g_RecordPendingTick > 0 && now - g_RecordPendingTick < g_VK_SequenceIntervalMs) {
        pendingKey := g_RecordPendingKey
        g_RecordPendingKey := ""
        g_RecordPendingTick := 0
        g_RecordFinalizeToken += 1
        _VkFinalizeRecordedHotkey(_VkBuildSequenceKey(pendingKey, ahkKey))
        return
    }

    g_RecordPendingKey := ahkKey
    g_RecordPendingTick := now
    token := g_RecordFinalizeToken + 1
    g_RecordFinalizeToken := token
    dispWait := _ToDisplayKey(ahkKey)
    VK_SendToWeb('{"type":"recordPending","displayKey":"' . _VkJsonStr(dispWait)
        . '","waitMs":' . g_VK_SequenceIntervalMs . '}')
    SetTimer(_VkMakeRecordFinalizeTimer(token), -g_VK_SequenceIntervalMs)
}

_VkMakeRecordFinalizeTimer(token) {
    return (*) => _VkFinalizePendingRecord(token)
}

_VkFinalizePendingRecord(token) {
    global g_RecordCtx, g_RecordPendingKey, g_RecordPendingTick, g_RecordFinalizeToken
    if (token != g_RecordFinalizeToken)
        return
    if !(g_RecordCtx.Has("active") && g_RecordCtx["active"])
        return
    if (g_RecordPendingKey = "")
        return
    ahkKey := g_RecordPendingKey
    g_RecordPendingKey := ""
    g_RecordPendingTick := 0
    _VkFinalizeRecordedHotkey(ahkKey)
}

_VkFinalizeRecordedHotkey(ahkKey) {
    global g_RecordCtx, g_Bindings, g_Commands, g_PendingConflict
    if !(g_RecordCtx.Has("active") && g_RecordCtx["active"])
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
        || keyName = "LCtrl"
        || keyName = "RCtrl"
        || keyName = "LAlt"
        || keyName = "RAlt"
        || keyName = "LShift"
        || keyName = "RShift"
}

_VkRecordModifierDoubleTap(keyName) {
    global g_VK_RecordDblModLast, g_VK_DblModIntervalMs
    grp := _VkModifierGroupFromKeyName(keyName)
    if grp = ""
        return ""
    now := A_TickCount
    prev := g_VK_RecordDblModLast[grp]
    if (prev > 0 && now - prev < g_VK_DblModIntervalMs) {
        g_VK_RecordDblModLast[grp] := 0
        return grp = "ctrl" ? "^^" : grp = "shift" ? "++" : "!!"
    }
    g_VK_RecordDblModLast[grp] := now
    return ""
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
    global g_Commands, g_InverseBindings, g_LastExecutedCmdId, g_VK_QuickBindArmed, g_VK_QuickBindConsumed, g_VK_IsAdmin, g_VK_AdminWarning, g_VK_Embedded

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
    ; User overrides only (cmdId -> { ahkKey, displayKey, explicitNone? })
    if g_Commands.Has("Bindings") && g_Commands["Bindings"] is Map {
        bMap := g_Commands["Bindings"]
        for cmdId, v in bMap {
            if !cmdList.Has(cmdId)
                continue
            if (v = "NONE") {
                bJson .= sep3 . _JsonStr(cmdId) . ':{"ahkKey":"","displayKey":"","explicitNone":true}'
                sep3 := ","
                continue
            }
            key := Trim(v)
            if (key = "")
                continue
            dk := _AhkKeyToDisplay(key)
            esc := StrReplace(StrReplace(dk, "\", "\\"), '"', '\"')
            bJson .= sep3 . _JsonStr(cmdId) . ':{"ahkKey":' . _JsonStr(key) . ',"displayKey":"' . esc . '"}'
            sep3 := ","
        }
    }
    bJson .= "}"

    lastActionId := _JsonStr(g_LastExecutedCmdId)
    lastActionName := _JsonStr(_VK_GetCommandName(g_LastExecutedCmdId))
    quickBindActive := (g_VK_QuickBindArmed && !g_VK_QuickBindConsumed) ? "true" : "false"
    lacKeyDisp := ""
    if (g_LastExecutedCmdId != "" && g_InverseBindings.Has(g_LastExecutedCmdId))
        lacKeyDisp := _AhkKeyToDisplay(g_InverseBindings[g_LastExecutedCmdId])
    lastActionCurrentKey := _JsonStr(lacKeyDisp)
    _VK_EnsureDashboardStorage()
    dashLayout := _JsonStr(g_Commands["DashboardLayout"])
    dashCfg := _VK_DashboardConfigJson()
    dashPinned := _VK_DashboardPinnedJson()
    adminWarning := _JsonStr(g_VK_AdminWarning)
    isAdmin := g_VK_IsAdmin ? "true" : "false"
    embeddedHost := g_VK_Embedded ? "true" : "false"

    payload := '{"type":"init","categories":' . catJson
        . ',"commands":' . clJson
        . ',"bindings":' . bJson
        . ',"suggestedBindings":' . sbJson
        . ',"lastActionId":' . lastActionId
        . ',"lastActionName":' . lastActionName
        . ',"lastActionCurrentKey":' . lastActionCurrentKey
        . ',"quickBindActive":' . quickBindActive
        . ',"isAdmin":' . isAdmin
        . ',"adminWarning":' . adminWarning
        . ',"embeddedHost":' . embeddedHost
        . ',"dashboardLayout":' . dashLayout
        . ',"dashboardConfig":' . dashCfg
        . ',"dashboardPinned":' . dashPinned . '}'
    VK_SendToWeb(payload)
    OutputDebug("[VK] init pushed")
}

_AhkKeyToDisplay(ahkKey) {
    if _VkIsSequenceKey(ahkKey) {
        parts := _VkParseSequenceKey(ahkKey)
        if (parts.Length >= 2) {
            firstPart := _AhkKeyToDisplay(parts[1])
            secondPart := _AhkKeyToDisplay(parts[2])
            if (parts[1] = parts[2])
                return firstPart . " twice"
            return firstPart . " then " . secondPart
        }
    }
    if (ahkKey = "^^")
        return "Double Ctrl"
    if (ahkKey = "++")
        return "Double Shift"
    if (ahkKey = "!!")
        return "Double Alt"
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

; 供宿主判断 VK 窗口是否已显示（例如托盘「显示键盘」已打开时，长按 CapsLock 松手不应误隐藏）
VK_IsHostVisible() {
    global g_VK_Gui
    if !IsObject(g_VK_Gui)
        return false
    try {
        if !WinExist("ahk_id " . g_VK_Gui.Hwnd)
            return false
        return !!(WinGetStyle("ahk_id " . g_VK_Gui.Hwnd) & 0x10000000)
    } catch as e {
        return false
    }
}

; 标记下一次 VK_Show 是否由「长按 CapsLock」触发（仅该入口开启上一动作即时绑定）
VK_MarkNextShowFromCapsLockHold(enabled := true) {
    global g_VK_NextShowFromCapsLockHold
    g_VK_NextShowFromCapsLockHold := !!enabled
}

VK_Show() {
    global g_VK_Gui, g_VK_Ready, g_VK_LastShown, g_VK_NextShowFromCapsLockHold
    if g_VK_Gui {
        openFromCapsHold := g_VK_NextShowFromCapsLockHold
        g_VK_NextShowFromCapsLockHold := false
        g_VK_Gui.Show("NoActivate")
        try WinMaximize("ahk_id " . g_VK_Gui.Hwnd)
        g_VK_LastShown := A_TickCount
        ; 预加载隐藏态创建时，首次显示需刷新布局与合成层（缓解 WebView2 黑屏）
        _VK_RefreshWebViewComposition()
        SetTimer(_VK_RefreshWebViewComposition, -30)
        SetTimer(_VK_RefreshWebViewComposition, -120)
        SetTimer(_VK_RefreshWebViewComposition, -380)
        _StartKeyPreviewHook()
        ; 仅在「长按 CapsLock 临时调起」时开启上一动作即时绑定，其他入口（托盘/按钮）保持关闭。
        ; 须先于 _PushInit：否则 init 里 quickBindActive 仍为 false，前端不显示即时绑定提示
        if (openFromCapsHold)
            _VK_StartQuickBindHook()
        else
            _VK_StopQuickBindHook()
        ; 某些场景下前端列表状态会丢失，显示时补发一次初始化数据
        if g_VK_Ready
            _PushInit()
        VK_SendToWeb('{"type":"keyPreviewClear"}')
        WMActivateChain_Register(_VK_WM_ACTIVATE)
        WebView2_MoveFocusProgrammatic(g_VK_Ctrl)
        SetTimer(_VK_DeferredMoveFocus, -100)
        _VK_RequestFocusInput()
        ; 不再 WinActivate：会与 Cursor/WebView 抢焦点，触发 WM_ACTIVATE 失活链，导致快捷键设置窗「闪一下就被 _VK_WM_ACTIVATE 关掉」
    }
}

VK_Hide() {
    global g_VK_Gui
    VK_SendToWeb('{"type":"keyPreviewClear"}')
    _StopKeyPreviewHook()
    _VK_StopQuickBindHook()
    WMActivateChain_Unregister(_VK_WM_ACTIVATE)
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
        WebView_QueueJson(g_VK_WV2, jsonStr)
}

_VK_WM_ACTIVATE(wParam, lParam, msg, hwnd) {
    global g_VK_Gui, g_VK_LastShown
    if !g_VK_Gui
        return
    if (hwnd = g_VK_Gui.Hwnd && (wParam & 0xFFFF) = 0) {
        try {
            if IsSet(FloatingToolbar_IsForegroundToolbarOrChild) && FloatingToolbar_IsForegroundToolbarOrChild()
                return
        } catch {
        }
        try {
            if _VK_IsForegroundGlobalFloat()
                return
        } catch {
        }
        ; 显示后一段时间内焦点可能在宿主/子控件间切换，勿误判为「用户点到外面」而立刻隐藏
        if (g_VK_LastShown && (A_TickCount - g_VK_LastShown < 2000))
            return
        SetTimer(VK_Hide, -50)
    }
}

_VK_IsForegroundGlobalFloat() {
    global g_VK_FloatGui
    if !IsObject(g_VK_FloatGui)
        return false
    fg := 0
    try fg := WinGetID("A")
    catch {
        return false
    }
    tb := g_VK_FloatGui.Hwnd
    hw := fg
    Loop 40 {
        if (hw = tb)
            return true
        np := DllCall("user32\GetParent", "Ptr", hw, "Ptr")
        if !np
            break
        hw := np
    }
    return false
}

_VK_RequestFocusInput() {
    global g_VK_WV2, g_VK_Ready, g_VK_FocusPending
    if g_VK_WV2 && g_VK_Ready {
        WebView_QueueJson(g_VK_WV2, '{"type":"focus_input"}')
        g_VK_FocusPending := false
        return
    }
    g_VK_FocusPending := true
}

; 释放当前进程内由 VK 注册的 Hotkey（独立模式全量重绑前调用）。
_VK_ReleaseOldHotkeys() {
    global g_HotkeyBound
    keys := []
    for k, _ in g_HotkeyBound
        keys.Push(k)
    for k in keys
        _VK_ReleaseBoundHotkey(k)
}

; 独立 VirtualKeyboard 保存绑定后通知 CursorHelper：重载 Commands.json 并同步 CapsLock 变量 / 双击修饰键与序列钩子。
VK_HandleBindingsReloaded(*) {
    global g_VK_Embedded, g_VK_Gui, g_VK_Ready, g_Commands, g_Bindings, g_ModState

    _LoadCommands()

    if (!(g_Commands is Map) || !g_Commands.Has("CommandList") || !(g_Commands["CommandList"] is Map)
        || g_Commands["CommandList"].Count = 0)
        OutputDebug("[VK] VK_HandleBindingsReloaded: CommandList 缺失或为空，请检查 Commands.json")
    if g_Bindings.Count = 0
        OutputDebug("[VK] VK_HandleBindingsReloaded: g_Bindings 为空（可能无有效绑定）")

    g_ModState["ctrl"] := GetKeyState("Ctrl", "P")
    g_ModState["alt"] := GetKeyState("Alt", "P")
    g_ModState["shift"] := GetKeyState("Shift", "P")
    if g_VK_Ready
        _PushModifierState()

    if g_VK_Embedded {
        try {
            global CapsLock
            CapsLock := GetKeyState("CapsLock", "P")
        } catch as e {
            OutputDebug("[VK] VK_HandleBindingsReloaded: CapsLock 同步跳过 — " . e.Message)
        }
    }

    if !g_VK_Embedded {
        _VK_ReleaseOldHotkeys()
        _ApplyAllBindings()
    } else {
        _EnsureDoubleModifierHook(true)
        _EnsureSequenceHook(true)
    }

    _PushInit()
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


