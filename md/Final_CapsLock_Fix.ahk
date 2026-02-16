; ======================================================================================================================
; CapsLock 状态问题终极修复
; 修复问题:
;   1. CapsLock+F 启动搜索后，CapsLock 大写状态被激活
;   2. 单击 CapsLock 无法切换中文输入法
;   3. 必须使用长按才能切换输入法
; 
; 根本原因: ~ 前缀导致系统和脚本同时处理 CapsLock，产生竞争条件
; 解决方案: 完全禁用 CapsLock 大写功能，使用键盘钩子拦截，脚本完全接管
; ======================================================================================================================

; ===================== 【步骤1】在脚本开头添加（第 7 行后）=====================
; 安装键盘钩子，确保能拦截 CapsLock
#InstallKeybdHook

; 完全禁用 CapsLock 的大写功能（这是关键！）
; 这样系统不会再处理 CapsLock 的大小写切换，完全由脚本控制
SetCapsLockState("AlwaysOff")

; 启动时确保 CapsLock 状态一致
Loop 3 {
    SetCapsLockState("AlwaysOff")
    Sleep(50)
}

; ===================== 【步骤2】替换 ~CapsLock:: 热键 =====================
; 将原来的 ~CapsLock:: 替换为以下代码
; 注意：由于使用了 SetCapsLockState("AlwaysOff")，不需要 ~ 前缀

#HotIf  ; 全局热键上下文

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
    
    ; 【修复】由于 AlwaysOff，不需要再关闭，但保留以保险
    SetCapsLockState("AlwaysOff")
    
    ; 标记 CapsLock 已按下
    CapsLock := true
    CapsLock2 := true
    IsCommandMode := false
    
    ; 记录按下时间
    CapsLockPressTime := A_TickCount
    
    ; ========== 语音输入/搜索模式处理 ==========
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
        
        ; 【修复】确保状态保持关闭
        SetCapsLockState("AlwaysOff")
        CapsLock := false
        CapsLock2 := false
        return
    }
    
    ; ========== 正常 CapsLock+ 逻辑 ==========
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
    
    ; 【修复】确保状态保持关闭
    SetCapsLockState("AlwaysOff")
    
    ; 检查面板是否已显示
    if (PanelVisible) {
        SetTimer(ClearCapsLockTimer, -100)
        CapsLock2 := false
        return
    }
    
    ; 【修复】根据是否使用了功能键决定行为
    if (!CapsLock2) {
        ; 使用了功能，保持关闭状态
        SetCapsLockState("AlwaysOff")
        SetTimer(ClearCapsLockTimer, -100)
    } else {
        ; 没有使用功能，这是一次单纯的 CapsLock 按下
        ; 【关键】模拟大小写切换，但使用更安全的方式
        ; 获取当前切换状态
        CurrentToggleState := GetKeyState("CapsLock", "T")
        ; 切换状态
        if (CurrentToggleState) {
            SetCapsLockState("Off")
        } else {
            SetCapsLockState("On")
        }
        ; 立即恢复 AlwaysOff，但保留切换效果给输入法
        SetTimer(RestoreAlwaysOff, -50)
        CapsLock := false
    }
    
    CapsLock2 := false
    IsCommandMode := false
}

; 恢复 AlwaysOff 状态的定时器函数
RestoreAlwaysOff(*) {
    SetCapsLockState("AlwaysOff")
}

#HotIf

; ===================== 【步骤3】修改所有 f:: 热键中的 CapsLock2 处理 =====================
; 确保在 f:: 热键中正确设置 CapsLock2 = false

; 在 HandleDynamicHotkey 函数中（约第 22830 行）：
; case "F":
;     CapsLock2 := false  ; ← 确保这行存在且在开头
;     ...

; ===================== 【步骤4】添加调试功能（可选）=====================
; 如果仍然有问题，启用以下调试代码来查看 CapsLock 状态

; CapsLock 状态监控（调试时使用）
; SetTimer(MonitorCapsLockState, 1000)

MonitorCapsLockState() {
    static LastState := -1
    CurrentState := GetKeyState("CapsLock", "T")
    if (CurrentState != LastState) {
        OutputDebug("AHK_DEBUG: CapsLock Toggle State changed to: " . CurrentState)
        LastState := CurrentState
    }
}

; ======================================================================================================================
; 使用说明
; ======================================================================================================================
;
; 【一键修复】
; 1. 打开 CursorHelper (1).ahk
; 2. 在第 7 行（基础配置后）添加：
;    #InstallKeybdHook
;    SetCapsLockState("AlwaysOff")
;    Loop 3 {
;        SetCapsLockState("AlwaysOff")
;        Sleep(50)
;    }
;
; 3. 将 ~CapsLock:: 替换为 CapsLock::（使用上面的代码）
;
; 4. 保存并重启脚本
;
; 【验证修复】
; 1. 启动脚本后，CapsLock 灯应该保持熄灭
; 2. 单击 CapsLock：应该能切换中文输入法（输入法依赖 CapsLock 状态）
; 3. CapsLock + F：打开搜索中心，CapsLock 灯保持熄灭
; 4. 再次单击 CapsLock：仍能正常切换输入法
;
; 【如果输入法仍无法切换】
; 某些输入法可能使用 Shift 键而不是 CapsLock 切换中英文。
; 这种情况下，需要在 CapsLock 热键中发送 Shift 键：
;
; } else {
;     ; 使用 Shift 键切换输入法
;     Send("{LShift}")
;     CapsLock := false
; }
;
; ======================================================================================================================
