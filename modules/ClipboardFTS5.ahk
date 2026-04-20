; ======================================================================================================================
; 高性能剪贴板管理器 - SQLite FTS5 全文搜索模块
; 版本: 1.0.0
; 作者: AutoHotkey v2
; 功能: 
;   - SQLite FTS5 全文搜索数据库
;   - 文本与图片的异步入库
;   - 智能内容分类（URL、代码块、Email）
;   - 图片缩略图生成
;   - 数据清理（保留30天，收藏的永不删除）
; ======================================================================================================================

#Requires AutoHotkey v2.0
#Include ..\lib\Class_SQLiteDB.ahk
#Include ..\lib\Gdip_All.ahk
#Include ..\lib\WinClipAPI.ahk
#Include ..\lib\WinClip.ahk
#Include ..\lib\ImagePut.ahk

; ===================== 全局变量 =====================
global ClipboardFTS5DB := 0  ; SQLite FTS5 数据库对象
; 获取主脚本目录（主脚本会在包含此模块前定义 MainScriptDir）
global ClipboardFTS5DBPath := (IsSet(MainScriptDir) ? MainScriptDir : A_ScriptDir) "\Clipboard.db"  ; 数据库文件路径

; ===================== 数据库初始化 =====================
; 创建 Clipboard.db 数据库，开启 WAL 模式，创建 FTS5 虚拟表
InitClipboardFTS5DB() {
    global ClipboardFTS5DB, ClipboardFTS5DBPath, MainScriptDir
    
    ; 获取主脚本目录（主脚本会在包含此模块前定义 MainScriptDir）
    ScriptDir := (IsSet(MainScriptDir) ? MainScriptDir : A_ScriptDir)
    
    ; 1. 检查 sqlite3.dll 是否存在（指向主脚本所在目录）
    DllPath := ScriptDir "\sqlite3.dll"
    if (!FileExist(DllPath)) {
        MsgBox("sqlite3.dll 未找到。`n请确保 sqlite3.dll 与脚本位于同一目录。", "数据库初始化错误", "IconX")
        ClipboardFTS5DB := 0
        return false
    }
    
    ; 2. 创建 SQLiteDB 实例并打开数据库
    try {
        ClipboardFTS5DB := SQLiteDB()
        if (!ClipboardFTS5DB.OpenDB(ClipboardFTS5DBPath)) {
            MsgBox("无法打开数据库: " . ClipboardFTS5DBPath . "`n错误: " . ClipboardFTS5DB.ErrorMsg, "数据库初始化错误", "IconX")
            ClipboardFTS5DB := 0
            return false
        }
        
        ; 3. 开启 WAL 模式以支持并发读写
        SQL := "PRAGMA journal_mode = WAL;"
        if (!ClipboardFTS5DB.Exec(SQL)) {
            MsgBox("开启 WAL 模式失败: " . ClipboardFTS5DB.ErrorMsg, "数据库初始化错误", "IconX")
            ClipboardFTS5DB.CloseDB()
            ClipboardFTS5DB := 0
            return false
        }
        
        ; 4. 创建主表 ClipMain（存储完整数据）
        SQL := "CREATE TABLE IF NOT EXISTS ClipMain (" .
               "ID INTEGER PRIMARY KEY AUTOINCREMENT, " .
               "Content TEXT, " .
               "SourceApp TEXT, " .
               "DataType TEXT, " .
               "CharCount INTEGER, " .
               "Timestamp DATETIME DEFAULT (datetime('now', 'localtime')), " .
               "ImagePath TEXT, " .
               "ThumbnailData BLOB, " .
               "IsFavorite INTEGER DEFAULT 0)"
        
        if (!ClipboardFTS5DB.Exec(SQL)) {
            MsgBox("创建主表失败: " . ClipboardFTS5DB.ErrorMsg, "数据库初始化错误", "IconX")
            ClipboardFTS5DB.CloseDB()
            ClipboardFTS5DB := 0
            return false
        }
        
        ; 4.1 添加新字段（如果表已存在，使用 ALTER TABLE）
        try {
            ; 检查字段是否存在，如果不存在则添加
            SQL := "PRAGMA table_info(ClipMain)"
            table := ""
            if (ClipboardFTS5DB.GetTable(SQL, &table)) {
                hasSourcePath := false
                hasIconPath := false
                hasLastCopyTime := false
                hasCopyCount := false
                hasSourceUrl := false
                hasImageFormat := false
                hasImageWidth := false
                hasImageHeight := false
                hasFileSize := false
                hasThumbPath := false
                
                if (table.HasRows && table.Rows.Length > 0) {
                    Loop table.Rows.Length {
                        row := table.Rows[A_Index]
                        columnName := row[2]  ; 列名在第2列
                        if (columnName = "ThumbPath") {
                            hasThumbPath := true
                        }
                        if (columnName = "SourcePath") {
                            hasSourcePath := true
                        }
                        if (columnName = "IconPath") {
                            hasIconPath := true
                        }
                        if (columnName = "LastCopyTime") {
                            hasLastCopyTime := true
                        }
                        if (columnName = "CopyCount") {
                            hasCopyCount := true
                        }
                        if (columnName = "SourceUrl") {
                            hasSourceUrl := true
                        }
                        if (columnName = "ImageFormat") {
                            hasImageFormat := true
                        }
                        if (columnName = "ImageWidth") {
                            hasImageWidth := true
                        }
                        if (columnName = "ImageHeight") {
                            hasImageHeight := true
                        }
                        if (columnName = "FileSize") {
                            hasFileSize := true
                        }
                    }
                }
                
                ; 添加缺失的字段（确保执行成功）
                if (!hasSourcePath) {
                    ClipboardFTS5DB.Exec("ALTER TABLE ClipMain ADD COLUMN SourcePath TEXT")
                }
                if (!hasIconPath) {
                    ClipboardFTS5DB.Exec("ALTER TABLE ClipMain ADD COLUMN IconPath TEXT")
                }
                if (!hasLastCopyTime) {
                    ClipboardFTS5DB.Exec("ALTER TABLE ClipMain ADD COLUMN LastCopyTime DATETIME DEFAULT (datetime('now', 'localtime'))")
                }
                if (!hasCopyCount) {
                    ClipboardFTS5DB.Exec("ALTER TABLE ClipMain ADD COLUMN CopyCount INTEGER DEFAULT 1")
                }
                if (!hasSourceUrl) {
                    ClipboardFTS5DB.Exec("ALTER TABLE ClipMain ADD COLUMN SourceUrl TEXT")
                }
                if (!hasImageFormat) {
                    ClipboardFTS5DB.Exec("ALTER TABLE ClipMain ADD COLUMN ImageFormat TEXT")
                }
                if (!hasImageWidth) {
                    ClipboardFTS5DB.Exec("ALTER TABLE ClipMain ADD COLUMN ImageWidth INTEGER")
                }
                if (!hasImageHeight) {
                    ClipboardFTS5DB.Exec("ALTER TABLE ClipMain ADD COLUMN ImageHeight INTEGER")
                }
                if (!hasFileSize) {
                    ClipboardFTS5DB.Exec("ALTER TABLE ClipMain ADD COLUMN FileSize INTEGER")
                }
                if (!hasThumbPath) {
                    ClipboardFTS5DB.Exec("ALTER TABLE ClipMain ADD COLUMN ThumbPath TEXT")
                }
            }
        } catch {
            ; 忽略错误，继续执行
        }
        
        ; 5. 创建 FTS5 虚拟表（用于高性能全文搜索）
        ; 使用 unicode61 分词器以完美支持中文搜索
        SQL := "CREATE VIRTUAL TABLE IF NOT EXISTS ClipboardHistory USING fts5(" .
               "Content, " .
               "SourceApp, " .
               "DataType, " .
               "LastCopyTime UNINDEXED, " .
               "SourcePath UNINDEXED, " .
               "IconPath UNINDEXED, " .
               "CharCount UNINDEXED, " .
               "Timestamp UNINDEXED, " .
               "ImagePath UNINDEXED, " .
               "IsFavorite UNINDEXED, " .
               "CopyCount UNINDEXED, " .
               "tokenize='unicode61'" .
               ")"
        
        if (!ClipboardFTS5DB.Exec(SQL)) {
            ; 如果 FTS5 创建失败，记录但不中断（可能是 SQLite 版本不支持）
            ; 继续使用普通表
        }
        
        ; 5.1 创建触发器，自动同步 ClipMain 表到 FTS5 虚拟表
        ; 先删除旧触发器（如果存在），避免字段不匹配问题
        ClipboardFTS5DB.Exec("DROP TRIGGER IF EXISTS clipmain_fts5_insert")
        ClipboardFTS5DB.Exec("DROP TRIGGER IF EXISTS clipmain_fts5_update")
        ClipboardFTS5DB.Exec("DROP TRIGGER IF EXISTS clipmain_fts5_delete")
        
        ; 插入触发器（动态构建，根据字段存在情况）
        ; 构建字段列表和值列表
        insertFields := "rowid, Content, SourceApp, DataType, SourcePath, IconPath, CharCount, Timestamp, ImagePath, IsFavorite"
        insertValues := "new.ID, new.Content, new.SourceApp, new.DataType, new.SourcePath, new.IconPath, new.CharCount, new.Timestamp, new.ImagePath, new.IsFavorite"
        
        if (hasLastCopyTime) {
            insertFields .= ", LastCopyTime"
            insertValues .= ", COALESCE(new.LastCopyTime, new.Timestamp)"
        } else {
            insertFields .= ", LastCopyTime"
            insertValues .= ", new.Timestamp"
        }
        
        if (hasCopyCount) {
            insertFields .= ", CopyCount"
            insertValues .= ", new.CopyCount"
        } else {
            insertFields .= ", CopyCount"
            insertValues .= ", 1"
        }
        
        SQL := "CREATE TRIGGER clipmain_fts5_insert AFTER INSERT ON ClipMain BEGIN " .
               "INSERT INTO ClipboardHistory(" . insertFields . ") " .
               "VALUES (" . insertValues . "); " .
               "END"
        ClipboardFTS5DB.Exec(SQL)
        
        ; 更新触发器（动态构建）
        updateFields := "Content = new.Content, " .
                       "SourceApp = new.SourceApp, " .
                       "DataType = new.DataType, " .
                       "SourcePath = new.SourcePath, " .
                       "IconPath = new.IconPath, " .
                       "CharCount = new.CharCount, " .
                       "Timestamp = new.Timestamp, " .
                       "ImagePath = new.ImagePath, " .
                       "IsFavorite = new.IsFavorite"
        
        if (hasLastCopyTime) {
            updateFields .= ", LastCopyTime = COALESCE(new.LastCopyTime, new.Timestamp)"
        } else {
            updateFields .= ", LastCopyTime = new.Timestamp"
        }
        
        if (hasCopyCount) {
            updateFields .= ", CopyCount = new.CopyCount"
        } else {
            updateFields .= ", CopyCount = 1"
        }
        
        SQL := "CREATE TRIGGER clipmain_fts5_update AFTER UPDATE ON ClipMain BEGIN " .
               "UPDATE ClipboardHistory SET " . updateFields . " " .
               "WHERE rowid = new.ID; " .
               "END"
        ClipboardFTS5DB.Exec(SQL)
        
        ; 删除触发器
        SQL := "CREATE TRIGGER IF NOT EXISTS clipmain_fts5_delete AFTER DELETE ON ClipMain BEGIN " .
               "DELETE FROM ClipboardHistory WHERE rowid = old.ID; " .
               "END"
        ClipboardFTS5DB.Exec(SQL)
        
        ; 5.2 如果 FTS5 表已存在但 ClipMain 表有数据，同步现有数据
        SQL := "INSERT OR IGNORE INTO ClipboardHistory(rowid, Content, SourceApp, DataType, LastCopyTime, SourcePath, IconPath, CharCount, Timestamp, ImagePath, IsFavorite, CopyCount) " .
               "SELECT ID, Content, SourceApp, DataType, " .
               "COALESCE(LastCopyTime, Timestamp), SourcePath, IconPath, CharCount, Timestamp, ImagePath, IsFavorite, " .
               "COALESCE(CopyCount, 1) " .
               "FROM ClipMain " .
               "WHERE ID NOT IN (SELECT rowid FROM ClipboardHistory)"
        ClipboardFTS5DB.Exec(SQL)
        
        ; 6. 创建索引以提升查询性能（针对 ClipMain 表）
        SQL := "CREATE INDEX IF NOT EXISTS idx_clipmain_timestamp ON ClipMain(Timestamp DESC)"
        ClipboardFTS5DB.Exec(SQL)
        
        SQL := "CREATE INDEX IF NOT EXISTS idx_clipmain_datatype ON ClipMain(DataType)"
        ClipboardFTS5DB.Exec(SQL)
        
        SQL := "CREATE INDEX IF NOT EXISTS idx_clipmain_isfavorite ON ClipMain(IsFavorite)"
        ClipboardFTS5DB.Exec(SQL)
        
        return true
        
    } catch as err {
        MsgBox("数据库初始化异常: " . err.Message, "数据库初始化错误", "IconX")
        if (ClipboardFTS5DB != 0) {
            ClipboardFTS5DB.CloseDB()
        }
        ClipboardFTS5DB := 0
        return false
    }
}

; ===================== Everything 搜索辅助函数 =====================
; 内部辅助函数：直接实现 Everything 搜索，不依赖主脚本
; 优先使用主脚本中的 GetEverythingResults（如果存在），否则直接调用 DLL
_ClipboardFTS5_GetEverythingResults(keyword, maxResults := 10, includeFolders := true) {
    ; 首先尝试使用主脚本中的函数（如果存在）
    ; 使用 try-catch 安全地尝试调用主脚本函数
    try {
        ; 直接调用函数，如果函数不存在会抛出异常
        result := (%"GetEverythingResults"%).Call(keyword, maxResults, includeFolders)
        if (IsObject(result)) {
            return result
        }
    } catch {
        ; 主脚本函数不存在或调用失败，继续使用直接 DLL 调用
    }
    
    ; 直接实现 Everything 搜索（独立于主脚本，与主函数保持一致）
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
        ; 尝试启动 Everything（带重试机制）
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
                
                if (FileExist(EverythingExe)) {
                    Run(EverythingExe . " -startup", , "Hide")
                    Sleep(2000)  ; 等待启动，增加等待时间
                } else {
                    ; 尝试在系统 PATH 中查找
                    Run("Everything.exe -startup", , "Hide")
                    Sleep(2000)
                }
                ; 重试检查版本
                majorVer := DllCall(evDll . "\Everything_GetMajorVersion", "UInt")
                if (majorVer = 0) {
                    OutputDebug("AHK_DEBUG: ClipboardFTS5 - Everything 服务启动失败，请手动启动 Everything.exe")
                    return []
                }
            } catch as err {
                OutputDebug("AHK_DEBUG: ClipboardFTS5 - 无法启动 Everything: " . err.Message)
                return []
            }
        } else {
            ; Everything 进程存在但IPC连接失败，等待重试
            Sleep(1000)
            majorVer := DllCall(evDll . "\Everything_GetMajorVersion", "UInt")
            if (majorVer = 0) {
                OutputDebug("AHK_DEBUG: ClipboardFTS5 - Everything 进程存在但IPC连接失败")
                return []
            }
        }
    }
    OutputDebug("AHK_DEBUG: ClipboardFTS5 - Everything 版本: " . majorVer)
    
    ; 4. 【关键】清理上一次的搜索状态，防止过滤器残留
    DllCall(evDll . "\Everything_CleanUp")
    
    ; 5. 设置搜索参数
    DllCall(evDll . "\Everything_SetSearchW", "WStr", keyword)
    DllCall(evDll . "\Everything_SetMax", "UInt", maxResults)
    
    ; 6. 【扩展】请求更多信息：完整路径、文件名、大小、修改日期、属性等
    ; 0x00000004 = EVERYTHING_REQUEST_FULL_PATH_AND_FILE_NAME
    ; 0x00000020 = EVERYTHING_REQUEST_SIZE
    ; 0x00000080 = EVERYTHING_REQUEST_DATE_MODIFIED
    ; 0x00000200 = EVERYTHING_REQUEST_ATTRIBUTES
    requestFlags := 0x00000004 | 0x00000020 | 0x00000080 | 0x00000200
    DllCall(evDll . "\Everything_SetRequestFlags", "UInt", requestFlags)
    
    ; 7. 执行查询 (1 = 阻塞等待直到结果准备好)
    isSuccess := DllCall(evDll . "\Everything_QueryW", "Int", 1)
    
    ; 8. 错误诊断
    if (!isSuccess) {
        errCode := DllCall(evDll . "\Everything_GetLastError", "UInt")
        OutputDebug("AHK_DEBUG: ClipboardFTS5 - Everything 查询指令发送失败，错误码: " . errCode)
        ; 错误码说明: 0=OK, 1=内存错误, 2=IPC错误, 3=注册类失败, 4=创建窗口失败, 5=创建线程失败, 6=搜索词无效, 7=取消
        return []
    }
    
    ; 9. 获取结果
    count := DllCall(evDll . "\Everything_GetNumResults", "UInt")
    OutputDebug("AHK_DEBUG: ClipboardFTS5 - Everything DLL 返回数量: " . count . " (关键词: " . keyword . ")")
    
    ; 如果返回0，检查是否有错误
    if (count = 0) {
        errCode := DllCall(evDll . "\Everything_GetLastError", "UInt")
        if (errCode != 0) {
            OutputDebug("AHK_DEBUG: ClipboardFTS5 - Everything 查询后错误码: " . errCode)
        }
    }
    
    ; 10. 获取结果（返回Map对象数组，包含路径、类型、大小等信息）
    results := []
    Loop Min(count, maxResults) {
        index := A_Index - 1
        
        ; 获取文件属性以判断是文件还是文件夹
        attributes := DllCall(evDll . "\Everything_GetResultAttributes", "UInt", index, "UInt")
        isDirectory := (attributes & 0x10) != 0  ; FILE_ATTRIBUTE_DIRECTORY = 0x10
        
        ; 如果设置了不包含文件夹，则跳过文件夹
        if (!includeFolders && isDirectory) {
            continue
        }
        
        ; 获取完整路径
        buf := Buffer(4096, 0)
        DllCall(evDll . "\Everything_GetResultFullPathNameW", "UInt", index, "Ptr", buf.Ptr, "UInt", 2048)
        fullPath := StrGet(buf.Ptr, "UTF-16")
        
        if (fullPath = "") {
            continue
        }
        
        ; 获取文件大小
        fileSize := DllCall(evDll . "\Everything_GetResultSize", "UInt", index, "Int64")
        
        ; 获取修改日期
        fileTime := DllCall(evDll . "\Everything_GetResultDateModified", "UInt", index, "Int64")
        
        ; 创建结果对象
        result := Map()
        result["Path"] := fullPath
        result["IsDirectory"] := isDirectory
        result["Type"] := isDirectory ? "folder" : "file"
        result["Size"] := fileSize
        result["DateModified"] := fileTime
        result["Attributes"] := attributes
        
        results.Push(result)
    }
    
    return results
}

; ===================== 获取应用信息 =====================
; 获取当前活动窗口的应用路径和图标路径
; 增强版：使用 Windows Shell API 和 Everything64.dll 查找图标路径
GetApplicationInfo() {
    info := Map()
    info["SourceApp"] := "Unknown"
    info["SourcePath"] := ""
    info["IconPath"] := ""
    
    try {
        ; 获取活动窗口ID
        ActiveID := WinGetID("A")
        
        ; 获取进程名
        SourceApp := WinGetProcessName(ActiveID)
        info["SourceApp"] := SourceApp
        
        ; 获取进程路径
        SourcePath := ""
        try {
            SourcePath := WinGetProcessPath(ActiveID)
            info["SourcePath"] := SourcePath
        } catch {
            ; 如果无法获取路径，尝试多种方法查找
            if (SourceApp != "Unknown" && SourceApp != "") {
                ; 方法1: 尝试在常见路径查找
                commonPaths := [
                    A_ProgramFiles . "\" . SourceApp,
                    A_ProgramFiles . "\Windows\System32\" . SourceApp,
                    A_ProgramFiles . "\Windows\" . SourceApp,
                    A_ProgramFiles . " (x86)\" . SourceApp,
                    A_AppData . "\..\Local\" . SourceApp,
                    A_AppData . "\..\Roaming\" . SourceApp
                ]
                
                for index, path in commonPaths {
                    if (FileExist(path)) {
                        SourcePath := path
                        info["SourcePath"] := path
                        break
                    }
                }
                
                ; 方法2: 如果仍未找到，尝试使用 Everything64.dll 搜索
                if (SourcePath = "" || !FileExist(SourcePath)) {
                    ; 使用内部辅助函数安全调用 GetEverythingResults（如果存在）
                    try {
                        ; 搜索进程名对应的 exe 文件
                        searchPattern := SourceApp
                        ; 如果进程名不包含扩展名，添加 .exe
                        if (!InStr(SourceApp, ".")) {
                            searchPattern := SourceApp . ".exe"
                        }
                        
                        ; 使用 Everything 搜索文件（精确匹配文件名）
                        ; 使用辅助函数，如果主脚本中定义了 GetEverythingResults 则使用它
                        everythingResults := _ClipboardFTS5_GetEverythingResults(searchPattern, 10)
                        
                        ; 遍历搜索结果，找到匹配的文件
                        if (IsObject(everythingResults) && everythingResults.Length > 0) {
                            for index, resultPath in everythingResults {
                                SplitPath(resultPath, &FileName)
                                ; 检查文件名是否匹配进程名（不区分大小写）
                                if (StrLower(FileName) = StrLower(SourceApp) || StrLower(FileName) = StrLower(searchPattern)) {
                                    if (FileExist(resultPath)) {
                                        SourcePath := resultPath
                                        info["SourcePath"] := resultPath
                                        break
                                    }
                                }
                            }
                            
                            ; 如果精确匹配失败，尝试模糊匹配（文件名包含进程名）
                            if (SourcePath = "" || !FileExist(SourcePath)) {
                                for index, resultPath in everythingResults {
                                    SplitPath(resultPath, &FileName, , &Ext)
                                    ; 检查是否是 exe 文件且文件名包含进程名
                                    if (StrLower(Ext) = "exe" && InStr(StrLower(FileName), StrLower(SourceApp))) {
                                        if (FileExist(resultPath)) {
                                            SourcePath := resultPath
                                            info["SourcePath"] := resultPath
                                            break
                                        }
                                    }
                                }
                            }
                        }
                    } catch as e {
                        ; GetEverythingResults 函数不存在或 Everything 搜索失败，继续使用其他方法
                        ; 不输出错误，静默失败
                    }
                }
            }
        }
        
        ; 确定图标路径
        IconPath := ""
        
        ; 方法1: 如果文件存在，直接使用文件路径（exe/dll 文件本身包含图标）
        if (SourcePath != "" && FileExist(SourcePath)) {
            IconPath := SourcePath
        }
        ; 方法2: 如果文件不存在但进程名已知，使用 Windows Shell API 通过扩展名获取系统图标
        ; 注意：虽然 Shell API 不能直接返回文件路径，但可以通过扩展名获取图标索引
        ; UI 层可以通过 GetFileIconIndex 函数使用扩展名获取图标索引
        else if (SourceApp != "Unknown" && SourceApp != "") {
            ; 提取文件扩展名
            SplitPath(SourceApp, , , &Ext)
            if (Ext = "") {
                Ext := "exe"  ; 默认使用 exe 扩展名
            }
            
            ; 使用 Windows Shell API 验证扩展名是否有效
            ; UI 层可以通过 GetFileIconIndex("." . Ext) 获取图标索引
            ; 这里不设置 IconPath，因为 Shell API 不返回文件路径
        }
        
        ; 设置图标路径（只有找到实际文件时才设置）
        if (IconPath != "") {
            info["IconPath"] := IconPath
        } else if (SourcePath != "" && FileExist(SourcePath)) {
            ; 如果 SourcePath 存在但 IconPath 未设置，使用 SourcePath
            info["IconPath"] := SourcePath
        }
        ; 如果都找不到，IconPath 保持为空字符串，UI 层会使用默认图标或通过扩展名获取
        
    } catch {
        ; 使用默认值
    }
    
    return info
}

; ===================== 智能内容分类 =====================
; 识别文本类型（URL、代码块、Email、Text）
ClassifyContentType(content) {
    if (content = "" || StrLen(content) = 0) {
        return "Text"
    }
    
    trimmedContent := Trim(content, " `t`r`n")
    
    ; 1. 链接检测 (Link/URL)
    if (RegExMatch(trimmedContent, "i)^(https?:\/\/|www\.|ftp:\/\/)[^\s]+$")) {
        return "Link"
    }
    
    ; 2. 邮箱检测 (Email)
    if (RegExMatch(trimmedContent, "i)^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$")) {
        return "Email"
    }
    
    ; 2.5 颜色检测 (Color) - 检测各类色值格式
    ; 检测 #RRGGBB 或 #RGB 格式（支持3位、4位、6位、8位）
    if (RegExMatch(trimmedContent, "i)^#[0-9A-Fa-f]{3,8}$")) {
        return "Color"
    }
    ; 检测 rgb(r, g, b) 或 rgba(r, g, b, a) 格式
    if (RegExMatch(trimmedContent, "i)^rgba?\([^)]+\)$")) {
        return "Color"
    }
    ; 检测 hsl(h, s%, l%) 或 hsla(h, s%, l%, a) 格式
    if (RegExMatch(trimmedContent, "i)^hsla?\([^)]+\)$")) {
        return "Color"
    }
    ; 检测十六进制色值（不带#号，6位或8位）
    if (RegExMatch(trimmedContent, "i)^[0-9A-Fa-f]{6}$|^[0-9A-Fa-f]{8}$")) {
        return "Color"
    }
    ; 检测RGB十进制格式：rgb(255, 255, 255) 或 (255, 255, 255)
    if (RegExMatch(trimmedContent, "i)^(rgb\()?\(?\s*\d{1,3}\s*,\s*\d{1,3}\s*,\s*\d{1,3}\s*\)?$")) {
        return "Color"
    }
    
    ; 3. 代码检测 (Code) - 检测常见的代码特征
    if (RegExMatch(trimmedContent, "[\{\}\[\]\(\);]|=>|:=|function|const|import|class|def|return|var|let|public|private|protected|namespace|using|#include|<?php|<?xml|<!DOCTYPE")) {
        return "Code"
    }
    
    ; 4. 默认文本 (Text)
    return "Text"
}

; 剪贴板文本规范化：去 BOM、首尾空白（避免「复制地址」带不可见字符导致无法匹配）
ClipboardFTS5_NormalizeCapturedText(s) {
    s := Trim(String(s), " `t`r`n")
    if (s = "")
        return s
    if (SubStr(s, 1, 1) = Chr(0xFEFF))
        s := SubStr(s, 2)
    if (StrLen(s) >= 3 && SubStr(s, 1, 3) = Chr(0xEF) Chr(0xBB) Chr(0xBF))
        s := SubStr(s, 4)
    return Trim(s, " `t`r`n")
}

_ClipboardFTS5_IsImagePathOrUrl(value) {
    s := ClipboardFTS5_NormalizeCapturedText(value)
    s := Trim(s, "'")
    s := Trim(s, '"')
    if (s = "")
        return false
    ; 允许 URL 带 query 与 fragment（论坛/图床常见）
    if RegExMatch(s, "i)^https?://\S+\.(png|jpg|jpeg|gif|webp|bmp|svg|ico)(\?\S*)?(#\S*)?$")
        return true
    if RegExMatch(s, "i)^www\.\S+\.(png|jpg|jpeg|gif|webp|bmp|svg|ico)(\?\S*)?(#\S*)?$")
        return true
    if RegExMatch(s, "i)^([A-Z]:\\|\\\\).+\.(png|jpg|jpeg|gif|webp|bmp|svg|ico)$")
        return true
    return false
}

; 剪贴板为「单行 https 图链」时（无扩展名或常见图床路径），按图片记录以便列表与预览
_ClipboardFTS5_IsLikelyRemoteImageUrl(value) {
    s := ClipboardFTS5_NormalizeCapturedText(value)
    if (s = "" || InStr(s, "`n") || InStr(s, "`r"))
        return false
    if !RegExMatch(s, "i)^https?://\S+$")
        return false
    if RegExMatch(s, "i)\.(png|jpe?g|gif|webp|bmp|svg|ico)(\?\S*)?($|#)")
        return true
    if RegExMatch(s, "i)/(image|img|photo|pics|pictures?|media|attachments|upload|avatar|cdn|templates|static|assets)/")
        return true
    return false
}

_ClipboardFTS5_ExtractImageRef(content) {
    s := ClipboardFTS5_NormalizeCapturedText(content)
    if (s = "")
        return ""
    if _ClipboardFTS5_IsImagePathOrUrl(s)
        return s
    ; 尖括号包裹：<https://...>
    if RegExMatch(s, "i)^<\s*(https?://[^>\s]+)\s*>$", &m) {
        t := Trim(m[1])
        if _ClipboardFTS5_IsImagePathOrUrl(t)
            return t
    }
    ; BBCode：[img]https://...[/img]
    if RegExMatch(s, "i)^\[img\]\s*(\S+?)\s*\[/img\]\s*$", &m) {
        t := Trim(m[1])
        if _ClipboardFTS5_IsImagePathOrUrl(t)
            return t
    }
    ; Markdown：![任意](url)
    if RegExMatch(s, "i)^!\[[^\]]*\]\(\s*([^)]+?)\s*\)\s*$", &m) {
        t := Trim(m[1])
        t := Trim(t, "'")
        t := Trim(t, Chr(34))
        if _ClipboardFTS5_IsImagePathOrUrl(t)
            return t
    }
    ; 正则里需要同时匹配 ' 与 "，用 Chr 拼接避免引号/转义被 AHK 解析器误判
    ap := Chr(39), dq := Chr(34)
    imgSrcPat := "i)<img\b[^>]*\bsrc\s*=\s*[" . ap . dq . "]([^" . ap . dq . "]+)[" . ap . dq . "]"
    if RegExMatch(s, imgSrcPat, &m) {
        t := Trim(m[1])
        if _ClipboardFTS5_IsImagePathOrUrl(t)
            return t
    }
    return ""
}

_ClipboardFTS5_GetClipboardHtmlImageRef() {
    try {
        clip := WinClip()
        html := clip.GetHtml()
        return _ClipboardFTS5_ExtractImageRef(html)
    } catch {
        return ""
    }
}

; ===================== 计算文本统计 =====================
; 计算字符数和词数
CalculateTextStats(content) {
    stats := Map()
    stats["CharCount"] := 0
    stats["WordCount"] := 0
    
    if (content = "" || StrLen(content) = 0) {
        return stats
    }
    
    trimmedContent := Trim(content, " `t`r`n")
    stats["CharCount"] := StrLen(trimmedContent)
    
    ; 计算词数（去除标点符号后按空格分割）
    words := StrSplit(RegExReplace(trimmedContent, "[^\w\s]+", ""), " ")
    wordCount := 0
    for index, word in words {
        if (word != "" && StrLen(word) > 0) {
            wordCount++
        }
    }
    stats["WordCount"] := wordCount
    
    return stats
}

; ===================== 图片处理：生成缩略图（使用 ImagePut 优化） =====================
; 从位图生成 64x64 的 JPG 缩略图，返回 Base64 编码的字符串
GenerateThumbnail(pBitmap, thumbSize := 64) {
    if (!pBitmap || pBitmap <= 0) {
        return ""
    }
    
    try {
        ; 获取原始图片尺寸（使用 ImagePut 的 Dimensions 函数）
        dims := ImageDimensions(pBitmap)
        width := dims[1]
        height := dims[2]
        
        if (width <= 0 || height <= 0) {
            return ""
        }
        
        ; 计算缩放比例（保持宽高比）
        scale := Min(thumbSize / width, thumbSize / height)
        thumbWidth := Round(width * scale)
        thumbHeight := Round(height * scale)
        
        ; 创建缩略图位图
        pThumbBitmap := Gdip_CreateBitmap(thumbWidth, thumbHeight)
        if (!pThumbBitmap || pThumbBitmap <= 0) {
            return ""
        }
        
        ; 创建图形对象并设置高质量插值
        pGraphics := Gdip_GraphicsFromImage(pThumbBitmap)
        if (!pGraphics || pGraphics <= 0) {
            Gdip_DisposeImage(pThumbBitmap)
            return ""
        }
        
        ; 设置高质量插值模式
        Gdip_SetInterpolationMode(pGraphics, 7)  ; HighQualityBicubic
        Gdip_SetSmoothingMode(pGraphics, 4)      ; AntiAlias
        
        ; 绘制缩略图
        Gdip_DrawImage(pGraphics, pBitmap, 0, 0, thumbWidth, thumbHeight, 0, 0, width, height)
        
        ; 清理图形对象
        Gdip_DeleteGraphics(pGraphics)
        
        ; 统一存为 JPG：与 ClipboardPanelCore._CP_ThumbnailToDataUrl 的 data:image/jpeg 前缀一致
        ; （若用 WebP 字节却标成 jpeg，WebView 中列表缩略图会解码失败）
        TempFile := A_Temp "\clipboard_thumb_" A_TickCount ".jpg"
        try {
            ImagePut("File", pThumbBitmap, TempFile, 85)
        } catch {
            return ""
        }
        
        ; 清理位图
        ImageDestroy(pThumbBitmap)
        
        ; 读取文件并转换为 Base64
        if (FileExist(TempFile)) {
            FileRead(&thumbData, TempFile)
            FileDelete(TempFile)
            
            ; 使用 Base64 编码
            if (thumbData && thumbData.Size > 0) {
                thumbBase64 := Base64Encode(thumbData)
                return thumbBase64
            }
        }
        
        return ""
        
    } catch as err {
        return ""
    }
}

; 将位图按最大宽度（默认 300px）等比缩放后保存为 JPG（供 WebView2 虚拟域名加载列表缩略图）
ClipboardFTS5_SaveJpegThumbMaxWidth(pBitmap, destPath, maxWidth := 300, quality := 82) {
    if (!pBitmap || pBitmap <= 0 || destPath = "")
        return false
    try {
        dims := ImageDimensions(pBitmap)
        width := dims[1]
        height := dims[2]
        if (width <= 0 || height <= 0)
            return false
        if (width <= maxWidth) {
            thumbW := width
            thumbH := height
        } else {
            scale := maxWidth / width
            thumbW := Round(width * scale)
            thumbH := Round(height * scale)
        }
        pThumbBitmap := Gdip_CreateBitmap(thumbW, thumbH)
        if (!pThumbBitmap || pThumbBitmap <= 0)
            return false
        pGraphics := Gdip_GraphicsFromImage(pThumbBitmap)
        if (!pGraphics || pGraphics <= 0) {
            Gdip_DisposeImage(pThumbBitmap)
            return false
        }
        Gdip_SetInterpolationMode(pGraphics, 7)
        Gdip_SetSmoothingMode(pGraphics, 4)
        Gdip_DrawImage(pGraphics, pBitmap, 0, 0, thumbW, thumbH, 0, 0, width, height)
        Gdip_DeleteGraphics(pGraphics)
        try {
            ImagePut("File", pThumbBitmap, destPath, quality)
        } catch as err {
            Gdip_DisposeImage(pThumbBitmap)
            return false
        }
        ImageDestroy(pThumbBitmap)
        return FileExist(destPath)
    } catch as err {
        return false
    }
}

; 生成用于数据库存储的 JPEG Base64（按最大宽度压缩，避免体积过大）
ClipboardFTS5_BitmapToJpegBase64MaxWidth(pBitmap, maxWidth := 1280, quality := 86) {
    if (!pBitmap || pBitmap <= 0)
        return ""
    try {
        w := 0, h := 0
        Gdip_GetImageDimensions(pBitmap, &w, &h)
        if (w < 1 || h < 1)
            return ""

        target := pBitmap
        needDispose := false
        if (w > maxWidth) {
            scale := maxWidth / w
            tw := Max(1, Round(w * scale))
            th := Max(1, Round(h * scale))
            pThumbBitmap := Gdip_CreateBitmap(tw, th)
            if (!pThumbBitmap || pThumbBitmap <= 0)
                return ""
            pGraphics := Gdip_GraphicsFromImage(pThumbBitmap)
            if (!pGraphics || pGraphics <= 0) {
                Gdip_DisposeImage(pThumbBitmap)
                return ""
            }
            Gdip_SetInterpolationMode(pGraphics, 7)
            Gdip_DrawImage(pGraphics, pBitmap, 0, 0, tw, th, 0, 0, w, h)
            Gdip_DeleteGraphics(pGraphics)
            target := pThumbBitmap
            needDispose := true
        }

        b64 := ""
        try b64 := ImagePut("Base64", target, "jpg", quality)
        if (needDispose)
            Gdip_DisposeImage(target)
        if (b64 = "")
            return ""
        if (SubStr(b64, 1, 5) = "data:")
            b64 := RegExReplace(b64, "i)^data:image/[^;]+;base64,")
        return b64
    } catch {
        return ""
    }
}

; ===================== Base64 编码辅助函数 =====================
; 简单的 Base64 编码实现（适用于二进制数据）
Base64Encode(data) {
    ; 使用 CryptBinaryToString Windows API
    ; 这是最简单的方式，但需要计算编码后的长度
    if (!data || data.Size <= 0) {
        return ""
    }
    
    ; 第一次调用获取所需缓冲区大小
    encodedSize := 0
    DllCall("crypt32\CryptBinaryToStringA", 
            "Ptr", data.Ptr, 
            "UInt", data.Size, 
            "UInt", 0x40000001,  ; CRYPT_STRING_BASE64 | CRYPT_STRING_NOCRLF
            "Ptr", 0, 
            "UInt*", &encodedSize)
    
    if (encodedSize <= 0) {
        return ""
    }
    
    ; 分配缓冲区
    encodedBuffer := Buffer(encodedSize, 0)
    
    ; 第二次调用进行实际编码
    if (DllCall("crypt32\CryptBinaryToStringA", 
                "Ptr", data.Ptr, 
                "UInt", data.Size, 
                "UInt", 0x40000001,  ; CRYPT_STRING_BASE64 | CRYPT_STRING_NOCRLF
                "Ptr", encodedBuffer.Ptr, 
                "UInt*", &encodedSize)) {
        ; 减去末尾的 null 终止符
        return StrGet(encodedBuffer.Ptr, encodedSize - 1, "UTF-8")
    }
    
    return ""
}

; ===================== 保存文本到数据库（带单引号转义）=====================
; 将文本内容保存到 FTS5 数据库，自动转义单引号防止 SQL 注入
SaveToClipboardFTS5(content, SourceApp := "Unknown", detectedType := "") {
    global ClipboardFTS5DB
    
    if (!ClipboardFTS5DB || ClipboardFTS5DB = 0) {
        return false
    }
    
    try {
        ; 检查内容是否为空
        if (content = "" || StrLen(content) = 0) {
            return false
        }
        content := ClipboardFTS5_NormalizeCapturedText(content)
        if (content = "") {
            return false
        }
        
        ; 转义单引号（将单引号替换为双单引号）
        escapedContent := StrReplace(content, "'", "''")
        ; 转义反斜杠（SQLite 中反斜杠需要转义）
        escapedContent := StrReplace(escapedContent, "\", "\\")
        
        ; 获取应用信息（路径、图标）
        appInfo := GetApplicationInfo()
        if (SourceApp = "Unknown" && appInfo["SourceApp"] != "Unknown") {
            SourceApp := appInfo["SourceApp"]
        }
        SourcePath := appInfo["SourcePath"]
        IconPath := appInfo["IconPath"]
        
        ; 转义路径中的特殊字符
        escapedSourceApp := StrReplace(SourceApp, "'", "''")
        escapedSourceApp := StrReplace(escapedSourceApp, "\", "\\")
        escapedSourcePath := StrReplace(SourcePath, "'", "''")
        escapedSourcePath := StrReplace(escapedSourcePath, "\", "\\")
        escapedIconPath := StrReplace(IconPath, "'", "''")
        escapedIconPath := StrReplace(escapedIconPath, "\", "\\")
        
        ; 分类内容类型（如果未提供检测类型，则自动分类）
        if (detectedType != "" && detectedType != "Text") {
            dataType := detectedType
        } else {
            dataType := ClassifyContentType(content)
        }

        imageRef := _ClipboardFTS5_ExtractImageRef(content)
        if (imageRef = "")
            imageRef := _ClipboardFTS5_GetClipboardHtmlImageRef()
        if (imageRef = "" && _ClipboardFTS5_IsLikelyRemoteImageUrl(content))
            imageRef := ClipboardFTS5_NormalizeCapturedText(content)
        if (imageRef != "") {
            dataType := "Image"
        }
        escapedImageRef := StrReplace(imageRef, "'", "''")
        escapedImageRef := StrReplace(escapedImageRef, "\", "\\")
        
        ; 计算统计信息
        stats := CalculateTextStats(content)
        charCount := stats["CharCount"]
        
        ; 检查字段是否存在（动态构建 SQL）
        ; 先检查表结构
        SQL := "PRAGMA table_info(ClipMain)"
        tableInfo := ""
        hasLastCopyTime := false
        hasCopyCount := false
        hasSourcePath := false
        hasIconPath := false
        
        if (ClipboardFTS5DB.GetTable(SQL, &tableInfo)) {
            if (tableInfo.HasRows && tableInfo.Rows.Length > 0) {
                Loop tableInfo.Rows.Length {
                    row := tableInfo.Rows[A_Index]
                    columnName := row[2]  ; 列名在第2列
                    if (columnName = "LastCopyTime") {
                        hasLastCopyTime := true
                    }
                    if (columnName = "CopyCount") {
                        hasCopyCount := true
                    }
                    if (columnName = "SourcePath") {
                        hasSourcePath := true
                    }
                    if (columnName = "IconPath") {
                        hasIconPath := true
                    }
                }
            }
        }
        
        ; 如果字段不存在，先添加
        if (!hasSourcePath) {
            ClipboardFTS5DB.Exec("ALTER TABLE ClipMain ADD COLUMN SourcePath TEXT")
        }
        if (!hasIconPath) {
            ClipboardFTS5DB.Exec("ALTER TABLE ClipMain ADD COLUMN IconPath TEXT")
        }
        if (!hasLastCopyTime) {
            ClipboardFTS5DB.Exec("ALTER TABLE ClipMain ADD COLUMN LastCopyTime DATETIME DEFAULT (datetime('now', 'localtime'))")
        }
        if (!hasCopyCount) {
            ClipboardFTS5DB.Exec("ALTER TABLE ClipMain ADD COLUMN CopyCount INTEGER DEFAULT 1")
        }
        
        ; 检查是否已存在相同内容（用于统计复制次数）
        SQL := "SELECT ID"
        if (hasCopyCount) {
            SQL .= ", CopyCount"
        }
        SQL .= " FROM ClipMain WHERE Content = '" . escapedContent . "' ORDER BY ID DESC LIMIT 1"
        
        table := ""
        copyCount := 1
        existingID := 0
        
        if (ClipboardFTS5DB.GetTable(SQL, &table)) {
            if (table.HasRows && table.Rows.Length > 0) {
                existingID := table.Rows[1][1]
                if (hasCopyCount && table.Rows[1].Length > 1) {
                    copyCount := table.Rows[1][2] + 1  ; 增加复制次数
                }
            }
        }
        
        ; 如果已存在，更新记录；否则插入新记录
        if (existingID > 0) {
            ; 更新现有记录：更新最后复制时间和复制次数
            SQL := "UPDATE ClipMain SET "
            if (hasLastCopyTime) {
                SQL .= "LastCopyTime = datetime('now', 'localtime'), "
            }
            if (hasCopyCount) {
                SQL .= "CopyCount = " . copyCount . ", "
            }
            SQL .= "SourceApp = '" . escapedSourceApp . "'"
            if (hasSourcePath) {
                SQL .= ", SourcePath = '" . escapedSourcePath . "'"
            }
            if (hasIconPath) {
                SQL .= ", IconPath = '" . escapedIconPath . "'"
            }
            SQL .= ", DataType = '" . dataType . "'"
            SQL .= ", CharCount = " . charCount
            if (imageRef != "") {
                SQL .= ", ImagePath = '" . escapedImageRef . "'"
            }
            SQL .= " WHERE ID = " . existingID
        } else {
            ; 插入新记录（动态构建字段列表）
            SQL := "INSERT INTO ClipMain (Content, SourceApp"
            if (hasSourcePath) {
                SQL .= ", SourcePath"
            }
            if (hasIconPath) {
                SQL .= ", IconPath"
            }
            SQL .= ", DataType, CharCount, ImagePath, Timestamp"
            if (hasLastCopyTime) {
                SQL .= ", LastCopyTime"
            }
            if (hasCopyCount) {
                SQL .= ", CopyCount"
            }
            SQL .= ") VALUES ('" . escapedContent . "', '" . escapedSourceApp . "'"
            if (hasSourcePath) {
                SQL .= ", '" . escapedSourcePath . "'"
            }
            if (hasIconPath) {
                SQL .= ", '" . escapedIconPath . "'"
            }
            SQL .= ", '" . dataType . "', " . charCount . ", '" . escapedImageRef . "', datetime('now', 'localtime')"
            if (hasLastCopyTime) {
                SQL .= ", datetime('now', 'localtime')"
            }
            if (hasCopyCount) {
                SQL .= ", 1"
            }
            SQL .= ")"
        }
        
        if (!ClipboardFTS5DB.Exec(SQL)) {
            ; 如果 Exec 失败，返回 false 并保留错误信息
            return false
        }
        
        return true
        
    } catch as err {
        ; 记录异常信息到数据库错误消息
        if (ClipboardFTS5DB && ClipboardFTS5DB != 0) {
            ClipboardFTS5DB.ErrorMsg := "异常: " . err.Message
        }
        return false
    }
}

; ===================== 智能采集函数 =====================
; 监听剪贴板并存入数据库（文本和图片）
CaptureClipboardToFTS5() {
    global ClipboardFTS5DB
    
    if (!ClipboardFTS5DB || ClipboardFTS5DB = 0) {
        return false
    }
    
    try {
        ; 检查剪贴板是否有内容（文本 / DIB / CF_BITMAP / CF_HDROP）
        if (!DllCall("IsClipboardFormatAvailable", "UInt", 1)
            && !DllCall("IsClipboardFormatAvailable", "UInt", 8)
            && !DllCall("IsClipboardFormatAvailable", "UInt", 2)
            && !DllCall("IsClipboardFormatAvailable", "UInt", 15)) {
            return false
        }
        
        ; 获取来源应用信息
        SourceApp := "Unknown"
        try {
            SourceApp := WinGetProcessName("A")
        } catch {
            SourceApp := "Unknown"
        }
        
        ; 优先检查图片（CF_DIB=8，CF_BITMAP=2）
        if (DllCall("IsClipboardFormatAvailable", "UInt", 8)
            || DllCall("IsClipboardFormatAvailable", "UInt", 2)) {
            return CaptureClipboardImageToFTS5(SourceApp)
        }

        ; 处理资源管理器复制文件（CF_HDROP=15）
        if (DllCall("IsClipboardFormatAvailable", "UInt", 15)) {
            try {
                wc := WinClip()
                files := wc.GetFiles()
                if (files != "") {
                    ; 先尝试图片文件入库；其余文件按“文本+SourcePath”记录（便于预览/粘贴路径）
                    okImg := ClipboardFTS5_ImportDroppedImageFiles(files, SourceApp)
                    okAny := okImg
                    okAny := ClipboardFTS5_ImportDroppedNonImageFiles(files, SourceApp) || okAny
                    if okAny
                        return true
                }
            } catch {
            }
            ; 继续后续文本兜底（部分应用会同时写入 CF_TEXT 路径）
        }
        
        ; 处理文本
        if (DllCall("IsClipboardFormatAvailable", "UInt", 1)) {
            ; 剪贴板中有文本（CF_TEXT = 1）
            return CaptureClipboardTextToFTS5(SourceApp)
        }
        
        return false
        
    } catch as err {
        return false
    }
}

; 资源管理器 CF_HDROP：把非图片文件也记入 ClipMain（Text + SourcePath + FileSize）
ClipboardFTS5_ImportDroppedNonImageFiles(fileListText, SourceApp) {
    global ClipboardFTS5DB
    if (!ClipboardFTS5DB || ClipboardFTS5DB = 0)
        return false
    if (fileListText = "")
        return false
    anyOk := false
    Loop parse, fileListText, "`n", "`r" {
        fp := Trim(A_LoopField)
        if (fp = "" || !FileExist(fp))
            continue
        SplitPath(fp, &fileName, , &ext)
        ext := StrLower(ext)
        ; 图片文件已由 CaptureImageFileToFTS5 处理
        if RegExMatch(ext, "^(png|jpe?g|gif|webp|bmp|ico|svg)$")
            continue
        fileSize := 0
        try fileSize := FileGetSize(fp)
        content := fp
        charCount := StrLen(content)
        SQL := "INSERT INTO ClipMain (Content, SourceApp, DataType, CharCount, SourcePath, FileSize, Timestamp) " .
               "VALUES (?, ?, ?, ?, ?, ?, datetime('now', 'localtime'))"
        stmt := ""
        try {
            if !ClipboardFTS5DB.Prepare(SQL, &stmt)
                continue
            stmt.Bind(1, content)
            stmt.Bind(2, SourceApp)
            stmt.Bind(3, "Text")
            stmt.Bind(4, charCount)
            stmt.Bind(5, fp)
            stmt.Bind(6, fileSize)
            if (stmt.Step() != 101) {
                ; ignore
            } else {
                anyOk := true
            }
        } catch {
        }
        try stmt.Free()
    }
    return anyOk
}

; ===================== 采集文本到数据库 =====================
CaptureClipboardTextToFTS5(SourceApp) {
    global ClipboardFTS5DB

    ; 调试日志函数
    DebugLog(message) {
        FileAppend(A_Now ": " . message . "`n", "debug_clipboard.log")
    }

    try {
        DebugLog("CaptureClipboardTextToFTS5 开始执行")

        ; 检查数据库连接
        if (!ClipboardFTS5DB || ClipboardFTS5DB = 0) {
            DebugLog("数据库连接无效")
            return false
        }
        DebugLog("数据库连接正常")

        ; 获取剪贴板文本
        content := ClipboardFTS5_NormalizeCapturedText(A_Clipboard)
        DebugLog("剪贴板内容长度: " . StrLen(content))
        if (content = "" || StrLen(content) = 0) {
            DebugLog("剪贴板内容为空")
            return false
        }

        ; 分类内容类型（纯 https 图链按 Image 存，并写入 ImagePath 供 WebView 预览）
        dataType := ClassifyContentType(content)
        imagePathForRow := ""
        if (_ClipboardFTS5_IsLikelyRemoteImageUrl(content)) {
            dataType := "Image"
            imagePathForRow := Trim(content, " `t`r`n")
        }
        DebugLog("内容类型: " . dataType)

        ; 计算统计信息
        stats := CalculateTextStats(content)
        charCount := stats["CharCount"]
        DebugLog("字符数: " . charCount)

        ; 插入到主表
        SQL := imagePathForRow != ""
            ? "INSERT INTO ClipMain (Content, SourceApp, DataType, CharCount, ImagePath, Timestamp) " .
              "VALUES (?, ?, ?, ?, ?, datetime('now', 'localtime'))"
            : "INSERT INTO ClipMain (Content, SourceApp, DataType, CharCount, Timestamp) " .
              "VALUES (?, ?, ?, ?, datetime('now', 'localtime'))"
        DebugLog("准备SQL语句")

        stmt := ""
        if (!ClipboardFTS5DB.Prepare(SQL, &stmt)) {
            DebugLog("准备SQL语句失败: " . ClipboardFTS5DB.ErrorMsg)
            return false
        }
        DebugLog("SQL语句准备成功")

        stmt.Bind(1, content)
        stmt.Bind(2, SourceApp)
        stmt.Bind(3, dataType)
        stmt.Bind(4, charCount)
        if (imagePathForRow != "")
            stmt.Bind(5, imagePathForRow)
        DebugLog("参数绑定完成")

        if (!stmt.Step()) {
            DebugLog("执行SQL语句失败: " . ClipboardFTS5DB.ErrorMsg)
            stmt.Free()
            return false
        }
        DebugLog("SQL语句执行成功")

        rowid := ClipboardFTS5DB.LastInsertRowID()
        stmt.Free()
        DebugLog("插入成功，ID: " . rowid)

        return true

    } catch as err {
        DebugLog("异常: " . err.Message)
        return false
    }
}

; 从剪贴板尽量取位图：Gdip → WinClip DIB → ImagePut（安全优先，避免 VTABLE 崩溃）
_ClipboardFTS5_ObtainBitmapFromClipboard(&pBitmap, &disposeWithGdip) {
    pBitmap := 0
    disposeWithGdip := false

    ; 1. 最安全：Gdip_CreateBitmapFromClipboard（SaveClipboardImage 已验证可靠，绝不崩溃）
    try {
        pBitmap := Gdip_CreateBitmapFromClipboard()
        if (pBitmap && pBitmap > 0) {
            disposeWithGdip := true
            return true
        }
    } catch {
        pBitmap := 0
    }

    ; 2. WinClip DIB → Gdip（Chrome/Edge 复制图片兼容）
    try {
        wc := WinClip()
        hbm := wc.iGetBitmap()
        if (hbm) {
            pBitmap := Gdip_CreateBitmapFromHBITMAP(hbm)
            if (pBitmap && pBitmap > 0)
                disposeWithGdip := true
            DllCall("DeleteObject", "ptr", hbm)
            if (pBitmap && pBitmap > 0)
                return true
        }
    } catch {
        pBitmap := 0
    }

    ; 3. ImagePutBitmap：仅 A_Clipboard 非空时尝试（空字符串会导致 VTABLE 崩溃）
    try {
        clipText := A_Clipboard
        if (clipText != "" && StrLen(clipText) > 0) {
            pBitmap := ImagePutBitmap(clipText)
            disposeWithGdip := false
            if (pBitmap && pBitmap != "" && pBitmap > 0)
                return true
        }
    } catch {
        pBitmap := 0
    }

    return (pBitmap && pBitmap != "" && pBitmap > 0)
}

_ClipboardFTS5_DisposeClipboardBitmap(pBitmap, disposeWithGdip) {
    if !pBitmap || pBitmap = "" || pBitmap <= 0
        return
    if disposeWithGdip
        Gdip_DisposeImage(pBitmap)
    else
        ImageDestroy(pBitmap)
}

; 资源管理器 CF_HDROP 多行路径：逐条尝试图片入库
ClipboardFTS5_ImportDroppedImageFiles(fileListText, SourceApp) {
    if (fileListText = "")
        return false
    anyOk := false
    Loop parse, fileListText, "`n", "`r" {
        fp := Trim(A_LoopField)
        if (fp = "" || !FileExist(fp))
            continue
        if CaptureImageFileToFTS5(fp, SourceApp)
            anyOk := true
    }
    return anyOk
}

; 单行本地图片绝对路径（复制文件时 A_Clipboard 常为单路径）
ClipboardFTS5_SingleLocalImagePathFromText(content) {
    s := ClipboardFTS5_NormalizeCapturedText(content)
    if (s = "" || InStr(s, "`n") || InStr(s, "`r"))
        return ""
    if !RegExMatch(s, "i)^([a-z]:\\|\\\\).+\.(png|jpe?g|gif|webp|bmp|svg|ico)$")
        return ""
    if !FileExist(s)
        return ""
    return s
}

; ===================== 采集图片到数据库（使用 ImagePut 优化） =====================
; SourceUrl: 网页复制图片时的原始 URL（可选）
CaptureClipboardImageToFTS5(SourceApp, SourceUrl := "") {
    global ClipboardFTS5DB
    
    try {
        pBitmap := 0
        disposeGdip := false
        if !_ClipboardFTS5_ObtainBitmapFromClipboard(&pBitmap, &disposeGdip)
            return false
        
        ; 获取图片尺寸：GDI+ 位图用 Gdip 函数（安全），ImagePut 位图用 ImagePut 函数
        imgWidth := 0, imgHeight := 0
        if (disposeGdip) {
            Gdip_GetImageDimensions(pBitmap, &imgWidth, &imgHeight)
        } else {
            dims := ImageDimensions(pBitmap)
            imgWidth := dims[1]
            imgHeight := dims[2]
        }
        
        ; 不再落地到 Cache\Images / Cache\Thumbs，直接存数据库 Base64
        imagePath := ""
        thumbPath := ""
        imageFormat := "jpg"
        thumbnailBase64 := ClipboardFTS5_BitmapToJpegBase64MaxWidth(pBitmap, 1280, 86)
        if (thumbnailBase64 = "")
            thumbnailBase64 := GenerateThumbnail(pBitmap)
        
        ; 清理位图资源
        _ClipboardFTS5_DisposeClipboardBitmap(pBitmap, disposeGdip)
        
        ; 无落地文件时 FileSize 记 0（UI 可正常回退显示）
        fileSize := 0
        
        escContent := "Clipboard Image"
        escSourceApp := StrReplace(StrReplace(SourceApp, "'", "''"), "\", "\\")
        escImagePath := StrReplace(StrReplace(imagePath, "'", "''"), "\", "\\")
        escThumbPath := StrReplace(StrReplace(thumbPath, "'", "''"), "\", "\\")
        escThumbData := StrReplace(thumbnailBase64 != "" ? thumbnailBase64 : "", "'", "''")
        escSourceUrl := StrReplace(StrReplace(SourceUrl, "'", "''"), "\", "\\")
        escImageFormat := StrReplace(imageFormat, "'", "''")

        SQL := "INSERT INTO ClipMain (Content, SourceApp, DataType, CharCount, ImagePath, ThumbPath, ThumbnailData, " .
               "SourceUrl, ImageFormat, ImageWidth, ImageHeight, FileSize, Timestamp) VALUES (" .
               "'" . escContent . "', '" . escSourceApp . "', 'Image', 0, '" . escImagePath . "', '" . escThumbPath . "', '" . escThumbData . "', " .
               "'" . escSourceUrl . "', '" . escImageFormat . "', " . imgWidth . ", " . imgHeight . ", " . fileSize . ", datetime('now', 'localtime'))"

        if (!ClipboardFTS5DB.Exec(SQL))
            return false
        return true
        
    } catch as err {
        if (ClipboardFTS5DB && ClipboardFTS5DB != 0)
            ClipboardFTS5DB.ErrorMsg := "CaptureClipboardImageToFTS5: " . err.Message
        return false
    }
}

; ===================== 采集本地图片文件到数据库 =====================
; 用于资源管理器复制文件时，将图片文件直接记录（不复制位图）
CaptureImageFileToFTS5(filePath, SourceApp) {
    global ClipboardFTS5DB
    
    if (!ClipboardFTS5DB || ClipboardFTS5DB = 0)
        return false
    if (!FileExist(filePath))
        return false
    
    ; 检查是否为图片扩展名
    SplitPath(filePath, , , &ext)
    ext := StrLower(ext)
    if !RegExMatch(ext, "^(png|jpe?g|gif|webp|bmp|ico|svg)$")
        return false
    
    try {
        ScriptDir := (IsSet(MainScriptDir) ? MainScriptDir : A_ScriptDir)
        ThumbsDir := ScriptDir "\Cache\Thumbs"
        if (!DirExist(ThumbsDir))
            DirCreate(ThumbsDir)
        
        ; 获取文件大小
        fileSize := 0
        try fileSize := FileGetSize(filePath)
        
        ; 获取图片尺寸（Gdip 对部分 JPG 解码失败时用 ImagePut 兜底）
        imgWidth := 0
        imgHeight := 0
        pBitmap := 0
        fromImagePut := false
        try {
            pBitmap := Gdip_CreateBitmapFromFile(filePath)
            if (pBitmap && pBitmap > 0)
                Gdip_GetImageDimensions(pBitmap, &imgWidth, &imgHeight)
        } catch as err {
            pBitmap := 0
        }
        if (!pBitmap || pBitmap <= 0) {
            try {
                pBitmap := ImagePutBitmap(filePath)
                if (pBitmap && pBitmap != "") {
                    fromImagePut := true
                    dims := ImageDimensions(pBitmap)
                    imgWidth := dims[1]
                    imgHeight := dims[2]
                }
            } catch as err2 {
                pBitmap := 0
            }
        }
        
        thumbPath := ""
        thumbnailBase64 := ""
        if (pBitmap && pBitmap > 0) {
            timestamp := FormatTime(, "yyyyMMddHHmmss")
            thumbFileName := "THF_" . timestamp . "_" . A_TickCount . ".jpg"
            thumbPath := ThumbsDir "\" . thumbFileName
            if (!ClipboardFTS5_SaveJpegThumbMaxWidth(pBitmap, thumbPath, 300, 82))
                thumbPath := ""
            try thumbnailBase64 := GenerateThumbnail(pBitmap)
            if fromImagePut
                ImageDestroy(pBitmap)
            else
                Gdip_DisposeImage(pBitmap)
        }
        
        ; 图片格式
        imageFormat := ext = "jpeg" ? "jpg" : ext
        
        escFilePath := StrReplace(StrReplace(filePath, "'", "''"), "\", "\\")
        escSourceApp := StrReplace(StrReplace(SourceApp, "'", "''"), "\", "\\")
        escThumbPath := StrReplace(StrReplace(thumbPath, "'", "''"), "\", "\\")
        escThumbData := StrReplace(thumbnailBase64, "'", "''")
        escImageFormat := StrReplace(imageFormat, "'", "''")

        SQL := "INSERT INTO ClipMain (Content, SourceApp, DataType, CharCount, ImagePath, ThumbPath, ThumbnailData, " .
               "ImageFormat, ImageWidth, ImageHeight, FileSize, Timestamp) VALUES (" .
               "'" . escFilePath . "', '" . escSourceApp . "', 'Image', 0, '" . escFilePath . "', '" . escThumbPath . "', '" . escThumbData . "', " .
               "'" . escImageFormat . "', " . imgWidth . ", " . imgHeight . ", " . fileSize . ", datetime('now', 'localtime'))"

        if (!ClipboardFTS5DB.Exec(SQL))
            return false
        return true
    } catch as err {
        if (ClipboardFTS5DB && ClipboardFTS5DB != 0)
            ClipboardFTS5DB.ErrorMsg := "CaptureImageFileToFTS5: " . err.Message
        return false
    }
}

; ===================== 清道夫函数 =====================
; 清理数据库：只保留最近 30 天的数据，但标记为"收藏"的数据永不删除
CleanupClipboardFTS5(keepDays := 30) {
    global ClipboardFTS5DB
    
    if (!ClipboardFTS5DB || ClipboardFTS5DB = 0) {
        return false
    }
    
    try {
        ; 计算30天前的时间
        cutoffDate := FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss")
        ; 使用 SQLite 的日期计算函数
        SQL := "DELETE FROM ClipMain " .
               "WHERE Timestamp < datetime('now', '-' || ? || ' days') " .
               "AND IsFavorite = 0"
        
        stmt := ""
        if (!ClipboardFTS5DB.Prepare(SQL, &stmt)) {
            return false
        }
        
        stmt.Bind(1, keepDays)
        
        if (!stmt.Step()) {
            stmt.Free()
            return false
        }
        
        deletedCount := ClipboardFTS5DB.Changes
        stmt.Free()
        
        ; FTS5 虚拟表通过触发器自动同步删除
        
        return deletedCount
        
    } catch as err {
        return false
    }
}

; ===================== 标记为收藏 =====================
; 将指定 ID 的记录标记为收藏（永不删除）
MarkAsFavorite(id) {
    global ClipboardFTS5DB
    
    if (!ClipboardFTS5DB || ClipboardFTS5DB = 0) {
        return false
    }
    
    try {
        SQL := "UPDATE ClipMain SET IsFavorite = 1 WHERE ID = ?"
        stmt := ""
        if (!ClipboardFTS5DB.Prepare(SQL, &stmt)) {
            return false
        }
        
        stmt.Bind(1, id)
        
        if (!stmt.Step()) {
            stmt.Free()
            return false
        }
        
        stmt.Free()
        return true
        
    } catch as err {
        return false
    }
}

; ===================== 取消收藏 =====================
UnmarkAsFavorite(id) {
    global ClipboardFTS5DB
    
    if (!ClipboardFTS5DB || ClipboardFTS5DB = 0) {
        return false
    }
    
    try {
        SQL := "UPDATE ClipMain SET IsFavorite = 0 WHERE ID = ?"
        stmt := ""
        if (!ClipboardFTS5DB.Prepare(SQL, &stmt)) {
            return false
        }
        
        stmt.Bind(1, id)
        
        if (!stmt.Step()) {
            stmt.Free()
            return false
        }
        
        stmt.Free()
        return true
        
    } catch as err {
        return false
    }
}

; ===================== FTS5 全文搜索 =====================
; 使用 FTS5 进行全文搜索
SearchClipboardFTS5(keyword, limit := 100) {
    global ClipboardFTS5DB
    
    if (!ClipboardFTS5DB || ClipboardFTS5DB = 0) {
        return []
    }
    
    try {
        ; 转义关键词中的特殊字符
        escapedKeyword := RegExReplace(keyword, "[^\w\s]", "")
        
        ; 使用 LIKE 查询替代 FTS5
        SQL := "SELECT ID, Content, SourceApp, DataType, CharCount, Timestamp, ImagePath, IsFavorite " .
               "FROM ClipMain " .
               "WHERE Content LIKE ? " .
               "ORDER BY Timestamp DESC " .
               "LIMIT ?"

        stmt := ""
        if (!ClipboardFTS5DB.Prepare(SQL, &stmt)) {
            return []
        }

        ; 使用 LIKE 查询语法：添加通配符
        searchQuery := "%" . escapedKeyword . "%"
        stmt.Bind(1, searchQuery)
        stmt.Bind(2, limit)
        
        results := []
        while (stmt.Step()) {
            row := Map()
            row["ID"] := stmt.Column(0)
            row["Content"] := stmt.Column(1)
            row["SourceApp"] := stmt.Column(2)
            row["DataType"] := stmt.Column(3)
            row["CharCount"] := stmt.Column(4)
            row["Timestamp"] := stmt.Column(5)
            row["ImagePath"] := stmt.Column(6)
            row["IsFavorite"] := stmt.Column(7)
            results.Push(row)
        }
        
        stmt.Free()
        return results
        
    } catch as err {
        return []
    }
}
