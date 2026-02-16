#Requires AutoHotkey v2.0
#Include modules\ClipboardFTS5.ahk

; 初始化数据库
if (!InitClipboardFTS5DB()) {
    MsgBox("数据库初始化失败")
    ExitApp
}

; 测试回调函数
TestClipChange(Type) {
    TrayTip("剪贴板变化", "Type: " . Type . ", Content: " . A_Clipboard, "Iconi 2")
    
    if (Type = 1) {
        ; 文本
        CaptureClipboardTextToFTS5("TestApp")
        TrayTip("保存成功", "文本已保存到数据库", "Iconi 1")
    } else if (Type = 2) {
        ; 图片
        CaptureClipboardImageToFTS5("TestApp")
        TrayTip("保存成功", "图片已保存到数据库", "Iconi 1")
    }
}

; 注册监听器
OnClipboardChange(TestClipChange, 1)

TrayTip("测试脚本", "剪贴板监听器已启动", "Iconi 1")

; 保持脚本运行
Loop {
    Sleep(1000)
}
