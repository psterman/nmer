# ToggleFloatingToolbar function conflict
_Exported on 01/09/2026 at 17:54:20 GMT+8 from Cursor via WayLog_


**User**

Error: This function declaration conflicts with an existing Func.

Text:	ToggleFloatingToolbar
Line:	3306

---


**Cursor**

查找 `ToggleFloatingToolbar` 的定义，检查是否有重复声明。



发现 `ToggleFloatingToolbar` 在两个文件中都有定义。查看这两个文件以确定如何处理：



检查 `CursorHelper (1).ahk` 中该函数的使用情况：



已确认：`CursorHelper (1).ahk` 已包含 `modules\FloatingToolbar.ahk`，但又在第3306行重复定义了 `ToggleFloatingToolbar`。删除重复定义，保留模块中的版本。查看调用处是否需要额外处理：



`CursorHelper (1).ahk` 中的版本包含关闭菜单的逻辑。删除重复定义，创建一个包装函数处理菜单关闭：



检查菜单如何处理 Action：



查找菜单项点击处理逻辑：



查找菜单创建和点击处理代码：



查看菜单创建和点击处理代码：



菜单项通过 `Item.Action.Call()` 调用。删除重复定义，创建一个包装函数处理菜单关闭逻辑：

---


**User**

Error: Invalid parameter(s).

	3245: {
	3246: A_TrayMenu.Delete()
▶	3248: A_TrayMenu.Add("", ShowCustomTrayMenu)

---


**Cursor**

检查 `A_TrayMenu.Add` 的调用：







检查 AutoHotkey v2 中 `A_TrayMenu.Add` 的正确用法：



`A_TrayMenu.Add()` 的第一个参数不能为空字符串。查看代码意图，改用 `A_TrayMenu.OnMenu()` 拦截菜单显示，或添加一个占位菜单项：



在 AutoHotkey v2 中，`A_TrayMenu.Add()` 的第一个参数不能为空。改用 `A_TrayMenu.OnMenu()` 拦截菜单显示，以显示自定义菜单：



检查语法是否正确：



改用占位菜单项，名称不为空：

---


**User**

现在托盘无法打开菜单了

---


**Cursor**

检查 `OnMenu` 的使用方式，并修复菜单显示问题：

---


**User**

Error: Parameter #1 of Gui.Control.Prototype.OnEvent is invalid.

Specifically: MouseMove

	3421: ItemText.OnEvent("Click", (*) => Item.Action.Call())
	3424: ItemIndex := Index
▶	3425: ItemBg.OnEvent("MouseMove", TrayMenuItemHover.Bind(ItemIndex))
Error: Parameter #1 of Gui.Control.Prototype.OnEvent is invalid.

Specifically: MouseMove

	3424: ItemIndex := Index
	3425: ItemBg.OnEvent("MouseMove", TrayMenuItemHover.Bind(ItemIndex))
▶	3426: ItemText.OnEvent("MouseMove", TrayMenuItemHover.Bind(ItemIndex))Error: Parameter #1 of Gui.Control.Prototype.OnEvent is invalid.

Specifically: MouseLeave

	3425: ItemBg.OnEvent("MouseMove", TrayMenuItemHover.Bind(ItemIndex))
	3426: ItemText.OnEvent("MouseMove", TrayMenuItemHover.Bind(ItemIndex))
▶	3429: ItemBg.OnEvent("MouseLeave", TrayMenuItemLeave.Bind(ItemIndex))Error: Parameter #1 of Gui.Control.Prototype.OnEvent is invalid.

Specifically: MouseLeave

	3426: ItemText.OnEvent("MouseMove", TrayMenuItemHover.Bind(ItemIndex))
	3429: ItemBg.OnEvent("MouseLeave", TrayMenuItemLeave.Bind(ItemIndex))
▶	3430: ItemText.OnEvent("MouseLeave", TrayMenuItemLeave.Bind(ItemIndex))

---
