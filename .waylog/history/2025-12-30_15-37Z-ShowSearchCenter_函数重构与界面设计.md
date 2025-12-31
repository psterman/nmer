# ShowSearchCenter 函数重构与界面设计
_Exported on 12/31/2025 at 07:49:27 GMT+8 from Cursor via WayLog_


**User**

重构 ShowSearchCenter 函数。激活方式是capslock+G
结构设计：创建一个无边框 GUI输入框。输入框的正上方设计一个名为 CategoryBar 的区域，用于渲染原语音面板的所有分类（AI、搜索、视频、图书、学术等）。
数据迁移：将语音搜索面板中 SearchEngines 数组里的分类提取出来，以横向标签的形式排列在顶部。每个标签对应一个领域，存放原来设定的多个搜索引擎
默认状态：初始状态焦点在输入框，一旦用户capslock+w向上切换，视觉上高亮左边第一个“AI 分区”。用户可以capslock+d和+w可以切换分类，

---


**Cursor**

查找 `ShowSearchCenter` 的当前实现以及语音搜索面板和 `SearchEngines` 的结构。















查找 CapsLock+G 的绑定以及相关的导航处理代码：







查看 CapsLock 快捷键绑定的相关代码：



开始重构。先检查 CapsLock+G 的绑定，并查看相关全局变量定义：



开始重构。先添加 CapsLock+G 快捷键绑定，然后重构 ShowSearchCenter 函数。



重构 `ShowSearchCenter` 函数，并添加必要的辅助函数和快捷键绑定。



重构 `ShowSearchCenter` 函数，并添加必要的辅助函数：



修复分类按钮的位置计算，并检查需要更新的相关函数：



修复分类按钮的位置计算问题：



检查 ESC 键处理，确保可以关闭搜索中心窗口，并确认所有功能正常：



添加 ESC 键关闭搜索中心窗口的功能：



已完成重构。检查是否有遗漏或需要改进的地方：



已完成 `ShowSearchCenter` 的重构。总结如下：

## 完成的功能

1. **无边框 GUI**：移除了标题栏和关闭按钮，创建了无边框窗口
2. **CategoryBar 区域**：在输入框上方创建了分类标签栏，从语音搜索面板提取分类数据（AI、搜索、视频、图书、学术等），横向排列
3. **导航逻辑**：
   - 初始状态焦点在输入框
   - CapsLock+W：从输入框向上切换到分类栏（高亮第一个分类）
   - 在分类栏时，CapsLock+W 向上切换分类，CapsLock+D 向右切换分类
   - CapsLock+S：从分类栏切换到输入框
   - ESC：关闭搜索中心窗口
4. **快捷键绑定**：添加了 CapsLock+G 快捷键来激活搜索中心

## 主要变更

- 重构了 `ShowSearchCenter()` 函数，使用无边框设计
- 添加了 `GetSearchCenterCategories()` 函数，从语音搜索面板提取分类
- 更新了 `SwitchSearchCenterCategory()` 函数来处理分类切换
- 更新了 `UpdateSearchCenterHighlight()` 函数来高亮当前激活的分类
- 修改了键盘导航逻辑，支持在输入框和分类栏之间切换

代码已通过语法检查，无错误。

---


**User**

Warning: This global variable appears to never be assigned a value.

Specifically: SearchCenterCurrentGroup

	19395: }
	19406: SearchGroups := [ {Name: "AI 智搜", Engines: ["DeepSeek", "Claude"], URLs: Map("DeepSeek", "https://chat.deepseek.com/?q={query}", "Claude", "https://claude.ai/chat?q={query}")}, {Name: "常用搜索", Engines: ["百度", "谷歌"], URLs: Map("百度", "https://www.baidu.com/s?wd={query}", "谷歌", "https://www.google.com/search?q={query}")}, {Name: "社交媒体", Engines: ["B站", "小红书"], URLs: Map("B站", "https://search.bilibili.com/all?keyword={query}", "小红书", "https://www.xiaohongshu.com/search_result?keyword={query}")} ]
▶	19413: If (SearchCenterCurrentGroup < 0 || SearchCenterCurrentGroup >= SearchGroups.Length)

---
