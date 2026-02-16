; Console Jxon test - no GUI
#Requires AutoHotkey v2.0

#Include Jxon.ahk

; Test basic functionality
try {
    testObj := Map("name", "test", "value", 123)
    jsonStr := Jxon_Dump(testObj)
    parsed := Jxon_Load(jsonStr)

    success := (parsed["name"] == "test" && parsed["value"] == 123)

    if (success) {
        MsgBox("✅ Jxon测试通过！`nJSON: " jsonStr, "成功")
    } else {
        MsgBox("❌ Jxon测试失败", "失败")
    }
} catch error {
    MsgBox("❌ Jxon测试错误: " Type(error), "错误")
}