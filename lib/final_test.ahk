; ======================================================================================================================
; Curser - 最终功能测试
; 测试所有核心功能是否正常工作
; ======================================================================================================================

#Requires AutoHotkey v2.0

; 测试结果
testResults := Map()

; 测试1: 库文件加载
try {
    #Include curser.ahk
    testResults["库文件加载"] := "✅ 通过"
} catch {
    testResults["库文件加载"] := "❌ 失败: " error.Message
}

; 测试2: 基本类实例化
try {
    ; 这里我们不能直接实例化CurserApp，因为它会创建GUI
    ; 但我们可以测试辅助函数
    result := RepeatString("test", 3)
    if (result == "testtesttest") {
        testResults["辅助函数"] := "✅ 通过"
    } else {
        testResults["辅助函数"] := "❌ 失败"
    }
} catch {
    testResults["辅助函数"] := "❌ 失败: " error.Message
}

; 测试3: JSON处理
try {
    testObj := Map("name", "test", "value", 123)
    jsonStr := JSON.stringify(testObj)
    if (InStr(jsonStr, "name") && InStr(jsonStr, "test")) {
        testResults["JSON处理"] := "✅ 通过"
    } else {
        testResults["JSON处理"] := "❌ 失败"
    }
} catch {
    testResults["JSON处理"] := "❌ 失败: " error.Message
}

; 测试4: Jxon库
try {
    testObj := Map("test", "value")
    jsonStr := Jxon_Dump(testObj)
    parsed := Jxon_Load(&jsonStr)
    if (parsed["test"] == "value") {
        testResults["Jxon库"] := "✅ 通过"
    } else {
        testResults["Jxon库"] := "❌ 失败"
    }
} catch {
    testResults["Jxon库"] := "❌ 失败: " error.Message
}

; 显示测试结果
report := "🎯 Curser 最终功能测试报告`n"
report .= "=".Repeat(50) "`n`n"

for testName, result in testResults {
    report .= testName ": " result "`n"
}

report .= "`n" "=".Repeat(50) "`n"

; 检查是否所有测试都通过
allPassed := true
for result in testResults {
    if (InStr(result, "❌")) {
        allPassed := false
        break
    }
}

if (allPassed) {
    report .= "🎉 所有测试通过！Curser功能正常。"
} else {
    report .= "⚠️ 部分测试失败，请检查相关功能。"
}

MsgBox(report, "Curser功能测试", "Iconi")