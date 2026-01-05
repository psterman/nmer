; ======================================================================================================================
; 高性能剪贴板管理器 GUI - 支持大量数据的列表显示
; 版本: 1.0.0
; 功能: 
;   - 双栏布局：左侧列表 + 右侧详情
;   - 暗黑模式配色
;   - SourceApp 颜色标识（在详情中显示）
;   - CapsLock+X 显示/隐藏
; ======================================================================================================================

#Requires AutoHotkey v2.0
#Include ClipboardFTS5.ahk

; ===================== 全局变量 =====================
global GuiID_ClipboardFTS5 := 0  ; GUI 对象
global ClipboardFTS5ListView := 0  ; ListView 控件
global ClipboardFTS5SearchEdit := 0  ; 搜索框控件
global ClipboardFTS5DetailEdit := 0  ; 详情显示控件
global ClipboardFTS5DisplayCache := []  ; 显示数据缓存
global ClipboardFTS5TotalCount := 0  ; 总记录数
global ClipboardFTS5IsVisible := false  ; 是否可见

; 暗黑模式配色
ClipboardFTS5_Colors := {
    Background: "1e1e1e",
    Sidebar: "252526",
    Border: "3c3c3c",
    Text: "cccccc",
    TextDim: "888888",
    InputBg: "2d2d30",
    ListBg: "252526",
    ListItemBg: "2d2d30",
    ListItemHover: "37373d",
    DetailBg: "1e1e1e",
    DetailText: "cccccc",
    SearchBorder: "0078d4"
}

; SourceApp 颜色映射（用于详情显示中的颜色标识）
SourceAppColors := Map(
    "chrome.exe", "4285F4",
    "firefox.exe", "FF7139",
    "Code.exe", "0078D4",
    "Cursor.exe", "0078D4",
    "notepad.exe", "FFFFFF",
    "winword.exe", "2B579A",
    "excel.exe", "217346",
    "powerpnt.exe", "D04423",
    "explorer.exe", "0078D4"
)

; ===================== 显示/隐藏 GUI =====================
ShowClipboardFTS5GUI() {
    global GuiID_ClipboardFTS5, ClipboardFTS5IsVisible, ClipboardFTS5SearchEdit
    
    if (ClipboardFTS5IsVisible && GuiID_ClipboardFTS5 != 0) {
        ; 如果已显示，聚焦到搜索框
        try {
            ControlFocus(ClipboardFTS5SearchEdit)
        }
        return
    }
    
    ; 创建 GUI
    CreateClipboardFTS5GUI()
    
    ; 加载数据
    LoadClipboardFTS5Data()
    
    ; 显示 GUI
    GuiID_ClipboardFTS5.Show("w1000 h700")
    ClipboardFTS5IsVisible := true
    
    ; 自动聚焦搜索框
    SetTimer(() => ControlFocus(ClipboardFTS5SearchEdit), -100)
}

HideClipboardFTS5GUI() {
    global GuiID_ClipboardFTS5, ClipboardFTS5IsVisible
    
    if (GuiID_ClipboardFTS5 != 0) {
        GuiID_ClipboardFTS5.Hide()
        ClipboardFTS5IsVisible := false
    }
}

ToggleClipboardFTS5GUI() {
    global ClipboardFTS5IsVisible
    
    if (ClipboardFTS5IsVisible) {
        HideClipboardFTS5GUI()
    } else {
        ShowClipboardFTS5GUI()
    }
}

; ===================== 创建 GUI =====================
CreateClipboardFTS5GUI() {
    global GuiID_ClipboardFTS5, ClipboardFTS5ListView
    global ClipboardFTS5SearchEdit, ClipboardFTS5DetailEdit
    global ClipboardFTS5_Colors
    
    ; 如果已存在，先销毁
    if (GuiID_ClipboardFTS5 != 0) {
        try {
            GuiID_ClipboardFTS5.Destroy()
        }
    }
    
    ; 创建 GUI（可调整大小，置顶）
    GuiID_ClipboardFTS5 := Gui("+Resize +AlwaysOnTop", "剪贴板管理器")
    GuiID_ClipboardFTS5.BackColor := ClipboardFTS5_Colors.Background
    GuiID_ClipboardFTS5.SetFont("s10 c" . ClipboardFTS5_Colors.Text, "Segoe UI")
    
    ; 窗口事件
    GuiID_ClipboardFTS5.OnEvent("Size", OnClipboardFTS5Size)
    GuiID_ClipboardFTS5.OnEvent("Close", OnClipboardFTS5Close)
    
    ; ========== 顶部搜索框 ==========
    SearchBoxX := 10
    SearchBoxY := 10
    SearchBoxWidth := 980
    SearchBoxHeight := 30
    
    ClipboardFTS5SearchEdit := GuiID_ClipboardFTS5.Add("Edit", 
        "x" . SearchBoxX . " y" . SearchBoxY . 
        " w" . SearchBoxWidth . " h" . SearchBoxHeight . 
        " Background" . ClipboardFTS5_Colors.InputBg . 
        " c" . ClipboardFTS5_Colors.Text . 
        " -VScroll -HScroll -Border" . 
        " vClipboardFTS5SearchEdit", "")
    
    ClipboardFTS5SearchEdit.SetFont("s11", "Segoe UI")
    ClipboardFTS5SearchEdit.OnEvent("Change", OnClipboardFTS5SearchChange)
    
    ; 移除 Edit 控件的默认边框样式
    SearchEditHwnd := ClipboardFTS5SearchEdit.Hwnd
    try {
        CurrentExStyle := DllCall("GetWindowLongPtr", "Ptr", SearchEditHwnd, "Int", -20, "Ptr")
        NewExStyle := CurrentExStyle & ~0x00000200  ; 移除 WS_EX_CLIENTEDGE
        DllCall("SetWindowLongPtr", "Ptr", SearchEditHwnd, "Int", -20, "Ptr", NewExStyle, "Ptr")
    }
    
    ; ========== 左侧 ListView ==========
    ListViewX := 10
    ListViewY := 50
    ListViewWidth := 480
    ListViewHeight := 640
    
    ClipboardFTS5ListView := GuiID_ClipboardFTS5.Add("ListView", 
        "x" . ListViewX . " y" . ListViewY . 
        " w" . ListViewWidth . " h" . ListViewHeight . 
        " Background" . ClipboardFTS5_Colors.ListBg . 
        " c" . ClipboardFTS5_Colors.Text . 
        " +ReadOnly -Multi" . 
        " vClipboardFTS5ListView", 
        ["内容预览", "时间"])
    
    ClipboardFTS5ListView.SetFont("s9", "Consolas")
    
    ; 设置列宽
    ClipboardFTS5ListView.ModifyCol(1, 350)  ; 内容预览
    ClipboardFTS5ListView.ModifyCol(2, 120)  ; 时间
    
    ; ListView 事件
    ClipboardFTS5ListView.OnEvent("ItemSelect", OnClipboardFTS5ListItemSelect)
    ClipboardFTS5ListView.OnEvent("DoubleClick", OnClipboardFTS5ListDoubleClick)
    
    ; ========== 右侧详情显示 ==========
    DetailX := 500
    DetailY := 50
    DetailWidth := 490
    DetailHeight := 640
    
    ClipboardFTS5DetailEdit := GuiID_ClipboardFTS5.Add("Edit", 
        "x" . DetailX . " y" . DetailY . 
        " w" . DetailWidth . " h" . DetailHeight . 
        " Background" . ClipboardFTS5_Colors.DetailBg . 
        " c" . ClipboardFTS5_Colors.DetailText . 
        " +ReadOnly +Multi +VScroll +HScroll" . 
        " vClipboardFTS5DetailEdit", "")
    
    ClipboardFTS5DetailEdit.SetFont("s10", "Consolas")
    
    ; 移除 Edit 控件的边框样式
    DetailEditHwnd := ClipboardFTS5DetailEdit.Hwnd
    try {
        CurrentExStyle := DllCall("GetWindowLongPtr", "Ptr", DetailEditHwnd, "Int", -20, "Ptr")
        NewExStyle := CurrentExStyle & ~0x00000200  ; 移除 WS_EX_CLIENTEDGE
        DllCall("SetWindowLongPtr", "Ptr", DetailEditHwnd, "Int", -20, "Ptr", NewExStyle, "Ptr")
    }
}

; ===================== 辅助函数：获取内容预览 =====================
GetContentPreview(content, maxLength := 50) {
    if (StrLen(content) <= maxLength) {
        return content
    }
    
    return SubStr(content, 1, maxLength) . "..."
}

; ===================== 加载数据到缓存 =====================
LoadClipboardFTS5Data(keyword := "") {
    global ClipboardFTS5DisplayCache, ClipboardFTS5TotalCount
    global ClipboardFTS5ListView, ClipboardFTS5DB
    
    ; 从数据库加载数据
    results := []
    
    if (keyword = "") {
        ; 加载所有数据（限制数量）
        SQL := "SELECT ID, Content, SourceApp, DataType, CharCount, Timestamp, ImagePath, IsFavorite " .
               "FROM ClipMain " .
               "ORDER BY Timestamp DESC " .
               "LIMIT 5000"
        
        try {
            if (ClipboardFTS5DB && ClipboardFTS5DB != 0) {
                stmt := ""
                if (ClipboardFTS5DB.Prepare(SQL, &stmt)) {
                    while (stmt.Step()) {
                        row := Map()
                        row["ID"] := stmt.Column(0)
                        row["Content"] := stmt.Column(1)
                        row["SourceApp"] := stmt.Column(2)
                        row["DataType"] := stmt.Column(3)
                        row["CharCount"] := stmt.Column(4)
                        row["Timestamp"] := stmt.Column(5)
                        row["ImagePath"] := stmt.Column(6)
                        row["IsFavorite"] := stmt.Column(7)
                        results.Push(row)
                    }
                    stmt.Free()
                }
            }
        } catch as err {
            ; 错误处理
        }
    } else {
        ; 使用 FTS5 搜索
        results := SearchClipboardFTS5(keyword, 5000)
    }
    
    ; 更新缓存
    ClipboardFTS5DisplayCache := results
    ClipboardFTS5TotalCount := results.Length
    
    ; 更新 ListView
    if (ClipboardFTS5ListView) {
        ; 暂停重绘以提高性能
        ClipboardFTS5ListView.Opt("-Redraw")
        
        ; 清空列表
        ClipboardFTS5ListView.Delete()
        
        ; 添加数据
        for index, rowData in results {
            previewText := GetContentPreview(rowData["Content"], 50)
            try {
                timeText := FormatTime(rowData["Timestamp"], "HH:mm:ss")
            } catch {
                timeText := rowData["Timestamp"]
            }
            ClipboardFTS5ListView.Add(, previewText, timeText)
        }
        
        ; 恢复重绘
        ClipboardFTS5ListView.Opt("+Redraw")
    }
}

; ===================== 搜索框变化事件 =====================
OnClipboardFTS5SearchChange(*) {
    global ClipboardFTS5SearchEdit
    
    keyword := ClipboardFTS5SearchEdit.Value
    LoadClipboardFTS5Data(keyword)
}

; ===================== ListView 项选择事件 =====================
OnClipboardFTS5ListItemSelect(*) {
    global ClipboardFTS5ListView, ClipboardFTS5DetailEdit, ClipboardFTS5DisplayCache
    
    selectedRow := ClipboardFTS5ListView.GetNext()
    if (selectedRow > 0 && selectedRow <= ClipboardFTS5DisplayCache.Length) {
        rowData := ClipboardFTS5DisplayCache[selectedRow]
        
        ; 更新详情显示
        detailText := FormatDetailText(rowData)
        ClipboardFTS5DetailEdit.Value := detailText
    }
}

; ===================== ListView 双击事件 =====================
OnClipboardFTS5ListDoubleClick(*) {
    global ClipboardFTS5ListView, ClipboardFTS5DisplayCache
    
    selectedRow := ClipboardFTS5ListView.GetNext()
    if (selectedRow > 0 && selectedRow <= ClipboardFTS5DisplayCache.Length) {
        rowData := ClipboardFTS5DisplayCache[selectedRow]
        
        ; 复制内容到剪贴板
        if (rowData.Has("Content")) {
            A_Clipboard := rowData["Content"]
            TrayTip("已复制", "内容已复制到剪贴板", "Iconi 1")
        }
    }
}

; ===================== 格式化详情文本 =====================
FormatDetailText(rowData) {
    global SourceAppColors
    
    text := "ID: " . rowData["ID"] . "`n"
    text .= "类型: " . rowData["DataType"] . "`n"
    
    ; SourceApp 颜色标识（在文本中显示颜色代码）
    sourceApp := rowData["SourceApp"]
    text .= "来源: " . sourceApp
    if (SourceAppColors.Has(sourceApp)) {
        text .= " [颜色: #" . SourceAppColors[sourceApp] . "]"
    }
    text .= "`n"
    
    text .= "时间: " . rowData["Timestamp"] . "`n"
    text .= "字符数: " . rowData["CharCount"] . "`n"
    text .= "收藏: " . (rowData["IsFavorite"] ? "是" : "否") . "`n"
    text .= "`n--- 内容 ---`n`n"
    text .= rowData["Content"]
    
    if (rowData.Has("ImagePath") && rowData["ImagePath"] != "") {
        text .= "`n`n图片路径: " . rowData["ImagePath"]
    }
    
    return text
}

; ===================== 窗口大小改变事件 =====================
OnClipboardFTS5Size(*) {
    global GuiID_ClipboardFTS5, ClipboardFTS5ListView, ClipboardFTS5DetailEdit, ClipboardFTS5SearchEdit
    
    ; 获取窗口大小
    GuiID_ClipboardFTS5.GetPos(,, &width, &height)
    
    ; 调整搜索框宽度
    ClipboardFTS5SearchEdit.Move(,, width - 20)
    
    ; 调整 ListView 和详情区域高度
    listHeight := height - 60
    ClipboardFTS5ListView.Move(,,, listHeight)
    ClipboardFTS5DetailEdit.Move(,,, listHeight)
    
    ; 调整详情区域宽度
    detailWidth := width - 510
    ClipboardFTS5DetailEdit.Move(, detailWidth)
}

; ===================== 窗口关闭事件 =====================
OnClipboardFTS5Close(*) {
    HideClipboardFTS5GUI()
}

; ===================== 获取数据库总记录数 =====================
GetClipboardFTS5TotalCount() {
    global ClipboardFTS5DB
    
    if (!ClipboardFTS5DB || ClipboardFTS5DB = 0) {
        return 0
    }
    
    try {
        SQL := "SELECT COUNT(*) FROM ClipMain"
        stmt := ""
        if (ClipboardFTS5DB.Prepare(SQL, &stmt)) {
            if (stmt.Step()) {
                count := stmt.Column(0)
                stmt.Free()
                return count
            }
            stmt.Free()
        }
    } catch as err {
        ; 错误处理
    }
    
    return 0
}

; ===================== 初始化（在脚本启动时调用） =====================
InitClipboardFTS5GUI() {
    ; 确保数据库已初始化
    if (!ClipboardFTS5DB || ClipboardFTS5DB = 0) {
        InitClipboardFTS5DB()
    }
    
    ; 注意：CapsLock+X 热键绑定需要在主脚本中完成
    ; 因为热键绑定需要特定的上下文（如 #HotIf GetCapsLockState()）
}
