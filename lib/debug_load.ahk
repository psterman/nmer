#Requires AutoHotkey v2.0

; 详细错误追踪版本
try {
    MsgBox("开始加载curser.ahk...", "调试")

    ; 分步骤加载和测试
    #Include curser.ahk

    MsgBox("curser.ahk加载完成，开始初始化...", "调试")

    ; 手动初始化
    global app := CurserApp()

    MsgBox("初始化完成！", "成功", "Iconi")

} catch error {
    MsgBox("错误详情:`n" error.Message "`n`n文件: " error.File "`n行号: " error.Line "`n`n堆栈: " error.Stack, "详细错误信息", "Iconx")
}