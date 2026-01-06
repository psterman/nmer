# Clipboard.ahk listview 数据获取失败
_Exported on 01/06/2026 at 12:02:31 GMT+8 from Cursor via WayLog_


**User**

CLIPBOARD.AHK的lilstview无法获取用户复制的数据，请检查数据库和监听方案

---


**Cursor**

检查数据库和监听方案。先查看相关文件。



检查数据库初始化和数据加载逻辑：



检查数据库连接和监听器注册，并查看是否有调试日志：

---


**User**

Error: Parameter #1 of FileGetSize requires a String, but received a VarRef.

	038: {
	039: AddDiagnosis("✓ Clipboard.db 存在: " . dbPath)
▶	041: FileGetSize(&fileSize, dbPath)Error: This global variable has not been assigned a value.

Specifically: fileSize

	039: AddDiagnosis("✓ Clipboard.db 存在: " . dbPath)
	041: FileGetSize(&fileSize, dbPath)
▶	042: AddDiagnosis("  文件大小: " . fileSize . " 字节")

解决以上两个问题，请检查为什么clipboardhistorypanel的输入框数据为什么无法匹配listview的数据

---


**Cursor**

修复诊断脚本的问题，并检查 ClipboardHistoryPanel 的搜索匹配问题。



修复这些问题：



修复触发器问题，并检查搜索匹配逻辑：



修复触发器问题，并检查搜索匹配逻辑：

---


**User**

用户在clipboardhistorypanel的输入框输入1，却无法匹配下方的剪贴板数据，请检查逻辑

---


**Cursor**

检查搜索逻辑，重点排查输入 "1" 无法匹配数据的原因：



检查并修复搜索逻辑。FTS5 对单个字符（如 "1"）的前缀匹配可能不生效。修复中：



修复搜索逻辑：FTS5 对单个字符（如 "1"）的前缀匹配可能无效。改为对短关键词使用 LIKE，对长关键词使用 FTS5，并同时搜索多个字段。

---
