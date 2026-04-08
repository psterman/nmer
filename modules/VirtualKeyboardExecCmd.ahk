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
            case "ch_c":
                HandleDynamicHotkey(HotkeyC != "" ? HotkeyC : "c", "C")
                executed := true
            case "ch_v":
                HandleDynamicHotkey(HotkeyV != "" ? HotkeyV : "v", "V")
                executed := true
            case "ch_x":
                HandleDynamicHotkey(HotkeyX != "" ? HotkeyX : "x", "X")
                executed := true
            case "ch_e":
                HandleDynamicHotkey(HotkeyE != "" ? HotkeyE : "e", "E")
                executed := true
            case "ch_r":
                HandleDynamicHotkey(HotkeyR != "" ? HotkeyR : "r", "R")
                executed := true
            case "ch_o":
                HandleDynamicHotkey(HotkeyO != "" ? HotkeyO : "o", "O")
                executed := true
            case "ch_q":
                HandleDynamicHotkey(HotkeyQ != "" ? HotkeyQ : "q", "Q")
                executed := true
            case "ch_z":
                HandleDynamicHotkey(HotkeyZ != "" ? HotkeyZ : "z", "Z")
                executed := true
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
                CapsLock2 := false
                Send("{Up}")
                executed := true
            case "ch_s":
                CapsLock2 := false
                Send("{Down}")
                executed := true
            case "ch_a":
                CapsLock2 := false
                Send("{Left}")
                executed := true
            case "ch_d":
                CapsLock2 := false
                Send("{Right}")
                executed := true
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
