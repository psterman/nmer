; ======================================================================================================================
; 剪贴板诊断工具 - 检查数据库和监听器状态
; 用于诊断 ListView 无法获取用户复制数据的问题
; ======================================================================================================================

#Requires AutoHotkey v2.0
#Include modules\ClipboardFTS5.ahk

; 设置主脚本目录
MainScriptDir := A_ScriptDir

; 诊断报告
diagnosisReport := ""

; 添加诊断信息
AddDiagnosis(message) {
    global diagnosisReport
    diagnosisReport .= message . "`n"
    OutputDebug(message . "`n")
}

; 开始诊断
AddDiagnosis("========== 剪贴板诊断开始 ==========")
AddDiagnosis("时间: " . FormatTime(, "yyyy-MM-dd HH:mm:ss"))

; 1. 检查 sqlite3.dll
AddDiagnosis("`n[1] 检查 sqlite3.dll")
dllPath := A_ScriptDir "\sqlite3.dll"
if (FileExist(dllPath)) {
    AddDiagnosis("✓ sqlite3.dll 存在: " . dllPath)
} else {
    AddDiagnosis("✗ sqlite3.dll 未找到: " . dllPath)
}

; 2. 检查数据库文件
AddDiagnosis("`n[2] 检查数据库文件")
dbPath := A_ScriptDir "\Clipboard.db"
if (FileExist(dbPath)) {
    AddDiagnosis("✓ Clipboard.db 存在: " . dbPath)
    ; 检查文件大小
    try {
        fileSize := FileGetSize(dbPath)
        AddDiagnosis("  文件大小: " . fileSize . " 字节")
    } catch as err {
        AddDiagnosis("  无法获取文件大小: " . err.Message)
    }
    ; 检查写入权限
    try {
        testFile := FileOpen(dbPath, "a")
        if (testFile) {
            testFile.Close()
            AddDiagnosis("✓ 数据库文件具有写入权限")
        } else {
            AddDiagnosis("✗ 数据库文件无法写入")
        }
    } catch as err {
        AddDiagnosis("✗ 数据库文件写入测试失败: " . err.Message)
    }
} else {
    AddDiagnosis("⚠ Clipboard.db 不存在（首次运行将自动创建）")
}

; 3. 初始化数据库
AddDiagnosis("`n[3] 初始化数据库")
if (InitClipboardFTS5DB()) {
    AddDiagnosis("✓ 数据库初始化成功")
} else {
    AddDiagnosis("✗ 数据库初始化失败")
    if (ClipboardFTS5DB && ClipboardFTS5DB != 0) {
        AddDiagnosis("  错误信息: " . ClipboardFTS5DB.ErrorMsg)
    }
}

; 4. 检查数据库连接
AddDiagnosis("`n[4] 检查数据库连接")
if (ClipboardFTS5DB && ClipboardFTS5DB != 0) {
    AddDiagnosis("✓ 数据库对象已创建")
    
    ; 检查表是否存在
    SQL := "SELECT name FROM sqlite_master WHERE type='table' AND name='ClipMain'"
    table := ""
    if (ClipboardFTS5DB.GetTable(SQL, &table)) {
        if (table.HasRows && table.Rows.Length > 0) {
            AddDiagnosis("✓ ClipMain 表存在")
        } else {
            AddDiagnosis("✗ ClipMain 表不存在")
        }
    } else {
        AddDiagnosis("✗ 检查表结构失败: " . ClipboardFTS5DB.ErrorMsg)
    }
    
    ; 检查记录数
    SQL := "SELECT COUNT(*) FROM ClipMain"
    table := ""
    if (ClipboardFTS5DB.GetTable(SQL, &table)) {
        if (table.HasRows && table.Rows.Length > 0) {
            recordCount := table.Rows[1][1]
            AddDiagnosis("✓ 数据库中有 " . recordCount . " 条记录")
        }
    }
    
    ; 获取最新5条记录
    SQL := "SELECT ID, Content, SourceApp, DataType, Timestamp FROM ClipMain ORDER BY ID DESC LIMIT 5"
    table := ""
    if (ClipboardFTS5DB.GetTable(SQL, &table)) {
        if (table.HasRows && table.Rows.Length > 0) {
            AddDiagnosis("`n最新5条记录:")
            Loop table.Rows.Length {
                row := table.Rows[A_Index]
                content := row[2]
                if (StrLen(content) > 50) {
                    content := SubStr(content, 1, 50) . "..."
                }
                AddDiagnosis("  [" . row[1] . "] " . content . " (" . row[3] . ", " . row[4] . ", " . row[5] . ")")
            }
        } else {
            AddDiagnosis("⚠ 数据库中没有记录")
        }
    }
} else {
    AddDiagnosis("✗ 数据库对象未创建")
}

; 5. 测试剪贴板监听
AddDiagnosis("`n[5] 测试剪贴板监听")
currentClipboard := A_Clipboard
AddDiagnosis("当前剪贴板内容: " . (currentClipboard != "" ? SubStr(currentClipboard, 1, 50) : "[空]"))

; 6. 测试数据保存
AddDiagnosis("`n[6] 测试数据保存")
testContent := "测试内容_" . A_TickCount
if (ClipboardFTS5DB && ClipboardFTS5DB != 0) {
    result := SaveToClipboardFTS5(testContent, "test_diagnosis.exe", "Text")
    if (result) {
        AddDiagnosis("✓ 测试数据保存成功")
        
        ; 验证数据是否真的保存了
        SQL := "SELECT ID, Content FROM ClipMain WHERE Content = '" . StrReplace(testContent, "'", "''") . "' ORDER BY ID DESC LIMIT 1"
        table := ""
        if (ClipboardFTS5DB.GetTable(SQL, &table)) {
            if (table.HasRows && table.Rows.Length > 0) {
                AddDiagnosis("✓ 验证：数据已成功写入数据库")
            } else {
                AddDiagnosis("✗ 验证：数据未找到（可能保存失败）")
            }
        }
    } else {
        AddDiagnosis("✗ 测试数据保存失败")
        if (ClipboardFTS5DB && ClipboardFTS5DB != 0) {
            AddDiagnosis("  错误信息: " . ClipboardFTS5DB.ErrorMsg)
        }
    }
} else {
    AddDiagnosis("✗ 无法测试：数据库未连接")
}

; 7. 检查 WAL 模式
AddDiagnosis("`n[7] 检查 WAL 模式")
if (ClipboardFTS5DB && ClipboardFTS5DB != 0) {
    SQL := "PRAGMA journal_mode"
    table := ""
    if (ClipboardFTS5DB.GetTable(SQL, &table)) {
        if (table.HasRows && table.Rows.Length > 0) {
            journalMode := table.Rows[1][1]
            if (journalMode = "wal") {
                AddDiagnosis("✓ WAL 模式已启用")
            } else {
                AddDiagnosis("⚠ 日志模式: " . journalMode . " (建议使用 WAL)")
            }
        }
    }
}

; 输出诊断报告
AddDiagnosis("`n========== 诊断完成 ==========")

; 显示诊断报告
MsgBox(diagnosisReport, "剪贴板诊断报告", "Iconi")

; 保存诊断报告到文件
diagnosisFile := A_ScriptDir "\clipboard_diagnosis_" . FormatTime(, "yyyyMMdd_HHmmss") . ".txt"
FileAppend(diagnosisReport, diagnosisFile)
AddDiagnosis("诊断报告已保存到: " . diagnosisFile)
