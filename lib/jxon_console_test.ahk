; Console test for Jxon
#Requires AutoHotkey v2.0

#Include Jxon.ahk

try {
    ; Test basic functionality
    testObj := Map("name", "test", "value", 123)
    jsonStr := Jxon_Dump(testObj)
    parsed := Jxon_Load(jsonStr)

    MsgBox("Jxon测试结果:`n`nJSON: " jsonStr "`n`n解析结果: name=" parsed["name"] ", value=" parsed["value"], "Jxon测试", "Iconi")
} catch error {
    MsgBox("Jxon测试失败: " Type(error), "错误", "Iconx")
}