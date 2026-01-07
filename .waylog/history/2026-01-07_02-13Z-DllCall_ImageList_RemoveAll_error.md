# DllCall ImageList_RemoveAll error
_Exported on 01/07/2026 at 10:14:13 GMT+8 from Cursor via WayLog_


**User**

Error: Call to nonexistent function.

	---- C:\Users\pster\Desktop\小c\modules\ClipboardHistoryPanel.ahk
	688: If (HistoryImageList && HistoryImageList != 0)
	688: {
▶	690: DllCall("ImageList_RemoveAll", "Ptr", HistoryImageList)

---


**Cursor**

检查 `ClipboardHistoryPanel.ahk` 中 `ImageList_RemoveAll` 的调用，定位错误原因。



第 690 行的 `ImageList_RemoveAll` 缺少 DLL 名称。第 1474 行使用了 `Comctl32\ImageList_AddIcon`，说明需要指定 DLL。检查其他相关调用：

---


**User**

Error: Call to nonexistent function.

Specifically: ImageList_RemoveAll

	---- C:\Users\pster\Desktop\小c\modules\ClipboardHistoryPanel.ahk
	688: If (HistoryImageList && HistoryImageList != 0)
	688: {
▶	690: DllCall("Comctl32\ImageList_RemoveAll", "Ptr", HistoryImageList)

---


**Cursor**

检查 Windows API 文档和代码中 ImageList 的处理方式，确认正确的清空方法。

---
