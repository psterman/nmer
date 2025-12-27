; ===================== 基础配置 =====================
#SingleInstance Force
SetTitleMatchMode(2)
SetControlDelay(-1)
SetKeyDelay(20, 20)
SetMouseDelay(10)
SendMode("Input")
DetectHiddenWindows(true)

; ===================== 管理员权限检查 =====================
; 如果脚本不是以管理员权限运行，则重新以管理员权限启动
if (!A_IsAdmin) {
    try {
        ; 使用 RunAs 以管理员权限重新运行脚本
        Run('*RunAs "' . A_ScriptFullPath . '"')
        ExitApp()
    } catch as e {
        MsgBox("无法以管理员权限运行脚本。某些功能可能无法正常工作。`n错误: " . e.Message, "警告", "Icon!")
    }
}

; 全局变量（v2用Class/全局变量管理）
global CapsLockDownTime := 0
global IsCommandMode := false
global PanelVisible := false
global GuiID_CursorPanel := 0
global CursorPanelDescText := 0  ; 快捷操作面板说明文字控件
global CursorPanelAlwaysOnTop := false  ; 面板是否置顶（默认不置顶）
global CursorPanelAutoHide := false  ; 面板是否启用靠边自动隐藏
global CursorPanelHidden := false  ; 面板是否已隐藏（靠边时）
global CursorPanelWidth := 420  ; 面板宽度
global CursorPanelHeight := 0  ; 面板高度（动态计算）
global ConfigFile := A_ScriptDir "\CursorShortcut.ini"
global TrayIconPath := A_ScriptDir "\cursor_helper.ico"
; CapsLock+ 方案的核心变量
global CapsLock := false
global GuiID_ConfigGUI := 0  ; 配置面板单例
global DefaultStartTabDDL_Hwnd := 0  ; 默认启动页面下拉框句柄
global DefaultStartTabDDL_Hwnd_ForTimer := 0  ; 默认启动页面下拉框句柄（用于定时器）
global DDLBrush := 0  ; 下拉列表背景画刷
global MoveGUIListBoxHwnd := 0  ; 移动分类弹窗ListBox句柄
global MoveGUIListBoxBrush := 0  ; 移动分类弹窗ListBox画刷
global MoveFromTemplateListBoxHwnd := 0  ; 从模板移动弹窗ListBox句柄
global MoveFromTemplateListBoxBrush := 0  ; 从模板移动弹窗ListBox画刷
global CapsLock2 := false  ; 是否使用过 CapsLock+ 功能标记，使用过会清除这个变量
; 动态快捷键映射（默认值）
global SplitHotkey := "s"
global BatchHotkey := "b"
global HotkeyESC := "Esc"  ; 关闭面板
global HotkeyC := "c"  ; 连续复制
global HotkeyV := "v"  ; 合并粘贴
global HotkeyX := "x"  ; 打开剪贴板管理面板
global HotkeyE := "e"  ; 执行解释
global HotkeyR := "r"  ; 执行重构
global HotkeyO := "o"  ; 执行优化
global HotkeyQ := "q"  ; 打开配置面板
global HotkeyZ := "z"  ; 语音输入
global HotkeyF := "f"  ; 语音搜索
global HotkeyP := "p"  ; 区域截图
; 截图等待粘贴相关变量
global ScreenshotWaiting := false  ; 是否正在等待粘贴截图
global ScreenshotClipboard := ""  ; 保存的截图剪贴板内容
global ScreenshotCheckTimer := 0  ; 截图检测定时器
global GuiID_ScreenshotButton := 0  ; 截图悬浮按钮 GUI ID
global ScreenshotButtonVisible := false  ; 截图按钮是否可见
global ScreenshotPanelX := -1  ; 截图面板 X 坐标（-1 表示使用默认居中位置）
global ScreenshotPanelY := -1  ; 截图面板 Y 坐标（-1 表示使用默认居中位置）
; 配置变量
global CursorPath := ""
global AISleepTime := 15000
global CapsLockHoldTimeSeconds := 0.5  ; CapsLock长按时间（秒），默认0.5秒
global Prompt_Explain := ""
global Prompt_Refactor := ""
global Prompt_Optimize := ""
; 提示词模板系统
global PromptTemplates := []  ; 模板数组 [{ID, Title, Content, Icon, FunctionCategory, Series, Category(兼容旧版本)}]
global DefaultTemplateIDs := Map()  ; 默认模板映射 {"Explain" => TemplateID, "Refactor" => TemplateID, "Optimize" => TemplateID}
global PromptTemplatesFile := A_ScriptDir "\PromptTemplates.ini"  ; 模板配置文件
global ExpandedTemplateKey := ""  ; 当前展开的模板键（格式：FunctionCategory_Series_Index）
global CategoryMap := Map()  ; 双层分类索引 CategoryMap[功能分类ID][模板系列ID] = 模板数组
; 性能优化索引（O(1)查找）
global TemplateIndexByID := Map()  ; ID -> Template 对象，用于快速查找
global TemplateIndexByTitle := Map()  ; "Category|Title" -> Template 对象，用于快速查找
global TemplateIndexByArrayIndex := Map()  ; ArrayIndex -> Template 对象，用于获取数组索引
global CategoryMapDirty := true  ; 标记分类映射是否需要重建（缓存机制）
global FunctionCategories := Map()  ; 功能分类定义 {ID: {Name, SortWeight}}
global SeriesCategories := Map()  ; 模板系列定义 {ID: {Name, SortWeight}}
global ExpandedState := Map()  ; 展开状态管理 {功能分类ID: {模板系列ID: 展开的模板ID}}
global CategoryExpandedState := Map()  ; 每个分类的展开状态 {CategoryName: TemplateKey}
global CurrentFunctionCategory := "Explain"  ; 当前选中的功能分类
global CurrentPromptFolder := ""  ; 当前查看的prompt文件夹（为空表示显示主文件夹列表）
global PromptManagerListView := 0  ; 模板管理器ListView控件
; 面板位置和屏幕配置
global PanelScreenIndex := 1  ; 屏幕索引（1为主屏幕）
global PanelPosition := "center"  ; 位置：center, top-left, top-right, bottom-left, bottom-right, custom
global FunctionPanelPos := "center"
global ConfigPanelPos := "center"
global ClipboardPanelPos := "center"
; 各面板的屏幕索引
global ConfigPanelScreenIndex := 1  ; 配置面板屏幕索引
global MsgBoxScreenIndex := 1  ; 弹窗屏幕索引
global VoiceInputScreenIndex := 1  ; 语音输入法提示屏幕索引
global CursorPanelScreenIndex := 1  ; cursor快捷弹出面板屏幕索引
global PanelX := -1  ; 自定义 X 坐标（-1 表示使用默认位置）
global PanelY := -1  ; 自定义 Y 坐标（-1 表示使用默认位置）
; 连续复制功能
global ClipboardHistory := []  ; 存储所有复制的内容（兼容旧版本，保留）
global ClipboardHistory_CtrlC := []  ; 存储 Ctrl+C 复制的内容
global ClipboardHistory_CapsLockC := []  ; 存储 CapsLock+C 复制的内容
global GuiID_ClipboardManager := 0  ; 剪贴板管理面板 GUI ID
global ClipboardCurrentTab := "CtrlC"  ; 当前显示的版块："CtrlC" 或 "CapsLockC"
global ClipboardCtrlCTab := 0  ; Ctrl+C Tab 控件引用
global ClipboardCapsLockCTab := 0  ; CapsLock+C Tab 控件引用
global LastSelectedIndex := 0  ; 最后选中的ListBox项索引，用于刷新后恢复
; 语音输入功能
global VoiceInputActive := false  ; 语音输入是否激活
global GuiID_VoiceInput := 0  ; 语音输入动画GUI ID
global GuiID_VoiceInputPanel := 0  ; 语音输入面板GUI ID
global VoiceInputContent := ""  ; 存储语音输入的内容
global VoiceInputMethod := ""  ; 当前使用的输入法类型：baidu, xunfei, auto
global VoiceInputPaused := false  ; 语音输入是否被暂停（按住CapsLock时）
global VoiceTitleText := 0  ; 语音输入动画标题文本控件
global VoiceHintText := 0  ; 语音输入动画提示文本控件
global VoiceAnimationText := 0  ; 语音输入/搜索动画文本控件
global VoiceInputStatusText := 0  ; 语音输入状态文本控件
global VoiceInputSendBtn := 0  ; 语音输入发送按钮
global VoiceInputPauseBtn := 0  ; 语音输入暂停/继续按钮
global VoiceSearchInputEdit := 0  ; 语音搜索输入框控件
global VoiceSearchEngineButtons := []  ; 搜索引擎按钮数组
global VoiceSearchInputLastEditTime := 0  ; 输入框最后编辑时间（用于检测用户是否正在输入）
; 语音搜索功能
global VoiceSearchActive := false  ; 语音搜索是否激活
global VoiceSearchContent := ""  ; 存储语音搜索的内容
global SearchEngine := "deepseek"  ; 默认搜索引擎：deepseek, yuanbao, doubao, zhipu, mita, wenxin, qianwen, kimi
global VoiceSearchSelecting := false  ; 是否正在选择搜索引擎
global VoiceSearchPanelVisible := false  ; 语音搜索面板是否显示
global VoiceSearchSelectedEngines := ["deepseek"]  ; 当前在语音搜索界面中选择的搜索引擎（支持多选）
global VoiceSearchCurrentCategory := "ai"  ; 当前选中的搜索引擎分类标签
global VoiceSearchCategoryTabs := []  ; 分类标签按钮数组
global VoiceSearchSelectedEnginesByCategory := Map()  ; 每个分类的搜索引擎选择状态（分类Key -> 引擎数组）
global AutoLoadSelectedText := false  ; 是否自动加载选中文本到输入框
global VoiceSearchAutoLoadSwitch := 0  ; 自动加载开关控件（语音搜索）
global VoiceInputAutoLoadSwitch := 0  ; 自动加载开关控件（语音输入）
global AutoUpdateVoiceInput := true  ; 是否自动更新语音输入内容到输入框
global AutoStart := false  ; 是否开启自启动
global VoiceSearchEnabledCategories := []  ; 启用的搜索标签列表
global VoiceSearchAutoUpdateSwitch := 0  ; 自动更新开关控件（语音搜索）
global VoiceInputActionSelectionVisible := false  ; 语音输入操作选择界面是否显示
; 多语言支持
global Language := "zh"  ; 语言设置：zh=中文, en=英文
global DefaultStartTab := "general"  ; 默认启动页面：general=通用, appearance=外观, prompts=提示词, hotkeys=快捷键, advanced=高级
; 快捷操作按钮（最多5个）
; 每个按钮配置格式：{Type: "Explain|Refactor|Optimize|Config", Hotkey: "e|r|o|q"}
global QuickActionButtons := [
    {Type: "Explain", Hotkey: "e"},
    {Type: "Refactor", Hotkey: "r"},
    {Type: "Optimize", Hotkey: "o"},
    {Type: "Config", Hotkey: "q"},
    {Type: "Explain", Hotkey: "e"}
]

; ===================== UI 颜色初始化（必须在脚本早期初始化）=====================
; 主题模式：dark（暗色，默认）或 light（亮色）
global ThemeMode := "dark"

; 暗色主题颜色
UI_Colors_Dark := {
    Background: "1e1e1e",
    Sidebar: "252526",
    Border: "3c3c3c", 
    Text: "cccccc",
    TextDim: "888888",
    InputBg: "3c3c3c",
    DDLBg: "2d2d30",
    DDLBorder: "3e3e42",
    DDLText: "cccccc",
    DDLHover: "37373d",
    BtnBg: "3c3c3c",
    BtnHover: "4c4c4c",
    BtnPrimary: "0078D4",
    BtnPrimaryHover: "1177bb",
    BtnDanger: "e81123",
    BtnDangerHover: "c50e1f",
    TabActive: "37373d",
    TitleBar: "252526"
}

; 亮色主题颜色
UI_Colors_Light := {
    Background: "ffffff",
    Sidebar: "f3f3f3",
    Border: "d0d0d0", 
    Text: "333333",
    TextDim: "666666",
    InputBg: "ffffff",
    DDLBg: "ffffff",
    DDLBorder: "d0d0d0",
    DDLText: "333333",
    DDLHover: "e8e8e8",
    BtnBg: "e8e8e8",
    BtnHover: "d0d0d0",
    BtnPrimary: "0078D4",
    BtnPrimaryHover: "1177bb",
    BtnDanger: "e81123",
    BtnDangerHover: "c50e1f",
    TabActive: "e8e8e8",
    TitleBar: "f3f3f3"
}

; 初始化UI颜色（默认暗色）
global UI_Colors := UI_Colors_Dark

; 应用主题
ApplyTheme(Mode) {
    global UI_Colors, ThemeMode, UI_Colors_Dark, UI_Colors_Light
    ThemeMode := Mode
    if (Mode = "light") {
        UI_Colors := UI_Colors_Light
    } else {
        UI_Colors := UI_Colors_Dark
    }
}

; ===================== 颜色混合辅助函数（模拟透明度效果）====================
BlendColor(Color1, Color2, Ratio) {
    ; 将十六进制颜色转换为 RGB（处理可能的格式）
    ; 确保颜色字符串长度为6
    if (StrLen(Color1) != 6) {
        Color1 := SubStr(Color1, -6)  ; 取最后6位
    }
    if (StrLen(Color2) != 6) {
        Color2 := SubStr(Color2, -6)  ; 取最后6位
    }
    
    ; 转换为整数
    R1 := Integer("0x" . SubStr(Color1, 1, 2))
    G1 := Integer("0x" . SubStr(Color1, 3, 2))
    B1 := Integer("0x" . SubStr(Color1, 5, 2))
    
    R2 := Integer("0x" . SubStr(Color2, 1, 2))
    G2 := Integer("0x" . SubStr(Color2, 3, 2))
    B2 := Integer("0x" . SubStr(Color2, 5, 2))
    
    ; 混合颜色
    R := Round(R1 + (R2 - R1) * Ratio)
    G := Round(G1 + (G2 - G1) * Ratio)
    B := Round(B1 + (B2 - B1) * Ratio)
    
    ; 限制范围
    R := (R < 0) ? 0 : ((R > 255) ? 255 : R)
    G := (G < 0) ? 0 : ((G > 255) ? 255 : G)
    B := (B < 0) ? 0 : ((B > 255) ? 255 : B)
    
    ; 转换回十六进制
    RHex := Format("{:02X}", R)
    GHex := Format("{:02X}", G)
    BHex := Format("{:02X}", B)
    
    return RHex . GHex . BHex
}

; ===================== 多语言支持 =====================
; 获取本地化文本
GetText(Key) {
    global Language
    static Texts := Map(
        "zh", Map(
            "app_name", "Cursor助手",
            "app_tip", "Cursor助手（长按CapsLock调出面板）",
            "panel_title", "Cursor 快捷操作",
            "config_title", "Cursor助手 - 配置面板",
            "clipboard_manager", "剪贴板管理",
            "explain_code", "解释代码 (E)",
            "refactor_code", "重构代码 (R)",
            "optimize_code", "优化代码 (O)",
            "open_config", "⚙️ 打开配置面板 (Q)",
            "split_hint", "按 {0} 分割 | 按 {1} 批量操作",
            "footer_hint", "按 ESC 关闭面板 | 按 Q 打开配置`n先选中代码再操作",
            "open_config_menu", "打开配置面板",
            "exit_menu", "退出工具",
            "copy_success", "已复制 ({0} 项)",
            "paste_success", "已粘贴到 Cursor",
            "clear_success", "已清空复制历史",
            "no_content", "未检测到新内容",
            "no_clipboard", "请先使用 CapsLock+C 复制内容",
            "clear_all", "清空全部",
            "clear_selection", "清空选择",
            "clear", "清空",
            "refresh", "刷新",
            "copy_selected", "复制选中",
            "delete_selected", "删除选中",
            "paste_to_cursor", "粘贴到 Cursor",
            "clipboard_hint", "双击项目可复制 | ESC 关闭",
            "clipboard_tab_ctrlc", "Ctrl+C",
            "clipboard_tab_capslockc", "CapsLock+C",
            "total_items", "共 {0} 项",
            "confirm_clear", "确定要清空所有剪贴板记录吗？",
            "cleared", "已清空所有记录",
            "copied", "已复制到剪贴板",
            "deleted", "已删除",
            "select_first", "请先选择要{0}的项目",
            "operation_failed", "操作失败，控件可能已关闭",
            "paste_failed", "粘贴失败",
            "cursor_not_running", "Cursor 未运行",
            "cursor_not_running_error", "Cursor 未运行且无法启动",
            "select_code_first", "请先选中要分割的代码",
            "split_marker_inserted", "已插入分割标记",
            "reset_default_success", "已重置为默认值！",
            "install_cursor_chinese", "安装 Cursor 中文版",
            "install_cursor_chinese_desc", "一键安装 Cursor 中文语言包",
            "install_cursor_chinese_guide", "安装步骤：`n`n1. 命令面板已自动打开，请等待选项显示`n2. 手动选择：Configure Display Language`n3. 点击：Install additional languages...`n4. 在扩展商店搜索：Chinese (Simplified) Language Pack`n5. 点击 Install 按钮安装`n6. 安装完成后重启 Cursor 生效",
            "install_cursor_chinese_starting", "命令面板已打开，请输入并选择 Configure Display Language，然后按照提示完成安装",
            "install_cursor_chinese_complete", "请按照以下步骤完成安装：`n`n1. 在命令面板中选择：Configure Display Language`n2. 点击：Install additional languages...`n3. 搜索：Chinese (Simplified) Language Pack`n4. 点击 Install 按钮`n5. 安装完成后重启 Cursor 生效",
            "config_saved", "配置已保存！快捷键已立即生效。",
            "ai_wait_time_error", "AI 响应等待时间必须是数字！",
            "split_hotkey_error", "分割快捷键必须是单个字符！",
            "batch_hotkey_error", "批量操作快捷键必须是单个字符！",
            "copy", "复制",
            "delete", "删除",
            "paste", "粘贴",
            "tip", "提示",
            "error", "错误",
            "confirm", "确认",
            "warning", "警告",
            "help_title", "使用说明",
            "language_setting", "语言设置",
            "language_chinese", "中文",
            "language_english", "English",
            "app_path", "应用程序路径",
            "cursor_path_hint", "提示：如果 Cursor 安装在非默认位置，请点击「浏览」按钮选择",
            "ai_response_time", "AI 响应等待时间",
            "ai_wait_hint", "建议：低配机 20000，高配机 10000",
            "prompt_config", "AI 提示词配置",
            "custom_hotkeys", "自定义快捷键",
            "single_char_hint", "（单个字符，默认: {0}）",
            "panel_display", "面板显示位置",
            "screen_detected", "显示屏幕 (检测到: {0}):",
            "screen", "屏幕 {0}",
            "tab_general", "通用",
            "tab_appearance", "外观",
            "tab_prompts", "提示词",
            "tab_hotkeys", "快捷键",
            "tab_advanced", "高级",
            "search_placeholder", "搜索设置...",
            "general_settings", "通用设置",
            "appearance_settings", "外观设置",
            "prompt_settings", "提示词设置",
            "hotkey_settings", "快捷键设置",
            "advanced_settings", "高级设置",
            "settings_basic", "📁 基础设置",
            "settings_performance", "⚡ 性能设置",
            "settings_prompts", "💬 提示词设置",
            "settings_hotkeys", "⌨️ 快捷键设置",
            "settings_panel", "🖥️ 面板位置设置",
            "cursor_path", "Cursor 路径:",
            "browse", "浏览...",
            "capslock_hold_time", "CapsLock 长按时间 (秒):",
            "capslock_hold_time_hint", "设置长按 CapsLock 键多少秒后弹出快捷操作面板，范围：0.1-5.0 秒，默认：0.5 秒",
            "capslock_hold_time_error", "CapsLock 长按时间必须在 0.1 到 5.0 秒之间",
            "ai_wait_time", "AI 响应等待时间 (毫秒):",
            "explain_prompt", "解释代码提示词:",
            "refactor_prompt", "重构代码提示词:",
            "optimize_prompt", "优化代码提示词:",
            "split_hotkey", "分割快捷键:",
            "batch_hotkey", "批量操作快捷键:",
            "hotkey_esc", "关闭面板 (ESC):",
            "hotkey_esc_desc", "当面板显示时，按此键可关闭面板。",
            "hotkey_c", "连续复制 (C):",
            "hotkey_c_desc", "选中文本后按此键，可将内容添加到剪贴板历史记录中，支持连续复制多段内容。",
            "hotkey_v", "合并粘贴 (V):",
            "hotkey_v_desc", "按此键可将所有已复制的内容合并后粘贴到 Cursor 中。",
            "hotkey_x", "剪贴板管理 (X):",
            "hotkey_x_desc", "按此键可打开剪贴板管理面板，查看和管理所有已复制的内容。",
            "hotkey_e", "解释代码 (E):",
            "hotkey_e_desc", "在 Cursor 中选中代码后按此键，AI 会自动解释代码的核心逻辑和功能。",
            "hotkey_r", "重构代码 (R):",
            "hotkey_r_desc", "在 Cursor 中选中代码后按此键，AI 会自动重构代码，优化代码结构。",
            "hotkey_o", "优化代码 (O):",
            "hotkey_o_desc", "在 Cursor 中选中代码后按此键，AI 会分析并优化代码性能。",
            "hotkey_q", "打开配置 (Q):",
            "hotkey_q_desc", "按此键可打开配置面板，进行各种设置。",
            "hotkey_z", "语音输入 (Z):",
            "hotkey_z_desc", "按此键可启动或停止语音输入功能，支持百度输入法和讯飞输入法。",
            "hotkey_f", "语音搜索 (F):",
            "hotkey_f_desc", "按此键可启动语音搜索功能，输入语音后自动打开浏览器搜索。",
            "hotkey_s", "分割代码 (S):",
            "hotkey_s_desc", "在 Cursor 中选中代码后，长按 CapsLock 调出面板，按此键可在代码中插入分割标记，用于标记多个代码片段以便批量处理。",
            "hotkey_b", "批量操作 (B):",
            "hotkey_b_desc", "在 Cursor 中选中代码后，长按 CapsLock 调出面板，按此键可对已标记的所有代码片段执行批量操作（解释/重构/优化）。",
            "hotkey_p", "区域截图 (P):",
            "hotkey_p_desc", "按此键可启动区域截图功能，选择截图区域后，会弹出悬浮面板，点击面板中的粘贴按钮即可将截图粘贴到 Cursor 输入框。",
            "screenshot_button_text", "📷 粘贴截图",
            "screenshot_paste_success", "截图已粘贴到输入框",
            "screenshot_button_tip", "点击此按钮将截图粘贴到 Cursor 输入框",
            "hotkey_single_char_hint", "（单个字符，默认: {0}）",
            "hotkey_esc_hint", "（特殊键，默认: Esc）",
            "display_screen", "显示屏幕:",
            "reset_default", "重置默认",
            "save_config", "保存配置",
            "cancel", "取消",
            "help", "使用说明",
            "pos_center", "居中",
            "pos_top_left", "左上角",
            "pos_top_right", "右上角",
            "pos_bottom_left", "左下角",
            "pos_bottom_right", "右下角",
            "panel_pos_func", "功能面板位置",
            "panel_pos_config", "设置面板位置",
            "panel_pos_clip", "剪贴板面板位置",
            "theme_mode", "主题模式:",
            "theme_light", "亮色模式",
            "theme_dark", "暗色模式",
            "config_panel_screen", "配置面板显示器:",
            "msgbox_screen", "弹窗显示器:",
            "voice_input_screen", "语音输入法提示显示器:",
            "cursor_panel_screen", "Cursor快捷弹出面板显示器:",
            "config_manage", "配置管理:",
            "default_prompt_explain", "解释这段代码的核心逻辑、输入输出、关键函数作用，用新手能懂的语言，标注易错点",
            "default_prompt_refactor", "重构这段代码，遵循PEP8/行业规范，简化冗余逻辑，添加中文注释，保持功能不变",
            "default_prompt_optimize", "分析这段代码的性能瓶颈（时间/空间复杂度），给出优化方案+对比说明，保留原逻辑可读性",
            "export_config", "导出配置",
            "export_config_desc", "将当前配置保存为INI文件",
            "import_config", "导入配置",
            "import_config_desc", "从INI文件加载配置",
            "export_clipboard", "导出剪贴板",
            "import_clipboard", "导入剪贴板",
            "export_success", "导出成功",
            "import_success", "导入成功",
            "import_failed", "导入失败",
            "confirm_reset", "确定要重置为默认设置吗？这将清除所有自定义配置。",
            "reset_default_desc", "将所有设置重置为默认值",
            "save_config_desc", "保存当前配置并关闭面板",
            "cancel_desc", "关闭配置面板，不保存更改",
            "config_saved", "配置已保存！",
            "voice_input_starting", "正在启动语音输入...",
            "voice_input_active", "🎤 语音输入中",
            "voice_input_paused", "⏸️ 语音输入已暂停",
            "voice_input_hint", "正在录入，请说话...",
            "voice_input_stopping", "正在结束语音输入...",
            "voice_input_sent", "语音输入已发送到 Cursor",
            "voice_input_failed", "语音输入失败",
            "voice_input_no_content", "未检测到语音输入内容",
            "pause", "暂停",
            "resume", "继续",
            "voice_input_detected_baidu", "检测到百度输入法",
            "voice_input_detected_xunfei", "检测到讯飞输入法",
            "voice_input_auto_detect", "自动检测输入法",
            "voice_search_active", "🎤 语音搜索中",
            "voice_search_hint", "正在录入，请说话...",
            "voice_search_sent", "正在打开搜索...",
            "voice_search_failed", "语音搜索失败",
            "voice_search_no_content", "未检测到语音搜索内容",
            "voice_search_title", "语音搜索",
            "voice_search_input_label", "输入内容:",
            "voice_search_button", "搜索",
            "voice_input_start", "○ 启动语音输入",
            "voice_input_active_text", "✓ 语音输入中",
            "auto_load_selected_text", "自动加载选中文本:",
            "auto_update_voice_input", "自动更新语音输入:",
            "auto_start", "开机自启动",
            "auto_start_desc", "开启后，软件将在Windows启动时自动运行",
            "switch_on", "✓ 已开启",
            "switch_off", "○ 已关闭",
            "select_search_engine", "选择搜索引擎:",
            "select_search_engine_title", "选择搜索引擎",
            "select_action", "选择操作",
            "voice_input_content", "语音输入内容:",
            "send_to_cursor", "发送到 Cursor",
            "no_search_engine_selected", "请至少选择一个搜索引擎",
            "search_engines_opened", "已打开 {0} 个搜索引擎",
            "tip", "提示",
            "search_engine_setting", "搜索引擎设置",
            "search_engine_label", "默认搜索引擎:",
            "search_engine_deepseek", "DeepSeek",
            "search_engine_yuanbao", "元宝",
            "search_engine_doubao", "豆包",
            "search_engine_zhipu", "智谱",
            "search_engine_mita", "秘塔",
            "search_engine_wenxin", "文心一言",
            "search_engine_qianwen", "千问",
            "search_engine_kimi", "Kimi",
            "search_engine_perplexity", "Perplexity",
            "search_engine_copilot", "Copilot",
            "search_engine_chatgpt", "ChatGPT",
            "search_engine_grok", "Grok",
            "search_engine_you", "You",
            "search_engine_claude", "Claude",
            "search_engine_monica", "Monica",
            "search_engine_webpilot", "WebPilot",
            ; 学术类搜索引擎
            "search_engine_zhihu", "知乎",
            "search_engine_wechat_article", "微信文章搜索",
            "search_engine_cainiao", "菜鸟编程",
            "search_engine_gitee", "Gitee",
            "search_engine_pubscholar", "PubScholar",
            "search_engine_semantic", "Semantic Scholar",
            "search_engine_baidu_academic", "百度学术",
            "search_engine_bing_academic", "微软必应学术",
            "search_engine_csdn", "CSDN搜索",
            "search_engine_national_library", "国家图书馆",
            "search_engine_chaoxing", "超星发现",
            "search_engine_cnki", "中国知网",
            "search_engine_wechat_reading", "微信读书",
            "search_engine_dada", "哒哒文库",
            "search_engine_patent", "专利检索",
            "search_engine_ip_office", "国家知识产权局",
            "search_engine_dedao", "得到",
            "search_engine_pkmer", "Pkmer知识社区",
            ; 百度类搜索引擎
            "search_engine_baidu", "百度",
            "search_engine_baidu_title", "限定标题搜索",
            "search_engine_baidu_hanyu", "百度汉语",
            "search_engine_baidu_wenku", "百度文库",
            "search_engine_baidu_map", "百度地图",
            "search_engine_baidu_pdf", "限定搜PDF",
            "search_engine_baidu_doc", "限定搜DOC",
            "search_engine_baidu_ppt", "限定搜PPT",
            "search_engine_baidu_xls", "限定搜XLS",
            ; 图片类搜索引擎
            "search_engine_image_aggregate", "搜图聚合搜索",
            "search_engine_iconfont", "搜矢量图标库",
            "search_engine_wenxin_image", "文心一言文生图",
            "search_engine_tiangong_image", "天工文生图",
            "search_engine_yuanbao_image", "元宝AI画图",
            "search_engine_tongyi_image", "通义万相文字作画",
            "search_engine_zhipu_image", "智谱清言AI画图",
            "search_engine_miaohua", "秒画",
            "search_engine_keling", "可灵",
            "search_engine_jimmeng", "即梦AI文生画",
            "search_engine_baidu_image", "百度图库",
            "search_engine_shetu", "摄图网",
            "search_engine_ai_image_lib", "AI图库网站",
            "search_engine_huaban", "花瓣网",
            "search_engine_zcool", "站酷",
            "search_engine_uisdc", "优设网",
            "search_engine_nipic", "昵图网",
            "search_engine_qianku", "千库网",
            "search_engine_qiantu", "千图网",
            "search_engine_zhongtu", "众图网",
            "search_engine_miyuan", "觅元素",
            "search_engine_mizhi", "觅知网",
            "search_engine_icons", "ICONS",
            "search_engine_tuxing", "图行天下",
            "search_engine_xiangsheji", "享设计",
            "search_engine_bing_image", "必应图片",
            "search_engine_google_image", "谷歌图片",
            "search_engine_weibo_image", "微博图片",
            "search_engine_sogou_image", "搜狗图片",
            "search_engine_haosou_image", "好搜图片",
            ; 音频类搜索引擎
            "search_engine_netease_music", "网易云音乐",
            "search_engine_tiangong_music", "天工AI音乐",
            "search_engine_text_to_speech", "文本转语音",
            "search_engine_speech_to_text", "语音转文本",
            "search_engine_shetu_music", "摄图背景音乐",
            "search_engine_qq_music", "QQ音乐",
            "search_engine_kuwo", "酷我音乐",
            "search_engine_kugou", "酷狗音乐",
            "search_engine_qianqian", "千千音乐",
            "search_engine_ximalaya", "喜马拉雅",
            "search_engine_5sing", "5sing原创音乐",
            "search_engine_lossless", "无损音乐吧",
            "search_engine_erling", "耳聆-音效",
            ; 视频类搜索引擎
            "search_engine_douyin", "抖音",
            "search_engine_yuewen", "悦问",
            "search_engine_qingying", "清影-AI生视频",
            "search_engine_tongyi_video", "通义万相视频生成",
            "search_engine_jimmeng_video", "即梦AI视频生成",
            "search_engine_youtube", "YouTube",
            "search_engine_find_lines", "找台词",
            "search_engine_shetu_video", "摄图视频",
            "search_engine_yandex", "Yandex",
            "search_engine_pexels", "Pexels",
            "search_engine_youku", "优酷",
            "search_engine_chanjing", "蝉镜",
            "search_engine_duojia", "度加创作",
            "search_engine_tencent_zhiying", "腾讯智影",
            "search_engine_wansheng", "万兴AI剪辑",
            "search_engine_tencent_video", "腾讯视频",
            "search_engine_iqiyi", "爱奇艺",
            ; 图书类搜索引擎
            "search_engine_duokan", "多看阅读",
            "search_engine_turing", "图灵社区",
            "search_engine_panda_book", "熊猫搜书",
            "search_engine_douban_book", "豆瓣读书",
            "search_engine_lifelong_edu", "终身教育平台",
            "search_engine_verypan", "verypan搜",
            "search_engine_zouddupai", "走读派导航网",
            "search_engine_gd_library", "广东省立中山图书馆",
            "search_engine_pansou", "盘搜",
            "search_engine_zsxq", "知识星球",
            "search_engine_jiumo", "鸠摩搜书",
            "search_engine_weibo_book", "微博",
            ; 比价类搜索引擎
            "search_engine_jd", "京东",
            "search_engine_baidu_procure", "百度爱采购",
            "search_engine_dangdang", "当当",
            "search_engine_1688", "1688",
            "search_engine_taobao", "淘宝",
            "search_engine_tmall", "天猫",
            "search_engine_pinduoduo", "拼多多",
            "search_engine_xianyu", "闲鱼",
            "search_engine_smzdm", "什么值得买",
            "search_engine_yanxuan", "网易严选",
            "search_engine_gaide", "盖得排行",
            "search_engine_suning", "苏宁易购",
            "search_engine_ebay", "eBay",
            "search_engine_amazon", "亚马逊",
            ; 医疗类搜索引擎
            "search_engine_dxy", "丁香园",
            "search_engine_left_doctor", "左手医生AI",
            "search_engine_medisearch", "MediSearch",
            "search_engine_merck", "默沙东诊疗手册",
            "search_engine_aplus_medical", "A+医学百科",
            "search_engine_medical_baike", "医学百科",
            "search_engine_weiyi", "微医",
            "search_engine_medlive", "医脉通",
            "search_engine_xywy", "寻医问药",
            ; 网盘类搜索引擎
            "search_engine_pansoso", "盘搜搜",
            "search_engine_panso", "盘搜Pro",
            "search_engine_xiaomapan", "小码盘",
            "search_engine_dashengpan", "大圣盘",
            "search_engine_miaosou", "秒搜",
            "search_category_ai", "AI",
            "search_category_academic", "学术",
            "search_category_baidu", "百度",
            "search_category_image", "图片",
            "search_category_audio", "音频",
            "search_category_video", "视频",
            "search_category_book", "图书",
            "search_category_price", "比价",
            "search_category_medical", "医疗",
            "search_category_cloud", "网盘",
            "search_category_config", "搜索标签",
            "search_category_config_desc", "配置语音搜索面板中显示的标签，只有勾选的标签才会显示",
            "quick_action_config", "快捷操作按钮",
            "quick_action_config_desc", "配置快捷操作面板中的按钮顺序和功能按键（最多5个）",
            "quick_action_button", "按钮 {0}",
            "quick_action_type", "功能类型:",
            "quick_action_hotkey", "快捷键:",
            "quick_action_move_up", "上移",
            "quick_action_move_down", "下移",
            "quick_action_add", "添加按钮",
            "quick_action_remove", "删除",
            "quick_action_type_explain", "解释代码",
            "quick_action_type_refactor", "重构代码",
            "quick_action_type_optimize", "优化代码",
            "quick_action_type_config", "打开配置",
            "quick_action_type_copy", "连续复制",
            "quick_action_type_paste", "合并粘贴",
            "quick_action_type_clipboard", "剪贴板管理",
            "quick_action_type_voice", "语音输入",
            "quick_action_type_split", "分割代码",
            "quick_action_type_batch", "批量操作",
            "quick_action_type_command_palette", "命令面板",
            "quick_action_type_terminal", "新建终端",
            "quick_action_type_global_search", "全局搜索",
            "quick_action_type_explorer", "资源管理器",
            "quick_action_type_source_control", "源代码管理",
            "quick_action_type_extensions", "扩展面板",
            "quick_action_type_browser", "打开浏览器",
            "quick_action_type_settings", "设置面板",
            "quick_action_type_cursor_settings", "Cursor 设置",
            "quick_action_desc_command_palette", "打开命令面板（Ctrl + Shift + P）",
            "quick_action_desc_terminal", "新建终端（Ctrl + Shift + `）",
            "quick_action_desc_global_search", "全局搜索（Ctrl + Shift + F）",
            "quick_action_desc_explorer", "显示资源管理器（Ctrl + Shift + E）",
            "quick_action_desc_source_control", "显示源代码管理（Ctrl + Shift + G）",
            "quick_action_desc_extensions", "显示扩展面板（Ctrl + Shift + X）",
            "quick_action_desc_browser", "打开浏览器（Ctrl + Shift + B）",
            "quick_action_desc_settings", "显示设置面板（Ctrl + Shift + J）",
            "quick_action_desc_cursor_settings", "显示 Cursor 设置面板（Ctrl + ,）",
            "quick_action_max_reached", "最多只能添加5个按钮",
            "quick_action_min_reached", "至少需要保留1个按钮",
            ; Cursor规则相关文本
            "hotkey_main_tab_settings", "快捷键设置",
            "hotkey_main_tab_rules", "Cursor规则",
            "cursor_rules_title", "Cursor 规则配置",
            "cursor_rules_intro", "根据您开发的程序类型，让 AI 更好地理解您的项目需求。💰 省钱：减少无效的 AI 对话，提高效率`n🎯 精准：AI 更准确理解项目需求`n🛡️ 避坑：避免常见错误和代码问题`n📐 垂直：针对特定领域优化建议`n⚡ 效率：快速生成符合规范的代码",
            "cursor_rules_location_title", "📋 复制位置",
            "cursor_rules_location_desc", "在 Cursor 中，按 Ctrl+Shift+P 打开命令面板，输入 'rules' 或 'cursor rules'，选择 'Open Cursor Rules' 打开 .cursorrules 文件，将规则内容粘贴到该文件中。",
            "cursor_rules_usage_title", "💡 使用方法",
            "cursor_rules_usage_desc", "1. 选择下方对应的开发类型标签`n2. 点击「复制规则」按钮`n3. 在 Cursor 中打开 .cursorrules 文件`n4. 粘贴规则内容并保存`n5. 重启 Cursor 使规则生效",
            "cursor_rules_copy_btn", "复制规则",
            "cursor_rules_copied", "规则已复制到剪贴板！",
            "cursor_rules_subtab_general", "通用规则",
            "cursor_rules_subtab_web", "网页开发",
            "cursor_rules_subtab_miniprogram", "小程序",
            "cursor_rules_subtab_plugin", "插件",
            "cursor_rules_subtab_android", "安卓App",
            "cursor_rules_subtab_ios", "iOS App",
            "cursor_rules_subtab_python", "Python",
            "cursor_rules_subtab_backend", "后端服务",
            "cursor_rules_content_placeholder", "规则内容待定，请稍后更新..."
        ),
        "en", Map(
            "app_name", "Cursor Assistant",
            "app_tip", "Cursor Assistant (Hold CapsLock to open panel)",
            "panel_title", "Cursor Quick Actions",
            "config_title", "Cursor Assistant - Settings",
            "clipboard_manager", "Clipboard Manager",
            "explain_code", "Explain Code (E)",
            "refactor_code", "Refactor Code (R)",
            "optimize_code", "Optimize Code (O)",
            "open_config", "⚙️ Open Settings (Q)",
            "split_hint", "Press {0} to split | Press {1} for batch",
            "footer_hint", "Press ESC to close | Press Q for settings`nSelect code first",
            "open_config_menu", "Open Settings",
            "exit_menu", "Exit",
            "copy_success", "Copied ({0} items)",
            "paste_success", "Pasted to Cursor",
            "clear_success", "Clipboard history cleared",
            "no_content", "No new content detected",
            "no_clipboard", "Please use CapsLock+C to copy content first",
            "clear_all", "Clear All",
            "clear_selection", "Clear Selection",
            "clear", "Clear",
            "refresh", "Refresh",
            "copy_selected", "Copy Selected",
            "delete_selected", "Delete Selected",
            "paste_to_cursor", "Paste to Cursor",
            "clipboard_hint", "Double-click to copy | ESC to close",
            "clipboard_tab_ctrlc", "Ctrl+C",
            "clipboard_tab_capslockc", "CapsLock+C",
            "total_items", "Total {0} items",
            "confirm_clear", "Are you sure you want to clear all clipboard records?",
            "cleared", "All records cleared",
            "copied", "Copied to clipboard",
            "deleted", "Deleted",
            "select_first", "Please select an item to {0} first",
            "operation_failed", "Operation failed, control may be closed",
            "paste_failed", "Paste failed",
            "cursor_not_running", "Cursor is not running",
            "cursor_not_running_error", "Cursor is not running and cannot be started",
            "select_code_first", "Please select code to split first",
            "split_marker_inserted", "Split marker inserted",
            "reset_default_success", "Reset to default values!",
            "install_cursor_chinese", "Install Cursor Chinese",
            "install_cursor_chinese_desc", "One-click install Cursor Chinese language pack",
            "install_cursor_chinese_guide", "Installation steps:`n`n1. Command palette will open automatically, please wait for options to appear`n2. Manually select: Configure Display Language`n3. Click: Install additional languages...`n4. Search in extension store: Chinese (Simplified) Language Pack`n5. Click Install button`n6. Restart Cursor after installation to apply",
            "install_cursor_chinese_starting", "Command palette opened, please type and select Configure Display Language, then follow the prompts to complete installation",
            "install_cursor_chinese_complete", "Please complete the installation following these steps:`n`n1. Select in command palette: Configure Display Language`n2. Click: Install additional languages...`n3. Search: Chinese (Simplified) Language Pack`n4. Click Install button`n5. Restart Cursor after installation to apply",
            "config_saved", "Settings saved!`n`nNote: If panel is showing, close and reopen to apply new settings.",
            "ai_wait_time_error", "AI response wait time must be a number!",
            "split_hotkey_error", "Split hotkey must be a single character!",
            "batch_hotkey_error", "Batch hotkey must be a single character!",
            "copy", "copy",
            "delete", "delete",
            "paste", "paste",
            "tip", "Tip",
            "error", "Error",
            "confirm", "Confirm",
            "warning", "Warning",
            "help_title", "Help",
            "language_setting", "Language",
            "language_chinese", "中文",
            "language_english", "English",
            "app_path", "Application Path",
            "cursor_path_hint", "Tip: If Cursor is installed in a non-default location, click 'Browse' to select",
            "ai_response_time", "AI Response Wait Time",
            "ai_wait_hint", "Recommendation: Low-end PC 20000, High-end PC 10000",
            "prompt_config", "AI Prompt Configuration",
            "custom_hotkeys", "Custom Hotkeys",
            "single_char_hint", "(Single character, default: {0})",
            "panel_display", "Panel Display Position",
            "screen_detected", "Display Screen (Detected: {0}):",
            "screen", "Screen {0}",
            "tab_general", "General",
            "tab_appearance", "Appearance",
            "tab_prompts", "Prompts",
            "tab_hotkeys", "Hotkeys",
            "tab_advanced", "Advanced",
            "search_placeholder", "Search settings...",
            "general_settings", "General Settings",
            "appearance_settings", "Appearance Settings",
            "prompt_settings", "Prompt Settings",
            "hotkey_settings", "Hotkey Settings",
            "advanced_settings", "Advanced Settings",
            "settings_basic", "📁 Basic Settings",
            "settings_performance", "⚡ Performance Settings",
            "settings_prompts", "💬 Prompt Settings",
            "settings_hotkeys", "⌨️ Hotkey Settings",
            "settings_panel", "🖥️ Panel Position Settings",
            "cursor_path", "Cursor Path:",
            "browse", "Browse...",
            "capslock_hold_time", "CapsLock Hold Time (seconds):",
            "capslock_hold_time_hint", "Set how many seconds to hold CapsLock before opening the quick action panel. Range: 0.1-5.0 seconds, Default: 0.5 seconds",
            "capslock_hold_time_error", "CapsLock hold time must be between 0.1 and 5.0 seconds",
            "ai_wait_time", "AI Response Wait Time (ms):",
            "explain_prompt", "Explain Code Prompt:",
            "refactor_prompt", "Refactor Code Prompt:",
            "optimize_prompt", "Optimize Code Prompt:",
            "split_hotkey", "Split Hotkey:",
            "batch_hotkey", "Batch Hotkey:",
            "hotkey_esc", "Close Panel (ESC):",
            "hotkey_esc_desc", "Press this key to close the panel when it is displayed.",
            "hotkey_c", "Continuous Copy (C):",
            "hotkey_c_desc", "After selecting text, press this key to add content to clipboard history, supporting continuous copying of multiple segments.",
            "hotkey_v", "Merge Paste (V):",
            "hotkey_v_desc", "Press this key to merge all copied content and paste it into Cursor.",
            "hotkey_x", "Clipboard Manager (X):",
            "hotkey_x_desc", "Press this key to open the clipboard manager panel to view and manage all copied content.",
            "hotkey_e", "Explain Code (E):",
            "hotkey_e_desc", "After selecting code in Cursor, press this key and AI will automatically explain the core logic and functionality of the code.",
            "hotkey_r", "Refactor Code (R):",
            "hotkey_r_desc", "After selecting code in Cursor, press this key and AI will automatically refactor the code and optimize its structure.",
            "hotkey_o", "Optimize Code (O):",
            "hotkey_o_desc", "After selecting code in Cursor, press this key and AI will analyze and optimize code performance.",
            "hotkey_q", "Open Config (Q):",
            "hotkey_q_desc", "Press this key to open the configuration panel for various settings.",
            "hotkey_z", "Voice Input (Z):",
            "hotkey_z_desc", "Press this key to start or stop voice input, supporting Baidu Input and Xunfei Input.",
            "hotkey_f", "Voice Search (F):",
            "hotkey_f_desc", "Press this key to start voice search, automatically open browser search after voice input.",
            "hotkey_s", "Split Code (S):",
            "hotkey_s_desc", "When the panel is displayed, press this key to insert split markers in the code for batch processing.",
            "hotkey_b", "Batch Operation (B):",
            "hotkey_b_desc", "When the panel is displayed, press this key to execute batch operations.",
            "hotkey_p", "Screenshot (P):",
            "hotkey_p_desc", "Press this key to start area screenshot. After selecting the area, a floating panel will appear. Click the paste button in the panel to paste the screenshot into Cursor's input box.",
            "screenshot_button_text", "📷 Paste Screenshot",
            "screenshot_paste_success", "Screenshot pasted to input box",
            "screenshot_button_tip", "Click this button to paste screenshot to Cursor input box",
            "hotkey_single_char_hint", "(Single character, default: {0})",
            "hotkey_esc_hint", "(Special key, default: Esc)",
            "display_screen", "Display Screen:",
            "reset_default", "Reset Default",
            "save_config", "Save Settings",
            "cancel", "Cancel",
            "help", "Help",
            "pos_center", "Center",
            "pos_top_left", "Top Left",
            "pos_top_right", "Top Right",
            "pos_bottom_left", "Bottom Left",
            "pos_bottom_right", "Bottom Right",
            "panel_pos_func", "Function Panel Position",
            "panel_pos_config", "Settings Panel Position",
            "panel_pos_clip", "Clipboard Panel Position",
            "theme_mode", "Theme Mode:",
            "theme_light", "Light Mode",
            "theme_dark", "Dark Mode",
            "config_panel_screen", "Config Panel Display:",
            "msgbox_screen", "Message Box Display:",
            "voice_input_screen", "Voice Input Prompt Display:",
            "cursor_panel_screen", "Cursor Quick Panel Display:",
            "config_manage", "Config Management:",
            "default_prompt_explain", "Explain the core logic, inputs/outputs, and key functions of this code in simple terms. Highlight potential pitfalls.",
            "default_prompt_refactor", "Refactor this code following PEP8/best practices. Simplify redundant logic, add comments, and keep functionality unchanged.",
            "default_prompt_optimize", "Analyze performance bottlenecks (time/space complexity). Provide optimization solutions with comparison. Keep original logic readable.",
            "close_button", "Close",
            "close_button_tip", "Close Panel",
            "export_config", "Export Config",
            "export_config_desc", "Save current configuration as INI file",
            "import_config", "Import Config",
            "import_config_desc", "Load configuration from INI file",
            "export_clipboard", "Export Clipboard",
            "import_clipboard", "Import Clipboard",
            "export_success", "Export Successful",
            "import_success", "Import Successful",
            "import_failed", "Import Failed",
            "confirm_reset", "Are you sure you want to reset to default settings? This will clear all custom configurations.",
            "reset_default_desc", "Reset all settings to default values",
            "save_config_desc", "Save current configuration and close panel",
            "cancel_desc", "Close configuration panel without saving changes",
            "config_saved", "Configuration Saved! Hotkeys are now active.",
            "voice_input_starting", "Starting voice input...",
            "voice_input_active", "🎤 Voice Input Active",
            "voice_input_paused", "⏸️ Voice Input Paused",
            "voice_input_hint", "Recording, please speak...",
            "voice_input_stopping", "Stopping voice input...",
            "voice_input_sent", "Voice input sent to Cursor",
            "voice_input_failed", "Voice input failed",
            "voice_input_no_content", "No voice input content detected",
            "pause", "Pause",
            "resume", "Resume",
            "voice_input_detected_baidu", "Baidu IME detected",
            "voice_input_detected_xunfei", "Xunfei IME detected",
            "voice_input_auto_detect", "Auto detect IME",
            "voice_search_active", "🎤 Voice Search Active",
            "voice_search_hint", "Recording, please speak...",
            "voice_search_sent", "Opening search...",
            "voice_search_failed", "Voice search failed",
            "voice_search_no_content", "No voice search content detected",
            "voice_search_title", "Voice Search",
            "voice_search_input_label", "Input Content:",
            "voice_search_button", "Search",
            "voice_input_start", "○ Start Voice Input",
            "voice_input_active_text", "✓ Voice Input Active",
            "auto_load_selected_text", "Auto Load Selected Text:",
            "auto_update_voice_input", "Auto Update Voice Input:",
            "auto_start", "Auto Start on Boot",
            "auto_start_desc", "Enable to automatically start the software when Windows starts",
            "switch_on", "✓ On",
            "switch_off", "○ Off",
            "select_search_engine", "Select Search Engine:",
            "select_search_engine_title", "Select Search Engine",
            "select_action", "Select Action",
            "voice_input_content", "Voice Input Content:",
            "send_to_cursor", "Send to Cursor",
            "no_search_engine_selected", "Please select at least one search engine",
            "search_engines_opened", "{0} search engines opened",
            "tip", "Tip",
            "search_engine_setting", "Search Engine Settings",
            "search_engine_label", "Default Search Engine:",
            "search_engine_deepseek", "DeepSeek",
            "search_engine_yuanbao", "Yuanbao",
            "search_engine_doubao", "Doubao",
            "search_engine_zhipu", "Zhipu",
            "search_engine_mita", "Mita",
            "search_engine_wenxin", "Wenxin Yiyan",
            "search_engine_qianwen", "Qianwen",
            "search_engine_kimi", "Kimi",
            "search_engine_perplexity", "Perplexity",
            "search_engine_copilot", "Copilot",
            "search_engine_chatgpt", "ChatGPT",
            "search_engine_grok", "Grok",
            "search_engine_you", "You",
            "search_engine_claude", "Claude",
            "search_engine_monica", "Monica",
            "search_engine_webpilot", "WebPilot",
            ; 学术类搜索引擎
            "search_engine_zhihu", "Zhihu",
            "search_engine_wechat_article", "WeChat Article",
            "search_engine_cainiao", "Cainiao Programming",
            "search_engine_gitee", "Gitee",
            "search_engine_pubscholar", "PubScholar",
            "search_engine_semantic", "Semantic Scholar",
            "search_engine_baidu_academic", "Baidu Academic",
            "search_engine_bing_academic", "Bing Academic",
            "search_engine_csdn", "CSDN Search",
            "search_engine_national_library", "National Library",
            "search_engine_chaoxing", "Chaoxing Discovery",
            "search_engine_cnki", "CNKI",
            "search_engine_wechat_reading", "WeChat Reading",
            "search_engine_dada", "Dada Wenku",
            "search_engine_patent", "Patent Search",
            "search_engine_ip_office", "IP Office",
            "search_engine_dedao", "Dedao",
            "search_engine_pkmer", "Pkmer",
            ; 百度类搜索引擎
            "search_engine_baidu", "Baidu",
            "search_engine_baidu_title", "Title Search",
            "search_engine_baidu_hanyu", "Baidu Hanyu",
            "search_engine_baidu_wenku", "Baidu Wenku",
            "search_engine_baidu_map", "Baidu Map",
            "search_engine_baidu_pdf", "PDF Search",
            "search_engine_baidu_doc", "DOC Search",
            "search_engine_baidu_ppt", "PPT Search",
            "search_engine_baidu_xls", "XLS Search",
            ; 图片类搜索引擎
            "search_engine_image_aggregate", "Image Aggregate",
            "search_engine_iconfont", "Icon Font",
            "search_engine_wenxin_image", "Wenxin Image",
            "search_engine_tiangong_image", "Tiangong Image",
            "search_engine_yuanbao_image", "Yuanbao Image",
            "search_engine_tongyi_image", "Tongyi Image",
            "search_engine_zhipu_image", "Zhipu Image",
            "search_engine_miaohua", "Miaohua",
            "search_engine_keling", "Keling",
            "search_engine_jimmeng", "Jimmeng",
            "search_engine_baidu_image", "Baidu Image",
            "search_engine_shetu", "Shetu",
            "search_engine_ai_image_lib", "AI Image Library",
            "search_engine_huaban", "Huaban",
            "search_engine_zcool", "Zcool",
            "search_engine_uisdc", "UISDC",
            "search_engine_nipic", "Nipic",
            "search_engine_qianku", "Qianku",
            "search_engine_qiantu", "Qiantu",
            "search_engine_zhongtu", "Zhongtu",
            "search_engine_miyuan", "Miyuan",
            "search_engine_mizhi", "Mizhi",
            "search_engine_icons", "ICONS",
            "search_engine_tuxing", "Tuxing",
            "search_engine_xiangsheji", "Xiangsheji",
            "search_engine_bing_image", "Bing Image",
            "search_engine_google_image", "Google Image",
            "search_engine_weibo_image", "Weibo Image",
            "search_engine_sogou_image", "Sogou Image",
            "search_engine_haosou_image", "Haosou Image",
            ; 音频类搜索引擎
            "search_engine_netease_music", "NetEase Music",
            "search_engine_tiangong_music", "Tiangong Music",
            "search_engine_text_to_speech", "Text to Speech",
            "search_engine_speech_to_text", "Speech to Text",
            "search_engine_shetu_music", "Shetu Music",
            "search_engine_qq_music", "QQ Music",
            "search_engine_kuwo", "Kuwo",
            "search_engine_kugou", "Kugou",
            "search_engine_qianqian", "Qianqian",
            "search_engine_ximalaya", "Ximalaya",
            "search_engine_5sing", "5sing",
            "search_engine_lossless", "Lossless Music",
            "search_engine_erling", "Erling",
            ; 视频类搜索引擎
            "search_engine_douyin", "Douyin",
            "search_engine_yuewen", "Yuewen",
            "search_engine_qingying", "Qingying",
            "search_engine_tongyi_video", "Tongyi Video",
            "search_engine_jimmeng_video", "Jimmeng Video",
            "search_engine_youtube", "YouTube",
            "search_engine_find_lines", "Find Lines",
            "search_engine_shetu_video", "Shetu Video",
            "search_engine_yandex", "Yandex",
            "search_engine_pexels", "Pexels",
            "search_engine_youku", "Youku",
            "search_engine_chanjing", "Chanjing",
            "search_engine_duojia", "Duojia",
            "search_engine_tencent_zhiying", "Tencent Zhiying",
            "search_engine_wansheng", "Wansheng",
            "search_engine_tencent_video", "Tencent Video",
            "search_engine_iqiyi", "iQiyi",
            ; 图书类搜索引擎
            "search_engine_duokan", "Duokan",
            "search_engine_turing", "Turing",
            "search_engine_panda_book", "Panda Book",
            "search_engine_douban_book", "Douban Book",
            "search_engine_lifelong_edu", "Lifelong Education",
            "search_engine_verypan", "Verypan",
            "search_engine_zouddupai", "Zouddupai",
            "search_engine_gd_library", "GD Library",
            "search_engine_pansou", "Pansou",
            "search_engine_zsxq", "ZSXQ",
            "search_engine_jiumo", "Jiumo",
            "search_engine_weibo_book", "Weibo",
            ; 比价类搜索引擎
            "search_engine_jd", "JD",
            "search_engine_baidu_procure", "Baidu Procure",
            "search_engine_dangdang", "Dangdang",
            "search_engine_1688", "1688",
            "search_engine_taobao", "Taobao",
            "search_engine_tmall", "Tmall",
            "search_engine_pinduoduo", "Pinduoduo",
            "search_engine_xianyu", "Xianyu",
            "search_engine_smzdm", "SMZDM",
            "search_engine_yanxuan", "Yanxuan",
            "search_engine_gaide", "Gaide",
            "search_engine_suning", "Suning",
            "search_engine_ebay", "eBay",
            "search_engine_amazon", "Amazon",
            ; 医疗类搜索引擎
            "search_engine_dxy", "DXY",
            "search_engine_left_doctor", "Left Doctor",
            "search_engine_medisearch", "MediSearch",
            "search_engine_merck", "Merck Manual",
            "search_engine_aplus_medical", "A+ Medical",
            "search_engine_medical_baike", "Medical Baike",
            "search_engine_weiyi", "Weiyi",
            "search_engine_medlive", "Medlive",
            "search_engine_xywy", "XYWY",
            ; 网盘类搜索引擎
            "search_engine_pansoso", "Pansoso",
            "search_engine_panso", "Panso Pro",
            "search_engine_xiaomapan", "Xiaomapan",
            "search_engine_dashengpan", "Dashengpan",
            "search_engine_miaosou", "Miaosou",
            "search_category_ai", "AI",
            "search_category_academic", "Academic",
            "search_category_baidu", "Baidu",
            "search_category_image", "Image",
            "search_category_audio", "Audio",
            "search_category_video", "Video",
            "search_category_book", "Book",
            "search_category_price", "Price",
            "search_category_medical", "Medical",
            "search_category_cloud", "Cloud",
            "search_category_config", "Search Category Configuration",
            "search_category_config_desc", "Configure which categories are displayed in the voice search panel",
            "quick_action_config", "Quick Action Button Configuration",
            "quick_action_config_desc", "Configure button order and hotkeys in the quick action panel (max 5)",
            "quick_action_button", "Button {0}",
            "quick_action_type", "Action Type:",
            "quick_action_hotkey", "Hotkey:",
            "quick_action_move_up", "Move Up",
            "quick_action_move_down", "Move Down",
            "quick_action_add", "Add Button",
            "quick_action_remove", "Remove",
            "quick_action_type_explain", "Explain Code",
            "quick_action_type_refactor", "Refactor Code",
            "quick_action_type_optimize", "Optimize Code",
            "quick_action_type_config", "Open Config",
            "quick_action_type_copy", "Continuous Copy",
            "quick_action_type_paste", "Merge Paste",
            "quick_action_type_clipboard", "Clipboard Manager",
            "quick_action_type_voice", "Voice Input",
            "quick_action_type_split", "Split Code",
            "quick_action_type_batch", "Batch Operation",
            "quick_action_type_command_palette", "Command Palette",
            "quick_action_type_terminal", "New Terminal",
            "quick_action_type_global_search", "Global Search",
            "quick_action_type_explorer", "Explorer",
            "quick_action_type_source_control", "Source Control",
            "quick_action_type_extensions", "Extensions",
            "quick_action_type_browser", "Open Browser",
            "quick_action_type_settings", "Settings",
            "quick_action_type_cursor_settings", "Cursor Settings",
            "quick_action_desc_command_palette", "Open command palette (Ctrl + Shift + P)",
            "quick_action_desc_terminal", "New terminal (Ctrl + Shift + `)",
            "quick_action_desc_global_search", "Global search (Ctrl + Shift + F)",
            "quick_action_desc_explorer", "Show explorer (Ctrl + Shift + E)",
            "quick_action_desc_source_control", "Show source control (Ctrl + Shift + G)",
            "quick_action_desc_extensions", "Show extensions (Ctrl + Shift + X)",
            "quick_action_desc_browser", "Open browser (Ctrl + Shift + B)",
            "quick_action_desc_settings", "Show settings (Ctrl + Shift + J)",
            "quick_action_desc_cursor_settings", "Show Cursor settings (Ctrl + ,)",
            "quick_action_max_reached", "Maximum 5 buttons allowed",
            "quick_action_min_reached", "At least 1 button required",
            ; Cursor rules related text
            "hotkey_main_tab_settings", "Hotkey Settings",
            "hotkey_main_tab_rules", "Cursor Rules",
            "cursor_rules_title", "Cursor Rules Configuration",
            "cursor_rules_intro", "Copy the corresponding rule content to Cursor's rules file based on your development program type, so that AI can better understand your project requirements.",
            "cursor_rules_location_title", "📋 Copy Location",
            "cursor_rules_location_desc", "In Cursor, press Ctrl+Shift+P to open the command palette, type 'rules' or 'cursor rules', select 'Open Cursor Rules' to open the .cursorrules file, and paste the rule content into that file.",
            "cursor_rules_usage_title", "💡 Usage",
            "cursor_rules_usage_desc", "1. Select the corresponding development type tab below`n2. Click the 'Copy Rules' button`n3. Open the .cursorrules file in Cursor`n4. Paste the rule content and save`n5. Restart Cursor to apply the rules",
            "cursor_rules_copy_btn", "Copy Rules",
            "cursor_rules_copied", "Rules copied to clipboard!",
            "cursor_rules_subtab_general", "General Rules",
            "cursor_rules_subtab_web", "Web Development",
            "cursor_rules_subtab_miniprogram", "Mini Program",
            "cursor_rules_subtab_plugin", "Plugin",
            "cursor_rules_subtab_android", "Android App",
            "cursor_rules_subtab_ios", "iOS App",
            "cursor_rules_subtab_python", "Python",
            "cursor_rules_subtab_backend", "Backend Service",
            "cursor_rules_content_placeholder", "Rule content pending, please update later..."
        )
    )
    
    ; 获取当前语言的文本
    if (!Texts.Has(Language)) {
        Language := "zh"  ; 默认使用中文
    }
    LangTexts := Texts[Language]
    
    ; 检查键是否存在
    if (!LangTexts.Has(Key)) {
        return Key  ; 如果找不到，返回键名
    }
    
    Text := LangTexts[Key]
    
    ; 支持参数替换 {0}, {1} 等
    if (InStr(Text, "{0}") || InStr(Text, "{1}")) {
        ; 这里需要调用者传入参数，暂时返回原文本
        return Text
    }
    
    return Text
}

; 格式化文本（支持参数）
FormatText(Key, Params*) {
    Text := GetText(Key)
    Loop Params.Length {
        Text := StrReplace(Text, "{" . (A_Index - 1) . "}", Params[A_Index])
    }
    return Text
}

; ===================== 提示词模板系统 =====================
; 初始化分类定义
InitCategoryDefinitions() {
    global FunctionCategories, SeriesCategories, Language
    IsZh := (Language = "zh")
    
    ; 功能分类定义（一级分类）
    FunctionCategories := Map()
    FunctionCategories["Explain"] := {Name: IsZh ? "解释" : "Explain", SortWeight: 1}
    FunctionCategories["Refactor"] := {Name: IsZh ? "重构" : "Refactor", SortWeight: 2}
    FunctionCategories["Optimize"] := {Name: IsZh ? "优化" : "Optimize", SortWeight: 3}
    
    ; 模板系列定义（二级分类）
    SeriesCategories := Map()
    SeriesCategories["Basic"] := {Name: IsZh ? "基础" : "Basic", SortWeight: 1}
    SeriesCategories["Professional"] := {Name: IsZh ? "专业" : "Professional", SortWeight: 2}
    SeriesCategories["BugFix"] := {Name: IsZh ? "改错" : "BugFix", SortWeight: 3}
    SeriesCategories["Custom"] := {Name: IsZh ? "自定义" : "Custom", SortWeight: 99}
}

; 构建双层分类索引
BuildCategoryMap() {
    global PromptTemplates, CategoryMap, FunctionCategories, SeriesCategories, CategoryMapDirty
    
    ; 🚀 性能优化：如果缓存有效，直接返回
    if (!CategoryMapDirty) {
        return
    }
    
    ; 初始化分类映射
    CategoryMap := Map()
    for FuncCatID, FuncCatInfo in FunctionCategories {
        CategoryMap[FuncCatID] := Map()
        for SeriesID, SeriesInfo in SeriesCategories {
            CategoryMap[FuncCatID][SeriesID] := []
        }
    }
    
    ; 遍历所有模板，分配到对应的分类
    for Index, Template in PromptTemplates {
        ; 获取功能分类（FunctionCategory字段，如果没有则从ID推断）
        FuncCatID := Template.HasProp("FunctionCategory") ? Template.FunctionCategory : InferFunctionCategory(Template)
        
        ; 获取模板系列（Series字段，如果没有则从Category推断）
        SeriesID := Template.HasProp("Series") ? Template.Series : InferSeries(Template)
        
        ; 确保功能分类存在
        if (!CategoryMap.Has(FuncCatID)) {
            CategoryMap[FuncCatID] := Map()
        }
        
        ; 确保模板系列存在
        if (!CategoryMap[FuncCatID].Has(SeriesID)) {
            CategoryMap[FuncCatID][SeriesID] := []
        }
        
        ; 添加到对应分类
        CategoryMap[FuncCatID][SeriesID].Push(Template)
    }
    
    ; 🚀 性能优化：标记缓存有效
    CategoryMapDirty := false
}

; ===================== 重建模板索引（性能优化） =====================
; 构建快速查找索引：ID -> Template, Category|Title -> Template
RebuildTemplateIndex() {
    global PromptTemplates, TemplateIndexByID, TemplateIndexByTitle, TemplateIndexByArrayIndex
    
    ; 清空旧索引
    TemplateIndexByID := Map()
    TemplateIndexByTitle := Map()
    TemplateIndexByArrayIndex := Map()
    
    ; 构建新索引 - O(n)，但只执行一次
    for Index, Template in PromptTemplates {
        ; ID 索引
        TemplateIndexByID[Template.ID] := Template
        
        ; Category+Title 复合索引
        Key := Template.Category . "|" . Template.Title
        TemplateIndexByTitle[Key] := Template
        
        ; 数组索引映射
        TemplateIndexByArrayIndex[Template.ID] := Index
    }
}

; ===================== 标记缓存失效（性能优化） =====================
; 在模板变更时调用，标记分类映射和索引需要重建
InvalidateTemplateCache() {
    global CategoryMapDirty
    CategoryMapDirty := true
    ; 重建索引
    RebuildTemplateIndex()
}

; 从模板ID推断功能分类
InferFunctionCategory(Template) {
    ID := Template.ID
    if (InStr(ID, "explain") || InStr(ID, "Explain")) {
        return "Explain"
    } else if (InStr(ID, "refactor") || InStr(ID, "Refactor")) {
        return "Refactor"
    } else if (InStr(ID, "optimize") || InStr(ID, "Optimize")) {
        return "Optimize"
    } else {
        ; 默认归类到Explain
        return "Explain"
    }
}

; 从模板Category推断模板系列
InferSeries(Template) {
    Category := Template.Category
    if (!Category) {
        Category := ""
    }
    
    ; 中文匹配
    if (Category = "基础" || Category = "Basic") {
        return "Basic"
    } else if (Category = "专业" || Category = "Professional") {
        return "Professional"
    } else if (Category = "改错" || Category = "BugFix") {
        return "BugFix"
    } else {
        ; 其他归类到自定义
        return "Custom"
    }
}

; 创建默认模板
CreateDefaultPromptTemplates() {
    global Language
    IsZh := (Language = "zh")
    
    Templates := []
    
    ; ========== 基础系列 - 解释功能 ==========
    Templates.Push({
        ID: "explain_basic",
        Title: IsZh ? "代码解释" : "Explain Code",
        Content: IsZh ? "解释这段代码的核心逻辑、输入输出、关键函数作用，用新手能懂的语言，标注易错点" : "Explain the core logic, inputs/outputs, and key functions of this code in simple terms. Highlight potential pitfalls.",
        Icon: "",
        FunctionCategory: "Explain",
        Series: "Basic",
        Category: IsZh ? "基础" : "Basic"  ; 保留用于兼容
    })
    
    ; ========== 基础系列 - 重构功能 ==========
    Templates.Push({
        ID: "refactor_basic",
        Title: IsZh ? "代码重构" : "Refactor Code",
        Content: IsZh ? "重构这段代码，遵循PEP8/行业规范，简化冗余逻辑，添加中文注释，保持功能不变" : "Refactor this code following PEP8/best practices. Simplify redundant logic, add comments, and keep functionality unchanged.",
        Icon: "",
        FunctionCategory: "Refactor",
        Series: "Basic",
        Category: IsZh ? "基础" : "Basic"  ; 保留用于兼容
    })
    
    ; ========== 基础系列 - 优化功能 ==========
    Templates.Push({
        ID: "optimize_basic",
        Title: IsZh ? "性能优化" : "Optimize Code",
        Content: IsZh ? "分析这段代码的性能瓶颈（时间/空间复杂度），给出优化方案+对比说明，保留原逻辑可读性" : "Analyze performance bottlenecks (time/space complexity). Provide optimization solutions with comparison. Keep original logic readable.",
        Icon: "",
        FunctionCategory: "Optimize",
        Series: "Basic",
        Category: IsZh ? "基础" : "Basic"  ; 保留用于兼容
    })
    
    Templates.Push({
        ID: "debug_basic",
        Title: IsZh ? "调试代码" : "Debug Code",
        Content: IsZh ? "请帮我调试这段代码，找出可能的bug和错误，并提供修复建议" : "Please help me debug this code, find potential bugs and errors, and provide fix suggestions.",
        Icon: "",
        Category: IsZh ? "基础" : "Basic"
    })
    
    Templates.Push({
        ID: "test_basic",
        Title: IsZh ? "编写测试" : "Write Tests",
        Content: IsZh ? "为这段代码编写单元测试，覆盖主要功能和边界情况" : "Write unit tests for this code, covering main functionality and edge cases.",
        Icon: "",
        Category: IsZh ? "基础" : "Basic"
    })
    
    Templates.Push({
        ID: "document_basic",
        Title: IsZh ? "添加文档" : "Add Documentation",
        Content: IsZh ? "为这段代码添加详细的文档注释，包括函数说明、参数说明、返回值说明和使用示例" : "Add detailed documentation comments to this code, including function descriptions, parameter descriptions, return value descriptions, and usage examples.",
        Icon: "",
        Category: IsZh ? "基础" : "Basic"
    })
    
    ; ========== 专业分类 ==========
    Templates.Push({
        ID: "code_review",
        Title: IsZh ? "代码审查" : "Code Review",
        Content: IsZh ? "请对这段代码进行全面审查，指出潜在问题、bug、安全隐患和改进建议" : "Review this code comprehensively. Point out potential issues, bugs, security vulnerabilities, and improvement suggestions.",
        Icon: "",
        Category: IsZh ? "专业" : "Professional"
    })
    
    Templates.Push({
        ID: "architecture_analysis",
        Title: IsZh ? "架构分析" : "Architecture Analysis",
        Content: IsZh ? "请从专业的角度分析这段代码，包括架构设计、设计模式、技术选型等方面的考量" : "Analyze this code from a professional perspective, including architectural design, design patterns, and technical choices.",
        Icon: "",
        Category: IsZh ? "专业" : "Professional"
    })
    
    Templates.Push({
        ID: "security_audit",
        Title: IsZh ? "安全审计" : "Security Audit",
        Content: IsZh ? "请对这段代码进行安全审计，检查是否存在SQL注入、XSS、CSRF等安全漏洞，并提供安全加固建议" : "Perform a security audit on this code, check for security vulnerabilities such as SQL injection, XSS, CSRF, and provide security hardening suggestions.",
        Icon: "",
        Category: IsZh ? "专业" : "Professional"
    })
    
    Templates.Push({
        ID: "performance_profiling",
        Title: IsZh ? "性能分析" : "Performance Profiling",
        Content: IsZh ? "请深入分析这段代码的性能问题，包括CPU使用、内存占用、I/O操作等，并提供详细的性能优化方案" : "Deeply analyze the performance issues of this code, including CPU usage, memory consumption, I/O operations, and provide detailed performance optimization solutions.",
        Icon: "",
        Category: IsZh ? "专业" : "Professional"
    })
    
    Templates.Push({
        ID: "design_pattern",
        Title: IsZh ? "设计模式" : "Design Pattern",
        Content: IsZh ? "请分析这段代码是否适合应用设计模式，如果适合，请重构代码应用合适的设计模式，并说明原因" : "Analyze whether this code is suitable for applying design patterns. If suitable, refactor the code to apply appropriate design patterns and explain the reasons.",
        Icon: "",
        Category: IsZh ? "专业" : "Professional"
    })
    
    Templates.Push({
        ID: "scalability",
        Title: IsZh ? "可扩展性分析" : "Scalability Analysis",
        Content: IsZh ? "请分析这段代码的可扩展性，包括如何处理高并发、大数据量等情况，并提供扩展性改进方案" : "Analyze the scalability of this code, including how to handle high concurrency, large data volumes, and provide scalability improvement solutions.",
        Icon: "",
        Category: IsZh ? "专业" : "Professional"
    })
    
    ; ========== 改错分类 ==========
    Templates.Push({
        ID: "bugfix_urgent",
        Title: "不分等着过年？",
        Content: "现在请你扮演一位经验丰富、以严谨著称的架构师。指出现在可能存在的风险、不足或考虑不周的地方，重新审查我们刚才制定的这个 Bug 修复方案 ，请粘贴错误代码或者截图",
        Icon: "",
        Category: IsZh ? "改错" : "BugFix"
    })
    
    Templates.Push({
        ID: "bugfix_multiple",
        Title: "AI海王手册",
        Content: "请提供三种不同的修复方案。并为每种方案说明其优点、缺点和适用场景，让我来做选择，请粘贴错误代码或者截图",
        Icon: "",
        Category: IsZh ? "改错" : "BugFix"
    })
    
    Templates.Push({
        ID: "bugfix_research",
        Title: "上外网看看吧",
        Content: "我的代码遇到了一个典型问题：请你扮演网络搜索助手，在GitHub Issues / Stack Overflow等开源社区汇总常见的解决方案，并针对我的这个bug给出最优的修复建议。请粘贴错误代码或者截图",
        Icon: "",
        Category: IsZh ? "改错" : "BugFix"
    })
    
    Templates.Push({
        ID: "bugfix_explain",
        Title: "给我翻译翻译",
        Content: "请用最简单易懂的语言告诉我这个错误是什么意思？最可能是我代码中的哪部分导致的？请粘贴错误代码或者截图",
        Icon: "",
        Category: IsZh ? "改错" : "BugFix"
    })
    
    Templates.Push({
        ID: "bugfix_diagram",
        Title: "无图无真相",
        Content: "请你为我分别生成 ASCII 序列图或mermaid流程图，模拟展示错误代码的执行步骤和关键变量的变化，帮我直观地看到问题出在哪一步。请粘贴错误代码或者截图",
        Icon: "",
        Category: IsZh ? "改错" : "BugFix"
    })
    
    Templates.Push({
        ID: "bugfix_rules",
        Title: "乱拳打死老师傅",
        Content: "我的代码违反了编程基础规则导致bug，请帮我用「规则校验法」排查：`n1. 列出代码违反的核心编程规则（比如「变量命名规范」「条件判断完整性」「资源释放规则」）；`n2. 用ASCII checklist（勾选框）标注每个规则的违反情况；`n3. 解释这些规则的作用，以及违反后为什么会触发bug；`n4. 给出符合规则的修改思路，附带新手易记的规则口诀。请粘贴错误代码或者截图",
        Icon: "",
        Category: IsZh ? "改错" : "BugFix"
    })
    
    Templates.Push({
        ID: "bugfix_reverse",
        Title: "倒反天罡",
        Content: "从最终的这个 错误结果 / 异常状态开始，进行逆向逻辑推导。分析：在什么情况下、输入了什么样的数据、经过了怎样的操作，才会导致产生这个特定的结果？列出导致该结果的 3 种最可能的根本原因。请粘贴错误代码或者截图",
        Icon: "",
        Category: IsZh ? "改错" : "BugFix"
    })
    
    Templates.Push({
        ID: "bugfix_debug",
        Title: "捉奸拿赃",
        Content: "给我提供一个图形弹窗方案，通过步骤来一步步追溯问题来源，定位问题所在。请粘贴错误代码或者截图",
        Icon: "",
        Category: IsZh ? "改错" : "BugFix"
    })
    
    Templates.Push({
        ID: "bugfix_simple",
        Title: "弱智吧",
        Content: "请用生活中的最简单多类比来解释这个 Bug 的成因。在我不理解任何编程术语的前提下，告诉我这个问题到底在'犯什么傻'。请粘贴错误代码或者截图",
        Icon: "",
        Category: IsZh ? "改错" : "BugFix"
    })
    
    Templates.Push({
        ID: "bugfix_isolate",
        Title: "拆东墙补西墙",
        Content: "把这段代码想象成乐高积木。请告诉我哪几块积木是独立的？请帮我通过'拆除法'定位到底是哪一块积木坏了？请粘贴错误代码或者截图",
        Icon: "",
        Category: IsZh ? "改错" : "BugFix"
    })
    
    Templates.Push({
        ID: "bugfix_color",
        Title: "给点color看看",
        Content: "请给我的代码涂色。绿色是确认安全的，黄色是逻辑可疑的，红色是报错核心。请重点解释红色部分的'逻辑死结'是如何形成的。请粘贴错误代码或者截图",
        Icon: "",
        Category: IsZh ? "改错" : "BugFix"
    })
    
    Templates.Push({
        ID: "bugfix_minimal",
        Title: "Word很大，你忍一下",
        Content: "不要大改我的架构。请给出一种'微创手术'方案：只修改最少的字符（比如改个符号或加个判断），就能让整个程序恢复运行，并解释为什么这一刀最关键。请粘贴错误代码或者截图",
        Icon: "",
        Category: IsZh ? "改错" : "BugFix"
    })
    
    Templates.Push({
        ID: "bugfix_human",
        Title: "请说人话",
        Content: "请提供一份双语对照表。左边是代码行，右边是对应的'人类意图'。通过对比，帮我定位哪一行有错误。请粘贴错误代码或者截图",
        Icon: "",
        Category: IsZh ? "改错" : "BugFix"
    })
    
    return Templates
}

; 加载提示词模板
LoadPromptTemplates() {
    global PromptTemplates, PromptTemplatesFile, DefaultTemplateIDs, Language
    
    ; 初始化分类定义
    InitCategoryDefinitions()
    
    ; 先创建默认模板
    PromptTemplates := CreateDefaultPromptTemplates()
    
    ; 从INI文件加载自定义模板
    if (FileExist(PromptTemplatesFile)) {
        try {
            ; 读取模板数量
            TemplateCount := Integer(IniRead(PromptTemplatesFile, "Templates", "Count", "0"))
            if (TemplateCount > 0) {
                Loop TemplateCount {
                    Index := A_Index
                    TemplateID := IniRead(PromptTemplatesFile, "Template" . Index, "ID", "")
                    if (TemplateID != "") {
                        ; 🚀 性能优化：使用索引查找 - O(1)
                        global TemplateIndexByID
                        if (TemplateIndexByID.Has(TemplateID)) {
                            ; 更新现有模板
                            Template := TemplateIndexByID[TemplateID]
                            Template.Title := IniRead(PromptTemplatesFile, "Template" . Index, "Title", Template.Title)
                            Template.Content := IniRead(PromptTemplatesFile, "Template" . Index, "Content", Template.Content)
                            Template.Icon := IniRead(PromptTemplatesFile, "Template" . Index, "Icon", Template.Icon)
                            Template.Category := IniRead(PromptTemplatesFile, "Template" . Index, "Category", Template.Category)
                            ; 更新索引
                            TemplateIndexByID[TemplateID] := Template
                            global TemplateIndexByTitle
                            Key := Template.Category . "|" . Template.Title
                            TemplateIndexByTitle[Key] := Template
                        } else {
                            ; 添加新模板
                            NewTemplate := {
                                ID: TemplateID,
                                Title: IniRead(PromptTemplatesFile, "Template" . Index, "Title", ""),
                                Content: IniRead(PromptTemplatesFile, "Template" . Index, "Content", ""),
                                Icon: IniRead(PromptTemplatesFile, "Template" . Index, "Icon", "📝"),
                                Category: IniRead(PromptTemplatesFile, "Template" . Index, "Category", "自定义")
                            }
                            PromptTemplates.Push(NewTemplate)
                            ; 🚀 性能优化：更新索引
                            TemplateIndexByID[TemplateID] := NewTemplate
                            Key := NewTemplate.Category . "|" . NewTemplate.Title
                            TemplateIndexByTitle[Key] := NewTemplate
                            global TemplateIndexByArrayIndex
                            TemplateIndexByArrayIndex[TemplateID] := PromptTemplates.Length
                        }
                    }
                }
            }
        } catch {
            ; 加载失败，使用默认模板
        }
    }
    
    ; 初始化默认模板映射
    DefaultTemplateIDs["Explain"] := IniRead(PromptTemplatesFile, "Defaults", "Explain", "explain_basic")
    DefaultTemplateIDs["Refactor"] := IniRead(PromptTemplatesFile, "Defaults", "Refactor", "refactor_basic")
    DefaultTemplateIDs["Optimize"] := IniRead(PromptTemplatesFile, "Defaults", "Optimize", "optimize_basic")
    
    ; 构建双层分类索引
    BuildCategoryMap()
    
    ; 🚀 性能优化：重建模板索引
    RebuildTemplateIndex()
    
    ; 加载分类展开状态（从配置文件）
    global CategoryExpandedState
    CategoryExpandedState := Map()
    try {
        ; 读取展开状态数量
        ExpandedStateCount := Integer(IniRead(PromptTemplatesFile, "ExpandedStates", "Count", "0"))
        if (ExpandedStateCount > 0) {
            Loop ExpandedStateCount {
                Index := A_Index
                CategoryName := IniRead(PromptTemplatesFile, "ExpandedState" . Index, "Category", "")
                TemplateKey := IniRead(PromptTemplatesFile, "ExpandedState" . Index, "TemplateKey", "")
                if (CategoryName != "" && TemplateKey != "") {
                    CategoryExpandedState[CategoryName] := TemplateKey
                }
            }
        }
    } catch {
        ; 加载失败，使用空的展开状态
        CategoryExpandedState := Map()
    }
}

; 保存提示词模板
SavePromptTemplates() {
    global PromptTemplates, PromptTemplatesFile, DefaultTemplateIDs
    
    try {
        ; 保存模板数量
        IniWrite(String(PromptTemplates.Length), PromptTemplatesFile, "Templates", "Count")
        
        ; 保存每个模板
        for Index, Template in PromptTemplates {
            SectionName := "Template" . Index
            IniWrite(Template.ID, PromptTemplatesFile, SectionName, "ID")
            IniWrite(Template.Title, PromptTemplatesFile, SectionName, "Title")
            IniWrite(Template.Content, PromptTemplatesFile, SectionName, "Content")
            IniWrite(Template.Icon, PromptTemplatesFile, SectionName, "Icon")
            IniWrite(Template.Category, PromptTemplatesFile, SectionName, "Category")
            
            ; 保存新字段（如果存在）
            if (Template.HasProp("FunctionCategory")) {
                IniWrite(Template.FunctionCategory, PromptTemplatesFile, SectionName, "FunctionCategory")
            }
            if (Template.HasProp("Series")) {
                IniWrite(Template.Series, PromptTemplatesFile, SectionName, "Series")
            }
        }
        
        ; 重新构建索引
        BuildCategoryMap()
        
        ; 🚀 性能优化：重建模板索引
        RebuildTemplateIndex()
        
        ; 保存默认模板映射
        IniWrite(DefaultTemplateIDs["Explain"], PromptTemplatesFile, "Defaults", "Explain")
        IniWrite(DefaultTemplateIDs["Refactor"], PromptTemplatesFile, "Defaults", "Refactor")
        IniWrite(DefaultTemplateIDs["Optimize"], PromptTemplatesFile, "Defaults", "Optimize")
        
        ; 保存分类展开状态
        global CategoryExpandedState
        if (IsSet(CategoryExpandedState) && IsObject(CategoryExpandedState) && CategoryExpandedState.Count > 0) {
            ; 先删除旧的展开状态配置
            ExpandedStateCount := Integer(IniRead(PromptTemplatesFile, "ExpandedStates", "Count", "0"))
            if (ExpandedStateCount > 0) {
                Loop ExpandedStateCount {
                    IniDelete(PromptTemplatesFile, "ExpandedState" . A_Index)
                }
            }
            
            ; 保存新的展开状态
            Index := 0
            for CategoryName, TemplateKey in CategoryExpandedState {
                Index++
                IniWrite(CategoryName, PromptTemplatesFile, "ExpandedState" . Index, "Category")
                IniWrite(TemplateKey, PromptTemplatesFile, "ExpandedState" . Index, "TemplateKey")
            }
            IniWrite(String(Index), PromptTemplatesFile, "ExpandedStates", "Count")
        } else {
            ; 如果没有展开状态，清空配置
            IniWrite("0", PromptTemplatesFile, "ExpandedStates", "Count")
        }
    } catch as e {
        ; 保存失败，忽略错误
    }
}

; 根据ID获取模板
GetTemplateByID(TemplateID) {
    global TemplateIndexByID
    
    ; 🚀 性能优化：使用索引直接查找 - O(1)
    if (TemplateIndexByID.Has(TemplateID)) {
        return TemplateIndexByID[TemplateID]
    }
    
    ; 如果索引未初始化，回退到旧方法（向后兼容）
    global PromptTemplates
    for Index, Template in PromptTemplates {
        if (Template.ID = TemplateID) {
            return Template
        }
    }
    return ""
}

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
    DefaultPanelScreenIndex := 1
    DefaultPanelPosition := "center"
    DefaultFunctionPanelPos := "center"
    DefaultConfigPanelPos := "center"
    DefaultClipboardPanelPos := "center"
    DefaultConfigPanelScreenIndex := 1
    DefaultMsgBoxScreenIndex := 1
    DefaultVoiceInputScreenIndex := 1
    DefaultCursorPanelScreenIndex := 1
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
        IniWrite("0", ConfigFile, "Settings", "AutoLoadSelectedText")
        IniWrite("1", ConfigFile, "Settings", "AutoUpdateVoiceInput")
        IniWrite("deepseek", ConfigFile, "Settings", "VoiceSearchSelectedEngines")  ; 保存默认选中的搜索引擎
        IniWrite("0", ConfigFile, "Settings", "AutoStart")  ; 默认不自启动
        ; 保存默认启用的搜索标签（默认全部启用）
        DefaultEnabledCategories := "ai,academic,baidu,image,audio,video,book,price,medical,cloud"
        IniWrite(DefaultEnabledCategories, ConfigFile, "Settings", "VoiceSearchEnabledCategories")
        
        IniWrite(DefaultPanelScreenIndex, ConfigFile, "Appearance", "ScreenIndex")
        IniWrite(DefaultFunctionPanelPos, ConfigFile, "Appearance", "FunctionPanelPos")
        IniWrite(DefaultConfigPanelPos, ConfigFile, "Appearance", "ConfigPanelPos")
        IniWrite(DefaultClipboardPanelPos, ConfigFile, "Appearance", "ClipboardPanelPos")
        IniWrite("dark", ConfigFile, "Settings", "ThemeMode")  ; 默认暗色主题
        IniWrite(DefaultConfigPanelScreenIndex, ConfigFile, "Advanced", "ConfigPanelScreenIndex")
        IniWrite(DefaultMsgBoxScreenIndex, ConfigFile, "Advanced", "MsgBoxScreenIndex")
        IniWrite(DefaultVoiceInputScreenIndex, ConfigFile, "Advanced", "VoiceInputScreenIndex")
        IniWrite(DefaultCursorPanelScreenIndex, ConfigFile, "Advanced", "CursorPanelScreenIndex")
        
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
    global CursorPath, AISleepTime, CapsLockHoldTimeSeconds, Prompt_Explain, Prompt_Refactor, Prompt_Optimize, SplitHotkey, BatchHotkey, PanelScreenIndex, Language
    global FunctionPanelPos, ConfigPanelPos, ClipboardPanelPos
    global HotkeyESC, HotkeyC, HotkeyV, HotkeyX, HotkeyE, HotkeyR, HotkeyO, HotkeyQ, HotkeyZ, HotkeyP
    global ConfigPanelScreenIndex, MsgBoxScreenIndex, VoiceInputScreenIndex, CursorPanelScreenIndex
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
    
    try {
        if FileExist(ConfigFile) {
            ; 兼容旧配置格式，优先读取新格式
            CursorPath := IniRead(ConfigFile, "Settings", "CursorPath", IniRead(ConfigFile, "General", "CursorPath", DefaultCursorPath))
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
            HotkeyP := IniRead(ConfigFile, "Hotkeys", "P", "p")
            SearchEngine := IniRead(ConfigFile, "Settings", "SearchEngine", "deepseek")
            AutoLoadSelectedText := (IniRead(ConfigFile, "Settings", "AutoLoadSelectedText", "0") = "1")
            AutoUpdateVoiceInput := (IniRead(ConfigFile, "Settings", "AutoUpdateVoiceInput", "1") = "1")
            AutoStart := (IniRead(ConfigFile, "Settings", "AutoStart", "0") = "1")
            global DefaultStartTab
            DefaultStartTab := IniRead(ConfigFile, "Settings", "DefaultStartTab", "general")
            ; 验证值是否有效，如果无效则使用默认值
            if (DefaultStartTab != "general" && DefaultStartTab != "appearance" && DefaultStartTab != "prompts" && DefaultStartTab != "hotkeys" && DefaultStartTab != "advanced") {
                DefaultStartTab := "general"
            }
            
            ; 加载启用的搜索标签
            global VoiceSearchEnabledCategories
            EnabledCategoriesStr := IniRead(ConfigFile, "Settings", "VoiceSearchEnabledCategories", "ai,academic,baidu,image,audio,video,book,price,medical,cloud")
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
                    VoiceSearchEnabledCategories := ["ai", "academic", "baidu", "image", "audio", "video", "book", "price", "medical", "cloud"]
                }
            } else {
                VoiceSearchEnabledCategories := ["ai", "academic", "baidu", "image", "audio", "video", "book", "price", "medical", "cloud"]
            }
            
            ; 应用自启动设置
            SetAutoStart(AutoStart)
            
            ; 加载主题模式（暗色或亮色）
            global ThemeMode
            ThemeMode := IniRead(ConfigFile, "Settings", "ThemeMode", "dark")
            ApplyTheme(ThemeMode)
            
            ; 初始化每个分类的搜索引擎选择状态Map
            global VoiceSearchSelectedEnginesByCategory
            if (!IsSet(VoiceSearchSelectedEnginesByCategory) || !IsObject(VoiceSearchSelectedEnginesByCategory)) {
                VoiceSearchSelectedEnginesByCategory := Map()
            }
            
            ; 加载每个分类的搜索引擎选择状态
            AllCategories := ["ai", "academic", "baidu", "image", "audio", "video", "book", "price", "medical", "cloud"]
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
            
            PanelScreenIndex := Integer(IniRead(ConfigFile, "Appearance", "ScreenIndex", DefaultPanelScreenIndex))
            FunctionPanelPos := IniRead(ConfigFile, "Appearance", "FunctionPanelPos", DefaultFunctionPanelPos)
            ConfigPanelPos := IniRead(ConfigFile, "Appearance", "ConfigPanelPos", DefaultConfigPanelPos)
            ClipboardPanelPos := IniRead(ConfigFile, "Appearance", "ClipboardPanelPos", DefaultClipboardPanelPos)
            ConfigPanelScreenIndex := Integer(IniRead(ConfigFile, "Advanced", "ConfigPanelScreenIndex", DefaultConfigPanelScreenIndex))
            MsgBoxScreenIndex := Integer(IniRead(ConfigFile, "Advanced", "MsgBoxScreenIndex", DefaultMsgBoxScreenIndex))
            VoiceInputScreenIndex := Integer(IniRead(ConfigFile, "Advanced", "VoiceInputScreenIndex", DefaultVoiceInputScreenIndex))
            CursorPanelScreenIndex := Integer(IniRead(ConfigFile, "Advanced", "CursorPanelScreenIndex", DefaultCursorPanelScreenIndex))
            
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
            AutoStart := false
            VoiceSearchEnabledCategories := ["ai", "academic", "baidu", "image", "audio", "video", "book", "price", "medical", "cloud"]
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
    }
    
    ; 验证语言设置
    if (Language != "zh" && Language != "en") {
        Language := "zh"  ; 默认中文
    }
}

; 在InitConfig结束后加载模板
InitConfig() ; 启动初始化
; 加载提示词模板系统（在配置初始化后）
LoadPromptTemplates()

; ===================== 剪贴板变化监听 =====================
; 注意：OnClipboardChange 必须在脚本启动时注册，确保在 InitConfig 之后定义
; 监听 Ctrl+C 复制操作，自动记录到 Ctrl+C 历史记录
global LastClipboardContent := ""  ; 记录上次剪贴板内容，避免重复记录
global CapsLockCopyInProgress := false  ; 标记 CapsLock+C 是否正在进行中
global CapsLockCopyEndTime := 0  ; CapsLock+C 结束时间，用于延迟检测

OnClipboardChange(ClipboardChanged) {
    ; 只在剪贴板内容变化时触发（不是由 CapsLock+C 触发的）
    global ClipboardHistory_CtrlC, LastClipboardContent, CapsLockCopyInProgress, CapsLockCopyEndTime
    
    ; 如果 CapsLock+C 正在进行中，不记录（避免重复记录）
    if (CapsLockCopyInProgress) {
        return
    }
    
    ; 如果 CapsLock+C 刚结束（2秒内），也不记录（避免重复记录）
    CurrentTime := A_TickCount
    if (CapsLockCopyEndTime > 0 && (CurrentTime - CapsLockCopyEndTime) < 2000) {
        return
    }
    
    ; 确保 ClipboardHistory_CtrlC 已初始化（使用全局变量）
    if (!IsSet(ClipboardHistory_CtrlC) || !IsObject(ClipboardHistory_CtrlC)) {
        ClipboardHistory_CtrlC := []
    }
    
    ; 确保其他全局变量已初始化
    if (!IsSet(LastClipboardContent)) {
        LastClipboardContent := ""
    }
    
    ; 获取当前剪贴板内容
    try {
        ; 直接读取剪贴板内容，不等待（因为 OnClipboardChange 已经表示剪贴板已变化）
        CurrentContent := A_Clipboard
        ; 如果内容为空或与上次相同，不记录
        if (CurrentContent = "" || CurrentContent = LastClipboardContent) {
            return
        }
        
        ; 检查内容长度（太短的内容可能是误触）
        if (StrLen(CurrentContent) < 1) {
            return
        }
        
        ; 记录到 Ctrl+C 历史记录（限制最多保存100条）
        ; 使用已声明的全局变量
        ClipboardHistory_CtrlC.Push(CurrentContent)
        if (ClipboardHistory_CtrlC.Length > 100) {
            ClipboardHistory_CtrlC.RemoveAt(1)  ; 删除最旧的记录
        }
        
        ; 更新上次内容
        LastClipboardContent := CurrentContent
        
        ; 如果剪贴板面板正在显示，刷新列表（无论当前Tab是什么）
        ; 使用 SetTimer 延迟刷新，确保数据已完全更新
        global GuiID_ClipboardManager
        if (GuiID_ClipboardManager != 0) {
            ; 延迟刷新，确保数据已完全更新，同时避免频繁刷新
            SetTimer(RefreshClipboardListDelayed, -100)
        }
    } catch as e {
        ; 忽略错误（剪贴板可能被其他程序占用）
    }
}

; ===================== 托盘图标配置 =====================
UpdateTrayMenu() {
    A_TrayMenu.Delete()  ; 清空菜单
    A_TrayMenu.Add(GetText("open_config_menu"), (*) => ShowConfigGUI())
    A_TrayMenu.Add(GetText("exit_menu"), (*) => CleanUp())
    A_TrayMenu.Default := GetText("exit_menu")
    A_IconTip := GetText("app_tip")
}

UpdateTrayMenu()  ; 初始化托盘菜单

; ===================== CapsLock 状态检查函数 =====================
; 用于 #HotIf 指令的函数
GetCapsLockState() {
    global CapsLock
    ; 检查变量状态或物理按键状态（确保即使变量被清除，物理按键仍能触发）
    ; 这样即使用户先按 CapsLock 再释放，只要在释放前按了其他键，也能触发
    return CapsLock || GetKeyState("CapsLock", "P")
}

; ===================== 面板可见状态检查函数 =====================
; 用于 #HotIf 指令的函数
GetPanelVisibleState() {
    global PanelVisible
    return PanelVisible
}

; ===================== CapsLock核心逻辑 =====================
; 定时器函数定义（需要在 CapsLock 处理函数外部定义）
ClearCapsLock2Timer(*) {
    global CapsLock2 := false
}

; 延迟清除 CapsLock 变量的函数
ClearCapsLockTimer(*) {
    global CapsLock := false
}

ShowPanelTimer(*) {
    global CapsLock, PanelVisible, VoiceInputActive, VoiceSearchActive, VoiceSearchSelecting
    ; 如果正在语音输入、语音搜索或选择搜索引擎，不显示快捷操作面板
    if (VoiceInputActive || VoiceSearchActive || VoiceSearchSelecting) {
        return
    }
    ; 如果CapsLock仍然按下且面板未显示，则显示面板
    ; 注意：如果使用了组合快捷键，HandleDynamicHotkey会清除这个定时器，所以这里不需要检查CapsLock2
    if (CapsLock && !PanelVisible) {
        ShowCursorPanel()
    }
}

; 记录 CapsLock 按下时间
global CapsLockPressTime := 0

; 采用 CapsLock+ 方案：使用 ~ 前缀保留原始功能，通过标记变量控制行为
~CapsLock:: {
    global CapsLock, CapsLock2, IsCommandMode, PanelVisible, VoiceInputActive, VoiceSearchActive, VoiceInputMethod, VoiceInputPaused
    
    ; 标记 CapsLock 已按下
    CapsLock := true
    CapsLock2 := true  ; 初始化为 true，如果使用了功能会被清除
    IsCommandMode := false
    
    ; 记录按下时间
    CapsLockPressTime := A_TickCount
    
    ; 如果正在语音输入或语音搜索，处理暂停/恢复逻辑
    if (VoiceInputActive || VoiceSearchActive) {
        ; 设置定时器：300ms 后清除 CapsLock2（用于检测是否按了其他键）
        SetTimer(ClearCapsLock2Timer, -300)
        
        ; 如果未暂停，则暂停语音输入
        if (!VoiceInputPaused) {
            VoiceInputPaused := true
            UpdateVoiceInputPausedState(true)
            
            ; 使用 Cursor 的快捷键 Ctrl+Shift+Space 暂停语音输入
            if (VoiceInputActive) {
                Send("^+{Space}")
                Sleep(200)
            }
        }
        
        ; 等待 CapsLock 释放
        KeyWait("CapsLock")
        
        ; 停止定时器
        SetTimer(ClearCapsLock2Timer, 0)
        
        ; 计算按下时长
        PressDuration := A_TickCount - CapsLockPressTime
        
        ; 如果按了其他键（如Z或F），CapsLock2会被清除，不恢复语音
        ; 如果只按了CapsLock（CapsLock2仍然为true），且是短按，则恢复语音输入或搜索
        if (CapsLock2 && PressDuration < 1500) {
            ; 只按了CapsLock，没有按其他键，恢复语音输入或搜索
            if (VoiceInputPaused) {
                VoiceInputPaused := false
                if (VoiceInputActive) {
                    UpdateVoiceInputPausedState(false)  ; 更新动画状态，显示恢复
                } else if (VoiceSearchActive) {
                    ; 语音搜索的恢复逻辑（如果需要的话）
                }
                
                ; 使用 Cursor 的快捷键 Ctrl+Shift+Space 恢复语音输入
                if (VoiceInputActive) {
                    Send("^+{Space}")
                    Sleep(200)
                }
            }
        }
        
        CapsLock := false
        CapsLock2 := false
        return
    }
    
    ; 如果未在语音输入，执行正常的 CapsLock+ 逻辑
    ; 设置定时器：300ms 后清除 CapsLock2（犹豫操作时间）
    ; 如果在这 300ms 内使用了 CapsLock+ 功能，CapsLock2 会被提前清除
    SetTimer(ClearCapsLock2Timer, -300)
    
    ; 设置定时器：长按指定时间后自动显示面板（不在语音输入时）
    ; 使用配置的长按时间（秒转换为毫秒）
    global CapsLockHoldTimeSeconds
    HoldTimeMs := Round(CapsLockHoldTimeSeconds * 1000)
    ; 确保时间在合理范围内（100ms到5000ms）
    if (HoldTimeMs < 100) {
        HoldTimeMs := 100
    } else if (HoldTimeMs > 5000) {
        HoldTimeMs := 5000
    }
    SetTimer(ShowPanelTimer, -HoldTimeMs)
    
    ; 等待 CapsLock 释放
    KeyWait("CapsLock")
    
    ; 停止所有定时器
    SetTimer(ClearCapsLock2Timer, 0)
    SetTimer(ShowPanelTimer, 0)
    
    ; 延迟清除 CapsLock 变量，给快捷键处理函数足够的时间
    ; 如果 CapsLock2 已被清除（说明使用了功能），延迟清除 CapsLock
    ; 如果 CapsLock2 仍为 true（说明没有使用功能），立即清除 CapsLock
    if (!CapsLock2) {
        ; 使用了功能，延迟清除 CapsLock（给快捷键处理函数时间）
        SetTimer(ClearCapsLockTimer, -100)
    } else {
        ; 没有使用功能，立即清除 CapsLock
        CapsLock := false
    }
    
    ; 如果 CapsLock2 还存在（说明没有使用过 CapsLock+ 功能），就切换大小写
    if (CapsLock2) {
        ; 切换 CapsLock 状态
        SetCapsLockState(GetKeyState("CapsLock", "T") ? "Off" : "On")
    }
    
    ; 清除标记
    CapsLock2 := false
    
    ; 如果面板还在显示，检查是否置顶，如果置顶则不自动隐藏
    if (PanelVisible) {
        global CursorPanelAlwaysOnTop
        ; 只有当面板未置顶时才自动隐藏
        if (!CursorPanelAlwaysOnTop) {
            HideCursorPanel()
        }
    }
    IsCommandMode := false
}

; ===================== 多屏幕支持函数 =====================
GetScreenInfo(ScreenIndex) {
    ; 获取指定屏幕的信息
    ; ScreenIndex: 1=主屏幕, 2=第二个屏幕, 等等
    ; 使用 MonitorGet 函数（AutoHotkey v2）
    try {
        MonitorGet(ScreenIndex, &Left, &Top, &Right, &Bottom)
        return {Left: Left, Top: Top, Right: Right, Bottom: Bottom, Width: Right - Left, Height: Bottom - Top}
    } catch as e {
        ; 如果失败，使用主屏幕
        try {
            MonitorGet(1, &Left, &Top, &Right, &Bottom)
            return {Left: Left, Top: Top, Right: Right, Bottom: Bottom, Width: Right - Left, Height: Bottom - Top}
        } catch {
            ; 如果还是失败，使用默认屏幕尺寸
            return {Left: 0, Top: 0, Right: A_ScreenWidth, Bottom: A_ScreenHeight, Width: A_ScreenWidth, Height: A_ScreenHeight}
        }
    }
}

GetPanelPosition(ScreenInfo, Width, Height, PosType := "Center") {
    ; 默认为居中
    X := ScreenInfo.Left + (ScreenInfo.Width - Width) // 2
    Y := ScreenInfo.Top + (ScreenInfo.Height - Height) // 2
    
    switch PosType {
        case "TopLeft":
            X := ScreenInfo.Left + 20
            Y := ScreenInfo.Top + 20
        case "TopRight":
            X := ScreenInfo.Right - Width - 20
            Y := ScreenInfo.Top + 20
        case "BottomLeft":
            X := ScreenInfo.Left + 20
            Y := ScreenInfo.Bottom - Height - 20
        case "BottomRight":
            X := ScreenInfo.Right - Width - 20
            Y := ScreenInfo.Bottom - Height - 20
    }
    
    return {X: X, Y: Y}
}

; 获取窗口所在的屏幕索引
GetWindowScreenIndex(WinTitle) {
    try {
        ; 获取窗口位置
        WinGetPos(&WinX, &WinY, &WinW, &WinH, WinTitle)
        
        ; 计算窗口中心点
        WinCenterX := WinX + WinW // 2
        WinCenterY := WinY + WinH // 2
        
        ; 遍历所有屏幕，找到包含该点的屏幕
        MonitorCount := MonitorGetCount()
        Loop MonitorCount {
            MonitorIndex := A_Index
            MonitorGet(MonitorIndex, &Left, &Top, &Right, &Bottom)
            
            ; 检查窗口中心点是否在此屏幕范围内
            if (WinCenterX >= Left && WinCenterX < Right && WinCenterY >= Top && WinCenterY < Bottom) {
                return MonitorIndex
            }
        }
        
        ; 如果没找到，返回主屏幕
        return 1
    } catch {
        ; 出错时返回主屏幕
        return 1
    }
}

; ===================== 显示面板函数 =====================
ShowCursorPanel() {
    global PanelVisible, GuiID_CursorPanel, SplitHotkey, BatchHotkey, CapsLock2
    global CursorPanelScreenIndex, FunctionPanelPos, QuickActionButtons
    global UI_Colors, ThemeMode, CursorPanelAlwaysOnTop, CursorPanelAutoHide, CursorPanelHidden
    
    if (PanelVisible) {
        return
    }
    
    CapsLock2 := false  ; 清除标记，表示使用了功能（显示面板）
    PanelVisible := true
    
    ; 根据按钮数量计算面板高度
    ButtonCount := QuickActionButtons.Length
    ButtonHeight := 42
    ButtonSpacing := 50
    BaseHeight := 200  ; 标题、提示、说明文字、底部提示等基础高度（增加50px给说明文字区域）
    global CursorPanelHeight := BaseHeight + (ButtonCount * ButtonSpacing)
    
    ; 面板尺寸（Cursor 风格，更紧凑现代）
    global CursorPanelWidth := 420
    
    ; 如果面板已存在，先销毁
    if (GuiID_CursorPanel != 0) {
        try {
            GuiID_CursorPanel.Destroy()
        } catch {
            ; 忽略错误
        }
        global GuiID_CursorPanel := 0
    }
    
    ; 创建 GUI
    ; 使用主题颜色
    GuiID_CursorPanel := Gui("+AlwaysOnTop +ToolWindow -Caption -DPIScale")
    GuiID_CursorPanel.BackColor := UI_Colors.Background
    GuiID_CursorPanel.SetFont("s11 c" . UI_Colors.Text, "Segoe UI")
    
    ; 添加圆角和阴影效果（通过边框实现）
    ; 标题栏控制按钮（右侧）- 先创建按钮，确保在标题背景之上
    global CursorPanelAlwaysOnTopBtn, CursorPanelAutoHideBtn, CursorPanelCloseBtn
    BtnSize := 30
    BtnY := 10
    BtnSpacing := 5
    BtnStartX := 420 - (BtnSize * 3 + BtnSpacing * 2) - 10
    
    ; 标题区域（可拖动）- 调整宽度，不覆盖按钮区域
    ; 按钮区域从BtnStartX开始，所以标题背景只到BtnStartX-5
    TitleBgWidth := BtnStartX - 5
    TitleBg := GuiID_CursorPanel.Add("Text", "x0 y0 w" . TitleBgWidth . " h50 Background" . UI_Colors.Background, "")
    ; 添加拖动功能到标题栏
    TitleBg.OnEvent("Click", (*) => PostMessage(0xA1, 2))  ; 拖动窗口
    TitleText := GuiID_CursorPanel.Add("Text", "x20 y12 w" . (TitleBgWidth - 40) . " h26 Center c" . UI_Colors.Text, GetText("panel_title"))
    TitleText.SetFont("s13 Bold", "Segoe UI")
    ; 标题文本也可以拖动
    TitleText.OnEvent("Click", (*) => PostMessage(0xA1, 2))  ; 拖动窗口
    
    ; 置顶按钮
    CursorPanelAlwaysOnTopBtn := GuiID_CursorPanel.Add("Text", "x" . BtnStartX . " y" . BtnY . " w" . BtnSize . " h" . BtnSize . " Center 0x200 c" . UI_Colors.Text . " Background" . (CursorPanelAlwaysOnTop ? UI_Colors.BtnPrimary : UI_Colors.BtnBg) . " vCursorPanelAlwaysOnTopBtn", "📌")
    CursorPanelAlwaysOnTopBtn.SetFont("s12", "Segoe UI")
    CursorPanelAlwaysOnTopBtn.OnEvent("Click", ToggleCursorPanelAlwaysOnTop)
    HoverBtnWithAnimation(CursorPanelAlwaysOnTopBtn, (CursorPanelAlwaysOnTop ? UI_Colors.BtnPrimary : UI_Colors.BtnBg), UI_Colors.BtnPrimaryHover)
    
    ; 自动隐藏按钮
    CursorPanelAutoHideBtn := GuiID_CursorPanel.Add("Text", "x" . (BtnStartX + BtnSize + BtnSpacing) . " y" . BtnY . " w" . BtnSize . " h" . BtnSize . " Center 0x200 c" . UI_Colors.Text . " Background" . (CursorPanelAutoHide ? UI_Colors.BtnPrimary : UI_Colors.BtnBg) . " vCursorPanelAutoHideBtn", "🔲")
    CursorPanelAutoHideBtn.SetFont("s12", "Segoe UI")
    CursorPanelAutoHideBtn.OnEvent("Click", ToggleCursorPanelAutoHide)
    HoverBtnWithAnimation(CursorPanelAutoHideBtn, (CursorPanelAutoHide ? UI_Colors.BtnPrimary : UI_Colors.BtnBg), UI_Colors.BtnPrimaryHover)
    
    ; 关闭按钮
    CursorPanelCloseBtn := GuiID_CursorPanel.Add("Text", "x" . (BtnStartX + (BtnSize + BtnSpacing) * 2) . " y" . BtnY . " w" . BtnSize . " h" . BtnSize . " Center 0x200 cFFFFFF Background" . UI_Colors.BtnBg . " vCursorPanelCloseBtn", "✕")
    CursorPanelCloseBtn.SetFont("s14", "Segoe UI")
    CursorPanelCloseBtn.OnEvent("Click", CloseCursorPanel)
    HoverBtnWithAnimation(CursorPanelCloseBtn, UI_Colors.BtnBg, "e81123")
    
    ; 分隔线（使用层叠投影替代1px边框）
    ; 底层：大范围、低饱和度、模糊阴影
    global ThemeMode
    OuterShadowColor := (ThemeMode = "light") ? "E0E0E0" : "1A1A1A"
    InnerShadowColor := (ThemeMode = "light") ? "B0B0B0" : "2A2A2A"
    ; 底层阴影（3层渐变）
    Loop 3 {
        LayerOffset := 4 + (A_Index - 1) * 1
        LayerAlpha := 255 - (A_Index - 1) * 60
        LayerColor := BlendColor(OuterShadowColor, (ThemeMode = "light") ? "FFFFFF" : "000000", LayerAlpha / 255)
        GuiID_CursorPanel.Add("Text", "x0 y" . (50 + LayerOffset) . " w420 h1 Background" . LayerColor, "")
    }
    ; 顶层阴影（紧凑、深色）
    GuiID_CursorPanel.Add("Text", "x0 y51 w420 h1 Background" . InnerShadowColor, "")
    
    ; 提示文本（更小的字体，更柔和的颜色）
    HintText := GuiID_CursorPanel.Add("Text", "x20 y60 w380 h18 Center c" . UI_Colors.TextDim, FormatText("split_hint", SplitHotkey, BatchHotkey))
    HintText.SetFont("s9", "Segoe UI")
    
    ; 按钮区域（根据配置动态创建）
    ButtonY := 90
    for Index, Button in QuickActionButtons {
        ; 获取按钮文本和功能
        ButtonText := ""
        ButtonAction := (*) => {}
        
        ; 获取基础文本（不包含快捷键）
        BaseText := ""
        switch Button.Type {
            case "Explain":
                BaseText := GetText("explain_code")
                ButtonAction := (*) => ExecutePrompt("Explain")
            case "Refactor":
                BaseText := GetText("refactor_code")
                ButtonAction := (*) => ExecutePrompt("Refactor")
            case "Optimize":
                BaseText := GetText("optimize_code")
                ButtonAction := (*) => ExecutePrompt("Optimize")
            case "Config":
                BaseText := GetText("open_config")
                ButtonAction := OpenConfigFromPanel
            case "Copy":
                BaseText := GetText("hotkey_c")
                ButtonAction := (*) => CapsLockCopy()
            case "Paste":
                BaseText := GetText("hotkey_v")
                ButtonAction := (*) => CapsLockPaste()
            case "Clipboard":
                BaseText := GetText("hotkey_x")
                ButtonAction := CreateClipboardAction()
            case "Voice":
                BaseText := GetText("hotkey_z")
                ButtonAction := CreateVoiceAction()
            case "Split":
                BaseText := GetText("hotkey_s")
                ButtonAction := (*) => SplitCode()
            case "Batch":
                BaseText := GetText("hotkey_b")
                ButtonAction := (*) => BatchOperation()
            case "CommandPalette":
                BaseText := GetText("quick_action_type_command_palette")
                ButtonAction := (*) => ExecuteCursorShortcut("^+p")
            case "Terminal":
                BaseText := GetText("quick_action_type_terminal")
                ButtonAction := (*) => ExecuteCursorShortcut("^+``")
            case "GlobalSearch":
                BaseText := GetText("quick_action_type_global_search")
                ButtonAction := (*) => ExecuteCursorShortcut("^+f")
            case "Explorer":
                BaseText := GetText("quick_action_type_explorer")
                ButtonAction := (*) => ExecuteCursorShortcut("^+e")
            case "SourceControl":
                BaseText := GetText("quick_action_type_source_control")
                ButtonAction := (*) => ExecuteCursorShortcut("^+g")
            case "Extensions":
                BaseText := GetText("quick_action_type_extensions")
                ButtonAction := (*) => ExecuteCursorShortcut("^+x")
            case "Browser":
                BaseText := GetText("quick_action_type_browser")
                ButtonAction := (*) => ExecuteCursorShortcut("^+b")
            case "Settings":
                BaseText := GetText("quick_action_type_settings")
                ButtonAction := (*) => ExecuteCursorShortcut("^+j")
            case "CursorSettings":
                BaseText := GetText("quick_action_type_cursor_settings")
                ButtonAction := (*) => ExecuteCursorShortcut("^,")
        }
        
        ; 替换快捷键（将默认快捷键替换为配置的快捷键）
        ; 例如："解释代码 (E)" -> "解释代码 (e)"（如果配置的是e）
        ; 如果 Hotkey 为空（新增的 Cursor 快捷键选项），不显示快捷键
        if (Button.Hotkey != "") {
            HotkeyUpper := StrUpper(Button.Hotkey)
            ; 尝试替换常见的默认快捷键
            ButtonText := StrReplace(BaseText, " (E)", " (" . HotkeyUpper . ")")
            ButtonText := StrReplace(ButtonText, " (R)", " (" . HotkeyUpper . ")")
            ButtonText := StrReplace(ButtonText, " (O)", " (" . HotkeyUpper . ")")
            ButtonText := StrReplace(ButtonText, " (Q)", " (" . HotkeyUpper . ")")
            ButtonText := StrReplace(ButtonText, " (C)", " (" . HotkeyUpper . ")")
            ButtonText := StrReplace(ButtonText, " (V)", " (" . HotkeyUpper . ")")
            ButtonText := StrReplace(ButtonText, " (X)", " (" . HotkeyUpper . ")")
            ButtonText := StrReplace(ButtonText, " (Z)", " (" . HotkeyUpper . ")")
            ButtonText := StrReplace(ButtonText, " (S)", " (" . HotkeyUpper . ")")
            ButtonText := StrReplace(ButtonText, " (B)", " (" . HotkeyUpper . ")")
            ; 如果替换失败，直接添加快捷键
            if (ButtonText = BaseText) {
                ; 提取基础文本（去掉括号部分）
                if (RegExMatch(BaseText, "^(.*?)\s*\([^)]+\)", &Match)) {
                    ButtonText := Match[1] . " (" . HotkeyUpper . ")"
                } else {
                    ButtonText := BaseText . " (" . HotkeyUpper . ")"
                }
            }
        } else {
            ; Hotkey 为空，直接使用基础文本
            ButtonText := BaseText
        }
        
        ; 获取按钮对应的说明文字
        ButtonDesc := ""
        switch Button.Type {
            case "Explain":
                ButtonDesc := GetText("hotkey_e_desc")
            case "Refactor":
                ButtonDesc := GetText("hotkey_r_desc")
            case "Optimize":
                ButtonDesc := GetText("hotkey_o_desc")
            case "Config":
                ButtonDesc := GetText("hotkey_q_desc")
            case "Copy":
                ButtonDesc := GetText("hotkey_c_desc")
            case "Paste":
                ButtonDesc := GetText("hotkey_v_desc")
            case "Clipboard":
                ButtonDesc := GetText("hotkey_x_desc")
            case "Voice":
                ButtonDesc := GetText("hotkey_z_desc")
            case "Split":
                ButtonDesc := GetText("hotkey_s_desc")
            case "Batch":
                ButtonDesc := GetText("hotkey_b_desc")
            case "CommandPalette":
                ButtonDesc := GetText("quick_action_desc_command_palette")
            case "Terminal":
                ButtonDesc := GetText("quick_action_desc_terminal")
            case "GlobalSearch":
                ButtonDesc := GetText("quick_action_desc_global_search")
            case "Explorer":
                ButtonDesc := GetText("quick_action_desc_explorer")
            case "SourceControl":
                ButtonDesc := GetText("quick_action_desc_source_control")
            case "Extensions":
                ButtonDesc := GetText("quick_action_desc_extensions")
            case "Browser":
                ButtonDesc := GetText("quick_action_desc_browser")
            case "Settings":
                ButtonDesc := GetText("quick_action_desc_settings")
            case "CursorSettings":
                ButtonDesc := GetText("quick_action_desc_cursor_settings")
        }
        
        ; 创建按钮，添加点击事件以更新说明文字
        Btn := GuiID_CursorPanel.Add("Button", "x30 y" . ButtonY . " w360 h" . ButtonHeight, ButtonText)
        ; 按钮文字颜色：亮色模式下使用深色文字，暗色模式下使用白色文字
        global ThemeMode
        BtnTextColor := (ThemeMode = "light") ? UI_Colors.Text : "FFFFFF"
        Btn.SetFont("s11 c" . BtnTextColor, "Segoe UI")
        ; 创建包装函数，同时更新说明文字和执行操作
        WrappedAction := CreateButtonActionWithDesc(ButtonAction, ButtonDesc)
        Btn.OnEvent("Click", WrappedAction)
        
        ; 保存按钮说明文字到按钮对象，用于鼠标悬停时更新说明文字
        ; 使用 WM_MOUSEMOVE 消息来检测鼠标悬停（Button 控件不支持 MouseMove 事件）
        Btn.ButtonDesc := ButtonDesc
        
        ButtonY += ButtonSpacing
    }
    
    ; 说明文字显示区域（在按钮和底部提示之间）
    DescY := ButtonY + 5
    global CursorPanelDescText := GuiID_CursorPanel.Add("Text", "x20 y" . DescY . " w380 h40 Center c" . UI_Colors.TextDim . " vCursorPanelDescText", "")
    CursorPanelDescText.SetFont("s9", "Segoe UI")
    
    ; 初始显示第一个按钮的说明（如果有按钮）
    if (QuickActionButtons.Length > 0) {
        FirstButtonDesc := ""
        switch QuickActionButtons[1].Type {
            case "Explain":
                FirstButtonDesc := GetText("hotkey_e_desc")
            case "Refactor":
                FirstButtonDesc := GetText("hotkey_r_desc")
            case "Optimize":
                FirstButtonDesc := GetText("hotkey_o_desc")
            case "Config":
                FirstButtonDesc := GetText("hotkey_q_desc")
            case "Copy":
                FirstButtonDesc := GetText("hotkey_c_desc")
            case "Paste":
                FirstButtonDesc := GetText("hotkey_v_desc")
            case "Clipboard":
                FirstButtonDesc := GetText("hotkey_x_desc")
            case "Voice":
                FirstButtonDesc := GetText("hotkey_z_desc")
            case "Split":
                FirstButtonDesc := GetText("hotkey_s_desc")
            case "Batch":
                FirstButtonDesc := GetText("hotkey_b_desc")
            case "CommandPalette":
                FirstButtonDesc := GetText("quick_action_desc_command_palette")
            case "Terminal":
                FirstButtonDesc := GetText("quick_action_desc_terminal")
            case "GlobalSearch":
                FirstButtonDesc := GetText("quick_action_desc_global_search")
            case "Explorer":
                FirstButtonDesc := GetText("quick_action_desc_explorer")
            case "SourceControl":
                FirstButtonDesc := GetText("quick_action_desc_source_control")
            case "Extensions":
                FirstButtonDesc := GetText("quick_action_desc_extensions")
            case "Browser":
                FirstButtonDesc := GetText("quick_action_desc_browser")
            case "Settings":
                FirstButtonDesc := GetText("quick_action_desc_settings")
            case "CursorSettings":
                FirstButtonDesc := GetText("quick_action_desc_cursor_settings")
        }
        if (FirstButtonDesc != "") {
            CursorPanelDescText.Text := FirstButtonDesc
        }
    }
    
    ; 底部提示文本
    FooterY := DescY + 45
    FooterText := GuiID_CursorPanel.Add("Text", "x20 y" . FooterY . " w380 h50 Center c" . UI_Colors.TextDim, GetText("footer_hint"))
    FooterText.SetFont("s9", "Segoe UI")
    
    ; 底部边框
    GuiID_CursorPanel.Add("Text", "x0 y" . (CursorPanelHeight - 10) . " w420 h10 Background" . UI_Colors.Background, "")
    
    ; 获取屏幕信息并计算位置
    ScreenInfo := GetScreenInfo(CursorPanelScreenIndex)
    Pos := GetPanelPosition(ScreenInfo, CursorPanelWidth, CursorPanelHeight, FunctionPanelPos)
    
    ; 显示面板
    GuiID_CursorPanel.Show("w" . CursorPanelWidth . " h" . CursorPanelHeight . " x" . Pos.X . " y" . Pos.Y . " NoActivate")
    
    ; 根据置顶状态设置窗口
    if (CursorPanelAlwaysOnTop) {
        WinSetAlwaysOnTop(1, GuiID_CursorPanel.Hwnd)
    } else {
        WinSetAlwaysOnTop(0, GuiID_CursorPanel.Hwnd)
    }
    
    ; 启动定时器检测窗口位置（用于自动隐藏功能）
    if (CursorPanelAutoHide) {
        SetTimer(CheckCursorPanelEdge, 500)  ; 每500ms检测一次
    }
}

; ===================== 切换面板置顶状态 =====================
ToggleCursorPanelAlwaysOnTop(*) {
    global CursorPanelAlwaysOnTop, GuiID_CursorPanel, CursorPanelAlwaysOnTopBtn, UI_Colors, PanelVisible
    
    ; 确保面板保持显示状态
    if (!PanelVisible || GuiID_CursorPanel = 0) {
        return
    }
    
    CursorPanelAlwaysOnTop := !CursorPanelAlwaysOnTop
    
    if (CursorPanelAlwaysOnTop) {
        WinSetAlwaysOnTop(1, GuiID_CursorPanel.Hwnd)
        CursorPanelAlwaysOnTopBtn.Opt("+Background" . UI_Colors.BtnPrimary)
    } else {
        WinSetAlwaysOnTop(0, GuiID_CursorPanel.Hwnd)
        CursorPanelAlwaysOnTopBtn.Opt("+Background" . UI_Colors.BtnBg)
    }
    
    ; 确保面板保持显示（不关闭）
    if (GuiID_CursorPanel != 0) {
        try {
            if (!WinExist("ahk_id " . GuiID_CursorPanel.Hwnd)) {
                return
            }
            ; 刷新窗口以确保状态更新
            WinRedraw(GuiID_CursorPanel.Hwnd)
        } catch {
            ; 忽略错误
        }
    }
}

; ===================== 更新面板说明文字 =====================
UpdateCursorPanelDesc(Desc) {
    global CursorPanelDescText
    if (CursorPanelDescText != 0) {
        try {
            CursorPanelDescText.Text := Desc
        } catch {
            ; 忽略错误
        }
    }
}

; ===================== 恢复默认面板说明文字 =====================
RestoreDefaultCursorPanelDesc() {
    global CursorPanelDescText, QuickActionButtons
    if (CursorPanelDescText != 0 && QuickActionButtons.Length > 0) {
        try {
            FirstButtonDesc := ""
            switch QuickActionButtons[1].Type {
                case "Explain":
                    FirstButtonDesc := GetText("hotkey_e_desc")
                case "Refactor":
                    FirstButtonDesc := GetText("hotkey_r_desc")
                case "Optimize":
                    FirstButtonDesc := GetText("hotkey_o_desc")
                case "Config":
                    FirstButtonDesc := GetText("hotkey_q_desc")
                case "Copy":
                    FirstButtonDesc := GetText("hotkey_c_desc")
                case "Paste":
                    FirstButtonDesc := GetText("hotkey_v_desc")
                case "Clipboard":
                    FirstButtonDesc := GetText("hotkey_x_desc")
                case "Voice":
                    FirstButtonDesc := GetText("hotkey_z_desc")
                case "Split":
                    FirstButtonDesc := GetText("hotkey_s_desc")
                case "Batch":
                    FirstButtonDesc := GetText("hotkey_b_desc")
                case "CommandPalette":
                    FirstButtonDesc := GetText("quick_action_desc_command_palette")
                case "Terminal":
                    FirstButtonDesc := GetText("quick_action_desc_terminal")
                case "GlobalSearch":
                    FirstButtonDesc := GetText("quick_action_desc_global_search")
                case "Explorer":
                    FirstButtonDesc := GetText("quick_action_desc_explorer")
                case "SourceControl":
                    FirstButtonDesc := GetText("quick_action_desc_source_control")
                case "Extensions":
                    FirstButtonDesc := GetText("quick_action_desc_extensions")
                case "Browser":
                    FirstButtonDesc := GetText("quick_action_desc_browser")
                case "Settings":
                    FirstButtonDesc := GetText("quick_action_desc_settings")
                case "CursorSettings":
                    FirstButtonDesc := GetText("quick_action_desc_cursor_settings")
            }
            if (FirstButtonDesc != "") {
                CursorPanelDescText.Text := FirstButtonDesc
            }
        } catch {
            ; 忽略错误
        }
    }
}

; ===================== 切换面板自动隐藏 =====================
ToggleCursorPanelAutoHide(*) {
    global CursorPanelAutoHide, CursorPanelAutoHideBtn, UI_Colors, PanelVisible, GuiID_CursorPanel, CursorPanelHidden
    
    ; 确保面板保持显示状态
    if (!PanelVisible || GuiID_CursorPanel = 0) {
        return
    }
    
    CursorPanelAutoHide := !CursorPanelAutoHide
    
    if (CursorPanelAutoHide) {
        CursorPanelAutoHideBtn.Opt("+Background" . UI_Colors.BtnPrimary)
        SetTimer(CheckCursorPanelEdge, 500)  ; 启动检测定时器
        ; 立即检测一次，如果已经靠边则隐藏
        CheckCursorPanelEdge()
    } else {
        CursorPanelAutoHideBtn.Opt("+Background" . UI_Colors.BtnBg)
        SetTimer(CheckCursorPanelEdge, 0)  ; 停止检测定时器
        ; 如果面板已隐藏，恢复显示
        if (CursorPanelHidden) {
            RestoreCursorPanel()
        }
    }
    
    ; 确保面板保持显示（不关闭）
    if (GuiID_CursorPanel != 0) {
        try {
            if (!WinExist("ahk_id " . GuiID_CursorPanel.Hwnd)) {
                return
            }
            ; 刷新窗口以确保状态更新
            WinRedraw(GuiID_CursorPanel.Hwnd)
        } catch {
            ; 忽略错误
        }
    }
}

; ===================== 检测面板是否靠边 =====================
CheckCursorPanelEdge(*) {
    global GuiID_CursorPanel, CursorPanelAutoHide, CursorPanelHidden, CursorPanelWidth, CursorPanelHeight, CursorPanelScreenIndex
    
    if (!CursorPanelAutoHide || GuiID_CursorPanel = 0) {
        return
    }
    
    try {
        ; 获取窗口位置
        WinGetPos(&WinX, &WinY, &WinW, &WinH, GuiID_CursorPanel.Hwnd)
        
        ; 获取屏幕信息
        ScreenInfo := GetScreenInfo(CursorPanelScreenIndex)
        ScreenLeft := ScreenInfo.Left
        ScreenRight := ScreenInfo.Right
        ScreenTop := ScreenInfo.Top
        ScreenBottom := ScreenInfo.Bottom
        
        ; 检测是否靠边（允许5px的误差）
        EdgeThreshold := 5
        IsAtLeftEdge := (WinX <= ScreenLeft + EdgeThreshold)
        IsAtRightEdge := (WinX + WinW >= ScreenRight - EdgeThreshold)
        IsAtTopEdge := (WinY <= ScreenTop + EdgeThreshold)
        IsAtBottomEdge := (WinY + WinH >= ScreenBottom - EdgeThreshold)
        
        ; 如果靠边且未隐藏，则隐藏
        if ((IsAtLeftEdge || IsAtRightEdge || IsAtTopEdge || IsAtBottomEdge) && !CursorPanelHidden) {
            HideCursorPanelToEdge(IsAtLeftEdge, IsAtRightEdge, IsAtTopEdge, IsAtBottomEdge)
        }
        ; 如果不靠边且已隐藏，则恢复
        else if (!IsAtLeftEdge && !IsAtRightEdge && !IsAtTopEdge && !IsAtBottomEdge && CursorPanelHidden) {
            RestoreCursorPanel()
        }
    } catch {
        ; 忽略错误
    }
}

; ===================== 隐藏面板到边缘 =====================
HideCursorPanelToEdge(IsLeft, IsRight, IsTop, IsBottom) {
    global GuiID_CursorPanel, CursorPanelHidden, CursorPanelWidth, CursorPanelHeight, CursorPanelScreenIndex
    
    if (GuiID_CursorPanel = 0) {
        return
    }
    
    try {
        ; 获取屏幕信息
        ScreenInfo := GetScreenInfo(CursorPanelScreenIndex)
        
        ; 计算隐藏后的位置和大小（只显示一个小条）
        HideBarWidth := 30
        HideBarHeight := 100
        
        if (IsLeft) {
            ; 靠左：显示在左边，垂直居中
            NewX := ScreenInfo.Left
            NewY := ScreenInfo.Top + (ScreenInfo.Height - HideBarHeight) // 2
            NewW := HideBarWidth
            NewH := HideBarHeight
        } else if (IsRight) {
            ; 靠右：显示在右边，垂直居中
            NewX := ScreenInfo.Right - HideBarWidth
            NewY := ScreenInfo.Top + (ScreenInfo.Height - HideBarHeight) // 2
            NewW := HideBarWidth
            NewH := HideBarHeight
        } else if (IsTop) {
            ; 靠上：显示在上边，水平居中
            NewX := ScreenInfo.Left + (ScreenInfo.Width - HideBarWidth) // 2
            NewY := ScreenInfo.Top
            NewW := HideBarWidth
            NewH := HideBarHeight
        } else if (IsBottom) {
            ; 靠下：显示在下边，水平居中
            NewX := ScreenInfo.Left + (ScreenInfo.Width - HideBarWidth) // 2
            NewY := ScreenInfo.Bottom - HideBarHeight
            NewW := HideBarWidth
            NewH := HideBarHeight
        } else {
            return
        }
        
        ; 保存原始位置和大小
        WinGetPos(&OldX, &OldY, &OldW, &OldH, GuiID_CursorPanel.Hwnd)
        global CursorPanelOriginalX := OldX
        global CursorPanelOriginalY := OldY
        global CursorPanelOriginalW := OldW
        global CursorPanelOriginalH := OldH
        
        ; 调整窗口大小和位置
        GuiID_CursorPanel.Move(NewX, NewY, NewW, NewH)
        
        ; 隐藏大部分控件，只显示标题栏
        ; 这里简化处理，直接缩小窗口
        CursorPanelHidden := true
    } catch {
        ; 忽略错误
    }
}

; ===================== 恢复面板显示 =====================
RestoreCursorPanel() {
    global GuiID_CursorPanel, CursorPanelHidden, CursorPanelOriginalX, CursorPanelOriginalY, CursorPanelOriginalW, CursorPanelOriginalH, CursorPanelWidth, CursorPanelHeight, CursorPanelScreenIndex, FunctionPanelPos
    
    if (GuiID_CursorPanel = 0 || !CursorPanelHidden) {
        return
    }
    
    try {
        ; 恢复原始大小和位置
        if (IsSet(CursorPanelOriginalX) && IsSet(CursorPanelOriginalY) && IsSet(CursorPanelOriginalW) && IsSet(CursorPanelOriginalH)) {
            GuiID_CursorPanel.Move(CursorPanelOriginalX, CursorPanelOriginalY, CursorPanelOriginalW, CursorPanelOriginalH)
        } else {
            ; 如果没有保存的位置，使用默认位置
            ScreenInfo := GetScreenInfo(CursorPanelScreenIndex)
            Pos := GetPanelPosition(ScreenInfo, CursorPanelWidth, CursorPanelHeight, FunctionPanelPos)
            GuiID_CursorPanel.Move(Pos.X, Pos.Y, CursorPanelWidth, CursorPanelHeight)
        }
        
        CursorPanelHidden := false
    } catch {
        ; 忽略错误
    }
}

; ===================== 关闭面板 =====================
CloseCursorPanel(*) {
    HideCursorPanel()
}

; ===================== 创建带说明文字的按钮操作 =====================
CreateButtonActionWithDesc(OriginalAction, Desc) {
    ; 返回一个函数，该函数会更新说明文字并执行原始操作
    ActionFunc(*) {
        ; 更新说明文字
        global CursorPanelDescText
        if (CursorPanelDescText) {
            CursorPanelDescText.Text := Desc
        }
        ; 执行原始操作
        OriginalAction()
    }
    return ActionFunc
}

; ===================== 创建剪贴板动作 =====================
CreateClipboardAction() {
    return ClipboardButtonAction
}

ClipboardButtonAction(*) {
    HideCursorPanel()
    ShowClipboardManager()
}

; ===================== 创建语音输入动作 =====================
CreateVoiceAction() {
    return VoiceButtonAction
}

VoiceButtonAction(*) {
    HideCursorPanel()
    StartVoiceInput()
}

; ===================== 隐藏面板函数 =====================
HideCursorPanel() {
    global PanelVisible, GuiID_CursorPanel, LastCursorPanelButton
    
    if (!PanelVisible) {
        return
    }
    
    PanelVisible := false
    
    ; 清除鼠标悬停按钮记录
    LastCursorPanelButton := 0
    
    ; 停止动态快捷键监听
    StopDynamicHotkeys()
    
    if (GuiID_CursorPanel != 0) {
        try {
            GuiID_CursorPanel.Hide()
        }
    }
}

; ===================== 从面板打开配置 =====================
OpenConfigFromPanel(*) {
    HideCursorPanel()
    ShowConfigGUI()
}

; ===================== 执行 Cursor 快捷键 =====================
ExecuteCursorShortcut(Shortcut) {
    global CursorPath, AISleepTime
    
    try {
        ; 检查 Cursor 是否运行
        if (!WinExist("ahk_exe Cursor.exe")) {
            if (CursorPath != "" && FileExist(CursorPath)) {
                Run(CursorPath)
                Sleep(AISleepTime)
            } else {
                TrayTip(GetText("cursor_not_running_error"), GetText("error"), "Iconx 2")
                return
            }
        }
        
        ; 激活 Cursor 窗口
        WinActivate("ahk_exe Cursor.exe")
        WinWaitActive("ahk_exe Cursor.exe", , 2)
        Sleep(200)
        
        ; 确保窗口已激活
        if (!WinActive("ahk_exe Cursor.exe")) {
            WinActivate("ahk_exe Cursor.exe")
            Sleep(200)
        }
        
        ; 发送快捷键
        Send(Shortcut)
    } catch as e {
        TrayTip("执行快捷键失败: " . e.Message, GetText("error"), "Iconx 2")
    }
}

; ===================== 执行提示词函数 =====================
ExecutePrompt(Type, TemplateID := "") {
    global Prompt_Explain, Prompt_Refactor, Prompt_Optimize, CursorPath, AISleepTime, IsCommandMode, CapsLock2, ClipboardHistory
    global DefaultTemplateIDs, PromptTemplates
    
    ; 清除标记，表示使用了功能
    CapsLock2 := false
    ; 标记命令模式结束，避免 CapsLock 释放后再次隐藏面板
    IsCommandMode := false
    
    HideCursorPanel()
    
    ; 根据类型选择提示词（优先使用模板系统）
    Prompt := ""
    
    ; 如果提供了TemplateID，直接使用模板
    if (TemplateID != "") {
        Template := GetTemplateByID(TemplateID)
        if (Template) {
            Prompt := Template.Content
        }
    }
    
    ; 如果没有TemplateID或模板未找到，使用默认模板或传统方式
    if (Prompt = "") {
        ; 尝试从默认模板映射获取
        if (DefaultTemplateIDs.Has(Type)) {
            TemplateID := DefaultTemplateIDs[Type]
            Template := GetTemplateByID(TemplateID)
            if (Template) {
                Prompt := Template.Content
            }
        }
        
        ; 如果模板系统未找到，回退到传统方式
        if (Prompt = "") {
            switch Type {
                case "Explain":
                    Prompt := Prompt_Explain
                case "Refactor":
                    Prompt := Prompt_Refactor
                case "Optimize":
                    Prompt := Prompt_Optimize
                case "BatchExplain":
                    Prompt := Prompt_Explain
                case "BatchRefactor":
                    Prompt := Prompt_Refactor
                case "BatchOptimize":
                    Prompt := Prompt_Optimize
            }
        }
    }
    
    if (Prompt = "") {
        return
    }
    
    ; 在切换窗口之前，先保存当前剪贴板内容并尝试复制选中文本
    ; 这样可以确保即使切换窗口后失去选中状态，也能获取到之前选中的文本
    ; 在切换窗口之前，先保存当前剪贴板内容
    OldClipboard := A_Clipboard
    
    ; 1. 保存当前剪贴板到历史记录（解决污染问题，防止用户数据丢失）
    if (OldClipboard != "") {
        ClipboardHistory.Push(OldClipboard)
    }
    
    SelectedCode := ""
    
    ; 尝试从当前活动窗口复制选中文本
    if WinActive("ahk_exe Cursor.exe") {
        Send("{Esc}")
        Sleep(50)
        A_Clipboard := "" ; 清空剪贴板以通过 ClipWait 检测
        Send("^c")
        if ClipWait(0.5) { ; 智能等待复制完成
            SelectedCode := A_Clipboard
        }
        ; 恢复剪贴板，避免影响后续判断
        A_Clipboard := OldClipboard
    } else {
        CurrentActiveWindow := WinGetID("A")
        A_Clipboard := ""
        Send("^c")
        if ClipWait(0.5) {
            SelectedCode := A_Clipboard
        }
        A_Clipboard := OldClipboard
    }
    
    ; 激活 Cursor 窗口
    try {
        if WinExist("ahk_exe Cursor.exe") {
            WinActivate("ahk_exe Cursor.exe")
            WinWaitActive("ahk_exe Cursor.exe", , 1)
            Sleep(200)
            
            ; 如果之前没有获取到选中文本，再次尝试在 Cursor 内复制
            if (SelectedCode = "" && WinActive("ahk_exe Cursor.exe")) {
                Send("{Esc}")
                Sleep(50)
                A_Clipboard := ""
                Send("^c")
                if ClipWait(0.5) {
                    SelectedCode := A_Clipboard
                }
                A_Clipboard := OldClipboard
            }
            
            ; 构建完整的提示词
            CodeBlockStart := "``````"
            CodeBlockEnd := "``````"
            if (SelectedCode != "") {
                FullPrompt := Prompt . "`n`n以下是选中的代码：`n" . CodeBlockStart . "`n" . SelectedCode . "`n" . CodeBlockEnd
            } else {
                FullPrompt := Prompt
            }
            
            ; 复制完整提示词到剪贴板
            A_Clipboard := FullPrompt
            if !ClipWait(1) {
                Sleep(100)
            }
            
            if !WinActive("ahk_exe Cursor.exe") {
                WinActivate("ahk_exe Cursor.exe")
                Sleep(200)
            }
            
            Send("{Esc}")
            Sleep(100)
            
            ; 打开聊天面板
            Send("^l")
            Sleep(400)
            
            if !WinActive("ahk_exe Cursor.exe") {
                WinActivate("ahk_exe Cursor.exe")
                Sleep(200)
            }
            
            ; 粘贴提示词
            Send("^v")
            Sleep(300) ; 等待粘贴完成
            
            ; 提交
            Send("{Enter}")
            
            ; 2. 恢复用户的原始剪贴板（解决污染问题）
            Sleep(200)
            A_Clipboard := OldClipboard
        } else {

            ; 如果 Cursor 未运行，尝试启动
            if (CursorPath != "" && FileExist(CursorPath)) {
                Run(CursorPath)
                Sleep(AISleepTime)
                
                ; 构建提示词（如果有选中文本）
                if (SelectedCode != "" && SelectedCode != OldClipboard && StrLen(SelectedCode) > 0) {
                    CodeBlockStart := "``````"
                    CodeBlockEnd := "``````"
                    FullPrompt := Prompt . "`n`n以下是选中的代码：`n" . CodeBlockStart . "`n" . SelectedCode . "`n" . CodeBlockEnd
                } else {
                    FullPrompt := Prompt
                }
                
                ; 复制提示词到剪贴板
                A_Clipboard := FullPrompt
                Sleep(100)
                Send("^l")
                Sleep(200)
                Send("^v")
                Sleep(100)
                Send("{Enter}")
            }
        }
    } catch as e {
        MsgBox("执行失败: " . e.Message)
    }
}

; ===================== 分割代码功能 =====================
SplitCode() {
    global CursorPath, AISleepTime, CapsLock2, ClipboardHistory
    
    CapsLock2 := false  ; 清除标记，表示使用了功能
    HideCursorPanel()
    
    try {
        if WinExist("ahk_exe Cursor.exe") {
            WinActivate("ahk_exe Cursor.exe")
            Sleep(200)
            
            ; 复制选中的代码
            OldClipboard := A_Clipboard
            ; 保存原始剪贴板到历史
            if (OldClipboard != "") {
                ClipboardHistory.Push(OldClipboard)
            }
            
            A_Clipboard := ""
            Send("^c")
            if !ClipWait(0.5) {
                A_Clipboard := OldClipboard
                TrayTip(GetText("select_code_first"), GetText("tip"), "Iconi")
                return
            }
            SelectedCode := A_Clipboard
            
            ; 插入分隔符
            Separator := "`n`n; ==================== 分割线 ====================`n`n"
            Send("{Right}")
            Send("{Enter}")
            A_Clipboard := Separator
            if ClipWait(0.5) {
                Send("^v")
                Sleep(200)
            }
            
            ; 恢复剪贴板
            A_Clipboard := OldClipboard
            
            TrayTip(GetText("split_marker_inserted"), GetText("tip"), "Iconi")
            
            TrayTip(GetText("split_marker_inserted"), GetText("tip"), "Iconi")
        } else {
            if (CursorPath != "" && FileExist(CursorPath)) {
                Run(CursorPath)
                Sleep(AISleepTime)
            }
        }
    } catch as e {
        MsgBox("分割失败: " . e.Message)
    }
}

; ===================== 批量操作功能 =====================
BatchOperation() {
    global PanelVisible, CapsLock2
    
    if (!PanelVisible) {
        return
    }
    
    CapsLock2 := false  ; 清除标记，表示使用了功能
    
    ; 显示批量操作选择菜单
    BatchMenu := Menu()
    BatchMenu.Add("批量解释", (*) => ExecutePrompt("BatchExplain"))
    BatchMenu.Add("批量重构", (*) => ExecutePrompt("BatchRefactor"))
    BatchMenu.Add("批量优化", (*) => ExecutePrompt("BatchOptimize"))
    
    ; 获取鼠标位置显示菜单
    MouseGetPos(&MouseX, &MouseY)
    BatchMenu.Show(MouseX, MouseY)
}

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
global HotkeyPEdit := 0
global PanelScreenRadio := []
; 已移除动画定时器，改用图片显示

; ===================== 标签切换函数 =====================
SwitchTab(TabName) {
    global ConfigTabs, CurrentTab
    global GeneralTabControls, AppearanceTabControls, PromptsTabControls, HotkeysTabControls, AdvancedTabControls
    
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
                } catch {
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
                } catch {
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
    
    ; 隐藏所有快捷键子标签页内容（防止覆盖其他标签页）
    global HotkeySubTabControls
    if (HotkeySubTabControls) {
        for Key, Controls in HotkeySubTabControls {
            if (Controls && Controls.Length > 0) {
                for Index, Ctrl in Controls {
                    if (Ctrl) {
                        try {
                            Ctrl.Visible := false
                        } catch {
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
                        } catch {
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
                        } catch {
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
                        } catch {
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
            ; 显示第一个子标签页（如果存在）
            global GeneralSubTabs
            if (GeneralSubTabControls && GeneralSubTabs) {
                ; 找到第一个子标签页
                FirstKey := ""
                for Key, TabBtn in GeneralSubTabs {
                    FirstKey := Key
                    break
                }
                if (FirstKey != "") {
                    SwitchGeneralSubTab(FirstKey)
                }
            }
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
                                    } catch {
                                    }
                                    ; 如果不是主标签按钮，则隐藏
                                    if (InStr(CtrlName, "PromptsMainTab") = 0) {
                                        Ctrl.Visible := false
                                    }
                                } catch {
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
                                } catch {
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
                                } catch {
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
                                } catch {
                                }
                            }
                        }
                    }
                } catch {
                }
            }
            
            ; 第三步：切换到模板管理标签页（这会显示对应的控件并隐藏其他标签页的控件）
            if (PromptsMainTabs && PromptsMainTabs.Has("manage")) {
                SwitchPromptsMainTab("manage")
            } else {
                ; 如果PromptsMainTabs还未初始化，延迟切换
                SetTimer(SwitchToManageTab, -100)
            }
        case "hotkeys":
            ShowControls(HotkeysTabControls)
            ; 显示第一个主标签页（快捷键设置）
            global HotkeysMainTabs
            if (HotkeysMainTabs && HotkeysMainTabs.Has("settings")) {
                SwitchHotkeysMainTab("settings")
            }
        case "advanced":
            ShowControls(AdvancedTabControls)
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
    CursorPathEdit := ConfigGUI.Add("Edit", "x" . (X + 30) . " y" . YPos . " w" . (W - 150) . " h30 vCursorPathEdit Background" . UI_Colors.InputBg . " c" . UI_Colors.Text, CursorPath)
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
    CapsLockHoldTimeEdit := ConfigGUI.Add("Edit", "x" . (X + 30) . " y" . YPos . " w150 h30 vCapsLockHoldTimeEdit Background" . UI_Colors.InputBg . " c" . UI_Colors.Text, CapsLockHoldTimeSeconds)
    CapsLockHoldTimeEdit.SetFont("s11", "Segoe UI")
    GeneralTabControls.Push(CapsLockHoldTimeEdit)
    
    YPos += 35
    HintCapsLockHoldTime := ConfigGUI.Add("Text", "x" . (X + 30) . " y" . YPos . " w" . (W - 60) . " h20 c" . UI_Colors.TextDim, GetText("capslock_hold_time_hint"))
    HintCapsLockHoldTime.SetFont("s9", "Segoe UI")
    GeneralTabControls.Push(HintCapsLockHoldTime)
    
    ; ========== 横向标签页区域（快捷操作按钮配置和搜索标签配置）==========
    TabBarY := YPos + 30  ; 缩小间距（从50px改为30px），为快捷操作按钮留出更多空间
    TabBarHeight := 40
    TabBarBg := ConfigGUI.Add("Text", "x" . (X + 30) . " y" . TabBarY . " w" . (W - 60) . " h" . TabBarHeight . " Background" . UI_Colors.Sidebar, "")
    GeneralTabControls.Push(TabBarBg)
    
    ; 创建两个子标签
    global GeneralSubTabs, GeneralSubTabControls
    GeneralSubTabs := Map()
    GeneralSubTabControls := Map()
    
    ; 子标签列表
    GeneralSubTabList := [
        {Key: "quickaction", Name: GetText("quick_action_config")},
        {Key: "searchcategory", Name: GetText("search_category_config")}
    ]
    
    ; 创建横向标签按钮
    TabWidth := (W - 60) / GeneralSubTabList.Length
    TabX := X + 30
    
    ; 创建横向标签点击处理函数
    CreateGeneralSubTabClickHandler(Key) {
        return (*) => SwitchGeneralSubTab(Key)
    }
    
    for Index, Item in GeneralSubTabList {
        ; 使用 Text 控件模拟 Material 风格按钮
        TabBtn := ConfigGUI.Add("Text", "x" . TabX . " y" . (TabBarY + 5) . " w" . (TabWidth - 2) . " h" . (TabBarHeight - 10) . " Center 0x200 vGeneralSubTab" . Item.Key, Item.Name)
        TabBtn.SetFont("s9", "Segoe UI")
        
        ; 使用主题颜色：默认未选中状态
        TabBtn.Opt("+Background" . UI_Colors.Sidebar)
        TabBtn.SetFont("s9 c" . UI_Colors.TextDim, "Segoe UI")
        
        TabBtn.OnEvent("Click", CreateGeneralSubTabClickHandler(Item.Key))
        ; 悬停效果使用主题颜色
        HoverBtnWithAnimation(TabBtn, UI_Colors.Sidebar, UI_Colors.BtnHover)
        GeneralTabControls.Push(TabBtn)
        GeneralSubTabs[Item.Key] := TabBtn
        TabX += TabWidth
    }
    
    global GeneralSubTabs := GeneralSubTabs
    
    ; 内容区域（显示当前选中的子标签页配置）
    ContentAreaY := TabBarY + TabBarHeight + 10  ; 缩小间距（从20px改为10px）
    ; 计算所需高度：5个按钮，每个136px，加上描述文字和间距，总共约750px
    ; 使用更大的高度值确保所有内容可见
    ContentAreaHeight := H - (ContentAreaY - Y) - 20
    ; 如果计算出的高度不够，使用固定高度
    if (ContentAreaHeight < 750) {
        ContentAreaHeight := 750
    }
    
    ; 为每个子标签创建内容面板
    for Index, Item in GeneralSubTabList {
        CreateGeneralSubTab(ConfigGUI, X + 30, ContentAreaY, W - 60, ContentAreaHeight, Item)
    }
    
    ; 默认显示第一个子标签页
    if (GeneralSubTabList.Length > 0) {
        SwitchGeneralSubTab(GeneralSubTabList[1].Key)
    }
}

; ===================== 创建快捷操作按钮配置UI =====================
CreateQuickActionConfigUI(ConfigGUI, X, Y, W, ParentControls) {
    global QuickActionButtons, QuickActionConfigControls, UI_Colors, ThemeMode
    
    ; 清空之前的控件
    for Index, Ctrl in QuickActionConfigControls {
        try {
            Ctrl.Destroy()
        } catch {
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
        
        ; 获取当前选中类型的说明
        CurrentDesc := ""
        for TypeIndex, ActionType in ActionTypes {
            if (Button.Type = ActionType.Type) {
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
            if (Button.Type = ActionType.Type) {
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
                    } catch {
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
            SelectedText := (ThemeMode = "dark") ? "E0E0E0" : "FFFFFF"
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
                    } catch {
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
            } catch {
                ; 忽略已销毁的控件
            }
        }
    }
    SearchCategoryConfigControls := []
    
    ; 所有可用的标签
    AllCategories := [
        {Key: "ai", Text: GetText("search_category_ai")},
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
        global VoiceSearchEnabledCategories := ["ai", "academic", "baidu", "image", "audio", "video", "book", "price", "medical", "cloud"]
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
    
    ; 更新按钮文本和样式
    try {
        if (AutoStartBtn && IsObject(AutoStartBtn)) {
            BtnText := AutoStart ? "开机自启动" : "不开机自启动"
            BtnBgColor := AutoStart ? UI_Colors.BtnPrimary : UI_Colors.BtnBg
            BtnTextColor := AutoStart ? "FFFFFF" : ((ThemeMode = "light") ? UI_Colors.Text : "FFFFFF")
            
            AutoStartBtn.Text := BtnText
            AutoStartBtn.BackColor := BtnBgColor
            AutoStartBtn.SetFont("s10 c" . BtnTextColor, "Segoe UI")
            
            ; 更新悬停效果
            HoverBtnWithAnimation(AutoStartBtn, BtnBgColor, AutoStart ? UI_Colors.BtnPrimaryHover : UI_Colors.BtnHover)
        }
    } catch {
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
    } catch {
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
            } catch {
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
    } catch {
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
    } catch {
        MonitorIndex := 1
        Loop 10 {
            try {
                MonitorGet(MonitorIndex, &Left, &Top, &Right, &Bottom)
                ScreenList.Push(FormatText("screen", MonitorIndex))
                MonitorCount++
                MonitorIndex++
            } catch {
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
    } catch {
        MonitorIndex := 1
        Loop 10 {
            try {
                MonitorGet(MonitorIndex, &Left, &Top, &Right, &Bottom)
                ScreenList.Push(FormatText("screen", MonitorIndex))
                MonitorCount++
                MonitorIndex++
            } catch {
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
    TextColor := (ThemeMode = "light") ? UI_Colors.Text : "FFFFFF"
    BtnY := TitleBarHeight + 370
    SaveBtn := EditGUI.Add("Text", "x20 y" . BtnY . " w120 h35 Center 0x200 c" . TextColor . " Background" . UI_Colors.BtnPrimary . " vSaveBtn", "保存")
    SaveBtn.SetFont("s10", "Segoe UI")
    SaveBtn.OnEvent("Click", (*) => SaveTemplateFromDialog(EditGUI, ""))
    HoverBtnWithAnimation(SaveBtn, UI_Colors.BtnPrimary, UI_Colors.BtnHover)
    
    CancelBtn := EditGUI.Add("Text", "x200 y" . BtnY . " w120 h35 Center 0x200 c" . TextColor . " Background" . UI_Colors.BtnBg . " vCancelBtn", "取消")
    CancelBtn.SetFont("s10", "Segoe UI")
    CancelBtn.OnEvent("Click", (*) => EditGUI.Destroy())
    HoverBtnWithAnimation(CancelBtn, UI_Colors.BtnBg, UI_Colors.BtnHover)
    
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
    TextColor := (ThemeMode = "light") ? UI_Colors.Text : "FFFFFF"
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
    TextColor := (ThemeMode = "light") ? UI_Colors.Text : "FFFFFF"
    BtnY := TitleBarHeight + 370
    SaveBtn := EditGUI.Add("Text", "x20 y" . BtnY . " w120 h35 Center 0x200 c" . TextColor . " Background" . UI_Colors.BtnPrimary . " vSaveBtn", "保存")
    SaveBtn.SetFont("s10", "Segoe UI")
    SaveBtn.OnEvent("Click", (*) => SaveTemplateFromDialog(EditGUI, TemplateID))
    HoverBtnWithAnimation(SaveBtn, UI_Colors.BtnPrimary, UI_Colors.BtnHover)
    
    CancelBtn := EditGUI.Add("Text", "x200 y" . BtnY . " w120 h35 Center 0x200 c" . TextColor . " Background" . UI_Colors.BtnBg . " vCancelBtn", "取消")
    CancelBtn.SetFont("s10", "Segoe UI")
    CancelBtn.OnEvent("Click", (*) => EditGUI.Destroy())
    HoverBtnWithAnimation(CancelBtn, UI_Colors.BtnBg, UI_Colors.BtnHover)
    
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
    } catch {
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
    TextColor := (ThemeMode = "light") ? UI_Colors.Text : "FFFFFF"
    
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
        
        TextColor := (ThemeMode = "light") ? UI_Colors.Text : "FFFFFF"
        
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
                    } catch {
                    }
                }
            }
        }
    }
    
    ; 设置当前标签样式
    if (PromptTemplateTabs.Has(TabIndex) && PromptTemplateTabs[TabIndex]) {
        try {
            TabBtn := PromptTemplateTabs[TabIndex]
            SelectedText := (ThemeMode = "dark") ? "E0E0E0" : "FFFFFF"
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
                    } catch {
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
    } catch {
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
                    } catch {
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
                    } catch {
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
                    } catch {
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
                        } catch {
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
                        } catch {
                        }
                    }
                }
            }
        }
    }
    
    ; 设置当前标签样式
    if (PromptsMainTabs.Has(TabKey) && PromptsMainTabs[TabKey]) {
        try {
            TabBtn := PromptsMainTabs[TabKey]
            SelectedText := (ThemeMode = "dark") ? "E0E0E0" : "FFFFFF"
            TabBtn.Opt("+Background" . UI_Colors.BtnPrimary)
            TabBtn.SetFont("s10 c" . SelectedText . " Bold", "Segoe UI")
            TabBtn.Redraw()
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
                    } catch {
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
                        } catch {
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
                        } catch {
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
                    } catch {
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
            } catch {
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
    
    TextColor := (ThemeMode = "light") ? UI_Colors.Text : "FFFFFF"
    
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
            SelectedText := (ThemeMode = "dark") ? "E0E0E0" : "FFFFFF"
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
                    } catch {
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
                    } catch {
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
        } catch {
        }
    }
    
    ; 刷新ListView显示（显示当前分类的模板）
    RefreshPromptListView()
    
    ; 刷新后再次确保ListView可见并刷新显示
    if (PromptManagerListView) {
        try {
            PromptManagerListView.Visible := true
            PromptManagerListView.Redraw()
        } catch {
        }
    }
}

; ===================== 刷新模板管理器ListView =====================
RefreshPromptListView() {
    global PromptManagerListView, CurrentPromptFolder, PromptTemplates, UI_Colors, ThemeMode
    
    if (!PromptManagerListView) {
        return
    }
    
    ; 确保ListView可见
    try {
        PromptManagerListView.Visible := true
    } catch {
    }
    
    ; 清空列表
    try {
        PromptManagerListView.Delete()
    } catch {
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
        } catch {
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
    } catch {
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
            
            PreviewGUI.Show("w640 h550")
            return
        }
    } catch {
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
    } catch {
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
    } catch {
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
    } catch {
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
        TextColor := (ThemeMode = "light") ? UI_Colors.Text : "FFFFFF"
        OkBtn := MoveGUI.Add("Text", "x120 y" . BtnY . " w80 h35 Center 0x200 c" . TextColor . " Background" . UI_Colors.BtnPrimary . " vMoveOkBtn", "确定")
        OkBtn.SetFont("s10", "Segoe UI")
        OkBtn.OnEvent("Click", CreateMoveTemplateConfirmHandler(MoveGUI, TargetTemplate, TemplateIndex))
        HoverBtnWithAnimation(OkBtn, UI_Colors.BtnPrimary, UI_Colors.BtnPrimaryHover)
        
        CancelBtn := MoveGUI.Add("Text", "x210 y" . BtnY . " w80 h35 Center 0x200 c" . TextColor . " Background" . UI_Colors.BtnBg . " vMoveCancelBtn", "取消")
        CancelBtn.SetFont("s10", "Segoe UI")
        CancelBtn.OnEvent("Click", CreateMoveCancelHandler(MoveGUI))
        HoverBtnWithAnimation(CancelBtn, UI_Colors.BtnBg, UI_Colors.BtnHover)
        
        ; 计算窗口高度（加上标题栏高度）
        WindowHeight := BtnY + 50 + TitleBarHeight
        MoveGUI.Show("w340 h" . WindowHeight)
    } catch {
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
    } catch {
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
    } catch {
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
        } catch {
        }
        
        MoveGUI.Destroy()
        TrayTip("已移动", "提示", "Iconi 1")
    } catch {
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
    
    TextColor := (ThemeMode = "light") ? UI_Colors.Text : "FFFFFF"
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
    TextColor := (ThemeMode = "light") ? UI_Colors.Text : "FFFFFF"
    OkBtn := MoveGUI.Add("Text", "x120 y" . BtnY . " w80 h35 Center 0x200 c" . TextColor . " Background" . UI_Colors.BtnPrimary . " vMoveOkBtn", "确定")
    OkBtn.SetFont("s10", "Segoe UI")
    OkBtn.OnEvent("Click", CreateMoveFromTemplateHandler(MoveGUI, Template))
    HoverBtnWithAnimation(OkBtn, UI_Colors.BtnPrimary, UI_Colors.BtnPrimaryHover)
    
    CancelBtn := MoveGUI.Add("Text", "x210 y" . BtnY . " w80 h35 Center 0x200 c" . TextColor . " Background" . UI_Colors.BtnBg . " vMoveCancelBtn", "取消")
    CancelBtn.SetFont("s10", "Segoe UI")
    CancelBtn.OnEvent("Click", CreateMoveFromTemplateCancelHandler(MoveGUI))
    HoverBtnWithAnimation(CancelBtn, UI_Colors.BtnBg, UI_Colors.BtnHover)
    
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
    } catch {
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
    } catch {
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
    } catch {
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
    } catch {
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
    } catch {
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
    } catch {
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
            } catch {
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
    global HotkeyESC, HotkeyC, HotkeyV, HotkeyX, HotkeyE, HotkeyR, HotkeyO, HotkeyQ, HotkeyZ, HotkeyP
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
    
    ; ========== 主标签页区域（快捷键设置 / Cursor规则）==========
    MainTabBarY := Y + 70
    MainTabBarHeight := 40
    MainTabBarBg := ConfigGUI.Add("Text", "x" . (X + 30) . " y" . MainTabBarY . " w" . (W - 60) . " h" . MainTabBarHeight . " Background" . UI_Colors.Sidebar, "")
    HotkeysTabControls.Push(MainTabBarBg)
    
    ; 创建主标签列表（移除rules，已转移到提示词标签页）
    MainTabList := [
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
    HotkeysTabControls.Push(TabBarBg)
    
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
        {Key: "P", Name: GetText("hotkey_p"), Default: HotkeyP, Edit: "HotkeyPEdit", Desc: "hotkey_p_desc", Hint: "hotkey_single_char_hint", DefaultVal: "p"}
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
        HotkeysTabControls.Push(TabBtn)
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
    
    ; 默认显示第一个主标签页（快捷键设置）
    SwitchHotkeysMainTab("settings")
}

; ===================== 创建快捷键子标签页 =====================
CreateHotkeySubTab(ConfigGUI, X, Y, W, H, Item) {
    global HotkeysTabControls, HotkeySubTabControls, UI_Colors
    global HotkeyESC, HotkeyC, HotkeyV, HotkeyX, HotkeyE, HotkeyR, HotkeyO, HotkeyQ, HotkeyZ, HotkeyP, HotkeyP
    global SplitHotkey, BatchHotkey
    global HotkeyESCEdit, HotkeyCEdit, HotkeyVEdit, HotkeyXEdit, HotkeyEEdit, HotkeyREdit, HotkeyOEdit, HotkeyQEdit, HotkeyZEdit, HotkeyPEdit
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
    } catch {
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
        } catch {
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
            return ImageDir . "\hotkey_p.png"
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
    } catch {
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
    } catch {
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
                    } catch {
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
            SelectedText := (ThemeMode = "dark") ? "E0E0E0" : "FFFFFF"
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
                    } catch {
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
                    } catch {
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
            SelectedText := (ThemeMode = "dark") ? "E0E0E0" : "FFFFFF"
            TabBtn.Opt("+Background" . UI_Colors.BtnPrimary)
            TabBtn.SetFont("s10 c" . SelectedText . " Bold", "Segoe UI")
            TabBtn.Redraw()
        }
    }
    
    ; 显示当前主标签页内容
    if (HotkeysMainTabControls.Has(MainTabKey)) {
        Controls := HotkeysMainTabControls[MainTabKey]
        if (Controls && Controls.Length > 0) {
            for Index, Ctrl in Controls {
                if (Ctrl) {
                    try {
                        Ctrl.Visible := true
                    } catch {
                        ; 忽略已销毁的控件
                    }
                }
            }
        }
    }
    
    ; 如果是快捷键设置标签，显示第一个快捷键子标签
    if (MainTabKey = "settings") {
        global HotkeySubTabs, HotkeySubTabControls
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
                    } catch {
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
    
    ; 规则内容区域（紧凑布局，确保复制按钮可见）
    ContentY := Y + 10
    ContentHeight := H - 80  ; 留出底部按钮空间（减少高度，更紧凑）
    
    ; 规则内容文本框（可编辑，方便用户查看和复制）
    RulesEdit := ConfigGUI.Add("Edit", "x" . X . " y" . ContentY . " w" . W . " h" . ContentHeight . " Background" . UI_Colors.InputBg . " c" . UI_Colors.Text . " Multi ReadOnly vCursorRulesContent" . Item.Key, GetText("cursor_rules_content_placeholder"))
    RulesEdit.SetFont("s10", "Consolas")
    RulesEdit.Visible := false  ; 默认隐藏，防止覆盖其他页面
    CursorRulesSubTabControls[Item.Key].Push(RulesEdit)
    
    ; 复制按钮（确保可见）
    CopyBtnY := Y + ContentHeight + 15  ; 减少间距，更紧凑
    CopyBtn := ConfigGUI.Add("Text", "x" . (X + W - 120) . " y" . CopyBtnY . " w100 h35 Center 0x200 cFFFFFF Background" . UI_Colors.BtnPrimary . " vCursorRulesCopyBtn" . Item.Key, GetText("cursor_rules_copy_btn"))
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
                    } catch {
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
            SelectedText := (ThemeMode = "dark") ? "E0E0E0" : "FFFFFF"
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
                    } catch {
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
            ; 复制到剪贴板
            A_Clipboard := RulesContent
            TrayTip(GetText("cursor_rules_copied"), GetText("tip"), "Iconi 1")
        }
    } catch as e {
        TrayTip("复制失败: " . e.Message, GetText("error"), "Iconx 2")
    }
}

; ===================== 创建高级标签页 =====================
CreateAdvancedTab(ConfigGUI, X, Y, W, H) {
    global AISleepTime, AdvancedTabPanel, AISleepTimeEdit, AdvancedTabControls
    global ConfigPanelScreenIndex, MsgBoxScreenIndex, VoiceInputScreenIndex, CursorPanelScreenIndex
    global ConfigPanelScreenRadio, MsgBoxScreenRadio, VoiceInputScreenRadio, CursorPanelScreenRadio
    global Language, LangChinese, LangEnglish, UI_Colors
    
    ; 创建标签页面板（默认隐藏）
    AdvancedTabPanel := ConfigGUI.Add("Text", "x" . X . " y" . Y . " w" . W . " h" . H . " Background" . UI_Colors.Background . " vAdvancedTabPanel", "")
    AdvancedTabPanel.Visible := false
    AdvancedTabControls.Push(AdvancedTabPanel)
    
    ; 标题
    Title := ConfigGUI.Add("Text", "x" . (X + 30) . " y" . (Y + 20) . " w" . (W - 60) . " h30 c" . UI_Colors.Text, GetText("advanced_settings"))
    Title.SetFont("s16 Bold", "Segoe UI")
    AdvancedTabControls.Push(Title)
    
    ; 自启动设置
    YPos := Y + 70
    LabelAutoStart := ConfigGUI.Add("Text", "x" . (X + 30) . " y" . YPos . " w200 h25 c" . UI_Colors.Text, GetText("auto_start"))
    LabelAutoStart.SetFont("s11", "Segoe UI")
    AdvancedTabControls.Push(LabelAutoStart)
    
    YPos += 30
    ; 创建自启动切换按钮（蓝色=开启，灰色=关闭）
    global AutoStartBtn
    BtnWidth := 200
    BtnHeight := 35
    BtnText := AutoStart ? "开机自启动" : "不开机自启动"
    BtnBgColor := AutoStart ? UI_Colors.BtnPrimary : UI_Colors.BtnBg
    BtnTextColor := AutoStart ? "FFFFFF" : ((ThemeMode = "light") ? UI_Colors.Text : "FFFFFF")
    
    AutoStartBtn := ConfigGUI.Add("Text", "x" . (X + 30) . " y" . YPos . " w" . BtnWidth . " h" . BtnHeight . " Center 0x200 c" . BtnTextColor . " Background" . BtnBgColor . " vAutoStartBtn", BtnText)
    AutoStartBtn.SetFont("s10", "Segoe UI")
    AutoStartBtn.OnEvent("Click", (*) => ToggleAutoStart())
    HoverBtnWithAnimation(AutoStartBtn, BtnBgColor, AutoStart ? UI_Colors.BtnPrimaryHover : UI_Colors.BtnHover)
    AdvancedTabControls.Push(AutoStartBtn)
    
    ; 语言设置（从通用设置移到这里）
    YPos += 60
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
    AISleepTimeEdit := ConfigGUI.Add("Edit", "x" . (X + 30) . " y" . YPos . " w150 h30 vAISleepTimeEdit Background" . UI_Colors.InputBg . " c" . UI_Colors.Text, AISleepTime)
    AISleepTimeEdit.SetFont("s11", "Segoe UI")
    AdvancedTabControls.Push(AISleepTimeEdit)
    
    YPos += 40
    Hint1 := ConfigGUI.Add("Text", "x" . (X + 30) . " y" . YPos . " w" . (W - 60) . " h20 c" . UI_Colors.TextDim, GetText("ai_wait_hint"))
    Hint1.SetFont("s9", "Segoe UI")
    AdvancedTabControls.Push(Hint1)
    
    ; 默认启动页面设置
    YPos += 80
    LabelDefaultStartTab := ConfigGUI.Add("Text", "x" . (X + 30) . " y" . YPos . " w200 h25 c" . UI_Colors.Text, "默认启动页面：")
    LabelDefaultStartTab.SetFont("s11", "Segoe UI")
    AdvancedTabControls.Push(LabelDefaultStartTab)
    
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
    ; 使用R5选项指定下拉列表显示5行（R选项设置下拉列表的高度）
    DefaultStartTabDDL := ConfigGUI.Add("DDL", "x" . (X + 30) . " y" . YPos . " w200 h30 R5 vDefaultStartTabDDL Background" . UI_Colors.DDLBg . " c" . UI_Colors.DDLText, StartTabOptions)
    DefaultStartTabDDL.SetFont("s10 c" . UI_Colors.DDLText, "Segoe UI")
    DefaultStartTabDDL.Value := DefaultIndex
    DefaultStartTabDDL.OnEvent("Change", (*) => OnDefaultStartTabChange())
    
    ; 保存下拉框句柄，用于在窗口显示后设置最小可见项数
    ; CB_SETMINVISIBLE需要在窗口完全创建并显示后才能生效
    try {
        DDL_Hwnd := DefaultStartTabDDL.Hwnd
        ; 保存句柄到全局变量，供窗口显示后的延迟函数使用
        global DefaultStartTabDDL_Hwnd_ForTimer
        DefaultStartTabDDL_Hwnd_ForTimer := DDL_Hwnd
    } catch {
        ; 如果获取句柄失败，忽略错误
    }
    
    ; 设置下拉框的背景色
    ; 使用DDLBg颜色来匹配Cursor主题色
    try {
        DefaultStartTabDDL.Opt("Background" . UI_Colors.DDLBg)
        ; 保存下拉框的句柄，用于消息处理
        global DefaultStartTabDDL_Hwnd
        DefaultStartTabDDL_Hwnd := DDL_Hwnd
        
        ; 创建画刷用于下拉列表背景色（DDLBg颜色）
        ; 将颜色从RRGGBB格式转换为BGR格式（Windows使用BGR格式）
        ColorCode := "0x" . UI_Colors.DDLBg
        RGBColor := Integer(ColorCode)
        ; 交换R和B字节（Windows使用BGR格式）
        R := (RGBColor & 0xFF0000) >> 16
        G := (RGBColor & 0x00FF00) >> 8
        B := RGBColor & 0x0000FF
        BGRColor := (B << 16) | (G << 8) | R
        global DDLBrush
        ; 如果已有画刷，先删除
        if (DDLBrush != 0) {
            try {
                DllCall("gdi32.dll\DeleteObject", "Ptr", DDLBrush)
            } catch {
            }
        }
        ; 创建实心画刷
        DDLBrush := DllCall("gdi32.dll\CreateSolidBrush", "UInt", BGRColor, "Ptr")
    } catch {
    }
    
    AdvancedTabControls.Push(DefaultStartTabDDL)
    
    YPos += 40
    HintDefaultStartTab := ConfigGUI.Add("Text", "x" . (X + 30) . " y" . YPos . " w" . (W - 60) . " h20 c" . UI_Colors.TextDim, "CapsLock+Q 启动配置界面时默认显示的页面")
    HintDefaultStartTab.SetFont("s9", "Segoe UI")
    AdvancedTabControls.Push(HintDefaultStartTab)
    
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
    TextColor := (ThemeMode = "light") ? UI_Colors.Text : "FFFFFF"
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
    
    ; 安装 Cursor 中文版按钮
    YPos += 60
    LabelInstallChinese := ConfigGUI.Add("Text", "x" . (X + 30) . " y" . YPos . " w200 h25 c" . UI_Colors.Text, GetText("install_cursor_chinese"))
    LabelInstallChinese.SetFont("s11", "Segoe UI")
    AdvancedTabControls.Push(LabelInstallChinese)
    
    YPos += 30
    TextColor := (ThemeMode = "light") ? UI_Colors.Text : "FFFFFF"
    InstallChineseBtn := ConfigGUI.Add("Text", "x" . BtnStartX . " y" . YPos . " w" . (BtnWidth * 2 + BtnSpacing) . " h" . BtnHeight . " Center 0x200 c" . TextColor . " Background" . UI_Colors.BtnBg . " vAdvancedInstallChineseBtn", GetText("install_cursor_chinese"))
    InstallChineseBtn.SetFont("s10", "Segoe UI")
    InstallChineseBtn.OnEvent("Click", InstallCursorChinese)
    HoverBtnWithAnimation(InstallChineseBtn, UI_Colors.BtnBg, UI_Colors.BtnHover)
    AdvancedTabControls.Push(InstallChineseBtn)
    
    YPos += 40
    HintInstallChinese := ConfigGUI.Add("Text", "x" . (X + 30) . " y" . YPos . " w" . (W - 60) . " h40 c" . UI_Colors.TextDim, GetText("install_cursor_chinese_desc"))
    HintInstallChinese.SetFont("s9", "Segoe UI")
    AdvancedTabControls.Push(HintInstallChinese)
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
    } catch {
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
        if (IsSet(HotkeyPEdit) && HotkeyPEdit) HotkeyPEdit.Value := "p"
        
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
    } catch {
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
        } catch {
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
        
        ; 步骤 1: 打开命令面板 (Ctrl + Shift + P)
        Sleep(500)
        Send("^+p")  ; Ctrl + Shift + P
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
    } catch {
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
    } catch {
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
    } catch {
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
    } catch {
    }
    
    try {
        Ctrl.IsAnimating := true
    } catch {
        ; 如果无法设置属性，直接设置颜色
        try {
            if (IsEntering) {
                Ctrl.BackColor := HoverColor
            } else {
                Ctrl.BackColor := NormalColor
            }
        } catch {
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
        } catch {
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
    } catch {
    }
    
    try {
        Ctrl.IsAnimating := false
    } catch {
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
    } catch {
        ; 忽略错误
    }
}

; 恢复按钮颜色的辅助函数
RestoreButtonColor(Ctrl, OriginalColor, *) {
    try {
        Ctrl.BackColor := OriginalColor
    } catch {
    }
}

; ===================== 创建Cursor风格的下拉框 =====================
; 创建一个带边框和Cursor风格样式的下拉框
CreateCursorDDL(Parent, X, Y, W, H, Options, VarName := "", ControlList := "") {
    global UI_Colors
    
    ; 外边框（浅灰色，模拟Cursor风格）
    DDLBorderOuter := Parent.Add("Text", "x" . X . " y" . Y . " w" . W . " h" . H . " Background" . UI_Colors.DDLBorder, "")
    if (ControlList != "") {
        ControlList.Push(DDLBorderOuter)
    }
    
    ; 内背景（深灰色，Cursor风格）
    DDLBgRect := Parent.Add("Text", "x" . (X + 1) . " y" . (Y + 1) . " w" . (W - 2) . " h" . (H - 2) . " Background" . UI_Colors.DDLBg, "")
    if (ControlList != "") {
        ControlList.Push(DDLBgRect)
    }
    
    ; 创建下拉框（内嵌2px以显示边框）
    DDL := Parent.Add("DDL", "x" . (X + 2) . " y" . (Y + 2) . " w" . (W - 4) . " h" . (H - 4) . " v" . VarName . " Background" . UI_Colors.DDLBg . " c" . UI_Colors.DDLText . " " . Options, [])
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
; 监听WM_CTLCOLORLISTBOX消息以自定义下拉列表背景色
OnMessage(0x0134, WM_CTLCOLORLISTBOX)

WM_CTLCOLORLISTBOX(wParam, lParam, Msg, Hwnd) {
    global DefaultStartTabDDL_Hwnd, DDLBrush, UI_Colors, MoveGUIListBoxHwnd, MoveGUIListBoxBrush, MoveFromTemplateListBoxHwnd, MoveFromTemplateListBoxBrush
    
    try {
        ; 检查是否是默认启动页面下拉框的列表框
        ; lParam是列表框的句柄，我们需要找到它的父ComboBox
        if (DefaultStartTabDDL_Hwnd != 0 && DDLBrush != 0) {
            ParentHwnd := DllCall("user32.dll\GetParent", "Ptr", lParam, "Ptr")
            if (ParentHwnd = DefaultStartTabDDL_Hwnd) {
                ; 将颜色从RRGGBB格式转换为BGR格式
                DDLTextColor := "0x" . UI_Colors.DDLText
                DDLBgColor := "0x" . UI_Colors.DDLBg
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
    } catch {
    }
    
    ; 如果不是我们的下拉框，返回0让系统使用默认处理
    return 0
}

WM_MOUSEMOVE(wParam, lParam, Msg, Hwnd) {
    global LastHoverCtrl, GuiID_CursorPanel, LastCursorPanelButton
    
    try {
        ; 获取鼠标下的控件
        MouseCtrl := GuiCtrlFromHwnd(Hwnd)
        
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
            } catch {
                ; 忽略错误
            }
        }
        
        ; 如果是新控件且具有 Hover 属性
        if (MouseCtrl && MouseCtrl.HasProp("HoverColor")) {
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
                        } catch {
                        }
                        
                        if (IsAnimating) {
                            ; 如果正在动画中，直接设置最终颜色
                            LastHoverCtrl.BackColor := LastHoverCtrl.NormalColor
                            try {
                                LastHoverCtrl.IsAnimating := false
                            } catch {
                            }
                        } else {
                            ; 使用动画过渡
                            AnimateButtonHover(LastHoverCtrl, LastHoverCtrl.NormalColor, LastHoverCtrl.HoverColor, false)
                        }
                    } catch {
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
                    } catch {
                    }
                    
                    if (!IsAnimating) {
                        AnimateButtonHover(MouseCtrl, MouseCtrl.NormalColor, MouseCtrl.HoverColor, true)
                    }
                } catch {
                    try MouseCtrl.BackColor := MouseCtrl.HoverColor
                }
                LastHoverCtrl := MouseCtrl
                
                ; 启动定时器检测鼠标离开
                SetTimer CheckMouseLeave, 50
            }
        }
    }
}

CheckMouseLeave() {
    global LastHoverCtrl, LastCursorPanelButton, GuiID_CursorPanel
    
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
                    } catch {
                        ; 如果出错，恢复默认说明
                        RestoreDefaultCursorPanelDesc()
                        LastCursorPanelButton := 0
                    }
                } else {
                    RestoreDefaultCursorPanelDesc()
                    LastCursorPanelButton := 0
                }
            }
        } catch {
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
                    } catch {
                    }
                    
                    ; 使用动画过渡恢复颜色
                    if (!IsAnimating) {
                        AnimateButtonHover(LastHoverCtrl, LastHoverCtrl.NormalColor, LastHoverCtrl.HoverColor, false)
                    } else {
                        LastHoverCtrl.BackColor := LastHoverCtrl.NormalColor
                        try {
                            LastHoverCtrl.IsAnimating := false
                        } catch {
                        }
                    }
                } catch {
                    try LastHoverCtrl.BackColor := LastHoverCtrl.NormalColor
                }
            }
            LastHoverCtrl := 0
            SetTimer , 0
        }
    } catch {
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
ShowConfigGUI() {
    global CursorPath, AISleepTime, Prompt_Explain, Prompt_Refactor, Prompt_Optimize
    global SplitHotkey, BatchHotkey, ConfigFile, Language
    global PanelScreenIndex, PanelPosition, ConfigPanelScreenIndex
    global UI_Colors, GuiID_ConfigGUI, GuiID_ClipboardManager
    
    ; 单例模式:如果配置面板已存在,直接激活
    if (GuiID_ConfigGUI != 0) {
        try {
            WinActivate(GuiID_ConfigGUI.Hwnd)
            return
        } catch {
            ; 如果窗口已被销毁,继续创建新的
            GuiID_ConfigGUI := 0
        }
    }
    
    ; 关闭剪贴板面板（确保一次只激活一个面板）
    if (GuiID_ClipboardManager != 0) {
        try {
            GuiID_ClipboardManager.Destroy()
            GuiID_ClipboardManager := 0
        } catch {
            GuiID_ClipboardManager := 0
        }
    }
    
    ; 清空全局控件数组，防止残留
    global GeneralTabControls := []
    global AppearanceTabControls := []
    global PromptsTabControls := []
    global HotkeysTabControls := []
    global AdvancedTabControls := []
    
    ; 创建配置 GUI（无边框窗口，无白边，无滚动条）
    ConfigGUI := Gui("+Resize -MaximizeBox -Caption", GetText("config_title"))
    ConfigGUI.SetFont("s10 c" . UI_Colors.Text, "Segoe UI")
    ConfigGUI.BackColor := UI_Colors.Background
    ; 启用窗口滚动（通过设置窗口样式和滚动区域）
    ; 添加滚动条样式（在窗口显示后设置）
    
    ; 窗口尺寸 - 全屏显示
    ScreenInfo := GetScreenInfo(PanelScreenIndex)
    global ConfigWidth := ScreenInfo.Width
    global ConfigHeight := ScreenInfo.Height
    
    ; 侧边栏宽度（全局变量，用于大小调整）
    global SidebarWidth := 150
    
    ; ========== 自定义标题栏 (35px) ==========
    TitleBar := ConfigGUI.Add("Text", "x0 y0 w" . ConfigWidth . " h35 Background" . UI_Colors.TitleBar . " vTitleBar", "")
    TitleBar.OnEvent("Click", (*) => PostMessage(0xA1, 2)) ; 拖动窗口
    
    ; 关闭按钮 - 四个角都设置（先创建关闭按钮，确保在最上层）
    ; 左上角关闭按钮（调整位置，不遮挡标题）
    CloseBtnTopLeft := ConfigGUI.Add("Text", "x0 y0 w35 h35 Center 0x200 Background" . UI_Colors.TitleBar . " c" . UI_Colors.Text . " vCloseBtnTopLeft", "✕")
    CloseBtnTopLeft.SetFont("s10", "Segoe UI")
    CloseBtnTopLeft.OnEvent("Click", (*) => CloseConfigGUI())
    HoverBtnWithAnimation(CloseBtnTopLeft, UI_Colors.TitleBar, "e81123") ; 红色关闭 hover（带动效）
    
    ; 窗口标题（调整位置，避免被左上角关闭按钮遮挡）
    WinTitle := ConfigGUI.Add("Text", "x40 y8 w" . (ConfigWidth - 80) . " h20 Background" . UI_Colors.TitleBar . " c" . UI_Colors.Text . " vWinTitle", GetText("config_title"))
    WinTitle.SetFont("s10 Bold", "Segoe UI")
    WinTitle.OnEvent("Click", (*) => PostMessage(0xA1, 2))
    
    ; 右上角关闭按钮
    CloseBtnTopRight := ConfigGUI.Add("Text", "x" . (ConfigWidth - 40) . " y0 w40 h35 Center 0x200 Background" . UI_Colors.TitleBar . " c" . UI_Colors.Text . " vCloseBtnTopRight", "✕")
    CloseBtnTopRight.SetFont("s10", "Segoe UI")
    CloseBtnTopRight.OnEvent("Click", (*) => CloseConfigGUI())
    HoverBtnWithAnimation(CloseBtnTopRight, UI_Colors.TitleBar, "e81123") ; 红色关闭 hover（带动效）
    
    ; 左下角关闭按钮
    CloseBtnBottomLeft := ConfigGUI.Add("Text", "x0 y" . (ConfigHeight - 40) . " w40 h40 Center 0x200 Background" . UI_Colors.Background . " c" . UI_Colors.Text . " vCloseBtnBottomLeft", "✕")
    CloseBtnBottomLeft.SetFont("s10", "Segoe UI")
    CloseBtnBottomLeft.OnEvent("Click", (*) => CloseConfigGUI())
    HoverBtnWithAnimation(CloseBtnBottomLeft, UI_Colors.Background, "e81123") ; 红色关闭 hover（带动效）
    
    ; 右下角关闭按钮
    CloseBtnBottomRight := ConfigGUI.Add("Text", "x" . (ConfigWidth - 40) . " y" . (ConfigHeight - 40) . " w40 h40 Center 0x200 Background" . UI_Colors.Background . " c" . UI_Colors.Text . " vCloseBtnBottomRight", "✕")
    CloseBtnBottomRight.SetFont("s10", "Segoe UI")
    CloseBtnBottomRight.OnEvent("Click", (*) => CloseConfigGUI())
    HoverBtnWithAnimation(CloseBtnBottomRight, UI_Colors.Background, "e81123") ; 红色关闭 hover（带动效）
    
    ; ========== 左侧侧边栏 (150px，更窄以给右侧更多空间) ==========
    ; SidebarWidth 已在上面声明为全局变量
    SidebarBg := ConfigGUI.Add("Text", "x0 y35 w" . SidebarWidth . " h" . (ConfigHeight - 35) . " Background" . UI_Colors.Sidebar . " vSidebarBg", "")
    
    ; 侧边栏搜索框
    SearchBg := ConfigGUI.Add("Text", "x10 y45 w" . (SidebarWidth - 20) . " h30 Background" . UI_Colors.InputBg, "")
    ; 放大镜图标
    SearchIcon := ConfigGUI.Add("Text", "x18 y50 w16 h16 Center 0x200 c" . UI_Colors.TextDim . " Background" . UI_Colors.InputBg, "🔍")
    SearchIcon.SetFont("s10", "Segoe UI")
    ; 搜索输入框（调整位置，为放大镜图标留出空间）
    global SearchEdit := ConfigGUI.Add("Edit", "x36 y50 w" . (SidebarWidth - 46) . " h20 vSearchEdit Background" . UI_Colors.InputBg . " c" . UI_Colors.Text . " -E0x200", "") 
    SearchEdit.SetFont("s9", "Segoe UI")
    
    global SearchHint := ConfigGUI.Add("Text", "x36 y50 w" . (SidebarWidth - 46) . " h20 c" . UI_Colors.TextDim . " Background" . UI_Colors.InputBg, GetText("search_placeholder"))
    SearchHint.SetFont("s9 Italic", "Segoe UI")
    
    ; 标签按钮起始位置
    TabY := 90
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
    
    ; ========== 右侧内容区域（可滚动）==========
    ContentX := SidebarWidth
    ContentWidth := ConfigWidth - SidebarWidth
    ContentY := 35
    ContentHeight := ConfigHeight - 35 - 50 ; 留出底部按钮空间
    
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
        "advanced", TabAdvanced
    )
    global ConfigTabs := ConfigTabs
    
    ; 创建各个标签页的内容面板 (注意: 此时传入的 Y 坐标是相对于窗口客户区的)
    ; 内容可以超出 ContentHeight，通过鼠标滚轮滚动查看
    CreateGeneralTab(ConfigGUI, ContentX, ContentY, ContentWidth, ContentHeight)
    CreateAppearanceTab(ConfigGUI, ContentX, ContentY, ContentWidth, ContentHeight)
    CreatePromptsTab(ConfigGUI, ContentX, ContentY, ContentWidth, ContentHeight)
    CreateHotkeysTab(ConfigGUI, ContentX, ContentY, ContentWidth, ContentHeight)
    CreateAdvancedTab(ConfigGUI, ContentX, ContentY, ContentWidth, ContentHeight)
    
    ; ========== 底部按钮区域 (右侧) ==========
    ButtonAreaY := ConfigHeight - 50  ; 减少高度（已移除说明文字）
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
    BtnStartX := ConfigWidth - (BtnWidth * 2 + BtnSpacing) - 20  ; 2个按钮，1个间距，右边距20
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
    
    ; 搜索功能绑定
    SearchEdit.OnEvent("Change", (*) => FilterSettings(SearchEdit.Value))
    SearchEdit.OnEvent("Focus", SearchEditFocus)
    SearchEdit.OnEvent("LoseFocus", SearchEditLoseFocus)
    
    ; 保存ConfigGUI引用
    GuiID_ConfigGUI := ConfigGUI
    
    ; 添加窗口大小调整事件处理
    ConfigGUI.OnEvent("Size", ConfigGUI_Size)
    ConfigGUI.OnEvent("Close", (*) => CloseConfigGUI())
    
    ; 全屏显示窗口
    ConfigGUI.Show("w" . ConfigWidth . " h" . ConfigHeight . " x" . PosX . " y" . PosY)
    
    ; 设置下拉列表最小可见项数（窗口显示后设置，延迟300ms确保ComboBox完全初始化）
    SetTimer(SetDDLMinVisible, -300)
    
    ; 设置窗口最小尺寸限制（使用 DllCall 调用 Windows API）
    SetWindowMinSizeLimit(ConfigGUI.Hwnd, 800, 600)
    
    ; 【移除滚动条】不再添加滚动条样式，避免出现白边和滚动条
    ; 移除窗口边框样式（WS_BORDER, WS_THICKFRAME）
    ; GWL_STYLE = -16
    CurrentStyle := DllCall("user32.dll\GetWindowLongPtr", "Ptr", ConfigGUI.Hwnd, "Int", -16, "Ptr")
    ; 移除边框和滚动条样式：~0x00B40000 = 移除 WS_BORDER(0x00800000), WS_THICKFRAME(0x00040000), WS_VSCROLL(0x00200000), WS_HSCROLL(0x00100000)
    NewStyle := CurrentStyle & ~0x00B40000
    DllCall("user32.dll\SetWindowLongPtr", "Ptr", ConfigGUI.Hwnd, "Int", -16, "Ptr", NewStyle, "Ptr")
    ; 移除扩展样式中的边框（WS_EX_CLIENTEDGE = 0x00000200）
    ; GWL_EXSTYLE = -20
    CurrentExStyle := DllCall("user32.dll\GetWindowLongPtr", "Ptr", ConfigGUI.Hwnd, "Int", -20, "Ptr")
    NewExStyle := CurrentExStyle & ~0x00000200
    DllCall("user32.dll\SetWindowLongPtr", "Ptr", ConfigGUI.Hwnd, "Int", -20, "Ptr", NewExStyle, "Ptr")
    ; 刷新窗口框架
    DllCall("user32.dll\SetWindowPos", "Ptr", ConfigGUI.Hwnd, "Ptr", 0, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x0027, "Int")  ; SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_FRAMECHANGED
    
    ; 确保窗口在最上层并激活
    WinSetAlwaysOnTop(1, ConfigGUI.Hwnd)
    WinActivate(ConfigGUI.Hwnd)
    
    ; 【移除滚动功能】不再启用配置面板的滚轮热键（已移除滚动条）
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
    global GuiID_ConfigGUI, SidebarWidth, UI_Colors
    
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
    
    ; 更新标题栏宽度
    try {
        TitleBar := GuiObj["TitleBar"]
        if (TitleBar) {
            TitleBar.Move(, , Width - 40)
        }
    }
    
    ; 更新关闭按钮位置（四个角）
    try {
        CloseBtnTopLeft := GuiObj["CloseBtnTopLeft"]
        if (CloseBtnTopLeft) {
            ; 左上角位置不变
        }
        
        CloseBtnTopRight := GuiObj["CloseBtnTopRight"]
        if (CloseBtnTopRight) {
            CloseBtnTopRight.Move(Width - 40)
        }
        
        CloseBtnBottomLeft := GuiObj["CloseBtnBottomLeft"]
        if (CloseBtnBottomLeft) {
            CloseBtnBottomLeft.Move(, Height - 40)
        }
        
        CloseBtnBottomRight := GuiObj["CloseBtnBottomRight"]
        if (CloseBtnBottomRight) {
            CloseBtnBottomRight.Move(Width - 40, Height - 40)
        }
    }
    
    ; 更新侧边栏高度
    try {
        SidebarBg := GuiObj["SidebarBg"]
        if (SidebarBg) {
            SidebarBg.Move(, , , Height - 35)
        }
    }
    
    ; 更新内容区域大小
    ContentX := SidebarWidth
    ContentWidth := Width - SidebarWidth
    ContentY := 35
    ContentHeight := Height - 35 - 50
    
    ; 更新底部按钮区域位置
    ButtonAreaY := Height - 70  ; 增加高度以容纳按钮说明文字
    ; 已移除ButtonAreaBg，不再需要更新
    ; try {
    ;     ButtonAreaBg := GuiObj["ButtonAreaBg"]
    ;     if (ButtonAreaBg) {
    ;         ButtonAreaBg.Move(ContentX, ButtonAreaY, ContentWidth)
    ;     }
    ; }
    
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

; 关闭配置面板
CloseConfigGUI() {
    global GuiID_ConfigGUI, CapsLockHoldTimeEdit, CapsLockHoldTimeSeconds, ConfigFile
    global DDLBrush, DefaultStartTabDDL_Hwnd
    ; 禁用滚动热键
    DisableConfigScroll()
    
    ; 清理下拉框相关的资源
    if (DDLBrush != 0) {
        try {
            DllCall("gdi32.dll\DeleteObject", "Ptr", DDLBrush)
            DDLBrush := 0
        } catch {
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
                } catch {
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
    
    if (GuiID_ConfigGUI != 0) {
        try {
            GuiID_ConfigGUI.Destroy()
        }
        GuiID_ConfigGUI := 0
    }
}

; ===================== 搜索框事件处理 =====================
SearchEditFocus(*) {
    global SearchHint
    try {
        if (SearchHint) {
            SearchHint.Visible := false
        }
    }
}

SearchEditLoseFocus(*) {
    global SearchEdit, SearchHint
    try {
        if (SearchEdit && SearchEdit.Value = "") {
            if (SearchHint) {
                SearchHint.Visible := true
            }
        }
    }
}

; ===================== 搜索功能 =====================
FilterSettings(SearchText) {
    global ConfigTabs, CurrentTab
    
    ; 如果搜索文本为空，显示所有标签
    if (SearchText = "") {
        ; 显示所有标签
        for Key, TabBtn in ConfigTabs {
            TabBtn.Visible := true
        }
        ; 如果当前标签存在，显示它
        if (CurrentTab && ConfigTabs.Has(CurrentTab)) {
            SwitchTab(CurrentTab)
        }
        return
    }
    
    ; 转换为小写以便搜索（不区分大小写）
    SearchLower := StrLower(SearchText)
    
    ; 定义每个标签的关键词（中英文）
    TabKeywords := Map(
        "general", ["通用", "general", "cursor", "路径", "path", "语言", "language", "设置", "settings"],
        "appearance", ["外观", "appearance", "屏幕", "screen", "显示", "display", "位置", "position"],
        "prompts", ["提示词", "prompt", "解释", "explain", "重构", "refactor", "优化", "optimize", "ai"],
        "hotkeys", ["快捷键", "hotkey", "分割", "split", "批量", "batch", "键盘", "keyboard"],
        "advanced", ["高级", "advanced", "ai", "等待", "wait", "时间", "time", "性能", "performance"]
    )
    
    ; 检查每个标签是否匹配搜索关键词
    for TabName, Keywords in TabKeywords {
        Match := false
        for Index, Keyword in Keywords {
            if (InStr(StrLower(Keyword), SearchLower)) {
                Match := true
                break
            }
        }
        
        ; 显示或隐藏标签
        if (ConfigTabs.Has(TabName)) {
            ConfigTabs[TabName].Visible := Match
        }
    }
    
    ; 如果当前标签被隐藏，切换到第一个可见的标签
    if (CurrentTab && ConfigTabs.Has(CurrentTab) && !ConfigTabs[CurrentTab].Visible) {
        for TabName, TabBtn in ConfigTabs {
            if (TabBtn.Visible) {
                SwitchTab(TabName)
                break
            }
        }
    }
}

; ===================== 保存配置函数 =====================
SaveConfig(*) {
    global AISleepTimeEdit, PanelScreenRadio, CapsLockHoldTimeEdit
    global CursorPathEdit, PromptExplainEdit, PromptRefactorEdit, PromptOptimizeEdit
    global LangChinese, ConfigFile, GuiID_CursorPanel, GuiID_ConfigGUI
    global ConfigPanelScreenRadio, MsgBoxScreenRadio, VoiceInputScreenRadio, CursorPanelScreenRadio
    global PanelVisible, ThemeLightRadio, ThemeDarkRadio
    
    ; 验证输入
    if (!AISleepTimeEdit || AISleepTimeEdit.Value = "" || !IsNumber(AISleepTimeEdit.Value)) {
        MsgBox(GetText("ai_wait_time_error"), GetText("error"), "Iconx")
        return false
    }
    
    ; 验证CapsLock长按时间
    if (CapsLockHoldTimeEdit && CapsLockHoldTimeEdit.Value != "") {
        NewHoldTime := Float(CapsLockHoldTimeEdit.Value)
        if (!IsNumber(NewHoldTime) || NewHoldTime < 0.1 || NewHoldTime > 5.0) {
            MsgBox(GetText("capslock_hold_time_error"), GetText("error"), "Iconx")
            return false
        }
    }
    
    ; 解析屏幕索引（Radio 按钮组）
    NewScreenIndex := 1
    if (PanelScreenRadio && PanelScreenRadio.Length > 0) {
        for Index, RadioBtn in PanelScreenRadio {
            if (RadioBtn.HasProp("IsSelected") && RadioBtn.IsSelected) {
                NewScreenIndex := Index
                break
            }
        }
    }
    if (NewScreenIndex < 1) {
        NewScreenIndex := 1
    }
    
    ; 获取语言设置
    NewLanguage := (LangChinese && LangChinese.HasProp("IsSelected") && LangChinese.IsSelected) ? "zh" : "en"
    
    ; 解析高级设置中的屏幕索引
    NewConfigPanelScreenIndex := 1
    if (ConfigPanelScreenRadio && ConfigPanelScreenRadio.Length > 0) {
        for Index, RadioBtn in ConfigPanelScreenRadio {
            if (RadioBtn.HasProp("IsSelected") && RadioBtn.IsSelected) {
                NewConfigPanelScreenIndex := Index
                break
            }
        }
    }
    if (NewConfigPanelScreenIndex < 1) {
        NewConfigPanelScreenIndex := 1
    }
    
    NewMsgBoxScreenIndex := 1
    if (MsgBoxScreenRadio && MsgBoxScreenRadio.Length > 0) {
        for Index, RadioBtn in MsgBoxScreenRadio {
            if (RadioBtn.HasProp("IsSelected") && RadioBtn.IsSelected) {
                NewMsgBoxScreenIndex := Index
                break
            }
        }
    }
    if (NewMsgBoxScreenIndex < 1) {
        NewMsgBoxScreenIndex := 1
    }
    
    NewVoiceInputScreenIndex := 1
    if (VoiceInputScreenRadio && VoiceInputScreenRadio.Length > 0) {
        for Index, RadioBtn in VoiceInputScreenRadio {
            if (RadioBtn.HasProp("IsSelected") && RadioBtn.IsSelected) {
                NewVoiceInputScreenIndex := Index
                break
            }
        }
    }
    if (NewVoiceInputScreenIndex < 1) {
        NewVoiceInputScreenIndex := 1
    }
    
    NewCursorPanelScreenIndex := 1
    if (CursorPanelScreenRadio && CursorPanelScreenRadio.Length > 0) {
        for Index, RadioBtn in CursorPanelScreenRadio {
            if (RadioBtn.HasProp("IsSelected") && RadioBtn.IsSelected) {
                NewCursorPanelScreenIndex := Index
                break
            }
        }
    }
    if (NewCursorPanelScreenIndex < 1) {
        NewCursorPanelScreenIndex := 1
    }
    
    ; 读取快捷操作按钮配置（从单选按钮读取类型，快捷键根据类型自动确定）
    global QuickActionButtons
    try {
        ConfigGUI := GuiFromHwnd(GuiID_ConfigGUI)
        if (ConfigGUI) {
            QuickActionButtons := []
            ; 定义所有功能类型（与CreateQuickActionConfigUI中的ActionTypes保持一致）
            ActionTypes := [
                {Type: "Explain", Hotkey: "e"},
                {Type: "Refactor", Hotkey: "r"},
                {Type: "Optimize", Hotkey: "o"},
                {Type: "Config", Hotkey: "q"},
                {Type: "Copy", Hotkey: "c"},
                {Type: "Paste", Hotkey: "v"},
                {Type: "Clipboard", Hotkey: "x"},
                {Type: "Voice", Hotkey: "z"},
                {Type: "Split", Hotkey: "s"},
                {Type: "Batch", Hotkey: "b"}
            ]
            
            Loop 5 {
                Index := A_Index
                ButtonType := ""
                ButtonHotkey := ""
                
                ; 读取单选按钮的值（现在每个按钮都有唯一的变量名）
                ; 遍历所有可能的单选按钮，找到选中的那个
                RadioGroupName := "QuickActionType" . Index
                for TypeIndex, ActionType in ActionTypes {
                    RadioCtrlName := RadioGroupName . "_" . TypeIndex
                    RadioCtrl := ConfigGUI[RadioCtrlName]
                    if (RadioCtrl && RadioCtrl.HasProp("IsSelected") && RadioCtrl.IsSelected) {
                        ButtonType := ActionType.Type
                        ButtonHotkey := ActionType.Hotkey
                        break
                    }
                }
                
                ; 如果没有选择类型，使用默认值
                if (ButtonType = "") {
                    ButtonType := "Explain"
                    ButtonHotkey := "e"
                }
                
                QuickActionButtons.Push({Type: ButtonType, Hotkey: ButtonHotkey})
            }
            
            ; 确保有5个按钮
            while (QuickActionButtons.Length < 5) {
                QuickActionButtons.Push({Type: "Explain", Hotkey: "e"})
            }
        }
    } catch {
        ; 如果读取失败，使用默认配置
        if (!QuickActionButtons || QuickActionButtons.Length = 0) {
            QuickActionButtons := [
                {Type: "Explain", Hotkey: "e"},
                {Type: "Refactor", Hotkey: "r"},
                {Type: "Optimize", Hotkey: "o"},
                {Type: "Config", Hotkey: "q"},
                {Type: "Copy", Hotkey: "c"}
            ]
        }
        ; 确保有5个按钮
        while (QuickActionButtons.Length < 5) {
            QuickActionButtons.Push({Type: "Explain", Hotkey: "e"})
        }
        while (QuickActionButtons.Length > 5) {
            QuickActionButtons.Pop()
        }
    }
    
    ; 获取主题模式设置
    NewThemeMode := "dark"
    ; 如果外观标签页已创建，从单选按钮读取；否则使用当前主题模式
    if (IsSet(ThemeLightRadio) && ThemeLightRadio && IsObject(ThemeLightRadio) && ThemeLightRadio.HasProp("IsSelected") && ThemeLightRadio.IsSelected) {
        NewThemeMode := "light"
    } else if (IsSet(ThemeDarkRadio) && ThemeDarkRadio && IsObject(ThemeDarkRadio) && ThemeDarkRadio.HasProp("IsSelected") && ThemeDarkRadio.IsSelected) {
        NewThemeMode := "dark"
    } else {
        ; 如果控件不存在，使用当前主题模式
        global ThemeMode
        NewThemeMode := ThemeMode
    }
    global ThemeMode
    if (ThemeMode != NewThemeMode) {
        ThemeMode := NewThemeMode
        ApplyTheme(NewThemeMode)
    }
    
    ; 更新全局变量
    global CursorPath := CursorPathEdit ? CursorPathEdit.Value : ""
    global AISleepTime := AISleepTimeEdit.Value
    ; 【修复】确保CapsLock长按时间正确保存：优先使用编辑框的值，如果为空则使用当前全局变量的值（不重置为默认值）
    if (CapsLockHoldTimeEdit && CapsLockHoldTimeEdit.Value != "") {
        global CapsLockHoldTimeSeconds := Float(CapsLockHoldTimeEdit.Value)
        ; 确保值在合理范围内
        if (CapsLockHoldTimeSeconds < 0.1) {
            CapsLockHoldTimeSeconds := 0.1
        } else if (CapsLockHoldTimeSeconds > 5.0) {
            CapsLockHoldTimeSeconds := 5.0
        }
    } else {
        ; 如果编辑框为空，保持当前全局变量的值（不重置为默认值）
        if (!IsSet(CapsLockHoldTimeSeconds) || CapsLockHoldTimeSeconds = "") {
            global CapsLockHoldTimeSeconds := 0.5  ; 只有在完全未设置时才使用默认值
        }
    }
    global Prompt_Explain := PromptExplainEdit ? PromptExplainEdit.Value : ""
    global Prompt_Refactor := PromptRefactorEdit ? PromptRefactorEdit.Value : ""
    global Prompt_Optimize := PromptOptimizeEdit ? PromptOptimizeEdit.Value : ""
    global PanelScreenIndex := NewScreenIndex
    global Language := NewLanguage
    global ConfigPanelScreenIndex := NewConfigPanelScreenIndex
    global MsgBoxScreenIndex := NewMsgBoxScreenIndex
    global VoiceInputScreenIndex := NewVoiceInputScreenIndex
    global CursorPanelScreenIndex := NewCursorPanelScreenIndex
    
    ; 读取默认启动页面设置（从下拉框读取）
    global DefaultStartTab, DefaultStartTabDDL
    if (DefaultStartTabDDL && DefaultStartTabDDL.Value) {
        StartTabOptions := ["general", "appearance", "prompts", "hotkeys", "advanced"]
        if (DefaultStartTabDDL.Value >= 1 && DefaultStartTabDDL.Value <= StartTabOptions.Length) {
            DefaultStartTab := StartTabOptions[DefaultStartTabDDL.Value]
        } else {
            DefaultStartTab := "general"
        }
    } else {
        DefaultStartTab := "general"
    }
    
    ; 读取自启动设置（从按钮状态读取，已在ToggleAutoStart中更新）
    global AutoStart
    
    ; 保存到配置文件
    IniWrite(CursorPath, ConfigFile, "Settings", "CursorPath")
    IniWrite(AISleepTime, ConfigFile, "Settings", "AISleepTime")
    ; 【修复】使用字符串格式保存，确保精度和一致性
    IniWrite(String(CapsLockHoldTimeSeconds), ConfigFile, "Settings", "CapsLockHoldTimeSeconds")
    IniWrite(Prompt_Explain, ConfigFile, "Settings", "Prompt_Explain")
    IniWrite(Prompt_Refactor, ConfigFile, "Settings", "Prompt_Refactor")
    IniWrite(Prompt_Optimize, ConfigFile, "Settings", "Prompt_Optimize")
    
    ; 保存提示词模板系统
    SavePromptTemplates()
    IniWrite(PanelScreenIndex, ConfigFile, "Panel", "ScreenIndex")
    IniWrite(Language, ConfigFile, "Settings", "Language")
    IniWrite(ThemeMode, ConfigFile, "Settings", "ThemeMode")
    
    ; 主题已更改，需要重新创建所有面板以应用新主题
    ; 注意：这里不立即重新创建，因为用户可能还在查看配置面板
    ; 主题会在下次打开面板时自动应用
    
    global AutoLoadSelectedText, AutoStart, VoiceSearchEnabledCategories
    IniWrite(AutoLoadSelectedText ? "1" : "0", ConfigFile, "Settings", "AutoLoadSelectedText")
    IniWrite(AutoStart ? "1" : "0", ConfigFile, "Settings", "AutoStart")
    
    ; 保存默认启动页面设置
    global DefaultStartTab
    if (IsSet(DefaultStartTab) && DefaultStartTab != "") {
        IniWrite(DefaultStartTab, ConfigFile, "Settings", "DefaultStartTab")
    } else {
        IniWrite("general", ConfigFile, "Settings", "DefaultStartTab")
    }
    
    ; 保存启用的搜索标签
    if (IsSet(VoiceSearchEnabledCategories) && IsObject(VoiceSearchEnabledCategories) && VoiceSearchEnabledCategories.Length > 0) {
        EnabledCategoriesStr := ""
        for Index, Category in VoiceSearchEnabledCategories {
            if (EnabledCategoriesStr != "") {
                EnabledCategoriesStr .= ","
            }
            EnabledCategoriesStr .= Category
        }
        IniWrite(EnabledCategoriesStr, ConfigFile, "Settings", "VoiceSearchEnabledCategories")
    } else {
        ; 如果为空，使用默认值
        IniWrite("ai,academic,baidu,image,audio,video,book,price,medical,cloud", ConfigFile, "Settings", "VoiceSearchEnabledCategories")
    }
    
    ; 应用自启动设置
    SetAutoStart(AutoStart)
    
    IniWrite(FunctionPanelPos, ConfigFile, "Panel", "FunctionPanelPos")
    IniWrite(ConfigPanelPos, ConfigFile, "Panel", "ConfigPanelPos")
    IniWrite(ClipboardPanelPos, ConfigFile, "Panel", "ClipboardPanelPos")
    IniWrite(ConfigPanelScreenIndex, ConfigFile, "Advanced", "ConfigPanelScreenIndex")
    IniWrite(MsgBoxScreenIndex, ConfigFile, "Advanced", "MsgBoxScreenIndex")
    IniWrite(VoiceInputScreenIndex, ConfigFile, "Advanced", "VoiceInputScreenIndex")
    IniWrite(CursorPanelScreenIndex, ConfigFile, "Advanced", "CursorPanelScreenIndex")
    
    ; 保存快捷操作按钮配置
    ButtonCount := QuickActionButtons.Length
    IniWrite(ButtonCount, ConfigFile, "QuickActions", "ButtonCount")
    for Index, Button in QuickActionButtons {
        IniWrite(Button.Type, ConfigFile, "QuickActions", "Button" . Index . "Type")
        IniWrite(Button.Hotkey, ConfigFile, "QuickActions", "Button" . Index . "Hotkey")
    }
    
    ; 更新托盘菜单（语言可能已改变）
    UpdateTrayMenu()
    
    ; 更新面板显示的快捷键和按钮配置
    if (GuiID_CursorPanel != 0) {
        try {
            GuiID_CursorPanel.Destroy()
        }
        global GuiID_CursorPanel := 0
    }
    
    ; 如果面板正在显示，重新创建面板以应用新配置
    if (PanelVisible) {
        HideCursorPanel()
        ShowCursorPanel()
    }
    
    return true
}

; 显示保存成功提示（已移除，不再显示弹窗）
; ShowSaveSuccessTip(*) {
;     ; 创建临时GUI确保消息框置顶
;     TempGui := Gui("+AlwaysOnTop -Caption +ToolWindow")
;     TempGui.Show("Hide")
;     MsgBox(GetText("config_saved"), GetText("tip"), "Iconi T1")
;     try TempGui.Destroy()
; }

; 显示导入成功提示（辅助函数）
ShowImportSuccessTip(*) {
    ; 创建临时GUI确保消息框置顶
    TempGui := Gui("+AlwaysOnTop -Caption +ToolWindow")
    TempGui.Show("Hide")
    MsgBox(GetText("import_success"), GetText("tip"), "Iconi")
    try TempGui.Destroy()
}

; 自动保存配置（延迟执行，避免频繁保存）
AutoSaveConfig(*) {
    ; 静默保存配置，不显示弹窗
    SaveConfig()
}

; 自动显示剪贴板管理面板（延迟执行，避免干扰复制操作）
AutoShowClipboardManager(*) {
    global GuiID_ClipboardManager
    ; 再次检查是否已打开（防止重复打开）
    if (GuiID_ClipboardManager = 0) {
        ShowClipboardManager()
        ; 切换到 CapsLock+C 标签
        global ClipboardCurrentTab
        if (ClipboardCurrentTab != "CapsLockC") {
            SwitchClipboardTab("CapsLockC")
        }
    }
}

; 保存配置并关闭
SaveConfigAndClose(*) {
    global GuiID_ConfigGUI
    
    if (SaveConfig()) {
        ; 关闭配置面板（不显示成功提示）
        CloseConfigGUI()
    }
}

; ===================== 清理函数 =====================
CleanUp() {
    global GuiID_CursorPanel, CapsLockHoldTimeSeconds, ConfigFile, GuiID_ConfigGUI, CapsLockHoldTimeEdit
    
    ; 【修复】在退出前保存CapsLock长按时间到配置文件
    try {
        ; 如果配置面板还打开着，优先从编辑框读取最新值
        if (GuiID_ConfigGUI != 0 && CapsLockHoldTimeEdit) {
            EditValue := CapsLockHoldTimeEdit.Value
            if (EditValue != "") {
                ; 尝试转换为浮点数（更健壮的方式）
                try {
                    NewHoldTime := Float(EditValue)
                    ; 验证值在合理范围内（0.1秒到5秒）
                    if (NewHoldTime >= 0.1 && NewHoldTime <= 5.0) {
                        CapsLockHoldTimeSeconds := NewHoldTime
                    } else {
                        ; 如果值超出范围，修正
                        if (NewHoldTime < 0.1) {
                            CapsLockHoldTimeSeconds := 0.1
                        } else if (NewHoldTime > 5.0) {
                            CapsLockHoldTimeSeconds := 5.0
                        }
                    }
                } catch {
                    ; 转换失败，保持当前值
                }
            }
        }
        
        ; 保存到配置文件（使用字符串格式确保精度）
        if (IsSet(CapsLockHoldTimeSeconds) && CapsLockHoldTimeSeconds != "") {
            IniWrite(String(CapsLockHoldTimeSeconds), ConfigFile, "Settings", "CapsLockHoldTimeSeconds")
        }
    } catch {
        ; 忽略保存错误
    }
    
    if (GuiID_CursorPanel != 0) {
        try {
            GuiID_CursorPanel.Destroy()
        }
    }
    
    ExitApp()
}

; ===================== 连续复制功能 =====================
; CapsLock+C: 连续复制，将内容添加到历史记录中
CapsLockCopy() {
    global CapsLock2, ClipboardHistory_CapsLockC, CapsLockCopyInProgress, CapsLockCopyEndTime
    global CapsLock, HotkeyC
    
    ; 诊断信息：确认函数被调用
    ; TrayTip("调试：CapsLockCopy() 函数被调用`n配置的快捷键: " . HotkeyC, "函数调用", "Iconi 2")
    
    ; 【关键修复】如果 CapsLockCopyInProgress 为 true，说明是在标签切换期间或其他阻止复制的场景，不执行复制
    ; 这样可以防止点击 CapsLock+C 标签时触发复制操作
    if (CapsLockCopyInProgress) {
        ; 【关键修复】如果 CapsLockCopyEndTime 被设置为未来时间，说明是在标签切换期间，不执行复制
        ; 优先检查这个，因为这是最明确的阻止信号
        if (CapsLockCopyEndTime > A_TickCount) {
            ; 在标签切换期间，直接返回，不执行任何复制操作
            return
        }
        ; 【关键修复】如果 CapsLock 为 false，说明是在标签切换期间，不执行复制操作
        if (!CapsLock) {
            ; 在标签切换期间，直接返回，不执行任何复制操作
            return
        }
    }
    
    ; 【关键修复】额外检查：如果 CapsLockCopyEndTime 被设置为未来时间（即使 CapsLockCopyInProgress 为 false），也不执行复制
    ; 这是双重保险，防止在标签切换期间触发复制
    if (CapsLockCopyEndTime > A_TickCount) {
        return
    }
    
    ; 【关键修复】额外检查：如果剪贴板管理面板已打开，且是标签点击期间，不执行复制
    ; 这个检查是为了防止在点击标签时，CapsLock 键还处于按下状态导致的意外触发
    global GuiID_ClipboardManager
    if (GuiID_ClipboardManager != 0 && CapsLockCopyInProgress && CapsLockCopyEndTime > A_TickCount) {
        ; 在标签点击期间且剪贴板管理面板打开时，不执行复制操作
        return
    }
    
    CapsLock2 := false  ; 清除标记，表示使用了功能
    ; 确保 CapsLock 变量在复制过程中保持为 true
    CapsLock := true
    
    ; 确保 ClipboardHistory_CapsLockC 已初始化（使用全局变量引用）
    if (!IsSet(ClipboardHistory_CapsLockC) || !IsObject(ClipboardHistory_CapsLockC)) {
        global ClipboardHistory_CapsLockC := []
    }
    
    ; 标记 CapsLock+C 正在进行中，避免 OnClipboardChange 重复记录
    CapsLockCopyInProgress := true
    CapsLockCopyEndTime := 0  ; 重置结束时间
    
    ; 保存当前剪贴板内容
    OldClipboard := A_Clipboard
    
    ; 立即执行复制操作，使用 ClipWait 确保稳定性
    ; 清空剪贴板以便检测复制操作是否成功
    A_Clipboard := ""
    ; 发送 Ctrl+C 复制命令
    Send("^c")
    ; 短暂等待，确保复制命令被处理
    Sleep(50)
    
    ; 【环节1】等待复制完成，增加等待时间确保稳定性（从1.0秒增加到2.0秒）
    if !ClipWait(2.0) {
        ; 故障：ClipWait 超时 - 2秒内未检测到剪贴板变化
        ; 可能原因：1) 没有选中文本 2) 应用程序响应慢 3) 剪贴板被占用
        A_Clipboard := OldClipboard
        CapsLockCopyEndTime := A_TickCount
        SetTimer(ClearCapsLockCopyFlag, -1500)
        TrayTip("【故障】复制超时：2秒内未检测到剪贴板变化`n可能原因：未选中文本、应用响应慢或剪贴板被占用", GetText("tip"), "Iconx 3")
        return
    }
    
    ; 【环节2】额外等待，确保剪贴板内容完全准备好
    Sleep(150)
    
    ; 【环节3】获取新内容
    try {
        NewContent := A_Clipboard
    } catch as e {
        ; 故障：获取剪贴板内容异常
        ; 可能原因：剪贴板格式不支持或剪贴板被其他程序占用
        A_Clipboard := OldClipboard
        CapsLockCopyEndTime := A_TickCount
        SetTimer(ClearCapsLockCopyFlag, -1500)
        TrayTip("【故障】获取剪贴板内容失败`n错误：" . e.Message . "`n可能原因：剪贴板格式不支持或被占用", GetText("tip"), "Iconx 3")
        return
    }
    
    ; 【环节4】检查内容是否有效（不为空且长度大于0）
    if (NewContent != "" && StrLen(NewContent) > 0) {
        ; 【环节5】添加到 CapsLock+C 历史记录
        try {
            ; 确保使用全局变量引用（已在函数开头声明 global）
            if (!IsSet(ClipboardHistory_CapsLockC) || !IsObject(ClipboardHistory_CapsLockC)) {
                global ClipboardHistory_CapsLockC := []
            }
            
            ; 使用已声明的全局变量（已在函数开头声明 global）
            ClipboardHistory_CapsLockC.Push(NewContent)
            
            ; 限制最多保存100条
            if (ClipboardHistory_CapsLockC.Length > 100) {
                ClipboardHistory_CapsLockC.RemoveAt(1)  ; 删除最旧的记录
            }
            
            ; 【完全隔离】恢复系统剪贴板到原始内容，不改变系统剪贴板
            ; 这样 Ctrl+C 和 CapsLock+C 的剪贴板完全隔离
            A_Clipboard := OldClipboard
            
            ; 【成功提示】显示复制成功提示（显示实际保存的数量）
            SavedCount := ClipboardHistory_CapsLockC.Length
            TrayTip("【成功】已复制到剪贴板管理（共 " . SavedCount . " 项）", GetText("tip"), "Iconi 1")
            
            ; 【环节6】自动弹出剪贴板管理面板（如果还未打开）
            global GuiID_ClipboardManager
            if (GuiID_ClipboardManager = 0) {
                ; 延迟显示，避免干扰复制操作
                SetTimer(AutoShowClipboardManager, -300)
            } else {
                ; 如果已打开，刷新列表并切换到 CapsLock+C 标签
                global ClipboardCurrentTab
                if (ClipboardCurrentTab != "CapsLockC") {
                    SwitchClipboardTab("CapsLockC")
                }
            }
            
            ; 【环节7】如果剪贴板面板正在显示，刷新列表
            ; 使用延迟刷新，确保数据已完全更新
            if (GuiID_ClipboardManager != 0) {
                ; 延迟刷新，确保数据已完全更新
                SetTimer(RefreshClipboardListDelayed, -100)
            }
        } catch as e {
            ; 故障：添加到历史记录失败
            ; 恢复旧剪贴板
            A_Clipboard := OldClipboard
            TrayTip("【故障】添加到剪贴板管理失败`n错误：" . e.Message, GetText("tip"), "Iconx 3")
        }
    } else {
        ; 【警告】内容为空，恢复旧剪贴板
        A_Clipboard := OldClipboard
        TrayTip("【警告】复制的内容为空`n请先选中要复制的文本", GetText("tip"), "Iconi 2")
    }
    
    ; 记录结束时间，然后延迟清除标记，确保 OnClipboardChange 不会触发
    ; 无论是否成功添加内容，都要设置结束时间
    CapsLockCopyEndTime := A_TickCount
    SetTimer(ClearCapsLockCopyFlag, -1500)  ; 延迟1.5秒，确保 OnClipboardChange 不会触发
}

; 清除 CapsLock+C 标记的辅助函数
ClearCapsLockCopyFlag(*) {
    global CapsLockCopyInProgress
    CapsLockCopyInProgress := false
}

; 恢复 CapsLock 状态的辅助函数（用于标签切换）
RestoreCapsLockState(*) {
    global CapsLock, CapsLock2, OldCapsLockForTab, OldCapsLock2ForTab
    if (IsSet(OldCapsLockForTab)) {
        CapsLock := OldCapsLockForTab
    }
    if (IsSet(OldCapsLock2ForTab)) {
        CapsLock2 := OldCapsLock2ForTab
    }
}

; 恢复 CapsLock+C 复制标记的辅助函数（用于标签切换）
RestoreCapsLockCopyFlag(*) {
    global CapsLockCopyInProgress, OldCapsLockCopyInProgress
    if (IsSet(OldCapsLockCopyInProgress)) {
        CapsLockCopyInProgress := OldCapsLockCopyInProgress
    } else {
        CapsLockCopyInProgress := false
    }
}

; 异步处理 (已废弃，改用同步 ClipWait)
ProcessCopyResult(OldClipboard) {
    return
}

; ===================== 合并粘贴功能 =====================
; CapsLock+V: 将所有复制的内容合并后粘贴到 Cursor 输入框
CapsLockPaste() {
    global CapsLock2, ClipboardHistory_CapsLockC, CursorPath, AISleepTime
    
    CapsLock2 := false  ; 清除标记，表示使用了功能
    
    ; 确保 ClipboardHistory_CapsLockC 已初始化
    if (!IsSet(ClipboardHistory_CapsLockC) || !IsObject(ClipboardHistory_CapsLockC)) {
        global ClipboardHistory_CapsLockC := []
    }
    
    ; 如果没有复制任何内容，提示用户
    if (ClipboardHistory_CapsLockC.Length = 0) {
        TrayTip("【警告】剪贴板管理中没有内容`n请先使用 CapsLock+C 复制内容", GetText("tip"), "Iconi 2")
        return
    }
    
    ; 合并所有复制的内容（用换行分隔）
    MergedContent := ""
    for Index, Content in ClipboardHistory_CapsLockC {
        if (Index > 1) {
            MergedContent .= "`n`n"  ; 两个换行分隔不同内容
        }
        MergedContent .= Content
    }
    
    ; 激活 Cursor 窗口
    try {
        if WinExist("ahk_exe Cursor.exe") {
            ; 先激活窗口，等待窗口完全激活
            WinActivate("ahk_exe Cursor.exe")
            WinWaitActive("ahk_exe Cursor.exe", , 1)  ; 等待窗口激活，最多等待1秒
            Sleep(200)  ; 额外等待，确保窗口完全就绪
            
            ; 确保 Cursor 窗口仍然激活
            if !WinActive("ahk_exe Cursor.exe") {
                WinActivate("ahk_exe Cursor.exe")
                Sleep(200)
            }
            
            ; 先按 ESC 关闭可能已打开的输入框，避免冲突
            Send("{Esc}")
            Sleep(100)
            
            ; 尝试打开 Cursor 的 AI 聊天面板（通常是 Ctrl+L）
            Send("^l")
            Sleep(400)  ; 增加等待时间，确保聊天面板完全打开
            
            ; 再次确保窗口激活（防止在等待期间窗口失去焦点）
            if !WinActive("ahk_exe Cursor.exe") {
                WinActivate("ahk_exe Cursor.exe")
                Sleep(200)
            }
            
            ; 保存当前剪贴板内容（用于恢复）
            OldClipboardForPaste := A_Clipboard
            
            ; 将合并的内容复制到剪贴板
            A_Clipboard := MergedContent
            ; 等待剪贴板准备好
            if !ClipWait(1.0) {
                ; 如果剪贴板设置失败，恢复旧剪贴板
                A_Clipboard := OldClipboardForPaste
                TrayTip("【故障】设置剪贴板失败，无法粘贴", GetText("tip"), "Iconx 2")
                return
            }
            Sleep(100)
            
            ; 粘贴合并的内容
            Send("^v")
            Sleep(300)  ; 增加等待时间，确保粘贴完成
            
            ; 粘贴后清空历史记录（只清空 CapsLock+C 的记录）
            global ClipboardHistory_CapsLockC
            ItemCount := ClipboardHistory_CapsLockC.Length
            ClipboardHistory_CapsLockC := []
            
            ; 自动关闭剪贴板管理面板
            global GuiID_ClipboardManager
            if (GuiID_ClipboardManager != 0) {
                CloseClipboardManager()
            }
            
            ; 恢复原始剪贴板内容（可选，保持合并内容在剪贴板中）
            ; A_Clipboard := OldClipboardForPaste
            
            TrayTip("【成功】已粘贴 " . ItemCount . " 项内容到 Cursor", GetText("tip"), "Iconi 1")
        } else {
            ; 如果 Cursor 未运行，尝试启动
            if (CursorPath != "" && FileExist(CursorPath)) {
                Run(CursorPath)
                Sleep(AISleepTime)
                
                ; 保存当前剪贴板内容（用于恢复）
                OldClipboardForPaste := A_Clipboard
                
                ; 将合并的内容复制到剪贴板
                A_Clipboard := MergedContent
                ; 等待剪贴板准备好
                if !ClipWait(1.0) {
                    ; 如果剪贴板设置失败，恢复旧剪贴板
                    A_Clipboard := OldClipboardForPaste
                    TrayTip("【故障】设置剪贴板失败，无法粘贴", GetText("tip"), "Iconx 2")
                    return
                }
                Sleep(100)
                
                Send("^l")
                Sleep(400)
                Send("^v")
                Sleep(300)  ; 增加等待时间，确保粘贴完成
                
                ; 粘贴后清空历史记录（只清空 CapsLock+C 的记录）
                global ClipboardHistory_CapsLockC
                ItemCount := ClipboardHistory_CapsLockC.Length
                ClipboardHistory_CapsLockC := []
                
                ; 自动关闭剪贴板管理面板
                global GuiID_ClipboardManager
                if (GuiID_ClipboardManager != 0) {
                    CloseClipboardManager()
                }
                
                ; 恢复原始剪贴板内容（可选，保持合并内容在剪贴板中）
                ; A_Clipboard := OldClipboardForPaste
                
                TrayTip("【成功】已粘贴 " . ItemCount . " 项内容到 Cursor", GetText("tip"), "Iconi 1")
            } else {
                TrayTip(GetText("cursor_not_running_error"), GetText("error"), "Iconx 2")
            }
        }
    } catch as e {
        MsgBox(GetText("paste_failed") . ": " . e.Message)
    }
}

; ===================== 剪贴板管理面板 =====================

; 关闭剪贴板面板（辅助函数）
CloseClipboardManager(*) {
    global GuiID_ClipboardManager
    try {
        if (GuiID_ClipboardManager != 0) {
            GuiID_ClipboardManager.Destroy()
            GuiID_ClipboardManager := 0
        }
    }
}

ShowClipboardManager() {
    global ClipboardHistory, GuiID_ClipboardManager, PanelScreenIndex, ClipboardPanelPos
    global UI_Colors, GuiID_ConfigGUI
    
    ; 如果面板已存在，先销毁
    if (GuiID_ClipboardManager != 0) {
        try {
            GuiID_ClipboardManager.Destroy()
        }
    }
    
    ; 关闭配置面板（确保一次只激活一个面板）
    if (GuiID_ConfigGUI != 0) {
        try {
            GuiID_ConfigGUI.Destroy()
            GuiID_ConfigGUI := 0
        } catch {
            GuiID_ConfigGUI := 0
        }
    }
    
    ; 面板尺寸
    PanelWidth := 600
    PanelHeight := 500
    
    ; 创建无边框 GUI
    GuiID_ClipboardManager := Gui("+AlwaysOnTop +ToolWindow -Caption +Border -DPIScale", GetText("clipboard_manager"))
    GuiID_ClipboardManager.BackColor := UI_Colors.Background
    GuiID_ClipboardManager.SetFont("s11 c" . UI_Colors.Text, "Segoe UI")
    
    ; ========== 自定义标题栏 (可拖动) ==========
    ; 调整标题栏宽度，避免覆盖关闭按钮
    TitleBar := GuiID_ClipboardManager.Add("Text", "x0 y0 w560 h40 Background" . UI_Colors.TitleBar, "")
    TitleBar.OnEvent("Click", (*) => PostMessage(0xA1, 2)) ; 拖动窗口
    
    ; 窗口标题
    TitleText := GuiID_ClipboardManager.Add("Text", "x20 y8 w500 h24 Background" . UI_Colors.TitleBar . " c" . UI_Colors.Text, "📋 " . GetText("clipboard_manager"))
    TitleText.SetFont("s12 Bold", "Segoe UI")
    TitleText.OnEvent("Click", (*) => PostMessage(0xA1, 2))
    
    ; 关闭按钮
    CloseBtn := GuiID_ClipboardManager.Add("Text", "x560 y0 w40 h40 Center 0x200 Background" . UI_Colors.TitleBar . " c" . UI_Colors.Text, "✕")
    CloseBtn.SetFont("s12", "Segoe UI")
    CloseBtn.OnEvent("Click", CloseClipboardManager)
    HoverBtn(CloseBtn, UI_Colors.TitleBar, "e81123")
    
    ; 分隔线（使用层叠投影替代1px边框）
    ; 底层：大范围、低饱和度、模糊阴影
    OuterShadowColor := (ThemeMode = "light") ? "E0E0E0" : "1A1A1A"
    InnerShadowColor := (ThemeMode = "light") ? "B0B0B0" : "2A2A2A"
    ; 底层阴影（3层渐变）
    Loop 3 {
        LayerOffset := 4 + (A_Index - 1) * 1
        LayerAlpha := 255 - (A_Index - 1) * 60
        LayerColor := BlendColor(OuterShadowColor, (ThemeMode = "light") ? "FFFFFF" : "000000", LayerAlpha / 255)
        GuiID_ClipboardManager.Add("Text", "x0 y" . (40 + LayerOffset) . " w600 h1 Background" . LayerColor, "")
    }
    ; 顶层阴影（紧凑、深色）
    GuiID_ClipboardManager.Add("Text", "x0 y41 w600 h1 Background" . InnerShadowColor, "")
    
    ; ========== 工具栏区域 ==========
    ToolbarBg := GuiID_ClipboardManager.Add("Text", "x0 y41 w600 h45 Background" . UI_Colors.Sidebar, "")
    
    ; 辅助函数：创建平面按钮
    CreateFlatBtn(Parent, Label, X, Y, W, H, Action, Color := "", IsPrimary := false) {
        if (Color = "")
            Color := UI_Colors.BtnBg
        
        ; 按钮文字颜色：主要按钮使用白色，非主要按钮根据主题调整
        global ThemeMode
        TextColor := IsPrimary ? "FFFFFF" : (ThemeMode = "light" ? UI_Colors.Text : "FFFFFF")
            
        Btn := Parent.Add("Text", "x" . X . " y" . Y . " w" . W . " h" . H . " Center 0x200 c" . TextColor . " Background" . Color, Label)
        Btn.SetFont("s10", "Segoe UI")
        Btn.OnEvent("Click", Action)
        HoverBtn(Btn, Color, UI_Colors.BtnHover)
        return Btn
    }
    
    ; ========== Tab 切换区域 ==========
    global ClipboardCurrentTab
    ; 确保 ClipboardCurrentTab 有默认值
    if (!IsSet(ClipboardCurrentTab) || ClipboardCurrentTab = "") {
        ClipboardCurrentTab := "CtrlC"
    }
    TabY := 48
    ; Ctrl+C Tab - 确保可以点击
    CtrlCTab := GuiID_ClipboardManager.Add("Text", "x20 y" . TabY . " w120 h30 Center 0x200 c" . UI_Colors.Text . " Background" . (ClipboardCurrentTab = "CtrlC" ? UI_Colors.TabActive : UI_Colors.Sidebar) . " vCtrlCTab", GetText("clipboard_tab_ctrlc"))
    CtrlCTab.SetFont("s10", "Segoe UI")
    ; 使用明确的点击处理函数，确保可以点击
    CtrlCTab.OnEvent("Click", SwitchClipboardTabCtrlC)
    HoverBtn(CtrlCTab, (ClipboardCurrentTab = "CtrlC" ? UI_Colors.TabActive : UI_Colors.Sidebar), UI_Colors.BtnHover)
    
    ; CapsLock+C Tab - 防止点击时触发复制操作
    CapsLockCTab := GuiID_ClipboardManager.Add("Text", "x150 y" . TabY . " w150 h30 Center 0x200 c" . UI_Colors.Text . " Background" . (ClipboardCurrentTab = "CapsLockC" ? UI_Colors.TabActive : UI_Colors.Sidebar) . " vCapsLockCTab", GetText("clipboard_tab_capslockc"))
    CapsLockCTab.SetFont("s10", "Segoe UI")
    ; 使用明确的点击处理函数，防止触发复制操作
    CapsLockCTab.OnEvent("Click", SwitchClipboardTabCapsLockC)
    HoverBtn(CapsLockCTab, (ClipboardCurrentTab = "CapsLockC" ? UI_Colors.TabActive : UI_Colors.Sidebar), UI_Colors.BtnHover)
    
    ; 清空按钮
    CreateFlatBtn(GuiID_ClipboardManager, GetText("clear_all"), 320, 48, 100, 30, ClearAllClipboard)
    
    ; 统计信息
    CountText := GuiID_ClipboardManager.Add("Text", "x430 y53 w150 h22 Background" . UI_Colors.Sidebar . " c" . UI_Colors.TextDim . " vClipboardCountText", FormatText("total_items", "0"))
    CountText.SetFont("s10", "Segoe UI")
    
    ; ========== 列表区域 ==========
    ; 使用深色背景的 ListBox
    ListBox := GuiID_ClipboardManager.Add("ListBox", "x20 y100 w560 h320 vClipboardListBox Background" . UI_Colors.InputBg . " c" . UI_Colors.Text . " -E0x200")
    ListBox.SetFont("s10", "Consolas")
    
    ; ========== 底部按钮区域 ==========
    GuiID_ClipboardManager.Add("Text", "x0 y430 w600 h70 Background" . UI_Colors.Background, "")
    
    ; 操作按钮
    CreateFlatBtn(GuiID_ClipboardManager, GetText("copy_selected"), 20, 440, 100, 35, CopySelectedItem)
    CreateFlatBtn(GuiID_ClipboardManager, GetText("delete_selected"), 130, 440, 100, 35, DeleteSelectedItem)
    CreateFlatBtn(GuiID_ClipboardManager, GetText("paste_to_cursor"), 240, 440, 120, 35, PasteSelectedToCursor, UI_Colors.BtnPrimary, true)
    
    ; 导出和导入按钮
    CreateFlatBtn(GuiID_ClipboardManager, GetText("export_clipboard"), 370, 440, 100, 35, ExportClipboard)
    CreateFlatBtn(GuiID_ClipboardManager, GetText("import_clipboard"), 480, 440, 100, 35, ImportClipboard)
    
    ; 底部提示
    HintText := GuiID_ClipboardManager.Add("Text", "x20 y485 w560 h15 c" . UI_Colors.TextDim, GetText("clipboard_hint"))
    HintText.SetFont("s9", "Segoe UI")
    
    ; 绑定选中变化和双击事件 (ListBox 需要特殊处理 OnEvent)
    ; 添加 Change 事件，确保选中状态被正确记录（当选中项改变时触发）
    ListBox.OnEvent("Change", OnClipboardListBoxChange)
    ListBox.OnEvent("DoubleClick", CopySelectedItem)
    
    ; 绑定 ESC 关闭
    GuiID_ClipboardManager.OnEvent("Escape", CloseClipboardManager)
    
    ; 确保历史记录数组已初始化
    if (!IsSet(ClipboardHistory_CtrlC) || !IsObject(ClipboardHistory_CtrlC)) {
        global ClipboardHistory_CtrlC := []
    }
    if (!IsSet(ClipboardHistory_CapsLockC) || !IsObject(ClipboardHistory_CapsLockC)) {
        global ClipboardHistory_CapsLockC := []
    }
    
    ; 保存控件引用（使用全局声明确保正确保存）
    global ClipboardListBox, ClipboardCountText, ClipboardCtrlCTab, ClipboardCapsLockCTab
    ClipboardListBox := ListBox
    ClipboardCountText := CountText
    ClipboardCtrlCTab := CtrlCTab
    ClipboardCapsLockCTab := CapsLockCTab
    ; 确保 ClipboardCurrentTab 已设置
    if (!IsSet(ClipboardCurrentTab) || ClipboardCurrentTab = "") {
        global ClipboardCurrentTab := "CtrlC"
    }
    
    ; 获取屏幕信息并计算位置 (使用 ClipboardPanelPos)
    ScreenInfo := GetScreenInfo(PanelScreenIndex)
    Pos := GetPanelPosition(ScreenInfo, PanelWidth, PanelHeight, ClipboardPanelPos)
    
    ; 先显示 GUI，确保控件已准备好
    GuiID_ClipboardManager.Show("w" . PanelWidth . " h" . PanelHeight . " x" . Pos.X . " y" . Pos.Y)
    
    ; 确保窗口在最上层并激活
    WinSetAlwaysOnTop(1, GuiID_ClipboardManager.Hwnd)
    WinActivate(GuiID_ClipboardManager.Hwnd)
    
    ; 确保全局变量已正确初始化
    if (!IsSet(ClipboardHistory_CtrlC) || !IsObject(ClipboardHistory_CtrlC)) {
        global ClipboardHistory_CtrlC := []
    }
    if (!IsSet(ClipboardHistory_CapsLockC) || !IsObject(ClipboardHistory_CapsLockC)) {
        global ClipboardHistory_CapsLockC := []
    }
    if (!IsSet(ClipboardCurrentTab) || ClipboardCurrentTab = "") {
        global ClipboardCurrentTab := "CtrlC"
    }
    
    ; 短暂延迟，确保 GUI 控件已完全准备好
    Sleep(50)
    
    ; 在 GUI 显示后刷新列表（确保控件已准备好）
    RefreshClipboardList()
}

; Ctrl+C 标签点击处理函数
SwitchClipboardTabCtrlC(*) {
    ; 直接调用切换函数
    SwitchClipboardTab("CtrlC")
}

; CapsLock+C 标签点击处理函数（防止触发复制操作）
SwitchClipboardTabCapsLockC(*) {
    ; 【关键修复】在切换标签前，先彻底阻止 CapsLock+C 快捷键触发
    ; 必须在函数最开始就设置阻止标记，防止任何复制操作
    global CapsLock, CapsLock2, CapsLockCopyInProgress, CapsLockCopyEndTime
    global OldCapsLockForTab, OldCapsLock2ForTab, OldCapsLockCopyInProgress
    
    ; 【关键修复】立即设置阻止标记，必须在任何其他操作之前（甚至在任何变量声明之前）
    ; 这是第一行代码，确保阻止标记在所有可能的快捷键处理之前生效
    
    ; 保存当前状态（用于后续恢复）
    OldCapsLockForTab := CapsLock
    OldCapsLock2ForTab := CapsLock2
    OldCapsLockCopyInProgress := CapsLockCopyInProgress
    
    ; 【关键修复】立即设置阻止标记（必须在保存状态之后立即设置）
    ; 1. 立即清除 CapsLock 标记，防止触发复制
    CapsLock := false
    CapsLock2 := false
    ; 2. 立即设置 CapsLockCopyInProgress 为 true，防止复制函数执行
    CapsLockCopyInProgress := true
    ; 3. 设置一个未来的结束时间（8秒），确保在恢复之前不会触发复制
    ; 增加延迟时间，确保点击标签后即使 CapsLock 键还处于按下状态也不会触发复制
    ; 使用更长的延迟时间（8秒），确保完全阻止
    CapsLockCopyEndTime := A_TickCount + 8000
    
    ; 【关键修复】短暂延迟，确保阻止标记已完全生效
    ; 增加延迟时间，确保阻止标记在所有快捷键处理之前生效
    Sleep(100)  ; 增加到 100ms，确保阻止标记完全生效
    
    ; 切换标签
    SwitchClipboardTab("CapsLockC")
    
    ; 【关键修复】延迟恢复状态（使用更长的延迟，确保不会触发复制）
    ; 延迟时间要大于 CapsLockCopyEndTime 的设置，确保恢复时已经过了阻止期
    ; 增加到 8.5 秒，确保完全安全
    SetTimer(RestoreCapsLockState, -8500)
    SetTimer(RestoreCapsLockCopyFlag, -8500)
}

; 切换剪贴板 Tab
SwitchClipboardTab(TabName) {
    global ClipboardCurrentTab, ClipboardCtrlCTab, ClipboardCapsLockCTab, UI_Colors
    global ClipboardListBox, ClipboardCountText, GuiID_ClipboardManager
    global CapsLock, CapsLock2, CapsLockCopyInProgress, LastSelectedIndex
    
    ; 检查 GUI 是否存在
    if (!GuiID_ClipboardManager) {
        ; 如果 GUI 对象不存在，尝试重新创建
        try {
            ShowClipboardManager()
            ; 等待 GUI 创建完成
            Sleep(100)
        } catch {
            return
        }
    }
    
    ; 验证 TabName 参数
    if (TabName != "CtrlC" && TabName != "CapsLockC") {
        return
    }
    
    ; 切换标签时，清除之前保存的选中索引（因为不同标签的数据不同）
    LastSelectedIndex := 0
    
    ; 注意：如果是从 SwitchClipboardTabCapsLockC 调用的，状态已经在那个函数中设置了
    ; 这里只处理从 SwitchClipboardTabCtrlC 调用的情况
    if (TabName = "CtrlC") {
        ; 防止点击标签时触发 CapsLock+C 快捷键
        ; 临时清除 CapsLock 标记，避免触发复制操作
        global OldCapsLockForTab, OldCapsLock2ForTab, OldCapsLockCopyInProgress
        OldCapsLockForTab := CapsLock
        OldCapsLock2ForTab := CapsLock2
        CapsLock := false
        CapsLock2 := false
        
        ; 临时标记 CapsLock+C 正在进行中，防止点击标签时触发复制操作
        ; 这样可以防止点击"CapsLock+C"标签时意外触发复制
        OldCapsLockCopyInProgress := CapsLockCopyInProgress
        CapsLockCopyInProgress := true
        
        ; 延迟恢复，确保点击事件处理完成（增加延迟时间，确保不会触发复制操作）
        ; 使用更长的延迟时间（200ms），确保标签切换完成后再恢复状态
        SetTimer(RestoreCapsLockState, -200)
        SetTimer(RestoreCapsLockCopyFlag, -200)
    }
    
    ; 尝试获取GUI对象（GuiID_ClipboardManager 应该是 Gui 对象，不是 Hwnd）
    ClipboardGUI := ""
    try {
        ; 如果 GuiID_ClipboardManager 是 Gui 对象，直接使用
        if (IsObject(GuiID_ClipboardManager) && GuiID_ClipboardManager.HasProp("Hwnd")) {
            ClipboardGUI := GuiID_ClipboardManager
        } else {
            ; 否则尝试从 Hwnd 获取
            ClipboardGUI := GuiFromHwnd(GuiID_ClipboardManager)
        }
        if (ClipboardGUI) {
            ; 如果控件引用丢失，尝试重新获取
            if (!ClipboardCtrlCTab || !IsObject(ClipboardCtrlCTab)) {
                try {
                    ClipboardCtrlCTab := ClipboardGUI["CtrlCTab"]
                    ; 确保事件绑定正确
                    if (ClipboardCtrlCTab && IsObject(ClipboardCtrlCTab)) {
                        ClipboardCtrlCTab.OnEvent("Click", SwitchClipboardTabCtrlC)
                    }
                } catch {
                    ; 忽略错误
                }
            }
            if (!ClipboardCapsLockCTab || !IsObject(ClipboardCapsLockCTab)) {
                try {
                    ClipboardCapsLockCTab := ClipboardGUI["CapsLockCTab"]
                    ; 确保事件绑定正确
                    if (ClipboardCapsLockCTab && IsObject(ClipboardCapsLockCTab)) {
                        ClipboardCapsLockCTab.OnEvent("Click", SwitchClipboardTabCapsLockC)
                    }
                } catch {
                    ; 忽略错误
                }
            }
            ; 同时更新其他控件引用
            if (!ClipboardListBox || !IsObject(ClipboardListBox)) {
                try {
                    ClipboardListBox := ClipboardGUI["ClipboardListBox"]
                } catch {
                    ; 忽略错误
                }
            }
            if (!ClipboardCountText || !IsObject(ClipboardCountText)) {
                try {
                    ClipboardCountText := ClipboardGUI["ClipboardCountText"]
                } catch {
                    ; 忽略错误
                }
            }
        }
    } catch {
        ; 忽略错误
    }
    
    ; 更新当前标签（必须在更新样式之前）
    ClipboardCurrentTab := TabName
    
    ; 【关键修复】在切换标签时，彻底清空列表，确保不会显示旧标签的数据
    ; 这解决了两个标签共用内容框的问题
    try {
        if (ClipboardListBox && IsObject(ClipboardListBox)) {
            ; 【改进】使用更可靠的清空方法，确保列表完全清空
            ; 方法1：从后往前删除
            Loop 200 {  ; 最多尝试200次，防止无限循环
                try {
                    CurrentList := ClipboardListBox.List
                    if (!CurrentList || CurrentList.Length = 0) {
                        break
                    }
                    ; 从后往前删除，避免索引变化
                    ClipboardListBox.Delete(CurrentList.Length)
                } catch {
                    break
                }
            }
            
            ; 方法2：从前往后删除（双重保险）
            Loop 200 {  ; 最多尝试200次
                try {
                    CurrentList := ClipboardListBox.List
                    if (!CurrentList || CurrentList.Length = 0) {
                        break
                    }
                    ClipboardListBox.Delete(1)
                } catch {
                    break
                }
            }
            
            ; 方法3：最终验证，确保列表为空
            try {
                FinalCheck := ClipboardListBox.List
                if (FinalCheck && FinalCheck.Length > 0) {
                    ; 如果还有项，强制清空
                    Loop FinalCheck.Length {
                        try {
                            ClipboardListBox.Delete(1)
                        } catch {
                            break
                        }
                    }
                }
            } catch {
                ; 忽略最终检查错误
            }
            
            ; 【关键】强制刷新UI，确保视觉上立即清空
            try {
                if (GuiID_ClipboardManager && IsObject(GuiID_ClipboardManager)) {
                    WinRedraw(GuiID_ClipboardManager.Hwnd)
                }
            } catch {
                ; 忽略重绘失败
            }
        }
    } catch {
        ; 忽略清空错误，继续执行
    }
    
    ; 更新 Tab 样式
    try {
        ; 先尝试使用现有的控件引用
        if (ClipboardCtrlCTab && IsObject(ClipboardCtrlCTab)) {
            if (TabName = "CtrlC") {
                ClipboardCtrlCTab.BackColor := UI_Colors.TabActive
            } else {
                ClipboardCtrlCTab.BackColor := UI_Colors.Sidebar
            }
        }
        
        if (ClipboardCapsLockCTab && IsObject(ClipboardCapsLockCTab)) {
            if (TabName = "CapsLockC") {
                ClipboardCapsLockCTab.BackColor := UI_Colors.TabActive
            } else {
                ClipboardCapsLockCTab.BackColor := UI_Colors.Sidebar
            }
        }
        
        ; 如果控件引用丢失，尝试从GUI重新获取
        if ((!ClipboardCtrlCTab || !IsObject(ClipboardCtrlCTab) || !ClipboardCapsLockCTab || !IsObject(ClipboardCapsLockCTab)) && ClipboardGUI) {
            try {
                if (!ClipboardCtrlCTab || !IsObject(ClipboardCtrlCTab)) {
                    TempCtrlCTab := ClipboardGUI["CtrlCTab"]
                    if (TempCtrlCTab && IsObject(TempCtrlCTab)) {
                        ClipboardCtrlCTab := TempCtrlCTab
                        if (TabName = "CtrlC") {
                            ClipboardCtrlCTab.BackColor := UI_Colors.TabActive
                        } else {
                            ClipboardCtrlCTab.BackColor := UI_Colors.Sidebar
                        }
                    }
                }
                
                if (!ClipboardCapsLockCTab || !IsObject(ClipboardCapsLockCTab)) {
                    TempCapsLockCTab := ClipboardGUI["CapsLockCTab"]
                    if (TempCapsLockCTab && IsObject(TempCapsLockCTab)) {
                        ClipboardCapsLockCTab := TempCapsLockCTab
                        if (TabName = "CapsLockC") {
                            ClipboardCapsLockCTab.BackColor := UI_Colors.TabActive
                        } else {
                            ClipboardCapsLockCTab.BackColor := UI_Colors.Sidebar
                        }
                    }
                }
            } catch {
                ; 忽略错误，继续执行
            }
        }
    } catch {
        ; 忽略样式更新错误，继续执行
    }
    
    ; 刷新列表（无论样式更新是否成功，都要刷新列表）
    RefreshClipboardList()
}

; 延迟刷新剪贴板列表（用于 OnClipboardChange 等场景）
RefreshClipboardListDelayed(*) {
    RefreshClipboardList()
}

; 刷新剪贴板列表
RefreshClipboardList() {
    global ClipboardHistory_CtrlC, ClipboardHistory_CapsLockC, ClipboardCurrentTab
    global ClipboardListBox, ClipboardCountText, GuiID_ClipboardManager
    
    ; 确保全局变量已初始化
    if (!IsSet(ClipboardHistory_CtrlC) || !IsObject(ClipboardHistory_CtrlC)) {
        ClipboardHistory_CtrlC := []
    }
    if (!IsSet(ClipboardHistory_CapsLockC) || !IsObject(ClipboardHistory_CapsLockC)) {
        ClipboardHistory_CapsLockC := []
    }
    if (!IsSet(ClipboardCurrentTab) || ClipboardCurrentTab = "") {
        ClipboardCurrentTab := "CtrlC"
    }
    
    ; 检查 GUI 是否存在
    if (!GuiID_ClipboardManager) {
        return
    }
    
    ; 如果控件引用丢失，尝试获取GUI对象并重新获取控件
    if (!ClipboardListBox || !IsObject(ClipboardListBox) || !ClipboardCountText || !IsObject(ClipboardCountText)) {
        try {
            ; 尝试获取GUI对象
            ClipboardGUI := ""
            if (IsObject(GuiID_ClipboardManager) && GuiID_ClipboardManager.HasProp("Hwnd")) {
                ClipboardGUI := GuiID_ClipboardManager
            } else {
                ClipboardGUI := GuiFromHwnd(GuiID_ClipboardManager)
            }
            if (ClipboardGUI) {
                ; 如果控件引用丢失，尝试重新获取
                if (!ClipboardListBox || !IsObject(ClipboardListBox)) {
                    try {
                        ClipboardListBox := ClipboardGUI["ClipboardListBox"]
                    } catch {
                        ; 如果无法获取，返回
                        return
                    }

                }
                if (!ClipboardCountText || !IsObject(ClipboardCountText)) {
                    try {
                        ClipboardCountText := ClipboardGUI["ClipboardCountText"]
                    } catch {
                        ; 如果无法获取，返回
                        return
                    }
                }
            } else {
                ; 如果无法获取GUI对象，但控件引用存在，继续使用现有引用
                if (!ClipboardListBox || !IsObject(ClipboardListBox) || !ClipboardCountText || !IsObject(ClipboardCountText)) {
                    return
                }
            }
        } catch {
            ; 如果出错，但控件引用存在，继续使用现有引用
            if (!ClipboardListBox || !IsObject(ClipboardListBox) || !ClipboardCountText || !IsObject(ClipboardCountText)) {
                return
            }
        }
    }
    
    ; 检查控件是否存在
    if (!ClipboardListBox || !ClipboardCountText) {
        return
    }
    
    try {
        ; 确保历史记录数组已初始化（使用全局声明确保正确访问）
        if (!IsSet(ClipboardHistory_CtrlC) || !IsObject(ClipboardHistory_CtrlC)) {
            global ClipboardHistory_CtrlC := []
        }
        if (!IsSet(ClipboardHistory_CapsLockC) || !IsObject(ClipboardHistory_CapsLockC)) {
            global ClipboardHistory_CapsLockC := []
        }
        
        ; 确保 ClipboardCurrentTab 有默认值
        if (!IsSet(ClipboardCurrentTab) || ClipboardCurrentTab = "") {
            global ClipboardCurrentTab := "CtrlC"
        }
        
        ; 根据当前 Tab 选择对应的历史记录（直接使用全局变量，确保引用正确）
        ; 【关键修复】直接使用全局变量引用，不要创建局部副本
        CurrentHistory := []
        HistoryLength := 0
        
        ; 【关键修复】确保使用全局变量，并根据当前标签选择正确的数组
        if (ClipboardCurrentTab = "CtrlC") {
            ; 直接使用全局变量 ClipboardHistory_CtrlC
            if (IsSet(ClipboardHistory_CtrlC) && IsObject(ClipboardHistory_CtrlC)) {
                ; 【关键】直接使用全局数组，不创建副本
                CurrentHistory := ClipboardHistory_CtrlC
                HistoryLength := ClipboardHistory_CtrlC.Length
            } else {
                CurrentHistory := []
                HistoryLength := 0
            }
        } else if (ClipboardCurrentTab = "CapsLockC") {
            ; 直接使用全局变量 ClipboardHistory_CapsLockC
            if (IsSet(ClipboardHistory_CapsLockC) && IsObject(ClipboardHistory_CapsLockC)) {
                ; 【关键】直接使用全局数组，不创建副本
                CurrentHistory := ClipboardHistory_CapsLockC
                HistoryLength := ClipboardHistory_CapsLockC.Length
            } else {
                CurrentHistory := []
                HistoryLength := 0
            }
        } else {
            ; 默认使用 CtrlC
            if (IsSet(ClipboardHistory_CtrlC) && IsObject(ClipboardHistory_CtrlC)) {
                CurrentHistory := ClipboardHistory_CtrlC
                HistoryLength := ClipboardHistory_CtrlC.Length
            } else {
                CurrentHistory := []
                HistoryLength := 0
            }
        }
        
        ; 确保 CurrentHistory 是有效的数组
        if (!IsObject(CurrentHistory)) {
            CurrentHistory := []
            HistoryLength := 0
        }
        
        ; 清空列表（使用更可靠的方法）
        ; 在 AutoHotkey v2 中，可以通过删除所有项来清空列表
        try {
            ; 方法1：尝试使用 List 属性获取并删除所有项
            Loop {
                try {
                    CurrentList := ClipboardListBox.List
                    if (!CurrentList || CurrentList.Length = 0) {
                        break
                    }
                    ; 从后往前删除，避免索引变化
                    ClipboardListBox.Delete(CurrentList.Length)
                } catch {
                    ; 如果删除失败，尝试其他方法
                    break
                }
            }
            
            ; 方法2：确保列表已完全清空（双重检查）
            Loop 100 {  ; 最多尝试100次，防止无限循环
                try {
                    CurrentList := ClipboardListBox.List
                    if (!CurrentList || CurrentList.Length = 0) {
                        break
                    }
                    ; 删除第一项
                    ClipboardListBox.Delete(1)
                } catch {
                    break
                }
            }
            
            ; 方法3：最终检查，确保列表为空
            try {
                FinalList := ClipboardListBox.List
                if (FinalList && FinalList.Length > 0) {
                    ; 如果还有项，强制清空（使用循环删除）
                    Loop FinalList.Length {
                        try {
                            ClipboardListBox.Delete(1)
                        } catch {
                            break
                        }
                    }
                }
            } catch {
                ; 忽略最终检查错误
            }
        } catch {
            ; 如果清空失败，尝试重新创建控件（最后手段）
            ; 这里不重新创建，只是忽略错误
        }
        
        ; 添加所有历史记录（显示前80个字符作为预览）
        Items := []
        ; 直接使用全局变量，确保数据正确
        if (HistoryLength > 0) {
            for Index, Content in CurrentHistory {
                ; 确保 Content 是字符串
                if (Content = "") {
                    continue
                }
                
                ; 处理换行和特殊字符，创建预览文本
                Preview := StrReplace(Content, "`r`n", " ")
                Preview := StrReplace(Preview, "`n", " ")
                Preview := StrReplace(Preview, "`r", " ")
                Preview := StrReplace(Preview, "`t", " ")
                
                ; 限制预览长度
                if (StrLen(Preview) > 80) {
                    Preview := SubStr(Preview, 1, 80) . "..."
                }
                
                ; 添加序号和预览
                DisplayText := "[" . Index . "] " . Preview
                Items.Push(DisplayText)
            }
        }
        
        ; 保存刷新前的选中索引
        global LastSelectedIndex
        PreviousSelectedIndex := 0
        try {
            if (IsSet(LastSelectedIndex) && LastSelectedIndex > 0) {
                PreviousSelectedIndex := LastSelectedIndex
            }
        } catch {
            PreviousSelectedIndex := 0
        }
        
        ; 批量添加项目
        if (Items.Length > 0) {
            try {
                ClipboardListBox.Add(Items)
            } catch {
                ; 如果批量添加失败，尝试逐个添加
                for Index, Item in Items {
                    try {
                        ClipboardListBox.Add(Item)
                    } catch {
                        ; 忽略单个项目添加失败
                        continue
                    }
                }
            }
        }
        
        ; 尝试恢复之前的选中状态
        if (PreviousSelectedIndex > 0 && PreviousSelectedIndex <= HistoryLength) {
            try {
                ClipboardListBox.Value := PreviousSelectedIndex
                LastSelectedIndex := PreviousSelectedIndex
            } catch {
                ; 如果恢复失败，清除保存的索引
                LastSelectedIndex := 0
            }
        } else {
            ; 如果没有有效的选中项，清除保存的索引
            LastSelectedIndex := 0
        }
        
        ; 更新统计信息（使用实际的历史记录长度）
        try {
            ClipboardCountText.Text := FormatText("total_items", HistoryLength)
        } catch {
            ; 忽略更新统计信息失败
        }
        
        ; 强制刷新UI，确保视觉更新
        try {
            if (GuiID_ClipboardManager && IsObject(GuiID_ClipboardManager)) {
                ; 强制重绘窗口
                WinRedraw(GuiID_ClipboardManager.Hwnd)
            }
        } catch {
            ; 忽略重绘失败
        }
    } catch as e {
        ; 如果控件已销毁，静默失败
        return
    }
}

; 清空所有剪贴板
ClearAllClipboard(*) {
    global ClipboardHistory_CtrlC, ClipboardHistory_CapsLockC, ClipboardCurrentTab
    global ClipboardListBox, ClipboardCountText
    
    ; 确认对话框
    Result := MsgBox(GetText("confirm_clear"), GetText("confirm"), "YesNo Icon?")
    if (Result = "Yes") {
        ; 根据当前 Tab 清空对应的历史记录
        if (ClipboardCurrentTab = "CtrlC") {
            ClipboardHistory_CtrlC := []
        } else {
            ClipboardHistory_CapsLockC := []
        }
        ; 立即刷新列表和计数，确保界面即时更新
        RefreshClipboardList()
        ; 强制刷新UI，确保视觉更新
        try {
            global GuiID_ClipboardManager
            if (GuiID_ClipboardManager && IsObject(GuiID_ClipboardManager)) {
                ; 强制重绘窗口
                WinRedraw(GuiID_ClipboardManager.Hwnd)
            }
        } catch {
            ; 忽略重绘失败
        }
        ; 确保刷新完成后再显示提示
        Sleep(10)
        TrayTip(GetText("cleared"), GetText("tip"), "Iconi 1")
    }
}

; ListBox 选中变化事件处理函数（确保选中状态被正确记录）
OnClipboardListBoxChange(*) {
    global ClipboardListBox, LastSelectedIndex
    try {
        if (ClipboardListBox && IsObject(ClipboardListBox)) {
            ; 获取当前选中项的索引
            SelectedIndex := ClipboardListBox.Value
            ; 确保是整数类型
            if (Type(SelectedIndex) != "Integer") {
                if (Type(SelectedIndex) = "String" && SelectedIndex != "") {
                    try {
                        SelectedIndex := Integer(SelectedIndex)
                    } catch {
                        SelectedIndex := 0
                    }
                } else {
                    SelectedIndex := 0
                }
            }
            ; 保存最后选中的索引，用于刷新后恢复
            if (SelectedIndex > 0) {
                LastSelectedIndex := SelectedIndex
            }
        }
    } catch {
        ; 忽略错误
    }
}

; 获取 ListBox 选中项索引的辅助函数
GetSelectedIndex(ListBox) {
    if (!ListBox || !IsObject(ListBox)) {
        return 0
    }
    try {
        ; 方法1：直接获取Value属性
        SelectedIndex := ListBox.Value
        
        ; 确保 SelectedIndex 是数字类型
        if (Type(SelectedIndex) != "Integer") {
            if (Type(SelectedIndex) = "String" && SelectedIndex != "") {
                ; 尝试转换为整数
                try {
                    SelectedIndex := Integer(SelectedIndex)
                } catch {
                    SelectedIndex := 0
                }
            } else {
                SelectedIndex := 0
            }
        }
        
        ; 如果Value为0，尝试使用最后保存的选中索引
        if (SelectedIndex <= 0) {
            global LastSelectedIndex
            if (IsSet(LastSelectedIndex) && LastSelectedIndex > 0) {
                ; 验证保存的索引是否仍然有效
                try {
                    ListItems := ListBox.List
                    if (ListItems && LastSelectedIndex <= ListItems.Length) {
                        ; 恢复选中状态
                        ListBox.Value := LastSelectedIndex
                        SelectedIndex := LastSelectedIndex
                    }
                } catch {
                    ; 忽略错误
                }
            }
        }
        
        return SelectedIndex
    } catch {
        return 0
    }
}

; 复制选中项
CopySelectedItem(*) {
    global ClipboardHistory_CtrlC, ClipboardHistory_CapsLockC, ClipboardCurrentTab
    global ClipboardListBox, GuiID_ClipboardManager
    
    if (!GuiID_ClipboardManager) {
        return
    }
    
    ; 如果控件引用丢失，尝试重新获取
    if (!ClipboardListBox || !IsObject(ClipboardListBox)) {
        try {
            ClipboardGUI := GuiFromHwnd(GuiID_ClipboardManager)
            if (ClipboardGUI) {
                ClipboardListBox := ClipboardGUI["ClipboardListBox"]
            }
        } catch {
            return
        }
    }
    
    if (!ClipboardListBox || !IsObject(ClipboardListBox)) {
        return
    }
    
    try {
        ; 确保全局变量已初始化
        if (!IsSet(ClipboardHistory_CtrlC) || !IsObject(ClipboardHistory_CtrlC)) {
            global ClipboardHistory_CtrlC := []
        }
        if (!IsSet(ClipboardHistory_CapsLockC) || !IsObject(ClipboardHistory_CapsLockC)) {
            global ClipboardHistory_CapsLockC := []
        }
        if (!IsSet(ClipboardCurrentTab) || ClipboardCurrentTab = "") {
            global ClipboardCurrentTab := "CtrlC"
        }
        
        ; 根据当前 Tab 选择对应的历史记录（直接使用全局变量引用）
        CurrentHistory := []
        if (ClipboardCurrentTab = "CtrlC") {
            if (IsSet(ClipboardHistory_CtrlC) && IsObject(ClipboardHistory_CtrlC)) {
                CurrentHistory := ClipboardHistory_CtrlC
            }
        } else {
            if (IsSet(ClipboardHistory_CapsLockC) && IsObject(ClipboardHistory_CapsLockC)) {
                CurrentHistory := ClipboardHistory_CapsLockC
            }
        }
        
        ; 获取选中项的索引
        SelectedIndex := GetSelectedIndex(ClipboardListBox)
        
        ; 验证索引有效性
        if (SelectedIndex > 0 && SelectedIndex <= CurrentHistory.Length) {
            A_Clipboard := CurrentHistory[SelectedIndex]
            TrayTip(GetText("copied"), GetText("tip"), "Iconi 1")
        } else {
            TrayTip(FormatText("select_first", GetText("copy")), GetText("tip"), "Iconi 1")
        }
    } catch as e {
        TrayTip(GetText("operation_failed") . ": " . e.Message, GetText("error"), "Iconx 1")
    }
}

; 删除选中项
DeleteSelectedItem(*) {
    global ClipboardHistory_CtrlC, ClipboardHistory_CapsLockC, ClipboardCurrentTab
    global ClipboardListBox, GuiID_ClipboardManager
    
    if (!GuiID_ClipboardManager) {
        return
    }
    
    ; 如果控件引用丢失，尝试重新获取
    if (!ClipboardListBox || !IsObject(ClipboardListBox)) {
        try {
            ClipboardGUI := GuiFromHwnd(GuiID_ClipboardManager)
            if (ClipboardGUI) {
                ClipboardListBox := ClipboardGUI["ClipboardListBox"]
            }
        } catch {
            return
        }
    }
    
    if (!ClipboardListBox || !IsObject(ClipboardListBox)) {
        return
    }
    
    try {
        ; 确保全局变量已初始化
        if (!IsSet(ClipboardHistory_CtrlC) || !IsObject(ClipboardHistory_CtrlC)) {
            global ClipboardHistory_CtrlC := []
        }
        if (!IsSet(ClipboardHistory_CapsLockC) || !IsObject(ClipboardHistory_CapsLockC)) {
            global ClipboardHistory_CapsLockC := []
        }
        if (!IsSet(ClipboardCurrentTab) || ClipboardCurrentTab = "") {
            global ClipboardCurrentTab := "CtrlC"
        }
        
        ; 获取选中项的索引
        SelectedIndex := GetSelectedIndex(ClipboardListBox)
        
        if (SelectedIndex > 0) {
            if (ClipboardCurrentTab = "CtrlC") {
                if (IsSet(ClipboardHistory_CtrlC) && IsObject(ClipboardHistory_CtrlC) && SelectedIndex <= ClipboardHistory_CtrlC.Length) {
                    ; 直接操作全局数组
                    ClipboardHistory_CtrlC.RemoveAt(SelectedIndex)
                    ; 【关键修复】清除保存的选中索引，防止刷新后选中错误的项
                    global LastSelectedIndex
                    LastSelectedIndex := 0
                    ; 立即刷新列表和计数，确保界面即时更新
                    RefreshClipboardList()
                    ; 【关键修复】强制刷新UI，确保视觉更新（延迟一点确保刷新完成）
                    Sleep(50)
                    try {
                        if (GuiID_ClipboardManager && IsObject(GuiID_ClipboardManager)) {
                            ; 强制重绘窗口
                            WinRedraw(GuiID_ClipboardManager.Hwnd)
                            ; 再次刷新列表，确保数据同步
                            RefreshClipboardList()
                        }
                    } catch {
                        ; 忽略重绘失败
                    }
                    TrayTip(GetText("deleted"), GetText("tip"), "Iconi 1")
                } else {
                    TrayTip(FormatText("select_first", GetText("delete")), GetText("tip"), "Iconi 1")
                }
            } else {
                if (IsSet(ClipboardHistory_CapsLockC) && IsObject(ClipboardHistory_CapsLockC) && SelectedIndex <= ClipboardHistory_CapsLockC.Length) {
                    ; 直接操作全局数组
                    ClipboardHistory_CapsLockC.RemoveAt(SelectedIndex)
                    ; 【关键修复】清除保存的选中索引，防止刷新后选中错误的项
                    global LastSelectedIndex
                    LastSelectedIndex := 0
                    ; 立即刷新列表和计数，确保界面即时更新
                    RefreshClipboardList()
                    ; 【关键修复】强制刷新UI，确保视觉更新（延迟一点确保刷新完成）
                    Sleep(50)
                    try {
                        if (GuiID_ClipboardManager && IsObject(GuiID_ClipboardManager)) {
                            ; 强制重绘窗口
                            WinRedraw(GuiID_ClipboardManager.Hwnd)
                            ; 再次刷新列表，确保数据同步
                            RefreshClipboardList()
                        }
                    } catch {
                        ; 忽略重绘失败
                    }
                    TrayTip(GetText("deleted"), GetText("tip"), "Iconi 1")
                } else {
                    TrayTip(FormatText("select_first", GetText("delete")), GetText("tip"), "Iconi 1")
                }
            }
        } else {
            TrayTip(FormatText("select_first", GetText("delete")), GetText("tip"), "Iconi 1")
        }
    } catch as e {
        TrayTip(GetText("operation_failed") . ": " . e.Message, GetText("error"), "Iconx 1")
    }
}

; 粘贴选中项到 Cursor
PasteSelectedToCursor(*) {
    global ClipboardHistory_CtrlC, ClipboardHistory_CapsLockC, ClipboardCurrentTab
    global ClipboardListBox, CursorPath, AISleepTime, GuiID_ClipboardManager
    
    if (!GuiID_ClipboardManager) {
        return
    }
    
    ; 如果控件引用丢失，尝试重新获取
    if (!ClipboardListBox || !IsObject(ClipboardListBox)) {
        try {
            ClipboardGUI := GuiFromHwnd(GuiID_ClipboardManager)
            if (ClipboardGUI) {
                ClipboardListBox := ClipboardGUI["ClipboardListBox"]
            }
        } catch {
            return
        }
    }
    
    if (!ClipboardListBox || !IsObject(ClipboardListBox)) {
        return
    }
    
    try {
        ; 确保全局变量已初始化
        if (!IsSet(ClipboardHistory_CtrlC) || !IsObject(ClipboardHistory_CtrlC)) {
            global ClipboardHistory_CtrlC := []
        }
        if (!IsSet(ClipboardHistory_CapsLockC) || !IsObject(ClipboardHistory_CapsLockC)) {
            global ClipboardHistory_CapsLockC := []
        }
        if (!IsSet(ClipboardCurrentTab) || ClipboardCurrentTab = "") {
            global ClipboardCurrentTab := "CtrlC"
        }
        
        ; 获取选中项的索引
        SelectedIndex := GetSelectedIndex(ClipboardListBox)
        
        Content := ""
        if (SelectedIndex > 0) {
            if (ClipboardCurrentTab = "CtrlC") {
                if (IsSet(ClipboardHistory_CtrlC) && IsObject(ClipboardHistory_CtrlC) && SelectedIndex <= ClipboardHistory_CtrlC.Length) {
                    Content := ClipboardHistory_CtrlC[SelectedIndex]
                }
            } else {
                if (IsSet(ClipboardHistory_CapsLockC) && IsObject(ClipboardHistory_CapsLockC) && SelectedIndex <= ClipboardHistory_CapsLockC.Length) {
                    Content := ClipboardHistory_CapsLockC[SelectedIndex]
                }
            }
        }
        
        if (Content != "" && StrLen(Content) > 0) {
            ; 激活 Cursor 窗口
            try {
                if WinExist("ahk_exe Cursor.exe") {
                    WinActivate("ahk_exe Cursor.exe")
                    WinWaitActive("ahk_exe Cursor.exe", , 1)
                    Sleep(200)
                    
                    if !WinActive("ahk_exe Cursor.exe") {
                        WinActivate("ahk_exe Cursor.exe")
                        Sleep(200)
                    }
                    
                    Send("{Esc}")
                    Sleep(100)
                    Send("^l")
                    Sleep(400)
                    
                    if !WinActive("ahk_exe Cursor.exe") {
                        WinActivate("ahk_exe Cursor.exe")
                        Sleep(200)
                    }
                    
                    A_Clipboard := Content
                    Sleep(100)
                    Send("^v")
                    Sleep(200)
                    
                    TrayTip(GetText("paste_success"), GetText("tip"), "Iconi 1")
                } else {
                    if (CursorPath != "" && FileExist(CursorPath)) {
                        Run(CursorPath)
                        Sleep(AISleepTime)
                        A_Clipboard := Content
                        Sleep(100)
                        Send("^l")
                        Sleep(400)
                        Send("^v")
                        Sleep(200)
                        TrayTip(GetText("paste_success"), GetText("tip"), "Iconi 1")
                    } else {
                        TrayTip(GetText("cursor_not_running"), GetText("error"), "Iconx 2")
                    }
                }
            } catch as e {
                MsgBox(GetText("paste_failed") . ": " . e.Message)
            }
        } else {
            TrayTip(FormatText("select_first", GetText("paste")), GetText("tip"), "Iconi 1")
        }
    } catch {
        TrayTip(GetText("operation_failed"), GetText("error"), "Iconx 1")
    }
}

; ===================== 动态快捷键处理函数 =====================
; 检查按键是否匹配配置的快捷键，如果匹配则执行相应操作
HandleDynamicHotkey(PressedKey, ActionType) {
    global HotkeyESC, HotkeyC, HotkeyV, HotkeyX, HotkeyE, HotkeyR, HotkeyO, HotkeyQ, HotkeyZ, HotkeyP, HotkeyF, HotkeyP
    global CapsLock2, PanelVisible, VoiceInputActive, CapsLock, VoiceSearchActive
    global QuickActionButtons
    
    ; 如果使用了组合快捷键，清除显示面板的定时器（防止面板被激活）
    SetTimer(ShowPanelTimer, 0)  ; 停止ShowPanelTimer定时器
    ; 清除CapsLock2标记，防止面板被激活
    CapsLock2 := false
    
    ; 将按键转换为小写进行比较（ESC特殊处理）
    KeyLower := StrLower(PressedKey)
    ConfigKey := ""
    
    ; 首先检查是否匹配快捷操作按钮配置的快捷键
    if (PanelVisible && QuickActionButtons.Length > 0) {
        for Index, Button in QuickActionButtons {
            if (StrLower(Button.Hotkey) = KeyLower) {
                ; 匹配到快捷操作按钮（CapsLock2已在上面清除）
                ; 立即隐藏面板
                if (PanelVisible) {
                    HideCursorPanel()
                }
                switch Button.Type {
                    case "Explain":
                        ExecutePrompt("Explain")
                    case "Refactor":
                        ExecutePrompt("Refactor")
                    case "Optimize":
                        ExecutePrompt("Optimize")
                    case "Config":
                        ShowConfigGUI()
                    case "CommandPalette":
                        ExecuteCursorShortcut("^+p")  ; Ctrl + Shift + P
                    case "Terminal":
                        ExecuteCursorShortcut("^+``")  ; Ctrl + Shift + `
                    case "GlobalSearch":
                        ExecuteCursorShortcut("^+f")  ; Ctrl + Shift + F
                    case "Explorer":
                        ExecuteCursorShortcut("^+e")  ; Ctrl + Shift + E
                    case "SourceControl":
                        ExecuteCursorShortcut("^+g")  ; Ctrl + Shift + G
                    case "Extensions":
                        ExecuteCursorShortcut("^+x")  ; Ctrl + Shift + X
                    case "Browser":
                        ExecuteCursorShortcut("^+b")  ; Ctrl + Shift + B
                    case "Settings":
                        ExecuteCursorShortcut("^+j")  ; Ctrl + Shift + J
                    case "CursorSettings":
                        ExecuteCursorShortcut("^,")  ; Ctrl + ,
                }
                return true  ; 已处理
            }
        }
    }
    
    ; 根据操作类型获取配置的快捷键
    switch ActionType {
        case "ESC": ConfigKey := StrLower(HotkeyESC)
        case "C": ConfigKey := StrLower(HotkeyC)
        case "V": ConfigKey := StrLower(HotkeyV)
        case "X": ConfigKey := StrLower(HotkeyX)
        case "E": ConfigKey := StrLower(HotkeyE)
        case "R": ConfigKey := StrLower(HotkeyR)
        case "O": ConfigKey := StrLower(HotkeyO)
        case "Q": ConfigKey := StrLower(HotkeyQ)
        case "Z": ConfigKey := StrLower(HotkeyZ)
        case "F": ConfigKey := StrLower(HotkeyF)
        case "P": ConfigKey := StrLower(HotkeyP)
    }
    
    ; 如果按键匹配配置的快捷键，执行操作
    if (KeyLower = ConfigKey || (ActionType = "ESC" && (PressedKey = "Esc" || KeyLower = "esc"))) {
        ; 【关键修复】对于 F 键，需要先检查语音搜索面板状态，避免影响弹出菜单
        ; 如果是 F 键且语音搜索面板已显示，不隐藏快捷操作面板，避免影响菜单状态
        global VoiceSearchPanelVisible
        if (ActionType = "F") {
            ; 确保变量已初始化
            if (!IsSet(VoiceSearchPanelVisible)) {
                VoiceSearchPanelVisible := false
            }
            ; 如果语音搜索面板已显示，不隐藏快捷操作面板，避免影响菜单状态
            if (!VoiceSearchPanelVisible && PanelVisible) {
                HideCursorPanel()
            }
        } else {
            ; 其他快捷键操作都应该隐藏面板
            if (PanelVisible) {
                HideCursorPanel()
            }
        }
        
        switch ActionType {
            case "ESC":
                CapsLock2 := false
            case "C":
                ; 【关键修复】检查是否在标签切换期间，如果是则不执行复制
                global CapsLockCopyInProgress, CapsLockCopyEndTime, GuiID_ClipboardManager
                
                ; 双重检查：1. 检查是否是标签切换期间
                if (CapsLockCopyInProgress && CapsLockCopyEndTime > A_TickCount) {
                    ; 在标签切换期间，不执行复制操作
                    return true  ; 已处理（阻止复制）
                }
                
                ; 双重检查：2. 如果剪贴板管理面板已打开，额外检查是否是标签点击期间
                ; 这个检查是为了防止在点击标签时，CapsLock 键还处于按下状态导致的意外触发
                if (GuiID_ClipboardManager != 0 && CapsLockCopyInProgress && CapsLockCopyEndTime > A_TickCount) {
                    ; 在标签点击期间且剪贴板管理面板打开时，不执行复制操作
                    return true  ; 已处理（阻止复制）
                }
                
                ; 确保 CapsLock 变量保持为 true，直到复制完成
                global CapsLock
                CapsLock := true
                ; 调用复制函数
                CapsLockCopy()
            case "V":
                CapsLockPaste()
            case "X":
                CapsLock2 := false
                ShowClipboardManager()
            case "E":
                CapsLock2 := false
                ExecutePrompt("Explain")
            case "R":
                CapsLock2 := false
                ExecutePrompt("Refactor")
            case "O":
                CapsLock2 := false
                ExecutePrompt("Optimize")
            case "Q":
                CapsLock2 := false
                ShowConfigGUI()
            case "Z":
                CapsLock2 := false
                if (VoiceInputActive) {
                    ; 如果正在语音输入，直接发送
                    if (CapsLock) {
                        CapsLock := false
                    }
                    StopVoiceInput()
                } else {
                    ; 如果未在语音输入，开始语音输入
                    StartVoiceInput()
                }
            case "F":
                CapsLock2 := false
                global VoiceSearchActive
                ; 【关键修复】确保变量已初始化
                if (!IsSet(VoiceSearchPanelVisible)) {
                    VoiceSearchPanelVisible := false
                }
                if (!IsSet(VoiceSearchActive)) {
                    VoiceSearchActive := false
                }
                if (VoiceSearchPanelVisible) {
                    ; 面板已显示
                    if (VoiceSearchActive) {
                        ; 正在语音输入，停止并执行搜索
                        if (CapsLock) {
                            CapsLock := false
                        }
                        StopVoiceInputInSearch()
                        ; 等待一下让内容填入输入框
                        Sleep(300)
                        ExecuteVoiceSearch()
                    } else {
                        ; 未在语音输入，切换焦点并开始语音输入
                        FocusVoiceSearchInput()
                        Sleep(200)
                        StartVoiceInputInSearch()
                    }
                } else {
                    ; 面板未显示，显示面板
                    ; 【关键修复】如果快捷操作面板正在显示，先关闭它（在 StartVoiceSearch 中处理）
                    StartVoiceSearch()
                }
            case "P":
                CapsLock2 := false
                ; 执行区域截图并粘贴到Cursor
                ExecuteScreenshot()
        }
        return true  ; 已处理
    }
    return false  ; 未匹配，需要发送原始按键
}

; ===================== 面板快捷键 =====================
; 当 CapsLock 按下时，响应快捷键（采用 CapsLock+ 方案）
; 注意：在 AutoHotkey v2 中，需要使用函数来检查变量
#HotIf GetCapsLockState()

; ESC 关闭面板
Esc:: {
    if (!HandleDynamicHotkey("Esc", "ESC")) {
        ; 如果不匹配，发送原始按键
        Send("{Esc}")
    }
}

; C 键连续复制（立即响应，不等待面板）
c:: {
    ; 【关键修复】在剪贴板管理面板打开时，检查是否是标签点击期间
    ; 如果是标签点击期间，不执行复制操作，避免点击标签时触发复制
    global GuiID_ClipboardManager, CapsLockCopyInProgress, CapsLockCopyEndTime
    
    ; 如果剪贴板管理面板已打开，检查是否是标签切换期间
    if (GuiID_ClipboardManager != 0) {
        ; 检查是否是标签点击期间（通过 CapsLockCopyInProgress 和 CapsLockCopyEndTime 判断）
        if (CapsLockCopyInProgress && CapsLockCopyEndTime > A_TickCount) {
            ; 在标签点击期间，不执行复制操作，直接返回
            return
        }
    }
    
    ; 添加调试信息：确认快捷键被触发
    ; TrayTip("调试：CapsLock+C 被触发", "快捷键检测", "Iconi 1")
    
    ; 确保 CapsLock 变量被设置（防止在释放时被清除）
    global CapsLock
    if (!CapsLock) {
        CapsLock := true
    }
    
    if (!HandleDynamicHotkey("c", "C")) {
        ; 如果没有匹配到配置的快捷键，发送原始按键
        Send("c")
    }
}

; V 键合并粘贴
v:: {
    if (!HandleDynamicHotkey("v", "V")) {
        Send("v")
    }
}

; X 键打开剪贴板管理面板
x:: {
    if (!HandleDynamicHotkey("x", "X")) {
        Send("x")
    }
}

; E 键执行解释
e:: {
    if (!HandleDynamicHotkey("e", "E")) {
        Send("e")
    }
}

; R 键执行重构
r:: {
    if (!HandleDynamicHotkey("r", "R")) {
        Send("r")
    }
}

; O 键执行优化
o:: {
    if (!HandleDynamicHotkey("o", "O")) {
        Send("o")
    }
}

; Q 键打开配置面板
q:: {
    if (!HandleDynamicHotkey("q", "Q")) {
        Send("q")
    }
}

; Z 键语音输入（切换模式）
z:: {
    if (!HandleDynamicHotkey("z", "Z")) {
        Send("z")
    }
}

; F 键语音搜索（切换模式）
f:: {
    if (!HandleDynamicHotkey("f", "F")) {
        Send("f")
    }
}

; P 键区域截图
p:: {
    if (!HandleDynamicHotkey("p", "P")) {
        Send("p")
    }
}

; 1-5 键激活对应顺序的快捷操作按钮
1:: {
    ActivateQuickActionButton(1)
}

2:: {
    ActivateQuickActionButton(2)
}

3:: {
    ActivateQuickActionButton(3)
}

4:: {
    ActivateQuickActionButton(4)
}

5:: {
    ActivateQuickActionButton(5)
}

#HotIf

; ===================== 激活快捷操作按钮 =====================
ActivateQuickActionButton(Index) {
    global QuickActionButtons, PanelVisible, CapsLock2
    
    ; 检查面板是否显示
    if (!PanelVisible) {
        return
    }
    
    ; 检查索引是否有效
    if (Index < 1 || Index > QuickActionButtons.Length) {
        return
    }
    
    ; 获取按钮配置
    Button := QuickActionButtons[Index]
    if (!IsObject(Button) || !Button.HasProp("Type")) {
        return
    }
    
    ; 隐藏面板
    CapsLock2 := false
    if (PanelVisible) {
        HideCursorPanel()
    }
    
    ; 执行对应的操作
    switch Button.Type {
        case "Explain":
            ExecutePrompt("Explain")
        case "Refactor":
            ExecutePrompt("Refactor")
        case "Optimize":
            ExecutePrompt("Optimize")
        case "Config":
            ShowConfigGUI()
        case "Copy":
            CapsLockCopy()
        case "Paste":
            CapsLockPaste()
        case "Clipboard":
            ShowClipboardManager()
        case "Voice":
            StartVoiceInput()
        case "Split":
            SplitCode()
        case "Batch":
            BatchOperation()
        case "CommandPalette":
            ExecuteCursorShortcut("^+p")  ; Ctrl + Shift + P
        case "Terminal":
            ExecuteCursorShortcut("^+``")  ; Ctrl + Shift + `
        case "GlobalSearch":
            ExecuteCursorShortcut("^+f")  ; Ctrl + Shift + F
        case "Explorer":
            ExecuteCursorShortcut("^+e")  ; Ctrl + Shift + E
        case "SourceControl":
            ExecuteCursorShortcut("^+g")  ; Ctrl + Shift + G
        case "Extensions":
            ExecuteCursorShortcut("^+x")  ; Ctrl + Shift + X
        case "Browser":
            ExecuteCursorShortcut("^+b")  ; Ctrl + Shift + B
        case "Settings":
            ExecuteCursorShortcut("^+j")  ; Ctrl + Shift + J
        case "CursorSettings":
            ExecuteCursorShortcut("^,")  ; Ctrl + ,
    }
}

; ===================== 动态快捷键处理 =====================
; 启动动态快捷键监听（当面板显示时）
StartDynamicHotkeys() {
    ; 这个函数保留用于未来扩展
    ; 目前使用 #HotIf 条件来处理动态快捷键
}

; 停止动态快捷键监听
StopDynamicHotkeys() {
    ; 这个函数保留用于未来扩展
}

; ===================== 面板显示时的动态快捷键 =====================
; 当 CapsLock 按下且面板显示时，响应快捷键
#HotIf GetCapsLockState() && GetPanelVisibleState()

; S 键（分割）
s:: {
    global SplitHotkey, CapsLock2
    CapsLock2 := false
    if (StrLower(SplitHotkey) = "s") {
        SplitCode()
    } else {
        Send("s")
    }
}

; B 键（批量）
b:: {
    global BatchHotkey, CapsLock2
    CapsLock2 := false
    if (StrLower(BatchHotkey) = "b") {
        BatchOperation()
    } else {
        Send("b")
    }
}

#HotIf

; ===================== 自启动功能 =====================
; 设置开机自启动（使用注册表）
SetAutoStart(Enable) {
    RegKey := "HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Run"
    AppName := "CursorHelper"
    ScriptPath := A_ScriptFullPath
    
    try {
        if (Enable) {
            ; 添加自启动项
            RegWrite(ScriptPath, "REG_SZ", RegKey, AppName)
        } else {
            ; 删除自启动项
            try {
                RegDelete(RegKey, AppName)
            } catch {
                ; 如果注册表项不存在，忽略错误
            }
        }
    } catch as e {
        ; 如果操作失败，显示错误提示（可选）
        ; TrayTip("设置自启动失败: " . e.Message, "错误", "Iconx 2")
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
    
    ; 根据当前 Tab 选择对应的历史记录
    CurrentHistory := (ClipboardCurrentTab = "CtrlC") ? ClipboardHistory_CtrlC : ClipboardHistory_CapsLockC
    
    if (CurrentHistory.Length = 0) {
        MsgBox(GetText("no_clipboard"), GetText("tip"), "Iconi")
        return
    }
    
    TabName := (ClipboardCurrentTab = "CtrlC") ? "CtrlC" : "CapsLockC"
    ExportPath := FileSelect("S", A_ScriptDir "\ClipboardHistory_" . TabName . "_" . A_Now . ".txt", GetText("export_clipboard"), "Text Files (*.txt)")
    if (ExportPath = "") {
        return
    }
    
    try {
        Content := "=== " . TabName . " Clipboard History ===`n`n"
        for Index, Item in CurrentHistory {
            Content .= "=== Item " . Index . " ===`n"
            Content .= Item . "`n`n"
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
        
        ; 根据当前 Tab 选择对应的历史记录
        CurrentHistory := (ClipboardCurrentTab = "CtrlC") ? ClipboardHistory_CtrlC : ClipboardHistory_CapsLockC
        
        ; 清空当前历史
        if (ClipboardCurrentTab = "CtrlC") {
            ClipboardHistory_CtrlC := []
            CurrentHistory := ClipboardHistory_CtrlC
        } else {
            ClipboardHistory_CapsLockC := []
            CurrentHistory := ClipboardHistory_CapsLockC
        }
        
        ; 解析导入的内容
        Lines := StrSplit(Content, "`n")
        CurrentItem := ""
        for Index, Line in Lines {
            ; 跳过标题行
            if (InStr(Line, "=== ") = 1 && InStr(Line, " Clipboard History") > 0) {
                continue
            }
            if (InStr(Line, "=== Item ") = 1) {
                if (CurrentItem != "") {
                    CurrentHistory.Push(Trim(CurrentItem, "`r`n "))
                    CurrentItem := ""
                }
            } else if (Line != "") {
                CurrentItem .= Line . "`n"
            }
        }
        ; 添加最后一项
        if (CurrentItem != "") {
            CurrentHistory.Push(Trim(CurrentItem, "`r`n "))
        }
        
        ; 更新对应的全局变量
        if (ClipboardCurrentTab = "CtrlC") {
            ClipboardHistory_CtrlC := CurrentHistory
        } else {
            ClipboardHistory_CapsLockC := CurrentHistory
        }
        
        ; 刷新剪贴板列表
        RefreshClipboardList()
        
        ; 显示成功提示（确保在最前方）
        SetTimer(ShowImportSuccessTip, -100)
    } catch as e {
        MsgBox(GetText("import_failed") . ": " . e.Message, GetText("error"), "Iconx")
    }
}

; ===================== 语音输入功能 =====================

; 检测输入法类型（改进版：多方法检测）
DetectInputMethod() {
    ; 检测百度输入法进程（常见进程名）
    BaiduProcesses := ["BaiduIME.exe", "BaiduPinyin.exe", "bdpinyin.exe", "BaiduInput.exe", "BaiduPinyinService.exe"]
    
    ; 检测讯飞输入法进程（常见进程名）
    ; 讯飞输入法的主要进程：XunfeiIME.exe, XunfeiInput.exe, XunfeiPinyin.exe
    XunfeiProcesses := ["XunfeiIME.exe", "XunfeiInput.exe", "XunfeiPinyin.exe", "XunfeiCloud.exe", "Xunfei.exe"]
    
    ; 方法1：通过进程检测（优先检测讯飞，因为进程名更独特）
    for Index, ProcessName in XunfeiProcesses {
        try {
            if (ProcessExist(ProcessName)) {
                return "xunfei"
            }
        }
    }
    
    ; 检测百度输入法
    for Index, ProcessName in BaiduProcesses {
        try {
            if (ProcessExist(ProcessName)) {
                return "baidu"
            }
        }
    }
    
    ; 方法2：通过窗口类名检测（更准确）
    ; 尝试检测当前活动的输入法窗口
    try {
        ; 检测讯飞输入法窗口（常见的窗口类名）
        if WinExist("ahk_class XunfeiIME") || WinExist("ahk_class XunfeiInput") || WinExist("ahk_class XunfeiPinyin") {
            return "xunfei"
        }
        ; 检测百度输入法窗口
        if WinExist("ahk_class BaiduIME") || WinExist("ahk_class BaiduPinyin") || WinExist("ahk_class BaiduInput") {
            return "baidu"
        }
    }
    
    ; 方法3：通过注册表检测（备用方案）
    try {
        ; 检测讯飞输入法注册表项
        try {
            RegRead("HKEY_CURRENT_USER\Software\Xunfei", "", "")
            return "xunfei"
        }
        ; 检测百度输入法注册表项
        try {
            RegRead("HKEY_CURRENT_USER\Software\Baidu", "", "")
            return "baidu"
        }
    }
    
    ; 如果都检测不到，默认尝试百度方案（因为百度更常见）
    ; 但提示用户可能需要手动选择
    return "baidu"
}

; 开始语音输入
StartVoiceInput() {
    global VoiceInputActive, VoiceInputContent, CursorPath, AISleepTime, PanelVisible, VoiceInputPaused
    
    if (VoiceInputActive) {
        ; 如果已经在语音输入中，检查是否暂停
        if (VoiceInputPaused) {
            ; 如果暂停，继续录制
            ResumeVoiceInput()
            return
        }
        return
    }
    
    ; 如果快捷操作面板正在显示，先关闭它
    if (PanelVisible) {
        HideCursorPanel()
    }
    
    try {
        if !WinExist("ahk_exe Cursor.exe") {
            if (CursorPath != "" && FileExist(CursorPath)) {
                Run(CursorPath)
                Sleep(AISleepTime)
            } else {
                TrayTip(GetText("cursor_not_running_error"), GetText("error"), "Iconx 2")
                return
            }
        }
        
        WinActivate("ahk_exe Cursor.exe")
        WinWaitActive("ahk_exe Cursor.exe", , 2)
        Sleep(300)
        
        Send("{Esc}")
        Sleep(100)
        Send("^l")
        Sleep(500)
        
        if !WinActive("ahk_exe Cursor.exe") {
            WinActivate("ahk_exe Cursor.exe")
            Sleep(200)
        }
        
        ; 确保窗口已激活
        WinWaitActive("ahk_exe Cursor.exe", , 1)
        Sleep(200)
        
        ; 清空输入框，避免复制到旧内容
        Send("^a")
        Sleep(100)
        Send("{Delete}")
        Sleep(100)
        
        ; 使用 Cursor 的快捷键 Ctrl+Shift+Space 启动语音输入
        ; 确保在 Cursor 窗口处于活动状态时发送
        if !WinActive("ahk_exe Cursor.exe") {
            ; 如果窗口未激活，再次尝试激活
            WinActivate("ahk_exe Cursor.exe")
            WinWaitActive("ahk_exe Cursor.exe", , 2)
            Sleep(300)
        }
        
        ; 确保窗口真正激活后再发送快捷键
        if WinActive("ahk_exe Cursor.exe") {
            ; 发送 Ctrl+Shift+Space 启动语音输入
            Send("^+{Space}")
            Sleep(800)  ; 增加等待时间，确保语音输入启动
        } else {
            ; 如果仍然无法激活，显示错误提示
            TrayTip("无法激活 Cursor 窗口", GetText("error"), "Iconx 2")
            return
        }
        
        VoiceInputActive := true
        VoiceInputPaused := false
        VoiceInputContent := ""
        ShowVoiceInputPanel()
    } catch as e {
        TrayTip(GetText("voice_input_failed") . ": " . e.Message, GetText("error"), "Iconx 2")
    }
}

; 结束语音输入并发送
StopVoiceInput() {
    global VoiceInputActive, VoiceInputContent, CapsLock
    
    if (!VoiceInputActive) {
        return
    }
    
    try {
        ; 先确保CapsLock状态被重置，避免影响后续操作
        if (CapsLock) {
            CapsLock := false
        }
        
        ; 确保 Cursor 窗口处于活动状态
        if !WinExist("ahk_exe Cursor.exe") {
            VoiceInputActive := false
            VoiceInputPaused := false
            HideVoiceInputPanel()
            return
        }
        
        WinActivate("ahk_exe Cursor.exe")
        WinWaitActive("ahk_exe Cursor.exe", , 2)
        Sleep(200)
        
        ; 使用 Cursor 的快捷键 Ctrl+Shift+Space 停止语音输入
        Send("^+{Space}")
        Sleep(800)  ; 等待语音识别完成并填入内容
        
        ; Cursor 的语音输入会自动将识别内容填入输入框
        ; 直接发送 Enter 键提交内容
        Send("{Enter}")
        Sleep(200)
        
        VoiceInputActive := false
        VoiceInputPaused := false
        HideVoiceInputPanel()
    } catch as e {
        VoiceInputActive := false
        VoiceInputPaused := false
        HideVoiceInputPanel()
        TrayTip(GetText("voice_input_failed") . ": " . e.Message, GetText("error"), "Iconx 2")
    }
}

; 暂停语音输入
PauseVoiceInput() {
    global VoiceInputActive, VoiceInputPaused
    
    if (!VoiceInputActive || VoiceInputPaused) {
        return
    }
    
    try {
        ; 确保 Cursor 窗口处于活动状态
        if !WinExist("ahk_exe Cursor.exe") {
            return
        }
        
        WinActivate("ahk_exe Cursor.exe")
        WinWaitActive("ahk_exe Cursor.exe", , 2)
        Sleep(200)
        
        ; 使用 Cursor 的快捷键 Ctrl+Shift+Space 暂停语音输入
        Send("^+{Space}")
        Sleep(300)
        
        VoiceInputPaused := true
        UpdateVoiceInputPanelState()
    } catch as e {
        TrayTip(GetText("voice_input_failed") . ": " . e.Message, GetText("error"), "Iconx 2")
    }
}

; 继续语音输入
ResumeVoiceInput() {
    global VoiceInputActive, VoiceInputPaused
    
    if (!VoiceInputActive || !VoiceInputPaused) {
        return
    }
    
    try {
        ; 确保 Cursor 窗口处于活动状态
        if !WinExist("ahk_exe Cursor.exe") {
            return
        }
        
        WinActivate("ahk_exe Cursor.exe")
        WinWaitActive("ahk_exe Cursor.exe", , 2)
        Sleep(200)
        
        ; 使用 Cursor 的快捷键 Ctrl+Shift+Space 继续语音输入
        Send("^+{Space}")
        Sleep(300)
        
        VoiceInputPaused := false
        UpdateVoiceInputPanelState()
    } catch as e {
        TrayTip(GetText("voice_input_failed") . ": " . e.Message, GetText("error"), "Iconx 2")
    }
}

; 显示语音输入面板（屏幕中心）
ShowVoiceInputPanel() {
    global GuiID_VoiceInputPanel, VoiceInputActive, VoiceInputScreenIndex, UI_Colors, VoiceInputPaused
    global VoiceInputSendBtn, VoiceInputPauseBtn, VoiceInputAnimationText, VoiceInputStatusText
    
    ; 【关键修复】确保所有必需的变量都已初始化
    if (!IsSet(UI_Colors) || !IsObject(UI_Colors)) {
        ; 如果 UI_Colors 未初始化，使用默认暗色主题
        global UI_Colors_Dark
        if (!IsSet(UI_Colors_Dark)) {
            UI_Colors_Dark := {Background: "1e1e1e", Text: "cccccc", BtnBg: "3c3c3c", BtnHover: "4c4c4c", BtnPrimary: "0e639c", BtnPrimaryHover: "1177bb"}
        }
        UI_Colors := UI_Colors_Dark
    }
    
    if (!IsSet(VoiceInputScreenIndex) || VoiceInputScreenIndex = "") {
        VoiceInputScreenIndex := 1
    }
    
    if (!IsSet(VoiceInputPaused)) {
        VoiceInputPaused := false
    }
    
    if (GuiID_VoiceInputPanel != 0) {
        try {
            GuiID_VoiceInputPanel.Destroy()
        }
        GuiID_VoiceInputPanel := 0
    }
    
    GuiID_VoiceInputPanel := Gui("+AlwaysOnTop +ToolWindow -Caption -DPIScale")
    GuiID_VoiceInputPanel.BackColor := UI_Colors.Background
    
    PanelWidth := 280
    PanelHeight := 120
    
    ; 状态文本
    YPos := 15
    VoiceInputStatusText := GuiID_VoiceInputPanel.Add("Text", "x20 y" . YPos . " w240 h25 c" . UI_Colors.Text, GetText("voice_input_active"))
    VoiceInputStatusText.SetFont("s12 Bold", "Segoe UI")
    
    ; 动画文本
    YPos += 30
    VoiceInputAnimationText := GuiID_VoiceInputPanel.Add("Text", "x20 y" . YPos . " w240 h25 Center c00FF00", "● ● ●")
    VoiceInputAnimationText.SetFont("s14", "Segoe UI")
    
    ; 按钮区域
    YPos += 35
    ButtonWidth := 100
    ButtonHeight := 30
    ButtonSpacing := 20
    
    ; 发送按钮
    SendBtnX := 20
    VoiceInputSendBtn := GuiID_VoiceInputPanel.Add("Text", "x" . SendBtnX . " y" . YPos . " w" . ButtonWidth . " h" . ButtonHeight . " Center 0x200 cFFFFFF Background" . UI_Colors.BtnPrimary . " vVoiceInputSendBtn", GetText("send_to_cursor"))
    VoiceInputSendBtn.SetFont("s10 Bold", "Segoe UI")
    VoiceInputSendBtn.OnEvent("Click", FinishAndSendVoiceInput)
    HoverBtn(VoiceInputSendBtn, UI_Colors.BtnPrimary, UI_Colors.BtnPrimaryHover)
    
    ; 暂停/继续按钮
    PauseBtnX := SendBtnX + ButtonWidth + ButtonSpacing
    PauseBtnText := VoiceInputPaused ? GetText("resume") : GetText("pause")
    VoiceInputPauseBtn := GuiID_VoiceInputPanel.Add("Text", "x" . PauseBtnX . " y" . YPos . " w" . ButtonWidth . " h" . ButtonHeight . " Center 0x200 cFFFFFF Background" . UI_Colors.BtnBg . " vVoiceInputPauseBtn", PauseBtnText)
    VoiceInputPauseBtn.SetFont("s10", "Segoe UI")
    VoiceInputPauseBtn.OnEvent("Click", ToggleVoiceInputPause)
    HoverBtn(VoiceInputPauseBtn, UI_Colors.BtnBg, UI_Colors.BtnHover)
    
    ; 启动动画定时器
    SetTimer(UpdateVoiceAnimation, 500)
    
    ; 获取 Cursor 窗口所在的屏幕索引，并在该屏幕中心显示面板
    try {
        CursorScreenIndex := GetWindowScreenIndex("ahk_exe Cursor.exe")
        ScreenInfo := GetScreenInfo(CursorScreenIndex)
        ; 使用 GetPanelPosition 函数计算中心位置
        Pos := GetPanelPosition(ScreenInfo, PanelWidth, PanelHeight, "Center")
        X := Pos.X
        Y := Pos.Y
    } catch {
        ; 如果出错，使用默认屏幕的中心位置
        ScreenInfo := GetScreenInfo(1)
        Pos := GetPanelPosition(ScreenInfo, PanelWidth, PanelHeight, "Center")
        X := Pos.X
        Y := Pos.Y
    }
    
    GuiID_VoiceInputPanel.Show("w" . PanelWidth . " h" . PanelHeight . " x" . X . " y" . Y . " NoActivate")
    WinSetAlwaysOnTop(1, GuiID_VoiceInputPanel.Hwnd)
}

; 更新语音输入面板状态
UpdateVoiceInputPanelState() {
    global VoiceInputPaused, VoiceInputPauseBtn, VoiceInputStatusText
    
    if (!VoiceInputPauseBtn || !VoiceInputStatusText) {
        return
    }
    
    try {
        ; 更新暂停按钮文本
        PauseBtnText := VoiceInputPaused ? GetText("resume") : GetText("pause")
        VoiceInputPauseBtn.Text := PauseBtnText
        
        ; 更新状态文本
        if (VoiceInputPaused) {
            VoiceInputStatusText.Text := GetText("voice_input_paused")
        } else {
            VoiceInputStatusText.Text := GetText("voice_input_active")
        }
    } catch {
        ; 忽略错误
    }
}

; 隐藏语音输入面板
HideVoiceInputPanel() {
    global GuiID_VoiceInputPanel, VoiceInputAnimationText, VoiceInputStatusText, VoiceInputSendBtn, VoiceInputPauseBtn
    global VoiceInputPaused
    
    ; 重置暂停状态
    VoiceInputPaused := false
    
    SetTimer(UpdateVoiceAnimation, 0)
    
    if (GuiID_VoiceInputPanel != 0) {
        try {
            GuiID_VoiceInputPanel.Destroy()
        }
        GuiID_VoiceInputPanel := 0
    }
    VoiceInputAnimationText := 0
    VoiceInputStatusText := 0
    VoiceInputSendBtn := 0
    VoiceInputPauseBtn := 0
}

; 切换暂停/继续
ToggleVoiceInputPause(*) {
    global VoiceInputPaused
    
    if (VoiceInputPaused) {
        ResumeVoiceInput()
    } else {
        PauseVoiceInput()
    }
}

; 完成并发送语音输入到 Cursor
FinishAndSendVoiceInput(*) {
    StopVoiceInput()
}

; 更新语音输入暂停状态
UpdateVoiceInputPausedState(IsPaused) {
    ; 使用新的面板状态更新函数
    UpdateVoiceInputPanelState()
}

; 更新语音输入动画
UpdateVoiceAnimation(*) {
    global VoiceInputActive, VoiceAnimationText, VoiceInputPaused, GuiID_VoiceInputPanel
    
    ; 【关键修复】检查面板是否存在且变量已初始化
    if (!VoiceInputActive || !GuiID_VoiceInputPanel || GuiID_VoiceInputPanel = 0) {
        SetTimer(UpdateVoiceAnimation, 0)
        return
    }
    
    if (!IsSet(VoiceAnimationText) || !VoiceAnimationText || VoiceInputPaused) {
        ; 如果暂停或动画文本未初始化，不更新动画
        return
    }
    
    try {
        static AnimationState := 0
        AnimationState := Mod(AnimationState + 1, 4)
        
        switch AnimationState {
            case 0:
                VoiceAnimationText.Text := "● ○ ○"
            case 1:
                VoiceAnimationText.Text := "○ ● ○"
            case 2:
                VoiceAnimationText.Text := "○ ○ ●"
            case 3:
                VoiceAnimationText.Text := "● ● ●"
        }
    } catch as e {
        ; 如果出错，停止定时器
        SetTimer(UpdateVoiceAnimation, 0)
    }
}


; 显示语音输入操作选择界面（发送到Cursor或搜索）
ShowVoiceInputActionSelection(Content) {
    global GuiID_VoiceInput, VoiceInputScreenIndex, UI_Colors, VoiceSearchSelecting, VoiceSearchEngineButtons
    
    VoiceSearchSelecting := true
    
    if (GuiID_VoiceInput != 0) {
        try {
            GuiID_VoiceInput.Destroy()
        }
        GuiID_VoiceInput := 0
    }
    
    GuiID_VoiceInput := Gui("+AlwaysOnTop +ToolWindow -Caption -DPIScale")
    GuiID_VoiceInput.BackColor := UI_Colors.Background
    GuiID_VoiceInput.SetFont("s12 c" . UI_Colors.Text . " Bold", "Segoe UI")
    
    PanelWidth := 500
    ; 计算所需高度：标题(50) + 内容标签(25) + 内容框(60) + 自动加载开关(35) + 操作标签(30) + 操作按钮(45) + 引擎标签(30) + 按钮区域 + 取消按钮(45) + 边距(20)
    ButtonsRows := Ceil(8 / 4)  ; 每行4个按钮，共8个搜索引擎
    ButtonsAreaHeight := ButtonsRows * 45  ; 每行45px（按钮35px + 间距10px）
    PanelHeight := 50 + 25 + 60 + 35 + 30 + 45 + 30 + ButtonsAreaHeight + 45 + 20
    
    ; 标题
    TitleText := GuiID_VoiceInput.Add("Text", "x0 y15 w500 h30 Center c" . UI_Colors.Text, GetText("select_action"))
    TitleText.SetFont("s14 Bold", "Segoe UI")
    
    ; 显示输入内容
    YPos := 55
    LabelText := GuiID_VoiceInput.Add("Text", "x20 y" . YPos . " w460 h20 c" . UI_Colors.TextDim, GetText("voice_input_content"))
    LabelText.SetFont("s10", "Segoe UI")
    
    YPos += 25
    ContentEdit := GuiID_VoiceInput.Add("Edit", "x20 y" . YPos . " w460 h60 vVoiceInputContentEdit Background" . UI_Colors.InputBg . " c" . UI_Colors.Text . " ReadOnly Multi", Content)
    ContentEdit.SetFont("s11", "Segoe UI")
    
    ; 自动加载选中文本开关
    YPos += 70
    global AutoLoadSelectedText, VoiceInputAutoLoadSwitch
    AutoLoadLabel := GuiID_VoiceInput.Add("Text", "x20 y" . YPos . " w200 h25 c" . UI_Colors.TextDim, GetText("auto_load_selected_text"))
    AutoLoadLabel.SetFont("s10", "Segoe UI")
    ; 创建开关按钮（使用文本按钮模拟开关）
    SwitchText := AutoLoadSelectedText ? GetText("switch_on") : GetText("switch_off")
    SwitchBg := AutoLoadSelectedText ? UI_Colors.BtnHover : UI_Colors.BtnBg
    ; 按钮文字颜色：根据主题调整
    global ThemeMode
    SwitchTextColor := (ThemeMode = "light") ? UI_Colors.Text : "FFFFFF"
    VoiceInputAutoLoadSwitch := GuiID_VoiceInput.Add("Text", "x220 y" . YPos . " w120 h25 Center 0x200 c" . SwitchTextColor . " Background" . SwitchBg . " vVoiceInputAutoLoadSwitch", SwitchText)
    VoiceInputAutoLoadSwitch.SetFont("s10", "Segoe UI")
    VoiceInputAutoLoadSwitch.OnEvent("Click", ToggleAutoLoadSelectedTextForVoiceInput)
    HoverBtn(VoiceInputAutoLoadSwitch, SwitchBg, UI_Colors.BtnHover)
    
    ; 操作选择
    YPos += 35
    LabelAction := GuiID_VoiceInput.Add("Text", "x20 y" . YPos . " w460 h20 c" . UI_Colors.TextDim, GetText("select_action") . ":")
    LabelAction.SetFont("s10", "Segoe UI")
    
    ; 搜索引擎按钮标签（先创建，以便后续引用）
    YPos += 50
    LabelEngine := GuiID_VoiceInput.Add("Text", "x20 y" . YPos . " w460 h20 c" . UI_Colors.TextDim . " vEngineLabel", GetText("select_search_engine"))
    LabelEngine.SetFont("s10", "Segoe UI")
    LabelEngine.Visible := false
    
    ; 操作按钮（在操作标签下方）
    YPos := 55 + 25 + 60 + 70 + 35 + 20 + 10  ; 重新计算YPos位置（标题+标签+输入框+开关间距+开关+操作标签间距+操作标签高度+按钮间距）
    ; 发送到Cursor按钮
    ; 按钮文字颜色：根据主题调整
    global ThemeMode
    ActionBtnTextColor := (ThemeMode = "light") ? UI_Colors.Text : "FFFFFF"
    SendToCursorBtn := GuiID_VoiceInput.Add("Text", "x20 y" . YPos . " w220 h35 Center 0x200 c" . ActionBtnTextColor . " Background" . UI_Colors.BtnBg . " vSendToCursorBtn", GetText("send_to_cursor"))
    SendToCursorBtn.SetFont("s11", "Segoe UI")
    SendToCursorBtn.OnEvent("Click", CreateSendToCursorHandler(Content))
    HoverBtn(SendToCursorBtn, UI_Colors.BtnBg, UI_Colors.BtnHover)
    
    ; 搜索按钮（保存引用以便后续访问）
    global VoiceInputSendToCursorBtn := SendToCursorBtn
    global VoiceInputSearchBtn
    SearchBtn := GuiID_VoiceInput.Add("Text", "x260 y" . YPos . " w220 h35 Center 0x200 c" . ActionBtnTextColor . " Background" . UI_Colors.BtnBg . " vSearchBtn", GetText("voice_search_button"))
    SearchBtn.SetFont("s11", "Segoe UI")
    SearchBtn.OnEvent("Click", CreateShowSearchEnginesHandler(Content, SendToCursorBtn, SearchBtn, LabelEngine))
    VoiceInputSearchBtn := SearchBtn
    HoverBtn(SearchBtn, UI_Colors.BtnBg, UI_Colors.BtnHover)
    
    ; 搜索引擎按钮位置（从LabelEngine下方开始）
    YPos := 55 + 25 + 60 + 70 + 35 + 20 + 10 + 35 + 50  ; 操作按钮下方（标题+标签+输入框+开关间距+开关+操作标签间距+操作标签+按钮间距+操作按钮+引擎标签间距）
    ; 搜索引擎列表
    global VoiceSearchCurrentCategory
    SearchEngines := GetSortedSearchEngines(VoiceSearchCurrentCategory)
    
    VoiceSearchEngineButtons := []
    ButtonWidth := 110
    ButtonHeight := 35
    ButtonSpacing := 10
    StartX := 20
    ButtonsPerRow := 4
    
    for Index, Engine in SearchEngines {
        ; 【修复】添加安全检查，防止访问无效对象属性
        if (!IsObject(Engine) || !Engine.HasProp("Value") || !Engine.HasProp("Name")) {
            continue  ; 跳过无效的引擎对象
        }
        
        Row := Floor((Index - 1) / ButtonsPerRow)
        Col := Mod((Index - 1), ButtonsPerRow)
        BtnX := StartX + Col * (ButtonWidth + ButtonSpacing)
        BtnY := YPos + Row * (ButtonHeight + ButtonSpacing)
        
        ; 创建按钮（初始隐藏）
        ; 按钮文字颜色：根据主题调整
        global ThemeMode
        EngineBtnTextColor := (ThemeMode = "light") ? UI_Colors.Text : "FFFFFF"
        Btn := GuiID_VoiceInput.Add("Text", "x" . BtnX . " y" . BtnY . " w" . ButtonWidth . " h" . ButtonHeight . " Center 0x200 c" . EngineBtnTextColor . " Background" . UI_Colors.BtnBg . " vSearchEngineBtn" . Index, Engine.Name)
        Btn.SetFont("s10", "Segoe UI")
        Btn.OnEvent("Click", CreateSearchEngineClickHandler(Content, Engine.Value))
        Btn.Visible := false
        HoverBtn(Btn, UI_Colors.BtnBg, UI_Colors.BtnHover)
        VoiceSearchEngineButtons.Push(Btn)
    }
    
    ; 取消按钮
    CancelBtnY := YPos + (Floor((SearchEngines.Length - 1) / ButtonsPerRow) + 1) * (ButtonHeight + ButtonSpacing) + 10
    ; 取消按钮颜色：根据主题调整
    global ThemeMode
    CancelBtnTextColor := (ThemeMode = "light") ? UI_Colors.Text : "FFFFFF"
    CancelBtnBg := (ThemeMode = "light") ? UI_Colors.BtnBg : "666666"
    CancelBtn := GuiID_VoiceInput.Add("Text", "x" . (PanelWidth // 2 - 60) . " y" . CancelBtnY . " w120 h35 Center 0x200 c" . CancelBtnTextColor . " Background" . CancelBtnBg . " vCancelBtn", GetText("cancel"))
    CancelBtn.SetFont("s11", "Segoe UI")
    CancelBtn.OnEvent("Click", CancelVoiceInputActionSelection)
    HoverBtn(CancelBtn, "666666", "777777")
    
    ScreenInfo := GetScreenInfo(VoiceInputScreenIndex)
    Pos := GetPanelPosition(ScreenInfo, PanelWidth, PanelHeight, "center")
    GuiID_VoiceInput.Show("w" . PanelWidth . " h" . PanelHeight . " x" . Pos.X . " y" . Pos.Y . " NoActivate")
    WinSetAlwaysOnTop(1, GuiID_VoiceInput.Hwnd)
    
    ; 标记界面已显示
    global VoiceInputActionSelectionVisible
    VoiceInputActionSelectionVisible := true
    
    ; 首先明确停止监听（无论之前状态如何）
    SetTimer(MonitorSelectedTextForVoiceInput, 0)
    
    ; 如果自动加载开关已开启，启动监听；否则确保监听已停止
    if (AutoLoadSelectedText) {
        SetTimer(MonitorSelectedTextForVoiceInput, 200)  ; 每200ms检查一次
    } else {
        ; 明确停止监听，确保不会自动加载
        SetTimer(MonitorSelectedTextForVoiceInput, 0)
    }
}

; 创建发送到Cursor处理函数
CreateSendToCursorHandler(Content) {
    SendToCursorHandler(*) {
        global VoiceSearchSelecting
        VoiceSearchSelecting := false
        HideVoiceInputActionSelection()
        SendVoiceInputToCursor(Content)
    }
    return SendToCursorHandler
}

; 创建显示搜索引擎处理函数
CreateShowSearchEnginesHandler(Content, SendToCursorBtn, SearchBtn, EngineLabel) {
    ShowSearchEnginesHandler(*) {
        global VoiceSearchEngineButtons
        try {
            ; 隐藏操作按钮
            if (SendToCursorBtn) {
                SendToCursorBtn.Visible := false
            }
            if (SearchBtn) {
                SearchBtn.Visible := false
            }
            if (EngineLabel) {
                EngineLabel.Visible := true
            }
            
            ; 显示搜索引擎按钮
            if (IsSet(VoiceSearchEngineButtons) && VoiceSearchEngineButtons.Length > 0) {
                Loop VoiceSearchEngineButtons.Length {
                    Index := A_Index
                    Btn := VoiceSearchEngineButtons[Index]
                    if (Btn) {
                        ; 检查是否是新的按钮结构（对象）还是旧的（直接控件）
                        if (IsObject(Btn) && Btn.Bg) {
                            ; 新结构：显示背景、图标和文字
                            if (Btn.Bg) {
                                Btn.Bg.Visible := true
                            }
                            if (Btn.Icon) {
                                Btn.Icon.Visible := true
                            }
                            if (Btn.Text) {
                                Btn.Text.Visible := true
                            }
                        } else {
                            ; 旧结构：直接显示控件
                            Btn.Visible := true
                        }
                    }
                }
            }
        } catch {
            ; 如果出错，直接显示搜索引擎选择界面
            HideVoiceInputActionSelection()
            ShowSearchEngineSelection(Content)
        }
    }
    return ShowSearchEnginesHandler
}

; 取消语音输入操作选择
CancelVoiceInputActionSelection(*) {
    global VoiceSearchSelecting
    VoiceSearchSelecting := false
    HideVoiceInputActionSelection()
}

; 隐藏语音输入操作选择界面
HideVoiceInputActionSelection() {
    global GuiID_VoiceInput, VoiceInputActionSelectionVisible
    
    ; 停止监听选中文本
    SetTimer(MonitorSelectedTextForVoiceInput, 0)
    
    ; 标记界面已隐藏
    VoiceInputActionSelectionVisible := false
    
    if (GuiID_VoiceInput != 0) {
        try {
            GuiID_VoiceInput.Destroy()
        }
        GuiID_VoiceInput := 0
    }
}

; 发送语音输入内容到 Cursor
SendVoiceInputToCursor(Content) {
    global CursorPath, AISleepTime
    
    try {
        if !WinActive("ahk_exe Cursor.exe") {
            WinActivate("ahk_exe Cursor.exe")
            WinWaitActive("ahk_exe Cursor.exe", , 1)
            Sleep(200)
        }
        
        if !WinActive("ahk_exe Cursor.exe") {
            WinActivate("ahk_exe Cursor.exe")
            Sleep(200)
        }
        
        if (Content != "" && StrLen(Content) > 0) {
            ; 确保输入框已打开
            Send("^l")
            Sleep(300)
            
            ; 清空输入框
            Send("^a")
            Sleep(100)
            Send("{Delete}")
            Sleep(100)
            
            ; 输入内容
            A_Clipboard := Content
            Sleep(100)
            Send("^v")
            Sleep(200)
            
            ; 发送
            Send("{Enter}")
            Sleep(300)
            ; 不显示发送成功的提示，避免弹窗干扰
        }
    } catch as e {
        TrayTip(GetText("voice_input_failed") . ": " . e.Message, GetText("error"), "Iconx 2")
    }
}

; ===================== 区域截图功能 =====================
; 执行区域截图并自动粘贴到Cursor
ExecuteScreenshot() {
    global CursorPath, AISleepTime, ScreenshotWaiting, ScreenshotClipboard, ScreenshotCheckTimer
    
    try {
        ; 隐藏面板（如果显示）
        global PanelVisible
        if (PanelVisible) {
            HideCursorPanel()
        }
        
        ; 保存当前剪贴板内容
        OldClipboard := ClipboardAll()
        
        ; 启动等待粘贴模式（在截图前就启动，以便立即显示悬浮面板）
        ScreenshotWaiting := true
        
        ; 立即显示悬浮面板（在截图前显示，给用户视觉反馈）
        try {
            ShowScreenshotButton()
        } catch as e {
            TrayTip("显示悬浮面板失败: " . e.Message, GetText("error"), "Iconx 2")
            ScreenshotWaiting := false
            return
        }
        
        ; 30秒后自动隐藏面板（不显示提示）
        SetTimer(StopScreenshotWaiting, -30000)
        
        ; 使用 Windows 10/11 的截图工具（Win+Shift+S）
        ; 这会打开截图工具，用户选择区域后，截图会自动保存到剪贴板
        Send("#+{s}")
        
        ; 等待用户完成截图（最多等待30秒）
        ; 通过检测剪贴板是否包含图片来判断截图是否完成
        MaxWaitTime := 30000  ; 30秒
        WaitInterval := 200   ; 每200ms检查一次
        ElapsedTime := 0
        ScreenshotTaken := false
        
        ; 等待一下，让截图工具启动
        Sleep(500)
        
        ; 清空剪贴板，用于检测新截图
        ; 注意：不要立即清空，因为可能影响用户其他操作
        ; 我们通过检测剪贴板内容变化来判断截图完成
        
        while (ElapsedTime < MaxWaitTime) {
            Sleep(WaitInterval)
            ElapsedTime += WaitInterval
            
            ; 检查剪贴板是否包含图片（通过检查剪贴板格式）
            try {
                ; 打开剪贴板进行检查
                if (DllCall("OpenClipboard", "Ptr", 0)) {
                    ; 检查是否包含位图格式
                    if (DllCall("IsClipboardFormatAvailable", "UInt", 2)) {  ; CF_BITMAP = 2
                        DllCall("CloseClipboard")
                        ScreenshotTaken := true
                        break
                    }
                    ; 检查是否包含 DIB 格式（设备无关位图）
                    if (DllCall("IsClipboardFormatAvailable", "UInt", 17)) {  ; CF_DIB = 17
                        DllCall("CloseClipboard")
                        ScreenshotTaken := true
                        break
                    }
                    ; 检查是否包含 PNG 格式（通过注册的格式ID）
                    PNGFormat := DllCall("RegisterClipboardFormat", "Str", "PNG")
                    if (PNGFormat && DllCall("IsClipboardFormatAvailable", "UInt", PNGFormat)) {
                        DllCall("CloseClipboard")
                        ScreenshotTaken := true
                        break
                    }
                    DllCall("CloseClipboard")
                }
            } catch as e {
                ; 如果检测失败，继续等待
                ; 可以添加调试信息：TrayTip("检测错误: " . e.Message, "调试", "Iconi 1")
            }
        }
        
        ; 如果截图成功，保存截图数据
        if (ScreenshotTaken) {
            ; 等待一下确保截图已保存到剪贴板
            Sleep(300)
            
            ; 保存截图到全局变量（使用 ClipboardAll 保存完整图片数据）
            ; 注意：必须在恢复旧剪贴板之前保存
            try {
                ; 在 AutoHotkey v2 中，使用 ClipboardAll() 获取数据对象
                ScreenshotClipboard := ClipboardAll()
                
                ; 验证截图是否成功保存（检查是否为有效的 ClipboardAll 对象）
                if (!ScreenshotClipboard) {
                    throw Error("截图数据为空")
                }
            } catch as e {
                TrayTip("保存截图失败: " . e.Message, GetText("error"), "Iconx 2")
                A_Clipboard := OldClipboard
                ScreenshotWaiting := false
                HideScreenshotButton()
                return
            }
            
            ; 恢复旧剪贴板（不影响用户其他操作）
            A_Clipboard := OldClipboard
            
            ; 显示成功提示（悬浮面板已经在截图前显示了）
            TrayTip("截图已保存，请点击悬浮面板粘贴", GetText("tip"), "Iconi 1")
        } else {
            ; 截图超时或取消，恢复旧剪贴板并隐藏面板
            A_Clipboard := OldClipboard
            ScreenshotWaiting := false
            HideScreenshotButton()
            TrayTip("截图已取消或超时", GetText("tip"), "Iconi 1")
        }
    } catch as e {
        TrayTip("截图失败: " . e.Message, GetText("error"), "Iconx 2")
        ; 尝试恢复旧剪贴板
        try {
            A_Clipboard := OldClipboard
        }
    }
}

; ===================== 从悬浮面板粘贴截图 =====================
PasteScreenshotFromButton(*) {
    global ScreenshotWaiting, ScreenshotClipboard, GuiID_ScreenshotButton, ScreenshotButtonVisible, CursorPath, AISleepTime
    
    ; 如果不在等待状态或没有截图数据，不执行
    if (!ScreenshotWaiting || !ScreenshotClipboard) {
        ; 如果不在等待状态，直接隐藏面板
        HideScreenshotButton()
        return
    }
    
    try {
        ; 先隐藏悬浮面板，避免干扰窗口焦点
        HideScreenshotButton()
        Sleep(100)  ; 等待面板关闭完成
        
        ; 确保 Cursor 窗口存在
        if (!WinExist("ahk_exe Cursor.exe")) {
            if (CursorPath != "" && FileExist(CursorPath)) {
                Run(CursorPath)
                Sleep(AISleepTime)
            } else {
                TrayTip("Cursor 未运行且无法启动", GetText("error"), "Iconx 2")
                return
            }
        }
        
        ; 激活 Cursor 窗口
        WinActivate("ahk_exe Cursor.exe")
        WinWaitActive("ahk_exe Cursor.exe", , 2)
        Sleep(300)  ; 增加等待时间确保窗口完全激活
        
        ; 确保 Cursor 窗口仍然激活
        if !WinActive("ahk_exe Cursor.exe") {
            WinActivate("ahk_exe Cursor.exe")
            WinWaitActive("ahk_exe Cursor.exe", , 2)
            Sleep(300)
        }
        
        ; 先按 ESC 关闭可能已打开的输入框，避免冲突
        Send("{Esc}")
        Sleep(150)
        
        ; 打开 Cursor 的 AI 聊天面板（Ctrl+L）
        Send("^l")
        Sleep(500)  ; 增加等待时间确保聊天面板完全打开
        
        ; 再次确保窗口激活（防止在等待期间窗口失去焦点）
        if !WinActive("ahk_exe Cursor.exe") {
            WinActivate("ahk_exe Cursor.exe")
            WinWaitActive("ahk_exe Cursor.exe", , 2)
            Sleep(300)
        }
        
        ; 将截图恢复到剪贴板（优先使用系统剪贴板中的最新数据）
        try {
            ; 先检查系统剪贴板是否有图片数据（可能是用户最新的截图）
            CurrentClipboardHasImage := false
            try {
                if (DllCall("OpenClipboard", "Ptr", 0)) {
                    ; 检查是否包含位图格式
                    if (DllCall("IsClipboardFormatAvailable", "UInt", 2)) {  ; CF_BITMAP = 2
                        CurrentClipboardHasImage := true
                    } else if (DllCall("IsClipboardFormatAvailable", "UInt", 17)) {  ; CF_DIB = 17
                        CurrentClipboardHasImage := true
                    } else {
                        ; 检查 PNG 格式
                        PNGFormat := DllCall("RegisterClipboardFormat", "Str", "PNG")
                        if (PNGFormat && DllCall("IsClipboardFormatAvailable", "UInt", PNGFormat)) {
                            CurrentClipboardHasImage := true
                        }
                    }
                    DllCall("CloseClipboard")
                }
            } catch {
                ; 检查失败，忽略，继续使用保存的数据
            }
            
            ; 如果系统剪贴板中有图片，优先使用最新的（用户可能进行了新的截图）
            if (CurrentClipboardHasImage) {
                ; 使用系统剪贴板中的最新截图数据
                ; 不需要恢复，直接使用当前剪贴板
                Sleep(200) ; 短暂等待确保剪贴板数据稳定
            } else if (ScreenshotClipboard) {
                ; 系统剪贴板没有图片，使用之前保存的数据
                ; 先清空剪贴板
                A_Clipboard := ""
                Sleep(100)
                
                ; 恢复 ClipboardAll 数据（图片数据）
                A_Clipboard := ScreenshotClipboard
                Sleep(800) ; 增加延迟确保系统识别图片数据并准备好
            } else {
                throw Error("没有可用的截图数据")
            }
            
            ; 验证剪贴板是否包含位图或 DIB 数据 (CF_BITMAP=2, CF_DIB=17)
            IsImage := DllCall("IsClipboardFormatAvailable", "UInt", 2) || DllCall("IsClipboardFormatAvailable", "UInt", 17)
            if (!IsImage) {
                ; 如果图片数据未准备好，再等待一次
                Sleep(500)
                IsImage := DllCall("IsClipboardFormatAvailable", "UInt", 2) || DllCall("IsClipboardFormatAvailable", "UInt", 17)
                if (!IsImage) {
                    ; 最后尝试检查 PNG 格式
                    PNGFormat := DllCall("RegisterClipboardFormat", "Str", "PNG")
                    if (PNGFormat && DllCall("IsClipboardFormatAvailable", "UInt", PNGFormat)) {
                        IsImage := true
                    }
                    if (!IsImage) {
                        throw Error("剪贴板中未检测到图片数据，截图可能已失效")
                    }
                }
            }
        } catch as e {
            throw Error("无法恢复截图到剪贴板: " . e.Message)
        }
        
        ; 恢复剪贴板后，再次确保窗口激活（恢复操作可能影响焦点）
        if !WinActive("ahk_exe Cursor.exe") {
            WinActivate("ahk_exe Cursor.exe")
            WinWaitActive("ahk_exe Cursor.exe", , 1)
            Sleep(300)
        }
        
        ; 最后一次确保窗口激活（粘贴前关键检查）
        if !WinActive("ahk_exe Cursor.exe") {
            WinActivate("ahk_exe Cursor.exe")
            WinWaitActive("ahk_exe Cursor.exe", , 1)
            Sleep(200)
        }
        
        ; 粘贴截图到 Cursor 输入框（使用 Shift+Insert）
        Send("+{Insert}")
        Sleep(800)  ; 增加等待时间确保粘贴完成
        
        ; 停止等待状态
        ScreenshotWaiting := false
        
        ; 清空截图数据
        ScreenshotClipboard := ""
        
        ; 显示成功提示
        TrayTip(GetText("screenshot_paste_success"), GetText("tip"), "Iconi 1")
    } catch as e {
        TrayTip("粘贴截图失败: " . e.Message, GetText("error"), "Iconx 2")
        ; 即使失败，也停止等待状态并隐藏面板
        ScreenshotWaiting := false
        HideScreenshotButton()
    }
}

; ===================== 显示截图悬浮面板 =====================
ShowScreenshotButton() {
    global GuiID_ScreenshotButton, ScreenshotButtonVisible, UI_Colors, ThemeMode
    
    try {
        ; 如果面板已显示，先隐藏
        if (ScreenshotButtonVisible && GuiID_ScreenshotButton != 0) {
            try {
                GuiID_ScreenshotButton.Destroy()
            } catch {
            }
            GuiID_ScreenshotButton := 0
        }
        
        ; 确保 UI_Colors 已初始化
        if (!IsSet(UI_Colors) || !UI_Colors) {
            ; 如果未初始化，使用默认颜色
            global ThemeMode
            if (!IsSet(ThemeMode)) {
                ThemeMode := "dark"
            }
            ApplyTheme(ThemeMode)
        }
        
        ; 创建悬浮面板 GUI（参考其他面板的创建方式）
        GuiID_ScreenshotButton := Gui("+AlwaysOnTop +ToolWindow -Caption -DPIScale")
        GuiID_ScreenshotButton.BackColor := UI_Colors.Background
        
        ; 面板尺寸
        PanelWidth := 160
        PanelHeight := 60
        
        ; 计算面板位置（优先显示在 Cursor 窗口正中间）
        global ScreenshotPanelX, ScreenshotPanelY, ConfigFile
        PanelX := -1
        PanelY := -1
        
        ; 尝试获取 Cursor 窗口位置和大小
        if (WinExist("ahk_exe Cursor.exe")) {
            try {
                WinGetPos(&CursorX, &CursorY, &CursorW, &CursorH, "ahk_exe Cursor.exe")
                ; 计算 Cursor 窗口中心位置
                PanelX := CursorX + (CursorW - PanelWidth) // 2
                PanelY := CursorY + (CursorH - PanelHeight) // 2
            } catch {
                ; 如果获取失败，使用保存的位置或屏幕中心
            }
        }
        
        ; 如果 Cursor 窗口不存在或获取失败，使用保存的位置
        if (PanelX = -1 || PanelY = -1) {
            ; 从配置文件读取上次保存的位置
            ScreenshotPanelX := IniRead(ConfigFile, "Screenshot", "PanelX", "-1")
            ScreenshotPanelY := IniRead(ConfigFile, "Screenshot", "PanelY", "-1")
            
            if (ScreenshotPanelX != "-1" && ScreenshotPanelY != "-1") {
                PanelX := Integer(ScreenshotPanelX)
                PanelY := Integer(ScreenshotPanelY)
            } else {
                ; 如果也没有保存的位置，使用屏幕中心
                ScreenWidth := A_ScreenWidth
                ScreenHeight := A_ScreenHeight
                PanelX := (ScreenWidth - PanelWidth) // 2
                PanelY := (ScreenHeight - PanelHeight) // 2
            }
        }
        
        ; 创建透明的标题栏用于拖动（不遮挡按钮区域）
        ; 标题栏只占据顶部5像素高度
        TitleBar := GuiID_ScreenshotButton.Add("Text", "x0 y0 w" . PanelWidth . " h5 BackgroundTrans")
        TitleBar.OnEvent("Click", (*) => PostMessage(0xA1, 2, , GuiID_ScreenshotButton.Hwnd))
        
        ; 创建按钮（后创建按钮，确保按钮在背景之上）
        ButtonText := GetText("screenshot_button_text")
        ButtonWidth := PanelWidth - 20
        ButtonHeight := 40
        ButtonX := 10
        ButtonY := 10
        
        ; 创建按钮（确保按钮在背景之上，可以点击）
        ; 添加 SS_NOTIFY (0x100) 确保 Text 控件响应点击
        ScreenshotBtn := GuiID_ScreenshotButton.Add("Text", "x" . ButtonX . " y" . ButtonY . " w" . ButtonWidth . " h" . ButtonHeight . " Center 0x200 +0x100 cFFFFFF Background" . UI_Colors.BtnPrimary . " vScreenshotBtn", ButtonText)
        ScreenshotBtn.SetFont("s11 Bold", "Segoe UI")
        ; 绑定点击事件（直接绑定函数，不使用闭包）
        ScreenshotBtn.OnEvent("Click", PasteScreenshotFromButton)
        
        ; 添加悬停效果
        HoverBtn(ScreenshotBtn, UI_Colors.BtnPrimary, UI_Colors.BtnHover)
        
        ; 使用定时器定期保存位置（因为 AutoHotkey v2 不支持 Move 事件）
        SetTimer(SaveScreenshotPanelPosition, 500)  ; 每500ms检查一次位置
        
        ; 显示面板（在 Show 中设置大小和位置）
        GuiID_ScreenshotButton.Show("w" . PanelWidth . " h" . PanelHeight . " x" . PanelX . " y" . PanelY . " NoActivate")
        ScreenshotButtonVisible := true
        
        ; 确保窗口始终置顶（使用 WinSetAlwaysOnTop）
        WinSetAlwaysOnTop(1, GuiID_ScreenshotButton.Hwnd)
        
        ; 设置工具提示
        try {
            ; 使用 ToolTip 显示提示
            ToolTip(GetText("screenshot_button_tip"), PanelX + PanelWidth // 2, PanelY - 30)
            SetTimer(() => ToolTip(), -3000)  ; 3秒后自动隐藏提示
        } catch {
        }
    } catch as e {
        ; 如果创建失败，显示错误信息
        TrayTip("创建悬浮面板失败: " . e.Message, GetText("error"), "Iconx 2")
        throw e
    }
}

; ===================== 隐藏截图悬浮面板 =====================
HideScreenshotButton() {
    global GuiID_ScreenshotButton, ScreenshotButtonVisible
    
    ; 停止定时器
    SetTimer(SaveScreenshotPanelPosition, 0)
    
    ; 在隐藏前保存位置
    SaveScreenshotPanelPosition()
    
    if (GuiID_ScreenshotButton != 0) {
        try {
            ; 确保窗口被销毁
            GuiID_ScreenshotButton.Destroy()
        } catch {
            ; 如果销毁失败，尝试强制关闭
            try {
                WinClose("ahk_id " . GuiID_ScreenshotButton.Hwnd)
            } catch {
            }
        }
        GuiID_ScreenshotButton := 0
    }
    ScreenshotButtonVisible := false
}

; ===================== 截图面板拖动处理 =====================
ScreenshotPanelDragHandler(*) {
    global GuiID_ScreenshotButton
    if (GuiID_ScreenshotButton != 0) {
        PostMessage(0xA1, 2, , GuiID_ScreenshotButton.Hwnd)  ; WM_NCLBUTTONDOWN
    }
}

; ===================== 保存截图面板位置 =====================
SaveScreenshotPanelPosition(*) {
    global GuiID_ScreenshotButton, ScreenshotPanelX, ScreenshotPanelY, ConfigFile, ScreenshotButtonVisible
    
    ; 只在面板可见时保存位置
    if (GuiID_ScreenshotButton != 0 && ScreenshotButtonVisible) {
        try {
            ; 获取窗口当前位置
            WinGetPos(&X, &Y, , , "ahk_id " . GuiID_ScreenshotButton.Hwnd)
            if (X >= 0 && Y >= 0) {  ; 确保位置有效
                ScreenshotPanelX := X
                ScreenshotPanelY := Y
                
                ; 保存到配置文件
                IniWrite(ScreenshotPanelX, ConfigFile, "Screenshot", "PanelX")
                IniWrite(ScreenshotPanelY, ConfigFile, "Screenshot", "PanelY")
            }
        } catch {
            ; 忽略保存失败
        }
    }
}

; ===================== 停止截图等待 =====================
StopScreenshotWaiting() {
    global ScreenshotWaiting, ScreenshotCheckTimer
    
    if (ScreenshotWaiting) {
        ScreenshotWaiting := false
        HideScreenshotButton()
        ; 移除超时提示（按用户要求，不显示任何提示）
    }
}

; ===================== 语音搜索功能 =====================
; 辅助函数：检查数组是否包含某个值
ArrayContainsValue(Arr, Value) {
    ; 【修复】添加安全检查，防止 "Item has no value" 错误
    if (!IsSet(Arr) || !IsObject(Arr) || Arr.Length = 0) {
        return 0
    }
    try {
        for Index, Item in Arr {
            ; 【关键修复】检查 Item 是否有值，防止 "Item has no value" 错误
            try {
                ; 先检查 Item 是否有效，然后再比较
                if (IsSet(Item) && Item = Value) {
                    return Index
                }
            } catch {
                ; 如果 Item 没有值或无法比较，跳过该项
                ; 继续下一次循环
            }
        }
    } catch {
        return 0
    }
    return 0
}

; 开始语音搜索（显示输入框界面）
StartVoiceSearch() {
    global VoiceSearchActive, VoiceSearchPanelVisible, PanelVisible
    
    ; 【关键修复】确保变量已初始化
    if (!IsSet(VoiceSearchPanelVisible)) {
        VoiceSearchPanelVisible := false
    }
    if (!IsSet(VoiceSearchActive)) {
        VoiceSearchActive := false
    }
    
    ; 自动关闭 CapsLock 大写状态
    SetCapsLockState("Off")
    
    ; 如果面板已显示，切换焦点到输入框并清空，然后激活语音输入
    if (VoiceSearchPanelVisible) {
        FocusVoiceSearchInput()
        Sleep(200)
        ; 如果未在语音输入，开始语音输入
        if (!VoiceSearchActive) {
            StartVoiceInputInSearch()
        }
        return
    }
    
    ; 如果正在语音输入中，先停止
    if (VoiceSearchActive) {
        StopVoiceInputInSearch()
    }
    
    ; 如果快捷操作面板正在显示，先关闭它
    if (PanelVisible) {
        HideCursorPanel()
    }
    
    try {
        ; 显示语音搜索输入界面（会自动激活语音输入）
        ShowVoiceSearchInputPanel()
    } catch as e {
        TrayTip(GetText("voice_search_failed") . ": " . e.Message, GetText("error"), "Iconx 2")
    }
}

; 获取所有搜索引擎（带分类信息）
GetAllSearchEngines() {
    ; 定义所有搜索引擎，每个引擎包含分类信息
    AllEngines := [
        ; AI类
        {Name: GetText("search_engine_deepseek"), Value: "deepseek", Category: "ai"},
        {Name: GetText("search_engine_yuanbao"), Value: "yuanbao", Category: "ai"},
        {Name: GetText("search_engine_doubao"), Value: "doubao", Category: "ai"},
        {Name: GetText("search_engine_zhipu"), Value: "zhipu", Category: "ai"},
        {Name: GetText("search_engine_mita"), Value: "mita", Category: "ai"},
        {Name: GetText("search_engine_wenxin"), Value: "wenxin", Category: "ai"},
        {Name: GetText("search_engine_qianwen"), Value: "qianwen", Category: "ai"},
        {Name: GetText("search_engine_kimi"), Value: "kimi", Category: "ai"},
        {Name: GetText("search_engine_perplexity"), Value: "perplexity", Category: "ai"},
        {Name: GetText("search_engine_copilot"), Value: "copilot", Category: "ai"},
        {Name: GetText("search_engine_chatgpt"), Value: "chatgpt", Category: "ai"},
        {Name: GetText("search_engine_grok"), Value: "grok", Category: "ai"},
        {Name: GetText("search_engine_you"), Value: "you", Category: "ai"},
        {Name: GetText("search_engine_claude"), Value: "claude", Category: "ai"},
        {Name: GetText("search_engine_monica"), Value: "monica", Category: "ai"},
        {Name: GetText("search_engine_webpilot"), Value: "webpilot", Category: "ai"},
        
        ; 学术类
        {Name: GetText("search_engine_zhihu"), Value: "zhihu", Category: "academic"},
        {Name: GetText("search_engine_wechat_article"), Value: "wechat_article", Category: "academic"},
        {Name: GetText("search_engine_cainiao"), Value: "cainiao", Category: "academic"},
        {Name: GetText("search_engine_gitee"), Value: "gitee", Category: "academic"},
        {Name: GetText("search_engine_pubscholar"), Value: "pubscholar", Category: "academic"},
        {Name: GetText("search_engine_semantic"), Value: "semantic", Category: "academic"},
        {Name: GetText("search_engine_baidu_academic"), Value: "baidu_academic", Category: "academic"},
        {Name: GetText("search_engine_bing_academic"), Value: "bing_academic", Category: "academic"},
        {Name: GetText("search_engine_csdn"), Value: "csdn", Category: "academic"},
        {Name: GetText("search_engine_national_library"), Value: "national_library", Category: "academic"},
        {Name: GetText("search_engine_chaoxing"), Value: "chaoxing", Category: "academic"},
        {Name: GetText("search_engine_cnki"), Value: "cnki", Category: "academic"},
        {Name: GetText("search_engine_wechat_reading"), Value: "wechat_reading", Category: "academic"},
        {Name: GetText("search_engine_dada"), Value: "dada", Category: "academic"},
        {Name: GetText("search_engine_patent"), Value: "patent", Category: "academic"},
        {Name: GetText("search_engine_ip_office"), Value: "ip_office", Category: "academic"},
        {Name: GetText("search_engine_dedao"), Value: "dedao", Category: "academic"},
        {Name: GetText("search_engine_pkmer"), Value: "pkmer", Category: "academic"},
        
        ; 百度类
        {Name: GetText("search_engine_baidu"), Value: "baidu", Category: "baidu"},
        {Name: GetText("search_engine_baidu_title"), Value: "baidu_title", Category: "baidu"},
        {Name: GetText("search_engine_baidu_hanyu"), Value: "baidu_hanyu", Category: "baidu"},
        {Name: GetText("search_engine_baidu_wenku"), Value: "baidu_wenku", Category: "baidu"},
        {Name: GetText("search_engine_baidu_map"), Value: "baidu_map", Category: "baidu"},
        {Name: GetText("search_engine_baidu_pdf"), Value: "baidu_pdf", Category: "baidu"},
        {Name: GetText("search_engine_baidu_doc"), Value: "baidu_doc", Category: "baidu"},
        {Name: GetText("search_engine_baidu_ppt"), Value: "baidu_ppt", Category: "baidu"},
        {Name: GetText("search_engine_baidu_xls"), Value: "baidu_xls", Category: "baidu"},
        
        ; 图片类
        {Name: GetText("search_engine_image_aggregate"), Value: "image_aggregate", Category: "image"},
        {Name: GetText("search_engine_iconfont"), Value: "iconfont", Category: "image"},
        {Name: GetText("search_engine_wenxin_image"), Value: "wenxin_image", Category: "image"},
        {Name: GetText("search_engine_tiangong_image"), Value: "tiangong_image", Category: "image"},
        {Name: GetText("search_engine_yuanbao_image"), Value: "yuanbao_image", Category: "image"},
        {Name: GetText("search_engine_tongyi_image"), Value: "tongyi_image", Category: "image"},
        {Name: GetText("search_engine_zhipu_image"), Value: "zhipu_image", Category: "image"},
        {Name: GetText("search_engine_miaohua"), Value: "miaohua", Category: "image"},
        {Name: GetText("search_engine_keling"), Value: "keling", Category: "image"},
        {Name: GetText("search_engine_jimmeng"), Value: "jimmeng", Category: "image"},
        {Name: GetText("search_engine_baidu_image"), Value: "baidu_image", Category: "image"},
        {Name: GetText("search_engine_shetu"), Value: "shetu", Category: "image"},
        {Name: GetText("search_engine_ai_image_lib"), Value: "ai_image_lib", Category: "image"},
        {Name: GetText("search_engine_huaban"), Value: "huaban", Category: "image"},
        {Name: GetText("search_engine_zcool"), Value: "zcool", Category: "image"},
        {Name: GetText("search_engine_uisdc"), Value: "uisdc", Category: "image"},
        {Name: GetText("search_engine_nipic"), Value: "nipic", Category: "image"},
        {Name: GetText("search_engine_qianku"), Value: "qianku", Category: "image"},
        {Name: GetText("search_engine_qiantu"), Value: "qiantu", Category: "image"},
        {Name: GetText("search_engine_zhongtu"), Value: "zhongtu", Category: "image"},
        {Name: GetText("search_engine_miyuan"), Value: "miyuan", Category: "image"},
        {Name: GetText("search_engine_mizhi"), Value: "mizhi", Category: "image"},
        {Name: GetText("search_engine_icons"), Value: "icons", Category: "image"},
        {Name: GetText("search_engine_tuxing"), Value: "tuxing", Category: "image"},
        {Name: GetText("search_engine_xiangsheji"), Value: "xiangsheji", Category: "image"},
        {Name: GetText("search_engine_bing_image"), Value: "bing_image", Category: "image"},
        {Name: GetText("search_engine_google_image"), Value: "google_image", Category: "image"},
        {Name: GetText("search_engine_weibo_image"), Value: "weibo_image", Category: "image"},
        {Name: GetText("search_engine_sogou_image"), Value: "sogou_image", Category: "image"},
        {Name: GetText("search_engine_haosou_image"), Value: "haosou_image", Category: "image"},
        
        ; 音频类
        {Name: GetText("search_engine_netease_music"), Value: "netease_music", Category: "audio"},
        {Name: GetText("search_engine_tiangong_music"), Value: "tiangong_music", Category: "audio"},
        {Name: GetText("search_engine_text_to_speech"), Value: "text_to_speech", Category: "audio"},
        {Name: GetText("search_engine_speech_to_text"), Value: "speech_to_text", Category: "audio"},
        {Name: GetText("search_engine_shetu_music"), Value: "shetu_music", Category: "audio"},
        {Name: GetText("search_engine_qq_music"), Value: "qq_music", Category: "audio"},
        {Name: GetText("search_engine_kuwo"), Value: "kuwo", Category: "audio"},
        {Name: GetText("search_engine_kugou"), Value: "kugou", Category: "audio"},
        {Name: GetText("search_engine_qianqian"), Value: "qianqian", Category: "audio"},
        {Name: GetText("search_engine_ximalaya"), Value: "ximalaya", Category: "audio"},
        {Name: GetText("search_engine_5sing"), Value: "5sing", Category: "audio"},
        {Name: GetText("search_engine_lossless"), Value: "lossless", Category: "audio"},
        {Name: GetText("search_engine_erling"), Value: "erling", Category: "audio"},
        
        ; 视频类
        {Name: GetText("search_engine_douyin"), Value: "douyin", Category: "video"},
        {Name: GetText("search_engine_yuewen"), Value: "yuewen", Category: "video"},
        {Name: GetText("search_engine_qingying"), Value: "qingying", Category: "video"},
        {Name: GetText("search_engine_tongyi_video"), Value: "tongyi_video", Category: "video"},
        {Name: GetText("search_engine_jimmeng_video"), Value: "jimmeng_video", Category: "video"},
        {Name: GetText("search_engine_youtube"), Value: "youtube", Category: "video"},
        {Name: GetText("search_engine_find_lines"), Value: "find_lines", Category: "video"},
        {Name: GetText("search_engine_shetu_video"), Value: "shetu_video", Category: "video"},
        {Name: GetText("search_engine_yandex"), Value: "yandex", Category: "video"},
        {Name: GetText("search_engine_pexels"), Value: "pexels", Category: "video"},
        {Name: GetText("search_engine_youku"), Value: "youku", Category: "video"},
        {Name: GetText("search_engine_chanjing"), Value: "chanjing", Category: "video"},
        {Name: GetText("search_engine_duojia"), Value: "duojia", Category: "video"},
        {Name: GetText("search_engine_tencent_zhiying"), Value: "tencent_zhiying", Category: "video"},
        {Name: GetText("search_engine_wansheng"), Value: "wansheng", Category: "video"},
        {Name: GetText("search_engine_tencent_video"), Value: "tencent_video", Category: "video"},
        {Name: GetText("search_engine_iqiyi"), Value: "iqiyi", Category: "video"},
        
        ; 图书类
        {Name: GetText("search_engine_duokan"), Value: "duokan", Category: "book"},
        {Name: GetText("search_engine_turing"), Value: "turing", Category: "book"},
        {Name: GetText("search_engine_panda_book"), Value: "panda_book", Category: "book"},
        {Name: GetText("search_engine_douban_book"), Value: "douban_book", Category: "book"},
        {Name: GetText("search_engine_lifelong_edu"), Value: "lifelong_edu", Category: "book"},
        {Name: GetText("search_engine_verypan"), Value: "verypan", Category: "book"},
        {Name: GetText("search_engine_zouddupai"), Value: "zouddupai", Category: "book"},
        {Name: GetText("search_engine_gd_library"), Value: "gd_library", Category: "book"},
        {Name: GetText("search_engine_pansou"), Value: "pansou", Category: "book"},
        {Name: GetText("search_engine_zsxq"), Value: "zsxq", Category: "book"},
        {Name: GetText("search_engine_jiumo"), Value: "jiumo", Category: "book"},
        {Name: GetText("search_engine_weibo_book"), Value: "weibo_book", Category: "book"},
        
        ; 比价类
        {Name: GetText("search_engine_jd"), Value: "jd", Category: "price"},
        {Name: GetText("search_engine_baidu_procure"), Value: "baidu_procure", Category: "price"},
        {Name: GetText("search_engine_dangdang"), Value: "dangdang", Category: "price"},
        {Name: GetText("search_engine_1688"), Value: "1688", Category: "price"},
        {Name: GetText("search_engine_taobao"), Value: "taobao", Category: "price"},
        {Name: GetText("search_engine_tmall"), Value: "tmall", Category: "price"},
        {Name: GetText("search_engine_pinduoduo"), Value: "pinduoduo", Category: "price"},
        {Name: GetText("search_engine_xianyu"), Value: "xianyu", Category: "price"},
        {Name: GetText("search_engine_smzdm"), Value: "smzdm", Category: "price"},
        {Name: GetText("search_engine_yanxuan"), Value: "yanxuan", Category: "price"},
        {Name: GetText("search_engine_gaide"), Value: "gaide", Category: "price"},
        {Name: GetText("search_engine_suning"), Value: "suning", Category: "price"},
        {Name: GetText("search_engine_ebay"), Value: "ebay", Category: "price"},
        {Name: GetText("search_engine_amazon"), Value: "amazon", Category: "price"},
        
        ; 医疗类
        {Name: GetText("search_engine_dxy"), Value: "dxy", Category: "medical"},
        {Name: GetText("search_engine_left_doctor"), Value: "left_doctor", Category: "medical"},
        {Name: GetText("search_engine_medisearch"), Value: "medisearch", Category: "medical"},
        {Name: GetText("search_engine_merck"), Value: "merck", Category: "medical"},
        {Name: GetText("search_engine_aplus_medical"), Value: "aplus_medical", Category: "medical"},
        {Name: GetText("search_engine_medical_baike"), Value: "medical_baike", Category: "medical"},
        {Name: GetText("search_engine_weiyi"), Value: "weiyi", Category: "medical"},
        {Name: GetText("search_engine_medlive"), Value: "medlive", Category: "medical"},
        {Name: GetText("search_engine_xywy"), Value: "xywy", Category: "medical"},
        
        ; 网盘类
        {Name: GetText("search_engine_pansoso"), Value: "pansoso", Category: "cloud"},
        {Name: GetText("search_engine_panso"), Value: "panso", Category: "cloud"},
        {Name: GetText("search_engine_xiaomapan"), Value: "xiaomapan", Category: "cloud"},
        {Name: GetText("search_engine_dashengpan"), Value: "dashengpan", Category: "cloud"},
        {Name: GetText("search_engine_miaosou"), Value: "miaosou", Category: "cloud"}
    ]
    
    return AllEngines
}

; 获取排序后的搜索引擎列表（根据语言版本和分类过滤）
GetSortedSearchEngines(Category := "") {
    global Language, VoiceSearchCurrentCategory
    
    ; 如果没有指定分类，使用当前选中的分类
    if (Category = "") {
        Category := VoiceSearchCurrentCategory
    }
    
    ; 获取所有搜索引擎
    AllEngines := GetAllSearchEngines()
    
    ; 按分类过滤
    FilteredEngines := []
    for Index, Engine in AllEngines {
        ; 【修复】添加安全检查，防止访问无效对象属性
        if (IsObject(Engine) && Engine.HasProp("Category") && Engine.Category = Category) {
            FilteredEngines.Push(Engine)
        }
    }
    
    ; 如果当前分类没有搜索引擎，返回空数组（不显示提示，让调用者处理）
    if (FilteredEngines.Length = 0) {
        return FilteredEngines
    }
    
    ; 根据语言版本排序（仅对AI类有效）
    if (Category = "ai") {
        ChineseEngines := []
        AIEngines := []
        
        for Index, Engine in FilteredEngines {
            ; 【修复】添加安全检查，防止访问无效对象属性
            if (!IsObject(Engine) || !Engine.HasProp("Value")) {
                continue
            }
            ; 判断是中文引擎还是AI引擎
            ChineseEngineValues := ["deepseek", "yuanbao", "doubao", "zhipu", "mita", "wenxin", "qianwen", "kimi"]
            if (ArrayContainsValue(ChineseEngineValues, Engine.Value) > 0) {
                ChineseEngines.Push(Engine)
            } else {
                AIEngines.Push(Engine)
            }
        }
        
        ; 根据语言版本排序
        if (Language = "en") {
            ; 英文版：AI引擎在前，中文引擎在后
            SearchEngines := []
            for Index, Engine in AIEngines {
                SearchEngines.Push(Engine)
            }
            for Index, Engine in ChineseEngines {
                SearchEngines.Push(Engine)
            }
        } else {
            ; 中文版：中文引擎在前，AI引擎在后
            SearchEngines := []
            for Index, Engine in ChineseEngines {
                SearchEngines.Push(Engine)
            }
            for Index, Engine in AIEngines {
                SearchEngines.Push(Engine)
            }
        }
        
        return SearchEngines
    }
    
    ; 其他分类直接返回过滤后的结果
    return FilteredEngines
}

; 获取搜索引擎对应的图标文件名
GetSearchEngineIcon(EngineValue) {
    ; 根据搜索引擎值返回对应的图标文件名
    IconMap := Map(
        ; AI类
        "deepseek", "DeepSeek.png",
        "yuanbao", "元宝.png",
        "doubao", "豆包.png",
        "zhipu", "智谱.png",
        "mita", "秘塔.png",
        "wenxin", "文心一言.png",
        "qianwen", "通义千问.png",
        "kimi", "Kimi.png",
        "perplexity", "Perplexity.png",
        "copilot", "Copilot.png",
        "chatgpt", "ChatGPT.png",
        "grok", "Grok.png",
        "you", "You.png",
        "claude", "Claude.png",
        "monica", "Monica.png",
        "webpilot", "WebPilot.png"
        ; 注意：其他分类的搜索引擎如果没有对应的图标文件，会返回空字符串，使用文本显示
    )
    
    IconName := IconMap.Get(EngineValue, "")
    if (IconName != "") {
        ; 返回完整的图标路径
        ScriptDir := A_ScriptDir
        IconPath := ScriptDir . "\aiicons\" . IconName
        if (FileExist(IconPath)) {
            return IconPath
        }
    }
    return ""  ; 如果图标不存在，返回空字符串
}

; 创建分类标签切换处理函数
CreateCategoryTabHandler(CategoryKey) {
    ; 使用闭包捕获CategoryKey
    CategoryTabHandler(*) {
        global VoiceSearchCurrentCategory, VoiceSearchCategoryTabs, VoiceSearchEngineButtons, GuiID_VoiceInput
        global VoiceSearchSelectedEngines, UI_Colors, ThemeMode, VoiceSearchLabelEngineY
        global VoiceSearchSelectedEnginesByCategory
        
        ; 确保 VoiceSearchSelectedEnginesByCategory 已初始化
        if (!IsSet(VoiceSearchSelectedEnginesByCategory) || !IsObject(VoiceSearchSelectedEnginesByCategory)) {
            VoiceSearchSelectedEnginesByCategory := Map()
        }
        
        ; 【关键修复】保存当前分类的搜索引擎选择状态
        OldCategory := VoiceSearchCurrentCategory
        if (OldCategory != "" && OldCategory != CategoryKey) {
            ; 保存当前分类的选择状态
            CurrentEngines := []
            for Index, Engine in VoiceSearchSelectedEngines {
                CurrentEngines.Push(Engine)
            }
            VoiceSearchSelectedEnginesByCategory[OldCategory] := CurrentEngines
        }
        
        ; 使用捕获的CategoryKey，而不是全局变量
        ; 更新当前分类
        VoiceSearchCurrentCategory := CategoryKey
        
        ; 确保GUI存在
        if (!GuiID_VoiceInput) {
            return
        }
        
        ; 更新所有标签按钮的样式
        for Index, TabObj in VoiceSearchCategoryTabs {
            ; 【关键修复】如果按钮引用丢失，尝试从GUI重新获取
            if (!TabObj.Btn || !IsObject(TabObj.Btn)) {
                try {
                    TabObj.Btn := GuiID_VoiceInput["CategoryTab" . TabObj.Key]
                } catch {
                    ; 如果无法获取，跳过这个标签
                    continue
                }
            }
            
            if (TabObj.Btn && IsObject(TabObj.Btn)) {
                IsActive := (TabObj.Key = CategoryKey)
                TabBg := IsActive ? UI_Colors.BtnPrimary : UI_Colors.BtnBg
                TabTextColor := IsActive ? "FFFFFF" : ((ThemeMode = "light") ? UI_Colors.Text : "FFFFFF")
                try {
                    ; 【关键修复】使用 Opt() 方法更新背景色，确保立即生效
                    TabObj.Btn.Opt("+Background" . TabBg)
                    TabObj.Btn.SetFont("s9 c" . TabTextColor, "Segoe UI")
                    TabObj.Btn.Text := GetText("search_category_" . TabObj.Key)
                    ; 强制重绘以确保背景色更新
                    TabObj.Btn.Redraw()
                } catch {
                    ; 如果上述方法失败，尝试直接设置 BackColor
                    try {
                        TabObj.Btn.BackColor := TabBg
                        TabObj.Btn.SetFont("s9 c" . TabTextColor, "Segoe UI")
                        TabObj.Btn.Text := GetText("search_category_" . TabObj.Key)
                    } catch {
                        ; 忽略更新样式时的错误
                    }
                }
            }
        }
        
        ; 【关键修复】恢复新分类的搜索引擎选择状态
        if (VoiceSearchSelectedEnginesByCategory.Has(CategoryKey)) {
            ; 如果该分类有保存的选择状态，恢复它
            VoiceSearchSelectedEngines := []
            for Index, Engine in VoiceSearchSelectedEnginesByCategory[CategoryKey] {
                VoiceSearchSelectedEngines.Push(Engine)
            }
        } else {
            ; 如果该分类没有保存的选择状态，使用默认值（根据分类的第一个搜索引擎）
            try {
                SearchEngines := GetSortedSearchEngines(CategoryKey)
                if (SearchEngines && SearchEngines.Length > 0 && IsObject(SearchEngines[1]) && SearchEngines[1].HasProp("Value")) {
                    VoiceSearchSelectedEngines := [SearchEngines[1].Value]
                } else {
                    VoiceSearchSelectedEngines := ["deepseek"]
                }
            } catch {
                VoiceSearchSelectedEngines := ["deepseek"]
            }
        }
        
        ; 【关键修复】先刷新标签背景色，确保立即显示
        try {
            if (GuiID_VoiceInput && IsObject(GuiID_VoiceInput) && GuiID_VoiceInput.HasProp("Hwnd")) {
                WinRedraw(GuiID_VoiceInput.Hwnd)
            }
        } catch {
            ; 忽略刷新错误
        }
        
        ; 【关键修复】刷新搜索引擎按钮显示（隐藏旧的，显示新的）
        ; 使用短暂延迟确保标签背景色先更新，提升流畅度
        SetTimer(() => RefreshSearchEngineButtons(), -10)
    }
    return CategoryTabHandler
}

; ===================== 刷新搜索引擎按钮显示 =====================
RefreshSearchEngineButtons() {
    global GuiID_VoiceInput, VoiceSearchCurrentCategory, VoiceSearchEngineButtons, VoiceSearchSelectedEngines
    global VoiceSearchLabelEngineY, UI_Colors, ThemeMode
    
    if (!GuiID_VoiceInput) {
        return
    }
    
    ; 【关键修复】从GUI窗口获取实际宽度
    try {
        WinGetPos(, , &PanelWidth, , "ahk_id " . GuiID_VoiceInput.Hwnd)
    } catch {
        ; 如果获取失败，使用默认值
        PanelWidth := 600
    }
    
    ; 【关键修复】优化切换流畅度：先隐藏旧按钮，创建新按钮后再销毁旧按钮
    if (IsSet(VoiceSearchEngineButtons) && IsObject(VoiceSearchEngineButtons)) {
        ; 先隐藏所有旧按钮（不立即销毁，保持界面流畅）
        for Index, BtnObj in VoiceSearchEngineButtons {
            if (IsObject(BtnObj)) {
                try {
                    if (BtnObj.Bg) {
                        BtnObj.Bg.Visible := false
                    }
                    if (BtnObj.Icon) {
                        BtnObj.Icon.Visible := false
                    }
                    if (BtnObj.Text) {
                        BtnObj.Text.Visible := false
                    }
                } catch {
                    ; 忽略隐藏错误
                }
            }
        }
    }
    
    ; 保存旧按钮数组用于后续销毁
    OldButtons := VoiceSearchEngineButtons
    ; 清空按钮数组，准备创建新按钮
    VoiceSearchEngineButtons := []
    
    ; 获取当前分类的搜索引擎列表
    try {
        SearchEngines := GetSortedSearchEngines(VoiceSearchCurrentCategory)
    } catch {
        return
    }
    
    if (!IsObject(SearchEngines) || SearchEngines.Length = 0) {
        return
    }
    
    ; 计算按钮位置和布局
    global VoiceSearchLabelEngineY
    YPos := VoiceSearchLabelEngineY + 30
    ButtonWidth := 130
    ButtonHeight := 35
    ButtonSpacing := 10
    StartX := 20
    ButtonsPerRow := 4
    IconSizeInButton := 20
    
    AvailableWidth := PanelWidth - 40
    MaxButtonsPerRow := Floor((AvailableWidth + ButtonSpacing) / (ButtonWidth + ButtonSpacing))
    if (MaxButtonsPerRow < 1) {
        MaxButtonsPerRow := 1
    }
    ButtonsPerRow := Min(ButtonsPerRow, MaxButtonsPerRow)
    
    ; 创建新的搜索引擎按钮
    for Index, Engine in SearchEngines {
        if (!IsObject(Engine) || !Engine.HasProp("Value") || !Engine.HasProp("Name")) {
            continue
        }
        
        Row := Floor((Index - 1) / ButtonsPerRow)
        Col := Mod((Index - 1), ButtonsPerRow)
        BtnX := StartX + Col * (ButtonWidth + ButtonSpacing)
        BtnY := YPos + Row * (ButtonHeight + ButtonSpacing)
        
        IsSelected := (ArrayContainsValue(VoiceSearchSelectedEngines, Engine.Value) > 0)
        BtnBgColor := IsSelected ? UI_Colors.BtnHover : UI_Colors.BtnBg
        BtnText := IsSelected ? "✓ " . Engine.Name : Engine.Name
        EngineBtnTextColor := (ThemeMode = "light") ? UI_Colors.Text : "FFFFFF"
        
        IconPath := GetSearchEngineIcon(Engine.Value)
        IconCtrl := 0
        
        Btn := GuiID_VoiceInput.Add("Text", "x" . BtnX . " y" . BtnY . " w" . ButtonWidth . " h" . ButtonHeight . " Center 0x200 c" . EngineBtnTextColor . " Background" . BtnBgColor, "")
        Btn.SetFont("s10", "Segoe UI")
        Btn.OnEvent("Click", CreateToggleSearchEngineHandler(Engine.Value, Index))
        HoverBtn(Btn, BtnBgColor, UI_Colors.BtnHover)
        
        if (IconPath != "" && FileExist(IconPath)) {
            try {
                IconX := BtnX + 8
                IconY := BtnY + (ButtonHeight - IconSizeInButton) // 2
                
                ImageSize := GetImageSize(IconPath)
                DisplaySize := CalculateImageDisplaySize(ImageSize.Width, ImageSize.Height, IconSizeInButton, IconSizeInButton)
                
                DisplayX := IconX
                DisplayY := IconY + (IconSizeInButton - DisplaySize.Height) // 2
                
                IconCtrl := GuiID_VoiceInput.Add("Picture", "x" . DisplayX . " y" . DisplayY . " w" . DisplaySize.Width . " h" . DisplaySize.Height . " 0x200", IconPath)
                IconCtrl.OnEvent("Click", CreateToggleSearchEngineHandler(Engine.Value, Index))
                
                TextX := IconX + IconSizeInButton + 5
                TextWidth := ButtonWidth - (TextX - BtnX) - 8
            } catch {
                IconCtrl := 0
                TextX := BtnX + 8
                TextWidth := ButtonWidth - 16
            }
        } else {
            TextX := BtnX + 8
            TextWidth := ButtonWidth - 16
        }
        
        TextCtrl := GuiID_VoiceInput.Add("Text", "x" . TextX . " y" . BtnY . " w" . TextWidth . " h" . ButtonHeight . " Left 0x200 c" . EngineBtnTextColor . " BackgroundTrans", BtnText)
        TextCtrl.SetFont("s10", "Segoe UI")
        TextCtrl.OnEvent("Click", CreateToggleSearchEngineHandler(Engine.Value, Index))
        
        ; 使用新的索引（从1开始）
        NewIndex := VoiceSearchEngineButtons.Length + 1
        VoiceSearchEngineButtons.Push({Bg: Btn, Icon: IconCtrl, Text: TextCtrl, Index: NewIndex})
    }
    
    ; 【关键修复】刷新GUI显示，确保新按钮立即显示
    try {
        if (GuiID_VoiceInput && IsObject(GuiID_VoiceInput) && GuiID_VoiceInput.HasProp("Hwnd")) {
            WinRedraw(GuiID_VoiceInput.Hwnd)
        }
    } catch {
        ; 忽略刷新错误
    }
    
    ; 【关键修复】延迟销毁旧按钮，确保新按钮已显示后再清理，提升流畅度
    SetTimer(() => DestroyOldSearchEngineButtons(OldButtons), -100)
}

; 销毁旧的搜索引擎按钮（延迟执行，提升流畅度）
DestroyOldSearchEngineButtons(OldButtons) {
    if (!IsSet(OldButtons) || !IsObject(OldButtons)) {
        return
    }
    
    for Index, BtnObj in OldButtons {
        if (IsObject(BtnObj)) {
            try {
                if (BtnObj.Bg) {
                    BtnObj.Bg.Destroy()
                }
                if (BtnObj.Icon) {
                    BtnObj.Icon.Destroy()
                }
                if (BtnObj.Text) {
                    BtnObj.Text.Destroy()
                }
            } catch {
                ; 忽略销毁错误
            }
        }
    }
}

; ===================== 语音搜索相关函数 =====================
; 执行语音搜索
ExecuteVoiceSearch(*) {
    global VoiceSearchInputEdit, VoiceSearchSelectedEngines, VoiceSearchPanelVisible
    
    if (!VoiceSearchPanelVisible || !VoiceSearchInputEdit) {
        return
    }
    
    try {
        Content := VoiceSearchInputEdit.Value
        if (Content != "" && StrLen(Content) > 0) {
            ; 检查是否有选中的搜索引擎
            if (VoiceSearchSelectedEngines.Length = 0) {
                TrayTip(GetText("no_search_engine_selected"), GetText("tip"), "Icon! 2")
                return
            }
            
            ; 隐藏面板
            HideVoiceSearchInputPanel()
            
            ; 打开所有选中的搜索引擎
            ; 【修复】检查VoiceSearchSelectedEngines是否已初始化且不为空
            if (!IsSet(VoiceSearchSelectedEngines) || !IsObject(VoiceSearchSelectedEngines) || VoiceSearchSelectedEngines.Length = 0) {
                TrayTip(GetText("no_search_engine_selected"), GetText("tip"), "Icon! 2")
                return
            }
            
            for Index, Engine in VoiceSearchSelectedEngines {
                ; 【修复】检查Engine是否有值
                if (!IsSet(Engine) || Engine = "") {
                    continue  ; 跳过无效的引擎
                }
                SendVoiceSearchToBrowser(Content, Engine)
                ; 每个搜索引擎之间稍作延迟，避免同时打开太多窗口
                if (Index < VoiceSearchSelectedEngines.Length) {
                    Sleep(300)
                }
            }
            
            TrayTip(FormatText("search_engines_opened", VoiceSearchSelectedEngines.Length), GetText("tip"), "Iconi 1")
        }
    } catch as e {
        TrayTip(GetText("voice_search_failed") . ": " . e.Message, GetText("error"), "Iconx 2")
    }
}

; 开始语音输入（在语音搜索界面中）
StartVoiceInputInSearch() {
    global VoiceSearchActive, VoiceInputMethod, VoiceSearchPanelVisible, VoiceSearchInputEdit, UI_Colors
    
    if (VoiceSearchActive || !VoiceSearchPanelVisible) {
        return
    }
    
    try {
        ; 确保窗口激活并输入框有真正的输入焦点
        global GuiID_VoiceInput
        if (GuiID_VoiceInput) {
            ; 激活窗口
            WinActivate("ahk_id " . GuiID_VoiceInput.Hwnd)
            Sleep(200)
            
            ; 确保窗口真正激活
            if (!WinActive("ahk_id " . GuiID_VoiceInput.Hwnd)) {
                ; 如果仍未激活，再次尝试
                WinActivate("ahk_id " . GuiID_VoiceInput.Hwnd)
                Sleep(200)
            }
        }
        
        ; 确保输入框为空并获取真正的输入焦点
        if (VoiceSearchInputEdit) {
            VoiceSearchInputEdit.Value := ""
            
            ; 获取输入框的控件句柄
            InputEditHwnd := VoiceSearchInputEdit.Hwnd
            
            ; 使用ControlFocus确保输入框有真正的输入焦点（IME焦点）
            try {
                ControlFocus(InputEditHwnd, "ahk_id " . GuiID_VoiceInput.Hwnd)
                Sleep(100)
            } catch {
                ; 如果ControlFocus失败，使用Focus方法
                VoiceSearchInputEdit.Focus()
                Sleep(100)
            }
        }
        
        ; 自动检测输入法类型
        VoiceInputMethod := DetectInputMethod()
        
        ; 根据输入法类型使用不同的快捷键
        if (VoiceInputMethod = "baidu") {
            ; 百度输入法：Alt+Y 激活，F2 开始
            if (VoiceSearchInputEdit) {
                InputEditHwnd := VoiceSearchInputEdit.Hwnd
                try {
                    ControlFocus(InputEditHwnd, "ahk_id " . GuiID_VoiceInput.Hwnd)
                    Sleep(150)
                } catch {
                    VoiceSearchInputEdit.Focus()
                    Sleep(150)
                }
                ; 切换到中文输入法，确保百度输入法处于活动状态
                SwitchToChineseIME()
                Sleep(200)
            }
            
            ; 发送 Alt+Y 激活百度输入法
            Send("!y")
            Sleep(800)
            
            ; 发送 F2 开始语音输入
            Send("{F2}")
            Sleep(300)
        } else if (VoiceInputMethod = "xunfei") {
            ; 讯飞输入法：直接按 F6 开始语音输入
            Send("{F6}")
            Sleep(800)
            if (VoiceSearchInputEdit) {
                InputEditHwnd := VoiceSearchInputEdit.Hwnd
                try {
                    ControlFocus(InputEditHwnd, "ahk_id " . GuiID_VoiceInput.Hwnd)
                    Sleep(100)
                } catch {
                    VoiceSearchInputEdit.Focus()
                    Sleep(100)
                }
            }
        } else {
            ; 默认尝试百度方案
            if (VoiceSearchInputEdit) {
                InputEditHwnd := VoiceSearchInputEdit.Hwnd
                try {
                    ControlFocus(InputEditHwnd, "ahk_id " . GuiID_VoiceInput.Hwnd)
                    Sleep(150)
                } catch {
                    VoiceSearchInputEdit.Focus()
                    Sleep(150)
                }
                SwitchToChineseIME()
                Sleep(200)
            }
            
            Send("!y")
            Sleep(800)
            Send("{F2}")
            Sleep(300)
        }
        
        VoiceSearchActive := true
        global VoiceSearchContent := ""
        
        ; 等待一下，确保语音输入已启动，再开始更新输入框内容
        Sleep(500)
        ; 根据"自动更新语音输入"或"自动加载选中文本"开关状态决定是否开始更新输入框内容
        global AutoLoadSelectedText, AutoUpdateVoiceInput
        ; 先停止定时器，确保状态正确
        SetTimer(UpdateVoiceSearchInputInPanel, 0)
        if (AutoUpdateVoiceInput || AutoLoadSelectedText) {
            ; 如果"自动更新语音输入"或"自动加载选中文本"任一开启，启动定时器
            SetTimer(UpdateVoiceSearchInputInPanel, 300)  ; 每300ms更新一次
        }
    } catch as e {
        VoiceSearchActive := false
        TrayTip(GetText("voice_search_failed") . ": " . e.Message, GetText("error"), "Iconx 2")
    }
}

; 停止语音输入（在语音搜索界面中）
StopVoiceInputInSearch() {
    global VoiceSearchActive, VoiceInputMethod, CapsLock, VoiceSearchInputEdit, VoiceSearchPanelVisible, UI_Colors
    
    if (!VoiceSearchActive || !VoiceSearchPanelVisible) {
        return
    }
    
    try {
        ; 先确保CapsLock状态被重置
        if (CapsLock) {
            CapsLock := false
        }
        
        ; 根据输入法类型使用不同的结束快捷键
        if (VoiceInputMethod = "baidu") {
            ; 百度输入法：F1 结束语音录入
            Send("{F1}")
            Sleep(800)
            
            ; 获取语音输入内容
            OldClipboard := A_Clipboard
            Send("^a")
            Sleep(200)
            A_Clipboard := ""
            Send("^c")
            if ClipWait(1.5) {
                global VoiceSearchContent := A_Clipboard
            }
            A_Clipboard := OldClipboard
            
            ; 退出百度输入法语音模式
            Send("!y")
            Sleep(300)
        } else if (VoiceInputMethod = "xunfei") {
            ; 讯飞输入法：F6 结束
            Send("{F6}")
            Sleep(1000)
            
            ; 获取语音输入内容
            OldClipboard := A_Clipboard
            Send("^a")
            Sleep(200)
            A_Clipboard := ""
            Send("^c")
            if ClipWait(1.5) {
                global VoiceSearchContent := A_Clipboard
            }
            A_Clipboard := OldClipboard
        } else {
            ; 默认尝试百度方案
            Send("{F1}")
            Sleep(800)
            
            ; 获取语音输入内容
            OldClipboard := A_Clipboard
            Send("^a")
            Sleep(200)
            A_Clipboard := ""
            Send("^c")
            if ClipWait(1.5) {
                global VoiceSearchContent := A_Clipboard
            }
            A_Clipboard := OldClipboard
            
            ; 退出百度输入法语音模式
            Send("!y")
            Sleep(300)
        }
        
        VoiceSearchActive := false
        SetTimer(UpdateVoiceSearchInputInPanel, 0)  ; 停止更新输入框
        
        ; 将内容填入输入框
        global VoiceSearchContent
        if (VoiceSearchContent != "" && StrLen(VoiceSearchContent) > 0 && VoiceSearchInputEdit) {
            VoiceSearchInputEdit.Value := VoiceSearchContent
            VoiceSearchInputEdit.Focus()
        }
    } catch as e {
        VoiceSearchActive := false
        SetTimer(UpdateVoiceSearchInputInPanel, 0)
        TrayTip(GetText("voice_search_failed") . ": " . e.Message, GetText("error"), "Iconx 2")
    }
}

; 聚焦语音搜索输入框
FocusVoiceSearchInput() {
    global VoiceSearchInputEdit, VoiceSearchPanelVisible, AutoLoadSelectedText
    
    if (!VoiceSearchPanelVisible || !VoiceSearchInputEdit) {
        return
    }
    
    try {
        ; 清空输入框
        VoiceSearchInputEdit.Value := ""
        ; 设置焦点
        VoiceSearchInputEdit.Focus()
        
        ; 根据开关状态确保定时器状态正确
        ; 先停止定时器，然后根据开关状态决定是否启动
        SetTimer(MonitorSelectedText, 0)
        
        ; 只有在开关开启时才启动定时器
        if (AutoLoadSelectedText) {
            SetTimer(MonitorSelectedText, 200)  ; 每200ms检查一次
        } else {
            ; 确保定时器已停止
            SetTimer(MonitorSelectedText, 0)
        }
    } catch {
        ; 忽略错误
    }
}

; 切换自动加载选中文本开关（语音输入界面）
ToggleAutoLoadSelectedTextForVoiceInput(*) {
    global AutoLoadSelectedText, VoiceInputAutoLoadSwitch, VoiceInputActionSelectionVisible, UI_Colors, ConfigFile
    
    if (!VoiceInputActionSelectionVisible || !VoiceInputAutoLoadSwitch) {
        return
    }
    
    ; 切换状态
    AutoLoadSelectedText := !AutoLoadSelectedText
    
    ; 更新开关显示
    SwitchText := AutoLoadSelectedText ? "✓ 已开启" : "○ 已关闭"
    SwitchBg := AutoLoadSelectedText ? UI_Colors.BtnHover : UI_Colors.BtnBg
    VoiceInputAutoLoadSwitch.Text := SwitchText
    VoiceInputAutoLoadSwitch.BackColor := SwitchBg
    
    ; 保存到配置文件
    try {
        IniWrite(AutoLoadSelectedText ? "1" : "0", ConfigFile, "Settings", "AutoLoadSelectedText")
    } catch {
        ; 忽略保存错误
    }
    
    ; 如果开启，启动监听；如果关闭，立即停止监听
    if (AutoLoadSelectedText) {
        SetTimer(MonitorSelectedTextForVoiceInput, 200)  ; 每200ms检查一次
    } else {
        ; 立即停止监听，确保不会继续自动加载
        SetTimer(MonitorSelectedTextForVoiceInput, 0)
    }
}

; 监听选中文本并自动加载到输入框（语音输入界面）
MonitorSelectedTextForVoiceInput(*) {
    global AutoLoadSelectedText, VoiceInputActionSelectionVisible, GuiID_VoiceInput
    
    ; 如果开关未开启或界面未显示，立即停止监听
    if (!AutoLoadSelectedText || !VoiceInputActionSelectionVisible || !GuiID_VoiceInput) {
        SetTimer(MonitorSelectedTextForVoiceInput, 0)
        return
    }
    
    ; 检查是否有选中的文本
    try {
        ; 保存当前剪贴板
        OldClipboard := A_Clipboard
        
        ; 尝试复制选中文本
        A_Clipboard := ""
        Send("^c")
        Sleep(50)  ; 等待复制完成
        
        ; 检查是否复制成功
        if (ClipWait(0.1) && A_Clipboard != "" && A_Clipboard != OldClipboard) {
            ; 有选中文本，加载到输入框
            SelectedText := A_Clipboard
            if (SelectedText != "" && StrLen(SelectedText) > 0) {
                ; 尝试获取输入框控件并更新
                try {
                    ContentEdit := GuiID_VoiceInput["VoiceInputContentEdit"]
                    if (ContentEdit && (ContentEdit.Value = "" || ContentEdit.Value != SelectedText)) {
                        ContentEdit.Value := SelectedText
                    }
                } catch {
                    ; 忽略错误
                }
            }
        }
        
        ; 恢复剪贴板
        A_Clipboard := OldClipboard
    } catch {
        ; 忽略错误
    }
}

; 显示搜索引擎选择界面
ShowSearchEngineSelection(Content) {
    global GuiID_VoiceInput, VoiceInputScreenIndex, UI_Colors, VoiceSearchSelecting, VoiceSearchEngineButtons
    
    VoiceSearchSelecting := true
    
    if (GuiID_VoiceInput != 0) {
        try {
            GuiID_VoiceInput.Destroy()
        }
        GuiID_VoiceInput := 0
    }
    
    GuiID_VoiceInput := Gui("+AlwaysOnTop +ToolWindow -Caption -DPIScale")
    GuiID_VoiceInput.BackColor := UI_Colors.Background
    GuiID_VoiceInput.SetFont("s12 c" . UI_Colors.Text . " Bold", "Segoe UI")
    
    ; 获取所有搜索引擎
    global SearchEngines := GetAllSearchEngines()
    
    PanelWidth := 500
    ; 计算所需高度：标题(50) + 内容标签(25) + 内容框(60) + 引擎标签(30) + 按钮区域 + 取消按钮(45) + 边距(20)
    ButtonsRows := Ceil(SearchEngines.Length / 4)  ; 每行4个按钮
    ButtonsAreaHeight := ButtonsRows * 45  ; 每行45px（按钮35px + 间距10px）
    PanelHeight := 50 + 25 + 60 + 30 + ButtonsAreaHeight + 45 + 20
    
    ; 标题
    TitleText := GuiID_VoiceInput.Add("Text", "x0 y15 w500 h30 Center c" . UI_Colors.Text, GetText("select_search_engine_title"))
    TitleText.SetFont("s14 Bold", "Segoe UI")
    
    ; 显示搜索内容
    YPos := 55
    LabelText := GuiID_VoiceInput.Add("Text", "x20 y" . YPos . " w460 h20 cCCCCCC", "搜索内容:")
    LabelText.SetFont("s10", "Segoe UI")
    
    YPos += 25
    ContentText := GuiID_VoiceInput.Add("Text", "x20 y" . YPos . " w460 h60 Background" . UI_Colors.InputBg . " c" . UI_Colors.Text, Content)
    ContentText.SetFont("s11", "Segoe UI")
    
    ; 搜索引擎按钮
    YPos += 70
    LabelEngine := GuiID_VoiceInput.Add("Text", "x20 y" . YPos . " w460 h25 c" . UI_Colors.Text, GetText("select_search_engine"))
    LabelEngine.SetFont("s11", "Segoe UI")
    
    YPos += 30
    ButtonWidth := 110
    ButtonHeight := 35
    ButtonSpacing := 10
    ButtonsPerRow := 4
    
    VoiceSearchEngineButtons := []
    for Index, Engine in SearchEngines {
        ; 【修复】添加安全检查，防止访问无效对象属性
        if (!IsObject(Engine) || !Engine.HasProp("Value") || !Engine.HasProp("Name")) {
            continue  ; 跳过无效的引擎对象
        }
        
        Row := Floor((Index - 1) / ButtonsPerRow)
        Col := Mod(Index - 1, ButtonsPerRow)
        BtnX := 20 + Col * (ButtonWidth + ButtonSpacing)
        BtnY := YPos + Row * (ButtonHeight + ButtonSpacing)
        
        Btn := GuiID_VoiceInput.Add("Text", "x" . BtnX . " y" . BtnY . " w" . ButtonWidth . " h" . ButtonHeight . " Center 0x200 c" . UI_Colors.Text . " Background" . UI_Colors.BtnBg . " vSearchEngineBtn" . Index, Engine.Name)
        Btn.SetFont("s10", "Segoe UI")
        Btn.OnEvent("Click", CreateSearchEngineClickHandler(Content, Engine.Value))
        HoverBtn(Btn, UI_Colors.BtnBg, UI_Colors.BtnHover)
        VoiceSearchEngineButtons.Push(Btn)
    }
    
    ; 取消按钮
    CancelBtnY := YPos + (Floor((SearchEngines.Length - 1) / ButtonsPerRow) + 1) * (ButtonHeight + ButtonSpacing) + 10
    global ThemeMode
    CancelBtnTextColor := (ThemeMode = "light") ? UI_Colors.Text : "FFFFFF"
    CancelBtnBg := (ThemeMode = "light") ? UI_Colors.BtnBg : "666666"
    CancelBtn := GuiID_VoiceInput.Add("Text", "x" . (PanelWidth // 2 - 60) . " y" . CancelBtnY . " w120 h35 Center 0x200 c" . CancelBtnTextColor . " Background" . CancelBtnBg . " vCancelBtn", GetText("cancel"))
    CancelBtn.SetFont("s11", "Segoe UI")
    CancelBtn.OnEvent("Click", CancelSearchEngineSelection)
    HoverBtn(CancelBtn, "666666", "777777")
    
    ScreenInfo := GetScreenInfo(VoiceInputScreenIndex)
    Pos := GetPanelPosition(ScreenInfo, PanelWidth, PanelHeight, "center")
    GuiID_VoiceInput.Show("w" . PanelWidth . " h" . PanelHeight . " x" . Pos.X . " y" . Pos.Y . " NoActivate")
    WinSetAlwaysOnTop(1, GuiID_VoiceInput.Hwnd)
}

; 创建搜索引擎点击处理函数
CreateSearchEngineClickHandler(Content, Engine) {
    ; 使用闭包保存参数
    SearchEngineClickHandler(*) {
        global VoiceSearchSelecting
        VoiceSearchSelecting := false
        HideVoiceSearchInputPanel()
        SendVoiceSearchToBrowser(Content, Engine)
    }
    return SearchEngineClickHandler
}

; 取消搜索引擎选择
CancelSearchEngineSelection(*) {
    global VoiceSearchSelecting
    VoiceSearchSelecting := false
    HideVoiceSearchInputPanel()
}

; 显示语音搜索输入界面
ShowVoiceSearchInputPanel() {
    global GuiID_VoiceInput, VoiceInputScreenIndex, UI_Colors, VoiceSearchPanelVisible
    global VoiceSearchInputEdit, VoiceSearchSelectedEngines, VoiceSearchEngineButtons
    
    VoiceSearchPanelVisible := true
    
    if (GuiID_VoiceInput != 0) {
        try {
            GuiID_VoiceInput.Destroy()
        }
        GuiID_VoiceInput := 0
    }
    
    ; 【关键修复】移除 -Caption，添加标题栏以支持窗口拖动
    GuiID_VoiceInput := Gui("+AlwaysOnTop -DPIScale")
    GuiID_VoiceInput.BackColor := UI_Colors.Background
    GuiID_VoiceInput.SetFont("s12 c" . UI_Colors.Text . " Bold", "Segoe UI")
    GuiID_VoiceInput.Title := GetText("voice_search_title")
    
    ; 动态计算宽度，确保所有按钮可见
    InputBoxHeight := 150
    global VoiceSearchCurrentCategory, VoiceSearchEnabledCategories
    if (!IsSet(VoiceSearchCurrentCategory) || VoiceSearchCurrentCategory = "") {
        VoiceSearchCurrentCategory := "ai"
    }
    if (!IsSet(VoiceSearchEnabledCategories) || !IsObject(VoiceSearchEnabledCategories)) {
        VoiceSearchEnabledCategories := ["ai", "academic", "baidu", "image", "audio", "video", "book", "price", "medical", "cloud"]
    }
    ; 【关键修复】确保 VoiceSearchSelectedEnginesByCategory 已初始化
    global VoiceSearchSelectedEnginesByCategory
    if (!IsSet(VoiceSearchSelectedEnginesByCategory) || !IsObject(VoiceSearchSelectedEnginesByCategory)) {
        VoiceSearchSelectedEnginesByCategory := Map()
    }
    
    ; 【关键修复】根据当前分类恢复搜索引擎选择状态
    if (VoiceSearchSelectedEnginesByCategory.Has(VoiceSearchCurrentCategory)) {
        VoiceSearchSelectedEngines := []
        for Index, Engine in VoiceSearchSelectedEnginesByCategory[VoiceSearchCurrentCategory] {
            VoiceSearchSelectedEngines.Push(Engine)
        }
    } else {
        ; 如果当前分类没有保存的状态，使用默认值
        try {
            SearchEngines := GetSortedSearchEngines(VoiceSearchCurrentCategory)
            if (SearchEngines && SearchEngines.Length > 0 && IsObject(SearchEngines[1]) && SearchEngines[1].HasProp("Value")) {
                VoiceSearchSelectedEngines := [SearchEngines[1].Value]
            } else {
                VoiceSearchSelectedEngines := ["deepseek"]
            }
        } catch {
            VoiceSearchSelectedEngines := ["deepseek"]
        }
    }
    
    ; 【关键修复】确保 VoiceSearchSelectedEngines 已正确初始化
    if (!IsSet(VoiceSearchSelectedEngines) || !IsObject(VoiceSearchSelectedEngines)) {
        VoiceSearchSelectedEngines := ["deepseek"]
    }
    if (VoiceSearchSelectedEngines.Length = 0) {
        VoiceSearchSelectedEngines := ["deepseek"]
    }
    SearchEngines := GetSortedSearchEngines(VoiceSearchCurrentCategory)
    ; 【修复】确保 SearchEngines 是有效的数组
    if (!IsObject(SearchEngines) || SearchEngines.Length = 0) {
        ; 如果当前分类没有搜索引擎，使用默认分类
        VoiceSearchCurrentCategory := "ai"
        SearchEngines := GetSortedSearchEngines(VoiceSearchCurrentCategory)
        if (!IsObject(SearchEngines) || SearchEngines.Length = 0) {
            ; 如果仍然为空，创建一个默认引擎
            SearchEngines := [{Name: GetText("search_engine_deepseek"), Value: "deepseek", Category: "ai"}]
        }
    }
    TotalEngines := SearchEngines.Length
    ButtonWidth := 130
    ButtonHeight := 35
    ButtonSpacing := 10
    ButtonsPerRow := 4
    ButtonsRows := Ceil(TotalEngines / ButtonsPerRow)
    ButtonsAreaHeight := ButtonsRows * (ButtonHeight + ButtonSpacing)
    
    InputBoxWidth := 520
    RightButtonsWidth := 40 + 20
    ButtonsAreaWidth := ButtonsPerRow * ButtonWidth + (ButtonsPerRow - 1) * ButtonSpacing
    MinWidth := InputBoxWidth + RightButtonsWidth + 40
    PanelWidth := Max(MinWidth, ButtonsAreaWidth + 40)
    
    ; 计算分类标签区域宽度
    TabWidth := 50
    TabSpacing := 5
    TabsPerRow := 10
    TabAreaWidth := TabsPerRow * TabWidth + (TabsPerRow - 1) * TabSpacing
    MinTabAreaWidth := TabAreaWidth + 150
    PanelWidth := Max(PanelWidth, MinTabAreaWidth)
    
    CategoryTabHeight := 28 + 15
    AllCategories := [
        {Key: "ai", Text: GetText("search_category_ai")},
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
    
    if (!IsSet(VoiceSearchEnabledCategories) || !IsObject(VoiceSearchEnabledCategories)) {
        VoiceSearchEnabledCategories := ["ai", "academic", "baidu", "image", "audio", "video", "book", "price", "medical", "cloud"]
    }
    
    Categories := []
    for Index, Category in AllCategories {
        ; 【关键修复】添加安全检查，防止访问无效对象属性导致 "Item has no value" 错误
        if (!IsObject(Category) || !Category.HasProp("Key")) {
            continue  ; 跳过无效的分类对象
        }
        if (ArrayContainsValue(VoiceSearchEnabledCategories, Category.Key) > 0) {
            Categories.Push(Category)
        }
    }
    
    if (Categories.Length = 0) {
        Categories.Push({Key: "ai", Text: GetText("search_category_ai")})
        VoiceSearchCurrentCategory := "ai"
    }
    
    if (ArrayContainsValue(VoiceSearchEnabledCategories, VoiceSearchCurrentCategory) = 0) {
        if (Categories.Length > 0) {
            ; 【关键修复】添加安全检查，防止访问无效对象属性
            if (IsObject(Categories[1]) && Categories[1].HasProp("Key")) {
                VoiceSearchCurrentCategory := Categories[1].Key
            } else {
                VoiceSearchCurrentCategory := "ai"
            }
        } else {
            VoiceSearchCurrentCategory := "ai"
        }
    }
    
    TabRows := Ceil(Categories.Length / TabsPerRow)
    CategoryTabHeight := TabRows * (28 + TabSpacing) + 15
    
    PanelHeight := 30 + 15 + 25 + InputBoxHeight + 35 + 35 + CategoryTabHeight + 30 + ButtonsAreaHeight + 20
    
    ; 关闭按钮
    CloseBtnX := PanelWidth - 40
    CloseBtnY := 5
    CloseBtn := GuiID_VoiceInput.Add("Text", "x" . CloseBtnX . " y" . CloseBtnY . " w30 h30 Center 0x200 c" . UI_Colors.Text . " Background" . UI_Colors.BtnBg . " vCloseBtn", "×")
    CloseBtn.SetFont("s18 Bold", "Segoe UI")
    CloseBtn.OnEvent("Click", HideVoiceSearchInputPanel)
    HoverBtn(CloseBtn, UI_Colors.BtnBg, "FF4444")
    
    ; 输入框标签
    YPos := 50
    LabelText := GuiID_VoiceInput.Add("Text", "x20 y" . YPos . " w" . (PanelWidth - 80) . " h20 c" . UI_Colors.TextDim, GetText("voice_search_input_label"))
    LabelText.SetFont("s10", "Segoe UI")
    
    ; 输入框
    YPos += 25
    InputBoxActualWidth := PanelWidth - 80
    VoiceSearchInputEdit := GuiID_VoiceInput.Add("Edit", "x20 y" . YPos . " w" . InputBoxActualWidth . " h150 vVoiceSearchInputEdit Background" . UI_Colors.InputBg . " c" . UI_Colors.Text . " Multi", "")
    VoiceSearchInputEdit.SetFont("s12", "Segoe UI")
    VoiceSearchInputEdit.OnEvent("Focus", SwitchToChineseIME)
    VoiceSearchInputEdit.OnEvent("Change", UpdateVoiceSearchInputEditTime)
    
    ; 清空按钮和搜索按钮
    global ThemeMode
    if (!IsSet(ThemeMode) || ThemeMode = "") {
        ThemeMode := "dark"
    }
    ClearBtnTextColor := (ThemeMode = "light") ? UI_Colors.Text : "FFFFFF"
    RightBtnX := PanelWidth - 60
    ClearBtn := GuiID_VoiceInput.Add("Text", "x" . RightBtnX . " y" . YPos . " w40 h40 Center 0x200 c" . ClearBtnTextColor . " Background" . UI_Colors.BtnBg . " vClearBtn", GetText("clear"))
    ClearBtn.SetFont("s10", "Segoe UI")
    ClearBtn.OnEvent("Click", ClearVoiceSearchInput)
    HoverBtn(ClearBtn, UI_Colors.BtnBg, UI_Colors.BtnHover)
    
    SearchBtnTextColor := (ThemeMode = "light") ? UI_Colors.Text : "FFFFFF"
    SearchBtn := GuiID_VoiceInput.Add("Text", "x" . RightBtnX . " y" . (YPos + 110) . " w40 h40 Center 0x200 c" . SearchBtnTextColor . " Background" . UI_Colors.BtnPrimary . " vSearchBtn", GetText("voice_search_button"))
    SearchBtn.SetFont("s11 Bold", "Segoe UI")
    SearchBtn.OnEvent("Click", ExecuteVoiceSearch)
    HoverBtn(SearchBtn, UI_Colors.BtnPrimary, UI_Colors.BtnPrimaryHover)
    
    ; 自动加载选中文本开关
    YPos += 160
    global AutoLoadSelectedText, VoiceSearchAutoLoadSwitch
    AutoLoadLabel := GuiID_VoiceInput.Add("Text", "x20 y" . YPos . " w200 h25 c" . UI_Colors.TextDim, GetText("auto_load_selected_text"))
    AutoLoadLabel.SetFont("s10", "Segoe UI")
    SwitchText := AutoLoadSelectedText ? GetText("switch_on") : GetText("switch_off")
    SwitchBg := AutoLoadSelectedText ? UI_Colors.BtnHover : UI_Colors.BtnBg
    SwitchTextColor := (ThemeMode = "light") ? UI_Colors.Text : "FFFFFF"
    VoiceSearchAutoLoadSwitch := GuiID_VoiceInput.Add("Text", "x220 y" . YPos . " w120 h25 Center 0x200 c" . SwitchTextColor . " Background" . SwitchBg . " vAutoLoadSwitch", SwitchText)
    VoiceSearchAutoLoadSwitch.SetFont("s10", "Segoe UI")
    VoiceSearchAutoLoadSwitch.OnEvent("Click", ToggleAutoLoadSelectedText)
    HoverBtn(VoiceSearchAutoLoadSwitch, SwitchBg, UI_Colors.BtnHover)
    
    ; 自动更新语音输入开关
    YPos += 35
    global AutoUpdateVoiceInput, VoiceSearchAutoUpdateSwitch
    AutoUpdateLabel := GuiID_VoiceInput.Add("Text", "x20 y" . YPos . " w200 h25 c" . UI_Colors.TextDim, GetText("auto_update_voice_input"))
    AutoUpdateLabel.SetFont("s10", "Segoe UI")
    UpdateSwitchText := AutoUpdateVoiceInput ? GetText("switch_on") : GetText("switch_off")
    UpdateSwitchBg := AutoUpdateVoiceInput ? UI_Colors.BtnHover : UI_Colors.BtnBg
    UpdateSwitchTextColor := (ThemeMode = "light") ? UI_Colors.Text : "FFFFFF"
    VoiceSearchAutoUpdateSwitch := GuiID_VoiceInput.Add("Text", "x220 y" . YPos . " w120 h25 Center 0x200 c" . UpdateSwitchTextColor . " Background" . UpdateSwitchBg . " vAutoUpdateSwitch", UpdateSwitchText)
    VoiceSearchAutoUpdateSwitch.SetFont("s10", "Segoe UI")
    VoiceSearchAutoUpdateSwitch.OnEvent("Click", ToggleAutoUpdateVoiceInput)
    HoverBtn(VoiceSearchAutoUpdateSwitch, UpdateSwitchBg, UI_Colors.BtnHover)
    
    ; 分类标签栏
    YPos += 35
    LabelCategoryWidth := PanelWidth - 280
    LabelCategory := GuiID_VoiceInput.Add("Text", "x20 y" . YPos . " w" . LabelCategoryWidth . " h20 c" . UI_Colors.TextDim, GetText("select_search_engine"))
    LabelCategory.SetFont("s10", "Segoe UI")
    
    ClearSelectionBtnTextColor := (ThemeMode = "light") ? UI_Colors.Text : "FFFFFF"
    ClearSelectionBtnX := PanelWidth - 150
    ClearSelectionBtn := GuiID_VoiceInput.Add("Text", "x" . ClearSelectionBtnX . " y" . YPos . " w130 h25 Center 0x200 c" . ClearSelectionBtnTextColor . " Background" . UI_Colors.BtnBg . " vClearSelectionBtn", GetText("clear_selection"))
    ClearSelectionBtn.SetFont("s10", "Segoe UI")
    ClearSelectionBtn.OnEvent("Click", ClearAllSearchEngineSelection)
    HoverBtn(ClearSelectionBtn, UI_Colors.BtnBg, UI_Colors.BtnHover)
    
    ; 创建分类标签按钮
    YPos += 30
    global VoiceSearchCategoryTabs
    
    VoiceSearchCategoryTabs := []
    TabWidth := 50
    TabHeight := 28
    TabSpacing := 5
    TabStartX := 20
    TabY := YPos
    TabsPerRow := 10
    
    ; 第一行标签
    for Index, Category in Categories {
        ; 【关键修复】添加安全检查，防止访问无效对象属性导致 "Item has no value" 错误
        if (!IsObject(Category) || !Category.HasProp("Key") || !Category.HasProp("Text")) {
            continue  ; 跳过无效的分类对象
        }
        if (Index > TabsPerRow) {
            break
        }
        TabX := TabStartX + (Index - 1) * (TabWidth + TabSpacing)
        IsActive := (VoiceSearchCurrentCategory = Category.Key)
        TabBg := IsActive ? UI_Colors.BtnPrimary : UI_Colors.BtnBg
        TabTextColor := IsActive ? "FFFFFF" : ((ThemeMode = "light") ? UI_Colors.Text : "FFFFFF")
        
        TabBtn := GuiID_VoiceInput.Add("Text", "x" . TabX . " y" . TabY . " w" . TabWidth . " h" . TabHeight . " Center 0x200 c" . TabTextColor . " Background" . TabBg . " vCategoryTab" . Category.Key, Category.Text)
        TabBtn.SetFont("s9", "Segoe UI")
        TabHandler := CreateCategoryTabHandler(Category.Key)
        TabBtn.OnEvent("Click", TabHandler)
        HoverBtn(TabBtn, TabBg, UI_Colors.BtnHover)
        VoiceSearchCategoryTabs.Push({Btn: TabBtn, Key: Category.Key, Handler: TabHandler})
    }
    
    ; 如果标签超过10个，创建第二行
    if (Categories.Length > TabsPerRow) {
        TabY += TabHeight + TabSpacing
        for Index, Category in Categories {
            ; 【关键修复】添加安全检查，防止访问无效对象属性导致 "Item has no value" 错误
            if (!IsObject(Category) || !Category.HasProp("Key") || !Category.HasProp("Text")) {
                continue  ; 跳过无效的分类对象
            }
            if (Index <= TabsPerRow) {
                continue
            }
            TabIndex := Index - TabsPerRow
            TabX := TabStartX + (TabIndex - 1) * (TabWidth + TabSpacing)
            IsActive := (VoiceSearchCurrentCategory = Category.Key)
            TabBg := IsActive ? UI_Colors.BtnPrimary : UI_Colors.BtnBg
            TabTextColor := IsActive ? "FFFFFF" : ((ThemeMode = "light") ? UI_Colors.Text : "FFFFFF")
            
            TabBtn := GuiID_VoiceInput.Add("Text", "x" . TabX . " y" . TabY . " w" . TabWidth . " h" . TabHeight . " Center 0x200 c" . TabTextColor . " Background" . TabBg . " vCategoryTab" . Category.Key, Category.Text)
            TabBtn.SetFont("s9", "Segoe UI")
            TabHandler := CreateCategoryTabHandler(Category.Key)
            TabBtn.OnEvent("Click", TabHandler)
            HoverBtn(TabBtn, TabBg, UI_Colors.BtnHover)
            VoiceSearchCategoryTabs.Push({Btn: TabBtn, Key: Category.Key, Handler: TabHandler})
        }
    }
    
    ; 搜索引擎标签
    YPos := TabY + TabHeight + 15
    LabelEngineWidth := PanelWidth - 40
    LabelEngine := GuiID_VoiceInput.Add("Text", "x20 y" . YPos . " w" . LabelEngineWidth . " h20 c" . UI_Colors.TextDim . " vLabelEngine", GetText("select_search_engine"))
    LabelEngine.SetFont("s10", "Segoe UI")
    
    global VoiceSearchLabelEngineY := YPos
    
    ; 搜索引擎按钮
    YPos += 30
    VoiceSearchEngineButtons := []
    ButtonWidth := 130
    ButtonHeight := 35
    ButtonSpacing := 10
    StartX := 20
    ButtonsPerRow := 4
    IconSizeInButton := 20
    
    AvailableWidth := PanelWidth - 40
    MaxButtonsPerRow := Floor((AvailableWidth + ButtonSpacing) / (ButtonWidth + ButtonSpacing))
    if (MaxButtonsPerRow < 1) {
        MaxButtonsPerRow := 1
    }
    ButtonsPerRow := Min(ButtonsPerRow, MaxButtonsPerRow)
    ButtonsRows := Ceil(TotalEngines / ButtonsPerRow)
    ButtonsAreaHeight := ButtonsRows * (ButtonHeight + ButtonSpacing)
    
    PanelHeight := 30 + 15 + 25 + InputBoxHeight + 35 + 35 + CategoryTabHeight + 30 + ButtonsAreaHeight + 20
    
    for Index, Engine in SearchEngines {
        ; 【关键修复】添加安全检查，防止访问无效对象属性导致 "Item has no value" 错误
        if (!IsObject(Engine) || !Engine.HasProp("Value") || !Engine.HasProp("Name")) {
            continue  ; 跳过无效的引擎对象
        }
        
        Row := Floor((Index - 1) / ButtonsPerRow)
        Col := Mod((Index - 1), ButtonsPerRow)
        BtnX := StartX + Col * (ButtonWidth + ButtonSpacing)
        BtnY := YPos + Row * (ButtonHeight + ButtonSpacing)
        
        IsSelected := (ArrayContainsValue(VoiceSearchSelectedEngines, Engine.Value) > 0)
        BtnBgColor := IsSelected ? UI_Colors.BtnHover : UI_Colors.BtnBg
        BtnText := IsSelected ? "✓ " . Engine.Name : Engine.Name
        EngineBtnTextColor := (ThemeMode = "light") ? UI_Colors.Text : "FFFFFF"
        
        IconPath := GetSearchEngineIcon(Engine.Value)
        IconCtrl := 0
        
        Btn := GuiID_VoiceInput.Add("Text", "x" . BtnX . " y" . BtnY . " w" . ButtonWidth . " h" . ButtonHeight . " Center 0x200 c" . EngineBtnTextColor . " Background" . BtnBgColor, "")
        Btn.SetFont("s10", "Segoe UI")
        Btn.OnEvent("Click", CreateToggleSearchEngineHandler(Engine.Value, Index))
        HoverBtn(Btn, BtnBgColor, UI_Colors.BtnHover)
        
        if (IconPath != "" && FileExist(IconPath)) {
            try {
                IconX := BtnX + 8
                IconY := BtnY + (ButtonHeight - IconSizeInButton) // 2
                
                ImageSize := GetImageSize(IconPath)
                DisplaySize := CalculateImageDisplaySize(ImageSize.Width, ImageSize.Height, IconSizeInButton, IconSizeInButton)
                
                DisplayX := IconX
                DisplayY := IconY + (IconSizeInButton - DisplaySize.Height) // 2
                
                IconCtrl := GuiID_VoiceInput.Add("Picture", "x" . DisplayX . " y" . DisplayY . " w" . DisplaySize.Width . " h" . DisplaySize.Height . " 0x200", IconPath)
                IconCtrl.OnEvent("Click", CreateToggleSearchEngineHandler(Engine.Value, Index))
                
                TextX := IconX + IconSizeInButton + 5
                TextWidth := ButtonWidth - (TextX - BtnX) - 8
            } catch {
                IconCtrl := 0
                TextX := BtnX + 8
                TextWidth := ButtonWidth - 16
            }
        } else {
            TextX := BtnX + 8
            TextWidth := ButtonWidth - 16
        }
        
        TextCtrl := GuiID_VoiceInput.Add("Text", "x" . TextX . " y" . BtnY . " w" . TextWidth . " h" . ButtonHeight . " Left 0x200 c" . EngineBtnTextColor . " BackgroundTrans", BtnText)
        TextCtrl.SetFont("s10", "Segoe UI")
        TextCtrl.OnEvent("Click", CreateToggleSearchEngineHandler(Engine.Value, Index))
        
        VoiceSearchEngineButtons.Push({Bg: Btn, Icon: IconCtrl, Text: TextCtrl, Index: Index})
    }
    
    ScreenInfo := GetScreenInfo(VoiceInputScreenIndex)
    Pos := GetPanelPosition(ScreenInfo, PanelWidth, PanelHeight, "center")
    GuiID_VoiceInput.Show("w" . PanelWidth . " h" . PanelHeight . " x" . Pos.X . " y" . Pos.Y)
    WinSetAlwaysOnTop(1, GuiID_VoiceInput.Hwnd)
    
    VoiceSearchInputEdit.Value := ""
    global VoiceSearchInputLastEditTime := 0
    
    SetTimer(MonitorSelectedText, 0)
    
    WinActivate("ahk_id " . GuiID_VoiceInput.Hwnd)
    Sleep(200)
    
    if (!WinActive("ahk_id " . GuiID_VoiceInput.Hwnd)) {
        WinActivate("ahk_id " . GuiID_VoiceInput.Hwnd)
        Sleep(200)
    }
    
    InputEditHwnd := VoiceSearchInputEdit.Hwnd
    
    try {
        ControlFocus(InputEditHwnd, "ahk_id " . GuiID_VoiceInput.Hwnd)
        Sleep(100)
    } catch {
        VoiceSearchInputEdit.Focus()
        Sleep(100)
    }
    
    try {
        ControlFocus(InputEditHwnd, "ahk_id " . GuiID_VoiceInput.Hwnd)
        Sleep(50)
    } catch {
        VoiceSearchInputEdit.Focus()
        Sleep(50)
    }
    
    if (AutoLoadSelectedText) {
        SetTimer(MonitorSelectedText, 200)
    } else {
        SetTimer(MonitorSelectedText, 0)
    }
    
    ; 自动激活语音输入
    try {
        Sleep(300)  ; 等待窗口完全显示和焦点设置完成
        StartVoiceInputInSearch()
    } catch as e {
        ; 如果启动语音输入失败，不影响面板显示
        TrayTip(GetText("voice_search_failed") . ": " . e.Message, GetText("error"), "Iconx 2")
    }
}

; ===================== 语音搜索辅助函数 =====================
; 隐藏语音搜索输入界面
HideVoiceSearchInputPanel(*) {
    global GuiID_VoiceInput, VoiceSearchPanelVisible, VoiceSearchInputEdit
    
    ; 自动关闭 CapsLock 大写状态
    SetCapsLockState("Off")
    
    ; 停止监听选中文本
    SetTimer(MonitorSelectedText, 0)
    
    VoiceSearchPanelVisible := false
    
    if (GuiID_VoiceInput != 0) {
        try {
            GuiID_VoiceInput.Destroy()
        }
        GuiID_VoiceInput := 0
    }
    VoiceSearchInputEdit := 0
}

; 清空语音搜索输入框
ClearVoiceSearchInput(*) {
    global VoiceSearchInputEdit, VoiceSearchPanelVisible
    
    if (!VoiceSearchPanelVisible || !VoiceSearchInputEdit) {
        return
    }
    
    try {
        VoiceSearchInputEdit.Value := ""
        ; 重新聚焦到输入框
        VoiceSearchInputEdit.Focus()
    } catch as e {
        ; 忽略错误
    }
}

; 切换自动加载选中文本开关
ToggleAutoLoadSelectedText(*) {
    global AutoLoadSelectedText, VoiceSearchAutoLoadSwitch, VoiceSearchPanelVisible, UI_Colors, ConfigFile
    
    if (!VoiceSearchPanelVisible || !VoiceSearchAutoLoadSwitch) {
        return
    }
    
    ; 切换状态
    AutoLoadSelectedText := !AutoLoadSelectedText
    
    ; 更新开关显示
    SwitchText := AutoLoadSelectedText ? "✓ 已开启" : "○ 已关闭"
    SwitchBg := AutoLoadSelectedText ? UI_Colors.BtnHover : UI_Colors.BtnBg
    VoiceSearchAutoLoadSwitch.Text := SwitchText
    VoiceSearchAutoLoadSwitch.BackColor := SwitchBg
    
    ; 保存到配置文件
    try {
        IniWrite(AutoLoadSelectedText ? "1" : "0", ConfigFile, "Settings", "AutoLoadSelectedText")
    } catch {
        ; 忽略保存错误
    }
    
    ; 如果开启，启动监听；如果关闭，立即停止监听
    if (AutoLoadSelectedText) {
        SetTimer(MonitorSelectedText, 200)  ; 每200ms检查一次
        ; 如果正在语音输入，也启动更新输入框的定时器
        global VoiceSearchActive
        if (VoiceSearchActive) {
            SetTimer(UpdateVoiceSearchInputInPanel, 300)  ; 每300ms更新一次
        }
    } else {
        ; 立即停止监听，确保不会继续自动加载
        SetTimer(MonitorSelectedText, 0)
    }
}

; 切换自动更新语音输入开关
ToggleAutoUpdateVoiceInput(*) {
    global AutoUpdateVoiceInput, VoiceSearchAutoUpdateSwitch, VoiceSearchPanelVisible, UI_Colors, ConfigFile, VoiceSearchActive
    
    if (!VoiceSearchPanelVisible || !VoiceSearchAutoUpdateSwitch) {
        return
    }
    
    ; 切换状态
    AutoUpdateVoiceInput := !AutoUpdateVoiceInput
    
    ; 更新开关显示
    SwitchText := AutoUpdateVoiceInput ? "✓ 已开启" : "○ 已关闭"
    SwitchBg := AutoUpdateVoiceInput ? UI_Colors.BtnHover : UI_Colors.BtnBg
    VoiceSearchAutoUpdateSwitch.Text := SwitchText
    VoiceSearchAutoUpdateSwitch.BackColor := SwitchBg
    
    ; 保存到配置文件
    try {
        IniWrite(AutoUpdateVoiceInput ? "1" : "0", ConfigFile, "Settings", "AutoUpdateVoiceInput")
    } catch {
        ; 忽略保存错误
    }
    
    ; 根据"自动更新语音输入"或"自动加载选中文本"开关状态立即启动或停止定时器
    SetTimer(UpdateVoiceSearchInputInPanel, 0)
    global AutoLoadSelectedText
    if ((AutoUpdateVoiceInput || AutoLoadSelectedText) && VoiceSearchActive) {
        ; 如果"自动更新语音输入"或"自动加载选中文本"任一开启，且正在语音输入，启动定时器
        SetTimer(UpdateVoiceSearchInputInPanel, 300)  ; 每300ms更新一次
    } else {
        ; 否则停止定时器
        SetTimer(UpdateVoiceSearchInputInPanel, 0)
    }
}

; 更新输入框最后编辑时间（用于检测用户是否正在输入）
UpdateVoiceSearchInputEditTime(*) {
    global VoiceSearchInputLastEditTime
    VoiceSearchInputLastEditTime := A_TickCount
}

; 监听选中文本并自动加载到输入框
MonitorSelectedText(*) {
    global AutoLoadSelectedText, VoiceSearchPanelVisible, GuiID_VoiceInput, VoiceSearchInputEdit
    global VoiceSearchInputLastEditTime
    
    ; 如果开关未开启或面板未显示，立即停止监听
    if (!AutoLoadSelectedText || !VoiceSearchPanelVisible || !GuiID_VoiceInput) {
        SetTimer(MonitorSelectedText, 0)
        return
    }
    
    ; 检测用户是否正在输入：如果输入框在最近2秒内被编辑过，说明用户正在输入，不自动加载
    CurrentTime := A_TickCount
    if (VoiceSearchInputLastEditTime > 0 && (CurrentTime - VoiceSearchInputLastEditTime) < 2000) {
        ; 用户正在输入（最近2秒内编辑过），不自动加载
        return
    }
    
    ; 检查输入框是否有内容，如果有内容且不是最近编辑的，也不自动加载（避免覆盖用户已输入的内容）
    try {
        if (VoiceSearchInputEdit && VoiceSearchInputEdit.Value != "") {
            ; 输入框有内容，且不是最近编辑的，不自动加载（避免覆盖用户输入）
            return
        }
    } catch {
        ; 忽略错误
    }
    
    ; 检查是否有选中的文本
    try {
        ; 保存当前剪贴板
        OldClipboard := A_Clipboard
        
        ; 尝试复制选中文本
        A_Clipboard := ""
        Send("^c")
        Sleep(50)  ; 等待复制完成
        
        ; 检查是否复制成功
        if (ClipWait(0.1) && A_Clipboard != "" && A_Clipboard != OldClipboard) {
            ; 有选中文本，加载到输入框
            SelectedText := A_Clipboard
            if (SelectedText != "" && StrLen(SelectedText) > 0) {
                ; 尝试获取输入框控件并更新
                try {
                    if (VoiceSearchInputEdit && (VoiceSearchInputEdit.Value = "" || VoiceSearchInputEdit.Value != SelectedText)) {
                        VoiceSearchInputEdit.Value := SelectedText
                    }
                } catch {
                    ; 忽略错误
                }
            }
        }
        
        ; 恢复剪贴板
        A_Clipboard := OldClipboard
    } catch {
        ; 忽略错误
    }
}

; 更新语音搜索输入框内容（定时器调用）
UpdateVoiceSearchInputInPanel(*) {
    global VoiceSearchActive, VoiceSearchInputEdit, VoiceSearchPanelVisible, AutoLoadSelectedText, AutoUpdateVoiceInput, GuiID_VoiceInput, VoiceInputMethod
    
    ; 如果"自动更新语音输入"和"自动加载选中文本"都未开启，停止定时器
    if (!AutoUpdateVoiceInput && !AutoLoadSelectedText) {
        SetTimer(UpdateVoiceSearchInputInPanel, 0)
        return
    }
    
    if (!VoiceSearchActive || !VoiceSearchPanelVisible || !VoiceSearchInputEdit) {
        SetTimer(UpdateVoiceSearchInputInPanel, 0)
        return
    }
    
    try {
        ; 检测百度输入法语音识别窗口是否存在
        BaiduVoiceWindowActive := false
        if (VoiceInputMethod = "baidu") {
            BaiduVoiceWindowActive := IsBaiduVoiceWindowActive()
        }
        
        ; 获取输入框的控件句柄
        InputEditHwnd := VoiceSearchInputEdit.Hwnd
        
        ; 如果百度输入法的语音识别窗口存在，使用ControlFocus确保输入框有输入焦点
        if (BaiduVoiceWindowActive) {
            if (GuiID_VoiceInput) {
                if (WinExist("ahk_id " . GuiID_VoiceInput.Hwnd)) {
                    try {
                        ControlFocus(InputEditHwnd, "ahk_id " . GuiID_VoiceInput.Hwnd)
                        Sleep(20)
                    } catch {
                        try {
                            VoiceSearchInputEdit.Focus()
                            Sleep(20)
                        } catch {
                        }
                    }
                }
            }
        } else {
            ; 输入法窗口不存在时，正常激活主窗口并设置焦点
            if (GuiID_VoiceInput) {
                if (!WinActive("ahk_id " . GuiID_VoiceInput.Hwnd)) {
                    WinActivate("ahk_id " . GuiID_VoiceInput.Hwnd)
                    Sleep(100)
                }
                
                try {
                    ControlFocus(InputEditHwnd, "ahk_id " . GuiID_VoiceInput.Hwnd)
                    Sleep(50)
                } catch {
                    VoiceSearchInputEdit.Focus()
                    Sleep(50)
                }
            }
        }
        
        ; 尝试直接读取输入框内容
        OldClipboard := A_Clipboard
        CurrentContent := ""
        CurrentInputValue := ""
        
        try {
            CurrentInputValue := VoiceSearchInputEdit.Value
            CurrentContent := CurrentInputValue
        } catch {
            ; 如果直接读取失败，使用剪贴板方式
            if (!BaiduVoiceWindowActive && GuiID_VoiceInput) {
                if (!WinActive("ahk_id " . GuiID_VoiceInput.Hwnd)) {
                    WinActivate("ahk_id " . GuiID_VoiceInput.Hwnd)
                    Sleep(50)
                }
                try {
                    ControlFocus(InputEditHwnd, "ahk_id " . GuiID_VoiceInput.Hwnd)
                    Sleep(30)
                } catch {
                    VoiceSearchInputEdit.Focus()
                    Sleep(30)
                }
                
                Send("^a")
                Sleep(30)
                A_Clipboard := ""
                Send("^c")
                Sleep(80)
                
                if (ClipWait(0.15)) {
                    CurrentContent := A_Clipboard
                }
            }
        }
        
        ; 处理读取到的内容
        if (CurrentContent != "" && StrLen(CurrentContent) > 0) {
            ; 检查内容是否看起来像语音输入的内容
            if (CurrentInputValue = "" && (InStr(CurrentContent, "\") || InStr(CurrentContent, ".lnk") || InStr(CurrentContent, "快捷方式"))) {
                ; 忽略看起来像文件路径或快捷方式的内容
                A_Clipboard := OldClipboard
                return
            }
            
            ; 如果内容有变化且新内容更长，更新输入框
            if (CurrentContent != CurrentInputValue && StrLen(CurrentContent) >= StrLen(CurrentInputValue)) {
                try {
                    ; 在输入法窗口存在时，不更新输入框内容（避免干扰输入法）
                    if (!BaiduVoiceWindowActive) {
                        VoiceSearchInputEdit.Value := CurrentContent
                        ; 将光标移到末尾
                        try {
                            ControlFocus(InputEditHwnd, "ahk_id " . GuiID_VoiceInput.Hwnd)
                            Sleep(20)
                            Send("^{End}")
                        } catch {
                        }
                    }
                } catch {
                }
            }
        }
        
        ; 恢复剪贴板
        A_Clipboard := OldClipboard
    } catch {
        ; 忽略错误
    }
}

; 创建切换搜索引擎选择处理函数
CreateToggleSearchEngineHandler(Engine, BtnIndex) {
    ToggleSearchEngineHandler(*) {
        global VoiceSearchSelectedEngines, VoiceSearchEngineButtons, UI_Colors
        global VoiceSearchCurrentCategory, VoiceSearchSelectedEnginesByCategory, ConfigFile
        
        ; 确保 VoiceSearchSelectedEnginesByCategory 已初始化
        if (!IsSet(VoiceSearchSelectedEnginesByCategory) || !IsObject(VoiceSearchSelectedEnginesByCategory)) {
            VoiceSearchSelectedEnginesByCategory := Map()
        }
        
        ; 切换选择状态
        FoundIndex := ArrayContainsValue(VoiceSearchSelectedEngines, Engine)
        if (FoundIndex > 0) {
            ; 取消选择
            VoiceSearchSelectedEngines.RemoveAt(FoundIndex)
        } else {
            ; 添加选择
            VoiceSearchSelectedEngines.Push(Engine)
        }
        
        ; 【关键修复】保存当前分类的选择状态到分类Map中
        if (VoiceSearchCurrentCategory != "") {
            CurrentEngines := []
            for Index, Eng in VoiceSearchSelectedEngines {
                CurrentEngines.Push(Eng)
            }
            VoiceSearchSelectedEnginesByCategory[VoiceSearchCurrentCategory] := CurrentEngines
        }
        
        ; 保存到配置文件（保存当前分类的选择状态）
        try {
            EnginesStr := ""
            for Index, Eng in VoiceSearchSelectedEngines {
                if (Index > 1) {
                    EnginesStr .= ","
                }
                EnginesStr .= Eng
            }
            if (EnginesStr = "") {
                EnginesStr := "deepseek"
            }
            ; 保存格式：分类:引擎1,引擎2
            CategoryEnginesStr := VoiceSearchCurrentCategory . ":" . EnginesStr
            IniWrite(CategoryEnginesStr, ConfigFile, "Settings", "VoiceSearchSelectedEngines_" . VoiceSearchCurrentCategory)
        } catch as e {
            TrayTip("保存搜索引擎选择失败: " . e.Message, "错误", "Iconx 1")
        }
        
        ; 更新按钮样式
        if (IsSet(VoiceSearchEngineButtons) && VoiceSearchEngineButtons.Length > 0 && BtnIndex <= VoiceSearchEngineButtons.Length) {
            BtnObj := VoiceSearchEngineButtons[BtnIndex]
            if (BtnObj && IsObject(BtnObj)) {
                IsSelected := (ArrayContainsValue(VoiceSearchSelectedEngines, Engine) > 0)
                
                ; 更新背景颜色
                if (BtnObj.Bg) {
                    BtnObj.Bg.BackColor := IsSelected ? UI_Colors.BtnHover : UI_Colors.BtnBg
                }
                
                ; 更新文字（添加/移除 ✓ 标记）
                if (BtnObj.Text) {
                    AllEngines := GetAllSearchEngines()
                    EngineName := ""
                    for Index, Eng in AllEngines {
                        if (Eng.Value = Engine) {
                            EngineName := Eng.Name
                            break
                        }
                    }
                    if (EngineName != "") {
                        BtnObj.Text.Text := IsSelected ? "✓ " . EngineName : EngineName
                    }
                }
            }
        }
        
        ; 立即刷新GUI
        try {
            global GuiID_VoiceInput
            if (GuiID_VoiceInput && IsObject(GuiID_VoiceInput) && GuiID_VoiceInput.HasProp("Hwnd")) {
                WinRedraw(GuiID_VoiceInput.Hwnd)
            }
        } catch {
        }
    }
    return ToggleSearchEngineHandler
}

; 清空所有搜索引擎选择
ClearAllSearchEngineSelection(*) {
    global VoiceSearchSelectedEngines, VoiceSearchEngineButtons, UI_Colors, GuiID_VoiceInput
    global ConfigFile, VoiceSearchCurrentCategory
    
    ; 清空选择数组
    VoiceSearchSelectedEngines := []
    
    ; 保存到配置文件
    try {
        IniWrite("deepseek", ConfigFile, "Settings", "VoiceSearchSelectedEngines")
    } catch as e {
    }
    
    ; 更新所有按钮的样式
    if (IsSet(VoiceSearchEngineButtons) && VoiceSearchEngineButtons.Length > 0) {
        try {
            CurrentEngines := GetSortedSearchEngines(VoiceSearchCurrentCategory)
        } catch {
            CurrentEngines := []
        }
        
        for Index, BtnObj in VoiceSearchEngineButtons {
            if (BtnObj && IsObject(BtnObj)) {
                try {
                    if (BtnObj.Bg && IsObject(BtnObj.Bg)) {
                        BtnObj.Bg.BackColor := UI_Colors.BtnBg
                    }
                } catch {
                }
                
                try {
                    if (BtnObj.Text && IsObject(BtnObj.Text) && BtnObj.Index > 0 && BtnObj.Index <= CurrentEngines.Length) {
                        EngineName := CurrentEngines[BtnObj.Index].Name
                        if (EngineName != "") {
                            CurrentText := BtnObj.Text.Text
                            if (SubStr(CurrentText, 1, 2) = "✓ ") {
                                BtnObj.Text.Text := EngineName
                            } else {
                                BtnObj.Text.Text := EngineName
                            }
                        }
                    }
                } catch {
                }
            }
        }
    }
    
    ; 立即刷新GUI
    try {
        if (GuiID_VoiceInput && IsObject(GuiID_VoiceInput) && GuiID_VoiceInput.HasProp("Hwnd")) {
            WinRedraw(GuiID_VoiceInput.Hwnd)
        }
    } catch {
    }
    
    ; 显示提示
    TrayTip(GetText("cleared"), GetText("tip"), "Iconi 1")
}

; 发送语音搜索内容到浏览器
SendVoiceSearchToBrowser(Content, Engine) {
    try {
        ; URL编码搜索内容
        EncodedContent := UriEncode(Content)
        
        ; 根据搜索引擎构建URL
        SearchURL := ""
        switch Engine {
            case "deepseek":
                SearchURL := "https://chat.deepseek.com/?q=" . EncodedContent
            case "yuanbao":
                SearchURL := "https://yuanbao.tencent.com/?q=" . EncodedContent
            case "doubao":
                SearchURL := "https://www.doubao.com/chat/?q=" . EncodedContent
            case "zhipu":
                SearchURL := "https://chatglm.cn/main/search?query=" . EncodedContent
            case "mita":
                SearchURL := "https://metaso.cn/?q=" . EncodedContent
            case "wenxin":
                SearchURL := "https://yiyan.baidu.com/search?query=" . EncodedContent
            case "qianwen":
                SearchURL := "https://tongyi.aliyun.com/qianwen/chat?intent=chat&query=" . EncodedContent
            case "kimi":
                SearchURL := "https://kimi.moonshot.cn/_prefill_chat?force_search=true&send_immediately=true&prefill_prompt=" . EncodedContent
            case "perplexity":
                SearchURL := "https://www.perplexity.ai/search?intent=qa&q=" . EncodedContent
            case "copilot":
                SearchURL := "https://copilot.microsoft.com/chat?q=" . EncodedContent
            case "chatgpt":
                SearchURL := "https://chat.openai.com/?q=" . EncodedContent
            case "grok":
                SearchURL := "https://grok.com/?q=" . EncodedContent
            case "you":
                SearchURL := "https://you.com/search?q=" . EncodedContent
            case "claude":
                SearchURL := "https://claude.ai/new?q=" . EncodedContent
            case "monica":
                SearchURL := "https://monica.so/answers/?q=" . EncodedContent
            case "webpilot":
                SearchURL := "https://webpilot.ai/search?q=" . EncodedContent
            case "zhihu":
                SearchURL := "https://www.zhihu.com/search?q=" . EncodedContent
            case "baidu":
                SearchURL := "https://www.baidu.com/s?wd=" . EncodedContent
            default:
                SearchURL := "https://chat.deepseek.com/?q=" . EncodedContent
        }
        
        ; 打开浏览器
        Run(SearchURL)
        TrayTip(GetText("voice_search_sent"), GetText("tip"), "Iconi 1")
    } catch as e {
        TrayTip(GetText("voice_search_failed") . ": " . e.Message, GetText("error"), "Iconx 2")
    }
}

; 切换到中文输入法
SwitchToChineseIME(*) {
    try {
        global GuiID_VoiceInput, VoiceSearchInputEdit
        if (GuiID_VoiceInput && VoiceSearchInputEdit) {
            WinActivate("ahk_id " . GuiID_VoiceInput.Hwnd)
            Sleep(50)
            VoiceSearchInputEdit.Focus()
            Sleep(50)
            ActiveHwnd := GuiID_VoiceInput.Hwnd
        } else {
            ActiveHwnd := WinGetID("A")
        }
        
        if (!ActiveHwnd) {
            return
        }
        
        ; 使用 Windows IME API 切换到中文输入法
        hIMC := DllCall("imm32\ImmGetContext", "Ptr", ActiveHwnd, "Ptr")
        if (hIMC) {
            DllCall("imm32\ImmGetConversionStatus", "Ptr", hIMC, "UInt*", &ConversionMode := 0, "UInt*", &SentenceMode := 0)
            ConversionMode := ConversionMode | 0x0001  ; IME_CMODE_NATIVE
            DllCall("imm32\ImmSetConversionStatus", "Ptr", hIMC, "UInt", ConversionMode, "UInt", SentenceMode)
            DllCall("imm32\ImmReleaseContext", "Ptr", ActiveHwnd, "Ptr", hIMC)
        }
        
        ; 尝试切换到中文键盘布局
        try {
            hKL := DllCall("user32\LoadKeyboardLayout", "Str", "00000804", "UInt", 0x00000001, "Ptr")
            if (hKL) {
                PostMessage(0x0050, 0x0001, hKL, , , "ahk_id " . ActiveHwnd)
            }
        } catch {
        }
    } catch {
    }
}

; 检测百度输入法语音识别窗口是否激活
IsBaiduVoiceWindowActive() {
    ; 检测百度输入法的语音识别窗口
    AllWindows := WinGetList()
    for Index, Hwnd in AllWindows {
        try {
            WinTitle := WinGetTitle("ahk_id " . Hwnd)
            ; 检查窗口标题是否包含语音识别相关关键词
            if (InStr(WinTitle, "正在识别") || InStr(WinTitle, "说完了") || InStr(WinTitle, "语音输入")) {
                ; 进一步检查窗口是否可见且处于活动状态
                if (WinExist("ahk_id " . Hwnd)) {
                    IsVisible := WinGetMinMax("ahk_id " . Hwnd)
                    if (IsVisible != -1) {  ; -1 表示最小化
                        return true
                    }
                }
            }
        } catch {
            ; 忽略错误，继续检测下一个窗口
        }
    }
    
    ; 通过窗口类名检测百度输入法相关窗口
    BaiduClasses := ["BaiduIME", "BaiduPinyin", "BaiduInput", "#32770"]
    for Index, ClassName in BaiduClasses {
        if (WinExist("ahk_class " . ClassName)) {
            try {
                WinTitle := WinGetTitle("ahk_class " . ClassName)
                if (InStr(WinTitle, "正在识别") || InStr(WinTitle, "说完了") || InStr(WinTitle, "语音输入")) {
                    return true
                }
            } catch {
            }
        }
    }
    
    return false
}

; URL编码函数（使用 UTF-8 编码，正确处理中文）
UriEncode(Uri) {
    try {
        ; 方法1：使用 JavaScript encodeURIComponent（如果可用）
        try {
            js := ComObject("MSScriptControl.ScriptControl")
            js.Language := "JScript"
            ; 转义单引号，防止 JavaScript 错误
            EscapedUri := StrReplace(Uri, "\", "\\")
            EscapedUri := StrReplace(EscapedUri, "'", "\'")
            EscapedUri := StrReplace(EscapedUri, "`n", "\n")
            EscapedUri := StrReplace(EscapedUri, "`r", "\r")
            Encoded := js.Eval("encodeURIComponent('" . EscapedUri . "')")
            return Encoded
        } catch {
            ; 方法2：手动 UTF-8 编码（更可靠的备用方案）
            Encoded := ""
            ; 将字符串转换为 UTF-8 字节数组
            UTF8Size := StrPut(Uri, "UTF-8")
            UTF8Bytes := Buffer(UTF8Size)
            StrPut(Uri, UTF8Bytes, "UTF-8")
            
            ; 遍历每个字节进行编码
            Loop UTF8Size - 1 {  ; -1 因为 StrPut 返回的大小包括 null 终止符
                Byte := NumGet(UTF8Bytes, A_Index - 1, "UChar")
                ; 保留字符：字母、数字、-、_、.、~（根据 RFC 3986）
                if ((Byte >= 48 && Byte <= 57) || (Byte >= 65 && Byte <= 90) || (Byte >= 97 && Byte <= 122) || Byte = 45 || Byte = 95 || Byte = 46 || Byte = 126) {
                    Encoded .= Chr(Byte)
                } else if (Byte = 32) {
                    ; 空格编码为 +
                    Encoded .= "+"
                } else {
                    ; URL编码：%XX（大写）
                    Encoded .= "%" . Format("{:02X}", Byte)
                }
            }
            return Encoded
        }
    } catch {
        ; 如果编码失败，返回原始字符串
        return Uri
    }
}