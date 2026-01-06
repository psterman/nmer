# Empty string in time comparison
_Exported on 01/06/2026 at 16:50:33 GMT+8 from Cursor via WayLog_


**User**

Error: Expected a Number but got an empty string.

	22065: TimeI := Results[i].HasProp("Timestamp") ? Results[i].Timestamp : Results[i].Time
	22066: TimeJ := Results[j].HasProp("Timestamp") ? Results[j].Timestamp : Results[j].Time
▶	22068: If (TimeJ > TimeI)

---


**Cursor**

这个错误表明在比较 `TimeJ > TimeI` 时，其中一个或两个变量是空字符串而不是数字。让我分析一下代码逻辑：

我看到代码中有两个排序逻辑，第一个（21988行）已经修复了空字符串问题，但第二个（22065行）没有修复。让我修复第二个排序逻辑：

修复完成！主要修改了第22065-22068行的排序逻辑，添加了：

1. **空字符串检查**：在比较前检查 `TimeI` 和 `TimeJ` 是否为空
2. **空值处理逻辑**：如果 `TimeI` 为空而 `TimeJ` 不为空，则交换位置（让空值排在后面）
3. **使用 StrCompare**：用字符串比较函数替代直接比较，避免类型错误

这样修改后，即使 `Results[i].Time` 或 `Results[i].Timestamp` 返回空字符串，也不会触发 "Expected a Number but got an

---


**User**

DebouncedSearchCenter 函数虽然执行了 Everything 搜索，但没有将搜索结果添加到界面的表格（ListView）中。

目前脚本的逻辑只把 Everything 的结果存进了内存数组 SearchCenterResults，却在界面显示的循环里漏掉了它们。

1. 核心问题修复：同步更新界面
请在你的脚本中找到 DebouncedSearchCenter 函数（约第 21680 行），将最后的部分修改为以下逻辑。

修改重点： 确保在 ListView.Add 的循环中，不论是配置项、剪贴板历史还是文件，都能被添加进去。

AutoHotkey

    ; ... 前面的 SearchConfigItems 和 SearchClipboardFTS5 逻辑保持不变 ...

    ; ========== 第二步：搜索 Everything ==========
    if (StrLen(Keyword) > 1) {
        try {
            EverythingPaths := GetEverythingResults(Keyword, 50)
            for path in EverythingPaths {
                SplitPath(path, &fileName)
                ; 将文件结果存入内存数组
                SearchCenterResults.Push({
                    Title: fileName,
                    Content: path,
                    Source: "Everything",
                    DataType: "file",
                    Time: ""
                })
            }
        }
    }

    ; ========== 第三步：渲染到界面 (这一步是修复关键) ==========
    SearchCenterLV.Delete()
    SearchCenterLV.Opt("-Redraw")
    for res in SearchCenterResults {
        ; 确保所有 Push 进去的结果都 Add 到 ListView 中
        SearchCenterLV.Add(, res.Title, res.Source, res.Time)
    }
    SearchCenterLV.ModifyCol(1, "AutoHdr")
    SearchCenterLV.Opt("+Redraw")
2. 检查 Everything 接口配置
为了确保 AHK 能够正确通过 DLL 通信，请检查脚本顶部的 GetEverythingResults 函数（约第 37 行）是否符合以下高性能标准：

AutoHotkey

GetEverythingResults(keyword, maxResults := 30) {
    static evDll := A_ScriptDir "\lib\everything64.dll"
    if (!FileExist(evDll)) return []

    ; 设置搜索条件
    DllCall(evDll "\Everything_SetSearchW", "WStr", keyword)
    DllCall(evDll "\Everything_SetMax", "UInt", maxResults)
    DllCall(evDll "\Everything_SetSort", "UInt", 14) ; 按路径排序
    
    ; 执行查询
    if !DllCall(evDll "\Everything_QueryW", "Int", 1)
        return []

    count := DllCall(evDll "\Everything_GetNumResults", "UInt")
    paths := []
    Loop Min(count, maxResults) {
        buf := Buffer(2048)
        DllCall(evDll "\Everything_GetResultFullPathNameW", "UInt", A_Index-1, "Ptr", buf.Ptr, "UInt", 1024)
        paths.Push(StrGet(buf.Ptr, "UTF-16"))
    }
    return paths
}

---


**Cursor**

我来修复 DebouncedSearchCenter 函数，确保 Everything 搜索结果能正确显示在界面上。

现在我看到问题了！代码中 Everything 搜索结果确实被添加到了 `Results` 数组中，

---


**User**

将你的 DebouncedSearchCenter 函数修改为如下形式：

AutoHotkey

DebouncedSearchCenter() {
    global SearchCenterResults, SearchCenterLV, SearchCenterEdit
    Keyword := Trim(SearchCenterEdit.Value)
    
    ; 埋点 1：记录进入函数
    OutputDebug("AHK_DEBUG: 开始搜索，关键词 = " . Keyword)
    
    SearchCenterResults := []
    SearchCenterLV.Delete()
    
    if (Keyword == "") {
        LoadDefaultTemplates()
        return
    }

    try {
        ; 渠道 1: 配置项
        OutputDebug("AHK_DEBUG: 正在匹配配置项...")
        ; ... 你的 SearchConfigItems 逻辑 ...
        
        ; 渠道 2: SQLite 历史
        OutputDebug("AHK_DEBUG: 正在查询 SQLite...")
        ; ... 你的 SearchClipboardFTS5 逻辑 ...

        ; 渠道 3: Everything (最重要)
        if (StrLen(Keyword) > 1) {
            OutputDebug("AHK_DEBUG: 正在调用 Everything DLL...")
            EverythingPaths := GetEverythingResults(Keyword, 50)
            
            ; 埋点 2：记录 DLL 返回的结果数量
            OutputDebug("AHK_DEBUG: Everything 返回条数: " . EverythingPaths.Length)
            
            for path in EverythingPaths {
                SplitPath(path, &fileName)
                SearchCenterResults.Push({
                    Title: fileName,
                    Content: path,
                    Source: "Everything",
                    DataType: "file",
                    Time: ""
                })
            }
        }
    } catch as err {
        OutputDebug("AHK_DEBUG: 发生错误: " . err.Message)
    }

    ; 渠道 4: 渲染界面
    OutputDebug("AHK_DEBUG: 正在渲染 ListView, 总结果数: " . SearchCenterResults.Length)
    SearchCenterLV.Opt("-Redraw")
    for res in SearchCenterResults {
        SearchCenterLV.Add(, res.Title, res.Source, res.Time)
    }
    SearchCenterLV.ModifyCol(1, "AutoHdr")
    SearchCenterLV.Opt("+Redraw")
    OutputDebug("AHK_DEBUG: 渲染完成")
}

---


**Cursor**

我来按照你的要求修改 DebouncedSearchCenter 函数，添加详细的调试信息和清晰的逻辑结构：现在我看到完整的 DebouncedSearchCenter 函数了。让我按照你的要求修改它，添加详细的调试信息：

---


**User**

继续

---
