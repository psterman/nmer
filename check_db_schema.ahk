#Requires AutoHotkey v2.0
#Include lib\Class_SQLiteDB.ahk

; 打开数据库
DB := SQLiteDB()
if (!DB.OpenDB("Clipboard.db")) {
    MsgBox("无法打开数据库: " . DB.ErrorMsg, "错误", "Iconx")
    ExitApp
}

; 查询表结构
SQL := "PRAGMA table_info(ClipMain)"
table := ""
if (DB.GetTable(SQL, &table)) {
    if (table.HasRows && table.Rows.Length > 0) {
        output := "ClipMain 表结构：`n`n"
        output .= "索引 | 列名 | 类型 | 非空 | 默认值 | 主键`n"
        output .= "------------------------------------------------------------`n"
        
        Loop table.Rows.Length {
            row := table.Rows[A_Index]
            output .= row[1] . " | " . row[2] . " | " . row[3] . " | " . row[4] . " | " . row[5] . " | " . row[6] . "`n"
        }
        
        MsgBox(output, "数据库表结构", "Iconi 64")
    } else {
        MsgBox("表中没有数据", "提示", "Iconi 64")
    }
} else {
    MsgBox("查询失败: " . DB.ErrorMsg, "错误", "Iconx")
}

; 查询实际数据（前10条）
SQL := "SELECT ID, Content, SourceApp, SourcePath, DataType, CharCount, Timestamp, LastCopyTime, CopyCount FROM ClipMain ORDER BY ID DESC LIMIT 10"
table := ""
if (DB.GetTable(SQL, &table)) {
    if (table.HasRows && table.Rows.Length > 0) {
        output := "前10条数据：`n`n"
        
        ; 显示列名
        if (table.HasNames && table.ColumnNames.Length > 0) {
            output .= "列名："
            Loop table.ColumnNames.Length {
                output .= "`n  " . A_Index . ": " . table.ColumnNames[A_Index]
            }
            output .= "`n`n"
        }
        
        ; 显示数据
        Loop table.Rows.Length {
            row := table.Rows[A_Index]
            output .= "记录 " . A_Index . ":`n"
            output .= "  ID: " . row[1] . "`n"
            output .= "  Content: " . SubStr(row[2], 1, 50) . "`n"
            output .= "  SourceApp: " . row[3] . "`n"
            output .= "  SourcePath: " . row[4] . "`n"
            output .= "  DataType: " . row[5] . "`n"
            output .= "  CharCount: " . row[6] . "`n"
            output .= "  Timestamp: " . row[7] . "`n"
            output .= "  LastCopyTime: " . row[8] . "`n"
            output .= "  CopyCount: " . row[9] . "`n`n"
        }
        
        MsgBox(output, "数据库实际数据", "Iconi 64")
    } else {
        MsgBox("表中没有数据", "提示", "Iconi 64")
    }
} else {
    MsgBox("查询失败: " . DB.ErrorMsg, "错误", "Iconx")
}

DB.CloseDB()
ExitApp
