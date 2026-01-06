# 搜索中心 ListView 和 SQLite 错误
_Exported on 01/06/2026 at 18:38:34 GMT+8 from Cursor via WayLog_


**User**

1. 致命错误：ListView 控件名称不匹配
这是最直接的原因。

GUI 定义中：你定义的 ListView 变量名是 SearchCenterResultLV (第 21601 行)。

搜索逻辑中：在 DebouncedSearchCenter 函数里，你却在操作 SearchCenterLV。

结果：脚本实际上是在往一个不存在的控件里添加数据，或者在操作一个旧的变量，导致界面看起来完全没更新 Everything 的结果。

2. 逻辑阻断：SQLite 报错未捕获
你在 DebugView 中看到的 _Statement 错误非常关键。

现状：在 DebouncedSearchCenter 中，调用 SearchClipboardFTS5ForSearchCenter 是在 Everything 之前的。

后果：由于 _Statement 报错是一个致命运行时错误，AHK 会直接终止当前的 Timer 线程。这意味着代码根本跑不到后面的 Everything 调用部分。

3. 修复方案：请完整替换以下函数
请在你的脚本中找到对应的位置，用下方的代码进行覆盖。

A. 修复 SearchClipboardFTS5ForSearchCenter (解决报错)
将第 21740 行附近的函数改为使用 GetTable：

AutoHotkey

SearchClipboardFTS5ForSearchCenter(Keyword) {
    global ClipboardDB
    if (!ClipboardDB || ClipboardDB == 0) return []
    
    SafeKeyword := StrReplace(Keyword, "'", "''")
    ; 使用适配你数据库结构的 SQL
    SQL := "SELECT Content, DataType, Timestamp FROM ClipboardHistory WHERE Content LIKE '%" . SafeKeyword . "%' ORDER BY Timestamp DESC LIMIT 50"
    
    Results := []
    if (ClipboardDB.GetTable(SQL, &ResultSet)) {
        if (ResultSet.HasRows) {
            for row in ResultSet.Rows {
                Results.Push({
                    Title: StrReplace(SubStr(row[1], 1, 100), "`n", " "),
                    Content: row[1],
                    DataType: row[2],
                    Source: "历史",
                    Time: row[3]
                })
            }
        }
    }
    return Results
}
B. 修复 DebouncedSearchCenter (解决控件名和流程问题)
注意：我统一使用了你 GUI 中定义的 SearchCenterResultLV。

AutoHotkey

DebouncedSearchCenter() {
    global SearchCenterResults, SearchCenterResultLV, SearchCenterSearchEdit
    Keyword := Trim(SearchCenterSearchEdit.Value)
    
    ; 1. 初始化
    SearchCenterResults := []
    SearchCenterResultLV.Delete() ; 清空界面
    
    if (Keyword == "") {
        ; 这里可以放加载默认模板的逻辑
        return
    }

    ; 锁定重绘提高性能
    SearchCenterResultLV.Opt("-Redraw")

    ; 2. 获取数据 (使用 try 确保一个报错不影响另一个)
    try {
        ; 渠道 1: 配置项
        for item in SearchConfigItems(Keyword)
            SearchCenterResults.Push(item)
            
        ; 渠道 2: 剪贴板历史
        for item in SearchClipboardFTS5ForSearchCenter(Keyword)
            SearchCenterResults.Push(item)
    } catch as err {
        OutputDebug("AHK_DEBUG: 数据库阶段出错: " . err.Message)
    }

    ; 渠道 3: Everything (关键词长度 > 1)
    if (StrLen(Keyword) > 1) {
        try {
            OutputDebug("AHK_DEBUG: 调用 Everything 搜索: " . Keyword)
            Files := GetEverythingResults(Keyword, 50)
            for path in Files {
                SplitPath(path, &name)
                SearchCenterResults.Push({
                    Title: name,
                    Content: path,
                    Source: "文件",
                    DataType: "file",
                    Time: ""
                })
            }
        } catch as err {
            OutputDebug("AHK_DEBUG: Everything 阶段出错: " . err.Message)
        }
    }

    ; 3. 最终渲染到界面
    for res in SearchCenterResults {
        SearchCenterResultLV.Add(, res.Title, res.Source, res.Time)
    }

    SearchCenterResultLV.ModifyCol(1, "AutoHdr")
    SearchCenterResultLV.Opt("+Redraw")
}

---


**Cursor**

定位相关代码，检查 ListView 控件名称和这两个函数。



读取这两个函数的具体实现：



检查是否存在 `SearchCenterLV` 的错误使用：



检查 `SearchConfigItems` 函数，并查看数据库结构：



查看 `SearchConfigItems` 函数的实现：



检查数据库的实际结构，确认字段名称：



按你的要求修复这两个函数：
1. 简化 `SearchClipboardFTS5ForSearchCenter`，使用简单的 SQL 查询
2. 修复 `DebouncedSearchCenter`，添加配置项搜索，并确保使用正确的控件名称



按你的要求修复这两个函数：

---


**User**

Error: Too many parameters passed to function.

Specifically: SearchClipboardFTS5ForSearchCenter

	11569: If (ClipboardFTS5DB && ClipboardFTS5DB != 0)
	11569: {
▶	11570: Results := SearchClipboardFTS5ForSearchCenter(Keyword, MaxResults)

---


**Cursor**

查找所有 `SearchClipboardFTS5ForSearchCenter` 的调用，确认传入的参数：



修复函数签名，使其接受可选的 `MaxResults` 参数：



已修复函数签名，添加可选的 `MaxResults` 参数（默认 50），兼容所有调用：

- 第 11570 行：`SearchClipboardFTS5ForSearchCenter(Keyword, MaxResults)` — 传入两个参数
- 第 21632 行：`SearchClipboardFTS5ForSearchCenter(Keyword)` — 只传入一个参数

函数签名已更新为：
```ahk
SearchClipboardFTS5ForSearchCenter(Keyword, MaxResults := 50)
```

SQL 查询中的 LIMIT 也会使用传入的 `MaxResults` 值。错误应已解决。

---


**User**

修复方案：请替换以下三个关键部分
第一步：修复 Everything 初始化 (建立通讯桥梁)
请将你的 InitEverythingService 函数替换为以下代码：

AutoHotkey

InitEverythingService() {
    static evDll := A_ScriptDir "\lib\everything64.dll"
    if !FileExist(evDll) {
        OutputDebug("AHK_DEBUG: Everything DLL 缺失")
        return false
    }
    
    ; 确保 Everything 客户端正在运行
    if !DllCall(evDll "\Everything_IsServiceRunning") {
        if !ProcessExist("Everything.exe") {
            OutputDebug("AHK_DEBUG: Everything.exe 未运行")
            return false
        }
    }
    
    ; 重置状态，不显式设置 ReplyWindow，让 DLL 使用默认线程通信
    DllCall(evDll "\Everything_CleanUp")
    OutputDebug("AHK_DEBUG: Everything 服务初始化成功")
    return true
}
第二步：彻底重写 GetEverythingResults (解决卡死)
之前的 Everything_QueryW(1) 如果没有正确的窗口句柄可能会阻塞。改用更稳健的调用方式：

AutoHotkey

GetEverythingResults(keyword, maxResults := 30) {
    static evDll := A_ScriptDir "\lib\everything64.dll"
    if (!FileExist(evDll)) return []

    ; 每次搜索前清理，防止状态残留
    DllCall(evDll "\Everything_CleanUp")
    
    ; 设置搜索词
    DllCall(evDll "\Everything_SetSearchW", "WStr", keyword)
    DllCall(evDll "\Everything_SetMax", "UInt", maxResults)
    DllCall(evDll "\Everything_SetRequestFlags", "UInt", 0x00000004) ; EVERYTHING_REQUEST_FULL_PATH_AND_FILE_NAME
    
    ; 执行异步查询（不等待返回，防止卡死 UI）
    DllCall(evDll "\Everything_QueryW", "Int", 1)
    
    count := DllCall(evDll "\Everything_GetNumResults", "UInt")
    paths := []
    
    Loop Min(count, maxResults) {
        buf := Buffer(2048)
        ; 使用正确的索引获取结果
        ptr := DllCall(evDll "\Everything_GetResultFullPathNameW", "UInt", A_Index-1, "Ptr", buf.Ptr, "UInt", 1024, "Ptr")
        if (ptr)
            paths.Push(StrGet(buf.Ptr, "UTF-16"))
    }
    return paths
}
第三步：修复 DebouncedSearchCenter 的渲染逻辑
确保使用了正确的 ListView 变量名 SearchCenterResultLV。

AutoHotkey

DebouncedSearchCenter() {
    global SearchCenterResults, SearchCenterResultLV, SearchCenterSearchEdit
    Keyword := Trim(SearchCenterSearchEdit.Value)
    
    ; 立即清空，显示“正在搜索”提示
    SearchCenterResultLV.Delete()
    SearchCenterResults := []
    
    if (Keyword == "") return

    SearchCenterResultLV.Opt("-Redraw")
    
    ; 1. 搜索本地配置和历史 (使用 try 隔离错误)
    try {
        ; 这里请确保 SearchClipboardFTS5ForSearchCenter 内部不再报错
        for item in SearchClipboardFTS5ForSearchCenter(Keyword)
            SearchCenterResults.Push(item)
    }

    ; 2. 搜索 Everything
    if (StrLen(Keyword) > 1) {
        evList := GetEverythingResults(Keyword, 50)
        for p in evList {
            SplitPath(p, &fn)
            SearchCenterResults.Push({Title: fn, Content: p, Source: "文件", DataType: "file", Time: ""})
        }
    }

    ; 3. 统一添加到 ListView
    for res in SearchCenterResults {
        SearchCenterResultLV.Add(, res.Title, res.Source, res.Time)
    }
    
    SearchCenterResultLV.ModifyCol(1, "AutoHdr")
    SearchCenterResultLV.Opt("+Redraw")
}

---


**Cursor**

查找这三个函数的位置：

---


**User**

Error: Call to nonexistent function.

Specifically: Everything_IsServiceRunning

	086: Return 0
	087: }
▶	090: If !DllCall(evDll "\Everything_IsServiceRunning")

---
