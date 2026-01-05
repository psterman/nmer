; ======================================================================================================================
; 剪贴板调试面板 - 诊断复制数据未显示问题
; 版本: 1.0.0
; 功能: 
;   - 实时显示剪贴板监听状态
;   - 显示数据保存流程的每一步
;   - 显示错误信息和调试日志
;   - 测试各个功能模块
; ======================================================================================================================

#Requires AutoHotkey v2.0
#Include ClipboardFTS5.ahk

; ===================== 全局变量 =====================
global GuiID_ClipboardDebug := 0
global DebugIsVisible := false
global DebugLogEdit := 0
global DebugStatusText := 0
global DebugClipboardListenerStatus := 0
global DebugDatabaseStatus := 0
global DebugLastClipboardContent := ""
global DebugEventCount := 0
global DebugSaveCount := 0
global DebugFailCount := 0
global DebugEventCountText := 0
global DebugSaveCountText := 0
global DebugFailCountText := 0
global DebugLastClipboardText := 0

; 暗黑模式配色
DebugColors := {
    Background: "1e1e1e",
    Text: "cccccc",
    TextDim: "888888",
    InputBg: "2d2d30",
    LogBg: "252526",
    StatusGreen: "00ff00",
    StatusRed: "ff0000",
    StatusYellow: "ffff00"
}

; ===================== 显示/隐藏调试面板 =====================
ShowClipboardDebugPanel() {
    global GuiID_ClipboardDebug, DebugIsVisible
    
    if (DebugIsVisible && GuiID_ClipboardDebug != 0) {
        try {
            GuiID_ClipboardDebug.Show()
            RefreshDebugStatus()
        }
        return
    }
    
    CreateDebugPanelGUI()
    RefreshDebugStatus()
    
    ; 显示窗口
    GuiID_ClipboardDebug.Show("w800 h700")
    DebugIsVisible := true
    
    ; 启动定时刷新（每1秒刷新一次状态）
    SetTimer(RefreshDebugStatus, 1000)
}

HideClipboardDebugPanel() {
    global GuiID_ClipboardDebug, DebugIsVisible
    
    if (GuiID_ClipboardDebug != 0) {
        GuiID_ClipboardDebug.Hide()
        DebugIsVisible := false
        SetTimer(RefreshDebugStatus, 0)  ; 停止定时刷新
    }
}

ToggleClipboardDebugPanel() {
    global DebugIsVisible
    
    if (DebugIsVisible) {
        HideClipboardDebugPanel()
    } else {
        ShowClipboardDebugPanel()
    }
}

; ===================== 创建调试 GUI =====================
CreateDebugPanelGUI() {
    global GuiID_ClipboardDebug, DebugLogEdit, DebugStatusText
    global DebugClipboardListenerStatus, DebugDatabaseStatus
    global DebugColors
    
    ; 如果已存在，先销毁
    if (GuiID_ClipboardDebug != 0) {
        try {
            GuiID_ClipboardDebug.Destroy()
        }
    }
    
    ; 创建 GUI（置顶）
    GuiID_ClipboardDebug := Gui("+AlwaysOnTop -Resize", "剪贴板调试面板")
    GuiID_ClipboardDebug.BackColor := DebugColors.Background
    GuiID_ClipboardDebug.SetFont("s9 c" . DebugColors.Text, "Segoe UI")
    
    ; 窗口关闭事件
    GuiID_ClipboardDebug.OnEvent("Close", OnDebugPanelClose)
    
    ; ========== 标题 ==========
    GuiID_ClipboardDebug.Add("Text", "x10 y10 w780 h25 Center", "剪贴板数据流调试面板")
    GuiID_ClipboardDebug.SetFont("s11 Bold", "Segoe UI")
    
    ; ========== 状态区域 ==========
    GuiID_ClipboardDebug.SetFont("s9", "Segoe UI")
    GuiID_ClipboardDebug.Add("Text", "x10 y40 w200 h20", "剪贴板监听器:")
    DebugClipboardListenerStatus := GuiID_ClipboardDebug.Add("Text", "x220 y40 w200 h20 c" . DebugColors.StatusRed, "未激活")
    
    GuiID_ClipboardDebug.Add("Text", "x10 y65 w200 h20", "数据库连接:")
    DebugDatabaseStatus := GuiID_ClipboardDebug.Add("Text", "x220 y65 w200 h20 c" . DebugColors.StatusRed, "未连接")
    
    GuiID_ClipboardDebug.Add("Text", "x10 y90 w200 h20", "最后剪贴板内容:")
    DebugLastClipboardText := GuiID_ClipboardDebug.Add("Text", "x220 y90 w550 h20 c" . DebugColors.TextDim, "无")
    
    ; ========== 统计信息 ==========
    GuiID_ClipboardDebug.Add("Text", "x10 y120 w780 h20", "统计信息:")
    GuiID_ClipboardDebug.Add("Text", "x10 y145 w150 h20", "监听事件数:")
    DebugEventCountText := GuiID_ClipboardDebug.Add("Text", "x170 y145 w100 h20", "0")
    
    GuiID_ClipboardDebug.Add("Text", "x280 y145 w150 h20", "成功保存数:")
    DebugSaveCountText := GuiID_ClipboardDebug.Add("Text", "x440 y145 w100 h20 c" . DebugColors.StatusGreen, "0")
    
    GuiID_ClipboardDebug.Add("Text", "x550 y145 w150 h20", "失败次数:")
    DebugFailCountText := GuiID_ClipboardDebug.Add("Text", "x710 y145 w100 h20 c" . DebugColors.StatusRed, "0")
    
    ; ========== 测试按钮 ==========
    TestListenerBtn := GuiID_ClipboardDebug.Add("Button", "x10 y175 w150 h30", "测试监听器")
    TestListenerBtn.OnEvent("Click", OnTestListenerClick)
    
    TestDatabaseBtn := GuiID_ClipboardDebug.Add("Button", "x170 y175 w150 h30", "测试数据库")
    TestDatabaseBtn.OnEvent("Click", OnTestDatabaseClick)
    
    TestSaveBtn := GuiID_ClipboardDebug.Add("Button", "x330 y175 w150 h30", "测试保存")
    TestSaveBtn.OnEvent("Click", OnTestSaveClick)
    
    ClearLogBtn := GuiID_ClipboardDebug.Add("Button", "x490 y175 w150 h30", "清空日志")
    ClearLogBtn.OnEvent("Click", OnClearLogClick)
    
    ; ========== 日志区域 ==========
    GuiID_ClipboardDebug.Add("Text", "x10 y215 w780 h20", "调试日志:")
    DebugLogEdit := GuiID_ClipboardDebug.Add("Edit", 
        "x10 y235 w780 h450 " .
        "Background" . DebugColors.LogBg . 
        " c" . DebugColors.TextDim . 
        " +ReadOnly +Multi +VScroll -HScroll", 
        "")
    DebugLogEdit.SetFont("s8", "Consolas")
    
    ; 添加初始日志
    AddDebugLog("调试面板已启动")
    AddDebugLog("等待剪贴板事件...")
}

; ===================== 添加调试日志 =====================
AddDebugLog(message) {
    global DebugLogEdit, DebugEventCount
    
    if (!DebugLogEdit) {
        return
    }
    
    timestamp := FormatTime(, "HH:mm:ss.fff")
    logEntry := "[" . timestamp . "] " . message . "`r`n"
    
    ; 追加到日志（保持最后200行）
    currentLog := DebugLogEdit.Value
    logLines := StrSplit(currentLog, "`r`n")
    
    ; 如果超过200行，删除最旧的
    if (logLines.Length > 200) {
        logLines.RemoveAt(1, logLines.Length - 200)
    }
    
    ; 添加新日志
    logLines.Push("[" . timestamp . "] " . message)
    DebugLogEdit.Value := Array_Join_Debug(logLines, "`r`n")
    
    ; 滚动到底部
    try {
        ControlSend("{End}", DebugLogEdit)
        Sleep(10)
        ControlSend("^{End}", DebugLogEdit)
    } catch {
    }
}

; 辅助函数：数组连接
Array_Join_Debug(arr, delimiter) {
    result := ""
    for index, item in arr {
        if (index > 1) {
            result .= delimiter
        }
        result .= item
    }
    return result
}

; ===================== 刷新调试状态 =====================
RefreshDebugStatus() {
    global ClipboardFTS5DB, DebugLastClipboardContent
    global DebugClipboardListenerStatus, DebugDatabaseStatus
    global DebugEventCount, DebugSaveCount, DebugFailCount
    global DebugEventCountText, DebugSaveCountText, DebugFailCountText, DebugLastClipboardText
    global DebugColors
    
    if (!GuiID_ClipboardDebug || GuiID_ClipboardDebug = 0) {
        return
    }
    
    ; 更新剪贴板监听器状态
    ; 注意：这里只能检查是否注册了，无法直接检测是否工作
    if (DebugClipboardListenerStatus) {
        DebugClipboardListenerStatus.Text := "已注册"
        DebugClipboardListenerStatus.TextColor := DebugColors.StatusGreen
    }
    
    ; 更新数据库状态
    if (DebugDatabaseStatus) {
        if (ClipboardFTS5DB && ClipboardFTS5DB != 0) {
            DebugDatabaseStatus.Text := "已连接"
            DebugDatabaseStatus.TextColor := DebugColors.StatusGreen
        } else {
            DebugDatabaseStatus.Text := "未连接"
            DebugDatabaseStatus.TextColor := DebugColors.StatusRed
        }
    }
    
    ; 更新最后剪贴板内容
    if (DebugLastClipboardText) {
        try {
            currentContent := A_Clipboard
            if (currentContent != "" && StrLen(currentContent) > 0) {
                preview := currentContent
                if (StrLen(preview) > 50) {
                    preview := SubStr(preview, 1, 50) . "..."
                }
                preview := StrReplace(preview, "`r`n", " ")
                preview := StrReplace(preview, "`n", " ")
                preview := StrReplace(preview, "`r", " ")
                DebugLastClipboardText.Text := preview
            } else {
                DebugLastClipboardText.Text := "无内容"
            }
        } catch {
            DebugLastClipboardText.Text := "无法读取"
        }
    }
    
    ; 更新统计信息
    if (DebugEventCountText) {
        DebugEventCountText.Text := DebugEventCount
    }
    if (DebugSaveCountText) {
        DebugSaveCountText.Text := DebugSaveCount
    }
    if (DebugFailCountText) {
        DebugFailCountText.Text := DebugFailCount
    }
}

; ===================== 测试监听器 =====================
OnTestListenerClick(*) {
    AddDebugLog("========== 测试剪贴板监听器 ==========")
    
    ; 检查 OnClipboardChange 是否注册
    AddDebugLog("检查 OnClipboardChange 注册状态...")
    
    ; 尝试读取当前剪贴板内容
    try {
        content := A_Clipboard
        if (content != "") {
            AddDebugLog("✓ 当前剪贴板内容: " . SubStr(content, 1, 100))
            AddDebugLog("✓ 剪贴板可读取，监听器应该正常工作")
        } else {
            AddDebugLog("⚠ 当前剪贴板为空")
        }
    } catch as err {
        AddDebugLog("✗ 无法读取剪贴板: " . err.Message)
    }
    
    AddDebugLog("提示: 请尝试复制一些文本，观察是否触发事件")
}

; ===================== 测试数据库 =====================
OnTestDatabaseClick(*) {
    global ClipboardFTS5DB
    
    AddDebugLog("========== 测试数据库连接 ==========")
    
    if (!ClipboardFTS5DB || ClipboardFTS5DB = 0) {
        AddDebugLog("✗ 数据库未初始化")
        AddDebugLog("尝试初始化数据库...")
        if (InitClipboardFTS5DB()) {
            AddDebugLog("✓ 数据库初始化成功")
        } else {
            AddDebugLog("✗ 数据库初始化失败")
        }
        return
    }
    
    AddDebugLog("✓ 数据库对象存在")
    
    ; 测试查询
    try {
        SQL := "SELECT COUNT(*) FROM ClipMain"
        table := ""
        if (ClipboardFTS5DB.GetTable(SQL, &table)) {
            if (table.HasRows && table.Rows.Length > 0) {
                count := table.Rows[1][1]
                AddDebugLog("✓ 数据库查询成功，当前记录数: " . count)
            } else {
                AddDebugLog("⚠ 数据库查询成功，但无数据")
            }
        } else {
            AddDebugLog("✗ 数据库查询失败: " . ClipboardFTS5DB.ErrorMsg)
        }
    } catch as err {
        AddDebugLog("✗ 数据库查询异常: " . err.Message)
    }
    
    ; 测试表结构
    try {
        SQL := "SELECT name FROM sqlite_master WHERE type='table' AND name='ClipMain'"
        table := ""
        if (ClipboardFTS5DB.GetTable(SQL, &table)) {
            if (table.HasRows && table.Rows.Length > 0) {
                AddDebugLog("✓ ClipMain 表存在")
            } else {
                AddDebugLog("✗ ClipMain 表不存在")
            }
        }
    } catch as err {
        AddDebugLog("✗ 检查表结构失败: " . err.Message)
    }
}

; ===================== 测试保存 =====================
OnTestSaveClick(*) {
    global ClipboardFTS5DB, DebugSaveCount, DebugFailCount
    
    AddDebugLog("========== 测试数据保存 ==========")
    
    if (!ClipboardFTS5DB || ClipboardFTS5DB = 0) {
        AddDebugLog("✗ 数据库未连接，无法测试保存")
        return
    }
    
    ; 获取当前剪贴板内容
    try {
        testContent := A_Clipboard
        if (testContent = "" || StrLen(testContent) = 0) {
            testContent := "测试内容 " . A_Now
            A_Clipboard := testContent
            AddDebugLog("⚠ 剪贴板为空，使用测试内容: " . testContent)
        } else {
            AddDebugLog("使用当前剪贴板内容进行测试")
        }
    } catch {
        testContent := "测试内容 " . A_Now
        A_Clipboard := testContent
        AddDebugLog("使用测试内容: " . testContent)
    }
    
    ; 获取来源应用
    SourceApp := "DebugTest"
    try {
        SourceApp := WinGetProcessName("A")
    } catch {
    }
    
    AddDebugLog("尝试保存到数据库...")
    AddDebugLog("内容: " . SubStr(testContent, 1, 100))
    AddDebugLog("来源: " . SourceApp)
    
    ; 尝试保存
    AddDebugLog("调用 SaveToClipboardFTS5...")
    result := SaveToClipboardFTS5(testContent, SourceApp)
    
    if (result) {
        DebugSaveCount++
        AddDebugLog("✓ 保存成功！")
        
        ; 验证保存
        try {
            SQL := "SELECT ID, Content FROM ClipMain ORDER BY ID DESC LIMIT 1"
            table := ""
            if (ClipboardFTS5DB.GetTable(SQL, &table)) {
                if (table.HasRows && table.Rows.Length > 0) {
                    lastID := table.Rows[1][1]
                    lastContent := table.Rows[1][2]
                    AddDebugLog("✓ 验证成功，最后一条记录 ID: " . lastID)
                    AddDebugLog("✓ 内容匹配: " . (lastContent = testContent ? "是" : "否"))
                    if (lastContent != testContent) {
                        AddDebugLog("⚠ 内容不匹配！数据库: " . SubStr(lastContent, 1, 50) . " | 期望: " . SubStr(testContent, 1, 50))
                    }
                } else {
                    AddDebugLog("⚠ 验证失败：查询成功但无数据")
                }
            } else {
                AddDebugLog("✗ 验证失败：无法查询数据库: " . ClipboardFTS5DB.ErrorMsg)
            }
        } catch as err {
            AddDebugLog("✗ 验证保存时出错: " . err.Message)
        }
    } else {
        DebugFailCount++
        errorMsg := "未知错误"
        if (ClipboardFTS5DB && ClipboardFTS5DB != 0) {
            errorMsg := ClipboardFTS5DB.ErrorMsg
            if (errorMsg = "") {
                errorMsg := "保存返回 false，但无错误信息（可能是 Prepare 方法失败）"
            }
        } else {
            errorMsg := "数据库未连接"
        }
        AddDebugLog("✗ 保存失败: " . errorMsg)
        AddDebugLog("提示: 如果错误信息为空，可能是 Prepare 方法的问题，已改用 Exec 方法")
    }
}

; ===================== 清空日志 =====================
OnClearLogClick(*) {
    global DebugLogEdit
    
    if (DebugLogEdit) {
        DebugLogEdit.Value := ""
        AddDebugLog("日志已清空")
    }
}

; ===================== 窗口关闭事件 =====================
OnDebugPanelClose(*) {
    HideClipboardDebugPanel()
}

; ===================== 记录剪贴板事件 =====================
RecordClipboardEvent(eventType, message) {
    global DebugEventCount, DebugIsVisible
    
    if (!DebugIsVisible) {
        return
    }
    
    DebugEventCount++
    AddDebugLog("[" . eventType . "] " . message)
}

; ===================== 记录保存结果 =====================
RecordSaveResult(success, message) {
    global DebugSaveCount, DebugFailCount, DebugIsVisible
    
    if (!DebugIsVisible) {
        return
    }
    
    if (success) {
        DebugSaveCount++
        AddDebugLog("[保存成功] " . message)
    } else {
        DebugFailCount++
        AddDebugLog("[保存失败] " . message)
    }
}

; ===================== 初始化调试面板 =====================
InitClipboardDebugPanel() {
    ; 确保数据库已初始化
    if (!ClipboardFTS5DB || ClipboardFTS5DB = 0) {
        InitClipboardFTS5DB()
    }
    
    AddDebugLog("调试面板已初始化")
}
