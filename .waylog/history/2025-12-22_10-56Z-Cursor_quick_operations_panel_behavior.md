# Cursor quick operations panel behavior
_Exported on 12/31/2025 at 07:50:08 GMT+8 from Cursor via WayLog_


**User**

1当用户鼠标在cursor快捷操作面板的按钮浮动时，页面最下方的说明文字动态说明
2/cursor快捷操作面板的置顶按钮没有将面板强行长期置顶于cursor之上，避免用户离开capslock就消失，直到用户关闭或者取消置顶为止

---


**Cursor**

查看相关代码，了解当前实现：


继续查找面板创建和置顶相关代码：


查看面板隐藏和置顶相关代码：


查看 HideCursorPanel 和 HoverBtnWithAnimation 函数：


查看 CapsLock 释放时的处理逻辑：


实现这两个功能：
1. 鼠标悬停时动态更新说明文字
2. 置顶时，即使离开 CapsLock 也不自动隐藏面板


实现这两个功能：


添加更新说明文字的辅助函数，并修改 CapsLock 释放逻辑：


检查 AutoHotkey v2 中按钮控件的鼠标事件支持，并查找其他可能隐藏面板的地方：


查看代码中如何处理鼠标悬停，因为 Button 控件可能不支持 MouseMove 事件：


改用 WM_MOUSEMOVE 消息实现鼠标悬停更新说明文字：


修改代码，使用 WM_MOUSEMOVE 消息处理鼠标悬停：


添加全局变量声明：


检查面板关闭时是否清除相关变量，并验证所有修改：


在 HideCursorPanel 函数中清除相关变量：


检查 HideCursorPanel 函数的完整内容：


修改已完成。总结如下：

## 已完成的修改

### 1. 鼠标悬停动态更新说明文字
- 在创建按钮时为每个按钮添加了 `ButtonDesc` 属性存储说明文字
- 修改了 `WM_MOUSEMOVE` 函数，检测鼠标是否在 Cursor 面板按钮上，并更新说明文字
- 修改了 `CheckMouseLeave` 函数，鼠标离开按钮时恢复默认说明
- 添加了 `UpdateCursorPanelDesc` 和 `RestoreDefaultCursorPanelDesc` 辅助函数
- 添加了 `LastCursorPanelButton` 全局变量跟踪当前悬停的按钮

### 2. 置顶功能增强
- 修改了 `CapsLockUp` 函数：当面板置顶（`CursorPanelAlwaysOnTop` 为 true）时，释放 CapsLock 不会自动隐藏面板
- 在 `HideCursorPanel` 函数中清除 `LastCursorPanelButton` 变量

## 功能说明

1. 鼠标悬停：当鼠标悬停在 Cursor 快捷操作面板的按钮上时，页面最下方的说明文字会动态更新为该按钮的说明
2. 置顶功能：点击置顶按钮后，面板会保持显示，即使释放 CapsLock 也不会自动隐藏，直到用户手动关闭面板或取消置顶

代码已通过语法检查，可以测试使用。

---
