# ClipboardHistoryPanel 和 searchcenter 的 everything64.dll 搜索代码
_Exported on 01/08/2026 at 14:50:58 GMT+8 from Cursor via WayLog_


**User**

列出@modules/ClipboardHistoryPanel.ahk 和searchcenter利用everything64.dll搜索匹配本地数据的关键代码和位置

---


**Cursor**

查找 ClipboardHistoryPanel.ahk 和 SearchCenter 中使用 Everything 搜索的关键代码和位置。



查找 SearchCenter 相关文件：



整理 ClipboardHistoryPanel.ahk 和 SearchCenter 中使用 Everything 搜索的关键代码和位置：



查看 `_ClipboardFTS5_GetEverythingResults` 的实现：



## Everything 搜索关键代码位置

### 一、ClipboardHistoryPanel.ahk 中的 Everything 搜索

#### 位置：`modules/ClipboardHistoryPanel.ahk` 第 1156-1210 行

```1156:1210:modules/ClipboardHistoryPanel.ahk
    ; ===================== 集成 Everything 文件搜索 =====================
    ; 参考 SearchCenter 的实现：当关键词长度 > 1 时，使用 Everything 搜索文件
    if (keyword != "" && StrLen(keyword) > 1 && HistorySelectedTag != "Image" && HistorySelectedTag != "Color" && HistorySelectedTag != "Code") {
        try {
            ; 使用辅助函数安全调用 GetEverythingResults（如果存在）
            everythingResults := _ClipboardFTS5_GetEverythingResults(keyword, 50)
            
            if (IsObject(everythingResults) && everythingResults.Length > 0) {
                ; 先收集所有文件结果
                fileResults := []
                
                for path in everythingResults {
                    ; 检查文件是否存在
                    if (!FileExist(path)) {
                        continue
                    }
                    
                    SplitPath(path, &FileName, &DirPath, &Ext, &NameNoExt)
                    
                    ; 创建文件结果项
                    fileItem := Map()
                    fileItem["ID"] := "file_" . path  ; 使用特殊前缀标识文件结果
                    fileItem["Content"] := path
                    fileItem["SourceApp"] := "文件系统"
                    fileItem["SourcePath"] := path
                    fileItem["IconPath"] := path
                    fileItem["DataType"] := "File"
                    fileItem["CharCount"] := 0
                    fileItem["Timestamp"] := ""  ; 文件没有时间戳
                    fileItem["LastCopyTime"] := ""
                    fileItem["CopyCount"] := 1
                    fileItem["ImagePath"] := ""
                    
                    fileResults.Push(fileItem)
                }
                
                ; 将文件结果插入到结果数组前面（优先显示文件结果）
                if (fileResults.Length > 0) {
                    ; 反转文件结果数组，然后插入到前面（这样第一个文件会在最前面）
                    fileResultsReverse := []
                    Loop fileResults.Length {
                        fileResultsReverse.Push(fileResults[fileResults.Length - A_Index + 1])
                    }
                    
                    ; 将文件结果插入到结果数组前面
                    for index, fileItem in fileResultsReverse {
                        results.InsertAt(index, fileItem)
                    }
                }
            }
        } catch as err {
            ; Everything 搜索失败，静默失败，不影响剪贴板历史显示
            ; OutputDebug("ClipboardHistoryPanel: Everything 搜索失败: " . err.Message . "`n")
        }
    }
```

要点：
- 调用位置：`RefreshHistoryData()` 函数内
- 触发条件：关键词长度 > 1，且标签不是 Image/Color/Code
- 调用函数：`_ClipboardFTS5_GetEverythingResults(keyword, 50)`
- 结果处理：将文件结果插入到数据库结果前面

---

### 二、SearchCenter 中的 Everything 搜索

#### 位置：`CursorHelper (1).ahk` 第 12295-12350 行

```12295:12350:CursorHelper (1).ahk
    ; 【关键修复】参考CapsLock+F的实现：优先使用Everything64.dll进行文件搜索
    ; 当关键词长度 > 1 时，使用Everything进行文件搜索
    if (StrLen(Keyword) > 1) {
        try {
            ; 调用GetEverythingResults获取文件搜索结果（增加 limit 以检测是否还有更多）
            Files := GetEverythingResults(Keyword, MaxResults + Offset + 1)
            
            ; 跳过 offset 数量的结果
            if (Offset > 0 && Files.Length > Offset) {
                Files := Files[Offset + 1]  ; 从 offset+1 开始
            } else if (Offset > 0) {
                Files := []  ; offset 超出范围
            }
            
            ; 检查是否还有更多数据
            hasMore := (Files.Length > MaxResults)
            if (hasMore) {
                Files.Pop()  ; 移除多查询的一条
            }
            
            ; 将Everything搜索结果转换为统一格式
            for path in Files {
                SplitPath(path, &FileName, &DirPath, &Ext, &NameNoExt)
                
                ResultItem := {
                    DataType: "file",
                    DataTypeName: "文件",
                    ID: path,
                    Title: FileName,
                    SubTitle: DirPath . " · " . (Ext ? Ext : "文件"),
                    Content: path,
                    Preview: path,
                    Source: "文件",
                    Metadata: Map(
                        "FilePath", path,
                        "FileName", FileName,
                        "DirPath", DirPath,
                        "Ext", Ext ? Ext : "",
                        "Timestamp", ""
                    ),
                    Action: "open_file",
                    ActionParams: Map("FilePath", path)
                }
                
                Results.Push(ResultItem)
            }
        } catch as err {
            ; 如果Everything搜索失败，继续使用数据库搜索作为回退
            OutputDebug("AHK_DEBUG: Everything DLL 搜索失败: " . err.Message)
        }
    }
    
    ; 如果Everything搜索结果已满足需求，直接返回
    if (Results.Length >= MaxResults) {
        return Results
    }
```

要点：
- 调用位置：SearchCenter 的搜索函数内
- 触发条件：关键词长度 > 1
- 调用函数：`GetEverythingResults(Keyword, MaxResults + Offset + 1)`
- 支持分页：通过 Offset 实现
- 结果格式：转换为统一的 ResultItem 格式

---

### 三、核心 Everything API 封装函数

#### 位置：`CursorHelper (1).ahk` 第 56-143 行

```56:143:CursorHelper (1).ahk
GetEverythingResults(keyword, maxResults := 30) {
    static evDll := A_ScriptDir "\lib\everything64.dll"
    static isInitialized := false

    ; 1. 基础防护
    if (!FileExist(evDll)) {
        OutputDebug("AHK_DEBUG: 致命错误 - 找不到 everything64.dll")
        return []
    }

    ; 2. 首次调用时，确保DLL已加载并检查Everything是否可用
    if (!isInitialized) {
        ; 加载DLL到进程空间
        hModule := DllCall("LoadLibrary", "Str", evDll, "Ptr")
        if (!hModule) {
            OutputDebug("AHK_DEBUG: 无法加载 everything64.dll")
            return []
        }
        isInitialized := true
        OutputDebug("AHK_DEBUG: Everything DLL 加载成功")
    }

    ; 3. 检查 Everything 客户端是否在运行（通过获取版本号判断IPC连接）
    majorVer := DllCall(evDll "\Everything_GetMajorVersion", "UInt")
    if (majorVer = 0) {
        errCode := DllCall(evDll "\Everything_GetLastError", "UInt")
        OutputDebug("AHK_DEBUG: Everything IPC 连接失败，错误码: " . errCode . " (2=未运行)")
        ; 尝试启动 Everything
        if (!ProcessExist("Everything.exe")) {
            OutputDebug("AHK_DEBUG: Everything.exe 未运行，尝试启动...")
            try {
                Run("Everything.exe -startup", , "Hide")
                Sleep(1000)  ; 等待启动
            } catch {
                OutputDebug("AHK_DEBUG: 无法启动 Everything")
            }
        }
        return []
    }
    OutputDebug("AHK_DEBUG: Everything 版本: " . majorVer)

    ; 4. 【关键】清理上一次的搜索状态，防止过滤器残留
    DllCall(evDll "\Everything_CleanUp")

    ; 5. 设置搜索参数
    DllCall(evDll "\Everything_SetSearchW", "WStr", keyword)
    DllCall(evDll "\Everything_SetMax", "UInt", maxResults)

    ; 6. 【核心修复】显式请求返回完整路径和文件名 (没有这一行，很多时候取不到路径)
    ; 0x00000004 = EVERYTHING_REQUEST_FULL_PATH_AND_FILE_NAME
    DllCall(evDll "\Everything_SetRequestFlags", "UInt", 0x00000004)

    ; 7. 执行查询 (1 = 阻塞等待直到结果准备好)
    isSuccess := DllCall(evDll "\Everything_QueryW", "Int", 1)

    ; 8. 错误诊断
    if (!isSuccess) {
        errCode := DllCall(evDll "\Everything_GetLastError", "UInt")
        OutputDebug("AHK_DEBUG: Everything 查询指令发送失败，错误码: " . errCode)
        ; 错误码说明: 0=OK, 1=内存错误, 2=IPC错误, 3=注册类失败, 4=创建窗口失败, 5=创建线程失败, 6=搜索词无效, 7=取消
        return []
    }

    ; 9. 获取结果
    count := DllCall(evDll "\Everything_GetNumResults", "UInt")
    OutputDebug("AHK_DEBUG: Everything DLL 返回数量: " . count . " (关键词: " . keyword . ")")

    ; 如果返回0，检查是否有错误
    if (count = 0) {
        errCode := DllCall(evDll "\Everything_GetLastError", "UInt")
        if (errCode != 0) {
            OutputDebug("AHK_DEBUG: Everything 查询后错误码: " . errCode)
        }
    }

    paths := []
    Loop Min(count, maxResults) {
        ; 预分配缓冲区，防乱码
        buf := Buffer(4096, 0)
        DllCall(evDll "\Everything_GetResultFullPathNameW", "UInt", A_Index-1, "Ptr", buf.Ptr, "UInt", 2048)
        fullPath := StrGet(buf.Ptr, "UTF-16")

        if (fullPath != "")
            paths.Push(fullPath)
    }

    return paths
}
```

核心 API 调用：
1. `Everything_GetMajorVersion` - 检查服务是否运行
2. `Everything_CleanUp` - 清理上次搜索状态
3. `Everything_SetSearchW` - 设置搜索关键词
4. `Everything_SetMax` - 设置最大结果数
5. `Everything_SetRequestFlags` - 设置请求标志（完整路径）
6. `Everything_QueryW` - 执行查询
7. `Everything_GetNumResults` - 获取结果数量
8. `Everything_GetResultFullPathNameW` - 获取完整路径

---

### 四、ClipboardFTS5 中的辅助函数

#### 位置：`modules/ClipboardFTS5.ahk` 第 258-337 行

```258:337:modules/ClipboardFTS5.ahk
_ClipboardFTS5_GetEverythingResults(keyword, maxResults := 10) {
    ; 首先尝试使用主脚本中的函数（如果存在）
    ; 使用 try-catch 安全地尝试调用主脚本函数
    try {
        ; 直接调用函数，如果函数不存在会抛出异常
        result := GetEverythingResults(keyword, maxResults)
        if (IsObject(result)) {
            return result
        }
    } catch {
        ; 主脚本函数不存在或调用失败，继续使用直接 DLL 调用
    }
    
    ; 直接实现 Everything 搜索（独立于主脚本）
    static evDll := ""
    static isInitialized := false
    
    ; 初始化 DLL 路径（支持主脚本目录和当前脚本目录）
    if (evDll = "") {
        ; 优先使用主脚本目录
        if (IsSet(MainScriptDir) && MainScriptDir != "") {
            evDll := MainScriptDir . "\lib\everything64.dll"
        } else {
            ; 尝试多个可能的路径
            possiblePaths := [
                A_ScriptDir . "\..\lib\everything64.dll",  ; 从 modules 目录向上
                A_ScriptDir . "\lib\everything64.dll",      ; 当前目录
                A_WorkingDir . "\lib\everything64.dll"       ; 工作目录
            ]
            
            for index, path in possiblePaths {
                if (FileExist(path)) {
                    evDll := path
                    break
                }
            }
            
            ; 如果仍未找到，使用默认路径
            if (evDll = "") {
                evDll := A_ScriptDir . "\..\lib\everything64.dll"
            }
        }
    }
    
    ; 1. 基础防护
    if (!FileExist(evDll)) {
        OutputDebug("AHK_DEBUG: ClipboardFTS5 - 找不到 everything64.dll: " . evDll)
        return []
    }
    
    ; 2. 首次调用时，确保DLL已加载并检查Everything是否可用
    if (!isInitialized) {
        ; 加载DLL到进程空间
        hModule := DllCall("LoadLibrary", "Str", evDll, "Ptr")
        if (!hModule) {
            OutputDebug("AHK_DEBUG: ClipboardFTS5 - 无法加载 everything64.dll")
            return []
        }
        isInitialized := true
        OutputDebug("AHK_DEBUG: ClipboardFTS5 - Everything DLL 加载成功")
    }
    
    ; 3. 检查 Everything 客户端是否在运行（通过获取版本号判断IPC连接）
    majorVer := DllCall(evDll . "\Everything_GetMajorVersion", "UInt")
    if (majorVer = 0) {
        errCode := DllCall(evDll . "\Everything_GetLastError", "UInt")
        OutputDebug("AHK_DEBUG: ClipboardFTS5 - Everything IPC 连接失败，错误码: " . errCode . " (2=未运行)")
        ; 尝试启动 Everything
        if (!ProcessExist("Everything.exe")) {
            OutputDebug("AHK_DEBUG: ClipboardFTS5 - Everything.exe 未运行，尝试启动...")
            try {
                ; 尝试在主脚本目录查找 Everything.exe
                EverythingExe := ""
                if (IsSet(MainScriptDir) && MainScriptDir != "") {
                    EverythingExe := MainScriptDir . "\Everything.exe"
                } else {
                    EverythingExe := A_ScriptDir . "\..\Everything.exe"
                }
```

要点：
- 优先调用主脚本的 `GetEverythingResults`
- 失败时回退到直接 DLL 调用
- 支持多路径查找 DLL

---

## 总结

| 模块 | 调用位置 | 调用函数 | 触发条件 | 结果处理 |
|------|---------|---------|---------|---------|
| **ClipboardHistoryPanel** | `RefreshHistoryData()` (1156行) | `_ClipboardFTS5_GetEverythingResults()` | 关键词长度>1，且非Image/Color/Code标签 | 插入到数据库结果前面 |
| **SearchCenter** | 搜索函数 (12295行) | `GetEverythingResults()` | 关键词长度>1 | 转换为ResultItem格式，支持分页 |
| **核心API** | `CursorHelper (1).ahk` (56行) | DLL直接调用 | - | 返回文件路径数组 |
| **辅助函数** | `ClipboardFTS5.ahk` (258行) | `_ClipboardFTS5_GetEverythingResults()` | - | 封装调用，提供回退机制 |

两个模块都通过 Everything64.dll 搜索本地文件，并将结果与数据库结果合并显示。

---
