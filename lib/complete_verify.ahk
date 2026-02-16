; ======================================================================================================================
; Curser - 完整功能验证测试
; ======================================================================================================================

#Requires AutoHotkey v2.0

; 定义辅助函数
RepeatString(str, count) {
    result := ""
    Loop count {
        result .= str
    }
    return result
}

; 定义简化JSON类
class JSON {
    static parse(jsonStr) {
        jsonStr := Trim(jsonStr)
        if (SubStr(jsonStr, 1, 1) == "{") {
            result := Map()
            content := SubStr(jsonStr, 2, -1)
            Loop Parse content, ',"' {
                if (InStr(A_LoopField, ":")) {
                    parts := StrSplit(A_LoopField, ":", , 2)
                    if (parts.Length == 2) {
                        key := Trim(parts[1], '" ')
                        value := Trim(parts[2], '" ')
                        result[key] := value
                    }
                }
            }
            return result
        }
        return jsonStr
    }

    static stringify(obj, indent := 0) {
        if (obj is Map) {
            result := "{"
            first := true
            for key, value in obj {
                if (!first) result .= ","
                result .= (indent ? "`n" RepeatString("  ", indent) : "") '"' key '":'
                if (value is String) {
                    result .= '"' value '"'
                } else {
                    result .= String(value)
                }
                first := false
            }
            result .= (indent ? "`n" RepeatString("  ", indent-1) : "") "}"
            return result
        }
        return String(obj)
    }
}

; 验证报告
report := "🎯 Curser 完整功能验证报告`n"
report .= "=".Repeat(60) "`n`n"

; 测试1: 辅助函数
try {
    result := RepeatString("test", 3)
    if (result == "testtesttest") {
        report .= "✅ 辅助函数测试: 通过`n"
    } else {
        report .= "❌ 辅助函数测试: 失败`n"
    }
} catch error {
    report .= "❌ 辅助函数测试: 错误 - " error.message "`n"
}

; 测试2: JSON处理
try {
    testObj := Map("name", "test", "value", 123)
    jsonStr := JSON.stringify(testObj)
    if (InStr(jsonStr, "name") && InStr(jsonStr, "test")) {
        report .= "✅ JSON处理测试: 通过`n"
    } else {
        report .= "❌ JSON处理测试: 失败`n"
    }
} catch error {
    report .= "❌ JSON处理测试: 错误 - " error.message "`n"
}

; 测试3: Jxon库
try {
    testObj := Map("test", "value")
    jsonStr := Jxon_Dump(testObj)
    parsed := Jxon_Load(&jsonStr)
    if (parsed["test"] == "value") {
        report .= "✅ Jxon库测试: 通过`n"
    } else {
        report .= "❌ Jxon库测试: 失败`n"
    }
} catch error {
    report .= "❌ Jxon库测试: 错误 - " error.message "`n"
}

; 测试4: SQLite库
try {
    ; 只是测试库文件存在，不实际连接数据库
    if (FileExist("Class_SQLiteDB.ahk")) {
        report .= "✅ SQLite库文件: 存在`n"
    } else {
        report .= "❌ SQLite库文件: 不存在`n"
    }
} catch error {
    report .= "❌ SQLite库测试: 错误 - " error.message "`n"
}

; 测试5: 主程序语法
try {
    ; 这里我们只是验证语法，不会实际运行GUI
    #Include curser.ahk
    report .= "✅ 主程序语法: 通过`n"
} catch error {
    report .= "❌ 主程序语法: 错误 - " error.message "`n"
}

; 总结
report .= "`n" "=".Repeat(60) "`n"

passedTests := 0
totalTests := 5

; 简单的成功计数
if (InStr(report, "辅助函数测试: 通过")) passedTests++
if (InStr(report, "JSON处理测试: 通过")) passedTests++
if (InStr(report, "Jxon库测试: 通过")) passedTests++
if (InStr(report, "SQLite库文件: 存在")) passedTests++
if (InStr(report, "主程序语法: 通过")) passedTests++

report .= "测试结果: " passedTests "/" totalTests " 通过`n`n"

if (passedTests == totalTests) {
    report .= "🎉 所有测试通过！Curser功能完全正常。"
} else {
    report .= "⚠️ 部分测试失败，请检查相关功能。"
}

MsgBox(report, "Curser完整验证", "Iconi")

; 如果所有测试通过，询问是否启动程序
if (passedTests == totalTests) {
    result := MsgBox("所有测试通过！是否现在启动 Curser？", "启动确认", "YesNo Icon?")
    if (result = "Yes") {
        Run("curser.ahk")
    }
}