; Curser 最小化测试版本
#Requires AutoHotkey v2.0
#SingleInstance Force

; 包含基本库
#Include Class_SQLiteDB.ahk
#Include Jxon.ahk

; 全局变量
global VERSION := "1.0.0"
global APP_NAME := "Curser Test"

; 辅助函数
RepeatString(str, count) {
    result := ""
    Loop count {
        result .= str
    }
    return result
}

; 简化的JSON类
class JSON {
    static stringify(obj, indent := 0) {
        if (obj is Map) {
            result := "{"
            first := true
            for key, value in obj {
                if (!first) result .= ","
                result .= '"' key '":'
                if (value is String) {
                    result .= '"' value '"'
                } else {
                    result .= String(value)
                }
                first := false
            }
            result .= "}"
            return result
        }
        return String(obj)
    }
}

; 测试类
class TestApp {
    __New() {
        this.CreateTestGUI()
    }

    CreateTestGUI() {
        global MainGUI

        MainGUI := Gui("+Resize", APP_NAME " v" VERSION " - 测试版")
        MainGUI.Add("Text", "x10 y10 w400 h30", "Curser - 最小化测试版本")
        MainGUI.Add("Text", "x10 y40 w400 h20", "如果您能看到这个窗口，说明基本功能正常！")

        ; 工作区信息
        cursorPath := A_AppData "\Cursor\User\workspaceStorage"
        workspaceCount := 0

        if (DirExist(cursorPath)) {
            Loop Files cursorPath "\*", "D" {
                workspaceCount++
            }
        }

        MainGUI.Add("Text", "x10 y70 w400 h25", "Cursor工作区检测: " (DirExist(cursorPath) ? "✅ 找到" : "❌ 未找到"))
        MainGUI.Add("Text", "x10 y95 w400 h25", "工作区数量: " workspaceCount)

        ; 测试按钮
        MainGUI.Add("Button", "x10 y125 w100 h30 vTestBtn", "测试导出").OnEvent("Click", TestExport)
        MainGUI.Add("Button", "x120 y125 w100 h30 vExitBtn", "退出").OnEvent("Click", (*) => ExitApp())

        ; 状态栏
        MainGUI.Add("StatusBar", "vStatusBar", "测试模式 - 基本功能正常")

        MainGUI.Show("w430 h200")
    }
}

; 测试导出功能
TestExport(*) {
    try {
        ; 查找第一个可用的工作区
        cursorPath := A_AppData "\Cursor\User\workspaceStorage"
        firstWorkspace := ""

        if (DirExist(cursorPath)) {
            Loop Files cursorPath "\*", "D" {
                dbPath := A_LoopFilePath "\state.vscdb"
                if (FileExist(dbPath)) {
                    firstWorkspace := A_LoopFileName
                    break
                }
            }
        }

        if (!firstWorkspace) {
            MsgBox("未找到可用的Cursor工作区", "错误", "Iconx")
            return
        }

        ; 尝试简单的数据库连接测试
        dbPath := cursorPath "\" firstWorkspace "\state.vscdb"
        db := SQLiteDB()

        if (!db.OpenDB(dbPath)) {
            MsgBox("数据库连接失败: " db.ErrorMsg, "错误", "Iconx")
            return
        }

        ; 尝试查询表结构
        SQL := "SELECT name FROM sqlite_master WHERE type='table'"
        result := db.GetTable(SQL)

        tableCount := result && result.HasRows ? result.Rows.Length : 0
        db.CloseDB()

        MsgBox("数据库连接成功！`n工作区: " firstWorkspace "`n表数量: " tableCount "`n`n基本功能测试通过！", "成功", "Iconi")

    } catch error {
        MsgBox("测试过程中出错: " Type(error), "错误", "Iconx")
    }
}

; 主程序
try {
    global app := TestApp()
} catch error {
    MsgBox("程序启动失败: " Type(error), "错误", "Iconx")
}