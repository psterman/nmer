; ConfigManager.ahk — 配置初始化、导出/导入（由 CursorHelper 主脚本 #Include）
; 依赖：主脚本已定义的 GetText、ConfigFile、NormalizeWindowsPath、ApplyTheme、UpdateTrayIcon、
; SetAutoStart、FTB_*、NormalizeAppearanceActivationMode、CloseConfigGUI、ShowConfigGUI、
; GetClipboardDataForCurrentTab、RefreshClipboardList、ShowImportSuccessTip 等。

; ===================== 初始化配置 =====================
InitConfig() {
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
            ThemeMode := IniRead(ConfigFile, "Settings", "ThemeMode", "dark")
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
