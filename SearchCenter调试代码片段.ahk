; ===================== SearchCenter 调试代码片段 =====================
; 这些代码可以直接添加到主程序（CursorHelper (1).ahk）中
; 用于定位搜索卡在"正在搜索..."的具体位置
;
; 使用方法：
; 1. 将这些代码添加到主程序的相应位置
; 2. 运行搜索功能
; 3. 使用 DebugView 工具查看 OutputDebug 输出
; 4. 或者查看 debug_search.log 文件

; ===================== 1. 在 DebouncedSearchCenter 函数开始处添加 =====================
; 位置：CursorHelper (1).ahk 第 21529 行附近
;
; DebouncedSearchCenter(*) {
;     global SearchCenterSearchEdit, SearchCenterResultLV, SearchCenterSearchResults
;     
;     ; 【调试代码开始】
;     OutputDebug("========== DebouncedSearchCenter 开始 ==========")
;     OutputDebug("关键词: " . SearchCenterSearchEdit.Value)
;     FileAppend("[" . FormatTime(, "HH:mm:ss") . "] DebouncedSearchCenter 开始，关键词: " . SearchCenterSearchEdit.Value . "`n", "debug_search.log")
;     ; 【调试代码结束】
;     
;     ; ... 原有代码 ...

; ===================== 2. 在 SearchAllDataSources 调用前后添加 =====================
; 位置：CursorHelper (1).ahk 第 21592 行附近
;
;     ; 【调试代码开始】
;     OutputDebug("准备调用 SearchAllDataSources")
;     FileAppend("[" . FormatTime(, "HH:mm:ss") . "] 准备调用 SearchAllDataSources`n", "debug_search.log")
;     StartTime := A_TickCount
;     ; 【调试代码结束】
;     
;     AllDataResults := SearchAllDataSources(Keyword, [], 50)
;     
;     ; 【调试代码开始】
;     ElapsedTime := A_TickCount - StartTime
;     OutputDebug("SearchAllDataSources 返回，耗时: " . ElapsedTime . "ms，结果数量: " . AllDataResults.Count)
;     FileAppend("[" . FormatTime(, "HH:mm:ss") . "] SearchAllDataSources 返回，耗时: " . ElapsedTime . "ms`n", "debug_search.log")
;     ; 【调试代码结束】

; ===================== 3. 在 SearchAllDataSources 函数内部添加 =====================
; 位置：CursorHelper (1).ahk 第 11505 行附近
;
; SearchAllDataSources(Keyword, DataTypes := [], MaxResults := 10) {
;     ; 【调试代码开始】
;     OutputDebug("SearchAllDataSources 开始，关键词: " . Keyword)
;     FileAppend("[" . FormatTime(, "HH:mm:ss") . "] SearchAllDataSources 开始`n", "debug_search.log")
;     ; 【调试代码结束】
;     
;     global ClipboardDB
;     if (ClipboardDB && ClipboardDB != 0) {
;         ; 【调试代码开始】
;         OutputDebug("数据库已连接，尝试 SearchGlobalView")
;         FileAppend("[" . FormatTime(, "HH:mm:ss") . "] 尝试 SearchGlobalView`n", "debug_search.log")
;         ; 【调试代码结束】
;         
;         GlobalResults := SearchGlobalView(Keyword, 100)
;         
;         ; 【调试代码开始】
;         OutputDebug("SearchGlobalView 返回，结果数量: " . GlobalResults.Length)
;         FileAppend("[" . FormatTime(, "HH:mm:ss") . "] SearchGlobalView 返回，结果数量: " . GlobalResults.Length . "`n", "debug_search.log")
;         ; 【调试代码结束】
;         
;         if (GlobalResults.Length > 0) {
;             ; ... 原有代码 ...
;         }
;     } else {
;         ; 【调试代码开始】
;         OutputDebug("数据库未连接，回退到多数据源搜索")
;         FileAppend("[" . FormatTime(, "HH:mm:ss") . "] 数据库未连接`n", "debug_search.log")
;         ; 【调试代码结束】
;     }
;     
;     ; ... 原有代码 ...

; ===================== 4. 在 SearchClipboardHistory 函数内部添加 =====================
; 位置：CursorHelper (1).ahk 第 11573 行附近
;
; SearchClipboardHistory(Keyword, MaxResults := 10) {
;     ; 【调试代码开始】
;     OutputDebug("SearchClipboardHistory 开始，关键词: " . Keyword)
;     FileAppend("[" . FormatTime(, "HH:mm:ss") . "] SearchClipboardHistory 开始`n", "debug_search.log")
;     ; 【调试代码结束】
;     
;     global ClipboardDB, global_ST
;     Results := []
;     
;     if (!ClipboardDB || ClipboardDB = 0) {
;         ; 【调试代码开始】
;         OutputDebug("SearchClipboardHistory: 数据库未连接")
;         FileAppend("[" . FormatTime(, "HH:mm:ss") . "] SearchClipboardHistory: 数据库未连接`n", "debug_search.log")
;         ; 【调试代码结束】
;         return Results
;     }
;     
;     ; ... 原有代码 ...
;     
;     try {
;         if (!ClipboardDB.Prepare(SQL, &ST)) {
;             ; 【调试代码开始】
;             OutputDebug("SearchClipboardHistory: Prepare 失败")
;             FileAppend("[" . FormatTime(, "HH:mm:ss") . "] SearchClipboardHistory: Prepare 失败`n", "debug_search.log")
;             ; 【调试代码结束】
;             return Results
;         }
;         
;         ; 【调试代码开始】
;         OutputDebug("SearchClipboardHistory: Prepare 成功")
;         FileAppend("[" . FormatTime(, "HH:mm:ss") . "] SearchClipboardHistory: Prepare 成功`n", "debug_search.log")
;         ; 【调试代码结束】
;         
;         ; ... 绑定参数 ...
;         
;         ; 【调试代码开始】
;         OutputDebug("SearchClipboardHistory: 开始 Step 循环")
;         FileAppend("[" . FormatTime(, "HH:mm:ss") . "] SearchClipboardHistory: 开始 Step 循环`n", "debug_search.log")
;         StepCount := 0
;         ; 【调试代码结束】
;         
;         while (ST.Step()) {
;             ; 【调试代码开始】
;             StepCount++
;             if (StepCount = 1 || StepCount = 10 || StepCount = 50) {
;                 OutputDebug("SearchClipboardHistory: Step " . StepCount)
;             }
;             ; 【调试代码结束】
;             
;             ; ... 原有代码 ...
;         }
;         
;         ; 【调试代码开始】
;         OutputDebug("SearchClipboardHistory: Step 循环完成，共 " . StepCount . " 条结果")
;         FileAppend("[" . FormatTime(, "HH:mm:ss") . "] SearchClipboardHistory: Step 循环完成，共 " . StepCount . " 条结果`n", "debug_search.log")
;         ; 【调试代码结束】
;         
;     } catch as err {
;         ; 【调试代码开始】
;         OutputDebug("SearchClipboardHistory: 异常 - " . err.Message)
;         FileAppend("[" . FormatTime(, "HH:mm:ss") . "] SearchClipboardHistory: 异常 - " . err.Message . "`n", "debug_search.log")
;         ; 【调试代码结束】
;     }

; ===================== 5. 在 GetEverythingResults 函数内部添加 =====================
; 位置：CursorHelper (1).ahk 第 50 行附近
;
; GetEverythingResults(keyword, maxResults := 30) {
;     ; 【调试代码开始】
;     OutputDebug("GetEverythingResults 开始，关键词: " . keyword)
;     FileAppend("[" . FormatTime(, "HH:mm:ss") . "] GetEverythingResults 开始`n", "debug_search.log")
;     ; 【调试代码结束】
;     
;     static evDll := A_ScriptDir "\lib\everything64.dll"
;     
;     if (!FileExist(evDll)) {
;         ; 【调试代码开始】
;         OutputDebug("GetEverythingResults: DLL 不存在")
;         FileAppend("[" . FormatTime(, "HH:mm:ss") . "] GetEverythingResults: DLL 不存在`n", "debug_search.log")
;         ; 【调试代码结束】
;         return []
;     }
;     
;     ; ... 检查服务 ...
;     
;     try {
;         ; 【调试代码开始】
;         OutputDebug("GetEverythingResults: 准备调用 DLL")
;         FileAppend("[" . FormatTime(, "HH:mm:ss") . "] GetEverythingResults: 准备调用 DLL`n", "debug_search.log")
;         ; 【调试代码结束】
;         
;         DllCall(evDll "\Everything_SetSearchW", "WStr", keyword)
;         
;         ; 【调试代码开始】
;         OutputDebug("GetEverythingResults: SetSearchW 完成")
;         FileAppend("[" . FormatTime(, "HH:mm:ss") . "] GetEverythingResults: SetSearchW 完成`n", "debug_search.log")
;         ; 【调试代码结束】
;         
;         DllCall(evDll "\Everything_SetMax", "UInt", maxResults)
;         DllCall(evDll "\Everything_QueryW", "Int", 1)
;         
;         ; 【调试代码开始】
;         OutputDebug("GetEverythingResults: QueryW 完成")
;         FileAppend("[" . FormatTime(, "HH:mm:ss") . "] GetEverythingResults: QueryW 完成`n", "debug_search.log")
;         ; 【调试代码结束】
;         
;         count := DllCall(evDll "\Everything_GetNumResults", "UInt")
;         
;         ; 【调试代码开始】
;         OutputDebug("GetEverythingResults: 找到 " . count . " 个结果")
;         FileAppend("[" . FormatTime(, "HH:mm:ss") . "] GetEverythingResults: 找到 " . count . " 个结果`n", "debug_search.log")
;         ; 【调试代码结束】
;         
;         ; ... 原有代码 ...
;         
;     } catch as err {
;         ; 【调试代码开始】
;         OutputDebug("GetEverythingResults: 异常 - " . err.Message)
;         FileAppend("[" . FormatTime(, "HH:mm:ss") . "] GetEverythingResults: 异常 - " . err.Message . "`n", "debug_search.log")
;         ; 【调试代码结束】
;         return []
;     }

; ===================== 6. 在 ListView 更新前后添加 =====================
; 位置：CursorHelper (1).ahk 第 21872 行附近（Finally 块中）
;
;     } finally {
;         ; 【调试代码开始】
;         OutputDebug("进入 Finally 块，准备更新 ListView")
;         FileAppend("[" . FormatTime(, "HH:mm:ss") . "] 进入 Finally 块`n", "debug_search.log")
;         ; 【调试代码结束】
;         
;         try {
;             ; 【调试代码开始】
;             OutputDebug("准备删除 ListView 中的'正在搜索...'")
;             FileAppend("[" . FormatTime(, "HH:mm:ss") . "] 准备删除 ListView`n", "debug_search.log")
;             ; 【调试代码结束】
;             
;             SearchCenterResultLV.Delete()
;             
;             ; 【调试代码开始】
;             OutputDebug("ListView 删除完成，准备添加结果")
;             FileAppend("[" . FormatTime(, "HH:mm:ss") . "] ListView 删除完成`n", "debug_search.log")
;             ; 【调试代码结束】
;             
;             if (SearchErrorOccurred) {
;                 ; ... 显示错误 ...
;             } else if (IsSet(SortedResults) && SortedResults.Length > 0) {
;                 ; 【调试代码开始】
;                 OutputDebug("准备添加 " . SortedResults.Length . " 个结果到 ListView")
;                 FileAppend("[" . FormatTime(, "HH:mm:ss") . "] 准备添加 " . SortedResults.Length . " 个结果`n", "debug_search.log")
;                 ; 【调试代码结束】
;                 
;                 ; ... 添加结果 ...
;                 
;                 ; 【调试代码开始】
;                 OutputDebug("ListView 更新完成，共添加 " . AddCount . " 个结果")
;                 FileAppend("[" . FormatTime(, "HH:mm:ss") . "] ListView 更新完成`n", "debug_search.log")
;                 ; 【调试代码结束】
;             }
;             
;         } catch as err {
;             ; 【调试代码开始】
;             OutputDebug("ListView 更新失败: " . err.Message)
;             FileAppend("[" . FormatTime(, "HH:mm:ss") . "] ListView 更新失败: " . err.Message . "`n", "debug_search.log")
;             ; 【调试代码结束】
;         }
;     }

; ===================== 使用说明 =====================
;
; 1. 将上述调试代码添加到主程序的相应位置
; 2. 运行搜索功能
; 3. 查看调试输出：
;    - 使用 DebugView 工具查看 OutputDebug 输出
;    - 或者查看 debug_search.log 文件
; 4. 根据输出定位问题：
;    - 如果某个步骤后没有输出，说明卡在那里
;    - 如果出现异常信息，说明该步骤出错
;    - 如果耗时过长，说明该步骤性能有问题
;
; DebugView 下载地址：
; https://docs.microsoft.com/en-us/sysinternals/downloads/debugview
