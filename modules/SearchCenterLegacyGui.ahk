#Requires AutoHotkey v2.0
; Legacy SearchCenter GUI (ListView path when not using WebView)

; ===================== 搜索中心导航处理函数 =====================
; 处理搜索中心的上方向导航 (Up / W)
; 处理搜索中心的上方向导航 (Up / W)
; 【功能】完全复刻方向键行为，遵守三个区域的操作规范
; 【区域1：category（分类栏）】↑/W：向上切换分类
; 【区域2：input（输入框）】↑/W：切换到分类栏
; 【区域3：listview（列表区域）】↑/W：如果在第一行 → 切换到输入框；否则 → 向上移动
HandleSearchCenterUp() {
    global SearchCenterActiveArea, SearchCenterResultLV, SearchCenterSearchEdit, GuiID_SearchCenter, CapsLock2
    CapsLock2 := false
    
    if (SearchCenterActiveArea = "category") {
        ; category (分类栏) -> ↑/W：向上切换分类
        SwitchSearchCenterCategory(-1)
    } else if (SearchCenterActiveArea = "input") {
        ; input (输入框) -> ↑/W：切换到分类栏
        SearchCenterActiveArea := "category"
        UpdateSearchCenterHighlight()
    } else if (SearchCenterActiveArea = "listview") {
        ; listview (列表区域) -> ↑/W：如果在第一行 → 切换到输入框；否则 → 向上移动
        if (SearchCenterResultLV != 0) {
            try {
                SelectedRow := SearchCenterResultLV.GetNext()
                if (SelectedRow <= 1) {
                    SearchCenterActiveArea := "input"
                    UpdateSearchCenterHighlight()
                    if (SearchCenterSearchEdit != 0) {
                        try {
                            SearchCenterSearchEdit.Focus()
                        } catch as err {
                            ; 忽略焦点错误
                        }
                    }
                } else {
                    ; 使用 $ 前缀防止循环触发热键，这里可以直接 send
                    Send("{Up}")
                }
            } catch as e {
                SearchCenterActiveArea := "input"
                UpdateSearchCenterHighlight()
            }
        }
    }
}

; 处理搜索中心的下方向导航 (Down / S)
; 【功能】完全复刻方向键行为，遵守三个区域的操作规范
; 【区域1：category（分类栏）】↓/S：切换到输入框
; 【区域2：input（输入框）】↓/S：切换到列表区域
; 【区域3：listview（列表区域）】↓/S：向下移动
HandleSearchCenterDown() {
    global SearchCenterActiveArea, SearchCenterResultLV, SearchCenterSearchEdit, GuiID_SearchCenter, CapsLock2
    CapsLock2 := false
    
    if (SearchCenterActiveArea = "category") {
        ; category (分类栏) -> ↓/S：切换到输入框
        SearchCenterActiveArea := "input"
        UpdateSearchCenterHighlight()
        if (SearchCenterSearchEdit != 0) {
            try {
                SearchCenterSearchEdit.Focus()
            } catch as err {
                ; 忽略焦点错误
            }
        }
    } else if (SearchCenterActiveArea = "input") {
        ; input (输入框) -> ↓/S：切换到列表区域
        SearchCenterActiveArea := "listview"
        UpdateSearchCenterHighlight()
        if (SearchCenterResultLV != 0) {
            try {
                if (GuiID_SearchCenter != 0 && !WinActive("ahk_id " . GuiID_SearchCenter.Hwnd)) {
                    WinActivate("ahk_id " . GuiID_SearchCenter.Hwnd)
                }
                ; 【优化】自动选中第一行，以便用户直接按 F 键"开火"
                if (SearchCenterResultLV.GetCount() > 0) {
                    SearchCenterResultLV.Modify(1, "Select Focus")
                    ; 确保第一行被选中并聚焦
                    Sleep(50)  ; 短暂延迟确保选中生效
                }
                ControlFocus(SearchCenterResultLV)
            } catch as e {
                ; 忽略焦点错误
            }
        }
    } else if (SearchCenterActiveArea = "listview") {
        ; listview (列表区域) -> ↓/S：向下移动
        Send("{Down}")
    }
}

; 处理搜索中心的左方向导航 (Left / A)
; 【功能】完全复刻方向键行为，遵守三个区域的操作规范
; 【区域1：category（分类栏）】←/A：向左切换分类
; 【区域2：input（输入框）】←/A：光标左移
; 【区域3：listview（列表区域）】←/A：向上翻页（PageUp）
HandleSearchCenterLeft() {
    global SearchCenterActiveArea, CapsLock2
    CapsLock2 := false
    if (SearchCenterActiveArea = "category") {
        ; category (分类栏) -> ←/A：向左切换分类
        SwitchSearchCenterCategory(-1)
    } else if (SearchCenterActiveArea = "input") {
        ; input (输入框) -> ←/A：光标左移
        Send("{Left}")
    } else if (SearchCenterActiveArea = "listview") {
        ; listview (列表区域) -> ←/A：向上翻页（PageUp）
        Send("{PgUp}")
    }
}

; 处理搜索中心的右方向导航 (Right / D)
; 【功能】完全复刻方向键行为，遵守三个区域的操作规范
; 【区域1：category（分类栏）】→/D：向右切换分类
; 【区域2：input（输入框）】→/D：光标右移
; 【区域3：listview（列表区域）】→/D：向下翻页（PageDown）
HandleSearchCenterRight() {
    global SearchCenterActiveArea, CapsLock2
    CapsLock2 := false
    if (SearchCenterActiveArea = "category") {
        ; category (分类栏) -> →/D：向右切换分类
        SwitchSearchCenterCategory(1)
    } else if (SearchCenterActiveArea = "input") {
        ; input (输入框) -> →/D：光标右移
        Send("{Right}")
    } else if (SearchCenterActiveArea = "listview") {
        ; listview (列表区域) -> →/D：向下翻页（PageDown）
        Send("{PgDn}")
    }
}

; 处理搜索中心 F 键导航 (F)
HandleSearchCenterF() {
    global SearchCenterActiveArea, SearchCenterResultLV, SearchCenterSearchResults
    global SearchCenterSearchEdit, CursorPath, CapsLock2
    
    ; 标记已处理按键，防止 CapsLock 切换状态
    CapsLock2 := false
    
    if (SearchCenterIsCLICategory() && (SearchCenterActiveArea = "input" || SearchCenterActiveArea = "category")) {
        ExecuteSearchCenterCLICommand()
        return
    }
    
    if (SearchCenterActiveArea = "category" || SearchCenterActiveArea = "input") {
        ; 搜索引擎/输入框区域：执行搜索操作
        ExecuteSearchCenterBatchSearch()
    } else if (SearchCenterActiveArea = "listview") {
        ; ListView 区域：如果已选中数据，立即启动倒计时准备粘贴
        if (!SearchCenterResultLV || SearchCenterResultLV = 0) {
            return
        }
        
        SelectedRow := SearchCenterResultLV.GetNext()
        if (SelectedRow <= 0) {
            ; 如果没有选中项，选中第一项
            if (SearchCenterResultLV.GetCount() > 0) {
                SearchCenterResultLV.Modify(1, "Select Focus")
                SelectedRow := 1
            } else {
                TrayTip("没有可用的搜索结果", "提示", "Icon! 2")
                return
            }
        }
        
        ; 获取选中内容并立即启动倒计时
        if (SelectedRow > 0 && SelectedRow <= SearchCenterSearchResults.Length) {
            Item := GetSearchCenterResultItemByRow(SelectedRow)
            if (!IsObject(Item)) {
                return
            }
            Content := Item.HasProp("Content") ? Item.Content : Item.Title
            
            ; 调用启动处理函数（封装了隐藏窗口和启动倒计时的逻辑）
            SearchCenterListViewLaunchHandler(Content, Item.Title)
        }
    }
}

; 搜索中心内容发射处理程序（封装逻辑，供 Enter 和 F 键共用）
SearchCenterListViewLaunchHandler(Content, Title) {
    global GuiID_SearchCenter, global_ST
    
    ; 1. 彻底销毁搜索中心窗口，确保 CapsLock + F 逻辑完美重置
    try {
        if (GuiID_SearchCenter != 0 && IsObject(GuiID_SearchCenter)) {
            CleanupSearchCenterResultLimitDDLBrush()
            GuiID_SearchCenter.Destroy()
        }
        ; 2. 释放数据库资源，防止占用
        if (IsSet(global_ST) && IsObject(global_ST) && global_ST.HasProp("Free")) {
            try {
                global_ST.Free()
            } catch as err {
            }
            global_ST := 0
        }
    } catch as err {
    }
    GuiID_SearchCenter := 0
    SearchCenterInvalidateGuiControlRefs()
    
    ; 3. 启动倒计时功能
    StartActionCountdown(Content, Title)
}

; ===================== 圆环倒计时模块 =====================
; 启动倒计时
StartActionCountdown(Content, Title := "") {
    global LaunchDelaySeconds, IsCountdownActive, CountdownGui, CountdownTimer
    global CountdownStartTime, CountdownContent, GuiID_SearchCenter
    
    ; 如果倒计时已激活，再次按 F 或 Enter 则加速执行
    if (IsCountdownActive) {
        ExecuteCountdownAction()
        return
    }
    
    ; 保存内容
    CountdownContent := Content
    
    ; 创建倒计时 GUI
    CreateCountdownGui()
    
    ; 启动倒计时
    IsCountdownActive := true
    CountdownStartTime := A_TickCount
    CountdownTimer := SetTimer(UpdateCountdown, 30)  ; 每 30ms 刷新一次
}

; 创建倒计时 GUI
CreateCountdownGui() {
    global CountdownGui, CountdownGraphics, CountdownBitmap
    global LaunchDelaySeconds
    
    ; 如果 GUI 已存在，先销毁
    if (CountdownGui != 0) {
        try {
            CleanupCountdownGui()
        } catch as err {
        }
    }
    
    ; 初始化 GDI+
    InitGDI()
    
    ; 1. 创建透明分层窗口
    ; WS_EX_LAYERED (0x80000) + WS_EX_TRANSPARENT (0x20) + WS_EX_TOPMOST (0x8)
    CountdownGui := Gui("+AlwaysOnTop +Disabled -Caption +E0x80028", "ActionCountdown")
    
    ; 设置窗口大小
    WindowSize := 100
    
    ; 2. 计算位置（在当前鼠标所在的显示器居中）
    ; 获取鼠标位置
    CoordMode("Mouse", "Screen")
    MouseGetPos(&mX, &mY)
    
    ; 获取显示器信息
    TargetMonitor := 1
    MonitorCount := MonitorGetCount()
    loop MonitorCount {
        MonitorGet(A_Index, &mLeft, &mTop, &mRight, &mBottom)
        if (mX >= mLeft && mX <= mRight && mY >= mTop && mY <= mBottom) {
            TargetMonitor := A_Index
            break
        }
    }
    
    MonitorGet(TargetMonitor, &Left, &Top, &Right, &Bottom)
    CountdownX := Left + (Right - Left - WindowSize) / 2
    CountdownY := Top + (Bottom - Top - WindowSize) / 2
    
    ; 3. 显示窗口（指定精确位置和分层属性）
    CountdownGui.Show("x" . CountdownX . " y" . CountdownY . " w" . WindowSize . " h" . WindowSize . " NA")
}

; 更新倒计时显示
UpdateCountdown(*) {
    global LaunchDelaySeconds, IsCountdownActive, CountdownStartTime
    global CountdownGui, CountdownGraphics, CountdownBitmap
    global CountdownContent
    
    if (!IsCountdownActive || CountdownGui = 0) {
        return
    }
    
    ; 计算剩余时间
    Elapsed := (A_TickCount - CountdownStartTime) / 1000.0
    Remaining := LaunchDelaySeconds - Elapsed
    
    ; 如果倒计时结束，执行操作
    if (Remaining <= 0) {
        ExecuteCountdownAction()
        return
    }
    
    ; 绘制圆环
    DrawCountdownRing(Remaining)
}

; 绘制倒计时圆环
DrawCountdownRing(Remaining) {
    global CountdownGui, LaunchDelaySeconds
    
    if (CountdownGui = 0) {
        return
    }
    
    WindowSize := 100
    CenterX := WindowSize / 2
    CenterY := WindowSize / 2
    Radius := 35  ; 稍微增大圆环
    StrokeWidth := 5  ; 减细一些，更精致
    
    ; 创建内存 DC 和位图用于绘制
    hdc := DllCall("GetDC", "Ptr", CountdownGui.Hwnd, "Ptr")
    hdcMem := DllCall("CreateCompatibleDC", "Ptr", hdc, "Ptr")
    hbm := DllCall("CreateCompatibleBitmap", "Ptr", hdc, "Int", WindowSize, "Int", WindowSize, "Ptr")
    hbmOld := DllCall("SelectObject", "Ptr", hdcMem, "Ptr", hbm)
    
    ; 初始化 GDI+ Graphics
    pGraphics := 0
    DllCall("gdiplus.dll\GdipCreateFromHDC", "Ptr", hdcMem, "Ptr*", &pGraphics)
    
    if (!pGraphics) {
        DllCall("SelectObject", "Ptr", hdcMem, "Ptr", hbmOld)
        DllCall("DeleteObject", "Ptr", hbm)
        DllCall("DeleteDC", "Ptr", hdcMem)
        DllCall("ReleaseDC", "Ptr", CountdownGui.Hwnd, "Ptr", hdc)
        return
    }
    
    try {
        ; 设置高质量渲染
        DllCall("gdiplus.dll\GdipSetSmoothingMode", "Ptr", pGraphics, "Int", 2)  ; SmoothingModeAntiAlias
        DllCall("gdiplus.dll\GdipSetTextRenderingHint", "Ptr", pGraphics, "Int", 4)  ; TextRenderingHintAntiAlias
        
        ; 清除背景（完全透明）
        DllCall("gdiplus.dll\GdipGraphicsClear", "Ptr", pGraphics, "UInt", 0x00000000)
        
        ; 计算进度（从 1.0 递减至 0.0）
        Progress := Remaining / LaunchDelaySeconds
        StartAngle := 270.0  ; 从顶部开始
        SweepAngle := 360.0 * Progress
        
        ; 绘制背景圆环（深色底环，作为辅助参照）
        DllCall("gdiplus.dll\GdipCreatePen1", "UInt", 0x20007AFF, "Float", StrokeWidth, "Int", 0, "Ptr*", &pPenBg := 0)
        DllCall("gdiplus.dll\GdipDrawArc", "Ptr", pGraphics, "Ptr", pPenBg, "Float", CenterX - Radius, "Float", CenterY - Radius, "Float", Radius * 2, "Float", Radius * 2, "Float", 0, "Float", 360)
        DllCall("gdiplus.dll\GdipDeletePen", "Ptr", pPenBg)
        
        ; 绘制进度圆弧（鲜艳的蓝色）
        ; 采用 iOS 风格的蓝色 #007AFF
        DllCall("gdiplus.dll\GdipCreatePen1", "UInt", 0xFF007AFF, "Float", StrokeWidth, "Int", 0, "Ptr*", &pPenProgress := 0)
        DllCall("gdiplus.dll\GdipSetPenStartCap", "Ptr", pPenProgress, "Int", 2)  ; LineCapRound
        DllCall("gdiplus.dll\GdipSetPenEndCap", "Ptr", pPenProgress, "Int", 2)  ; LineCapRound
        DllCall("gdiplus.dll\GdipDrawArc", "Ptr", pGraphics, "Ptr", pPenProgress, "Float", CenterX - Radius, "Float", CenterY - Radius, "Float", Radius * 2, "Float", Radius * 2, "Float", StartAngle, "Float", SweepAngle)
        DllCall("gdiplus.dll\GdipDeletePen", "Ptr", pPenProgress)
        
        ; 绘制中心文本 "Esc取消"
        ; 第一行 Esc，第二行 取消，增加识别度
        Text := "Esc`n取消"
        DllCall("gdiplus.dll\GdipCreateFontFamilyFromName", "WStr", "Microsoft YaHei", "Ptr", 0, "Ptr*", &pFontFamily := 0)
        DllCall("gdiplus.dll\GdipCreateFont", "Ptr", pFontFamily, "Float", 11, "Int", 1, "Int", 0, "Ptr*", &pFont := 0) ; Bold
        
        DllCall("gdiplus.dll\GdipCreateStringFormat", "Int", 0, "UShort", 0, "Ptr*", &pStringFormat := 0)
        DllCall("gdiplus.dll\GdipSetStringFormatAlign", "Ptr", pStringFormat, "Int", 1) ; Center
        DllCall("gdiplus.dll\GdipSetStringFormatLineAlign", "Ptr", pStringFormat, "Int", 1) ; Middle
        
        DllCall("gdiplus.dll\GdipCreateSolidFill", "UInt", 0xFFFFFFFF, "Ptr*", &pBrush := 0)
        
        Rect := Buffer(16, 0)
        NumPut("Float", 0, Rect, 0)
        NumPut("Float", 0, Rect, 4)
        NumPut("Float", WindowSize, Rect, 8)
        NumPut("Float", WindowSize, Rect, 12)
        
        DllCall("gdiplus.dll\GdipDrawString", "Ptr", pGraphics, "WStr", Text, "Int", -1, "Ptr", pFont, "Ptr", Rect, "Ptr", pStringFormat, "Ptr", pBrush)
        
        ; 清理 GDI+ 资源
        DllCall("gdiplus.dll\GdipDeleteBrush", "Ptr", pBrush)
        DllCall("gdiplus.dll\GdipDeleteStringFormat", "Ptr", pStringFormat)
        DllCall("gdiplus.dll\GdipDeleteFont", "Ptr", pFont)
        DllCall("gdiplus.dll\GdipDeleteFontFamily", "Ptr", pFontFamily)
        DllCall("gdiplus.dll\GdipDeleteGraphics", "Ptr", pGraphics)
        
        ; 更新分层窗口
        ; 获取窗口位置
        WinGetPos(&WinX, &WinY, , , "ahk_id " . CountdownGui.Hwnd)
        
        ; BLENDFUNCTION 结构体（4字节）
        BlendFunc := Buffer(4, 0)
        NumPut("UChar", 1, BlendFunc, 0)  ; BlendOp: AC_SRC_OVER
        NumPut("UChar", 0, BlendFunc, 1)  ; BlendFlags
        NumPut("UChar", 255, BlendFunc, 2)  ; SourceConstantAlpha (0-255)
        NumPut("UChar", 1, BlendFunc, 3)  ; AlphaFormat: AC_SRC_ALPHA
        
        ; 目标位置（POINT 结构，8字节）
        DstPoint := Buffer(8, 0)
        NumPut("Int", WinX, DstPoint, 0)  ; xDst
        NumPut("Int", WinY, DstPoint, 4)  ; yDst
        
        ; 大小（SIZE 结构，8字节）
        Size := Buffer(8, 0)
        NumPut("Int", WindowSize, Size, 0)  ; cx
        NumPut("Int", WindowSize, Size, 4)  ; cy
        
        ; 源位置（POINT 结构，8字节）
        SrcPoint := Buffer(8, 0)
        NumPut("Int", 0, SrcPoint, 0)  ; xSrc
        NumPut("Int", 0, SrcPoint, 4)  ; ySrc
        
        ; 调用 UpdateLayeredWindow
        ; UpdateLayeredWindow(hwnd, hdcDst, pptDst, psize, hdcSrc, pptSrc, crKey, pblend, dwFlags)
        DllCall("UpdateLayeredWindow", "Ptr", CountdownGui.Hwnd, "Ptr", 0, "Ptr", DstPoint, "Ptr", Size, "Ptr", hdcMem, "Ptr", SrcPoint, "UInt", 0, "Ptr", BlendFunc, "UInt", 2)
    } catch as e {
        OutputDebug("绘制圆环失败: " . e.Message)
        ; 确保清理资源
        DllCall("gdiplus.dll\GdipDeleteGraphics", "Ptr", pGraphics)
    }
    
    ; 清理资源
    DllCall("SelectObject", "Ptr", hdcMem, "Ptr", hbmOld)
    DllCall("DeleteObject", "Ptr", hbm)
    DllCall("DeleteDC", "Ptr", hdcMem)
    DllCall("ReleaseDC", "Ptr", CountdownGui.Hwnd, "Ptr", hdc)
}

; 执行倒计时操作
ExecuteCountdownAction() {
    global IsCountdownActive, CountdownContent, CountdownTimer
    global global_ST
    
    ; 停止倒计时
    if (CountdownTimer != 0) {
        try {
            CountdownTimer.Delete()
        } catch as err {
        }
        CountdownTimer := 0
    }
    IsCountdownActive := false
    
    ; 清理 GUI
    CleanupCountdownGui()
    
    ; 执行粘贴操作
    try {
        ; 复制到剪贴板
        A_Clipboard := CountdownContent
        Sleep(150)  ; 等待剪贴板写入完成
        
        ; 查找并激活 Cursor 窗口
        if (WinExist("ahk_exe Cursor.exe")) {
            WinActivate("ahk_exe Cursor.exe")
            WinWaitActive("ahk_exe Cursor.exe", , 1)
            Sleep(150)  ; 【健壮性要求】防止粘贴指令发送过快
        } else {
            global CursorPath
            if (IsSet(CursorPath) && CursorPath != "" && FileExist(CursorPath)) {
                Run(CursorPath)
                WinWaitActive("ahk_exe Cursor.exe", , 5)
                Sleep(150)
            }
        }
        
        ; 发送粘贴命令
        Send("^v")
        TrayTip("已粘贴到 Cursor", "", "Iconi 1")
    } catch as e {
        TrayTip("粘贴失败: " . e.Message, "错误", "Iconx 2")
    }
    
    ; 清空内容
    CountdownContent := ""
}

; 取消倒计时
CancelCountdown() {
    global IsCountdownActive, CountdownTimer, CountdownContent
    
    ; 停止倒计时
    if (CountdownTimer != 0) {
        try {
            CountdownTimer.Delete()
        } catch as err {
        }
        CountdownTimer := 0
    }
    IsCountdownActive := false
    
    ; 清理 GUI
    CleanupCountdownGui()
    
    ; 清空内容
    CountdownContent := ""
    
    ; 显示提示
    ToolTip("已取消")
    SetTimer(() => ToolTip(), -2000)  ; 2秒后清除提示
}

; 清理倒计时 GUI
CleanupCountdownGui() {
    global CountdownGui, CountdownGraphics, CountdownBitmap
    
    ; 销毁 GUI
    if (CountdownGui != 0) {
        try {
            CountdownGui.Destroy()
        } catch as err {
        }
        CountdownGui := 0
    }
    
    ; 清理变量
    CountdownGraphics := 0
    CountdownBitmap := 0
}

; 初始化 GDI+
; 初始化 GDI+
InitGDI() {
    static GdiplusToken := 0
    if (GdiplusToken = 0) {
        ; 确保 gdiplus.dll 已加载
        if (!DllCall("GetModuleHandle", "Str", "gdiplus", "Ptr")) {
            DllCall("LoadLibrary", "Str", "gdiplus")
        }
        
        ; GdiplusStartupInput 结构体
        ; 32位: 4字节 (UInt GdiplusVersion) + 4字节 (Void* DebugEventCallback) + 4字节 (Bool SuppressBackgroundThread) + 4字节 (Bool SuppressExternalCodecs) = 16字节
        ; 64位: 4字节 (UInt GdiplusVersion) + 8字节 (Void* DebugEventCallback) + 4字节 (Bool SuppressBackgroundThread) + 4字节 (Bool SuppressExternalCodecs) = 20字节（对齐到24字节）
        Input := Buffer(A_PtrSize = 8 ? 24 : 16, 0)
        NumPut("UInt", 1, Input, 0)  ; GdiplusVersion = 1
        ; 其他字段默认为 0
        
        ; 调用 GdipStartup（与代码库中其他 GDI+ 函数保持一致，使用 Gdip* 前缀）
        ; GdipStartup(token, input, output)
        ; token: ULONG_PTR* (输出参数)
        ; input: GdiplusStartupInput* (输入结构)
        ; output: GdiplusStartupOutput* (输出结构，可以为 NULL)
        ; 返回值：Status (UInt)，0 表示成功
        ; 注意：参考第9474行的调用方式，使用 "gdiplus.dll\GdipStartup"
        try {
            Status := DllCall("gdiplus.dll\GdipStartup", "Ptr*", &GdiplusToken := 0, "Ptr", Input, "Ptr", 0, "Int")
            if (Status != 0) {
                OutputDebug("GDI+ 初始化失败，状态码: " . Status)
                GdiplusToken := 0
            }
        } catch as e {
            OutputDebug("GDI+ 初始化失败: " . e.Message)
            GdiplusToken := 0
        }
    }
}

; ===================== 搜索中心窗口 =====================
; 显示搜索中心窗口（无边框，带分类标签栏）
ShowSearchCenter() {
    if (SearchCenter_ShouldUseWebView()) {
        SCWV_Show()
        return
    }
    global GuiID_SearchCenter, UI_Colors, ThemeMode
    global SearchCenterActiveArea, SearchCenterCurrentCategory
    global SearchCenterSearchEdit, SearchCenterResultLV, SearchCenterCategoryButtons
    global VoiceSearchEnabledCategories, SearchCenterAreaIndicator
    global SearchCenterFilterButtons, SearchCenterFilterType, SearchCenterFilterButtonMap
    global SearchCenterCLIOutputEdit
    global SearchCenterCLIRunButton, SearchCenterCLIClearButton, SearchCenterCLIOpenButton
    global SearchCenterResultLimitDDL_Hwnd, SearchCenterResultLimitDDL_ListHwnd
    
    ; 如果窗口已存在，先销毁
    if (GuiID_SearchCenter != 0) {
        try {
            CleanupSearchCenterResultLimitDDLBrush()
            GuiID_SearchCenter.Destroy()
        } catch as err {
        }
        GuiID_SearchCenter := 0
        SearchCenterInvalidateGuiControlRefs()
    }
    
    ; 初始化状态
    SearchCenterActiveArea := "input"  ; 默认焦点在输入框
    SearchCenterCurrentCategory := 0
    SearchCenterCategoryButtons := []
    ; 初始化搜索引擎图标数组
    if (!IsSet(SearchCenterEngineIcons) || !IsObject(SearchCenterEngineIcons)) {
        SearchCenterEngineIcons := []
    }
    
    ; 初始化搜索引擎选择状态
    if (!IsSet(SearchCenterSelectedEngines) || !IsObject(SearchCenterSelectedEngines)) {
        SearchCenterSelectedEngines := []
    }
    if (!IsSet(SearchCenterSelectedEnginesByCategory) || !IsObject(SearchCenterSelectedEnginesByCategory)) {
        SearchCenterSelectedEnginesByCategory := Map()
        ; 【关键修复】参考CAPSLOCK+F的实现：从配置文件加载所有分类的选择状态
        try {
            global ConfigFile
            AllCategories := GetSearchCenterCategories()
            for Index, Category in AllCategories {
                CategoryKey := Category.Key
                CategoryEnginesStr := IniRead(ConfigFile, "Settings", "SearchCenterSelectedEngines_" . CategoryKey, "")
                if (CategoryEnginesStr != "") {
                    ; 解析格式：分类:引擎1,引擎2
                    if (InStr(CategoryEnginesStr, ":") > 0) {
                        EnginesStr := SubStr(CategoryEnginesStr, InStr(CategoryEnginesStr, ":") + 1)
                    } else {
                        EnginesStr := CategoryEnginesStr
                    }
                    if (EnginesStr != "") {
                        EnginesArray := StrSplit(EnginesStr, ",")
                        CurrentEngines := []
                        for Index2, Engine in EnginesArray {
                            Engine := Trim(Engine)
                            if (Engine != "") {
                                CurrentEngines.Push(Engine)
                            }
                        }
                        if (CurrentEngines.Length > 0) {
                            SearchCenterSelectedEnginesByCategory[CategoryKey] := CurrentEngines
                        }
                    }
                }
            }
        } catch as err {
            ; 忽略加载错误
        }
    }
    
    ; 窗口尺寸（增加高度以容纳过滤标签按钮）
    WindowWidth := 900
    WindowHeight := 650  ; 从600增加到650，为过滤标签按钮留出空间
    Padding := 20
    
    ; 创建窗口（使用原生标题栏）
    GuiID_SearchCenter := Gui("+AlwaysOnTop -DPIScale +Resize", "搜索中心")
    GuiID_SearchCenter.BackColor := UI_Colors.Background
    GuiID_SearchCenter.SetFont("s11 c" . UI_Colors.Text, "Segoe UI")
    
    ; ========== 顶部分类标签栏（CategoryBar）==========
    CategoryBarHeight := 50
    CategoryBarY := Padding  ; 使用原生标题栏，从Padding开始
    
    ; 获取分类列表（从语音搜索面板提取）
    AllCategories := GetSearchCenterCategories()
    
    if (AllCategories.Length = 0) {
        ; 如果没有分类，使用默认分类
        AllCategories := [{Key: "ai", Text: GetText("search_category_ai")}]
    }
    
    ; 创建分类标签按钮（横向排列）
    CategoryButtonHeight := 35
    CategoryButtonSpacing := 10
    CategoryStartX := Padding
    CategoryButtonY := CategoryBarY + (CategoryBarHeight - CategoryButtonHeight) / 2
    CurrentCategoryX := CategoryStartX  ; 当前X坐标
    
    for Index, Category in AllCategories {
        ; 计算按钮宽度（根据文本长度动态调整）
        CategoryText := Category.Text
        
        ; 【关键修复】显示已选中的搜索引擎数量
        CategoryKey := Category.Key
        SelectedCount := 0
        if (IsSet(SearchCenterSelectedEnginesByCategory) && IsObject(SearchCenterSelectedEnginesByCategory) && SearchCenterSelectedEnginesByCategory.Has(CategoryKey)) {
            SelectedCount := SearchCenterSelectedEnginesByCategory[CategoryKey].Length
        } else {
            ; 尝试从配置文件加载
            try {
                global ConfigFile
                CategoryEnginesStr := IniRead(ConfigFile, "Settings", "SearchCenterSelectedEngines_" . CategoryKey, "")
                if (CategoryEnginesStr != "") {
                    if (InStr(CategoryEnginesStr, ":") > 0) {
                        EnginesStr := SubStr(CategoryEnginesStr, InStr(CategoryEnginesStr, ":") + 1)
                    } else {
                        EnginesStr := CategoryEnginesStr
                    }
                    if (EnginesStr != "") {
                        EnginesArray := StrSplit(EnginesStr, ",")
                        SelectedCount := EnginesArray.Length
                    }
                }
            } catch as err {
            }
        }
        
        ; 如果有选中的搜索引擎，在标签文本后显示数量
        if (SelectedCount > 0) {
            CategoryText .= " (" . SelectedCount . ")"
        }
        
        TextWidth := StrLen(CategoryText) * 10 + 20  ; 估算宽度
        CategoryButtonWidth := Max(60, TextWidth)  ; 最小宽度60
        
        ; 根据是否选中设置背景色
        IsSelected := (Index - 1 = SearchCenterCurrentCategory)
        BgColor := IsSelected ? UI_Colors.BtnPrimary : UI_Colors.Sidebar
        TextColor := IsSelected ? "FFFFFF" : UI_Colors.Text
        
        CategoryBtn := GuiID_SearchCenter.Add("Text", "x" . CurrentCategoryX . " y" . CategoryButtonY . " w" . CategoryButtonWidth . " h" . CategoryButtonHeight . " Center 0x200 c" . TextColor . " Background" . BgColor . " vSearchCategoryBtn" . Index, CategoryText)
        CategoryBtn.SetFont("s10 Bold", "Segoe UI")
        CategoryBtn.OnEvent("Click", CreateSearchCategoryClickHandler(Index - 1))
        HoverBtnWithAnimation(CategoryBtn, BgColor, UI_Colors.BtnHover)
        SearchCenterCategoryButtons.Push(CategoryBtn)
        
        ; 更新下一个按钮的X坐标
        CurrentCategoryX += CategoryButtonWidth + CategoryButtonSpacing
    }
    
    ; ========== 搜索引擎图标行 ==========
    EngineIconRowY := CategoryBarY + CategoryBarHeight + 5
    EngineIconRowHeight := 70  ; 图标行高度（50图标 + 2间距 + 16名称 = 68，留2像素余量）
    
    ; ========== 中部输入区（放在图标行下方）==========
    InputAreaY := EngineIconRowY + EngineIconRowHeight + Padding
    InputAreaHeight := 70
    
    ; 根据主题模式设置输入框颜色（Material Design风格，完全移除边框和底边）
    if (ThemeMode = "dark") {
        InputBgColor := UI_Colors.InputBg  ; html.to.design 风格背景
        InputTextColor := UI_Colors.Text   ; html.to.design 风格文本
    } else {
        InputBgColor := UI_Colors.InputBg
        InputTextColor := UI_Colors.Text
    }
    
    ; ========== 结果数量限制下拉菜单（搜索框左侧）==========
    DropdownX := Padding
    DropdownY := InputAreaY + (InputAreaHeight - 50) / 2
    DropdownWidth := 120
    DropdownHeight := 50
    
    ; 创建来源过滤下拉菜单
    ; R7 表示显示 7 行，确保所有选项可见
    DropdownOptions := ["10", "20", "50", "100", "200"]
    DropdownDefaultIndex := GetSearchCenterLimitDropdownIndex(SearchCenterCurrentLimit)

    SearchCenterResultLimitDropdown := GuiID_SearchCenter.Add("DropDownList",
        "x" . DropdownX . " y" . DropdownY .
        " w" . DropdownWidth . " h" . DropdownHeight .
        " R6" .
        " BackgroundFFFFFF" .
        " c000000" .
        " Choose" . DropdownDefaultIndex .
        " vSearchCenterResultLimitDropdown",
        DropdownOptions)
    SearchCenterResultLimitDropdown.SetFont("s14", "Segoe UI")
    SearchCenterResultLimitDropdown.OnEvent("Change", OnSearchCenterResultLimitChange)
    try {
        SearchCenterResultLimitDDL_Hwnd := SearchCenterResultLimitDropdown.Hwnd
        ComboBoxInfoSize := (A_PtrSize = 8) ? 64 : 52
        ComboBoxInfo := Buffer(ComboBoxInfoSize, 0)
        NumPut("UInt", ComboBoxInfoSize, ComboBoxInfo, 0)
        if (DllCall("user32.dll\GetComboBoxInfo", "Ptr", SearchCenterResultLimitDDL_Hwnd, "Ptr", ComboBoxInfo, "Int")) {
            ListHwndOffset := 40 + A_PtrSize * 2
            SearchCenterResultLimitDDL_ListHwnd := NumGet(ComboBoxInfo, ListHwndOffset, "Ptr")
        }
        SetTimer(UpdateSearchCenterResultLimitDDLBrush, -100)
    } catch as err {
    }
    
    ; ========== 搜索输入框（下拉菜单右侧）==========
    SearchEditX := DropdownX + DropdownWidth + 10  ; 下拉菜单右侧，间距10
    SearchEditY := DropdownY
    SearchEditWidth := WindowWidth - Padding * 2 - DropdownWidth - 10  ; 总宽度减去下拉菜单宽度和间距
    SearchEditHeight := 50
    
    ; 【Material Design风格】完全移除边框容器，避免任何底边显示
    ; 使用 -Border 选项移除默认边框，避免黑边问题
    ; 使用 -VScroll -HScroll 禁用滚动条，-Border 移除默认边框
    ; 【关键修复】Edit 控件默认是单行的，不支持换行，回车键已在顶部热键中处理为触发搜索
    SearchCenterSearchEdit := GuiID_SearchCenter.Add("Edit", "x" . SearchEditX . " y" . SearchEditY . " w" . SearchEditWidth . " h" . SearchEditHeight . " Background" . InputBgColor . " c" . InputTextColor . " -VScroll -HScroll -Border vSearchCenterEdit", "")
    SearchCenterSearchEdit.SetFont("s16", "Segoe UI")
    
    ; 初始化 Everything 搜索限制值
    SearchCenterEverythingLimit := SearchCenterCurrentLimit
    
    ; 完全移除边框容器，不再使用
    SearchCenterInputContainer := 0
    
    ; 【Material Design风格】完全移除Edit控件的边框（包括底部黑边）
    ; 通过移除WS_EX_CLIENTEDGE和WS_BORDER样式来完全消除边框效果
    try {
        EditHwnd := SearchCenterSearchEdit.Hwnd
        if (EditHwnd) {
            ; GWL_EXSTYLE = -20, WS_EX_CLIENTEDGE = 0x00000200
            ; 获取当前扩展样式
            CurrentExStyle := DllCall("GetWindowLongPtr", "Ptr", EditHwnd, "Int", -20, "Ptr")
            ; 移除WS_EX_CLIENTEDGE（3D边框效果），保留其他样式
            NewExStyle := CurrentExStyle & ~0x00000200
            ; 应用新扩展样式
            DllCall("SetWindowLongPtr", "Ptr", EditHwnd, "Int", -20, "Ptr", NewExStyle, "Ptr")
            
            ; GWL_STYLE = -16, WS_BORDER = 0x00800000
            ; 获取当前窗口样式
            CurrentStyle := DllCall("GetWindowLongPtr", "Ptr", EditHwnd, "Int", -16, "Ptr")
            ; 移除WS_BORDER（边框样式），保留其他样式
            NewStyle := CurrentStyle & ~0x00800000
            ; 应用新窗口样式
            DllCall("SetWindowLongPtr", "Ptr", EditHwnd, "Int", -16, "Ptr", NewStyle, "Ptr")
            
            ; 强制重绘窗口以应用样式更改
            DllCall("InvalidateRect", "Ptr", EditHwnd, "Ptr", 0, "Int", 1)
            DllCall("UpdateWindow", "Ptr", EditHwnd)
            ; 延迟再次刷新，确保样式完全应用（使用命名函数避免箭头函数语法问题）
            SetTimer(RefreshSearchCenterEditBorder.Bind(EditHwnd), -100)
        }
    } catch as err {
        ; 如果API调用失败，至少确保基本功能正常
    }
    SearchCenterSearchEdit.OnEvent("Change", ExecuteSearchCenterSearch)
    ; 【关键修复】添加Focus事件处理：设置焦点区域为input，并切换到中文输入法
    SearchCenterSearchEdit.OnEvent("Focus", (*) => (
        SearchCenterActiveArea := "input",
        UpdateSearchCenterHighlight(),
        SwitchToChineseIMEForSearchCenter()
    ))
    ; 注意：AutoHotkey v2 的 Edit 控件不支持 "Enter" 事件，改用窗口级别的快捷键绑定
    ; ESC键关闭窗口（使用统一的关闭处理函数）
    GuiID_SearchCenter.OnEvent("Escape", SearchCenterCloseHandler)
    
    ; ========== 区域名称动画展示（输入框下方）==========
    AreaIndicatorY := SearchEditY + SearchEditHeight + 8
    AreaIndicatorHeight := 25
    ; 创建区域名称动画展示控件（显示当前区域名称：分类搜索/输入框/本地搜索）
    SearchCenterAreaIndicator := GuiID_SearchCenter.Add("Text", "x" . Padding . " y" . AreaIndicatorY . " w" . SearchEditWidth . " h" . AreaIndicatorHeight . " c" . UI_Colors.BtnPrimary . " BackgroundTrans vSearchCenterAreaIndicator", "")
    SearchCenterAreaIndicator.SetFont("s11 Bold", "Segoe UI")
    SearchCenterAreaIndicator.Visible := true
    
    ; ========== 操作提示文本（区域名称下方）==========
    HintTextY := AreaIndicatorY + AreaIndicatorHeight + 5
    HintTextHeight := 40
    ; 创建操作提示文本控件（显示详细的操作提示）
    SearchCenterHintText := GuiID_SearchCenter.Add("Text", "x" . Padding . " y" . HintTextY . " w" . SearchEditWidth . " h" . HintTextHeight . " c" . UI_Colors.TextDim . " BackgroundTrans vSearchCenterHintText", "")
    SearchCenterHintText.SetFont("s9", "Segoe UI")
    SearchCenterHintText.Visible := true
    
    ; ========== 过滤标签按钮区域（橙色标签）==========
    FilterBarHeight := 40
    PreviewHeight := 120
    PreviewGap := 12
    ButtonHeight := 34
    ButtonReservedHeight := SearchCenterIsCLICategory() ? (ButtonHeight + PreviewGap) : 0
    ; 过滤标签栏固定放在搜索结果框上方，而不是绝对贴底
    FilterBarY := HintTextY + HintTextHeight + 10
    FilterButtonHeight := 30
    FilterButtonSpacing := 8
    FilterStartX := Padding
    FilterButtonY := FilterBarY + (FilterBarHeight - FilterButtonHeight) / 2
    
    ; 初始化过滤标签按钮数组
    SearchCenterFilterButtons := []
    SearchCenterFilterButtonMap := Map()
    SearchCenterFilterType := ""  ; 默认显示全部
    
    ; 过滤标签配置：全部、文件、剪贴板、提示词、配置、快捷键、功能
    FilterConfigs := [
        Map("Type", "", "Text", "全部"),
        Map("Type", "File", "Text", "文件"),
        Map("Type", "clipboard", "Text", "剪贴板"),
        Map("Type", "template", "Text", "提示词"),
        Map("Type", "config", "Text", "配置"),
        Map("Type", "hotkey", "Text", "快捷键"),
        Map("Type", "function", "Text", "功能")
    ]
    
    CurrentFilterX := FilterStartX
    for Index, FilterConfig in FilterConfigs {
        FilterType := FilterConfig["Type"]
        FilterText := FilterConfig["Text"]
        
        ; 计算按钮宽度（根据文本长度动态调整）
        TextWidth := StrLen(FilterText) * 10 + 20  ; 估算宽度
        FilterButtonWidth := Max(50, TextWidth)  ; 最小宽度50
        
            ; 参考记录面板：统一标签激活与未激活配色
            IsSelected := (SearchCenterFilterType = FilterType)
            TagBg := UI_Colors.Sidebar
            TagBgActive := "e67e22"
            TagText := UI_Colors.TextDim
            TagTextActive := "ffffff"
            BgColor := IsSelected ? TagBgActive : TagBg
            TextColor := IsSelected ? TagTextActive : TagText

            ; 【关键修复】在按钮对象上存储 FilterType，方便后续获取
            FilterBtn := GuiID_SearchCenter.Add("Text", "x" . CurrentFilterX . " y" . FilterButtonY . " w" . FilterButtonWidth . " h" . FilterButtonHeight . " Center 0x200 +0x100 c" . TextColor . " Background" . BgColor . " vSearchCenterFilterBtn" . Index, FilterText)
            FilterBtn.SetFont("s10 Bold", "Segoe UI")
            FilterBtn.OnEvent("Click", CreateSearchCenterFilterClickHandler(FilterType))
            FilterBtn.Visible := true
            ; 【关键修复】在按钮上存储 FilterType 属性，方便后续获取
            FilterBtn.FilterType := FilterType
            HoverBtnWithAnimation(FilterBtn, BgColor, TagBgActive)
        SearchCenterFilterButtons.Push(FilterBtn)
        SearchCenterFilterButtonMap[FilterType] := FilterBtn
        
        ; 更新下一个按钮的X坐标
        CurrentFilterX += FilterButtonWidth + FilterButtonSpacing
    }
    
    ; ========== 底部结果区 ==========
    ResultAreaY := FilterBarY + FilterBarHeight + 8
    ResultAreaHeight := Max(120, WindowHeight - Padding - PreviewHeight - ButtonReservedHeight - PreviewGap - ResultAreaY)
    
    ; 结果 ListView
    ResultLVX := Padding
    ResultLVY := ResultAreaY
    ResultLVWidth := WindowWidth - Padding * 2
    ResultLVHeight := ResultAreaHeight
    
    SearchCenterResultLV := GuiID_SearchCenter.Add("ListView", "x" . ResultLVX . " y" . ResultLVY . " w" . ResultLVWidth . " h" . ResultLVHeight . " Background" . UI_Colors.InputBg . " c" . UI_Colors.Text . " -Multi +ReadOnly vSearchResultLV", ["", "标题", "路径", "类型", "时间"])
    SearchCenterResultLV.SetFont("s10", "Segoe UI")
    SearchCenterResultLV.OnEvent("DoubleClick", OnSearchCenterResultDoubleClick)
    SearchCenterResultLV.OnEvent("ItemSelect", OnSearchCenterResultItemSelect)
    ; 【关键修复】添加Focus事件处理：设置焦点区域为listview
    SearchCenterResultLV.OnEvent("Focus", (*) => (
        SearchCenterActiveArea := "listview",
        UpdateSearchCenterHighlight()
    ))
    
    ; 5 列：图标列固定宽度，其余按剩余宽度比例
    SearchCenterResultLV.ModifyCol(1, 36)
    restW := ResultLVWidth - 36
    SearchCenterResultLV.ModifyCol(2, restW * 0.4)
    SearchCenterResultLV.ModifyCol(3, restW * 0.2)
    SearchCenterResultLV.ModifyCol(4, restW * 0.15)
    SearchCenterResultLV.ModifyCol(5, restW * 0.25)
    
    ; ========== CLI 页面控件（仅在 cli 分类显示）==========
    SearchCenterCLIRunButton := GuiID_SearchCenter.Add("Button", "x0 y0 w100 h32", "发送到 AI")
    SearchCenterCLIRunButton.OnEvent("Click", ExecuteSearchCenterCLICommand)
    
    SearchCenterCLIClearButton := GuiID_SearchCenter.Add("Button", "x0 y0 w100 h32", "清空输入")
    SearchCenterCLIClearButton.OnEvent("Click", ClearSearchCenterCLIOutput)
    
    SearchCenterCLIOpenButton := GuiID_SearchCenter.Add("Button", "x0 y0 w140 h32", "打开所选终端")
    SearchCenterCLIOpenButton.OnEvent("Click", OpenSelectedCLIAgents)
    
    SearchCenterCLIOutputEdit := GuiID_SearchCenter.Add("Edit", "x0 y0 w100 h120 Background" . UI_Colors.InputBg . " c" . UI_Colors.Text . " +Multi -Wrap ReadOnly")
    SearchCenterCLIOutputEdit.SetFont("s12", "Segoe UI")
    SearchCenterCLIOutputEdit.OnEvent("Focus", (*) => (
        SearchCenterActiveArea := "listview",
        UpdateSearchCenterHighlight()
    ))
    
    UpdateSearchCenterCLILayout(WindowWidth, WindowHeight)
    
    
    ; 窗口关闭事件（ESC键关闭）
    GuiID_SearchCenter.OnEvent("Close", SearchCenterCloseHandler)
    
    ; 窗口大小改变事件（更新按钮位置）
    GuiID_SearchCenter.OnEvent("Size", OnSearchCenterSize)
    
    ; 显示窗口（居中显示）
    GuiID_SearchCenter.Show("w" . WindowWidth . " h" . WindowHeight . " Center")
    BringSearchCenterFilterButtonsToFront()
    
    ; 【关键修复】激活窗口并聚焦到输入框（参考CAPSLOCK+F的实现）
    WinActivate("ahk_id " . GuiID_SearchCenter.Hwnd)
    Sleep(100)
    try {
        if (SearchCenterIsCLICategory()) {
            FocusSearchCenterCLIInput()
        } else {
            SearchCenterSearchEdit.Focus()
            Sleep(100)
            ; 切换到中文输入法
            SwitchToChineseIMEForSearchCenter()
        }
    } catch as err {
        ; 忽略错误
    }
    try CapsLock_ScheduleNormalizeAfterChord()
    try SearchCenter_ScheduleIMEStabilize()
    
    ; 注意：Enter和ESC键热键已在文件顶部使用#HotIf IsSearchCenterActive()定义，无需在此注册
    
    ; 更新高亮显示
    UpdateSearchCenterCategoryMode()
    UpdateSearchCenterHighlight()
    
    ; 刷新搜索引擎图标显示
    RefreshSearchCenterEngineIcons()
    
    ; 【关键修复】确保标签按钮的初始状态正确显示（默认"全部"标签应为橙色）
    UpdateSearchCenterFilterButtons()
}

; 获取搜索中心分类列表（从语音搜索面板提取）
GetSearchCenterCategories() {
    global VoiceSearchEnabledCategories
    
    ; 所有可用的分类
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
    
    ; 确保 VoiceSearchEnabledCategories 已初始化
    if (!IsSet(VoiceSearchEnabledCategories) || !IsObject(VoiceSearchEnabledCategories)) {
        VoiceSearchEnabledCategories := ["ai", "cli", "academic", "baidu", "image", "audio", "video", "book", "price", "medical", "cloud"]
    }
    
    ; 过滤出启用的分类
    EnabledCategories := []
    for Index, Category in AllCategories {
        if (ArrayContainsValue(VoiceSearchEnabledCategories, Category.Key) > 0) {
            EnabledCategories.Push(Category)
        }
    }
    
    ; 如果没有启用的分类，返回默认分类
    if (EnabledCategories.Length = 0) {
        EnabledCategories.Push({Key: "ai", Text: GetText("search_category_ai")})
    }
    
    return EnabledCategories
}

GetSearchCenterCurrentCategoryKey() {
    global SearchCenterCurrentCategory
    Categories := GetSearchCenterCategories()
    if (Categories.Length = 0 || SearchCenterCurrentCategory < 0 || SearchCenterCurrentCategory >= Categories.Length) {
        return "ai"
    }
    return Categories[SearchCenterCurrentCategory + 1].Key
}

SearchCenterIsCLICategory() {
    return (GetSearchCenterCurrentCategoryKey() = "cli")
}

SetSearchCenterControlVisible(Ctrl, IsVisible) {
    if (!Ctrl || Ctrl = 0) {
        return
    }
    try {
        Ctrl.Visible := IsVisible
    } catch {
    }
}

SetSearchCenterEngineIconsVisible(IsVisible) {
    global SearchCenterEngineIcons
    if (!IsSet(SearchCenterEngineIcons) || !IsObject(SearchCenterEngineIcons)) {
        return
    }
    for _, IconObj in SearchCenterEngineIcons {
        if (!IsObject(IconObj)) {
            continue
        }
        try {
            if (IconObj.HasProp("Bg") && IconObj.Bg != 0) {
                IconObj.Bg.Visible := IsVisible
            }
            if (IconObj.HasProp("Icon") && IconObj.Icon != 0) {
                IconObj.Icon.Visible := IsVisible
            }
            if (IconObj.HasProp("NameLabel") && IconObj.NameLabel != 0) {
                IconObj.NameLabel.Visible := IsVisible
            }
            if (IconObj.HasProp("Check") && IconObj.Check != 0) {
                IconObj.Check.Visible := IsVisible
            }
        } catch {
        }
    }
}

GetSearchCenterCLIPrompt() {
    return ""
}

GetSearchCenterCLIWelcomeText() {
    return ""
}

EnsureSearchCenterCLISession() {
    global SearchCenterCLIOutputEdit
    if (!SearchCenterCLIOutputEdit || SearchCenterCLIOutputEdit = 0) {
        return
    }
    try {
        ; CLI 页使用普通多行输入框，无需初始化终端欢迎文本
    } catch {
    }
}

FocusSearchCenterCLIInput() {
    global SearchCenterSearchEdit
    if (!SearchCenterSearchEdit || SearchCenterSearchEdit = 0) {
        return
    }
    try {
        SearchCenterSearchEdit.Focus()
        ControlSend("{End}", , SearchCenterSearchEdit)
    } catch {
    }
}

GetSearchCenterCurrentCLICommand() {
    global SearchCenterSearchEdit
    if (!SearchCenterSearchEdit || SearchCenterSearchEdit = 0) {
        return ""
    }
    return Trim(SearchCenterSearchEdit.Value, " `t`r`n")
}

UpdateSearchCenterCLILayout(WindowWidth := 0, WindowHeight := 0, KeepFilterTop := true) {
    global GuiID_SearchCenter, SearchCenterCLIOutputEdit, SearchCenterResultLV, SearchCenterFilterButtons
    global SearchCenterCLIRunButton, SearchCenterCLIClearButton, SearchCenterCLIOpenButton
    global SearchCenterHintText
    
    if (!GuiID_SearchCenter || GuiID_SearchCenter = 0) {
        return
    }
    if (WindowWidth <= 0 || WindowHeight <= 0) {
        try {
            GuiID_SearchCenter.GetClientPos(, , &WindowWidth, &WindowHeight)
        } catch {
            WindowWidth := 900
            WindowHeight := 650
        }
    }
    
    Padding := 20
    ContentTop := 325
    if (SearchCenterHintText != 0) {
        try {
            ControlGetPos(&HintX, &HintY, &HintW, &HintH, SearchCenterHintText)
            ContentTop := HintY + HintH + 12
        } catch {
            ContentTop := 325
        }
    }
    IsCLI := SearchCenterIsCLICategory()
    ContentWidth := WindowWidth - Padding * 2
    ButtonWidth := 120
    ButtonHeight := 34
    ButtonGap := 12
    FilterBarHeight := 40
    OutputHeight := 120
    PreviewGap := 12
    if (IsCLI) {
        ButtonY := WindowHeight - Padding - ButtonHeight
        OutputY := ButtonY - OutputHeight - PreviewGap
    } else {
        ButtonY := WindowHeight - Padding - ButtonHeight
        OutputY := WindowHeight - Padding - OutputHeight
    }
    ; 过滤标签栏始终在列表上方，必须预留 FilterBarHeight；否则 ListView 上移会遮挡「全部/文件/…」标签（且 ListView 后创建会盖住 z-order）
    FilterBarY := ContentTop
    ResultY := FilterBarY + FilterBarHeight + 8
    AvailableSpace := OutputY - ResultY - PreviewGap
    if (AvailableSpace < 0) {
        AvailableSpace := 0
    }
    ; 不可用 Max(120, 可用高度)：当可用不足 120 时强行 120 会侵入预览区
    ResultHeight := AvailableSpace
    
    try SearchCenterCLIOutputEdit.Move(Padding, OutputY, ContentWidth, OutputHeight)
    try SearchCenterResultLV.Move(Padding, ResultY, ContentWidth, ResultHeight)
    MoveSearchCenterFilterButtons(FilterBarY, Padding, KeepFilterTop)
    BringSearchCenterFilterButtonsToFront()
    if (IsCLI) {
        try SearchCenterCLIRunButton.Move(Padding, ButtonY, ButtonWidth, ButtonHeight)
        try SearchCenterCLIClearButton.Move(Padding + ButtonWidth + ButtonGap, ButtonY, ButtonWidth, ButtonHeight)
        try SearchCenterCLIOpenButton.Move(Padding + (ButtonWidth + ButtonGap) * 2, ButtonY, 170, ButtonHeight)
    }
}

BringSearchCenterFilterButtonsToFront() {
    global SearchCenterFilterButtons

    if (!IsSet(SearchCenterFilterButtons) || !IsObject(SearchCenterFilterButtons)) {
        return
    }

    for _, FilterBtn in SearchCenterFilterButtons {
        if (!FilterBtn || FilterBtn = 0) {
            continue
        }
        try {
            DllCall("SetWindowPos"
                , "ptr", FilterBtn.Hwnd
                , "ptr", 0
                , "int", 0
                , "int", 0
                , "int", 0
                , "int", 0
                , "uint", 0x0013)
            FilterBtn.Visible := true
            FilterBtn.Redraw()
        } catch {
        }
    }
}

MoveSearchCenterFilterButtons(FilterBarY, Padding := 20, KeepTop := true) {
    global SearchCenterFilterButtons

    if (!IsSet(SearchCenterFilterButtons) || !IsObject(SearchCenterFilterButtons)) {
        return
    }

    FilterButtonHeight := 30
    FilterButtonSpacing := 8
    FilterButtonY := FilterBarY + 5
    CurrentFilterX := Padding

    for _, FilterBtn in SearchCenterFilterButtons {
        if (!FilterBtn || FilterBtn = 0) {
            continue
        }
        try {
            FilterBtn.Visible := true
            FilterText := FilterBtn.Text
            FilterButtonWidth := Max(50, StrLen(FilterText) * 10 + 20)
            FilterBtn.Move(CurrentFilterX, FilterButtonY, FilterButtonWidth, FilterButtonHeight)
            CurrentFilterX += FilterButtonWidth + FilterButtonSpacing
        } catch {
        }
    }

    if (KeepTop) {
        BringSearchCenterFilterButtonsToFront()
    }
}

GetSearchCenterFilterDropdownLabel(FilterType := "") {
    switch FilterType {
        case "File":
            return "文件"
        case "clipboard":
            return "剪贴板"
        case "template":
            return "模板"
        case "config":
            return "配置"
        case "hotkey":
            return "快捷键"
        case "function":
            return "功能"
        default:
            return "全部"
    }
}

GetSearchCenterFilterDropdownIndex(FilterType := "") {
    switch FilterType {
        case "File":
            return 2
        case "clipboard":
            return 3
        case "template":
            return 4
        case "config":
            return 5
        case "hotkey":
            return 6
        case "function":
            return 7
        default:
            return 1
    }
}

GetSearchCenterFilterTypeFromDropdownLabel(FilterLabel := "") {
    switch Trim(FilterLabel) {
        case "文件":
            return "File"
        case "剪贴板":
            return "clipboard"
        case "模板":
            return "template"
        case "配置":
            return "config"
        case "快捷键":
            return "hotkey"
        case "功能":
            return "function"
        default:
            return ""
    }
}

GetSearchCenterFilterTypeFromDropdownIndex(FilterIndex := 1) {
    switch Integer(FilterIndex) {
        case 2:
            return "File"
        case 3:
            return "clipboard"
        case 4:
            return "template"
        case 5:
            return "config"
        case 6:
            return "hotkey"
        case 7:
            return "function"
        default:
            return ""
    }
}

GetSearchCenterDataTypesForFilter(FilterType := "") {
    switch FilterType {
        case "File":
            return ["file"]
        case "clipboard":
            return ["clipboard"]
        case "template":
            return ["template"]
        case "config":
            return ["config"]
        case "hotkey":
            return ["hotkey"]
        case "function":
            return ["function"]
        default:
            return []
    }
}

GetSearchCenterLimitFromDropdownText(LimitText := "") {
    Text := Trim(LimitText)
    Value := Integer(Text)
    if (Value <= 0) {
        return 50
    }
    return Value
}

GetSearchCenterLimitDropdownIndex(LimitValue := 50) {
    Value := Integer(LimitValue)
    switch Value {
        case 10:
            return 1
        case 20:
            return 2
        case 50:
            return 3
        case 100:
            return 4
        case 200:
            return 5
        default:
            return 3
    }
}

UpdateSearchCenterFilterDropdown() {
    global SearchCenterResultLimitDropdown, SearchCenterCurrentLimit

    if (!IsSet(SearchCenterResultLimitDropdown) || !SearchCenterResultLimitDropdown) {
        return
    }

    try SearchCenterResultLimitDropdown.Choose(GetSearchCenterLimitDropdownIndex(SearchCenterCurrentLimit))
}

SyncSearchCenterFilterTypeFromDropdown() {
    global SearchCenterFilterType
    return SearchCenterFilterType
}

UpdateSearchCenterCategoryMode() {
    global SearchCenterResultLimitDropdown, SearchCenterSearchEdit, SearchCenterAreaIndicator
    global SearchCenterHintText, SearchCenterResultLV, SearchCenterFilterButtons, SearchCenterActiveArea
    global SearchCenterCLIOutputEdit
    global SearchCenterCLIRunButton, SearchCenterCLIClearButton, SearchCenterCLIOpenButton

    IsCLI := SearchCenterIsCLICategory()
    
    SetSearchCenterControlVisible(SearchCenterResultLimitDropdown, true)
    SetSearchCenterControlVisible(SearchCenterSearchEdit, true)
    SetSearchCenterControlVisible(SearchCenterResultLV, true)
    SetSearchCenterControlVisible(SearchCenterAreaIndicator, true)
    SetSearchCenterControlVisible(SearchCenterHintText, true)
    for _, FilterBtn in SearchCenterFilterButtons {
        ; CLI 页同样需要本地结果分类筛选，与 AI 页一致显示过滤标签
        SetSearchCenterControlVisible(FilterBtn, true)
    }
    SetSearchCenterEngineIconsVisible(true)
    
    SetSearchCenterControlVisible(SearchCenterCLIOutputEdit, true)
    SetSearchCenterControlVisible(SearchCenterCLIRunButton, IsCLI)
    SetSearchCenterControlVisible(SearchCenterCLIClearButton, IsCLI)
    SetSearchCenterControlVisible(SearchCenterCLIOpenButton, IsCLI)
    
    if (IsCLI && SearchCenterActiveArea != "category" && SearchCenterActiveArea != "input" && SearchCenterActiveArea != "listview") {
        SearchCenterActiveArea := "input"
    }
    if (IsCLI) {
        UpdateSearchCenterCLIPreview()
        FocusSearchCenterCLIInput()
    }
    UpdateSearchCenterFilterDropdown()
    BringSearchCenterFilterButtonsToFront()
}

GetSearchCenterResultItemByRow(Row) {
    global SearchCenterVisibleResults, SearchCenterSearchResults

    if (IsSet(SearchCenterVisibleResults) && IsObject(SearchCenterVisibleResults) && Row > 0 && Row <= SearchCenterVisibleResults.Length) {
        return SearchCenterVisibleResults[Row]
    }
    if (Row > 0 && Row <= SearchCenterSearchResults.Length) {
        return SearchCenterSearchResults[Row]
    }
    return 0
}

BuildSearchCenterPreviewText(Item) {
    if (!IsObject(Item)) {
        return "当前未选中本地结果。`r`n`r`n在上方输入内容可实时过滤数据，选中列表项后会在这里显示详情预览。"
    }

    if (Item is Map) {
        Title := Item.Has("Title") ? String(Item["Title"]) : ""
        Source := Item.Has("Source") ? String(Item["Source"]) : ""
        Content := Item.Has("Content") ? String(Item["Content"]) : Title
        DataType := ""
        if (Item.Has("DataType") && Item["DataType"] != "") {
            DataType := String(Item["DataType"])
        } else if (Item.Has("OriginalDataType") && Item["OriginalDataType"] != "") {
            DataType := String(Item["OriginalDataType"])
        }
        TimeText := Item.Has("Time") ? String(Item["Time"]) : ""
    } else {
        Title := Item.HasProp("Title") ? Item.Title : ""
        Source := Item.HasProp("Source") ? Item.Source : ""
        Content := Item.HasProp("Content") ? Item.Content : Title
        DataType := ""
        if (Item.HasProp("DataType") && Item.DataType != "") {
            DataType := Item.DataType
        } else if (Item.HasProp("OriginalDataType") && Item.OriginalDataType != "") {
            DataType := Item.OriginalDataType
        }
        TimeText := Item.HasProp("Time") ? Item.Time : ""
    }

    PreviewText := "标题： " . Title
    if (Source != "") {
        PreviewText .= "`r`n来源： " . Source
    }
    if (DataType != "") {
        PreviewText .= "`r`n类型： " . DataType
    }
    if (TimeText != "") {
        PreviewText .= "`r`n时间： " . TimeText
    }
    PreviewText .= "`r`n`r`n内容预览：`r`n"
    PreviewText .= Content
    return PreviewText
}

UpdateSearchCenterCLIPreview(Row := 0) {
    global SearchCenterCLIOutputEdit, SearchCenterResultLV

    if (!SearchCenterCLIOutputEdit || SearchCenterCLIOutputEdit = 0) {
        return
    }

    if (Row <= 0 && SearchCenterResultLV && SearchCenterResultLV != 0) {
        try Row := SearchCenterResultLV.GetNext()
    }

    Item := GetSearchCenterResultItemByRow(Row)
    PreviewText := BuildSearchCenterPreviewText(Item)
    try SearchCenterCLIOutputEdit.Value := PreviewText
}

OnSearchCenterResultItemSelect(LV, Item, Selected) {
    if (Selected) {
        UpdateSearchCenterCLIPreview(Item)
    }
}

AppendSearchCenterCLIOutput(Text, AddBlankLine := true) {
    global SearchCenterCLIOutputEdit
    if (!SearchCenterCLIOutputEdit || SearchCenterCLIOutputEdit = 0) {
        return
    }
    ExistingText := ""
    try ExistingText := SearchCenterCLIOutputEdit.Value
    if (ExistingText != "") {
        ExistingText .= "`r`n"
    }
    ExistingText .= Text
    if (AddBlankLine) {
        ExistingText .= "`r`n"
    }
    try {
        SearchCenterCLIOutputEdit.Value := ExistingText
    } catch {
    }
}

RunEmbeddedPowerShellCommand(CommandText) {
    PowerShellPath := A_WinDir . "\System32\WindowsPowerShell\v1.0\powershell.exe"
    if (!FileExist(PowerShellPath)) {
        throw Error("找不到 Windows PowerShell")
    }
    Shell := ComObject("WScript.Shell")
    ExecObj := Shell.Exec('"' . PowerShellPath . '" -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command -')
    ExecObj.StdIn.WriteLine(CommandText)
    ExecObj.StdIn.Close()
    while (ExecObj.Status = 0) {
        Sleep(50)
    }
    StdOut := ExecObj.StdOut.ReadAll()
    StdErr := ExecObj.StdErr.ReadAll()
    ResultText := StdOut
    if (StdErr != "") {
        if (ResultText != "") {
            ResultText .= "`r`n"
        }
        ResultText .= StdErr
    }
    return Trim(ResultText, "`r`n")
}

GetGeminiAPIKey() {
    Key := ""
    try Key := Trim(EnvGet("GEMINI_API_KEY"))
    if (Key != "") {
        return Key
    }

    Key := ""
    try Key := Trim(EnvGet("GOOGLE_API_KEY"))
    if (Key != "") {
        return Key
    }

    try {
        global ConfigFile
        if (IsSet(ConfigFile) && ConfigFile != "" && FileExist(ConfigFile)) {
            Key := Trim(IniRead(ConfigFile, "API", "GeminiApiKey", ""))
            if (Key != "") {
                return Key
            }
        }
    } catch {
    }

    return ""
}

ExtractGeminiResponseText(ResponseObj) {
    try {
        if (ResponseObj is Map && ResponseObj.Has("candidates")) {
            Candidates := ResponseObj["candidates"]
            if (Candidates is Array && Candidates.Length > 0) {
                Candidate := Candidates[1]
                if (Candidate is Map && Candidate.Has("content")) {
                    Content := Candidate["content"]
                    if (Content is Map && Content.Has("parts")) {
                        Parts := Content["parts"]
                        if (Parts is Array) {
                            TextParts := []
                            for _, Part in Parts {
                                if (Part is Map && Part.Has("text")) {
                                    TextParts.Push(String(Part["text"]))
                                }
                            }
                            if (TextParts.Length > 0) {
                                Combined := ""
                                for Index, TextPart in TextParts {
                                    if (Index > 1) {
                                        Combined .= "`r`n"
                                    }
                                    Combined .= TextPart
                                }
                                return Combined
                            }
                        }
                    }
                }
            }
        }
    } catch {
    }
    return ""
}

SaveHeadlessAIResponseToDB(ResponseText, Engine, PromptText := "", ModelName := "") {
    global ClipboardDB

    if (ResponseText = "") {
        return false
    }
    if (!ClipboardDB || ClipboardDB = 0) {
        InitClipboardDB()
    }
    if (!ClipboardDB || ClipboardDB = 0) {
        return false
    }

    Meta := Map(
        "mode", "headless_api",
        "engine", Engine,
        "model", ModelName,
        "prompt", PromptText
    )
    MetaJson := StrReplace(Jxon_Dump(Meta), "'", "''")
    EscapedResponse := StrReplace(ResponseText, "'", "''")
    EscapedEngine := StrReplace(Engine, "'", "''")
    EscapedModel := StrReplace(ModelName, "'", "''")

    CharCount := StrLen(ResponseText)
    CleanedText := Trim(RegExReplace(ResponseText, "\s+", " "))
    WordCount := (CleanedText = "") ? 0 : StrSplit(CleanedText, A_Space).Length
    SQL := "INSERT INTO ClipboardHistory " .
           "(Content, DataType, SourceApp, SourceTitle, SourcePath, CharCount, WordCount, MetaData, Timestamp) VALUES (" .
           "'" . EscapedResponse . "', " .
           "'Text', " .
           "'GeminiAPI', " .
           "'Gemini Headless Response', " .
           "'" . EscapedEngine . ":" . EscapedModel . "', " .
           CharCount . ", " . WordCount . ", " .
           "'" . MetaJson . "', " .
           "datetime('now', 'localtime'))"
    try {
        return ClipboardDB.Exec(SQL)
    } catch {
        return false
    }
}

TryGeminiHeadlessRequest(PromptText, &ResponseText := "", &ErrorText := "") {
    ApiKey := GetGeminiAPIKey()
    if (ApiKey = "") {
        ErrorText := "未找到 GEMINI_API_KEY 或 GOOGLE_API_KEY"
        return false
    }

    ModelName := "gemini-2.5-flash"
    Url := "https://generativelanguage.googleapis.com/v1beta/models/" . ModelName . ":generateContent"
    RequestBody := Map(
        "contents", [
            Map("role", "user", "parts", [Map("text", PromptText)])
        ]
    )
    BodyText := Jxon_Dump(RequestBody)

    try {
        Http := ComObject("WinHttp.WinHttpRequest.5.1")
        Http.Open("POST", Url, false)
        Http.SetTimeouts(5000, 5000, 15000, 30000)
        Http.SetRequestHeader("x-goog-api-key", ApiKey)
        Http.SetRequestHeader("Content-Type", "application/json; charset=utf-8")
        Http.Send(BodyText)

        Status := Http.Status
        RawResponse := Http.ResponseText
        if (Status < 200 || Status >= 300) {
            ErrorText := "Gemini API HTTP " . Status . ": " . RawResponse
            return false
        }

        Parsed := Jxon_Load(RawResponse)
        ResponseText := ExtractGeminiResponseText(Parsed)
        if (ResponseText = "") {
            ErrorText := "Gemini API 返回为空或无法解析"
            return false
        }

        SaveHeadlessAIResponseToDB(ResponseText, "gemini_cli", PromptText, ModelName)
        return true
    } catch as err {
        ErrorText := err.Message
        return false
    }
}

TryGeminiHeadlessDispatch(PromptText, AppendToPanel := true) {
    ResponseText := ""
    ErrorText := ""
    if (!TryGeminiHeadlessRequest(PromptText, &ResponseText, &ErrorText)) {
        return false
    }

    if (AppendToPanel) {
        try {
            AppendSearchCenterCLIOutput("Gemini > " . PromptText, true)
            AppendSearchCenterCLIOutput(ResponseText, true)
        } catch {
        }
    }

    TrayTip("Gemini 已通过 Headless API 返回结果", "提示", "Iconi 1")
    return true
}

ExecuteSearchCenterCLICommand(*) {
    PromptText := GetSearchCenterCurrentCLICommand()
    if (PromptText = "") {
        TrayTip("请输入要发送给 AI 的内容", "提示", "Icon! 2")
        return
    }
    
    LaunchSelectedCLIAgents(PromptText)
    FocusSearchCenterCLIInput()
}

ClearSearchCenterCLIOutput(*) {
    global SearchCenterCLIOutputEdit, SearchCenterSearchEdit
    if (SearchCenterCLIOutputEdit && SearchCenterCLIOutputEdit != 0) {
        try SearchCenterCLIOutputEdit.Value := ""
    }
    if (SearchCenterSearchEdit && SearchCenterSearchEdit != 0) {
        try SearchCenterSearchEdit.Value := ""
    }
    UpdateSearchCenterCLIPreview(0)
    FocusSearchCenterCLIInput()
}

; 创建分类点击处理器
CreateSearchCategoryClickHandler(CategoryIndex) {
    return SearchCategoryClickHandler.Bind(CategoryIndex)
}

; 创建搜索中心过滤标签点击处理器
CreateSearchCenterFilterClickHandler(FilterType) {
    return SearchCenterFilterClickHandler.Bind(FilterType)
}

; ===================== 更新搜索中心过滤标签按钮样式 =====================
; 【参考 ClipboardHistoryPanel 的实现】
UpdateSearchCenterFilterButtons() {
    global SearchCenterFilterButtons, SearchCenterFilterButtonMap, SearchCenterFilterType, UI_Colors, GuiID_SearchCenter
    
    if (!IsSet(SearchCenterFilterButtons) || !IsObject(SearchCenterFilterButtons)) {
        return
    }
    
    OutputDebug("AHK_DEBUG: UpdateSearchCenterFilterButtons - SearchCenterFilterType: " . SearchCenterFilterType)
    
    ; 优先使用映射表（与记录面板同思路：类型驱动样式）
    if (IsSet(SearchCenterFilterButtonMap) && IsObject(SearchCenterFilterButtonMap) && SearchCenterFilterButtonMap.Count > 0) {
        for BtnType, FilterBtn in SearchCenterFilterButtonMap {
            try {
                IsSelected := (SearchCenterFilterType = BtnType)
                TagBg := UI_Colors.Sidebar
                TagBgActive := "e67e22"
                TagText := UI_Colors.TextDim
                TagTextActive := "ffffff"
                BgColor := IsSelected ? TagBgActive : TagBg
                TextColor := IsSelected ? TagTextActive : TagText

                FilterBtn.Opt("+Background" . BgColor)
                FilterBtn.SetFont("s10 c" . TextColor . " Bold", "Segoe UI")
                try {
                    hoverFunc := HoverBtnWithAnimation
                    if (IsSet(hoverFunc)) {
                        HoverBtnWithAnimation(FilterBtn, BgColor, TagBgActive)
                    }
                } catch {
                }
                try FilterBtn.Redraw()
            } catch as err {
                OutputDebug("AHK_DEBUG: UpdateSearchCenterFilterButtons(map) - Error: " . err.Message)
            }
        }
        return
    }

    ; 回退：遍历数组
    for Index, FilterBtn in SearchCenterFilterButtons {
        try {
            ; 从按钮对象上获取 FilterType
            BtnType := ""
            if (FilterBtn.HasProp("FilterType")) {
                BtnType := FilterBtn.FilterType
            } else {
                ; 向后兼容：通过索引推断（如果 FilterType 属性不存在）
                if (Index = 1) {
                    BtnType := ""  ; 全部
                } else if (Index = 2) {
                    BtnType := "File"
                } else if (Index = 3) {
                    BtnType := "clipboard"
                } else if (Index = 4) {
                    BtnType := "template"
                } else if (Index = 5) {
                    BtnType := "config"
                } else if (Index = 6) {
                    BtnType := "hotkey"
                } else if (Index = 7) {
                    BtnType := "function"
                }
            }
            
            IsSelected := (SearchCenterFilterType = BtnType)
            OutputDebug("AHK_DEBUG: UpdateSearchCenterFilterButtons - Index: " . Index . ", BtnType: " . BtnType . ", IsSelected: " . IsSelected)
            
            TagBg := UI_Colors.Sidebar
            TagBgActive := "e67e22"
            TagText := UI_Colors.TextDim
            TagTextActive := "ffffff"
            BgColor := IsSelected ? TagBgActive : TagBg
            TextColor := IsSelected ? TagTextActive : TagText

            ; 更新按钮样式（参考 ClipboardHistoryPanel 的实现方式）
            FilterBtn.Opt("+Background" . BgColor)
            FilterBtn.SetFont("s10 c" . TextColor . " Bold", "Segoe UI")
            try {
                hoverFunc := HoverBtnWithAnimation
                if (IsSet(hoverFunc)) {
                    HoverBtnWithAnimation(FilterBtn, BgColor, TagBgActive)
                }
            } catch {
            }
        } catch as err {
            OutputDebug("AHK_DEBUG: UpdateSearchCenterFilterButtons - Error: " . err.Message)
        }
    }
}

; 搜索中心过滤标签点击处理函数
SearchCenterFilterClickHandler(FilterType, *) {
    global SearchCenterFilterType, SearchCenterSearchResults, SearchCenterResultLV, UI_Colors, GuiID_SearchCenter
    global SearchCenterSearchEdit, SearchCenterEverythingLimit, SearchCenterCurrentLimit

    ; 兼容“全部”标签空字符串绑定场景：若首参是控件对象，则从控件属性读取 FilterType
    if (IsObject(FilterType)) {
        try {
            if (FilterType.HasProp("FilterType")) {
                FilterType := FilterType.FilterType
            } else {
                FilterType := ""
            }
        } catch {
            FilterType := ""
        }
    }
    if (!IsSet(FilterType))
        FilterType := ""

    OutputDebug("AHK_DEBUG: SearchCenterFilterClickHandler - FilterType: " . FilterType . ", Old SearchCenterFilterType: " . SearchCenterFilterType)
    
    ; 如果点击的是已选中的标签，则取消选中（显示全部）
    if (SearchCenterFilterType = FilterType) {
        SearchCenterFilterType := ""
    } else {
        ; 更新过滤类型
        SearchCenterFilterType := FilterType
    }
    
    OutputDebug("AHK_DEBUG: SearchCenterFilterClickHandler - New SearchCenterFilterType: " . SearchCenterFilterType)
    
    ; 【关键修复】使用统一的更新函数更新按钮样式
    UpdateSearchCenterFilterButtons()
    BringSearchCenterFilterButtonsToFront()
    try {
        if (GuiID_SearchCenter && IsObject(GuiID_SearchCenter) && GuiID_SearchCenter.HasProp("Hwnd")) {
            WinRedraw(GuiID_SearchCenter.Hwnd)
        }
    } catch {
    }
    
    ; 刷新搜索结果列表（根据过滤类型过滤）
    RefreshSearchCenterResults()
}

; 分类点击处理函数
SearchCategoryClickHandler(CategoryIndex, *) {
    ; 切换分类并聚焦到分类区域
    global SearchCenterActiveArea, SearchCenterCurrentCategory
    SearchCenterCurrentCategory := CategoryIndex
    SwitchSearchCenterCategory(CategoryIndex, true)
    SearchCenterActiveArea := "category"
    UpdateSearchCenterHighlight()
    ; 【关键修复】立即刷新标签样式，确保点击后立即变橙色
    try {
        if (GuiID_SearchCenter && IsObject(GuiID_SearchCenter) && GuiID_SearchCenter.HasProp("Hwnd")) {
            WinRedraw(GuiID_SearchCenter.Hwnd)
        }
    } catch as err {
        ; 忽略刷新错误
    }
}

; 切换搜索中心分类
SwitchSearchCenterCategory(Direction, DirectIndex := false) {
    global SearchCenterCurrentCategory, SearchCenterCategoryButtons, UI_Colors, SearchCenterActiveArea
    global SearchCenterSelectedEngines, SearchCenterSelectedEnginesByCategory
    
    ; 获取分类列表
    Categories := GetSearchCenterCategories()
    
    if (Categories.Length = 0) {
        return
    }
    
    ; 【关键修复】保存当前分类的搜索引擎选择状态（切换分类前保存）
    if (Categories.Length > 0 && SearchCenterCurrentCategory >= 0 && SearchCenterCurrentCategory < Categories.Length) {
        OldCategory := Categories[SearchCenterCurrentCategory + 1]
        if (IsSet(SearchCenterSelectedEngines) && IsObject(SearchCenterSelectedEngines)) {
            CurrentEngines := []
            for Index, Engine in SearchCenterSelectedEngines {
                CurrentEngines.Push(Engine)
            }
            if (!IsSet(SearchCenterSelectedEnginesByCategory) || !IsObject(SearchCenterSelectedEnginesByCategory)) {
                SearchCenterSelectedEnginesByCategory := Map()
            }
            SearchCenterSelectedEnginesByCategory[OldCategory.Key] := CurrentEngines
            
            ; 【关键修复】参考CAPSLOCK+F的实现：保存到配置文件
            try {
                global ConfigFile
                EnginesStr := ""
                for Index, Eng in SearchCenterSelectedEngines {
                    if (Index > 1) {
                        EnginesStr .= ","
                    }
                    EnginesStr .= Eng
                }
                ; 保存格式：分类:引擎1,引擎2
                CategoryEnginesStr := OldCategory.Key . ":" . EnginesStr
                IniWrite(CategoryEnginesStr, ConfigFile, "Settings", "SearchCenterSelectedEngines_" . OldCategory.Key)
            } catch as err {
                ; 忽略保存错误
            }
        }
    }
    
    if (DirectIndex) {
        ; 直接设置索引
        NewIndex := Direction
    } else {
        ; 根据方向切换
        NewIndex := SearchCenterCurrentCategory + Direction
        if (NewIndex < 0)
            NewIndex := Categories.Length - 1
        else if (NewIndex >= Categories.Length)
            NewIndex := 0
    }
    
    SearchCenterCurrentCategory := NewIndex
    
    ; 更新按钮样式
    UpdateSearchCenterHighlight()
    UpdateSearchCenterCategoryMode()
    UpdateSearchCenterCLILayout()
    
    ; 【关键修复】先刷新标签背景色，确保立即显示
    try {
        if (GuiID_SearchCenter && IsObject(GuiID_SearchCenter) && GuiID_SearchCenter.HasProp("Hwnd")) {
            WinRedraw(GuiID_SearchCenter.Hwnd)
        }
    } catch as err {
        ; 忽略刷新错误
    }
    BringSearchCenterFilterButtonsToFront()
    
    ; 刷新搜索引擎图标显示
    RefreshSearchCenterEngineIcons()

    if (SearchCenterIsCLICategory()) {
        try ExecuteSearchCenterSearch()
    }
    
    ; 确保激活状态在分类栏
    SearchCenterActiveArea := "category"
}

; 刷新搜索中心输入框边框（用于 SetTimer 回调，确保边框完全移除）
RefreshSearchCenterEditBorder(EditHwnd) {
    try {
        if (EditHwnd) {
            DllCall("InvalidateRect", "Ptr", EditHwnd, "Ptr", 0, "Int", 1)
            DllCall("UpdateWindow", "Ptr", EditHwnd)
        }
    } catch {
        ; 忽略错误
    }
}

; 恢复搜索中心区域指示器字体（用于 SetTimer 回调）
RestoreSearchCenterAreaIndicatorFont() {
    global SearchCenterAreaIndicator, UI_Colors
    ; 【修复】检查控件是否存在，避免控件已销毁错误
    if (SearchCenterAreaIndicator != 0) {
        try {
            SearchCenterAreaIndicator.SetFont("s11 Bold c" . UI_Colors.BtnPrimary, "Segoe UI")
        } catch as err {
            ; 忽略控件已销毁的错误
        }
    }
}

; 更新搜索中心高亮显示
UpdateSearchCenterHighlight() {
    global SearchCenterActiveArea, SearchCenterCurrentCategory, SearchCenterCategoryButtons, SearchCenterSearchEdit, SearchCenterResultLV, UI_Colors, ThemeMode
    global SearchCenterSelectedEnginesByCategory, ConfigFile, SearchCenterHintText, GuiID_SearchCenter, SearchCenterAreaIndicator
    global SearchCenterCLIOutputEdit
    
    ; 更新分类标签高亮
    Categories := GetSearchCenterCategories()
    for Index, Btn in SearchCenterCategoryButtons {
        IsSelected := (Index - 1 = SearchCenterCurrentCategory)
        IsActive := (SearchCenterActiveArea = "category" && IsSelected)
        
        ; 获取当前分类的选中搜索引擎数量
        if (Index <= Categories.Length) {
            CategoryKey := Categories[Index].Key
            SelectedCount := 0
            if (IsSet(SearchCenterSelectedEnginesByCategory) && IsObject(SearchCenterSelectedEnginesByCategory) && SearchCenterSelectedEnginesByCategory.Has(CategoryKey)) {
                SelectedCount := SearchCenterSelectedEnginesByCategory[CategoryKey].Length
            } else {
                ; 尝试从配置文件加载
                try {
                    CategoryEnginesStr := IniRead(ConfigFile, "Settings", "SearchCenterSelectedEngines_" . CategoryKey, "")
                    if (CategoryEnginesStr != "") {
                        if (InStr(CategoryEnginesStr, ":") > 0) {
                            EnginesStr := SubStr(CategoryEnginesStr, InStr(CategoryEnginesStr, ":") + 1)
                        } else {
                            EnginesStr := CategoryEnginesStr
                        }
                        if (EnginesStr != "") {
                            EnginesArray := StrSplit(EnginesStr, ",")
                            SelectedCount := EnginesArray.Length
                        }
                    }
                } catch as err {
                }
            }
            
            ; 更新标签文本，显示选中数量
            CategoryText := Categories[Index].Text
            if (SelectedCount > 0) {
                CategoryText := Categories[Index].Text . " (" . SelectedCount . ")"
            }
            
            try {
                Btn.Text := CategoryText
            } catch as err {
            }
        }
        
        if (IsActive) {
            ; 激活状态：高亮背景色（更亮的颜色）
            BgColor := UI_Colors.BtnPrimary
            TextColor := "FFFFFF"
        } else if (IsSelected) {
            ; 选中但未激活
            BgColor := UI_Colors.BtnPrimary
            TextColor := "FFFFFF"
        } else {
            ; 未选中
            BgColor := UI_Colors.Sidebar
            TextColor := UI_Colors.Text
        }
        
        try {
            Btn.Opt("+Background" . BgColor)
            Btn.SetFont("s10 Bold c" . TextColor, "Segoe UI")
        } catch as err {
            ; 忽略错误
        }
    }
    
    ; 更新输入框高亮（Material Design风格：聚焦时背景色变化，无边框）
    if (SearchCenterSearchEdit != 0) {
        try {
            ; 根据主题模式设置背景色（完全移除边框，只改变背景色）
            if (SearchCenterActiveArea = "input") {
                ; 激活输入框时，使用更亮的背景色
                if (ThemeMode = "dark") {
                    SearchCenterSearchEdit.Opt("+Background" . "3d3d40")  ; 稍亮的背景
                } else {
                    SearchCenterSearchEdit.Opt("+Background" . UI_Colors.InputBg)
                }
            } else {
                ; 未激活时，恢复默认背景色
                if (ThemeMode = "dark") {
                    SearchCenterSearchEdit.Opt("+Background" . UI_Colors.InputBg)  ; html.to.design 风格背景
                } else {
                    SearchCenterSearchEdit.Opt("+Background" . UI_Colors.InputBg)
                }
            }
        } catch as err {
            ; 忽略错误
        }
    }
    
    if (SearchCenterCLIOutputEdit != 0) {
        try {
            SearchCenterCLIOutputEdit.Opt("+Background" . UI_Colors.InputBg)
        } catch {
        }
    }
    
    ; 更新ListView高亮（通过选中状态）
    if (SearchCenterResultLV != 0) {
        try {
            if (SearchCenterActiveArea = "listview") {
                ; 激活ListView时，确保有选中项
                if (SearchCenterResultLV.GetCount() > 0 && SearchCenterResultLV.GetNext() = 0) {
                    ; 如果没有选中项，选中第一项
                    SearchCenterResultLV.Modify(1, "Select Focus")
                }
            }
        } catch as err {
            ; 忽略错误
        }
    }
    
    ; 更新区域名称动画展示
    if (SearchCenterAreaIndicator != 0) {
        try {
            ; 根据当前区域生成区域名称
            AreaName := ""
            if (SearchCenterIsCLICategory()) {
                switch SearchCenterActiveArea {
                    case "category":
                        AreaName := "CLI 分类"
                    case "input":
                        AreaName := "AI 对话"
                    case "listview":
                        AreaName := "本地结果"
                }
            } else {
                switch SearchCenterActiveArea {
                    case "category":
                        AreaName := "📍 分类搜索"  ; 当前区域名称
                    case "input":
                        AreaName := "✏️ 输入框"  ; 当前区域名称
                    case "listview":
                        AreaName := "🔍 本地搜索"  ; 当前区域名称（搜索结果列表）
                }
            }
            
            ; 更新区域名称文本（带动效：先放大高亮，然后恢复）
            SearchCenterAreaIndicator.Text := AreaName
            
            ; 区域切换动效：文本颜色和大小动画
            try {
                ; 【修复】检查控件是否存在，避免访问已销毁的控件
                if (SearchCenterAreaIndicator != 0) {
                    ; 先设置为高亮颜色和更大字体（动效提示）
                    HighlightColor := UI_Colors.BtnPrimary
                    SearchCenterAreaIndicator.SetFont("s13 Bold c" . HighlightColor, "Segoe UI")
                    ; 300ms后恢复为普通大小和颜色
                    SetTimer(RestoreSearchCenterAreaIndicatorFont, -300)
                }
            } catch as err {
                ; 忽略动效错误
            }
        } catch as err {
            ; 忽略更新错误
        }
    }
    
    ; 更新操作提示文本
    if (SearchCenterHintText != 0) {
        try {
            ; 根据当前区域生成详细的操作提示文本
            AreaHint := ""
            
            if (SearchCenterIsCLICategory()) {
                switch SearchCenterActiveArea {
                    case "category":
                        AreaHint := "当前是 CLI 页面。选择上方 AI，向下进入输入框，继续向下可查看本地结果和筛选标签。"
                    case "input":
                        AreaHint := "顶部输入框会实时过滤本地数据；Enter 发送给所选 AI，向下可浏览全部、文件、剪贴板等结果，底部区域显示选中项详情。"
                    case "listview":
                        AreaHint := "这里与 AI 页一致，显示本地检索结果。可用筛选标签切换全部、文件、剪贴板等数据，底部区域会预览当前选中项的详细内容。"
                }
            } else {
                switch SearchCenterActiveArea {
                    case "category":
                        AreaHint := "您可以使用方向键或 CapsLock+WSAD 切换操作。向上可以切换分类，向下进入输入框，Enter 执行搜索"
                    case "input":
                        AreaHint := "您可以使用方向键或 CapsLock+WSAD 切换操作。向上进入分类栏，向下查看本地搜索结果，Enter 执行搜索。向上实现向多个AI提问或者网络搜索，向下可以查看搜索本地提示词和剪贴板"
                    case "listview":
                        AreaHint := "您可以使用方向键或 CapsLock+WSAD 切换操作。向上返回输入框，向下浏览结果，Enter 粘贴选中项。这里显示本地搜索的提示词和剪贴板历史"
                }
            }
            
            ; 更新提示文本
            SearchCenterHintText.Text := AreaHint
            
            ; 区域切换动效：文本颜色闪烁提示
            try {
                ; 先设置为高亮颜色（动效提示）
                HighlightColor := UI_Colors.BtnPrimary
                SearchCenterHintText.SetFont("s9 Bold c" . HighlightColor, "Segoe UI")
                ; 200ms后恢复为普通颜色
                SetTimer(() => (
                    SearchCenterHintText.SetFont("s9 c" . UI_Colors.TextDim, "Segoe UI")
                ), -200)
            } catch as err {
                ; 忽略动效错误
            }
        } catch as err {
            ; 忽略更新错误
        }
    }
    
    ; 区域边框高亮动效（通过改变输入框和ListView的边框颜色）
    try {
        ; 输入框边框动效
        if (SearchCenterSearchEdit != 0) {
            if (SearchCenterActiveArea = "input") {
                ; 激活时：添加边框高亮效果（通过改变背景色实现）
                if (ThemeMode = "dark") {
                    ; 暗色模式：使用更亮的背景色作为边框效果
                    SearchCenterSearchEdit.Opt("+Background" . "3d3d40")
                } else {
                    ; 亮色模式：使用稍亮的背景色
                    SearchCenterSearchEdit.Opt("+Background" . UI_Colors.InputBg)
                }
            }
        }
        
        ; ListView边框动效（通过背景色变化实现）
        if (SearchCenterResultLV != 0) {
            if (SearchCenterActiveArea = "listview") {
                ; 激活时：使用稍亮的背景色
                if (ThemeMode = "dark") {
                    SearchCenterResultLV.Opt("+Background" . "3d3d40")
                } else {
                    SearchCenterResultLV.Opt("+Background" . UI_Colors.InputBg)
                }
            } else {
                ; 未激活时：恢复默认背景色
                SearchCenterResultLV.Opt("+Background" . UI_Colors.InputBg)
            }
        }
    } catch as err {
        ; 忽略动效错误
    }
}

; ===================== 结果数量限制下拉菜单变化事件 =====================
OnSearchCenterResultLimitChange(*) {
    global SearchCenterResultLimitDropdown, SearchCenterSearchEdit
    global SearchCenterCurrentLimit, SearchCenterEverythingLimit
    
    if (!IsSet(SearchCenterResultLimitDropdown) || !SearchCenterResultLimitDropdown) {
        return
    }
    
    try {
        selectedText := SearchCenterResultLimitDropdown.Text
        newLimit := GetSearchCenterLimitFromDropdownText(selectedText)
    } catch {
        newLimit := 50
    }

    if (newLimit <= 0)
        newLimit := 50

    SearchCenterCurrentLimit := newLimit
    SearchCenterEverythingLimit := newLimit
    
    UpdateSearchCenterFilterDropdown()
    if (IsSet(SearchCenterSearchEdit) && SearchCenterSearchEdit && Trim(SearchCenterSearchEdit.Value) != "") {
        ExecuteSearchCenterSearch()
        return
    }
    RefreshSearchCenterResults()
}

; 执行搜索中心搜索（带防抖）
ExecuteSearchCenterSearch(*) {
    global SearchCenterSearchEdit, SearchCenterResultLV, SearchCenterSearchResults
    global SearchCenterDebounceTimer
    
    ; 取消之前的防抖定时器（专用定时器，避免与配置面板 SearchDebounceTimer 互相覆盖）
    if (SearchCenterDebounceTimer != 0) {
        SetTimer(SearchCenterDebounceTimer, 0)
        SearchCenterDebounceTimer := 0
    }
    
    ; 设置新的防抖定时器（150ms 延迟）
    SearchCenterDebounceTimer := (*) => DebouncedSearchCenter(0)  ; 新搜索，offset = 0
    SetTimer(SearchCenterDebounceTimer, -150)
}

; 防抖后的实际搜索执行
; 加载默认模板到搜索中心
LoadDefaultTemplates() {
    global SearchCenterSearchResults, SearchCenterResultLV, SearchCenterVisibleResults
    
    ; 加载提示词模板作为默认内容
    global PromptTemplates
    if (!PromptTemplates) {
        LoadPromptTemplates()
    }
    
    ; 将模板添加到搜索结果
    for template in PromptTemplates {
        SearchCenterSearchResults.Push({
            Title: template.Title,
            Content: template.Content,
            Source: "模板",
            DataType: "template",
            Time: ""
        })
    }
    
    RefreshSearchCenterResults()
    
    ; 【关键修复】确保标签按钮状态正确显示
    UpdateSearchCenterFilterButtons()
    
    OutputDebug("AHK_DEBUG: 默认模板加载完成，数量: " . SearchCenterSearchResults.Length)
}

; 防抖后的实际搜索执行
DebouncedSearchCenter(offset := 0) {
    global SearchCenterSearchResults, SearchCenterResultLV, SearchCenterSearchEdit
    global SearchCenterCurrentLimit, SearchCenterHasMoreData, SearchCenterFilterType
    
    ; 下拉仅控制结果数量，不覆盖过滤标签状态
    Keyword := Trim(SearchCenterSearchEdit.Value)
    
    ; 如果是新搜索（offset = 0），重置数据
    if (offset = 0) {
        SearchCenterSearchResults := []
        SearchCenterResultLV.Delete()
    }
    
    if (Keyword == "") {
        if (offset = 0) {
            LoadDefaultTemplates()
        }
        return
    }

    OutputDebug("AHK_DEBUG: 开始搜索流程... (offset: " . offset . ", limit: " . SearchCenterCurrentLimit . ")")
    OutputDebug("AHK_DEBUG: 当前来源过滤: " . SearchCenterFilterType)

    ; 2. 使用 SearchAllDataSources 搜索所有数据源（支持分页）
    ; 临时存储新加载的数据
    NewResults := []
    try {
        FilterDataTypes := GetSearchCenterDataTypesForFilter(SearchCenterFilterType)
        ; 非「全部」且当前不是仅「文件」过滤时，顺带检索磁盘（Everything），与剪贴板/模板等混排
        if (FilterDataTypes.Length > 0) {
            hasFileType := false
            for _, dt in FilterDataTypes {
                if (dt = "file") {
                    hasFileType := true
                    break
                }
            }
            if (!hasFileType)
                FilterDataTypes.Push("file")
        }
        AllDataResults := SearchAllDataSources(Keyword, FilterDataTypes, SearchCenterCurrentLimit, offset)
        
        ; 检查是否有更多数据
        SearchCenterHasMoreData := false
        for DataType, TypeData in AllDataResults {
            if (IsObject(TypeData) && TypeData.HasProp("HasMore") && TypeData.HasMore) {
                SearchCenterHasMoreData := true
                break
            }
        }
        
        ; 将 Map 格式转换为扁平化的数组
        for DataType, TypeData in AllDataResults {
            if (IsObject(TypeData) && TypeData.HasProp("Items")) {
                for Index, Item in TypeData.Items {
                    ; 格式化时间显示
                    TimeDisplay := ""
                    if (Item.HasProp("TimeFormatted")) {
                        TimeDisplay := Item.TimeFormatted
                    } else if (Item.HasProp("Timestamp")) {
                        try {
                            TimeDisplay := FormatTime(Item.Timestamp, "yyyy-MM-dd HH:mm:ss")
                        } catch as err {
                            TimeDisplay := Item.Timestamp
                        }
                    } else {
                        TimeDisplay := ""
                    }
                    
                    ; 生成标题（文件类优先友好 DisplayTitle）
                    TitleText := ""
                    if (Item.HasProp("DisplayTitle") && Item.DisplayTitle != "") {
                        TitleText := Item.DisplayTitle
                    } else if (Item.HasProp("Title") && Item.Title != "") {
                        TitleText := Item.Title
                    } else if (Item.HasProp("Content") && Item.Content != "") {
                        TitleText := SubStr(Item.Content, 1, 50)
                        if (StrLen(Item.Content) > 50) {
                            TitleText .= "..."
                        }
                    } else {
                        TitleText := ""
                    }
                    
                    ; 提取数据类型（优先从Metadata.DataType中获取，然后从Item.DataType，最后从DataType推断）
                    ItemDataType := ""
                    ; 1. 优先从Metadata中获取（剪贴板历史使用这种方式）
                    if (Item.HasProp("Metadata") && IsObject(Item.Metadata) && Item.Metadata.Has("DataType") && Item.Metadata["DataType"] != "") {
                        ItemDataType := Item.Metadata["DataType"]
                    } 
                    ; 2. 从Item.DataType获取（其他数据源可能直接有这个字段，但要排除数据源类型）
                    else if (Item.HasProp("DataType") && Item.DataType != "") {
                        ; 排除数据源类型（clipboard/template/config/file/hotkey/function/ui），这些不是内容类型
                        if (Item.DataType != "clipboard" && Item.DataType != "template" && Item.DataType != "config" && Item.DataType != "file" && Item.DataType != "hotkey" && Item.DataType != "function" && Item.DataType != "ui") {
                            ItemDataType := Item.DataType
                        }
                    }
                    
                    ; 3. 如果是剪贴板数据，但没有找到具体类型，从DataTypeName反向映射
                    if (ItemDataType = "" && DataType = "clipboard") {
                        if (Item.HasProp("DataTypeName") && Item.DataTypeName != "") {
                            DataTypeName := Item.DataTypeName
                            if (DataTypeName = "代码片段" || DataTypeName = "代码") {
                                ItemDataType := "Code"
                            } else if (DataTypeName = "链接") {
                                ItemDataType := "Link"
                            } else if (DataTypeName = "邮箱" || DataTypeName = "邮件") {
                                ItemDataType := "Email"
                            } else if (DataTypeName = "图片") {
                                ItemDataType := "Image"
                            } else if (DataTypeName = "颜色") {
                                ItemDataType := "Color"
                            } else if (DataTypeName = "文本" || DataTypeName = "剪贴板历史") {
                                ItemDataType := "Text"
                            }
                        }
                    }
                    
                    ; 4. 对于非剪贴板数据源，使用数据源类型作为显示类型（template/config/file等）
                    if (ItemDataType = "" && DataType != "clipboard") {
                        ; 使用数据源类型作为标签
                        if (DataType = "template") {
                            ItemDataType := "Template"
                        } else if (DataType = "config") {
                            ItemDataType := "Config"
                        } else if (DataType = "file") {
                            ItemDataType := "File"
                        } else if (DataType = "hotkey") {
                            ItemDataType := "Hotkey"
                        } else if (DataType = "function") {
                            ItemDataType := "Function"
                        } else if (DataType = "ui") {
                            ItemDataType := "UI"
                        }
                    }
                    
                    ; 5. 如果没有找到类型，使用默认值（对于剪贴板默认为Text，其他为数据源类型）
                    if (ItemDataType = "") {
                        ItemDataType := DataType = "clipboard" ? "Text" : DataType
                    }
                    
                    ResultItem := {
                        Title: TitleText,
                        Source: TypeData.HasProp("DataTypeName") ? TypeData.DataTypeName : DataType,
                        DataType: ItemDataType,
                        Time: TimeDisplay,
                        Content: Item.HasProp("Content") ? Item.Content : TitleText,
                        ID: Item.HasProp("ID") ? Item.ID : "",
                        OriginalDataType: DataType
                    }
                    if (Item.HasProp("Metadata") && IsObject(Item.Metadata))
                        ResultItem.Metadata := Item.Metadata
                    if (Item.HasProp("DisplayTitle") && Item.DisplayTitle != "")
                        ResultItem.DisplayTitle := Item.DisplayTitle
                    if (Item.HasProp("Category") && Item.Category != "")
                        ResultItem.Category := Item.Category
                    if (Item.HasProp("TypeHint") && Item.TypeHint != "")
                        ResultItem.TypeHint := Item.TypeHint
                    if (Item.HasProp("FzyCategoryBonus"))
                        ResultItem.FzyCategoryBonus := Item.FzyCategoryBonus
                    if (Item.HasProp("DisplayPath") && Item.DisplayPath != "")
                        ResultItem.DisplayPath := Item.DisplayPath
                    if (Item.HasProp("DisplaySubtitle") && Item.DisplaySubtitle != "")
                        ResultItem.DisplaySubtitle := Item.DisplaySubtitle
                    if (Item.HasProp("SubCategory") && Item.SubCategory != "")
                        ResultItem.SubCategory := Item.SubCategory
                    if (Item.HasProp("CategoryColor") && Item.CategoryColor != "")
                        ResultItem.CategoryColor := Item.CategoryColor
                    if (Item.HasProp("PathTrust"))
                        ResultItem.PathTrust := Item.PathTrust
                    if (Item.HasProp("BonusTotal"))
                        ResultItem.BonusTotal := Item.BonusTotal
                    if (Item.HasProp("PenaltyTotal"))
                        ResultItem.PenaltyTotal := Item.PenaltyTotal
                    if (Item.HasProp("FzyBase"))
                        ResultItem.FzyBase := Item.FzyBase
                    if (Item.HasProp("FinalScore"))
                        ResultItem.FinalScore := Item.FinalScore
                    if (Item.HasProp("QuotaCategory"))
                        ResultItem.QuotaCategory := Item.QuotaCategory
                    
                    ; 如果是新搜索，追加到总结果；如果是加载更多，只追加到新结果
                    if (offset = 0) {
                        SearchCenterSearchResults.Push(ResultItem)
                    } else {
                        NewResults.Push(ResultItem)
                    }
                }
            }
        }
    } catch as err {
        OutputDebug("AHK_DEBUG: SearchAllDataSources 报错: " . err.Message)
    }

    ; 身份化：标题前缀与副标题（排序前）
    if (offset = 0 && SearchCenterSearchResults.Length > 0 && StrLen(Keyword) > 0) {
        try {
            Loop SearchCenterSearchResults.Length {
                scItem := SearchCenterSearchResults[A_Index]
                SyncIdentityToResultItem(&scItem, Keyword)
            }
        } catch as errId {
            OutputDebug("AHK_DEBUG: SyncIdentityToResultItem: " . errId.Message)
        }
    }

    ; 文件（Everything）置顶 + Fzy 精准加权；其余来源排在后面
    if (offset = 0 && SearchCenterSearchResults.Length > 0) {
        try SortSearchCenterMergedResults(&SearchCenterSearchResults, Keyword)
    }

    ; 3. 【关键修复】统一渲染到界面（使用中文类型名称）
    ; 刷新结果显示（应用过滤）
    RefreshSearchCenterResults()
    
    OutputDebug("AHK_DEBUG: 搜索中心刷新完成，总结果: " . SearchCenterSearchResults.Length . ", 还有更多: " . (SearchCenterHasMoreData ? "是" : "否"))
}

; Destroy 之后必须清空控件引用，否则异步 RefreshSearchCenterResults 仍持有旧 Gui.Control 会报 “control is destroyed”
SearchCenterInvalidateGuiControlRefs() {
    global SearchCenterSearchEdit, SearchCenterResultLV, SearchCenterCLIOutputEdit
    global SearchCenterAreaIndicator, SearchCenterHintText, SearchCenterResultLimitDropdown
    SearchCenterSearchEdit := 0
    SearchCenterResultLV := 0
    SearchCenterCLIOutputEdit := 0
    SearchCenterAreaIndicator := 0
    SearchCenterHintText := 0
    SearchCenterResultLimitDropdown := 0
}

; 刷新搜索中心结果显示（应用过滤类型）
RefreshSearchCenterResults() {
    global SearchCenterSearchResults, SearchCenterResultLV, SearchCenterFilterType, SearchCenterVisibleResults
    global GuiID_SearchCenter
    
    if (!GuiID_SearchCenter || GuiID_SearchCenter = 0) {
        return
    }
    try {
        if (!GuiID_SearchCenter.HasProp("Hwnd") || !WinExist("ahk_id " . GuiID_SearchCenter.Hwnd)) {
            return
        }
    } catch {
        return
    }
    if (!SearchCenterResultLV || SearchCenterResultLV = 0) {
        return
    }

    ; 下拉仅控制结果数量，不覆盖过滤标签状态
    try {
    ; 清空ListView
    SearchCenterResultLV.Opt("-Redraw")
    SearchCenterResultLV.Delete()
    
    ; 根据过滤类型过滤结果
    FilteredResults := []
    for index, res in SearchCenterSearchResults {
        ; 检查是否匹配过滤类型
        ShouldInclude := false
        
        if (SearchCenterFilterType = "") {
            ; 全部：显示所有结果
            ShouldInclude := true
        } else if (SearchCenterFilterType = "clipboard") {
            ; 严格过滤：仅显示剪贴板来源
            ShouldInclude := (res.HasProp("OriginalDataType") && res.OriginalDataType = "clipboard") || (res.HasProp("Source") && InStr(res.Source, "剪贴板") > 0)
        } else if (SearchCenterFilterType = "template") {
            ; 严格过滤：仅显示模板/提示词来源
            ShouldInclude := (res.HasProp("OriginalDataType") && res.OriginalDataType = "template") || (res.HasProp("Source") && (InStr(res.Source, "模板") > 0 || InStr(res.Source, "提示词") > 0))
        } else if (SearchCenterFilterType = "config") {
            ; 严格过滤：仅显示配置来源
            ShouldInclude := (res.HasProp("OriginalDataType") && res.OriginalDataType = "config") || (res.HasProp("Source") && InStr(res.Source, "配置") > 0)
        } else if (SearchCenterFilterType = "hotkey") {
            ; 严格过滤：仅显示快捷键来源
            ShouldInclude := (res.HasProp("OriginalDataType") && res.OriginalDataType = "hotkey") || (res.HasProp("Source") && InStr(res.Source, "快捷键") > 0)
        } else if (SearchCenterFilterType = "function") {
            ; 严格过滤：仅显示功能来源
            ShouldInclude := (res.HasProp("OriginalDataType") && res.OriginalDataType = "function") || (res.HasProp("Source") && InStr(res.Source, "功能") > 0)
        } else if (SearchCenterFilterType = "File") {
            ; 文件：检查OriginalDataType是否为file，或DataType为File，或Source包含"文件"
            ShouldInclude := (res.HasProp("OriginalDataType") && res.OriginalDataType = "file") || (res.HasProp("DataType") && res.DataType = "File") || (res.HasProp("Source") && InStr(res.Source, "文件") > 0)
        }
        
        if (ShouldInclude) {
            FilteredResults.Push(res)
        }
    }
    
    ; 添加过滤后的结果到ListView（第 1 列图标，第 2 列起为标题/来源/类型/时间）
    for index, res in FilteredResults {
        ContentType := res.HasProp("DataType") ? res.DataType : "Text"
        TypeDisplayName := GetContentTypeDisplayName(ContentType)
        if (res.HasProp("OriginalDataType") && res.OriginalDataType = "file" && res.HasProp("Category") && res.Category != "")
            try TypeDisplayName := FileClassifier.GetCategoryDisplayName(res.Category)
        iconOpt := ""
        try {
            if (ShellIcon_EnsureImageList(SearchCenterResultLV, "sc"))
                iconOpt := "Icon" . ShellIcon_GetPlaceholderIndex("sc")
        } catch {
        }
        rowTitle := (res.HasProp("DisplayTitle") && res.DisplayTitle != "") ? res.DisplayTitle : res.Title
        rowSubtitle := (res.HasProp("DisplaySubtitle") && res.DisplaySubtitle != "") ? res.DisplaySubtitle : res.Source
        if (iconOpt != "")
            SearchCenterResultLV.Add(iconOpt, "", rowTitle, rowSubtitle, TypeDisplayName, res.Time)
        else
            SearchCenterResultLV.Add("", "", rowTitle, rowSubtitle, TypeDisplayName, res.Time)
    }
    
    SearchCenterVisibleResults := FilteredResults
    SearchCenterResultLV.ModifyCol(1, 36)
    SearchCenterResultLV.ModifyCol(2, "AutoHdr")
    SearchCenterResultLV.ModifyCol(3, "AutoHdr")
    SearchCenterResultLV.ModifyCol(4, "AutoHdr")
    SearchCenterResultLV.ModifyCol(5, "AutoHdr")
    try UpdateIcons(SearchCenterVisibleResults, SearchCenterVisibleResults.Length, SearchCenterResultLV, "sc")
    SearchCenterResultLV.Opt("+Redraw")
    if (SearchCenterResultLV.GetCount() > 0) {
        SearchCenterResultLV.Modify(1, "Select Focus Vis")
        UpdateSearchCenterCLIPreview(1)
    } else {
        UpdateSearchCenterCLIPreview(0)
    }
    
    ; 【关键修复】刷新结果显示后，更新标签按钮样式以保持选中状态
    UpdateSearchCenterFilterButtons()
    } catch as err {
        OutputDebug("AHK_DEBUG: RefreshSearchCenterResults: " . err.Message)
    }
}


; 搜索中心搜索结果双击事件
OnSearchCenterResultDoubleClick(LV, Row) {
    global SearchCenterVisibleResults

    if (Row > 0 && Row <= SearchCenterVisibleResults.Length) {
        Item := GetSearchCenterResultItemByRow(Row)
        if (!IsObject(Item)) {
            return
        }
        Content := Item.HasProp("Content") ? Item.Content : Item.Title
        
        ; 检查数据类型（优先检查 DataType 字段，然后检查 Metadata）
        DataType := ""
        if (Item.HasProp("DataType") && Item.DataType != "") {
            DataType := Item.DataType
        } else if (Item.HasProp("Metadata") && IsObject(Item.Metadata) && Item.Metadata.Has("DataType")) {
            DataType := Item.Metadata["DataType"]
        }
        
        ; 根据类型执行不同操作（搜索中心扁平化后 DataType 可能为 File/Folder 或 OriginalDataType=file）
        origDt := Item.HasProp("OriginalDataType") ? Item.OriginalDataType : ""
        isFileLike := (DataType = "file" || DataType = "File" || DataType = "Folder" || origDt = "file")
        if (isFileLike) {
            ; 文件类型：打开文件或文件夹
            FilePath := Content
            try {
                if (FileExist(FilePath) || DirExist(FilePath)) {
                    Run(FilePath)
                    TrayTip("已打开", Item.Title, "Iconi 1")
                } else {
                    TrayTip("路径不存在", FilePath, "Iconx 2")
                }
            } catch as err {
                TrayTip("打开失败", err.Message, "Iconx 2")
            }
        } else if (DataType = "Link") {
            ; 链接类型：直接打开浏览器
            try {
                Run(Content)
                TrayTip("已打开链接", Content, "Iconi 1")
            } catch as err {
                TrayTip("打开链接失败", err.Message, "Iconx 2")
            }
        } else if (DataType = "Image") {
            ; 图片类型：使用系统查看器打开
            try {
                if (FileExist(Content)) {
                    Run(Content)
                    TrayTip("已打开图片", Content, "Iconi 1")
                } else {
                    TrayTip("图片文件不存在", Content, "Iconx 2")
                }
            } catch as err {
                TrayTip("打开图片失败", err.Message, "Iconx 2")
            }
        } else {
            ; 其他类型：复制内容到剪贴板并粘贴
            A_Clipboard := Content
            Sleep(50)
            Send("^v")  ; Ctrl+V 粘贴
            TrayTip("已粘贴", Item.Title, "Iconi 1")
        }
    }
}

; ===================== SearchCenter 窗口大小改变事件 =====================
OnSearchCenterSize(GuiObj, MinMax, Width, Height) {
    global GuiID_SearchCenter, SearchCenterResultLV, SearchCenterSearchEdit
    global SearchCenterAreaIndicator, SearchCenterHintText, SearchCenterResultLimitDropdown
    global SearchCenterFilterButtons
    global SearchCenterCLIOutputEdit
    global SearchCenterCLIRunButton, SearchCenterCLIClearButton, SearchCenterCLIOpenButton

    if (GuiID_SearchCenter = 0 || GuiObj.Hwnd != GuiID_SearchCenter.Hwnd) {
        return
    }
    
    ; 如果窗口正在最小化，不进行调整
    if (MinMax = -1) {
        return
    }
    
    ; 常量定义（与 ShowSearchCenter 中保持一致）
    Padding := 20
    DropdownWidth := 120
    AreaIndicatorHeight := 25
    HintTextHeight := 40
    SearchEditHeight := 50
    FilterBarHeight := 40  ; 【新增】过滤标签按钮区域高度
    
    ; 计算搜索输入框的新宽度
    SearchEditWidth := Width - Padding * 2 - DropdownWidth - 10
    
    ; 调整搜索输入框宽度（保持 X 坐标和 Y 坐标不变，只改变宽度）
    if (SearchCenterSearchEdit != 0) {
        try {
            ControlGetPos(&CurrentX, &CurrentY, &CurrentW, &CurrentH, SearchCenterSearchEdit)
            SearchCenterSearchEdit.Move(CurrentX, CurrentY, SearchEditWidth, SearchEditHeight)
        } catch as err {
            ; 忽略错误
        }
    }
    
    ; 调整区域指示器宽度（保持 X 坐标和 Y 坐标不变，只改变宽度）
    if (SearchCenterAreaIndicator != 0) {
        try {
            ControlGetPos(&CurrentX, &CurrentY, &CurrentW, &CurrentH, SearchCenterAreaIndicator)
            SearchCenterAreaIndicator.Move(CurrentX, CurrentY, SearchEditWidth, CurrentH)
        } catch as err {
            ; 忽略错误
        }
    }
    
    ; 调整提示文本宽度（保持 X 坐标和 Y 坐标不变，只改变宽度）
    if (SearchCenterHintText != 0) {
        try {
            ControlGetPos(&CurrentX, &CurrentY, &CurrentW, &CurrentH, SearchCenterHintText)
            SearchCenterHintText.Move(CurrentX, CurrentY, SearchEditWidth, CurrentH)
        } catch as err {
            ; 忽略错误
        }
    }
    
    static InLayout := false
    if (InLayout) {
        return
    }
    InLayout := true
    
    try {
        if (SearchCenterResultLV != 0) {
            SearchCenterResultLV.Opt("-Redraw")
        }
        
        ; 缩放过程只做必要重排，避免每帧置顶导致抖动
        UpdateSearchCenterCLILayout(Width, Height, false)
    if (SearchCenterResultLV != 0) {
        try {
            innerW := Width - Padding * 2
            SearchCenterResultLV.ModifyCol(1, 36)
            restW := innerW - 36
            SearchCenterResultLV.ModifyCol(2, restW * 0.4)
            SearchCenterResultLV.ModifyCol(3, restW * 0.2)
            SearchCenterResultLV.ModifyCol(4, restW * 0.15)
            SearchCenterResultLV.ModifyCol(5, restW * 0.25)
        } catch as err {
        }
    }
    } finally {
        if (SearchCenterResultLV != 0) {
            try SearchCenterResultLV.Opt("+Redraw")
        }
        InLayout := false
    }
}

; 搜索中心 Enter 键处理函数（检查窗口是否激活）
; 搜索中心窗口关闭处理函数
SearchCenterCloseHandler(*) {
    global GuiID_SearchCenter, SearchCenterSelectedEngines, SearchCenterSelectedEnginesByCategory, SearchCenterCurrentCategory
    ; 【关键修复】在关闭窗口前保存当前分类的选择状态
    try {
        Categories := GetSearchCenterCategories()
        if (Categories.Length > 0 && SearchCenterCurrentCategory >= 0 && SearchCenterCurrentCategory < Categories.Length) {
            CurrentCategory := Categories[SearchCenterCurrentCategory + 1]
            CategoryKey := CurrentCategory.Key
            if (IsSet(SearchCenterSelectedEngines) && IsObject(SearchCenterSelectedEngines)) {
                ; 保存到内存Map
                if (!IsSet(SearchCenterSelectedEnginesByCategory) || !IsObject(SearchCenterSelectedEnginesByCategory)) {
                    SearchCenterSelectedEnginesByCategory := Map()
                }
                CurrentEngines := []
                for Index, Engine in SearchCenterSelectedEngines {
                    CurrentEngines.Push(Engine)
                }
                SearchCenterSelectedEnginesByCategory[CategoryKey] := CurrentEngines
                
                ; 保存到配置文件
                global ConfigFile
                EnginesStr := ""
                for Index, Eng in SearchCenterSelectedEngines {
                    if (Index > 1) {
                        EnginesStr .= ","
                    }
                    EnginesStr .= Eng
                }
                ; 保存格式：分类:引擎1,引擎2
                CategoryEnginesStr := CategoryKey . ":" . EnginesStr
                IniWrite(CategoryEnginesStr, ConfigFile, "Settings", "SearchCenterSelectedEngines_" . CategoryKey)
            }
        }
    } catch as err {
        ; 忽略保存错误，不影响关闭窗口
    }
    
    ; 注意：Enter和ESC键热键使用#HotIf自动管理，无需手动取消注册
    ; 销毁窗口
    if (GuiID_SearchCenter) {
        try {
            CleanupSearchCenterResultLimitDDLBrush()
            GuiID_SearchCenter.Destroy()
        } catch as err {
            ; 忽略错误
        }
        GuiID_SearchCenter := 0
        SearchCenterInvalidateGuiControlRefs()
    }
}

; 执行搜索中心批量搜索（按Enter键时）
ExecuteSearchCenterBatchSearch(*) {
    global SearchCenterSearchEdit, SearchCenterSelectedEngines, GuiID_SearchCenter
    global GlobalSearchStatement, SearchCenterDebounceTimer
    
    if (SearchCenterIsCLICategory()) {
        ExecuteSearchCenterCLICommand()
        return
    }
    
    ; 【并发同步】第一行代码：强制释放 Statement 句柄
    GlobalSearchEngine.ReleaseOldStatement()
    
    ; 取消搜索中心防抖定时器
    if (SearchCenterDebounceTimer != 0) {
        SetTimer(SearchCenterDebounceTimer, 0)
        SearchCenterDebounceTimer := 0
    }
    
    ; 窗口已销毁或 Invalidate 后引用为 0 时，热键/定时器仍可能晚到，避免对 Integer 取 .Value
    if (!GuiID_SearchCenter || GuiID_SearchCenter = 0 || !IsObject(SearchCenterSearchEdit)) {
        return
    }
    
    ; 获取搜索关键词
    Keyword := SearchCenterSearchEdit.Value
    if (StrLen(Keyword) < 1) {
        TrayTip("请输入搜索关键词", "提示", "Icon! 2")
        return
    }
    
    ; 检查是否有选中的搜索引擎
    if (!IsSet(SearchCenterSelectedEngines) || !IsObject(SearchCenterSelectedEngines) || SearchCenterSelectedEngines.Length = 0) {
        TrayTip("请至少选择一个搜索引擎", "提示", "Icon! 2")
        return
    }
    
    ; 打开所有选中的搜索引擎
    for Index, Engine in SearchCenterSelectedEngines {
        if (!IsSet(Engine) || Engine = "") {
            continue  ; 跳过无效的引擎
        }
        SendVoiceSearchToBrowser(Keyword, Engine)
        ; 每个搜索引擎之间稍作延迟，避免同时打开太多窗口
        if (Index < SearchCenterSelectedEngines.Length) {
            Sleep(300)
        }
    }
    
    TrayTip("已打开 " . SearchCenterSelectedEngines.Length . " 个搜索引擎", "提示", "Iconi 1")
    
    ; 可选：关闭搜索中心窗口
    ; if (GuiID_SearchCenter != 0) {
    ;     try {
    ;         GuiID_SearchCenter.Destroy()
    ;     } catch as err {
    ;     }
    ; }
}

; 刷新搜索中心搜索引擎图标显示
RefreshSearchCenterEngineIcons() {
    global GuiID_SearchCenter, SearchCenterCurrentCategory, SearchCenterEngineIcons, UI_Colors
    global SearchCenterSelectedEngines, SearchCenterSelectedEnginesByCategory
    
    ; 如果窗口不存在，直接返回
    if (!GuiID_SearchCenter || GuiID_SearchCenter = 0) {
        return
    }
    
    ; 【关键修复】参考capslock+f的实现：先隐藏旧图标，创建新图标后再销毁旧图标，避免闪烁
    if (IsSet(SearchCenterEngineIcons) && IsObject(SearchCenterEngineIcons)) {
        ; 先隐藏所有旧图标控件（不立即销毁，保持界面流畅）
        for Index, IconObj in SearchCenterEngineIcons {
            if (IsObject(IconObj)) {
                try {
                    if (IconObj.HasProp("Icon") && IconObj.Icon != 0) {
                        IconObj.Icon.Visible := false
                    }
                    if (IconObj.HasProp("NameLabel") && IconObj.NameLabel != 0) {
                        IconObj.NameLabel.Visible := false
                    }
                    if (IconObj.HasProp("Bg") && IconObj.Bg != 0) {
                        IconObj.Bg.Visible := false
                    }
                    if (IconObj.HasProp("Check") && IconObj.Check != 0) {
                        IconObj.Check.Visible := false
                    }
                } catch as err {
                    ; 忽略隐藏错误
                }
            }
        }
    }
    
    ; 保存旧图标数组用于后续销毁
    OldIcons := SearchCenterEngineIcons
    ; 清空图标数组，准备创建新图标
    SearchCenterEngineIcons := []
    
    ; 获取当前分类
    Categories := GetSearchCenterCategories()
    if (Categories.Length = 0 || SearchCenterCurrentCategory < 0 || SearchCenterCurrentCategory >= Categories.Length) {
        return
    }
    
    CurrentCategory := Categories[SearchCenterCurrentCategory + 1]
    CategoryKey := CurrentCategory.Key
    
    ; 【关键修复】恢复当前分类的搜索引擎选择状态（参考CAPSLOCK+F的实现）
    if (!IsSet(SearchCenterSelectedEnginesByCategory) || !IsObject(SearchCenterSelectedEnginesByCategory)) {
        SearchCenterSelectedEnginesByCategory := Map()
    }
    
    if (SearchCenterSelectedEnginesByCategory.Has(CategoryKey)) {
        SearchCenterSelectedEngines := []
        for Index, Engine in SearchCenterSelectedEnginesByCategory[CategoryKey] {
            SearchCenterSelectedEngines.Push(Engine)
        }
    } else {
        ; 如果内存中没有，尝试从配置文件加载
        try {
            global ConfigFile
            CategoryEnginesStr := IniRead(ConfigFile, "Settings", "SearchCenterSelectedEngines_" . CategoryKey, "")
            if (CategoryEnginesStr != "") {
                ; 解析格式：分类:引擎1,引擎2
                if (InStr(CategoryEnginesStr, ":") > 0) {
                    EnginesStr := SubStr(CategoryEnginesStr, InStr(CategoryEnginesStr, ":") + 1)
                } else {
                    EnginesStr := CategoryEnginesStr
                }
                if (EnginesStr != "") {
                    SearchCenterSelectedEngines := []
                    EnginesArray := StrSplit(EnginesStr, ",")
                    for Index, Engine in EnginesArray {
                        Engine := Trim(Engine)
                        if (Engine != "") {
                            SearchCenterSelectedEngines.Push(Engine)
                        }
                    }
                    ; 保存到内存Map中
                    CurrentEngines := []
                    for Index, Engine in SearchCenterSelectedEngines {
                        CurrentEngines.Push(Engine)
                    }
                    SearchCenterSelectedEnginesByCategory[CategoryKey] := CurrentEngines
                } else {
                    SearchCenterSelectedEngines := []
                }
            } else {
                ; 如果该分类没有保存的选择状态，初始化为空数组，让用户自己选择（支持多选）
                SearchCenterSelectedEngines := (CategoryKey = "cli") ? ["codex_cli"] : []
            }
        } catch as err {
            ; 如果加载失败，初始化为空数组
            SearchCenterSelectedEngines := (CategoryKey = "cli") ? ["codex_cli"] : []
        }
    }
    
    ; 获取当前分类的搜索引擎列表
    SearchEngines := GetSortedSearchEngines(CategoryKey)
    if (!IsObject(SearchEngines) || SearchEngines.Length = 0) {
        return
    }
    
    ; 计算图标位置参数（与 ShowSearchCenter 中的布局保持一致）
    Padding := 20
    CategoryBarY := Padding
    CategoryBarHeight := 50
    EngineIconRowY := CategoryBarY + CategoryBarHeight + 5
    EngineIconRowHeight := 70  ; 增加高度以容纳图标下方的名称标签（50图标 + 2间距 + 16名称 = 68，留2像素余量）
    EngineIconSize := 40
    EngineIconSpacing := 15
    EngineIconStartX := Padding
    IconButtonSize := 50  ; 图标按钮的总大小（包括边框）
    
    ; 创建搜索引擎图标
    CurrentX := EngineIconStartX
    for Index, Engine in SearchEngines {
        if (!IsObject(Engine) || !Engine.HasProp("Value")) {
            continue
        }
        
        ; 检查是否选中
        IsSelected := (ArrayContainsValue(SearchCenterSelectedEngines, Engine.Value) > 0)
        
        ; 获取图标路径
        IconPath := GetSearchEngineIcon(Engine.Value)
        
        ; 计算图标按钮位置
        IconButtonX := CurrentX
        IconButtonY := EngineIconRowY + (EngineIconRowHeight - IconButtonSize) // 2
        
        ; 创建背景按钮（用于点击区域和选中状态显示）
        BgColor := IsSelected ? UI_Colors.BtnHover : UI_Colors.BtnBg
        BgBtn := GuiID_SearchCenter.Add("Text", "x" . IconButtonX . " y" . IconButtonY . " w" . IconButtonSize . " h" . IconButtonSize . " Center 0x200 Background" . BgColor, "")
        BgBtn.OnEvent("Click", CreateSearchCenterEngineClickHandler(Engine.Value, Index))
        HoverBtn(BgBtn, BgColor, UI_Colors.BtnHover)
        
        IconCtrl := 0
        CheckMark := 0
        NameLabel := 0
        
        if (IconPath != "" && FileExist(IconPath)) {
            try {
                ; 计算图标显示尺寸
                ImageSize := GetImageSize(IconPath)
                DisplaySize := CalculateImageDisplaySize(ImageSize.Width, ImageSize.Height, EngineIconSize, EngineIconSize)
                
                ; 计算图标位置（在按钮中居中）
                IconX := IconButtonX + (IconButtonSize - DisplaySize.Width) // 2
                IconY := IconButtonY + (IconButtonSize - DisplaySize.Height) // 2
                
                ; 创建图标控件
                IconCtrl := GuiID_SearchCenter.Add("Picture", "x" . IconX . " y" . IconY . " w" . DisplaySize.Width . " h" . DisplaySize.Height . " 0x200", IconPath)
                IconCtrl.OnEvent("Click", CreateSearchCenterEngineClickHandler(Engine.Value, Index))
                
                ; 如果选中，显示选中标记
                if (IsSelected) {
                    CheckX := IconButtonX + IconButtonSize - 18
                    CheckY := IconButtonY + 2
                    CheckMark := GuiID_SearchCenter.Add("Text", "x" . CheckX . " y" . CheckY . " w16 h16 Center 0x200 cFFFFFF Background" . UI_Colors.BtnPrimary, "✓")
                    CheckMark.SetFont("s12 Bold", "Segoe UI")
                    CheckMark.OnEvent("Click", CreateSearchCenterEngineClickHandler(Engine.Value, Index))
                }
            } catch as e {
                OutputDebug("创建搜索引擎图标失败: " . Engine.Value . " - " . e.Message)
                ; 如果图标创建失败，使用文字显示
                IconPath := ""
            }
        }
        
        ; 如果图标不存在，显示搜索引擎名称（在图标下方）
        if (IconPath = "" || !FileExist(IconPath)) {
            try {
                ; 获取搜索引擎名称
                EngineName := Engine.HasProp("Name") ? Engine.Name : Engine.Value
                
                ; 创建文字标签（显示在图标按钮下方，而不是中间）
                NameLabelY := IconButtonY + IconButtonSize + 2  ; 图标下方2像素
                NameLabelHeight := 16  ; 名称标签高度
                NameLabel := GuiID_SearchCenter.Add("Text", "x" . IconButtonX . " y" . NameLabelY . " w" . IconButtonSize . " h" . NameLabelHeight . " Center 0x200 c" . UI_Colors.Text . " BackgroundTrans", EngineName)
                NameLabel.SetFont("s8", "Segoe UI")
                NameLabel.OnEvent("Click", CreateSearchCenterEngineClickHandler(Engine.Value, Index))
                
                ; 如果选中，显示选中标记
                if (IsSelected) {
                    CheckX := IconButtonX + IconButtonSize - 18
                    CheckY := IconButtonY + 2
                    CheckMark := GuiID_SearchCenter.Add("Text", "x" . CheckX . " y" . CheckY . " w16 h16 Center 0x200 cFFFFFF Background" . UI_Colors.BtnPrimary, "✓")
                    CheckMark.SetFont("s12 Bold", "Segoe UI")
                    CheckMark.OnEvent("Click", CreateSearchCenterEngineClickHandler(Engine.Value, Index))
                }
            } catch as e {
                OutputDebug("创建搜索引擎名称标签失败: " . Engine.Value . " - " . e.Message)
            }
        } else {
            ; 即使有图标，也在图标下方显示名称
            try {
                ; 获取搜索引擎名称
                EngineName := Engine.HasProp("Name") ? Engine.Name : Engine.Value
                
                ; 创建文字标签（显示在图标按钮下方）
                NameLabelY := IconButtonY + IconButtonSize + 2  ; 图标下方2像素
                NameLabelHeight := 16  ; 名称标签高度
                NameLabel := GuiID_SearchCenter.Add("Text", "x" . IconButtonX . " y" . NameLabelY . " w" . IconButtonSize . " h" . NameLabelHeight . " Center 0x200 c" . UI_Colors.Text . " BackgroundTrans", EngineName)
                NameLabel.SetFont("s8", "Segoe UI")
                NameLabel.OnEvent("Click", CreateSearchCenterEngineClickHandler(Engine.Value, Index))
            } catch as e {
                OutputDebug("创建搜索引擎名称标签失败: " . Engine.Value . " - " . e.Message)
            }
        }
        
        ; 保存图标对象（包括名称标签）
        SearchCenterEngineIcons.Push({Bg: BgBtn, Icon: IconCtrl, NameLabel: NameLabel, Check: CheckMark, Engine: Engine.Value, Index: Index})
        
        ; 更新下一个图标的位置
        CurrentX += IconButtonSize + EngineIconSpacing
    }
    
    ; 【关键修复】刷新GUI显示，确保新图标立即显示
    try {
        if (GuiID_SearchCenter && IsObject(GuiID_SearchCenter) && GuiID_SearchCenter.HasProp("Hwnd")) {
            WinRedraw(GuiID_SearchCenter.Hwnd)
        }
    } catch as err {
        ; 忽略刷新错误
    }
    
    ; 【关键修复】延迟销毁旧图标，确保新图标已显示后再清理，提升流畅度并避免名称叠加
    SetTimer(() => DestroyOldSearchCenterIcons(OldIcons), -100)
}

; 销毁旧的搜索中心图标（延迟执行，提升流畅度）
DestroyOldSearchCenterIcons(OldIcons) {
    if (!IsSet(OldIcons) || !IsObject(OldIcons)) {
        return
    }
    
    for Index, IconObj in OldIcons {
        if (IsObject(IconObj)) {
            try {
                if (IconObj.HasProp("Icon") && IconObj.Icon != 0) {
                    IconObj.Icon.Destroy()
                }
                if (IconObj.HasProp("NameLabel") && IconObj.NameLabel != 0) {
                    IconObj.NameLabel.Destroy()
                }
                if (IconObj.HasProp("Bg") && IconObj.Bg != 0) {
                    IconObj.Bg.Destroy()
                }
                if (IconObj.HasProp("Check") && IconObj.Check != 0) {
                    IconObj.Check.Destroy()
                }
            } catch as err {
                ; 忽略销毁错误
            }
        }
    }
}

; 创建搜索中心搜索引擎点击处理函数
CreateSearchCenterEngineClickHandler(EngineValue, Index) {
    return (*) => ToggleSearchCenterEngine(EngineValue, Index)
}

; 切换搜索中心搜索引擎选择状态
ToggleSearchCenterEngine(EngineValue, Index) {
    global SearchCenterSelectedEngines, SearchCenterSelectedEnginesByCategory, SearchCenterCurrentCategory
    global SearchCenterEngineIcons, UI_Colors, GuiID_SearchCenter
    
    ; 确保数组已初始化
    if (!IsSet(SearchCenterSelectedEngines) || !IsObject(SearchCenterSelectedEngines)) {
        SearchCenterSelectedEngines := []
    }
    
    ; 确保Map已初始化
    if (!IsSet(SearchCenterSelectedEnginesByCategory) || !IsObject(SearchCenterSelectedEnginesByCategory)) {
        SearchCenterSelectedEnginesByCategory := Map()
    }
    
    ; 获取当前分类
    Categories := GetSearchCenterCategories()
    if (Categories.Length = 0 || SearchCenterCurrentCategory < 0 || SearchCenterCurrentCategory >= Categories.Length) {
        return
    }
    CurrentCategory := Categories[SearchCenterCurrentCategory + 1]
    CategoryKey := CurrentCategory.Key
    
    ; 切换选中状态
    FoundIndex := ArrayContainsValue(SearchCenterSelectedEngines, EngineValue)
    IsSelected := (FoundIndex = 0)  ; 如果没找到，说明要选中
    
    if (CategoryKey = "cli") {
        ; CLI 终端只能发往一个：多选会导致 codex 在 Native 队列里先于 qwen 打开，用户只选 Qwen 时仍会激活 Codex
        if (FoundIndex > 0) {
            SearchCenterSelectedEngines.RemoveAt(FoundIndex)
        } else {
            SearchCenterSelectedEngines := [EngineValue]
        }
    } else if (FoundIndex > 0) {
        ; 取消选中
        SearchCenterSelectedEngines.RemoveAt(FoundIndex)
    } else {
        ; 选中（支持多选）
        SearchCenterSelectedEngines.Push(EngineValue)
    }
    
    ; 保存到分类Map
    CurrentEngines := []
    for Index, Eng in SearchCenterSelectedEngines {
        CurrentEngines.Push(Eng)
    }
    SearchCenterSelectedEnginesByCategory[CategoryKey] := CurrentEngines
    
    ; 【关键修复】参考CAPSLOCK+F的实现：保存到配置文件（持久化记忆用户选择）
    try {
        global ConfigFile
        EnginesStr := ""
        for Index, Eng in SearchCenterSelectedEngines {
            if (Index > 1) {
                EnginesStr .= ","
            }
            EnginesStr .= Eng
        }
        ; 保存格式：分类:引擎1,引擎2
        CategoryEnginesStr := CategoryKey . ":" . EnginesStr
        IniWrite(CategoryEnginesStr, ConfigFile, "Settings", "SearchCenterSelectedEngines_" . CategoryKey)
    } catch as e {
        ; 忽略保存错误，不影响功能
    }
    
    ; CLI 单选后必须重绘全部图标，否则其它 CLI 的勾号仍会残留
    if (CategoryKey = "cli") {
        RefreshSearchCenterEngineIcons()
        return
    }
    
    ; 【优化】只更新当前图标的选中状态，避免重新创建所有图标导致闪烁
    if (IsSet(SearchCenterEngineIcons) && IsObject(SearchCenterEngineIcons)) {
        ; 找到对应的图标对象
        for IconIndex, IconObj in SearchCenterEngineIcons {
            if (IsObject(IconObj) && IconObj.HasProp("Engine") && IconObj.Engine = EngineValue) {
                ; 更新背景按钮颜色
                if (IconObj.HasProp("Bg") && IconObj.Bg != 0) {
                    try {
                        NewBgColor := IsSelected ? UI_Colors.BtnHover : UI_Colors.BtnBg
                        IconObj.Bg.Opt("+Background" . NewBgColor)
                        IconObj.Bg.Redraw()
                    } catch as err {
                        ; 如果更新失败，使用完整刷新
                        RefreshSearchCenterEngineIcons()
                        return
                    }
                }
                
                ; 更新选中标记
                if (IsSelected) {
                    ; 需要显示选中标记
                    if (!IconObj.HasProp("Check") || IconObj.Check = 0) {
                        ; 创建选中标记
                        try {
                            IconButtonX := 0
                            IconButtonY := 0
                            IconButtonSize := 50
                            ; 从背景按钮获取位置
                            if (IconObj.HasProp("Bg") && IconObj.Bg != 0) {
                                IconObj.Bg.GetPos(&IconButtonX, &IconButtonY, &IconButtonSize, &IconButtonSize)
                            }
                            CheckX := IconButtonX + IconButtonSize - 18
                            CheckY := IconButtonY + 2
                            CheckMark := GuiID_SearchCenter.Add("Text", "x" . CheckX . " y" . CheckY . " w16 h16 Center 0x200 cFFFFFF Background" . UI_Colors.BtnPrimary, "✓")
                            CheckMark.SetFont("s12 Bold", "Segoe UI")
                            CheckMark.OnEvent("Click", CreateSearchCenterEngineClickHandler(EngineValue, Index))
                            IconObj.Check := CheckMark
                        } catch as err {
                            ; 如果创建失败，使用完整刷新
                            RefreshSearchCenterEngineIcons()
                            return
                        }
                    }
                } else {
                    ; 需要隐藏选中标记
                    if (IconObj.HasProp("Check") && IconObj.Check != 0) {
                        try {
                            IconObj.Check.Destroy()
                            IconObj.Check := 0
                        } catch as err {
                            ; 如果销毁失败，使用完整刷新
                            RefreshSearchCenterEngineIcons()
                            return
                        }
                    }
                }
                ; 找到并更新后退出循环
                break
            }
        }
    } else {
        ; 如果图标数组不存在，使用完整刷新
        RefreshSearchCenterEngineIcons()
    }
}
