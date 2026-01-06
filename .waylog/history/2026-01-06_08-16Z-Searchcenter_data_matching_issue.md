# Searchcenter data matching issue
_Exported on 01/06/2026 at 16:20:33 GMT+8 from Cursor via WayLog_


**User**

修改搜索逻辑后，searchcenter的输入框中的文本无法匹配到任何数据了，请找出错误，确保everything，剪贴板，提示词模板，配置项的数据都能混排并且能与搜索框中的文本匹配

---


**Cursor**

检查 SearchCenter 的搜索逻辑，定位输入框文本无法匹配数据的原因。先查看相关代码。



查找 SearchCenter 的主文件，检查搜索逻辑实现：



查看主文件中的搜索逻辑实现：



查找 SearchCenter 输入框的 Change 事件处理和 DebouncedSearchCenter 函数：



查看 DebouncedSearchCenter 函数的完整实现：



继续查看 DebouncedSearchCenter 函数的剩余部分：



检查各个搜索函数的实现，重点查看匹配逻辑：

---


**User**

Error: Expected a Number but got an empty string.

	21962: TimeI := Results[i].HasProp("Timestamp") ? Results[i].Timestamp : Results[i].Time
	21963: TimeJ := Results[j].HasProp("Timestamp") ? Results[j].Timestamp : Results[j].Time
▶	21965: If (TimeJ > TimeI)
Error: The control is destroyed.

	21737: }
	21740: GlobalSearchEngine.ReleaseOldStatement()
▶	21742: Keyword := SearchCenterSearchEdit.Value

---
