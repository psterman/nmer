# Empty string in time comparison
_Exported on 01/06/2026 at 16:50:33 GMT+8 from Cursor via WayLog_


**User**

Error: Expected a Number but got an empty string.

	22065: TimeI := Results[i].HasProp("Timestamp") ? Results[i].Timestamp : Results[i].Time
	22066: TimeJ := Results[j].HasProp("Timestamp") ? Results[j].Timestamp : Results[j].Time
▶	22068: If (TimeJ > TimeI)

---


**Cursor**

这个错误表明在比较 `TimeJ > TimeI` 时，其中一个或两个变量是空字符串而不是数字。让我分析一下代码逻辑：

我看到代码中有两个排序逻辑，第一个（21988行）已经修复了空字符串问题，但第二个（22065行）没有修复。让我修复第二个排序逻辑：

修复完成！主要修改了第22065-22068行的排序逻辑，添加了：

1. **空字符串检查**：在比较前检查 `TimeI` 和 `TimeJ` 是否为空
2. **空值处理逻辑**：如果 `TimeI` 为空而 `TimeJ` 不为空，则交换位置（让空值排在后面）
3. **使用 StrCompare**：用字符串比较函数替代直接比较，避免类型错误

这样修改后，即使 `Results[i].Time` 或 `Results[i].Timestamp` 返回空字符串，也不会触发 "Expected a Number but got an

---
