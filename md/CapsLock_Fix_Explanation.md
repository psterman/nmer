# CapsLock 状态冲突问题分析与修复

## 问题现象
- 使用 CapsLock+快捷键（如 CapsLock+F）后，CapsLock 大写状态被异常激活
- 用户单击 CapsLock 无法正常切换中文输入法

## 根本原因

### 1. 使用了 `~` 前缀（第 3799 行）
```ahk
~CapsLock:: {
```
`~` 前缀表示**保留原始按键功能**，这意味着：
- 系统会正常处理 CapsLock 按键（切换大小写）
- 同时脚本也处理 CapsLock 按键
- **冲突**：`SetCapsLockState` 与系统的 CapsLock 处理竞争

### 2. 状态恢复逻辑复杂
代码在多个地方恢复 CapsLock 状态：
- 语音输入模式恢复（第 3880 行）
- 长按显示面板后恢复（第 3916 行）
- 使用快捷键后恢复（第 3929 行）
- 未使用功能时切换（第 3934 行）

### 3. 具体 Bug 场景
```
1. 用户按下 CapsLock → 记录 InitialCapsLockState = false
2. 立即执行 SetCapsLockState("Off") → 试图阻止系统切换
3. 用户按 F 键 → CapsLock2 = false（标记使用了功能）
4. 用户释放 CapsLock → 检测到 CapsLock2 = false
5. 执行 SetCapsLockState(InitialCapsLockState) → SetCapsLockState(false)
```

问题：第 5 步虽然恢复为 false，但由于使用了 `~` 前缀，系统可能已经在第 1-2 步之间切换了状态！

## 修复方案

### 方案 1：移除 `~` 前缀（推荐）
完全接管 CapsLock 按键，不让系统处理：

```ahk
; 修改前
~CapsLock:: {
    ...
}

; 修改后
CapsLock:: {
    ...
    ; 在函数末尾手动切换大小写（如果需要）
}
```

### 方案 2：使用键盘钩子拦截
在脚本开头添加：
```ahk
#InstallKeybdHook
SetCapsLockState("AlwaysOff")  ; 完全禁用 CapsLock 的原始功能
```

### 方案 3：修复状态管理逻辑
确保在释放时正确处理状态：

```ahk
; 等待 CapsLock 释放
KeyWait("CapsLock")

; 【修复】强制关闭 CapsLock 状态，防止残留
SetCapsLockState("Off")

; 然后根据逻辑决定是否重新开启
if (!CapsLock2) {
    ; 使用了功能，保持关闭
    SetCapsLockState("Off")
} else {
    ; 没有使用功能，切换状态
    SetCapsLockState(!InitialCapsLockState)
}
```

## 推荐的完整修复代码

替换 `~CapsLock::` 热键为：

```ahk
; ===================== CapsLock核心逻辑（修复版）=====================
; 【修复】移除 ~ 前缀，完全接管 CapsLock 按键
; 这样可以避免与系统的 CapsLock 处理冲突
CapsLock:: {
    global CapsLock, CapsLock2, IsCommandMode, PanelVisible, VoiceInputActive, VoiceSearchActive, VoiceInputMethod, VoiceInputPaused, CapsLockHoldTimeSeconds
    
    ; 确保全局变量已初始化
    if (!IsSet(PanelVisible)) {
        PanelVisible := false
    }
    if (!IsSet(VoiceInputActive)) {
        VoiceInputActive := false
    }
    if (!IsSet(VoiceSearchActive)) {
        VoiceSearchActive := false
    }
    if (!IsSet(CapsLockHoldTimeSeconds) || CapsLockHoldTimeSeconds = "") {
        CapsLockHoldTimeSeconds := 0.5
    }
    
    ; 【关键修复】记录初始状态
    local InitialCapsLockState := GetKeyState("CapsLock", "T")
    
    ; 【关键修复】立即关闭 CapsLock，防止大写锁定
    SetCapsLockState("Off")
    
    ; 标记 CapsLock 已按下
    CapsLock := true
    CapsLock2 := true
    IsCommandMode := false
    
    ; 记录按下时间
    CapsLockPressTime := A_TickCount
    
    ; 如果正在语音输入或语音搜索，处理暂停/恢复逻辑
    if (VoiceInputActive || VoiceSearchActive) {
        ; ... 语音处理逻辑保持不变 ...
        
        ; 等待 CapsLock 释放
        KeyWait("CapsLock")
        
        ; 【修复】强制关闭 CapsLock 后再恢复，避免状态冲突
        SetCapsLockState("Off")
        Sleep(10)
        SetCapsLockState(InitialCapsLockState)
        
        CapsLock := false
        CapsLock2 := false
        return
    }
    
    ; 设置定时器：长按指定时间后自动显示面板
    HoldTimeMs := Round(CapsLockHoldTimeSeconds * 1000)
    if (HoldTimeMs < 100) {
        HoldTimeMs := 100
    } else if (HoldTimeMs > 5000) {
        HoldTimeMs := 5000
    }
    SetTimer(ShowPanelTimer, -HoldTimeMs)
    
    ; 等待 CapsLock 释放
    KeyWait("CapsLock")
    
    ; 停止定时器
    SetTimer(ShowPanelTimer, 0)
    
    ; 【关键修复】首先强制关闭 CapsLock，清除任何可能的残留状态
    SetCapsLockState("Off")
    Sleep(10)  ; 短暂延迟确保状态生效
    
    ; 检查面板是否已显示
    if (PanelVisible) {
        ; 面板已显示（长按），恢复初始状态
        SetCapsLockState(InitialCapsLockState)
        SetTimer(ClearCapsLockTimer, -100)
        CapsLock2 := false
        return
    }
    
    ; 根据是否使用了功能键决定状态
    if (!CapsLock2) {
        ; 使用了功能，恢复到按下前的状态
        SetCapsLockState(InitialCapsLockState)
        SetTimer(ClearCapsLockTimer, -100)
    } else {
        ; 没有使用功能，切换状态（短按 CapsLock 的正常行为）
        SetCapsLockState(!InitialCapsLockState)
        CapsLock := false
    }
    
    ; 清除标记
    CapsLock2 := false
    IsCommandMode := false
}
```

## 额外建议

### 在脚本开头添加（第 8 行附近）：
```ahk
#InstallKeybdHook  ; 安装键盘钩子，更好地控制按键
```

### 或者在系统层面禁用 CapsLock：
```ahk
; 完全禁用 CapsLock 的原始功能，由脚本完全接管
SetCapsLockState("AlwaysOff")
```

## 测试验证

修复后应该测试以下场景：
1. ✅ 短按 CapsLock：正常切换大小写
2. ✅ CapsLock + F：打开搜索中心，大小写状态不变
3. ✅ CapsLock + C：复制内容，大小写状态不变
4. ✅ 长按 CapsLock：显示面板，大小写状态不变
5. ✅ 中文输入法切换：CapsLock 单击正常切换中英文
