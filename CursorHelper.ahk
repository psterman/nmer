#Requires AutoHotkey v2.0
; Stable entrypoint without spaces/parentheses.
#Include "CursorHelper (1).ahk"

; Fallback visibility: if startup appears "no response", force-open Search Center once.
try SetTimer(_CH_ForceShowAfterBoot, -1500)

_CH_ForceShowAfterBoot(*) {
    try {
        if IsSet(ShowSearchCenter)
            ShowSearchCenter()
    } catch {
    }
    try MsgBox("CursorHelper 已启动（若看不到主界面，请按 CapsLock+F）", "CursorHelper", "T2 64")
}
