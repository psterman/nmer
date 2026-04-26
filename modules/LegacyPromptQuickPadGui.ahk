; LegacyPromptQuickPadGui.ahk — Prompt Quick-Pad 原生 ListView 窗体
; 由 AIListPanel.ahk 拆分，在文件末尾由 AIListPanel 包含。

LegacyPromptQuickPad_ShowNative(openForCapture := false, forceCenterMaximize := false) {
    global AIListPanelGUI, AIListPanelIsVisible
    global AIListPanelWindowX, AIListPanelWindowY, AIListPanelWindowW, AIListPanelWindowH
    global FloatingToolbarGUI, FloatingToolbarWindowX, FloatingToolbarWindowY
    global AIListPanelEnterHotkey, AIListPanelEscHotkey, AIListPanelSearchInput
    global PromptQuickPad_PasteTargetHwnd
    global PromptQuickPad_CaptureChromeVisible

    if AIListPanelIsVisible && AIListPanelGUI != 0 {
        if forceCenterMaximize {
            try WinRestore("ahk_id " . AIListPanelGUI.Hwnd)
            catch {
            }
            PromptQuickPad_CenterAndMaximizeOnActiveMonitor()
            try WinActivate("ahk_id " . AIListPanelGUI.Hwnd)
            catch {
            }
            return
        }
        HideAIListPanel()
        return
    }

    PromptQuickPad_CaptureChromeVisible := openForCapture
    prevHwnd := DllCall("GetForegroundWindow", "ptr")
    if prevHwnd && !PromptQuickPad_CapsB_IsOurGuiWindow(prevHwnd)
        PromptQuickPad_PasteTargetHwnd := prevHwnd

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
        panelH := savedH > 0 ? savedH : 560
    } else if FloatingToolbarGUI != 0 {
        try {
            FloatingToolbarGUI.GetPos(&toolbarX, &toolbarY, &toolbarW, &toolbarH)
            panelW := AIListPanelWindowW > 0 ? AIListPanelWindowW : 520
            panelH := AIListPanelWindowH > 0 ? AIListPanelWindowH : 560
            panelX := toolbarX
            panelY := toolbarY - panelH
            ScreenHeight := SysGet(1)
            if panelY < 0
                panelY := toolbarY + toolbarH + 5
        } catch {
            ScreenWidth := SysGet(0)
            ScreenHeight := SysGet(1)
            panelW := 520
            panelH := 560
            panelX := (ScreenWidth - panelW) // 2
            panelY := (ScreenHeight - panelH) // 2
        }
    } else {
        ScreenWidth := SysGet(0)
        ScreenHeight := SysGet(1)
        panelW := 520
        panelH := 560
        panelX := (ScreenWidth - panelW) // 2
        panelY := (ScreenHeight - panelH) // 2
    }

    AIListPanelWindowX := panelX
    AIListPanelWindowY := panelY
    AIListPanelWindowW := panelW
    AIListPanelWindowH := panelH

    try {
        AIListPanelGUI.Show("x" . panelX . " y" . panelY . " w" . panelW . " h" . panelH)
        if forceCenterMaximize {
            PromptQuickPad_CenterAndMaximizeOnActiveMonitor()
        }
        AIListPanelIsVisible := true
    } catch as err {
        TrayTip("显示失败: " . err.Message, "错误", "Iconx 2")
        return
    }

    if !openForCapture
        PromptQuickPad_SetCaptureChromeVisible(false, false)
    PromptQuickPad_RefreshListView()
    SetTimer(AIListPanelFollowToolbar, 100)

    try {
        HotIfWinActive("ahk_id " . AIListPanelGUI.Hwnd)
        AIListPanelEnterHotkey := Hotkey("Enter", PromptQuickPad_OnEnter, "On")
        AIListPanelEscHotkey := Hotkey("Escape", PromptQuickPad_OnEsc, "On")
        HotIfWinActive()
    } catch {
    }

    if !openForCapture && AIListPanelSearchInput != 0
        AIListPanelSearchInput.Focus()
}

LegacyPromptQuickPad_HideNative() {
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
        PromptQuickPad_CaptureChromeVisible := false
        SetTimer(AIListPanelFollowToolbar, 0)
    }
}

LegacyPromptQuickPad_CreateGUI() {
    global AIListPanelGUI, AIListPanelColors, AIListPanelSearchInput
    global PromptQuickPadListLV, PromptQuickPadStatusText, PromptQuickPadDragBar
    global PromptQuickPadLastCategorySig
    global PromptQuickPadBtnImport, PromptQuickPadBtnExport, PromptQuickPadBtnJsonHelp, PromptQuickPadBtnPinTop
    global PromptQuickPadCaptureToggle, PromptQuickPadLblDraftTitle, PromptQuickPad_edDraftTitle
    global PromptQuickPadLblDraftCat, PromptQuickPad_cbDraftCategory, PromptQuickPadLblDraftTags, PromptQuickPad_edDraftTags
    global PromptQuickPad_chkCaptureSilent, PromptQuickPad_chkCaptureSilentTpl
    global PromptQuickPadLblDraftBody, PromptQuickPad_edDraftContent
    global PromptQuickPad_btnDraftLoad, PromptQuickPad_btnDraftSave, PromptQuickPad_btnDraftClear
    global PromptQuickPadLblListFilter, PromptQuickPad_CaptureChromeVisible

    PromptQuickPad_LoadPinFromIni()

    if AIListPanelGUI != 0 {
        PromptQuickPad_ClearCategoryStrip()
        try AIListPanelGUI.Destroy()
        catch {
        }
    }
    PromptQuickPadLastCategorySig := ""
    PromptQuickPadDragBar := 0
    PromptQuickPad_ResetCaptureDraftRefs()

    PromptQuickPad_LoadFromDisk()
    PromptQuickPad_LoadCaptureExpandedFromIni()

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

    linkInitY := initH - 34
    if linkInitY < 54
        linkInitY := 54
    PromptQuickPadBtnImport := AIListPanelGUI.Add("Text", "x" . margin . " y" . linkInitY . " w40 h18 +0x100 c" . AIListPanelColors.AccentOrange, "导入")
    PromptQuickPadBtnImport.SetFont("s9 underline", "Segoe UI")
    PromptQuickPadBtnImport.OnEvent("Click", PromptQuickPad_DoImport)
    PromptQuickPadBtnExport := AIListPanelGUI.Add("Text", "x" . (margin + 52) . " y" . linkInitY . " w40 h18 +0x100 c" . AIListPanelColors.AccentOrange, "导出")
    PromptQuickPadBtnExport.SetFont("s9 underline", "Segoe UI")
    PromptQuickPadBtnExport.OnEvent("Click", PromptQuickPad_DoExport)
    PromptQuickPadBtnPinTop := AIListPanelGUI.Add("Text", "x" . (margin + 100) . " y" . linkInitY . " w72 h18 +0x100 c" . AIListPanelColors.AccentOrange, "")
    PromptQuickPadBtnPinTop.SetFont("s9 underline", "Segoe UI")
    PromptQuickPadBtnPinTop.OnEvent("Click", PromptQuickPad_TogglePinTop)
    PromptQuickPad_RefreshPinTopLabel()
    PromptQuickPadBtnJsonHelp := AIListPanelGUI.Add("Text", "x" . (margin + 182) . " y" . linkInitY . " w130 h18 +0x100 c" . AIListPanelColors.AccentOrange, "JSON 格式说明")
    PromptQuickPadBtnJsonHelp.SetFont("s9 underline", "Segoe UI")
    PromptQuickPadBtnJsonHelp.OnEvent("Click", PromptQuickPad_ShowJsonFormatHelp)

    capOpts := PromptQuickPad_CaptureChromeVisible ? "" : " Hidden"
    lblW0 := 72
    edX0 := margin + lblW0 + 8
    edW0 := initW - margin - edX0
    if edW0 < 100
        edW0 := 100
    y0 := 200
    PromptQuickPadCaptureToggle := AIListPanelGUI.Add("Text",
        "x" . margin . " y" . y0 . " w" . (initW - margin * 2) . " h22 Center 0x200 +0x100 Background363636 cffffff" . capOpts, "")
    PromptQuickPadCaptureToggle.SetFont("s8", "Segoe UI")
    PromptQuickPadCaptureToggle.OnEvent("Click", PromptQuickPad_OnCaptureToggleClick)
    PromptQuickPad_UpdateCaptureToggleText()
    y0 += 28
    PromptQuickPadLblDraftTitle := AIListPanelGUI.Add("Text", "x" . margin . " y" . y0 . " w" . lblW0 . " h22 c" . AIListPanelColors.Text . capOpts, "标题")
    PromptQuickPad_edDraftTitle := AIListPanelGUI.Add("Edit", "x" . edX0 . " y" . y0 . " w" . edW0 . " h22" . capOpts, "")
    PromptQuickPad_edDraftTitle.SetFont("s9", "Segoe UI")
    y0 += 28
    PromptQuickPadLblDraftCat := AIListPanelGUI.Add("Text", "x" . margin . " y" . y0 . " w" . lblW0 . " h22 c" . AIListPanelColors.Text . capOpts, "分类")
    PromptQuickPad_cbDraftCategory := AIListPanelGUI.Add("ComboBox", "x" . edX0 . " y" . y0 . " w" . edW0 . " h120" . capOpts, PromptQuickPad_BuildDraftCategoryChoices())
    PromptQuickPad_cbDraftCategory.SetFont("s9", "Segoe UI")
    y0 += 28
    PromptQuickPadLblDraftTags := AIListPanelGUI.Add("Text", "x" . margin . " y" . y0 . " w" . lblW0 . " h22 c" . AIListPanelColors.Text . capOpts, "标签")
    PromptQuickPad_edDraftTags := AIListPanelGUI.Add("Edit", "x" . edX0 . " y" . y0 . " w" . edW0 . " h22" . capOpts, "")
    PromptQuickPad_edDraftTags.SetFont("s9", "Segoe UI")
    y0 += 30
    PromptQuickPad_chkCaptureSilent := AIListPanelGUI.Add("Checkbox", "x" . margin . " y" . y0 . " w220 h36" . capOpts,
        "静默 CapsLock+B（勾选时把标题/分类/标签写入 ini）")
    PromptQuickPad_chkCaptureSilent.SetFont("s8", "Segoe UI")
    PromptQuickPad_chkCaptureSilentTpl := AIListPanelGUI.Add("Checkbox", "x" . (margin + 230) . " y" . y0 . " w280 h36" . capOpts,
        "静默时写入模板库，否则写入 prompts.json")
    PromptQuickPad_chkCaptureSilentTpl.SetFont("s8", "Segoe UI")
    y0 += 42
    PromptQuickPadLblDraftBody := AIListPanelGUI.Add("Text", "x" . margin . " y" . y0 . " w120 h18 c" . AIListPanelColors.Text . capOpts, "正文")
    y0 += 22
    PromptQuickPad_edDraftContent := AIListPanelGUI.Add("Edit", "x" . margin . " y" . y0 . " w" . (initW - margin * 2) . " h120 Multi VScroll WantReturn" . capOpts, "")
    PromptQuickPad_edDraftContent.SetFont("s9", "Consolas")
    y0 += 128
    PromptQuickPad_btnDraftLoad := AIListPanelGUI.Add("Button", "x" . margin . " y" . y0 . " w100 h28" . capOpts, "载入所选")
    PromptQuickPad_btnDraftLoad.OnEvent("Click", PromptQuickPad_LoadDraftFromListSelection)
    PromptQuickPad_btnDraftSave := AIListPanelGUI.Add("Button", "x" . (margin + 110) . " y" . y0 . " w100 h28" . capOpts, "保存")
    PromptQuickPad_btnDraftSave.OnEvent("Click", PromptQuickPad_SaveDraftToJson)
    PromptQuickPad_btnDraftClear := AIListPanelGUI.Add("Button", "x" . (margin + 220) . " y" . y0 . " w100 h28" . capOpts, "清空")
    PromptQuickPad_btnDraftClear.OnEvent("Click", PromptQuickPad_ClearCaptureDraft)
    y0 += 36
    PromptQuickPadLblListFilter := AIListPanelGUI.Add("Text", "x" . margin . " y" . y0 . " w120 h18 c888888" . capOpts, "列表搜索")
    PromptQuickPadLblListFilter.SetFont("s8", "Segoe UI")

    PromptQuickPad_chkCaptureSilent.OnEvent("Click", PromptQuickPad_OnCaptureSilentChange)
    PromptQuickPad_chkCaptureSilentTpl.OnEvent("Click", PromptQuickPad_OnCaptureSilentTplChange)
    PromptQuickPad_SyncCaptureDraftFromIni()
    PromptQuickPad_ApplyCaptureControlsVisibility()

    ; -Theme 后 Background/c 在多数系统上才稳定；失败则降级为系统默认外观
    try {
        AIListPanelSearchInput := AIListPanelGUI.Add("Edit",
            "x" . margin . " y486 w" . (initW - margin * 2) . " h22 -Theme Background" . AIListPanelColors.ItemBg . " c" . AIListPanelColors.Text, "")
    } catch {
        AIListPanelSearchInput := AIListPanelGUI.Add("Edit",
            "x" . margin . " y80 w" . (initW - margin * 2) . " h24", "")
    }
    AIListPanelSearchInput.SetFont("s9", "Segoe UI")
    AIListPanelSearchInput.OnEvent("Change", PromptQuickPad_OnSearchChange)

    lvCols := ["标题", "分类", "快捷键", "预览"]
    lvOptsFull := "x" . margin . " y514 w" . (initW - margin * 2) . " h200 -Theme Background" . AIListPanelColors.ItemBg . " c" . AIListPanelColors.Text . " Grid NoSortHdr"
    lvOptsPlain := "x" . margin . " y514 w" . (initW - margin * 2) . " h200 Grid NoSortHdr"
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
