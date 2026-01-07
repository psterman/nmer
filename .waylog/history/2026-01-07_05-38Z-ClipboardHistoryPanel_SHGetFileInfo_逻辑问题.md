# ClipboardHistoryPanel SHGetFileInfo 逻辑问题
_Exported on 01/07/2026 at 13:42:13 GMT+8 from Cursor via WayLog_


**User**

[12468] ClipboardHistoryPanel: 未找到图片路径，Content=SHGetFileInfo, DataType=Text
目前的逻辑可能还在尝试用处理“图片数据”的方式去处理“图标句柄”。在 Windows 中，SHGetFileInfo 返回的是系统图标列表的索引（Index），而不是一个可以直接显示的图片文件路径。

---


**Cursor**

检查 `ClipboardHistoryPanel` 中对 `SHGetFileInfo` 返回值的处理逻辑。



检查代码中对 `IconPath` 的处理，确认是否存在将其当作图片路径的错误用法。



检查 `GetImagePathFromRowData` 函数，确认是否错误地将 `Content` 字段中的 "SHGetFileInfo" 当作图片路径处理：

---


**User**

要调用 ImagePut 或 Gdip 的函数，将图片数据渲染到该窗口的 HDC 或 Pic 控件中。
Token 校验： 在使用任何 GDI+ 函数前，必须先调用 Gdip_Startup()。如果 Token 获取失败，后续所有绘图操作都会失效。

图像句柄： 如果你尝试通过 HBITMAP 加载图片，必须确保图片文件路径 HistoryImagePreviewCurrentPath 是有效的。如果路径指向的是数据库中的二进制流（BLOB）而没有先写入临时文件，Gui.Add("Pic") 将无法直接读取。

---


**Cursor**

检查代码中 GDI+ 的初始化和图片预览的实现：



检查数据库中的图片存储方式，并修复 GDI+ 初始化和图片渲染问题：

---


**User**

Error: Unexpected "Else"

	---- C:\Users\pster\Desktop\小c\modules\ClipboardHistoryPanel.ahk
	1458: }
	1459: }
▶	1459: Else

---


**Cursor**

检查第1459行附近的代码，定位语法错误：



查看更大的上下文以理解代码结构：



修复代码结构错误：验证代码被错误地放在了 else 块内。调整结构：

---


**User**

Error: Unexpected "Else"

	---- C:\Users\pster\Desktop\小c\modules\ClipboardHistoryPanel.ahk
	2130: }
	2131: }
▶	2131: Else

---


**Cursor**

检查第2131行附近的代码：



查看更大的上下文以理解代码结构：

---
