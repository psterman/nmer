# SysGet function parameter error
_Exported on 01/09/2026 at 19:29:24 GMT+8 from Cursor via WayLog_


**User**

Error: Too many parameters passed to function.

Specifically: SysGet

	3522: MenuItems.Push({Text: GetText("exit_menu"), Action: ExitFromMenu})
	3525: MenuHeight := MenuItems.Length * MenuItemHeight + Padding * 2
▶	3528: SysGet(&ScreenWidth, 78)

---


**Cursor**

检查 `SysGet` 的用法和定义，定位参数过多的原因。

---


**User**

我希望不要通过“显示菜单”，直接右键单击托盘图标显示gui自定义菜单

---


**Cursor**

查找托盘图标右键点击的处理代码，并修改为直接显示自定义 GUI 菜单。



查看托盘菜单相关代码：



修改代码，使右键点击托盘图标直接显示自定义 GUI 菜单，跳过系统菜单。



修改代码，使右键点击托盘图标直接显示自定义 GUI 菜单：

---


**User**

1. 彻底禁用原生托盘菜单
在脚本的初始化部分（通常在 TraySetIcon 附近），添加以下代码。这会清空并禁用 AHK 默认的右键响应。

AutoHotkey

; 放在脚本开头
A_TrayMenu.Delete() ; 删除所有默认菜单项
A_TrayMenu.ClickCount := 0 ; 禁用默认的双击行为
2. 接管托盘消息通知 (OnMessage)
当鼠标在托盘图标上点击时，Windows 会发送一个 0x404 消息。我们需要通过监听这个消息，手动判断是左键还是右键，然后立即显示你的 GUI。

在 CursorHelper (1).ahk 中加入此函数：

AutoHotkey

; 监听托盘消息
OnMessage(0x404, TRAY_ICON_MESSAGE)

TRAY_ICON_MESSAGE(wParam, lParam, msg, hwnd) {
    ; lParam 含义: 
    ; 0x202 = 左键弹起 (WM_LBUTTONUP)
    ; 0x205 = 右键弹起 (WM_RBUTTONUP)
    if (lParam = 0x205 || lParam = 0x202) { 
        ShowTrayMenuGUI() ; 调用你显示自定义菜单的函数
        return 0 ; 拦截消息，不让系统处理
    }
}
3. 优化 ShowTrayMenuGUI 的弹出位置
为了让自定义菜单看起来像原生菜单一样从图标上方弹出，需要动态获取鼠标坐标。

修改你的显示函数：

AutoHotkey

ShowTrayMenuGUI() {
    global TrayMenuGUI
    
    ; 1. 必须先获取鼠标位置
    CoordMode "Mouse", "Screen"
    MouseGetPos(&mX, &mY)
    
    ; 2. 简单的位置偏移（假设菜单宽 160，高约 200）
    ; 这样菜单会出现在鼠标点击位置的上方，避免被任务栏遮挡
    posX := mX - 80
    posY := mY - 220 
    
    ; 3. 显示并激活，确保点击别处能自动消失
    TrayMenuGUI.Show("x" . posX . " y" . posY)
    WinActivate(TrayMenuGUI.Hwnd) 
}

---


**Cursor**

查看代码结构，准备实现：禁用原生托盘菜单、通过 OnMessage 监听托盘消息、优化菜单弹出位置。



查看 `ShowCustomTrayMenu` 函数的完整代码：



实现：禁用原生托盘菜单、通过 OnMessage 监听托盘消息、优化菜单弹出位置。

---


**User**

1、弹出菜单的字体从白色改成橙色
2、菜单一一对应命令：第一个：切换显示/隐藏悬浮工具栏，第二个：打开capslock+f，第三个：打开capslock+x,第四个：打开capslock+q，第五个：退出软件
3、双击托盘图标直接退出软件
4、每个选项，最左边加上一个橙色图形图标，material扁平化风格

---


**Cursor**

查看当前菜单代码和快捷键定义：



查找 CapsLock+f、CapsLock+x、CapsLock+q 对应的函数：







实现这些功能：



修改代码以实现这些功能：

---
