; VirtualKeyboard ↔ CursorHelper：WM_COPYDATA（与 VirtualKeyboard.ahk NotifyScript 一致）
; 需在 CursorHelper 中于 HandleDynamicHotkey、ActivateQuickActionButton 等定义之后再 #Include

OnMessage(0x4A, _VkInteropCopyData)

_VkInteropCopyData(wParam, lParam, *) {
    sz  := NumGet(lParam + 4, "UInt")
    ptr := NumGet(lParam + 8, "Ptr")
    if (sz = 0 || !ptr)
        return false
    try {
        j := Jxon_Load(StrGet(ptr, sz, "UTF-8"))
    } catch {
        return false
    }
    if !(j is Map) || !j.Has("type")
        return false
    if (j["type"] = "bindingsReloaded")
        return true
    if (j["type"] = "vkExec" && j.Has("cmdId")) {
        _VkExecCmd(j["cmdId"])
        return true
    }
    return false
}

_VkExecCmd(cmdId) {
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
                ActivateQuickActionButton(1)
            case "ch_2":
                ActivateQuickActionButton(2)
            case "ch_3":
                ActivateQuickActionButton(3)
            case "ch_4":
                ActivateQuickActionButton(4)
            case "ch_5":
                ActivateQuickActionButton(5)
            default:
                OutputDebug("[VK-Interop] unknown cmdId: " . cmdId)
        }
    } catch as e {
        OutputDebug("[VK-Interop] vkExec error: " . e.Message)
    } finally {
        CapsLock := prevCaps
    }
}
