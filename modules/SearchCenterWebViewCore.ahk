#Requires AutoHotkey v2.0

global g_SCWV_Gui := 0
global g_SCWV_Ctrl := 0
global g_SCWV_WV2 := 0
global g_SCWV_Ready := false
global g_SCWV_Visible := false
global g_SCWV_SearchTimer := 0
global g_SCWV_FocusPending := false
global SearchCenterWebKeyword := ""

SearchCenter_ShouldUseWebView() {
    return true
}

SCWV_IsVisible() {
    global g_SCWV_Visible
    return g_SCWV_Visible
}

SCWV_GetGui() {
    global g_SCWV_Gui
    return g_SCWV_Gui
}

SCWV_GetGuiHwnd() {
    global g_SCWV_Gui
    if g_SCWV_Gui {
        try return g_SCWV_Gui.Hwnd
    }
    return 0
}

SCWV_Init() {
    global g_SCWV_Gui

    if g_SCWV_Gui
        return

    g_SCWV_Gui := Gui("+AlwaysOnTop +Resize +MinSize760x540 +MinimizeBox +MaximizeBox +Caption -DPIScale +Owner", "搜索中心")
    g_SCWV_Gui.BackColor := "1b1b1d"
    g_SCWV_Gui.MarginX := 0
    g_SCWV_Gui.MarginY := 0
    g_SCWV_Gui.OnEvent("Close", SCWV_OnGuiClose)
    g_SCWV_Gui.OnEvent("Size", SCWV_OnGuiResize)
    g_SCWV_Gui.Show("w1180 h760 Hide")

    WebView2.create(g_SCWV_Gui.Hwnd, SCWV_OnCreated)

    _SCWV_EnsureCurrentCategoryState()
    _SCWV_EnsureSearchDataReady()
}

SCWV_OnCreated(ctrl) {
    global g_SCWV_Ctrl, g_SCWV_WV2

    g_SCWV_Ctrl := ctrl
    g_SCWV_WV2 := ctrl.CoreWebView2

    try g_SCWV_Ctrl.DefaultBackgroundColor := 0xFF1B1B1D
    try g_SCWV_Ctrl.IsVisible := true

    SCWV_ApplyBounds()

    s := g_SCWV_WV2.Settings
    s.AreDefaultContextMenusEnabled := false
    s.IsStatusBarEnabled := false
    s.AreDevToolsEnabled := false

    g_SCWV_WV2.add_WebMessageReceived(SCWV_OnWebMessage)
    try g_SCWV_WV2.add_NavigationCompleted(SCWV_OnNavigationCompleted)

    try ApplyUnifiedWebViewAssets(g_SCWV_WV2)
    g_SCWV_WV2.Navigate(BuildAppLocalUrl("SearchCenter.html"))
}

SCWV_OnGuiClose(*) {
    SCWV_Hide(true)
}

SCWV_OnGuiResize(GuiObj, MinMax, Width, Height) {
    if (MinMax = -1)
        return
    SCWV_ApplyBounds()
}

SCWV_OnNavigationCompleted(sender, args) {
    global g_SCWV_Visible

    if !g_SCWV_Visible
        return

    try ok := args.IsSuccess
    catch {
        ok := true
    }
    if !ok
        return

    SCWV_RefreshComposition()
}

SCWV_ApplyBounds() {
    global g_SCWV_Gui, g_SCWV_Ctrl

    if !g_SCWV_Gui || !g_SCWV_Ctrl
        return

    WinGetClientPos(, , &cw, &ch, g_SCWV_Gui.Hwnd)
    rc := WebView2.RECT()
    rc.left := 0
    rc.top := 0
    rc.right := cw
    rc.bottom := ch
    g_SCWV_Ctrl.Bounds := rc
}

SCWV_RefreshComposition(*) {
    global g_SCWV_Gui, g_SCWV_Ctrl, g_SCWV_Visible

    if !g_SCWV_Visible || !g_SCWV_Gui || !g_SCWV_Ctrl
        return

    try {
        SCWV_ApplyBounds()
        g_SCWV_Ctrl.NotifyParentWindowPositionChanged()
    } catch {
    }
}

SCWV_Show() {
    global g_SCWV_Gui, g_SCWV_Visible, g_SCWV_Ready, g_SCWV_Ctrl, GuiID_SearchCenter

    if !g_SCWV_Gui
        SCWV_Init()

    GuiID_SearchCenter := g_SCWV_Gui

    if g_SCWV_Visible {
        try WinActivate("ahk_id " . g_SCWV_Gui.Hwnd)
        WebView2_MoveFocusProgrammatic(g_SCWV_Ctrl)
        SetTimer(_SCWV_DeferredMoveFocus100, -100)
        return
    }

    g_SCWV_Gui.Show("w1180 h760 Center")
    g_SCWV_Visible := true
    OnMessage(0x0006, SCWV_WM_ACTIVATE)

    SCWV_RefreshComposition()
    SetTimer(SCWV_RefreshComposition, -120)
    SetTimer(SCWV_RefreshComposition, -380)

    if g_SCWV_Ready
        SCWV_PushState("init")
    else
        SetTimer(SCWV_DeferredPush, -250)

    WebView2_MoveFocusProgrammatic(g_SCWV_Ctrl)
    SetTimer(_SCWV_DeferredMoveFocus100, -100)
    SetTimer(SCWV_FocusDeferred, -80)
    SCWV_RequestFocusInput()
}

_SCWV_DeferredMoveFocus100(*) {
    global g_SCWV_Gui, g_SCWV_Visible, g_SCWV_Ctrl
    if g_SCWV_Visible && g_SCWV_Gui
        WebView2_MoveFocusProgrammatic(g_SCWV_Ctrl)
}

SCWV_DeferredPush(*) {
    global g_SCWV_Visible, g_SCWV_Ready

    if !g_SCWV_Visible
        return

    if g_SCWV_Ready {
        SCWV_PushState("init")
    } else {
        SetTimer(SCWV_DeferredPush, -350)
    }
}

SCWV_FocusDeferred(*) {
    global g_SCWV_Gui, g_SCWV_Visible, g_SCWV_Ctrl

    if g_SCWV_Visible && g_SCWV_Gui {
        try WinActivate("ahk_id " . g_SCWV_Gui.Hwnd)
        WebView2_MoveFocusProgrammatic(g_SCWV_Ctrl)
    }
}

SCWV_RequestFocusInput() {
    global g_SCWV_WV2, g_SCWV_Ready, g_SCWV_FocusPending
    if g_SCWV_WV2 && g_SCWV_Ready {
        WebView_QueueJson(g_SCWV_WV2, '{"type":"focus_input"}')
        g_SCWV_FocusPending := false
        return
    }
    g_SCWV_FocusPending := true
}

SCWV_Hide(PersistSelection := true) {
    global g_SCWV_Gui, g_SCWV_Visible, g_SCWV_SearchTimer, GuiID_SearchCenter

    if PersistSelection
        _SCWV_SaveCurrentCategorySelection()

    if g_SCWV_SearchTimer {
        SetTimer(g_SCWV_SearchTimer, 0)
        g_SCWV_SearchTimer := 0
    }

    g_SCWV_Visible := false
    OnMessage(0x0006, SCWV_WM_ACTIVATE, 0)
    GuiID_SearchCenter := 0
    SearchCenterInvalidateGuiControlRefs()

    if g_SCWV_Gui {
        try g_SCWV_Gui.Hide()
    }
}

SCWV_WM_ACTIVATE(wParam, lParam, msg, hwnd) {
    global g_SCWV_Gui, g_SCWV_Visible

    if !g_SCWV_Visible || !g_SCWV_Gui
        return

    if (hwnd = g_SCWV_Gui.Hwnd && (wParam & 0xFFFF) = 0)
        SetTimer(() => SCWV_Hide(true), -50)
}

SCWV_PostJson(jsonStr) {
    global g_SCWV_WV2, g_SCWV_Ready

    if !(g_SCWV_WV2 && g_SCWV_Ready)
        return
    if (IsObject(jsonStr))
        WebView_QueuePayload(g_SCWV_WV2, jsonStr)
    else
        WebView_QueueJson(g_SCWV_WV2, jsonStr)
}

SCWV_OnWebMessage(sender, args) {
    jsonStr := args.WebMessageAsJson
    try {
        msg := Jxon_Load(jsonStr)
    } catch {
        return
    }

    if (msg is String) {
        try msg := Jxon_Load(msg)
        catch {
            return
        }
    }
    if !(msg is Map)
        return

    action := msg.Has("type") ? msg["type"] : (msg.Has("action") ? msg["action"] : "")
    if (action = "")
        return

    switch action {
        case "ready":
            global g_SCWV_Ready
            g_SCWV_Ready := true
            SCWV_PushState("init")
            if g_SCWV_FocusPending
                SCWV_RequestFocusInput()
        case "search":
            keyword := msg.Has("keyword") ? String(msg["keyword"]) : ""
            _SCWV_PerformSearch(keyword)
            SCWV_PushState("state")
        case "setCategory":
            if msg.Has("category")
                _SCWV_SetCategoryByKey(String(msg["category"]))
            SCWV_PushState("state")
        case "setFilter":
            global SearchCenterFilterType
            nextFilter := msg.Has("filterType") ? String(msg["filterType"]) : ""
            SearchCenterFilterType := (SearchCenterFilterType = nextFilter) ? "" : nextFilter
            SCWV_PushState("state")
        case "setLimit":
            global SearchCenterCurrentLimit, SearchCenterEverythingLimit
            val := msg.Has("limit") ? Integer(msg["limit"]) : 50
            if (val <= 0)
                val := 50
            SearchCenterCurrentLimit := val
            SearchCenterEverythingLimit := val
            _SCWV_PerformSearch(SearchCenterWebKeyword)
            SCWV_PushState("state")
        case "loadMore":
            offset := msg.Has("offset") ? Integer(msg["offset"]) : 0
            if (offset < 0)
                offset := 0
            _SCWV_PerformSearch(SearchCenterWebKeyword, offset)
            SCWV_PushState("state")
        case "toggleEngine":
            if msg.Has("engine")
                _SCWV_ToggleEngine(String(msg["engine"]))
            SCWV_PushState("state")
        case "batchSearch":
            _SCWV_BatchSearch()
        case "cliSend":
            prompt := msg.Has("prompt") ? String(msg["prompt"]) : ""
            _SCWV_SendToCLI(prompt)
        case "cliOpen":
            OpenSelectedCLIAgents()
        case "activateResult":
            row := msg.Has("row") ? Integer(msg["row"]) : 0
            _SCWV_ActivateResultRow(row)
        case "close":
            SCWV_Hide(true)
    }
}

SCWV_QueueSearch(keyword) {
    global g_SCWV_SearchTimer, SearchCenterWebKeyword

    SearchCenterWebKeyword := keyword

    if g_SCWV_SearchTimer {
        SetTimer(g_SCWV_SearchTimer, 0)
        g_SCWV_SearchTimer := 0
    }

    fn := _SCWV_FireSearch.Bind()
    g_SCWV_SearchTimer := fn
    SetTimer(fn, -150)
}

_SCWV_FireSearch(*) {
    global g_SCWV_SearchTimer, SearchCenterWebKeyword

    g_SCWV_SearchTimer := 0
    _SCWV_PerformSearch(SearchCenterWebKeyword)
    SCWV_PushState("state")
}

_SCWV_PerformSearch(keyword, offset := 0) {
    global SearchCenterSearchResults, SearchCenterCurrentLimit, SearchCenterHasMoreData, SearchCenterFilterType

    keyword := Trim(String(keyword))

    if (offset = 0)
        SearchCenterSearchResults := []

    if (keyword = "") {
        SearchCenterHasMoreData := false
        _SCWV_LoadDefaultTemplatesData()
        return
    }

    NewResults := []
    SearchCenterHasMoreData := false

    try {
        FilterDataTypes := GetSearchCenterDataTypesForFilter(SearchCenterFilterType)
        if (FilterDataTypes.Length > 0) {
            hasFileType := false
            for _, dt in FilterDataTypes {
                if (dt = "file") {
                    hasFileType := true
                    break
                }
            }
            if !hasFileType
                FilterDataTypes.Push("file")
        }

        AllDataResults := SearchAllDataSources(keyword, FilterDataTypes, SearchCenterCurrentLimit, offset)
        for _, TypeData in AllDataResults {
            if (IsObject(TypeData) && TypeData.HasProp("HasMore") && TypeData.HasMore) {
                SearchCenterHasMoreData := true
                break
            }
        }

        for DataType, TypeData in AllDataResults {
            if !(IsObject(TypeData) && TypeData.HasProp("Items"))
                continue

            for _, Item in TypeData.Items {
                TimeDisplay := ""
                if (Item.HasProp("TimeFormatted")) {
                    TimeDisplay := Item.TimeFormatted
                } else if (Item.HasProp("Timestamp")) {
                    try {
                        TimeDisplay := FormatTime(Item.Timestamp, "yyyy-MM-dd HH:mm:ss")
                    } catch {
                        TimeDisplay := Item.Timestamp
                    }
                }

                TitleText := ""
                if (Item.HasProp("DisplayTitle") && Item.DisplayTitle != "") {
                    TitleText := Item.DisplayTitle
                } else if (Item.HasProp("Title") && Item.Title != "") {
                    TitleText := Item.Title
                } else if (Item.HasProp("Content") && Item.Content != "") {
                    TitleText := SubStr(Item.Content, 1, 50)
                    if (StrLen(Item.Content) > 50)
                        TitleText .= "..."
                }

                ItemDataType := ""
                if (Item.HasProp("Metadata") && IsObject(Item.Metadata) && Item.Metadata.Has("DataType") && Item.Metadata["DataType"] != "") {
                    ItemDataType := Item.Metadata["DataType"]
                } else if (Item.HasProp("DataType") && Item.DataType != "") {
                    if (Item.DataType != "clipboard" && Item.DataType != "template" && Item.DataType != "config" && Item.DataType != "file" && Item.DataType != "hotkey" && Item.DataType != "function" && Item.DataType != "ui")
                        ItemDataType := Item.DataType
                }

                if (ItemDataType = "" && DataType = "clipboard") {
                    if (Item.HasProp("DataTypeName") && Item.DataTypeName != "") {
                        DataTypeName := Item.DataTypeName
                        if (DataTypeName = "代码片段" || DataTypeName = "代码")
                            ItemDataType := "Code"
                        else if (DataTypeName = "链接")
                            ItemDataType := "Link"
                        else if (DataTypeName = "邮箱" || DataTypeName = "邮件")
                            ItemDataType := "Email"
                        else if (DataTypeName = "图片")
                            ItemDataType := "Image"
                        else if (DataTypeName = "颜色")
                            ItemDataType := "Color"
                        else if (DataTypeName = "文本" || DataTypeName = "剪贴板历史")
                            ItemDataType := "Text"
                    }
                }

                if (ItemDataType = "" && DataType != "clipboard") {
                    if (DataType = "template")
                        ItemDataType := "Template"
                    else if (DataType = "config")
                        ItemDataType := "Config"
                    else if (DataType = "file")
                        ItemDataType := "File"
                    else if (DataType = "hotkey")
                        ItemDataType := "Hotkey"
                    else if (DataType = "function")
                        ItemDataType := "Function"
                    else if (DataType = "ui")
                        ItemDataType := "UI"
                }

                if (ItemDataType = "")
                    ItemDataType := (DataType = "clipboard") ? "Text" : DataType

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

                if (offset = 0)
                    SearchCenterSearchResults.Push(ResultItem)
                else
                    NewResults.Push(ResultItem)
            }
        }
    } catch as err {
        OutputDebug("SCWV search error: " . err.Message)
    }

    if (offset > 0 && NewResults.Length > 0) {
        for _, item in NewResults
            SearchCenterSearchResults.Push(item)
    }

    if (offset = 0 && SearchCenterSearchResults.Length > 0 && StrLen(keyword) > 0) {
        try {
            Loop SearchCenterSearchResults.Length {
                scItem := SearchCenterSearchResults[A_Index]
                SyncIdentityToResultItem(&scItem, keyword)
            }
        } catch {
        }
    }

    if (offset = 0 && SearchCenterSearchResults.Length > 0) {
        try SortSearchCenterMergedResults(&SearchCenterSearchResults, keyword)
    }
}

_SCWV_LoadDefaultTemplatesData() {
    global SearchCenterSearchResults, PromptTemplates

    SearchCenterSearchResults := []
    if !PromptTemplates
        LoadPromptTemplates()

    for template in PromptTemplates {
        SearchCenterSearchResults.Push({
            Title: template.Title,
            Content: template.Content,
            Source: "模板",
            DataType: "template",
            Time: "",
            OriginalDataType: "template"
        })
    }
}

_SCWV_GetFilteredResults() {
    global SearchCenterSearchResults, SearchCenterVisibleResults, SearchCenterFilterType

    FilteredResults := []
    for _, res in SearchCenterSearchResults {
        ShouldInclude := false
        if (SearchCenterFilterType = "") {
            ShouldInclude := true
        } else if (SearchCenterFilterType = "clipboard") {
            ShouldInclude := (res.HasProp("OriginalDataType") && res.OriginalDataType = "clipboard") || (res.HasProp("Source") && InStr(res.Source, "剪贴板") > 0)
        } else if (SearchCenterFilterType = "template") {
            ShouldInclude := (res.HasProp("OriginalDataType") && res.OriginalDataType = "template") || (res.HasProp("Source") && (InStr(res.Source, "模板") > 0 || InStr(res.Source, "提示词") > 0))
        } else if (SearchCenterFilterType = "config") {
            ShouldInclude := (res.HasProp("OriginalDataType") && res.OriginalDataType = "config") || (res.HasProp("Source") && InStr(res.Source, "配置") > 0)
        } else if (SearchCenterFilterType = "hotkey") {
            ShouldInclude := (res.HasProp("OriginalDataType") && res.OriginalDataType = "hotkey") || (res.HasProp("Source") && InStr(res.Source, "快捷键") > 0)
        } else if (SearchCenterFilterType = "function") {
            ShouldInclude := (res.HasProp("OriginalDataType") && res.OriginalDataType = "function") || (res.HasProp("Source") && InStr(res.Source, "功能") > 0)
        } else if (SearchCenterFilterType = "File") {
            ShouldInclude := (res.HasProp("OriginalDataType") && res.OriginalDataType = "file") || (res.HasProp("DataType") && res.DataType = "File") || (res.HasProp("Source") && InStr(res.Source, "文件") > 0)
        }

        if ShouldInclude
            FilteredResults.Push(res)
    }

    SearchCenterVisibleResults := FilteredResults
    return FilteredResults
}

SCWV_PushState(msgType := "state") {
    global SearchCenterWebKeyword, SearchCenterCurrentLimit, SearchCenterSelectedEngines, SearchCenterFilterType
    global SearchCenterHasMoreData

    if !SearchCenter_ShouldUseWebView()
        return

    visible := _SCWV_GetFilteredResults()
    results := []
    for index, item in visible {
        rowTitle := (item.HasProp("DisplayTitle") && item.DisplayTitle != "") ? item.DisplayTitle : item.Title
        rowSubtitle := (item.HasProp("DisplaySubtitle") && item.DisplaySubtitle != "") ? item.DisplaySubtitle : item.Source
        typeDisplay := item.HasProp("DataType") ? item.DataType : ""
        if (item.HasProp("OriginalDataType") && item.OriginalDataType = "file" && item.HasProp("Category") && item.Category != "") {
            try typeDisplay := FileClassifier.GetCategoryDisplayName(item.Category)
        } else if (typeDisplay != "") {
            try typeDisplay := GetContentTypeDisplayName(typeDisplay)
        }
        results.Push(Map(
            "row", index,
            "title", rowTitle,
            "subtitle", rowSubtitle,
            "type", typeDisplay,
            "time", item.HasProp("Time") ? item.Time : "",
            "preview", item.HasProp("Content") ? SubStr(item.Content, 1, 180) : rowTitle,
            "previewText", BuildSearchCenterPreviewText(item),
            "dataType", item.HasProp("DataType") ? item.DataType : "",
            "source", item.HasProp("Source") ? item.Source : "",
            "content", item.HasProp("Content") ? item.Content : rowTitle
        ))
    }

    currentCategoryKey := GetSearchCenterCurrentCategoryKey()
    status := "本地结果 " . results.Length . " 条"
    status .= " · 已选引擎 " . (IsObject(SearchCenterSelectedEngines) ? SearchCenterSelectedEngines.Length : 0) . " 个"
    status .= " · 当前限制 " . SearchCenterCurrentLimit

    payload := Map(
        "type", msgType,
        "keyword", SearchCenterWebKeyword,
        "limit", SearchCenterCurrentLimit,
        "categories", _SCWV_BuildCategoryPayload(),
        "currentCategoryKey", currentCategoryKey,
        "engines", _SCWV_BuildEnginePayload(currentCategoryKey),
        "selectedEngines", _SCWV_CopyArray(SearchCenterSelectedEngines),
        "filters", _SCWV_BuildFilterPayload(),
        "filterType", SearchCenterFilterType,
        "results", results,
        "statusLine", status,
        "isCliCategory", (currentCategoryKey = "cli") ? true : false,
        "canRun", Trim(SearchCenterWebKeyword) != "",
        "canOpenCli", (currentCategoryKey = "cli") ? true : false,
        "hasMore", SearchCenterHasMoreData ? true : false,
        "total", results.Length
    )

    try SCWV_PostJson(payload)
}

_SCWV_BuildFilterPayload() {
    return [
        Map("key", "", "text", "全部"),
        Map("key", "File", "text", "文件"),
        Map("key", "clipboard", "text", "剪贴板"),
        Map("key", "template", "text", "提示词"),
        Map("key", "config", "text", "配置"),
        Map("key", "hotkey", "text", "快捷键"),
        Map("key", "function", "text", "功能")
    ]
}

_SCWV_BuildCategoryPayload() {
    Categories := GetSearchCenterCategories()
    payload := []
    for _, Category in Categories {
        engines := _SCWV_LoadSelectedEngines(Category.Key)
        payload.Push(Map(
            "key", Category.Key,
            "text", Category.Text,
            "selectedCount", engines.Length
        ))
    }
    return payload
}

_SCWV_BuildEnginePayload(CategoryKey) {
    engines := GetSortedSearchEngines(CategoryKey)
    payload := []
    for _, engine in engines {
        iconPath := GetSearchEngineIcon(engine.Value)
        payload.Push(Map(
            "name", engine.Name,
            "value", engine.Value,
            "iconUrl", _SCWV_PathToWebAssetUrl(iconPath)
        ))
    }
    return payload
}

_SCWV_PathToWebAssetUrl(path) {
    p := Trim(path)
    if (p = "" || !FileExist(p))
        return ""

    scriptRoot := StrReplace(A_ScriptDir, "\", "/")
    normalized := StrReplace(p, "\", "/")
    scriptRootWithSlash := scriptRoot . "/"
    if (SubStr(normalized, 1, StrLen(scriptRootWithSlash)) = scriptRootWithSlash) {
        relativePath := SubStr(normalized, StrLen(scriptRootWithSlash) + 1)
        return BuildAppAssetUrl(relativePath)
    }

    return ""
}

_SCWV_CopyArray(arr) {
    out := []
    if !IsObject(arr)
        return out
    for _, v in arr
        out.Push(v)
    return out
}

_SCWV_EnsureCurrentCategoryState() {
    global SearchCenterSelectedEngines

    Categories := GetSearchCenterCategories()
    if (Categories.Length = 0)
        return

    currentKey := GetSearchCenterCurrentCategoryKey()
    SearchCenterSelectedEngines := _SCWV_LoadSelectedEngines(currentKey)
}

_SCWV_SaveCurrentCategorySelection() {
    global SearchCenterSelectedEngines

    CategoryKey := GetSearchCenterCurrentCategoryKey()
    _SCWV_SaveSelectedEngines(CategoryKey, SearchCenterSelectedEngines)
}

_SCWV_SetCategoryByKey(CategoryKey) {
    global SearchCenterCurrentCategory, SearchCenterSelectedEngines

    _SCWV_SaveCurrentCategorySelection()

    Categories := GetSearchCenterCategories()
    for index, Category in Categories {
        if (Category.Key = CategoryKey) {
            SearchCenterCurrentCategory := index - 1
            break
        }
    }
    SearchCenterSelectedEngines := _SCWV_LoadSelectedEngines(CategoryKey)
}

_SCWV_LoadSelectedEngines(CategoryKey) {
    global SearchCenterSelectedEnginesByCategory, ConfigFile

    if (!IsSet(SearchCenterSelectedEnginesByCategory) || !IsObject(SearchCenterSelectedEnginesByCategory))
        SearchCenterSelectedEnginesByCategory := Map()

    if (SearchCenterSelectedEnginesByCategory.Has(CategoryKey))
        return _SCWV_CopyArray(SearchCenterSelectedEnginesByCategory[CategoryKey])

    Engines := []
    try {
        CategoryEnginesStr := IniRead(ConfigFile, "Settings", "SearchCenterSelectedEngines_" . CategoryKey, "")
        if (CategoryEnginesStr != "") {
            if (InStr(CategoryEnginesStr, ":") > 0)
                CategoryEnginesStr := SubStr(CategoryEnginesStr, InStr(CategoryEnginesStr, ":") + 1)
            for _, Engine in StrSplit(CategoryEnginesStr, ",") {
                Engine := Trim(Engine)
                if (Engine != "")
                    Engines.Push(Engine)
            }
        }
    } catch {
    }

    if (Engines.Length = 0 && CategoryKey = "cli")
        Engines := ["codex_cli"]

    SearchCenterSelectedEnginesByCategory[CategoryKey] := _SCWV_CopyArray(Engines)
    return Engines
}

_SCWV_SaveSelectedEngines(CategoryKey, Engines) {
    global SearchCenterSelectedEnginesByCategory, ConfigFile

    if (!IsSet(SearchCenterSelectedEnginesByCategory) || !IsObject(SearchCenterSelectedEnginesByCategory))
        SearchCenterSelectedEnginesByCategory := Map()

    SearchCenterSelectedEnginesByCategory[CategoryKey] := _SCWV_CopyArray(Engines)

    EnginesStr := ""
    if IsObject(Engines) {
        for index, Engine in Engines {
            if (index > 1)
                EnginesStr .= ","
            EnginesStr .= Engine
        }
    }
    try IniWrite(CategoryKey . ":" . EnginesStr, ConfigFile, "Settings", "SearchCenterSelectedEngines_" . CategoryKey)
}

_SCWV_ToggleEngine(EngineValue) {
    global SearchCenterSelectedEngines

    CategoryKey := GetSearchCenterCurrentCategoryKey()
    if !IsObject(SearchCenterSelectedEngines)
        SearchCenterSelectedEngines := []

    idx := ArrayContainsValue(SearchCenterSelectedEngines, EngineValue)
    if (CategoryKey = "cli") {
        if (idx > 0)
            SearchCenterSelectedEngines.RemoveAt(idx)
        else
            SearchCenterSelectedEngines := [EngineValue]
    } else if (idx > 0) {
        SearchCenterSelectedEngines.RemoveAt(idx)
    } else {
        SearchCenterSelectedEngines.Push(EngineValue)
    }

    _SCWV_SaveSelectedEngines(CategoryKey, SearchCenterSelectedEngines)
}

_SCWV_EnsureSearchDataReady() {
    global SearchCenterSearchResults, SearchCenterWebKeyword

    if (Trim(SearchCenterWebKeyword) = "") {
        if !IsObject(SearchCenterSearchResults) || SearchCenterSearchResults.Length = 0
            _SCWV_LoadDefaultTemplatesData()
        return
    }

    if !IsObject(SearchCenterSearchResults) || SearchCenterSearchResults.Length = 0
        _SCWV_PerformSearch(SearchCenterWebKeyword)
}

_SCWV_BatchSearch() {
    global SearchCenterSelectedEngines, SearchCenterWebKeyword

    Keyword := Trim(SearchCenterWebKeyword)
    if (Keyword = "") {
        TrayTip("请输入搜索关键词", "提示", "Icon! 2")
        return
    }
    if (!IsObject(SearchCenterSelectedEngines) || SearchCenterSelectedEngines.Length = 0) {
        TrayTip("请至少选择一个搜索引擎", "提示", "Icon! 2")
        return
    }

    for index, Engine in SearchCenterSelectedEngines {
        if (Engine = "")
            continue
        SendVoiceSearchToBrowser(Keyword, Engine)
        if (index < SearchCenterSelectedEngines.Length)
            Sleep(300)
    }
}

_SCWV_SendToCLI(prompt) {
    global SearchCenterWebKeyword

    if (Trim(prompt) = "")
        prompt := Trim(SearchCenterWebKeyword)

    if (prompt = "") {
        TrayTip("请输入要发送给 AI 的内容", "提示", "Icon! 2")
        return
    }

    LaunchSelectedCLIAgents(prompt)
}

_SCWV_ActivateResultRow(Row) {
    Item := GetSearchCenterResultItemByRow(Row)
    if !IsObject(Item)
        return

    Content := Item.HasProp("Content") ? Item.Content : Item.Title
    DataType := ""
    if (Item.HasProp("DataType") && Item.DataType != "") {
        DataType := Item.DataType
    } else if (Item.HasProp("Metadata") && IsObject(Item.Metadata) && Item.Metadata.Has("DataType")) {
        DataType := Item.Metadata["DataType"]
    }

    origDt := Item.HasProp("OriginalDataType") ? Item.OriginalDataType : ""
    isFileLike := (DataType = "file" || DataType = "File" || DataType = "Folder" || origDt = "file")

    SCWV_Hide(true)
    Sleep(60)

    if (isFileLike) {
        try {
            if (FileExist(Content) || DirExist(Content))
                Run(Content)
            else
                TrayTip("路径不存在", Content, "Iconx 2")
        } catch as err {
            TrayTip("打开失败", err.Message, "Iconx 2")
        }
        return
    }

    if (DataType = "Link") {
        try Run(Content)
        catch as err {
            TrayTip("打开链接失败", err.Message, "Iconx 2")
        }
        return
    }

    if (DataType = "Image") {
        try {
            if FileExist(Content)
                Run(Content)
            else
                TrayTip("图片文件不存在", Content, "Iconx 2")
        } catch as err {
            TrayTip("打开图片失败", err.Message, "Iconx 2")
        }
        return
    }

    try {
        A_Clipboard := Content
        Sleep(80)
        Send("^v")
    } catch as err {
        TrayTip("粘贴失败", err.Message, "Iconx 2")
    }
}
