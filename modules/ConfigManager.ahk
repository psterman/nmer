; ConfigManager.ahk — 配置初始化、导出/导入（由 CursorHelper 主脚本 #Include）
; 依赖：主脚本已定义的 GetText、ConfigFile、NormalizeWindowsPath、ApplyTheme、UpdateTrayIcon、
; SetAutoStart、FTB_*、NormalizeAppearanceActivationMode、CloseConfigGUI、ShowConfigGUI、
; GetClipboardDataForCurrentTab、RefreshClipboardList、ShowImportSuccessTip 等。

; ===================== 初始化配置 =====================
_Cfg_FindAsciiMarker(rawBuf, markerText) {
    if !(rawBuf is Buffer)
        return -1
    m := Buffer(StrPut(markerText, "CP0") - 1, 0)
    StrPut(markerText, m, "CP0")
    if (m.Size <= 0 || rawBuf.Size < m.Size)
        return -1
    max := rawBuf.Size - m.Size
    i := 0
    while (i <= max) {
        ok := true
        j := 0
        while (j < m.Size) {
            if (NumGet(rawBuf, i + j, "UChar") != NumGet(m, j, "UChar")) {
                ok := false
                break
            }
            j += 1
        }
        if ok
            return i
        i += 1
    }
    return -1
}

_Cfg_SliceBuffer(src, startPos, byteCount := -1) {
    if !(src is Buffer)
        return Buffer(0)
    if (startPos < 0)
        startPos := 0
    if (startPos >= src.Size)
        return Buffer(0)
    len := (byteCount < 0) ? (src.Size - startPos) : Min(byteCount, src.Size - startPos)
    out := Buffer(len, 0)
    if (len > 0)
        DllCall("RtlMoveMemory", "Ptr", out.Ptr, "Ptr", src.Ptr + startPos, "UPtr", len)
    return out
}

_Cfg_StripLeadingBOM(text) {
    ; 去除字符串开头所有 U+FEFF（字节序标记），避免 FileAppend 再次加 BOM 造成累积
    while (StrLen(text) > 0 && Ord(SubStr(text, 1, 1)) = 0xFEFF)
        text := SubStr(text, 2)
    return text
}

_Cfg_CountLeadingUtf16BOMs(rawBuf) {
    ; 统计文件开头连续的 FF FE（UTF-16 LE BOM）对数
    if !(rawBuf is Buffer) || rawBuf.Size < 2
        return 0
    cnt := 0
    pos := 0
    while (pos + 1 < rawBuf.Size
        && NumGet(rawBuf, pos, "UChar") = 0xFF
        && NumGet(rawBuf, pos + 1, "UChar") = 0xFE) {
        cnt += 1
        pos += 2
    }
    return cnt
}

; 合并 INI 文件中重复的同名 Section（保留首次出现的，将后续出现的键值合并进来，以后出现的同名键优先覆盖首次的）
_Cfg_DeduplicateSections(cfgPath) {
    try {
        if !FileExist(cfgPath)
            return
        content := FileRead(cfgPath, "UTF-16")
        lines := StrSplit(content, "`n")
        ; 收集所有 section 名称及出现次数
        sectionCounts := Map()
        for i, line in lines {
            trimmed := Trim(line, " `r")
            if (RegExMatch(trimmed, "^\[(.+)\]$", &m)) {
                name := m[1]
                sectionCounts[name] := sectionCounts.Has(name) ? sectionCounts[name] + 1 : 1
            }
        }
        ; 判断是否有重复 section
        hasDup := false
        for name, cnt in sectionCounts
            if cnt > 1 {
                hasDup := true
                break
            }
        if !hasDup
            return
        ; 合并：对每个重复段，将后续出现的键合并到第一个段（后出现的同名键覆盖）
        ; 数据结构：sections 数组，每项 {name, keys(Map), order(Array)}，uniqueNames 跟踪已出现
        sections := []          ; [{name, keys, order}, ...]
        sectionIndex := Map()   ; name -> index in sections (first occurrence)
        currentIdx := -1
        for i, line in lines {
            trimmed := Trim(line, " `r")
            if (RegExMatch(trimmed, "^\[(.+)\]$", &m)) {
                name := m[1]
                if sectionIndex.Has(name) {
                    ; 重复段：后续内容合并到已有段
                    currentIdx := sectionIndex[name]
                } else {
                    sections.Push(Map("name", name, "keys", Map(), "order", []))
                    currentIdx := sections.Length
                    sectionIndex[name] := currentIdx
                }
            } else if (currentIdx > 0) {
                ; 属于某个 section 的行（key=value 或空行注释）
                sec := sections[currentIdx]
                if (RegExMatch(trimmed, "^([^;=]+)=(.*)$", &kv)) {
                    key := Trim(kv[1])
                    val := kv[2]
                    if !sec["keys"].Has(key)
                        sec["order"].Push(key)   ; 记录首次出现顺序
                    sec["keys"][key] := val       ; 后出现的覆盖前面的
                }
                ; 注释行和空行不需要合并，直接丢弃（重建时只保留 key=value）
            }
        }
        ; 重建文件内容
        newContent := ""
        for i, sec in sections {
            newContent .= "[" . sec["name"] . "]`r`n"
            for j, key in sec["order"]
                newContent .= key . "=" . sec["keys"][key] . "`r`n"
            newContent .= "`r`n"
        }
        backup := cfgPath . ".bak_dedup_" . A_Now
        try FileCopy(cfgPath, backup, true)
        try FileDelete(cfgPath)
        FileAppend(newContent, cfgPath, "UTF-16")
        OutputDebug("[Config] deduplicated ini sections: " . cfgPath)
    } catch as e {
        OutputDebug("[Config] dedup failed: " . e.Message)
    }
}

_Cfg_NormalizeIniEncoding(cfgPath) {
    try {
        if !FileExist(cfgPath)
            return
        raw := FileRead(cfgPath, "RAW")
        if !(raw is Buffer) || raw.Size < 4
            return

        sampleLen := Min(raw.Size, 512)
        zeroCount := 0
        idx := 1
        while (idx < sampleLen) {
            if (NumGet(raw, idx, "UChar") = 0)
                zeroCount += 1
            idx += 2
        }
        looksUtf16Head := (zeroCount >= 16)
        if !looksUtf16Head {
            utf8Text := _Cfg_StripLeadingBOM(Trim(StrGet(raw, "UTF-8"), "`r`n`t "))
            if (utf8Text = "" || !InStr(utf8Text, "[Settings]"))
                return
            backup := cfgPath . ".bak_utf8_" . A_Now
            try FileCopy(cfgPath, backup, true)
            try FileDelete(cfgPath)
            FileAppend(utf8Text . "`r`n", cfgPath, "UTF-16")
            OutputDebug("[Config] normalized ini utf8->utf16: " . cfgPath)
            return
        }

        asciiSettingsPos := _Cfg_FindAsciiMarker(raw, "[Settings]")
        bomCount := _Cfg_CountLeadingUtf16BOMs(raw)
        ; 已经是干净的 UTF-16（单 BOM、无 ASCII 段落残留），直接跳过避免反复重写导致 BOM 堆叠
        if (asciiSettingsPos < 0 && bomCount <= 1)
            return

        repairedText := ""
        if (asciiSettingsPos > 0) {
            head := _Cfg_SliceBuffer(raw, 0, asciiSettingsPos)
            tail := _Cfg_SliceBuffer(raw, asciiSettingsPos)
            headText := _Cfg_StripLeadingBOM(Trim(StrGet(head, "UTF-16"), "`r`n`t "))
            tailText := _Cfg_StripLeadingBOM(Trim(StrGet(tail, "UTF-8"), "`r`n`t "))

            headHasSettings := InStr(headText, "[Settings]")
            tailHasSettings := InStr(tailText, "[Settings]")
            headHasTheme := InStr(headText, "ThemeMode=")
            tailHasTheme := InStr(tailText, "ThemeMode=")

            ; 混写时优先保留 UTF-16 头（IniWrite 最新写入通常在这里），避免回退到旧尾部配置
            if (headHasSettings && headHasTheme) {
                repairedText := headText
            } else if (tailHasSettings && tailHasTheme) {
                repairedText := tailText
            } else if (headHasSettings) {
                repairedText := headText
            } else {
                repairedText := tailText
            }
        } else {
            repairedText := _Cfg_StripLeadingBOM(Trim(StrGet(raw, "UTF-16"), "`r`n`t "))
        }
        repairedText := _Cfg_StripLeadingBOM(repairedText)
        if (repairedText = "" || !InStr(repairedText, "[Settings]"))
            return

        backup := cfgPath . ".bak_mixed_" . A_Now
        try FileCopy(cfgPath, backup, true)
        try FileDelete(cfgPath)
        FileAppend(repairedText . "`r`n", cfgPath, "UTF-16")
        OutputDebug("[Config] normalized ini encoding: " . cfgPath)
    } catch as e {
        OutputDebug("[Config] normalize ini failed: " . e.Message)
    }
}

; 统一解析 ini / 前端 传来的主题值（去 BOM、兼容中文别名）
NormalizeIniThemeMode(raw, defaultMode := "dark") {
    s := Trim(String(raw))
    if (StrLen(s) > 0 && Ord(SubStr(s, 1, 1)) = 0xFEFF)
        s := SubStr(s, 2)
    s := StrLower(Trim(s))
    if (s = "light" || s = "浅色" || s = "lite")
        return "light"
    if (s = "dark" || s = "深色")
        return "dark"
    return (defaultMode = "light") ? "light" : "dark"
}

; 读取持久化主题：先 [Settings] 再 [Appearance]（与设置页双写一致，规避重复 [Settings] 段导致读不到的问题）
ReadPersistedThemeMode() {
    global ConfigFile
    t1 := IniRead(ConfigFile, "Settings", "ThemeMode", "")
    if (t1 != "")
        return NormalizeIniThemeMode(t1, "dark")
    t2 := IniRead(ConfigFile, "Appearance", "ThemeMode", "")
    if (t2 != "")
        return NormalizeIniThemeMode(t2, "dark")
    return "dark"
}

InitConfig() {
    _Cfg_DeduplicateSections(ConfigFile)
    _Cfg_NormalizeIniEncoding(ConfigFile)
    ; 1. 默认配置
    DefaultCursorPath := "C:\Users\" A_UserName "\AppData\Local\Cursor\Cursor.exe"
    DefaultAISleepTime := 15000
    DefaultCapsLockHoldTimeSeconds := 0.5  ; 默认长按0.5秒
    ; 根据语言设置使用不同的默认提示词
    DefaultLanguage := IniRead(ConfigFile, "Settings", "Language", "zh")
    if (DefaultLanguage = "en") {
        DefaultPrompt_Explain := GetText("default_prompt_explain")
        DefaultPrompt_Refactor := GetText("default_prompt_refactor")
        DefaultPrompt_Optimize := GetText("default_prompt_optimize")
    } else {
        DefaultPrompt_Explain := "解释这段代码的核心逻辑、输入输出、关键函数作用，用新手能懂的语言，标注易错点"
        DefaultPrompt_Refactor := "重构这段代码，遵循PEP8/行业规范，简化冗余逻辑，添加中文注释，保持功能不变"
        DefaultPrompt_Optimize := "分析这段代码的性能瓶颈（时间/空间复杂度），给出优化方案+对比说明，保留原逻辑可读性"
    }
    DefaultSplitHotkey := "s"
    DefaultBatchHotkey := "b"
    DefaultHotkeyESC := "Esc"
    DefaultHotkeyC := "c"
    DefaultHotkeyV := "v"
    DefaultHotkeyX := "x"
    DefaultHotkeyE := "e"
    DefaultHotkeyR := "r"
    DefaultHotkeyO := "o"
    DefaultHotkeyQ := "q"
    DefaultHotkeyZ := "z"
    DefaultCursorShortcut_CommandPalette := "^+p"
    DefaultCursorShortcut_Terminal := "^+``"
    DefaultCursorShortcut_GlobalSearch := "^+f"
    DefaultCursorShortcut_Explorer := "^+e"
    DefaultCursorShortcut_SourceControl := "^+g"
    DefaultCursorShortcut_Extensions := "^+x"
    DefaultCursorShortcut_Browser := "^+b"
    DefaultCursorShortcut_Settings := "^+j"
    DefaultCursorShortcut_CursorSettings := "^,"
    DefaultPanelScreenIndex := 1
    DefaultPanelPosition := "center"
    DefaultFunctionPanelPos := "center"
    DefaultConfigPanelPos := "center"
    DefaultClipboardPanelPos := "center"
    DefaultConfigPanelScreenIndex := 1
    DefaultMsgBoxScreenIndex := 1
    DefaultVoiceInputScreenIndex := 1
    DefaultCursorPanelScreenIndex := 1
    DefaultClipboardPanelScreenIndex := 1
    DefaultLanguage := "zh"  ; 默认中文

    ; 2. 无配置文件则创建
    if !FileExist(ConfigFile) {
        IniWrite(DefaultCursorPath, ConfigFile, "General", "CursorPath")
        IniWrite(DefaultAISleepTime, ConfigFile, "General", "AISleepTime")
        IniWrite(DefaultCapsLockHoldTimeSeconds, ConfigFile, "Settings", "CapsLockHoldTimeSeconds")
        IniWrite(DefaultLanguage, ConfigFile, "General", "Language")
        
        IniWrite(DefaultPrompt_Explain, ConfigFile, "Prompts", "Explain")
        IniWrite(DefaultPrompt_Refactor, ConfigFile, "Prompts", "Refactor")
        IniWrite(DefaultPrompt_Optimize, ConfigFile, "Prompts", "Optimize")
        
        IniWrite(DefaultSplitHotkey, ConfigFile, "Hotkeys", "Split")
        IniWrite(DefaultBatchHotkey, ConfigFile, "Hotkeys", "Batch")
        IniWrite(DefaultHotkeyESC, ConfigFile, "Hotkeys", "ESC")
        IniWrite(DefaultHotkeyC, ConfigFile, "Hotkeys", "C")
        IniWrite(DefaultHotkeyV, ConfigFile, "Hotkeys", "V")
        IniWrite(DefaultHotkeyX, ConfigFile, "Hotkeys", "X")
        IniWrite(DefaultHotkeyE, ConfigFile, "Hotkeys", "E")
        IniWrite(DefaultHotkeyR, ConfigFile, "Hotkeys", "R")
        IniWrite(DefaultHotkeyO, ConfigFile, "Hotkeys", "O")
        IniWrite(DefaultHotkeyQ, ConfigFile, "Hotkeys", "Q")
        IniWrite(DefaultHotkeyZ, ConfigFile, "Hotkeys", "Z")
        IniWrite("f", ConfigFile, "Hotkeys", "F")
        IniWrite("p", ConfigFile, "Hotkeys", "P")
        IniWrite("deepseek", ConfigFile, "Settings", "SearchEngine")
        IniWrite(DefaultCursorShortcut_CommandPalette, ConfigFile, "Settings", "CursorShortcut_CommandPalette")
        IniWrite(DefaultCursorShortcut_Terminal, ConfigFile, "Settings", "CursorShortcut_Terminal")
        IniWrite(DefaultCursorShortcut_GlobalSearch, ConfigFile, "Settings", "CursorShortcut_GlobalSearch")
        IniWrite(DefaultCursorShortcut_Explorer, ConfigFile, "Settings", "CursorShortcut_Explorer")
        IniWrite(DefaultCursorShortcut_SourceControl, ConfigFile, "Settings", "CursorShortcut_SourceControl")
        IniWrite(DefaultCursorShortcut_Extensions, ConfigFile, "Settings", "CursorShortcut_Extensions")
        IniWrite(DefaultCursorShortcut_Browser, ConfigFile, "Settings", "CursorShortcut_Browser")
        IniWrite(DefaultCursorShortcut_Settings, ConfigFile, "Settings", "CursorShortcut_Settings")
        IniWrite(DefaultCursorShortcut_CursorSettings, ConfigFile, "Settings", "CursorShortcut_CursorSettings")
        IniWrite("0", ConfigFile, "Settings", "AutoLoadSelectedText")
        IniWrite("1", ConfigFile, "Settings", "AutoUpdateVoiceInput")
        IniWrite("deepseek", ConfigFile, "Settings", "VoiceSearchSelectedEngines")  ; 保存默认选中的搜索引擎
        IniWrite("0", ConfigFile, "Settings", "AutoStart")  ; 默认不自启动
        IniWrite("1", ConfigFile, "Settings", "CapsLockHoldVkEnabled")  ; 默认启用长按 CapsLock → VK KeyBinder
        ; 保存默认启用的搜索标签（默认全部启用）
        DefaultEnabledCategories := "ai,cli,academic,baidu,image,audio,video,book,price,medical,cloud"
        IniWrite(DefaultEnabledCategories, ConfigFile, "Settings", "VoiceSearchEnabledCategories")
        
        IniWrite(DefaultPanelScreenIndex, ConfigFile, "Appearance", "ScreenIndex")
        IniWrite(DefaultPanelScreenIndex, ConfigFile, "Appearance", "PopupScreenIndex")
        IniWrite(DefaultFunctionPanelPos, ConfigFile, "Appearance", "FunctionPanelPos")
        IniWrite(DefaultConfigPanelPos, ConfigFile, "Appearance", "ConfigPanelPos")
        IniWrite(DefaultClipboardPanelPos, ConfigFile, "Appearance", "ClipboardPanelPos")
        IniWrite("dark", ConfigFile, "Settings", "ThemeMode")  ; 默认暗色主题
        IniWrite("dark", ConfigFile, "Appearance", "ThemeMode")
        IniWrite(DefaultConfigPanelScreenIndex, ConfigFile, "Advanced", "ConfigPanelScreenIndex")
        IniWrite(DefaultMsgBoxScreenIndex, ConfigFile, "Advanced", "MsgBoxScreenIndex")
        IniWrite(DefaultVoiceInputScreenIndex, ConfigFile, "Advanced", "VoiceInputScreenIndex")
        IniWrite(DefaultCursorPanelScreenIndex, ConfigFile, "Advanced", "CursorPanelScreenIndex")
        IniWrite(DefaultClipboardPanelScreenIndex, ConfigFile, "Advanced", "ClipboardPanelScreenIndex")
        
        ; 保存默认快捷操作按钮配置（固定5个按钮）
        IniWrite(5, ConfigFile, "QuickActions", "ButtonCount")
        IniWrite("Explain", ConfigFile, "QuickActions", "Button1Type")
        IniWrite("e", ConfigFile, "QuickActions", "Button1Hotkey")
        IniWrite("Refactor", ConfigFile, "QuickActions", "Button2Type")
        IniWrite("r", ConfigFile, "QuickActions", "Button2Hotkey")
        IniWrite("Optimize", ConfigFile, "QuickActions", "Button3Type")
        IniWrite("o", ConfigFile, "QuickActions", "Button3Hotkey")
        IniWrite("Config", ConfigFile, "QuickActions", "Button4Type")
        IniWrite("q", ConfigFile, "QuickActions", "Button4Hotkey")
        IniWrite("Explain", ConfigFile, "QuickActions", "Button5Type")
        IniWrite("e", ConfigFile, "QuickActions", "Button5Hotkey")
    }

    ; 3. 加载配置（v2的IniRead返回值更直观）
    global CursorPath, AISleepTime, CapsLockHoldTimeSeconds, CapsLockHoldVkEnabled, Prompt_Explain, Prompt_Refactor, Prompt_Optimize, SplitHotkey, BatchHotkey, PanelScreenIndex, Language
    global FunctionPanelPos, ConfigPanelPos, ClipboardPanelPos
    global HotkeyESC, HotkeyC, HotkeyV, HotkeyX, HotkeyE, HotkeyR, HotkeyO, HotkeyQ, HotkeyZ, HotkeyT
    global ConfigPanelScreenIndex, MsgBoxScreenIndex, VoiceInputScreenIndex, CursorPanelScreenIndex, ClipboardPanelScreenIndex
    global QuickActionButtons
    
    ; 确保默认值变量已定义（如果InitConfig未调用）
    if (!IsSet(DefaultCursorPath)) {
        DefaultCursorPath := "C:\Users\" A_UserName "\AppData\Local\Cursor\Cursor.exe"
    }
    if (!IsSet(DefaultAISleepTime)) {
        DefaultAISleepTime := 15000
    }
    if (!IsSet(DefaultCapsLockHoldTimeSeconds)) {
        DefaultCapsLockHoldTimeSeconds := 0.5
    }
    if (!IsSet(DefaultLanguage)) {
        DefaultLanguage := "zh"
    }
    if (!IsSet(DefaultSplitHotkey)) {
        DefaultSplitHotkey := "s"
    }
    if (!IsSet(DefaultBatchHotkey)) {
        DefaultBatchHotkey := "b"
    }
    if (!IsSet(DefaultHotkeyESC)) {
        DefaultHotkeyESC := "Esc"
    }
    if (!IsSet(DefaultHotkeyC)) {
        DefaultHotkeyC := "c"
    }
    if (!IsSet(DefaultHotkeyV)) {
        DefaultHotkeyV := "v"
    }
    if (!IsSet(DefaultHotkeyX)) {
        DefaultHotkeyX := "x"
    }
    if (!IsSet(DefaultHotkeyE)) {
        DefaultHotkeyE := "e"
    }
    if (!IsSet(DefaultHotkeyR)) {
        DefaultHotkeyR := "r"
    }
    if (!IsSet(DefaultHotkeyO)) {
        DefaultHotkeyO := "o"
    }
    if (!IsSet(DefaultHotkeyQ)) {
        DefaultHotkeyQ := "q"
    }
    if (!IsSet(DefaultHotkeyZ)) {
        DefaultHotkeyZ := "z"
    }
    if (!IsSet(DefaultPanelScreenIndex)) {
        DefaultPanelScreenIndex := 1
    }
    if (!IsSet(DefaultFunctionPanelPos)) {
        DefaultFunctionPanelPos := "center"
    }
    if (!IsSet(DefaultConfigPanelPos)) {
        DefaultConfigPanelPos := "center"
    }
    if (!IsSet(DefaultClipboardPanelPos)) {
        DefaultClipboardPanelPos := "center"
    }
    if (!IsSet(DefaultConfigPanelScreenIndex)) {
        DefaultConfigPanelScreenIndex := 1
    }
    if (!IsSet(DefaultMsgBoxScreenIndex)) {
        DefaultMsgBoxScreenIndex := 1
    }
    if (!IsSet(DefaultVoiceInputScreenIndex)) {
        DefaultVoiceInputScreenIndex := 1
    }
    if (!IsSet(DefaultCursorPanelScreenIndex)) {
        DefaultCursorPanelScreenIndex := 1
    }
    if (!IsSet(DefaultClipboardPanelScreenIndex)) {
        DefaultClipboardPanelScreenIndex := 1
    }
    
    try {
        if FileExist(ConfigFile) {
            ; 兼容旧配置格式，优先读取新格式
            CursorPath := NormalizeWindowsPath(IniRead(ConfigFile, "Settings", "CursorPath", IniRead(ConfigFile, "General", "CursorPath", DefaultCursorPath)))
            AISleepTime := Integer(IniRead(ConfigFile, "Settings", "AISleepTime", IniRead(ConfigFile, "General", "AISleepTime", DefaultAISleepTime)))
            ; 读取CapsLock长按时间（秒），如果未设置则使用默认值
            if (!IsSet(DefaultCapsLockHoldTimeSeconds)) {
                DefaultCapsLockHoldTimeSeconds := 0.5
            }
            CapsLockHoldTimeSeconds := Float(IniRead(ConfigFile, "Settings", "CapsLockHoldTimeSeconds", DefaultCapsLockHoldTimeSeconds))
            ; 确保值在合理范围内（0.1秒到5秒）
            if (CapsLockHoldTimeSeconds < 0.1) {
                CapsLockHoldTimeSeconds := 0.1
            } else if (CapsLockHoldTimeSeconds > 5.0) {
                CapsLockHoldTimeSeconds := 5.0
            }
            ; 【确保持久化】将验证后的值写回 ini 文件，确保配置总是保存的（使用字符串格式）
            IniWrite(String(CapsLockHoldTimeSeconds), ConfigFile, "Settings", "CapsLockHoldTimeSeconds")
            ; 读取倒计时延迟时间（秒），如果未设置则使用默认值
            global LaunchDelaySeconds
            if (!IsSet(LaunchDelaySeconds)) {
                LaunchDelaySeconds := 3.0
            }
            LaunchDelaySeconds := Float(IniRead(ConfigFile, "Settings", "LaunchDelaySeconds", LaunchDelaySeconds))
            ; 确保值在合理范围内（0.5秒到10秒）
            if (LaunchDelaySeconds < 0.5) {
                LaunchDelaySeconds := 0.5
            } else if (LaunchDelaySeconds > 10.0) {
                LaunchDelaySeconds := 10.0
            }
            ; 【确保持久化】将验证后的值写回 ini 文件
            IniWrite(String(LaunchDelaySeconds), ConfigFile, "Settings", "LaunchDelaySeconds")
            Language := IniRead(ConfigFile, "Settings", "Language", IniRead(ConfigFile, "General", "Language", DefaultLanguage))
            
            ; 读取prompt，如果为空或使用默认值，根据当前语言设置
            Prompt_Explain := IniRead(ConfigFile, "Settings", "Prompt_Explain", IniRead(ConfigFile, "Prompts", "Explain", ""))
            Prompt_Refactor := IniRead(ConfigFile, "Settings", "Prompt_Refactor", IniRead(ConfigFile, "Prompts", "Refactor", ""))
            Prompt_Optimize := IniRead(ConfigFile, "Settings", "Prompt_Optimize", IniRead(ConfigFile, "Prompts", "Optimize", ""))
            
            ; 如果prompt为空，根据当前语言设置默认值
            ; 确保DefaultPrompt_Explain等变量已定义
            if (!IsSet(DefaultPrompt_Explain)) {
                if (Language = "zh") {
                    DefaultPrompt_Explain := "解释这段代码的核心逻辑、输入输出、关键函数作用，用新手能懂的语言，标注易错点"
                    DefaultPrompt_Refactor := "重构这段代码，遵循PEP8/行业规范，简化冗余逻辑，添加中文注释，保持功能不变"
                    DefaultPrompt_Optimize := "分析这段代码的性能瓶颈（时间/空间复杂度），给出优化方案+对比说明，保留原逻辑可读性"
                } else {
                    DefaultPrompt_Explain := GetText("default_prompt_explain")
                    DefaultPrompt_Refactor := GetText("default_prompt_refactor")
                    DefaultPrompt_Optimize := GetText("default_prompt_optimize")
                }
            }
            ; 检查prompt是否为中文默认值，如果是且当前语言是英文，则替换为英文
            ; 检查 prompt 是否为中文或英文默认值，根据当前语言进行适配
            ; 获取两种语言的默认值
            ; 注意：静态变量或临时获取
            zhExp := "解释这段代码的核心逻辑、输入输出、关键函数作用，用新手能懂的语言，标注易错点"
            zhRef := "重构这段代码，遵循PEP8/行业规范，简化冗余逻辑，添加中文注释，保持功能不变"
            zhOpt := "分析这段代码的性能瓶颈（时间/空间复杂度），给出优化方案+对比说明，保留原逻辑可读性"
            
            ; 临时切换语言环境获取英文默认值
            OldLang := Language
            Language := "en"
            enExp := GetText("default_prompt_explain")
            enRef := GetText("default_prompt_refactor")
            enOpt := GetText("default_prompt_optimize")
            Language := OldLang
            
            if (Prompt_Explain == "" || Prompt_Explain == zhExp || Prompt_Explain == enExp) {
                Prompt_Explain := (Language == "zh") ? zhExp : enExp
            }
            if (Prompt_Refactor == "" || Prompt_Refactor == zhRef || Prompt_Refactor == enRef) {
                Prompt_Refactor := (Language == "zh") ? zhRef : enRef
            }
            if (Prompt_Optimize == "" || Prompt_Optimize == zhOpt || Prompt_Optimize == enOpt) {
                Prompt_Optimize := (Language == "zh") ? zhOpt : enOpt
            }
            
            SplitHotkey := IniRead(ConfigFile, "Hotkeys", "Split", DefaultSplitHotkey)
            BatchHotkey := IniRead(ConfigFile, "Hotkeys", "Batch", DefaultBatchHotkey)
            HotkeyESC := IniRead(ConfigFile, "Hotkeys", "ESC", DefaultHotkeyESC)
            HotkeyC := IniRead(ConfigFile, "Hotkeys", "C", DefaultHotkeyC)
            HotkeyV := IniRead(ConfigFile, "Hotkeys", "V", DefaultHotkeyV)
            HotkeyX := IniRead(ConfigFile, "Hotkeys", "X", DefaultHotkeyX)
            HotkeyE := IniRead(ConfigFile, "Hotkeys", "E", DefaultHotkeyE)
            HotkeyR := IniRead(ConfigFile, "Hotkeys", "R", DefaultHotkeyR)
            HotkeyO := IniRead(ConfigFile, "Hotkeys", "O", DefaultHotkeyO)
            HotkeyQ := IniRead(ConfigFile, "Hotkeys", "Q", DefaultHotkeyQ)
            HotkeyZ := IniRead(ConfigFile, "Hotkeys", "Z", DefaultHotkeyZ)
            HotkeyF := IniRead(ConfigFile, "Hotkeys", "F", "f")
            HotkeyT := IniRead(ConfigFile, "Hotkeys", "T", "t")
            HotkeyP := IniRead(ConfigFile, "Hotkeys", "P", "p")
            global PromptQuickCaptureHotkey
            PromptQuickCaptureHotkey := IniRead(ConfigFile, "Settings", "PromptQuickCaptureHotkey", "")
            global CursorShortcut_CommandPalette, CursorShortcut_Terminal, CursorShortcut_GlobalSearch
            global CursorShortcut_Explorer, CursorShortcut_SourceControl, CursorShortcut_Extensions
            global CursorShortcut_Browser, CursorShortcut_Settings, CursorShortcut_CursorSettings
            CursorShortcut_CommandPalette := IniRead(ConfigFile, "Settings", "CursorShortcut_CommandPalette", "^+p")
            CursorShortcut_Terminal := IniRead(ConfigFile, "Settings", "CursorShortcut_Terminal", "^+``")
            CursorShortcut_GlobalSearch := IniRead(ConfigFile, "Settings", "CursorShortcut_GlobalSearch", "^+f")
            CursorShortcut_Explorer := IniRead(ConfigFile, "Settings", "CursorShortcut_Explorer", "^+e")
            CursorShortcut_SourceControl := IniRead(ConfigFile, "Settings", "CursorShortcut_SourceControl", "^+g")
            CursorShortcut_Extensions := IniRead(ConfigFile, "Settings", "CursorShortcut_Extensions", "^+x")
            CursorShortcut_Browser := IniRead(ConfigFile, "Settings", "CursorShortcut_Browser", "^+b")
            CursorShortcut_Settings := IniRead(ConfigFile, "Settings", "CursorShortcut_Settings", "^+j")
            CursorShortcut_CursorSettings := IniRead(ConfigFile, "Settings", "CursorShortcut_CursorSettings", "^,")
            SearchEngine := IniRead(ConfigFile, "Settings", "SearchEngine", "deepseek")
            AutoLoadSelectedText := (IniRead(ConfigFile, "Settings", "AutoLoadSelectedText", "0") = "1")
            AutoUpdateVoiceInput := (IniRead(ConfigFile, "Settings", "AutoUpdateVoiceInput", "1") = "1")
            AutoStart := (IniRead(ConfigFile, "Settings", "AutoStart", "0") = "1")
            global CapsLockHoldVkEnabled
            CapsLockHoldVkEnabled := (IniRead(ConfigFile, "Settings", "CapsLockHoldVkEnabled", "1") = "1")
            IniWrite(CapsLockHoldVkEnabled ? "1" : "0", ConfigFile, "Settings", "CapsLockHoldVkEnabled")
            global DefaultStartTab
            DefaultStartTab := IniRead(ConfigFile, "Settings", "DefaultStartTab", "general")
            global FloatingToolbarButtonItems
            FloatingToolbarButtonItems := FTB_SanitizeToolbarButtonItems(IniRead(ConfigFile, "Settings", "FloatingToolbarButtonItems", FTB_ItemsToCsv(FloatingToolbarButtonItems)))
            IniWrite(FTB_ItemsToCsv(FloatingToolbarButtonItems), ConfigFile, "Settings", "FloatingToolbarButtonItems")
            ; 读取自定义图标路径
            global CustomIconPath
            CustomIconPath := IniRead(ConfigFile, "Settings", "CustomIconPath", "")
            ; 如果路径存在且文件存在，使用自定义图标；否则使用默认图标
            if (CustomIconPath != "" && FileExist(CustomIconPath)) {
                ; 使用自定义图标
            } else {
                CustomIconPath := ""
            }
            TrySetTrayIconHighQuality()
            ; 验证值是否有效，如果无效则使用默认值
            if (DefaultStartTab != "general" && DefaultStartTab != "appearance" && DefaultStartTab != "prompts" && DefaultStartTab != "hotkeys" && DefaultStartTab != "advanced" && DefaultStartTab != "search") {
                DefaultStartTab := "general"
            }
            
            ; 加载启用的搜索标签
            global VoiceSearchEnabledCategories
            EnabledCategoriesStr := IniRead(ConfigFile, "Settings", "VoiceSearchEnabledCategories", "ai,cli,academic,baidu,image,audio,video,book,price,medical,cloud")
            if (EnabledCategoriesStr != "") {
                VoiceSearchEnabledCategories := []
                CategoriesArray := StrSplit(EnabledCategoriesStr, ",")
                for Index, Category in CategoriesArray {
                    Category := Trim(Category)
                    if (Category != "") {
                        VoiceSearchEnabledCategories.Push(Category)
                    }
                }
                ; 如果解析后为空，使用默认值
                if (VoiceSearchEnabledCategories.Length = 0) {
                    VoiceSearchEnabledCategories := ["ai", "cli", "academic", "baidu", "image", "audio", "video", "book", "price", "medical", "cloud"]
                }
            } else {
                VoiceSearchEnabledCategories := ["ai", "cli", "academic", "baidu", "image", "audio", "video", "book", "price", "medical", "cloud"]
            }
            
            ; 应用自启动设置
            SetAutoStart(AutoStart)
            
            ; 加载主题模式（暗色或亮色）
            global ThemeMode
            ThemeMode := ReadPersistedThemeMode()
            ApplyTheme(ThemeMode)
            
            ; 更新托盘图标（使用自定义图标）
            UpdateTrayIcon()
            
            ; 初始化每个分类的搜索引擎选择状态Map
            global VoiceSearchSelectedEnginesByCategory
            if (!IsSet(VoiceSearchSelectedEnginesByCategory) || !IsObject(VoiceSearchSelectedEnginesByCategory)) {
                VoiceSearchSelectedEnginesByCategory := Map()
            }
            
            ; 加载每个分类的搜索引擎选择状态
            AllCategories := ["ai", "cli", "academic", "baidu", "image", "audio", "video", "book", "price", "medical", "cloud"]
            for Index, Category in AllCategories {
                CategoryEnginesStr := IniRead(ConfigFile, "Settings", "VoiceSearchSelectedEngines_" . Category, "")
                if (CategoryEnginesStr != "") {
                    ; 解析格式：分类:引擎1,引擎2 或直接是 引擎1,引擎2
                    if (InStr(CategoryEnginesStr, ":") > 0) {
                        EnginesStr := SubStr(CategoryEnginesStr, InStr(CategoryEnginesStr, ":") + 1)
                    } else {
                        EnginesStr := CategoryEnginesStr
                    }
                    EnginesArray := StrSplit(EnginesStr, ",")
                    CategoryEngines := []
                    for EngIndex, Engine in EnginesArray {
                        Engine := Trim(Engine)
                        if (Engine != "") {
                            CategoryEngines.Push(Engine)
                        }
                    }
                    if (CategoryEngines.Length > 0) {
                        VoiceSearchSelectedEnginesByCategory[Category] := CategoryEngines
                    }
                }
            }
            
            ; 加载当前分类的搜索引擎选择状态（兼容旧版本）
            global VoiceSearchCurrentCategory
            if (!IsSet(VoiceSearchCurrentCategory) || VoiceSearchCurrentCategory = "") {
                VoiceSearchCurrentCategory := "ai"
            }
            
            ; 如果当前分类有保存的状态，使用它；否则使用默认值
            if (VoiceSearchSelectedEnginesByCategory.Has(VoiceSearchCurrentCategory)) {
                VoiceSearchSelectedEngines := []
                for Index, Engine in VoiceSearchSelectedEnginesByCategory[VoiceSearchCurrentCategory] {
                    VoiceSearchSelectedEngines.Push(Engine)
                }
            } else {
                ; 兼容旧版本：加载全局的搜索引擎选择
                VoiceSearchSelectedEnginesStr := IniRead(ConfigFile, "Settings", "VoiceSearchSelectedEngines", "deepseek")
                if (VoiceSearchSelectedEnginesStr != "") {
                    VoiceSearchSelectedEngines := []
                    EnginesArray := StrSplit(VoiceSearchSelectedEnginesStr, ",")
                    for Index, Engine in EnginesArray {
                        Engine := Trim(Engine)
                        if (Engine != "") {
                            VoiceSearchSelectedEngines.Push(Engine)
                        }
                    }
                    ; 如果解析后为空，使用默认值
                    if (VoiceSearchSelectedEngines.Length = 0) {
                        VoiceSearchSelectedEngines := ["deepseek"]
                    }
                    ; 保存到当前分类的Map中
                    CurrentEngines := []
                    for Index, Engine in VoiceSearchSelectedEngines {
                        CurrentEngines.Push(Engine)
                    }
                    VoiceSearchSelectedEnginesByCategory[VoiceSearchCurrentCategory] := CurrentEngines
                } else {
                    VoiceSearchSelectedEngines := ["deepseek"]
                }
            }
            
            UnifiedPopupScreenIndex := Integer(IniRead(ConfigFile, "Appearance", "PopupScreenIndex", IniRead(ConfigFile, "Appearance", "ScreenIndex", DefaultPanelScreenIndex)))
            PanelScreenIndex := UnifiedPopupScreenIndex
            FunctionPanelPos := IniRead(ConfigFile, "Appearance", "FunctionPanelPos", DefaultFunctionPanelPos)
            ConfigPanelPos := IniRead(ConfigFile, "Appearance", "ConfigPanelPos", DefaultConfigPanelPos)
            ClipboardPanelPos := IniRead(ConfigFile, "Appearance", "ClipboardPanelPos", DefaultClipboardPanelPos)
            ConfigPanelScreenIndex := UnifiedPopupScreenIndex
            MsgBoxScreenIndex := UnifiedPopupScreenIndex
            VoiceInputScreenIndex := UnifiedPopupScreenIndex
            CursorPanelScreenIndex := UnifiedPopupScreenIndex
            ClipboardPanelScreenIndex := UnifiedPopupScreenIndex
            
            global AppearanceActivationMode
            AppearanceActivationMode := NormalizeAppearanceActivationMode(IniRead(ConfigFile, "Appearance", "ActivationMode", "toolbar"))
            
            ; 加载快捷操作按钮配置
            QuickActionButtons := []
            ButtonCount := Integer(IniRead(ConfigFile, "QuickActions", "ButtonCount", "5"))
            if (ButtonCount < 1) {
                ButtonCount := 5
            }
            if (ButtonCount > 5) {
                ButtonCount := 5
            }
            Loop ButtonCount {
                Index := A_Index
                ButtonType := IniRead(ConfigFile, "QuickActions", "Button" . Index . "Type", "")
                ButtonHotkey := IniRead(ConfigFile, "QuickActions", "Button" . Index . "Hotkey", "")
                ; 修改：允许 Hotkey 为空（新增的 Cursor 快捷键选项没有 Hotkey）
                if (ButtonType != "") {
                    QuickActionButtons.Push({Type: ButtonType, Hotkey: ButtonHotkey})
                } else {
                    ; 如果某个按钮配置缺失，使用默认值
                    QuickActionButtons.Push({Type: "Explain", Hotkey: "e"})
                }
            }
            ; 确保有5个按钮
            while (QuickActionButtons.Length < 5) {
                QuickActionButtons.Push({Type: "Explain", Hotkey: "e"})
            }
            while (QuickActionButtons.Length > 5) {
                QuickActionButtons.Pop()
            }
            ; 如果没有加载到任何按钮，使用默认配置
            if (QuickActionButtons.Length = 0) {
                QuickActionButtons := [
                    {Type: "Explain", Hotkey: "e"},
                    {Type: "Refactor", Hotkey: "r"},
                    {Type: "Optimize", Hotkey: "o"},
                    {Type: "Config", Hotkey: "q"},
                    {Type: "Explain", Hotkey: "e"}
                ]
            }
        } else {
            ; If config file doesn't exist, use default values directly
            CursorPath := DefaultCursorPath
            AISleepTime := DefaultAISleepTime
            CapsLockHoldTimeSeconds := DefaultCapsLockHoldTimeSeconds
            Language := DefaultLanguage
            ; 根据当前语言设置默认prompt值
            ChineseDefaultExplain := "解释这段代码的核心逻辑、输入输出、关键函数作用，用新手能懂的语言，标注易错点"
            ChineseDefaultRefactor := "重构这段代码，遵循PEP8/行业规范，简化冗余逻辑，添加中文注释，保持功能不变"
            ChineseDefaultOptimize := "分析这段代码的性能瓶颈（时间/空间复杂度），给出优化方案+对比说明，保留原逻辑可读性"
            Prompt_Explain := (Language = "zh") ? ChineseDefaultExplain : GetText("default_prompt_explain")
            Prompt_Refactor := (Language = "zh") ? ChineseDefaultRefactor : GetText("default_prompt_refactor")
            Prompt_Optimize := (Language = "zh") ? ChineseDefaultOptimize : GetText("default_prompt_optimize")
            SplitHotkey := DefaultSplitHotkey
            BatchHotkey := DefaultBatchHotkey
            HotkeyESC := DefaultHotkeyESC
            HotkeyC := DefaultHotkeyC
            HotkeyV := DefaultHotkeyV
            HotkeyX := DefaultHotkeyX
            HotkeyE := DefaultHotkeyE
            HotkeyR := DefaultHotkeyR
            HotkeyO := DefaultHotkeyO
            HotkeyQ := DefaultHotkeyQ
            HotkeyZ := DefaultHotkeyZ
            CapsLockHoldTimeSeconds := DefaultCapsLockHoldTimeSeconds
            PanelScreenIndex := DefaultPanelScreenIndex
            FunctionPanelPos := DefaultFunctionPanelPos
            ConfigPanelPos := DefaultConfigPanelPos
            ClipboardPanelPos := DefaultClipboardPanelPos
            ConfigPanelScreenIndex := DefaultConfigPanelScreenIndex
            MsgBoxScreenIndex := DefaultMsgBoxScreenIndex
            VoiceInputScreenIndex := DefaultVoiceInputScreenIndex
            CursorPanelScreenIndex := DefaultCursorPanelScreenIndex
            ClipboardPanelScreenIndex := DefaultClipboardPanelScreenIndex
            AutoStart := false
            global CapsLockHoldVkEnabled
            CapsLockHoldVkEnabled := true
            global FloatingToolbarButtonItems, FloatingToolbarMenuItems
            FloatingToolbarButtonItems := FTB_SanitizeToolbarButtonItems(FloatingToolbarButtonItems)
            FloatingToolbarMenuItems := FTB_SanitizeToolbarMenuItems(FloatingToolbarMenuItems)
            VoiceSearchEnabledCategories := ["ai", "cli", "academic", "baidu", "image", "audio", "video", "book", "price", "medical", "cloud"]
            global PromptQuickCaptureHotkey
            PromptQuickCaptureHotkey := ""
            global AppearanceActivationMode
            AppearanceActivationMode := "toolbar"
        }
    } catch as e {
        MsgBox("Error loading config: " . e.Message, "Error", "IconX")
        ; Fallback to defaults in case of error
        CursorPath := DefaultCursorPath
        AISleepTime := DefaultAISleepTime
        Language := DefaultLanguage
        ; 根据当前语言设置默认prompt值
        ChineseDefaultExplain := "解释这段代码的核心逻辑、输入输出、关键函数作用，用新手能懂的语言，标注易错点"
        ChineseDefaultRefactor := "重构这段代码，遵循PEP8/行业规范，简化冗余逻辑，添加中文注释，保持功能不变"
        ChineseDefaultOptimize := "分析这段代码的性能瓶颈（时间/空间复杂度），给出优化方案+对比说明，保留原逻辑可读性"
        Prompt_Explain := (Language = "zh") ? ChineseDefaultExplain : GetText("default_prompt_explain")
        Prompt_Refactor := (Language = "zh") ? ChineseDefaultRefactor : GetText("default_prompt_refactor")
        Prompt_Optimize := (Language = "zh") ? ChineseDefaultOptimize : GetText("default_prompt_optimize")
        SplitHotkey := DefaultSplitHotkey
        BatchHotkey := DefaultBatchHotkey
        HotkeyESC := DefaultHotkeyESC
        HotkeyC := DefaultHotkeyC
        HotkeyV := DefaultHotkeyV
        HotkeyX := DefaultHotkeyX
        HotkeyE := DefaultHotkeyE
        HotkeyR := DefaultHotkeyR
        HotkeyO := DefaultHotkeyO
        HotkeyQ := DefaultHotkeyQ
        HotkeyZ := DefaultHotkeyZ
        PanelScreenIndex := DefaultPanelScreenIndex
        FunctionPanelPos := DefaultFunctionPanelPos
        ConfigPanelPos := DefaultConfigPanelPos
        ClipboardPanelPos := DefaultClipboardPanelPos
        ConfigPanelScreenIndex := DefaultConfigPanelScreenIndex
        MsgBoxScreenIndex := DefaultMsgBoxScreenIndex
        VoiceInputScreenIndex := DefaultVoiceInputScreenIndex
        CursorPanelScreenIndex := DefaultCursorPanelScreenIndex
        ClipboardPanelScreenIndex := DefaultClipboardPanelScreenIndex
        global FloatingToolbarButtonItems, FloatingToolbarMenuItems
        FloatingToolbarButtonItems := FTB_SanitizeToolbarButtonItems(FloatingToolbarButtonItems)
        FloatingToolbarMenuItems := FTB_SanitizeToolbarMenuItems(FloatingToolbarMenuItems)
        global PromptQuickCaptureHotkey
        PromptQuickCaptureHotkey := ""
        global AppearanceActivationMode
        AppearanceActivationMode := "toolbar"
    }
    
    global AppearanceActivationMode
    AppearanceActivationMode := NormalizeAppearanceActivationMode(AppearanceActivationMode)
    
    ; 验证语言设置
    if (Language != "zh" && Language != "en") {
        Language := "zh"  ; 默认中文
    }
}
; ===================== 导出导入配置功能 =====================
; 导出配置
ExportConfig(*) {
    global ConfigFile
    
    ExportPath := FileSelect("S", A_ScriptDir "\CursorHelper_Config_" . A_Now . ".ini", GetText("export_config"), "INI Files (*.ini)")
    if (ExportPath = "") {
        return
    }
    
    try {
        FileCopy(ConfigFile, ExportPath, 1)
        MsgBox(GetText("export_success"), GetText("tip"), "Iconi")
    } catch as e {
        MsgBox(GetText("import_failed") . ": " . e.Message, GetText("error"), "Iconx")
    }
}

; 导入配置
ImportConfig(*) {
    global ConfigFile
    
    ImportPath := FileSelect(1, A_ScriptDir, GetText("import_config"), "INI Files (*.ini)")
    if (ImportPath = "") {
        return
    }
    
    try {
        FileCopy(ImportPath, ConfigFile, 1)
        ; 重新加载配置
        InitConfig()
        ; 关闭并重新打开配置面板
        CloseConfigGUI()
        ShowConfigGUI()
        ; 显示成功提示（确保在最前方）
        SetTimer(ShowImportSuccessTip, -100)
    } catch as e {
        MsgBox(GetText("import_failed") . ": " . e.Message, GetText("error"), "Iconx")
    }
}

; 导出剪贴板历史
ExportClipboard(*) {
    global ClipboardHistory_CtrlC, ClipboardHistory_CapsLockC, ClipboardCurrentTab
    
    ; 获取当前标签页的数据
    DataInfo := GetClipboardDataForCurrentTab()
    CurrentHistory := DataInfo.Data
    
    if (CurrentHistory.Length = 0) {
        MsgBox(GetText("no_clipboard"), GetText("tip"), "Iconi")
        return
    }
    
        TabName := "CapsLockC"
    ExportPath := FileSelect("S", A_ScriptDir "\ClipboardHistory_" . TabName . "_" . A_Now . ".txt", GetText("export_clipboard"), "Text Files (*.txt)")
    if (ExportPath = "") {
        return
    }
    
    try {
        Content := "=== " . TabName . " Clipboard History ===`n`n"
        for Index, ItemData in CurrentHistory {
            ; 检查数据结构：如果是Map（数据库模式），使用Content；如果是字符串（数组模式），直接使用
            ItemContent := ""
            if (IsObject(ItemData) && ItemData.Has("Content")) {
                ItemContent := ItemData["Content"]
            } else if (Type(ItemData) = "String") {
                ItemContent := ItemData
            }
            if (ItemContent != "") {
                Content .= "=== Item " . Index . " ===`n"
                Content .= ItemContent . "`n`n"
            }
        }
        FileDelete(ExportPath)
        FileAppend(Content, ExportPath, "UTF-8")
        MsgBox(GetText("export_success"), GetText("tip"), "Iconi")
    } catch as e {
        MsgBox(GetText("import_failed") . ": " . e.Message, GetText("error"), "Iconx")
    }
}

; 导入剪贴板历史
ImportClipboard(*) {
    global ClipboardHistory_CtrlC, ClipboardHistory_CapsLockC, ClipboardCurrentTab
    
    ImportPath := FileSelect(1, A_ScriptDir, GetText("import_clipboard"), "Text Files (*.txt)")
    if (ImportPath = "") {
        return
    }
    
    try {
        Content := FileRead(ImportPath, "UTF-8")
        
        ; 解析导入的内容
        Lines := StrSplit(Content, "`n")
        ImportedItems := []
        CurrentItem := ""
        for Index, Line in Lines {
            ; 跳过标题行
            if (InStr(Line, "=== ") = 1 && InStr(Line, " Clipboard History") > 0) {
                continue
            }
            if (InStr(Line, "=== Item ") = 1) {
                if (CurrentItem != "") {
                    ImportedItems.Push(Trim(CurrentItem, "`r`n "))
                    CurrentItem := ""
                }
            } else if (Line != "") {
                CurrentItem .= Line . "`n"
            }
        }
        ; 添加最后一项
        if (CurrentItem != "") {
            ImportedItems.Push(Trim(CurrentItem, "`r`n "))
        }
        
        ; 根据当前Tab导入数据
        if (ClipboardCurrentTab = "CtrlC") {
            ; Ctrl+C 标签：导入到数组
            global ClipboardHistory_CtrlC := ImportedItems
        } else {
            ; CapsLock+C 标签：导入到数据库
            global ClipboardDB
            if (ClipboardDB && ClipboardDB != 0) {
                try {
                    ClipboardDB.Exec("BEGIN IMMEDIATE")
                    ClipboardDB.Exec("DELETE FROM ClipboardHistory")
                    for Index, Item in ImportedItems {
                        EscapedContent := StrReplace(Item, "'", "''")
                        SQL := "INSERT INTO ClipboardHistory (Content, SourceApp) VALUES ('" . EscapedContent . "', 'Import')"
                        if !ClipboardDB.Exec(SQL) {
                            throw Error(ClipboardDB.ErrorMsg)
                        }
                    }
                    ClipboardDB.Exec("COMMIT")
                } catch as err {
                    try ClipboardDB.Exec("ROLLBACK")
                    catch {
                    }
                    global ClipboardHistory_CapsLockC := ImportedItems
                }
            } else {
                ; 数据库未初始化，导入到数组
                global ClipboardHistory_CapsLockC := ImportedItems
            }
        }
        
        ; 刷新剪贴板列表
        RefreshClipboardList()
        
        ; 显示成功提示（确保在最前方）
        SetTimer(ShowImportSuccessTip, -100)
    } catch as e {
        MsgBox(GetText("import_failed") . ": " . e.Message, GetText("error"), "Iconx")
    }
}
