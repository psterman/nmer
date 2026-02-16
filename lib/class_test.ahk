#Requires AutoHotkey v2.0

; 测试CurserApp类定义
try {
    ; 测试类定义语法
    class CurserApp {
        __New() {
            this.value := "test"
        }

        TestMethod() {
            return "working"
        }
    }

    ; 测试实例化
    testApp := CurserApp()
    result := testApp.TestMethod()

    if (result == "working") {
        MsgBox("✅ CurserApp类语法正确", "成功")
    } else {
        MsgBox("❌ 类方法测试失败", "错误")
    }

} catch error {
    MsgBox("❌ 类定义错误: " error.Message "`n行号: " error.Line, "错误", "Iconx")
}