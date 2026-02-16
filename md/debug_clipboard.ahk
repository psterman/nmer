#Requires AutoHotkey v2.0
#Include modules\ClipboardFTS5.ahk

; 创建调试日志函数
DebugLog(message) {
    FileAppend(A_Now ": " . message . "`n", "debug_clipboard.log")
}

; 初始化数据库
DebugLog("开始初始化数据库")
if (!InitClipboardFTS5DB()) {
    DebugLog("数据库初始化失败")
    MsgBox("数据库初始化失败")
    ExitApp
}
DebugLog("数据库初始化成功")

; 检查全局变量
global ClipboardFTS5DB
DebugLog("ClipboardFTS5DB 状态: " . (ClipboardFTS5DB ? "已设置" : "未设置"))

; 测试剪贴板监听器
TestClipChange(Type) {
    DebugLog("剪贴板变化检测到，类型: " . Type)
    
    if (Type = 1) {
        DebugLog("剪贴板内容: " . A_Clipboard)
        DebugLog("开始调用 CaptureClipboardTextToFTS5")
        result := CaptureClipboardTextToFTS5("DebugApp")
        DebugLog("CaptureClipboardTextToFTS5 结果: " . (result ? "成功" : "失败"))
        
        ; 验证数据库
        if (ClipboardFTS5DB && ClipboardFTS5DB != 0) {
            SQL := "SELECT COUNT(*) FROM ClipMain"
            stmt := ""
            if (ClipboardFTS5DB.Prepare(SQL, &stmt) && stmt.Step()) {
                count := stmt.Column(0)
                DebugLog("数据库中记录数: " . count)
                stmt.Free()
            }
        }
    }
}

; 注册监听器
OnClipboardChange(TestClipChange, 1)
DebugLog("剪贴板监听器已注册")

TrayTip("调试脚本", "剪贴板监听器已启动，请复制一些文本", "Iconi 1")

; 保持脚本运行
Loop {
    Sleep(1000)
}
