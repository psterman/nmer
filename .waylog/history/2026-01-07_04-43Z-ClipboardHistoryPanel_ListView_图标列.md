# ClipboardHistoryPanel ListView 图标列
_Exported on 01/07/2026 at 13:02:13 GMT+8 from Cursor via WayLog_


**User**

请修改 ClipboardHistoryPanel.ahk，在 ListView 的第 1 列（序号）和第 2 列（内容）之间插入一个新的图标列。

使用 DllCall("shell32\SHGetFileInfoW", ...) 挂载 Windows 全局系统 ImageList 到 ListView。

编写一个 GetFileIconIndex 函数，利用 SHGFI_SYSICONINDEX 获取文件或后缀的图标索引。

在刷新列表循环中，先用 FileExist 或路径特征判断内容，如果是路径则提取对应图标，否则根据数据类型（图片/文本）赋予 .png 或 .txt 的系统默认图标。

确保图标列宽度固定（约 24 像素），且支持 AHK v2 语法。"

---


**Cursor**

查看 `ClipboardHistoryPanel.ahk` 的当前实现：



在 ListView 的第 1 列和第 2 列之间插入图标列，并挂载系统 ImageList。



修改代码，添加图标列：



添加设置系统 ImageList 的函数和获取文件图标索引的函数：

---


**User**

clipboardhistorypanel图标没有加载
排查清单
没有启用 +IconSmall 样式： 创建 ListView 时必须包含这个样式：MainGui.Add("ListView", "... +IconSmall", ...)。

没有指定 Icon 参数： 在 ListView.Add 时，第一个参数必须是 "Icon" . N。

索引偏移： SHGetFileInfo 返回的索引是从 0 开始的，而 AHK 的 IconN 参数是从 1 开始的，所以代码中必须是 iconIdx + 1。

列宽问题： 确保你的图标列（第二列）宽度不为 0。建议设为 24。

---


**Cursor**

按排查清单检查并修复图标加载问题：



修复这些问题：



检查并修复 Add 方法中的图标参数设置：

---
