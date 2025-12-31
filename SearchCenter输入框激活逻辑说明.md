# SearchCenter 输入框激活逻辑说明

## 📋 核心功能概述

这段代码实现了 SearchCenter（搜索中心）输入框的激活和样式管理功能。主要包含两个核心部分：
1. **输入框创建和样式设置** - 在 `ShowSearchCenter()` 函数中
2. **输入框高亮更新** - 在 `UpdateSearchCenterHighlight()` 函数中

---

## 🔍 核心逻辑流程

### 1. 输入框创建流程（ShowSearchCenter 函数）

```
用户触发 CapsLock+G
    ↓
ShowSearchCenter() 被调用
    ↓
根据主题模式（亮色/暗色）设置输入框颜色
    ↓
创建输入框控件（Edit控件，无边框）
    ↓
移除 Edit 控件的默认 3D 边框（通过 Windows API）
    ↓
注册输入框的 Focus 事件处理器
    ↓
当输入框获得焦点时 → 自动调用 UpdateSearchCenterHighlight()
```

### 2. 输入框高亮更新流程（UpdateSearchCenterHighlight 函数）

```
用户切换焦点区域（分类/输入框/列表）
    ↓
SearchCenterActiveArea 变量被更新
    ↓
UpdateSearchCenterHighlight() 被调用
    ↓
检查当前激活区域是否为 "input"
    ↓
如果是输入框：
    - 聚焦时：背景色变亮（暗色模式：2d2d30 → 3d3d40）
    - 未聚焦时：恢复默认背景色
```

---

## 📥 输入输出说明

### 输入（Input）

1. **全局变量（输入）**：
   - `SearchCenterActiveArea` - 当前激活区域（"category" / "input" / "listview"）
   - `ThemeMode` - 主题模式（"light" / "dark"）
   - `UI_Colors` - UI 颜色配置对象

2. **函数调用触发**：
   - 用户按 `CapsLock+G` → 触发 `ShowSearchCenter()`
   - 输入框获得/失去焦点 → 触发 `UpdateSearchCenterHighlight()`
   - 用户使用方向键切换区域 → 触发 `UpdateSearchCenterHighlight()`

### 输出（Output）

1. **视觉输出**：
   - 输入框背景色变化（聚焦时变亮，未聚焦时恢复）
   - 区域名称动画展示（分类搜索/输入框/本地搜索）
   - 操作提示文本更新

2. **状态更新**：
   - `SearchCenterSearchEdit` - 输入框控件对象
   - `SearchCenterAreaIndicator` - 区域名称显示控件
   - `SearchCenterHintText` - 操作提示文本控件

---

## 🔧 关键函数作用

### 1. `ShowSearchCenter()` - 创建搜索中心窗口

**作用**：创建整个搜索中心界面，包括输入框

**关键代码段**：
```autohotkey
; 根据主题模式设置输入框颜色
if (ThemeMode = "dark") {
    InputBgColor := "2d2d30"  ; 暗色模式背景
    InputTextColor := "FFFFFF"  ; 白色文字
} else {
    InputBgColor := UI_Colors.InputBg  ; 亮色模式背景
    InputTextColor := UI_Colors.Text  ; 文字颜色
}

; 创建输入框（无边框，避免黑边问题）
SearchCenterSearchEdit := GuiID_SearchCenter.Add("Edit", 
    "x" . SearchEditX . " y" . SearchEditY . 
    " w" . SearchEditWidth . " h" . SearchEditHeight . 
    " Background" . InputBgColor . " c" . InputTextColor . 
    " -VScroll -HScroll -Border vSearchCenterEdit", "")

; 移除 Edit 控件的默认 3D 边框（底部黑边）
EditHwnd := SearchCenterSearchEdit.Hwnd
CurrentExStyle := DllCall("GetWindowLongPtr", "Ptr", EditHwnd, "Int", -20, "Ptr")
NewExStyle := CurrentExStyle & ~0x00000200  ; 移除 WS_EX_CLIENTEDGE
DllCall("SetWindowLongPtr", "Ptr", EditHwnd, "Int", -20, "Ptr", NewExStyle, "Ptr")
```

**易错点**：
- ⚠️ **必须使用 `-Border` 选项**，否则会显示默认边框（包括底部黑边）
- ⚠️ **必须移除 `WS_EX_CLIENTEDGE` 扩展样式**，否则会有 3D 边框效果
- ⚠️ **Windows API 调用可能失败**，需要用 try-catch 包裹

---

### 2. `UpdateSearchCenterHighlight()` - 更新输入框高亮

**作用**：根据当前激活区域更新输入框的视觉样式

**关键代码段**：
```autohotkey
; 更新输入框高亮（Material Design风格：聚焦时背景色变化，无边框）
if (SearchCenterSearchEdit != 0) {
    try {
        if (SearchCenterActiveArea = "input") {
            ; 激活输入框时，使用更亮的背景色
            if (ThemeMode = "dark") {
                SearchCenterSearchEdit.Opt("+Background" . "3d3d40")  ; 稍亮的背景
            } else {
                SearchCenterSearchEdit.Opt("+Background" . UI_Colors.InputBg)
            }
        } else {
            ; 未激活时，恢复默认背景色
            if (ThemeMode = "dark") {
                SearchCenterSearchEdit.Opt("+Background" . "2d2d30")
            } else {
                SearchCenterSearchEdit.Opt("+Background" . UI_Colors.InputBg)
            }
        }
    } catch {
        ; 忽略错误
    }
}
```

**易错点**：
- ⚠️ **必须检查控件是否存在**（`SearchCenterSearchEdit != 0`），否则会报错
- ⚠️ **必须使用 try-catch**，因为控件可能已被销毁
- ⚠️ **颜色值必须是 6 位十六进制字符串**（如 "2d2d30"），不能带 "#" 前缀

---

### 3. `SearchCenterSearchEdit.OnEvent("Focus", ...)` - 焦点事件处理

**作用**：当输入框获得焦点时，自动更新区域状态并切换到中文输入法

**关键代码段**：
```autohotkey
SearchCenterSearchEdit.OnEvent("Focus", (*) => (
    SearchCenterActiveArea := "input",
    UpdateSearchCenterHighlight(),
    SwitchToChineseIMEForSearchCenter()
))
```

**易错点**：
- ⚠️ **箭头函数参数必须使用 `(*)`**，不能使用 `global`（AutoHotkey v2 限制）
- ⚠️ **必须更新 `SearchCenterActiveArea`**，否则高亮状态不会更新
- ⚠️ **必须调用 `UpdateSearchCenterHighlight()`**，否则视觉不会更新

---

## ⚠️ 常见易错点总结

### 1. 边框问题
- ❌ **错误**：使用 `+Border` 选项 → 会显示默认边框（包括底部黑边）
- ✅ **正确**：使用 `-Border` 选项 + 移除 `WS_EX_CLIENTEDGE` 扩展样式

### 2. 颜色格式问题
- ❌ **错误**：`"#2d2d30"` 或 `0x2d2d30` → AutoHotkey 不接受这种格式
- ✅ **正确**：`"2d2d30"` → 必须是 6 位十六进制字符串

### 3. 控件检查问题
- ❌ **错误**：直接调用 `SearchCenterSearchEdit.Opt()` → 控件可能不存在
- ✅ **正确**：先检查 `if (SearchCenterSearchEdit != 0)` 再操作

### 4. 全局变量作用域问题
- ❌ **错误**：在箭头函数中使用 `global SearchCenterActiveArea` → AutoHotkey v2 不支持
- ✅ **正确**：在函数开头声明 `global`，箭头函数中直接使用变量名

### 5. Windows API 调用问题
- ❌ **错误**：直接调用 API 不处理错误 → 可能崩溃
- ✅ **正确**：使用 try-catch 包裹所有 API 调用

---

## 📊 数据流图

```
用户操作
    ↓
CapsLock+G 按下
    ↓
ShowSearchCenter() 执行
    ├─→ 创建输入框控件
    ├─→ 移除默认边框
    └─→ 注册 Focus 事件
        ↓
用户点击输入框 / 方向键切换到输入框
    ↓
Focus 事件触发
    ├─→ SearchCenterActiveArea := "input"
    ├─→ UpdateSearchCenterHighlight() 执行
    │   ├─→ 检查当前区域是否为 "input"
    │   ├─→ 更新输入框背景色（变亮）
    │   ├─→ 更新区域名称动画（显示 "✏️ 输入框"）
    │   └─→ 更新操作提示文本
    └─→ SwitchToChineseIMEForSearchCenter() 执行
        ↓
用户切换到其他区域
    ↓
UpdateSearchCenterHighlight() 再次执行
    ├─→ 检查当前区域不是 "input"
    └─→ 恢复输入框默认背景色
```

---

## 🎯 关键设计决策

1. **完全移除边框容器**：避免任何底边显示问题
2. **只改变背景色**：聚焦时背景色变亮，提供视觉反馈
3. **动画展示区域名称**：帮助用户理解当前所在区域
4. **详细的操作提示**：指导用户如何使用方向键和快捷键

---

## 📝 代码注释说明

- `-Border`：移除默认边框
- `-VScroll -HScroll`：禁用滚动条
- `WS_EX_CLIENTEDGE`：Windows 扩展样式，产生 3D 边框效果
- `GWL_EXSTYLE = -20`：获取/设置窗口扩展样式的参数
- `~0x00000200`：按位取反，用于移除特定样式位
