# Everything service integration and startup
_Exported on 01/09/2026 at 08:01:08 GMT+8 from Cursor via WayLog_


**User**

@Everything搜索集成问题分析.md 解决这些问题，确保每次启动脚本时也启动Everything服务

---


**Cursor**

查找相关代码文件，定位 Everything 搜索集成的问题。



读取相关代码文件，了解当前实现：

---


**User**

参考searchcenter，分析剪贴板管理的搜索的能力

---


**Cursor**

查看 SearchCenter 和剪贴板管理的搜索实现，进行对比分析：



查看 ClipboardManagement 的搜索实现：



查看 SearchCenter 的完整搜索实现：

---


**User**

@剪贴板管理搜索能力分析.md 修复ClipboardManagement的能力，并且新增剪贴板（用户ctrl+c和capslock+c的数据），本地文件（everything匹配的文件），提示词（软件设置中的提示词模板）作为三个分类标签，方便用户单独过滤

---


**Cursor**

查看相关代码，了解当前实现：



查看 SearchPromptTemplates 的实现和分类按钮的创建代码：



创建任务列表并开始实现：



修改分类标签定义，添加三个新分类：

---


**User**

原来的分类（全部、CapsLock+C、文本、代码、链接、图片）不要改

---


**User**

原来的分类（CapsLock+C、文本、代码、链接、图片）不要改，确保每一个分类可以精准匹配数据

---
