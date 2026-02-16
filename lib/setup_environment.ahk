; ======================================================================================================================
; Curser 环境初始化脚本
; 自动创建必要的目录结构和配置文件
; ======================================================================================================================

#Requires AutoHotkey v2.0

; 定义目录结构
dirs := [
    "..\config",
    "..\output\markdown",
    "..\output\html",
    "..\output\json",
    "..\logs"
]

; 定义配置文件内容
configContent := `;[Curser Configuration File]
[Settings]
Theme=dark
ExportFormat=markdown
ExportDir={EXPORT_DIR}
AutoScan=true
MaxPreviewLines=100
LogLevel=info

[Advanced]
EnableDebug=false
CacheEnabled=true
Timeout=30000
`

; 进度报告
progress := "🚀 Curser 环境初始化`n`n"

; 创建目录
progress .= "📁 创建目录结构:`n"
for dir in dirs {
    fullPath := A_ScriptDir "\" dir
    if !DirExist(fullPath) {
        DirCreate(fullPath)
        progress .= "  ✅ " dir "`n"
    } else {
        progress .= "  ⏭️ " dir " (已存在)`n"
    }
}

; 创建配置文件
configFile := A_ScriptDir "\..\config\curser.ini"
exportDir := StrReplace(A_ScriptDir "\..\output", "\", "/")
configContent := StrReplace(configContent, "{EXPORT_DIR}", exportDir)

if !FileExist(configFile) {
    try {
        FileAppend(configContent, configFile, "UTF-8")
        progress .= "`n📄 创建配置文件: ✅ curser.ini`n"
    } catch {
        progress .= "`n📄 创建配置文件: ❌ 失败`n"
    }
} else {
    progress .= "`n📄 配置文件: ⏭️ 已存在`n"
}

; 检查必要的库文件
progress .= "`n📚 检查库文件:`n"
requiredLibs := [
    "Class_SQLiteDB.ahk",
    "Gdip_All.ahk",
    "Jxon.ahk",
    "Neutron.ahk"
]

for lib in requiredLibs {
    if FileExist(A_ScriptDir "\" lib) {
        progress .= "  ✅ " lib "`n"
    } else {
        progress .= "  ❌ " lib "`n"
    }
}

; 检查可选库文件
progress .= "`n🔧 可选库文件:`n"
optionalLibs := [
    "WebView2.ahk",
    "WinClip.ahk",
    "WinClipAPI.ahk",
    "ImagePut.ahk",
    "OCR.ahk"
]

for lib in optionalLibs {
    if FileExist(A_ScriptDir "\" lib) {
        progress .= "  ✅ " lib "`n"
    } else {
        progress .= "  ⏭️ " lib " (可选)`n"
    }
}

; 检查Cursor环境
progress .= "`n🎯 检查Cursor环境:`n"
cursorPath := A_AppData "\Cursor\User\workspaceStorage"
if DirExist(cursorPath) {
    workspaceCount := 0
    Loop Files cursorPath "\*", "D" {
        dbPath := A_LoopFilePath "\state.vscdb"
        if FileExist(dbPath) {
            workspaceCount++
        }
    }
    progress .= "  ✅ 发现 " workspaceCount " 个工作区`n"
} else {
    progress .= "  ⚠️ 未检测到Cursor工作区`n"
}

; 创建启动脚本
startupScript := A_ScriptDir "\..\StartCurser.ahk"
startupContent := `; Curser 快速启动脚本
#Requires AutoHotkey v2.0
Run(A_ScriptDir "\lib\curser.ahk")
`

if !FileExist(startupScript) {
    try {
        FileAppend(startupContent, startupScript, "UTF-8")
        progress .= "`n🚀 创建启动脚本: ✅ StartCurser.ahk`n"
    } catch {
        progress .= "`n🚀 创建启动脚本: ❌ 失败`n"
    }
} else {
    progress .= "`n🚀 启动脚本: ⏭️ 已存在`n"
}

; 完成报告
progress .= "`n" "=".Repeat(50) "`n"
progress .= "🎉 环境初始化完成！`n`n"
progress .= "📖 使用方法:`n"
progress .= "  1. 双击 lib\curser.ahk 启动程序`n"
progress .= "  2. 或运行 StartCurser.ahk 快速启动`n"
progress .= "  3. 或运行 lib\curser_demo.ahk 查看演示`n`n"
progress .= "📄 配置文件位置: config\curser.ini`n"
progress .= "📁 输出目录: output\`n"
progress .= "📋 日志文件: logs\curser.log"

MsgBox(progress, "Curser 环境初始化完成", "Iconi")

; 询问是否立即运行
result := MsgBox("环境初始化完成！是否现在运行 Curser？", "启动确认", "YesNo Icon?")
if result = "Yes" {
    Run(A_ScriptDir "\curser.ahk")
}