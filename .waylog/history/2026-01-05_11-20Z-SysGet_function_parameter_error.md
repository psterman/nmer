# SysGet function parameter error
_Exported on 01/05/2026 at 19:21:01 GMT+8 from Cursor via WayLog_


**User**

Error: Too many parameters passed to function.

Specifically: SysGet

	---- C:\Users\pster\Desktop\小c\modules\FloatingToolbar.ahk
	047: If (FloatingToolbarWindowX = 0 && FloatingToolbarWindowY = 0)
	047: {
▶	049: SysGet(&ScreenWidth, 0)

---


**Cursor**

检查 `FloatingToolbar.ahk` 中 `SysGet` 的用法，修复参数错误。



在 AutoHotkey v2 中，`SysGet` 只接受一个参数并返回值，不再使用输出变量。修复这两处用法：



检查是否还有其他错误：



已修复。在 AutoHotkey v2 中，`SysGet` 的语法已更改：

**修复内容：**

1. **第 49-50 行**：将 `SysGet(&ScreenWidth, 0)` 和 `SysGet(&ScreenHeight, 1)` 改为：
   - `ScreenWidth := SysGet(0)`
   - `ScreenHeight := SysGet(1)`

2. **第 291-292 行**：同样修复了拖动处理中的 `SysGet` 调用。

在 AutoHotkey v2 中，`SysGet` 只接受一个参数（系统指标常量）并直接返回值，不再使用输出变量（`&` 语法）。现在代码应可正常运行。

---


**User**

Error: Parameter #1 of Gui.Control.Prototype.OnEvent is invalid.

Specifically: MouseMove

	---- C:\Users\pster\Desktop\小c\modules\FloatingToolbar.ahk
	160: button.OnEvent("Click", OnToolbarSettingsClick)
	161: }
▶	164: button.OnEvent("MouseMove", OnToolbarButtonHover.Bind(button, config["action"]))

---


**Cursor**

检查代码，修复按钮的 `MouseMove` 事件问题。在 AutoHotkey v2 中，按钮控件不支持 `MouseMove` 事件。



在 AutoHotkey v2 中，按钮控件不支持 `MouseMove` 和 `MouseLeave`。改用窗口级别的鼠标移动事件实现悬停效果：



查看悬停效果处理函数，然后修复：



移除按钮的 `MouseMove` 和 `MouseLeave` 事件，改用窗口级别的鼠标移动事件实现悬停效果：



修复代码：移除按钮的 `MouseMove` 和 `MouseLeave` 事件，改用窗口级别的鼠标移动事件实现悬停效果。



检查是否有语法错误：



已修复。主要改动：

1. **移除了按钮的 `MouseMove` 和 `MouseLeave` 事件**（第 164-165 行），因为 AutoHotkey v2 的按钮控件不支持这些事件。

2. **添加了全局变量**：
   - `FloatingToolbarButtons`：存储所有按钮的位置和引用

---


**User**

Error: Parameter #1 of Gui.Control.Prototype.OnEvent is invalid.

Specifically: MouseLeave

	---- C:\Users\pster\Desktop\小c\modules\FloatingToolbar.ahk
	161: }
	164: button.OnEvent("MouseMove", OnToolbarButtonHover.Bind(button, config["action"]))
▶	165: button.OnEvent("MouseLeave", OnToolbarButtonLeave.Bind(button))

---


**Cursor**

检查文件，确认是否仍有旧的代码：



检查按钮创建部分的完整代码：



搜索文件中是否仍有 `MouseMove` 或 `MouseLeave` 事件：



文件看起来已正确。错误可能来自缓存或旧版本。完整读取文件以确认：



文件内容看起来正确，已移除按钮的 `MouseMove` 和 `MouseLeave` 事件。错误可能来自 AutoHotkey 的缓存。检查是否有其他相关文件或备份：

---


**User**

Error: Parameter #1 of Gui.Control.Prototype.OnEvent is invalid.

Specifically: MouseMove

	---- C:\Users\pster\Desktop\小c\modules\FloatingToolbar.ahk
	180: FloatingToolbarGUI.OnEvent("ContextMenu", OnFloatingToolbarContextMenu)
	183: ToolbarBg.OnEvent("Click", OnToolbarBgClick)
▶	184: ToolbarBg.OnEvent("MouseMove", OnToolbarBgMouseMove)

---


**Cursor**

错误在 `ToolbarBg`（Text 控件）上，它可能也不支持 `MouseMove`。检查并修复：



移除 `ToolbarBg` 的 `MouseMove` 事件，并将拖动逻辑整合到窗口级别的 `MouseMove` 事件中：



移除 `ToolbarBg` 的 `MouseMove` 事件，并将拖动逻辑整合到窗口事件中：

---


**User**

Error: Parameter #1 of Gui.Prototype.OnEvent is invalid.

Specifically: MouseMove

	---- C:\Users\pster\Desktop\小c\modules\FloatingToolbar.ahk
	180: FloatingToolbarGUI.OnEvent("ContextMenu", OnFloatingToolbarContextMenu)
	183: ToolbarBg.OnEvent("Click", OnToolbarBgClick)
▶	186: FloatingToolbarGUI.OnEvent("MouseMove", OnFloatingToolbarMouseMove)
Error: Parameter #1 of Gui.Prototype.OnEvent is invalid.

Specifically: Move

	---- C:\Users\pster\Desktop\小c\modules\FloatingToolbar.ahk
	183: ToolbarBg.OnEvent("Click", OnToolbarBgClick)
	186: FloatingToolbarGUI.OnEvent("MouseMove", OnFloatingToolbarMouseMove)
▶	189: FloatingToolbarGUI.OnEvent("Move", OnFloatingToolbarMove)
Error: This local variable has not been assigned a value.
A global declaration inside the function may be required.

Specifically: FloatingToolbarWindowX

	---- C:\Users\pster\Desktop\小c\modules\FloatingToolbar.ahk
	043: }
	046: CreateFloatingToolbarGUI()
▶	049: If (FloatingToolbarWindowX = 0 && FloatingToolbarWindowY = 0)Error: This local variable has not been assigned a value.
A global declaration inside the function may be required.

Specifically: FloatingToolbarWindowX

	---- C:\Users\pster\Desktop\小c\modules\FloatingToolbar.ahk
	056: FloatingToolbarWindowY := ScreenHeight - 80
	057: }
▶	059: FloatingToolbarGUI.Show("x" . FloatingToolbarWindowX . " y" . FloatingToolbarWindowY . " w280 h50")

---


**Cursor**

修复这些问题：GUI 对象不支持 `MouseMove` 和 `Move` 事件，且需要声明全局变量。



修复这些问题：移除 GUI 的 `MouseMove` 和 `Move` 事件，改用定时器实现悬停效果，并修复全局变量声明。



检查语法错误：

---


**User**

Error: This function declaration conflicts with an existing Func.

Text:	CheckButtonHover
Line:	23875
File:	C:\Users\pster\Desktop\小c\CursorHelper (1).ahk

---


**Cursor**

`CheckButtonHover` 已在主文件中定义。重命名该函数以避免冲突：



重命名函数以避免冲突：

---


**User**

1、长按floatingtoolbar的按钮无法拖动，不能只能再边缘拖动
2、点击五个按钮无法激活对应的ahk窗口：
capslock+f，capslock+x，ctrl+shift+b后，再粘贴https://gemini.google.com/  加载，capslock+t，capslock+q
3、鼠标经过工具栏按钮有悬浮效果，点击有深色效果
4、增加一个favicon.ico图标在左方

---


**Cursor**

查看当前代码，逐一处理这些需求：



检查 favicon.ico 是否存在，然后逐一修复：

---
