#Requires AutoHotkey v2.0

; 语法检查脚本 - 只检查语法不运行GUI
try {
    ; 包含主脚本进行语法检查
    #Include curser.ahk

    MsgBox("语法检查通过！", "成功", "Iconi")
} catch error {
    MsgBox("语法错误: " error.Message "`n`n行号: " error.Line "`n文件: " error.File, "错误", "Iconx")
}