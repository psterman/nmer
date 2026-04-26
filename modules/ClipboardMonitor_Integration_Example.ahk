; ======================================================================================================================
; 剪贴板监控器集成示例
; 此文件展示如何将 ClipboardMonitor.ahk 集成到主脚本中
; ======================================================================================================================

#Requires AutoHotkey v2.0

; 包含监控器模块
#Include ClipboardMonitor.ahk

; ===================== 示例：修改 ProcessClipboardChange 函数 =====================
; 在您的主脚本中，找到 ProcessClipboardChange 函数，将数据库操作部分修改为：

ProcessClipboardChange_Example() {
    global ClipboardFTS5DB, PendingClipboardType, PendingClipboardContent
    
    Type := PendingClipboardType
    if (Type = 0 || A_PtrSize = "") {
        return
    }
    
    try {
        ; 获取来源应用
        SourceApp := "Unknown"
        try {
            SourceApp := WinGetProcessName("A")
        } catch {
            SourceApp := "Unknown"
        }
        
        content := ""
        if (Type = 1) {
            content := A_Clipboard
        }
        
        ; ========== 修改这里：使用带监控的入库函数 ==========
        if (ClipboardFTS5DB && ClipboardFTS5DB != 0) {
            if (Type = 1) {
                ; 原来：SaveToClipboardFTS5(content, SourceApp)
                ; 改为：
                SaveToClipboardFTS5WithMonitor(content, SourceApp)
            } else if (Type = 2) {
                ; 原来：CaptureClipboardImageToFTS5(SourceApp)
                ; 改为：
                CaptureClipboardImageToFTS5WithMonitor(SourceApp)
            }
        }
        ; ====================================================
        
    } catch as err {
        ; 错误会被监控器自动记录
    }
}

; ===================== 示例：在 OnClipboardChangeHandler 中记录防抖过滤 =====================
; 在您的主脚本中，找到 OnClipboardChangeHandler 函数，添加防抖过滤记录：

OnClipboardChangeHandler_Example(Type) {
    global ClipboardChangeDebounceTimer, CapsLockCopyInProgress
    global MonitorIsVisible
    
    ; 如果 CapsLock+C 正在进行中，不记录
    if (CapsLockCopyInProgress) {
        return
    }
    
    if (Type = 0 || A_PtrSize = "") {
        return
    }
    
    ; 防抖处理：清除之前的定时器
    if (ClipboardChangeDebounceTimer != 0) {
        try {
            SetTimer(ClipboardChangeDebounceTimer, 0)  ; 清除定时器
            
            ; ========== 添加这里：记录防抖过滤 ==========
            if (MonitorIsVisible) {
                RecordDebounceFiltered()
            }
            ; ===========================================
            
        } catch {
        }
    }
    
    ; ... 其余代码保持不变
}

; ===================== 示例：在主脚本初始化部分添加 =====================
; 在您的主脚本的初始化部分（通常在文件末尾，在 OnExit 之前）添加：

InitScript_Example() {
    ; ... 其他初始化代码 ...
    
    ; 初始化剪贴板数据库
    InitClipboardFTS5DB()
    
    ; ========== 添加这里：初始化监控器 ==========
    InitClipboardMonitor()
    ; ===========================================
    
    ; ... 其他初始化代码 ...
}

; ===================== 示例：添加热键打开监控窗口 =====================
; 在您的主脚本的热键定义部分添加：

; 例如：CapsLock+M 打开监控窗口
; #HotIf GetCapsLockState()
; m::ShowClipboardMonitor()
; #HotIf

; 或者使用其他热键组合，例如：
; ^!m::ShowClipboardMonitor()  ; Ctrl+Alt+M

; ===================== 完整集成步骤 =====================
; 
; 1. 在主脚本顶部添加：
;    #Include modules\ClipboardMonitor.ahk
;
; 2. 在初始化部分添加：
;    InitClipboardMonitor()
;
; 3. 修改 ProcessClipboardChange 函数：
;    - 将 SaveToClipboardFTS5 改为 SaveToClipboardFTS5WithMonitor
;    - 将 CaptureClipboardImageToFTS5 改为 CaptureClipboardImageToFTS5WithMonitor
;
; 4. 在 OnClipboardChangeHandler 中添加防抖过滤记录：
;    if (MonitorIsVisible) { RecordDebounceFiltered() }
;
; 5. 添加热键打开监控窗口（可选）：
;    CapsLock+M::ShowClipboardMonitor()
;
; ===================== 注意事项 =====================
;
; - 监控器会自动刷新数据，无需手动调用
; - 如果不想使用监控功能，可以继续使用原来的函数
; - 监控器对性能影响极小（<1ms）
; - 监控窗口可以随时打开/关闭，不影响主功能
