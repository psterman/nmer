; ======================================================================================================================
; 测试搜索逻辑 - 验证输入框搜索是否能正确匹配数据
; ======================================================================================================================

#Requires AutoHotkey v2.0
#Include modules\ClipboardFTS5.ahk

; 设置主脚本目录
MainScriptDir := A_ScriptDir

; 初始化数据库
if (!InitClipboardFTS5DB()) {
    MsgBox("数据库初始化失败！", "错误", "IconX")
    ExitApp
}

; 测试搜索功能
testKeyword := "1"
MsgBox("测试搜索关键词: " . testKeyword, "搜索测试", "Iconi")

; 构建测试查询
SQL := "SELECT ID, Content, SourceApp, DataType FROM ClipMain WHERE (Content LIKE '%" . testKeyword . "%' OR SourceApp LIKE '%" . testKeyword . "%') ORDER BY ID DESC LIMIT 10"

table := ""
if (ClipboardFTS5DB.GetTable(SQL, &table)) {
    if (table.HasRows && table.Rows.Length > 0) {
        result := "找到 " . table.Rows.Length . " 条匹配记录：`n`n"
        Loop table.Rows.Length {
            row := table.Rows[A_Index]
            content := row[2]
            if (StrLen(content) > 50) {
                content := SubStr(content, 1, 50) . "..."
            }
            result .= "[" . row[1] . "] " . content . " (" . row[3] . ", " . row[4] . ")`n"
        }
        MsgBox(result, "搜索测试结果", "Iconi")
    } else {
        MsgBox("未找到匹配的记录", "搜索测试结果", "Iconi")
    }
} else {
    MsgBox("查询失败: " . ClipboardFTS5DB.ErrorMsg, "搜索测试结果", "IconX")
}

; 测试 FTS5 搜索
SQL := "SELECT rowid FROM ClipboardHistory WHERE ClipboardHistory MATCH '1*'"
table := ""
if (ClipboardFTS5DB.GetTable(SQL, &table)) {
    if (table.HasRows && table.Rows.Length > 0) {
        result := "FTS5 搜索找到 " . table.Rows.Length . " 条记录"
        MsgBox(result, "FTS5 搜索测试", "Iconi")
    } else {
        MsgBox("FTS5 搜索未找到记录（这是正常的，因为 FTS5 对单个字符的匹配可能不准确）", "FTS5 搜索测试", "Iconi")
    }
}
