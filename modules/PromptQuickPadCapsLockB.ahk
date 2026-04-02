; CapsLock+B：静默入库 或 打开 Prompt Quick-Pad 内「摘录/采集」区（逻辑在 AIListPanel.ahk）
#Requires AutoHotkey v2.0

; 跨模块全局变量默认值（用于抑制单文件 LSP 误报；运行时会被主脚本真实值覆盖）
global AIListPanelGUI := 0
global FloatingToolbarGUI := 0
global GuiID_ConfigGUI := 0
global GuiID_ClipboardManager := 0
global PromptTemplates := []
global TemplateIndexByID := Map()
global TemplateIndexByTitle := Map()
global TemplateIndexByArrayIndex := Map()
global AIListPanelIsVisible := false
global PromptQuickPadData := []

_PQPCB_CallExternal(funcName, args*) {
    try {
        return (%funcName%)(args*)
    } catch as err {
        OutputDebug("[PQP-CapsB] external call failed: " . funcName . " - " . err.Message)
    }
    return ""
}

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

PromptQuickPad_CapsB_IsOurGuiWindow(hwnd) {
    if !hwnd
        return false
    global AIListPanelGUI, FloatingToolbarGUI, GuiID_ConfigGUI, GuiID_ClipboardManager
    try {
        pqpHwnd := _PQPCB_CallExternal("PQP_GetGuiHwnd")
        if pqpHwnd && hwnd = pqpHwnd
            return true
        if AIListPanelGUI && hwnd = AIListPanelGUI.Hwnd
            return true
        if FloatingToolbarGUI && hwnd = FloatingToolbarGUI.Hwnd
            return true
        if GuiID_ConfigGUI && hwnd = GuiID_ConfigGUI
            return true
        if GuiID_ClipboardManager && hwnd = GuiID_ClipboardManager
            return true
    } catch {
    }
    return false
}

; A_Clipboard 非纯文本时，尝试直接读取 CF_UNICODETEXT（部分应用复制后属性不是 String）
PromptQuickPad_CapsB_ClipboardUnicodeText() {
    if !DllCall("OpenClipboard", "ptr", 0, "int")
        return ""
    hData := 0
    pData := 0
    try {
        hData := DllCall("GetClipboardData", "uint", 13, "ptr")  ; CF_UNICODETEXT
        if !hData
            return ""
        pData := DllCall("GlobalLock", "ptr", hData, "ptr")
        if !pData
            return ""
        return StrGet(pData, "UTF-16")
    } catch {
        return ""
    } finally {
        if pData && hData
            DllCall("GlobalUnlock", "ptr", hData)
        DllCall("CloseClipboard")
    }
}

PromptQuickPad_CapsB_CopySelection(&outText) {
    outText := ""
    fg := DllCall("GetForegroundWindow", "ptr")
    global PromptQuickPad_PasteTargetHwnd
    if PromptQuickPad_CapsB_IsOurGuiWindow(fg) {
        tgt := PromptQuickPad_PasteTargetHwnd
        if !tgt || !DllCall("IsWindow", "ptr", tgt) || PromptQuickPad_CapsB_IsOurGuiWindow(tgt) {
            TrayTip("请先切到要摘录的应用里选中文字（焦点在本面板时无法从其它窗口复制）", "Prompt Quick-Pad", "Icon! 1")
            return false
        }
        try {
            WinActivate("ahk_id " . tgt)
            WinWaitActive("ahk_id " . tgt, , 0.6)
        } catch {
        }
        DllCall("Sleep", "uint", 120)
    } else {
        DllCall("Sleep", "uint", 80)
    }
    oldClip := ClipboardAll()
    try {
        A_Clipboard := ""
        SendInput("^c")
        ok := ClipWait(2.0)
        if !ok {
            Send("^c")
            ok := ClipWait(1.2)
        }
        if !ok {
            SendEvent("^c")
            ok := ClipWait(1.0)
        }
        if !ok
            return false
        DllCall("Sleep", "uint", 60)
        raw := ""
        try
            raw := A_Clipboard
        catch
            return false
        if !(raw is String) {
            try
                raw := String(raw)
            catch
                raw := ""
        }
        if Trim(raw, " `t`r`n") = "" {
            plain := PromptQuickPad_CapsB_ClipboardUnicodeText()
            if plain != ""
                raw := plain
        }
        if Trim(raw, " `t`r`n") = ""
            return false
        outText := Trim(raw, " `t`r`n")
        return true
    } finally {
        try
            A_Clipboard := oldClip
        catch {
        }
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
    _PQPCB_CallExternal("InvalidateTemplateCache")
    try {
        _PQPCB_CallExternal("SavePromptTemplates")
    } catch as err {
        TrayTip("保存模板库失败：" . err.Message, "Prompt Quick-Pad", "Iconx 1")
        return false
    }
    if AIListPanelIsVisible
        _PQPCB_CallExternal("PromptQuickPad_RefreshListView")
    try
        _PQPCB_CallExternal("RefreshPromptListView")
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
    global PromptQuickPadData, AIListPanelIsVisible, PromptQuickPad_PasteTargetHwnd
    PromptQuickPad_ReloadCapsLockBSettings()
    fg := DllCall("GetForegroundWindow", "ptr")
    if !PromptQuickPad_CapsB_IsOurGuiWindow(fg)
        PromptQuickPad_PasteTargetHwnd := fg
    if !PromptQuickPad_CapsB_CopySelection(&t) {
        if !PromptQuickPad_CapsB_IsOurGuiWindow(fg)
            TrayTip("未获取到选中文本（请确认已选中文字，部分程序需先 Ctrl+C）", "Prompt Quick-Pad", "Iconi 1")
        return
    }
    if PromptQuickPad_CapsLockBSilent {
        if PromptQuickPad_CapsLockBSilentToTemplate {
            PromptQuickPad_AppendCapsLockBToTemplateLibrary(t)
            return
        }
        _PQPCB_CallExternal("PromptQuickPad_LoadFromDisk")
        title := Trim(PromptQuickPad_CapsLockBDefaultTitle)
        if title = ""
            title := "摘录"
        cat := Trim(PromptQuickPad_CapsLockBDefaultCategory)
        tags := Trim(PromptQuickPad_CapsLockBDefaultTags)
        normalized := _PQPCB_CallExternal("PromptQuickPad_NormalizeEntry", Map("title", title, "tags", tags, "content", t, "category", cat, "hotkey", ""))
        if normalized is Map
            PromptQuickPadData.Push(normalized)
        else
            PromptQuickPadData.Push(Map("title", title, "tags", tags, "content", t, "category", cat, "hotkey", ""))
        _PQPCB_CallExternal("PromptQuickPad_SaveToDisk")
        if AIListPanelIsVisible
            _PQPCB_CallExternal("PromptQuickPad_RefreshListView")
        TrayTip("已静默保存到用户库（prompts.json）", "Prompt Quick-Pad", "Iconi 1")
        return
    }
    _PQPCB_CallExternal("PromptQuickPad_OpenCaptureDraft", t, true)
}
