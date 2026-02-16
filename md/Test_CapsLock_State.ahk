; ======================================================================================================================
; CapsLock 状态测试脚本
; 用于验证 CapsLock 状态管理是否正确
; 使用方法：运行此脚本，然后按照提示测试各种操作
; ======================================================================================================================

#Requires AutoHotkey v2.0
#SingleInstance Force

global TestResults := []
global CapsLockStateBefore := false
global CapsLockStateAfter := false

; 创建测试窗口
TestGUI := Gui("+AlwaysOnTop", "CapsLock 状态测试")
TestGUI.SetFont("s11", "Segoe UI")

TestGUI.Add("Text", "w400", "CapsLock 状态测试工具").SetFont("s14 Bold")
TestGUI.Add("Text", "w400", "请按照以下步骤测试：")
TestGUI.Add("Text", "w400", "")

; 测试1
TestGUI.Add("Text", "w400 cBlue", "测试 1: 单击 CapsLock")
TestGUI.Add("Text", "w400", "1. 观察 CapsLock 指示灯状态").SetFont("s9")
TestGUI.Add("Text", "w400", "2. 单击 CapsLock 键").SetFont("s9")
TestGUI.Add("Text", "w400", "3. 观察指示灯是否切换").SetFont("s9")
TestGUI.Add("Text", "w400", "4. 再次单击，观察是否切换回来").SetFont("s9")
Test1Result := TestGUI.Add("Text", "w400 cRed", "结果: 未测试")
TestGUI.Add("Button", "w100", "通过", (*) => Test1Result.SetText("结果: ✅ 通过").SetFont("cGreen"))
TestGUI.Add("Button", "w100 x+10", "失败", (*) => Test1Result.SetText("结果: ❌ 失败").SetFont("cRed"))
TestGUI.Add("Text", "w400", "")

; 测试2
TestGUI.Add("Text", "w400 cBlue", "测试 2: CapsLock + F（或其他快捷键）")
TestGUI.Add("Text", "w400", "1. 确保 CapsLock 指示灯关闭").SetFont("s9")
TestGUI.Add("Text", "w400", "2. 按住 CapsLock，按 F 键，释放 CapsLock").SetFont("s9")
TestGUI.Add("Text", "w400", "3. 观察 CapsLock 指示灯是否保持关闭").SetFont("s9")
Test2Result := TestGUI.Add("Text", "w400 cRed", "结果: 未测试")
TestGUI.Add("Button", "w100", "通过", (*) => Test2Result.SetText("结果: ✅ 通过").SetFont("cGreen"))
TestGUI.Add("Button", "w100 x+10", "失败", (*) => Test2Result.SetText("结果: ❌ 失败").SetFont("cRed"))
TestGUI.Add("Text", "w400", "")

; 测试3
TestGUI.Add("Text", "w400 cBlue", "测试 3: 中文输入法切换")
TestGUI.Add("Text", "w400", "1. 打开记事本或文本编辑器").SetFont("s9")
TestGUI.Add("Text", "w400", "2. 使用 CapsLock 切换中英文输入法").SetFont("s9")
TestGUI.Add("Text", "w400", "3. 观察是否能正常切换").SetFont("s9")
Test3Result := TestGUI.Add("Text", "w400 cRed", "结果: 未测试")
TestGUI.Add("Button", "w100", "通过", (*) => Test3Result.SetText("结果: ✅ 通过").SetFont("cGreen"))
TestGUI.Add("Button", "w100 x+10", "失败", (*) => Test3Result.SetText("结果: ❌ 失败").SetFont("cRed"))
TestGUI.Add("Text", "w400", "")

; 实时状态显示
TestGUI.Add("Text", "w400", "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━").SetFont("s10")
StatusText := TestGUI.Add("Text", "w400 cBlue", "当前 CapsLock 状态: 检测中...")
TestGUI.Add("Text", "w400", "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━").SetFont("s10")

; 退出按钮
TestGUI.Add("Button", "w100", "退出", (*) => ExitApp())

; 显示窗口
TestGUI.Show("Center")

; 启动状态监测定时器
SetTimer(UpdateCapsLockStatus.Bind(StatusText), 100)

; 监测 CapsLock 状态的函数
UpdateCapsLockStatus(StatusCtrl, *) {
    try {
        State := GetKeyState("CapsLock", "T")
        if (State) {
            StatusCtrl.SetText("当前 CapsLock 状态: 🔴 开启 (ON)")
            StatusCtrl.SetFont("cRed")
        } else {
            StatusCtrl.SetText("当前 CapsLock 状态: 🟢 关闭 (OFF)")
            StatusCtrl.SetFont("cGreen")
        }
    } catch as err {
        StatusCtrl.SetText("当前 CapsLock 状态: 检测错误")
        StatusCtrl.SetFont("cGray")
    }
}

; 托盘提示
TrayTip("CapsLock 测试工具", "测试工具已启动，请按照窗口中的步骤进行测试", "Iconi")
