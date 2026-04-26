; ======================================================================================================================
; Curser - Cursor Chat Exporter (极简化测试版本)
; ======================================================================================================================

#Requires AutoHotkey v2.0
#SingleInstance Force

; 包含必要的库文件
#Include Class_SQLiteDB.ahk
#Include Jxon.ahk

; 全局变量
global VERSION := "1.0.0"
global APP_NAME := "Cursor Chat Exporter"

; 简化的主类
class CurserApp {
    __New() {
        this.TestFunction()
    }

    TestFunction() {
        MsgBox("Curser应用初始化成功！", "测试", "Iconi")
    }
}

; 主函数
Main() {
    try {
        global app := CurserApp()
    } catch error {
        MsgBox("程序启动失败: " error.Message "`n行号: " error.Line "`n文件: " error.File, "错误", "Iconx")
    }
}

; 启动程序
Main()