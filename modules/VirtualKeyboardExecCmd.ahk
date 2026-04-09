; CursorHelper 命令执行（VirtualKeyboard CH_RUN / WM_COPYDATA vkExec 共用）
; 须在 HandleDynamicHotkey、ExecuteQuickActionByType、ExecuteQuickActionSlot 等定义之后再 #Include

VK_ExecCursorHelperCmd(cmdId) {
    global CapsLock, CapsLock2, BatchHotkey, IsCountdownActive
    global g_LastExecutedCmdId
    global HotkeyESC, HotkeyC, HotkeyV, HotkeyX, HotkeyE, HotkeyR, HotkeyO, HotkeyQ, HotkeyZ, HotkeyT, HotkeyP
    prevCaps := CapsLock
    CapsLock := true
    executed := false
    try {
        switch cmdId {
            ; ==================== 牛马 AI：消息 ====================
            case "send":
                if !VK_NiumaExecScript("(function(){var b=document.getElementById('send'); if(b){ b.click(); return 'ok'; } return 'no-send';})();", true)
                    VK_NiumaControlSend("{Enter}", true)
                executed := true
            case "newline":
                if !VK_NiumaExecScript("(function(){var i=document.getElementById('input'); if(!i) return 'no-input'; var s=i.selectionStart||0,e=i.selectionEnd||0,v=i.value||''; i.value=v.slice(0,s)+'\\n'+v.slice(e); i.selectionStart=i.selectionEnd=s+1; try{i.dispatchEvent(new Event('input',{bubbles:true}));}catch(_){ } return 'ok';})();", true)
                    VK_NiumaControlSend("^{Enter}", true)
                executed := true
            case "new_chat":
                if !VK_NiumaExecScript("(function(){var b=document.querySelector('#sessionTabs .stab-add'); if(b){ b.click(); return 'ok'; } return 'no-add';})();", true)
                    VK_NiumaControlSend("^n", true)
                executed := true
            case "clear_input":
                if !VK_NiumaExecScript("(function(){var i=document.getElementById('input'); if(!i) return 'no-input'; i.value=''; try{i.dispatchEvent(new Event('input',{bubbles:true}));}catch(_){ } return 'ok';})();", true)
                    VK_NiumaControlSend("^{Del}", true)
                executed := true
            case "close_tab":
                if !VK_NiumaExecScript("(function(){var x=document.querySelector('#sessionTabs .stab.active .stab-x'); if(x){ x.click(); return 'ok'; } return 'no-close';})();", true)
                    VK_NiumaControlSend("^w", true)
                executed := true
            case "exit_ai":
                try FloatingToolbarSetChatDrawerState(false)
                VK_NiumaControlSend("{Esc}", false)
                executed := true

            ; ==================== 牛马 AI：切换 ====================
            case "tab1":
                VK_SwitchTab(1)
                executed := true
            case "tab2":
                VK_SwitchTab(2)
                executed := true
            case "tab3":
                VK_SwitchTab(3)
                executed := true
            case "tab4":
                VK_SwitchTab(4)
                executed := true
            case "tab5":
                VK_SwitchTab(5)
                executed := true
            case "tab6":
                VK_SwitchTab(6)
                executed := true
            case "tab7":
                VK_SwitchTab(7)
                executed := true
            case "tab8":
                VK_SwitchTab(8)
                executed := true

            ; ==================== 牛马 AI：提示词 ====================
            case "ai_exp":
                VK_SendPromptByClipboard("请用小白能听懂的话解释下面这段内容：")
                executed := true
            case "ai_opt":
                VK_SendPromptByClipboard("请优化下面内容的表达逻辑，让语句更清楚：")
                executed := true
            case "ai_ref":
                VK_SendPromptByClipboard("请重构下面代码，给出更清晰的结构和实现：")
                executed := true
            case "ai_act":
                VK_SendPromptByClipboard("请根据下面内容给出可执行的下一步动作建议：")
                executed := true

            ; ==================== 搜索中心：选项命令（可自定义绑定） ====================
            case "sc_activate_search":
                ShowSearchCenter()
                executed := true
            case "sc_cat_ai":
                if (IsSearchCenterActive())
                    VK_SearchCenterSetCategory("ai")
                executed := true
            case "sc_cat_cli":
                if (IsSearchCenterActive())
                    VK_SearchCenterSetCategory("cli")
                executed := true
            case "sc_cat_academic":
                if (IsSearchCenterActive())
                    VK_SearchCenterSetCategory("academic")
                executed := true
            case "sc_cat_baidu":
                if (IsSearchCenterActive())
                    VK_SearchCenterSetCategory("baidu")
                executed := true
            case "sc_cat_image":
                if (IsSearchCenterActive())
                    VK_SearchCenterSetCategory("image")
                executed := true
            case "sc_cat_audio":
                if (IsSearchCenterActive())
                    VK_SearchCenterSetCategory("audio")
                executed := true
            case "sc_cat_video":
                if (IsSearchCenterActive())
                    VK_SearchCenterSetCategory("video")
                executed := true
            case "sc_cat_book":
                if (IsSearchCenterActive())
                    VK_SearchCenterSetCategory("book")
                executed := true
            case "sc_cat_price":
                if (IsSearchCenterActive())
                    VK_SearchCenterSetCategory("price")
                executed := true
            case "sc_cat_medical":
                if (IsSearchCenterActive())
                    VK_SearchCenterSetCategory("medical")
                executed := true
            case "sc_cat_cloud":
                if (IsSearchCenterActive())
                    VK_SearchCenterSetCategory("cloud")
                executed := true

            case "sc_eng_deepseek":
                if (IsSearchCenterActive())
                    VK_SearchCenterToggleEngine("deepseek")
                executed := true
            case "sc_eng_yuanbao":
                if (IsSearchCenterActive())
                    VK_SearchCenterToggleEngine("yuanbao")
                executed := true
            case "sc_eng_doubao":
                if (IsSearchCenterActive())
                    VK_SearchCenterToggleEngine("doubao")
                executed := true
            case "sc_eng_zhipu":
                if (IsSearchCenterActive())
                    VK_SearchCenterToggleEngine("zhipu")
                executed := true
            case "sc_eng_mita":
                if (IsSearchCenterActive())
                    VK_SearchCenterToggleEngine("mita")
                executed := true
            case "sc_eng_wenxin":
                if (IsSearchCenterActive())
                    VK_SearchCenterToggleEngine("wenxin")
                executed := true
            case "sc_eng_qianwen":
                if (IsSearchCenterActive())
                    VK_SearchCenterToggleEngine("qianwen")
                executed := true
            case "sc_eng_kimi":
                if (IsSearchCenterActive())
                    VK_SearchCenterToggleEngine("kimi")
                executed := true
            case "sc_eng_perplexity":
                if (IsSearchCenterActive())
                    VK_SearchCenterToggleEngine("perplexity")
                executed := true
            case "sc_eng_copilot":
                if (IsSearchCenterActive())
                    VK_SearchCenterToggleEngine("copilot")
                executed := true
            case "sc_eng_chatgpt":
                if (IsSearchCenterActive())
                    VK_SearchCenterToggleEngine("chatgpt")
                executed := true
            case "sc_eng_grok":
                if (IsSearchCenterActive())
                    VK_SearchCenterToggleEngine("grok")
                executed := true
            case "sc_eng_you":
                if (IsSearchCenterActive())
                    VK_SearchCenterToggleEngine("you")
                executed := true
            case "sc_eng_claude":
                if (IsSearchCenterActive())
                    VK_SearchCenterToggleEngine("claude")
                executed := true
            case "sc_eng_monica":
                if (IsSearchCenterActive())
                    VK_SearchCenterToggleEngine("monica")
                executed := true
            case "sc_eng_webpilot":
                if (IsSearchCenterActive())
                    VK_SearchCenterToggleEngine("webpilot")
                executed := true
            case "sc_eng_wepilot":
                if (IsSearchCenterActive())
                    VK_SearchCenterToggleEngine("webpilot")
                executed := true

            case "sc_filter_text":
                if (IsSearchCenterActive())
                    VK_SearchCenterSetFilter("File")
                executed := true
            case "sc_filter_clipboard":
                if (IsSearchCenterActive())
                    VK_SearchCenterSetFilter("clipboard")
                executed := true
            case "sc_filter_prompt":
                if (IsSearchCenterActive())
                    VK_SearchCenterSetFilter("template")
                executed := true
            case "sc_filter_config":
                if (IsSearchCenterActive())
                    VK_SearchCenterSetFilter("config")
                executed := true
            case "sc_filter_hotkey":
                if (IsSearchCenterActive())
                    VK_SearchCenterSetFilter("hotkey")
                executed := true
            case "sc_filter_function":
                if (IsSearchCenterActive())
                    VK_SearchCenterSetFilter("function")
                executed := true

            case "cp_search":
                if (VK_IsClipboardPanelActive())
                    VK_ClipboardSearchNow()
                executed := true
            case "cp_clear_search":
                if (VK_IsClipboardPanelActive())
                    VK_ClipboardClearSearch()
                executed := true
            case "cp_show_shortcuts":
                if (VK_IsClipboardPanelActive())
                    VK_ClipboardToggleShortcuts()
                executed := true

            case "ch_c":
                if (IsSearchCenterActive()) {
                    VK_SearchCenterSetFilter("template")
                    executed := true
                } else {
                    HandleDynamicHotkey(HotkeyC != "" ? HotkeyC : "c", "C")
                    executed := true
                }
            case "ch_v":
                if (VK_IsClipboardPanelActive()) {
                    VK_ClipboardSetContinuousPaste(true)
                    executed := true
                } else if (IsSearchCenterActive()) {
                    VK_SearchCenterSetFilter("config")
                    executed := true
                } else {
                    HandleDynamicHotkey(HotkeyV != "" ? HotkeyV : "v", "V")
                    executed := true
                }
            case "ch_x":
                if (IsSearchCenterActive()) {
                    VK_SearchCenterSetFilter("clipboard")
                    executed := true
                } else {
                    HandleDynamicHotkey(HotkeyX != "" ? HotkeyX : "x", "X")
                    executed := true
                }
            case "ch_e":
                if (VK_IsClipboardPanelActive()) {
                    VK_ClipboardSetFilter("image")
                    executed := true
                } else if (IsSearchCenterActive()) {
                    VK_SearchCenterSetCategory("academic")
                    executed := true
                } else {
                    HandleDynamicHotkey(HotkeyE != "" ? HotkeyE : "e", "E")
                    executed := true
                }
            case "ch_r":
                if (VK_IsClipboardPanelActive()) {
                    VK_ClipboardSetFilter("clipboard")
                    executed := true
                } else if (IsSearchCenterActive()) {
                    VK_SearchCenterSetCategory("baidu")
                    executed := true
                } else {
                    HandleDynamicHotkey(HotkeyR != "" ? HotkeyR : "r", "R")
                    executed := true
                }
            case "ch_o":
                HandleDynamicHotkey(HotkeyO != "" ? HotkeyO : "o", "O")
                executed := true
            case "ch_q":
                if (VK_IsClipboardPanelActive()) {
                    VK_ClipboardSetFilter("all")
                    executed := true
                } else if (IsSearchCenterActive()) {
                    VK_SearchCenterSetCategory("ai")
                    executed := true
                } else {
                    HandleDynamicHotkey(HotkeyQ != "" ? HotkeyQ : "q", "Q")
                    executed := true
                }
            case "ch_z":
                if (IsSearchCenterActive()) {
                    VK_SearchCenterSetFilter("File")
                    executed := true
                } else {
                    HandleDynamicHotkey(HotkeyZ != "" ? HotkeyZ : "z", "Z")
                    executed := true
                }
            case "ch_t":
                HandleDynamicHotkey(HotkeyT != "" ? HotkeyT : "t", "T")
                executed := true
            case "ch_f":
                if (IsCountdownActive) {
                    ExecuteCountdownAction()
                } else if (IsSearchCenterActive()) {
                    HandleSearchCenterF()
                } else {
                    ShowSearchCenter()
                }
                executed := true
            case "ch_g":
                StartVoiceSearch()
                executed := true
            case "ch_b":
                if (GetPanelVisibleState()) {
                    CapsLock2 := false
                    if StrLower(BatchHotkey) = "b"
                        BatchOperation()
                    else
                        Send("b")
                } else {
                    PromptQuickPad_HandleCapsLockB()
                }
                executed := true
            case "ch_p":
                HandleDynamicHotkey(HotkeyP != "" ? HotkeyP : "p", "P")
                executed := true
            case "ch_w":
                if (VK_IsClipboardPanelActive()) {
                    VK_ClipboardSetFilter("text")
                    executed := true
                } else if (IsSearchCenterActive()) {
                    VK_SearchCenterSetCategory("cli")
                    executed := true
                } else {
                    CapsLock2 := false
                    Send("{Up}")
                    executed := true
                }
            case "ch_s":
                if (VK_IsClipboardPanelActive()) {
                    VK_ClipboardSetFilter("url")
                    executed := true
                } else if (IsSearchCenterActive()) {
                    CapsLock2 := false
                    Send("{Down}")
                    executed := true
                } else {
                    CapsLock2 := false
                    Send("{Down}")
                    executed := true
                }
            case "ch_a":
                if (VK_IsClipboardPanelActive()) {
                    VK_ClipboardSetFilter("code")
                    executed := true
                } else if (IsSearchCenterActive()) {
                    CapsLock2 := false
                    Send("{Left}")
                    executed := true
                } else {
                    CapsLock2 := false
                    Send("{Left}")
                    executed := true
                }
            case "ch_d":
                if (VK_IsClipboardPanelActive()) {
                    VK_ClipboardSetFilter("favorite")
                    executed := true
                } else if (IsSearchCenterActive()) {
                    CapsLock2 := false
                    Send("{Right}")
                    executed := true
                } else {
                    CapsLock2 := false
                    Send("{Right}")
                    executed := true
                }
            case "ch_1":
                ExecuteQuickActionSlot(1)
                executed := true
            case "ch_2":
                ExecuteQuickActionSlot(2)
                executed := true
            case "ch_3":
                ExecuteQuickActionSlot(3)
                executed := true
            case "ch_4":
                ExecuteQuickActionSlot(4)
                executed := true
            case "ch_5":
                ExecuteQuickActionSlot(5)
                executed := true
            case "qa_split":
                ExecuteQuickActionByType("Split")
                executed := true
            case "qa_batch":
                ExecuteQuickActionByType("Batch")
                executed := true
            case "qa_explain":
                ExecuteQuickActionByType("Explain")
                executed := true
            case "qa_refactor":
                ExecuteQuickActionByType("Refactor")
                executed := true
            case "qa_optimize":
                ExecuteQuickActionByType("Optimize")
                executed := true
            case "qa_config":
                ExecuteQuickActionByType("Config")
                executed := true
            case "qa_copy":
                ExecuteQuickActionByType("Copy")
                executed := true
            case "qa_paste":
                ExecuteQuickActionByType("Paste")
                executed := true
            case "qa_clipboard":
                ExecuteQuickActionByType("Clipboard")
                executed := true
            case "qa_voice":
                ExecuteQuickActionByType("Voice")
                executed := true
            case "qa_command_palette":
                ExecuteQuickActionByType("CommandPalette")
                executed := true
            case "qa_terminal":
                ExecuteQuickActionByType("Terminal")
                executed := true
            case "qa_global_search":
                ExecuteQuickActionByType("GlobalSearch")
                executed := true
            case "qa_explorer":
                ExecuteQuickActionByType("Explorer")
                executed := true
            case "qa_source_control":
                ExecuteQuickActionByType("SourceControl")
                executed := true
            case "qa_extensions":
                ExecuteQuickActionByType("Extensions")
                executed := true
            case "qa_browser":
                ExecuteQuickActionByType("Browser")
                executed := true
            case "qa_settings":
                ExecuteQuickActionByType("Settings")
                executed := true
            case "qa_cursor_settings":
                ExecuteQuickActionByType("CursorSettings")
                executed := true
            case "pqp_capture":
                PromptQuickPad_QuickCapture()
                executed := true
            default:
                if (SubStr(cmdId, 1, 3) = "pt_") {
                    runPt := Func("ExecutePromptByTemplateId")
                    if runPt {
                        runPt.Call(SubStr(cmdId, 4))
                        executed := true
                    } else
                        OutputDebug("[VK-Exec] pt_* 需要 CursorHelper")
                } else
                    OutputDebug("[VK-Exec] unknown cmdId: " . cmdId)
        }
        if executed {
            g_LastExecutedCmdId := cmdId
            try _VK_PushQuickBindState()
        }
    } catch as e {
        OutputDebug("[VK-Exec] error: " . e.Message)
    } finally {
        CapsLock := prevCaps
    }
}

VK_SearchCenterPost(payloadJson) {
    if !IsSearchCenterActive()
        return false
    try {
        SCWV_PostJson(payloadJson)
        return true
    } catch as e {
        OutputDebug("[VK-Exec] SearchCenter post failed: " . e.Message)
        return false
    }
}

VK_SearchCenterSetCategory(categoryKey) {
    return VK_SearchCenterPost('{"type":"setCategory","category":"' . categoryKey . '"}')
}

VK_SearchCenterSetFilter(filterType) {
    return VK_SearchCenterPost('{"type":"setFilter","filterType":"' . filterType . '"}')
}

VK_SearchCenterToggleEngine(engineKey) {
    return VK_SearchCenterPost('{"type":"toggleEngine","engine":"' . engineKey . '"}')
}

VK_IsClipboardPanelActive() {
    try return CP_IsForeground()
    catch {
        return false
    }
}

VK_ClipboardPost(payloadJson) {
    if !VK_IsClipboardPanelActive()
        return false
    try {
        CP_SendToWeb(payloadJson)
        return true
    } catch as e {
        OutputDebug("[VK-Exec] Clipboard post failed: " . e.Message)
        return false
    }
}

VK_ClipboardSetFilter(filterType) {
    return VK_ClipboardPost('{"type":"vk_set_filter","filterType":"' . filterType . '"}')
}

VK_ClipboardSearchNow() {
    return VK_ClipboardPost('{"type":"vk_search"}')
}

VK_ClipboardClearSearch() {
    return VK_ClipboardPost('{"type":"vk_clear_search"}')
}

VK_ClipboardSetContinuousPaste(enable := true) {
    return VK_ClipboardPost('{"type":"vk_continuous_paste_on","enabled":' . (enable ? "true" : "false") . '}')
}

VK_ClipboardToggleShortcuts() {
    return VK_ClipboardPost('{"type":"vk_show_shortcuts"}')
}

VK_EnsureNiumaWindow(openDrawer := true) {
    global FloatingToolbarGUI
    try ShowFloatingToolbar()
    if openDrawer {
        try FloatingToolbarSetChatDrawerState(true)
    }
    if !(IsObject(FloatingToolbarGUI) && FloatingToolbarGUI) {
        return 0
    }
    try return FloatingToolbarGUI.Hwnd
    catch {
        return 0
    }
}

VK_NiumaExecScript(js, openDrawer := true) {
    global g_FTB_WV2
    VK_EnsureNiumaWindow(openDrawer)
    if !g_FTB_WV2
        return false
    try {
        g_FTB_WV2.ExecuteScript(js)
        return true
    } catch as e {
        OutputDebug("[VK-Exec] Niuma ExecuteScript failed: " . e.Message)
        return false
    }
}

; 消息类：优先 ControlSend，失败回退 PostMessage（确保非焦点窗口也尽量可执行）
VK_NiumaControlSend(keys, openDrawer := true) {
    hwnd := VK_EnsureNiumaWindow(openDrawer)
    if !hwnd
        return false
    try {
        ControlSend(keys, , "ahk_id " . hwnd)
        return true
    } catch {
    }

    ; 兜底：仅对 Enter / Esc 做 PostMessage，组合键继续依赖 ControlSend
    vk := 0
    if (keys = "{Enter}")
        vk := 0x0D
    else if (keys = "{Esc}")
        vk := 0x1B
    if (vk = 0)
        return false
    try {
        PostMessage(0x0100, vk, 0, , "ahk_id " . hwnd) ; WM_KEYDOWN
        PostMessage(0x0101, vk, 0, , "ahk_id " . hwnd) ; WM_KEYUP
        return true
    } catch {
        return false
    }
}

; 切换类：通过 WebView2.ExecuteScript 调用前端切换逻辑
VK_SwitchTab(n) {
    global g_FTB_WV2
    idx := Integer(n)
    if (idx < 1)
        idx := 1
    if (idx > 8)
        idx := 8

    VK_EnsureNiumaWindow(true)
    if !g_FTB_WV2
        return false

    js := "(function(){var i=" . idx . ";var all=[].slice.call(document.querySelectorAll('#sessionTabs .stab[data-session-id]'));var el=all[i-1];if(el){el.click();return 'ok';}return 'no-tab';})();"
    try {
        g_FTB_WV2.ExecuteScript(js)
        return true
    } catch as e {
        OutputDebug("[VK-Exec] VK_SwitchTab ExecuteScript failed: " . e.Message)
        return false
    }
}

VK_SendPromptByClipboard(prefix) {
    txt := Trim(String(A_Clipboard), " `t`r`n")
    if (txt = "") {
        ; 小白可感知反馈：选中内容后再触发提示词动作
        try TrayTip("未检测到选中文本，请先复制或选中后重试。", "牛马AI", "Icon! 2")
        return false
    }
    payload := prefix . "`n`n" . txt
    try return FloatingToolbar_SendTextToNiumaChat(payload, true, false, true)
    catch as e {
        OutputDebug("[VK-Exec] VK_SendPromptByClipboard failed: " . e.Message)
        return false
    }
}

; 供 CursorHelper 内 CapsLock+ 热键与面板快捷按钮调用：与虚拟键盘「上一动作 / 即时绑定」共用同一变量
VK_NoteLastExecutedId(cmdId) {
    global g_LastExecutedCmdId
    if (cmdId = "")
        return
    g_LastExecutedCmdId := cmdId
    try _VK_PushQuickBindState()
}

VK_NoteLastChFromCapsLockKey(keyLower) {
    global g_VK_Embedded
    if g_VK_Embedded {
        bid := VK_LookupBindingCmdForPhys(keyLower)
        if bid != "" {
            VK_NoteLastExecutedId(bid)
            return
        }
    }
    static m := Map(
        "c", "ch_c", "v", "ch_v", "x", "ch_x", "e", "ch_e", "r", "ch_r",
        "o", "ch_o", "q", "ch_q", "z", "ch_z", "t", "ch_t", "p", "ch_p",
        "w", "ch_w", "s", "ch_s", "a", "ch_a", "d", "ch_d",
        "f", "ch_f", "g", "ch_g", "b", "ch_b",
        "1", "ch_1", "2", "ch_2", "3", "ch_3", "4", "ch_4", "5", "ch_5"
    )
    kl := StrLower(keyLower)
    if m.Has(kl)
        VK_NoteLastExecutedId(m[kl])
}
