; CursorHelper 命令执行（VirtualKeyboard CH_RUN / WM_COPYDATA vkExec 共用）
; 须在 HandleDynamicHotkey、ExecuteQuickActionByType、ExecuteQuickActionSlot 等定义之后再 #Include

VK_ExecCursorHelperCmd(cmdId) {
    global CapsLock, CapsLock2, BatchHotkey, IsCountdownActive
    prevCaps := CapsLock
    CapsLock := true
    try {
        switch cmdId {
            case "ch_c":
                HandleDynamicHotkey("c", "C")
            case "ch_v":
                HandleDynamicHotkey("v", "V")
            case "ch_x":
                HandleDynamicHotkey("x", "X")
            case "ch_e":
                HandleDynamicHotkey("e", "E")
            case "ch_r":
                HandleDynamicHotkey("r", "R")
            case "ch_o":
                HandleDynamicHotkey("o", "O")
            case "ch_q":
                HandleDynamicHotkey("q", "Q")
            case "ch_z":
                HandleDynamicHotkey("z", "Z")
            case "ch_t":
                HandleDynamicHotkey("t", "T")
            case "ch_f":
                if (IsCountdownActive) {
                    ExecuteCountdownAction()
                } else if (IsSearchCenterActive()) {
                    HandleSearchCenterF()
                } else {
                    ShowSearchCenter()
                }
            case "ch_g":
                StartVoiceSearch()
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
            case "ch_p":
                HandleDynamicHotkey("p", "P")
            case "ch_w":
                CapsLock2 := false
                Send("{Up}")
            case "ch_s":
                CapsLock2 := false
                Send("{Down}")
            case "ch_a":
                CapsLock2 := false
                Send("{Left}")
            case "ch_d":
                CapsLock2 := false
                Send("{Right}")
            case "ch_1":
                ExecuteQuickActionSlot(1)
            case "ch_2":
                ExecuteQuickActionSlot(2)
            case "ch_3":
                ExecuteQuickActionSlot(3)
            case "ch_4":
                ExecuteQuickActionSlot(4)
            case "ch_5":
                ExecuteQuickActionSlot(5)
            case "qa_split":
                ExecuteQuickActionByType("Split")
            case "qa_command_palette":
                ExecuteQuickActionByType("CommandPalette")
            case "qa_terminal":
                ExecuteQuickActionByType("Terminal")
            case "qa_global_search":
                ExecuteQuickActionByType("GlobalSearch")
            case "qa_explorer":
                ExecuteQuickActionByType("Explorer")
            case "qa_source_control":
                ExecuteQuickActionByType("SourceControl")
            case "qa_extensions":
                ExecuteQuickActionByType("Extensions")
            case "qa_browser":
                ExecuteQuickActionByType("Browser")
            case "qa_settings":
                ExecuteQuickActionByType("Settings")
            case "qa_cursor_settings":
                ExecuteQuickActionByType("CursorSettings")
            default:
                if (SubStr(cmdId, 1, 3) = "pt_") {
                    runPt := Func("ExecutePromptByTemplateId")
                    if runPt
                        runPt.Call(SubStr(cmdId, 4))
                    else
                        OutputDebug("[VK-Exec] pt_* 需要 CursorHelper")
                } else
                    OutputDebug("[VK-Exec] unknown cmdId: " . cmdId)
        }
    } catch as e {
        OutputDebug("[VK-Exec] error: " . e.Message)
    } finally {
        CapsLock := prevCaps
    }
}
