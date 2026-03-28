; CapsLock+B：全局提示词采集（静默或弹窗），样式对齐悬浮工具栏色板
; 依赖：FloatingToolbarColors、AIListPanel 中 PromptQuickPad_* 等
#Requires AutoHotkey v2.0

global PromptQuickPadCapsB_Gui := 0
global PromptQuickPadCapsB_edTitle := 0
global PromptQuickPadCapsB_cbCategory := 0
global PromptQuickPadCapsB_edTags := 0
global PromptQuickPadCapsB_edContent := 0
global PromptQuickPadCapsB_lv := 0
global PromptQuickPadCapsB_lvY := 0
global PromptQuickPadCapsB_MergedSnapshot := []
global PromptQuickPadCapsB_btnLoad := 0
global PromptQuickPadCapsB_btnSave := 0
global PromptQuickPadCapsB_btnQuit := 0
global PromptQuickPadCapsB_chkSilent := 0
global PromptQuickPadCapsB_chkSilentToTemplate := 0

PromptQuickPad_ReloadCapsLockBSettings() {
    global PromptQuickPad_CapsLockBSilent, PromptQuickPad_CapsLockBSilentToTemplate, PromptQuickPad_CapsLockBDefaultTitle
    global PromptQuickPad_CapsLockBDefaultCategory, PromptQuickPad_CapsLockBDefaultTags
    cfg := A_ScriptDir . "\CursorShortcut.ini"
    try {
        PromptQuickPad_CapsLockBSilent := (IniRead(cfg, "PromptQuickPad", "CapsLockBSilent", "0") = "1")
        PromptQuickPad_CapsLockBSilentToTemplate := (IniRead(cfg, "PromptQuickPad", "CapsLockBSilentToTemplate", "0") = "1")
        PromptQuickPad_CapsLockBDefaultTitle := IniRead(cfg, "PromptQuickPad", "CapsLockBDefaultTitle", "摘录")
        PromptQuickPad_CapsLockBDefaultCategory := IniRead(cfg, "PromptQuickPad", "CapsLockBDefaultCategory", "")
        PromptQuickPad_CapsLockBDefaultTags := IniRead(cfg, "PromptQuickPad", "CapsLockBDefaultTags", "")
    } catch {
    }
}

PromptQuickPad_CapsB_CopySelection(&outText) {
    outText := ""
    oldClip := ClipboardAll()
    try {
        A_Clipboard := ""
        SendInput("^c")
        if !ClipWait(1.5)
            return false
        outText := A_Clipboard
        return true
    } finally {
        A_Clipboard := oldClip
    }
}

PromptQuickPad_AppendCapsLockBToTemplateLibrary(content) {
    global PromptTemplates, TemplateIndexByID, TemplateIndexByTitle, TemplateIndexByArrayIndex
    global PromptQuickPad_CapsLockBDefaultTitle, PromptQuickPad_CapsLockBDefaultCategory
    global AIListPanelIsVisible
    title := Trim(PromptQuickPad_CapsLockBDefaultTitle)
    if title = ""
        title := "摘录"
    cat := Trim(PromptQuickPad_CapsLockBDefaultCategory)
    if cat = ""
        cat := "自定义"
    NewID := "template_" . A_TickCount
    NewTemplate := { ID: NewID, Title: title, Content: content, Icon: "", Category: cat }
    PromptTemplates.Push(NewTemplate)
    TemplateIndexByID[NewID] := NewTemplate
    Key := NewTemplate.Category . "|" . NewTemplate.Title
    TemplateIndexByTitle[Key] := NewTemplate
    TemplateIndexByArrayIndex[NewID] := PromptTemplates.Length
    InvalidateTemplateCache()
    try {
        SavePromptTemplates()
    } catch as err {
        TrayTip("保存模板库失败：" . err.Message, "Prompt Quick-Pad", "Iconx 1")
        return false
    }
    if AIListPanelIsVisible
        PromptQuickPad_RefreshListView()
    try
        RefreshPromptListView()
    catch {
    }
    tip := "已静默保存到模板库（PromptTemplates.ini）"
    if StrLen(title) <= 24
        tip .= "`n「" . title . "」"
    else
        tip .= "`n「" . SubStr(title, 1, 24) . "…」"
    TrayTip(tip, "Prompt Quick-Pad", "Iconi 1")
    return true
}

PromptQuickPad_HandleCapsLockB() {
    global PromptQuickPad_CapsLockBSilent, PromptQuickPad_CapsLockBSilentToTemplate
    global PromptQuickPad_CapsLockBDefaultTitle, PromptQuickPad_CapsLockBDefaultCategory, PromptQuickPad_CapsLockBDefaultTags
    global PromptQuickPadData, AIListPanelIsVisible
    PromptQuickPad_ReloadCapsLockBSettings()
    if !PromptQuickPad_CapsB_CopySelection(&t) {
        TrayTip("未获取到选中文本", "Prompt Quick-Pad", "Iconi 1")
        return
    }
    if PromptQuickPad_CapsLockBSilent {
        if PromptQuickPad_CapsLockBSilentToTemplate {
            PromptQuickPad_AppendCapsLockBToTemplateLibrary(t)
            return
        }
        PromptQuickPad_LoadFromDisk()
        title := Trim(PromptQuickPad_CapsLockBDefaultTitle)
        if title = ""
            title := "摘录"
        cat := Trim(PromptQuickPad_CapsLockBDefaultCategory)
        tags := Trim(PromptQuickPad_CapsLockBDefaultTags)
        PromptQuickPadData.Push(PromptQuickPad_NormalizeEntry(Map("title", title, "tags", tags, "content", t, "category", cat, "hotkey", "")))
        PromptQuickPad_SaveToDisk()
        if AIListPanelIsVisible
            PromptQuickPad_RefreshListView()
        TrayTip("已静默保存到用户库（prompts.json）", "Prompt Quick-Pad", "Iconi 1")
        return
    }
    PromptQuickPad_ShowCapturePanel(t)
}

PromptQuickPadCapsB_ClearGuiRefs() {
    global PromptQuickPadCapsB_Gui, PromptQuickPadCapsB_edTitle, PromptQuickPadCapsB_cbCategory
    global PromptQuickPadCapsB_edTags, PromptQuickPadCapsB_edContent, PromptQuickPadCapsB_lv
    global PromptQuickPadCapsB_lvY, PromptQuickPadCapsB_MergedSnapshot, PromptQuickPadCapsB_btnLoad, PromptQuickPadCapsB_btnSave, PromptQuickPadCapsB_btnQuit
    global PromptQuickPadCapsB_chkSilent, PromptQuickPadCapsB_chkSilentToTemplate
    PromptQuickPadCapsB_Gui := 0
    PromptQuickPadCapsB_edTitle := 0
    PromptQuickPadCapsB_cbCategory := 0
    PromptQuickPadCapsB_edTags := 0
    PromptQuickPadCapsB_edContent := 0
    PromptQuickPadCapsB_lv := 0
    PromptQuickPadCapsB_lvY := 0
    PromptQuickPadCapsB_MergedSnapshot := []
    PromptQuickPadCapsB_btnLoad := 0
    PromptQuickPadCapsB_btnSave := 0
    PromptQuickPadCapsB_btnQuit := 0
    PromptQuickPadCapsB_chkSilent := 0
    PromptQuickPadCapsB_chkSilentToTemplate := 0
}

PromptQuickPadCapsB_WriteDefaultsFromPanel() {
    global PromptQuickPadCapsB_edTitle, PromptQuickPadCapsB_cbCategory, PromptQuickPadCapsB_edTags
    global PromptQuickPad_CapsLockBDefaultTitle, PromptQuickPad_CapsLockBDefaultCategory, PromptQuickPad_CapsLockBDefaultTags
    if PromptQuickPadCapsB_edTitle = 0 || PromptQuickPadCapsB_cbCategory = 0 || PromptQuickPadCapsB_edTags = 0
        return
    t := Trim(PromptQuickPadCapsB_edTitle.Value)
    if t = ""
        t := "摘录"
    cat := Trim(PromptQuickPadCapsB_cbCategory.Text)
    if cat = "未分类"
        cat := ""
    tags := Trim(PromptQuickPadCapsB_edTags.Value)
    PromptQuickPad_CapsLockBDefaultTitle := t
    PromptQuickPad_CapsLockBDefaultCategory := cat
    PromptQuickPad_CapsLockBDefaultTags := tags
    cfg := A_ScriptDir . "\CursorShortcut.ini"
    try {
        IniWrite(t, cfg, "PromptQuickPad", "CapsLockBDefaultTitle")
        IniWrite(cat, cfg, "PromptQuickPad", "CapsLockBDefaultCategory")
        IniWrite(tags, cfg, "PromptQuickPad", "CapsLockBDefaultTags")
    } catch {
    }
}

PromptQuickPadCapsB_OnSilentModeChange(*) {
    global PromptQuickPadCapsB_chkSilent, PromptQuickPad_CapsLockBSilent
    PromptQuickPad_CapsLockBSilent := PromptQuickPadCapsB_chkSilent.Value = 1
    cfg := A_ScriptDir . "\CursorShortcut.ini"
    try
        IniWrite(PromptQuickPad_CapsLockBSilent ? "1" : "0", cfg, "PromptQuickPad", "CapsLockBSilent")
    catch {
    }
    if PromptQuickPad_CapsLockBSilent
        PromptQuickPadCapsB_WriteDefaultsFromPanel()
    if PromptQuickPad_CapsLockBSilent
        TrayTip("已启用静默：CapsLock+B 自动保存、不弹窗", "Prompt Quick-Pad", "Iconi 1")
    else
        TrayTip("已关闭静默：CapsLock+B 将打开采集窗口", "Prompt Quick-Pad", "Iconi 1")
}

PromptQuickPadCapsB_OnSilentTemplateChange(*) {
    global PromptQuickPadCapsB_chkSilentToTemplate, PromptQuickPad_CapsLockBSilentToTemplate
    PromptQuickPad_CapsLockBSilentToTemplate := PromptQuickPadCapsB_chkSilentToTemplate.Value = 1
    cfg := A_ScriptDir . "\CursorShortcut.ini"
    try
        IniWrite(PromptQuickPad_CapsLockBSilentToTemplate ? "1" : "0", cfg, "PromptQuickPad", "CapsLockBSilentToTemplate")
    catch {
    }
}

PromptQuickPad_ShowCapturePanel(InitialText := "") {
    global PromptQuickPadCapsB_Gui
    if PromptQuickPadCapsB_Gui {
        try PromptQuickPadCapsB_Gui.Destroy()
        catch {
        }
        PromptQuickPadCapsB_ClearGuiRefs()
    }
    PromptQuickPadCapsB_CreateGui(InitialText)
}

PromptQuickPadCapsB_CategoryTextToSave() {
    global PromptQuickPadCapsB_cbCategory
    if PromptQuickPadCapsB_cbCategory = 0
        return ""
    s := Trim(PromptQuickPadCapsB_cbCategory.Text)
    if s = "未分类"
        return ""
    return s
}

PromptQuickPadCapsB_FillListView() {
    global PromptQuickPadCapsB_lv, PromptQuickPadCapsB_MergedSnapshot
    if PromptQuickPadCapsB_lv = 0
        return
    PromptQuickPadCapsB_lv.Delete()
    PromptQuickPadCapsB_MergedSnapshot := PromptQuickPad_BuildMergedList()
    cnt := 0
    for item in PromptQuickPadCapsB_MergedSnapshot {
        if !(item is Map)
            continue
        title := item.Has("title") ? item["title"] : ""
        cat := item.Has("category") ? item["category"] : ""
        content := item.Has("content") ? item["content"] : ""
        src := item.Has("source") ? item["source"] : ""
        srcDisp := src = "json" ? "用户" : src = "template" ? "模板" : src = "builtin" ? "快捷" : ""
        pv := PromptQuickPad_MakePreview(content, 96)
        catDisp := cat = "" ? "（未分类）" : cat
        PromptQuickPadCapsB_lv.Add("", title, catDisp, (srcDisp != "" ? "[" . srcDisp . "] " : "") . pv)
        cnt++
    }
    if cnt = 0
        PromptQuickPadCapsB_lv.Add("", "（无条目）", "", "请检查 PromptTemplates 与 prompts.json")
}

PromptQuickPadCapsB_BuildCategoryChoices() {
    merged := PromptQuickPad_BuildMergedList()
    tabs := PromptQuickPad_UniqueCategoryTabs(merged)
    opts := ["未分类"]
    seen := Map("未分类", true)
    for t in tabs {
        if t = "" || t = "全部" || t = "未分类"
            continue
        if seen.Has(t)
            continue
        seen[t] := true
        opts.Push(t)
    }
    return opts
}

PromptQuickPadCapsB_LoadSelectedRow(*) {
    global PromptQuickPadCapsB_lv, PromptQuickPadCapsB_edTitle, PromptQuickPadCapsB_cbCategory
    global PromptQuickPadCapsB_edTags, PromptQuickPadCapsB_edContent, PromptQuickPadCapsB_MergedSnapshot
    if PromptQuickPadCapsB_lv = 0
        return
    r := PromptQuickPadCapsB_lv.GetNext(0, "Focused")
    if r < 1
        r := PromptQuickPadCapsB_lv.GetNext(0)
    if r < 1 || r > PromptQuickPadCapsB_MergedSnapshot.Length
        return
    entry := PromptQuickPadCapsB_MergedSnapshot[r]
    if !(entry is Map)
        return
    PromptQuickPadCapsB_edTitle.Value := entry.Has("title") ? entry["title"] : ""
    c := entry.Has("category") ? entry["category"] : ""
    PromptQuickPadCapsB_cbCategory.Text := c = "" ? "未分类" : c
    PromptQuickPadCapsB_edTags.Value := entry.Has("tags") ? entry["tags"] : ""
    PromptQuickPadCapsB_edContent.Value := entry.Has("content") ? entry["content"] : ""
}

PromptQuickPadCapsB_OnLvDoubleClick(GuiCtrl, Item) {
    if Item >= 1
        PromptQuickPadCapsB_LoadSelectedRow()
}

PromptQuickPadCapsB_Save(*) {
    global PromptQuickPadCapsB_edTitle, PromptQuickPadCapsB_edTags
    global PromptQuickPadCapsB_edContent, PromptQuickPadData, AIListPanelIsVisible
    global PromptQuickPadCapsB_lv
    title := Trim(PromptQuickPadCapsB_edTitle.Value)
    if title = ""
        title := "未命名"
    cat := PromptQuickPadCapsB_CategoryTextToSave()
    tags := Trim(PromptQuickPadCapsB_edTags.Value)
    content := Trim(PromptQuickPadCapsB_edContent.Value, " `t`r`n")
    if content = "" {
        TrayTip("正文不能为空", "Prompt Quick-Pad", "Icon! 1")
        return
    }
    PromptQuickPad_LoadFromDisk()
    PromptQuickPadData.Push(PromptQuickPad_NormalizeEntry(Map("title", title, "tags", tags, "content", content, "category", cat, "hotkey", "")))
    PromptQuickPad_SaveToDisk()
    if PromptQuickPadCapsB_lv != 0
        PromptQuickPadCapsB_FillListView()
    if AIListPanelIsVisible
        PromptQuickPad_RefreshListView()
    TrayTip("已保存到 prompts.json", "Prompt Quick-Pad", "Iconi 1")
}

PromptQuickPadCapsB_Close(*) {
    global PromptQuickPadCapsB_Gui
    if PromptQuickPadCapsB_Gui {
        try PromptQuickPadCapsB_Gui.Destroy()
        catch {
        }
    }
    PromptQuickPadCapsB_ClearGuiRefs()
}

PromptQuickPadCapsB_OnSize(GuiObj, MinMax, Width, Height) {
    global PromptQuickPadCapsB_lv, PromptQuickPadCapsB_lvY
    global PromptQuickPadCapsB_btnLoad, PromptQuickPadCapsB_btnSave, PromptQuickPadCapsB_btnQuit
    if MinMax = -1 || PromptQuickPadCapsB_lv = 0
        return
    margin := 12
    btnH := 32
    btnW := 100
    gapB := 8
    gapBtn := 12
    if PromptQuickPadCapsB_lvY <= 0
        return
    btnY := Height - margin - btnH
    if btnY < PromptQuickPadCapsB_lvY + 60
        btnY := PromptQuickPadCapsB_lvY + 60
    lvH := btnY - gapB - PromptQuickPadCapsB_lvY
    if lvH < 72
        lvH := 72
    cx := margin
    cw := Width - margin * 2
    if cw < 200
        cw := 200
    try {
        PromptQuickPadCapsB_lv.Move(cx, PromptQuickPadCapsB_lvY, cw, lvH)
    } catch {
    }
    if PromptQuickPadCapsB_btnLoad = 0 || PromptQuickPadCapsB_btnSave = 0 || PromptQuickPadCapsB_btnQuit = 0
        return
    try {
        PromptQuickPadCapsB_btnLoad.Move(cx, btnY, btnW, btnH)
        PromptQuickPadCapsB_btnSave.Move(cx + btnW + gapBtn, btnY, btnW, btnH)
        PromptQuickPadCapsB_btnQuit.Move(cx + (btnW + gapBtn) * 2, btnY, btnW, btnH)
    } catch {
    }
}

PromptQuickPadCapsB_CreateGui(InitialText) {
    global PromptQuickPadCapsB_Gui, PromptQuickPadCapsB_edTitle, PromptQuickPadCapsB_cbCategory
    global PromptQuickPadCapsB_edTags, PromptQuickPadCapsB_edContent, PromptQuickPadCapsB_lv
    global PromptQuickPadCapsB_lvY, PromptQuickPadCapsB_btnLoad, PromptQuickPadCapsB_btnSave, PromptQuickPadCapsB_btnQuit
    global PromptQuickPadCapsB_chkSilent, PromptQuickPadCapsB_chkSilentToTemplate
    global FloatingToolbarColors
    global PromptQuickPad_CapsLockBDefaultTitle, PromptQuickPad_CapsLockBDefaultCategory, PromptQuickPad_CapsLockBDefaultTags
    global PromptQuickPad_CapsLockBSilent, PromptQuickPad_CapsLockBSilentToTemplate

    PromptQuickPad_ReloadCapsLockBSettings()

    fc := FloatingToolbarColors
    bg := fc.Background
    ibg := fc.ButtonBg
    tx := fc.Text
    accent := "ff6600"

    PromptQuickPad_LoadFromDisk()

    ; 标准标题栏：可拖动、最小化、最大化、关闭（不使用 +ToolWindow -Caption）
    PromptQuickPadCapsB_Gui := Gui("+Resize +MinimizeBox +MaximizeBox +Caption +AlwaysOnTop", "提示词采集 · CapsLock+B")
    g := PromptQuickPadCapsB_Gui
    g.BackColor := bg
    g.SetFont("s10 c" . tx, "Segoe UI")
    g.MarginX := 12
    g.MarginY := 10
    try g.Opt("+MinSize560x520")
    catch {
    }

    g.OnEvent("Close", PromptQuickPadCapsB_Close)
    g.OnEvent("Size", PromptQuickPadCapsB_OnSize)

    g.Add("Text", "xm ym w72", "标题")
    PromptQuickPadCapsB_edTitle := g.Add("Edit", "x+4 w520 h24 -Theme Background" . ibg . " c" . tx, "")

    g.Add("Text", "xm y+8 w72", "分类")
    choices := PromptQuickPadCapsB_BuildCategoryChoices()
    ; 单个 ComboBox：下拉选用 + 可直接输入新分类
    PromptQuickPadCapsB_cbCategory := g.Add("ComboBox", "x+4 w520", choices)
    PromptQuickPadCapsB_cbCategory.Opt("-Theme Background" . ibg . " c" . tx)

    g.Add("Text", "xm y+8 w72", "标签")
    PromptQuickPadCapsB_edTags := g.Add("Edit", "x+4 w520 h24 -Theme Background" . ibg . " c" . tx, "")

    PromptQuickPadCapsB_chkSilent := g.Add("Checkbox", "xm y+8 w520", "静默模式：CapsLock+B 不弹窗，按下方标题/分类/标签自动保存")
    PromptQuickPadCapsB_chkSilent.Value := PromptQuickPad_CapsLockBSilent ? 1 : 0
    PromptQuickPadCapsB_chkSilent.Opt("-Theme Background" . ibg . " c" . tx)
    PromptQuickPadCapsB_chkSilent.OnEvent("Click", PromptQuickPadCapsB_OnSilentModeChange)
    g.Add("Text", "xm y+4 w520", "勾选静默时会将当前标题、分类、标签写入配置，作为静默保存的默认值。")

    PromptQuickPadCapsB_chkSilentToTemplate := g.Add("Checkbox", "xm y+6 w520", "静默时保存到模板库（PromptTemplates.ini），否则写入 prompts.json")
    PromptQuickPadCapsB_chkSilentToTemplate.Value := PromptQuickPad_CapsLockBSilentToTemplate ? 1 : 0
    PromptQuickPadCapsB_chkSilentToTemplate.Opt("-Theme Background" . ibg . " c" . tx)
    PromptQuickPadCapsB_chkSilentToTemplate.OnEvent("Click", PromptQuickPadCapsB_OnSilentTemplateChange)

    g.Add("Text", "xm y+10", "正文")
    PromptQuickPadCapsB_edContent := g.Add("Edit", "xm y+4 w520 h160 Multi VScroll WantReturn -Theme Background" . ibg . " c" . tx, "")
    PromptQuickPadCapsB_edContent.SetFont("s10", "Consolas")

    g.Add("Text", "xm y+8 w520", "已有提示词（与快捷面板一致：快捷词·模板·用户 JSON；双击或「载入所选」填入上方）")

    PromptQuickPadCapsB_lv := g.Add("ListView", "xm y+4 w520 h240 -Theme Background" . ibg . " c" . tx . " Grid AltSubmit", ["标题", "分类", "预览"])
    PromptQuickPadCapsB_lv.SetFont("s9", "Segoe UI")
    PromptQuickPadCapsB_lv.OnEvent("DoubleClick", PromptQuickPadCapsB_OnLvDoubleClick)

    try {
        PromptQuickPadCapsB_lv.ModifyCol(1, 160)
        PromptQuickPadCapsB_lv.ModifyCol(2, 110)
        PromptQuickPadCapsB_lv.ModifyCol(3, "AutoHdr")
    } catch {
    }

    PromptQuickPadCapsB_btnLoad := g.Add("Button", "xm y+10 w100 h32 -Theme Background" . ibg, "载入所选")
    PromptQuickPadCapsB_btnLoad.SetFont("s10 c" . tx, "Segoe UI")
    PromptQuickPadCapsB_btnLoad.OnEvent("Click", PromptQuickPadCapsB_LoadSelectedRow)
    PromptQuickPadCapsB_btnSave := g.Add("Button", "x+12 w100 h32 Background" . accent, "保存")
    PromptQuickPadCapsB_btnSave.SetFont("s10 cffffff", "Segoe UI")
    PromptQuickPadCapsB_btnSave.OnEvent("Click", PromptQuickPadCapsB_Save)
    PromptQuickPadCapsB_btnQuit := g.Add("Button", "x+12 w100 h32 -Theme Background" . ibg, "关闭")
    PromptQuickPadCapsB_btnQuit.SetFont("s10 c" . tx, "Segoe UI")
    PromptQuickPadCapsB_btnQuit.OnEvent("Click", PromptQuickPadCapsB_Close)

    g.OnEvent("Escape", PromptQuickPadCapsB_Close)

    PromptQuickPadCapsB_edTitle.Value := PromptQuickPad_CapsLockBDefaultTitle
    PromptQuickPadCapsB_edTags.Value := PromptQuickPad_CapsLockBDefaultTags
    defC := Trim(PromptQuickPad_CapsLockBDefaultCategory)
    disp := defC = "" ? "未分类" : defC
    PromptQuickPadCapsB_cbCategory.Text := disp

    idx := 1
    Loop choices.Length {
        if choices[A_Index] = disp {
            idx := A_Index
            break
        }
    }
    try PromptQuickPadCapsB_cbCategory.Choose(idx)
    catch {
    }

    PromptQuickPadCapsB_edContent.Value := InitialText

    PromptQuickPadCapsB_FillListView()

    w := 580
    h := 720
    try {
        MonitorGetWorkArea(MonitorGetPrimary(), &wl, &wt, &wr, &wb)
        sw := wr - wl
        sh := wb - wt
        x := wl + (sw - w) // 2
        y := wt + (sh - h) // 2
    } catch {
        sw := SysGet(78)
        sh := SysGet(79)
        x := (sw - w) // 2
        y := (sh - h) // 2
    }
    if x < 10
        x := 10
    if y < 10
        y := 10
    g.Show("x" . x . " y" . y . " w" . w . " h" . h)

    try {
        PromptQuickPadCapsB_lv.GetPos(, &ly2, , &lh2)
        PromptQuickPadCapsB_lvY := ly2
    } catch {
        PromptQuickPadCapsB_lvY := 0
    }
    try {
        WinGetClientPos(, , &cw0, &ch0, "ahk_id " g.Hwnd)
        PromptQuickPadCapsB_OnSize(g, 0, cw0, ch0)
    } catch {
    }

    try WinActivate("ahk_id " . g.Hwnd)
    catch {
    }
}
