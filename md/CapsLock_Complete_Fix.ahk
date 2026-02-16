; ======================================================================================================================
; CapsLock 完全修复方案 - 解决 CapsLock+F 后仍是大写状态的问题
; 
; 问题分析：
;   1. ~CapsLock:: 使用 ~ 前缀，系统立即处理 CapsLock，切换大写 ON
;   2. 用户按 F 键时，大写状态已经激活
;   3. 虽然脚本尝试恢复状态，但存在竞争条件
; 
; 解决方案：
;   1. 脚本启动时完全禁用 CapsLock 大写功能
;   2. 移除 ~ 前缀，让脚本完全接管
;   3. 在关键位置强制关闭 CapsLock 状态
; ======================================================================================================================

; ===================== 【必须】脚本开头添加（第 1 行之后立即添加）=====================
#InstallKeybdHook
SetCapsLockState("AlwaysOff")

; 启动时多次确保 CapsLock 被禁用
Loop 5 {
    SetCapsLockState("AlwaysOff")
    Sleep(50)
}

; 定时器持续保持 CapsLock 关闭状态（防止任何意外）
SetTimer(ForceCapsLockOff, 100)

ForceCapsLockOff() {
    static lastState := false
    currentState := GetKeyState("CapsLock", "T")
    if (currentState) {
        SetCapsLockState("AlwaysOff")
        ; 如果状态从关闭变为开启，强制再次关闭
        if (!lastState && currentState) {
            SetCapsLockState("AlwaysOff")
            OutputDebug("AHK_DEBUG: Forced CapsLock Off`n")
        }
    }
    lastState := currentState
}

; ===================== 【替换】~CapsLock:: 热键（完整替换）=====================
#HotIf

; 【关键】移除 ~ 前缀，完全接管 CapsLock
CapsLock:: {
    global CapsLock, CapsLock2, IsCommandMode, PanelVisible, VoiceInputActive, VoiceSearchActive, VoiceInputPaused, CapsLockHoldTimeSeconds
    
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
    
    ; 【关键】立即强制关闭 CapsLock
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
    
    ; 【关键】强制关闭 CapsLock
    SetCapsLockState("AlwaysOff")
    
    ; 检查面板是否已显示
    if (PanelVisible) {
        SetTimer(ClearCapsLockTimer, -100)
        CapsLock2 := false
        return
    }
    
    ; 根据是否使用了功能键决定行为
    if (!CapsLock2) {
        ; 使用了功能，保持关闭
        SetCapsLockState("AlwaysOff")
        SetTimer(ClearCapsLockTimer, -100)
    } else {
        ; 没有使用功能，模拟 CapsLock 切换
        ; 由于 AlwaysOff，这里需要使用其他方式切换输入法
        ; 发送 Shift 键来切换输入法
        Send("{LShift}")
        CapsLock := false
    }
    
    ; 【关键】最后再次确保关闭
    SetCapsLockState("AlwaysOff")
    
    CapsLock2 := false
    IsCommandMode := false
}

#HotIf

; ===================== 【修改】f:: 热键中添加强制关闭 =====================
; 在 f:: 热键（约第 22984 行）中，添加 SetCapsLockState("AlwaysOff")

f:: {
    global IsCountdownActive
    
    ; 【关键】立即强制关闭 CapsLock
    SetCapsLockState("AlwaysOff")
    
    ; 如果倒计时正在进行，按下 F 立即加速执行
    if (IsCountdownActive) {
        ExecuteCountdownAction()
        SetCapsLockState("AlwaysOff")
        return
    }
    
    ; 如果 SearchCenter 窗口已激活，执行区域内操作逻辑
    if (IsSearchCenterActive()) {
        HandleSearchCenterF()
    } else {
        ; 否则激活搜索中心窗口
        ShowSearchCenter()
    }
    
    ; 【关键】执行完成后强制关闭 CapsLock
    SetCapsLockState("AlwaysOff")
    SetTimer(ForceCapsLockOffDelay, -100)
}

ForceCapsLockOffDelay() {
    SetCapsLockState("AlwaysOff")
}

; ===================== 【修改】ShowSearchCenter 函数开头添加 =====================
; 在 ShowSearchCenter 函数（约第 23983 行）开头添加：

; ShowSearchCenter() {
;     global GuiID_SearchCenter, UI_Colors, ThemeMode
;     ...
;     
;     ; 【关键】进入搜索中心前强制关闭 CapsLock
;     SetCapsLockState("AlwaysOff")
;     
;     ... 函数其余代码 ...
; }

; ===================== 【修改】HandleSearchCenterF 函数添加 =====================
; 在 HandleSearchCenterF 函数（约第 23566 行）开头添加：

; HandleSearchCenterF() {
;     global SearchCenterActiveArea, SearchCenterResultLV, SearchCenterSearchResults
;     ...
;     
;     ; 【关键】处理 F 键时强制关闭 CapsLock
;     SetCapsLockState("AlwaysOff")
;     
;     ... 函数其余代码 ...
; }

; ======================================================================================================================
; 快速修复步骤：
; ======================================================================================================================
;
; 1. 在脚本第 1 行后添加：
;    #InstallKeybdHook
;    SetCapsLockState("AlwaysOff")
;    Loop 5 { SetCapsLockState("AlwaysOff") Sleep(50) }
;    SetTimer(ForceCapsLockOff, 100)
;
; 2. 将 ~CapsLock:: 改为 CapsLock::
;
; 3. 在 f:: 热键开头和结尾添加 SetCapsLockState("AlwaysOff")
;
; 4. 在 ShowSearchCenter() 开头添加 SetCapsLockState("AlwaysOff")
;
; 5. 保存并重启脚本
;
; ======================================================================================================================
