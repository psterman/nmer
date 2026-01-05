#Requires AutoHotkey v2.0
#Include lib\Class_SQLiteDB.ahk

; 全局变量
global ClipboardFTS5DB := 0
global ClipboardFTS5DBPath := A_ScriptDir "\Clipboard.db"

; 测试数据库连接
TrayTip("测试", "开始测试数据库连接", "Iconi 1")

try {
    ClipboardFTS5DB := SQLiteDB()
    if (!ClipboardFTS5DB.OpenDB(ClipboardFTS5DBPath)) {
        TrayTip("错误", "无法打开数据库: " . ClipboardFTS5DB.ErrorMsg, "Iconx 2")
        ExitApp
    }
    TrayTip("成功", "数据库连接成功", "Iconi 1")
    
    ; 测试插入数据
    SQL := "INSERT INTO ClipMain (Content, SourceApp, DataType, CharCount) VALUES (?, ?, ?, ?)"
    stmt := ""
    if (!ClipboardFTS5DB.Prepare(SQL, &stmt)) {
        TrayTip("错误", "准备语句失败: " . ClipboardFTS5DB.ErrorMsg, "Iconx 2")
        ExitApp
    }
    
    stmt.Bind(1, "Test content from debug script")
    stmt.Bind(2, "DebugApp")
    stmt.Bind(3, "Text")
    stmt.Bind(4, 30)
    
    if (!stmt.Step()) {
        TrayTip("错误", "插入数据失败: " . ClipboardFTS5DB.ErrorMsg, "Iconx 2")
        stmt.Free()
        ExitApp
    }
    
    rowid := ClipboardFTS5DB.LastInsertRowID()
    stmt.Free()
    
    TrayTip("成功", "数据插入成功，ID: " . rowid, "Iconi 1")
    
    ; 验证数据
    SQL := "SELECT COUNT(*) FROM ClipMain"
    stmt := ""
    if (ClipboardFTS5DB.Prepare(SQL, &stmt) && stmt.Step()) {
        count := stmt.Column(0)
        TrayTip("验证", "数据库中有 " . count . " 条记录", "Iconi 1")
        stmt.Free()
    }
    
} catch as err {
    TrayTip("异常", "发生错误: " . err.Message, "Iconx 2")
}

Sleep(5000)
ExitApp
