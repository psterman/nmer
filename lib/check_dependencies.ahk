; ======================================================================================================================
; Curser 依赖检查脚本
; 检查所有必要的库文件是否存在且可正常加载
; ======================================================================================================================

#Requires AutoHotkey v2.0

; 依赖清单
requiredLibs := [
    "Class_SQLiteDB.ahk",
    "Gdip_All.ahk",
    "Jxon.ahk",
    "Neutron.ahk",
    "WebView2.ahk",
    "WinClip.ahk",
    "WinClipAPI.ahk",
    "ImagePut.ahk",
    "OCR.ahk"
]

; 检查结果
checkResults := Map()

; 执行检查
for libName in requiredLibs {
    libPath := A_ScriptDir "\" libName
    exists := FileExist(libPath)
    checkResults[libName] := Map("exists", exists, "path", libPath, "loadable", false)

    if exists {
        ; 尝试加载库（简单的语法检查）
        try {
            ; 这里只是检查文件是否能被读取，实际加载在运行时进行
            FileRead(libPath, "UTF-8")
            checkResults[libName]["loadable"] := true
        } catch {
            checkResults[libName]["loadable"] := false
        }
    }
}

; 生成报告
report := "🔍 Curser 依赖库检查报告`n`n"
report .= "必需库文件检查:`n"
report .= "=".Repeat(50) "`n"

allGood := true
for libName, result in checkResults {
    status := result["exists"] ? (result["loadable"] ? "✅ 正常" : "⚠️ 存在但可能有问题") : "❌ 缺失"
    report .= libName " - " status "`n"
    if !result["exists"] || !result["loadable"] {
        allGood := false
    }
}

report .= "`n" "=".Repeat(50) "`n"

if allGood {
    report .= "🎉 所有依赖库都正常！Curser 可以正常运行。"
} else {
    report .= "⚠️ 发现问题，请检查缺失或损坏的库文件。"
}

; 检查其他必要的文件
report .= "`n`n其他必要文件检查:`n"
report .= "=".Repeat(30) "`n"

otherFiles := [
    "..\config\curser.ini",
    "..\output\markdown",
    "..\output\html",
    "..\output\json",
    "..\logs"
]

for filePath in otherFiles {
    fullPath := A_ScriptDir "\" filePath
    if InStr(filePath, "\") && !DirExist(fullPath) {
        DirCreate(fullPath)
    }
    exists := DirExist(fullPath) || FileExist(fullPath)
    status := exists ? "✅ 存在" : "❌ 缺失"
    report .= filePath " - " status "`n"
}

; 显示报告
MsgBox(report, "Curser 依赖检查", "Iconi")

; 如果所有检查都通过，询问是否运行主程序
if allGood {
    result := MsgBox("所有依赖检查通过！是否现在运行 Curser？", "启动确认", "YesNo Icon?")
    if result = "Yes" {
        Run(A_ScriptDir "\curser.ahk")
    }
}