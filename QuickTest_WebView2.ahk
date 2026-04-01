; 快速测试 WebView2
#Requires AutoHotkey v2.0
#Include lib\WebView2.ahk

MsgBox("正在创建 WebView2 测试窗口...`n`n如果看到绿色窗口，说明 WebView2 正常。`n如果黑屏或报错，说明 WebView2 有问题。", "WebView2 快速测试", "Iconi T3")

TestGui := Gui("+Resize", "WebView2 快速测试")
TestGui.Show("w800 h600")

try {
    WebView2.create(TestGui.Hwnd, WV2_Ready)
    MsgBox("WebView2.create() 调用成功！`n请等待窗口加载...", "成功", "Iconi T2")
} catch as err {
    MsgBox("WebView2.create() 失败！`n`n错误: " . err.Message . "`n`n可能的原因:`n1. WebView2 运行时未安装`n2. 需要以管理员身份运行`n3. 系统权限问题`n`n请下载并安装 WebView2 运行时:`nhttps://go.microsoft.com/fwlink/p/?LinkId=2124703", "错误", "IconX")
    ExitApp
}

WV2_Ready(ctrl) {
    try {
        wv2 := ctrl.CoreWebView2
        
        ; 加载绿色测试页面
        testHtml := '
        (
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="UTF-8">
            <title>WebView2 Test</title>
        </head>
        <body style="margin:0;padding:50px;background:linear-gradient(135deg, #667eea 0%, #764ba2 100%);color:#fff;font-family:Arial;text-align:center;">
            <h1 style="font-size:48px;margin-bottom:20px;">✓ WebView2 工作正常！</h1>
            <p style="font-size:24px;margin-bottom:30px;">如果你能看到这个紫色渐变背景，说明 WebView2 渲染功能正常。</p>
            <div style="background:rgba(255,255,255,0.2);padding:30px;border-radius:10px;display:inline-block;">
                <p style="font-size:18px;margin:10px 0;">✓ HTML 加载成功</p>
                <p style="font-size:18px;margin:10px 0;">✓ CSS 渲染正常</p>
                <p id="js-test" style="font-size:18px;margin:10px 0;color:#ff6b6b;">✗ JavaScript 未运行</p>
            </div>
            <script>
                // 测试 JavaScript
                setTimeout(function() {
                    document.getElementById("js-test").style.color = "#51cf66";
                    document.getElementById("js-test").textContent = "✓ JavaScript 正常运行";
                }, 500);
            </script>
        </body>
        </html>
        )'
        
        wv2.NavigateToString(testHtml)
        
        ToolTip("WebView2 初始化成功！`n如果看到紫色渐变背景，说明功能正常。")
        SetTimer(() => ToolTip(), -3000)
        
    } catch as err {
        MsgBox("WebView2 初始化失败！`n`n错误: " . err.Message, "错误", "IconX")
    }
}
