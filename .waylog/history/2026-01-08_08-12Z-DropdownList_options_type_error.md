# DropdownList options type error
_Exported on 01/08/2026 at 16:12:59 GMT+8 from Cursor via WayLog_


**User**

Error: Expected an Array but got a String.

Specifically: 10|20|30|50|100|200|500

	21417: DropdownOptions := "10|20|30|50|100|200|500"
	21418: DropdownDefaultIndex := 1
▶	21420: SearchCenterResultLimitDropdown := GuiID_SearchCenter.Add("DropDownList", "x" . DropdownX . " y" . DropdownY . " w" . DropdownWidth . " h" . DropdownHeight . " Background" . InputBgColor . " c" . InputTextColor . " Choose" . DropdownDefaultIndex . " vSearchCenterResultLimitDropdown", DropdownOptions)
	Error: This value of type "String" has no method named "SetFont".

	21418: DropdownDefaultIndex := 1
	21420: SearchCenterResultLimitDropdown := GuiID_SearchCenter.Add("DropDownList", "x" . DropdownX . " y" . DropdownY . " w" . DropdownWidth . " h" . DropdownHeight . " Background" . InputBgColor . " c" . InputTextColor . " Choose" . DropdownDefaultIndex . " vSearchCenterResultLimitDropdown", DropdownOptions)
▶	21428: SearchCenterResultLimitDropdown.SetFont("s14", "Segoe UI")
	Error: This value of type "String" has no method named "OnEvent".

	21420: SearchCenterResultLimitDropdown := GuiID_SearchCenter.Add("DropDownList", "x" . DropdownX . " y" . DropdownY . " w" . DropdownWidth . " h" . DropdownHeight . " Background" . InputBgColor . " c" . InputTextColor . " Choose" . DropdownDefaultIndex . " vSearchCenterResultLimitDropdown", DropdownOptions)
	21428: SearchCenterResultLimitDropdown.SetFont("s14", "Segoe UI")
▶	21429: SearchCenterResultLimitDropdown.OnEvent("Change", OnSearchCenterResultLimitChange)

---


**Cursor**

问题在于 `DropdownOptions` 是字符串，但 AutoHotkey 的 `DropDownList` 需要数组。查找相关代码以修复：







代码中第 21417 行已使用数组格式。检查是否有其他地方将 `DropdownOptions` 定义为字符串：



代码中第 21417 行已使用数组格式。检查该区域代码，确保格式正确：



代码中第 21417 行已使用数组格式。如果仍报错，可能是脚本未重新加载。检查并确认代码格式正确：



代码已使用数组格式。若仍报错，可能是脚本未重新加载，或存在其他版本。根据错误信息，确保代码格式正确。检查是否有其他问题：



代码中第 21417 行已使用数组格式：

```21417:21417:CursorHelper (1).ahk
    DropdownOptions := ["10", "20", "30", "50", "100", "200", "500"]
```

如果仍报错，可能是脚本未重新加载。请：
1. 保存文件
2. 重新加载脚本（在 AutoHotkey 中右键托盘图标选择 "Reload Script"，或关闭后重新运行）

如果错误仍存在，可能是缓存或旧版本。请确认：
- 是否修改了文件但未保存
- 是否运行了其他版本的脚本文件

代码格式是正确的，AutoHotkey v2 的 `DropDownList` 需要使用数组而不是管道符分隔的字符串。重新加载脚本后应可正常运行。

---


**User**

Error: Expected an Array but got a String.

Specifically: 10|20|30|50||100|200|500

	---- C:\Users\pster\Desktop\小c\modules\ClipboardHistoryPanel.ahk
	161: DropdownHeight := SearchBoxHeight
	165: DropdownOptionsStr := "10|20|30|50||100|200|500"
▶	167: HistoryResultLimitDropdown := GuiID_ClipboardHistory.Add("DropDownList", "x" . DropdownX . " y" . DropdownY . " w" . DropdownWidth . " h" . DropdownHeight . " Background" . HistoryColors.InputBg . " c" . HistoryColors.Text . " vHistoryResultLimitDropdown", DropdownOptionsStr)
修改后，软件重启了，DropdownOptions 依然还是只有一个m默认选项50

---


**Cursor**

检查 `modules\ClipboardHistoryPanel.ahk` 中的相关代码：



修复 `modules\ClipboardHistoryPanel.ahk`：将字符串格式改为数组，并使用 `Choose` 设置默认选项。



修复：将字符串格式改为数组，并使用 `Choose` 设置默认选项。



检查是否有语法错误：

---


**User**

Error: This value of type "Integer" has no property named "Text".

	21921: }
	21924: {
▶	21928: selectedText := SearchCenterResultLimitDropdown.TextError: The control is destroyed.

	21932: SearchCenterEverythingLimit := 10
	21933: }
▶	21936: If (SearchCenterSearchEdit && SearchCenterSearchEdit.Value != "")Error: This value of type "Integer" has no property named "Text".

	---- C:\Users\pster\Desktop\小c\modules\ClipboardHistoryPanel.ahk
	1604: }
	1607: {
▶	1611: selectedText := HistoryResultLimitDropdown.Text

---


**Cursor**

在 AutoHotkey v2 中，下拉菜单的 `Text` 属性可能不可用，应使用 `Value` 获取索引，再从数组获取对应文本。检查相关代码：



查看下拉菜单的选项数组定义，以便从索引获取文本：



修复：在 AutoHotkey v2 中，`DropDownList` 应使用 `Value` 获取索引，再从数组获取文本。先定义选项数组为常量，再更新事件处理函数：

---
