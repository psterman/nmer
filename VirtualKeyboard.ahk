; ===========================================================================
; VirtualKeyboard.ahk — 独立进程入口（同目录 VirtualKeyboardCore + WebView2）
; 与 CursorHelper 同进程时请从 CursorHelper 打开虚拟键盘，勿重复运行本脚本
; ===========================================================================
#Requires AutoHotkey v2.0
#SingleInstance Force

#Include lib\WebView2.ahk
#Include lib\Jxon.ahk
; 独立进程未 #Include VirtualKeyboardExecCmd；提供占位，供 Core 内直接调用（避免 Func("VK_ExecCursorHelperCmd") 在函数不存在时抛错）
VK_ExecCursorHelperCmd(cmdId) {
    OutputDebug("[VK] 独立 VK 无 CursorHelper CH_RUN 实现: " . cmdId)
}
#Include modules\WMActivateChain.ahk
#Include modules\VirtualKeyboardCore.ahk

VK_Init(false)

OnExit (*) => VK_OnHostExit()

^+k:: {
    global g_VK_Gui
    if !g_VK_Gui
        return
    if WinExist("ahk_id " . g_VK_Gui.Hwnd) && WinGetStyle("ahk_id " . g_VK_Gui.Hwnd) & 0x10000000
        VK_Hide()
    else
        VK_Show()
}

~Ctrl:: _UpdateModifierState()
~Ctrl Up:: _UpdateModifierState()
~Alt:: _UpdateModifierState()
~Alt Up:: _UpdateModifierState()
~Shift:: _UpdateModifierState()
~Shift Up:: _UpdateModifierState()
