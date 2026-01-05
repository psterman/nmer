
#Requires AutoHotkey v2.0
#Include modules\ClipboardHistoryPanel.ahk
#Include modules\ClipboardDebugPanel.ahk

; 全局变量
global LastClipboardContent := ""  ; 记录上次剪贴板内容，避免重复记录
global ClipboardChangeDebounceTimer := 0  ; 剪贴板变化防抖定时器

; 初始化
InitClipboardFTS5DB()
InitClipboardHistoryPanel()
InitClipboardDebugPanel()

; 注册剪贴板监听器
OnClipboardChange(OnClipboardChangeHandler, 1)
RecordClipboardEvent("初始化", "剪贴板监听器已注册")

; 显示面板
ShowClipboardHistoryPanel()

; 不再自动显示调试面板（用户需要时手动打开）
; ShowClipboardDebugPanel()

; 保持脚本运行
Persistent

; ===================== 剪贴板变化监听器 =====================
OnClipboardChangeHandler(Type) {
    global LastClipboardContent, ClipboardChangeDebounceTimer
    
    ; 记录事件
    RecordClipboardEvent("监听触发", "剪贴板变化检测到，类型: " . Type)
    
    ; 防抖处理：清除之前的定时器
    if (ClipboardChangeDebounceTimer != 0) {
        try {
            SetTimer(ClipboardChangeDebounceTimer, 0)  ; 清除定时器
            RecordClipboardEvent("防抖", "清除之前的定时器")
        } catch {
        }
    }
    
    ; 设置防抖定时器（300毫秒延迟，避免频繁触发）
    ClipboardChangeDebounceTimer := (*) => ProcessClipboardChange(Type)
    SetTimer(ClipboardChangeDebounceTimer, -300)  ; 300毫秒后执行
    RecordClipboardEvent("防抖", "设置300ms延迟定时器")
}

; ===================== 处理剪贴板变化（防抖后的实际处理函数）=====================
ProcessClipboardChange(Type) {
    global LastClipboardContent, ClipboardFTS5DB, HistoryIsVisible
    
    RecordClipboardEvent("处理开始", "开始处理剪贴板变化，类型: " . Type)
    
    if (Type = 0 || A_PtrSize = "") {
        RecordClipboardEvent("处理跳过", "类型无效，跳过处理")
        return
    }
    
    try {
        ; 获取来源应用信息
        SourceApp := "Unknown"
        try {
            SourceApp := WinGetProcessName("A")
            RecordClipboardEvent("来源检测", "来源应用: " . SourceApp)
        } catch {
            SourceApp := "Unknown"
            RecordClipboardEvent("来源检测", "无法获取来源应用，使用默认值")
        }
        
        ; 处理文本类型
        if (Type = 1) {
            RecordClipboardEvent("类型判断", "检测到文本类型")
            content := A_Clipboard
            trimmedContent := Trim(content, " `t`r`n")
            
            ; ========== 1. 基础过滤系统 (所有用户) ==========
            ; 检查内容是否为空
            if (content = "" || StrLen(content) = 0) {
                RecordClipboardEvent("基础过滤", "内容为空，跳过保存")
                return
            }
            
            ; 过滤过短字符（少于3个字符）
            if (StrLen(trimmedContent) < 3) {
                RecordClipboardEvent("基础过滤", "内容过短（<3字符），跳过保存")
                return
            }
            
            ; 过滤纯空白内容
            if (RegExMatch(trimmedContent, "^[\s\r\n]*$")) {
                RecordClipboardEvent("基础过滤", "纯空白内容，跳过保存")
                return
            }
            
            ; ========== 2. 专业过滤系统 (针对 Cursor/开发者) ==========
            ; 过滤 node_modules, .git 等开发干扰路径
            if (RegExMatch(content, "i)(node_modules|\.git|__pycache__|\.vs|obj|bin|dist|build|\.next|\.nuxt)")) {
                RecordClipboardEvent("专业过滤", "开发路径，跳过保存")
                return
            }
            
            ; 过滤 API Keys (如 OpenAI)
            if (RegExMatch(content, "sk-[a-zA-Z0-9]{32,}")) {
                RecordClipboardEvent("专业过滤", "检测到API Key，跳过保存")
                return
            }
            
            ; 过滤 Base64 图片字符串
            if (InStr(content, "data:image/") && InStr(content, "base64")) {
                RecordClipboardEvent("专业过滤", "Base64图片字符串，跳过保存")
                return
            }
            
            RecordClipboardEvent("内容检查", "内容长度: " . StrLen(content) . " 字符")
            RecordClipboardEvent("内容预览", "内容: " . SubStr(content, 1, 100))
            
            ; ========== 3. 类型识别打标 ==========
            detectedType := "Text"
            
            ; 识别十六进制色值（#RGB 或 #RRGGBB）
            if (RegExMatch(trimmedContent, "i)^#([A-Fa-f0-9]{6}|[A-Fa-f0-9]{3})$")) {
                detectedType := "Color"
                RecordClipboardEvent("类型识别", "识别为颜色: " . trimmedContent)
            }
            ; 识别链接
            else if (RegExMatch(trimmedContent, "i)^https?://\S+")) {
                detectedType := "Link"
                RecordClipboardEvent("类型识别", "识别为链接: " . trimmedContent)
            }
            ; 识别代码特征（包含代码常见符号）
            else if (RegExMatch(content, "[\{\}\[\]\(\);]|=>|:=|function|const|import|class|def|return|var|let|public|private|protected|namespace|using|#include|<?php|<?xml|<!DOCTYPE")) {
                detectedType := "Code"
                RecordClipboardEvent("类型识别", "识别为代码")
            }
            else {
                RecordClipboardEvent("类型识别", "识别为文本")
            }
            
            ; 去重检查：如果内容与上次相同，不重复保存
            if (content = LastClipboardContent) {
                RecordClipboardEvent("去重检查", "内容与上次相同，跳过保存")
                return
            }
            
            ; 更新上次内容
            LastClipboardContent := content
            RecordClipboardEvent("去重检查", "内容为新内容，继续保存")
            
            ; 保存到数据库（使用检测到的类型）
            if (ClipboardFTS5DB && ClipboardFTS5DB != 0) {
                RecordClipboardEvent("数据库检查", "数据库已连接，开始保存，类型: " . detectedType)
                ; 注意：SaveToClipboardFTS5 内部会调用 ClassifyContentType，但我们已经识别了类型
                ; 为了确保使用我们识别的类型，需要修改 SaveToClipboardFTS5 或直接调用数据库插入
                result := SaveToClipboardFTS5(content, SourceApp, detectedType)
                
                ; 如果保存成功
                if (result) {
                    RecordSaveResult(true, "内容已保存到数据库，来源: " . SourceApp)
                    
                    ; 如果面板已打开，刷新数据
                    if (HistoryIsVisible) {
                        RecordClipboardEvent("面板刷新", "历史面板已打开，准备刷新")
                        SetTimer(() => RefreshHistoryData(), -500)
                    } else {
                        RecordClipboardEvent("面板刷新", "历史面板未打开，跳过刷新")
                    }
                } else {
                    errorMsg := "未知错误"
                    if (ClipboardFTS5DB && ClipboardFTS5DB != 0) {
                        errorMsg := ClipboardFTS5DB.ErrorMsg
                    }
                    RecordSaveResult(false, "保存失败: " . errorMsg)
                }
            } else {
                RecordClipboardEvent("数据库检查", "数据库未连接")
                RecordSaveResult(false, "数据库未初始化")
                TrayTip("错误", "数据库未初始化", "Iconx 2")
            }
        }
        ; 处理图片类型
        else if (Type = 2) {
            RecordClipboardEvent("类型判断", "检测到图片类型")
            if (ClipboardFTS5DB && ClipboardFTS5DB != 0) {
                RecordClipboardEvent("数据库检查", "数据库已连接，开始保存图片")
                result := CaptureClipboardImageToFTS5(SourceApp)
                
                if (result) {
                    RecordSaveResult(true, "图片已保存到数据库")
                } else {
                    errorMsg := "未知错误"
                    if (ClipboardFTS5DB && ClipboardFTS5DB != 0) {
                        errorMsg := ClipboardFTS5DB.ErrorMsg
                    }
                    RecordSaveResult(false, "图片保存失败: " . errorMsg)
                }
                
                ; 如果面板已打开，刷新数据
                if (result && HistoryIsVisible) {
                    RecordClipboardEvent("面板刷新", "历史面板已打开，准备刷新")
                    SetTimer(() => RefreshHistoryData(), -500)
                }
            } else {
                RecordSaveResult(false, "数据库未初始化")
            }
        } else {
            RecordClipboardEvent("类型判断", "未知类型: " . Type)
        }
    } catch as err {
        RecordClipboardEvent("异常", "处理过程中发生异常: " . err.Message)
        RecordSaveResult(false, "异常: " . err.Message)
    }
    
    RecordClipboardEvent("处理完成", "剪贴板变化处理完成")
}