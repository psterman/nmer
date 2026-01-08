; ======================================================================================================================
; 悬浮工具栏 - 类似输入法的悬浮窗
; 版本: 1.1.0
; 功能: 
;   - 类似输入法的悬浮长条窗口
;   - 左键拖动
;   - 右键弹出菜单关闭
;   - 5个功能按钮：搜索、笔记、AI助手、截图、设置（使用图片图标）
;   - Cursor色系配色
; 
; 图标文件要求：
;   - 图标文件应放在 images 目录下
;   - 文件命名（按顺序）：toolbar_search.png, toolbar_note.png, toolbar_ai.png, toolbar_screenshot.png, toolbar_settings.png
;   - 推荐尺寸：16x16 或 20x20 像素，PNG格式，支持透明背景
;   - 如果图标文件不存在，将使用文字作为后备显示
; ======================================================================================================================

#Requires AutoHotkey v2.0

; 注意：此模块需要主脚本已包含 ClipboardHistoryPanel.ahk 模块
; 如果函数不存在，将使用快捷键作为后备

; 加载 Gdip 库用于图片颜色滤镜效果
#Include ..\lib\Gdip_All.ahk

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
global FloatingToolbarIsMinimized := false  ; 是否已最小化到边缘
global FloatingToolbarSelectedButton := 0  ; 当前选中的按钮（显示橙色点）
global FloatingToolbarScale := 1.0  ; 工具栏缩放比例（1.0 = 100%）
global FloatingToolbarMinScale := 0.7  ; 最小缩放比例（70%）
global FloatingToolbarMaxScale := 1.5  ; 最大缩放比例（150%）
global FloatingToolbarPressedButton := 0  ; 当前按下的按钮（用于下沉效果）
global FloatingToolbarGdipToken := 0  ; Gdip token
global FloatingToolbarGdipInitialized := false  ; Gdip是否已初始化

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

    ; 初始化Gdip（用于按钮特效）
    FloatingToolbarInitializeGdip()

    ; 加载缩放比例
    FloatingToolbarLoadScale()

    ; 创建GUI
    CreateFloatingToolbarGUI()

    ; [需求1] 从配置文件加载保存的位置
    LoadFloatingToolbarPosition()

    ; 显示GUI（默认位置：屏幕右下角）
    if (FloatingToolbarWindowX = 0 && FloatingToolbarWindowY = 0) {
        ; 获取屏幕尺寸
        ScreenWidth := SysGet(0)  ; SM_CXSCREEN
        ScreenHeight := SysGet(1)  ; SM_CYSCREEN

        ; 计算窗口宽度和高度（使用基础尺寸和缩放比例）
        ToolbarWidth := FloatingToolbarCalculateWidth()
        ToolbarHeight := FloatingToolbarCalculateHeight()
        FloatingToolbarWindowX := ScreenWidth - ToolbarWidth
        FloatingToolbarWindowY := ScreenHeight - ToolbarHeight
    }

    ; 计算窗口宽度和高度
    ToolbarWidth := FloatingToolbarCalculateWidth()
    ToolbarHeight := FloatingToolbarCalculateHeight()
    FloatingToolbarGUI.Show("x" . FloatingToolbarWindowX . " y" . FloatingToolbarWindowY . " w" . ToolbarWidth . " h" . ToolbarHeight)
    FloatingToolbarIsVisible := true

    ; 应用圆角边框（窗口显示后）
    FloatingToolbarApplyRoundedCorners()

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

        ; 清理Gdip资源
        FloatingToolbarShutdownGdip()
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

    ; 按钮配置：搜索、笔记、AI助手、截图、设置（使用图片图标）
    ; 图标文件路径（按顺序：搜索、笔记、AI、截图、设置）
    IconPaths := [
        A_ScriptDir . "\images\toolbar_search.png",
        A_ScriptDir . "\images\toolbar_note.png",
        A_ScriptDir . "\images\toolbar_ai.png",
        A_ScriptDir . "\images\toolbar_screenshot.png",
        A_ScriptDir . "\images\toolbar_settings.png"
    ]
    
    ButtonConfigs := [
        Map("text", "搜索", "iconPath", IconPaths[1], "action", "Search", "shortcut", "Caps+F"),
        Map("text", "笔记", "iconPath", IconPaths[2], "action", "Record", "shortcut", "Caps+X"),
        Map("text", "AI助手", "iconPath", IconPaths[3], "action", "AIAssistant", "shortcut", "Ctrl+Shift+B"),
        Map("text", "截图", "iconPath", IconPaths[4], "action", "Screenshot", "shortcut", "Caps+T"),
        Map("text", "设置", "iconPath", IconPaths[5], "action", "Settings", "shortcut", "Caps+Q")
    ]
    
    ; 按钮尺寸和间距（增大尺寸，应用缩放比例）
    global FloatingToolbarScale
    BaseButtonWidth := 40
    BaseButtonHeight := 35
    BaseButtonSpacing := 5
    BaseIconSize := 28  ; 图标大小（按钮内部，增大以显示更清晰的图片）
    BaseStartX := 35  ; 从图标右侧开始
    BaseStartY := 5
    
    ButtonWidth := Round(BaseButtonWidth * FloatingToolbarScale)
    ButtonHeight := Round(BaseButtonHeight * FloatingToolbarScale)
    ButtonSpacing := Round(BaseButtonSpacing * FloatingToolbarScale)
    IconSize := Round(BaseIconSize * FloatingToolbarScale)
    StartX := Round(BaseStartX * FloatingToolbarScale)
    StartY := Round(BaseStartY * FloatingToolbarScale)
    
    ; 清空按钮信息
    FloatingToolbarButtons := Map()

    ; 添加favicon图标（左侧，使用缩放比例）
    ; 尝试多个可能的路径
    FavIconPaths := [
        A_ScriptDir . "\favicon.ico",
        A_WorkingDir . "\favicon.ico",
        A_ScriptDir . "\..\favicon.ico"
    ]
    FavIconPath := ""
    for path in FavIconPaths {
        if (FileExist(path)) {
            FavIconPath := path
            break
        }
    }

    ; favicon基础尺寸和位置（应用缩放比例）
    BaseFavIconSize := 28
    BaseFavIconX := 5
    BaseFavIconY := 5

    FavIconSize := Round(BaseFavIconSize * FloatingToolbarScale)
    FavIconX := Round(BaseFavIconX * FloatingToolbarScale)
    FavIconY := Round(BaseFavIconY * FloatingToolbarScale)

    if (FavIconPath != "") {
        IconPic := FloatingToolbarGUI.Add("Picture",
            "x" . FavIconX . " y" . FavIconY . " w" . FavIconSize . " h" . FavIconSize . " 0x200",
            FavIconPath)
    }

    ; 创建按钮
    Loop ButtonConfigs.Length {
        index := A_Index
        config := ButtonConfigs[index]
        
        x := StartX + (index - 1) * (ButtonWidth + ButtonSpacing)
        
        ; 检查图标文件是否存在
        iconPath := config["iconPath"]
        if (!FileExist(iconPath)) {
            ; 如果文件不存在，尝试其他可能的路径
            actionLower := StrLower(config["action"])  ; 使用 StrLower 代替 LCase
            altPaths := [
                A_WorkingDir . "\images\toolbar_" . actionLower . ".png",
                A_ScriptDir . "\..\images\toolbar_" . actionLower . ".png"
            ]
            for altPath in altPaths {
                if (FileExist(altPath)) {
                    iconPath := altPath
                    break
                }
            }
        }
        
        ; 图标位置（居中显示）
        ; 搜索按钮使用更大的图标尺寸
        currentIconSize := IconSize
        if (config["action"] = "Search") {
            currentIconSize := Round(IconSize * 1.2)  ; 搜索按钮放大20%
        }
        
        iconX := x + (ButtonWidth - currentIconSize) / 2  ; 居中
        iconY := StartY + (ButtonHeight - currentIconSize) / 2  ; 居中
        
        ; 创建图片控件（直接作为可点击区域，使用0x200样式保持图片比例，避免压缩）
        if (FileExist(iconPath)) {
            iconPic := FloatingToolbarGUI.Add("Picture", 
                "x" . iconX . " y" . iconY . 
                " w" . currentIconSize . " h" . currentIconSize . 
                " BackgroundTrans 0x200 vToolbarIcon_" . config["action"], 
                iconPath)
        } else {
            ; 如果图标文件不存在，使用文字作为后备
            iconPic := FloatingToolbarGUI.Add("Text", 
                "x" . x . " y" . StartY . 
                " w" . ButtonWidth . " h" . ButtonHeight . 
                " Center 0x200 c" . FloatingToolbarColors.Text . 
                " BackgroundTrans vToolbarIcon_" . config["action"], 
                SubStr(config["text"], 1, 1))  ; 显示第一个字符
        }
        
        iconPicHwnd := iconPic.Hwnd
        
        ; 创建选中指示器（橙色点）- 初始隐藏
        dotSize := 5  ; 点的大小（稍微增大）
        dotX := x + (ButtonWidth - dotSize) / 2  ; 居中
        dotY := StartY + ButtonHeight - dotSize - 3  ; 图标下方
        
        selectedDot := FloatingToolbarGUI.Add("Text", 
            "x" . dotX . " y" . dotY . 
            " w" . dotSize . " h" . dotSize . 
            " BackgroundFF6600 cFF6600" .  ; 橙色
            " vToolbarDot_" . config["action"], 
            "")
        selectedDot.Visible := false  ; 初始隐藏
        
        ; [核心修复] 使用原生 ToolTip 属性
        ; 格式：功能名称 (快捷键)
        iconPic.ToolTip := config["text"] . " (" . config["shortcut"] . ")"
        
        ; 绑定鼠标点击事件（使用图片控件）
        iconPic.OnEvent("Click", OnToolbarButtonClick.Bind(iconPic, config["action"], iconPicHwnd, config["text"]))
        
        ; 存储按钮信息（用于悬停检测和tooltip）
        FloatingToolbarButtons[iconPicHwnd] := {
            iconPic: iconPic,
            selectedDot: selectedDot,
            x: x,
            y: StartY,
            w: ButtonWidth,
            h: ButtonHeight,
            iconX: iconX,
            iconY: iconY,
            iconSize: currentIconSize,  ; 使用实际图标尺寸（搜索按钮更大）
            action: config["action"],
            tooltip: config["text"],
            shortcut: config["shortcut"],
            iconPath: iconPath,
            isHovered: false  ; 悬停状态
        }
    }
    
    ; 为所有按钮添加拖动支持（通过定时器检测长按）
    SetTimer(FloatingToolbarCheckButtonDrag, 50)
    
    ; 使用窗口事件处理拖动（更可靠）
    FloatingToolbarGUI.OnEvent("ContextMenu", OnFloatingToolbarContextMenu)
    
    ; 监听 WM_LBUTTONDOWN 消息，实现整个窗口拖动
    ; 注意：必须在GUI创建后注册消息监听
    OnMessage(0x0201, FloatingToolbarWM_LBUTTONDOWN)  ; WM_LBUTTONDOWN
    
    ; 监听鼠标滚轮消息，实现缩放功能
    OnMessage(0x020A, FloatingToolbarWM_MOUSEWHEEL)  ; WM_MOUSEWHEEL
}

; ===================== 圆角边框处理 =====================
; 应用圆角边框到窗口
FloatingToolbarApplyRoundedCorners() {
    global FloatingToolbarGUI, FloatingToolbarScale
    
    if (FloatingToolbarGUI = 0) {
        return
    }
    
    try {
        ; 获取窗口尺寸
        FloatingToolbarGUI.GetPos(, , &winWidth, &winHeight)
        
        ; 圆角半径（8px，应用缩放比例）
        radius := Round(8 * FloatingToolbarScale)
        
        ; 使用 CreateRoundRectRgn 创建圆角区域
        ; CreateRoundRectRgn(left, top, right, bottom, widthEllipse, heightEllipse)
        hRgn := DllCall("CreateRoundRectRgn"
            , "Int", 0
            , "Int", 0
            , "Int", winWidth
            , "Int", winHeight
            , "Int", radius * 2
            , "Int", radius * 2
            , "Ptr")
        
        if (hRgn) {
            ; 应用圆角区域到窗口
            DllCall("SetWindowRgn"
                , "Ptr", FloatingToolbarGUI.Hwnd
                , "Ptr", hRgn
                , "Int", 1)  ; 1 = 重绘窗口
            
            ; 注意：SetWindowRgn 会接管 hRgn 的所有权，不需要手动删除
        }
    } catch {
        ; 如果设置圆角失败，静默处理
    }
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
    
    ; 如果点击在按钮上，记录按下时间（用于拖动检测）并应用下沉效果
    if (FloatingToolbarHoveredButton != 0 && !FloatingToolbarDragging) {
        ; 记录按下的按钮和时间
        FloatingToolbarClickedButton := FloatingToolbarHoveredButton
        FloatingToolbarButtonDownTime := A_TickCount
        FloatingToolbarPressedButton := FloatingToolbarHoveredButton
        
        ; 应用下沉效果（坐标下移2px）
        FloatingToolbarApplyPressEffect(FloatingToolbarHoveredButton)
        
        ; 让消息继续传递，控件的Click事件会处理点击
    }
}


; ===================== 按钮点击处理 =====================
OnToolbarButtonClick(iconPic, action, iconPicHwnd, tooltipText, *) {
    global FloatingToolbarDragging, FloatingToolbarSelectedButton, FloatingToolbarButtons, FloatingToolbarPressedButton
    
    ; 如果正在拖动，不处理点击
    if (FloatingToolbarDragging) {
        return
    }
    
    ; 恢复下沉效果（坐标恢复）
    if (FloatingToolbarPressedButton != 0) {
        FloatingToolbarRemovePressEffect(FloatingToolbarPressedButton)
        FloatingToolbarPressedButton := 0
    }
    
    ; 更新选中状态（显示橙色点）
    ; 先隐藏所有点的选中状态
    for btnHwnd, btnInfo in FloatingToolbarButtons {
        if (btnInfo.HasProp("selectedDot")) {
            btnInfo.selectedDot.Visible := false
        }
    }
    
    ; 显示当前按钮的选中点
    if (FloatingToolbarButtons.Has(iconPicHwnd)) {
        if (FloatingToolbarButtons[iconPicHwnd].HasProp("selectedDot")) {
            FloatingToolbarButtons[iconPicHwnd].selectedDot.Visible := true
        }
        FloatingToolbarSelectedButton := iconPicHwnd
    }
    
    ; 直接执行动作
    FloatingToolbarExecuteButtonAction(action, iconPicHwnd)
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
                    ; 开始拖动（恢复下沉效果）
                    global FloatingToolbarPressedButton
                    if (FloatingToolbarPressedButton != 0) {
                        FloatingToolbarRemovePressEffect(FloatingToolbarPressedButton)
                        FloatingToolbarPressedButton := 0
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
            ; 恢复下沉效果
            global FloatingToolbarPressedButton
            if (FloatingToolbarPressedButton != 0) {
                FloatingToolbarRemovePressEffect(FloatingToolbarPressedButton)
                FloatingToolbarPressedButton := 0
            }
            
            ; 获取按钮信息并执行动作
            if (FloatingToolbarButtons.Has(FloatingToolbarClickedButton)) {
                buttonInfo := FloatingToolbarButtons[FloatingToolbarClickedButton]
                action := buttonInfo.action
                
                ; 更新选中状态（显示橙色点）
                global FloatingToolbarSelectedButton
                ; 先隐藏所有点的选中状态
                for btnHwnd, btn in FloatingToolbarButtons {
                    if (btn.HasProp("selectedDot")) {
                        btn.selectedDot.Visible := false
                    }
                }
                ; 显示当前按钮的选中点
                if (buttonInfo.HasProp("selectedDot")) {
                    buttonInfo.selectedDot.Visible := true
                }
                FloatingToolbarSelectedButton := FloatingToolbarClickedButton
                
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

                ; 1. 悬停动效（图标放大效果 + 亮度增强）
                try {
                    if (currentHoverInfo.HasProp("iconPic") && currentHoverInfo.HasProp("iconSize")) {
                        iconPic := currentHoverInfo.iconPic
                        if (Type(iconPic) != "Text") {
                            ; 图片控件：放大效果（从28放大到32）
                            hoverIconSize := currentHoverInfo.iconSize + 4
                            hoverIconX := currentHoverInfo.iconX - 2  ; 居中调整
                            hoverIconY := currentHoverInfo.iconY - 2
                            iconPic.Move(hoverIconX, hoverIconY, hoverIconSize, hoverIconSize)
                            currentHoverInfo.isHovered := true

                            ; 应用亮度增强特效
                            FloatingToolbarApplyHoverBrightness(iconPic, currentHoverInfo)
                        } else {
                            ; 文字后备：改变文字颜色
                            iconPic.Opt("c" . FloatingToolbarColors.TextHover)
                        }
                    }
                } catch as err {
                    ; 调试：显示悬停错误
                    ToolTip("Hover Effect Error: " . err.Message)
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

; [新增辅助函数] 专门用来恢复按钮颜色和动效，让主逻辑更清晰（透明背景，无按钮）
FloatingToolbarRestoreButtonColor(btnHwnd) {
    global FloatingToolbarButtons, FloatingToolbarColors
    if (FloatingToolbarButtons.Has(btnHwnd)) {
        try {
            ; 恢复图标大小和位置（悬停动效还原）
            if (FloatingToolbarButtons[btnHwnd].HasProp("iconPic") && FloatingToolbarButtons[btnHwnd].HasProp("isHovered")) {
                if (FloatingToolbarButtons[btnHwnd].isHovered) {
                    iconPic := FloatingToolbarButtons[btnHwnd].iconPic
                    if (Type(iconPic) != "Text") {
                        ; 恢复原始大小和位置
                        iconPic.Move(
                            FloatingToolbarButtons[btnHwnd].iconX,
                            FloatingToolbarButtons[btnHwnd].iconY,
                            FloatingToolbarButtons[btnHwnd].iconSize,
                            FloatingToolbarButtons[btnHwnd].iconSize
                        )
                        FloatingToolbarButtons[btnHwnd].isHovered := false
                        
                        ; 恢复原始亮度（移除颜色滤镜）
                        FloatingToolbarRemoveHoverBrightness(iconPic, FloatingToolbarButtons[btnHwnd])
                    } else {
                        ; 文字后备：恢复文字颜色
                        iconPic.Opt("c" . FloatingToolbarColors.Text)
                    }
                }
            } else if (FloatingToolbarButtons[btnHwnd].HasProp("iconPic")) {
                ; 如果没有isHovered属性，检查是否是文字后备
                iconPic := FloatingToolbarButtons[btnHwnd].iconPic
                if (Type(iconPic) = "Text") {
                    iconPic.Opt("c" . FloatingToolbarColors.Text)
                }
            }
        }
    }
}

; ===================== 按钮动效函数 =====================
; 应用按下下沉效果
FloatingToolbarApplyPressEffect(btnHwnd) {
    global FloatingToolbarButtons
    if (FloatingToolbarButtons.Has(btnHwnd)) {
        try {
            btnInfo := FloatingToolbarButtons[btnHwnd]
            if (btnInfo.HasProp("iconPic")) {
                iconPic := btnInfo.iconPic
                if (Type(iconPic) != "Text") {
                    ; 下沉效果：坐标下移2px
                    ; 获取当前坐标（考虑悬停状态）
                    currentX := btnInfo.iconX
                    currentY := btnInfo.iconY
                    currentSize := btnInfo.iconSize
                    
                    if (btnInfo.isHovered) {
                        ; 如果正在悬停，使用悬停后的坐标和大小
                        currentX := currentX - 2
                        currentY := currentY - 2
                        currentSize := currentSize + 4
                    }
                    
                    ; 应用下沉：坐标下移2px
                    iconPic.Move(currentX + 2, currentY + 2, currentSize, currentSize)
                    
                    ; 应用点击着色效果（橙色调）
                    FloatingToolbarApplyClickColor(iconPic, btnInfo)
                }
            }
        } catch {
        }
    }
}

; 移除按下下沉效果
FloatingToolbarRemovePressEffect(btnHwnd) {
    global FloatingToolbarButtons
    if (FloatingToolbarButtons.Has(btnHwnd)) {
        try {
            btnInfo := FloatingToolbarButtons[btnHwnd]
            if (btnInfo.HasProp("iconPic")) {
                iconPic := btnInfo.iconPic
                if (Type(iconPic) != "Text") {
                    ; 恢复坐标（考虑悬停状态）
                    currentX := btnInfo.iconX
                    currentY := btnInfo.iconY
                    currentSize := btnInfo.iconSize
                    
                    if (btnInfo.isHovered) {
                        ; 如果正在悬停，使用悬停后的坐标和大小
                        currentX := currentX - 2
                        currentY := currentY - 2
                        currentSize := currentSize + 4
                    }
                    
                    ; 恢复原始位置
                    iconPic.Move(currentX, currentY, currentSize, currentSize)
                    
                    ; 恢复颜色（如果正在悬停，恢复悬停亮度；否则恢复原始）
                    if (btnInfo.isHovered) {
                        FloatingToolbarApplyHoverBrightness(iconPic, btnInfo)
                    } else {
                        FloatingToolbarRemoveHoverBrightness(iconPic, btnInfo)
                    }
                }
            }
        } catch {
        }
    }
}

; ===================== Gdip 初始化和清理 =====================
FloatingToolbarInitializeGdip() {
    global FloatingToolbarGdipToken, FloatingToolbarGdipInitialized

    if (!FloatingToolbarGdipInitialized) {
        FloatingToolbarGdipToken := Gdip_Startup()
        FloatingToolbarGdipInitialized := true
    }
}

FloatingToolbarShutdownGdip() {
    global FloatingToolbarGdipToken, FloatingToolbarGdipInitialized, FloatingToolbarButtons

    if (FloatingToolbarGdipInitialized) {
        ; 清理所有按钮的Gdip资源
        for btnHwnd, btnInfo in FloatingToolbarButtons {
            FloatingToolbarCleanupButtonGdip(btnInfo)
        }
        Gdip_Shutdown(FloatingToolbarGdipToken)
        FloatingToolbarGdipToken := 0
        FloatingToolbarGdipInitialized := false
    }
}

FloatingToolbarCleanupButtonGdip(btnInfo) {
    try {
        ; 清理悬停状态图片
        if (btnInfo.HasProp("hoverBitmap") && btnInfo.hoverBitmap != 0) {
            Gdip_DisposeImage(btnInfo.hoverBitmap)
            btnInfo.hoverBitmap := 0
        }
        ; 清理按下状态图片
        if (btnInfo.HasProp("pressBitmap") && btnInfo.pressBitmap != 0) {
            Gdip_DisposeImage(btnInfo.pressBitmap)
            btnInfo.pressBitmap := 0
        }
        ; 清理临时文件
        if (btnInfo.HasProp("hoverFile") && btnInfo.hoverFile != "" && FileExist(btnInfo.hoverFile)) {
            FileDelete(btnInfo.hoverFile)
            btnInfo.hoverFile := ""
        }
        if (btnInfo.HasProp("pressFile") && btnInfo.pressFile != "" && FileExist(btnInfo.pressFile)) {
            FileDelete(btnInfo.pressFile)
            btnInfo.pressFile := ""
        }
    } catch {
    }
}

; ===================== 悬停和点击特效 =====================

; 应用悬停亮度增强效果
FloatingToolbarApplyHoverBrightness(iconPic, btnInfo) {
    global FloatingToolbarGdipInitialized

    if (!FloatingToolbarGdipInitialized || Type(iconPic) = "Text") {
        return
    }

    try {
        ; 如果还没有生成悬停图片，生成并缓存
        if (!btnInfo.HasProp("hoverFile") || btnInfo.hoverFile = "" || !FileExist(btnInfo.hoverFile)) {
            FloatingToolbarCreateHoverImage(btnInfo)
        }

        ; 应用悬停图片（使用WM_SETICON消息更新）
        if (btnInfo.HasProp("hoverFile") && btnInfo.hoverFile != "" && FileExist(btnInfo.hoverFile)) {
            ; 使用SendMessage更新图片（更可靠的方法）
            iconPic.Opt("+BackgroundTrans")
            SendMessage(0x0172, 0, 0, iconPic.Hwnd)  ; STM_SETIMAGE = 0x0172
            iconPic.Value := btnInfo.hoverFile
        }
    } catch as err {
        ; 调试：显示错误信息
        ; ToolTip("Hover Error: " . err.Message)
    }
}

; 移除悬停亮度效果
FloatingToolbarRemoveHoverBrightness(iconPic, btnInfo) {
    if (Type(iconPic) = "Text") {
        return
    }

    try {
        ; 恢复原始图片
        if (btnInfo.HasProp("iconPath") && btnInfo.iconPath != "" && FileExist(btnInfo.iconPath)) {
            iconPic.Value := btnInfo.iconPath
        }
    } catch as err {
        ; ToolTip("Restore Error: " . err.Message)
    }
}

; 应用点击着色效果
FloatingToolbarApplyClickColor(iconPic, btnInfo) {
    global FloatingToolbarGdipInitialized

    if (!FloatingToolbarGdipInitialized || Type(iconPic) = "Text") {
        return
    }

    try {
        ; 如果还没有生成按下图片，生成并缓存
        if (!btnInfo.HasProp("pressFile") || btnInfo.pressFile = "" || !FileExist(btnInfo.pressFile)) {
            FloatingToolbarCreatePressImage(btnInfo)
        }

        ; 应用按下图片
        if (btnInfo.HasProp("pressFile") && btnInfo.pressFile != "" && FileExist(btnInfo.pressFile)) {
            iconPic.Opt("+BackgroundTrans")
            iconPic.Value := btnInfo.pressFile
        }
    } catch as err {
        ; ToolTip("Press Error: " . err.Message)
    }
}

; 创建悬停状态图片（亮度增强 - 使用叠加白色半透明层实现）
FloatingToolbarCreateHoverImage(btnInfo) {
    global FloatingToolbarGdipToken

    try {
        if (!FileExist(btnInfo.iconPath)) {
            return
        }

        ; 加载原始图片
        pBitmap := Gdip_CreateBitmapFromFile(btnInfo.iconPath)
        if (!pBitmap) {
            return
        }

        ; 获取图片尺寸
        width := Gdip_GetImageWidth(pBitmap)
        height := Gdip_GetImageHeight(pBitmap)

        ; 创建新的位图用于处理
        pProcessedBitmap := Gdip_CloneBitmapArea(pBitmap, 0, 0, width, height)

        ; 获取Graphics
        pGraphics := Gdip_GraphicsFromImage(pProcessedBitmap)

        ; 添加白色半透明叠加层（模拟亮度增加效果）
        ; 25% 透明度的白色
        pBrush := Gdip_BrushCreateSolid(0x40FFFFFF)
        Gdip_FillRectangle(pGraphics, pBrush, 0, 0, width, height)
        Gdip_DeleteBrush(pBrush)

        ; 清理资源
        Gdip_DeleteGraphics(pGraphics)
        Gdip_DisposeImage(pBitmap)

        ; 保存到临时文件
        tempDir := A_Temp . "\FloatingToolbar"
        if (!DirExist(tempDir)) {
            DirCreate(tempDir)
        }
        hoverFile := tempDir . "\hover_" . btnInfo.action . "_" . A_TickCount . ".png"
        Gdip_SaveBitmapToFile(pProcessedBitmap, hoverFile, 100)
        Gdip_DisposeImage(pProcessedBitmap)

        ; 存储到按钮信息
        btnInfo.hoverFile := hoverFile
    } catch {
    }
}

; 创建按下状态图片（变暗 + 橙色叠加）
FloatingToolbarCreatePressImage(btnInfo) {
    global FloatingToolbarGdipToken

    try {
        if (!FileExist(btnInfo.iconPath)) {
            return
        }

        ; 加载原始图片
        pBitmap := Gdip_CreateBitmapFromFile(btnInfo.iconPath)
        if (!pBitmap) {
            return
        }

        ; 获取图片尺寸
        width := Gdip_GetImageWidth(pBitmap)
        height := Gdip_GetImageHeight(pBitmap)

        ; 创建新的位图用于处理
        pProcessedBitmap := Gdip_CloneBitmapArea(pBitmap, 0, 0, width, height)

        ; 获取Graphics
        pGraphics := Gdip_GraphicsFromImage(pProcessedBitmap)

        ; 先绘制原始图片
        Gdip_DrawImage(pGraphics, pBitmap, 0, 0, width, height)

        ; 添加黑色半透明叠加层（变暗效果 - 40%透明度的黑色）
        pBrushDark := Gdip_BrushCreateSolid(0x66000000)
        Gdip_FillRectangle(pGraphics, pBrushDark, 0, 0, width, height)
        Gdip_DeleteBrush(pBrushDark)

        ; 添加橙色半透明叠加（增强点击反馈 - 25%透明度的橙色）
        pBrushOrange := Gdip_BrushCreateSolid(0x40FF6600)
        Gdip_FillRectangle(pGraphics, pBrushOrange, 0, 0, width, height)
        Gdip_DeleteBrush(pBrushOrange)

        ; 清理资源
        Gdip_DeleteGraphics(pGraphics)
        Gdip_DisposeImage(pBitmap)

        ; 保存到临时文件
        tempDir := A_Temp . "\FloatingToolbar"
        if (!DirExist(tempDir)) {
            DirCreate(tempDir)
        }
        pressFile := tempDir . "\press_" . btnInfo.action . "_" . A_TickCount . ".png"
        Gdip_SaveBitmapToFile(pProcessedBitmap, pressFile, 100)
        Gdip_DisposeImage(pProcessedBitmap)

        ; 存储到按钮信息
        btnInfo.pressFile := pressFile
    } catch {
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
    
    ; 检查是否在按钮区域内（更新坐标以适应新尺寸）
    ; 按钮区域：StartX 到 StartX + (ButtonWidth * 5) + (ButtonSpacing * 4)
    buttonAreaStartX := 35
    buttonAreaEndX := 35 + (40 * 5) + (5 * 4)
    buttonAreaStartY := 5
    buttonAreaEndY := 5 + 35
    if (wx >= buttonAreaStartX && wx <= buttonAreaEndX && wy >= buttonAreaStartY && wy <= buttonAreaEndY) {
        ; 在按钮区域内，不拖动（按钮有自己的拖动处理）
        return
    }
    
    ; 检查是否在图标区域内（图标区域：x5-33, y5-33）
    if (wx >= 5 && wx <= 33 && wy >= 5 && wy <= 33) {
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

; ===================== 计算工具栏宽度和高度 =====================
FloatingToolbarCalculateWidth() {
    global FloatingToolbarScale
    BaseStartX := 35
    BaseButtonWidth := 40
    BaseButtonSpacing := 5
    StartX := Round(BaseStartX * FloatingToolbarScale)
    ButtonWidth := Round(BaseButtonWidth * FloatingToolbarScale)
    ButtonSpacing := Round(BaseButtonSpacing * FloatingToolbarScale)
    return StartX + (ButtonWidth * 5) + (ButtonSpacing * 4) + Round(10 * FloatingToolbarScale)
}

FloatingToolbarCalculateHeight() {
    global FloatingToolbarScale
    BaseStartY := 5
    BaseButtonHeight := 35
    StartY := Round(BaseStartY * FloatingToolbarScale)
    ButtonHeight := Round(BaseButtonHeight * FloatingToolbarScale)
    return StartY + ButtonHeight + Round(10 * FloatingToolbarScale)
}

; ===================== 鼠标滚轮缩放处理 =====================
FloatingToolbarWM_MOUSEWHEEL(wParam, lParam, msg, hwnd) {
    global FloatingToolbarGUI, FloatingToolbarIsVisible, FloatingToolbarScale, FloatingToolbarMinScale, FloatingToolbarMaxScale, FloatingToolbarWindowX, FloatingToolbarWindowY

    ; 检查窗口是否可见
    if (!FloatingToolbarIsVisible || !FloatingToolbarGUI) {
        return
    }

    ; 检查鼠标是否在工具栏窗口内（使用MouseGetPos检测）
    MouseGetPos(&mx, &my, &winHwnd)
    if (winHwnd != FloatingToolbarGUI.Hwnd) {
        return
    }
    
    ; 获取滚轮方向（wParam的高16位包含滚轮增量）
    ; 正数 = 向上滚动（放大），负数 = 向下滚动（缩小）
    wheelDelta := (wParam >> 16) & 0xFFFF
    if (wheelDelta > 0x7FFF) {
        wheelDelta := wheelDelta - 0x10000
    }
    
    ; 计算新的缩放比例（每次滚动调整15%，提高缩放效率）
    scaleStep := 0.15
    newScale := FloatingToolbarScale
    
    if (wheelDelta > 0) {
        ; 向上滚动，放大
        newScale := FloatingToolbarScale + scaleStep
        if (newScale > FloatingToolbarMaxScale) {
            newScale := FloatingToolbarMaxScale
        }
    } else {
        ; 向下滚动，缩小
        newScale := FloatingToolbarScale - scaleStep
        if (newScale < FloatingToolbarMinScale) {
            newScale := FloatingToolbarMinScale
        }
    }
    
    ; 如果缩放比例发生变化，重新创建工具栏
    if (newScale != FloatingToolbarScale) {
        ; 获取当前窗口位置和尺寸
        FloatingToolbarGUI.GetPos(&oldX, &oldY, &oldWidth, &oldHeight)
        
        ; 获取鼠标在窗口内的相对位置（相对于窗口左上角）
        MouseGetPos(&mouseScreenX, &mouseScreenY)
        mouseRelX := mouseScreenX - oldX
        mouseRelY := mouseScreenY - oldY
        
        ; 计算鼠标位置在窗口中的比例（0.0 到 1.0）
        mouseRatioX := oldWidth > 0 ? mouseRelX / oldWidth : 0.5
        mouseRatioY := oldHeight > 0 ? mouseRelY / oldHeight : 0.5
        
        ; 更新缩放比例
        FloatingToolbarScale := newScale
        
        ; 重新创建GUI（应用新的缩放比例）
        CreateFloatingToolbarGUI()
        
        ; 重新计算窗口尺寸
        ToolbarWidth := FloatingToolbarCalculateWidth()
        ToolbarHeight := FloatingToolbarCalculateHeight()
        
        ; 计算新窗口位置，使得鼠标位置对应的点在缩放前后保持不变
        ; 新窗口的左上角位置 = 鼠标屏幕位置 - 鼠标在新窗口中的相对位置
        newX := mouseScreenX - Round(mouseRatioX * ToolbarWidth)
        newY := mouseScreenY - Round(mouseRatioY * ToolbarHeight)
        
        ; 边界检查（防止窗口超出屏幕）
        ScreenWidth := SysGet(0)
        ScreenHeight := SysGet(1)
        if (newX < 0) {
            newX := 0
        }
        if (newY < 0) {
            newY := 0
        }
        if (newX + ToolbarWidth > ScreenWidth) {
            newX := ScreenWidth - ToolbarWidth
        }
        if (newY + ToolbarHeight > ScreenHeight) {
            newY := ScreenHeight - ToolbarHeight
        }
        
        ; 更新窗口位置
        FloatingToolbarWindowX := newX
        FloatingToolbarWindowY := newY
        
        ; 显示窗口（使用新位置和新尺寸）
        FloatingToolbarGUI.Show("x" . newX . " y" . newY . " w" . ToolbarWidth . " h" . ToolbarHeight)
        
        ; 重新应用圆角边框（窗口尺寸改变后）
        FloatingToolbarApplyRoundedCorners()
        
        ; 保存缩放比例和位置到配置文件
        FloatingToolbarSaveScale()
        SaveFloatingToolbarPosition()
    }
    
    return 0  ; 表示已处理消息
}

; ===================== 保存和加载缩放比例 =====================
FloatingToolbarSaveScale() {
    global FloatingToolbarScale
    try {
        ConfigFile := A_ScriptDir . "\CursorShortcut.ini"
        IniWrite(String(FloatingToolbarScale), ConfigFile, "FloatingToolbar", "Scale")
    } catch {
    }
}

FloatingToolbarLoadScale() {
    global FloatingToolbarScale, FloatingToolbarMinScale, FloatingToolbarMaxScale
    try {
        ConfigFile := A_ScriptDir . "\CursorShortcut.ini"
        savedScale := IniRead(ConfigFile, "FloatingToolbar", "Scale", "1.0")
        if (savedScale != "" && savedScale != "ERROR") {
            scaleValue := Float(savedScale)
            ; 确保缩放比例在有效范围内
            if (scaleValue >= FloatingToolbarMinScale && scaleValue <= FloatingToolbarMaxScale) {
                FloatingToolbarScale := scaleValue
            }
        }
    } catch {
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
            
            ; 计算窗口宽度和高度
            ToolbarWidth := FloatingToolbarCalculateWidth()
            ToolbarHeight := FloatingToolbarCalculateHeight()
            if (FloatingToolbarWindowX < 0 || FloatingToolbarWindowX > ScreenWidth - ToolbarWidth) {
                FloatingToolbarWindowX := 0
            }
            if (FloatingToolbarWindowY < 0 || FloatingToolbarWindowY > ScreenHeight - ToolbarHeight) {
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
; ===================== 隐藏到屏幕边缘 =====================
MinimizeFloatingToolbarToEdge() {
    global FloatingToolbarGUI, FloatingToolbarIsVisible, FloatingToolbarIsMinimized
    global FloatingToolbarWindowX, FloatingToolbarWindowY
    
    if (!FloatingToolbarIsVisible || FloatingToolbarGUI = 0) {
        return
    }
    
    ; 获取当前窗口位置
    FloatingToolbarGUI.GetPos(&currentX, &currentY, &currentW, &currentH)
    
    ; 获取屏幕尺寸
    ScreenWidth := SysGet(0)
    ScreenHeight := SysGet(1)
    
    ; 计算到各边缘的距离，选择最近的边缘
    distLeft := currentX
    distRight := ScreenWidth - (currentX + currentW)
    distTop := currentY
    distBottom := ScreenHeight - (currentY + currentH)
    
    ; 找到最小距离
    minDist := distLeft
    targetX := 0
    targetY := currentY
    
    if (distRight < minDist) {
        minDist := distRight
        targetX := ScreenWidth - currentW
        targetY := currentY
    }
    if (distTop < minDist) {
        minDist := distTop
        targetX := currentX
        targetY := 0
    }
    if (distBottom < minDist) {
        minDist := distBottom
        targetX := currentX
        targetY := ScreenHeight - currentH
    }
    
    ; 移动到最近的边缘
    FloatingToolbarGUI.Move(targetX, targetY)
    FloatingToolbarWindowX := targetX
    FloatingToolbarWindowY := targetY
    FloatingToolbarIsMinimized := true
    
    ; 保存位置
    SaveFloatingToolbarPosition()
}

; ===================== 恢复悬浮工具栏 =====================
RestoreFloatingToolbar() {
    global FloatingToolbarIsMinimized
    FloatingToolbarIsMinimized := false
    ; 位置已保存，显示时会自动加载
}

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
