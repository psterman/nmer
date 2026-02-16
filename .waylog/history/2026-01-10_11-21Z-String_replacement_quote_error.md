# String replacement quote error
_Exported on 01/10/2026 at 19:22:26 GMT+8 from Cursor via WayLog_


**User**

Error: Missing space or operator before this.

Specifically: "", "&quot;")

	24437: EscapedText := StrReplace(EscapedText, "<", "&lt;")
	24438: EscapedText := StrReplace(EscapedText, ">", "&gt;")
▶	24439: EscapedText := StrReplace(EscapedText, """", "&quot;")

---


**Cursor**

检查相关文件以了解上下文：



查看第24439行附近的代码：



在 AutoHotkey 中，双引号字符串内要用 `""` 表示一个双引号字符，所以应将 `"""` 改为 `""""`。修复：



更正：应为 `""""`（两个双引号表示一个双引号字符）。重新修复：



修复为 `""""`（4 个引号）。

---
