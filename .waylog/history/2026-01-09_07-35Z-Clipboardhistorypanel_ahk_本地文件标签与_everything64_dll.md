# Clipboardhistorypanel.ahk 本地文件标签与 everything64.dll 数据
_Exported on 01/09/2026 at 15:38:15 GMT+8 from Cursor via WayLog_


**User**

请修改clipboardhistorypanel.ahk,增加一个本地文件的标签，对接everything64.dll数据

---


**Cursor**

查看相关文件，了解当前实现和 everything64.dll 的使用方式。



查看 ClipboardHistoryPanel.ahk 的标签系统实现：



查看搜索逻辑和 Everything 集成部分：



查看 Everything 搜索函数的实现：



添加“本地文件”标签，对接 Everything 搜索。创建初始任务列表：



修改代码，添加“本地文件”标签：



在标签过滤逻辑中添加对 LocalFile 的处理：



修改 Everything 搜索逻辑，使其在选择“本地文件”标签时也能工作：

---
