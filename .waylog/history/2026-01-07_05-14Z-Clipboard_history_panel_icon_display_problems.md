# Clipboard history panel icon display problems
_Exported on 01/07/2026 at 13:18:13 GMT+8 from Cursor via WayLog_


**User**

clipboardhistorypanel图标没有加载
排查清单
没有启用 +IconSmall 样式： 创建 ListView 时必须包含这个样式：MainGui.Add("ListView", "... +IconSmall", ...)。

没有指定 Icon 参数： 在 ListView.Add 时，第一个参数必须是 "Icon" . N。

索引偏移： SHGetFileInfo 返回的索引是从 0 开始的，而 AHK 的 IconN 参数是从 1 开始的，所以代码中必须是 iconIdx + 1。

列宽问题： 确保你的图标列（第二列）宽度不为 0。建议设为 24。

---


**Cursor**

检查 `ClipboardHistoryPanel.ahk` 中与图标加载相关的代码。



检查代码，按排查清单修复图标加载问题。



修复图标加载问题：
1. 添加 `+IconSmall` 样式
2. 确保 Icon 参数正确传递
3. 验证索引偏移和列宽



修复：在创建 ListView 时添加 `+IconSmall` 样式。

---
