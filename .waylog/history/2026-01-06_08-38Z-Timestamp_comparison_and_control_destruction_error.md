# Timestamp comparison and control destruction errors
_Exported on 01/06/2026 at 16:39:33 GMT+8 from Cursor via WayLog_


**User**

Error: Expected a Number but got an empty string.

	21962: TimeI := Results[i].HasProp("Timestamp") ? Results[i].Timestamp : Results[i].Time
	21963: TimeJ := Results[j].HasProp("Timestamp") ? Results[j].Timestamp : Results[j].Time
▶	21965: If (TimeJ > TimeI)
Error: The control is destroyed.

	21737: }
	21740: GlobalSearchEngine.ReleaseOldStatement()
▶	21742: Keyword := SearchCenterSearchEdit.Value

---


**Cursor**

查看相关代码上下文以定位问题。



查看更多上下文，了解这些变量的来源和控件定义：



修复这两个问题：
1. 时间戳比较：`TimeI` 或 `TimeJ` 可能为空，需要空值检查
2. 控件访问：`SearchCenterSearchEdit` 可能已被销毁，需要先检查控件是否存在



修复这两个问题：

---


**User**

Error: Expected a Number but got a String.

Specifically: 2026-01-06 16:40:39

	21980: Continue
	21981: }
▶	21984: If (TimeJ > TimeI)
Error: The control is destroyed.

	21745: Return
	21746: }
▶	21748: Keyword := SearchCenterSearchEdit.Value

---


**Cursor**

检查代码上下文，修复这两个问题：



修复这两个问题：
1. 时间戳比较：AHK 中字符串不能直接用 `>`，改用 `StrCompare()`。
2. 控件访问：添加 try-catch 保护。



修复这两个问题：

---


**User**

Error: The control is destroyed.

	21624: SearchCenterAreaIndicator.SetFont("s13 Bold c" . HighlightColor, "Segoe UI")
	21626: {
▶	21626: Return  ( SearchCenterAreaIndicator.SetFont("s11 Bold c" . UI_Colors.BtnPrimary, "Segoe UI") )

---


**Cursor**

查看相关代码上下文：



查看完整函数上下文：



修复 SetTimer 回调中的控件访问问题：在回调中添加控件存在性检查，并在设置 SetTimer 前检查控件是否存在。

---


**User**

Error: Expected a Number but got an empty string.

	22065: TimeI := Results[i].HasProp("Timestamp") ? Results[i].Timestamp : Results[i].Time
	22066: TimeJ := Results[j].HasProp("Timestamp") ? Results[j].Timestamp : Results[j].Time
▶	22068: If (TimeJ > TimeI)

---
