; ======================================================================================================================
; Curser - 最终完整性验证
; ======================================================================================================================

#Requires AutoHotkey v2.0

; 包含必要的库
#Include Jxon.ahk

; ===================== 全局辅助函数 =====================
RepeatString(str, count) {
    result := ""
    Loop count {
        result .= str
    }
    return result
}

; ===================== 验证报告 =====================
report := "🎯 Curser 最终完整性验证报告`n"
report .= RepeatString("=", 70) "`n`n"

; 测试计数
passedTests := 0
totalTests := 5

; 测试1: 辅助函数
try {
    result := RepeatString("test", 3)
    if (result == "testtesttest") {
        report .= "✅ 辅助函数: 通过`n"
        passedTests++
    } else {
        report .= "❌ 辅助函数: 失败`n"
    }
} catch error {
    report .= "❌ 辅助函数: 错误 - " Type(error) "`n"
}

; 测试2: Jxon库
try {
    testObj := Map("name", "test", "value", 123)
    jsonStr := Jxon_Dump(testObj)
    parsed := Jxon_Load(jsonStr)
    if (parsed["name"] == "test" && parsed["value"] == 123) {
        report .= "✅ Jxon库: 通过`n"
        passedTests++
    } else {
        report .= "❌ Jxon库: 失败`n"
    }
} catch error {
    report .= "❌ Jxon库: 错误 - " Type(error) "`n"
}

; 测试3: 库文件存在性
try {
    libsExist := 0
    requiredLibs := ["Class_SQLiteDB.ahk", "Gdip_All.ahk", "Jxon.ahk"]
    for lib in requiredLibs {
        if (FileExist(lib)) {
            libsExist++
        }
    }
    if (libsExist == requiredLibs.Length) {
        report .= "✅ 库文件: 全部存在`n"
        passedTests++
    } else {
        report .= "❌ 库文件: 缺失 " (requiredLibs.Length - libsExist) " 个`n"
    }
} catch error {
    report .= "❌ 库文件检查: 错误 - " Type(error) "`n"
}

; 测试4: 目录结构
try {
    dirsExist := 0
    dirs := ["..\config", "..\output\markdown", "..\output\html", "..\output\json", "..\logs"]
    for dir in dirs {
        if (DirExist(dir)) {
            dirsExist++
        }
    }
    if (dirsExist == dirs.Length) {
        report .= "✅ 目录结构: 完整`n"
        passedTests++
    } else {
        report .= "❌ 目录结构: 缺失 " (dirs.Length - dirsExist) " 个`n"
    }
} catch error {
    report .= "❌ 目录检查: 错误 - " Type(error) "`n"
}

; 测试5: 配置文件
try {
    configFile := "..\config\curser.ini"
    if (FileExist(configFile)) {
        report .= "✅ 配置文件: 存在`n"
        passedTests++
    } else {
        report .= "❌ 配置文件: 不存在`n"
    }
} catch error {
    report .= "❌ 配置文件检查: 错误 - " Type(error) "`n"
}

; 总结报告
report .= "`n" RepeatString("=", 70) "`n"
report .= "测试结果: " passedTests "/" totalTests " 通过 (" Round(passedTests/totalTests*100) "%)`n`n"

if (passedTests == totalTests) {
    report .= "🎉 所有测试通过！Curser已完全准备就绪。`n"
    report .= "🚀 您现在可以运行 curser.ahk 开始使用。`n"
    success := true
} else {
    report .= "⚠️  部分测试失败，请检查相关组件。`n"
    success := false
}

; 显示报告
MsgBox(report, "Curser完整性验证", "Iconi")

; 如果全部通过，询问是否启动程序
if (passedTests == totalTests) {
    result := MsgBox("验证通过！是否现在启动Curser？", "启动确认", "YesNo Icon?")
    if (result = "Yes") {
        try {
            Run("curser.ahk")
        } catch error {
            MsgBox("启动失败: " Type(error), "错误", "Iconx")
        }
    }
}