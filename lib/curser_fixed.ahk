; ======================================================================================================================
; Curser - Cursor Chat Exporter (修复版本)
; ======================================================================================================================

#Requires AutoHotkey v2.0
#SingleInstance Force
SetTitleMatchMode(2)
DetectHiddenWindows(true)

; 包含必要的库文件
#Include Class_SQLiteDB.ahk
#Include Gdip_All.ahk

; ===================== 全局变量和配置 =====================
global VERSION := "1.0.0"
global APP_NAME := "Cursor Chat Exporter"
global CONFIG_FILE := A_ScriptDir "\..\config\curser.ini"
global EXPORT_DIR := A_ScriptDir "\..\output"

; GUI相关全局变量
global MainGUI := 0
global Workspaces := []
global SearchQuery := ""
global FilterType := "all"
global ExportFormat := "markdown"

; 主题颜色配置 (简化版)
global ThemeMode := "dark"

; ===================== 辅助函数 =====================
RepeatString(str, count) {
    result := ""
    Loop count {
        result .= str
    }
    return result
}

; ===================== JSON处理 =====================
class JSON {
    static parse(jsonStr) {
        jsonStr := Trim(jsonStr)
        if (SubStr(jsonStr, 1, 1) == "{") {
            result := Map()
            content := SubStr(jsonStr, 2, -1)
            Loop Parse content, ',"' {
                if (InStr(A_LoopField, ":")) {
                    parts := StrSplit(A_LoopField, ":", , 2)
                    if (parts.Length == 2) {
                        key := Trim(parts[1], '" ')
                        value := Trim(parts[2], '" ')
                        result[key] := value
                    }
                }
            }
            return result
        }
        return jsonStr
    }

    static stringify(obj, indent := 0) {
        if (obj is Map) {
            result := "{"
            first := true
            for key, value in obj {
                if (!first) result .= ","
                result .= (indent ? "`n" RepeatString("  ", indent) : "") '"' key '":'
                if (value is String) {
                    result .= '"' value '"'
                } else {
                    result .= String(value)
                }
                first := false
            }
            result .= (indent ? "`n" RepeatString("  ", indent-1) : "") "}"
            return result
        }
        return String(obj)
    }
}

; ===================== CurserApp类 =====================
class CurserApp {
    __New() {
        this.InitDirectories()
        this.CreateMainGUI()
        this.ScanWorkspaces()
        this.UpdateUI()
    }

    InitDirectories() {
        DirCreate(A_ScriptDir "\..\config")
        DirCreate(EXPORT_DIR "\markdown")
        DirCreate(EXPORT_DIR "\html")
        DirCreate(EXPORT_DIR "\json")
    }

    ScanWorkspaces() {
        Workspaces := []
        workspacePath := A_AppData "\Cursor\User\workspaceStorage"

        if (!DirExist(workspacePath)) {
            MsgBox("未找到Cursor目录", "警告", "Icon!")
            return
        }

        Loop Files workspacePath "\*", "D" {
            dbPath := A_LoopFilePath "\state.vscdb"
            if (FileExist(dbPath)) {
                workspace := Map(
                    "id", A_LoopFileName,
                    "path", dbPath,
                    "name", this.GetWorkspaceName(A_LoopFilePath "\workspace.json"),
                    "chatCount", 0
                )
                Workspaces.Push(workspace)
            }
        }
    }

    GetWorkspaceName(jsonPath) {
        try {
            if (FileExist(jsonPath)) {
                content := FileRead(jsonPath, "UTF-8")
                if (RegExMatch(content, '"folder"\s*:\s*"([^"]+)"', &match)) {
                    SplitPath(match[1], &name)
                    return name
                }
            }
        }
        return "未知项目"
    }

    Log(message) {
        ; 简化的日志记录
    }
}

; ===================== GUI界面创建 =====================

CreateMainGUI() {
    global MainGUI

    MainGUI := Gui("+Resize", APP_NAME " v" VERSION)
    MainGUI.Add("Text", "x10 y10 w400 h30", "Cursor Chat Exporter")
    MainGUI.Add("Text", "x10 y40 w400 h20", "导出您的AI聊天记录")

    ; 工作区列表
    MainGUI.Add("ListView", "x10 y70 w400 h200 vWorkspaceList -Multi +Grid +ReadOnly", ["项目名称", "ID", "聊天数"])

    ; 按钮
    MainGUI.Add("Button", "x10 y280 w80 h30 vRefreshBtn", "刷新").OnEvent("Click", RefreshWorkspaces)
    MainGUI.Add("Button", "x100 y280 w80 h30 vTestBtn", "测试").OnEvent("Click", TestExport)

    ; 状态栏
    MainGUI.Add("StatusBar", "vStatusBar", "就绪")

    MainGUI.Show("w430 h340")
}

; ===================== 事件处理函数 =====================

RefreshWorkspaces(*) {
    app.ScanWorkspaces()
    UpdateUI()
}

TestExport(*) {
    MsgBox("导出功能开发中...", "提示", "Iconi")
}

; ===================== UI更新函数 =====================

UpdateUI() {
    lv := MainGUI["WorkspaceList"]
    lv.Delete()

    for workspace in Workspaces {
        lv.Add(, workspace["name"], workspace["id"], workspace["chatCount"])
    }

    MainGUI["StatusBar"].SetText("找到 " Workspaces.Length " 个工作区")
}

; ===================== 主程序入口 =====================

Main() {
    try {
        global app := CurserApp()
    } catch error {
        MsgBox("程序启动失败: " error.Message "`n行号: " error.Line, "错误", "Iconx")
    }
}

Main()</content>
<parameter name="filePath">C:\Users\pster\Desktop\小c\lib\curser_fixed.ahk