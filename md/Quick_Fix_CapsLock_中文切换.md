# 快速修复：CapsLock 无法切换中文输入法

## 问题症状
- 启动软件后，单击 CapsLock 无法切换到中文输入法
- 必须长按 CapsLock 切换到英文小写，再单击才能切换到中文

## 根本原因
1. **脚本启动时 CapsLock 状态未重置** - 可能处于混乱状态
2. **`~` 前缀冲突** - 系统和脚本同时处理 CapsLock，导致状态不一致
3. **中文输入法依赖** - 输入法通过 CapsLock 状态判断是否切换中英文

---

## 🔧 快速修复（3步，2分钟）

### 第1步：添加启动时重置代码

**位置**：`CursorHelper (1).ahk` 第 7 行（基础配置下方）

**添加代码**：
```ahk
; ===================== 基础配置 =====================
#SingleInstance Force
SetTitleMatchMode(2)
; ... 其他配置 ...

; 【修复】启动时强制重置 CapsLock 状态
Loop 3 {
    SetCapsLockState("Off")
    Sleep(50)
}
```

---

### 第2步：修改 ~CapsLock:: 为 CapsLock::

**位置**：约第 3799 行

**找到**：
```ahk
; 采用 CapsLock+ 方案：使用 ~ 前缀保留原始功能，通过标记变量控制行为
~CapsLock:: {
```

**替换为**：
```ahk
; 【修复】移除 ~ 前缀，完全接管 CapsLock，避免与系统冲突
CapsLock:: {
```

---

### 第3步：修复状态切换逻辑

**位置**：`~CapsLock::` 热键内部，约第 3932 行

**找到**：
```ahk
} else {
    ; 没有使用功能，切换状态（短按 CapsLock 的正常行为）
    SetCapsLockState(!InitialCapsLockState)
    CapsLock := false
}
```

**替换为**：
```ahk
} else {
    ; 【修复】没有使用功能，这是一次单纯的 CapsLock 按下
    ; 确保当前是关闭状态，然后根据原状态切换
    SetCapsLockState("Off")
    Sleep(10)
    if (InitialCapsLockState) {
        ; 原来是开启的，现在保持关闭（切换为关闭）
        SetCapsLockState("Off")
    } else {
        ; 原来是关闭的，现在开启（切换为开启）
        SetCapsLockState("On")
    }
    CapsLock := false
}
```

---

## ✅ 完整修复后的 CapsLock 热键代码

如果需要完整替换整个 `~CapsLock::` 热键，使用以下代码：

```ahk
; 【修复】移除 ~ 前缀，完全接管 CapsLock
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
    
    ; 记录初始状态
    local InitialCapsLockState := GetKeyState("CapsLock", "T")
    
    ; 立即关闭 CapsLock
    SetCapsLockState("Off")
    
    ; 标记 CapsLock 已按下
    CapsLock := true
    CapsLock2 := true
    IsCommandMode := false
    
    ; 记录按下时间
    CapsLockPressTime := A_TickCount
    
    ; 语音输入/搜索模式处理
    if (VoiceInputActive || VoiceSearchActive) {
        SetTimer(ClearCapsLock2Timer, -300)
        
        if (!VoiceInputPaused) {
            VoiceInputPaused := true
            UpdateVoiceInputPausedState(true)
            
            if (VoiceInputActive) {
                Send("^+{Space}")
                Sleep(200)
            }
        }
        
        KeyWait("CapsLock")
        SetTimer(ClearCapsLock2Timer, 0)
        
        PressDuration := A_TickCount - CapsLockPressTime
        
        if (CapsLock2 && PressDuration < 1500) {
            if (VoiceInputPaused) {
                VoiceInputPaused := false
                if (VoiceInputActive) {
                    UpdateVoiceInputPausedState(false)
                }
                
                if (VoiceInputActive) {
                    Send("^+{Space}")
                    Sleep(200)
                }
            }
        }
        
        SetCapsLockState("Off")
        Sleep(10)
        SetCapsLockState(InitialCapsLockState)
        
        CapsLock := false
        CapsLock2 := false
        return
    }
    
    ; 正常 CapsLock+ 逻辑
    HoldTimeMs := Round(CapsLockHoldTimeSeconds * 1000)
    if (HoldTimeMs < 100) {
        HoldTimeMs := 100
    } else if (HoldTimeMs > 5000) {
        HoldTimeMs := 5000
    }
    SetTimer(ShowPanelTimer, -HoldTimeMs)
    
    KeyWait("CapsLock")
    SetTimer(ShowPanelTimer, 0)
    
    ; 释放时首先强制关闭
    SetCapsLockState("Off")
    Sleep(10)
    
    ; 检查面板是否已显示
    if (PanelVisible) {
        SetCapsLockState(InitialCapsLockState)
        SetTimer(ClearCapsLockTimer, -100)
        CapsLock2 := false
        return
    }
    
    ; 根据是否使用了功能键决定最终状态
    if (!CapsLock2) {
        ; 使用了功能
        SetCapsLockState(InitialCapsLockState)
        SetTimer(ClearCapsLockTimer, -100)
    } else {
        ; 【关键修复】没有使用功能，切换状态
        SetCapsLockState("Off")
        Sleep(10)
        if (InitialCapsLockState) {
            SetCapsLockState("Off")
        } else {
            SetCapsLockState("On")
        }
        CapsLock := false
    }
    
    CapsLock2 := false
    IsCommandMode := false
}
```

---

## 🧪 验证修复

1. **重启脚本**
   - 完全退出脚本（托盘图标右键 -> 退出）
   - 重新启动

2. **测试步骤**
   ```
   步骤1: 观察 CapsLock 指示灯（应该熄灭）
   步骤2: 单击 CapsLock，观察灯是否亮起
   步骤3: 在文本框中输入，观察是否能输入大写字母
   步骤4: 再次单击 CapsLock，观察灯是否熄灭
   步骤5: 切换到中文输入法，单击 CapsLock 观察是否能切换中英文
   步骤6: 使用 CapsLock+F 打开搜索中心，观察灯是否保持熄灭
   步骤7: 关闭搜索中心，再次测试中文输入法切换
   ```

3. **预期结果**
   - ✅ 单击 CapsLock 正常切换大小写
   - ✅ 中文输入法可以通过 CapsLock 切换中英文
   - ✅ 使用快捷键后 CapsLock 灯不亮
   - ✅ 长按显示面板后 CapsLock 状态正确

---

## ⚠️ 备选方案

如果上述修复无效，可能是输入法使用 Shift 键而不是 CapsLock 切换中英文：

### 方案 A：修改切换方式为 Shift
将 CapsLock 热键中的切换逻辑改为发送 Shift：
```ahk
} else {
    ; 使用 Shift 切换输入法
    Send("{LShift}")
    CapsLock := false
}
```

### 方案 B：禁用脚本的 CapsLock 处理
如果不需要脚本管理 CapsLock，只保留快捷键功能：
```ahk
; 在脚本开头添加
SetCapsLockState("AlwaysOff")  ; 禁用 CapsLock 大写功能

; 然后使用 ~ 前缀热键
~CapsLock:: {
    ; 只处理快捷键，不管理状态
    ; ... 快捷键逻辑 ...
}
```

---

## 📞 如果仍有问题

1. **检查输入法设置**
   - 确认输入法的中英文切换键设置为 CapsLock
   - 某些输入法可能需要单独配置

2. **检查其他软件冲突**
   - 关闭其他可能管理 CapsLock 的软件（如 CapsLock+、AutoHotkey 其他脚本）

3. **启用调试输出**
   在脚本开头添加：
   ```ahk
   #InstallKeybdHook
   ```
   这样可以更好地监控键盘事件。
