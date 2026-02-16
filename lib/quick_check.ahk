#Requires AutoHotkey v2.0

; 辅助函数
RepeatString(str, count) {
    result := ""
    Loop count {
        result .= str
    }
    return result
}

; 简化语法检查 - 只测试核心函数
try {
    ; 测试辅助函数
    result := RepeatString("test", 3)
    if (result != "testtesttest") {
        throw Error("RepeatString函数错误")
    }

    ; 测试JSON类
    testObj := Map("name", "test", "value", 123)
    jsonStr := JSON.stringify(testObj)
    if (!InStr(jsonStr, "name")) {
        throw Error("JSON.stringify错误")
    }

    parsed := JSON.parse('{"name":"test"}')
    if (!parsed.Has("name")) {
        throw Error("JSON.parse错误")
    }

    MsgBox("✅ 核心函数语法检查通过！", "成功", "Iconi")

} catch error {
    MsgBox("❌ 语法错误: " error.Message "`n`n行号: " error.Line "`n文件: " error.File, "错误", "Iconx")
}

; 包含核心定义以进行完整检查
#Include curser.ahk