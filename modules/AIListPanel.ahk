; ======================================================================================================================
; AI选择列表面板 - 显示所有AI搜索引擎供用户选择
; 版本: 1.0.0
; 功能: 
;   - 显示SearchCenter中所有AI分类的搜索引擎
;   - 每个列表项显示图标和名称
;   - 鼠标悬浮和点击有动画效果
;   - 点击后打开Cursor浏览器并加载对应AI，将剪贴板内容作为参数
;   - 加载时显示提示
; ======================================================================================================================

#Requires AutoHotkey v2.0

; ===================== 全局变量 =====================
global AIListPanelGUI := 0  ; AI列表面板GUI对象
global AIListPanelIsVisible := false  ; 是否可见
global AIListPanelItems := []  ; 列表项数组
global AIListPanelHoveredIndex := 0  ; 当前悬浮的列表项索引
global AIListPanelLoadingEngine := ""  ; 当前正在加载的引擎
global AIListPanelIconOnlyMode := false  ; 是否只显示图标模式
global AIListPanelDragging := false  ; 是否正在拖动
global AIListPanelDragStartX := 0  ; 拖动起始X坐标
global AIListPanelDragStartY := 0  ; 拖动起始Y坐标
global AIListPanelWindowX := 0  ; 窗口X坐标（竖排模式）
global AIListPanelWindowY := 0  ; 窗口Y坐标（竖排模式）
global AIListPanelWindowW := 180  ; 窗口宽度（竖排模式）
global AIListPanelWindowH := 400  ; 窗口高度（竖排模式）
global AIListPanelIconModeX := 0  ; 窗口X坐标（横排模式）
global AIListPanelIconModeY := 0  ; 窗口Y坐标（横排模式）
global AIListPanelIconModeW := 400  ; 窗口宽度（横排模式）
global AIListPanelIconModeH := 100  ; 窗口高度（横排模式）
global AIListPanelLastWidth := 0  ; 上一次的宽度（用于判断是否需要重新计算高度）
global AIListPanelLastRows := 0  ; 上一次的行数（用于判断是否需要重新计算高度）
global AIListPanelTitleBar := 0  ; 标题栏控件（已隐藏）
global AIListPanelToggleBtn := 0  ; 切换模式按钮控件
global AIListPanelIsMinimized := false  ; 是否已最小化到边缘
global AIListPanelSearchInput := 0  ; 搜索输入框控件
global AIListPanelSearchBtn := 0  ; 搜索按钮控件
global AIListPanelSelectedEngines := []  ; 选中的AI引擎列表
global AIListPanelCheckboxes := Map()  ; 复选框控件映射（engineValue -> checkbox控件）
global AIListPanelEnterHotkey := 0  ; 回车键快捷键对象
global AIListPanelIsResizing := false  ; 是否正在调整大小（防止循环触发）
global AIListPanelUserResizing := false  ; 用户是否正在手动调整大小
global AIListPanelUserMoving := false  ; 用户是否正在手动移动窗口

; Cursor色系配色
AIListPanelColors := {
    Background: "1e1e1e",
    Border: "3c3c3c",
    Text: "cccccc",
    TextHover: "ffffff",
    ItemBg: "252526",
    ItemHover: "37373d",
    ItemActive: "007acc",
    ItemBorder: "3c3c3c",
    LoadingBg: "2d2d30",
    LoadingText: "007acc"
}

; ===================== 显示/隐藏AI列表面板 =====================
ShowAIListPanel() {
    global AIListPanelGUI, AIListPanelIsVisible, AIListPanelIconOnlyMode
    global AIListPanelIconModeX, AIListPanelIconModeY, AIListPanelIconModeW, AIListPanelIconModeH
    global AIListPanelWindowX, AIListPanelWindowY, AIListPanelWindowW, AIListPanelWindowH
    global FloatingToolbarGUI, FloatingToolbarWindowX, FloatingToolbarWindowY
    
    ; 调试信息
    debugInfo := ""
    
    try {
        if (AIListPanelIsVisible && AIListPanelGUI != 0) {
            ; 如果已显示，则隐藏
            HideAIListPanel()
            return
        }
        
        debugInfo .= "步骤1: 检查完成`n"
        
        ; 创建GUI
        try {
            CreateAIListPanelGUI()
            debugInfo .= "步骤2: GUI创建成功`n"
        } catch as err {
            debugInfo .= "步骤2: GUI创建失败 - " . err.Message . "`n"
            MsgBox("AI选择面板调试信息:`n`n" . debugInfo, "调试信息", "Iconx")
            return
        }
        
        debugInfo .= "步骤3: 准备显示GUI`n"

        ; 加载保存的位置和尺寸
        LoadAIListPanelPosition()

        ; 根据模式使用对应的位置变量
        global AIListPanelIconOnlyMode, AIListPanelIconModeX, AIListPanelIconModeY
        global AIListPanelIconModeW, AIListPanelIconModeH

        if (AIListPanelIconOnlyMode) {
            ; 横排模式：使用横排模式的位置
            savedX := AIListPanelIconModeX
            savedY := AIListPanelIconModeY
            savedW := AIListPanelIconModeW
            savedH := AIListPanelIconModeH
        } else {
            ; 竖排模式：使用竖排模式的位置
            savedX := AIListPanelWindowX
            savedY := AIListPanelWindowY
            savedW := AIListPanelWindowW
            savedH := AIListPanelWindowH
        }

        ; 优先使用保存的位置，如果没有保存位置才跟随工具栏
        if (savedX != 0 && savedY != 0) {
            ; 使用保存的位置
            panelX := savedX
            panelY := savedY
            panelW := savedW > 0 ? savedW : (AIListPanelIconOnlyMode ? 400 : 180)
            panelH := savedH > 0 ? savedH : (AIListPanelIconOnlyMode ? 100 : 400)
            debugInfo .= "步骤4: 使用保存的位置`n"
        } else {
            ; 没有保存位置，尝试跟随工具栏
            global FloatingToolbarGUI, FloatingToolbarWindowX, FloatingToolbarWindowY
            if (FloatingToolbarGUI != 0) {
                try {
                    FloatingToolbarGUI.GetPos(&toolbarX, &toolbarY, &toolbarW, &toolbarH)
                    ; 跟随工具栏位置，显示在工具栏上方
                    panelX := toolbarX
                    panelY := toolbarY - (AIListPanelIconOnlyMode ? AIListPanelIconModeH : AIListPanelWindowH)
                    ; 如果超出屏幕上方，则显示在工具栏下方
                    ScreenHeight := SysGet(1)
                    if (panelY < 0) {
                        panelY := toolbarY + toolbarH + 5
                    }
                    panelW := AIListPanelIconOnlyMode ? AIListPanelIconModeW : AIListPanelWindowW
                    panelH := AIListPanelIconOnlyMode ? AIListPanelIconModeH : AIListPanelWindowH
                    debugInfo .= "步骤4: 跟随工具栏位置`n"
                } catch as err {
                    debugInfo .= "步骤4: 工具栏位置获取失败 - " . err.Message . "`n"
                    ; 使用默认位置
                    ScreenWidth := SysGet(0)
                    ScreenHeight := SysGet(1)
                    panelW := AIListPanelIconOnlyMode ? AIListPanelIconModeW : AIListPanelWindowW
                    panelH := AIListPanelIconOnlyMode ? AIListPanelIconModeH : AIListPanelWindowH
                    panelX := (ScreenWidth - panelW) // 2
                    panelY := (ScreenHeight - panelH) // 2
                }
            } else {
                ; 没有工具栏，使用默认位置
                ScreenWidth := SysGet(0)
                ScreenHeight := SysGet(1)
                panelW := AIListPanelIconOnlyMode ? AIListPanelIconModeW : AIListPanelWindowW
                panelH := AIListPanelIconOnlyMode ? AIListPanelIconModeH : AIListPanelWindowH
                panelX := (ScreenWidth - panelW) // 2
                panelY := (ScreenHeight - panelH) // 2
                debugInfo .= "步骤4: 使用默认位置`n"
            }
        }

        ; 更新全局变量
        if (AIListPanelIconOnlyMode) {
            AIListPanelIconModeX := panelX
            AIListPanelIconModeY := panelY
            AIListPanelIconModeW := panelW
            AIListPanelIconModeH := panelH
        } else {
            AIListPanelWindowX := panelX
            AIListPanelWindowY := panelY
            AIListPanelWindowW := panelW
            AIListPanelWindowH := panelH
        }
        
        debugInfo .= "步骤5: 准备显示窗口，位置: x=" . panelX . ", y=" . panelY . ", w=" . panelW . ", h=" . panelH . "`n"

        ; 显示GUI
        try {
            if (AIListPanelGUI = 0) {
                throw Error("GUI对象为空")
            }
            AIListPanelGUI.Show("x" . panelX . " y" . panelY . " w" . panelW . " h" . panelH)
            AIListPanelIsVisible := true
            debugInfo .= "步骤6: GUI显示成功`n"
        } catch as err {
            debugInfo .= "步骤6: GUI显示失败 - " . err.Message . "`n"
            MsgBox("AI选择面板调试信息:`n`n" . debugInfo, "调试信息", "Iconx")
            return
        }
        
        debugInfo .= "步骤7: 启动悬停检测定时器`n"
        
        ; 启动定时器用于悬停效果检测和跟随工具栏
        try {
            SetTimer(AIListPanelCheckItemHover, 50)
            SetTimer(AIListPanelFollowToolbar, 100)  ; 跟随悬浮工具栏移动
            
            ; 设置窗口级别的回车键快捷键（当窗口激活时）
            global AIListPanelEnterHotkey, AIListPanelGUI
            try {
                ; 使用条件Hotkey，仅在AI面板窗口激活时生效
                HotIfWinActive("ahk_id " . AIListPanelGUI.Hwnd)
                AIListPanelEnterHotkey := Hotkey("Enter", OnAIListPanelSearch, "On")
                HotIfWinActive()  ; 重置条件
            } catch {
                ; 如果设置失败，静默处理
            }
            
            debugInfo .= "步骤8: 所有步骤完成`n"
        } catch as err {
            debugInfo .= "步骤8: 定时器启动失败 - " . err.Message . "`n"
            MsgBox("AI选择面板调试信息:`n`n" . debugInfo, "调试信息", "Iconx")
        }
        
    } catch as err {
        debugInfo .= "发生未捕获的错误: " . err.Message . "`n"
        debugInfo .= "错误位置: " . err.File . " 第 " . err.Line . " 行`n"
        MsgBox("AI选择面板调试信息:`n`n" . debugInfo, "调试信息", "Iconx")
    }
}

HideAIListPanel() {
    global AIListPanelGUI, AIListPanelIsVisible, AIListPanelEnterHotkey
    
    if (AIListPanelGUI != 0) {
        ; 保存位置和尺寸
        SaveAIListPanelPosition()
        
        ; 移除回车键快捷键
        try {
            if (AIListPanelEnterHotkey != 0) {
                AIListPanelEnterHotkey.Off()
            }
        } catch {
        }
        
        AIListPanelGUI.Hide()
        AIListPanelIsVisible := false
        
        ; 停止定时器
        SetTimer(AIListPanelCheckItemHover, 0)
        SetTimer(AIListPanelFollowToolbar, 0)  ; 停止跟随定时器
    }
}

ToggleAIListPanel() {
    global AIListPanelIsVisible
    
    if (AIListPanelIsVisible) {
        HideAIListPanel()
    } else {
        ShowAIListPanel()
    }
}

; ===================== 创建GUI =====================
CreateAIListPanelGUI() {
    global AIListPanelGUI, AIListPanelColors, AIListPanelItems, AIListPanelCheckboxes
    
    ; 初始化复选框映射
    AIListPanelCheckboxes := Map()
    
    ; 如果已存在，先销毁
    if (AIListPanelGUI != 0) {
        try {
            AIListPanelGUI.Destroy()
        } catch {
        }
    }
    
    ; 创建GUI（有边框、置顶、可调整大小）
    ; 横排模式下禁用竖向拉伸，竖排模式下可以拉伸
    resizeFlags := AIListPanelIconOnlyMode ? "+AlwaysOnTop +Resize -MaximizeBox +MinimizeBox" : "+AlwaysOnTop +Resize -MaximizeBox +MinimizeBox"
    AIListPanelGUI := Gui(resizeFlags, "AI助手选择")
    AIListPanelGUI.BackColor := AIListPanelColors.Background
    AIListPanelGUI.SetFont("s10 c" . AIListPanelColors.Text, "Segoe UI")
    
    ; 窗口事件
    AIListPanelGUI.OnEvent("Close", OnAIListPanelClose)
    AIListPanelGUI.OnEvent("Size", OnAIListPanelSize)
    ; AutoHotkey v2 不支持 "Move" 事件，使用定时器跟踪位置
    
    ; 监听拖动消息
    OnMessage(0x0201, AIListPanelWM_LBUTTONDOWN)  ; WM_LBUTTONDOWN
    OnMessage(0x0200, AIListPanelWM_MOUSEMOVE)  ; WM_MOUSEMOVE
    OnMessage(0x0202, AIListPanelWM_LBUTTONUP)  ; WM_LBUTTONUP
    
    ; 创建标题栏（可拖动，但默认隐藏）
    global AIListPanelTitleBar, AIListPanelToggleBtn
    AIListPanelTitleBar := AIListPanelGUI.Add("Text", 
        "x0 y0 w" . AIListPanelWindowW . " h30 Center 0x200 Background" . AIListPanelColors.ItemBg . 
        " c" . AIListPanelColors.TextHover, "")
    AIListPanelTitleBar.SetFont("s11 Bold", "Segoe UI")
    AIListPanelTitleBar.Visible := false  ; 默认隐藏标题栏
    
    ; 创建切换显示模式按钮（开关图标）- 放在搜索框左侧
    global AIListPanelToggleBtn
    AIListPanelToggleBtn := AIListPanelGUI.Add("Text", 
        "x5 y5 w20 h20 Center 0x200 Background" . AIListPanelColors.ItemHover . 
        " c" . AIListPanelColors.TextHover, AIListPanelIconOnlyMode ? "☰" : "☷")
    AIListPanelToggleBtn.SetFont("s12", "Segoe UI")
    try {
        AIListPanelToggleBtn.OnEvent("Click", CreateToggleModeButtonHandler())
    } catch as err {
        MsgBox("切换按钮绑定失败: " . err.Message, "错误", "Iconx")
    }
    
    ; 创建搜索输入框和按钮
    global AIListPanelSearchInput, AIListPanelSearchBtn
    ; 搜索框使用完整宽度，与搜索按钮相切
    searchInputWidth := AIListPanelWindowW - 75  ; 完整宽度
    AIListPanelSearchInput := AIListPanelGUI.Add("Edit",
        "x30 y5 w" . searchInputWidth . " h20 Background" . AIListPanelColors.ItemBg .
        " c" . AIListPanelColors.Text, "")
    AIListPanelSearchInput.SetFont("s9", "Segoe UI")

    ; 搜索按钮（紧跟在搜索框后面，相切）
    searchBtnX := 30 + searchInputWidth + 5
    AIListPanelSearchBtn := AIListPanelGUI.Add("Text",
        "x" . searchBtnX . " y5 w40 h20 Center 0x200 Background" . AIListPanelColors.ItemHover .
        " c" . AIListPanelColors.TextHover, "搜索")
    AIListPanelSearchBtn.SetFont("s9", "Segoe UI")
    AIListPanelSearchBtn.OnEvent("Click", OnAIListPanelSearch)
    
    ; 输入框内容变化时，显示/隐藏复选框
    AIListPanelSearchInput.OnEvent("Change", OnAIListPanelSearchInputChange)
    
    ; 使用窗口级别的快捷键处理回车键（AutoHotkey v2的Edit控件不支持KeyDown事件）
    ; 当输入框获得焦点时，回车键会触发搜索
    
    ; 获取所有AI分类的搜索引擎
    debugInfo := ""
    try {
        debugInfo .= "步骤1: 开始获取AI引擎列表...`n"
        
        ; 直接尝试调用函数，如果不存在会抛出错误
        AIEngines := GetSortedSearchEngines("ai")
        debugInfo .= "步骤2: GetSortedSearchEngines调用成功`n"
        debugInfo .= "步骤3: 返回类型: " . Type(AIEngines) . "`n"
        
        if (!IsObject(AIEngines)) {
            throw Error("GetSortedSearchEngines返回的不是对象，类型: " . Type(AIEngines))
        }
        
        debugInfo .= "步骤4: 确认返回的是对象`n"
        
        if (AIEngines.Length = 0) {
            debugInfo .= "步骤5: AI引擎列表为空`n"
            ; 如果没有AI引擎，显示提示
            NoEnginesLabel := AIListPanelGUI.Add("Text", 
                "x0 y5 w" . AIListPanelWindowW . " h370 Center 0x200 Background" . AIListPanelColors.Background . 
                " c" . AIListPanelColors.Text, "暂无AI引擎")
            MsgBox("AI选择面板调试信息:`n`n" . debugInfo, "调试信息", "Iconi")
            return
        }
        
        debugInfo .= "步骤5: 找到 " . AIEngines.Length . " 个AI引擎`n"
    } catch as err {
        ; 如果获取失败，显示错误提示和调试信息
        debugInfo .= "错误: " . err.Message . "`n"
        if (err.HasProp("File")) {
            debugInfo .= "错误位置: " . err.File . " 第 " . err.Line . " 行`n"
        }
        if (err.Message = "This local variable has not been assigned a value.") {
            debugInfo .= "`n提示: GetSortedSearchEngines函数可能未定义或未加载`n"
            debugInfo .= "请确保主脚本已正确加载所有模块`n"
        }
        MsgBox("AI选择面板调试信息:`n`n" . debugInfo, "调试信息", "Iconx")
        
        ErrorLabel := AIListPanelGUI.Add("Text", 
            "x0 y5 w" . AIListPanelWindowW . " h370 Center 0x200 Background" . AIListPanelColors.Background . 
            " c" . AIListPanelColors.Text, "加载失败: " . err.Message)
        return
    }
    
    ; 清空列表项数组
    AIListPanelItems := []
    
    ; 列表项尺寸
    ItemHeight := 45
    ItemPadding := 5
    IconSize := 32
    StartY := 30  ; 从搜索框下方开始（搜索框高度20 + 间距5 + 切换按钮区域5）
    
    ; 创建列表项
    Loop AIEngines.Length {
        index := A_Index
        engine := AIEngines[index]
        
        if (!IsObject(engine) || !engine.HasProp("Value")) {
            continue
        }
        
        y := StartY + (index - 1) * ItemHeight
        
        ; 创建列表项背景
        itemBg := AIListPanelGUI.Add("Text", 
            "x0 y" . y . " w" . AIListPanelWindowW . " h" . ItemHeight . " Background" . AIListPanelColors.ItemBg . " 0x200", "")
        
        ; 获取图标路径
        iconPath := GetSearchEngineIcon(engine.Value)
        engineName := engine.HasProp("Name") ? engine.Name : engine.Value
        
        ; 创建复选框（默认隐藏，当输入框有内容时显示）
        ; 复选框有背景色，在横排模式右上角更显眼
        ; 增大尺寸到18x18，更容易点击
        global AIListPanelCheckboxes
        checkboxX := ItemPadding
        checkboxY := y + (ItemHeight - 18) // 2
        checkbox := AIListPanelGUI.Add("Checkbox",
            "x" . checkboxX . " y" . checkboxY . " w18 h18 Background" . AIListPanelColors.ItemHover . " cWhite", "")
        checkbox.Visible := false  ; 默认隐藏
        checkbox.OnEvent("Click", CreateCheckboxClickHandler(engine.Value))
        AIListPanelCheckboxes[engine.Value] := checkbox
        
        ; 创建图标
        iconCtrl := 0
        if (iconPath != "" && FileExist(iconPath)) {
            try {
                ; 计算图标位置（复选框右侧，垂直居中）
                iconX := ItemPadding + 19  ; 复选框宽度18 + 间距1
                iconY := y + (ItemHeight - IconSize) // 2
                
                ; 创建图标控件
                iconCtrl := AIListPanelGUI.Add("Picture", 
                    "x" . iconX . " y" . iconY . " w" . IconSize . " h" . IconSize . " 0x200", iconPath)
                
                ; 绑定点击事件和右键菜单（使用闭包创建处理函数）
                try {
                    clickHandler := CreateAIListItemClickHandler(engine.Value, engineName, index)
                    contextMenuHandler := CreateAIListItemContextMenuHandler(engine.Value, engineName, index)
                    if (!IsObject(clickHandler)) {
                        throw Error("CreateAIListItemClickHandler返回的不是有效对象，类型: " . Type(clickHandler))
                    }
                    iconCtrl.OnEvent("Click", clickHandler)
                    iconCtrl.OnEvent("ContextMenu", contextMenuHandler)
                } catch as err {
                    ; 如果绑定失败，显示调试信息
                    errorMsg := "绑定图标事件失败:`n`n引擎: " . engineName . "`n错误: " . err.Message
                    if (err.HasProp("File")) {
                        errorMsg .= "`n错误位置: " . err.File . " 第 " . err.Line . " 行"
                    }
                    MsgBox(errorMsg, "调试信息", "Iconx")
                }
            } catch {
                iconCtrl := 0
            }
        }
        
        ; 创建名称标签
        nameX := ItemPadding + 19 + IconSize + ItemPadding  ; 复选框(18) + 间距(1) + 图标 + 间距
        nameY := y + (ItemHeight - 20) // 2
        nameLabel := AIListPanelGUI.Add("Text", 
            "x" . nameX . " y" . nameY . " w" . (AIListPanelWindowW - nameX - ItemPadding) . " h20 Left 0x200" .
            " c" . AIListPanelColors.Text . " BackgroundTrans", engineName)
        nameLabel.SetFont("s10", "Segoe UI")
        
        ; 绑定点击事件和右键菜单（使用闭包创建处理函数）
        try {
            clickHandler := CreateAIListItemClickHandler(engine.Value, engineName, index)
            contextMenuHandler := CreateAIListItemContextMenuHandler(engine.Value, engineName, index)
            if (!IsObject(clickHandler)) {
                throw Error("CreateAIListItemClickHandler返回的不是有效对象，类型: " . Type(clickHandler))
            }
            itemBg.OnEvent("Click", clickHandler)
            itemBg.OnEvent("ContextMenu", contextMenuHandler)
            nameLabel.OnEvent("Click", clickHandler)
            nameLabel.OnEvent("ContextMenu", contextMenuHandler)
        } catch as err {
            ; 如果绑定失败，显示调试信息
            errorMsg := "绑定事件失败:`n`n引擎: " . engineName . "`n错误: " . err.Message
            if (err.HasProp("File")) {
                errorMsg .= "`n错误位置: " . err.File . " 第 " . err.Line . " 行"
            }
            MsgBox(errorMsg, "调试信息", "Iconx")
        }
        
        ; 存储列表项信息
        AIListPanelItems.Push({
            bg: itemBg,
            icon: iconCtrl,
            name: nameLabel,
            checkbox: checkbox,
            engineValue: engine.Value,
            engineName: engineName,
            index: index
        })
    }
    
}

; ===================== 创建切换模式按钮处理函数 =====================
CreateToggleModeButtonHandler() {
    handler(*) {
        ToggleAIListPanelIconMode()
    }
    return handler
}

; ===================== 创建复选框点击处理函数 =====================
CreateCheckboxClickHandler(engineValue) {
    handler(*) {
        ToggleAISelection(engineValue)
    }
    return handler
}

; ===================== 创建列表项点击处理函数 =====================
CreateAIListItemClickHandler(engineValue, engineName, index) {
    ; 使用闭包函数捕获参数
    handler(*) {
        ; 新的交互逻辑：输入框有内容时，点击图标变成勾选；输入框为空时，不执行操作
        OnAIListItemClick(engineValue, engineName, index)
    }
    return handler
}

; ===================== 创建列表项右键菜单处理函数 =====================
CreateAIListItemContextMenuHandler(engineValue, engineName, index) {
    handler(*) {
        OnAIListItemContextMenu(engineValue, engineName, index)
    }
    return handler
}

; ===================== 列表项点击处理 =====================
OnAIListItemClick(engineValue, engineName, index) {
    global AIListPanelSearchInput
    
    ; 检查输入框是否有内容
    if (AIListPanelSearchInput != 0) {
        searchText := Trim(AIListPanelSearchInput.Value)
        if (searchText != "") {
            ; 输入框有内容时，点击图标变成勾选/取消勾选
            ToggleAISelection(engineValue)
            return
        }
    }
    
    ; 输入框为空时，不执行任何操作（或者可以保持原功能，根据需求）
    ; 如果需要保持原功能，取消下面的注释
    ; HideAIListPanel()
    ; ShowAIListPanelLoadingTip(engineName)
    ; OpenAIWithClipboard(engineValue, engineName)
}

; ===================== 列表项右键菜单处理 =====================
OnAIListItemContextMenu(engineValue, engineName, index) {
    ; 创建右键菜单
    contextMenu := Menu()
    contextMenu.Add("1. 浏览器打开", (*) => OpenAIInBrowser(engineValue, engineName))
    contextMenu.Add("2. 编辑模式", (*) => ShowAIEditMode(engineValue))
    contextMenu.Add("3. 提问" . engineName . "对应的AI", (*) => ShowAIInputDialog(engineValue, engineName))
    
    ; 显示菜单
    contextMenu.Show()
}

; ===================== 在浏览器中打开AI =====================
OpenAIInBrowser(engineValue, engineName) {
    HideAIListPanel()
    OpenAIInDefaultBrowser(engineValue, A_Clipboard)
}

; ===================== 显示AI编辑模式 =====================
ShowAIEditMode(engineValue) {
    ; TODO: 实现编辑模式，允许调整顺序和隐藏图标
    TrayTip("提示", "编辑模式功能开发中", "Iconi 1")
}

; ===================== 显示AI输入对话框 =====================
ShowAIInputDialog(engineValue, engineName) {
    ; 创建输入对话框
    inputGui := Gui("+AlwaysOnTop", "输入文字")
    inputGui.BackColor := AIListPanelColors.Background
    inputGui.SetFont("s10 c" . AIListPanelColors.Text, "Segoe UI")
    
    inputGui.Add("Text", "x10 y10 w200 h20", "请输入要搜索的内容：")
    inputEdit := inputGui.Add("Edit", "x10 y35 w200 h80 Multi", "")
    inputEdit.SetFont("s9", "Segoe UI")
    
    ; 确定按钮
    okBtn := inputGui.Add("Button", "x10 y125 w90 h30 Default", "确定")
    okBtn.OnEvent("Click", OnInputDialogOK.Bind(inputGui, inputEdit, engineValue))
    
    ; 取消按钮
    cancelBtn := inputGui.Add("Button", "x120 y125 w90 h30", "取消")
    cancelBtn.OnEvent("Click", (*) => inputGui.Destroy())
    
    inputGui.Show()
}

; ===================== 输入对话框确定按钮处理 =====================
OnInputDialogOK(inputGui, inputEdit, engineValue, *) {
    text := Trim(inputEdit.Value)
    inputGui.Destroy()
    if (text != "") {
        HideAIListPanel()
        OpenAIWithText(engineValue, text)
    }
}

; ===================== 打开AI并带入剪贴板内容 =====================
OpenAIWithClipboard(engineValue, engineName) {
    try {
        ; 保存当前剪贴板内容
        oldClipboard := A_Clipboard
        clipboardContent := Trim(A_Clipboard)
        hasClipboardContent := (clipboardContent != "")
        
        ; 检查Cursor是否运行
        if (!WinExist("ahk_exe Cursor.exe")) {
            ; Cursor未运行，直接使用默认浏览器打开
            OpenAIInDefaultBrowser(engineValue, clipboardContent)
            return
        }
        
        ; Cursor已运行，尝试使用Cursor浏览器
        try {
            ; 激活Cursor窗口
            WinActivate("ahk_exe Cursor.exe")
            WinWaitActive("ahk_exe Cursor.exe", , 3)
            Sleep(400)
            
            if (!WinActive("ahk_exe Cursor.exe")) {
                WinActivate("ahk_exe Cursor.exe")
                Sleep(400)
            }
            
            ; 发送Ctrl+Shift+B打开浏览器
            SendInput("^+b")
            Sleep(1200)
            
            ; 构建URL
            if (hasClipboardContent) {
                encodedContent := UriEncode(clipboardContent)
                searchURL := BuildAIEngineURL(engineValue, encodedContent)
            } else {
                searchURL := BuildAIEngineURL(engineValue, "")
            }
            
            ; 导航到URL
            A_Clipboard := searchURL
            Sleep(150)
            
            ; 聚焦地址栏并输入URL
            SendInput("^l")
            Sleep(300)
            SendInput("^v")
            Sleep(200)
            SendInput("{Enter}")
            
            ; 如果URL不支持参数，等待页面加载后粘贴到输入框
            if (hasClipboardContent && !AISupportsURLParams(engineValue)) {
                Sleep(3000)  ; 等待页面加载
                A_Clipboard := clipboardContent
                Sleep(150)
                SendInput("{Tab}")
                Sleep(200)
                SendInput("^v")
                Sleep(300)
                SendInput("{Enter}")
            }
            
            ; 恢复剪贴板
            Sleep(200)
            A_Clipboard := oldClipboard
            
            ; 隐藏加载提示
            HideAIListPanelLoadingTip()
        } catch as err {
            ; 如果Cursor浏览器打开失败，回退到默认浏览器
            OpenAIInDefaultBrowser(engineValue, clipboardContent)
        }
    } catch as err {
        ; 如果失败，使用默认浏览器
        try {
            OpenAIInDefaultBrowser(engineValue, clipboardContent)
        } catch {
            HideAIListPanelLoadingTip()
            TrayTip("打开AI失败: " . err.Message, "错误", "Iconx 2")
        }
    }
}

; ===================== 构建AI引擎URL =====================
BuildAIEngineURL(engineValue, encodedContent) {
    baseURL := ""
    
    switch engineValue {
        case "deepseek":
            baseURL := "https://chat.deepseek.com/"
            if (encodedContent != "") {
                baseURL .= "?q=" . encodedContent
            }
        case "yuanbao":
            baseURL := "https://yuanbao.tencent.com/"
            if (encodedContent != "") {
                baseURL .= "?q=" . encodedContent
            }
        case "doubao":
            baseURL := "https://www.doubao.com/chat/"
            if (encodedContent != "") {
                baseURL .= "?q=" . encodedContent
            }
        case "zhipu":
            baseURL := "https://chatglm.cn/main/search"
            if (encodedContent != "") {
                baseURL .= "?query=" . encodedContent
            }
        case "mita":
            baseURL := "https://metaso.cn/"
            if (encodedContent != "") {
                baseURL .= "?q=" . encodedContent
            }
        case "wenxin":
            baseURL := "https://yiyan.baidu.com/search"
            if (encodedContent != "") {
                baseURL .= "?query=" . encodedContent
            }
        case "qianwen":
            baseURL := "https://tongyi.aliyun.com/qianwen/chat"
            if (encodedContent != "") {
                baseURL .= "?intent=chat&query=" . encodedContent
            }
        case "kimi":
            baseURL := "https://kimi.moonshot.cn/_prefill_chat"
            if (encodedContent != "") {
                baseURL .= "?force_search=true&send_immediately=true&prefill_prompt=" . encodedContent
            }
        case "perplexity":
            baseURL := "https://www.perplexity.ai/search"
            if (encodedContent != "") {
                baseURL .= "?intent=qa&q=" . encodedContent
            }
        case "copilot":
            baseURL := "https://copilot.microsoft.com/chat"
            if (encodedContent != "") {
                baseURL .= "?q=" . encodedContent
            }
        case "chatgpt":
            baseURL := "https://chat.openai.com/"
            if (encodedContent != "") {
                baseURL .= "?q=" . encodedContent
            }
        case "grok":
            baseURL := "https://grok.com/"
            if (encodedContent != "") {
                baseURL .= "?q=" . encodedContent
            }
        case "you":
            baseURL := "https://you.com/search"
            if (encodedContent != "") {
                baseURL .= "?q=" . encodedContent
            }
        case "claude":
            baseURL := "https://claude.ai/new"
            if (encodedContent != "") {
                baseURL .= "?q=" . encodedContent
            }
        case "monica":
            baseURL := "https://monica.so/answers/"
            if (encodedContent != "") {
                baseURL .= "?q=" . encodedContent
            }
        case "webpilot":
            baseURL := "https://webpilot.ai/search"
            if (encodedContent != "") {
                baseURL .= "?q=" . encodedContent
            }
        default:
            baseURL := "https://chat.deepseek.com/"
            if (encodedContent != "") {
                baseURL .= "?q=" . encodedContent
            }
    }
    
    return baseURL
}

; ===================== 检查AI是否支持URL参数 =====================
AISupportsURLParams(engineValue) {
    ; 某些AI不支持URL参数，需要在页面加载后手动输入
    unsupportedEngines := ["chatgpt", "claude"]
    ; 检查engineValue是否在unsupportedEngines数组中
    for index, engine in unsupportedEngines {
        if (engine = engineValue) {
            return false
        }
    }
    return true
}

; ===================== 使用默认浏览器打开AI =====================
OpenAIInDefaultBrowser(engineValue, clipboardContent) {
    try {
        ; 构建URL
        if (clipboardContent != "" && Trim(clipboardContent) != "") {
            encodedContent := UriEncode(clipboardContent)
            searchURL := BuildAIEngineURL(engineValue, encodedContent)
        } else {
            searchURL := BuildAIEngineURL(engineValue, "")
        }
        
        ; 使用默认浏览器打开URL
        Run(searchURL)
        
        ; 隐藏加载提示
        HideAIListPanelLoadingTip()
        
        ; 显示提示信息（Cursor未运行时）
        if (!WinExist("ahk_exe Cursor.exe")) {
            engineDisplayName := GetAIEngineDisplayName(engineValue)
            TrayTip("已在浏览器中打开 " . engineDisplayName, "AI助手", "Iconi 1")
        }
    } catch as err {
        HideAIListPanelLoadingTip()
        TrayTip("打开浏览器失败: " . err.Message, "错误", "Iconx 2")
    }
}

; ===================== 获取AI引擎显示名称 =====================
GetAIEngineDisplayName(engineValue) {
    ; 根据引擎值返回显示名称
    nameMap := Map(
        "deepseek", "DeepSeek",
        "yuanbao", "元宝",
        "doubao", "豆包",
        "zhipu", "智谱",
        "mita", "秘塔",
        "wenxin", "文心一言",
        "qianwen", "通义千问",
        "kimi", "Kimi",
        "perplexity", "Perplexity",
        "copilot", "Copilot",
        "chatgpt", "ChatGPT",
        "grok", "Grok",
        "you", "You",
        "claude", "Claude",
        "monica", "Monica",
        "webpilot", "WebPilot"
    )
    
    return nameMap.Get(engineValue, engineValue)
}

; ===================== 显示加载提示 =====================
ShowAIListPanelLoadingTip(engineName) {
    global AIListPanelLoadingEngine
    AIListPanelLoadingEngine := engineName
    TrayTip("正在打开 " . engineName . "...", "AI助手", "Iconi 1")
}

; ===================== 隐藏加载提示 =====================
HideAIListPanelLoadingTip() {
    global AIListPanelLoadingEngine
    AIListPanelLoadingEngine := ""
    ToolTip()  ; 清除ToolTip
}

; ===================== 检测列表项悬停 =====================
AIListPanelCheckItemHover() {
    global AIListPanelGUI, AIListPanelItems, AIListPanelHoveredIndex, AIListPanelColors, AIListPanelIsVisible
    
    if (!AIListPanelIsVisible || AIListPanelGUI = 0) {
        return
    }
    
    try {
        MouseGetPos(&mx, &my, &winHwnd, &ctrlHwnd, 2)
        
        ; 检查鼠标是否在面板窗口内
        if (winHwnd != AIListPanelGUI.Hwnd) {
            ; 鼠标不在窗口内，恢复所有项的颜色
            if (AIListPanelHoveredIndex != 0) {
                RestoreAIListItemColor(AIListPanelHoveredIndex)
                AIListPanelHoveredIndex := 0
            }
            return
        }
        
        ; 查找鼠标下的列表项
        currentHover := 0
        for index, item in AIListPanelItems {
            if (IsObject(item) && item.HasProp("bg")) {
                item.bg.GetPos(&itemX, &itemY, &itemW, &itemH)
                if (mx >= itemX && mx <= itemX + itemW && my >= itemY && my <= itemY + itemH) {
                    currentHover := index
                    break
                }
            }
        }
        
        ; 如果悬停状态改变
        if (currentHover != AIListPanelHoveredIndex) {
            ; 恢复旧项的颜色
            if (AIListPanelHoveredIndex != 0) {
                RestoreAIListItemColor(AIListPanelHoveredIndex)
            }
            
            ; 高亮新项
            if (currentHover != 0) {
                HighlightAIListItem(currentHover)
            }
            
            AIListPanelHoveredIndex := currentHover
        }
    } catch {
    }
}

; ===================== 高亮列表项 =====================
HighlightAIListItem(index) {
    global AIListPanelItems, AIListPanelColors
    
    if (index > 0 && index <= AIListPanelItems.Length) {
        item := AIListPanelItems[index]
        if (IsObject(item) && item.HasProp("bg")) {
            try {
                item.bg.Opt("Background" . AIListPanelColors.ItemHover)
                if (item.HasProp("name") && item.name != 0) {
                    item.name.Opt("c" . AIListPanelColors.TextHover)
                }
            } catch {
            }
        }
    }
}

; ===================== 恢复列表项颜色 =====================
RestoreAIListItemColor(index) {
    global AIListPanelItems, AIListPanelColors
    
    if (index > 0 && index <= AIListPanelItems.Length) {
        item := AIListPanelItems[index]
        if (IsObject(item) && item.HasProp("bg")) {
            try {
                item.bg.Opt("Background" . AIListPanelColors.ItemBg)
                if (item.HasProp("name") && item.name != 0) {
                    item.name.Opt("c" . AIListPanelColors.Text)
                }
            } catch {
            }
        }
    }
}

; ===================== 窗口关闭事件 =====================
OnAIListPanelClose(*) {
    HideAIListPanel()
}

; ===================== 窗口大小改变事件 =====================
OnAIListPanelSize(GuiObj, MinMax, Width, Height) {
    global AIListPanelWindowW, AIListPanelWindowH, AIListPanelIconOnlyMode
    global AIListPanelIconModeW, AIListPanelIconModeH, AIListPanelIsResizing

    ; 防止循环触发
    if (AIListPanelIsResizing) {
        return
    }

    ; 根据模式保存不同的尺寸
    if (AIListPanelIconOnlyMode) {
        AIListPanelIconModeW := Width
        AIListPanelIconModeH := Height
    } else {
        AIListPanelWindowW := Width
        AIListPanelWindowH := Height
    }

    ; 只更新控件布局，不重新设置窗口大小（避免循环）
    RefreshAIListPanelControls(Width)

    ; 保存位置和尺寸
    SaveAIListPanelPosition()
}

; ===================== 窗口移动事件 =====================
; AutoHotkey v2 不支持 "Move" 事件，窗口位置通过定时器在 AIListPanelFollowToolbar 中更新

; ===================== 拖动相关消息处理 =====================
AIListPanelWM_LBUTTONDOWN(wParam, lParam, msg, hwnd) {
    global AIListPanelGUI, AIListPanelDragging, AIListPanelDragStartX, AIListPanelDragStartY
    global AIListPanelUserMoving

    ; 检查是否是AI面板窗口
    if (!AIListPanelGUI || AIListPanelGUI = 0 || hwnd != AIListPanelGUI.Hwnd) {
        return  ; 返回，让其他窗口处理消息
    }

    try {
        ; 检查是否点击在标题栏区域（y < 30），但不在按钮上
        MouseGetPos(&mx, &my, &winHwnd, &ctrlHwnd, 2)

        ; 确保鼠标在正确的窗口上
        if (winHwnd != AIListPanelGUI.Hwnd) {
            return
        }

        ; 检查是否点击在按钮上（如果是，不拖动）
        global AIListPanelToggleBtn
        if (AIListPanelToggleBtn != 0 && ctrlHwnd = AIListPanelToggleBtn.Hwnd) {
            return  ; 点击在按钮上，不拖动
        }

        AIListPanelGUI.GetPos(&wx, &wy, &ww, &wh)
        relX := mx - wx
        relY := my - wy

        ; 如果点击在窗口顶部区域（y < 30），开始拖动
        if (relY >= 0 && relY <= 30 && relX >= 0 && relX <= ww - 30) {
            AIListPanelDragging := true
            AIListPanelUserMoving := true  ; 标记用户正在移动窗口
            AIListPanelDragStartX := mx
            AIListPanelDragStartY := my
            PostMessage(0x00A1, 2, 0, AIListPanelGUI.Hwnd)  ; WM_NCLBUTTONDOWN, HTCAPTION
        }
    } catch {
        ; 如果出错，返回让系统处理
    }
    
    return  ; 返回，让消息继续传递
}

AIListPanelWM_MOUSEMOVE(wParam, lParam, msg, hwnd) {
    global AIListPanelGUI, AIListPanelDragging
    
    ; 检查是否是AI面板窗口
    if (!AIListPanelGUI || AIListPanelGUI = 0 || hwnd != AIListPanelGUI.Hwnd) {
        return  ; 返回，让其他窗口处理消息
    }
    
    ; 拖动处理由系统自动完成
    return
}

AIListPanelWM_LBUTTONUP(wParam, lParam, msg, hwnd) {
    global AIListPanelGUI, AIListPanelDragging, AIListPanelUserMoving

    ; 检查是否是AI面板窗口
    if (!AIListPanelGUI || AIListPanelGUI = 0 || hwnd != AIListPanelGUI.Hwnd) {
        return  ; 返回，让其他窗口处理消息
    }

    ; 拖动结束，保存位置
    if (AIListPanelDragging) {
        SaveAIListPanelPosition()
    }

    AIListPanelDragging := false

    ; 延迟1秒后重置用户移动标志（给用户时间松开鼠标）
    SetTimer(() => (AIListPanelUserMoving := false), -1000)

    return
}

; ===================== 切换图标模式 =====================
ToggleAIListPanelIconMode(*) {
    global AIListPanelIconOnlyMode, AIListPanelGUI, AIListPanelItems, AIListPanelToggleBtn
    global AIListPanelWindowX, AIListPanelWindowY, AIListPanelWindowW, AIListPanelWindowH
    global AIListPanelIconModeX, AIListPanelIconModeY, AIListPanelIconModeW, AIListPanelIconModeH
    
    ; 保存当前模式的位置和尺寸
    if (AIListPanelGUI != 0) {
        AIListPanelGUI.GetPos(&currentX, &currentY, &currentW, &currentH)
        if (AIListPanelIconOnlyMode) {
            ; 当前是横排模式，保存横排位置
            AIListPanelIconModeX := currentX
            AIListPanelIconModeY := currentY
            AIListPanelIconModeW := currentW
            AIListPanelIconModeH := currentH
        } else {
            ; 当前是竖排模式，保存竖排位置
            AIListPanelWindowX := currentX
            AIListPanelWindowY := currentY
            AIListPanelWindowW := currentW
            AIListPanelWindowH := currentH
        }
        SaveAIListPanelPosition()
    }
    
    ; 切换模式
    AIListPanelIconOnlyMode := !AIListPanelIconOnlyMode
    
    ; 更新切换按钮图标
    if (AIListPanelToggleBtn != 0) {
        AIListPanelToggleBtn.Text := AIListPanelIconOnlyMode ? "☰" : "☷"
    }
    
    ; 加载对应模式的位置和尺寸
    LoadAIListPanelPosition()
    
    ; 刷新布局（会自动应用保存的位置和尺寸）
    ; 重置上一次的宽度和行数，确保切换模式后重新计算
    global AIListPanelLastWidth, AIListPanelLastRows
    AIListPanelLastWidth := 0
    AIListPanelLastRows := 0
    RefreshAIListPanelLayout()
}

; ===================== 刷新控件布局（不改变窗口大小）=====================
RefreshAIListPanelControls(realTimeWidth := 0) {
    global AIListPanelGUI, AIListPanelItems, AIListPanelIconOnlyMode
    global AIListPanelWindowW, AIListPanelIconModeW
    global AIListPanelSearchInput, AIListPanelSearchBtn, AIListPanelToggleBtn

    if (!AIListPanelGUI || AIListPanelGUI = 0) {
        return
    }

    ; 获取当前窗口大小
    AIListPanelGUI.GetPos(&currentX, &currentY, &currentWidth, &currentHeight)

    ; 列表项尺寸
    ItemHeight := 45
    ItemPadding := 5
    IconSize := 32
    SearchBarHeight := 30
    Padding := 5

    ; 使用传入的宽度或当前窗口宽度
    if (realTimeWidth > 0) {
        currentWidth := realTimeWidth
    }

    try {
        if (AIListPanelIconOnlyMode) {
            ; 图标模式：横向排列（增大图标区域以容纳复选框）
            ItemSize := 60  ; 从50增大到60，给复选框更多空间
            ItemsPerRow := Floor((currentWidth - Padding * 2) / ItemSize)
            if (ItemsPerRow < 1) {
                ItemsPerRow := 1
            }

            ; 更新搜索框和按钮位置
            if (AIListPanelToggleBtn != 0) {
                AIListPanelToggleBtn.Move(5, 5, , )
            }
            if (AIListPanelSearchInput != 0) {
                AIListPanelSearchInput.Move(30, 5, currentWidth - 75, 20)
            }
            if (AIListPanelSearchBtn != 0) {
                AIListPanelSearchBtn.Move(currentWidth - 45, 5, , )
            }

            ; 横向排列图标（从搜索栏下方开始）
            for index, item in AIListPanelItems {
                row := Floor((index - 1) / ItemsPerRow)
                col := Mod(index - 1, ItemsPerRow)
                itemX := Padding + col * ItemSize
                itemY := SearchBarHeight + row * ItemSize

                if (IsObject(item) && item.HasProp("bg") && item.bg != 0) {
                    item.bg.Move(itemX, itemY, ItemSize, ItemSize)
                }
                ; 横排模式下复选框显示在图标右上角（如果搜索激活）
                if (IsObject(item) && item.HasProp("checkbox") && item.checkbox != 0) {
                    if (item.checkbox.Visible) {
                        ; 复选框放在右上角，更容易看到和点击
                        ; 复选框尺寸18x18，距离右边和上边各2px
                        checkboxX := itemX + ItemSize - 20
                        checkboxY := itemY + 2
                        item.checkbox.Move(checkboxX, checkboxY, 18, 18)
                    } else {
                        ; 隐藏时移到外面，避免误触
                        item.checkbox.Move(-100, -100, 18, 18)
                    }
                }
                if (IsObject(item) && item.HasProp("icon") && item.icon != 0) {
                    iconX := itemX + (ItemSize - IconSize) // 2
                    iconY := itemY + (ItemSize - IconSize) // 2
                    item.icon.Move(iconX, iconY, IconSize, IconSize)
                }
                if (IsObject(item) && item.HasProp("name") && item.name != 0) {
                    item.name.Visible := false
                }
            }
        } else {
            ; 完整模式：纵向排列
            ; 更新搜索框和按钮位置（搜索框使用完整宽度，与搜索按钮相切）
            if (AIListPanelToggleBtn != 0) {
                AIListPanelToggleBtn.Move(5, 5, , )
            }
            if (AIListPanelSearchInput != 0) {
                ; 搜索框使用完整宽度：切换按钮(25) + 搜索框 + 间距(5) + 搜索按钮(40) + 边距(5)
                searchInputWidth := currentWidth - 75  ; 完整宽度
                AIListPanelSearchInput.Move(30, 5, searchInputWidth, 20)
            }
            if (AIListPanelSearchBtn != 0) {
                ; 搜索按钮紧跟在搜索框后面（相切）
                searchInputWidth := currentWidth - 75
                searchBtnX := 30 + searchInputWidth + 5
                AIListPanelSearchBtn.Move(searchBtnX, 5, , )
            }

            ; 纵向排列列表项
            for index, item in AIListPanelItems {
                y := SearchBarHeight + (index - 1) * ItemHeight

                if (IsObject(item) && item.HasProp("bg") && item.bg != 0) {
                    item.bg.Move(0, y, currentWidth, ItemHeight)
                }
                if (IsObject(item) && item.HasProp("checkbox") && item.checkbox != 0) {
                    item.checkbox.Move(ItemPadding + 1, y + (ItemHeight - 18) // 2, 18, 18)
                }
                if (IsObject(item) && item.HasProp("icon") && item.icon != 0) {
                    iconX := ItemPadding + 19  ; 复选框宽度18 + 间距1
                    iconY := y + (ItemHeight - IconSize) // 2
                    item.icon.Move(iconX, iconY, IconSize, IconSize)
                }
                if (IsObject(item) && item.HasProp("name") && item.name != 0) {
                    nameX := ItemPadding + 19 + IconSize + ItemPadding  ; 复选框(18) + 间距(1) + 图标 + 间距
                    nameY := y + (ItemHeight - 20) // 2
                    item.name.Move(nameX, nameY, currentWidth - nameX - ItemPadding, 20)
                    item.name.Visible := true
                }
            }
        }
    } catch {
    }
}

; ===================== 刷新布局 =====================
RefreshAIListPanelLayout(realTimeWidth := 0) {
    global AIListPanelGUI, AIListPanelItems, AIListPanelIconOnlyMode
    global AIListPanelWindowW, AIListPanelWindowH, AIListPanelIconModeW, AIListPanelIconModeH
    global AIListPanelWindowX, AIListPanelWindowY, AIListPanelIconModeX, AIListPanelIconModeY
    global AIListPanelSearchInput, AIListPanelSearchBtn, AIListPanelToggleBtn
    global AIListPanelLastWidth, AIListPanelLastRows, AIListPanelIsResizing

    if (!AIListPanelGUI || AIListPanelGUI = 0) {
        return
    }
    
    ; 列表项尺寸（与 CreateAIListPanelGUI 中保持一致）
    ItemHeight := 45
    ItemPadding := 5
    IconSize := 32
    SearchBarHeight := 30  ; 搜索栏区域高度
    Padding := 5  ; 边距（两种模式都使用）
    
    try {
        if (AIListPanelIconOnlyMode) {
            ; 只显示图标模式：横向排列（增大图标区域以容纳复选框）
            ItemSize := 60  ; 从50增大到60，给复选框更多空间

            ; 优先使用实时传入的宽度参数，确保实时性
            if (realTimeWidth > 0) {
                currentWidth := realTimeWidth
            } else {
                ; 否则使用保存的宽度，如果没有则使用默认值
                currentWidth := AIListPanelIconModeW > 0 ? AIListPanelIconModeW : 400
            }

            ; 自适应排列：计算每行能放几个图标，确保整齐排列
            ItemsPerRow := Floor((currentWidth - Padding * 2) / ItemSize)  ; 计算每行能放几个
            if (ItemsPerRow < 1) {
                ItemsPerRow := 1
            }

            Rows := Ceil(AIListPanelItems.Length / ItemsPerRow)  ; 计算需要几行

            ; 优化高度计算：仅在宽度改变导致行数变化时才重新计算高度
            ; 如果宽度和行数都没变化，保持当前高度不变，避免抖动
            needRecalculateHeight := false
            if (currentWidth != AIListPanelLastWidth || Rows != AIListPanelLastRows) {
                needRecalculateHeight := true
                AIListPanelLastWidth := currentWidth
                AIListPanelLastRows := Rows
            }

            newWidth := currentWidth
            if (needRecalculateHeight) {
                newHeight := SearchBarHeight + Rows * ItemSize + Padding  ; 搜索栏高度 + 图标行数 * 图标大小 + 底部边距
            } else {
                ; 如果不需要重新计算，使用当前高度
                AIListPanelGUI.GetPos(, , , &currentHeight)
                newHeight := currentHeight
            }
            
            ; 更新窗口大小和位置（仅在需要时更新高度）
            AIListPanelIsResizing := true
            if (AIListPanelIconModeX > 0 || AIListPanelIconModeY > 0) {
                if (needRecalculateHeight) {
                    AIListPanelGUI.Move(AIListPanelIconModeX, AIListPanelIconModeY, newWidth, newHeight)
                } else {
                    ; 只更新宽度，保持高度不变
                    AIListPanelGUI.Move(AIListPanelIconModeX, AIListPanelIconModeY, newWidth)
                }
            } else {
                if (needRecalculateHeight) {
                    AIListPanelGUI.Move(, , newWidth, newHeight)
                } else {
                    AIListPanelGUI.Move(, , newWidth)
                }
            }
            AIListPanelIsResizing := false
            AIListPanelIconModeW := newWidth
            if (needRecalculateHeight) {
                AIListPanelIconModeH := newHeight
            }
            
            ; 更新搜索框和按钮位置
            if (AIListPanelToggleBtn != 0) {
                AIListPanelToggleBtn.Move(5, 5, , )
            }
            if (AIListPanelSearchInput != 0) {
                AIListPanelSearchInput.Move(30, 5, newWidth - 75, 20)
            }
            if (AIListPanelSearchBtn != 0) {
                AIListPanelSearchBtn.Move(newWidth - 45, 5, , )
            }
            
            ; 隐藏标题栏
            if (AIListPanelTitleBar != 0) {
                AIListPanelTitleBar.Visible := false
            }
            
            ; 横向排列图标（从搜索栏下方开始）- 自适应居中排列
            ; 计算每行的实际宽度，如果图标数量少于每行最大值，则居中显示
            actualItemsPerRow := ItemsPerRow
            if (AIListPanelItems.Length < ItemsPerRow) {
                actualItemsPerRow := AIListPanelItems.Length
            }
            
            ; 计算居中偏移量（如果图标数量少于每行最大值）
            centerOffset := 0
            if (AIListPanelItems.Length < ItemsPerRow && ItemsPerRow > 1 && Rows == 1) {
                totalWidth := actualItemsPerRow * ItemSize
                availableWidth := currentWidth - Padding * 2
                centerOffset := (availableWidth - totalWidth) // 2
            }
            
            for index, item in AIListPanelItems {
                row := Floor((index - 1) / ItemsPerRow)
                col := Mod(index - 1, ItemsPerRow)
                itemX := Padding + centerOffset + col * ItemSize
                itemY := SearchBarHeight + row * ItemSize

                if (IsObject(item) && item.HasProp("bg") && item.bg != 0) {
                    item.bg.Move(itemX, itemY, ItemSize, ItemSize)
                }
                ; 横排模式下复选框显示在图标右上角（如果搜索激活）
                if (IsObject(item) && item.HasProp("checkbox") && item.checkbox != 0) {
                    if (item.checkbox.Visible) {
                        ; 复选框放在右上角，更容易看到和点击
                        ; 复选框尺寸18x18，距离右边和上边各2px
                        checkboxX := itemX + ItemSize - 20
                        checkboxY := itemY + 2
                        item.checkbox.Move(checkboxX, checkboxY, 18, 18)
                    } else {
                        ; 隐藏时移到外面，避免误触
                        item.checkbox.Move(-100, -100, 18, 18)
                    }
                }
                if (IsObject(item) && item.HasProp("icon") && item.icon != 0) {
                    iconX := itemX + (ItemSize - IconSize) // 2
                    iconY := itemY + (ItemSize - IconSize) // 2
                    item.icon.Move(iconX, iconY, IconSize, IconSize)
                }
                if (IsObject(item) && item.HasProp("name") && item.name != 0) {
                    item.name.Visible := false
                }
            }
        } else {
            ; 完整模式：纵向排列，显示图标和名称
            ; 使用保存的尺寸，如果没有则使用默认值
            currentWidth := AIListPanelWindowW > 0 ? AIListPanelWindowW : 180
            newWidth := currentWidth

            ; 使用当前保存的高度（允许用户自由调整），如果没有则计算默认高度
            if (AIListPanelWindowH > 0) {
                ; 使用已保存的高度（用户可能已经调整过）
                newHeight := AIListPanelWindowH
                ; 确保高度不小于最小值
                minHeight := SearchBarHeight + AIListPanelItems.Length * ItemHeight + Padding
                if (newHeight < minHeight) {
                    newHeight := minHeight
                }
            } else {
                ; 首次显示，计算默认高度
                newHeight := SearchBarHeight + AIListPanelItems.Length * ItemHeight + Padding
            }
            
            ; 更新窗口大小和位置
            AIListPanelIsResizing := true
            if (AIListPanelWindowX > 0 || AIListPanelWindowY > 0) {
                AIListPanelGUI.Move(AIListPanelWindowX, AIListPanelWindowY, newWidth, newHeight)
            } else {
                AIListPanelGUI.Move(, , newWidth, newHeight)
            }
            AIListPanelIsResizing := false
            AIListPanelWindowW := newWidth
            AIListPanelWindowH := newHeight
            
            ; 更新搜索框和按钮位置（竖排模式下搜索框使用完整宽度，与搜索按钮相切）
            if (AIListPanelToggleBtn != 0) {
                AIListPanelToggleBtn.Move(5, 5, , )
            }
            if (AIListPanelSearchInput != 0) {
                ; 搜索框使用完整宽度：切换按钮(25) + 搜索框 + 间距(5) + 搜索按钮(40) + 边距(5)
                searchInputWidth := newWidth - 75  ; 完整宽度
                AIListPanelSearchInput.Move(30, 5, searchInputWidth, 20)
            }
            if (AIListPanelSearchBtn != 0) {
                ; 搜索按钮紧跟在搜索框后面（相切）
                searchInputWidth := newWidth - 75
                searchBtnX := 30 + searchInputWidth + 5
                AIListPanelSearchBtn.Move(searchBtnX, 5, , )
            }
            
            ; 隐藏标题栏
            if (AIListPanelTitleBar != 0) {
                AIListPanelTitleBar.Visible := false
            }
            
            ; 纵向排列（从搜索栏下方开始）
            for index, item in AIListPanelItems {
                y := SearchBarHeight + (index - 1) * ItemHeight
                
                if (IsObject(item) && item.HasProp("bg") && item.bg != 0) {
                    item.bg.Move(0, y, newWidth, ItemHeight)
                }
                if (IsObject(item) && item.HasProp("checkbox") && item.checkbox != 0) {
                    item.checkbox.Move(ItemPadding + 1, y + (ItemHeight - 18) // 2, 18, 18)
                }
                if (IsObject(item) && item.HasProp("icon") && item.icon != 0) {
                    iconX := ItemPadding + 19  ; 复选框宽度18 + 间距1
                    iconY := y + (ItemHeight - IconSize) // 2
                    item.icon.Move(iconX, iconY, IconSize, IconSize)
                }
                if (IsObject(item) && item.HasProp("name") && item.name != 0) {
                    nameX := ItemPadding + 19 + IconSize + ItemPadding  ; 复选框(18) + 间距(1) + 图标 + 间距
                    nameY := y + (ItemHeight - 20) // 2
                    item.name.Move(nameX, nameY, newWidth - nameX - ItemPadding, 20)
                    item.name.Visible := true
                }
            }
        }
        
        ; 保存位置和尺寸
        SaveAIListPanelPosition()
    } catch as err {
        MsgBox("刷新布局失败: " . err.Message, "错误", "Iconx")
    }
}

; ===================== 跟随悬浮工具栏移动（吸附逻辑） =====================
AIListPanelFollowToolbar() {
    global AIListPanelGUI, AIListPanelIsVisible, FloatingToolbarGUI, FloatingToolbarIsVisible
    global AIListPanelWindowW, AIListPanelWindowH, AIListPanelWindowX, AIListPanelWindowY
    global AIListPanelDragging, AIListPanelUserMoving

    ; 如果面板不可见或工具栏不可见，不处理
    if (!AIListPanelIsVisible || AIListPanelGUI = 0 || !FloatingToolbarIsVisible || FloatingToolbarGUI = 0) {
        return
    }

    ; 如果正在拖动或用户刚刚拖动结束，不自动跟随（允许自由拖动）
    if (AIListPanelDragging || AIListPanelUserMoving) {
        return
    }
    
    try {
        ; 获取工具栏位置
        FloatingToolbarGUI.GetPos(&toolbarX, &toolbarY, &toolbarW, &toolbarH)
        
        ; 获取面板当前位置
        AIListPanelGUI.GetPos(&panelX, &panelY, &panelW, &panelH)
        
        ; 计算工具栏的理想位置（工具栏上方）
        idealX := toolbarX
        idealY := toolbarY - AIListPanelWindowH
        
        ; 如果超出屏幕上方，显示在工具栏下方
        ScreenHeight := SysGet(1)
        if (idealY < 0) {
            idealY := toolbarY + toolbarH + 5
        }
        
        ; 计算面板中心点到工具栏理想位置的距离
        panelCenterX := panelX + panelW // 2
        panelCenterY := panelY + panelH // 2
        idealCenterX := idealX + panelW // 2
        idealCenterY := idealY + panelH // 2
        
        distanceX := Abs(panelCenterX - idealCenterX)
        distanceY := Abs(panelCenterY - idealCenterY)
        
        ; 吸附阈值：如果距离小于30像素，自动吸附到工具栏位置
        snapThreshold := 30
        
        if (distanceX <= snapThreshold && distanceY <= snapThreshold) {
            ; 靠近工具栏，自动吸附
            if (panelX != idealX || panelY != idealY) {
                AIListPanelGUI.Move(idealX, idealY)
                AIListPanelWindowX := idealX
                AIListPanelWindowY := idealY
                SaveAIListPanelPosition()
            }
        }
    } catch {
        ; 如果出错，静默处理
    }
}

; ===================== 保存AI面板位置和尺寸 =====================
SaveAIListPanelPosition() {
    global AIListPanelGUI, AIListPanelIconOnlyMode
    global AIListPanelWindowX, AIListPanelWindowY, AIListPanelWindowW, AIListPanelWindowH
    global AIListPanelIconModeX, AIListPanelIconModeY, AIListPanelIconModeW, AIListPanelIconModeH
    
    if (AIListPanelGUI = 0) {
        return
    }
    
    try {
        ; 获取当前窗口位置和尺寸
        AIListPanelGUI.GetPos(&x, &y, &w, &h)
        
        ; 根据模式保存到不同的变量和配置文件
        ConfigFile := A_ScriptDir . "\CursorShortcut.ini"
        
        if (AIListPanelIconOnlyMode) {
            ; 横排模式
            AIListPanelIconModeX := x
            AIListPanelIconModeY := y
            AIListPanelIconModeW := w
            AIListPanelIconModeH := h
            
            IniWrite(String(x), ConfigFile, "WindowPositions", "AIListPanel_IconMode_X")
            IniWrite(String(y), ConfigFile, "WindowPositions", "AIListPanel_IconMode_Y")
            IniWrite(String(w), ConfigFile, "WindowPositions", "AIListPanel_IconMode_W")
            IniWrite(String(h), ConfigFile, "WindowPositions", "AIListPanel_IconMode_H")
        } else {
            ; 竖排模式
            AIListPanelWindowX := x
            AIListPanelWindowY := y
            AIListPanelWindowW := w
            AIListPanelWindowH := h
            
            IniWrite(String(x), ConfigFile, "WindowPositions", "AIListPanel_X")
            IniWrite(String(y), ConfigFile, "WindowPositions", "AIListPanel_Y")
            IniWrite(String(w), ConfigFile, "WindowPositions", "AIListPanel_W")
            IniWrite(String(h), ConfigFile, "WindowPositions", "AIListPanel_H")
        }
    } catch {
        ; 保存失败时静默处理
    }
}

; ===================== 加载AI面板位置和尺寸 =====================
LoadAIListPanelPosition() {
    global AIListPanelIconOnlyMode
    global AIListPanelWindowX, AIListPanelWindowY, AIListPanelWindowW, AIListPanelWindowH
    global AIListPanelIconModeX, AIListPanelIconModeY, AIListPanelIconModeW, AIListPanelIconModeH
    
    try {
        ConfigFile := A_ScriptDir . "\CursorShortcut.ini"
        ScreenWidth := SysGet(0)
        ScreenHeight := SysGet(1)
        
        if (AIListPanelIconOnlyMode) {
            ; 横排模式：读取横排模式的位置和尺寸
            savedX := IniRead(ConfigFile, "WindowPositions", "AIListPanel_IconMode_X", "")
            savedY := IniRead(ConfigFile, "WindowPositions", "AIListPanel_IconMode_Y", "")
            savedW := IniRead(ConfigFile, "WindowPositions", "AIListPanel_IconMode_W", "")
            savedH := IniRead(ConfigFile, "WindowPositions", "AIListPanel_IconMode_H", "")
            
            if (savedX != "" && savedY != "" && savedX != "ERROR" && savedY != "ERROR") {
                AIListPanelIconModeX := Integer(savedX)
                AIListPanelIconModeY := Integer(savedY)
                
                if (savedW != "" && savedW != "ERROR") {
                    AIListPanelIconModeW := Integer(savedW)
                } else {
                    AIListPanelIconModeW := 400  ; 默认宽度
                }
                if (savedH != "" && savedH != "ERROR") {
                    AIListPanelIconModeH := Integer(savedH)
                } else {
                    AIListPanelIconModeH := 100  ; 默认高度
                }
                
                ; 验证位置是否在屏幕范围内
                if (AIListPanelIconModeX < 0 || AIListPanelIconModeX > ScreenWidth - AIListPanelIconModeW) {
                    AIListPanelIconModeX := 0
                }
                if (AIListPanelIconModeY < 0 || AIListPanelIconModeY > ScreenHeight - AIListPanelIconModeH) {
                    AIListPanelIconModeY := 0
                }
            } else {
                AIListPanelIconModeX := 0
                AIListPanelIconModeY := 0
                AIListPanelIconModeW := 400
                AIListPanelIconModeH := 100
            }
        } else {
            ; 竖排模式：读取竖排模式的位置和尺寸
            savedX := IniRead(ConfigFile, "WindowPositions", "AIListPanel_X", "")
            savedY := IniRead(ConfigFile, "WindowPositions", "AIListPanel_Y", "")
            savedW := IniRead(ConfigFile, "WindowPositions", "AIListPanel_W", "")
            savedH := IniRead(ConfigFile, "WindowPositions", "AIListPanel_H", "")
            
            if (savedX != "" && savedY != "" && savedX != "ERROR" && savedY != "ERROR") {
                AIListPanelWindowX := Integer(savedX)
                AIListPanelWindowY := Integer(savedY)
                
                if (savedW != "" && savedW != "ERROR") {
                    AIListPanelWindowW := Integer(savedW)
                } else {
                    AIListPanelWindowW := 180  ; 默认宽度
                }
                if (savedH != "" && savedH != "ERROR") {
                    AIListPanelWindowH := Integer(savedH)
                } else {
                    AIListPanelWindowH := 400  ; 默认高度
                }
                
                ; 验证位置是否在屏幕范围内
                if (AIListPanelWindowX < 0 || AIListPanelWindowX > ScreenWidth - AIListPanelWindowW) {
                    AIListPanelWindowX := 0
                }
                if (AIListPanelWindowY < 0 || AIListPanelWindowY > ScreenHeight - AIListPanelWindowH) {
                    AIListPanelWindowY := 0
                }
            } else {
                AIListPanelWindowX := 0
                AIListPanelWindowY := 0
                AIListPanelWindowW := 180
                AIListPanelWindowH := 400
            }
        }
    } catch {
        ; 加载失败时使用默认值
        if (AIListPanelIconOnlyMode) {
            AIListPanelIconModeX := 0
            AIListPanelIconModeY := 0
            AIListPanelIconModeW := 400
            AIListPanelIconModeH := 100
        } else {
            AIListPanelWindowX := 0
            AIListPanelWindowY := 0
            AIListPanelWindowW := 180
            AIListPanelWindowH := 400
        }
    }
}

; ===================== 隐藏到屏幕边缘 =====================
MinimizeAIListPanelToEdge() {
    global AIListPanelGUI, AIListPanelIsVisible, AIListPanelIsMinimized
    global AIListPanelWindowX, AIListPanelWindowY, AIListPanelWindowW, AIListPanelWindowH
    
    if (!AIListPanelIsVisible || AIListPanelGUI = 0) {
        return
    }
    
    ; 获取当前窗口位置
    AIListPanelGUI.GetPos(&currentX, &currentY, &currentW, &currentH)
    
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
    AIListPanelGUI.Move(targetX, targetY)
    AIListPanelWindowX := targetX
    AIListPanelWindowY := targetY
    AIListPanelIsMinimized := true
    
    ; 保存位置
    SaveAIListPanelPosition()
}

; ===================== 恢复AI面板 =====================
RestoreAIListPanel() {
    global AIListPanelIsMinimized
    AIListPanelIsMinimized := false
    ; 位置已保存，显示时会自动加载
}

; ===================== 输入框内容变化处理 =====================
OnAIListPanelSearchInputChange(*) {
    global AIListPanelSearchInput, AIListPanelCheckboxes, AIListPanelItems
    
    if (AIListPanelSearchInput = 0) {
        return
    }
    
    searchText := Trim(AIListPanelSearchInput.Value)
    hasText := (searchText != "")
    
    ; 显示或隐藏所有复选框
    for engineValue, checkbox in AIListPanelCheckboxes {
        if (checkbox != 0) {
            checkbox.Visible := hasText
        }
    }

    ; 如果有文本，刷新控件布局以确保复选框在正确位置（特别是横排模式）
    if (hasText) {
        RefreshAIListPanelControls()
    }

    ; 如果没有文本，清除所有选择
    if (!hasText) {
        global AIListPanelSelectedEngines
        AIListPanelSelectedEngines := []
        RefreshAIListPanelSelection()
        ; 也刷新布局，将隐藏的复选框移到外面
        RefreshAIListPanelControls()
    }
}

; 注意：AutoHotkey v2的Edit控件不支持KeyDown事件
; 回车键功能通过窗口级别的Hotkey实现（在ShowAIListPanel中设置）

; ===================== 搜索功能 =====================
OnAIListPanelSearch(*) {
    global AIListPanelSearchInput, AIListPanelSelectedEngines
    
    if (AIListPanelSearchInput = 0) {
        return
    }
    
    searchText := Trim(AIListPanelSearchInput.Value)
    if (searchText = "") {
        ; 如果没有搜索文本，清除选择
        AIListPanelSelectedEngines := []
        RefreshAIListPanelSelection()
        TrayTip("提示", "请输入搜索内容", "Iconi 1")
        return
    }
    
    ; 执行搜索并打开选中的AI
    if (AIListPanelSelectedEngines.Length > 0) {
        OpenSelectedAIs(searchText)
        ; 清空输入框
        AIListPanelSearchInput.Value := ""
    } else {
        TrayTip("提示", "请先勾选AI图标进行多选", "Iconi 1")
    }
}

; ===================== 打开选中的AI =====================
OpenSelectedAIs(searchText := "") {
    global AIListPanelSelectedEngines
    
    if (AIListPanelSelectedEngines.Length = 0) {
        return
    }
    
    ; 隐藏面板
    HideAIListPanel()
    
    ; 为每个选中的AI打开浏览器
    for index, engineValue in AIListPanelSelectedEngines {
        if (searchText != "") {
            ; 如果有搜索文本，使用搜索文本
            OpenAIWithText(engineValue, searchText)
        } else {
            ; 否则使用剪贴板内容
            OpenAIWithClipboard(engineValue, GetAIEngineDisplayName(engineValue))
        }
        ; 稍微延迟，避免同时打开太多窗口
        if (index < AIListPanelSelectedEngines.Length) {
            Sleep(200)
        }
    }
    
    ; 清空选择
    AIListPanelSelectedEngines := []
}

; ===================== 使用文本打开AI =====================
OpenAIWithText(engineValue, text) {
    try {
        ; 检查Cursor是否运行
        if (!WinExist("ahk_exe Cursor.exe")) {
            ; Cursor未运行，使用默认浏览器
            OpenAIInDefaultBrowser(engineValue, text)
            return
        }
        
        ; Cursor已运行，使用Cursor浏览器
        WinActivate("ahk_exe Cursor.exe")
        WinWaitActive("ahk_exe Cursor.exe", , 3)
        Sleep(400)
        
        ; 发送Ctrl+Shift+B打开浏览器
        SendInput("^+b")
        Sleep(1200)
        
        ; 构建URL
        encodedContent := UriEncode(text)
        searchURL := BuildAIEngineURL(engineValue, encodedContent)
        
        ; 导航到URL
        A_Clipboard := searchURL
        Sleep(150)
        SendInput("^l")
        Sleep(300)
        SendInput("^v")
        Sleep(200)
        SendInput("{Enter}")
        
        ; 如果URL不支持参数，等待页面加载后粘贴
        if (!AISupportsURLParams(engineValue)) {
            Sleep(3000)
            A_Clipboard := text
            Sleep(150)
            SendInput("{Tab}")
            Sleep(200)
            SendInput("^v")
            Sleep(300)
            SendInput("{Enter}")
        }
    } catch as err {
        ; 如果失败，使用默认浏览器
        OpenAIInDefaultBrowser(engineValue, text)
    }
}

; ===================== 刷新选择状态 =====================
RefreshAIListPanelSelection() {
    global AIListPanelItems, AIListPanelSelectedEngines, AIListPanelColors, AIListPanelCheckboxes
    
    for index, item in AIListPanelItems {
        if (IsObject(item) && item.HasProp("engineValue")) {
            ; 检查是否被选中
            isSelected := false
            for idx, selectedValue in AIListPanelSelectedEngines {
                if (selectedValue = item.engineValue) {
                    isSelected := true
                    break
                }
            }
            
            ; 更新复选框状态
            if (item.HasProp("checkbox") && item.checkbox != 0) {
                item.checkbox.Value := isSelected ? 1 : 0
            }
            
            ; 更新背景色
            if (isSelected) {
                if (item.HasProp("bg") && item.bg != 0) {
                    item.bg.Opt("Background" . AIListPanelColors.ItemActive)
                }
            } else {
                if (item.HasProp("bg") && item.bg != 0) {
                    item.bg.Opt("Background" . AIListPanelColors.ItemBg)
                }
            }
        }
    }
}

; ===================== 切换AI选择状态 =====================
ToggleAISelection(engineValue) {
    global AIListPanelSelectedEngines, AIListPanelCheckboxes
    
    ; 查找是否已选中
    foundIndex := 0
    for index, value in AIListPanelSelectedEngines {
        if (value = engineValue) {
            foundIndex := index
            break
        }
    }
    
    if (foundIndex > 0) {
        ; 取消选择
        AIListPanelSelectedEngines.RemoveAt(foundIndex)
        if (AIListPanelCheckboxes.Has(engineValue)) {
            AIListPanelCheckboxes[engineValue].Value := 0
        }
    } else {
        ; 添加选择
        AIListPanelSelectedEngines.Push(engineValue)
        if (AIListPanelCheckboxes.Has(engineValue)) {
            AIListPanelCheckboxes[engineValue].Value := 1
        }
    }
    
    RefreshAIListPanelSelection()
}

; ===================== 初始化 =====================
InitAIListPanel() {
    ; 初始化完成，可以调用 ShowAIListPanel() 显示面板
}
