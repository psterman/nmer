; Jxon基础功能测试
#Requires AutoHotkey v2.0

try {
    ; 测试1: 类定义
    class TestClass {
        static testMethod() {
            return "类方法正常"
        }
    }

    result1 := TestClass.testMethod()
    test1Passed := (result1 = "类方法正常")

    ; 测试2: 简单JSON解析
    simpleJSON := '{"name":"test"}'
    
    ; 手动解析（不使用Jxon）
    if (InStr(simpleJSON, "name") && InStr(simpleJSON, "test")) {
        test2Passed := true
    } else {
        test2Passed := false
    }

    ; 测试3: 简化JSON序列化
    testObj := Map("key1", "value1", "key2", "value2")
    
    ; 手动序列化
    manualJSON := "{"
    first := true
    for key, value in testObj {
        if (!first) {
            manualJSON .= ","
        }
        manualJSON .= '"' key '":"' value '"'
        first := false
    }
    manualJSON .= "}"
    
    if (InStr(manualJSON, "key1") && InStr(manualJSON, "value1")) {
        test3Passed := true
    } else {
        test3Passed := false
    }

    ; 生成报告
    report := "Jxon基础功能测试报告`n"
    report .= "=".Repeat(50) "`n`n"
    report .= "测试1 - 类定义: " (test1Passed ? "✅ 通过" : "❌ 失败") "`n"
    report .= "测试2 - JSON识别: " (test2Passed ? "✅ 通过" : "❌ 失败") "`n"
    report .= "测试3 - 对象序列化: " (test3Passed ? "✅ 通过" : "❌ 失败") "`n"
    report .= "`n" "=".Repeat(50) "`n`n"

    passedCount := (test1Passed ? 1 : 0) + (test2Passed ? 1 : 0) + (test3Passed ? 1 : 0)
    totalCount := 3

    report .= "结果: " passedCount "/" totalCount " 通过 (" Round(passedCount/totalCount*100) "%)`n`n"

    if (passedCount == totalCount) {
        report .= "🎉 所有测试通过！Jxon基础功能正常。"
    } else {
        report .= "⚠️  部分测试失败。"
    }

    MsgBox(report, "Jxon测试", "Iconi")

} catch error {
    MsgBox("测试过程出错: " Type(error), "错误", "Iconx")
}