; 导出功能测试
#Requires AutoHotkey v2.0

#Include curser.ahk

try {
    ; 创建一个测试聊天数据
    testChat := Map(
        "id", "test_001",
        "title", "测试聊天",
        "type", "chat",
        "timestamp", A_Now,
        "data", Map(
            "bubbles", [
                Map("type", "user", "text", "你好，这是一个测试消息"),
                Map("type", "ai", "text", "你好！这是一个AI回复测试")
            ]
        )
    )

    ; 测试Markdown导出
    chats := [testChat]
    filePath := "..\output\markdown\test_export.md"

    app.ExportToMarkdown(chats, filePath)

    if FileExist(filePath) {
        MsgBox("✅ 导出功能测试成功！`n文件已保存至: " filePath, "成功", "Iconi")
        Run(filePath)
    } else {
        MsgBox("❌ 导出功能测试失败", "错误", "Iconx")
    }

} catch error {
    MsgBox("❌ 测试出错: " Type(error), "错误", "Iconx")
}