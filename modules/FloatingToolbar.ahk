; ======================================================================================================================
; 悬浮工具栏 - 类似输入法的悬浮窗
; 版本: 1.0.0
; 功能: 
;   - 类似输入法的悬浮长条窗口
;   - 左键拖动
;   - 右键弹出菜单关闭
;   - 5个功能按钮：搜索、记录、AI助手、截图、设置
;   - Cursor色系配色
; ======================================================================================================================

#Requires AutoHotkey v2.0

; 注意：此模块需要主脚本已包含 ClipboardHistoryPanel.ahk 模块
; 如果函数不存在，将使用快捷键作为后备

; ===================== 全局变量 =====================
global FloatingToolbarGUI := 0  ; 悬浮窗GUI对象
global FloatingToolbarIsVisible := false  ; 是否可见
global FloatingToolbarDragging := false  ; 是否正在拖动
global FloatingToolbarDragStartX := 0  ; 拖动起始X坐标
global FloatingToolbarDragStartY := 0  ; 拖动起始Y坐标
global FloatingToolbarWindowX := 0  ; 窗口X坐标
global FloatingToolbarWindowY := 0  ; 窗口Y坐标
global FloatingToolbarButtons := Map()  ; 存储按钮信息（用于悬停检测）
global FloatingToolbarHoveredButton := 0  ; 当前悬停的按钮
global FloatingToolbarClickedButton := 0  ; 当前点击的按钮
global FloatingToolbarButtonDownTime := 0  ; 按钮按下时间（用于区分点击和拖动）
global FloatingToolbarTooltipText := ""  ; Tooltip文本
global FloatingToolbarTooltipTimer := 0  ; Tooltip定时器

; Cursor色系配色
FloatingToolbarColors := {
    Background: "1e1e1e",
    Border: "3c3c3c",
    Text: "cccccc",
    TextHover: "ffffff",
    ButtonBg: "252526",
    ButtonHover: "37373d",
    ButtonActive: "007acc",
    ButtonBorder: "3c3c3c"
}

; ===================== 显示/隐藏悬浮窗 =====================
ShowFloatingToolbar() {
    global FloatingToolbarGUI, FloatingToolbarIsVisible, FloatingToolbarWindowX, FloatingToolbarWindowY
    
    if (FloatingToolbarIsVisible && FloatingToolbarGUI != 0) {
        return
    }
    
    ; 创建GUI
    CreateFloatingToolbarGUI()
    
    ; [需求1] 从配置文件加载保存的位置
    LoadFloatingToolbarPosition()
    
    ; 显示GUI（默认位置：屏幕右下角）
    if (FloatingToolbarWindowX = 0 && FloatingToolbarWindowY = 0) {
        ; 获取屏幕尺寸
        ScreenWidth := SysGet(0)  ; SM_CXSCREEN
        ScreenHeight := SysGet(1)  ; SM_CYSCREEN
        
        ; 默认位置：屏幕右下角，留出边距
        FloatingToolbarWindowX := ScreenWidth - 180
        FloatingToolbarWindowY := ScreenHeight - 40
    }
    
    ; [需求3] 增加窗口宽度，防止设置按钮被截断
    FloatingToolbarGUI.Show("x" . FloatingToolbarWindowX . " y" . FloatingToolbarWindowY . " w180 h25")
    FloatingToolbarIsVisible := true
    
    ; 启动定时器用于悬停效果检测和位置检查（优化频率为100ms）
    SetTimer(FloatingToolbarCheckButtonHover, 100)
    SetTimer(FloatingToolbarCheckWindowPosition, 100)
    SetTimer(FloatingToolbarCheckButtonDrag, 50)
}

HideFloatingToolbar() {
    global FloatingToolbarGUI, FloatingToolbarIsVisible, FloatingToolbarWindowX, FloatingToolbarWindowY
    
    if (FloatingToolbarGUI != 0) {
        ; [需求1] 保存当前位置到配置文件
        SaveFloatingToolbarPosition()
        
        FloatingToolbarGUI.Hide()
        FloatingToolbarIsVisible := false
        
        ; 停止定时器
        SetTimer(FloatingToolbarCheckButtonHover, 0)
        SetTimer(FloatingToolbarCheckWindowPosition, 0)
        SetTimer(FloatingToolbarCheckButtonDrag, 0)
    }
}

ToggleFloatingToolbar() {
    global FloatingToolbarIsVisible
    
    if (FloatingToolbarIsVisible) {
        HideFloatingToolbar()
    } else {
        ShowFloatingToolbar()
    }
}

; ===================== 创建GUI =====================
CreateFloatingToolbarGUI() {
    global FloatingToolbarGUI, FloatingToolbarColors
    
    ; 如果已存在，先销毁
    if (FloatingToolbarGUI != 0) {
        try {
            FloatingToolbarGUI.Destroy()
        } catch {
        }
    }
    
    ; 创建GUI（无边框、置顶、可拖动）
    FloatingToolbarGUI := Gui("+AlwaysOnTop -Caption +ToolWindow", "悬浮工具栏")
    FloatingToolbarGUI.BackColor := FloatingToolbarColors.Background
    FloatingToolbarGUI.SetFont("s10 c" . FloatingToolbarColors.Text, "Segoe UI")
    
    ; 窗口事件
    FloatingToolbarGUI.OnEvent("Close", OnFloatingToolbarClose)
    
    ; 创建按钮容器（背景，缩小一倍）
    ; 注意：不添加背景控件，让整个窗口都可以拖动
    ; ToolbarBg := FloatingToolbarGUI.Add("Text", 
    ;     "x0 y0 w160 h25 Background" . FloatingToolbarColors.Background, "")
    
    ; 添加favicon图标（左侧，缩小一倍）
    ; 尝试多个可能的路径
    IconPaths := [
        A_ScriptDir . "\favicon.ico",
        A_WorkingDir . "\favicon.ico",
        A_ScriptDir . "\..\favicon.ico"
    ]
    IconPath := ""
    for path in IconPaths {
        if (FileExist(path)) {
            IconPath := path
            break
        }
    }
    if (IconPath != "") {
        IconPic := FloatingToolbarGUI.Add("Picture", "x3 y3 w20 h20", IconPath)
    }
    
    ; 按钮配置：搜索、记录、AI助手、截图、设置（使用Material风格图标）
    ; Material Design Icons Unicode (Segoe MDL2 Assets字体)
    ButtonConfigs := [
        Map("text", "搜索", "icon", Chr(0xE721), "action", "Search", "shortcut", "Caps+F"),
        Map("text", "记录", "icon", Chr(0xE82F), "action", "Record", "shortcut", "Caps+X"),  ; [需求4] 笔图标
        Map("text", "AI助手", "icon", Chr(0xE8BD), "action", "AIAssistant", "shortcut", "Ctrl+Shift+B"),  ; [需求5] 对话框图标
        Map("text", "截图", "icon", Chr(0xE114), "action", "Screenshot", "shortcut", "Caps+T"),
        Map("text", "设置", "icon", Chr(0xE713), "action", "Settings", "shortcut", "Caps+Q")
    ]
    
    ; 按钮尺寸和间距（缩小一倍）
    ButtonWidth := 25
    ButtonHeight := 20
    ButtonSpacing := 3
    StartX := 30  ; 从图标右侧开始
    StartY := 3
    
    ; 清空按钮信息
    FloatingToolbarButtons := Map()
    
    ; 创建按钮
    Loop ButtonConfigs.Length {
        index := A_Index
        config := ButtonConfigs[index]
        
        x := StartX + (index - 1) * (ButtonWidth + ButtonSpacing)
        
        ; 创建按钮（只显示图标，不显示文字）
        button := FloatingToolbarGUI.Add("Button", 
            "x" . x . " y" . StartY . 
            " w" . ButtonWidth . " h" . ButtonHeight . 
            " Background" . FloatingToolbarColors.ButtonBg . 
            " c" . FloatingToolbarColors.Text . 
            " -Theme vToolbarBtn_" . config["action"], 
            config["icon"])
        
        ; 使用Segoe MDL2 Assets字体显示Material风格图标
        button.SetFont("s12", "Segoe MDL2 Assets")
        
        ; [核心修复] 使用原生 ToolTip 属性，这是最可靠的方式
        ; 格式：功能名称 (快捷键)
        button.ToolTip := config["text"] . " (" . config["shortcut"] . ")"
        
        ; 设置按钮样式（扁平、无边框）
        buttonHwnd := button.Hwnd
        try {
            ; 设置按钮为扁平样式
            DllCall("uxtheme\SetWindowTheme", "Ptr", buttonHwnd, "Ptr", 0, "Ptr", 0)
            ; 设置按钮为扁平样式（BS_FLAT）
            CurrentStyle := DllCall("GetWindowLongPtr", "Ptr", buttonHwnd, "Int", -16, "Ptr")
            NewStyle := CurrentStyle | 0x8000  ; BS_FLAT
            DllCall("SetWindowLongPtr", "Ptr", buttonHwnd, "Int", -16, "Ptr", NewStyle, "Ptr")
        }
        
        ; 绑定鼠标点击事件
        button.OnEvent("Click", OnToolbarButtonClick.Bind(button, config["action"], buttonHwnd, config["text"]))
        
        ; 存储按钮信息（用于悬停检测和tooltip）
        FloatingToolbarButtons[buttonHwnd] := {
            button: button,
            x: x,
            y: StartY,
            w: ButtonWidth,
            h: ButtonHeight,
            action: config["action"],
            tooltip: config["text"],
            shortcut: config["shortcut"]
        }
    }
    
    ; 为所有按钮添加拖动支持（通过定时器检测长按）
    SetTimer(FloatingToolbarCheckButtonDrag, 50)
    
    ; 使用窗口事件处理拖动（更可靠）
    FloatingToolbarGUI.OnEvent("ContextMenu", OnFloatingToolbarContextMenu)
    
    ; 监听 WM_LBUTTONDOWN 消息，实现整个窗口拖动
    ; 注意：必须在GUI创建后注册消息监听
    OnMessage(0x0201, FloatingToolbarWM_LBUTTONDOWN)  ; WM_LBUTTONDOWN
}

; ===================== WM_LBUTTONDOWN 消息处理（简化版） =====================
FloatingToolbarWM_LBUTTONDOWN(wParam, lParam, msg, hwnd) {
    global FloatingToolbarGUI, FloatingToolbarHoveredButton, FloatingToolbarButtons, FloatingToolbarClickedButton, FloatingToolbarButtonDownTime, FloatingToolbarDragging, FloatingToolbarColors
    
    ; 检查是否是工具栏窗口
    if (!FloatingToolbarGUI || hwnd != FloatingToolbarGUI.Hwnd) {
        return
    }
    
    ; 如果点击的是悬浮窗，且当前鼠标没有悬停在任何按钮上（即点击的是空白处）
    if (FloatingToolbarHoveredButton = 0 && !FloatingToolbarDragging) {
        ; 发送 0xA1 (WM_NCLBUTTONDOWN) 消息，参数 2 代表标题栏
        ; 这样系统会自动接管拖动，操作起来非常顺滑
        PostMessage(0x00A1, 2, 0, FloatingToolbarGUI.Hwnd)
        return
    }
    
    ; 如果点击在按钮上，添加按下效果
    if (FloatingToolbarHoveredButton != 0 && !FloatingToolbarDragging) {
        ; 记录按下的按钮和时间
        FloatingToolbarClickedButton := FloatingToolbarHoveredButton
        FloatingToolbarButtonDownTime := A_TickCount
        
        ; 添加按下效果（深色）
        try {
            button := FloatingToolbarButtons[FloatingToolbarHoveredButton].button
            button.Opt("Background" . FloatingToolbarColors.ButtonActive)
            button.Opt("c" . FloatingToolbarColors.TextHover)
        } catch {
        }
        ; 让消息继续传递，按钮的Click事件会处理点击
    }
}


; ===================== 按钮点击处理 =====================
OnToolbarButtonClick(button, action, buttonHwnd, tooltipText, *) {
    global FloatingToolbarDragging, FloatingToolbarColors
    
    ; 如果正在拖动，不处理点击
    if (FloatingToolbarDragging) {
        return
    }
    
    ; 恢复按钮颜色
    try {
        button.Opt("Background" . FloatingToolbarColors.ButtonBg)
        button.Opt("c" . FloatingToolbarColors.Text)
    } catch {
    }
    
    ; 直接执行动作，不检查 FloatingToolbarClickedButton（简化逻辑）
    FloatingToolbarExecuteButtonAction(action, buttonHwnd)
}

; 执行按钮动作
FloatingToolbarExecuteButtonAction(action, buttonHwnd) {
    global FloatingToolbarDragging
    
    ; 如果正在拖动，不执行动作
    if (FloatingToolbarDragging) {
        return
    }
    
    ; 执行对应的动作（直接调用窗口显示函数）
    switch action {
        case "Search":
            ; 直接显示搜索中心窗口
            try {
                ShowSearchCenter()
            } catch as err {
                ; 如果函数不存在或调用失败，发送快捷键作为后备
                SetCapsLockState("AlwaysOff")
                Send("{CapsLock down}")
                Sleep(30)
                Send("f")
                Sleep(30)
                Send("{CapsLock up}")
                SetCapsLockState("Off")
            }
        case "Record":
            ; 显示剪贴板管理器窗口（clipboard.AHK）
            ; 直接调用 ShowClipboardHistoryPanel 函数
            try {
                ShowClipboardHistoryPanel()
            } catch as err {
                ; 如果函数不存在或调用失败，使用快捷键作为后备
                SetCapsLockState("AlwaysOff")
                Sleep(30)
                Send("{CapsLock down}")
                Sleep(30)
                Send("x")
                Sleep(30)
                Send("{CapsLock up}")
                Sleep(30)
                SetCapsLockState("Off")
            }
        case "AIAssistant":
            ; 显示AI选择列表面板
            try {
                ShowAIListPanel()
            } catch as err {
                ; 如果AIListPanel模块未加载，使用默认行为
                TrayTip("AI选择面板加载失败: " . err.Message, "错误", "Iconx 2")
            }
        case "Screenshot":
            ; [需求2] 执行截图并弹出截图助手让用户选择
            try {
                ExecuteScreenshotWithMenu()
            } catch as err {
                ; 如果函数不存在或调用失败，发送快捷键作为后备
                SetCapsLockState("AlwaysOff")
                Send("{CapsLock down}")
                Sleep(30)
                Send("t")
                Sleep(30)
                Send("{CapsLock up}")
                SetCapsLockState("Off")
            }
        case "Settings":
            ; 显示配置面板（CapsLock+Q 对应的窗口）
            try {
                ShowConfigGUI()
            } catch as err {
                ; 如果函数不存在或调用失败，发送快捷键作为后备
                SetCapsLockState("AlwaysOff")
                Send("{CapsLock down}")
                Sleep(30)
                Send("q")
                Sleep(30)
                Send("{CapsLock up}")
                SetCapsLockState("Off")
            }
    }
}

; 检测按钮拖动（长按按钮时拖动）
FloatingToolbarCheckButtonDrag() {
    global FloatingToolbarGUI, FloatingToolbarButtons, FloatingToolbarDragging, FloatingToolbarButtonDownTime, FloatingToolbarClickedButton, FloatingToolbarIsVisible, FloatingToolbarColors, FloatingToolbarWindowX, FloatingToolbarWindowY
    
    static lastX := 0, lastY := 0
    
    ; 如果窗口不可见，不处理
    if (!FloatingToolbarIsVisible || FloatingToolbarGUI = 0) {
        return
    }
    
    ; 如果鼠标左键按下且按下了按钮
    if (GetKeyState("LButton", "P") && FloatingToolbarClickedButton != 0) {
        ; 检查是否长按（超过150ms，降低阈值使拖动更容易触发）
        if (A_TickCount - FloatingToolbarButtonDownTime > 150) {
            ; 检查鼠标是否移动（拖动）
            MouseGetPos(&mx, &my)
            if (lastX != 0 && lastY != 0) {
                ; 降低移动阈值，使拖动更容易触发
                if (Abs(mx - lastX) > 3 || Abs(my - lastY) > 3) {
                    ; 开始拖动
                    ; 先恢复按钮颜色
                    clickedBtn := FloatingToolbarClickedButton
                    if (FloatingToolbarButtons.Has(clickedBtn)) {
                        try {
                            button := FloatingToolbarButtons[clickedBtn].button
                            button.Opt("Background" . FloatingToolbarColors.ButtonBg)
                        } catch {
                        }
                    }
                    
                    FloatingToolbarDragging := true
                    FloatingToolbarClickedButton := 0
                    
                    ; 使用标准的Windows拖动方法
                    FloatingToolbarGUI.GetPos(&winX, &winY)
                    FloatingToolbarWindowX := winX
                    FloatingToolbarWindowY := winY
                    PostMessage(0x00A1, 2, 0, FloatingToolbarGUI.Hwnd)  ; WM_NCLBUTTONDOWN, HTCAPTION
                    
                    ; 启动定时器来检测拖动结束
                    SetTimer(FloatingToolbarCheckDragEnd, 50)
                }
            }
            lastX := mx
            lastY := my
        } else {
            ; 记录初始位置
            MouseGetPos(&mx, &my)
            lastX := mx
            lastY := my
        }
    } else {
        ; 鼠标释放，检查是否是点击（不是拖动）
        if (FloatingToolbarClickedButton != 0 && !FloatingToolbarDragging) {
            ; 获取按钮信息并执行动作
            if (FloatingToolbarButtons.Has(FloatingToolbarClickedButton)) {
                buttonInfo := FloatingToolbarButtons[FloatingToolbarClickedButton]
                action := buttonInfo.action
                
                ; 恢复按钮颜色
                try {
                    buttonInfo.button.Opt("Background" . FloatingToolbarColors.ButtonBg)
                } catch {
                }
                
                ; 执行动作
                FloatingToolbarExecuteButtonAction(action, FloatingToolbarClickedButton)
            }
            FloatingToolbarClickedButton := 0
        }
        
        ; 重置拖动检测
        lastX := 0
        lastY := 0
    }
}

; ===================== 按钮悬停效果（ID检测版 + 双重保险） =====================
FloatingToolbarCheckButtonHover() {
    global FloatingToolbarGUI, FloatingToolbarButtons, FloatingToolbarHoveredButton, FloatingToolbarColors, FloatingToolbarDragging, FloatingToolbarIsVisible
    
    static LastHovered := 0  ; 记录上一次悬停的按钮
    
    ; 1. 基础检查：窗口不存在或不可见则退出
    if (!FloatingToolbarIsVisible || FloatingToolbarGUI = 0) {
        return
    }
    
    ; 2. 防干扰：正在拖动时，强制清除提示并退出
    if (FloatingToolbarDragging) {
        ToolTip()
        return
    }
    
    try {
        ; [方法1] 使用控件句柄检测（最准确）
        MouseGetPos(&mx, &my, &winHwnd, &ctrlHwnd, 2)
        
        ; 3. 检查：鼠标是否还在悬浮窗内？
        if (winHwnd != FloatingToolbarGUI.Hwnd) {
            ; 鼠标跑出去了
            if (LastHovered != 0) {
                FloatingToolbarRestoreButtonColor(LastHovered)
                ToolTip() ; 清除提示
                LastHovered := 0
                FloatingToolbarHoveredButton := 0
            }
            return
        }
        
        ; 4. 检查：鼠标下的控件，是不是我们的按钮之一？
        currentHover := 0
        currentHoverInfo := 0
        
        ; 首先尝试通过控件句柄检测
        if (ctrlHwnd && FloatingToolbarButtons.Has(ctrlHwnd)) {
            currentHover := ctrlHwnd
            currentHoverInfo := FloatingToolbarButtons[ctrlHwnd]
        } 
        ; [双重保险] 如果控件句柄检测失败，使用坐标检测作为备选
        else {
            FloatingToolbarGUI.GetPos(&wx, &wy)
            relX := mx - wx
            relY := my - wy
            
            for buttonHwnd, btn in FloatingToolbarButtons {
                if (relX >= btn.x && relX <= btn.x + btn.w && relY >= btn.y && relY <= btn.y + btn.h) {
                    currentHover := buttonHwnd
                    currentHoverInfo := btn
                    break
                }
            }
        }
        
        ; 5. 状态机：只有当状态发生改变时（从A移到B，或从无移到有）才执行操作
        if (currentHover != LastHovered) {
            
            ; A. 把旧的（上一个）按钮颜色恢复原样
            if (LastHovered != 0) {
                FloatingToolbarRestoreButtonColor(LastHovered)
            }
            
            ; B. 处理新状态
            if (currentHover != 0) {
                ; === 鼠标移入了按钮 ===
                
                ; 1. 按钮变亮（视觉反馈）
                try {
                    currentHoverInfo.button.Opt("Background" . FloatingToolbarColors.ButtonHover)
                    currentHoverInfo.button.Opt("c" . FloatingToolbarColors.TextHover)
                }
                
                ; 2. 弹出提示词（小白帮助）
                action := currentHoverInfo.action
                tipText := GetButtonTip(action)
                ToolTip(tipText) ; 默认在鼠标旁边显示，最符合直觉
                
            } else {
                ; === 鼠标在悬浮窗上，但不在按钮上（比如空隙） ===
                ToolTip() ; 清除提示
            }
            
            ; 更新状态
            LastHovered := currentHover
            FloatingToolbarHoveredButton := currentHover
        }
        
    } catch as err {
        ; 容错处理，显示错误信息便于调试
        ; ToolTip("Error: " . err.Message)
    }
}

; [新增辅助函数] 专门用来恢复按钮颜色，让主逻辑更清晰
FloatingToolbarRestoreButtonColor(btnHwnd) {
    global FloatingToolbarButtons, FloatingToolbarColors
    if (FloatingToolbarButtons.Has(btnHwnd)) {
        try {
            prevButton := FloatingToolbarButtons[btnHwnd].button
            prevButton.Opt("Background" . FloatingToolbarColors.ButtonBg)
            prevButton.Opt("c" . FloatingToolbarColors.Text)
        }
    }
}


; ===================== 背景区域拖动处理 =====================
OnToolbarBgClick(*) {
    global FloatingToolbarGUI, FloatingToolbarDragging, FloatingToolbarDragStartX, FloatingToolbarDragStartY, FloatingToolbarWindowX, FloatingToolbarWindowY
    
    ; 检查是否在按钮区域（按钮区域不拖动）
    MouseGetPos(&mx, &my)
    FloatingToolbarGUI.GetPos(&winX, &winY)
    
    ; 计算相对于窗口的坐标
    wx := mx - winX
    wy := my - winY
    
    ; 检查是否在按钮区域内（按钮区域：x30-155, y3-23，缩小一倍）
    if (wx >= 30 && wx <= 155 && wy >= 3 && wy <= 23) {
        ; 在按钮区域内，不拖动（按钮有自己的拖动处理）
        return
    }
    
    ; 检查是否在图标区域内（图标区域：x3-23, y3-23，缩小一倍）
    if (wx >= 3 && wx <= 23 && wy >= 3 && wy <= 23) {
        ; 在图标区域内，不拖动
        return
    }
    
    ; 开始拖动
    FloatingToolbarDragging := true
    FloatingToolbarDragStartX := mx
    FloatingToolbarDragStartY := my
    FloatingToolbarWindowX := winX
    FloatingToolbarWindowY := winY
    
    ; 使用标准的Windows拖动方法
    PostMessage(0x00A1, 2, 0, FloatingToolbarGUI.Hwnd)  ; WM_NCLBUTTONDOWN, HTCAPTION
    
    ; 启动定时器来检测拖动结束
    SetTimer(FloatingToolbarCheckDragEnd, 50)
}

; 检测拖动结束
FloatingToolbarCheckDragEnd() {
    global FloatingToolbarDragging, FloatingToolbarWindowX, FloatingToolbarWindowY
    
    ; 如果鼠标左键释放，停止拖动并触发磁吸检查
    if (!GetKeyState("LButton", "P")) {
        FloatingToolbarDragging := false
        SetTimer(FloatingToolbarCheckDragEnd, 0)
        
        ; 立即触发位置检查和磁吸效果
        FloatingToolbarCheckWindowPosition()
    }
}

; 拖动结束后的边界检查和位置更新（使用定时器）
FloatingToolbarCheckWindowPosition() {
    global FloatingToolbarGUI, FloatingToolbarWindowX, FloatingToolbarWindowY, FloatingToolbarDragging, FloatingToolbarIsVisible
    
    ; 如果窗口不可见，不处理
    if (!FloatingToolbarIsVisible || FloatingToolbarGUI = 0) {
        return
    }
    
    ; 如果正在拖动，不处理
    if (FloatingToolbarDragging) {
        return
    }
    
    ; 如果鼠标左键释放，检查边界并调整位置
    if (!GetKeyState("LButton", "P")) {
        try {
            FloatingToolbarGUI.GetPos(&newX, &newY)
            FloatingToolbarWindowX := newX
            FloatingToolbarWindowY := newY
            
            ; 获取屏幕尺寸
            ScreenWidth := SysGet(0)
            ScreenHeight := SysGet(1)
            adjustedX := newX
            adjustedY := newY
            
            ; 磁吸距离阈值（30像素）
            snapDistance := 30
            windowWidth := 180  ; [需求3] 更新窗口宽度
            windowHeight := 25
            
            ; 磁吸到左边缘
            if (adjustedX < snapDistance) {
                adjustedX := 0
            }
            ; 磁吸到右边缘
            else if (adjustedX + windowWidth > ScreenWidth - snapDistance) {
                adjustedX := ScreenWidth - windowWidth
            }
            
            ; 磁吸到上边缘
            if (adjustedY < snapDistance) {
                adjustedY := 0
            }
            ; 磁吸到下边缘
            else if (adjustedY + windowHeight > ScreenHeight - snapDistance) {
                adjustedY := ScreenHeight - windowHeight
            }
            
            ; 边界检查（防止超出屏幕）
            if (adjustedX < 0) {
                adjustedX := 0
            }
            if (adjustedY < 0) {
                adjustedY := 0
            }
            if (adjustedX + windowWidth > ScreenWidth) {
                adjustedX := ScreenWidth - windowWidth
            }
            if (adjustedY + windowHeight > ScreenHeight) {
                adjustedY := ScreenHeight - windowHeight
            }
            
            ; 如果位置需要调整，更新窗口位置
            if (adjustedX != newX || adjustedY != newY) {
                FloatingToolbarGUI.Move(adjustedX, adjustedY)
                FloatingToolbarWindowX := adjustedX
                FloatingToolbarWindowY := adjustedY
            }
            
            ; [需求1] 位置变化时保存到配置文件
            SaveFloatingToolbarPosition()
        } catch {
        }
    }
}

; ===================== 右键菜单事件 =====================
OnFloatingToolbarContextMenu(*) {
    ShowFloatingToolbarContextMenu()
}

; ===================== 右键菜单 =====================
ShowFloatingToolbarContextMenu() {
    global FloatingToolbarGUI
    
    ; 创建上下文菜单
    contextMenu := Menu()
    contextMenu.Add("关闭", OnFloatingToolbarMenuClose)
    contextMenu.Add()  ; 分隔线
    contextMenu.Add("重启脚本", OnFloatingToolbarMenuRestart)
    
    ; [需求6] 调整菜单位置：显示在悬浮工具栏上方，避免遮挡
    FloatingToolbarGUI.GetPos(&wx, &wy, &ww, &wh)
    MouseGetPos(&mx, &my)
    
    ; 如果鼠标在工具栏下方，菜单显示在工具栏上方
    ; 否则显示在鼠标位置
    if (my > wy + wh) {
        menuX := wx + ww / 2
        menuY := wy - 5
    } else {
        menuX := mx
        menuY := my
    }
    
    ; 显示菜单
    contextMenu.Show(menuX, menuY)
}

OnFloatingToolbarMenuRestart(*) {
    ; 重启脚本
    Reload
}

OnFloatingToolbarMenuClose(*) {
    HideFloatingToolbar()
}

; ===================== 窗口关闭事件 =====================
OnFloatingToolbarClose(*) {
    HideFloatingToolbar()
}

; ===================== 位置保存和加载 =====================
; [需求1] 保存悬浮工具栏位置到配置文件
SaveFloatingToolbarPosition() {
    global FloatingToolbarGUI, FloatingToolbarWindowX, FloatingToolbarWindowY
    
    if (FloatingToolbarGUI = 0) {
        return
    }
    
    try {
        ; 获取当前窗口位置
        FloatingToolbarGUI.GetPos(&x, &y)
        FloatingToolbarWindowX := x
        FloatingToolbarWindowY := y
        
        ; 保存到配置文件（使用主脚本的配置文件路径）
        ConfigFile := A_ScriptDir . "\CursorShortcut.ini"
        IniWrite(String(x), ConfigFile, "WindowPositions", "FloatingToolbar_X")
        IniWrite(String(y), ConfigFile, "WindowPositions", "FloatingToolbar_Y")
    } catch {
        ; 保存失败时静默处理
    }
}

; [需求1] 从配置文件加载悬浮工具栏位置
LoadFloatingToolbarPosition() {
    global FloatingToolbarWindowX, FloatingToolbarWindowY
    
    try {
        ConfigFile := A_ScriptDir . "\CursorShortcut.ini"
        
        ; 读取保存的位置
        savedX := IniRead(ConfigFile, "WindowPositions", "FloatingToolbar_X", "")
        savedY := IniRead(ConfigFile, "WindowPositions", "FloatingToolbar_Y", "")
        
        ; 如果读取成功且值有效，使用保存的位置
        if (savedX != "" && savedY != "" && savedX != "ERROR" && savedY != "ERROR") {
            FloatingToolbarWindowX := Integer(savedX)
            FloatingToolbarWindowY := Integer(savedY)
            
            ; 验证位置是否在屏幕范围内
            ScreenWidth := SysGet(0)
            ScreenHeight := SysGet(1)
            
            if (FloatingToolbarWindowX < 0 || FloatingToolbarWindowX > ScreenWidth - 180) {
                FloatingToolbarWindowX := 0
            }
            if (FloatingToolbarWindowY < 0 || FloatingToolbarWindowY > ScreenHeight - 25) {
                FloatingToolbarWindowY := 0
            }
        }
    } catch {
        ; 加载失败时使用默认位置
        FloatingToolbarWindowX := 0
        FloatingToolbarWindowY := 0
    }
}

; ===================== 初始化 =====================
InitFloatingToolbar() {
    ; 初始化完成，可以调用 ShowFloatingToolbar() 显示悬浮窗
}

; ===================== 根据按钮action获取提示文字 =====================
GetButtonTip(action) {
    ; 根据按钮的action类型返回对应的提示文字
    switch action {
        case "Search":
            return "搜索记录 (Caps + F)"
        case "Record":
            return "剪贴板历史 (Caps + X)"
        case "AIAssistant":
            return "AI助手 (Ctrl+Shift+B)"
        case "Screenshot":
            return "屏幕截图 (Caps + T)"
        case "Settings":
            return "系统设置 (Caps + Q)"
        default:
            return ""
    }
}
