; ======================================================================================================================
; Prompt Quick-Pad（原 AI 助手入口）：提示词快捷记录与粘贴
; 数据：A_ScriptDir "\prompts.json" 仅用户条目 [{title, tags, content, category?}]
; 列表展示 = 设置中快捷三项 + PromptTemplates + json 合并
; 对外保留：ShowAIListPanel / HideAIListPanel / InitAIListPanel 及 CursorHelper 使用的全局变量名
; ======================================================================================================================

#Requires AutoHotkey v2.0

global AIListPanelGUI := 0
global AIListPanelIsVisible := false
global AIListPanelItems := []  ; 兼容保留（不再使用 AI 引擎项）
global AIListPanelHoveredIndex := 0
global AIListPanelDragging := false
global AIListPanelDragStartX := 0
global AIListPanelDragStartY := 0
global AIListPanelWindowX := 0
global AIListPanelWindowY := 0
global AIListPanelWindowW := 520
global AIListPanelWindowH := 480
global AIListPanelIsMinimized := false
global AIListPanelSearchInput := 0
global AIListPanelEnterHotkey := 0
global AIListPanelEscHotkey := 0
global AIListPanelUserMoving := false
global AIListPanelIsResizing := false

; 以下全局仅为兼容旧 ini 键与脚本中可能的引用，固定为「竖排」逻辑
global AIListPanelIconOnlyMode := false
global AIListPanelIconModeX := 0
global AIListPanelIconModeY := 0
global AIListPanelIconModeW := 400
global AIListPanelIconModeH := 100
global AIListPanelLastWidth := 0
global AIListPanelLastRows := 0
global AIListPanelTitleBar := 0
global AIListPanelToggleBtn := 0
global AIListPanelSearchBtn := 0
global AIListPanelSelectedEngines := []
global AIListPanelCheckboxes := Map()
global AIListPanelUserResizing := false

global PromptQuickPadData := []
global PromptQuickPadFilteredIdx := []
global PromptQuickPadListLV := 0
global PromptQuickPadStatusText := 0
global PromptQuickPadSearchDebounce := 0
global PromptQuickPadCaptureHotkeyObj := 0
global PromptQuickPadMergedSnapshot := []  ; 当前完整合并列表（与 FilteredIdx 下标对应）
global PromptQuickPadSelectedCategory := "全部"
global PromptQuickPadCategoryStrip := []  ; 分类标签控件，便于销毁
global PromptQuickPadCategoryCtrlByName := Map()
global PromptQuickPadLastCategorySig := ""
global PromptQuickPadCategoryStripHeight := 32
global PromptQuickPadDragBar := 0  ; 保留变量；已改用标准标题栏，不再创建拖动条

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

PromptQuickPad_JsonPath() => A_ScriptDir . "\prompts.json"

PromptQuickPad_TryGetText(Key, Fallback) {
    try
        return GetText(Key)
    catch
        return Fallback
}

PromptQuickPad_NormalizeEntry(m) {
    if !(m is Map)
        return Map("title", "", "tags", "", "content", "", "category", "", "hotkey", "")
    t := m.Has("title") ? String(m["title"]) : m.Has("Title") ? String(m["Title"]) : ""
    g := m.Has("tags") ? String(m["tags"]) : m.Has("Tags") ? String(m["Tags"]) : ""
    c := m.Has("content") ? String(m["content"]) : m.Has("Content") ? String(m["Content"]) : ""
    cat := m.Has("category") ? String(m["category"]) : m.Has("Category") ? String(m["Category"]) : ""
    hk := m.Has("hotkey") ? String(m["hotkey"]) : m.Has("Hotkey") ? String(m["Hotkey"]) : ""
    return Map("title", t, "tags", g, "content", c, "category", cat, "hotkey", hk)
}

PromptQuickPad_LoadFromDisk() {
    global PromptQuickPadData
    path := PromptQuickPad_JsonPath()
    PromptQuickPadData := []
    if !FileExist(path) {
        try FileAppend("[]", path, "UTF-8")
        return
    }
    try {
        raw := FileRead(path, "UTF-8")
        parsed := Jxon_Load(raw)
        if !(parsed is Array) {
            PromptQuickPadData := []
            return
        }
        for item in parsed {
            if item is Map
                PromptQuickPadData.Push(PromptQuickPad_NormalizeEntry(item))
        }
    } catch {
        PromptQuickPadData := []
    }
}

PromptQuickPad_SaveToDisk() {
    global PromptQuickPadData
    path := PromptQuickPad_JsonPath()
    try {
        clean := []
        for item in PromptQuickPadData {
            if !(item is Map)
                continue
            o := Map("title", item.Has("title") ? item["title"] : "", "tags", item.Has("tags") ? item["tags"] : "",
                "content", item.Has("content") ? item["content"] : "")
            if item.Has("category") && item["category"] != ""
                o["category"] := item["category"]
            if item.Has("hotkey") && item["hotkey"] != ""
                o["hotkey"] := item["hotkey"]
            clean.Push(o)
        }
        f := FileOpen(path, "w", "UTF-8")
        if !f
            return
        f.Write(Jxon_Dump(clean))
        f.Close()
    } catch {
    }
}

PromptQuickPad_TemplateExtraTags(T) {
    parts := ""
    fc := ""
    ser := ""
    try fc := T.FunctionCategory
    try ser := T.Series
    if fc != ""
        parts .= fc
    if ser != "" {
        if parts != ""
            parts .= ","
        parts .= ser
    }
    return parts
}

; 合并：设置页三项快捷词 + PromptTemplates.ini 加载的全局模板 + prompts.json 用户项
PromptQuickPad_BuildMergedList() {
    global PromptQuickPadData, PromptTemplates
    merged := []
    global Prompt_Explain, Prompt_Refactor, Prompt_Optimize

    capCat := "快捷操作"
    if Trim(Prompt_Explain) != "" {
        merged.Push(Map(
            "title", PromptQuickPad_TryGetText("quick_action_type_explain", "解释代码"),
            "category", capCat,
            "tags", "",
            "hotkey", "CapsLock+E",
            "content", Prompt_Explain,
            "source", "builtin",
            "userIndex", 0
        ))
    }
    if Trim(Prompt_Refactor) != "" {
        merged.Push(Map(
            "title", PromptQuickPad_TryGetText("quick_action_type_refactor", "重构代码"),
            "category", capCat,
            "tags", "",
            "hotkey", "CapsLock+R",
            "content", Prompt_Refactor,
            "source", "builtin",
            "userIndex", 0
        ))
    }
    if Trim(Prompt_Optimize) != "" {
        merged.Push(Map(
            "title", PromptQuickPad_TryGetText("quick_action_type_optimize", "优化代码"),
            "category", capCat,
            "tags", "",
            "hotkey", "CapsLock+O",
            "content", Prompt_Optimize,
            "source", "builtin",
            "userIndex", 0
        ))
    }

    if IsSet(PromptTemplates) && PromptTemplates is Array {
        for T in PromptTemplates {
            if !IsObject(T)
                continue
            title := ""
            content := ""
            cat := ""
            tid := ""
            try title := T.Title
            try content := T.Content
            try cat := T.Category
            try tid := T.ID
            if title = "" && content = ""
                continue
            merged.Push(Map(
                "title", title,
                "category", cat,
                "tags", PromptQuickPad_TemplateExtraTags(T),
                "hotkey", "",
                "content", content,
                "source", "template",
                "templateId", tid,
                "userIndex", 0
            ))
        }
    }

    idx := 0
    for item in PromptQuickPadData {
        idx++
        e := PromptQuickPad_NormalizeEntry(item)
        e["source"] := "json"
        e["userIndex"] := idx
        if !e.Has("category")
            e["category"] := ""
        if !e.Has("hotkey")
            e["hotkey"] := ""
        merged.Push(e)
    }
    return merged
}

PromptQuickPad_MakePreview(Text, MaxLen := 96) {
    s := RegExReplace(Text, "[\r\n\t]+", " ")
    s := Trim(s)
    if StrLen(s) > MaxLen
        s := SubStr(s, 1, MaxLen) . "…"
    return s
}

PromptQuickPad_UniqueCategoryTabs(merged) {
    hasUncat := false
    m := Map()
    for e in merged {
        c := e.Has("category") ? e["category"] : ""
        if c = ""
            hasUncat := true
        else
            m[c] := true
    }
    out := ["全部"]
    if hasUncat
        out.Push("未分类")
    blob := ""
    for k in m {
        if blob != ""
            blob .= "`n"
        blob .= k
    }
    if blob != "" {
        blob := Sort(blob, "D`n")
        for k in StrSplit(blob, "`n")
            out.Push(k)
    }
    return out
}

PromptQuickPad_CategorySignature(cats) {
    s := ""
    for c in cats {
        s .= c . "`n"
    }
    return s
}

PromptQuickPad_CategoryMatches(entry, Tab) {
    if Tab = "" || Tab = "全部"
        return true
    raw := entry.Has("category") ? entry["category"] : ""
    if Tab = "未分类"
        return raw = ""
    return raw = Tab
}

PromptQuickPad_ClearCategoryStrip() {
    global PromptQuickPadCategoryStrip, PromptQuickPadCategoryCtrlByName
    for c in PromptQuickPadCategoryStrip {
        try c.Destroy()
        catch {
        }
    }
    PromptQuickPadCategoryStrip := []
    PromptQuickPadCategoryCtrlByName := Map()
}

PromptQuickPad_StyleCategoryTabs() {
    global PromptQuickPadCategoryCtrlByName, PromptQuickPadSelectedCategory, AIListPanelColors
    for name, ctrl in PromptQuickPadCategoryCtrlByName {
        active := (name = PromptQuickPadSelectedCategory)
        bg := active ? AIListPanelColors.ItemActive : AIListPanelColors.ItemHover
        tc := active ? AIListPanelColors.TextHover : AIListPanelColors.Text
        try {
            ctrl.Opt("Background" . bg . " c" . tc)
        } catch {
        }
    }
}

PromptQuickPad_GetClientSize(hwnd, &cw, &ch) {
    rect := Buffer(16, 0)
    if !DllCall("GetClientRect", "ptr", hwnd, "ptr", rect)
        return false
    cw := NumGet(rect, 8, "int")
    ch := NumGet(rect, 12, "int")
    return true
}

; clientW/clientH 可传入 OnEvent("Size") 的客户端宽高；为 0 时用 GetClientRect
PromptQuickPad_RelayoutMainControls(clientW := 0, clientH := 0) {
    global AIListPanelGUI, AIListPanelSearchInput, PromptQuickPadListLV, PromptQuickPadStatusText
    global PromptQuickPadCategoryStripHeight
    if AIListPanelGUI = 0
        return
    if clientW <= 0 || clientH <= 0
        PromptQuickPad_GetClientSize(AIListPanelGUI.Hwnd, &clientW, &clientH)
    w := clientW
    h := clientH
    margin := 10
    topPad := 10
    searchH := 24
    statusH := 44
    bottomPad := 12
    catBlock := PromptQuickPadCategoryStripHeight > 8 ? PromptQuickPadCategoryStripHeight : 36
    searchY := topPad + catBlock + 10
    if AIListPanelSearchInput != 0
        AIListPanelSearchInput.Move(margin, searchY, w - margin * 2, searchH)
    lvY := searchY + searchH + margin
    lvH := h - lvY - statusH - bottomPad
    if lvH < 80
        lvH := 80
    if PromptQuickPadListLV != 0 {
        PromptQuickPadListLV.Move(margin, lvY, w - margin * 2, lvH)
        try {
            avail := w - margin * 2 - 120 - 72 - 88 - 8
            if avail < 100
                avail := 100
            PromptQuickPadListLV.ModifyCol(4, avail)
        } catch {
        }
    }
    if PromptQuickPadStatusText != 0
        PromptQuickPadStatusText.Move(margin, h - statusH - bottomPad, w - margin * 2, statusH)
}

PromptQuickPad_MakeCategoryHandler(CatName) {
    return (Ctrl, *) => PromptQuickPad_ApplyCategoryFilter(CatName)
}

PromptQuickPad_ApplyCategoryFilter(CatName) {
    global PromptQuickPadSelectedCategory
    PromptQuickPadSelectedCategory := CatName
    PromptQuickPad_StyleCategoryTabs()
    merged := PromptQuickPad_BuildMergedList()
    PromptQuickPad_FillListViewFromMerged(merged)
    PromptQuickPad_RelayoutMainControls()
}

PromptQuickPad_RefreshCategoryStrip(merged) {
    global AIListPanelGUI, PromptQuickPadLastCategorySig, PromptQuickPadSelectedCategory, AIListPanelColors
    global PromptQuickPadCategoryStripHeight, PromptQuickPadCategoryStrip, PromptQuickPadCategoryCtrlByName
    if AIListPanelGUI = 0
        return
    cats := PromptQuickPad_UniqueCategoryTabs(merged)
    sig := PromptQuickPad_CategorySignature(cats)
    if sig = PromptQuickPadLastCategorySig && PromptQuickPadCategoryStrip.Length > 0 {
        PromptQuickPad_StyleCategoryTabs()
        return
    }
    PromptQuickPadLastCategorySig := sig
    PromptQuickPad_ClearCategoryStrip()
    cw := 0
    ch := 0
    PromptQuickPad_GetClientSize(AIListPanelGUI.Hwnd, &cw, &ch)
    if cw < 200
        cw := 400
    margin := 10
    catY := 10
    rowY := catY
    x := margin
    maxRight := cw - margin
    chipH := 30
    gapX := 10
    gapY := 8
    for cat in cats {
        wch := Min(maxRight - margin, Max(52, StrLen(cat) * 9 + 28))
        if x + wch > maxRight && x > margin {
            x := margin
            rowY += chipH + gapY
        }
        bg := (cat = PromptQuickPadSelectedCategory) ? AIListPanelColors.ItemActive : AIListPanelColors.ItemHover
        tc := (cat = PromptQuickPadSelectedCategory) ? AIListPanelColors.TextHover : AIListPanelColors.Text
        t := AIListPanelGUI.Add("Text", "x" . x . " y" . rowY . " w" . wch . " h" . chipH . " Center 0x200 Background" . bg . " c" . tc, cat)
        t.SetFont("s10", "Segoe UI")
        t.OnEvent("Click", PromptQuickPad_MakeCategoryHandler(cat))
        PromptQuickPadCategoryStrip.Push(t)
        PromptQuickPadCategoryCtrlByName[cat] := t
        x += wch + gapX
    }
    PromptQuickPadCategoryStripHeight := (rowY - catY) + chipH + 10
    PromptQuickPad_StyleCategoryTabs()
}

PromptQuickPad_ValidateSelectedCategory(merged) {
    global PromptQuickPadSelectedCategory
    cats := PromptQuickPad_UniqueCategoryTabs(merged)
    ok := false
    for c in cats {
        if c = PromptQuickPadSelectedCategory {
            ok := true
            break
        }
    }
    if !ok
        PromptQuickPadSelectedCategory := "全部"
}

PromptQuickPad_MatchFilter(entry, needle) {
    if needle = ""
        return true
    t := entry.Has("title") ? entry["title"] : ""
    g := entry.Has("tags") ? entry["tags"] : ""
    c := entry.Has("content") ? entry["content"] : ""
    cat := entry.Has("category") ? entry["category"] : ""
    hk := entry.Has("hotkey") ? entry["hotkey"] : ""
    pv := PromptQuickPad_MakePreview(c, 200)
    if SubStr(needle, 1, 1) = "/" {
        endPos := InStr(needle, "/", , 2)
        if endPos >= 2 {
            pat := SubStr(needle, 2, endPos - 2)
            opt := ""
            rest := SubStr(needle, endPos + 1)
            if (rest = "i" || SubStr(rest, 1, 1) = "i")
                opt := "i)"
            try {
                return RegExMatch(t, opt . pat) || RegExMatch(g, opt . pat) || RegExMatch(cat, opt . pat)
                    || RegExMatch(c, opt . pat) || RegExMatch(hk, opt . pat)
            } catch {
                return false
            }
        }
    }
    n := StrLower(needle)
    return InStr(StrLower(t), n) || InStr(StrLower(g), n) || InStr(StrLower(cat), n) || InStr(StrLower(c), n)
        || InStr(StrLower(hk), n) || InStr(StrLower(pv), n)
}

PromptQuickPad_FillListViewFromMerged(merged) {
    global AIListPanelSearchInput, PromptQuickPadListLV, PromptQuickPadFilteredIdx, PromptQuickPadMergedSnapshot
    global PromptQuickPadStatusText, PromptQuickPadData, PromptQuickPadSelectedCategory
    if PromptQuickPadListLV = 0
        return
    needle := AIListPanelSearchInput != 0 ? Trim(AIListPanelSearchInput.Value) : ""
    PromptQuickPadMergedSnapshot := merged
    PromptQuickPadFilteredIdx := []
    PromptQuickPadListLV.Delete()
    row := 0
    for index, entry in merged {
        if !PromptQuickPad_CategoryMatches(entry, PromptQuickPadSelectedCategory)
            continue
        if !PromptQuickPad_MatchFilter(entry, needle)
            continue
        row++
        ccol := entry.Has("category") ? entry["category"] : ""
        hk := entry.Has("hotkey") ? entry["hotkey"] : ""
        cont := entry.Has("content") ? entry["content"] : ""
        prev := PromptQuickPad_MakePreview(cont)
        PromptQuickPadListLV.Add("", entry["title"], ccol, hk, prev)
        PromptQuickPadFilteredIdx.Push(index)
    }
    if PromptQuickPadStatusText != 0 {
        catDisp := PromptQuickPadSelectedCategory
        if StrLen(catDisp) > 18
            catDisp := SubStr(catDisp, 1, 18) . "…"
        PromptQuickPadStatusText.Value := "共 " . merged.Length . " 条 · prompts.json " . PromptQuickPadData.Length . " 条"
            . "`n「" . catDisp . "」显示 " . row . " 条 · 双击行粘贴 · 右键编辑"
    }
}

PromptQuickPad_RefreshListView(*) {
    global PromptQuickPadListLV, PromptQuickPadData
    if PromptQuickPadListLV = 0
        return
    merged := PromptQuickPad_BuildMergedList()
    PromptQuickPad_ValidateSelectedCategory(merged)
    PromptQuickPad_RefreshCategoryStrip(merged)
    PromptQuickPad_FillListViewFromMerged(merged)
    PromptQuickPad_RelayoutMainControls()
}

PromptQuickPad_OnSearchChange(*) {
    global PromptQuickPadSearchDebounce
    if PromptQuickPadSearchDebounce
        SetTimer(PromptQuickPadSearchDebounce, 0)
    PromptQuickPadSearchDebounce := PromptQuickPad_DebouncedRefresh
    SetTimer(PromptQuickPadSearchDebounce, -80)
}

PromptQuickPad_DebouncedRefresh(*) {
    global PromptQuickPadSearchDebounce
    PromptQuickPadSearchDebounce := 0
    PromptQuickPad_RefreshListView()
}

PromptQuickPad_GetFocusedRow() {
    global PromptQuickPadListLV
    if PromptQuickPadListLV = 0
        return 0
    r := PromptQuickPadListLV.GetNext(0, "Focused")
    if r = 0
        r := PromptQuickPadListLV.GetNext(0)
    return r
}

PromptQuickPad_PasteRow(row) {
    global PromptQuickPadFilteredIdx, PromptQuickPadMergedSnapshot
    if row < 1 || row > PromptQuickPadFilteredIdx.Length
        return
    srcIdx := PromptQuickPadFilteredIdx[row]
    if srcIdx < 1 || srcIdx > PromptQuickPadMergedSnapshot.Length
        return
    entry := PromptQuickPadMergedSnapshot[srcIdx]
    content := entry.Has("content") ? entry["content"] : ""
    if content = ""
        return
    A_Clipboard := ""
    A_Clipboard := content
    if !ClipWait(1.0) {
        TrayTip("剪贴板写入失败", "Prompt Quick-Pad", "Iconx 1")
        return
    }
    HideAIListPanel()
    Sleep(50)
    SendInput("^v")
}

PromptQuickPad_OnEnter(*) {
    row := PromptQuickPad_GetFocusedRow()
    if row > 0
        PromptQuickPad_PasteRow(row)
}

PromptQuickPad_OnEsc(*) {
    HideAIListPanel()
}

PromptQuickPad_OnDoubleClick(GuiCtrl, Item) {
    if Item >= 1
        PromptQuickPad_PasteRow(Item)
}

; ListView 右键/双击在部分环境下事件不可靠，用 WM_NOTIFY 兜底
PromptQuickPad_ListViewHitItemOneBased(LV) {
    if LV = 0
        return 0
    pt := Buffer(8, 0)
    DllCall("GetCursorPos", "int*", &gx := 0, "int*", &gy := 0)
    NumPut("int", gx, pt, 0)
    NumPut("int", gy, pt, 4)
    if !DllCall("ScreenToClient", "ptr", LV.Hwnd, "ptr", pt)
        return 0
    lx := NumGet(pt, 0, "int")
    ly := NumGet(pt, 4, "int")
    info := Buffer(24, 0)
    NumPut("int", lx, info, 0)
    NumPut("int", ly, info, 4)
    SendMessage(0x1012, 0, info, LV)
    idx := NumGet(info, 12, "int")
    if idx < 0
        return 0
    return idx + 1
}

PromptQuickPad_OnWmNotify(wParam, lParam, msg, hwnd) {
    global AIListPanelGUI, PromptQuickPadListLV
    if AIListPanelGUI = 0 || PromptQuickPadListLV = 0
        return
    if hwnd != AIListPanelGUI.Hwnd
        return
    hwndFrom := NumGet(lParam, 0, "ptr")
    if hwndFrom != PromptQuickPadListLV.Hwnd
        return
    code := NumGet(lParam, 2 * A_PtrSize, "int")
    nmSize := A_PtrSize = 8 ? 24 : 12
    iItem := NumGet(lParam, nmSize, "int")
    if code = -3 {  ; NM_DBLCLK
        if iItem >= 0
            PromptQuickPad_PasteRow(iItem + 1)
    } else if code = -5 {  ; NM_RCLICK
        if iItem >= 0
            PromptQuickPad_ShowRowContextMenu(iItem + 1)
        else {
            r := PromptQuickPad_ListViewHitItemOneBased(PromptQuickPadListLV)
            if r > 0
                PromptQuickPad_ShowRowContextMenu(r)
        }
    }
}

PromptQuickPad_ShowRowContextMenu(RowOneBased) {
    global PromptQuickPadListLV
    if RowOneBased < 1 || PromptQuickPadListLV = 0
        return
    try PromptQuickPadListLV.Modify(RowOneBased, "Select Vis")
    catch {
    }
    m := Menu()
    m.Add("编辑提示词", (*) => PromptQuickPad_EditItem(RowOneBased))
    m.Add("删除", (*) => PromptQuickPad_DeleteItem(RowOneBased))
    try {
        DllCall("GetCursorPos", "int*", &mx := 0, "int*", &my := 0)
        m.Show(mx, my)
    } catch {
        m.Show()
    }
}

PromptQuickPad_ApplyListViewStyles() {
    global PromptQuickPadListLV
    if PromptQuickPadListLV = 0
        return
    LVM_SETEXTENDEDLISTVIEWSTYLE := 0x1000 + 54
    ex := 0x20 | 0x8 | 0x10000  ; FULLROWSELECT | TRACKSELECT | DOUBLEBUFFER
    try SendMessage(LVM_SETEXTENDEDLISTVIEWSTYLE, 0xFFFFFFFF, ex, , "ahk_id " . PromptQuickPadListLV.Hwnd)
}

PromptQuickPad_OnSize(GuiObj, MinMax, Width, Height) {
    global AIListPanelWindowW, AIListPanelWindowH, AIListPanelIsResizing
    if MinMax = -1
        return
    AIListPanelIsResizing := true
    AIListPanelWindowW := Width
    AIListPanelWindowH := Height
    PromptQuickPad_RelayoutMainControls(Width, Height)
    AIListPanelIsResizing := false
    SaveAIListPanelPosition()
}

PromptQuickPad_LVContextMenu(GuiCtrl, Item, IsRightClick, X, Y) {
    row := Item
    if row < 1
        row := PromptQuickPad_ListViewHitItemOneBased(GuiCtrl)
    if row < 1
        return
    PromptQuickPad_ShowRowContextMenu(row)
}

PromptQuickPad_DeleteItem(row) {
    global PromptQuickPadFilteredIdx, PromptQuickPadMergedSnapshot, PromptQuickPadData
    if row < 1 || row > PromptQuickPadFilteredIdx.Length
        return
    mi := PromptQuickPadFilteredIdx[row]
    if mi < 1 || mi > PromptQuickPadMergedSnapshot.Length
        return
    entry := PromptQuickPadMergedSnapshot[mi]
    src := entry.Has("source") ? entry["source"] : ""
    if src != "json" {
        MsgBox("此项来自设置中的「快捷操作」或「提示词模板」，请在主界面 设置 → 提示词 中修改或删除。", "Prompt Quick-Pad", "Iconi")
        return
    }
    if MsgBox("确定删除该条用户提示词？（仅移除 prompts.json 中的条目）", "Prompt Quick-Pad", "YesNo Icon?") != "Yes"
        return
    uix := entry.Has("userIndex") ? Integer(entry["userIndex"]) : 0
    if uix >= 1 && uix <= PromptQuickPadData.Length {
        PromptQuickPadData.RemoveAt(uix)
        PromptQuickPad_SaveToDisk()
        PromptQuickPad_RefreshListView()
    }
}

PromptQuickPad_OpenReadOnlyViewer(Title, Content) {
    global AIListPanelGUI, AIListPanelColors
    opt := "+AlwaysOnTop +Resize"
    if AIListPanelGUI
        opt .= " +Owner" . AIListPanelGUI.Hwnd
    g := Gui(opt, "查看 — " . (Title != "" ? Title : "内置/模板"))
    g.BackColor := AIListPanelColors.Background
    g.SetFont("s10 c" . AIListPanelColors.Text, "Segoe UI")
    g.Add("Text", "x10 y8 w520 h20", "此为设置中的快捷词或模板，正文请在「设置 → 提示词」中修改。")
    ed := g.Add("Edit", "x10 y32 w540 h300 Multi ReadOnly VScroll", Content)
    ed.SetFont("s9", "Consolas")
    g.Add("Button", "x10 y340 w100 h28 Default", "关闭").OnEvent("Click", (*) => g.Destroy())
    g.OnEvent("Escape", (*) => g.Destroy())
    g.Show()
}

PromptQuickPad_SaveEditContent(eg, ed, entry) {
    entry["content"] := ed.Value
    PromptQuickPad_SaveToDisk()
    eg.Destroy()
    PromptQuickPad_RefreshListView()
}

PromptQuickPad_EditItem(row) {
    global PromptQuickPadFilteredIdx, PromptQuickPadMergedSnapshot, PromptQuickPadData, AIListPanelColors, AIListPanelGUI
    if row < 1 || row > PromptQuickPadFilteredIdx.Length
        return
    mi := PromptQuickPadFilteredIdx[row]
    if mi < 1 || mi > PromptQuickPadMergedSnapshot.Length
        return
    shell := PromptQuickPadMergedSnapshot[mi]
    src := shell.Has("source") ? shell["source"] : ""
    if src != "json" {
        PromptQuickPad_OpenReadOnlyViewer(shell.Has("title") ? shell["title"] : "提示词", shell.Has("content") ? shell["content"] : "")
        return
    }
    uix := shell.Has("userIndex") ? Integer(shell["userIndex"]) : 0
    if uix < 1 || uix > PromptQuickPadData.Length
        return
    entry := PromptQuickPadData[uix]
    opt := "+AlwaysOnTop"
    if AIListPanelGUI != 0
        opt .= " +Owner" . AIListPanelGUI.Hwnd
    eg := Gui(opt, "编辑内容")
    eg.BackColor := AIListPanelColors.Background
    eg.SetFont("s10 c" . AIListPanelColors.Text, "Segoe UI")
    ed := eg.Add("Edit", "x10 y10 w420 h260 Multi WantReturn VScroll", entry["content"])
    ed.SetFont("s9", "Consolas")
    eg.Add("Button", "x10 y280 w100 h28 Default", "保存").OnEvent("Click", (*) => PromptQuickPad_SaveEditContent(eg, ed, entry))
    eg.Add("Button", "x120 y280 w100 h28", "取消").OnEvent("Click", (*) => eg.Destroy())
    eg.OnEvent("Escape", (*) => eg.Destroy())
    eg.Show()
}

ShowAIListPanel() {
    global AIListPanelGUI, AIListPanelIsVisible
    global AIListPanelWindowX, AIListPanelWindowY, AIListPanelWindowW, AIListPanelWindowH
    global FloatingToolbarGUI, FloatingToolbarWindowX, FloatingToolbarWindowY
    global AIListPanelEnterHotkey, AIListPanelEscHotkey, AIListPanelSearchInput

    if AIListPanelIsVisible && AIListPanelGUI != 0 {
        HideAIListPanel()
        return
    }

    LoadAIListPanelPosition()

    try {
        CreateAIListPanelGUI()
    } catch as err {
        TrayTip("Prompt Quick-Pad 创建失败: " . err.Message, "错误", "Iconx 2")
        return
    }

    savedX := AIListPanelWindowX
    savedY := AIListPanelWindowY
    savedW := AIListPanelWindowW
    savedH := AIListPanelWindowH

    if savedX != 0 && savedY != 0 {
        panelX := savedX
        panelY := savedY
        panelW := savedW > 0 ? savedW : 520
        panelH := savedH > 0 ? savedH : 480
    } else if FloatingToolbarGUI != 0 {
        try {
            FloatingToolbarGUI.GetPos(&toolbarX, &toolbarY, &toolbarW, &toolbarH)
            panelW := AIListPanelWindowW > 0 ? AIListPanelWindowW : 520
            panelH := AIListPanelWindowH > 0 ? AIListPanelWindowH : 480
            panelX := toolbarX
            panelY := toolbarY - panelH
            ScreenHeight := SysGet(1)
            if panelY < 0
                panelY := toolbarY + toolbarH + 5
        } catch {
            ScreenWidth := SysGet(0)
            ScreenHeight := SysGet(1)
            panelW := 520
            panelH := 480
            panelX := (ScreenWidth - panelW) // 2
            panelY := (ScreenHeight - panelH) // 2
        }
    } else {
        ScreenWidth := SysGet(0)
        ScreenHeight := SysGet(1)
        panelW := 520
        panelH := 480
        panelX := (ScreenWidth - panelW) // 2
        panelY := (ScreenHeight - panelH) // 2
    }

    AIListPanelWindowX := panelX
    AIListPanelWindowY := panelY
    AIListPanelWindowW := panelW
    AIListPanelWindowH := panelH

    try {
        AIListPanelGUI.Show("x" . panelX . " y" . panelY . " w" . panelW . " h" . panelH)
        AIListPanelIsVisible := true
    } catch as err {
        TrayTip("显示失败: " . err.Message, "错误", "Iconx 2")
        return
    }

    PromptQuickPad_RelayoutMainControls()
    PromptQuickPad_RefreshListView()
    SetTimer(AIListPanelFollowToolbar, 100)

    try {
        HotIfWinActive("ahk_id " . AIListPanelGUI.Hwnd)
        AIListPanelEnterHotkey := Hotkey("Enter", PromptQuickPad_OnEnter, "On")
        AIListPanelEscHotkey := Hotkey("Escape", PromptQuickPad_OnEsc, "On")
        HotIfWinActive()
    } catch {
    }

    if AIListPanelSearchInput != 0
        AIListPanelSearchInput.Focus()
}

HideAIListPanel() {
    global AIListPanelGUI, AIListPanelIsVisible, AIListPanelEnterHotkey, AIListPanelEscHotkey

    if AIListPanelGUI != 0 {
        try SaveAIListPanelPosition()
        catch {
        }
        try {
            HotIfWinActive("ahk_id " . AIListPanelGUI.Hwnd)
            if AIListPanelEnterHotkey != 0 {
                AIListPanelEnterHotkey.Off()
                AIListPanelEnterHotkey := 0
            }
            if AIListPanelEscHotkey != 0 {
                AIListPanelEscHotkey.Off()
                AIListPanelEscHotkey := 0
            }
            HotIfWinActive()
        } catch {
            try HotIfWinActive()
            catch {
            }
        }
        try AIListPanelGUI.Hide()
        catch {
        }
        AIListPanelIsVisible := false
        SetTimer(AIListPanelFollowToolbar, 0)
    }
}

ToggleAIListPanel() {
    global AIListPanelIsVisible
    if AIListPanelIsVisible
        HideAIListPanel()
    else
        ShowAIListPanel()
}

CreateAIListPanelGUI() {
    global AIListPanelGUI, AIListPanelColors, AIListPanelSearchInput
    global PromptQuickPadListLV, PromptQuickPadStatusText, PromptQuickPadDragBar
    global PromptQuickPadLastCategorySig

    if AIListPanelGUI != 0 {
        PromptQuickPad_ClearCategoryStrip()
        try AIListPanelGUI.Destroy()
        catch {
        }
    }
    PromptQuickPadLastCategorySig := ""
    PromptQuickPadDragBar := 0

    PromptQuickPad_LoadFromDisk()

    ; 标准标题栏：置顶、最小化、最大化、关闭（系统按钮）
    AIListPanelGUI := Gui("+AlwaysOnTop +Resize +MinimizeBox +MaximizeBox +Caption +Border +MinSize440x460", "Prompt Quick-Pad")
    AIListPanelGUI.BackColor := AIListPanelColors.Background
    AIListPanelGUI.SetFont("s10 c" . AIListPanelColors.Text, "Segoe UI")
    AIListPanelGUI.OnEvent("Close", (*) => HideAIListPanel())
    AIListPanelGUI.OnEvent("Size", PromptQuickPad_OnSize)

    margin := 10
    global AIListPanelWindowW, AIListPanelWindowH
    initW := AIListPanelWindowW > 0 ? AIListPanelWindowW : 560
    initH := AIListPanelWindowH > 0 ? AIListPanelWindowH : 520

    AIListPanelSearchInput := AIListPanelGUI.Add("Edit",
        "x" . margin . " y80 w" . (initW - margin * 2) . " h24 Background" . AIListPanelColors.ItemBg . " c" . AIListPanelColors.Text, "")
    AIListPanelSearchInput.SetFont("s9", "Segoe UI")
    AIListPanelSearchInput.OnEvent("Change", PromptQuickPad_OnSearchChange)

    PromptQuickPadListLV := AIListPanelGUI.Add("ListView",
        "x" . margin . " y120 w" . (initW - margin * 2) . " h200 Background" . AIListPanelColors.ItemBg . " c" . AIListPanelColors.Text . " Grid NoSortHdr",
        ["标题", "分类", "快捷键", "预览"])
    PromptQuickPadListLV.SetFont("s9", "Segoe UI")
    PromptQuickPadListLV.OnEvent("DoubleClick", PromptQuickPad_OnDoubleClick)
    PromptQuickPadListLV.OnEvent("ContextMenu", PromptQuickPad_LVContextMenu)

    PromptQuickPadStatusText := AIListPanelGUI.Add("Text",
        "x" . margin . " y" . (initH - 70) . " w" . (initW - margin * 2) . " h44 0x200 c" . AIListPanelColors.Text, "")

    PromptQuickPad_ApplyListViewStyles()
    try {
        PromptQuickPadListLV.ModifyCol(1, 120)
        PromptQuickPadListLV.ModifyCol(2, 72)
        PromptQuickPadListLV.ModifyCol(3, 88)
        PromptQuickPadListLV.ModifyCol(4, initW - margin * 2 - 120 - 72 - 88 - 24)
    } catch {
    }
}

AIListPanelFollowToolbar() {
    global AIListPanelGUI, AIListPanelIsVisible, FloatingToolbarGUI, FloatingToolbarIsVisible
    global AIListPanelDragging, AIListPanelUserMoving

    if !AIListPanelIsVisible || AIListPanelGUI = 0 || !FloatingToolbarIsVisible || FloatingToolbarGUI = 0
        return
    if AIListPanelDragging || AIListPanelUserMoving
        return

    try {
        FloatingToolbarGUI.GetPos(&toolbarX, &toolbarY, &toolbarW, &toolbarH)
        AIListPanelGUI.GetPos(&panelX, &panelY, &panelW, &panelH)
        idealX := toolbarX
        idealY := toolbarY - panelH
        ScreenHeight := SysGet(1)
        if idealY < 0
            idealY := toolbarY + toolbarH + 5
        panelCenterX := panelX + panelW // 2
        panelCenterY := panelY + panelH // 2
        idealCenterX := idealX + panelW // 2
        idealCenterY := idealY + panelH // 2
        if Abs(panelCenterX - idealCenterX) <= 30 && Abs(panelCenterY - idealCenterY) <= 30 {
            if panelX != idealX || panelY != idealY {
                AIListPanelGUI.Move(idealX, idealY)
                AIListPanelWindowX := idealX
                AIListPanelWindowY := idealY
                SaveAIListPanelPosition()
            }
        }
    } catch {
    }
}

SaveAIListPanelPosition() {
    global AIListPanelGUI, AIListPanelWindowX, AIListPanelWindowY, AIListPanelWindowW, AIListPanelWindowH
    if AIListPanelGUI = 0
        return
    try {
        AIListPanelGUI.GetPos(&x, &y, &w, &h)
        AIListPanelWindowX := x
        AIListPanelWindowY := y
        AIListPanelWindowW := w
        AIListPanelWindowH := h
        ConfigFile := A_ScriptDir . "\CursorShortcut.ini"
        IniWrite(String(x), ConfigFile, "WindowPositions", "AIListPanel_X")
        IniWrite(String(y), ConfigFile, "WindowPositions", "AIListPanel_Y")
        IniWrite(String(w), ConfigFile, "WindowPositions", "AIListPanel_W")
        IniWrite(String(h), ConfigFile, "WindowPositions", "AIListPanel_H")
    } catch {
    }
}

LoadAIListPanelPosition() {
    global AIListPanelWindowX, AIListPanelWindowY, AIListPanelWindowW, AIListPanelWindowH
    try {
        ConfigFile := A_ScriptDir . "\CursorShortcut.ini"
        ScreenWidth := SysGet(0)
        ScreenHeight := SysGet(1)
        savedX := IniRead(ConfigFile, "WindowPositions", "AIListPanel_X", "")
        savedY := IniRead(ConfigFile, "WindowPositions", "AIListPanel_Y", "")
        savedW := IniRead(ConfigFile, "WindowPositions", "AIListPanel_W", "")
        savedH := IniRead(ConfigFile, "WindowPositions", "AIListPanel_H", "")

        if savedX != "" && savedY != "" && savedX != "ERROR" && savedY != "ERROR" {
            AIListPanelWindowX := Integer(savedX)
            AIListPanelWindowY := Integer(savedY)
            AIListPanelWindowW := (savedW != "" && savedW != "ERROR") ? Integer(savedW) : 520
            AIListPanelWindowH := (savedH != "" && savedH != "ERROR") ? Integer(savedH) : 480
        } else {
            AIListPanelWindowX := 0
            AIListPanelWindowY := 0
            AIListPanelWindowW := 520
            AIListPanelWindowH := 480
        }
        if AIListPanelWindowW < 400
            AIListPanelWindowW := 400
        if AIListPanelWindowH < 400
            AIListPanelWindowH := 400
        if AIListPanelWindowX < 0 || AIListPanelWindowX > ScreenWidth - 50
            AIListPanelWindowX := 0
        if AIListPanelWindowY < 0 || AIListPanelWindowY > ScreenHeight - 50
            AIListPanelWindowY := 0
    } catch {
        AIListPanelWindowX := 0
        AIListPanelWindowY := 0
        AIListPanelWindowW := 520
        AIListPanelWindowH := 480
    }
}

MinimizeAIListPanelToEdge() {
    global AIListPanelGUI, AIListPanelIsVisible, AIListPanelIsMinimized, AIListPanelWindowX, AIListPanelWindowY
    if !AIListPanelIsVisible || AIListPanelGUI = 0
        return
    AIListPanelGUI.GetPos(&currentX, &currentY, &currentW, &currentH)
    ScreenWidth := SysGet(0)
    ScreenHeight := SysGet(1)
    distLeft := currentX
    distRight := ScreenWidth - (currentX + currentW)
    distTop := currentY
    distBottom := ScreenHeight - (currentY + currentH)
    minDist := distLeft
    targetX := 0
    targetY := currentY
    if distRight < minDist {
        minDist := distRight
        targetX := ScreenWidth - currentW
        targetY := currentY
    }
    if distTop < minDist {
        minDist := distTop
        targetX := currentX
        targetY := 0
    }
    if distBottom < minDist {
        targetX := currentX
        targetY := ScreenHeight - currentH
    }
    AIListPanelGUI.Move(targetX, targetY)
    AIListPanelWindowX := targetX
    AIListPanelWindowY := targetY
    AIListPanelIsMinimized := true
    SaveAIListPanelPosition()
}

RestoreAIListPanel() {
    global AIListPanelIsMinimized
    AIListPanelIsMinimized := false
}

; 复制当前选区，InputBox 标题/标签后追加到 prompts.json（由全局热键调用）
PromptQuickPad_QuickCapture(*) {
    oldClip := ClipboardAll()
    try {
        A_Clipboard := ""
        SendInput("^c")
        if !ClipWait(1.5) {
            TrayTip("未获取到选中文本", "Prompt Quick-Pad", "Iconi 1")
            return
        }
        text := A_Clipboard
        ib := InputBox("条目显示名称：", "Prompt Quick-Pad", , "未命名")
        if ib.Result != "OK"
            return
        title := Trim(ib.Value)
        if title = ""
            title := "未命名"
        ib2 := InputBox("标签（可选，逗号分隔）：", "Prompt Quick-Pad", , "")
        tags := ib2.Result = "OK" ? Trim(ib2.Value) : ""
        PromptQuickPad_LoadFromDisk()
        global PromptQuickPadData
        PromptQuickPadData.Push(Map("title", title, "tags", tags, "content", text, "category", "", "hotkey", ""))
        PromptQuickPad_SaveToDisk()
        TrayTip("已保存到 prompts.json", "Prompt Quick-Pad", "Iconi 1")
    } finally {
        A_Clipboard := oldClip
    }
}

; 由主脚本在加载配置后调用：根据 PromptQuickCaptureHotkey 注册/注销
PromptQuickPad_RegisterCaptureHotkey() {
    global PromptQuickPadCaptureHotkeyObj
    global PromptQuickCaptureHotkey
    if PromptQuickPadCaptureHotkeyObj != 0 {
        try PromptQuickPadCaptureHotkeyObj.Off()
        catch {
        }
        PromptQuickPadCaptureHotkeyObj := 0
    }
    hk := Trim(PromptQuickCaptureHotkey)
    if hk = ""
        return
    try {
        PromptQuickPadCaptureHotkeyObj := Hotkey(hk, PromptQuickPad_QuickCapture, "On")
    } catch as e {
        TrayTip("Prompt 采集热键无效: " . hk . " — " . e.Message, "Prompt Quick-Pad", "Iconx 2")
    }
}

InitAIListPanel() {
}

; WM_NOTIFY 由主脚本 OnClipboardListViewWMNotify 转发到 PromptQuickPad_OnWmNotify（避免覆盖全局监听）
