; ScreenshotEditorPlugin.ahk — 截图助手（类封装，由主脚本 #Include）
; 状态为 ScreenshotEditorPlugin 的 static 字段；Hub 同步少量全局供 LegacyConfigGui。

class ScreenshotEditorPlugin {

    static g_ShowScreenshotEditorInFlight := false
    static GuiID_ScreenshotEditor := 0
    static GuiID_ScreenshotToolbar := 0
    static ScreenshotToolbarWV2Ctrl := 0
    static ScreenshotToolbarWV2 := 0
    static ScreenshotToolbarWV2Ready := false
    static ScreenshotToolbarWV2PaintOk := false
    static ScreenshotToolbarNativeFallback := false
    static ScreenshotToolbarCurrentWidth := 520
    static ScreenshotToolbarCurrentHeight := 56
    static ScreenshotOCRHubPendingText := ""
    static ScreenshotOCRHubPushAttempts := 0
    static ScreenshotOCRHubPushInFlight := false
    static ScreenshotEditorBitmap := 0
    static ScreenshotEditorGraphics := 0
    static ScreenshotEditorImagePath := ""
    static ScreenshotEditorTitleBarHeight := 30
    static ScreenshotEditorZoomScale := 1.0
    static ScreenshotEditorZoomMin := 0.2
    static ScreenshotEditorZoomMax := 4.0
    static ScreenshotEditorBaseWidth := 0
    static ScreenshotEditorBaseHeight := 0
    static GuiID_ScreenshotZoomTip := 0
    static ScreenshotZoomTipTextCtrl := 0
    static ScreenshotEditorAlwaysOnTop := true
    static ScreenshotEditorTitleBar := 0
    static ScreenshotEditorCloseBtn := 0
    static ScreenshotEditorToolbarVisible := true
    static ScreenshotEditorIsDraggingWindow := false
    static ScreenshotToolbarHoverItems := []
    static ScreenshotToolbarHoverTipLastKey := ""
    static GuiID_ScreenshotToolbarTip := 0
    static ScreenshotToolbarTipTextCtrl := 0
    static ScreenshotOCRTextLayoutMode := "auto"
    static ScreenshotOCRPunctuationMode := "keep"
    static ScreenshotOCRDirectCopyEnabled := false
    static ScreenshotColorPickerActive := false
    static GuiID_ScreenshotColorPicker := 0
    static ScreenshotColorPickerMagnifierPic := 0
    static ScreenshotColorPickerCurrentText := 0
    static ScreenshotColorPickerCompareText := 0
    static ScreenshotColorPickerHistoryEdit := 0
    static ScreenshotColorPickerCurrent := Map()
    static ScreenshotColorPickerAnchor := Map()
    static ScreenshotColorPickerHistory := []
    static ScreenshotColorPickerTickBusy := false
    static ScreenshotEditorPreviewBitmap := 0
    static ScreenshotEditorPreviewWidth := 0
    static ScreenshotEditorPreviewHeight := 0
    static ScreenshotEditorImgWidth := 0
    static ScreenshotEditorImgHeight := 0
    static ScreenshotEditorPreviewPic := 0
    static ScreenshotEditorMode := ""

    static IsScreenshotEditorActive() {
    try {
        if !(IsObject(this.GuiID_ScreenshotEditor) && this.GuiID_ScreenshotEditor != 0)
            return false
        hwnd := this.GuiID_ScreenshotEditor.Hwnd
        if !hwnd
            return false
        return !!WinExist("ahk_id " . hwnd)
    } catch {
        return false
    }
}

    static IsScreenshotEditorZoomHotkeyActive() {
    if !this.IsScreenshotEditorActive()
        return false
    ; 仅在置顶隐藏工具栏模式下启用滚轮缩放
    if (this.ScreenshotEditorToolbarVisible)
        return false
    try {
        MouseGetPos(, , &hoverHwnd)
        if !hoverHwnd
            return false
        ; 鼠标位于截图助手窗口或其子控件上均允许缩放
        return (hoverHwnd = this.GuiID_ScreenshotEditor.Hwnd) || DllCall("user32\IsChild", "ptr", this.GuiID_ScreenshotEditor.Hwnd, "ptr", hoverHwnd, "int")
    }
    catch {
        return false
    }
}

    static HandleScreenshotEditorHotkey(ActionType) {
    if !this.IsScreenshotEditorActive()
        return false
    switch ActionType {
        case "Q":
            this.ToggleScreenshotEditorAlwaysOnTop()
            return true
        case "E":
            this.ExecuteScreenshotOCR()
            return true
        case "C":
            this.PasteScreenshotAsText()
            return true
        case "R":
            this.SaveScreenshotToFile()
            return true
        case "Z":
            this.ScreenshotEditorSendToAI()
            return true
        case "F":
            this.ScreenshotEditorSearchText()
            return true
        case "X":
            this.ScreenshotEditorToggleColorPicker()
            return true
        case "ESC":
            this.CloseScreenshotEditor()
            return true
    }
    return false
}

; ===================== 截图助手预览窗 =====================

    static SafeGdipDisposeImage(pBitmap) {
    if (!pBitmap || pBitmap = 0)
        return
    try Gdip_DisposeImage(pBitmap)
    catch {
    }
}

    static SafeGdipDeleteGraphics(pGraphics) {
    if (!pGraphics || pGraphics = 0)
        return
    try Gdip_DeleteGraphics(pGraphics)
    catch {
    }
}

; 检查可能有干扰的剪贴板工具
    static CheckInterferingClipboardTools() {
    ; 常见的剪贴板增强工具
    clipboardTools := ["ClipX.exe", "Ditto.exe", "PowerClipboard.exe", "ARClipboard.exe", "Clipboardic.exe"]
    
    for tool in clipboardTools {
        if (ProcessExist(tool)) {
            OutputDebug("[Screenshot] 检测到可能干扰的剪贴板工具: " . tool)
            ; 记录到日志
            try {
                FileAppend("[" . A_Now . "] 检测到剪贴板工具: " . tool . "`n", A_ScriptDir . "\cache\screenshot_interference.log")
            } catch {
            }
        }
    }
}

; 关闭可能残留的截图窗口（包含本脚本与系统截图工具）
    static CloseAllScreenshotWindows() {
    global GuiID_ScreenshotButton, ScreenshotButtonVisible

    ; 先关闭我们自己的截图相关窗口（仅当全局为真实 Gui 对象时，避免误把整数当窗口关闭）
    try {
        if (IsObject(this.GuiID_ScreenshotEditor)) {
            this.CloseScreenshotEditor()
        }
    } catch as e {
    }

    try {
        if (ScreenshotButtonVisible) {
            HideScreenshotButton()
        } else if (GuiID_ScreenshotButton != 0) {
            if (IsObject(GuiID_ScreenshotButton)) {
                GuiID_ScreenshotButton.Destroy()
            } else if (GuiID_ScreenshotButton.HasProp("Hwnd") && GuiID_ScreenshotButton.Hwnd) {
                WinClose("ahk_id " . GuiID_ScreenshotButton.Hwnd)
            }
            GuiID_ScreenshotButton := 0
        }
    } catch as e {
    }

    ; 尝试关闭常见的系统截图工具窗口
    winTargets := [
        "ahk_exe SnippingTool.exe",
        "ahk_exe ScreenClippingHost.exe",
        "ahk_exe SnipAndSketch.exe",
        "ahk_exe ScreenSketch.exe",
        "ahk_class ScreenClippingHostWindow",
        "ahk_class SnippingTool"
    ]

    for _, target in winTargets {
        try {
            if (WinExist(target)) {
                WinClose(target)
            }
        } catch as e {
        }
    }
}

; 显示截图助手预览窗
    static ShowScreenshotEditor(DebugGui := 0) {
    global ScreenshotClipboard, UI_Colors, ThemeMode
    
    ; 初始化局部变量
    pToken := 0
    hBitmap := 0
    pBitmap := 0
    ImgWidth := 0
    ImgHeight := 0
    pPreviewBitmap := 0
    pGraphics := 0
    
    prevCrit := Critical("On")
    if (this.g_ShowScreenshotEditorInFlight) {
        Critical(prevCrit)
        return
    }
    this.g_ShowScreenshotEditorInFlight := true
    Critical(prevCrit)
    try {
        if (DebugGui) {
            UpdateDebugStep(DebugGui, 14, "ShowScreenshotEditor: 开始执行...", false)
        }
        
        ; 如果预览窗已存在，先关闭并清理旧资源，确保每次都是新截图
        if (DebugGui) {
            UpdateDebugStep(DebugGui, 15, "检查预览窗是否已存在...", false)
        }
        if (IsObject(this.GuiID_ScreenshotEditor)) {
            if (DebugGui) {
                UpdateDebugStep(DebugGui, 15, "发现旧的预览窗，正在关闭并清理资源...", false)
            }
            ; 关闭旧窗口并清理所有资源，确保每次都是新截图
            this.CloseScreenshotEditor()
            if (DebugGui) {
                UpdateDebugStep(DebugGui, 15, "旧预览窗已关闭，资源已清理", true)
            }
        } else {
            if (DebugGui) {
                UpdateDebugStep(DebugGui, 15, "预览窗不存在，继续", true)
            }
        }
        
        ; 初始化GDI+
        if (DebugGui) {
            UpdateDebugStep(DebugGui, 16, "初始化 GDI+...", false)
        }
        try {
            pToken := Gdip_Startup()
            if (!pToken) {
                if (DebugGui) {
                    UpdateDebugStep(DebugGui, 16, "GDI+ 初始化失败: pToken 为空", false)
                }
                TrayTip("错误", "无法初始化GDI+", "Iconx 2")
                return
            }
            if (DebugGui) {
                UpdateDebugStep(DebugGui, 16, "GDI+ 初始化成功，pToken: " . pToken, true)
            }
        } catch as e {
            if (DebugGui) {
                UpdateDebugStep(DebugGui, 16, "GDI+ 初始化异常: " . e.Message, false)
            }
            TrayTip("错误", "初始化GDI+失败: " . e.Message, "Iconx 2")
            return
        }
        
        ; 如果ScreenshotClipboard存在，先恢复它到剪贴板
        if (DebugGui) {
            UpdateDebugStep(DebugGui, 17, "检查 ScreenshotClipboard...", false)
        }
        if (ScreenshotClipboard) {
            if (DebugGui) {
                UpdateDebugStep(DebugGui, 17, "ScreenshotClipboard 存在，恢复到剪贴板...", false)
            }
            try {
                A_Clipboard := ScreenshotClipboard
                Sleep(300)
                if (DebugGui) {
                    UpdateDebugStep(DebugGui, 17, "剪贴板已恢复", true)
                }
            } catch as e {
                if (DebugGui) {
                    UpdateDebugStep(DebugGui, 17, "恢复失败: " . e.Message, false)
                }
                TrayTip("错误", "恢复截图到剪贴板失败: " . e.Message, "Iconx 2")
                try {
                    Gdip_Shutdown(pToken)
                } catch as e2 {
                }
                return
            }
        } else {
            if (DebugGui) {
                UpdateDebugStep(DebugGui, 17, "ScreenshotClipboard 为空，跳过", true)
            }
        }
        
        ; 直接使用 Gdip 从剪贴板创建位图，失败时回退到 ImagePut
        if (DebugGui) {
            UpdateDebugStep(DebugGui, 18, "使用 Gdip_CreateBitmapFromClipboard()...", false)
        }
        try {
            pBitmap := Gdip_CreateBitmapFromClipboard()
            if (!pBitmap || pBitmap = 0) {
                pBitmap := ImagePutBitmap(A_Clipboard)
                if (DebugGui) {
                    UpdateDebugStep(DebugGui, 18, "Gdip 返回空，已回退到 ImagePutBitmap()", !!pBitmap)
                }
            }
            if (DebugGui) {
                UpdateDebugStep(DebugGui, 18, "成功，pBitmap: " . (pBitmap ? pBitmap : "空"), true)
            }
        } catch as e {
            if (DebugGui) {
                UpdateDebugStep(DebugGui, 18, "Gdip 失败，尝试 ImagePutBitmap(): " . e.Message, false)
            }
            try {
                pBitmap := ImagePutBitmap(A_Clipboard)
                if (DebugGui) {
                    UpdateDebugStep(DebugGui, 18, "ImagePutBitmap() 结果: " . (pBitmap ? "成功" : "失败"), !!pBitmap)
                }
            } catch as e2 {
                if (DebugGui) {
                    UpdateDebugStep(DebugGui, 18, "ImagePutBitmap() 失败: " . e2.Message, false)
                }
            }
            if (!pBitmap || pBitmap = 0) {
                TrayTip("错误", "从剪贴板创建位图失败: " . e.Message, "Iconx 2")
                try {
                    Gdip_Shutdown(pToken)
                } catch as e3 {
                }
                return
            }
        }
        
        ; 验证pBitmap是否有效
        if (DebugGui) {
            UpdateDebugStep(DebugGui, 19, "验证 pBitmap 有效性...", false)
        }
        if (!pBitmap || pBitmap = 0) {
            if (DebugGui) {
                UpdateDebugStep(DebugGui, 19, "pBitmap 无效", false)
            }
            TrayTip("错误", "无法从剪贴板获取图片。请确保已成功截图。", "Iconx 2")
            try {
                Gdip_Shutdown(pToken)
            } catch as e {
            }
            return
        }
        if (DebugGui) {
            UpdateDebugStep(DebugGui, 19, "pBitmap 验证通过: " . pBitmap, true)
        }
        
        ; 获取位图尺寸（先用 Gdip_All 封装，失败再 DllCall 兜底）
        if (DebugGui) {
            UpdateDebugStep(DebugGui, 22, "获取位图尺寸...", false)
        }
        ImgWidth := 0
        ImgHeight := 0
        SizeGetOk := false
        ; 某些系统下截图写入剪贴板存在短暂延迟，给一次重试窗口提升稳定性
        Loop 2 {
            try {
                ImgWidth := Gdip_GetImageWidth(pBitmap)
                ImgHeight := Gdip_GetImageHeight(pBitmap)
                SizeGetOk := (ImgWidth > 0 && ImgHeight > 0)
            } catch as e {
                SizeGetOk := false
            }

            if (!SizeGetOk) {
                try {
                    resultW := DllCall("gdiplus\GdipGetImageWidth", "Ptr", pBitmap, "UInt*", &ImgWidth)
                    resultH := DllCall("gdiplus\GdipGetImageHeight", "Ptr", pBitmap, "UInt*", &ImgHeight)
                    SizeGetOk := (resultW = 0 && resultH = 0 && ImgWidth > 0 && ImgHeight > 0)
                } catch as e {
                    SizeGetOk := false
                }
            }

            if (SizeGetOk)
                break
            Sleep(80)
        }

        if (!SizeGetOk) {
            TrayTip("错误", "无法获取位图尺寸（截图数据可能无效）", "Iconx 2")
            this.SafeGdipDisposeImage(pBitmap)
            try {
                Gdip_Shutdown(pToken)
            } catch as e {
                ; 忽略关闭错误
            }
            return
        }
        
        ; 计算预览窗口尺寸（最大800x600，保持宽高比）
        MaxWidth := 800
        MaxHeight := 600
        ScaleX := MaxWidth / ImgWidth
        ScaleY := MaxHeight / ImgHeight
        Scale := ScaleX < ScaleY ? ScaleX : ScaleY
        PreviewWidth := Round(ImgWidth * Scale)
        PreviewHeight := Round(ImgHeight * Scale)
        
        ; 验证计算出的尺寸有效
        if (PreviewWidth <= 0 || PreviewHeight <= 0) {
            TrayTip("错误", "预览尺寸计算失败", "Iconx 2")
            this.SafeGdipDisposeImage(pBitmap)
            try {
                Gdip_Shutdown(pToken)
            } catch as e {
                ; 忽略关闭错误
            }
            return
        }
        
        ; 创建预览位图
        result := DllCall("gdiplus\GdipCreateBitmapFromScan0", "Int", PreviewWidth, "Int", PreviewHeight, "Int", 0, "UInt", 0x26200A, "Ptr", 0, "Ptr*", &pPreviewBitmap := 0)
        if (result != 0 || !pPreviewBitmap || pPreviewBitmap = 0) {
            TrayTip("错误", "无法创建预览位图", "Iconx 2")
            this.SafeGdipDisposeImage(pBitmap)
            try {
                Gdip_Shutdown(pToken)
            } catch as e {
                ; 忽略关闭错误
            }
            return
        }
        
        ; 获取图形上下文
        result := DllCall("gdiplus\GdipGetImageGraphicsContext", "Ptr", pPreviewBitmap, "Ptr*", &pGraphics := 0)
        if (result != 0 || !pGraphics || pGraphics = 0) {
            TrayTip("错误", "无法获取图形上下文", "Iconx 2")
            this.SafeGdipDisposeImage(pPreviewBitmap)
            this.SafeGdipDisposeImage(pBitmap)
            try {
                Gdip_Shutdown(pToken)
            } catch as e {
                ; 忽略关闭错误
            }
            return
        }
        
        ; 设置高质量插值模式并绘制图像
        DllCall("gdiplus\GdipSetInterpolationMode", "Ptr", pGraphics, "Int", 7)  ; HighQualityBicubic
        result := DllCall("gdiplus\GdipDrawImageRect", "Ptr", pGraphics, "Ptr", pBitmap, "Float", 0, "Float", 0, "Float", PreviewWidth, "Float", PreviewHeight)
        if (result != 0) {
            TrayTip("错误", "无法绘制预览图像", "Iconx 2")
            this.SafeGdipDeleteGraphics(pGraphics)
            this.SafeGdipDisposeImage(pPreviewBitmap)
            this.SafeGdipDisposeImage(pBitmap)
            try {
                Gdip_Shutdown(pToken)
            } catch as e {
                ; 忽略关闭错误
            }
            return
        }
        
        ; 保存位图和图形句柄
        this.ScreenshotEditorBitmap := pBitmap
        this.ScreenshotEditorGraphics := pGraphics
        this.ScreenshotEditorPreviewBitmap := pPreviewBitmap
        this.ScreenshotEditorPreviewWidth := PreviewWidth
        this.ScreenshotEditorPreviewHeight := PreviewHeight
        this.ScreenshotEditorBaseWidth := PreviewWidth
        this.ScreenshotEditorBaseHeight := PreviewHeight
        this.ScreenshotEditorZoomScale := 1.0
        this.ScreenshotEditorImgWidth := ImgWidth
        this.ScreenshotEditorImgHeight := ImgHeight
        
        ; 创建GUI（可拖动窗口）
        ; 使用局部 EditorGui 构建，最后再赋给全局 this.GuiID_ScreenshotEditor，避免构建过程中
        ; 全局被其它逻辑清空或未绑定导致 .Show 对整数 0 调用。
        EditorGui := Gui("+AlwaysOnTop +ToolWindow -Caption -DPIScale")
        EditorGui.BackColor := UI_Colors.Background
        EditorGui.SetFont("s10 c" . UI_Colors.Text, "Segoe UI")
        
        ; 窗口尺寸（仅预览区域，工具栏独立悬浮）
        ; 消除黑边：窗口宽度等于图片宽度，高度等于标题栏+图片高度
        TitleBarHeight := 30
        this.ScreenshotEditorTitleBarHeight := TitleBarHeight
        WindowWidth := PreviewWidth
        WindowHeight := TitleBarHeight + PreviewHeight
        
        ; 标题栏（可拖动）
        this.ScreenshotEditorTitleBar := EditorGui.Add("Text", "x0 y0 w" . (WindowWidth - 40) . " h" . TitleBarHeight . " Center Background" . UI_Colors.TitleBar . " c" . UI_Colors.Text, "📷 截图助手")
        this.ScreenshotEditorTitleBar.SetFont("s11 Bold", "Segoe UI")
        ; 添加拖动功能（Text控件只支持Click事件）
        this.ScreenshotEditorTitleBar.OnEvent("Click", ObjBindMethod(ScreenshotEditorPlugin, "ScreenshotEditorDragWindow"))
        
        ; [关闭] 按钮（在标题栏右侧，最后创建以确保在最上层）
        ; 注意：关闭按钮需要在所有其他控件之后创建，以确保它在最上层
        this.ScreenshotEditorCloseBtn := 0
        
        ; 预览区域（使用Picture控件显示，紧贴窗口边缘，无黑边）
        PreviewY := TitleBarHeight
        ; 将位图保存为临时文件用于显示
        TempImagePath := A_Temp "\ScreenshotEditor_" . A_TickCount . ".png"
        try {
            result := Gdip_SaveBitmapToFile(pPreviewBitmap, TempImagePath)
            if (result != 0) {
                throw Error("保存预览图片失败，错误代码: " . result)
            }
        } catch as e {
            TrayTip("错误", "保存预览图片失败: " . e.Message, "Iconx 2")
            this.SafeGdipDeleteGraphics(pGraphics)
            this.SafeGdipDisposeImage(pPreviewBitmap)
            this.SafeGdipDisposeImage(pBitmap)
            try {
                Gdip_Shutdown(pToken)
            } catch as e {
                ; 忽略关闭错误
            }
            return
        }
        PreviewPic := EditorGui.Add("Picture", "x0 y" . PreviewY . " w" . PreviewWidth . " h" . PreviewHeight, TempImagePath)
        
        ; 为图片控件添加拖动功能（Picture控件支持Click事件）
        PreviewPic.OnEvent("Click", (*) => this.ScreenshotEditorDragWindow())
        PreviewPic.OnEvent("ContextMenu", ObjBindMethod(ScreenshotEditorPlugin, "OnScreenshotEditorContextMenu"))
        this.ScreenshotEditorPreviewPic := PreviewPic
        
        ; 创建独立的悬浮工具栏窗口（WebView2 承载独立 HTML）
        this.GuiID_ScreenshotToolbar := Gui("+AlwaysOnTop +ToolWindow -Caption -DPIScale")
        ; 不再使用 TransColor 色键透明：在部分机器/WebView2 组合下会出现点击穿透，导致按钮无法生效
        this.GuiID_ScreenshotToolbar.BackColor := "0a0a0a"
        ToolbarWidth := this.ScreenshotToolbarCurrentWidth
        ToolbarHeight := this.ScreenshotToolbarCurrentHeight
        this.ScreenshotToolbarWV2Ctrl := 0
        this.ScreenshotToolbarWV2 := 0
        this.ScreenshotToolbarWV2Ready := false
        this.ScreenshotToolbarWV2PaintOk := false
        this.ScreenshotToolbarNativeFallback := false
        this.GuiID_ScreenshotToolbar.OnEvent("Size", ObjBindMethod(ScreenshotEditorPlugin, "ScreenshotToolbar_OnSize"))
        try WebView2.create(this.GuiID_ScreenshotToolbar.Hwnd, ObjBindMethod(ScreenshotEditorPlugin, "ScreenshotToolbar_OnCreated"), WebView2_EnsureSharedEnvBlocking())
        
        ; [关闭] 按钮（在标题栏右侧，最后创建以确保在最上层）
        if (!this.ScreenshotEditorCloseBtn || this.ScreenshotEditorCloseBtn = 0) {
            this.ScreenshotEditorCloseBtn := EditorGui.Add("Text", "x" . (WindowWidth - 40) . " y0 w40 h" . TitleBarHeight . " Center 0x200 cFFFFFF Background" . UI_Colors.BtnDanger, "✕")
            this.ScreenshotEditorCloseBtn.SetFont("s12", "Segoe UI")
            this.ScreenshotEditorCloseBtn.OnEvent("Click", (*) => this.CloseScreenshotEditor())
            HoverBtnWithAnimation(this.ScreenshotEditorCloseBtn, UI_Colors.BtnDanger, UI_Colors.BtnDangerHover)
        }
        
        ; 添加键盘事件
        EditorGui.OnEvent("Escape", (*) => this.CloseScreenshotEditor())
        
        ; 与全局同步：此后 CloseScreenshotEditor / 同步工具栏等依赖 this.GuiID_ScreenshotEditor
        this.GuiID_ScreenshotEditor := EditorGui
        ScreenshotEditorPlugin._SyncHub()
        
        ; 计算窗口位置（屏幕居中）
        ScreenInfo := GetScreenInfo(1)
        if (!IsObject(ScreenInfo) || !ScreenInfo.HasProp("Width") || !ScreenInfo.HasProp("Height")) {
            throw Error("无法获取屏幕信息")
        }
        WindowX := (ScreenInfo.Width - WindowWidth) // 2
        WindowY := (ScreenInfo.Height - WindowHeight) // 2
        
        ; 确保所有变量都是数字类型
        WindowX := Integer(WindowX)
        WindowY := Integer(WindowY)
        WindowWidth := Integer(WindowWidth)
        WindowHeight := Integer(WindowHeight)
        
        ; 注意：不可在此处调用 this.CloseAllScreenshotWindows() —— 该函数会 this.CloseScreenshotEditor()，
        ; 刚创建的 this.GuiID_ScreenshotEditor 会被销毁，随后 .Show() 会对整数 0 调用而报错。
        ; 旧预览窗已在函数开头关闭；系统截图工具由调用方在 ShowScreenshotEditor 之前已处理。
        
        ; 强制激活桌面，确保我们的窗口能显示在最前面
        try {
            WinActivate("Program Manager")
            Sleep(50)
        }
        
        ; 显示主窗口
        if (DebugGui) {
            UpdateDebugStep(DebugGui, 23, "显示截图助手窗口...", false)
        }
        ; 使用局部 EditorGui 调用 Show，避免全局变量在极少数情况下非对象时崩溃
        EditorGui.Show("w" . WindowWidth . " h" . WindowHeight . " x" . WindowX . " y" . WindowY)
        
        ; 激活窗口并确保在最前面
        try {
            WinActivate("ahk_id " . EditorGui.Hwnd)
            Sleep(50)
            ; 确保窗口获得焦点
            WinSetAlwaysOnTop("On", "ahk_id " . EditorGui.Hwnd)
            WinSetAlwaysOnTop("Off", "ahk_id " . EditorGui.Hwnd)
        } catch as e {
        }
        
        if (DebugGui) {
            UpdateDebugStep(DebugGui, 23, "截图助手窗口已显示！", true)
        }
        
        ; 计算工具栏位置（放在主窗口下方）
        ToolbarX := WindowX
        ToolbarY := WindowY + WindowHeight + 10
        
        ; 显示悬浮工具栏
        this.GuiID_ScreenshotToolbar.Show("w" . ToolbarWidth . " h" . ToolbarHeight . " x" . ToolbarX . " y" . ToolbarY)
        this.ScreenshotToolbar_NotifyHostMemory(true)
        this.ScreenshotToolbar_ApplyWindowRegion()
        this.ScreenshotToolbar_ApplyBounds()
        SetTimer(ObjBindMethod(ScreenshotEditorPlugin, "ScreenshotToolbar_RefreshComposition"), -40)
        SetTimer(ObjBindMethod(ScreenshotEditorPlugin, "ScreenshotToolbar_EnsureCreated"), -900)
        SetTimer(ObjBindMethod(ScreenshotEditorPlugin, "ScreenshotToolbar_EnsureUsable"), -1200)
        
        ; 激活工具栏窗口
        try {
            WinActivate("ahk_id " . this.GuiID_ScreenshotToolbar.Hwnd)
        } catch as e {
        }
        
        ; 再次激活主窗口确保它在最前面
        Sleep(50)
        try {
            WinActivate("ahk_id " . EditorGui.Hwnd)
        } catch as e {
        }
        
        ; 使用原生 Windows API 确保窗口置顶并激活
        try {
            hwnd := EditorGui.Hwnd
            ; 仅置顶，不移动当前位置（保留前面已计算好的居中坐标）
            DllCall("SetWindowPos", "Ptr", hwnd, "Ptr", -1, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x0001 | 0x0002 | 0x0004)
            DllCall("SetForegroundWindow", "Ptr", hwnd)
            Sleep(50)
            ; 再次确保置顶
            DllCall("SetWindowPos", "Ptr", hwnd, "Ptr", -1, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x0001 | 0x0002 | 0x0004)
        } catch as e {
        }
        
        ; 同时也激活工具栏窗口
        try {
            toolbarHwnd := this.GuiID_ScreenshotToolbar.Hwnd
            ; 工具栏同样只置顶，不重置到左上角
            DllCall("SetWindowPos", "Ptr", toolbarHwnd, "Ptr", -1, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x0001 | 0x0002 | 0x0004)
        } catch as e {
        }
        
        ; 初始化编辑状态
        
        ; 保存临时图片路径
        this.ScreenshotEditorImagePath := TempImagePath
        
    } catch as e {
        ; 显示详细的错误诊断信息
        this.ShowScreenshotErrorDiagnostics(e)
        this.CloseScreenshotEditor()
    } finally {
        this.g_ShowScreenshotEditorInFlight := false
    }
}

; 显示截图助手错误诊断信息
    static ShowScreenshotErrorDiagnostics(e) {
    global ScreenshotClipboard
    
    ; 收集诊断信息
    ErrorInfo := "【错误诊断报告】`n`n"
    ErrorInfo .= "═══════════════════════════════════════`n"
    ErrorInfo .= "错误消息: " . e.Message . "`n"
    ErrorInfo .= "错误文件: " . (e.File ? e.File : "未知") . "`n"
    ErrorInfo .= "错误行号: " . (e.Line ? e.Line : "未知") . "`n"
    ErrorInfo .= "═══════════════════════════════════════`n`n"
    
    ; 检查关键变量状态
    ErrorInfo .= "【关键变量状态】`n"
    ErrorInfo .= "───────────────────────────────────────`n"
    ErrorInfo .= "ScreenshotClipboard: " . (ScreenshotClipboard ? "已设置 (长度: " . (IsObject(ScreenshotClipboard) ? "对象" : StrLen(String(ScreenshotClipboard))) . ")" : "未设置") . "`n"
    ; 修复：this.GuiID_ScreenshotEditor 是Gui对象，不能直接用于字符串连接
    if (this.GuiID_ScreenshotEditor && IsObject(this.GuiID_ScreenshotEditor)) {
        ErrorInfo .= "this.GuiID_ScreenshotEditor: 已创建 (Hwnd: " . (this.GuiID_ScreenshotEditor.Hwnd ? this.GuiID_ScreenshotEditor.Hwnd : "未知") . ")`n"
    } else {
        ErrorInfo .= "this.GuiID_ScreenshotEditor: " . (this.GuiID_ScreenshotEditor ? String(this.GuiID_ScreenshotEditor) : "0 (未创建)") . "`n"
    }
    ErrorInfo .= "this.ScreenshotEditorBitmap: " . (this.ScreenshotEditorBitmap ? this.ScreenshotEditorBitmap : "0 (未创建)") . "`n"
    ErrorInfo .= "this.ScreenshotEditorGraphics: " . (this.ScreenshotEditorGraphics ? this.ScreenshotEditorGraphics : "0 (未创建)") . "`n"
    ErrorInfo .= "───────────────────────────────────────`n`n"
    
    ; 可能的原因分析
    ErrorInfo .= "【可能的原因分析】`n"
    ErrorInfo .= "───────────────────────────────────────`n"
    
    ; 检查是否是 GDI+ 相关错误
    if (InStr(e.Message, "GDI") || InStr(e.Message, "Gdip") || InStr(e.Message, "gdiplus")) {
        ErrorInfo .= "❌ GDI+ 库相关错误`n"
        ErrorInfo .= "   - 可能原因: Gdip_Startup() 失败或库未正确加载`n"
        ErrorInfo .= "   - 检查点: 确认 gdiplus.dll 是否可用`n"
        ErrorInfo .= "   - 建议: 重启脚本或检查系统 GDI+ 支持`n`n"
    }
    
    ; 检查是否是剪贴板相关错误
    if (InStr(e.Message, "clipboard") || InStr(e.Message, "剪贴板") || !ScreenshotClipboard) {
        ErrorInfo .= "❌ 剪贴板数据错误`n"
        ErrorInfo .= "   - 可能原因: 截图数据未正确保存到剪贴板`n"
        ErrorInfo .= "   - 检查点: ScreenshotClipboard 变量状态`n"
        ErrorInfo .= "   - 建议: 重新截图或检查截图工具是否正常工作`n`n"
    }
    
    ; 检查是否是位图相关错误
    if (InStr(e.Message, "bitmap") || InStr(e.Message, "位图") || InStr(e.Message, "Bitmap")) {
        ErrorInfo .= "❌ 位图处理错误`n"
        ErrorInfo .= "   - 可能原因: 位图创建或转换失败`n"
        ErrorInfo .= "   - 检查点: hBitmap 或 pBitmap 是否有效`n"
        ErrorInfo .= "   - 建议: 检查 WinClip.GetBitmap() 返回值`n`n"
    }
    
    ; 检查是否是文件操作错误
    if (InStr(e.Message, "file") || InStr(e.Message, "文件") || InStr(e.Message, "File")) {
        ErrorInfo .= "❌ 文件操作错误`n"
        ErrorInfo .= "   - 可能原因: 临时文件创建或保存失败`n"
        ErrorInfo .= "   - 检查点: A_Temp 目录权限和磁盘空间`n"
        ErrorInfo .= "   - 建议: 检查临时目录是否可写`n`n"
    }
    
    ; 检查是否是 GUI 相关错误
    if (InStr(e.Message, "GUI") || InStr(e.Message, "Gui") || InStr(e.Message, "窗口")) {
        ErrorInfo .= "❌ GUI 创建错误`n"
        ErrorInfo .= "   - 可能原因: 窗口创建或控件添加失败`n"
        ErrorInfo .= "   - 检查点: UI_Colors 变量是否已初始化`n"
        ErrorInfo .= "   - 建议: 检查 GUI 相关变量和资源`n`n"
    }
    
    ; 通用错误提示
    if (!InStr(ErrorInfo, "❌")) {
        ErrorInfo .= "⚠️ 未识别的错误类型`n"
        ErrorInfo .= "   - 错误消息: " . e.Message . "`n"
        ErrorInfo .= "   - 建议: 查看错误行号和文件定位问题`n`n"
    }
    
    ErrorInfo .= "───────────────────────────────────────`n`n"
    
    ; 调试建议
    ErrorInfo .= "【调试建议】`n"
    ErrorInfo .= "───────────────────────────────────────`n"
    ErrorInfo .= "1. 检查错误发生的具体行号: " . (e.Line ? e.Line : "未知") . "`n"
    ErrorInfo .= "2. 检查错误文件: " . (e.File ? e.File : "未知") . "`n"
    ErrorInfo .= "3. 确认截图是否成功完成`n"
    ErrorInfo .= "4. 检查系统剪贴板是否包含图片数据`n"
    ErrorInfo .= "5. 尝试重新运行脚本`n"
    ErrorInfo .= "───────────────────────────────────────`n"
    
    ; 显示错误诊断窗口
    ErrorGui := Gui("+AlwaysOnTop +ToolWindow -MaximizeBox -MinimizeBox", "截图助手错误诊断")
    ErrorGui.BackColor := "0x1E1E1E"
    ErrorGui.SetFont("s10", "Consolas")
    
    ; 错误信息显示区域
    ErrorText := ErrorGui.Add("Edit", "x10 y10 w800 h500 ReadOnly Multi Background 0x2D2D2D c0xCCCCCC", ErrorInfo)
    ErrorText.SetFont("s9", "Consolas")
    
    ; 关闭按钮
    CloseBtn := ErrorGui.Add("Button", "x350 y520 w120 h35 Default", "关闭")
    CloseBtn.OnEvent("Click", (*) => ErrorGui.Destroy())
    
    ; 复制错误信息按钮
    CopyBtn := ErrorGui.Add("Button", "x480 y520 w120 h35", "复制信息")
    CopyBtn.OnEvent("Click", (*) => this.CopyErrorInfoToClipboard(ErrorInfo))
    
    ; 显示窗口
    ErrorGui.Show("w820 h570")
    
    ; 同时显示系统提示
    TrayTip("错误", "显示截图助手失败，已弹出详细诊断窗口", "Iconx 2")
}

; 复制错误信息到剪贴板的辅助函数
    static CopyErrorInfoToClipboard(ErrorInfo) {
    A_Clipboard := ErrorInfo
    TrayTip("提示", "错误信息已复制到剪贴板", "Iconi 1")
}

; 截图助手窗口拖动函数
    static ScreenshotEditorDragWindow(*) {
    
    try {
        if (this.GuiID_ScreenshotEditor && this.GuiID_ScreenshotEditor != 0) {
            ; 发送拖动消息（WM_NCLBUTTONDOWN with HTCAPTION = 2）
            ; 使用 PostMessage，参数格式：PostMessage(Msg, wParam, lParam, Control, WinTitle)
            PostMessage(0xA1, 2, 0, , "ahk_id " . this.GuiID_ScreenshotEditor.Hwnd)
        }
    } catch as e {
        ; 如果失败，尝试直接使用窗口句柄
        try {
            if (this.GuiID_ScreenshotEditor && this.GuiID_ScreenshotEditor.Hwnd) {
                PostMessage(0xA1, 2, 0, 0, this.GuiID_ScreenshotEditor.Hwnd)
            }
        } catch {
            ; 忽略错误
        }
    }
}

; 工具栏拖动窗口函数
    static ScreenshotToolbarDragWindow(*) {
    
    try {
        if (this.GuiID_ScreenshotToolbar && this.GuiID_ScreenshotToolbar != 0) {
            ; 发送拖动消息（WM_NCLBUTTONDOWN with HTCAPTION = 2）
            PostMessage(0xA1, 2, 0, , "ahk_id " . this.GuiID_ScreenshotToolbar.Hwnd)
        }
    } catch as e {
        ; 如果失败，尝试直接使用窗口句柄
        try {
            if (this.GuiID_ScreenshotToolbar && this.GuiID_ScreenshotToolbar.Hwnd) {
                PostMessage(0xA1, 2, 0, 0, this.GuiID_ScreenshotToolbar.Hwnd)
            }
        } catch {
            ; 忽略错误
        }
    }
}

    static ScreenshotToolbar_OnCreated(ctrl) {
    this.ScreenshotToolbarWV2Ctrl := ctrl
    this.ScreenshotToolbarWV2 := ctrl.CoreWebView2
    this.ScreenshotToolbarWV2Ready := false
    this.ScreenshotToolbarWV2PaintOk := false
    try this.ScreenshotToolbarWV2Ctrl.DefaultBackgroundColor := 0xFF0A0A0A
    try {
        s := this.ScreenshotToolbarWV2.Settings
        s.AreDefaultContextMenusEnabled := false
        s.AreDevToolsEnabled := true
    }
    ApplyWebView2PerformanceSettings(this.ScreenshotToolbarWV2)
    WebView2_RegisterHostBridge(this.ScreenshotToolbarWV2)
    try this.ScreenshotToolbarWV2Ctrl.IsVisible := true
    try this.ScreenshotToolbarWV2.add_WebMessageReceived(ObjBindMethod(ScreenshotEditorPlugin, "ScreenshotToolbar_OnMessage"))
    try this.ScreenshotToolbarWV2.add_NavigationCompleted(ObjBindMethod(ScreenshotEditorPlugin, "ScreenshotToolbar_OnNavigationCompleted"))
    htmlPath := A_ScriptDir "\ScreenshotToolbarWebView.html"
    try {
        if FileExist(htmlPath) {
            this.ScreenshotToolbarWV2.NavigateToString(FileRead(htmlPath, "UTF-8"))
        } else {
            try ApplyUnifiedWebViewAssets(this.ScreenshotToolbarWV2)
            this.ScreenshotToolbarWV2.Navigate(BuildAppLocalUrl("ScreenshotToolbarWebView.html"))
        }
    } catch as e {
        try this.ScreenshotToolbarWV2.NavigateToString("<!doctype html><html><body style='margin:0;background:#0a0a0a;color:#ff9d3a;font:12px Segoe UI;padding:10px'>截图工具栏加载失败: " . e.Message . "</body></html>")
    }
    this.ScreenshotToolbar_ApplyBounds()
}

    static ScreenshotToolbar_EnsureCreated(*) {
    if !this.ScreenshotToolbarWV2Ctrl
        this.ScreenshotToolbar_EnableNativeFallback("wv2_create_timeout")
}

    static ScreenshotToolbar_OnNavigationCompleted(sender, args) {
    try ok := args.IsSuccess
    catch
        ok := true
    if ok
        return
    try sender.NavigateToString("<!doctype html><html><body style='margin:0;background:#0a0a0a;color:#ff9d3a;font:12px Segoe UI;padding:10px'>截图工具栏页面加载失败</body></html>")
}

    static ScreenshotToolbar_OnSize(*) {
    this.ScreenshotToolbar_ApplyBounds()
}

    static ScreenshotToolbar_ApplyBounds() {
    if !(IsObject(this.GuiID_ScreenshotToolbar) && this.GuiID_ScreenshotToolbar != 0)
        return
    if !this.ScreenshotToolbarWV2Ctrl
        return
    WinGetClientPos(, , &cw, &ch, this.GuiID_ScreenshotToolbar.Hwnd)
    rc := WebView2.RECT()
    rc.left := 0
    rc.top := 0
    rc.right := cw
    rc.bottom := ch
    this.ScreenshotToolbarWV2Ctrl.Bounds := rc
}

    static ScreenshotToolbar_NotifyHostMemory(shown) {
    if shown
        WebView2_NotifyShown(this.ScreenshotToolbarWV2)
    else
        WebView2_NotifyHidden(this.ScreenshotToolbarWV2)
}

    static ScreenshotToolbar_RefreshComposition(*) {
    if !this.ScreenshotToolbarWV2Ctrl
        return
    try {
        this.ScreenshotToolbar_ApplyBounds()
        this.ScreenshotToolbarWV2Ctrl.NotifyParentWindowPositionChanged()
    }
}

    static ScreenshotToolbar_OnMessage(sender, args) {
    jsonStr := args.WebMessageAsJson
    try msg := Jxon_Load(jsonStr)
    catch
        return
    if !(msg is Map)
        return
    action := msg.Has("action") ? msg["action"] : (msg.Has("type") ? msg["type"] : "")
    switch action {
        case "ready":
            this.ScreenshotToolbarWV2Ready := true
            this.ScreenshotToolbar_SendState()
        case "paint_ok":
            this.ScreenshotToolbarWV2PaintOk := true
        case "layout":
            this.ScreenshotToolbar_ApplyLayout(msg.Get("width", 0), msg.Get("height", 0))
        case "dragWindow":
            this.ScreenshotToolbarDragWindow()
        case "invoke":
            cmd := msg.Get("cmd", "")
            this.ScreenshotToolbar_InvokeCommand(cmd)
    }
}

    static ScreenshotToolbar_InvokeCommand(cmd) {
    switch cmd {
        case "pin":
            this.ToggleScreenshotEditorAlwaysOnTop()
        case "ocr":
            this.ExecuteScreenshotOCR()
        case "ocr_edit":
            this.ScreenshotEditorEditOCRInHubCapsule()
        case "text":
            this.PasteScreenshotAsText()
        case "save":
            this.SaveScreenshotToFile()
        case "ai":
            this.ScreenshotEditorSendToAI()
        case "search":
            this.ScreenshotEditorSearchText()
        case "color":
            this.ScreenshotEditorToggleColorPicker()
        case "close":
            this.CloseScreenshotEditor()
    }
}

    static ScreenshotToolbar_SendState() {
    if !this.ScreenshotToolbarWV2 || !this.ScreenshotToolbarWV2Ready
        return
    try this.ScreenshotToolbarWV2.PostWebMessageAsJson(
        WebView_DumpJson(Map("type", "state", "toolbarVisible", this.ScreenshotEditorToolbarVisible))
    )
}

    static ScreenshotToolbar_ApplyLayout(width, height) {

    try {
        w := Integer(Round(Float(width)))
        h := Integer(Round(Float(height)))
    } catch {
        return
    }

    if (w <= 0 || h <= 0)
        return

    w := Max(240, Min(960, w))
    h := Max(40, Min(120, h))
    this.ScreenshotToolbarCurrentWidth := w
    this.ScreenshotToolbarCurrentHeight := h

    if !(IsObject(this.GuiID_ScreenshotToolbar) && this.GuiID_ScreenshotToolbar != 0)
        return

    tx := 0
    ty := 0
    if (IsObject(this.GuiID_ScreenshotEditor) && this.GuiID_ScreenshotEditor != 0) {
        try {
            WinGetPos(&ex, &ey, , &eh, "ahk_id " . this.GuiID_ScreenshotEditor.Hwnd)
            tx := ex
            ty := ey + eh + 10
        } catch {
            WinGetPos(&tx, &ty, , , "ahk_id " . this.GuiID_ScreenshotToolbar.Hwnd)
        }
    } else {
        WinGetPos(&tx, &ty, , , "ahk_id " . this.GuiID_ScreenshotToolbar.Hwnd)
    }

    try this.GuiID_ScreenshotToolbar.Show("x" . tx . " y" . ty . " w" . w . " h" . h)
    this.ScreenshotToolbar_NotifyHostMemory(true)
    this.ScreenshotToolbar_ApplyWindowRegion()
    this.ScreenshotToolbar_ApplyBounds()
    SetTimer(ObjBindMethod(ScreenshotEditorPlugin, "ScreenshotToolbar_RefreshComposition"), -30)
}

    static ScreenshotToolbar_ApplyWindowRegion() {
    if !(IsObject(this.GuiID_ScreenshotToolbar) && this.GuiID_ScreenshotToolbar != 0)
        return
    hwnd := this.GuiID_ScreenshotToolbar.Hwnd
    if !hwnd
        return
    try WinGetPos(, , &w, &h, "ahk_id " . hwnd)
    catch
        return
    if (w < 20 || h < 20)
        return
    ; 与 HTML 卡片圆角一致（radius≈12px -> ellipse 24x24）
    rgn := DllCall("gdi32\CreateRoundRectRgn", "Int", 0, "Int", 0, "Int", w + 1, "Int", h + 1, "Int", 24, "Int", 24, "Ptr")
    if !rgn
        return
    ; SetWindowRgn 成功后系统接管 rgn 句柄
    DllCall("user32\SetWindowRgn", "Ptr", hwnd, "Ptr", rgn, "Int", 1)
}

    static ScreenshotToolbar_EnsureUsable(*) {
    if !this.ScreenshotToolbarWV2 {
        this.ScreenshotToolbar_EnableNativeFallback("wv2_missing")
        return
    }
    ; 若首帧仍未完成，切换到极简安全版 HTML，保证按钮可见
    if (!this.ScreenshotToolbarWV2PaintOk) {
        try this.ScreenshotToolbarWV2.NavigateToString(this.ScreenshotToolbar_BuildSafeInlineHtml())
        SetTimer(ObjBindMethod(ScreenshotEditorPlugin, "ScreenshotToolbar_RefreshComposition"), -60)
        SetTimer(ObjBindMethod(ScreenshotEditorPlugin, "ScreenshotToolbar_EnsureUsableSecondPass"), -700)
    }
}

    static ScreenshotToolbar_EnsureUsableSecondPass(*) {
    if !this.ScreenshotToolbarWV2PaintOk {
        this.ScreenshotToolbar_EnableNativeFallback("wv2_paint_timeout")
        TrayTip("截图工具栏", "已切换到兼容渲染模式", "Iconi 1")
    }
}

    static ScreenshotToolbar_BuildSafeInlineHtml() {
    return "
(
<!doctype html>
<html><head><meta charset='utf-8'><meta name='viewport' content='width=device-width,initial-scale=1'>
<style>
html,body{margin:0;padding:0;width:100%;height:100%;background:#010203;color:#ff9d3a;font:12px Segoe UI,Microsoft YaHei UI,sans-serif;overflow:hidden}
#bar{height:100%;display:flex;align-items:center;gap:4px;padding:6px}
.b{min-width:34px;height:34px;border:1px solid #663c1f;border-radius:8px;background:#14171b;color:#ff9d3a;cursor:pointer}
.b:hover{background:#222830}
.d{color:#ff8a95;border-color:#73414a}
.s{width:1px;height:18px;background:#5a3a20;margin:0 2px}
</style></head>
<body><div id='bar'>
<button class='b' data-cmd='pin' title='置顶'>钉</button>
<button class='b' data-cmd='ocr' title='识别文本'>识</button>
<button class='b' data-cmd='ocr_edit' title='编辑OCR到草稿本'>编</button>
<button class='b' data-cmd='text' title='复制文本'>文</button>
<button class='b' data-cmd='save' title='保存图片'>存</button>
<div class='s'></div>
<button class='b' data-cmd='ai' title='发送到AI'>AI</button>
<button class='b' data-cmd='search' title='搜索文本'>搜</button>
<button class='b' data-cmd='color' title='取色器'>色</button>
<div class='s'></div>
<button class='b d' data-cmd='close' title='关闭'>关</button>
</div>
<script>
(function(){
  function post(o){try{if(window.chrome&&window.chrome.webview){window.chrome.webview.postMessage(o);}}catch(e){}}
  var bar=document.getElementById('bar');
  bar.addEventListener('click',function(ev){
    var t=ev.target;
    while(t&&t!==bar&&!t.getAttribute('data-cmd')) t=t.parentNode;
    if(!t||t===bar) return;
    post({action:'invoke',cmd:t.getAttribute('data-cmd')});
  });
  bar.addEventListener('mousedown',function(ev){
    if(ev.button!==0) return;
    var t=ev.target;
    while(t&&t!==bar&&!t.getAttribute('data-cmd')) t=t.parentNode;
    if(!t||t===bar) post({action:'dragWindow'});
  });
  post({action:'ready'}); post({action:'paint_ok'});
})();
</script></body></html>
)"
}

    static ScreenshotToolbar_EnableNativeFallback(reason := "") {
    if !(IsObject(this.GuiID_ScreenshotToolbar) && this.GuiID_ScreenshotToolbar != 0)
        return
    if this.ScreenshotToolbarNativeFallback
        return
    this.ScreenshotToolbarNativeFallback := true
    this.ScreenshotToolbarWV2Ready := false
    this.ScreenshotToolbarWV2PaintOk := false
    try {
        if (this.ScreenshotToolbarWV2Ctrl)
            this.ScreenshotToolbarWV2Ctrl.IsVisible := false
    }
    this.GuiID_ScreenshotToolbar.BackColor := "0f1114"
    x := 8
    y := 10
    btnW := 32
    btnH := 32
    gap := 6
    sepGap := 5

    AddBtn(txt, cmd, isDanger := false) {
        bg := isDanger ? "251417" : "14171b"
        bd := isDanger ? "73414a" : "663c1f"
        tc := isDanger ? "ff8a95" : "ff9d3a"
        c := this.GuiID_ScreenshotToolbar.Add("Text", "x" . x . " y" . y . " w" . btnW . " h" . btnH . " Center 0x200 Border c" . bd . " Background" . bg, txt)
        c.SetFont("s10 Bold c" . tc, "Segoe UI")
        c.OnEvent("Click", (*) => this.ScreenshotToolbar_InvokeCommand(cmd))
        x += btnW + gap
    }
    AddSep() {
        x += sepGap
        this.GuiID_ScreenshotToolbar.Add("Text", "x" . x . " y" . (y + 7) . " w1 h18 Background5a3a20 c5a3a20", "")
        x += 1 + sepGap
    }

    AddBtn("钉", "pin")
    AddBtn("识", "ocr")
    AddBtn("编", "ocr_edit")
    AddBtn("文", "text")
    AddBtn("存", "save")
    AddSep()
    AddBtn("AI", "ai")
    AddBtn("搜", "search")
    AddBtn("色", "color")
    AddSep()
    AddBtn("关", "close", true)

    this.ScreenshotToolbarCurrentWidth := Max(320, x + 8)
    this.ScreenshotToolbarCurrentHeight := 52
    dragTop := this.GuiID_ScreenshotToolbar.Add("Text", "x0 y0 w" . this.ScreenshotToolbarCurrentWidth . " h8 BackgroundTrans", "")
    dragBottom := this.GuiID_ScreenshotToolbar.Add("Text", "x0 y" . (this.ScreenshotToolbarCurrentHeight - 8) . " w" . this.ScreenshotToolbarCurrentWidth . " h8 BackgroundTrans", "")
    dragTop.OnEvent("Click", ObjBindMethod(ScreenshotEditorPlugin, "ScreenshotToolbarDragWindow"))
    dragBottom.OnEvent("Click", ObjBindMethod(ScreenshotEditorPlugin, "ScreenshotToolbarDragWindow"))
    try this.GuiID_ScreenshotToolbar.Show("NA w" . this.ScreenshotToolbarCurrentWidth . " h" . this.ScreenshotToolbarCurrentHeight)
    this.ScreenshotToolbar_NotifyHostMemory(true)
    this.ScreenshotToolbar_ApplyWindowRegion()
    if (reason != "")
        OutputDebug("[ScreenshotToolbar] native fallback: " . reason)
}

; 同步工具栏位置（跟随主窗口移动）
    static SyncScreenshotToolbarPosition() {
    
    try {
        if (!this.GuiID_ScreenshotEditor || this.GuiID_ScreenshotEditor = 0) {
            SetTimer(ObjBindMethod(ScreenshotEditorPlugin, "SyncScreenshotToolbarPosition"), 0)  ; 停止定时器
            return
        }
        
        if (!this.GuiID_ScreenshotToolbar || this.GuiID_ScreenshotToolbar = 0) {
            SetTimer(ObjBindMethod(ScreenshotEditorPlugin, "SyncScreenshotToolbarPosition"), 0)  ; 停止定时器
            return
        }
        
        ; 获取主窗口位置和尺寸
        WinGetPos(&EditorX, &EditorY, &EditorW, &EditorH, "ahk_id " . this.GuiID_ScreenshotEditor.Hwnd)
        
        if (!EditorX || !EditorY || !EditorW || !EditorH) {
            return  ; 如果获取位置失败，跳过本次同步
        }
        
        ; 计算工具栏位置（放在主窗口下方，间距10像素）
        ToolbarX := EditorX
        ToolbarY := EditorY + EditorH + 10
        
        ; 获取工具栏当前尺寸
        WinGetPos(, , &ToolbarW, &ToolbarH, "ahk_id " . this.GuiID_ScreenshotToolbar.Hwnd)
        
        ; 移动工具栏到新位置
        if (ToolbarW && ToolbarH) {
            this.GuiID_ScreenshotToolbar.Show("x" . ToolbarX . " y" . ToolbarY)
            this.ScreenshotToolbar_ApplyWindowRegion()
            this.ScreenshotToolbar_ApplyBounds()
        }
        if (this.ScreenshotColorPickerActive) {
            this.ScreenshotColorPickerSyncPosition()
        }
    } catch as e {
        ; 如果出错，停止定时器
        SetTimer(ObjBindMethod(ScreenshotEditorPlugin, "SyncScreenshotToolbarPosition"), 0)
    }
}

; 切换截图助手置顶状态（隐藏/显示工具栏和标题栏）
    static ToggleScreenshotEditorAlwaysOnTop() {
    
    try {
        this.ScreenshotEditorToolbarVisible := !this.ScreenshotEditorToolbarVisible
        
        if (!this.ScreenshotEditorToolbarVisible) {
            ; 隐藏工具栏和标题栏
            if (this.ScreenshotEditorTitleBar) {
                this.ScreenshotEditorTitleBar.Visible := false
            }
            if (this.ScreenshotEditorCloseBtn) {
                this.ScreenshotEditorCloseBtn.Visible := false
            }
            if (this.GuiID_ScreenshotToolbar != 0) {
                this.ScreenshotToolbar_NotifyHostMemory(false)
                this.GuiID_ScreenshotToolbar.Hide()
            }
            this.ScreenshotEditorApplyZoom(this.ScreenshotEditorZoomScale, true)
            this.ScreenshotToolbar_SendState()
            TrayTip("提示", "已进入置顶缩放模式：滚轮可缩放", "Iconi 1")
        } else {
            ; 显示工具栏和标题栏
            this.ShowScreenshotEditorToolbar()
            this.ScreenshotToolbar_SendState()
            TrayTip("提示", "已显示工具栏和标题栏", "Iconi 1")
        }
    } catch as e {
        TrayTip("错误", "切换显示状态失败: " . e.Message, "Iconx 2")
    }
}

; 显示截图助手工具栏和标题栏
    static ShowScreenshotEditorToolbar() {
    
    try {
        this.ScreenshotEditorToolbarVisible := true
        
        ; 显示标题栏和关闭按钮
        if (this.ScreenshotEditorTitleBar) {
            this.ScreenshotEditorTitleBar.Visible := true
        }
        if (this.ScreenshotEditorCloseBtn) {
            this.ScreenshotEditorCloseBtn.Visible := true
        }

        ; 按当前缩放比例恢复布局
        this.ScreenshotEditorApplyZoom(this.ScreenshotEditorZoomScale, false)
        this.ScreenshotToolbar_SendState()
    } catch as e {
        TrayTip("错误", "显示工具栏失败: " . e.Message, "Iconx 2")
    }
}

    static ScreenshotEditorZoomBy(step) {
    newScale := this.ScreenshotEditorZoomScale + step
    this.ScreenshotEditorApplyZoom(newScale, true)
}

; 指数缩放：参考 d3/openSeadragon 的滚轮缩放思路，使用 2^delta 让不同倍率下手感一致
    static ScreenshotEditorZoomWithWheel(direction) {
    try {
        d := (direction > 0) ? 1 : -1
        wheelDelta := 0.12 * d
        factor := Exp(wheelDelta * Ln(2.0))
        newScale := this.ScreenshotEditorZoomScale * factor
        this.ScreenshotEditorApplyZoom(newScale, true)
    } catch {
        this.ScreenshotEditorZoomBy(0.1 * ((direction > 0) ? 1 : -1))
    }
}

    static ScreenshotEditorApplyZoom(newScale, showTip := true) {

    try {
        if !(IsObject(this.GuiID_ScreenshotEditor) && this.GuiID_ScreenshotEditor != 0)
            return
        if (!this.ScreenshotEditorPreviewPic)
            return

        if (!this.ScreenshotEditorBaseWidth || !this.ScreenshotEditorBaseHeight) {
            this.ScreenshotEditorBaseWidth := this.ScreenshotEditorPreviewWidth
            this.ScreenshotEditorBaseHeight := this.ScreenshotEditorPreviewHeight
        }
        if (!this.ScreenshotEditorBaseWidth || !this.ScreenshotEditorBaseHeight)
            return

        if (newScale < this.ScreenshotEditorZoomMin)
            newScale := this.ScreenshotEditorZoomMin

        ; 屏幕可视范围动态限幅，避免放大后出现“截断感”
        titleH := this.ScreenshotEditorToolbarVisible ? this.ScreenshotEditorTitleBarHeight : 0
        vW := SysGet(78), vH := SysGet(79)
        maxScaleW := (vW - 20) / this.ScreenshotEditorBaseWidth
        maxScaleH := (vH - 20 - titleH) / this.ScreenshotEditorBaseHeight
        screenMaxScale := Min(maxScaleW, maxScaleH)
        if (screenMaxScale < this.ScreenshotEditorZoomMin)
            screenMaxScale := this.ScreenshotEditorZoomMin
        effectiveMaxScale := Min(this.ScreenshotEditorZoomMax, screenMaxScale)
        if (newScale > effectiveMaxScale)
            newScale := effectiveMaxScale
        this.ScreenshotEditorZoomScale := newScale

        drawW := Max(120, Round(this.ScreenshotEditorBaseWidth * this.ScreenshotEditorZoomScale))
        drawH := Max(80, Round(this.ScreenshotEditorBaseHeight * this.ScreenshotEditorZoomScale))

        previewY := titleH
        winW := drawW
        winH := drawH + titleH

        WinGetPos(&oldX, &oldY, &oldW, &oldH, "ahk_id " . this.GuiID_ScreenshotEditor.Hwnd)
        if (!oldW || !oldH) {
            oldW := winW
            oldH := winH
        }

        ; 以当前窗口中心为基准缩放，避免向右下扩展造成“截断感”
        centerX := oldX + (oldW // 2)
        centerY := oldY + (oldH // 2)
        winX := centerX - (winW // 2)
        winY := centerY - (winH // 2)

        ; 限制在虚拟屏幕范围内，避免放大后跑出边界
        vL := SysGet(76), vT := SysGet(77), vW := SysGet(78), vH := SysGet(79)
        vR := vL + vW, vB := vT + vH
        if (winX < vL)
            winX := vL
        if (winY < vT)
            winY := vT
        if (winX + winW > vR)
            winX := vR - winW
        if (winY + winH > vB)
            winY := vB - winH
        if (winX < vL)
            winX := vL
        if (winY < vT)
            winY := vT

        ; 关键修复：从原图重采样当前尺寸，避免仅拉伸控件导致的“截断/失真感”
        this.ScreenshotEditorRefreshScaledPreview(drawW, drawH)
        this.ScreenshotEditorPreviewPic.Move(0, previewY, drawW, drawH)
        this.GuiID_ScreenshotEditor.Show("w" . winW . " h" . winH . " x" . winX . " y" . winY)

        if (this.ScreenshotEditorToolbarVisible && this.GuiID_ScreenshotToolbar != 0) {
            toolbarX := winX
            toolbarY := winY + winH + 10
            this.GuiID_ScreenshotToolbar.Show("x" . toolbarX . " y" . toolbarY)
            this.ScreenshotToolbar_NotifyHostMemory(true)
            this.ScreenshotToolbar_ApplyBounds()
            SetTimer(ObjBindMethod(ScreenshotEditorPlugin, "ScreenshotToolbar_RefreshComposition"), -30)
        }

        if (showTip)
            this.ScreenshotEditorShowZoomTip(this.ScreenshotEditorZoomScale, drawW, drawH)
    } catch as e {
        TrayTip("缩放", "缩放失败: " . e.Message, "Iconx 1")
    }
}

    static ScreenshotEditorRefreshScaledPreview(drawW, drawH) {
    if (!this.ScreenshotEditorBitmap || !this.ScreenshotEditorPreviewPic)
        return
    pScaled := 0
    pG := 0
    try {
        result := DllCall("gdiplus\GdipCreateBitmapFromScan0"
            , "Int", drawW
            , "Int", drawH
            , "Int", 0
            , "UInt", 0x26200A
            , "Ptr", 0
            , "Ptr*", &pScaled := 0)
        if (result != 0 || !pScaled)
            return

        result := DllCall("gdiplus\GdipGetImageGraphicsContext", "Ptr", pScaled, "Ptr*", &pG := 0)
        if (result != 0 || !pG)
            return

        DllCall("gdiplus\GdipSetInterpolationMode", "Ptr", pG, "Int", 7) ; HighQualityBicubic
        DllCall("gdiplus\GdipDrawImageRect", "Ptr", pG, "Ptr", this.ScreenshotEditorBitmap
            , "Float", 0, "Float", 0, "Float", drawW, "Float", drawH)

        newPath := A_Temp "\ScreenshotEditor_zoom_" . A_TickCount . ".png"
        saveRet := Gdip_SaveBitmapToFile(pScaled, newPath)
        if (saveRet != 0)
            return

        ; 先切图，再删旧图，避免控件引用失效
        this.ScreenshotEditorPreviewPic.Value := newPath
        oldPath := this.ScreenshotEditorImagePath
        this.ScreenshotEditorImagePath := newPath
        if (oldPath != "" && oldPath != newPath && FileExist(oldPath)) {
            try FileDelete(oldPath)
        }
    } catch {
    } finally {
        if (pG)
            try Gdip_DeleteGraphics(pG)
        if (pScaled)
            try Gdip_DisposeImage(pScaled)
    }
}

    static ScreenshotEditorShowZoomTip(scale, width, height) {

    try {
        if !(IsObject(this.GuiID_ScreenshotZoomTip) && this.GuiID_ScreenshotZoomTip != 0) {
            this.GuiID_ScreenshotZoomTip := Gui("+AlwaysOnTop -Caption +ToolWindow -DPIScale")
            this.GuiID_ScreenshotZoomTip.BackColor := "0b0b0b"
            this.GuiID_ScreenshotZoomTip.MarginX := 10
            this.GuiID_ScreenshotZoomTip.MarginY := 6
            this.ScreenshotZoomTipTextCtrl := this.GuiID_ScreenshotZoomTip.Add("Text", "cFF8A00", "")
            this.ScreenshotZoomTipTextCtrl.SetFont("s10 Bold", "Segoe UI")
        }

        txt := "缩放 " . Round(scale * 100) . "%  |  尺寸 " . width . " x " . height
        this.ScreenshotZoomTipTextCtrl.Value := txt
        this.GuiID_ScreenshotZoomTip.Show("NA AutoSize")

        WinGetPos(&ex, &ey, &ew, , "ahk_id " . this.GuiID_ScreenshotEditor.Hwnd)
        WinGetPos(, , &tw, &th, "ahk_id " . this.GuiID_ScreenshotZoomTip.Hwnd)
        tx := ex + ew - tw - 12
        ty := ey + (this.ScreenshotEditorToolbarVisible ? this.ScreenshotEditorTitleBarHeight + 8 : 8)
        this.GuiID_ScreenshotZoomTip.Show("NA x" . tx . " y" . ty)

        SetTimer(ObjBindMethod(ScreenshotEditorPlugin, "ScreenshotEditorHideZoomTip"), -1200)
    } catch {
    }
}

    static ScreenshotEditorHideZoomTip(*) {
    try {
        if (IsObject(this.GuiID_ScreenshotZoomTip) && this.GuiID_ScreenshotZoomTip != 0)
            this.GuiID_ScreenshotZoomTip.Hide()
    } catch {
    }
}

    static ScreenshotEditorShowCurrentZoomTip() {
    if (!this.ScreenshotEditorBaseWidth || !this.ScreenshotEditorBaseHeight)
        return
    drawW := Max(120, Round(this.ScreenshotEditorBaseWidth * this.ScreenshotEditorZoomScale))
    drawH := Max(80, Round(this.ScreenshotEditorBaseHeight * this.ScreenshotEditorZoomScale))
    this.ScreenshotEditorShowZoomTip(this.ScreenshotEditorZoomScale, drawW, drawH)
}

; 截图助手图片控件点击事件（用于拖动窗口）
    static OnScreenshotEditorPicClick(Ctrl, Info) {
    
    try {
        ; 检查是否长按左键（等待200ms判断）
        Sleep(200)
        if (GetKeyState("LButton", "P")) {
            ; 长按左键，开始拖动窗口
            this.ScreenshotEditorIsDraggingWindow := true
            
            ; 发送拖动消息（确保窗口句柄有效）
            if (this.GuiID_ScreenshotEditor && this.GuiID_ScreenshotEditor != 0) {
                PostMessage(0xA1, 2, 0, 0, this.GuiID_ScreenshotEditor.Hwnd)
            }
            
            ; 监听鼠标释放
            SetTimer(() => this.CheckScreenshotEditorWindowDragUp(), 10)
        }
    } catch as e {
        ; 忽略错误
    }
}

; 检查窗口拖动是否结束
    static CheckScreenshotEditorWindowDragUp() {
    
    if (!this.ScreenshotEditorIsDraggingWindow) {
        SetTimer(() => this.CheckScreenshotEditorWindowDragUp(), 0)
        return
    }
    
    if (!GetKeyState("LButton", "P")) {
        this.ScreenshotEditorIsDraggingWindow := false
        SetTimer(() => this.CheckScreenshotEditorWindowDragUp(), 0)
    }
}

; 关闭截图助手预览窗
    static CloseScreenshotEditor() {
    
    try {
        this.ScreenshotEditorStopColorPicker()

        ; 关闭工具栏窗口
        if (this.GuiID_ScreenshotToolbar && (this.GuiID_ScreenshotToolbar != 0)) {
            try {
                if (IsObject(this.GuiID_ScreenshotToolbar)) {
                    this.GuiID_ScreenshotToolbar.Destroy()
                }
            } catch as e {
                ; 忽略销毁错误
            }
            this.GuiID_ScreenshotToolbar := 0
        }
        this.ScreenshotToolbarWV2Ctrl := 0
        this.ScreenshotToolbarWV2 := 0
        this.ScreenshotToolbarWV2Ready := false
        this.ScreenshotToolbarWV2PaintOk := false
        this.ScreenshotToolbarNativeFallback := false

        if (this.GuiID_ScreenshotToolbarTip && (this.GuiID_ScreenshotToolbarTip != 0)) {
            try {
                if (IsObject(this.GuiID_ScreenshotToolbarTip))
                    this.GuiID_ScreenshotToolbarTip.Destroy()
            } catch {
            }
            this.GuiID_ScreenshotToolbarTip := 0
            this.ScreenshotToolbarTipTextCtrl := 0
        }

        if (this.GuiID_ScreenshotZoomTip && (this.GuiID_ScreenshotZoomTip != 0)) {
            try {
                if (IsObject(this.GuiID_ScreenshotZoomTip)) {
                    this.GuiID_ScreenshotZoomTip.Destroy()
                }
            } catch {
            }
            this.GuiID_ScreenshotZoomTip := 0
            this.ScreenshotZoomTipTextCtrl := 0
        }
        
        ; 重置状态
        
        ; 释放Gdip资源
        if (this.ScreenshotEditorBitmap) {
            try {
                Gdip_DisposeImage(this.ScreenshotEditorBitmap)
            } catch as e {
                ; 忽略释放错误
            }
            this.ScreenshotEditorBitmap := 0
        }
        if (this.ScreenshotEditorGraphics) {
            try {
                Gdip_DeleteGraphics(this.ScreenshotEditorGraphics)
            } catch as e {
                ; 忽略释放错误
            }
            this.ScreenshotEditorGraphics := 0
        }
        if (this.ScreenshotEditorPreviewBitmap) {
            try {
                Gdip_DisposeImage(this.ScreenshotEditorPreviewBitmap)
            } catch as e {
                ; 忽略释放错误
            }
            this.ScreenshotEditorPreviewBitmap := 0
        }
        
        ; 删除临时文件
        if (this.ScreenshotEditorImagePath && FileExist(this.ScreenshotEditorImagePath)) {
            try {
                FileDelete(this.ScreenshotEditorImagePath)
            } catch as err {
            }
            this.ScreenshotEditorImagePath := ""
        }
        
        ; 销毁GUI（安全处理Gui对象）
        if (IsObject(this.GuiID_ScreenshotEditor)) {
            try {
                this.GuiID_ScreenshotEditor.Destroy()
            } catch as e {
                ; 忽略销毁错误
            }
            this.GuiID_ScreenshotEditor := 0
        }
        this.ScreenshotEditorPreviewPic := 0

        this.ScreenshotEditorZoomScale := 1.0
        this.ScreenshotEditorBaseWidth := 0
        this.ScreenshotEditorBaseHeight := 0
        ScreenshotEditorPlugin._SyncHub()
    } catch as err {
    }
}


; 更新截图助手预览（从原始位图重新绘制到预览位图）
    static UpdateScreenshotEditorPreview() {
    
    if (!this.ScreenshotEditorBitmap || !this.ScreenshotEditorGraphics || !this.ScreenshotEditorPreviewBitmap) {
        return
    }
    
    try {
        ; 重新绘制预览（从原始位图重新绘制，包含所有已绘制的标注）
        ; 先清除图形
        DllCall("gdiplus\GdipGraphicsClear", "Ptr", this.ScreenshotEditorGraphics, "UInt", 0xFF000000)
        
        ; 重新绘制原始图像（包含所有标注）
        DllCall("gdiplus\GdipSetInterpolationMode", "Ptr", this.ScreenshotEditorGraphics, "Int", 7)  ; HighQualityBicubic
        DllCall("gdiplus\GdipDrawImageRect", "Ptr", this.ScreenshotEditorGraphics, "Ptr", this.ScreenshotEditorBitmap, "Float", 0, "Float", 0, "Float", this.ScreenshotEditorPreviewWidth, "Float", this.ScreenshotEditorPreviewHeight)
        
        ; 保存更新后的预览位图到临时文件
        Gdip_SaveBitmapToFile(this.ScreenshotEditorPreviewBitmap, this.ScreenshotEditorImagePath)
        
        ; 更新Picture控件显示
        if (this.ScreenshotEditorPreviewPic) {
            this.ScreenshotEditorPreviewPic.Value := this.ScreenshotEditorImagePath
        }
        
    } catch as e {
        ; 忽略错误
    }
}

    static ScreenshotEditorToolbarIconPath(iconKey) {
    baseDir := A_ScriptDir "\assets\images"
    menuDir := baseDir "\screenshot-menu"
    iconMap := Map(
        "pin", menuDir "\toolbar-show.png",
        "ocr", menuDir "\process.png",
        "text", menuDir "\copy.png",
        "save", menuDir "\save.png",
        "ai", baseDir "\toolbar_ai.png",
        "search", baseDir "\toolbar_search.png",
        "color", menuDir "\flip-h.png",
        "close", menuDir "\close.png"
    )
    return iconMap.Has(iconKey) ? iconMap[iconKey] : ""
}

    static ScreenshotToolbarEnsureTipGui() {
    if (this.GuiID_ScreenshotToolbarTip && this.GuiID_ScreenshotToolbarTip != 0)
        return
    this.GuiID_ScreenshotToolbarTip := Gui("+AlwaysOnTop -Caption +ToolWindow +Border +E0x20")
    this.GuiID_ScreenshotToolbarTip.BackColor := "0f1114"
    this.ScreenshotToolbarTipTextCtrl := this.GuiID_ScreenshotToolbarTip.Add("Text", "x8 y4 cffb062 BackgroundTrans", "")
    this.ScreenshotToolbarTipTextCtrl.SetFont("s9", "Segoe UI")
}

    static ScreenshotToolbarShowHoverTip(tipText, anchorX, anchorY) {
    this.ScreenshotToolbarEnsureTipGui()
    if (!(this.GuiID_ScreenshotToolbarTip && this.ScreenshotToolbarTipTextCtrl))
        return
    try {
        this.ScreenshotToolbarTipTextCtrl.Value := tipText
        this.GuiID_ScreenshotToolbarTip.Show("NA AutoSize x-32000 y-32000")
        this.GuiID_ScreenshotToolbarTip.GetPos(, , &tw, &th)
        ScreenVirtual_GetBounds(&vl, &vt, &vw, &vh)
        tx := anchorX - (tw // 2)
        ty := anchorY - th - 14
        if (tx < vl)
            tx := vl + 2
        if (tx + tw > vl + vw)
            tx := vl + vw - tw - 2
        if (ty < vt)
            ty := anchorY + 14
        this.GuiID_ScreenshotToolbarTip.Show("NA x" . tx . " y" . ty)
    } catch {
    }
}

    static ScreenshotToolbarHideHoverTip() {
    this.ScreenshotToolbarHoverTipLastKey := ""
    try {
        if (this.GuiID_ScreenshotToolbarTip && this.GuiID_ScreenshotToolbarTip != 0)
            this.GuiID_ScreenshotToolbarTip.Hide()
    } catch {
    }
}

    static ScreenshotToolbarHoverTick(*) {
    if !(this.GuiID_ScreenshotToolbar && IsObject(this.GuiID_ScreenshotToolbar) && this.GuiID_ScreenshotToolbar != 0) {
        this.ScreenshotToolbarHideHoverTip()
        SetTimer(ObjBindMethod(ScreenshotEditorPlugin, "ScreenshotToolbarHoverTick"), 0)
        return
    }
    try WinGetPos(&wx, &wy, &ww, &wh, "ahk_id " . this.GuiID_ScreenshotToolbar.Hwnd)
    catch {
        this.ScreenshotToolbarHideHoverTip()
        return
    }

    MouseGetPos(&mx, &my, &hoverWin)
    if (hoverWin != this.GuiID_ScreenshotToolbar.Hwnd) {
        this.ScreenshotToolbarHideHoverTip()
        return
    }

    lx := mx - wx
    ly := my - wy
    hitKey := ""
    hitTip := ""
    for _, item in this.ScreenshotToolbarHoverItems {
        if (lx >= item["x"] && lx <= item["x"] + item["w"] && ly >= item["y"] && ly <= item["y"] + item["h"]) {
            hitKey := item["key"]
            hitTip := item["tip"]
            break
        }
    }
    if (hitKey = "") {
        this.ScreenshotToolbarHideHoverTip()
        return
    }
    if (hitKey != this.ScreenshotToolbarHoverTipLastKey) {
        this.ScreenshotToolbarHoverTipLastKey := hitKey
        this.ScreenshotToolbarShowHoverTip(hitTip, mx, my)
    }
}

    static ScreenshotEditorMenuSvgIconPath(iconKey) {
    ; 统一维护截图右键菜单图标映射（SVG 资源路径）
    baseDir := A_ScriptDir "\assets\images\screenshot-menu"
    iconMap := Map(
        "copy", baseDir "\copy.svg",
        "save", baseDir "\save.svg",
        "folder", baseDir "\folder.svg",
        "toolbar_show", baseDir "\toolbar-show.svg",
        "toolbar_hide", baseDir "\toolbar-hide.svg",
        "process", baseDir "\process.svg",
        "rotate_left", baseDir "\rotate-left.svg",
        "rotate_right", baseDir "\rotate-right.svg",
        "flip_h", baseDir "\flip-h.svg",
        "flip_v", baseDir "\flip-v.svg",
        "delete", baseDir "\delete.svg",
        "close", baseDir "\close.svg"
    )
    return iconMap.Has(iconKey) ? iconMap[iconKey] : ""
}

; 截图助手右键菜单（黑橙风格）
    static OnScreenshotEditorContextMenu(Ctrl, Info := 0, *) {

    try {
        if !this.IsScreenshotEditorActive()
            return
        CloseDarkStylePopupMenu()
        MouseGetPos(&MouseX, &MouseY)

        MenuItems := []
        MenuItems.Push({Text: "复制", Icon: "⎘", SvgIcon: this.ScreenshotEditorMenuSvgIconPath("copy"), Action: (*) => this.ScreenshotEditorCopyKeepMode()})
        MenuItems.Push({Text: "保存图片", Icon: "⬇", SvgIcon: this.ScreenshotEditorMenuSvgIconPath("save"), Action: (*) => this.ScreenshotEditorSaveKeepMode()})
        MenuItems.Push({Text: "在文件夹中查看", Icon: "▦", SvgIcon: this.ScreenshotEditorMenuSvgIconPath("folder"), Action: (*) => this.ScreenshotEditorRevealInFolder()})
        MenuItems.Push({Text: "处理图片", Icon: "◫", SvgIcon: this.ScreenshotEditorMenuSvgIconPath("process"), Action: (*) => this.ScreenshotEditorShowImageProcessMenu()})
        MenuItems.Push({Text: "弹出工具栏", Icon: "▣", SvgIcon: this.ScreenshotEditorMenuSvgIconPath("toolbar_show"), Action: (*) => this.ScreenshotEditorShowToolbarFromMenu()})
        if (this.ScreenshotEditorToolbarVisible) {
            MenuItems.Push({Text: "关闭工具栏", Icon: "◩", SvgIcon: this.ScreenshotEditorMenuSvgIconPath("toolbar_hide"), Action: (*) => this.ScreenshotEditorHideToolbarFromMenu()})
        } else {
            MenuItems.Push({Text: "关闭工具栏", Icon: "◩", SvgIcon: this.ScreenshotEditorMenuSvgIconPath("toolbar_hide"), Action: (*) => this.ScreenshotEditorHideToolbarFromMenu()})
        }
        MenuItems.Push({Text: "彻底删除", Icon: "⌦", SvgIcon: this.ScreenshotEditorMenuSvgIconPath("delete"), Action: (*) => this.ScreenshotEditorDeletePermanently()})
        MenuItems.Push({Text: "关闭", Icon: "✕", SvgIcon: this.ScreenshotEditorMenuSvgIconPath("close"), Action: (*) => this.CloseScreenshotEditor()})
        ShowDarkStylePopupMenuAt(MenuItems, MouseX + 2, MouseY + 2)
    } catch {
    }
}

    static ScreenshotEditorShowFallbackContextMenu() {
    m := Menu()
    processMenu := Menu()
    processMenu.Add("向左旋转", (*) => this.ScreenshotEditorTransformImage("rotate_left"))
    processMenu.Add("向右旋转", (*) => this.ScreenshotEditorTransformImage("rotate_right"))
    processMenu.Add("水平翻转", (*) => this.ScreenshotEditorTransformImage("flip_h"))
    processMenu.Add("垂直翻转", (*) => this.ScreenshotEditorTransformImage("flip_v"))
    m.Add("复制", (*) => this.ScreenshotEditorCopyKeepMode())
    m.Add("保存图片", (*) => this.ScreenshotEditorSaveKeepMode())
    m.Add("在文件夹中查看", (*) => this.ScreenshotEditorRevealInFolder())
    m.Add("处理图片", processMenu)
    m.Add()
    m.Add("弹出工具栏", (*) => this.ScreenshotEditorShowToolbarFromMenu())
    m.Add("关闭工具栏", (*) => this.ScreenshotEditorHideToolbarFromMenu())
    m.Add("彻底删除", (*) => this.ScreenshotEditorDeletePermanently())
    m.Add("关闭", (*) => this.CloseScreenshotEditor())
    MouseGetPos(&x, &y)
    m.Show(x, y)
}

    static ScreenshotEditorShowToolbarFromMenu() {
    try {
        this.ScreenshotEditorToolbarVisible := true
        this.ShowScreenshotEditorToolbar()
        SetTimer(ObjBindMethod(ScreenshotEditorPlugin, "ScreenshotEditorEnsureToolbarVisible"), -40)
        SetTimer(ObjBindMethod(ScreenshotEditorPlugin, "ScreenshotEditorEnsureToolbarVisible"), -140)
    } catch as e {
        TrayTip("工具栏", "弹出工具栏失败: " . e.Message, "Iconx 1")
    }
}

    static ScreenshotEditorEnsureToolbarVisible(*) {
    if (!this.ScreenshotEditorToolbarVisible)
        return
    try {
        if !(IsObject(this.GuiID_ScreenshotEditor) && this.GuiID_ScreenshotEditor != 0)
            return
        if !(IsObject(this.GuiID_ScreenshotToolbar) && this.GuiID_ScreenshotToolbar != 0)
            return
        WinGetPos(&winX, &winY, &winW, &winH, "ahk_id " . this.GuiID_ScreenshotEditor.Hwnd)
        this.GuiID_ScreenshotToolbar.Show("x" . winX . " y" . (winY + winH + 10))
        this.ScreenshotToolbar_NotifyHostMemory(true)
        this.ScreenshotToolbar_ApplyBounds()
        SetTimer(ObjBindMethod(ScreenshotEditorPlugin, "ScreenshotToolbar_RefreshComposition"), -30)
        WinSetAlwaysOnTop("On", "ahk_id " . this.GuiID_ScreenshotToolbar.Hwnd)
    } catch {
    }
}

    static ScreenshotEditorHideToolbarFromMenu() {
    try {
        this.ScreenshotEditorToolbarVisible := false
        if (this.ScreenshotEditorTitleBar)
            this.ScreenshotEditorTitleBar.Visible := false
        if (this.ScreenshotEditorCloseBtn)
            this.ScreenshotEditorCloseBtn.Visible := false
        if (this.GuiID_ScreenshotToolbar && this.GuiID_ScreenshotToolbar != 0) {
            this.ScreenshotToolbar_NotifyHostMemory(false)
            this.GuiID_ScreenshotToolbar.Hide()
        }
        this.ScreenshotEditorApplyZoom(this.ScreenshotEditorZoomScale, false)
        this.ScreenshotToolbar_SendState()
    } catch as e {
        TrayTip("工具栏", "关闭工具栏失败: " . e.Message, "Iconx 1")
    }
}

    static ScreenshotEditorCopyKeepMode() {
    this.CopyScreenshotToClipboard(false)
}

    static ScreenshotEditorSaveKeepMode() {
    this.SaveScreenshotToFile(false)
}

    static ScreenshotEditorRevealInFolder() {
    try {
        if (this.ScreenshotEditorImagePath != "" && FileExist(this.ScreenshotEditorImagePath)) {
            Run('explorer.exe /select,"' . this.ScreenshotEditorImagePath . '"')
            return
        }
        TrayTip("文件", "当前截图尚未生成可定位的文件", "Iconi 1")
    } catch as e {
        TrayTip("文件", "打开文件夹失败: " . e.Message, "Iconx 1")
    }
}

    static ScreenshotEditorShowImageProcessMenu() {
    try {
        MouseGetPos(&mx, &my)
        MenuItems := []
        MenuItems.Push({Text: "向左旋转", Icon: "↶", SvgIcon: this.ScreenshotEditorMenuSvgIconPath("rotate_left"), Action: (*) => this.ScreenshotEditorTransformImage("rotate_left")})
        MenuItems.Push({Text: "向右旋转", Icon: "↷", SvgIcon: this.ScreenshotEditorMenuSvgIconPath("rotate_right"), Action: (*) => this.ScreenshotEditorTransformImage("rotate_right")})
        MenuItems.Push({Text: "水平翻转", Icon: "⇋", SvgIcon: this.ScreenshotEditorMenuSvgIconPath("flip_h"), Action: (*) => this.ScreenshotEditorTransformImage("flip_h")})
        MenuItems.Push({Text: "垂直翻转", Icon: "⇵", SvgIcon: this.ScreenshotEditorMenuSvgIconPath("flip_v"), Action: (*) => this.ScreenshotEditorTransformImage("flip_v")})
        ShowDarkStylePopupMenuAt(MenuItems, mx + 140, my + 2)
    } catch {
    }
}

    static ScreenshotEditorTransformImage(actionType) {
    if (!this.ScreenshotEditorBitmap) {
        TrayTip("图像处理", "当前无可处理图片", "Iconx 1")
        return
    }

    rotateFlipType := 0
    switch actionType {
        case "rotate_left":
            rotateFlipType := 3
        case "rotate_right":
            rotateFlipType := 1
        case "flip_h":
            rotateFlipType := 4
        case "flip_v":
            rotateFlipType := 6
        default:
            return
    }

    try {
        st := DllCall("gdiplus\GdipImageRotateFlip", "Ptr", this.ScreenshotEditorBitmap, "Int", rotateFlipType, "Int")
        if (st != 0) {
            TrayTip("图像处理", "图像变换失败，状态码: " . st, "Iconx 1")
            return
        }

        newW := Gdip_GetImageWidth(this.ScreenshotEditorBitmap)
        newH := Gdip_GetImageHeight(this.ScreenshotEditorBitmap)
        if (!newW || !newH)
            return

        if (this.ScreenshotEditorGraphics) {
            try Gdip_DeleteGraphics(this.ScreenshotEditorGraphics)
            this.ScreenshotEditorGraphics := 0
        }
        if (this.ScreenshotEditorPreviewBitmap) {
            try Gdip_DisposeImage(this.ScreenshotEditorPreviewBitmap)
            this.ScreenshotEditorPreviewBitmap := 0
        }

        pPreview := 0
        pGraphics := 0
        ret := DllCall("gdiplus\GdipCreateBitmapFromScan0"
            , "Int", newW
            , "Int", newH
            , "Int", 0
            , "UInt", 0x26200A
            , "Ptr", 0
            , "Ptr*", &pPreview := 0)
        if (ret = 0 && pPreview) {
            ret2 := DllCall("gdiplus\GdipGetImageGraphicsContext", "Ptr", pPreview, "Ptr*", &pGraphics := 0)
            if (ret2 = 0 && pGraphics) {
                DllCall("gdiplus\GdipSetInterpolationMode", "Ptr", pGraphics, "Int", 7)
                DllCall("gdiplus\GdipDrawImageRect", "Ptr", pGraphics, "Ptr", this.ScreenshotEditorBitmap
                    , "Float", 0, "Float", 0, "Float", newW, "Float", newH)
                this.ScreenshotEditorPreviewBitmap := pPreview
                this.ScreenshotEditorGraphics := pGraphics
            } else {
                if (pPreview)
                    try Gdip_DisposeImage(pPreview)
            }
        }

        this.ScreenshotEditorPreviewWidth := newW
        this.ScreenshotEditorPreviewHeight := newH
        this.ScreenshotEditorBaseWidth := newW
        this.ScreenshotEditorBaseHeight := newH

        this.ScreenshotEditorApplyZoom(this.ScreenshotEditorZoomScale, false)
        this.ScreenshotEditorShowCurrentZoomTip()
    } catch as e {
        TrayTip("图像处理", "图像处理失败: " . e.Message, "Iconx 1")
    }
}

    static ScreenshotEditorDeletePermanently() {
    try {
        answer := MsgBox("确定要彻底删除当前截图吗？此操作不可恢复。", "彻底删除", "YesNo Iconx")
        if (answer != "Yes")
            return
        targetPath := this.ScreenshotEditorImagePath
        this.CloseScreenshotEditor()
        if (targetPath != "" && FileExist(targetPath)) {
            try FileDelete(targetPath)
        }
        TrayTip("删除", "截图已彻底删除", "Iconi 1")
    } catch as e {
        TrayTip("删除", "删除失败: " . e.Message, "Iconx 1")
    }
}

    static ScreenshotEditorToggleColorPicker() {
    if (this.ScreenshotColorPickerActive) {
        this.ScreenshotEditorStopColorPicker()
        TrayTip("取色器", "已退出取色模式", "Iconi 1")
    } else {
        this.ScreenshotEditorStartColorPicker()
    }
}

    static ScreenshotEditorStartColorPicker() {
    if !(IsObject(this.GuiID_ScreenshotEditor) && this.GuiID_ScreenshotEditor != 0)
        return
    this.ScreenshotColorPickerEnsureGui()
    this.ScreenshotColorPickerActive := true
    this.ScreenshotColorPickerTick()
    SetTimer(ObjBindMethod(ScreenshotEditorPlugin, "ScreenshotColorPickerTick"), 40)
    TrayTip("取色器", "移动鼠标查看放大镜；左键记录历史；Caps+X 退出", "Iconi 1")
}

    static ScreenshotEditorStopColorPicker() {

    SetTimer(ObjBindMethod(ScreenshotEditorPlugin, "ScreenshotColorPickerTick"), 0)
    this.ScreenshotColorPickerTickBusy := false
    this.ScreenshotColorPickerActive := false
    if (IsObject(this.GuiID_ScreenshotColorPicker) && this.GuiID_ScreenshotColorPicker != 0) {
        try this.GuiID_ScreenshotColorPicker.Destroy()
    }
    this.GuiID_ScreenshotColorPicker := 0
    this.ScreenshotColorPickerMagnifierPic := 0
    this.ScreenshotColorPickerCurrentText := 0
    this.ScreenshotColorPickerCompareText := 0
    this.ScreenshotColorPickerHistoryEdit := 0
}

    static ScreenshotColorPickerEnsureGui() {

    if (IsObject(this.GuiID_ScreenshotColorPicker) && this.GuiID_ScreenshotColorPicker != 0) {
        try this.GuiID_ScreenshotColorPicker.Show("NA")
        return
    }

    panel := Gui("+AlwaysOnTop +ToolWindow -Caption -DPIScale")
    panel.BackColor := "121820"
    panel.SetFont("s9 cE8EDF2", "Segoe UI")

    panel.Add("Text", "x12 y8 w220 h20 cFF9D3A", "屏幕取色器")
    this.ScreenshotColorPickerMagnifierPic := panel.Add("Picture", "x12 y30 w180 h180 0xE Border")
    this.ScreenshotColorPickerCurrentText := panel.Add("Text", "x200 y32 w220 h78 cE8EDF2", "当前颜色")
    this.ScreenshotColorPickerCurrentText.SetFont("s9", "Consolas")
    this.ScreenshotColorPickerCompareText := panel.Add("Text", "x200 y114 w220 h46 cAAB7C4", "对比: 未设置")

    btnCopyHex := panel.Add("Button", "x12 y220 w84 h26", "复制HEX")
    btnCopyRgb := panel.Add("Button", "x104 y220 w84 h26", "复制RGB")
    btnAnchor := panel.Add("Button", "x200 y220 w84 h26", "设为对比")
    btnHistory := panel.Add("Button", "x292 y220 w84 h26", "加入历史")
    btnClose := panel.Add("Button", "x384 y220 w36 h26", "✕")

    panel.Add("Text", "x12 y254 w170 h18 c9DB0C2", "历史颜色（最新在前）")
    this.ScreenshotColorPickerHistoryEdit := panel.Add("Edit", "x12 y274 w408 h166 ReadOnly -Wrap -VScroll cDCE9F7 Background101820", "")
    this.ScreenshotColorPickerHistoryEdit.SetFont("s10", "Consolas")

    btnCopyHex.OnEvent("Click", (*) => this.ScreenshotColorPickerCopyCurrent("hex"))
    btnCopyRgb.OnEvent("Click", (*) => this.ScreenshotColorPickerCopyCurrent("rgb"))
    btnAnchor.OnEvent("Click", (*) => this.ScreenshotColorPickerSetAnchor())
    btnHistory.OnEvent("Click", (*) => this.ScreenshotColorPickerPushCurrentToHistory())
    btnClose.OnEvent("Click", (*) => this.ScreenshotEditorStopColorPicker())

    this.GuiID_ScreenshotColorPicker := panel
    this.ScreenshotColorPickerSyncPosition()
    panel.Show("NA w432 h452")
}

    static ScreenshotColorPickerSyncPosition() {
    if !(IsObject(this.GuiID_ScreenshotEditor) && this.GuiID_ScreenshotEditor != 0)
        return
    if !(IsObject(this.GuiID_ScreenshotColorPicker) && this.GuiID_ScreenshotColorPicker != 0)
        return
    try {
        WinGetPos(&ex, &ey, &ew, &eh, "ahk_id " . this.GuiID_ScreenshotEditor.Hwnd)
        px := ex + ew + 12
        py := ey
        vL := SysGet(76), vT := SysGet(77), vW := SysGet(78), vH := SysGet(79)
        vR := vL + vW, vB := vT + vH
        panelW := 432, panelH := 452
        if (px + panelW > vR)
            px := Max(vL, ex - panelW - 12)
        if (py + panelH > vB)
            py := Max(vT, vB - panelH - 8)
        this.GuiID_ScreenshotColorPicker.Show("NA x" . px . " y" . py . " w" . panelW . " h" . panelH)
    } catch {
    }
}

    static ScreenshotColorPickerCaptureAtCursor() {
    if (!this.ScreenshotColorPickerActive)
        return
    try {
        MouseGetPos(&mx, &my, &hoverHwnd)
        if (IsObject(this.GuiID_ScreenshotColorPicker) && this.GuiID_ScreenshotColorPicker != 0) {
            if (hoverHwnd = this.GuiID_ScreenshotColorPicker.Hwnd
                || DllCall("user32\IsChild", "ptr", this.GuiID_ScreenshotColorPicker.Hwnd, "ptr", hoverHwnd, "int")) {
                return
            }
        }
        colorInfo := this.ScreenshotColorPickerGetColorInfo(mx, my)
        this.ScreenshotColorPickerAddHistory(colorInfo)
        this.ScreenshotColorPickerRefreshHistoryText()
        TrayTip("取色", "已记录 " . colorInfo["hex"], "Iconi 1")
    } catch {
    }
}

    static ScreenshotColorPickerTick(*) {

    if (!this.ScreenshotColorPickerActive)
        return
    if (this.ScreenshotColorPickerTickBusy)
        return
    this.ScreenshotColorPickerTickBusy := true
    try {
        if !(IsObject(this.GuiID_ScreenshotEditor) && this.GuiID_ScreenshotEditor != 0) {
            this.ScreenshotEditorStopColorPicker()
            return
        }
        if !(IsObject(this.GuiID_ScreenshotColorPicker) && this.GuiID_ScreenshotColorPicker != 0) {
            this.ScreenshotColorPickerEnsureGui()
        }
        MouseGetPos(&mx, &my)
        colorInfo := this.ScreenshotColorPickerGetColorInfo(mx, my)
        this.ScreenshotColorPickerCurrent := colorInfo
        if (this.ScreenshotColorPickerCurrentText) {
            this.ScreenshotColorPickerCurrentText.Value :=
                "屏幕: (" . mx . ", " . my . ")`n"
                . "HEX: " . colorInfo["hex"] . "`n"
                . "hex: " . colorInfo["hex_lower"] . "`n"
                . "RGB: " . colorInfo["rgb"]
        }
        if (this.ScreenshotColorPickerCompareText) {
            this.ScreenshotColorPickerCompareText.Value := this.ScreenshotColorPickerBuildCompareText(colorInfo, this.ScreenshotColorPickerAnchor)
        }
        this.ScreenshotColorPickerRenderMagnifier(mx, my)
    } catch {
    } finally {
        this.ScreenshotColorPickerTickBusy := false
    }
}

    static ScreenshotColorPickerGetColorInfo(x, y) {
    color := PixelGetColor(x, y, "RGB")
    r := (color >> 16) & 0xFF
    g := (color >> 8) & 0xFF
    b := color & 0xFF
    info := Map()
    info["value"] := color
    info["r"] := r
    info["g"] := g
    info["b"] := b
    info["hex"] := Format("#{1:06X}", color)
    info["hex_lower"] := StrLower(info["hex"])
    info["rgb"] := "rgb(" . r . ", " . g . ", " . b . ")"
    return info
}

    static ScreenshotColorPickerBuildCompareText(current, anchor) {
    if !(anchor is Map) || anchor.Count = 0
        return "对比: 未设置（点击“设为对比”）"
    dr := current["r"] - anchor["r"]
    dg := current["g"] - anchor["g"]
    db := current["b"] - anchor["b"]
    distance := Round(Sqrt(dr * dr + dg * dg + db * db), 2)
    return "对比基准: " . anchor["hex"] . "`n"
        . "ΔRGB: (" . dr . ", " . dg . ", " . db . ")  |  距离: " . distance
}

    static ScreenshotColorPickerCaptureScreenBitmapNative(x, y, w, h) {
    if (w <= 0 || h <= 0)
        return 0
    hdcScreen := 0, hdcMem := 0, hbm := 0, obm := 0, pBitmap := 0
    try {
        hdcScreen := DllCall("user32\GetDC", "ptr", 0, "ptr")
        if (!hdcScreen)
            return 0
        hdcMem := DllCall("gdi32\CreateCompatibleDC", "ptr", hdcScreen, "ptr")
        if (!hdcMem)
            return 0
        hbm := DllCall("gdi32\CreateCompatibleBitmap", "ptr", hdcScreen, "int", w, "int", h, "ptr")
        if (!hbm)
            return 0
        obm := DllCall("gdi32\SelectObject", "ptr", hdcMem, "ptr", hbm, "ptr")
        ; SRCCOPY | CAPTUREBLT，优先抓取合成后的屏幕内容
        DllCall("gdi32\BitBlt"
            , "ptr", hdcMem, "int", 0, "int", 0, "int", w, "int", h
            , "ptr", hdcScreen, "int", x, "int", y, "uint", 0x00CC0020 | 0x40000000)
        pBitmap := Gdip_CreateBitmapFromHBITMAP(hbm)
    } catch {
        pBitmap := 0
    } finally {
        if (obm && hdcMem)
            try DllCall("gdi32\SelectObject", "ptr", hdcMem, "ptr", obm, "ptr")
        if (hbm)
            try DeleteObject(hbm)
        if (hdcMem)
            try DllCall("gdi32\DeleteDC", "ptr", hdcMem)
        if (hdcScreen)
            try DllCall("user32\ReleaseDC", "ptr", 0, "ptr", hdcScreen)
    }
    return pBitmap
}

    static ScreenshotColorPickerRenderMagnifier(mouseX, mouseY) {
    if (!this.ScreenshotColorPickerMagnifierPic)
        return
    sampleSize := 15
    zoom := 12
    drawSize := sampleSize * zoom
    startX := mouseX - (sampleSize // 2)
    startY := mouseY - (sampleSize // 2)

    pSrc := 0, pDst := 0, pG := 0, hBitmap := 0, pPen := 0
    try {
        pSrc := this.ScreenshotColorPickerCaptureScreenBitmapNative(startX, startY, sampleSize, sampleSize)
        if (!pSrc)
            return
        pDst := Gdip_CreateBitmap(drawSize, drawSize)
        if (!pDst)
            return
        pG := Gdip_GraphicsFromImage(pDst)
        if (!pG)
            return

        Gdip_SetInterpolationMode(pG, 5)  ; NearestNeighbor
        Gdip_DrawImage(pG, pSrc, 0, 0, drawSize, drawSize, 0, 0, sampleSize, sampleSize)

        centerCell := (sampleSize // 2) * zoom
        pPen := Gdip_CreatePen(0xFFFF8A00, 2)
        if (pPen) {
            Gdip_DrawRectangle(pG, pPen, centerCell, centerCell, zoom, zoom)
        }

        hBitmap := Gdip_CreateHBITMAPFromBitmap(pDst)
        if (hBitmap) {
            SetImage(this.ScreenshotColorPickerMagnifierPic.Hwnd, hBitmap)
            hBitmap := 0
        }
    } catch {
    } finally {
        if (pPen)
            try Gdip_DeletePen(pPen)
        if (pG)
            try Gdip_DeleteGraphics(pG)
        if (pDst)
            try Gdip_DisposeImage(pDst)
        if (pSrc)
            try Gdip_DisposeImage(pSrc)
    }
}

    static ScreenshotColorPickerCopyCurrent(copyType) {
    if !(this.ScreenshotColorPickerCurrent is Map) || this.ScreenshotColorPickerCurrent.Count = 0
        return
    if (copyType = "rgb") {
        A_Clipboard := this.ScreenshotColorPickerCurrent["rgb"]
        TrayTip("取色器", "RGB 已复制", "Iconi 1")
    } else {
        A_Clipboard := this.ScreenshotColorPickerCurrent["hex"]
        TrayTip("取色器", "HEX 已复制", "Iconi 1")
    }
}

    static ScreenshotColorPickerSetAnchor() {
    if !(this.ScreenshotColorPickerCurrent is Map) || this.ScreenshotColorPickerCurrent.Count = 0
        return
    anchor := Map()
    for k, v in this.ScreenshotColorPickerCurrent
        anchor[k] := v
    this.ScreenshotColorPickerAnchor := anchor
    if (this.ScreenshotColorPickerCompareText)
        this.ScreenshotColorPickerCompareText.Value := this.ScreenshotColorPickerBuildCompareText(this.ScreenshotColorPickerCurrent, this.ScreenshotColorPickerAnchor)
    TrayTip("取色器", "已设置对比基准: " . anchor["hex"], "Iconi 1")
}

    static ScreenshotColorPickerPushCurrentToHistory() {
    if !(this.ScreenshotColorPickerCurrent is Map) || this.ScreenshotColorPickerCurrent.Count = 0
        return
    this.ScreenshotColorPickerAddHistory(this.ScreenshotColorPickerCurrent)
    this.ScreenshotColorPickerRefreshHistoryText()
}

    static ScreenshotColorPickerAddHistory(colorInfo) {
    if !(this.ScreenshotColorPickerHistory is Array)
        this.ScreenshotColorPickerHistory := []
    item := Map()
    for k, v in colorInfo
        item[k] := v
    item["time"] := FormatTime(A_Now, "HH:mm:ss")
    this.ScreenshotColorPickerHistory.InsertAt(1, item)
    while (this.ScreenshotColorPickerHistory.Length > 12) {
        this.ScreenshotColorPickerHistory.Pop()
    }
}

    static ScreenshotColorPickerRefreshHistoryText() {
    if (!this.ScreenshotColorPickerHistoryEdit)
        return
    if !(this.ScreenshotColorPickerHistory is Array) || this.ScreenshotColorPickerHistory.Length = 0 {
        this.ScreenshotColorPickerHistoryEdit.Value := "序号  时间       HEX      hex      RGB`r`n---------------------------------------------`r`n暂无历史颜色（点击“加入历史”或左键取样）"
        return
    }
    txt := "序号  时间       HEX       hex       RGB`r`n"
    txt .= "---------------------------------------------------------------`r`n"
    for idx, item in this.ScreenshotColorPickerHistory {
        seq := Format("{1:02}", idx)
        hexUpper := item["hex"]
        hexLower := item.Has("hex_lower") ? item["hex_lower"] : StrLower(hexUpper)
        txt .= seq . "    " . item["time"] . "   " . hexUpper . "  " . hexLower . "  " . item["rgb"] . "`r`n"
    }
    this.ScreenshotColorPickerHistoryEdit.Value := RTrim(txt, "`r`n")
}

; 粘贴OCR文本到Cursor
    static PasteOCRTextToCursor(Text, OCRResultGui) {
    try {
        ; 关闭OCR结果窗口
        if (OCRResultGui) {
            OCRResultGui.Destroy()
        }
        
        ; 将文本复制到剪贴板
        A_Clipboard := Text
        Sleep(200)
        
        ; 激活Cursor窗口
        try {
            WinActivate("ahk_exe Cursor.exe")
            Sleep(300)
        } catch as e {
            ; 如果Cursor未运行，显示提示
            TrayTip("提示", "请先打开Cursor窗口", "Iconi 1")
            return
        }
        
        ; 按ESC关闭可能已打开的输入框
        Send("{Escape}")
        Sleep(100)
        
        ; 按Ctrl+L打开AI聊天面板
        Send("^l")
        Sleep(300)
        
        ; 粘贴文本
        Send("^v")
        Sleep(200)
        
        TrayTip("成功", "已粘贴OCR文本到Cursor", "Iconi 1")
    } catch as e {
        TrayTip("错误", "粘贴失败: " . e.Message, "Iconx 2")
    }
}

; 执行OCR识别
; 为代码OCR预处理位图（放大、裁剪、增强对比度）
    static PrepareBitmapForCodeOCR(pBitmap) {
    if (!pBitmap || pBitmap <= 0) {
        return 0
    }
    
    G := 0
    pNew := 0
    pAttr := 0
    
    try {
        ; 获取原始尺寸
        Width := Gdip_GetImageWidth(pBitmap)
        Height := Gdip_GetImageHeight(pBitmap)
        
        if (Width <= 0 || Height <= 0) {
            return 0
        }
        
        ; 1. 比例缩放：如果高度小于500px，放大2倍
        scale := (Height < 500) ? 2 : 1
        margin := 8  ; 四周内缩8像素
        
        ; 确保裁剪后尺寸有效
        if (Width <= margin * 2 || Height <= margin * 2) {
            ; 如果图片太小，不进行裁剪，只进行缩放
            margin := 0
        }
        
        ; 计算裁剪后的源尺寸
        srcW := Width - (margin * 2)
        srcH := Height - (margin * 2)
        
        if (srcW <= 0 || srcH <= 0) {
            ; 如果裁剪后无效，使用原始尺寸
            srcW := Width
            srcH := Height
            margin := 0
        }
        
        ; 计算新尺寸（裁剪后放大）
        newW := Floor(srcW * scale)
        newH := Floor(srcH * scale)
        
        if (newW <= 0 || newH <= 0) {
            return 0
        }
        
        ; 创建新位图
        pNew := Gdip_CreateBitmap(newW, newH)
        if (!pNew || pNew <= 0) {
            return 0
        }
        
        ; 获取图形上下文
        G := Gdip_GraphicsFromImage(pNew)
        if (!G || G <= 0) {
            Gdip_DisposeImage(pNew)
            return 0
        }
        
        ; 设置高质量插值模式
        Gdip_SetInterpolationMode(G, 7)  ; HighQualityBicubic
        
        ; 2. 应用极致对比度颜色矩阵
        ; 矩阵格式：2.5|0|0|0|0|0|2.5|0|0|0|0|0|2.5|0|0|0|0|0|1|0|-1|-1|-1|0|1
        Matrix := "2.5|0|0|0|0|0|2.5|0|0|0|0|0|2.5|0|0|0|0|0|1|0|-1|-1|-1|0|1"
        pAttr := Gdip_SetImageAttributesColorMatrix(Matrix)
        
        ; 3. 绘制时进行偏移（实现裁剪边缘）
        ; 从源位图的(margin, margin)位置开始，尺寸为(srcW, srcH)
        ; 绘制到新位图的(0, 0)位置，尺寸为(newW, newH)（已放大）
        srcX := margin
        srcY := margin
        
        ; 绘制图像（应用颜色矩阵和裁剪，同时放大）
        ; Gdip_DrawImage(pGraphics, pBitmap, dx, dy, dw, dh, sx, sy, sw, sh, Matrix)
        result := Gdip_DrawImage(G, pBitmap, 0, 0, newW, newH, srcX, srcY, srcW, srcH, pAttr)
        
        ; 检查绘制是否成功
        if (result != 0) {
            ; 绘制失败，释放资源并返回0
            if (pAttr) {
                Gdip_DisposeImageAttributes(pAttr)
            }
            Gdip_DeleteGraphics(G)
            Gdip_DisposeImage(pNew)
            return 0
        }
        
        ; 释放资源
        if (pAttr) {
            Gdip_DisposeImageAttributes(pAttr)
            pAttr := 0
        }
        Gdip_DeleteGraphics(G)
        G := 0
        
        return pNew
    } catch as e {
        ; 如果出错，释放已创建的资源
        if (G && G > 0) {
            try Gdip_DeleteGraphics(G)
        }
        if (pNew && pNew > 0) {
            try Gdip_DisposeImage(pNew)
        }
        if (pAttr && pAttr > 0) {
            try Gdip_DisposeImageAttributes(pAttr)
        }
        return 0
    }
}

; 清洗代码OCR结果文本
    static CleanCodeOCRText(ResultObj) {
    ; 首先尝试直接返回 Text 属性
    try {
        if (ResultObj.HasProp("Text") && ResultObj.Text != "") {
            return ResultObj.Text
        }
    } catch {
    }

    ; 如果没有 Text 属性或为空，尝试从 Words 构建
    try {
        if (!ResultObj.HasProp("Words")) {
            return ""
        }

        Words := ResultObj.Words
        if (!Words || Words.Length = 0) {
            return ""
        }

        ; 计算所有字符的平均高度
        sumH := 0
        wordCount := 0
        for w in Words {
            try {
                if (w.HasProp("h") && w.h > 0) {
                    sumH += w.h
                    wordCount++
                }
            } catch {
                continue
            }
        }

        if (wordCount = 0) {
            ; 如果无法获取高度信息，直接拼接所有单词
            simpleText := ""
            for w in Words {
                try {
                    if (w.HasProp("Text")) {
                        simpleText .= w.Text . " "
                    }
                } catch {
                }
            }
            return Trim(simpleText)
        }

        avgH := sumH / wordCount

        ; 按行组织单词（根据y坐标）
        lines := Map()
        for w in Words {
            try {
                ; 过滤掉异常高度的字符（噪点或边框）
                if (!w.HasProp("h") || w.h <= 0) {
                    continue
                }
                if (w.h < avgH * 0.4 || w.h > avgH * 2.0) {
                    continue
                }

                ; 简单的行合并逻辑（根据y坐标，每10像素为一组）
                yKey := Round(w.y / 10) * 10
                if (!lines.Has(yKey)) {
                    lines[yKey] := []
                }
                lines[yKey].Push(w)
            } catch {
                continue
            }
        }

        ; 按y坐标排序
        sortedYKeys := []
        for yKey in lines {
            sortedYKeys.Push(yKey)
        }
        sortedYKeys.Sort()

        ; 构建最终文本
        finalText := ""
        for yKey in sortedYKeys {
            words := lines[yKey]

            ; 按x坐标排序单词
            wordsArray := []
            for w in words {
                wordsArray.Push(w)
            }
            ; 按x坐标排序（使用Sort方法）
            wordsArray.Sort((a, b) => a.x - b.x)

            ; 构建行文本
            lineStr := ""
            for w in wordsArray {
                try {
                    ; 访问Word对象的Text属性
                    if (w.HasProp("Text")) {
                        lineStr .= w.Text . " "
                    }
                } catch {
                    ; 如果访问失败，跳过该单词
                }
            }
            
            ; 正则清理行首行尾干扰符
            lineStr := RegExReplace(lineStr, "^[|!_I:.\-]\s*", "")
            lineStr := RegExReplace(lineStr, "\s*[|!_I:.\-]$", "")
            
            ; 修正代码常见符号：单独出现的 | 在行首或行尾时移除
            lineStr := RegExReplace(lineStr, "^\s*\|\s+", "")
            lineStr := RegExReplace(lineStr, "\s+\|\s*$", "")
            
            ; 移除多余空格
            lineStr := RegExReplace(lineStr, "\s+", " ")
            lineStr := Trim(lineStr)
            
            if (lineStr != "") {
                finalText .= lineStr . "`n"
            }
        }
        
        return Trim(finalText, "`n")
    } catch as e {
        ; 如果清洗失败，返回原始文本
        try {
            return ResultObj.Text
        } catch {
            return ""
        }
    }
}

    static ScreenshotOCRLoadPrefs() {
    global ConfigFile
    static loaded := false
    if (loaded)
        return
    loaded := true
    try {
        mode := IniRead(ConfigFile, "Settings", "ScreenshotOCRTextLayoutMode", this.ScreenshotOCRTextLayoutMode)
        punct := IniRead(ConfigFile, "Settings", "ScreenshotOCRPunctuationMode", this.ScreenshotOCRPunctuationMode)
        directCopy := IniRead(ConfigFile, "Settings", "ScreenshotOCRDirectCopyEnabled", this.ScreenshotOCRDirectCopyEnabled ? "1" : "0")

        if (mode != "auto" && mode != "single_line" && mode != "multi_line")
            mode := "auto"
        if (punct != "keep" && punct != "halfwidth" && punct != "strip")
            punct := "keep"
        this.ScreenshotOCRTextLayoutMode := mode
        this.ScreenshotOCRPunctuationMode := punct
        this.ScreenshotOCRDirectCopyEnabled := (String(directCopy) = "1")
    } catch {
    }
}

    static ScreenshotOCRSavePrefs() {
    global ConfigFile
    try IniWrite(this.ScreenshotOCRTextLayoutMode, ConfigFile, "Settings", "ScreenshotOCRTextLayoutMode")
    try IniWrite(this.ScreenshotOCRPunctuationMode, ConfigFile, "Settings", "ScreenshotOCRPunctuationMode")
    try IniWrite(this.ScreenshotOCRDirectCopyEnabled ? "1" : "0", ConfigFile, "Settings", "ScreenshotOCRDirectCopyEnabled")
}

    static ScreenshotOCRNormalizePunctuationHalfwidth(Text) {
    charMap := Map(
        "，", ",", "。", ".", "：", ":", "；", ";", "！", "!", "？", "?",
        "（", "(", "）", ")", "【", "[", "】", "]", "《", "<", "》", ">",
        "“", '"', "”", '"', "‘", "'", "’", "'",
        "、", ",", "——", "-", "…", "..."
    )
    out := Text
    for k, v in charMap
        out := StrReplace(out, k, v)
    return out
}

    static ScreenshotOCRStripPunctuation(Text) {
    ; Remove most punctuation/symbols while keeping letters/digits/chinese/newlines/spaces.
    return RegExReplace(Text, "[^\p{L}\p{N}\x{4E00}-\x{9FFF}\s`r`n]+", "")
}

    static ScreenshotOCRApplyTextFormattingByMode(Text, layoutMode, punctMode) {
    out := String(Text)
    if (layoutMode = "multi_line") {
        out := ProcessOCRTextPreserveLayout(out)
    } else if (layoutMode = "single_line") {
        out := ProcessOCRTextAutoFlow(out)
    } else {
        ; auto: choose by structure (many short lines -> multiline, else single line)
        lineCount := 0
        shortLineCount := 0
        lines := StrSplit(StrReplace(out, "`r", ""), "`n")
        for _, line in lines {
            t := Trim(line)
            if (t = "")
                continue
            lineCount += 1
            if (StrLen(t) <= 18)
                shortLineCount += 1
        }
        if (lineCount >= 3 && shortLineCount * 1.0 / lineCount >= 0.55) {
            out := ProcessOCRTextPreserveLayout(out)
        } else {
            out := ProcessOCRTextAutoFlow(out)
        }
    }

    if (punctMode = "halfwidth") {
        out := this.ScreenshotOCRNormalizePunctuationHalfwidth(out)
    } else if (punctMode = "strip") {
        out := this.ScreenshotOCRStripPunctuation(out)
        out := RegExReplace(out, "[ \t]{2,}", " ")
        out := RegExReplace(out, "(`r?`n){3,}", "`n`n")
    }
    return Trim(out)
}

    static ScreenshotOCRApplyTextFormatting(Text) {
    this.ScreenshotOCRLoadPrefs()
    return this.ScreenshotOCRApplyTextFormattingByMode(Text, this.ScreenshotOCRTextLayoutMode, this.ScreenshotOCRPunctuationMode)
}

    static ScreenshotOCRLayoutModeLabel(layoutMode) {
    if (layoutMode = "single_line")
        return "移除换行"
    if (layoutMode = "multi_line")
        return "多行"
    return "自动"
}

    static ScreenshotOCRPunctuationModeLabel(punctMode) {
    if (punctMode = "halfwidth")
        return "半角"
    if (punctMode = "strip")
        return "去标点"
    return "保留"
}

; 执行截图OCR识别（优化版，专为代码截图设计）
    static ExecuteScreenshotOCR() {
    
    ToolTip("正在优化代码格式并识别...")
    
    try {
        ; 使用截图编辑器中的位图
        if (!this.ScreenshotEditorBitmap || this.ScreenshotEditorBitmap <= 0) {
            TrayTip("错误", "截图位图不存在", "Iconx 2")
            ToolTip()
            return
        }
        
        ; 验证位图有效性
        try {
            testWidth := Gdip_GetImageWidth(this.ScreenshotEditorBitmap)
            testHeight := Gdip_GetImageHeight(this.ScreenshotEditorBitmap)
            if (testWidth <= 0 || testHeight <= 0) {
                throw Error("位图尺寸无效: " . testWidth . "x" . testHeight)
            }
        } catch as e {
            TrayTip("错误", "位图无效: " . e.Message, "Iconx 2")
            ToolTip()
            return
        }
        
        ; 不使用预处理，直接保存为临时文件进行 OCR
        ; 因为 OCR.FromBitmap 可能不稳定，改用 OCR.FromFile
        TempPath := A_Temp "\OCR_Screenshot_" . A_TickCount . ".png"
        result := Gdip_SaveBitmapToFile(this.ScreenshotEditorBitmap, TempPath)
        if (result != 0) {
            TrayTip("错误", "保存临时图片失败", "Iconx 2")
            ToolTip()
            return
        }

        ; 调用OCR识别（指定中文语言）
        ToolTip("正在识别文字...")
        Result := OCR.FromFile(TempPath, "zh-CN")

        ; 删除临时文件
        try {
            FileDelete(TempPath)
        } catch {
        }

        if (!Result) {
            TrayTip("提示", "OCR识别失败，请重试", "Iconi 1")
            ToolTip()
            return
        }
        
        ; 获取识别文本
        cleanedText := ""
        try {
            ; 优先使用 Text 属性
            if (Result.HasProp("Text") && Result.Text != "") {
                cleanedText := Result.Text
            }
        } catch {
        }

        ; 如果 Text 为空，尝试清洗处理
        if (cleanedText = "") {
            try {
                cleanedText := this.CleanCodeOCRText(Result)
            } catch as e {
                TrayTip("错误", "处理OCR结果失败: " . e.Message, "Iconx 2")
                ToolTip()
                return
            }
        }

        if (cleanedText = "") {
            TrayTip("提示", "未识别到文字，请确保截图包含清晰的文字内容", "Iconi 1")
            ToolTip()
            return
        }
        
        this.ScreenshotOCRLoadPrefs()

        if (this.ScreenshotOCRDirectCopyEnabled) {
            directText := this.ScreenshotOCRApplyTextFormatting(cleanedText)
            A_Clipboard := directText
            TrayTip("识别完成", "已直接复制文本（" . this.ScreenshotOCRLayoutModeLabel(this.ScreenshotOCRTextLayoutMode) . "）", "Iconi 1")
            ToolTip()
            return
        }

        ; 显示OCR结果（支持复制排版）
        OCRResultGui := Gui("+AlwaysOnTop -Caption")
        OCRResultGui.BackColor := UI_Colors.Background
        OCRResultGui.SetFont("s10 c" . UI_Colors.Text, "Segoe UI")
        OCRResultGui.OnEvent("Escape", (*) => OCRResultGui.Destroy())

        rawText := cleanedText
        layoutMode := this.ScreenshotOCRTextLayoutMode
        punctuationMode := this.ScreenshotOCRPunctuationMode
        previewText := this.ScreenshotOCRApplyTextFormattingByMode(rawText, layoutMode, punctuationMode)

        ResultText := OCRResultGui.Add("Edit", "x10 y10 w560 h310 ReadOnly Multi Background" . UI_Colors.InputBg . " c" . UI_Colors.Text, previewText)
        ResultText.SetFont("s11", "Consolas")

        CloseBtn := OCRResultGui.Add("Text", "x550 y2 w20 h20 Center 0x200 c" . UI_Colors.Text . " Background" . UI_Colors.Background, "✕")
        CloseBtn.SetFont("s10", "Segoe UI")
        CloseBtn.OnEvent("Click", (*) => OCRResultGui.Destroy())
        HoverBtnWithAnimation(CloseBtn, UI_Colors.Background, UI_Colors.BtnDanger)

        DirectCopyCheck := OCRResultGui.Add("CheckBox", "x10 y330 w180 h24 c" . UI_Colors.Text, "下次直接复制文本")
        DirectCopyCheck.Value := this.ScreenshotOCRDirectCopyEnabled ? 1 : 0

        LayoutBtn := OCRResultGui.Add("Text", "x340 y328 w90 h30 Center 0x200 cFFFFFF Background" . UI_Colors.BtnBg, "排版")
        LayoutBtn.SetFont("s10", "Segoe UI")
        HoverBtnWithAnimation(LayoutBtn, UI_Colors.BtnBg, UI_Colors.BtnHover)

        CopyBtn := OCRResultGui.Add("Text", "x438 y328 w64 h30 Center 0x200 cFFFFFF Background" . UI_Colors.BtnPrimary, "复制")
        CopyBtn.SetFont("s10", "Segoe UI")
        HoverBtnWithAnimation(CopyBtn, UI_Colors.BtnPrimary, UI_Colors.BtnPrimaryHover)

        PasteBtn := OCRResultGui.Add("Text", "x506 y328 w64 h30 Center 0x200 cFFFFFF Background" . UI_Colors.BtnPrimary, "粘贴")
        PasteBtn.SetFont("s10", "Segoe UI")
        HoverBtnWithAnimation(PasteBtn, UI_Colors.BtnPrimary, UI_Colors.BtnPrimaryHover)

        RefreshPreviewText() {
            formatted := this.ScreenshotOCRApplyTextFormattingByMode(rawText, layoutMode, punctuationMode)
            ResultText.Value := formatted
            LayoutBtn.Value := "排版 " . this.ScreenshotOCRLayoutModeLabel(layoutMode)
        }

        SaveModeToGlobal() {
            this.ScreenshotOCRTextLayoutMode := layoutMode
            this.ScreenshotOCRPunctuationMode := punctuationMode
            this.ScreenshotOCRSavePrefs()
        }

        CopyCurrentText(*) {
            txt := ResultText.Value
            if (txt = "") {
                TrayTip("复制", "没有可复制的文本", "Iconx 1")
                return
            }
            A_Clipboard := txt
            TrayTip("复制", "文本已复制到剪贴板", "Iconi 1")
        }

        PasteCurrentText(*) {
            txt := ResultText.Value
            if (txt = "") {
                TrayTip("粘贴", "没有可粘贴的文本", "Iconx 1")
                return
            }
            this.PasteOCRTextToCursor(txt, OCRResultGui)
        }

        ShowLayoutMenu(*) {
            punctMenu := Menu()
            punctMenu.Add((punctuationMode = "keep" ? "✓ " : "") . "保留标点", (*) => (punctuationMode := "keep", SaveModeToGlobal(), RefreshPreviewText()))
            punctMenu.Add((punctuationMode = "halfwidth" ? "✓ " : "") . "转半角标点", (*) => (punctuationMode := "halfwidth", SaveModeToGlobal(), RefreshPreviewText()))
            punctMenu.Add((punctuationMode = "strip" ? "✓ " : "") . "移除标点", (*) => (punctuationMode := "strip", SaveModeToGlobal(), RefreshPreviewText()))

            layoutMenu := Menu()
            layoutMenu.Add((layoutMode = "auto" ? "✓ " : "") . "自动", (*) => (layoutMode := "auto", SaveModeToGlobal(), RefreshPreviewText()))
            layoutMenu.Add((layoutMode = "single_line" ? "✓ " : "") . "移除换行符", (*) => (layoutMode := "single_line", SaveModeToGlobal(), RefreshPreviewText()))
            layoutMenu.Add((layoutMode = "multi_line" ? "✓ " : "") . "多行", (*) => (layoutMode := "multi_line", SaveModeToGlobal(), RefreshPreviewText()))
            layoutMenu.Add()
            layoutMenu.Add("标点", punctMenu)

            MouseGetPos(&mx, &my)
            layoutMenu.Show(mx, my)
        }

        DirectCopyCheck.OnEvent("Click", (*) => (
            this.ScreenshotOCRDirectCopyEnabled := (DirectCopyCheck.Value = 1),
            this.ScreenshotOCRSavePrefs()
        ))
        LayoutBtn.OnEvent("Click", ShowLayoutMenu)
        CopyBtn.OnEvent("Click", CopyCurrentText)
        PasteBtn.OnEvent("Click", PasteCurrentText)
        OCRResultGui.Show("w580 h366")
        RefreshPreviewText()
        ToolTip()
    } catch as e {
        ToolTip()
        TrayTip("错误", "OCR识别失败: " . e.Message, "Iconx 2")
    }
}

    static ScreenshotEditorExtractText(showProgressTip := true) {

    try {
        if (!this.ScreenshotEditorBitmap || this.ScreenshotEditorBitmap <= 0) {
            TrayTip("错误", "没有可用的截图", "Iconx 2")
            return ""
        }

        if (showProgressTip) {
            TrayTip("识别中", "正在识别截图文本...", "Iconi 1")
        }

        tempPath := A_Temp "\OCR_SS_Action_" . A_TickCount . ".png"
        result := Gdip_SaveBitmapToFile(this.ScreenshotEditorBitmap, tempPath)
        if (result != 0) {
            TrayTip("错误", "保存临时图片失败", "Iconx 2")
            return ""
        }

        ocrResult := OCR.FromFile(tempPath, "zh-CN")
        try FileDelete(tempPath)

        if (!ocrResult) {
            TrayTip("错误", "OCR识别失败", "Iconx 2")
            return ""
        }

        recognizedText := ""
        try {
            if (ocrResult.HasProp("Text")) {
                recognizedText := Trim(String(ocrResult.Text))
            }
        } catch {
            recognizedText := ""
        }

        if (recognizedText = "") {
            TrayTip("提示", "未识别到可用文本", "Iconi 1")
            return ""
        }
        return recognizedText
    } catch as e {
        TrayTip("错误", "OCR识别失败: " . e.Message, "Iconx 2")
        return ""
    }
}

    static ScreenshotEditorSendToAI() {
    text := this.ScreenshotEditorExtractText(true)
    if (text = "")
        return
    try {
        ok := FloatingToolbar_SendTextToNiumaChat(text, true, true, true)
        if (ok) {
            TrayTip("AI", "截图文本已发送到 AI", "Iconi 1")
        } else {
            TrayTip("AI", "发送失败，请重试", "Iconx 1")
        }
    } catch as e {
        TrayTip("AI", "发送失败: " . e.Message, "Iconx 1")
    }
}

    static ScreenshotEditorSearchText() {
    text := this.ScreenshotEditorExtractText(true)
    if (text = "")
        return
    try {
        SearchCenter_RunQueryWithKeyword(text)
    } catch as e {
        TrayTip("搜索", "打开搜索失败: " . e.Message, "Iconx 1")
    }
}

    static ScreenshotEditorEditOCRInHubCapsule() {
    text := this.ScreenshotEditorExtractText(true)
    if (text = "")
        return
    formatted := this.ScreenshotOCRApplyTextFormatting(text)
    if (formatted = "")
        return
    ; 去掉截图工具栏自建的 HubCapsule 联动轮询机制，改为复用悬浮工具栏/SelectionSense 的标准打开与预览填充链路：
    ; SelectionSense_OpenHubCapsuleFromToolbar 会设置 pendingText 并在 WebView ready 后自动推送到预览区。
    try {
        global g_SelSense_MenuActivateOnShow
        g_SelSense_MenuActivateOnShow := true
    } catch {
    }

    ; 直接调用 HubCapsule 原生接口（SelectionSenseCore），并用“CapsLock+C 同款重推”保证预览区一定收到文本
    try {
        try g_SelSense_PendingText := formatted
        SelectionSense_OpenHubCapsuleFromToolbar(false, formatted)
        ; HubCapsule/WebView2 冷启动时 selection_menu_ready 可能滞后，延迟重推两次 + 轮询兜底
        SetTimer(this.ScreenshotEditor_ResyncHubPreviewAfterOcrBind(formatted), -250)
        SetTimer(this.ScreenshotEditor_ResyncHubPreviewAfterOcrBind(formatted), -850)
        TrayTip("草稿本", "已打开 HubCapsule 并填入 OCR 文本", "Iconi 1")
        return
    } catch as e1 {
        ; 可能是模块未初始化/热重载顺序问题：尝试先 Init 再调用一次
        try {
            if FuncExists("SelectionSense_Init")
                SelectionSense_Init()
        } catch {
        }
        try {
            SelectionSense_OpenHubCapsuleFromToolbar(false, formatted)
            SetTimer(this.ScreenshotEditor_ResyncHubPreviewAfterOcrBind(formatted), -250)
            SetTimer(this.ScreenshotEditor_ResyncHubPreviewAfterOcrBind(formatted), -850)
            TrayTip("草稿本", "已打开 HubCapsule 并填入 OCR 文本", "Iconi 1")
            return
        } catch as e2 {
            ; 原生兜底：走命令系统触发 hub_capsule（与悬浮工具栏/虚拟键盘同源）
            try {
                if FuncExists("_ExecuteCommand") {
                    _ExecuteCommand("hub_capsule")
                    ; 把文本挂到 SelectionSense pending，等 ready 后由其推送
                    try g_SelSense_PendingText := formatted
                    SetTimer(this.ScreenshotEditor_ResyncHubPreviewAfterOcrBind(formatted), -250)
                    SetTimer(this.ScreenshotEditor_ResyncHubPreviewAfterOcrBind(formatted), -850)
                    TrayTip("草稿本", "已触发 hub_capsule 打开，请稍候…", "Iconi 1")
                    return
                }
            } catch {
            }
            ; 最后兜底：无法打开则复制到剪贴板
            try A_Clipboard := formatted
            TrayTip("草稿本", "HubCapsule 入口不可用，已复制 OCR 文本到剪贴板", "Iconi 1")
            return
        }
    }
}

; OCR -> HubCapsule：按 CapsLock+C 的逻辑重推一次预览文本，覆盖 WebView2 冷启动/动画期丢消息
    static ScreenshotEditor_ResyncHubPreviewAfterOcrBind(text) {
    ; Bind helper：返回闭包，避免 AHK v2 SetTimer 直接传参的兼容问题
    return (*) => this.ScreenshotEditor_ResyncHubPreviewAfterOcrTick(text)
}

    static ScreenshotEditor_ResyncHubPreviewAfterOcrTick(text) {
    static attempt := 0
    global g_SelSense_MenuReady, g_SelSense_PendingText
    t := Trim(String(text), " `t`r`n")
    if (t = "")
        return
    attempt += 1
    ; 最多约 3 秒：15 * 200ms
    if (attempt > 15) {
        attempt := 0
        return
    }
    try g_SelSense_PendingText := t
    try {
        if (IsSet(g_SelSense_MenuReady) && g_SelSense_MenuReady && FuncExists("SelectionSense_PushMenuText")) {
            SelectionSense_PushMenuText(t)
            attempt := 0
            return
        }
    } catch {
    }
    SetTimer(this.ScreenshotEditor_ResyncHubPreviewAfterOcrBind(t), -200)
}

    static ScreenshotEditorPushOCRToHubCapsuleTick(*) {
    ; 兼容旧版本：该函数已废弃（截图工具栏 OCR->HubCapsule 改为复用 SelectionSense_OpenHubCapsuleFromToolbar）
    return
}

    static ScreenshotEditorEnsureHubCapsuleOpen(pendingText := "") {
    global g_SelSense_MenuActivateOnShow, g_SelSense_MenuGui, g_SelSense_MenuVisible, g_SelSense_MenuShowingHub
    opened := false
    t := Trim(String(pendingText), " `t`r`n")
    try {
        if FuncExists("SelectionSense_HubCapsuleHostIsOpen") && SelectionSense_HubCapsuleHostIsOpen()
            opened := true
    } catch {
    }

    ; 截图 OCR 入口的期望是：一定要“打开并激活 HubCapsule”
    ; 优先走 SelectionSenseCore 的标准入口（它会 Navigate HubCapsule.html 并处理激活/焦点）
    if (!opened) {
        try {
            g_SelSense_MenuActivateOnShow := true
            if FuncExists("SelectionSense_OpenHubCapsuleFromToolbar") {
                SelectionSense_OpenHubCapsuleFromToolbar(false, t)
                opened := true
            }
        } catch {
        }
    }

    ; 兜底：复用“悬浮工具栏 NewPrompt 按钮”的同源打开路径
    if (!opened) {
        try {
            g_SelSense_MenuActivateOnShow := true
            if FuncExists("FloatingToolbarExecuteButtonAction") {
                FloatingToolbarExecuteButtonAction("NewPrompt", 0)
                opened := true
            }
        } catch {
        }
    }

    if (!opened) {
        try {
            if FuncExists("FloatingToolbar_DeferredToolbarCmd") {
                FloatingToolbar_DeferredToolbarCmd("hub_capsule")
                opened := true
            }
        } catch {
        }
    }

    try {
        ; 强制本次展示抢焦点：截图工具栏入口需要“激活草稿本弹窗”
        g_SelSense_MenuActivateOnShow := true
        if FuncExists("SelectionSense_ShowMenuNearCursor")
            SelectionSense_ShowMenuNearCursor()
    } catch {
    }

    ; 若宿主已存在且可见但未在前台，再兜底激活一次（WebView2 内焦点有时会被其他窗口抢走）
    try {
        if (IsSet(g_SelSense_MenuGui) && g_SelSense_MenuGui && IsSet(g_SelSense_MenuVisible) && g_SelSense_MenuVisible
            && IsSet(g_SelSense_MenuShowingHub) && g_SelSense_MenuShowingHub) {
            WinActivate("ahk_id " . g_SelSense_MenuGui.Hwnd)
        }
    } catch {
    }
    return opened
}

; 复制截图到剪贴板
    static CopyScreenshotToClipboard(closeAfter := true) {
    global ScreenshotClipboard

    try {
        ; 如果位图已修改，需要保存并重新设置到剪贴板
        if (this.ScreenshotEditorBitmap) {
            ; 直接使用Gdip_SetBitmapToClipboard设置到剪贴板
            Gdip_SetBitmapToClipboard(this.ScreenshotEditorBitmap)
            TrayTip("成功", "截图已复制到剪贴板", "Iconi 1")
        } else if (ScreenshotClipboard) {
            ; 如果没有编辑，直接使用原始截图
            A_Clipboard := ScreenshotClipboard
            TrayTip("成功", "截图已复制到剪贴板", "Iconi 1")
        }

        ; 按需关闭预览窗
        if (closeAfter)
            this.CloseScreenshotEditor()
    } catch as e {
        TrayTip("错误", "复制失败: " . e.Message, "Iconx 2")
    }
}

; 粘贴截图为纯文本（OCR识别后粘贴）
    static PasteScreenshotAsText() {

    try {
        ; 先执行OCR识别
        if (!this.ScreenshotEditorBitmap) {
            TrayTip("错误", "没有可用的截图", "Iconx 2")
            return
        }

        ; 保存临时图片用于OCR
        TempPath := A_Temp "\OCR_Temp_" . A_TickCount . ".png"
        result := Gdip_SaveBitmapToFile(this.ScreenshotEditorBitmap, TempPath)
        if (result != 0) {
            TrayTip("错误", "保存临时图片失败", "Iconx 2")
            return
        }

        ; 执行OCR识别
        TrayTip("识别中", "正在识别图片中的文字...", "Iconi 1")
        ocrResult := OCR.FromFile(TempPath, "zh-CN")

        ; 删除临时文件
        try {
            FileDelete(TempPath)
        } catch {
        }

        if (!ocrResult) {
            TrayTip("错误", "OCR识别失败", "Iconx 2")
            return
        }

        ; 获取识别文本
        recognizedText := ""
        try {
            if (ocrResult.HasProp("Text")) {
                recognizedText := ocrResult.Text
            }
        } catch {
        }

        if (recognizedText = "") {
            TrayTip("错误", "未识别到文字", "Iconx 2")
            return
        }

        ; 按 OCR 排版设置处理后复制到剪贴板
        formattedText := this.ScreenshotOCRApplyTextFormatting(recognizedText)
        A_Clipboard := formattedText
        TrayTip("成功", "文字已复制到剪贴板（" . this.ScreenshotOCRLayoutModeLabel(this.ScreenshotOCRTextLayoutMode) . "）", "Iconi 1")

        ; 关闭预览窗
        this.CloseScreenshotEditor()

        ; 等待一下，然后自动粘贴
        Sleep(200)
        Send("^v")
    } catch as e {
        TrayTip("错误", "OCR识别失败: " . e.Message, "Iconx 2")
    }
}

; 保存截图到文件
    static SaveScreenshotToFile(closeAfter := true) {
    global ClipboardDB
    
    try {
        ; 弹出保存对话框
        FilePath := FileSelect("S16", A_Desktop, "保存截图", "图片文件 (*.png; *.jpg; *.bmp)")
        if (!FilePath) {
            return
        }
        
        ; 确定文件格式
        Ext := StrLower(SubStr(FilePath, InStr(FilePath, ".", , -1) + 1))
        if (Ext != "png" && Ext != "jpg" && Ext != "jpeg" && Ext != "bmp") {
            Ext := "png"
            FilePath .= ".png"
        }
        
        ; 保存位图
        if (this.ScreenshotEditorBitmap) {
            ; 获取编码器CLSID
            if (Ext = "png") {
                EncoderCLSID := "{557CF406-1A04-11D3-9A73-0000F81EF32E}"
            } else if (Ext = "jpg" || Ext = "jpeg") {
                EncoderCLSID := "{557CF401-1A04-11D3-9A73-0000F81EF32E}"
            } else {
                EncoderCLSID := "{557CF400-1A04-11D3-9A73-0000F81EF32E}"  ; BMP
            }
            
            ; 保存文件（Gdip_SaveBitmapToFile第三个参数是Quality，不是EncoderCLSID）
            ; 需要根据扩展名使用不同的保存方式
            if (Ext = "png") {
                Gdip_SaveBitmapToFile(this.ScreenshotEditorBitmap, FilePath)
            } else if (Ext = "jpg" || Ext = "jpeg") {
                Gdip_SaveBitmapToFile(this.ScreenshotEditorBitmap, FilePath, 90)  ; Quality = 90
            } else {
                Gdip_SaveBitmapToFile(this.ScreenshotEditorBitmap, FilePath)
            }
            
            ; 保存到缓存目录
            CacheDir := A_ScriptDir "\Cache"
            if (!DirExist(CacheDir)) {
                DirCreate(CacheDir)
            }
            CachePath := CacheDir "\Screenshot_" . A_Now . "." . Ext
            FileCopy(FilePath, CachePath, 1)
            
            ; 保存到数据库
            if (ClipboardDB && ClipboardDB != 0) {
                try {
                    ; 转义路径中的单引号
                    EscapedPath := StrReplace(CachePath, "'", "''")
                    SQL := "INSERT INTO ClipboardHistory (Content, SourceApp, DataType, CharCount, WordCount, Timestamp) VALUES ('" . EscapedPath . "', 'ScreenshotEditor', 'Image', " . StrLen(CachePath) . ", 1, datetime('now', 'localtime'))"
                    ClipboardDB.Exec(SQL)
                } catch as err {
                    ; 忽略数据库错误
                }
            }
            
            TrayTip("成功", "截图已保存: " . FilePath, "Iconi 1")
        } else {
            TrayTip("错误", "没有可保存的图片", "Iconx 2")
        }
        
        ; 按需关闭预览窗
        if (closeAfter)
            this.CloseScreenshotEditor()
    } catch as e {
        TrayTip("错误", "保存失败: " . e.Message, "Iconx 2")
    }
}

    static _SyncHub() {
        global GuiID_ScreenshotEditor, GuiID_ScreenshotToolbar, ScreenshotEditorPreviewPic, ScreenshotColorPickerActive
        GuiID_ScreenshotEditor := ScreenshotEditorPlugin.GuiID_ScreenshotEditor
        GuiID_ScreenshotToolbar := ScreenshotEditorPlugin.GuiID_ScreenshotToolbar
        ScreenshotEditorPreviewPic := ScreenshotEditorPlugin.ScreenshotEditorPreviewPic
        ScreenshotColorPickerActive := ScreenshotEditorPlugin.ScreenshotColorPickerActive
    }

}

; 滚轮缩放（须在类定义之后；#HotIf 不能放在 class 体内）
#HotIf ScreenshotEditorPlugin_IsZoomHotkeyActive()
WheelUp:: {
    ScreenshotEditorPlugin.ScreenshotEditorZoomWithWheel(1)
}
WheelDown:: {
    ScreenshotEditorPlugin.ScreenshotEditorZoomWithWheel(-1)
}
#HotIf

#HotIf ScreenshotEditorPlugin_IsColorPickerHotkeyActive()
~LButton:: {
    ScreenshotEditorPlugin.ScreenshotColorPickerCaptureAtCursor()
}
#HotIf

ScreenshotEditorPlugin_IsZoomHotkeyActive() {
    return ScreenshotEditorPlugin.IsScreenshotEditorZoomHotkeyActive()
}

ScreenshotEditorPlugin_IsColorPickerHotkeyActive() {
    global ScreenshotColorPickerActive
    return IsSet(ScreenshotColorPickerActive) && ScreenshotColorPickerActive
}
