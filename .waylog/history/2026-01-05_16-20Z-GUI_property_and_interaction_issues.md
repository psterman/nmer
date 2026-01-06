# GUI property and interaction issues
_Exported on 01/06/2026 at 00:22:04 GMT+8 from Cursor via WayLog_


**User**

1/Error: This value of type "Gui" has no property named "ClientWidth".

	21289: Height := SearchCenterMinHeight
	21290: }
▶	21293: If (Width != GuiObj.ClientWidth || Height != GuiObj.ClientHeight)
2/输入框无法输入
3/调试面板激活后，按钮点击没有反应

---


**Cursor**

正在查找相关代码文件，定位这些问题。



读取相关代码文件以了解上下文：



继续查看相关代码：



查看输入框创建和调试按钮事件处理代码：



查看调试按钮事件处理函数的定义：



创建修复任务列表并开始修复：



修复这三个问题：



检查调试面板按钮的显示和事件绑定问题：



检查输入框和调试按钮的启用状态，并查看是否有其他问题：



检查窗口显示和焦点设置，确保输入框可输入：

---


**User**

无法拉伸searchcenter的窗口了，请把调试面板解释这段代码的核心逻辑、输入输出、关键函数作用，用新手能懂的语言，标注易错点

以下是选中的代码：
```
12
```

---


**User**

确保窗口能够拖动，现在无法拉伸searchcenter的窗口大小了，把调试面板功能优化，确保每一步都有对应提示

---


**Cursor**

检查窗口大小调整功能，并优化调试面板的提示信息。



检查窗口大小调整和拖动相关代码：



查看 `OnSearchCenterNCHitTest` 函数，并优化调试面板提示：

---


**User**

把调试面板独立出来，随着capslock+f一起启动

---
