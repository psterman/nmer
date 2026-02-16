#Requires AutoHotkey v2.0
#Include Class_SQLiteDB.ahk

; 测试数据库连接
dbPath := A_AppData "\Cursor\User\workspaceStorage\6fb3543a16c9429471828e4642945e66\state.vscdb"

if (!FileExist(dbPath)) {
    MsgBox("数据库文件不存在: " dbPath, "错误", "Iconx")
    ExitApp
}

db := SQLiteDB()
if (!db.OpenDB(dbPath)) {
    MsgBox("无法打开数据库: " db.ErrorMsg, "错误", "Iconx")
    ExitApp
}

; 查询表结构
SQL := "SELECT name FROM sqlite_master WHERE type='table'"
tables := db.GetTable(SQL)

if (tables && tables.HasRows) {
    tableList := "找到的表:`n"
    for row in tables.Rows {
        tableList .= "- " row[1] "`n"
    }
    MsgBox(tableList, "数据库表结构", "Iconi")
} else {
    MsgBox("无法查询表结构", "错误", "Iconx")
}

; 查询ItemTable的内容
SQL := "SELECT [key], length(value) as size FROM ItemTable LIMIT 10"
items := db.GetTable(SQL)

if (items && items.HasRows) {
    itemList := "ItemTable内容 (前10条):`n"
    for row in items.Rows {
        itemList .= "- " row[1] " (大小: " row[2] " 字节)`n"
    }
    MsgBox(itemList, "ItemTable内容", "Iconi")
}

db.CloseDB()
MsgBox("数据库测试完成", "完成", "Iconi")