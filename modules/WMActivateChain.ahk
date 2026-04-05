#Requires AutoHotkey v2.0
; 同进程内多个无边框 WebView 窗口各自用 WM_ACTIVATE 做「失焦自动隐藏」时，
; 若直接 OnMessage(0x0006, …) 会互相覆盖；关闭其中一个窗口时 OnMessage(…, 0) 还会把其它窗口的监听一并卸掉。
; 通过链式分发，各模块只 Register/Unregister 自己的回调即可。

global g_WMActivateChain := []
global g_WMActivateChain_DispatchActive := false

_WMActivateChain_Dispatch(wParam, lParam, msg, hwnd) {
    global g_WMActivateChain
    if g_WMActivateChain.Length = 0
        return
    snap := []
    for fn in g_WMActivateChain
        snap.Push(fn)
    for fn in snap
        try fn.Call(wParam, lParam, msg, hwnd)
}

WMActivateChain_Register(fn) {
    global g_WMActivateChain, g_WMActivateChain_DispatchActive
    if !(fn is Func)
        return
    for x in g_WMActivateChain
        if (x = fn)
            return
    g_WMActivateChain.Push(fn)
    if !g_WMActivateChain_DispatchActive {
        OnMessage(0x0006, _WMActivateChain_Dispatch)
        g_WMActivateChain_DispatchActive := true
    }
}

WMActivateChain_Unregister(fn) {
    global g_WMActivateChain, g_WMActivateChain_DispatchActive
    i := 0
    Loop g_WMActivateChain.Length {
        if (g_WMActivateChain[A_Index] = fn) {
            i := A_Index
            break
        }
    }
    if (i > 0)
        g_WMActivateChain.RemoveAt(i)
    if (g_WMActivateChain.Length = 0 && g_WMActivateChain_DispatchActive) {
        OnMessage(0x0006, _WMActivateChain_Dispatch, 0)
        g_WMActivateChain_DispatchActive := false
    }
}
