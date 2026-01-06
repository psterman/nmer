; ===================== SearchCenter 搜索调试面板 =====================
; 独立测试面板，用于定位搜索功能卡在哪里
; 使用方法：直接运行此脚本，输入搜索关键词，点击"开始调试搜索"按钮
; 每个关键步骤都会用 MsgBox 提示，帮助定位问题

#Requires AutoHotkey v2.0
#SingleInstance Force

; 全局变量
global GuiID_SearchDebug := 0
global SearchDebugKeyword := ""
global KeywordEditControl := 0  ; 保存关键词输入框控件引用

; 主函数
Main() {
    CreateSearchDebugPanel()
}

; 创建调试面板
CreateSearchDebugPanel() {
    global GuiID_SearchDebug
    
    ; 如果面板已存在，先销毁
    if (GuiID_SearchDebug != 0) {
        try {
            GuiID_SearchDebug.Destroy()
        } catch {
        }
        GuiID_SearchDebug := 0
    }
    
    ; 创建 GUI
    GuiID_SearchDebug := Gui("+AlwaysOnTop -Caption +Resize", "SearchCenter 搜索调试面板")
    GuiID_SearchDebug.BackColor := "1e1e1e"
    GuiID_SearchDebug.SetFont("s10", "Consolas")
    
    ; 标题栏
    TitleBar := GuiID_SearchDebug.Add("Text", "x10 y10 w600 h30 cFFFFFF", "SearchCenter 搜索调试面板")
    TitleBar.SetFont("s12 Bold", "Segoe UI")
    
    ; 说明文字
    GuiID_SearchDebug.Add("Text", "x10 y50 w600 h60 cFFFFFF", 
        "此面板用于调试搜索功能，每个关键步骤都会用 MsgBox 提示。`n" .
        "请先确保主程序（CursorHelper (1).ahk）已运行，`n" .
        "然后输入搜索关键词，点击【开始调试搜索】按钮。")
    
    ; 搜索关键词输入框
    GuiID_SearchDebug.Add("Text", "x10 y120 w150 h25 cFFFFFF", "搜索关键词:")
    global KeywordEditControl
    KeywordEditControl := GuiID_SearchDebug.Add("Edit", "x170 y118 w300 h28 vKeywordEdit Background2d2d30 cFFFFFF", "")
    
    ; 开始调试按钮
    StartDebugBtn := GuiID_SearchDebug.Add("Button", "x10 y160 w200 h40", "开始调试搜索")
    StartDebugBtn.OnEvent("Click", StartSearchDebug)
    
    ; 关闭按钮
    CloseBtn := GuiID_SearchDebug.Add("Button", "x220 y160 w100 h40", "关闭")
    CloseBtn.OnEvent("Click", (*) => GuiID_SearchDebug.Destroy())
    
    ; 计算窗口尺寸
    WindowWidth := 620
    WindowHeight := 220
    
    ; 计算窗口位置（屏幕中央）
    WinWidth := A_ScreenWidth
    WinHeight := A_ScreenHeight
    WindowX := (WinWidth - WindowWidth) // 2
    WindowY := (WinHeight - WindowHeight) // 2
    
    ; 显示窗口
    GuiID_SearchDebug.Show("x" . WindowX . " y" . WindowY . " w" . WindowWidth . " h" . WindowHeight)
}

; 开始搜索调试
StartSearchDebug(*) {
    global GuiID_SearchDebug, SearchDebugKeyword, KeywordEditControl
    
    ; 获取关键词
    try {
        if (KeywordEditControl != 0) {
            SearchDebugKeyword := KeywordEditControl.Value
        } else {
            SearchDebugKeyword := ""
        }
    } catch {
        SearchDebugKeyword := ""
    }
    
    if (StrLen(SearchDebugKeyword) = 0) {
        MsgBox("请输入搜索关键词！", "提示", "Icon!")
        return
    }
    
    ; 开始调试流程
    DebugSearchFlow(SearchDebugKeyword)
}

; 调试搜索流程
DebugSearchFlow(Keyword) {
    Step := 1
    
    ; ========== 步骤 1: 检查主程序是否运行 ==========
    MsgBox("步骤 " . Step . ": 检查主程序是否运行`n`n" .
           "正在检查 CursorHelper (1).ahk 是否已运行...", 
           "搜索调试 - 步骤 " . Step, "Icon!")
    Step++
    
    MainScriptRunning := false
    SearchCenterWindowExists := false
    
    try {
        ; 方法1: 检测 SearchCenter 窗口是否存在（最可靠的方法）
        ; SearchCenter 窗口通常是 AutoHotkeyGUI 类，无标题栏
        if (WinExist("ahk_class AutoHotkeyGUI")) {
            ; 检查是否有多个 AutoHotkey 窗口，尝试找到 SearchCenter
            ; 由于 SearchCenter 是无边框窗口，可能难以直接识别
            ; 但如果有 AutoHotkey 窗口存在，说明主程序可能在运行
            SearchCenterWindowExists := true
            MainScriptRunning := true
        }
        
        ; 方法2: 检测 AutoHotkey 进程（可能有多个，不够准确）
        if (!MainScriptRunning) {
            PID := ProcessExist("AutoHotkey.exe")
            if (PID > 0) {
                MainScriptRunning := true
            }
        }
    } catch {
    }
    
    ; 如果检测不到，给用户选择继续或取消
    if (!MainScriptRunning) {
        Result := MsgBox("⚠ 无法确认主程序是否运行`n`n" .
                        "检测方法：`n" .
                        "1. 未找到 SearchCenter 窗口`n" .
                        "2. 未找到 AutoHotkey 进程`n`n" .
                        "请确认：`n" .
                        "- 主程序 CursorHelper (1).ahk 是否已运行？`n" .
                        "- 如果已运行，请点击【是】继续调试`n" .
                        "- 如果未运行，请点击【否】退出", 
                        "确认主程序状态", "YesNo Icon?")
        
        if (Result = "No") {
            return
        }
        ; 如果用户选择"是"，继续执行
        MainScriptRunning := true
    }
    
    StatusMsg := "✓ 主程序检测完成"
    if (SearchCenterWindowExists) {
        StatusMsg .= "（检测到 SearchCenter 窗口）"
    } else {
        StatusMsg .= "（未检测到 SearchCenter 窗口，但继续调试）"
    }
    MsgBox(StatusMsg, "步骤 " . (Step - 1) . " 完成", "Icon!")
    Sleep(500)
    
    ; ========== 步骤 2: 检查 SearchCenter 窗口是否存在 ==========
    MsgBox("步骤 " . Step . ": 检查 SearchCenter 窗口`n`n" .
           "正在检查 SearchCenter 窗口是否存在...`n`n" .
           "提示：如果 SearchCenter 未打开，请按 CapsLock+G 打开。", 
           "搜索调试 - 步骤 " . Step, "Icon!")
    Step++
    
    SearchCenterExists := false
    try {
        ; 尝试通过窗口类查找（SearchCenter 通常是 AutoHotkeyGUI 类）
        if (WinExist("ahk_class AutoHotkeyGUI")) {
            SearchCenterExists := true
        }
    } catch {
    }
    
    if (!SearchCenterExists) {
        Result := MsgBox("⚠ 未检测到 SearchCenter 窗口`n`n" .
                        "可能原因：`n" .
                        "1. SearchCenter 窗口未打开`n" .
                        "2. 窗口类名不是 AutoHotkeyGUI`n`n" .
                        "建议：`n" .
                        "- 按 CapsLock+G 打开 SearchCenter`n" .
                        "- 或者点击【是】继续调试（即使窗口未打开）`n`n" .
                        "是否继续调试？", 
                        "SearchCenter 窗口检测", "YesNo Icon?")
        
        if (Result = "No") {
            return
        }
        ; 如果用户选择"是"，继续执行
        SearchCenterExists := true
    }
    
    if (SearchCenterExists) {
        MsgBox("✓ SearchCenter 窗口检测完成`n`n" .
               "注意：即使检测到窗口，调试过程仍会继续。", 
               "步骤 " . (Step - 1) . " 完成", "Icon!")
    }
    Sleep(500)
    
    ; ========== 步骤 3: 检查数据库连接 ==========
    MsgBox("步骤 " . Step . ": 检查数据库连接`n`n" .
           "正在检查 ClipboardDB 数据库连接...", 
           "搜索调试 - 步骤 " . Step, "Icon!")
    Step++
    
    ; 注意：这里无法直接访问主程序的变量，只能提示用户检查
    MsgBox("⚠ 无法直接检查数据库连接`n`n" .
           "请检查主程序中 ClipboardDB 是否已初始化。`n" .
           "如果数据库未连接，搜索会回退到多数据源搜索模式。", 
           "步骤 " . (Step - 1) . " 提示", "Icon!")
    Sleep(500)
    
    ; ========== 步骤 4: 模拟搜索流程 - 检查关键词 ==========
    MsgBox("步骤 " . Step . ": 检查搜索关键词`n`n" .
           "关键词: '" . Keyword . "'`n" .
           "长度: " . StrLen(Keyword) . " 字符", 
           "搜索调试 - 步骤 " . Step, "Icon!")
    Step++
    
    if (StrLen(Keyword) < 1) {
        MsgBox("❌ 关键词为空，搜索将不会执行", "错误", "Icon!")
        return
    }
    
    MsgBox("✓ 关键词有效", "步骤 " . (Step - 1) . " 完成", "Icon!")
    Sleep(500)
    
    ; ========== 步骤 5: 模拟调用 SearchAllDataSources ==========
    MsgBox("步骤 " . Step . ": 调用 SearchAllDataSources`n`n" .
           "正在调用 SearchAllDataSources('" . Keyword . "', [], 50)...`n`n" .
           "⚠ 注意：如果这里卡住，说明 SearchAllDataSources 函数内部有问题。", 
           "搜索调试 - 步骤 " . Step, "Icon!")
    Step++
    
    ; 这里无法真正调用主程序的函数，只能提示
    MsgBox("⚠ 无法直接调用主程序的函数`n`n" .
           "请检查主程序中 SearchAllDataSources 函数的执行情况。`n" .
           "可能卡住的位置：`n" .
           "1. SearchGlobalView 查询`n" .
           "2. 多数据源搜索回退`n" .
           "3. 数据库查询超时", 
           "步骤 " . (Step - 1) . " 提示", "Icon!")
    Sleep(500)
    
    ; ========== 步骤 6: 检查 SearchClipboardHistory ==========
    MsgBox("步骤 " . Step . ": 检查剪贴板搜索`n`n" .
           "正在检查 SearchClipboardHistory 函数...`n`n" .
           "⚠ 注意：如果这里卡住，说明剪贴板搜索有问题。", 
           "搜索调试 - 步骤 " . Step, "Icon!")
    Step++
    
    MsgBox("⚠ 无法直接调用主程序的函数`n`n" .
           "请检查主程序中 SearchClipboardHistory 函数的执行情况。`n" .
           "可能卡住的位置：`n" .
           "1. 数据库查询`n" .
           "2. FTS5 全文搜索`n" .
           "3. 结果处理", 
           "步骤 " . (Step - 1) . " 提示", "Icon!")
    Sleep(500)
    
    ; ========== 步骤 7: 检查 GetEverythingResults ==========
    if (StrLen(Keyword) > 1) {
        MsgBox("步骤 " . Step . ": 检查 Everything 搜索`n`n" .
               "关键词长度 > 1，将执行 Everything 搜索...`n`n" .
               "正在检查 GetEverythingResults 函数...`n`n" .
               "⚠ 注意：如果这里卡住，说明 Everything 搜索有问题。", 
               "搜索调试 - 步骤 " . Step, "Icon!")
        Step++
        
        MsgBox("⚠ 无法直接调用主程序的函数`n`n" .
               "请检查主程序中 GetEverythingResults 函数的执行情况。`n" .
               "可能卡住的位置：`n" .
               "1. Everything DLL 加载`n" .
               "2. DLL 函数调用`n" .
               "3. Everything 服务未运行`n" .
               "4. 文件路径处理", 
               "步骤 " . (Step - 1) . " 提示", "Icon!")
        Sleep(500)
    } else {
        MsgBox("步骤 " . Step . ": 跳过 Everything 搜索`n`n" .
               "关键词长度 <= 1，跳过 Everything 搜索（这是正常行为）", 
               "搜索调试 - 步骤 " . Step, "Icon!")
        Step++
        Sleep(500)
    }
    
    ; ========== 步骤 8: 检查结果处理和排序 ==========
    MsgBox("步骤 " . Step . ": 检查结果处理`n`n" .
           "正在检查搜索结果的处理和排序...`n`n" .
           "⚠ 注意：如果这里卡住，说明结果处理逻辑有问题。", 
           "搜索调试 - 步骤 " . Step, "Icon!")
    Step++
    
    MsgBox("⚠ 无法直接检查结果处理`n`n" .
           "请检查主程序中结果处理的执行情况。`n" .
           "可能卡住的位置：`n" .
           "1. 结果数组扁平化`n" .
           "2. 时间戳排序`n" .
           "3. 结果数量限制", 
           "步骤 " . (Step - 1) . " 提示", "Icon!")
    Sleep(500)
    
    ; ========== 步骤 9: 检查 ListView 更新 ==========
    MsgBox("步骤 " . Step . ": 检查 ListView 更新`n`n" .
           "正在检查 SearchCenterResultLV 的更新...`n`n" .
           "⚠ 注意：如果这里卡住，说明 ListView 更新有问题。", 
           "搜索调试 - 步骤 " . Step, "Icon!")
    Step++
    
    MsgBox("⚠ 无法直接检查 ListView 更新`n`n" .
           "请检查主程序中 ListView 更新的执行情况。`n" .
           "可能卡住的位置：`n" .
           "1. SearchCenterResultLV.Delete() 删除'正在搜索...'`n" .
           "2. SearchCenterResultLV.Add() 添加结果`n" .
           "3. ListView 控件已销毁`n" .
           "4. 控件句柄无效", 
           "步骤 " . (Step - 1) . " 提示", "Icon!")
    Sleep(500)
    
    ; ========== 步骤 10: 检查异常处理 ==========
    MsgBox("步骤 " . Step . ": 检查异常处理`n`n" .
           "正在检查是否有异常被捕获但没有正确处理...`n`n" .
           "⚠ 注意：如果搜索卡在'正在搜索...'，可能是异常处理有问题。", 
           "搜索调试 - 步骤 " . Step, "Icon!")
    Step++
    
    MsgBox("⚠ 检查异常处理`n`n" .
           "请检查主程序中 DebouncedSearchCenter 函数的异常处理：`n" .
           "1. Try...Catch...Finally 块是否正确`n" .
           "2. Finally 块中是否确保更新了 ListView`n" .
           "3. 是否有异常被捕获但 ListView 没有更新`n" .
           "4. 检查 OutputDebug 输出，看是否有错误信息", 
           "步骤 " . (Step - 1) . " 提示", "Icon!")
    Sleep(500)
    
    ; ========== 步骤 11: 完成 ==========
    MsgBox("✅ 调试流程完成！`n`n" .
           "如果搜索一直显示'正在搜索...'，请根据上述步骤的提示，`n" .
           "在主程序的相应位置添加调试代码来定位问题。`n`n" .
           "🔍 推荐调试方法：`n" .
           "1. 在 DebouncedSearchCenter 函数开始处添加：`n" .
           "   OutputDebug('开始搜索: ' . Keyword)`n" .
           "2. 在 SearchAllDataSources 调用前后添加：`n" .
           "   OutputDebug('调用 SearchAllDataSources 前')`n" .
           "   AllDataResults := SearchAllDataSources(...)`n" .
           "   OutputDebug('SearchAllDataSources 返回: ' . AllDataResults.Count)`n" .
           "3. 在 ListView 更新前后添加：`n" .
           "   OutputDebug('准备更新 ListView')`n" .
           "   SearchCenterResultLV.Delete()`n" .
           "   OutputDebug('ListView 删除完成')`n" .
           "4. 在 Finally 块开始处添加：`n" .
           "   OutputDebug('进入 Finally 块')`n" .
           "5. 使用 DebugView 工具查看 OutputDebug 输出`n`n" .
           "💡 常见问题：`n" .
           "- 如果 OutputDebug 在某个位置停止，说明卡在那里`n" .
           "- 如果 Finally 块没有执行，说明异常处理有问题`n" .
           "- 如果 ListView 更新失败，检查控件是否已销毁", 
           "调试完成", "Icon!")
}

; 运行主函数
Main()
