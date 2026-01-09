# CursorHelper 搜索刷新函数调整
_Exported on 01/09/2026 at 12:40:13 GMT+8 from Cursor via WayLog_


**User**

请按照以下提示修改 CursorHelper (1).ahk 中的搜索刷新函数：

取消标签页限制：确保搜索框输入变化时，无论处于哪个标签页，都能触发数据库查询 。
动态构建 WHERE 子句：

关键词部分：始终添加 (Content LIKE '%关键词%') 。
标签部分：只有当 ClipboardCurrentCategory != "" 时，才添加 AND DataType = '分类名'。如果分类为空，则不添加这部分 。

---


**Cursor**

查找并修改搜索刷新函数。



搜索搜索刷新函数：



读取搜索刷新函数的具体内容：



查找 `RefreshClipboardListView` 函数，实际的数据库查询应该在这里：







继续读取 WHERE 子句的构建部分：



查看其他标签页的 WHERE 子句构建逻辑：



修改搜索刷新函数：移除标签页限制，并调整 WHERE 子句构建逻辑。



修改 `RefreshClipboardListView` 函数，移除标签页限制，并调整 WHERE 子句构建逻辑：

---
