; Curser - 超级简化版本 (仅控制台输出)
#Requires AutoHotkey v2.0

; 包含基本库
#Include Class_SQLiteDB.ahk
#Include Jxon.ahk

; 辅助函数
RepeatString(str, count) {
    result := ""
    Loop count {
        result .= str
    }
    return result
}

; 主程序
try {
    MsgBox("Curser启动中...", "信息", "Iconi")

    ; 检查Cursor工作区
    cursorPath := A_AppData "\Cursor\User\workspaceStorage"

    if (!DirExist(cursorPath)) {
        MsgBox("未找到Cursor工作区目录:`n" cursorPath "`n请确保Cursor已安装并使用过", "警告", "Icon!")
        ExitApp
    }

    MsgBox("找到Cursor工作区目录，开始扫描...", "信息", "Iconi")

    ; 扫描工作区
    workspaces := []
    Loop Files cursorPath "\*", "D" {
        dbPath := A_LoopFilePath "\state.vscdb"
        if (FileExist(dbPath)) {
            workspaces.Push({
                id: A_LoopFileName,
                path: dbPath,
                name: "项目-" A_LoopFileName
            })
        }
    }

    if (workspaces.Length == 0) {
        MsgBox("未找到任何包含数据库的工作区", "警告", "Icon!")
        ExitApp
    }

    MsgBox("找到 " workspaces.Length " 个工作区，开始测试数据库连接...", "信息", "Iconi")

    ; 测试第一个工作区的数据库连接
    workspace := workspaces[1]
    db := SQLiteDB()

    if (!db.OpenDB(workspace.path)) {
        MsgBox("数据库连接失败: " db.ErrorMsg, "错误", "Iconx")
        ExitApp
    }

    MsgBox("数据库连接成功！`n工作区: " workspace.name "`n路径: " workspace.path, "成功", "Iconi")

    ; 测试查询
    SQL := "SELECT name FROM sqlite_master WHERE type='table'"
    result := db.GetTable(SQL)

    tableCount := result && result.HasRows ? result.Rows.Length : 0
    tableNames := ""

    if (result && result.HasRows) {
        for row in result.Rows {
            tableNames .= row[1] "`n"
        }
    }

    db.CloseDB()

    MsgBox("数据库查询成功！`n表数量: " tableCount "`n表名:`n" tableNames "`n`nCurser基本功能测试通过！", "成功", "Iconi")

} catch error {
    MsgBox("程序运行出错: " Type(error), "错误", "Iconx")
}