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
#Include modules\ClipboardFTS5.ahk
#Include ..\lib\Gdip_All.ahk
#Include ..\lib\WinClip.ahk

; ===================== 全局变量 =====================
global GuiID_ClipboardFTS5 := 0  ; GUI 对象
global ClipboardFTS5ListView := 0  ; ListView 控件
global ClipboardFTS5SearchEdit := 0  ; 搜索框控件
global ClipboardFTS5DisplayCache := []  ; 显示数据缓存
global ClipboardFTS5TotalCount := 0  ; 总记录数
global ClipboardFTS5IsVisible := false  ; 是否可见
global ClipboardFTS5SearchTimer := 0  ; 搜索防抖定时器

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
    
    ; 设置键盘钩子
    SetClipboardFTS5KeyboardHook()
    
    ; 自动聚焦搜索框
    SetTimer(() => ControlFocus(ClipboardFTS5SearchEdit), -100)
}

HideClipboardFTS5GUI() {
    global GuiID_ClipboardFTS5, ClipboardFTS5IsVisible
    global ClipboardFTS5SearchTimer
    
    ; 清理搜索定时器
    if (ClipboardFTS5SearchTimer != 0) {
        try {
            SetTimer(ClipboardFTS5SearchTimer, 0)
        }
        ClipboardFTS5SearchTimer := 0
    }
    
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
    global ClipboardFTS5SearchEdit
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
    SearchBoxWidth := 1000 - 20  ; 窗口宽度减去左右边距
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
    ClipboardFTS5ListView.OnNotify(-12, OnClipboardFTS5ListViewNotify)  ; NM_CUSTOMDRAW = -12
    
    ; 键盘事件处理（Enter 键）
    GuiID_ClipboardFTS5.OnEvent("Escape", OnClipboardFTS5Escape)
    GuiID_ClipboardFTS5.AddText("x0 y0 w0 h0 vClipboardFTS5FocusHandler")  ; 用于捕获键盘事件
}

; ===================== 辅助函数：获取内容预览 =====================
GetContentPreview(content, maxLength := 50) {
    if (StrLen(content) <= maxLength) {
        return content
    }
    
    return SubStr(content, 1, maxLength) . "..."
}

; ===================== 加载数据到缓存（带异常处理和 SendMessage 更新行数） =====================
LoadClipboardFTS5Data(keyword := "") {
    global ClipboardFTS5DisplayCache, ClipboardFTS5TotalCount
    global ClipboardFTS5ListView, ClipboardFTS5DB
    
    ; 检查数据库死锁
    if (!CheckDatabaseConnection()) {
        return false
    }
    
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
                ; 使用 PRAGMA busy_timeout 防止死锁（5000ms 超时）
                ClipboardFTS5DB.Exec("PRAGMA busy_timeout = 5000")
                
                stmt := ""
                if (!ClipboardFTS5DB.Prepare(SQL, &stmt)) {
                    continue
                }
                if (stmt) {
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
            ; 数据库错误处理
            TrayTip("数据库错误", "查询失败: " . err.Message, "IconX 2")
            return false
        }
    } else {
        ; 使用 FTS5 搜索（带异常处理）
        try {
            results := SearchClipboardFTS5(keyword, 5000)
        } catch as err {
            TrayTip("搜索错误", "搜索失败: " . err.Message, "IconX 2")
            return false
        }
    }
    
    ; 更新缓存
    ClipboardFTS5DisplayCache := results
    ClipboardFTS5TotalCount := results.Length
    
    ; 更新 ListView
    if (ClipboardFTS5ListView) {
        ListViewHwnd := ClipboardFTS5ListView.Hwnd
        
        ; 暂停重绘以提高性能
        DllCall("SendMessage", "Ptr", ListViewHwnd, "UInt", 0x000B, "Ptr", 0, "Ptr", 0)  ; WM_SETREDRAW = 0x000B, wParam = FALSE
        
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
        
        ; 使用 SendMessage 更新 ListView 总行数（LVM_SETITEMCOUNT）
        ; 0x102F = LVM_SETITEMCOUNT, wParam = itemCount, lParam = LVSICF_NOINVALIDATEALL
        DllCall("SendMessage", "Ptr", ListViewHwnd, "UInt", 0x102F, "Ptr", results.Length, "Ptr", 0x0001)
        
        ; 恢复重绘
        DllCall("SendMessage", "Ptr", ListViewHwnd, "UInt", 0x000B, "Ptr", 1, "Ptr", 0)  ; WM_SETREDRAW = 0x000B, wParam = TRUE
        
        ; 强制重绘
        DllCall("InvalidateRect", "Ptr", ListViewHwnd, "Ptr", 0, "Int", 1)
    }
    
    return true
}

; ===================== 检查数据库连接（死锁检测） =====================
CheckDatabaseConnection() {
    global ClipboardFTS5DB
    
    if (!ClipboardFTS5DB || ClipboardFTS5DB = 0) {
        ; 尝试重新初始化
        try {
            InitClipboardFTS5DB()
            return (ClipboardFTS5DB != 0 && ClipboardFTS5DB != false)
        } catch {
            return false
        }
    }
    
    try {
        ; 设置超时（5秒）防止死锁
        ClipboardFTS5DB.Exec("PRAGMA busy_timeout = 5000")
        
        ; 尝试执行一个简单的查询来检查连接
        testSQL := "SELECT 1"
        stmt := ""
        if (!ClipboardFTS5DB.Prepare(testSQL, &stmt)) {
            return false
        }
        
        if (stmt.Step()) {
            stmt.Free()
            return true
        }
        
        stmt.Free()
        return false
        
    } catch as err {
        ; 如果出现错误（如死锁），尝试重新初始化
        try {
            if (ClipboardFTS5DB != 0) {
                try {
                    ClipboardFTS5DB.CloseDB()
                }
            }
            InitClipboardFTS5DB()
            return (ClipboardFTS5DB != 0 && ClipboardFTS5DB != false)
        } catch {
            return false
        }
    }
}

; ===================== 搜索框变化事件（带防抖） =====================
OnClipboardFTS5SearchChange(*) {
    global ClipboardFTS5SearchTimer, ClipboardFTS5SearchEdit
    
    ; 清除之前的定时器
    if (ClipboardFTS5SearchTimer != 0) {
        try {
            SetTimer(ClipboardFTS5SearchTimer, 0)
        }
    }
    
    ; 设置新的防抖定时器（300ms 延迟）
    ClipboardFTS5SearchTimer := () => {
        keyword := ClipboardFTS5SearchEdit.Value
        LoadClipboardFTS5Data(keyword)
    }
    SetTimer(ClipboardFTS5SearchTimer, -300)  ; -300ms 表示只执行一次，延迟 300ms
}

; ===================== ListView 项选择事件 =====================
OnClipboardFTS5ListItemSelect(*) {
    global ClipboardFTS5ListView, ClipboardFTS5DisplayCache
    
    ; 选择事件保留，但不再显示详情（详情控件已移除）
    selectedRow := ClipboardFTS5ListView.GetNext()
}

; ===================== ListView 双击事件 =====================
OnClipboardFTS5ListDoubleClick(*) {
    ; 双击等同于 Enter 键
    OnClipboardFTS5EnterKey()
}

; ===================== Enter 键处理（还原格式并粘贴） =====================
OnClipboardFTS5EnterKey() {
    global ClipboardFTS5ListView, ClipboardFTS5DisplayCache
    
    selectedRow := ClipboardFTS5ListView.GetNext()
    if (selectedRow > 0 && selectedRow <= ClipboardFTS5DisplayCache.Length) {
        rowData := ClipboardFTS5DisplayCache[selectedRow]
        
        try {
            dataType := rowData.Has("DataType") ? rowData["DataType"] : "Text"
            
            if (dataType = "Image" && rowData.Has("ImagePath") && rowData["ImagePath"] != "") {
                ; 图片：从文件路径加载到剪贴板
                if (FileExist(rowData["ImagePath"])) {
                    ; 使用 GDI+ 加载图片到剪贴板
                    pToken := 0
                    try {
                        pToken := Gdip_Startup()
                        pBitmap := Gdip_CreateBitmapFromFile(rowData["ImagePath"])
                        if (pBitmap && pBitmap > 0) {
                            Gdip_SetBitmapToClipboard(pBitmap)
                            Gdip_DisposeImage(pBitmap)
                            Gdip_Shutdown(pToken)
                            
                            ; 隐藏窗口并粘贴
                            HideClipboardFTS5GUI()
                            Sleep(50)
                            Send("^v")
                            TrayTip("已粘贴", "图片已粘贴", "Iconi 1")
                            return
                        }
                        if (pToken) {
                            Gdip_Shutdown(pToken)
                        }
                    } catch {
                        if (pToken) {
                            try {
                                Gdip_Shutdown(pToken)
                            }
                        }
                    }
                }
            } else {
                ; 文本：使用 WinClip 还原格式
                content := rowData.Has("Content") ? rowData["Content"] : ""
                
                if (content != "") {
                    ; 尝试使用 WinClip 还原格式（如果格式数据存在）
                    ; 否则使用普通剪贴板
                    clipboardObj := WinClip()
                    
                    ; 先保存当前剪贴板
                    clipboardObj.Snap(&savedData)
                    
                    ; 设置新内容到剪贴板
                    A_Clipboard := content
                    
                    ; 等待剪贴板就绪
                    ClipWait(1, 1)
                    
                    ; 隐藏窗口并粘贴
                    HideClipboardFTS5GUI()
                    Sleep(50)
                    Send("^v")
                    
                    ; 恢复原始剪贴板
                    Sleep(100)
                    clipboardObj.Restore(&savedData)
                    
                    TrayTip("已粘贴", "内容已粘贴", "Iconi 1")
                    return
                }
            }
        } catch as err {
            TrayTip("粘贴错误", "粘贴失败: " . err.Message, "IconX 2")
        }
    }
}

; ===================== Escape 键处理 =====================
OnClipboardFTS5Escape(*) {
    HideClipboardFTS5GUI()
}

; ===================== 在 GUI 显示时设置键盘钩子 =====================
SetClipboardFTS5KeyboardHook() {
    global GuiID_ClipboardFTS5
    
    if (GuiID_ClipboardFTS5 && GuiID_ClipboardFTS5 != 0) {
        ; 使用 OnMessage 捕获 Enter 键
        OnMessage(0x0100, OnClipboardFTS5WMKeyDown)  ; WM_KEYDOWN = 0x0100
    }
}

; WM_KEYDOWN 消息处理（Enter 键）
OnClipboardFTS5WMKeyDown(wParam, lParam, msg, hwnd) {
    global ClipboardFTS5ListView, ClipboardFTS5IsVisible, GuiID_ClipboardFTS5
    
    ; 检查是否在剪贴板管理器窗口中
    if (!ClipboardFTS5IsVisible || !GuiID_ClipboardFTS5) {
        return
    }
    
    ; Enter 键的虚拟键码是 0x0D (VK_RETURN)
    if (wParam = 0x0D) {
        ; 检查焦点是否在当前窗口
        try {
            focusedHwnd := DllCall("GetFocus", "Ptr")
            guiHwnd := GuiID_ClipboardFTS5.Hwnd
            ListViewHwnd := ClipboardFTS5ListView.Hwnd
            
            ; 检查焦点是否在 GUI 窗口或其子控件中
            parentHwnd := focusedHwnd
            Loop 10 {  ; 最多检查 10 层父窗口
                if (parentHwnd = guiHwnd || parentHwnd = ListViewHwnd) {
                    OnClipboardFTS5EnterKey()
                    return 0  ; 消费该消息
                }
                parentHwnd := DllCall("GetParent", "Ptr", parentHwnd, "Ptr")
                if (!parentHwnd || parentHwnd = 0) {
                    break
                }
            }
        } catch {
            ; 如果检查失败，也尝试处理（以防万一）
            OnClipboardFTS5EnterKey()
            return 0
        }
    }
    
    return  ; 继续传递消息
}

; ===================== ListView 自定义绘制通知（颜色区分） =====================
OnClipboardFTS5ListViewNotify(lParam, *) {
    global ClipboardFTS5ListView, ClipboardFTS5DisplayCache, SourceAppColors
    
    ; 获取 NMHDR 结构（通知消息头）
    ; NMHDR: hwndFrom (8 bytes), idFrom (Ptr), code (UInt)
    code := NumGet(lParam + 8 + A_PtrSize, "Int")
    
    ; 检查是否是 NM_CUSTOMDRAW 消息（code = -12）
    if (code != -12) {
        return 0  ; 不处理其他消息
    }
    
    ; 获取 NMLVCUSTOMDRAW 结构
    ; NMLVCUSTOMDRAW: NMHDR + dwDrawStage + hdc + rc (RECT) + dwItemSpec + uItemState + lItemlParam + clrText + clrTextBk + iSubItem + dwItemType + clrFace + iIconEffect + iIconPhase + iPartId + iStateId + rcText (RECT) + uAlign
    drawStage := NumGet(lParam + 8 + A_PtrSize + 4, "UInt")
    
    ; CDDS_PREPAINT (0x00000001): 在绘制之前
    ; CDDS_ITEMPREPAINT (0x00010001): 在绘制项目之前
    ; CDDS_SUBITEM | CDDS_ITEMPREPAINT (0x00010001 | 0x00020000): 在绘制子项目之前
    
    if (drawStage = 0x00000001) {
        ; CDDS_PREPAINT: 返回 CDRF_NOTIFYITEMDRAW 以接收每个项目的通知
        return 0x00000020  ; CDRF_NOTIFYITEMDRAW
    }
    
    if (drawStage = 0x00010001) {
        ; CDDS_ITEMPREPAINT: 处理单个项目的绘制
        
        ; 获取项目索引（dwItemSpec）
        itemIndex := NumGet(lParam + 8 + A_PtrSize + 4 + 4 + A_PtrSize + 16, "Int") + 1  ; +1 因为 ListView 索引从 1 开始
        
        ; 检查索引是否有效
        if (itemIndex > 0 && itemIndex <= ClipboardFTS5DisplayCache.Length) {
            rowData := ClipboardFTS5DisplayCache[itemIndex]
            sourceApp := rowData.Has("SourceApp") ? rowData["SourceApp"] : "Unknown"
            
            ; 根据 SourceApp 设置文本颜色
            if (SourceAppColors.Has(sourceApp)) {
                colorCode := SourceAppColors[sourceApp]
                ; 将十六进制颜色转换为 RGB
                colorRGB := Integer("0x" . colorCode)
                ; BGR 格式（Windows GDI 使用 BGR）
                bgrColor := ((colorRGB & 0xFF) << 16) | (colorRGB & 0xFF00) | ((colorRGB >> 16) & 0xFF)
                
                ; 设置文本颜色（clrText 偏移）
                clrTextOffset := 8 + A_PtrSize + 4 + 4 + A_PtrSize + 16 + 4 + 4 + A_PtrSize
                NumPut("UInt", bgrColor, lParam, clrTextOffset)
                
                ; 保持背景色（可选：也可以设置背景色）
                ; clrTextBk 偏移在 clrText 之后
                ; NumPut("UInt", 0x1e1e1e, lParam, clrTextOffset + 4)
            }
            
            ; 返回 CDRF_NOTIFYPOSTPAINT 以处理子项目
            return 0x00000010  ; CDRF_NOTIFYPOSTPAINT
        }
    }
    
    ; 其他阶段不处理
    return 0x00000000  ; CDRF_DODEFAULT
}

; ===================== 窗口大小改变事件 =====================
OnClipboardFTS5Size(*) {
    global GuiID_ClipboardFTS5, ClipboardFTS5ListView, ClipboardFTS5SearchEdit
    
    ; 获取窗口大小
    GuiID_ClipboardFTS5.GetPos(,, &width, &height)
    
    ; 调整搜索框宽度
    ClipboardFTS5SearchEdit.Move(,, width - 10)
    
    ; 调整 ListView 宽度和高度
    listHeight := height - 60
    ClipboardFTS5ListView.Move(,, width - 10, listHeight)
}

; ===================== 窗口关闭事件 =====================
OnClipboardFTS5Close(*) {
    HideClipboardFTS5GUI()
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
