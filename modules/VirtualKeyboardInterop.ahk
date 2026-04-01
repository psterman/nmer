; VirtualKeyboard ↔ CursorHelper：WM_COPYDATA（独立运行的 VirtualKeyboard.ahk 发 vkExec 时仍可用）
; 需在 VirtualKeyboardExecCmd.ahk（VK_ExecCursorHelperCmd）之后 #Include

OnMessage(0x4A, _VkInteropCopyData)

_VkInteropCopyData(wParam, lParam, *) {
    sz := NumGet(lParam + 4, "UInt")
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
        VK_ExecCursorHelperCmd(j["cmdId"])
        return true
    }
    return false
}
