; ======================================================================================================================
; Curser 最终环境检查
; 验证所有组件是否正常工作
; ======================================================================================================================

#Requires AutoHotkey v2.0

; 最终检查报告
finalReport := "🎯 Curser 最终环境检查报告`n"
finalReport .= "=".Repeat(60) "`n`n"

; 1. 检查目录结构
finalReport .= "📁 目录结构检查:`n"
dirs := ["config", "output\markdown", "output\html", "output\json", "logs", "lib"]
for dir in dirs {
    fullPath := A_ScriptDir "\..\" dir
    if DirExist(fullPath) {
        finalReport .= "  ✅ " dir "`n"
    } else {
        finalReport .= "  ❌ " dir "`n"
    }
}

; 2. 检查关键文件
finalReport .= "`n📄 关键文件检查:`n"
files := [
    "lib\curser.ahk",
    "lib\Class_SQLiteDB.ahk",
    "lib\Gdip_All.ahk",
    "lib\Jxon.ahk",
    "config\curser.ini"
]

for file in files {
    fullPath := A_ScriptDir "\..\" file
    if FileExist(fullPath) {
        finalReport .= "  ✅ " file "`n"
    } else {
        finalReport .= "  ❌ " file "`n"
    }
}

; 3. 检查Cursor环境
finalReport .= "`n🎯 Cursor环境检查:`n"
cursorPath := A_AppData "\Cursor\User\workspaceStorage"
if DirExist(cursorPath) {
    workspaceCount := 0
    dbCount := 0
    Loop Files cursorPath "\*", "D" {
        workspaceCount++
        dbPath := A_LoopFilePath "\state.vscdb"
        if FileExist(dbPath) {
            dbCount++
        }
    }
    finalReport .= "  ✅ 工作区目录存在`n"
    finalReport .= "  📊 发现 " workspaceCount " 个工作区文件夹`n"
    finalReport .= "  🗄️ 发现 " dbCount " 个数据库文件`n"
} else {
    finalReport .= "  ⚠️ 未检测到Cursor工作区目录`n"
    finalReport .= "     路径: " cursorPath "`n"
}

; 4. 测试基本功能
finalReport .= "`n🧪 功能测试:`n"
try {
    ; 测试文件读取
    configContent := FileRead(A_ScriptDir "\..\config\curser.ini")
    finalReport .= "  ✅ 配置文件读取正常`n"
} catch {
    finalReport .= "  ❌ 配置文件读取失败`n"
}

try {
    ; 测试库文件存在性
    libContent := FileRead(A_ScriptDir "\Class_SQLiteDB.ahk")
    finalReport .= "  ✅ SQLite库文件正常`n"
} catch {
    finalReport .= "  ❌ SQLite库文件异常`n"
}

; 5. 使用说明
finalReport .= "`n📖 使用指南:`n"
finalReport .= "  🚀 启动: 双击 lib\curser.ahk`n"
finalReport .= "  🔍 演示: 运行 lib\curser_demo.ahk`n"
finalReport .= "  ⚙️ 配置: 编辑 config\curser.ini`n"
finalReport .= "  📁 输出: output\ 目录`n"
finalReport .= "  📋 日志: logs\curser.log`n"

; 6. 故障排除
finalReport .= "`n🔧 常见问题:`n"
finalReport .= "  • 如果启动失败，检查所有库文件是否存在`n"
finalReport .= "  • 如果找不到工作区，确保Cursor已安装并使用过`n"
finalReport .= "  • 如果导出失败，检查输出目录权限`n"

finalReport .= "`n" "=".Repeat(60) "`n"
finalReport .= "🎉 Curser 环境检查完成！"

MsgBox(finalReport, "Curser 环境检查报告", "Iconi")

; 询问是否启动程序
result := MsgBox("环境检查完成！是否现在启动 Curser？", "启动确认", "YesNo Icon?")
if result = "Yes" {
    try {
        Run(A_ScriptDir "\curser.ahk")
    } catch error {
        MsgBox("启动失败: " error.Message, "错误", "Iconx")
    }
}