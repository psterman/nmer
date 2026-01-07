# Local variable `IsFunc` warning
_Exported on 01/07/2026 at 13:35:13 GMT+8 from Cursor via WayLog_


**User**

Warning: This local variable appears to never be assigned a value.

Specifically: IsFunc

	---- C:\Users\pster\Desktop\小c\modules\ClipboardFTS5.ahk
	299: If (SourcePath = "" || !FileExist(SourcePath))
	299: {
▶	301: If (IsFunc("GetEverythingResults"))

---


**Cursor**

检查 `ClipboardFTS5.ahk` 中 `IsFunc` 的使用情况。



检查文件开头，确认变量声明和作用域：



查看第 301 行所在函数的完整上下文：



搜索文件中 `IsFunc` 的所有出现：

---
