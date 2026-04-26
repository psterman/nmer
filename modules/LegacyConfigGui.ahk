; LegacyConfigGui.ahk — 原生全屏配置窗（UseWebViewSettings = false）
; 由 CursorHelper 主脚本拆分；依赖主脚本已加载的工具与全局变量。
global CloseConfigGUI_IsClosing := false

; ===================== 配置面板辅助函数 =====================
; 这些函数需要在 ShowConfigGUI 之前定义

; 全局变量声明
global CurrentTab := ""
global ConfigTabs := Map()
global GeneralTabPanel := 0
global GeneralTabControls := []
global AppearanceTabPanel := 0
global AppearanceTabControls := []
global PromptsTabPanel := 0
global PromptsTabControls := []
global HotkeysTabPanel := 0
global HotkeysTabControls := []
global HotkeysMainTabs := Map()  ; 快捷键主标签（快捷键设置/Cursor规则）
global HotkeysMainTabControls := Map()  ; 快捷键主标签控件映射
global CursorRulesSubTabs := Map()  ; Cursor规则子标签
global CursorRulesSubTabControls := Map()  ; Cursor规则子标签控件映射
global AdvancedTabPanel := 0
global AdvancedTabControls := []
global CursorPathEdit := 0
global LangChinese := 0
global LangEnglish := 0
global AISleepTimeEdit := 0
global CapsLockHoldTimeEdit := 0
global PromptExplainEdit := 0
global PromptRefactorEdit := 0
global PromptOptimizeEdit := 0
global SplitHotkeyEdit := 0
global BatchHotkeyEdit := 0
global HotkeyESCEdit := 0
global HotkeyCEdit := 0
global HotkeyVEdit := 0
global HotkeyXEdit := 0
global HotkeyEEdit := 0
global HotkeyREdit := 0
global HotkeyOEdit := 0
global HotkeyQEdit := 0
global HotkeyZEdit := 0
global HotkeyTEdit := 0
global PanelScreenRadio := []
; 已移除动画定时器，改用图片显示

; ===================== 标签切换函数 =====================
SwitchTab(TabName) {
    global ConfigTabs, CurrentTab
    global GeneralTabControls, AppearanceTabControls, PromptsTabControls, HotkeysTabControls, AdvancedTabControls, SearchTabControls
    
    ; 重置所有标签样式（使用 Material 风格单选按钮）
    global TabRadioGroup
    if (TabRadioGroup && TabRadioGroup.Length > 0) {
        for Index, TabBtn in TabRadioGroup {
            if (TabBtn) {
                try {
                    TabBtn.IsSelected := false
                    UpdateMaterialRadioButtonStyle(TabBtn, false)
                }
            }
        }
    }
    
    ; 设置当前标签样式（选中状态）
    if (ConfigTabs.Has(TabName) && ConfigTabs[TabName]) {
        try {
            ConfigTabs[TabName].IsSelected := true
            UpdateMaterialRadioButtonStyle(ConfigTabs[TabName], true)
        }
    }
    
    ; 辅助函数：可以隐藏控制列表
    HideControls(ControlList) {
        if (ControlList && ControlList.Length > 0) {
            for Ctrl in ControlList {
                try {
                    if (Ctrl) {
                        Ctrl.Visible := false
                    }
                } catch as err {
                    ; 忽略已销毁的控件
                }
            }
        }
    }
    
    ; 辅助函数：显示控制列表
    ShowControls(ControlList) {
        if (ControlList && ControlList.Length > 0) {
            for Ctrl in ControlList {
                try {
                    if (Ctrl) {
                        Ctrl.Visible := true
                    }
                } catch as err {
                    ; 忽略已销毁的控件
                }
            }
        }
    }

    ; 隐藏所有标签页内容
    HideControls(GeneralTabControls)
    HideControls(AppearanceTabControls)
    HideControls(PromptsTabControls)
    HideControls(HotkeysTabControls)
    HideControls(AdvancedTabControls)
    HideControls(SearchTabControls)
    
    ; 隐藏所有快捷键子标签页内容（防止覆盖其他标签页）
    global HotkeySubTabControls
    if (HotkeySubTabControls) {
        for Key, Controls in HotkeySubTabControls {
            if (Controls && Controls.Length > 0) {
                for Index, Ctrl in Controls {
                    if (Ctrl) {
                        try {
                            Ctrl.Visible := false
                        } catch as err {
                            ; 忽略已销毁的控件
                        }
                    }
                }
            }
        }
    }
    
    ; 隐藏所有Cursor规则子标签页内容（防止覆盖其他标签页）
    global CursorRulesSubTabControls, HotkeysMainTabControls
    if (CursorRulesSubTabControls) {
        for Key, Controls in CursorRulesSubTabControls {
            if (Controls && Controls.Length > 0) {
                for Index, Ctrl in Controls {
                    if (Ctrl) {
                        try {
                            Ctrl.Visible := false
                        } catch as err {
                            ; 忽略已销毁的控件
                        }
                    }
                }
            }
        }
    }
    
    ; 隐藏所有主标签页内容（快捷键设置和Cursor规则）
    if (HotkeysMainTabControls) {
        for Key, Controls in HotkeysMainTabControls {
            if (Controls && Controls.Length > 0) {
                for Index, Ctrl in Controls {
                    if (Ctrl) {
                        try {
                            Ctrl.Visible := false
                        } catch as err {
                            ; 忽略已销毁的控件
                        }
                    }
                }
            }
        }
    }
    
    ; 隐藏所有通用子标签页内容（防止覆盖其他标签页）
    global GeneralSubTabControls
    if (GeneralSubTabControls) {
        for Key, Controls in GeneralSubTabControls {
            if (Controls && Controls.Length > 0) {
                for Index, Ctrl in Controls {
                    if (Ctrl) {
                        try {
                            Ctrl.Visible := false
                        } catch as err {
                            ; 忽略已销毁的控件
                        }
                    }
                }
            }
        }
    }
    
    ; 显示当前标签页内容
    switch TabName {
        case "general":
            ShowControls(GeneralTabControls)
        case "appearance":
            ShowControls(AppearanceTabControls)
        case "prompts":
            ; 【架构修复】正确的切换逻辑：
            ; 问题根源：PromptsTabControls包含了所有控件（公共控件+三个子标签页的所有控件）
            ; 当ShowControls(PromptsTabControls)时，所有控件都会显示，导致重叠
            
            ; 解决方案：分步骤精确控制
            ; 1. 先隐藏所有子标签页的控件（确保干净状态）
            ; 2. 显示公共控件（面板、标题、主标签栏）
            ; 3. 切换到模板管理标签页（会自动显示对应的控件）
            
            ; 第一步：强制隐藏所有子标签页的控件（确保干净状态）
            global PromptsMainTabControls, CursorRulesSubTabControls, PromptCategoryTabControls
            
            ; 隐藏所有主标签页的内容控件（但不包括主标签按钮，它们应该始终可见）
            if (PromptsMainTabControls) {
                for Key, Controls in PromptsMainTabControls {
                    if (Controls && Controls.Length > 0) {
                        for Index, Ctrl in Controls {
                            if (Ctrl) {
                                try {
                                    ; 通过控件名称判断是否是主标签按钮（应该始终可见）
                                    CtrlName := ""
                                    try {
                                        CtrlName := Ctrl.Name
                                    } catch as err {
                                    }
                                    ; 如果不是主标签按钮，则隐藏
                                    if (InStr(CtrlName, "PromptsMainTab") = 0) {
                                        Ctrl.Visible := false
                                    }
                                } catch as err {
                                }
                            }
                        }
                    }
                }
            }
            
            ; 隐藏所有Cursor规则子标签页内容
            if (IsSet(CursorRulesSubTabControls) && IsObject(CursorRulesSubTabControls)) {
                for SubTabKey, Controls in CursorRulesSubTabControls {
                    if (Controls && Controls.Length > 0) {
                        for Index, Ctrl in Controls {
                            if (Ctrl) {
                                try {
                                    Ctrl.Visible := false
                                } catch as err {
                                }
                            }
                        }
                    }
                }
            }
            
            ; 隐藏所有分类标签页内容
            if (IsSet(PromptCategoryTabControls) && IsObject(PromptCategoryTabControls)) {
                for CategoryName, Controls in PromptCategoryTabControls {
                    if (Controls && Controls.Length > 0) {
                        for Index, Ctrl in Controls {
                            if (Ctrl) {
                                try {
                                    Ctrl.Visible := false
                                } catch as err {
                                }
                            }
                        }
                    }
                }
            }
            
            ; 第二步：显示公共控件（面板、标题、主标签栏背景和按钮）
            ; 通过GuiID_ConfigGUI直接访问公共控件，避免使用PromptsTabControls（因为它包含子标签页控件）
            global GuiID_ConfigGUI, PromptsTabPanel, PromptsMainTabs
            if (GuiID_ConfigGUI) {
                try {
                    ; 显示面板
                    if (PromptsTabPanel) {
                        PromptsTabPanel.Visible := true
                    } else {
                        ; 如果全局变量不存在，尝试通过名称获取
                        PromptsTabPanel := GuiID_ConfigGUI["PromptsTabPanel"]
                        if (PromptsTabPanel) {
                            PromptsTabPanel.Visible := true
                        }
                    }
                    ; 显示主标签按钮（它们应该始终可见）
                    if (PromptsMainTabs) {
                        for Key, TabBtn in PromptsMainTabs {
                            if (TabBtn) {
                                try {
                                    TabBtn.Visible := true
                                } catch as err {
                                }
                            }
                        }
                    }
                } catch as err {
                }
            }
            
            ; 第三步：确保所有主标签按钮都可见（包括rules和legacy标签按钮）
            if (PromptsMainTabs && PromptsMainTabs.Count > 0) {
                for Key, TabBtn in PromptsMainTabs {
                    if (TabBtn) {
                        try {
                            TabBtn.Visible := true
                        } catch as err {
                        }
                    }
                }
            }
            
            ; 第四步：切换到模板管理标签页（这会显示对应的控件并隐藏其他标签页的控件）
            if (PromptsMainTabs && PromptsMainTabs.Has("manage")) {
                SwitchPromptsMainTab("manage")
            } else {
                ; 如果PromptsMainTabs还未初始化，延迟切换
                SetTimer(SwitchToManageTab, -100)
            }
        case "hotkeys":
            ; 先隐藏所有主标签页内容，确保干净状态（在显示HotkeysTabControls之前）
            global HotkeysMainTabControls
            if (HotkeysMainTabControls) {
                for Key, Controls in HotkeysMainTabControls {
                    if (Controls && Controls.Length > 0) {
                        for Index, Ctrl in Controls {
                            if (Ctrl) {
                                try {
                                    Ctrl.Visible := false
                                } catch as err {
                                }
                            }
                        }
                    }
                }
            }
            ; 显示快捷键标签页的公共控件（主标签按钮等）
            ; 【架构修复】HotkeysTabControls 现在只包含真正的公共控件（主标签按钮、标题、面板背景等）
            ; TabBarBg 和快捷键子标签按钮已从 HotkeysTabControls 中移除，只属于 HotkeysMainTabControls["settings"]
            ShowControls(HotkeysTabControls)
            ; 显示第一个主标签页（快捷操作按钮）
            global HotkeysMainTabs
            if (HotkeysMainTabs && HotkeysMainTabs.Has("quickaction")) {
                SwitchHotkeysMainTab("quickaction")
            } else {
                ; 如果HotkeysMainTabs还未初始化，延迟切换
                SetTimer(SwitchToQuickActionTab, -100)
            }
        case "advanced":
            ShowControls(AdvancedTabControls)
        case "search":
            ; 【Bug修复1】先准备数据，再显示控件，减少闪烁
            global SearchHistoryEdit, SearchResultsCache, SearchCurrentFilterType
            if (SearchHistoryEdit && SearchHistoryEdit.Value != "") {
                ; 如果已有缓存，先刷新数据（此时控件还隐藏，不会闪烁）
                if (IsSet(SearchResultsCache) && SearchResultsCache.Count > 0) {
                    ; 先填充数据（控件隐藏时）
                    RefreshSearchResultsListView(SearchResultsCache, SearchCurrentFilterType)
                } else {
                    ; 否则执行搜索（先获取数据）
                    PerformSearch()
                }
            }
            ; 数据准备完成后再显示控件
            ShowControls(SearchTabControls)
    }
    
    CurrentTab := TabName
}

; ===================== 创建通用标签页 =====================
CreateGeneralTab(ConfigGUI, X, Y, W, H) {
    global CursorPath, Language, GeneralTabPanel, CursorPathEdit, LangChinese, LangEnglish, BtnBrowse, GeneralTabControls
    global UI_Colors
    
    ; 创建标签页面板（默认显示，因为是第一个标签）
    GeneralTabPanel := ConfigGUI.Add("Text", "x" . X . " y" . Y . " w" . W . " h" . H . " Background" . UI_Colors.Background . " vGeneralTabPanel", "")
    GeneralTabPanel.Visible := true  ; 通用标签页默认显示
    GeneralTabControls.Push(GeneralTabPanel)
    
    ; 标题
    Title := ConfigGUI.Add("Text", "x" . (X + 30) . " y" . (Y + 20) . " w" . (W - 60) . " h30 c" . UI_Colors.Text, GetText("general_settings"))
    Title.SetFont("s16 Bold", "Segoe UI")
    GeneralTabControls.Push(Title)
    
    ; Cursor 路径设置
    YPos := Y + 70
    Label1 := ConfigGUI.Add("Text", "x" . (X + 30) . " y" . YPos . " w200 h25 c" . UI_Colors.Text, GetText("cursor_path"))
    Label1.SetFont("s11", "Segoe UI")
    GeneralTabControls.Push(Label1)
    
    YPos += 30
    ; 根据主题模式设置输入框颜色（暗色模式使用cursor黑灰色系）
    global ThemeMode
    if (!IsSet(ThemeMode) || ThemeMode = "") {
        ThemeMode := "dark"
    }
    if (ThemeMode = "dark") {
        InputBgColor := UI_Colors.InputBg  ; html.to.design 风格背景
        InputTextColor := UI_Colors.Text   ; html.to.design 风格文本
    } else {
        InputBgColor := UI_Colors.InputBg
        InputTextColor := UI_Colors.Text
    }
    CursorPathEdit := ConfigGUI.Add("Edit", "x" . (X + 30) . " y" . YPos . " w" . (W - 150) . " h30 vCursorPathEdit Background" . InputBgColor . " c" . InputTextColor, CursorPath)
    CursorPathEdit.SetFont("s11", "Segoe UI")
    GeneralTabControls.Push(CursorPathEdit)
    
    ; 浏览按钮 (自定义样式)
    BtnBrowse := ConfigGUI.Add("Text", "x" . (X + W - 110) . " y" . YPos . " w80 h30 Center 0x200 cWhite Background" . UI_Colors.BtnBg . " vBtnBrowse", GetText("browse"))
    BtnBrowse.SetFont("s10", "Segoe UI")
    BtnBrowse.OnEvent("Click", BrowseCursorPath)
    HoverBtn(BtnBrowse, UI_Colors.BtnBg, UI_Colors.BtnHover)
    GeneralTabControls.Push(BtnBrowse)
    
    YPos += 40
    Hint1 := ConfigGUI.Add("Text", "x" . (X + 30) . " y" . YPos . " w" . (W - 60) . " h20 c" . UI_Colors.TextDim, GetText("cursor_path_hint"))
    Hint1.SetFont("s9", "Segoe UI")
    GeneralTabControls.Push(Hint1)
    
    ; CapsLock长按时间设置（移除语言设置，已移到高级标签页）
    YPos += 40  ; 缩小间距（从50px改为40px）
    global CapsLockHoldTimeSeconds, CapsLockHoldTimeEdit
    LabelCapsLockHoldTime := ConfigGUI.Add("Text", "x" . (X + 30) . " y" . YPos . " w200 h25 c" . UI_Colors.Text, GetText("capslock_hold_time"))
    LabelCapsLockHoldTime.SetFont("s11", "Segoe UI")
    GeneralTabControls.Push(LabelCapsLockHoldTime)
    
    YPos += 30
    ; 使用之前定义的InputBgColor和InputTextColor（如果已定义）
    if (!IsSet(InputBgColor) || !IsSet(InputTextColor)) {
        if (ThemeMode = "dark") {
            InputBgColor := UI_Colors.InputBg  ; html.to.design 风格背景
            InputTextColor := UI_Colors.Text    ; html.to.design 风格文本
        } else {
            InputBgColor := UI_Colors.InputBg
            InputTextColor := UI_Colors.Text
        }
    }
    CapsLockHoldTimeEdit := ConfigGUI.Add("Edit", "x" . (X + 30) . " y" . YPos . " w150 h30 vCapsLockHoldTimeEdit Background" . InputBgColor . " c" . InputTextColor, CapsLockHoldTimeSeconds)
    CapsLockHoldTimeEdit.SetFont("s11", "Segoe UI")
    GeneralTabControls.Push(CapsLockHoldTimeEdit)
    
    YPos += 35
    HintCapsLockHoldTime := ConfigGUI.Add("Text", "x" . (X + 30) . " y" . YPos . " w" . (W - 60) . " h20 c" . UI_Colors.TextDim, GetText("capslock_hold_time_hint"))
    HintCapsLockHoldTime.SetFont("s9", "Segoe UI")
    GeneralTabControls.Push(HintCapsLockHoldTime)
    
    ; 自启动设置（从高级设置移到这里）
    YPos += 60
    LabelAutoStart := ConfigGUI.Add("Text", "x" . (X + 30) . " y" . YPos . " w200 h25 c" . UI_Colors.Text, GetText("auto_start"))
    LabelAutoStart.SetFont("s11", "Segoe UI")
    GeneralTabControls.Push(LabelAutoStart)
    
    YPos += 30
    ; 创建自启动切换按钮（蓝色=开启，灰色=关闭）
    global AutoStartBtn
    BtnWidth := 200
    BtnHeight := 35
    BtnText := AutoStart ? "开机自启动" : "不开机自启动"
    BtnBgColor := AutoStart ? UI_Colors.BtnPrimary : UI_Colors.BtnBg
    BtnTextColor := AutoStart ? UI_Colors.Text : ((ThemeMode = "light") ? UI_Colors.Text : UI_Colors.Text)  ; html.to.design 风格文本
    
    AutoStartBtn := ConfigGUI.Add("Text", "x" . (X + 30) . " y" . YPos . " w" . BtnWidth . " h" . BtnHeight . " Center 0x200 c" . BtnTextColor . " Background" . BtnBgColor . " vAutoStartBtn", BtnText)
    AutoStartBtn.SetFont("s10", "Segoe UI")
    AutoStartBtn.OnEvent("Click", (*) => ToggleAutoStart())
    HoverBtnWithAnimation(AutoStartBtn, BtnBgColor, AutoStart ? UI_Colors.BtnPrimaryHover : UI_Colors.BtnHover)
    GeneralTabControls.Push(AutoStartBtn)
    
    ; 默认启动页面设置（从高级设置移到这里）
    YPos += 60
    LabelDefaultStartTab := ConfigGUI.Add("Text", "x" . (X + 30) . " y" . YPos . " w200 h25 c" . UI_Colors.Text, "默认启动页面：")
    LabelDefaultStartTab.SetFont("s11", "Segoe UI")
    GeneralTabControls.Push(LabelDefaultStartTab)
    
    YPos += 30
    global DefaultStartTab, DefaultStartTabDDL
    ; 创建下拉框，让用户选择默认启动页面
    StartTabOptions := ["通用", "外观", "提示词", "快捷键", "高级"]
    StartTabValues := ["general", "appearance", "prompts", "hotkeys", "advanced"]
    
    ; 找到当前选择的索引
    DefaultIndex := 1
    for Index, Value in StartTabValues {
        if (Value = DefaultStartTab) {
            DefaultIndex := Index
            break
        }
    }
    
    ; 创建下拉框
    ; 根据主题模式设置下拉框颜色（暗色模式使用cursor黑灰色系）
    if (!IsSet(ThemeMode) || ThemeMode = "") {
        ThemeMode := "dark"
    }
    if (ThemeMode = "dark") {
        DDLBgColor := UI_Colors.DDLBg    ; html.to.design 风格背景
        DDLTextColor := UI_Colors.DDLText ; html.to.design 风格文本
    } else {
        DDLBgColor := UI_Colors.DDLBg
        DDLTextColor := UI_Colors.DDLText
    }
    ; 使用R5选项指定下拉列表显示5行（R选项设置下拉列表的高度）
    DefaultStartTabDDL := ConfigGUI.Add("DDL", "x" . (X + 30) . " y" . YPos . " w200 h30 R5 vDefaultStartTabDDL Background" . DDLBgColor . " c" . DDLTextColor, StartTabOptions)
    DefaultStartTabDDL.SetFont("s10 c" . DDLTextColor, "Segoe UI")
    DefaultStartTabDDL.Value := DefaultIndex
    DefaultStartTabDDL.OnEvent("Change", (*) => OnDefaultStartTabChange())
    
    ; 保存下拉框句柄，用于在窗口显示后设置最小可见项数
    ; CB_SETMINVISIBLE需要在窗口完全创建并显示后才能生效
    try {
        DDL_Hwnd := DefaultStartTabDDL.Hwnd
        ; 保存句柄到全局变量，供窗口显示后的延迟函数使用
        global DefaultStartTabDDL_Hwnd_ForTimer
        DefaultStartTabDDL_Hwnd_ForTimer := DDL_Hwnd
    } catch as err {
        ; 如果获取句柄失败，忽略错误
    }
    
    ; 设置下拉框的背景色
    ; 使用DDLBg颜色来匹配Cursor主题色
    try {
        DefaultStartTabDDL.Opt("Background" . UI_Colors.DDLBg)
        ; 保存下拉框的句柄，用于消息处理
        global DefaultStartTabDDL_Hwnd, ThemeMode
        DefaultStartTabDDL_Hwnd := DDL_Hwnd
        
        ; 创建画刷用于下拉列表背景色（根据主题模式设置）
        ; 在窗口显示后设置下拉列表的背景色
        SetTimer(UpdateDefaultStartTabDDLBrush, -300)
    } catch as err {
        ; 如果设置失败，忽略错误
    }
    GeneralTabControls.Push(DefaultStartTabDDL)
    
    ; 安装 Cursor 中文版按钮（从高级设置移到这里）
    YPos += 60
    LabelInstallChinese := ConfigGUI.Add("Text", "x" . (X + 30) . " y" . YPos . " w200 h25 c" . UI_Colors.Text, GetText("install_cursor_chinese"))
    LabelInstallChinese.SetFont("s11", "Segoe UI")
    GeneralTabControls.Push(LabelInstallChinese)
    
    YPos += 30
    TextColor := (ThemeMode = "light") ? UI_Colors.Text : UI_Colors.Text  ; html.to.design 风格文本
    InstallChineseBtn := ConfigGUI.Add("Text", "x" . (X + 30) . " y" . YPos . " w" . (BtnWidth * 2 + 10) . " h" . BtnHeight . " Center 0x200 c" . TextColor . " Background" . UI_Colors.BtnBg . " vGeneralInstallChineseBtn", GetText("install_cursor_chinese"))
    InstallChineseBtn.SetFont("s10", "Segoe UI")
    InstallChineseBtn.OnEvent("Click", InstallCursorChinese)
    HoverBtnWithAnimation(InstallChineseBtn, UI_Colors.BtnBg, UI_Colors.BtnHover)
    GeneralTabControls.Push(InstallChineseBtn)
    
    YPos += 40
    HintInstallChinese := ConfigGUI.Add("Text", "x" . (X + 30) . " y" . YPos . " w" . (W - 60) . " h40 c" . UI_Colors.TextDim, GetText("install_cursor_chinese_desc"))
    HintInstallChinese.SetFont("s9", "Segoe UI")
    GeneralTabControls.Push(HintInstallChinese)
}

; ===================== 创建快捷操作按钮配置UI =====================
CreateQuickActionConfigUI(ConfigGUI, X, Y, W, ParentControls) {
    global QuickActionButtons, QuickActionConfigControls, UI_Colors, ThemeMode
    
    ; 清空之前的控件
    for Index, Ctrl in QuickActionConfigControls {
        try {
            Ctrl.Destroy()
        } catch as err {
            ; 忽略已销毁的控件
        }
    }
    QuickActionConfigControls := []
    
    ; 确保有5个按钮
    while (QuickActionButtons.Length < 5) {
        QuickActionButtons.Push({Type: "Explain", Hotkey: "e"})
    }
    while (QuickActionButtons.Length > 5) {
        QuickActionButtons.Pop()
    }
    
    ; 功能类型选项（用于单选按钮）- 包括所有快捷键设置
    ActionTypes := [
        {Type: "Explain", Name: GetText("quick_action_type_explain"), Hotkey: "e", Desc: GetText("hotkey_e_desc")},
        {Type: "Refactor", Name: GetText("quick_action_type_refactor"), Hotkey: "r", Desc: GetText("hotkey_r_desc")},
        {Type: "Optimize", Name: GetText("quick_action_type_optimize"), Hotkey: "o", Desc: GetText("hotkey_o_desc")},
        {Type: "Config", Name: GetText("quick_action_type_config"), Hotkey: "q", Desc: GetText("hotkey_q_desc")},
        {Type: "Copy", Name: GetText("quick_action_type_copy"), Hotkey: "c", Desc: GetText("hotkey_c_desc")},
        {Type: "Paste", Name: GetText("quick_action_type_paste"), Hotkey: "v", Desc: GetText("hotkey_v_desc")},
        {Type: "Clipboard", Name: GetText("quick_action_type_clipboard"), Hotkey: "x", Desc: GetText("hotkey_x_desc")},
        {Type: "Voice", Name: GetText("quick_action_type_voice"), Hotkey: "z", Desc: GetText("hotkey_z_desc")},
        {Type: "Split", Name: GetText("quick_action_type_split"), Hotkey: "s", Desc: GetText("hotkey_s_desc")},
        {Type: "Batch", Name: GetText("quick_action_type_batch"), Hotkey: "b", Desc: GetText("hotkey_b_desc")},
        {Type: "CommandPalette", Name: GetText("quick_action_type_command_palette"), Hotkey: "", Desc: GetText("quick_action_desc_command_palette")},
        {Type: "Terminal", Name: GetText("quick_action_type_terminal"), Hotkey: "", Desc: GetText("quick_action_desc_terminal")},
        {Type: "GlobalSearch", Name: GetText("quick_action_type_global_search"), Hotkey: "", Desc: GetText("quick_action_desc_global_search")},
        {Type: "Explorer", Name: GetText("quick_action_type_explorer"), Hotkey: "", Desc: GetText("quick_action_desc_explorer")},
        {Type: "SourceControl", Name: GetText("quick_action_type_source_control"), Hotkey: "", Desc: GetText("quick_action_desc_source_control")},
        {Type: "Extensions", Name: GetText("quick_action_type_extensions"), Hotkey: "", Desc: GetText("quick_action_desc_extensions")},
        {Type: "Browser", Name: GetText("quick_action_type_browser"), Hotkey: "", Desc: GetText("quick_action_desc_browser")},
        {Type: "Settings", Name: GetText("quick_action_type_settings"), Hotkey: "", Desc: GetText("quick_action_desc_settings")},
        {Type: "CursorSettings", Name: GetText("quick_action_type_cursor_settings"), Hotkey: "", Desc: GetText("quick_action_desc_cursor_settings")}
    ]
    
    ; 按钮配置列表（Cursor风格：简洁现代）
    ButtonY := Y
    Loop 5 {
        Index := A_Index
        Button := QuickActionButtons[Index]
        
        ; 左侧序号区域
        BtnNum := ConfigGUI.Add("Text", "x" . X . " y" . (ButtonY + 12) . " w50 h28 c" . UI_Colors.TextDim . " Background" . UI_Colors.Background, FormatText("quick_action_button", Index))
        BtnNum.SetFont("s10", "Segoe UI")
        QuickActionConfigControls.Push(BtnNum)
        
        ; 功能类型单选按钮组
        RadioX := X + 60
        RadioY := ButtonY + 12
        ; 调整间距：19个选项，两行排列，每行约10个，缩小间距以适应
        RadioSpacing := 95  ; 单选按钮之间的间距（增加以确保文字完整显示）
        RadioButtonWidth := 90  ; 单选按钮宽度（增加以确保文字完整显示）
        
        ; 说明文字（去掉快捷键输入框，直接显示说明）
        DescX := RadioX
        ; 单选按钮区域：两行，每行高度28px，行间距35px
        ; 第一行按钮：RadioY 到 RadioY + 28
        ; 第二行按钮：RadioY + 28 + 35 = RadioY + 63 到 RadioY + 63 + 28 = RadioY + 91
        ; 说明文字距离按钮的距离再缩小1倍（从3px缩小到1.5px，取整为2px）
        DescY := RadioY + 91 + 2  ; 调整位置：第二行按钮底部 + 2px间距（靠拢但不遮盖）
        DescW := W - (DescX - X) - 10
        DescH := 40  ; 增加高度，确保多行文字能完整显示
        
        BtnType := ""
        if (Button is Map)
            BtnType := Button.Get("Type", "")
        else if (IsObject(Button) && Button.HasProp("Type"))
            BtnType := Button.Type

        ; 获取当前选中类型的说明
        CurrentDesc := ""
        for TypeIndex, ActionType in ActionTypes {
            if (BtnType = ActionType.Type) {
                CurrentDesc := ActionType.Desc
                break
            }
        }
        
        ; 创建浅灰色圆角背景（使用两个Text控件叠加实现圆角效果）
        ; 浅灰色背景色（根据主题调整）
        DescBgColor := (ThemeMode = "light") ? "E8E8E8" : "3A3A3A"
        DescBgPadding := 4  ; 背景内边距（缩小一半：从8px改为4px）
        DescBgX := DescX - DescBgPadding
        DescBgY := DescY - DescBgPadding
        DescBgW := DescW + DescBgPadding * 2
        DescBgH := DescH + DescBgPadding * 2
        
        ; 背景层（圆角通过设置样式实现，这里先用矩形背景）
        DescBg := ConfigGUI.Add("Text", "x" . DescBgX . " y" . DescBgY . " w" . DescBgW . " h" . DescBgH . " Background" . DescBgColor . " +0x200", "")
        QuickActionConfigControls.Push(DescBg)
        
        ; 说明文字（在背景上方）
        DescText := ConfigGUI.Add("Text", "x" . DescX . " y" . DescY . " w" . DescW . " h" . DescH . " vQuickActionDesc" . Index . " c" . UI_Colors.Text . " BackgroundTrans +0x200", CurrentDesc)  ; +0x200 = SS_LEFTNOWORDWRAP，BackgroundTrans 使背景透明，显示下层背景
        DescText.SetFont("s8 Bold", "Segoe UI")  ; 缩小文字（从s9改为s8），加粗加黑
        QuickActionConfigControls.Push(DescText)
        
        ; 创建单选按钮组（在说明文字创建之后，以便绑定事件）
        ; 使用相同的变量名确保互斥（AutoHotkey v2的Radio控件默认互斥）
        RadioGroupName := "QuickActionType" . Index
        SelectedTypeIndex := 1
        
        ; 先确定当前选中的类型索引
        for TypeIndex, ActionType in ActionTypes {
            if (BtnType = ActionType.Type) {
                SelectedTypeIndex := TypeIndex
                break
            }
        }
        
        ; 单选按钮分两行显示（每行约10个，共19个选项）
        RadioControls := []  ; 存储所有单选按钮，用于设置选中状态
        ButtonsPerRow := 10  ; 每行按钮数量
        for TypeIndex, ActionType in ActionTypes {
            ; 计算行和列（两行布局）
            Row := Floor((TypeIndex - 1) / ButtonsPerRow)
            Col := Mod((TypeIndex - 1), ButtonsPerRow)
            RadioXPos := RadioX + Col * RadioSpacing
            RadioYPos := RadioY + Row * 35  ; 行间距35px（按钮高度28px + 7px间距）
            
            ; 保存当前ActionType的值到局部变量，确保闭包中能正确访问
            CurrentActionTypeDesc := ActionType.Desc
            CurrentTypeIndex := TypeIndex
            
            ; 由于单选按钮在循环中创建且位置不连续，无法使用自动互斥功能
            ; 改为手动管理互斥：每个按钮使用唯一的变量名，在点击事件中手动取消其他按钮的选中状态
            RadioCtrlName := RadioGroupName . "_" . TypeIndex
            ; 使用 Material 风格的单选按钮（不自动绑定默认点击事件，使用自定义事件）
            RadioCtrl := CreateMaterialRadioButton(ConfigGUI, RadioXPos, RadioYPos, RadioButtonWidth, 28, RadioCtrlName, ActionType.Name, RadioControls, 9, false)
            
            ; 添加事件处理：当单选按钮改变时，更新说明文字并手动管理互斥
            ; 为每个单选按钮创建独立的事件处理器，确保点击时能正确更新说明和互斥状态
            ; 使用局部变量确保闭包中能正确访问值
            RadioCtrl.OnEvent("Click", CreateRadioClickHandler(Index, CurrentActionTypeDesc, CurrentTypeIndex, RadioControls))
            
            RadioControls.Push(RadioCtrl)
            QuickActionConfigControls.Push(RadioCtrl)
        }
        
        ; 设置选中状态（Material 风格）
        ; 确保至少有一个按钮被选中（默认选择第一个）
        if (SelectedTypeIndex >= 1 && SelectedTypeIndex <= RadioControls.Length) {
            RadioControls[SelectedTypeIndex].IsSelected := true
            UpdateMaterialRadioButtonStyle(RadioControls[SelectedTypeIndex], true)
        } else if (RadioControls.Length > 0) {
            ; 如果没有匹配的，默认选择第一个
            RadioControls[1].IsSelected := true
            UpdateMaterialRadioButtonStyle(RadioControls[1], true)
        }
        
        ; 说明文字已在创建DescText时设置，无需重复初始化
        
        ; 去掉底部分隔线，使用更简洁的 Material 风格
        
        ; 计算每个按钮区域的总高度：
        ; 单选按钮区域：两行，每行28px高度，行间距35px，总高度 = 28 + 35 + 28 = 91px
        ; 说明文字区域：30px高度 + 背景内边距8px（上下各4px）= 38px（缩小后）
        ; 间距：单选按钮到说明文字3px（缩小后），说明文字到下一个按钮区域5px（缩小后）
        ; 总高度 = 91 + 2 + 38 + 5 = 136px（再缩小1倍后，从137px缩小到136px）
        ButtonY += 136  ; 增加高度以适应两行单选按钮和说明文字，确保不遮挡
    }
    
    ; 将控件添加到父控件列表
    for Index, Ctrl in QuickActionConfigControls {
        ParentControls.Push(Ctrl)
    }
}

; ===================== 创建通用子标签页 =====================
CreateGeneralSubTab(ConfigGUI, X, Y, W, H, Item) {
    global GeneralTabControls, GeneralSubTabControls, UI_Colors
    
    ; 初始化子标签页控件数组
    if (!GeneralSubTabControls.Has(Item.Key)) {
        GeneralSubTabControls[Item.Key] := []
    }
    
    ; 创建子标签页面板（默认隐藏，作为背景）
    SubTabPanel := ConfigGUI.Add("Text", "x" . X . " y" . Y . " w" . W . " h" . H . " Background" . UI_Colors.Background . " vGeneralSubTab" . Item.Key . "Panel", "")
    SubTabPanel.Visible := false
    GeneralSubTabControls[Item.Key].Push(SubTabPanel)
    
    ; 根据子标签类型创建不同的内容
    switch Item.Key {
        case "quickaction":
            ; 快捷操作按钮
            YPos := Y + 10  ; 缩小间距（从20px改为10px）
            QuickActionDesc := ConfigGUI.Add("Text", "x" . X . " y" . YPos . " w" . W . " h20 c" . UI_Colors.TextDim, GetText("quick_action_config_desc"))
            QuickActionDesc.SetFont("s9", "Segoe UI")
            GeneralSubTabControls[Item.Key].Push(QuickActionDesc)
            
            YPos += 25  ; 缩小间距（从30px改为25px）
            global QuickActionConfigControls := []
            CreateQuickActionConfigUI(ConfigGUI, X, YPos, W, GeneralSubTabControls[Item.Key])
            
        case "searchcategory":
            ; 搜索标签
            YPos := Y + 20
            SearchCategoryDesc := ConfigGUI.Add("Text", "x" . X . " y" . YPos . " w" . W . " h20 c" . UI_Colors.TextDim, GetText("search_category_config_desc"))
            SearchCategoryDesc.SetFont("s9", "Segoe UI")
            GeneralSubTabControls[Item.Key].Push(SearchCategoryDesc)
            
            YPos += 30
            global SearchCategoryConfigControls := []
            CreateSearchCategoryConfigUI(ConfigGUI, X, YPos, W, GeneralSubTabControls[Item.Key])
    }
}

; ===================== 切换通用子标签页 =====================
SwitchGeneralSubTab(SubTabKey) {
    global GeneralSubTabs, GeneralSubTabControls, UI_Colors
    
    ; 重置所有子标签样式
    for Key, TabBtn in GeneralSubTabs {
        if (TabBtn) {
            try {
                TabBtn.Opt("+Background" . UI_Colors.Sidebar)
                TabBtn.SetFont("s9 c" . UI_Colors.TextDim . " Norm", "Segoe UI")
                TabBtn.Redraw()
            }
        }
    }
    
    ; 隐藏所有子标签页内容
    for Key, Controls in GeneralSubTabControls {
        if (Controls && Controls.Length > 0) {
            for Index, Ctrl in Controls {
                if (Ctrl) {
                    try {
                        Ctrl.Visible := false
                    } catch as err {
                        ; 忽略已销毁的控件
                    }
                }
            }
        }
    }
    
    ; 设置当前子标签样式
    if (GeneralSubTabs.Has(SubTabKey) && GeneralSubTabs[SubTabKey]) {
        try {
            TabBtn := GeneralSubTabs[SubTabKey]
            ; 选中状态：蓝色背景 (0078D4)，高亮文字
            SelectedText := (ThemeMode = "dark") ? UI_Colors.Text : "FFFFFF"  ; html.to.design 风格文本（亮色模式保持白色）
            TabBtn.Opt("+Background" . UI_Colors.BtnPrimary)
            TabBtn.SetFont("s9 c" . SelectedText . " Bold", "Segoe UI")
            TabBtn.Redraw()
        }
    }
    
    ; 显示当前子标签页内容
    if (GeneralSubTabControls.Has(SubTabKey)) {
        Controls := GeneralSubTabControls[SubTabKey]
        if (Controls && Controls.Length > 0) {
            for Index, Ctrl in Controls {
                if (Ctrl) {
                    try {
                        Ctrl.Visible := true
                    } catch as err {
                        ; 忽略已销毁的控件
                    }
                }
            }
        }
    }
}

; ===================== 创建搜索标签配置UI =====================
CreateSearchCategoryConfigUI(ConfigGUI, X, Y, W, ParentControls) {
    global VoiceSearchEnabledCategories, SearchCategoryConfigControls, UI_Colors
    
    ; 清空之前的控件
    if (IsSet(SearchCategoryConfigControls)) {
        for Index, Ctrl in SearchCategoryConfigControls {
            try {
                Ctrl.Destroy()
            } catch as err {
                ; 忽略已销毁的控件
            }
        }
    }
    SearchCategoryConfigControls := []
    
    ; 所有可用的标签
    AllCategories := [
        {Key: "ai", Text: GetText("search_category_ai")},
        {Key: "cli", Text: GetText("search_category_cli")},
        {Key: "academic", Text: GetText("search_category_academic")},
        {Key: "baidu", Text: GetText("search_category_baidu")},
        {Key: "image", Text: GetText("search_category_image")},
        {Key: "audio", Text: GetText("search_category_audio")},
        {Key: "video", Text: GetText("search_category_video")},
        {Key: "book", Text: GetText("search_category_book")},
        {Key: "price", Text: GetText("search_category_price")},
        {Key: "medical", Text: GetText("search_category_medical")},
        {Key: "cloud", Text: GetText("search_category_cloud")}
    ]
    
    ; 确保 VoiceSearchEnabledCategories 已初始化
    if (!IsSet(VoiceSearchEnabledCategories) || !IsObject(VoiceSearchEnabledCategories)) {
        global VoiceSearchEnabledCategories := ["ai", "cli", "academic", "baidu", "image", "audio", "video", "book", "price", "medical", "cloud"]
    }
    
    ; 创建复选框（每行2个，参考单选按钮尺寸）
    CheckboxY := Y
    CheckboxWidth := 100  ; 参考单选按钮宽度
    CheckboxHeight := 30  ; 参考单选按钮高度
    CheckboxSpacing := 10
    
    for Index, Category in AllCategories {
        ; 计算位置
        Row := Floor((Index - 1) / 2)
        Col := Mod((Index - 1), 2)
        CheckboxX := X + Col * (CheckboxWidth + 30)
        CurrentY := CheckboxY + Row * (CheckboxHeight + CheckboxSpacing)
        
        ; 检查是否启用
        IsEnabled := (ArrayContainsValue(VoiceSearchEnabledCategories, Category.Key) > 0)
        
        ; 创建 Material 风格的复选框
        Checkbox := CreateMaterialCheckbox(ConfigGUI, CheckboxX, CurrentY, CheckboxWidth, CheckboxHeight, "SearchCategoryCheckbox" . Category.Key, Category.Text, 10)
        Checkbox.IsChecked := IsEnabled
        UpdateMaterialCheckboxStyle(Checkbox, IsEnabled)
        Checkbox.OnEvent("Click", CreateSearchCategoryCheckboxHandler(Category.Key))
        SearchCategoryConfigControls.Push(Checkbox)
        ParentControls.Push(Checkbox)  ; 将复选框添加到父控件列表，确保在标签页切换时正确显示/隐藏
    }
}

; ===================== 搜索标签复选框点击处理 =====================
CreateSearchCategoryCheckboxHandler(CategoryKey) {
    return (*) => ToggleSearchCategory(CategoryKey)
}

; ===================== 默认启动页面变更处理 =====================
OnDefaultStartTabChange(*) {
    ; 自动保存配置（延迟执行，避免频繁保存）
    SetTimer(AutoSaveConfig, -100)
}

ToggleAutoStart(*) {
    global AutoStart, AutoStartBtn, GuiID_ConfigGUI, UI_Colors, ThemeMode
    
    ; 切换自启动状态
    AutoStart := !AutoStart
    
    ; 更新按钮文本和样式（开启时蓝色，关闭时灰色）
    try {
        if (AutoStartBtn && IsObject(AutoStartBtn)) {
            BtnText := AutoStart ? "开机自启动" : "不开机自启动"
            BtnBgColor := AutoStart ? UI_Colors.BtnPrimary : UI_Colors.BtnBg
            BtnTextColor := AutoStart ? UI_Colors.Text : ((ThemeMode = "light") ? UI_Colors.Text : UI_Colors.Text)  ; html.to.design 风格文本
            
            AutoStartBtn.Text := BtnText
            ; 使用Opt方法更新背景色（更可靠）
            AutoStartBtn.Opt("+Background" . BtnBgColor)
            AutoStartBtn.SetFont("s10 c" . BtnTextColor, "Segoe UI")
            AutoStartBtn.Redraw()  ; 强制重绘按钮
            
            ; 更新悬停效果
            HoverBtnWithAnimation(AutoStartBtn, BtnBgColor, AutoStart ? UI_Colors.BtnPrimaryHover : UI_Colors.BtnHover)
        }
    } catch as err {
        ; 忽略错误
    }
    
    ; 自动保存配置
    SetTimer(AutoSaveConfig, -100)
}

ToggleSearchCategory(CategoryKey) {
    global VoiceSearchEnabledCategories, GuiID_ConfigGUI
    
    ; 确保数组已初始化
    if (!IsSet(VoiceSearchEnabledCategories) || !IsObject(VoiceSearchEnabledCategories)) {
        VoiceSearchEnabledCategories := []
    }
    
    ; 获取复选框状态
    try {
        Checkbox := GuiID_ConfigGUI["SearchCategoryCheckbox" . CategoryKey]
        if (Checkbox && IsObject(Checkbox)) {
            ; 切换选中状态
            if (Checkbox.HasProp("IsChecked")) {
                Checkbox.IsChecked := !Checkbox.IsChecked
                IsEnabled := Checkbox.IsChecked
            } else {
                ; 兼容旧代码
                IsEnabled := (Checkbox.Value = 1)
                Checkbox.IsChecked := IsEnabled
            }
            
            ; 更新启用列表
            FoundIndex := ArrayContainsValue(VoiceSearchEnabledCategories, CategoryKey)
            if (IsEnabled && FoundIndex = 0) {
                ; 启用：添加到列表
                VoiceSearchEnabledCategories.Push(CategoryKey)
            } else if (!IsEnabled && FoundIndex > 0) {
                ; 禁用：从列表移除
                VoiceSearchEnabledCategories.RemoveAt(FoundIndex)
            }
            
            ; 确保至少有一个标签启用
            if (VoiceSearchEnabledCategories.Length = 0) {
                VoiceSearchEnabledCategories.Push("ai")  ; 默认启用AI标签
                Checkbox.IsChecked := true
                UpdateMaterialCheckboxStyle(Checkbox, true)
            } else {
                ; 更新样式
                UpdateMaterialCheckboxStyle(Checkbox, IsEnabled)
            }
            
            ; 自动保存配置
            SetTimer(AutoSaveConfig, -100)
        }
    } catch as err {
        ; 忽略错误
    }
}

; ===================== 快捷操作类型改变处理 =====================
CreateQuickActionTypeChangeHandler(Index, Desc, TypeIndex) {
    return (*) => UpdateQuickActionDesc(Index, Desc, TypeIndex)
}

; ===================== 创建 Material 风格单选按钮 =====================
; 创建 Material Design 扁平化风格的单选按钮（使用 Button 控件模拟）
; AutoBindClick: 是否自动绑定默认点击事件（如果为 false，需要手动绑定自定义事件）
CreateMaterialRadioButton(GUI, X, Y, W, H, VarName, Text, RadioGroup, FontSize := 11, AutoBindClick := true) {
    global UI_Colors, ThemeMode
    
    ; 使用 Text 控件模拟按钮，因为 Text 控件在 v2 中能更可靠地设置背景色
    RadioBtn := GUI.Add("Text", "x" . X . " y" . Y . " w" . W . " h" . H . " v" . VarName . " Center +0x200", Text)
    RadioBtn.SetFont("s" . FontSize, "Segoe UI")
    
    ; 设置基础样式 (使用 Opt 设置背景色，BackColor 在 v2 Text 控件上有时不奏效)
    RadioBtn.Opt("+Background" . UI_Colors.Sidebar)
    RadioBtn.SetFont("s" . FontSize . " c" . UI_Colors.Text, "Segoe UI")
    
    ; 存储信息
    if (!RadioBtn.HasProp("RadioGroup")) {
        RadioBtn.DefineProp("RadioGroup", {Value: RadioGroup})
    }
    if (!RadioBtn.HasProp("IsSelected")) {
        RadioBtn.DefineProp("IsSelected", {Value: false})
    }
    if (!RadioBtn.HasProp("FontSize")) {
        RadioBtn.DefineProp("FontSize", {Value: FontSize})
    }
    
    ; 添加响应
    if (AutoBindClick) {
        RadioBtn.OnEvent("Click", MaterialRadioButtonClick)
    }
    
    return RadioBtn
}

; Material 单选按钮点击事件
MaterialRadioButtonClick(Ctrl, *) {
    global UI_Colors
    
    ; 获取按钮组
    RadioGroup := Ctrl.RadioGroup
    if (!RadioGroup || !RadioGroup.Length) {
        return
    }
    
    ; 取消同组其他按钮的选中状态
    for Index, Btn in RadioGroup {
        if (Btn != Ctrl) {
            Btn.IsSelected := false
            UpdateMaterialRadioButtonStyle(Btn, false)
        }
    }
    
    ; 设置当前按钮为选中状态
    Ctrl.IsSelected := true
    UpdateMaterialRadioButtonStyle(Ctrl, true)
    
    ; 自动保存配置
    SetTimer(AutoSaveConfig, -100)
}

; 注意：由于 AutoHotkey v2 的 Button 控件不支持 MouseMove 和 MouseLeave 事件
; 悬停效果暂时无法实现，但 Material 风格仍然通过选中/未选中状态的颜色差异来体现

; ===================== 创建 Material 风格复选框 =====================
; 创建 Material Design 扁平化风格的复选框（使用 Button 控件模拟）
CreateMaterialCheckbox(GUI, X, Y, W, H, VarName, Text, FontSize := 10) {
    global UI_Colors, ThemeMode
    
    ; 使用 Text 控件模拟
    CheckboxBtn := GUI.Add("Text", "x" . X . " y" . Y . " w" . W . " h" . H . " v" . VarName . " Center +0x200", Text)
    CheckboxBtn.SetFont("s" . FontSize, "Segoe UI")
    
    CheckboxBtn.Opt("+Background" . UI_Colors.Sidebar)
    CheckboxBtn.SetFont("s" . FontSize . " c" . UI_Colors.Text, "Segoe UI")
    
    if (!CheckboxBtn.HasProp("IsChecked")) {
        CheckboxBtn.DefineProp("IsChecked", {Value: false})
    }
    if (!CheckboxBtn.HasProp("FontSize")) {
        CheckboxBtn.DefineProp("FontSize", {Value: FontSize})
    }
    
    return CheckboxBtn
}

; 更新 Material 复选框样式
UpdateMaterialCheckboxStyle(Ctrl, IsChecked) {
    global UI_Colors, ThemeMode
    
    FontSize := Ctrl.HasProp("FontSize") ? Ctrl.FontSize : 10
    
    if (IsChecked) {
        ; 选中状态：使用图片中的蓝色 (0078D4)，浅色文字，无前缀
        SelectedText := (ThemeMode = "dark") ? "E0E0E0" : "FFFFFF"
        Ctrl.Opt("+Background" . UI_Colors.BtnPrimary)
        Ctrl.SetFont("s" . FontSize . " c" . SelectedText . " Bold", "Segoe UI")
    } else {
        ; 未选中状态：侧边栏背景
        Ctrl.Opt("+Background" . UI_Colors.Sidebar)
        Ctrl.SetFont("s" . FontSize . " c" . UI_Colors.Text . " Norm", "Segoe UI")
    }
    Ctrl.Redraw()
}

; 更新 Material 单选按钮样式
UpdateMaterialRadioButtonStyle(Ctrl, IsSelected) {
    global UI_Colors, ThemeMode
    
    FontSize := Ctrl.HasProp("FontSize") ? Ctrl.FontSize : 11
    
    if (IsSelected) {
        ; 选中状态：蓝色背景
        SelectedText := (ThemeMode = "dark") ? "E0E0E0" : "FFFFFF"
        Ctrl.Opt("+Background" . UI_Colors.BtnPrimary)
        Ctrl.SetFont("s" . FontSize . " c" . SelectedText . " Bold", "Segoe UI")
    } else {
        ; 未选中状态
        Ctrl.Opt("+Background" . UI_Colors.Sidebar)
        Ctrl.SetFont("s" . FontSize . " c" . UI_Colors.Text . " Norm", "Segoe UI")
    }
    Ctrl.Redraw()
}

; ===================== 创建单选按钮点击处理器 =====================
CreateRadioClickHandler(Index, Desc, TypeIndex, RadioControls) {
    ; 返回一个函数，该函数会手动管理互斥并更新说明文字
    ActionFunc(*) {
        ; 手动管理互斥：取消其他按钮的选中状态
        for RadioIndex, RadioCtrl in RadioControls {
            if (RadioIndex != TypeIndex) {
                if (RadioCtrl.HasProp("IsSelected")) {
                    RadioCtrl.IsSelected := false
                    UpdateMaterialRadioButtonStyle(RadioCtrl, false)
                } else {
                    RadioCtrl.Value := 0
                }
            } else {
                if (RadioCtrl.HasProp("IsSelected")) {
                    RadioCtrl.IsSelected := true
                    UpdateMaterialRadioButtonStyle(RadioCtrl, true)
                } else {
                    RadioCtrl.Value := 1
                }
            }
        }
        ; 更新说明文字
        UpdateQuickActionDesc(Index, Desc, TypeIndex)
        
        ; 自动保存配置
        SetTimer(AutoSaveConfig, -100)
    }
    return ActionFunc
}

UpdateQuickActionDesc(Index, Desc, TypeIndex) {
    global GuiID_ConfigGUI, QuickActionButtons
    try {
        ; GuiID_ConfigGUI 直接是 GUI 对象，不需要 GuiFromHwnd
        if (GuiID_ConfigGUI) {
            ; 更新说明文字
            DescCtrl := GuiID_ConfigGUI["QuickActionDesc" . Index]
            if (DescCtrl) {
                DescCtrl.Text := Desc
            }
            
            ; 更新对应的按钮类型（保存到QuickActionButtons中）
            if (QuickActionButtons && QuickActionButtons.Length >= Index) {
                ; 根据TypeIndex找到对应的ActionType（与CreateQuickActionConfigUI中的定义保持一致）
                ActionTypes := [
                    {Type: "Explain", Name: GetText("quick_action_type_explain"), Hotkey: "e", Desc: GetText("hotkey_e_desc")},
                    {Type: "Refactor", Name: GetText("quick_action_type_refactor"), Hotkey: "r", Desc: GetText("hotkey_r_desc")},
                    {Type: "Optimize", Name: GetText("quick_action_type_optimize"), Hotkey: "o", Desc: GetText("hotkey_o_desc")},
                    {Type: "Config", Name: GetText("quick_action_type_config"), Hotkey: "q", Desc: GetText("hotkey_q_desc")},
                    {Type: "Copy", Name: GetText("quick_action_type_copy"), Hotkey: "c", Desc: GetText("hotkey_c_desc")},
                    {Type: "Paste", Name: GetText("quick_action_type_paste"), Hotkey: "v", Desc: GetText("hotkey_v_desc")},
                    {Type: "Clipboard", Name: GetText("quick_action_type_clipboard"), Hotkey: "x", Desc: GetText("hotkey_x_desc")},
                    {Type: "Voice", Name: GetText("quick_action_type_voice"), Hotkey: "z", Desc: GetText("hotkey_z_desc")},
                    {Type: "Split", Name: GetText("quick_action_type_split"), Hotkey: "s", Desc: GetText("hotkey_s_desc")},
                    {Type: "Batch", Name: GetText("quick_action_type_batch"), Hotkey: "b", Desc: GetText("hotkey_b_desc")},
                    {Type: "CommandPalette", Name: GetText("quick_action_type_command_palette"), Hotkey: "", Desc: GetText("quick_action_desc_command_palette")},
                    {Type: "Terminal", Name: GetText("quick_action_type_terminal"), Hotkey: "", Desc: GetText("quick_action_desc_terminal")},
                    {Type: "GlobalSearch", Name: GetText("quick_action_type_global_search"), Hotkey: "", Desc: GetText("quick_action_desc_global_search")},
                    {Type: "Explorer", Name: GetText("quick_action_type_explorer"), Hotkey: "", Desc: GetText("quick_action_desc_explorer")},
                    {Type: "SourceControl", Name: GetText("quick_action_type_source_control"), Hotkey: "", Desc: GetText("quick_action_desc_source_control")},
                    {Type: "Extensions", Name: GetText("quick_action_type_extensions"), Hotkey: "", Desc: GetText("quick_action_desc_extensions")},
                    {Type: "Browser", Name: GetText("quick_action_type_browser"), Hotkey: "", Desc: GetText("quick_action_desc_browser")},
                    {Type: "Settings", Name: GetText("quick_action_type_settings"), Hotkey: "", Desc: GetText("quick_action_desc_settings")},
                    {Type: "CursorSettings", Name: GetText("quick_action_type_cursor_settings"), Hotkey: "", Desc: GetText("quick_action_desc_cursor_settings")}
                ]
                if (TypeIndex >= 1 && TypeIndex <= ActionTypes.Length) {
                    SelectedType := ActionTypes[TypeIndex]
                    QuickActionButtons[Index].Type := SelectedType.Type
                    QuickActionButtons[Index].Hotkey := SelectedType.Hotkey
                }
            }
        }
    } catch as e {
        ; 调试时输出错误信息
        ; MsgBox("UpdateQuickActionDesc Error: " . e.Message)
    }
}

; ===================== 快捷操作按钮移动处理 =====================
CreateQuickActionMoveHandler(Index, Direction) {
    return (*) => MoveQuickActionButton(Index, Direction)
}

MoveQuickActionButton(Index, Direction) {
    global QuickActionButtons, GuiID_ConfigGUI
    
    if (Direction = "up" && Index > 1) {
        ; 上移
        Temp := QuickActionButtons[Index]
        QuickActionButtons[Index] := QuickActionButtons[Index - 1]
        QuickActionButtons[Index - 1] := Temp
        RefreshQuickActionConfigUI()
    } else if (Direction = "down" && Index < QuickActionButtons.Length) {
        ; 下移
        Temp := QuickActionButtons[Index]
        QuickActionButtons[Index] := QuickActionButtons[Index + 1]
        QuickActionButtons[Index + 1] := Temp
        RefreshQuickActionConfigUI()
    }
}

; ===================== 快捷操作按钮删除处理 =====================
CreateQuickActionRemoveHandler(Index) {
    return (*) => RemoveQuickActionButton(Index)
}

RemoveQuickActionButton(Index) {
    global QuickActionButtons
    
    if (QuickActionButtons.Length <= 1) {
        MsgBox(GetText("quick_action_min_reached"), GetText("tip"), "Icon!")
        return
    }
    
    QuickActionButtons.RemoveAt(Index)
    RefreshQuickActionConfigUI()
}


; ===================== 刷新快捷操作配置UI =====================
RefreshQuickActionConfigUI() {
    global GuiID_ConfigGUI, GeneralTabControls, QuickActionButtons
    
    if (GuiID_ConfigGUI = 0) {
        return
    }
    
    try {
        ConfigGUI := GuiFromHwnd(GuiID_ConfigGUI)
        if (!ConfigGUI) {
            return
        }
        
        ; 获取通用标签页的位置和尺寸
        ; 由于需要重新创建UI，我们需要找到通用标签页的位置
        ; 这里我们通过查找GeneralTabPanel来获取位置
        GeneralTabPanel := ConfigGUI["GeneralTabPanel"]
        if (!GeneralTabPanel) {
            return
        }
        
        ; 获取面板位置和尺寸
        GeneralTabPanel.GetPos(&TabX, &TabY, &TabW, &TabH)
        
        ; 重新创建快捷操作配置UI
        ; 先销毁旧的控件
        global QuickActionConfigControls
        for Index, Ctrl in QuickActionConfigControls {
            try {
                Ctrl.Destroy()
            } catch as err {
                ; 忽略已销毁的控件
            }
        }
        
        ; 从GeneralTabControls中移除快捷操作相关的控件
        NewGeneralTabControls := []
        for Index, Ctrl in GeneralTabControls {
            IsQuickActionCtrl := false
            for J, QACtrl in QuickActionConfigControls {
                if (Ctrl = QACtrl) {
                    IsQuickActionCtrl := true
                    break
                }
            }
            if (!IsQuickActionCtrl) {
                NewGeneralTabControls.Push(Ctrl)
            }
        }
        GeneralTabControls := NewGeneralTabControls
        
        ; 重新创建快捷操作配置UI
        ; 计算Y位置（在语言设置之后，大约在TabY + 200的位置）
        ; 需要找到语言设置之后的位置，这里使用固定偏移
        ; 由于UI结构已简化，高度计算：每个按钮75px，5个按钮共375px
        CreateQuickActionConfigUI(ConfigGUI, TabX + 30, TabY + 200, TabW - 60, GeneralTabControls)
    } catch as err {
        ; 如果更新失败，忽略错误
    }
}

; ===================== 创建外观标签页 =====================
CreateAppearanceTab(ConfigGUI, X, Y, W, H) {
    global PanelScreenIndex, AppearanceTabPanel, PanelScreenRadio, AppearanceTabControls
    global UI_Colors
    
    ; 创建标签页面板（默认隐藏）
    AppearanceTabPanel := ConfigGUI.Add("Text", "x" . X . " y" . Y . " w" . W . " h" . H . " Background" . UI_Colors.Background . " vAppearanceTabPanel", "")
    AppearanceTabPanel.Visible := false
    AppearanceTabControls.Push(AppearanceTabPanel)
    
    ; 标题
    Title := ConfigGUI.Add("Text", "x" . (X + 30) . " y" . (Y + 20) . " w" . (W - 60) . " h30 c" . UI_Colors.Text, GetText("appearance_settings"))
    Title.SetFont("s16 Bold", "Segoe UI")
    AppearanceTabControls.Push(Title)
    
    ; 屏幕选择
    YPos := Y + 70
    Label1 := ConfigGUI.Add("Text", "x" . (X + 30) . " y" . YPos . " w200 h25 c" . UI_Colors.Text, GetText("display_screen"))
    Label1.SetFont("s11", "Segoe UI")
    AppearanceTabControls.Push(Label1)
    
    ; 获取屏幕列表
    ScreenList := []
    MonitorCount := 0
    try {
        MonitorCount := MonitorGetCount()
        if (MonitorCount > 0) {
            Loop MonitorCount {
                MonitorIndex := A_Index
                MonitorGet(MonitorIndex, &Left, &Top, &Right, &Bottom)
                ScreenList.Push(FormatText("screen", MonitorIndex))
            }
        }
    } catch as err {
        MonitorIndex := 1
        Loop 10 {
            try {
                MonitorGet(MonitorIndex, &Left, &Top, &Right, &Bottom)
                ScreenList.Push(FormatText("screen", MonitorIndex))
                MonitorCount++
                MonitorIndex++
            } catch as err {
                break
            }
        }
    }
    if (ScreenList.Length = 0) {
        ScreenList.Push(FormatText("screen", 1))
        MonitorCount := 1
    }
    
    YPos += 30
    PanelScreenRadio := []
    StartX := X + 30
    RadioWidth := 100
    RadioHeight := 30
    Spacing := 10
    ; 确保 PanelScreenIndex 在有效范围内
    if (PanelScreenIndex < 1 || PanelScreenIndex > ScreenList.Length) {
        PanelScreenIndex := 1
    }
    for Index, ScreenName in ScreenList {
        XPos := StartX + (Index - 1) * (RadioWidth + Spacing)
        ; 使用 Material 风格的单选按钮
        RadioBtn := CreateMaterialRadioButton(ConfigGUI, XPos, YPos, RadioWidth, RadioHeight, "PanelScreenRadio" . Index, ScreenName, PanelScreenRadio, 11)
        if (Index = PanelScreenIndex) {
            RadioBtn.IsSelected := true
            UpdateMaterialRadioButtonStyle(RadioBtn, true)
        }
        PanelScreenRadio.Push(RadioBtn)
        AppearanceTabControls.Push(RadioBtn)
    }

    ; 面板位置设置
    ; 位置选项 (内部值)
    PosKeys := ["Center", "TopLeft", "TopRight", "BottomLeft", "BottomRight"]
    ; 显示文本
    PosTexts := [GetText("pos_center"), GetText("pos_top_left"), GetText("pos_top_right"), GetText("pos_bottom_left"), GetText("pos_bottom_right")]
    
    ; 主题模式设置（亮色/暗色）
    YPos += 50
    LabelTheme := ConfigGUI.Add("Text", "x" . (X + 30) . " y" . YPos . " w200 h25 c" . UI_Colors.Text, GetText("theme_mode"))
    LabelTheme.SetFont("s11", "Segoe UI")
    AppearanceTabControls.Push(LabelTheme)
    
    YPos += 30
    global ThemeMode, ThemeLightRadio, ThemeDarkRadio
    ; 创建 Material 风格的主题模式单选按钮组
    global ThemeRadioGroup := []
    ThemeLightRadio := CreateMaterialRadioButton(ConfigGUI, X + 30, YPos, 100, 30, "ThemeLightRadio", GetText("theme_light"), ThemeRadioGroup, 11)
    ThemeRadioGroup.Push(ThemeLightRadio)
    AppearanceTabControls.Push(ThemeLightRadio)
    
    ThemeDarkRadio := CreateMaterialRadioButton(ConfigGUI, X + 140, YPos, 100, 30, "ThemeDarkRadio", GetText("theme_dark"), ThemeRadioGroup, 11)
    ThemeRadioGroup.Push(ThemeDarkRadio)
    AppearanceTabControls.Push(ThemeDarkRadio)
    
    ; 设置当前主题
    if (ThemeMode = "light") {
        ThemeLightRadio.IsSelected := true
        UpdateMaterialRadioButtonStyle(ThemeLightRadio, true)
    } else {
        ThemeDarkRadio.IsSelected := true
        UpdateMaterialRadioButtonStyle(ThemeDarkRadio, true)
    }
    
    ; 获取屏幕列表（用于显示器选择）
    ScreenList := []
    MonitorCount := 0
    try {
        MonitorCount := MonitorGetCount()
        if (MonitorCount > 0) {
            Loop MonitorCount {
                MonitorIndex := A_Index
                MonitorGet(MonitorIndex, &Left, &Top, &Right, &Bottom)
                ScreenList.Push(FormatText("screen", MonitorIndex))
            }
        }
    } catch as err {
        MonitorIndex := 1
        Loop 10 {
            try {
                MonitorGet(MonitorIndex, &Left, &Top, &Right, &Bottom)
                ScreenList.Push(FormatText("screen", MonitorIndex))
                MonitorCount++
                MonitorIndex++
            } catch as err {
                break
            }
        }
    }
    if (ScreenList.Length = 0) {
        ScreenList.Push(FormatText("screen", 1))
        MonitorCount := 1
    }
    
    ; 配置面板显示器选择（从高级设置移到这里）
    YPos += 60
    global ConfigPanelScreenIndex, ConfigPanelScreenRadio
    LabelConfigPanel := ConfigGUI.Add("Text", "x" . (X + 30) . " y" . YPos . " w200 h25 c" . UI_Colors.Text, GetText("config_panel_screen"))
    LabelConfigPanel.SetFont("s11", "Segoe UI")
    AppearanceTabControls.Push(LabelConfigPanel)
    
    YPos += 30
    ConfigPanelScreenRadio := []
    StartX := X + 30
    RadioWidth := 100
    RadioHeight := 30
    Spacing := 10
    if (ConfigPanelScreenIndex < 1 || ConfigPanelScreenIndex > ScreenList.Length) {
        ConfigPanelScreenIndex := 1
    }
    for Index, ScreenName in ScreenList {
        XPos := StartX + (Index - 1) * (RadioWidth + Spacing)
        RadioBtn := CreateMaterialRadioButton(ConfigGUI, XPos, YPos, RadioWidth, RadioHeight, "ConfigPanelScreenRadio" . Index, ScreenName, ConfigPanelScreenRadio, 11)
        if (Index = ConfigPanelScreenIndex) {
            RadioBtn.IsSelected := true
            UpdateMaterialRadioButtonStyle(RadioBtn, true)
        }
        ConfigPanelScreenRadio.Push(RadioBtn)
        AppearanceTabControls.Push(RadioBtn)
    }
    
    ; 弹窗显示器选择
    YPos += 50
    global MsgBoxScreenIndex, MsgBoxScreenRadio
    LabelMsgBox := ConfigGUI.Add("Text", "x" . (X + 30) . " y" . YPos . " w200 h25 c" . UI_Colors.Text, GetText("msgbox_screen"))
    LabelMsgBox.SetFont("s11", "Segoe UI")
    AppearanceTabControls.Push(LabelMsgBox)
    
    YPos += 30
    MsgBoxScreenRadio := []
    if (MsgBoxScreenIndex < 1 || MsgBoxScreenIndex > ScreenList.Length) {
        MsgBoxScreenIndex := 1
    }
    for Index, ScreenName in ScreenList {
        XPos := StartX + (Index - 1) * (RadioWidth + Spacing)
        RadioBtn := CreateMaterialRadioButton(ConfigGUI, XPos, YPos, RadioWidth, RadioHeight, "MsgBoxScreenRadio" . Index, ScreenName, MsgBoxScreenRadio, 11)
        if (Index = MsgBoxScreenIndex) {
            RadioBtn.IsSelected := true
            UpdateMaterialRadioButtonStyle(RadioBtn, true)
        }
        MsgBoxScreenRadio.Push(RadioBtn)
        AppearanceTabControls.Push(RadioBtn)
    }
    
    ; 语音输入法提示显示器选择
    YPos += 50
    global VoiceInputScreenIndex, VoiceInputScreenRadio
    LabelVoiceInput := ConfigGUI.Add("Text", "x" . (X + 30) . " y" . YPos . " w200 h25 c" . UI_Colors.Text, GetText("voice_input_screen"))
    LabelVoiceInput.SetFont("s11", "Segoe UI")
    AppearanceTabControls.Push(LabelVoiceInput)
    
    YPos += 30
    VoiceInputScreenRadio := []
    if (VoiceInputScreenIndex < 1 || VoiceInputScreenIndex > ScreenList.Length) {
        VoiceInputScreenIndex := 1
    }
    for Index, ScreenName in ScreenList {
        XPos := StartX + (Index - 1) * (RadioWidth + Spacing)
        RadioBtn := CreateMaterialRadioButton(ConfigGUI, XPos, YPos, RadioWidth, RadioHeight, "VoiceInputScreenRadio" . Index, ScreenName, VoiceInputScreenRadio, 11)
        if (Index = VoiceInputScreenIndex) {
            RadioBtn.IsSelected := true
            UpdateMaterialRadioButtonStyle(RadioBtn, true)
        }
        VoiceInputScreenRadio.Push(RadioBtn)
        AppearanceTabControls.Push(RadioBtn)
    }
    
    ; Cursor快捷弹出面板显示器选择
    YPos += 50
    global CursorPanelScreenIndex, CursorPanelScreenRadio
    LabelCursorPanel := ConfigGUI.Add("Text", "x" . (X + 30) . " y" . YPos . " w200 h25 c" . UI_Colors.Text, GetText("cursor_panel_screen"))
    LabelCursorPanel.SetFont("s11", "Segoe UI")
    AppearanceTabControls.Push(LabelCursorPanel)
    
    YPos += 30
    CursorPanelScreenRadio := []
    if (CursorPanelScreenIndex < 1 || CursorPanelScreenIndex > ScreenList.Length) {
        CursorPanelScreenIndex := 1
    }
    for Index, ScreenName in ScreenList {
        XPos := StartX + (Index - 1) * (RadioWidth + Spacing)
        RadioBtn := CreateMaterialRadioButton(ConfigGUI, XPos, YPos, RadioWidth, RadioHeight, "CursorPanelScreenRadio" . Index, ScreenName, CursorPanelScreenRadio, 11)
        if (Index = CursorPanelScreenIndex) {
            RadioBtn.IsSelected := true
            UpdateMaterialRadioButtonStyle(RadioBtn, true)
        }
        CursorPanelScreenRadio.Push(RadioBtn)
        AppearanceTabControls.Push(RadioBtn)
    }
    
    ; 剪贴板管理面板显示器选择
    YPos += 50
    global ClipboardPanelScreenIndex, ClipboardPanelScreenRadio
    LabelClipboardPanel := ConfigGUI.Add("Text", "x" . (X + 30) . " y" . YPos . " w200 h25 c" . UI_Colors.Text, GetText("clipboard_panel_screen"))
    LabelClipboardPanel.SetFont("s11", "Segoe UI")
    AppearanceTabControls.Push(LabelClipboardPanel)
    
    YPos += 30
    ClipboardPanelScreenRadio := []
    if (ClipboardPanelScreenIndex < 1 || ClipboardPanelScreenIndex > ScreenList.Length) {
        ClipboardPanelScreenIndex := 1
    }
    for Index, ScreenName in ScreenList {
        XPos := StartX + (Index - 1) * (RadioWidth + Spacing)
        RadioBtn := CreateMaterialRadioButton(ConfigGUI, XPos, YPos, RadioWidth, RadioHeight, "ClipboardPanelScreenRadio" . Index, ScreenName, ClipboardPanelScreenRadio, 11)
        if (Index = ClipboardPanelScreenIndex) {
            RadioBtn.IsSelected := true
            UpdateMaterialRadioButtonStyle(RadioBtn, true)
        }
        ClipboardPanelScreenRadio.Push(RadioBtn)
        AppearanceTabControls.Push(RadioBtn)
    }
}

; ===================== 模板管理功能 =====================
; 刷新模板列表
RefreshTemplateListView() {
    global PromptTemplateListView, PromptTemplates, DefaultTemplateIDs
    
    if (!IsSet(PromptTemplateListView) || !PromptTemplateListView) {
        return
    }
    
    ; 清空列表
    PromptTemplateListView.Delete()
    
    ; 添加模板到列表
    for Index, Template in PromptTemplates {
        ; 检查是否为默认模板
        DefaultMark := ""
        if (DefaultTemplateIDs["Explain"] = Template.ID) {
            DefaultMark := "解释"
        } else if (DefaultTemplateIDs["Refactor"] = Template.ID) {
            DefaultMark := "重构"
        } else if (DefaultTemplateIDs["Optimize"] = Template.ID) {
            DefaultMark := "优化"
        }
        
        PromptTemplateListView.Add("", Template.Title, Template.Category, DefaultMark)
    }
}

; 添加提示词模板
AddPromptTemplate() {
    global PromptTemplates, UI_Colors, ConfigGUI, ThemeMode
    
    ; 创建编辑对话框
    EditGUI := Gui("+AlwaysOnTop -Caption", "添加提示词模板")
    EditGUI.BackColor := UI_Colors.Background
    EditGUI.SetFont("s10 c" . UI_Colors.Text, "Segoe UI")
    
    ; 自定义标题栏
    TitleBarHeight := 35
    TitleBar := EditGUI.Add("Text", "x0 y0 w340 h" . TitleBarHeight . " Background" . UI_Colors.TitleBar . " vAddTemplateTitleBar", "添加提示词模板")
    TitleBar.SetFont("s10 Bold c" . UI_Colors.Text, "Segoe UI")
    TitleBar.OnEvent("Click", (*) => PostMessage(0xA1, 2, , , EditGUI.Hwnd)) ; 拖动窗口
    
    ; 关闭按钮
    CloseBtn := EditGUI.Add("Text", "x300 y0 w40 h" . TitleBarHeight . " Center 0x200 c" . UI_Colors.Text . " Background" . UI_Colors.TitleBar . " vAddTemplateCloseBtn", "✕")
    CloseBtn.SetFont("s10", "Segoe UI")
    CloseBtn.OnEvent("Click", (*) => EditGUI.Destroy())
    HoverBtnWithAnimation(CloseBtn, UI_Colors.TitleBar, "e81123")
    
    ; 调整Y位置，为标题栏留出空间
    EditGUI.Add("Text", "x20 y" . (TitleBarHeight + 10) . " w300 h25 c" . UI_Colors.Text, "模板标题:")
    TitleEdit := EditGUI.Add("Edit", "x20 y" . (TitleBarHeight + 35) . " w300 h25 vTemplateTitle Background" . UI_Colors.InputBg . " c" . UI_Colors.Text, "")
    TitleEdit.SetFont("s10", "Segoe UI")
    
    ; 分类
    EditGUI.Add("Text", "x20 y" . (TitleBarHeight + 70) . " w300 h25 c" . UI_Colors.Text, "分类:")
    CategoryOrder := ["基础", "改错", "专业"]
    CategoryDDL := EditGUI.Add("DDL", "x20 y" . (TitleBarHeight + 95) . " w300 h30 R3 Background" . UI_Colors.DDLBg . " c" . UI_Colors.DDLText . " vTemplateCategory", CategoryOrder)
    CategoryDDL.SetFont("s10", "Segoe UI")
    ; 默认选择第一个分类
    CategoryDDL.Value := 1
    
    ; 内容
    EditGUI.Add("Text", "x20 y" . (TitleBarHeight + 135) . " w300 h25 c" . UI_Colors.Text, "提示词内容:")
    ContentEdit := EditGUI.Add("Edit", "x20 y" . (TitleBarHeight + 160) . " w300 h200 vTemplateContent Background" . UI_Colors.InputBg . " c" . UI_Colors.Text . " Multi", "")
    ContentEdit.SetFont("s10", "Consolas")
    
    ; 按钮
    TextColor := (ThemeMode = "light") ? UI_Colors.Text : UI_Colors.Text  ; html.to.design 风格文本
    BtnY := TitleBarHeight + 370
    SaveBtn := EditGUI.Add("Text", "x20 y" . BtnY . " w120 h35 Center 0x200 c" . TextColor . " Background" . UI_Colors.BtnPrimary . " vSaveBtn", "保存")
    SaveBtn.SetFont("s10", "Segoe UI")
    SaveBtn.OnEvent("Click", (*) => SaveTemplateFromDialog(EditGUI, ""))
    HoverBtnWithAnimation(SaveBtn, UI_Colors.BtnPrimary, UI_Colors.BtnHover)
    
    CancelBtn := EditGUI.Add("Text", "x200 y" . BtnY . " w120 h35 Center 0x200 c" . TextColor . " Background" . UI_Colors.BtnBg . " vCancelBtn", "取消")
    CancelBtn.SetFont("s10", "Segoe UI")
    CancelBtn.OnEvent("Click", (*) => EditGUI.Destroy())
    HoverBtnWithAnimation(CancelBtn, UI_Colors.BtnBg, UI_Colors.BtnHover)
    
    ; ESC键关闭窗口
    EditGUI.OnEvent("Escape", (*) => EditGUI.Destroy())
    
    EditGUI.Show("w340 h" . (BtnY + 50))
}

; 编辑提示词模板
EditPromptTemplate() {
    global PromptTemplateListView, PromptTemplates, UI_Colors, ThemeMode
    
    SelectedRow := PromptTemplateListView.GetNext()
    if (SelectedRow = 0) {
        MsgBox("请先选择一个模板", "提示", "Iconi")
        return
    }
    
    ; 获取选中的模板
    TemplateIndex := SelectedRow
    if (TemplateIndex < 1 || TemplateIndex > PromptTemplates.Length) {
        return
    }
    
    Template := PromptTemplates[TemplateIndex]
    
    ; 创建编辑对话框
    EditGUI := Gui("+AlwaysOnTop -Caption", "编辑提示词模板")
    EditGUI.BackColor := UI_Colors.Background
    EditGUI.SetFont("s10 c" . UI_Colors.Text, "Segoe UI")
    
    ; 自定义标题栏
    TitleBarHeight := 35
    TitleBar := EditGUI.Add("Text", "x0 y0 w340 h" . TitleBarHeight . " Background" . UI_Colors.TitleBar . " vEditPromptTemplateTitleBar", "编辑提示词模板")
    TitleBar.SetFont("s10 Bold c" . UI_Colors.Text, "Segoe UI")
    TitleBar.OnEvent("Click", (*) => PostMessage(0xA1, 2)) ; 拖动窗口
    
    ; 关闭按钮
    CloseBtn := EditGUI.Add("Text", "x300 y0 w40 h" . TitleBarHeight . " Center 0x200 c" . UI_Colors.Text . " Background" . UI_Colors.TitleBar . " vEditPromptTemplateCloseBtn", "✕")
    CloseBtn.SetFont("s10", "Segoe UI")
    CloseBtn.OnEvent("Click", (*) => EditGUI.Destroy())
    HoverBtnWithAnimation(CloseBtn, UI_Colors.TitleBar, "e81123")
    
    ; 调整Y位置，为标题栏留出空间
    EditGUI.Add("Text", "x20 y" . (TitleBarHeight + 10) . " w300 h25 c" . UI_Colors.Text, "模板标题:")
    TitleEdit := EditGUI.Add("Edit", "x20 y" . (TitleBarHeight + 35) . " w300 h25 vTemplateTitle Background" . UI_Colors.InputBg . " c" . UI_Colors.Text, Template.Title)
    TitleEdit.SetFont("s10", "Segoe UI")
    
    ; 分类
    EditGUI.Add("Text", "x20 y" . (TitleBarHeight + 70) . " w300 h25 c" . UI_Colors.Text, "分类:")
    CategoryEdit := EditGUI.Add("Edit", "x20 y" . (TitleBarHeight + 95) . " w300 h25 vTemplateCategory Background" . UI_Colors.InputBg . " c" . UI_Colors.Text, Template.Category)
    CategoryEdit.SetFont("s10", "Segoe UI")
    
    ; 内容
    EditGUI.Add("Text", "x20 y" . (TitleBarHeight + 130) . " w300 h25 c" . UI_Colors.Text, "提示词内容:")
    ContentEdit := EditGUI.Add("Edit", "x20 y" . (TitleBarHeight + 155) . " w300 h200 vTemplateContent Background" . UI_Colors.InputBg . " c" . UI_Colors.Text . " Multi", Template.Content)
    ContentEdit.SetFont("s10", "Consolas")
    
    ; 按钮
    TextColor := (ThemeMode = "light") ? UI_Colors.Text : UI_Colors.Text  ; html.to.design 风格文本
    BtnY := TitleBarHeight + 365
    SaveBtn := EditGUI.Add("Text", "x20 y" . BtnY . " w120 h35 Center 0x200 c" . TextColor . " Background" . UI_Colors.BtnPrimary . " vSaveBtn", "保存")
    SaveBtn.SetFont("s10", "Segoe UI")
    SaveBtn.OnEvent("Click", (*) => SaveTemplateFromDialog(EditGUI, Template.ID))
    HoverBtnWithAnimation(SaveBtn, UI_Colors.BtnPrimary, UI_Colors.BtnHover)
    
    CancelBtn := EditGUI.Add("Text", "x200 y" . BtnY . " w120 h35 Center 0x200 c" . TextColor . " Background" . UI_Colors.BtnBg . " vCancelBtn", "取消")
    CancelBtn.SetFont("s10", "Segoe UI")
    CancelBtn.OnEvent("Click", (*) => EditGUI.Destroy())
    HoverBtnWithAnimation(CancelBtn, UI_Colors.BtnBg, UI_Colors.BtnHover)
    
    EditGUI.Show("w340 h" . (BtnY + 50))
}

; ===================== 编辑模板对话框（接受ID和Template对象）=====================
EditPromptTemplateDialog(TemplateID, Template) {
    global PromptTemplates, UI_Colors, ThemeMode, SavePromptTemplates
    
    ; 创建编辑对话框
    EditGUI := Gui("+AlwaysOnTop -Caption", "编辑提示词模板")
    EditGUI.BackColor := UI_Colors.Background
    EditGUI.SetFont("s10 c" . UI_Colors.Text, "Segoe UI")
    
    ; 自定义标题栏
    TitleBarHeight := 35
    TitleBar := EditGUI.Add("Text", "x0 y0 w340 h" . TitleBarHeight . " Background" . UI_Colors.TitleBar . " vEditTemplateTitleBar", "编辑提示词模板")
    TitleBar.SetFont("s10 Bold c" . UI_Colors.Text, "Segoe UI")
    TitleBar.OnEvent("Click", (*) => PostMessage(0xA1, 2, , , EditGUI.Hwnd)) ; 拖动窗口
    
    ; 关闭按钮
    CloseBtn := EditGUI.Add("Text", "x300 y0 w40 h" . TitleBarHeight . " Center 0x200 c" . UI_Colors.Text . " Background" . UI_Colors.TitleBar . " vEditTemplateCloseBtn", "✕")
    CloseBtn.SetFont("s10", "Segoe UI")
    CloseBtn.OnEvent("Click", (*) => EditGUI.Destroy())
    HoverBtnWithAnimation(CloseBtn, UI_Colors.TitleBar, "e81123")
    
    ; 调整Y位置，为标题栏留出空间
    EditGUI.Add("Text", "x20 y" . (TitleBarHeight + 10) . " w300 h25 c" . UI_Colors.Text, "模板标题:")
    TitleEdit := EditGUI.Add("Edit", "x20 y" . (TitleBarHeight + 35) . " w300 h25 vTemplateTitle Background" . UI_Colors.InputBg . " c" . UI_Colors.Text, Template.Title)
    TitleEdit.SetFont("s10", "Segoe UI")
    
    ; 分类
    EditGUI.Add("Text", "x20 y" . (TitleBarHeight + 70) . " w300 h25 c" . UI_Colors.Text, "分类:")
    CategoryOrder := ["基础", "改错", "专业"]
    CategoryDDL := EditGUI.Add("DDL", "x20 y" . (TitleBarHeight + 95) . " w300 h30 R3 Background" . UI_Colors.DDLBg . " c" . UI_Colors.DDLText . " vTemplateCategory", CategoryOrder)
    CategoryDDL.SetFont("s10", "Segoe UI")
    ; 设置当前分类为选中
    for Index, Cat in CategoryOrder {
        if (Cat = Template.Category) {
            CategoryDDL.Value := Index
            break
        }
    }
    
    ; 内容
    EditGUI.Add("Text", "x20 y" . (TitleBarHeight + 135) . " w300 h25 c" . UI_Colors.Text, "提示词内容:")
    ContentEdit := EditGUI.Add("Edit", "x20 y" . (TitleBarHeight + 160) . " w300 h200 vTemplateContent Background" . UI_Colors.InputBg . " c" . UI_Colors.Text . " Multi", Template.Content)
    ContentEdit.SetFont("s10", "Consolas")
    
    ; 按钮
    TextColor := (ThemeMode = "light") ? UI_Colors.Text : UI_Colors.Text  ; html.to.design 风格文本
    BtnY := TitleBarHeight + 370
    SaveBtn := EditGUI.Add("Text", "x20 y" . BtnY . " w120 h35 Center 0x200 c" . TextColor . " Background" . UI_Colors.BtnPrimary . " vSaveBtn", "保存")
    SaveBtn.SetFont("s10", "Segoe UI")
    SaveBtn.OnEvent("Click", (*) => SaveTemplateFromDialog(EditGUI, TemplateID))
    HoverBtnWithAnimation(SaveBtn, UI_Colors.BtnPrimary, UI_Colors.BtnHover)
    
    CancelBtn := EditGUI.Add("Text", "x200 y" . BtnY . " w120 h35 Center 0x200 c" . TextColor . " Background" . UI_Colors.BtnBg . " vCancelBtn", "取消")
    CancelBtn.SetFont("s10", "Segoe UI")
    CancelBtn.OnEvent("Click", (*) => EditGUI.Destroy())
    HoverBtnWithAnimation(CancelBtn, UI_Colors.BtnBg, UI_Colors.BtnHover)
    
    ; ESC键关闭窗口
    EditGUI.OnEvent("Escape", (*) => EditGUI.Destroy())
    
    EditGUI.Show("w340 h" . (BtnY + 50))
}

; 从对话框保存模板
SaveTemplateFromDialog(EditGUI, TemplateID) {
    global PromptTemplates
    
    ; 获取输入值
    Title := EditGUI["TemplateTitle"].Value
    ; 检查是否是DDL还是Edit控件
    CategoryCtrl := EditGUI["TemplateCategory"]
    if (Type(CategoryCtrl) = "ComboBox" || CategoryCtrl.Type = "ComboBox") {
        Category := CategoryCtrl.Text  ; DDL使用Text属性
    } else {
        Category := CategoryCtrl.Value  ; Edit控件使用Value属性
    }
    Content := EditGUI["TemplateContent"].Value
    
    if (Title = "" || Content = "") {
        MsgBox("标题和内容不能为空", "提示", "Iconx")
        return
    }
    
    if (TemplateID = "") {
        ; 添加新模板
        NewID := "template_" . A_TickCount
        NewTemplate := {
            ID: NewID,
            Title: Title,
            Content: Content,
            Icon: "",  ; 不再使用图标
            Category: Category != "" ? Category : "自定义"
        }
        PromptTemplates.Push(NewTemplate)
        
        ; 🚀 性能优化：立即更新索引
        global TemplateIndexByID, TemplateIndexByTitle, TemplateIndexByArrayIndex
        TemplateIndexByID[NewID] := NewTemplate
        Key := NewTemplate.Category . "|" . NewTemplate.Title
        TemplateIndexByTitle[Key] := NewTemplate
        TemplateIndexByArrayIndex[NewID] := PromptTemplates.Length
    } else {
        ; 🚀 性能优化：使用索引直接更新 - O(1)
        global TemplateIndexByID
        if (TemplateIndexByID.Has(TemplateID)) {
            Template := TemplateIndexByID[TemplateID]
            OldCategory := Template.Category
            Template.Title := Title
            Template.Content := Content
            Template.Category := Category != "" ? Category : "自定义"
            
            ; 更新索引
            TemplateIndexByID[TemplateID] := Template
            ; 更新Title索引（如果分类或标题改变）
            if (OldCategory != Template.Category || Template.Title != Title) {
                global TemplateIndexByTitle
                ; 删除旧索引
                OldKey := OldCategory . "|" . Template.Title
                if (TemplateIndexByTitle.Has(OldKey)) {
                    TemplateIndexByTitle.Delete(OldKey)
                }
                ; 添加新索引
                NewKey := Template.Category . "|" . Template.Title
                TemplateIndexByTitle[NewKey] := Template
            }
        }
    }
    
    ; 🚀 性能优化：标记分类映射需要重建（如果添加了新模板）
    if (TemplateID = "") {
        InvalidateTemplateCache()
    }
    
    ; 保存到文件
    SavePromptTemplates()
    
    ; 刷新模板管理ListView
    try {
        RefreshPromptListView()
    } catch as err {
        ; 如果函数不存在，忽略错误
    }
    
    ; 关闭对话框
    EditGUI.Destroy()
}

; 删除提示词模板
DeletePromptTemplate() {
    global PromptTemplateListView, PromptTemplates, DefaultTemplateIDs
    
    SelectedRow := PromptTemplateListView.GetNext()
    if (SelectedRow = 0) {
        MsgBox("请先选择一个模板", "提示", "Iconi")
        return
    }
    
    TemplateIndex := SelectedRow
    if (TemplateIndex < 1 || TemplateIndex > PromptTemplates.Length) {
        return
    }
    
    Template := PromptTemplates[TemplateIndex]
    
    ; 检查是否为默认模板
    if (DefaultTemplateIDs["Explain"] = Template.ID || DefaultTemplateIDs["Refactor"] = Template.ID || DefaultTemplateIDs["Optimize"] = Template.ID) {
        MsgBox("不能删除默认模板，请先取消其默认设置", "提示", "Iconx")
        return
    }
    
    ; 确认删除
    Quote := Chr(34)
    Result := MsgBox("确定要删除模板 " . Quote . Template.Title . Quote . " 吗？", "确认删除", "YesNo Icon?")
    if (Result = "Yes") {
        ; 删除模板
        PromptTemplates.RemoveAt(TemplateIndex)
        
        ; 保存到文件
        SavePromptTemplates()
        
        ; 刷新模板管理标签页
        RefreshPromptsManageTab()
    }
}

; 设为默认模板
SetDefaultTemplate() {
    global PromptTemplateListView, PromptTemplates, DefaultTemplateIDs
    
    SelectedRow := PromptTemplateListView.GetNext()
    if (SelectedRow = 0) {
        MsgBox("请先选择一个模板", "提示", "Iconi")
        return
    }
    
    TemplateIndex := SelectedRow
    if (TemplateIndex < 1 || TemplateIndex > PromptTemplates.Length) {
        return
    }
    
    Template := PromptTemplates[TemplateIndex]
    
    ; 创建选择对话框
    SelectGUI := Gui("+AlwaysOnTop -Caption", "设为默认模板")
    SelectGUI.BackColor := UI_Colors.Background
    SelectGUI.SetFont("s10 c" . UI_Colors.Text, "Segoe UI")
    
    ; 自定义标题栏
    TitleBarHeight := 35
    TitleBar := SelectGUI.Add("Text", "x0 y0 w300 h" . TitleBarHeight . " Background" . UI_Colors.TitleBar . " vSelectTemplateTitleBar", "设为默认模板")
    TitleBar.SetFont("s10 Bold c" . UI_Colors.Text, "Segoe UI")
    TitleBar.OnEvent("Click", (*) => PostMessage(0xA1, 2, , , SelectGUI.Hwnd)) ; 拖动窗口
    
    ; 关闭按钮
    CloseBtn := SelectGUI.Add("Text", "x260 y0 w40 h" . TitleBarHeight . " Center 0x200 c" . UI_Colors.Text . " Background" . UI_Colors.TitleBar . " vSelectTemplateCloseBtn", "✕")
    CloseBtn.SetFont("s10", "Segoe UI")
    CloseBtn.OnEvent("Click", (*) => SelectGUI.Destroy())
    HoverBtnWithAnimation(CloseBtn, UI_Colors.TitleBar, "e81123")
    
    ; 调整Y位置，为标题栏留出空间
    SelectGUI.Add("Text", "x20 y" . (TitleBarHeight + 10) . " w260 h25 c" . UI_Colors.Text, "选择默认用途:")
    
    global ThemeMode
    TextColor := (ThemeMode = "light") ? UI_Colors.Text : UI_Colors.Text  ; html.to.design 风格文本
    
    BtnStartY := TitleBarHeight + 50
    ExplainBtn := SelectGUI.Add("Text", "x20 y" . BtnStartY . " w260 h35 Center 0x200 c" . TextColor . " Background" . UI_Colors.BtnBg . " vExplainBtn", "设为解释默认模板")
    ExplainBtn.SetFont("s10", "Segoe UI")
    ExplainBtn.OnEvent("Click", (*) => SetDefaultTemplateAction(Template.ID, "Explain", SelectGUI))
    HoverBtnWithAnimation(ExplainBtn, UI_Colors.BtnBg, UI_Colors.BtnHover)
    
    BtnStartY += 45
    RefactorBtn := SelectGUI.Add("Text", "x20 y" . BtnStartY . " w260 h35 Center 0x200 c" . TextColor . " Background" . UI_Colors.BtnBg . " vRefactorBtn", "设为重构默认模板")
    RefactorBtn.SetFont("s10", "Segoe UI")
    RefactorBtn.OnEvent("Click", (*) => SetDefaultTemplateAction(Template.ID, "Refactor", SelectGUI))
    HoverBtnWithAnimation(RefactorBtn, UI_Colors.BtnBg, UI_Colors.BtnHover)
    
    BtnStartY += 45
    OptimizeBtn := SelectGUI.Add("Text", "x20 y" . BtnStartY . " w260 h35 Center 0x200 c" . TextColor . " Background" . UI_Colors.BtnBg . " vOptimizeBtn", "设为优化默认模板")
    OptimizeBtn.SetFont("s10", "Segoe UI")
    OptimizeBtn.OnEvent("Click", (*) => SetDefaultTemplateAction(Template.ID, "Optimize", SelectGUI))
    HoverBtnWithAnimation(OptimizeBtn, UI_Colors.BtnBg, UI_Colors.BtnHover)
    
    BtnStartY += 45
    CancelBtn := SelectGUI.Add("Text", "x20 y" . BtnStartY . " w260 h35 Center 0x200 c" . TextColor . " Background" . UI_Colors.BtnBg . " vCancelBtn", "取消")
    CancelBtn.SetFont("s10", "Segoe UI")
    CancelBtn.OnEvent("Click", (*) => SelectGUI.Destroy())
    HoverBtnWithAnimation(CancelBtn, UI_Colors.BtnBg, UI_Colors.BtnHover)
    
    ; ESC键关闭窗口
    SelectGUI.OnEvent("Escape", (*) => SelectGUI.Destroy())
    
    SelectGUI.Show("w300 h" . (BtnStartY + 50))
}

; 执行设为默认操作
SetDefaultTemplateAction(TemplateID, Type, SelectGUI) {
    global DefaultTemplateIDs
    
    DefaultTemplateIDs[Type] := TemplateID
    
    ; 保存到文件
    SavePromptTemplates()
    
    ; 刷新模板管理标签页
    RefreshPromptsManageTab()
    
    ; 关闭对话框
    SelectGUI.Destroy()
    
    MsgBox("已设置为" . Type . "的默认模板", "提示", "Iconi")
}

; 导入提示词模板
ImportPromptTemplates() {
    global PromptTemplates, UI_Colors, ThemeMode
    
    ; 选择文件
    FilePath := FileSelect(1, A_ScriptDir, "选择要导入的模板文件", "JSON文件 (*.json)")
    if (FilePath = "") {
        return
    }
    
    try {
        ; 读取JSON文件
        JsonContent := FileRead(FilePath, "UTF-8")
        if (JsonContent = "") {
            MsgBox("文件为空", "提示", "Iconx")
            return
        }
        
        ; 解析JSON（改进解析）
        ImportedTemplates := ParseJSONTemplates(JsonContent)
        if (ImportedTemplates.Length = 0) {
            MsgBox("文件中没有找到模板", "提示", "Iconx")
            return
        }
        
        ; 询问导入方式
        ImportGUI := Gui("+AlwaysOnTop -Caption", "导入模板")
        ImportGUI.BackColor := UI_Colors.Background
        ImportGUI.SetFont("s10 c" . UI_Colors.Text, "Segoe UI")
        
        ; 自定义标题栏
        TitleBarHeight := 35
        TitleBar := ImportGUI.Add("Text", "x0 y0 w300 h" . TitleBarHeight . " Background" . UI_Colors.TitleBar . " vImportTemplateTitleBar", "导入模板")
        TitleBar.SetFont("s10 Bold c" . UI_Colors.Text, "Segoe UI")
        TitleBar.OnEvent("Click", (*) => PostMessage(0xA1, 2, , , ImportGUI.Hwnd)) ; 拖动窗口
        
        ; 关闭按钮
        CloseBtn := ImportGUI.Add("Text", "x260 y0 w40 h" . TitleBarHeight . " Center 0x200 c" . UI_Colors.Text . " Background" . UI_Colors.TitleBar . " vImportTemplateCloseBtn", "✕")
        CloseBtn.SetFont("s10", "Segoe UI")
        CloseBtn.OnEvent("Click", (*) => ImportGUI.Destroy())
        HoverBtnWithAnimation(CloseBtn, UI_Colors.TitleBar, "e81123")
        
        ; 调整Y位置，为标题栏留出空间
        ImportGUI.Add("Text", "x20 y" . (TitleBarHeight + 10) . " w260 h25 c" . UI_Colors.Text, "发现 " . ImportedTemplates.Length . " 个模板")
        ImportGUI.Add("Text", "x20 y" . (TitleBarHeight + 40) . " w260 h40 c" . UI_Colors.Text, "选择导入方式:")
        
        TextColor := (ThemeMode = "light") ? UI_Colors.Text : UI_Colors.Text  ; html.to.design 风格文本
        
        ; 全部导入（跳过已存在的）
        BtnStartY := TitleBarHeight + 90
        ImportAllBtn := ImportGUI.Add("Text", "x20 y" . BtnStartY . " w260 h35 Center 0x200 c" . TextColor . " Background" . UI_Colors.BtnPrimary . " vImportAllBtn", "全部导入（跳过已存在）")
        ImportAllBtn.SetFont("s10", "Segoe UI")
        ImportAllBtn.OnEvent("Click", (*) => ImportTemplatesAction(ImportedTemplates, "skip", ImportGUI))
        HoverBtnWithAnimation(ImportAllBtn, UI_Colors.BtnPrimary, UI_Colors.BtnPrimaryHover)
        
        ; 全部导入（覆盖已存在的）
        BtnStartY += 45
        ImportOverwriteBtn := ImportGUI.Add("Text", "x20 y" . BtnStartY . " w260 h35 Center 0x200 c" . TextColor . " Background" . UI_Colors.BtnBg . " vImportOverwriteBtn", "全部导入（覆盖已存在）")
        ImportOverwriteBtn.SetFont("s10", "Segoe UI")
        ImportOverwriteBtn.OnEvent("Click", (*) => ImportTemplatesAction(ImportedTemplates, "overwrite", ImportGUI))
        HoverBtnWithAnimation(ImportOverwriteBtn, UI_Colors.BtnBg, UI_Colors.BtnHover)
        
        ; 取消
        BtnStartY += 45
        CancelBtn := ImportGUI.Add("Text", "x20 y" . BtnStartY . " w260 h35 Center 0x200 c" . TextColor . " Background" . UI_Colors.BtnBg . " vCancelBtn", "取消")
        CancelBtn.SetFont("s10", "Segoe UI")
        CancelBtn.OnEvent("Click", (*) => ImportGUI.Destroy())
        HoverBtnWithAnimation(CancelBtn, UI_Colors.BtnBg, UI_Colors.BtnHover)
        
        ; ESC键关闭窗口
        ImportGUI.OnEvent("Escape", (*) => ImportGUI.Destroy())
        
        ImportGUI.Show("w300 h" . (BtnStartY + 50))
    } catch as e {
        MsgBox("导入失败: " . e.Message, "错误", "Iconx")
    }
}

; 执行导入操作
ImportTemplatesAction(ImportedTemplates, Mode, ImportGUI) {
    global PromptTemplates
    
    ImportedCount := 0
    OverwrittenCount := 0
    
    global TemplateIndexByID, TemplateIndexByArrayIndex
    
    for Index, Template in ImportedTemplates {
        ; 🚀 性能优化：使用索引直接查找 - O(1)
        if (TemplateIndexByID.Has(Template.ID)) {
            if (Mode = "overwrite") {
                ; 获取数组索引并覆盖
                if (TemplateIndexByArrayIndex.Has(Template.ID)) {
                    FoundIndex := TemplateIndexByArrayIndex[Template.ID]
                    PromptTemplates[FoundIndex] := Template
                    ; 更新索引
                    TemplateIndexByID[Template.ID] := Template
                    ; 更新Title索引
                    Key := Template.Category . "|" . Template.Title
                    global TemplateIndexByTitle
                    TemplateIndexByTitle[Key] := Template
                }
                OverwrittenCount++
            }
            ; 如果Mode = "skip"，跳过
        } else {
            ; 添加新模板
            PromptTemplates.Push(Template)
            ; 更新索引
            TemplateIndexByID[Template.ID] := Template
            Key := Template.Category . "|" . Template.Title
            global TemplateIndexByTitle
            TemplateIndexByTitle[Key] := Template
            TemplateIndexByArrayIndex[Template.ID] := PromptTemplates.Length
            ImportedCount++
        }
    }
    
    ; 标记分类映射需要重建
    InvalidateTemplateCache()
    
    ; 保存到文件
    SavePromptTemplates()
    
    ; 刷新模板管理标签页
    RefreshPromptsManageTab()
    
    ; 关闭对话框
    ImportGUI.Destroy()
    
    ; 显示结果
    ResultMsg := "导入完成！`n"
    if (ImportedCount > 0) {
        ResultMsg .= "新增: " . ImportedCount . " 个模板`n"
    }
    if (OverwrittenCount > 0) {
        ResultMsg .= "覆盖: " . OverwrittenCount . " 个模板`n"
    }
    if (ImportedCount = 0 && OverwrittenCount = 0) {
        ResultMsg .= "没有新模板导入（所有模板已存在）"
    }
    MsgBox(ResultMsg, "导入结果", "Iconi")
}

; 导出提示词模板
ExportPromptTemplates() {
    global PromptTemplates
    
    ; 选择保存位置
    FilePath := FileSelect("S16", A_ScriptDir, "保存模板文件", "JSON文件 (*.json)")
    if (FilePath = "") {
        return
    }
    
    ; 确保文件扩展名正确
    if (!InStr(FilePath, ".json")) {
        FilePath .= ".json"
    }
    
    try {
        ; 生成JSON内容
        JsonContent := TemplatesToJSON(PromptTemplates)
        
        ; 写入文件
        FileDelete(FilePath)
        FileAppend(JsonContent, FilePath, "UTF-8")
        
        MsgBox("模板已导出到: " . FilePath, "提示", "Iconi")
    } catch as e {
        MsgBox("导出失败: " . e.Message, "错误", "Iconx")
    }
}

; ===================== JSON处理函数 =====================
; 将模板数组转换为JSON（改进格式，支持批量导入）
TemplatesToJSON(Templates) {
    Json := "{`n  `"version`": `"1.0`",`n"
    Json .= '  `"exportTime`": `"' . FormatTime(, "yyyy-MM-dd HH:mm:ss") . '`,`n'
    Json .= '  `"count`": ' . Templates.Length . ',`n'
    Json .= '  `"templates`": [`n'
    for Index, Template in Templates {
        if (Index > 1) {
            Json .= ",`n"
        }
        Json .= "    {`n"
        Json .= '      `"id`": `"' . EscapeJSON(Template.ID) . '`,`n'
        Json .= '      `"title`": `"' . EscapeJSON(Template.Title) . '`,`n'
        Json .= '      `"content`": `"' . EscapeJSON(Template.Content) . '`,`n'
        Json .= '      `"category`": `"' . EscapeJSON(Template.Category) . '`'`n'
        Json .= "    }"
    }
    Json .= "`n  ]`n}"
    return Json
}

; JSON转义
EscapeJSON(Text) {
    ; 转义反斜杠
    Text := StrReplace(Text, "\", "\\")
    ; 转义换行
    Text := StrReplace(Text, "`n", "\n")
    Text := StrReplace(Text, "`r", "\r")
    ; 转义制表符
    Text := StrReplace(Text, "`t", "\t")
    ; 转义双引号
    Text := StrReplace(Text, '"', '\"')
    return Text
}

; 解析JSON模板（改进解析，支持多行内容和转义字符）
ParseJSONTemplates(JsonContent) {
    Templates := []
    
    ; 方法1：使用改进的正则表达式匹配（支持转义字符）
    ; 模式：{"id":"...","title":"...","content":"...","category":"..."}
    Pattern := 'i)\{\s*"id"\s*:\s*"([^"\\]*(?:\\.[^"\\]*)*)"\s*,\s*"title"\s*:\s*"([^"\\]*(?:\\.[^"\\]*)*)"\s*,\s*"content"\s*:\s*"((?:[^"\\]|\\.)*)"\s*,\s*"category"\s*:\s*"([^"\\]*(?:\\.[^"\\]*)*)"\s*\}'
    
    Pos := 1
    while (Pos := RegExMatch(JsonContent, Pattern, &Match, Pos)) {
        ; 反转义内容
        ID := UnescapeJSON(Match[1])
        Title := UnescapeJSON(Match[2])
        Content := UnescapeJSON(Match[3])
        Category := UnescapeJSON(Match[4])
        
        Templates.Push({
            ID: ID,
            Title: Title,
            Content: Content,
            Icon: "",  ; 不再使用图标
            Category: Category != "" ? Category : "自定义"
        })
        
        Pos += Match.Len
    }
    
    ; 如果方法1失败，尝试方法2：逐对象解析
    if (Templates.Length = 0) {
        ; 查找templates数组
        TemplatesStart := InStr(JsonContent, '"templates"')
        if (TemplatesStart > 0) {
            ; 从templates开始查找所有对象
            TemplatesSection := SubStr(JsonContent, TemplatesStart)
            
            ; 查找所有 { ... } 对象
            ObjectStart := 1
            while (ObjectStart := InStr(TemplatesSection, "{", false, ObjectStart)) {
                ; 找到匹配的右括号
                BraceCount := 1
                ObjectEnd := ObjectStart + 1
                while (ObjectEnd <= StrLen(TemplatesSection) && BraceCount > 0) {
                    Char := SubStr(TemplatesSection, ObjectEnd, 1)
                    if (Char = "{") {
                        BraceCount++
                    } else if (Char = "}") {
                        BraceCount--
                    }
                    ObjectEnd++
                }
                
                if (BraceCount = 0) {
                    ObjectContent := SubStr(TemplatesSection, ObjectStart, ObjectEnd - ObjectStart)
                    
                    ; 提取各个字段
                    IDPattern := 'i)"id"\s*:\s*"([^"\\]*(?:\\.[^"\\]*)*)"'
                    TitlePattern := 'i)"title"\s*:\s*"([^"\\]*(?:\\.[^"\\]*)*)"'
                    ContentPattern := 'i)"content"\s*:\s*"((?:[^"\\]|\\.)*)"'
                    CategoryPattern := 'i)"category"\s*:\s*"([^"\\]*(?:\\.[^"\\]*)*)"'
                    
                    if (RegExMatch(ObjectContent, IDPattern, &IDMatch) && 
                        RegExMatch(ObjectContent, TitlePattern, &TitleMatch) &&
                        RegExMatch(ObjectContent, ContentPattern, &ContentMatch) &&
                        RegExMatch(ObjectContent, CategoryPattern, &CategoryMatch)) {
                        
                        ID := UnescapeJSON(IDMatch[1])
                        Title := UnescapeJSON(TitleMatch[1])
                        Content := UnescapeJSON(ContentMatch[1])
                        Category := UnescapeJSON(CategoryMatch[1])
                        
                        Templates.Push({
                            ID: ID,
                            Title: Title,
                            Content: Content,
                            Icon: "",
                            Category: Category != "" ? Category : "自定义"
                        })
                    }
                }
                
                ObjectStart := ObjectEnd
            }
        }
    }
    
    return Templates
}

; JSON反转义
UnescapeJSON(Text) {
    ; 反转义双引号
    Text := StrReplace(Text, '\"', '"')
    ; 反转义换行
    Text := StrReplace(Text, "\n", "`n")
    Text := StrReplace(Text, "\r", "`r")
    ; 反转义制表符
    Text := StrReplace(Text, "\t", "`t")
    ; 反转义反斜杠
    Text := StrReplace(Text, "\\", "\")
    return Text
}

; ===================== 创建提示词模板系列 =====================
CreatePromptTemplateSeries(ConfigGUI, X, Y, W, H, Series, SeriesIndex) {
    global PromptTemplateTabControls, UI_Colors, PromptsMainTabControls
    
    ; 创建系列面板（默认隐藏）
    SeriesPanel := ConfigGUI.Add("Text", "x" . X . " y" . Y . " w" . W . " h" . H . " Background" . UI_Colors.Background . " vPromptTemplateSeries" . SeriesIndex, "")
    SeriesPanel.Visible := false
    PromptTemplateTabControls[SeriesIndex].Push(SeriesPanel)
    ; 同时添加到模板系列标签页控件列表
    PromptsMainTabControls["series"].Push(SeriesPanel)
    
    ; 创建模板按钮列表
    BtnY := Y
    BtnHeight := 35
    BtnSpacing := 10
    for Index, Template in Series.Templates {
        Btn := ConfigGUI.Add("Text", "x" . X . " y" . BtnY . " w" . W . " h" . BtnHeight . " Center 0x200 c" . UI_Colors.Text . " Background" . UI_Colors.BtnBg . " vPromptTemplateBtn" . SeriesIndex . "_" . Index, Template.Name)
        Btn.SetFont("s10", "Segoe UI")
        ; 使用闭包创建点击处理器，避免函数名冲突
        ClickHandler(*) {
            ApplyPromptTemplate(Template)
        }
        Btn.OnEvent("Click", ClickHandler)
        HoverBtnWithAnimation(Btn, UI_Colors.BtnBg, UI_Colors.BtnHover)
        Btn.Visible := false  ; 默认隐藏，由SwitchPromptTemplateTab控制显示
        PromptTemplateTabControls[SeriesIndex].Push(Btn)
        ; 添加到模板系列标签页控件列表
        PromptsMainTabControls["series"].Push(Btn)
        BtnY += BtnHeight + BtnSpacing
    }
}

; ===================== 切换提示词模板标签页 =====================
SwitchPromptTemplateTab(TabIndex) {
    global PromptTemplateTabs, PromptTemplateTabControls, UI_Colors, ThemeMode
    
    ; 重置所有标签样式
    for Index, TabBtn in PromptTemplateTabs {
        if (TabBtn) {
            try {
                TabBtn.Opt("+Background" . UI_Colors.Sidebar)
                TabBtn.SetFont("s10 c" . UI_Colors.TextDim . " Norm", "Segoe UI")
                TabBtn.Redraw()
            }
        }
    }
    
    ; 隐藏所有系列内容
    for Index, Controls in PromptTemplateTabControls {
        if (Controls && Controls.Length > 0) {
            for CtrlIndex, Ctrl in Controls {
                if (Ctrl) {
                    try {
                        Ctrl.Visible := false
                    } catch as err {
                    }
                }
            }
        }
    }
    
    ; 设置当前标签样式
    if (PromptTemplateTabs.Has(TabIndex) && PromptTemplateTabs[TabIndex]) {
        try {
            TabBtn := PromptTemplateTabs[TabIndex]
            SelectedText := (ThemeMode = "dark") ? UI_Colors.Text : "FFFFFF"  ; html.to.design 风格文本（亮色模式保持白色）
            TabBtn.Opt("+Background" . UI_Colors.BtnPrimary)
            TabBtn.SetFont("s10 c" . SelectedText . " Bold", "Segoe UI")
            TabBtn.Redraw()
        }
    }
    
    ; 显示当前系列内容
    if (PromptTemplateTabControls.Has(TabIndex)) {
        Controls := PromptTemplateTabControls[TabIndex]
        if (Controls && Controls.Length > 0) {
            for CtrlIndex, Ctrl in Controls {
                if (Ctrl) {
                    try {
                        Ctrl.Visible := true
                    } catch as err {
                    }
                }
            }
        }
    }
}

; ===================== 创建提示词模板标签点击处理器 =====================
CreatePromptTemplateTabClickHandler(TabIndex) {
    return (*) => SwitchPromptTemplateTab(TabIndex)
}

; ===================== 应用提示词模板 =====================
ApplyPromptTemplate(Template) {
    global PromptExplainEdit, PromptRefactorEdit, PromptOptimizeEdit
    
    if (!Template || !IsObject(Template)) {
        return
    }
    
    ; 应用模板到编辑框
    try {
        if (IsSet(PromptExplainEdit) && PromptExplainEdit) {
            PromptExplainEdit.Value := Template.Explain
        }
        if (IsSet(PromptRefactorEdit) && PromptRefactorEdit) {
            PromptRefactorEdit.Value := Template.Refactor
        }
        if (IsSet(PromptOptimizeEdit) && PromptOptimizeEdit) {
            PromptOptimizeEdit.Value := Template.Optimize
        }
    } catch as err {
        ; 忽略错误
    }
}

; ===================== 创建提示词标签页 =====================
CreatePromptsTab(ConfigGUI, X, Y, W, H) {
    global Prompt_Explain, Prompt_Refactor, Prompt_Optimize, PromptsTabPanel, PromptExplainEdit, PromptRefactorEdit, PromptOptimizeEdit, PromptsTabControls
    global UI_Colors, PromptTemplates
    
    ; 创建标签页面板（默认隐藏）
    PromptsTabPanel := ConfigGUI.Add("Text", "x" . X . " y" . Y . " w" . W . " h" . H . " Background" . UI_Colors.Background . " vPromptsTabPanel", "")
    PromptsTabPanel.Visible := false
    PromptsTabControls.Push(PromptsTabPanel)
    
    ; 标题
    Title := ConfigGUI.Add("Text", "x" . (X + 30) . " y" . (Y + 20) . " w" . (W - 60) . " h30 c" . UI_Colors.Text, GetText("prompt_settings"))
    Title.SetFont("s16 Bold", "Segoe UI")
    PromptsTabControls.Push(Title)
    
    ; 创建主标签页（模板系列 / 模板管理 / 传统编辑）
    MainTabBarY := Y + 60
    MainTabBarHeight := 40
    MainTabBarBg := ConfigGUI.Add("Text", "x" . (X + 30) . " y" . MainTabBarY . " w" . (W - 60) . " h" . MainTabBarHeight . " Background" . UI_Colors.Sidebar, "")
    PromptsTabControls.Push(MainTabBarBg)
    
    global PromptsMainTabs := Map()
    global PromptsMainTabControls := Map()
    MainTabWidth := (W - 60) / 3
    MainTabX := X + 30
    
    MainTabList := [
        {Key: "manage", Name: "模板管理"},
        {Key: "rules", Name: GetText("hotkey_main_tab_rules")},
        {Key: "legacy", Name: "传统编辑"}
    ]
    
    MainTabWidth := (W - 60) / MainTabList.Length
    
    for Index, TabItem in MainTabList {
        TabBtn := ConfigGUI.Add("Text", "x" . MainTabX . " y" . MainTabBarY . " w" . MainTabWidth . " h" . MainTabBarHeight . " Center 0x200 c" . UI_Colors.TextDim . " Background" . UI_Colors.Sidebar . " vPromptsMainTab" . TabItem.Key, TabItem.Name)
        TabBtn.SetFont("s10", "Segoe UI")
        TabBtn.OnEvent("Click", CreatePromptsMainTabClickHandler(TabItem.Key))
        HoverBtnWithAnimation(TabBtn, UI_Colors.Sidebar, UI_Colors.BtnHover)
        PromptsMainTabs[TabItem.Key] := TabBtn
        PromptsMainTabControls[TabItem.Key] := []
        PromptsTabControls.Push(TabBtn)
        MainTabX += MainTabWidth
    }
    
    ; 创建各主标签页的内容面板
    ContentY := MainTabBarY + MainTabBarHeight + 20
    ContentHeight := H - (ContentY - Y) - 50
    
    ; 1. 模板管理标签页（合并了模板系列功能）
    CreatePromptsManageTab(ConfigGUI, X + 30, ContentY, W - 60, ContentHeight)
    
    ; 2. Cursor规则标签页
    CreateCursorRulesTabForPrompts(ConfigGUI, X + 30, ContentY, W - 60, ContentHeight + 500)
    
    ; 3. 传统编辑标签页
    CreatePromptsLegacyTab(ConfigGUI, X + 30, ContentY, W - 60, ContentHeight)
    
    ; 在显示默认标签页之前，先隐藏rules和legacy标签页的所有控件，避免混合显示
    if (PromptsMainTabControls.Has("rules")) {
        RulesControls := PromptsMainTabControls["rules"]
        if (RulesControls && RulesControls.Length > 0) {
            for Index, Ctrl in RulesControls {
                if (Ctrl) {
                    try {
                        Ctrl.Visible := false
                    } catch as err {
                    }
                }
            }
        }
    }
    if (PromptsMainTabControls.Has("legacy")) {
        LegacyControls := PromptsMainTabControls["legacy"]
        if (LegacyControls && LegacyControls.Length > 0) {
            for Index, Ctrl in LegacyControls {
                if (Ctrl) {
                    try {
                        Ctrl.Visible := false
                    } catch as err {
                    }
                }
            }
        }
    }
    
    ; 默认显示模板管理标签页
    SwitchPromptsMainTab("manage")
}

; ===================== 切换到模板管理标签页（用于延迟调用）=====================
SwitchToManageTab(*) {
    global PromptsMainTabs
    if (PromptsMainTabs && PromptsMainTabs.Has("manage")) {
        SwitchPromptsMainTab("manage")
    }
}

SwitchToQuickActionTab(*) {
    global HotkeysMainTabs
    if (HotkeysMainTabs && HotkeysMainTabs.Has("quickaction")) {
        SwitchHotkeysMainTab("quickaction")
    }
}

; ===================== 创建提示词主标签点击处理器 =====================
CreatePromptsMainTabClickHandler(TabKey) {
    return (*) => SwitchPromptsMainTab(TabKey)
}

; ===================== 切换提示词主标签页 =====================
SwitchPromptsMainTab(TabKey) {
    global PromptsMainTabs, PromptsMainTabControls, UI_Colors, ThemeMode, PromptCategoryTabControls
    
    ; 重置所有标签样式
    for Key, TabBtn in PromptsMainTabs {
        if (TabBtn) {
            try {
                TabBtn.Opt("+Background" . UI_Colors.Sidebar)
                TabBtn.SetFont("s10 c" . UI_Colors.TextDim . " Norm", "Segoe UI")
                TabBtn.Redraw()
            }
        }
    }
    
    ; 隐藏所有标签页内容（先隐藏所有，避免交错显示）
    for Key, Controls in PromptsMainTabControls {
        if (Controls && Controls.Length > 0) {
            for Index, Ctrl in Controls {
                if (Ctrl) {
                    try {
                        Ctrl.Visible := false
                    } catch as err {
                    }
                }
            }
        }
    }
    
    ; 隐藏所有分类标签页内容（如果存在）
    if (IsSet(PromptCategoryTabControls) && IsObject(PromptCategoryTabControls)) {
        for CategoryName, Controls in PromptCategoryTabControls {
            if (Controls && Controls.Length > 0) {
                for Index, Ctrl in Controls {
                    if (Ctrl) {
                        try {
                            Ctrl.Visible := false
                        } catch as err {
                        }
                    }
                }
            }
        }
    }
    
    ; 隐藏所有Cursor规则子标签页内容（如果存在）
    global CursorRulesSubTabControls
    if (IsSet(CursorRulesSubTabControls) && IsObject(CursorRulesSubTabControls)) {
        for SubTabKey, Controls in CursorRulesSubTabControls {
            if (Controls && Controls.Length > 0) {
                for Index, Ctrl in Controls {
                    if (Ctrl) {
                        try {
                            Ctrl.Visible := false
                        } catch as err {
                        }
                    }
                }
            }
        }
    }
    
    ; 设置当前标签样式（确保所有标签按钮都可见）
    if (PromptsMainTabs && PromptsMainTabs.Count > 0) {
        for Key, TabBtn in PromptsMainTabs {
            if (TabBtn) {
                try {
                    ; 确保标签按钮可见
                    TabBtn.Visible := true
                    if (Key = TabKey) {
                        ; 当前选中的标签按钮
                        SelectedText := (ThemeMode = "dark") ? UI_Colors.Text : "FFFFFF"  ; html.to.design 风格文本（亮色模式保持白色）
                        TabBtn.Opt("+Background" . UI_Colors.BtnPrimary)
                        TabBtn.SetFont("s10 c" . SelectedText . " Bold", "Segoe UI")
                    } else {
                        ; 其他标签按钮
                        TabBtn.Opt("+Background" . UI_Colors.Sidebar)
                        TabBtn.SetFont("s10 c" . UI_Colors.TextDim . " Norm", "Segoe UI")
                    }
                    TabBtn.Redraw()
                } catch as err {
                }
            }
        }
    }
    
    ; 显示当前标签页内容
    if (PromptsMainTabControls.Has(TabKey)) {
        Controls := PromptsMainTabControls[TabKey]
        if (Controls && Controls.Length > 0) {
            for Index, Ctrl in Controls {
                if (Ctrl) {
                    try {
                        Ctrl.Visible := true
                    } catch as err {
                    }
                }
            }
        }
    }
    
    ; 如果是Cursor规则标签，显示第一个规则子标签
    if (TabKey = "rules") {
        global CursorRulesSubTabs
        if (CursorRulesSubTabs && CursorRulesSubTabs.Count > 0) {
            FirstKey := ""
            for Key, TabBtn in CursorRulesSubTabs {
                FirstKey := Key
                break
            }
            if (FirstKey != "") {
                SwitchCursorRulesSubTab(FirstKey)
            }
        }
    }
    
    ; 如果是模板管理标签页，需要重新显示分类标签和默认分类内容
    if (TabKey = "manage") {
        ; 重置展开状态
        global ExpandedTemplateKey
        ExpandedTemplateKey := ""
        
        ; 【关键修复】确保Cursor规则和传统编辑标签页的所有控件都被隐藏
        if (PromptsMainTabControls.Has("rules")) {
            RulesControls := PromptsMainTabControls["rules"]
            if (RulesControls && RulesControls.Length > 0) {
                for Index, Ctrl in RulesControls {
                    if (Ctrl) {
                        try {
                            Ctrl.Visible := false
                        } catch as err {
                        }
                    }
                }
            }
        }
        if (PromptsMainTabControls.Has("legacy")) {
            LegacyControls := PromptsMainTabControls["legacy"]
            if (LegacyControls && LegacyControls.Length > 0) {
                for Index, Ctrl in LegacyControls {
                    if (Ctrl) {
                        try {
                            Ctrl.Visible := false
                        } catch as err {
                        }
                    }
                }
            }
        }
        
        ; 显示分类标签栏
        global PromptCategoryTabs
        if (IsSet(PromptCategoryTabs) && PromptCategoryTabs.Count > 0) {
            for CategoryName, TabBtn in PromptCategoryTabs {
                if (TabBtn) {
                    try {
                        TabBtn.Visible := true
                    } catch as err {
                    }
                }
            }
        }
        
        ; 确保ListView显示在最上层（通过重新设置位置来提升Z-order）
        global PromptManagerListView, UI_Colors, ThemeMode, CurrentPromptFolder
        if (PromptManagerListView) {
            try {
                PromptManagerListView.GetPos(&ListViewX, &ListViewY, &ListViewW, &ListViewH)
                PromptManagerListView.Move(ListViewX, ListViewY, ListViewW, ListViewH)
                PromptManagerListView.Visible := true
                ; 确保背景色正确设置
                PromptManagerListView.Opt("+Background" . UI_Colors.InputBg)
                ; 强制刷新ListView
                PromptManagerListView.Redraw()
            } catch as err {
            }
        }
        
        ; 【关键修复】切换到"基础"分类标签页（如果存在）
        global PromptTemplates
        DefaultCategory := "基础"
        if (IsSet(PromptCategoryTabs) && PromptCategoryTabs.Has(DefaultCategory)) {
            ; 切换到基础分类
            SwitchPromptCategoryTab(DefaultCategory)
        } else if (IsSet(PromptCategoryTabControls) && PromptCategoryTabControls.Has(CurrentPromptFolder)) {
            ; 如果基础分类不存在，使用当前分类，但确保刷新显示
            if (IsSet(PromptTemplates) && PromptTemplates.Length > 0) {
                RefreshPromptListView()
            }
        }
    }
}

; ===================== 创建模板系列标签页 =====================
CreatePromptsSeriesTab(ConfigGUI, X, Y, W, H) {
    global PromptTemplateSeries, PromptsMainTabControls, UI_Colors, PromptsTabControls
    
    ; 创建面板
    SeriesPanel := ConfigGUI.Add("Text", "x" . X . " y" . Y . " w" . W . " h" . H . " Background" . UI_Colors.Background . " vPromptsSeriesPanel", "")
    SeriesPanel.Visible := false
    PromptsMainTabControls["series"] := []
    PromptsMainTabControls["series"].Push(SeriesPanel)
    PromptsTabControls.Push(SeriesPanel)
    
    ; 定义模板系列（每个系列作为一个标签页）
    if (!IsSet(PromptTemplateSeries) || !IsObject(PromptTemplateSeries)) {
        global PromptTemplateSeries := [
            {SeriesName: "基础系列", Templates: [
                {Name: "默认模板", Explain: "解释这段代码的核心逻辑、输入输出、关键函数作用，用新手能懂的语言，标注易错点", Refactor: "重构这段代码，遵循PEP8/行业规范，简化冗余逻辑，添加中文注释，保持功能不变", Optimize: "分析这段代码的性能瓶颈（时间/空间复杂度），给出优化方案+对比说明，保留原逻辑可读性"},
                {Name: "简洁版本", Explain: "简洁地解释这段代码做了什么", Refactor: "重构代码，使其更简洁易读", Optimize: "优化代码性能"},
                {Name: "详细版本", Explain: "请详细解释这段代码的功能、原理、设计思路和实现细节，包括每个函数的作用、参数含义、返回值说明，以及代码的整体架构", Refactor: "请重构这段代码，提高代码质量和可维护性，添加详细的文档字符串和类型注解，优化代码结构，遵循最佳实践", Optimize: "请分析这段代码的性能问题，提供详细的性能优化方案，包括算法优化、数据结构优化、缓存策略等，并说明优化前后的性能对比"}
            ]},
            {SeriesName: "专业系列", Templates: [
                {Name: "代码审查", Explain: "请对这段代码进行全面审查，指出潜在问题、bug、安全隐患和改进建议", Refactor: "请从代码审查的角度重构这段代码，修复所有发现的问题，提高代码质量和安全性", Optimize: "请从性能和可维护性角度审查代码，提供优化建议和重构方案"},
                {Name: "架构分析", Explain: "请从专业的角度分析这段代码，包括架构设计、设计模式、技术选型等方面的考量", Refactor: "请使用专业的设计模式和架构原则重构代码，提高代码的可扩展性和可维护性", Optimize: "请提供专业的性能优化方案，包括算法优化、系统设计优化、资源管理优化等方面"},
                {Name: "最佳实践", Explain: "请分析这段代码是否符合最佳实践，指出可以改进的地方", Refactor: "请按照行业最佳实践重构代码，包括命名规范、代码组织、错误处理等方面", Optimize: "请提供基于最佳实践的性能优化建议"}
            ]},
            {SeriesName: "改错系列", Templates: [
                {Name: "改错版本", Explain: "现在请你扮演一位经验丰富、以严谨著称的架构师。指出现在可能存在的风险、不足或考虑不周的地方，重新审查我们刚才制定的这个 Bug 修复方案 ，请粘贴错误代码或者截图", Refactor: "请提供三种不同的修复方案。并为每种方案说明其优点、缺点和适用场景，让我来做选择，请粘贴错误代码或者截图", Optimize: "我的代码遇到了一个典型问题：请你扮演网络搜索助手，在GitHub Issues / Stack Overflow等开源社区汇总常见的解决方案，并针对我的这个bug给出最优的修复建议。请粘贴错误代码或者截图"},
                {Name: "入门版", Explain: "请用最简单的语言解释这段代码，适合完全没有编程基础的人理解", Refactor: "请将代码重构为最基础的版本，添加大量注释，使用最简单的实现方式", Optimize: "请用通俗易懂的方式解释性能优化的概念"}
            ]}
        ]
    }
    
    ; 创建模板标签页栏
    YPos := Y + 10
    TemplateTabBarY := YPos
    TemplateTabBarHeight := 40
    TemplateTabBarBg := ConfigGUI.Add("Text", "x" . X . " y" . TemplateTabBarY . " w" . W . " h" . TemplateTabBarHeight . " Background" . UI_Colors.Sidebar, "")
    PromptsMainTabControls["series"].Push(TemplateTabBarBg)
    
    ; 创建模板标签按钮
    global PromptTemplateTabs := Map()
    global PromptTemplateTabControls := Map()
    TemplateTabWidth := W / PromptTemplateSeries.Length
    TemplateTabX := X
    
    for Index, Series in PromptTemplateSeries {
        TabBtn := ConfigGUI.Add("Text", "x" . TemplateTabX . " y" . TemplateTabBarY . " w" . TemplateTabWidth . " h" . TemplateTabBarHeight . " Center 0x200 c" . UI_Colors.TextDim . " Background" . UI_Colors.Sidebar . " vPromptTemplateTab" . Index, Series.SeriesName)
        TabBtn.SetFont("s10", "Segoe UI")
        TabBtn.OnEvent("Click", CreatePromptTemplateTabClickHandler(Index))
        HoverBtnWithAnimation(TabBtn, UI_Colors.Sidebar, UI_Colors.BtnHover)
        PromptTemplateTabs[Index] := TabBtn
        PromptTemplateTabControls[Index] := []
        PromptsMainTabControls["series"].Push(TabBtn)
        TemplateTabX += TemplateTabWidth
    }
    
    ; 创建模板内容区域
    TemplateContentY := TemplateTabBarY + TemplateTabBarHeight + 20
    TemplateContentHeight := H - (TemplateContentY - Y) - 20
    
    ; 为每个系列创建模板列表
    for Index, Series in PromptTemplateSeries {
        CreatePromptTemplateSeries(ConfigGUI, X, TemplateContentY, W, TemplateContentHeight, Series, Index)
    }
    
    ; 默认显示第一个系列
    if (PromptTemplateSeries.Length > 0) {
        SwitchPromptTemplateTab(1)
    }
}

; ===================== 创建模板管理标签页 =====================
CreatePromptsManageTab(ConfigGUI, X, Y, W, H) {
    global PromptTemplates, PromptsMainTabControls, UI_Colors, DefaultTemplateIDs, ThemeMode, PromptsTabControls
    
    ; 创建面板
    ManagePanel := ConfigGUI.Add("Text", "x" . X . " y" . Y . " w" . W . " h" . H . " Background" . UI_Colors.Background . " vPromptsManagePanel", "")
    ManagePanel.Visible := false
    PromptsMainTabControls["manage"] := []
    PromptsMainTabControls["manage"].Push(ManagePanel)
    PromptsTabControls.Push(ManagePanel)
    
    ; 确保模板已加载
    if (!IsSet(PromptTemplates) || PromptTemplates.Length = 0) {
        LoadPromptTemplates()
    }
    
    ; 只获取三个主分类：基础、改错、专业
    Categories := Map()
    CategoryOrder := ["基础", "改错", "专业"]
    
    ; 只收集这三个分类的模板
    for Index, Template in PromptTemplates {
        CategoryName := Template.Category
        ; 只处理基础、专业、改错这三个分类
        if (CategoryName = "基础" || CategoryName = "专业" || CategoryName = "改错") {
            if (!Categories.Has(CategoryName)) {
                Categories[CategoryName] := []
            }
            Categories[CategoryName].Push(Template)
        }
    }
    
    ; 创建分类标签栏
    YPos := Y + 10
    CategoryTabBarY := YPos
    CategoryTabBarHeight := 40
    CategoryTabBarBg := ConfigGUI.Add("Text", "x" . X . " y" . CategoryTabBarY . " w" . W . " h" . CategoryTabBarHeight . " Background" . UI_Colors.Sidebar, "")
    PromptsMainTabControls["manage"].Push(CategoryTabBarBg)
    PromptsTabControls.Push(CategoryTabBarBg)
    
    global PromptCategoryTabs := Map()
    global PromptCategoryTabControls := Map()
    
    ; 按固定顺序排列分类（基础、专业、改错）
    SortedCategories := []
    for CategoryName in CategoryOrder {
        if (Categories.Has(CategoryName)) {
            SortedCategories.Push(CategoryName)
        }
    }
    
    ; 创建三个标签按钮（固定宽度）
    CategoryTabWidth := W / 3
    CategoryTabX := X
    
    ; 默认选中第一个分类
    FirstCategory := ""
    
    for Index, CategoryName in CategoryOrder {
        ; 统计该分类下的模板数量
        TemplateCount := Categories.Has(CategoryName) ? Categories[CategoryName].Length : 0
        
        ; 创建标签按钮（无论是否有模板都创建）
        TabBtn := ConfigGUI.Add("Text", "x" . CategoryTabX . " y" . CategoryTabBarY . " w" . CategoryTabWidth . " h" . CategoryTabBarHeight . " Center 0x200 c" . UI_Colors.TextDim . " Background" . UI_Colors.Sidebar . " vPromptCategoryTab" . CategoryName, CategoryName . " (" . TemplateCount . ")")
        TabBtn.SetFont("s10", "Segoe UI")
        TabBtn.OnEvent("Click", CreatePromptCategoryTabClickHandler(CategoryName))
        HoverBtnWithAnimation(TabBtn, UI_Colors.Sidebar, UI_Colors.BtnHover)
        PromptCategoryTabs[CategoryName] := TabBtn
        PromptCategoryTabControls[CategoryName] := []
        PromptsMainTabControls["manage"].Push(TabBtn)
        PromptsTabControls.Push(TabBtn)
        
        ; 记录第一个分类
        if (FirstCategory = "") {
            FirstCategory := CategoryName
        }
        
        CategoryTabX += CategoryTabWidth
    }
    
    ; 默认选中基础分类（如果存在），否则选中第一个分类
    DefaultCategory := "基础"
    if (Categories.Has(DefaultCategory)) {
        SwitchPromptCategoryTab(DefaultCategory, true)
    } else if (FirstCategory != "") {
        SwitchPromptCategoryTab(FirstCategory, true)
    }
    
    ; 创建ListView文件管理器风格的显示区域
    TemplateContentY := CategoryTabBarY + CategoryTabBarHeight + 20
    ; 为底部按钮预留空间（按钮高度35 + 间距15）
    TemplateContentHeight := H - (TemplateContentY - Y) - 60
    
    ; 创建ListView用于显示文件夹和prompt
    global PromptManagerListView, ThemeMode
    ; 确保文本颜色与背景色有足够对比度
    ListViewTextColor := (ThemeMode = "dark") ? "FFFFFF" : "000000"
    ; 创建ListView，使用NoSortHdr移除列标题排序功能
    ; 添加双缓冲绘图（LVS_EX_DOUBLEBUFFER = 0x10000）以减少拖动时的视觉残留
    PromptManagerListView := ConfigGUI.Add("ListView", "x" . X . " y" . TemplateContentY . " w" . W . " h" . TemplateContentHeight . " vPromptManagerListView Background" . UI_Colors.InputBg . " c" . ListViewTextColor . " -Multi +ReadOnly +NoSortHdr +LV0x10000", ["名称", "内容"])
    PromptManagerListView.SetFont("s10 c" . ListViewTextColor, "Segoe UI")
    PromptManagerListView.OnEvent("DoubleClick", ShowTemplateActionCenterFromDoubleClick)
    PromptManagerListView.OnEvent("ContextMenu", OnPromptManagerContextMenu)
    PromptCategoryTabControls["ListView"] := [PromptManagerListView]
    PromptsMainTabControls["manage"].Push(PromptManagerListView)
    PromptsTabControls.Push(PromptManagerListView)
    
    ; 当前导航路径（用于跟踪当前查看的文件夹）
    global CurrentPromptFolder := "基础"  ; 默认显示基础分类
    
    ; 初始化显示第一个分类（基础）的模板列表
    RefreshPromptListView()
    
    ; 导入/导出按钮区域（放在底部，确保在ListView下方）
    BtnY := TemplateContentY + TemplateContentHeight + 10
    BtnWidth := 100
    BtnHeight := 35
    BtnSpacing := 15
    BtnX := X
    
    TextColor := (ThemeMode = "light") ? UI_Colors.Text : UI_Colors.Text  ; html.to.design 风格文本
    
    ; 导入模板按钮
    ImportTemplateBtn := ConfigGUI.Add("Text", "x" . BtnX . " y" . BtnY . " w" . BtnWidth . " h" . BtnHeight . " Center 0x200 c" . TextColor . " Background" . UI_Colors.BtnBg . " vImportTemplateBtn", "导入模板")
    ImportTemplateBtn.SetFont("s10", "Segoe UI")
    ImportTemplateBtn.OnEvent("Click", (*) => ImportPromptTemplates())
    HoverBtnWithAnimation(ImportTemplateBtn, UI_Colors.BtnBg, UI_Colors.BtnHover)
    PromptsMainTabControls["manage"].Push(ImportTemplateBtn)
    PromptsTabControls.Push(ImportTemplateBtn)
    
    ; 导出模板按钮
    BtnX += BtnWidth + BtnSpacing
    ExportTemplateBtn := ConfigGUI.Add("Text", "x" . BtnX . " y" . BtnY . " w" . BtnWidth . " h" . BtnHeight . " Center 0x200 c" . TextColor . " Background" . UI_Colors.BtnBg . " vExportTemplateBtn", "导出模板")
    ExportTemplateBtn.SetFont("s10", "Segoe UI")
    ExportTemplateBtn.OnEvent("Click", (*) => ExportPromptTemplates())
    HoverBtnWithAnimation(ExportTemplateBtn, UI_Colors.BtnBg, UI_Colors.BtnHover)
    PromptsMainTabControls["manage"].Push(ExportTemplateBtn)
    PromptsTabControls.Push(ExportTemplateBtn)
    
    ; 添加模板按钮
    BtnX += BtnWidth + BtnSpacing
    AddTemplateBtn := ConfigGUI.Add("Text", "x" . BtnX . " y" . BtnY . " w" . BtnWidth . " h" . BtnHeight . " Center 0x200 c" . TextColor . " Background" . UI_Colors.BtnBg . " vAddTemplateBtn", "添加模板")
    AddTemplateBtn.SetFont("s10", "Segoe UI")
    AddTemplateBtn.OnEvent("Click", (*) => AddPromptTemplate())
    HoverBtnWithAnimation(AddTemplateBtn, UI_Colors.BtnBg, UI_Colors.BtnHover)
    PromptsMainTabControls["manage"].Push(AddTemplateBtn)
    PromptsTabControls.Push(AddTemplateBtn)
}

; ===================== 创建分类标签点击处理器 =====================
CreatePromptCategoryTabClickHandler(CategoryName) {
    return (*) => SwitchPromptCategoryTab(CategoryName)
}

; ===================== 切换分类标签页 =====================
SwitchPromptCategoryTab(CategoryName, IsInit := false) {
    global PromptCategoryTabs, PromptCategoryTabControls, UI_Colors, ThemeMode, PromptTemplates, GuiID_ConfigGUI
    global CurrentPromptFolder, PromptManagerListView, PromptsMainTabControls
    
    ; 设置当前文件夹为选中的分类（直接显示该分类下的模板）
    CurrentPromptFolder := CategoryName
    
    ; 重置所有分类标签样式
    for TabCategoryName, TabBtn in PromptCategoryTabs {
        if (TabCategoryName = CategoryName) {
            ; 选中状态
            SelectedText := (ThemeMode = "dark") ? UI_Colors.Text : "FFFFFF"  ; html.to.design 风格文本（亮色模式保持白色）
            TabBtn.Opt("+Background" . UI_Colors.BtnPrimary)
            TabBtn.SetFont("s10 c" . SelectedText . " Bold", "Segoe UI")
            TabBtn.Redraw()
        } else {
            ; 未选中状态
            TabBtn.Opt("+Background" . UI_Colors.Sidebar)
            TabBtn.SetFont("s10 c" . UI_Colors.Text . " Norm", "Segoe UI")
            TabBtn.Redraw()
        }
    }
    
    ; 确保传统编辑面板被隐藏（防止遮挡ListView）
    if (PromptsMainTabControls.Has("legacy")) {
        LegacyControls := PromptsMainTabControls["legacy"]
        if (LegacyControls && LegacyControls.Length > 0) {
            for Index, Ctrl in LegacyControls {
                if (Ctrl) {
                    try {
                        Ctrl.Visible := false
                    } catch as err {
                    }
                }
            }
        }
    }
    
    ; 显示ListView并刷新
    if (PromptCategoryTabControls.Has("ListView")) {
        Controls := PromptCategoryTabControls["ListView"]
        if (Controls && Controls.Length > 0) {
            for Index, Ctrl in Controls {
                if (Ctrl) {
                    try {
                        Ctrl.Visible := true
                        ; 确保ListView在最上层，通过重新设置位置来提升Z-order
                        Ctrl.GetPos(&CtrlX, &CtrlY, &CtrlW, &CtrlH)
                        Ctrl.Move(CtrlX, CtrlY, CtrlW, CtrlH)
                    } catch as err {
                    }
                }
            }
        }
    }
    
    ; 直接操作PromptManagerListView，确保它显示在最上层
    if (PromptManagerListView) {
        try {
            PromptManagerListView.Visible := true
            PromptManagerListView.GetPos(&ListViewX, &ListViewY, &ListViewW, &ListViewH)
            PromptManagerListView.Move(ListViewX, ListViewY, ListViewW, ListViewH)
            ; 强制刷新ListView，确保背景色和内容正确显示
            PromptManagerListView.Redraw()
        } catch as err {
        }
    }
    
    ; 刷新ListView显示（显示当前分类的模板）
    RefreshPromptListView()
    
    ; 刷新后再次确保ListView可见并刷新显示
    if (PromptManagerListView) {
        try {
            PromptManagerListView.Visible := true
            PromptManagerListView.Redraw()
        } catch as err {
        }
    }
}

; ===================== 刷新模板管理器ListView =====================
RefreshPromptListView() {
    global PromptManagerListView, CurrentPromptFolder, PromptTemplates, UI_Colors, ThemeMode, WindowDragging
    
    ; 如果窗口正在拖动，跳过刷新以避免闪烁
    if (WindowDragging) {
        return
    }
    
    if (!PromptManagerListView) {
        return
    }
    
    ; 确保ListView可见
    try {
        PromptManagerListView.Visible := true
    } catch as err {
    }
    
    ; 清空列表
    try {
        PromptManagerListView.Delete()
    } catch as err {
    }
    
    ; 确定要显示的分类（如果CurrentPromptFolder为空，默认显示"基础"）
    DisplayCategory := CurrentPromptFolder != "" ? CurrentPromptFolder : "基础"
    
    ; 直接显示该分类下的所有模板（不再显示文件夹）
    try {
        for Index, Template in PromptTemplates {
            if (Template.Category = DisplayCategory) {
                ; 检查控件是否仍然有效
                if (PromptManagerListView && !PromptManagerListView.HasProp("Destroyed")) {
                    ; 生成内容预览（截取前100个字符，如果太长加省略号）
                    ContentPreview := Template.Content
                    if (StrLen(ContentPreview) > 100) {
                        ContentPreview := SubStr(ContentPreview, 1, 100) . "..."
                    }
                    ; 替换换行符为空格，以便在ListView中显示
                    ContentPreview := StrReplace(ContentPreview, "`n", " ")
                    ContentPreview := StrReplace(ContentPreview, "`r", "")
                    PromptManagerListView.Add("", Template.Title, ContentPreview)
                } else {
                    return  ; 控件已被销毁，退出
                }
            }
        }
    } catch as e {
        ; 如果控件已被销毁，忽略错误
        if (!InStr(e.Message, "destroyed") && !InStr(e.Message, "控件")) {
            ; 其他错误才抛出
            throw e
        }
    }
    
    ; 调整列宽：名称列固定宽度，内容列自适应
    ; 检查控件是否仍然有效
    if (PromptManagerListView && !PromptManagerListView.HasProp("Destroyed")) {
        try {
            PromptManagerListView.ModifyCol(1, 150)  ; 名称列固定150像素
            PromptManagerListView.ModifyCol(2, "AutoHdr")  ; 内容列自适应
        } catch as err {
            ; 如果控件已被销毁，忽略错误
            return
        }
    } else {
        return  ; 控件已被销毁，退出
    }
    
    ; ========== 修复拖动列分隔符时的黑色方块和线条问题 ==========
    ; 再次检查控件是否仍然有效
    if (!PromptManagerListView || PromptManagerListView.HasProp("Destroyed")) {
        return  ; 控件已被销毁，退出
    }
    
    try {
        LV_Hwnd := PromptManagerListView.Hwnd
        
        ; 1. 启用双缓冲绘图（减少重绘闪烁）
        ; LVM_SETEXTENDEDLISTVIEWSTYLE = 0x1036
        ; LVS_EX_DOUBLEBUFFER = 0x00010000
        CurrentStyle := DllCall("SendMessage", "Ptr", LV_Hwnd, "UInt", 0x1037, "Ptr", 0, "Ptr", 0, "UInt")  ; LVM_GETEXTENDEDLISTVIEWSTYLE
        NewStyle := CurrentStyle | 0x00010000
        DllCall("SendMessage", "Ptr", LV_Hwnd, "UInt", 0x1036, "Ptr", 0x00010000, "Ptr", NewStyle, "UInt")  ; LVM_SETEXTENDEDLISTVIEWSTYLE
        
        ; 2. 通过Header控件禁用列分隔符拖动功能（最彻底的解决方案）
        ; LVM_GETHEADER = 0x101F
        HeaderHwnd := DllCall("SendMessage", "Ptr", LV_Hwnd, "UInt", 0x101F, "Ptr", 0, "Ptr", 0, "Ptr")
        if (HeaderHwnd) {
            ; 获取第一列的HDITEM结构
            ; HDM_GETITEM = 0x120B, HDM_SETITEM = 0x120C
            ; HDITEM结构：mask, cxy, pszText, hbm, cchTextMax, fmt, lParam, iImage, iOrder
            ; fmt标志：HDF_FIXEDWIDTH = 0x0100 (固定列宽，不允许调整)
            
            ; 为HDITEM结构分配内存（64位系统需要56字节，32位需要44字节）
            HDITEMSize := A_PtrSize = 8 ? 56 : 44
            HDITEM := Buffer(HDITEMSize, 0)
            
            ; 设置mask = HDI_FORMAT (0x0004)，表示我们要修改fmt字段
            NumPut("UInt", 0x0004, HDITEM, 0)
            
            ; 获取第一列的当前格式
            DllCall("SendMessage", "Ptr", HeaderHwnd, "UInt", 0x120B, "Ptr", 0, "Ptr", HDITEM.Ptr, "UInt")  ; HDM_GETITEM
            
            ; 读取当前fmt值
            CurrentFmt := NumGet(HDITEM, A_PtrSize = 8 ? 20 : 16, "Int")
            ; 设置HDF_FIXEDWIDTH标志（0x0100），禁用列宽调整
            NewFmt := CurrentFmt | 0x0100
            NumPut("Int", NewFmt, HDITEM, A_PtrSize = 8 ? 20 : 16)
            
            ; 应用修改到第一列
            DllCall("SendMessage", "Ptr", HeaderHwnd, "UInt", 0x120C, "Ptr", 0, "Ptr", HDITEM.Ptr, "UInt")  ; HDM_SETITEM
            
            ; 对第二列也做同样处理
            DllCall("SendMessage", "Ptr", HeaderHwnd, "UInt", 0x120B, "Ptr", 1, "Ptr", HDITEM.Ptr, "UInt")  ; HDM_GETITEM
            CurrentFmt2 := NumGet(HDITEM, A_PtrSize = 8 ? 20 : 16, "Int")
            NewFmt2 := CurrentFmt2 | 0x0100
            NumPut("Int", NewFmt2, HDITEM, A_PtrSize = 8 ? 20 : 16)
            DllCall("SendMessage", "Ptr", HeaderHwnd, "UInt", 0x120C, "Ptr", 1, "Ptr", HDITEM.Ptr, "UInt")  ; HDM_SETITEM
        }
        
        ; 3. 强制刷新ListView，清除任何视觉残留
        ; InvalidateRect清除指定区域的绘制缓存
        DllCall("InvalidateRect", "Ptr", LV_Hwnd, "Ptr", 0, "Int", 1)  ; 1 = TRUE，清除整个控件
        DllCall("UpdateWindow", "Ptr", LV_Hwnd)  ; 立即重绘
        
    } catch as e {
        ; 如果API调用失败，至少确保基本功能正常
    }
    
    ; 确保ListView的背景色正确设置并强制刷新显示
    try {
        ListViewTextColor := (ThemeMode = "dark") ? "FFFFFF" : "000000"
        PromptManagerListView.Opt("+Background" . UI_Colors.InputBg)
        PromptManagerListView.Redraw()
    } catch as err {
    }
}

; ===================== DoubleClick事件处理器 =====================
ShowTemplateActionCenterFromDoubleClick(GuiCtrlObj, Info) {
    ; DoubleClick事件传递参数：GuiCtrlObj（控件对象），Info（行号）
    ShowTemplateActionCenter(Info)
}

; ===================== 显示模板操作中心 =====================
ShowTemplateActionCenter(Item) {
    global PromptManagerListView, CurrentPromptFolder, PromptTemplates, UI_Colors, ThemeMode
    
    if (!PromptManagerListView) {
        TrayTip("ListView未初始化", "错误", "Iconx 2")
        return
    }
    
    try {
        ; 如果没有传递Item参数或Item不是数字，尝试获取选中的项
        ; 注意：DoubleClick事件的第二个参数Info是行号（数字）
        if (Type(Item) != "Integer" || Item < 1) {
            Item := PromptManagerListView.GetNext()
            if (Item = 0) {
                return
            }
        }
        
        ; 确保Item是数字
        if (Type(Item) != "Integer" || Item < 1) {
            return
        }
        
        ; 获取选中项的信息
        ItemName := PromptManagerListView.GetText(Item, 1)
        ; 移除类型检查，因为现在所有项目都是模板
        
        ; 选中该项
        PromptManagerListView.Modify(Item, "Select")
        
        ; 确保必要的变量已初始化
        if (!IsSet(PromptTemplates) || !IsObject(PromptTemplates)) {
            TrayTip("模板数据未初始化", "错误", "Iconx 2")
            return
        }
        
        if (!IsSet(CurrentPromptFolder) || CurrentPromptFolder = "") {
            CurrentPromptFolder := "基础"
        }
        
        ; 🚀 性能优化：使用索引直接查找 - O(1)
        Key := CurrentPromptFolder . "|" . ItemName
        global TemplateIndexByTitle, TemplateIndexByArrayIndex
        
        if (TemplateIndexByTitle.Has(Key)) {
            TargetTemplate := TemplateIndexByTitle[Key]
            
            ; 获取数组索引
            if (TemplateIndexByArrayIndex.Has(TargetTemplate.ID)) {
                TemplateIndex := TemplateIndexByArrayIndex[TargetTemplate.ID]
            } else {
                ; 如果索引未初始化，回退到旧方法
                TemplateIndex := 0
                for Index, Template in PromptTemplates {
                    if (Template.ID = TargetTemplate.ID) {
                        TemplateIndex := Index
                        break
                    }
                }
            }
            
            ; 创建模板操作中心弹窗
            CreateTemplateActionCenter(TargetTemplate, TemplateIndex)
        } else {
            TrayTip("未找到模板: " . ItemName, "提示", "Iconx 2")
            return
        }
        
    } catch as e {
        TrayTip("打开操作中心错误: " . e.Message, "错误", "Iconx 2")
    }
}

; ===================== ListView右键菜单 =====================
OnPromptManagerContextMenu(Control, Item, IsRightClick, X, Y) {
    global PromptManagerListView, CurrentPromptFolder
    
    ; 如果没有选中项，尝试从参数获取
    if (!Item || Item < 1) {
        ; 尝试从鼠标位置获取选中项
        Item := PromptManagerListView.GetNext()
        if (Item = 0) {
            return
        }
    }
    
    try {
        ItemName := PromptManagerListView.GetText(Item, 1)
        
        ; 确保选中该项
        PromptManagerListView.Modify(Item, "Select")
        
        ; 创建右键菜单（所有项目都是模板）
        ContextMenu := Menu()
        
        ; 模板的右键菜单
        ContextMenu.Add("复制", (*) => OnPromptManagerCopy())
        ContextMenu.Add("发送到Cursor", (*) => OnPromptManagerSendToCursor())
        ContextMenu.Add()  ; 分隔线
        ContextMenu.Add("编辑", (*) => OnPromptManagerEdit())
        ContextMenu.Add("重命名", (*) => OnPromptManagerRename())
        ContextMenu.Add("移动分类", (*) => OnPromptManagerMove())
        ContextMenu.Add("删除", (*) => OnPromptManagerDelete())
        ContextMenu.Add()  ; 分隔线
        ContextMenu.Add("关闭菜单", (*) => "")
        
        ; 显示菜单
        ContextMenu.Show(X, Y)
    } catch as e {
        ; 调试信息
        TrayTip("右键菜单错误: " . e.Message, "错误", "Iconx 2")
    }
}

; ===================== 创建模板操作中心 =====================
CreateTemplateActionCenter(Template, TemplateIndex) {
    global UI_Colors, ThemeMode, PromptTemplates, SavePromptTemplates, RefreshPromptListView, CursorPath
    
    ; 创建操作中心窗口
    ActionCenterGUI := Gui("+AlwaysOnTop -Caption", "模板操作中心: " . Template.Title)
    ActionCenterGUI.BackColor := UI_Colors.Background
    ActionCenterGUI.SetFont("s10 c" . UI_Colors.Text, "Segoe UI")
    
    ; 自定义标题栏
    TitleBarHeight := 35
    TitleBar := ActionCenterGUI.Add("Text", "x0 y0 w680 h" . TitleBarHeight . " Background" . UI_Colors.TitleBar . " vActionCenterTitleBar", "模板操作中心: " . Template.Title)
    TitleBar.SetFont("s10 Bold c" . UI_Colors.Text, "Segoe UI")
    TitleBar.OnEvent("Click", (*) => PostMessage(0xA1, 2, , , ActionCenterGUI.Hwnd)) ; 拖动窗口
    
    ; 关闭按钮
    CloseBtn := ActionCenterGUI.Add("Text", "x640 y0 w40 h" . TitleBarHeight . " Center 0x200 c" . UI_Colors.Text . " Background" . UI_Colors.TitleBar . " vActionCenterCloseBtn", "✕")
    CloseBtn.SetFont("s10", "Segoe UI")
    CloseBtn.OnEvent("Click", (*) => ActionCenterGUI.Destroy())
    HoverBtnWithAnimation(CloseBtn, UI_Colors.TitleBar, "e81123")
    
    ; 标题区域
    TitleY := TitleBarHeight + 20
    TitleText := ActionCenterGUI.Add("Text", "x20 y" . TitleY . " w640 h30 c" . UI_Colors.Text, "模板: " . Template.Title)
    TitleText.SetFont("s14 Bold", "Segoe UI")
    
    ; 分类信息
    CategoryY := TitleY + 35
    CategoryText := ActionCenterGUI.Add("Text", "x20 y" . CategoryY . " w640 h25 c" . UI_Colors.TextDim, "分类: " . Template.Category)
    CategoryText.SetFont("s10", "Segoe UI")
    
    ; 内容预览区域（只读，可滚动）
    ContentY := CategoryY + 35
    ContentHeight := 280
    ContentEdit := ActionCenterGUI.Add("Edit", "x20 y" . ContentY . " w640 h" . ContentHeight . " Multi ReadOnly Background" . UI_Colors.InputBg . " c" . UI_Colors.Text . " +VScroll", Template.Content)
    ContentEdit.SetFont("s9", "Consolas")
    
    ; 按钮区域（分两行显示）
    BtnY := ContentY + ContentHeight + 20
    BtnY2 := BtnY + 45
    BtnWidth := 110
    BtnHeight := 38
    BtnSpacing := 12
    BtnStartX := 20
    TextColor := (ThemeMode = "dark") ? "FFFFFF" : "000000"
    
    ; 第一行按钮：复制、发送到Cursor、编辑
    ; 复制按钮
    CopyBtn := ActionCenterGUI.Add("Text", "x" . BtnStartX . " y" . BtnY . " w" . BtnWidth . " h" . BtnHeight . " Center 0x200 c" . TextColor . " Background" . UI_Colors.BtnBg . " vActionCenterCopyBtn", "📋 复制")
    CopyBtn.SetFont("s10", "Segoe UI")
    ; 设置颜色属性，但不调用HoverBtnWithAnimation（避免覆盖事件）
    CopyBtn.NormalColor := UI_Colors.BtnBg
    CopyBtn.HoverColor := UI_Colors.BtnHover
    CopyBtn.OnEvent("Click", CreateActionCenterCopyHandler(Template))
    
    ; 发送到Cursor按钮
    BtnStartX += BtnWidth + BtnSpacing
    SendBtn := ActionCenterGUI.Add("Text", "x" . BtnStartX . " y" . BtnY . " w" . BtnWidth . " h" . BtnHeight . " Center 0x200 c" . TextColor . " Background" . UI_Colors.BtnPrimary . " vActionCenterSendBtn", "🚀 发送到Cursor")
    SendBtn.SetFont("s10", "Segoe UI")
    SendBtn.NormalColor := UI_Colors.BtnPrimary
    SendBtn.HoverColor := UI_Colors.BtnPrimaryHover
    SendBtn.OnEvent("Click", CreateActionCenterSendHandler(ActionCenterGUI, Template))
    
    ; 编辑按钮
    BtnStartX += BtnWidth + BtnSpacing
    EditBtn := ActionCenterGUI.Add("Text", "x" . BtnStartX . " y" . BtnY . " w" . BtnWidth . " h" . BtnHeight . " Center 0x200 c" . TextColor . " Background" . UI_Colors.BtnPrimary . " vActionCenterEditBtn", "✏️ 编辑")
    EditBtn.SetFont("s10", "Segoe UI")
    EditBtn.NormalColor := UI_Colors.BtnPrimary
    EditBtn.HoverColor := UI_Colors.BtnPrimaryHover
    EditBtn.OnEvent("Click", CreateActionCenterEditHandler(ActionCenterGUI, Template))
    
    ; 重命名按钮
    BtnStartX += BtnWidth + BtnSpacing
    RenameBtn := ActionCenterGUI.Add("Text", "x" . BtnStartX . " y" . BtnY . " w" . BtnWidth . " h" . BtnHeight . " Center 0x200 c" . TextColor . " Background" . UI_Colors.BtnBg . " vActionCenterRenameBtn", "🏷️ 重命名")
    RenameBtn.SetFont("s10", "Segoe UI")
    RenameBtn.NormalColor := UI_Colors.BtnBg
    RenameBtn.HoverColor := UI_Colors.BtnHover
    RenameBtn.OnEvent("Click", CreateActionCenterRenameHandler(ActionCenterGUI, Template))
    
    ; 第二行按钮：移动分类、删除、关闭
    BtnStartX := 20
    ; 移动分类按钮
    MoveBtn := ActionCenterGUI.Add("Text", "x" . BtnStartX . " y" . BtnY2 . " w" . BtnWidth . " h" . BtnHeight . " Center 0x200 c" . TextColor . " Background" . UI_Colors.BtnBg . " vActionCenterMoveBtn", "📁 移动分类")
    MoveBtn.SetFont("s10", "Segoe UI")
    MoveBtn.NormalColor := UI_Colors.BtnBg
    MoveBtn.HoverColor := UI_Colors.BtnHover
    MoveBtn.OnEvent("Click", CreateActionCenterMoveHandler(ActionCenterGUI, Template))
    
    ; 删除按钮
    BtnStartX += BtnWidth + BtnSpacing
    DeleteBtn := ActionCenterGUI.Add("Text", "x" . BtnStartX . " y" . BtnY2 . " w" . BtnWidth . " h" . BtnHeight . " Center 0x200 c" . TextColor . " Background" . UI_Colors.BtnDanger . " vActionCenterDeleteBtn", "🗑️ 删除")
    DeleteBtn.SetFont("s10", "Segoe UI")
    DeleteBtn.NormalColor := UI_Colors.BtnDanger
    DeleteBtn.HoverColor := UI_Colors.BtnDangerHover
    DeleteBtn.OnEvent("Click", CreateActionCenterDeleteHandler(ActionCenterGUI, Template))
    
    ; 关闭按钮
    BtnStartX += BtnWidth + BtnSpacing
    CloseBtn := ActionCenterGUI.Add("Text", "x" . BtnStartX . " y" . BtnY2 . " w" . BtnWidth . " h" . BtnHeight . " Center 0x200 c" . TextColor . " Background" . UI_Colors.BtnBg . " vActionCenterCloseBtn", "❌ 关闭")
    CloseBtn.SetFont("s10", "Segoe UI")
    CloseBtn.NormalColor := UI_Colors.BtnBg
    CloseBtn.HoverColor := UI_Colors.BtnHover
    CloseBtn.OnEvent("Click", (*) => ActionCenterGUI.Destroy())
    
    ; ESC键关闭窗口
    ActionCenterGUI.OnEvent("Escape", (*) => ActionCenterGUI.Destroy())
    
    ; 显示窗口
    ActionCenterGUI.Show("w680 h" . (BtnY2 + BtnHeight + 20))
}

; ===================== 操作中心按钮处理函数 =====================
CreateActionCenterCopyHandler(Template) {
    return ActionCenterCopyHandler.Bind(Template)
}

ActionCenterCopyHandler(Template, *) {
    A_Clipboard := Template.Content
    TrayTip("已复制到剪贴板", "提示", "Iconi 1")
}

CreateActionCenterSendHandler(ActionCenterGUI, Template) {
    return ActionCenterSendHandler.Bind(ActionCenterGUI, Template)
}

ActionCenterSendHandler(ActionCenterGUI, Template, *) {
    ActionCenterGUI.Destroy()
    SendTemplateToCursorWithKey("", Template)
}

CreateActionCenterEditHandler(ActionCenterGUI, Template) {
    return ActionCenterEditHandler.Bind(ActionCenterGUI, Template)
}

ActionCenterEditHandler(ActionCenterGUI, Template, *) {
    ActionCenterGUI.Destroy()
    EditPromptTemplateDialog(Template.ID, Template)
    SetTimer(() => RefreshPromptListView(), -300)
}

CreateActionCenterRenameHandler(ActionCenterGUI, Template) {
    return ActionCenterRenameHandler.Bind(ActionCenterGUI, Template)
}

ActionCenterRenameHandler(ActionCenterGUI, Template, *) {
    OnPromptManagerRenameFromPreview(ActionCenterGUI, Template)
}

CreateActionCenterMoveHandler(ActionCenterGUI, Template) {
    return ActionCenterMoveHandler.Bind(ActionCenterGUI, Template)
}

ActionCenterMoveHandler(ActionCenterGUI, Template, *) {
    ActionCenterGUI.Destroy()
    OnPromptManagerMoveFromTemplate(Template)
}

CreateActionCenterDeleteHandler(ActionCenterGUI, Template) {
    return ActionCenterDeleteHandler.Bind(ActionCenterGUI, Template)
}

ActionCenterDeleteHandler(ActionCenterGUI, Template, *) {
    ActionCenterGUI.Destroy()
    OnPromptManagerDeleteFromTemplate(Template)
}

; ===================== 双击打开编辑窗口（保留作为备用） =====================
OnPromptManagerEditDialog() {
    global PromptManagerListView, CurrentPromptFolder, PromptTemplates, UI_Colors, ThemeMode
    
    if (!PromptManagerListView) {
        TrayTip("ListView未初始化", "错误", "Iconx 2")
        return
    }
    
    SelectedRow := PromptManagerListView.GetNext()
    if (SelectedRow = 0) {
        return
    }
    
    try {
        ItemName := PromptManagerListView.GetText(SelectedRow, 1)
        ; 移除类型检查，因为现在所有项目都是模板
        
        ; 确保必要的变量已初始化
        if (!IsSet(PromptTemplates) || !IsObject(PromptTemplates)) {
            TrayTip("模板数据未初始化", "错误", "Iconx 2")
            return
        }
        
        if (!IsSet(CurrentPromptFolder) || CurrentPromptFolder = "") {
            CurrentPromptFolder := "基础"
        }
        
        ; 🚀 性能优化：使用索引直接查找 - O(1)
        Key := CurrentPromptFolder . "|" . ItemName
        global TemplateIndexByTitle, TemplateIndexByArrayIndex
        
        if (TemplateIndexByTitle.Has(Key)) {
            TargetTemplate := TemplateIndexByTitle[Key]
            ; 获取数组索引
            if (TemplateIndexByArrayIndex.Has(TargetTemplate.ID)) {
                TemplateIndex := TemplateIndexByArrayIndex[TargetTemplate.ID]
            } else {
                TemplateIndex := 0
            }
        } else {
            TrayTip("未找到模板: " . ItemName, "提示", "Iconx 2")
            return
        }
        
        ; 创建编辑窗口
        EditDialogGUI := Gui("+AlwaysOnTop -MinimizeBox", "编辑模板: " . TargetTemplate.Title)
        EditDialogGUI.BackColor := UI_Colors.Background
        
        ; 标题
        EditDialogGUI.Add("Text", "x20 y20 w640 h30 c" . UI_Colors.Text, "模板: " . TargetTemplate.Title)
        EditDialogGUI.SetFont("s12 Bold", "Segoe UI")
        
        ; 分类信息
        EditDialogGUI.Add("Text", "x20 y55 w640 h25 c" . UI_Colors.TextDim, "分类: " . TargetTemplate.Category)
        EditDialogGUI.SetFont("s9", "Segoe UI")
        
        ; 内容显示区域（只读）
        ContentEdit := EditDialogGUI.Add("Edit", "x20 y85 w640 h350 Multi ReadOnly Background" . UI_Colors.InputBg . " c" . UI_Colors.Text, TargetTemplate.Content)
        ContentEdit.SetFont("s9", "Consolas")
        
        ; 保存模板引用到GUI对象，供按钮使用
        EditDialogGUI["Template"] := TargetTemplate
        EditDialogGUI["TemplateIndex"] := TemplateIndex
        
        ; 按钮区域（底部，分两行显示）
        BtnY := 450
        BtnY2 := BtnY + 45  ; 第二行按钮Y位置
        BtnWidth := 100
        BtnHeight := 35
        BtnSpacing := 10
        BtnStartX := 20
        TextColor := (ThemeMode = "dark") ? "FFFFFF" : "000000"
        
        ; 第一行按钮：复制、重命名、删除
        ; 复制按钮
        CopyBtn := EditDialogGUI.Add("Text", "x" . BtnStartX . " y" . BtnY . " w" . BtnWidth . " h" . BtnHeight . " Center 0x200 c" . TextColor . " Background" . UI_Colors.BtnBg . " vEditDialogCopyBtn", "复制")
        CopyBtn.SetFont("s10", "Segoe UI")
        CopyBtn.OnEvent("Click", CreateEditDialogCopyHandler(TargetTemplate))
        HoverBtnWithAnimation(CopyBtn, UI_Colors.BtnBg, UI_Colors.BtnHover)
        
        ; 重命名按钮
        BtnStartX += BtnWidth + BtnSpacing
        RenameBtn := EditDialogGUI.Add("Text", "x" . BtnStartX . " y" . BtnY . " w" . BtnWidth . " h" . BtnHeight . " Center 0x200 c" . TextColor . " Background" . UI_Colors.BtnBg . " vEditDialogRenameBtn", "重命名")
        RenameBtn.SetFont("s10", "Segoe UI")
        RenameBtn.OnEvent("Click", CreateEditDialogRenameHandler(EditDialogGUI, TargetTemplate))
        HoverBtnWithAnimation(RenameBtn, UI_Colors.BtnBg, UI_Colors.BtnHover)
        
        ; 删除按钮
        BtnStartX += BtnWidth + BtnSpacing
        DeleteBtn := EditDialogGUI.Add("Text", "x" . BtnStartX . " y" . BtnY . " w" . BtnWidth . " h" . BtnHeight . " Center 0x200 c" . TextColor . " Background" . UI_Colors.BtnDanger . " vEditDialogDeleteBtn", "删除")
        DeleteBtn.SetFont("s10", "Segoe UI")
        DeleteBtn.OnEvent("Click", CreateEditDialogDeleteHandler(EditDialogGUI, TargetTemplate))
        HoverBtnWithAnimation(DeleteBtn, UI_Colors.BtnDanger, UI_Colors.BtnDangerHover)
        
        ; 第二行按钮：发送到Cursor、移动分类、关闭
        BtnStartX := 20
        ; 发送到Cursor按钮
        SendBtn := EditDialogGUI.Add("Text", "x" . BtnStartX . " y" . BtnY2 . " w" . BtnWidth . " h" . BtnHeight . " Center 0x200 c" . TextColor . " Background" . UI_Colors.BtnPrimary . " vEditDialogSendBtn", "发送到Cursor")
        SendBtn.SetFont("s10", "Segoe UI")
        SendBtn.OnEvent("Click", CreateEditDialogSendHandler(EditDialogGUI, TargetTemplate))
        HoverBtnWithAnimation(SendBtn, UI_Colors.BtnPrimary, UI_Colors.BtnPrimaryHover)
        
        ; 移动分类按钮
        BtnStartX += BtnWidth + BtnSpacing
        MoveBtn := EditDialogGUI.Add("Text", "x" . BtnStartX . " y" . BtnY2 . " w" . BtnWidth . " h" . BtnHeight . " Center 0x200 c" . TextColor . " Background" . UI_Colors.BtnBg . " vEditDialogMoveBtn", "移动分类")
        MoveBtn.SetFont("s10", "Segoe UI")
        MoveBtn.OnEvent("Click", CreateEditDialogMoveHandler(EditDialogGUI, TargetTemplate))
        HoverBtnWithAnimation(MoveBtn, UI_Colors.BtnBg, UI_Colors.BtnHover)
        
        ; 关闭按钮
        BtnStartX += BtnWidth + BtnSpacing
        CloseBtn := EditDialogGUI.Add("Text", "x" . BtnStartX . " y" . BtnY2 . " w" . BtnWidth . " h" . BtnHeight . " Center 0x200 c" . TextColor . " Background" . UI_Colors.BtnBg . " vEditDialogCloseBtn", "关闭")
        CloseBtn.SetFont("s10", "Segoe UI")
        CloseBtn.OnEvent("Click", (*) => EditDialogGUI.Destroy())
        HoverBtnWithAnimation(CloseBtn, UI_Colors.BtnBg, UI_Colors.BtnHover)
        
        ; ESC键关闭窗口
        EditDialogGUI.OnEvent("Escape", (*) => EditDialogGUI.Destroy())
        
        ; 显示窗口（增加高度以容纳两行按钮）
        EditDialogGUI.Show("w680 h550")
    } catch as e {
        TrayTip("打开编辑窗口错误: " . e.Message, "错误", "Iconx 2")
    }
}

; ===================== 编辑窗口按钮处理函数 =====================
CreateEditDialogCopyHandler(Template) {
    return EditDialogCopyHandler.Bind(Template)
}

EditDialogCopyHandler(Template, *) {
    A_Clipboard := Template.Content
    TrayTip("已复制到剪贴板", "提示", "Iconi 1")
}

CreateEditDialogRenameHandler(EditDialogGUI, Template) {
    return EditDialogRenameHandler.Bind(EditDialogGUI, Template)
}

EditDialogRenameHandler(EditDialogGUI, Template, *) {
    OnPromptManagerRenameFromPreview(EditDialogGUI, Template)
}

CreateEditDialogDeleteHandler(EditDialogGUI, Template) {
    return EditDialogDeleteHandler.Bind(EditDialogGUI, Template)
}

EditDialogDeleteHandler(EditDialogGUI, Template, *) {
    OnPromptManagerDeleteFromTemplate(Template)
    EditDialogGUI.Destroy()
}

CreateEditDialogSendHandler(EditDialogGUI, Template) {
    return EditDialogSendHandler.Bind(EditDialogGUI, Template)
}

EditDialogSendHandler(EditDialogGUI, Template, *) {
    EditDialogGUI.Destroy()
    SendTemplateToCursorWithKey("", Template)
}

CreateEditDialogMoveHandler(EditDialogGUI, Template) {
    return EditDialogMoveHandler.Bind(EditDialogGUI, Template)
}

EditDialogMoveHandler(EditDialogGUI, Template, *) {
    OnPromptManagerMoveFromTemplate(Template)
    EditDialogGUI.Destroy()
}

; ===================== 预览模板 =====================
OnPromptManagerPreview() {
    global PromptManagerListView, CurrentPromptFolder, PromptTemplates, UI_Colors
    
    SelectedRow := PromptManagerListView.GetNext()
    if (SelectedRow = 0) {
        return
    }
    
    try {
        ItemName := PromptManagerListView.GetText(SelectedRow, 1)
        ; 移除类型检查，因为现在所有项目都是模板
        
        ; 🚀 性能优化：使用索引直接查找 - O(1)
        Key := CurrentPromptFolder . "|" . ItemName
        global TemplateIndexByTitle, TemplateIndexByArrayIndex
        
        if (TemplateIndexByTitle.Has(Key)) {
            Template := TemplateIndexByTitle[Key]
            ; 获取数组索引
            if (TemplateIndexByArrayIndex.Has(Template.ID)) {
                Index := TemplateIndexByArrayIndex[Template.ID]
            } else {
                Index := 0
            }
            
            ; 显示预览窗口
            PreviewGUI := Gui("+AlwaysOnTop -MinimizeBox", "预览: " . Template.Title)
            PreviewGUI.BackColor := UI_Colors.Background
            
            ; 标题
            PreviewGUI.Add("Text", "x20 y20 w600 h30 c" . UI_Colors.Text, "模板: " . Template.Title)
            PreviewGUI.SetFont("s12 Bold", "Segoe UI")
            
            ; 分类信息
            PreviewGUI.Add("Text", "x20 y55 w600 h25 c" . UI_Colors.TextDim, "分类: " . Template.Category)
            PreviewGUI.SetFont("s9", "Segoe UI")
            
            ; 内容预览
            PreviewEdit := PreviewGUI.Add("Edit", "x20 y85 w600 h400 Multi ReadOnly Background" . UI_Colors.InputBg . " c" . UI_Colors.Text, Template.Content)
            PreviewEdit.SetFont("s9", "Consolas")
            
            ; 注释掉不支持的属性保存方式（AHK v2 GUI对象不支持直接索引赋值）
            ; PreviewGUI["Template"] := Template
            ; PreviewGUI["TemplateIndex"] := Index
            
            ; 按钮区域（底部）
            BtnY := 500
            BtnWidth := 90
            BtnHeight := 35
            BtnSpacing := 10
            BtnStartX := 20
            TextColor := (ThemeMode = "dark") ? "FFFFFF" : "000000"
            
            ; 复制按钮
            CopyBtn := PreviewGUI.Add("Text", "x" . BtnStartX . " y" . BtnY . " w" . BtnWidth . " h" . BtnHeight . " Center 0x200 c" . TextColor . " Background" . UI_Colors.BtnBg . " vPreviewCopyBtn", "复制")
            CopyBtn.SetFont("s10", "Segoe UI")
            CopyBtn.OnEvent("Click", CreatePreviewCopyHandler(PreviewGUI, Template))
            HoverBtnWithAnimation(CopyBtn, UI_Colors.BtnBg, UI_Colors.BtnHover)
            
            ; 编辑按钮
            BtnStartX += BtnWidth + BtnSpacing
            EditBtn := PreviewGUI.Add("Text", "x" . BtnStartX . " y" . BtnY . " w" . BtnWidth . " h" . BtnHeight . " Center 0x200 c" . TextColor . " Background" . UI_Colors.BtnPrimary . " vPreviewEditBtn", "编辑")
            EditBtn.SetFont("s10", "Segoe UI")
            EditBtn.OnEvent("Click", CreatePreviewEditHandler(PreviewGUI, Template))
            HoverBtnWithAnimation(EditBtn, UI_Colors.BtnPrimary, UI_Colors.BtnPrimaryHover)
            
            ; 重命名按钮
            BtnStartX += BtnWidth + BtnSpacing
            RenameBtn := PreviewGUI.Add("Text", "x" . BtnStartX . " y" . BtnY . " w" . BtnWidth . " h" . BtnHeight . " Center 0x200 c" . TextColor . " Background" . UI_Colors.BtnBg . " vPreviewRenameBtn", "重命名")
            RenameBtn.SetFont("s10", "Segoe UI")
            RenameBtn.OnEvent("Click", CreatePreviewRenameHandler(PreviewGUI, Template))
            HoverBtnWithAnimation(RenameBtn, UI_Colors.BtnBg, UI_Colors.BtnHover)
            
            ; 发送到Cursor按钮
            BtnStartX += BtnWidth + BtnSpacing
            SendBtn := PreviewGUI.Add("Text", "x" . BtnStartX . " y" . BtnY . " w" . BtnWidth . " h" . BtnHeight . " Center 0x200 c" . TextColor . " Background" . UI_Colors.BtnPrimary . " vPreviewSendBtn", "发送")
            SendBtn.SetFont("s10", "Segoe UI")
            SendBtn.OnEvent("Click", CreatePreviewSendHandler(PreviewGUI, Template))
            HoverBtnWithAnimation(SendBtn, UI_Colors.BtnPrimary, UI_Colors.BtnPrimaryHover)
            
            ; 移动分类按钮
            BtnStartX += BtnWidth + BtnSpacing
            MoveBtn := PreviewGUI.Add("Text", "x" . BtnStartX . " y" . BtnY . " w" . BtnWidth . " h" . BtnHeight . " Center 0x200 c" . TextColor . " Background" . UI_Colors.BtnBg . " vPreviewMoveBtn", "移动")
            MoveBtn.SetFont("s10", "Segoe UI")
            MoveBtn.OnEvent("Click", CreatePreviewMoveHandler(PreviewGUI, Template))
            HoverBtnWithAnimation(MoveBtn, UI_Colors.BtnBg, UI_Colors.BtnHover)
            
            ; 删除按钮
            BtnStartX += BtnWidth + BtnSpacing
            DeleteBtn := PreviewGUI.Add("Text", "x" . BtnStartX . " y" . BtnY . " w" . BtnWidth . " h" . BtnHeight . " Center 0x200 c" . TextColor . " Background" . UI_Colors.BtnDanger . " vPreviewDeleteBtn", "删除")
            DeleteBtn.SetFont("s10", "Segoe UI")
            DeleteBtn.OnEvent("Click", CreatePreviewDeleteHandler(PreviewGUI, Template))
            HoverBtnWithAnimation(DeleteBtn, UI_Colors.BtnDanger, UI_Colors.BtnDangerHover)
            
            ; 关闭按钮
            BtnStartX += BtnWidth + BtnSpacing
            CloseBtn := PreviewGUI.Add("Text", "x" . BtnStartX . " y" . BtnY . " w" . BtnWidth . " h" . BtnHeight . " Center 0x200 c" . TextColor . " Background" . UI_Colors.BtnBg . " vPreviewCloseBtn", "关闭")
            CloseBtn.SetFont("s10", "Segoe UI")
            CloseBtn.OnEvent("Click", (*) => PreviewGUI.Destroy())
            HoverBtnWithAnimation(CloseBtn, UI_Colors.BtnBg, UI_Colors.BtnHover)
            
            ; ESC键关闭窗口
            PreviewGUI.OnEvent("Escape", (*) => PreviewGUI.Destroy())
            
            PreviewGUI.Show("w640 h550")
            return
        }
    } catch as err {
    }
}

; ===================== 发送到Cursor =====================
OnPromptManagerSendToCursor() {
    global PromptManagerListView, CurrentPromptFolder, PromptTemplates
    
    SelectedRow := PromptManagerListView.GetNext()
    if (SelectedRow = 0) {
        return
    }
    
    try {
        ItemName := PromptManagerListView.GetText(SelectedRow, 1)
        ; 移除类型检查，因为现在所有项目都是模板
        
        ; 找到对应的模板
        for Index, Template in PromptTemplates {
            if (Template.Category = CurrentPromptFolder && Template.Title = ItemName) {
                SendTemplateToCursorWithKey("", Template)
                return
            }
        }
    } catch as err {
    }
}

; ===================== 复制模板 =====================
OnPromptManagerCopy() {
    global PromptManagerListView, CurrentPromptFolder, PromptTemplates
    
    SelectedRow := PromptManagerListView.GetNext()
    if (SelectedRow = 0) {
        return
    }
    
    try {
        ItemName := PromptManagerListView.GetText(SelectedRow, 1)
        
        ; 🚀 性能优化：使用索引直接查找 - O(1)
        Key := CurrentPromptFolder . "|" . ItemName
        global TemplateIndexByTitle
        if (TemplateIndexByTitle.Has(Key)) {
            Template := TemplateIndexByTitle[Key]
            A_Clipboard := Template.Content
            TrayTip("已复制", "提示", "Iconi 1")
            return
        }
    } catch as err {
    }
}

; ===================== 编辑模板 =====================
OnPromptManagerEdit() {
    global PromptManagerListView, CurrentPromptFolder, PromptTemplates
    
    SelectedRow := PromptManagerListView.GetNext()
    if (SelectedRow = 0) {
        return
    }
    
    try {
        ItemName := PromptManagerListView.GetText(SelectedRow, 1)
        
        ; 🚀 性能优化：使用索引直接查找 - O(1)
        Key := CurrentPromptFolder . "|" . ItemName
        global TemplateIndexByTitle
        if (TemplateIndexByTitle.Has(Key)) {
            Template := TemplateIndexByTitle[Key]
            EditPromptTemplateDialog(Template.ID, Template)
            ; 使用SetTimer延迟刷新，确保编辑对话框已关闭
            SetTimer(() => RefreshPromptListView(), -300)
            return
        }
    } catch as err {
    }
}

; ===================== 移动模板 =====================
OnPromptManagerMove() {
    global PromptManagerListView, CurrentPromptFolder, PromptTemplates, SavePromptTemplates
    
    SelectedRow := PromptManagerListView.GetNext()
    if (SelectedRow = 0) {
        return
    }
    
    try {
        ItemName := PromptManagerListView.GetText(SelectedRow, 1)
        
        ; 找到对应的模板
        TargetTemplate := ""
        TemplateIndex := 0
        for Index, Template in PromptTemplates {
            if (Template.Category = CurrentPromptFolder && Template.Title = ItemName) {
                TargetTemplate := Template
                TemplateIndex := Index
                break
            }
        }
        
        if (!TargetTemplate) {
            return
        }
        
        ; 显示移动对话框，选择目标文件夹
        global UI_Colors, ThemeMode
        MoveGUI := Gui("+AlwaysOnTop -Caption", "移动到")
        MoveGUI.BackColor := UI_Colors.Background
        MoveGUI.SetFont("s10 c" . UI_Colors.Text, "Segoe UI")
        
        ; 自定义标题栏
        TitleBarHeight := 35
        TitleBar := MoveGUI.Add("Text", "x0 y0 w340 h" . TitleBarHeight . " Background" . UI_Colors.TitleBar . " vMoveTitleBar", "移动到")
        TitleBar.SetFont("s10 Bold c" . UI_Colors.Text, "Segoe UI")
        TitleBar.OnEvent("Click", (*) => PostMessage(0xA1, 2, , , MoveGUI.Hwnd)) ; 拖动窗口
        
        ; 关闭按钮
        CloseBtn := MoveGUI.Add("Text", "x300 y0 w40 h" . TitleBarHeight . " Center 0x200 c" . UI_Colors.Text . " Background" . UI_Colors.TitleBar . " vMoveCloseBtn", "✕")
        CloseBtn.SetFont("s10", "Segoe UI")
        CloseBtn.OnEvent("Click", (*) => MoveGUI.Destroy())
        HoverBtnWithAnimation(CloseBtn, UI_Colors.TitleBar, "e81123")
        
        ; 调整Y位置，为标题栏留出空间
        MoveGUI.Add("Text", "x20 y" . (TitleBarHeight + 10) . " w300 h25 c" . UI_Colors.Text, "选择目标分类：")
        
        ; 从PromptTemplates中获取所有唯一的分类名称（排除"教学"分类）
        CategorySet := Map()
        for Index, T in PromptTemplates {
            ; 直接访问Category属性（与RefreshPromptListView保持一致）
            ; 排除"教学"分类（已改为"改错"）
            if (IsObject(T) && T.Category != "" && T.Category != "教学") {
                CategorySet[T.Category] := true
            }
        }
        
        ; 将Map的键转换为数组，并按字母顺序排序
        CategoryOrder := []
        for CategoryName, _ in CategorySet {
            CategoryOrder.Push(CategoryName)
        }
        
        ; 使用自定义排序函数对数组进行排序
        if (CategoryOrder.Length > 1) {
            ; 使用冒泡排序，使用StrCompare进行字符串比较
            Loop CategoryOrder.Length - 1 {
                i := A_Index
                Loop CategoryOrder.Length - i {
                    j := A_Index + i
                    ; 使用StrCompare进行字符串比较（返回-1, 0, 1）
                    if (StrCompare(CategoryOrder[i], CategoryOrder[j]) > 0) {
                        temp := CategoryOrder[i]
                        CategoryOrder[i] := CategoryOrder[j]
                        CategoryOrder[j] := temp
                    }
                }
            }
        }
        
        ; 如果没有找到任何分类，使用默认分类
        if (CategoryOrder.Length = 0) {
            CategoryOrder := ["基础", "改错", "专业"]
        }
        
        ; 调整Y位置，为标题栏留出空间
        LabelY := TitleBarHeight + 40
        MoveGUI.Add("Text", "x20 y" . LabelY . " w300 h25 c" . UI_Colors.Text, "分类：")
        ; 使用ListBox替代DDL，以便显示更多选项
        ; 计算ListBox高度（每项25像素，最多显示8项，最少100像素）
        ListBoxHeight := Min(Max(CategoryOrder.Length * 25 + 10, 100), 210)
        ListBoxY := LabelY + 25
        CategoryListBox := MoveGUI.Add("ListBox", "x20 y" . ListBoxY . " w300 h" . ListBoxHeight . " Background" . UI_Colors.InputBg . " c" . UI_Colors.Text . " vCategoryDDL", CategoryOrder)
        CategoryListBox.SetFont("s10 c" . UI_Colors.Text, "Segoe UI")
        
        ; 获取ListBox的句柄并保存，用于WM_CTLCOLORLISTBOX消息处理
        ListBoxHwnd := CategoryListBox.Hwnd
        MoveGUI["ListBoxHwnd"] := ListBoxHwnd
        
        ; 创建画刷用于ListBox背景色（InputBg颜色）
        ColorCode := "0x" . UI_Colors.InputBg
        RGBColor := Integer(ColorCode)
        R := (RGBColor & 0xFF0000) >> 16
        G := (RGBColor & 0x00FF00) >> 8
        B := RGBColor & 0x0000FF
        BGRColor := (B << 16) | (G << 8) | R
        ; 保存ListBox句柄和画刷到全局变量，供WM_CTLCOLORLISTBOX使用
        global MoveGUIListBoxHwnd, MoveGUIListBoxBrush
        MoveGUIListBoxHwnd := ListBoxHwnd
        ListBoxBrush := DllCall("gdi32.dll\CreateSolidBrush", "UInt", BGRColor, "Ptr")
        MoveGUIListBoxBrush := ListBoxBrush
        
        ; 在窗口关闭时清理资源
        MoveGUI.OnEvent("Close", CleanupMoveGUIListBox)
        
        ; 设置当前文件夹为默认选项
        for Index, Cat in CategoryOrder {
            if (Cat = CurrentPromptFolder) {
                CategoryListBox.Value := Index
                break
            }
        }
        
        ; 计算按钮Y位置（ListBox下方20像素）
        BtnY := ListBoxY + ListBoxHeight + 20
        TextColor := (ThemeMode = "light") ? UI_Colors.Text : UI_Colors.Text  ; html.to.design 风格文本
        OkBtn := MoveGUI.Add("Text", "x120 y" . BtnY . " w80 h35 Center 0x200 c" . TextColor . " Background" . UI_Colors.BtnPrimary . " vMoveOkBtn", "确定")
        OkBtn.SetFont("s10", "Segoe UI")
        OkBtn.OnEvent("Click", CreateMoveTemplateConfirmHandler(MoveGUI, TargetTemplate, TemplateIndex))
        HoverBtnWithAnimation(OkBtn, UI_Colors.BtnPrimary, UI_Colors.BtnPrimaryHover)
        
        CancelBtn := MoveGUI.Add("Text", "x210 y" . BtnY . " w80 h35 Center 0x200 c" . TextColor . " Background" . UI_Colors.BtnBg . " vMoveCancelBtn", "取消")
        CancelBtn.SetFont("s10", "Segoe UI")
        CancelBtn.OnEvent("Click", CreateMoveCancelHandler(MoveGUI))
        HoverBtnWithAnimation(CancelBtn, UI_Colors.BtnBg, UI_Colors.BtnHover)
        
        ; ESC键关闭窗口
        MoveGUI.OnEvent("Escape", (*) => MoveGUI.Destroy())
        
        ; 计算窗口高度（加上标题栏高度）
        WindowHeight := BtnY + 50 + TitleBarHeight
        MoveGUI.Show("w340 h" . WindowHeight)
    } catch as err {
    }
}

; ===================== 清理移动分类弹窗的ListBox资源 =====================
CleanupMoveGUIListBox(*) {
    global MoveGUIListBoxHwnd, MoveGUIListBoxBrush
    try {
        if (MoveGUIListBoxBrush != 0) {
            DllCall("gdi32.dll\DeleteObject", "Ptr", MoveGUIListBoxBrush)
            MoveGUIListBoxBrush := 0
        }
        MoveGUIListBoxHwnd := 0
    } catch as err {
    }
}

; ===================== 清理从模板移动弹窗的ListBox资源 =====================
CleanupMoveFromTemplateListBox(*) {
    global MoveFromTemplateListBoxHwnd, MoveFromTemplateListBoxBrush
    try {
        if (MoveFromTemplateListBoxBrush != 0) {
            DllCall("gdi32.dll\DeleteObject", "Ptr", MoveFromTemplateListBoxBrush)
            MoveFromTemplateListBoxBrush := 0
        }
        MoveFromTemplateListBoxHwnd := 0
    } catch as err {
    }
}

; ===================== 创建移动分类弹窗取消按钮处理器 =====================
CreateMoveCancelHandler(MoveGUI) {
    return MoveCancelHandler.Bind(MoveGUI)
}

MoveCancelHandler(MoveGUI, *) {
    CleanupMoveGUIListBox()
    MoveGUI.Destroy()
}

; ===================== 创建从模板移动弹窗取消按钮处理器 =====================
CreateMoveFromTemplateCancelHandler(MoveGUI) {
    return MoveFromTemplateCancelHandler.Bind(MoveGUI)
}

MoveFromTemplateCancelHandler(MoveGUI, *) {
    CleanupMoveFromTemplateListBox()
    MoveGUI.Destroy()
}

; ===================== 创建移动模板确认处理器 =====================
CreateMoveTemplateConfirmHandler(MoveGUI, TargetTemplate, TemplateIndex) {
    return MoveTemplateConfirmHandler.Bind(MoveGUI, TargetTemplate, TemplateIndex)
}

MoveTemplateConfirmHandler(MoveGUI, TargetTemplate, TemplateIndex, *) {
    global PromptTemplates, SavePromptTemplates, RefreshPromptListView, TemplateIndexByTitle, TemplateIndexByArrayIndex
    global MoveGUIListBoxHwnd, MoveGUIListBoxBrush
    
    try {
        CategoryDDL := MoveGUI["CategoryDDL"]
        NewCategory := CategoryDDL.Text
        
        ; 🚀 性能优化：更新模板的分类并更新索引
        if (TemplateIndex > 0 && TemplateIndex <= PromptTemplates.Length && TargetTemplate) {
            OldCategory := TargetTemplate.Category
            TargetTemplate.Category := NewCategory
            PromptTemplates[TemplateIndex].Category := NewCategory
            
            ; 更新索引
            OldKey := OldCategory . "|" . TargetTemplate.Title
            NewKey := NewCategory . "|" . TargetTemplate.Title
            if (TemplateIndexByTitle.Has(OldKey)) {
                TemplateIndexByTitle.Delete(OldKey)
            }
            TemplateIndexByTitle[NewKey] := TargetTemplate
            
            ; 标记分类映射需要重建
            InvalidateTemplateCache()
            
            SavePromptTemplates()
            RefreshPromptListView()
        }
        
        ; 清理画刷和句柄
        try {
            if (MoveGUIListBoxBrush != 0) {
                DllCall("gdi32.dll\DeleteObject", "Ptr", MoveGUIListBoxBrush)
                MoveGUIListBoxBrush := 0
            }
            MoveGUIListBoxHwnd := 0
        } catch as err {
        }
        
        MoveGUI.Destroy()
        TrayTip("已移动", "提示", "Iconi 1")
    } catch as err {
    }
}

; ===================== 预览窗口按钮处理函数 =====================
CreatePreviewCopyHandler(PreviewGUI, Template) {
    return PreviewCopyHandler.Bind(Template)
}

PreviewCopyHandler(Template, *) {
    A_Clipboard := Template.Content
    TrayTip("已复制到剪贴板", "提示", "Iconi 1")
}

CreatePreviewEditHandler(PreviewGUI, Template) {
    return PreviewEditHandler.Bind(PreviewGUI, Template)
}

PreviewEditHandler(PreviewGUI, Template, *) {
    PreviewGUI.Destroy()
    EditPromptTemplateDialog(Template.ID, Template)
    SetTimer(RefreshPromptListView, -300)
}

CreatePreviewRenameHandler(PreviewGUI, Template) {
    return PreviewRenameHandler.Bind(PreviewGUI, Template)
}

PreviewRenameHandler(PreviewGUI, Template, *) {
    OnPromptManagerRenameFromPreview(PreviewGUI, Template)
}

CreatePreviewSendHandler(PreviewGUI, Template) {
    return PreviewSendHandler.Bind(PreviewGUI, Template)
}

PreviewSendHandler(PreviewGUI, Template, *) {
    PreviewGUI.Destroy()
    SendTemplateToCursorWithKey("", Template)
}

CreatePreviewMoveHandler(PreviewGUI, Template) {
    return PreviewMoveHandler.Bind(PreviewGUI, Template)
}

PreviewMoveHandler(PreviewGUI, Template, *) {
    PreviewGUI.Destroy()
    OnPromptManagerMoveFromTemplate(Template)
}

CreatePreviewDeleteHandler(PreviewGUI, Template) {
    return PreviewDeleteHandler.Bind(PreviewGUI, Template)
}

PreviewDeleteHandler(PreviewGUI, Template, *) {
    PreviewGUI.Destroy()
    OnPromptManagerDeleteFromTemplate(Template)
}

; ===================== 从预览窗口重命名 =====================
OnPromptManagerRenameFromPreview(PreviewGUI, Template) {
    global PromptTemplates, SavePromptTemplates, UI_Colors, ThemeMode
    
    ; 创建重命名对话框
    RenameGUI := Gui("+AlwaysOnTop -Caption", "重命名模板")
    RenameGUI.BackColor := UI_Colors.Background
    RenameGUI.SetFont("s10 c" . UI_Colors.Text, "Segoe UI")
    
    ; 自定义标题栏
    TitleBarHeight := 35
    TitleBar := RenameGUI.Add("Text", "x0 y0 w340 h" . TitleBarHeight . " Background" . UI_Colors.TitleBar . " vRenameTitleBar", "重命名模板")
    TitleBar.SetFont("s10 Bold c" . UI_Colors.Text, "Segoe UI")
    TitleBar.OnEvent("Click", (*) => PostMessage(0xA1, 2, , , RenameGUI.Hwnd)) ; 拖动窗口
    
    ; 关闭按钮
    CloseBtn := RenameGUI.Add("Text", "x300 y0 w40 h" . TitleBarHeight . " Center 0x200 c" . UI_Colors.Text . " Background" . UI_Colors.TitleBar . " vRenameCloseBtn", "✕")
    CloseBtn.SetFont("s10", "Segoe UI")
    CloseBtn.OnEvent("Click", (*) => RenameGUI.Destroy())
    HoverBtnWithAnimation(CloseBtn, UI_Colors.TitleBar, "e81123")
    
    ; 调整Y位置，为标题栏留出空间
    RenameGUI.Add("Text", "x20 y" . (TitleBarHeight + 10) . " w300 h25 c" . UI_Colors.Text, "新名称:")
    EditY := TitleBarHeight + 40
    NameEdit := RenameGUI.Add("Edit", "x20 y" . EditY . " w300 h30 vNewName Background" . UI_Colors.InputBg . " c" . UI_Colors.Text, Template.Title)
    NameEdit.SetFont("s10", "Segoe UI")
    
    TextColor := (ThemeMode = "light") ? UI_Colors.Text : UI_Colors.Text  ; html.to.design 风格文本
    BtnY := TitleBarHeight + 80
    OkBtn := RenameGUI.Add("Text", "x80 y" . BtnY . " w80 h35 Center 0x200 c" . TextColor . " Background" . UI_Colors.BtnPrimary . " vRenameOkBtn", "确定")
    OkBtn.SetFont("s10", "Segoe UI")
    OkBtn.NormalColor := UI_Colors.BtnPrimary
    OkBtn.HoverColor := UI_Colors.BtnPrimaryHover
    OkBtn.OnEvent("Click", CreateRenameConfirmHandler(RenameGUI, Template))
    HoverBtnWithAnimation(OkBtn, UI_Colors.BtnPrimary, UI_Colors.BtnPrimaryHover)
    
    CancelBtn := RenameGUI.Add("Text", "x180 y" . BtnY . " w80 h35 Center 0x200 c" . TextColor . " Background" . UI_Colors.BtnBg . " vRenameCancelBtn", "取消")
    CancelBtn.SetFont("s10", "Segoe UI")
    CancelBtn.NormalColor := UI_Colors.BtnBg
    CancelBtn.HoverColor := UI_Colors.BtnHover
    CancelBtn.OnEvent("Click", (*) => RenameGUI.Destroy())
    HoverBtnWithAnimation(CancelBtn, UI_Colors.BtnBg, UI_Colors.BtnHover)
    
    ; ESC键关闭窗口
    RenameGUI.OnEvent("Escape", (*) => RenameGUI.Destroy())
    
    RenameGUI.Show("w340 h" . (BtnY + 50))
}

CreateRenameConfirmHandler(RenameGUI, Template) {
    return RenameConfirmHandler.Bind(RenameGUI, Template)
}

RenameConfirmHandler(RenameGUI, Template, *) {
    global PromptTemplates, SavePromptTemplates, TemplateIndexByTitle
    
    NewName := RenameGUI["NewName"].Value
    if (NewName = "" || NewName = Template.Title) {
        RenameGUI.Destroy()
        return
    }
    
    ; 🚀 性能优化：使用索引检查名称是否重复 - O(1)
    Key := Template.Category . "|" . NewName
    if (TemplateIndexByTitle.Has(Key)) {
        ExistingTemplate := TemplateIndexByTitle[Key]
        if (ExistingTemplate.ID != Template.ID) {
            MsgBox("该分类下已存在同名模板", "提示", "Iconx")
            return
        }
    }
    
    ; 更新模板名称
    OldTitle := Template.Title
    Template.Title := NewName
    
    ; 🚀 性能优化：更新索引
    OldKey := Template.Category . "|" . OldTitle
    if (TemplateIndexByTitle.Has(OldKey)) {
        TemplateIndexByTitle.Delete(OldKey)
    }
    TemplateIndexByTitle[Key] := Template
    
    ; 标记分类映射需要重建
    InvalidateTemplateCache()
    
    SavePromptTemplates()
    RefreshPromptListView()
    RenameGUI.Destroy()
    TrayTip("已重命名", "提示", "Iconi 1")
}

; ===================== 从预览窗口编辑 =====================
OnPromptManagerEditFromPreview(PreviewGUI, Template) {
    ; 如果提供了GUI，先关闭它
    if (PreviewGUI != 0 && PreviewGUI) {
        try {
            PreviewGUI.Destroy()
        } catch as err {
        }
    }
    
    ; 打开编辑对话框
    EditPromptTemplateDialog(Template.ID, Template)
    
    ; 延迟刷新列表，确保编辑对话框已关闭
    SetTimer(() => RefreshPromptListView(), -300)
}

; ===================== 从模板对象执行移动 =====================
OnPromptManagerMoveFromTemplate(Template) {
    global PromptTemplates, SavePromptTemplates, CurrentPromptFolder, UI_Colors, ThemeMode
    
    ; 显示移动对话框，选择目标文件夹
    MoveGUI := Gui("+AlwaysOnTop -Caption", "移动到")
    MoveGUI.BackColor := UI_Colors.Background
    MoveGUI.SetFont("s10 c" . UI_Colors.Text, "Segoe UI")
    
    ; 自定义标题栏
    TitleBarHeight := 35
    TitleBar := MoveGUI.Add("Text", "x0 y0 w340 h" . TitleBarHeight . " Background" . UI_Colors.TitleBar . " vMoveFromTemplateTitleBar", "移动到")
    TitleBar.SetFont("s10 Bold c" . UI_Colors.Text, "Segoe UI")
    TitleBar.OnEvent("Click", (*) => PostMessage(0xA1, 2, , , MoveGUI.Hwnd)) ; 拖动窗口
    
    ; 关闭按钮
    CloseBtn := MoveGUI.Add("Text", "x300 y0 w40 h" . TitleBarHeight . " Center 0x200 c" . UI_Colors.Text . " Background" . UI_Colors.TitleBar . " vMoveFromTemplateCloseBtn", "✕")
    CloseBtn.SetFont("s10", "Segoe UI")
    CloseBtn.OnEvent("Click", (*) => MoveGUI.Destroy())
    HoverBtnWithAnimation(CloseBtn, UI_Colors.TitleBar, "e81123")
    
    ; 从PromptTemplates中获取所有唯一的分类名称（排除"教学"分类）
    CategorySet := Map()
    for Index, T in PromptTemplates {
        ; 直接访问Category属性（与RefreshPromptListView保持一致）
        ; 排除"教学"分类（已改为"改错"）
        if (IsObject(T) && T.Category != "" && T.Category != "教学") {
            CategorySet[T.Category] := true
        }
    }
    
    ; 将Map的键转换为数组，并按字母顺序排序
    CategoryOrder := []
    for CategoryName, _ in CategorySet {
        CategoryOrder.Push(CategoryName)
    }
    
    ; 使用自定义排序函数对数组进行排序
    if (CategoryOrder.Length > 1) {
        ; 使用冒泡排序，使用StrCompare进行字符串比较
        Loop CategoryOrder.Length - 1 {
            i := A_Index
            Loop CategoryOrder.Length - i {
                j := A_Index + i
                ; 使用StrCompare进行字符串比较（返回-1, 0, 1）
                if (StrCompare(CategoryOrder[i], CategoryOrder[j]) > 0) {
                    temp := CategoryOrder[i]
                    CategoryOrder[i] := CategoryOrder[j]
                    CategoryOrder[j] := temp
                }
            }
        }
    }
    
    ; 如果没有找到任何分类，使用默认分类
    if (CategoryOrder.Length = 0) {
        CategoryOrder := ["基础", "专业", "改错"]
    }
    
    ; 调整Y位置，为标题栏留出空间
    LabelY := TitleBarHeight + 20
    MoveGUI.Add("Text", "x20 y" . LabelY . " w300 h25 c" . UI_Colors.Text, "选择目标分类：")
    
    ; 使用ListBox替代DDL，以便显示更多选项
    ; 计算ListBox高度（每项25像素，最多显示8项，最少100像素）
    ListBoxHeight := Min(Max(CategoryOrder.Length * 25 + 10, 100), 210)
    ListBoxY := LabelY + 30
    CategoryListBox := MoveGUI.Add("ListBox", "x20 y" . ListBoxY . " w300 h" . ListBoxHeight . " Background" . UI_Colors.InputBg . " c" . UI_Colors.Text . " vCategoryDDL", CategoryOrder)
    CategoryListBox.SetFont("s10 c" . UI_Colors.Text, "Segoe UI")
    
    ; 获取ListBox的句柄并保存，用于WM_CTLCOLORLISTBOX消息处理
    ListBoxHwnd := CategoryListBox.Hwnd
    global MoveFromTemplateListBoxHwnd, MoveFromTemplateListBoxBrush
    MoveFromTemplateListBoxHwnd := ListBoxHwnd
    
    ; 创建画刷用于ListBox背景色（InputBg颜色）
    ColorCode := "0x" . UI_Colors.InputBg
    RGBColor := Integer(ColorCode)
    R := (RGBColor & 0xFF0000) >> 16
    G := (RGBColor & 0x00FF00) >> 8
    B := RGBColor & 0x0000FF
    BGRColor := (B << 16) | (G << 8) | R
    MoveFromTemplateListBoxBrush := DllCall("gdi32.dll\CreateSolidBrush", "UInt", BGRColor, "Ptr")
    
    ; 在窗口关闭时清理资源
    MoveGUI.OnEvent("Close", CleanupMoveFromTemplateListBox)
    
    ; 设置当前分类为默认选项
    for Index, Cat in CategoryOrder {
        if (Cat = Template.Category) {
            CategoryListBox.Value := Index
            break
        }
    }
    
    ; 计算按钮Y位置（ListBox下方20像素）
    BtnY := ListBoxY + ListBoxHeight + 20
    TextColor := (ThemeMode = "light") ? UI_Colors.Text : UI_Colors.Text  ; html.to.design 风格文本
    OkBtn := MoveGUI.Add("Text", "x120 y" . BtnY . " w80 h35 Center 0x200 c" . TextColor . " Background" . UI_Colors.BtnPrimary . " vMoveOkBtn", "确定")
    OkBtn.SetFont("s10", "Segoe UI")
    OkBtn.OnEvent("Click", CreateMoveFromTemplateHandler(MoveGUI, Template))
    HoverBtnWithAnimation(OkBtn, UI_Colors.BtnPrimary, UI_Colors.BtnPrimaryHover)
    
    CancelBtn := MoveGUI.Add("Text", "x210 y" . BtnY . " w80 h35 Center 0x200 c" . TextColor . " Background" . UI_Colors.BtnBg . " vMoveCancelBtn", "取消")
    CancelBtn.SetFont("s10", "Segoe UI")
    CancelBtn.OnEvent("Click", CreateMoveFromTemplateCancelHandler(MoveGUI))
    HoverBtnWithAnimation(CancelBtn, UI_Colors.BtnBg, UI_Colors.BtnHover)
    
    ; ESC键关闭窗口
    MoveGUI.OnEvent("Escape", (*) => MoveGUI.Destroy())
    
    ; 计算窗口高度（加上标题栏高度）
    WindowHeight := BtnY + 50 + TitleBarHeight
    MoveGUI.Show("w340 h" . WindowHeight)
}

CreateMoveFromTemplateHandler(MoveGUI, Template) {
    return MoveFromTemplateHandler.Bind(MoveGUI, Template)
}

MoveFromTemplateHandler(MoveGUI, Template, *) {
    global PromptTemplates, SavePromptTemplates, RefreshPromptListView
    global MoveFromTemplateListBoxHwnd, MoveFromTemplateListBoxBrush
    
    CategoryDDL := MoveGUI["CategoryDDL"]
    NewCategory := CategoryDDL.Text
    
    ; 更新模板的分类
    Template.Category := NewCategory
    SavePromptTemplates()
    RefreshPromptListView()
    
    ; 清理画刷和句柄
    try {
        if (MoveFromTemplateListBoxBrush != 0) {
            DllCall("gdi32.dll\DeleteObject", "Ptr", MoveFromTemplateListBoxBrush)
            MoveFromTemplateListBoxBrush := 0
        }
        MoveFromTemplateListBoxHwnd := 0
    } catch as err {
    }
    
    MoveGUI.Destroy()
    TrayTip("已移动", "提示", "Iconi 1")
}

; ===================== 从模板对象执行删除 =====================
OnPromptManagerDeleteFromTemplate(Template) {
    global PromptTemplates, SavePromptTemplates, DefaultTemplateIDs
    
    ; 检查是否是默认模板
    IsDefault := false
    for Type, TemplateID in DefaultTemplateIDs {
        if (TemplateID = Template.ID) {
            IsDefault := true
            break
        }
    }
    
    if (IsDefault) {
        MsgBox("不能删除默认模板", "提示", "Iconx")
        return
    }
    
    ; 确认删除
    Quote := Chr(34)
    Result := MsgBox("确定要删除模板 " . Quote . Template.Title . Quote . " 吗？", "确认删除", "YesNo Icon?")
    if (Result != "Yes") {
        return
    }
    
    ; 🚀 性能优化：使用索引直接查找数组位置 - O(1)
    global TemplateIndexByArrayIndex, TemplateIndexByID, TemplateIndexByTitle
    if (TemplateIndexByArrayIndex.Has(Template.ID)) {
        Index := TemplateIndexByArrayIndex[Template.ID]
        PromptTemplates.RemoveAt(Index)
        
        ; 立即删除索引
        TemplateIndexByID.Delete(Template.ID)
        Key := Template.Category . "|" . Template.Title
        if (TemplateIndexByTitle.Has(Key)) {
            TemplateIndexByTitle.Delete(Key)
        }
        TemplateIndexByArrayIndex.Delete(Template.ID)
        
        ; 标记分类映射需要重建
        InvalidateTemplateCache()
    }
    
    SavePromptTemplates()
    RefreshPromptListView()
    TrayTip("已删除", "提示", "Iconi 1")
}

; ===================== 重命名模板 =====================
OnPromptManagerRename() {
    global PromptManagerListView, CurrentPromptFolder, PromptTemplates
    
    SelectedRow := PromptManagerListView.GetNext()
    if (SelectedRow = 0) {
        return
    }
    
    try {
        ItemName := PromptManagerListView.GetText(SelectedRow, 1)
        
        ; 找到对应的模板
        for Index, Template in PromptTemplates {
            if (Template.Category = CurrentPromptFolder && Template.Title = ItemName) {
                OnPromptManagerRenameFromPreview(0, Template)
                return
            }
        }
    } catch as err {
    }
}

; ===================== 删除模板 =====================
OnPromptManagerDelete() {
    global PromptManagerListView, CurrentPromptFolder, PromptTemplates, SavePromptTemplates, DefaultTemplateIDs
    
    SelectedRow := PromptManagerListView.GetNext()
    if (SelectedRow = 0) {
        return
    }
    
    try {
        ItemName := PromptManagerListView.GetText(SelectedRow, 1)
        
        ; 🚀 性能优化：使用索引直接查找 - O(1)
        Key := CurrentPromptFolder . "|" . ItemName
        global TemplateIndexByTitle, TemplateIndexByArrayIndex
        
        if (TemplateIndexByTitle.Has(Key)) {
            TargetTemplate := TemplateIndexByTitle[Key]
            ; 获取数组索引
            if (TemplateIndexByArrayIndex.Has(TargetTemplate.ID)) {
                TemplateIndex := TemplateIndexByArrayIndex[TargetTemplate.ID]
            } else {
                TemplateIndex := 0
            }
        } else {
            return
        }
        
        ; 检查是否是默认模板
        IsDefault := false
        for Key, DefaultID in DefaultTemplateIDs {
            if (DefaultID = TargetTemplate.ID) {
                IsDefault := true
                break
            }
        }
        
        if (IsDefault) {
            MsgBox("无法删除默认模板", "提示", "Icon!")
            return
        }
        
        ; 确认删除
        Quote := Chr(34)
        Result := MsgBox("确定要删除模板 " . Quote . ItemName . Quote . " 吗？", "确认删除", "YesNo Icon?")
        if (Result = "Yes") {
            ; 从数组中删除
            PromptTemplates.RemoveAt(TemplateIndex)
            SavePromptTemplates()
            RefreshPromptListView()
            TrayTip("已删除", "提示", "Iconi 1")
        }
    } catch as err {
    }
}

; ===================== 返回上级文件夹 =====================
OnPromptManagerGoBack() {
    global CurrentPromptFolder
    CurrentPromptFolder := ""
    RefreshPromptListView()
}

; ===================== 恢复展开的模板 =====================
RestoreExpandedTemplate(TemplateKey, CategoryName, Template) {
    global ExpandedTemplateKey, CategoryExpandedState
    ExpandTemplate(TemplateKey, CategoryName, Template)
    ExpandedTemplateKey := TemplateKey
    ; 更新保存的状态
    if (!IsSet(CategoryExpandedState)) {
        CategoryExpandedState := Map()
    }
    CategoryExpandedState[CategoryName] := TemplateKey
}

; ===================== 展开分类中的第一个模板 =====================
ExpandFirstTemplateInCategory(CategoryName, ShouldExpand) {
    global PromptTemplates, ExpandedTemplateKey, CategoryExpandedState
    
    if (!ShouldExpand) {
        ExpandedTemplateKey := ""
        return
    }
    
    ; 找到第一个模板
    FirstTemplate := ""
    FirstIndex := 0
    TemplateIndex := 0
    for Index, Template in PromptTemplates {
        if (Template.Category = CategoryName) {
            TemplateIndex++
            if (TemplateIndex = 1) {
                FirstTemplate := Template
                FirstIndex := TemplateIndex
                break
            }
        }
    }
    
    if (FirstTemplate && FirstTemplate.ID != "") {
        TemplateKey := CategoryName . "_" . FirstIndex
        ; 使用SetTimer延迟展开，确保UI已经渲染完成
        SetTimer(() => RestoreExpandedTemplate(TemplateKey, CategoryName, FirstTemplate), -150)
    } else {
        ExpandedTemplateKey := ""
    }
}

; ===================== 自动展开第一个模板（用于初始化）=====================
AutoExpandFirstTemplate(TemplateKey, CategoryName, Template) {
    global ExpandedTemplateKey
    ExpandTemplate(TemplateKey, CategoryName, Template)
    ExpandedTemplateKey := TemplateKey
}

; ===================== 创建分类内容显示区域 =====================
CreatePromptCategoryContent(ConfigGUI, X, Y, W, H, CategoryName, Templates) {
    global PromptCategoryTabControls, UI_Colors, PromptsMainTabControls, PromptsTabControls, ExpandedTemplateKey
    
    ; 创建分类面板（默认隐藏）
    CategoryPanel := ConfigGUI.Add("Text", "x" . X . " y" . Y . " w" . W . " h" . H . " Background" . UI_Colors.Background . " vPromptCategoryPanel" . CategoryName, "")
    CategoryPanel.Visible := false
    PromptCategoryTabControls[CategoryName] := []
    PromptCategoryTabControls[CategoryName].Push(CategoryPanel)
    PromptsMainTabControls["manage"].Push(CategoryPanel)
    PromptsTabControls.Push(CategoryPanel)
    
    ; 创建模板按钮列表（动态计算位置，避免重叠）
    BtnY := Y + 10
    BtnHeight := 40
    BtnSpacing := 10
    ExpandPanelHeight := 300  ; 展开面板的高度
    ScrollArea := H - 20
    
    ; 保存每个模板按钮的位置信息，用于后续动态调整
    global TemplateButtonPositions := Map()
    if (!IsSet(TemplateButtonPositions)) {
        TemplateButtonPositions := Map()
    }
    if (!TemplateButtonPositions.Has(CategoryName)) {
        TemplateButtonPositions[CategoryName] := Map()
    }
    
    for Index, Template in Templates {
        TemplateKey := CategoryName . "_" . Index
        
        ; 模板按钮（可点击展开/折叠）
        Btn := ConfigGUI.Add("Text", "x" . (X + 10) . " y" . BtnY . " w" . (W - 20) . " h" . BtnHeight . " Center 0x200 c" . UI_Colors.Text . " Background" . UI_Colors.BtnBg . " vPromptTemplateBtn" . TemplateKey, Template.Title)
        Btn.SetFont("s10", "Segoe UI")
        Btn.OnEvent("Click", CreateTemplateToggleHandler(TemplateKey, Template, CategoryName, Index, ConfigGUI, X, BtnY + BtnHeight + 5, W - 20, ExpandPanelHeight))
        HoverBtnWithAnimation(Btn, UI_Colors.BtnBg, UI_Colors.BtnHover)
        Btn.Visible := false
        PromptCategoryTabControls[CategoryName].Push(Btn)
        PromptsMainTabControls["manage"].Push(Btn)
        PromptsTabControls.Push(Btn)
        
        ; 展开面板（默认隐藏）
        ExpandPanel := ConfigGUI.Add("Text", "x" . (X + 10) . " y" . (BtnY + BtnHeight + 5) . " w" . (W - 20) . " h" . ExpandPanelHeight . " Background" . UI_Colors.InputBg . " vPromptExpandPanel" . TemplateKey, "")
        ExpandPanel.Visible := false
        PromptCategoryTabControls[CategoryName].Push(ExpandPanel)
        PromptsMainTabControls["manage"].Push(ExpandPanel)
        PromptsTabControls.Push(ExpandPanel)
        
        ; 模板内容编辑框
        ContentEditY := BtnY + BtnHeight + 15
        ContentEdit := ConfigGUI.Add("Edit", "x" . (X + 20) . " y" . ContentEditY . " w" . (W - 40) . " h" . (ExpandPanelHeight - 100) . " Multi vPromptContentEdit" . TemplateKey . " Background" . UI_Colors.Background . " c" . UI_Colors.Text, Template.Content)
        ContentEdit.SetFont("s9", "Consolas")
        ContentEdit.Visible := false
        PromptCategoryTabControls[CategoryName].Push(ContentEdit)
        PromptsMainTabControls["manage"].Push(ContentEdit)
        PromptsTabControls.Push(ContentEdit)
        
        ; 按钮区域
        BtnAreaY := ContentEditY + ExpandPanelHeight - 90
        BtnWidth := 80
        BtnHeight2 := 30
        BtnSpacing2 := 10
        BtnX := X + 20
        
        ; 预览按钮
        PreviewBtn := ConfigGUI.Add("Text", "x" . BtnX . " y" . BtnAreaY . " w" . BtnWidth . " h" . BtnHeight2 . " Center 0x200 cFFFFFF Background" . UI_Colors.BtnPrimary . " vPromptPreviewBtn" . TemplateKey, "预览")
        PreviewBtn.SetFont("s9", "Segoe UI")
        PreviewBtn.OnEvent("Click", CreatePreviewTemplateHandler(TemplateKey, Template))
        HoverBtnWithAnimation(PreviewBtn, UI_Colors.BtnPrimary, UI_Colors.BtnPrimaryHover)
        PreviewBtn.Visible := false
        PromptCategoryTabControls[CategoryName].Push(PreviewBtn)
        PromptsMainTabControls["manage"].Push(PreviewBtn)
        PromptsTabControls.Push(PreviewBtn)
        
        ; 发送按钮
        BtnX += BtnWidth + BtnSpacing2
        SendBtn := ConfigGUI.Add("Text", "x" . BtnX . " y" . BtnAreaY . " w" . BtnWidth . " h" . BtnHeight2 . " Center 0x200 cFFFFFF Background" . UI_Colors.BtnPrimary . " vPromptSendBtn" . TemplateKey, "发送")
        SendBtn.SetFont("s9", "Segoe UI")
        SendBtn.OnEvent("Click", CreateSendTemplateHandlerWithKey(TemplateKey, Template))
        HoverBtnWithAnimation(SendBtn, UI_Colors.BtnPrimary, UI_Colors.BtnPrimaryHover)
        SendBtn.Visible := false
        PromptCategoryTabControls[CategoryName].Push(SendBtn)
        PromptsMainTabControls["manage"].Push(SendBtn)
        PromptsTabControls.Push(SendBtn)
        
        ; 复制按钮
        BtnX += BtnWidth + BtnSpacing2
        CopyBtn := ConfigGUI.Add("Text", "x" . BtnX . " y" . BtnAreaY . " w" . BtnWidth . " h" . BtnHeight2 . " Center 0x200 cFFFFFF Background" . UI_Colors.BtnPrimary . " vPromptCopyBtn" . TemplateKey, "复制")
        CopyBtn.SetFont("s9", "Segoe UI")
        CopyBtn.OnEvent("Click", CreateCopyTemplateHandlerWithKey(TemplateKey, Template))
        HoverBtnWithAnimation(CopyBtn, UI_Colors.BtnPrimary, UI_Colors.BtnPrimaryHover)
        CopyBtn.Visible := false
        PromptCategoryTabControls[CategoryName].Push(CopyBtn)
        PromptsMainTabControls["manage"].Push(CopyBtn)
        PromptsTabControls.Push(CopyBtn)
        
        ; 编辑按钮
        BtnX += BtnWidth + BtnSpacing2
        EditBtn := ConfigGUI.Add("Text", "x" . BtnX . " y" . BtnAreaY . " w" . BtnWidth . " h" . BtnHeight2 . " Center 0x200 cFFFFFF Background" . UI_Colors.BtnPrimary . " vPromptEditBtn" . TemplateKey, "编辑")
        EditBtn.SetFont("s9", "Segoe UI")
        EditBtn.OnEvent("Click", CreateEditTemplateHandlerWithKey(TemplateKey, Template))
        HoverBtnWithAnimation(EditBtn, UI_Colors.BtnPrimary, UI_Colors.BtnPrimaryHover)
        EditBtn.Visible := false
        PromptCategoryTabControls[CategoryName].Push(EditBtn)
        PromptsMainTabControls["manage"].Push(EditBtn)
        PromptsTabControls.Push(EditBtn)
        
        ; 删除按钮
        BtnX += BtnWidth + BtnSpacing2
        DeleteBtn := ConfigGUI.Add("Text", "x" . BtnX . " y" . BtnAreaY . " w" . BtnWidth . " h" . BtnHeight2 . " Center 0x200 cFFFFFF Background" . UI_Colors.BtnDanger . " vPromptDeleteBtn" . TemplateKey, "删除")
        DeleteBtn.SetFont("s9", "Segoe UI")
        DeleteBtn.OnEvent("Click", CreateDeleteTemplateHandlerWithKey(TemplateKey, Template))
        HoverBtnWithAnimation(DeleteBtn, UI_Colors.BtnDanger, UI_Colors.BtnDangerHover)
        DeleteBtn.Visible := false
        PromptCategoryTabControls[CategoryName].Push(DeleteBtn)
        PromptsMainTabControls["manage"].Push(DeleteBtn)
        PromptsTabControls.Push(DeleteBtn)
        
        ; 更新下一个按钮的Y位置（按钮基础高度 + 间距）
        ; 注意：展开面板不会影响后续按钮的初始位置，因为展开时我们使用Move来调整位置
        BtnY += BtnHeight + BtnSpacing
    }
}

; ===================== 创建模板展开/折叠处理器 =====================
CreateTemplateToggleHandler(TemplateKey, Template, CategoryName, Index, ConfigGUI, PanelX, PanelY, PanelW, PanelH) {
    return (*) => ToggleTemplateExpand(TemplateKey, Template, CategoryName, Index, ConfigGUI, PanelX, PanelY, PanelW, PanelH)
}

; ===================== 切换模板展开/折叠 =====================
ToggleTemplateExpand(TemplateKey, Template, CategoryName, Index, ConfigGUI, PanelX, PanelY, PanelW, PanelH) {
    global ExpandedTemplateKey, PromptCategoryTabControls, UI_Colors, CategoryExpandedState
    
    ; 如果点击的是当前展开的模板，则折叠
    if (ExpandedTemplateKey = TemplateKey) {
        CollapseTemplate(TemplateKey, CategoryName)
        ExpandedTemplateKey := ""
        ; 清除保存的展开状态
        if (IsSet(CategoryExpandedState) && CategoryExpandedState.Has(CategoryName)) {
            CategoryExpandedState.Delete(CategoryName)
        }
        ; 延迟保存到配置文件
        SetTimer(SavePromptTemplates, -500)
        return
    }
    
    ; 折叠之前展开的模板（同一分类内的）
    if (ExpandedTemplateKey != "") {
        ; 检查是否是同一分类
        Parts := StrSplit(ExpandedTemplateKey, "_", , 2)
        if (Parts.Length >= 2 && Parts[1] = CategoryName) {
            CollapseTemplate(ExpandedTemplateKey, CategoryName)
        }
    }
    
    ; 展开当前模板
    ExpandTemplate(TemplateKey, CategoryName, Template)
    ExpandedTemplateKey := TemplateKey
    
    ; 保存当前分类的展开状态到内存
    if (!IsSet(CategoryExpandedState)) {
        CategoryExpandedState := Map()
    }
    CategoryExpandedState[CategoryName] := TemplateKey
    
    ; 延迟保存到配置文件（避免频繁IO）
    SetTimer(SavePromptTemplates, -500)
}

; ===================== 展开模板 =====================
ExpandTemplate(TemplateKey, CategoryName, Template) {
    global PromptCategoryTabControls, GuiID_ConfigGUI
    
    try {
        ConfigGUI := GuiFromHwnd(GuiID_ConfigGUI)
        if (!ConfigGUI) {
            return
        }
        
        ; 显示展开面板
        ExpandPanel := ConfigGUI["PromptExpandPanel" . TemplateKey]
        if (ExpandPanel) {
            ExpandPanel.Visible := true
        }
        
        ; 显示内容编辑框
        ContentEdit := ConfigGUI["PromptContentEdit" . TemplateKey]
        if (ContentEdit) {
            ContentEdit.Visible := true
            ContentEdit.Value := Template.Content
        }
        
        ; 显示所有按钮
        PreviewBtn := ConfigGUI["PromptPreviewBtn" . TemplateKey]
        if (PreviewBtn) {
            PreviewBtn.Visible := true
        }
        
        SendBtn := ConfigGUI["PromptSendBtn" . TemplateKey]
        if (SendBtn) {
            SendBtn.Visible := true
        }
        
        CopyBtn := ConfigGUI["PromptCopyBtn" . TemplateKey]
        if (CopyBtn) {
            CopyBtn.Visible := true
        }
        
        EditBtn := ConfigGUI["PromptEditBtn" . TemplateKey]
        if (EditBtn) {
            EditBtn.Visible := true
        }
        
        DeleteBtn := ConfigGUI["PromptDeleteBtn" . TemplateKey]
        if (DeleteBtn) {
            DeleteBtn.Visible := true
        }
    } catch as err {
    }
}

; ===================== 折叠模板 =====================
CollapseTemplate(TemplateKey, CategoryName) {
    global GuiID_ConfigGUI
    
    try {
        ConfigGUI := GuiFromHwnd(GuiID_ConfigGUI)
        if (!ConfigGUI) {
            return
        }
        
        ; 隐藏展开面板
        ExpandPanel := ConfigGUI["PromptExpandPanel" . TemplateKey]
        if (ExpandPanel) {
            ExpandPanel.Visible := false
        }
        
        ; 隐藏内容编辑框
        ContentEdit := ConfigGUI["PromptContentEdit" . TemplateKey]
        if (ContentEdit) {
            ContentEdit.Visible := false
        }
        
        ; 隐藏所有按钮
        PreviewBtn := ConfigGUI["PromptPreviewBtn" . TemplateKey]
        if (PreviewBtn) {
            PreviewBtn.Visible := false
        }
        
        SendBtn := ConfigGUI["PromptSendBtn" . TemplateKey]
        if (SendBtn) {
            SendBtn.Visible := false
        }
        
        CopyBtn := ConfigGUI["PromptCopyBtn" . TemplateKey]
        if (CopyBtn) {
            CopyBtn.Visible := false
        }
        
        EditBtn := ConfigGUI["PromptEditBtn" . TemplateKey]
        if (EditBtn) {
            EditBtn.Visible := false
        }
        
        DeleteBtn := ConfigGUI["PromptDeleteBtn" . TemplateKey]
        if (DeleteBtn) {
            DeleteBtn.Visible := false
        }
    } catch as err {
    }
}

; ===================== 创建预览模板处理器 =====================
CreatePreviewTemplateHandler(TemplateKey, Template) {
    return (*) => PreviewTemplateContent(TemplateKey, Template)
}

; ===================== 预览模板内容 =====================
PreviewTemplateContent(TemplateKey, Template) {
    global GuiID_ConfigGUI
    
    try {
        ConfigGUI := GuiFromHwnd(GuiID_ConfigGUI)
        if (!ConfigGUI) {
            return
        }
        
        ; 从编辑框获取内容
        ContentEdit := ConfigGUI["PromptContentEdit" . TemplateKey]
        Content := ContentEdit ? ContentEdit.Value : Template.Content
        
        ; 显示预览窗口
        PreviewGUI := Gui("+AlwaysOnTop +ToolWindow", "预览: " . Template.Title)
        PreviewGUI.BackColor := "FFFFFF"
        PreviewGUI.SetFont("s10", "Consolas")
        
        PreviewEdit := PreviewGUI.Add("Edit", "x10 y10 w600 h400 Multi ReadOnly BackgroundFFFFFF", Content)
        PreviewEdit.SetFont("s9", "Consolas")
        
        CloseBtn := PreviewGUI.Add("Button", "x250 y420 w100 h30", "关闭")
        CloseBtn.OnEvent("Click", (*) => PreviewGUI.Destroy())
        
        ; ESC键关闭窗口
        PreviewGUI.OnEvent("Escape", (*) => PreviewGUI.Destroy())
        
        PreviewGUI.Show()
    } catch as e {
        TrayTip("预览失败: " . e.Message, "错误", "Iconx 2")
    }
}

; ===================== 创建复制模板处理器（带键） =====================
CreateCopyTemplateHandlerWithKey(TemplateKey, Template) {
    return (*) => CopyTemplateToClipboardWithKey(TemplateKey, Template)
}

; ===================== 复制模板到剪贴板（带键） =====================
CopyTemplateToClipboardWithKey(TemplateKey, Template) {
    global GuiID_ConfigGUI
    
    try {
        ConfigGUI := GuiFromHwnd(GuiID_ConfigGUI)
        if (!ConfigGUI) {
            return
        }
        
        ; 从编辑框获取内容
        ContentEdit := ConfigGUI["PromptContentEdit" . TemplateKey]
        Content := ContentEdit ? ContentEdit.Value : Template.Content
        
        A_Clipboard := Content
        TrayTip("已复制到剪贴板", "提示", "Iconi 1")
    } catch as err {
        A_Clipboard := Template.Content
        TrayTip("已复制到剪贴板", "提示", "Iconi 1")
    }
}

; ===================== 创建发送模板处理器（带键） =====================
CreateSendTemplateHandlerWithKey(TemplateKey, Template) {
    return (*) => SendTemplateToCursorWithKey(TemplateKey, Template)
}

; ===================== 发送模板到Cursor（带键） =====================
SendTemplateToCursorWithKey(TemplateKey, Template) {
    global GuiID_ConfigGUI, CursorPath, AISleepTime
    
    try {
        ; 直接使用模板内容，不需要从编辑框获取（因为新界面没有编辑框）
        Content := Template.Content
        
        ; 检查 Cursor 是否运行
        if (!WinExist("ahk_exe Cursor.exe")) {
            if (CursorPath != "" && FileExist(CursorPath)) {
                Run(CursorPath)
                Sleep(AISleepTime)
            } else {
                TrayTip("Cursor未运行", "错误", "Iconx 2")
                return
            }
        }
        
        ; 激活 Cursor 窗口
        WinActivate("ahk_exe Cursor.exe")
        Sleep(200)
        
        ; 打开聊天面板
        Send("^l")
        Sleep(300)
        
        ; 发送模板内容
        Send("^v")
        Sleep(100)
        
        ; 如果剪贴板内容不是模板内容，直接输入
        if (A_Clipboard != Content) {
            Send("^a")
            Sleep(50)
            Send(Content)
        }
        
        ; 发送消息
        Send("{Enter}")
        TrayTip("已发送到Cursor", "提示", "Iconi 1")
    } catch as e {
        TrayTip("发送失败: " . e.Message, "错误", "Iconx 2")
    }
}

; ===================== 创建编辑模板处理器 =====================
CreateEditTemplateHandlerWithKey(TemplateKey, Template) {
    return (*) => SaveTemplateFromEdit(TemplateKey, Template)
}

; ===================== 保存模板编辑 =====================
SaveTemplateFromEdit(TemplateKey, Template) {
    global GuiID_ConfigGUI, PromptTemplates, SavePromptTemplates
    
    try {
        ConfigGUI := GuiFromHwnd(GuiID_ConfigGUI)
        if (!ConfigGUI) {
            return
        }
        
        ; 从编辑框获取内容
        ContentEdit := ConfigGUI["PromptContentEdit" . TemplateKey]
        if (!ContentEdit) {
            TrayTip("无法找到编辑框", "错误", "Iconx 2")
            return
        }
        
        NewContent := ContentEdit.Value
        
        ; 更新模板内容
        for Index, T in PromptTemplates {
            if (T.ID = Template.ID) {
                T.Content := NewContent
                break
            }
        }
        
        ; 保存配置
        SavePromptTemplates()
        TrayTip("模板已保存", "提示", "Iconi 1")
    } catch as e {
        TrayTip("保存失败: " . e.Message, "错误", "Iconx 2")
    }
}

; ===================== 创建删除模板处理器 =====================
CreateDeleteTemplateHandlerWithKey(TemplateKey, Template) {
    return (*) => DeleteTemplateFromEdit(TemplateKey, Template)
}

; ===================== 删除模板 =====================
DeleteTemplateFromEdit(TemplateKey, Template) {
    global GuiID_ConfigGUI, PromptTemplates, DefaultTemplateIDs, SavePromptTemplates, ExpandedTemplateKey
    
    ; 检查是否是默认模板
    IsDefault := false
    for Type, TemplateID in DefaultTemplateIDs {
        if (TemplateID = Template.ID) {
            IsDefault := true
            break
        }
    }
    
    if (IsDefault) {
        TrayTip("无法删除默认模板，请先取消默认设置", "提示", "Icon! 2")
        return
    }
    
    ; 确认删除
    Quote := Chr(34)
    Result := MsgBox("确定要删除模板 " . Quote . Template.Title . Quote . " 吗？", "确认删除", "YesNo Icon?")
    if (Result != "Yes") {
        return
    }
    
    try {
        ; 从数组中删除
        for Index, T in PromptTemplates {
            if (T.ID = Template.ID) {
                PromptTemplates.RemoveAt(Index)
                break
            }
        }
        
        ; 如果当前展开的是被删除的模板，折叠它
        if (ExpandedTemplateKey = TemplateKey) {
            ExpandedTemplateKey := ""
        }
        
        ; 保存配置
        SavePromptTemplates()
        
        ; 刷新UI（重新创建模板管理标签页）
        RefreshPromptsManageTab()
        
        TrayTip("模板已删除", "提示", "Iconi 1")
    } catch as e {
        TrayTip("删除失败: " . e.Message, "错误", "Iconx 2")
    }
}

; ===================== 刷新模板管理标签页 =====================
RefreshPromptsManageTab() {
    global GuiID_ConfigGUI, PromptsMainTabControls, PromptsTabControls
    
    try {
        ConfigGUI := GuiFromHwnd(GuiID_ConfigGUI)
        if (!ConfigGUI) {
            return
        }
        
        ; 获取管理面板的位置和尺寸
        ManagePanel := ConfigGUI["PromptsManagePanel"]
        if (!ManagePanel) {
            return
        }
        
        ManagePanel.GetPos(&X, &Y, &W, &H)
        
        ; 销毁旧的控件
        for Index, Ctrl in PromptsMainTabControls["manage"] {
            try {
                if (Ctrl && Ctrl != ManagePanel) {
                    Ctrl.Destroy()
                }
            } catch as err {
            }
        }
        
        ; 清空控件列表
        PromptsMainTabControls["manage"] := [ManagePanel]
        
        ; 从PromptsTabControls中移除旧的控件（保留ManagePanel）
        NewPromptsTabControls := []
        for Index, Ctrl in PromptsTabControls {
            if (Ctrl = ManagePanel) {
                NewPromptsTabControls.Push(Ctrl)
            } else {
                ; 检查是否在manage列表中
                IsManageCtrl := false
                for J, ManageCtrl in PromptsMainTabControls["manage"] {
                    if (Ctrl = ManageCtrl) {
                        IsManageCtrl := true
                        break
                    }
                }
                if (!IsManageCtrl) {
                    NewPromptsTabControls.Push(Ctrl)
                }
            }
        }
        PromptsTabControls := NewPromptsTabControls
        
        ; 重新创建模板管理标签页
        CreatePromptsManageTab(ConfigGUI, X, Y, W, H)
        
        ; 切换到管理标签页
        SwitchPromptsMainTab("manage")
    } catch as e {
        TrayTip("刷新失败: " . e.Message, "错误", "Iconx 2")
    }
}

; ===================== 发送模板到Cursor =====================
SendTemplateToCursor(Template) {
    global CursorPath, AISleepTime
    
    try {
        ; 检查 Cursor 是否运行
        if (!WinExist("ahk_exe Cursor.exe")) {
            if (CursorPath != "" && FileExist(CursorPath)) {
                Run(CursorPath)
                Sleep(AISleepTime)
            } else {
                TrayTip("Cursor未运行", "错误", "Iconx 2")
                return
            }
        }
        
        ; 激活 Cursor 窗口
        WinActivate("ahk_exe Cursor.exe")
        Sleep(200)
        
        ; 打开聊天面板
        Send("^l")
        Sleep(400)
        
        ; 复制模板内容到剪贴板
        OldClipboard := A_Clipboard
        A_Clipboard := Template.Content
        
        ; 粘贴
        Send("^v")
        Sleep(300)
        
        ; 提交
        Send("{Enter}")
        
        ; 恢复剪贴板
        Sleep(200)
        A_Clipboard := OldClipboard
        
        TrayTip("已发送到Cursor", "提示", "Iconi 1")
    } catch as e {
        TrayTip("发送失败: " . e.Message, "错误", "Iconx 2")
    }
}

; ===================== 创建传统编辑标签页 =====================
CreatePromptsLegacyTab(ConfigGUI, X, Y, W, H) {
    global Prompt_Explain, Prompt_Refactor, Prompt_Optimize, PromptExplainEdit, PromptRefactorEdit, PromptOptimizeEdit, PromptsMainTabControls, UI_Colors, PromptsTabControls
    
    ; 创建面板
    LegacyPanel := ConfigGUI.Add("Text", "x" . X . " y" . Y . " w" . W . " h" . H . " Background" . UI_Colors.Background . " vPromptsLegacyPanel", "")
    LegacyPanel.Visible := false
    PromptsMainTabControls["legacy"] := []
    PromptsMainTabControls["legacy"].Push(LegacyPanel)
    PromptsTabControls.Push(LegacyPanel)
    
    ; 解释代码提示词
    YPos := Y + 20
    Label1 := ConfigGUI.Add("Text", "x" . X . " y" . YPos . " w" . W . " h25 c" . UI_Colors.Text, GetText("explain_prompt"))
    Label1.SetFont("s11", "Segoe UI")
    PromptsMainTabControls["legacy"].Push(Label1)
    PromptsTabControls.Push(Label1)
    
    YPos += 30
    PromptExplainEdit := ConfigGUI.Add("Edit", "x" . X . " y" . YPos . " w" . W . " h80 vPromptExplainEdit Background" . UI_Colors.InputBg . " c" . UI_Colors.Text . " Multi", Prompt_Explain)
    PromptExplainEdit.SetFont("s10", "Consolas")
    PromptsMainTabControls["legacy"].Push(PromptExplainEdit)
    PromptsTabControls.Push(PromptExplainEdit)
    
    ; 重构代码提示词
    YPos += 100
    Label2 := ConfigGUI.Add("Text", "x" . X . " y" . YPos . " w" . W . " h25 c" . UI_Colors.Text, GetText("refactor_prompt"))
    Label2.SetFont("s11", "Segoe UI")
    PromptsMainTabControls["legacy"].Push(Label2)
    PromptsTabControls.Push(Label2)
    
    YPos += 30
    PromptRefactorEdit := ConfigGUI.Add("Edit", "x" . X . " y" . YPos . " w" . W . " h80 vPromptRefactorEdit Background" . UI_Colors.InputBg . " c" . UI_Colors.Text . " Multi", Prompt_Refactor)
    PromptRefactorEdit.SetFont("s10", "Consolas")
    PromptsMainTabControls["legacy"].Push(PromptRefactorEdit)
    PromptsTabControls.Push(PromptRefactorEdit)
    
    ; 优化代码提示词
    YPos += 100
    Label3 := ConfigGUI.Add("Text", "x" . X . " y" . YPos . " w" . W . " h25 c" . UI_Colors.Text, GetText("optimize_prompt"))
    Label3.SetFont("s11", "Segoe UI")
    PromptsMainTabControls["legacy"].Push(Label3)
    PromptsTabControls.Push(Label3)
    
    YPos += 30
    PromptOptimizeEdit := ConfigGUI.Add("Edit", "x" . X . " y" . YPos . " w" . W . " h80 vPromptOptimizeEdit Background" . UI_Colors.InputBg . " c" . UI_Colors.Text . " Multi", Prompt_Optimize)
    PromptOptimizeEdit.SetFont("s10", "Consolas")
    PromptsMainTabControls["legacy"].Push(PromptOptimizeEdit)
    PromptsTabControls.Push(PromptOptimizeEdit)
    
    ; 提示文字
    YPos += 100
    HintText := ConfigGUI.Add("Text", "x" . X . " y" . YPos . " w" . W . " h40 c" . UI_Colors.TextDim, "提示：使用 {code} 表示选中的代码，{lang} 表示编程语言。例如：请用 {lang} 解释以下代码：{code}")
    HintText.SetFont("s9", "Segoe UI")
    PromptsMainTabControls["legacy"].Push(HintText)
    PromptsTabControls.Push(HintText)
}

; ===================== 创建快捷键标签页 =====================
CreateHotkeysTab(ConfigGUI, X, Y, W, H) {
    global SplitHotkey, BatchHotkey, HotkeysTabPanel, SplitHotkeyEdit, BatchHotkeyEdit, HotkeysTabControls
    global HotkeyESC, HotkeyC, HotkeyV, HotkeyX, HotkeyE, HotkeyR, HotkeyO, HotkeyQ, HotkeyZ, HotkeyT
    global HotkeyESCEdit, HotkeyCEdit, HotkeyVEdit, HotkeyXEdit, HotkeyEEdit, HotkeyREdit, HotkeyOEdit, HotkeyQEdit, HotkeyZEdit
    global HotkeySubTabs, HotkeySubTabControls, UI_Colors
    global HotkeysMainTabs, HotkeysMainTabControls, CursorRulesTabPanel
    
    ; 创建标签页面板（默认隐藏）
    HotkeysTabPanel := ConfigGUI.Add("Text", "x" . X . " y" . Y . " w" . W . " h" . H . " Background" . UI_Colors.Background . " vHotkeysTabPanel", "")
    HotkeysTabPanel.Visible := false
    HotkeysTabControls.Push(HotkeysTabPanel)
    
    ; 标题
    Title := ConfigGUI.Add("Text", "x" . (X + 30) . " y" . (Y + 20) . " w" . (W - 60) . " h30 c" . UI_Colors.Text, GetText("hotkey_settings"))
    Title.SetFont("s16 Bold", "Segoe UI")
    HotkeysTabControls.Push(Title)
    
    ; ========== 主标签页区域（快捷键设置 / 快操作按钮 / 搜索标签）==========
    MainTabBarY := Y + 70
    MainTabBarHeight := 40
    MainTabBarBg := ConfigGUI.Add("Text", "x" . (X + 30) . " y" . MainTabBarY . " w" . (W - 60) . " h" . MainTabBarHeight . " Background" . UI_Colors.Sidebar, "")
    HotkeysTabControls.Push(MainTabBarBg)
    
    ; 创建主标签列表（三个标签：快操作按钮、搜索标签、快捷键设置）
    MainTabList := [
        {Key: "quickaction", Name: GetText("quick_action_config")},
        {Key: "searchcategory", Name: GetText("search_category_config")},
        {Key: "settings", Name: GetText("hotkey_main_tab_settings")}
    ]
    
    ; 创建主标签按钮
    MainTabWidth := (W - 60) / MainTabList.Length
    MainTabX := X + 30
    HotkeysMainTabs := Map()
    global HotkeysMainTabControls := Map()
    
    ; 创建主标签点击处理函数
    CreateMainTabClickHandler(Key) {
        return (*) => SwitchHotkeysMainTab(Key)
    }
    
    for Index, Item in MainTabList {
        ; 使用 Text 控件模拟 Material 风格按钮
        MainTabBtn := ConfigGUI.Add("Text", "x" . MainTabX . " y" . (MainTabBarY + 5) . " w" . (MainTabWidth - 2) . " h" . (MainTabBarHeight - 10) . " Center 0x200 vHotkeysMainTab" . Item.Key, Item.Name)
        MainTabBtn.SetFont("s10", "Segoe UI")
        
        ; 使用主题颜色：默认未选中状态
        MainTabBtn.Opt("+Background" . UI_Colors.Sidebar)
        MainTabBtn.SetFont("s10 c" . UI_Colors.TextDim, "Segoe UI")
        
        MainTabBtn.OnEvent("Click", CreateMainTabClickHandler(Item.Key))
        ; 悬停效果使用主题颜色（带动效）
        HoverBtnWithAnimation(MainTabBtn, UI_Colors.Sidebar, UI_Colors.BtnHover)
        HotkeysTabControls.Push(MainTabBtn)
        HotkeysMainTabs[Item.Key] := MainTabBtn
        MainTabX += MainTabWidth
    }
    
    global HotkeysMainTabs := HotkeysMainTabs
    
    ; 内容区域（显示当前选中的主标签页内容）
    ContentAreaY := MainTabBarY + MainTabBarHeight + 20
    ContentAreaHeight := H - (ContentAreaY - Y) - 20
    
    ; ========== 快捷键设置标签页内容 ==========
    ; 横向标签页区域（原有的快捷键子标签）
    TabBarY := ContentAreaY
    TabBarHeight := 35
    TabBarBg := ConfigGUI.Add("Text", "x" . (X + 30) . " y" . TabBarY . " w" . (W - 60) . " h" . TabBarHeight . " Background" . UI_Colors.Sidebar . " vHotkeySettingsTabBar", "")
    ; 【架构修复】TabBarBg 只属于 "settings" 主标签页，不添加到 HotkeysTabControls（公共控件列表）
    ; 这样 SwitchHotkeysMainTab 可以统一管理其显示/隐藏
    
    ; 快捷键列表（定义每个快捷键的信息）
    HotkeyList := [
        {Key: "C", Name: GetText("hotkey_c"), Default: HotkeyC, Edit: "HotkeyCEdit", Desc: "hotkey_c_desc", Hint: "hotkey_single_char_hint", DefaultVal: "c"},
        {Key: "V", Name: GetText("hotkey_v"), Default: HotkeyV, Edit: "HotkeyVEdit", Desc: "hotkey_v_desc", Hint: "hotkey_single_char_hint", DefaultVal: "v"},
        {Key: "X", Name: GetText("hotkey_x"), Default: HotkeyX, Edit: "HotkeyXEdit", Desc: "hotkey_x_desc", Hint: "hotkey_single_char_hint", DefaultVal: "x"},
        {Key: "E", Name: GetText("hotkey_e"), Default: HotkeyE, Edit: "HotkeyEEdit", Desc: "hotkey_e_desc", Hint: "hotkey_single_char_hint", DefaultVal: "e"},
        {Key: "R", Name: GetText("hotkey_r"), Default: HotkeyR, Edit: "HotkeyREdit", Desc: "hotkey_r_desc", Hint: "hotkey_single_char_hint", DefaultVal: "r"},
        {Key: "O", Name: GetText("hotkey_o"), Default: HotkeyO, Edit: "HotkeyOEdit", Desc: "hotkey_o_desc", Hint: "hotkey_single_char_hint", DefaultVal: "o"},
        {Key: "Q", Name: GetText("hotkey_q"), Default: HotkeyQ, Edit: "HotkeyQEdit", Desc: "hotkey_q_desc", Hint: "hotkey_single_char_hint", DefaultVal: "q"},
        {Key: "Z", Name: GetText("hotkey_z"), Default: HotkeyZ, Edit: "HotkeyZEdit", Desc: "hotkey_z_desc", Hint: "hotkey_single_char_hint", DefaultVal: "z"},
        {Key: "S", Name: GetText("hotkey_s"), Default: SplitHotkey, Edit: "SplitHotkeyEdit", Desc: "hotkey_s_desc", Hint: "hotkey_single_char_hint", DefaultVal: "s"},
        {Key: "B", Name: GetText("hotkey_b"), Default: BatchHotkey, Edit: "BatchHotkeyEdit", Desc: "hotkey_b_desc", Hint: "hotkey_single_char_hint", DefaultVal: "b"},
        {Key: "T", Name: GetText("hotkey_t"), Default: HotkeyT, Edit: "HotkeyTEdit", Desc: "hotkey_t_desc", Hint: "hotkey_single_char_hint", DefaultVal: "t"}
    ]
    
    ; 创建横向标签按钮（十一个选项一行显示）
    ; 计算每个标签的宽度，确保11个标签能在一行显示
    TabSpacing := 2  ; 标签之间的间距
    TotalSpacing := TabSpacing * (HotkeyList.Length - 1)  ; 总间距
    TabWidth := (W - 60 - TotalSpacing) / HotkeyList.Length  ; 每个标签的宽度
    TabX := X + 30
    HotkeySubTabs := Map()
    global HotkeySubTabControls := Map()  ; 确保是全局变量
    
    ; 创建横向标签点击处理函数（避免闭包问题）
    CreateHotkeyTabClickHandler(Key) {
        return (*) => SwitchHotkeyTab(Key)
    }
    
    for Index, Item in HotkeyList {
        ; 创建横向标签按钮，确保可以点击
        ; 使用 Text 控件模拟 Material 风格按钮
        TabBtn := ConfigGUI.Add("Text", "x" . TabX . " y" . (TabBarY + 5) . " w" . TabWidth . " h" . (TabBarHeight - 10) . " Center 0x200 vHotkeyTab" . Item.Key, Item.Name)
        TabBtn.SetFont("s8", "Segoe UI")  ; 减小字体以适应一行显示
        
        ; 使用主题颜色：默认未选中状态
        TabBtn.Opt("+Background" . UI_Colors.Sidebar)
        TabBtn.SetFont("s8 c" . UI_Colors.TextDim, "Segoe UI")
        
        ; 绑定点击事件
        TabBtn.OnEvent("Click", CreateHotkeyTabClickHandler(Item.Key))
        ; 悬停效果使用主题颜色（带动效）
        HoverBtnWithAnimation(TabBtn, UI_Colors.Sidebar, UI_Colors.BtnHover)
        ; 【架构修复】快捷键子标签按钮只属于 "settings" 主标签页，不添加到 HotkeysTabControls（公共控件列表）
        ; 这样 SwitchHotkeysMainTab 可以统一管理其显示/隐藏
        HotkeySubTabs[Item.Key] := TabBtn
        TabX += TabWidth + TabSpacing  ; 添加间距
    }
    
    global HotkeySubTabs := HotkeySubTabs
    
    ; 快捷键设置内容区域
    HotkeySettingsContentY := TabBarY + TabBarHeight + 20
    HotkeySettingsContentHeight := ContentAreaHeight - (HotkeySettingsContentY - ContentAreaY) - 20
    
    ; 为每个快捷键创建内容面板
    ; 注意：内容可以超出 ContentAreaHeight，通过滚动查看
    for Index, Item in HotkeyList {
        ; 传入更大的高度值，允许内容超出可视区域
        CreateHotkeySubTab(ConfigGUI, X + 30, HotkeySettingsContentY, W - 60, HotkeySettingsContentHeight + 500, Item)
    }
    
    ; 将快捷键设置相关的控件添加到主标签控件映射中
    HotkeysMainTabControls["settings"] := [TabBarBg]
    for Index, Item in HotkeyList {
        if (HotkeySubTabControls.Has(Item.Key)) {
            if (!HotkeysMainTabControls.Has("settings")) {
                HotkeysMainTabControls["settings"] := []
            }
            for Ctrl in HotkeySubTabControls[Item.Key] {
                HotkeysMainTabControls["settings"].Push(Ctrl)
            }
        }
    }
    ; 添加快捷键子标签按钮
    for Key, TabBtn in HotkeySubTabs {
        HotkeysMainTabControls["settings"].Push(TabBtn)
    }
    
    ; ========== 快操作按钮主标签页内容 ==========
    QuickActionContentY := ContentAreaY
    QuickActionContentHeight := ContentAreaHeight
    HotkeysMainTabControls["quickaction"] := []
    
    ; 描述文字
    QuickActionDesc := ConfigGUI.Add("Text", "x" . (X + 30) . " y" . (QuickActionContentY + 10) . " w" . (W - 60) . " h20 c" . UI_Colors.TextDim . " vHotkeysQuickActionDesc", GetText("quick_action_config_desc"))
    QuickActionDesc.SetFont("s9", "Segoe UI")
    QuickActionDesc.Visible := false
    HotkeysMainTabControls["quickaction"].Push(QuickActionDesc)
    ; 【架构修复】QuickActionDesc 只属于 "quickaction" 主标签页，不添加到 HotkeysTabControls
    
    ; 创建快操作按钮配置UI
    global QuickActionConfigControls := []
    CreateQuickActionConfigUI(ConfigGUI, X + 30, QuickActionContentY + 35, W - 60, HotkeysMainTabControls["quickaction"])
    ; 【架构修复】快操作按钮配置控件只属于 "quickaction" 主标签页，不添加到 HotkeysTabControls
    ; 这些控件由 SwitchHotkeysMainTab 统一管理显示/隐藏
    for Index, Ctrl in QuickActionConfigControls {
        try {
            Ctrl.Visible := false
        } catch as err {
        }
    }
    
    ; ========== 搜索标签主标签页内容 ==========
    SearchCategoryContentY := ContentAreaY
    SearchCategoryContentHeight := ContentAreaHeight
    HotkeysMainTabControls["searchcategory"] := []
    
    ; 描述文字
    SearchCategoryDesc := ConfigGUI.Add("Text", "x" . (X + 30) . " y" . (SearchCategoryContentY + 20) . " w" . (W - 60) . " h20 c" . UI_Colors.TextDim . " vHotkeysSearchCategoryDesc", GetText("search_category_config_desc"))
    SearchCategoryDesc.SetFont("s9", "Segoe UI")
    SearchCategoryDesc.Visible := false
    HotkeysMainTabControls["searchcategory"].Push(SearchCategoryDesc)
    ; 【架构修复】SearchCategoryDesc 只属于 "searchcategory" 主标签页，不添加到 HotkeysTabControls
    
    ; 创建搜索标签配置UI
    global SearchCategoryConfigControls := []
    CreateSearchCategoryConfigUI(ConfigGUI, X + 30, SearchCategoryContentY + 50, W - 60, HotkeysMainTabControls["searchcategory"])
    ; 【架构修复】搜索标签配置控件只属于 "searchcategory" 主标签页，不添加到 HotkeysTabControls
    ; 这些控件由 SwitchHotkeysMainTab 统一管理显示/隐藏
    for Index, Ctrl in SearchCategoryConfigControls {
        try {
            Ctrl.Visible := false
        } catch as err {
        }
    }
    
    ; 默认显示第一个主标签页（快捷操作按钮）
    SwitchHotkeysMainTab("quickaction")
}

; ===================== 创建快捷键子标签页 =====================
CreateHotkeySubTab(ConfigGUI, X, Y, W, H, Item) {
    global HotkeysTabControls, HotkeySubTabControls, UI_Colors
    global HotkeyESC, HotkeyC, HotkeyV, HotkeyX, HotkeyE, HotkeyR, HotkeyO, HotkeyQ, HotkeyZ, HotkeyT
    global SplitHotkey, BatchHotkey
    global HotkeyESCEdit, HotkeyCEdit, HotkeyVEdit, HotkeyXEdit, HotkeyEEdit, HotkeyREdit, HotkeyOEdit, HotkeyQEdit, HotkeyZEdit, HotkeyTEdit
    global SplitHotkeyEdit, BatchHotkeyEdit
    
    ; 初始化子标签页控件数组
    if (!HotkeySubTabControls.Has(Item.Key)) {
        HotkeySubTabControls[Item.Key] := []
    }
    
    ; 创建子标签页面板（默认隐藏，作为背景）
    ; 注意：不添加到 HotkeysTabControls，只添加到 HotkeySubTabControls
    SubTabPanel := ConfigGUI.Add("Text", "x" . X . " y" . Y . " w" . W . " h" . H . " Background" . UI_Colors.Background . " vHotkeySubTab" . Item.Key, "")
    SubTabPanel.Visible := false
    HotkeySubTabControls[Item.Key].Push(SubTabPanel)
    
    ; ========== 功能演示板块（居中显示，占据更多空间）==========
    ; 图片区域从顶部开始，居中显示（去掉标题，直接显示图片）
    AnimX := X + 30  ; 从左侧边距开始
    AnimY := Y + 20  ; 从顶部开始，去掉标题
    AnimWidth := W - 60  ; 占据整个宽度（减去左右边距）
    ; 计算可用高度：参考屏幕高度，确保图片不会太高，留出下方空间
    ; 使用屏幕高度的70%作为最大图片容器高度，确保下方有足够空间
    global ConfigHeight
    MaxImageHeight := Round(ConfigHeight * 0.7)  ; 屏幕高度的70%
    AvailableHeight := H - (AnimY - Y) - 150  ; 预留150px给底部空间（按钮等）
    ; 取两者中的较小值，确保图片不会太高
    AnimHeight := Min(AvailableHeight, MaxImageHeight)
    
    ; 图片显示区域（保持比例，不拉伸）
    ImagePath := GetHotkeyImagePath(Item.Key)
    
    ; 创建一个容器背景（始终创建，用于显示图片或提示）
    PictureBg := ConfigGUI.Add("Text", "x" . AnimX . " y" . AnimY . " w" . AnimWidth . " h" . AnimHeight . " Background" . UI_Colors.InputBg . " vHotkeyPicBg" . Item.Key, "")
    HotkeySubTabControls[Item.Key].Push(PictureBg)
    
    if (FileExist(ImagePath)) {
        ; 获取图片实际尺寸
        ImageSize := GetImageSize(ImagePath)
        
        ; 计算保持比例的显示尺寸
        DisplaySize := CalculateImageDisplaySize(ImageSize.Width, ImageSize.Height, AnimWidth, AnimHeight)
        
        ; 计算居中位置
        DisplayX := AnimX + (AnimWidth - DisplaySize.Width) // 2
        DisplayY := AnimY + (AnimHeight - DisplaySize.Height) // 2
        
        try {
            ; 使用计算好的尺寸和位置显示图片，保持原比例
            ; 使用 0x200 (SS_CENTERIMAGE) 样式保持图片居中
            PictureCtrl := ConfigGUI.Add("Picture", "x" . DisplayX . " y" . DisplayY . " w" . DisplaySize.Width . " h" . DisplaySize.Height . " 0x200 vHotkeyPic" . Item.Key, ImagePath)
            HotkeySubTabControls[Item.Key].Push(PictureCtrl)
        } catch as e {
            ; 如果加载失败，显示错误信息
            ErrorText := ConfigGUI.Add("Text", "x" . AnimX . " y" . AnimY . " w" . AnimWidth . " h" . AnimHeight . " Center c" . UI_Colors.TextDim . " Background" . UI_Colors.InputBg . " vHotkeyPicError" . Item.Key, "图片加载失败`n`n错误: " . e.Message . "`n`n路径: " . ImagePath)
            ErrorText.SetFont("s9", "Segoe UI")
            HotkeySubTabControls[Item.Key].Push(ErrorText)
        }
    } else {
        ; 如果图片不存在，显示提示文本（包含完整路径和脚本目录）
        NoImageText := ConfigGUI.Add("Text", "x" . AnimX . " y" . AnimY . " w" . AnimWidth . " h" . AnimHeight . " Center c" . UI_Colors.TextDim . " Background" . UI_Colors.InputBg . " vHotkeyNoPic" . Item.Key, "图片文件未找到`n`n请将图片保存为:`n" . ImagePath . "`n`n当前脚本目录: " . A_ScriptDir)
        NoImageText.SetFont("s9", "Segoe UI")
        HotkeySubTabControls[Item.Key].Push(NoImageText)
    }
}

; ===================== 获取图片尺寸 =====================
GetImageSize(ImagePath) {
    ; 使用 Windows API 获取图片的实际尺寸
    try {
        ; 使用 LoadImage 加载图片获取尺寸
        hBitmap := DllCall("user32.dll\LoadImage", "UInt", 0, "Str", ImagePath, "UInt", 0, "Int", 0, "Int", 0, "UInt", 0x10, "Ptr")  ; LR_LOADFROMFILE = 0x10
        if (hBitmap) {
            ; 获取位图信息
            bm := Buffer(A_PtrSize = 8 ? 32 : 24, 0)
            DllCall("gdi32.dll\GetObject", "Ptr", hBitmap, "Int", A_PtrSize = 8 ? 32 : 24, "Ptr", bm, "Int")
            Width := NumGet(bm, 4, "Int")
            Height := NumGet(bm, 8, "Int")
            DllCall("gdi32.dll\DeleteObject", "Ptr", hBitmap, "Ptr")
            return {Width: Width, Height: Height}
        }
    } catch as err {
        ; 如果获取失败，尝试使用 GDI+
        try {
            ; 初始化 GDI+
            Input := Buffer(A_PtrSize = 8 ? 24 : 16, 0)
            NumPut("UInt", 1, Input, 0)  ; GdiplusVersion = 1
            DllCall("gdiplus.dll\GdipStartup", "Ptr*", &GdiplusToken := 0, "Ptr", Input, "Ptr", 0, "Int")
            
            ; 创建 GDI+ 位图对象
            DllCall("gdiplus.dll\GdipCreateBitmapFromFile", "WStr", ImagePath, "Ptr*", &pBitmap := 0, "Int")
            if (pBitmap) {
                ; 获取图片宽度和高度
                DllCall("gdiplus.dll\GdipGetImageWidth", "Ptr", pBitmap, "UInt*", &Width := 0, "Int")
                DllCall("gdiplus.dll\GdipGetImageHeight", "Ptr", pBitmap, "UInt*", &Height := 0, "Int")
                DllCall("gdiplus.dll\GdipDisposeImage", "Ptr", pBitmap, "Int")
                return {Width: Width, Height: Height}
            }
        } catch as err {
            ; 如果都失败，返回默认值
        }
    }
    return {Width: 0, Height: 0}
}

; ===================== 计算保持比例的图片显示尺寸 =====================
CalculateImageDisplaySize(ImageWidth, ImageHeight, ContainerWidth, ContainerHeight) {
    ; 计算保持原比例的图片显示尺寸
    if (ImageWidth = 0 || ImageHeight = 0) {
        ; 如果无法获取图片尺寸，使用容器尺寸
        return {Width: ContainerWidth, Height: ContainerHeight}
    }
    
    ; 计算宽高比
    ImageRatio := ImageWidth / ImageHeight
    ContainerRatio := ContainerWidth / ContainerHeight
    
    ; 根据比例计算合适的显示尺寸
    if (ImageRatio > ContainerRatio) {
        ; 图片更宽，以宽度为准
        DisplayWidth := ContainerWidth
        DisplayHeight := Round(ContainerWidth / ImageRatio)
    } else {
        ; 图片更高，以高度为准
        DisplayHeight := ContainerHeight
        DisplayWidth := Round(ContainerHeight * ImageRatio)
    }
    
    return {Width: DisplayWidth, Height: DisplayHeight}
}

; ===================== 获取快捷键图片路径 =====================
GetHotkeyImagePath(HotkeyKey) {
    ; 返回快捷键对应的图片路径
    ; 图片文件应放在脚本目录下的 images 文件夹中
    ImageDir := A_ScriptDir . "\images"
    switch HotkeyKey {
        case "C":
            return ImageDir . "\hotkey_c.png"
        case "V":
            return ImageDir . "\hotkey_v.png"
        case "X":
            return ImageDir . "\hotkey_x.png"
        case "E":
            return ImageDir . "\hotkey_e.png"
        case "R":
            return ImageDir . "\hotkey_r.png"
        case "O":
            return ImageDir . "\hotkey_o.png"
        case "Q":
            return ImageDir . "\hotkey_q.png"
        case "Z":
            return ImageDir . "\hotkey_z.png"
        case "S":
            return ImageDir . "\hotkey_s.png"
        case "B":
            return ImageDir . "\hotkey_b.png"
        case "P":
            return ImageDir . "\hotkey_t.png"
        case "ESC":
            return ImageDir . "\hotkey_esc.png"
        default:
            return ImageDir . "\hotkey_default.png"
    }
}

; ===================== 创建快捷键动画文本 =====================
CreateHotkeyAnimation(HotkeyKey) {
    switch HotkeyKey {
        case "ESC":
            return "1. 【操作步骤】`n`n   1.1 长按 CapsLock 键`n   1.2 快捷操作面板自动显示`n   1.3 按下 ESC 键`n   1.4 面板立即关闭`n`n2. 【使用场景】`n`n   2.1 快速关闭已打开的面板`n   2.2 取消当前操作`n   2.3 返回正常工作状态`n`n3. 【实现效果】`n`n   3.1 面板瞬间关闭`n   3.2 不影响其他操作`n   3.3 可随时重新打开"
        case "C":
            return "1. 【操作步骤】`n`n   1.1 选中第一段文本`n   1.2 长按 CapsLock + C`n   1.3 选中第二段文本`n   1.4 再次按 CapsLock + C`n   1.5 可继续复制更多内容`n`n2. 【使用场景】`n`n   2.1 需要复制多段不连续的内容`n   2.2 收集多个代码片段`n   2.3 批量收集文本信息`n`n3. 【实现效果】`n`n   3.1 所有内容保存到历史`n   3.2 支持无限次连续复制`n   3.3 使用 CapsLock+V 合并粘贴"
        case "V":
            return "1. 【操作步骤】`n`n   1.1 使用 CapsLock+C 复制多段内容`n   1.2 长按 CapsLock + V`n   1.3 所有内容自动合并`n   1.4 粘贴到 Cursor 中`n`n2. 【使用场景】`n`n   2.1 将多个代码片段合并粘贴`n   2.2 组合多个文本段落`n   2.3 批量内容一次性插入`n`n3. 【实现效果】`n`n   3.1 自动打开 Cursor`n   3.2 内容按顺序合并`n   3.3 一键完成所有操作"
        case "X":
            return "1. 【操作步骤】`n`n   1.1 长按 CapsLock`n   1.2 按下 X 键`n   1.3 剪贴板管理面板打开`n   1.4 查看所有复制历史`n   1.5 双击或选择后操作`n`n2. 【使用场景】`n`n   2.1 查看所有复制历史`n   2.2 选择特定内容粘贴`n   2.3 管理剪贴板记录`n`n3. 【实现效果】`n`n   3.1 显示所有历史记录`n   3.2 支持快速复制`n   3.3 可删除不需要的项目"
        case "E":
            return "1. 【操作步骤】`n`n   1.1 在 Cursor 中选中代码`n   1.2 长按 CapsLock`n   1.3 按下 E 键`n   1.4 AI 自动分析代码`n   1.5 显示解释结果`n`n2. 【使用场景】`n`n   2.1 理解复杂代码逻辑`n   2.2 学习新代码库`n   2.3 快速了解函数功能`n`n3. 【实现效果】`n`n   3.1 AI 自动解释代码`n   3.2 用通俗语言说明`n   3.3 标注关键点和易错点"
        case "R":
            return "1. 【操作步骤】`n`n   1.1 在 Cursor 中选中代码`n   1.2 长按 CapsLock`n   1.3 按下 R 键`n   1.4 AI 自动重构代码`n   1.5 显示优化后的代码`n`n2. 【使用场景】`n`n   2.1 改进代码结构`n   2.2 遵循编码规范`n   2.3 提升代码可读性`n`n3. 【实现效果】`n`n   3.1 自动重构代码`n   3.2 添加中文注释`n   3.3 保持功能不变"
        case "O":
            return "1. 【操作步骤】`n`n   1.1 在 Cursor 中选中代码`n   1.2 长按 CapsLock`n   1.3 按下 O 键`n   1.4 AI 分析性能瓶颈`n   1.5 提供优化方案`n`n2. 【使用场景】`n`n   2.1 优化代码性能`n   2.2 分析复杂度问题`n   2.3 提升执行效率`n`n3. 【实现效果】`n`n   3.1 分析时间/空间复杂度`n   3.2 提供优化对比`n   3.3 保留原逻辑可读性"
        case "Q":
            return "1. 【操作步骤】`n`n   1.1 长按 CapsLock`n   1.2 按下 Q 键`n   1.3 配置面板自动打开`n   1.4 进行各种设置`n   1.5 保存配置生效`n`n2. 【使用场景】`n`n   2.1 自定义快捷键`n   2.2 调整提示词`n   2.3 修改面板位置`n`n3. 【实现效果】`n`n   3.1 配置立即生效`n   3.2 支持导入导出`n   3.3 可重置为默认值"
        case "Z":
            return "1. 【操作步骤】`n`n   1.1 长按 CapsLock`n   1.2 按下 Z 键启动`n   1.3 开始说话录入`n   1.4 再次按 Z 结束`n   1.5 内容自动发送`n`n2. 【使用场景】`n`n   2.1 快速输入长文本`n   2.2 语音转文字`n   2.3 解放双手输入`n`n3. 【实现效果】`n`n   3.1 支持百度/讯飞输入法`n   3.2 实时语音识别`n   3.3 自动发送到 Cursor"
        case "S":
            return "1. 【操作步骤】`n`n   1.1 长按 CapsLock 显示面板`n   1.2 在 Cursor 中选中代码`n   1.3 按下 S 键`n   1.4 插入分割标记`n   1.5 可继续选择其他代码`n`n2. 【使用场景】`n`n   2.1 标记代码分段位置`n   2.2 准备批量处理`n   2.3 组织代码结构`n`n3. 【实现效果】`n`n   3.1 自动插入标记`n   3.2 支持多次标记`n   3.3 便于后续处理"
        case "B":
            return "1. 【操作步骤】`n`n   1.1 长按 CapsLock 显示面板`n   1.2 在 Cursor 中选中代码`n   1.3 按下 B 键`n   1.4 执行批量操作`n   1.5 处理所有标记的代码`n`n2. 【使用场景】`n`n   2.1 批量处理多段代码`n   2.2 统一执行操作`n   2.3 提高工作效率`n`n3. 【实现效果】`n`n   3.1 自动识别标记`n   3.2 批量处理代码`n   3.3 一次性完成操作"
        case "P":
            return "1. 【操作步骤】`n`n   1.1 长按 CapsLock`n   1.2 按下 P 键启动截图`n   1.3 选择截图区域`n   1.4 截图自动粘贴到 Cursor`n   1.5 手动发送到 AI`n`n2. 【使用场景】`n`n   2.1 截图代码或界面`n   2.2 快速分享屏幕内容`n   2.3 向 AI 展示视觉信息`n`n3. 【实现效果】`n`n   3.1 使用 Windows 截图工具`n   3.2 自动激活 Cursor`n   3.3 截图粘贴到输入框，等待您发送"
        default:
            return "操作说明"
    }
}

; ===================== 更新快捷键动画 =====================
UpdateHotkeyAnimation(AnimArea, HotkeyKey) {
    global VoiceInputActive
    
    ; 检查控件是否还存在
    try {
        if (!AnimArea || !AnimArea.Hwnd) {
            return  ; 控件已销毁，停止更新
        }
    } catch as err {
        return  ; 控件已销毁，停止更新
    }
    
    ; 为不同快捷键提供不同的动画效果
    static AnimStates := Map()
    if (!AnimStates.Has(HotkeyKey)) {
        AnimStates[HotkeyKey] := 0
    }
    
    AnimStates[HotkeyKey] := Mod(AnimStates[HotkeyKey] + 1, 4)
    CurrentState := AnimStates[HotkeyKey]
    
    ; 只更新图形动画，不包含文字说明（文字说明在左侧独立板块）
    try {
        switch HotkeyKey {
            case "ESC":
                AnimArea.Text := CreateGraphicAnimation("ESC", CurrentState)
            case "C":
                ; CapsLock + C 使用图片显示，不再使用动画
                return
            case "V":
                AnimArea.Text := CreateGraphicAnimation("V", CurrentState)
            case "X":
                AnimArea.Text := CreateGraphicAnimation("X", CurrentState)
            case "E":
                AnimArea.Text := CreateGraphicAnimation("E", CurrentState)
            case "R":
                AnimArea.Text := CreateGraphicAnimation("R", CurrentState)
            case "O":
                AnimArea.Text := CreateGraphicAnimation("O", CurrentState)
            case "Q":
                AnimArea.Text := CreateGraphicAnimation("Q", CurrentState)
            case "Z":
                AnimArea.Text := CreateGraphicAnimation("Z", CurrentState, VoiceInputActive)
            case "S":
                AnimArea.Text := CreateGraphicAnimation("S", CurrentState)
            case "B":
                AnimArea.Text := CreateGraphicAnimation("B", CurrentState)
            case "P":
                AnimArea.Text := CreateGraphicAnimation("P", CurrentState)
            default:
                AnimArea.Text := CreateGraphicAnimation(HotkeyKey, CurrentState)
        }
    } catch as err {
        ; 控件已销毁，忽略错误
    }
}

; ===================== 创建图形动画 =====================
CreateGraphicAnimation(HotkeyKey, State, VoiceActive := false) {
    switch HotkeyKey {
        case "ESC":
            switch State {
                case 0: return "      ┌──────────┐`n      │ CapsLock  │`n      │  [按下]   │`n      └─────┬────┘`n            │`n            ▼`n      ┌──────────┐`n      │ 面板显示  │`n      │ [显示中]  │`n      └─────┬────┘`n            │`n            ▼`n      ┌──────────┐`n      │ 按ESC键   │`n      │  [等待]  │`n      └──────────┘"
                case 1: return "      ┌──────────┐`n      │ CapsLock  │`n      │  [按下]   │`n      └─────┬────┘`n            │`n            ▼`n      ┌──────────┐`n      │ 面板显示  │`n      │ [已显示]  │`n      └─────┬────┘`n            │`n            ▼`n      ┌──────────┐`n      │ 按ESC键   │`n      │  [按下]  │`n      └─────┬────┘`n            │`n            ▼`n      ┌──────────┐`n      │ 面板关闭  │`n      │  [关闭]  │`n      └──────────┘"
                case 2: return "      ┌──────────┐`n      │ CapsLock  │`n      │  [按下]   │`n      └─────┬────┘`n            │`n            ▼`n      ┌──────────┐`n      │ 面板显示  │`n      │ [显示中]  │`n      └─────┬────┘`n            │`n            ▼`n      ┌──────────┐`n      │ 按ESC键   │`n      │  [等待]  │`n      └──────────┘"
                case 3: return "      ┌──────────┐`n      │ CapsLock  │`n      │  [按下]   │`n      └─────┬────┘`n            │`n            ▼`n      ┌──────────┐`n      │ 面板显示  │`n      │ [已显示]  │`n      └─────┬────┘`n            │`n            ▼`n      ┌──────────┐`n      │ 按ESC键   │`n      │  [按下]  │`n      └─────┬────┘`n            │`n            ▼`n      ┌──────────┐`n      │ 面板关闭  │`n      │  [关闭]  │`n      └──────────┘"
            }
        case "C":
            ; CapsLock + C 使用图片显示，不再使用文本动画
            return ""
        case "V":
            switch State {
                case 0: return "      ┌──────────┐`n      │  剪贴板   │`n      │ [N项内容] │`n      └─────┬────┘`n            │`n            ▼`n      ┌──────────┐`n      │CapsLock+V │`n      │  [按下]  │`n      └─────┬────┘`n            │`n            ▼`n      ┌──────────┐`n      │打开Cursor │`n      │ [启动中]  │`n      └──────────┘"
                case 1: return "      ┌──────────┐`n      │  剪贴板   │`n      │ [N项内容] │`n      └─────┬────┘`n            │`n            ▼`n      ┌──────────┐`n      │CapsLock+V │`n      │  [按下]  │`n      └─────┬────┘`n            │`n            ▼`n      ┌──────────┐`n      │打开Cursor │`n      │ [已打开]  │`n      └─────┬────┘`n            │`n            ▼`n      ┌──────────┐`n      │ 合并内容  │`n      │ [处理中]  │`n      └──────────┘"
                case 2: return "      ┌──────────┐`n      │  剪贴板   │`n      │ [N项内容] │`n      └─────┬────┘`n            │`n            ▼`n      ┌──────────┐`n      │CapsLock+V │`n      │  [按下]  │`n      └─────┬────┘`n            │`n            ▼`n      ┌──────────┐`n      │打开Cursor │`n      │ [已打开]  │`n      └─────┬────┘`n            │`n            ▼`n      ┌──────────┐`n      │ 合并内容  │`n      │ [已完成]  │`n      └─────┬────┘`n            │`n            ▼`n      ┌──────────┐`n      │  粘贴中   │`n      │  [处理]   │`n      └──────────┘"
                case 3: return "      ┌──────────┐`n      │  剪贴板   │`n      │ [N项内容] │`n      └─────┬────┘`n            │`n            ▼`n      ┌──────────┐`n      │CapsLock+V │`n      │  [按下]  │`n      └─────┬────┘`n            │`n            ▼`n      ┌──────────┐`n      │打开Cursor │`n      │ [已打开]  │`n      └─────┬────┘`n            │`n            ▼`n      ┌──────────┐`n      │ 合并内容  │`n      │ [已完成]  │`n      └─────┬────┘`n            │`n            ▼`n      ┌──────────┐`n      │ 粘贴完成  │`n      │ [✓完成]  │`n      └──────────┘"
            }
        case "E", "R", "O":
            ActionName := (HotkeyKey = "E") ? "解释" : (HotkeyKey = "R") ? "重构" : "优化"
            switch State {
                case 0: return "      ┌──────────────┐`n      │   选中代码    │`n      │  [代码片段]  │`n      └──────┬───────┘`n             │`n             ▼`n      ┌──────────────┐`n      │  AI" . ActionName . "处理  │`n      │  [分析中...] │`n      └──────┬───────┘`n             │`n             ▼`n      ┌──────────────┐`n      │   生成结果    │`n      │  [处理中...]  │`n      └──────────────┘"
                case 1: return "      ┌──────────────┐`n      │   选中代码    │`n      │  [代码片段]  │`n      └──────┬───────┘`n             │`n             ▼`n      ┌──────────────┐`n      │  AI" . ActionName . "处理  │`n      │  [分析完成] ✓│`n      └──────┬───────┘`n             │`n             ▼`n      ┌──────────────┐`n      │   生成结果    │`n      │  [处理中...]  │`n      └──────────────┘"
                case 2: return "      ┌──────────────┐`n      │   选中代码    │`n      │  [代码片段]  │`n      └──────┬───────┘`n             │`n             ▼`n      ┌──────────────┐`n      │  AI" . ActionName . "处理  │`n      │  [分析完成] ✓│`n      └──────┬───────┘`n             │`n             ▼`n      ┌──────────────┐`n      │   生成结果    │`n      │  [处理中...]  │`n      └──────────────┘"
                case 3: return "      ┌──────────────┐`n      │   选中代码    │`n      │  [代码片段]  │`n      └──────┬───────┘`n             │`n             ▼`n      ┌──────────────┐`n      │  AI" . ActionName . "处理  │`n      │  [分析完成] ✓│`n      └──────┬───────┘`n             │`n             ▼`n      ┌──────────────┐`n      │   生成结果    │`n      │  [已完成] ✓  │`n      └──────────────┘"
            }
        case "Z":
            if (VoiceActive) {
                switch State {
                    case 0: return "      ┌──────────┐`n      │CapsLock+Z │`n      │  [按下]  │`n      └─────┬────┘`n            │`n            ▼`n      ┌──────────┐`n      │ 语音输入  │`n      │  ● ○ ○   │`n      │ [启动中]  │`n      └──────────┘"
                    case 1: return "      ┌──────────┐`n      │CapsLock+Z │`n      │  [按下]  │`n      └─────┬────┘`n            │`n            ▼`n      ┌──────────┐`n      │ 语音输入  │`n      │  ○ ● ○   │`n      │ [识别中]  │`n      └──────────┘"
                    case 2: return "      ┌──────────┐`n      │CapsLock+Z │`n      │  [按下]  │`n      └─────┬────┘`n            │`n            ▼`n      ┌──────────┐`n      │ 语音输入  │`n      │  ○ ○ ●   │`n      │ [处理中]  │`n      └──────────┘"
                    case 3: return "      ┌──────────┐`n      │CapsLock+Z │`n      │  [按下]  │`n      └─────┬────┘`n            │`n            ▼`n      ┌──────────┐`n      │ 语音输入  │`n      │  ● ● ●   │`n      │ [录入中]  │`n      └──────────┘"
                }
            } else {
                switch State {
                    case 0: return "      ┌──────────┐`n      │CapsLock+Z │`n      │  [按下]  │`n      └─────┬────┘`n            │`n            ▼`n      ┌──────────┐`n      │ 启动语音  │`n      │  ● ○ ○   │`n      │ [启动中]  │`n      └──────────┘"
                    case 1: return "      ┌──────────┐`n      │CapsLock+Z │`n      │  [按下]  │`n      └─────┬────┘`n            │`n            ▼`n      ┌──────────┐`n      │ 启动语音  │`n      │  ○ ● ○   │`n      │ [识别中]  │`n      └─────┬────┘`n            │`n            ▼`n      ┌──────────┐`n      │ 开始说话  │`n      │  [等待]  │`n      └──────────┘"
                    case 2: return "      ┌──────────┐`n      │CapsLock+Z │`n      │  [按下]  │`n      └─────┬────┘`n            │`n            ▼`n      ┌──────────┐`n      │ 启动语音  │`n      │  ○ ○ ●   │`n      │ [处理中]  │`n      └─────┬────┘`n            │`n            ▼`n      ┌──────────┐`n      │ 开始说话  │`n      │ [已启动]  │`n      └─────┬────┘`n            │`n            ▼`n      ┌──────────┐`n      │ 语音识别  │`n      │ [进行中]  │`n      └──────────┘"
                    case 3: return "      ┌──────────┐`n      │CapsLock+Z │`n      │  [按下]  │`n      └─────┬────┘`n            │`n            ▼`n      ┌──────────┐`n      │ 启动语音  │`n      │  ● ● ●   │`n      │ [已完成]  │`n      └─────┬────┘`n            │`n            ▼`n      ┌──────────┐`n      │ 开始说话  │`n      │ [已启动]  │`n      └─────┬────┘`n            │`n            ▼`n      ┌──────────┐`n      │ 语音识别  │`n      │ [进行中]  │`n      └─────┬────┘`n            │`n            ▼`n      ┌──────────┐`n      │发送到Cursor│`n      │ [✓完成]  │`n      └──────────┘"
                }
            }
        case "X":
            switch State {
                case 0: return "      ┌──────────────┐`n      │ 剪贴板管理面板 │`n      │  [打开中...]  │`n      └──────┬───────┘`n             │`n             ▼`n      ┌──────────────┐`n      │ 显示历史记录  │`n      │  [加载中...]  │`n      └──────────────┘"
                case 1: return "      ┌──────────────┐`n      │ 剪贴板管理面板 │`n      │  [已打开] ✓  │`n      └──────┬───────┘`n             │`n             ▼`n      ┌──────────────┐`n      │ 显示历史记录  │`n      │  [已加载] ✓  │`n      └──────────────┘"
                case 2: return "      ┌──────────────┐`n      │ 剪贴板管理面板 │`n      │  [已打开] ✓  │`n      └──────┬───────┘`n             │`n             ▼`n      ┌──────────────┐`n      │ 显示历史记录  │`n      │  [已加载] ✓  │`n      └──────────────┘"
                case 3: return "      ┌──────────────┐`n      │ 剪贴板管理面板 │`n      │  [已打开] ✓  │`n      └──────┬───────┘`n             │`n             ▼`n      ┌──────────────┐`n      │ 显示历史记录  │`n      │  [已加载] ✓  │`n      └──────────────┘"
            }
        case "Q":
            switch State {
                case 0: return "      ┌──────────────┐`n      │   配置面板    │`n      │  [打开中...]  │`n      └──────┬───────┘`n             │`n             ▼`n      ┌──────────────┐`n      │ 加载配置选项  │`n      │  [加载中...]  │`n      └──────────────┘"
                case 1: return "      ┌──────────────┐`n      │   配置面板    │`n      │  [已打开] ✓  │`n      └──────┬───────┘`n             │`n             ▼`n      ┌──────────────┐`n      │ 加载配置选项  │`n      │  [已加载] ✓  │`n      └──────────────┘"
                case 2: return "      ┌──────────────┐`n      │   配置面板    │`n      │  [已打开] ✓  │`n      └──────┬───────┘`n             │`n             ▼`n      ┌──────────────┐`n      │ 加载配置选项  │`n      │  [已加载] ✓  │`n      └──────────────┘"
                case 3: return "      ┌──────────────┐`n      │   配置面板    │`n      │  [已打开] ✓  │`n      └──────┬───────┘`n             │`n             ▼`n      ┌──────────────┐`n      │ 加载配置选项  │`n      │  [已加载] ✓  │`n      └──────────────┘"
            }
        case "S":
            switch State {
                case 0: return "      ┌──────────────┐`n      │   代码片段1   │`n      │  [已标记] ✓  │`n      └──────────────┘`n            +`n      ┌──────────────┐`n      │   代码片段2   │`n      │  [已标记] ✓  │`n      └──────────────┘`n            │`n            ▼`n      ┌──────────────┐`n      │ 插入分割标记 │`n      │  [标记中...] │`n      └──────────────┘"
                case 1: return "      ┌──────────────┐`n      │   代码片段1   │`n      │  [已标记] ✓  │`n      └──────────────┘`n            +`n      ┌──────────────┐`n      │   代码片段2   │`n      │  [已标记] ✓  │`n      └──────────────┘`n            │`n            ▼`n      ┌──────────────┐`n      │ 插入分割标记 │`n      │  [标记完成] ✓│`n      └──────────────┘"
                case 2: return "      ┌──────────────┐`n      │   代码片段1   │`n      │  [已标记] ✓  │`n      └──────────────┘`n            +`n      ┌──────────────┐`n      │   代码片段2   │`n      │  [已标记] ✓  │`n      └──────────────┘`n            │`n            ▼`n      ┌──────────────┐`n      │ 插入分割标记 │`n      │  [标记完成] ✓│`n      └──────────────┘"
                case 3: return "      ┌──────────────┐`n      │   代码片段1   │`n      │  [已标记] ✓  │`n      └──────────────┘`n            +`n      ┌──────────────┐`n      │   代码片段2   │`n      │  [已标记] ✓  │`n      └──────────────┘`n            │`n            ▼`n      ┌──────────────┐`n      │ 插入分割标记 │`n      │  [标记完成] ✓│`n      └──────────────┘"
            }
        case "B":
            switch State {
                case 0: return "      ┌──────────────┐`n      │   代码片段1   │`n      │  [已标记] ✓  │`n      └──────────────┘`n            +`n      ┌──────────────┐`n      │   代码片段2   │`n      │  [已标记] ✓  │`n      └──────────────┘`n            │`n            ▼`n      ┌──────────────┐`n      │ 批量处理执行  │`n      │  [处理中...]  │`n      └──────────────┘"
                case 1: return "      ┌──────────────┐`n      │   代码片段1   │`n      │  [已标记] ✓  │`n      └──────────────┘`n            +`n      ┌──────────────┐`n      │   代码片段2   │`n      │  [已标记] ✓  │`n      └──────────────┘`n            │`n            ▼`n      ┌──────────────┐`n      │ 批量处理执行  │`n      │  [处理中...]  │`n      └──────┬───────┘`n             │`n             ▼`n      ┌──────────────┐`n      │ 处理结果展示  │`n      │  [生成中...]  │`n      └──────────────┘"
                case 2: return "      ┌──────────────┐`n      │   代码片段1   │`n      │  [已标记] ✓  │`n      └──────────────┘`n            +`n      ┌──────────────┐`n      │   代码片段2   │`n      │  [已标记] ✓  │`n      └──────────────┘`n            │`n            ▼`n      ┌──────────────┐`n      │ 批量处理执行  │`n      │  [处理中...]  │`n      └──────┬───────┘`n             │`n             ▼`n      ┌──────────────┐`n      │ 处理结果展示  │`n      │  [生成中...]  │`n      └──────────────┘"
                case 3: return "      ┌──────────────┐`n      │   代码片段1   │`n      │  [已标记] ✓  │`n      └──────────────┘`n            +`n      ┌──────────────┐`n      │   代码片段2   │`n      │  [已标记] ✓  │`n      └──────────────┘`n            │`n            ▼`n      ┌──────────────┐`n      │ 批量处理执行  │`n      │  [处理完成] ✓│`n      └──────┬───────┘`n             │`n             ▼`n      ┌──────────────┐`n      │ 处理结果展示  │`n      │  [已完成] ✓  │`n      └──────────────┘"
            }
        case "P":
            switch State {
                case 0: return "      ┌──────────────┐`n      │CapsLock+P启动│`n      │  [按下]  │`n      └──────┬───────┘`n             │`n             ▼`n      ┌──────────────┐`n      │ 打开截图工具  │`n      │  [启动中...]  │`n      └──────────────┘"
                case 1: return "      ┌──────────────┐`n      │CapsLock+P启动│`n      │  [按下]  │`n      └──────┬───────┘`n             │`n             ▼`n      ┌──────────────┐`n      │ 打开截图工具  │`n      │  [已打开] ✓  │`n      └──────┬───────┘`n             │`n             ▼`n      ┌──────────────┐`n      │ 选择截图区域  │`n      │  [选择中...]  │`n      └──────────────┘"
                case 2: return "      ┌──────────────┐`n      │CapsLock+P启动│`n      │  [按下]  │`n      └──────┬───────┘`n             │`n             ▼`n      ┌──────────────┐`n      │ 打开截图工具  │`n      │  [已打开] ✓  │`n      └──────┬───────┘`n             │`n             ▼`n      ┌──────────────┐`n      │ 选择截图区域  │`n      │  [已选择] ✓  │`n      └──────┬───────┘`n             │`n             ▼`n      ┌──────────────┐`n      │ 粘贴到Cursor │`n      │  [处理中...]  │`n      └──────────────┘"
                case 3: return "      ┌──────────────┐`n      │CapsLock+P启动│`n      │  [按下]  │`n      └──────┬───────┘`n             │`n             ▼`n      ┌──────────────┐`n      │ 打开截图工具  │`n      │  [已打开] ✓  │`n      └──────┬───────┘`n             │`n             ▼`n      ┌──────────────┐`n      │ 选择截图区域  │`n      │  [已选择] ✓  │`n      └──────┬───────┘`n             │`n             ▼`n      ┌──────────────┐`n      │ 粘贴到Cursor │`n      │  [已完成] ✓  │`n      └──────┬───────┘`n             │`n             ▼`n      ┌──────────────┐`n      │ 等待手动发送 │`n      │  [就绪]  │`n      └──────────────┘"
            }
        default:
            switch State {
                case 0: return "      ┌──────────────┐`n      │   功能执行    │`n      │  [执行中...]  │`n      └──────────────┘"
                case 1: return "      ┌──────────────┐`n      │   功能执行    │`n      │  [执行中...]  │`n      └──────┬───────┘`n             │`n             ▼`n      ┌──────────────┐`n      │   处理结果    │`n      │  [处理中...]  │`n      └──────────────┘"
                case 2: return "      ┌──────────────┐`n      │   功能执行    │`n      │  [执行中...]  │`n      └──────┬───────┘`n             │`n             ▼`n      ┌──────────────┐`n      │   处理结果    │`n      │  [处理中...]  │`n      └──────────────┘"
                case 3: return "      ┌──────────────┐`n      │   功能执行    │`n      │  [执行完成] ✓│`n      └──────┬───────┘`n             │`n             ▼`n      ┌──────────────┐`n      │   处理结果    │`n      │  [已完成] ✓  │`n      └──────────────┘"
            }
    }
}

; ===================== 切换快捷键子标签页 =====================
SwitchHotkeyTab(HotkeyKey) {
    global HotkeySubTabs, HotkeySubTabControls, UI_Colors
    
    ; 调试输出（可以删除）
    ; TrayTip("切换到: " . HotkeyKey, "提示", "Iconi 1")
    
    ; 重置所有子标签样式（使用主题颜色）
    for Key, TabBtn in HotkeySubTabs {
        if (TabBtn) {
            try {
                TabBtn.Opt("+Background" . UI_Colors.Sidebar)  ; 使用主题侧边栏颜色
                TabBtn.SetFont("s8 c" . UI_Colors.TextDim . " Norm", "Segoe UI")  ; 使用主题文字颜色
                TabBtn.Redraw()
            }
        }
    }
    
    ; 隐藏所有子标签页内容
    for Key, Controls in HotkeySubTabControls {
        if (Controls && Controls.Length > 0) {
            for Index, Ctrl in Controls {
                if (Ctrl) {
                    try {
                        Ctrl.Visible := false
                    } catch as err {
                        ; 忽略已销毁的控件
                    }
                }
            }
        }
    }
    
    ; 设置当前子标签样式（选中状态）
    if (HotkeySubTabs.Has(HotkeyKey) && HotkeySubTabs[HotkeyKey]) {
        try {
            TabBtn := HotkeySubTabs[HotkeyKey]
            ; 选中状态：蓝色背景 (0078D4)，高亮文字
            SelectedText := (ThemeMode = "dark") ? UI_Colors.Text : "FFFFFF"  ; html.to.design 风格文本（亮色模式保持白色）
            TabBtn.Opt("+Background" . UI_Colors.BtnPrimary)
            TabBtn.SetFont("s8 c" . SelectedText . " Bold", "Segoe UI")
            TabBtn.Redraw()
        }
    }
    
    ; 显示当前子标签页内容
    if (HotkeySubTabControls.Has(HotkeyKey)) {
        Controls := HotkeySubTabControls[HotkeyKey]
        if (Controls && Controls.Length > 0) {
            for Index, Ctrl in Controls {
                if (Ctrl) {
                    try {
                        Ctrl.Visible := true
                    } catch as err {
                        ; 忽略已销毁的控件
                    }
                }
            }
        }
    }
}

; ===================== 切换快捷键主标签页 =====================
SwitchHotkeysMainTab(MainTabKey) {
    global HotkeysMainTabs, HotkeysMainTabControls, UI_Colors, ThemeMode
    
    ; 重置所有主标签样式
    for Key, TabBtn in HotkeysMainTabs {
        if (TabBtn) {
            try {
                TabBtn.Opt("+Background" . UI_Colors.Sidebar)
                TabBtn.SetFont("s10 c" . UI_Colors.TextDim . " Norm", "Segoe UI")
                TabBtn.Redraw()
            }
        }
    }
    
    ; 隐藏所有主标签页内容
    for Key, Controls in HotkeysMainTabControls {
        if (Controls && Controls.Length > 0) {
            for Index, Ctrl in Controls {
                if (Ctrl) {
                    try {
                        Ctrl.Visible := false
                    } catch as err {
                        ; 忽略已销毁的控件
                    }
                }
            }
        }
    }
    
    ; 设置当前主标签样式（选中状态）
    if (HotkeysMainTabs.Has(MainTabKey) && HotkeysMainTabs[MainTabKey]) {
        try {
            TabBtn := HotkeysMainTabs[MainTabKey]
            ; 选中状态：使用主题主色
            SelectedText := (ThemeMode = "dark") ? UI_Colors.Text : "FFFFFF"  ; html.to.design 风格文本（亮色模式保持白色）
            TabBtn.Opt("+Background" . UI_Colors.BtnPrimary)
            TabBtn.SetFont("s10 c" . SelectedText . " Bold", "Segoe UI")
            TabBtn.Redraw()
        }
    }
    
    ; 显示当前主标签页内容
    ; 【架构修复】现在 TabBarBg 和快捷键子标签按钮都在 HotkeysMainTabControls["settings"] 中
    ; 所以这里统一显示/隐藏即可，不需要特殊处理
    if (HotkeysMainTabControls.Has(MainTabKey)) {
        Controls := HotkeysMainTabControls[MainTabKey]
        if (Controls && Controls.Length > 0) {
            for Index, Ctrl in Controls {
                if (Ctrl) {
                    try {
                        Ctrl.Visible := true
                    } catch as err {
                        ; 忽略已销毁的控件
                    }
                }
            }
        }
    }
    
    ; 如果是快捷键设置标签，显示第一个快捷键子标签
    if (MainTabKey = "settings") {
        global HotkeySubTabControls
        if (HotkeySubTabs && HotkeySubTabs.Count > 0) {
            FirstKey := ""
            for Key, TabBtn in HotkeySubTabs {
                FirstKey := Key
                break
            }
            if (FirstKey != "") {
                SwitchHotkeyTab(FirstKey)
            }
        }
    }
    
}

; ===================== 创建Cursor规则标签页（用于提示词标签页）=====================
CreateCursorRulesTabForPrompts(ConfigGUI, X, Y, W, H) {
    global PromptsMainTabControls, PromptsTabControls, UI_Colors, CursorRulesSubTabs, CursorRulesSubTabControls
    
    ; 初始化控件数组
    if (!PromptsMainTabControls.Has("rules")) {
        PromptsMainTabControls["rules"] := []
    }
    CursorRulesSubTabs := Map()
    global CursorRulesSubTabControls := Map()
    
    ; 创建说明区域（紧凑布局）
    IntroY := Y + 10
    IntroTitle := ConfigGUI.Add("Text", "x" . X . " y" . IntroY . " w" . W . " h28 c" . UI_Colors.Text . " vCursorRulesIntroTitle", GetText("cursor_rules_title"))
    IntroTitle.SetFont("s13 Bold", "Segoe UI")
    PromptsMainTabControls["rules"].Push(IntroTitle)
    PromptsTabControls.Push(IntroTitle)
    
    IntroY += 28
    IntroText := ConfigGUI.Add("Text", "x" . X . " y" . IntroY . " w" . W . " h35 c" . UI_Colors.TextDim . " vCursorRulesIntroText +0x200", GetText("cursor_rules_intro"))
    IntroText.SetFont("s9", "Segoe UI")
    PromptsMainTabControls["rules"].Push(IntroText)
    PromptsTabControls.Push(IntroText)
    
    ; 复制位置说明（缩小间距）
    LocationTitleY := IntroY + 40
    LocationTitle := ConfigGUI.Add("Text", "x" . X . " y" . LocationTitleY . " w" . W . " h22 c" . UI_Colors.Text . " vCursorRulesLocationTitle", GetText("cursor_rules_location_title"))
    LocationTitle.SetFont("s10 Bold", "Segoe UI")
    PromptsMainTabControls["rules"].Push(LocationTitle)
    PromptsTabControls.Push(LocationTitle)
    
    LocationDescY := LocationTitleY + 22
    LocationDesc := ConfigGUI.Add("Text", "x" . X . " y" . LocationDescY . " w" . W . " h35 c" . UI_Colors.TextDim . " vCursorRulesLocationDesc +0x200", GetText("cursor_rules_location_desc"))
    LocationDesc.SetFont("s9", "Segoe UI")
    PromptsMainTabControls["rules"].Push(LocationDesc)
    PromptsTabControls.Push(LocationDesc)
    
    ; 使用方法说明（缩小间距）
    UsageTitleY := LocationDescY + 40
    UsageTitle := ConfigGUI.Add("Text", "x" . X . " y" . UsageTitleY . " w" . W . " h22 c" . UI_Colors.Text . " vCursorRulesUsageTitle", GetText("cursor_rules_usage_title"))
    UsageTitle.SetFont("s10 Bold", "Segoe UI")
    PromptsMainTabControls["rules"].Push(UsageTitle)
    PromptsTabControls.Push(UsageTitle)
    
    UsageDescY := UsageTitleY + 22
    UsageDesc := ConfigGUI.Add("Text", "x" . X . " y" . UsageDescY . " w" . W . " h50 c" . UI_Colors.TextDim . " vCursorRulesUsageDesc +0x200", GetText("cursor_rules_usage_desc"))
    UsageDesc.SetFont("s9", "Segoe UI")
    PromptsMainTabControls["rules"].Push(UsageDesc)
    PromptsTabControls.Push(UsageDesc)
    
    ; ========== 子标签页区域 ==========
    SubTabBarY := UsageDescY + 55
    SubTabBarHeight := 35
    SubTabBarBg := ConfigGUI.Add("Text", "x" . X . " y" . SubTabBarY . " w" . W . " h" . SubTabBarHeight . " Background" . UI_Colors.Sidebar . " vCursorRulesSubTabBar", "")
    PromptsMainTabControls["rules"].Push(SubTabBarBg)
    PromptsTabControls.Push(SubTabBarBg)
    
    ; 子标签列表（8个分类）
    CursorRulesSubTabList := [
        {Key: "general", Name: GetText("cursor_rules_subtab_general")},
        {Key: "web", Name: GetText("cursor_rules_subtab_web")},
        {Key: "miniprogram", Name: GetText("cursor_rules_subtab_miniprogram")},
        {Key: "plugin", Name: GetText("cursor_rules_subtab_plugin")},
        {Key: "android", Name: GetText("cursor_rules_subtab_android")},
        {Key: "ios", Name: GetText("cursor_rules_subtab_ios")},
        {Key: "python", Name: GetText("cursor_rules_subtab_python")},
        {Key: "backend", Name: GetText("cursor_rules_subtab_backend")}
    ]
    
    ; 创建子标签按钮（8个标签，分两行显示）
    SubTabSpacing := 2
    SubTabWidth := (W - SubTabSpacing * 3) / 4  ; 每行4个标签
    SubTabX := X
    SubTabRow := 0
    
    ; 创建子标签点击处理函数
    CreateCursorRulesSubTabClickHandler(Key) {
        return (*) => SwitchCursorRulesSubTab(Key)
    }
    
    for Index, Item in CursorRulesSubTabList {
        ; 计算行和列
        Row := Floor((Index - 1) / 4)
        Col := Mod((Index - 1), 4)
        SubTabXPos := X + Col * (SubTabWidth + SubTabSpacing)
        SubTabYPos := SubTabBarY + 5 + Row * (SubTabBarHeight - 5)
        
        ; 创建子标签按钮
        SubTabBtn := ConfigGUI.Add("Text", "x" . SubTabXPos . " y" . SubTabYPos . " w" . SubTabWidth . " h" . (SubTabBarHeight - 10) . " Center 0x200 vCursorRulesSubTab" . Item.Key, Item.Name)
        SubTabBtn.SetFont("s9", "Segoe UI")
        
        ; 使用主题颜色：默认未选中状态
        SubTabBtn.Opt("+Background" . UI_Colors.Sidebar)
        SubTabBtn.SetFont("s9 c" . UI_Colors.TextDim, "Segoe UI")
        
        SubTabBtn.OnEvent("Click", CreateCursorRulesSubTabClickHandler(Item.Key))
        ; 悬停效果使用主题颜色（带动效）
        HoverBtnWithAnimation(SubTabBtn, UI_Colors.Sidebar, UI_Colors.BtnHover)
        PromptsMainTabControls["rules"].Push(SubTabBtn)
        PromptsTabControls.Push(SubTabBtn)
        CursorRulesSubTabs[Item.Key] := SubTabBtn
    }
    
    global CursorRulesSubTabs := CursorRulesSubTabs
    
    ; 子标签内容区域
    SubTabContentY := SubTabBarY + SubTabBarHeight + 20
    SubTabContentHeight := H - (SubTabContentY - Y) - 20
    
    ; 为每个子标签创建内容面板
    for Index, Item in CursorRulesSubTabList {
        CreateCursorRulesSubTab(ConfigGUI, X, SubTabContentY, W, SubTabContentHeight + 500, Item)
    }
    
    ; 将所有规则子标签的控件添加到主标签控件映射中，确保切换主标签时能正确隐藏
    for Key, Controls in CursorRulesSubTabControls {
        if (Controls && Controls.Length > 0) {
            for Index, Ctrl in Controls {
                PromptsMainTabControls["rules"].Push(Ctrl)
                PromptsTabControls.Push(Ctrl)
            }
        }
    }
    
    ; 默认隐藏所有规则标签页的控件，等待用户点击标签时才显示
    ; 这样可以避免在初始化时与其他标签页内容混合显示
    if (PromptsMainTabControls.Has("rules")) {
        RulesControls := PromptsMainTabControls["rules"]
        if (RulesControls && RulesControls.Length > 0) {
            for Index, Ctrl in RulesControls {
                if (Ctrl) {
                    try {
                        Ctrl.Visible := false
                    } catch as err {
                    }
                }
            }
        }
    }
}

; ===================== 创建Cursor规则子标签页 =====================
CreateCursorRulesSubTab(ConfigGUI, X, Y, W, H, Item) {
    global CursorRulesSubTabControls, UI_Colors
    
    ; 初始化子标签页控件数组
    if (!CursorRulesSubTabControls.Has(Item.Key)) {
        CursorRulesSubTabControls[Item.Key] := []
    }
    
    ; 创建子标签页面板（默认隐藏）
    SubTabPanel := ConfigGUI.Add("Text", "x" . X . " y" . Y . " w" . W . " h" . H . " Background" . UI_Colors.Background . " vCursorRulesSubTab" . Item.Key . "Panel", "")
    SubTabPanel.Visible := false
    CursorRulesSubTabControls[Item.Key].Push(SubTabPanel)
    
    ; 规则内容区域（紧凑布局，确保按钮可见且不与底部按钮重叠）
    ContentY := Y + 10
    ; 缩小文本框面积到原来的三分之一（缩小三分之二）
    ContentHeight := (H - 120) // 3  ; 缩小三分之二，保留三分之一
    
    ; 尝试从配置文件读取已保存的规则内容
    global ConfigFile
    SavedRulesContent := IniRead(ConfigFile, "CursorRules", Item.Key, GetText("cursor_rules_content_placeholder"))
    
    ; 规则内容文本框（可编辑，方便用户查看、编辑和复制）
    RulesEdit := ConfigGUI.Add("Edit", "x" . X . " y" . ContentY . " w" . W . " h" . ContentHeight . " Background" . UI_Colors.InputBg . " c" . UI_Colors.Text . " Multi vCursorRulesContent" . Item.Key, SavedRulesContent)
    RulesEdit.SetFont("s10", "Consolas")
    RulesEdit.Visible := false  ; 默认隐藏，防止覆盖其他页面
    CursorRulesSubTabControls[Item.Key].Push(RulesEdit)
    
    ; 按钮区域（导入按钮和复制按钮）
    BtnY := Y + ContentHeight + 15  ; 减少间距，更紧凑
    BtnSpacing := 10
    BtnWidth := 100
    
    ; 导入规则按钮（左侧）
    ImportBtn := ConfigGUI.Add("Text", "x" . X . " y" . BtnY . " w" . BtnWidth . " h35 Center 0x200 cFFFFFF Background" . UI_Colors.BtnBg . " vCursorRulesImportBtn" . Item.Key, GetText("cursor_rules_import_btn"))
    ImportBtn.SetFont("s10 Bold", "Segoe UI")
    ImportBtn.Visible := false  ; 默认隐藏，防止覆盖其他页面
    
    ; 创建导入按钮点击处理函数
    CreateImportBtnClickHandler(Key) {
        return (*) => ImportCursorRules(Key)
    }
    
    ImportBtn.OnEvent("Click", CreateImportBtnClickHandler(Item.Key))
    ; 悬停效果
    HoverBtnWithAnimation(ImportBtn, UI_Colors.BtnBg, UI_Colors.BtnHover)
    CursorRulesSubTabControls[Item.Key].Push(ImportBtn)
    
    ; 导出到.cursorrules按钮（中间）
    ExportBtn := ConfigGUI.Add("Text", "x" . (X + W - BtnWidth * 2 - BtnSpacing) . " y" . BtnY . " w" . BtnWidth . " h35 Center 0x200 cFFFFFF Background" . UI_Colors.BtnPrimary . " vCursorRulesExportBtn" . Item.Key, GetText("cursor_rules_export_btn"))
    ExportBtn.SetFont("s10 Bold", "Segoe UI")
    ExportBtn.Visible := false  ; 默认隐藏，防止覆盖其他页面
    
    ; 创建导出按钮点击处理函数
    CreateExportBtnClickHandler(Key) {
        return (*) => ExportCursorRulesToFile(Key)
    }
    
    ExportBtn.OnEvent("Click", CreateExportBtnClickHandler(Item.Key))
    ; 悬停效果
    HoverBtnWithAnimation(ExportBtn, UI_Colors.BtnPrimary, UI_Colors.BtnPrimaryHover)
    CursorRulesSubTabControls[Item.Key].Push(ExportBtn)
    
    ; 复制按钮（右侧）
    CopyBtn := ConfigGUI.Add("Text", "x" . (X + W - BtnWidth) . " y" . BtnY . " w" . BtnWidth . " h35 Center 0x200 cFFFFFF Background" . UI_Colors.BtnPrimary . " vCursorRulesCopyBtn" . Item.Key, GetText("cursor_rules_copy_btn"))
    CopyBtn.SetFont("s10 Bold", "Segoe UI")
    CopyBtn.Visible := false  ; 默认隐藏，防止覆盖其他页面
    
    ; 创建复制按钮点击处理函数
    CreateCopyBtnClickHandler(Key) {
        return (*) => CopyCursorRules(Key)
    }
    
    CopyBtn.OnEvent("Click", CreateCopyBtnClickHandler(Item.Key))
    ; 悬停效果
    HoverBtnWithAnimation(CopyBtn, UI_Colors.BtnPrimary, UI_Colors.BtnPrimaryHover)
    CursorRulesSubTabControls[Item.Key].Push(CopyBtn)
}

; ===================== 切换Cursor规则子标签页 =====================
SwitchCursorRulesSubTab(SubTabKey) {
    global CursorRulesSubTabs, CursorRulesSubTabControls, UI_Colors, ThemeMode
    
    ; 重置所有子标签样式
    for Key, TabBtn in CursorRulesSubTabs {
        if (TabBtn) {
            try {
                TabBtn.Opt("+Background" . UI_Colors.Sidebar)
                TabBtn.SetFont("s9 c" . UI_Colors.TextDim . " Norm", "Segoe UI")
                TabBtn.Redraw()
            }
        }
    }
    
    ; 隐藏所有子标签页内容
    for Key, Controls in CursorRulesSubTabControls {
        if (Controls && Controls.Length > 0) {
            for Index, Ctrl in Controls {
                if (Ctrl) {
                    try {
                        Ctrl.Visible := false
                    } catch as err {
                        ; 忽略已销毁的控件
                    }
                }
            }
        }
    }
    
    ; 设置当前子标签样式（选中状态）
    if (CursorRulesSubTabs.Has(SubTabKey) && CursorRulesSubTabs[SubTabKey]) {
        try {
            TabBtn := CursorRulesSubTabs[SubTabKey]
            ; 选中状态：使用主题主色
            SelectedText := (ThemeMode = "dark") ? UI_Colors.Text : "FFFFFF"  ; html.to.design 风格文本（亮色模式保持白色）
            TabBtn.Opt("+Background" . UI_Colors.BtnPrimary)
            TabBtn.SetFont("s9 c" . SelectedText . " Bold", "Segoe UI")
            TabBtn.Redraw()
        }
    }
    
    ; 显示当前子标签页内容
    if (CursorRulesSubTabControls.Has(SubTabKey)) {
        Controls := CursorRulesSubTabControls[SubTabKey]
        if (Controls && Controls.Length > 0) {
            for Index, Ctrl in Controls {
                if (Ctrl) {
                    try {
                        Ctrl.Visible := true
                    } catch as err {
                        ; 忽略已销毁的控件
                    }
                }
            }
        }
    }
}

; ===================== 复制Cursor规则 =====================
CopyCursorRules(SubTabKey) {
    global CursorRulesSubTabControls, GuiID_ConfigGUI
    
    ; 获取规则内容
    try {
        if (!GuiID_ConfigGUI) {
            TrayTip("配置面板未打开", GetText("error"), "Iconx 2")
            return
        }
        RulesEdit := GuiID_ConfigGUI["CursorRulesContent" . SubTabKey]
        if (RulesEdit) {
            RulesContent := RulesEdit.Value
            
            ; 如果内容为空，提示用户
            if (RulesContent = "" || RulesContent = GetText("cursor_rules_content_placeholder")) {
                TrayTip("规则内容为空，请先导入规则", GetText("tip"), "Iconi 1")
                return
            }
            
            ; 复制到剪贴板
            A_Clipboard := RulesContent
            
            ; 显示文件名提示
            FileNameMap := Map(
                "general", "general.md",
                "web", "web.md",
                "miniprogram", "miniprogram.md",
                "plugin", "plugin.md",
                "android", "android.md",
                "ios", "ios.md",
                "python", "python.md",
                "backend", "backend.md"
            )
            
            FileName := FileNameMap.Has(SubTabKey) ? FileNameMap[SubTabKey] : SubTabKey . ".md"
            TrayTip(GetText("cursor_rules_copied") . "`n文件名: " . FileName, GetText("tip"), "Iconi 1")
        }
    } catch as e {
        TrayTip("复制失败: " . e.Message, GetText("error"), "Iconx 2")
    }
}

; ===================== 导出 Cursor 规则到文件 =====================
ExportCursorRulesToFile(SubTabKey) {
    global CursorRulesSubTabControls, GuiID_ConfigGUI, A_ScriptDir
    
    try {
        if (!GuiID_ConfigGUI) {
            TrayTip("配置面板未打开", GetText("error"), "Iconx 2")
            return
        }
        
        ; 获取规则内容
        RulesEdit := GuiID_ConfigGUI["CursorRulesContent" . SubTabKey]
        if (!RulesEdit) {
            TrayTip("无法找到规则编辑框", GetText("error"), "Iconx 2")
            return
        }
        
        RulesContent := RulesEdit.Value
        PlaceholderText := GetText("cursor_rules_content_placeholder")
        
        ; 检查内容是否有效
        if (RulesContent = "" || RulesContent = PlaceholderText) {
            TrayTip("规则内容为空，请先导入或编辑规则", GetText("tip"), "Iconi 1")
            return
        }
        
        ; 定义文件名映射
        FileNameMap := Map(
            "general", "general.md",
            "web", "web.md",
            "miniprogram", "miniprogram.md",
            "plugin", "plugin.md",
            "android", "android.md",
            "ios", "ios.md",
            "python", "python.md",
            "backend", "backend.md"
        )
        
        FileName := FileNameMap.Has(SubTabKey) ? FileNameMap[SubTabKey] : SubTabKey . ".md"
        
        ; 查找 Cursor 的 .cursorrules 目录
        ; 通常在用户目录下的 .cursor 文件夹中
        CursorRulesDir := ""
        
        ; 方法1：尝试从环境变量获取
        UserProfile := EnvGet("USERPROFILE")
        if (UserProfile != "") {
            ; 尝试多个可能的位置
            PossiblePaths := [
                UserProfile . "\.cursor\rules",
                UserProfile . "\.cursorrules",
                A_ScriptDir . "\.cursorrules"
            ]
            
            for Index, Path in PossiblePaths {
                if (DirExist(Path)) {
                    CursorRulesDir := Path
                    break
                }
            }
            
            ; 如果目录不存在，尝试创建
            if (CursorRulesDir = "") {
                ; 使用第一个路径作为默认位置
                CursorRulesDir := UserProfile . "\.cursor\rules"
                try {
                    DirCreate(CursorRulesDir)
                } catch as err {
                    ; 如果创建失败，使用脚本目录
                    CursorRulesDir := A_ScriptDir . "\.cursorrules"
                    DirCreate(CursorRulesDir)
                }
            }
        } else {
            ; 如果无法获取用户目录，使用脚本目录
            CursorRulesDir := A_ScriptDir . "\.cursorrules"
            DirCreate(CursorRulesDir)
        }
        
        ; 构建完整文件路径
        FilePath := CursorRulesDir . "\" . FileName
        
        ; 写入文件（使用UTF-8编码）
        FileObj := FileOpen(FilePath, "w", "UTF-8")
        if (!FileObj) {
            throw Error("无法创建文件: " . FilePath)
        }
        
        FileObj.Write(RulesContent)
        FileObj.Close()
        
        TrayTip(GetText("cursor_rules_exported") . "`n" . FilePath, GetText("tip"), "Iconi 1")
    } catch as e {
        TrayTip(GetText("cursor_rules_export_failed") . ": " . e.Message, GetText("error"), "Iconx 2")
    }
}

; ===================== 导入 Cursor 规则 =====================
ImportCursorRules(SubTabKey) {
    global CursorRulesSubTabControls, GuiID_ConfigGUI, A_ScriptDir
    
    try {
        if (!GuiID_ConfigGUI) {
            TrayTip("配置面板未打开", GetText("error"), "Iconx 2")
            return
        }
        
        ; 查找 Programming Rules.txt 文件（在脚本目录下）
        RulesFilePath := A_ScriptDir . "\Programming Rules.txt"
        if (!FileExist(RulesFilePath)) {
            TrayTip(GetText("cursor_rules_file_not_found"), GetText("error"), "Iconx 2")
            return
        }
        
        ; 读取文件内容（使用UTF-8编码）
        RulesFileContent := FileRead(RulesFilePath, "UTF-8")
        
        ; 解析规则文件，提取对应类别的规则
        RulesContent := ParseRulesFile(RulesFileContent, SubTabKey)
        
        if (RulesContent = "" || RulesContent = GetText("cursor_rules_content_placeholder")) {
            TrayTip("未找到对应类别的规则，请检查 Programming Rules.txt 文件格式", GetText("error"), "Iconx 2")
            return
        }
        
        ; 更新规则内容到编辑框
        RulesEdit := GuiID_ConfigGUI["CursorRulesContent" . SubTabKey]
        if (RulesEdit) {
            RulesEdit.Value := RulesContent
            RulesEdit.Redraw()  ; 强制刷新显示
            TrayTip(GetText("cursor_rules_imported"), GetText("tip"), "Iconi 1")
        } else {
            TrayTip("无法找到规则编辑框", GetText("error"), "Iconx 2")
        }
    } catch as e {
        TrayTip(GetText("cursor_rules_import_failed") . ": " . e.Message, GetText("error"), "Iconx 2")
    }
}

; ===================== 解析规则文件 =====================
ParseRulesFile(FileContent, CategoryKey) {
    ; 定义类别映射（匹配 Programming Rules.txt 中的标题）
    ; 注意：plugin 类别的标题包含括号，需要特殊处理
    CategoryMap := Map(
        "general", "General Programming Rules",
        "web", "Web Development Rules",
        "miniprogram", "WeChat Mini Program Rules",
        "plugin", "Browser Extension Rules (MV3)",
        "android", "Android Development Rules",
        "ios", "iOS Development Rules",
        "python", "Python Development Rules",
        "backend", "Backend Service Rules"
    )
    
    ; 获取对应的标题
    if (!CategoryMap.Has(CategoryKey)) {
        return ""
    }
    
    TargetTitle := CategoryMap[CategoryKey]
    
    ; 查找目标标题的位置
    Lines := StrSplit(FileContent, "`n", "`r")
    StartIndex := 0
    EndIndex := 0
    
    ; 查找开始位置（匹配 "# 标题" 格式）
    ; 使用多种匹配方式确保能找到标题
    for Index, Line in Lines {
        ; 方法1：精确匹配（转义特殊字符）
        EscapedTitle := RegExReplace(TargetTitle, "([\(\)])", "\$1")
        if (RegExMatch(Line, "^# " . EscapedTitle . "$")) {
            StartIndex := Index
            break
        }
        
        ; 方法2：直接匹配（不转义，用于处理括号）
        if (RegExMatch(Line, "^# " . TargetTitle . "$")) {
            StartIndex := Index
            break
        }
        
        ; 方法3：不区分大小写匹配
        if (RegExMatch(Line, "i)^# " . TargetTitle)) {
            StartIndex := Index
            break
        }
    }
    
    if (StartIndex = 0) {
        return ""
    }
    
    ; 查找结束位置（下一个 # 开头的行，或者文件结束）
    EndIndex := Lines.Length + 1
    for Index, Line in Lines {
        if (Index > StartIndex && RegExMatch(Line, "^# ")) {
            EndIndex := Index
            break
        }
    }
    
    ; 提取规则内容
    RulesLines := []
    Loop EndIndex - StartIndex {
        RulesLines.Push(Lines[StartIndex + A_Index - 1])
    }
    
    ; 合并为字符串
    RulesContent := ""
    for Index, Line in RulesLines {
        RulesContent .= Line . "`n"
    }
    
    ; 去除末尾的换行符
    RulesContent := RTrim(RulesContent, "`n")
    
    return RulesContent
}

; ===================== 创建高级标签页 =====================
CreateAdvancedTab(ConfigGUI, X, Y, W, H) {
    global AISleepTime, AdvancedTabPanel, AISleepTimeEdit, AdvancedTabControls
    global ConfigPanelScreenIndex, MsgBoxScreenIndex, VoiceInputScreenIndex, CursorPanelScreenIndex, ClipboardPanelScreenIndex
    global ConfigPanelScreenRadio, MsgBoxScreenRadio, VoiceInputScreenRadio, CursorPanelScreenRadio
    global Language, LangChinese, LangEnglish, UI_Colors, LaunchDelaySeconds, LaunchDelaySecondsEdit
    
    ; 创建标签页面板（默认隐藏）
    AdvancedTabPanel := ConfigGUI.Add("Text", "x" . X . " y" . Y . " w" . W . " h" . H . " Background" . UI_Colors.Background . " vAdvancedTabPanel", "")
    AdvancedTabPanel.Visible := false
    AdvancedTabControls.Push(AdvancedTabPanel)
    
    ; 标题
    Title := ConfigGUI.Add("Text", "x" . (X + 30) . " y" . (Y + 20) . " w" . (W - 60) . " h30 c" . UI_Colors.Text, GetText("advanced_settings"))
    Title.SetFont("s16 Bold", "Segoe UI")
    AdvancedTabControls.Push(Title)
    
    ; 语言设置（从通用设置移到这里）
    YPos := Y + 70
    LabelLanguage := ConfigGUI.Add("Text", "x" . (X + 30) . " y" . YPos . " w200 h25 c" . UI_Colors.Text, GetText("language_setting"))
    LabelLanguage.SetFont("s11", "Segoe UI")
    AdvancedTabControls.Push(LabelLanguage)
    
    YPos += 30
    ; 创建 Material 风格的语言选择单选按钮组
    global LangRadioGroup := []
    LangChinese := CreateMaterialRadioButton(ConfigGUI, X + 30, YPos, 100, 30, "LangChinese", GetText("language_chinese"), LangRadioGroup, 11)
    LangRadioGroup.Push(LangChinese)
    AdvancedTabControls.Push(LangChinese)
    
    LangEnglish := CreateMaterialRadioButton(ConfigGUI, X + 140, YPos, 100, 30, "LangEnglish", GetText("language_english"), LangRadioGroup, 11)
    LangRadioGroup.Push(LangEnglish)
    AdvancedTabControls.Push(LangEnglish)
    
    ; 设置当前语言
    if (Language = "zh") {
        LangChinese.IsSelected := true
        UpdateMaterialRadioButtonStyle(LangChinese, true)
    } else {
        LangEnglish.IsSelected := true
        UpdateMaterialRadioButtonStyle(LangEnglish, true)
    }
    
    ; AI 响应等待时间
    YPos += 60
    Label1 := ConfigGUI.Add("Text", "x" . (X + 30) . " y" . YPos . " w200 h25 c" . UI_Colors.Text, GetText("ai_wait_time"))
    Label1.SetFont("s11", "Segoe UI")
    AdvancedTabControls.Push(Label1)
    
    YPos += 30
    ; 根据主题模式设置输入框颜色（暗色模式使用cursor黑灰色系）
    global ThemeMode
    if (!IsSet(ThemeMode) || ThemeMode = "") {
        ThemeMode := "dark"
    }
    if (ThemeMode = "dark") {
        InputBgColor := UI_Colors.InputBg  ; html.to.design 风格背景
        InputTextColor := UI_Colors.Text   ; html.to.design 风格文本
    } else {
        InputBgColor := UI_Colors.InputBg
        InputTextColor := UI_Colors.Text
    }
    AISleepTimeEdit := ConfigGUI.Add("Edit", "x" . (X + 30) . " y" . YPos . " w150 h30 vAISleepTimeEdit Background" . InputBgColor . " c" . InputTextColor, AISleepTime)
    AISleepTimeEdit.SetFont("s11", "Segoe UI")
    AdvancedTabControls.Push(AISleepTimeEdit)
    
    YPos += 40
    Hint1 := ConfigGUI.Add("Text", "x" . (X + 30) . " y" . YPos . " w" . (W - 60) . " h20 c" . UI_Colors.TextDim, GetText("ai_wait_hint"))
    Hint1.SetFont("s9", "Segoe UI")
    AdvancedTabControls.Push(Hint1)
    
    ; 倒计时延迟时间设置
    YPos += 60
    global LaunchDelaySeconds, LaunchDelaySecondsEdit
    LabelCountdown := ConfigGUI.Add("Text", "x" . (X + 30) . " y" . YPos . " w200 h25 c" . UI_Colors.Text, GetText("countdown_delay"))
    LabelCountdown.SetFont("s11", "Segoe UI")
    AdvancedTabControls.Push(LabelCountdown)
    
    YPos += 30
    LaunchDelaySecondsEdit := ConfigGUI.Add("Edit", "x" . (X + 30) . " y" . YPos . " w150 h30 vLaunchDelaySecondsEdit Background" . InputBgColor . " c" . InputTextColor, LaunchDelaySeconds)
    LaunchDelaySecondsEdit.SetFont("s11", "Segoe UI")
    AdvancedTabControls.Push(LaunchDelaySecondsEdit)
    
    YPos += 40
    HintCountdown := ConfigGUI.Add("Text", "x" . (X + 30) . " y" . YPos . " w" . (W - 60) . " h20 c" . UI_Colors.TextDim, GetText("countdown_delay_hint"))
    HintCountdown.SetFont("s9", "Segoe UI")
    AdvancedTabControls.Push(HintCountdown)
    
    ; 配置管理功能（导出、导入、重置默认）
    YPos += 60
    LabelConfigManage := ConfigGUI.Add("Text", "x" . (X + 30) . " y" . YPos . " w200 h25 c" . UI_Colors.Text, GetText("config_manage"))
    LabelConfigManage.SetFont("s11", "Segoe UI")
    AdvancedTabControls.Push(LabelConfigManage)
    
    YPos += 30
    ; 创建三个功能按钮
    BtnWidth := 120
    BtnHeight := 35
    BtnSpacing := 15
    BtnStartX := X + 30
    
    ; 导出配置按钮（改为灰色）
    global ThemeMode
    TextColor := (ThemeMode = "light") ? UI_Colors.Text : UI_Colors.Text  ; html.to.design 风格文本
    ExportBtn := ConfigGUI.Add("Text", "x" . BtnStartX . " y" . YPos . " w" . BtnWidth . " h" . BtnHeight . " Center 0x200 c" . TextColor . " Background" . UI_Colors.BtnBg . " vAdvancedExportBtn", GetText("export_config"))
    ExportBtn.SetFont("s10", "Segoe UI")
    ExportBtn.OnEvent("Click", ExportConfig)
    HoverBtnWithAnimation(ExportBtn, UI_Colors.BtnBg, UI_Colors.BtnHover)
    AdvancedTabControls.Push(ExportBtn)
    
    ; 导入配置按钮（改为灰色）
    ImportBtn := ConfigGUI.Add("Text", "x" . (BtnStartX + BtnWidth + BtnSpacing) . " y" . YPos . " w" . BtnWidth . " h" . BtnHeight . " Center 0x200 c" . TextColor . " Background" . UI_Colors.BtnBg . " vAdvancedImportBtn", GetText("import_config"))
    ImportBtn.SetFont("s10", "Segoe UI")
    ImportBtn.OnEvent("Click", ImportConfig)
    HoverBtnWithAnimation(ImportBtn, UI_Colors.BtnBg, UI_Colors.BtnHover)
    AdvancedTabControls.Push(ImportBtn)
    
    ; 重置默认按钮（改为灰色）
    ResetBtn := ConfigGUI.Add("Text", "x" . (BtnStartX + (BtnWidth + BtnSpacing) * 2) . " y" . YPos . " w" . BtnWidth . " h" . BtnHeight . " Center 0x200 c" . TextColor . " Background" . UI_Colors.BtnBg . " vAdvancedResetBtn", GetText("reset_default"))
    ResetBtn.SetFont("s10", "Segoe UI")
    ResetBtn.OnEvent("Click", ResetToDefaults)
    HoverBtnWithAnimation(ResetBtn, UI_Colors.BtnBg, UI_Colors.BtnHover)
    AdvancedTabControls.Push(ResetBtn)
}

; ===================== 搜索功能核心函数 =====================
; 获取数据类型名称
; ===================== 获取数据类型名称（数据源类型）=====================
GetDataTypeName(DataType) {
    SearchDataType := Map(
        "clipboard", "剪贴板历史",
        "template", "提示词模板",
        "config", "配置项",
        "file", "文件路径",
        "hotkey", "快捷键",
        "function", "功能",
        "ui", "界面元素"
    )
    return SearchDataType.Has(DataType) ? SearchDataType[DataType] : "未知类型"
}

; ===================== 获取内容类型显示名称（内容类型，如 Text, Code, Image 等）=====================
GetContentTypeDisplayName(ContentType) {
    ContentTypeMap := Map(
        "Text", "文本",
        "Code", "代码",
        "Link", "链接",
        "Image", "图片",
        "Color", "颜色",
        "Email", "邮箱",
        "Folder", "文件夹",
        "Screenshot", "截图",
        "CapsLockC", "CapsLock+C",
        "Stack", "CapsLock+C",
        "Template", "模板",
        "Config", "配置",
        "File", "文件",
        "Hotkey", "快捷键",
        "Function", "功能",
        "UI", "界面"
    )
    
    return ContentTypeMap.Has(ContentType) ? ContentTypeMap[ContentType] : ContentType
}

; 统一搜索函数
; ===================== 使用统一视图搜索 =====================
SearchGlobalView(Keyword, MaxResults := 100) {
    global ClipboardDB, global_ST
    Results := []

    if (!ClipboardDB || ClipboardDB = 0) {
        return Results
    }

    if (Keyword = "") {
        return Results
    }

    ; 【入口熔断】在执行 Prepare 之前，必须先检查并释放旧句柄
    if (IsObject(global_ST) && global_ST.HasProp("Free")) {
        try {
            global_ST.Free()
        } catch as err {
        }
        global_ST := 0
    }

    KeywordLower := StrLower(Keyword)
    ; 使用统一搜索视图进行搜索（字段顺序：Title, Content, Source, Timestamp, OriginalID）
    SQL := "SELECT Title, Content, Source, Timestamp, OriginalID FROM v_GlobalSearch WHERE LOWER(Title) LIKE ? OR LOWER(Content) LIKE ? ORDER BY Timestamp DESC LIMIT ?"

    ST := ""
    try {
        if (!ClipboardDB.Prepare(SQL, &ST)) {
            return Results
        }
        
        ; 更新全局句柄
        global_ST := ST
        
        ; 检查ST是否是有效的Statement对象
        if (!IsObject(ST) || !ST.HasProp("Bind")) {
            return Results
        }
        
        ; 使用小写关键词进行搜索
        SearchPattern := "%" . KeywordLower . "%"
        if (!ST.Bind(1, "Text", SearchPattern)) {
            return Results
        }
        if (!ST.Bind(2, "Text", SearchPattern)) {
            return Results
        }
        if (!ST.Bind(3, "Int", MaxResults)) {
            return Results
        }
        
        while (ST.Step()) {
            Title := ST.Column(0)
            Content := ST.Column(1)
            Source := ST.Column(2)
            Timestamp := ST.Column(3)
            OriginalID := ST.Column(4)
            
            ; 格式化时间
            try {
                TimeFormatted := FormatTime(Timestamp, "yyyy-MM-dd HH:mm:ss")
            } catch as err {
                TimeFormatted := Timestamp
            }
            
            ; 生成预览文本（截取前100个字符）
            Preview := SubStr(Content, 1, 100)
            if (StrLen(Content) > 100) {
                Preview .= "..."
            }
            
            ; 根据来源设置不同的操作
            Action := ""
            ActionParams := Map()
            DataTypeName := ""
            
            switch Source {
                case "prompt":
                    DataTypeName := "提示词"
                    Action := "open_prompt"
                    ActionParams["ID"] := OriginalID
                case "clipboard":
                    DataTypeName := "剪贴板"
                    Action := "copy_to_clipboard"
                    ActionParams["ID"] := OriginalID
                    ActionParams["Content"] := Content
                default:
                    DataTypeName := Source
                    Action := "copy_to_clipboard"
                    ActionParams["Content"] := Content
            }
            
            ResultItem := {
                DataType: Source,
                DataTypeName: DataTypeName,
                ID: OriginalID,
                Title: Title,
                Content: Content,
                Preview: Preview,
                Timestamp: Timestamp,
                TimeFormatted: TimeFormatted,
                Source: Source,
                Action: Action,
                ActionParams: ActionParams
            }
            
            Results.Push(ResultItem)
        }
    } catch as e {
        ; 错误处理
    } finally {
        ; 【过程保底】无论查询成功还是报错，都在 finally 块中释放句柄
        try {
            if (IsObject(global_ST) && global_ST.HasProp("Free")) {
                global_ST.Free()
            }
            global_ST := 0
        } catch as err {
        }
    }
    
    return Results
}

SearchAllDataSources(Keyword, DataTypes := [], MaxResults := 10, Offset := 0) {
    ; 【修改】始终搜索所有数据源，确保剪贴板、提示词、配置项等数据能够混排显示
    ; 不再优先使用统一视图，而是并行搜索所有数据源，然后混排结果
    ; 支持 Offset 参数用于分页加载
    
    Results := Map()
    
    ; 如果未指定类型，搜索所有数据源（增强搜索功能）
    if (DataTypes.Length = 0) {
        DataTypes := ["clipboard", "template", "config", "file", "hotkey", "function", "ui"]
    }
    
    ; 并行搜索各个数据源（各分支独立 try/catch，避免某一源异常阻断后续含 file/Everything）
    for Index, DataType in DataTypes {
        TypeResults := []
        try {
            switch DataType {
                case "clipboard":
                    ; 【关键】优先使用新的剪贴板数据库（ClipMain）
                    TypeResults := SearchClipboardHistory(Keyword, MaxResults, Offset)
                case "template":
                    TypeResults := SearchPromptTemplates(Keyword, MaxResults, Offset)
                case "config":
                    TypeResults := SearchConfigItems(Keyword, MaxResults, Offset)
                case "file":
                    TypeResults := SearchFilePaths(Keyword, MaxResults, Offset)
                case "hotkey":
                    TypeResults := SearchHotkeys(Keyword, MaxResults, Offset)
                case "function":
                    TypeResults := SearchFunctions(Keyword, MaxResults, Offset)
                case "ui":
                    TypeResults := SearchUITabs(Keyword, MaxResults, Offset)
            }
        } catch as err {
            OutputDebug("AHK_DEBUG: SearchAllDataSources[" . DataType . "] 错误: " . err.Message)
            TypeResults := []
        }
        
        if (TypeResults.Length > 0) {
            Results[DataType] := {
                DataType: DataType,
                DataTypeName: GetDataTypeName(DataType),
                Count: TypeResults.Length,
                Items: TypeResults,
                HasMore: TypeResults.Length >= MaxResults  ; 标记是否还有更多数据
            }
        }
    }
    
    return Results
}

; ===================== 搜索剪贴板 FTS5 数据库（用于 SearchCenter）=====================
; 从新的剪贴板数据库 ClipMain 表搜索数据
SearchClipboardFTS5ForSearchCenter(Keyword, MaxResults := 10, Offset := 0) {
    global ClipboardFTS5DB
    Results := []
    
    if (!ClipboardFTS5DB || ClipboardFTS5DB = 0) {
        return Results
    }
    
    try {
        ; 【修复】如果关键词为空，直接返回空结果
        if (StrLen(Keyword) < 1) {
            return Results
        }
        
        KeywordLower := StrLower(Keyword)
        SearchPattern := "%" . KeywordLower . "%"
        
        ; 检查字段是否存在，动态构建查询
        SQL := "PRAGMA table_info(ClipMain)"
        tableInfo := ""
        hasLastCopyTime := false
        hasCopyCount := false
        hasSourcePath := false
        
        if (ClipboardFTS5DB.GetTable(SQL, &tableInfo)) {
            if (tableInfo.HasRows && tableInfo.Rows.Length > 0) {
                Loop tableInfo.Rows.Length {
                    row := tableInfo.Rows[A_Index]
                    columnName := row[2]
                    if (columnName = "LastCopyTime") {
                        hasLastCopyTime := true
                    }
                    if (columnName = "CopyCount") {
                        hasCopyCount := true
                    }
                    if (columnName = "SourcePath") {
                        hasSourcePath := true
                    }
                }
            }
        }
        
        ; 构建查询字段
        selectFields := "ID, Content, SourceApp, DataType, CharCount, Timestamp"
        if (hasSourcePath) {
            selectFields .= ", SourcePath"
        } else {
            selectFields .= ", '' AS SourcePath"
        }
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
        
        ; 使用 LIKE 查询（支持短关键词即时匹配）
        ; 同时搜索 Content 和 SourceApp 字段
        ; 【修复】使用 GetTable 替代 Prepare+Step，避免 _Statement 错误
        ; 转义 SQL 字符串中的单引号，防止 SQL 注入
        ; 支持分页：查询 limit+1 条数据，用于检测是否还有更多
        SearchPatternEscaped := StrReplace(SearchPattern, "'", "''")
        SQL := "SELECT " . selectFields . " FROM ClipMain " .
               "WHERE (LOWER(Content) LIKE '" . SearchPatternEscaped . "' OR LOWER(SourceApp) LIKE '" . SearchPatternEscaped . "') " .
               "ORDER BY " . (hasLastCopyTime ? "LastCopyTime" : "Timestamp") . " DESC LIMIT " . (MaxResults + 1) . " OFFSET " . Offset
        
        ResultSet := ""
        if (!ClipboardFTS5DB.GetTable(SQL, &ResultSet)) {
            return Results
        }
        
        ; 遍历结果
        try {
            if (ResultSet.HasRows && ResultSet.Rows.Length > 0) {
                ; 检查是否还有更多数据（如果返回的数据量等于 MaxResults+1，说明还有更多）
                hasMore := (ResultSet.Rows.Length > MaxResults)
                maxRows := hasMore ? MaxResults : ResultSet.Rows.Length
                
                ; 创建列名映射
                columnNames := []
                columnIndexMap := Map()
                if (ResultSet.HasNames && ResultSet.ColumnNames.Length > 0) {
                    columnNames := ResultSet.ColumnNames
                    Loop columnNames.Length {
                        colName := columnNames[A_Index]
                        columnIndexMap[colName] := A_Index
                    }
                }

                Loop maxRows {
                    row := ResultSet.Rows[A_Index]
                    
                    ; 使用列名映射访问（正确方式）
                    if (columnIndexMap.Count > 0) {
                        ID := columnIndexMap.Has("ID") && row.Has(columnIndexMap["ID"]) ? row[columnIndexMap["ID"]] : ""
                        Content := columnIndexMap.Has("Content") && row.Has(columnIndexMap["Content"]) ? row[columnIndexMap["Content"]] : ""
                        SourceApp := columnIndexMap.Has("SourceApp") && row.Has(columnIndexMap["SourceApp"]) ? row[columnIndexMap["SourceApp"]] : ""
                        DataType := columnIndexMap.Has("DataType") && row.Has(columnIndexMap["DataType"]) ? row[columnIndexMap["DataType"]] : ""
                        CharCount := columnIndexMap.Has("CharCount") && row.Has(columnIndexMap["CharCount"]) ? row[columnIndexMap["CharCount"]] : 0
                        Timestamp := columnIndexMap.Has("Timestamp") && row.Has(columnIndexMap["Timestamp"]) ? row[columnIndexMap["Timestamp"]] : ""
                        SourcePath := columnIndexMap.Has("SourcePath") && row.Has(columnIndexMap["SourcePath"]) ? row[columnIndexMap["SourcePath"]] : ""
                        LastCopyTime := columnIndexMap.Has("LastCopyTime") && row.Has(columnIndexMap["LastCopyTime"]) ? row[columnIndexMap["LastCopyTime"]] : Timestamp
                        CopyCount := columnIndexMap.Has("CopyCount") && row.Has(columnIndexMap["CopyCount"]) ? row[columnIndexMap["CopyCount"]] : 1
                    } else {
                        ; 后备方案：按固定顺序读取
                        ID := row.HasProp("Length") && row.Length >= 1 ? row[1] : ""
                        Content := row.HasProp("Length") && row.Length >= 2 ? row[2] : ""
                        SourceApp := row.HasProp("Length") && row.Length >= 3 ? row[3] : ""
                        DataType := row.HasProp("Length") && row.Length >= 4 ? row[4] : ""
                        CharCount := row.HasProp("Length") && row.Length >= 5 ? row[5] : 0
                        Timestamp := row.HasProp("Length") && row.Length >= 6 ? row[6] : ""
                        SourcePath := row.HasProp("Length") && row.Length >= 7 ? row[7] : ""
                        LastCopyTime := row.HasProp("Length") && row.Length >= 8 ? row[8] : Timestamp
                        CopyCount := row.HasProp("Length") && row.Length >= 9 ? row[9] : 1
                    }
                    
                    ; 生成预览文本（截取前100个字符）
                    Preview := SubStr(Content, 1, 100)
                    if (StrLen(Content) > 100) {
                        Preview .= "..."
                    }
                    
                    ; 格式化时间
                    try {
                        TimeFormatted := FormatTime(LastCopyTime ? LastCopyTime : Timestamp, "yyyy-MM-dd HH:mm:ss")
                    } catch as err {
                        TimeFormatted := LastCopyTime ? LastCopyTime : Timestamp
                    }
                    
                    ; 构建标题 Emoji 前缀
                    TitlePrefix := ""
                    if (DataType = "Code") {
                        TitlePrefix := "💻 [代码] "
                    } else if (DataType = "Link") {
                        TitlePrefix := "🔗 [链接] "
                    } else if (DataType = "Email") {
                        TitlePrefix := "📧 [邮件] "
                    } else if (DataType = "Image") {
                        TitlePrefix := "🖼️ [图片] "
                    } else if (DataType = "Color") {
                        TitlePrefix := "🎨 [颜色] "
                    } else if (DataType = "Text") {
                        TitlePrefix := "📝 [文本] "
                    }
                    
                    ; 构建子标题（包含来源应用、字数等信息）
                    SubTitle := ""
                    if (SourceApp && SourceApp != "") {
                        SubTitle := "来自: " . SourceApp
                    }
                    if (CharCount && CharCount > 0) {
                        if (SubTitle != "") {
                            SubTitle .= " | 字数: " . CharCount
                        } else {
                            SubTitle := "字数: " . CharCount
                        }
                    }
                    if (SubTitle != "") {
                        SubTitle .= " · " . TimeFormatted
                    } else {
                        SubTitle := TimeFormatted
                    }
                    
                    ; 获取数据类型显示名称
                    DataTypeDisplayName := "剪贴板历史"
                    if (DataType = "Code") {
                        DataTypeDisplayName := "代码片段"
                    } else if (DataType = "Link") {
                        DataTypeDisplayName := "链接"
                    } else if (DataType = "Email") {
                        DataTypeDisplayName := "邮箱"
                    } else if (DataType = "Color") {
                        DataTypeDisplayName := "颜色"
                    } else if (DataType = "Image") {
                        DataTypeDisplayName := "图片"
                    } else if (DataType = "Text") {
                        DataTypeDisplayName := "文本"
                    }
                    
                    ; 生成带 Emoji 前缀的标题
                    DisplayTitle := TitlePrefix . Preview
                    
                    ResultItem := {
                        DataType: "clipboard",
                        DataTypeName: DataTypeDisplayName,
                        ID: ID,
                        Title: DisplayTitle,
                        SubTitle: SubTitle,
                        Content: Content,
                        Preview: Preview,
                        Time: TimeFormatted,
                        TimeFormatted: TimeFormatted,
                        Timestamp: LastCopyTime ? LastCopyTime : Timestamp,
                        Source: DataTypeDisplayName,  ; 【新增】添加 Source 字段，用于 ListView 显示
                        Metadata: Map(
                            "SourceApp", SourceApp ? SourceApp : "",
                            "SourcePath", SourcePath ? SourcePath : "",
                            "DataType", DataType ? DataType : "",
                            "Timestamp", Timestamp,
                            "TimeFormatted", TimeFormatted,
                            "CharCount", CharCount ? CharCount : 0,
                            "CopyCount", CopyCount ? CopyCount : 1
                        )
                    }
                    
                    Results.Push(ResultItem)
                }
            }
        } catch as err {
            ; 错误处理
            OutputDebug("SearchClipboardFTS5ForSearchCenter 遍历结果时出错: " . err.Message)
        }
        
    } catch as err {
        ; 错误处理
        OutputDebug("SearchClipboardFTS5ForSearchCenter 错误: " . err.Message)
    }
    
    return Results
}

; 搜索剪贴板历史（优先使用新的 FTS5 数据库 ClipMain）
SearchClipboardHistory(Keyword, MaxResults := 10, Offset := 0) {
    global ClipboardDB, ClipboardFTS5DB
    Results := []
    
    ; 【新增】优先使用新的剪贴板数据库（ClipMain）
    if (ClipboardFTS5DB && ClipboardFTS5DB != 0) {
        Results := SearchClipboardFTS5ForSearchCenter(Keyword, MaxResults, Offset)
        ; 【修复】如果新数据库有结果，直接返回；如果没有结果，回退到旧数据库查询
        if (Results.Length > 0) {
            return Results
        }
    }
    
    ; 回退到旧数据库（ClipboardHistory）
    if (!ClipboardDB || ClipboardDB = 0) {
        return Results
    }
    
    KeywordLower := StrLower(Keyword)
    ; 【增强搜索】支持多字段搜索：Content, SourceApp, SourceTitle, SourcePath, DataType
    ; 【修复】使用 ORDER BY Timestamp DESC 确保按时间倒序排列
    ; 支持分页：查询 limit+1 条数据，用于检测是否还有更多
    SQL := "SELECT ID, Content, SourceApp, SourceTitle, SourcePath, DataType, Timestamp, CharCount, WordCount FROM ClipboardHistory WHERE LOWER(Content) LIKE ? OR LOWER(SourceApp) LIKE ? OR LOWER(SourceTitle) LIKE ? OR LOWER(SourcePath) LIKE ? OR LOWER(DataType) LIKE ? ORDER BY Timestamp DESC LIMIT " . (MaxResults + 1) . " OFFSET " . Offset

    ST := ""
    try {
        if (!ClipboardDB.Prepare(SQL, &ST)) {
            return Results
        }

        ; 检查ST是否是有效的Statement对象
        if (!IsObject(ST) || !ST.HasProp("Bind")) {
            return Results
        }

        ; 使用小写关键词进行搜索（绑定所有搜索字段）
        SearchPattern := "%" . KeywordLower . "%"
        if (!ST.Bind(1, "Text", SearchPattern)) {
            return Results
        }
        if (!ST.Bind(2, "Text", SearchPattern)) {
            return Results
        }
        if (!ST.Bind(3, "Text", SearchPattern)) {
            return Results
        }
        if (!ST.Bind(4, "Text", SearchPattern)) {
            return Results
        }
        if (!ST.Bind(5, "Text", SearchPattern)) {
            return Results
        }
        ; 注意：LIMIT 和 OFFSET 已经在 SQL 中，不需要绑定

        ; 检查是否还有更多数据
        rowCount := 0
        while (ST.Step() && rowCount < MaxResults) {
            rowCount++
            ID := ST.Column(0)
            Content := ST.Column(1)
            SourceApp := ST.Column(2)
            SourceTitle := ST.Column(3)
            SourcePath := ST.Column(4)
            DataType := ST.Column(5)
            Timestamp := ST.Column(6)
            CharCount := ST.Column(7)
            WordCount := ST.Column(8)

            ; 生成预览文本（截取前100个字符）
            Preview := SubStr(Content, 1, 100)
            if (StrLen(Content) > 100) {
                Preview .= "..."
            }

            ; 格式化时间
            try {
                TimeFormatted := FormatTime(Timestamp, "yyyy-MM-dd HH:mm:ss")
            } catch as err {
                TimeFormatted := Timestamp
            }

            ; 构建标题 Emoji 前缀
            TitlePrefix := ""
            if (DataType = "Code") {
                TitlePrefix := "💻 [代码] "
            } else if (DataType = "Link") {
                TitlePrefix := "🔗 [链接] "
            } else if (DataType = "Email") {
                TitlePrefix := "📧 [邮件] "
            } else if (DataType = "Image") {
                TitlePrefix := "🖼️ [图片] "
            } else if (DataType = "Text") {
                TitlePrefix := "📝 [文本] "
            }

            ; 构建子标题（包含来源应用、字数等信息）
            SubTitle := ""
            if (SourceApp && SourceApp != "") {
                SubTitle := "来自: " . SourceApp
            }
            if (CharCount && CharCount > 0) {
                if (SubTitle != "") {
                    SubTitle .= " | 字数: " . CharCount
                } else {
                    SubTitle := "字数: " . CharCount
                }
            }
            if (SubTitle != "") {
                SubTitle .= " · " . TimeFormatted
            } else {
                SubTitle := TimeFormatted
            }

            ; 获取数据类型显示名称
            DataTypeDisplayName := "剪贴板历史"
            if (DataType = "Code") {
                DataTypeDisplayName := "代码片段"
            } else if (DataType = "Link") {
                DataTypeDisplayName := "链接"
            } else if (DataType = "Email") {
                DataTypeDisplayName := "邮箱"
            } else if (DataType = "File") {
                DataTypeDisplayName := "文件"
            } else if (DataType = "Image") {
                DataTypeDisplayName := "图片"
            } else if (DataType = "Text") {
                DataTypeDisplayName := "文本"
            }

            ; 生成带 Emoji 前缀的标题
            DisplayTitle := TitlePrefix . Preview
            
            ResultItem := {
                DataType: "clipboard",
                DataTypeName: DataTypeDisplayName,
                ID: ID,
                Title: DisplayTitle,
                SubTitle: SubTitle,
                Content: Content,
                Preview: Preview,
                Timestamp: Timestamp,  ; 添加时间戳字段用于排序
                Metadata: Map(
                    "SourceApp", SourceApp ? SourceApp : "",
                    "SourceTitle", SourceTitle ? SourceTitle : "",
                    "SourcePath", SourcePath ? SourcePath : "",
                    "DataType", DataType ? DataType : "",
                    "Timestamp", Timestamp,
                    "TimeFormatted", TimeFormatted,
                    "CharCount", CharCount ? CharCount : 0,
                    "WordCount", WordCount ? WordCount : 0
                ),
                Action: "copy_to_clipboard",
                ActionParams: Map("ID", ID, "Content", Content)
            }

            Results.Push(ResultItem)
        }
    } catch as e {
        ; 错误处理
    } finally {
        ; 使用局部 ST，避免干扰其他模块正在使用的全局 SQLite 语句句柄
        try {
            if (IsObject(ST) && ST.HasProp("Free")) {
                ST.Free()
            }
        } catch as err {
        }
    }
    
    return Results
}

; 搜索提示词模板
SearchPromptTemplates(Keyword, MaxResults := 10, Offset := 0) {
    global PromptTemplates
    Results := []
    
    ; 【修复】如果关键词为空，直接返回空结果
    if (StrLen(Keyword) < 1) {
        return Results
    }
    
    if (!IsSet(PromptTemplates) || PromptTemplates.Length = 0) {
        return Results
    }
    
    KeywordLower := StrLower(Keyword)
    Count := 0
    skipped := 0  ; 跳过的数量（用于 offset）
    
    for Index, Template in PromptTemplates {
        ; 跳过 offset 数量的结果
        if (skipped < Offset) {
            skipped++
            continue
        }
        
        if (Count >= MaxResults) {
            break
        }
        
        ; 搜索标题、内容、分类
        TitleMatch := InStr(StrLower(Template.Title), KeywordLower)
        ContentMatch := InStr(StrLower(Template.Content), KeywordLower)
        CategoryMatch := InStr(StrLower(Template.Category), KeywordLower)
        
        if (TitleMatch || ContentMatch || CategoryMatch) {
            ; 生成内容预览
            ContentPreview := SubStr(Template.Content, 1, 80)
            if (StrLen(Template.Content) > 80) {
                ContentPreview .= "..."
            }
            
            ; 为模板添加时间戳用于排序
            ; 如果没有时间戳，使用当前时间（模板会显示在一起，按索引顺序）
            TemplateTimestamp := ""
            if (Template.HasProp("Timestamp") && Template.Timestamp != "") {
                TemplateTimestamp := Template.Timestamp
            } else {
                ; 使用当前时间作为模板时间戳
                ; SQLite DATETIME 格式通常是 "YYYY-MM-DD HH:MM:SS"
                ; 转换为相同格式以确保正确排序
                CurrentTime := A_Now
                ; A_Now 格式：yyyyMMddHHmmss
                ; 转换为 SQLite 格式：yyyy-MM-dd HH:mm:ss
                Year := SubStr(CurrentTime, 1, 4)
                Month := SubStr(CurrentTime, 5, 2)
                Day := SubStr(CurrentTime, 7, 2)
                Hour := SubStr(CurrentTime, 9, 2)
                Min := SubStr(CurrentTime, 11, 2)
                Sec := SubStr(CurrentTime, 13, 2)
                TemplateTimestamp := Format("{}-{}-{} {}:{}:{}", Year, Month, Day, Hour, Min, Sec)
            }
            
            ResultItem := {
                DataType: "template",
                DataTypeName: "提示词模板",
                ID: Template.ID,
                Title: Template.Title,
                SubTitle: Template.Category . " · " . ContentPreview,
                Content: Template.Content,
                Preview: ContentPreview,
                Timestamp: TemplateTimestamp,  ; 添加时间戳字段
                Metadata: Map(
                    "Category", Template.Category,
                    "Icon", Template.HasProp("Icon") ? Template.Icon : "",
                    "FunctionCategory", Template.HasProp("FunctionCategory") ? Template.FunctionCategory : "",
                    "Series", Template.HasProp("Series") ? Template.Series : ""
                ),
                Action: "send_to_cursor",
                ActionParams: Map("TemplateID", Template.ID, "Template", Template)
            }
            
            Results.Push(ResultItem)
            Count++
        }
    }
    
    return Results
}

; 搜索配置项
SearchConfigItems(Keyword, MaxResults := 10, Offset := 0) {
    global ConfigFile
    Results := []
    
    ; 【修复】如果关键词为空，直接返回空结果
    if (StrLen(Keyword) < 1) {
        return Results
    }
    
    if (!FileExist(ConfigFile)) {
        return Results
    }
    
    KeywordLower := StrLower(Keyword)
    Count := 0
    Skipped := 0
    
    ; 【Bug修复3】扩展配置项映射，包括标签页名称搜索
    ; 定义配置项映射（配置项名称 -> 所属标签页）
    ConfigSections := Map(
        "General", "general",
        "Settings", "general",
        "Prompts", "prompts",
        "Hotkeys", "hotkeys",
        "Appearance", "appearance",
        "Advanced", "advanced"
    )
    
    ; 定义标签页名称映射（用于搜索标签页）
    TabNameMap := Map(
        "通用", "general",
        "General", "general",
        "外观", "appearance",
        "Appearance", "appearance",
        "提示词", "prompts",
        "Prompts", "prompts",
        "快捷键", "hotkeys",
        "Hotkeys", "hotkeys",
        "高级", "advanced",
        "Advanced", "advanced"
    )
    
    ; 搜索标签页名称
    for TabName, TabKey in TabNameMap {
        if (Count >= MaxResults) {
            break
        }
        
        if (InStr(StrLower(TabName), KeywordLower)) {
            ; 跳过前 Offset 个结果
            if (Skipped < Offset) {
                Skipped++
                continue
            }
            
            ResultItem := {
                DataType: "config",
                DataTypeName: "配置项",
                ID: "config_tab_" . TabKey,
                Title: TabName . "标签页",
                SubTitle: "标签页 · 配置面板",
                Content: "跳转到" . TabName . "标签页",
                Preview: "点击跳转到" . TabName . "标签页",
                Metadata: Map(
                    "Section", "",
                    "Key", "",
                    "TabName", TabKey
                ),
                Action: "jump_to_config",
                ActionParams: Map("TabName", TabKey, "Section", "", "Key", "")
            }
            
            Results.Push(ResultItem)
            Count++
        }
    }
    
    ; 读取所有配置节
    for SectionName, TabName in ConfigSections {
        try {
            ; 获取节下的所有键
            SectionContent := IniRead(ConfigFile, SectionName)
            if (SectionContent) {
                ; 解析键值对
                Loop Parse, SectionContent, "`n" {
                    if (Count >= MaxResults) {
                        break
                    }
                    
                    Line := Trim(A_LoopField)
                    if (Line = "") {
                        continue
                    }
                    
                    ; 解析键值对（格式：Key=Value）
                    KeyValuePos := InStr(Line, "=")
                    if (KeyValuePos > 0) {
                        Key := Trim(SubStr(Line, 1, KeyValuePos - 1))
                        Value := Trim(SubStr(Line, KeyValuePos + 1))
                        
                    ; 搜索键名和值
                    KeyMatch := InStr(StrLower(Key), KeywordLower)
                    ValueMatch := InStr(StrLower(Value), KeywordLower)
                    
                    if (KeyMatch || ValueMatch) {
                        ; 跳过前 Offset 个结果
                        if (Skipped < Offset) {
                            Skipped++
                            continue
                        }
                        
                        ; 截取值预览
                        ValuePreview := SubStr(Value, 1, 60)
                        if (StrLen(Value) > 60) {
                            ValuePreview .= "..."
                        }
                        
                        ResultItem := {
                            DataType: "config",
                            DataTypeName: "配置项",
                            ID: SectionName . "." . Key,
                            Title: Key,
                            SubTitle: SectionName . " · " . ValuePreview,
                            Content: Value,
                            Preview: ValuePreview,
                            Metadata: Map(
                                "Section", SectionName,
                                "Key", Key,
                                "TabName", TabName
                            ),
                            Action: "jump_to_config",
                            ActionParams: Map("TabName", TabName, "Section", SectionName, "Key", Key)
                        }
                        
                        Results.Push(ResultItem)
                        Count++
                    }
                    }
                }
            }
        } catch as err {
            ; 忽略读取错误
        }
    }
    
    return Results
}

; ===================== Fzy 风格子序列打分（纯 InStr/SubStr，无外部 DLL）=====================
; 子序列不匹配返回 -100；否则首字/边界/CamelCase/连续/Gap/路径深度加权汇总
FzyScore(query, target) {
    if (StrLen(query) = 0 || StrLen(target) = 0)
        return 0
    qL := StrLower(query)
    tL := StrLower(target)
    lenQ := StrLen(qL)
    lenT := StrLen(tL)
    pos := []
    start := 1
    Loop lenQ {
        ch := SubStr(qL, A_Index, 1)
        found := InStr(tL, ch, false, start)
        if (!found)
            return -100
        pos.Push(found)
        start := found + 1
    }
    slashCount := 0
    Loop lenT {
        if (SubStr(target, A_Index, 1) = "\")
            slashCount += 1
    }
    score := 0.0
    ; 精准：整段关键词在路径中连续出现（比子序列更贴近「打什么搜什么」）
    if (InStr(tL, qL))
        score += 480.0
    ; 精准：路径以关键词开头（前缀匹配）
    if (StrLen(qL) <= lenT && SubStr(tL, 1, lenQ) = qL)
        score += 220.0
    ; 精准：仅看最后一段文件名（用户多搜文件名而非盘符路径）
    fnSeg := target
    Loop {
        p := InStr(fnSeg, "\")
        if (!p)
            break
        fnSeg := SubStr(fnSeg, p + 1)
    }
    fnL := StrLower(fnSeg)
    if (fnL = qL)
        score += 420.0
    else if (StrLen(qL) <= StrLen(fnL) && SubStr(fnL, 1, lenQ) = qL)
        score += 260.0
    else if (InStr(fnL, qL))
        score += 140.0
    ; 首字：第一次命中在 target 第 1 位
    if (pos[1] = 1)
        score += 100
    for k, p in pos {
        curCh := SubStr(target, p, 1)
        if (p > 1) {
            prevCh := SubStr(target, p - 1, 1)
            oPrev := Ord(prevCh)
            ; 词首/边界：分隔符后匹配
            if (prevCh = "\" || prevCh = "/" || prevCh = "_" || prevCh = "-" || prevCh = "." || prevCh = " ")
                score += 80
            ; CamelCase：小写后跟大写
            oCur := Ord(curCh)
            if (oCur >= 65 && oCur <= 90 && oPrev >= 97 && oPrev <= 122)
                score += 60
        }
        if (k > 1) {
            prevP := pos[k - 1]
            gap := p - prevP - 1
            score -= 2 * gap
            ; 连续性：与前一次命中相邻
            if (p = prevP + 1)
                score += 50
        }
    }
    ; 路径深度：总长与反斜杠越多略扣分，浅层路径优先
    score -= StrLen(target) * 0.02
    score -= slashCount * 1.0
    return score
}

ComputeSearchItemFinalScore(Item, Keyword, path) {
    fs := FzyScore(Keyword, path)
    Item.FzyBase := fs
    tr := Item.HasProp("PathTrust") ? Item.PathTrust : 1.0
    b := Item.HasProp("BonusTotal") ? Item.BonusTotal : 0.0
    p := Item.HasProp("PenaltyTotal") ? Item.PenaltyTotal : 0.0
    Item.FinalScore := fs * tr + b - p
    Item.FzyScore := Item.FinalScore
    Item.FzyCategoryBonus := b - p
    if (Item.HasProp("Metadata") && IsObject(Item.Metadata)) {
        try {
            Item.Metadata["FzyScore"] := Item.FinalScore
            Item.Metadata["FzyBase"] := fs
        } catch {
        }
    }
}

SortSearchResultsByFzy(&Results, Keyword) {
    if (Results.Length = 0 || StrLen(Keyword) < 1)
        return
    Loop Results.Length {
        Item := Results[A_Index]
        path := Item.HasProp("Preview") ? Item.Preview : (Item.HasProp("Content") ? Item.Content : "")
        if (path = "" && Item.HasProp("Metadata") && IsObject(Item.Metadata) && Item.Metadata.Has("FilePath"))
            path := Item.Metadata["FilePath"]
        ComputeSearchItemFinalScore(Item, Keyword, path)
        Item._FzyStableIdx := A_Index
    }
    Results.Sort(FzyScoreResultItemStableCompare)
}

FzyScoreResultItemStableCompare(a, b, *) {
    sa := a.HasProp("FinalScore") ? a.FinalScore : (a.HasProp("FzyScore") ? a.FzyScore : -1e30)
    sb := b.HasProp("FinalScore") ? b.FinalScore : (b.HasProp("FzyScore") ? b.FzyScore : -1e30)
    if (Abs(sa - sb) > 1e-9) {
        diff := sb - sa
        return diff > 0 ? 1 : (diff < 0 ? -1 : 0)
    }
    ia := a.HasProp("_FzyStableIdx") ? a._FzyStableIdx : 0
    ib := b.HasProp("_FzyStableIdx") ? b._FzyStableIdx : 0
    return ia - ib
}

FinalizeSearchFilePathsResults(&Results, Keyword) {
    if (Results.Length = 0 || StrLen(Keyword) < 1)
        return
    try {
        FileClassifier.ProcessResults(&Results, Keyword)
    } catch as err {
        OutputDebug("AHK_DEBUG: FileClassifier.ProcessResults 失败: " . err.Message)
    }
    try {
        SortSearchResultsByFzy(&Results, Keyword)
    } catch as err {
        ; 排序失败时保留 Everything 返回顺序，避免整段文件结果丢失
        OutputDebug("AHK_DEBUG: FzyScore 排序失败，保留原始顺序: " . err.Message)
    }
    ; 父目录折叠仅在 SortSearchCenterMergedResults 中执行一次（排序后），避免与扁平化结果重复扣分
}

; 搜索中心：非文件条目的简单相关度（标题/内容含关键词），用于排在文件结果之后时内部排序
SearchCenterOtherRelevance(Keyword, item) {
    if (StrLen(Keyword) < 1)
        return 0.0
    kw := StrLower(Keyword)
    title := item.HasProp("Title") ? StrLower(item.Title) : ""
    content := item.HasProp("Content") ? StrLower(item.Content) : ""
    sc := 0.0
    if (title = kw)
        sc += 300.0
    else if (StrLen(kw) <= StrLen(title) && SubStr(title, 1, StrLen(kw)) = kw)
        sc += 180.0
    else if (InStr(title, kw))
        sc += 90.0
    if (InStr(content, kw))
        sc += 40.0
    ; 剪贴板：关键词命中来源进程名或友好名时提高排序
    try {
        if (item.HasProp("OriginalDataType") && item.OriginalDataType = "clipboard") {
            if (item.HasProp("Metadata") && IsObject(item.Metadata) && item.Metadata.Has("SourceApp")) {
                sa := StrLower(String(item.Metadata["SourceApp"]))
                fr := StrLower(ShellIcon_FriendlyNameFromExe(item.Metadata["SourceApp"]))
                if (InStr(sa, kw) || (fr != "" && InStr(fr, kw)))
                    sc += 95.0
            }
        }
    } catch {
    }
    return sc
}

; 搜索中心：扁平化后根据关键词与 SourceApp 对齐展示标题/副标题（排序前调用）
SyncIdentityToResultItem(&item, Keyword) {
    kw := Trim(Keyword)
    if (kw = "")
        return
    kwLower := StrLower(kw)
    if (!(item.HasProp("OriginalDataType") && item.OriginalDataType = "clipboard"))
        return
    if (!item.HasProp("Metadata") || !IsObject(item.Metadata))
        return
    sa := item.Metadata.Has("SourceApp") ? String(item.Metadata["SourceApp"]) : ""
    if (sa = "" || sa = "Unknown")
        return
    content := item.HasProp("Content") ? String(item.Content) : ""
    hitContent := InStr(StrLower(content), kwLower)
    friendly := ShellIcon_FriendlyNameFromExe(sa)
    if (friendly = "")
        friendly := sa
    hitApp := InStr(StrLower(sa), kwLower) || InStr(StrLower(friendly), kwLower)
    if (hitApp && !hitContent) {
        zh := (SubStr(A_Language, 1, 2) = "zh")
        prefix := zh ? "[来自 " . friendly . "] " : "[From " . friendly . "] "
        dt := ""
        if (item.HasProp("DisplayTitle") && item.DisplayTitle != "")
            dt := item.DisplayTitle
        else if (item.HasProp("Title") && item.Title != "")
            dt := item.Title
        else
            dt := SubStr(content, 1, 220)
        if (SubStr(dt, 1, StrLen(prefix)) != prefix && !InStr(dt, "[来自 ") && !InStr(dt, "[From "))
            item.DisplayTitle := prefix . dt
    }
    timeFmt := item.HasProp("Time") ? item.Time : ""
    if (timeFmt = "" && item.Metadata.Has("TimeFormatted")) {
        try timeFmt := String(item.Metadata["TimeFormatted"])
    }
    charCount := 0
    try {
        if (item.Metadata.Has("CharCount"))
            charCount := Integer(item.Metadata["CharCount"])
    } catch {
    }
    sub := friendly . " › " . timeFmt
    if (charCount > 0)
        sub := friendly . " · " . charCount . " 字 › " . timeFmt
    item.DisplaySubtitle := sub
}

SearchCenterOtherCompare(a, b, *) {
    sa := a.HasProp("SearchCenterScore") ? a.SearchCenterScore : 0.0
    sb := b.HasProp("SearchCenterScore") ? b.SearchCenterScore : 0.0
    if (Abs(sa - sb) > 1e-9) {
        diff := sb - sa
        return diff > 0 ? 1 : (diff < 0 ? -1 : 0)
    }
    ia := a.HasProp("_scIdx") ? a._scIdx : 0
    ib := b.HasProp("_scIdx") ? b._scIdx : 0
    return ia - ib
}

; 搜索中心混排：文件类 FinalScore = Fzy×Trust + Bonus − Penalty；父目录折叠；Top9 分类配额
SortSearchCenterMergedResults(&items, Keyword) {
    if (items.Length = 0 || StrLen(Keyword) < 1)
        return
    fileArr := []
    otherArr := []
    for item in items {
        if (item.HasProp("OriginalDataType") && item.OriginalDataType = "file")
            fileArr.Push(item)
        else
            otherArr.Push(item)
    }
    if (fileArr.Length > 0) {
        kwLower := StrLower(Keyword)
        Loop fileArr.Length {
            p := fileArr[A_Index].HasProp("Content") ? fileArr[A_Index].Content : ""
            ComputeSearchItemFinalScore(fileArr[A_Index], Keyword, p)
            fileArr[A_Index]._FzyStableIdx := A_Index
            try {
                if (p != "" && FileExist(p) && !DirExist(p)) {
                    SplitPath(p, &fn)
                    fnl := StrLower(fn)
                    stem := StrReplace(fnl, ".exe", "")
                    if (fnl = kwLower || fnl = kwLower . ".exe" || stem = kwLower)
                        fileArr[A_Index].FinalScore += 45.0
                }
            } catch {
            }
        }
        try fileArr.Sort(FzyScoreResultItemStableCompare)
        try FileClassifier.ApplyParentDirectoryCollapse(&fileArr)
        try FileClassifier.ApplyTop9CategoryQuota(&fileArr)
    }
    if (otherArr.Length > 0) {
        Loop otherArr.Length {
            otherArr[A_Index].SearchCenterScore := SearchCenterOtherRelevance(Keyword, otherArr[A_Index])
            otherArr[A_Index]._scIdx := A_Index
        }
        try otherArr.Sort(SearchCenterOtherCompare)
    }
    items.Length := 0
    for x in fileArr
        items.Push(x)
    for x in otherArr
        items.Push(x)
}

SearchResultItemIsFileLike(Item) {
    if (Item.HasProp("DataType")) {
        dt := Item.DataType
        if (dt = "file" || dt = "folder")
            return true
    }
    if (Item.HasProp("Source")) {
        s := Item.Source
        if (s = "文件" || s = "文件夹" || s = "文件路径")
            return true
    }
    return false
}

BubbleSortSearchItemsByTimestampDesc(&arr) {
    if (arr.Length <= 1)
        return
    Loop arr.Length - 1 {
        i := A_Index
        Loop arr.Length - i {
            j := A_Index + i
            TimeI := arr[i].HasProp("Timestamp") ? arr[i].Timestamp : ""
            TimeJ := arr[j].HasProp("Timestamp") ? arr[j].Timestamp : ""
            if (TimeI = "" && TimeJ != "") {
                temp := arr[i]
                arr[i] := arr[j]
                arr[j] := temp
            } else if (TimeI != "" && TimeJ != "") {
                if (StrCompare(TimeJ, TimeI) > 0) {
                    temp := arr[i]
                    arr[i] := arr[j]
                    arr[j] := temp
                }
            }
        }
    }
}

; 判断是否为文件路径
IsFilePath(Path) {
    ; 检查Windows路径格式（C:\、\\server\等）
    if (RegExMatch(Path, "^(?:[A-Za-z]:\\|\\\\).*")) {
        return FileExist(Path) || DirExist(Path)
    }
    
    ; 检查URL格式
    if (RegExMatch(Path, "^(?:https?|file)://.*")) {
        return true
    }
    
    ; 检查相对路径（以.\或..\开头）
    if (RegExMatch(Path, "^(?:\.\.?[/\\]).*")) {
        return FileExist(Path) || DirExist(Path)
    }
    
    return false
}

NormalizeWindowsPath(path) {
    p := Trim(path)
    if (p = "")
        return p
    ; 统一分隔符，去掉多余反斜杠（保留 UNC 前缀）
    p := StrReplace(p, "/", "\")
    if (RegExMatch(p, "^\\\\[^\\]+\\[^\\]+")) {
        p := "\\" . RegExReplace(SubStr(p, 3), "\\{2,}", "\")
    } else {
        p := RegExReplace(p, "\\{2,}", "\")
    }
    return p
}

; 搜索文件路径
SearchFilePaths(Keyword, MaxResults := 10, Offset := 0) {
    global ClipboardDB, SearchCenterEverythingLimit
    Results := []
    
    ; 【修复】如果关键词为空，直接返回空结果
    if (StrLen(Keyword) < 1) {
        return Results
    }
    
    ; 【关键修复】参考CapsLock+F的实现：优先使用Everything64.dll进行文件搜索（关键词非空即可，含单字符）
    try {
            ; 调用GetEverythingResults获取文件搜索结果（增加 limit 以检测是否还有更多）
            ; 使用下拉菜单设置的结果数量限制（如果设置了，优先使用；否则使用 MaxResults）
            everythingLimit := SearchCenterEverythingLimit > 0 ? SearchCenterEverythingLimit : MaxResults
            EverythingResults := GetEverythingResults(Keyword, everythingLimit + Offset + 1, true)  ; 包含文件夹
            ; 若 IPC 已通但暂无结果，尝试启动 Everything 客户端后再查一次（常见：未常驻）
            if (EverythingResults.Length = 0) {
                startedEv := ""
                if (TryStartEverything(&startedEv)) {
                    Sleep(400)
                    EverythingResults := GetEverythingResults(Keyword, everythingLimit + Offset + 1, true)
                }
            }
            
            ; 跳过 offset 数量的结果（修复：使用数组切片而不是单个元素）
            if (Offset > 0 && EverythingResults.Length > Offset) {
                ; 创建新数组，包含从 Offset+1 开始的所有元素
                slicedResults := []
                Loop EverythingResults.Length - Offset {
                    slicedResults.Push(EverythingResults[Offset + A_Index])
                }
                EverythingResults := slicedResults
            } else if (Offset > 0) {
                EverythingResults := []  ; offset 超出范围
            }
            
            ; 检查是否还有更多数据
            hasMore := (EverythingResults.Length > MaxResults)
            if (hasMore) {
                EverythingResults.Pop()  ; 移除多查询的一条
            }
            
            ; 将Everything搜索结果转换为统一格式
            for index, result in EverythingResults {
                ; 处理新的Map格式结果
                if (Type(result) = "Map") {
                    path := result["Path"]
                    isDirectory := result["IsDirectory"]
                    fileSize := result.Has("Size") ? result["Size"] : 0
                    dateModified := result.Has("DateModified") ? result["DateModified"] : 0
                    
                    SplitPath(path, &FileName, &DirPath, &Ext, &NameNoExt)
                    
                    ; 格式化文件大小
                    sizeStr := ""
                    if (!isDirectory && fileSize > 0) {
                        if (fileSize < 1024) {
                            sizeStr := fileSize . " B"
                        } else if (fileSize < 1048576) {
                            sizeStr := Round(fileSize / 1024, 2) . " KB"
                        } else if (fileSize < 1073741824) {
                            sizeStr := Round(fileSize / 1048576, 2) . " MB"
                        } else {
                            sizeStr := Round(fileSize / 1073741824, 2) . " GB"
                        }
                    }
                    
                    ; 格式化修改日期
                    dateStr := ""
                    if (dateModified > 0) {
                        try {
                            ; 将FILETIME转换为日期字符串
                            ; FILETIME是自1601年1月1日以来的100纳秒间隔数
                            ; 使用Windows API FileTimeToSystemTime和SystemTimeToFileTime
                            ; 或者直接使用FileTimeToLocalFileTime + FileTimeToSystemTime
                            ; 简化处理：使用FormatTime需要先转换为系统时间
                            ; 这里使用一个辅助函数来转换
                            ; 由于AHK v2的FormatTime不支持FILETIME，我们使用DllCall
                            fileTime := Buffer(8)
                            NumPut("Int64", dateModified, fileTime)
                            
                            ; 转换为本地文件时间
                            localFileTime := Buffer(8)
                            if (DllCall("FileTimeToLocalFileTime", "Ptr", fileTime.Ptr, "Ptr", localFileTime.Ptr)) {
                                ; 转换为系统时间
                                systemTime := Buffer(16)  ; SYSTEMTIME结构
                                if (DllCall("FileTimeToSystemTime", "Ptr", localFileTime.Ptr, "Ptr", systemTime.Ptr)) {
                                    ; 提取年月日时分
                                    year := NumGet(systemTime, 0, "UShort")
                                    month := NumGet(systemTime, 2, "UShort")
                                    day := NumGet(systemTime, 4, "UShort")
                                    hour := NumGet(systemTime, 6, "UShort")
                                    minute := NumGet(systemTime, 8, "UShort")
                                    dateStr := Format("{:04d}-{:02d}-{:02d} {:02d}:{:02d}", year, month, day, hour, minute)
                                }
                            }
                        } catch {
                            dateStr := ""
                        }
                    }
                    
                    ; 构建副标题
                    subTitleParts := []
                    if (DirPath != "") {
                        subTitleParts.Push(DirPath)
                    }
                    if (isDirectory) {
                        subTitleParts.Push("文件夹")
                    } else {
                        if (Ext != "") {
                            subTitleParts.Push(Ext)
                        } else {
                            subTitleParts.Push("文件")
                        }
                    }
                    if (sizeStr != "") {
                        subTitleParts.Push(sizeStr)
                    }
                    if (dateStr != "") {
                        subTitleParts.Push(dateStr)
                    }
                    subTitle := ""
                    for i, part in subTitleParts {
                        if (i > 1) {
                            subTitle .= " · "
                        }
                        subTitle .= part
                    }
                    
                    ResultItem := {
                        DataType: isDirectory ? "folder" : "file",
                        DataTypeName: isDirectory ? "文件夹" : "文件",
                        ID: path,
                        Title: FileName,
                        SubTitle: subTitle,
                        Content: path,
                        Preview: path,
                        Source: isDirectory ? "文件夹" : "文件",
                        Metadata: Map(
                            "FilePath", path,
                            "FileName", FileName,
                            "DirPath", DirPath,
                            "Ext", Ext ? Ext : "",
                            "IsDirectory", isDirectory,
                            "Size", fileSize,
                            "DateModified", dateModified,
                            "Timestamp", dateStr
                        ),
                        Action: isDirectory ? "open_folder" : "open_file",
                        ActionParams: Map("FilePath", path)
                    }
                } else {
                    ; 向后兼容：如果返回的是字符串路径
                    path := result
                    SplitPath(path, &FileName, &DirPath, &Ext, &NameNoExt)
                    
                    ResultItem := {
                        DataType: "file",
                        DataTypeName: "文件",
                        ID: path,
                        Title: FileName,
                        SubTitle: DirPath . " · " . (Ext ? Ext : "文件"),
                        Content: path,
                        Preview: path,
                        Source: "文件",
                        Metadata: Map(
                            "FilePath", path,
                            "FileName", FileName,
                            "DirPath", DirPath,
                            "Ext", Ext ? Ext : "",
                            "Timestamp", ""
                        ),
                        Action: "open_file",
                        ActionParams: Map("FilePath", path)
                    }
                }
                
                Results.Push(ResultItem)
            }
    } catch as err {
        ; 如果Everything搜索失败，继续使用数据库搜索作为回退
        OutputDebug("AHK_DEBUG: Everything DLL 搜索失败: " . err.Message)
        EverythingUserTipOnce("文件搜索异常: " . err.Message)
    }
    
    ; 如果Everything搜索结果已满足需求，直接返回
    if (Results.Length >= MaxResults) {
        FinalizeSearchFilePathsResults(&Results, Keyword)
        return Results
    }
    
    ; 回退到数据库搜索：从剪贴板历史中提取文件路径（作为补充）
    if (!ClipboardDB || ClipboardDB = 0) {
        FinalizeSearchFilePathsResults(&Results, Keyword)
        return Results
    }
    
    KeywordLower := StrLower(Keyword)
    Count := Results.Length  ; 从已有结果数量开始计数
    
    ; 从剪贴板历史中提取文件路径
    ; 使用LOWER()函数进行大小写不敏感的搜索
    SQL := "SELECT DISTINCT Content, Timestamp FROM ClipboardHistory WHERE (LOWER(Content) LIKE ? OR LOWER(Content) LIKE ?) ORDER BY Timestamp DESC LIMIT ?"
    ST := ""
    try {
        if (!ClipboardDB.Prepare(SQL, &ST)) {
            FinalizeSearchFilePathsResults(&Results, Keyword)
            return Results
        }
        
        ; 检查ST是否是有效的Statement对象
        if (!IsObject(ST) || !ST.HasProp("Bind")) {
            FinalizeSearchFilePathsResults(&Results, Keyword)
            return Results
        }
        
        ; 搜索路径格式（Windows路径、URL等），使用小写关键词
        ; 限制数量为剩余需要的数量
        RemainingCount := MaxResults - Count
        if (RemainingCount <= 0) {
            FinalizeSearchFilePathsResults(&Results, Keyword)
            return Results
        }
        
        if (!ST.Bind(1, "Text", "%" . KeywordLower . "%")) {
            FinalizeSearchFilePathsResults(&Results, Keyword)
            return Results
        }
        if (!ST.Bind(2, "Text", "file://%" . KeywordLower . "%")) {
            FinalizeSearchFilePathsResults(&Results, Keyword)
            return Results
        }
        if (!ST.Bind(3, "Int", RemainingCount * 2)) {
            FinalizeSearchFilePathsResults(&Results, Keyword)
            return Results
        }
        
        while (ST.Step() && Count < MaxResults) {
            Content := ST.Column(0)
            Timestamp := ST.Column(1)
            
            ; 检查是否为文件路径
            if (IsFilePath(Content)) {
                SplitPath(Content, &FileName, &DirPath, &Ext, &NameNoExt)
                
                ; 检查文件名或路径是否匹配关键词
                if (InStr(StrLower(FileName), KeywordLower) || InStr(StrLower(Content), KeywordLower)) {
                    ; 检查是否已存在（避免重复）
                    IsDuplicate := false
                    for Index, ExistingItem in Results {
                        if (ExistingItem.Content = Content) {
                            IsDuplicate := true
                            break
                        }
                    }
                    
                    if (!IsDuplicate) {
                        ResultItem := {
                            DataType: "file",
                            DataTypeName: "文件路径",
                            ID: Content,
                            Title: FileName,
                            SubTitle: DirPath . " · " . (Ext ? Ext : "文件"),
                            Content: Content,
                            Preview: Content,
                            Source: "文件路径",
                            Metadata: Map(
                                "FilePath", Content,
                                "FileName", FileName,
                                "DirPath", DirPath,
                                "Ext", Ext ? Ext : "",
                                "Timestamp", Timestamp
                            ),
                            Action: "open_file",
                            ActionParams: Map("FilePath", Content)
                        }
                        
                        Results.Push(ResultItem)
                        Count++
                    }
                }
            }
        }
    } catch as e {
        ; 错误处理
    } finally {
        ; 使用局部 ST，避免搜索中心查询时误释放其他模块仍在使用的全局语句句柄
        try {
            if (IsObject(ST) && ST.HasProp("Free")) {
                ST.Free()
            }
        } catch as err {
        }
    }
    
    FinalizeSearchFilePathsResults(&Results, Keyword)
    return Results
}

; 搜索快捷键
SearchHotkeys(Keyword, MaxResults := 10, Offset := 0) {
    global HotkeyESC, HotkeyC, HotkeyV, HotkeyX, HotkeyE, HotkeyR, HotkeyO, HotkeyQ, HotkeyZ, HotkeyT
    global SplitHotkey, BatchHotkey
    Results := []
    
    ; 【修复】如果关键词为空，直接返回空结果
    if (StrLen(Keyword) < 1) {
        return Results
    }
    
    KeywordLower := StrLower(Keyword)
    Count := 0
    Skipped := 0
    
    ; 【Bug修复3】扩展搜索关键词，包括"快捷"、"快捷键"等
    ; 如果关键词包含"快捷"，添加快捷键标签页结果
    if (InStr(KeywordLower, "快捷")) {
        ; 跳过前 Offset 个结果
        if (Skipped >= Offset) {
            ResultItem := {
                DataType: "hotkey",
                DataTypeName: "快捷键",
                ID: "hotkeys_tab",
                Title: "快捷键标签页",
                SubTitle: "标签页 · 配置面板中的快捷键设置",
                Content: "跳转到快捷键标签页",
                Preview: "点击跳转到快捷键标签页",
                Metadata: Map(
                    "TabKey", "hotkeys",
                    "Type", "标签页"
                ),
                Action: "jump_to_config",
                ActionParams: Map("TabName", "hotkeys", "Section", "", "Key", "")
            }
            Results.Push(ResultItem)
            Count++
        } else {
            Skipped++
        }
    }
    
    ; 定义快捷键映射
    HotkeyMap := Map(
        "关闭面板", Map("Hotkey", HotkeyESC, "Function", "关闭面板", "Description", "关闭快捷操作面板"),
        "连续复制", Map("Hotkey", HotkeyC, "Function", "连续复制", "Description", "CapsLock+C 连续复制内容"),
        "合并粘贴", Map("Hotkey", HotkeyV, "Function", "合并粘贴", "Description", "CapsLock+V 合并粘贴所有复制的内容"),
        "剪贴板管理", Map("Hotkey", HotkeyX, "Function", "剪贴板管理", "Description", "CapsLock+X 打开剪贴板管理面板"),
        "解释", Map("Hotkey", HotkeyE, "Function", "解释", "Description", "CapsLock+E 解释代码"),
        "重构", Map("Hotkey", HotkeyR, "Function", "重构", "Description", "CapsLock+R 重构代码"),
        "优化", Map("Hotkey", HotkeyO, "Function", "优化", "Description", "CapsLock+O 优化代码"),
        "配置", Map("Hotkey", HotkeyQ, "Function", "配置", "Description", "CapsLock+Q 打开配置面板"),
        "语音输入", Map("Hotkey", HotkeyZ, "Function", "语音输入", "Description", "CapsLock+Z 语音输入"),
        "区域截图", Map("Hotkey", HotkeyT, "Function", "区域截图", "Description", "CapsLock+T 区域截图"),
        "分割代码", Map("Hotkey", SplitHotkey, "Function", "分割代码", "Description", "CapsLock+" . SplitHotkey . " 分割代码"),
        "批量操作", Map("Hotkey", BatchHotkey, "Function", "批量操作", "Description", "CapsLock+" . BatchHotkey . " 批量操作"),
        "快捷操作", Map("Hotkey", "", "Function", "快捷操作", "Description", "快捷操作按钮面板"),
        "快捷操作按钮", Map("Hotkey", "", "Function", "快捷操作按钮", "Description", "快捷操作按钮面板")
    )
    
    for FunctionName, HotkeyInfo in HotkeyMap {
        if (Count >= MaxResults) {
            break
        }
        
        ; 【Bug修复3】扩展搜索范围：功能名称、快捷键、描述，以及"快捷"相关关键词
        FunctionMatch := InStr(StrLower(FunctionName), KeywordLower)
        HotkeyMatch := InStr(StrLower(HotkeyInfo["Hotkey"]), KeywordLower)
        DescMatch := InStr(StrLower(HotkeyInfo["Description"]), KeywordLower)
        ; 如果关键词包含"快捷"，匹配所有快捷键相关项
        QuickMatch := (InStr(KeywordLower, "快捷") && (InStr(StrLower(FunctionName), "快捷") || InStr(StrLower(HotkeyInfo["Description"]), "快捷")))
        
        if (FunctionMatch || HotkeyMatch || DescMatch || QuickMatch) {
            ; 跳过前 Offset 个结果
            if (Skipped < Offset) {
                Skipped++
                continue
            }
            
            HotkeyDisplay := "CapsLock+" . HotkeyInfo["Hotkey"]
            
            ResultItem := {
                DataType: "hotkey",
                DataTypeName: "快捷键",
                ID: FunctionName,
                Title: FunctionName,
                SubTitle: HotkeyDisplay . " · " . HotkeyInfo["Description"],
                Content: HotkeyInfo["Description"],
                Preview: HotkeyDisplay,
                Metadata: Map(
                    "Hotkey", HotkeyInfo["Hotkey"],
                    "Function", HotkeyInfo["Function"],
                    "Description", HotkeyInfo["Description"]
                ),
                Action: "jump_to_hotkey_config",
                ActionParams: Map("Function", FunctionName)
            }
            
            Results.Push(ResultItem)
            Count++
        }
    }
    
    return Results
}

; 搜索功能
SearchFunctions(Keyword, MaxResults := 10, Offset := 0) {
    Results := []
    
    ; 【修复】如果关键词为空，直接返回空结果
    if (StrLen(Keyword) < 1) {
        return Results
    }
    
    KeywordLower := StrLower(Keyword)
    Count := 0
    Skipped := 0
    
    ; 定义功能列表
    Functions := [
        Map("Name", "解释代码", "Description", "使用AI解释代码逻辑", "Category", "AI功能"),
        Map("Name", "重构代码", "Description", "使用AI重构代码", "Category", "AI功能"),
        Map("Name", "优化代码", "Description", "使用AI优化代码性能", "Category", "AI功能"),
        Map("Name", "剪贴板管理", "Description", "管理剪贴板历史记录", "Category", "工具功能"),
        Map("Name", "语音输入", "Description", "使用语音输入文本", "Category", "工具功能"),
        Map("Name", "语音搜索", "Description", "使用语音搜索", "Category", "工具功能"),
        Map("Name", "区域截图", "Description", "截取屏幕区域", "Category", "工具功能"),
        Map("Name", "模板管理", "Description", "管理提示词模板", "Category", "配置功能")
    ]
    
    for Index, Func in Functions {
        if (Count >= MaxResults) {
            break
        }
        
        NameMatch := InStr(StrLower(Func["Name"]), KeywordLower)
        DescMatch := InStr(StrLower(Func["Description"]), KeywordLower)
        CategoryMatch := InStr(StrLower(Func["Category"]), KeywordLower)
        
        if (NameMatch || DescMatch || CategoryMatch) {
            ; 跳过前 Offset 个结果
            if (Skipped < Offset) {
                Skipped++
                continue
            }
            
            ResultItem := {
                DataType: "function",
                DataTypeName: "功能",
                ID: Func["Name"],
                Title: Func["Name"],
                SubTitle: Func["Category"] . " · " . Func["Description"],
                Content: Func["Description"],
                Preview: Func["Description"],
                Metadata: Map(
                    "Category", Func["Category"],
                    "Description", Func["Description"]
                ),
                Action: "execute_function",
                ActionParams: Map("FunctionName", Func["Name"])
            }
            
            Results.Push(ResultItem)
            Count++
        }
    }
    
    return Results
}

; ===================== 搜索UI标签页和界面元素 =====================
SearchUITabs(Keyword, MaxResults := 10, Offset := 0) {
    Results := []
    
    ; 【修复】如果关键词为空，直接返回空结果
    if (StrLen(Keyword) < 1) {
        return Results
    }
    
    KeywordLower := StrLower(Keyword)
    Count := 0
    Skipped := 0
    
    ; 定义标签页映射（标签页名称 -> 标签页Key）
    TabMap := Map(
        "通用", "general",
        "General", "general",
        "外观", "appearance",
        "Appearance", "appearance",
        "提示词", "prompts",
        "Prompts", "prompts",
        "快捷键", "hotkeys",
        "Hotkeys", "hotkeys",
        "高级", "advanced",
        "Advanced", "advanced",
        "搜索", "search"
    )
    
    ; 定义UI元素映射（按钮/标签文本 -> 标签页Key和描述）
    UIElements := [
        Map("Name", "快捷操作", "Tab", "hotkeys", "Description", "快捷操作按钮面板", "Type", "按钮"),
        Map("Name", "快捷操作按钮", "Tab", "hotkeys", "Description", "快捷操作按钮面板", "Type", "按钮"),
        Map("Name", "快捷键设置", "Tab", "hotkeys", "Description", "快捷键配置页面", "Type", "标签页"),
        Map("Name", "快捷键配置", "Tab", "hotkeys", "Description", "快捷键配置页面", "Type", "标签页"),
        Map("Name", "模板管理", "Tab", "prompts", "Description", "提示词模板管理", "Type", "标签页"),
        Map("Name", "剪贴板管理", "Tab", "general", "Description", "剪贴板历史管理", "Type", "功能"),
        Map("Name", "配置面板", "Tab", "general", "Description", "打开配置面板", "Type", "功能")
    ]
    
    ; 搜索标签页
    for TabName, TabKey in TabMap {
        if (Count >= MaxResults) {
            break
        }
        
        if (InStr(StrLower(TabName), KeywordLower)) {
            ; 跳过前 Offset 个结果
            if (Skipped < Offset) {
                Skipped++
                continue
            }
            
            ResultItem := {
                DataType: "ui",
                DataTypeName: "界面元素",
                ID: "tab_" . TabKey,
                Title: TabName,
                SubTitle: "标签页 · 配置面板",
                Content: "跳转到" . TabName . "标签页",
                Preview: "点击跳转到" . TabName . "标签页",
                Metadata: Map(
                    "TabKey", TabKey,
                    "TabName", TabName,
                    "Type", "标签页"
                ),
                Action: "jump_to_config",
                ActionParams: Map("TabName", TabKey, "Section", "", "Key", "")
            }
            
            Results.Push(ResultItem)
            Count++
        }
    }
    
    ; 搜索UI元素（按钮、功能等）
    for Index, Element in UIElements {
        if (Count >= MaxResults) {
            break
        }
        
        NameMatch := InStr(StrLower(Element["Name"]), KeywordLower)
        DescMatch := InStr(StrLower(Element["Description"]), KeywordLower)
        
        if (NameMatch || DescMatch) {
            ; 跳过前 Offset 个结果
            if (Skipped < Offset) {
                Skipped++
                continue
            }
            ResultItem := {
                DataType: "ui",
                DataTypeName: "界面元素",
                ID: "ui_" . Element["Tab"] . "_" . Element["Name"],
                Title: Element["Name"],
                SubTitle: Element["Type"] . " · " . Element["Description"],
                Content: Element["Description"],
                Preview: Element["Description"],
                Metadata: Map(
                    "TabKey", Element["Tab"],
                    "TabName", Element["Name"],
                    "Type", Element["Type"],
                    "Description", Element["Description"]
                ),
                Action: "jump_to_config",
                ActionParams: Map("TabName", Element["Tab"], "Section", "", "Key", "")
            }
            
            Results.Push(ResultItem)
            Count++
        }
    }
    
    return Results
}

; ===================== 创建搜索标签页 =====================
CreateSearchTab(ConfigGUI, X, Y, W, H) {
    global SearchTabControls, UI_Colors, ThemeMode, SearchHistoryEdit, SearchResultsListView
    global SearchTypeFilterButtons, SearchCurrentFilterType
    
    ; 初始化控件数组
    if (!IsSet(SearchTabControls)) {
        global SearchTabControls := []
    }
    
    ; 创建标签页面板（默认隐藏）
    SearchTabPanel := ConfigGUI.Add("Text", "x" . X . " y" . Y . " w" . W . " h" . H . " Background" . UI_Colors.Background . " vSearchTabPanel", "")
    SearchTabPanel.Visible := false
    SearchTabControls.Push(SearchTabPanel)
    
    ; 标题
    Title := ConfigGUI.Add("Text", "x" . (X + 30) . " y" . (Y + 20) . " w" . (W - 60) . " h30 c" . UI_Colors.Text, "全域搜索")
    Title.SetFont("s16 Bold", "Segoe UI")
    SearchTabControls.Push(Title)
    
    ; 搜索输入框
    YPos := Y + 70
    LabelSearch := ConfigGUI.Add("Text", "x" . (X + 30) . " y" . YPos . " w200 h25 c" . UI_Colors.Text, "搜索关键词：")
    LabelSearch.SetFont("s11", "Segoe UI")
    SearchTabControls.Push(LabelSearch)
    
    YPos += 30
    ; 根据主题模式设置输入框颜色
    if (!IsSet(ThemeMode) || ThemeMode = "") {
        ThemeMode := "dark"
    }
    if (ThemeMode = "dark") {
        InputBgColor := "2d2d30"
        InputTextColor := "FFFFFF"
    } else {
        InputBgColor := UI_Colors.InputBg
        InputTextColor := UI_Colors.Text
    }
    global SearchHistoryEdit := ConfigGUI.Add("Edit", "x" . (X + 30) . " y" . YPos . " w" . (W - 100) . " h30 vSearchHistoryEdit Background" . InputBgColor . " c" . InputTextColor, "")
    SearchHistoryEdit.SetFont("s11", "Segoe UI")
    SearchHistoryEdit.OnEvent("Change", OnSearchInputChange)
    SearchTabControls.Push(SearchHistoryEdit)
    
    ; 类型过滤按钮
    YPos += 50
    CreateSearchTypeFilters(ConfigGUI, X + 30, YPos, W - 60)
    YPos += 40
    
    ; ListView - 使用新列结构：内容、来源、时间
    ListViewHeight := H - (YPos - Y) - 30
    ListViewTextColor := (ThemeMode = "dark") ? "FFFFFF" : UI_Colors.Text
    ; Report 模式（默认）：第 1 列为图标占位（空标题），勿用 +Icon 控件选项以免切换为大图标视图
    global SearchResultsListView := ConfigGUI.Add("ListView", "x" . (X + 30) . " y" . YPos . " w" . (W - 60) . " h" . ListViewHeight . " vSearchResultsListView Background" . UI_Colors.InputBg . " c" . ListViewTextColor . " -Multi +ReadOnly", ["", "内容", "来源", "时间"])
    SearchResultsListView.SetFont("s10 c" . ListViewTextColor, "Segoe UI")
    SearchResultsListView.OnEvent("DoubleClick", OnSearchResultDoubleClick)
    SearchTabControls.Push(SearchResultsListView)
    
    ; 列宽：第 1 列仅图标（与 ShellIconCache 中 48~64px 图协调）
    SearchResultsListView.ModifyCol(1, 36)
    SearchResultsListView.ModifyCol(2, 380)  ; 内容
    SearchResultsListView.ModifyCol(3, 100)  ; 来源
    SearchResultsListView.ModifyCol(4, 150)  ; 时间
}

; ===================== 创建类型过滤按钮 =====================
CreateSearchTypeFilters(ConfigGUI, X, Y, W) {
    global SearchTypeFilterButtons, SearchCurrentFilterType
    
    SearchTypeFilterButtons := []
    SearchCurrentFilterType := ""  ; 空字符串表示显示所有类型
    
    ; 定义类型按钮
    Types := [
        {Key: "", Name: "全部"},
        {Key: "clipboard", Name: "剪贴板"},
        {Key: "template", Name: "模板"},
        {Key: "config", Name: "配置"},
        {Key: "file", Name: "文件"},
        {Key: "hotkey", Name: "快捷键"},
        {Key: "function", Name: "功能"}
    ]
    
    ButtonWidth := 80
    ButtonHeight := 30
    ButtonSpacing := 10
    CurrentX := X
    
    for Index, Type in Types {
        FilterBtn := ConfigGUI.Add("Button", "x" . CurrentX . " y" . Y . " w" . ButtonWidth . " h" . ButtonHeight . " vSearchFilter" . Type.Key, Type.Name)
        FilterBtn.SetFont("s10", "Segoe UI")
        FilterBtn.OnEvent("Click", CreateSearchFilterHandler(Type.Key))
        SearchTypeFilterButtons.Push(FilterBtn)
        global SearchTabControls
        SearchTabControls.Push(FilterBtn)
        
        CurrentX += ButtonWidth + ButtonSpacing
    }
}

; ===================== 创建过滤按钮事件处理器 =====================
CreateSearchFilterHandler(FilterType) {
    return (*) => OnSearchFilterClick(FilterType)
}

; ===================== 搜索过滤按钮点击事件 =====================
OnSearchFilterClick(FilterType) {
    global SearchCurrentFilterType, SearchResultsCache, SearchHistoryEdit
    
    SearchCurrentFilterType := FilterType
    
    ; 更新按钮样式（高亮当前选中的按钮）
    UpdateSearchFilterButtons(FilterType)
    
    ; 【Bug修复2】确保缓存存在后再刷新显示
    ; 如果缓存为空且搜索框有内容，先执行搜索
    if ((!IsSet(SearchResultsCache) || SearchResultsCache.Count = 0) && SearchHistoryEdit) {
        try {
            Keyword := SearchHistoryEdit.Value
            if (Keyword != "") {
                ; 重新执行搜索
                SearchResultsCache := SearchAllDataSources(Keyword)
            }
        } catch as err {
        }
    }
    
    ; 刷新ListView显示
    if (IsSet(SearchResultsCache) && SearchResultsCache.Count > 0) {
        RefreshSearchResultsListView(SearchResultsCache, FilterType)
    } else {
        ; 即使缓存为空，也刷新ListView（会显示空列表）
        RefreshSearchResultsListView(Map(), FilterType)
    }
}

; ===================== 更新过滤按钮样式 =====================
UpdateSearchFilterButtons(ActiveType) {
    global SearchTypeFilterButtons, UI_Colors, ThemeMode
    
    ; 定义类型按钮映射
    TypeButtonMap := Map(
        "", "全部",
        "clipboard", "剪贴板",
        "template", "模板",
        "config", "配置",
        "file", "文件",
        "hotkey", "快捷键",
        "function", "功能"
    )
    
    for Index, Btn in SearchTypeFilterButtons {
        if (Btn) {
            try {
                ; 根据是否为活动按钮设置不同样式
                BtnText := Btn.Text
                ExpectedText := TypeButtonMap.Has(ActiveType) ? TypeButtonMap[ActiveType] : ""
                
                if (BtnText = ExpectedText) {
                    ; 选中状态
                    Btn.Opt("Background" . UI_Colors.BtnPrimary)
                } else {
                    ; 未选中状态
                    Btn.Opt("Background" . UI_Colors.BtnBg)
                }
            } catch as err {
            }
        }
    }
}

; ===================== 刷新搜索结果ListView =====================
RefreshSearchResultsListView(SearchResults, FilterType := "") {
    global SearchResultsListView, SearchResultsData, SearchHistoryEdit
    
    if (!SearchResultsListView) {
        return
    }
    
    ; 检查控件是否有效
    try {
        ; 尝试访问控件属性来检查是否有效
        _ := SearchResultsListView.Hwnd
    } catch as err {
        ; 控件已被销毁，直接返回
        return
    }
    
    ; 【Bug修复2】如果SearchResults为空且搜索框有内容，自动重新搜索
    if ((!SearchResults || SearchResults.Count = 0) && SearchHistoryEdit) {
        try {
            Keyword := SearchHistoryEdit.Value
            if (Keyword != "") {
                ; 重新执行搜索
                global SearchResultsCache
                SearchResultsCache := SearchAllDataSources(Keyword)
                SearchResults := SearchResultsCache
            }
        } catch as err {
            ; 如果重新搜索失败，继续使用空的SearchResults
        }
    }
    
    ; 【Bug修复1】禁用重绘，减少闪烁
    try {
        SearchResultsListView.Opt("-Redraw")
    } catch as err {
    }
    
    ; 清空列表和数据
    try {
        SearchResultsListView.Delete()
    } catch as err {
        ; 如果删除失败，可能控件已被销毁
        try {
            SearchResultsListView.Opt("+Redraw")
        } catch as err {
        }
        return
    }
    
    try {
        SearchResultsData.Clear()
    } catch as err {
    }
    
    ; 收集所有结果项
    AllItems := []
    
    ; 如果指定了过滤类型，只显示该类型的结果
    if (FilterType != "") {
        if (SearchResults.Has(FilterType)) {
            Group := SearchResults[FilterType]
            for Index, Item in Group.Items {
                AllItems.Push(Item)
            }
        }
    } else {
        ; 显示所有类型的结果，合并到一个数组
        for Key, Group in SearchResults {
            if (IsObject(Group) && Group.HasProp("Items")) {
                for ItemIndex, Item in Group.Items {
                    AllItems.Push(Item)
                }
            }
        }
    }
    
    ; 排序：有关键词时文件类按 FzyScore 降序（与 Everything 重排一致），其余按时间；ListView 仅展示 Top 9
    SearchKeyword := ""
    try {
        if (SearchHistoryEdit)
            SearchKeyword := SearchHistoryEdit.Value
    } catch {
        SearchKeyword := ""
    }
    if (SearchKeyword != "" && AllItems.Length > 0) {
        fileItems := []
        otherItems := []
        for Item in AllItems {
            if (SearchResultItemIsFileLike(Item))
                fileItems.Push(Item)
            else
                otherItems.Push(Item)
        }
        if (fileItems.Length > 0)
            SortSearchResultsByFzy(&fileItems, SearchKeyword)
        if (otherItems.Length > 1)
            BubbleSortSearchItemsByTimestampDesc(&otherItems)
        AllItems := []
        for x in fileItems
            AllItems.Push(x)
        for x in otherItems
            AllItems.Push(x)
    } else if (AllItems.Length > 1) {
        BubbleSortSearchItemsByTimestampDesc(&AllItems)
    }
    DisplayLimit := Min(9, AllItems.Length)
    
    ; 将排序后的结果添加到ListView
    try {
        Loop DisplayLimit {
            AddSearchResultItem(SearchResultsListView, AllItems[A_Index])
        }
        
        ; 自动调整列宽（3列：内容、来源、时间）
        SearchResultsListView.ModifyCol(1, 36)
        SearchResultsListView.ModifyCol(2, "AutoHdr")
        SearchResultsListView.ModifyCol(3, "AutoHdr")
        SearchResultsListView.ModifyCol(4, "AutoHdr")
        
        ; 异步补全系统图标（Top 9）
        UpdateIcons(AllItems, DisplayLimit, SearchResultsListView, "cfg")
    } catch as err {
        ; 如果添加失败，可能控件已被销毁，忽略错误
    }
    
    ; 【Bug修复1】重新启用重绘
    try {
        SearchResultsListView.Opt("+Redraw")
    } catch as err {
    }
}

; ===================== 添加搜索结果项到ListView =====================
AddSearchResultItem(ListView, Item) {
    global SearchResultsListView
    ; 检查ListView是否有效
    if (!ListView) {
        return
    }
    
    try {
        ; 尝试访问控件属性来检查是否有效
        _ := ListView.Hwnd
    } catch as err {
        ; 控件已被销毁，直接返回
        return
    }
    
    try {
        ; 新列结构：内容 | 来源 | 时间（首列图标由 ShellIconCache 异步更新）
        Content := Item.HasProp("Preview") ? Item.Preview : (Item.HasProp("Content") ? Item.Content : Item.Title)
        Source := Item.HasProp("Source") ? Item.Source : (Item.HasProp("DataTypeName") ? Item.DataTypeName : "")
        TimeStr := Item.HasProp("TimeFormatted") ? Item.TimeFormatted : (Item.HasProp("Timestamp") ? Item.Timestamp : "")
        
        ; GuiControl 勿用 = 比较同一控件（v2 下可能不相等）；本函数仅用于搜索 ListView
        iconOpt := ""
        try {
            if (ShellIcon_EnsureImageList(ListView, "cfg"))
                iconOpt := "Icon" . ShellIcon_GetPlaceholderIndex("cfg")
        } catch {
        }
        ; 第 1 列留空仅显示图标，文本从第 2 列开始
        if (iconOpt != "")
            ListView.Add(iconOpt, "", Content, Source, TimeStr)
        else
            ListView.Add("", "", Content, Source, TimeStr)
        
        ; 保存结果项数据到ListView行数据（通过行索引关联）
        RowIndex := ListView.GetCount()
        ; 注意：AutoHotkey v2的ListView不直接支持行数据，需要通过全局Map存储
        global SearchResultsData
        if (!IsSet(SearchResultsData)) {
            global SearchResultsData := Map()
        }
        SearchResultsData[RowIndex] := Item
    } catch as err {
        ; 如果添加失败，可能控件已被销毁，忽略错误
    }
}

; ===================== 搜索输入框变化事件 =====================
OnSearchInputChange(*) {
    global SearchHistoryEdit, SearchResultsCache, SearchDebounceTimer
    
    ; 防抖处理：延迟150ms执行搜索（Everything式即时搜索体验）
    if (SearchDebounceTimer != 0) {
        SetTimer(SearchDebounceTimer, 0)
    }
    
    SearchDebounceTimer := (*) => PerformSearch()
    
    SetTimer(SearchDebounceTimer, -150)  ; 150ms延迟
}

; ===================== 执行搜索 =====================
PerformSearch() {
    global SearchHistoryEdit, SearchResultsCache, SearchCurrentFilterType
    
    ; 检查控件是否有效
    if (!SearchHistoryEdit) {
        return
    }
    
    try {
        ; 尝试访问控件属性来检查是否有效
        _ := SearchHistoryEdit.Hwnd
    } catch as err {
        ; 控件已被销毁，直接返回
        return
    }
    
    try {
        Keyword := SearchHistoryEdit.Value
    } catch as err {
        ; 如果获取值失败，可能控件已被销毁
        return
    }
    
    if (Keyword = "") {
        ; 清空结果
        RefreshSearchResultsListView(Map(), "")
        return
    }
    
    ; 执行搜索（使用 LIMIT 100）
    try {
        SearchResultsCache := SearchAllDataSources(Keyword, [], 100)
        
        ; 刷新ListView（使用当前过滤类型）
        RefreshSearchResultsListView(SearchResultsCache, SearchCurrentFilterType)
    } catch as e {
        ; 如果搜索失败，忽略错误
    }
}

; ===================== 搜索结果ListView双击事件 =====================
OnSearchResultDoubleClick(*) {
    global SearchResultsListView, SearchResultsData
    
    SelectedRow := SearchResultsListView.GetNext()
    if (SelectedRow = 0) {
        return
    }
    
    ; 获取对应的结果项
    if (SearchResultsData.Has(SelectedRow)) {
        Item := SearchResultsData[SelectedRow]
        HandleSearchResultAction(Item)
    }
}

; ===================== 处理搜索结果跳转 =====================
HandleSearchResultAction(Item) {
    global GuiID_ConfigGUI
    
    ; 根据来源类型处理
    Source := Item.HasProp("Source") ? Item.Source : Item.DataType
    
    switch Source {
        case "prompt":
            ; 提示词：切换到提示词标签并加载对应编辑页面
            if (GuiID_ConfigGUI != 0) {
                SwitchTab("prompts")
                ; 查找并加载对应的模板
                TemplateID := Item.HasProp("ID") ? Item.ID : (Item.ActionParams.Has("ID") ? Item.ActionParams["ID"] : "")
                if (TemplateID != "") {
                    global PromptTemplates
                    for Index, Template in PromptTemplates {
                        if (Template.ID = TemplateID) {
                            ; 触发编辑模板事件
                            OnPromptManagerEditFromPreview(0, Template)
                            break
                        }
                    }
                }
            }
            
        case "clipboard":
            ; 剪贴板：复制到剪贴板并关闭面板
            Content := Item.HasProp("Content") ? Item.Content : ""
            if (Content != "") {
                A_Clipboard := Content
                TrayTip("提示", "已复制到剪贴板", "Iconi 1")
                ; 可选：关闭配置面板
                ; if (GuiID_ConfigGUI != 0) {
                ;     GuiID_ConfigGUI.Hide()
                ; }
            }
            
        default:
            ; 其他操作类型
            switch Item.Action {
                case "copy_to_clipboard":
                    ; 复制到剪贴板
                    A_Clipboard := Item.Content
                    TrayTip("提示", "已复制到剪贴板", "Iconi 1")
                    
                case "send_to_cursor":
                    ; 发送模板到Cursor
                    Template := Item.ActionParams["Template"]
                    SendTemplateToCursorWithKey("", Template)
                    
                case "open_prompt":
                    ; 打开提示词编辑
                    TemplateID := Item.ActionParams["ID"]
                    if (GuiID_ConfigGUI != 0) {
                        SwitchTab("prompts")
                        global PromptTemplates
                        for Index, Template in PromptTemplates {
                            if (Template.ID = TemplateID) {
                                OnPromptManagerEditFromPreview(0, Template)
                                break
                            }
                        }
                    }
                    
                case "jump_to_config":
                    ; 跳转到配置标签页
                    TabName := Item.ActionParams["TabName"]
                    Section := Item.ActionParams["Section"]
                    Key := Item.ActionParams["Key"]
                    JumpToConfigItem(TabName, Section, Key)
                    
                case "open_file":
                    ; 打开文件
                    FilePath := Item.ActionParams["FilePath"]
                    try {
                        Run(FilePath)
                    } catch as err {
                        TrayTip("错误", "无法打开文件: " . FilePath, "Iconx 2")
                    }
                    
                case "jump_to_hotkey_config":
                    ; 跳转到快捷键配置
                    FunctionName := Item.ActionParams["Function"]
                    JumpToHotkeyConfig(FunctionName)
                    
                case "execute_function":
                    ; 执行功能
                    FunctionName := Item.ActionParams["FunctionName"]
                    ExecuteFunction(FunctionName)
            }
    }
}

; ===================== 跳转到配置项 =====================
JumpToConfigItem(TabName, Section, Key) {
    global GuiID_ConfigGUI
    
    ; 切换到对应标签页
    SwitchTab(TabName)
    
    ; 高亮对应的配置项（需要根据具体实现）
    ; 这里简化处理，实际需要根据控件名称定位并高亮
    TrayTip("提示", "已跳转到" . TabName . "标签页", "Iconi 1")
}

; ===================== 跳转到快捷键配置 =====================
JumpToHotkeyConfig(FunctionName) {
    ; 切换到快捷键标签页
    SwitchTab("hotkeys")
    
    ; 高亮对应的快捷键配置项
    ; 需要根据具体实现定位控件
    TrayTip("提示", "已跳转到快捷键配置", "Iconi 1")
}

; ===================== 执行功能 =====================
ExecuteFunction(FunctionName) {
    switch FunctionName {
        case "解释代码":
            ; 触发解释功能
            ExecutePrompt("Explain")
        case "重构代码":
            ExecutePrompt("Refactor")
        case "优化代码":
            ExecutePrompt("Optimize")
        case "剪贴板管理":
            ; 打开粘贴板面板
            CP_Show()
        case "模板管理":
            ; 跳转到模板管理标签页
            SwitchTab("prompts")
            ; 切换到管理子标签
            ; SwitchPromptTemplateTab(?)  ; 需要根据实际实现
        default:
            TrayTip("提示", "功能: " . FunctionName, "Iconi 1")
    }
}

; ===================== 设置下拉列表最小可见项数 =====================
SetDDLMinVisible(*) {
    global DefaultStartTabDDL_Hwnd_ForTimer
    try {
        if (DefaultStartTabDDL_Hwnd_ForTimer != 0) {
            ; CB_SETMINVISIBLE = 0x1701, 设置最小可见项数为5
            ; 这样可以确保下拉列表一次性显示5个选项（Windows Vista+）
            ; 使用SendMessage设置
            ; wParam = 5 (最小可见项数), lParam = 0 (未使用)
            DllCall("SendMessage", "Ptr", DefaultStartTabDDL_Hwnd_ForTimer, "UInt", 0x1701, "Ptr", 5, "Ptr", 0, "Int")
            ; 为了确保生效，也尝试使用PostMessage（某些情况下PostMessage更可靠）
            DllCall("PostMessage", "Ptr", DefaultStartTabDDL_Hwnd_ForTimer, "UInt", 0x1701, "Ptr", 5, "Ptr", 0)
        }
    } catch as err {
        ; 如果设置失败，忽略错误（某些系统可能不支持此功能）
    }
}

; ===================== 浏览 Cursor 路径 =====================
BrowseCursorPath(*) {
    global CursorPathEdit
    FilePath := FileSelect(1, , "选择 Cursor.exe", "可执行文件 (*.exe)")
    if (FilePath != "" && CursorPathEdit) {
        CursorPathEdit.Value := FilePath
    }
}

; ===================== 重置为默认值 =====================
ResetToDefaults(*) {
    global CursorPathEdit, AISleepTimeEdit, PromptExplainEdit, PromptRefactorEdit, PromptOptimizeEdit
    global SplitHotkeyEdit, BatchHotkeyEdit, PanelScreenRadio
    global HotkeyESCEdit, HotkeyCEdit, HotkeyVEdit, HotkeyXEdit, HotkeyEEdit, HotkeyREdit, HotkeyOEdit, HotkeyQEdit, HotkeyZEdit
    
    ; 确认对话框
    Result := MsgBox(GetText("confirm_reset"), GetText("confirm"), "YesNo Icon?")
    if (Result != "Yes") {
        return
    }
    
    DefaultCursorPath := "C:\Users\" A_UserName "\AppData\Local\Cursor\Cursor.exe"
    DefaultAISleepTime := 15000
    DefaultPrompt_Explain := GetText("default_prompt_explain")
    DefaultPrompt_Refactor := GetText("default_prompt_refactor")
    DefaultPrompt_Optimize := GetText("default_prompt_optimize")
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
    DefaultPanelScreenIndex := 1
    
    try {
        if (IsSet(CursorPathEdit) && CursorPathEdit) CursorPathEdit.Value := DefaultCursorPath
        if (IsSet(AISleepTimeEdit) && AISleepTimeEdit) AISleepTimeEdit.Value := DefaultAISleepTime
        if (IsSet(PromptExplainEdit) && PromptExplainEdit) PromptExplainEdit.Value := DefaultPrompt_Explain
        if (IsSet(PromptRefactorEdit) && PromptRefactorEdit) PromptRefactorEdit.Value := DefaultPrompt_Refactor
        if (IsSet(PromptOptimizeEdit) && PromptOptimizeEdit) PromptOptimizeEdit.Value := DefaultPrompt_Optimize
        if (IsSet(SplitHotkeyEdit) && SplitHotkeyEdit) SplitHotkeyEdit.Value := DefaultSplitHotkey
        if (IsSet(BatchHotkeyEdit) && BatchHotkeyEdit) BatchHotkeyEdit.Value := DefaultBatchHotkey
        if (IsSet(HotkeyESCEdit) && HotkeyESCEdit) HotkeyESCEdit.Value := DefaultHotkeyESC
        if (IsSet(HotkeyCEdit) && HotkeyCEdit) HotkeyCEdit.Value := DefaultHotkeyC
        if (IsSet(HotkeyVEdit) && HotkeyVEdit) HotkeyVEdit.Value := DefaultHotkeyV
        if (IsSet(HotkeyXEdit) && HotkeyXEdit) HotkeyXEdit.Value := DefaultHotkeyX
        if (IsSet(HotkeyEEdit) && HotkeyEEdit) HotkeyEEdit.Value := DefaultHotkeyE
        if (IsSet(HotkeyREdit) && HotkeyREdit) HotkeyREdit.Value := DefaultHotkeyR
        if (IsSet(HotkeyOEdit) && HotkeyOEdit) HotkeyOEdit.Value := DefaultHotkeyO
        if (IsSet(HotkeyQEdit) && HotkeyQEdit) HotkeyQEdit.Value := DefaultHotkeyQ
        if (IsSet(HotkeyZEdit) && HotkeyZEdit) HotkeyZEdit.Value := DefaultHotkeyZ
        if (IsSet(HotkeyTEdit) && HotkeyTEdit) HotkeyTEdit.Value := "t"
        
        ; 重置屏幕选择
        if (IsSet(PanelScreenRadio) && PanelScreenRadio && PanelScreenRadio.Length > 0) {
            for Index, RadioBtn in PanelScreenRadio {
                if (RadioBtn.HasProp("IsSelected")) {
                    RadioBtn.IsSelected := false
                    UpdateMaterialRadioButtonStyle(RadioBtn, false)
                }
            }
            if (DefaultPanelScreenIndex >= 1 && DefaultPanelScreenIndex <= PanelScreenRadio.Length) {
                PanelScreenRadio[DefaultPanelScreenIndex].IsSelected := true
                UpdateMaterialRadioButtonStyle(PanelScreenRadio[DefaultPanelScreenIndex], true)
            } else if (PanelScreenRadio.Length > 0) {
                PanelScreenRadio[1].IsSelected := true
                UpdateMaterialRadioButtonStyle(PanelScreenRadio[1], true)
            }
        }
    } catch as err {
        ; 忽略控件失效错误
    }
    
    MsgBox(GetText("reset_default_success"), GetText("tip"), "Iconi")
}

; ===================== 安装 Cursor 中文版 =====================
InstallCursorChinese(*) {
    global CursorPath, AISleepTime, GuiID_ConfigGUI
    
    ; 关闭配置面板
    if (GuiID_ConfigGUI != 0) {
        try {
            CloseConfigGUI()
        } catch as err {
            ; 如果关闭失败，直接销毁
            try {
                GuiID_ConfigGUI.Destroy()
                GuiID_ConfigGUI := 0
            }
        }
    }
    
    ; 显示提示信息
    MsgBox(GetText("install_cursor_chinese_guide"), GetText("install_cursor_chinese"), "Iconi")
    
    ; 检查 Cursor 是否运行
    if (!WinExist("ahk_exe Cursor.exe")) {
        if (CursorPath != "" && FileExist(CursorPath)) {
            Run(CursorPath)
            Sleep(AISleepTime * 2)  ; 等待 Cursor 启动
        } else {
            TrayTip(GetText("cursor_not_running_error"), GetText("error"), "Iconx 2")
            return
        }
    }
    
    ; 激活 Cursor 窗口
    try {
        WinActivate("ahk_exe Cursor.exe")
        WinWaitActive("ahk_exe Cursor.exe", , 3)
        Sleep(500)  ; 等待窗口完全激活
        
        ; 确保窗口已激活
        if (!WinActive("ahk_exe Cursor.exe")) {
            WinActivate("ahk_exe Cursor.exe")
            Sleep(300)
        }
        
        ; 步骤 1: 打开命令面板（支持自定义快捷键）
        Sleep(500)
        Send(GetCursorActionShortcut("CommandPalette"))
        Sleep(1000)  ; 等待命令面板打开
        
        ; 步骤 2: 直接粘贴 "Configure Display Language"
        ; 先保存当前剪贴板内容
        OldClipboard := A_Clipboard
        A_Clipboard := "Configure Display Language"
        ClipWait(1)  ; 等待剪贴板就绪
        
        ; 粘贴文本
        Send("^v")  ; Ctrl + V
        Sleep(500)  ; 等待粘贴完成和选项显示
        
        ; 恢复原剪贴板内容
        A_Clipboard := OldClipboard
        
        ; 步骤 3: 按回车确认
        Send("{Enter}")
        
        ; 显示详细的操作提示
        TrayTip(GetText("install_cursor_chinese_complete"), GetText("install_cursor_chinese"), "Iconi 5")
        
    } catch as e {
        TrayTip("安装流程执行失败: " . e.Message, GetText("error"), "Iconx 2")
    }
}

; ===================== UI 常量定义 =====================
; UI颜色已在脚本开头初始化（第104-165行），这里不再重复定义

; 窗口拖动事件
WM_LBUTTONDOWN(*) {
    PostMessage(0xA1, 2)
}

; 自定义按钮悬停效果（基础版本，保持兼容性）
; 注意：Text 控件不支持 MouseEnter/MouseLeave 事件，所以只实现点击效果
HoverBtn(Ctrl, NormalColor, HoverColor) {
    Ctrl.NormalColor := NormalColor
    Ctrl.HoverColor := HoverColor
    
    ; 添加点击效果
    try {
        if (!Ctrl.HasProp("ClickWrapped")) {
            ClickHandler := BindEventForClick(Ctrl)
            Ctrl.OnEvent("Click", ClickHandler)
            Ctrl.ClickWrapped := true
        }
    } catch as err {
        ClickHandler := BindEventForClick(Ctrl)
        Ctrl.OnEvent("Click", ClickHandler)
    }
}

; 辅助函数：绑定点击事件
BindEventForClick(Ctrl) {
    ; 使用闭包捕获变量
    Handler(*) {
        AnimateButtonClick(Ctrl)
    }
    return Handler
}

; 自定义按钮悬停效果（带动效版本）
; 注意：Text 控件不支持 MouseEnter/MouseLeave 事件，所以只实现点击效果
HoverBtnWithAnimation(Ctrl, NormalColor, HoverColor) {
    Ctrl.NormalColor := NormalColor
    Ctrl.HoverColor := HoverColor
    try {
        Ctrl.IsAnimating := false  ; 标记是否正在动画中
    } catch as err {
        ; 如果无法设置属性，忽略
    }
    
    ; 添加点击效果
    try {
        if (!Ctrl.HasProp("ClickWrapped")) {
            ClickHandler := BindEventForClick(Ctrl)
            ; 保存原有的点击事件（如果存在）
            ; 注意：AutoHotkey v2中无法直接获取已有的事件处理器
            ; 所以点击动画会在原有事件之前执行
            Ctrl.OnEvent("Click", ClickHandler)
            Ctrl.ClickWrapped := true
        }
    } catch as err {
        ClickHandler := BindEventForClick(Ctrl)
        Ctrl.OnEvent("Click", ClickHandler)
    }
}


; 按钮悬停动画（平滑过渡）
AnimateButtonHover(Ctrl, NormalColor, HoverColor, IsEntering) {
    ; 如果正在动画中，跳过
    try {
        if (Ctrl.HasProp("IsAnimating") && Ctrl.IsAnimating) {
            return
        }
    } catch as err {
    }
    
    try {
        Ctrl.IsAnimating := true
    } catch as err {
        ; 如果无法设置属性，直接设置颜色
        try {
            if (IsEntering) {
                Ctrl.BackColor := HoverColor
            } else {
                Ctrl.BackColor := NormalColor
            }
        } catch as err {
        }
        return
    }
    
    ; 使用颜色混合实现平滑过渡（5帧动画）
    AnimationSteps := 5
    Loop AnimationSteps {
        Step := A_Index
        Ratio := Step / AnimationSteps
        
        ; 计算中间颜色
        if (IsEntering) {
            CurrentColor := BlendColor(NormalColor, HoverColor, Ratio)
        } else {
            CurrentColor := BlendColor(HoverColor, NormalColor, Ratio)
        }
        
        try {
            Ctrl.BackColor := CurrentColor
        } catch as err {
            ; 忽略错误
        }
        
        Sleep(10)  ; 每帧10ms，总共50ms的动画
    }
    
    ; 设置最终颜色
    try {
        if (IsEntering) {
            Ctrl.BackColor := HoverColor
        } else {
            Ctrl.BackColor := NormalColor
        }
    } catch as err {
    }
    
    try {
        Ctrl.IsAnimating := false
    } catch as err {
    }
}

; 按钮点击动画（按下效果）
AnimateButtonClick(Ctrl) {
    if (!Ctrl.HasProp("HoverColor")) {
        return
    }
    
    try {
        OriginalColor := Ctrl.BackColor
        ClickColor := BlendColor(Ctrl.HoverColor, "000000", 0.3)  ; 变暗30%模拟按下效果
        
        ; 快速变暗（使用定时器避免阻塞）
        Ctrl.BackColor := ClickColor
        ; 使用定时器恢复颜色（通过闭包捕获变量）
        RestoreColorFunc := RestoreButtonColor.Bind(Ctrl, OriginalColor)
        SetTimer(RestoreColorFunc, -50)  ; 50ms后恢复
    } catch as err {
        ; 忽略错误
    }
}

; 恢复按钮颜色的辅助函数
RestoreButtonColor(Ctrl, OriginalColor, *) {
    try {
        Ctrl.BackColor := OriginalColor
    } catch as err {
    }
}

; ===================== 创建Cursor风格的下拉框 =====================
; 创建一个带边框和Cursor风格样式的下拉框
CreateCursorDDL(Parent, X, Y, W, H, Options, VarName := "", ControlList := "") {
    global UI_Colors, ThemeMode
    
    ; 根据主题模式设置下拉框颜色（暗色模式使用cursor黑灰色系）
    if (!IsSet(ThemeMode) || ThemeMode = "") {
        ThemeMode := "dark"
    }
    if (ThemeMode = "dark") {
        DDLBgColor := UI_Colors.DDLBg      ; html.to.design 风格背景
        DDLTextColor := UI_Colors.DDLText   ; html.to.design 风格文本
        DDLBorderColor := UI_Colors.DDLBorder ; html.to.design 风格边框
    } else {
        DDLBgColor := UI_Colors.DDLBg
        DDLTextColor := UI_Colors.DDLText
        DDLBorderColor := UI_Colors.DDLBorder
    }
    
    ; 外边框（浅灰色，模拟Cursor风格）
    DDLBorderOuter := Parent.Add("Text", "x" . X . " y" . Y . " w" . W . " h" . H . " Background" . DDLBorderColor, "")
    if (ControlList != "") {
        ControlList.Push(DDLBorderOuter)
    }
    
    ; 内背景（深灰色，Cursor风格）
    DDLBgRect := Parent.Add("Text", "x" . (X + 1) . " y" . (Y + 1) . " w" . (W - 2) . " h" . (H - 2) . " Background" . DDLBgColor, "")
    if (ControlList != "") {
        ControlList.Push(DDLBgRect)
    }
    
    ; 创建下拉框（内嵌2px以显示边框）
    DDL := Parent.Add("DDL", "x" . (X + 2) . " y" . (Y + 2) . " w" . (W - 4) . " h" . (H - 4) . " v" . VarName . " Background" . DDLBgColor . " c" . DDLTextColor . " " . Options, [])
    DDL.SetFont("s10", "Segoe UI")
    
    ; 添加选项
    if (Type(Options) = "Array") {
        for Index, Option in Options {
            DDL.Add(Option)
        }
    }
    
    return DDL
}

; 全局变量记录当前悬停控件
global LastHoverCtrl := 0
global LastCursorPanelButton := 0  ; 当前鼠标悬停的 Cursor 面板按钮（用于更新说明文字）

; 监听鼠标移动消息实现 Hover
OnMessage(0x0200, WM_MOUSEMOVE)
; 监听右键点击消息（用于截图助手右键菜单）
OnMessage(0x0204, WM_RBUTTONDOWN)
; 托盘图标右键点击通过 A_TrayMenu.Click 处理，在 OnTrayMenuClick 中显示自定义GUI菜单
; 监听WM_CTLCOLORLISTBOX消息以自定义下拉列表背景色
OnMessage(0x0134, WM_CTLCOLORLISTBOX)
; 监听WM_CTLCOLOREDIT消息以自定义ComboBox编辑框背景色
OnMessage(0x0133, WM_CTLCOLOREDIT)
; 监听WM_NOTIFY消息以处理ListView单元格点击（NM_CLICK）
OnMessage(0x004E, OnClipboardListViewWMNotify)
; 监听窗口拖动消息（WM_ENTERSIZEMOVE = 0x0231, WM_EXITSIZEMOVE = 0x0232）
OnMessage(0x0231, WM_ENTERSIZEMOVE)
OnMessage(0x0232, WM_EXITSIZEMOVE)

WM_CTLCOLORLISTBOX(wParam, lParam, Msg, Hwnd) {
    global DefaultStartTabDDL_Hwnd, DDLBrush, UI_Colors, MoveGUIListBoxHwnd, MoveGUIListBoxBrush, MoveFromTemplateListBoxHwnd, MoveFromTemplateListBoxBrush
    global ClipboardListBoxHwnd, ClipboardListBoxBrush, ThemeMode
    global SearchCenterResultLimitDDL_Hwnd, SearchCenterResultLimitDDLBrush
    
    try {
        ; 检查是否是剪贴板管理的ListBox
        if (ClipboardListBoxHwnd != 0 && lParam = ClipboardListBoxHwnd && ClipboardListBoxBrush != 0) {
            ; 根据主题模式设置颜色
            if (ThemeMode = "dark") {
                TextColor := "0x" . UI_Colors.Text
                BgColor := "0x" . UI_Colors.InputBg
                ; 选中项背景色（使用稍微亮一点的颜色）
                SelectedBgColor := "0x" . UI_Colors.BtnPrimary
            } else {
                TextColor := "0x" . UI_Colors.Text
                BgColor := "0x" . UI_Colors.InputBg
                SelectedBgColor := "0x" . UI_Colors.BtnPrimary
            }
            TextRGB := Integer(TextColor)
            BgRGB := Integer(BgColor)
            SelectedBgRGB := Integer(SelectedBgColor)
            ; 转换为BGR格式（交换R和B字节）
            TextBGR := ((TextRGB & 0xFF) << 16) | (TextRGB & 0xFF00) | ((TextRGB & 0xFF0000) >> 16)
            BgBGR := ((BgRGB & 0xFF) << 16) | (BgRGB & 0xFF00) | ((BgRGB & 0xFF0000) >> 16)
            SelectedBgBGR := ((SelectedBgRGB & 0xFF) << 16) | (SelectedBgRGB & 0xFF00) | ((SelectedBgRGB & 0xFF0000) >> 16)
            ; 设置文本颜色
            DllCall("gdi32.dll\SetTextColor", "Ptr", wParam, "UInt", TextBGR)
            ; 设置背景色（未选中项）
            DllCall("gdi32.dll\SetBkColor", "Ptr", wParam, "UInt", BgBGR)
            ; 返回画刷句柄
            return ClipboardListBoxBrush
        }
        
        ; 检查是否是默认启动页面下拉框的列表框
        ; lParam是列表框的句柄，我们需要找到它的父ComboBox
        if (DefaultStartTabDDL_Hwnd != 0 && DDLBrush != 0) {
            ParentHwnd := DllCall("user32.dll\GetParent", "Ptr", lParam, "Ptr")
            if (ParentHwnd = DefaultStartTabDDL_Hwnd) {
                ; 根据主题模式设置下拉列表背景色和文字颜色
                if (ThemeMode = "dark") {
                    ; 暗色模式：html.to.design 风格配色
                    DDLTextColor := "0x" . UI_Colors.DDLText  ; html.to.design 风格文本
                    DDLBgColor := "0x" . UI_Colors.DDLBg      ; html.to.design 风格背景
                } else {
                    ; 亮色模式：使用UI_Colors中的颜色
                    DDLTextColor := "0x" . UI_Colors.DDLText
                    DDLBgColor := "0x" . UI_Colors.DDLBg
                }
                TextRGB := Integer(DDLTextColor)
                BgRGB := Integer(DDLBgColor)
                ; 转换为BGR格式（交换R和B字节）
                TextBGR := ((TextRGB & 0xFF) << 16) | (TextRGB & 0xFF00) | ((TextRGB & 0xFF0000) >> 16)
                BgBGR := ((BgRGB & 0xFF) << 16) | (BgRGB & 0xFF00) | ((BgRGB & 0xFF0000) >> 16)
                ; 设置文本颜色
                DllCall("gdi32.dll\SetTextColor", "Ptr", wParam, "UInt", TextBGR)
                ; 设置背景色
                DllCall("gdi32.dll\SetBkColor", "Ptr", wParam, "UInt", BgBGR)
                ; 返回画刷句柄
                return DDLBrush
            }
        }

        if (SearchCenterResultLimitDDL_ListHwnd != 0 && lParam = SearchCenterResultLimitDDL_ListHwnd && SearchCenterResultLimitDDLBrush != 0) {
            TextBGR := 0x000000
            BgBGR := 0xFFFFFF
            DllCall("gdi32.dll\SetTextColor", "Ptr", wParam, "UInt", TextBGR)
            DllCall("gdi32.dll\SetBkColor", "Ptr", wParam, "UInt", BgBGR)
            return SearchCenterResultLimitDDLBrush
        }
        
        ; 检查是否是移动分类弹窗的ListBox
        if (MoveGUIListBoxHwnd != 0 && lParam = MoveGUIListBoxHwnd && MoveGUIListBoxBrush != 0) {
            TextColor := "0x" . UI_Colors.Text
            BgColor := "0x" . UI_Colors.InputBg
            TextRGB := Integer(TextColor)
            BgRGB := Integer(BgColor)
            TextBGR := ((TextRGB & 0xFF) << 16) | (TextRGB & 0xFF00) | ((TextRGB & 0xFF0000) >> 16)
            BgBGR := ((BgRGB & 0xFF) << 16) | (BgRGB & 0xFF00) | ((BgRGB & 0xFF0000) >> 16)
            DllCall("gdi32.dll\SetTextColor", "Ptr", wParam, "UInt", TextBGR)
            DllCall("gdi32.dll\SetBkColor", "Ptr", wParam, "UInt", BgBGR)
            return MoveGUIListBoxBrush
        }
        
        ; 检查是否是从模板移动弹窗的ListBox
        if (MoveFromTemplateListBoxHwnd != 0 && lParam = MoveFromTemplateListBoxHwnd && MoveFromTemplateListBoxBrush != 0) {
            TextColor := "0x" . UI_Colors.Text
            BgColor := "0x" . UI_Colors.InputBg
            TextRGB := Integer(TextColor)
            BgRGB := Integer(BgColor)
            TextBGR := ((TextRGB & 0xFF) << 16) | (TextRGB & 0xFF00) | ((TextRGB & 0xFF0000) >> 16)
            BgBGR := ((BgRGB & 0xFF) << 16) | (BgRGB & 0xFF00) | ((BgRGB & 0xFF0000) >> 16)
            DllCall("gdi32.dll\SetTextColor", "Ptr", wParam, "UInt", TextBGR)
            DllCall("gdi32.dll\SetBkColor", "Ptr", wParam, "UInt", BgBGR)
            return MoveFromTemplateListBoxBrush
        }
    } catch as err {
    }
    
    ; 如果不是我们的下拉框，返回0让系统使用默认处理
    return 0
}

; 处理ComboBox编辑框部分的背景色和文字颜色
WM_CTLCOLOREDIT(wParam, lParam, Msg, Hwnd) {
    global DefaultStartTabDDL_Hwnd, DDLBrush, UI_Colors, ThemeMode
    global SearchCenterResultLimitDDL_Hwnd, SearchCenterResultLimitDDLBrush
    
    try {
        ; 检查是否是默认启动页面下拉框的编辑框部分
        ; lParam是编辑框的句柄，我们需要找到它的父ComboBox
        if (DefaultStartTabDDL_Hwnd != 0 && DDLBrush != 0) {
            ParentHwnd := DllCall("user32.dll\GetParent", "Ptr", lParam, "Ptr")
            if (ParentHwnd = DefaultStartTabDDL_Hwnd) {
                ; 根据主题模式设置颜色
                if (ThemeMode = "dark") {
                    ; 暗色模式：html.to.design 风格配色
                    DDLTextColor := "0x" . UI_Colors.DDLText  ; html.to.design 风格文本
                    DDLBgColor := "0x" . UI_Colors.DDLBg      ; html.to.design 风格背景
                } else {
                    ; 亮色模式：使用UI_Colors中的颜色
                    DDLTextColor := "0x" . UI_Colors.DDLText
                    DDLBgColor := "0x" . UI_Colors.DDLBg
                }
                TextRGB := Integer(DDLTextColor)
                BgRGB := Integer(DDLBgColor)
                ; 转换为BGR格式（交换R和B字节）
                TextBGR := ((TextRGB & 0xFF) << 16) | (TextRGB & 0xFF00) | ((TextRGB & 0xFF0000) >> 16)
                BgBGR := ((BgRGB & 0xFF) << 16) | (BgRGB & 0xFF00) | ((BgRGB & 0xFF0000) >> 16)
                ; 设置文本颜色
                DllCall("gdi32.dll\SetTextColor", "Ptr", wParam, "UInt", TextBGR)
                ; 设置背景色
                DllCall("gdi32.dll\SetBkColor", "Ptr", wParam, "UInt", BgBGR)
                ; 返回画刷句柄
                return DDLBrush
            }
        }

        if (SearchCenterResultLimitDDL_Hwnd != 0 && SearchCenterResultLimitDDLBrush != 0) {
            ParentHwnd := DllCall("user32.dll\GetParent", "Ptr", lParam, "Ptr")
            if (ParentHwnd = SearchCenterResultLimitDDL_Hwnd) {
                DllCall("gdi32.dll\SetTextColor", "Ptr", wParam, "UInt", 0x000000)
                DllCall("gdi32.dll\SetBkColor", "Ptr", wParam, "UInt", 0xFFFFFF)
                return SearchCenterResultLimitDDLBrush
            }
        }
    } catch as err {
    }
    
    ; 如果不是我们的下拉框，返回0让系统使用默认处理
    return 0
}

; ===================== 窗口拖动消息处理（防止拖动时组件闪烁）====================
WM_ENTERSIZEMOVE(wParam, lParam, Msg, Hwnd) {
    global WindowDragging, GuiID_ConfigGUI, GuiID_CursorPanel, GuiID_ClipboardManager
    global GuiID_VoiceInputPanel, GuiID_ScreenshotButton, GuiID_ScreenshotEditor, GuiID_ScreenshotToolbar
    
    ; 检查是否是我们的窗口
    IsOurWindow := false
    IsScreenshotEditor := false
    try {
        if (GuiID_ConfigGUI != 0 && Hwnd = GuiID_ConfigGUI.Hwnd) {
            IsOurWindow := true
        } else if (GuiID_CursorPanel != 0 && Hwnd = GuiID_CursorPanel.Hwnd) {
            IsOurWindow := true
        } else if (GuiID_ClipboardManager != 0 && Hwnd = GuiID_ClipboardManager.Hwnd) {
            IsOurWindow := true
        } else if (GuiID_VoiceInputPanel != 0 && Hwnd = GuiID_VoiceInputPanel.Hwnd) {
            IsOurWindow := true
        } else if (GuiID_ScreenshotButton != 0 && Hwnd = GuiID_ScreenshotButton.Hwnd) {
            IsOurWindow := true
        } else if (GuiID_ScreenshotEditor != 0 && Hwnd = GuiID_ScreenshotEditor.Hwnd) {
            IsOurWindow := true
            IsScreenshotEditor := true
        }
    } catch as err {
    }
    
    if (!IsOurWindow) {
        return
    }
    
    ; 如果是截图助手窗口开始拖动，启动工具栏同步移动定时器
    if (IsScreenshotEditor && GuiID_ScreenshotToolbar != 0) {
        SetTimer(SyncScreenshotToolbarPosition, 10)  ; 每10ms同步一次位置
    }
    
    ; 标记窗口正在拖动
    WindowDragging := true
    
    ; 暂停所有可能引起闪烁的定时器
    try {
        ; 暂停面板边缘检测定时器
        SetTimer(CheckCursorPanelEdge, 0)
        DraggingTimers["CheckCursorPanelEdge"] := true
        
        ; 暂停剪贴板列表刷新定时器
        SetTimer(RefreshClipboardListDelayed, 0)
        DraggingTimers["RefreshClipboardListDelayed"] := true
        
        ; 暂停提示词列表刷新定时器
        SetTimer(RefreshPromptListView, 0)
        DraggingTimers["RefreshPromptListView"] := true
        
        ; 暂停搜索引擎按钮刷新定时器
        SetTimer(() => RefreshSearchEngineButtons(), 0)
        DraggingTimers["RefreshSearchEngineButtons"] := true
    } catch as err {
    }
    
    ; 禁用ListView重绘（如果存在）
    try {
        global PromptManagerListView, ClipboardListViewHwnd
        if (PromptManagerListView) {
            ; 使用LockWindowUpdate来锁定窗口更新
            DllCall("user32.dll\LockWindowUpdate", "Ptr", PromptManagerListView.Hwnd)
        }
        if (ClipboardListViewHwnd) {
            DllCall("user32.dll\LockWindowUpdate", "Ptr", ClipboardListViewHwnd)
        }
    } catch as err {
    }
}

WM_EXITSIZEMOVE(wParam, lParam, Msg, Hwnd) {
    global WindowDragging, GuiID_ConfigGUI, GuiID_CursorPanel, GuiID_ClipboardManager
    global GuiID_VoiceInputPanel, GuiID_ScreenshotButton, CursorPanelAutoHide
    global GuiID_ScreenshotEditor, GuiID_ScreenshotToolbar
    
    ; 检查是否是我们的窗口
    IsOurWindow := false
    IsScreenshotEditor := false
    try {
        if (GuiID_ConfigGUI != 0 && Hwnd = GuiID_ConfigGUI.Hwnd) {
            IsOurWindow := true
        } else if (GuiID_CursorPanel != 0 && Hwnd = GuiID_CursorPanel.Hwnd) {
            IsOurWindow := true
        } else if (GuiID_ClipboardManager != 0 && Hwnd = GuiID_ClipboardManager.Hwnd) {
            IsOurWindow := true
        } else if (GuiID_VoiceInputPanel != 0 && Hwnd = GuiID_VoiceInputPanel.Hwnd) {
            IsOurWindow := true
        } else if (GuiID_ScreenshotButton != 0 && Hwnd = GuiID_ScreenshotButton.Hwnd) {
            IsOurWindow := true
        } else if (GuiID_ScreenshotEditor != 0 && Hwnd = GuiID_ScreenshotEditor.Hwnd) {
            IsOurWindow := true
            IsScreenshotEditor := true
        }
    } catch as err {
    }
    
    if (!IsOurWindow) {
        return
    }
    
    ; 如果是截图助手窗口结束拖动，停止工具栏同步移动定时器
    if (IsScreenshotEditor) {
        SetTimer(SyncScreenshotToolbarPosition, 0)  ; 停止定时器
    }
    
    ; 标记窗口拖动结束
    WindowDragging := false
    
    ; 恢复窗口更新锁定
    try {
        DllCall("user32.dll\LockWindowUpdate", "Ptr", 0)
    } catch as err {
    }
    
    ; 恢复所有定时器
    try {
        ; 恢复面板边缘检测定时器（如果启用）
        if (CursorPanelAutoHide && DraggingTimers.Has("CheckCursorPanelEdge")) {
            SetTimer(CheckCursorPanelEdge, 500)
            DraggingTimers.Delete("CheckCursorPanelEdge")
        }
        
        ; 其他定时器在需要时会自动恢复，不需要在这里恢复
        ; 因为它们通常是延迟执行的（-100, -300等），不会持续运行
        DraggingTimers.Clear()
    } catch as err {
    }
    
    ; 强制刷新ListView（如果需要）
    try {
        global PromptManagerListView, ClipboardListViewHwnd
        if (PromptManagerListView) {
            PromptManagerListView.Redraw()
        }
        if (ClipboardListViewHwnd) {
            DllCall("user32.dll\InvalidateRect", "Ptr", ClipboardListViewHwnd, "Ptr", 0, "Int", 1)
            DllCall("user32.dll\UpdateWindow", "Ptr", ClipboardListViewHwnd)
        }
    } catch as err {
    }
    
    ; 【关键优化】如果是配置面板，在拖动结束后执行完整的布局更新
    try {
        global GuiID_ConfigGUI
        if (GuiID_ConfigGUI != 0 && Hwnd = GuiID_ConfigGUI.Hwnd) {
            ; 获取当前窗口大小并触发完整的布局更新
            WinGetPos(, , &WinWidth, &WinHeight, GuiID_ConfigGUI.Hwnd)
            ; 延迟执行，确保窗口位置已稳定
            SetTimer(() => UpdateConfigGUILayoutAfterDrag(WinWidth, WinHeight), -50)
        }
    } catch as err {
    }
}

; ===================== 拖动结束后更新配置面板布局 =====================
UpdateConfigGUILayoutAfterDrag(Width, Height) {
    global GuiID_ConfigGUI, SidebarWidth
    
    if (GuiID_ConfigGUI = 0) {
        return
    }
    
    try {
        ; 锁定窗口更新，防止闪烁
        DllCall("user32.dll\LockWindowUpdate", "Ptr", GuiID_ConfigGUI.Hwnd)
        
        ; 使用原生标题栏，不需要更新自定义标题栏
        
        ; 更新侧边栏高度
        try {
            SidebarBg := GuiID_ConfigGUI["SidebarBg"]
            if (SidebarBg) {
                SidebarBg.Move(, , , Height)
            }
        } catch as err {
        }
        
        ; 更新内容区域大小（使用原生标题栏，内容从顶部开始）
        ContentX := SidebarWidth
        ContentWidth := Width - SidebarWidth
        ContentY := 0
        ContentHeight := Height - 50
        
        ; 更新各个标签页的内容区域大小
        TabPanels := ["GeneralTabPanel", "AppearanceTabPanel", "PromptsTabPanel", "HotkeysTabPanel", "AdvancedTabPanel"]
        for Index, PanelName in TabPanels {
            try {
                TabPanel := GuiID_ConfigGUI[PanelName]
                if (TabPanel) {
                    TabPanel.Move(ContentX, ContentY, ContentWidth, ContentHeight)
                }
            } catch as err {
            }
        }
        
        ; 更新底部按钮位置
        try {
            ButtonAreaY := Height - 70
            BtnWidth := 80
            BtnSpacing := 10
            BtnStartX := Width - (BtnWidth * 2 + BtnSpacing) - 20
            
            SaveBtn := GuiID_ConfigGUI["SaveBtn"]
            if (SaveBtn) {
                SaveBtn.Move(BtnStartX, ButtonAreaY + 10)
            }
            CancelBtn := GuiID_ConfigGUI["CancelBtn"]
            if (CancelBtn) {
                CancelBtn.Move(BtnStartX + BtnWidth + BtnSpacing, ButtonAreaY + 10)
            }
        } catch as err {
        }
        
        ; 保存窗口大小（使用延迟保存）
        try {
            WinGetPos(&WinX, &WinY, , , GuiID_ConfigGUI.Hwnd)
            WindowName := GetText("config_title")
            QueueWindowPositionSave(WindowName, WinX, WinY, Width, Height)
        } catch as err {
        }
        
        ; 解锁窗口更新
        DllCall("user32.dll\LockWindowUpdate", "Ptr", 0)
        
        ; 强制刷新窗口
        WinRedraw(GuiID_ConfigGUI.Hwnd)
    } catch as err {
        ; 确保解锁窗口更新
        try {
            DllCall("user32.dll\LockWindowUpdate", "Ptr", 0)
        } catch as err {
        }
    }
}

WM_MOUSEMOVE(wParam, lParam, Msg, Hwnd) {
    global LastHoverCtrl, GuiID_CursorPanel, LastCursorPanelButton, GuiID_ClipboardSmartMenu, ClipboardMenuSelectedIndex
    
    try {
        ; 获取鼠标下的控件
        MouseCtrl := GuiCtrlFromHwnd(Hwnd)
        
        ; 检查是否是 smart 菜单的按钮
        if (MouseCtrl && GuiID_ClipboardSmartMenu != 0) {
            try {
                ; 检查控件是否属于 smart 菜单
                CtrlGui := MouseCtrl.Gui
                if (CtrlGui = GuiID_ClipboardSmartMenu && MouseCtrl.HasProp("IsMenuButton")) {
                    ; 这是菜单按钮，处理悬停效果
                    if (LastHoverCtrl != MouseCtrl) {
                        ; 恢复上一个按钮的颜色
                        if (LastHoverCtrl && LastHoverCtrl.HasProp("IsMenuButton")) {
                            try {
                                if (LastHoverCtrl.HasProp("ButtonIndex") && LastHoverCtrl.ButtonIndex = ClipboardMenuSelectedIndex) {
                                    ; 上一个按钮是选中的，恢复选中背景色
                                    LastHoverCtrl.BackColor := LastHoverCtrl.SelectedBg
                                } else {
                                    ; 上一个按钮未选中，恢复正常背景色
                                    LastHoverCtrl.BackColor := LastHoverCtrl.NormalColor
                                }
                            } catch as err {
                                ; 忽略错误
                            }
                        }
                        
                        ; 设置当前按钮的悬停颜色
                        try {
                            if (MouseCtrl.HasProp("ButtonIndex") && MouseCtrl.ButtonIndex = ClipboardMenuSelectedIndex) {
                                ; 当前按钮是选中的，使用选中+悬停背景色
                                MouseCtrl.BackColor := MouseCtrl.SelectedHoverBg
                            } else {
                                ; 当前按钮未选中，使用悬停背景色
                                MouseCtrl.BackColor := MouseCtrl.HoverColor
                            }
                        } catch as err {
                            ; 忽略错误
                        }
                        
                        LastHoverCtrl := MouseCtrl
                    }
                    return  ; 已处理，不需要继续
                }
            } catch as err {
                ; 忽略错误
            }
        }
        
        ; 检查是否是 Cursor 快捷操作面板的按钮（用于更新说明文字）
        if (MouseCtrl && GuiID_CursorPanel != 0) {
            try {
                ; 检查控件是否属于 Cursor 面板
                CtrlGui := MouseCtrl.Gui
                if (CtrlGui = GuiID_CursorPanel) {
                    ; 检查是否是按钮且具有 ButtonDesc 属性
                    if (MouseCtrl.HasProp("ButtonDesc")) {
                        if (LastCursorPanelButton != MouseCtrl) {
                            ; 更新说明文字
                            UpdateCursorPanelDesc(MouseCtrl.ButtonDesc)
                            LastCursorPanelButton := MouseCtrl
                        }
                    } else if (LastCursorPanelButton) {
                        ; 鼠标移到了面板上的其他控件，恢复默认说明
                        RestoreDefaultCursorPanelDesc()
                        LastCursorPanelButton := 0
                    }
                }
            } catch as err {
                ; 忽略错误
            }
        }
        
        ; 如果是新控件且具有 Hover 属性（但不是菜单按钮）
        if (MouseCtrl && MouseCtrl.HasProp("HoverColor") && !MouseCtrl.HasProp("IsMenuButton")) {
            if (LastHoverCtrl != MouseCtrl) {
                ; 恢复上一个控件颜色（带动效）
                if (LastHoverCtrl && LastHoverCtrl.HasProp("NormalColor")) {
                    try {
                        ; 检查是否正在动画中
                        IsAnimating := false
                        try {
                            if (LastHoverCtrl.HasProp("IsAnimating")) {
                                IsAnimating := LastHoverCtrl.IsAnimating
                            }
                        } catch as err {
                        }
                        
                        if (IsAnimating) {
                            ; 如果正在动画中，直接设置最终颜色
                            LastHoverCtrl.BackColor := LastHoverCtrl.NormalColor
                            try {
                                LastHoverCtrl.IsAnimating := false
                            } catch as err {
                            }
                        } else {
                            ; 使用动画过渡
                            AnimateButtonHover(LastHoverCtrl, LastHoverCtrl.NormalColor, LastHoverCtrl.HoverColor, false)
                        }
                    } catch as err {
                        try LastHoverCtrl.BackColor := LastHoverCtrl.NormalColor
                    }
                }
                
                ; 设置新控件颜色（带动效）
                try {
                    IsAnimating := false
                    try {
                        if (MouseCtrl.HasProp("IsAnimating")) {
                            IsAnimating := MouseCtrl.IsAnimating
                        }
                    } catch as err {
                    }
                    
                    if (!IsAnimating) {
                        AnimateButtonHover(MouseCtrl, MouseCtrl.NormalColor, MouseCtrl.HoverColor, true)
                    }
                } catch as err {
                    try MouseCtrl.BackColor := MouseCtrl.HoverColor
                }
                LastHoverCtrl := MouseCtrl
                
                ; 启动定时器检测鼠标离开
                SetTimer CheckMouseLeave, 50
            }
        }
    }
}

WM_RBUTTONDOWN(wParam, lParam, Msg, Hwnd) {
    global GuiID_ScreenshotEditor, ScreenshotEditorPreviewPic
    
    try {
        ; 获取鼠标下的控件
        MouseCtrl := GuiCtrlFromHwnd(Hwnd)
        
        ; 检查是否是截图助手的图片控件
        if (MouseCtrl && GuiID_ScreenshotEditor != 0) {
            try {
                CtrlGui := MouseCtrl.Gui
                if (CtrlGui = GuiID_ScreenshotEditor && MouseCtrl = ScreenshotEditorPreviewPic) {
                    ; 显示右键菜单
                    OnScreenshotEditorContextMenu(MouseCtrl, 0)
                    return  ; 已处理，阻止默认右键菜单
                }
            } catch as err {
                ; 忽略错误
            }
        }
    } catch as err {
        ; 忽略错误
    }
}


CheckMouseLeave() {
    global LastHoverCtrl, LastCursorPanelButton, GuiID_CursorPanel, GuiID_ClipboardSmartMenu, ClipboardMenuSelectedIndex
    
    ; 检查 smart 菜单按钮的鼠标离开
    if (LastHoverCtrl && LastHoverCtrl.HasProp("IsMenuButton") && GuiID_ClipboardSmartMenu != 0) {
        try {
            MouseGetPos ,,, &MouseHwnd, 2
            ; 如果鼠标不在按钮上，恢复按钮颜色
            if (MouseHwnd != LastHoverCtrl.Hwnd) {
                ; 检查鼠标是否还在菜单窗口上
                try {
                    MenuHwnd := GuiID_ClipboardSmartMenu.Hwnd
                    MouseGetPos(, , , &MouseWinHwnd, 2)
                    if (MouseWinHwnd != MenuHwnd) {
                        ; 鼠标离开了菜单窗口，恢复按钮颜色
                        if (LastHoverCtrl.HasProp("ButtonIndex") && LastHoverCtrl.ButtonIndex = ClipboardMenuSelectedIndex) {
                            LastHoverCtrl.BackColor := LastHoverCtrl.SelectedBg
                        } else {
                            LastHoverCtrl.BackColor := LastHoverCtrl.NormalColor
                        }
                        LastHoverCtrl := 0
                    }
                } catch as err {
                    ; 如果菜单已关闭，清除引用
                    if (GuiID_ClipboardSmartMenu = 0) {
                        LastHoverCtrl := 0
                    }
                }
            }
        } catch as err {
            ; 忽略错误
        }
    }
    
    ; 检查 Cursor 面板按钮的鼠标离开
    if (LastCursorPanelButton) {
        try {
            MouseGetPos ,,, &MouseHwnd, 2
            ; 如果鼠标不在按钮上，恢复默认说明
            if (MouseHwnd != LastCursorPanelButton.Hwnd) {
                ; 检查鼠标是否还在面板上
                if (GuiID_CursorPanel != 0) {
                    try {
                        PanelHwnd := GuiID_CursorPanel.Hwnd
                        WinGetPos ,,, &PanelW, &PanelH, "ahk_id " . PanelHwnd
                        MouseGetPos &MouseX, &MouseY
                        WinGetPos &PanelX, &PanelY,,, "ahk_id " . PanelHwnd
                        
                        ; 如果鼠标不在面板范围内，恢复默认说明
                        if (MouseX < PanelX || MouseX > PanelX + PanelW || MouseY < PanelY || MouseY > PanelY + PanelH) {
                            RestoreDefaultCursorPanelDesc()
                            LastCursorPanelButton := 0
                        }
                    } catch as err {
                        ; 如果出错，恢复默认说明
                        RestoreDefaultCursorPanelDesc()
                        LastCursorPanelButton := 0
                    }
                } else {
                    RestoreDefaultCursorPanelDesc()
                    LastCursorPanelButton := 0
                }
            }
        } catch as err {
            ; 忽略错误
        }
    }
    
    if (!LastHoverCtrl) {
        SetTimer , 0
        return
    }
    
    try {
        MouseGetPos ,,, &MouseHwnd, 2
        
        ; 如果鼠标不在当前控件上
        if (MouseHwnd != LastHoverCtrl.Hwnd) {
            if (LastHoverCtrl.HasProp("NormalColor")) {
                try {
                    ; 检查是否正在动画中
                    IsAnimating := false
                    try {
                        if (LastHoverCtrl.HasProp("IsAnimating")) {
                            IsAnimating := LastHoverCtrl.IsAnimating
                        }
                    } catch as err {
                    }
                    
                    ; 使用动画过渡恢复颜色
                    if (!IsAnimating) {
                        AnimateButtonHover(LastHoverCtrl, LastHoverCtrl.NormalColor, LastHoverCtrl.HoverColor, false)
                    } else {
                        LastHoverCtrl.BackColor := LastHoverCtrl.NormalColor
                        try {
                            LastHoverCtrl.IsAnimating := false
                        } catch as err {
                        }
                    }
                } catch as err {
                    try LastHoverCtrl.BackColor := LastHoverCtrl.NormalColor
                }
            }
            LastHoverCtrl := 0
            SetTimer , 0
        }
    } catch as err {
        ; 出错时清理
        LastHoverCtrl := 0
        SetTimer , 0
    }
}

; ===================== 显示使用说明 =====================
ShowHelp(*) {
    HelpText := "
    (
    ════════════════════════════════════════════════════
    Cursor助手 - 使用说明
    ════════════════════════════════════════════════════

    【核心功能】
    1. 长按 CapsLock 键 → 弹出快捷操作面板
    2. 短按 CapsLock 键 → 正常切换大小写（不影响原有功能）

    【快捷操作】
    • 在 Cursor 中选中代码后，长按 CapsLock 调出面板：
      - 按 E 键：解释代码（快速理解代码逻辑）
      - 按 R 键：重构代码（规范化、添加注释）
      - 按 O 键：优化代码（性能分析和优化建议）
      - 按 S 键：分割代码（插入分割标记）
      - 按 B 键：批量操作（批量解释/重构/优化）
      - 按 ESC：关闭面板

    【使用流程】
    1. 在 Cursor 中选中要处理的代码
    2. 长按 CapsLock 调出面板
    3. 按对应快捷键（E/R/O）执行操作
    4. AI 会自动将提示词和代码发送到 Cursor

    【配置说明】
    • Cursor 路径：如果 Cursor 安装在非默认位置，请手动选择
    • AI 响应等待时间：根据电脑性能调整（低配机建议 20000ms）
    • 提示词：可以自定义每个操作的 AI 提示词
    • 快捷键：可以自定义分割和批量操作的快捷键

    【注意事项】
    • 使用前请确保 Cursor 已安装并可以正常运行
    • 建议先选中代码再调出面板，这样 AI 会自动包含代码
    • 如果 Cursor 未运行，脚本会自动尝试启动

    ════════════════════════════════════════════════════
    )"
    MsgBox(HelpText, GetText("help_title"), "Iconi")
}

; ===================== 配置面板函数 =====================
; ===================== 设置窗口最小尺寸限制辅助函数 =====================
SetWindowMinSizeLimit(Hwnd, MinWidth, MinHeight) {
    ; 使用窗口属性存储最小尺寸，供 ConfigGUI_Size 使用
    ; 这样可以在事件处理函数中访问这些值
    DllCall("user32.dll\SetProp", "Ptr", Hwnd, "Str", "MinWidth", "Int", MinWidth, "Ptr")
    DllCall("user32.dll\SetProp", "Ptr", Hwnd, "Str", "MinHeight", "Int", MinHeight, "Ptr")
}

; ===================== 设置窗口滚动信息辅助函数 =====================
SetWindowScrollInfo(Hwnd, ScrollWidth, ScrollHeight, VisibleWidth, VisibleHeight) {
    ; 设置窗口的滚动区域，启用滚动条
    ; ScrollWidth: 滚动区域的总宽度
    ; ScrollHeight: 滚动区域的总高度
    ; VisibleWidth: 可视区域的宽度
    ; VisibleHeight: 可视区域的高度
    
    ; 使用 SetScrollInfo 设置滚动条信息
    ScrollInfo := Buffer(A_PtrSize = 8 ? 32 : 28, 0)
    
    ; 水平滚动条（如果需要）
    if (ScrollWidth > VisibleWidth) {
        NumPut("UInt", A_PtrSize = 8 ? 32 : 28, ScrollInfo, 0)  ; cbSize
        NumPut("UInt", 0x17, ScrollInfo, 4)  ; fMask = SIF_RANGE | SIF_PAGE | SIF_DISABLENOSCROLL
        NumPut("Int", 0, ScrollInfo, 8)  ; nMin
        NumPut("Int", ScrollWidth, ScrollInfo, 12)  ; nMax
        NumPut("Int", VisibleWidth, ScrollInfo, 16)  ; nPage (可视宽度)
        DllCall("user32.dll\SetScrollInfo", "Ptr", Hwnd, "Int", 0, "Ptr", ScrollInfo, "Int", 1)  ; SB_HORZ = 0
    }
    
    ; 垂直滚动条
    if (ScrollHeight > VisibleHeight) {
        NumPut("UInt", A_PtrSize = 8 ? 32 : 28, ScrollInfo, 0)  ; cbSize
        NumPut("UInt", 0x17, ScrollInfo, 4)  ; fMask = SIF_RANGE | SIF_PAGE | SIF_DISABLENOSCROLL
        NumPut("Int", 0, ScrollInfo, 8)  ; nMin
        NumPut("Int", ScrollHeight, ScrollInfo, 12)  ; nMax
        NumPut("Int", VisibleHeight, ScrollInfo, 16)  ; nPage (可视高度)
        DllCall("user32.dll\SetScrollInfo", "Ptr", Hwnd, "Int", 1, "Ptr", ScrollInfo, "Int", 1)  ; SB_VERT = 1
    }
    
    ; 存储滚动信息到窗口属性，供滚动消息处理使用
    DllCall("user32.dll\SetProp", "Ptr", Hwnd, "Str", "ScrollWidth", "Int", ScrollWidth, "Ptr")
    DllCall("user32.dll\SetProp", "Ptr", Hwnd, "Str", "ScrollHeight", "Int", ScrollHeight, "Ptr")
    DllCall("user32.dll\SetProp", "Ptr", Hwnd, "Str", "VisibleWidth", "Int", VisibleWidth, "Ptr")
    DllCall("user32.dll\SetProp", "Ptr", Hwnd, "Str", "VisibleHeight", "Int", VisibleHeight, "Ptr")
    DllCall("user32.dll\SetProp", "Ptr", Hwnd, "Str", "ScrollX", "Int", 0, "Ptr")
    DllCall("user32.dll\SetProp", "Ptr", Hwnd, "Str", "ScrollY", "Int", 0, "Ptr")
}

; ===================== 配置面板函数 =====================
; 旧版 ListView 剪贴板：先 Hide，失败再 Destroy
SafeHideLegacyClipboardManager(*) {
    global GuiID_ClipboardManager
    if (GuiID_ClipboardManager = 0)
        return
    try {
        GuiID_ClipboardManager.Hide()
    } catch as e {
        try GuiID_ClipboardManager.Destroy()
        catch as e2 {
        }
        GuiID_ClipboardManager := 0
    }
}

; 打开设置前收起剪贴板（WebView + 旧版 ListView），以 Hide 为主、避免无谓 Destroy
HideClipboardPanelsForConfigConflict(*) {
    try CP_Hide()
    catch as e {
    }
    SafeHideLegacyClipboardManager()
}

LegacyConfigGui_Show() {
    global CursorPath, AISleepTime, Prompt_Explain, Prompt_Refactor, Prompt_Optimize
    global SplitHotkey, BatchHotkey, ConfigFile, Language
    global PanelScreenIndex, PanelPosition, ConfigPanelScreenIndex
    global UI_Colors, GuiID_ConfigGUI, GuiID_ClipboardManager, ConfigWebViewMode

    ; 单例模式:如果配置面板已存在,直接激活
    if (GuiID_ConfigGUI != 0 && !ConfigWebViewMode) {
        try {
            WinActivate(GuiID_ConfigGUI.Hwnd)
            return
        } catch as err {
            ; 如果窗口已被销毁,继续创建新的
            GuiID_ConfigGUI := 0
        }
    }
    
    HideClipboardPanelsForConfigConflict()

    ; 清空全局控件数组，防止残留
    global GeneralTabControls := []
    global AppearanceTabControls := []
    global PromptsTabControls := []
    global HotkeysTabControls := []
    global AdvancedTabControls := []
    global GeneralSubTabs := Map()
    global GeneralSubTabControls := Map()
    
    ; 创建配置 GUI（使用原生标题栏）
    ConfigGUI := Gui("+Resize +MinimizeBox +MaximizeBox", GetText("config_title"))
    ConfigGUI.SetFont("s10 c" . UI_Colors.Text, "Segoe UI")
    ConfigGUI.BackColor := UI_Colors.Background
    
    ; 窗口尺寸 - 全屏显示
    ScreenInfo := GetScreenInfo(PanelScreenIndex)
    ; 窗口总尺寸（包括标题栏和边框）- 使用屏幕尺寸
    global ConfigWidth := ScreenInfo.Width
    global ConfigHeight := ScreenInfo.Height
    
    ; 注意：控件坐标是相对于客户区的，客户区从标题栏下方开始
    ; 窗口显示后，我们可以通过 WinGetClientPos 获取实际客户区尺寸
    ; 暂时使用估算值，窗口显示后会通过 Size 事件更新
    global ConfigClientWidth := ScreenInfo.Width - 20  ; 估算：减去左右边框
    global ConfigClientHeight := ScreenInfo.Height - 50  ; 估算：减去标题栏和上下边框
    
    ; 侧边栏宽度（全局变量，用于大小调整）
    global SidebarWidth := 150
    
    ; ========== 左侧侧边栏 (150px，更窄以给右侧更多空间) ==========
    ; SidebarWidth 已在上面声明为全局变量
    ; 控件坐标是相对于客户区的，客户区从标题栏下方开始，所以 y=0 就是标题栏下方
    SidebarBg := ConfigGUI.Add("Text", "x0 y0 w" . SidebarWidth . " h" . ConfigClientHeight . " Background" . UI_Colors.Sidebar . " vSidebarBg", "")
    
    ; 牛马图标（放大显示，可点击切换）
    global ThemeMode, CustomIconPath
    if (!IsSet(ThemeMode) || ThemeMode = "") {
        ThemeMode := "dark"
    }
    IconSize := 32
    IconX := 10
    IconY := 10  ; 客户区顶部（标题栏下方）
    ; 优先使用用户自定义图标
    IconPath := ResolveDefaultUiIconPath()
    if (FileExist(IconPath)) {
        global SearchIcon := ConfigGUI.Add("Picture", "x" . IconX . " y" . IconY . " w" . IconSize . " h" . IconSize . " BackgroundTrans vConfigIcon", IconPath)
        SearchIcon.OnEvent("Click", (*) => ChangeCustomIcon())
    }
    
    ; 标签按钮起始位置（使用原生标题栏，从图标下方开始）
    TabY := IconY + IconSize + 10
    TabHeight := 35
    TabSpacing := 2
    
    ; 创建侧边栏标签按钮组（使用 Material 风格单选按钮）
    global TabRadioGroup := []
    TabRadioWidth := SidebarWidth - 10
    TabRadioHeight := TabHeight
    
    ; 创建标签页单选按钮（不自动绑定点击事件，使用自定义事件）
    TabGeneral := CreateMaterialRadioButton(ConfigGUI, 5, TabY, TabRadioWidth, TabRadioHeight, "TabGeneral", GetText("tab_general"), TabRadioGroup, 10, false)
    TabRadioGroup.Push(TabGeneral)
    TabGeneral.OnEvent("Click", (*) => SwitchTab("general"))
    
    TabAppearance := CreateMaterialRadioButton(ConfigGUI, 5, TabY + (TabHeight + TabSpacing), TabRadioWidth, TabRadioHeight, "TabAppearance", GetText("tab_appearance"), TabRadioGroup, 10, false)
    TabRadioGroup.Push(TabAppearance)
    TabAppearance.OnEvent("Click", (*) => SwitchTab("appearance"))
    
    TabPrompts := CreateMaterialRadioButton(ConfigGUI, 5, TabY + (TabHeight + TabSpacing) * 2, TabRadioWidth, TabRadioHeight, "TabPrompts", GetText("tab_prompts"), TabRadioGroup, 10, false)
    TabRadioGroup.Push(TabPrompts)
    TabPrompts.OnEvent("Click", (*) => SwitchTab("prompts"))
    
    TabHotkeys := CreateMaterialRadioButton(ConfigGUI, 5, TabY + (TabHeight + TabSpacing) * 3, TabRadioWidth, TabRadioHeight, "TabHotkeys", GetText("tab_hotkeys"), TabRadioGroup, 10, false)
    TabRadioGroup.Push(TabHotkeys)
    TabHotkeys.OnEvent("Click", (*) => SwitchTab("hotkeys"))
    
    TabAdvanced := CreateMaterialRadioButton(ConfigGUI, 5, TabY + (TabHeight + TabSpacing) * 4, TabRadioWidth, TabRadioHeight, "TabAdvanced", GetText("tab_advanced"), TabRadioGroup, 10, false)
    TabRadioGroup.Push(TabAdvanced)
    TabAdvanced.OnEvent("Click", (*) => SwitchTab("advanced"))
    
    ; 添加全域搜索标签
    TabSearch := CreateMaterialRadioButton(ConfigGUI, 5, TabY + (TabHeight + TabSpacing) * 5, TabRadioWidth, TabRadioHeight, "TabSearch", "全域搜索", TabRadioGroup, 10, false)
    TabRadioGroup.Push(TabSearch)
    TabSearch.OnEvent("Click", (*) => SwitchTab("search"))
    
    ; ========== 右侧内容区域（可滚动）==========
    ContentX := SidebarWidth
    ContentWidth := ConfigClientWidth - SidebarWidth
    ContentY := 0  ; 客户区顶部（标题栏下方）
    ContentHeight := ConfigClientHeight - 50 ; 留出底部按钮空间
    
    ; 创建一个可滚动的容器来包裹所有内容
    ; 使用隐藏的滚动条控件来启用窗口滚动功能
    ; 在 AutoHotkey v2 中，可以通过设置窗口的滚动区域来实现滚动
    global ScrollContainer := 0  ; 不使用单独的滚动容器，直接使用窗口滚动
    
    ; 保存标签控件的引用
    ConfigTabs := Map(
        "general", TabGeneral,
        "appearance", TabAppearance,
        "prompts", TabPrompts,
        "hotkeys", TabHotkeys,
        "advanced", TabAdvanced,
        "search", TabSearch
    )
    global ConfigTabs := ConfigTabs
    
    ; 创建各个标签页的内容面板 (注意: 此时传入的 Y 坐标是相对于窗口客户区的)
    ; 内容可以超出 ContentHeight，通过鼠标滚轮滚动查看
    CreateGeneralTab(ConfigGUI, ContentX, ContentY, ContentWidth, ContentHeight)
    CreateAppearanceTab(ConfigGUI, ContentX, ContentY, ContentWidth, ContentHeight)
    CreatePromptsTab(ConfigGUI, ContentX, ContentY, ContentWidth, ContentHeight)
    CreateHotkeysTab(ConfigGUI, ContentX, ContentY, ContentWidth, ContentHeight)
    CreateAdvancedTab(ConfigGUI, ContentX, ContentY, ContentWidth, ContentHeight)
    CreateSearchTab(ConfigGUI, ContentX, ContentY, ContentWidth, ContentHeight)
    
    ; ========== 底部按钮区域 (右侧) ==========
    ButtonAreaY := ConfigClientHeight - 50  ; 底部按钮位置（相对于客户区）
    ; 移除底部按钮区域的背景色块，只保留按钮本身
    ; ButtonAreaBg := ConfigGUI.Add("Text", "x" . ContentX . " y" . ButtonAreaY . " w" . ContentWidth . " h50 Background" . UI_Colors.Background . " vButtonAreaBg", "") ; 遮挡背景
    
    ; 底部按钮辅助函数（不带说明文字）
    CreateBottomBtn(Label, XPos, Action, IsPrimary := false, BtnName := "", Desc := "") {
        BgColor := IsPrimary ? UI_Colors.BtnPrimary : UI_Colors.BtnBg
        HoverColor := IsPrimary ? UI_Colors.BtnPrimaryHover : UI_Colors.BtnHover
        
        ; 按钮文字颜色：主要按钮使用白色，非主要按钮根据主题调整
        ; 亮色模式下非主要按钮使用深色文字，暗色模式下使用白色文字
        global ThemeMode
        TextColor := IsPrimary ? "FFFFFF" : (ThemeMode = "light" ? UI_Colors.Text : "FFFFFF")
        
        Btn := ConfigGUI.Add("Text", "x" . XPos . " y" . (ButtonAreaY + 10) . " w80 h30 Center 0x200 c" . TextColor . " Background" . BgColor . (BtnName ? " v" . BtnName : ""), Label)
        Btn.SetFont("s9", "Segoe UI")
        Btn.OnEvent("Click", Action)
        ; 使用带动效的悬停函数
        HoverBtnWithAnimation(Btn, BgColor, HoverColor)
        
        ; 【移除说明文字】不再添加按钮功能说明
        
        return Btn
    }

    ; 计算按钮位置 (右对齐，确保不重叠)
    ; 导出、导入、重置默认已移到高级标签页，现在只有2个按钮
    BtnWidth := 80
    BtnSpacing := 10
    BtnStartX := ConfigClientWidth - (BtnWidth * 2 + BtnSpacing) - 20  ; 2个按钮，1个间距，右边距20
    CreateBottomBtn(GetText("save_config"), BtnStartX, SaveConfigAndClose, true, "SaveBtn", GetText("save_config_desc")) ; Primary
    CreateBottomBtn(GetText("cancel"), BtnStartX + BtnWidth + BtnSpacing, (*) => CloseConfigGUI(), false, "CancelBtn", GetText("cancel_desc"))
    
    ; 根据配置显示默认标签页
    global DefaultStartTab
    if (!IsSet(DefaultStartTab) || DefaultStartTab = "") {
        DefaultStartTab := "general"
    }
    SwitchTab(DefaultStartTab)
    
    ; 获取屏幕信息并全屏显示
    ScreenInfo := GetScreenInfo(ConfigPanelScreenIndex)
    ; 全屏显示，使用屏幕的左上角坐标
    PosX := ScreenInfo.Left
    PosY := ScreenInfo.Top
    
    ; 保存ConfigGUI引用
    GuiID_ConfigGUI := ConfigGUI
    
    ; 添加窗口大小调整事件处理
    ConfigGUI.OnEvent("Size", ConfigGUI_Size)
    ; 注意：AutoHotkey v2 不支持 Move 事件，使用定时器定期保存位置
    ConfigGUI.OnEvent("Close", (*) => CloseConfigGUI())
    
    ; 使用定时器定期保存配置窗口位置（每500ms检查一次）
    ; 注意：AutoHotkey v2 不支持 Move 事件，所以使用定时器
    SetTimer(() => SaveConfigGUIPosition(ConfigGUI), 500)
    
    ; 恢复窗口位置和大小
    WindowName := GetText("config_title")
    RestoredPos := RestoreWindowPosition(WindowName, ConfigWidth, ConfigHeight)
    if (RestoredPos.X = -1 || RestoredPos.Y = -1) {
        RestoredPos.X := PosX
        RestoredPos.Y := PosY
    }
    ; 确保窗口尺寸正确（如果恢复的尺寸无效，使用默认尺寸）
    if (RestoredPos.Width < 800 || RestoredPos.Height < 600) {
        RestoredPos.Width := ConfigWidth
        RestoredPos.Height := ConfigHeight
    }
    
    ; 使用原生标题栏，不需要自定义关闭按钮

    ; 添加 Escape 键关闭命令
    ConfigGUI.OnEvent("Escape", (*) => CloseConfigGUI())
    
    ; 显示窗口（使用窗口总尺寸，包括标题栏和边框）
    ConfigGUI.Show("w" . RestoredPos.Width . " h" . RestoredPos.Height . " x" . RestoredPos.X . " y" . RestoredPos.Y)
    
    ; 确保窗口有正确的样式，显示标题栏
    ; 检查窗口是否有标题栏样式（WS_CAPTION = 0x00C00000）
    CurrentStyle := DllCall("user32.dll\GetWindowLongPtr", "Ptr", ConfigGUI.Hwnd, "Int", -16, "Ptr")
    WS_CAPTION := 0x00C00000
    if (!(CurrentStyle & WS_CAPTION)) {
        ; 如果没有标题栏样式，添加它
        NewStyle := CurrentStyle | WS_CAPTION
        DllCall("user32.dll\SetWindowLongPtr", "Ptr", ConfigGUI.Hwnd, "Int", -16, "Ptr", NewStyle, "Ptr")
        ; 刷新窗口框架
        DllCall("user32.dll\SetWindowPos", "Ptr", ConfigGUI.Hwnd, "Ptr", 0, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x0027, "Int")
    }
    
    ; 窗口显示后，获取实际客户区尺寸并更新布局
    WinGetClientPos(, , &ActualClientWidth, &ActualClientHeight, ConfigGUI.Hwnd)
    if (ActualClientWidth > 0 && ActualClientHeight > 0) {
        global ConfigClientWidth := ActualClientWidth
        global ConfigClientHeight := ActualClientHeight
        ; 更新侧边栏和内容区域尺寸
        try {
            SidebarBg := ConfigGUI["SidebarBg"]
            if (SidebarBg) {
                SidebarBg.Move(, , , ActualClientHeight)
            }
        }
        ; 触发 Size 事件更新所有控件
        ConfigGUI_Size(ConfigGUI, 0, ActualClientWidth, ActualClientHeight)
    }
    
    ; 设置下拉列表最小可见项数（窗口显示后设置，延迟300ms确保ComboBox完全初始化）
    SetTimer(SetDDLMinVisible, -300)
    
    ; 设置窗口最小尺寸限制（使用 DllCall 调用 Windows API）
    SetWindowMinSizeLimit(ConfigGUI.Hwnd, 800, 600)
    
    ; 保留原生标题栏和边框，不修改窗口样式
    ; 移除之前的边框修改代码，确保标题栏正常显示
    
    ; 确保窗口在最上层并激活
    WinSetAlwaysOnTop(1, ConfigGUI.Hwnd)
    WinActivate(ConfigGUI.Hwnd)
    
    ; 【移除滚动功能】不再启用配置面板的滚轮热键（已移除滚动条）
}
OpenLegacyConfigGUI(targetTab := "") {
    global UseWebViewSettings
    UseWebViewSettings := false
    try {
        ShowConfigGUI()
        if (targetTab != "") {
            SetTimer((*) => SwitchTab(targetTab), -200)
        }
    } finally {
        SetTimer((*) => (UseWebViewSettings := true), -300)
    }
}
; ===================== 配置面板滚动消息处理 =====================
ConfigGUI_OnScroll(wParam, lParam, msg, hwnd) {
    global GuiID_ConfigGUI
    
    if (GuiID_ConfigGUI = 0 || hwnd != GuiID_ConfigGUI.Hwnd) {
        return
    }
    
    ; 获取滚动信息
    ScrollWidth := DllCall("user32.dll\GetProp", "Ptr", hwnd, "Str", "ScrollWidth", "Int")
    ScrollHeight := DllCall("user32.dll\GetProp", "Ptr", hwnd, "Str", "ScrollHeight", "Int")
    VisibleWidth := DllCall("user32.dll\GetProp", "Ptr", hwnd, "Str", "VisibleWidth", "Int")
    VisibleHeight := DllCall("user32.dll\GetProp", "Ptr", hwnd, "Str", "VisibleHeight", "Int")
    ScrollX := DllCall("user32.dll\GetProp", "Ptr", hwnd, "Str", "ScrollX", "Int")
    ScrollY := DllCall("user32.dll\GetProp", "Ptr", hwnd, "Str", "ScrollY", "Int")
    
    if (!ScrollWidth || !ScrollHeight) {
        return
    }
    
    ; 判断是垂直滚动还是水平滚动
    if (msg = 0x115) {  ; WM_VSCROLL - 垂直滚动
        ScrollCode := wParam & 0xFFFF
        NewScrollY := ScrollY
        
        switch ScrollCode {
            case 0:  ; SB_LINEUP - 向上滚动一行
                NewScrollY := Max(0, ScrollY - 20)
            case 1:  ; SB_LINEDOWN - 向下滚动一行
                NewScrollY := Min(ScrollHeight - VisibleHeight, ScrollY + 20)
            case 2:  ; SB_PAGEUP - 向上滚动一页
                NewScrollY := Max(0, ScrollY - VisibleHeight)
            case 3:  ; SB_PAGEDOWN - 向下滚动一页
                NewScrollY := Min(ScrollHeight - VisibleHeight, ScrollY + VisibleHeight)
            case 4:  ; SB_THUMBPOSITION - 拖动滚动条
                NewScrollY := (wParam >> 16) & 0xFFFF
            case 5:  ; SB_THUMBTRACK - 拖动滚动条（实时跟踪）
                NewScrollY := (wParam >> 16) & 0xFFFF
            case 6:  ; SB_TOP - 滚动到顶部
                NewScrollY := 0
            case 7:  ; SB_BOTTOM - 滚动到底部
                NewScrollY := ScrollHeight - VisibleHeight
        }
        
        if (NewScrollY != ScrollY) {
            ; 更新滚动位置
            DllCall("user32.dll\SetProp", "Ptr", hwnd, "Str", "ScrollY", "Int", NewScrollY, "Ptr")
            
            ; 更新滚动条位置
            ScrollInfo := Buffer(A_PtrSize = 8 ? 32 : 28, 0)
            NumPut("UInt", A_PtrSize = 8 ? 32 : 28, ScrollInfo, 0)
            NumPut("UInt", 0x14, ScrollInfo, 4)  ; fMask = SIF_POS
            NumPut("Int", NewScrollY, ScrollInfo, 20)  ; nPos
            DllCall("user32.dll\SetScrollInfo", "Ptr", hwnd, "Int", 1, "Ptr", ScrollInfo, "Int", 1)
            
            ; 滚动窗口内容
            DllCall("user32.dll\ScrollWindowEx", "Ptr", hwnd, "Int", 0, "Int", ScrollY - NewScrollY, "Ptr", 0, "Ptr", 0, "Ptr", 0, "Ptr", 0, "Int", 0x0010)  ; SW_INVALIDATE
            DllCall("user32.dll\UpdateWindow", "Ptr", hwnd, "Int")
        }
    } else if (msg = 0x114) {  ; WM_HSCROLL - 水平滚动
        ScrollCode := wParam & 0xFFFF
        NewScrollX := ScrollX
        
        switch ScrollCode {
            case 0:  ; SB_LINELEFT
                NewScrollX := Max(0, ScrollX - 20)
            case 1:  ; SB_LINERIGHT
                NewScrollX := Min(ScrollWidth - VisibleWidth, ScrollX + 20)
            case 2:  ; SB_PAGELEFT
                NewScrollX := Max(0, ScrollX - VisibleWidth)
            case 3:  ; SB_PAGERIGHT
                NewScrollX := Min(ScrollWidth - VisibleWidth, ScrollX + VisibleWidth)
            case 4:  ; SB_THUMBPOSITION
                NewScrollX := (wParam >> 16) & 0xFFFF
            case 5:  ; SB_THUMBTRACK
                NewScrollX := (wParam >> 16) & 0xFFFF
            case 6:  ; SB_LEFT
                NewScrollX := 0
            case 7:  ; SB_RIGHT
                NewScrollX := ScrollWidth - VisibleWidth
        }
        
        if (NewScrollX != ScrollX) {
            ; 更新滚动位置
            DllCall("user32.dll\SetProp", "Ptr", hwnd, "Str", "ScrollX", "Int", NewScrollX, "Ptr")
            
            ; 更新滚动条位置
            ScrollInfo := Buffer(A_PtrSize = 8 ? 32 : 28, 0)
            NumPut("UInt", A_PtrSize = 8 ? 32 : 28, ScrollInfo, 0)
            NumPut("UInt", 0x14, ScrollInfo, 4)  ; fMask = SIF_POS
            NumPut("Int", NewScrollX, ScrollInfo, 20)  ; nPos
            DllCall("user32.dll\SetScrollInfo", "Ptr", hwnd, "Int", 0, "Ptr", ScrollInfo, "Int", 1)
            
            ; 滚动窗口内容
            DllCall("user32.dll\ScrollWindowEx", "Ptr", hwnd, "Int", ScrollX - NewScrollX, "Int", 0, "Ptr", 0, "Ptr", 0, "Ptr", 0, "Ptr", 0, "Int", 0x0010)  ; SW_INVALIDATE
            DllCall("user32.dll\UpdateWindow", "Ptr", hwnd, "Int")
        }
    }
}

; ===================== 配置面板大小调整处理 =====================
ConfigGUI_Size(GuiObj, MinMax, Width, Height) {
    global GuiID_ConfigGUI, SidebarWidth, UI_Colors, WindowDragging
    
    if (GuiID_ConfigGUI = 0 || GuiID_ConfigGUI != GuiObj) {
        return
    }
    
    ; 获取最小窗口尺寸限制（从窗口属性中读取）
    MinWidth := DllCall("user32.dll\GetProp", "Ptr", GuiObj.Hwnd, "Str", "MinWidth", "Int")
    MinHeight := DllCall("user32.dll\GetProp", "Ptr", GuiObj.Hwnd, "Str", "MinHeight", "Int")
    
    ; 如果没有设置，使用默认值
    if (!MinWidth) {
        MinWidth := 800
    }
    if (!MinHeight) {
        MinHeight := 600
    }
    
    ; 检查并限制最小尺寸
    if (Width < MinWidth || Height < MinHeight) {
        ; 如果窗口尺寸小于最小值，调整到最小值
        NewWidth := Width < MinWidth ? MinWidth : Width
        NewHeight := Height < MinHeight ? MinHeight : Height
        GuiObj.Move(, , NewWidth, NewHeight)
        return
    }
    
    ; 【关键优化】如果窗口正在拖动，只更新必要的控件位置，跳过复杂的布局更新
    ; 这样可以避免拖动时频繁重绘整个窗口
    if (WindowDragging) {
        ; 使用原生标题栏，不需要更新自定义按钮位置
        ; 拖动时不保存位置，不更新其他控件，避免频繁重绘
        return
    }
    
    ; 【修复闪烁问题】锁定窗口更新，防止在调整大小过程中出现闪烁
    ; LockWindowUpdate 会阻止窗口重绘，直到调用 UnlockWindowUpdate
    try {
        DllCall("user32.dll\LockWindowUpdate", "Ptr", GuiObj.Hwnd)
    } catch as err {
        ; 如果锁定失败，继续执行（某些情况下可能失败）
    }
    
    ; 使用原生标题栏，不需要更新自定义标题栏和按钮
    ; 注意：Size 事件中的 Width 和 Height 是客户区大小（不包括标题栏）
    ; 控件坐标是相对于客户区的，所以 y=0 就是标题栏下方
    
    ; 更新侧边栏高度（客户区从 y=0 开始）
    try {
        SidebarBg := GuiObj["SidebarBg"]
        if (SidebarBg) {
            SidebarBg.Move(, , , Height)  ; 客户区高度
        }
    }
    
    ; 更新内容区域大小（客户区从 y=0 开始）
    ContentX := SidebarWidth
    ContentWidth := Width - SidebarWidth
    ContentY := 0  ; 客户区顶部
    ContentHeight := Height - 50  ; 留出底部按钮空间
    
    ; 更新底部按钮区域位置
    ButtonAreaY := Height - 70  ; 增加高度以容纳按钮说明文字
    ; 已移除ButtonAreaBg，不再需要更新
    ; try {
    ;     ButtonAreaBg := GuiObj["ButtonAreaBg"]
    ;     if (ButtonAreaBg) {
    ;         ButtonAreaBg.Move(ContentX, ButtonAreaY, ContentWidth)
    ;     }
    ; }
    
    ; 保存窗口大小（使用延迟保存，避免频繁IO）
    try {
        WinGetPos(&WinX, &WinY, , , GuiObj.Hwnd)
        WindowName := GetText("config_title")
        QueueWindowPositionSave(WindowName, WinX, WinY, Width, Height)
    } catch as err {
        ; 忽略错误
    }
    
    ; 更新各个标签页的内容区域大小
    ; 通用标签页
    try {
        GeneralTabPanel := GuiObj["GeneralTabPanel"]
        if (GeneralTabPanel) {
            GeneralTabPanel.Move(ContentX, ContentY, ContentWidth, ContentHeight)
        }
    }
    
    ; 外观标签页
    try {
        AppearanceTabPanel := GuiObj["AppearanceTabPanel"]
        if (AppearanceTabPanel) {
            AppearanceTabPanel.Move(ContentX, ContentY, ContentWidth, ContentHeight)
        }
    }
    
    ; 提示词标签页
    try {
        PromptsTabPanel := GuiObj["PromptsTabPanel"]
        if (PromptsTabPanel) {
            PromptsTabPanel.Move(ContentX, ContentY, ContentWidth, ContentHeight)
        }
    }
    
    ; 快捷键标签页
    try {
        HotkeysTabPanel := GuiObj["HotkeysTabPanel"]
        if (HotkeysTabPanel) {
            HotkeysTabPanel.Move(ContentX, ContentY, ContentWidth, ContentHeight)
        }
    }
    
    ; 高级标签页
    try {
        AdvancedTabPanel := GuiObj["AdvancedTabPanel"]
        if (AdvancedTabPanel) {
            AdvancedTabPanel.Move(ContentX, ContentY, ContentWidth, ContentHeight)
        }
    }
    
    ; 搜索标签页（全域搜索）
    try {
        SearchTabPanel := GuiObj["SearchTabPanel"]
        if (SearchTabPanel) {
            SearchTabPanel.Move(ContentX, ContentY, ContentWidth, ContentHeight)
            
            ; 更新搜索输入框宽度
            global SearchHistoryEdit
            if (SearchHistoryEdit) {
                try {
                    SearchHistoryEdit.GetPos(&EditX, &EditY, , &EditH)
                    SearchHistoryEdit.Move(EditX, EditY, ContentWidth - 100, EditH)
                } catch as err {
                }
            }
            
            ; 更新搜索结果ListView大小
            global SearchResultsListView
            if (SearchResultsListView) {
                try {
                    SearchResultsListView.GetPos(&LVX, &LVY, , &LVH)
                    SearchResultsListView.Move(LVX, LVY, ContentWidth - 60, LVH)
                } catch as err {
                }
            }
        }
    }
    
    ; 更新滚动容器大小（如果存在）
    try {
        ScrollContainer := GuiObj["ScrollContainer"]
        if (ScrollContainer) {
            ScrollContainer.Move(ContentX, ContentY, ContentWidth, ContentHeight)
        }
    }
    
    ; 更新底部按钮位置（右对齐，确保不重叠）
    try {
        ; 计算按钮起始位置（右对齐）
        ; 导出、导入、重置默认已移到高级标签页，现在只有2个按钮
        BtnWidth := 80
        BtnSpacing := 10
        BtnStartX := Width - (BtnWidth * 2 + BtnSpacing) - 20  ; 2个按钮，1个间距，右边距20
        
        ; 更新所有底部按钮的位置
        SaveBtn := GuiObj["SaveBtn"]
        if (SaveBtn) {
            SaveBtn.Move(BtnStartX, ButtonAreaY + 10)
        }
        CancelBtn := GuiObj["CancelBtn"]
        if (CancelBtn) {
            CancelBtn.Move(BtnStartX + (BtnWidth + BtnSpacing) * 4, ButtonAreaY + 10)
        }
    }
    
    ; 【修复闪烁问题】解锁窗口更新，允许窗口重绘
    ; 所有控件更新完成后，一次性重绘窗口
    try {
        DllCall("user32.dll\LockWindowUpdate", "Ptr", 0)  ; 0表示解锁
        ; 使用InvalidateRect和UpdateWindow来强制重绘整个窗口
        DllCall("user32.dll\InvalidateRect", "Ptr", GuiObj.Hwnd, "Ptr", 0, "Int", 1)  ; 1 = TRUE，重绘整个窗口
        DllCall("user32.dll\UpdateWindow", "Ptr", GuiObj.Hwnd)
    } catch as err {
        ; 如果解锁失败，尝试使用WinRedraw作为后备方案
        try {
            WinRedraw(GuiObj.Hwnd)
        } catch as err {
        }
    }
}

; ===================== 配置面板滚动处理 =====================
; 启用配置面板滚动热键
EnableConfigScroll() {
    ; 使用热键捕获滚轮事件（仅在配置面板激活时）
    Hotkey("WheelUp", ConfigWheelUp, "On")
    Hotkey("WheelDown", ConfigWheelDown, "On")
}

; 禁用配置面板滚动热键
DisableConfigScroll() {
    try {
        Hotkey("WheelUp", ConfigWheelUp, "Off")
        Hotkey("WheelDown", ConfigWheelDown, "Off")
    }
}

ConfigWheelUp(*) {
    ; 鼠标滚轮向上滚动
    global GuiID_ConfigGUI, ScrollContainer
    if (GuiID_ConfigGUI = 0) {
        return
    }
    
    ; 检查配置面板是否激活
    if (!WinActive("ahk_id " . GuiID_ConfigGUI.Hwnd)) {
        return
    }
    
    MouseGetPos(&MouseX, &MouseY)
    try {
        WinGetPos(&WinX, &WinY, &WinW, &WinH, GuiID_ConfigGUI.Hwnd)
        ; 检查鼠标是否在内容区域（排除标题栏、侧边栏和底部按钮）
        global SidebarWidth
        if (MouseX > WinX + SidebarWidth && MouseY > WinY + 35 && MouseY < WinY + WinH - 50) {
            ; 如果有滚动容器，向滚动容器发送滚动消息
            if (ScrollContainer && ScrollContainer.Hwnd) {
                SendMessage(0x115, 0, 0, ScrollContainer.Hwnd)  ; WM_VSCROLL, SB_LINEUP
            } else {
                ; 否则向窗口发送滚动消息
                SendMessage(0x115, 0, 0, , GuiID_ConfigGUI.Hwnd)  ; WM_VSCROLL, SB_LINEUP
            }
        }
    }
}

ConfigWheelDown(*) {
    ; 鼠标滚轮向下滚动
    global GuiID_ConfigGUI, ScrollContainer
    if (GuiID_ConfigGUI = 0) {
        return
    }
    
    ; 检查配置面板是否激活
    if (!WinActive("ahk_id " . GuiID_ConfigGUI.Hwnd)) {
        return
    }
    
    MouseGetPos(&MouseX, &MouseY)
    try {
        WinGetPos(&WinX, &WinY, &WinW, &WinH, GuiID_ConfigGUI.Hwnd)
        ; 检查鼠标是否在内容区域（排除标题栏、侧边栏和底部按钮）
        global SidebarWidth
        if (MouseX > WinX + SidebarWidth && MouseY > WinY + 35 && MouseY < WinY + WinH - 50) {
            ; 向窗口发送滚动消息（使用 PostMessage 确保消息被处理）
            PostMessage(0x115, 1, 0, , GuiID_ConfigGUI.Hwnd)  ; WM_VSCROLL, SB_LINEDOWN
        }
    }
}

; 原生配置窗关闭路径（WebView 分支留在主脚本 CloseConfigGUI）
LegacyConfigGui_CloseNative() {
    global CloseConfigGUI_IsClosing
    global GuiID_ConfigGUI, CapsLockHoldTimeEdit, CapsLockHoldTimeSeconds, ConfigFile
    global DDLBrush, DefaultStartTabDDL_Hwnd
    ; 检查窗口是否仍然有效
    try {
        if (!WinExist("ahk_id " . GuiID_ConfigGUI.Hwnd)) {
            GuiID_ConfigGUI := 0
            return
        }
    } catch as err {
        ; 如果检查失败，说明窗口可能已经关闭
        GuiID_ConfigGUI := 0
        return
    }
    
    ; 设置关闭标志
    CloseConfigGUI_IsClosing := true
    
    ; 禁用滚动热键
    DisableConfigScroll()
    
    ; 清理下拉框相关的资源
    if (DDLBrush != 0) {
        try {
            DllCall("gdi32.dll\DeleteObject", "Ptr", DDLBrush)
            DDLBrush := 0
        } catch as err {
        }
    }
    DefaultStartTabDDL_Hwnd := 0
    
    ; 【修复】在关闭配置面板前，自动保存 CapsLock 长按时间的修改
    if (GuiID_ConfigGUI != 0 && CapsLockHoldTimeEdit) {
        try {
            ; 获取编辑框的值
            EditValue := CapsLockHoldTimeEdit.Value
            if (EditValue != "") {
                ; 尝试转换为浮点数（更健壮的方式，不依赖 IsNumber）
                try {
                    NewHoldTime := Float(EditValue)
                    ; 验证值在合理范围内（0.1秒到5秒）
                    if (NewHoldTime >= 0.1 && NewHoldTime <= 5.0) {
                        ; 更新全局变量
                        CapsLockHoldTimeSeconds := NewHoldTime
                        ; 保存到配置文件（确保使用字符串格式保存，避免精度问题）
                        IniWrite(String(CapsLockHoldTimeSeconds), ConfigFile, "Settings", "CapsLockHoldTimeSeconds")
                    } else {
                        ; 如果值超出范围，修正并保存
                        if (NewHoldTime < 0.1) {
                            CapsLockHoldTimeSeconds := 0.1
                        } else if (NewHoldTime > 5.0) {
                            CapsLockHoldTimeSeconds := 5.0
                        }
                        IniWrite(String(CapsLockHoldTimeSeconds), ConfigFile, "Settings", "CapsLockHoldTimeSeconds")
                    }
                } catch as err {
                    ; 如果转换失败，保持当前全局变量的值并保存
                    if (IsSet(CapsLockHoldTimeSeconds) && CapsLockHoldTimeSeconds != "") {
                        IniWrite(String(CapsLockHoldTimeSeconds), ConfigFile, "Settings", "CapsLockHoldTimeSeconds")
                    }
                }
            } else {
                ; 如果编辑框为空，保存当前全局变量的值（不丢失已有配置）
                if (IsSet(CapsLockHoldTimeSeconds) && CapsLockHoldTimeSeconds != "") {
                    IniWrite(String(CapsLockHoldTimeSeconds), ConfigFile, "Settings", "CapsLockHoldTimeSeconds")
                }
            }
        } catch as e {
            ; 记录错误但不影响关闭操作
            ; 尝试保存当前全局变量的值作为后备
            try {
                if (IsSet(CapsLockHoldTimeSeconds) && CapsLockHoldTimeSeconds != "") {
                    IniWrite(String(CapsLockHoldTimeSeconds), ConfigFile, "Settings", "CapsLockHoldTimeSeconds")
                }
            }
        }
    }
    
    ; 关闭窗口
    if (GuiID_ConfigGUI != 0) {
        try {
            ; 先重置全局变量，避免重复调用
            TempGUI := GuiID_ConfigGUI
            GuiID_ConfigGUI := 0
            
            ; 销毁窗口
            TempGUI.Destroy()
        } catch as e {
            ; 如果销毁失败，确保全局变量已重置
            GuiID_ConfigGUI := 0
        }
    }
    
    ; 重置关闭标志（延迟重置，确保窗口完全关闭）
    SetTimer(LegacyConfigGui_ClearClosingFlag, -100)
}

LegacyConfigGui_ClearClosingFlag(*) {
    global CloseConfigGUI_IsClosing
    CloseConfigGUI_IsClosing := false
}
