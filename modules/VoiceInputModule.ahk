; VoiceInputModule.ahk — 语音输入 / 语音搜索（由 CursorHelper 中枢 #Include）
; 依赖宿主：GetText、FormatText、HoverBtn、OnWindowSize、RestoreWindowPosition、GetWindowScreenIndex、
; GetScreenInfo、GetPanelPosition、HideCursorPanel、QueueWindowPositionSave、FlushPendingWindowPositions、
; ArrayContainsValue、ConfigFile、CursorPath、AISleepTime、PanelVisible、UI_Colors、ThemeMode、Language、
; GetCLIAgentLaunchInfo、ShouldUseNativeCLITerminal、OpenCLIAgentTerminal、DispatchPromptToCLIAgent、InvokePythonCLIBridge 等。

VoiceButtonAction(*) {
    HideCursorPanel()
    StartVoiceInput()
}

; ===================== 保存语音输入面板窗口位置 =====================
SaveVoiceInputPanelPosition() {
    global GuiID_VoiceInputPanel
    try {
        ; 检查窗口是否还存在
        if (!GuiID_VoiceInputPanel || GuiID_VoiceInputPanel = 0) {
            ; 窗口已关闭，停止定时器并立即保存所有待保存的位置
            SetTimer(() => SaveVoiceInputPanelPosition(), 0)
            FlushPendingWindowPositions()
            return
        }
        
        ; 获取窗口位置和大小
        WinGetPos(&WinX, &WinY, &WinW, &WinH, GuiID_VoiceInputPanel.Hwnd)
        WindowName := GetText("voice_input_active")
        ; 使用延迟保存，统一管理
        QueueWindowPositionSave(WindowName, WinX, WinY, WinW, WinH)
    } catch as err {
        ; 忽略错误（窗口可能已关闭）
    }
}

; ===================== 保存语音搜索输入窗口位置 =====================
SaveVoiceInputPosition() {
    global GuiID_VoiceInput
    try {
        ; 检查窗口是否还存在
        if (!GuiID_VoiceInput || GuiID_VoiceInput = 0) {
            ; 窗口已关闭，停止定时器并立即保存所有待保存的位置
            SetTimer(() => SaveVoiceInputPosition(), 0)
            FlushPendingWindowPositions()
            return
        }
        
        ; 获取窗口位置和大小
        WinGetPos(&WinX, &WinY, &WinW, &WinH, GuiID_VoiceInput.Hwnd)
        WindowName := GetText("voice_search_title")
        ; 使用延迟保存，统一管理
        QueueWindowPositionSave(WindowName, WinX, WinY, WinW, WinH)
    } catch as err {
        ; 忽略错误（窗口可能已关闭）
    }
}
; ===================== 语音输入功能 =====================

; 检测输入法类型（改进版：多方法检测）
DetectInputMethod() {
    ; 检测百度输入法进程（常见进程名）
    BaiduProcesses := ["BaiduIME.exe", "BaiduPinyin.exe", "bdpinyin.exe", "BaiduInput.exe", "BaiduPinyinService.exe"]
    
    ; 检测讯飞输入法进程（常见进程名）
    ; 讯飞输入法的主要进程：XunfeiIME.exe, XunfeiInput.exe, XunfeiPinyin.exe
    XunfeiProcesses := ["XunfeiIME.exe", "XunfeiInput.exe", "XunfeiPinyin.exe", "XunfeiCloud.exe", "Xunfei.exe"]
    
    ; 方法1：通过进程检测（优先检测讯飞，因为进程名更独特）
    for Index, ProcessName in XunfeiProcesses {
        try {
            if (ProcessExist(ProcessName)) {
                return "xunfei"
            }
        }
    }
    
    ; 检测百度输入法
    for Index, ProcessName in BaiduProcesses {
        try {
            if (ProcessExist(ProcessName)) {
                return "baidu"
            }
        }
    }
    
    ; 方法2：通过窗口类名检测（更准确）
    ; 尝试检测当前活动的输入法窗口
    try {
        ; 检测讯飞输入法窗口（常见的窗口类名）
        if WinExist("ahk_class XunfeiIME") || WinExist("ahk_class XunfeiInput") || WinExist("ahk_class XunfeiPinyin") {
            return "xunfei"
        }
        ; 检测百度输入法窗口
        if WinExist("ahk_class BaiduIME") || WinExist("ahk_class BaiduPinyin") || WinExist("ahk_class BaiduInput") {
            return "baidu"
        }
    }
    
    ; 方法3：通过注册表检测（备用方案）
    try {
        ; 检测讯飞输入法注册表项
        try {
            RegRead("HKEY_CURRENT_USER\Software\Xunfei", "", "")
            return "xunfei"
        }
        ; 检测百度输入法注册表项
        try {
            RegRead("HKEY_CURRENT_USER\Software\Baidu", "", "")
            return "baidu"
        }
    }
    
    ; 如果都检测不到，默认尝试百度方案（因为百度更常见）
    ; 但提示用户可能需要手动选择
    return "baidu"
}

; 开始语音输入
StartVoiceInput() {
    global VoiceInputActive, VoiceInputContent, CursorPath, AISleepTime, PanelVisible, VoiceInputPaused
    
    if (VoiceInputActive) {
        ; 如果已经在语音输入中，检查是否暂停
        if (VoiceInputPaused) {
            ; 如果暂停，继续录制
            ResumeVoiceInput()
            return
        }
        return
    }
    
    ; 如果快捷操作面板正在显示，先关闭它
    if (PanelVisible) {
        HideCursorPanel()
    }
    
    try {
        if !WinExist("ahk_exe Cursor.exe") {
            if (CursorPath != "" && FileExist(CursorPath)) {
                Run(CursorPath)
                Sleep(AISleepTime)
            } else {
                TrayTip(GetText("cursor_not_running_error"), GetText("error"), "Iconx 2")
                return
            }
        }
        
        WinActivate("ahk_exe Cursor.exe")
        WinWaitActive("ahk_exe Cursor.exe", , 2)
        Sleep(300)
        
        Send("{Esc}")
        Sleep(100)
        Send("^l")
        Sleep(500)
        
        if !WinActive("ahk_exe Cursor.exe") {
            WinActivate("ahk_exe Cursor.exe")
            Sleep(200)
        }
        
        ; 确保窗口已激活
        WinWaitActive("ahk_exe Cursor.exe", , 1)
        Sleep(200)
        
        ; 清空输入框，避免复制到旧内容
        Send("^a")
        Sleep(100)
        Send("{Delete}")
        Sleep(100)
        
        ; 使用 Cursor 的快捷键 Ctrl+Shift+Space 启动语音输入
        ; 确保在 Cursor 窗口处于活动状态时发送
        if !WinActive("ahk_exe Cursor.exe") {
            ; 如果窗口未激活，再次尝试激活
            WinActivate("ahk_exe Cursor.exe")
            WinWaitActive("ahk_exe Cursor.exe", , 2)
            Sleep(300)
        }
        
        ; 确保窗口真正激活后再发送快捷键
        if WinActive("ahk_exe Cursor.exe") {
            ; 发送 Ctrl+Shift+Space 启动语音输入
            Send("^+{Space}")
            Sleep(800)  ; 增加等待时间，确保语音输入启动
        } else {
            ; 如果仍然无法激活，显示错误提示
            TrayTip("无法激活 Cursor 窗口", GetText("error"), "Iconx 2")
            return
        }
        
        VoiceInputActive := true
        VoiceInputPaused := false
        VoiceInputContent := ""
        ShowVoiceInputPanel()
    } catch as e {
        TrayTip(GetText("voice_input_failed") . ": " . e.Message, GetText("error"), "Iconx 2")
    }
}

; 结束语音输入并发送
StopVoiceInput() {
    global VoiceInputActive, VoiceInputContent, CapsLock
    
    if (!VoiceInputActive) {
        return
    }
    
    try {
        ; 先确保CapsLock状态被重置，避免影响后续操作
        if (CapsLock) {
            CapsLock := false
        }
        
        ; 确保 Cursor 窗口处于活动状态
        if !WinExist("ahk_exe Cursor.exe") {
            VoiceInputActive := false
            VoiceInputPaused := false
            HideVoiceInputPanel()
            return
        }
        
        WinActivate("ahk_exe Cursor.exe")
        WinWaitActive("ahk_exe Cursor.exe", , 2)
        Sleep(200)
        
        ; 使用 Cursor 的快捷键 Ctrl+Shift+Space 停止语音输入
        Send("^+{Space}")
        Sleep(800)  ; 等待语音识别完成并填入内容
        
        ; Cursor 的语音输入会自动将识别内容填入输入框
        ; 直接发送 Enter 键提交内容
        Send("{Enter}")
        Sleep(200)
        
        VoiceInputActive := false
        VoiceInputPaused := false
        HideVoiceInputPanel()
    } catch as e {
        VoiceInputActive := false
        VoiceInputPaused := false
        HideVoiceInputPanel()
        TrayTip(GetText("voice_input_failed") . ": " . e.Message, GetText("error"), "Iconx 2")
    }
}

; 暂停语音输入
PauseVoiceInput() {
    global VoiceInputActive, VoiceInputPaused
    
    if (!VoiceInputActive || VoiceInputPaused) {
        return
    }
    
    try {
        ; 确保 Cursor 窗口处于活动状态
        if !WinExist("ahk_exe Cursor.exe") {
            return
        }
        
        WinActivate("ahk_exe Cursor.exe")
        WinWaitActive("ahk_exe Cursor.exe", , 2)
        Sleep(200)
        
        ; 使用 Cursor 的快捷键 Ctrl+Shift+Space 暂停语音输入
        Send("^+{Space}")
        Sleep(300)
        
        VoiceInputPaused := true
        UpdateVoiceInputPanelState()
    } catch as e {
        TrayTip(GetText("voice_input_failed") . ": " . e.Message, GetText("error"), "Iconx 2")
    }
}

; 继续语音输入
ResumeVoiceInput() {
    global VoiceInputActive, VoiceInputPaused
    
    if (!VoiceInputActive || !VoiceInputPaused) {
        return
    }
    
    try {
        ; 确保 Cursor 窗口处于活动状态
        if !WinExist("ahk_exe Cursor.exe") {
            return
        }
        
        WinActivate("ahk_exe Cursor.exe")
        WinWaitActive("ahk_exe Cursor.exe", , 2)
        Sleep(200)
        
        ; 使用 Cursor 的快捷键 Ctrl+Shift+Space 继续语音输入
        Send("^+{Space}")
        Sleep(300)
        
        VoiceInputPaused := false
        UpdateVoiceInputPanelState()
    } catch as e {
        TrayTip(GetText("voice_input_failed") . ": " . e.Message, GetText("error"), "Iconx 2")
    }
}

; 显示语音输入面板（屏幕中心）
ShowVoiceInputPanel() {
    global GuiID_VoiceInputPanel, VoiceInputActive, VoiceInputScreenIndex, UI_Colors, VoiceInputPaused
    global VoiceInputSendBtn, VoiceInputPauseBtn, VoiceInputAnimationText, VoiceInputStatusText
    
    ; 【关键修复】确保所有必需的变量都已初始化
    if (!IsSet(UI_Colors) || !IsObject(UI_Colors)) {
        ; 如果 UI_Colors 未初始化，使用默认暗色主题
        global UI_Colors_Dark
        if (!IsSet(UI_Colors_Dark)) {
            ; 使用 html.to.design 风格配色作为默认值
            UI_Colors_Dark := {Background: "0a0a0a", Text: "f5f5f5", BtnBg: "1a1a1a", BtnHover: "2a2a2a", BtnPrimary: "e67e22", BtnPrimaryHover: "d35400"}
        }
        UI_Colors := UI_Colors_Dark
    }
    
    if (!IsSet(VoiceInputScreenIndex) || VoiceInputScreenIndex = "") {
        VoiceInputScreenIndex := 1
    }
    
    if (!IsSet(VoiceInputPaused)) {
        VoiceInputPaused := false
    }
    
    if (GuiID_VoiceInputPanel != 0) {
        try {
            GuiID_VoiceInputPanel.Destroy()
        }
        GuiID_VoiceInputPanel := 0
    }
    
    GuiID_VoiceInputPanel := Gui("+AlwaysOnTop +ToolWindow -Caption -DPIScale +Resize -MaximizeBox")
    GuiID_VoiceInputPanel.BackColor := UI_Colors.Background
    
    PanelWidth := 280
    PanelHeight := 120
    
    ; 添加窗口大小改变和移动事件处理
    GuiID_VoiceInputPanel.OnEvent("Size", OnWindowSize)
    ; 注意：AutoHotkey v2 不支持 Move 事件，使用定时器定期保存位置
    ; GuiID_VoiceInputPanel.OnEvent("Move", OnWindowMove)
    SetTimer(() => SaveVoiceInputPanelPosition(), 500)
    
    ; 状态文本
    YPos := 15
    VoiceInputStatusText := GuiID_VoiceInputPanel.Add("Text", "x20 y" . YPos . " w240 h25 c" . UI_Colors.Text, GetText("voice_input_active"))
    VoiceInputStatusText.SetFont("s12 Bold", "Segoe UI")
    
    ; 动画文本
    YPos += 30
    VoiceInputAnimationText := GuiID_VoiceInputPanel.Add("Text", "x20 y" . YPos . " w240 h25 Center c00FF00", "● ● ●")
    VoiceInputAnimationText.SetFont("s14", "Segoe UI")
    
    ; 按钮区域
    YPos += 35
    ButtonWidth := 100
    ButtonHeight := 30
    ButtonSpacing := 20
    
    ; 发送按钮
    SendBtnX := 20
    VoiceInputSendBtn := GuiID_VoiceInputPanel.Add("Text", "x" . SendBtnX . " y" . YPos . " w" . ButtonWidth . " h" . ButtonHeight . " Center 0x200 cFFFFFF Background" . UI_Colors.BtnPrimary . " vVoiceInputSendBtn", GetText("send_to_cursor"))
    VoiceInputSendBtn.SetFont("s10 Bold", "Segoe UI")
    VoiceInputSendBtn.OnEvent("Click", FinishAndSendVoiceInput)
    HoverBtn(VoiceInputSendBtn, UI_Colors.BtnPrimary, UI_Colors.BtnPrimaryHover)
    
    ; 暂停/继续按钮
    PauseBtnX := SendBtnX + ButtonWidth + ButtonSpacing
    PauseBtnText := VoiceInputPaused ? GetText("resume") : GetText("pause")
    VoiceInputPauseBtn := GuiID_VoiceInputPanel.Add("Text", "x" . PauseBtnX . " y" . YPos . " w" . ButtonWidth . " h" . ButtonHeight . " Center 0x200 cFFFFFF Background" . UI_Colors.BtnBg . " vVoiceInputPauseBtn", PauseBtnText)
    VoiceInputPauseBtn.SetFont("s10", "Segoe UI")
    VoiceInputPauseBtn.OnEvent("Click", ToggleVoiceInputPause)
    HoverBtn(VoiceInputPauseBtn, UI_Colors.BtnBg, UI_Colors.BtnHover)
    
    ; 关闭按钮（右上角）
    CloseBtnSize := 25
    CloseBtnX := PanelWidth - CloseBtnSize - 5
    CloseBtnY := 5
    VoiceInputCloseBtn := GuiID_VoiceInputPanel.Add("Text", "x" . CloseBtnX . " y" . CloseBtnY . " w" . CloseBtnSize . " h" . CloseBtnSize . " Center 0x200 cFFFFFF Background" . UI_Colors.BtnBg . " vVoiceInputCloseBtn", "✕")
    VoiceInputCloseBtn.SetFont("s12", "Segoe UI")
    VoiceInputCloseBtn.OnEvent("Click", (*) => HideVoiceInputPanel())
    HoverBtn(VoiceInputCloseBtn, UI_Colors.BtnBg, "e81123")
    
    ; 启动动画定时器
    SetTimer(UpdateVoiceAnimation, 500)
    
    ; 恢复窗口位置和大小
    WindowName := "VoiceInputPanel"
    RestoredPos := RestoreWindowPosition(WindowName, PanelWidth, PanelHeight)
    if (RestoredPos.X = -1 || RestoredPos.Y = -1) {
        ; 获取 Cursor 窗口所在的屏幕索引，并在该屏幕中心显示面板
        try {
            CursorScreenIndex := GetWindowScreenIndex("ahk_exe Cursor.exe")
            ScreenInfo := GetScreenInfo(CursorScreenIndex)
            ; 使用 GetPanelPosition 函数计算中心位置
            Pos := GetPanelPosition(ScreenInfo, PanelWidth, PanelHeight, "Center")
            RestoredPos.X := Pos.X
            RestoredPos.Y := Pos.Y
        } catch as err {
            ; 如果出错，使用默认屏幕的中心位置
            ScreenInfo := GetScreenInfo(1)
            Pos := GetPanelPosition(ScreenInfo, PanelWidth, PanelHeight, "Center")
            RestoredPos.X := Pos.X
            RestoredPos.Y := Pos.Y
        }
    }
    
    ; 添加 Escape 键关闭命令
    GuiID_VoiceInputPanel.OnEvent("Escape", (*) => HideVoiceInputPanel())
    
    GuiID_VoiceInputPanel.Show("w" . RestoredPos.Width . " h" . RestoredPos.Height . " x" . RestoredPos.X . " y" . RestoredPos.Y . " NoActivate")
    WinSetAlwaysOnTop(1, GuiID_VoiceInputPanel.Hwnd)
}

; 更新语音输入面板状态
UpdateVoiceInputPanelState() {
    global VoiceInputPaused, VoiceInputPauseBtn, VoiceInputStatusText
    
    if (!VoiceInputPauseBtn || !VoiceInputStatusText) {
        return
    }
    
    try {
        ; 更新暂停按钮文本
        PauseBtnText := VoiceInputPaused ? GetText("resume") : GetText("pause")
        VoiceInputPauseBtn.Text := PauseBtnText
        
        ; 更新状态文本
        if (VoiceInputPaused) {
            VoiceInputStatusText.Text := GetText("voice_input_paused")
        } else {
            VoiceInputStatusText.Text := GetText("voice_input_active")
        }
    } catch as err {
        ; 忽略错误
    }
}

; 隐藏语音输入面板
HideVoiceInputPanel() {
    global GuiID_VoiceInputPanel, VoiceInputAnimationText, VoiceInputStatusText, VoiceInputSendBtn, VoiceInputPauseBtn
    global VoiceInputPaused
    
    ; 重置暂停状态
    VoiceInputPaused := false
    
    SetTimer(UpdateVoiceAnimation, 0)
    
    if (GuiID_VoiceInputPanel != 0) {
        try {
            GuiID_VoiceInputPanel.Destroy()
        }
        GuiID_VoiceInputPanel := 0
    }
    VoiceInputAnimationText := 0
    VoiceInputStatusText := 0
    VoiceInputSendBtn := 0
    VoiceInputPauseBtn := 0
}

; 切换暂停/继续
ToggleVoiceInputPause(*) {
    global VoiceInputPaused
    
    if (VoiceInputPaused) {
        ResumeVoiceInput()
    } else {
        PauseVoiceInput()
    }
}

; 完成并发送语音输入到 Cursor
FinishAndSendVoiceInput(*) {
    StopVoiceInput()
}

; 更新语音输入暂停状态
UpdateVoiceInputPausedState(IsPaused) {
    ; 使用新的面板状态更新函数
    UpdateVoiceInputPanelState()
}

; 更新语音输入动画
UpdateVoiceAnimation(*) {
    global VoiceInputActive, VoiceAnimationText, VoiceInputPaused, GuiID_VoiceInputPanel
    
    ; 【关键修复】检查面板是否存在且变量已初始化
    if (!VoiceInputActive || !GuiID_VoiceInputPanel || GuiID_VoiceInputPanel = 0) {
        SetTimer(UpdateVoiceAnimation, 0)
        return
    }
    
    if (!IsSet(VoiceAnimationText) || !VoiceAnimationText || VoiceInputPaused) {
        ; 如果暂停或动画文本未初始化，不更新动画
        return
    }
    
    try {
        static AnimationState := 0
        AnimationState := Mod(AnimationState + 1, 4)
        
        switch AnimationState {
            case 0:
                VoiceAnimationText.Text := "● ○ ○"
            case 1:
                VoiceAnimationText.Text := "○ ● ○"
            case 2:
                VoiceAnimationText.Text := "○ ○ ●"
            case 3:
                VoiceAnimationText.Text := "● ● ●"
        }
    } catch as e {
        ; 如果出错，停止定时器
        SetTimer(UpdateVoiceAnimation, 0)
    }
}


; 显示语音输入操作选择界面（发送到Cursor或搜索）
ShowVoiceInputActionSelection(Content) {
    global GuiID_VoiceInput, VoiceInputScreenIndex, UI_Colors, VoiceSearchSelecting, VoiceSearchEngineButtons
    
    VoiceSearchSelecting := true
    
    if (GuiID_VoiceInput != 0) {
        try {
            GuiID_VoiceInput.Destroy()
        }
        GuiID_VoiceInput := 0
    }
    
    GuiID_VoiceInput := Gui("+AlwaysOnTop +ToolWindow -Caption -DPIScale")
    GuiID_VoiceInput.BackColor := UI_Colors.Background
    GuiID_VoiceInput.SetFont("s12 c" . UI_Colors.Text . " Bold", "Segoe UI")
    
    PanelWidth := 500
    ; 计算所需高度：标题(50) + 内容标签(25) + 内容框(60) + 自动加载开关(35) + 操作标签(30) + 操作按钮(45) + 引擎标签(30) + 按钮区域 + 取消按钮(45) + 边距(20)
    ButtonsRows := Ceil(8 / 4)  ; 每行4个按钮，共8个搜索引擎
    ButtonsAreaHeight := ButtonsRows * 45  ; 每行45px（按钮35px + 间距10px）
    PanelHeight := 50 + 25 + 60 + 35 + 30 + 45 + 30 + ButtonsAreaHeight + 45 + 20
    
    ; 标题
    TitleText := GuiID_VoiceInput.Add("Text", "x0 y15 w500 h30 Center c" . UI_Colors.Text, GetText("select_action"))
    TitleText.SetFont("s14 Bold", "Segoe UI")
    
    ; 显示输入内容
    YPos := 55
    LabelText := GuiID_VoiceInput.Add("Text", "x20 y" . YPos . " w460 h20 c" . UI_Colors.TextDim, GetText("voice_input_content"))
    LabelText.SetFont("s10", "Segoe UI")
    
    YPos += 25
    ContentEdit := GuiID_VoiceInput.Add("Edit", "x20 y" . YPos . " w460 h60 vVoiceInputContentEdit Background" . UI_Colors.InputBg . " c" . UI_Colors.Text . " ReadOnly Multi", Content)
    ContentEdit.SetFont("s11", "Segoe UI")
    
    ; 自动加载选中文本开关
    YPos += 70
    global AutoLoadSelectedText, VoiceInputAutoLoadSwitch
    AutoLoadLabel := GuiID_VoiceInput.Add("Text", "x20 y" . YPos . " w200 h25 c" . UI_Colors.TextDim, GetText("auto_load_selected_text"))
    AutoLoadLabel.SetFont("s10", "Segoe UI")
    ; 创建开关按钮（使用文本按钮模拟开关）
    SwitchText := AutoLoadSelectedText ? GetText("switch_on") : GetText("switch_off")
    SwitchBg := AutoLoadSelectedText ? UI_Colors.BtnHover : UI_Colors.BtnBg
    ; 按钮文字颜色：根据主题调整
    global ThemeMode
    SwitchTextColor := (ThemeMode = "light") ? UI_Colors.Text : "FFFFFF"
    VoiceInputAutoLoadSwitch := GuiID_VoiceInput.Add("Text", "x220 y" . YPos . " w120 h25 Center 0x200 c" . SwitchTextColor . " Background" . SwitchBg . " vVoiceInputAutoLoadSwitch", SwitchText)
    VoiceInputAutoLoadSwitch.SetFont("s10", "Segoe UI")
    VoiceInputAutoLoadSwitch.OnEvent("Click", ToggleAutoLoadSelectedTextForVoiceInput)
    HoverBtn(VoiceInputAutoLoadSwitch, SwitchBg, UI_Colors.BtnHover)
    
    ; 操作选择
    YPos += 35
    LabelAction := GuiID_VoiceInput.Add("Text", "x20 y" . YPos . " w460 h20 c" . UI_Colors.TextDim, GetText("select_action") . ":")
    LabelAction.SetFont("s10", "Segoe UI")
    
    ; 搜索引擎按钮标签（先创建，以便后续引用）
    YPos += 50
    LabelEngine := GuiID_VoiceInput.Add("Text", "x20 y" . YPos . " w460 h20 c" . UI_Colors.TextDim . " vEngineLabel", GetText("select_search_engine"))
    LabelEngine.SetFont("s10", "Segoe UI")
    LabelEngine.Visible := false
    
    ; 操作按钮（在操作标签下方）
    YPos := 55 + 25 + 60 + 70 + 35 + 20 + 10  ; 重新计算YPos位置（标题+标签+输入框+开关间距+开关+操作标签间距+操作标签高度+按钮间距）
    ; 发送到Cursor按钮
    ; 按钮文字颜色：根据主题调整
    global ThemeMode
    ActionBtnTextColor := (ThemeMode = "light") ? UI_Colors.Text : "FFFFFF"
    SendToCursorBtn := GuiID_VoiceInput.Add("Text", "x20 y" . YPos . " w220 h35 Center 0x200 c" . ActionBtnTextColor . " Background" . UI_Colors.BtnBg . " vSendToCursorBtn", GetText("send_to_cursor"))
    SendToCursorBtn.SetFont("s11", "Segoe UI")
    SendToCursorBtn.OnEvent("Click", CreateSendToCursorHandler(Content))
    HoverBtn(SendToCursorBtn, UI_Colors.BtnBg, UI_Colors.BtnHover)
    
    ; 搜索按钮（保存引用以便后续访问）
    global VoiceInputSendToCursorBtn := SendToCursorBtn
    global VoiceInputSearchBtn
    SearchBtn := GuiID_VoiceInput.Add("Text", "x260 y" . YPos . " w220 h35 Center 0x200 c" . ActionBtnTextColor . " Background" . UI_Colors.BtnBg . " vSearchBtn", GetText("voice_search_button"))
    SearchBtn.SetFont("s11", "Segoe UI")
    SearchBtn.OnEvent("Click", CreateShowSearchEnginesHandler(Content, SendToCursorBtn, SearchBtn, LabelEngine))
    VoiceInputSearchBtn := SearchBtn
    HoverBtn(SearchBtn, UI_Colors.BtnBg, UI_Colors.BtnHover)
    
    ; 搜索引擎按钮位置（从LabelEngine下方开始）
    YPos := 55 + 25 + 60 + 70 + 35 + 20 + 10 + 35 + 50  ; 操作按钮下方（标题+标签+输入框+开关间距+开关+操作标签间距+操作标签+按钮间距+操作按钮+引擎标签间距）
    ; 搜索引擎列表
    global VoiceSearchCurrentCategory
    SearchEngines := GetSortedSearchEngines(VoiceSearchCurrentCategory)
    
    VoiceSearchEngineButtons := []
    ButtonWidth := 110
    ButtonHeight := 35
    ButtonSpacing := 10
    StartX := 20
    ButtonsPerRow := 4
    
    for Index, Engine in SearchEngines {
        ; 【修复】添加安全检查，防止访问无效对象属性
        if (!IsObject(Engine) || !Engine.HasProp("Value") || !Engine.HasProp("Name")) {
            continue  ; 跳过无效的引擎对象
        }
        
        Row := Floor((Index - 1) / ButtonsPerRow)
        Col := Mod((Index - 1), ButtonsPerRow)
        BtnX := StartX + Col * (ButtonWidth + ButtonSpacing)
        BtnY := YPos + Row * (ButtonHeight + ButtonSpacing)
        
        ; 创建按钮（初始隐藏）
        ; 按钮文字颜色：根据主题调整
        global ThemeMode
        EngineBtnTextColor := (ThemeMode = "light") ? UI_Colors.Text : "FFFFFF"
        Btn := GuiID_VoiceInput.Add("Text", "x" . BtnX . " y" . BtnY . " w" . ButtonWidth . " h" . ButtonHeight . " Center 0x200 c" . EngineBtnTextColor . " Background" . UI_Colors.BtnBg . " vSearchEngineBtn" . Index, Engine.Name)
        Btn.SetFont("s10", "Segoe UI")
        Btn.OnEvent("Click", CreateSearchEngineClickHandler(Content, Engine.Value))
        Btn.Visible := false
        HoverBtn(Btn, UI_Colors.BtnBg, UI_Colors.BtnHover)
        VoiceSearchEngineButtons.Push(Btn)
    }
    
    ; 取消按钮
    CancelBtnY := YPos + (Floor((SearchEngines.Length - 1) / ButtonsPerRow) + 1) * (ButtonHeight + ButtonSpacing) + 10
    ; 取消按钮颜色：根据主题调整
    global ThemeMode
    CancelBtnTextColor := (ThemeMode = "light") ? UI_Colors.Text : "FFFFFF"
    CancelBtnBg := (ThemeMode = "light") ? UI_Colors.BtnBg : "666666"
    CancelBtn := GuiID_VoiceInput.Add("Text", "x" . (PanelWidth // 2 - 60) . " y" . CancelBtnY . " w120 h35 Center 0x200 c" . CancelBtnTextColor . " Background" . CancelBtnBg . " vCancelBtn", GetText("cancel"))
    CancelBtn.SetFont("s11", "Segoe UI")
    CancelBtn.OnEvent("Click", CancelVoiceInputActionSelection)
    HoverBtn(CancelBtn, "666666", "777777")
    
    ScreenInfo := GetScreenInfo(VoiceInputScreenIndex)
    Pos := GetPanelPosition(ScreenInfo, PanelWidth, PanelHeight, "center")
    GuiID_VoiceInput.Show("w" . PanelWidth . " h" . PanelHeight . " x" . Pos.X . " y" . Pos.Y . " NoActivate")
    WinSetAlwaysOnTop(1, GuiID_VoiceInput.Hwnd)
    
    ; 标记界面已显示
    global VoiceInputActionSelectionVisible
    VoiceInputActionSelectionVisible := true
    
    ; 首先明确停止监听（无论之前状态如何）
    SetTimer(MonitorSelectedTextForVoiceInput, 0)
    
    ; 如果自动加载开关已开启，启动监听；否则确保监听已停止
    if (AutoLoadSelectedText) {
        SetTimer(MonitorSelectedTextForVoiceInput, 200)  ; 每200ms检查一次
    } else {
        ; 明确停止监听，确保不会自动加载
        SetTimer(MonitorSelectedTextForVoiceInput, 0)
    }
}

; 创建发送到Cursor处理函数
CreateSendToCursorHandler(Content) {
    SendToCursorHandler(*) {
        global VoiceSearchSelecting
        VoiceSearchSelecting := false
        HideVoiceInputActionSelection()
        SendVoiceInputToCursor(Content)
    }
    return SendToCursorHandler
}

; 创建显示搜索引擎处理函数
CreateShowSearchEnginesHandler(Content, SendToCursorBtn, SearchBtn, EngineLabel) {
    ShowSearchEnginesHandler(*) {
        global VoiceSearchEngineButtons
        try {
            ; 隐藏操作按钮
            if (SendToCursorBtn) {
                SendToCursorBtn.Visible := false
            }
            if (SearchBtn) {
                SearchBtn.Visible := false
            }
            if (EngineLabel) {
                EngineLabel.Visible := true
            }
            
            ; 显示搜索引擎按钮
            if (IsSet(VoiceSearchEngineButtons) && VoiceSearchEngineButtons.Length > 0) {
                Loop VoiceSearchEngineButtons.Length {
                    Index := A_Index
                    Btn := VoiceSearchEngineButtons[Index]
                    if (Btn) {
                        ; 检查是否是新的按钮结构（对象）还是旧的（直接控件）
                        if (IsObject(Btn) && Btn.Bg) {
                            ; 新结构：显示背景、图标和文字
                            if (Btn.Bg) {
                                Btn.Bg.Visible := true
                            }
                            if (Btn.Icon) {
                                Btn.Icon.Visible := true
                            }
                            if (Btn.Text) {
                                Btn.Text.Visible := true
                            }
                        } else {
                            ; 旧结构：直接显示控件
                            Btn.Visible := true
                        }
                    }
                }
            }
        } catch as err {
            ; 如果出错，直接显示搜索引擎选择界面
            HideVoiceInputActionSelection()
            ShowSearchEngineSelection(Content)
        }
    }
    return ShowSearchEnginesHandler
}

; 取消语音输入操作选择
CancelVoiceInputActionSelection(*) {
    global VoiceSearchSelecting
    VoiceSearchSelecting := false
    HideVoiceInputActionSelection()
}

; 隐藏语音输入操作选择界面
HideVoiceInputActionSelection() {
    global GuiID_VoiceInput, VoiceInputActionSelectionVisible
    
    ; 停止监听选中文本
    SetTimer(MonitorSelectedTextForVoiceInput, 0)
    
    ; 标记界面已隐藏
    VoiceInputActionSelectionVisible := false
    
    if (GuiID_VoiceInput != 0) {
        try {
            GuiID_VoiceInput.Destroy()
        }
        GuiID_VoiceInput := 0
    }
}

; 发送语音输入内容到 Cursor
SendVoiceInputToCursor(Content) {
    global CursorPath, AISleepTime
    
    try {
        if !WinActive("ahk_exe Cursor.exe") {
            WinActivate("ahk_exe Cursor.exe")
            WinWaitActive("ahk_exe Cursor.exe", , 1)
            Sleep(200)
        }
        
        if !WinActive("ahk_exe Cursor.exe") {
            WinActivate("ahk_exe Cursor.exe")
            Sleep(200)
        }
        
        if (Content != "" && StrLen(Content) > 0) {
            ; 确保输入框已打开
            Send("^l")
            Sleep(300)
            
            ; 清空输入框
            Send("^a")
            Sleep(100)
            Send("{Delete}")
            Sleep(100)
            
            ; 输入内容
            A_Clipboard := Content
            Sleep(100)
            Send("^v")
            Sleep(200)
            
            ; 发送
            Send("{Enter}")
            Sleep(300)
            ; 不显示发送成功的提示，避免弹窗干扰
        }
    } catch as e {
        TrayTip(GetText("voice_input_failed") . ": " . e.Message, GetText("error"), "Iconx 2")
    }
}


; ===================== 语音搜索功能 =====================
; 辅助函数：检查数组是否包含某个值
ArrayContainsValue(Arr, Value) {
    ; 【修复】添加安全检查，防止 "Item has no value" 错误
    if (!IsSet(Arr) || !IsObject(Arr) || Arr.Length = 0) {
        return 0
    }
    try {
        for Index, Item in Arr {
            ; 【关键修复】检查 Item 是否有值，防止 "Item has no value" 错误
            try {
                ; 先检查 Item 是否有效，然后再比较
                if (IsSet(Item) && Item = Value) {
                    return Index
                }
            } catch as err {
                ; 如果 Item 没有值或无法比较，跳过该项
                ; 继续下一次循环
            }
        }
    } catch as err {
        return 0
    }
    return 0
}

; 开始语音搜索（显示输入框界面）
StartVoiceSearch() {
    global VoiceSearchActive, VoiceSearchPanelVisible, PanelVisible
    
    ; 【关键修复】确保变量已初始化
    if (!IsSet(VoiceSearchPanelVisible)) {
        VoiceSearchPanelVisible := false
    }
    if (!IsSet(VoiceSearchActive)) {
        VoiceSearchActive := false
    }
    
    ; 自动关闭 CapsLock 大写状态
    SetCapsLockState("Off")
    
    ; 如果面板已显示，切换焦点到输入框并清空，然后激活语音输入
    if (VoiceSearchPanelVisible) {
        FocusVoiceSearchInput()
        Sleep(200)
        ; 如果未在语音输入，开始语音输入
        if (!VoiceSearchActive) {
            StartVoiceInputInSearch()
        }
        return
    }
    
    ; 如果正在语音输入中，先停止
    if (VoiceSearchActive) {
        StopVoiceInputInSearch()
    }
    
    ; 如果快捷操作面板正在显示，先关闭它
    if (PanelVisible) {
        HideCursorPanel()
    }
    
    try {
        ; 显示语音搜索输入界面（会自动激活语音输入）
        ShowVoiceSearchInputPanel()
    } catch as e {
        TrayTip(GetText("voice_search_failed") . ": " . e.Message, GetText("error"), "Iconx 2")
    }
}

; 获取所有搜索引擎（带分类信息）
GetAllSearchEngines() {
    ; 定义所有搜索引擎，每个引擎包含分类信息
    AllEngines := [
        ; AI类
        {Name: GetText("search_engine_deepseek"), Value: "deepseek", Category: "ai"},
        {Name: GetText("search_engine_yuanbao"), Value: "yuanbao", Category: "ai"},
        {Name: GetText("search_engine_doubao"), Value: "doubao", Category: "ai"},
        {Name: GetText("search_engine_zhipu"), Value: "zhipu", Category: "ai"},
        {Name: GetText("search_engine_mita"), Value: "mita", Category: "ai"},
        {Name: GetText("search_engine_wenxin"), Value: "wenxin", Category: "ai"},
        {Name: GetText("search_engine_qianwen"), Value: "qianwen", Category: "ai"},
        {Name: GetText("search_engine_kimi"), Value: "kimi", Category: "ai"},
        {Name: GetText("search_engine_perplexity"), Value: "perplexity", Category: "ai"},
        {Name: GetText("search_engine_copilot"), Value: "copilot", Category: "ai"},
        {Name: GetText("search_engine_chatgpt"), Value: "chatgpt", Category: "ai"},
        {Name: GetText("search_engine_grok"), Value: "grok", Category: "ai"},
        {Name: GetText("search_engine_you"), Value: "you", Category: "ai"},
        {Name: GetText("search_engine_claude"), Value: "claude", Category: "ai"},
        {Name: GetText("search_engine_monica"), Value: "monica", Category: "ai"},
        {Name: GetText("search_engine_webpilot"), Value: "webpilot", Category: "ai"},
        
        ; CLI类
        {Name: GetText("search_engine_cli_codex"), Value: "codex_cli", Category: "cli"},
        {Name: GetText("search_engine_cli_gemini"), Value: "gemini_cli", Category: "cli"},
        {Name: GetText("search_engine_cli_openclaw"), Value: "openclaw_cli", Category: "cli"},
        {Name: GetText("search_engine_cli_qwen"), Value: "qwen_cli", Category: "cli"},
        
        ; 学术类
        {Name: GetText("search_engine_zhihu"), Value: "zhihu", Category: "academic"},
        {Name: GetText("search_engine_wechat_article"), Value: "wechat_article", Category: "academic"},
        {Name: GetText("search_engine_cainiao"), Value: "cainiao", Category: "academic"},
        {Name: GetText("search_engine_gitee"), Value: "gitee", Category: "academic"},
        {Name: GetText("search_engine_pubscholar"), Value: "pubscholar", Category: "academic"},
        {Name: GetText("search_engine_semantic"), Value: "semantic", Category: "academic"},
        {Name: GetText("search_engine_baidu_academic"), Value: "baidu_academic", Category: "academic"},
        {Name: GetText("search_engine_bing_academic"), Value: "bing_academic", Category: "academic"},
        {Name: GetText("search_engine_csdn"), Value: "csdn", Category: "academic"},
        {Name: GetText("search_engine_national_library"), Value: "national_library", Category: "academic"},
        {Name: GetText("search_engine_chaoxing"), Value: "chaoxing", Category: "academic"},
        {Name: GetText("search_engine_cnki"), Value: "cnki", Category: "academic"},
        {Name: GetText("search_engine_wechat_reading"), Value: "wechat_reading", Category: "academic"},
        {Name: GetText("search_engine_dada"), Value: "dada", Category: "academic"},
        {Name: GetText("search_engine_patent"), Value: "patent", Category: "academic"},
        {Name: GetText("search_engine_ip_office"), Value: "ip_office", Category: "academic"},
        {Name: GetText("search_engine_dedao"), Value: "dedao", Category: "academic"},
        {Name: GetText("search_engine_pkmer"), Value: "pkmer", Category: "academic"},
        
        ; 百度类
        {Name: GetText("search_engine_baidu"), Value: "baidu", Category: "baidu"},
        {Name: GetText("search_engine_baidu_title"), Value: "baidu_title", Category: "baidu"},
        {Name: GetText("search_engine_baidu_hanyu"), Value: "baidu_hanyu", Category: "baidu"},
        {Name: GetText("search_engine_baidu_wenku"), Value: "baidu_wenku", Category: "baidu"},
        {Name: GetText("search_engine_baidu_map"), Value: "baidu_map", Category: "baidu"},
        {Name: GetText("search_engine_baidu_pdf"), Value: "baidu_pdf", Category: "baidu"},
        {Name: GetText("search_engine_baidu_doc"), Value: "baidu_doc", Category: "baidu"},
        {Name: GetText("search_engine_baidu_ppt"), Value: "baidu_ppt", Category: "baidu"},
        {Name: GetText("search_engine_baidu_xls"), Value: "baidu_xls", Category: "baidu"},
        
        ; 图片类
        {Name: GetText("search_engine_image_aggregate"), Value: "image_aggregate", Category: "image"},
        {Name: GetText("search_engine_iconfont"), Value: "iconfont", Category: "image"},
        {Name: GetText("search_engine_wenxin_image"), Value: "wenxin_image", Category: "image"},
        {Name: GetText("search_engine_tiangong_image"), Value: "tiangong_image", Category: "image"},
        {Name: GetText("search_engine_yuanbao_image"), Value: "yuanbao_image", Category: "image"},
        {Name: GetText("search_engine_tongyi_image"), Value: "tongyi_image", Category: "image"},
        {Name: GetText("search_engine_zhipu_image"), Value: "zhipu_image", Category: "image"},
        {Name: GetText("search_engine_miaohua"), Value: "miaohua", Category: "image"},
        {Name: GetText("search_engine_keling"), Value: "keling", Category: "image"},
        {Name: GetText("search_engine_jimmeng"), Value: "jimmeng", Category: "image"},
        {Name: GetText("search_engine_baidu_image"), Value: "baidu_image", Category: "image"},
        {Name: GetText("search_engine_shetu"), Value: "shetu", Category: "image"},
        {Name: GetText("search_engine_ai_image_lib"), Value: "ai_image_lib", Category: "image"},
        {Name: GetText("search_engine_huaban"), Value: "huaban", Category: "image"},
        {Name: GetText("search_engine_zcool"), Value: "zcool", Category: "image"},
        {Name: GetText("search_engine_uisdc"), Value: "uisdc", Category: "image"},
        {Name: GetText("search_engine_nipic"), Value: "nipic", Category: "image"},
        {Name: GetText("search_engine_qianku"), Value: "qianku", Category: "image"},
        {Name: GetText("search_engine_qiantu"), Value: "qiantu", Category: "image"},
        {Name: GetText("search_engine_zhongtu"), Value: "zhongtu", Category: "image"},
        {Name: GetText("search_engine_miyuan"), Value: "miyuan", Category: "image"},
        {Name: GetText("search_engine_mizhi"), Value: "mizhi", Category: "image"},
        {Name: GetText("search_engine_icons"), Value: "icons", Category: "image"},
        {Name: GetText("search_engine_tuxing"), Value: "tuxing", Category: "image"},
        {Name: GetText("search_engine_xiangsheji"), Value: "xiangsheji", Category: "image"},
        {Name: GetText("search_engine_bing_image"), Value: "bing_image", Category: "image"},
        {Name: GetText("search_engine_google_image"), Value: "google_image", Category: "image"},
        {Name: GetText("search_engine_weibo_image"), Value: "weibo_image", Category: "image"},
        {Name: GetText("search_engine_sogou_image"), Value: "sogou_image", Category: "image"},
        {Name: GetText("search_engine_haosou_image"), Value: "haosou_image", Category: "image"},
        
        ; 音频类
        {Name: GetText("search_engine_netease_music"), Value: "netease_music", Category: "audio"},
        {Name: GetText("search_engine_tiangong_music"), Value: "tiangong_music", Category: "audio"},
        {Name: GetText("search_engine_text_to_speech"), Value: "text_to_speech", Category: "audio"},
        {Name: GetText("search_engine_speech_to_text"), Value: "speech_to_text", Category: "audio"},
        {Name: GetText("search_engine_shetu_music"), Value: "shetu_music", Category: "audio"},
        {Name: GetText("search_engine_qq_music"), Value: "qq_music", Category: "audio"},
        {Name: GetText("search_engine_kuwo"), Value: "kuwo", Category: "audio"},
        {Name: GetText("search_engine_kugou"), Value: "kugou", Category: "audio"},
        {Name: GetText("search_engine_qianqian"), Value: "qianqian", Category: "audio"},
        {Name: GetText("search_engine_ximalaya"), Value: "ximalaya", Category: "audio"},
        {Name: GetText("search_engine_5sing"), Value: "5sing", Category: "audio"},
        {Name: GetText("search_engine_lossless"), Value: "lossless", Category: "audio"},
        {Name: GetText("search_engine_erling"), Value: "erling", Category: "audio"},
        
        ; 视频类
        {Name: GetText("search_engine_douyin"), Value: "douyin", Category: "video"},
        {Name: GetText("search_engine_yuewen"), Value: "yuewen", Category: "video"},
        {Name: GetText("search_engine_qingying"), Value: "qingying", Category: "video"},
        {Name: GetText("search_engine_tongyi_video"), Value: "tongyi_video", Category: "video"},
        {Name: GetText("search_engine_jimmeng_video"), Value: "jimmeng_video", Category: "video"},
        {Name: GetText("search_engine_youtube"), Value: "youtube", Category: "video"},
        {Name: GetText("search_engine_find_lines"), Value: "find_lines", Category: "video"},
        {Name: GetText("search_engine_shetu_video"), Value: "shetu_video", Category: "video"},
        {Name: GetText("search_engine_yandex"), Value: "yandex", Category: "video"},
        {Name: GetText("search_engine_pexels"), Value: "pexels", Category: "video"},
        {Name: GetText("search_engine_youku"), Value: "youku", Category: "video"},
        {Name: GetText("search_engine_chanjing"), Value: "chanjing", Category: "video"},
        {Name: GetText("search_engine_duojia"), Value: "duojia", Category: "video"},
        {Name: GetText("search_engine_tencent_zhiying"), Value: "tencent_zhiying", Category: "video"},
        {Name: GetText("search_engine_wansheng"), Value: "wansheng", Category: "video"},
        {Name: GetText("search_engine_tencent_video"), Value: "tencent_video", Category: "video"},
        {Name: GetText("search_engine_iqiyi"), Value: "iqiyi", Category: "video"},
        
        ; 图书类
        {Name: GetText("search_engine_duokan"), Value: "duokan", Category: "book"},
        {Name: GetText("search_engine_turing"), Value: "turing", Category: "book"},
        {Name: GetText("search_engine_panda_book"), Value: "panda_book", Category: "book"},
        {Name: GetText("search_engine_douban_book"), Value: "douban_book", Category: "book"},
        {Name: GetText("search_engine_lifelong_edu"), Value: "lifelong_edu", Category: "book"},
        {Name: GetText("search_engine_verypan"), Value: "verypan", Category: "book"},
        {Name: GetText("search_engine_zouddupai"), Value: "zouddupai", Category: "book"},
        {Name: GetText("search_engine_gd_library"), Value: "gd_library", Category: "book"},
        {Name: GetText("search_engine_pansou"), Value: "pansou", Category: "book"},
        {Name: GetText("search_engine_zsxq"), Value: "zsxq", Category: "book"},
        {Name: GetText("search_engine_jiumo"), Value: "jiumo", Category: "book"},
        {Name: GetText("search_engine_weibo_book"), Value: "weibo_book", Category: "book"},
        
        ; 比价类
        {Name: GetText("search_engine_jd"), Value: "jd", Category: "price"},
        {Name: GetText("search_engine_baidu_procure"), Value: "baidu_procure", Category: "price"},
        {Name: GetText("search_engine_dangdang"), Value: "dangdang", Category: "price"},
        {Name: GetText("search_engine_1688"), Value: "1688", Category: "price"},
        {Name: GetText("search_engine_taobao"), Value: "taobao", Category: "price"},
        {Name: GetText("search_engine_tmall"), Value: "tmall", Category: "price"},
        {Name: GetText("search_engine_pinduoduo"), Value: "pinduoduo", Category: "price"},
        {Name: GetText("search_engine_xianyu"), Value: "xianyu", Category: "price"},
        {Name: GetText("search_engine_smzdm"), Value: "smzdm", Category: "price"},
        {Name: GetText("search_engine_yanxuan"), Value: "yanxuan", Category: "price"},
        {Name: GetText("search_engine_gaide"), Value: "gaide", Category: "price"},
        {Name: GetText("search_engine_suning"), Value: "suning", Category: "price"},
        {Name: GetText("search_engine_ebay"), Value: "ebay", Category: "price"},
        {Name: GetText("search_engine_amazon"), Value: "amazon", Category: "price"},
        
        ; 医疗类
        {Name: GetText("search_engine_dxy"), Value: "dxy", Category: "medical"},
        {Name: GetText("search_engine_left_doctor"), Value: "left_doctor", Category: "medical"},
        {Name: GetText("search_engine_medisearch"), Value: "medisearch", Category: "medical"},
        {Name: GetText("search_engine_merck"), Value: "merck", Category: "medical"},
        {Name: GetText("search_engine_aplus_medical"), Value: "aplus_medical", Category: "medical"},
        {Name: GetText("search_engine_medical_baike"), Value: "medical_baike", Category: "medical"},
        {Name: GetText("search_engine_weiyi"), Value: "weiyi", Category: "medical"},
        {Name: GetText("search_engine_medlive"), Value: "medlive", Category: "medical"},
        {Name: GetText("search_engine_xywy"), Value: "xywy", Category: "medical"},
        
        ; 网盘类
        {Name: GetText("search_engine_pansoso"), Value: "pansoso", Category: "cloud"},
        {Name: GetText("search_engine_panso"), Value: "panso", Category: "cloud"},
        {Name: GetText("search_engine_xiaomapan"), Value: "xiaomapan", Category: "cloud"},
        {Name: GetText("search_engine_dashengpan"), Value: "dashengpan", Category: "cloud"},
        {Name: GetText("search_engine_miaosou"), Value: "miaosou", Category: "cloud"}
    ]
    
    return AllEngines
}

; 获取排序后的搜索引擎列表（根据语言版本和分类过滤）
GetSortedSearchEngines(Category := "") {
    global Language, VoiceSearchCurrentCategory
    
    ; 如果没有指定分类，使用当前选中的分类
    if (Category = "") {
        Category := VoiceSearchCurrentCategory
    }
    
    ; 获取所有搜索引擎
    AllEngines := GetAllSearchEngines()
    
    ; 按分类过滤
    FilteredEngines := []
    for Index, Engine in AllEngines {
        ; 【修复】添加安全检查，防止访问无效对象属性
        if (IsObject(Engine) && Engine.HasProp("Category") && Engine.Category = Category) {
            FilteredEngines.Push(Engine)
        }
    }
    
    ; 如果当前分类没有搜索引擎，返回空数组（不显示提示，让调用者处理）
    if (FilteredEngines.Length = 0) {
        return FilteredEngines
    }
    
    ; 根据语言版本排序（仅对AI类有效）
    if (Category = "ai") {
        ChineseEngines := []
        AIEngines := []
        
        for Index, Engine in FilteredEngines {
            ; 【修复】添加安全检查，防止访问无效对象属性
            if (!IsObject(Engine) || !Engine.HasProp("Value")) {
                continue
            }
            ; 判断是中文引擎还是AI引擎
            ChineseEngineValues := ["deepseek", "yuanbao", "doubao", "zhipu", "mita", "wenxin", "qianwen", "kimi"]
            if (ArrayContainsValue(ChineseEngineValues, Engine.Value) > 0) {
                ChineseEngines.Push(Engine)
            } else {
                AIEngines.Push(Engine)
            }
        }
        
        ; 根据语言版本排序
        if (Language = "en") {
            ; 英文版：AI引擎在前，中文引擎在后
            SearchEngines := []
            for Index, Engine in AIEngines {
                SearchEngines.Push(Engine)
            }
            for Index, Engine in ChineseEngines {
                SearchEngines.Push(Engine)
            }
        } else {
            ; 中文版：中文引擎在前，AI引擎在后
            SearchEngines := []
            for Index, Engine in ChineseEngines {
                SearchEngines.Push(Engine)
            }
            for Index, Engine in AIEngines {
                SearchEngines.Push(Engine)
            }
        }
        
        return SearchEngines
    }
    
    ; 其他分类直接返回过滤后的结果
    return FilteredEngines
}

; 获取搜索引擎对应的图标文件名
GetSearchEngineIcon(EngineValue) {
    ; 根据搜索引擎值返回对应的图标文件名
    IconMap := Map(
        ; AI类
        "deepseek", "DeepSeek.png",
        "yuanbao", "yuanbao.png",
        "doubao", "doubao.png",
        "zhipu", "zhipu.png",
        "mita", "mita.png",
        "wenxin", "wenxin.png",
        "qianwen", "qwen.png",
        "kimi", "Kimi.png",
        "perplexity", "Perplexity.png",
        "copilot", "Copilot.png",
        "chatgpt", "ChatGPT.png",
        "grok", "Grok.png",
        "you", "You.png",
        "claude", "Claude.png",
        "monica", "Monica.png",
        "webpilot", "WebPilot.png",
        ; CLI类
        "codex_cli", "codex.jpg",
        "gemini_cli", "gemini.jpg",
        "openclaw_cli", "openclaw.jpg",
        "qwen_cli", "qwen.png"
        ; 注意：其他分类的搜索引擎如果没有对应的图标文件，会返回空字符串，使用文本显示
    )
    
    IconName := IconMap.Get(EngineValue, "")
    if (IconName != "") {
        ; 返回完整的图标路径
        ScriptDir := A_ScriptDir
        IconDirs := [ScriptDir . "\aiicons", ScriptDir . "\images"]
        for _, DirPath in IconDirs {
            IconPath := DirPath . "\" . IconName
            if (FileExist(IconPath)) {
                return IconPath
            }
        }
    }
    return ""  ; 如果图标不存在，返回空字符串
}

; 创建分类标签切换处理函数
CreateCategoryTabHandler(CategoryKey) {
    ; 使用闭包捕获CategoryKey
    CategoryTabHandler(*) {
        global VoiceSearchCurrentCategory, VoiceSearchCategoryTabs, VoiceSearchEngineButtons, GuiID_VoiceInput
        global VoiceSearchSelectedEngines, UI_Colors, ThemeMode, VoiceSearchLabelEngineY
        global VoiceSearchSelectedEnginesByCategory
        
        ; 确保 VoiceSearchSelectedEnginesByCategory 已初始化
        if (!IsSet(VoiceSearchSelectedEnginesByCategory) || !IsObject(VoiceSearchSelectedEnginesByCategory)) {
            VoiceSearchSelectedEnginesByCategory := Map()
        }
        
        ; 【关键修复】保存当前分类的搜索引擎选择状态
        OldCategory := VoiceSearchCurrentCategory
        if (OldCategory != "" && OldCategory != CategoryKey) {
            ; 保存当前分类的选择状态
            CurrentEngines := []
            for Index, Engine in VoiceSearchSelectedEngines {
                CurrentEngines.Push(Engine)
            }
            VoiceSearchSelectedEnginesByCategory[OldCategory] := CurrentEngines
        }
        
        ; 使用捕获的CategoryKey，而不是全局变量
        ; 更新当前分类
        VoiceSearchCurrentCategory := CategoryKey
        
        ; 确保GUI存在
        if (!GuiID_VoiceInput) {
            return
        }
        
        ; 更新所有标签按钮的样式
        for Index, TabObj in VoiceSearchCategoryTabs {
            ; 【关键修复】如果按钮引用丢失，尝试从GUI重新获取
            if (!TabObj.Btn || !IsObject(TabObj.Btn)) {
                try {
                    TabObj.Btn := GuiID_VoiceInput["CategoryTab" . TabObj.Key]
                } catch as err {
                    ; 如果无法获取，跳过这个标签
                    continue
                }
            }
            
            if (TabObj.Btn && IsObject(TabObj.Btn)) {
                IsActive := (TabObj.Key = CategoryKey)
                TabBg := IsActive ? UI_Colors.BtnPrimary : UI_Colors.BtnBg
                TabTextColor := IsActive ? "FFFFFF" : ((ThemeMode = "light") ? UI_Colors.Text : "FFFFFF")
                try {
                    ; 【关键修复】使用 Opt() 方法更新背景色，确保立即生效
                    TabObj.Btn.Opt("+Background" . TabBg)
                    TabObj.Btn.SetFont("s9 c" . TabTextColor, "Segoe UI")
                    TabObj.Btn.Text := GetText("search_category_" . TabObj.Key)
                    ; 强制重绘以确保背景色更新
                    TabObj.Btn.Redraw()
                } catch as err {
                    ; 如果上述方法失败，尝试直接设置 BackColor
                    try {
                        TabObj.Btn.BackColor := TabBg
                        TabObj.Btn.SetFont("s9 c" . TabTextColor, "Segoe UI")
                        TabObj.Btn.Text := GetText("search_category_" . TabObj.Key)
                    } catch as err {
                        ; 忽略更新样式时的错误
                    }
                }
            }
        }
        
        ; 【关键修复】恢复新分类的搜索引擎选择状态
        if (VoiceSearchSelectedEnginesByCategory.Has(CategoryKey)) {
            ; 如果该分类有保存的选择状态，恢复它
            VoiceSearchSelectedEngines := []
            for Index, Engine in VoiceSearchSelectedEnginesByCategory[CategoryKey] {
                VoiceSearchSelectedEngines.Push(Engine)
            }
        } else {
            ; 如果该分类没有保存的选择状态，使用默认值（根据分类的第一个搜索引擎）
            try {
                SearchEngines := GetSortedSearchEngines(CategoryKey)
                if (SearchEngines && SearchEngines.Length > 0 && IsObject(SearchEngines[1]) && SearchEngines[1].HasProp("Value")) {
                    VoiceSearchSelectedEngines := [SearchEngines[1].Value]
                } else {
                    VoiceSearchSelectedEngines := ["deepseek"]
                }
            } catch as err {
                VoiceSearchSelectedEngines := ["deepseek"]
            }
        }
        
        ; 【关键修复】先刷新标签背景色，确保立即显示
        try {
            if (GuiID_VoiceInput && IsObject(GuiID_VoiceInput) && GuiID_VoiceInput.HasProp("Hwnd")) {
                WinRedraw(GuiID_VoiceInput.Hwnd)
            }
        } catch as err {
            ; 忽略刷新错误
        }
        
        ; 【关键修复】刷新搜索引擎按钮显示（隐藏旧的，显示新的）
        ; 使用短暂延迟确保标签背景色先更新，提升流畅度
        SetTimer(() => RefreshSearchEngineButtons(), -10)
    }
    return CategoryTabHandler
}

; ===================== 刷新搜索引擎按钮显示 =====================
RefreshSearchEngineButtons() {
    global GuiID_VoiceInput, VoiceSearchCurrentCategory, VoiceSearchEngineButtons, VoiceSearchSelectedEngines
    global VoiceSearchLabelEngineY, UI_Colors, ThemeMode, WindowDragging
    
    ; 如果窗口正在拖动，跳过刷新以避免闪烁
    if (WindowDragging) {
        return
    }
    
    if (!GuiID_VoiceInput) {
        return
    }
    
    ; 【关键修复】从GUI窗口获取实际宽度
    try {
        WinGetPos(, , &PanelWidth, , "ahk_id " . GuiID_VoiceInput.Hwnd)
    } catch as err {
        ; 如果获取失败，使用默认值
        PanelWidth := 600
    }
    
    ; 【关键修复】优化切换流畅度：先隐藏旧按钮，创建新按钮后再销毁旧按钮
    if (IsSet(VoiceSearchEngineButtons) && IsObject(VoiceSearchEngineButtons)) {
        ; 先隐藏所有旧按钮（不立即销毁，保持界面流畅）
        for Index, BtnObj in VoiceSearchEngineButtons {
            if (IsObject(BtnObj)) {
                try {
                    if (BtnObj.Bg) {
                        BtnObj.Bg.Visible := false
                    }
                    if (BtnObj.Icon) {
                        BtnObj.Icon.Visible := false
                    }
                    if (BtnObj.Text) {
                        BtnObj.Text.Visible := false
                    }
                } catch as err {
                    ; 忽略隐藏错误
                }
            }
        }
    }
    
    ; 保存旧按钮数组用于后续销毁
    OldButtons := VoiceSearchEngineButtons
    ; 清空按钮数组，准备创建新按钮
    VoiceSearchEngineButtons := []
    
    ; 获取当前分类的搜索引擎列表
    try {
        SearchEngines := GetSortedSearchEngines(VoiceSearchCurrentCategory)
    } catch as err {
        return
    }
    
    if (!IsObject(SearchEngines) || SearchEngines.Length = 0) {
        return
    }
    
    ; 计算按钮位置和布局
    global VoiceSearchLabelEngineY
    YPos := VoiceSearchLabelEngineY + 30
    ButtonWidth := 130
    ButtonHeight := 35
    ButtonSpacing := 10
    StartX := 20
    ButtonsPerRow := 4
    IconSizeInButton := 20
    
    AvailableWidth := PanelWidth - 40
    MaxButtonsPerRow := Floor((AvailableWidth + ButtonSpacing) / (ButtonWidth + ButtonSpacing))
    if (MaxButtonsPerRow < 1) {
        MaxButtonsPerRow := 1
    }
    ButtonsPerRow := Min(ButtonsPerRow, MaxButtonsPerRow)
    
    ; 创建新的搜索引擎按钮
    for Index, Engine in SearchEngines {
        if (!IsObject(Engine) || !Engine.HasProp("Value") || !Engine.HasProp("Name")) {
            continue
        }
        
        Row := Floor((Index - 1) / ButtonsPerRow)
        Col := Mod((Index - 1), ButtonsPerRow)
        BtnX := StartX + Col * (ButtonWidth + ButtonSpacing)
        BtnY := YPos + Row * (ButtonHeight + ButtonSpacing)
        
        IsSelected := (ArrayContainsValue(VoiceSearchSelectedEngines, Engine.Value) > 0)
        BtnBgColor := IsSelected ? UI_Colors.BtnHover : UI_Colors.BtnBg
        BtnText := IsSelected ? "✓ " . Engine.Name : Engine.Name
        EngineBtnTextColor := (ThemeMode = "light") ? UI_Colors.Text : "FFFFFF"
        
        IconPath := GetSearchEngineIcon(Engine.Value)
        IconCtrl := 0
        
        Btn := GuiID_VoiceInput.Add("Text", "x" . BtnX . " y" . BtnY . " w" . ButtonWidth . " h" . ButtonHeight . " Center 0x200 c" . EngineBtnTextColor . " Background" . BtnBgColor, "")
        Btn.SetFont("s10", "Segoe UI")
        Btn.OnEvent("Click", CreateToggleSearchEngineHandler(Engine.Value, Index))
        HoverBtn(Btn, BtnBgColor, UI_Colors.BtnHover)
        
        if (IconPath != "" && FileExist(IconPath)) {
            try {
                IconX := BtnX + 8
                IconY := BtnY + (ButtonHeight - IconSizeInButton) // 2
                
                ImageSize := GetImageSize(IconPath)
                DisplaySize := CalculateImageDisplaySize(ImageSize.Width, ImageSize.Height, IconSizeInButton, IconSizeInButton)
                
                DisplayX := IconX
                DisplayY := IconY + (IconSizeInButton - DisplaySize.Height) // 2
                
                IconCtrl := GuiID_VoiceInput.Add("Picture", "x" . DisplayX . " y" . DisplayY . " w" . DisplaySize.Width . " h" . DisplaySize.Height . " 0x200", IconPath)
                IconCtrl.OnEvent("Click", CreateToggleSearchEngineHandler(Engine.Value, Index))
                
                TextX := IconX + IconSizeInButton + 5
                TextWidth := ButtonWidth - (TextX - BtnX) - 8
            } catch as err {
                IconCtrl := 0
                TextX := BtnX + 8
                TextWidth := ButtonWidth - 16
            }
        } else {
            TextX := BtnX + 8
            TextWidth := ButtonWidth - 16
        }
        
        TextCtrl := GuiID_VoiceInput.Add("Text", "x" . TextX . " y" . BtnY . " w" . TextWidth . " h" . ButtonHeight . " Left 0x200 c" . EngineBtnTextColor . " BackgroundTrans", BtnText)
        TextCtrl.SetFont("s10", "Segoe UI")
        TextCtrl.OnEvent("Click", CreateToggleSearchEngineHandler(Engine.Value, Index))
        
        ; 使用新的索引（从1开始）
        NewIndex := VoiceSearchEngineButtons.Length + 1
        VoiceSearchEngineButtons.Push({Bg: Btn, Icon: IconCtrl, Text: TextCtrl, Index: NewIndex})
    }
    
    ; 【关键修复】刷新GUI显示，确保新按钮立即显示
    try {
        if (GuiID_VoiceInput && IsObject(GuiID_VoiceInput) && GuiID_VoiceInput.HasProp("Hwnd")) {
            WinRedraw(GuiID_VoiceInput.Hwnd)
        }
    } catch as err {
        ; 忽略刷新错误
    }
    
    ; 【关键修复】延迟销毁旧按钮，确保新按钮已显示后再清理，提升流畅度
    SetTimer(() => DestroyOldSearchEngineButtons(OldButtons), -100)
}

; 销毁旧的搜索引擎按钮（延迟执行，提升流畅度）
DestroyOldSearchEngineButtons(OldButtons) {
    if (!IsSet(OldButtons) || !IsObject(OldButtons)) {
        return
    }
    
    for Index, BtnObj in OldButtons {
        if (IsObject(BtnObj)) {
            try {
                if (BtnObj.Bg) {
                    BtnObj.Bg.Destroy()
                }
                if (BtnObj.Icon) {
                    BtnObj.Icon.Destroy()
                }
                if (BtnObj.Text) {
                    BtnObj.Text.Destroy()
                }
            } catch as err {
                ; 忽略销毁错误
            }
        }
    }
}

; ===================== 语音搜索相关函数 =====================
; 执行语音搜索
ExecuteVoiceSearch(*) {
    global VoiceSearchInputEdit, VoiceSearchSelectedEngines, VoiceSearchPanelVisible
    
    if (!VoiceSearchPanelVisible || !VoiceSearchInputEdit) {
        return
    }
    
    try {
        Content := VoiceSearchInputEdit.Value
        if (Content != "" && StrLen(Content) > 0) {
            ; 检查是否有选中的搜索引擎
            if (VoiceSearchSelectedEngines.Length = 0) {
                TrayTip(GetText("no_search_engine_selected"), GetText("tip"), "Icon! 2")
                return
            }
            
            ; 隐藏面板
            HideVoiceSearchInputPanel()
            
            ; 打开所有选中的搜索引擎
            ; 【修复】检查VoiceSearchSelectedEngines是否已初始化且不为空
            if (!IsSet(VoiceSearchSelectedEngines) || !IsObject(VoiceSearchSelectedEngines) || VoiceSearchSelectedEngines.Length = 0) {
                TrayTip(GetText("no_search_engine_selected"), GetText("tip"), "Icon! 2")
                return
            }
            
            for Index, Engine in VoiceSearchSelectedEngines {
                ; 【修复】检查Engine是否有值
                if (!IsSet(Engine) || Engine = "") {
                    continue  ; 跳过无效的引擎
                }
                SendVoiceSearchToBrowser(Content, Engine)
                ; 每个搜索引擎之间稍作延迟，避免同时打开太多窗口
                if (Index < VoiceSearchSelectedEngines.Length) {
                    Sleep(300)
                }
            }
            
            TrayTip(FormatText("search_engines_opened", VoiceSearchSelectedEngines.Length), GetText("tip"), "Iconi 1")
        }
    } catch as e {
        TrayTip(GetText("voice_search_failed") . ": " . e.Message, GetText("error"), "Iconx 2")
    }
}

; 开始语音输入（在语音搜索界面中）
StartVoiceInputInSearch() {
    global VoiceSearchActive, VoiceInputMethod, VoiceSearchPanelVisible, VoiceSearchInputEdit, UI_Colors
    
    if (VoiceSearchActive || !VoiceSearchPanelVisible) {
        return
    }
    
    try {
        ; 确保窗口激活并输入框有真正的输入焦点
        global GuiID_VoiceInput
        if (GuiID_VoiceInput) {
            ; 激活窗口
            WinActivate("ahk_id " . GuiID_VoiceInput.Hwnd)
            Sleep(200)
            
            ; 确保窗口真正激活
            if (!WinActive("ahk_id " . GuiID_VoiceInput.Hwnd)) {
                ; 如果仍未激活，再次尝试
                WinActivate("ahk_id " . GuiID_VoiceInput.Hwnd)
                Sleep(200)
            }
        }
        
        ; 确保输入框为空并获取真正的输入焦点
        if (VoiceSearchInputEdit) {
            VoiceSearchInputEdit.Value := ""
            
            ; 获取输入框的控件句柄
            InputEditHwnd := VoiceSearchInputEdit.Hwnd
            
            ; 使用ControlFocus确保输入框有真正的输入焦点（IME焦点）
            try {
                ControlFocus(InputEditHwnd, "ahk_id " . GuiID_VoiceInput.Hwnd)
                Sleep(100)
            } catch as err {
                ; 如果ControlFocus失败，使用Focus方法
                VoiceSearchInputEdit.Focus()
                Sleep(100)
            }
        }
        
        ; 自动检测输入法类型
        VoiceInputMethod := DetectInputMethod()
        
        ; 根据输入法类型使用不同的快捷键
        if (VoiceInputMethod = "baidu") {
            ; 百度输入法：Alt+Y 激活，F2 开始
            if (VoiceSearchInputEdit) {
                InputEditHwnd := VoiceSearchInputEdit.Hwnd
                try {
                    ControlFocus(InputEditHwnd, "ahk_id " . GuiID_VoiceInput.Hwnd)
                    Sleep(150)
                } catch as err {
                    VoiceSearchInputEdit.Focus()
                    Sleep(150)
                }
                ; 切换到中文输入法，确保百度输入法处于活动状态
                SwitchToChineseIME()
                Sleep(200)
            }
            
            ; 发送 Alt+Y 激活百度输入法
            Send("!y")
            Sleep(800)
            
            ; 发送 F2 开始语音输入
            Send("{F2}")
            Sleep(300)
        } else if (VoiceInputMethod = "xunfei") {
            ; 讯飞输入法：直接按 F6 开始语音输入
            Send("{F6}")
            Sleep(800)
            if (VoiceSearchInputEdit) {
                InputEditHwnd := VoiceSearchInputEdit.Hwnd
                try {
                    ControlFocus(InputEditHwnd, "ahk_id " . GuiID_VoiceInput.Hwnd)
                    Sleep(100)
                } catch as err {
                    VoiceSearchInputEdit.Focus()
                    Sleep(100)
                }
            }
        } else {
            ; 默认尝试百度方案
            if (VoiceSearchInputEdit) {
                InputEditHwnd := VoiceSearchInputEdit.Hwnd
                try {
                    ControlFocus(InputEditHwnd, "ahk_id " . GuiID_VoiceInput.Hwnd)
                    Sleep(150)
                } catch as err {
                    VoiceSearchInputEdit.Focus()
                    Sleep(150)
                }
                SwitchToChineseIME()
                Sleep(200)
            }
            
            Send("!y")
            Sleep(800)
            Send("{F2}")
            Sleep(300)
        }
        
        VoiceSearchActive := true
        global VoiceSearchContent := ""
        
        ; 等待一下，确保语音输入已启动
        Sleep(500)
        ; 注意：自动更新和自动加载功能已移除，不再启动定时器
    } catch as e {
        VoiceSearchActive := false
        TrayTip(GetText("voice_search_failed") . ": " . e.Message, GetText("error"), "Iconx 2")
    }
}

; 停止语音输入（在语音搜索界面中）
StopVoiceInputInSearch() {
    global VoiceSearchActive, VoiceInputMethod, CapsLock, VoiceSearchInputEdit, VoiceSearchPanelVisible, UI_Colors
    
    if (!VoiceSearchActive || !VoiceSearchPanelVisible) {
        return
    }
    
    try {
        ; 先确保CapsLock状态被重置
        if (CapsLock) {
            CapsLock := false
        }
        
        ; 根据输入法类型使用不同的结束快捷键
        if (VoiceInputMethod = "baidu") {
            ; 百度输入法：F1 结束语音录入
            Send("{F1}")
            Sleep(800)
            
            ; 获取语音输入内容
            OldClipboard := A_Clipboard
            Send("^a")
            Sleep(200)
            A_Clipboard := ""
            Send("^c")
            if ClipWait(1.5) {
                global VoiceSearchContent := A_Clipboard
            }
            A_Clipboard := OldClipboard
            
            ; 退出百度输入法语音模式
            Send("!y")
            Sleep(300)
        } else if (VoiceInputMethod = "xunfei") {
            ; 讯飞输入法：F6 结束
            Send("{F6}")
            Sleep(1000)
            
            ; 获取语音输入内容
            OldClipboard := A_Clipboard
            Send("^a")
            Sleep(200)
            A_Clipboard := ""
            Send("^c")
            if ClipWait(1.5) {
                global VoiceSearchContent := A_Clipboard
            }
            A_Clipboard := OldClipboard
        } else {
            ; 默认尝试百度方案
            Send("{F1}")
            Sleep(800)
            
            ; 获取语音输入内容
            OldClipboard := A_Clipboard
            Send("^a")
            Sleep(200)
            A_Clipboard := ""
            Send("^c")
            if ClipWait(1.5) {
                global VoiceSearchContent := A_Clipboard
            }
            A_Clipboard := OldClipboard
            
            ; 退出百度输入法语音模式
            Send("!y")
            Sleep(300)
        }
        
        VoiceSearchActive := false
        SetTimer(UpdateVoiceSearchInputInPanel, 0)  ; 停止更新输入框
        
        ; 将内容填入输入框
        global VoiceSearchContent
        if (VoiceSearchContent != "" && StrLen(VoiceSearchContent) > 0 && VoiceSearchInputEdit) {
            VoiceSearchInputEdit.Value := VoiceSearchContent
            VoiceSearchInputEdit.Focus()
        }
    } catch as e {
        VoiceSearchActive := false
        SetTimer(UpdateVoiceSearchInputInPanel, 0)
        TrayTip(GetText("voice_search_failed") . ": " . e.Message, GetText("error"), "Iconx 2")
    }
}

; 聚焦语音搜索输入框
FocusVoiceSearchInput() {
    global VoiceSearchInputEdit, VoiceSearchPanelVisible, AutoLoadSelectedText
    
    if (!VoiceSearchPanelVisible || !VoiceSearchInputEdit) {
        return
    }
    
    try {
        ; 清空输入框
        VoiceSearchInputEdit.Value := ""
        ; 设置焦点
        VoiceSearchInputEdit.Focus()
        
        ; 注意：自动加载功能已移除，不再启动定时器
        SetTimer(MonitorSelectedText, 0)
    } catch as err {
        ; 忽略错误
    }
}

; 切换自动加载选中文本开关（语音输入界面）
ToggleAutoLoadSelectedTextForVoiceInput(*) {
    global AutoLoadSelectedText, VoiceInputAutoLoadSwitch, VoiceInputActionSelectionVisible, UI_Colors, ConfigFile
    
    if (!VoiceInputActionSelectionVisible || !VoiceInputAutoLoadSwitch) {
        return
    }
    
    ; 切换状态
    AutoLoadSelectedText := !AutoLoadSelectedText
    
    ; 更新开关显示
    SwitchText := AutoLoadSelectedText ? "✓ 已开启" : "○ 已关闭"
    SwitchBg := AutoLoadSelectedText ? UI_Colors.BtnHover : UI_Colors.BtnBg
    VoiceInputAutoLoadSwitch.Text := SwitchText
    VoiceInputAutoLoadSwitch.BackColor := SwitchBg
    
    ; 保存到配置文件
    try {
        IniWrite(AutoLoadSelectedText ? "1" : "0", ConfigFile, "Settings", "AutoLoadSelectedText")
    } catch as err {
        ; 忽略保存错误
    }
    
    ; 如果开启，启动监听；如果关闭，立即停止监听
    if (AutoLoadSelectedText) {
        SetTimer(MonitorSelectedTextForVoiceInput, 200)  ; 每200ms检查一次
    } else {
        ; 立即停止监听，确保不会继续自动加载
        SetTimer(MonitorSelectedTextForVoiceInput, 0)
    }
}

; 监听选中文本并自动加载到输入框（语音输入界面）
MonitorSelectedTextForVoiceInput(*) {
    global AutoLoadSelectedText, VoiceInputActionSelectionVisible, GuiID_VoiceInput
    
    ; 如果开关未开启或界面未显示，立即停止监听
    if (!AutoLoadSelectedText || !VoiceInputActionSelectionVisible || !GuiID_VoiceInput) {
        SetTimer(MonitorSelectedTextForVoiceInput, 0)
        return
    }
    
    ; 检查是否有选中的文本
    try {
        ; 保存当前剪贴板
        OldClipboard := A_Clipboard
        
        ; 尝试复制选中文本
        A_Clipboard := ""
        Send("^c")
        Sleep(50)  ; 等待复制完成
        
        ; 检查是否复制成功
        if (ClipWait(0.1) && A_Clipboard != "" && A_Clipboard != OldClipboard) {
            ; 有选中文本，加载到输入框
            SelectedText := A_Clipboard
            if (SelectedText != "" && StrLen(SelectedText) > 0) {
                ; 尝试获取输入框控件并更新
                try {
                    ContentEdit := GuiID_VoiceInput["VoiceInputContentEdit"]
                    if (ContentEdit && (ContentEdit.Value = "" || ContentEdit.Value != SelectedText)) {
                        ContentEdit.Value := SelectedText
                    }
                } catch as err {
                    ; 忽略错误
                }
            }
        }
        
        ; 恢复剪贴板
        A_Clipboard := OldClipboard
    } catch as err {
        ; 忽略错误
    }
}

; 显示搜索引擎选择界面
ShowSearchEngineSelection(Content) {
    global GuiID_VoiceInput, VoiceInputScreenIndex, UI_Colors, VoiceSearchSelecting, VoiceSearchEngineButtons
    
    VoiceSearchSelecting := true
    
    if (GuiID_VoiceInput != 0) {
        try {
            GuiID_VoiceInput.Destroy()
        }
        GuiID_VoiceInput := 0
    }
    
    GuiID_VoiceInput := Gui("+AlwaysOnTop +ToolWindow -Caption -DPIScale")
    GuiID_VoiceInput.BackColor := UI_Colors.Background
    GuiID_VoiceInput.SetFont("s12 c" . UI_Colors.Text . " Bold", "Segoe UI")
    
    ; 获取所有搜索引擎
    global SearchEngines := GetAllSearchEngines()
    
    PanelWidth := 500
    ; 计算所需高度：标题(50) + 内容标签(25) + 内容框(60) + 引擎标签(30) + 按钮区域 + 取消按钮(45) + 边距(20)
    ButtonsRows := Ceil(SearchEngines.Length / 4)  ; 每行4个按钮
    ButtonsAreaHeight := ButtonsRows * 45  ; 每行45px（按钮35px + 间距10px）
    PanelHeight := 50 + 25 + 60 + 30 + ButtonsAreaHeight + 45 + 20
    
    ; 标题
    TitleText := GuiID_VoiceInput.Add("Text", "x0 y15 w500 h30 Center c" . UI_Colors.Text, GetText("select_search_engine_title"))
    TitleText.SetFont("s14 Bold", "Segoe UI")
    
    ; 显示搜索内容
    YPos := 55
    LabelText := GuiID_VoiceInput.Add("Text", "x20 y" . YPos . " w460 h20 cCCCCCC", "搜索内容:")
    LabelText.SetFont("s10", "Segoe UI")
    
    YPos += 25
    ContentText := GuiID_VoiceInput.Add("Text", "x20 y" . YPos . " w460 h60 Background" . UI_Colors.InputBg . " c" . UI_Colors.Text, Content)
    ContentText.SetFont("s11", "Segoe UI")
    
    ; 搜索引擎按钮
    YPos += 70
    LabelEngine := GuiID_VoiceInput.Add("Text", "x20 y" . YPos . " w460 h25 c" . UI_Colors.Text, GetText("select_search_engine"))
    LabelEngine.SetFont("s11", "Segoe UI")
    
    YPos += 30
    ButtonWidth := 110
    ButtonHeight := 35
    ButtonSpacing := 10
    ButtonsPerRow := 4
    
    VoiceSearchEngineButtons := []
    for Index, Engine in SearchEngines {
        ; 【修复】添加安全检查，防止访问无效对象属性
        if (!IsObject(Engine) || !Engine.HasProp("Value") || !Engine.HasProp("Name")) {
            continue  ; 跳过无效的引擎对象
        }
        
        Row := Floor((Index - 1) / ButtonsPerRow)
        Col := Mod(Index - 1, ButtonsPerRow)
        BtnX := 20 + Col * (ButtonWidth + ButtonSpacing)
        BtnY := YPos + Row * (ButtonHeight + ButtonSpacing)
        
        Btn := GuiID_VoiceInput.Add("Text", "x" . BtnX . " y" . BtnY . " w" . ButtonWidth . " h" . ButtonHeight . " Center 0x200 c" . UI_Colors.Text . " Background" . UI_Colors.BtnBg . " vSearchEngineBtn" . Index, Engine.Name)
        Btn.SetFont("s10", "Segoe UI")
        Btn.OnEvent("Click", CreateSearchEngineClickHandler(Content, Engine.Value))
        HoverBtn(Btn, UI_Colors.BtnBg, UI_Colors.BtnHover)
        VoiceSearchEngineButtons.Push(Btn)
    }
    
    ; 取消按钮
    CancelBtnY := YPos + (Floor((SearchEngines.Length - 1) / ButtonsPerRow) + 1) * (ButtonHeight + ButtonSpacing) + 10
    global ThemeMode
    CancelBtnTextColor := (ThemeMode = "light") ? UI_Colors.Text : "FFFFFF"
    CancelBtnBg := (ThemeMode = "light") ? UI_Colors.BtnBg : "666666"
    CancelBtn := GuiID_VoiceInput.Add("Text", "x" . (PanelWidth // 2 - 60) . " y" . CancelBtnY . " w120 h35 Center 0x200 c" . CancelBtnTextColor . " Background" . CancelBtnBg . " vCancelBtn", GetText("cancel"))
    CancelBtn.SetFont("s11", "Segoe UI")
    CancelBtn.OnEvent("Click", CancelSearchEngineSelection)
    HoverBtn(CancelBtn, "666666", "777777")
    
    ScreenInfo := GetScreenInfo(VoiceInputScreenIndex)
    Pos := GetPanelPosition(ScreenInfo, PanelWidth, PanelHeight, "center")
    GuiID_VoiceInput.Show("w" . PanelWidth . " h" . PanelHeight . " x" . Pos.X . " y" . Pos.Y . " NoActivate")
    WinSetAlwaysOnTop(1, GuiID_VoiceInput.Hwnd)
}

; 创建搜索引擎点击处理函数
CreateSearchEngineClickHandler(Content, Engine) {
    ; 使用闭包保存参数
    SearchEngineClickHandler(*) {
        global VoiceSearchSelecting
        VoiceSearchSelecting := false
        HideVoiceSearchInputPanel()
        SendVoiceSearchToBrowser(Content, Engine)
    }
    return SearchEngineClickHandler
}

; 取消搜索引擎选择
CancelSearchEngineSelection(*) {
    global VoiceSearchSelecting
    VoiceSearchSelecting := false
    HideVoiceSearchInputPanel()
}

; 显示语音搜索输入界面
ShowVoiceSearchInputPanel() {
    global GuiID_VoiceInput, VoiceInputScreenIndex, UI_Colors, VoiceSearchPanelVisible
    global VoiceSearchInputEdit, VoiceSearchSelectedEngines, VoiceSearchEngineButtons
    
    VoiceSearchPanelVisible := true
    
    if (GuiID_VoiceInput != 0) {
        try {
            GuiID_VoiceInput.Destroy()
        }
        GuiID_VoiceInput := 0
    }
    
    ; 【关键修复】移除 -Caption，添加标题栏以支持窗口拖动，添加 +Resize 支持调整大小
    GuiID_VoiceInput := Gui("+AlwaysOnTop -DPIScale +Resize -MaximizeBox")
    GuiID_VoiceInput.BackColor := UI_Colors.Background
    GuiID_VoiceInput.SetFont("s12 c" . UI_Colors.Text . " Bold", "Segoe UI")
    GuiID_VoiceInput.Title := GetText("voice_search_title")
    
    ; 添加窗口大小改变和移动事件处理
    ; 注意：在窗口显示后再绑定事件，避免初始化问题
    
    ; 动态计算宽度，确保所有按钮可见
    InputBoxHeight := 150
    global VoiceSearchCurrentCategory, VoiceSearchEnabledCategories
    if (!IsSet(VoiceSearchCurrentCategory) || VoiceSearchCurrentCategory = "") {
        VoiceSearchCurrentCategory := "ai"
    }
    if (!IsSet(VoiceSearchEnabledCategories) || !IsObject(VoiceSearchEnabledCategories)) {
        VoiceSearchEnabledCategories := ["ai", "cli", "academic", "baidu", "image", "audio", "video", "book", "price", "medical", "cloud"]
    }
    ; 【关键修复】确保 VoiceSearchSelectedEnginesByCategory 已初始化
    global VoiceSearchSelectedEnginesByCategory
    if (!IsSet(VoiceSearchSelectedEnginesByCategory) || !IsObject(VoiceSearchSelectedEnginesByCategory)) {
        VoiceSearchSelectedEnginesByCategory := Map()
    }
    
    ; 【关键修复】根据当前分类恢复搜索引擎选择状态
    if (VoiceSearchSelectedEnginesByCategory.Has(VoiceSearchCurrentCategory)) {
        VoiceSearchSelectedEngines := []
        for Index, Engine in VoiceSearchSelectedEnginesByCategory[VoiceSearchCurrentCategory] {
            VoiceSearchSelectedEngines.Push(Engine)
        }
    } else {
        ; 如果当前分类没有保存的状态，使用默认值
        try {
            SearchEngines := GetSortedSearchEngines(VoiceSearchCurrentCategory)
            if (SearchEngines && SearchEngines.Length > 0 && IsObject(SearchEngines[1]) && SearchEngines[1].HasProp("Value")) {
                VoiceSearchSelectedEngines := [SearchEngines[1].Value]
            } else {
                VoiceSearchSelectedEngines := ["deepseek"]
            }
        } catch as err {
            VoiceSearchSelectedEngines := ["deepseek"]
        }
    }
    
    ; 【关键修复】确保 VoiceSearchSelectedEngines 已正确初始化
    if (!IsSet(VoiceSearchSelectedEngines) || !IsObject(VoiceSearchSelectedEngines)) {
        VoiceSearchSelectedEngines := ["deepseek"]
    }
    if (VoiceSearchSelectedEngines.Length = 0) {
        VoiceSearchSelectedEngines := ["deepseek"]
    }
    SearchEngines := GetSortedSearchEngines(VoiceSearchCurrentCategory)
    ; 【修复】确保 SearchEngines 是有效的数组
    if (!IsObject(SearchEngines) || SearchEngines.Length = 0) {
        ; 如果当前分类没有搜索引擎，使用默认分类
        VoiceSearchCurrentCategory := "ai"
        SearchEngines := GetSortedSearchEngines(VoiceSearchCurrentCategory)
        if (!IsObject(SearchEngines) || SearchEngines.Length = 0) {
            ; 如果仍然为空，创建一个默认引擎
            SearchEngines := [{Name: GetText("search_engine_deepseek"), Value: "deepseek", Category: "ai"}]
        }
    }
    TotalEngines := SearchEngines.Length
    ButtonWidth := 130
    ButtonHeight := 35
    ButtonSpacing := 10
    ButtonsPerRow := 4
    ButtonsRows := Ceil(TotalEngines / ButtonsPerRow)
    ButtonsAreaHeight := ButtonsRows * (ButtonHeight + ButtonSpacing)
    
    InputBoxWidth := 520
    RightButtonsWidth := 40 + 20
    ButtonsAreaWidth := ButtonsPerRow * ButtonWidth + (ButtonsPerRow - 1) * ButtonSpacing
    MinWidth := InputBoxWidth + RightButtonsWidth + 40
    PanelWidth := Max(MinWidth, ButtonsAreaWidth + 40)
    
    ; 计算分类标签区域宽度
    TabWidth := 50
    TabSpacing := 5
    TabsPerRow := 10
    TabAreaWidth := TabsPerRow * TabWidth + (TabsPerRow - 1) * TabSpacing
    MinTabAreaWidth := TabAreaWidth + 150
    PanelWidth := Max(PanelWidth, MinTabAreaWidth)
    
    CategoryTabHeight := 28 + 15
    AllCategories := [
        {Key: "ai", Text: GetText("search_category_ai")},
        {Key: "cli", Text: GetText("search_category_cli")},
        {Key: "academic", Text: GetText("search_category_academic")},
        {Key: "baidu", Text: GetText("search_category_baidu")},
        {Key: "image", Text: GetText("search_category_image")},
        {Key: "audio", Text: GetText("search_category_audio")},
        {Key: "video", Text: GetText("search_category_video")},
        {Key: "book", Text: GetText("search_category_book")},
        {Key: "price", Text: GetText("search_category_price")},
        {Key: "medical", Text: GetText("search_category_medical")},
        {Key: "cloud", Text: GetText("search_category_cloud")}
    ]
    
    if (!IsSet(VoiceSearchEnabledCategories) || !IsObject(VoiceSearchEnabledCategories)) {
        VoiceSearchEnabledCategories := ["ai", "cli", "academic", "baidu", "image", "audio", "video", "book", "price", "medical", "cloud"]
    }
    
    Categories := []
    for Index, Category in AllCategories {
        ; 【关键修复】添加安全检查，防止访问无效对象属性导致 "Item has no value" 错误
        if (!IsObject(Category) || !Category.HasProp("Key")) {
            continue  ; 跳过无效的分类对象
        }
        if (ArrayContainsValue(VoiceSearchEnabledCategories, Category.Key) > 0) {
            Categories.Push(Category)
        }
    }
    
    if (Categories.Length = 0) {
        Categories.Push({Key: "ai", Text: GetText("search_category_ai")})
        VoiceSearchCurrentCategory := "ai"
    }
    
    if (ArrayContainsValue(VoiceSearchEnabledCategories, VoiceSearchCurrentCategory) = 0) {
        if (Categories.Length > 0) {
            ; 【关键修复】添加安全检查，防止访问无效对象属性
            if (IsObject(Categories[1]) && Categories[1].HasProp("Key")) {
                VoiceSearchCurrentCategory := Categories[1].Key
            } else {
                VoiceSearchCurrentCategory := "ai"
            }
        } else {
            VoiceSearchCurrentCategory := "ai"
        }
    }
    
    TabRows := Ceil(Categories.Length / TabsPerRow)
    CategoryTabHeight := TabRows * (28 + TabSpacing) + 15
    
    PanelHeight := 30 + 15 + 25 + InputBoxHeight + CategoryTabHeight + 30 + ButtonsAreaHeight + 20
    
    ; 关闭按钮
    CloseBtnX := PanelWidth - 40
    CloseBtnY := 5
    CloseBtn := GuiID_VoiceInput.Add("Text", "x" . CloseBtnX . " y" . CloseBtnY . " w30 h30 Center 0x200 c" . UI_Colors.Text . " Background" . UI_Colors.BtnBg . " vCloseBtn", "×")
    CloseBtn.SetFont("s18 Bold", "Segoe UI")
    CloseBtn.OnEvent("Click", HideVoiceSearchInputPanel)
    HoverBtn(CloseBtn, UI_Colors.BtnBg, "FF4444")
    
    ; 输入框标签
    YPos := 50
    LabelText := GuiID_VoiceInput.Add("Text", "x20 y" . YPos . " w" . (PanelWidth - 80) . " h20 c" . UI_Colors.TextDim, GetText("voice_search_input_label"))
    LabelText.SetFont("s10", "Segoe UI")
    
    ; 检查主题模式
    global ThemeMode
    if (!IsSet(ThemeMode) || ThemeMode = "") {
        ThemeMode := "dark"
    }
    
    ; 牛马图标（放在输入框左边）
    YPos += 25
    IconSize := 32
    IconX := 20
    IconY := YPos
    ; 优先使用用户自定义图标
    global CustomIconPath
    IconPath := ResolveDefaultUiIconPath()
    if (FileExist(IconPath)) {
        VoiceSearchIcon := GuiID_VoiceInput.Add("Picture", "x" . IconX . " y" . IconY . " w" . IconSize . " h" . IconSize . " 0x200", IconPath)
    }
    
    ; 输入框（调整位置，为图标留出空间）
    InputBoxX := IconX + IconSize + 10  ; 图标右边留10px间距
    InputBoxActualWidth := PanelWidth - InputBoxX - 80  ; 减去左边距和右边距
    ; 根据主题模式设置输入框颜色（暗色模式使用cursor黑灰色系）
    if (ThemeMode = "dark") {
        InputBgColor := UI_Colors.InputBg  ; html.to.design 风格背景
        InputTextColor := UI_Colors.Text   ; html.to.design 风格文本
    } else {
        InputBgColor := UI_Colors.InputBg
        InputTextColor := UI_Colors.Text
    }
    VoiceSearchInputEdit := GuiID_VoiceInput.Add("Edit", "x" . InputBoxX . " y" . YPos . " w" . InputBoxActualWidth . " h150 vVoiceSearchInputEdit Background" . InputBgColor . " c" . InputTextColor . " Multi", "")
    VoiceSearchInputEdit.SetFont("s12", "Segoe UI")
    VoiceSearchInputEdit.OnEvent("Focus", SwitchToChineseIME)
    VoiceSearchInputEdit.OnEvent("Change", UpdateVoiceSearchInputEditTime)
    
    ; 清空按钮和搜索按钮
    ClearBtnTextColor := (ThemeMode = "light") ? UI_Colors.Text : "FFFFFF"
    RightBtnX := PanelWidth - 60
    ClearBtn := GuiID_VoiceInput.Add("Text", "x" . RightBtnX . " y" . YPos . " w40 h40 Center 0x200 c" . ClearBtnTextColor . " Background" . UI_Colors.BtnBg . " vClearBtn", GetText("clear"))
    ClearBtn.SetFont("s10", "Segoe UI")
    ClearBtn.OnEvent("Click", ClearVoiceSearchInput)
    HoverBtn(ClearBtn, UI_Colors.BtnBg, UI_Colors.BtnHover)
    
    SearchBtnTextColor := (ThemeMode = "light") ? UI_Colors.Text : "FFFFFF"
    SearchBtn := GuiID_VoiceInput.Add("Text", "x" . RightBtnX . " y" . (YPos + 110) . " w40 h40 Center 0x200 c" . SearchBtnTextColor . " Background" . UI_Colors.BtnPrimary . " vSearchBtn", GetText("voice_search_button"))
    SearchBtn.SetFont("s11 Bold", "Segoe UI")
    SearchBtn.OnEvent("Click", ExecuteVoiceSearch)
    HoverBtn(SearchBtn, UI_Colors.BtnPrimary, UI_Colors.BtnPrimaryHover)
    
    ; 分类标签栏
    YPos += 160
    LabelCategoryWidth := PanelWidth - 280
    LabelCategory := GuiID_VoiceInput.Add("Text", "x20 y" . YPos . " w" . LabelCategoryWidth . " h20 c" . UI_Colors.TextDim, GetText("select_search_engine"))
    LabelCategory.SetFont("s10", "Segoe UI")
    
    ClearSelectionBtnTextColor := (ThemeMode = "light") ? UI_Colors.Text : "FFFFFF"
    ClearSelectionBtnX := PanelWidth - 150
    ClearSelectionBtn := GuiID_VoiceInput.Add("Text", "x" . ClearSelectionBtnX . " y" . YPos . " w130 h25 Center 0x200 c" . ClearSelectionBtnTextColor . " Background" . UI_Colors.BtnBg . " vClearSelectionBtn", GetText("clear_selection"))
    ClearSelectionBtn.SetFont("s10", "Segoe UI")
    ClearSelectionBtn.OnEvent("Click", ClearAllSearchEngineSelection)
    HoverBtn(ClearSelectionBtn, UI_Colors.BtnBg, UI_Colors.BtnHover)
    
    ; 创建分类标签按钮
    YPos += 30
    global VoiceSearchCategoryTabs
    
    VoiceSearchCategoryTabs := []
    TabWidth := 50
    TabHeight := 28
    TabSpacing := 5
    TabStartX := 20
    TabY := YPos
    TabsPerRow := 10
    
    ; 第一行标签
    for Index, Category in Categories {
        ; 【关键修复】添加安全检查，防止访问无效对象属性导致 "Item has no value" 错误
        if (!IsObject(Category) || !Category.HasProp("Key") || !Category.HasProp("Text")) {
            continue  ; 跳过无效的分类对象
        }
        if (Index > TabsPerRow) {
            break
        }
        TabX := TabStartX + (Index - 1) * (TabWidth + TabSpacing)
        IsActive := (VoiceSearchCurrentCategory = Category.Key)
        TabBg := IsActive ? UI_Colors.BtnPrimary : UI_Colors.BtnBg
        TabTextColor := IsActive ? "FFFFFF" : ((ThemeMode = "light") ? UI_Colors.Text : "FFFFFF")
        
        TabBtn := GuiID_VoiceInput.Add("Text", "x" . TabX . " y" . TabY . " w" . TabWidth . " h" . TabHeight . " Center 0x200 c" . TabTextColor . " Background" . TabBg . " vCategoryTab" . Category.Key, Category.Text)
        TabBtn.SetFont("s9", "Segoe UI")
        TabHandler := CreateCategoryTabHandler(Category.Key)
        TabBtn.OnEvent("Click", TabHandler)
        HoverBtn(TabBtn, TabBg, UI_Colors.BtnHover)
        VoiceSearchCategoryTabs.Push({Btn: TabBtn, Key: Category.Key, Handler: TabHandler})
    }
    
    ; 如果标签超过10个，创建第二行
    if (Categories.Length > TabsPerRow) {
        TabY += TabHeight + TabSpacing
        for Index, Category in Categories {
            ; 【关键修复】添加安全检查，防止访问无效对象属性导致 "Item has no value" 错误
            if (!IsObject(Category) || !Category.HasProp("Key") || !Category.HasProp("Text")) {
                continue  ; 跳过无效的分类对象
            }
            if (Index <= TabsPerRow) {
                continue
            }
            TabIndex := Index - TabsPerRow
            TabX := TabStartX + (TabIndex - 1) * (TabWidth + TabSpacing)
            IsActive := (VoiceSearchCurrentCategory = Category.Key)
            TabBg := IsActive ? UI_Colors.BtnPrimary : UI_Colors.BtnBg
            TabTextColor := IsActive ? "FFFFFF" : ((ThemeMode = "light") ? UI_Colors.Text : "FFFFFF")
            
            TabBtn := GuiID_VoiceInput.Add("Text", "x" . TabX . " y" . TabY . " w" . TabWidth . " h" . TabHeight . " Center 0x200 c" . TabTextColor . " Background" . TabBg . " vCategoryTab" . Category.Key, Category.Text)
            TabBtn.SetFont("s9", "Segoe UI")
            TabHandler := CreateCategoryTabHandler(Category.Key)
            TabBtn.OnEvent("Click", TabHandler)
            HoverBtn(TabBtn, TabBg, UI_Colors.BtnHover)
            VoiceSearchCategoryTabs.Push({Btn: TabBtn, Key: Category.Key, Handler: TabHandler})
        }
    }
    
    ; 搜索引擎标签
    YPos := TabY + TabHeight + 15
    LabelEngineWidth := PanelWidth - 40
    LabelEngine := GuiID_VoiceInput.Add("Text", "x20 y" . YPos . " w" . LabelEngineWidth . " h20 c" . UI_Colors.TextDim . " vLabelEngine", GetText("select_search_engine"))
    LabelEngine.SetFont("s10", "Segoe UI")
    
    global VoiceSearchLabelEngineY := YPos
    
    ; 搜索引擎按钮
    YPos += 30
    VoiceSearchEngineButtons := []
    ButtonWidth := 130
    ButtonHeight := 35
    ButtonSpacing := 10
    StartX := 20
    ButtonsPerRow := 4
    IconSizeInButton := 20
    
    AvailableWidth := PanelWidth - 40
    MaxButtonsPerRow := Floor((AvailableWidth + ButtonSpacing) / (ButtonWidth + ButtonSpacing))
    if (MaxButtonsPerRow < 1) {
        MaxButtonsPerRow := 1
    }
    ButtonsPerRow := Min(ButtonsPerRow, MaxButtonsPerRow)
    ButtonsRows := Ceil(TotalEngines / ButtonsPerRow)
    ButtonsAreaHeight := ButtonsRows * (ButtonHeight + ButtonSpacing)
    
    PanelHeight := 30 + 15 + 25 + InputBoxHeight + CategoryTabHeight + 30 + ButtonsAreaHeight + 20
    
    for Index, Engine in SearchEngines {
        ; 【关键修复】添加安全检查，防止访问无效对象属性导致 "Item has no value" 错误
        if (!IsObject(Engine) || !Engine.HasProp("Value") || !Engine.HasProp("Name")) {
            continue  ; 跳过无效的引擎对象
        }
        
        Row := Floor((Index - 1) / ButtonsPerRow)
        Col := Mod((Index - 1), ButtonsPerRow)
        BtnX := StartX + Col * (ButtonWidth + ButtonSpacing)
        BtnY := YPos + Row * (ButtonHeight + ButtonSpacing)
        
        IsSelected := (ArrayContainsValue(VoiceSearchSelectedEngines, Engine.Value) > 0)
        BtnBgColor := IsSelected ? UI_Colors.BtnHover : UI_Colors.BtnBg
        BtnText := IsSelected ? "✓ " . Engine.Name : Engine.Name
        EngineBtnTextColor := (ThemeMode = "light") ? UI_Colors.Text : "FFFFFF"
        
        IconPath := GetSearchEngineIcon(Engine.Value)
        IconCtrl := 0
        
        Btn := GuiID_VoiceInput.Add("Text", "x" . BtnX . " y" . BtnY . " w" . ButtonWidth . " h" . ButtonHeight . " Center 0x200 c" . EngineBtnTextColor . " Background" . BtnBgColor, "")
        Btn.SetFont("s10", "Segoe UI")
        Btn.OnEvent("Click", CreateToggleSearchEngineHandler(Engine.Value, Index))
        HoverBtn(Btn, BtnBgColor, UI_Colors.BtnHover)
        
        if (IconPath != "" && FileExist(IconPath)) {
            try {
                IconX := BtnX + 8
                IconY := BtnY + (ButtonHeight - IconSizeInButton) // 2
                
                ImageSize := GetImageSize(IconPath)
                DisplaySize := CalculateImageDisplaySize(ImageSize.Width, ImageSize.Height, IconSizeInButton, IconSizeInButton)
                
                DisplayX := IconX
                DisplayY := IconY + (IconSizeInButton - DisplaySize.Height) // 2
                
                IconCtrl := GuiID_VoiceInput.Add("Picture", "x" . DisplayX . " y" . DisplayY . " w" . DisplaySize.Width . " h" . DisplaySize.Height . " 0x200", IconPath)
                IconCtrl.OnEvent("Click", CreateToggleSearchEngineHandler(Engine.Value, Index))
                
                TextX := IconX + IconSizeInButton + 5
                TextWidth := ButtonWidth - (TextX - BtnX) - 8
            } catch as err {
                IconCtrl := 0
                TextX := BtnX + 8
                TextWidth := ButtonWidth - 16
            }
        } else {
            TextX := BtnX + 8
            TextWidth := ButtonWidth - 16
        }
        
        TextCtrl := GuiID_VoiceInput.Add("Text", "x" . TextX . " y" . BtnY . " w" . TextWidth . " h" . ButtonHeight . " Left 0x200 c" . EngineBtnTextColor . " BackgroundTrans", BtnText)
        TextCtrl.SetFont("s10", "Segoe UI")
        TextCtrl.OnEvent("Click", CreateToggleSearchEngineHandler(Engine.Value, Index))
        
        VoiceSearchEngineButtons.Push({Bg: Btn, Icon: IconCtrl, Text: TextCtrl, Index: Index})
    }
    
    ; 恢复窗口位置和大小
    WindowName := GetText("voice_search_title")
    RestoredPos := RestoreWindowPosition(WindowName, PanelWidth, PanelHeight)
    if (RestoredPos.X = -1 || RestoredPos.Y = -1) {
        ScreenInfo := GetScreenInfo(VoiceInputScreenIndex)
        Pos := GetPanelPosition(ScreenInfo, PanelWidth, PanelHeight, "center")
        RestoredPos.X := Pos.X
        RestoredPos.Y := Pos.Y
    }
    GuiID_VoiceInput.Show("w" . RestoredPos.Width . " h" . RestoredPos.Height . " x" . RestoredPos.X . " y" . RestoredPos.Y)
    WinSetAlwaysOnTop(1, GuiID_VoiceInput.Hwnd)
    
    ; 添加 Escape 键关闭命令
    GuiID_VoiceInput.OnEvent("Escape", HideVoiceSearchInputPanel)
    
    ; 在窗口显示后绑定事件（避免初始化问题）
    try {
        GuiID_VoiceInput.OnEvent("Size", OnWindowSize)
        ; 注意：AutoHotkey v2 不支持 Move 事件，使用定时器定期保存位置
        ; GuiID_VoiceInput.OnEvent("Move", OnWindowMove)
        SetTimer(() => SaveVoiceInputPosition(), 500)
    } catch as err {
        ; 如果绑定失败，忽略错误（窗口仍然可以正常使用）
    }
    
    VoiceSearchInputEdit.Value := ""
    global VoiceSearchInputLastEditTime := 0
    
    SetTimer(MonitorSelectedText, 0)
    
    WinActivate("ahk_id " . GuiID_VoiceInput.Hwnd)
    Sleep(200)
    
    if (!WinActive("ahk_id " . GuiID_VoiceInput.Hwnd)) {
        WinActivate("ahk_id " . GuiID_VoiceInput.Hwnd)
        Sleep(200)
    }
    
    InputEditHwnd := VoiceSearchInputEdit.Hwnd
    
    try {
        ControlFocus(InputEditHwnd, "ahk_id " . GuiID_VoiceInput.Hwnd)
        Sleep(100)
    } catch as err {
        VoiceSearchInputEdit.Focus()
        Sleep(100)
    }
    
    try {
        ControlFocus(InputEditHwnd, "ahk_id " . GuiID_VoiceInput.Hwnd)
        Sleep(50)
    } catch as err {
        VoiceSearchInputEdit.Focus()
        Sleep(50)
    }
    
    ; 注意：自动加载功能已移除，不再启动定时器
    
    ; 自动激活语音输入
    try {
        Sleep(300)  ; 等待窗口完全显示和焦点设置完成
        StartVoiceInputInSearch()
    } catch as e {
        ; 如果启动语音输入失败，不影响面板显示
        TrayTip(GetText("voice_search_failed") . ": " . e.Message, GetText("error"), "Iconx 2")
    }
}

; ===================== 语音搜索辅助函数 =====================
; 隐藏语音搜索输入界面
HideVoiceSearchInputPanel(*) {
    global GuiID_VoiceInput, VoiceSearchPanelVisible, VoiceSearchInputEdit
    
    ; 自动关闭 CapsLock 大写状态
    SetCapsLockState("Off")
    
    ; 停止监听选中文本
    SetTimer(MonitorSelectedText, 0)
    
    VoiceSearchPanelVisible := false
    
    if (GuiID_VoiceInput != 0) {
        try {
            GuiID_VoiceInput.Destroy()
        }
        GuiID_VoiceInput := 0
    }
    VoiceSearchInputEdit := 0
}

; 清空语音搜索输入框
ClearVoiceSearchInput(*) {
    global VoiceSearchInputEdit, VoiceSearchPanelVisible
    
    if (!VoiceSearchPanelVisible || !VoiceSearchInputEdit) {
        return
    }
    
    try {
        VoiceSearchInputEdit.Value := ""
        ; 重新聚焦到输入框
        VoiceSearchInputEdit.Focus()
    } catch as e {
        ; 忽略错误
    }
}

; 切换自动加载选中文本开关（已删除 - 语音搜索不再支持此功能）
; ToggleAutoLoadSelectedText 函数已删除

; 切换自动更新语音输入开关（已删除 - 语音搜索不再支持此功能）
; ToggleAutoUpdateVoiceInput 函数已删除

; 更新输入框最后编辑时间（用于检测用户是否正在输入）
UpdateVoiceSearchInputEditTime(*) {
    global VoiceSearchInputLastEditTime
    VoiceSearchInputLastEditTime := A_TickCount
}

; 监听选中文本并自动加载到输入框
MonitorSelectedText(*) {
    global AutoLoadSelectedText, VoiceSearchPanelVisible, GuiID_VoiceInput, VoiceSearchInputEdit
    global VoiceSearchInputLastEditTime
    
    ; 如果开关未开启或面板未显示，立即停止监听
    if (!AutoLoadSelectedText || !VoiceSearchPanelVisible || !GuiID_VoiceInput) {
        SetTimer(MonitorSelectedText, 0)
        return
    }
    
    ; 检测用户是否正在输入：如果输入框在最近2秒内被编辑过，说明用户正在输入，不自动加载
    CurrentTime := A_TickCount
    if (VoiceSearchInputLastEditTime > 0 && (CurrentTime - VoiceSearchInputLastEditTime) < 2000) {
        ; 用户正在输入（最近2秒内编辑过），不自动加载
        return
    }
    
    ; 检查输入框是否有内容，如果有内容且不是最近编辑的，也不自动加载（避免覆盖用户已输入的内容）
    try {
        if (VoiceSearchInputEdit && VoiceSearchInputEdit.Value != "") {
            ; 输入框有内容，且不是最近编辑的，不自动加载（避免覆盖用户输入）
            return
        }
    } catch as err {
        ; 忽略错误
    }
    
    ; 检查是否有选中的文本
    try {
        ; 保存当前剪贴板
        OldClipboard := A_Clipboard
        
        ; 尝试复制选中文本
        A_Clipboard := ""
        Send("^c")
        Sleep(50)  ; 等待复制完成
        
        ; 检查是否复制成功
        if (ClipWait(0.1) && A_Clipboard != "" && A_Clipboard != OldClipboard) {
            ; 有选中文本，加载到输入框
            SelectedText := A_Clipboard
            if (SelectedText != "" && StrLen(SelectedText) > 0) {
                ; 尝试获取输入框控件并更新
                try {
                    if (VoiceSearchInputEdit && (VoiceSearchInputEdit.Value = "" || VoiceSearchInputEdit.Value != SelectedText)) {
                        VoiceSearchInputEdit.Value := SelectedText
                    }
                } catch as err {
                    ; 忽略错误
                }
            }
        }
        
        ; 恢复剪贴板
        A_Clipboard := OldClipboard
    } catch as err {
        ; 忽略错误
    }
}

; 更新语音搜索输入框内容（定时器调用）
UpdateVoiceSearchInputInPanel(*) {
    global VoiceSearchActive, VoiceSearchInputEdit, VoiceSearchPanelVisible, AutoLoadSelectedText, AutoUpdateVoiceInput, GuiID_VoiceInput, VoiceInputMethod
    
    ; 如果"自动更新语音输入"和"自动加载选中文本"都未开启，停止定时器
    if (!AutoUpdateVoiceInput && !AutoLoadSelectedText) {
        SetTimer(UpdateVoiceSearchInputInPanel, 0)
        return
    }
    
    if (!VoiceSearchActive || !VoiceSearchPanelVisible || !VoiceSearchInputEdit) {
        SetTimer(UpdateVoiceSearchInputInPanel, 0)
        return
    }
    
    try {
        ; 检测百度输入法语音识别窗口是否存在
        BaiduVoiceWindowActive := false
        if (VoiceInputMethod = "baidu") {
            BaiduVoiceWindowActive := IsBaiduVoiceWindowActive()
        }
        
        ; 获取输入框的控件句柄
        InputEditHwnd := VoiceSearchInputEdit.Hwnd
        
        ; 如果百度输入法的语音识别窗口存在，使用ControlFocus确保输入框有输入焦点
        if (BaiduVoiceWindowActive) {
            if (GuiID_VoiceInput) {
                if (WinExist("ahk_id " . GuiID_VoiceInput.Hwnd)) {
                    try {
                        ControlFocus(InputEditHwnd, "ahk_id " . GuiID_VoiceInput.Hwnd)
                        Sleep(20)
                    } catch as err {
                        try {
                            VoiceSearchInputEdit.Focus()
                            Sleep(20)
                        } catch as err {
                        }
                    }
                }
            }
        } else {
            ; 输入法窗口不存在时，正常激活主窗口并设置焦点
            if (GuiID_VoiceInput) {
                if (!WinActive("ahk_id " . GuiID_VoiceInput.Hwnd)) {
                    WinActivate("ahk_id " . GuiID_VoiceInput.Hwnd)
                    Sleep(100)
                }
                
                try {
                    ControlFocus(InputEditHwnd, "ahk_id " . GuiID_VoiceInput.Hwnd)
                    Sleep(50)
                } catch as err {
                    VoiceSearchInputEdit.Focus()
                    Sleep(50)
                }
            }
        }
        
        ; 尝试直接读取输入框内容
        OldClipboard := A_Clipboard
        CurrentContent := ""
        CurrentInputValue := ""
        
        try {
            CurrentInputValue := VoiceSearchInputEdit.Value
            CurrentContent := CurrentInputValue
        } catch as err {
            ; 如果直接读取失败，使用剪贴板方式
            if (!BaiduVoiceWindowActive && GuiID_VoiceInput) {
                if (!WinActive("ahk_id " . GuiID_VoiceInput.Hwnd)) {
                    WinActivate("ahk_id " . GuiID_VoiceInput.Hwnd)
                    Sleep(50)
                }
                try {
                    ControlFocus(InputEditHwnd, "ahk_id " . GuiID_VoiceInput.Hwnd)
                    Sleep(30)
                } catch as err {
                    VoiceSearchInputEdit.Focus()
                    Sleep(30)
                }
                
                Send("^a")
                Sleep(30)
                A_Clipboard := ""
                Send("^c")
                Sleep(80)
                
                if (ClipWait(0.15)) {
                    CurrentContent := A_Clipboard
                }
            }
        }
        
        ; 处理读取到的内容
        if (CurrentContent != "" && StrLen(CurrentContent) > 0) {
            ; 检查内容是否看起来像语音输入的内容
            if (CurrentInputValue = "" && (InStr(CurrentContent, "\") || InStr(CurrentContent, ".lnk") || InStr(CurrentContent, "快捷方式"))) {
                ; 忽略看起来像文件路径或快捷方式的内容
                A_Clipboard := OldClipboard
                return
            }
            
            ; 如果内容有变化且新内容更长，更新输入框
            if (CurrentContent != CurrentInputValue && StrLen(CurrentContent) >= StrLen(CurrentInputValue)) {
                try {
                    ; 在输入法窗口存在时，不更新输入框内容（避免干扰输入法）
                    if (!BaiduVoiceWindowActive) {
                        VoiceSearchInputEdit.Value := CurrentContent
                        ; 将光标移到末尾
                        try {
                            ControlFocus(InputEditHwnd, "ahk_id " . GuiID_VoiceInput.Hwnd)
                            Sleep(20)
                            Send("^{End}")
                        } catch as err {
                        }
                    }
                } catch as err {
                }
            }
        }
        
        ; 恢复剪贴板
        A_Clipboard := OldClipboard
    } catch as err {
        ; 忽略错误
    }
}

; 创建切换搜索引擎选择处理函数
CreateToggleSearchEngineHandler(Engine, BtnIndex) {
    ToggleSearchEngineHandler(*) {
        global VoiceSearchSelectedEngines, VoiceSearchEngineButtons, UI_Colors
        global VoiceSearchCurrentCategory, VoiceSearchSelectedEnginesByCategory, ConfigFile
        
        ; 确保 VoiceSearchSelectedEnginesByCategory 已初始化
        if (!IsSet(VoiceSearchSelectedEnginesByCategory) || !IsObject(VoiceSearchSelectedEnginesByCategory)) {
            VoiceSearchSelectedEnginesByCategory := Map()
        }
        
        ; 切换选择状态
        FoundIndex := ArrayContainsValue(VoiceSearchSelectedEngines, Engine)
        if (FoundIndex > 0) {
            ; 取消选择
            VoiceSearchSelectedEngines.RemoveAt(FoundIndex)
        } else {
            ; 添加选择
            VoiceSearchSelectedEngines.Push(Engine)
        }
        
        ; 【关键修复】保存当前分类的选择状态到分类Map中
        if (VoiceSearchCurrentCategory != "") {
            CurrentEngines := []
            for Index, Eng in VoiceSearchSelectedEngines {
                CurrentEngines.Push(Eng)
            }
            VoiceSearchSelectedEnginesByCategory[VoiceSearchCurrentCategory] := CurrentEngines
        }
        
        ; 保存到配置文件（保存当前分类的选择状态）
        try {
            EnginesStr := ""
            for Index, Eng in VoiceSearchSelectedEngines {
                if (Index > 1) {
                    EnginesStr .= ","
                }
                EnginesStr .= Eng
            }
            if (EnginesStr = "") {
                EnginesStr := "deepseek"
            }
            ; 保存格式：分类:引擎1,引擎2
            CategoryEnginesStr := VoiceSearchCurrentCategory . ":" . EnginesStr
            IniWrite(CategoryEnginesStr, ConfigFile, "Settings", "VoiceSearchSelectedEngines_" . VoiceSearchCurrentCategory)
        } catch as e {
            TrayTip("保存搜索引擎选择失败: " . e.Message, "错误", "Iconx 1")
        }
        
        ; 更新按钮样式
        if (IsSet(VoiceSearchEngineButtons) && VoiceSearchEngineButtons.Length > 0 && BtnIndex <= VoiceSearchEngineButtons.Length) {
            BtnObj := VoiceSearchEngineButtons[BtnIndex]
            if (BtnObj && IsObject(BtnObj)) {
                IsSelected := (ArrayContainsValue(VoiceSearchSelectedEngines, Engine) > 0)
                
                ; 更新背景颜色
                if (BtnObj.Bg) {
                    BtnObj.Bg.BackColor := IsSelected ? UI_Colors.BtnHover : UI_Colors.BtnBg
                }
                
                ; 更新文字（添加/移除 ✓ 标记）
                if (BtnObj.Text) {
                    AllEngines := GetAllSearchEngines()
                    EngineName := ""
                    for Index, Eng in AllEngines {
                        if (Eng.Value = Engine) {
                            EngineName := Eng.Name
                            break
                        }
                    }
                    if (EngineName != "") {
                        BtnObj.Text.Text := IsSelected ? "✓ " . EngineName : EngineName
                    }
                }
            }
        }
        
        ; 立即刷新GUI
        try {
            global GuiID_VoiceInput
            if (GuiID_VoiceInput && IsObject(GuiID_VoiceInput) && GuiID_VoiceInput.HasProp("Hwnd")) {
                WinRedraw(GuiID_VoiceInput.Hwnd)
            }
        } catch as err {
        }
    }
    return ToggleSearchEngineHandler
}

; 清空所有搜索引擎选择
ClearAllSearchEngineSelection(*) {
    global VoiceSearchSelectedEngines, VoiceSearchEngineButtons, UI_Colors, GuiID_VoiceInput
    global ConfigFile, VoiceSearchCurrentCategory
    
    ; 清空选择数组
    VoiceSearchSelectedEngines := []
    
    ; 保存到配置文件
    try {
        IniWrite("deepseek", ConfigFile, "Settings", "VoiceSearchSelectedEngines")
    } catch as e {
    }
    
    ; 更新所有按钮的样式
    if (IsSet(VoiceSearchEngineButtons) && VoiceSearchEngineButtons.Length > 0) {
        try {
            CurrentEngines := GetSortedSearchEngines(VoiceSearchCurrentCategory)
        } catch as err {
            CurrentEngines := []
        }
        
        for Index, BtnObj in VoiceSearchEngineButtons {
            if (BtnObj && IsObject(BtnObj)) {
                try {
                    if (BtnObj.Bg && IsObject(BtnObj.Bg)) {
                        BtnObj.Bg.BackColor := UI_Colors.BtnBg
                    }
                } catch as err {
                }
                
                try {
                    if (BtnObj.Text && IsObject(BtnObj.Text) && BtnObj.Index > 0 && BtnObj.Index <= CurrentEngines.Length) {
                        EngineName := CurrentEngines[BtnObj.Index].Name
                        if (EngineName != "") {
                            CurrentText := BtnObj.Text.Text
                            if (SubStr(CurrentText, 1, 2) = "✓ ") {
                                BtnObj.Text.Text := EngineName
                            } else {
                                BtnObj.Text.Text := EngineName
                            }
                        }
                    }
                } catch as err {
                }
            }
        }
    }
    
    ; 立即刷新GUI
    try {
        if (GuiID_VoiceInput && IsObject(GuiID_VoiceInput) && GuiID_VoiceInput.HasProp("Hwnd")) {
            WinRedraw(GuiID_VoiceInput.Hwnd)
        }
    } catch as err {
    }
    
; 显示提示
TrayTip(GetText("cleared"), GetText("tip"), "Iconi 1")
}

OpenAdminWindowsPowerShell() {
    PowerShellPath := A_WinDir . "\System32\WindowsPowerShell\v1.0\powershell.exe"
    if (!FileExist(PowerShellPath)) {
        throw Error("找不到 Windows PowerShell")
    }
    Run('*RunAs "' . PowerShellPath . '"')
}

GetCLIAgentLaunchInfo(Engine) {
    switch Engine {
        case "codex_cli":
            return {Name: GetText("search_engine_cli_codex"), Command: GetPreferredCLIExecutable("codex_cli")}
        case "gemini_cli":
            return {Name: GetText("search_engine_cli_gemini"), Command: GetPreferredCLIExecutable("gemini_cli")}
        case "openclaw_cli":
            return {Name: GetText("search_engine_cli_openclaw"), Command: GetPreferredCLIExecutable("openclaw_cli")}
        case "qwen_cli":
            return {Name: GetText("search_engine_cli_qwen"), Command: GetPreferredCLIExecutable("qwen_cli")}
        default:
            return 0
    }
}

; 使用 where.exe 解析 PATH 中的可执行文件，返回首个存在的完整路径
TryResolveExecutableViaWhere(WhereExe, Name) {
    if (Name = "" || !FileExist(WhereExe)) {
        return ""
    }
    try {
        Shell := ComObject("WScript.Shell")
        Exec := Shell.Exec('"' . WhereExe . '" "' . Name . '"')
        while (Exec.Status = 0) {
            Sleep(20)
        }
        Out := Exec.StdOut.ReadAll()
        for Line in StrSplit(Out, "`n", "`r") {
            L := Trim(Line)
            if (L = "" || InStr(L, "INFO:") = 1) {
                continue
            }
            if (FileExist(L)) {
                return L
            }
        }
    } catch {
    }
    return ""
}

; 将裸名（如 codex.cmd）解析为 PATH 或 where.exe 找到的完整路径，避免 PowerShell 中 & 'codex.cmd' 因不在 PATH 而失败
ResolveBareCLIExecutableInPath(ExecutableName) {
    if (ExecutableName = "" || InStr(ExecutableName, "\")) {
        return ExecutableName
    }
    if (FileExist(A_ScriptDir . "\" . ExecutableName)) {
        return A_ScriptDir . "\" . ExecutableName
    }
    WhereExe := A_WinDir . "\System32\where.exe"
    R := TryResolveExecutableViaWhere(WhereExe, ExecutableName)
    if (R != "") {
        return R
    }
    Base := StrReplace(StrReplace(ExecutableName, ".cmd", ""), ".exe", "")
    if (Base != "" && Base != ExecutableName) {
        R := TryResolveExecutableViaWhere(WhereExe, Base)
        if (R != "") {
            return R
        }
    }
    return ExecutableName
}

GetPreferredCLIExecutable(Engine) {
    LocalAppDataDir := EnvGet("LOCALAPPDATA")
    Candidates := []
    switch Engine {
        case "codex_cli":
            Candidates := [
                A_AppData . "\npm-global\codex.cmd",
                A_AppData . "\npm\codex.cmd",
                LocalAppDataDir . "\npm\codex.cmd",
                LocalAppDataDir . "\npm-global\codex.cmd",
                "codex.cmd"
            ]
        case "gemini_cli":
            Candidates := [
                A_AppData . "\npm\gemini.cmd",
                A_AppData . "\npm-global\gemini.cmd",
                "gemini.cmd"
            ]
        case "openclaw_cli":
            Candidates := [
                LocalAppDataDir . "\pnpm\openclaw.cmd",
                A_AppData . "\npm\openclaw.cmd",
                A_AppData . "\npm-global\openclaw.cmd",
                "C:\Program Files\Qclaw\resources\cli\openclaw.cmd",
                "openclaw.cmd"
            ]
        case "qwen_cli":
            Candidates := [
                A_AppData . "\npm-global\qwen.cmd",
                A_AppData . "\npm\qwen.cmd",
                LocalAppDataDir . "\npm\qwen.cmd",
                LocalAppDataDir . "\npm-global\qwen.cmd",
                "qwen.cmd"
            ]
        default:
            return ""
    }
    
    for _, Candidate in Candidates {
        if (InStr(Candidate, "\") && FileExist(Candidate)) {
            return Candidate
        }
    }
    Last := Candidates.Length > 0 ? Candidates[Candidates.Length] : ""
    Resolved := ResolveBareCLIExecutableInPath(Last)
    ; 仍未解析出磁盘路径时无法安全启动（避免 PowerShell 中 & 'codex.cmd' 报错）
    if (Resolved != "" && !InStr(Resolved, "\") && !InStr(Resolved, "/")) {
        return ""
    }
    return Resolved
}

GetCLIAgentWindowTitle(Engine) {
    ; 必须与 scripts/cli_window_bridge.py 中 AGENTS 的英文 name 一致，否则无法匹配队列终端窗口标题
    switch Engine {
        case "codex_cli":
            return "CursorHelper AI - Codex"
        case "gemini_cli":
            return "CursorHelper AI - Gemini"
        case "openclaw_cli":
            return "CursorHelper AI - OpenClaw"
        case "qwen_cli":
            return "CursorHelper AI - Qwen"
        default:
            AgentInfo := GetCLIAgentLaunchInfo(Engine)
            if (!AgentInfo || !IsObject(AgentInfo)) {
                return ""
            }
            return "CursorHelper AI - " . AgentInfo.Name
    }
}

FindCLIAgentWindow(Engine) {
    WindowTitle := GetCLIAgentWindowTitle(Engine)
    if (WindowTitle = "") {
        return 0
    }
    return WinExist(WindowTitle)
}

GetCLIAgentInputControl(WindowHwnd) {
    if (!WindowHwnd) {
        return ""
    }

    try {
        FocusedControl := ControlGetFocus("ahk_id " . WindowHwnd)
        if (FocusedControl != "") {
            return FocusedControl
        }
    } catch {
    }

    PreferredPatterns := [
        "CASCADIA_HOSTING_WINDOW_CLASS",
        "Windows.UI",
        "TermControl",
        "Terminal",
        "Console",
        "Chrome_WidgetWin"
    ]

    try {
        Controls := WinGetControls("ahk_id " . WindowHwnd)
        for _, Pattern in PreferredPatterns {
            for _, ControlName in Controls {
                if (InStr(ControlName, Pattern)) {
                    return ControlName
                }
            }
        }
        if (Controls.Length > 0) {
            return Controls[1]
        }
    } catch {
    }

    return ""
}

RestoreClipboardDeferred(ClipboardBackup, DelayMs := 10000) {
    SetTimer((*) => (
        A_Clipboard := ClipboardBackup
    ), -DelayMs)
}

SendPromptToCLIAgentWindow(WindowHwnd, PromptText, Engine := "") {
    if (!WindowHwnd || PromptText = "") {
        return
    }

    try {
        WinActivate("ahk_id " . WindowHwnd)
        WinWaitActive("ahk_id " . WindowHwnd, , 3)
        Sleep((Engine = "qwen_cli" || Engine = "gemini_cli") ? 400 : 180)

        if (Engine = "codex_cli") {
            SendText(PromptText)
            Sleep(100)
            Send("{Enter}")
            return
        }

        ; Qwen / Gemini TUI：Ctrl+V 往往无效；优先对终端子控件 ControlSend {Text}（与 Windows Terminal 兼容），否则回退 SendText
        if (Engine = "qwen_cli" || Engine = "gemini_cli") {
            TargetCtl := GetCLIAgentInputControl(WindowHwnd)
            if (TargetCtl != "") {
                try ControlFocus(TargetCtl, "ahk_id " . WindowHwnd)
                Sleep(150)
            }
            try {
                if (TargetCtl != "") {
                    ControlSend("{Text}" . PromptText, TargetCtl, "ahk_id " . WindowHwnd)
                    Sleep(80)
                    ControlSend("{Enter}", TargetCtl, "ahk_id " . WindowHwnd)
                } else {
                    SendText(PromptText)
                    Sleep(120)
                    Send("{Enter}")
                }
            } catch {
                SendText(PromptText)
                Sleep(120)
                Send("{Enter}")
            }
            return
        }

        TargetControl := GetCLIAgentInputControl(WindowHwnd)

        if (TargetControl != "") {
            ControlSend("{Text}" . PromptText, TargetControl, "ahk_id " . WindowHwnd)
            Sleep(120)
            ControlSend("{Enter}", TargetControl, "ahk_id " . WindowHwnd)
            return
        }

        ControlSend("{Text}" . PromptText, , "ahk_id " . WindowHwnd)
        Sleep(120)
        ControlSend("{Enter}", , "ahk_id " . WindowHwnd)
    } catch {
    }
}

GetWindowTextSafe(WindowHwnd) {
    if (!WindowHwnd) {
        return ""
    }
    try {
        return WinGetText("ahk_id " . WindowHwnd)
    } catch {
        return ""
    }
}

GeminiWindowNeedsAuth(WindowHwnd) {
    WindowText := StrLower(GetWindowTextSafe(WindowHwnd))
    ; 文本尚不可读时不当作「仍在登录页」，避免永远不发（终端刚启动时常短暂为空）
    if (WindowText = "") {
        return false
    }
    AuthPatterns := [
        "sign in",
        "login",
        "authenticate",
        "authentication",
        "browser",
        "google account",
        "continue in browser",
        "waiting for authentication",
        "open this url",
        "open the following link",
        "登录",
        "在浏览器",
        "verify it"
    ]
    for _, Pattern in AuthPatterns {
        if (InStr(WindowText, Pattern)) {
            return true
        }
    }
    return false
}

RegisterPendingCLIAgentPrompt(WindowHwnd, PromptText, Engine := "gemini_cli") {
    global CLIAgentPendingPrompts, CLIAgentPromptMonitorRunning
    
    if (PromptText = "") {
        return
    }
    
    PendingKey := String(WindowHwnd)
    CLIAgentPendingPrompts[PendingKey] := {
        Hwnd: WindowHwnd,
        Prompt: PromptText,
        Engine: Engine,
        CreatedAt: A_TickCount,
        ProbeSent: false,
        InputWakeSent: false,
        LastWindowText: "",
        ReadySeenCount: 0,
        EmptyWindowTextRounds: 0,
        FallbackMode: false,
        GeminiLastText: "",
        GeminiStableRounds: 0,
        GeminiEmptyPolls: 0
    }
    
    if (!CLIAgentPromptMonitorRunning) {
        CLIAgentPromptMonitorRunning := true
        SetTimer(MonitorPendingCLIAgentPrompts, 500)
    }
}

QueuePromptForCLIAgent(Engine, WindowHwnd, PromptText) {
    AgentInfo := GetCLIAgentLaunchInfo(Engine)
    if (!AgentInfo || !WindowHwnd || PromptText = "") {
        return false
    }
    
    if (Engine = "gemini_cli") {
        RegisterPendingCLIAgentPrompt(WindowHwnd, PromptText, Engine)
        TrayTip(AgentInfo.Name . " 正在等待终端就绪（登录完成后界面稳定即发送）。", "提示", "Iconi 2")
        return true
    }
    
    if (Engine = "codex_cli") {
        RegisterPendingCLIAgentPrompt(WindowHwnd, PromptText, Engine)
        TrayTip(AgentInfo.Name . " 正在等待终端就绪，准备好后会自动发送。", "提示", "Iconi 2")
        return true
    }
    
    if (Engine = "qwen_cli") {
        RegisterPendingCLIAgentPrompt(WindowHwnd, PromptText, Engine)
        TrayTip(AgentInfo.Name . " 正在等待终端就绪，准备好后会自动发送。", "提示", "Iconi 2")
        return true
    }
    
    return false
}

DispatchPromptToCLIAgent(Engine, LaunchResult, PromptText) {
    if (PromptText = "" || !IsObject(LaunchResult) || !LaunchResult.Hwnd) {
        return
    }
    
    if (Engine = "codex_cli") {
        if (LaunchResult.IsNew) {
            QueuePromptForCLIAgent(Engine, LaunchResult.Hwnd, PromptText)
        } else {
            SendPromptToCLIAgentWindow(LaunchResult.Hwnd, PromptText, Engine)
        }
        return
    }
    
    if (Engine = "qwen_cli") {
        if (LaunchResult.IsNew) {
            QueuePromptForCLIAgent(Engine, LaunchResult.Hwnd, PromptText)
        } else {
            SendPromptToCLIAgentWindow(LaunchResult.Hwnd, PromptText, Engine)
        }
        return
    }
    
    if (Engine = "gemini_cli") {
        if (LaunchResult.IsNew) {
            QueuePromptForCLIAgent(Engine, LaunchResult.Hwnd, PromptText)
        } else {
            SendPromptToCLIAgentWindow(LaunchResult.Hwnd, PromptText, Engine)
        }
        return
    } else if (LaunchResult.IsNew) {
        AgentInfo := GetCLIAgentLaunchInfo(Engine)
        if (AgentInfo && IsObject(AgentInfo)) {
            TrayTip(AgentInfo.Name . " 已打开。首次启动可能需要认证或等待加载，准备好后再次点击发送。", "提示", "Iconi 2")
        }
        return
    }
    
    SendPromptToCLIAgentWindow(LaunchResult.Hwnd, PromptText, Engine)
}

MonitorPendingCLIAgentPrompts() {
    global CLIAgentPendingPrompts, CLIAgentPromptMonitorRunning
    global CLIGeminiReadyMinMs, CLIGeminiStablePollsRequired, CLIGeminiForceSendAfterMs, CLIGeminiNoTextMinMs
    
    if (!IsSet(CLIAgentPendingPrompts) || CLIAgentPendingPrompts.Count = 0) {
        CLIAgentPromptMonitorRunning := false
        SetTimer(MonitorPendingCLIAgentPrompts, 0)
        return
    }
    
    CompletedKeys := []
    for Key, Pending in CLIAgentPendingPrompts {
        if (!WinExist("ahk_id " . Pending.Hwnd)) {
            CompletedKeys.Push(Key)
            continue
        }
        
        MaxWaitMs := (Pending.Engine = "gemini_cli") ? 120000 : 90000
        if ((A_TickCount - Pending.CreatedAt) > MaxWaitMs) {
            CompletedKeys.Push(Key)
            AgentInfo := GetCLIAgentLaunchInfo(Pending.Engine)
            AgentName := (AgentInfo && IsObject(AgentInfo)) ? AgentInfo.Name : Pending.Engine
            TrayTip(AgentName . " 等待就绪超时，请完成启动后重新发送。", "提示", "Icon! 2")
            continue
        }
        
        ; Gemini：登录态阻塞；有 WinGetText 时按文本稳定；无文本（Windows Terminal 常见）则按 EmptyPolls 回退，否则会永远不发送
        if (Pending.Engine = "gemini_cli") {
            LatestGeminiWindow := FindCLIAgentWindow("gemini_cli")
            if (LatestGeminiWindow) {
                Pending.Hwnd := LatestGeminiWindow
            }
            Hwnd := Pending.Hwnd
            if (!Hwnd || !WinExist("ahk_id " . Hwnd)) {
                CLIAgentPendingPrompts[Key] := Pending
                continue
            }
            if (GeminiWindowNeedsAuth(Hwnd)) {
                Pending.GeminiStableRounds := 0
                Pending.GeminiLastText := ""
                Pending.GeminiEmptyPolls := 0
                CLIAgentPendingPrompts[Key] := Pending
                continue
            }
            CurrentText := GetWindowTextSafe(Hwnd)
            Elapsed := A_TickCount - Pending.CreatedAt
            if (Elapsed < CLIGeminiReadyMinMs) {
                Pending.GeminiLastText := CurrentText
                Pending.GeminiStableRounds := 1
                Pending.GeminiEmptyPolls := 0
                CLIAgentPendingPrompts[Key] := Pending
                continue
            }
            if (CurrentText = "") {
                if (Elapsed < CLIGeminiNoTextMinMs) {
                    Pending.GeminiStableRounds := 0
                    Pending.GeminiLastText := ""
                    Pending.GeminiEmptyPolls := 0
                    CLIAgentPendingPrompts[Key] := Pending
                    continue
                }
                Pending.GeminiLastText := ""
                Pending.GeminiStableRounds := 0
                Pending.GeminiEmptyPolls += 1
                CLIAgentPendingPrompts[Key] := Pending
                NoTextReady := (Pending.GeminiEmptyPolls >= CLIGeminiStablePollsRequired)
                ForceSend := (CLIGeminiForceSendAfterMs > 0 && Elapsed >= CLIGeminiForceSendAfterMs)
                if (NoTextReady || ForceSend) {
                    SendPromptToCLIAgentWindow(Pending.Hwnd, Pending.Prompt, Pending.Engine)
                    CompletedKeys.Push(Key)
                }
                continue
            }
            Pending.GeminiEmptyPolls := 0
            if (CurrentText = Pending.GeminiLastText) {
                Pending.GeminiStableRounds += 1
            } else {
                Pending.GeminiLastText := CurrentText
                Pending.GeminiStableRounds := 1
            }
            CLIAgentPendingPrompts[Key] := Pending
            StableReady := (Pending.GeminiStableRounds >= CLIGeminiStablePollsRequired)
            ForceSend := false
            if (CLIGeminiForceSendAfterMs > 0 && Elapsed >= CLIGeminiForceSendAfterMs) {
                ForceSend := true
            }
            if (StableReady || ForceSend) {
                SendPromptToCLIAgentWindow(Pending.Hwnd, Pending.Prompt, Pending.Engine)
                CompletedKeys.Push(Key)
            }
            continue
        }
        
        if (Pending.Engine = "codex_cli" || Pending.Engine = "qwen_cli") {
            RequiredDelay := (Pending.Engine = "qwen_cli") ? 4000 : 2500
            if ((A_TickCount - Pending.CreatedAt) < RequiredDelay) {
                continue
            }
            SendPromptToCLIAgentWindow(Pending.Hwnd, Pending.Prompt, Pending.Engine)
            CompletedKeys.Push(Key)
            continue
        }
        
        CurrentWindowText := GetWindowTextSafe(Pending.Hwnd)
        if (CurrentWindowText = "") {
            Pending.EmptyWindowTextRounds += 1
            if (Pending.EmptyWindowTextRounds >= 20) {
                Pending.FallbackMode := true
            }
            CLIAgentPendingPrompts[Key] := Pending
        } else {
            Pending.EmptyWindowTextRounds := 0
            if (GeminiWindowNeedsAuth(Pending.Hwnd)) {
                CLIAgentPendingPrompts[Key] := Pending
                continue
            }
        }
        
        if (!Pending.FallbackMode && CurrentWindowText = "") {
            continue
        }
        
        if (!Pending.ProbeSent) {
            try {
                WinActivate("ahk_id " . Pending.Hwnd)
                WinWaitActive("ahk_id " . Pending.Hwnd, , 3)
                Sleep(200)
                Send("{Enter}")
                Pending.ProbeSent := true
                Pending.CreatedAt := A_TickCount
                Pending.LastWindowText := CurrentWindowText
                Pending.ReadySeenCount := 0
                CLIAgentPendingPrompts[Key] := Pending
            } catch {
            }
            continue
        }
        
        if (Pending.FallbackMode) {
            if ((A_TickCount - Pending.CreatedAt) < 1800) {
                CLIAgentPendingPrompts[Key] := Pending
                continue
            }
            SendPromptToCLIAgentWindow(Pending.Hwnd, Pending.Prompt, Pending.Engine)
            CompletedKeys.Push(Key)
            continue
        }
        
        if (CurrentWindowText != Pending.LastWindowText) {
            Pending.LastWindowText := CurrentWindowText
            Pending.ReadySeenCount := 1
            CLIAgentPendingPrompts[Key] := Pending
            continue
        }
        
        Pending.ReadySeenCount += 1
        CLIAgentPendingPrompts[Key] := Pending
        if (Pending.ReadySeenCount < 3) {
            continue
        }
        
        Sleep(200)
        SendPromptToCLIAgentWindow(Pending.Hwnd, Pending.Prompt, Pending.Engine)
        CompletedKeys.Push(Key)
    }
    
    for _, Key in CompletedKeys {
        try CLIAgentPendingPrompts.Delete(Key)
    }
    
    if (CLIAgentPendingPrompts.Count = 0) {
        CLIAgentPromptMonitorRunning := false
        SetTimer(MonitorPendingCLIAgentPrompts, 0)
    }
}

OpenCLIAgentTerminal(Engine) {
    AgentInfo := GetCLIAgentLaunchInfo(Engine)
    if (!AgentInfo || !IsObject(AgentInfo)) {
        throw Error("未配置该 CLI: " . Engine)
    }
    if (AgentInfo.Command = "") {
        throw Error("找不到 " . AgentInfo.Name . " 可执行文件。请安装 CLI（例如 npm 全局安装）或将其加入系统 PATH。")
    }
    
    ExistingWindow := FindCLIAgentWindow(Engine)
    if (ExistingWindow) {
        try {
            WinActivate("ahk_id " . ExistingWindow)
            WinWaitActive("ahk_id " . ExistingWindow, , 3)
        } catch {
        }
        return {Hwnd: ExistingWindow, IsNew: false}
    }
    
    PowerShellPath := A_WinDir . "\System32\WindowsPowerShell\v1.0\powershell.exe"
    if (!FileExist(PowerShellPath)) {
        throw Error("找不到 Windows PowerShell")
    }
    
    WinTitleStr := GetCLIAgentWindowTitle(Engine)
    if (WinTitleStr = "") {
        WinTitleStr := "CursorHelper AI - " . AgentInfo.Name
    }
    ; Gemini：与 Qwen 一样走原生交互终端；启动前由 gemini_native_terminal.ps1 加载 .env / 注册表等（与队列 worker 共用 gemini_env.ps1）
    if (Engine = "gemini_cli") {
        NativeScript := A_ScriptDir . "\scripts\gemini_native_terminal.ps1"
        if (!FileExist(NativeScript)) {
            throw Error("找不到 Gemini 启动脚本: " . NativeScript)
        }
        EscapedTitle := StrReplace(WinTitleStr, "'", "''")
        EscapedWorkDir := StrReplace(A_ScriptDir, "'", "''")
        EscapedExe := StrReplace(AgentInfo.Command, "'", "''")
        CommandLine := '"' . PowerShellPath . '" -NoExit -ExecutionPolicy Bypass -File "' . NativeScript . '" -Title "' . EscapedTitle . '" -Workdir "' . EscapedWorkDir . '" -Executable "' . EscapedExe . '"'
        Run(CommandLine, A_ScriptDir, , &TerminalPid)
        WinWaitActive("ahk_pid " . TerminalPid, , 5)
        return {Hwnd: WinExist("ahk_pid " . TerminalPid), IsNew: true}
    }
    EscapedTitle := StrReplace(WinTitleStr, "'", "''")
    EscapedWorkDir := StrReplace(A_ScriptDir, "'", "''")
    EscapedCommand := StrReplace(AgentInfo.Command, "'", "''")
    PowerShellCommand := "$Host.UI.RawUI.WindowTitle = '" . EscapedTitle . "'; Set-Location -LiteralPath '" . EscapedWorkDir . "'; & '" . EscapedCommand . "'"
    CommandLine := '"' . PowerShellPath . '" -NoExit -ExecutionPolicy Bypass -Command "' . PowerShellCommand . '"'
    Run(CommandLine, A_ScriptDir, , &TerminalPid)
    WinWaitActive("ahk_pid " . TerminalPid, , 5)
    return {Hwnd: WinExist("ahk_pid " . TerminalPid), IsNew: true}
}

; 通过 PowerShell 启动 cli_queue_worker.ps1（与 Python 版 bridge 等价），不依赖系统已安装 python
InvokePythonCLIBridge(Engines, PromptText := "", Action := "send") {
    global A_ScriptDir
    if (!IsObject(Engines) || Engines.Length = 0) {
        return 0
    }
    if (Action = "send" && PromptText = "") {
        return 0
    }
    WorkerScript := A_ScriptDir . "\scripts\cli_queue_worker.ps1"
    if (!FileExist(WorkerScript)) {
        TrayTip("找不到 CLI 队列脚本: " . WorkerScript, "错误", "Iconx 2")
        return 0
    }
    PowerShellPath := A_WinDir . "\System32\WindowsPowerShell\v1.0\powershell.exe"
    if (!FileExist(PowerShellPath)) {
        TrayTip("找不到 Windows PowerShell", "错误", "Iconx 2")
        return 0
    }
    OkCount := 0
    for _, Engine in Engines {
        AgentInfo := GetCLIAgentLaunchInfo(Engine)
        if (!AgentInfo || !IsObject(AgentInfo) || AgentInfo.Command = "") {
            TrayTip("未找到 " . Engine . " 的可执行文件，请先安装 CLI 或配置 PATH", "错误", "Iconx 2")
            continue
        }
        Title := GetCLIAgentWindowTitle(Engine)
        if (Title = "") {
            continue
        }
        QueueDir := A_ScriptDir . "\cache\cli_queue\" . Engine
        try DirCreate(QueueDir)
        Hwnd := FindCLIAgentWindow(Engine)
        if (!Hwnd) {
            CmdLine := '"' . PowerShellPath . '" -NoExit -ExecutionPolicy Bypass -File "' . WorkerScript . '"'
            CmdLine .= ' -Engine "' . Engine . '" -Title "' . Title . '" -Workdir "' . A_ScriptDir . '" -QueueDir "' . QueueDir . '" -Executable "' . AgentInfo.Command . '"'
            try {
                Run(CmdLine, A_ScriptDir)
            } catch as err {
                TrayTip("启动 " . AgentInfo.Name . " 失败: " . err.Message, "错误", "Iconx 2")
                continue
            }
            Deadline := A_TickCount + 12000
            while (A_TickCount < Deadline) {
                Hwnd := FindCLIAgentWindow(Engine)
                if (Hwnd) {
                    break
                }
                Sleep(250)
            }
        }
        if (!Hwnd) {
            TrayTip("超时：未检测到 " . AgentInfo.Name . " 终端窗口", "错误", "Iconx 2")
            continue
        }
        if (Action = "send") {
            PromptFile := QueueDir . "\" . A_TickCount . "_" . Random(1, 999999) . ".txt"
            try FileAppend(PromptText, PromptFile, "UTF-8")
        }
        try {
            WinActivate("ahk_id " . Hwnd)
            WinWaitActive("ahk_id " . Hwnd, , 2)
        } catch {
        }
        OkCount += 1
        Sleep(150)
    }
    return OkCount
}

; 直接 PowerShell 里 & qwen.cmd / codex.cmd / gemini（无参即交互式），用户可在终端内连续输入；队列 worker 仅用于 openclaw 等非原生 CLI
ShouldUseNativeCLITerminal(Engine) {
    return (Engine = "codex_cli" || Engine = "qwen_cli" || Engine = "gemini_cli")
}

LaunchSelectedCLIAgents(PromptText := "") {
    global SearchCenterSelectedEngines
    
    if (!IsSet(SearchCenterSelectedEngines) || !IsObject(SearchCenterSelectedEngines) || SearchCenterSelectedEngines.Length = 0) {
        TrayTip("请至少选择一个 CLI", "提示", "Icon! 2")
        return
    }
    
    NativeEngines := []
    BridgeEngines := []
    for _, Engine in SearchCenterSelectedEngines {
        if (ShouldUseNativeCLITerminal(Engine)) {
            NativeEngines.Push(Engine)
        } else {
            BridgeEngines.Push(Engine)
        }
    }
    
    ProcessedCount := 0
    for Index, Engine in NativeEngines {
        AgentInfo := GetCLIAgentLaunchInfo(Engine)
        if (!AgentInfo || !IsObject(AgentInfo)) {
            continue
        }
        try {
            LaunchResult := OpenCLIAgentTerminal(Engine)
            ProcessedCount += 1
            if (PromptText != "") {
                DispatchPromptToCLIAgent(Engine, LaunchResult, PromptText)
            }
            if (Index < NativeEngines.Length) {
                Sleep(400)
            }
        } catch as err {
            TrayTip("启动 " . AgentInfo.Name . " 失败: " . err.Message, "错误", "Iconx 2")
        }
    }
    
    if (BridgeEngines.Length > 0) {
        Action := (PromptText = "") ? "open" : "send"
        BridgeOk := InvokePythonCLIBridge(BridgeEngines, PromptText, Action)
        if (BridgeOk > 0) {
            ProcessedCount += BridgeOk
        }
    }
    
    if (ProcessedCount > 0) {
        if (PromptText = "") {
            TrayTip("正在打开 " . ProcessedCount . " 个 AI 终端", "提示", "Iconi 1")
        } else {
            TrayTip("正在发送到 " . ProcessedCount . " 个 AI 终端", "提示", "Iconi 1")
        }
    }
}

OpenSelectedCLIAgents(*) {
    LaunchSelectedCLIAgents("")
}

; 发送语音搜索内容到浏览器
SendVoiceSearchToBrowser(Content, Engine) {
    try {
        AgentInfo := GetCLIAgentLaunchInfo(Engine)
        if (AgentInfo && IsObject(AgentInfo)) {
            if (ShouldUseNativeCLITerminal(Engine)) {
                LaunchResult := OpenCLIAgentTerminal(Engine)
                DispatchPromptToCLIAgent(Engine, LaunchResult, Content)
            } else {
                InvokePythonCLIBridge([Engine], Content, "send")
            }
            return
        }

        ; URL编码搜索内容
        EncodedContent := UriEncode(Content)
        
        ; 根据搜索引擎构建URL
        SearchURL := ""
        switch Engine {
            case "deepseek":
                SearchURL := "https://chat.deepseek.com/?q=" . EncodedContent
            case "yuanbao":
                SearchURL := "https://yuanbao.tencent.com/?q=" . EncodedContent
            case "doubao":
                SearchURL := "https://www.doubao.com/chat/?q=" . EncodedContent
            case "zhipu":
                SearchURL := "https://chatglm.cn/main/search?query=" . EncodedContent
            case "mita":
                SearchURL := "https://metaso.cn/?q=" . EncodedContent
            case "wenxin":
                SearchURL := "https://yiyan.baidu.com/search?query=" . EncodedContent
            case "qianwen":
                SearchURL := "https://tongyi.aliyun.com/qianwen/chat?intent=chat&query=" . EncodedContent
            case "kimi":
                SearchURL := "https://kimi.moonshot.cn/_prefill_chat?force_search=true&send_immediately=true&prefill_prompt=" . EncodedContent
            case "perplexity":
                SearchURL := "https://www.perplexity.ai/search?intent=qa&q=" . EncodedContent
            case "copilot":
                SearchURL := "https://copilot.microsoft.com/chat?q=" . EncodedContent
            case "chatgpt":
                SearchURL := "https://chat.openai.com/?q=" . EncodedContent
            case "grok":
                SearchURL := "https://grok.com/?q=" . EncodedContent
            case "you":
                SearchURL := "https://you.com/search?q=" . EncodedContent
            case "claude":
                SearchURL := "https://claude.ai/new?q=" . EncodedContent
            case "monica":
                SearchURL := "https://monica.so/answers/?q=" . EncodedContent
            case "webpilot":
                SearchURL := "https://webpilot.ai/search?q=" . EncodedContent
            case "zhihu":
                SearchURL := "https://www.zhihu.com/search?q=" . EncodedContent
            case "baidu":
                SearchURL := "https://www.baidu.com/s?wd=" . EncodedContent
            default:
                SearchURL := "https://chat.deepseek.com/?q=" . EncodedContent
        }
        
        ; 打开浏览器
        Run(SearchURL)
        TrayTip(GetText("voice_search_sent"), GetText("tip"), "Iconi 1")
    } catch as e {
        TrayTip(GetText("voice_search_failed") . ": " . e.Message, GetText("error"), "Iconx 2")
    }
}
SwitchToChineseIME(*) {
    try {
        global GuiID_VoiceInput, VoiceSearchInputEdit
        if (GuiID_VoiceInput && VoiceSearchInputEdit) {
            WinActivate("ahk_id " . GuiID_VoiceInput.Hwnd)
            Sleep(50)
            VoiceSearchInputEdit.Focus()
            Sleep(50)
            ActiveHwnd := GuiID_VoiceInput.Hwnd
        } else {
            ActiveHwnd := WinGetID("A")
        }
        
        if (!ActiveHwnd) {
            return
        }
        
        ; 使用 Windows IME API 切换到中文输入法
        hIMC := DllCall("imm32\ImmGetContext", "Ptr", ActiveHwnd, "Ptr")
        if (hIMC) {
            DllCall("imm32\ImmGetConversionStatus", "Ptr", hIMC, "UInt*", &ConversionMode := 0, "UInt*", &SentenceMode := 0)
            ConversionMode := ConversionMode | 0x0001  ; IME_CMODE_NATIVE
            DllCall("imm32\ImmSetConversionStatus", "Ptr", hIMC, "UInt", ConversionMode, "UInt", SentenceMode)
            DllCall("imm32\ImmReleaseContext", "Ptr", ActiveHwnd, "Ptr", hIMC)
        }
        
        ; 尝试切换到中文键盘布局
        try {
            hKL := DllCall("user32\LoadKeyboardLayout", "Str", "00000804", "UInt", 0x00000001, "Ptr")
            if (hKL) {
                PostMessage(0x0050, 0x0001, hKL, , , "ahk_id " . ActiveHwnd)
            }
        } catch as err {
        }
    } catch as err {
    }
}
; 检测百度输入法语音识别窗口是否激活
IsBaiduVoiceWindowActive() {
    ; 检测百度输入法的语音识别窗口
    AllWindows := WinGetList()
    for Index, Hwnd in AllWindows {
        try {
            WinTitle := WinGetTitle("ahk_id " . Hwnd)
            ; 检查窗口标题是否包含语音识别相关关键词
            if (InStr(WinTitle, "正在识别") || InStr(WinTitle, "说完了") || InStr(WinTitle, "语音输入")) {
                ; 进一步检查窗口是否可见且处于活动状态
                if (WinExist("ahk_id " . Hwnd)) {
                    IsVisible := WinGetMinMax("ahk_id " . Hwnd)
                    if (IsVisible != -1) {  ; -1 表示最小化
                        return true
                    }
                }
            }
        } catch as err {
            ; 忽略错误，继续检测下一个窗口
        }
    }
    
    ; 通过窗口类名检测百度输入法相关窗口
    BaiduClasses := ["BaiduIME", "BaiduPinyin", "BaiduInput", "#32770"]
    for Index, ClassName in BaiduClasses {
        if (WinExist("ahk_class " . ClassName)) {
            try {
                WinTitle := WinGetTitle("ahk_class " . ClassName)
                if (InStr(WinTitle, "正在识别") || InStr(WinTitle, "说完了") || InStr(WinTitle, "语音输入")) {
                    return true
                }
            } catch as err {
            }
        }
    }
    
    return false
}
; URL编码函数（使用 UTF-8 编码，正确处理中文）
UriEncode(Uri) {
    try {
        ; 方法1：使用 JavaScript encodeURIComponent（如果可用）
        try {
            js := ComObject("MSScriptControl.ScriptControl")
            js.Language := "JScript"
            ; 转义单引号，防止 JavaScript 错误
            EscapedUri := StrReplace(Uri, "\", "\\")
            EscapedUri := StrReplace(EscapedUri, "'", "\'")
            EscapedUri := StrReplace(EscapedUri, "`n", "\n")
            EscapedUri := StrReplace(EscapedUri, "`r", "\r")
            Encoded := js.Eval("encodeURIComponent('" . EscapedUri . "')")
            return Encoded
        } catch as err {
            ; 方法2：手动 UTF-8 编码（更可靠的备用方案）
            Encoded := ""
            ; 将字符串转换为 UTF-8 字节数组
            UTF8Size := StrPut(Uri, "UTF-8")
            UTF8Bytes := Buffer(UTF8Size)
            StrPut(Uri, UTF8Bytes, "UTF-8")
            
            ; 遍历每个字节进行编码
            Loop UTF8Size - 1 {  ; -1 因为 StrPut 返回的大小包括 null 终止符
                Byte := NumGet(UTF8Bytes, A_Index - 1, "UChar")
                ; 保留字符：字母、数字、-、_、.、~（根据 RFC 3986）
                if ((Byte >= 48 && Byte <= 57) || (Byte >= 65 && Byte <= 90) || (Byte >= 97 && Byte <= 122) || Byte = 45 || Byte = 95 || Byte = 46 || Byte = 126) {
                    Encoded .= Chr(Byte)
                } else if (Byte = 32) {
                    ; 空格编码为 +
                    Encoded .= "+"
                } else {
                    ; URL编码：%XX（大写）
                    Encoded .= "%" . Format("{:02X}", Byte)
                }
            }
            return Encoded
        }
    } catch as err {
        ; 如果编码失败，返回原始字符串
        return Uri
    }
}
