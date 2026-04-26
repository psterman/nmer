; LegacyClipboardListView.ahk — 原生 ListView 剪贴板管理器 GUI
; 由 CursorHelper 主脚本拆分；依赖主脚本全局变量与 OnWindowSize 等共用函数。

; ===================== 剪贴板管理面板 =====================

; 关闭剪贴板面板（辅助函数）
CloseClipboardManager(*) {
    global GuiID_ClipboardManager, ConfigFile, ClipboardListView, ClipboardCurrentTab
    global ClipboardListViewHwnd, ClipboardListViewHighlightedRow, ClipboardListViewHighlightedCol, ClipboardManagerHwnd
    try {
        if (GuiID_ClipboardManager != 0) {
            ; 保存窗口位置和大小
            try {
                WinGetPos(&WinX, &WinY, &WinWidth, &WinHeight, "ahk_id " . GuiID_ClipboardManager.Hwnd)
                IniWrite(WinWidth, ConfigFile, "Appearance", "ClipboardPanelWidth")
                IniWrite(WinHeight, ConfigFile, "Appearance", "ClipboardPanelHeight")
                IniWrite(WinX, ConfigFile, "Appearance", "ClipboardPanelX")
                IniWrite(WinY, ConfigFile, "Appearance", "ClipboardPanelY")
            } catch as err {
                ; 忽略保存错误
            }
            
            ; 保存ListView列宽（仅在CapsLockC标签时保存）
            try {
                if (ClipboardCurrentTab = "CapsLockC" && ClipboardListView && IsObject(ClipboardListView)) {
                    LV_Hwnd := ClipboardListView.Hwnd
                    if (LV_Hwnd) {
                        ColCount := ClipboardListView.GetCount("Col")
                        if (ColCount >= 1) {
                            ; 使用API获取第一列宽度
                            ; LVM_GETCOLUMNWIDTH = 0x101D
                            FirstColWidth := DllCall("SendMessage", "Ptr", LV_Hwnd, "UInt", 0x101D, "Ptr", 0, "Ptr", 0, "Int")
                            if (FirstColWidth > 0 && FirstColWidth < 1000) {
                                IniWrite(FirstColWidth, ConfigFile, "ClipboardListView", "FirstColWidth")
                            }
                            
                            ; 保存内容列宽度（使用第二列的宽度作为参考）
                            if (ColCount >= 2) {
                                ContentColWidth := DllCall("SendMessage", "Ptr", LV_Hwnd, "UInt", 0x101D, "Ptr", 1, "Ptr", 0, "Int")
                                if (ContentColWidth > 0 && ContentColWidth < 1000) {
                                    IniWrite(ContentColWidth, ConfigFile, "ClipboardListView", "ContentColWidth")
                                }
                            }
                        }
                    }
                }
            } catch as err {
                ; 忽略保存列宽错误
            }
            
            SafeHideLegacyClipboardManager()
        }
        
        ; 仅在实际 Destroy 后清理控件 HWND；Hide 保留实例时控件仍有效
        if (GuiID_ClipboardManager = 0) {
            ClipboardListViewHwnd := 0
            ClipboardListViewHighlightedRow := 0
            ClipboardListViewHighlightedCol := 0
            ClipboardManagerHwnd := 0
        }
        
        ; 销毁高亮覆盖层
        DestroyClipboardHighlightOverlay()
    } catch as err {
        ; 确保清理状态，即使出错也要清理
        ClipboardListViewHwnd := 0
        ClipboardListViewHighlightedRow := 0
        ClipboardListViewHighlightedCol := 0
        ClipboardManagerHwnd := 0
        
        ; 销毁高亮覆盖层
        DestroyClipboardHighlightOverlay()
    }
}

ShowClipboardManager() {
    global ClipboardHistory, GuiID_ClipboardManager, ClipboardPanelScreenIndex, ClipboardPanelPos
    global UI_Colors, GuiID_ConfigGUI, ClipboardCurrentTab, ClipboardManagerHwnd
    
    ; 若已有隐藏实例则直接显示，避免无谓 Destroy 与重建
    if (GuiID_ClipboardManager != 0 && IsObject(GuiID_ClipboardManager) && GuiID_ClipboardManager.HasProp("Hwnd") && WinExist("ahk_id " . GuiID_ClipboardManager.Hwnd)) {
        if (GuiID_ConfigGUI != 0) {
            try {
                GuiID_ConfigGUI.Destroy()
                GuiID_ConfigGUI := 0
            } catch as err {
                GuiID_ConfigGUI := 0
            }
        }
        DefaultWidth := 800
        DefaultHeight := 600
        WindowName := "📋 " . GetText("clipboard_manager")
        RestoredPos := RestoreWindowPosition(WindowName, DefaultWidth, DefaultHeight)
        if (RestoredPos.X = -1 || RestoredPos.Y = -1) {
            ScreenInfo := GetScreenInfo(ClipboardPanelScreenIndex)
            Pos := GetPanelPosition(ScreenInfo, RestoredPos.Width, RestoredPos.Height, ClipboardPanelPos)
            RestoredPos.X := Pos.X
            RestoredPos.Y := Pos.Y
        }
        GuiID_ClipboardManager.Show("w" . RestoredPos.Width . " h" . RestoredPos.Height . " x" . RestoredPos.X . " y" . RestoredPos.Y)
        ClipboardManagerHwnd := GuiID_ClipboardManager.Hwnd
        if (ClipboardCurrentTab = "CapsLockC")
            SetTimer(() => CreateClipboardHighlightOverlay(), -50)
        WinSetAlwaysOnTop(1, GuiID_ClipboardManager.Hwnd)
        WinActivate(GuiID_ClipboardManager.Hwnd)
        Sleep(100)
        SetTimer(RefreshClipboardListAfterShow, -150)
        return
    }
    if (GuiID_ClipboardManager != 0) {
        try GuiID_ClipboardManager.Destroy()
        catch as e {
        }
        GuiID_ClipboardManager := 0
    }
    
    ; 关闭配置面板（确保一次只激活一个面板）
    if (GuiID_ConfigGUI != 0) {
        try {
            GuiID_ConfigGUI.Destroy()
            GuiID_ConfigGUI := 0
        } catch as err {
            GuiID_ConfigGUI := 0
        }
    }
    
    ; 面板尺寸（增大默认尺寸，避免按钮重叠）
    ; 使用通用函数恢复窗口位置和大小
    DefaultWidth := 800
    DefaultHeight := 600
    WindowName := "📋 " . GetText("clipboard_manager")
    RestoredPos := RestoreWindowPosition(WindowName, DefaultWidth, DefaultHeight)
    PanelWidth := RestoredPos.Width
    PanelHeight := RestoredPos.Height
    
    ; 创建可调整大小的 GUI（使用系统标题栏以支持调整大小）
    GuiID_ClipboardManager := Gui("+AlwaysOnTop +Resize -MaximizeBox -DPIScale", "📋 " . GetText("clipboard_manager"))
    GuiID_ClipboardManager.BackColor := UI_Colors.Background
    GuiID_ClipboardManager.SetFont("s11 c" . UI_Colors.Text, "Segoe UI")
    
    ; 添加窗口大小改变和移动事件处理
    GuiID_ClipboardManager.OnEvent("Size", OnWindowSize)
    ; 注意：AutoHotkey v2 不支持 Move 事件，使用定时器定期保存位置
    ; GuiID_ClipboardManager.OnEvent("Move", OnWindowMove)
    SetTimer(() => SaveClipboardManagerPosition(), 500)
    
    ; 工具栏区域（从 y=0 开始，系统标题栏会自动显示，内容区域从 y=30 开始）
    
    ; 分隔线
    SeparatorY := 30
    OuterShadowColor := (ThemeMode = "light") ? "E0E0E0" : "1A1A1A"
    InnerShadowColor := (ThemeMode = "light") ? "B0B0B0" : "2A2A2A"
    GuiID_ClipboardManager.Add("Text", "x0 y" . SeparatorY . " w" . PanelWidth . " h1 Background" . InnerShadowColor, "")
    
    ; ========== 工具栏区域 ==========
    ; 移除工具栏背景，让按钮直接显示在窗口背景上
    
    ; 辅助函数：创建平面按钮
    CreateFlatBtn(Parent, Label, X, Y, W, H, Action, Color := "", IsPrimary := false) {
        if (Color = "")
            Color := UI_Colors.BtnBg
        
        ; 按钮文字颜色：主要按钮使用白色，非主要按钮根据主题调整
        global ThemeMode
        TextColor := IsPrimary ? "FFFFFF" : (ThemeMode = "light" ? UI_Colors.Text : "FFFFFF")
            
        Btn := Parent.Add("Text", "x" . X . " y" . Y . " w" . W . " h" . H . " Center 0x200 c" . TextColor . " Background" . Color, Label)
        Btn.SetFont("s10", "Segoe UI")
        Btn.OnEvent("Click", Action)
        HoverBtn(Btn, Color, UI_Colors.BtnHover)
        return Btn
    }
    
    ; ========== 搜索功能区域（参考 ClipboardHistoryPanel，扩大加宽）==========
    ; 搜索框位置：在最上方
    SearchBoxY := 38  ; 调整Y坐标以适应系统标题栏
    SearchBoxHeight := 30  ; 参考 ClipboardHistoryPanel 的高度
    
    ; 下拉菜单（限制结果数量）
    DropdownX := 10
    DropdownY := SearchBoxY
    DropdownWidth := 100
    DropdownHeight := SearchBoxHeight
    DropdownDefaultIndex := 4  ; 默认选择50（索引从1开始，50是第4个选项）
    
    ClipboardManagementResultLimitDropdown := GuiID_ClipboardManager.Add("DropDownList",
        "x" . DropdownX . " y" . DropdownY .
        " w" . DropdownWidth . " h" . DropdownHeight .
        " R7" .  ; 显示 7 行，确保所有选项可见
        " Background" . UI_Colors.InputBg .
        " c" . UI_Colors.Text .
        " Choose" . DropdownDefaultIndex .
        " vClipboardManagementResultLimitDropdown",
        ["10", "20", "30", "50", "100", "200", "500"])
    
    ClipboardManagementResultLimitDropdown.SetFont("s11", "Segoe UI")
    ClipboardManagementResultLimitDropdown.OnEvent("Change", OnClipboardManagementResultLimitChange)
    
    ; 搜索框位置：下拉菜单右侧
    SearchBoxX := DropdownX + DropdownWidth + 10  ; 下拉菜单右侧，间距10
    SearchBoxWidth := PanelWidth - SearchBoxX - 20  ; 总宽度减去下拉菜单宽度和间距，自适应窗口宽度
    
    ; 添加搜索框背景板（参考 ClipboardHistoryPanel）
    SearchBoxBg := GuiID_ClipboardManager.Add("Text", 
        "x0 y" . (SearchBoxY - 5) . " w" . PanelWidth . " h" . (SearchBoxHeight + 10) . 
        " Background" . UI_Colors.Background . 
        " vClipboardSearchBoxBg", "")
    
    SearchEdit := GuiID_ClipboardManager.Add("Edit", 
        "x" . SearchBoxX . " y" . SearchBoxY . 
        " w" . SearchBoxWidth . " h" . SearchBoxHeight . 
        " Background" . UI_Colors.InputBg . 
        " c" . UI_Colors.Text . 
        " -VScroll -HScroll -Border" . 
        " vClipboardSearchEdit", "")
    SearchEdit.SetFont("s11", "Segoe UI")  ; 参考 ClipboardHistoryPanel 的字体大小
    SearchEdit.OnEvent("Change", OnClipboardSearchChange)
    
    ; 移除 Edit 控件的默认边框样式（参考 ClipboardHistoryPanel）
    SearchEditHwnd := SearchEdit.Hwnd
    try {
        CurrentExStyle := DllCall("GetWindowLongPtr", "Ptr", SearchEditHwnd, "Int", -20, "Ptr")
        NewExStyle := CurrentExStyle & ~0x00000200  ; 移除 WS_EX_CLIENTEDGE
        DllCall("SetWindowLongPtr", "Ptr", SearchEditHwnd, "Int", -20, "Ptr", NewExStyle, "Ptr")
    }
    
    ; 搜索跳转按钮（上下箭头，默认隐藏）
    SearchPrevBtn := GuiID_ClipboardManager.Add("Text", "x" . (SearchBoxX + SearchBoxWidth + 10) . " y" . SearchBoxY . " w25 h" . SearchBoxHeight . " Center 0x200 cFFFFFF Background" . UI_Colors.BtnBg . " vClipboardSearchPrevBtn", "▲")
    SearchPrevBtn.SetFont("s9", "Segoe UI")
    SearchPrevBtn.OnEvent("Click", OnClipboardSearchPrev)
    SearchPrevBtn.Visible := false
    HoverBtn(SearchPrevBtn, UI_Colors.BtnBg, UI_Colors.BtnHover)
    
    SearchNextBtn := GuiID_ClipboardManager.Add("Text", "x" . (SearchBoxX + SearchBoxWidth + 40) . " y" . SearchBoxY . " w25 h" . SearchBoxHeight . " Center 0x200 cFFFFFF Background" . UI_Colors.BtnBg . " vClipboardSearchNextBtn", "▼")
    SearchNextBtn.SetFont("s9", "Segoe UI")
    SearchNextBtn.OnEvent("Click", OnClipboardSearchNext)
    SearchNextBtn.Visible := false
    HoverBtn(SearchNextBtn, UI_Colors.BtnBg, UI_Colors.BtnHover)
    
    ; ========== 分类标签栏（在搜索框下方）==========
    global ClipboardCurrentCategory, ClipboardCategoryButtons
    ; 【修改】参考 ClipboardHistoryPanel：使用空字符串表示全部，默认显示全部数据
    if (!IsSet(ClipboardCurrentCategory) || ClipboardCurrentCategory = "") {
        ClipboardCurrentCategory := ""  ; 空字符串表示全部，不添加过滤条件
    }
    ClipboardCategoryButtons := []
    
    ; 【修改】去掉"全部"标签，其他标签保留（8个标签：CapsLock+C、文本、代码、链接、图片、剪贴板、本地文件、提示词）
    ; 默认状态显示全部数据，参考 ClipboardHistoryPanel 的实现
    Categories := [
        {Key: "CapsLockC", Text: "CapsLock+C"},
        {Key: "Text", Text: "文本"},
        {Key: "Code", Text: "代码"},
        {Key: "Link", Text: "链接"},
        {Key: "Image", Text: "图片"},
        {Key: "Clipboard", Text: "剪贴板"},
        {Key: "File", Text: "本地文件"},
        {Key: "Template", Text: "提示词"}
    ]
    
    ; 分类标签栏位置（在搜索框下方）
    CategoryBarY := SearchBoxY + SearchBoxHeight + 10  ; 搜索框下方，间距10
    CategoryBarHeight := 35  ; 增高背景板，参考 ClipboardHistoryPanel
    CategoryButtonHeight := 28
    CategoryButtonSpacing := 8
    CategoryStartX := 20
    CategoryButtonY := CategoryBarY + (CategoryBarHeight - CategoryButtonHeight) / 2
    CurrentCategoryX := CategoryStartX
    
    ; 添加分类标签栏背景板（参考 ClipboardHistoryPanel）
    CategoryBarBg := GuiID_ClipboardManager.Add("Text", 
        "x0 y" . CategoryBarY . " w" . PanelWidth . " h" . CategoryBarHeight . 
        " Background" . UI_Colors.Background . 
        " vClipboardCategoryBarBg", "")
    
    ; 创建分类标签按钮（自适应宽度，让标签有更多空间排布）
    for Index, Category in Categories {
        ; 计算按钮宽度（根据文本长度自适应，最小宽度60）
        TextWidth := StrLen(Category.Text) * 9 + 20
        CategoryButtonWidth := Max(60, TextWidth)
        
        ; 根据是否选中设置背景色
        IsSelected := (Category.Key = ClipboardCurrentCategory)
        BgColor := IsSelected ? UI_Colors.BtnPrimary : UI_Colors.Sidebar
        TextColor := IsSelected ? "FFFFFF" : UI_Colors.Text
        
        CategoryBtn := GuiID_ClipboardManager.Add("Text", "x" . CurrentCategoryX . " y" . CategoryButtonY . " w" . CategoryButtonWidth . " h" . CategoryButtonHeight . " Center 0x200 c" . TextColor . " Background" . BgColor . " vClipboardCategoryBtn" . Category.Key, Category.Text)
        CategoryBtn.SetFont("s9", "Segoe UI")
        CategoryBtn.OnEvent("Click", CreateClipboardCategoryClickHandler(Category.Key))
        HoverBtn(CategoryBtn, BgColor, UI_Colors.BtnHover)
        ClipboardCategoryButtons.Push(CategoryBtn)
        
        ; 更新下一个按钮的X坐标
        CurrentCategoryX += CategoryButtonWidth + CategoryButtonSpacing
    }
    
    ; 清空按钮移到下方（在底部按钮区域）
    
    ; ========== 列表区域 ==========
    ; 【新功能】CapsLockC标签使用ListView表格布局，CtrlC标签使用ListBox
    global ThemeMode
    ListBoxBgColor := (ThemeMode = "dark") ? UI_Colors.InputBg : UI_Colors.InputBg
    ListBoxTextColor := (ThemeMode = "dark") ? UI_Colors.Text : UI_Colors.Text
    
    ; 【关键修复】根据窗口大小计算 ListView/ListBox 的初始大小，而不是使用固定值
    ; 列表控件位置：x=20, y=标签栏下方
    ; 列表控件宽度：窗口宽度 - 左右边距(40) = PanelWidth - 40（自适应）
    ; 列表控件高度：窗口高度 - 分类标签栏(38+35+10) - 搜索框(30+10) - 底部区域(70) = PanelHeight - 193
    ListX := 20
    ListY := CategoryBarY + CategoryBarHeight + 10  ; 标签栏下方
    ListWidth := PanelWidth - 40  ; 自适应窗口宽度
    ListHeight := PanelHeight - (CategoryBarY + CategoryBarHeight + 10) - 70
    
    ; 确保最小尺寸
    if (ListWidth < 200) {
        ListWidth := 200
    }
    if (ListHeight < 100) {
        ListHeight := 100
    }
    
    ; 创建两个控件（根据当前Tab显示/隐藏）
    ; ListBox用于CtrlC标签
    ListBox := GuiID_ClipboardManager.Add("ListBox", "x" . ListX . " y" . ListY . " w" . ListWidth . " h" . ListHeight . " vClipboardListBox Background" . ListBoxBgColor . " c" . ListBoxTextColor . " -E0x200")
    ListBox.SetFont("s10 c" . ListBoxTextColor, "Consolas")
    ListBox.Opt("+Background" . ListBoxBgColor)
    
    ; ListView用于CapsLockC标签（表格布局 - 单列显示内容）
    ListViewTextColor := (ThemeMode = "dark") ? UI_Colors.Text : UI_Colors.Text
    ; 单列布局：只显示内容（参考 ClipboardHistoryPanel.ahk 的实现）
    ; +LV0x1 = LVS_EX_GRIDLINES（网格线）
    ; 【修改】支持多选：从 -Multi 改为 +Multi，允许用户选择多个项目
    ; 注意：不使用 +LV0x20 (LVS_EX_FULLROWSELECT) 以允许单元格级别的操作
    ListViewCtrl := GuiID_ClipboardManager.Add("ListView", "x" . ListX . " y" . ListY . " w" . ListWidth . " h" . ListHeight . " vClipboardListView Background" . ListBoxBgColor . " c" . ListViewTextColor . " +Multi +ReadOnly +NoSortHdr +LV0x10000 +LV0x1", ["内容"])
    ListViewCtrl.SetFont("s9 c" . ListViewTextColor, "Consolas")
    
    ; 保存 ListView 句柄和窗口句柄，用于 WM_NOTIFY 消息识别
    global ClipboardListViewHwnd, ClipboardManagerHwnd
    ClipboardListViewHwnd := ListViewCtrl.Hwnd
    ClipboardManagerHwnd := GuiID_ClipboardManager.Hwnd
    
    ; 【关键修复】禁用 ListView 的默认选中行为
    ; 通过移除 LVS_SHOWSELALWAYS 样式和设置扩展样式来实现
    ; 获取当前窗口样式
    LV_Hwnd := ListViewCtrl.Hwnd
    CurrentStyle := DllCall("GetWindowLong" . (A_PtrSize = 8 ? "Ptr" : ""), "Ptr", LV_Hwnd, "Int", -16, "Ptr")  ; GWL_STYLE = -16
    ; 移除 LVS_SHOWSELALWAYS (0x0008) 样式
    NewStyle := CurrentStyle & ~0x0008
    DllCall("SetWindowLong" . (A_PtrSize = 8 ? "Ptr" : ""), "Ptr", LV_Hwnd, "Int", -16, "Ptr", NewStyle)
    
    ; 设置扩展样式
    ; LVM_SETEXTENDEDLISTVIEWSTYLE = 0x1036, LVM_GETEXTENDEDLISTVIEWSTYLE = 0x1037
    ; LVS_EX_FULLROWSELECT = 0x00000020 (整行选中，我们不需要)
    ; LVS_EX_SUBITEMIMAGES = 0x00000002 (允许子项图像，这对 LVM_SUBITEMHITTEST 很重要)
    CurrentExStyle := DllCall("SendMessage", "Ptr", LV_Hwnd, "UInt", 0x1037, "Ptr", 0, "Ptr", 0, "UInt")
    ; 移除 LVS_EX_FULLROWSELECT，但保留其他样式
    ; 注意：不添加 LVS_EX_SUBITEMIMAGES，因为它可能不是必需的
    NewExStyle := CurrentExStyle & ~0x00000020
    DllCall("SendMessage", "Ptr", LV_Hwnd, "UInt", 0x1036, "Ptr", 0, "Ptr", NewExStyle, "UInt")
    
    ; 注意：不再使用OnNotify自定义绘制，改用覆盖层方案
    ; 覆盖层方案更可靠，不依赖OnNotify的返回值机制
    
    ; 绑定单元格点击事件（用于显示浮窗和更新高亮）
    ListViewCtrl.OnEvent("ItemSelect", OnClipboardListViewItemSelect)
    
    ; 保存ListBox句柄和创建画刷，用于WM_CTLCOLORLISTBOX消息处理
    global ClipboardListBoxHwnd, ClipboardListBoxBrush
    ClipboardListBoxHwnd := ListBox.Hwnd
    BgColorCode := "0x" . ListBoxBgColor
    BGRColor := Integer(BgColorCode)
    BGRColor := ((BGRColor & 0xFF) << 16) | (BGRColor & 0xFF00) | ((BGRColor & 0xFF0000) >> 16)
    ClipboardListBoxBrush := DllCall("gdi32.dll\CreateSolidBrush", "UInt", BGRColor, "Ptr")
    
    ; 根据当前Tab显示/隐藏控件
    if (ClipboardCurrentTab = "CapsLockC") {
        ListBox.Visible := false
        ListViewCtrl.Visible := true
    } else {
        ListBox.Visible := true
        ListViewCtrl.Visible := false
    }
    
    ; ========== 底部按钮区域 ==========
    ; 底部区域Y坐标需要根据窗口高度动态调整（在Size事件中处理）
    ; 【关键修复】根据窗口高度计算底部区域的初始位置
    BottomAreaY := PanelHeight - 70
    ; 底部区域宽度：窗口宽度
    BottomArea := GuiID_ClipboardManager.Add("Text", "x0 y" . BottomAreaY . " w" . PanelWidth . " h70 Background" . UI_Colors.Background . " vClipboardBottomArea", "")
    
    ; 操作按钮（使用v参数保存引用以便调整位置，对齐排布）
    ButtonY := BottomAreaY + 10
    ButtonHeight := 35
    ButtonWidth := 100
    ButtonSpacing := 10
    
    ; 第一行按钮（从左到右对齐排布）
    CopyBtn := GuiID_ClipboardManager.Add("Text", "x20 y" . ButtonY . " w" . ButtonWidth . " h" . ButtonHeight . " Center 0x200 c" . ((ThemeMode = "dark") ? "FFFFFF" : "000000") . " Background" . UI_Colors.BtnBg . " vClipboardCopyBtn", GetText("copy_selected"))
    CopyBtn.SetFont("s10", "Segoe UI")
    CopyBtn.OnEvent("Click", CopySelectedItem)
    HoverBtn(CopyBtn, UI_Colors.BtnBg, UI_Colors.BtnHover)
    
    DeleteBtn := GuiID_ClipboardManager.Add("Text", "x" . (20 + ButtonWidth + ButtonSpacing) . " y" . ButtonY . " w" . ButtonWidth . " h" . ButtonHeight . " Center 0x200 c" . ((ThemeMode = "dark") ? "FFFFFF" : "000000") . " Background" . UI_Colors.BtnBg . " vClipboardDeleteBtn", GetText("delete_selected"))
    DeleteBtn.SetFont("s10", "Segoe UI")
    DeleteBtn.OnEvent("Click", DeleteSelectedItem)
    HoverBtn(DeleteBtn, UI_Colors.BtnBg, UI_Colors.BtnHover)
    
    PasteBtn := GuiID_ClipboardManager.Add("Text", "x" . (20 + (ButtonWidth + ButtonSpacing) * 2) . " y" . ButtonY . " w" . (ButtonWidth + 20) . " h" . ButtonHeight . " Center 0x200 cFFFFFF Background" . UI_Colors.BtnPrimary . " vClipboardPasteBtn", GetText("paste_to_cursor"))
    PasteBtn.SetFont("s10", "Segoe UI")
    PasteBtn.OnEvent("Click", PasteSelectedToCursor)
    HoverBtn(PasteBtn, UI_Colors.BtnPrimary, UI_Colors.BtnPrimaryHover)
    
    ; 清空全部按钮（放在"粘贴到cursor"右边）
    ClearAllBtn := GuiID_ClipboardManager.Add("Text", "x" . (20 + (ButtonWidth + ButtonSpacing) * 2 + ButtonWidth + 20 + ButtonSpacing) . " y" . ButtonY . " w" . ButtonWidth . " h" . ButtonHeight . " Center 0x200 c" . ((ThemeMode = "dark") ? "FFFFFF" : "000000") . " Background" . UI_Colors.BtnBg . " vClipboardClearAllBtn", GetText("clear_all"))
    ClearAllBtn.SetFont("s10", "Segoe UI")
    ClearAllBtn.OnEvent("Click", ClearAllClipboard)
    HoverBtn(ClearAllBtn, UI_Colors.BtnBg, UI_Colors.BtnHover)
    
    ExportBtn := GuiID_ClipboardManager.Add("Text", "x" . (20 + (ButtonWidth + ButtonSpacing) * 3 + ButtonWidth + 20 + ButtonSpacing) . " y" . ButtonY . " w" . ButtonWidth . " h" . ButtonHeight . " Center 0x200 c" . ((ThemeMode = "dark") ? "FFFFFF" : "000000") . " Background" . UI_Colors.BtnBg . " vClipboardExportBtn", GetText("export_clipboard"))
    ExportBtn.SetFont("s10", "Segoe UI")
    ExportBtn.OnEvent("Click", ExportClipboard)
    HoverBtn(ExportBtn, UI_Colors.BtnBg, UI_Colors.BtnHover)
    
    ImportBtn := GuiID_ClipboardManager.Add("Text", "x" . (20 + (ButtonWidth + ButtonSpacing) * 4 + ButtonWidth + 20 + ButtonSpacing) . " y" . ButtonY . " w" . ButtonWidth . " h" . ButtonHeight . " Center 0x200 c" . ((ThemeMode = "dark") ? "FFFFFF" : "000000") . " Background" . UI_Colors.BtnBg . " vClipboardImportBtn", GetText("import_clipboard"))
    ImportBtn.SetFont("s10", "Segoe UI")
    ImportBtn.OnEvent("Click", ImportClipboard)
    HoverBtn(ImportBtn, UI_Colors.BtnBg, UI_Colors.BtnHover)
    
    ; 底部提示
    ; 【关键修复】根据窗口宽度计算提示文字的宽度
    HintText := GuiID_ClipboardManager.Add("Text", "x20 y" . (BottomAreaY + 55) . " w" . (PanelWidth - 40) . " h15 c" . UI_Colors.TextDim . " vClipboardHintText", GetText("clipboard_hint"))
    HintText.SetFont("s9", "Segoe UI")
    
    ; 绑定选中变化和双击事件
    ; ListBox用于CtrlC标签
    ListBox.OnEvent("Change", OnClipboardListBoxChange)
    ListBox.OnEvent("DoubleClick", CopySelectedItem)
    
    ; ListView用于CapsLockC标签
    ; 双击显示悬浮编辑窗
    ListViewCtrl.OnEvent("DoubleClick", OnClipboardListViewDoubleClick)
    ; 注意：ItemSelect 事件已在上面绑定，这里不需要重复绑定
    
    ; 绑定窗口大小变化事件（使ListView自适应窗口大小）
    GuiID_ClipboardManager.OnEvent("Size", OnClipboardManagerSize)
    
    ; 绑定窗口关闭事件（保存位置和大小）
    GuiID_ClipboardManager.OnEvent("Close", CloseClipboardManager)
    
    ; 绑定 ESC 关闭
    GuiID_ClipboardManager.OnEvent("Escape", CloseClipboardManager)
    
    ; 确保历史记录数组已初始化
    if (!IsSet(ClipboardHistory_CtrlC) || !IsObject(ClipboardHistory_CtrlC)) {
        global ClipboardHistory_CtrlC := []
    }
    if (!IsSet(ClipboardHistory_CapsLockC) || !IsObject(ClipboardHistory_CapsLockC)) {
        global ClipboardHistory_CapsLockC := []
    }
    
    ; 保存控件引用（使用全局声明确保正确保存）
    global ClipboardListBox, ClipboardListView
    ClipboardListBox := ListBox
    ClipboardListView := ListViewCtrl  ; ListView控件
    ; 确保 ClipboardCurrentTab 已设置
    if (!IsSet(ClipboardCurrentTab) || ClipboardCurrentTab = "") {
        global ClipboardCurrentTab := "CtrlC"
    }
    
    ; 使用恢复的位置，如果没有保存的位置则使用默认位置
    if (RestoredPos.X = -1 || RestoredPos.Y = -1) {
        ScreenInfo := GetScreenInfo(ClipboardPanelScreenIndex)
        Pos := GetPanelPosition(ScreenInfo, PanelWidth, PanelHeight, ClipboardPanelPos)
        RestoredPos.X := Pos.X
        RestoredPos.Y := Pos.Y
    }
    
    ; 先显示 GUI，确保控件已准备好
    GuiID_ClipboardManager.Show("w" . RestoredPos.Width . " h" . RestoredPos.Height . " x" . RestoredPos.X . " y" . RestoredPos.Y)
    
    ; 如果当前是CapsLockC标签，创建高亮覆盖层
    if (ClipboardCurrentTab = "CapsLockC") {
        ; 延迟一点时间创建覆盖层，确保ListView已完全显示
        SetTimer(() => CreateClipboardHighlightOverlay(), -50)
    }
    
    ; 为搜索框添加回车键支持（使用窗口级别的快捷键）
    ; 由于Edit控件不支持Enter事件，我们使用Hotkey来处理
    ; 只有当搜索框获得焦点时才触发搜索
    try {
        ; 使用窗口的快捷键功能，但需要检测焦点在搜索框上
        ; 更简单的方法：使用定时器检测搜索框焦点和回车键
        ; 或者直接在Change事件中处理（但这不是最优方案）
        ; 这里我们使用一个变通方法：在窗口显示后设置一个全局快捷键（仅在窗口激活时有效）
        ; 但由于可能会影响其他功能，我们改为使用OnNotify来监听键盘事件
        ; 实际上，最实用的方法是：用户可以直接点击搜索按钮，或者使用Tab键切换到搜索按钮后按回车
        ; 暂时保留这个功能，但不强制要求回车键（用户可以使用搜索按钮）
    } catch as err {
    }
    
    ; 确保窗口在最上层并激活
    WinSetAlwaysOnTop(1, GuiID_ClipboardManager.Hwnd)
    WinActivate(GuiID_ClipboardManager.Hwnd)
    
    ; 确保全局变量已正确初始化
    if (!IsSet(ClipboardHistory_CtrlC) || !IsObject(ClipboardHistory_CtrlC)) {
        global ClipboardHistory_CtrlC := []
    }
    if (!IsSet(ClipboardHistory_CapsLockC) || !IsObject(ClipboardHistory_CapsLockC)) {
        global ClipboardHistory_CapsLockC := []
    }
    if (!IsSet(ClipboardCurrentTab) || ClipboardCurrentTab = "") {
        global ClipboardCurrentTab := "CtrlC"
    }
    
    ; 【架构修复】确保在GUI完全准备好后再加载数据
    ; 增加延迟时间，确保所有控件都已完全初始化
    Sleep(100)
    
    ; 【架构修复】在GUI显示后，确保ListBox颜色正确，然后刷新列表
    ; 强制刷新ListBox的颜色设置，确保立即生效
    try {
        if (ListBox && IsObject(ListBox)) {
            ListBoxBgColor := (ThemeMode = "dark") ? UI_Colors.InputBg : UI_Colors.InputBg
            ListBoxTextColor := (ThemeMode = "dark") ? UI_Colors.Text : UI_Colors.Text
            ListBox.Opt("+Background" . ListBoxBgColor)
            ListBox.SetFont("s10 c" . ListBoxTextColor, "Consolas")
            ListBox.Redraw()
        }
    } catch as err {
        ; 忽略错误
    }
    
    ; 【关键修复】确保全局变量已正确初始化（在刷新列表之前）
    ; 使用全局声明确保正确访问历史记录数组
    global ClipboardHistory_CtrlC, ClipboardHistory_CapsLockC, ClipboardCurrentTab
    if (!IsSet(ClipboardHistory_CtrlC) || !IsObject(ClipboardHistory_CtrlC)) {
        global ClipboardHistory_CtrlC := []
    }
    if (!IsSet(ClipboardHistory_CapsLockC) || !IsObject(ClipboardHistory_CapsLockC)) {
        global ClipboardHistory_CapsLockC := []
    }
    if (!IsSet(ClipboardCurrentTab) || ClipboardCurrentTab = "") {
        global ClipboardCurrentTab := "CtrlC"
    }
    
    ; 【关键修复】确保控件引用已正确保存（在刷新列表之前）
    ; 重新获取控件引用，确保它们可用
    try {
        if (!ClipboardListBox || !IsObject(ClipboardListBox)) {
            ClipboardListBox := ListBox
        }
        ; ClipboardCountText 已移除
        ; 确保 ListView 控件引用已保存
        global ClipboardListView
        if (!ClipboardListView || !IsObject(ClipboardListView)) {
            ClipboardListView := ListViewCtrl
        }
    } catch as err {
        ; 忽略错误
    }
    
    ; 【新增】启动时自动切换到 CapsLockC 标签，方便用户选择
    ; 参考 ClipboardHistoryPanel 的实现，默认显示 CapsLockC 标签
    global ClipboardCurrentTab, ClipboardCurrentCategory, ClipboardCategoryButtons, UI_Colors
    ClipboardCurrentTab := "CapsLockC"
    ; 【修复】默认不选择任何分类标签，显示全部数据（空字符串表示全部）
    ; 用户可以根据需要点击标签进行过滤
    ClipboardCurrentCategory := ""
    
    ; 更新分类标签按钮样式（确保所有标签都显示为未选中状态）
    Categories := [
        {Key: "CapsLockC", Text: "CapsLock+C"},
        {Key: "Text", Text: "文本"},
        {Key: "Code", Text: "代码"},
        {Key: "Link", Text: "链接"},
        {Key: "Image", Text: "图片"},
        {Key: "Clipboard", Text: "剪贴板"},
        {Key: "File", Text: "本地文件"},
        {Key: "Template", Text: "提示词"}
    ]
    
    ; 更新标签按钮样式
    for Index, Category in Categories {
        if (Index <= ClipboardCategoryButtons.Length) {
            Btn := ClipboardCategoryButtons[Index]
            IsSelected := (Category.Key = ClipboardCurrentCategory)
            BgColor := IsSelected ? UI_Colors.BtnPrimary : UI_Colors.Sidebar
            TextColor := IsSelected ? "FFFFFF" : UI_Colors.Text
            
            try {
                Btn.Opt("+Background" . BgColor)
                Btn.SetFont("s9 c" . TextColor, "Segoe UI")
            } catch as err {
            }
        }
    }
    
    ; 更新 Tab 按钮样式（如果需要）
    ; 显示 ListView，隐藏 ListBox
    try {
        if (ClipboardListView && IsObject(ClipboardListView)) {
            ClipboardListView.Visible := true
        }
        if (ClipboardListBox && IsObject(ClipboardListBox)) {
            ClipboardListBox.Visible := false
        }
        ; 创建高亮覆盖层（延迟创建，确保 ListView 已完全显示）
        SetTimer(() => CreateClipboardHighlightOverlay(), -50)
    } catch as err {
    }
    
    ; 【关键修复】在 GUI 显示后立即刷新列表（确保控件已准备好）
    ; 【新增】自动加载 ListView：窗口显示后立即刷新列表，确保 ListView 自动加载数据
    ; 使用延迟刷新，确保所有初始化都已完成
    ; 对于 CapsLockC 标签，使用更短的延迟以确保 ListView 立即加载
    ; CapsLockC 标签使用 ListView，需要立即加载
    SetTimer(RefreshClipboardListAfterShow, -150)
}

; Ctrl+C 标签点击处理函数

; CapsLock+C 标签点击处理函数（防止触发复制操作）
SwitchClipboardTabCapsLockC(*) {
    ; 【关键修复】在切换标签前，先彻底阻止 CapsLock+C 快捷键触发
    ; 必须在函数最开始就设置阻止标记，防止任何复制操作
    global CapsLock, CapsLock2, CapsLockCopyInProgress, CapsLockCopyEndTime
    global OldCapsLockForTab, OldCapsLock2ForTab, OldCapsLockCopyInProgress
    
    ; 【关键修复】立即设置阻止标记，必须在任何其他操作之前（甚至在任何变量声明之前）
    ; 这是第一行代码，确保阻止标记在所有可能的快捷键处理之前生效
    
    ; 保存当前状态（用于后续恢复）
    OldCapsLockForTab := CapsLock
    OldCapsLock2ForTab := CapsLock2
    OldCapsLockCopyInProgress := CapsLockCopyInProgress
    
    ; 【关键修复】立即设置阻止标记（必须在保存状态之后立即设置）
    ; 1. 立即清除 CapsLock 标记，防止触发复制
    CapsLock := false
    CapsLock2 := false
    ; 2. 立即设置 CapsLockCopyInProgress 为 true，防止复制函数执行
    CapsLockCopyInProgress := true
    ; 3. 设置一个未来的结束时间（8秒），确保在恢复之前不会触发复制
    ; 增加延迟时间，确保点击标签后即使 CapsLock 键还处于按下状态也不会触发复制
    ; 使用更长的延迟时间（8秒），确保完全阻止
    CapsLockCopyEndTime := A_TickCount + 8000
    
    ; 【关键修复】短暂延迟，确保阻止标记已完全生效
    ; 增加延迟时间，确保阻止标记在所有快捷键处理之前生效
    Sleep(100)  ; 增加到 100ms，确保阻止标记完全生效
    
    ; 切换标签
    SwitchClipboardTab("CapsLockC")
    
    ; 【关键修复】延迟恢复状态（使用更长的延迟，确保不会触发复制）
    ; 延迟时间要大于 CapsLockCopyEndTime 的设置，确保恢复时已经过了阻止期
    ; 增加到 8.5 秒，确保完全安全
    SetTimer(RestoreCapsLockState, -8500)
    SetTimer(RestoreCapsLockCopyFlag, -8500)
}

; 创建分类点击处理函数
CreateClipboardCategoryClickHandler(CategoryKey) {
    return (*) => SwitchClipboardCategory(CategoryKey)
}

; 切换剪贴板分类
SwitchClipboardCategory(CategoryKey) {
    global ClipboardCurrentCategory, ClipboardCategoryButtons, UI_Colors
    global ClipboardListView, ClipboardCurrentTab
    
    ; 只在 CapsLockC 标签时生效
    if (ClipboardCurrentTab != "CapsLockC") {
        return
    }
    
    ; 【修改】参考 ClipboardHistoryPanel：使用空字符串表示全部，点击已选中标签时取消选中
    ; 如果点击的是已选中的标签，则取消选中（显示全部）
    if (CategoryKey = ClipboardCurrentCategory) {
        ClipboardCurrentCategory := ""  ; 空字符串表示全部，不添加过滤条件
    } else {
        ClipboardCurrentCategory := CategoryKey
    }
    
    ; 立即清空 ListView，防止数据堆叠
    try {
        if (ClipboardListView && IsObject(ClipboardListView)) {
            ClipboardListView.Delete()
        }
    } catch as err {
    }
    
    ; 更新分类标签按钮样式（与创建时保持一致，去掉"全部"标签）
    Categories := [
        {Key: "CapsLockC", Text: "CapsLock+C"},
        {Key: "Text", Text: "文本"},
        {Key: "Code", Text: "代码"},
        {Key: "Link", Text: "链接"},
        {Key: "Image", Text: "图片"},
        {Key: "Clipboard", Text: "剪贴板"},
        {Key: "File", Text: "本地文件"},
        {Key: "Template", Text: "提示词"}
    ]
    
    for Index, Category in Categories {
        if (Index <= ClipboardCategoryButtons.Length) {
            Btn := ClipboardCategoryButtons[Index]
            IsSelected := (Category.Key = ClipboardCurrentCategory)
            BgColor := IsSelected ? UI_Colors.BtnPrimary : UI_Colors.Sidebar
            TextColor := IsSelected ? "FFFFFF" : UI_Colors.Text
            
            try {
                Btn.Opt("+Background" . BgColor)
                Btn.SetFont("s9 c" . TextColor, "Segoe UI")
            } catch as err {
            }
        }
    }
    
    ; 立即调用 RefreshClipboardListView() 重新加载数据
    RefreshClipboardListView()
}

; 切换剪贴板 Tab
SwitchClipboardTab(TabName) {
    global ClipboardCurrentTab, ClipboardCapsLockCTab, UI_Colors
    global ClipboardListBox, GuiID_ClipboardManager
    global CapsLock, CapsLock2, CapsLockCopyInProgress, LastSelectedIndex
    
    ; 检查 GUI 是否存在
    if (!GuiID_ClipboardManager) {
        ; 如果 GUI 对象不存在，尝试重新创建
        try {
            ShowClipboardManager()
            ; 等待 GUI 创建完成
            Sleep(100)
        } catch as err {
            return
        }
    }
    
    ; 验证 TabName 参数（只支持 CapsLockC）
    if (TabName != "CapsLockC") {
        return
    }
    
    ; 切换标签时，清除之前保存的选中索引（因为不同标签的数据不同）
    LastSelectedIndex := 0
    
    ; 切换标签时，清除高亮状态并更新覆盖层
    global ClipboardListViewHighlightedRow, ClipboardListViewHighlightedCol
    ClipboardListViewHighlightedRow := 0
    ClipboardListViewHighlightedCol := 0
    UpdateClipboardHighlightOverlay()
    
    
    ; 尝试获取GUI对象（GuiID_ClipboardManager 应该是 Gui 对象，不是 Hwnd）
    ClipboardGUI := ""
    try {
        ; 如果 GuiID_ClipboardManager 是 Gui 对象，直接使用
        if (IsObject(GuiID_ClipboardManager) && GuiID_ClipboardManager.HasProp("Hwnd")) {
            ClipboardGUI := GuiID_ClipboardManager
        } else {
            ; 否则尝试从 Hwnd 获取
            ClipboardGUI := GuiFromHwnd(GuiID_ClipboardManager)
        }
        if (ClipboardGUI) {
            ; 如果控件引用丢失，尝试重新获取
            ; ClipboardCapsLockCTab 已移除，不再需要重新获取
            ; 同时更新其他控件引用
            if (!ClipboardListBox || !IsObject(ClipboardListBox)) {
                try {
                    ClipboardListBox := ClipboardGUI["ClipboardListBox"]
                } catch as err {
                    ; 忽略错误
                }
            }
            ; ClipboardCountText 已移除，不再需要检查
        }
    } catch as err {
        ; 忽略错误
    }
    
    ; 更新当前标签（必须在更新样式之前）
    ClipboardCurrentTab := TabName
    
    ; 【新功能】根据Tab切换显示ListBox或ListView
    global ClipboardListView
    try {
        if (TabName = "CapsLockC") {
            ; CapsLockC标签使用ListView
            if (ClipboardListBox && IsObject(ClipboardListBox)) {
                ClipboardListBox.Visible := false
            }
            if (ClipboardListView && IsObject(ClipboardListView)) {
                ClipboardListView.Visible := true
            }
            ; 切换到CapsLockC标签时，延迟创建覆盖层（等待ListView显示完成）
            SetTimer(() => CreateClipboardHighlightOverlay(), -100)
        } else {
            ; CtrlC标签使用ListBox
            if (ClipboardListBox && IsObject(ClipboardListBox)) {
                ClipboardListBox.Visible := true
            }
            if (ClipboardListView && IsObject(ClipboardListView)) {
                ClipboardListView.Visible := false
            }
            ; 切换到CtrlC标签时，销毁覆盖层
            DestroyClipboardHighlightOverlay()
        }
    } catch as err {
        ; 忽略错误
    }
    
    ; 【关键修复】在切换标签时，彻底清空列表，确保不会显示旧标签的数据
    ; 这解决了两个标签共用内容框的问题
    global ClipboardListView
    try {
        ; 清空ListView（如果存在）
        if (ClipboardListView && IsObject(ClipboardListView)) {
            ClipboardListView.Delete()
        }
        
        ; 清空ListBox（如果存在）
        if (ClipboardListBox && IsObject(ClipboardListBox)) {
            ; 【改进】使用更可靠的清空方法，确保列表完全清空
            ; 方法1：从后往前删除
            Loop 200 {  ; 最多尝试200次，防止无限循环
                try {
                    CurrentList := ClipboardListBox.List
                    if (!CurrentList || CurrentList.Length = 0) {
                        break
                    }
                    ; 从后往前删除，避免索引变化
                    ClipboardListBox.Delete(CurrentList.Length)
                } catch as err {
                    break
                }
            }
            
            ; 方法2：从前往后删除（双重保险）
            Loop 200 {  ; 最多尝试200次
                try {
                    CurrentList := ClipboardListBox.List
                    if (!CurrentList || CurrentList.Length = 0) {
                        break
                    }
                    ClipboardListBox.Delete(1)
                } catch as err {
                    break
                }
            }
            
            ; 方法3：最终验证，确保列表为空
            try {
                FinalCheck := ClipboardListBox.List
                if (FinalCheck && FinalCheck.Length > 0) {
                    ; 如果还有项，强制清空
                    Loop FinalCheck.Length {
                        try {
                            ClipboardListBox.Delete(1)
                        } catch as err {
                            break
                        }
                    }
                }
            } catch as err {
                ; 忽略最终检查错误
            }
            
            ; 【关键】强制刷新UI，确保视觉上立即清空
            try {
                if (GuiID_ClipboardManager && IsObject(GuiID_ClipboardManager)) {
                    WinRedraw(GuiID_ClipboardManager.Hwnd)
                }
            } catch as err {
                ; 忽略重绘失败
            }
        }
    } catch as err {
        ; 忽略清空错误，继续执行
    }
    
    ; Tab 样式更新已移除（因为删除了 CapsLock+C Tab 按钮）
    
    ; 刷新列表（无论样式更新是否成功，都要刷新列表）
    RefreshClipboardList()
}

; 延迟刷新剪贴板列表（用于 OnClipboardChange 等场景）
RefreshClipboardListDelayed(*) {
    global WindowDragging
    
    ; 如果窗口正在拖动，跳过刷新以避免闪烁
    if (WindowDragging) {
        return
    }
    
    ; 确保刷新时当前标签是 CapsLockC
    global ClipboardCurrentTab
    if (ClipboardCurrentTab = "CapsLockC") {
        RefreshClipboardList()
    }
}

; 在 GUI 显示后刷新剪贴板列表（用于 ShowClipboardManager）
RefreshClipboardListAfterShow(*) {
    try {
        global GuiID_ClipboardManager, ClipboardListView
        if (GuiID_ClipboardManager != 0) {
            ; 确保 ListView 控件可用
            if (ClipboardListView && IsObject(ClipboardListView)) {
                RefreshClipboardList()
            } else {
                ; 如果 ListView 不可用，稍后重试
                SetTimer(() => RefreshClipboardList(), -200)
            }
        }
    } catch as err {
        ; 如果失败，使用更长的延迟作为后备
        SetTimer(() => RefreshClipboardList(), -300)
    }
}

; 刷新剪贴板列表
RefreshClipboardList() {
    global ClipboardHistory_CtrlC, ClipboardHistory_CapsLockC, ClipboardCurrentTab
    global ClipboardListBox, GuiID_ClipboardManager
    global RefreshClipboardListInProgress := false  ; 防重复刷新标志
    global WindowDragging
    
    ; 如果窗口正在拖动，跳过刷新以避免闪烁
    if (WindowDragging) {
        return
    }
    
    ; 【关键修复】防止并发刷新导致的数据叠加
    ; 如果正在刷新，直接返回，避免重复执行
    if (IsSet(RefreshClipboardListInProgress) && RefreshClipboardListInProgress) {
        return
    }
    RefreshClipboardListInProgress := true
    
    ; 确保全局变量已初始化
    if (!IsSet(ClipboardHistory_CtrlC) || !IsObject(ClipboardHistory_CtrlC)) {
        ClipboardHistory_CtrlC := []
    }
    if (!IsSet(ClipboardHistory_CapsLockC) || !IsObject(ClipboardHistory_CapsLockC)) {
        ClipboardHistory_CapsLockC := []
    }
    if (!IsSet(ClipboardCurrentTab) || ClipboardCurrentTab = "") {
        ClipboardCurrentTab := "CtrlC"
    }
    
    ; 检查 GUI 是否存在
    if (!GuiID_ClipboardManager) {
        return
    }
    
    ; 如果控件引用丢失，尝试获取GUI对象并重新获取控件
    if (!ClipboardListBox || !IsObject(ClipboardListBox)) {
        try {
            ; 尝试获取GUI对象
            ClipboardGUI := ""
            if (IsObject(GuiID_ClipboardManager) && GuiID_ClipboardManager.HasProp("Hwnd")) {
                ClipboardGUI := GuiID_ClipboardManager
            } else {
                ClipboardGUI := GuiFromHwnd(GuiID_ClipboardManager)
            }
            if (ClipboardGUI) {
                ; 如果控件引用丢失，尝试重新获取
                if (!ClipboardListBox || !IsObject(ClipboardListBox)) {
                    try {
                        ClipboardListBox := ClipboardGUI["ClipboardListBox"]
                    } catch as err {
                        ; 如果无法获取，返回
                        return
                    }

                }
                ; ClipboardCountText 已移除，不再需要检查
            } else {
                ; 如果无法获取GUI对象，但控件引用存在，继续使用现有引用
                if (!ClipboardListBox || !IsObject(ClipboardListBox)) {
                    return
                }
            }
        } catch as err {
            ; 如果出错，但控件引用存在，继续使用现有引用
            if (!ClipboardListBox || !IsObject(ClipboardListBox)) {
                return
            }
        }
    }
    
    ; 检查控件是否存在
    global ClipboardListView
    if (!ClipboardListBox) {
        return
    }
    
    ; 【新功能】CapsLockC标签使用ListView表格布局
    if (ClipboardCurrentTab = "CapsLockC") {
        RefreshClipboardListView()
        RefreshClipboardListInProgress := false
        return
    }
    
    try {
        ; 确保历史记录数组已初始化（使用全局声明确保正确访问）
        if (!IsSet(ClipboardHistory_CtrlC) || !IsObject(ClipboardHistory_CtrlC)) {
            global ClipboardHistory_CtrlC := []
        }
        if (!IsSet(ClipboardHistory_CapsLockC) || !IsObject(ClipboardHistory_CapsLockC)) {
            global ClipboardHistory_CapsLockC := []
        }
        
        ; 确保 ClipboardCurrentTab 有默认值
        if (!IsSet(ClipboardCurrentTab) || ClipboardCurrentTab = "") {
            global ClipboardCurrentTab := "CtrlC"
        }
        
        ; 根据当前 Tab 选择对应的历史记录（直接使用全局变量，确保引用正确）
        ; 【关键修复】直接使用全局变量引用，不要创建局部副本
        CurrentHistory := []
        HistoryLength := 0
        
        ; 【关键修复】确保使用全局变量，并根据当前标签选择正确的数据源
        if (ClipboardCurrentTab = "CtrlC") {
            ; Ctrl+C 标签仍然使用数组（保持兼容）
            if (IsSet(ClipboardHistory_CtrlC) && IsObject(ClipboardHistory_CtrlC)) {
                CurrentHistory := ClipboardHistory_CtrlC
                HistoryLength := ClipboardHistory_CtrlC.Length
            } else {
                CurrentHistory := []
                HistoryLength := 0
            }
        } else if (ClipboardCurrentTab = "CapsLockC") {
            ; CapsLock+C 标签从 SQLite 数据库读取
            global ClipboardDB
            if (ClipboardDB && ClipboardDB != 0) {
                try {
                    ResultTable := ""
                    ; 【修复】使用 ORDER BY Timestamp DESC 确保按时间倒序排列，兼容旧的 UI 过滤逻辑
                    if (ClipboardDB.GetTable("SELECT ID, Content FROM ClipboardHistory ORDER BY Timestamp DESC", &ResultTable)) {
                        if (ResultTable && ResultTable.HasProp("Rows") && ResultTable.Rows.Length > 0) {
                            ; 从数据库结果构建数组（Row[1]=ID, Row[2]=Content）
                            CurrentHistory := []
                            for Index, Row in ResultTable.Rows {
                                ; Row数组索引从1开始：Row[1]=ID, Row[2]=Content
                                if (Row.Length > 1 && Row[2] != "") {
                                    ; 存储格式：直接存储内容（废弃 SessionID 模式）
                                    CurrentHistory.Push(Row[2])
                                }
                            }
                            HistoryLength := CurrentHistory.Length
                        } else {
                            CurrentHistory := []
                            HistoryLength := 0
                        }
                    } else {
                        CurrentHistory := []
                        HistoryLength := 0
                    }
                } catch as err {
                    ; 如果数据库读取失败，回退到数组
                    if (IsSet(ClipboardHistory_CapsLockC) && IsObject(ClipboardHistory_CapsLockC)) {
                        CurrentHistory := ClipboardHistory_CapsLockC
                        HistoryLength := ClipboardHistory_CapsLockC.Length
                    } else {
                        CurrentHistory := []
                        HistoryLength := 0
                    }
                }
            } else {
                ; 如果数据库未初始化，回退到数组（兼容模式）
                if (IsSet(ClipboardHistory_CapsLockC) && IsObject(ClipboardHistory_CapsLockC)) {
                    CurrentHistory := ClipboardHistory_CapsLockC
                    HistoryLength := ClipboardHistory_CapsLockC.Length
                } else {
                    CurrentHistory := []
                    HistoryLength := 0
                }
            }
        } else {
            ; 默认使用 CtrlC
            if (IsSet(ClipboardHistory_CtrlC) && IsObject(ClipboardHistory_CtrlC)) {
                CurrentHistory := ClipboardHistory_CtrlC
                HistoryLength := ClipboardHistory_CtrlC.Length
            } else {
                CurrentHistory := []
                HistoryLength := 0
            }
        }
        
        ; 确保 CurrentHistory 是有效的数组
        if (!IsObject(CurrentHistory)) {
            CurrentHistory := []
            HistoryLength := 0
        }
        
        ; 【关键修复】原子性清空列表（确保列表完全清空后再添加数据，防止数据叠加）
        ; 使用"先禁用更新-清空-验证-重新启用"的模式，确保操作的原子性
        try {
            ; 方法1：先禁用ListBox更新，提高清空操作的可靠性
            ClipboardListBox.Opt("-Redraw")
            
            ; 方法2：循环删除，直到列表完全为空（使用简单的while循环）
            Loop 200 {  ; 最多尝试200次，防止死循环
                CurrentList := ClipboardListBox.List
                if (!CurrentList || CurrentList.Length = 0) {
                    ; 列表已为空，退出循环
                    break
                }
                ; 从前往后删除第一项（最简单可靠的方法）
                try {
                    ClipboardListBox.Delete(1)
                } catch as err {
                    ; 删除失败，可能已经为空，退出循环
                    break
                }
            }
            
            ; 方法3：最终验证，确保列表确实为空
            FinalCheckList := ClipboardListBox.List
            if (FinalCheckList && FinalCheckList.Length > 0) {
                ; 如果还有残留项，最后一次清空
                Loop FinalCheckList.Length {
                    try {
                        ClipboardListBox.Delete(1)
                    } catch as err {
                        break
                    }
                }
            }
            
            ; 重新启用ListBox更新
            ClipboardListBox.Opt("+Redraw")
        } catch as err {
            ; 如果清空过程出错，尝试重新启用更新
            try {
                ClipboardListBox.Opt("+Redraw")
            } catch as err {
            }
        }
        
        ; 【架构修复】确保ListBox颜色正确（在添加数据之前）
        try {
            if (ClipboardListBox && IsObject(ClipboardListBox)) {
                global ThemeMode
                ListBoxBgColor := (ThemeMode = "dark") ? UI_Colors.InputBg : UI_Colors.InputBg
                ListBoxTextColor := (ThemeMode = "dark") ? UI_Colors.Text : UI_Colors.Text
                ; 强制设置背景色和文字颜色
                ClipboardListBox.Opt("+Background" . ListBoxBgColor)
                ClipboardListBox.SetFont("s10 c" . ListBoxTextColor, "Consolas")
            }
        } catch as err {
            ; 忽略颜色设置错误
        }
        
        ; 添加所有历史记录（显示前80个字符作为预览）
        ; 【新功能】按阶段分组显示：[SessionID-ItemIndex] 格式
        Items := []
        
        ; 直接使用全局变量，确保数据正确
        if (HistoryLength > 0) {
            for Index, ItemData in CurrentHistory {
                ; 检查数据结构：如果是Map（数据库模式），使用SessionID和ItemIndex；如果是字符串（数组模式），使用索引
                Content := ""
                SessionID := 0
                ItemIndex := 0
                
                if (IsObject(ItemData) && ItemData.Has("Content")) {
                    ; 数据库模式：使用Map对象
                    Content := ItemData["Content"]
                    SessionID := ItemData["SessionID"]
                    ItemIndex := ItemData["ItemIndex"]
                } else if (Type(ItemData) = "String") {
                    ; 数组模式：使用字符串和索引
                    Content := ItemData
                    SessionID := 1  ; 数组模式默认为阶段1
                    ItemIndex := Index
                }
                
                ; 确保 Content 是字符串
                if (Content = "" || Type(Content) != "String") {
                    continue
                }
                
                ; 处理换行和特殊字符，创建预览文本
                Preview := StrReplace(Content, "`r`n", " ")
                Preview := StrReplace(Preview, "`n", " ")
                Preview := StrReplace(Preview, "`r", " ")
                Preview := StrReplace(Preview, "`t", " ")
                
                ; 限制预览长度
                if (StrLen(Preview) > 80) {
                    Preview := SubStr(Preview, 1, 80) . "..."
                }
                
                ; 添加序号和预览（格式：[SessionID-ItemIndex] 内容预览）
                DisplayText := "[" . SessionID . "-" . ItemIndex . "] " . Preview
                Items.Push(DisplayText)
            }
        }
        
        ; 保存刷新前的选中索引
        global LastSelectedIndex
        PreviousSelectedIndex := 0
        try {
            if (IsSet(LastSelectedIndex) && LastSelectedIndex > 0) {
                PreviousSelectedIndex := LastSelectedIndex
            }
        } catch as err {
            PreviousSelectedIndex := 0
        }
        
        ; 批量添加项目（此时列表已确保为空，不会叠加）
        if (Items.Length > 0) {
            try {
                ClipboardListBox.Add(Items)
            } catch as err {
                ; 如果批量添加失败，尝试逐个添加
                for Index, Item in Items {
                    try {
                        ClipboardListBox.Add(Item)
                    } catch as err {
                        ; 忽略单个项目添加失败
                        continue
                    }
                }
            }
        }
        
        ; 尝试恢复之前的选中状态
        if (PreviousSelectedIndex > 0 && PreviousSelectedIndex <= HistoryLength) {
            try {
                ClipboardListBox.Value := PreviousSelectedIndex
                LastSelectedIndex := PreviousSelectedIndex
            } catch as err {
                ; 如果恢复失败，清除保存的索引
                LastSelectedIndex := 0
            }
        } else {
            ; 如果没有有效的选中项，清除保存的索引
            LastSelectedIndex := 0
        }
        
        ; 统计信息在选中行变化时更新，这里不需要更新
        ; （移除旧的统计信息更新逻辑）
        
        ; 强制刷新UI，确保视觉更新
        try {
            if (GuiID_ClipboardManager && IsObject(GuiID_ClipboardManager)) {
                ; 强制重绘窗口
                WinRedraw(GuiID_ClipboardManager.Hwnd)
            }
        } catch as err {
            ; 忽略重绘失败
        }
    } catch as e {
        ; 如果控件已销毁，静默失败
        return
    } finally {
        ; 【关键修复】无论成功或失败，都要重置防重复刷新标志
        global RefreshClipboardListInProgress
        RefreshClipboardListInProgress := false
    }
}

; ===================== 刷新剪贴板ListView表格（CapsLockC标签） =====================
; 【横向布局】每个阶段（SessionID）为一行，同一阶段的复制内容横向排列为不同列
RefreshClipboardListView() {
    global ClipboardListView, ClipboardDB, ClipboardCurrentTab
    global RefreshClipboardListInProgress, GuiID_ClipboardManager
    global ClipboardListViewHighlightedRow, ClipboardListViewHighlightedCol
    global ClipboardCurrentCategory, ClipboardFTS5DB
    global ClipboardManagementEverythingLimit, ClipboardManagementResultLimitDropdown
    
    ; 确保当前标签是CapsLockC
    if (ClipboardCurrentTab != "CapsLockC") {
        return
    }
    
    ; 【修改】参考 ClipboardHistoryPanel：使用空字符串表示全部，不添加过滤条件
    CurrentCategory := ClipboardCurrentCategory
    if (!IsSet(CurrentCategory) || CurrentCategory = "") {
        CurrentCategory := ""  ; 空字符串表示全部，不添加过滤条件
    }
    
    ; 清除高亮单元格
    ClipboardListViewHighlightedRow := 0
    ClipboardListViewHighlightedCol := 0
    
    ; 更新覆盖层（隐藏高亮）
    UpdateClipboardHighlightOverlay()
    
    ; 如果控件引用丢失，尝试重新获取
    if (!ClipboardListView || !IsObject(ClipboardListView)) {
        try {
            ClipboardGUI := ""
            if (IsObject(GuiID_ClipboardManager) && GuiID_ClipboardManager.HasProp("Hwnd")) {
                ClipboardGUI := GuiID_ClipboardManager
            } else if (GuiID_ClipboardManager) {
                ClipboardGUI := GuiFromHwnd(GuiID_ClipboardManager)
            }
            if (ClipboardGUI) {
                if (!ClipboardListView || !IsObject(ClipboardListView)) {
                    try {
                        ClipboardListView := ClipboardGUI["ClipboardListView"]
                    } catch as err {
                    }
                }
                ; ClipboardCountText 已移除
            }
        } catch as err {
        }
    }
    
    ; 检查控件是否存在
    if (!ClipboardListView || !IsObject(ClipboardListView)) {
        return
    }
    
    try {
        ; 【关键修复】锁定界面更新，防止闪烁（先禁用重绘，避免切换标签时的空白）
        ClipboardListView.Opt("-Redraw")
        
        ; 【关键修复】在查询前立即清空列表，防止数据堆叠
        try {
            ClipboardListView.Delete()
        } catch as err {
        }
        
        ; 【优化】先查询数据，再一次性添加，避免空白闪烁
        ; 【参考 ClipboardHistoryPanel.ahk】使用 ClipboardFTS5DB 数据库（ClipMain 表）
        if (!ClipboardFTS5DB || ClipboardFTS5DB = 0) {
            ; 尝试重新初始化数据库
            try {
                if (!InitClipboardFTS5DB()) {
                    ; 初始化失败，清空列表
                    ClipboardListView.Opt("+Redraw")
                    return
                }
            } catch as err {
                ; 初始化异常
                ClipboardListView.Opt("+Redraw")
                return
            }
        }
        
        ResultTable := ""
        ; 【参考 ClipboardHistoryPanel.ahk】从 ClipMain 表查询数据
        ; 检查字段是否存在，动态构建查询
        SQL := "PRAGMA table_info(ClipMain)"
        tableInfo := ""
        hasLastCopyTime := false
        hasCopyCount := false
        
        if (ClipboardFTS5DB.GetTable(SQL, &tableInfo)) {
            if (tableInfo.HasRows && tableInfo.Rows.Length > 0) {
                Loop tableInfo.Rows.Length {
                    row := tableInfo.Rows[A_Index]
                    columnName := row[2]  ; 列名在第2列
                    if (columnName = "LastCopyTime") {
                        hasLastCopyTime := true
                    }
                    if (columnName = "CopyCount") {
                        hasCopyCount := true
                    }
                }
            }
        }
        
        ; 根据字段存在情况构建查询
        selectFields := "ID, Content, DataType, SourceApp, SourcePath, CharCount, Timestamp"
        if (hasLastCopyTime) {
            selectFields .= ", LastCopyTime"
        } else {
            selectFields .= ", Timestamp AS LastCopyTime"
        }
        if (hasCopyCount) {
            selectFields .= ", CopyCount"
        } else {
            selectFields .= ", 1 AS CopyCount"
        }
        
        ; 获取搜索关键词（如果有）
        SearchKeyword := ""
        try {
            if (GuiID_ClipboardManager && IsObject(GuiID_ClipboardManager)) {
                SearchEdit := GuiID_ClipboardManager["ClipboardSearchEdit"]
                if (SearchEdit && IsObject(SearchEdit)) {
                    SearchKeyword := Trim(SearchEdit.Value)
                }
            }
        } catch {
        }
        
        ; 获取限制值
        EverythingLimit := ClipboardManagementEverythingLimit > 0 ? ClipboardManagementEverythingLimit : 50
        
        ; 创建 ImageList 用于显示图标（如果还没有创建）
        static ClipboardImageList := 0
        static IconCache := Map()
        if (!ClipboardImageList) {
            ; 创建 ImageList：16x16 图标，支持 32 位色
            ClipboardImageList := IL_Create(10, 10, 0)  ; 初始容量 10，增长 10
            ; 设置 ListView 的 ImageList
            try {
                LV_Hwnd := ClipboardListView.Hwnd
                ; LVM_SETIMAGELIST = 0x1003, LVSIL_SMALL = 0x0001
                SendMessage(0x1003, 0x0001, ClipboardImageList, LV_Hwnd)
            } catch as err {
            }
        }
        
        ; 【新增】根据分类执行不同的搜索逻辑
        ClipboardItems := []
        TotalItems := 0
        
        ; 【修改】参考 ClipboardHistoryPanel：当 CurrentCategory 为空字符串时，不添加过滤条件，查询所有数据
        ; 根据分类选择数据源
        if (CurrentCategory == "" || CurrentCategory == "All" || CurrentCategory == "全部") {
            ; ========== 全部：显示剪贴板、文件、提示词 ==========
            ; 【修复】参考 ClipboardHistoryPanel 的实现：使用空数组作为 whereConditions，只在有搜索关键词时添加条件
            ; 这样可以确保当没有搜索关键词时，查询所有剪贴板数据
            ; 1. 剪贴板数据
            whereConditions := []
            
            if (SearchKeyword != "") {
                ; 转义关键词（用于 LIKE 查询）
                escapedKeyword := StrReplace(SearchKeyword, "'", "''")
                escapedKeyword := StrReplace(escapedKeyword, "\", "\\")
                escapedKeyword := StrReplace(escapedKeyword, "%", "\%")
                escapedKeyword := StrReplace(escapedKeyword, "_", "\_")
                
                ; 检查 FTS5 虚拟表是否存在
                SQL := "SELECT name FROM sqlite_master WHERE type='table' AND name='ClipboardHistory'"
                table := ""
                hasFTS5Table := false
                if (ClipboardFTS5DB.GetTable(SQL, &table)) {
                    if (table.HasRows && table.Rows.Length > 0) {
                        hasFTS5Table := true
                    }
                }
                
                ; 对于短关键词（1-2个字符）或包含特殊字符的，使用 LIKE 查询
                ; 【修复】参考 ClipboardHistoryPanel：使用简化的正则表达式，移除 Unicode 转义
                keywordLen := StrLen(SearchKeyword)
                useLikeQuery := (keywordLen <= 2) || !RegExMatch(SearchKeyword, "^[\w\s]+$")
                
                ; 【修复】确保短关键词（<=2个字符）始终使用 LIKE 查询，避免 FTS5 查询问题
                if (hasFTS5Table && !useLikeQuery && keywordLen > 3) {
                    ; 使用 FTS5 MATCH 语法（仅适用于长关键词且不包含中文的情况）
                    ftsEscapedKeyword := StrReplace(SearchKeyword, "'", "''")
                    ftsEscapedKeyword := StrReplace(ftsEscapedKeyword, "\", "\\")
                    ftsEscapedKeyword := StrReplace(ftsEscapedKeyword, '"', '""')
                    
                    ; 如果关键词包含空格，使用短语匹配；否则使用全文匹配（不使用前缀匹配，因为中文词可能不是独立词）
                    if (InStr(ftsEscapedKeyword, " ")) {
                        ftsQuery := '"' . ftsEscapedKeyword . '"'
                    } else {
                        ; 修复：对于中文单字或词，使用全文匹配而不是前缀匹配
                        ftsQuery := ftsEscapedKeyword
                    }
                    
                    ; 使用 FTS5 表进行搜索（MATCH 语法）
                    ; 只搜索 FTS5 表的内容，不搜索 DataType 字段（DataType 过滤由标签条件处理）
                    whereConditions.Push("ID IN (SELECT rowid FROM ClipboardHistory WHERE ClipboardHistory MATCH '" . ftsQuery . "')")
                } else {
                    ; 使用 LIKE 查询（适用于短关键词、包含中文的关键词或 FTS5 不可用）
                    ; 搜索 Content 和 SourceApp 字段（DataType 过滤由标签条件处理）
                    ; 【修复】确保 LIKE 查询正确构建，使用单引号包裹转义后的关键词
                    whereConditions.Push("(Content LIKE '%" . escapedKeyword . "%' OR SourceApp LIKE '%" . escapedKeyword . "%')")
                }
            }
            
            ; 构建SQL查询（从 ClipMain 表查询，但使用 FTS5 进行搜索）
            ; 【修复】参考 ClipboardHistoryPanel：当 whereConditions 为空时，查询所有数据（不添加 WHERE 子句）
            SQL := "SELECT " . selectFields . " FROM ClipMain"
            if (whereConditions.Length > 0) {
                SQL .= " WHERE " . whereConditions[1]
                Loop whereConditions.Length - 1 {
                    SQL .= " AND " . whereConditions[A_Index + 1]
                }
            }
            ; 【修复】使用正确的排序字段（参考 ClipboardHistoryPanel 使用 LastCopyTime 或 Timestamp）
            orderByField := hasLastCopyTime ? "LastCopyTime" : "Timestamp"
            SQL .= " ORDER BY " . orderByField . " DESC LIMIT " . EverythingLimit
            
            ; 【调试】记录SQL查询（启用调试日志）
            FileAppend("[" . FormatTime(, "yyyy-MM-dd HH:mm:ss") . "] 全部标签SQL查询: " . SQL . "`n", A_ScriptDir "\clipboard_debug.log")
            
            ResultTable := 0
            ; 【修复】确保查询执行成功，并正确处理结果
            querySuccess := ClipboardFTS5DB.GetTable(SQL, &ResultTable)
            if (querySuccess && ResultTable && ResultTable.HasProp("Rows")) {
                ; 【调试】记录查询结果数量
                FileAppend("[" . FormatTime(, "yyyy-MM-dd HH:mm:ss") . "] 全部标签查询成功，结果数: " . (ResultTable.HasProp("Rows") ? ResultTable.Rows.Length : 0) . "`n", A_ScriptDir "\clipboard_debug.log")
                
                ; 【修复】创建列名映射，使用 Map 对象访问而非数组索引
                columnNames := []
                columnIndexMap := Map()
                if (ResultTable.HasNames && ResultTable.ColumnNames.Length > 0) {
                    columnNames := ResultTable.ColumnNames
                    Loop columnNames.Length {
                        colName := columnNames[A_Index]
                        columnIndexMap[colName] := A_Index
                    }
                }
                
                for Index, Row in ResultTable.Rows {
                    ; 【修复】使用 Map 方式访问 Row 对象，而非数组索引
                    rowData := Map()
                    
                    if (columnIndexMap.Count > 0) {
                        ; 使用列名映射访问（正确方式）
                        if (columnIndexMap.Has("ID")) {
                            rowData["ID"] := Row[columnIndexMap["ID"]]
                        }
                        if (columnIndexMap.Has("Content")) {
                            rowData["Content"] := Row[columnIndexMap["Content"]]
                        }
                        if (columnIndexMap.Has("DataType")) {
                            rowData["DataType"] := Row[columnIndexMap["DataType"]]
                        }
                        if (columnIndexMap.Has("SourceApp")) {
                            rowData["SourceApp"] := Row[columnIndexMap["SourceApp"]]
                        }
                        if (columnIndexMap.Has("SourcePath")) {
                            rowData["SourcePath"] := Row[columnIndexMap["SourcePath"]]
                        }
                        if (columnIndexMap.Has("CharCount")) {
                            rowData["CharCount"] := Row[columnIndexMap["CharCount"]]
                        }
                        if (columnIndexMap.Has("Timestamp")) {
                            rowData["Timestamp"] := Row[columnIndexMap["Timestamp"]]
                        }
                        if (columnIndexMap.Has("LastCopyTime")) {
                            rowData["LastCopyTime"] := Row[columnIndexMap["LastCopyTime"]]
                        }
                        if (columnIndexMap.Has("CopyCount")) {
                            rowData["CopyCount"] := Row[columnIndexMap["CopyCount"]]
                        }
                        if (columnIndexMap.Has("ImagePath")) {
                            rowData["ImagePath"] := Row[columnIndexMap["ImagePath"]]
                        }
                    } else {
                        ; 后备方案：按固定顺序读取
                        if (Row.HasProp("Length") && Row.Length >= 1) {
                            rowData["ID"] := Row[1]
                        }
                        if (Row.HasProp("Length") && Row.Length >= 2) {
                            rowData["Content"] := Row[2]
                        }
                        if (Row.HasProp("Length") && Row.Length >= 3) {
                            rowData["DataType"] := Row[3]
                        }
                        if (Row.HasProp("Length") && Row.Length >= 4) {
                            rowData["SourceApp"] := Row[4]
                        }
                        if (Row.HasProp("Length") && Row.Length >= 5) {
                            rowData["SourcePath"] := Row[5]
                        }
                        if (Row.HasProp("Length") && Row.Length >= 6) {
                            rowData["CharCount"] := Row[6]
                        }
                        if (Row.HasProp("Length") && Row.Length >= 7) {
                            rowData["Timestamp"] := Row[7]
                        }
                        if (Row.HasProp("Length") && Row.Length >= 8) {
                            rowData["LastCopyTime"] := Row[8]
                        }
                        if (Row.HasProp("Length") && Row.Length >= 9) {
                            rowData["CopyCount"] := Row[9]
                        }
                        if (Row.HasProp("Length") && Row.Length >= 10) {
                            rowData["ImagePath"] := Row[10]
                        }
                    }
                    
                    ; 确保所有必需字段都有值
                    if (!rowData.Has("ID") || rowData["ID"] = "") {
                        continue
                    }
                    if (!rowData.Has("Content") || rowData["Content"] = "") {
                        continue
                    }
                    
                    ID := Integer(rowData["ID"])
                    Content := String(rowData["Content"])
                    DataType := rowData.Has("DataType") && rowData["DataType"] != "" ? String(rowData["DataType"]) : "Text"
                    SourceApp := rowData.Has("SourceApp") && rowData["SourceApp"] != "" ? String(rowData["SourceApp"]) : ""
                    SourcePath := rowData.Has("SourcePath") && rowData["SourcePath"] != "" ? String(rowData["SourcePath"]) : ""
                    CharCount := rowData.Has("CharCount") && rowData["CharCount"] != "" && rowData["CharCount"] != 0 ? Integer(rowData["CharCount"]) : 0
                    Timestamp := rowData.Has("Timestamp") && rowData["Timestamp"] != "" ? String(rowData["Timestamp"]) : ""
                    LastCopyTime := rowData.Has("LastCopyTime") && rowData["LastCopyTime"] != "" ? String(rowData["LastCopyTime"]) : Timestamp
                    CopyCount := rowData.Has("CopyCount") && rowData["CopyCount"] != "" && rowData["CopyCount"] != 0 ? Integer(rowData["CopyCount"]) : 1
                            
                            IconIndex := 0
                            if (SourcePath != "" && FileExist(SourcePath)) {
                                if (IconCache.Has(SourcePath)) {
                                    IconIndex := IconCache[SourcePath]
                                } else {
                                    try {
                                        IconIndex := IL_Add(ClipboardImageList, SourcePath, 0)
                                        if (IconIndex > 0) {
                                            IconCache[SourcePath] := IconIndex
                                        }
                                    } catch {
                                    }
                                }
                            }
                            
                            ClipboardItems.Push({ID: ID, Content: Content, DataType: DataType, SourceApp: SourceApp, SourcePath: SourcePath, CharCount: CharCount, Timestamp: Timestamp, LastCopyTime: LastCopyTime, CopyCount: CopyCount, IconIndex: IconIndex})
                            TotalItems++
                        }
                }
            
            ; 2. 文件数据（如果有搜索关键词）
            ; 【修复说明】文件数据只在有搜索关键词时查询是合理的，因为查询所有文件会非常慢
            ; 但如果用户期望"全部"标签显示所有文件，可以考虑添加一个选项或限制数量
            if (SearchKeyword != "" && StrLen(SearchKeyword) > 1) {
                try {
                    EverythingResults := GetEverythingResults(SearchKeyword, EverythingLimit, true)
                    for index, result in EverythingResults {
                        if (Type(result) = "Map") {
                            path := result["Path"]
                            isDirectory := result["IsDirectory"]
                            fileSize := result.Has("Size") ? result["Size"] : 0
                            dateModified := result.Has("DateModified") ? result["DateModified"] : 0
                            
                            SplitPath(path, &FileName, &DirPath, &Ext, &NameNoExt)
                            
                            IconIndex := 0
                            if (IconCache.Has(path)) {
                                IconIndex := IconCache[path]
                            } else {
                                try {
                                    IconIndex := IL_Add(ClipboardImageList, path, 0)
                                    if (IconIndex > 0) {
                                        IconCache[path] := IconIndex
                                    }
                                } catch {
                                }
                            }
                            
                            sizeStr := ""
                            if (!isDirectory && fileSize > 0) {
                                if (fileSize < 1024) {
                                    sizeStr := fileSize . " B"
                                } else if (fileSize < 1048576) {
                                    sizeStr := Round(fileSize / 1024, 2) . " KB"
                                } else if (fileSize < 1073741824) {
                                    sizeStr := Round(fileSize / 1048576, 2) . " MB"
                                } else {
                                    sizeStr := Round(fileSize / 1073741824, 2) . " GB"
                                }
                            }
                            
                            dateStr := ""
                            if (dateModified > 0) {
                                try {
                                    fileTime := Buffer(8)
                                    NumPut("Int64", dateModified, fileTime)
                                    localFileTime := Buffer(8)
                                    if (DllCall("FileTimeToLocalFileTime", "Ptr", fileTime.Ptr, "Ptr", localFileTime.Ptr)) {
                                        systemTime := Buffer(16)
                                        if (DllCall("FileTimeToSystemTime", "Ptr", localFileTime.Ptr, "Ptr", systemTime.Ptr)) {
                                            year := NumGet(systemTime, 0, "UShort")
                                            month := NumGet(systemTime, 2, "UShort")
                                            day := NumGet(systemTime, 4, "UShort")
                                            hour := NumGet(systemTime, 6, "UShort")
                                            minute := NumGet(systemTime, 8, "UShort")
                                            dateStr := Format("{:04d}-{:02d}-{:02d} {:02d}:{:02d}", year, month, day, hour, minute)
                                        }
                                    }
                                } catch {
                                }
                            }
                            
                            fileItem := Map()
                            fileItem["ID"] := 0
                            fileItem["Content"] := path
                            fileItem["DataType"] := isDirectory ? "Folder" : "File"
                            fileItem["SourceApp"] := "文件系统"
                            fileItem["SourcePath"] := path
                            fileItem["CharCount"] := 0
                            fileItem["Timestamp"] := dateStr
                            fileItem["LastCopyTime"] := dateStr
                            fileItem["CopyCount"] := 1
                            fileItem["IconIndex"] := IconIndex
                            fileItem["FileSize"] := sizeStr
                            
                            ClipboardItems.Push(fileItem)
                            TotalItems++
                        }
                    }
                } catch {
                }
            }
            
            ; 3. 提示词数据（如果有搜索关键词）
            if (SearchKeyword != "") {
                try {
                    TemplateResults := SearchPromptTemplates(SearchKeyword, EverythingLimit, 0)
                    for index, templateResult in TemplateResults {
                        if (Type(templateResult) = "Map" && templateResult.Has("Content")) {
                            templateItem := Map()
                            templateItem["ID"] := templateResult.Has("ID") ? templateResult["ID"] : 0
                            templateItem["Content"] := templateResult["Content"]
                            templateItem["DataType"] := "Template"
                            templateItem["SourceApp"] := templateResult.Has("Metadata") && templateResult["Metadata"].Has("Category") ? templateResult["Metadata"]["Category"] : "提示词"
                            templateItem["SourcePath"] := ""
                            templateItem["CharCount"] := StrLen(templateResult["Content"])
                            templateItem["Timestamp"] := ""
                            templateItem["LastCopyTime"] := ""
                            templateItem["CopyCount"] := 1
                            templateItem["IconIndex"] := 0
                            templateItem["FileSize"] := "-"
                            templateItem["Title"] := templateResult.Has("Title") ? templateResult["Title"] : ""
                            
                            ClipboardItems.Push(templateItem)
                            TotalItems++
                        }
                    }
                } catch {
                }
            }
            
            ; 4. 配置项数据（软件内部选项，如果有搜索关键词）
            if (SearchKeyword != "") {
                try {
                    ConfigResults := SearchConfigItems(SearchKeyword, EverythingLimit, 0)
                    for index, configResult in ConfigResults {
                        if (Type(configResult) = "Map" && configResult.Has("Content")) {
                            configItem := Map()
                            configItem["ID"] := configResult.Has("ID") ? configResult["ID"] : 0
                            configItem["Content"] := configResult["Content"]
                            configItem["DataType"] := "Config"
                            configItem["SourceApp"] := configResult.Has("DataTypeName") ? configResult["DataTypeName"] : "配置项"
                            configItem["SourcePath"] := ""
                            configItem["CharCount"] := StrLen(configResult["Content"])
                            configItem["Timestamp"] := ""
                            configItem["LastCopyTime"] := ""
                            configItem["CopyCount"] := 1
                            configItem["IconIndex"] := 0
                            configItem["FileSize"] := "-"
                            configItem["Title"] := configResult.Has("Title") ? configResult["Title"] : ""
                            ; 保存配置项的元数据，用于跳转
                            if (configResult.Has("Metadata")) {
                                configItem["Metadata"] := configResult["Metadata"]
                            }
                            if (configResult.Has("ActionParams")) {
                                configItem["ActionParams"] := configResult["ActionParams"]
                            }
                            
                            ClipboardItems.Push(configItem)
                            TotalItems++
                        }
                    }
                } catch {
                }
            }
        } else if (CurrentCategory == "CapsLockC") {
            ; ========== CapsLock+C：显示DataType为Stack的数据 ==========
            whereConditions := []
            whereConditions.Push("DataType = 'Stack'")
            
            if (SearchKeyword != "") {
                ; 转义关键词（用于 LIKE 查询）
                escapedKeyword := StrReplace(SearchKeyword, "'", "''")
                escapedKeyword := StrReplace(escapedKeyword, "\", "\\")
                escapedKeyword := StrReplace(escapedKeyword, "%", "\%")
                escapedKeyword := StrReplace(escapedKeyword, "_", "\_")
                
                ; 检查 FTS5 虚拟表是否存在
                SQL := "SELECT name FROM sqlite_master WHERE type='table' AND name='ClipboardHistory'"
                table := ""
                hasFTS5Table := false
                if (ClipboardFTS5DB.GetTable(SQL, &table)) {
                    if (table.HasRows && table.Rows.Length > 0) {
                        hasFTS5Table := true
                    }
                }
                
                ; 对于短关键词（1-3个字符）或包含特殊字符的，使用 LIKE 查询
                keywordLen := StrLen(SearchKeyword)
                useLikeQuery := (keywordLen <= 3) || !RegExMatch(SearchKeyword, "^[\w\s\u4e00-\u9fff]+$")
                
                if (hasFTS5Table && !useLikeQuery) {
                    ; 使用 FTS5 MATCH 语法（适用于长关键词，>=4个字符）
                    ftsEscapedKeyword := StrReplace(SearchKeyword, "'", "''")
                    ftsEscapedKeyword := StrReplace(ftsEscapedKeyword, "\", "\\")
                    ftsEscapedKeyword := StrReplace(ftsEscapedKeyword, '"', '""')
                    
                    ; 如果关键词包含空格，使用短语匹配；否则使用全文匹配
                    if (InStr(ftsEscapedKeyword, " ")) {
                        ftsQuery := '"' . ftsEscapedKeyword . '"'
                    } else {
                        ftsQuery := ftsEscapedKeyword
                    }
                    
                    ; 使用 FTS5 表进行搜索（MATCH 语法）
                    whereConditions.Push("ID IN (SELECT rowid FROM ClipboardHistory WHERE ClipboardHistory MATCH '" . ftsQuery . "')")
                } else {
                    ; 使用 LIKE 查询（适用于短关键词或 FTS5 不可用）
                    whereConditions.Push("(Content LIKE '%" . escapedKeyword . "%' OR SourceApp LIKE '%" . escapedKeyword . "%')")
                }
            }
            
            ; 构建SQL查询
            SQL := "SELECT " . selectFields . " FROM ClipMain"
            if (whereConditions.Length > 0) {
                SQL .= " WHERE " . whereConditions[1]
                Loop whereConditions.Length - 1 {
                    SQL .= " AND " . whereConditions[A_Index + 1]
                }
            }
            ; 【修复】使用正确的排序字段（参考 ClipboardHistoryPanel 使用 LastCopyTime 或 Timestamp）
            orderByField := hasLastCopyTime ? "LastCopyTime" : "Timestamp"
            SQL .= " ORDER BY " . orderByField . " DESC LIMIT " . EverythingLimit
            ResultTable := 0
            if (ClipboardFTS5DB.GetTable(SQL, &ResultTable) && ResultTable && ResultTable.HasProp("Rows")) {
                ; 创建列名映射
                columnNames := []
                columnIndexMap := Map()
                if (ResultTable.HasNames && ResultTable.ColumnNames.Length > 0) {
                    columnNames := ResultTable.ColumnNames
                    Loop columnNames.Length {
                        colName := columnNames[A_Index]
                        columnIndexMap[colName] := A_Index
                    }
                }

                for Index, Row in ResultTable.Rows {
                    rowData := Map()
                    
                    if (columnIndexMap.Count > 0) {
                        ; 使用列名映射访问（正确方式）
                        if (columnIndexMap.Has("ID")) {
                            rowData["ID"] := Row[columnIndexMap["ID"]]
                        }
                        if (columnIndexMap.Has("Content")) {
                            rowData["Content"] := Row[columnIndexMap["Content"]]
                        }
                        if (columnIndexMap.Has("DataType")) {
                            rowData["DataType"] := Row[columnIndexMap["DataType"]]
                        }
                        if (columnIndexMap.Has("SourceApp")) {
                            rowData["SourceApp"] := Row[columnIndexMap["SourceApp"]]
                        }
                        if (columnIndexMap.Has("SourcePath")) {
                            rowData["SourcePath"] := Row[columnIndexMap["SourcePath"]]
                        }
                        if (columnIndexMap.Has("CharCount")) {
                            rowData["CharCount"] := Row[columnIndexMap["CharCount"]]
                        }
                        if (columnIndexMap.Has("Timestamp")) {
                            rowData["Timestamp"] := Row[columnIndexMap["Timestamp"]]
                        }
                        if (columnIndexMap.Has("LastCopyTime")) {
                            rowData["LastCopyTime"] := Row[columnIndexMap["LastCopyTime"]]
                        }
                        if (columnIndexMap.Has("CopyCount")) {
                            rowData["CopyCount"] := Row[columnIndexMap["CopyCount"]]
                        }
                        if (columnIndexMap.Has("ImagePath")) {
                            rowData["ImagePath"] := Row[columnIndexMap["ImagePath"]]
                        }
                    } else {
                        ; 后备方案：按固定顺序读取
                        if (Row.HasProp("Length") && Row.Length >= 1) {
                            rowData["ID"] := Row[1]
                        }
                        if (Row.HasProp("Length") && Row.Length >= 2) {
                            rowData["Content"] := Row[2]
                        }
                        if (Row.HasProp("Length") && Row.Length >= 3) {
                            rowData["DataType"] := Row[3]
                        }
                        if (Row.HasProp("Length") && Row.Length >= 4) {
                            rowData["SourceApp"] := Row[4]
                        }
                        if (Row.HasProp("Length") && Row.Length >= 5) {
                            rowData["SourcePath"] := Row[5]
                        }
                        if (Row.HasProp("Length") && Row.Length >= 6) {
                            rowData["CharCount"] := Row[6]
                        }
                        if (Row.HasProp("Length") && Row.Length >= 7) {
                            rowData["Timestamp"] := Row[7]
                        }
                        if (Row.HasProp("Length") && Row.Length >= 8) {
                            rowData["LastCopyTime"] := Row[8]
                        }
                        if (Row.HasProp("Length") && Row.Length >= 9) {
                            rowData["CopyCount"] := Row[9]
                        }
                        if (Row.HasProp("Length") && Row.Length >= 10) {
                            rowData["ImagePath"] := Row[10]
                        }
                    }
                    
                    ; 确保所有必需字段都有值
                    if (!rowData.Has("ID") || rowData["ID"] = "") {
                        continue
                    }
                    if (!rowData.Has("Content") || rowData["Content"] = "") {
                        continue
                    }
                    if (!rowData.Has("DataType") || rowData["DataType"] = "") {
                        rowData["DataType"] := "Text"
                    }
                    if (!rowData.Has("SourceApp") || rowData["SourceApp"] = "") {
                        rowData["SourceApp"] := ""
                    }
                    if (!rowData.Has("SourcePath")) {
                        rowData["SourcePath"] := ""
                    }
                    if (!rowData.Has("CharCount") || rowData["CharCount"] = "" || rowData["CharCount"] = 0) {
                        rowData["CharCount"] := StrLen(rowData["Content"])
                    }
                    if (!rowData.Has("Timestamp") || rowData["Timestamp"] = "") {
                        rowData["Timestamp"] := ""
                    }
                    if (!rowData.Has("LastCopyTime") || rowData["LastCopyTime"] = "") {
                        rowData["LastCopyTime"] := rowData["Timestamp"]
                    }
                    if (!rowData.Has("CopyCount") || rowData["CopyCount"] = "" || rowData["CopyCount"] = 0) {
                        rowData["CopyCount"] := 1
                    }
                    
                    ID := Integer(rowData["ID"])
                    Content := String(rowData["Content"])
                    DataType := String(rowData["DataType"])
                    SourceApp := String(rowData["SourceApp"])
                    SourcePath := String(rowData["SourcePath"])
                    CharCount := Integer(rowData["CharCount"])
                    Timestamp := String(rowData["Timestamp"])
                    LastCopyTime := String(rowData["LastCopyTime"])
                    CopyCount := Integer(rowData["CopyCount"])
                    
                    IconIndex := 0
                    if (SourcePath != "" && FileExist(SourcePath)) {
                        if (IconCache.Has(SourcePath)) {
                            IconIndex := IconCache[SourcePath]
                        } else {
                            try {
                                IconIndex := IL_Add(ClipboardImageList, SourcePath, 0)
                                if (IconIndex > 0) {
                                    IconCache[SourcePath] := IconIndex
                                }
                            } catch {
                            }
                        }
                    }
                    
                    ClipboardItems.Push({ID: ID, Content: Content, DataType: DataType, SourceApp: SourceApp, SourcePath: SourcePath, CharCount: CharCount, Timestamp: Timestamp, LastCopyTime: LastCopyTime, CopyCount: CopyCount, IconIndex: IconIndex})
                    TotalItems++
                }
            }
        } else if (CurrentCategory == "Text") {
            ; ========== 文本：显示DataType为Text的数据 ==========
            whereConditions := []
            whereConditions.Push("DataType = 'Text'")
            
            if (SearchKeyword != "") {
                ; 转义关键词（用于 LIKE 查询）
                escapedKeyword := StrReplace(SearchKeyword, "'", "''")
                escapedKeyword := StrReplace(escapedKeyword, "\", "\\")
                escapedKeyword := StrReplace(escapedKeyword, "%", "\%")
                escapedKeyword := StrReplace(escapedKeyword, "_", "\_")
                
                ; 检查 FTS5 虚拟表是否存在
                SQL := "SELECT name FROM sqlite_master WHERE type='table' AND name='ClipboardHistory'"
                table := ""
                hasFTS5Table := false
                if (ClipboardFTS5DB.GetTable(SQL, &table)) {
                    if (table.HasRows && table.Rows.Length > 0) {
                        hasFTS5Table := true
                    }
                }
                
                ; 对于短关键词（1-3个字符）或包含特殊字符的，使用 LIKE 查询
                keywordLen := StrLen(SearchKeyword)
                useLikeQuery := (keywordLen <= 3) || !RegExMatch(SearchKeyword, "^[\w\s\u4e00-\u9fff]+$")
                
                if (hasFTS5Table && !useLikeQuery) {
                    ; 使用 FTS5 MATCH 语法（适用于长关键词，>=4个字符）
                    ftsEscapedKeyword := StrReplace(SearchKeyword, "'", "''")
                    ftsEscapedKeyword := StrReplace(ftsEscapedKeyword, "\", "\\")
                    ftsEscapedKeyword := StrReplace(ftsEscapedKeyword, '"', '""')
                    
                    ; 如果关键词包含空格，使用短语匹配；否则使用全文匹配
                    if (InStr(ftsEscapedKeyword, " ")) {
                        ftsQuery := '"' . ftsEscapedKeyword . '"'
                    } else {
                        ftsQuery := ftsEscapedKeyword
                    }
                    
                    ; 使用 FTS5 表进行搜索（MATCH 语法）
                    whereConditions.Push("ID IN (SELECT rowid FROM ClipboardHistory WHERE ClipboardHistory MATCH '" . ftsQuery . "')")
                } else {
                    ; 使用 LIKE 查询（适用于短关键词或 FTS5 不可用）
                    whereConditions.Push("(Content LIKE '%" . escapedKeyword . "%' OR SourceApp LIKE '%" . escapedKeyword . "%')")
                }
            }
            
            ; 构建SQL查询
            SQL := "SELECT " . selectFields . " FROM ClipMain"
            if (whereConditions.Length > 0) {
                SQL .= " WHERE " . whereConditions[1]
                Loop whereConditions.Length - 1 {
                    SQL .= " AND " . whereConditions[A_Index + 1]
                }
            }
            ; 【修复】使用正确的排序字段（参考 ClipboardHistoryPanel 使用 LastCopyTime 或 Timestamp）
            orderByField := hasLastCopyTime ? "LastCopyTime" : "Timestamp"
            SQL .= " ORDER BY " . orderByField . " DESC LIMIT " . EverythingLimit
            ResultTable := 0
            if (ClipboardFTS5DB.GetTable(SQL, &ResultTable) && ResultTable && ResultTable.HasProp("Rows")) {
                ; 创建列名映射
                columnNames := []
                columnIndexMap := Map()
                if (ResultTable.HasNames && ResultTable.ColumnNames.Length > 0) {
                    columnNames := ResultTable.ColumnNames
                    Loop columnNames.Length {
                        colName := columnNames[A_Index]
                        columnIndexMap[colName] := A_Index
                    }
                }

                for Index, Row in ResultTable.Rows {
                    rowData := Map()
                    
                    if (columnIndexMap.Count > 0) {
                        ; 使用列名映射访问（正确方式）
                        if (columnIndexMap.Has("ID")) {
                            rowData["ID"] := Row[columnIndexMap["ID"]]
                        }
                        if (columnIndexMap.Has("Content")) {
                            rowData["Content"] := Row[columnIndexMap["Content"]]
                        }
                        if (columnIndexMap.Has("DataType")) {
                            rowData["DataType"] := Row[columnIndexMap["DataType"]]
                        }
                        if (columnIndexMap.Has("SourceApp")) {
                            rowData["SourceApp"] := Row[columnIndexMap["SourceApp"]]
                        }
                        if (columnIndexMap.Has("SourcePath")) {
                            rowData["SourcePath"] := Row[columnIndexMap["SourcePath"]]
                        }
                        if (columnIndexMap.Has("CharCount")) {
                            rowData["CharCount"] := Row[columnIndexMap["CharCount"]]
                        }
                        if (columnIndexMap.Has("Timestamp")) {
                            rowData["Timestamp"] := Row[columnIndexMap["Timestamp"]]
                        }
                        if (columnIndexMap.Has("LastCopyTime")) {
                            rowData["LastCopyTime"] := Row[columnIndexMap["LastCopyTime"]]
                        }
                        if (columnIndexMap.Has("CopyCount")) {
                            rowData["CopyCount"] := Row[columnIndexMap["CopyCount"]]
                        }
                        if (columnIndexMap.Has("ImagePath")) {
                            rowData["ImagePath"] := Row[columnIndexMap["ImagePath"]]
                        }
                    } else {
                        ; 后备方案：按固定顺序读取
                        if (Row.HasProp("Length") && Row.Length >= 1) {
                            rowData["ID"] := Row[1]
                        }
                        if (Row.HasProp("Length") && Row.Length >= 2) {
                            rowData["Content"] := Row[2]
                        }
                        if (Row.HasProp("Length") && Row.Length >= 3) {
                            rowData["DataType"] := Row[3]
                        }
                        if (Row.HasProp("Length") && Row.Length >= 4) {
                            rowData["SourceApp"] := Row[4]
                        }
                        if (Row.HasProp("Length") && Row.Length >= 5) {
                            rowData["SourcePath"] := Row[5]
                        }
                        if (Row.HasProp("Length") && Row.Length >= 6) {
                            rowData["CharCount"] := Row[6]
                        }
                        if (Row.HasProp("Length") && Row.Length >= 7) {
                            rowData["Timestamp"] := Row[7]
                        }
                        if (Row.HasProp("Length") && Row.Length >= 8) {
                            rowData["LastCopyTime"] := Row[8]
                        }
                        if (Row.HasProp("Length") && Row.Length >= 9) {
                            rowData["CopyCount"] := Row[9]
                        }
                        if (Row.HasProp("Length") && Row.Length >= 10) {
                            rowData["ImagePath"] := Row[10]
                        }
                    }
                    
                    ; 确保所有必需字段都有值
                    if (!rowData.Has("ID") || rowData["ID"] = "") {
                        continue
                    }
                    if (!rowData.Has("Content") || rowData["Content"] = "") {
                        continue
                    }
                    if (!rowData.Has("DataType") || rowData["DataType"] = "") {
                        rowData["DataType"] := "Text"
                    }
                    if (!rowData.Has("SourceApp") || rowData["SourceApp"] = "") {
                        rowData["SourceApp"] := ""
                    }
                    if (!rowData.Has("SourcePath")) {
                        rowData["SourcePath"] := ""
                    }
                    if (!rowData.Has("CharCount") || rowData["CharCount"] = "" || rowData["CharCount"] = 0) {
                        rowData["CharCount"] := StrLen(rowData["Content"])
                    }
                    if (!rowData.Has("Timestamp") || rowData["Timestamp"] = "") {
                        rowData["Timestamp"] := ""
                    }
                    if (!rowData.Has("LastCopyTime") || rowData["LastCopyTime"] = "") {
                        rowData["LastCopyTime"] := rowData["Timestamp"]
                    }
                    if (!rowData.Has("CopyCount") || rowData["CopyCount"] = "" || rowData["CopyCount"] = 0) {
                        rowData["CopyCount"] := 1
                    }
                    
                    ID := Integer(rowData["ID"])
                    Content := String(rowData["Content"])
                    DataType := String(rowData["DataType"])
                    SourceApp := String(rowData["SourceApp"])
                    SourcePath := String(rowData["SourcePath"])
                    CharCount := Integer(rowData["CharCount"])
                    Timestamp := String(rowData["Timestamp"])
                    LastCopyTime := String(rowData["LastCopyTime"])
                    CopyCount := Integer(rowData["CopyCount"])
                    
                    IconIndex := 0
                    if (SourcePath != "" && FileExist(SourcePath)) {
                        if (IconCache.Has(SourcePath)) {
                            IconIndex := IconCache[SourcePath]
                        } else {
                            try {
                                IconIndex := IL_Add(ClipboardImageList, SourcePath, 0)
                                if (IconIndex > 0) {
                                    IconCache[SourcePath] := IconIndex
                                }
                            } catch {
                            }
                        }
                    }
                    
                    ClipboardItems.Push({ID: ID, Content: Content, DataType: DataType, SourceApp: SourceApp, SourcePath: SourcePath, CharCount: CharCount, Timestamp: Timestamp, LastCopyTime: LastCopyTime, CopyCount: CopyCount, IconIndex: IconIndex})
                    TotalItems++
                }
            }
        } else if (CurrentCategory == "Code") {
            ; ========== 代码：显示DataType为Code的数据 ==========
            whereConditions := []
            whereConditions.Push("DataType = 'Code'")
            
            if (SearchKeyword != "") {
                ; 转义关键词（用于 LIKE 查询）
                escapedKeyword := StrReplace(SearchKeyword, "'", "''")
                escapedKeyword := StrReplace(escapedKeyword, "\", "\\")
                escapedKeyword := StrReplace(escapedKeyword, "%", "\%")
                escapedKeyword := StrReplace(escapedKeyword, "_", "\_")
                
                ; 检查 FTS5 虚拟表是否存在
                SQL := "SELECT name FROM sqlite_master WHERE type='table' AND name='ClipboardHistory'"
                table := ""
                hasFTS5Table := false
                if (ClipboardFTS5DB.GetTable(SQL, &table)) {
                    if (table.HasRows && table.Rows.Length > 0) {
                        hasFTS5Table := true
                    }
                }
                
                ; 对于短关键词（1-3个字符）或包含特殊字符的，使用 LIKE 查询
                keywordLen := StrLen(SearchKeyword)
                useLikeQuery := (keywordLen <= 3) || !RegExMatch(SearchKeyword, "^[\w\s\u4e00-\u9fff]+$")
                
                if (hasFTS5Table && !useLikeQuery) {
                    ; 使用 FTS5 MATCH 语法（适用于长关键词，>=4个字符）
                    ftsEscapedKeyword := StrReplace(SearchKeyword, "'", "''")
                    ftsEscapedKeyword := StrReplace(ftsEscapedKeyword, "\", "\\")
                    ftsEscapedKeyword := StrReplace(ftsEscapedKeyword, '"', '""')
                    
                    ; 如果关键词包含空格，使用短语匹配；否则使用全文匹配
                    if (InStr(ftsEscapedKeyword, " ")) {
                        ftsQuery := '"' . ftsEscapedKeyword . '"'
                    } else {
                        ftsQuery := ftsEscapedKeyword
                    }
                    
                    ; 使用 FTS5 表进行搜索（MATCH 语法）
                    whereConditions.Push("ID IN (SELECT rowid FROM ClipboardHistory WHERE ClipboardHistory MATCH '" . ftsQuery . "')")
                } else {
                    ; 使用 LIKE 查询（适用于短关键词或 FTS5 不可用）
                    whereConditions.Push("(Content LIKE '%" . escapedKeyword . "%' OR SourceApp LIKE '%" . escapedKeyword . "%')")
                }
            }
            
            ; 构建SQL查询
            SQL := "SELECT " . selectFields . " FROM ClipMain"
            if (whereConditions.Length > 0) {
                SQL .= " WHERE " . whereConditions[1]
                Loop whereConditions.Length - 1 {
                    SQL .= " AND " . whereConditions[A_Index + 1]
                }
            }
            ; 【修复】使用正确的排序字段（参考 ClipboardHistoryPanel 使用 LastCopyTime 或 Timestamp）
            orderByField := hasLastCopyTime ? "LastCopyTime" : "Timestamp"
            SQL .= " ORDER BY " . orderByField . " DESC LIMIT " . EverythingLimit
            ResultTable := 0
            if (ClipboardFTS5DB.GetTable(SQL, &ResultTable) && ResultTable && ResultTable.HasProp("Rows")) {
                ; 创建列名映射
                columnNames := []
                columnIndexMap := Map()
                if (ResultTable.HasNames && ResultTable.ColumnNames.Length > 0) {
                    columnNames := ResultTable.ColumnNames
                    Loop columnNames.Length {
                        colName := columnNames[A_Index]
                        columnIndexMap[colName] := A_Index
                    }
                }

                for Index, Row in ResultTable.Rows {
                    rowData := Map()
                    
                    if (columnIndexMap.Count > 0) {
                        ; 使用列名映射访问（正确方式）
                        if (columnIndexMap.Has("ID")) {
                            rowData["ID"] := Row[columnIndexMap["ID"]]
                        }
                        if (columnIndexMap.Has("Content")) {
                            rowData["Content"] := Row[columnIndexMap["Content"]]
                        }
                        if (columnIndexMap.Has("DataType")) {
                            rowData["DataType"] := Row[columnIndexMap["DataType"]]
                        }
                        if (columnIndexMap.Has("SourceApp")) {
                            rowData["SourceApp"] := Row[columnIndexMap["SourceApp"]]
                        }
                        if (columnIndexMap.Has("SourcePath")) {
                            rowData["SourcePath"] := Row[columnIndexMap["SourcePath"]]
                        }
                        if (columnIndexMap.Has("CharCount")) {
                            rowData["CharCount"] := Row[columnIndexMap["CharCount"]]
                        }
                        if (columnIndexMap.Has("Timestamp")) {
                            rowData["Timestamp"] := Row[columnIndexMap["Timestamp"]]
                        }
                        if (columnIndexMap.Has("LastCopyTime")) {
                            rowData["LastCopyTime"] := Row[columnIndexMap["LastCopyTime"]]
                        }
                        if (columnIndexMap.Has("CopyCount")) {
                            rowData["CopyCount"] := Row[columnIndexMap["CopyCount"]]
                        }
                        if (columnIndexMap.Has("ImagePath")) {
                            rowData["ImagePath"] := Row[columnIndexMap["ImagePath"]]
                        }
                    } else {
                        ; 后备方案：按固定顺序读取
                        if (Row.HasProp("Length") && Row.Length >= 1) {
                            rowData["ID"] := Row[1]
                        }
                        if (Row.HasProp("Length") && Row.Length >= 2) {
                            rowData["Content"] := Row[2]
                        }
                        if (Row.HasProp("Length") && Row.Length >= 3) {
                            rowData["DataType"] := Row[3]
                        }
                        if (Row.HasProp("Length") && Row.Length >= 4) {
                            rowData["SourceApp"] := Row[4]
                        }
                        if (Row.HasProp("Length") && Row.Length >= 5) {
                            rowData["SourcePath"] := Row[5]
                        }
                        if (Row.HasProp("Length") && Row.Length >= 6) {
                            rowData["CharCount"] := Row[6]
                        }
                        if (Row.HasProp("Length") && Row.Length >= 7) {
                            rowData["Timestamp"] := Row[7]
                        }
                        if (Row.HasProp("Length") && Row.Length >= 8) {
                            rowData["LastCopyTime"] := Row[8]
                        }
                        if (Row.HasProp("Length") && Row.Length >= 9) {
                            rowData["CopyCount"] := Row[9]
                        }
                        if (Row.HasProp("Length") && Row.Length >= 10) {
                            rowData["ImagePath"] := Row[10]
                        }
                    }
                    
                    ; 确保所有必需字段都有值
                    if (!rowData.Has("ID") || rowData["ID"] = "") {
                        continue
                    }
                    if (!rowData.Has("Content") || rowData["Content"] = "") {
                        continue
                    }
                    if (!rowData.Has("DataType") || rowData["DataType"] = "") {
                        rowData["DataType"] := "Text"
                    }
                    if (!rowData.Has("SourceApp") || rowData["SourceApp"] = "") {
                        rowData["SourceApp"] := ""
                    }
                    if (!rowData.Has("SourcePath")) {
                        rowData["SourcePath"] := ""
                    }
                    if (!rowData.Has("CharCount") || rowData["CharCount"] = "" || rowData["CharCount"] = 0) {
                        rowData["CharCount"] := StrLen(rowData["Content"])
                    }
                    if (!rowData.Has("Timestamp") || rowData["Timestamp"] = "") {
                        rowData["Timestamp"] := ""
                    }
                    if (!rowData.Has("LastCopyTime") || rowData["LastCopyTime"] = "") {
                        rowData["LastCopyTime"] := rowData["Timestamp"]
                    }
                    if (!rowData.Has("CopyCount") || rowData["CopyCount"] = "" || rowData["CopyCount"] = 0) {
                        rowData["CopyCount"] := 1
                    }
                    
                    ID := Integer(rowData["ID"])
                    Content := String(rowData["Content"])
                    DataType := String(rowData["DataType"])
                    SourceApp := String(rowData["SourceApp"])
                    SourcePath := String(rowData["SourcePath"])
                    CharCount := Integer(rowData["CharCount"])
                    Timestamp := String(rowData["Timestamp"])
                    LastCopyTime := String(rowData["LastCopyTime"])
                    CopyCount := Integer(rowData["CopyCount"])
                    
                    IconIndex := 0
                    if (SourcePath != "" && FileExist(SourcePath)) {
                        if (IconCache.Has(SourcePath)) {
                            IconIndex := IconCache[SourcePath]
                        } else {
                            try {
                                IconIndex := IL_Add(ClipboardImageList, SourcePath, 0)
                                if (IconIndex > 0) {
                                    IconCache[SourcePath] := IconIndex
                                }
                            } catch {
                            }
                        }
                    }
                    
                    ClipboardItems.Push({ID: ID, Content: Content, DataType: DataType, SourceApp: SourceApp, SourcePath: SourcePath, CharCount: CharCount, Timestamp: Timestamp, LastCopyTime: LastCopyTime, CopyCount: CopyCount, IconIndex: IconIndex})
                    TotalItems++
                }
            }
        } else if (CurrentCategory == "Link") {
            ; ========== 链接：显示DataType为Link的数据 ==========
            whereConditions := []
            whereConditions.Push("DataType = 'Link'")
            
            if (SearchKeyword != "") {
                ; 转义关键词（用于 LIKE 查询）
                escapedKeyword := StrReplace(SearchKeyword, "'", "''")
                escapedKeyword := StrReplace(escapedKeyword, "\", "\\")
                escapedKeyword := StrReplace(escapedKeyword, "%", "\%")
                escapedKeyword := StrReplace(escapedKeyword, "_", "\_")
                
                ; 检查 FTS5 虚拟表是否存在
                SQL := "SELECT name FROM sqlite_master WHERE type='table' AND name='ClipboardHistory'"
                table := ""
                hasFTS5Table := false
                if (ClipboardFTS5DB.GetTable(SQL, &table)) {
                    if (table.HasRows && table.Rows.Length > 0) {
                        hasFTS5Table := true
                    }
                }
                
                ; 对于短关键词（1-3个字符）或包含特殊字符的，使用 LIKE 查询
                keywordLen := StrLen(SearchKeyword)
                useLikeQuery := (keywordLen <= 3) || !RegExMatch(SearchKeyword, "^[\w\s\u4e00-\u9fff]+$")
                
                if (hasFTS5Table && !useLikeQuery) {
                    ; 使用 FTS5 MATCH 语法（适用于长关键词，>=4个字符）
                    ftsEscapedKeyword := StrReplace(SearchKeyword, "'", "''")
                    ftsEscapedKeyword := StrReplace(ftsEscapedKeyword, "\", "\\")
                    ftsEscapedKeyword := StrReplace(ftsEscapedKeyword, '"', '""')
                    
                    ; 如果关键词包含空格，使用短语匹配；否则使用全文匹配
                    if (InStr(ftsEscapedKeyword, " ")) {
                        ftsQuery := '"' . ftsEscapedKeyword . '"'
                    } else {
                        ftsQuery := ftsEscapedKeyword
                    }
                    
                    ; 使用 FTS5 表进行搜索（MATCH 语法）
                    whereConditions.Push("ID IN (SELECT rowid FROM ClipboardHistory WHERE ClipboardHistory MATCH '" . ftsQuery . "')")
                } else {
                    ; 使用 LIKE 查询（适用于短关键词或 FTS5 不可用）
                    whereConditions.Push("(Content LIKE '%" . escapedKeyword . "%' OR SourceApp LIKE '%" . escapedKeyword . "%')")
                }
            }
            
            ; 构建SQL查询
            SQL := "SELECT " . selectFields . " FROM ClipMain"
            if (whereConditions.Length > 0) {
                SQL .= " WHERE " . whereConditions[1]
                Loop whereConditions.Length - 1 {
                    SQL .= " AND " . whereConditions[A_Index + 1]
                }
            }
            ; 【修复】使用正确的排序字段（参考 ClipboardHistoryPanel 使用 LastCopyTime 或 Timestamp）
            orderByField := hasLastCopyTime ? "LastCopyTime" : "Timestamp"
            SQL .= " ORDER BY " . orderByField . " DESC LIMIT " . EverythingLimit
            ResultTable := 0
            if (ClipboardFTS5DB.GetTable(SQL, &ResultTable) && ResultTable && ResultTable.HasProp("Rows")) {
                ; 创建列名映射
                columnNames := []
                columnIndexMap := Map()
                if (ResultTable.HasNames && ResultTable.ColumnNames.Length > 0) {
                    columnNames := ResultTable.ColumnNames
                    Loop columnNames.Length {
                        colName := columnNames[A_Index]
                        columnIndexMap[colName] := A_Index
                    }
                }

                for Index, Row in ResultTable.Rows {
                    rowData := Map()
                    
                    if (columnIndexMap.Count > 0) {
                        ; 使用列名映射访问（正确方式）
                        if (columnIndexMap.Has("ID")) {
                            rowData["ID"] := Row[columnIndexMap["ID"]]
                        }
                        if (columnIndexMap.Has("Content")) {
                            rowData["Content"] := Row[columnIndexMap["Content"]]
                        }
                        if (columnIndexMap.Has("DataType")) {
                            rowData["DataType"] := Row[columnIndexMap["DataType"]]
                        }
                        if (columnIndexMap.Has("SourceApp")) {
                            rowData["SourceApp"] := Row[columnIndexMap["SourceApp"]]
                        }
                        if (columnIndexMap.Has("SourcePath")) {
                            rowData["SourcePath"] := Row[columnIndexMap["SourcePath"]]
                        }
                        if (columnIndexMap.Has("CharCount")) {
                            rowData["CharCount"] := Row[columnIndexMap["CharCount"]]
                        }
                        if (columnIndexMap.Has("Timestamp")) {
                            rowData["Timestamp"] := Row[columnIndexMap["Timestamp"]]
                        }
                        if (columnIndexMap.Has("LastCopyTime")) {
                            rowData["LastCopyTime"] := Row[columnIndexMap["LastCopyTime"]]
                        }
                        if (columnIndexMap.Has("CopyCount")) {
                            rowData["CopyCount"] := Row[columnIndexMap["CopyCount"]]
                        }
                        if (columnIndexMap.Has("ImagePath")) {
                            rowData["ImagePath"] := Row[columnIndexMap["ImagePath"]]
                        }
                    } else {
                        ; 后备方案：按固定顺序读取
                        if (Row.HasProp("Length") && Row.Length >= 1) {
                            rowData["ID"] := Row[1]
                        }
                        if (Row.HasProp("Length") && Row.Length >= 2) {
                            rowData["Content"] := Row[2]
                        }
                        if (Row.HasProp("Length") && Row.Length >= 3) {
                            rowData["DataType"] := Row[3]
                        }
                        if (Row.HasProp("Length") && Row.Length >= 4) {
                            rowData["SourceApp"] := Row[4]
                        }
                        if (Row.HasProp("Length") && Row.Length >= 5) {
                            rowData["SourcePath"] := Row[5]
                        }
                        if (Row.HasProp("Length") && Row.Length >= 6) {
                            rowData["CharCount"] := Row[6]
                        }
                        if (Row.HasProp("Length") && Row.Length >= 7) {
                            rowData["Timestamp"] := Row[7]
                        }
                        if (Row.HasProp("Length") && Row.Length >= 8) {
                            rowData["LastCopyTime"] := Row[8]
                        }
                        if (Row.HasProp("Length") && Row.Length >= 9) {
                            rowData["CopyCount"] := Row[9]
                        }
                        if (Row.HasProp("Length") && Row.Length >= 10) {
                            rowData["ImagePath"] := Row[10]
                        }
                    }
                    
                    ; 确保所有必需字段都有值
                    if (!rowData.Has("ID") || rowData["ID"] = "") {
                        continue
                    }
                    if (!rowData.Has("Content") || rowData["Content"] = "") {
                        continue
                    }
                    if (!rowData.Has("DataType") || rowData["DataType"] = "") {
                        rowData["DataType"] := "Text"
                    }
                    if (!rowData.Has("SourceApp") || rowData["SourceApp"] = "") {
                        rowData["SourceApp"] := ""
                    }
                    if (!rowData.Has("SourcePath")) {
                        rowData["SourcePath"] := ""
                    }
                    if (!rowData.Has("CharCount") || rowData["CharCount"] = "" || rowData["CharCount"] = 0) {
                        rowData["CharCount"] := StrLen(rowData["Content"])
                    }
                    if (!rowData.Has("Timestamp") || rowData["Timestamp"] = "") {
                        rowData["Timestamp"] := ""
                    }
                    if (!rowData.Has("LastCopyTime") || rowData["LastCopyTime"] = "") {
                        rowData["LastCopyTime"] := rowData["Timestamp"]
                    }
                    if (!rowData.Has("CopyCount") || rowData["CopyCount"] = "" || rowData["CopyCount"] = 0) {
                        rowData["CopyCount"] := 1
                    }
                    
                    ID := Integer(rowData["ID"])
                    Content := String(rowData["Content"])
                    DataType := String(rowData["DataType"])
                    SourceApp := String(rowData["SourceApp"])
                    SourcePath := String(rowData["SourcePath"])
                    CharCount := Integer(rowData["CharCount"])
                    Timestamp := String(rowData["Timestamp"])
                    LastCopyTime := String(rowData["LastCopyTime"])
                    CopyCount := Integer(rowData["CopyCount"])
                    
                    IconIndex := 0
                    if (SourcePath != "" && FileExist(SourcePath)) {
                        if (IconCache.Has(SourcePath)) {
                            IconIndex := IconCache[SourcePath]
                        } else {
                            try {
                                IconIndex := IL_Add(ClipboardImageList, SourcePath, 0)
                                if (IconIndex > 0) {
                                    IconCache[SourcePath] := IconIndex
                                }
                            } catch {
                            }
                        }
                    }
                    
                    ClipboardItems.Push({ID: ID, Content: Content, DataType: DataType, SourceApp: SourceApp, SourcePath: SourcePath, CharCount: CharCount, Timestamp: Timestamp, LastCopyTime: LastCopyTime, CopyCount: CopyCount, IconIndex: IconIndex})
                    TotalItems++
                }
            }
        } else if (CurrentCategory == "Image") {
            ; ========== 图片：显示DataType为Image的数据 ==========
            whereConditions := []
            whereConditions.Push("DataType = 'Image'")
            
            if (SearchKeyword != "") {
                ; 转义关键词（用于 LIKE 查询）
                escapedKeyword := StrReplace(SearchKeyword, "'", "''")
                escapedKeyword := StrReplace(escapedKeyword, "\", "\\")
                escapedKeyword := StrReplace(escapedKeyword, "%", "\%")
                escapedKeyword := StrReplace(escapedKeyword, "_", "\_")
                
                ; 检查 FTS5 虚拟表是否存在
                SQL := "SELECT name FROM sqlite_master WHERE type='table' AND name='ClipboardHistory'"
                table := ""
                hasFTS5Table := false
                if (ClipboardFTS5DB.GetTable(SQL, &table)) {
                    if (table.HasRows && table.Rows.Length > 0) {
                        hasFTS5Table := true
                    }
                }
                
                ; 对于短关键词（1-3个字符）或包含特殊字符的，使用 LIKE 查询
                keywordLen := StrLen(SearchKeyword)
                useLikeQuery := (keywordLen <= 3) || !RegExMatch(SearchKeyword, "^[\w\s\u4e00-\u9fff]+$")
                
                if (hasFTS5Table && !useLikeQuery) {
                    ; 使用 FTS5 MATCH 语法（适用于长关键词，>=4个字符）
                    ftsEscapedKeyword := StrReplace(SearchKeyword, "'", "''")
                    ftsEscapedKeyword := StrReplace(ftsEscapedKeyword, "\", "\\")
                    ftsEscapedKeyword := StrReplace(ftsEscapedKeyword, '"', '""')
                    
                    ; 如果关键词包含空格，使用短语匹配；否则使用全文匹配
                    if (InStr(ftsEscapedKeyword, " ")) {
                        ftsQuery := '"' . ftsEscapedKeyword . '"'
                    } else {
                        ftsQuery := ftsEscapedKeyword
                    }
                    
                    ; 使用 FTS5 表进行搜索（MATCH 语法）
                    whereConditions.Push("ID IN (SELECT rowid FROM ClipboardHistory WHERE ClipboardHistory MATCH '" . ftsQuery . "')")
                } else {
                    ; 使用 LIKE 查询（适用于短关键词或 FTS5 不可用）
                    whereConditions.Push("(Content LIKE '%" . escapedKeyword . "%' OR SourceApp LIKE '%" . escapedKeyword . "%')")
                }
            }
            
            ; 构建SQL查询
            SQL := "SELECT " . selectFields . " FROM ClipMain"
            if (whereConditions.Length > 0) {
                SQL .= " WHERE " . whereConditions[1]
                Loop whereConditions.Length - 1 {
                    SQL .= " AND " . whereConditions[A_Index + 1]
                }
            }
            ; 【修复】使用正确的排序字段（参考 ClipboardHistoryPanel 使用 LastCopyTime 或 Timestamp）
            orderByField := hasLastCopyTime ? "LastCopyTime" : "Timestamp"
            SQL .= " ORDER BY " . orderByField . " DESC LIMIT " . EverythingLimit
            ResultTable := 0
            if (ClipboardFTS5DB.GetTable(SQL, &ResultTable) && ResultTable && ResultTable.HasProp("Rows")) {
                ; 创建列名映射
                columnNames := []
                columnIndexMap := Map()
                if (ResultTable.HasNames && ResultTable.ColumnNames.Length > 0) {
                    columnNames := ResultTable.ColumnNames
                    Loop columnNames.Length {
                        colName := columnNames[A_Index]
                        columnIndexMap[colName] := A_Index
                    }
                }

                for Index, Row in ResultTable.Rows {
                    rowData := Map()
                    
                    if (columnIndexMap.Count > 0) {
                        ; 使用列名映射访问（正确方式）
                        if (columnIndexMap.Has("ID")) {
                            rowData["ID"] := Row[columnIndexMap["ID"]]
                        }
                        if (columnIndexMap.Has("Content")) {
                            rowData["Content"] := Row[columnIndexMap["Content"]]
                        }
                        if (columnIndexMap.Has("DataType")) {
                            rowData["DataType"] := Row[columnIndexMap["DataType"]]
                        }
                        if (columnIndexMap.Has("SourceApp")) {
                            rowData["SourceApp"] := Row[columnIndexMap["SourceApp"]]
                        }
                        if (columnIndexMap.Has("SourcePath")) {
                            rowData["SourcePath"] := Row[columnIndexMap["SourcePath"]]
                        }
                        if (columnIndexMap.Has("CharCount")) {
                            rowData["CharCount"] := Row[columnIndexMap["CharCount"]]
                        }
                        if (columnIndexMap.Has("Timestamp")) {
                            rowData["Timestamp"] := Row[columnIndexMap["Timestamp"]]
                        }
                        if (columnIndexMap.Has("LastCopyTime")) {
                            rowData["LastCopyTime"] := Row[columnIndexMap["LastCopyTime"]]
                        }
                        if (columnIndexMap.Has("CopyCount")) {
                            rowData["CopyCount"] := Row[columnIndexMap["CopyCount"]]
                        }
                        if (columnIndexMap.Has("ImagePath")) {
                            rowData["ImagePath"] := Row[columnIndexMap["ImagePath"]]
                        }
                    } else {
                        ; 后备方案：按固定顺序读取
                        if (Row.HasProp("Length") && Row.Length >= 1) {
                            rowData["ID"] := Row[1]
                        }
                        if (Row.HasProp("Length") && Row.Length >= 2) {
                            rowData["Content"] := Row[2]
                        }
                        if (Row.HasProp("Length") && Row.Length >= 3) {
                            rowData["DataType"] := Row[3]
                        }
                        if (Row.HasProp("Length") && Row.Length >= 4) {
                            rowData["SourceApp"] := Row[4]
                        }
                        if (Row.HasProp("Length") && Row.Length >= 5) {
                            rowData["SourcePath"] := Row[5]
                        }
                        if (Row.HasProp("Length") && Row.Length >= 6) {
                            rowData["CharCount"] := Row[6]
                        }
                        if (Row.HasProp("Length") && Row.Length >= 7) {
                            rowData["Timestamp"] := Row[7]
                        }
                        if (Row.HasProp("Length") && Row.Length >= 8) {
                            rowData["LastCopyTime"] := Row[8]
                        }
                        if (Row.HasProp("Length") && Row.Length >= 9) {
                            rowData["CopyCount"] := Row[9]
                        }
                        if (Row.HasProp("Length") && Row.Length >= 10) {
                            rowData["ImagePath"] := Row[10]
                        }
                    }
                    
                    ; 确保所有必需字段都有值
                    if (!rowData.Has("ID") || rowData["ID"] = "") {
                        continue
                    }
                    if (!rowData.Has("Content") || rowData["Content"] = "") {
                        continue
                    }
                    if (!rowData.Has("DataType") || rowData["DataType"] = "") {
                        rowData["DataType"] := "Text"
                    }
                    if (!rowData.Has("SourceApp") || rowData["SourceApp"] = "") {
                        rowData["SourceApp"] := ""
                    }
                    if (!rowData.Has("SourcePath")) {
                        rowData["SourcePath"] := ""
                    }
                    if (!rowData.Has("CharCount") || rowData["CharCount"] = "" || rowData["CharCount"] = 0) {
                        rowData["CharCount"] := StrLen(rowData["Content"])
                    }
                    if (!rowData.Has("Timestamp") || rowData["Timestamp"] = "") {
                        rowData["Timestamp"] := ""
                    }
                    if (!rowData.Has("LastCopyTime") || rowData["LastCopyTime"] = "") {
                        rowData["LastCopyTime"] := rowData["Timestamp"]
                    }
                    if (!rowData.Has("CopyCount") || rowData["CopyCount"] = "" || rowData["CopyCount"] = 0) {
                        rowData["CopyCount"] := 1
                    }
                    
                    ID := Integer(rowData["ID"])
                    Content := String(rowData["Content"])
                    DataType := String(rowData["DataType"])
                    SourceApp := String(rowData["SourceApp"])
                    SourcePath := String(rowData["SourcePath"])
                    CharCount := Integer(rowData["CharCount"])
                    Timestamp := String(rowData["Timestamp"])
                    LastCopyTime := String(rowData["LastCopyTime"])
                    CopyCount := Integer(rowData["CopyCount"])
                    
                    IconIndex := 0
                    if (SourcePath != "" && FileExist(SourcePath)) {
                        if (IconCache.Has(SourcePath)) {
                            IconIndex := IconCache[SourcePath]
                        } else {
                            try {
                                IconIndex := IL_Add(ClipboardImageList, SourcePath, 0)
                                if (IconIndex > 0) {
                                    IconCache[SourcePath] := IconIndex
                                }
                            } catch {
                            }
                        }
                    }
                    
                    ClipboardItems.Push({ID: ID, Content: Content, DataType: DataType, SourceApp: SourceApp, SourcePath: SourcePath, CharCount: CharCount, Timestamp: Timestamp, LastCopyTime: LastCopyTime, CopyCount: CopyCount, IconIndex: IconIndex})
                    TotalItems++
                }
            }
        } else if (CurrentCategory == "Clipboard") {
            ; ========== 剪贴板：显示所有剪贴板数据（普通剪贴板数据）==========
            ; 注意：如果ClipMain表没有SessionID字段，则显示所有数据
            WhereClause := ""
            if (SearchKeyword != "") {
                WhereClause := "WHERE ClipMain MATCH '" . StrReplace(SearchKeyword, "'", "''") . "'"
            }
            ; 【修复】使用正确的排序字段（参考 ClipboardHistoryPanel 使用 LastCopyTime 或 Timestamp）
            orderByField := hasLastCopyTime ? "LastCopyTime" : "Timestamp"
            SQL := "SELECT " . selectFields . " FROM ClipMain " . (WhereClause != "" ? WhereClause : "") . " ORDER BY " . orderByField . " DESC LIMIT " . EverythingLimit
            ResultTable := 0
            if (ClipboardFTS5DB.GetTable(SQL, &ResultTable) && ResultTable && ResultTable.HasProp("Rows")) {
                ; 创建列名映射
                columnNames := []
                columnIndexMap := Map()
                if (ResultTable.HasNames && ResultTable.ColumnNames.Length > 0) {
                    columnNames := ResultTable.ColumnNames
                    Loop columnNames.Length {
                        colName := columnNames[A_Index]
                        columnIndexMap[colName] := A_Index
                    }
                }

                for Index, Row in ResultTable.Rows {
                    rowData := Map()
                    
                    if (columnIndexMap.Count > 0) {
                        ; 使用列名映射访问（正确方式）
                        if (columnIndexMap.Has("ID")) {
                            rowData["ID"] := Row[columnIndexMap["ID"]]
                        }
                        if (columnIndexMap.Has("Content")) {
                            rowData["Content"] := Row[columnIndexMap["Content"]]
                        }
                        if (columnIndexMap.Has("DataType")) {
                            rowData["DataType"] := Row[columnIndexMap["DataType"]]
                        }
                        if (columnIndexMap.Has("SourceApp")) {
                            rowData["SourceApp"] := Row[columnIndexMap["SourceApp"]]
                        }
                        if (columnIndexMap.Has("SourcePath")) {
                            rowData["SourcePath"] := Row[columnIndexMap["SourcePath"]]
                        }
                        if (columnIndexMap.Has("CharCount")) {
                            rowData["CharCount"] := Row[columnIndexMap["CharCount"]]
                        }
                        if (columnIndexMap.Has("Timestamp")) {
                            rowData["Timestamp"] := Row[columnIndexMap["Timestamp"]]
                        }
                        if (columnIndexMap.Has("LastCopyTime")) {
                            rowData["LastCopyTime"] := Row[columnIndexMap["LastCopyTime"]]
                        }
                        if (columnIndexMap.Has("CopyCount")) {
                            rowData["CopyCount"] := Row[columnIndexMap["CopyCount"]]
                        }
                        if (columnIndexMap.Has("ImagePath")) {
                            rowData["ImagePath"] := Row[columnIndexMap["ImagePath"]]
                        }
                    } else {
                        ; 后备方案：按固定顺序读取
                        if (Row.HasProp("Length") && Row.Length >= 1) {
                            rowData["ID"] := Row[1]
                        }
                        if (Row.HasProp("Length") && Row.Length >= 2) {
                            rowData["Content"] := Row[2]
                        }
                        if (Row.HasProp("Length") && Row.Length >= 3) {
                            rowData["DataType"] := Row[3]
                        }
                        if (Row.HasProp("Length") && Row.Length >= 4) {
                            rowData["SourceApp"] := Row[4]
                        }
                        if (Row.HasProp("Length") && Row.Length >= 5) {
                            rowData["SourcePath"] := Row[5]
                        }
                        if (Row.HasProp("Length") && Row.Length >= 6) {
                            rowData["CharCount"] := Row[6]
                        }
                        if (Row.HasProp("Length") && Row.Length >= 7) {
                            rowData["Timestamp"] := Row[7]
                        }
                        if (Row.HasProp("Length") && Row.Length >= 8) {
                            rowData["LastCopyTime"] := Row[8]
                        }
                        if (Row.HasProp("Length") && Row.Length >= 9) {
                            rowData["CopyCount"] := Row[9]
                        }
                        if (Row.HasProp("Length") && Row.Length >= 10) {
                            rowData["ImagePath"] := Row[10]
                        }
                    }
                    
                    ; 确保所有必需字段都有值
                    if (!rowData.Has("ID") || rowData["ID"] = "") {
                        continue
                    }
                    if (!rowData.Has("Content") || rowData["Content"] = "") {
                        continue
                    }
                    if (!rowData.Has("DataType") || rowData["DataType"] = "") {
                        rowData["DataType"] := "Text"
                    }
                    if (!rowData.Has("SourceApp") || rowData["SourceApp"] = "") {
                        rowData["SourceApp"] := ""
                    }
                    if (!rowData.Has("SourcePath")) {
                        rowData["SourcePath"] := ""
                    }
                    if (!rowData.Has("CharCount") || rowData["CharCount"] = "" || rowData["CharCount"] = 0) {
                        rowData["CharCount"] := StrLen(rowData["Content"])
                    }
                    if (!rowData.Has("Timestamp") || rowData["Timestamp"] = "") {
                        rowData["Timestamp"] := ""
                    }
                    if (!rowData.Has("LastCopyTime") || rowData["LastCopyTime"] = "") {
                        rowData["LastCopyTime"] := rowData["Timestamp"]
                    }
                    if (!rowData.Has("CopyCount") || rowData["CopyCount"] = "" || rowData["CopyCount"] = 0) {
                        rowData["CopyCount"] := 1
                    }
                    
                    ID := Integer(rowData["ID"])
                    Content := String(rowData["Content"])
                    DataType := String(rowData["DataType"])
                    SourceApp := String(rowData["SourceApp"])
                    SourcePath := String(rowData["SourcePath"])
                    CharCount := Integer(rowData["CharCount"])
                    Timestamp := String(rowData["Timestamp"])
                    LastCopyTime := String(rowData["LastCopyTime"])
                    CopyCount := Integer(rowData["CopyCount"])
                    
                    IconIndex := 0
                    if (SourcePath != "" && FileExist(SourcePath)) {
                        if (IconCache.Has(SourcePath)) {
                            IconIndex := IconCache[SourcePath]
                        } else {
                            try {
                                IconIndex := IL_Add(ClipboardImageList, SourcePath, 0)
                                if (IconIndex > 0) {
                                    IconCache[SourcePath] := IconIndex
                                }
                            } catch {
                            }
                        }
                    }
                    
                    ClipboardItems.Push({ID: ID, Content: Content, DataType: DataType, SourceApp: SourceApp, SourcePath: SourcePath, CharCount: CharCount, Timestamp: Timestamp, LastCopyTime: LastCopyTime, CopyCount: CopyCount, IconIndex: IconIndex})
                    TotalItems++
                }
            }
        } else if (CurrentCategory == "File") {
            ; ========== 本地文件搜索（使用Everything直接搜索文件系统）==========
            if (SearchKeyword != "" && StrLen(SearchKeyword) > 1) {
                try {
                    ; 使用GetEverythingResults直接搜索文件系统
                    EverythingResults := GetEverythingResults(SearchKeyword, EverythingLimit, true)  ; 包含文件夹
                    
                    for index, result in EverythingResults {
                        if (Type(result) = "Map") {
                            path := result["Path"]
                            isDirectory := result["IsDirectory"]
                            fileSize := result.Has("Size") ? result["Size"] : 0
                            dateModified := result.Has("DateModified") ? result["DateModified"] : 0
                            
                            SplitPath(path, &FileName, &DirPath, &Ext, &NameNoExt)
                            
                            ; 提取图标
                            IconIndex := 0
                            if (IconCache.Has(path)) {
                                IconIndex := IconCache[path]
                            } else {
                                try {
                                    IconIndex := IL_Add(ClipboardImageList, path, 0)
                                    if (IconIndex > 0) {
                                        IconCache[path] := IconIndex
                                    }
                                } catch {
                                    IconIndex := 0
                                }
                            }
                            
                            ; 格式化文件大小
                            sizeStr := ""
                            if (!isDirectory && fileSize > 0) {
                                if (fileSize < 1024) {
                                    sizeStr := fileSize . " B"
                                } else if (fileSize < 1048576) {
                                    sizeStr := Round(fileSize / 1024, 2) . " KB"
                                } else if (fileSize < 1073741824) {
                                    sizeStr := Round(fileSize / 1048576, 2) . " MB"
                                } else {
                                    sizeStr := Round(fileSize / 1073741824, 2) . " GB"
                                }
                            }
                            
                            ; 格式化修改日期
                            dateStr := ""
                            if (dateModified > 0) {
                                try {
                                    fileTime := Buffer(8)
                                    NumPut("Int64", dateModified, fileTime)
                                    localFileTime := Buffer(8)
                                    if (DllCall("FileTimeToLocalFileTime", "Ptr", fileTime.Ptr, "Ptr", localFileTime.Ptr)) {
                                        systemTime := Buffer(16)
                                        if (DllCall("FileTimeToSystemTime", "Ptr", localFileTime.Ptr, "Ptr", systemTime.Ptr)) {
                                            year := NumGet(systemTime, 0, "UShort")
                                            month := NumGet(systemTime, 2, "UShort")
                                            day := NumGet(systemTime, 4, "UShort")
                                            hour := NumGet(systemTime, 6, "UShort")
                                            minute := NumGet(systemTime, 8, "UShort")
                                            dateStr := Format("{:04d}-{:02d}-{:02d} {:02d}:{:02d}", year, month, day, hour, minute)
                                        }
                                    }
                                } catch {
                                    dateStr := ""
                                }
                            }
                            
                            ; 创建文件结果项
                            fileItem := Map()
                            fileItem["ID"] := 0
                            fileItem["Content"] := path
                            fileItem["DataType"] := isDirectory ? "Folder" : "File"
                            fileItem["SourceApp"] := "文件系统"
                            fileItem["SourcePath"] := path
                            fileItem["CharCount"] := 0
                            fileItem["Timestamp"] := dateStr
                            fileItem["LastCopyTime"] := dateStr
                            fileItem["CopyCount"] := 1
                            fileItem["IconIndex"] := IconIndex
                            fileItem["FileSize"] := sizeStr
                            fileItem["IsDirectory"] := isDirectory
                            
                            ClipboardItems.Push(fileItem)
                            TotalItems++
                        }
                    }
                } catch as err {
                    OutputDebug("AHK_DEBUG: ClipboardManagement 文件搜索失败: " . err.Message)
                }
            }
        } else if (CurrentCategory == "Template") {
            ; ========== 提示词搜索 ==========
            if (SearchKeyword != "") {
                try {
                    ; 使用SearchPromptTemplates搜索提示词
                    TemplateResults := SearchPromptTemplates(SearchKeyword, EverythingLimit, 0)
                    
                    for index, templateResult in TemplateResults {
                        ; SearchPromptTemplates返回的是ResultItem格式
                        if (Type(templateResult) = "Map" && templateResult.Has("Content")) {
                            ; 提取图标（使用默认图标）
                            IconIndex := 0
                            
                            ; 创建提示词结果项
                            templateItem := Map()
                            templateItem["ID"] := templateResult.Has("ID") ? templateResult["ID"] : 0
                            templateItem["Content"] := templateResult["Content"]
                            templateItem["DataType"] := "Template"
                            templateItem["SourceApp"] := templateResult.Has("Metadata") && templateResult["Metadata"].Has("Category") ? templateResult["Metadata"]["Category"] : "提示词"
                            templateItem["SourcePath"] := ""
                            templateItem["CharCount"] := StrLen(templateResult["Content"])
                            templateItem["Timestamp"] := ""
                            templateItem["LastCopyTime"] := ""
                            templateItem["CopyCount"] := 1
                            templateItem["IconIndex"] := IconIndex
                            templateItem["FileSize"] := "-"
                            templateItem["Title"] := templateResult.Has("Title") ? templateResult["Title"] : ""
                            
                            ClipboardItems.Push(templateItem)
                            TotalItems++
                        }
                    }
                } catch as err {
                    OutputDebug("AHK_DEBUG: ClipboardManagement 提示词搜索失败: " . err.Message)
                }
            }
        } else {
            ; ========== 默认情况：剪贴板搜索（从数据库查询）==========
            ; 构建SQL查询条件
            WhereClause := ""
            
            ; 如果有搜索关键词，使用FTS5全文搜索
            if (SearchKeyword != "") {
                ; 使用FTS5全文搜索（参考ClipboardHistoryPanel）
                WhereClause := "WHERE ClipMain MATCH '" . StrReplace(SearchKeyword, "'", "''") . "'"
            }
            
            ; 构建最终 SQL 查询
            ; 【修复】使用正确的排序字段（参考 ClipboardHistoryPanel 使用 LastCopyTime 或 Timestamp）
            orderByField := hasLastCopyTime ? "LastCopyTime" : "Timestamp"
            if (WhereClause != "") {
                SQL := "SELECT " . selectFields . " FROM ClipMain " . WhereClause . " ORDER BY " . orderByField . " DESC LIMIT " . EverythingLimit
            } else {
                SQL := "SELECT " . selectFields . " FROM ClipMain ORDER BY " . orderByField . " DESC LIMIT " . EverythingLimit
            }
            
            ; 使用 GetTable 查询
            ResultTable := 0
            if (!ClipboardFTS5DB.GetTable(SQL, &ResultTable)) {
                ; 查询失败，清空列表
                ClipboardListView.Delete()
                ClipboardListView.Opt("+Redraw")
                return
            }
            
            if (!ResultTable || !ResultTable.HasProp("Rows") || ResultTable.Rows.Length = 0) {
                ; 没有数据，清空列表
                ClipboardListView.Delete()
                ClipboardListView.Opt("+Redraw")
                return
            }
            
            ; 创建列名映射
            columnNames := []
            columnIndexMap := Map()
            if (ResultTable.HasNames && ResultTable.ColumnNames.Length > 0) {
                columnNames := ResultTable.ColumnNames
                Loop columnNames.Length {
                    colName := columnNames[A_Index]
                    columnIndexMap[colName] := A_Index
                }
            }
            
            ; 处理数据库查询结果
            for Index, Row in ResultTable.Rows {
                if (!IsObject(Row)) {
                    continue
                }
                
                rowData := Map()
                
                if (columnIndexMap.Count > 0) {
                    ; 使用列名映射访问（正确方式）
                    if (columnIndexMap.Has("ID")) {
                        rowData["ID"] := Row[columnIndexMap["ID"]]
                    }
                    if (columnIndexMap.Has("Content")) {
                        rowData["Content"] := Row[columnIndexMap["Content"]]
                    }
                    if (columnIndexMap.Has("DataType")) {
                        rowData["DataType"] := Row[columnIndexMap["DataType"]]
                    }
                    if (columnIndexMap.Has("SourceApp")) {
                        rowData["SourceApp"] := Row[columnIndexMap["SourceApp"]]
                    }
                    if (columnIndexMap.Has("SourcePath")) {
                        rowData["SourcePath"] := Row[columnIndexMap["SourcePath"]]
                    }
                    if (columnIndexMap.Has("CharCount")) {
                        rowData["CharCount"] := Row[columnIndexMap["CharCount"]]
                    }
                    if (columnIndexMap.Has("Timestamp")) {
                        rowData["Timestamp"] := Row[columnIndexMap["Timestamp"]]
                    }
                    if (columnIndexMap.Has("LastCopyTime")) {
                        rowData["LastCopyTime"] := Row[columnIndexMap["LastCopyTime"]]
                    }
                    if (columnIndexMap.Has("CopyCount")) {
                        rowData["CopyCount"] := Row[columnIndexMap["CopyCount"]]
                    }
                    if (columnIndexMap.Has("ImagePath")) {
                        rowData["ImagePath"] := Row[columnIndexMap["ImagePath"]]
                    }
                } else {
                    ; 后备方案：按固定顺序读取
                    if (Row.HasProp("Length") && Row.Length >= 1) {
                        rowData["ID"] := Row[1]
                    }
                    if (Row.HasProp("Length") && Row.Length >= 2) {
                        rowData["Content"] := Row[2]
                    }
                    if (Row.HasProp("Length") && Row.Length >= 3) {
                        rowData["DataType"] := Row[3]
                    }
                    if (Row.HasProp("Length") && Row.Length >= 4) {
                        rowData["SourceApp"] := Row[4]
                    }
                    if (Row.HasProp("Length") && Row.Length >= 5) {
                        rowData["SourcePath"] := Row[5]
                    }
                    if (Row.HasProp("Length") && Row.Length >= 6) {
                        rowData["CharCount"] := Row[6]
                    }
                    if (Row.HasProp("Length") && Row.Length >= 7) {
                        rowData["Timestamp"] := Row[7]
                    }
                    if (Row.HasProp("Length") && Row.Length >= 8) {
                        rowData["LastCopyTime"] := Row[8]
                    }
                    if (Row.HasProp("Length") && Row.Length >= 9) {
                        rowData["CopyCount"] := Row[9]
                    }
                    if (Row.HasProp("Length") && Row.Length >= 10) {
                        rowData["ImagePath"] := Row[10]
                    }
                }
                
                ; 确保所有必需字段都有值
                if (!rowData.Has("ID") || rowData["ID"] = "") {
                    continue
                }
                if (!rowData.Has("Content") || rowData["Content"] = "") {
                    continue
                }
                if (!rowData.Has("DataType") || rowData["DataType"] = "") {
                    rowData["DataType"] := "Text"
                }
                if (!rowData.Has("SourceApp") || rowData["SourceApp"] = "") {
                    rowData["SourceApp"] := ""
                }
                if (!rowData.Has("SourcePath")) {
                    rowData["SourcePath"] := ""
                }
                if (!rowData.Has("CharCount") || rowData["CharCount"] = "" || rowData["CharCount"] = 0) {
                    rowData["CharCount"] := StrLen(rowData["Content"])
                }
                if (!rowData.Has("Timestamp") || rowData["Timestamp"] = "") {
                    rowData["Timestamp"] := ""
                }
                if (!rowData.Has("LastCopyTime") || rowData["LastCopyTime"] = "") {
                    rowData["LastCopyTime"] := rowData["Timestamp"]
                }
                if (!rowData.Has("CopyCount") || rowData["CopyCount"] = "" || rowData["CopyCount"] = 0) {
                    rowData["CopyCount"] := 1
                }
                
                ID := Integer(rowData["ID"])
                Content := String(rowData["Content"])
                DataType := String(rowData["DataType"])
                SourceApp := String(rowData["SourceApp"])
                SourcePath := String(rowData["SourcePath"])
                CharCount := Integer(rowData["CharCount"])
                Timestamp := String(rowData["Timestamp"])
                LastCopyTime := String(rowData["LastCopyTime"])
                CopyCount := Integer(rowData["CopyCount"])
                
                if (Content = "") {
                    continue
                }
                
                ; 提取图标（如果有 SourcePath）
                IconIndex := 0
                if (SourcePath != "" && FileExist(SourcePath)) {
                    ; 检查缓存
                    if (IconCache.Has(SourcePath)) {
                        IconIndex := IconCache[SourcePath]
                    } else {
                        ; 提取图标
                        try {
                            IconIndex := IL_Add(ClipboardImageList, SourcePath, 0)
                            if (IconIndex > 0) {
                                IconCache[SourcePath] := IconIndex
                            } else {
                                IconIndex := 0
                            }
                        } catch as err {
                            IconIndex := 0
                        }
                    }
                }
                
                ; 添加到列表
                ClipboardItems.Push({ID: ID, Content: Content, DataType: DataType, SourceApp: SourceApp, SourcePath: SourcePath, CharCount: CharCount, Timestamp: Timestamp, LastCopyTime: LastCopyTime, CopyCount: CopyCount, IconIndex: IconIndex})
                TotalItems++
            }
        }
        
        ; 如果没有有效数据
        if (ClipboardItems.Length = 0) {
            ; ListView 已在函数开始时清空
            ClipboardListView.Opt("+Redraw") ; 恢复重绘
            return
        }
        
        ; ListView 已在函数开始时清空，这里直接添加数据
        
        ; 【多列布局】设置为8列显示
        ; 先获取当前列数
        CurrentColCount := 0
        try {
            CurrentColCount := ClipboardListView.GetCount("Col")
        } catch as err {
            CurrentColCount := 0
        }
        
        ; 需要 8 列：内容预览、来源应用、文件位置、类型、文件大小、最后复制时间、复制次数、字符数
        NeededColCount := 8
        
        ; 如果列数不对，重新设置列
        if (CurrentColCount != NeededColCount) {
            try {
                ; 删除所有现有列
                Loop CurrentColCount {
                    ClipboardListView.DeleteCol(1)
                }
                ; 添加所有列
                ClipboardListView.InsertCol(1, 250 . " Left", "内容预览")
                ClipboardListView.InsertCol(2, 100 . " Left", "来源应用")
                ClipboardListView.InsertCol(3, 180 . " Left", "文件位置")
                ClipboardListView.InsertCol(4, 60 . " Left", "类型")
                ClipboardListView.InsertCol(5, 80 . " Left", "文件大小")
                ClipboardListView.InsertCol(6, 130 . " Left", "最后复制时间")
                ClipboardListView.InsertCol(7, 70 . " Left", "复制次数")
                ClipboardListView.InsertCol(8, 70 . " Left", "字符数")
            } catch as err {
            }
        } else {
            ; 更新列标题和宽度
            try {
                ClipboardListView.ModifyCol(1, 250 . " Left", "内容预览")
                ClipboardListView.ModifyCol(2, 100 . " Left", "来源应用")
                ClipboardListView.ModifyCol(3, 180 . " Left", "文件位置")
                ClipboardListView.ModifyCol(4, 60 . " Left", "类型")
                ClipboardListView.ModifyCol(5, 80 . " Left", "文件大小")
                ClipboardListView.ModifyCol(6, 130 . " Left", "最后复制时间")
                ClipboardListView.ModifyCol(7, 70 . " Left", "复制次数")
                ClipboardListView.ModifyCol(8, 70 . " Left", "字符数")
            } catch as err {
            }
        }
        
        ; 【添加行】按时间倒序显示（最新的在最前面）
        for Index, Item in ClipboardItems {
            ; 截取内容预览（对于提示词，优先显示标题）
            ContentPreview := Item.Content
            if (Item.HasProp("Title") && Item.Title != "") {
                ContentPreview := Item.Title . " - " . ContentPreview
            }
            if (StrLen(ContentPreview) > 200) {
                ContentPreview := SubStr(ContentPreview, 1, 200) . "..."
            }
            ; 替换换行符
            ContentPreview := StrReplace(ContentPreview, "`r`n", " ")
            ContentPreview := StrReplace(ContentPreview, "`n", " ")
            ContentPreview := StrReplace(ContentPreview, "`r", " ")
            ContentPreview := StrReplace(ContentPreview, "`t", " ")
            
            ; 获取来源应用
            SourceApp := Item.HasProp("SourceApp") ? Item.SourceApp : ""
            if (SourceApp = "") {
                SourceApp := "-"
            }
            
            ; 获取文件位置（显示文件名或路径）
            FileLocation := "-"
            SourcePath := Item.HasProp("SourcePath") ? Item.SourcePath : ""
            if (SourcePath != "" && SourcePath != "\\") {
                try {
                    SplitPath(SourcePath, &fileName)
                    FileLocation := fileName
                } catch {
                    FileLocation := SourcePath
                }
            }
            
            ; 获取类型
            DataType := Item.HasProp("DataType") ? Item.DataType : "Text"
            
            ; 获取文件大小（优先使用Item中的FileSize字段）
            FileSize := "-"
            if (Item.HasProp("FileSize") && Item.FileSize != "") {
                FileSize := Item.FileSize
            } else if (SourcePath != "" && SourcePath != "\\" && FileExist(SourcePath)) {
                try {
                    fileSizeBytes := FileGetSize(SourcePath)
                    if (fileSizeBytes >= 0) {
                        FileSize := FormatFileSize(fileSizeBytes)
                    }
                } catch {
                    FileSize := "-"
                }
            }
            
            ; 格式化最后复制时间
            LastCopyTimeText := "-"
            LastCopyTime := Item.HasProp("LastCopyTime") ? Item.LastCopyTime : ""
            if (LastCopyTime != "") {
                try {
                    LastCopyTimeText := FormatTime(LastCopyTime, "yyyy-MM-dd HH:mm:ss")
                } catch {
                    LastCopyTimeText := LastCopyTime
                }
            }
            
            ; 获取复制次数
            CopyCount := Item.HasProp("CopyCount") ? Item.CopyCount : 1
            if (CopyCount = "" || CopyCount = 0) {
                CopyCount := 1
            }
            
            ; 获取字符数
            CharCount := Item.HasProp("CharCount") ? Item.CharCount : 0
            if (CharCount = "" || CharCount = 0) {
                CharCount := StrLen(Item.Content)
            }
            
            ; 添加行到 ListView（第一个参数是图标选项字符串，如 "Icon1"）
            IconIndex := Item.HasProp("IconIndex") ? Item.IconIndex : 0
            IconOption := (IconIndex > 0) ? "Icon" . IconIndex : ""
            try {
                ClipboardListView.Add(IconOption,
                    String(ContentPreview),      ; 第1列：内容预览
                    String(SourceApp),           ; 第2列：来源应用
                    String(FileLocation),        ; 第3列：文件位置
                    String(DataType),            ; 第4列：类型
                    String(FileSize),            ; 第5列：文件大小
                    String(LastCopyTimeText),   ; 第6列：最后复制时间
                    String(CopyCount),           ; 第7列：复制次数
                    String(CharCount))           ; 第8列：字符数
            } catch as e {
                try {
                    FileAppend("[" . FormatTime(, "yyyy-MM-dd HH:mm:ss") . "] RefreshClipboardListView: 添加行失败 - ID=" . Item.ID . ", 错误=" . e.Message . "`n", A_ScriptDir "\clipboard_debug.log")
                } catch as err {
                }
            }
        }
        
        ; 统计信息已移除
        
        ; 调试：记录刷新完成
        try {
            FileAppend("[" . FormatTime(, "yyyy-MM-dd HH:mm:ss") . "] RefreshClipboardListView: 列表刷新完成 - 总项数=" . TotalItems . ", 已添加行数=" . ClipboardListView.GetCount() . "`n", A_ScriptDir "\clipboard_debug.log")
        } catch as err {
        }
        
        ; 【关键修复】恢复绘制（在所有数据添加完成后）
        ClipboardListView.Opt("+Redraw")
        
        ; 强制刷新显示
        try {
            ClipboardListView.Redraw()
        } catch as err {
        }
        
    } catch as e {
        ; 发生错误，清空列表
        try {
            ClipboardListView.Delete()
            FileAppend("[" . FormatTime(, "yyyy-MM-dd HH:mm:ss") . "] RefreshClipboardListView: 发生异常 - " . e.Message . "`n", A_ScriptDir "\clipboard_debug.log")
        } catch as err {
        }
        ; 【关键修复】即使发生错误，也要恢复重绘
        try {
            ClipboardListView.Opt("+Redraw")
        } catch as err {
        }
    }
}

; ===================== 窗口大小变化事件处理 =====================
OnClipboardManagerSize(GuiObj, MinMax, Width, Height) {
    global ClipboardListView, ClipboardListBox, ClipboardCurrentTab, GuiID_ClipboardManager
    
    try {
        ; 计算ListView的新尺寸（窗口宽度 - 左右边距40，窗口高度 - 搜索框(38+30+10) - 标签栏(35+10) - 底部区域70）
        ; 搜索框Y: 38, 高度: 30, 间距: 10
        ; 标签栏Y: 38+30+10=78, 高度: 35, 间距: 10
        ; 列表Y: 78+35+10=123
        ListViewX := 20
        ListViewY := 123  ; 标签栏下方
        ListViewWidth := Width - 40  ; 自适应窗口宽度
        ListViewHeight := Height - ListViewY - 70  ; 窗口高度 - 列表Y - 底部区域
        
        ; 调整搜索框宽度（自适应窗口宽度）
        try {
            SearchEdit := GuiObj["ClipboardSearchEdit"]
            if (SearchEdit && IsObject(SearchEdit)) {
                DropdownWidth := 100
                SearchBoxX := 10 + DropdownWidth + 10
                SearchBoxWidth := Width - SearchBoxX - 20  ; 自适应窗口宽度
                SearchEdit.Move(SearchBoxX, , SearchBoxWidth)
            }
        } catch as err {
        }
        
        ; 调整标签栏宽度（自适应窗口宽度）
        try {
            CategoryBarBg := GuiObj["ClipboardCategoryBarBg"]
            if (CategoryBarBg && IsObject(CategoryBarBg)) {
                CategoryBarBg.Move(, , Width)
            }
        } catch as err {
        }
        
        ; 调整ListView尺寸
        if (ClipboardCurrentTab = "CapsLockC" && ClipboardListView && IsObject(ClipboardListView)) {
            ClipboardListView.Move(ListViewX, ListViewY, ListViewWidth, ListViewHeight)
            ; ListView尺寸改变后，更新覆盖层位置
            UpdateClipboardHighlightOverlay()
        } else if (ClipboardCurrentTab = "CtrlC" && ClipboardListBox && IsObject(ClipboardListBox)) {
            ClipboardListBox.Move(ListViewX, ListViewY, ListViewWidth, ListViewHeight)
            ; CtrlC标签不显示覆盖层，确保覆盖层已销毁
            DestroyClipboardHighlightOverlay()
        }
        
        ; 调整底部区域和按钮位置（固定在底部）
        try {
            BottomAreaY := Height - 70
            BottomArea := GuiObj["ClipboardBottomArea"]
            if (BottomArea && IsObject(BottomArea)) {
                BottomArea.Move(, BottomAreaY, Width, 70)
            }
            
            ; 调整底部按钮位置（保持相对位置）- 通过v参数访问控件
            ButtonY := BottomAreaY + 10
            ButtonWidth := 100
            ButtonSpacing := 10
            try {
                CopyBtn := GuiObj["ClipboardCopyBtn"]
                if (CopyBtn && IsObject(CopyBtn)) {
                    CopyBtn.Move(20, ButtonY)
                }
                DeleteBtn := GuiObj["ClipboardDeleteBtn"]
                if (DeleteBtn && IsObject(DeleteBtn)) {
                    DeleteBtn.Move(20 + ButtonWidth + ButtonSpacing, ButtonY)
                }
                PasteBtn := GuiObj["ClipboardPasteBtn"]
                if (PasteBtn && IsObject(PasteBtn)) {
                    PasteBtn.Move(20 + (ButtonWidth + ButtonSpacing) * 2, ButtonY)
                }
                ClearAllBtn := GuiObj["ClipboardClearAllBtn"]
                if (ClearAllBtn && IsObject(ClearAllBtn)) {
                    ClearAllBtn.Move(20 + (ButtonWidth + ButtonSpacing) * 2 + ButtonWidth + 20 + ButtonSpacing, ButtonY)
                }
                ExportBtn := GuiObj["ClipboardExportBtn"]
                if (ExportBtn && IsObject(ExportBtn)) {
                    ExportBtn.Move(20 + (ButtonWidth + ButtonSpacing) * 3 + ButtonWidth + 20 + ButtonSpacing, ButtonY)
                }
                ImportBtn := GuiObj["ClipboardImportBtn"]
                if (ImportBtn && IsObject(ImportBtn)) {
                    ImportBtn.Move(20 + (ButtonWidth + ButtonSpacing) * 4 + ButtonWidth + 20 + ButtonSpacing, ButtonY)
                }
            } catch as err {
                ; 如果无法访问控件，忽略错误
            }
            
            ; 调整底部提示文字位置
            HintText := GuiObj["ClipboardHintText"]
            if (HintText && IsObject(HintText)) {
                HintText.Move(20, BottomAreaY + 55, Width - 40)
            }
        } catch as err {
        }
    } catch as err {
    }
}

; ===================== ListView双击事件处理（显示悬浮编辑窗） =====================
OnClipboardListViewDoubleClick(Control, Item, *) {
    global ClipboardListView, ClipboardDB, ClipboardCurrentTab, ClipboardListViewHwnd
    
    ; 【调试日志】记录双击事件
    try {
        FileAppend("[" . FormatTime(, "yyyy-MM-dd HH:mm:ss") . "] DoubleClick: Item=" . Item . ", Tab=" . ClipboardCurrentTab . "`n", A_ScriptDir "\clipboard_debug.log")
    } catch as err {
    }
    
    ; 只在CapsLockC标签时处理
    if (ClipboardCurrentTab != "CapsLockC" || !ClipboardListView || !IsObject(ClipboardListView)) {
        try {
            FileAppend("[" . FormatTime(, "yyyy-MM-dd HH:mm:ss") . "] DoubleClick: Early return - Tab=" . ClipboardCurrentTab . ", ListView=" . (ClipboardListView ? "exists" : "null") . "`n", A_ScriptDir "\clipboard_debug.log")
        } catch as err {
        }
        return
    }
    
    ; 获取双击的行（Item参数是行索引，从1开始）
    RowIndex := Item
    if (RowIndex < 1) {
        try {
            FileAppend("[" . FormatTime(, "yyyy-MM-dd HH:mm:ss") . "] DoubleClick: Invalid RowIndex=" . RowIndex . "`n", A_ScriptDir "\clipboard_debug.log")
        } catch as err {
        }
        return
    }
    
    ; 【关键修复】立即使用 LVM_SUBITEMHITTEST 获取精确的列索引
    ; 不再使用延迟处理，避免鼠标移动导致列索引错误
    try {
        LV_Hwnd := ClipboardListViewHwnd
        if (!LV_Hwnd) {
            try {
                FileAppend("[" . FormatTime(, "yyyy-MM-dd HH:mm:ss") . "] DoubleClick: No LV_Hwnd`n", A_ScriptDir "\clipboard_debug.log")
            } catch as err {
            }
            return
        }
        
        ; 获取当前鼠标位置（屏幕坐标）
        POINT := Buffer(8, 0)
        DllCall("GetCursorPos", "Ptr", POINT.Ptr)
        
        ; 将屏幕坐标转换为ListView客户端坐标
        DllCall("ScreenToClient", "Ptr", LV_Hwnd, "Ptr", POINT.Ptr)
        ClientX := NumGet(POINT, 0, "Int")
        ClientY := NumGet(POINT, 4, "Int")
        
        ; 准备 LVHITTESTINFO 结构
        LVHITTESTINFO := Buffer(24, 0)
        NumPut("Int", ClientX, LVHITTESTINFO, 0)   ; pt.x
        NumPut("Int", ClientY, LVHITTESTINFO, 4)   ; pt.y
        
        ; 调用 LVM_SUBITEMHITTEST 获取精确的列索引
        Result := DllCall("SendMessage", "Ptr", LV_Hwnd, "UInt", 0x1039, "Ptr", 0, "Ptr", LVHITTESTINFO.Ptr, "Int")
        
        ; 读取结果（注意：iSubItem 是从 0 开始的）
        iSubItem := NumGet(LVHITTESTINFO, 16, "Int")
        
        ; 转换为从1开始的索引
        ColIndex := iSubItem + 1
        
        ; 【调试日志】记录列索引
        try {
            FileAppend("[" . FormatTime(, "yyyy-MM-dd HH:mm:ss") . "] DoubleClick: Row=" . RowIndex . ", Col=" . ColIndex . ", iSubItem=" . iSubItem . ", ClientX=" . ClientX . ", ClientY=" . ClientY . "`n", A_ScriptDir "\clipboard_debug.log")
        } catch as err {
        }
        
        ; 如果列索引无效（iSubItem < 0 表示没有命中），默认使用第1列
        if (iSubItem < 0) {
            ColIndex := 1
            try {
                FileAppend("[" . FormatTime(, "yyyy-MM-dd HH:mm:ss") . "] DoubleClick: Invalid iSubItem, using Col=1`n", A_ScriptDir "\clipboard_debug.log")
            } catch as err {
            }
        }
        
        ; 从数据库获取完整内容和数据类型
        FullContent := GetCellFullContent(RowIndex, ColIndex)
        DataType := GetCellDataType(RowIndex, ColIndex)
        
        try {
            FileAppend("[" . FormatTime(, "yyyy-MM-dd HH:mm:ss") . "] DoubleClick: FullContent length=" . StrLen(FullContent) . ", DataType=" . DataType . "`n", A_ScriptDir "\clipboard_debug.log")
        } catch as err {
        }
        
        if (FullContent != "") {
            ; 根据数据类型执行不同操作
            if (DataType = "Link") {
                ; 链接类型：直接打开浏览器
                try {
                    Run(FullContent)
                    TrayTip("已打开链接", FullContent, "Iconi 1")
                } catch as err {
                    TrayTip("打开链接失败", err.Message, "Iconx 2")
                }
            } else if (DataType = "Image") {
                ; 图片类型：使用系统查看器打开
                try {
                    if (FileExist(FullContent)) {
                        Run(FullContent)
                        TrayTip("已打开图片", FullContent, "Iconi 1")
                    } else {
                        TrayTip("图片文件不存在", FullContent, "Iconx 2")
                    }
                } catch as err {
                    TrayTip("打开图片失败", err.Message, "Iconx 2")
                }
            } else {
                ; 其他类型：显示浮窗（传递数据类型）
                ShowClipboardCellContentWindow(FullContent, RowIndex, ColIndex, DataType)
                try {
                    FileAppend("[" . FormatTime(, "yyyy-MM-dd HH:mm:ss") . "] DoubleClick: ShowClipboardCellContentWindow called`n", A_ScriptDir "\clipboard_debug.log")
                } catch as err {
                }
            }
        } else {
            try {
                FileAppend("[" . FormatTime(, "yyyy-MM-dd HH:mm:ss") . "] DoubleClick: FullContent is empty, not showing window`n", A_ScriptDir "\clipboard_debug.log")
            } catch as err {
            }
        }
    } catch as e {
        ; 记录错误
        try {
            FileAppend("[" . FormatTime(, "yyyy-MM-dd HH:mm:ss") . "] DoubleClick Error: " . e.Message . "`n", A_ScriptDir "\clipboard_debug.log")
        } catch as err {
        }
    }
}

; ===================== 处理 ListView 双击消息（NM_DBLCLICK） =====================
; 用于处理第二列及以后列的双击事件
HandleClipboardListViewDoubleClick(lParam) {
    global ClipboardListView, ClipboardDB, ClipboardCurrentTab, ClipboardListViewHwnd
    
    try {
        ; 【调试日志】记录 NM_DBLCLICK 消息
        FileAppend("[" . FormatTime(, "yyyy-MM-dd HH:mm:ss") . "] NM_DBLCLICK received`n", A_ScriptDir "\clipboard_debug.log")
    } catch as err {
    }
    
    ; 只在CapsLockC标签时处理
    if (ClipboardCurrentTab != "CapsLockC" || !ClipboardListView || !IsObject(ClipboardListView)) {
        return
    }
    
    try {
        LV_Hwnd := ClipboardListViewHwnd
        if (!LV_Hwnd) {
            return
        }
        
        ; 【关键修复】NMITEMACTIVATE 结构在 64 位系统上的正确布局：
        ; NMHDR hdr
        ;   - hwndFrom: HWND (8字节)
        ;   - idFrom: UINT_PTR (8字节)
        ;   - code: UINT (4字节)
        ;   - 对齐填充 (4字节)
        ; int iItem (4字节)
        ; int iSubItem (4字节)
        ; UINT uNewState (4字节)
        ; UINT uOldState (4字节)
        ; UINT uChanged (4字节)
        ; POINT ptAction (8字节)
        ; LPARAM lParam (8字节)
        
        ; 计算偏移量（64位系统）
        NMHDRSize := A_PtrSize = 8 ? 24 : 12
        
        ; 读取行和列索引
        iItem := NumGet(lParam, NMHDRSize, "Int")
        iSubItem := NumGet(lParam, NMHDRSize + 4, "Int")
        
        ; 【调试日志】
        try {
            FileAppend("[" . FormatTime(, "yyyy-MM-dd HH:mm:ss") . "] NM_DBLCLICK: iItem=" . iItem . ", iSubItem=" . iSubItem . "`n", A_ScriptDir "\clipboard_debug.log")
        } catch as err {
        }
        
        ; 【关键修复】NMITEMACTIVATE 的 iItem 和 iSubItem 在双击非第一列时可能无效
        ; 总是使用 LVM_SUBITEMHITTEST 来获取精确的位置
        ; 获取当前鼠标位置（屏幕坐标）
        POINT := Buffer(8, 0)
        DllCall("GetCursorPos", "Ptr", POINT.Ptr)
        
        ; 将屏幕坐标转换为ListView客户端坐标
        DllCall("ScreenToClient", "Ptr", LV_Hwnd, "Ptr", POINT.Ptr)
        ClientX := NumGet(POINT, 0, "Int")
        ClientY := NumGet(POINT, 4, "Int")
        
        ; 使用 LVM_SUBITEMHITTEST 获取精确的行和列索引
        LVHITTESTINFO := Buffer(24, 0)
        NumPut("Int", ClientX, LVHITTESTINFO, 0)   ; pt.x
        NumPut("Int", ClientY, LVHITTESTINFO, 4)   ; pt.y
        
        ; 调用 LVM_SUBITEMHITTEST
        Result := DllCall("SendMessage", "Ptr", LV_Hwnd, "UInt", 0x1039, "Ptr", 0, "Ptr", LVHITTESTINFO.Ptr, "Int")
        
        ; 读取结果
        flags := NumGet(LVHITTESTINFO, 8, "UInt")
        iItem := NumGet(LVHITTESTINFO, 12, "Int")
        iSubItem := NumGet(LVHITTESTINFO, 16, "Int")
        
        ; 转换为从1开始的索引
        RowIndex := iItem + 1
        ColIndex := iSubItem + 1
        
        ; 【调试日志】
        try {
            FileAppend("[" . FormatTime(, "yyyy-MM-dd HH:mm:ss") . "] NM_DBLCLICK: After hittest - Row=" . RowIndex . ", Col=" . ColIndex . ", ClientX=" . ClientX . ", ClientY=" . ClientY . ", flags=0x" . Format("{:X}", flags) . "`n", A_ScriptDir "\clipboard_debug.log")
        } catch as err {
        }
        
        ; 检查是否点击了有效的单元格
        if (iItem >= 0 && iSubItem >= 0 && RowIndex >= 1 && ColIndex >= 1) {
            ; 从数据库获取完整内容并显示浮窗
            FullContent := GetCellFullContent(RowIndex, ColIndex)
            try {
                FileAppend("[" . FormatTime(, "yyyy-MM-dd HH:mm:ss") . "] NM_DBLCLICK: FullContent length=" . StrLen(FullContent) . "`n", A_ScriptDir "\clipboard_debug.log")
            } catch as err {
            }
            
            if (FullContent != "") {
                try {
                    FileAppend("[" . FormatTime(, "yyyy-MM-dd HH:mm:ss") . "] NM_DBLCLICK: Calling ShowClipboardCellContentWindow with Row=" . RowIndex . ", Col=" . ColIndex . ", ContentLength=" . StrLen(FullContent) . "`n", A_ScriptDir "\clipboard_debug.log")
                    ShowClipboardCellContentWindow(FullContent, RowIndex, ColIndex)
                    FileAppend("[" . FormatTime(, "yyyy-MM-dd HH:mm:ss") . "] NM_DBLCLICK: ShowClipboardCellContentWindow returned`n", A_ScriptDir "\clipboard_debug.log")
                } catch as e {
                    FileAppend("[" . FormatTime(, "yyyy-MM-dd HH:mm:ss") . "] NM_DBLCLICK: ShowClipboardCellContentWindow Error: " . e.Message . "`n", A_ScriptDir "\clipboard_debug.log")
                }
                ; 【关键】在 AutoHotkey v2 中，WM_NOTIFY 消息处理函数返回的值会被忽略
                ; 我们需要通过其他方式阻止默认行为，或者不返回值
                return
            } else {
                try {
                    FileAppend("[" . FormatTime(, "yyyy-MM-dd HH:mm:ss") . "] NM_DBLCLICK: FullContent is empty`n", A_ScriptDir "\clipboard_debug.log")
                } catch as err {
                }
            }
        } else {
            try {
                FileAppend("[" . FormatTime(, "yyyy-MM-dd HH:mm:ss") . "] NM_DBLCLICK: Invalid cell - Row=" . RowIndex . ", Col=" . ColIndex . "`n", A_ScriptDir "\clipboard_debug.log")
            } catch as err {
            }
        }
    } catch as e {
        try {
            FileAppend("[" . FormatTime(, "yyyy-MM-dd HH:mm:ss") . "] NM_DBLCLICK Error: " . e.Message . "`n", A_ScriptDir "\clipboard_debug.log")
        } catch as err {
        }
    }
    
    ; 不返回值，让系统继续处理（AutoHotkey v2 中返回值可能无效）
}

; ===================== ListView WM_NOTIFY 消息处理（用于获取单元格点击位置） =====================
; WM_NOTIFY = 0x004E
; 处理 NM_CLICK 消息来获取用户点击的单元格位置
OnClipboardListViewWMNotify(wParam, lParam, Msg, Hwnd) {
    global ClipboardListViewHwnd, ClipboardListViewHighlightedRow, ClipboardListViewHighlightedCol
    global ClipboardCurrentTab, ClipboardManagerHwnd, ClipboardListView
    global GuiID_SearchCenter, SearchCenterResultLV
    
    ; Prompt Quick-Pad（AIListPanel）ListView 双击/右键
    try PromptQuickPad_OnWmNotify(wParam, lParam, Msg, Hwnd)
    
    ; 搜索中心：NM_CUSTOMDRAW 路径列（iSubItem=2）副标题灰色
    try {
        if (GuiID_SearchCenter && Hwnd = GuiID_SearchCenter.Hwnd && SearchCenterResultLV) {
            scHwnd := SearchCenterResultLV.Hwnd
            HwndFrom := NumGet(lParam, 0, "Ptr")
            if (HwndFrom = scHwnd) {
                Code := NumGet(lParam, A_PtrSize * 2, "Int")
                if (Code = -12) {
                    r := SearchCenterListViewCustomDraw(lParam)
                    if (r != "")
                        return r
                }
            }
        }
    } catch {
    }
    
    ; 检查是否是剪贴板管理窗口的消息
    if (!ClipboardManagerHwnd || Hwnd != ClipboardManagerHwnd) {
        return  ; 不是我们的窗口，不处理
    }
    
    ; 检查是否是我们的 ListView 发送的消息
    if (!ClipboardListViewHwnd || ClipboardListViewHwnd = 0) {
        return  ; 不是我们的 ListView，不处理
    }
    
    ; 只在CapsLockC标签时处理
    if (ClipboardCurrentTab != "CapsLockC") {
        return  ; 不处理，让系统继续默认处理
    }
    
    try {
        ; 读取 NMHDR 结构
        ; NMHDR 结构：
        ;   hwndFrom: HWND (A_PtrSize 字节)
        ;   idFrom: UINT_PTR (A_PtrSize 字节)
        ;   code: UINT (4字节)
        ;   对齐填充 (64位系统需要4字节填充到8字节边界)
        ; 总计：24字节（64位）或 12字节（32位）
        HwndFrom := NumGet(lParam, 0, "Ptr")
        
        ; 检查是否是我们的 ListView
        if (HwndFrom != ClipboardListViewHwnd) {
            return  ; 不是我们的 ListView，不处理
        }
        
        ; 读取 code 字段
        CodeOffset := A_PtrSize * 2  ; hwndFrom + idFrom
        Code := NumGet(lParam, CodeOffset, "Int")
        
        ; NM_CUSTOMDRAW = -12 (自定义绘制)
        if (Code = -12) {
            return HandleClipboardListViewCustomDraw(lParam)
        }
        
        ; NM_DBLCLICK = -3 (用户双击了 ListView)
        if (Code = -3) {
            return HandleClipboardListViewDoubleClick(lParam)
        }
        
        ; NM_CLICK = -2 (用户点击了 ListView)
        if (Code = -2) {
            ; 【关键修复】使用 LVM_SUBITEMHITTEST 精确获取点击的单元格位置
            ; 因为 NMITEMACTIVATE 的 iSubItem 字段可能不可靠（某些情况下总是0）
            ; LVM_SUBITEMHITTEST = 0x1039
            
            ; 获取当前鼠标位置（屏幕坐标）
            POINT := Buffer(8, 0)
            DllCall("GetCursorPos", "Ptr", POINT.Ptr)
            MouseX := NumGet(POINT, 0, "Int")
            MouseY := NumGet(POINT, 4, "Int")
            
            ; 将屏幕坐标转换为ListView客户端坐标
            LV_Hwnd := ClipboardListViewHwnd
            DllCall("ScreenToClient", "Ptr", LV_Hwnd, "Ptr", POINT.Ptr)
            ClientX := NumGet(POINT, 0, "Int")
            ClientY := NumGet(POINT, 4, "Int")
            
            ; 准备 LVHITTESTINFO 结构
            ; LVHITTESTINFO (64位)：
            ;   POINT pt (8字节)
            ;   UINT flags (4字节)
            ;   int iItem (4字节)
            ;   int iSubItem (4字节) - 这是我们需要的！
            ;   int iGroup (4字节)
            ; 总计：24字节
            LVHITTESTINFO := Buffer(24, 0)
            NumPut("Int", ClientX, LVHITTESTINFO, 0)   ; pt.x
            NumPut("Int", ClientY, LVHITTESTINFO, 4)   ; pt.y
            
            ; 调用 LVM_SUBITEMHITTEST 获取精确的行和列索引
            Result := DllCall("SendMessage", "Ptr", LV_Hwnd, "UInt", 0x1039, "Ptr", 0, "Ptr", LVHITTESTINFO.Ptr, "Int")
            
            ; 读取结果（注意：iItem 和 iSubItem 都是从 0 开始的）
            flags := NumGet(LVHITTESTINFO, 8, "UInt")       ; 命中测试标志
            iItem := NumGet(LVHITTESTINFO, 12, "Int")       ; 行索引（从0开始）
            iSubItem := NumGet(LVHITTESTINFO, 16, "Int")    ; 列索引（从0开始）
            
            ; 【调试日志】记录点击位置和详细信息
            try {
                FileAppend("[" . FormatTime(, "yyyy-MM-dd HH:mm:ss") . "] Click: ClientX=" . ClientX . ", ClientY=" . ClientY . ", Result=" . Result . ", flags=0x" . Format("{:X}", flags) . ", iItem=" . iItem . ", iSubItem=" . iSubItem . "`n", A_ScriptDir "\clipboard_debug.log")
            } catch as err {
            }
            
            ; 转换为从1开始的索引
            RowIndex := iItem + 1
            ColIndex := iSubItem + 1
            
            ; 如果点击了有效的单元格（iItem >= 0 表示点击了有效行，iSubItem >= 0 表示点击了有效列）
            if (iItem >= 0 && iSubItem >= 0) {
                ; 销毁覆盖层（不再使用）
                DestroyClipboardHighlightOverlay()
                
                ; 更新高亮位置
                ClipboardListViewHighlightedRow := RowIndex
                ClipboardListViewHighlightedCol := ColIndex
                
                ; 强制 ListView 重绘以显示自定义高亮效果
                DllCall("InvalidateRect", "Ptr", LV_Hwnd, "Ptr", 0, "Int", 1)
                
                ; 【关键修复】不返回任何值，让系统继续处理单击和双击事件
                ; 返回1会阻止双击事件的触发，导致第二列及以后的单元格无法双击打开编辑窗口
                ; 取消选中的操作在ItemSelect事件中延迟执行，以确保双击事件能够正常触发
            }
        }
    } catch as e {
        ; 出错时记录日志
        try {
            FileAppend("[" . FormatTime(, "yyyy-MM-dd HH:mm:ss") . "] OnClipboardListViewWMNotify Error: " . e.Message . "`n", A_ScriptDir "\clipboard_debug.log")
        } catch as err {
        }
    }
    
    return  ; 不处理，让系统继续默认处理
}

; ===================== 搜索中心 ListView：路径列（副标题）灰色文字 =====================
SearchCenterListViewCustomDraw(lParam) {
    global UI_Colors, ThemeMode
    try {
        if (A_PtrSize = 8) {
            dwDrawStageOffset := 24
            NMCUSTOMDRAWSize := 80
        } else {
            dwDrawStageOffset := 12
            NMCUSTOMDRAWSize := 48
        }
        clrTextOffset := NMCUSTOMDRAWSize
        clrTextBkOffset := NMCUSTOMDRAWSize + 4
        iSubItemOffset := NMCUSTOMDRAWSize + 8
        dwDrawStage := NumGet(lParam, dwDrawStageOffset, "UInt")
        CDDS_PREPAINT := 0x00000001
        CDDS_ITEMPREPAINT := 0x00010001
        CDDS_SUBITEMPREPAINT := 0x00030001
        CDRF_DODEFAULT := 0x00000000
        ; WinUser.h: NOTIFYITEMDRAW=0x40（预绘后接收行）, NOTIFYSUBITEMDRAW=0x20（行绘后接收列）；勿用 0x04（CDRF_SKIPDEFAULT 会跳过默认绘制导致列表空白）
        CDRF_NOTIFYITEMDRAW := 0x00000040
        CDRF_NOTIFYSUBITEMDRAW := 0x00000020
        CDRF_NEWFONT := 0x00000002
        if (dwDrawStage = CDDS_PREPAINT)
            return CDRF_NOTIFYITEMDRAW
        if (dwDrawStage = CDDS_ITEMPREPAINT)
            return CDRF_NOTIFYSUBITEMDRAW
        if (dwDrawStage = CDDS_SUBITEMPREPAINT) {
            iSubItem := NumGet(lParam, iSubItemOffset, "Int")
            ; 第 3 列（索引 2）：路径/副标题 — 灰色
            if (iSubItem = 2) {
                NumPut("UInt", 0x00808080, lParam, clrTextOffset)
                return CDRF_NEWFONT
            }
            try {
                TextColorStr := UI_Colors.Text
                R := Integer("0x" . SubStr(TextColorStr, 1, 2))
                G := Integer("0x" . SubStr(TextColorStr, 3, 2))
                B := Integer("0x" . SubStr(TextColorStr, 5, 2))
                DefaultTextColor := (B << 16) | (G << 8) | R
            } catch {
                DefaultTextColor := (ThemeMode = "dark") ? 0x00FFFFFF : 0x00000000
            }
            NumPut("UInt", DefaultTextColor, lParam, clrTextOffset)
            return CDRF_NEWFONT
        }
        return CDRF_DODEFAULT
    } catch {
        return ""
    }
}

; ===================== 处理 ListView 自定义绘制（NM_CUSTOMDRAW） =====================
; 用于实现单元格级别的高亮效果
HandleClipboardListViewCustomDraw(lParam) {
    global ClipboardListViewHighlightedRow, ClipboardListViewHighlightedCol
    global ThemeMode, UI_Colors
    
    try {
        ; NMLVCUSTOMDRAW 结构（用于 ListView 的自定义绘制）
        ; 
        ; 首先是 NMCUSTOMDRAW 基础结构：
        ; - NMHDR hdr
        ;     - hwndFrom: HWND (A_PtrSize)
        ;     - idFrom: UINT_PTR (A_PtrSize)
        ;     - code: UINT (4字节)
        ;     - 64位系统padding (4字节)
        ; - dwDrawStage: DWORD (4字节)
        ; - 64位系统padding (4字节)
        ; - hdc: HDC (A_PtrSize)
        ; - rc: RECT (16字节)
        ; - dwItemSpec: DWORD_PTR (A_PtrSize)
        ; - uItemState: UINT (4字节)
        ; - 64位系统padding (4字节)
        ; - lItemlParam: LPARAM (A_PtrSize)
        ;
        ; 然后是 NMLVCUSTOMDRAW 扩展：
        ; - clrText: COLORREF (4字节)
        ; - clrTextBk: COLORREF (4字节)
        ; - iSubItem: int (4字节)
        
        ; 计算各字段偏移量
        if (A_PtrSize = 8) {
            ; 64位系统
            NMHDRSize := 24  ; 8 + 8 + 4 + 4(padding)
            dwDrawStageOffset := 24
            hdcOffset := 32  ; 24 + 4 + 4(padding)
            rcOffset := 40   ; 32 + 8
            dwItemSpecOffset := 56  ; 40 + 16
            uItemStateOffset := 64  ; 56 + 8
            lItemlParamOffset := 72  ; 64 + 4 + 4(padding)
            ; NMCUSTOMDRAW 结束位置: 80 (72 + 8)
            NMCUSTOMDRAWSize := 80
        } else {
            ; 32位系统
            NMHDRSize := 12  ; 4 + 4 + 4
            dwDrawStageOffset := 12
            hdcOffset := 16  ; 12 + 4
            rcOffset := 20   ; 16 + 4
            dwItemSpecOffset := 36  ; 20 + 16
            uItemStateOffset := 40  ; 36 + 4
            lItemlParamOffset := 44 ; 40 + 4
            ; NMCUSTOMDRAW 结束位置: 48 (44 + 4)
            NMCUSTOMDRAWSize := 48
        }
        
        ; NMLVCUSTOMDRAW 扩展字段偏移
        clrTextOffset := NMCUSTOMDRAWSize
        clrTextBkOffset := NMCUSTOMDRAWSize + 4
        iSubItemOffset := NMCUSTOMDRAWSize + 8
        
        ; 读取 dwDrawStage
        dwDrawStage := NumGet(lParam, dwDrawStageOffset, "UInt")
        
        ; 定义常量
        CDDS_PREPAINT := 0x00000001
        CDDS_ITEMPREPAINT := 0x00010001
        CDDS_SUBITEMPREPAINT := 0x00030001
        CDRF_DODEFAULT := 0x00000000
        CDRF_NOTIFYITEMDRAW := 0x00000020
        CDRF_NEWFONT := 0x00000002
        
        ; 整个控件开始绘制 - 请求接收项目绘制通知
        if (dwDrawStage = CDDS_PREPAINT) {
            return CDRF_NOTIFYITEMDRAW
        }
        
        ; 项目开始绘制 - 请求接收子项目绘制通知
        if (dwDrawStage = CDDS_ITEMPREPAINT) {
            return CDRF_NOTIFYITEMDRAW
        }
        
        ; 子项目开始绘制 - 这里设置高亮颜色
        if (dwDrawStage = CDDS_SUBITEMPREPAINT) {
            ; 读取当前绘制的行索引
            iItem := NumGet(lParam, dwItemSpecOffset, "UPtr")
            ; 读取当前绘制的列索引
            iSubItem := NumGet(lParam, iSubItemOffset, "Int")
            
            ; 转换为从1开始的索引
            RowIndex := iItem + 1
            ColIndex := iSubItem + 1
            
            ; 【关键修复】必须始终设置颜色，否则会继承之前的颜色
            ; 从 UI_Colors 获取默认颜色，并转换为 BGR 格式
            ; UI_Colors.InputBg 是 RGB 十六进制字符串，如 "2B2B2B"
            ; 需要转换为 BGR 整数
            try {
                ; 获取背景色（RGB字符串）
                BgColorStr := UI_Colors.InputBg
                ; 转换 RGB 字符串为 BGR 整数
                ; 例如 "2B2B2B" -> 0x002B2B2B (恰好 BGR 和 RGB 相同因为 R=G=B)
                R := Integer("0x" . SubStr(BgColorStr, 1, 2))
                G := Integer("0x" . SubStr(BgColorStr, 3, 2))
                B := Integer("0x" . SubStr(BgColorStr, 5, 2))
                DefaultBgColor := (B << 16) | (G << 8) | R  ; BGR 格式
                
                ; 获取文字色
                TextColorStr := UI_Colors.Text
                R := Integer("0x" . SubStr(TextColorStr, 1, 2))
                G := Integer("0x" . SubStr(TextColorStr, 3, 2))
                B := Integer("0x" . SubStr(TextColorStr, 5, 2))
                DefaultTextColor := (B << 16) | (G << 8) | R  ; BGR 格式
            } catch as err {
                ; 如果获取失败，使用硬编码的默认值
                if (ThemeMode = "dark") {
                    DefaultBgColor := 0x002B2B2B   ; 暗色背景 BGR
                    DefaultTextColor := 0x00FFFFFF ; 白色文字 BGR
                } else {
                    DefaultBgColor := 0x00FFFFFF   ; 白色背景 BGR
                    DefaultTextColor := 0x00000000 ; 黑色文字 BGR
                }
            }
            
            ; 检查是否是我们选中的单元格
            if (RowIndex = ClipboardListViewHighlightedRow && ColIndex = ClipboardListViewHighlightedCol) {
                ; 设置高亮背景色（使用 BGR 格式）
                if (ThemeMode = "dark") {
                    ; 暗色主题：使用蓝色高亮
                    ; RGB 0078D4 -> BGR D47800
                    HighlightBgColor := 0x00D47800
                    HighlightTextColor := 0x00FFFFFF
                } else {
                    ; 亮色主题：使用浅蓝色高亮
                    ; RGB CCE8FF -> BGR FFE8CC
                    HighlightBgColor := 0x00FFE8CC
                    HighlightTextColor := 0x00000000
                }
                
                ; 写入颜色到 NMLVCUSTOMDRAW 结构
                NumPut("UInt", HighlightTextColor, lParam, clrTextOffset)
                NumPut("UInt", HighlightBgColor, lParam, clrTextBkOffset)
                
                ; 返回 CDRF_NEWFONT 告诉系统使用我们设置的颜色
                return CDRF_NEWFONT
            } else {
                ; 【关键】非选中单元格：重置为默认颜色，防止继承高亮颜色
                NumPut("UInt", DefaultTextColor, lParam, clrTextOffset)
                NumPut("UInt", DefaultBgColor, lParam, clrTextBkOffset)
                
                ; 返回 CDRF_NEWFONT 使用我们设置的默认颜色
                return CDRF_NEWFONT
            }
        }
        
        return CDRF_DODEFAULT
        
    } catch as e {
        try {
            FileAppend("[" . FormatTime(, "yyyy-MM-dd HH:mm:ss") . "] HandleClipboardListViewCustomDraw Error: " . e.Message . "`n", A_ScriptDir "\clipboard_debug.log")
        } catch as err {
        }
        return 0
    }
}

; ===================== 取消 ListView 所有行的选中状态 =====================
; 使用API直接设置，避免触发ItemSelect事件，确保立即生效
UnselectAllListViewRows() {
    global ClipboardListView, ClipboardListViewHwnd
    
    try {
        if (!ClipboardListView || !IsObject(ClipboardListView) || !ClipboardListViewHwnd) {
            return
        }
        
        LV_Hwnd := ClipboardListViewHwnd
        if (!LV_Hwnd) {
            return
        }
        
        ; 获取当前选中的行数
        RowCount := ClipboardListView.GetCount()
        if (RowCount < 1) {
            return
        }
        
        ; 【关键优化】使用LVM_SETITEMSTATE API批量取消所有行的选中状态
        ; LVM_SETITEMSTATE = 0x102B
        ; 使用更高效的方式：一次性处理所有行
        Loop RowCount {
            LVITEM := Buffer(A_PtrSize = 8 ? 80 : 60, 0)
            NumPut("UInt", 0x8, LVITEM, 0)  ; mask = LVIF_STATE
            NumPut("Int", A_Index - 1, LVITEM, A_PtrSize = 8 ? 8 : 4)  ; iItem（从0开始）
            NumPut("UInt", 0, LVITEM, A_PtrSize = 8 ? 16 : 12)  ; state = 0（取消选中）
            NumPut("UInt", 0x2, LVITEM, A_PtrSize = 8 ? 20 : 16)  ; stateMask = LVIS_SELECTED (0x2)
            DllCall("SendMessage", "Ptr", LV_Hwnd, "UInt", 0x102B, "Ptr", A_Index - 1, "Ptr", LVITEM.Ptr, "Int")
        }
        
        ; 【关键】立即强制重绘ListView，确保视觉上立即取消选中
        ; 使用InvalidateRect强制重绘
        DllCall("InvalidateRect", "Ptr", LV_Hwnd, "Ptr", 0, "Int", 1)  ; 1 = TRUE，立即重绘
        DllCall("UpdateWindow", "Ptr", LV_Hwnd)
    } catch as err {
        ; 如果API调用失败，尝试使用Modify方法（可能较慢但更兼容）
        try {
            if (ClipboardListView && IsObject(ClipboardListView)) {
                RowCount := ClipboardListView.GetCount()
                Loop RowCount {
                    ClipboardListView.Modify(A_Index, "-Select")
                }
                ClipboardListView.Redraw()
            }
        } catch as err {
            ; 忽略错误
        }
    }
}

; ===================== 创建单元格高亮覆盖层 =====================
; 使用小型覆盖层GUI实现单元格高亮，比自定义绘制更可靠
; 覆盖层只显示在单元格位置，不会遮挡其他内容
CreateClipboardHighlightOverlay() {
    global ClipboardHighlightOverlay, ClipboardListView, ClipboardManagerHwnd
    global ClipboardListViewHighlightedRow, ClipboardListViewHighlightedCol
    
    ; 不需要预先创建，在UpdateClipboardHighlightOverlay中按需创建
}

; ===================== 更新单元格高亮覆盖层显示 =====================
UpdateClipboardHighlightOverlay() {
    global ClipboardHighlightOverlay, ClipboardListView, ClipboardManagerHwnd
    global ClipboardListViewHighlightedRow, ClipboardListViewHighlightedCol, ClipboardCurrentTab
    global UI_Colors, ThemeMode
    
    try {
        ; 只在CapsLockC标签时显示覆盖层
        if (ClipboardCurrentTab != "CapsLockC") {
            DestroyClipboardHighlightOverlay()
            return
        }
        
        ; 如果没有有效的行和列索引，销毁覆盖层
        if (ClipboardListViewHighlightedRow < 1 || ClipboardListViewHighlightedCol < 1) {
            DestroyClipboardHighlightOverlay()
            return
        }
        
        if (!ClipboardListView || !IsObject(ClipboardListView) || !ClipboardManagerHwnd) {
            DestroyClipboardHighlightOverlay()
            return
        }
        
        ; 获取ListView的位置和大小
        ClipboardListView.GetPos(&LVX, &LVY, &LVW, &LVH)
        
        ; 获取父窗口的屏幕坐标
        WinGetPos(&WinX, &WinY, &WinW, &WinH, "ahk_id " . ClipboardManagerHwnd)
        
        ; 计算ListView在屏幕上的绝对位置
        ScreenX := WinX + LVX
        ScreenY := WinY + LVY
        
        ; 【调试日志】记录窗口和ListView位置
        try {
            FileAppend("[" . FormatTime(, "yyyy-MM-dd HH:mm:ss") . "] Window: X=" . WinX . ", Y=" . WinY . ", ListView: X=" . LVX . ", Y=" . LVY . ", ScreenX=" . ScreenX . ", ScreenY=" . ScreenY . "`n", A_ScriptDir "\clipboard_debug.log")
        } catch as err {
        }
        
        ; 获取单元格的矩形位置（相对于ListView）
        LV_Hwnd := ClipboardListView.Hwnd
        if (!LV_Hwnd) {
            DestroyClipboardHighlightOverlay()
            return
        }
        
        ; 使用列宽计算方法获取单元格矩形（更可靠）
        ; LVM_GETSUBITEMRECT 在某些情况下不能正确返回子项矩形
        
        ; 首先获取行的矩形（使用 LVM_GETITEMRECT）
        ; LVM_GETITEMRECT = 0x100E, LVIR_BOUNDS = 0
        RECT := Buffer(16, 0)
        NumPut("Int", 0, RECT, 0)  ; left = LVIR_BOUNDS
        Result := DllCall("SendMessage", "Ptr", LV_Hwnd, "UInt", 0x100E, "Ptr", ClipboardListViewHighlightedRow - 1, "Ptr", RECT.Ptr, "Int")
        
        if (!Result) {
            try {
                FileAppend("[" . FormatTime(, "yyyy-MM-dd HH:mm:ss") . "] LVM_GETITEMRECT FAILED`n", A_ScriptDir "\clipboard_debug.log")
            } catch as err {
            }
            DestroyClipboardHighlightOverlay()
            return
        }
        
        ; 读取行矩形
        RowTop := NumGet(RECT, 4, "Int")     ; top
        RowBottom := NumGet(RECT, 12, "Int") ; bottom
        
        ; 计算列的左边界和宽度（使用 LVM_GETCOLUMNWIDTH）
        ; LVM_GETCOLUMNWIDTH = 0x101D
        CellLeft := 0
        ColIndex := ClipboardListViewHighlightedCol
        
        ; 累加前面所有列的宽度
        Loop (ColIndex - 1) {
            ColWidth := DllCall("SendMessage", "Ptr", LV_Hwnd, "UInt", 0x101D, "Ptr", A_Index - 1, "Ptr", 0, "Int")
            ; 【调试日志】记录每列的宽度(在累加前输出,显示该列的起始位置)
            try {
                FileAppend("[" . FormatTime(, "yyyy-MM-dd HH:mm:ss") . "] Col " . A_Index . " width=" . ColWidth . ", CellLeft=" . CellLeft . "`n", A_ScriptDir "\clipboard_debug.log")
            } catch as err {
            }
            CellLeft += ColWidth
        }
        
        ; 获取当前列的宽度
        CellWidth := DllCall("SendMessage", "Ptr", LV_Hwnd, "UInt", 0x101D, "Ptr", ColIndex - 1, "Ptr", 0, "Int")
        CellRight := CellLeft + CellWidth
        CellTop := RowTop
        CellBottom := RowBottom
        
        ; 【调试日志】记录当前列的宽度
        try {
            FileAppend("[" . FormatTime(, "yyyy-MM-dd HH:mm:ss") . "] Current Col " . ColIndex . " width=" . CellWidth . "`n", A_ScriptDir "\clipboard_debug.log")
        } catch as err {
        }
        
        ; 【调试日志】记录计算结果
        try {
            FileAppend("[" . FormatTime(, "yyyy-MM-dd HH:mm:ss") . "] CalcCell: Col=" . ColIndex . ", CellLeft=" . CellLeft . ", CellWidth=" . CellWidth . ", RowTop=" . RowTop . ", RowBottom=" . RowBottom . "`n", A_ScriptDir "\clipboard_debug.log")
        } catch as err {
        }
        
        ; 设置 Result 为成功（因为我们已经手动计算了）
        Result := 1
        
        ; 计算单元格在屏幕上的绝对位置
        CellScreenX := ScreenX + CellLeft
        CellScreenY := ScreenY + CellTop
        CellHeight := CellBottom - CellTop
        
        ; 【调试日志】记录单元格位置和尺寸
        try {
            FileAppend("[" . FormatTime(, "yyyy-MM-dd HH:mm:ss") . "] CellRect: Left=" . CellLeft . ", Top=" . CellTop . ", Width=" . CellWidth . ", Height=" . CellHeight . ", ScreenX=" . CellScreenX . ", ScreenY=" . CellScreenY . "`n", A_ScriptDir "\clipboard_debug.log")
        } catch as err {
        }
        
        ; 如果单元格尺寸无效，销毁覆盖层
        if (CellWidth <= 0 || CellHeight <= 0) {
            try {
                FileAppend("[" . FormatTime(, "yyyy-MM-dd HH:mm:ss") . "] Invalid cell size: Width=" . CellWidth . ", Height=" . CellHeight . "`n", A_ScriptDir "\clipboard_debug.log")
            } catch as err {
            }
            DestroyClipboardHighlightOverlay()
            return
        }
        
        ; 选择高亮颜色（根据主题模式）- 使用与系统选中效果类似的蓝色
        if (ThemeMode = "dark") {
            ; 暗色主题：使用蓝色高亮（与系统选中效果类似）
            HighlightColor := "0078D4"
        } else {
            ; 亮色主题：使用浅蓝色高亮
            HighlightColor := "CCE8FF"
        }
        
        ; 如果覆盖层不存在，创建它；如果已存在，更新位置和大小
        if (!ClipboardHighlightOverlay) {
            ; 创建小型覆盖层GUI（只覆盖单元格大小）
            ; -Caption = 无标题栏
            ; +ToolWindow = 工具窗口（不显示在任务栏）
            ; +AlwaysOnTop = 始终置顶，确保在ListView上方
            ClipboardHighlightOverlay := Gui("+AlwaysOnTop -Caption +ToolWindow", "")
            ClipboardHighlightOverlay.BackColor := HighlightColor
            
            ; 创建高亮矩形控件（填充整个窗口）
            HighlightRect := ClipboardHighlightOverlay.Add("Text", "x0 y0 w" . CellWidth . " h" . CellHeight . " Background" . HighlightColor, "")
            
            ; 设置半透明效果（透明度128 = 50%），让用户可以看到底下的单元格文字
            WinSetTransparent(128, ClipboardHighlightOverlay)
        } else {
            ; 更新现有覆盖层的位置和大小
            try {
                ; 清除旧控件
                for Ctrl in ClipboardHighlightOverlay {
                    Ctrl.Destroy()
                }
                ; 重新创建高亮矩形
                HighlightRect := ClipboardHighlightOverlay.Add("Text", "x0 y0 w" . CellWidth . " h" . CellHeight . " Background" . HighlightColor, "")
                ClipboardHighlightOverlay.BackColor := HighlightColor
            } catch as err {
                ; 如果更新失败，重新创建
                DestroyClipboardHighlightOverlay()
                ClipboardHighlightOverlay := Gui("+AlwaysOnTop -Caption +ToolWindow", "")
                ClipboardHighlightOverlay.BackColor := HighlightColor
                HighlightRect := ClipboardHighlightOverlay.Add("Text", "x0 y0 w" . CellWidth . " h" . CellHeight . " Background" . HighlightColor, "")
            }
        }
        
        ; 显示覆盖层窗口（位置和大小精确匹配单元格）
        ClipboardHighlightOverlay.Show("x" . CellScreenX . " y" . CellScreenY . " w" . CellWidth . " h" . CellHeight . " NoActivate")
        
        ; 【调试日志】记录覆盖层显示
        try {
            FileAppend("[" . FormatTime(, "yyyy-MM-dd HH:mm:ss") . "] Overlay shown at: X=" . CellScreenX . ", Y=" . CellScreenY . ", W=" . CellWidth . ", H=" . CellHeight . "`n", A_ScriptDir "\clipboard_debug.log")
        } catch as err {
        }
        
        ; 使用API设置覆盖层窗口的Z-order，确保它在ListView上方
        ; 剪贴板管理窗口使用 +AlwaysOnTop（TOPMOST），所以覆盖层也必须是 TOPMOST
        try {
            OverlayHwnd := ClipboardHighlightOverlay.Hwnd
            if (OverlayHwnd) {
                ; SetWindowPos：将覆盖层窗口置于最顶层（TOPMOST）
                ; hWndInsertAfter = -1 (HWND_TOPMOST)，必须使用TOPMOST才能显示在AlwaysOnTop窗口上方
                ; X, Y, cx, cy 设置为0表示不改变位置和大小（因为已经在Show中设置了）
                ; uFlags = SWP_NOMOVE(0x0002) | SWP_NOSIZE(0x0001) | SWP_NOACTIVATE(0x0010) | SWP_SHOWWINDOW(0x0040)
                HWND_TOPMOST := -1
                DllCall("SetWindowPos", "Ptr", OverlayHwnd, "Ptr", HWND_TOPMOST, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x0002 | 0x0001 | 0x0010 | 0x0040)
                
                        ; 【调试日志】记录 SetWindowPos 调用并验证窗口状态
                try {
                    ; 检查窗口是否可见
                    IsVisible := DllCall("IsWindowVisible", "Ptr", OverlayHwnd, "Int")
                    ; 检查窗口是否最小化
                    IsIconic := DllCall("IsIconic", "Ptr", OverlayHwnd, "Int")
                    FileAppend("[" . FormatTime(, "yyyy-MM-dd HH:mm:ss") . "] SetWindowPos: OverlayHwnd=" . OverlayHwnd . ", IsVisible=" . IsVisible . ", IsIconic=" . IsIconic . "`n", A_ScriptDir "\clipboard_debug.log")
                } catch as err {
                }
            }
        } catch as e {
            ; 如果API调用失败，记录错误
            try {
                FileAppend("[" . FormatTime(, "yyyy-MM-dd HH:mm:ss") . "] SetWindowPos Error: " . e.Message . "`n", A_ScriptDir "\clipboard_debug.log")
            } catch as err {
            }
        }
        
        ; 将覆盖层窗口设置为剪贴板管理窗口的子窗口，确保同步移动和层级关系
        ; SetParent会改变窗口的坐标系统，所以我们不使用它，而是在窗口移动时手动更新位置
        
    } catch as e {
        ; 出错时销毁覆盖层
        DestroyClipboardHighlightOverlay()
        ; 可选：记录错误日志
        ; FileAppend("[" . FormatTime(, "yyyy-MM-dd HH:mm:ss") . "] UpdateClipboardHighlightOverlay Error: " . e.Message . "`n", A_ScriptDir "\clipboard_debug.log")
    }
}

; ===================== 销毁单元格高亮覆盖层 =====================
DestroyClipboardHighlightOverlay() {
    global ClipboardHighlightOverlay, ClipboardHighlightOverlayBrush
    
    try {
        if (ClipboardHighlightOverlay) {
            ClipboardHighlightOverlay.Destroy()
            ClipboardHighlightOverlay := 0
        }
        if (ClipboardHighlightOverlayBrush) {
            DllCall("gdi32.dll\DeleteObject", "Ptr", ClipboardHighlightOverlayBrush)
            ClipboardHighlightOverlayBrush := 0
        }
    } catch as err {
        ClipboardHighlightOverlay := 0
        ClipboardHighlightOverlayBrush := 0
    }
}

; ===================== 延迟取消ListView选中（辅助函数） =====================
DelayUnselectListViewRows(*) {
    global ClipboardListView
    if (ClipboardListView && IsObject(ClipboardListView)) {
        UnselectAllListViewRows()
    }
}

; ===================== ListView项目选择事件处理（更新统计信息和单元格高亮） =====================
OnClipboardListViewItemSelect(Control, Item, *) {
    global ClipboardListView, ClipboardDB, ClipboardCurrentTab, GuiID_ClipboardManager
    
    ; 【关键修复】延迟取消选中，确保双击事件能够正常触发
    ; 使用定时器延迟150ms后取消选中，这样双击事件可以在两次单击之间正常触发
    SetTimer(DelayUnselectListViewRows, -150)  ; 延迟150ms执行，只执行一次
    
    ; 只在CapsLockC标签时处理
    if (ClipboardCurrentTab != "CapsLockC" || !ClipboardListView || !IsObject(ClipboardListView)) {
        return
    }
    
    ; 获取选中的行（Item参数是行索引，从1开始）
    RowIndex := Item
    if (RowIndex < 1) {
        return
    }
    
    ; 更新统计信息：显示当前选中行的选项数值
    try {
        if (ClipboardDB && ClipboardDB != 0) {
            ; 从ListView获取阶段标签（第一列），提取SessionID
            StageLabel := ClipboardListView.GetText(RowIndex, 1)
            if (StageLabel != "") {
                RegExMatch(StageLabel, "阶段\s+(\d+)", &Match)
                if (Match && Match[1]) {
                    SessionID := Integer(Match[1])
                    
                    ; 查询该SessionID对应的ItemIndex数量
                    ResultTable := ""
                    SQL := "SELECT COUNT(DISTINCT ItemIndex) FROM ClipboardHistory WHERE SessionID = " . SessionID
                    if (ClipboardDB.GetTable(SQL, &ResultTable)) {
                        if (ResultTable && ResultTable.HasProp("Rows") && ResultTable.Rows.Length > 0 && ResultTable.Rows[1].Length > 0) {
                            ItemCount := ResultTable.Rows[1][1]
                            if (ItemCount != "") {
                                ; ClipboardCountText 已移除
                            }
                        }
                    }
                }
            }
        }
    } catch as err {
        ; 忽略错误
    }
    
    ; 注意：单元格高亮现在通过NM_CLICK消息直接处理（在OnClipboardListViewWMNotify中）
    ; 这里只处理统计信息更新，不再处理单元格高亮
}

; ===================== 从数据库获取单元格完整内容 =====================
GetCellFullContent(RowIndex, ColIndex) {
    global ClipboardDB, ClipboardListView
    
    try {
        if (!ClipboardDB || ClipboardDB = 0 || !ClipboardListView) {
            return ""
        }
        
        ; 从ListView获取阶段标签（第一列），提取SessionID
        StageLabel := ClipboardListView.GetText(RowIndex, 1)
        if (StageLabel = "") {
            return ""
        }
        
        ; 解析阶段标签：格式为 "阶段 X"
        RegExMatch(StageLabel, "阶段\s+(\d+)", &Match)
        if (!Match || !Match[1]) {
            return ""
        }
        SessionID := Integer(Match[1])
        
        ; 如果是第一列（阶段标签列），返回阶段标签文本
        if (ColIndex = 1) {
            return StageLabel
        }
        
        ; 其他列：ItemIndex = ColIndex - 1（因为第一列是阶段标签）
        ItemIndex := ColIndex - 1
        
        ; 从数据库查询完整内容
        ResultTable := ""
        SQL := "SELECT Content FROM ClipboardHistory WHERE SessionID = " . SessionID . " AND ItemIndex = " . ItemIndex . " LIMIT 1"
        if (ClipboardDB.GetTable(SQL, &ResultTable)) {
            if (ResultTable && ResultTable.HasProp("Rows") && ResultTable.Rows.Length > 0) {
                if (ResultTable.Rows[1].Length > 0) {
                    return ResultTable.Rows[1][1]  ; Content列
                }
            }
        }
    } catch as err {
    }
    
    return ""
}

; 获取单元格数据类型
GetCellDataType(RowIndex, ColIndex) {
    global ClipboardDB, ClipboardListView
    
    try {
        if (!ClipboardDB || ClipboardDB = 0 || !ClipboardListView) {
            return "Text"
        }
        
        ; 从ListView获取阶段标签（第一列），提取SessionID
        StageLabel := ClipboardListView.GetText(RowIndex, 1)
        if (StageLabel = "") {
            return "Text"
        }
        
        ; 解析阶段标签：格式为 "阶段 X"
        RegExMatch(StageLabel, "阶段\s+(\d+)", &Match)
        if (!Match || !Match[1]) {
            return "Text"
        }
        SessionID := Integer(Match[1])
        
        ; 如果是第一列（阶段标签列），返回默认类型
        if (ColIndex = 1) {
            return "Text"
        }
        
        ; 其他列：ItemIndex = ColIndex - 1（因为第一列是阶段标签）
        ItemIndex := ColIndex - 1
        
        ; 从数据库查询数据类型
        ResultTable := ""
        SQL := "SELECT DataType FROM ClipboardHistory WHERE SessionID = " . SessionID . " AND ItemIndex = " . ItemIndex . " LIMIT 1"
        if (ClipboardDB.GetTable(SQL, &ResultTable)) {
            if (ResultTable && ResultTable.HasProp("Rows") && ResultTable.Rows.Length > 0) {
                if (ResultTable.Rows[1].Length > 0) {
                    DataType := ResultTable.Rows[1][1]
                    return (DataType != "") ? DataType : "Text"
                }
            }
        }
    } catch as err {
    }
    
    return "Text"
}

; ===================== 搜索功能：搜索关键词变化事件 =====================
OnClipboardSearchChange(Control, *) {
    ; 参考 SearchCenter 的实现，添加防抖搜索机制
    global ClipboardSearchTimer, ClipboardCurrentTab
    
    ; 取消之前的防抖定时器
    if (ClipboardSearchTimer != 0) {
        try {
            SetTimer(ClipboardSearchTimer, 0)
            ClipboardSearchTimer := 0
        } catch {
        }
    }
    
    ; 设置新的防抖定时器（300ms 延迟，参考 ClipboardHistoryPanel）
    ClipboardSearchTimer := DebouncedClipboardSearch
    SetTimer(ClipboardSearchTimer, -300)
}

; ===================== 执行搜索刷新（防抖回调，参考 SearchCenter）=====================
DebouncedClipboardSearch(*) {
    global ClipboardSearchTimer, GuiID_ClipboardManager, ClipboardCurrentTab
    
    ; 清除定时器引用
    ClipboardSearchTimer := 0
    
    ; 只在 CapsLockC 标签时执行搜索刷新
    if (ClipboardCurrentTab != "CapsLockC") {
        return
    }
    
    try {
        ; 获取搜索关键词
        if (!GuiID_ClipboardManager || !IsObject(GuiID_ClipboardManager)) {
            return
        }
        
        SearchEdit := GuiID_ClipboardManager["ClipboardSearchEdit"]
        if (!SearchEdit || !IsObject(SearchEdit)) {
            return
        }
        
        ; 参考 SearchCenter 的实现，使用 Trim 处理关键词
        Keyword := Trim(SearchEdit.Value)
        
        ; 如果搜索框为空，清除搜索结果并刷新列表
        if (Keyword = "") {
            global ClipboardSearchMatches, ClipboardSearchCurrentIndex
            ClipboardSearchMatches := []
            ClipboardSearchCurrentIndex := 0
            
            ; 隐藏跳转按钮
            try {
                SearchPrevBtn := GuiID_ClipboardManager["ClipboardSearchPrevBtn"]
                SearchNextBtn := GuiID_ClipboardManager["ClipboardSearchNextBtn"]
                if (SearchPrevBtn && IsObject(SearchPrevBtn)) {
                    SearchPrevBtn.Visible := false
                }
                if (SearchNextBtn && IsObject(SearchNextBtn)) {
                    SearchNextBtn.Visible := false
                }
            } catch {
            }
        }
        
        ; 刷新列表（RefreshClipboardListView 函数内部会读取搜索关键词并过滤）
        RefreshClipboardListView()
    } catch as err {
        OutputDebug("AHK_DEBUG: DebouncedClipboardSearch 错误: " . err.Message . "`n")
    }
}

; 剪贴板管理结果数量限制下拉菜单变化事件处理
OnClipboardManagementResultLimitChange(Control, *) {
    global ClipboardManagementEverythingLimit, ClipboardCurrentTab
    
    ; 获取选中的值
    SelectedValue := Control.Text
    if (SelectedValue != "") {
        ; 更新全局限制值
        ClipboardManagementEverythingLimit := Integer(SelectedValue)
        
        ; 如果当前标签是 CapsLockC，重新加载数据
        if (ClipboardCurrentTab = "CapsLockC") {
            ; 调用刷新函数重新加载数据
            try {
                RefreshClipboardListView()
            } catch as err {
                OutputDebug("AHK_DEBUG: OnClipboardManagementResultLimitChange - 刷新失败: " . err.Message)
            }
        }
    }
}

; ===================== 搜索框回车键处理（窗口级别快捷键） =====================
; 注意：由于Edit控件不支持Enter事件，我们使用窗口级别的快捷键
; 当剪贴板管理窗口激活时，回车键会触发搜索（如果焦点在搜索框上）
; 这个功能通过Hotkey在窗口显示时启用，窗口关闭时禁用

; ===================== 搜索功能：执行搜索 =====================
OnClipboardSearch(*) {
    global ClipboardSearchMatches, ClipboardSearchCurrentIndex, ClipboardSearchKeyword
    global ClipboardListView, ClipboardDB, ClipboardCurrentTab, GuiID_ClipboardManager
    
    ; 只在CapsLockC标签时搜索
    if (ClipboardCurrentTab != "CapsLockC" || !ClipboardListView || !IsObject(ClipboardListView)) {
        return
    }
    
    try {
        ; 获取搜索关键词
        SearchEdit := GuiID_ClipboardManager["ClipboardSearchEdit"]
        if (!SearchEdit) {
            return
        }
        Keyword := Trim(SearchEdit.Text)
        if (Keyword = "") {
            ClipboardSearchMatches := []
            ClipboardSearchCurrentIndex := 0
            return
        }
        
        ClipboardSearchKeyword := Keyword
        
        ; 从数据库搜索所有匹配的单元格
        ClipboardSearchMatches := []
        
        if (!ClipboardDB || ClipboardDB = 0) {
            TrayTip("搜索失败", "数据库未初始化", "Iconx 1")
            return
        }
        
        ; 查询所有数据
        ResultTable := ""
        SQL := "SELECT ID, Content FROM ClipboardHistory ORDER BY Timestamp DESC"
        if (!ClipboardDB.GetTable(SQL, &ResultTable)) {
            TrayTip("搜索失败", "数据库查询失败", "Iconx 1")
            return
        }
        
        if (!ResultTable || !ResultTable.HasProp("Rows") || ResultTable.Rows.Length = 0) {
            TrayTip("搜索完成", "未找到匹配项", "Iconi 1")
            return
        }
        
        ; 获取ListView的行数，建立SessionID到行索引的映射
        RowCount := ClipboardListView.GetCount()
        SessionIDToRowIndex := Map()
        Loop RowCount {
            RowLabel := ClipboardListView.GetText(A_Index, 1)
            if (RegExMatch(RowLabel, "阶段\s+(\d+)", &Match)) {
                SessionID := Integer(Match[1])
                SessionIDToRowIndex[SessionID] := A_Index
            }
        }
        
        ; 遍历所有数据，查找匹配项
        for Index, Row in ResultTable.Rows {
            if (Row.Length < 4) {
                continue
            }
            
            SessionID := Integer(Row[2])
            ItemIndex := Integer(Row[3])
            Content := String(Row[4])
            
            ; 检查内容是否包含关键词（不区分大小写）
            if (InStr(Content, Keyword, true)) {
                ; 找到匹配的行索引
                RowIndex := 0
                if (SessionIDToRowIndex.Has(SessionID)) {
                    RowIndex := SessionIDToRowIndex[SessionID]
                }
                
                ; 计算列索引（第1列是阶段标签，ItemIndex对应的列是ItemIndex+1）
                ColIndex := ItemIndex + 1
                
                ; 添加到匹配列表
                ClipboardSearchMatches.Push({RowIndex: RowIndex, ColIndex: ColIndex, SessionID: SessionID, ItemIndex: ItemIndex})
            }
        }
        
        ; 如果有匹配项，跳转到第一个
        if (ClipboardSearchMatches.Length > 0) {
            ClipboardSearchCurrentIndex := 0
            JumpToSearchMatch(0)
            
            ; 显示跳转按钮（如果有多个匹配）
            if (ClipboardSearchMatches.Length > 1) {
                try {
                    SearchPrevBtn := GuiID_ClipboardManager["ClipboardSearchPrevBtn"]
                    SearchNextBtn := GuiID_ClipboardManager["ClipboardSearchNextBtn"]
                    if (SearchPrevBtn && IsObject(SearchPrevBtn)) {
                        SearchPrevBtn.Visible := true
                    }
                    if (SearchNextBtn && IsObject(SearchNextBtn)) {
                        SearchNextBtn.Visible := true
                    }
                } catch as err {
                }
            }
            
            TrayTip("搜索完成", "找到 " . ClipboardSearchMatches.Length . " 个匹配项", "Iconi 1")
        } else {
            TrayTip("搜索完成", "未找到匹配项", "Iconi 1")
            ; 隐藏跳转按钮
            try {
                SearchPrevBtn := GuiID_ClipboardManager["ClipboardSearchPrevBtn"]
                SearchNextBtn := GuiID_ClipboardManager["ClipboardSearchNextBtn"]
                if (SearchPrevBtn && IsObject(SearchPrevBtn)) {
                    SearchPrevBtn.Visible := false
                }
                if (SearchNextBtn && IsObject(SearchNextBtn)) {
                    SearchNextBtn.Visible := false
                }
            } catch as err {
            }
        }
    } catch as e {
        TrayTip("搜索失败", e.Message, "Iconx 1")
    }
}

; ===================== 搜索功能：跳转到匹配项（精确定位到单元格） =====================
JumpToSearchMatch(MatchIndex) {
    global ClipboardSearchMatches, ClipboardListView, ClipboardSearchCurrentIndex
    
    if (!ClipboardSearchMatches || ClipboardSearchMatches.Length = 0) {
        return
    }
    
    if (MatchIndex < 0 || MatchIndex >= ClipboardSearchMatches.Length) {
        return
    }
    
    try {
        Match := ClipboardSearchMatches[MatchIndex + 1]  ; 数组索引从1开始
        RowIndex := Match.RowIndex
        ColIndex := Match.ColIndex
        
        if (RowIndex > 0 && ClipboardListView && IsObject(ClipboardListView)) {
            LV_Hwnd := ClipboardListView.Hwnd
            if (LV_Hwnd) {
                ; 先取消所有行的选中状态，只激活匹配单元格所在的行
                RowCount := ClipboardListView.GetCount()
                Loop RowCount {
                    if (A_Index != RowIndex) {
                        ; LVM_SETITEMSTATE = 0x102B
                        LVITEM := Buffer(A_PtrSize = 8 ? 80 : 60, 0)
                        NumPut("UInt", 0x8, LVITEM, 0)  ; mask = LVIF_STATE
                        NumPut("Int", A_Index - 1, LVITEM, A_PtrSize = 8 ? 8 : 4)  ; iItem
                        NumPut("UInt", 0, LVITEM, A_PtrSize = 8 ? 16 : 12)  ; state = 0
                        NumPut("UInt", 0x2, LVITEM, A_PtrSize = 8 ? 20 : 16)  ; stateMask = LVIS_SELECTED
                        DllCall("SendMessage", "Ptr", LV_Hwnd, "UInt", 0x102B, "Ptr", A_Index - 1, "Ptr", LVITEM.Ptr, "Int")
                    }
                }
                
                ; 选中匹配的行（ListView不支持单元格级别选中，只能选中整行）
                ClipboardListView.Modify(RowIndex, "Select Focus")
                
                ; 滚动行到可见区域
                ClipboardListView.Modify(RowIndex, "Vis")
                
                ; 精确定位到单元格：使用LVM_GETSUBITEMRECT获取单元格位置并滚动
                ; 创建RECT结构（用于LVM_GETSUBITEMRECT）
                RECT := Buffer(16, 0)
                NumPut("Int", ColIndex - 1, RECT, 0)  ; iSubItem（列索引，从0开始，放在left位置）
                
                ; LVM_GETSUBITEMRECT = 0x1038
                Result := DllCall("SendMessage", "Ptr", LV_Hwnd, "UInt", 0x1038, "Ptr", RowIndex - 1, "Ptr", RECT.Ptr, "Int")
                
                if (Result) {
                    ; 获取单元格的位置（调用后，RECT包含实际的left, top, right, bottom）
                    CellLeft := NumGet(RECT, 0, "Int")   ; left
                    CellTop := NumGet(RECT, 4, "Int")    ; top
                    CellRight := NumGet(RECT, 8, "Int")  ; right
                    CellBottom := NumGet(RECT, 12, "Int") ; bottom
                    
                    ; 获取ListView的位置和大小
                    ClipboardListView.GetPos(&LVX, &LVY, &LVW, &LVH)
                    
                    ; 如果单元格不在可见区域，滚动ListView
                    ScrollX := 0
                    
                    ; 检查单元格是否在可见区域
                    if (CellLeft < 0) {
                        ScrollX := CellLeft - 10  ; 向左滚动，留10px边距
                    } else if (CellRight > LVW) {
                        ScrollX := CellRight - LVW + 10  ; 向右滚动，留10px边距
                    }
                    
                    if (ScrollX != 0) {
                        ; LVM_SCROLL = 0x1014
                        DllCall("SendMessage", "Ptr", LV_Hwnd, "UInt", 0x1014, "Int", ScrollX, "Int", 0, "Int")
                    }
                }
            }
        }
    } catch as err {
    }
}

; ===================== 搜索功能：上一个匹配项 =====================
OnClipboardSearchPrev(*) {
    global ClipboardSearchMatches, ClipboardSearchCurrentIndex
    
    if (!ClipboardSearchMatches || ClipboardSearchMatches.Length = 0) {
        return
    }
    
    ; 向前移动索引（循环）
    ClipboardSearchCurrentIndex--
    if (ClipboardSearchCurrentIndex < 0) {
        ClipboardSearchCurrentIndex := ClipboardSearchMatches.Length - 1
    }
    
    JumpToSearchMatch(ClipboardSearchCurrentIndex)
}

; ===================== 搜索功能：下一个匹配项 =====================
OnClipboardSearchNext(*) {
    global ClipboardSearchMatches, ClipboardSearchCurrentIndex
    
    if (!ClipboardSearchMatches || ClipboardSearchMatches.Length = 0) {
        return
    }
    
    ; 向后移动索引（循环）
    ClipboardSearchCurrentIndex++
    if (ClipboardSearchCurrentIndex >= ClipboardSearchMatches.Length) {
        ClipboardSearchCurrentIndex := 0
    }
    
    JumpToSearchMatch(ClipboardSearchCurrentIndex)
}

; ===================== 显示单元格内容浮窗 =====================
; 全局变量用于存储浮窗引用
global CellContentWindow := 0

; 关闭浮窗的处理函数
CloseCellContentWindow(*) {
    global CellContentWindow
    if (CellContentWindow && IsObject(CellContentWindow)) {
        try {
            CellContentWindow.Destroy()
        } catch as err {
        }
        CellContentWindow := 0
    }
}

; 复制单元格内容的处理函数
OnCellContentCopy(*) {
    global CellContentWindow
    try {
        ; 从编辑框获取当前内容（可能已被用户编辑）
        if (CellContentWindow && IsObject(CellContentWindow)) {
            ContentEdit := CellContentWindow["ContentEdit"]
            if (ContentEdit && IsObject(ContentEdit)) {
                A_Clipboard := ContentEdit.Value
                TrayTip("已复制到剪贴板", "提示", "Iconi 1")
            } else {
                TrayTip("复制失败", "无法获取内容", "Iconx 1")
            }
        }
    } catch as err {
        TrayTip("复制失败", "错误", "Iconx 1")
    }
}

ShowClipboardCellContentWindow(Content, RowIndex, ColIndex, DataType := "") {
    global UI_Colors, ThemeMode, GuiID_ClipboardManager, CellContentWindow

    ; 如果窗口已存在，先销毁
    if (CellContentWindow != 0) {
        try {
            CellContentWindow.Destroy()
        } catch as err {
        }
        CellContentWindow := 0
    }

    try {
        ; 检查是否是图片类型
        IsImage := (DataType = "Image" && FileExist(Content))
        
        ; 创建浮窗
        CellContentWindow := Gui("+AlwaysOnTop -Caption +ToolWindow -DPIScale", IsImage ? "图片预览" : "单元格内容")
        CellContentWindow.BackColor := UI_Colors.Background

        ; 窗口尺寸（图片预览窗口更大）
        if (IsImage) {
            WindowWidth := 800
            WindowHeight := 600
        } else {
            WindowWidth := 600
            WindowHeight := 400
        }

        ; 保存Content到局部变量，供复制按钮使用
        SavedContent := Content
        
        ; 自定义标题栏
        TitleBarHeight := 35
        TitleBar := CellContentWindow.Add("Text", "x0 y0 w" . WindowWidth . " h" . TitleBarHeight . " Background" . UI_Colors.TitleBar, "")
        TitleBar.OnEvent("Click", (*) => PostMessage(0xA1, 2))
        
        TitleText := CellContentWindow.Add("Text", "x20 y8 w" . (WindowWidth - 80) . " h20 Background" . UI_Colors.TitleBar . " c" . UI_Colors.Text, "单元格内容 (行 " . RowIndex . ", 列 " . ColIndex . ")")
        TitleText.SetFont("s10 Bold", "Segoe UI")
        TitleText.OnEvent("Click", (*) => PostMessage(0xA1, 2))
        
        ; 关闭按钮（标题栏右上角）
        CloseBtn := CellContentWindow.Add("Text", "x" . (WindowWidth - 40) . " y0 w40 h" . TitleBarHeight . " Center 0x200 Background" . UI_Colors.TitleBar . " c" . UI_Colors.Text . " vCellContentCloseBtn", "✕")
        CloseBtn.SetFont("s12", "Segoe UI")
        CloseBtn.OnEvent("Click", CloseCellContentWindow)
        HoverBtn(CloseBtn, UI_Colors.TitleBar, "e81123")
        
        ; 分隔线
        CellContentWindow.Add("Text", "x0 y" . TitleBarHeight . " w" . WindowWidth . " h1 Background" . UI_Colors.Border, "")
        
        ; 内容编辑框（可编辑、可选中、可复制）- 移除ReadOnly以支持编辑
        ContentY := TitleBarHeight + 10
        ContentHeight := WindowHeight - TitleBarHeight - 60
        ContentEdit := CellContentWindow.Add("Edit", "x20 y" . ContentY . " w" . (WindowWidth - 40) . " h" . ContentHeight . " Multi Background" . UI_Colors.InputBg . " c" . UI_Colors.Text . " +VScroll +HScroll vContentEdit", Content)
        ContentEdit.SetFont("s9", "Consolas")
        
        ; 底部按钮区域
        BtnY := WindowHeight - 45
        TextColor := (ThemeMode = "dark") ? "FFFFFF" : "000000"
        
        ; 复制按钮
        CopyBtn := CellContentWindow.Add("Text", "x20 y" . BtnY . " w100 h35 Center 0x200 c" . TextColor . " Background" . UI_Colors.BtnPrimary . " vCellContentCopyBtn", "📋 复制")
        CopyBtn.SetFont("s10", "Segoe UI")
        CopyBtn.OnEvent("Click", OnCellContentCopy)
        HoverBtn(CopyBtn, UI_Colors.BtnPrimary, UI_Colors.BtnPrimaryHover)
        
        ; 关闭按钮（底部）
        CloseBtn2 := CellContentWindow.Add("Text", "x" . (WindowWidth - 120) . " y" . BtnY . " w100 h35 Center 0x200 c" . TextColor . " Background" . UI_Colors.BtnBg . " vCellContentCloseBtn2", "关闭")
        CloseBtn2.SetFont("s10", "Segoe UI")
        CloseBtn2.OnEvent("Click", CloseCellContentWindow)
        HoverBtn(CloseBtn2, UI_Colors.BtnBg, UI_Colors.BtnHover)
        
        ; 绑定ESC关闭
        CellContentWindow.OnEvent("Escape", CloseCellContentWindow)
        
        ; 显示窗口（居中显示）
        try {
            CellContentWindow.Show("w" . WindowWidth . " h" . WindowHeight . " Center")
            FileAppend("[" . FormatTime(, "yyyy-MM-dd HH:mm:ss") . "] ShowClipboardCellContentWindow: Window shown, Hwnd=" . CellContentWindow.Hwnd . "`n", A_ScriptDir "\clipboard_debug.log")
        } catch as e {
            FileAppend("[" . FormatTime(, "yyyy-MM-dd HH:mm:ss") . "] ShowClipboardCellContentWindow: Show() Error: " . e.Message . "`n", A_ScriptDir "\clipboard_debug.log")
            throw e
        }
        
        ; 确保窗口在最上层
        try {
            WinSetAlwaysOnTop(1, CellContentWindow.Hwnd)
            FileAppend("[" . FormatTime(, "yyyy-MM-dd HH:mm:ss") . "] ShowClipboardCellContentWindow: AlwaysOnTop set`n", A_ScriptDir "\clipboard_debug.log")
        } catch as e {
            FileAppend("[" . FormatTime(, "yyyy-MM-dd HH:mm:ss") . "] ShowClipboardCellContentWindow: WinSetAlwaysOnTop Error: " . e.Message . "`n", A_ScriptDir "\clipboard_debug.log")
        }
        
    } catch as e {
        FileAppend("[" . FormatTime(, "yyyy-MM-dd HH:mm:ss") . "] ShowClipboardCellContentWindow: Exception: " . e.Message . "`n", A_ScriptDir "\clipboard_debug.log")
        TrayTip("显示浮窗失败: " . e.Message, "错误", "Iconx 1")
        CellContentWindow := 0
    }
}

; ===================== 辅助函数：数组降序排序 =====================
SortArrayDesc(Array) {
    ; 使用冒泡排序实现降序排列
    SortedArray := []
    for Item in Array {
        SortedArray.Push(Item)
    }
    
    n := SortedArray.Length
    Loop n - 1 {
        i := A_Index
        Loop n - i {
            j := A_Index
            if (SortedArray[j] < SortedArray[j + 1]) {
                ; 交换
                Temp := SortedArray[j]
                SortedArray[j] := SortedArray[j + 1]
                SortedArray[j + 1] := Temp
            }
        }
    }
    
    return SortedArray
}

; ===================== 辅助函数：数组排序 =====================
SortArray(Array, Ascending := true) {
    ; 简单的冒泡排序实现
    SortedArray := []
    for Item in Array {
        SortedArray.Push(Item)
    }
    
    n := SortedArray.Length
    Loop (n - 1) {
        i := A_Index
        Loop (n - i) {
            j := A_Index
            if (Ascending) {
                if (SortedArray[j] > SortedArray[j + 1]) {
                    ; 交换
                    Temp := SortedArray[j]
                    SortedArray[j] := SortedArray[j + 1]
                    SortedArray[j + 1] := Temp
                }
            } else {
                if (SortedArray[j] < SortedArray[j + 1]) {
                    ; 交换
                    Temp := SortedArray[j]
                    SortedArray[j] := SortedArray[j + 1]
                    SortedArray[j + 1] := Temp
                }
            }
        }
    }
    return SortedArray
}

; ===================== 辅助函数：从数据库获取CapsLock+C数据 =====================
; 获取当前标签页的剪贴板数据（从数据库或数组）
GetClipboardDataForCurrentTab() {
    global ClipboardCurrentTab, ClipboardHistory_CtrlC, ClipboardDB
    
    if (ClipboardCurrentTab = "CtrlC") {
        ; Ctrl+C 标签从数组读取
        if (!IsSet(ClipboardHistory_CtrlC) || !IsObject(ClipboardHistory_CtrlC)) {
            global ClipboardHistory_CtrlC := []
        }
        return {Source: "array", Data: ClipboardHistory_CtrlC}
    } else if (ClipboardCurrentTab = "CapsLockC") {
        ; CapsLock+C 标签从数据库读取
        if (ClipboardDB && ClipboardDB != 0) {
            try {
                ResultTable := ""
                ; 【新功能】按SessionID和ItemIndex排序，实现按阶段分组
                if (ClipboardDB.GetTable("SELECT ID, Content FROM ClipboardHistory ORDER BY Timestamp DESC", &ResultTable)) {
                    if (ResultTable && ResultTable.HasProp("Rows") && ResultTable.Rows.Length > 0) {
                        DataArray := []
                        IDArray := []  ; 保存ID，用于删除操作
                        for Index, Row in ResultTable.Rows {
                            ; Row数组索引从1开始：Row[1] = ID, Row[2] = SessionID, Row[3] = ItemIndex, Row[4] = Content
                            if (Row.Length > 3) {
                                ; 存储格式：Map对象，包含SessionID、ItemIndex和Content
                                ItemData := Map()
                                ItemData["SessionID"] := Row[2]
                                ItemData["ItemIndex"] := Row[3]
                                ItemData["Content"] := Row[4]
                                DataArray.Push(ItemData)
                                IDArray.Push(Row[1])    ; ID（第一列），用于删除操作
                            }
                        }
                        return {Source: "database", Data: DataArray, IDs: IDArray}
                    }
                }
            } catch as err {
                ; 数据库读取失败，回退到数组
            }
        }
        ; 如果数据库不可用，回退到数组
        if (!IsSet(ClipboardHistory_CapsLockC) || !IsObject(ClipboardHistory_CapsLockC)) {
            global ClipboardHistory_CapsLockC := []
        }
        return {Source: "array", Data: ClipboardHistory_CapsLockC}
    }
    return {Source: "array", Data: []}
}

; 根据显示索引获取数据库记录的ID（用于删除操作）
; 注意：此函数已废弃，现在使用GetClipboardDataForCurrentTab返回的IDs数组
; 保留此函数仅用于兼容性
GetDatabaseIDByDisplayIndex(DisplayIndex) {
    global ClipboardCurrentTab, ClipboardDB
    if (ClipboardCurrentTab != "CapsLockC" || !ClipboardDB || ClipboardDB = 0) {
        return 0
    }
    try {
        ; 使用GetClipboardDataForCurrentTab获取数据，包括IDs数组
        DataInfo := GetClipboardDataForCurrentTab()
        if (DataInfo.Source = "database" && DataInfo.HasProp("IDs") && IsObject(DataInfo.IDs)) {
            if (DisplayIndex > 0 && DisplayIndex <= DataInfo.IDs.Length) {
                return DataInfo.IDs[DisplayIndex]
            }
        }
    } catch as err {
    }
    return 0
}

; 清空所有剪贴板
ClearAllClipboard(*) {
    global ClipboardHistory_CtrlC, ClipboardHistory_CapsLockC, ClipboardCurrentTab
    global ClipboardListBox, ClipboardDB
    
    ; 确认对话框
    Result := MsgBox(GetText("confirm_clear"), GetText("confirm"), "YesNo Icon?")
    if (Result = "Yes") {
        ; 根据当前 Tab 清空对应的历史记录
        if (ClipboardCurrentTab = "CtrlC") {
            ; Ctrl+C 标签：清空数组
            ClipboardHistory_CtrlC := []
        } else {
            ; CapsLock+C 标签：清空数据库或数组
            if (ClipboardDB && ClipboardDB != 0) {
                try {
                    ; 从数据库清空
                    ClipboardDB.Exec("DELETE FROM ClipboardHistory")
                } catch as err {
                    ; 数据库清空失败，清空数组（兼容模式）
                    if (!IsSet(ClipboardHistory_CapsLockC) || !IsObject(ClipboardHistory_CapsLockC)) {
                        global ClipboardHistory_CapsLockC := []
                    } else {
                        ClipboardHistory_CapsLockC := []
                    }
                }
            } else {
                ; 数据库未初始化，清空数组
                if (!IsSet(ClipboardHistory_CapsLockC) || !IsObject(ClipboardHistory_CapsLockC)) {
                    global ClipboardHistory_CapsLockC := []
                } else {
                    ClipboardHistory_CapsLockC := []
                }
            }
        }
        ; 立即刷新列表和计数，确保界面即时更新
        RefreshClipboardList()
        ; 强制刷新UI，确保视觉更新
        try {
            global GuiID_ClipboardManager
            if (GuiID_ClipboardManager && IsObject(GuiID_ClipboardManager)) {
                ; 强制重绘窗口
                WinRedraw(GuiID_ClipboardManager.Hwnd)
            }
        } catch as err {
            ; 忽略重绘失败
        }
        ; 确保刷新完成后再显示提示
        Sleep(10)
        TrayTip(GetText("cleared"), GetText("tip"), "Iconi 1")
    }
}

; ListBox 选中变化事件处理函数（确保选中状态被正确记录）
OnClipboardListBoxChange(*) {
    global ClipboardListBox, LastSelectedIndex
    try {
        if (ClipboardListBox && IsObject(ClipboardListBox)) {
            ; 获取当前选中项的索引
            SelectedIndex := ClipboardListBox.Value
            ; 确保是整数类型
            if (Type(SelectedIndex) != "Integer") {
                if (Type(SelectedIndex) = "String" && SelectedIndex != "") {
                    try {
                        SelectedIndex := Integer(SelectedIndex)
                    } catch as err {
                        SelectedIndex := 0
                    }
                } else {
                    SelectedIndex := 0
                }
            }
            ; 保存最后选中的索引，用于刷新后恢复
            if (SelectedIndex > 0) {
                LastSelectedIndex := SelectedIndex
            }
        }
    } catch as err {
        ; 忽略错误
    }
}

; 获取 ListBox 选中项索引的辅助函数
GetSelectedIndex(ListBox) {
    if (!ListBox || !IsObject(ListBox)) {
        return 0
    }
    try {
        ; 方法1：直接获取Value属性
        SelectedIndex := ListBox.Value
        
        ; 确保 SelectedIndex 是数字类型
        if (Type(SelectedIndex) != "Integer") {
            if (Type(SelectedIndex) = "String" && SelectedIndex != "") {
                ; 尝试转换为整数
                try {
                    SelectedIndex := Integer(SelectedIndex)
                } catch as err {
                    SelectedIndex := 0
                }
            } else {
                SelectedIndex := 0
            }
        }
        
        ; 如果Value为0，尝试使用最后保存的选中索引
        if (SelectedIndex <= 0) {
            global LastSelectedIndex
            if (IsSet(LastSelectedIndex) && LastSelectedIndex > 0) {
                ; 验证保存的索引是否仍然有效
                try {
                    ListItems := ListBox.List
                    if (ListItems && LastSelectedIndex <= ListItems.Length) {
                        ; 恢复选中状态
                        ListBox.Value := LastSelectedIndex
                        SelectedIndex := LastSelectedIndex
                    }
                } catch as err {
                    ; 忽略错误
                }
            }
        }
        
        return SelectedIndex
    } catch as err {
        return 0
    }
}

; 复制选中项
CopySelectedItem(*) {
    global ClipboardHistory_CtrlC, ClipboardHistory_CapsLockC, ClipboardCurrentTab
    global ClipboardListBox, ClipboardListView, GuiID_ClipboardManager
    
    if (!GuiID_ClipboardManager) {
        return
    }
    
    ; 【新功能】根据当前Tab选择使用ListBox或ListView
    if (ClipboardCurrentTab = "CapsLockC") {
        ; CapsLockC标签使用ListView
        if (!ClipboardListView || !IsObject(ClipboardListView)) {
            try {
                ClipboardGUI := GuiFromHwnd(GuiID_ClipboardManager)
                if (ClipboardGUI) {
                    ClipboardListView := ClipboardGUI["ClipboardListView"]
                }
            } catch as err {
                return
            }
        }
        
        if (!ClipboardListView || !IsObject(ClipboardListView)) {
            return
        }
        
        ; 获取ListView中选中的行
        SelectedRow := ClipboardListView.GetNext()
        if (SelectedRow = 0) {
            TrayTip(FormatText("select_first", GetText("copy")), GetText("tip"), "Iconi 1")
            return
        }
        
        ; 从ListView获取选中行的标签（格式：阶段 X-第 Y 个）
        DisplayLabel := ClipboardListView.GetText(SelectedRow, 1)
        
        ; 解析SessionID和ItemIndex
        ; 格式：阶段 X-第 Y 个
        if (!RegExMatch(DisplayLabel, "阶段\s+(\d+)-第\s+(\d+)\s+个", &Match)) {
            TrayTip("无法解析选中项标签", GetText("error"), "Iconx 1")
            return
        }
        
        SessionID := Integer(Match[1])
        ItemIndex := Integer(Match[2])
        
        ; 从数据库查询完整内容
        global ClipboardDB
        if (ClipboardDB && ClipboardDB != 0) {
            try {
                ResultTable := ""
                SQL := "SELECT Content FROM ClipboardHistory WHERE SessionID = " . SessionID . " AND ItemIndex = " . ItemIndex . " LIMIT 1"
                if (ClipboardDB.GetTable(SQL, &ResultTable)) {
                    if (ResultTable && ResultTable.HasProp("Rows") && ResultTable.Rows.Length > 0) {
                        Row := ResultTable.Rows[1]
                        if (Row.Length >= 1 && Row[1] != "") {
                            Content := String(Row[1])
                            A_Clipboard := Content
                            TrayTip(GetText("copied"), GetText("tip"), "Iconi 1")
                            return
                        }
                    }
                }
                TrayTip("无法获取选中项内容", GetText("error"), "Iconx 1")
            } catch as e {
                TrayTip("复制失败: " . e.Message, GetText("error"), "Iconx 1")
            }
        } else {
            TrayTip("数据库未初始化", GetText("error"), "Iconx 1")
        }
        return
    }
    
    ; CtrlC标签使用ListBox
    ; 如果控件引用丢失，尝试重新获取
    if (!ClipboardListBox || !IsObject(ClipboardListBox)) {
        try {
            ClipboardGUI := GuiFromHwnd(GuiID_ClipboardManager)
            if (ClipboardGUI) {
                ClipboardListBox := ClipboardGUI["ClipboardListBox"]
            }
        } catch as err {
            return
        }
    }
    
    if (!ClipboardListBox || !IsObject(ClipboardListBox)) {
        return
    }
    
    try {
        ; 确保全局变量已初始化
        if (!IsSet(ClipboardHistory_CtrlC) || !IsObject(ClipboardHistory_CtrlC)) {
            global ClipboardHistory_CtrlC := []
        }
        if (!IsSet(ClipboardHistory_CapsLockC) || !IsObject(ClipboardHistory_CapsLockC)) {
            global ClipboardHistory_CapsLockC := []
        }
        if (!IsSet(ClipboardCurrentTab) || ClipboardCurrentTab = "") {
            global ClipboardCurrentTab := "CtrlC"
        }
        
        ; 获取当前标签页的数据
        DataInfo := GetClipboardDataForCurrentTab()
        CurrentHistory := DataInfo.Data
        
        ; 获取选中项的索引
        SelectedIndex := GetSelectedIndex(ClipboardListBox)
        
        ; 验证索引有效性
        if (SelectedIndex > 0 && SelectedIndex <= CurrentHistory.Length) {
            ItemData := CurrentHistory[SelectedIndex]
            ; 检查数据结构：如果是Map（数据库模式），使用Content；如果是字符串（数组模式），直接使用
            Content := ""
            if (IsObject(ItemData) && ItemData.Has("Content")) {
                Content := ItemData["Content"]
            } else if (Type(ItemData) = "String") {
                Content := ItemData
            }
            if (Content != "") {
                A_Clipboard := Content
                TrayTip(GetText("copied"), GetText("tip"), "Iconi 1")
            } else {
                TrayTip(FormatText("select_first", GetText("copy")), GetText("tip"), "Iconi 1")
            }
        } else {
            TrayTip(FormatText("select_first", GetText("copy")), GetText("tip"), "Iconi 1")
        }
    } catch as e {
        TrayTip(GetText("operation_failed") . ": " . e.Message, GetText("error"), "Iconx 1")
    }
}

; 删除选中项
DeleteSelectedItem(*) {
    global ClipboardHistory_CtrlC, ClipboardHistory_CapsLockC, ClipboardCurrentTab
    global ClipboardListBox, ClipboardListView, GuiID_ClipboardManager, ClipboardDB
    
    if (!GuiID_ClipboardManager) {
        return
    }
    
    ; 【新功能】根据当前Tab选择使用ListBox或ListView
    if (ClipboardCurrentTab = "CapsLockC") {
        ; CapsLockC标签使用ListView
        if (!ClipboardListView || !IsObject(ClipboardListView)) {
            try {
                ClipboardGUI := GuiFromHwnd(GuiID_ClipboardManager)
                if (ClipboardGUI) {
                    ClipboardListView := ClipboardGUI["ClipboardListView"]
                }
            } catch as err {
                return
            }
        }
        
        if (!ClipboardListView || !IsObject(ClipboardListView)) {
            return
        }
        
        ; 获取ListView中选中的行
        SelectedRow := ClipboardListView.GetNext()
        if (SelectedRow = 0) {
            TrayTip(FormatText("select_first", GetText("delete")), GetText("tip"), "Iconi 1")
            return
        }
        
        ; 从ListView获取选中行的标签（格式：阶段 X-第 Y 个）
        DisplayLabel := ClipboardListView.GetText(SelectedRow, 1)
        
        ; 解析SessionID和ItemIndex
        ; 格式：阶段 X-第 Y 个
        if (!RegExMatch(DisplayLabel, "阶段\s+(\d+)-第\s+(\d+)\s+个", &Match)) {
            TrayTip("无法解析选中项标签", GetText("error"), "Iconx 1")
            return
        }
        
        SessionID := Integer(Match[1])
        ItemIndex := Integer(Match[2])
        
        ; 删除该记录（只删除这一条，不是整个阶段）
        global ClipboardDB
        if (ClipboardDB && ClipboardDB != 0) {
            try {
                SQL := "DELETE FROM ClipboardHistory WHERE SessionID = " . SessionID . " AND ItemIndex = " . ItemIndex
                if (ClipboardDB.Exec(SQL)) {
                    global LastSelectedIndex
                    LastSelectedIndex := 0
                    RefreshClipboardList()
                    TrayTip(GetText("deleted"), GetText("tip"), "Iconi 1")
                } else {
                    TrayTip("删除失败: " . ClipboardDB.ErrorMsg, GetText("error"), "Iconx 1")
                }
            } catch as e {
                TrayTip("删除失败: " . e.Message, GetText("error"), "Iconx 1")
            }
        } else {
            TrayTip("数据库未初始化", GetText("error"), "Iconx 1")
        }
        return
    }
    
    ; CtrlC标签使用ListBox
    ; 如果控件引用丢失，尝试重新获取
    if (!ClipboardListBox || !IsObject(ClipboardListBox)) {
        try {
            ClipboardGUI := GuiFromHwnd(GuiID_ClipboardManager)
            if (ClipboardGUI) {
                ClipboardListBox := ClipboardGUI["ClipboardListBox"]
            }
        } catch as err {
            return
        }
    }
    
    if (!ClipboardListBox || !IsObject(ClipboardListBox)) {
        return
    }
    
    try {
        ; 确保全局变量已初始化
        if (!IsSet(ClipboardHistory_CtrlC) || !IsObject(ClipboardHistory_CtrlC)) {
            global ClipboardHistory_CtrlC := []
        }
        if (!IsSet(ClipboardHistory_CapsLockC) || !IsObject(ClipboardHistory_CapsLockC)) {
            global ClipboardHistory_CapsLockC := []
        }
        if (!IsSet(ClipboardCurrentTab) || ClipboardCurrentTab = "") {
            global ClipboardCurrentTab := "CtrlC"
        }
        
        ; 获取选中项的索引
        SelectedIndex := GetSelectedIndex(ClipboardListBox)
        
        if (SelectedIndex > 0) {
            if (ClipboardCurrentTab = "CtrlC") {
                ; Ctrl+C 标签：从数组删除
                if (IsSet(ClipboardHistory_CtrlC) && IsObject(ClipboardHistory_CtrlC) && SelectedIndex <= ClipboardHistory_CtrlC.Length) {
                    ClipboardHistory_CtrlC.RemoveAt(SelectedIndex)
                    global LastSelectedIndex
                    LastSelectedIndex := 0
                    RefreshClipboardList()
                    TrayTip(GetText("deleted"), GetText("tip"), "Iconi 1")
                } else {
                    TrayTip(FormatText("select_first", GetText("delete")), GetText("tip"), "Iconi 1")
                }
            } else {
                ; CapsLock+C 标签：从数据库删除
                global ClipboardDB
                if (ClipboardDB && ClipboardDB != 0) {
                    try {
                        ; 使用GetClipboardDataForCurrentTab获取数据，包括IDs数组
                        DataInfo := GetClipboardDataForCurrentTab()
                        if (DataInfo.Source = "database" && DataInfo.HasProp("IDs") && IsObject(DataInfo.IDs)) {
                            if (SelectedIndex > 0 && SelectedIndex <= DataInfo.IDs.Length) {
                                RecordID := DataInfo.IDs[SelectedIndex]
                                if (RecordID > 0) {
                                    SQL := "DELETE FROM ClipboardHistory WHERE ID = " . RecordID
                                    if (ClipboardDB.Exec(SQL)) {
                                        global LastSelectedIndex
                                        LastSelectedIndex := 0
                                        RefreshClipboardList()
                                        TrayTip(GetText("deleted"), GetText("tip"), "Iconi 1")
                                    } else {
                                        TrayTip("删除失败: " . ClipboardDB.ErrorMsg, GetText("error"), "Iconx 1")
                                    }
                                } else {
                                    TrayTip("无法获取记录ID", GetText("error"), "Iconx 1")
                                }
                            } else {
                                TrayTip(FormatText("select_first", GetText("delete")), GetText("tip"), "Iconi 1")
                            }
                        } else {
                            TrayTip("无法获取记录ID", GetText("error"), "Iconx 1")
                        }
                    } catch as e {
                        ; 数据库删除失败，尝试从数组删除（兼容模式）
                        if (IsSet(ClipboardHistory_CapsLockC) && IsObject(ClipboardHistory_CapsLockC) && SelectedIndex <= ClipboardHistory_CapsLockC.Length) {
                            ClipboardHistory_CapsLockC.RemoveAt(SelectedIndex)
                            global LastSelectedIndex
                            LastSelectedIndex := 0
                            RefreshClipboardList()
                            TrayTip(GetText("deleted"), GetText("tip"), "Iconi 1")
                        } else {
                            TrayTip("删除失败: " . e.Message, GetText("error"), "Iconx 1")
                        }
                    }
                } else {
                    ; 数据库未初始化，从数组删除（兼容模式）
                    if (IsSet(ClipboardHistory_CapsLockC) && IsObject(ClipboardHistory_CapsLockC) && SelectedIndex <= ClipboardHistory_CapsLockC.Length) {
                        ClipboardHistory_CapsLockC.RemoveAt(SelectedIndex)
                        global LastSelectedIndex
                        LastSelectedIndex := 0
                        RefreshClipboardList()
                        TrayTip(GetText("deleted"), GetText("tip"), "Iconi 1")
                    } else {
                        TrayTip(FormatText("select_first", GetText("delete")), GetText("tip"), "Iconi 1")
                    }
                }
            }
        } else {
            TrayTip(FormatText("select_first", GetText("delete")), GetText("tip"), "Iconi 1")
        }
    } catch as e {
        TrayTip(GetText("operation_failed") . ": " . e.Message, GetText("error"), "Iconx 1")
    }
}

; 粘贴选中项到 Cursor
PasteSelectedToCursor(*) {
    global ClipboardHistory_CtrlC, ClipboardHistory_CapsLockC, ClipboardCurrentTab
    global ClipboardListBox, CursorPath, AISleepTime, GuiID_ClipboardManager
    
    if (!GuiID_ClipboardManager) {
        return
    }
    
    ; 如果控件引用丢失，尝试重新获取
    if (!ClipboardListBox || !IsObject(ClipboardListBox)) {
        try {
            ClipboardGUI := GuiFromHwnd(GuiID_ClipboardManager)
            if (ClipboardGUI) {
                ClipboardListBox := ClipboardGUI["ClipboardListBox"]
            }
        } catch as err {
            return
        }
    }
    
    if (!ClipboardListBox || !IsObject(ClipboardListBox)) {
        return
    }
    
    try {
        ; 确保全局变量已初始化
        if (!IsSet(ClipboardHistory_CtrlC) || !IsObject(ClipboardHistory_CtrlC)) {
            global ClipboardHistory_CtrlC := []
        }
        if (!IsSet(ClipboardHistory_CapsLockC) || !IsObject(ClipboardHistory_CapsLockC)) {
            global ClipboardHistory_CapsLockC := []
        }
        if (!IsSet(ClipboardCurrentTab) || ClipboardCurrentTab = "") {
            global ClipboardCurrentTab := "CtrlC"
        }
        
        ; 获取当前标签页的数据
        DataInfo := GetClipboardDataForCurrentTab()
        CurrentHistory := DataInfo.Data
        
        ; 获取选中项的索引
        SelectedIndex := GetSelectedIndex(ClipboardListBox)
        
        Content := ""
        if (SelectedIndex > 0 && SelectedIndex <= CurrentHistory.Length) {
            ItemData := CurrentHistory[SelectedIndex]
            ; 检查数据结构：如果是Map（数据库模式），使用Content；如果是字符串（数组模式），直接使用
            if (IsObject(ItemData) && ItemData.Has("Content")) {
                Content := ItemData["Content"]
            } else if (Type(ItemData) = "String") {
                Content := ItemData
            }
        }
        
        if (Content != "" && StrLen(Content) > 0) {
            ; 激活 Cursor 窗口
            try {
                if WinExist("ahk_exe Cursor.exe") {
                    WinActivate("ahk_exe Cursor.exe")
                    WinWaitActive("ahk_exe Cursor.exe", , 1)
                    Sleep(200)
                    
                    if !WinActive("ahk_exe Cursor.exe") {
                        WinActivate("ahk_exe Cursor.exe")
                        Sleep(200)
                    }
                    
                    Send("{Esc}")
                    Sleep(100)
                    Send("^l")
                    Sleep(400)
                    
                    if !WinActive("ahk_exe Cursor.exe") {
                        WinActivate("ahk_exe Cursor.exe")
                        Sleep(200)
                    }
                    
                    A_Clipboard := Content
                    Sleep(100)
                    Send("^v")
                    Sleep(200)
                    
                    TrayTip(GetText("paste_success"), GetText("tip"), "Iconi 1")
                } else {
                    if (CursorPath != "" && FileExist(CursorPath)) {
                        Run(CursorPath)
                        Sleep(AISleepTime)
                        A_Clipboard := Content
                        Sleep(100)
                        Send("^l")
                        Sleep(400)
                        Send("^v")
                        Sleep(200)
                        TrayTip(GetText("paste_success"), GetText("tip"), "Iconi 1")
                    } else {
                        TrayTip(GetText("cursor_not_running"), GetText("error"), "Iconx 2")
                    }
                }
            } catch as e {
                MsgBox(GetText("paste_failed") . ": " . e.Message)
            }
        } else {
            TrayTip(FormatText("select_first", GetText("paste")), GetText("tip"), "Iconi 1")
        }
    } catch as err {
        TrayTip(GetText("operation_failed"), GetText("error"), "Iconx 1")
    }
}
