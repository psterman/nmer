; ScreenshotWorkflow.ahk — 截图业务流程（智能菜单、区域截图、悬浮按钮等，由主脚本 #Include）
; 依赖：ShowScreenshotEditor、CloseScreenshotEditor、DeferredScreenshotHistorySave、GetScreenInfo、
; UI_Colors、ThemeMode、FloatingToolbar、HideCursorPanel、ImagePut/OCR、GetText 等。

; ===================== 截图后智能处理菜单 =====================
; 从悬浮条隐藏工具栏后发起截图时，在剪贴板就绪、显示助手前恢复悬浮条（避免与 finally 延迟 Show 重复导致双开/偏移）
ScreenshotFlowRestoreFloatingToolbarIfNeeded() {
    global FloatingToolbar_ScheduleRestoreAfterScreenshot, AppearanceActivationMode
    if (FloatingToolbar_ScheduleRestoreAfterScreenshot) {
        FloatingToolbar_ScheduleRestoreAfterScreenshot := false
        if (NormalizeAppearanceActivationMode(AppearanceActivationMode) != "toolbar")
            return
        try ShowFloatingToolbar()
        catch as _e {
        }
    }
}

; 执行截图并等待完成后弹出智能菜单
; fromFloatingDeferred: 为 true 时表示 FloatingToolbar_DeferredScreenshot 已在 Hide/Sleep 前原子地占用了 g_ExecuteScreenshotWithMenuBusy，此处不得因 busy 而 return
ExecuteScreenshotWithMenu(fromFloatingDeferred := false) {
    global CursorPath, AISleepTime, ScreenshotWaiting, ScreenshotClipboard, ScreenshotOldClipboard
    global PanelVisible
    global g_ExecuteScreenshotWithMenuBusy, FloatingToolbar_ScheduleRestoreAfterScreenshot
    ; 与热键/定时器线程竞态：Sleep 让出执行权前 busy 检查与赋值须原子化；Deferred 路径在 Sleep 前预占 busy，避免第二次 Deferred 叠加入口
    prevCrit := Critical("On")
    if (g_ExecuteScreenshotWithMenuBusy && !fromFloatingDeferred) {
        Critical(prevCrit)
        return
    }
    if (!fromFloatingDeferred)
        g_ExecuteScreenshotWithMenuBusy := true
    Critical(prevCrit)
    try {
    ; 初始化 DebugGui 变量
    DebugGui := 0
    
    ; 创建调试窗口
    try {
        DebugGui := CreateScreenshotDebugWindow()
        if (DebugGui) {
            UpdateDebugStep(DebugGui, 1, "开始执行截图流程...", true)
        }
    } catch as e {
        ; 如果创建调试窗口失败，继续执行但不显示调试信息
        TrayTip("警告", "无法创建调试窗口: " . e.Message, "Icon! 1")
    }
    
    try {
        ; 隐藏面板（如果显示）
        if (DebugGui) {
            UpdateDebugStep(DebugGui, 2, "检查并隐藏面板...", false)
        }
        if (PanelVisible) {
            HideCursorPanel()
            if (DebugGui) {
                UpdateDebugStep(DebugGui, 2, "面板已隐藏", true)
            }
        } else {
            if (DebugGui) {
                UpdateDebugStep(DebugGui, 2, "面板未显示，跳过", true)
            }
        }
        
        ; 保存当前剪贴板内容
        if (DebugGui) {
            UpdateDebugStep(DebugGui, 3, "保存当前剪贴板内容...", false)
        }
        ScreenshotOldClipboard := ClipboardAll()
        if (DebugGui) {
            UpdateDebugStep(DebugGui, 3, "剪贴板内容已保存", true)
        }
        
        ; 启动等待截图模式
        if (DebugGui) {
            UpdateDebugStep(DebugGui, 4, "设置等待状态...", false)
        }
        ScreenshotWaiting := true
        ScreenshotImageDetected := false
        if (DebugGui) {
            UpdateDebugStep(DebugGui, 4, "等待状态已设置", true)
        }
        
        ; 记录剪贴板序列号并清空剪贴板，确保后续能检测到“新截图”
        A_Clipboard := ""
        Sleep(80)
        ClipboardSeqBeforeShot := DllCall("GetClipboardSequenceNumber", "UInt")

        ; 使用 Windows 10/11 的截图工具（Win+Shift+S）
        if (DebugGui) {
            UpdateDebugStep(DebugGui, 5, "发送 Win+Shift+S 启动截图工具...", false)
        }
        Send("#+{s}")
        if (DebugGui) {
            UpdateDebugStep(DebugGui, 5, "截图工具启动命令已发送", true)
        }
        
        ; 等待用户完成截图（最多等待30秒）
        if (DebugGui) {
            UpdateDebugStep(DebugGui, 6, "初始化等待参数...", false)
        }
        MaxWaitTime := 30000  ; 30秒
        WaitInterval := 200   ; 每200ms检查一次
        ElapsedTime := 0
        ScreenshotTaken := false
        if (DebugGui) {
            UpdateDebugStep(DebugGui, 6, "等待参数已初始化 (最大30秒)", true)
        }
        
        ; 等待一下，让截图工具启动
        if (DebugGui) {
            UpdateDebugStep(DebugGui, 7, "等待截图工具启动 (500ms)...", false)
        }
        Sleep(500)
        if (DebugGui) {
            UpdateDebugStep(DebugGui, 7, "等待完成，开始监控剪贴板...", true)
        }
        
        ; 监控剪贴板，等待截图完成
        if (DebugGui) {
            UpdateDebugStep(DebugGui, 8, "监控剪贴板，等待截图完成...", false)
        }
        CheckCount := 0
        while (ElapsedTime < MaxWaitTime) {
            CheckCount++
            if (Mod(CheckCount, 10) = 0 && DebugGui) {
                UpdateDebugStep(DebugGui, 8, "监控中... (已等待 " . Round(ElapsedTime/1000) . " 秒)", false)
            }
            Sleep(WaitInterval)
            ElapsedTime += WaitInterval
            
            ; 主要检测：OnClipboardChange 回调已检测到图片写入
            if (ScreenshotImageDetected) {
                ScreenshotTaken := true
                if (DebugGui) {
                    UpdateDebugStep(DebugGui, 8, "OnClipboardChange 检测到图片，截图完成！", true)
                }
                break
            }
            
            ; 备用检测：直接轮询剪贴板序列号 + 格式，避免把非图片当成截图成功“图片格式可用”，避免把非图片当成截图成功
            try {
                ClipboardSeqNow := DllCall("GetClipboardSequenceNumber", "UInt")
                if (ClipboardSeqNow = ClipboardSeqBeforeShot) {
                    continue
                }
                if (DllCall("OpenClipboard", "Ptr", 0)) {
                    ; 检查是否包含位图格式
                    if (DllCall("IsClipboardFormatAvailable", "UInt", 2)) {  ; CF_BITMAP = 2
                        DllCall("CloseClipboard")
                        ScreenshotTaken := true
                        if (DebugGui) {
                            UpdateDebugStep(DebugGui, 8, "检测到 CF_BITMAP 格式，截图完成！", true)
                        }
                        break
                    }
                    ; 检查是否包含 DIB / DIBV5 格式
                    if (DllCall("IsClipboardFormatAvailable", "UInt", 8)) {  ; CF_DIB = 8
                        DllCall("CloseClipboard")
                        ScreenshotTaken := true
                        if (DebugGui) {
                            UpdateDebugStep(DebugGui, 8, "检测到 CF_DIB 格式，截图完成！", true)
                        }
                        break
                    }
                    if (DllCall("IsClipboardFormatAvailable", "UInt", 17)) {  ; CF_DIBV5 = 17
                        DllCall("CloseClipboard")
                        ScreenshotTaken := true
                        if (DebugGui) {
                            UpdateDebugStep(DebugGui, 8, "检测到 CF_DIBV5 格式，截图完成！", true)
                        }
                        break
                    }
                    ; 检查是否包含 PNG 格式
                    PNGFormat := DllCall("RegisterClipboardFormat", "Str", "PNG")
                    if (PNGFormat && DllCall("IsClipboardFormatAvailable", "UInt", PNGFormat)) {
                        DllCall("CloseClipboard")
                        ScreenshotTaken := true
                        if (DebugGui) {
                            UpdateDebugStep(DebugGui, 8, "检测到 PNG 格式，截图完成！", true)
                        }
                        break
                    }
                    DllCall("CloseClipboard")
                }
            } catch as e {
                ; 如果检测失败，继续等待
            }
        }
        
        ; 如果截图成功，保存截图并弹出智能菜单
        if (ScreenshotTaken) {
            if (DebugGui) {
                UpdateDebugStep(DebugGui, 9, "截图检测成功，开始保存截图数据...", false)
            }
            ; 等待一下确保截图已保存到剪贴板
            Sleep(300)
            
            ; 保存截图到全局变量
            try {
                if (DebugGui) {
                    UpdateDebugStep(DebugGui, 10, "调用 ClipboardAll() 保存截图...", false)
                }
                ; 再次确认当前剪贴板确实是图片，防止竞争条件导致保存到非图片数据
                if (GetClipboardType() != "image") {
                    throw Error("当前剪贴板不是图片数据")
                }
                ScreenshotClipboard := ClipboardAll()
                
                if (!ScreenshotClipboard) {
                    throw Error("截图数据为空")
                }
                if (DebugGui) {
                    UpdateDebugStep(DebugGui, 10, "截图数据已保存到 ScreenshotClipboard", true)
                }
            } catch as e {
                if (DebugGui) {
                    UpdateDebugStep(DebugGui, 10, "保存截图失败: " . e.Message, false)
                }
                TrayTip("保存截图失败", e.Message, "Iconx 2")
                A_Clipboard := ScreenshotOldClipboard
                ScreenshotWaiting := false
                if (DebugGui) {
                    try {
                        DebugGui.Destroy()
                    } catch {
                        ; 忽略销毁错误
                    }
                }
                ScreenshotFlowRestoreFloatingToolbarIfNeeded()
                return
            }
            
            ; 恢复旧剪贴板（预览窗会重新设置）
            if (DebugGui) {
                UpdateDebugStep(DebugGui, 11, "恢复旧剪贴板内容...", false)
            }
            A_Clipboard := ScreenshotOldClipboard
            if (DebugGui) {
                UpdateDebugStep(DebugGui, 11, "旧剪贴板已恢复", true)
            }
            
            ; 清除等待状态
            if (DebugGui) {
                UpdateDebugStep(DebugGui, 12, "清除等待状态...", false)
            }
            ScreenshotWaiting := false
            SetTimer(DeferredScreenshotHistorySave, -800)
            if (DebugGui) {
                UpdateDebugStep(DebugGui, 12, "等待状态已清除", true)
            }
            
            ; 等待截图工具关闭后再恢复悬浮条并打开助手（避免与延迟 Show 重复导致双开/位置偏移）
            if (DebugGui) {
                UpdateDebugStep(DebugGui, 13, "等待截图工具关闭...", false)
            }
            Sleep(400)
            CloseAllScreenshotWindows()
            Sleep(150)
            Sleep(200)
            ScreenshotFlowRestoreFloatingToolbarIfNeeded()
            ; 弹出截图助手预览窗（替代智能菜单）
            if (DebugGui) {
                UpdateDebugStep(DebugGui, 13, "调用 ShowScreenshotEditor() 显示助手窗口...", false)
            }
            try {
                ShowScreenshotEditor(DebugGui)
                if (DebugGui) {
                    UpdateDebugStep(DebugGui, 13, "ShowScreenshotEditor() 调用成功", true)
                }
                TrayTip("调试", "ShowScreenshotEditor() 调用成功", "Iconi 1")
                ; 延迟关闭调试窗口，让用户看到最后的状态
                if (DebugGui) {
                    SetTimer(DestroyDebugGui.Bind(DebugGui), -2000)
                }
            } catch as e {
                if (DebugGui) {
                    UpdateDebugStep(DebugGui, 13, "ShowScreenshotEditor() 失败: " . e.Message, false)
                }
                ErrorMsg := "显示截图助手失败:`n"
                ErrorMsg .= "错误: " . e.Message . "`n"
                ErrorMsg .= "文件: " . (e.HasProp("File") ? e.File : "未知") . "`n"
                ErrorMsg .= "行号: " . (e.HasProp("Line") ? e.Line : "未知") . "`n"
                ErrorMsg .= "堆栈: " . (e.HasProp("Stack") ? e.Stack : "未知")
                MsgBox(ErrorMsg, "截图助手错误", "Icon!")
                if (DebugGui) {
                    SetTimer(DestroyDebugGui.Bind(DebugGui), -3000)
                }
            }
        } else {
            ; 截图超时或取消，恢复旧剪贴板
            if (DebugGui) {
                UpdateDebugStep(DebugGui, 9, "截图超时或取消 (等待了 " . Round(ElapsedTime/1000) . " 秒)", false)
            }
            A_Clipboard := ScreenshotOldClipboard
            ScreenshotWaiting := false
            TrayTip("提示", "截图已取消或超时", "Iconi 1")
            if (DebugGui) {
                SetTimer(DestroyDebugGui.Bind(DebugGui), -2000)
            }
            ScreenshotFlowRestoreFloatingToolbarIfNeeded()
        }
    } catch as e {
        if (DebugGui) {
            UpdateDebugStep(DebugGui, 0, "发生异常: " . e.Message . "`n文件: " . (e.File ? e.File : "未知") . "`n行号: " . (e.Line ? e.Line : "未知"), false)
        }
        TrayTip("截图失败: " . e.Message, GetText("error"), "Iconx 2")
        try {
            A_Clipboard := ScreenshotOldClipboard
        }
        ScreenshotWaiting := false
        if (DebugGui) {
            SetTimer(DestroyDebugGui.Bind(DebugGui), -3000)
        }
        ScreenshotFlowRestoreFloatingToolbarIfNeeded()
    }
    } finally {
        g_ExecuteScreenshotWithMenuBusy := false
    }
}

; 销毁调试窗口的辅助函数
DestroyDebugGui(DebugGui) {
    try {
        if (DebugGui && IsObject(DebugGui)) {
            DebugGui.Destroy()
        }
    } catch {
        ; 忽略销毁错误
    }
}

; 创建截图调试窗口
CreateScreenshotDebugWindow() {
    try {
        DebugGui := Gui("+AlwaysOnTop +ToolWindow -MaximizeBox -MinimizeBox", "截图流程调试")
        if (!DebugGui) {
            throw Error("无法创建 GUI 对象")
        }
        DebugGui.BackColor := "0x1E1E1E"
        DebugGui.SetFont("s9", "Consolas")
        
        ; 标题
        TitleText := DebugGui.Add("Text", "x10 y10 w780 h30 Center c0xFFFFFF Background0x2D2D2D", "📊 截图流程调试信息")
        if (TitleText) {
            TitleText.SetFont("s11 Bold", "Segoe UI")
        }
        
        ; 步骤显示区域
        StepsText := DebugGui.Add("Edit", "x10 y50 w780 h450 ReadOnly Multi Background0x2D2D2D c0xCCCCCC", "")
        if (StepsText) {
            StepsText.SetFont("s9", "Consolas")
        }
        
        ; 保存引用以便更新
        if (StepsText) {
            DebugGui["StepsText"] := StepsText
            DebugGui["Steps"] := []
        }
        
        ; 关闭按钮
        CloseBtn := DebugGui.Add("Button", "x350 y510 w120 h35 Default", "关闭")
        if (CloseBtn) {
            CloseBtn.OnEvent("Click", (*) => DebugGui.Destroy())
        }
        
        ; 显示窗口
        DebugGui.Show("w800 h560")
        
        return DebugGui
    } catch as e {
        ; 如果创建失败，返回 0
        return 0
    }
}

; 更新调试步骤
UpdateDebugStep(DebugGui, StepNum, Message, IsSuccess) {
    if (!DebugGui || !IsObject(DebugGui["Steps"])) {
        return
    }
    
    Steps := DebugGui["Steps"]
    StepsText := DebugGui["StepsText"]
    
    ; 格式化步骤信息
    ; 在 AutoHotkey v2 中，FormatTime 的第一个参数可以为空字符串表示当前时间
    TimeStr := FormatTime("", "HH:mm:ss.fff")
    StatusIcon := IsSuccess ? "✓" : "⏳"
    StatusColor := IsSuccess ? "0x00FF00" : "0xFFFF00"
    
    StepInfo := "[" . TimeStr . "] "
    if (StepNum > 0) {
        StepInfo .= "步骤 " . StepNum . ": "
    }
    StepInfo .= Message
    
    ; 添加到步骤列表
    Steps.Push(StepInfo)
    
    ; 更新显示（只显示最后30个步骤）
    DisplayText := ""
    StartIdx := Steps.Length > 30 ? Steps.Length - 30 : 1
    Loop Steps.Length - StartIdx + 1 {
        idx := StartIdx + A_Index - 1
        DisplayText .= Steps[idx] . "`n"
    }
    
    StepsText.Value := DisplayText
    StepsText.Focus()
}

; 显示剪贴板智能处理菜单
ShowClipboardSmartMenu(ForceType := "") {
    global GuiID_ClipboardSmartMenu, UI_Colors, ThemeMode, PanelVisible
    global ClipboardMenuSelectedIndex, ClipboardMenuButtons, ClipboardMenuOptions
    
    ; 如果面板已显示，先隐藏
    if (PanelVisible) {
        HideCursorPanel()
    }
    
    ; 如果菜单已存在，先销毁
    if (GuiID_ClipboardSmartMenu != 0) {
        try {
            GuiID_ClipboardSmartMenu.Destroy()
        } catch as err {
            ; 忽略错误
        }
        global GuiID_ClipboardSmartMenu := 0
    }
    
    ; 检查剪贴板内容类型
    if (ForceType != "") {
        ; 强制指定类型（截图后使用）
        ClipboardType := ForceType
    } else {
        ; 自动检测类型
        ClipboardType := GetClipboardType()
    }
    
    ; 创建菜单 GUI
    GuiID_ClipboardSmartMenu := Gui("+AlwaysOnTop +ToolWindow -Caption -DPIScale")
    GuiID_ClipboardSmartMenu.BackColor := UI_Colors.Background
    GuiID_ClipboardSmartMenu.SetFont("s11 c" . UI_Colors.Text, "Segoe UI")
    
    ; 菜单尺寸
    MenuWidth := 420
    MenuHeight := 0  ; 动态计算
    ButtonHeight := 50
    ButtonSpacing := 8
    Padding := 20
    
    ; 当前 Y 位置
    CurrentY := Padding
    
    ; 标题
    TitleText := GuiID_ClipboardSmartMenu.Add("Text", "x" . Padding . " y" . CurrentY . " w" . (MenuWidth - Padding * 2) . " h30 Center c" . UI_Colors.Text, "📋 智能剪贴板处理")
    TitleText.SetFont("s13 Bold", "Segoe UI")
    CurrentY += 35
    
    ; 提示文字（根据类型显示不同提示）
    if (ClipboardType = "image") {
        HintText := GuiID_ClipboardSmartMenu.Add("Text", "x" . Padding . " y" . CurrentY . " w" . (MenuWidth - Padding * 2) . " h20 Center c" . UI_Colors.TextDim, "检测到图片，请选择处理方式：")
    } else if (ClipboardType = "text") {
        HintText := GuiID_ClipboardSmartMenu.Add("Text", "x" . Padding . " y" . CurrentY . " w" . (MenuWidth - Padding * 2) . " h20 Center c" . UI_Colors.TextDim, "检测到文本，请选择处理方式：")
    } else {
        HintText := GuiID_ClipboardSmartMenu.Add("Text", "x" . Padding . " y" . CurrentY . " w" . (MenuWidth - Padding * 2) . " h20 Center c" . UI_Colors.TextDim, "剪贴板为空")
    }
    HintText.SetFont("s9", "Segoe UI")
    CurrentY += 25
    
    ; 根据剪贴板类型显示不同的选项
    ClipboardMenuOptions := []
    
    if (ClipboardType = "image") {
        ; 图片类型：显示图片相关选项
        ClipboardMenuOptions.Push(Map("icon", "🔍", "text", "识图取词 (保留布局)", "desc", "提取文字，保留原始分行和缩进", "action", "ocr_preserve_layout"))
        ClipboardMenuOptions.Push(Map("icon", "🔄", "text", "识图取词 (自动流转)", "desc", "提取文字，合并断行并去除中文间空格", "action", "ocr_auto_flow"))
        ClipboardMenuOptions.Push(Map("icon", "📷", "text", "粘贴图片", "desc", "保留原始图片状态", "action", "paste_image"))
        ; 如果是截图后的菜单，确保使用保存的截图数据
        if (ForceType = "image") {
            ; 恢复截图到剪贴板，供后续操作使用
            global ScreenshotClipboard
            if (ScreenshotClipboard) {
                A_Clipboard := ScreenshotClipboard
                Sleep(200)
            }
        }
    } else if (ClipboardType = "text") {
        ; 文本类型：显示文本相关选项
        ClipboardMenuOptions.Push(Map("icon", "📝", "text", "提取文本 (保留布局)", "desc", "保留原始的分行和缩进（适合代码、诗歌）", "action", "extract_preserve_layout"))
        ClipboardMenuOptions.Push(Map("icon", "🔄", "text", "提取文本 (自动流转)", "desc", "合并断行，去除中文间空格（适合阅读、论文）", "action", "extract_auto_flow"))
        ClipboardMenuOptions.Push(Map("icon", "✨", "text", "文本净化", "desc", "去除重复空格、统一标点、移除 HTML 标签", "action", "text_cleanup"))
    } else {
        ; 空剪贴板或其他类型
        ClipboardMenuOptions.Push(Map("icon", "⚠️", "text", "剪贴板为空", "desc", "请先复制内容", "action", "empty"))
    }
    
    ; 初始化按钮数组和选中索引
    ClipboardMenuButtons := []
    ClipboardMenuSelectedIndex := 1  ; 默认选中第一个按钮
    
    ; 计算按钮背景色（增强对比度，让光效更明显）
    ; 如果背景是深色，按钮使用稍亮的灰色；如果背景是浅色，按钮使用稍暗的灰色
    BtnNormalBg := (ThemeMode = "light") ? "e0e0e0" : "2d2d2d"  ; 正常状态（稍暗，与背景有区别）
    BtnHoverBg := (ThemeMode = "light") ? "c0c0c0" : "5a5a5a"   ; 悬停时的背景色（明显的光效）
    BtnSelectedBg := (ThemeMode = "light") ? "b0b0b0" : "6a6a6a"  ; 选中时的背景色（更亮的光效）
    BtnSelectedHoverBg := (ThemeMode = "light") ? "a0a0a0" : "7a7a7a"  ; 选中+悬停时的背景色（最亮的光效）
    
    ; 添加选项按钮
    for Index, Option in ClipboardMenuOptions {
        if (Option["action"] = "empty") {
            ; 空剪贴板提示
            EmptyText := GuiID_ClipboardSmartMenu.Add("Text", "x" . Padding . " y" . CurrentY . " w" . (MenuWidth - Padding * 2) . " h" . ButtonHeight . " Center c" . UI_Colors.TextDim, Option["text"])
            EmptyText.SetFont("s11", "Segoe UI")
            CurrentY += ButtonHeight + ButtonSpacing
        } else {
            ; 创建按钮
            BtnY := CurrentY
            BtnX := Padding
            
            ; 确定按钮背景色（选中时使用更亮的颜色）
            CurrentBtnBg := (Index = ClipboardMenuSelectedIndex) ? BtnSelectedBg : BtnNormalBg
            
            ; 按钮背景（使用更亮的背景色，确保与背景有对比度，避免黑色块效果）
            BtnBg := GuiID_ClipboardSmartMenu.Add("Text", "x" . BtnX . " y" . BtnY . " w" . (MenuWidth - Padding * 2) . " h" . ButtonHeight . " Background" . CurrentBtnBg . " vBtnBg" . Index, "")
            
            ; 图标和文字
            IconText := GuiID_ClipboardSmartMenu.Add("Text", "x" . (BtnX + 15) . " y" . (BtnY + 10) . " w30 h30 Center 0x200 c" . UI_Colors.Text . " BackgroundTrans vBtnIcon" . Index, Option["icon"])
            IconText.SetFont("s16", "Segoe UI")
            
            ; 主文字
            MainText := GuiID_ClipboardSmartMenu.Add("Text", "x" . (BtnX + 55) . " y" . (BtnY + 8) . " w" . (MenuWidth - Padding * 2 - 70) . " h22 0x200 c" . UI_Colors.Text . " BackgroundTrans vBtnText" . Index, Option["text"])
            MainText.SetFont("s11 Bold", "Segoe UI")
            
            ; 描述文字
            DescText := GuiID_ClipboardSmartMenu.Add("Text", "x" . (BtnX + 55) . " y" . (BtnY + 28) . " w" . (MenuWidth - Padding * 2 - 70) . " h18 0x200 c" . UI_Colors.TextDim . " BackgroundTrans vBtnDesc" . Index, Option["desc"])
            DescText.SetFont("s9", "Segoe UI")
            
            ; 为按钮背景设置悬停属性（让WM_MOUSEMOVE能处理）
            BtnBg.NormalColor := BtnNormalBg
            BtnBg.HoverColor := BtnHoverBg
            BtnBg.SelectedBg := BtnSelectedBg
            BtnBg.SelectedHoverBg := BtnSelectedHoverBg
            BtnBg.ButtonIndex := Index
            BtnBg.IsMenuButton := true  ; 标记这是菜单按钮
            
            ; 保存按钮引用
            ClipboardMenuButtons.Push({
                Bg: BtnBg,
                Icon: IconText,
                Text: MainText,
                Desc: DescText,
                Index: Index,
                Action: Option["action"],
                NormalBg: BtnNormalBg,
                HoverBg: BtnHoverBg,
                SelectedBg: BtnSelectedBg,
                SelectedHoverBg: BtnSelectedHoverBg
            })
            
            ; 添加点击事件
            ActionFunc := CreateMenuActionHandler(Option["action"])
            BtnBg.OnEvent("Click", ActionFunc)
            IconText.OnEvent("Click", ActionFunc)
            MainText.OnEvent("Click", ActionFunc)
            DescText.OnEvent("Click", ActionFunc)
            
            CurrentY += ButtonHeight + ButtonSpacing
        }
    }
    
    ; 关闭按钮
    CloseBtnY := CurrentY + 10
    CloseBtn := GuiID_ClipboardSmartMenu.Add("Text", "x" . (MenuWidth - 40) . " y" . (CloseBtnY - 5) . " w30 h30 Center 0x200 cFFFFFF Background" . BtnNormalBg . " vCloseBtn", "✕")
    CloseBtn.SetFont("s12", "Segoe UI")
    CloseBtn.OnEvent("Click", (*) => CloseClipboardSmartMenu())
    HoverBtnWithAnimation(CloseBtn, BtnNormalBg, "e81123")
    
    ; 更新菜单高度
    MenuHeight := CloseBtnY + 35
    
    ; 计算菜单位置（屏幕居中）
    ScreenInfo := GetScreenInfo(1)
    MenuX := (ScreenInfo.Width - MenuWidth) // 2
    MenuY := (ScreenInfo.Height - MenuHeight) // 2
    
    ; 创建一个隐藏的输入框用于接收键盘焦点（在显示前创建）
    DummyEdit := GuiID_ClipboardSmartMenu.Add("Edit", "x0 y0 w0 h0 vDummyFocus")
    
    ; 显示菜单
    GuiID_ClipboardSmartMenu.Show("w" . MenuWidth . " h" . MenuHeight . " x" . MenuX . " y" . MenuY)
    
    ; 添加键盘事件
    GuiID_ClipboardSmartMenu.OnEvent("Escape", (*) => CloseClipboardSmartMenu())
    
    ; 使用窗口消息处理键盘事件（更可靠）
    OnMessage(0x0100, HandleClipboardMenuKeyMessage)  ; WM_KEYDOWN
    
    ; 注册热键（仅在菜单显示时生效）
    RegisterClipboardMenuHotkeys()
    
    ; 更新按钮高亮（初始状态）
    UpdateClipboardMenuHighlight()
    
    ; 确保窗口获得焦点，以便接收键盘事件
    try {
        ; 等待窗口完全显示
        Sleep(50)
        WinActivate("ahk_id " . GuiID_ClipboardSmartMenu.Hwnd)
        ; 再次等待确保激活完成
        Sleep(50)
        ; 设置输入框焦点
        DummyEdit.Focus()
        ; 确保窗口在前台
        WinSetAlwaysOnTop(true, "ahk_id " . GuiID_ClipboardSmartMenu.Hwnd)
    } catch as err {
        ; 忽略错误
    }
}

; 处理剪贴板菜单键盘消息
HandleClipboardMenuKeyMessage(wParam, lParam, msg, hwnd) {
    global GuiID_ClipboardSmartMenu
    if (GuiID_ClipboardSmartMenu = 0 || hwnd != GuiID_ClipboardSmartMenu.Hwnd) {
        return
    }
    
    ; wParam 是虚拟键码
    KeyCode := wParam
    
    ; 上方向键 (VK_UP = 0x26)
    if (KeyCode = 0x26) {
        HandleClipboardMenuUp()
        return 1  ; 阻止默认行为
    }
    
    ; 下方向键 (VK_DOWN = 0x28)
    if (KeyCode = 0x28) {
        HandleClipboardMenuDown()
        return 1  ; 阻止默认行为
    }
    
    ; 回车键 (VK_RETURN = 0x0D)
    if (KeyCode = 0x0D) {
        HandleClipboardMenuEnter()
        return 1  ; 阻止默认行为
    }
    
    return 0  ; 允许默认行为
}

; 创建菜单操作处理函数
CreateMenuActionHandler(Action) {
    return (*) => HandleClipboardMenuAction(Action)
}

; 处理菜单操作
HandleClipboardMenuAction(Action) {
    global GuiID_ClipboardSmartMenu
    
    ; 关闭菜单
    CloseClipboardSmartMenu()
    
    ; 根据操作类型执行相应功能
    switch Action {
        case "ocr_preserve_layout":
            ProcessOCR("preserve_layout")
        case "ocr_auto_flow":
            ProcessOCR("auto_flow")
        case "paste_image":
            PasteImage()
        case "extract_preserve_layout":
            ExtractTextPreserveLayout()
        case "extract_auto_flow":
            ExtractTextAutoFlow()
        case "text_cleanup":
            CleanupText()
    }
}

; 关闭智能菜单
CloseClipboardSmartMenu() {
    global GuiID_ClipboardSmartMenu, ClipboardMenuHotkeysRegistered
    if (GuiID_ClipboardSmartMenu != 0) {
        try {
            ; 注销热键
            UnregisterClipboardMenuHotkeys()
            ; 移除消息处理
            OnMessage(0x0100, HandleClipboardMenuKeyMessage, 0)  ; 移除 WM_KEYDOWN 处理
            ; 清理所有按钮的悬停状态（不需要清理定时器，因为使用WM_MOUSEMOVE）
            global LastHoverCtrl
            if (LastHoverCtrl && LastHoverCtrl.HasProp("IsMenuButton")) {
                try {
                    if (LastHoverCtrl.HasProp("ButtonIndex") && LastHoverCtrl.ButtonIndex = ClipboardMenuSelectedIndex) {
                        LastHoverCtrl.BackColor := LastHoverCtrl.SelectedBg
                    } else {
                        LastHoverCtrl.BackColor := LastHoverCtrl.NormalColor
                    }
                } catch as err {
                    ; 忽略错误
                }
                LastHoverCtrl := 0
            }
            GuiID_ClipboardSmartMenu.Destroy()
        } catch as err {
            ; 忽略错误
        }
        global GuiID_ClipboardSmartMenu := 0
        global ClipboardMenuButtons := []
        global ClipboardMenuSelectedIndex := 0
    }
}

; 注册剪贴板菜单热键（占位函数，实际使用窗口消息处理）
RegisterClipboardMenuHotkeys() {
    global ClipboardMenuHotkeysRegistered
    ClipboardMenuHotkeysRegistered := true
}

; 注销剪贴板菜单热键（占位函数）
UnregisterClipboardMenuHotkeys() {
    global ClipboardMenuHotkeysRegistered
    ClipboardMenuHotkeysRegistered := false
}

; 处理剪贴板菜单上方向键
HandleClipboardMenuUp(*) {
    global ClipboardMenuSelectedIndex, ClipboardMenuButtons, GuiID_ClipboardSmartMenu
    if (GuiID_ClipboardSmartMenu = 0 || ClipboardMenuButtons.Length = 0) {
        return
    }
    
    ClipboardMenuSelectedIndex--
    if (ClipboardMenuSelectedIndex < 1) {
        ClipboardMenuSelectedIndex := ClipboardMenuButtons.Length
    }
    
    ; 更新高亮（会同时检查悬停状态）
    UpdateClipboardMenuHighlight()
    
    ; 确保窗口获得焦点，以便继续接收键盘事件
    try {
        WinActivate("ahk_id " . GuiID_ClipboardSmartMenu.Hwnd)
        ; 重新设置焦点到隐藏输入框
        try {
            DummyEdit := GuiID_ClipboardSmartMenu["DummyFocus"]
            if (DummyEdit) {
                DummyEdit.Focus()
            }
        } catch as err {
            ; 忽略错误
        }
    } catch as err {
        ; 忽略错误
    }
}

; 处理剪贴板菜单下方向键
HandleClipboardMenuDown(*) {
    global ClipboardMenuSelectedIndex, ClipboardMenuButtons, GuiID_ClipboardSmartMenu
    if (GuiID_ClipboardSmartMenu = 0 || ClipboardMenuButtons.Length = 0) {
        return
    }
    
    ClipboardMenuSelectedIndex++
    if (ClipboardMenuSelectedIndex > ClipboardMenuButtons.Length) {
        ClipboardMenuSelectedIndex := 1
    }
    
    ; 更新高亮（会同时检查悬停状态）
    UpdateClipboardMenuHighlight()
    
    ; 确保窗口获得焦点，以便继续接收键盘事件
    try {
        WinActivate("ahk_id " . GuiID_ClipboardSmartMenu.Hwnd)
        ; 重新设置焦点到隐藏输入框
        try {
            DummyEdit := GuiID_ClipboardSmartMenu["DummyFocus"]
            if (DummyEdit) {
                DummyEdit.Focus()
            }
        } catch as err {
            ; 忽略错误
        }
    } catch as err {
        ; 忽略错误
    }
}

; 处理剪贴板菜单回车键
HandleClipboardMenuEnter(*) {
    global ClipboardMenuSelectedIndex, ClipboardMenuButtons, GuiID_ClipboardSmartMenu
    if (GuiID_ClipboardSmartMenu = 0 || ClipboardMenuButtons.Length = 0 || ClipboardMenuSelectedIndex < 1 || ClipboardMenuSelectedIndex > ClipboardMenuButtons.Length) {
        return
    }
    
    Button := ClipboardMenuButtons[ClipboardMenuSelectedIndex]
    HandleClipboardMenuAction(Button.Action)
}

; 更新剪贴板菜单高亮（所有按钮都有悬停光效）
UpdateClipboardMenuHighlight() {
    global ClipboardMenuButtons, ClipboardMenuSelectedIndex, GuiID_ClipboardSmartMenu, LastHoverCtrl
    
    if (GuiID_ClipboardSmartMenu = 0 || ClipboardMenuButtons.Length = 0) {
        return
    }
    
    ; 更新所有按钮的背景色（考虑选中状态和悬停状态）
    ; 悬停状态由WM_MOUSEMOVE处理，这里只处理选中状态
    for Index, Button in ClipboardMenuButtons {
        try {
            ; 检查按钮是否被鼠标悬停（通过LastHoverCtrl判断）
            IsHovering := (LastHoverCtrl = Button.Bg)
            
            ; 根据选中和悬停状态设置背景色
            if (Index = ClipboardMenuSelectedIndex) {
                ; 已选中状态
                if (IsHovering) {
                    ; 选中+悬停 = 最亮光效
                    Button.Bg.BackColor := Button.SelectedHoverBg
                } else {
                    ; 选中但未悬停：使用选中背景色
                    Button.Bg.BackColor := Button.SelectedBg
                }
            } else {
                ; 未选中状态
                if (IsHovering) {
                    ; 悬停时有光效
                    Button.Bg.BackColor := Button.HoverBg
                } else {
                    ; 未悬停：使用正常背景色
                    Button.Bg.BackColor := Button.NormalBg
                }
            }
        } catch as err {
            ; 忽略错误
        }
    }
}

; 设置按钮悬停效果
SetupButtonHover(BtnBg, IconText, MainText, DescText, NormalBg, HoverBg, SelectedBg, SelectedHoverBg, Index) {
    global ClipboardMenuButtons, ClipboardMenuSelectedIndex, GuiID_ClipboardSmartMenu
    
    ; 创建悬停检测函数
    HoverCheckFunc(*) {
        CheckButtonHover(Index, BtnBg, NormalBg, HoverBg, SelectedBg, SelectedHoverBg)
    }
    
    ; 使用定时器检测鼠标位置（每30ms检查一次，更流畅）
    SetTimer(HoverCheckFunc, 30)
    
    ; 保存定时器引用以便清理
    try {
        BtnBg.HoverTimer := HoverCheckFunc
    } catch as err {
        ; 忽略错误
    }
}

; 检查按钮悬停状态（所有按钮都有悬停光效）
CheckButtonHover(Index, BtnBg, NormalBg, HoverBg, SelectedBg, SelectedHoverBg) {
    global ClipboardMenuSelectedIndex, GuiID_ClipboardSmartMenu
    
    if (GuiID_ClipboardSmartMenu = 0) {
        return
    }
    
    try {
        ; 获取按钮位置和大小
        WinGetPos(&WinX, &WinY, , , "ahk_id " . GuiID_ClipboardSmartMenu.Hwnd)
        ControlGetPos(&CtrlX, &CtrlY, &CtrlW, &CtrlH, , "ahk_id " . BtnBg.Hwnd)
        
        ; 获取鼠标位置
        MouseGetPos(&MouseX, &MouseY)
        
        ; 计算按钮在屏幕上的绝对位置
        BtnLeft := WinX + CtrlX
        BtnRight := BtnLeft + CtrlW
        BtnTop := WinY + CtrlY
        BtnBottom := BtnTop + CtrlH
        
        ; 检查鼠标是否在按钮上
        IsHovering := (MouseX >= BtnLeft && MouseX <= BtnRight && MouseY >= BtnTop && MouseY <= BtnBottom)
        
        ; 所有按钮都有悬停光效
        if (Index = ClipboardMenuSelectedIndex) {
            ; 已选中状态：根据是否悬停来决定背景色
            if (IsHovering) {
                ; 选中+悬停 = 最亮光效
                BtnBg.BackColor := SelectedHoverBg
            } else {
                ; 选中但未悬停：使用选中背景色
                BtnBg.BackColor := SelectedBg
            }
        } else {
            ; 未选中状态
            if (IsHovering) {
                ; 悬停时有光效
                BtnBg.BackColor := HoverBg
            } else {
                ; 未悬停：使用正常背景色
                BtnBg.BackColor := NormalBg
            }
        }
    } catch as err {
        ; 忽略错误
    }
}

; 获取剪贴板类型
GetClipboardType() {
    try {
        ; 检查是否包含图片
        if (DllCall("OpenClipboard", "Ptr", 0)) {
            ; 检查位图格式
            if (DllCall("IsClipboardFormatAvailable", "UInt", 2)) {  ; CF_BITMAP
                DllCall("CloseClipboard")
                return "image"
            }
            ; 检查 DIB / DIBV5 格式
            if (DllCall("IsClipboardFormatAvailable", "UInt", 8)) {  ; CF_DIB
                DllCall("CloseClipboard")
                return "image"
            }
            if (DllCall("IsClipboardFormatAvailable", "UInt", 17)) {  ; CF_DIBV5
                DllCall("CloseClipboard")
                return "image"
            }
            ; 检查 PNG 格式
            PNGFormat := DllCall("RegisterClipboardFormat", "Str", "PNG")
            if (PNGFormat && DllCall("IsClipboardFormatAvailable", "UInt", PNGFormat)) {
                DllCall("CloseClipboard")
                return "image"
            }
            DllCall("CloseClipboard")
        }
        
        ; 检查文本
        try {
            ClipboardText := A_Clipboard
            if (ClipboardText != "" && StrLen(ClipboardText) > 0) {
                return "text"
            }
        } catch as err {
            ; 忽略错误
        }
        
        return "empty"
    } catch as err {
        return "empty"
    }
}

; ===================== OCR 识图取词功能（使用 ImagePut 优化） =====================
ProcessOCR(Mode := "preserve_layout") {
    global UI_Colors, ScreenshotClipboard
    
    ; 显示处理中提示
    TrayTip("⚙️ OCR 处理中...", "", "Iconi 1")
    
    try {
        ; 保存当前剪贴板
        OldClipboard := ClipboardAll()
        
        ; 如果有保存的截图数据，优先使用
        if (ScreenshotClipboard) {
            A_Clipboard := ScreenshotClipboard
            Sleep(200)
        }
        
        ; 使用 ImagePutBitmap 直接从剪贴板获取位图（自动处理所有格式：CF_BITMAP, CF_DIB, PNG等）
        ; ImagePut 会自动检测并转换剪贴板中的任何图片格式，无需手动判断
        pBitmap := ImagePutBitmap(A_Clipboard)
        
        if (!pBitmap || pBitmap = "") {
            TrayTip("剪贴板中没有可识别的图片格式", "错误", "Iconx 2")
            A_Clipboard := OldClipboard
            return
        }
        
        ; 将 GDI+ Bitmap 转换为 RandomAccessStream（OCR 需要）
        ; 先保存为临时文件，然后使用 OCR.FromFile 识别（性能更好，支持更多格式）
        TempFile := A_Temp "\ocr_temp_" . A_TickCount . ".png"
        OCRResult := ""
        
        try {
            ; 使用 ImagePut 保存为 PNG（高质量，支持透明通道）
            ImagePut("File", pBitmap, TempFile)
            
            ; 清理 Bitmap 资源
            ImageDestroy(pBitmap)
            pBitmap := ""
            
            ; 使用 OCR.FromFile 识别（支持更多格式，性能更好）
            OCRResult := OCR.FromFile(TempFile)
            
            ; 删除临时文件
            try {
                FileDelete(TempFile)
            } catch {
                ; 忽略删除错误
            }
            
        } catch as e {
            ; 清理资源
            try {
                if (FileExist(TempFile)) {
                    FileDelete(TempFile)
                }
            } catch {
                ; 忽略清理错误
            }
            
            ; 如果文件方式失败，尝试直接使用 RandomAccessStream（备用方案）
            try {
                ; 重新从剪贴板读取（如果之前已清理）
                if (!pBitmap) {
                    pBitmap := ImagePutBitmap(A_Clipboard)
                }
                
                if (pBitmap) {
                    ; 将 Bitmap 转换为 RandomAccessStream
                    ras := ImagePut("RandomAccessStream", pBitmap, "png")
                    OCRResult := OCR(ras)
                    ImageDestroy(pBitmap)
                    pBitmap := ""
                } else {
                    throw Error("无法读取剪贴板图片")
                }
            } catch as err {
                TrayTip("OCR 识别失败：" . err.Message, "错误", "Iconx 2")
                A_Clipboard := OldClipboard
                return
            }
        }
        
        if (!OCRResult || !OCRResult.Text || StrLen(OCRResult.Text) = 0) {
            TrayTip("OCR 识别失败：未检测到文字", "错误", "Iconx 2")
            A_Clipboard := OldClipboard
            return
        }
        
        ; 提取原始文本
        ExtractedText := OCRResult.Text
        
        ; 根据模式处理文本
        if (Mode = "auto_flow") {
            ; 自动流转模式：合并断行，去除中文间空格，去除 HTML 标签
            ExtractedText := ProcessOCRTextAutoFlow(ExtractedText)
        } else {
            ; 保留布局模式：仅进行基础清理（乱码修复、去 HTML 标签）
            ExtractedText := ProcessOCRTextPreserveLayout(ExtractedText)
        }
        
        ; 将处理后的文本放入剪贴板
        A_Clipboard := ExtractedText
        Sleep(200)
        
        ; 清除截图数据（已处理完成）
        global ScreenshotClipboard
        ScreenshotClipboard := ""
        
        ; 显示成功提示
        TrayTip("✅ OCR 完成", "已识别 " . StrLen(ExtractedText) . " 个字符", "Iconi 1")
        
        ; 自动粘贴
        Sleep(300)
        Send("^v")
        
    } catch as e {
        TrayTip("OCR 识别失败：" . e.Message, "错误", "Iconx 2")
        try {
            A_Clipboard := OldClipboard
        } catch as err {
            ; 忽略错误
        }
    }
}

; ===================== OCR 文本处理（保留布局） =====================
ProcessOCRTextPreserveLayout(Text) {
    ; 1. 乱码修复（常见 OCR 错误字符替换）
    Text := FixOCREncodingErrors(Text)
    
    ; 2. 去除 HTML 标签
    Text := RemoveHTMLTags(Text)
    
    ; 3. 去除多余的空格（但保留换行和基本布局）
    ; 去除行首行尾空格
    Lines := StrSplit(Text, "`n")
    ProcessedLines := []
    for Index, Line in Lines {
        ProcessedLine := Trim(Line, " `t`r")
        ProcessedLines.Push(ProcessedLine)
    }
    Text := ""
    for Index, Line in ProcessedLines {
        if (Index > 1) {
            Text .= "`n"
        }
        Text .= Line
    }
    
    ; 4. 清理重复的换行（超过 2 个连续换行合并为 2 个）
    while (InStr(Text, "`n`n`n")) {
        Text := StrReplace(Text, "`n`n`n", "`n`n")
    }
    
    return Text
}

; ===================== OCR 文本处理（自动流转） =====================
ProcessOCRTextAutoFlow(Text) {
    ; 1. 乱码修复
    Text := FixOCREncodingErrors(Text)
    
    ; 2. 去除 HTML 标签
    Text := RemoveHTMLTags(Text)
    
    ; 3. 合并所有换行符为空格（但保留段落分隔）
    Text := StrReplace(Text, "`r`n", " ")
    Text := StrReplace(Text, "`n", " ")
    Text := StrReplace(Text, "`r", " ")
    
    ; 4. 去除中文间的无意义空格
    Text := RemoveSpacesBetweenChinese(Text)
    
    ; 5. 清理多余空格（多个连续空格合并为一个）
    while (InStr(Text, "  ")) {
        Text := StrReplace(Text, "  ", " ")
    }
    
    ; 6. 去除首尾空格
    Text := Trim(Text)
    
    return Text
}

; ===================== OCR 乱码修复 =====================
FixOCREncodingErrors(Text) {
    ; 常见 OCR 识别错误字符映射表
    ; 格式：错误字符 => 正确字符
    ErrorMap := Map(
        "０", "0", "１", "1", "２", "2", "３", "3", "４", "4",
        "５", "5", "６", "6", "７", "7", "８", "8", "９", "9",
        "（", "(", "）", ")", "，", ",", "。", ".", "：", ":",
        "；", ";", "？", "?", "！", "!", "、", ",", "—", "-",
        "…", "...", "“", '"', "”", '"', "'", "'", "'", "'",
        "【", "[", "】", "]", "《", "<", "》", ">", "·", "·"
    )
    
    ; 替换错误字符
    Result := Text
    for WrongChar, CorrectChar in ErrorMap {
        Result := StrReplace(Result, WrongChar, CorrectChar)
    }
    
    ; 修复常见的 OCR 识别错误
    ; 修复 "l" 和 "1" 的混淆（在特定上下文中）
    ; 修复 "O" 和 "0" 的混淆（在特定上下文中）
    ; 这里可以根据需要添加更多规则
    
    ; 修复常见的英文识别错误
    CommonErrors := Map(
        "rn", "m",  ; rn 常被识别为 m
        "vv", "w",  ; vv 常被识别为 w
        "cl", "d",  ; cl 常被识别为 d
        "ii", "n"   ; ii 常被识别为 n
    )
    
    ; 注意：这些替换需要谨慎，只在特定上下文中才适用
    ; 这里简化处理，不进行自动替换，避免误替换
    
    return Result
}

; ===================== 粘贴图片功能 =====================
PasteImage() {
    global ScreenshotClipboard
    
    try {
        ; 如果有保存的截图数据，优先使用
        if (ScreenshotClipboard) {
            A_Clipboard := ScreenshotClipboard
            Sleep(200)
        }
        
        ; 检查剪贴板是否有图片
        if (!DllCall("OpenClipboard", "Ptr", 0)) {
            TrayTip("剪贴板中没有图片", "错误", "Iconx 2")
            return
        }
        
        HasImage := false
        if (DllCall("IsClipboardFormatAvailable", "UInt", 2)
            || DllCall("IsClipboardFormatAvailable", "UInt", 8)
            || DllCall("IsClipboardFormatAvailable", "UInt", 17)) {
            HasImage := true
        } else {
            PNGFormat := DllCall("RegisterClipboardFormat", "Str", "PNG")
            if (PNGFormat && DllCall("IsClipboardFormatAvailable", "UInt", PNGFormat)) {
                HasImage := true
            }
        }
        DllCall("CloseClipboard")
        
        if (!HasImage) {
            TrayTip("剪贴板中没有图片", "错误", "Iconx 2")
            return
        }
        
        ; 清除截图数据（已处理完成）
        global ScreenshotClipboard
        ScreenshotClipboard := ""
        
        ; 直接粘贴图片
        Send("^v")
        Sleep(200)
        
        ; 显示成功提示（简化）
        TrayTip("✅ 图片已粘贴", "", "Iconi 1")
        
    } catch as e {
        TrayTip("粘贴图片失败：" . e.Message, "错误", "Iconx 2")
    }
}

; ===================== 提取文本（保留布局） =====================
ExtractTextPreserveLayout() {
    try {
        ; 显示处理中提示（简化）
        TrayTip("⚙️ 处理中...", "", "Iconi 1")
        
        ; 获取剪贴板文本
        ClipboardText := A_Clipboard
        
        if (ClipboardText = "" || StrLen(ClipboardText) = 0) {
            TrayTip("剪贴板中没有文本", "错误", "Iconx 2")
            return
        }
        
        ; 保留原始布局，仅进行基础清理
        ProcessedText := ClipboardText
        
        ; 1. 去除 HTML 标签
        ProcessedText := RemoveHTMLTags(ProcessedText)
        
        ; 2. 去除行首行尾空格（保留换行）
        Lines := StrSplit(ProcessedText, "`n")
        ProcessedLines := []
        for Index, Line in Lines {
            ProcessedLine := Trim(Line, " `t`r")
            ProcessedLines.Push(ProcessedLine)
        }
        ProcessedText := ""
        for Index, Line in ProcessedLines {
            if (Index > 1) {
                ProcessedText .= "`n"
            }
            ProcessedText .= Line
        }
        
        ; 3. 清理重复的换行（超过 2 个连续换行合并为 2 个）
        while (InStr(ProcessedText, "`n`n`n")) {
            ProcessedText := StrReplace(ProcessedText, "`n`n`n", "`n`n")
        }
        
        ; 回填剪贴板
        A_Clipboard := ProcessedText
        Sleep(200)
        
        ; 显示成功提示（简化）
        TrayTip("✅ 文本已处理", "", "Iconi 1")
        
        ; 自动粘贴
        Sleep(300)
        Send("^v")
        
    } catch as e {
        TrayTip("文本提取失败：" . e.Message, "错误", "Iconx 2")
    }
}

; ===================== 提取文本（自动流转） =====================
ExtractTextAutoFlow() {
    try {
        ; 显示处理中提示（简化）
        TrayTip("⚙️ 处理中...", "", "Iconi 1")
        
        ; 获取剪贴板文本
        ClipboardText := A_Clipboard
        
        if (ClipboardText = "" || StrLen(ClipboardText) = 0) {
            TrayTip("剪贴板中没有文本", "错误", "Iconx 2")
            return
        }
        
        ; 处理文本：合并断行，去除中文间空格
        ProcessedText := ClipboardText
        
        ; 1. 去除 HTML 标签
        ProcessedText := RemoveHTMLTags(ProcessedText)
        
        ; 2. 合并所有换行符为空格（但保留段落分隔）
        ProcessedText := StrReplace(ProcessedText, "`r`n", " ")
        ProcessedText := StrReplace(ProcessedText, "`n", " ")
        ProcessedText := StrReplace(ProcessedText, "`r", " ")
        
        ; 3. 去除中文间的无意义空格（中文字符之间的空格）
        ProcessedText := RemoveSpacesBetweenChinese(ProcessedText)
        
        ; 4. 清理多余空格（多个连续空格合并为一个）
        while (InStr(ProcessedText, "  ")) {
            ProcessedText := StrReplace(ProcessedText, "  ", " ")
        }
        
        ; 5. 去除首尾空格
        ProcessedText := Trim(ProcessedText)
        
        ; 回填剪贴板
        A_Clipboard := ProcessedText
        Sleep(200)
        
        ; 显示成功提示（简化）
        TrayTip("✅ 文本已处理", "", "Iconi 1")
        
        ; 自动粘贴
        Sleep(300)
        Send("^v")
        
    } catch as e {
        TrayTip("文本流转失败：" . e.Message, "错误", "Iconx 2")
    }
}

; 去除中文字符之间的空格
RemoveSpacesBetweenChinese(Text) {
    ; 简单的实现：遍历文本，如果遇到中文字符-空格-中文字符的模式，删除空格
    Result := ""
    TextLen := StrLen(Text)
    
    Loop TextLen {
        CurrentChar := SubStr(Text, A_Index, 1)
        NextChar := (A_Index < TextLen) ? SubStr(Text, A_Index + 1, 1) : ""
        PrevChar := (A_Index > 1) ? SubStr(Text, A_Index - 1, 1) : ""
        
        ; 检查是否是中文字符（Unicode 范围：\u4e00-\u9fff）
        IsChinese := (Ord(CurrentChar) >= 0x4E00 && Ord(CurrentChar) <= 0x9FFF)
        IsPrevChinese := (PrevChar != "" && Ord(PrevChar) >= 0x4E00 && Ord(PrevChar) <= 0x9FFF)
        IsNextChinese := (NextChar != "" && Ord(NextChar) >= 0x4E00 && Ord(NextChar) <= 0x9FFF)
        
        ; 如果是空格，且前后都是中文，则跳过（不添加到结果）
        if (CurrentChar = " " && IsPrevChinese && IsNextChinese) {
            continue
        }
        
        Result .= CurrentChar
    }
    
    return Result
}

; ===================== 文本净化功能 =====================
CleanupText() {
    try {
        ; 显示处理中提示（简化）
        TrayTip("⚙️ 处理中...", "", "Iconi 1")
        
        ; 获取剪贴板文本
        ClipboardText := A_Clipboard
        
        if (ClipboardText = "" || StrLen(ClipboardText) = 0) {
            TrayTip("剪贴板中没有文本", "错误", "Iconx 2")
            return
        }
        
        ; 文本净化处理
        ProcessedText := ClipboardText
        
        ; 1. 去除 HTML 标签
        ProcessedText := RemoveHTMLTags(ProcessedText)
        
        ; 2. 去除链接（http:// 或 https:// 开头的 URL）
        ProcessedText := RemoveURLs(ProcessedText)
        
        ; 3. 去除重复空格
        while (InStr(ProcessedText, "  ")) {
            ProcessedText := StrReplace(ProcessedText, "  ", " ")
        }
        
        ; 4. 统一标点格式（将中文标点后的空格去除，英文标点后添加空格）
        ProcessedText := NormalizePunctuation(ProcessedText)
        
        ; 5. 去除中文间的无意义空格
        ProcessedText := RemoveSpacesBetweenChinese(ProcessedText)
        
        ; 6. 去除首尾空格和换行
        ProcessedText := Trim(ProcessedText, " `t`r`n")
        
        ; 7. 清理重复的换行（超过 2 个连续换行合并为 2 个）
        while (InStr(ProcessedText, "`n`n`n")) {
            ProcessedText := StrReplace(ProcessedText, "`n`n`n", "`n`n")
        }
        
        ; 回填剪贴板
        A_Clipboard := ProcessedText
        Sleep(200)
        
        ; 显示成功提示（简化）
        TrayTip("✅ 文本已净化", "", "Iconi 1")
        
        ; 自动粘贴
        Sleep(300)
        Send("^v")
        
    } catch as e {
        TrayTip("文本净化失败：" . e.Message, "错误", "Iconx 2")
    }
}

; 去除 HTML 标签
RemoveHTMLTags(Text) {
    ; 简单的 HTML 标签移除（使用正则表达式或循环）
    Result := Text
    
    ; 移除常见的 HTML 标签
    Loop {
        ; 查找 <...> 标签
        StartPos := InStr(Result, "<")
        if (!StartPos) {
            break
        }
        
        EndPos := InStr(Result, ">", false, StartPos)
        if (!EndPos) {
            break
        }
        
        ; 移除标签
        Result := SubStr(Result, 1, StartPos - 1) . SubStr(Result, EndPos + 1)
    }
    
    ; 解码 HTML 实体
    Result := StrReplace(Result, "&nbsp;", " ")
    Result := StrReplace(Result, "&amp;", "&")
    Result := StrReplace(Result, "&lt;", "<")
    Result := StrReplace(Result, "&gt;", ">")
    Result := StrReplace(Result, "&quot;", '"')
    Result := StrReplace(Result, "&#39;", "'")
    
    return Result
}

; 去除 URL
RemoveURLs(Text) {
    ; 简单的 URL 移除（查找 http:// 或 https:// 开头的字符串）
    Result := Text
    Pos := 1
    
    Loop {
        ; 查找 http:// 或 https://
        HttpPos := InStr(Result, "http://", false, Pos)
        HttpsPos := InStr(Result, "https://", false, Pos)
        
        StartPos := 0
        if (HttpPos && (!HttpsPos || HttpPos < HttpsPos)) {
            StartPos := HttpPos
        } else if (HttpsPos) {
            StartPos := HttpsPos
        }
        
        if (!StartPos) {
            break
        }
        
        ; 查找 URL 结束位置（空格、换行、标点等）
        EndPos := StartPos
        TextLen := StrLen(Result)
        
        while (EndPos <= TextLen) {
            Char := SubStr(Result, EndPos, 1)
            if (Char = " " || Char = "`n" || Char = "`r" || Char = "`t" || 
                Char = "<" || Char = ">" || Char = "(" || Char = ")" || 
                Char = "[" || Char = "]" || Char = "{" || Char = "}") {
                break
            }
            EndPos++
        }
        
        ; 移除 URL
        Result := SubStr(Result, 1, StartPos - 1) . SubStr(Result, EndPos)
        Pos := StartPos
    }
    
    return Result
}

; 统一标点格式
NormalizePunctuation(Text) {
    Result := Text
    
    ; 中文标点后去除空格
    ChinesePunctuation := "，。！？；：、"
    Loop StrLen(ChinesePunctuation) {
        Punctuation := SubStr(ChinesePunctuation, A_Index, 1)
        Result := StrReplace(Result, Punctuation . " ", Punctuation)
    }
    
    ; 英文标点后添加空格（如果后面不是空格或标点）
    EnglishPunctuation := ".,!?;:"
    Loop StrLen(EnglishPunctuation) {
        Punctuation := SubStr(EnglishPunctuation, A_Index, 1)
        ; 简单的处理：标点后如果是字母或数字，添加空格
        ; 这里使用简单的替换，实际可能需要更复杂的逻辑
    }
    
    return Result
}

; ===================== 区域截图功能 =====================
; 执行区域截图并自动粘贴到Cursor
ExecuteScreenshot() {
    global CursorPath, AISleepTime, ScreenshotWaiting, ScreenshotClipboard, ScreenshotCheckTimer
    
    try {
        ; 隐藏面板（如果显示）
        global PanelVisible
        if (PanelVisible) {
            HideCursorPanel()
        }
        
        ; 保存当前剪贴板内容
        OldClipboard := ClipboardAll()
        
        ; 启动等待粘贴模式
        ScreenshotWaiting := true
        ScreenshotImageDetected := false
        
        ; 清空剪贴板，然后记录序列号（顺序很关键：先清空再记录，否则序列号比较失效）
        A_Clipboard := ""
        Sleep(80)
        ClipboardSeqBeforeShot := DllCall("GetClipboardSequenceNumber", "UInt")

        ; 使用 Windows 10/11 的截图工具（Win+Shift+S）
        Send("#+{s}")
        
        ; 等待用户完成截图（最多等待30秒）
        ; 通过检测剪贴板是否包含图片来判断截图是否完成
        MaxWaitTime := 30000  ; 30秒
        WaitInterval := 200   ; 每200ms检查一次
        ElapsedTime := 0
        ScreenshotTaken := false
        
        ; 等待一下，让截图工具启动
        Sleep(500)
        
        ; 清空剪贴板，用于检测新截图
        ; 注意：不要立即清空，因为可能影响用户其他操作
        ; 我们通过检测剪贴板内容变化来判断截图完成
        
        while (ElapsedTime < MaxWaitTime) {
            Sleep(WaitInterval)
            ElapsedTime += WaitInterval
            
            ; 主要检测：OnClipboardChange 回调已检测到图片写入
            if (ScreenshotImageDetected) {
                ScreenshotTaken := true
                break
            }
            
            ; 备用检测：直接轮询剪贴板序列号 + 格式
            try {
                ClipboardSeqNow := DllCall("GetClipboardSequenceNumber", "UInt")
                if (ClipboardSeqNow = ClipboardSeqBeforeShot) {
                    continue
                }
                if (DllCall("OpenClipboard", "Ptr", 0)) {
                    if (DllCall("IsClipboardFormatAvailable", "UInt", 2)) {  ; CF_BITMAP
                        DllCall("CloseClipboard")
                        ScreenshotTaken := true
                        break
                    }
                    if (DllCall("IsClipboardFormatAvailable", "UInt", 8)) {  ; CF_DIB
                        DllCall("CloseClipboard")
                        ScreenshotTaken := true
                        break
                    }
                    if (DllCall("IsClipboardFormatAvailable", "UInt", 17)) {  ; CF_DIBV5
                        DllCall("CloseClipboard")
                        ScreenshotTaken := true
                        break
                    }
                    PNGFormat := DllCall("RegisterClipboardFormat", "Str", "PNG")
                    if (PNGFormat && DllCall("IsClipboardFormatAvailable", "UInt", PNGFormat)) {
                        DllCall("CloseClipboard")
                        ScreenshotTaken := true
                        break
                    }
                    DllCall("CloseClipboard")
                }
            } catch as e {
            }
        }
        
        ; 如果截图成功，立即自动粘贴到 Cursor
        if (ScreenshotTaken) {
            ; 等待一下确保截图已保存到剪贴板
            Sleep(300)
            
            ; 保存截图到全局变量（使用 ClipboardAll 保存完整图片数据）
            ; 注意：必须在恢复旧剪贴板之前保存
            try {
                ; 再次确认当前剪贴板确实是图片
                if (GetClipboardType() != "image") {
                    throw Error("当前剪贴板不是图片数据")
                }
                ; 在 AutoHotkey v2 中，使用 ClipboardAll() 获取数据对象
                ScreenshotClipboard := ClipboardAll()
                
                ; 验证截图是否成功保存（检查是否为有效的 ClipboardAll 对象）
                if (!ScreenshotClipboard) {
                    throw Error("截图数据为空")
                }
            } catch as e {
                TrayTip("保存截图失败: " . e.Message, GetText("error"), "Iconx 2")
                A_Clipboard := OldClipboard
                ScreenshotWaiting := false
                return
            }
            
            ; 恢复旧剪贴板（不影响用户其他操作）
            A_Clipboard := OldClipboard
            
            ; 补发剪贴板历史入库（OnClipboardChange 在截图等待期间被跳过了）
            savedClip := ScreenshotClipboard
            SetTimer(() => DeferredScreenshotHistorySave(savedClip), -800)
            
            ; 立即自动粘贴截图到 Cursor 输入框
            try {
                PasteScreenshotToCursor()
            } catch as e {
                TrayTip("自动粘贴失败: " . e.Message, GetText("error"), "Iconx 2")
                ScreenshotWaiting := false
                ScreenshotClipboard := ""
            }
        } else {
            ; 截图超时或取消，恢复旧剪贴板
            A_Clipboard := OldClipboard
            ScreenshotWaiting := false
            TrayTip("截图已取消或超时", GetText("tip"), "Iconi 1")
        }
    } catch as e {
        TrayTip("截图失败: " . e.Message, GetText("error"), "Iconx 2")
        ; 尝试恢复旧剪贴板
        try {
            A_Clipboard := OldClipboard
        }
    }
}

; ===================== 自动粘贴截图到 Cursor =====================
PasteScreenshotToCursor() {
    global ScreenshotWaiting, ScreenshotClipboard, CursorPath, AISleepTime
    
    ; 如果不在等待状态或没有截图数据，不执行
    if (!ScreenshotWaiting || !ScreenshotClipboard) {
        return
    }
    
    try {
        ; 检查当前焦点是否在 Cursor 的输入框
        ; 如果 Cursor 窗口已激活，假设焦点可能在输入框，直接尝试粘贴（不改变焦点）
        IsInCursorInput := WinActive("ahk_exe Cursor.exe")
        
        if (IsInCursorInput) {
            ; 焦点在 Cursor，直接粘贴（不等待，立即粘贴，不改变焦点）
            ; 先恢复截图到剪贴板
            try {
                ; 检查系统剪贴板是否有图片数据（可能是用户最新的截图）
                CurrentClipboardHasImage := false
                try {
                    if (DllCall("OpenClipboard", "Ptr", 0)) {
                        if (DllCall("IsClipboardFormatAvailable", "UInt", 2)
                            || DllCall("IsClipboardFormatAvailable", "UInt", 8)
                            || DllCall("IsClipboardFormatAvailable", "UInt", 17)) {
                            CurrentClipboardHasImage := true
                        } else {
                            PNGFormat := DllCall("RegisterClipboardFormat", "Str", "PNG")
                            if (PNGFormat && DllCall("IsClipboardFormatAvailable", "UInt", PNGFormat)) {
                                CurrentClipboardHasImage := true
                            }
                        }
                        DllCall("CloseClipboard")
                    }
                } catch as err {
                }
                
                ; 如果系统剪贴板没有图片，使用保存的数据
                if (!CurrentClipboardHasImage && ScreenshotClipboard) {
                    A_Clipboard := ""
                    Sleep(50)
                    A_Clipboard := ScreenshotClipboard
                    Sleep(200)  ; 短暂等待确保系统识别图片数据
                }
                
                ; 立即粘贴（不等待，不改变焦点）
                Send("^v")
                Sleep(100)  ; 短暂等待确保粘贴完成
                
                ; 停止等待状态
                ScreenshotWaiting := false
                ScreenshotClipboard := ""
                
                ; 显示成功提示
                TrayTip(GetText("screenshot_paste_success"), GetText("tip"), "Iconi 1")
                return
            } catch as e {
                ; 如果直接粘贴失败，继续执行完整流程
            }
        }
        
        ; 如果焦点不在 Cursor 或直接粘贴失败，执行完整的激活和粘贴流程
        ; 确保 Cursor 窗口存在
        if (!WinExist("ahk_exe Cursor.exe")) {
            if (CursorPath != "" && FileExist(CursorPath)) {
                Run(CursorPath)
                Sleep(AISleepTime)
            } else {
                TrayTip("Cursor 未运行且无法启动", GetText("error"), "Iconx 2")
                return
            }
        }
        
        ; 激活 Cursor 窗口（多次尝试确保激活成功）
        WinActivate("ahk_exe Cursor.exe")
        WinWaitActive("ahk_exe Cursor.exe", , 3)
        Sleep(400)  ; 增加等待时间确保窗口完全激活
        
        ; 再次确保 Cursor 窗口激活
        if !WinActive("ahk_exe Cursor.exe") {
            WinActivate("ahk_exe Cursor.exe")
            WinWaitActive("ahk_exe Cursor.exe", , 3)
            Sleep(400)
        }
        
        ; 第三次确保窗口激活（关键步骤）
        if !WinActive("ahk_exe Cursor.exe") {
            WinActivate("ahk_exe Cursor.exe")
            WinWaitActive("ahk_exe Cursor.exe", , 3)
            Sleep(300)
        }
        
        ; 先按 ESC 关闭可能已打开的输入框，避免冲突
        Send("{Esc}")
        Sleep(300)
        
        ; 确保窗口激活（ESC 后可能失去焦点）
        if !WinActive("ahk_exe Cursor.exe") {
            WinActivate("ahk_exe Cursor.exe")
            WinWaitActive("ahk_exe Cursor.exe", , 3)
            Sleep(400)
        }
        
        ; 打开 Cursor 的 AI 聊天面板（Ctrl+L）
        Send("^l")
        Sleep(1000)  ; 增加等待时间确保聊天面板完全打开
        
        ; 再次确保窗口激活（打开聊天面板后可能失去焦点）
        if !WinActive("ahk_exe Cursor.exe") {
            WinActivate("ahk_exe Cursor.exe")
            WinWaitActive("ahk_exe Cursor.exe", , 3)
            Sleep(500)
        }
        
        ; 确保输入框获得焦点
        ; 方法1：按 Tab 键移动到输入框（如果焦点不在输入框上）
        Send("{Tab}")
        Sleep(200)
        
        ; 方法2：再次确保窗口激活
        if !WinActive("ahk_exe Cursor.exe") {
            WinActivate("ahk_exe Cursor.exe")
            WinWaitActive("ahk_exe Cursor.exe", , 2)
            Sleep(300)
        }
        
        ; 方法3：如果 Tab 不起作用，尝试再次按 Ctrl+L 确保聊天面板打开且焦点在输入框
        ; 但先检查一下，如果已经打开了，再次按可能会关闭，所以先按 ESC 再按 Ctrl+L
        Send("{Esc}")
        Sleep(150)
        Send("^l")
        Sleep(600)
        
        ; 最后一次确保窗口激活（粘贴前关键检查）
        if !WinActive("ahk_exe Cursor.exe") {
            WinActivate("ahk_exe Cursor.exe")
            WinWaitActive("ahk_exe Cursor.exe", , 2)
            Sleep(300)
        }
        
        ; 将截图恢复到剪贴板（优先使用系统剪贴板中的最新数据）
        try {
            ; 先检查系统剪贴板是否有图片数据（可能是用户最新的截图）
            CurrentClipboardHasImage := false
            try {
                if (DllCall("OpenClipboard", "Ptr", 0)) {
                    ; 检查是否包含位图格式
                    if (DllCall("IsClipboardFormatAvailable", "UInt", 2)) {  ; CF_BITMAP = 2
                        CurrentClipboardHasImage := true
                    } else if (DllCall("IsClipboardFormatAvailable", "UInt", 8)) {  ; CF_DIB = 8
                        CurrentClipboardHasImage := true
                    } else if (DllCall("IsClipboardFormatAvailable", "UInt", 17)) {  ; CF_DIBV5 = 17
                        CurrentClipboardHasImage := true
                    } else {
                        ; 检查 PNG 格式
                        PNGFormat := DllCall("RegisterClipboardFormat", "Str", "PNG")
                        if (PNGFormat && DllCall("IsClipboardFormatAvailable", "UInt", PNGFormat)) {
                            CurrentClipboardHasImage := true
                        }
                    }
                    DllCall("CloseClipboard")
                }
            } catch as err {
                ; 检查失败，忽略，继续使用保存的数据
            }
            
            ; 如果系统剪贴板中有图片，优先使用最新的（用户可能进行了新的截图）
            if (CurrentClipboardHasImage) {
                ; 使用系统剪贴板中的最新截图数据
                ; 不需要恢复，直接使用当前剪贴板
                Sleep(200) ; 短暂等待确保剪贴板数据稳定
            } else if (ScreenshotClipboard) {
                ; 系统剪贴板没有图片，使用之前保存的数据
                ; 先清空剪贴板
                A_Clipboard := ""
                Sleep(150)
                
                ; 恢复 ClipboardAll 数据（图片数据）
                A_Clipboard := ScreenshotClipboard
                Sleep(1000) ; 增加延迟确保系统识别图片数据并准备好
                
                ; 验证数据是否成功恢复
                if (!DllCall("OpenClipboard", "Ptr", 0)) {
                    ; 如果无法打开剪贴板，再等待一次
                    Sleep(500)
                } else {
                    DllCall("CloseClipboard")
                }
            } else {
                throw Error("没有可用的截图数据")
            }
            
            ; 验证剪贴板是否包含图片数据（需要先打开剪贴板）
            IsImage := false
            if (DllCall("OpenClipboard", "Ptr", 0)) {
                try {
                    ; 检查是否包含位图格式
                    if (DllCall("IsClipboardFormatAvailable", "UInt", 2)) {  ; CF_BITMAP = 2
                        IsImage := true
                    } else if (DllCall("IsClipboardFormatAvailable", "UInt", 8)) {  ; CF_DIB = 8
                        IsImage := true
                    } else if (DllCall("IsClipboardFormatAvailable", "UInt", 17)) {  ; CF_DIBV5 = 17
                        IsImage := true
                    } else {
                        ; 检查 PNG 格式
                        PNGFormat := DllCall("RegisterClipboardFormat", "Str", "PNG")
                        if (PNGFormat && DllCall("IsClipboardFormatAvailable", "UInt", PNGFormat)) {
                            IsImage := true
                        }
                    }
                } finally {
                    DllCall("CloseClipboard")
                }
            }
            
            if (!IsImage) {
                ; 如果图片数据未准备好，再等待一次并重新检查
                Sleep(500)
                if (DllCall("OpenClipboard", "Ptr", 0)) {
                    try {
                        if (DllCall("IsClipboardFormatAvailable", "UInt", 2)
                            || DllCall("IsClipboardFormatAvailable", "UInt", 8)
                            || DllCall("IsClipboardFormatAvailable", "UInt", 17)) {
                            IsImage := true
                        } else {
                            PNGFormat := DllCall("RegisterClipboardFormat", "Str", "PNG")
                            if (PNGFormat && DllCall("IsClipboardFormatAvailable", "UInt", PNGFormat)) {
                                IsImage := true
                            }
                        }
                    } finally {
                        DllCall("CloseClipboard")
                    }
                }
                
                if (!IsImage) {
                    throw Error("剪贴板中未检测到图片数据，截图可能已失效")
                }
            }
        } catch as e {
            throw Error("无法恢复截图到剪贴板: " . e.Message)
        }
        
        ; 恢复剪贴板后，再次确保窗口激活（恢复操作可能影响焦点）
        if !WinActive("ahk_exe Cursor.exe") {
            WinActivate("ahk_exe Cursor.exe")
            WinWaitActive("ahk_exe Cursor.exe", , 1)
            Sleep(300)
        }
        
        ; 最后一次确保窗口激活（粘贴前关键检查）
        if !WinActive("ahk_exe Cursor.exe") {
            WinActivate("ahk_exe Cursor.exe")
            WinWaitActive("ahk_exe Cursor.exe", , 1)
            Sleep(200)
        }
        
        ; 确保输入框获得焦点（粘贴前最后检查）
        ; 再次确保窗口激活
        if !WinActive("ahk_exe Cursor.exe") {
            WinActivate("ahk_exe Cursor.exe")
            WinWaitActive("ahk_exe Cursor.exe", , 2)
            Sleep(300)
        }
        
        ; 使用 Ctrl+V 粘贴（只使用一种方式，避免重复粘贴）
        ; 在粘贴前，再次确保焦点在输入框（通过发送一个字符然后删除）
        ; 这样可以确保输入框确实获得了焦点
        Send("{Home}")  ; 移动到输入框开头（如果焦点在输入框，这会生效）
        Sleep(100)
        
        ; 执行粘贴
        Send("^v")
        Sleep(600)  ; 等待粘贴完成（图片粘贴可能需要更长时间）
        
        ; 停止等待状态
        ScreenshotWaiting := false
        
        ; 清空截图数据
        ScreenshotClipboard := ""
        
        ; 显示成功提示
        TrayTip(GetText("screenshot_paste_success"), GetText("tip"), "Iconi 1")
    } catch as e {
        TrayTip("粘贴截图失败: " . e.Message, GetText("error"), "Iconx 2")
        ; 即使失败，也停止等待状态
        ScreenshotWaiting := false
        ScreenshotClipboard := ""
    }
}

; ===================== 从悬浮面板粘贴截图（已废弃，保留用于兼容）=====================
PasteScreenshotFromButton(*) {
    ; 直接调用自动粘贴函数
    PasteScreenshotToCursor()
}

; ===================== 显示截图悬浮面板 =====================
ShowScreenshotButton() {
    global GuiID_ScreenshotButton, ScreenshotButtonVisible, UI_Colors, ThemeMode
    
    try {
        ; 如果面板已显示，先隐藏
        if (ScreenshotButtonVisible && GuiID_ScreenshotButton != 0) {
            try {
                GuiID_ScreenshotButton.Destroy()
            } catch as err {
            }
            GuiID_ScreenshotButton := 0
        }
        
        ; 确保 UI_Colors 已初始化
        if (!IsSet(UI_Colors) || !UI_Colors) {
            ; 如果未初始化，使用默认颜色
            global ThemeMode
            if (!IsSet(ThemeMode)) {
                ThemeMode := "dark"
            }
            ApplyTheme(ThemeMode)
        }
        
        ; 创建悬浮面板 GUI（参考其他面板的创建方式）
        GuiID_ScreenshotButton := Gui("+AlwaysOnTop +ToolWindow -Caption -DPIScale")
        GuiID_ScreenshotButton.BackColor := UI_Colors.Background
        
        ; 面板尺寸
        PanelWidth := 160
        PanelHeight := 60
        
        ; 计算面板位置（优先显示在 Cursor 窗口正中间，并确保在同一屏幕）
        global ScreenshotPanelX, ScreenshotPanelY, ConfigFile
        PanelX := -1
        PanelY := -1
        
        ; 尝试获取 Cursor 窗口位置和大小，并确定其所在的屏幕
        if (WinExist("ahk_exe Cursor.exe")) {
            try {
                WinGetPos(&CursorX, &CursorY, &CursorW, &CursorH, "ahk_exe Cursor.exe")
                ; 获取 Cursor 窗口所在的屏幕索引
                CursorScreenIndex := GetWindowScreenIndex("ahk_exe Cursor.exe")
                ScreenInfo := GetScreenInfo(CursorScreenIndex)
                
                ; 计算 Cursor 窗口中心位置（相对于其所在屏幕）
                CursorCenterX := CursorX + CursorW // 2
                CursorCenterY := CursorY + CursorH // 2
                
                ; 确保中心点在屏幕范围内
                if (CursorCenterX >= ScreenInfo.Left && CursorCenterX < ScreenInfo.Right && 
                    CursorCenterY >= ScreenInfo.Top && CursorCenterY < ScreenInfo.Bottom) {
                    ; 计算面板位置（Cursor 窗口中心）
                    PanelX := CursorCenterX - PanelWidth // 2
                    PanelY := CursorCenterY - PanelHeight // 2
                    
                    ; 确保面板完全在屏幕范围内
                    if (PanelX < ScreenInfo.Left) {
                        PanelX := ScreenInfo.Left + 10
                    }
                    if (PanelY < ScreenInfo.Top) {
                        PanelY := ScreenInfo.Top + 10
                    }
                    if (PanelX + PanelWidth > ScreenInfo.Right) {
                        PanelX := ScreenInfo.Right - PanelWidth - 10
                    }
                    if (PanelY + PanelHeight > ScreenInfo.Bottom) {
                        PanelY := ScreenInfo.Bottom - PanelHeight - 10
                    }
                }
            } catch as err {
                ; 如果获取失败，使用保存的位置或屏幕中心
            }
        }
        
        ; 如果 Cursor 窗口不存在或获取失败，使用保存的位置
        if (PanelX = -1 || PanelY = -1) {
            ; 从配置文件读取上次保存的位置
            ScreenshotPanelX := IniRead(ConfigFile, "Screenshot", "PanelX", "-1")
            ScreenshotPanelY := IniRead(ConfigFile, "Screenshot", "PanelY", "-1")
            
            if (ScreenshotPanelX != "-1" && ScreenshotPanelY != "-1") {
                PanelX := Integer(ScreenshotPanelX)
                PanelY := Integer(ScreenshotPanelY)
                
                ; 验证保存的位置是否在有效屏幕范围内
                ; 如果不在，使用主屏幕中心
                ValidPosition := false
                MonitorCount := MonitorGetCount()
                Loop MonitorCount {
                    MonitorIndex := A_Index
                    MonitorGet(MonitorIndex, &Left, &Top, &Right, &Bottom)
                    if (PanelX >= Left && PanelX < Right && PanelY >= Top && PanelY < Bottom) {
                        ValidPosition := true
                        break
                    }
                }
                
                if (!ValidPosition) {
                    ; 位置无效，使用主屏幕中心
                    ScreenInfo := GetScreenInfo(1)
                    PanelX := ScreenInfo.Left + (ScreenInfo.Width - PanelWidth) // 2
                    PanelY := ScreenInfo.Top + (ScreenInfo.Height - PanelHeight) // 2
                }
            } else {
                ; 如果也没有保存的位置，使用主屏幕中心
                ScreenInfo := GetScreenInfo(1)
                PanelX := ScreenInfo.Left + (ScreenInfo.Width - PanelWidth) // 2
                PanelY := ScreenInfo.Top + (ScreenInfo.Height - PanelHeight) // 2
            }
        }
        
        ; 创建按钮（先创建按钮，确保可以点击）
        ButtonText := GetText("screenshot_button_text")
        ButtonWidth := PanelWidth - 20
        ButtonHeight := 40
        ButtonX := 10
        ButtonY := 10
        
        ; 创建按钮（确保按钮可以点击）
        ; 添加 SS_NOTIFY (0x100) 确保 Text 控件响应点击
        ScreenshotBtn := GuiID_ScreenshotButton.Add("Text", "x" . ButtonX . " y" . ButtonY . " w" . ButtonWidth . " h" . ButtonHeight . " Center 0x200 +0x100 cFFFFFF Background" . UI_Colors.BtnPrimary . " vScreenshotBtn", ButtonText)
        ScreenshotBtn.SetFont("s11 Bold", "Segoe UI")
        ; 绑定点击事件（直接绑定函数，不使用闭包）
        ScreenshotBtn.OnEvent("Click", PasteScreenshotFromButton)
        
        ; 在按钮右上角添加拖动柄（显示一个拖动图标）
        DragHandleSize := 20
        DragHandleX := ButtonX + ButtonWidth - DragHandleSize - 2
        DragHandleY := ButtonY + 2
        ; 使用半透明背景，让拖动柄更明显
        DragHandleBg := (ThemeMode = "light") ? "E0E0E0" : "404040"
        DragHandle := GuiID_ScreenshotButton.Add("Text", "x" . DragHandleX . " y" . DragHandleY . " w" . DragHandleSize . " h" . DragHandleSize . " Center 0x200 cFFFFFF Background" . DragHandleBg . " vDragHandle", "☰")
        DragHandle.SetFont("s12 Bold", "Segoe UI")
        DragHandle.OnEvent("Click", (*) => PostMessage(0xA1, 2, , , GuiID_ScreenshotButton.Hwnd))
        ; 注意：Text 控件不支持 MouseMove/MouseLeave 事件，所以使用固定背景色
        
        ; 创建可拖动的背景区域（后创建，在按钮下方，但不覆盖按钮）
        ; 创建多个拖动区域，覆盖按钮周围的区域
        ; 顶部拖动区域
        DragAreaTop := GuiID_ScreenshotButton.Add("Text", "x0 y0 w" . PanelWidth . " h" . ButtonY . " BackgroundTrans")
        DragAreaTop.OnEvent("Click", (*) => PostMessage(0xA1, 2, , , GuiID_ScreenshotButton.Hwnd))
        ; 左侧拖动区域
        DragAreaLeft := GuiID_ScreenshotButton.Add("Text", "x0 y" . ButtonY . " w" . ButtonX . " h" . ButtonHeight . " BackgroundTrans")
        DragAreaLeft.OnEvent("Click", (*) => PostMessage(0xA1, 2, , , GuiID_ScreenshotButton.Hwnd))
        ; 右侧拖动区域（不包括拖动柄区域）
        DragAreaRight := GuiID_ScreenshotButton.Add("Text", "x" . (ButtonX + ButtonWidth) . " y" . ButtonY . " w" . (PanelWidth - ButtonX - ButtonWidth) . " h" . ButtonHeight . " BackgroundTrans")
        DragAreaRight.OnEvent("Click", (*) => PostMessage(0xA1, 2, , , GuiID_ScreenshotButton.Hwnd))
        ; 底部拖动区域
        DragAreaBottom := GuiID_ScreenshotButton.Add("Text", "x0 y" . (ButtonY + ButtonHeight) . " w" . PanelWidth . " h" . (PanelHeight - ButtonY - ButtonHeight) . " BackgroundTrans")
        DragAreaBottom.OnEvent("Click", (*) => PostMessage(0xA1, 2, , , GuiID_ScreenshotButton.Hwnd))
        
        ; 添加悬停效果
        HoverBtn(ScreenshotBtn, UI_Colors.BtnPrimary, UI_Colors.BtnHover)
        
        ; 使用定时器定期保存位置（因为 AutoHotkey v2 不支持 Move 事件）
        SetTimer(SaveScreenshotPanelPosition, 500)  ; 每500ms检查一次位置
        
        ; 显示面板（在 Show 中设置大小和位置）
        GuiID_ScreenshotButton.Show("w" . PanelWidth . " h" . PanelHeight . " x" . PanelX . " y" . PanelY . " NoActivate")
        ScreenshotButtonVisible := true
        
        ; 确保窗口始终置顶（使用 WinSetAlwaysOnTop）
        WinSetAlwaysOnTop(1, GuiID_ScreenshotButton.Hwnd)
        
        ; 设置工具提示
        try {
            ; 使用 ToolTip 显示提示
            ToolTip(GetText("screenshot_button_tip"), PanelX + PanelWidth // 2, PanelY - 30)
            SetTimer(() => ToolTip(), -3000)  ; 3秒后自动隐藏提示
        } catch as err {
        }
    } catch as e {
        ; 如果创建失败，显示错误信息
        TrayTip("创建悬浮面板失败: " . e.Message, GetText("error"), "Iconx 2")
        throw e
    }
}

; ===================== 隐藏截图悬浮面板 =====================
HideScreenshotButton() {
    global GuiID_ScreenshotButton, ScreenshotButtonVisible
    
    ; 停止定时器
    SetTimer(SaveScreenshotPanelPosition, 0)
    
    ; 在隐藏前保存位置
    SaveScreenshotPanelPosition()
    
    if (GuiID_ScreenshotButton != 0) {
        try {
            ; 确保窗口被销毁
            GuiID_ScreenshotButton.Destroy()
        } catch as err {
            ; 如果销毁失败，尝试强制关闭
            try {
                WinClose("ahk_id " . GuiID_ScreenshotButton.Hwnd)
            } catch as err {
            }
        }
        GuiID_ScreenshotButton := 0
    }
    ScreenshotButtonVisible := false
}

; ===================== 截图面板拖动处理 =====================
ScreenshotPanelDragHandler(*) {
    global GuiID_ScreenshotButton
    if (GuiID_ScreenshotButton != 0) {
        PostMessage(0xA1, 2, , GuiID_ScreenshotButton.Hwnd)  ; WM_NCLBUTTONDOWN
    }
}

; ===================== 保存截图面板位置 =====================
SaveScreenshotPanelPosition(*) {
    global GuiID_ScreenshotButton, ScreenshotPanelX, ScreenshotPanelY, ConfigFile, ScreenshotButtonVisible
    
    ; 只在面板可见时保存位置
    if (GuiID_ScreenshotButton != 0 && ScreenshotButtonVisible) {
        try {
            ; 获取窗口当前位置
            WinGetPos(&X, &Y, , , "ahk_id " . GuiID_ScreenshotButton.Hwnd)
            if (X >= 0 && Y >= 0) {  ; 确保位置有效
                ScreenshotPanelX := X
                ScreenshotPanelY := Y
                
                ; 保存到配置文件
                IniWrite(ScreenshotPanelX, ConfigFile, "Screenshot", "PanelX")
                IniWrite(ScreenshotPanelY, ConfigFile, "Screenshot", "PanelY")
            }
        } catch as err {
            ; 忽略保存失败
        }
    }
}

; ===================== 停止截图等待 =====================
StopScreenshotWaiting() {
    global ScreenshotWaiting, ScreenshotCheckTimer
    
    if (ScreenshotWaiting) {
        ScreenshotWaiting := false
        HideScreenshotButton()
        ; 移除超时提示（按用户要求，不显示任何提示）
    }
}
