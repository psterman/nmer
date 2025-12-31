# Global reserved word error
_Exported on 12/31/2025 at 12:36:24 GMT+8 from Cursor via WayLog_


**User**

Error: The following reserved word must not be used as a variable name:
"global"

	19497: SearchCenterSearchEdit.OnEvent("Change", ExecuteSearchCenterSearch)
	19499: {
▶	19499: Return  ( global SearchCenterActiveArea, SearchCenterActiveArea := "input", UpdateSearchCenterHighlight(), SwitchToChineseIMEForSearchCenter() )

---


**Cursor**

查看相关代码上下文，定位问题。



问题在于箭头函数中误用了 `global`。在 AutoHotkey v2 中，`global` 是保留字，不能在参数列表中使用。应在函数体内使用 `global` 语句。修复中：



修复语法错误：在 AutoHotkey v2 中，`global` 不能在箭头函数的参数列表中使用。改为在函数体内声明 `global`。

---


**User**

Error: Missing "propertyname:" in object literal.

	19497: SearchCenterSearchEdit.OnEvent("Change", ExecuteSearchCenterSearch)
	19499: {
▶	19499: Return  { global SearchCenterActiveArea SearchCenterActiveArea := "input" UpdateSearchCenterHighlight() SwitchToChineseIMEForSearchCenter() }
	19499: }

---


**Cursor**

检查错误并查看周围的代码上下文，确认正确的语法：



查看其他类似代码的用法：

---


**User**

Error: Missing "propertyname:" in object literal.

	19497: SearchCenterSearchEdit.OnEvent("Change", ExecuteSearchCenterSearch)
	19499: {
▶	19499: Return  { SearchCenterActiveArea := "input" UpdateSearchCenterHighlight() SwitchToChineseIMEForSearchCenter() }

---


**Cursor**

检查 AutoHotkey v2 中箭头函数的多语句语法，并查看项目中其他类似用法：



第 19523 行使用了 `(*) => (...)` 语法（圆括号和逗号）。改用相同语法，并移除 `global` 声明：

---


**User**

用户在searchcenter输入相关关键词后，无法用上下方向键激活上方搜索引擎列表，也不能激活光标在下方listview中进行选择？

---


**Cursor**

检查 SearchCenter 的键盘事件处理，特别是方向键逻辑：

---


**User**

解释这段代码的核心逻辑、输入输出、关键函数作用，用新手能懂的语言，标注易错点11

---


**User**

请还原个searchcenter里的各个标签里的搜索引擎图标

---


**Cursor**

查找 SearchCenter 中搜索引擎图标的显示逻辑：

---


**User**

1/请明确三个区域的方向键定义：
a 图标操作区域（上方向是切换搜索引擎区域的功能，左右是横向切换搜索引擎功能，下方向键则是切换焦点到输入框）
b输入框操作区域时，（上方向是切换到搜索引擎区域，左右正常的方向键，下方向键则是切换下方的listview区域）
c操作到图标区域时，如果往下方向键时，则是往下选择列表区域，如果左右方向键则是上下翻页，如果是上键方向键分为两种情况，如果光标在listview的列表的最上一栏时，则切换到输入框，如果是其他位置，则是往上方向键
确保capslock+w/s/a/d也支持以上同样的方向键选择

---
