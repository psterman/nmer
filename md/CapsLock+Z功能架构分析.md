# CapsLock+Z 语音输入功能架构分析

## 整体架构 ASCII 图

```
┌─────────────────────────────────────────────────────────────────┐
│                    CapsLock+Z 语音输入功能架构                      │
└─────────────────────────────────────────────────────────────────┘

用户操作流程：
┌─────────────┐
│ 按下CapsLock │
└──────┬──────┘
       │
       ▼
┌──────────────────────────────────────────────────────────────┐
│  CapsLockDown() - 检测CapsLock按下                             │
│  • 设置 CapsLock = true                                       │
│  • 设置 CapsLock2 = true (标记未使用功能)                      │
│  • 启动定时器：长按 CapsLockHoldTimeSeconds 秒后显示面板       │
└──────┬───────────────────────────────────────────────────────┘
       │
       ▼
┌─────────────┐
│ 按下 Z 键   │
└──────┬──────┘
       │
       ▼
┌──────────────────────────────────────────────────────────────┐
│  z:: 热键处理 (第7097行)                                        │
│  └─→ HandleDynamicHotkey("z", "Z")                            │
│      └─→ 检查是否匹配配置的 HotkeyZ                            │
│          └─→ 如果匹配，执行语音输入逻辑                         │
└──────┬───────────────────────────────────────────────────────┘
       │
       ▼
┌──────────────────────────────────────────────────────────────┐
│  HandleDynamicHotkey() - 处理 Z 键 (第6963行)                   │
│  ┌────────────────────────────────────────────────────────┐  │
│  │ if (VoiceInputActive) {                                 │  │
│  │     StopVoiceInput()  // 如果正在输入，停止输入          │  │
│  │ } else {                                                │  │
│  │     StartVoiceInput()  // 如果未输入，开始输入           │  │
│  │ }                                                       │  │
│  └────────────────────────────────────────────────────────┘  │
└──────┬───────────────────────────────────────────────────────┘
       │
       ├─────────────────┐
       │                 │
       ▼                 ▼
┌──────────────┐  ┌──────────────┐
│ 开始语音输入  │  │ 停止语音输入  │
│StartVoiceInput│  │StopVoiceInput│
└──────┬───────┘  └──────┬───────┘
       │                 │
       │                 │
       ▼                 ▼
```

## StartVoiceInput() 函数流程 (第7349行)

```
┌─────────────────────────────────────────────────────────────────┐
│                    StartVoiceInput() 流程                        │
└─────────────────────────────────────────────────────────────────┘

1. 检查状态
   ┌─────────────────────────────┐
   │ if (VoiceInputActive)       │
   │     return  // 已在输入中   │
   └─────────────────────────────┘

2. 关闭快捷操作面板
   ┌─────────────────────────────┐
   │ if (PanelVisible)            │
   │     HideCursorPanel()        │
   └─────────────────────────────┘

3. 启动/激活 Cursor
   ┌─────────────────────────────────────────────┐
   │ if (!WinExist("ahk_exe Cursor.exe")) {      │
   │     Run(CursorPath)  // 启动 Cursor         │
   │     Sleep(AISleepTime)                      │
   │ }                                           │
   │ WinActivate("ahk_exe Cursor.exe")           │
   │ WinWaitActive("ahk_exe Cursor.exe", , 2)    │
   └─────────────────────────────────────────────┘

4. 打开 Cursor AI 聊天面板
   ┌─────────────────────────────────────────────┐
   │ Send("{Esc}")      // 关闭可能打开的输入框  │
   │ Send("^l")         // 打开 AI 聊天面板      │
   │ Sleep(500)                                  │
   │ Send("^a")         // 全选                  │
   │ Send("{Delete}")   // 清空输入框             │
   └─────────────────────────────────────────────┘

5. 检测输入法类型
   ┌─────────────────────────────────────────────┐
   │ VoiceInputMethod := DetectInputMethod()     │
   │ // 返回: "baidu", "xunfei", 或 "auto"       │
   └─────────────────────────────────────────────┘

6. 启动语音输入（根据输入法类型）
   ┌─────────────────────────────────────────────┐
   │ if (VoiceInputMethod = "baidu") {           │
   │     Send("!y")      // Alt+Y 激活百度语音   │
   │     Sleep(500)                               │
   │     Send("{F2}")    // F2 开始语音输入      │
   │ } else if (VoiceInputMethod = "xunfei") {   │
   │     Send("{F6}")    // F6 开始/结束讯飞语音  │
   │     Sleep(800)                               │
   │ } else {                                    │
   │     // 默认尝试百度方案                      │
   │     Send("!y")                               │
   │     Send("{F2}")                            │
   │ }                                           │
   └─────────────────────────────────────────────┘

7. 设置状态并显示动画
   ┌─────────────────────────────────────────────┐
   │ VoiceInputActive := true                    │
   │ VoiceInputContent := ""                     │
   │ ShowVoiceInputAnimation()  // 显示动画界面  │
   └─────────────────────────────────────────────┘
```

## StopVoiceInput() 函数流程 (第7425行)

```
┌─────────────────────────────────────────────────────────────────┐
│                    StopVoiceInput() 流程                         │
└─────────────────────────────────────────────────────────────────┘

1. 检查状态
   ┌─────────────────────────────┐
   │ if (!VoiceInputActive)       │
   │     return  // 未在输入中    │
   └─────────────────────────────┘

2. 重置 CapsLock 状态
   ┌─────────────────────────────┐
   │ if (CapsLock)               │
   │     CapsLock := false        │
   └─────────────────────────────┘

3. 结束语音输入（根据输入法类型）
   ┌─────────────────────────────────────────────────────────────┐
   │ if (VoiceInputMethod = "baidu") {                            │
   │     Send("{F1}")      // F1 结束百度语音输入                 │
   │     Sleep(800)                                               │
   │     // 获取内容：全选 → 复制 → 读取剪贴板                    │
   │     Send("^a")                                               │
   │     A_Clipboard := ""                                        │
   │     Send("^c")                                               │
   │     if ClipWait(1.5) {                                       │
   │         VoiceInputContent := A_Clipboard                     │
   │     }                                                        │
   │     Send("!y")      // Alt+Y 关闭百度语音窗口                 │
   │ } else if (VoiceInputMethod = "xunfei") {                   │
   │     Send("{F6}")     // F6 结束讯飞语音输入                  │
   │     Sleep(1000)                                              │
   │     // 获取内容：全选 → 复制 → 读取剪贴板                    │
   │     Send("^a")                                               │
   │     A_Clipboard := ""                                        │
   │     Send("^c")                                               │
   │     if ClipWait(1.5) {                                       │
   │         VoiceInputContent := A_Clipboard                     │
   │     }                                                        │
   │ }                                                            │
   └─────────────────────────────────────────────────────────────┘

4. 更新状态并隐藏动画
   ┌─────────────────────────────────────────────┐
   │ VoiceInputActive := false                   │
   │ HideVoiceInputAnimation()                   │
   └─────────────────────────────────────────────┘

5. 显示操作选择界面
   ┌─────────────────────────────────────────────┐
   │ if (VoiceInputContent != "") {              │
   │     ShowVoiceInputActionSelection(          │
   │         VoiceInputContent                   │
   │     )  // 显示：发送到Cursor 或 搜索        │
   │ } else {                                    │
   │     TrayTip("未检测到语音输入内容")          │
   │ }                                           │
   └─────────────────────────────────────────────┘
```

## ShowVoiceInputActionSelection() 函数流程 (第7689行)

```
┌─────────────────────────────────────────────────────────────────┐
│           ShowVoiceInputActionSelection() 流程                    │
└─────────────────────────────────────────────────────────────────┘

1. 创建操作选择界面
   ┌─────────────────────────────────────────────┐
   │ GuiID_VoiceInput := Gui(...)                 │
   │ // 显示语音输入的内容                        │
   │ // 显示两个操作按钮：                        │
   │ //   - 发送到Cursor                          │
   │ //   - 搜索                                  │
   └─────────────────────────────────────────────┘

2. 用户选择操作
   ┌─────────────────────────────────────────────┐
   │ 点击"发送到Cursor"                          │
   │   └─→ SendToCursorHandler()                 │
   │       └─→ 发送内容到 Cursor                 │
   │                                            │
   │ 点击"搜索"                                  │
   │   └─→ ShowSearchEnginesHandler()           │
   │       └─→ 显示搜索引擎选择界面              │
   │           └─→ 用户选择搜索引擎              │
   │               └─→ 打开浏览器搜索            │
   └─────────────────────────────────────────────┘
```

## 完整数据流

```
用户操作
   │
   ├─→ CapsLock 按下
   │   └─→ CapsLockDown()
   │       ├─→ CapsLock = true
   │       ├─→ CapsLock2 = true
   │       └─→ 启动定时器（长按显示面板）
   │
   ├─→ Z 键按下
   │   └─→ z:: 热键 (第7097行)
   │       └─→ HandleDynamicHotkey("z", "Z")
   │           └─→ 检查 HotkeyZ 配置
   │               └─→ 执行语音输入逻辑
   │
   └─→ 语音输入流程
       │
       ├─→ StartVoiceInput() (第7349行)
       │   ├─→ 激活 Cursor
       │   ├─→ 打开 AI 聊天面板 (Ctrl+L)
       │   ├─→ 检测输入法类型
       │   ├─→ 启动语音输入（百度/讯飞）
       │   └─→ ShowVoiceInputAnimation()
       │
       ├─→ 用户说话（语音识别中）
       │   └─→ UpdateVoiceAnimation() (每500ms更新动画)
       │
       └─→ Z 键再次按下（或 CapsLock 释放）
           └─→ StopVoiceInput() (第7425行)
               ├─→ 结束语音输入
               ├─→ 获取识别内容
               ├─→ HideVoiceInputAnimation()
               └─→ ShowVoiceInputActionSelection()
                   ├─→ 发送到Cursor
                   └─→ 或搜索
```

## 关键全局变量

```
VoiceInputActive          - 语音输入是否激活
VoiceInputContent         - 存储语音输入的内容
VoiceInputMethod          - 当前使用的输入法类型（baidu/xunfei/auto）
VoiceInputPaused          - 语音输入是否被暂停（按住CapsLock时）
GuiID_VoiceInput          - 语音输入动画GUI ID
VoiceTitleText            - 语音输入动画标题文本控件
VoiceHintText             - 语音输入动画提示文本控件
VoiceAnimationText        - 语音输入/搜索动画文本控件
AutoLoadSelectedText      - 是否自动加载选中文本到输入框
AutoUpdateVoiceInput      - 是否自动更新语音输入内容到输入框
VoiceInputActionSelectionVisible - 语音输入操作选择界面是否显示
```

## 关键函数说明

| 函数名 | 位置 | 功能 |
|--------|------|------|
| `CapsLockDown()` | 第1794行 | 处理 CapsLock 按下事件，启动长按定时器 |
| `z::` | 第7097行 | Z 键热键处理，调用 HandleDynamicHotkey |
| `HandleDynamicHotkey()` | 第6856行 | 处理动态快捷键，检查是否匹配配置的 HotkeyZ |
| `StartVoiceInput()` | 第7349行 | 开始语音输入，激活 Cursor 并启动语音识别 |
| `StopVoiceInput()` | 第7425行 | 停止语音输入，获取识别内容并显示操作选择 |
| `DetectInputMethod()` | 第7147行 | 检测输入法类型（百度/讯飞） |
| `ShowVoiceInputAnimation()` | 第7560行 | 显示语音输入动画界面 |
| `HideVoiceInputAnimation()` | 第7673行 | 隐藏语音输入动画界面 |
| `UpdateVoiceAnimation()` | 第7641行 | 更新语音输入动画（每500ms） |
| `ShowVoiceInputActionSelection()` | 第7689行 | 显示操作选择界面（发送到Cursor或搜索） |
| `UpdateVoiceInputPausedState()` | 第7598行 | 更新语音输入暂停状态显示 |

## CapsLock 暂停/恢复机制

```
用户按住 CapsLock 时：
   ┌─────────────────────────────────────────────┐
   │ CapsLockDown() 检测到 CapsLock 按下         │
   │   └─→ if (VoiceInputActive) {               │
   │           VoiceInputPaused := true          │
   │           UpdateVoiceInputPausedState(true) │
   │           // 暂停语音输入动画                │
   │       }                                     │
   └─────────────────────────────────────────────┘

用户释放 CapsLock 时：
   ┌─────────────────────────────────────────────┐
   │ CapsLockUp() 检测到 CapsLock 释放           │
   │   └─→ if (VoiceInputPaused) {               │
   │           VoiceInputPaused := false         │
   │           UpdateVoiceInputPausedState(false)│
   │           // 恢复语音输入动画                │
   │       }                                     │
   └─────────────────────────────────────────────┘
```

## 输入法支持

### 百度输入法
- 激活：Alt+Y
- 开始：F2
- 结束：F1
- 关闭：Alt+Y

### 讯飞输入法
- 开始/结束：F6（切换模式）

## 操作选择界面

```
┌─────────────────────────────────────────┐
│           选择操作                       │
├─────────────────────────────────────────┤
│ 语音输入内容:                             │
│ [显示识别的内容]                          │
│                                            │
│ 自动加载选中文本: [开关]                   │
│                                            │
│ [发送到Cursor]  [搜索]                    │
│                                            │
│ 选择搜索引擎: (点击搜索后显示)             │
│ [DeepSeek] [Yuanbao] [Doubao] ...         │
│                                            │
│              [取消]                       │
└─────────────────────────────────────────┘
```

