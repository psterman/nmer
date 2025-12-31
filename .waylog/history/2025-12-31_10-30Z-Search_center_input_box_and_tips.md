# Search center input box and tips
_Exported on 12/31/2025 at 18:34:27 GMT+8 from Cursor via WayLog_


**User**

2/capslock+g的searchcenter输入框的样式有问题，输入框内下方有黑边，参考material重构样式
3/在输入框下方的区域提供添加了操作提示的文本说明提示
显示当前区域名称（分类搜索/输入框/本地搜索）
显示当前区域的操作提示
显示轻提示：可以使用方向键或 CapsLock+WSAD 切换区域

---


**Cursor**

查找 searchcenter 相关代码，定位输入框样式和操作提示的实现位置。

---


**User**

有两个问题，激活searchcenter的输入框解释这段代码的核心逻辑、输入输出、关键函数作用，用新手能懂的语言，标注易错点

以下是选中的代码：
```
w

```

---


**User**

1/激活searchcenter的输入框下方有蓝色的底边，切换焦点会变黑色底边，我需要彻底去掉这个底边
2/我希望动画展示用户现在所在当前区域名称（分类搜索/输入框/本地搜索）
同时在输入框下方外围和listview区域之间的区域做一个文本提示：
显示当前区域的操作提示：您可以使用方向键或 CapsLock+WSAD 切换操作，向上实现向多个AI提问或者网络搜索，向下可以查看搜索本地提示词和剪贴板

---


**Cursor**

查看相关代码，定位并修复这两个问题：

---


**User**

交换 CapsLock + G 和 CapsLock + F:
由 CapsLock + F 全权负责激活 SearchCenter 窗口。
CapsLock + g唤起 “语音输入面板” 或 “旧版快捷面板” 
当 SearchCenter 窗口已激活时，按下 CapsLock + F 执行逻辑根据当前焦点区域分流：
搜索引擎 / 输入框区域：根据输入内容，一键并发跳转（Run）当前选中的搜索引擎组。
ListView 区域：将选中的本地结果（代码片段或 Prompt）直接粘贴（Paste）到 Cursor 窗口。

---
