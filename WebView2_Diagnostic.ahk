; ======================================================================================================================
; WebView2 诊断工具
; 用于检测 WebView2 运行时是否正确安装
; ======================================================================================================================

#Requires AutoHotkey v2.0
#Include lib\WebView2.ahk

; 创建诊断窗口
DiagGui := Gui("+Resize", "WebView2 诊断工具")
DiagGui.SetFont("s10", "Consolas")
DiagGui.BackColor := "0x1e1e1e"

; 添加输出框
global OutputEdit := DiagGui.Add("Edit", "w600 h400 ReadOnly Multi c0xcccccc Background0x2d2d30", "正在检测 WebView2..`n`n")

; 添加按钮
DiagGui.Add("Button", "w150 h30", "测试 WebView2").OnEvent("Click", TestWebView2)
DiagGui.Add("Button", "x+10 w150 h30", "复制日志").OnEvent("Click", (*) => A_Clipboard := OutputEdit.Value)
DiagGui.Add("Button", "x+10 w150 h30", "清除日志").OnEvent("Click", (*) => OutputEdit.Value := "")

DiagGui.Show()

; 自动开始检测
SetTimer(AutoTest, -500)

AutoTest() {
    TestWebView2()
}

TestWebView2(*) {
    Log(StrRepeat("=", 60))
    Log("开始 WebView2 诊断 [" . A_Now . "]")
    Log(StrRepeat("=", 60))
    
    ; 1. 检查 WebView2.ahk 是否存在
    Log("`n[1/7] 检查 WebView2.ahk 文件...")
    webview2Path := A_ScriptDir "\lib\WebView2.ahk"
    if FileExist(webview2Path) {
        Log("✓ WebView2.ahk 存在: " . webview2Path)
    } else {
        Log("✗ WebView2.ahk 不存在: " . webview2Path)
        Log("  请确保 lib\WebView2.ahk 文件存在")
        return
    }
    
    ; 2. 检查 WebView2 运行时注册表
    Log("`n[2/7] 检查 WebView2 运行时注册表...")
    try {
        version := RegRead("HKLM\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}", "pv")
        Log("✓ WebView2 运行时已安装，版本: " . version)
    } catch {
        try {
            version := RegRead("HKLM\SOFTWARE\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}", "pv")
            Log("✓ WebView2 运行时已安装，版本: " . version)
        } catch {
            Log("✗ 未找到 WebView2 运行时注册表项")
            Log("  请访问以下地址下载并安装 WebView2 运行时:")
            Log("  https://developer.microsoft.com/microsoft-edge/webview2/")
        }
    }
    
    ; 3. 检查 Edge 浏览器
    Log("`n[3/7] 检查 Microsoft Edge...")
    edgePath := A_ProgramFiles . "\Microsoft\Edge\Application\msedge.exe"
    if FileExist(edgePath) {
        Log("✓ Microsoft Edge 已安装: " . edgePath)
    } else {
        Log("⚠ Microsoft Edge 未找到（非必需，但 WebView2 通常依赖它）")
    }
    
    ; 4. 尝试创建 WebView2 对象
    Log("`n[4/7] 尝试创建 WebView2 对象...")
    testGui := Gui("+AlwaysOnTop", "WebView2 Test")
    testGui.Show("w800 h600 Hide")
    
    testSuccess := false
    testError := ""
    
    try {
        Log("  调用 WebView2.create()...")
        WebView2.create(testGui.Hwnd, WebView2Created)
        Log("✓ WebView2.create() 调用成功")
        testSuccess := true
    } catch as err {
        Log("✗ WebView2.create() 失败")
        Log("  错误: " . err.Message)
        testError := err.Message
    }
    
    ; 5. 等待初始化
    if testSuccess {
        Log("`n[5/7] 等待 WebView2 初始化...")
        Log("  请等待最多 10 秒...")
        
        timeout := A_TickCount + 10000
        while (A_TickCount < timeout) {
            Sleep(100)
            if WinExist("ahk_id " . testGui.Hwnd) {
                ; 检查是否有子窗口（WebView2 控件）
                try {
                    childHwnd := DllCall("GetWindow", "Ptr", testGui.Hwnd, "UInt", 5, "Ptr")  ; GW_CHILD = 5
                    if childHwnd {
                        Log("✓ WebView2 控件已创建")
                        break
                    }
                }
            }
        }
    }
    
    ; 6. 测试完成
    Log("`n[6/7] 清理测试窗口...")
    try testGui.Destroy()
    Log("✓ 测试窗口已关闭")
    
    ; 7. 总结
    Log("`n[7/7] 诊断总结")
    Log(StrRepeat("=", 60))
    if testSuccess {
        Log("✓ WebView2 基础测试通过！")
        Log("  如果剪贴板面板仍然黑屏，问题可能在于:")
        Log("  1. HTML 文件加载失败")
        Log("  2. JavaScript 执行错误")
        Log("  3. 文件路径编码问题（包含非 ASCII 字符）")
        Log("`n  建议:")
        Log("  - 打开剪贴板面板后按 F12 打开开发者工具")
        Log("  - 查看 Console 标签是否有错误")
        Log("  - 检查 Network 标签文件是否加载成功")
    } else {
        Log("✗ WebView2 测试失败！")
        Log("  可能的原因:")
        Log("  1. WebView2 运行时未安装或损坏")
        Log("  2. 系统权限问题")
        Log("  3. 与其他软件冲突")
        Log("`n  解决方案:")
        Log("  1. 下载并安装 WebView2 运行时:")
        Log("     https://go.microsoft.com/fwlink/p/?LinkId=2124703")
        Log("  2. 以管理员身份运行脚本")
        Log("  3. 重启电脑后再试")
    }
    Log(StrRepeat("=", 60))
    Log("`n诊断完成！")
}

WebView2Created(wv2Ctrl) {
    Log("  ✓ WebView2 回调函数被调用")
    try {
        coreWV2 := wv2Ctrl.CoreWebView2
        Log("  ✓ CoreWebView2 对象已创建")
        
        ; 尝试加载测试页面
        testHtml := '<html><head><meta charset="UTF-8"></head><body style="background:#0f0;color:#000;font-size:24px;padding:50px;text-align:center;"><h1>✓ WebView2 工作正常！</h1><p>如果你能看到绿色背景，说明 WebView2 基本功能正常。</p></body></html>'
        coreWV2.NavigateToString(testHtml)
        Log("  ✓ 测试页面已加载（绿色背景）")
    } catch as err {
        Log("  ✗ WebView2 初始化失败: " . err.Message)
    }
}

Log(msg) {
    global OutputEdit
    OutputEdit.Value .= msg . "`n"
    ; 滚动到底部
    try {
        SendMessage(0x0115, 7, 0, OutputEdit.Hwnd)  ; WM_VSCROLL, SB_BOTTOM
    }
}

; 字符串重复函数
StrRepeat(char, count) {
    result := ""
    Loop count
        result .= char
    return result
}
