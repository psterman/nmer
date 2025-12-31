# Invalid usage error
_Exported on 12/31/2025 at 07:50:05 GMT+8 from Cursor via WayLog_


**User**

Error: Invalid usage.

Line:	9268

---


**Cursor**

Checking line 9268 to identify the issue.



Checking how `GetCapsLockState` is defined and how `#HotIf` is used elsewhere:



Checking the function definition and the other `#HotIf` usage:



In AutoHotkey v2, `#HotIf` requires function calls with parentheses. Fixing both occurrences:



Fixed the "Invalid usage" error. In AutoHotkey v2, `#HotIf` requires function calls with parentheses.

**Fixed:**
- Line 9268: Changed `#HotIf GetCapsLockState` to `#HotIf GetCapsLockState()`
- Line 9477: Changed `#HotIf GetCapsLockState && GetPanelVisibleState` to `#HotIf GetCapsLockState() && GetPanelVisibleState()`

The script should now run without the "Invalid usage" error. The `#HotIf` directive now correctly calls the functions with parentheses as required by AutoHotkey v2 syntax.

---


**User**

Error: Invalid usage.

Line:	9268

---


**Cursor**

Checking the current state of line 9268:



Checking other `#HotIf` usages and the AutoHotkey version to identify the issue:



Checking the function definition and whether it's accessible at that point:



Trying a different syntax. In AutoHotkey v2, `#HotIf` may require an expression. Checking the exact error context and trying an alternative:



Checking if the function needs to be defined differently or if there's a scope issue. Trying an expression-based approach:



Trying wrapping the function call in parentheses or using an expression. Checking if the function definition needs adjustment:



Wrapped the function calls in parentheses to make them expressions, which is required in AutoHotkey v2 for `#HotIf`.

**Changes made:**
- Line 9268: Changed `#HotIf GetCapsLockState()` to `#HotIf (GetCapsLockState())`
- Line 9477: Changed `#HotIf GetCapsLockState() && GetPanelVisibleState()` to `#HotIf (GetCapsLockState() && GetPanelVisibleState())`

In AutoHotkey v2, `#HotIf` requires expressions to be wrapped in parentheses. This should resolve the "Invalid usage" error. Test the script again.

---


**User**

Error: Invalid usage.

Line:	9268

---


**Cursor**

Checking AutoHotkey v2 `#HotIf` syntax and verifying the function definition:



Trying a different approach: using an expression with `GetKeyState` directly or checking if the function needs to be referenced differently:



Trying a direct expression using the variable and `GetKeyState` instead of a function call:



Updating the second `#HotIf` to use a direct expression:



Updated both `#HotIf` directives to use direct expressions instead of function calls. In AutoHotkey v2, `#HotIf` requires expressions, and direct variable references are more reliable than custom functions that use `global`.

**Changes made:**
- **Line 9268**: Changed from `#HotIf (GetCapsLockState())` to `#HotIf (CapsLock || GetKeyState("CapsLock", "P"))`
- **Line 9477**: Changed from `#HotIf (GetCapsLockState() && GetPanelVisibleState())` to `#HotIf ((CapsLock || GetKeyState("CapsLock", "P")) && PanelVisible)`

These expressions check:
1. The `CapsLock` variable state OR the physical CapsLock key state
2. The `PanelVisible` variable state

This should resolve the "Invalid usage" error. The script should now work correctly.

---
