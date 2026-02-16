#Requires AutoHotkey v2.0
#Include modules\ClipboardFTS5.ahk

; 删除旧数据库文件
try {
    FileDelete("Clipboard.db")
    FileDelete("Clipboard.db-shm")
    FileDelete("Clipboard.db-wal")
}

; 初始化数据库
TrayTip("测试", "开始初始化数据库", "Iconi 1")
if (!InitClipboardFTS5DB()) {
    MsgBox("数据库初始化失败")
    ExitApp
}
TrayTip("测试", "数据库初始化成功", "Iconi 1")

; 设置测试内容到剪贴板
A_Clipboard := "Fixed test content"
ClipWait(2)

; 手动调用保存函数
TrayTip("测试", "开始保存文本", "Iconi 1")
result := CaptureClipboardTextToFTS5("FixedTest")
if (result) {
    TrayTip("成功", "文本保存成功", "Iconi 1")
} else {
    TrayTip("失败", "文本保存失败", "Iconx 2")
}

Sleep(2000)

; 验证数据
global ClipboardFTS5DB
SQL := "SELECT COUNT(*) FROM ClipMain"
stmt := ""
if (ClipboardFTS5DB.Prepare(SQL, &stmt) && stmt.Step()) {
    count := stmt.Column(0)
    TrayTip("验证", "数据库中有 " . count . " 条记录", "Iconi 1")
    stmt.Free()
}

Sleep(3000)
ExitApp
