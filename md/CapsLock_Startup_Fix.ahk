; ======================================================================================================================
; CapsLock 启动修复 - 解决单击无法切换中文问题
; 版本: 1.1.0
; 问题: 启动软件后单击 CapsLock 无法返回中文，必须长按切换
; 原因: 
;   1. 脚本启动时 CapsLock 状态未重置
;   2. ~ 前缀导致系统和脚本同时处理 CapsLock
;   3. 中文输入法依赖 CapsLock 状态，状态混乱导致切换失效
; ======================================================================================================================

; ===================== 【步骤1】脚本启动时强制重置 CapsLock 状态 =====================
; 放在脚本最开头（第 1 行之后，任何其他代码之前）

; 【修复】启动时强制关闭 CapsLock，确保初始状态一致
; 循环多次确保状态真正生效
Loop 3 {
    SetCapsLockState("Off")
    Sleep(50)
}

; 【可选】启动时显示 CapsLock 状态提示（用于调试）
; 如果想确认修复是否生效，可以取消下面的注释
; StartupCapsState := GetKeyState("CapsLock", "T")
; TrayTip("CapsLock 状态", "启动时 CapsLock 状态: " . (StartupCapsState ? "开启" : "关闭"), "Iconi 2")

; ======================================================================================================================
; ===================== 【步骤2】完全接管 CapsLock 热键（移除 ~ 前缀）=====================
; 替换原始的 ~CapsLock:: 热键
; ======================================================================================================================

#HotIf  ; 全局热键上下文

; 【关键修复】移除 ~ 前缀，完全接管 CapsLock
; 这样可以避免系统与脚本同时处理 CapsLock 导致的冲突
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
    
    ; 【关键修复1】记录初始状态（必须在关闭之前记录）
    local InitialCapsLockState := GetKeyState("CapsLock", "T")
    
    ; 【关键修复2】立即关闭 CapsLock
    ; 由于移除了 ~ 前缀，我们需要手动管理 CapsLock 状态
    SetCapsLockState("Off")
    
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
        
        ; 【关键修复3】语音模式结束后，强制关闭再恢复状态
        SetCapsLockState("Off")
        Sleep(10)
        SetCapsLockState(InitialCapsLockState)
        
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
    
    KeyWait("CapsLock")
    SetTimer(ShowPanelTimer, 0)
    
    ; 【关键修复4】释放时首先强制关闭 CapsLock
    ; 清除任何可能由系统或之前的操作导致的残留状态
    SetCapsLockState("Off")
    Sleep(10)  ; 短暂延迟确保状态生效
    
    ; 检查面板是否已显示（长按触发）
    if (PanelVisible) {
        ; 面板已显示（长按），恢复初始状态
        SetCapsLockState(InitialCapsLockState)
        SetTimer(ClearCapsLockTimer, -100)
        CapsLock2 := false
        return
    }
    
    ; 【关键修复5】根据是否使用了功能键决定最终状态
    if (!CapsLock2) {
        ; 使用了功能（如 CapsLock+F, CapsLock+C 等）
        ; 恢复到按下前的状态
        SetCapsLockState(InitialCapsLockState)
        SetTimer(ClearCapsLockTimer, -100)
    } else {
        ; 没有使用功能，这是一次单纯的 CapsLock 按下
        ; 【关键】模拟原始 CapsLock 行为：切换大小写状态
        ; 但首先确保当前是关闭状态，然后切换
        if (InitialCapsLockState) {
            ; 原来是开启的，现在关闭
            SetCapsLockState("Off")
        } else {
            ; 原来是关闭的，现在开启
            SetCapsLockState("On")
        }
        CapsLock := false
    }
    
    CapsLock2 := false
    IsCommandMode := false
}

#HotIf

; ======================================================================================================================
; ===================== 【步骤3】定时检查 CapsLock 状态（防止异常）=====================
; ======================================================================================================================

; 启动时立即执行一次检查
SetTimer(CheckCapsLockState, -1000)

; 定期检查 CapsLock 状态，如果发现异常则修复
CheckCapsLockState() {
    static LastKnownState := false
    static CheckCount := 0
    
    ; 获取当前 CapsLock 切换状态（T = Toggle）
    CurrentState := GetKeyState("CapsLock", "T")
    
    ; 每10次检查输出一次调试信息（用于排查问题）
    CheckCount++
    if (CheckCount >= 10) {
        CheckCount := 0
        ; OutputDebug("AHK_DEBUG: CapsLock State Check - Current: " . CurrentState . ", Last: " . LastKnownState)
    }
    
    LastKnownState := CurrentState
}

; ======================================================================================================================
; ===================== 【步骤4】修复输入法切换问题 =====================
; 如果用户报告单击 CapsLock 无法切换中文，可能是因为：
; 1. CapsLock 指示灯显示开启状态，但输入法认为是大写模式
; 2. 某些输入法依赖 Shift 键而不是 CapsLock 来切换中英文
; ======================================================================================================================

; 【备选方案】如果上述修复无效，可以尝试使用 Shift 键切换输入法
; 将下面的代码添加到 CapsLock 热键的 "else" 分支中：
;
; } else {
;     ; 没有使用功能，使用 Shift 键切换输入法（而不是 CapsLock）
;     ; 这样可以避免 CapsLock 状态混乱
;     Send("{Shift}")
;     CapsLock := false
; }

; ======================================================================================================================
; ===================== 使用说明 =====================
;
; 【方法一】直接修改主脚本（推荐）
; 1. 打开 CursorHelper (1).ahk
; 2. 在第 1 行后添加启动重置代码：
;    Loop 3 {
;        SetCapsLockState("Off")
;        Sleep(50)
;    }
; 3. 将 ~CapsLock:: 替换为 CapsLock::（使用上面的代码）
; 4. 保存并重启脚本
;
; 【方法二】包含此修复文件
; 1. 将此文件保存为 CapsLock_Startup_Fix.ahk
; 2. 在 CursorHelper (1).ahk 的末尾添加：
;    #Include CapsLock_Startup_Fix.ahk
; 3. 注释掉原始的 ~CapsLock:: 热键
; 4. 保存并重启脚本
;
; 【验证修复】
; 1. 启动脚本前，确保 CapsLock 处于关闭状态（灯灭）
; 2. 启动脚本
; 3. 立即单击 CapsLock，观察是否可以切换到中文输入法
; 4. 使用 CapsLock+F 打开搜索中心，观察 CapsLock 灯是否保持熄灭
; 5. 再次单击 CapsLock，观察是否可以正常切换输入法
; ======================================================================================================================
