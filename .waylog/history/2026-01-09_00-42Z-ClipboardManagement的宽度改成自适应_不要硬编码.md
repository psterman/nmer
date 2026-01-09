# ClipboardManagement的宽度改成自适应，不要硬编码
_Exported on 01/09/2026 at 08:45:09 GMT+8 from Cursor via WayLog_


**User**

ClipboardManagement的宽度改成自适应，不要硬编码
我需要clipboardmanagerment有全部、CapsLock+C、文本、代码、链接、图片、剪贴板，本地文件，提示词这些标签，可以精准过滤对应标签的数据
搜索框在上，标签在下
点击标签会有高亮，并且标签中的listview匹配对应的数据

---


**Cursor**

查找 ClipboardManagement 相关代码文件。







检查主脚本中实际使用的文件：



检查主脚本如何引用 ClipboardGUI：



修改 `ClipboardGUI_FTS5.ahk`：调整布局（搜索框在上，标签在下），移除硬编码宽度，改为自适应。



修改代码：调整布局（搜索框在上，标签在下），移除硬编码宽度，改为自适应。

---
