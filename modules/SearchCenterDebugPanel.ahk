; ===================== SearchCenter 调试面板模块 =====================
; 用于调试 SearchCenter 中 SQLite 和 Everything 搜索结果融合的问题
;
; 注意：此模块使用主文件（CursorHelper (1).ahk）中定义的以下函数和变量：
;   - GetEverythingResults() : 在主文件第56行定义
;   - SearchAllDataSources() : 在主文件第11494行定义
;   - ClipboardDB : 在主文件第233行定义为全局变量

; 全局变量
global GuiID_SearchCenterDebug := 0
global SearchCenterDebugLogText := ""
global SearchCenterDebugTestKeyword := "test"

; 从主文件导入的全局变量和函数
; ClipboardDB - 在主文件第233行定义为全局变量
; GetEverythingResults() - 在主文件第56行定义
; SearchAllDataSources() - 在主文件第11494行定义

; 创建调试面板
ShowSearchCenterDebugPanel() {
    global GuiID_SearchCenterDebug, SearchCenterDebugLogText, SearchCenterDebugTestKeyword
    
    ; 如果面板已存在，先销毁
    if (GuiID_SearchCenterDebug != 0) {
        try {
            GuiID_SearchCenterDebug.Destroy()
        } catch {
        }
        GuiID_SearchCenterDebug := 0
    }
    
    ; 创建 GUI
    GuiID_SearchCenterDebug := Gui("+AlwaysOnTop -Caption +Resize", "SearchCenter 调试面板")
    GuiID_SearchCenterDebug.BackColor := "1e1e1e"
    GuiID_SearchCenterDebug.SetFont("s10", "Consolas")
    
    ; 标题栏
    TitleBar := GuiID_SearchCenterDebug.Add("Text", "x10 y10 w700 h30 cFFFFFF", "SearchCenter 调试面板")
    TitleBar.SetFont("s12 Bold", "Segoe UI")
    
    ; 测试关键词输入框
    GuiID_SearchCenterDebug.Add("Text", "x10 y50 w150 h25 cFFFFFF", "测试关键词:")
    KeywordEdit := GuiID_SearchCenterDebug.Add("Edit", "x170 y48 w200 h28 vTestKeywordEdit Background2d2d30 cFFFFFF", SearchCenterDebugTestKeyword)
    
    ; 按钮区域
    BtnY := 85
    BtnWidth := 120
    BtnHeight := 35
    BtnSpacing := 10
    
    ; 检测 Everything DLL 按钮
    CheckDLLBtn := GuiID_SearchCenterDebug.Add("Button", "x10 y" . BtnY . " w" . BtnWidth . " h" . BtnHeight, "检测 DLL")
    CheckDLLBtn.OnEvent("Click", CheckEverythingDLL)
    
    ; 检测 SQLite 按钮
    CheckSQLiteBtn := GuiID_SearchCenterDebug.Add("Button", "x" . (10 + BtnWidth + BtnSpacing) . " y" . BtnY . " w" . BtnWidth . " h" . BtnHeight, "检测 SQLite")
    CheckSQLiteBtn.OnEvent("Click", CheckSQLiteStatus)
    
    ; 测试 Everything 搜索按钮
    TestEverythingBtn := GuiID_SearchCenterDebug.Add("Button", "x" . (10 + (BtnWidth + BtnSpacing) * 2) . " y" . BtnY . " w" . BtnWidth . " h" . BtnHeight, "测试 Everything")
    TestEverythingBtn.OnEvent("Click", TestEverythingSearchInSearchCenterDebug)
    
    ; 测试 SQLite 搜索按钮
    TestSQLiteBtn := GuiID_SearchCenterDebug.Add("Button", "x" . (10 + (BtnWidth + BtnSpacing) * 3) . " y" . BtnY . " w" . BtnWidth . " h" . BtnHeight, "测试 SQLite")
    TestSQLiteBtn.OnEvent("Click", TestSQLiteSearch)
    
    ; 测试融合搜索按钮
    TestFusionBtn := GuiID_SearchCenterDebug.Add("Button", "x" . (10 + (BtnWidth + BtnSpacing) * 4) . " y" . BtnY . " w" . BtnWidth . " h" . BtnHeight, "测试融合")
    TestFusionBtn.OnEvent("Click", TestFusionSearch)
    
    ; 检测 ListView 按钮
    CheckListViewBtn := GuiID_SearchCenterDebug.Add("Button", "x10 y" . (BtnY + BtnHeight + 10) . " w" . BtnWidth . " h" . BtnHeight, "检测 ListView")
    CheckListViewBtn.OnEvent("Click", CheckListViewStatusInSearchCenterDebug)
    
    ; 完整流程测试按钮
    FullTestBtn := GuiID_SearchCenterDebug.Add("Button", "x" . (10 + BtnWidth + BtnSpacing) . " y" . (BtnY + BtnHeight + 10) . " w" . (BtnWidth * 2 + BtnSpacing) . " h" . BtnHeight, "完整流程测试")
    FullTestBtn.OnEvent("Click", FullFlowTestInSearchCenterDebug)
    
    ; 清空日志按钮
    ClearLogBtn := GuiID_SearchCenterDebug.Add("Button", "x" . (10 + (BtnWidth * 3 + BtnSpacing * 2) + 10) . " y" . (BtnY + BtnHeight + 10) . " w" . BtnWidth . " h" . BtnHeight, "清空日志")
    ClearLogBtn.OnEvent("Click", ClearDebugLogInSearchCenterDebug)
    
    ; 日志显示区域
    LogY := BtnY + BtnHeight * 2 + 20
    GuiID_SearchCenterDebug.Add("Text", "x10 y" . LogY . " w700 h25 cFFFFFF", "调试日志:")
    LogEdit := GuiID_SearchCenterDebug.Add("Edit", "x10 y" . (LogY + 25) . " w700 h350 ReadOnly Multi VDebugLogEdit Background1e1e1e cFFFFFF", SearchCenterDebugLogText)
    LogEdit.SetFont("s9", "Consolas")
    
    ; 关闭按钮
    CloseBtn := GuiID_SearchCenterDebug.Add("Button", "x10 y" . (LogY + 380) . " w100 h35", "关闭")
    CloseBtn.OnEvent("Click", (*) => GuiID_SearchCenterDebug.Destroy())
    
    ; 保存控件引用
    GuiID_SearchCenterDebug["KeywordEdit"] := KeywordEdit
    GuiID_SearchCenterDebug["LogEdit"] := LogEdit
    
    ; 计算窗口尺寸
    WindowWidth := 730
    WindowHeight := LogY + 430
    
    ; 计算窗口位置（屏幕右下角，但确保在可见区域）
    WinWidth := A_ScreenWidth
    WinHeight := A_ScreenHeight
    WindowX := WinWidth - WindowWidth - 50  ; 距离右边缘50像素
    WindowY := WinHeight - WindowHeight - 50  ; 距离底边缘50像素
    
    ; 确保窗口在屏幕范围内
    if (WindowX < 0) {
        WindowX := 50
    }
    if (WindowY < 0) {
        WindowY := 50
    }
    
    ; 显示窗口（指定位置和尺寸）
    GuiID_SearchCenterDebug.Show("x" . WindowX . " y" . WindowY . " w" . WindowWidth . " h" . WindowHeight)
    
    ; 【关键修复】重新激活 SearchCenter 窗口，确保输入框获得焦点
    ; 因为调试面板使用了 +AlwaysOnTop，可能会抢走焦点
    try {
        global GuiID_SearchCenter, SearchCenterSearchEdit
        if (IsSet(GuiID_SearchCenter) && GuiID_SearchCenter != 0) {
            ; 延迟一点时间，确保调试面板完全显示
            Sleep(100)
            ; 激活 SearchCenter 窗口
            WinActivate("ahk_id " . GuiID_SearchCenter.Hwnd)
            WinWaitActive("ahk_id " . GuiID_SearchCenter.Hwnd, , 1)
            Sleep(100)
            ; 聚焦到输入框
            if (IsSet(SearchCenterSearchEdit) && SearchCenterSearchEdit != 0) {
                SearchCenterSearchEdit.Focus()
            }
        }
    } catch {
        ; 忽略错误，不影响调试面板的显示
    }
    
    ; 自动执行完整检测
    SetTimer(() => FullFlowTestInSearchCenterDebug(), -500)
}

; 添加日志
AddSearchCenterDebugLog(Message) {
    global SearchCenterDebugLogText, GuiID_SearchCenterDebug
    Timestamp := FormatTime(, "HH:mm:ss")
    SearchCenterDebugLogText .= "[" . Timestamp . "] " . Message . "`r`n"
    
    if (GuiID_SearchCenterDebug != 0) {
        try {
            LogEdit := GuiID_SearchCenterDebug["LogEdit"]
            if (LogEdit != 0) {
                LogEdit.Value := SearchCenterDebugLogText
                ; 滚动到底部
                SendMessage(0x0115, 7, 0, LogEdit)  ; EM_SCROLL = 0x0115, SB_BOTTOM = 7
            }
        } catch {
        }
    }
}

; 检测 Everything DLL
CheckEverythingDLL(*) {
    AddSearchCenterDebugLog("========== 开始检测 Everything DLL ==========")
    
    ; 检查 64 位 DLL
    DLL64Path := A_ScriptDir "\lib\everything64.dll"
    AddSearchCenterDebugLog("检查 64 位 DLL: " . DLL64Path)
    
    if (FileExist(DLL64Path)) {
        FileSize := FileGetSize(DLL64Path)
        AddSearchCenterDebugLog("✓ 64 位 DLL 存在，大小: " . FileSize . " 字节")
        
        ; 尝试加载 DLL
        try {
            ; 测试调用 Everything_GetVersion
            Version := DllCall(DLL64Path "\Everything_GetVersion", "UInt")
            if (Version != "") {
                AddSearchCenterDebugLog("✓ DLL 加载成功，版本: " . Version)
            } else {
                AddSearchCenterDebugLog("⚠ DLL 加载但版本信息为空")
            }
        } catch as err {
            AddSearchCenterDebugLog("✗ DLL 加载失败: " . err.Message)
        }
    } else {
        AddSearchCenterDebugLog("✗ 64 位 DLL 不存在")
    }
    
    ; 检查系统架构
    if (A_PtrSize = 8) {
        AddSearchCenterDebugLog("系统架构: 64 位 (应使用 everything64.dll)")
    } else {
        AddSearchCenterDebugLog("系统架构: 32 位 (应使用 everything32.dll)")
    }
    
    AddSearchCenterDebugLog("========== DLL 检测完成 ==========")
}

; 检测 SQLite 状态
CheckSQLiteStatus(*) {
    global ClipboardDB
    AddSearchCenterDebugLog("========== 开始检测 SQLite 状态 ==========")
    
    ; 检查数据库连接（ClipboardDB 在主文件中定义和初始化）
    if (!IsSet(ClipboardDB) || !ClipboardDB || ClipboardDB = 0) {
        AddSearchCenterDebugLog("✗ 数据库未连接 (ClipboardDB = 0)")
        AddSearchCenterDebugLog("  提示: 需要先初始化数据库连接")
        AddSearchCenterDebugLog("========== SQLite 检测完成 ==========")
        return
    }
    
    AddSearchCenterDebugLog("✓ 数据库已连接")
    
    ; 测试查询
    try {
        SQL := "SELECT COUNT(*) as count FROM sqlite_master WHERE type='table'"
        Result := ClipboardDB.Query(SQL)
        if (Result.Length > 0) {
            TableCount := Result[1].count
            AddSearchCenterDebugLog("✓ 数据库查询成功，表数量: " . TableCount)
        } else {
            AddSearchCenterDebugLog("⚠ 数据库查询返回空结果")
        }
    } catch as err {
        AddSearchCenterDebugLog("✗ 数据库查询失败: " . err.Message)
    }
    
    ; 检查 v_GlobalSearch 视图
    try {
        SQL := "SELECT COUNT(*) as count FROM sqlite_master WHERE type='view' AND name='v_GlobalSearch'"
        Result := ClipboardDB.Query(SQL)
        if (Result.Length > 0 && Result[1].count > 0) {
            AddSearchCenterDebugLog("✓ v_GlobalSearch 视图存在")
        } else {
            AddSearchCenterDebugLog("⚠ v_GlobalSearch 视图不存在")
        }
    } catch as err {
        AddSearchCenterDebugLog("⚠ 无法检查视图: " . err.Message)
    }
    
    AddSearchCenterDebugLog("========== SQLite 检测完成 ==========")
}

; 测试 Everything 搜索（SearchCenter 调试面板版本）
TestEverythingSearchInSearchCenterDebug(*) {
    AddSearchCenterDebugLog("========== 开始测试 Everything 搜索 ==========")
    
    ; 获取测试关键词
    TestKeyword := GetTestKeyword()
    AddSearchCenterDebugLog("测试关键词: '" . TestKeyword . "'")
    AddSearchCenterDebugLog("关键词长度: " . StrLen(TestKeyword))
    
    ; 检查关键词长度
    if (StrLen(TestKeyword) <= 1) {
        AddSearchCenterDebugLog("⚠ 关键词长度 <= 1，Everything 搜索不会执行（这是正常行为）")
    }
    
    ; 调用搜索函数（GetEverythingResults 在主文件中定义）
    AddSearchCenterDebugLog("调用 GetEverythingResults()...")
    try {
        ; GetEverythingResults 是函数，定义在主文件第56行
        GetEverythingResultsFunc := Func("GetEverythingResults")
        Results := GetEverythingResultsFunc.Call(TestKeyword, 50)
        ResultCount := Results.Length
        AddSearchCenterDebugLog("✓ 搜索完成，返回 " . ResultCount . " 个结果")
        
        if (ResultCount > 0) {
            AddSearchCenterDebugLog("前 10 个结果:")
            Loop Min(ResultCount, 10) {
                AddSearchCenterDebugLog("  " . A_Index . ". " . Results[A_Index])
            }
            if (ResultCount > 10) {
                AddSearchCenterDebugLog("  ... (还有 " . (ResultCount - 10) . " 个结果)")
            }
        } else {
            AddSearchCenterDebugLog("⚠ 未找到任何结果")
            AddSearchCenterDebugLog("  可能原因:")
            AddSearchCenterDebugLog("    1. Everything 服务未运行")
            AddSearchCenterDebugLog("    2. 搜索关键词无匹配项")
            AddSearchCenterDebugLog("    3. DLL 调用失败")
            AddSearchCenterDebugLog("    4. 关键词长度 <= 1（不会执行搜索）")
        }
    } catch as err {
        AddSearchCenterDebugLog("✗ 搜索异常: " . err.Message)
        if (err.HasProp("Extra")) {
            AddSearchCenterDebugLog("  错误详情: " . err.Extra)
        }
        if (err.HasProp("File") && err.HasProp("Line")) {
            AddSearchCenterDebugLog("  位置: " . err.File . ":" . err.Line)
        }
    }
    
    AddSearchCenterDebugLog("========== Everything 搜索测试完成 ==========")
}

; 测试 SQLite 搜索
TestSQLiteSearch(*) {
    AddSearchCenterDebugLog("========== 开始测试 SQLite 搜索 ==========")
    
    ; 获取测试关键词
    TestKeyword := GetTestKeyword()
    AddSearchCenterDebugLog("测试关键词: '" . TestKeyword . "'")
    
    ; 测试 SearchAllDataSources（在主文件中定义）
    AddSearchCenterDebugLog("调用 SearchAllDataSources()...")
    try {
        ; SearchAllDataSources 是函数，定义在主文件第11494行
        SearchAllDataSourcesFunc := Func("SearchAllDataSources")
        AllDataResults := SearchAllDataSourcesFunc.Call(TestKeyword, [], 50)
        
        ; 统计结果
        TotalCount := 0
        TypeCounts := Map()
        
        for DataType, TypeData in AllDataResults {
            if (IsObject(TypeData) && TypeData.HasProp("Items")) {
                Count := TypeData.Items.Length
                TotalCount += Count
                TypeCounts[DataType] := Count
                DataTypeName := TypeData.HasProp("DataTypeName") ? TypeData.DataTypeName : DataType
                AddSearchCenterDebugLog("  " . DataTypeName . ": " . Count . " 个结果")
            }
        }
        
        AddSearchCenterDebugLog("✓ SQLite 搜索完成，总计 " . TotalCount . " 个结果")
        
        if (TotalCount = 0) {
            AddSearchCenterDebugLog("⚠ 未找到任何结果")
            AddSearchCenterDebugLog("  可能原因:")
            AddSearchCenterDebugLog("    1. 数据库中无匹配数据")
            AddSearchCenterDebugLog("    2. 搜索关键词无匹配项")
            AddSearchCenterDebugLog("    3. 数据库连接失败")
        }
    } catch as err {
        AddSearchCenterDebugLog("✗ SQLite 搜索异常: " . err.Message)
        if (err.HasProp("Extra")) {
            AddSearchCenterDebugLog("  错误详情: " . err.Extra)
        }
        if (err.HasProp("File") && err.HasProp("Line")) {
            AddSearchCenterDebugLog("  位置: " . err.File . ":" . err.Line)
        }
    }
    
    AddSearchCenterDebugLog("========== SQLite 搜索测试完成 ==========")
}

; 测试融合搜索（模拟 DebouncedSearchCenter 的完整流程）
TestFusionSearch(*) {
    AddSearchCenterDebugLog("========== 开始测试融合搜索 ==========")
    AddSearchCenterDebugLog("模拟 DebouncedSearchCenter 的完整搜索流程")
    
    ; 获取测试关键词
    TestKeyword := GetTestKeyword()
    AddSearchCenterDebugLog("测试关键词: '" . TestKeyword . "'")
    
    ; 步骤 1: SQLite 搜索
    AddSearchCenterDebugLog("")
    AddSearchCenterDebugLog(">>> 步骤 1: SQLite 搜索 <<<")
    SQLiteResults := []
    try {
        ; SearchAllDataSources 是函数，定义在主文件第11494行
        SearchAllDataSourcesFunc := Func("SearchAllDataSources")
        AllDataResults := SearchAllDataSourcesFunc.Call(TestKeyword, [], 50)
        
        ; 转换为扁平化数组
        for DataType, TypeData in AllDataResults {
            if (IsObject(TypeData) && TypeData.HasProp("Items")) {
                for Index, Item in TypeData.Items {
                    TimeDisplay := ""
                    if (Item.HasProp("TimeFormatted")) {
                        TimeDisplay := Item.TimeFormatted
                    } else if (Item.HasProp("Timestamp")) {
                        try {
                            TimeDisplay := FormatTime(Item.Timestamp, "yyyy-MM-dd HH:mm:ss")
                        } catch {
                            TimeDisplay := Item.Timestamp
                        }
                    }
                    
                    TitleText := ""
                    if (Item.HasProp("Title") && Item.Title != "") {
                        TitleText := Item.Title
                    } else if (Item.HasProp("Content") && Item.Content != "") {
                        TitleText := SubStr(Item.Content, 1, 50)
                        if (StrLen(Item.Content) > 50) {
                            TitleText .= "..."
                        }
                    }
                    
                    ContentText := Item.HasProp("Content") ? Item.Content : (Item.HasProp("Title") ? Item.Title : "")
                    
                    SQLiteResults.Push({
                        Title: TitleText,
                        Source: TypeData.HasProp("DataTypeName") ? TypeData.DataTypeName : DataType,
                        Time: TimeDisplay,
                        Content: ContentText,
                        ID: Item.HasProp("ID") ? Item.ID : "",
                        DataType: DataType
                    })
                }
            }
        }
        
        AddSearchCenterDebugLog("✓ SQLite 搜索完成，获得 " . SQLiteResults.Length . " 个结果")
    } catch as err {
        AddSearchCenterDebugLog("✗ SQLite 搜索失败: " . err.Message)
    }
    
    ; 步骤 2: Everything 搜索
    AddSearchCenterDebugLog("")
    AddSearchCenterDebugLog(">>> 步骤 2: Everything 搜索 <<<")
    EverythingResults := []
    if (StrLen(TestKeyword) > 1) {
        try {
            ; GetEverythingResults 是函数，定义在主文件第56行
            GetEverythingResultsFunc := Func("GetEverythingResults")
            EverythingPaths := GetEverythingResultsFunc.Call(TestKeyword, 50)
            for Index, FilePath in EverythingPaths {
                if (!FileExist(FilePath)) {
                    continue
                }
                
                SplitPath(FilePath, &FileName, &DirPath, &Ext, &NameNoExt)
                
                FileTime := ""
                try {
                    FileTime := FileGetTime(FilePath, "M")
                    FileTime := FormatTime(FileTime, "yyyy-MM-dd HH:mm:ss")
                } catch {
                    FileTime := ""
                }
                
                EverythingResults.Push({
                    Title: FileName,
                    Source: "Everything",
                    Time: FileTime,
                    Content: FilePath,
                    ID: FilePath,
                    DataType: "file"
                })
            }
            
            AddSearchCenterDebugLog("✓ Everything 搜索完成，获得 " . EverythingResults.Length . " 个结果")
        } catch as err {
            AddSearchCenterDebugLog("✗ Everything 搜索失败: " . err.Message)
        }
    } else {
        AddSearchCenterDebugLog("⚠ 关键词长度 <= 1，跳过 Everything 搜索")
    }
    
    ; 步骤 3: 融合结果
    AddSearchCenterDebugLog("")
    AddSearchCenterDebugLog(">>> 步骤 3: 融合结果 <<<")
    AllResults := []
    
    ; 先添加 SQLite 结果
    for Index, Item in SQLiteResults {
        AllResults.Push(Item)
    }
    
    ; 再添加 Everything 结果
    for Index, Item in EverythingResults {
        AllResults.Push(Item)
    }
    
    AddSearchCenterDebugLog("✓ 融合完成，总计 " . AllResults.Length . " 个结果")
    AddSearchCenterDebugLog("  - SQLite 结果: " . SQLiteResults.Length . " 个")
    AddSearchCenterDebugLog("  - Everything 结果: " . EverythingResults.Length . " 个")
    
    ; 步骤 4: 检查 ListView
    AddSearchCenterDebugLog("")
    AddSearchCenterDebugLog(">>> 步骤 4: 检查 ListView <<<")
    CheckListViewWithResults(AllResults)
    
    AddSearchCenterDebugLog("========== 融合搜索测试完成 ==========")
}

; 检测 ListView 状态（SearchCenter 调试面板版本）
CheckListViewStatusInSearchCenterDebug(*) {
    global GuiID_SearchCenter, SearchCenterResultLV, SearchCenterSearchResults, SearchCenterSearchEdit
    AddSearchCenterDebugLog("========== 开始检测 ListView 状态 ==========")
    
    ; 检查 SearchCenter 窗口
    try {
        if (IsSet(GuiID_SearchCenter) && GuiID_SearchCenter != 0) {
            AddSearchCenterDebugLog("✓ SearchCenter 窗口存在")
        } else {
            AddSearchCenterDebugLog("✗ SearchCenter 窗口不存在")
        }
    } catch as err {
        AddSearchCenterDebugLog("✗ 检查窗口失败: " . err.Message)
    }
    
    ; 检查 SearchCenterResultLV 控件
    try {
        if (IsSet(SearchCenterResultLV)) {
            if (SearchCenterResultLV != 0) {
                AddSearchCenterDebugLog("✓ SearchCenterResultLV 控件存在")
                try {
                    Count := SearchCenterResultLV.GetCount()
                    AddSearchCenterDebugLog("  ListView 项目数量: " . Count)
                } catch as err {
                    AddSearchCenterDebugLog("  ⚠ 无法获取项目数量: " . err.Message)
                }
            } else {
                AddSearchCenterDebugLog("✗ SearchCenterResultLV 为 0（控件未创建）")
            }
        } else {
            AddSearchCenterDebugLog("✗ SearchCenterResultLV 变量未定义")
        }
    } catch as err {
        AddSearchCenterDebugLog("✗ 检查 ListView 控件失败: " . err.Message)
    }
    
    ; 检查 SearchCenterSearchResults 数组
    try {
        if (IsSet(SearchCenterSearchResults)) {
            ResultCount := SearchCenterSearchResults.Length
            AddSearchCenterDebugLog("✓ SearchCenterSearchResults 数组存在，包含 " . ResultCount . " 个结果")
            
            ; 统计来源
            SourceCounts := Map()
            for Index, Item in SearchCenterSearchResults {
                Source := Item.HasProp("Source") ? Item.Source : "未知"
                if (!SourceCounts.Has(Source)) {
                    SourceCounts[Source] := 0
                }
                SourceCounts[Source]++
            }
            
            AddSearchCenterDebugLog("  结果来源统计:")
            for Source, Count in SourceCounts {
                AddSearchCenterDebugLog("    " . Source . ": " . Count . " 个")
            }
            
            ; 检查是否有 Everything 结果
            EverythingCount := SourceCounts.Has("Everything") ? SourceCounts["Everything"] : 0
            if (EverythingCount = 0 && ResultCount > 0) {
                AddSearchCenterDebugLog("  ⚠ 警告: 有搜索结果但没有 Everything 结果")
            }
        } else {
            AddSearchCenterDebugLog("✗ SearchCenterSearchResults 变量未定义")
        }
    } catch as err {
        AddSearchCenterDebugLog("✗ 检查搜索结果数组失败: " . err.Message)
    }
    
    AddSearchCenterDebugLog("========== ListView 检测完成 ==========")
}

; 检查 ListView 与结果数组的一致性
CheckListViewWithResults(ExpectedResults) {
    global SearchCenterResultLV, SearchCenterSearchResults
    AddSearchCenterDebugLog("检查 ListView 与结果数组的一致性...")
    
    try {
        if (!IsSet(SearchCenterResultLV) || SearchCenterResultLV = 0) {
            AddSearchCenterDebugLog("✗ SearchCenterResultLV 不存在")
            return
        }
        
        if (!IsSet(SearchCenterSearchResults)) {
            AddSearchCenterDebugLog("✗ SearchCenterSearchResults 不存在")
            return
        }
        
        LVCount := SearchCenterResultLV.GetCount()
        ArrayCount := SearchCenterSearchResults.Length
        ExpectedCount := ExpectedResults.Length
        
        AddSearchCenterDebugLog("  ListView 项目数: " . LVCount)
        AddSearchCenterDebugLog("  搜索结果数组数: " . ArrayCount)
        AddSearchCenterDebugLog("  预期结果数: " . ExpectedCount)
        
        if (LVCount != ArrayCount) {
            AddSearchCenterDebugLog("  ⚠ 警告: ListView 项目数与数组数不一致")
        }
        
        if (ArrayCount != ExpectedCount) {
            AddSearchCenterDebugLog("  ⚠ 警告: 数组数与预期结果数不一致")
        }
        
        ; 检查前几个项目是否匹配
        CheckCount := Min(5, LVCount, ArrayCount, ExpectedCount)
        if (CheckCount > 0) {
            AddSearchCenterDebugLog("  检查前 " . CheckCount . " 个项目:")
            Loop CheckCount {
                LVText := SearchCenterResultLV.GetText(A_Index, 1)
                ArrayTitle := SearchCenterSearchResults[A_Index].HasProp("Title") ? SearchCenterSearchResults[A_Index].Title : ""
                ExpectedTitle := ExpectedResults[A_Index].HasProp("Title") ? ExpectedResults[A_Index].Title : ""
                
                Match := (LVText = ArrayTitle && ArrayTitle = ExpectedTitle)
                Status := Match ? "✓" : "✗"
                AddSearchCenterDebugLog("    " . Status . " [" . A_Index . "] LV: '" . LVText . "' | Array: '" . ArrayTitle . "' | Expected: '" . ExpectedTitle . "'")
            }
        }
    } catch as err {
        AddSearchCenterDebugLog("✗ 检查失败: " . err.Message)
    }
}

; 完整流程测试（SearchCenter 调试面板版本）
FullFlowTestInSearchCenterDebug(*) {
    AddSearchCenterDebugLog("========================================")
    AddSearchCenterDebugLog("开始完整流程测试")
    AddSearchCenterDebugLog("========================================")
    
    ; 1. 检测 Everything DLL
    CheckEverythingDLL()
    Sleep(100)
    
    ; 2. 检测 SQLite
    CheckSQLiteStatus()
    Sleep(100)
    
    ; 3. 测试 Everything 搜索
    TestEverythingSearchInSearchCenterDebug()
    Sleep(100)
    
    ; 4. 测试 SQLite 搜索
    TestSQLiteSearch()
    Sleep(100)
    
    ; 5. 测试融合搜索
    TestFusionSearch()
    Sleep(100)
    
    ; 6. 检测 ListView
    CheckListViewStatusInSearchCenterDebug()
    
    AddSearchCenterDebugLog("========================================")
    AddSearchCenterDebugLog("完整流程测试完成")
    AddSearchCenterDebugLog("========================================")
}

; 清空日志（SearchCenter 调试面板版本）
ClearDebugLogInSearchCenterDebug(*) {
    global SearchCenterDebugLogText, GuiID_SearchCenterDebug
    SearchCenterDebugLogText := ""
    if (GuiID_SearchCenterDebug != 0) {
        try {
            LogEdit := GuiID_SearchCenterDebug["LogEdit"]
            if (LogEdit != 0) {
                LogEdit.Value := ""
            }
        } catch {
        }
    }
    AddSearchCenterDebugLog("日志已清空")
}

; 获取测试关键词
GetTestKeyword() {
    global GuiID_SearchCenterDebug, SearchCenterDebugTestKeyword, SearchCenterSearchEdit
    
    if (GuiID_SearchCenterDebug != 0) {
        try {
            KeywordEdit := GuiID_SearchCenterDebug["KeywordEdit"]
            if (KeywordEdit != 0) {
                return KeywordEdit.Value
            }
        } catch {
        }
    }
    
    ; 如果无法从输入框获取，尝试从 SearchCenter 输入框获取
    try {
        if (IsSet(SearchCenterSearchEdit) && SearchCenterSearchEdit != 0) {
            return SearchCenterSearchEdit.Value
        }
    } catch {
    }
    
    return SearchCenterDebugTestKeyword
}
