# FormatFileSize function conflict
_Exported on 01/07/2026 at 22:02:18 GMT+8 from Cursor via WayLog_


**User**

Error: This function declaration conflicts with an existing Func.

Text:	FormatFileSize
Line:	17007
File:	C:\Users\pster\Desktop\小c\CursorHelper (1).ahk

---


**Cursor**

查找 `FormatFileSize` 的所有定义，定位重复声明。



查看第 17007 行附近的代码，并搜索是否还有其他 `FormatFileSize` 定义：



搜索整个项目中的 `FormatFileSize` 定义：

---


**User**

剪贴板管理切换标签时，listview会有一个长时间的空白才会加载对应标签数据，但是@modules/ClipboardHistoryPanel.ahk 不会
我需要将剪贴板管理的页面中，将capslock+c的数据单独归类，点击capslock+c的标签只显示用户capslock+c的复制数据
我需要ClipboardHistoryPanel也有复制选中，删除选中，粘贴到cursor，清空全部，导出剪贴板，导入剪贴板的按钮

---


**Cursor**

查看相关代码，了解当前实现：



查看 ClipboardHistoryPanel.ahk 的结构和主文件中剪贴板管理的实现：

---
