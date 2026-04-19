#Requires AutoHotkey v2.0

; CapsLock 组合动态热键逻辑（由主脚本 #HotIf 调用）


; ===================== 动态快捷键处理函数 =====================
; 检查按键是否匹配配置的快捷键，如果匹配则执行相应操作
HandleDynamicHotkey(PressedKey, ActionType) {
    global HotkeyESC, HotkeyC, HotkeyV, HotkeyX, HotkeyE, HotkeyR, HotkeyO, HotkeyQ, HotkeyZ, HotkeyT, HotkeyF, HotkeyP
    global CapsLock2, PanelVisible, VoiceInputActive, CapsLock, VoiceSearchActive
    global QuickActionButtons
    
    ; 如果使用了组合快捷键，清除显示面板的定时器（防止面板被激活）
    SetTimer(ShowPanelTimer, 0)  ; 停止ShowPanelTimer定时器
    ; 清除CapsLock2标记，防止面板被激活
    CapsLock2 := false
    RestoreCapsLockAfterChord()
    
    ; 将按键转换为小写进行比较（ESC特殊处理）
    KeyLower := StrLower(PressedKey)
    ConfigKey := ""

    ; 截图助手优先：当截图助手打开时，Q/E/C/R/Z/F/X/Esc 统一切到截图工具栏动作
    if (HandleScreenshotEditorHotkey(ActionType)) {
        return true
    }
    
    ; 首先检查是否匹配快捷操作按钮配置的快捷键
    if (PanelVisible && QuickActionButtons.Length > 0) {
        for Index, Button in QuickActionButtons {
            btnType := ""
            btnHotkey := ""
            if (Button is Map) {
                btnType := Button.Get("Type", "")
                btnHotkey := Button.Get("Hotkey", "")
            } else if (IsObject(Button)) {
                if Button.HasProp("Type")
                    btnType := Button.Type
                if Button.HasProp("Hotkey")
                    btnHotkey := Button.Hotkey
            }
            if (StrLower(btnHotkey) = KeyLower) {
                ; 匹配到快捷操作按钮（CapsLock2已在上面清除）
                ; 立即隐藏面板
                if (PanelVisible) {
                    HideCursorPanel()
                }
                switch btnType {
                    case "Explain":
                        ExecutePrompt("Explain")
                    case "Refactor":
                        ExecutePrompt("Refactor")
                    case "Optimize":
                        ExecutePrompt("Optimize")
                    case "Config":
                        ShowConfigGUI()
                    case "Copy":
                        CapsLockCopy()
                    case "Paste":
                        CapsLockPaste()
                    case "Clipboard":
                        CP_Show()
                    case "Voice":
                        StartVoiceInput()
                    case "Split":
                        SplitCode()
                    case "Batch":
                        BatchOperation()
                    case "CommandPalette":
                        ExecuteCursorShortcut(GetCursorActionShortcut("CommandPalette"))
                    case "Terminal":
                        ExecuteCursorShortcut(GetCursorActionShortcut("Terminal"))
                    case "GlobalSearch":
                        ExecuteCursorShortcut(GetCursorActionShortcut("GlobalSearch"))
                    case "Explorer":
                        ExecuteCursorShortcut(GetCursorActionShortcut("Explorer"))
                    case "SourceControl":
                        ExecuteCursorShortcut(GetCursorActionShortcut("SourceControl"))
                    case "Extensions":
                        ExecuteCursorShortcut(GetCursorActionShortcut("Extensions"))
                    case "Browser":
                        ExecuteCursorShortcut(GetCursorActionShortcut("Browser"))
                    case "Settings":
                        ExecuteCursorShortcut(GetCursorActionShortcut("Settings"))
                    case "CursorSettings":
                        ExecuteCursorShortcut(GetCursorActionShortcut("CursorSettings"))
                }
                return true  ; 已处理
            }
        }
    }
    
    ; 根据操作类型获取配置的快捷键
    switch ActionType {
        case "ESC": ConfigKey := StrLower(HotkeyESC)
        case "C": ConfigKey := StrLower(HotkeyC)
        case "V": ConfigKey := StrLower(HotkeyV)
        case "X": ConfigKey := StrLower(HotkeyX)
        case "E": ConfigKey := StrLower(HotkeyE)
        case "R": ConfigKey := StrLower(HotkeyR)
        case "O": ConfigKey := StrLower(HotkeyO)
        case "Q": ConfigKey := StrLower(HotkeyQ)
        case "Z": ConfigKey := StrLower(HotkeyZ)
        case "F": ConfigKey := StrLower(HotkeyF)
        case "T": ConfigKey := StrLower(HotkeyT)
        case "P": ConfigKey := StrLower(HotkeyP)
    }
    
    ; 如果按键匹配配置的快捷键，执行操作
    ; 添加调试信息
    if (KeyLower = ConfigKey || (ActionType = "ESC" && (PressedKey = "Esc" || KeyLower = "esc"))) {
        ; 【关键修复】对于 F 键，需要先检查语音搜索面板状态，避免影响弹出菜单
        ; 如果是 F 键且语音搜索面板已显示，不隐藏快捷操作面板，避免影响菜单状态
        global VoiceSearchPanelVisible
        if (ActionType = "F") {
            ; 确保变量已初始化
            if (!IsSet(VoiceSearchPanelVisible)) {
                VoiceSearchPanelVisible := false
            }
            ; 如果语音搜索面板已显示，不隐藏快捷操作面板，避免影响菜单状态
            if (!VoiceSearchPanelVisible && PanelVisible) {
                HideCursorPanel()
            }
        } else {
            ; 其他快捷键操作都应该隐藏面板
            if (PanelVisible) {
                HideCursorPanel()
            }
        }
        
        switch ActionType {
            case "ESC":
                CapsLock2 := false
            case "C":
                ; 【关键修复】检查是否在标签切换期间，如果是则不执行复制
                global CapsLockCopyInProgress, CapsLockCopyEndTime, GuiID_ClipboardManager
                
                ; 双重检查：1. 检查是否是标签切换期间
                if (CapsLockCopyInProgress && CapsLockCopyEndTime > A_TickCount) {
                    ; 在标签切换期间，不执行复制操作
                    return true  ; 已处理（阻止复制）
                }
                
                ; 双重检查：2. 如果剪贴板管理面板已打开，额外检查是否是标签点击期间
                ; 这个检查是为了防止在点击标签时，CapsLock 键还处于按下状态导致的意外触发
                if (GuiID_ClipboardManager != 0 && CapsLockCopyInProgress && CapsLockCopyEndTime > A_TickCount) {
                    ; 在标签点击期间且剪贴板管理面板打开时，不执行复制操作
                    return true  ; 已处理（阻止复制）
                }
                
                ; 确保 CapsLock 变量保持为 true，直到复制完成
                global CapsLock
                CapsLock := true
                ; 调用复制函数
                CapsLockCopy()
            case "V":
                CapsLockPaste()
            case "X":
                CapsLock2 := false
                CP_Show()
            case "E":
                CapsLock2 := false
                ExecutePrompt("Explain")
            case "R":
                CapsLock2 := false
                ExecutePrompt("Refactor")
            case "O":
                CapsLock2 := false
                ExecutePrompt("Optimize")
            case "Q":
                CapsLock2 := false
                ShowConfigGUI()
            case "Z":
                CapsLock2 := false
                if (VoiceInputActive) {
                    ; 如果正在语音输入，直接发送
                    if (CapsLock) {
                        CapsLock := false
                    }
                    StopVoiceInput()
                } else {
                    ; 如果未在语音输入，开始语音输入
                    StartVoiceInput()
                }
            case "F":
                CapsLock2 := false
                global VoiceSearchActive
                ; 【关键修复】确保变量已初始化
                if (!IsSet(VoiceSearchPanelVisible)) {
                    VoiceSearchPanelVisible := false
                }
                if (!IsSet(VoiceSearchActive)) {
                    VoiceSearchActive := false
                }
                if (VoiceSearchPanelVisible) {
                    ; 面板已显示
                    if (VoiceSearchActive) {
                        ; 正在语音输入，停止并执行搜索
                        if (CapsLock) {
                            CapsLock := false
                        }
                        StopVoiceInputInSearch()
                        ; 等待一下让内容填入输入框
                        Sleep(300)
                        ExecuteVoiceSearch()
                    } else {
                        ; 未在语音输入，切换焦点并开始语音输入
                        FocusVoiceSearchInput()
                        Sleep(200)
                        StartVoiceInputInSearch()
                    }
                } else {
                    ; 面板未显示，显示面板
                    ; 【关键修复】如果快捷操作面板正在显示，先关闭它（在 StartVoiceSearch 中处理）
                    StartVoiceSearch()
                }
            case "P":
                CapsLock2 := false
                ; CapsLock+P：提示词快捷采集（区域截图请用 CapsLock+T 智能截图菜单）
                try PromptQuickPad_OpenCaptureDraft("", true)
                catch as e {
                    TrayTip("无法打开提示词采集：`n" . e.Message, GetText("tip"), "Iconx 2")
                }
            case "T":
                CapsLock2 := false
                ; 执行截图，完成后弹出智能菜单
                try {
                    ExecuteScreenshotWithMenu()
                } catch as e {
                    TrayTip("错误", "执行截图失败: " . e.Message, "Iconx 2")
                }
        }
        return true  ; 已处理
    }
    return false  ; 未匹配，需要发送原始按键
}
