# 请修改 RefreshHistoryData 函数中的 SQL 构建逻辑，以支持“全域搜索”：
_Exported on 01/09/2026 at 12:01:12 GMT+8 from Cursor via WayLog_


**User**

请修改 RefreshHistoryData 函数中的 SQL 构建逻辑，以支持“全域搜索”：

1. 检查标签判断逻辑：定位到处理 HistorySelectedTag 的代码块。确保它被包裹在 if (HistorySelectedTag != "") 的条件判断中。  
2. 实现逻辑： * 当 HistorySelectedTag 不为空时：按照现有逻辑，向 whereConditions 数组中 Push 对应的 DataType 过滤条件（如 DataType = 'Text'）。 * 当 HistorySelectedTag 为空时（默认状态）：不要 向 whereConditions 添加任何关于 DataType 的条件。这样生成的 SQL 语句将只包含关键词搜索部分，从而实现对所有类型数据的匹配。
3. 关键词匹配增强：确保在关键词搜索部分（keyword != ""），SQL 条件是针对 Content 或 SourceApp 等核心字段进行 LIKE 或 MATCH 检索，而不受具体标签的限制。 
4. SQL 组装：在最后组装 WHERE 子句时，使用 AND 连接 whereConditions 数组中的所有成员。如果数组为空（既没搜关键词也没选标签），则不添加 WHERE 子句，直接查询全表。

---


**Cursor**

查找 `RefreshHistoryData` 函数及其 SQL 构建逻辑：







查看 `RefreshHistoryData` 函数的实现：

---
