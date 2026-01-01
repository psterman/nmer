# Cursor快捷操作listview数据匹配
_Exported on 01/01/2026 at 10:25:55 GMT+8 from Cursor via WayLog_


**User**

cursor快捷操作的listview的中没有匹配输入框的数据，请参考全域搜索的匹配逻辑，检查问题出在哪里

---


**Cursor**

查看相关代码，定位 cursor 快捷操作的 listview 匹配问题。先查找相关实现：



查找 cursor 快捷操作面板的输入框和 listview 相关代码：



查看 cursor 快捷操作面板的搜索函数和全域搜索的匹配逻辑：



读取这两个函数的完整实现进行对比：



继续查看完整的函数实现，特别关注搜索匹配逻辑：



查找 SearchGlobalView 和 SearchAllDataSources 的实现：



查看 SearchGlobalView 的完整实现，了解其返回的数据结构：



对比两个函数的实现，确认问题。查看是否有全局变量访问的问题：



对比两个函数，发现关键问题：`DebouncedCursorPanelSearch` 中缺少对 `CursorPanelSearchEdit` 的全局变量声明。检查完整的函数实现：



问题：在 `DebouncedCursorPanelSearch` 中，对 `CursorPanelSearchEdit` 的全局变量声明方式可能存在问题。参考全域搜索的实现，对比两个函数使用全局变量的方式：

---
