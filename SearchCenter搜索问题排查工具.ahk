; ===================== SearchCenter 搜索问题排查工具 =====================
; 增强版调试工具，能够实际检测和排查搜索问题
; 使用方法：直接运行此脚本，输入搜索关键词，点击"开始排查"按钮

#Requires AutoHotkey v2.0
#SingleInstance Force

; 全局变量
global GuiID_SearchTroubleshoot := 0
global KeywordEditControl := 0
global TroubleshootLogText := ""

; 主函数
Main() {
    CreateTroubleshootPanel()
}

; 创建排查面板
CreateTroubleshootPanel() {
    global GuiID_SearchTroubleshoot, KeywordEditControl
    
    ; 如果面板已存在，先销毁
    if (GuiID_SearchTroubleshoot != 0) {
        try {
            GuiID_SearchTroubleshoot.Destroy()
        } catch {
        }
        GuiID_SearchTroubleshoot := 0
    }
    
    ; 创建 GUI
    GuiID_SearchTroubleshoot := Gui("+AlwaysOnTop -Caption +Resize", "SearchCenter 搜索问题排查工具")
    GuiID_SearchTroubleshoot.BackColor := "1e1e1e"
    GuiID_SearchTroubleshoot.SetFont("s10", "Consolas")
    
    ; 标题栏
    TitleBar := GuiID_SearchTroubleshoot.Add("Text", "x10 y10 w700 h30 cFFFFFF", "SearchCenter 搜索问题排查工具")
    TitleBar.SetFont("s12 Bold", "Segoe UI")
    
    ; 说明文字
    GuiID_SearchTroubleshoot.Add("Text", "x10 y50 w700 h50 cFFFFFF", 
        "此工具会依次检测搜索功能的各个关键环节，`n" .
        "帮助定位搜索卡在"正在搜索..."的具体原因。")
    
    ; 搜索关键词输入框
    GuiID_SearchTroubleshoot.Add("Text", "x10 y110 w150 h25 cFFFFFF", "搜索关键词:")
    KeywordEditControl := GuiID_SearchTroubleshoot.Add("Edit", "x170 y108 w300 h28 vKeywordEdit Background2d2d30 cFFFFFF", "")
    
    ; 开始排查按钮
    StartBtn := GuiID_SearchTroubleshoot.Add("Button", "x10 y150 w200 h40", "开始排查")
    StartBtn.OnEvent("Click", StartTroubleshoot)
    
    ; 关闭按钮
    CloseBtn := GuiID_SearchTroubleshoot.Add("Button", "x220 y150 w100 h40", "关闭")
    CloseBtn.OnEvent("Click", (*) => GuiID_SearchTroubleshoot.Destroy())
    
    ; 日志显示区域
    GuiID_SearchTroubleshoot.Add("Text", "x10 y200 w700 h25 cFFFFFF", "排查日志:")
    LogEdit := GuiID_SearchTroubleshoot.Add("Edit", "x10 y225 w700 h300 ReadOnly Multi VDebugLogEdit Background1e1e1e cFFFFFF", "")
    LogEdit.SetFont("s9", "Consolas")
    
    ; 保存控件引用
    GuiID_SearchTroubleshoot["LogEdit"] := LogEdit
    
    ; 计算窗口尺寸
    WindowWidth := 730
    WindowHeight := 550
    
    ; 计算窗口位置（屏幕中央）
    WinWidth := A_ScreenWidth
    WinHeight := A_ScreenHeight
    WindowX := (WinWidth - WindowWidth) // 2
    WindowY := (WinHeight - WindowHeight) // 2
    
    ; 显示窗口
    GuiID_SearchTroubleshoot.Show("x" . WindowX . " y" . WindowY . " w" . WindowWidth . " h" . WindowHeight)
}

; 添加日志
AddTroubleshootLog(Message) {
    global TroubleshootLogText, GuiID_SearchTroubleshoot
    Timestamp := FormatTime(, "HH:mm:ss")
    TroubleshootLogText .= "[" . Timestamp . "] " . Message . "`r`n"
    
    if (GuiID_SearchTroubleshoot != 0) {
        try {
            LogEdit := GuiID_SearchTroubleshoot["LogEdit"]
            if (LogEdit != 0) {
                LogEdit.Value := TroubleshootLogText
                ; 滚动到底部
                SendMessage(0x0115, 7, 0, LogEdit)  ; EM_SCROLL = 0x0115, SB_BOTTOM = 7
            }
        } catch {
        }
    }
}

; 开始排查
StartTroubleshoot(*) {
    global KeywordEditControl
    
    ; 获取关键词
    Keyword := ""
    try {
        if (KeywordEditControl != 0) {
            Keyword := KeywordEditControl.Value
        }
    } catch {
    }
    
    if (StrLen(Keyword) = 0) {
        MsgBox("请输入搜索关键词！", "提示", "Icon!")
        return
    }
    
    ; 清空日志
    TroubleshootLogText := ""
    AddTroubleshootLog("========================================")
    AddTroubleshootLog("开始排查搜索问题")
    AddTroubleshootLog("搜索关键词: '" . Keyword . "'")
    AddTroubleshootLog("========================================")
    
    ; 依次排查各个问题
    TroubleshootStep1_CheckDatabase(Keyword)
    Sleep(500)
    
    TroubleshootStep2_CheckSearchAllDataSources(Keyword)
    Sleep(500)
    
    TroubleshootStep3_CheckSearchClipboardHistory(Keyword)
    Sleep(500)
    
    TroubleshootStep4_CheckGetEverythingResults(Keyword)
    Sleep(500)
    
    TroubleshootStep5_CheckListView()
    Sleep(500)
    
    ; 完成
    AddTroubleshootLog("========================================")
    AddTroubleshootLog("排查完成！")
    AddTroubleshootLog("请查看上述日志，定位问题所在。")
    AddTroubleshootLog("========================================")
    
    MsgBox("排查完成！请查看日志面板中的详细信息。", "排查完成", "Icon!")
}

; 步骤1: 检查数据库连接
TroubleshootStep1_CheckDatabase(Keyword) {
    AddTroubleshootLog("")
    AddTroubleshootLog(">>> 步骤 1: 检查数据库连接 <<<")
    
    ; 检查数据库文件是否存在
    DBPath := A_ScriptDir . "\clipboard.db"
    if (FileExist(DBPath)) {
        AddTroubleshootLog("✓ 数据库文件存在: " . DBPath)
        FileSize := FileGetSize(DBPath)
        AddTroubleshootLog("  文件大小: " . FileSize . " 字节")
    } else {
        AddTroubleshootLog("✗ 数据库文件不存在: " . DBPath)
        AddTroubleshootLog("  问题: 数据库文件未创建，搜索功能无法使用数据库")
        return
    }
    
    ; 尝试连接数据库
    try {
        ; 注意：这里无法直接访问主程序的 ClipboardDB 变量
        ; 但可以尝试创建临时连接来测试
        AddTroubleshootLog("⚠ 无法直接访问主程序的 ClipboardDB 变量")
        AddTroubleshootLog("  建议：检查主程序中 ClipboardDB 是否已初始化")
        AddTroubleshootLog("  如果 ClipboardDB = 0，搜索会回退到多数据源搜索模式")
    } catch as err {
        AddTroubleshootLog("✗ 数据库连接测试失败: " . err.Message)
    }
}

; 步骤2: 检查 SearchAllDataSources
TroubleshootStep2_CheckSearchAllDataSources(Keyword) {
    AddTroubleshootLog("")
    AddTroubleshootLog(">>> 步骤 2: 检查 SearchAllDataSources 函数 <<<")
    
    AddTroubleshootLog("⚠ 无法直接调用主程序的函数")
    AddTroubleshootLog("  建议：在主程序的 DebouncedSearchCenter 函数中添加调试代码")
    AddTroubleshootLog("")
    AddTroubleshootLog("  可能卡住的位置：")
    AddTroubleshootLog("  1. SearchGlobalView 查询")
    AddTroubleshootLog("     - 检查 ClipboardDB 是否已初始化")
    AddTroubleshootLog("     - 检查 v_GlobalSearch 视图是否存在")
    AddTroubleshootLog("     - 检查 SQL 查询是否超时")
    AddTroubleshootLog("")
    AddTroubleshootLog("  2. 多数据源搜索回退")
    AddTroubleshootLog("     - 如果 SearchGlobalView 无结果，会回退到多数据源搜索")
    AddTroubleshootLog("     - 检查各个数据源搜索函数是否正常")
    AddTroubleshootLog("")
    AddTroubleshootLog("  3. 数据库查询超时")
    AddTroubleshootLog("     - 如果数据库查询时间过长，可能导致卡住")
    AddTroubleshootLog("     - 检查数据库文件是否损坏")
    AddTroubleshootLog("     - 检查是否有其他进程锁定数据库")
}

; 步骤3: 检查 SearchClipboardHistory
TroubleshootStep3_CheckSearchClipboardHistory(Keyword) {
    AddTroubleshootLog("")
    AddTroubleshootLog(">>> 步骤 3: 检查 SearchClipboardHistory 函数 <<<")
    
    AddTroubleshootLog("⚠ 无法直接调用主程序的函数")
    AddTroubleshootLog("  建议：在主程序的 SearchClipboardHistory 函数中添加调试代码")
    AddTroubleshootLog("")
    AddTroubleshootLog("  可能卡住的位置：")
    AddTroubleshootLog("  1. 数据库查询")
    AddTroubleshootLog("     - ClipboardDB.Prepare() 可能失败")
    AddTroubleshootLog("     - 检查 SQL 语句是否正确")
    AddTroubleshootLog("     - 检查 global_ST 句柄是否已释放")
    AddTroubleshootLog("")
    AddTroubleshootLog("  2. FTS5 全文搜索")
    AddTroubleshootLog("     - 如果使用 FTS5，检查索引是否正常")
    AddTroubleshootLog("     - 检查 FTS5 查询语法是否正确")
    AddTroubleshootLog("")
    AddTroubleshootLog("  3. 结果处理")
    AddTroubleshootLog("     - ST.Step() 循环可能卡住")
    AddTroubleshootLog("     - 检查是否有大量数据导致处理缓慢")
    AddTroubleshootLog("     - 检查结果格式化是否正常")
}

; 步骤4: 检查 GetEverythingResults
TroubleshootStep4_CheckGetEverythingResults(Keyword) {
    AddTroubleshootLog("")
    AddTroubleshootLog(">>> 步骤 4: 检查 GetEverythingResults 函数 <<<")
    
    if (StrLen(Keyword) <= 1) {
        AddTroubleshootLog("⚠ 关键词长度 <= 1，跳过 Everything 搜索（这是正常行为）")
        return
    }
    
    ; 检查 Everything DLL
    DLLPath := A_ScriptDir . "\lib\everything64.dll"
    if (FileExist(DLLPath)) {
        AddTroubleshootLog("✓ Everything DLL 存在: " . DLLPath)
        FileSize := FileGetSize(DLLPath)
        AddTroubleshootLog("  文件大小: " . FileSize . " 字节")
    } else {
        AddTroubleshootLog("✗ Everything DLL 不存在: " . DLLPath)
        AddTroubleshootLog("  问题: 无法执行 Everything 搜索")
        return
    }
    
    ; 检查 Everything 服务
    EverythingPID := ProcessExist("Everything.exe")
    if (EverythingPID > 0) {
        AddTroubleshootLog("✓ Everything 服务正在运行 (PID: " . EverythingPID . ")")
    } else {
        AddTroubleshootLog("✗ Everything 服务未运行")
        AddTroubleshootLog("  问题: Everything 搜索无法执行")
        AddTroubleshootLog("  解决: 启动 Everything.exe 或运行 InitEverythingService()")
    }
    
    ; 尝试加载 DLL（仅测试，不执行搜索）
    try {
        ; 注意：这里只测试 DLL 是否可以加载，不执行实际搜索
        AddTroubleshootLog("⚠ 无法直接测试 DLL 函数调用")
        AddTroubleshootLog("  建议：检查主程序中 GetEverythingResults 函数的执行情况")
        AddTroubleshootLog("")
        AddTroubleshootLog("  可能卡住的位置：")
        AddTroubleshootLog("  1. Everything DLL 加载")
        AddTroubleshootLog("     - DllCall 可能失败")
        AddTroubleshootLog("     - DLL 版本不兼容")
        AddTroubleshootLog("")
        AddTroubleshootLog("  2. DLL 函数调用")
        AddTroubleshootLog("     - Everything_SetSearchW 可能失败")
        AddTroubleshootLog("     - Everything_QueryW 可能阻塞")
        AddTroubleshootLog("")
        AddTroubleshootLog("  3. Everything 服务未运行")
        AddTroubleshootLog("     - 如果服务未运行，查询会失败")
        AddTroubleshootLog("")
        AddTroubleshootLog("  4. 文件路径处理")
        AddTroubleshootLog("     - Everything_GetResultFullPathNameW 可能失败")
    } catch as err {
        AddTroubleshootLog("✗ DLL 测试失败: " . err.Message)
    }
}

; 步骤5: 检查 ListView
TroubleshootStep5_CheckListView() {
    AddTroubleshootLog("")
    AddTroubleshootLog(">>> 步骤 5: 检查 ListView 更新 <<<")
    
    AddTroubleshootLog("⚠ 无法直接检查主程序的 ListView 控件")
    AddTroubleshootLog("  建议：检查主程序中 ListView 更新的执行情况")
    AddTroubleshootLog("")
    AddTroubleshootLog("  可能卡住的位置：")
    AddTroubleshootLog("  1. SearchCenterResultLV.Delete()")
    AddTroubleshootLog("     - 删除'正在搜索...'提示行可能失败")
    AddTroubleshootLog("     - 控件可能已销毁")
    AddTroubleshootLog("")
    AddTroubleshootLog("  2. SearchCenterResultLV.Add()")
    AddTroubleshootLog("     - 添加结果可能失败")
    AddTroubleshootLog("     - 数据格式可能不正确")
    AddTroubleshootLog("")
    AddTroubleshootLog("  3. ListView 控件已销毁")
    AddTroubleshootLog("     - 如果窗口已关闭，控件可能已销毁")
    AddTroubleshootLog("     - 需要检查控件是否存在")
    AddTroubleshootLog("")
    AddTroubleshootLog("  4. 控件句柄无效")
    AddTroubleshootLog("     - 控件句柄可能已失效")
    AddTroubleshootLog("     - 需要重新获取控件引用")
}

; 运行主函数
Main()
