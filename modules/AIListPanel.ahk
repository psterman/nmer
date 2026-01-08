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
global AIListPanelWindowX := 0  ; 窗口X坐标
global AIListPanelWindowY := 0  ; 窗口Y坐标
global AIListPanelWindowW := 250  ; 窗口宽度
global AIListPanelWindowH := 400  ; 窗口高度
global AIListPanelTitleBar := 0  ; 标题栏控件
global AIListPanelCloseBtn := 0  ; 关闭按钮控件
global AIListPanelToggleBtn := 0  ; 切换模式按钮控件

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
    global AIListPanelGUI, AIListPanelIsVisible
    
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
        
        ; 获取悬浮工具栏位置，在工具栏上方显示
        global FloatingToolbarGUI, FloatingToolbarWindowX, FloatingToolbarWindowY
        if (FloatingToolbarGUI != 0) {
            try {
                FloatingToolbarGUI.GetPos(&toolbarX, &toolbarY, &toolbarW, &toolbarH)
                ; 在工具栏上方显示
                panelX := toolbarX
                panelY := toolbarY - 400  ; 面板高度约400，显示在工具栏上方
                ; 如果超出屏幕上方，则显示在工具栏下方
                ScreenHeight := SysGet(1)
                if (panelY < 0) {
                    panelY := toolbarY + toolbarH + 5
                }
                debugInfo .= "步骤4: 工具栏位置获取成功`n"
            } catch as err {
                debugInfo .= "步骤4: 工具栏位置获取失败 - " . err.Message . "`n"
                ; 如果工具栏不存在，显示在屏幕中央
                ScreenWidth := SysGet(0)
                ScreenHeight := SysGet(1)
                panelX := (ScreenWidth - 250) // 2
                panelY := (ScreenHeight - 400) // 2
            }
        } else {
            ; 如果工具栏不存在，显示在屏幕中央
            ScreenWidth := SysGet(0)
            ScreenHeight := SysGet(1)
            panelX := (ScreenWidth - 250) // 2
            panelY := (ScreenHeight - 400) // 2
            debugInfo .= "步骤4: 使用屏幕中央位置`n"
        }
        
        debugInfo .= "步骤5: 准备显示窗口，位置: x=" . panelX . ", y=" . panelY . "`n"
        
        ; 显示GUI
        try {
            if (AIListPanelGUI = 0) {
                throw Error("GUI对象为空")
            }
            AIListPanelGUI.Show("x" . panelX . " y" . panelY . " w250 h400")
            AIListPanelIsVisible := true
            debugInfo .= "步骤6: GUI显示成功`n"
        } catch as err {
            debugInfo .= "步骤6: GUI显示失败 - " . err.Message . "`n"
            MsgBox("AI选择面板调试信息:`n`n" . debugInfo, "调试信息", "Iconx")
            return
        }
        
        debugInfo .= "步骤7: 启动悬停检测定时器`n"
        
        ; 启动定时器用于悬停效果检测
        try {
            SetTimer(AIListPanelCheckItemHover, 50)
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
    global AIListPanelGUI, AIListPanelIsVisible
    
    if (AIListPanelGUI != 0) {
        AIListPanelGUI.Hide()
        AIListPanelIsVisible := false
        
        ; 停止定时器
        SetTimer(AIListPanelCheckItemHover, 0)
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
    global AIListPanelGUI, AIListPanelColors, AIListPanelItems
    
    ; 如果已存在，先销毁
    if (AIListPanelGUI != 0) {
        try {
            AIListPanelGUI.Destroy()
        } catch {
        }
    }
    
    ; 创建GUI（有边框、置顶、可调整大小）
    AIListPanelGUI := Gui("+AlwaysOnTop +Resize -MaximizeBox -MinimizeBox", "AI助手选择")
    AIListPanelGUI.BackColor := AIListPanelColors.Background
    AIListPanelGUI.SetFont("s10 c" . AIListPanelColors.Text, "Segoe UI")
    
    ; 窗口事件
    AIListPanelGUI.OnEvent("Close", OnAIListPanelClose)
    AIListPanelGUI.OnEvent("Size", OnAIListPanelSize)
    
    ; 监听拖动消息
    OnMessage(0x0201, AIListPanelWM_LBUTTONDOWN)  ; WM_LBUTTONDOWN
    OnMessage(0x0200, AIListPanelWM_MOUSEMOVE)  ; WM_MOUSEMOVE
    OnMessage(0x0202, AIListPanelWM_LBUTTONUP)  ; WM_LBUTTONUP
    
    ; 创建标题栏（可拖动）
    global AIListPanelTitleBar, AIListPanelCloseBtn, AIListPanelToggleBtn
    AIListPanelTitleBar := AIListPanelGUI.Add("Text", 
        "x0 y0 w" . AIListPanelWindowW . " h30 Center 0x200 Background" . AIListPanelColors.ItemBg . 
        " c" . AIListPanelColors.TextHover, "选择AI助手")
    AIListPanelTitleBar.SetFont("s11 Bold", "Segoe UI")
    
    ; 创建关闭按钮（右上角）
    AIListPanelCloseBtn := AIListPanelGUI.Add("Text", 
        "x" . (AIListPanelWindowW - 25) . " y5 w20 h20 Center 0x200 Background" . AIListPanelColors.ItemHover . 
        " c" . AIListPanelColors.TextHover, "×")
    AIListPanelCloseBtn.SetFont("s14 Bold", "Segoe UI")
    try {
        AIListPanelCloseBtn.OnEvent("Click", CreateCloseButtonHandler())
    } catch as err {
        MsgBox("关闭按钮绑定失败: " . err.Message, "错误", "Iconx")
    }
    
    ; 创建切换显示模式按钮（只显示图标/显示完整）
    AIListPanelToggleBtn := AIListPanelGUI.Add("Text", 
        "x" . (AIListPanelWindowW - 50) . " y5 w20 h20 Center 0x200 Background" . AIListPanelColors.ItemHover . 
        " c" . AIListPanelColors.TextHover, "◐")
    AIListPanelToggleBtn.SetFont("s12", "Segoe UI")
    try {
        AIListPanelToggleBtn.OnEvent("Click", CreateToggleModeButtonHandler())
    } catch as err {
        MsgBox("切换按钮绑定失败: " . err.Message, "错误", "Iconx")
    }
    
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
                "x0 y30 w250 h370 Center 0x200 Background" . AIListPanelColors.Background . 
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
            "x0 y30 w250 h370 Center 0x200 Background" . AIListPanelColors.Background . 
            " c" . AIListPanelColors.Text, "加载失败: " . err.Message)
        return
    }
    
    ; 清空列表项数组
    AIListPanelItems := []
    
    ; 列表项尺寸
    ItemHeight := 45
    ItemPadding := 5
    IconSize := 32
    StartY := 30
    
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
            "x0 y" . y . " w250 h" . ItemHeight . " Background" . AIListPanelColors.ItemBg . " 0x200", "")
        
        ; 获取图标路径
        iconPath := GetSearchEngineIcon(engine.Value)
        engineName := engine.HasProp("Name") ? engine.Name : engine.Value
        
        ; 创建图标
        iconCtrl := 0
        if (iconPath != "" && FileExist(iconPath)) {
            try {
                ; 计算图标位置（左侧，垂直居中）
                iconX := ItemPadding
                iconY := y + (ItemHeight - IconSize) // 2
                
                ; 创建图标控件
                iconCtrl := AIListPanelGUI.Add("Picture", 
                    "x" . iconX . " y" . iconY . " w" . IconSize . " h" . IconSize . " 0x200", iconPath)
                
                ; 绑定点击事件（使用闭包创建处理函数）
                try {
                    handler := CreateAIListItemClickHandler(engine.Value, engineName, index)
                    if (!IsObject(handler)) {
                        throw Error("CreateAIListItemClickHandler返回的不是有效对象，类型: " . Type(handler))
                    }
                    iconCtrl.OnEvent("Click", handler)
                } catch as err {
                    ; 如果绑定失败，显示调试信息
                    errorMsg := "绑定图标点击事件失败:`n`n引擎: " . engineName . "`n错误: " . err.Message
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
        nameX := ItemPadding + IconSize + ItemPadding
        nameY := y + (ItemHeight - 20) // 2
        nameLabel := AIListPanelGUI.Add("Text", 
            "x" . nameX . " y" . nameY . " w" . (250 - nameX - ItemPadding) . " h20 Left 0x200" .
            " c" . AIListPanelColors.Text . " BackgroundTrans", engineName)
        nameLabel.SetFont("s10", "Segoe UI")
        
        ; 绑定点击事件（使用闭包创建处理函数）
        try {
            handler := CreateAIListItemClickHandler(engine.Value, engineName, index)
            if (!IsObject(handler)) {
                throw Error("CreateAIListItemClickHandler返回的不是有效对象，类型: " . Type(handler))
            }
            itemBg.OnEvent("Click", handler)
            nameLabel.OnEvent("Click", handler)
        } catch as err {
            ; 如果绑定失败，显示调试信息
            errorMsg := "绑定点击事件失败:`n`n引擎: " . engineName . "`n错误: " . err.Message
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
            engineValue: engine.Value,
            engineName: engineName,
            index: index
        })
    }
    
    ; 关闭按钮已在标题栏创建时添加
}

; ===================== 创建关闭按钮处理函数 =====================
CreateCloseButtonHandler() {
    handler(*) {
        HideAIListPanel()
    }
    return handler
}

; ===================== 创建切换模式按钮处理函数 =====================
CreateToggleModeButtonHandler() {
    handler(*) {
        ToggleAIListPanelIconMode()
    }
    return handler
}

; ===================== 创建列表项点击处理函数 =====================
CreateAIListItemClickHandler(engineValue, engineName, index) {
    ; 使用闭包函数捕获参数
    handler(*) {
        OnAIListItemClick(engineValue, engineName, index)
    }
    return handler
}

; ===================== 列表项点击处理 =====================
OnAIListItemClick(engineValue, engineName, index) {
    global AIListPanelLoadingEngine
    
    ; 隐藏面板
    HideAIListPanel()
    
    ; 显示加载提示
    AIListPanelLoadingEngine := engineName
    ShowAIListPanelLoadingTip(engineName)
    
    ; 执行打开AI的操作
    OpenAIWithClipboard(engineValue, engineName)
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
            try {
                global CursorPath
                if (IsSet(CursorPath) && CursorPath != "" && FileExist(CursorPath)) {
                    Run(CursorPath)
                    Sleep(1500)
                } else {
                    ; 如果无法启动，使用默认浏览器
                    OpenAIInDefaultBrowser(engineValue, clipboardContent)
                    return
                }
            } catch {
                OpenAIInDefaultBrowser(engineValue, clipboardContent)
                return
            }
        }
        
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
        if (clipboardContent != "") {
            encodedContent := UriEncode(clipboardContent)
            searchURL := BuildAIEngineURL(engineValue, encodedContent)
        } else {
            searchURL := BuildAIEngineURL(engineValue, "")
        }
        Run(searchURL)
        HideAIListPanelLoadingTip()
    } catch {
        HideAIListPanelLoadingTip()
    }
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
    
    AIListPanelWindowW := Width
    AIListPanelWindowH := Height
    
    ; 如果窗口大小改变，更新布局
    if (AIListPanelIconOnlyMode) {
        RefreshAIListPanelLayout()
    }
}

; ===================== 拖动相关消息处理 =====================
AIListPanelWM_LBUTTONDOWN(wParam, lParam, msg, hwnd) {
    global AIListPanelGUI, AIListPanelDragging, AIListPanelDragStartX, AIListPanelDragStartY
    
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
        global AIListPanelCloseBtn, AIListPanelToggleBtn
        if ((AIListPanelCloseBtn != 0 && ctrlHwnd = AIListPanelCloseBtn.Hwnd) || 
            (AIListPanelToggleBtn != 0 && ctrlHwnd = AIListPanelToggleBtn.Hwnd)) {
            return  ; 点击在按钮上，不拖动
        }
        
        AIListPanelGUI.GetPos(&wx, &wy, &ww, &wh)
        relX := mx - wx
        relY := my - wy
        
        ; 如果点击在标题栏区域（y < 30），开始拖动
        if (relY >= 0 && relY <= 30 && relX >= 0 && relX <= ww - 50) {
            AIListPanelDragging := true
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
    global AIListPanelGUI, AIListPanelDragging
    
    ; 检查是否是AI面板窗口
    if (!AIListPanelGUI || AIListPanelGUI = 0 || hwnd != AIListPanelGUI.Hwnd) {
        return  ; 返回，让其他窗口处理消息
    }
    
    AIListPanelDragging := false
    return
}

; ===================== 切换图标模式 =====================
ToggleAIListPanelIconMode(*) {
    global AIListPanelIconOnlyMode, AIListPanelGUI, AIListPanelItems
    
    AIListPanelIconOnlyMode := !AIListPanelIconOnlyMode
    
    ; 刷新布局
    RefreshAIListPanelLayout()
}

; ===================== 刷新布局 =====================
RefreshAIListPanelLayout() {
    global AIListPanelGUI, AIListPanelItems, AIListPanelIconOnlyMode, AIListPanelWindowW, AIListPanelWindowH
    
    if (!AIListPanelGUI || AIListPanelGUI = 0) {
        return
    }
    
    try {
        if (AIListPanelIconOnlyMode) {
            ; 只显示图标模式：缩小窗口，只显示图标
            newWidth := 60  ; 只显示图标，宽度60
            newHeight := 30 + AIListPanelItems.Length * 50  ; 标题栏30 + 每个图标50
            
            ; 更新窗口大小
            AIListPanelGUI.Move(, , newWidth, newHeight)
            AIListPanelWindowW := newWidth
            AIListPanelWindowH := newHeight
            
            ; 隐藏名称标签
            for index, item in AIListPanelItems {
                if (IsObject(item) && item.HasProp("name") && item.name != 0) {
                    item.name.Visible := false
                }
                if (IsObject(item) && item.HasProp("bg") && item.bg != 0) {
                    ; 调整背景宽度
                    item.bg.Move(, , newWidth, 50)
                }
            }
        } else {
            ; 完整模式：显示图标和名称
            newWidth := 250
            newHeight := 30 + AIListPanelItems.Length * 45
            
            ; 更新窗口大小
            AIListPanelGUI.Move(, , newWidth, newHeight)
            AIListPanelWindowW := newWidth
            AIListPanelWindowH := newHeight
            
            ; 显示名称标签
            for index, item in AIListPanelItems {
                if (IsObject(item) && item.HasProp("name") && item.name != 0) {
                    item.name.Visible := true
                }
                if (IsObject(item) && item.HasProp("bg") && item.bg != 0) {
                    ; 调整背景宽度
                    item.bg.Move(, , newWidth, 45)
                }
            }
        }
        
        ; 更新标题栏和按钮位置
        UpdateAIListPanelTitleBar()
    } catch as err {
        MsgBox("刷新布局失败: " . err.Message, "错误", "Iconx")
    }
}

; ===================== 更新标题栏 =====================
UpdateAIListPanelTitleBar() {
    global AIListPanelGUI, AIListPanelWindowW, AIListPanelIconOnlyMode
    global AIListPanelTitleBar, AIListPanelCloseBtn, AIListPanelToggleBtn
    
    if (!AIListPanelGUI || AIListPanelGUI = 0) {
        return
    }
    
    try {
        ; 更新标题栏宽度
        if (AIListPanelTitleBar != 0) {
            AIListPanelTitleBar.Move(, , AIListPanelWindowW, 30)
        }
        
        ; 更新关闭按钮位置
        if (AIListPanelCloseBtn != 0) {
            AIListPanelCloseBtn.Move(AIListPanelWindowW - 25, , , )
        }
        
        ; 更新切换按钮位置
        if (AIListPanelToggleBtn != 0) {
            AIListPanelToggleBtn.Move(AIListPanelWindowW - 50, , , )
        }
    } catch {
    }
}

; ===================== 初始化 =====================
InitAIListPanel() {
    ; 初始化完成，可以调用 ShowAIListPanel() 显示面板
}
