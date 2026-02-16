#Requires AutoHotkey v2.0
#Include modules\ClipboardHistoryPanel.ahk

; 初始化数据库
InitClipboardFTS5DB()

; 插入一些测试数据
try {
    ; 插入测试数据1
    SaveToClipboardFTS5("测试数据1", "explorer.exe")
    Sleep(100)
    
    ; 插入测试数据2
    SaveToClipboardFTS5("测试数据2", "notepad.exe")
    Sleep(100)
    
    ; 插入测试数据3
    SaveToClipboardFTS5("测试数据3", "chrome.exe")
    Sleep(100)
    
    ; 插入测试数据4
    SaveToClipboardFTS5("测试数据4", "code.exe")
    Sleep(100)
    
    ; 插入测试数据5
    SaveToClipboardFTS5("测试数据5", "firefox.exe")
    Sleep(100)
    
    ; 插入测试数据6
    SaveToClipboardFTS5("测试数据6", "msedge.exe")
    Sleep(100)
    
    ; 插入测试数据7
    SaveToClipboardFTS5("测试数据7", "winword.exe")
    Sleep(100)
    
    ; 插入测试数据8
    SaveToClipboardFTS5("测试数据8", "excel.exe")
    Sleep(100)
    
    MsgBox("测试数据已插入数据库", "成功", "Iconi 64")
} catch as err {
    MsgBox("插入数据失败: " . err.Message, "错误", "Iconx 48")
}

; 显示历史面板
ShowClipboardHistoryPanel()

; 保持脚本运行
Persistent
