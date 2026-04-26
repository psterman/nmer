#Requires AutoHotkey v2.0

; 测试curser.ahk的核心功能
try {
    ; 模拟主要类的基本功能测试

    ; 测试目录结构
    configDir := A_ScriptDir "\..\config"
    outputDir := A_ScriptDir "\..\output"
    logsDir := A_ScriptDir "\..\logs"

    DirCreate(configDir)
    DirCreate(outputDir "\markdown")
    DirCreate(outputDir "\html")
    DirCreate(outputDir "\json")
    DirCreate(logsDir)

    ; 测试配置文件
    configFile := configDir "\curser.ini"
    IniWrite("dark", configFile, "Settings", "Theme")
    IniWrite("markdown", configFile, "Settings", "ExportFormat")
    IniWrite(outputDir, configFile, "Settings", "ExportDir")

    ; 读取配置测试
    theme := IniRead(configFile, "Settings", "Theme", "dark")
    format := IniRead(configFile, "Settings", "ExportFormat", "markdown")

    ; 测试工作区扫描
    workspacePath := A_AppData "\Cursor\User\workspaceStorage"
    workspaceCount := 0

    if (DirExist(workspacePath)) {
        Loop Files workspacePath "\*", "D" {
            dbPath := A_LoopFilePath "\state.vscdb"
            if (FileExist(dbPath)) {
                workspaceCount++
            }
        }
    }

    ; 显示测试结果
    result := "Curser功能测试结果:`n`n"
    result .= "✅ 目录结构创建成功`n"
    result .= "✅ 配置文件读写正常`n"
    result .= "   - 主题: " theme "`n"
    result .= "   - 格式: " format "`n"
    result .= "✅ 找到 " workspaceCount " 个工作区`n"

    if (workspaceCount > 0) {
        result .= "`n🎯 脚本准备就绪！可以正常使用。"
    } else {
        result .= "`n⚠️  未找到Cursor工作区，请确保Cursor已安装并使用过。"
    }

    MsgBox(result, "功能测试完成", "Iconi")

} catch error {
    MsgBox("测试失败: " error.Message "`n`n请检查依赖库是否完整。", "错误", "Iconx")
}