# 剪贴板入库监控工具使用说明

## 功能概述

`ClipboardMonitor.ahk` 是一个独立的调试监控 GUI，用于实时验证 `ClipboardFTS5.ahk` 的入库精准度和稳定性。

## 主要功能

1. **实时看板**
   - 显示最新一条记录的 SourceApp（来源进程）
   - 显示 DataType（识别出的类型：文本/链接/代码/图片）
   - 显示 CharCount（字数）
   - 入库状态灯（绿色=正常，红色=错误）

2. **内容预览**
   - 实时显示最新入库内容的前 150 个字符

3. **统计面板**
   - 今日捕获总数
   - 图片数
   - 入库失败次数
   - 防抖过滤次数

4. **操作日志**
   - 实时滚动显示数据库操作结果
   - 记录成功/失败信息
   - 记录防抖过滤事件

5. **环境自检**
   - 检测 sqlite3.dll 是否存在
   - 检测 Clipboard.db 写入权限
   - 检测数据库连接状态
   - 检测表结构
   - 检测 WAL 模式

6. **视觉反馈**
   - 入库成功时窗口短暂闪烁绿色
   - 即使监控窗口未打开，也会显示托盘提示
   - 支持自动显示监控窗口（入库时自动打开）

## 使用方法

### 方法一：在主脚本中集成（推荐）

在 `CursorHelper.ahk` 中添加：

```ahk
; 在文件顶部包含监控器
#Include modules\ClipboardMonitor.ahk

; 在初始化部分添加
InitClipboardMonitor()  ; 不自动显示窗口
; 或
InitClipboardMonitor(true)  ; 自动显示窗口（推荐用于调试）

; 修改 ProcessClipboardChange 函数，使用带监控的版本
; 将原来的：
;   SaveToClipboardFTS5(content, SourceApp)
; 改为：
;   SaveToClipboardFTS5WithMonitor(content, SourceApp)

; 将原来的：
;   CaptureClipboardImageToFTS5(SourceApp)
; 改为：
;   CaptureClipboardImageToFTS5WithMonitor(SourceApp)

; 添加热键打开监控窗口（例如：CapsLock+M）
; #HotIf GetCapsLockState()
; m::ShowClipboardMonitor()
; #HotIf
```

### 方法二：独立运行

创建一个测试脚本 `test_monitor.ahk`：

```ahk
#Requires AutoHotkey v2.0
#Include modules\ClipboardMonitor.ahk

; 初始化
InitClipboardFTS5DB()
InitClipboardMonitor()

; 显示监控窗口
ShowClipboardMonitor()

; 保持脚本运行
Persistent
```

## 集成到现有流程

### 修改 ProcessClipboardChange 函数

在 `CursorHelper.ahk` 的 `ProcessClipboardChange` 函数中，将：

```ahk
if (ClipboardFTS5DB && ClipboardFTS5DB != 0) {
    if (Type = 1) {
        SaveToClipboardFTS5(content, SourceApp)
    } else if (Type = 2) {
        CaptureClipboardImageToFTS5(SourceApp)
    }
}
```

改为：

```ahk
if (ClipboardFTS5DB && ClipboardFTS5DB != 0) {
    if (Type = 1) {
        SaveToClipboardFTS5WithMonitor(content, SourceApp)
    } else if (Type = 2) {
        CaptureClipboardImageToFTS5WithMonitor(SourceApp)
    }
}
```

### 记录防抖过滤

在 `OnClipboardChangeHandler` 函数中，当检测到防抖过滤时，添加：

```ahk
; 在防抖定时器设置后，如果监控器可见，记录过滤
if (MonitorIsVisible) {
    RecordDebounceFiltered()
}
```

或者更简单的方式，在 `ProcessClipboardChange` 开始时检查：

```ahk
ProcessClipboardChange() {
    global ClipboardChangeDebounceTimer
    
    ; 如果防抖定时器被清除，说明有重复请求被过滤
    if (ClipboardChangeDebounceTimer = 0 && MonitorIsVisible) {
        ; 这个逻辑需要根据实际情况调整
    }
    
    ; ... 其余代码
}
```

## API 函数

### 显示/隐藏监控窗口

```ahk
ShowClipboardMonitor()      ; 显示监控窗口
HideClipboardMonitor()      ; 隐藏监控窗口
ToggleClipboardMonitor()    ; 切换显示/隐藏
```

### 记录入库事件

```ahk
RecordInsertSuccess(sourceApp, dataType, charCount, content)  ; 记录成功（会自动显示托盘提示或更新GUI）
RecordInsertFail(errorMsg, errorCode := "")                    ; 记录失败（会自动显示托盘提示或更新GUI）
RecordDebounceFiltered()                                       ; 记录防抖过滤
```

### 自动显示选项

```ahk
; 启用自动显示（入库时自动打开监控窗口）
SetMonitorAutoShow(true)
InitClipboardMonitor(true)  ; 或直接在初始化时启用

; 禁用自动显示
SetMonitorAutoShow(false)
```

### 增强的入库函数

```ahk
SaveToClipboardFTS5WithMonitor(content, SourceApp)           ; 带监控的文本入库
CaptureClipboardImageToFTS5WithMonitor(SourceApp)             ; 带监控的图片入库
```

## 注意事项

1. 监控器会自动刷新数据（每2秒一次）
2. 日志最多保留50行，超出会自动删除最旧的
3. 状态灯会在入库成功时变绿，失败时变红
4. 窗口闪烁效果持续200ms
5. 今日统计基于数据库中的 Timestamp 字段
6. **即使监控窗口未打开，入库成功/失败也会显示托盘提示**
7. 可以设置自动显示模式，入库时自动打开监控窗口

## 故障排查

如果监控器无法正常工作：

1. 检查数据库是否已初始化
2. 运行"环境自检"按钮查看详细信息
3. 查看日志区域了解具体错误
4. 确保 `ClipboardFTS5.ahk` 已正确包含

## 性能影响

- 监控器每2秒刷新一次统计数据
- 入库操作会触发一次数据刷新（延迟500ms）
- 对入库性能影响极小（<1ms）
