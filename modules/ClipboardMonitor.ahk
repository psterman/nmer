; ======================================================================================================================
; 剪贴板入库监控调试工具
; 版本: 1.0.0
; 功能: 
;   - 实时监控 ClipboardFTS5 入库状态
;   - 显示最新记录信息和统计
;   - 错误诊断和日志记录
;   - 环境自检功能
; ======================================================================================================================

#Requires AutoHotkey v2.0
#Include ClipboardFTS5.ahk

; ===================== 全局变量 =====================
global GuiID_ClipboardMonitor := 0
global MonitorStatusLight := 0
global MonitorSourceAppText := 0
global MonitorDataTypeText := 0
global MonitorCharCountText := 0
global MonitorContentPreview := 0
global MonitorTodayTotalText := 0
global MonitorImageCountText := 0
global MonitorFailCountText := 0
global MonitorLogEdit := 0
global MonitorIsVisible := false
global MonitorLastRecordID := 0
global MonitorTodayStats := Map("Total", 0, "Images", 0, "Fails", 0)
global MonitorDebounceFiltered := 0
global MonitorLastSuccessTime := 0
global MonitorDebounceText := 0
global MonitorFlashOriginalBg := ""
global MonitorAutoShow := false  ; 是否自动显示监控窗口（入库时）

; 暗黑模式配色
MonitorColors := {
    Background: "1e1e1e",
    Border: "3c3c3c",
    Text: "cccccc",
    TextDim: "888888",
    StatusGreen: "00ff00",
    StatusRed: "ff0000",
    InputBg: "2d2d30",
    LogBg: "252526"
}

; ===================== 显示/隐藏监控窗口 =====================
ShowClipboardMonitor() {
    global GuiID_ClipboardMonitor, MonitorIsVisible
    
    if (MonitorIsVisible && GuiID_ClipboardMonitor != 0) {
        try {
            GuiID_ClipboardMonitor.Show()
            return
        }
    }
    
    CreateClipboardMonitorGUI()
    RefreshMonitorData()
    
    ; 显示窗口
    GuiID_ClipboardMonitor.Show("w600 h500")
    MonitorIsVisible := true
    
    ; 添加初始日志
    AddMonitorLog("监控窗口已打开")
    AddMonitorLog("等待剪贴板变化...")
    
    ; 启动定时刷新（每2秒刷新一次统计数据）
    SetTimer(RefreshMonitorData, 2000)
}

HideClipboardMonitor() {
    global GuiID_ClipboardMonitor, MonitorIsVisible
    
    if (GuiID_ClipboardMonitor != 0) {
        GuiID_ClipboardMonitor.Hide()
        MonitorIsVisible := false
        SetTimer(RefreshMonitorData, 0)  ; 停止定时刷新
    }
}

ToggleClipboardMonitor() {
    global MonitorIsVisible
    
    if (MonitorIsVisible) {
        HideClipboardMonitor()
    } else {
        ShowClipboardMonitor()
    }
}

; ===================== 创建监控 GUI =====================
CreateClipboardMonitorGUI() {
    global GuiID_ClipboardMonitor, MonitorStatusLight
    global MonitorSourceAppText, MonitorDataTypeText, MonitorCharCountText
    global MonitorContentPreview, MonitorTodayTotalText, MonitorImageCountText, MonitorFailCountText
    global MonitorLogEdit, MonitorColors
    
    ; 如果已存在，先销毁
    if (GuiID_ClipboardMonitor != 0) {
        try {
            GuiID_ClipboardMonitor.Destroy()
        }
    }
    
    ; 创建 GUI（置顶，无边框样式但保留标题栏）
    GuiID_ClipboardMonitor := Gui("+AlwaysOnTop -Resize", "剪贴板入库监控")
    GuiID_ClipboardMonitor.BackColor := MonitorColors.Background
    GuiID_ClipboardMonitor.SetFont("s9 c" . MonitorColors.Text, "Segoe UI")
    
    ; 窗口关闭事件
    GuiID_ClipboardMonitor.OnEvent("Close", OnMonitorClose)
    
    ; ========== 标题栏 ==========
    GuiID_ClipboardMonitor.Add("Text", "x10 y10 w580 h25 Center", "剪贴板入库实时监控")
    GuiID_ClipboardMonitor.SetFont("s11 Bold", "Segoe UI")
    
    ; ========== 实时看板区域 ==========
    GuiID_ClipboardMonitor.SetFont("s9", "Segoe UI")
    GuiID_ClipboardMonitor.Add("Text", "x10 y40 w100 h20", "入库状态:")
    MonitorStatusLight := GuiID_ClipboardMonitor.Add("Text", "x120 y40 w20 h20 Background" . MonitorColors.StatusGreen, "●")
    MonitorStatusLight.SetFont("s16", "Segoe UI")
    
    GuiID_ClipboardMonitor.Add("Text", "x10 y65 w100 h20", "来源进程:")
    MonitorSourceAppText := GuiID_ClipboardMonitor.Add("Text", "x120 y65 w470 h20 c" . MonitorColors.TextDim, "等待中...")
    
    GuiID_ClipboardMonitor.Add("Text", "x10 y90 w100 h20", "内容类型:")
    MonitorDataTypeText := GuiID_ClipboardMonitor.Add("Text", "x120 y90 w200 h20", "等待中...")
    
    GuiID_ClipboardMonitor.Add("Text", "x330 y90 w100 h20", "字符数:")
    MonitorCharCountText := GuiID_ClipboardMonitor.Add("Text", "x400 y90 w190 h20", "0")
    
    ; ========== 内容预览 ==========
    GuiID_ClipboardMonitor.Add("Text", "x10 y115 w580 h20", "内容预览 (最新150字符):")
    MonitorContentPreview := GuiID_ClipboardMonitor.Add("Edit", 
        "x10 y135 w580 h80 " .
        "Background" . MonitorColors.InputBg . 
        " c" . MonitorColors.Text . 
        " +ReadOnly +Multi +VScroll -HScroll", 
        "等待数据...")
    MonitorContentPreview.SetFont("s8", "Consolas")
    
    ; ========== 统计面板 ==========
    GuiID_ClipboardMonitor.Add("Text", "x10 y225 w580 h20", "今日统计:")
    GuiID_ClipboardMonitor.Add("Text", "x10 y250 w150 h20", "今日捕获总数:")
    MonitorTodayTotalText := GuiID_ClipboardMonitor.Add("Text", "x170 y250 w100 h20", "0")
    
    GuiID_ClipboardMonitor.Add("Text", "x280 y250 w100 h20", "图片数:")
    MonitorImageCountText := GuiID_ClipboardMonitor.Add("Text", "x390 y250 w100 h20", "0")
    
    GuiID_ClipboardMonitor.Add("Text", "x10 y275 w150 h20", "入库失败次数:")
    MonitorFailCountText := GuiID_ClipboardMonitor.Add("Text", "x170 y275 w100 h20 c" . MonitorColors.StatusRed, "0")
    
    MonitorDebounceText := GuiID_ClipboardMonitor.Add("Text", "x280 y275 w200 h20 c" . MonitorColors.TextDim, "防抖过滤: 0 次")
    
    ; ========== 自检按钮 ==========
    SelfCheckBtn := GuiID_ClipboardMonitor.Add("Button", "x10 y305 w150 h30", "运行环境自检")
    SelfCheckBtn.OnEvent("Click", OnSelfCheckClick)
    
    ; ========== 日志区域 ==========
    GuiID_ClipboardMonitor.Add("Text", "x10 y345 w580 h20", "操作日志:")
    MonitorLogEdit := GuiID_ClipboardMonitor.Add("Edit", 
        "x10 y365 w580 h120 " .
        "Background" . MonitorColors.LogBg . 
        " c" . MonitorColors.TextDim . 
        " +ReadOnly +Multi +VScroll -HScroll", 
        "")
    MonitorLogEdit.SetFont("s8", "Consolas")
    
    ; 添加初始日志
    AddMonitorLog("监控窗口已启动")
}

; ===================== 刷新监控数据 =====================
RefreshMonitorData() {
    global ClipboardFTS5DB, MonitorLastRecordID, MonitorTodayStats
    global MonitorSourceAppText, MonitorDataTypeText, MonitorCharCountText
    global MonitorContentPreview, MonitorTodayTotalText, MonitorImageCountText, MonitorFailCountText
    global MonitorStatusLight, MonitorColors
    
    if (!ClipboardFTS5DB || ClipboardFTS5DB = 0) {
        UpdateStatusLight(false, "数据库未连接")
        return
    }
    
    try {
        ; 获取最新一条记录（使用 GetTable 方法）
        SQL := "SELECT ID, Content, SourceApp, DataType, CharCount, Timestamp " .
               "FROM ClipMain " .
               "ORDER BY ID DESC " .
               "LIMIT 1"
        
        table := ""
        if (ClipboardFTS5DB.GetTable(SQL, &table, 1)) {
            if (table.HasRows && table.Rows.Length > 0) {
                row := table.Rows[1]
                recordID := row[1]  ; ID
                
                ; 如果是最新记录，更新显示
                if (recordID != MonitorLastRecordID) {
                    MonitorLastRecordID := recordID
                    
                    content := row[2]      ; Content
                    sourceApp := row[3]    ; SourceApp
                    dataType := row[4]     ; DataType
                    charCount := row[5]    ; CharCount
                    timestamp := row[6]    ; Timestamp
                    
                    ; 更新显示
                    MonitorSourceAppText.Text := sourceApp
                    MonitorDataTypeText.Text := dataType
                    MonitorCharCountText.Text := charCount
                    
                    ; 更新内容预览（前150字符）
                    preview := content
                    if (StrLen(preview) > 150) {
                        preview := SubStr(preview, 1, 150) . "..."
                    }
                    MonitorContentPreview.Value := preview
                    
                    ; 更新状态灯为绿色
                    UpdateStatusLight(true, "")
                }
            }
        }
        
        ; 更新今日统计
        UpdateTodayStats()
        
    } catch as err {
        UpdateStatusLight(false, err.Message)
        AddMonitorLog("刷新数据错误: " . err.Message)
    }
}

; ===================== 更新今日统计 =====================
UpdateTodayStats() {
    global ClipboardFTS5DB, MonitorTodayStats
    global MonitorTodayTotalText, MonitorImageCountText, MonitorFailCountText
    global MonitorDebounceFiltered
    
    if (!ClipboardFTS5DB || ClipboardFTS5DB = 0) {
        return
    }
    
    try {
        ; 获取今日开始时间
        todayStart := FormatTime(A_Now, "yyyy-MM-dd") . " 00:00:00"
        
        ; 今日总数（使用 GetTable，需要转义单引号）
        escapedTodayStart := StrReplace(todayStart, "'", "''")
        SQL := "SELECT COUNT(*) FROM ClipMain WHERE Timestamp >= '" . escapedTodayStart . "'"
        table := ""
        if (ClipboardFTS5DB.GetTable(SQL, &table, 1)) {
            if (table.HasRows && table.Rows.Length > 0) {
                MonitorTodayStats["Total"] := table.Rows[1][1]
            }
        }
        
        ; 今日图片数
        SQL := "SELECT COUNT(*) FROM ClipMain WHERE DataType = 'Image' AND Timestamp >= '" . escapedTodayStart . "'"
        table := ""
        if (ClipboardFTS5DB.GetTable(SQL, &table, 1)) {
            if (table.HasRows && table.Rows.Length > 0) {
                MonitorTodayStats["Images"] := table.Rows[1][1]
            }
        }
        
        ; 更新显示
        MonitorTodayTotalText.Text := MonitorTodayStats["Total"]
        MonitorImageCountText.Text := MonitorTodayStats["Images"]
        MonitorFailCountText.Text := MonitorTodayStats["Fails"]
        
        ; 更新防抖过滤显示（通过全局变量引用）
        global MonitorDebounceText
        if (MonitorDebounceText && MonitorDebounceFiltered > 0) {
            MonitorDebounceText.Text := "防抖过滤: " . MonitorDebounceFiltered . " 次"
        }
        
    } catch as err {
        AddMonitorLog("更新统计错误: " . err.Message)
    }
}

; ===================== 更新状态灯 =====================
UpdateStatusLight(isSuccess, errorMsg := "") {
    global MonitorStatusLight, MonitorColors, MonitorFailCountText, MonitorTodayStats
    
    if (isSuccess) {
        MonitorStatusLight.BackColor := MonitorColors.StatusGreen
        MonitorStatusLight.Text := "●"
    } else {
        MonitorStatusLight.BackColor := MonitorColors.StatusRed
        MonitorStatusLight.Text := "●"
        if (errorMsg != "") {
            MonitorStatusLight.ToolTip := "错误: " . errorMsg
        }
    }
}

; ===================== 添加日志 =====================
AddMonitorLog(message) {
    global MonitorLogEdit
    
    if (!MonitorLogEdit) {
        return
    }
    
    timestamp := FormatTime(, "HH:mm:ss")
    logEntry := "[" . timestamp . "] " . message . "`r`n"
    
    ; 追加到日志（保持最后50行）
    currentLog := MonitorLogEdit.Value
    logLines := StrSplit(currentLog, "`r`n")
    
    ; 如果超过50行，删除最旧的
    if (logLines.Length > 50) {
        logLines.RemoveAt(1, logLines.Length - 50)
    }
    
    ; 添加新日志
    logLines.Push("[" . timestamp . "] " . message)
    MonitorLogEdit.Value := Array_Join(logLines, "`r`n")
    
    ; 滚动到底部
    try {
        ; 使用 ControlSend 滚动到底部
        ControlSend("{End}", MonitorLogEdit)
        Sleep(10)
        ControlSend("^{End}", MonitorLogEdit)
    } catch {
        ; 忽略错误
    }
}

; 辅助函数：数组连接
Array_Join(arr, delimiter) {
    result := ""
    for index, item in arr {
        if (index > 1) {
            result .= delimiter
        }
        result .= item
    }
    return result
}

; ===================== 记录入库成功 =====================
RecordInsertSuccess(sourceApp, dataType, charCount, content) {
    global MonitorLastSuccessTime, MonitorIsVisible, MonitorAutoShow
    
    ; 更新成功时间
    MonitorLastSuccessTime := A_TickCount
    
    ; 如果设置了自动显示，且窗口未打开，则打开窗口
    if (MonitorAutoShow && !MonitorIsVisible) {
        ShowClipboardMonitor()
    }
    
    ; 如果监控窗口打开，更新GUI
    if (MonitorIsVisible) {
        ; 添加日志
        AddMonitorLog("成功入库: " . sourceApp . " (" . dataType . ", " . charCount . " 字符)")
        
        ; 触发绿色闪烁
        FlashMonitorWindow()
        
        ; 延迟刷新数据（避免频繁刷新）
        SetTimer(() => RefreshMonitorData(), -500)
    } else {
        ; 即使窗口未打开，也显示托盘提示
        preview := content
        if (StrLen(preview) > 50) {
            preview := SubStr(preview, 1, 50) . "..."
        }
        TrayTip("入库成功", sourceApp . " (" . dataType . ", " . charCount . " 字符)`n" . preview, "Iconi 1")
    }
}

; ===================== 记录入库失败 =====================
RecordInsertFail(errorMsg, errorCode := "") {
    global MonitorTodayStats, MonitorFailCountText, MonitorIsVisible
    
    ; 增加失败计数
    MonitorTodayStats["Fails"]++
    
    ; 如果监控窗口打开，更新GUI
    if (MonitorIsVisible) {
        MonitorFailCountText.Text := MonitorTodayStats["Fails"]
        
        ; 更新状态灯
        UpdateStatusLight(false, errorMsg)
        
        ; 添加日志
        logMsg := "错误: " . errorMsg
        if (errorCode != "") {
            logMsg .= " (错误码: " . errorCode . ")"
        }
        AddMonitorLog(logMsg)
    } else {
        ; 即使窗口未打开，也显示托盘提示
        logMsg := "入库失败: " . errorMsg
        if (errorCode != "") {
            logMsg .= " (错误码: " . errorCode . ")"
        }
        TrayTip("入库失败", logMsg, "Iconx 2")
    }
}

; ===================== 记录防抖过滤 =====================
RecordDebounceFiltered() {
    global MonitorDebounceFiltered, MonitorIsVisible, MonitorDebounceText
    
    if (!MonitorIsVisible) {
        return
    }
    
    MonitorDebounceFiltered++
    AddMonitorLog("防抖过滤: 重复请求被过滤 (300ms)")
    
    ; 更新显示
    if (MonitorDebounceText) {
        MonitorDebounceText.Text := "防抖过滤: " . MonitorDebounceFiltered . " 次"
    }
}

; ===================== 窗口闪烁效果 =====================
FlashMonitorWindow() {
    global GuiID_ClipboardMonitor, MonitorColors, MonitorFlashOriginalBg
    
    if (!GuiID_ClipboardMonitor || GuiID_ClipboardMonitor = 0) {
        return
    }
    
    try {
        ; 闪烁绿色边框（通过临时改变背景色实现）
        MonitorFlashOriginalBg := GuiID_ClipboardMonitor.BackColor
        GuiID_ClipboardMonitor.BackColor := MonitorColors.StatusGreen
        
        ; 200ms后恢复
        SetTimer(RestoreMonitorWindowBg, -200)
        
    } catch {
        ; 忽略错误
    }
}

; ===================== 恢复窗口背景色 =====================
RestoreMonitorWindowBg() {
    global GuiID_ClipboardMonitor, MonitorFlashOriginalBg
    
    try {
        if (GuiID_ClipboardMonitor && GuiID_ClipboardMonitor != 0) {
            GuiID_ClipboardMonitor.BackColor := MonitorFlashOriginalBg
        }
    } catch {
    }
}

; ===================== 环境自检 =====================
OnSelfCheckClick(*) {
    global MainScriptDir
    
    AddMonitorLog("开始运行环境自检...")
    
    ; 1. 检查 sqlite3.dll
    ScriptDir := (IsSet(MainScriptDir) ? MainScriptDir : A_ScriptDir)
    dllPath := ScriptDir "\sqlite3.dll"
    if (FileExist(dllPath)) {
        AddMonitorLog("✓ sqlite3.dll 存在: " . dllPath)
    } else {
        AddMonitorLog("✗ sqlite3.dll 未找到: " . dllPath)
    }
    
    ; 2. 检查 Clipboard.db 写入权限
    dbPath := ScriptDir "\Clipboard.db"
    if (FileExist(dbPath)) {
        ; 尝试打开文件进行写入测试
        try {
            testFile := FileOpen(dbPath, "a")
            if (testFile) {
                testFile.Close()
                AddMonitorLog("✓ Clipboard.db 具有写入权限")
            } else {
                AddMonitorLog("✗ Clipboard.db 无法写入")
            }
        } catch as err {
            AddMonitorLog("✗ Clipboard.db 写入测试失败: " . err.Message)
        }
    } else {
        AddMonitorLog("⚠ Clipboard.db 不存在（首次运行将自动创建）")
    }
    
    ; 3. 检查数据库连接
    global ClipboardFTS5DB
    if (ClipboardFTS5DB && ClipboardFTS5DB != 0) {
        AddMonitorLog("✓ 数据库连接正常")
        
        ; 检查表是否存在（使用 GetTable 方法）
        try {
            SQL := "SELECT name FROM sqlite_master WHERE type='table' AND name='ClipMain'"
            table := ""
            if (ClipboardFTS5DB.GetTable(SQL, &table)) {
                if (table.HasRows && table.Rows.Length > 0) {
                    AddMonitorLog("✓ ClipMain 表存在")
                } else {
                    AddMonitorLog("✗ ClipMain 表不存在")
                }
            } else {
                AddMonitorLog("✗ 检查表结构失败: " . ClipboardFTS5DB.ErrorMsg)
            }
        } catch as err {
            AddMonitorLog("✗ 检查表结构失败: " . err.Message)
        }
    } else {
        AddMonitorLog("✗ 数据库未连接")
    }
    
    ; 4. 检查 WAL 模式（使用 GetTable 方法）
    try {
        if (ClipboardFTS5DB && ClipboardFTS5DB != 0) {
            SQL := "PRAGMA journal_mode"
            table := ""
            if (ClipboardFTS5DB.GetTable(SQL, &table)) {
                if (table.HasRows && table.Rows.Length > 0) {
                    journalMode := table.Rows[1][1]  ; 第一行第一列
                    if (journalMode = "wal") {
                        AddMonitorLog("✓ WAL 模式已启用")
                    } else {
                        AddMonitorLog("⚠ 日志模式: " . journalMode . " (建议使用 WAL)")
                    }
                } else {
                    AddMonitorLog("⚠ 无法获取日志模式信息")
                }
            } else {
                AddMonitorLog("✗ 检查 WAL 模式失败: " . ClipboardFTS5DB.ErrorMsg)
            }
        }
    } catch as err {
        AddMonitorLog("✗ 检查 WAL 模式失败: " . err.Message)
    }
    
    AddMonitorLog("环境自检完成")
}

; ===================== 窗口关闭事件 =====================
OnMonitorClose(*) {
    HideClipboardMonitor()
}

; ===================== 增强的入库函数（带监控）=====================
; 包装 SaveToClipboardFTS5，添加监控功能
SaveToClipboardFTS5WithMonitor(content, SourceApp := "Unknown") {
    global ClipboardFTS5DB
    
    ; 分类内容类型（在入库前获取，用于监控显示）
    dataType := ClassifyContentType(content)
    charCount := StrLen(content)
    
    ; 尝试入库
    result := SaveToClipboardFTS5(content, SourceApp)
    
    if (result) {
        ; 入库成功
        RecordInsertSuccess(SourceApp, dataType, charCount, content)
        return true
    } else {
        ; 入库失败
        errorMsg := "入库失败"
        if (ClipboardFTS5DB && ClipboardFTS5DB != 0) {
            errorMsg := ClipboardFTS5DB.ErrorMsg
        }
        RecordInsertFail(errorMsg, ClipboardFTS5DB ? ClipboardFTS5DB.ErrorCode : "")
        return false
    }
}

; 包装 CaptureClipboardImageToFTS5，添加监控功能
CaptureClipboardImageToFTS5WithMonitor(SourceApp) {
    global ClipboardFTS5DB
    
    ; 尝试入库
    result := CaptureClipboardImageToFTS5(SourceApp)
    
    if (result) {
        ; 入库成功
        RecordInsertSuccess(SourceApp, "Image", 0, "[图片]")
        return true
    } else {
        ; 入库失败
        errorMsg := "图片入库失败"
        if (ClipboardFTS5DB && ClipboardFTS5DB != 0) {
            errorMsg := ClipboardFTS5DB.ErrorMsg
        }
        RecordInsertFail(errorMsg, ClipboardFTS5DB ? ClipboardFTS5DB.ErrorCode : "")
        return false
    }
}

; ===================== 增强的剪贴板处理函数（带监控）=====================
; 这个函数可以替换或包装 ProcessClipboardChange 中的数据库操作部分
ProcessClipboardChangeWithMonitor(Type) {
    global ClipboardFTS5DB
    
    ; 如果 CapsLock+C 正在进行中，不记录（检查变量是否存在）
    try {
        if (IsSet(CapsLockCopyInProgress) && CapsLockCopyInProgress) {
            return
        }
    } catch {
        ; 变量未定义，继续执行
    }
    
    if (Type = 0 || A_PtrSize = "") {
        return
    }
    
    try {
        ; 获取来源应用
        SourceApp := "Unknown"
        try {
            SourceApp := WinGetProcessName("A")
        } catch {
            SourceApp := "Unknown"
        }
        
        if (Type = 1) {
            ; 文本类型
            content := A_Clipboard
            if (content != "" && ClipboardFTS5DB && ClipboardFTS5DB != 0) {
                SaveToClipboardFTS5WithMonitor(content, SourceApp)
            }
        } else if (Type = 2) {
            ; 图片类型
            if (ClipboardFTS5DB && ClipboardFTS5DB != 0) {
                CaptureClipboardImageToFTS5WithMonitor(SourceApp)
            }
        }
    } catch as err {
        RecordInsertFail("处理剪贴板变化异常: " . err.Message)
    }
}

; ===================== 设置自动显示监控窗口 =====================
SetMonitorAutoShow(enable := true) {
    global MonitorAutoShow
    MonitorAutoShow := enable
}

; ===================== 初始化监控器 =====================
InitClipboardMonitor(autoShow := false) {
    global MonitorAutoShow
    
    ; 确保数据库已初始化
    if (!ClipboardFTS5DB || ClipboardFTS5DB = 0) {
        InitClipboardFTS5DB()
    }
    
    ; 设置自动显示选项
    MonitorAutoShow := autoShow
    
    ; 如果设置了自动显示，立即打开窗口
    if (autoShow) {
        ShowClipboardMonitor()
        ; 添加初始日志
        AddMonitorLog("监控器已初始化（自动显示模式）")
    }
    ; 注意：如果未设置自动显示，窗口会在用户手动打开时初始化
}
