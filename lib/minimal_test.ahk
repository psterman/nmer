#Requires AutoHotkey v2.0
#SingleInstance Force

; 最小化测试版本 - 只测试基本语法
MsgBox("基本AHK语法正常", "测试")

; 测试变量定义
global VERSION := "1.0.0"
global APP_NAME := "Test"

; 测试Map定义
global Themes := Map(
    "dark", Map("bg", 0x1e1e1e),
    "light", Map("bg", 0xffffff)
)

; 测试类定义
class TestClass {
    __New() {
        this.value := "test"
    }

    TestMethod() {
        return "working"
    }
}

; 测试类实例化
testInstance := TestClass()
result := testInstance.TestMethod()

if (result == "working") {
    MsgBox("✅ 语法检查完全通过！", "成功")
} else {
    MsgBox("❌ 语法检查失败", "错误")
}