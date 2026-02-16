; ======================================================================================================================
; CapsLock 状态冲突修复补丁
; 版本: 1.0.0
; 修复问题:
;   - 使用 CapsLock+快捷键后，大写状态被异常激活
;   - 单击 CapsLock 无法正常切换中文输入法
; ======================================================================================================================

; ===================== 修复方案说明 =====================
; 【核心问题】使用了 ~ 前缀导致系统与脚本同时处理 CapsLock，产生状态冲突
; 【解决方案】移除 ~ 前缀，完全接管 CapsLock 按键处理
; 【副作用】需要手动处理 CapsLock 的原始功能（大小写切换）

; ===================== 替换原始 ~CapsLock:: 热键 =====================
; 【使用说明】
; 1. 在主脚本中找到 ~CapsLock:: 热键（约第 3799 行）
; 2. 将整个 ~CapsLock:: 到下一个 #HotIf 之间的代码替换为以下内容
; 3. 或者在主脚本末尾添加此代码来覆盖原始热键（推荐）

; 【方法1】在主脚本末尾添加此代码块来覆盖（推荐）
; 【方法2】直接修改 ~CapsLock:: 为 CapsLock:: 并应用以下逻辑

#HotIf  ; 确保在全局热键上下文

; ===================== 修复后的 CapsLock 处理（完全接管）=====================
; 【重要】移除了 ~ 前缀，完全接管 CapsLock 按键
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
    
    ; 【关键修复1】记录初始状态
    local InitialCapsLockState := GetKeyState("CapsLock", "T")
    local WasCapsLockOn := InitialCapsLockState  ; 保存原始状态用于后续比较
    
    ; 【关键修复2】立即关闭 CapsLock，防止系统切换大写状态
    ; 由于移除了 ~ 前缀，这里需要主动管理状态
    SetCapsLockState("Off")
    
    ; 标记 CapsLock 已按下
    CapsLock := true
    CapsLock2 := true  ; 初始化为 true，如果使用了功能会被清除
    IsCommandMode := false
    
    ; 记录按下时间
    CapsLockPressTime := A_TickCount
    
    ; ========== 语音输入/搜索模式处理 ==========
    if (VoiceInputActive || VoiceSearchActive) {
        ; 设置定时器：300ms 后清除 CapsLock2
        SetTimer(ClearCapsLock2Timer, -300)
        
        ; 如果未暂停，则暂停语音输入
        if (!VoiceInputPaused) {
            VoiceInputPaused := true
            UpdateVoiceInputPausedState(true)
            
            ; 使用 Cursor 的快捷键 Ctrl+Shift+Space 暂停语音输入
            if (VoiceInputActive) {
                Send("^+{Space}")
                Sleep(200)
            }
        }
        
        ; 等待 CapsLock 释放
        KeyWait("CapsLock")
        
        ; 停止定时器
        SetTimer(ClearCapsLock2Timer, 0)
        
        ; 计算按下时长
        PressDuration := A_TickCount - CapsLockPressTime
        
        ; 如果只按了CapsLock（没有按其他键），且是短按，则恢复语音
        if (CapsLock2 && PressDuration < 1500) {
            if (VoiceInputPaused) {
                VoiceInputPaused := false
                if (VoiceInputActive) {
                    UpdateVoiceInputPausedState(false)
                }
                
                ; 使用 Cursor 的快捷键恢复语音输入
                if (VoiceInputActive) {
                    Send("^+{Space}")
                    Sleep(200)
                }
            }
        }
        
        ; 【关键修复3】语音模式结束后，恢复到按下前的状态
        ; 添加短暂延迟确保之前的 Send 命令完成
        Sleep(50)
        SetCapsLockState("Off")
        Sleep(10)
        SetCapsLockState(InitialCapsLockState)
        
        CapsLock := false
        CapsLock2 := false
        return
    }
    
    ; ========== 正常 CapsLock+ 逻辑 ==========
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
    
    ; 【关键修复4】释放时首先强制关闭 CapsLock
    ; 这样可以清除任何可能由系统或之前的操作导致的残留状态
    SetCapsLockState("Off")
    Sleep(10)  ; 短暂延迟确保状态生效
    
    ; 检查面板是否已显示（长按触发）
    if (PanelVisible) {
        ; 面板已显示，说明是长按，恢复初始状态
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
        ; 模拟原始 CapsLock 行为：切换大小写状态
        SetCapsLockState(!InitialCapsLockState)
        CapsLock := false
    }
    
    ; 清除标记
    CapsLock2 := false
    IsCommandMode := false
}

#HotIf

; ===================== 额外的修复措施 =====================

; 【可选】在脚本启动时重置 CapsLock 状态，确保初始状态正确
ResetCapsLockState() {
    ; 强制关闭 CapsLock，确保初始状态一致
    SetCapsLockState("Off")
}

; 【可选】定时检查 CapsLock 状态，防止异常激活
; 如果检测到 CapsLock 被意外激活，自动关闭
PreventCapsLockStuck() {
    static LastCheckTime := 0
    static LastCapsLockState := false
    
    CurrentTime := A_TickCount
    if (CurrentTime - LastCheckTime < 1000) {  ; 每秒检查一次
        return
    }
    LastCheckTime := CurrentTime
    
    CurrentState := GetKeyState("CapsLock", "T")
    
    ; 如果 CapsLock 意外开启（没有用户操作），自动关闭
    ; 这里可以根据需要添加更多判断逻辑
    if (CurrentState && !LastCapsLockState) {
        ; CapsLock 状态从未知变为开启，可能是异常
        ; 检查是否是在合理的时间窗口内
        ; 这里只是示例，实际逻辑需要根据使用情况调整
    }
    
    LastCapsLockState := CurrentState
}

; ===================== 使用方法 =====================
; 
; 【方法一：直接替换】（推荐）
; 1. 打开 CursorHelper (1).ahk
; 2. 找到 ~CapsLock:: （约第 3799 行）
; 3. 删除从 ~CapsLock:: 到对应 #HotIf 之间的所有代码
; 4. 将上面的 CapsLock:: 代码复制粘贴到该位置
;
; 【方法二：覆盖定义】
; 1. 将此文件保存为 CapsLock_Fix.ahk
; 2. 在 CursorHelper (1).ahk 的末尾添加：#Include CapsLock_Fix.ahk
; 3. 注意：确保此热键定义在原始 ~CapsLock:: 之后，以覆盖原始定义
;
; 【验证修复】
; 1. 重启脚本
; 2. 测试 CapsLock + F：应该打开搜索中心，CapsLock 灯不应该亮
; 3. 测试单击 CapsLock：应该正常切换大小写，用于切换中文输入法
; 4. 测试 CapsLock + C：应该复制内容，CapsLock 状态不变

; ======================================================================================================================
