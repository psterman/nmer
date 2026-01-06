# Everything_IsServiceRunning function error
_Exported on 01/06/2026 at 19:07:34 GMT+8 from Cursor via WayLog_


**Cursor**

这个错误表明代码尝试调用 `Everything_IsServiceRunning` 函数，但该函数在 Everything DLL 中不存在。让我先查看相关代码文件来理解上下文。

让我检查 Everything DLL 中实际可用的函数：

让我查看 Everything DLL 的文档或检查是否有其他相关文件来了解正确的函数名称：让我检查 lib 目录中的 Everything DLL 文件和相关文档：

让我搜索 Everything SDK 的正确函数名称：

---


**User**

Error: Call to nonexistent function.

Specifically: Everything_IsServiceRunning

	086: Return 0
	087: }
▶	090: If !DllCall(evDll "\Everything_IsServiceRunning")

---


**Cursor**

查找代码中 `Everything_IsServiceRunning` 的调用位置，并检查 Everything DLL 的使用情况。

---
