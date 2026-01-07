# Clipboard history panel dynamic icons
_Exported on 01/07/2026 at 18:26:15 GMT+8 from Cursor via WayLog_


**User**

请修改我的 ClipboardHistoryPanel.ahk 代码，实现根据剪贴板内容（文件路径、文本、图片）动态显示 Windows 系统图标的功能。

具体修改点：

初始化挂载： 在 InitClipboardHistoryPanel 函数创建 HistoryListView 后，添加调用 SHGetFileInfo 获取系统小图标列表句柄的逻辑，并通过 SendMessage(0x1003, 1, hSysImageList, HistoryListView.Hwnd) 绑定。

列结构调整： 将 ListView 的列定义修改为 ["#", "", "内容", "时间"]（增加一个空标题列作为图标位），并设置第二列宽度为 24。

新增图标识别函数： 增加 GetSystemIconIndex(content) 函数：

使用 0x4011 标志（系统索引 + 虚拟属性 + 小图标），确保即使文件路径不存在也能根据后缀名（如 .html）获取图标。

识别逻辑：如果是路径则取路径图标；如果是图片条目则模拟 .png；否则模拟 .txt。

重构渲染循环： 在 RefreshHistoryList 循环中：

调用 GetSystemIconIndex 获取索引。

修复排布： 修改 HistoryListView.Add 语句为 HistoryListView.Add("Icon" . (idx + 1), index, "", item.content, item.time)。注意必须保留中间的 "" 占位符，防止内容覆盖图标列。

样式修复： 确保只使用 +Report 模式，不要使用 +IconSmall 样式以免变成网格视图。

---


**Cursor**

查看 `ClipboardHistoryPanel.ahk` 的代码结构：



检查代码结构，按需求修改：



按需求修改代码：



修改 `SetSystemImageList` 函数，确保正确绑定系统图标列表：



添加 `GetSystemIconIndex` 函数：

---
