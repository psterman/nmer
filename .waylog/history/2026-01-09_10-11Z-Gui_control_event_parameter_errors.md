# Gui control event parameter errors
_Exported on 01/09/2026 at 18:12:22 GMT+8 from Cursor via WayLog_


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


**Cursor**

查看相关代码，定位问题。







查看相关代码段：



在 AutoHotkey v2 中，`Text` 控件不支持 `MouseMove` 和 `MouseLeave`。改用 GUI 级别的鼠标事件处理悬停效果。查看完整的函数上下文：



修复：`Text` 控件不支持 `MouseMove` 和 `MouseLeave`。改用 GUI 级别的鼠标事件处理悬停效果。

---


**User**

Error: Parameter #1 of Gui.Prototype.OnEvent is invalid.

Specifically: MouseMove

	3475: ItemText.OnEvent("Click", (*) => Item.Action.Call())
	3476: }
▶	3479: TrayMenuGUI.OnEvent("MouseMove", TrayMenuMouseMove)
Error: Parameter #1 of Gui.Prototype.OnEvent is invalid.

Specifically: MouseLeave

	3476: }
	3479: TrayMenuGUI.OnEvent("MouseMove", TrayMenuMouseMove)
▶	3480: TrayMenuGUI.OnEvent("MouseLeave", TrayMenuMouseLeave)

---


**Cursor**

GUI 对象也不支持 `MouseMove` 和 `MouseLeave`。改用定时器定期检查鼠标位置，或使用支持鼠标事件的控件。查看代码以确定最佳方案：



改用定时器定期检查鼠标位置，实现悬停效果：



移除 GUI 级别的鼠标事件，改用定时器检查鼠标位置：



修改鼠标位置检查函数，使其可通过定时器调用，并查看菜单关闭逻辑：



查看菜单关闭函数，并修改鼠标位置检查函数：



修改鼠标位置检查函数，使其可通过定时器调用，并整合鼠标离开的逻辑：



在菜单关闭时停止鼠标位置检查定时器：



查找所有关闭菜单的位置，确保停止鼠标位置检查定时器：



查找所有关闭菜单的函数，更新它们以停止鼠标位置检查定时器：



更新所有关闭菜单的函数，添加停止鼠标位置检查定时器：



批量更新这些函数，在关闭菜单时停止鼠标位置检查定时器：



检查语法错误：



## 修复说明

**问题原因：**
在 AutoHotkey v2 中，GUI 对象和 `Text` 控件都不支持 `MouseMove` 和 `MouseLeave` 事件。

**解决方案：**
1. 移除了 GUI 级别的事件绑定（第 3479-3480 行）
2. 使用定时器实现悬停效果：
   - 添加 `SetTimer(CheckTrayMenuMousePosition, 50)` 每 50ms 检查一次鼠标位置
   - 创建 `CheckTrayMenuMousePosition` 函数，通过定时器调用
3. 整合了鼠标离开逻辑：
   - 在 `CheckTrayMenuMousePosition` 中检查鼠标是否在菜单窗口内
   - 如果不在窗口内或不在菜单项上，自动清除悬停效果
4. 在所有关闭菜单的地方停止定时器：
   - `CloseTrayMenuIfClickedOutside`
   - `ToggleFloatingToolbarFromMenu`
   - `ShowSearchCenterFromMenu`
   - `ShowClipboardFromMenu`
   - `ShowConfigFromMenu`
   - `ShowCustomTrayMenu`（重新创建菜单时）

现在代码应可正常运行，悬停效果通过定时器检查鼠标位置实现，不再依赖不支持的事件。

---


**User**

彻底删除 脚本中所有类似 A_TrayMenu.Add(...) 的代码，只使用 Gui 构建的菜单。

---
