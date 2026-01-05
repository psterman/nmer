# 剪贴板历史面板使用说明

## 功能概述

`ClipboardHistoryPanel.ahk` 是一个简洁的剪贴板历史查看器，可以显示所有复制过的数据，按时间倒序排列。

## 主要功能

1. **列表显示**
   - 显示所有复制过的内容
   - 按时间倒序排列（最新的在前）
   - 显示序号、内容预览、来源、类型、时间、字符数

2. **搜索过滤**
   - 实时搜索，输入关键词即时过滤
   - 支持内容全文搜索

3. **快速复制**
   - 双击列表项即可复制到剪贴板
   - 复制后自动刷新列表

4. **暗黑模式界面**
   - 现代化的暗黑主题
   - 可调整大小的窗口

## 使用方法

### 方法一：在主脚本中集成

在 `CursorHelper.ahk` 中添加：

```ahk
; 在文件顶部包含面板
#Include modules\ClipboardHistoryPanel.ahk

; 在初始化部分添加
InitClipboardHistoryPanel()

; 添加热键打开面板（例如：CapsLock+H）
#HotIf GetCapsLockState()
h::ShowClipboardHistoryPanel()  ; CapsLock+H 打开历史面板
#HotIf
```

### 方法二：独立运行

创建一个测试脚本 `test_history.ahk`：

```ahk
#Requires AutoHotkey v2.0
#Include modules\ClipboardHistoryPanel.ahk

; 初始化
InitClipboardFTS5DB()
InitClipboardHistoryPanel()

; 显示面板
ShowClipboardHistoryPanel()

; 保持脚本运行
Persistent
```

## API 函数

### 显示/隐藏面板

```ahk
ShowClipboardHistoryPanel()      ; 显示面板
HideClipboardHistoryPanel()      ; 隐藏面板
ToggleClipboardHistoryPanel()    ; 切换显示/隐藏
```

### 刷新数据

```ahk
RefreshHistoryData()              ; 刷新所有数据
RefreshHistoryData(keyword)       ; 刷新并搜索关键词
```

## 界面说明

### 列说明

- **序号**: 显示顺序（1, 2, 3...）
- **内容预览**: 内容的前80个字符
- **来源**: 复制来源的应用名称
- **类型**: 内容类型（Text/Code/Link/Email/Image）
- **时间**: 复制时间（HH:mm:ss）
- **字符数**: 内容字符数

### 操作说明

- **搜索**: 在顶部搜索框输入关键词，实时过滤
- **复制**: 双击列表项，内容自动复制到剪贴板
- **调整大小**: 拖动窗口边缘调整大小

## 注意事项

1. 面板最多显示1000条记录（按时间倒序）
2. 内容预览最多显示80个字符，超出部分显示"..."
3. 搜索支持全文匹配，不区分大小写
4. 双击复制后会自动刷新列表

## 性能优化

- 使用 `GetTable` 方法批量读取数据
- 暂停重绘以提高加载性能
- 限制显示数量避免界面卡顿

## 与现有功能的关系

- 与 `ClipboardGUI_FTS5.ahk` 独立，可以同时使用
- 使用相同的数据库（Clipboard.db）
- 数据自动同步，无需额外配置
