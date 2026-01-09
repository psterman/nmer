; ======================================================================================================================
; 剪贴板历史面板 - 简洁列表视图
; 版本: 1.0.0
; 功能: 
;   - 显示所有复制过的数据，按时间倒序排列
;   - 支持搜索过滤
;   - 双击复制到剪贴板
;   - 暗黑模式界面
; ======================================================================================================================

#Requires AutoHotkey v2.0
#Include ClipboardFTS5.ahk
#Include ..\lib\ImagePut.ahk
#Include ..\lib\Gdip_All.ahk
#Include ..\lib\WinClip.ahk
#Include ..\lib\OCR.ahk

; ===================== 全局变量 =====================
global GuiID_ClipboardHistory := 0
global HistoryListView := 0
global HistorySearchEdit := 0
global HistoryStatusBarText := 0  ; 状态栏文本控件
global HistoryBottomArea := 0  ; 底部按钮区域背景
global HistoryIsVisible := false
global HistoryDisplayCache := []
global HistoryTagButtons := Map()  ; 存储标签按钮对象
global HistorySelectedTag := ""  ; 当前选中的标签（空字符串表示全部）
global ColorSummaryGUI := 0  ; 颜色汇总面板GUI
global ColorSummaryIsVisible := false  ; 颜色汇总面板是否可见
global HistorySearchTimer := 0  ; 搜索防抖定时器
global HistoryImagePreviewGUI := 0  ; 图片预览窗口
global HistoryImagePreviewIsVisible := false  ; 图片预览窗口是否可见
global HistoryImagePreviewTimer := 0  ; 图片预览防抖定时器
global HistoryImagePreviewCurrentPath := ""  ; 当前预览的图片路径
global HistoryGdiplusToken := 0  ; GDI+ Token（用于初始化 GDI+）
global StackClipboardItems := []  ; 叠加复制的内容列表（存储数据库ID）
global HistoryImageList := 0  ; 自定义 ImageList（用于显示精准软件图标）
global HistoryIconCache := Map()  ; 图标缓存（避免重复提取）
global HistoryCurrentLimit := 100  ; 当前加载的数据量限制
global HistoryHasMoreData := false  ; 是否还有更多数据
global HistoryResultLimitDropdown := 0  ; 结果数量限制下拉菜单
global HistoryEverythingLimit := 50  ; Everything 搜索的结果数量限制（默认50）

; 暗黑模式配色（Cursor色系）
HistoryColors := {
    Background: "1e1e1e",
    Border: "3c3c3c",
    Text: "cccccc",
    TextDim: "888888",
    InputBg: "2d2d30",
    ListBg: "252526",
    ListItemHover: "37373d",
    SearchBorder: "007acc",  ; Cursor蓝色
    TagBg: "2d2d30",  ; 侧边栏颜色（未选中状态，与 SearchCenter 一致）
    TagBgActive: "e67e22",  ; 橙色（激活状态，与 SearchCenter 一致）
    TagText: "cccccc",
    TagTextActive: "ffffff",
    TagBorder: "3c3c3c",
    TagBorderActive: "e67e22"  ; 橙色
}

; ===================== 显示/隐藏面板 =====================
ShowClipboardHistoryPanel() {
    global GuiID_ClipboardHistory, HistoryIsVisible, HistorySearchEdit, ClipboardFTS5DB
    
    if (HistoryIsVisible && GuiID_ClipboardHistory != 0) {
        ; 如果已显示，聚焦到搜索框并刷新数据
        try {
            ControlFocus(HistorySearchEdit)
            ; 重置限制并强制刷新数据
            HistoryCurrentLimit := 100
            RefreshHistoryData()
        }
        return
    }
    
    ; 检查数据库连接
    if (!ClipboardFTS5DB || ClipboardFTS5DB = 0) {
        MsgBox("数据库未连接！`n请检查数据库初始化。", "错误", "IconX")
        return
    }
    
    ; 创建 GUI
    CreateHistoryPanelGUI()
    
    ; 重置限制
    HistoryCurrentLimit := 100
    
    ; 加载数据（确保在显示前加载）
    RefreshHistoryData()
    
    ; 显示 GUI（增加宽度以容纳所有列和图标）
    GuiID_ClipboardHistory.Show("w1200 h700")
    HistoryIsVisible := true
    
    ; 自动聚焦搜索框
    SetTimer(() => ControlFocus(HistorySearchEdit), -100)
    
    ; 延迟再次刷新，确保数据最新（处理可能的时序问题）
    SetTimer(() => RefreshHistoryData(), -200)
}

HideClipboardHistoryPanel() {
    global GuiID_ClipboardHistory, HistoryIsVisible
    
    ; 隐藏颜色汇总面板
    HideColorSummaryPanel()
    
    ; 隐藏图片预览窗口
    HideHistoryImagePreview()
    
    if (GuiID_ClipboardHistory != 0) {
        GuiID_ClipboardHistory.Hide()
        HistoryIsVisible := false
    }
    
    ; 注意：不在这里销毁 ImageList，因为窗口可能再次显示
    ; ImageList 会在程序退出时自动清理
}

ToggleClipboardHistoryPanel() {
    global HistoryIsVisible
    
    if (HistoryIsVisible) {
        HideClipboardHistoryPanel()
    } else {
        ShowClipboardHistoryPanel()
    }
}

; ===================== 创建 GUI =====================
CreateHistoryPanelGUI() {
    global GuiID_ClipboardHistory, HistoryListView, HistorySearchEdit, HistoryStatusBarText, HistoryBottomArea
    global HistoryColors, HistoryTagButtons, HistorySelectedTag
    
    ; 如果已存在，先销毁
    if (GuiID_ClipboardHistory != 0) {
        try {
            GuiID_ClipboardHistory.Destroy()
        }
    }
    
    ; 创建 GUI（可调整大小，置顶）
    GuiID_ClipboardHistory := Gui("+Resize +AlwaysOnTop", "记录")  ; [需求4] 窗口名称改为"记录"
    GuiID_ClipboardHistory.BackColor := HistoryColors.Background
    GuiID_ClipboardHistory.SetFont("s10 c" . HistoryColors.Text, "Segoe UI")
    
    ; 窗口事件
    GuiID_ClipboardHistory.OnEvent("Size", OnHistoryPanelSize)
    GuiID_ClipboardHistory.OnEvent("Close", OnHistoryPanelClose)
    
    ; ========== 顶部搜索框区域 ==========
    SearchBoxY := 10
    SearchBoxHeight := 30
    
    ; ========== 结果数量限制下拉菜单（搜索框左侧）==========
    DropdownX := 10
    DropdownY := SearchBoxY
    DropdownWidth := 80
    DropdownHeight := SearchBoxHeight
    
    ; 创建下拉菜单选项（10, 20, 30, 50, 100, 200, 500）- 直接内联数组
    ; R7 表示显示 7 行，确保所有选项都可见
    DropdownDefaultIndex := 4  ; 默认选择50（索引从1开始，50是第4个选项)

    HistoryResultLimitDropdown := GuiID_ClipboardHistory.Add("DropDownList",
        "x" . DropdownX . " y" . DropdownY .
        " w" . DropdownWidth . " h" . DropdownHeight .
        " R7" .  ; 显示 7 行，确保所有选项可见
        " Background" . HistoryColors.InputBg .
        " c" . HistoryColors.Text .
        " Choose" . DropdownDefaultIndex .
        " vHistoryResultLimitDropdown",
        ["10", "20", "30", "50", "100", "200", "500"])
    
    HistoryResultLimitDropdown.SetFont("s10", "Segoe UI")
    HistoryResultLimitDropdown.OnEvent("Change", OnHistoryResultLimitChange)
    
    ; ========== 搜索框（下拉菜单右侧）==========
    SearchBoxX := DropdownX + DropdownWidth + 10  ; 下拉菜单右侧，间距10
    SearchBoxWidth := 1180 - DropdownWidth - 10  ; 总宽度减去下拉菜单宽度和间距
    
    HistorySearchEdit := GuiID_ClipboardHistory.Add("Edit", 
        "x" . SearchBoxX . " y" . SearchBoxY . 
        " w" . SearchBoxWidth . " h" . SearchBoxHeight . 
        " Background" . HistoryColors.InputBg . 
        " c" . HistoryColors.Text . 
        " -VScroll -HScroll -Border" . 
        " vHistorySearchEdit", "")
    
    HistorySearchEdit.SetFont("s11", "Segoe UI")
    HistorySearchEdit.OnEvent("Change", OnHistorySearchChange)
    
    ; 初始化 Everything 搜索限制值
    HistoryEverythingLimit := 50
    
    ; 移除 Edit 控件的默认边框样式
    SearchEditHwnd := HistorySearchEdit.Hwnd
    try {
        CurrentExStyle := DllCall("GetWindowLongPtr", "Ptr", SearchEditHwnd, "Int", -20, "Ptr")
        NewExStyle := CurrentExStyle & ~0x00000200  ; 移除 WS_EX_CLIENTEDGE
        DllCall("SetWindowLongPtr", "Ptr", SearchEditHwnd, "Int", -20, "Ptr", NewExStyle, "Ptr")
    }
    
    ; ========== 标签过滤区域 ==========
    TagAreaY := 50
    TagAreaHeight := 35
    TagSpacing := 8
    TagButtonHeight := 28
    TagButtonWidth := 80  ; 标签按钮宽度
    TagStartX := 10
    
    ; 标签列表：文本、图片、链接、颜色、代码、文件夹、截图、CapsLock+C
    TagLabels := ["文本", "图片", "链接", "颜色", "代码", "文件夹", "截图", "CapsLock+C"]
    TagTypes := ["Text", "Image", "Link", "Color", "Code", "Folder", "Screenshot", "CapsLockC"]
    
    ; 清空标签按钮映射
    HistoryTagButtons := Map()
    HistorySelectedTag := ""  ; 默认不选中任何标签（显示全部）
    
    ; 创建标签按钮
    Loop TagLabels.Length {
        tagIndex := A_Index
        tagLabel := TagLabels[tagIndex]
        tagType := TagTypes[tagIndex]
        
        ; 计算按钮X位置
        tagX := TagStartX + (tagIndex - 1) * (TagButtonWidth + TagSpacing)
        
        ; 创建标签按钮（使用 Text 控件，与 SearchCenter 风格一致）
        ; 根据是否选中设置背景色和文字颜色
        IsSelected := (HistorySelectedTag = tagType)
        BgColor := IsSelected ? HistoryColors.TagBgActive : HistoryColors.TagBg
        TextColor := IsSelected ? HistoryColors.TagTextActive : HistoryColors.TagText
        
        tagButton := GuiID_ClipboardHistory.Add("Text", 
            "x" . tagX . " y" . TagAreaY . 
            " w" . TagButtonWidth . " h" . TagButtonHeight . 
            " Center 0x200 c" . TextColor . 
            " Background" . BgColor . 
            " vHistoryTag_" . tagType, tagLabel)
        
        tagButton.SetFont("s10 Bold", "Segoe UI")
        
        ; 绑定点击事件
        tagButton.OnEvent("Click", OnHistoryTagClick.Bind(tagType))
        
        ; 添加悬停效果（如果 HoverBtnWithAnimation 函数可用）
        try {
            hoverFunc := HoverBtnWithAnimation
            if (IsSet(hoverFunc)) {
                HoverBtnWithAnimation(tagButton, BgColor, HistoryColors.TagBgActive)
            }
        } catch {
            ; 如果函数不可用，忽略错误
        }
        
        ; 存储按钮引用
        HistoryTagButtons[tagType] := tagButton
    }
    
    ; 初始化标签按钮样式
    UpdateHistoryTagButtons()
    
    ; ========== ListView ==========
    ListViewX := 10
    ListViewY := 90  ; 调整Y位置，为标签区域留出空间
    ListViewWidth := 1180  ; 增加宽度以匹配窗口
    ; 调整高度：窗口高度(700) - ListView起始Y(90) - 底部按钮区域(70) - 状态栏(20) = 520
    ListViewHeight := 520  ; 移除加载更多按钮后的空间
    
    HistoryListView := GuiID_ClipboardHistory.Add("ListView",
        "x" . ListViewX . " y" . ListViewY .
        " w" . ListViewWidth . " h" . ListViewHeight .
        " Background" . HistoryColors.ListBg .
        " c" . HistoryColors.Text .
        " +ReadOnly +Multi +Report" .
        " vHistoryListView",
        ["序号", "内容预览", "来源应用", "文件位置", "类型", "文件后缀", "文件大小", "最后复制", "复制次数", "字符数"])
    
    HistoryListView.SetFont("s9", "Consolas")
    
    ; 创建自定义 ImageList 用于显示精准软件图标（参考剪贴板管理的实现）
    CreateHistoryImageList(HistoryListView)
    
    ; 设置列宽（注意：图标列通过 ImageList 和 IconN 选项显示在第一列前，不占用列索引）
    ; 图标会自动显示在第一列（序号列）的左侧，宽度约为24像素
    HistoryListView.ModifyCol(1, 50)   ; 序号（包含图标空间）
    HistoryListView.ModifyCol(2, 250)  ; 内容预览（增加宽度以显示更多内容）
    HistoryListView.ModifyCol(3, 100)   ; 来源应用
    HistoryListView.ModifyCol(4, 180)  ; 文件位置（增加宽度）
    HistoryListView.ModifyCol(5, 60)   ; 类型
    HistoryListView.ModifyCol(6, 70)   ; 文件后缀
    HistoryListView.ModifyCol(7, 80)   ; 文件大小
    HistoryListView.ModifyCol(8, 130)  ; 最后复制时间（增加宽度）
    HistoryListView.ModifyCol(9, 70)   ; 复制次数
    HistoryListView.ModifyCol(10, 70)  ; 字符数
    
    ; ListView 事件
    HistoryListView.OnEvent("ItemSelect", OnHistoryItemSelect)
    HistoryListView.OnEvent("ItemFocus", OnHistoryItemSelect)  ; 添加焦点事件，确保点击时能触发
    HistoryListView.OnEvent("DoubleClick", OnHistoryItemDoubleClick)
    HistoryListView.OnEvent("Click", OnHistoryItemClick)  ; 添加点击事件，确保能触发预览
    HistoryListView.OnEvent("ContextMenu", OnHistoryListViewContextMenu)  ; 右键菜单
    HistoryListView.OnEvent("ColClick", OnHistoryColumnClick)  ; 列点击事件（用于排序）
    
    ; ========== 底部按钮区域（自适应布局）==========
    ; 使用全局变量存储按钮引用，以便在窗口大小改变时调整位置
    global HistoryCopyBtn, HistoryDeleteBtn, HistoryPasteBtn, HistoryClearAllBtn, HistoryExportBtn, HistoryImportBtn
    
    ; 计算底部区域位置
    BottomAreaHeight := 70
    StatusBarHeight := 20
    ListViewHeight := 520  ; 初始高度
    bottomAreaY := ListViewY + ListViewHeight
    
    ; 底部区域高度
    ButtonHeight := 30
    ButtonWidth := 100
    ButtonSpacing := 10
    ButtonPadding := 10  ; 左右边距
    
    ; 创建底部背景区域（自适应宽度）
    BottomArea := GuiID_ClipboardHistory.Add("Text", 
        "x0 y" . bottomAreaY . " w1200 h" . BottomAreaHeight . 
        " Background" . HistoryColors.Background . 
        " vHistoryBottomArea", "")
    
    ; 按钮Y位置（相对于底部区域）
    ButtonY := bottomAreaY + 10
    
    ; 计算按钮总宽度和起始X位置（居中或左对齐）
    TotalButtonsWidth := (ButtonWidth * 6) + (ButtonSpacing * 5) + (ButtonPadding * 2)
    StartX := ButtonPadding
    
    ; 复制选中按钮
    HistoryCopyBtn := GuiID_ClipboardHistory.Add("Text", 
        "x" . StartX . " y" . ButtonY . " w" . ButtonWidth . " h" . ButtonHeight . 
        " Center 0x200 c" . HistoryColors.TagText . 
        " Background" . HistoryColors.TagBg . 
        " vHistoryCopyBtn", "复制选中")
    HistoryCopyBtn.SetFont("s10", "Segoe UI")
    HistoryCopyBtn.OnEvent("Click", HistoryCopySelected)
    
    ; 删除选中按钮
    HistoryDeleteBtn := GuiID_ClipboardHistory.Add("Text", 
        "x" . (StartX + ButtonWidth + ButtonSpacing) . " y" . ButtonY . 
        " w" . ButtonWidth . " h" . ButtonHeight . 
        " Center 0x200 c" . HistoryColors.TagText . 
        " Background" . HistoryColors.TagBg . 
        " vHistoryDeleteBtn", "删除选中")
    HistoryDeleteBtn.SetFont("s10", "Segoe UI")
    HistoryDeleteBtn.OnEvent("Click", HistoryDeleteSelected)
    
    ; 粘贴到 Cursor 按钮
    HistoryPasteBtn := GuiID_ClipboardHistory.Add("Text", 
        "x" . (StartX + (ButtonWidth + ButtonSpacing) * 2) . " y" . ButtonY . 
        " w" . (ButtonWidth + 20) . " h" . ButtonHeight . 
        " Center 0x200 cFFFFFF Background" . HistoryColors.TagBgActive . 
        " vHistoryPasteBtn", "粘贴到 Cursor")
    HistoryPasteBtn.SetFont("s10", "Segoe UI")
    HistoryPasteBtn.OnEvent("Click", HistoryPasteToCursor)
    
    ; 清空全部按钮
    HistoryClearAllBtn := GuiID_ClipboardHistory.Add("Text", 
        "x" . (StartX + (ButtonWidth + ButtonSpacing) * 3 + 20) . " y" . ButtonY . 
        " w" . ButtonWidth . " h" . ButtonHeight . 
        " Center 0x200 c" . HistoryColors.TagText . 
        " Background" . HistoryColors.TagBg . 
        " vHistoryClearAllBtn", "清空全部")
    HistoryClearAllBtn.SetFont("s10", "Segoe UI")
    HistoryClearAllBtn.OnEvent("Click", HistoryClearAll)
    
    ; 导出剪贴板按钮
    HistoryExportBtn := GuiID_ClipboardHistory.Add("Text", 
        "x" . (StartX + (ButtonWidth + ButtonSpacing) * 4 + 20) . " y" . ButtonY . 
        " w" . ButtonWidth . " h" . ButtonHeight . 
        " Center 0x200 c" . HistoryColors.TagText . 
        " Background" . HistoryColors.TagBg . 
        " vHistoryExportBtn", "导出")
    HistoryExportBtn.SetFont("s10", "Segoe UI")
    HistoryExportBtn.OnEvent("Click", HistoryExportClipboard)
    
    ; 导入剪贴板按钮
    HistoryImportBtn := GuiID_ClipboardHistory.Add("Text", 
        "x" . (StartX + (ButtonWidth + ButtonSpacing) * 5 + 20) . " y" . ButtonY . 
        " w" . ButtonWidth . " h" . ButtonHeight . 
        " Center 0x200 c" . HistoryColors.TagText . 
        " Background" . HistoryColors.TagBg . 
        " vHistoryImportBtn", "导入")
    HistoryImportBtn.SetFont("s10", "Segoe UI")
    HistoryImportBtn.OnEvent("Click", HistoryImportClipboard)
    
    ; ========== 底部状态栏 ==========
    StatusBarY := bottomAreaY + BottomAreaHeight
    HistoryStatusBarText := GuiID_ClipboardHistory.Add("Text", 
        "x10 y" . StatusBarY . " w1180 h20 c" . HistoryColors.TextDim . 
        " vHistoryStatusBarText", 
        "提示: 双击项目复制到剪贴板 | 使用搜索框过滤内容 | 点击标签分类筛选 | 右键菜单操作 | 点击序号列按图标排序")
    HistoryStatusBarText.SetFont("s8", "Segoe UI")
}

; ===================== 创建自定义 ImageList =====================
CreateHistoryImageList(ListViewCtrl) {
    global HistoryImageList
    
    ; 如果已经创建，直接返回
    if (HistoryImageList != 0) {
        return
    }
    
    ; 创建 ImageList：16x16 图标，支持 32 位色
    ; IL_Create(初始容量, 增长量, 标志) - 标志 0 表示 32 位色
    HistoryImageList := IL_Create(10, 10, 0)  ; 初始容量 10，增长 10
    
    if (HistoryImageList != 0) {
        ; 设置 ListView 的 ImageList
        try {
            LV_Hwnd := ListViewCtrl.Hwnd
            ; LVM_SETIMAGELIST = 0x1003, LVSIL_SMALL = 0x0001
            SendMessage(0x1003, 0x0001, HistoryImageList, LV_Hwnd)
        } catch as err {
            ; 如果设置失败，清理 ImageList
            try {
                IL_Destroy(HistoryImageList)
            } catch {
            }
            HistoryImageList := 0
        }
    }
}

; ===================== 获取文件大小（使用 FileGetSize）=====================
GetFileSize(filePath) {
    ; 如果路径为空或不是文件路径，返回空字符串
    if (filePath = "" || !filePath) {
        return "-"
    }
    
    ; 清理路径中的转义字符
    path := StrReplace(filePath, "\\\\", "\")
    path := StrReplace(path, "\\", "\")
    
    ; 检查是否是文件路径
    if (!InStr(path, "\") && !InStr(path, "/")) {
        return "-"  ; 不是文件路径
    }
    
    ; 检查文件是否存在
    if (!FileExist(path)) {
        return "-"
    }
    
    ; 使用 FileGetSize 获取文件大小
    try {
        fileSize := FileGetSize(path)
        if (fileSize >= 0) {
            return FormatFileSize(fileSize)
        }
    } catch {
        return "-"
    }
    
    return "-"
}

; ===================== 格式化文件大小 =====================
FormatFileSize(bytes) {
    if (bytes < 1024) {
        return bytes . " B"
    } else if (bytes < 1024 * 1024) {
        return Round(bytes / 1024, 1) . " KB"
    } else if (bytes < 1024 * 1024 * 1024) {
        return Round(bytes / (1024 * 1024), 1) . " MB"
    } else {
        return Round(bytes / (1024 * 1024 * 1024), 2) . " GB"
    }
}

; ===================== 获取文件后缀名 =====================
GetFileExtension(filePath) {
    ; 如果路径为空或不是文件路径，返回空字符串
    if (filePath = "" || !filePath) {
        return "-"
    }
    
    ; 清理路径中的转义字符
    path := StrReplace(filePath, "\\\\", "\")
    path := StrReplace(path, "\\", "\")
    
    ; 检查是否是文件路径
    if (!InStr(path, "\") && !InStr(path, "/")) {
        return "-"  ; 不是文件路径
    }
    
    ; 提取文件扩展名
    try {
        SplitPath(path, , , &ext)
        if (ext != "") {
            return StrLower(ext)
        }
    } catch {
        return "-"
    }
    
    return "-"
}

; ===================== 获取最佳图标路径 =====================
getBestIconPath(item) {
    ; 支持 Map 和对象两种格式
    content := item.Has("Content") ? item["Content"] : (item.HasProp("Content") ? item.Content : "")
    dataType := item.Has("DataType") ? item["DataType"] : (item.HasProp("DataType") ? item.DataType : "")
    imagePath := item.Has("ImagePath") ? item["ImagePath"] : (item.HasProp("ImagePath") ? item.ImagePath : "")
    sourcePath := item.Has("SourcePath") ? item["SourcePath"] : (item.HasProp("SourcePath") ? item.SourcePath : "")
    
    ; 清理路径中的转义字符
    if (content != "") {
        content := StrReplace(content, "\\\\", "\")
        content := StrReplace(content, "\\", "\")
    }
    if (imagePath != "") {
        imagePath := StrReplace(imagePath, "\\\\", "\")
        imagePath := StrReplace(imagePath, "\\", "\")
    }
    
    ; 1. 图片类型：优先使用 ImagePath，然后是 Content（如果是图片路径）
    if (dataType = "Image") {
        if (imagePath != "" && FileExist(imagePath))
            return imagePath
        ; 检查 Content 是否是图片文件路径
        if (content != "" && (InStr(content, "\") || InStr(content, "/"))) {
            if (FileExist(content)) {
                ; 验证是否是图片文件
                SplitPath(content, , , &ext)
                ext := StrLower(ext)
                if (ext = "png" || ext = "jpg" || ext = "jpeg" || ext = "gif" || 
                    ext = "bmp" || ext = "webp" || ext = "tiff" || ext = "ico" || ext = "svg")
                    return content
            }
        }
        return ".png"
    }
    
    ; 2. 链接类型
    if (dataType = "Link") {
        return ".url"
    }
    
    ; 3. 颜色类型
    if (dataType = "Color") {
        return "shell32.dll,245" ; 借用系统的调色板图标
    }
    
    ; 4. 代码类型和其他文本类型：优先从 Content 中提取信息
    ; 4.1 检查 Content 是否是文件路径
    if (content != "" && (InStr(content, "\") || InStr(content, "/"))) {
        if (FileExist(content)) {
            ; Content 是真实文件路径，直接返回
            return content
        }
        ; 即使文件不存在，也尝试提取扩展名
        SplitPath(content, , , &ext)
        if (ext != "")
            return "." . ext
    }
    
    ; 4.2 检查 Content 是否包含文件扩展名模式（如 "test.js" 或 "function.js"）
    if (content != "") {
        ; 尝试匹配常见的文件扩展名模式
        if (RegExMatch(content, "i)\.([a-z]{2,5})(\s|$|`r|`n)", &match)) {
            ext := match[1]
            ; 验证是否是常见的文件扩展名
            commonExts := ["js", "ts", "py", "java", "cpp", "c", "h", "cs", "php", 
                          "rb", "go", "rs", "swift", "kt", "scala", "sh", "bat",
                          "html", "css", "xml", "json", "yaml", "yml", "md", "txt",
                          "sql", "r", "m", "pl", "lua", "vim", "conf", "ini", "cfg"]
            ; 检查扩展名是否在常见扩展名列表中
            for _, commonExt in commonExts {
                if (ext = commonExt) {
                    return "." . ext
                }
            }
        }
    }
    
    ; 5. 代码类型：尝试从 Content 中提取扩展名（更宽松的匹配）
    if (dataType = "Code") {
        ; 如果 Content 包含代码文件扩展名提示，提取它
        if (content != "") {
            ; 匹配类似 "// file.js" 或 "# file.py" 的模式
            if (RegExMatch(content, "i)(file|filename|path)[:\s]+[^\s]+\.([a-z]{2,5})", &match)) {
                ext := match[2]
                return "." . ext
            }
        }
        return ".txt"
    }
    
    ; 6. 最终兜底：使用文本图标
    return ".txt"
}

; ===================== 获取文件图标索引（使用自定义 ImageList）=====================
GetFileIconIndex(filePathOrExt, rowData := "") {
    global HistoryImageList, HistoryIconCache
    
    ; 如果 ImageList 未创建，返回 0
    if (!HistoryImageList || HistoryImageList = 0) {
        return 0
    }
    
    ; 优先使用 SourcePath（应用程序路径）来提取精准图标
    actualPath := ""
    if (IsObject(rowData)) {
        ; 优先使用 SourcePath（应用程序路径）
        if (rowData.Has("SourcePath") && rowData["SourcePath"] != "" && rowData["SourcePath"] != "\\") {
            sourcePath := rowData["SourcePath"]
            sourcePath := StrReplace(sourcePath, "\\\\", "\")
            sourcePath := StrReplace(sourcePath, "\\", "\")
            if (FileExist(sourcePath)) {
                actualPath := sourcePath
            }
        }
        
        ; 如果 SourcePath 不可用，尝试使用 ImagePath（图片路径）
        if (actualPath = "" && rowData.Has("ImagePath") && rowData["ImagePath"] != "") {
            imagePath := rowData["ImagePath"]
            imagePath := StrReplace(imagePath, "\\\\", "\")
            imagePath := StrReplace(imagePath, "\\", "\")
            if (FileExist(imagePath)) {
                actualPath := imagePath
            }
        }
        
        ; 如果 ImagePath 也不可用，尝试使用 Content（如果是文件路径）
        if (actualPath = "" && rowData.Has("Content") && rowData["Content"] != "") {
            content := rowData["Content"]
            content := StrReplace(content, "\\\\", "\")
            content := StrReplace(content, "\\", "\")
            if ((InStr(content, "\") || InStr(content, "/")) && FileExist(content)) {
                actualPath := content
            }
        }
    }
    
    ; 如果 actualPath 为空，使用传入的 filePathOrExt
    if (actualPath = "") {
        actualPath := filePathOrExt
    }
    
    ; 清理路径
    actualPath := StrReplace(actualPath, "\\\\", "\")
    actualPath := StrReplace(actualPath, "\\", "\")
    
    ; 如果路径为空或不是文件路径，返回 0
    if (actualPath = "" || (!InStr(actualPath, "\") && !InStr(actualPath, "/"))) {
        return 0
    }
    
    ; 检查文件是否存在
    if (!FileExist(actualPath)) {
        return 0
    }
    
    ; 检查缓存
    if (HistoryIconCache.Has(actualPath)) {
        return HistoryIconCache[actualPath]
    }
    
    ; 使用 IL_Add 从文件路径提取图标（参考剪贴板管理的实现）
    try {
        ; IL_Add(ImageList, 文件路径, 图标索引) - 图标索引 0 表示使用默认图标
        IconIndex := IL_Add(HistoryImageList, actualPath, 0)
        if (IconIndex > 0) {
            ; 缓存图标索引
            HistoryIconCache[actualPath] := IconIndex
            return IconIndex
        } else {
            ; 提取失败，返回 0
            return 0
        }
    } catch as err {
        ; 提取异常，返回 0
        return 0
    }
}

; ===================== 加载数据 =====================
RefreshHistoryData(keyword := "", offset := 0, limit := 0) {
    global HistoryListView, HistoryDisplayCache, ClipboardFTS5DB, HistorySelectedTag
    global HistoryCurrentLimit, HistoryHasMoreData
    
    ; 如果未指定 limit，使用当前限制
    if (limit = 0) {
        limit := HistoryCurrentLimit
    }
    
    ; 如果 ListView 不存在，但面板可能正在创建，不返回（允许后续创建）
    ; 如果数据库未连接，记录错误但不中断
    if (!ClipboardFTS5DB || ClipboardFTS5DB = 0) {
        ; 尝试重新初始化数据库
        if (InitClipboardFTS5DB()) {
            ; 重新初始化成功，继续执行
        } else {
            ; 如果 ListView 已存在，显示错误信息
            if (HistoryListView) {
                HistoryListView.Delete()
                HistoryListView.Add(, "数据库未连接", "请检查数据库初始化", "-", "-", "-", "-", "-", "-")
            }
            return
        }
    }
    
    ; 如果 ListView 不存在，可能是 GUI 还未创建，直接返回
    if (!HistoryListView) {
        return
    }
    
    ; 从数据库加载数据
    results := []
    
    try {
        if (ClipboardFTS5DB && ClipboardFTS5DB != 0) {
            ; 先检查字段是否存在，动态构建查询
            SQL := "PRAGMA table_info(ClipMain)"
            tableInfo := ""
            hasLastCopyTime := false
            hasCopyCount := false
            hasSourcePath := false
            hasIconPath := false
            
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
                        if (columnName = "SourcePath") {
                            hasSourcePath := true
                        }
                        if (columnName = "IconPath") {
                            hasIconPath := true
                        }
                    }
                }
            }
            
            ; 根据字段存在情况构建查询
            selectFields := "ID, Content, SourceApp"
            if (hasSourcePath) {
                selectFields .= ", SourcePath"
            } else {
                selectFields .= ", '' AS SourcePath"
            }
            if (hasIconPath) {
                selectFields .= ", IconPath"
            } else {
                selectFields .= ", '' AS IconPath"
            }
            selectFields .= ", DataType, CharCount, Timestamp, ImagePath"
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
            
            orderByField := hasLastCopyTime ? "LastCopyTime" : "Timestamp"
            
            ; 检查 FTS5 虚拟表是否存在
            SQL := "SELECT name FROM sqlite_master WHERE type='table' AND name='ClipboardHistory'"
            table := ""
            hasFTS5Table := false
            if (ClipboardFTS5DB.GetTable(SQL, &table)) {
                if (table.HasRows && table.Rows.Length > 0) {
                    hasFTS5Table := true
                }
            }
            
            ; 构建WHERE条件
            ; 支持全域搜索：当 HistorySelectedTag 为空时，不添加 DataType 过滤，可以搜索所有类型
            whereConditions := []
            
            ; 添加关键词搜索条件（优先使用 FTS5 MATCH 语法）
            ; 关键词搜索不受标签限制，可以跨所有 DataType 进行搜索
            ; 参考 SearchCenter 的实现，确保关键词经过 Trim 处理
            keyword := Trim(keyword)
            if (keyword != "") {
                ; 转义关键词（用于 LIKE 查询）
                escapedKeyword := StrReplace(keyword, "'", "''")
                escapedKeyword := StrReplace(escapedKeyword, "\", "\\")
                escapedKeyword := StrReplace(escapedKeyword, "%", "\%")
                escapedKeyword := StrReplace(escapedKeyword, "_", "\_")
                
                ; 对于短关键词（1-2个字符）或包含特殊字符的，使用 LIKE 查询
                ; FTS5 对单个字符或数字的匹配不够可靠
                keywordLen := StrLen(keyword)
                useLikeQuery := (keywordLen <= 2) || !RegExMatch(keyword, "^[\w\s]+$")
                
                if (hasFTS5Table && !useLikeQuery) {
                    ; 使用 FTS5 MATCH 语法（适用于长关键词）
                    ; FTS5 语法说明：
                    ; - keyword* 表示前缀匹配（以 keyword 开头的词）
                    ; - "phrase" 表示短语匹配
                    ; - 多个词用空格分隔表示 AND
                    ; 转义特殊字符（FTS5 需要特殊处理）
                    ftsEscapedKeyword := StrReplace(keyword, "'", "''")
                    ftsEscapedKeyword := StrReplace(ftsEscapedKeyword, "\", "\\")
                    ftsEscapedKeyword := StrReplace(ftsEscapedKeyword, '"', '""')
                    
                    ; 如果关键词包含空格，使用短语匹配；否则使用前缀匹配
                    if (InStr(ftsEscapedKeyword, " ")) {
                        ; 包含空格，使用短语匹配
                        ftsQuery := '"' . ftsEscapedKeyword . '"'
                    } else {
                        ; 单个词，使用前缀匹配
                        ftsQuery := ftsEscapedKeyword . '*'
                    }
                    
                    ; 使用 FTS5 表进行搜索（MATCH 语法）
                    ; 注意：FTS5 MATCH 需要使用单引号包裹查询字符串
                    ; 搜索 Content 和 SourceApp 等核心字段，不受 DataType 限制（全域搜索）
                    whereConditions.Push("ID IN (SELECT rowid FROM ClipboardHistory WHERE ClipboardHistory MATCH '" . ftsQuery . "')")
                } else {
                    ; 使用 LIKE 查询（适用于短关键词或 FTS5 不可用）
                    ; 搜索 Content 和 SourceApp 字段，不受 DataType 限制（全域搜索）
                    whereConditions.Push("(Content LIKE '%" . escapedKeyword . "%' OR SourceApp LIKE '%" . escapedKeyword . "%')")
                }
            }
            
            ; 添加标签过滤条件
            ; 只有当 HistorySelectedTag 不为空时，才添加 DataType 过滤条件
            ; 当 HistorySelectedTag 为空时（默认状态），不添加任何 DataType 条件，实现全域搜索
            if (HistorySelectedTag != "") {
                ; 转义标签类型
                escapedTagType := StrReplace(HistorySelectedTag, "'", "''")
                
                ; 特殊处理：文本标签包含Text和Email类型
                if (HistorySelectedTag = "Text") {
                    whereConditions.Push("(DataType = 'Text' OR DataType = 'Email')")
                } else if (HistorySelectedTag = "Image") {
                    ; 图片标签：筛选 DataType = 'Image' 的记录
                    ; 同时也筛选 Content 字段是图片路径的记录（即使 DataType 不是 Image）
                    whereConditions.Push("(DataType = 'Image' OR " .
                        "(Content LIKE '%.png' OR Content LIKE '%.jpg' OR Content LIKE '%.jpeg' OR " .
                        "Content LIKE '%.gif' OR Content LIKE '%.bmp' OR Content LIKE '%.webp' OR " .
                        "Content LIKE '%.tiff' OR Content LIKE '%.ico' OR " .
                        "ImagePath IS NOT NULL AND ImagePath != ''))")
                } else if (HistorySelectedTag = "Folder") {
                    ; 文件夹标签：筛选文件夹路径
                    ; 注意：由于 SQLite 无法直接调用 DirExist，我们先通过路径格式进行初步筛选
                    ; 精确过滤将在数据加载后通过代码完成
                    folderCondition := "(" .
                        "(Content LIKE '%\\%' OR Content LIKE '%/%') OR " .  ; Content 包含路径分隔符
                        "(SourcePath IS NOT NULL AND SourcePath != '' AND SourcePath != '\\' AND " .
                        "(SourcePath LIKE '%\\%' OR SourcePath LIKE '%/%'))" .  ; SourcePath 是路径
                        ")"
                    whereConditions.Push(folderCondition)
                } else if (HistorySelectedTag = "Screenshot") {
                    ; 截图标签：筛选截图（图片类型）
                    screenshotCondition := "(" .
                        "DataType = 'Image' OR " .  ; 截图类型
                        "ImagePath IS NOT NULL AND ImagePath != ''" .  ; 有图片路径
                        ")"
                    whereConditions.Push(screenshotCondition)
                } else if (HistorySelectedTag = "CapsLockC") {
                    ; CapsLock+C 标签：筛选 CapsLock+C 复制的数据（DataType=Stack）
                    whereConditions.Push("DataType = 'Stack'")
                } else {
                    whereConditions.Push("DataType = '" . escapedTagType . "'")
                }
            }
            
            ; 构建SQL查询（从 ClipMain 表查询，但使用 FTS5 进行搜索）
            SQL := "SELECT " . selectFields . " FROM ClipMain"
            ; 如果 whereConditions 数组不为空，使用 AND 连接所有条件
            ; 如果数组为空（既没搜关键词也没选标签），则不添加 WHERE 子句，直接查询全表
            if (whereConditions.Length > 0) {
                SQL .= " WHERE " . whereConditions[1]
                Loop whereConditions.Length - 1 {
                    SQL .= " AND " . whereConditions[A_Index + 1]
                }
            }
            ; 使用 OFFSET 和 LIMIT 支持分页加载
            SQL .= " ORDER BY " . orderByField . " DESC LIMIT " . (limit + 1) . " OFFSET " . offset
            
            ; 调试：记录 SQL 查询和结果（开发时启用）
            ; OutputDebug("ClipboardHistoryPanel SQL: " . SQL . "`n")
            ; OutputDebug("ClipboardHistoryPanel 搜索关键词: " . keyword . ", 标签: " . HistorySelectedTag . "`n")
            
            table := ""
            querySuccess := ClipboardFTS5DB.GetTable(SQL, &table)
            if (querySuccess) {
                if (table.HasRows && table.Rows.Length > 0) {
                    ; 获取列名（用于验证列顺序）
                    columnNames := []
                    columnIndexMap := Map()
                    if (table.HasNames && table.ColumnNames.Length > 0) {
                        columnNames := table.ColumnNames
                        ; 创建列名到索引的映射
                        Loop columnNames.Length {
                            colName := columnNames[A_Index]
                            columnIndexMap[colName] := A_Index
                        }
                    }
                    
                    ; 遍历所有行
                    Loop table.Rows.Length {
                        row := table.Rows[A_Index]
                        rowData := Map()
                        
                        ; 如果有列名映射，使用列名映射读取；否则按固定位置读取
                        if (columnIndexMap.Count > 0) {
                            ; 使用列名映射读取（更安全）
                            if (columnIndexMap.Has("ID")) {
                                rowData["ID"] := row[columnIndexMap["ID"]]
                            }
                            if (columnIndexMap.Has("Content")) {
                                rowData["Content"] := row[columnIndexMap["Content"]]
                            }
                            if (columnIndexMap.Has("SourceApp")) {
                                rowData["SourceApp"] := row[columnIndexMap["SourceApp"]]
                            }
                            if (columnIndexMap.Has("SourcePath")) {
                                rowData["SourcePath"] := row[columnIndexMap["SourcePath"]]
                            }
                            if (columnIndexMap.Has("IconPath")) {
                                rowData["IconPath"] := row[columnIndexMap["IconPath"]]
                            }
                            if (columnIndexMap.Has("DataType")) {
                                rowData["DataType"] := row[columnIndexMap["DataType"]]
                            }
                            if (columnIndexMap.Has("CharCount")) {
                                rowData["CharCount"] := row[columnIndexMap["CharCount"]]
                            }
                            if (columnIndexMap.Has("Timestamp")) {
                                rowData["Timestamp"] := row[columnIndexMap["Timestamp"]]
                            }
                            if (columnIndexMap.Has("LastCopyTime")) {
                                rowData["LastCopyTime"] := row[columnIndexMap["LastCopyTime"]]
                            }
                            if (columnIndexMap.Has("CopyCount")) {
                                rowData["CopyCount"] := row[columnIndexMap["CopyCount"]]
                            }
                            if (columnIndexMap.Has("ImagePath")) {
                                rowData["ImagePath"] := row[columnIndexMap["ImagePath"]]
                            }
                        } else {
                            ; 按固定顺序读取（后备方案）
                            ; SQL查询的列顺序：ID(1), Content(2), SourceApp(3), SourcePath(4), IconPath(5), DataType(6), CharCount(7), Timestamp(8), ImagePath(9), LastCopyTime(10), CopyCount(11)
                            rowCount := row.Length
                            
                            if (rowCount >= 1) {
                                rowData["ID"] := row[1]
                            }
                            if (rowCount >= 2) {
                                rowData["Content"] := row[2]
                            }
                            if (rowCount >= 3) {
                                rowData["SourceApp"] := row[3]
                            }
                            if (rowCount >= 4) {
                                rowData["SourcePath"] := row[4]
                            }
                            if (rowCount >= 5) {
                                rowData["IconPath"] := row[5]
                            }
                            if (rowCount >= 6) {
                                rowData["DataType"] := row[6]
                            }
                            if (rowCount >= 7) {
                                rowData["CharCount"] := row[7]
                            }
                            if (rowCount >= 8) {
                                rowData["Timestamp"] := row[8]
                            }
                            if (rowCount >= 9) {
                                rowData["ImagePath"] := row[9]
                            }
                            if (rowCount >= 10) {
                                rowData["LastCopyTime"] := row[10]
                            }
                            if (rowCount >= 11) {
                                rowData["CopyCount"] := row[11]
                            }
                        }
                        
                        ; 确保所有必需字段都有值
                        if (!rowData.Has("ID") || rowData["ID"] = "") {
                            continue
                        }
                        ; 对于图片类型，Content 可能为空（因为图片路径存储在 ImagePath 中）
                        ; 对于非图片类型，Content 不能为空
                        if (rowData.Has("DataType") && rowData["DataType"] != "Image") {
                            if (!rowData.Has("Content") || rowData["Content"] = "") {
                                continue  ; 跳过空内容（非图片类型）
                            }
                        } else if (!rowData.Has("DataType") || rowData["DataType"] = "") {
                            ; 如果没有数据类型，检查 Content
                            if (!rowData.Has("Content") || rowData["Content"] = "") {
                                continue  ; 跳过空内容
                            }
                        }
                        if (!rowData.Has("SourceApp") || rowData["SourceApp"] = "") {
                            rowData["SourceApp"] := "Unknown"
                        }
                        if (!rowData.Has("DataType") || rowData["DataType"] = "") {
                            rowData["DataType"] := "Text"
                        }
                        if (!rowData.Has("CharCount") || rowData["CharCount"] = "" || rowData["CharCount"] = 0) {
                            rowData["CharCount"] := StrLen(rowData["Content"])
                        }
                        if (!rowData.Has("Timestamp") || rowData["Timestamp"] = "") {
                            continue  ; 跳过没有时间戳的记录
                        }
                        if (!rowData.Has("LastCopyTime") || rowData["LastCopyTime"] = "") {
                            rowData["LastCopyTime"] := rowData["Timestamp"]
                        }
                        if (!rowData.Has("CopyCount") || rowData["CopyCount"] = "" || rowData["CopyCount"] = 0) {
                            rowData["CopyCount"] := 1
                        }
                        if (!rowData.Has("SourcePath")) {
                            rowData["SourcePath"] := ""
                        }
                        if (!rowData.Has("IconPath")) {
                            rowData["IconPath"] := ""
                        }
                        if (!rowData.Has("ImagePath")) {
                            rowData["ImagePath"] := ""
                        }
                        
                        ; 如果选择了"文件夹"标签，进行精确过滤
                        if (HistorySelectedTag = "Folder") {
                            ; 检查是否是文件夹路径
                            isFolder := false
                            
                            ; 1. 检查 Content 是否是文件夹路径
                            if (rowData.Has("Content") && rowData["Content"] != "") {
                                content := rowData["Content"]
                                content := StrReplace(content, "\\\\", "\")
                                content := StrReplace(content, "\\", "\")
                                
                                ; 检查是否是路径格式（包含路径分隔符）
                                if (InStr(content, "\") || InStr(content, "/")) {
                                    ; 检查是否是文件夹（不是文件）
                                    if (DirExist(content)) {
                                        isFolder := true
                                    }
                                }
                            }
                            
                            ; 2. 检查 SourcePath 是否是文件夹路径
                            if (!isFolder && rowData.Has("SourcePath") && rowData["SourcePath"] != "" && rowData["SourcePath"] != "\\") {
                                sourcePath := rowData["SourcePath"]
                                sourcePath := StrReplace(sourcePath, "\\\\", "\")
                                sourcePath := StrReplace(sourcePath, "\\", "\")
                                
                                ; 检查是否是路径格式（包含路径分隔符）
                                if (InStr(sourcePath, "\") || InStr(sourcePath, "/")) {
                                    ; 检查是否是文件夹（不是文件）
                                    if (DirExist(sourcePath)) {
                                        isFolder := true
                                    }
                                }
                            }
                            
                            ; 只有是文件夹时才添加到结果中
                            if (!isFolder) {
                                continue  ; 跳过这条记录
                            }
                        }
                        
                        ; 如果选择了"截图"标签，进行精确过滤
                        if (HistorySelectedTag = "Screenshot") {
                            ; 检查是否是截图（图片）
                            isScreenshot := false
                            
                            ; 1. 检查 DataType 是否是 Image
                            if (rowData.Has("DataType") && rowData["DataType"] = "Image") {
                                isScreenshot := true
                            }
                            
                            ; 2. 检查 ImagePath 是否存在且是图片文件
                            if (!isScreenshot && rowData.Has("ImagePath") && rowData["ImagePath"] != "") {
                                imagePath := rowData["ImagePath"]
                                imagePath := StrReplace(imagePath, "\\\\", "\")
                                imagePath := StrReplace(imagePath, "\\", "\")
                                if (FileExist(imagePath)) {
                                    ; 检查文件扩展名，确认是图片文件
                                    SplitPath(imagePath, , , &ext)
                                    ext := StrLower(ext)
                                    if (ext = "png" || ext = "jpg" || ext = "jpeg" || ext = "gif" || 
                                        ext = "bmp" || ext = "webp" || ext = "tiff" || ext = "ico") {
                                        isScreenshot := true
                                    }
                                }
                            }
                            
                            ; 3. 检查 Content 是否是图片文件路径
                            if (!isScreenshot && rowData.Has("Content") && rowData["Content"] != "") {
                                content := rowData["Content"]
                                content := StrReplace(content, "\\\\", "\")
                                content := StrReplace(content, "\\", "\")
                                
                                ; 检查是否是路径格式（包含路径分隔符）
                                if (InStr(content, "\") || InStr(content, "/")) {
                                    if (FileExist(content)) {
                                        ; 检查文件扩展名，确认是图片文件
                                        SplitPath(content, , , &ext)
                                        ext := StrLower(ext)
                                        if (ext = "png" || ext = "jpg" || ext = "jpeg" || ext = "gif" || 
                                            ext = "bmp" || ext = "webp" || ext = "tiff" || ext = "ico") {
                                            isScreenshot := true
                                        }
                                    }
                                }
                            }
                            
                            ; 只有是截图时才添加到结果中
                            if (!isScreenshot) {
                                continue  ; 跳过这条记录
                            }
                        }
                        
                        ; 如果选择了"图片"标签，进行精确过滤
                        if (HistorySelectedTag = "Image") {
                            ; 检查是否是图片
                            isImage := false
                            
                            ; 1. 检查 DataType 是否是 Image
                            if (rowData.Has("DataType") && rowData["DataType"] = "Image") {
                                isImage := true
                            }
                            
                            ; 2. 检查 ImagePath 是否存在且是图片文件
                            if (!isImage && rowData.Has("ImagePath") && rowData["ImagePath"] != "") {
                                imagePath := rowData["ImagePath"]
                                imagePath := StrReplace(imagePath, "\\\\", "\")
                                imagePath := StrReplace(imagePath, "\\", "\")
                                if (FileExist(imagePath)) {
                                    ; 检查文件扩展名，确认是图片文件
                                    SplitPath(imagePath, , , &ext)
                                    ext := StrLower(ext)
                                    if (ext = "png" || ext = "jpg" || ext = "jpeg" || ext = "gif" || 
                                        ext = "bmp" || ext = "webp" || ext = "tiff" || ext = "ico" || ext = "svg") {
                                        isImage := true
                                    }
                                }
                            }
                            
                            ; 3. 检查 Content 是否是图片文件路径
                            if (!isImage && rowData.Has("Content") && rowData["Content"] != "") {
                                content := rowData["Content"]
                                content := StrReplace(content, "\\\\", "\")
                                content := StrReplace(content, "\\", "\")
                                
                                ; 检查是否是路径格式（包含路径分隔符）
                                if (InStr(content, "\") || InStr(content, "/")) {
                                    if (FileExist(content)) {
                                        ; 检查文件扩展名，确认是图片文件
                                        SplitPath(content, , , &ext)
                                        ext := StrLower(ext)
                                        if (ext = "png" || ext = "jpg" || ext = "jpeg" || ext = "gif" || 
                                            ext = "bmp" || ext = "webp" || ext = "tiff" || ext = "ico" || ext = "svg") {
                                            isImage := true
                                        }
                                    }
                                }
                            }
                            
                            ; 只有是图片时才添加到结果中
                            if (!isImage) {
                                continue  ; 跳过这条记录
                            }
                        }
                        
                        ; 如果选择了"代码"标签，进行精确过滤
                        if (HistorySelectedTag = "Code") {
                            ; 只匹配 DataType = 'Code' 的记录
                            if (!rowData.Has("DataType") || rowData["DataType"] != "Code") {
                                continue  ; 跳过非代码类型的记录
                            }
                        }
                        
                        ; 如果选择了"链接"标签，进行精确过滤
                        if (HistorySelectedTag = "Link") {
                            ; 只匹配 DataType = 'Link' 的记录
                            if (!rowData.Has("DataType") || rowData["DataType"] != "Link") {
                                continue  ; 跳过非链接类型的记录
                            }
                        }
                        
                        ; 如果选择了"文本"标签，进行精确过滤
                        if (HistorySelectedTag = "Text") {
                            ; 只匹配 DataType = 'Text' 或 'Email' 的记录
                            if (!rowData.Has("DataType") || 
                                (rowData["DataType"] != "Text" && rowData["DataType"] != "Email")) {
                                continue  ; 跳过非文本类型的记录
                            }
                        }
                        
                        ; 如果选择了"CapsLock+C"标签，进行精确过滤
                        if (HistorySelectedTag = "CapsLockC") {
                            ; 只匹配 DataType = 'Stack' 的记录
                            if (!rowData.Has("DataType") || rowData["DataType"] != "Stack") {
                                continue  ; 跳过非Stack类型的记录
                            }
                        }
                        
                        results.Push(rowData)
                    }
                }
                
                ; 检查是否还有更多数据（如果返回的数据量等于 limit+1，说明还有更多）
                HistoryHasMoreData := (results.Length > limit)
                if (HistoryHasMoreData) {
                    ; 移除最后一条数据（多查询的一条用于检测）
                    results.Pop()
                }
            } else {
                ; 查询失败，记录错误并尝试最简单的查询
                errorMsg := ClipboardFTS5DB.ErrorMsg
                ; OutputDebug("ClipboardHistoryPanel 查询失败: " . errorMsg . "`n")
                
                ; 尝试最简单的查询（也使用分页）
                fallbackSQL := "SELECT ID, Content, SourceApp, DataType, CharCount, Timestamp FROM ClipMain ORDER BY ID DESC LIMIT " . (limit + 1) . " OFFSET " . offset
                fallbackTable := ""
                if (ClipboardFTS5DB.GetTable(fallbackSQL, &fallbackTable)) {
                    if (fallbackTable.HasRows && fallbackTable.Rows.Length > 0) {
                        ; 检查是否还有更多数据
                        HistoryHasMoreData := (fallbackTable.Rows.Length > limit)
                        maxRows := HistoryHasMoreData ? limit : fallbackTable.Rows.Length
                        
                        Loop maxRows {
                            row := fallbackTable.Rows[A_Index]
                            rowData := Map()
                            rowData["ID"] := row[1]
                            rowData["Content"] := row[2]
                            rowData["SourceApp"] := row[3]
                            rowData["DataType"] := row[4]
                            rowData["CharCount"] := row[5]
                            rowData["Timestamp"] := row[6]
                            rowData["SourcePath"] := ""
                            rowData["IconPath"] := ""
                            rowData["LastCopyTime"] := row[6]
                            rowData["CopyCount"] := 1
                            results.Push(rowData)
                        }
                    } else {
                        HistoryHasMoreData := false
                    }
                } else {
                    HistoryHasMoreData := false
                }
            }
        }
    } catch as err {
        ; 错误处理 - 可以在这里添加错误日志
    }
    
    ; ===================== 集成 Everything 文件搜索 =====================
    ; 参考 SearchCenter 的实现：当关键词长度 > 1 时，使用 Everything 搜索文件
    if (keyword != "" && StrLen(keyword) > 1 && HistorySelectedTag != "Image" && HistorySelectedTag != "Color" && HistorySelectedTag != "Code") {
        try {
            ; 使用辅助函数安全调用 GetEverythingResults（如果存在）
            ; 使用下拉菜单设置的结果数量限制
            everythingResults := _ClipboardFTS5_GetEverythingResults(keyword, HistoryEverythingLimit)
            
            if (IsObject(everythingResults) && everythingResults.Length > 0) {
                ; 先收集所有文件结果
                fileResults := []
                
                for index, result in everythingResults {
                    ; 处理新的Map格式结果
                    path := ""
                    isDirectory := false
                    
                    if (Type(result) = "Map") {
                        path := result["Path"]
                        isDirectory := result.Has("IsDirectory") ? result["IsDirectory"] : false
                    } else {
                        ; 向后兼容：如果返回的是字符串路径
                        path := result
                    }
                    
                    ; 检查路径是否存在
                    if (path = "" || (!FileExist(path) && !DirExist(path))) {
                        continue
                    }
                    
                    SplitPath(path, &FileName, &DirPath, &Ext, &NameNoExt)
                    
                    ; 创建文件结果项
                    fileItem := Map()
                    fileItem["ID"] := (isDirectory ? "folder_" : "file_") . path  ; 使用特殊前缀标识文件/文件夹结果
                    fileItem["Content"] := path
                    fileItem["SourceApp"] := isDirectory ? "文件夹" : "文件系统"
                    fileItem["SourcePath"] := path
                    fileItem["IconPath"] := path
                    fileItem["DataType"] := isDirectory ? "Folder" : "File"
                    fileItem["CharCount"] := 0
                    fileItem["Timestamp"] := ""  ; 文件没有时间戳
                    fileItem["LastCopyTime"] := ""
                    fileItem["CopyCount"] := 1
                    fileItem["ImagePath"] := ""
                    fileItem["IsDirectory"] := isDirectory
                    
                    fileResults.Push(fileItem)
                }
                
                ; 将文件结果插入到结果数组前面（优先显示文件结果）
                if (fileResults.Length > 0) {
                    ; 反转文件结果数组，然后插入到前面（这样第一个文件会在最前面）
                    fileResultsReverse := []
                    Loop fileResults.Length {
                        fileResultsReverse.Push(fileResults[fileResults.Length - A_Index + 1])
                    }
                    
                    ; 将文件结果插入到结果数组前面
                    for index, fileItem in fileResultsReverse {
                        results.InsertAt(index, fileItem)
                    }
                }
            }
        } catch as err {
            ; Everything 搜索失败，静默失败，不影响剪贴板历史显示
            ; OutputDebug("ClipboardHistoryPanel: Everything 搜索失败: " . err.Message . "`n")
        }
    }
    
    ; 更新缓存（如果是追加模式，合并数据；否则替换）
    if (offset > 0 && HistoryDisplayCache.Length > 0) {
        ; 追加模式：合并到现有缓存
        for index, item in results {
            HistoryDisplayCache.Push(item)
        }
    } else {
        ; 替换模式：直接替换缓存
        HistoryDisplayCache := results
    }
    
    ; 调试输出：检查数据数量
    ; OutputDebug("ClipboardHistoryPanel: 准备添加 " . results.Length . " 条数据到 ListView`n")
    
    ; 更新 ListView
    if (HistoryListView) {
        ; 暂停重绘以提高性能
        HistoryListView.Opt("-Redraw")
        
        ; 如果是追加模式，不清空列表；否则清空
        if (offset = 0) {
            HistoryListView.Delete()
        }
        
        ; 添加数据（追加模式只添加新数据）
        for index, rowData in HistoryDisplayCache {
            ; 追加模式：只添加新数据（跳过已存在的）
            if (offset > 0 && index <= offset) {
                continue
            }
            ; 调试输出：检查每条数据
            ; if (index <= 3) {
            ;     OutputDebug("ClipboardHistoryPanel: 数据 " . index . " - Content=" . (rowData.Has("Content") ? SubStr(rowData["Content"], 1, 50) : "无") . ", SourceApp=" . (rowData.Has("SourceApp") ? rowData["SourceApp"] : "无") . "`n")
            ; }
            ; 获取内容预览（最多80字符）
            ; 对于图片类型，Content 字段存储的是图片路径，显示文件名
            dataType := rowData.Has("DataType") ? rowData["DataType"] : "Text"
            preview := rowData.Has("Content") ? rowData["Content"] : ""
            
            ; 如果是图片类型，显示图片文件名而不是完整路径
            if (dataType = "Image") {
                imagePath := rowData.Has("ImagePath") ? rowData["ImagePath"] : preview
                if (imagePath != "" && FileExist(imagePath)) {
                    try {
                        SplitPath(imagePath, &fileName)
                        preview := "[图片] " . fileName
                    } catch {
                        preview := "[图片] " . imagePath
                    }
                } else {
                    preview := "[图片]"
                }
            } else {
                ; 文本类型，正常处理
                if (preview = "") {
                    preview := "(空内容)"
                } else {
                    if (StrLen(preview) > 80) {
                        preview := SubStr(preview, 1, 80) . "..."
                    }
                    ; 替换换行符为空格
                    preview := StrReplace(preview, "`r`n", " ")
                    preview := StrReplace(preview, "`n", " ")
                    preview := StrReplace(preview, "`r", " ")
                }
            }
            
            ; 如果是 Stack 标签，在内容前缀添加红色圆点标识和样式标记
            if (dataType = "Stack") {
                preview := "🔴 [叠加] " . preview
            }
            
            ; 格式化时间
            try {
                lastCopyTime := rowData.Has("LastCopyTime") && rowData["LastCopyTime"] != "" ? rowData["LastCopyTime"] : rowData["Timestamp"]
                timeText := FormatTime(lastCopyTime, "yyyy-MM-dd HH:mm:ss")
            } catch {
                timeText := rowData.Has("LastCopyTime") ? rowData["LastCopyTime"] : rowData["Timestamp"]
            }
            
            ; 确保所有字段都有值并正确类型
            sourceApp := rowData.Has("SourceApp") && rowData["SourceApp"] != "" ? String(rowData["SourceApp"]) : "Unknown"
            dataType := rowData.Has("DataType") && rowData["DataType"] != "" ? String(rowData["DataType"]) : "Text"
            
            ; 处理图片路径识别（需要在 fileLocation 计算之前）
            imagePath := ""
            ; 优先使用 ImagePath 字段
            if (rowData.Has("ImagePath") && rowData["ImagePath"] != "") {
                imagePath := rowData["ImagePath"]
            } else if (rowData.Has("Content") && rowData["Content"] != "") {
                ; 如果 ImagePath 为空，检查 Content 是否是图片路径
                content := rowData["Content"]
                ; 处理路径中的转义字符（将 \\\\ 转换为 \\，将 \\ 转换为 \）
                content := StrReplace(content, "\\\\", "\")
                content := StrReplace(content, "\\", "\")
                
                ; 检查是否是文件路径（包含路径分隔符）
                if (InStr(content, "\") || InStr(content, "/")) {
                    ; 检查文件扩展名，确认是图片文件（先检查扩展名，避免不必要的 FileExist 调用）
                    SplitPath(content, , , &ext)
                    ext := StrLower(ext)
                    if (ext = "png" || ext = "jpg" || ext = "jpeg" || ext = "gif" || ext = "bmp" || ext = "webp" || ext = "tiff" || ext = "ico") {
                        ; 检查文件是否存在
                        if (FileExist(content)) {
                            imagePath := content
                            ; 如果数据类型不是 Image，但文件是图片，也当作图片处理
                            if (dataType != "Image") {
                                dataType := "Image"
                            }
                        }
                    }
                }
            }
            
            ; 获取文件位置（显示文件名或路径）
            ; 对于图片类型，优先显示图片文件名；否则显示来源应用的文件名
            fileLocation := "-"
            if (dataType = "Image" || (imagePath != "" && FileExist(imagePath))) {
                ; 图片类型，显示图片文件名
                if (imagePath != "" && FileExist(imagePath)) {
                    try {
                        SplitPath(imagePath, &fileName)
                        fileLocation := fileName
                    } catch {
                        ; 如果解析失败，尝试从 Content 获取
                        if (rowData.Has("Content")) {
                            content := rowData["Content"]
                            if (InStr(content, "\") || InStr(content, "/")) {
                                SplitPath(content, &fileName)
                                fileLocation := fileName
                            } else {
                                fileLocation := "-"
                            }
                        }
                    }
                } else {
                    fileLocation := "-"
                }
            } else {
                ; 非图片类型，显示来源应用的文件名
                sourcePath := rowData.Has("SourcePath") ? rowData["SourcePath"] : ""
                if (sourcePath != "" && sourcePath != "\\") {
                    try {
                        SplitPath(sourcePath, &fileName)
                        fileLocation := fileName
                    } catch {
                        fileLocation := sourcePath
                    }
                } else {
                    fileLocation := "-"
                }
            }
            
            ; 获取复制次数（确保是数字）
            copyCount := 1
            if (rowData.Has("CopyCount")) {
                copyCountValue := rowData["CopyCount"]
                if (copyCountValue != "" && copyCountValue != 0) {
                    ; 确保是数字类型
                    try {
                        copyCount := Integer(copyCountValue)
                    } catch {
                        copyCount := 1
                    }
                }
            }
            
            ; 获取字符数（确保是数字）
            charCount := 0
            if (rowData.Has("CharCount")) {
                charCountValue := rowData["CharCount"]
                if (charCountValue != "" && charCountValue != 0) {
                    try {
                        charCount := Integer(charCountValue)
                    } catch {
                        charCount := StrLen(rowData["Content"])
                    }
                } else {
                    charCount := StrLen(rowData["Content"])
                }
            } else {
                charCount := StrLen(rowData["Content"])
            }
            
            ; 确定图标索引（使用自定义 ImageList 提取精准软件图标）
            ; 优先使用 SourcePath（应用程序路径）来提取图标
            iconIndex := GetFileIconIndex("", rowData)
            
            ; 注意：IL_Add 返回的索引从 1 开始，直接使用即可
            ; 如果 iconIndex 为 0，表示没有图标，不显示图标
            
            ; 获取文件后缀名和文件大小
            fileExtension := "-"
            fileSize := "-"
            
            ; 确定文件路径（优先使用 imagePath，然后是 sourcePath，最后是 Content）
            actualFilePath := ""
            if (imagePath != "" && FileExist(imagePath)) {
                actualFilePath := imagePath
            } else {
                sourcePath := rowData.Has("SourcePath") ? rowData["SourcePath"] : ""
                if (sourcePath != "" && sourcePath != "\\" && FileExist(sourcePath)) {
                    actualFilePath := sourcePath
                } else {
                    content := rowData.Has("Content") ? rowData["Content"] : ""
                    if (content != "") {
                        content := StrReplace(content, "\\\\", "\")
                        content := StrReplace(content, "\\", "\")
                        if ((InStr(content, "\") || InStr(content, "/")) && FileExist(content)) {
                            actualFilePath := content
                        }
                    }
                }
            }
            
            ; 如果有文件路径，获取文件后缀名和大小
            if (actualFilePath != "") {
                fileExtension := GetFileExtension(actualFilePath)
                fileSize := GetFileSize(actualFilePath)
            }
            
            ; 确保所有字段都有有效值（不能为空字符串，至少要有占位符）
            if (preview = "") {
                preview := "(空内容)"
            }
            if (sourceApp = "") {
                sourceApp := "Unknown"
            }
            if (fileLocation = "") {
                fileLocation := "-"
            }
            if (dataType = "") {
                dataType := "Text"
            }
            if (fileExtension = "") {
                fileExtension := "-"
            }
            if (fileSize = "") {
                fileSize := "-"
            }
            if (timeText = "") {
                timeText := "-"
            }
            if (copyCount = "") {
                copyCount := "0"
            }
            if (charCount = "") {
                charCount := "0"
            }
            
            ; 添加行到 ListView（标准写法：防止数据覆盖）
            ; 关键！参数对应：
            ; 参数1 ("Icon" . N): 行属性，指定图标索引（IL_Add 返回的索引从1开始，直接使用）
            ;   注意：在 Report 视图中，图标通过 ImageList 和 IconN 选项显示在第一列前
            ; 参数2 (index): 第1列 [序号]
            ; 参数3 (preview): 第2列 [内容预览]
            ; 参数4 (sourceApp): 第3列 [来源应用]
            ; 参数5 (fileLocation): 第4列 [文件位置]
            ; 参数6 (dataType): 第5列 [类型]
            ; 参数7 (fileExtension): 第6列 [文件后缀]
            ; 参数8 (fileSize): 第7列 [文件大小]
            ; 参数9 (timeText): 第8列 [最后复制时间]
            ; 参数10 (copyCount): 第9列 [复制次数]
            ; 参数11 (charCount): 第10列 [字符数]
            ; IL_Add 返回的索引从 1 开始，如果为 0 表示没有图标
            iconOption := (iconIndex > 0) ? "Icon" . iconIndex : ""
            rowIndex := HistoryListView.Add(iconOption,
                String(index),            ; 第1列：序号
                String(preview),          ; 第2列：内容预览
                String(sourceApp),        ; 第3列：来源应用
                String(fileLocation),     ; 第4列：文件位置
                String(dataType),         ; 第5列：类型
                String(fileExtension),     ; 第6列：文件后缀
                String(fileSize),         ; 第7列：文件大小
                String(timeText),         ; 第8列：最后复制时间
                String(copyCount),        ; 第9列：复制次数
                String(charCount))        ; 第10列：字符数
        }
        
        ; 恢复重绘
        HistoryListView.Opt("+Redraw")
        
    }
}

; ===================== 结果数量限制下拉菜单变化事件 =====================
OnHistoryResultLimitChange(*) {
    global HistoryResultLimitDropdown, HistoryEverythingLimit, HistorySearchEdit, HistoryCurrentLimit
    
    ; 检查控件是否存在
    if (!IsSet(HistoryResultLimitDropdown) || !HistoryResultLimitDropdown) {
        return
    }
    
    ; 获取选中的值
    try {
        selectedText := HistoryResultLimitDropdown.Value
        HistoryEverythingLimit := Integer(selectedText)
    } catch {
        HistoryEverythingLimit := 50  ; 默认值
    }
    
    ; 如果搜索框有内容，重新搜索
    if (IsSet(HistorySearchEdit) && HistorySearchEdit && HistorySearchEdit.Value != "") {
        keyword := Trim(HistorySearchEdit.Value)
        HistoryCurrentLimit := 100  ; 重置限制
        RefreshHistoryData(keyword, 0, HistoryCurrentLimit)
    }
}

; ===================== 搜索框变化事件（带防抖）=====================
OnHistorySearchChange(*) {
    global HistorySearchEdit, HistorySearchTimer
    
    ; 搜索时隐藏图片预览窗口
    HideHistoryImagePreview()
    
    ; 如果用户正在快速输入，取消上一个还没执行的刷新任务
    if (HistorySearchTimer != 0) {
        try {
            SetTimer(HistorySearchTimer, 0)  ; 取消定时器
        } catch {
        }
    }
    
    ; 设置 300 毫秒后执行刷新（用户停顿后才查数据库）
    ; 使用函数对象而不是箭头函数，避免语法问题
    HistorySearchTimer := DoSearchRefresh
    SetTimer(HistorySearchTimer, -300)  ; 300毫秒后执行
}

; ===================== 执行搜索刷新（防抖回调）=====================
DoSearchRefresh(*) {
    global HistorySearchEdit, HistoryCurrentLimit
    
    ; 参考 SearchCenter 的实现，使用 Trim 处理关键词
    keyword := Trim(HistorySearchEdit.Value)
    ; 搜索时重置限制
    HistoryCurrentLimit := 100
    RefreshHistoryData(keyword, 0, HistoryCurrentLimit)
}

; ===================== 标签点击事件 =====================
OnHistoryTagClick(tagType, *) {
    global HistorySelectedTag, HistoryTagButtons, HistorySearchEdit
    
    ; 如果点击的是已选中的标签，则取消选中（显示全部）
    if (HistorySelectedTag = tagType) {
        HistorySelectedTag := ""
        ; 如果关闭了颜色标签，隐藏颜色汇总面板
        if (tagType = "Color") {
            HideColorSummaryPanel()
        }
    } else {
        HistorySelectedTag := tagType
        
        ; 如果点击的是颜色标签，显示颜色汇总面板
        if (tagType = "Color") {
            ; 先刷新数据，然后显示汇总面板
            keyword := Trim(HistorySearchEdit.Value)
            HistoryCurrentLimit := 100
            RefreshHistoryData(keyword, 0, HistoryCurrentLimit)
            ; 延迟显示，确保数据已加载
            SetTimer(() => ShowColorSummaryPanel(), -200)
        } else {
            ; 点击其他标签时，隐藏颜色汇总面板
            HideColorSummaryPanel()
        }
    }
    
    ; 更新所有标签按钮的样式
    UpdateHistoryTagButtons()
    
    ; 如果不是颜色标签，刷新数据
    if (tagType != "Color") {
        keyword := Trim(HistorySearchEdit.Value)
        ; 切换标签时重置限制
        HistoryCurrentLimit := 100
        RefreshHistoryData(keyword, 0, HistoryCurrentLimit)
    }
}

; ===================== 更新标签按钮样式 =====================
UpdateHistoryTagButtons() {
    global HistoryTagButtons, HistorySelectedTag, HistoryColors
    
    ; 遍历所有标签按钮
    for tagType, button in HistoryTagButtons {
        IsSelected := (HistorySelectedTag = tagType)
        BgColor := IsSelected ? HistoryColors.TagBgActive : HistoryColors.TagBg
        TextColor := IsSelected ? HistoryColors.TagTextActive : HistoryColors.TagText
        
        try {
            button.Opt("+Background" . BgColor)
            button.SetFont("s10 c" . TextColor . " Bold", "Segoe UI")
            
            ; 更新悬停效果（如果 HoverBtnWithAnimation 函数可用）
            try {
                hoverFunc := HoverBtnWithAnimation
                if (IsSet(hoverFunc)) {
                    HoverBtnWithAnimation(button, BgColor, HistoryColors.TagBgActive)
                }
            } catch {
                ; 如果函数不可用，忽略错误
            }
        } catch as err {
            ; 忽略错误，继续处理下一个按钮
        }
    }
}

; ===================== ListView 点击事件 =====================
OnHistoryItemClick(*) {
    ; 点击时立即触发预览
    OutputDebug("ClipboardHistoryPanel: OnHistoryItemClick 被调用`n")
    ; 延迟一点执行，确保选中状态已更新
    SetTimer(() => ProcessImagePreview(), -10)
}

; ===================== ListView 项选择事件 =====================
OnHistoryItemSelect(*) {
    ; 选中时也触发预览
    OutputDebug("ClipboardHistoryPanel: OnHistoryItemSelect 被调用`n")
    ; 延迟一点执行，确保选中状态已更新
    SetTimer(() => ProcessImagePreview(), -10)
}

; ===================== 处理图片预览（统一处理函数）=====================
ProcessImagePreview() {
    global HistoryListView, HistoryDisplayCache, HistoryImagePreviewTimer, HistoryImagePreviewCurrentPath, GuiID_ClipboardHistory
    
    OutputDebug("ClipboardHistoryPanel: ProcessImagePreview 开始执行`n")
    
    ; 确保 ListView 存在且事件已绑定
    if (!HistoryListView) {
        OutputDebug("ClipboardHistoryPanel: HistoryListView 不存在，退出`n")
        return
    }
    
    selectedRow := HistoryListView.GetNext()
    OutputDebug("ClipboardHistoryPanel: 选中的行 = " . selectedRow . ", 缓存长度 = " . HistoryDisplayCache.Length . "`n")
    
    if (selectedRow > 0 && selectedRow <= HistoryDisplayCache.Length) {
        rowData := HistoryDisplayCache[selectedRow]
        
        ; 改进的图片判定逻辑：不仅检查 DataType，还检查文件扩展名和文件是否存在
        imagePath := GetImagePathFromRowData(rowData)
        
        ; 调试输出（用于排查问题）
        ; 只在真正需要调试时输出，避免对非图片类型的正常情况输出警告
        if (imagePath != "") {
            OutputDebug("ClipboardHistoryPanel: 找到图片路径 - " . imagePath . ", FileExist=" . (FileExist(imagePath) ? "true" : "false") . "`n")
        } else {
            ; 只在 DataType 为 Image 但找不到路径时输出警告
            dataType := rowData.Has("DataType") ? rowData["DataType"] : ""
            if (dataType = "Image") {
                content := rowData.Has("Content") ? rowData["Content"] : ""
                OutputDebug("ClipboardHistoryPanel: 图片类型但未找到图片路径，Content=" . content . ", DataType=" . dataType . "`n")
            }
            ; 对于非图片类型（如 Text），不输出调试信息，这是正常情况
        }
        
        ; 如果是图片且有有效路径，立即显示预览
        if (imagePath != "" && FileExist(imagePath)) {
            ; 取消之前的定时器（如果有）
            if (HistoryImagePreviewTimer != 0) {
                try {
                    SetTimer(HistoryImagePreviewTimer, 0)
                } catch {
                }
                HistoryImagePreviewTimer := 0
            }
            
            ; 保存当前路径
            HistoryImagePreviewCurrentPath := imagePath
            
            ; 隐藏工具提示（如果有）
            ToolTip()
            
            ; 立即显示预览窗口（不延迟）
            ShowImagePreviewImmediately(imagePath)
        } else {
            ; 不是图片或图片路径无效，隐藏预览窗口
            HideHistoryImagePreview()
            HistoryImagePreviewCurrentPath := ""
            
            ; 显示详细信息（工具提示）- 仅当不是图片类型时显示
            ; 如果是图片类型但路径无效，不显示工具提示，避免干扰
            dataType := rowData.Has("DataType") ? rowData["DataType"] : "Text"
            if (dataType != "Image") {
                detailText := "ID: " . rowData["ID"] . "`n"
                detailText .= "内容: " . rowData["Content"] . "`n"
                detailText .= "来源应用: " . rowData["SourceApp"] . "`n"
                
                if (rowData.Has("SourcePath") && rowData["SourcePath"] != "") {
                    detailText .= "文件位置: " . rowData["SourcePath"] . "`n"
                }
                
                if (rowData.Has("IconPath") && rowData["IconPath"] != "") {
                    detailText .= "图标路径: " . rowData["IconPath"] . "`n"
                }
                
                detailText .= "类型: " . rowData["DataType"] . "`n"
                detailText .= "字符数: " . rowData["CharCount"] . "`n"
                detailText .= "首次复制: " . rowData["Timestamp"] . "`n"
                
                if (rowData.Has("LastCopyTime") && rowData["LastCopyTime"] != "") {
                    detailText .= "最后复制: " . rowData["LastCopyTime"] . "`n"
                }
                
                if (rowData.Has("CopyCount")) {
                    detailText .= "复制次数: " . rowData["CopyCount"] . "`n"
                }
                
                ; 显示工具提示
                ToolTip(detailText)
                SetTimer(() => ToolTip(), -5000)  ; 5秒后自动隐藏
            }
        }
    } else {
        ; 没有选中项，隐藏预览
        HideHistoryImagePreview()
        HistoryImagePreviewCurrentPath := ""
    }
}

; ===================== 解析图片路径（处理文件路径和数据库 BLOB）=====================
ResolveImagePath(imagePath) {
    ; 如果路径为空，返回空
    if (imagePath = "" || !imagePath) {
        return ""
    }
    
    ; 清理路径中的转义字符
    path := StrReplace(imagePath, "\\\\", "\")
    path := StrReplace(path, "\\", "\")
    
    ; 检查是否是有效的文件路径
    if (FileExist(path)) {
        return path
    }
    
    ; 如果不是文件路径，检查是否是数据库中的 BLOB 引用
    ; 这里可以根据实际需求扩展，比如从数据库读取 BLOB 并写入临时文件
    ; 目前先返回原路径，让调用者处理
    
    return path
}

; ===================== 从行数据获取图片路径（改进的判定逻辑）=====================
GetImagePathFromRowData(rowData) {
    path := ""
    
    ; 1. 优先检查 ImagePath 字段
    if (rowData.Has("ImagePath") && rowData["ImagePath"] != "") {
        path := rowData["ImagePath"]
    }
    ; 2. 如果 ImagePath 为空，检查 Content 字段
    else if (rowData.Has("Content") && rowData["Content"] != "") {
        content := rowData["Content"]
        
        ; 排除明显不是文件路径的值（如 API 函数名、图标索引等）
        ; 检查是否包含路径分隔符，或者是否以图片扩展名结尾
        if (InStr(content, "\") || InStr(content, "/") || RegExMatch(content, "i)\.(png|jpg|jpeg|gif|bmp|webp|ico|tiff|svg)$")) {
            path := content
        } else {
            ; Content 不是文件路径，跳过
            return ""
        }
    }
    
    if (path != "") {
        ; 清理可能的双斜杠转义（处理数据库存储时的转义）
        path := StrReplace(path, "\\\\", "\")
        path := StrReplace(path, "\\", "\")
        
        ; 验证文件后缀和文件是否存在
        SplitPath(path, , , &ext)
        if (ext != "") {
            ext := StrLower(ext)
            ; 使用正则表达式检查是否为图片格式
            if (RegExMatch(ext, "i)^(png|jpg|jpeg|gif|bmp|webp|ico|tiff|svg)$") && FileExist(path)) {
                return path
            }
        }
    }
    
    return ""
}

; ===================== 立即显示图片预览 =====================
ShowImagePreviewImmediately(imagePath) {
    global GuiID_ClipboardHistory, HistoryImagePreviewGUI, HistoryColors, HistoryGdiplusToken
    
    OutputDebug("ClipboardHistoryPanel: ShowImagePreviewImmediately 被调用，imagePath=" . imagePath . "`n")
    
    if (GuiID_ClipboardHistory = 0) {
        OutputDebug("ClipboardHistoryPanel: GuiID_ClipboardHistory 为 0，退出`n")
        return
    }
    
    ; 确保 GDI+ 已初始化
    if (HistoryGdiplusToken = 0) {
        InitGdiplus()
        if (HistoryGdiplusToken = 0) {
            OutputDebug("ClipboardHistoryPanel: GDI+ 初始化失败，无法显示图片预览`n")
            return
        }
    }
    
    ; 检查图片路径是否有效（可能是文件路径或需要从数据库读取的 BLOB）
    actualImagePath := ResolveImagePath(imagePath)
    if (actualImagePath = "") {
        OutputDebug("ClipboardHistoryPanel: 无法解析图片路径 - " . imagePath . "`n")
        return
    }
    
    if (!FileExist(actualImagePath)) {
        OutputDebug("ClipboardHistoryPanel: 图片文件不存在 - " . actualImagePath . "`n")
        return
    }
    
    try {
        OutputDebug("ClipboardHistoryPanel: 开始加载图片 - " . actualImagePath . "`n")
        
        ; 1. 获取图片尺寸（使用 GDI+）
        pBitmap := Gdip_CreateBitmapFromFile(actualImagePath)
        if (!pBitmap || pBitmap = 0) {
            OutputDebug("ClipboardHistoryPanel: Gdip_CreateBitmapFromFile 失败，尝试使用 ImagePut`n")
            ; 回退到 ImagePut
            pBitmap := ImagePut("Bitmap", actualImagePath)
            if (!pBitmap || pBitmap = "") {
                OutputDebug("ClipboardHistoryPanel: ImagePut 也失败，无法加载图片`n")
                return
            }
        }
        
        ; 获取图片尺寸
        imgWidth := 0
        imgHeight := 0
        if (IsInteger(pBitmap) && pBitmap != 0) {
            ; GDI+ Bitmap，使用 Gdip_GetImageDimensions
            Gdip_GetImageDimensions(pBitmap, &imgWidth, &imgHeight)
            Gdip_DisposeImage(pBitmap)
        } else if (pBitmap && pBitmap != "") {
            ; ImagePut Bitmap，使用 ImageDimensions
            dims := ImageDimensions(pBitmap)
            imgWidth := dims[1]
            imgHeight := dims[2]
            ImageDestroy(pBitmap)
        }
        
        if (imgWidth <= 0 || imgHeight <= 0) {
            OutputDebug("ClipboardHistoryPanel: 图片尺寸无效 - width=" . imgWidth . ", height=" . imgHeight . "`n")
            return
        }
        
        ; 2. 计算预览窗口尺寸（固定宽度，按比例计算高度）
        previewWidth := 350
        previewHeight := Round((imgHeight / imgWidth) * previewWidth)
        
        ; 限制最大高度
        maxHeight := 600
        if (previewHeight > maxHeight) {
            previewHeight := maxHeight
            previewWidth := Round((imgWidth / imgHeight) * previewHeight)
        }
        
        ; 3. 计算显示坐标（修复：确保坐标变量被正确赋值）
        ; 获取主窗口位置，将预览窗放在主窗口右侧
        GuiID_ClipboardHistory.GetPos(&mainX, &mainY, &mainW, &mainH)
        targetX := mainX + mainW + 10  ; 右偏移 10 像素
        targetY := mainY  ; 与主窗口顶部对齐
        
        ; 屏幕边界检测
        MonitorGetWorkArea(1, &screenLeft, &screenTop, &screenRight, &screenBottom)
        if (targetX + previewWidth > screenRight) {
            ; 如果右侧空间不足，显示在左侧
            targetX := mainX - previewWidth - 10
            if (targetX < screenLeft) {
                ; 如果左侧也放不下，使用屏幕中心
                targetX := screenLeft + (screenRight - screenLeft - previewWidth) // 2
            }
        }
        
        ; 确保 Y 坐标在屏幕内
        if (targetY + previewHeight > screenBottom) {
            targetY := screenBottom - previewHeight - 10
        }
        if (targetY < screenTop) {
            targetY := screenTop + 10
        }
        
        OutputDebug("ClipboardHistoryPanel: 计算坐标完成 - targetX=" . targetX . ", targetY=" . targetY . ", previewWidth=" . previewWidth . ", previewHeight=" . previewHeight . "`n")
        
        ; 4. 销毁旧窗口（如果存在）
        if (HistoryImagePreviewGUI != 0) {
            try {
                HistoryImagePreviewGUI.Destroy()
            } catch {
            }
            HistoryImagePreviewGUI := 0
        }
        
        ; 5. 创建预览窗口（无标题栏，置顶，带边框）
        HistoryImagePreviewGUI := Gui("+AlwaysOnTop -Caption +ToolWindow +Border", "")
        HistoryImagePreviewGUI.BackColor := HistoryColors.Background
        
        ; 添加图片控件（使用实际解析后的路径）
        picCtrl := HistoryImagePreviewGUI.Add("Picture", "x0 y0 w" . previewWidth . " h" . previewHeight . " vPreviewPic", actualImagePath)
        
        ; 存储图片路径到全局变量（用于比较和右键菜单）
        HistoryImagePreviewCurrentPath := actualImagePath
        
        ; 为窗口添加右键菜单事件
        HistoryImagePreviewGUI.OnEvent("ContextMenu", OnImagePreviewContextMenu)
        
        ; 添加关闭事件（按ESC关闭）
        HistoryImagePreviewGUI.OnEvent("Escape", HideHistoryImagePreview)
        
        ; 6. 显示窗口（修复：使用正确计算的坐标变量）
        OutputDebug("ClipboardHistoryPanel: 显示预览窗口，位置 x=" . targetX . ", y=" . targetY . "`n")
        HistoryImagePreviewGUI.Show("x" . targetX . " y" . targetY . " w" . previewWidth . " h" . previewHeight . " NoActivate")
        HistoryImagePreviewIsVisible := true
        OutputDebug("ClipboardHistoryPanel: 预览窗口显示成功`n")
        
    } catch as err {
        ; 预览失败，输出错误信息
        OutputDebug("ClipboardHistoryPanel: 预览失败 - " . err.Message . ", File: " . (err.HasProp("File") ? err.File : "未知") . ", Line: " . (err.HasProp("Line") ? err.Line : "未知") . "`n")
        HistoryImagePreviewGUI := 0
        HistoryImagePreviewIsVisible := false
    }
}

; ===================== ListView 双击事件 =====================
; ===================== ListView 列点击事件（排序）=====================
OnHistoryColumnClick(LV, ColumnNumber) {
    global HistoryDisplayCache, HistoryListView
    
    ; 如果点击的是序号列（第1列），按图标排序
    if (ColumnNumber = 1) {
        ; 按图标路径排序，相同图标的数据排列在一起
        ; 获取所有行的图标路径
        iconPaths := Map()
        for index, rowData in HistoryDisplayCache {
            iconPath := GetIconPathForRow(rowData)
            if (!iconPaths.Has(iconPath)) {
                iconPaths[iconPath] := []
            }
            iconPaths[iconPath].Push(index)
        }
        
        ; 重新排序：按图标路径分组
        sortedResults := []
        for iconPath, indices in iconPaths {
            for index in indices {
                sortedResults.Push(HistoryDisplayCache[index])
            }
        }
        
        ; 更新缓存
        HistoryDisplayCache := sortedResults
        
        ; 刷新 ListView
        RefreshHistoryListView()
    }
}

; ===================== 刷新 ListView 显示 =====================
RefreshHistoryListView() {
    global HistoryListView, HistoryDisplayCache
    
    if (!HistoryListView || HistoryDisplayCache.Length = 0) {
        return
    }
    
    ; 暂停重绘以提高性能
    HistoryListView.Opt("-Redraw")
    
    ; 清空列表
    HistoryListView.Delete()
    
    ; 添加数据（复用 RefreshHistoryData 中的显示逻辑）
    for index, rowData in HistoryDisplayCache {
        ; 获取内容预览
        dataType := rowData.Has("DataType") ? rowData["DataType"] : "Text"
        preview := rowData.Has("Content") ? rowData["Content"] : ""
        
        ; 如果是图片类型，显示图片文件名
        if (dataType = "Image") {
            imagePath := rowData.Has("ImagePath") ? rowData["ImagePath"] : preview
            if (imagePath != "" && FileExist(imagePath)) {
                try {
                    SplitPath(imagePath, &fileName)
                    preview := "[图片] " . fileName
                } catch {
                    preview := "[图片] " . imagePath
                }
            } else {
                preview := "[图片]"
            }
        } else {
            if (preview = "") {
                preview := "(空内容)"
            } else {
                if (StrLen(preview) > 80) {
                    preview := SubStr(preview, 1, 80) . "..."
                }
                preview := StrReplace(preview, "`r`n", " ")
                preview := StrReplace(preview, "`n", " ")
                preview := StrReplace(preview, "`r", " ")
            }
        }
        
        ; 格式化时间
        try {
            lastCopyTime := rowData.Has("LastCopyTime") && rowData["LastCopyTime"] != "" ? rowData["LastCopyTime"] : rowData["Timestamp"]
            timeText := FormatTime(lastCopyTime, "yyyy-MM-dd HH:mm:ss")
        } catch {
            timeText := rowData.Has("LastCopyTime") ? rowData["LastCopyTime"] : rowData["Timestamp"]
        }
        
        ; 获取其他字段
        sourceApp := rowData.Has("SourceApp") && rowData["SourceApp"] != "" ? String(rowData["SourceApp"]) : "Unknown"
        dataType := rowData.Has("DataType") && rowData["DataType"] != "" ? String(rowData["DataType"]) : "Text"
        
        ; 获取文件位置
        fileLocation := ""
        if (rowData.Has("SourcePath") && rowData["SourcePath"] != "") {
            SplitPath(rowData["SourcePath"], &fileName)
            fileLocation := fileName
        } else if (rowData.Has("Content") && rowData["Content"] != "") {
            content := rowData["Content"]
            if (InStr(content, "\") || InStr(content, "/")) {
                SplitPath(content, &fileName)
                fileLocation := fileName
            }
        }
        
        ; 获取文件后缀
        fileExtension := ""
        if (rowData.Has("Content") && rowData["Content"] != "") {
            content := rowData["Content"]
            if (InStr(content, ".")) {
                SplitPath(content, , , &ext)
                fileExtension := ext
            }
        }
        
        ; 获取文件大小
        fileSize := ""
        if (rowData.Has("CharCount")) {
            fileSize := FormatBytes(rowData["CharCount"])
        }
        
        ; 获取复制次数
        copyCount := rowData.Has("CopyCount") ? String(rowData["CopyCount"]) : "1"
        
        ; 获取字符数
        charCount := rowData.Has("CharCount") ? String(rowData["CharCount"]) : "0"
        
        ; 获取图标索引
        iconIndex := GetFileIconIndex(GetIconPathForRow(rowData), rowData)
        iconOption := iconIndex > 0 ? "Icon" . iconIndex : ""
        
        ; 添加到 ListView
        HistoryListView.Add(iconOption,
            String(index),
            String(preview),
            String(sourceApp),
            String(fileLocation),
            String(dataType),
            String(fileExtension),
            String(fileSize),
            String(timeText),
            String(copyCount),
            String(charCount))
    }
    
    ; 恢复重绘
    HistoryListView.Opt("+Redraw")
}

; ===================== 格式化字节数 =====================
FormatBytes(bytes) {
    if (bytes < 1024) {
        return bytes . " B"
    } else if (bytes < 1048576) {
        return Round(bytes / 1024, 2) . " KB"
    } else {
        return Round(bytes / 1048576, 2) . " MB"
    }
}

; ===================== 获取行的图标路径 =====================
GetIconPathForRow(rowData) {
    ; 优先使用 SourcePath，然后是 IconPath，最后是 Content
    if (rowData.Has("SourcePath") && rowData["SourcePath"] != "") {
        return rowData["SourcePath"]
    }
    if (rowData.Has("IconPath") && rowData["IconPath"] != "") {
        return rowData["IconPath"]
    }
    if (rowData.Has("Content") && rowData["Content"] != "") {
        content := rowData["Content"]
        ; 如果是文件路径，返回路径
        if (InStr(content, "\") || InStr(content, "/")) {
            return content
        }
    }
    return ""
}

; ===================== ListView 右键菜单事件 =====================
OnHistoryListViewContextMenu(LV, Item, IsRightClick, X, Y) {
    global HistoryListView, HistoryDisplayCache
    
    ; 获取选中的行（支持多选）
    selectedRows := []
    row := 0
    Loop {
        row := HistoryListView.GetNext(row, "Checked")
        if (row = 0) {
            break
        }
        selectedRows.Push(row)
    }
    
    ; 如果没有选中任何行，选中当前右键点击的行
    if (selectedRows.Length = 0 && Item > 0) {
        selectedRows.Push(Item)
    }
    
    ; 如果没有选中任何行，不显示菜单
    if (selectedRows.Length = 0) {
        return
    }
    
    ; 创建右键菜单
    contextMenu := Menu()
    contextMenu.Add("复制", HistoryContextMenuCopy)
    contextMenu.Add("粘贴", HistoryContextMenuPaste)
    contextMenu.Add("删除", HistoryContextMenuDelete)
    contextMenu.Add("添加到提示词", HistoryContextMenuAddToPrompt)
    
    ; 显示菜单
    contextMenu.Show(X, Y)
}

; ===================== 右键菜单：复制 =====================
HistoryContextMenuCopy(*) {
    global HistoryListView, HistoryDisplayCache
    
    ; 获取选中的行
    selectedRows := []
    row := 0
    Loop {
        row := HistoryListView.GetNext(row, "Checked")
        if (row = 0) {
            break
        }
        selectedRows.Push(row)
    }
    
    if (selectedRows.Length = 0) {
        return
    }
    
    ; 复制第一个选中的项
    if (selectedRows[1] > 0 && selectedRows[1] <= HistoryDisplayCache.Length) {
        rowData := HistoryDisplayCache[selectedRows[1]]
        if (rowData.Has("Content") && rowData["Content"] != "") {
            A_Clipboard := rowData["Content"]
            TrayTip("已复制", "内容已复制到剪贴板", "Iconi 1")
        }
    }
}

; ===================== 右键菜单：粘贴 =====================
HistoryContextMenuPaste(*) {
    global HistoryListView, HistoryDisplayCache
    
    ; 获取选中的行
    selectedRows := []
    row := 0
    Loop {
        row := HistoryListView.GetNext(row, "Checked")
        if (row = 0) {
            break
        }
        selectedRows.Push(row)
    }
    
    if (selectedRows.Length = 0) {
        return
    }
    
    ; 粘贴第一个选中的项
    if (selectedRows[1] > 0 && selectedRows[1] <= HistoryDisplayCache.Length) {
        rowData := HistoryDisplayCache[selectedRows[1]]
        if (rowData.Has("Content") && rowData["Content"] != "") {
            A_Clipboard := rowData["Content"]
            Sleep(50)
            Send("^v")
            TrayTip("已粘贴", "内容已粘贴到 Cursor", "Iconi 1")
        }
    }
}

; ===================== 右键菜单：删除 =====================
HistoryContextMenuDelete(*) {
    global HistoryListView, HistoryDisplayCache, ClipboardFTS5DB
    
    ; 获取选中的行
    selectedRows := []
    row := 0
    Loop {
        row := HistoryListView.GetNext(row, "Checked")
        if (row = 0) {
            break
        }
        selectedRows.Push(row)
    }
    
    if (selectedRows.Length = 0) {
        return
    }
    
    ; 确认删除
    if (MsgBox("确定要删除选中的 " . selectedRows.Length . " 项吗？", "确认删除", "YesNo IconQuestion") != "Yes") {
        return
    }
    
    ; 删除选中的项
    deletedCount := 0
    for index, rowNum in selectedRows {
        if (rowNum > 0 && rowNum <= HistoryDisplayCache.Length) {
            rowData := HistoryDisplayCache[rowNum]
            if (rowData.Has("ID") && rowData["ID"] != "") {
                try {
                    SQL := "DELETE FROM ClipMain WHERE ID = " . rowData["ID"]
                    if (ClipboardFTS5DB.Exec(SQL)) {
                        deletedCount++
                    }
                } catch as err {
                    ; 忽略错误，继续删除下一项
                }
            }
        }
    }
    
    if (deletedCount > 0) {
        TrayTip("已删除", "成功删除 " . deletedCount . " 项", "Iconi 1")
        RefreshHistoryData()
    }
}

; ===================== 右键菜单：添加到提示词 =====================
HistoryContextMenuAddToPrompt(*) {
    global HistoryListView, HistoryDisplayCache
    
    ; 获取选中的行
    selectedRows := []
    row := 0
    Loop {
        row := HistoryListView.GetNext(row, "Checked")
        if (row = 0) {
            break
        }
        selectedRows.Push(row)
    }
    
    if (selectedRows.Length = 0) {
        return
    }
    
    ; 收集所有选中项的内容
    contents := []
    for index, rowNum in selectedRows {
        if (rowNum > 0 && rowNum <= HistoryDisplayCache.Length) {
            rowData := HistoryDisplayCache[rowNum]
            if (rowData.Has("Content") && rowData["Content"] != "") {
                contents.Push(rowData["Content"])
            }
        }
    }
    
    if (contents.Length = 0) {
        return
    }
    
    ; 合并内容（用换行符分隔）
    combinedContent := ""
    for index, content in contents {
        if (index > 1) {
            combinedContent .= "`n"
        }
        combinedContent .= content
    }
    
    ; 复制到剪贴板，用户可以手动添加到提示词
    A_Clipboard := combinedContent
    TrayTip("已复制", "内容已复制到剪贴板，可以添加到提示词模板", "Iconi 1")
}

OnHistoryItemDoubleClick(*) {
    global HistoryListView, HistoryDisplayCache

    selectedRow := HistoryListView.GetNext()
    if (selectedRow > 0 && selectedRow <= HistoryDisplayCache.Length) {
        rowData := HistoryDisplayCache[selectedRow]
        
        ; 获取数据类型
        dataType := rowData.Has("DataType") ? rowData["DataType"] : "Text"
        
        ; 获取图片路径（优先使用 ImagePath，如果没有则使用 Content）
        imagePath := ""
        if (rowData.Has("ImagePath") && rowData["ImagePath"] != "") {
            imagePath := rowData["ImagePath"]
        } else if (rowData.Has("Content") && rowData["Content"] != "") {
            ; 检查 Content 是否是图片路径
            content := rowData["Content"]
            ; 如果 Content 是文件路径且文件存在，则使用它（不限制数据类型，因为可能是旧数据）
            if (FileExist(content)) {
                ; 检查文件扩展名，确认是图片文件
                SplitPath(content, , , &ext)
                ext := StrLower(ext)
                if (ext = "png" || ext = "jpg" || ext = "jpeg" || ext = "gif" || ext = "bmp" || ext = "webp" || ext = "tiff" || ext = "ico") {
                    imagePath := content
                    ; 如果数据类型不是 Image，但文件是图片，也当作图片处理
                    if (dataType != "Image") {
                        dataType := "Image"
                    }
                }
            }
        }
        
        ; 如果有有效的图片路径，尝试复制图片到剪贴板
        if (imagePath != "" && FileExist(imagePath)) {
            ; 先清空剪贴板，避免文本和图片同时存在
            A_Clipboard := ""
            Sleep(100)  ; 等待剪贴板清空
            
            try {
                ; 确保 GDI+ 已初始化
                if (HistoryGdiplusToken = 0) {
                    InitGdiplus()
                }
                
                ; 解析图片路径
                actualImagePath := ResolveImagePath(imagePath)
                if (actualImagePath = "" || !FileExist(actualImagePath)) {
                    throw Error("图片路径无效")
                }
                
                ; 使用 GDI+ 加载图片
                pBitmap := Gdip_CreateBitmapFromFile(actualImagePath)
                if (!pBitmap || pBitmap = 0) {
                    ; 回退到 ImagePut
                    pBitmap := ImagePut("Bitmap", actualImagePath)
                    if (!pBitmap || pBitmap = "") {
                        throw Error("无法加载图片")
                    }
                    ; 使用 ImagePut 时，使用 Gdip_SetBitmapToClipboard
                    Gdip_SetBitmapToClipboard(pBitmap)
                    ImageDestroy(pBitmap)
                } else {
                    ; 使用 GDI+ 时，使用 Gdip_SetBitmapToClipboard
                    Gdip_SetBitmapToClipboard(pBitmap)
                    Gdip_DisposeImage(pBitmap)
                }
                
                ; 验证图片是否成功复制到剪贴板（检查剪贴板是否有图片格式）
                Sleep(50)
                if (DllCall("IsClipboardFormatAvailable", "UInt", 8)) {  ; CF_DIB = 8
                    TrayTip("已复制", "图片已复制到剪贴板", "Iconi 1")
                    ; 刷新数据（将刚复制的项移到最前面）
                    RefreshHistoryData()
                    return  ; 成功复制图片，直接返回
                } else {
                    ; 图片复制失败，回退到文本复制
                    TrayTip("警告", "图片复制失败，已复制路径文本", "Iconx 1")
                }
            } catch as err {
                ; 图片复制异常，回退到文本复制
                TrayTip("警告", "复制图片失败: " . err.Message . "，已复制路径文本", "Iconx 1")
            }
        }
        
        ; 如果不是图片类型，或者图片路径无效，或者图片复制失败，则复制文本内容
        if (rowData.Has("Content") && rowData["Content"] != "") {
            A_Clipboard := rowData["Content"]
            if (imagePath = "" || !FileExist(imagePath)) {
                TrayTip("已复制", "内容已复制到剪贴板", "Iconi 1")
            }
            
            ; 刷新数据（将刚复制的项移到最前面）
            RefreshHistoryData()
        }
    }
}

; ===================== 窗口大小改变事件 =====================
OnHistoryPanelSize(*) {
    global GuiID_ClipboardHistory, HistoryListView, HistorySearchEdit, HistoryTagButtons, HistoryStatusBarText, HistoryBottomArea
    global HistoryCopyBtn, HistoryDeleteBtn, HistoryPasteBtn, HistoryClearAllBtn, HistoryExportBtn, HistoryImportBtn
    global HistoryResultLimitDropdown
    
    ; 获取窗口大小
    GuiID_ClipboardHistory.GetPos(,, &width, &height)
    
    ; 调整下拉菜单和搜索框位置
    DropdownWidth := 80
    DropdownX := 10
    SearchBoxX := DropdownX + DropdownWidth + 10
    SearchBoxWidth := width - SearchBoxX - 10
    
    if (HistoryResultLimitDropdown && IsObject(HistoryResultLimitDropdown)) {
        ; 下拉菜单位置不变，只调整搜索框
    }
    
    ; 调整搜索框位置和宽度
    if (HistorySearchEdit && IsObject(HistorySearchEdit)) {
        HistorySearchEdit.Move(SearchBoxX,, SearchBoxWidth)
    }
    
    ; 调整标签按钮位置（如果需要的话，可以保持左对齐）
    ; 标签按钮保持原位置，不随窗口大小改变
    
    ; 计算底部区域位置和大小
    BottomAreaHeight := 70
    StatusBarHeight := 20
    ListViewY := 90
    ListViewHeight := height - ListViewY - BottomAreaHeight - StatusBarHeight
    
    ; 计算底部区域Y位置（必须在条件块外，确保变量总是被赋值）
    bottomAreaY := ListViewY + ListViewHeight
    
    ; 调整 ListView 宽度和高度
    HistoryListView.Move(,, width - 20, ListViewHeight)
    
    ; 调整底部背景区域位置和大小
    if (HistoryBottomArea && IsObject(HistoryBottomArea)) {
        HistoryBottomArea.Move(, bottomAreaY, width, BottomAreaHeight)
    }
    
    ; 调整按钮位置（自适应窗口宽度）
    ButtonHeight := 30
    ButtonWidth := 100
    ButtonSpacing := 10
    ButtonPadding := 10
    
    ; 计算按钮起始位置（保持左对齐）
    StartX := ButtonPadding
    ButtonY := bottomAreaY + 10
    
    ; 调整所有按钮位置
    if (HistoryCopyBtn && IsObject(HistoryCopyBtn)) {
        HistoryCopyBtn.Move(StartX, ButtonY)
    }
    if (HistoryDeleteBtn && IsObject(HistoryDeleteBtn)) {
        HistoryDeleteBtn.Move(StartX + ButtonWidth + ButtonSpacing, ButtonY)
    }
    if (HistoryPasteBtn && IsObject(HistoryPasteBtn)) {
        HistoryPasteBtn.Move(StartX + (ButtonWidth + ButtonSpacing) * 2, ButtonY)
    }
    if (HistoryClearAllBtn && IsObject(HistoryClearAllBtn)) {
        HistoryClearAllBtn.Move(StartX + (ButtonWidth + ButtonSpacing) * 3 + 20, ButtonY)
    }
    if (HistoryExportBtn && IsObject(HistoryExportBtn)) {
        HistoryExportBtn.Move(StartX + (ButtonWidth + ButtonSpacing) * 4 + 20, ButtonY)
    }
    if (HistoryImportBtn && IsObject(HistoryImportBtn)) {
        HistoryImportBtn.Move(StartX + (ButtonWidth + ButtonSpacing) * 5 + 20, ButtonY)
    }
    
    ; 调整状态栏宽度和位置
    if (HistoryStatusBarText) {
        ; 计算状态栏的Y位置（底部按钮区域下方）
        statusBarY := height - 25
        HistoryStatusBarText.Move(, statusBarY, width - 20)
    }
}

; ===================== 窗口关闭事件 =====================
OnHistoryPanelClose(*) {
    HideClipboardHistoryPanel()
}

; ===================== 颜色汇总面板 =====================
; 显示颜色汇总面板（当点击颜色标签时）
ShowColorSummaryPanel() {
    global ColorSummaryGUI, ColorSummaryIsVisible, GuiID_ClipboardHistory, HistoryDisplayCache
    
    if (ColorSummaryIsVisible && ColorSummaryGUI != 0) {
        ; 如果已显示，刷新数据
        RefreshColorSummaryPanel()
        return
    }
    
    ; 获取主窗口位置
    if (GuiID_ClipboardHistory = 0) {
        return
    }
    
    GuiID_ClipboardHistory.GetPos(&mainX, &mainY, &mainW, &mainH)
    
    ; 创建颜色汇总面板
    ColorSummaryGUI := Gui("+AlwaysOnTop -Caption +ToolWindow", "颜色汇总")
    ColorSummaryGUI.BackColor := HistoryColors.Background
    ColorSummaryGUI.SetFont("s10 c" . HistoryColors.Text, "Segoe UI")
    
    ; 获取所有颜色数据
    colorData := GetColorData()
    
    if (colorData.Length = 0) {
        ; 如果没有颜色数据，显示提示
        ColorSummaryGUI.Add("Text", "x10 y10 w200 h30 c" . HistoryColors.TextDim, "暂无颜色数据")
        ColorSummaryGUI.Show("x" . (mainX + mainW + 10) . " y" . mainY . " w220 h50")
        ColorSummaryIsVisible := true
        return
    }
    
    ; 创建滚动区域
    scrollY := 10
    blockSize := 40
    blockSpacing := 10
    blocksPerRow := 8
    rowHeight := blockSize + blockSpacing
    
    ; 创建颜色块
    for index, colorItem in colorData {
        row := (index - 1) // blocksPerRow
        col := Mod(index - 1, blocksPerRow)
        
        x := 10 + col * (blockSize + blockSpacing)
        y := scrollY + row * rowHeight
        
        ; 创建颜色块按钮（去掉 # 号，因为 Background 选项不接受 #）
        hexColor := StrReplace(colorItem["hex"], "#", "")
        colorBtn := ColorSummaryGUI.Add("Button", 
            "x" . x . " y" . y . 
            " w" . blockSize . " h" . blockSize . 
            " Background" . hexColor . 
            " -Theme vColorBtn_" . index, "")
        
        ; 设置按钮点击事件
        colorBtn.OnEvent("Click", OnColorBlockClick.Bind(colorItem["value"]))
    }
    
    ; 计算面板大小
    totalRows := Ceil(colorData.Length / blocksPerRow)
    panelWidth := 10 + blocksPerRow * (blockSize + blockSpacing)
    panelHeight := scrollY + totalRows * rowHeight + 10
    
    ; 限制最大高度
    maxHeight := 600
    if (panelHeight > maxHeight) {
        panelHeight := maxHeight
    }
    
    ; 显示面板（在主窗口右侧）
    ColorSummaryGUI.Show("x" . (mainX + mainW + 10) . " y" . mainY . " w" . panelWidth . " h" . panelHeight)
    ColorSummaryIsVisible := true
}

; ===================== 隐藏颜色汇总面板 =====================
HideColorSummaryPanel() {
    global ColorSummaryGUI, ColorSummaryIsVisible
    
    if (ColorSummaryGUI != 0) {
        try {
            ColorSummaryGUI.Hide()
            ColorSummaryIsVisible := false
        } catch {
        }
    }
}

; ===================== 获取颜色数据 =====================
GetColorData() {
    global HistoryDisplayCache
    
    colorData := []
    
    ; 从当前显示缓存中获取颜色数据
    for index, rowData in HistoryDisplayCache {
        if (rowData.Has("DataType") && rowData["DataType"] = "Color") {
            colorValue := Trim(rowData["Content"], " `t`r`n")
            hexValue := ParseColorValue(colorValue)
            
            if (hexValue != "") {
                ; 转换为显示用的格式（去掉0x前缀）
                displayHex := StrReplace(hexValue, "0x", "#")
                colorData.Push(Map("value", colorValue, "hex", displayHex))
            }
        }
    }
    
    ; 去重（相同颜色值只显示一次）
    uniqueColors := Map()
    uniqueData := []
    for index, item in colorData {
        if (!uniqueColors.Has(item["value"])) {
            uniqueColors[item["value"]] := true
            uniqueData.Push(item)
        }
    }
    
    return uniqueData
}

; ===================== 刷新颜色汇总面板 =====================
RefreshColorSummaryPanel() {
    global ColorSummaryGUI, ColorSummaryIsVisible
    
    if (ColorSummaryIsVisible && ColorSummaryGUI != 0) {
        try {
            ColorSummaryGUI.Destroy()
        } catch {
        }
        ColorSummaryGUI := 0
        ColorSummaryIsVisible := false
        ShowColorSummaryPanel()
    }
}

; ===================== 颜色块点击事件 =====================
OnColorBlockClick(colorValue, *) {
    ; 复制颜色值到剪贴板
    A_Clipboard := colorValue
    TrayTip("已复制", "颜色值已复制: " . colorValue, "Iconi 1")
}

; ===================== 解析颜色值 =====================
; 将各种颜色格式转换为RGB值（用于显示色块）
ParseColorValue(colorStr) {
    if (colorStr = "" || StrLen(colorStr) = 0) {
        return ""
    }
    
    trimmed := Trim(colorStr, " `t`r`n")
    
    ; 1. 处理 #RRGGBB 或 #RGB 格式
    if (RegExMatch(trimmed, "i)^#([0-9A-Fa-f]{3,8})$", &match)) {
        hex := match[1]
        if (StrLen(hex) = 3) {
            ; #RGB -> #RRGGBB
            r := SubStr(hex, 1, 1) . SubStr(hex, 1, 1)
            g := SubStr(hex, 2, 1) . SubStr(hex, 2, 1)
            b := SubStr(hex, 3, 1) . SubStr(hex, 3, 1)
            return "0x" . r . g . b
        } else if (StrLen(hex) = 6) {
            return "0x" . hex
        } else if (StrLen(hex) = 8) {
            ; #RRGGBBAA -> 取前6位
            return "0x" . SubStr(hex, 1, 6)
        }
    }
    
    ; 2. 处理 rgb(r, g, b) 或 rgba(r, g, b, a) 格式
    if (RegExMatch(trimmed, "i)^rgba?\(([^)]+)\)$", &match)) {
        values := StrSplit(match[1], ",")
        if (values.Length >= 3) {
            r := Integer(Trim(values[1]))
            g := Integer(Trim(values[2]))
            b := Integer(Trim(values[3]))
            ; 转换为十六进制
            rHex := Format("{:02X}", r)
            gHex := Format("{:02X}", g)
            bHex := Format("{:02X}", b)
            return "0x" . rHex . gHex . bHex
        }
    }
    
    ; 3. 处理不带#号的6位或8位十六进制
    if (RegExMatch(trimmed, "i)^([0-9A-Fa-f]{6})$")) {
        return "0x" . trimmed
    }
    if (RegExMatch(trimmed, "i)^([0-9A-Fa-f]{8})$", &match)) {
        return "0x" . SubStr(match[1], 1, 6)
    }
    
    ; 4. 处理RGB十进制格式：(255, 255, 255)
    if (RegExMatch(trimmed, "i)^\(?\s*(\d{1,3})\s*,\s*(\d{1,3})\s*,\s*(\d{1,3})\s*\)?$", &match)) {
        r := Integer(match[1])
        g := Integer(match[2])
        b := Integer(match[3])
        rHex := Format("{:02X}", r)
        gHex := Format("{:02X}", g)
        bHex := Format("{:02X}", b)
        return "0x" . rHex . gHex . bHex
    }
    
    return ""
}


; ===================== 延迟显示图片预览（防抖回调）=====================
ShowHistoryImagePreviewDelayed(*) {
    global HistoryImagePreviewCurrentPath, GuiID_ClipboardHistory
    
    if (HistoryImagePreviewCurrentPath = "") {
        return
    }
    
    ; 1. 读取磁盘路径（已在 HistoryImagePreviewCurrentPath 中）
    ; 处理路径中的转义字符
    imagePath := HistoryImagePreviewCurrentPath
    imagePath := StrReplace(imagePath, "\\\\", "\")
    imagePath := StrReplace(imagePath, "\\", "\")
    
    if (!FileExist(imagePath)) {
        ; 如果文件不存在，尝试调试输出
        ; OutputDebug("ClipboardHistoryPanel: 图片文件不存在 - " . imagePath . "`n")
        return
    }
    
    ; 2. 使用 GDI+ 解析图片尺寸
    try {
        ; 确保 GDI+ 已初始化
        if (HistoryGdiplusToken = 0) {
            InitGdiplus()
        }
        
        ; 解析图片路径
        actualImagePath := ResolveImagePath(imagePath)
        if (actualImagePath = "" || !FileExist(actualImagePath)) {
            return
        }
        
        ; 使用 GDI+ 加载图片
        pBitmap := Gdip_CreateBitmapFromFile(actualImagePath)
        if (!pBitmap || pBitmap = 0) {
            ; 回退到 ImagePut
            pBitmap := ImagePut("Bitmap", actualImagePath)
            if (!pBitmap || pBitmap = "") {
                return
            }
            dims := ImageDimensions(pBitmap)
            imgWidth := dims[1]
            imgHeight := dims[2]
            ImageDestroy(pBitmap)
        } else {
            ; 使用 GDI+ 获取尺寸
            Gdip_GetImageDimensions(pBitmap, &imgWidth, &imgHeight)
            Gdip_DisposeImage(pBitmap)
        }
        
        if (imgWidth <= 0 || imgHeight <= 0) {
            return
        }
        
        ; 3. 计算主窗侧边坐标
        if (GuiID_ClipboardHistory = 0) {
            return
        }
        
        ; 获取主窗口位置和大小
        GuiID_ClipboardHistory.GetPos(&mainX, &mainY, &mainW, &mainH)
        
        ; 限制预览窗口最大尺寸（800x600）
        maxWidth := 800
        maxHeight := 600
        
        if (imgWidth > maxWidth || imgHeight > maxHeight) {
            scale := Min(maxWidth / imgWidth, maxHeight / imgHeight)
            previewWidth := Round(imgWidth * scale)
            previewHeight := Round(imgHeight * scale)
        } else {
            previewWidth := imgWidth
            previewHeight := imgHeight
        }
        
        ; 计算预览窗口位置（主窗口右侧，垂直居中）
        spacing := 10  ; 主窗口和预览窗口之间的间距
        previewX := mainX + mainW + spacing
        previewY := mainY + (mainH - previewHeight) // 2
        
        ; 确保预览窗口不超出屏幕
        MonitorGetWorkArea(, &screenLeft, &screenTop, &screenRight, &screenBottom)
        if (previewX + previewWidth > screenRight) {
            ; 如果右侧放不下，放在左侧
            previewX := mainX - previewWidth - spacing
            if (previewX < screenLeft) {
                ; 如果左侧也放不下，放在主窗口上方
                previewX := mainX + (mainW - previewWidth) // 2
                previewY := mainY - previewHeight - spacing
                if (previewY < screenTop) {
                    ; 如果上方也放不下，放在主窗口下方
                    previewY := mainY + mainH + spacing
                }
            }
        }
        
        if (previewY + previewHeight > screenBottom) {
            previewY := screenBottom - previewHeight - 10
        }
        if (previewY < screenTop) {
            previewY := screenTop + 10
        }
        
        ; 4. 弹出无标题栏置顶窗口
        ShowHistoryImagePreview(imagePath, previewX, previewY, previewWidth, previewHeight)
        
    } catch as err {
        ; 预览失败，静默处理
    }
}

; ===================== 显示图片预览窗口（无标题栏，置顶）=====================
ShowHistoryImagePreview(imagePath, x := 0, y := 0, width := 0, height := 0) {
    global HistoryImagePreviewGUI, HistoryImagePreviewIsVisible, HistoryColors
    
    OutputDebug("ClipboardHistoryPanel: ShowHistoryImagePreview 被调用，imagePath=" . imagePath . ", x=" . x . ", y=" . y . ", width=" . width . ", height=" . height . "`n")
    
    ; 如果预览窗口已存在且显示的是同一张图片，只更新位置
    if (HistoryImagePreviewIsVisible && HistoryImagePreviewGUI != 0) {
        try {
            ; 检查当前显示的图片路径（使用全局变量）
            currentPath := HistoryImagePreviewCurrentPath
            if (currentPath = imagePath) {
                ; 更新位置和大小
                OutputDebug("ClipboardHistoryPanel: 更新现有预览窗口位置`n")
                HistoryImagePreviewGUI.Show("x" . x . " y" . y . " w" . width . " h" . height . " NoActivate")
                return
            } else {
                ; 图片不同，销毁旧窗口
                OutputDebug("ClipboardHistoryPanel: 销毁旧预览窗口，创建新窗口`n")
                HistoryImagePreviewGUI.Destroy()
                HistoryImagePreviewGUI := 0
            }
        } catch as err {
            OutputDebug("ClipboardHistoryPanel: 处理现有窗口时出错 - " . err.Message . "`n")
            HistoryImagePreviewGUI := 0
        }
    }
    
    try {
        ; 如果未提供尺寸，读取图片尺寸
        if (width <= 0 || height <= 0) {
            OutputDebug("ClipboardHistoryPanel: 未提供尺寸，读取图片尺寸`n")
            
            ; 确保 GDI+ 已初始化
            if (HistoryGdiplusToken = 0) {
                InitGdiplus()
            }
            
            ; 解析图片路径
            actualImagePath := ResolveImagePath(imagePath)
            if (actualImagePath = "" || !FileExist(actualImagePath)) {
                OutputDebug("ClipboardHistoryPanel: 图片路径无效`n")
                return
            }
            
            ; 使用 GDI+ 加载图片
            pBitmap := Gdip_CreateBitmapFromFile(actualImagePath)
            if (!pBitmap || pBitmap = 0) {
                ; 回退到 ImagePut
                pBitmap := ImagePut("Bitmap", actualImagePath)
                if (!pBitmap || pBitmap = "") {
                    OutputDebug("ClipboardHistoryPanel: 无法加载图片位图`n")
                    return
                }
                dims := ImageDimensions(pBitmap)
                imgWidth := dims[1]
                imgHeight := dims[2]
                ImageDestroy(pBitmap)
            } else {
                ; 使用 GDI+ 获取尺寸
                Gdip_GetImageDimensions(pBitmap, &imgWidth, &imgHeight)
                Gdip_DisposeImage(pBitmap)
            }
            
            OutputDebug("ClipboardHistoryPanel: 图片尺寸 - width=" . imgWidth . ", height=" . imgHeight . "`n")
            
            ; 限制预览窗口最大尺寸（800x600）
            maxWidth := 800
            maxHeight := 600
            
            if (imgWidth > maxWidth || imgHeight > maxHeight) {
                scale := Min(maxWidth / imgWidth, maxHeight / imgHeight)
                width := Round(imgWidth * scale)
                height := Round(imgHeight * scale)
            } else {
                width := imgWidth
                height := imgHeight
            }
        }
        
        OutputDebug("ClipboardHistoryPanel: 创建预览窗口，尺寸 - width=" . width . ", height=" . height . "`n")
        
        ; 创建预览窗口（无标题栏，置顶）
        HistoryImagePreviewGUI := Gui("+AlwaysOnTop -Caption +ToolWindow", "")
        HistoryImagePreviewGUI.BackColor := HistoryColors.Background
        
        ; 创建图片控件
        picCtrl := HistoryImagePreviewGUI.Add("Picture", "x0 y0 w" . width . " h" . height . " vPreviewPic", imagePath)
        
        ; 存储图片路径到全局变量（用于比较和右键菜单）
        HistoryImagePreviewCurrentPath := imagePath
        
        ; 为窗口添加右键菜单事件（Picture控件可能不支持ContextMenu，使用窗口级别）
        HistoryImagePreviewGUI.OnEvent("ContextMenu", OnImagePreviewContextMenu)
        
        ; 添加关闭事件（点击窗口外部或按ESC关闭）
        HistoryImagePreviewGUI.OnEvent("Escape", HideHistoryImagePreview)
        
        ; 确保坐标有效
        if (x <= 0 || y <= 0) {
            ; 如果坐标无效，使用屏幕中心
            MonitorGetWorkArea(1, &screenLeft, &screenTop, &screenRight, &screenBottom)
            x := screenLeft + (screenRight - screenLeft - width) // 2
            y := screenTop + (screenBottom - screenTop - height) // 2
            OutputDebug("ClipboardHistoryPanel: ShowHistoryImagePreview 坐标无效，使用屏幕中心 - x=" . x . ", y=" . y . "`n")
        }
        
        ; 显示窗口
        OutputDebug("ClipboardHistoryPanel: 显示预览窗口，位置 x=" . x . ", y=" . y . ", 大小 w=" . width . ", h=" . height . "`n")
        HistoryImagePreviewGUI.Show("x" . x . " y" . y . " w" . width . " h" . height . " NoActivate")
        HistoryImagePreviewIsVisible := true
        OutputDebug("ClipboardHistoryPanel: 预览窗口显示成功`n")
        
    } catch as err {
        ; 预览失败，输出错误信息
        OutputDebug("ClipboardHistoryPanel: 预览窗口创建失败 - " . err.Message . ", File: " . (err.HasProp("File") ? err.File : "未知") . ", Line: " . (err.HasProp("Line") ? err.Line : "未知") . "`n")
        HistoryImagePreviewGUI := 0
        HistoryImagePreviewIsVisible := false
    }
}

; ===================== 图片预览右键菜单事件 =====================
OnImagePreviewContextMenu(GuiObj, GuiCtrl, Item, IsRightClick, X, Y) {
    global HistoryImagePreviewGUI, HistoryImagePreviewCurrentPath
    
    if (!HistoryImagePreviewGUI || HistoryImagePreviewGUI = 0) {
        return
    }
    
    ; 获取当前图片路径（使用全局变量）
    imagePath := HistoryImagePreviewCurrentPath
    if (imagePath = "" || !FileExist(imagePath)) {
        return
    }
    
    ; 创建右键菜单
    contextMenu := Menu()
    contextMenu.Add("保存", OnImagePreviewSave)
    contextMenu.Add("跳转", OnImagePreviewOpenLocation)
    contextMenu.Add("提取文字", OnImagePreviewExtractText)
    contextMenu.Add("复制", OnImagePreviewCopy)
    contextMenu.Add()  ; 分隔线
    contextMenu.Add("关闭", OnImagePreviewClose)
    
    ; 显示菜单（使用屏幕坐标）
    contextMenu.Show(X, Y)
}

; ===================== 图片预览菜单功能 =====================
; 保存图片
OnImagePreviewSave(*) {
    global HistoryImagePreviewGUI, HistoryImagePreviewCurrentPath
    
    if (!HistoryImagePreviewGUI || HistoryImagePreviewGUI = 0) {
        return
    }
    
    imagePath := HistoryImagePreviewCurrentPath
    if (imagePath = "" || !FileExist(imagePath)) {
        TrayTip("错误", "图片路径无效", "Iconx 1")
        return
    }
    
    ; 获取原文件名和扩展名
    SplitPath(imagePath, &fileName, &fileDir, &fileExt, &fileBaseName)
    
    ; 显示保存文件对话框
    selectedFile := FileSelect("S16", fileDir, "保存图片", "图片文件 (*.png; *.jpg; *.jpeg; *.gif; *.bmp; *.webp; *.tiff; *.ico)")
    
    if (selectedFile = "") {
        return  ; 用户取消
    }
    
    try {
        ; 复制文件到新位置
        FileCopy(imagePath, selectedFile, 1)  ; 1 = 覆盖已存在的文件
        TrayTip("成功", "图片已保存: " . selectedFile, "Iconi 1")
    } catch as err {
        TrayTip("错误", "保存失败: " . err.Message, "Iconx 1")
    }
}

; 跳转到文件位置
OnImagePreviewOpenLocation(*) {
    global HistoryImagePreviewGUI, HistoryImagePreviewCurrentPath
    
    if (!HistoryImagePreviewGUI || HistoryImagePreviewGUI = 0) {
        return
    }
    
    imagePath := HistoryImagePreviewCurrentPath
    if (imagePath = "" || !FileExist(imagePath)) {
        TrayTip("错误", "图片路径无效", "Iconx 1")
        return
    }
    
    try {
        ; 获取文件所在目录
        SplitPath(imagePath, &fileName, &fileDir)
        
        ; 在资源管理器中打开并选中文件
        Run('explorer.exe /select,"' . imagePath . '"')
    } catch as err {
        TrayTip("错误", "打开文件位置失败: " . err.Message, "Iconx 1")
    }
}

; 提取文字（OCR）
OnImagePreviewExtractText(*) {
    global HistoryImagePreviewGUI, HistoryImagePreviewCurrentPath
    
    if (!HistoryImagePreviewGUI || HistoryImagePreviewGUI = 0) {
        return
    }
    
    imagePath := HistoryImagePreviewCurrentPath
    if (imagePath = "" || !FileExist(imagePath)) {
        TrayTip("错误", "图片路径无效", "Iconx 1")
        return
    }
    
    try {
        ; 显示提示
        TrayTip("提示", "正在提取文字，请稍候...", "Iconi 1")
        
        ; 使用OCR从文件提取文字
        ocrResult := OCR.FromFile(imagePath)
        
        if (!ocrResult || !ocrResult.HasProp("Text")) {
            TrayTip("错误", "无法提取文字", "Iconx 1")
            return
        }
        
        extractedText := ocrResult.Text
        
        if (extractedText = "" || Trim(extractedText) = "") {
            TrayTip("提示", "未检测到文字", "Iconi 1")
            return
        }
        
        ; 复制提取的文字到剪贴板
        A_Clipboard := extractedText
        
        ; 显示提取结果窗口
        ShowExtractedTextWindow(extractedText)
        
        TrayTip("成功", "文字已提取并复制到剪贴板", "Iconi 1")
        
    } catch as err {
        TrayTip("错误", "提取文字失败: " . err.Message, "Iconx 1")
    }
}

; 复制图片到剪贴板
OnImagePreviewCopy(*) {
    global HistoryImagePreviewGUI, HistoryImagePreviewCurrentPath
    
    if (!HistoryImagePreviewGUI || HistoryImagePreviewGUI = 0) {
        return
    }
    
    imagePath := HistoryImagePreviewCurrentPath
    if (imagePath = "" || !FileExist(imagePath)) {
        TrayTip("错误", "图片路径无效", "Iconx 1")
        return
    }
    
    try {
        ; 先清空剪贴板
        A_Clipboard := ""
        Sleep(100)
        
        ; 确保 GDI+ 已初始化
        if (HistoryGdiplusToken = 0) {
            InitGdiplus()
        }
        
        ; 解析图片路径
        actualImagePath := ResolveImagePath(imagePath)
        if (actualImagePath = "" || !FileExist(actualImagePath)) {
            TrayTip("错误", "图片路径无效", "Iconx 1")
            return
        }
        
        ; 使用 GDI+ 加载图片
        pBitmap := Gdip_CreateBitmapFromFile(actualImagePath)
        if (!pBitmap || pBitmap = 0) {
            ; 回退到 ImagePut
            pBitmap := ImagePut("Bitmap", actualImagePath)
            if (!pBitmap || pBitmap = "") {
                TrayTip("错误", "无法读取图片文件", "Iconx 1")
                return
            }
            ; 使用 ImagePut 时，使用 Gdip_SetBitmapToClipboard
            Gdip_SetBitmapToClipboard(pBitmap)
            ImageDestroy(pBitmap)
        } else {
            ; 使用 GDI+ 时，使用 Gdip_SetBitmapToClipboard
            Gdip_SetBitmapToClipboard(pBitmap)
            Gdip_DisposeImage(pBitmap)
        }
        
        ; 验证图片是否成功复制到剪贴板
        Sleep(50)
        if (DllCall("IsClipboardFormatAvailable", "UInt", 8)) {  ; CF_DIB = 8
            TrayTip("成功", "图片已复制到剪贴板", "Iconi 1")
        } else {
            TrayTip("警告", "图片复制失败", "Iconx 1")
        }
    } catch as err {
        TrayTip("错误", "复制失败: " . err.Message, "Iconx 1")
    }
}

; 关闭预览窗口
OnImagePreviewClose(*) {
    HideHistoryImagePreview()
}

; ===================== 提取文字复制按钮事件 =====================
OnExtractedTextCopy(text, *) {
    A_Clipboard := text
    TrayTip("提示", "已复制到剪贴板", "Iconi 1")
}

; ===================== 显示提取的文字窗口 =====================
ShowExtractedTextWindow(text) {
    ; 创建显示文字的窗口
    textGui := Gui("+AlwaysOnTop +Resize", "提取的文字")
    textGui.BackColor := HistoryColors.Background
    textGui.SetFont("s10 c" . HistoryColors.Text, "Consolas")
    
    ; 创建文本框（多行，只读）
    textEdit := textGui.Add("Edit", "x10 y10 w600 h400 +ReadOnly +Multi +VScroll +HScroll", text)
    textEdit.SetFont("s10", "Consolas")
    
    ; 添加关闭按钮
    closeBtn := textGui.Add("Button", "x520 y420 w90 h30", "关闭")
    closeBtn.OnEvent("Click", (*) => textGui.Destroy())
    
    ; 添加复制按钮
    copyBtn := textGui.Add("Button", "x420 y420 w90 h30", "复制")
    copyBtn.OnEvent("Click", OnExtractedTextCopy.Bind(text))
    
    ; 窗口关闭事件
    textGui.OnEvent("Close", (*) => textGui.Destroy())
    textGui.OnEvent("Escape", (*) => textGui.Destroy())
    
    ; 显示窗口
    textGui.Show("w630 h470")
}

; ===================== 隐藏图片预览窗口 =====================
HideHistoryImagePreview(*) {
    global HistoryImagePreviewGUI, HistoryImagePreviewIsVisible, HistoryImagePreviewTimer
    
    ; 取消定时器
    if (HistoryImagePreviewTimer != 0) {
        try {
            SetTimer(HistoryImagePreviewTimer, 0)
        } catch {
        }
        HistoryImagePreviewTimer := 0
    }
    
    ; 隐藏预览窗口
    if (HistoryImagePreviewGUI != 0) {
        try {
            HistoryImagePreviewGUI.Hide()
            HistoryImagePreviewIsVisible := false
        } catch {
        }
    }
}

; ===================== GDI+ 初始化 =====================
InitGdiplus() {
    global HistoryGdiplusToken
    
    ; 如果已经初始化，直接返回
    if (HistoryGdiplusToken != 0) {
        return HistoryGdiplusToken
    }
    
    try {
        ; 调用 Gdip_Startup 初始化 GDI+
        HistoryGdiplusToken := Gdip_Startup()
        if (!HistoryGdiplusToken || HistoryGdiplusToken = 0) {
            OutputDebug("ClipboardHistoryPanel: GDI+ 初始化失败`n")
            HistoryGdiplusToken := 0
            return 0
        }
        OutputDebug("ClipboardHistoryPanel: GDI+ 初始化成功，Token=" . HistoryGdiplusToken . "`n")
        return HistoryGdiplusToken
    } catch as err {
        OutputDebug("ClipboardHistoryPanel: GDI+ 初始化异常 - " . err.Message . "`n")
        HistoryGdiplusToken := 0
        return 0
    }
}

; ===================== GDI+ 清理 =====================
ShutdownGdiplus() {
    global HistoryGdiplusToken
    
    if (HistoryGdiplusToken != 0) {
        try {
            Gdip_Shutdown(HistoryGdiplusToken)
            HistoryGdiplusToken := 0
            OutputDebug("ClipboardHistoryPanel: GDI+ 已关闭`n")
        } catch as err {
            OutputDebug("ClipboardHistoryPanel: GDI+ 关闭异常 - " . err.Message . "`n")
        }
    }
}

; ===================== 初始化 =====================
InitClipboardHistoryPanel() {
    ; 确保数据库已初始化
    if (!ClipboardFTS5DB || ClipboardFTS5DB = 0) {
        InitClipboardFTS5DB()
    }
    
    ; 初始化 GDI+（在使用图片功能前）
    InitGdiplus()
    
    ; 确保事件已绑定（如果GUI已创建）
    if (HistoryListView && GuiID_ClipboardHistory != 0) {
        ; 重新绑定事件（防止事件丢失）
        try {
            HistoryListView.OnEvent("ItemSelect", OnHistoryItemSelect)
            HistoryListView.OnEvent("DoubleClick", OnHistoryItemDoubleClick)
            HistoryListView.OnEvent("Click", OnHistoryItemClick)
        } catch {
            ; 如果绑定失败，忽略错误（可能GUI还未完全创建）
        }
    }
}

; ===================== 叠加复制功能 =====================
; CapsLock + C：捕获文本并存入数据库（DataType=Stack）
HandleStackCopy() {
    global ClipboardFTS5DB, StackClipboardItems
    
    ; 确保数据库已初始化
    if (!ClipboardFTS5DB || ClipboardFTS5DB = 0) {
        if (!InitClipboardFTS5DB()) {
            TrayTip("错误", "数据库未初始化，无法保存叠加复制", "Iconx 1")
            return
        }
    }
    
    ; 获取剪贴板内容
    try {
        clipboardContent := A_Clipboard
        if (clipboardContent = "" || StrLen(clipboardContent) = 0) {
            TrayTip("提示", "剪贴板为空，无法叠加复制", "Iconi 1")
            return
        }
        
        ; 转义单引号和反斜杠
        escapedContent := StrReplace(clipboardContent, "'", "''")
        escapedContent := StrReplace(escapedContent, "\", "\\")
        
        ; 获取来源应用信息
        SourceApp := "Unknown"
        SourcePath := ""
        IconPath := ""
        try {
            SourceApp := WinGetProcessName("A")
            ; 获取应用信息（路径、图标）
            appInfo := GetApplicationInfo()
            if (appInfo.Has("SourceApp") && appInfo["SourceApp"] != "Unknown") {
                SourceApp := appInfo["SourceApp"]
            }
            if (appInfo.Has("SourcePath")) {
                SourcePath := appInfo["SourcePath"]
            }
            if (appInfo.Has("IconPath")) {
                IconPath := appInfo["IconPath"]
            }
        } catch {
            SourceApp := "Unknown"
        }
        
        ; 转义路径中的特殊字符
        escapedSourceApp := StrReplace(SourceApp, "'", "''")
        escapedSourceApp := StrReplace(escapedSourceApp, "\", "\\")
        escapedSourcePath := StrReplace(SourcePath, "'", "''")
        escapedSourcePath := StrReplace(escapedSourcePath, "\", "\\")
        escapedIconPath := StrReplace(IconPath, "'", "''")
        escapedIconPath := StrReplace(escapedIconPath, "\", "\\")
        
        ; 计算字符数
        charCount := StrLen(clipboardContent)
        
        ; 检查字段是否存在
        SQL := "PRAGMA table_info(ClipMain)"
        tableInfo := ""
        hasLastCopyTime := false
        hasCopyCount := false
        hasSourcePath := false
        hasIconPath := false
        
        if (ClipboardFTS5DB.GetTable(SQL, &tableInfo)) {
            if (tableInfo.HasRows && tableInfo.Rows.Length > 0) {
                Loop tableInfo.Rows.Length {
                    row := tableInfo.Rows[A_Index]
                    columnName := row[2]
                    if (columnName = "LastCopyTime") {
                        hasLastCopyTime := true
                    }
                    if (columnName = "CopyCount") {
                        hasCopyCount := true
                    }
                    if (columnName = "SourcePath") {
                        hasSourcePath := true
                    }
                    if (columnName = "IconPath") {
                        hasIconPath := true
                    }
                }
            }
        }
        
        ; 确保字段存在
        if (!hasSourcePath) {
            ClipboardFTS5DB.Exec("ALTER TABLE ClipMain ADD COLUMN SourcePath TEXT")
            hasSourcePath := true
        }
        if (!hasIconPath) {
            ClipboardFTS5DB.Exec("ALTER TABLE ClipMain ADD COLUMN IconPath TEXT")
            hasIconPath := true
        }
        if (!hasLastCopyTime) {
            ClipboardFTS5DB.Exec("ALTER TABLE ClipMain ADD COLUMN LastCopyTime DATETIME DEFAULT (datetime('now', 'localtime'))")
            hasLastCopyTime := true
        }
        if (!hasCopyCount) {
            ClipboardFTS5DB.Exec("ALTER TABLE ClipMain ADD COLUMN CopyCount INTEGER DEFAULT 1")
            hasCopyCount := true
        }
        
        ; 直接插入新记录（叠加复制总是插入新记录，不检查是否已存在）
        SQL := "INSERT INTO ClipMain (Content, SourceApp"
        if (hasSourcePath) {
            SQL .= ", SourcePath"
        }
        if (hasIconPath) {
            SQL .= ", IconPath"
        }
        SQL .= ", DataType, CharCount, Timestamp"
        if (hasLastCopyTime) {
            SQL .= ", LastCopyTime"
        }
        if (hasCopyCount) {
            SQL .= ", CopyCount"
        }
        SQL .= ") VALUES ('" . escapedContent . "', '" . escapedSourceApp . "'"
        if (hasSourcePath) {
            SQL .= ", '" . escapedSourcePath . "'"
        }
        if (hasIconPath) {
            SQL .= ", '" . escapedIconPath . "'"
        }
        SQL .= ", 'Stack', " . charCount . ", datetime('now', 'localtime')"
        if (hasLastCopyTime) {
            SQL .= ", datetime('now', 'localtime')"
        }
        if (hasCopyCount) {
            SQL .= ", 1"
        }
        SQL .= ")"
        
        if (ClipboardFTS5DB.Exec(SQL)) {
            ; 获取刚插入的记录ID
            recordID := ClipboardFTS5DB.LastInsertRowID()
            if (recordID > 0) {
                ; 添加到叠加列表
                StackClipboardItems.Push(recordID)
                
                ; 轻提示：显示叠加数量（1秒后自动消失）
                previewText := clipboardContent
                if (StrLen(previewText) > 30) {
                    previewText := SubStr(previewText, 1, 30) . "..."
                }
                TrayTip("叠加复制 " . StackClipboardItems.Length, previewText, "Iconi 1")
                SetTimer(() => TrayTip(), -1000)  ; 1秒后自动关闭提示
                
                ; 如果历史面板已打开，自动切换到 CapsLock+C 标签并刷新数据
                if (HistoryIsVisible) {
                    global HistorySelectedTag, HistoryTagButtons, HistorySearchEdit
                    ; 自动切换到 CapsLock+C 标签
                    HistorySelectedTag := "CapsLockC"
                    ; 更新标签按钮样式
                    if (IsSet(HistoryTagButtons) && HistoryTagButtons.Has("CapsLockC")) {
                        UpdateHistoryTagButtons()
                    }
                    ; 刷新数据（只显示 CapsLock+C 的数据）
                    keyword := Trim(HistorySearchEdit ? HistorySearchEdit.Value : "")
                    HistoryCurrentLimit := 100
                    RefreshHistoryData(keyword, 0, HistoryCurrentLimit)
                }
            } else {
                TrayTip("错误", "无法获取插入的记录ID", "Iconx 1")
            }
        } else {
            TrayTip("错误", "保存叠加复制失败: " . (ClipboardFTS5DB.ErrorMsg ? ClipboardFTS5DB.ErrorMsg : "未知错误"), "Iconx 1")
        }
    } catch as err {
        TrayTip("错误", "叠加复制异常: " . err.Message, "Iconx 1")
    }
}

; CapsLock + V：一次性粘贴所有叠加内容并清空缓存
HandleStackPaste() {
    global ClipboardFTS5DB, StackClipboardItems
    
    ; 确保数据库已初始化
    if (!ClipboardFTS5DB || ClipboardFTS5DB = 0) {
        TrayTip("错误", "数据库未初始化", "Iconx 1")
        return
    }
    
    ; 如果没有叠加内容，提示用户
    if (StackClipboardItems.Length = 0) {
        TrayTip("提示", "没有叠加复制的内容", "Iconi 1")
        return
    }
    
    try {
        ; 从数据库读取所有叠加内容
        allContent := []
        for index, recordID in StackClipboardItems {
            SQL := "SELECT Content FROM ClipMain WHERE ID = " . recordID
            table := ""
            if (ClipboardFTS5DB.GetTable(SQL, &table)) {
                if (table.HasRows && table.Rows.Length > 0) {
                    content := table.Rows[1][1]
                    if (content != "" && StrLen(content) > 0) {
                        allContent.Push(content)
                    }
                }
            }
        }
        
        ; 如果没有有效内容，提示用户
        if (allContent.Length = 0) {
            TrayTip("提示", "叠加内容为空", "Iconi 1")
            StackClipboardItems := []  ; 清空缓存
            return
        }
        
        ; 合并所有内容（用换行符连接）
        mergedContent := ""
        for index, content in allContent {
            if (index = 1) {
                mergedContent := content
            } else {
                mergedContent .= "`r`n" . content
            }
        }
        
        ; 保存当前剪贴板内容（用于恢复）
        oldClipboard := A_Clipboard
        
        ; 复制合并后的内容到剪贴板
        A_Clipboard := mergedContent
        Sleep(50)  ; 等待剪贴板更新
        
        ; 直接粘贴到当前输入位置
        SendInput("^v")  ; Ctrl+V 粘贴
        
        ; 等待粘贴完成
        Sleep(100)
        
        ; 清空叠加列表（重新开始记录）
        itemCount := StackClipboardItems.Length
        StackClipboardItems := []
        
        ; 轻提示：显示粘贴成功（1秒后自动消失）
        TrayTip("叠加粘贴", "已粘贴 " . itemCount . " 段内容", "Iconi 1")
        SetTimer(() => TrayTip(), -1000)  ; 1秒后自动关闭提示
        
        ; 如果历史面板已打开，刷新数据
        if (HistoryIsVisible) {
            RefreshHistoryData()
        }
        
    } catch as err {
        TrayTip("错误", "叠加粘贴异常: " . err.Message, "Iconx 1")
    }
}

; ===================== 按钮处理函数 =====================

; 复制选中项
HistoryCopySelected(*) {
    global HistoryListView, HistoryDisplayCache
    
    if (!HistoryListView || !IsObject(HistoryListView)) {
        return
    }
    
    ; 获取选中的行
    selectedRow := HistoryListView.GetNext()
    if (selectedRow = 0) {
        TrayTip("提示", "请先选中一项", "Iconi 1")
        return
    }
    
    ; 从缓存中获取数据
    if (selectedRow > 0 && selectedRow <= HistoryDisplayCache.Length) {
        rowData := HistoryDisplayCache[selectedRow]
        content := rowData.Has("Content") ? rowData["Content"] : ""
        
        if (content != "") {
            A_Clipboard := content
            TrayTip("提示", "已复制到剪贴板", "Iconi 1")
        } else {
            TrayTip("错误", "内容为空", "Iconx 1")
        }
    } else {
        TrayTip("错误", "无法获取选中项", "Iconx 1")
    }
}

; 删除选中项
HistoryDeleteSelected(*) {
    global HistoryListView, HistoryDisplayCache, ClipboardFTS5DB
    
    if (!HistoryListView || !IsObject(HistoryListView)) {
        return
    }
    
    ; 获取选中的行
    selectedRow := HistoryListView.GetNext()
    if (selectedRow = 0) {
        TrayTip("提示", "请先选中一项", "Iconi 1")
        return
    }
    
    ; 从缓存中获取数据
    if (selectedRow > 0 && selectedRow <= HistoryDisplayCache.Length) {
        rowData := HistoryDisplayCache[selectedRow]
        itemID := rowData.Has("ID") ? rowData["ID"] : 0
        
        if (itemID > 0 && ClipboardFTS5DB && ClipboardFTS5DB != 0) {
            try {
                SQL := "DELETE FROM ClipMain WHERE ID = " . itemID
                if (ClipboardFTS5DB.Exec(SQL)) {
                    ; 刷新数据
                    RefreshHistoryData()
                    TrayTip("提示", "已删除", "Iconi 1")
                } else {
                    TrayTip("错误", "删除失败: " . (ClipboardFTS5DB.ErrorMsg ? ClipboardFTS5DB.ErrorMsg : "未知错误"), "Iconx 1")
                }
            } catch as err {
                TrayTip("错误", "删除异常: " . err.Message, "Iconx 1")
            }
        } else {
            TrayTip("错误", "无法获取项目ID", "Iconx 1")
        }
    } else {
        TrayTip("错误", "无法获取选中项", "Iconx 1")
    }
}

; 粘贴到 Cursor
HistoryPasteToCursor(*) {
    global HistoryListView, HistoryDisplayCache
    
    if (!HistoryListView || !IsObject(HistoryListView)) {
        return
    }
    
    ; 获取选中的行
    selectedRow := HistoryListView.GetNext()
    if (selectedRow = 0) {
        TrayTip("提示", "请先选中一项", "Iconi 1")
        return
    }
    
    ; 从缓存中获取数据
    if (selectedRow > 0 && selectedRow <= HistoryDisplayCache.Length) {
        rowData := HistoryDisplayCache[selectedRow]
        content := rowData.Has("Content") ? rowData["Content"] : ""
        
        if (content != "") {
            ; 保存当前剪贴板
            oldClipboard := A_Clipboard
            A_Clipboard := content
            Sleep(50)
            
            ; 获取 Cursor 路径（从配置文件或使用默认路径）
            CursorPath := ""
            try {
                ; 尝试从配置文件读取
                ConfigFile := A_ScriptDir "\CursorShortcut.ini"
                if (FileExist(ConfigFile)) {
                    CursorPath := IniRead(ConfigFile, "Settings", "CursorPath", "")
                    if (CursorPath = "") {
                        CursorPath := IniRead(ConfigFile, "General", "CursorPath", "")
                    }
                }
            } catch {
            }
            
            ; 如果配置文件没有，使用默认路径
            if (CursorPath = "" || !FileExist(CursorPath)) {
                DefaultCursorPath := "C:\Users\" . A_UserName . "\AppData\Local\Cursor\Cursor.exe"
                if (FileExist(DefaultCursorPath)) {
                    CursorPath := DefaultCursorPath
                }
            }
            
            ; 打开 Cursor（如果未打开）
            if (!WinExist("ahk_exe Cursor.exe")) {
                if (CursorPath != "" && FileExist(CursorPath)) {
                    Run(CursorPath)
                    WinWait("ahk_exe Cursor.exe", , 5)
                } else {
                    TrayTip("错误", "未找到 Cursor 路径，请先打开 Cursor", "Iconx 1")
                    A_Clipboard := oldClipboard
                    return
                }
            }
            
            ; 激活 Cursor 窗口
            WinActivate("ahk_exe Cursor.exe")
            Sleep(100)
            
            ; 粘贴内容
            SendInput("^v")
            
            ; 恢复剪贴板
            A_Clipboard := oldClipboard
            
            TrayTip("提示", "已粘贴到 Cursor", "Iconi 1")
        } else {
            TrayTip("错误", "内容为空", "Iconx 1")
        }
    } else {
        TrayTip("错误", "无法获取选中项", "Iconx 1")
    }
}

; 清空全部
HistoryClearAll(*) {
    global ClipboardFTS5DB, HistoryDisplayCache
    
    ; 确认对话框
    result := MsgBox("确定要清空所有剪贴板历史吗？", "确认", "YesNo IconQuestion")
    if (result != "Yes") {
        return
    }
    
    if (ClipboardFTS5DB && ClipboardFTS5DB != 0) {
        try {
            ; 清空数据库
            if (ClipboardFTS5DB.Exec("DELETE FROM ClipMain")) {
                ; 清空 FTS5 虚拟表
                ClipboardFTS5DB.Exec("DELETE FROM ClipboardHistory")
                
                ; 刷新显示
                HistoryDisplayCache := []
                RefreshHistoryData()
                
                TrayTip("提示", "已清空所有历史", "Iconi 1")
            } else {
                TrayTip("错误", "清空失败: " . (ClipboardFTS5DB.ErrorMsg ? ClipboardFTS5DB.ErrorMsg : "未知错误"), "Iconx 1")
            }
        } catch as err {
            TrayTip("错误", "清空异常: " . err.Message, "Iconx 1")
        }
    } else {
        TrayTip("错误", "数据库未初始化", "Iconx 1")
    }
}

; 导出剪贴板
HistoryExportClipboard(*) {
    global HistoryDisplayCache
    
    if (HistoryDisplayCache.Length = 0) {
        MsgBox("没有可导出的数据", "提示", "Iconi")
        return
    }
    
    exportPath := FileSelect("S", A_ScriptDir "\ClipboardHistory_" . A_Now . ".txt", "导出剪贴板历史", "Text Files (*.txt)")
    if (exportPath = "") {
        return
    }
    
    try {
        content := "=== Clipboard History Export ===`n`n"
        for index, rowData in HistoryDisplayCache {
            itemContent := rowData.Has("Content") ? rowData["Content"] : ""
            if (itemContent != "") {
                content .= "=== Item " . index . " ===`n"
                content .= itemContent . "`n`n"
            }
        }
        
        FileDelete(exportPath)
        FileAppend(content, exportPath, "UTF-8")
        MsgBox("导出成功", "提示", "Iconi")
    } catch as err {
        MsgBox("导出失败: " . err.Message, "错误", "Iconx")
    }
}

; 导入剪贴板
HistoryImportClipboard(*) {
    global ClipboardFTS5DB
    
    importPath := FileSelect(1, A_ScriptDir, "导入剪贴板历史", "Text Files (*.txt)")
    if (importPath = "") {
        return
    }
    
    if (!ClipboardFTS5DB || ClipboardFTS5DB = 0) {
        MsgBox("数据库未初始化", "错误", "Iconx")
        return
    }
    
    try {
        content := FileRead(importPath, "UTF-8")
        
        ; 解析导入的内容
        lines := StrSplit(content, "`n")
        importedItems := []
        currentItem := ""
        
        for index, line in lines {
            ; 跳过标题行
            if (InStr(line, "=== ") = 1 && InStr(line, " Clipboard History Export") > 0) {
                continue
            }
            if (InStr(line, "=== Item ") = 1) {
                if (currentItem != "") {
                    importedItems.Push(Trim(currentItem, "`r`n "))
                    currentItem := ""
                }
            } else if (line != "") {
                currentItem .= line . "`n"
            }
        }
        
        ; 添加最后一项
        if (currentItem != "") {
            importedItems.Push(Trim(currentItem, "`r`n "))
        }
        
        ; 导入到数据库
        importedCount := 0
        for index, item in importedItems {
            if (item != "") {
                escapedContent := StrReplace(item, "'", "''")
                escapedContent := StrReplace(escapedContent, "\", "\\")
                
                SQL := "INSERT INTO ClipMain (Content, SourceApp, DataType, Timestamp) VALUES ('" . escapedContent . "', 'Import', 'Text', datetime('now', 'localtime'))"
                if (ClipboardFTS5DB.Exec(SQL)) {
                    importedCount++
                }
            }
        }
        
        ; 刷新显示
        RefreshHistoryData()
        
        MsgBox("导入成功，共导入 " . importedCount . " 项", "提示", "Iconi")
    } catch as err {
        MsgBox("导入失败: " . err.Message, "错误", "Iconx")
    }
}
