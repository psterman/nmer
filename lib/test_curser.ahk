#Requires AutoHotkey v2.0

; 测试curser.ahk的基本功能
try {
    ; 包含主脚本
    #Include curser.ahk

    ; 简单的测试
    MsgBox("Curser脚本加载成功！", "测试", "Iconi")

} catch error {
    MsgBox("加载失败: " error.Message, "错误", "Iconx")
}