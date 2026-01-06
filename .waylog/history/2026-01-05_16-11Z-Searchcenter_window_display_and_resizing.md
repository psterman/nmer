# Searchcenter window display and resizing
_Exported on 01/06/2026 at 00:12:04 GMT+8 from Cursor via WayLog_


**User**

看不到listview，也看不到调试面板，确保窗口各个模块可以完整展示，searchcenter窗口可以拉伸变大缩小，窗口可以移动

---


**Cursor**

检查 SearchCenter 窗口的实现，确保所有模块可见，并支持窗口移动和调整大小。



查找包含 SearchCenter 窗口实现的 AutoHotkey 脚本文件：



查找主要的 AutoHotkey 脚本文件：



检查主要的脚本文件，查找 SearchCenter 的实现：



搜索 SearchCenter 相关代码：

---


**User**

Error: This value of type "Gui" has no property named "ClientWidth".

	21289: Height := SearchCenterMinHeight
	21290: }
▶	21293: If (Width != GuiObj.ClientWidth || Height != GuiObj.ClientHeight)

---
