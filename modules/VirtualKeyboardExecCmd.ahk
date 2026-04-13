; CursorHelper 命令执行（VirtualKeyboard CH_RUN / WM_COPYDATA vkExec 共用）
; 须在 HandleDynamicHotkey、ExecuteQuickActionByType、ExecuteQuickActionSlot 等定义之后再 #Include
;
; 宿主函数由主脚本在 Include 本文件之前定义。此处用静态 Map 缓存 Func引用再 .Call：
; - 单独打开本文件时 LSP 不会把裸名当成「未赋值局部变量」
; - 与「每次 Func(字符串)」相比，首次进入时一次性绑定，减少异常时机问题

_VK_H(name, args*) {
    static _m := 0
    if (_m = 0) {
        _m := Map()
        for _n in [
            "FloatingToolbarSetChatDrawerState", "ShowSearchCenter", "ShowSearchCenterFromMenu",
            "IsSearchCenterActive", "IsScreenshotEditorActive", "ToggleScreenshotEditorAlwaysOnTop",
            "ExecuteScreenshotOCR", "PasteScreenshotAsText", "SaveScreenshotToFile",
            "ScreenshotEditorSendToAI", "ScreenshotEditorSearchText", "CloseScreenshotEditor",
            "HandleDynamicHotkey", "ExecuteCountdownAction", "HandleSearchCenterF",
            "SelectionSense_OnToolbarSearchClick", "FloatingToolbar_ActivateSearchCenter",
            "FloatingToolbarResetScale", "MinimizeFloatingToolbarToEdge",
            "HideFloatingToolbarFromPopupMenu", "ToggleFloatingToolbarFromMenu",
            "ShowFloatingToolbar", "FloatingToolbar_SendTextToNiumaChat"
        ]
            _m[_n] := Func(_n)
    }
    return _m[name].Call(args*)
}

VK_ExecCursorHelperCmd(cmdId) {
    global CapsLock, CapsLock2, BatchHotkey, IsCountdownActive
    global g_LastExecutedCmdId
    global HotkeyESC, HotkeyC, HotkeyV, HotkeyX, HotkeyE, HotkeyR, HotkeyO, HotkeyQ, HotkeyZ, HotkeyT
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
                try _VK_H("FloatingToolbarSetChatDrawerState", false)
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
                try _VK_H("FloatingToolbar_ActivateSearchCenter")
                catch {
                    _VK_H("ShowSearchCenter")
                }
                executed := true
            case "sc_cat_ai":
                if (_VK_H("IsSearchCenterActive"))
                    VK_SearchCenterSetCategory("ai")
                executed := true
            case "sc_cat_cli":
                if (_VK_H("IsSearchCenterActive"))
                    VK_SearchCenterSetCategory("cli")
                executed := true
            case "sc_cat_academic":
                if (_VK_H("IsSearchCenterActive"))
                    VK_SearchCenterSetCategory("academic")
                executed := true
            case "sc_cat_baidu":
                if (_VK_H("IsSearchCenterActive"))
                    VK_SearchCenterSetCategory("baidu")
                executed := true
            case "sc_cat_image":
                if (_VK_H("IsSearchCenterActive"))
                    VK_SearchCenterSetCategory("image")
                executed := true
            case "sc_cat_audio":
                if (_VK_H("IsSearchCenterActive"))
                    VK_SearchCenterSetCategory("audio")
                executed := true
            case "sc_cat_video":
                if (_VK_H("IsSearchCenterActive"))
                    VK_SearchCenterSetCategory("video")
                executed := true
            case "sc_cat_book":
                if (_VK_H("IsSearchCenterActive"))
                    VK_SearchCenterSetCategory("book")
                executed := true
            case "sc_cat_price":
                if (_VK_H("IsSearchCenterActive"))
                    VK_SearchCenterSetCategory("price")
                executed := true
            case "sc_cat_medical":
                if (_VK_H("IsSearchCenterActive"))
                    VK_SearchCenterSetCategory("medical")
                executed := true
            case "sc_cat_cloud":
                if (_VK_H("IsSearchCenterActive"))
                    VK_SearchCenterSetCategory("cloud")
                executed := true

            case "sc_eng_deepseek":
                if (_VK_H("IsSearchCenterActive"))
                    VK_SearchCenterToggleEngine("deepseek")
                executed := true
            case "sc_eng_yuanbao":
                if (_VK_H("IsSearchCenterActive"))
                    VK_SearchCenterToggleEngine("yuanbao")
                executed := true
            case "sc_eng_doubao":
                if (_VK_H("IsSearchCenterActive"))
                    VK_SearchCenterToggleEngine("doubao")
                executed := true
            case "sc_eng_zhipu":
                if (_VK_H("IsSearchCenterActive"))
                    VK_SearchCenterToggleEngine("zhipu")
                executed := true
            case "sc_eng_mita":
                if (_VK_H("IsSearchCenterActive"))
                    VK_SearchCenterToggleEngine("mita")
                executed := true
            case "sc_eng_wenxin":
                if (_VK_H("IsSearchCenterActive"))
                    VK_SearchCenterToggleEngine("wenxin")
                executed := true
            case "sc_eng_qianwen":
                if (_VK_H("IsSearchCenterActive"))
                    VK_SearchCenterToggleEngine("qianwen")
                executed := true
            case "sc_eng_kimi":
                if (_VK_H("IsSearchCenterActive"))
                    VK_SearchCenterToggleEngine("kimi")
                executed := true
            case "sc_eng_perplexity":
                if (_VK_H("IsSearchCenterActive"))
                    VK_SearchCenterToggleEngine("perplexity")
                executed := true
            case "sc_eng_copilot":
                if (_VK_H("IsSearchCenterActive"))
                    VK_SearchCenterToggleEngine("copilot")
                executed := true
            case "sc_eng_chatgpt":
                if (_VK_H("IsSearchCenterActive"))
                    VK_SearchCenterToggleEngine("chatgpt")
                executed := true
            case "sc_eng_grok":
                if (_VK_H("IsSearchCenterActive"))
                    VK_SearchCenterToggleEngine("grok")
                executed := true
            case "sc_eng_you":
                if (_VK_H("IsSearchCenterActive"))
                    VK_SearchCenterToggleEngine("you")
                executed := true
            case "sc_eng_claude":
                if (_VK_H("IsSearchCenterActive"))
                    VK_SearchCenterToggleEngine("claude")
                executed := true
            case "sc_eng_monica":
                if (_VK_H("IsSearchCenterActive"))
                    VK_SearchCenterToggleEngine("monica")
                executed := true
            case "sc_eng_webpilot":
                if (_VK_H("IsSearchCenterActive"))
                    VK_SearchCenterToggleEngine("webpilot")
                executed := true
            case "sc_eng_wepilot":
                if (_VK_H("IsSearchCenterActive"))
                    VK_SearchCenterToggleEngine("webpilot")
                executed := true

            case "sc_filter_text":
                if (_VK_H("IsSearchCenterActive"))
                    VK_SearchCenterSetFilter("File")
                executed := true
            case "sc_filter_clipboard":
                if (_VK_H("IsSearchCenterActive"))
                    VK_SearchCenterSetFilter("clipboard")
                executed := true
            case "sc_filter_prompt":
                if (_VK_H("IsSearchCenterActive"))
                    VK_SearchCenterSetFilter("template")
                executed := true
            case "sc_filter_config":
                if (_VK_H("IsSearchCenterActive"))
                    VK_SearchCenterSetFilter("config")
                executed := true
            case "sc_filter_hotkey":
                if (_VK_H("IsSearchCenterActive"))
                    VK_SearchCenterSetFilter("hotkey")
                executed := true
            case "sc_filter_function":
                if (_VK_H("IsSearchCenterActive"))
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
            case "ss_pin":
                if (_VK_H("IsScreenshotEditorActive"))
                    _VK_H("ToggleScreenshotEditorAlwaysOnTop")
                executed := true
            case "ss_ocr":
                if (_VK_H("IsScreenshotEditorActive"))
                    _VK_H("ExecuteScreenshotOCR")
                executed := true
            case "ss_text":
                if (_VK_H("IsScreenshotEditorActive"))
                    _VK_H("PasteScreenshotAsText")
                executed := true
            case "ss_save":
                if (_VK_H("IsScreenshotEditorActive"))
                    _VK_H("SaveScreenshotToFile")
                executed := true
            case "ss_ai":
                if (_VK_H("IsScreenshotEditorActive"))
                    _VK_H("ScreenshotEditorSendToAI")
                executed := true
            case "ss_search":
                if (_VK_H("IsScreenshotEditorActive"))
                    _VK_H("ScreenshotEditorSearchText")
                executed := true
            case "ss_close":
                if (_VK_H("IsScreenshotEditorActive"))
                    _VK_H("CloseScreenshotEditor")
                executed := true
            case "ch_backspace":
                if (VK_IsHubCapsuleActive()) {
                    VK_HubCapsuleAction("clear")
                    executed := true
                } else {
                    CapsLock2 := false
                    Send("{Backspace}")
                    executed := true
                }

            case "ch_c":
                if (VK_IsPromptQuickPadActive()) {
                    VK_PromptQuickPadAction("capture_clear")
                    executed := true
                } else if (VK_IsHubCapsuleActive()) {
                    VK_HubCapsuleAction("set_trigger_capslock")
                    executed := true
                } else if (_VK_H("IsSearchCenterActive")) {
                    VK_SearchCenterSetFilter("template")
                    executed := true
                } else {
                    _VK_H("HandleDynamicHotkey",HotkeyC != "" ? HotkeyC : "c", "C")
                    executed := true
                }
            case "ch_v":
                if (VK_IsPromptQuickPadActive()) {
                    VK_PromptQuickPadAction("capture_toggle")
                    executed := true
                } else if (VK_IsHubCapsuleActive()) {
                    VK_HubCapsuleAction("copy_image")
                    executed := true
                } else if (VK_IsClipboardPanelActive()) {
                    VK_ClipboardSetContinuousPaste(true)
                    executed := true
                } else if (_VK_H("IsSearchCenterActive")) {
                    VK_SearchCenterSetFilter("config")
                    executed := true
                } else {
                    _VK_H("HandleDynamicHotkey",HotkeyV != "" ? HotkeyV : "v", "V")
                    executed := true
                }
            case "ch_x":
                if (VK_IsPromptQuickPadActive()) {
                    VK_PromptQuickPadAction("capture_save")
                    executed := true
                } else if (VK_IsHubCapsuleActive()) {
                    VK_HubCapsuleAction("set_trigger_double")
                    executed := true
                } else if (_VK_H("IsSearchCenterActive")) {
                    VK_SearchCenterSetFilter("clipboard")
                    executed := true
                } else {
                    _VK_H("HandleDynamicHotkey",HotkeyX != "" ? HotkeyX : "x", "X")
                    executed := true
                }
            case "ch_e":
                if (VK_IsPromptQuickPadActive()) {
                    VK_PromptQuickPadSetSourceFilter("template")
                    executed := true
                } else if (VK_IsClipboardPanelActive()) {
                    VK_ClipboardSetFilter("image")
                    executed := true
                } else if (_VK_H("IsSearchCenterActive")) {
                    VK_SearchCenterSetCategory("academic")
                    executed := true
                } else {
                    _VK_H("HandleDynamicHotkey",HotkeyE != "" ? HotkeyE : "e", "E")
                    executed := true
                }
            case "ch_r":
                if (VK_IsPromptQuickPadActive()) {
                    VK_PromptQuickPadSetSourceFilter("json")
                    executed := true
                } else if (VK_IsClipboardPanelActive()) {
                    VK_ClipboardSetFilter("clipboard")
                    executed := true
                } else if (_VK_H("IsSearchCenterActive")) {
                    VK_SearchCenterSetCategory("baidu")
                    executed := true
                } else {
                    VK_EnsureNiumaWindow(true)
                    executed := true
                }
            case "ch_o":
                _VK_H("HandleDynamicHotkey",HotkeyO != "" ? HotkeyO : "o", "O")
                executed := true
            case "ch_q":
                if (VK_IsPromptQuickPadActive()) {
                    VK_PromptQuickPadSetSourceFilter("all")
                    executed := true
                } else if (VK_IsClipboardPanelActive()) {
                    VK_ClipboardSetFilter("all")
                    executed := true
                } else if (_VK_H("IsSearchCenterActive")) {
                    VK_SearchCenterSetCategory("ai")
                    executed := true
                } else {
                    _VK_H("HandleDynamicHotkey",HotkeyQ != "" ? HotkeyQ : "q", "Q")
                    executed := true
                }
            case "ch_z":
                if (VK_IsPromptQuickPadActive()) {
                    VK_PromptQuickPadAction("capture_load_selected")
                    executed := true
                } else if (_VK_H("IsSearchCenterActive")) {
                    VK_SearchCenterSetFilter("File")
                    executed := true
                } else {
                    _VK_H("HandleDynamicHotkey",HotkeyZ != "" ? HotkeyZ : "z", "Z")
                    executed := true
                }
            case "ch_t":
                if (VK_IsPromptQuickPadActive()) {
                    VK_PromptQuickPadAction("import")
                    executed := true
                } else {
                    _VK_H("HandleDynamicHotkey",HotkeyT != "" ? HotkeyT : "t", "T")
                    executed := true
                }
            case "ch_f":
                if (VK_IsPromptQuickPadActive()) {
                    VK_PromptQuickPadAction("delete")
                } else if (VK_IsHubCapsuleActive()) {
                    VK_HubCapsuleAction("search")
                } else if (IsCountdownActive) {
                    _VK_H("ExecuteCountdownAction")
                } else if (_VK_H("IsSearchCenterActive")) {
                    _VK_H("HandleSearchCenterF")
                } else {
                    _VK_H("ShowSearchCenter")
                }
                executed := true
            case "ch_g":
                if (VK_IsPromptQuickPadActive())
                    VK_PromptQuickPadAction("close")
                else if (VK_IsHubCapsuleActive())
                    VK_HubCapsuleAction("close")
                else {
                    try VK_Show()
                    catch as e {
                        OutputDebug("[VK-Exec] VK_Show failed: " . e.Message)
                    }
                }
                executed := true
            case "ch_b":
                if (VK_IsPromptQuickPadActive()) {
                    VK_PromptQuickPadAction("toggle_pin")
                } else if (GetPanelVisibleState()) {
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
                if (VK_IsPromptQuickPadActive()) {
                    VK_PromptQuickPadAction("export")
                } else {
                    try PromptQuickPad_OpenCaptureDraft("", true)
                    catch as e {
                        try TrayTip("无法打开提示词采集：`n" . e.Message, "VK", "Iconx 2")
                        catch as _e {
                        }
                    }
                }
                executed := true
            case "ch_w":
                if (VK_IsPromptQuickPadActive()) {
                    VK_PromptQuickPadSetSourceFilter("builtin")
                    executed := true
                } else if (VK_IsClipboardPanelActive()) {
                    VK_ClipboardSetFilter("text")
                    executed := true
                } else if (_VK_H("IsSearchCenterActive")) {
                    VK_SearchCenterSetCategory("cli")
                    executed := true
                } else {
                    CapsLock2 := false
                    Send("{Up}")
                    executed := true
                }
            case "ch_s":
                if (VK_IsPromptQuickPadActive()) {
                    VK_PromptQuickPadAction("edit")
                    executed := true
                } else if (VK_IsClipboardPanelActive()) {
                    VK_ClipboardSetFilter("url")
                    executed := true
                } else if (_VK_H("IsSearchCenterActive")) {
                    CapsLock2 := false
                    Send("{Down}")
                    executed := true
                } else {
                    CapsLock2 := false
                    Send("{Down}")
                    executed := true
                }
            case "ch_a":
                if (VK_IsPromptQuickPadActive()) {
                    VK_PromptQuickPadAction("paste")
                    executed := true
                } else if (VK_IsHubCapsuleActive()) {
                    VK_HubCapsuleAction("ai")
                    executed := true
                } else if (VK_IsClipboardPanelActive()) {
                    VK_ClipboardSetFilter("code")
                    executed := true
                } else if (_VK_H("IsSearchCenterActive")) {
                    CapsLock2 := false
                    Send("{Left}")
                    executed := true
                } else {
                    CapsLock2 := false
                    Send("{Left}")
                    executed := true
                }
            case "ch_d":
                if (VK_IsPromptQuickPadActive()) {
                    VK_PromptQuickPadAction("view")
                    executed := true
                } else if (VK_IsClipboardPanelActive()) {
                    VK_ClipboardSetFilter("favorite")
                    executed := true
                } else if (_VK_H("IsSearchCenterActive")) {
                    CapsLock2 := false
                    Send("{Right}")
                    executed := true
                } else {
                    CapsLock2 := false
                    Send("{Right}")
                    executed := true
                }
            case "ch_1":
                if (VK_IsPromptQuickPadActive())
                    VK_PromptQuickPadAction("json_help")
                else if (VK_IsHubCapsuleActive())
                    VK_HubCapsuleAction("select_slot_1")
                else
                    ExecuteQuickActionSlot(1)
                executed := true
            case "ch_2":
                if (VK_IsPromptQuickPadActive())
                    VK_PromptQuickPadAction("item_save")
                else if (VK_IsHubCapsuleActive())
                    VK_HubCapsuleAction("select_slot_2")
                else
                    ExecuteQuickActionSlot(2)
                executed := true
            case "ch_3":
                if (VK_IsPromptQuickPadActive())
                    VK_PromptQuickPadAction("item_cancel")
                else if (VK_IsHubCapsuleActive())
                    VK_HubCapsuleAction("select_slot_3")
                else
                    ExecuteQuickActionSlot(3)
                executed := true
            case "ch_4":
                if (VK_IsPromptQuickPadActive())
                    VK_PromptQuickPadAction("help_close")
                else if (VK_IsHubCapsuleActive())
                    VK_HubCapsuleAction("select_slot_4")
                else
                    ExecuteQuickActionSlot(4)
                executed := true
            case "ch_5":
                if (VK_IsHubCapsuleActive())
                    VK_HubCapsuleAction("select_slot_5")
                else
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
            case "ftm_reset_scale":
                _VK_H("FloatingToolbarResetScale")
                executed := true
            case "ftm_search_center":
                _VK_H("ShowSearchCenterFromMenu")
                executed := true
            case "ftm_clipboard":
                ShowClipboardFromMenu()
                executed := true
            case "ftm_minimize_to_edge":
                _VK_H("MinimizeFloatingToolbarToEdge")
                executed := true
            case "ftm_exit_app":
                ExitFromMenu()
                executed := true
            case "ftm_hide_toolbar":
                _VK_H("HideFloatingToolbarFromPopupMenu")
                executed := true
            case "ftm_open_config":
                ShowConfigFromMenu()
                executed := true
            case "ftm_toggle_toolbar":
                _VK_H("ToggleFloatingToolbarFromMenu")
                executed := true
            case "ftm_reload_script":
                ReloadScriptFromPopupMenu()
                executed := true
            case "hub_capsule":
                try {
                    SelectionSense_OpenHubCapsuleFromToolbar()
                } catch as err {
                    try TrayTip("无法打开 HubCapsule：`n" . err.Message, "HubCapsule", "Iconx 2")
                    catch as _e {
                    }
                }
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
    return executed
}

VK_SearchCenterPost(payloadJson) {
    if !_VK_H("IsSearchCenterActive")
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

VK_IsPromptQuickPadActive() {
    hwnd := 0
    try hwnd := PromptQuickPad_GetHostHwnd()
    catch {
        hwnd := 0
    }
    if !hwnd
        return false
    try return WinActive("ahk_id " . hwnd) ? true : false
    catch {
        return false
    }
}

VK_PromptQuickPadPost(payloadJson) {
    if !VK_IsPromptQuickPadActive()
        return false
    try {
        if !PromptQuickPad_ShouldUseWebView() || !PQP_IsReady()
            return false
    } catch {
        return false
    }
    try {
        PQP_SendToWeb(payloadJson)
        return true
    } catch as e {
        OutputDebug("[VK-Exec] PromptQuickPad post failed: " . e.Message)
        return false
    }
}

VK_PromptQuickPadSetSourceFilter(filterType) {
    return VK_PromptQuickPadPost('{"type":"vk_set_source_filter","filterType":"' . filterType . '"}')
}

VK_PromptQuickPadAction(actionName) {
    return VK_PromptQuickPadPost('{"type":"vk_action","action":"' . actionName . '"}')
}

VK_IsHubCapsuleActive() {
    global g_SelSense_MenuShowingHub, g_SelSense_MenuGui
    if !g_SelSense_MenuShowingHub
        return false
    hwnd := 0
    try hwnd := (IsObject(g_SelSense_MenuGui) ? g_SelSense_MenuGui.Hwnd : 0)
    catch {
        hwnd := 0
    }
    if !hwnd
        return false
    try return WinActive("ahk_id " . hwnd) ? true : false
    catch {
        return false
    }
}

VK_HubCapsulePost(msgObj) {
    global g_SelSense_MenuWV2, g_SelSense_MenuShowingHub
    if !g_SelSense_MenuShowingHub
        return false
    try {
        if !g_SelSense_MenuWV2
            return false
    } catch {
        return false
    }
    try {
        WebView_QueuePayload(g_SelSense_MenuWV2, msgObj)
        return true
    } catch as e {
        OutputDebug("[VK-Exec] HubCapsule post failed: " . e.Message)
        return false
    }
}

VK_HubCapsuleAction(actionName) {
    return VK_HubCapsulePost(Map("type", "vk_action", "action", String(actionName)))
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
    try _VK_H("ShowFloatingToolbar")
    if openDrawer {
        try _VK_H("FloatingToolbarSetChatDrawerState", true)
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
    try return _VK_H("FloatingToolbar_SendTextToNiumaChat",payload, true, false, true)
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
        "1", "ch_1", "2", "ch_2", "3", "ch_3", "4", "ch_4", "5", "ch_5",
        "backspace", "ch_backspace"
    )
    kl := StrLower(keyLower)
    if m.Has(kl)
        VK_NoteLastExecutedId(m[kl])
}

SC_JoinAllRegExMatches(haystack, pattern) {
    h := String(haystack)
    out := ""
    start := 1
    while RegExMatch(h, pattern, &m, start) {
        out .= m[]
        start := m.Pos + m.Len
    }
    return out
}

; 内容中首条 http(s) URL（用于「复制链接」）；\S 外先用 [^\s]+ 避免引号转义出错，尾部标点由 RTrim 去掉
SC_ExtractFirstHttpUrl(haystack) {
    h := String(haystack)
    if !RegExMatch(h, "i)(https?://[^\s]+)", &m)
        return ""
    return RTrim(m[1], ".,;:!?)'|" . Chr(34))
}

; 优先取存在的本地路径：逐行 → 整段 → 常见 Windows 路径样式
SC_ExtractPathForCopy(Content) {
    c := String(Content)
    Loop Parse, c, "`n", "`r" {
        line := Trim(A_LoopField)
        if (line = "")
            continue
        lineEx := line
        if (StrLen(line) >= 2 && SubStr(line, 1, 1) = '"' && SubStr(line, -1) = '"')
            lineEx := SubStr(line, 2, StrLen(line) - 2)
        if !InStr(lineEx, "`n") && (FileExist(lineEx) || DirExist(lineEx))
            return lineEx
    }
    one := Trim(StrReplace(StrReplace(c, "`r", ""), "`n", ""))
    if (StrLen(one) >= 2 && SubStr(one, 1, 1) = '"' && SubStr(one, -1) = '"')
        one := SubStr(one, 2, StrLen(one) - 2)
    if (one != "" && (FileExist(one) || DirExist(one)))
        return one
    ; 禁止 Windows 路径非法字符；双引号用 Chr(34) 拼接，避免 "" 与 `r`n 在同一字面量里触发解析错误
    ccBad := "\\/:*?" . Chr(34) . "<>|" . "`r`n"
    if RegExMatch(c, "i)([a-z]:\\(?:[^" . ccBad . "]+[\\/])*[^" . ccBad . "]+)", &m)
        return m[1]
    if RegExMatch(c, "i)(\\\\[^\s`r`n]+\\[^\s`r`n]+(?:\\[^\s`r`n]+)*)", &m2) {
        cand := m2[1]
        if (FileExist(cand) || DirExist(cand))
            return cand
    }
    return ""
}

; shell32 ShellExecuteW：返回 >32 为成功（原先用 DllCall("ptr","shell32\...") 会把返回类型写错导致始终失败）
SC_ShellExecuteFileVerb(filePath, verb) {
    p := Trim(String(filePath))
    v := Trim(String(verb))
    if (p = "" || v = "")
        return false
    if !FileExist(p) && !DirExist(p)
        return false
    hr := DllCall("shell32\ShellExecuteW", "ptr", 0, "wstr", v, "wstr", p, "ptr", 0, "ptr", 0, "int", 1, "ptr")
    return (hr > 32)
}

; 若类型标记非文件但 Content 实为存在的本地路径，则按文件处理（属性/打开方式/回收等）
SC_CtxCoerceLocalFilePath(&isFileLike, &path, Content) {
    path := Trim(String(path))
    c := Trim(String(Content))
    if (path = "" && c != "")
        path := c
    if isFileLike || path = ""
        return
    if InStr(path, "`n") || InStr(path, "`r")
        return
    if (FileExist(path) || DirExist(path))
        isFileLike := true
}

; 规范化本地路径（长路径名），便于 explorer / Shell API
SC_NormalizeFsPath(p) {
    s := Trim(String(p))
    if (s = "")
        return ""
    if !FileExist(s) && !DirExist(s)
        return s
    buf := Buffer(520 * 2, 0)
    n := DllCall("kernel32\GetLongPathNameW", "wstr", s, "ptr", buf.Ptr, "uint", 260, "uint")
    if (n > 0 && n < 260)
        return StrGet(buf.Ptr, n, "UTF-16")
    return s
}

; 资源管理器原生：在父文件夹中选中该项（比 /select 命令行更稳）
SC_OpenFolderAndSelectPath(path) {
    p := SC_NormalizeFsPath(path)
    if (p = "" || (!FileExist(p) && !DirExist(p)))
        return false
    hr := DllCall("shell32\SHParseDisplayName", "wstr", p, "ptr", 0, "ptr*", &pidlFull := 0, "uint", 0, "uint*", &attrs := 0, "uint")
    if (hr != 0 || pidlFull = 0)
        return false
    pidlFolder := DllCall("shell32\ILClone", "ptr", pidlFull, "ptr")
    if !pidlFolder {
        DllCall("ole32\CoTaskMemFree", "ptr", pidlFull)
        return false
    }
    if !DllCall("shell32\ILRemoveLastID", "ptr", pidlFolder) {
        DllCall("ole32\CoTaskMemFree", "ptr", pidlFolder)
        DllCall("ole32\CoTaskMemFree", "ptr", pidlFull)
        return false
    }
    last := DllCall("shell32\ILFindLastID", "ptr", pidlFull, "ptr")
    if !last {
        DllCall("ole32\CoTaskMemFree", "ptr", pidlFolder)
        DllCall("ole32\CoTaskMemFree", "ptr", pidlFull)
        return false
    }
    childArr := Buffer(A_PtrSize, 0)
    NumPut("ptr", last, childArr, 0)
    hr2 := DllCall("shell32\SHOpenFolderAndSelectItems", "ptr", pidlFolder, "uint", 1, "ptr", childArr.Ptr, "uint", 0, "uint")
    DllCall("ole32\CoTaskMemFree", "ptr", pidlFolder)
    DllCall("ole32\CoTaskMemFree", "ptr", pidlFull)
    return (hr2 = 0)
}

; 搜索中心 WebView 结果行右键：统一执行入口。
; ctxItem：可选 Map（剪贴板 / Hub / PQP 合成项），键 Title/Content/DataType/OriginalDataType/Source/ClipboardId/HubSegIndex/PromptMergedIndex
SC_ExecuteContextCommand(cmdId, visibleRow := 0, ctxItem := unset) {
    id := Trim(String(cmdId))
    if (id = "")
        return
    if (id = "sc_voice_stop") {
        SC_SAPI_Stop()
        return
    }

    Item := 0
    r := Integer(visibleRow)
    if IsSet(ctxItem) && ctxItem is Map {
        Item := ctxItem
        r := 0
    } else {
        if (r < 1)
            return
        Item := GetSearchCenterResultItemByRow(r)
    }
    if !IsObject(Item)
        return

    if Item is Map {
        Content := Item.Has("Content") ? Item["Content"] : (Item.Has("Title") ? Item["Title"] : "")
        Title := Item.Has("Title") ? Item["Title"] : Content
        DataType := Item.Has("DataType") ? Item["DataType"] : ""
        origDt := Item.Has("OriginalDataType") ? Item["OriginalDataType"] : ""
    } else {
        Content := Item.HasProp("Content") ? Item.Content : Item.Title
        Title := Item.HasProp("Title") ? Item.Title : Content
        DataType := Item.HasProp("DataType") ? Item.DataType : ""
        origDt := Item.HasProp("OriginalDataType") ? Item.OriginalDataType : ""
    }
    isFileLike := (DataType = "file" || DataType = "File" || DataType = "Folder" || origDt = "file")
    path := Trim(String(Content))
    SC_CtxCoerceLocalFilePath(&isFileLike, &path, Content)

    ; 搜索中心暗色子菜单：粘贴到 / 剪贴板类命令（需剪贴板来源 + ClipboardId）
    if (SubStr(id, 1, 8) = "cp_ctx_") {
        clipId := 0
        if Item is Map && Item.Has("Source") && Item["Source"] = "clipboard" && Item.Has("ClipboardId")
            clipId := Integer(Item["ClipboardId"])
        if (clipId < 1) {
            try TrayTip("剪贴板项", "当前结果不是剪贴板条目", "Icon! 2")
            catch {
            }
            return
        }
        switch id {
            case "cp_ctx_pastePlain":
                _CP_DoPastePlain(clipId, false)
            case "cp_ctx_pasteWithNewline":
                _CP_DoPasteWithNewline(clipId, false)
            case "cp_ctx_pastePath":
                _CP_DoPastePath(clipId, false)
            case "cp_ctx_copyToClipboard":
                _CP_DoCopyToClipboard(clipId, false)
            default:
                try TrayTip("剪贴板", "不支持该命令", "Iconi 2")
                catch {
                }
        }
        return
    }

    switch id {
        case "sc_execute":
            if Item is Map && Item.Has("Source") {
                src := String(Item["Source"])
                if (src = "clipboard" && Item.Has("ClipboardId") && Integer(Item["ClipboardId"]) > 0) {
                    _CP_DoPaste(Integer(Item["ClipboardId"]), false)
                    return
                }
                if (src = "hub") {
                    t := Trim(String(Content), " `t`r`n")
                    if (t != "") {
                        try A_Clipboard := t
                        catch {
                        }
                        Sleep(50)
                        try Send("^v")
                        catch {
                        }
                    }
                    return
                }
                if (src = "pqp" && Item.Has("PromptMergedIndex")) {
                    PromptQuickPad_PasteByMergedIndex(Integer(Item["PromptMergedIndex"]))
                    Sleep(50)
                    try Send("^v")
                    catch {
                    }
                    return
                }
                try TrayTip("立即执行", "当前项无法在此面板执行", "Iconi 2")
                catch {
                }
                return
            }
            ; 从搜索中心右键菜单执行：不关闭搜索中心窗口（避免失焦自动 Hide 与操作被打断）
            SC_ActivateSearchResultItem(Item, false, true)
        case "sc_run_as_admin":
            if !isFileLike || !FileExist(path) {
                try TrayTip("仅支持本地 .exe / .bat", path, "Icon! 2")
                catch {
                }
                return
            }
            ext := ""
            SplitPath(path, , , &ext)
            el := StrLower(ext)
            if (el != ".exe" && el != ".bat") {
                try TrayTip("仅支持 .exe / .bat", path, "Icon! 2")
                catch {
                }
                return
            }
            try Run('*RunAs "' . path . '"')
            catch as err {
                try TrayTip("提升运行失败", err.Message, "Iconx 2")
                catch {
                }
            }
        case "sc_open_path":
            if !isFileLike || (!FileExist(path) && !DirExist(path)) {
                try TrayTip("无法打开位置", "非本地文件或文件夹路径", "Icon! 2")
                catch {
                }
                return
            }
            pn := SC_NormalizeFsPath(path)
            if SC_OpenFolderAndSelectPath(pn)
                return
            try {
                Run('explorer.exe /select,"' . pn . '"')
            } catch as err {
                try TrayTip("资源管理器失败", err.Message, "Iconx 2")
                catch {
                }
            }
        case "sc_open_with":
            ; 已从搜索中心右键移除；保留 case 供旧热键/脚本调用
            if !isFileLike || !FileExist(path) {
                try TrayTip("打开方式", "需要存在的本地文件", "Icon! 2")
                catch {
                }
                return
            }
            if SC_ShellExecuteFileVerb(path, "openas")
                return
            sysRoot := EnvGet("SystemRoot")
            if (sysRoot = "")
                sysRoot := A_WinDir
            try {
                Run(Format('"{1}\System32\rundll32.exe" shell32.dll,OpenAs_RunDLL "{2}"', sysRoot, path))
            } catch as err {
                try TrayTip("打开方式失败", err.Message, "Iconx 2")
                catch {
                }
            }
        case "sc_copy":
        case "sc_copy_plain":
            try A_Clipboard := Content
            try TrayTip("已复制", "全文已复制到剪贴板", "Iconi 1")
            catch {
            }
        case "sc_copy_path":
            p := SC_ExtractPathForCopy(Content)
            if (p = "") {
                try TrayTip("未找到路径", "内容中无可用的本地路径", "Icon! 2")
                catch {
                }
                return
            }
            try A_Clipboard := p
            try TrayTip("已复制路径", p, "Iconi 1")
            catch {
            }
        case "sc_copy_url":
            u := SC_ExtractFirstHttpUrl(Content)
            if (u = "") {
                try TrayTip("未找到链接", "", "Icon! 2")
                catch {
                }
                return
            }
            try A_Clipboard := u
            try TrayTip("已复制链接", u, "Iconi 1")
            catch {
            }
        case "sc_copy_link":
            p := SC_ExtractPathForCopy(Content)
            if (p != "") {
                try A_Clipboard := p
            } else {
                u := SC_ExtractFirstHttpUrl(Content)
                if (u != "") {
                    try A_Clipboard := u
                } else {
                    try A_Clipboard := Content
                }
            }
            try TrayTip("已复制", "路径/链接/全文已复制", "Iconi 1")
            catch {
            }
        case "sc_copy_digit":
            d := SC_JoinAllRegExMatches(Content, "\d+")
            if (d = "") {
                try TrayTip("未匹配到数字", "", "Icon! 2")
                catch {
                }
                return
            }
            try A_Clipboard := d
            try TrayTip("已复制数字", d, "Iconi 1")
            catch {
            }
        case "sc_copy_chinese":
            zh := SC_JoinAllRegExMatches(Content, "\p{Han}+")
            if (zh = "") {
                try TrayTip("未匹配到中文", "", "Icon! 2")
                catch {
                }
                return
            }
            try A_Clipboard := zh
            try TrayTip("已复制中文", SubStr(zh, 1, 80), "Iconi 1")
            catch {
            }
        case "sc_copy_md":
            link := Content
            name := Title
            if (DataType = "Link" || RegExMatch(Content, "i)^https?://"))
                md := "[" . name . "](" . link . ")"
            else
                md := "[" . name . "](" . link . ")"
            try A_Clipboard := md
            try TrayTip("已复制 Markdown", md, "Iconi 1")
            catch {
            }
        case "sc_to_draft":
            seg := Trim(String(Content), " `t`r`n")
            if (seg = "")
                return
            try SelectionSense_OpenHubCapsuleFromToolbar(false, seg)
            catch {
            }
            Sleep(280)
            if !VK_HubCapsulePost(Map("type", "draft_collect", "text", seg, "source", "vk_clip_ctx")) {
                try TrayTip("草稿本", "HubCapsule 未就绪，请稍后再试", "Icon! 2")
                catch {
                }
            }
        case "sc_to_prompt":
            try A_Clipboard := Content
            try TrayTip("已复制", "内容已复制，可粘贴到提示词模板", "Iconi 1")
            catch {
            }
        case "sc_to_openclaw":
            t := Trim(String(Content), " `t`r`n")
            if (t = "") {
                return
            }
            try _VK_H("FloatingToolbar_SendTextToNiumaChat",t, true, true, true)
            catch as err {
                try TrayTip("发送失败", err.Message, "Iconx 2")
                catch {
                }
            }
        case "sc_send_desktop":
        case "sc_send_documents":
            if !isFileLike || !FileExist(path) {
                try TrayTip("发送", "仅支持本地文件（非文件夹）", "Iconi 2")
                catch {
                }
                return
            }
            destRoot := EnvGet("USERPROFILE") . (id = "sc_send_desktop" ? "\Desktop" : "\Documents")
            if !DirExist(destRoot) {
                try DirCreate(destRoot)
                catch as _e {
                }
            }
            SplitPath(path, &srcFn)
            dest := destRoot . "\" . srcFn
            if FileExist(dest) {
                SplitPath(path, &nameNoExt, , &ext)
                dest := destRoot . "\" . nameNoExt . " (" . A_Now . ")" . (ext != "" ? "." . ext : "")
            }
            try {
                FileCopy path, dest, false
                try TrayTip("已发送", dest, "Iconi 1")
                catch {
                }
            } catch as err {
                try TrayTip("复制失败", err.Message, "Iconx 2")
                catch {
                }
            }
        case "sc_open_sendto_folder":
            st := EnvGet("APPDATA") . "\Microsoft\Windows\SendTo"
            if !DirExist(st) {
                try TrayTip("发送到", "未找到系统「发送到」目录", "Icon! 2")
                catch {
                }
                return
            }
            try Run('explorer.exe "' . st . '"')
            catch as err {
                try TrayTip("打开失败", err.Message, "Iconx 2")
                catch {
                }
            }
        case "ai_explain_item":
            t := Trim(String(Content), " `t`r`n")
            if (t = "") {
                return
            }
            payload := "请用小白能听懂的话解释下面这段内容：`n`n" . t
            try _VK_H("FloatingToolbar_SendTextToNiumaChat",payload, true, false, true)
            catch as err {
                try TrayTip("牛马 AI", err.Message, "Iconx 2")
                catch {
                }
            }
        case "ai_translate_item":
            t := Trim(String(Content), " `t`r`n")
            if (t = "") {
                return
            }
            payload := "请自动检测语种并将下面内容翻译为另一种常用语言（中文↔英文优先），只输出译文：`n`n" . t
            try _VK_H("FloatingToolbar_SendTextToNiumaChat",payload, true, false, true)
            catch as err {
                try TrayTip("翻译", err.Message, "Iconx 2")
                catch {
                }
            }
        case "ai_prompt_refine":
            t := Trim(String(Content), " `t`r`n")
            clip := Trim(String(A_Clipboard), " `t`r`n")
            payload := "请将「结果项内容」与「剪贴板内容」结合，精炼为一条高质量、可执行的提示词，只输出最终 Prompt：`n`n--- 结果项 ---`n" . t . "`n`n--- 剪贴板 ---`n" . clip
            try _VK_H("FloatingToolbar_SendTextToNiumaChat",payload, true, false, true)
            catch as err {
                try TrayTip("提示词精炼", err.Message, "Iconx 2")
                catch {
                }
            }
        case "sc_pin_item":
            if Item is Map && Item.Has("Source") && String(Item["Source"]) = "clipboard" && Item.Has("ClipboardId") {
                _CP_DoPin(Integer(Item["ClipboardId"]))
                return
            }
            if Item is Map && Item.Has("Source") && String(Item["Source"]) != "" && String(Item["Source"]) != "clipboard" {
                try TrayTip("置顶", "仅剪贴板历史条目支持置顶", "Iconi 2")
                catch {
                }
                return
            }
            SC_SearchCenterTogglePinByItem(Item)
        case "sc_delete_item":
            if Item is Map && Item.Has("Source") {
                src := String(Item["Source"])
                if (src = "clipboard" && Item.Has("ClipboardId")) {
                    _CP_DoDelete(Integer(Item["ClipboardId"]))
                    return
                }
                if (src = "hub" && Item.Has("HubSegIndex")) {
                    global g_SelSense_MenuWV2
                    if g_SelSense_MenuWV2 {
                        try WebView_QueuePayload(g_SelSense_MenuWV2, Map("type", "hub_remove_at", "index", Integer(Item["HubSegIndex"])))
                        catch {
                        }
                    }
                    return
                }
                if (src = "pqp" && Item.Has("PromptMergedIndex")) {
                    PromptQuickPad_DeleteByMergedIndex(Integer(Item["PromptMergedIndex"]))
                    return
                }
            }
            if (r < 1)
                return
            SC_SearchCenterRecycleVisibleRow(r)
        case "sc_recycle_item":
            if Item is Map && Item.Has("Source") && String(Item["Source"]) = "clipboard" {
                if !(isFileLike && FileExist(path)) {
                    try TrayTip("回收", "当前剪贴板项不是可进回收站的本地文件", "Iconi 2")
                    catch {
                    }
                    return
                }
                try FileRecycle(path)
                catch as err {
                    try TrayTip("回收失败", err.Message, "Iconx 2")
                    catch {
                    }
                    return
                }
                if Item.Has("ClipboardId")
                    _CP_DoDelete(Integer(Item["ClipboardId"]))
                return
            }
            if Item is Map && Item.Has("Source") && String(Item["Source"]) = "pqp" {
                try TrayTip("回收", "提示词列表项请使用「删除」或自行管理 prompts.json", "Iconi 2")
                catch {
                }
                return
            }
            if Item is Map && Item.Has("Source") && String(Item["Source"]) = "hub" {
                try TrayTip("回收", "草稿卡片请使用「移除」或清空堆叠", "Iconi 2")
                catch {
                }
                return
            }
            if (r < 1)
                return
            SC_SearchCenterRecycleVisibleRow(r)
        case "sys_empty_recycle":
            SC_SearchCenterEmptyRecycleBin()
        case "sc_voice_speak":
            SC_SAPI_SpeakFromContextItem(Item)
        default:
            return
    }
}
