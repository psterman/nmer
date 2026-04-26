#Requires AutoHotkey v2.0
; 引力场预留：60fps 坐标泵，默认不启动，避免空转开销

global g_Gravity_MouseX := 0
global g_Gravity_MouseY := 0
global g_GravityPumpRunning := false

GravityPump_OnTick(*) {
    global g_Gravity_MouseX, g_Gravity_MouseY
    CoordMode("Mouse", "Screen")
    MouseGetPos(&mx, &my)
    g_Gravity_MouseX := mx
    g_Gravity_MouseY := my
}

GravityPump_Start() {
    global g_GravityPumpRunning
    if g_GravityPumpRunning
        return
    g_GravityPumpRunning := true
    SetTimer(GravityPump_OnTick, 16)
}

GravityPump_Stop() {
    global g_GravityPumpRunning
    g_GravityPumpRunning := false
    SetTimer(GravityPump_OnTick, 0)
}

GravityPump_Register() {
    ; 由主脚本启动时调用：仅完成模块加载与 API 就绪，不启 SetTimer
}
