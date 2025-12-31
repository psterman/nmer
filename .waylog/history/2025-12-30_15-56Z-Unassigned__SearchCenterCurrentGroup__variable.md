# Unassigned `SearchCenterCurrentGroup` variable
_Exported on 12/31/2025 at 07:49:27 GMT+8 from Cursor via WayLog_


**User**

Warning: This global variable appears to never be assigned a value.

Specifically: SearchCenterCurrentGroup

	19395: }
	19406: SearchGroups := [ {Name: "AI 智搜", Engines: ["DeepSeek", "Claude"], URLs: Map("DeepSeek", "https://chat.deepseek.com/?q={query}", "Claude", "https://claude.ai/chat?q={query}")}, {Name: "常用搜索", Engines: ["百度", "谷歌"], URLs: Map("百度", "https://www.baidu.com/s?wd={query}", "谷歌", "https://www.google.com/search?q={query}")}, {Name: "社交媒体", Engines: ["B站", "小红书"], URLs: Map("B站", "https://search.bilibili.com/all?keyword={query}", "小红书", "https://www.xiaohongshu.com/search_result?keyword={query}")} ]
▶	19413: If (SearchCenterCurrentGroup < 0 || SearchCenterCurrentGroup >= SearchGroups.Length)

---


**Cursor**

检查 `SearchCenterCurrentGroup` 的使用情况，定位未赋值问题。



查看函数完整上下文，了解 `SearchCenterCurrentGroup` 的初始化位置：



搜索搜索中心窗口的创建代码，查找 `SearchCenterCurrentGroup` 的初始化位置：



查看搜索中心窗口的创建代码，确认是否应初始化 `SearchCenterCurrentGroup`：



查看 `ShowSearchCenter` 函数，确认搜索组的处理逻辑：



`SearchCenterCurrentGroup` 被使用但未初始化。在全局变量声明处初始化它。修复中：



在全局变量声明处初始化 `SearchCenterCurrentGroup`：



检查是否还有其他问题：



已修复。在全局变量声明部分添加了 `SearchCenterCurrentGroup` 的初始化：

```146:146:CursorHelper (1).ahk
global SearchCenterCurrentGroup := 0  ; 当前选中的搜索组索引（0-based）
```

该变量默认值为 `0`（第一个搜索组），与 `SearchCenterCurrentCategory` 的初始化方式一致。警告应已消失，代码可正常使用该变量。

---


**User**

现在的showsearchcenter的多个分类中没有加载对应的搜索一群图标，下方也解释这段代码的核心逻辑、输入输出、关键函数作用，用新手能懂的语言，标注易错点

以下是选中的代码：
```
        TabName := "CapsLockC"

```

---
