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

; ===================== 全局变量 =====================
global GuiID_ClipboardHistory := 0
global HistoryListView := 0
global HistorySearchEdit := 0
global HistoryIsVisible := false
global HistoryDisplayCache := []
global HistoryTagButtons := Map()  ; 存储标签按钮对象
global HistorySelectedTag := ""  ; 当前选中的标签（空字符串表示全部）
global ColorSummaryGUI := 0  ; 颜色汇总面板GUI
global ColorSummaryIsVisible := false  ; 颜色汇总面板是否可见
global HistorySearchTimer := 0  ; 搜索防抖定时器

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
    TagBg: "2d2d30",
    TagBgActive: "007acc",  ; Cursor蓝色（激活状态）
    TagText: "cccccc",
    TagTextActive: "ffffff",
    TagBorder: "3c3c3c",
    TagBorderActive: "007acc"  ; Cursor蓝色
}

; ===================== 显示/隐藏面板 =====================
ShowClipboardHistoryPanel() {
    global GuiID_ClipboardHistory, HistoryIsVisible, HistorySearchEdit, ClipboardFTS5DB
    
    if (HistoryIsVisible && GuiID_ClipboardHistory != 0) {
        ; 如果已显示，聚焦到搜索框并刷新数据
        try {
            ControlFocus(HistorySearchEdit)
            ; 强制刷新数据
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
    
    ; 加载数据（确保在显示前加载）
    RefreshHistoryData()
    
    ; 显示 GUI
    GuiID_ClipboardHistory.Show("w900 h600")
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
    
    if (GuiID_ClipboardHistory != 0) {
        GuiID_ClipboardHistory.Hide()
        HistoryIsVisible := false
    }
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
    global GuiID_ClipboardHistory, HistoryListView, HistorySearchEdit
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
    
    ; ========== 顶部搜索框 ==========
    SearchBoxX := 10
    SearchBoxY := 10
    SearchBoxWidth := 880
    SearchBoxHeight := 30
    
    HistorySearchEdit := GuiID_ClipboardHistory.Add("Edit", 
        "x" . SearchBoxX . " y" . SearchBoxY . 
        " w" . SearchBoxWidth . " h" . SearchBoxHeight . 
        " Background" . HistoryColors.InputBg . 
        " c" . HistoryColors.Text . 
        " -VScroll -HScroll -Border" . 
        " vHistorySearchEdit", "")
    
    HistorySearchEdit.SetFont("s11", "Segoe UI")
    HistorySearchEdit.OnEvent("Change", OnHistorySearchChange)
    
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
    TagButtonWidth := 80
    TagStartX := 10
    
    ; 标签列表：文本、图片、链接、颜色、代码
    TagLabels := ["文本", "图片", "链接", "颜色", "代码"]
    TagTypes := ["Text", "Image", "Link", "Color", "Code"]
    
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
        
        ; 创建按钮（Material风格：扁平、无边框）
        tagButton := GuiID_ClipboardHistory.Add("Button", 
            "x" . tagX . " y" . TagAreaY . 
            " w" . TagButtonWidth . " h" . TagButtonHeight . 
            " Background" . HistoryColors.TagBg . 
            " c" . HistoryColors.TagText . 
            " vHistoryTag_" . tagType, tagLabel)
        
        tagButton.SetFont("s9 Bold", "Segoe UI")
        
        ; 设置按钮样式（Material风格：扁平、无边框）
        tagButtonHwnd := tagButton.Hwnd
        try {
            ; 设置按钮为扁平样式（移除Windows主题）
            DllCall("uxtheme\SetWindowTheme", "Ptr", tagButtonHwnd, "Ptr", 0, "Ptr", 0)
            ; 设置按钮为扁平样式（BS_FLAT）
            CurrentStyle := DllCall("GetWindowLongPtr", "Ptr", tagButtonHwnd, "Int", -16, "Ptr")
            NewStyle := CurrentStyle | 0x8000  ; BS_FLAT
            DllCall("SetWindowLongPtr", "Ptr", tagButtonHwnd, "Int", -16, "Ptr", NewStyle, "Ptr")
            ; 移除边框
            NewStyle := NewStyle & ~0x84000000  ; 移除WS_BORDER和WS_DLGFRAME
            DllCall("SetWindowLongPtr", "Ptr", tagButtonHwnd, "Int", -16, "Ptr", NewStyle, "Ptr")
        }
        
        ; 绑定点击事件
        tagButton.OnEvent("Click", OnHistoryTagClick.Bind(tagType))
        
        ; 存储按钮引用
        HistoryTagButtons[tagType] := tagButton
    }
    
    ; 初始化标签按钮样式
    UpdateHistoryTagButtons()
    
    ; ========== ListView ==========
    ListViewX := 10
    ListViewY := 90  ; 调整Y位置，为标签区域留出空间
    ListViewWidth := 880
    ListViewHeight := 500  ; 调整高度
    
    HistoryListView := GuiID_ClipboardHistory.Add("ListView", 
        "x" . ListViewX . " y" . ListViewY . 
        " w" . ListViewWidth . " h" . ListViewHeight . 
        " Background" . HistoryColors.ListBg . 
        " c" . HistoryColors.Text . 
        " +ReadOnly -Multi" . 
        " vHistoryListView", 
        ["序号", "内容预览", "来源应用", "文件位置", "类型", "最后复制", "复制次数", "字符数"])
    
    HistoryListView.SetFont("s9", "Consolas")
    
    ; 设置列宽
    HistoryListView.ModifyCol(1, 50)   ; 序号
    HistoryListView.ModifyCol(2, 310)  ; 内容预览
    HistoryListView.ModifyCol(3, 100)  ; 来源应用
    HistoryListView.ModifyCol(4, 200)  ; 文件位置
    HistoryListView.ModifyCol(5, 70)   ; 类型
    HistoryListView.ModifyCol(6, 120)  ; 最后复制时间
    HistoryListView.ModifyCol(7, 70)   ; 复制次数
    HistoryListView.ModifyCol(8, 70)   ; 字符数
    
    ; ListView 事件
    HistoryListView.OnEvent("ItemSelect", OnHistoryItemSelect)
    HistoryListView.OnEvent("DoubleClick", OnHistoryItemDoubleClick)
    
    ; ========== 底部状态栏 ==========
    StatusBarText := GuiID_ClipboardHistory.Add("Text", 
        "x10 y595 w880 h20 c" . HistoryColors.TextDim, 
        "提示: 双击项目复制到剪贴板 | 使用搜索框过滤内容 | 点击标签分类筛选 | 鼠标悬停查看完整路径")
    StatusBarText.SetFont("s8", "Segoe UI")
}

; ===================== 加载数据 =====================
RefreshHistoryData(keyword := "") {
    global HistoryListView, HistoryDisplayCache, ClipboardFTS5DB, HistorySelectedTag
    
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
                HistoryListView.Add(, "数据库未连接", "请检查数据库初始化", "", "", "", "", "")
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
            selectFields .= ", DataType, CharCount, Timestamp"
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
            whereConditions := []
            
            ; 添加关键词搜索条件（优先使用 FTS5 MATCH 语法）
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
                    whereConditions.Push("ID IN (SELECT rowid FROM ClipboardHistory WHERE ClipboardHistory MATCH '" . ftsQuery . "')")
                } else {
                    ; 使用 LIKE 查询（适用于短关键词或 FTS5 不可用）
                    ; 同时搜索 Content 和 SourceApp 字段，提高匹配率
                    whereConditions.Push("(Content LIKE '%" . escapedKeyword . "%' OR SourceApp LIKE '%" . escapedKeyword . "%')")
                }
            } else {
                ; 如果没有搜索关键词，但需要确保查询正常执行
                ; 这里不需要添加条件
            }
            
            ; 添加标签过滤条件
            if (HistorySelectedTag != "") {
                ; 转义标签类型
                escapedTagType := StrReplace(HistorySelectedTag, "'", "''")
                
                ; 特殊处理：文本标签包含Text和Email类型
                if (HistorySelectedTag = "Text") {
                    whereConditions.Push("(DataType = 'Text' OR DataType = 'Email')")
                } else {
                    whereConditions.Push("DataType = '" . escapedTagType . "'")
                }
            }
            
            ; 构建SQL查询（从 ClipMain 表查询，但使用 FTS5 进行搜索）
            SQL := "SELECT " . selectFields . " FROM ClipMain"
            if (whereConditions.Length > 0) {
                SQL .= " WHERE " . whereConditions[1]
                Loop whereConditions.Length - 1 {
                    SQL .= " AND " . whereConditions[A_Index + 1]
                }
            }
            SQL .= " ORDER BY " . orderByField . " DESC LIMIT 1000"
            
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
                        } else {
                            ; 按固定顺序读取（后备方案）
                            ; SQL查询的列顺序：ID(1), Content(2), SourceApp(3), SourcePath(4), IconPath(5), DataType(6), CharCount(7), Timestamp(8), LastCopyTime(9), CopyCount(10)
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
                                rowData["LastCopyTime"] := row[9]
                            }
                            if (rowCount >= 10) {
                                rowData["CopyCount"] := row[10]
                            }
                        }
                        
                        ; 确保所有必需字段都有值
                        if (!rowData.Has("ID") || rowData["ID"] = "") {
                            continue
                        }
                        if (!rowData.Has("Content") || rowData["Content"] = "") {
                            continue  ; 跳过空内容
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
                        
                        results.Push(rowData)
                    }
                }
            } else {
                ; 查询失败，记录错误并尝试最简单的查询
                errorMsg := ClipboardFTS5DB.ErrorMsg
                ; OutputDebug("ClipboardHistoryPanel 查询失败: " . errorMsg . "`n")
                
                ; 尝试最简单的查询
                fallbackSQL := "SELECT ID, Content, SourceApp, DataType, CharCount, Timestamp FROM ClipMain ORDER BY ID DESC LIMIT 1000"
                fallbackTable := ""
                if (ClipboardFTS5DB.GetTable(fallbackSQL, &fallbackTable)) {
                    if (fallbackTable.HasRows && fallbackTable.Rows.Length > 0) {
                        Loop fallbackTable.Rows.Length {
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
                    }
                }
            }
        }
    } catch as err {
        ; 错误处理 - 可以在这里添加错误日志
    }
    
    ; 更新缓存
    HistoryDisplayCache := results
    
    ; 更新 ListView
    if (HistoryListView) {
        ; 暂停重绘以提高性能
        HistoryListView.Opt("-Redraw")
        
        ; 清空列表
        HistoryListView.Delete()
        
        ; 添加数据
        for index, rowData in results {
            ; 获取内容预览（最多80字符）
            preview := rowData["Content"]
            if (StrLen(preview) > 80) {
                preview := SubStr(preview, 1, 80) . "..."
            }
            ; 替换换行符为空格
            preview := StrReplace(preview, "`r`n", " ")
            preview := StrReplace(preview, "`n", " ")
            preview := StrReplace(preview, "`r", " ")
            
            ; 格式化时间
            try {
                lastCopyTime := rowData.Has("LastCopyTime") && rowData["LastCopyTime"] != "" ? rowData["LastCopyTime"] : rowData["Timestamp"]
                timeText := FormatTime(lastCopyTime, "yyyy-MM-dd HH:mm:ss")
            } catch {
                timeText := rowData.Has("LastCopyTime") ? rowData["LastCopyTime"] : rowData["Timestamp"]
            }
            
            ; 获取文件位置（显示文件名或路径）
            sourcePath := rowData.Has("SourcePath") ? rowData["SourcePath"] : ""
            fileLocation := ""
            if (sourcePath != "" && sourcePath != "\\") {
                ; 只显示文件名，完整路径在工具提示中显示
                try {
                    SplitPath(sourcePath, &fileName)
                    fileLocation := fileName
                } catch {
                    fileLocation := sourcePath
                }
            } else {
                fileLocation := "-"
            }
            
            ; 确保所有字段都有值并正确类型
            sourceApp := rowData.Has("SourceApp") && rowData["SourceApp"] != "" ? String(rowData["SourceApp"]) : "Unknown"
            dataType := rowData.Has("DataType") && rowData["DataType"] != "" ? String(rowData["DataType"]) : "Text"
            
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
            
            ; 添加行（确保数据类型正确）
            rowIndex := HistoryListView.Add(, 
                String(index),            ; 序号
                String(preview),          ; 内容预览
                String(sourceApp),        ; 来源应用
                String(fileLocation),     ; 文件位置
                String(dataType),         ; 类型
                String(timeText),         ; 最后复制时间
                String(copyCount),        ; 复制次数
                String(charCount))        ; 字符数
        }
        
        ; 恢复重绘
        HistoryListView.Opt("+Redraw")
    }
}

; ===================== 搜索框变化事件（带防抖）=====================
OnHistorySearchChange(*) {
    global HistorySearchEdit, HistorySearchTimer
    
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
    global HistorySearchEdit
    keyword := HistorySearchEdit.Value
    RefreshHistoryData(keyword)
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
            keyword := HistorySearchEdit.Value
            RefreshHistoryData(keyword)
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
        keyword := HistorySearchEdit.Value
        RefreshHistoryData(keyword)
    }
}

; ===================== 更新标签按钮样式 =====================
UpdateHistoryTagButtons() {
    global HistoryTagButtons, HistorySelectedTag, HistoryColors
    
    ; 遍历所有标签按钮
    for tagType, button in HistoryTagButtons {
        if (HistorySelectedTag = tagType) {
            ; 选中状态：使用激活颜色
            try {
                button.Opt("Background" . HistoryColors.TagBgActive)
                button.Opt("c" . HistoryColors.TagTextActive)
            }
        } else {
            ; 未选中状态：使用默认颜色
            try {
                button.Opt("Background" . HistoryColors.TagBg)
                button.Opt("c" . HistoryColors.TagText)
            }
        }
    }
}

; ===================== ListView 项选择事件 =====================
OnHistoryItemSelect(*) {
    global HistoryListView, HistoryDisplayCache
    
    selectedRow := HistoryListView.GetNext()
    if (selectedRow > 0 && selectedRow <= HistoryDisplayCache.Length) {
        rowData := HistoryDisplayCache[selectedRow]
        
        ; 显示详细信息（工具提示）
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

; ===================== ListView 双击事件 =====================
OnHistoryItemDoubleClick(*) {
    global HistoryListView, HistoryDisplayCache
    
    selectedRow := HistoryListView.GetNext()
    if (selectedRow > 0 && selectedRow <= HistoryDisplayCache.Length) {
        rowData := HistoryDisplayCache[selectedRow]
        
        ; 复制内容到剪贴板
        if (rowData.Has("Content")) {
            A_Clipboard := rowData["Content"]
            TrayTip("已复制", "内容已复制到剪贴板", "Iconi 1")
            
            ; 刷新数据（将刚复制的项移到最前面）
            RefreshHistoryData()
        }
    }
}

; ===================== 窗口大小改变事件 =====================
OnHistoryPanelSize(*) {
    global GuiID_ClipboardHistory, HistoryListView, HistorySearchEdit, HistoryTagButtons
    
    ; 获取窗口大小
    GuiID_ClipboardHistory.GetPos(,, &width, &height)
    
    ; 调整搜索框宽度
    HistorySearchEdit.Move(,, width - 20)
    
    ; 调整标签按钮位置（如果需要的话，可以保持左对齐）
    ; 标签按钮保持原位置，不随窗口大小改变
    
    ; 调整 ListView 宽度和高度（为标签区域留出空间）
    listHeight := height - 110  ; 90（ListView起始Y）+ 20（底部状态栏）
    HistoryListView.Move(,, width - 20, listHeight)
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
        
        ; 创建颜色块按钮
        colorBtn := ColorSummaryGUI.Add("Button", 
            "x" . x . " y" . y . 
            " w" . blockSize . " h" . blockSize . 
            " Background" . colorItem["hex"] . 
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

; ===================== 初始化 =====================
InitClipboardHistoryPanel() {
    ; 确保数据库已初始化
    if (!ClipboardFTS5DB || ClipboardFTS5DB = 0) {
        InitClipboardFTS5DB()
    }
}
