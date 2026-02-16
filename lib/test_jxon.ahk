; Jxon 测试脚本 - 验证 JSON 功能
#Requires AutoHotkey v2.0

#Include Jxon.ahk

; 辅助函数
RepeatString(str, count) {
    result := ""
    Loop count {
        result .= str
    }
    return result
}

report := "Jxon 功能测试报告`n"
report .= RepeatString("=", 50) "`n`n"

; 测试1: 基本对象 dump/load
try {
    testObj := Map("name", "test", "value", 123)
    jsonStr := Jxon_Dump(testObj)
    parsed := Jxon_Load(jsonStr)
    if (parsed["name"] == "test" && parsed["value"] == 123) {
        report .= "✅ 基本对象测试: 通过`n"
    } else {
        report .= "❌ 基本对象测试: 失败`n"
    }
} catch error {
    report .= "❌ 基本对象测试: 错误 - " Type(error) "`n"
}

; 测试2: 数组 dump/load
try {
    testArr := [1, 2, 3, "test"]
    jsonStr := Jxon_Dump(testArr)
    parsed := Jxon_Load(jsonStr)
    if (parsed.Length == 4 && parsed[4] == "test") {
        report .= "✅ 数组测试: 通过`n"
    } else {
        report .= "❌ 数组测试: 失败`n"
    }
} catch error {
    report .= "❌ 数组测试: 错误 - " Type(error) "`n"
}

; 测试3: 嵌套对象
try {
    nested := Map("user", Map("name", "Alice", "age", 30), "active", true)
    jsonStr := Jxon_Dump(nested)
    parsed := Jxon_Load(jsonStr)
    if (parsed["user"]["name"] == "Alice" && parsed["active"] == true) {
        report .= "✅ 嵌套对象测试: 通过`n"
    } else {
        report .= "❌ 嵌套对象测试: 失败`n"
    }
} catch error {
    report .= "❌ 嵌套对象测试: 错误 - " Type(error) "`n"
}

; 测试4: 字符串转义
try {
    escStr := Map("text", 'Hello "World" with \n newlines and \t tabs')
    jsonStr := Jxon_Dump(escStr)
    parsed := Jxon_Load(jsonStr)
    if (parsed["text"] == 'Hello "World" with \n newlines and \t tabs') {
        report .= "✅ 字符串转义测试: 通过`n"
    } else {
        report .= "❌ 字符串转义测试: 失败`n"
    }
} catch error {
    report .= "❌ 字符串转义测试: 错误 - " Type(error) "`n"
}

report .= "`n" "=".Repeat(50) "`n"

; 检查是否所有测试通过
if (InStr(report, "❌")) {
    report .= "⚠️  部分测试失败，请检查 Jxon 实现`n"
} else {
    report .= "🎉 所有测试通过！Jxon 功能正常`n"
}

MsgBox(report, "Jxon 测试结果", "Iconi")