# 叠加复制功能使用说明

## 功能概述

在 `ClipboardHistoryPanel.ahk` 中新增了"叠加复制"功能，允许用户通过快捷键将多段文本叠加复制，然后一次性粘贴所有内容。

## 功能特性

1. **叠加复制**：使用 `CapsLock + C` 捕获文本并存入数据库（DataType=Stack）
2. **叠加粘贴**：使用 `CapsLock + V` 一次性粘贴所有叠加内容并清空缓存
3. **视觉标识**：在剪贴板历史面板中，Stack 标签的条目会在内容列前缀显示红色圆点（🔴）
4. **独立记录**：叠加的每一段文字在剪贴板历史面板中都是独立可查的记录

## 集成方法

### 方法一：在主脚本中注册快捷键（推荐）

在主脚本文件（如 `CursorHelper (1).ahk`）中添加以下代码：

```ahk
; 在文件顶部包含 ClipboardHistoryPanel 模块
#Include modules\ClipboardHistoryPanel.ahk

; 在 #HotIf GetCapsLockState() 部分添加或修改快捷键处理
#HotIf GetCapsLockState()

; C 键叠加复制（如果主脚本中已有 CapsLock+C 处理，需要修改 HandleDynamicHotkey）
c:: {
    ; 调用叠加复制函数
    HandleStackCopy()
    ; 如果需要保留原有的 CapsLock+C 功能，可以在这里添加条件判断
}

; V 键叠加粘贴（如果主脚本中已有 CapsLock+V 处理，需要修改 HandleDynamicHotkey）
v:: {
    ; 调用叠加粘贴函数
    HandleStackPaste()
    ; 如果需要保留原有的 CapsLock+V 功能，可以在这里添加条件判断
}

#HotIf
```

### 方法二：修改 HandleDynamicHotkey 函数

如果主脚本使用 `HandleDynamicHotkey` 函数处理快捷键，可以在该函数中添加：

```ahk
HandleDynamicHotkey(PressedKey, ActionType) {
    ; ... 现有代码 ...
    
    switch ActionType {
        case "C":
            ; 叠加复制功能
            HandleStackCopy()
            return true
        case "V":
            ; 叠加粘贴功能
            HandleStackPaste()
            return true
        ; ... 其他 case ...
    }
}
```

## 使用方法

1. **叠加复制**：
   - 复制第一段文本（Ctrl+C）
   - 按 `CapsLock + C` 将文本添加到叠加列表
   - 复制第二段文本（Ctrl+C）
   - 按 `CapsLock + C` 将文本添加到叠加列表
   - 重复以上步骤，添加更多文本

2. **叠加粘贴**：
   - 按 `CapsLock + V` 一次性粘贴所有叠加内容
   - 所有叠加内容会用换行符连接后复制到剪贴板
   - 叠加列表会自动清空

3. **查看历史**：
   - 打开剪贴板历史面板（默认快捷键可能是 `CapsLock + X` 或其他）
   - 叠加复制的内容会显示红色圆点（🔴）标识
   - 每条叠加内容都是独立的记录，可以单独查看和复制

## 技术实现

### 全局变量

- `StackClipboardItems`：存储叠加复制的数据库记录ID列表

### 主要函数

- `HandleStackCopy()`：处理叠加复制，将剪贴板内容存入数据库（DataType=Stack）
- `HandleStackPaste()`：处理叠加粘贴，从数据库读取所有叠加内容并合并粘贴

### 数据库字段

- `DataType`：设置为 "Stack" 用于标识叠加复制的内容
- 每条叠加内容都会作为独立记录存储在数据库中

## 注意事项

1. 确保数据库已正确初始化（`InitClipboardFTS5DB()`）
2. 叠加复制功能依赖 `ClipboardFTS5.ahk` 模块中的 `SaveToClipboardFTS5()` 函数
3. 如果主脚本中已有 `CapsLock + C` 或 `CapsLock + V` 的处理逻辑，需要根据实际需求调整优先级或合并功能
4. 叠加列表存储在内存中，脚本重启后会清空（但数据库记录会保留）

## 示例代码

完整的主脚本集成示例：

```ahk
#Requires AutoHotkey v2.0

; 包含必要的模块
#Include modules\ClipboardFTS5.ahk
#Include modules\ClipboardHistoryPanel.ahk

; 初始化数据库
InitClipboardFTS5DB()

; 初始化剪贴板历史面板
InitClipboardHistoryPanel()

; 注册快捷键
#HotIf GetCapsLockState()

; 叠加复制
c:: {
    HandleStackCopy()
}

; 叠加粘贴
v:: {
    HandleStackPaste()
}

; 打开历史面板（示例）
x:: {
    ShowClipboardHistoryPanel()
}

#HotIf

; 保持脚本运行
Persistent
```

## 更新日志

- v1.0.0：初始版本
  - 实现叠加复制功能
  - 实现叠加粘贴功能
  - 添加 Stack 标签的视觉标识（红色圆点）
