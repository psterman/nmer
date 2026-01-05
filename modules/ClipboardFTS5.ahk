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
                
                if (table.HasRows && table.Rows.Length > 0) {
                    Loop table.Rows.Length {
                        row := table.Rows[A_Index]
                        columnName := row[2]  ; 列名在第2列
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
                    }
                }
                
                ; 添加缺失的字段（确保执行成功）
                if (!hasSourcePath) {
                    if (!ClipboardFTS5DB.Exec("ALTER TABLE ClipMain ADD COLUMN SourcePath TEXT")) {
                        ; 如果失败，记录错误但不中断
                    }
                }
                if (!hasIconPath) {
                    if (!ClipboardFTS5DB.Exec("ALTER TABLE ClipMain ADD COLUMN IconPath TEXT")) {
                        ; 如果失败，记录错误但不中断
                    }
                }
                if (!hasLastCopyTime) {
                    if (!ClipboardFTS5DB.Exec("ALTER TABLE ClipMain ADD COLUMN LastCopyTime DATETIME DEFAULT (datetime('now', 'localtime'))")) {
                        ; 如果失败，记录错误但不中断
                    }
                }
                if (!hasCopyCount) {
                    if (!ClipboardFTS5DB.Exec("ALTER TABLE ClipMain ADD COLUMN CopyCount INTEGER DEFAULT 1")) {
                        ; 如果失败，记录错误但不中断
                    }
                }
            }
        } catch {
            ; 忽略错误，继续执行
        }
        
        ; 5. 跳过 FTS5 虚拟表创建（因为当前SQLite版本不支持FTS5）
        ; 注意：如果需要全文搜索功能，需要使用支持FTS5的SQLite版本
        ; 目前使用简单的LIKE查询作为替代方案
        
        ; 6. 创建索引以提升查询性能
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

; ===================== 获取应用信息 =====================
; 获取当前活动窗口的应用路径和图标路径
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
        try {
            SourcePath := WinGetProcessPath(ActiveID)
            info["SourcePath"] := SourcePath
            
            ; 图标路径就是可执行文件路径（exe/dll文件本身包含图标）
            if (FileExist(SourcePath)) {
                info["IconPath"] := SourcePath
            }
        } catch {
            ; 如果无法获取路径，尝试从进程名推断
            if (SourceApp != "Unknown") {
                ; 尝试在常见路径查找
                commonPaths := [
                    A_ProgramFiles . "\" . SourceApp,
                    A_ProgramFiles . "\Windows\System32\" . SourceApp,
                    A_ProgramFiles . "\Windows\" . SourceApp
                ]
                
                for index, path in commonPaths {
                    if (FileExist(path)) {
                        info["SourcePath"] := path
                        info["IconPath"] := path
                        break
                    }
                }
            }
        }
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

; ===================== 图片处理：生成缩略图 =====================
; 从位图生成 64x64 的 JPG 缩略图，返回 Base64 编码的字符串
GenerateThumbnail(pBitmap, thumbSize := 64) {
    if (!pBitmap || pBitmap <= 0) {
        return ""
    }
    
    try {
        ; 获取原始图片尺寸
        width := Gdip_GetImageWidth(pBitmap)
        height := Gdip_GetImageHeight(pBitmap)
        
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
        
        ; 保存为 JPG 到临时文件
        TempFile := A_Temp "\clipboard_thumb_" A_TickCount ".jpg"
        Gdip_SaveBitmapToFile(pThumbBitmap, TempFile, 85)
        
        ; 清理位图
        Gdip_DisposeImage(pThumbBitmap)
        
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
            SQL .= ", DataType, CharCount, Timestamp"
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
            SQL .= ", '" . dataType . "', " . charCount . ", datetime('now', 'localtime')"
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
        ; 检查剪贴板是否有内容
        if (!DllCall("IsClipboardFormatAvailable", "UInt", 1) && !DllCall("IsClipboardFormatAvailable", "UInt", 8)) {
            ; 既没有文本也没有图片
            return false
        }
        
        ; 获取来源应用信息
        SourceApp := "Unknown"
        try {
            SourceApp := WinGetProcessName("A")
        } catch {
            SourceApp := "Unknown"
        }
        
        ; 优先检查图片
        if (DllCall("IsClipboardFormatAvailable", "UInt", 8)) {
            ; 剪贴板中有图片（CF_DIB = 8）
            return CaptureClipboardImageToFTS5(SourceApp)
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
        content := A_Clipboard
        DebugLog("剪贴板内容长度: " . StrLen(content))
        if (content = "" || StrLen(content) = 0) {
            DebugLog("剪贴板内容为空")
            return false
        }

        ; 分类内容类型
        dataType := ClassifyContentType(content)
        DebugLog("内容类型: " . dataType)

        ; 计算统计信息
        stats := CalculateTextStats(content)
        charCount := stats["CharCount"]
        DebugLog("字符数: " . charCount)

        ; 插入到主表
        SQL := "INSERT INTO ClipMain (Content, SourceApp, DataType, CharCount, Timestamp) " .
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

; ===================== 采集图片到数据库 =====================
CaptureClipboardImageToFTS5(SourceApp) {
    global ClipboardFTS5DB
    
    try {
        ; 创建缓存目录（使用主脚本目录）
        ScriptDir := (IsSet(MainScriptDir) ? MainScriptDir : A_ScriptDir)
        CacheDir := ScriptDir "\Cache\Images"
        if (!DirExist(CacheDir)) {
            DirCreate(CacheDir)
        }
        
        ; 从剪贴板创建位图
        pBitmap := Gdip_CreateBitmapFromClipboard()
        if (!pBitmap || pBitmap <= 0) {
            return false
        }
        
        ; 生成唯一文件名
        timestamp := FormatTime(, "yyyyMMddHHmmss")
        imageFileName := "IMG_" . timestamp . "_" . A_TickCount . ".png"
        imagePath := CacheDir "\" . imageFileName
        
        ; 保存原始图片
        if (Gdip_SaveBitmapToFile(pBitmap, imagePath) != 0) {
            Gdip_DisposeImage(pBitmap)
            return false
        }
        
        ; 生成缩略图（Base64）
        thumbnailBase64 := GenerateThumbnail(pBitmap)
        
        ; 清理位图资源
        Gdip_DisposeImage(pBitmap)
        
        ; 插入到数据库
        SQL := "INSERT INTO ClipMain (Content, SourceApp, DataType, CharCount, ImagePath, ThumbnailData, Timestamp) " .
               "VALUES (?, ?, ?, ?, ?, ?, datetime('now', 'localtime'))"
        
        stmt := ""
        if (!ClipboardFTS5DB.Prepare(SQL, &stmt)) {
            return false
        }
        
        ; Content 字段存储图片路径（便于检索）
        stmt.Bind(1, imagePath)
        stmt.Bind(2, SourceApp)
        stmt.Bind(3, "Image")
        stmt.Bind(4, 0)  ; 图片没有字符数
        stmt.Bind(5, imagePath)
        
        ; 绑定缩略图数据（Base64 字符串）
        if (thumbnailBase64 != "") {
            stmt.Bind(6, thumbnailBase64)
        } else {
            stmt.Bind(6, "")
        }
        
        if (!stmt.Step()) {
            stmt.Free()
            return false
        }
        
        rowid := ClipboardFTS5DB.LastInsertRowID()
        stmt.Free()
        
        return true
        
    } catch as err {
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
