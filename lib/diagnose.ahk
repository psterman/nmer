; Curser 启动诊断脚本
#Requires AutoHotkey v2.0

MsgBox("Curser启动诊断开始...", "诊断", "Iconi")

; 检查必要的库文件
libs := ["Class_SQLiteDB.ahk", "Gdip_All.ahk", "Jxon.ahk"]
missingLibs := []

for lib in libs {
    if (!FileExist(lib)) {
        missingLibs.Push(lib)
    }
}

if (missingLibs.Length > 0) {
    MsgBox("缺少必要的库文件:`n" Join(missingLibs, "`n"), "错误", "Iconx")
    ExitApp
}

; 检查目录结构
dirs := ["..\config", "..\output\markdown", "..\output\html", "..\output\json"]
missingDirs := []

for dir in dirs {
    if (!DirExist(dir)) {
        missingDirs.Push(dir)
    }
}

if (missingDirs.Length > 0) {
    MsgBox("缺少必要的目录:`n" Join(missingDirs, "`n"), "警告", "Icon!")
    ; 尝试创建缺失的目录
    for dir in missingDirs {
        DirCreate(dir)
    }
    MsgBox("已创建缺失的目录", "信息", "Iconi")
}

; 检查配置文件
configFile := "..\config\curser.ini"
if (!FileExist(configFile)) {
    MsgBox("配置文件不存在，正在创建默认配置...", "信息", "Iconi")
    configContent := `;[Curser Configuration File]
[Settings]
Theme=dark
ExportFormat=markdown
ExportDir=C:/Users/pster/Desktop/小c/output
AutoScan=true
MaxPreviewLines=100
LogLevel=info

[Advanced]
EnableDebug=false
CacheEnabled=true
Timeout=30000`

    try {
        FileAppend(configContent, configFile, "UTF-8")
        MsgBox("配置文件创建成功", "成功", "Iconi")
    } catch {
        MsgBox("配置文件创建失败", "错误", "Iconx")
        ExitApp
    }
}

; 检查SQLite DLL
sqliteDll := "sqlite3.dll"
if (!FileExist(sqliteDll)) {
    MsgBox("sqlite3.dll 文件不存在，请确保SQLite库已正确安装", "错误", "Iconx")
    ExitApp
}

; 检查Cursor工作区
cursorPath := A_AppData "\Cursor\User\workspaceStorage"
if (!DirExist(cursorPath)) {
    MsgBox("未找到Cursor工作区目录:`n" cursorPath "`n请确保Cursor已正确安装并使用过", "警告", "Icon!")
} else {
    ; 统计工作区数量
    workspaceCount := 0
    dbCount := 0
    Loop Files cursorPath "\*", "D" {
        workspaceCount++
        dbPath := A_LoopFilePath "\state.vscdb"
        if (FileExist(dbPath)) {
            dbCount++
        }
    }
    MsgBox("找到 " workspaceCount " 个工作区，其中 " dbCount " 个包含数据库文件", "信息", "Iconi")
}

; 所有检查通过，尝试启动主程序
result := MsgBox("诊断完成！所有检查通过。是否现在启动Curser？", "启动确认", "YesNo Icon?")
if (result = "Yes") {
    try {
        Run("curser.ahk")
        MsgBox("Curser已启动！", "成功", "Iconi")
    } catch error {
        MsgBox("启动失败: " Type(error), "错误", "Iconx")
    }
} else {
    MsgBox("诊断完成。您可以手动运行 curser.ahk 启动程序。", "完成", "Iconi")
}

; 辅助函数
Join(arr, separator := ", ") {
    result := ""
    for item in arr {
        if (result != "") {
            result .= separator
        }
        result .= item
    }
    return result
}