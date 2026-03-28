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
global PromptQuickPad_PasteTargetHwnd := 0  ; 打开面板前的前台窗口，用于粘贴回目标
global PromptQuickPadBtnImport := 0
global PromptQuickPadBtnExport := 0
global PromptQuickPadBtnJsonHelp := 0
global PromptQuickPadBtnPinTop := 0
global PromptQuickPad_PinTop := true
global PromptQuickPad_LinkBarHeight := 22
global PromptQuickPadCtxMenuGUI := 0
global PromptQuickPadCtxMenuSel := 0

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
    LoadingText: "007acc",
    CategoryTabActive: "ff7700",
    CategoryTabInactive: "363636",
    MenuBg: "1a1a1a",
    AccentOrange: "ff9933",
    PopupBg: "1a1a1a",
    PopupTextBright: "ffffff",
    PopupEditBg: "252526",
    PopupEditText: "f0f0f0"
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

PromptQuickPad_BuildCleanArrayForFile() {
    global PromptQuickPadData
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
    return clean
}

PromptQuickPad_SaveToDisk() {
    path := PromptQuickPad_JsonPath()
    try {
        clean := PromptQuickPad_BuildCleanArrayForFile()
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
        bg := active ? AIListPanelColors.CategoryTabActive : AIListPanelColors.CategoryTabInactive
        tc := active ? AIListPanelColors.TextHover : AIListPanelColors.Text
        try {
            ctrl.Opt("Background" . bg . " c" . tc)
            ctrl.SetFont((active ? "s10 Bold c" : "s10 Norm c") . tc, "Segoe UI")
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
    linkBarH := PromptQuickPad_LinkBarHeight > 8 ? PromptQuickPad_LinkBarHeight : 22
    catBlock := PromptQuickPadCategoryStripHeight > 8 ? PromptQuickPadCategoryStripHeight : 36
    belowCat := topPad + catBlock + 6
    if PromptQuickPadBtnImport != 0
        PromptQuickPadBtnImport.Move(margin, belowCat)
    if PromptQuickPadBtnExport != 0
        PromptQuickPadBtnExport.Move(margin + 52, belowCat)
    if PromptQuickPadBtnPinTop != 0
        PromptQuickPadBtnPinTop.Move(margin + 100, belowCat)
    if PromptQuickPadBtnJsonHelp != 0
        PromptQuickPadBtnJsonHelp.Move(margin + 182, belowCat)
    searchY := belowCat + linkBarH + 8
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
        bg := (cat = PromptQuickPadSelectedCategory) ? AIListPanelColors.CategoryTabActive : AIListPanelColors.CategoryTabInactive
        tc := (cat = PromptQuickPadSelectedCategory) ? AIListPanelColors.TextHover : AIListPanelColors.Text
        t := AIListPanelGUI.Add("Text", "x" . x . " y" . rowY . " w" . wch . " h" . chipH . " Center 0x200 +0x100 Background" . bg . " c" . tc, cat)
        t.SetFont((cat = PromptQuickPadSelectedCategory) ? "s10 Bold" : "s10 Norm", "Segoe UI")
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
            . "`n「" . catDisp . "」显示 " . row . " 条 · 双击粘贴 · 右键菜单 · 上方可导入/导出/查看 JSON 说明"
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
    global PromptQuickPadFilteredIdx, PromptQuickPadMergedSnapshot, PromptQuickPad_PasteTargetHwnd, AIListPanelGUI, FloatingToolbarGUI
    if row < 1 || row > PromptQuickPadFilteredIdx.Length
        return
    srcIdx := PromptQuickPadFilteredIdx[row]
    if srcIdx < 1 || srcIdx > PromptQuickPadMergedSnapshot.Length
        return
    entry := PromptQuickPadMergedSnapshot[srcIdx]
    content := entry.Has("content") ? entry["content"] : ""
    if content = ""
        return
    target := PromptQuickPad_PasteTargetHwnd
    if FloatingToolbarGUI && target = FloatingToolbarGUI.Hwnd
        target := 0
    A_Clipboard := ""
    A_Clipboard := content
    if !ClipWait(2.0) {
        TrayTip("剪贴板写入失败", "Prompt Quick-Pad", "Iconx 1")
        return
    }
    HideAIListPanel()
    if target && DllCall("IsWindow", "ptr", target) {
        if !AIListPanelGUI || target != AIListPanelGUI.Hwnd {
            try DllCall("AllowSetForegroundWindow", "uint", 0xFFFFFFFF)
            catch {
            }
            try {
                WinActivate("ahk_id " . target)
                WinWaitActive("ahk_id " . target, , 0.45)
            } catch {
            }
        }
    }
    Sleep(90)
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

; 双击仅由 WM_NOTIFY NM_DBLCLK 处理，避免与 OnEvent("DoubleClick") 重复触发导致粘贴两次

; ListView 双击在部分环境下 OnEvent 不可靠，用 WM_NOTIFY 兜底（不注册 DoubleClick）
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
    if code = -3 {  ; NM_DBLCLK（仅此路径处理双击粘贴，避免重复）
        r := 0
        if iItem >= 0
            r := iItem + 1
        else
            r := PromptQuickPad_ListViewHitItemOneBased(PromptQuickPadListLV)
        if r > 0
            PromptQuickPad_PasteRow(r)
    }
    ; 右键菜单仅由 ListView ContextMenu 事件弹出（含 Client→Screen），避免与 NM_RCLICK 双开菜单
}

PromptQuickPad_LoadPinFromIni() {
    global PromptQuickPad_PinTop
    try {
        v := IniRead(A_ScriptDir . "\CursorShortcut.ini", "PromptQuickPad", "AlwaysOnTop", "1")
        PromptQuickPad_PinTop := !(v = "0" || StrLower(v) = "false")
    } catch {
        PromptQuickPad_PinTop := true
    }
}

PromptQuickPad_SavePinToIni() {
    global PromptQuickPad_PinTop
    try IniWrite(PromptQuickPad_PinTop ? "1" : "0", A_ScriptDir . "\CursorShortcut.ini", "PromptQuickPad", "AlwaysOnTop")
    catch {
    }
}

PromptQuickPad_RefreshPinTopLabel(*) {
    global PromptQuickPadBtnPinTop, PromptQuickPad_PinTop
    if PromptQuickPadBtnPinTop
        PromptQuickPadBtnPinTop.Value := PromptQuickPad_PinTop ? "置顶·开" : "置顶·关"
}

PromptQuickPad_TogglePinTop(*) {
    global AIListPanelGUI, PromptQuickPad_PinTop
    PromptQuickPad_PinTop := !PromptQuickPad_PinTop
    PromptQuickPad_SavePinToIni()
    if AIListPanelGUI {
        try AIListPanelGUI.Opt(PromptQuickPad_PinTop ? "+AlwaysOnTop" : "-AlwaysOnTop")
        catch {
        }
    }
    PromptQuickPad_RefreshPinTopLabel()
}

PromptQuickPad_DestroyCtxMenu() {
    global PromptQuickPadCtxMenuGUI, PromptQuickPadCtxMenuSel
    SetTimer(PromptQuickPad_CheckCtxMenuMouse, 0)
    SetTimer(PromptQuickPad_CloseCtxMenuIfOutside, 0)
    PromptQuickPadCtxMenuSel := 0
    if PromptQuickPadCtxMenuGUI {
        try PromptQuickPadCtxMenuGUI.Destroy()
        catch {
        }
        PromptQuickPadCtxMenuGUI := 0
    }
}

PromptQuickPad_CtxMenuClick(act, *) {
    PromptQuickPad_DestroyCtxMenu()
    try act()
    catch {
    }
}

PromptQuickPad_CtxItemHover(ItemIndex) {
    global PromptQuickPadCtxMenuGUI, PromptQuickPadCtxMenuSel
    if PromptQuickPadCtxMenuSel != ItemIndex {
        if PromptQuickPadCtxMenuSel > 0 {
            try {
                PromptQuickPadCtxMenuGUI["MenuItemBg" . PromptQuickPadCtxMenuSel].BackColor := "1a1a1a"
                PromptQuickPadCtxMenuGUI["MenuItemText" . PromptQuickPadCtxMenuSel].Opt("cff6600")
                if PromptQuickPadCtxMenuGUI.HasProp("MenuItemIcon" . PromptQuickPadCtxMenuSel)
                    PromptQuickPadCtxMenuGUI["MenuItemIcon" . PromptQuickPadCtxMenuSel].Opt("cff6600")
            } catch {
            }
        }
        PromptQuickPadCtxMenuSel := ItemIndex
        try {
            PromptQuickPadCtxMenuGUI["MenuItemBg" . ItemIndex].BackColor := "ff6600"
            PromptQuickPadCtxMenuGUI["MenuItemText" . ItemIndex].Opt("cFFFFFF")
            if PromptQuickPadCtxMenuGUI.HasProp("MenuItemIcon" . ItemIndex)
                PromptQuickPadCtxMenuGUI["MenuItemIcon" . ItemIndex].Opt("cFFFFFF")
        } catch {
        }
    }
}

PromptQuickPad_CheckCtxMenuMouse(*) {
    global PromptQuickPadCtxMenuGUI, PromptQuickPadCtxMenuSel
    if !PromptQuickPadCtxMenuGUI
        return
    try {
        if !PromptQuickPadCtxMenuGUI.HasProp("Hwnd") || !PromptQuickPadCtxMenuGUI.Hwnd {
            PromptQuickPadCtxMenuGUI := 0
            SetTimer(PromptQuickPad_CheckCtxMenuMouse, 0)
            return
        }
        if !WinExist("ahk_id " . PromptQuickPadCtxMenuGUI.Hwnd) {
            PromptQuickPadCtxMenuGUI := 0
            SetTimer(PromptQuickPad_CheckCtxMenuMouse, 0)
            return
        }
    } catch {
        PromptQuickPadCtxMenuGUI := 0
        SetTimer(PromptQuickPad_CheckCtxMenuMouse, 0)
        return
    }
    try {
        MouseGetPos(&MX, &MY)
        WinGetPos(&WX, &WY, &WW, &WH, "ahk_id " . PromptQuickPadCtxMenuGUI.Hwnd)
    } catch {
        PromptQuickPadCtxMenuGUI := 0
        SetTimer(PromptQuickPad_CheckCtxMenuMouse, 0)
        return
    }
    if MX < WX || MX > WX + WW || MY < WY || MY > WY + WH {
        if PromptQuickPadCtxMenuSel > 0 {
            try {
                PromptQuickPadCtxMenuGUI["MenuItemBg" . PromptQuickPadCtxMenuSel].BackColor := "1a1a1a"
                PromptQuickPadCtxMenuGUI["MenuItemText" . PromptQuickPadCtxMenuSel].Opt("cff6600")
                if PromptQuickPadCtxMenuGUI.HasProp("MenuItemIcon" . PromptQuickPadCtxMenuSel)
                    PromptQuickPadCtxMenuGUI["MenuItemIcon" . PromptQuickPadCtxMenuSel].Opt("cff6600")
                PromptQuickPadCtxMenuSel := 0
            } catch {
            }
        }
        return
    }
    RelY := MY - WY
    MenuItemHeight := 35
    Padding := 10
    if RelY < Padding {
        if PromptQuickPadCtxMenuSel > 0 {
            try {
                PromptQuickPadCtxMenuGUI["MenuItemBg" . PromptQuickPadCtxMenuSel].BackColor := "1a1a1a"
                PromptQuickPadCtxMenuGUI["MenuItemText" . PromptQuickPadCtxMenuSel].Opt("cff6600")
                if PromptQuickPadCtxMenuGUI.HasProp("MenuItemIcon" . PromptQuickPadCtxMenuSel)
                    PromptQuickPadCtxMenuGUI["MenuItemIcon" . PromptQuickPadCtxMenuSel].Opt("cff6600")
                PromptQuickPadCtxMenuSel := 0
            } catch {
            }
        }
        return
    }
    ItemIndex := Floor((RelY - Padding) / MenuItemHeight) + 1
    try {
        if !PromptQuickPadCtxMenuGUI["MenuItemBg" . ItemIndex]
            return
    } catch {
        return
    }
    ItemY := Padding + (ItemIndex - 1) * MenuItemHeight
    if RelY >= ItemY && RelY < ItemY + MenuItemHeight
        PromptQuickPad_CtxItemHover(ItemIndex)
    else if PromptQuickPadCtxMenuSel > 0 {
        try {
            PromptQuickPadCtxMenuGUI["MenuItemBg" . PromptQuickPadCtxMenuSel].BackColor := "1a1a1a"
            PromptQuickPadCtxMenuGUI["MenuItemText" . PromptQuickPadCtxMenuSel].Opt("cff6600")
            if PromptQuickPadCtxMenuGUI.HasProp("MenuItemIcon" . PromptQuickPadCtxMenuSel)
                PromptQuickPadCtxMenuGUI["MenuItemIcon" . PromptQuickPadCtxMenuSel].Opt("cff6600")
            PromptQuickPadCtxMenuSel := 0
        } catch {
        }
    }
}

PromptQuickPad_CloseCtxMenuIfOutside(*) {
    global PromptQuickPadCtxMenuGUI
    if !PromptQuickPadCtxMenuGUI
        return
    try {
        if !PromptQuickPadCtxMenuGUI.HasProp("Hwnd") || !PromptQuickPadCtxMenuGUI.Hwnd {
            PromptQuickPad_DestroyCtxMenu()
            return
        }
        MouseGetPos(&MX, &MY)
        WinGetPos(&WX, &WY, &WW, &WH, "ahk_id " . PromptQuickPadCtxMenuGUI.Hwnd)
        if MX < WX || MX > WX + WW || MY < WY || MY > WY + WH {
            if GetKeyState("LButton", "P") || GetKeyState("RButton", "P")
                PromptQuickPad_DestroyCtxMenu()
        }
    } catch {
        PromptQuickPad_DestroyCtxMenu()
    }
}

; 与悬浮工具栏 ShowDarkStylePopupMenuAt 同款：黑底 + 橙色字/图标 + 悬停橙条（独立 GUI，不占 TrayMenuGUI）
PromptQuickPad_ShowDarkCtxMenuAt(MenuItems, posX, posY) {
    global PromptQuickPadCtxMenuGUI, PromptQuickPadCtxMenuSel
    PromptQuickPad_DestroyCtxMenu()

    MenuWidth := 220
    MenuItemHeight := 35
    Padding := 10
    MenuHeight := MenuItems.Length * MenuItemHeight + Padding * 2

    ScreenWidth := SysGet(78)
    ScreenHeight := SysGet(79)
    if posX < 10
        posX := 10
    else if posX + MenuWidth > ScreenWidth - 10
        posX := ScreenWidth - MenuWidth - 10
    if posY < 10
        posY := 10
    else if posY + MenuHeight > ScreenHeight - 10
        posY := ScreenHeight - MenuHeight - 10

    PromptQuickPadCtxMenuGUI := Gui("+AlwaysOnTop +ToolWindow -Caption -DPIScale")
    PromptQuickPadCtxMenuGUI.BackColor := "1a1a1a"
    PromptQuickPadCtxMenuGUI.Add("Text", "x0 y0 w" . MenuWidth . " h" . MenuHeight . " Background1a1a1a", "")
    PromptQuickPadCtxMenuSel := 0
    IconSize := 20
    IconLeftMargin := Padding + 8
    TextLeftMargin := IconLeftMargin + IconSize + 10

    Loop MenuItems.Length {
        Index := A_Index
        Item := MenuItems[Index]
        actFn := Item["Action"]
        ItemY := Padding + (Index - 1) * MenuItemHeight
        ItemBg := PromptQuickPadCtxMenuGUI.Add("Text", "x" . Padding . " y" . ItemY . " w" . (MenuWidth - Padding * 2) . " h" . MenuItemHeight . " Background1a1a1a vMenuItemBg" . Index, "")
        ItemBg.OnEvent("Click", PromptQuickPad_CtxMenuClick.Bind(actFn))
        if Item.Has("Icon") && Item["Icon"] != "" {
            IconText := PromptQuickPadCtxMenuGUI.Add("Text", "x" . IconLeftMargin . " y" . ItemY . " w" . IconSize . " h" . MenuItemHeight . " Center 0x200 cff6600 BackgroundTrans vMenuItemIcon" . Index, Item["Icon"])
            IconText.SetFont("s14", "Segoe UI Symbol")
            IconText.OnEvent("Click", PromptQuickPad_CtxMenuClick.Bind(actFn))
        }
        ItemText := PromptQuickPadCtxMenuGUI.Add("Text", "x" . TextLeftMargin . " y" . ItemY . " w" . (MenuWidth - TextLeftMargin - Padding) . " h" . MenuItemHeight . " Left 0x200 cff6600 BackgroundTrans vMenuItemText" . Index, Item["Text"])
        ItemText.SetFont("s11", "Segoe UI")
        ItemText.OnEvent("Click", PromptQuickPad_CtxMenuClick.Bind(actFn))
    }

    PromptQuickPadCtxMenuGUI.Show("x" . posX . " y" . posY . " w" . MenuWidth . " h" . MenuHeight)
    try WinActivate("ahk_id " . PromptQuickPadCtxMenuGUI.Hwnd)
    catch {
    }
    SetTimer(PromptQuickPad_CheckCtxMenuMouse, 50)
    SetTimer(PromptQuickPad_CloseCtxMenuIfOutside, 100)
}

PromptQuickPad_ShowRowContextMenu(RowOneBased, mx := unset, my := unset) {
    global PromptQuickPadListLV
    if RowOneBased < 1 || PromptQuickPadListLV = 0
        return
    try PromptQuickPadListLV.Modify(RowOneBased, "Select Vis")
    catch {
    }
    if !IsSet(mx) || !IsSet(my)
        DllCall("GetCursorPos", "int*", &mx := 0, "int*", &my := 0)
    r := RowOneBased
    menuItems := [
        Map("Text", "编辑提示词", "Icon", "✎", "Action", (*) => PromptQuickPad_EditItem(r)),
        Map("Text", "删除", "Icon", "✕", "Action", (*) => PromptQuickPad_DeleteItem(r))
    ]
    MenuItemHeight := 35
    Padding := 10
    MenuHeight := menuItems.Length * MenuItemHeight + Padding * 2
    MenuWidth := 220
    anchorX := mx
    anchorY := my
    posX := anchorX + 2
    posY := anchorY + 2
    ScreenWidth := SysGet(78)
    ScreenHeight := SysGet(79)
    if posY + MenuHeight > ScreenHeight - 10
        posY := anchorY - MenuHeight - 2
    if posX + MenuWidth > ScreenWidth - 10
        posX := anchorX - MenuWidth - 2
    PromptQuickPad_ShowDarkCtxMenuAt(menuItems, posX, posY)
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
    row := Item >= 1 ? Item : PromptQuickPad_ListViewHitItemOneBased(GuiCtrl)
    if row < 1
        return
    pt := Buffer(8, 0)
    NumPut("int", Integer(X), pt, 0)
    NumPut("int", Integer(Y), pt, 4)
    if !DllCall("ClientToScreen", "ptr", GuiCtrl.Hwnd, "ptr", pt)
        return
    sx := NumGet(pt, 0, "int")
    sy := NumGet(pt, 4, "int")
    PromptQuickPad_ShowRowContextMenu(row, sx, sy)
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
    g.BackColor := AIListPanelColors.PopupBg
    top := g.Add("Text", "x12 y10 w540 h40 c" . AIListPanelColors.PopupTextBright . " Wrap",
        "此为设置中的快捷词或模板，正文请在「设置 → 提示词」中修改。")
    top.SetFont("s10", "Segoe UI")
    ed := g.Add("Edit", "x12 y54 w540 h300 Multi ReadOnly VScroll -Theme Background" . AIListPanelColors.PopupEditBg . " c" . AIListPanelColors.PopupEditText, Content)
    ed.SetFont("s10", "Consolas")
    bClose := g.Add("Button", "x12 y362 w100 h30 Default Backgroundff6600", "关闭")
    bClose.SetFont("s10 cffffff", "Segoe UI")
    bClose.OnEvent("Click", (*) => g.Destroy())
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
    global PromptQuickPad_PasteTargetHwnd

    PromptQuickPad_PasteTargetHwnd := DllCall("GetForegroundWindow", "ptr")

    if AIListPanelIsVisible && AIListPanelGUI != 0 {
        HideAIListPanel()
        return
    }

    LoadAIListPanelPosition()

    try {
        CreateAIListPanelGUI()
    } catch as err {
        lineHint := ""
        try {
            if err.Line
                lineHint := " 行" . err.Line
        } catch {
        }
        TrayTip("Prompt Quick-Pad 创建失败: " . err.Message . lineHint, "错误", "Iconx 3")
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

    PromptQuickPad_DestroyCtxMenu()

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
    global PromptQuickPadBtnImport, PromptQuickPadBtnExport, PromptQuickPadBtnJsonHelp, PromptQuickPadBtnPinTop

    PromptQuickPad_LoadPinFromIni()

    if AIListPanelGUI != 0 {
        PromptQuickPad_ClearCategoryStrip()
        try AIListPanelGUI.Destroy()
        catch {
        }
    }
    PromptQuickPadLastCategorySig := ""
    PromptQuickPadDragBar := 0

    PromptQuickPad_LoadFromDisk()

    ; 标准标题栏；置顶可由链接「置顶·开/关」切换并写入 ini
    topOpt := PromptQuickPad_PinTop ? "+AlwaysOnTop" : "-AlwaysOnTop"
    AIListPanelGUI := Gui(topOpt . " +Resize +MinimizeBox +MaximizeBox +Caption", "Prompt Quick-Pad")
    try AIListPanelGUI.Opt("+MinSize440x460")
    catch {
    }
    AIListPanelGUI.BackColor := AIListPanelColors.Background
    AIListPanelGUI.SetFont("s10 c" . AIListPanelColors.Text, "Segoe UI")
    AIListPanelGUI.OnEvent("Close", (*) => HideAIListPanel())
    AIListPanelGUI.OnEvent("Size", PromptQuickPad_OnSize)

    margin := 10
    global AIListPanelWindowW, AIListPanelWindowH
    initW := AIListPanelWindowW > 0 ? AIListPanelWindowW : 560
    initH := AIListPanelWindowH > 0 ? AIListPanelWindowH : 520

    PromptQuickPadBtnImport := AIListPanelGUI.Add("Text", "x" . margin . " y54 w40 h18 +0x100 c" . AIListPanelColors.AccentOrange, "导入")
    PromptQuickPadBtnImport.SetFont("s9 underline", "Segoe UI")
    PromptQuickPadBtnImport.OnEvent("Click", PromptQuickPad_DoImport)
    PromptQuickPadBtnExport := AIListPanelGUI.Add("Text", "x" . (margin + 52) . " y54 w40 h18 +0x100 c" . AIListPanelColors.AccentOrange, "导出")
    PromptQuickPadBtnExport.SetFont("s9 underline", "Segoe UI")
    PromptQuickPadBtnExport.OnEvent("Click", PromptQuickPad_DoExport)
    PromptQuickPadBtnPinTop := AIListPanelGUI.Add("Text", "x" . (margin + 100) . " y54 w72 h18 +0x100 c" . AIListPanelColors.AccentOrange, "")
    PromptQuickPadBtnPinTop.SetFont("s9 underline", "Segoe UI")
    PromptQuickPadBtnPinTop.OnEvent("Click", PromptQuickPad_TogglePinTop)
    PromptQuickPad_RefreshPinTopLabel()
    PromptQuickPadBtnJsonHelp := AIListPanelGUI.Add("Text", "x" . (margin + 182) . " y54 w130 h18 +0x100 c" . AIListPanelColors.AccentOrange, "JSON 格式说明")
    PromptQuickPadBtnJsonHelp.SetFont("s9 underline", "Segoe UI")
    PromptQuickPadBtnJsonHelp.OnEvent("Click", PromptQuickPad_ShowJsonFormatHelp)

    ; -Theme 后 Background/c 在多数系统上才稳定；失败则降级为系统默认外观
    try {
        AIListPanelSearchInput := AIListPanelGUI.Add("Edit",
            "x" . margin . " y80 w" . (initW - margin * 2) . " h24 -Theme Background" . AIListPanelColors.ItemBg . " c" . AIListPanelColors.Text, "")
    } catch {
        AIListPanelSearchInput := AIListPanelGUI.Add("Edit",
            "x" . margin . " y80 w" . (initW - margin * 2) . " h24", "")
    }
    AIListPanelSearchInput.SetFont("s9", "Segoe UI")
    AIListPanelSearchInput.OnEvent("Change", PromptQuickPad_OnSearchChange)

    lvCols := ["标题", "分类", "快捷键", "预览"]
    lvOptsFull := "x" . margin . " y120 w" . (initW - margin * 2) . " h200 -Theme Background" . AIListPanelColors.ItemBg . " c" . AIListPanelColors.Text . " Grid NoSortHdr"
    lvOptsPlain := "x" . margin . " y120 w" . (initW - margin * 2) . " h200 Grid NoSortHdr"
    try {
        PromptQuickPadListLV := AIListPanelGUI.Add("ListView", lvOptsFull, lvCols)
    } catch {
        PromptQuickPadListLV := AIListPanelGUI.Add("ListView", lvOptsPlain, lvCols)
    }
    PromptQuickPadListLV.SetFont("s9", "Segoe UI")
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

PromptQuickPad_GetJsonHelpBody() {
    return "
(
文件位置：脚本目录下的 prompts.json，UTF-8 编码。

内容必须是一个 JSON 数组（顶层用英文方括号 [ ] 包裹），数组中每个元素是一条用户提示词对象。

字段说明：
  • title（字符串，建议）列表中显示的标题。
  • content（字符串，必填）双击粘贴到目标窗口的正文，可含换行。
  • tags（字符串，可选）标签或备注，逗号分隔，参与搜索。
  • category（字符串，可选）顶部分类名；省略或空字符串会出现在「未分类」。
  • hotkey（字符串，可选）仅作列表展示用说明，不自动绑定热键。

最小示例（单条）：
[
  {
    ""title"": ""代码说明"",
    ""tags"": ""doc,zh"",
    ""category"": ""文档"",
    ""hotkey"": """",
    ""content"": ""请用简洁中文解释下面代码在做什么：\n\n""
  }
]

注意：面板里的「快捷操作」「模板」来自设置与模板文件，不会写入 prompts.json；导入导出仅针对上述用户条目数组。
)"
}

PromptQuickPad_ShowJsonFormatHelp(*) {
    global AIListPanelGUI, AIListPanelColors
    opt := "+AlwaysOnTop +Resize"
    if AIListPanelGUI
        opt .= " +Owner" . AIListPanelGUI.Hwnd
    g := Gui(opt, "prompts.json 格式说明")
    g.BackColor := AIListPanelColors.PopupBg
    top := g.Add("Text", "x12 y10 w560 h44 c" . AIListPanelColors.PopupTextBright . " Wrap",
        "以下为 prompts.json 的结构说明。导入/导出使用相同格式（仅用户自定义条目）。")
    top.SetFont("s10", "Segoe UI")
    ed := g.Add("Edit", "x12 y60 w560 h352 Multi ReadOnly VScroll WantReturn -Theme Background" . AIListPanelColors.PopupEditBg . " c" . AIListPanelColors.PopupEditText, PromptQuickPad_GetJsonHelpBody())
    ed.SetFont("s10", "Consolas")
    bClose := g.Add("Button", "x12 y422 w100 h30 Default Backgroundff6600", "关闭")
    bClose.SetFont("s10 cffffff", "Segoe UI")
    bClose.OnEvent("Click", (*) => g.Destroy())
    g.OnEvent("Escape", (*) => g.Destroy())
    g.Show()
}

PromptQuickPad_DoImport(*) {
    global PromptQuickPadData
    p := FileSelect(1, A_ScriptDir, "选择要导入的 JSON", "JSON (*.json)")
    if p = ""
        return
    try
        raw := FileRead(p, "UTF-8")
    catch {
        MsgBox("无法读取该文件。", "导入提示词", "Iconx")
        return
    }
    try
        parsed := Jxon_Load(raw)
    catch {
        MsgBox("JSON 解析失败，请检查语法。", "导入提示词", "Iconx")
        return
    }
    if !(parsed is Array) {
        MsgBox("文件顶层必须是 JSON 数组，例如 [ {...}, {...} ]。", "导入提示词", "Iconx")
        return
    }
    ans := MsgBox("将读取 " . parsed.Length . " 条记录。`n`n是 = 合并到现有末尾`n否 = 清空后仅保留导入内容`n取消 = 放弃", "导入提示词", "YesNoCancel Icon?")
    if ans = "Cancel"
        return
    if ans = "No"
        PromptQuickPadData := []
    for item in parsed {
        if item is Map
            PromptQuickPadData.Push(PromptQuickPad_NormalizeEntry(item))
    }
    PromptQuickPad_SaveToDisk()
    PromptQuickPad_RefreshListView()
    TrayTip("导入完成", "Prompt Quick-Pad", "Iconi 1")
}

PromptQuickPad_DoExport(*) {
    def := A_ScriptDir . "\prompts_export_" . A_Now . ".json"
    p := FileSelect("S16", def, "导出 prompts.json", "JSON (*.json)")
    if p = ""
        return
    try {
        clean := PromptQuickPad_BuildCleanArrayForFile()
        f := FileOpen(p, "w", "UTF-8")
        if !f {
            MsgBox("无法创建或写入文件。", "导出提示词", "Iconx")
            return
        }
        f.Write(Jxon_Dump(clean))
        f.Close()
        TrayTip("已导出", "Prompt Quick-Pad", "Iconi 1")
    } catch as e {
        MsgBox("导出失败: " . e.Message, "导出提示词", "Iconx")
    }
}

InitAIListPanel() {
}

; WM_NOTIFY 由主脚本 OnClipboardListViewWMNotify 转发到 PromptQuickPad_OnWmNotify（避免覆盖全局监听）
