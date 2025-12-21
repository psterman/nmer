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
global ConfigFile := A_ScriptDir "\CursorShortcut.ini"
global TrayIconPath := A_ScriptDir "\cursor_helper.ico"
; CapsLock+ 方案的核心变量
global CapsLock := false
global GuiID_ConfigGUI := 0  ; 配置面板单例
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
; 配置变量
global CursorPath := ""
global AISleepTime := 15000
global CapsLockHoldTimeSeconds := 0.5  ; CapsLock长按时间（秒），默认0.5秒
global Prompt_Explain := ""
global Prompt_Refactor := ""
global Prompt_Optimize := ""
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
global ClipboardListBoxCtrlC := 0  ; Ctrl+C 列表容器控件引用
global ClipboardListBoxCapsLockC := 0  ; CapsLock+C 列表容器控件引用
global ClipboardListBox := 0  ; 当前激活的ListBox引用（兼容旧代码）
global LastSelectedIndexCtrlC := 0  ; Ctrl+C最后选中的ListBox项索引
global LastSelectedIndexCapsLockC := 0  ; CapsLock+C最后选中的ListBox项索引
global ClipboardClearAllBtn := 0  ; 清空全部按钮控件引用
; 语音输入功能
global VoiceInputActive := false  ; 语音输入是否激活
global GuiID_VoiceInput := 0  ; 语音输入动画GUI ID
global VoiceInputContent := ""  ; 存储语音输入的内容
global VoiceInputMethod := ""  ; 当前使用的输入法类型：baidu, xunfei, auto
global VoiceInputPaused := false  ; 语音输入是否被暂停（按住CapsLock时）
global VoiceTitleText := 0  ; 语音输入动画标题文本控件
global VoiceHintText := 0  ; 语音输入动画提示文本控件
global VoiceAnimationText := 0  ; 语音输入/搜索动画文本控件
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
global VoiceSearchEnabledCategories := ["ai", "academic", "baidu", "image", "audio", "video", "book", "price", "medical", "cloud"]  ; 启用的搜索标签列表（默认全部启用）
global AutoLoadSelectedText := false  ; 是否自动加载选中文本到输入框
global VoiceSearchAutoLoadSwitch := 0  ; 自动加载开关控件（语音搜索）
global VoiceInputAutoLoadSwitch := 0  ; 自动加载开关控件（语音输入）
global AutoUpdateVoiceInput := true  ; 是否自动更新语音输入内容到输入框
global VoiceSearchAutoUpdateSwitch := 0  ; 自动更新开关控件（语音搜索）
global VoiceInputActionSelectionVisible := false  ; 语音输入操作选择界面是否显示
; 多语言支持
global Language := "zh"  ; 语言设置：zh=中文, en=英文
; 快捷操作按钮配置（最多5个）
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
    BtnPrimary: "0e639c",
    BtnPrimaryHover: "1177bb",
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
    BtnPrimary: "0e639c",
    BtnPrimaryHover: "1177bb",
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
            "voice_input_hint", "正在录入，请说话...",
            "voice_input_stopping", "正在结束语音输入...",
            "voice_input_sent", "语音输入已发送到 Cursor",
            "voice_input_failed", "语音输入失败",
            "voice_input_no_content", "未检测到语音输入内容",
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
            "quick_action_config", "快捷操作按钮配置",
            "quick_action_config_desc", "配置快捷操作面板中的按钮顺序和功能按键（最多5个）",
            "search_category_config", "搜索标签配置",
            "search_category_config_desc", "配置语音搜索面板中显示的标签，只有勾选的标签才会显示",
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
            "quick_action_max_reached", "最多只能添加5个按钮",
            "quick_action_min_reached", "至少需要保留1个按钮"
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
            "voice_input_hint", "Recording, please speak...",
            "voice_input_stopping", "Stopping voice input...",
            "voice_input_sent", "Voice input sent to Cursor",
            "voice_input_failed", "Voice input failed",
            "voice_input_no_content", "No voice input content detected",
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
            "quick_action_config", "Quick Action Button Configuration",
            "quick_action_config_desc", "Configure button order and hotkeys in the quick action panel (max 5)",
            "search_category_config", "Search Category Configuration",
            "search_category_config_desc", "Configure which categories are displayed in the voice search panel",
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
            "quick_action_max_reached", "Maximum 5 buttons allowed",
            "quick_action_min_reached", "At least 1 button required"
        )
    )
    
    ; 获取当前语言的文本
    LangTexts := Texts[Language]
    if (!LangTexts) {
        LangTexts := Texts["zh"]  ; 默认使用中文
    }
    
    Text := LangTexts[Key]
    if (!Text) {
        Text := Key  ; 如果找不到，返回键名
    }
    
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
        IniWrite("deepseek", ConfigFile, "Settings", "SearchEngine")
        IniWrite("0", ConfigFile, "Settings", "AutoLoadSelectedText")
        IniWrite("1", ConfigFile, "Settings", "AutoUpdateVoiceInput")
        IniWrite("deepseek", ConfigFile, "Settings", "VoiceSearchSelectedEngines")  ; 保存默认选中的搜索引擎
        
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
    global CursorPath, AISleepTime, Prompt_Explain, Prompt_Refactor, Prompt_Optimize, SplitHotkey, BatchHotkey, PanelScreenIndex, Language
    global FunctionPanelPos, ConfigPanelPos, ClipboardPanelPos
    global HotkeyESC, HotkeyC, HotkeyV, HotkeyX, HotkeyE, HotkeyR, HotkeyO, HotkeyQ, HotkeyZ
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
            ChineseDefaultExplain := "解释这段代码的核心逻辑、输入输出、关键函数作用，用新手能懂的语言，标注易错点"
            ChineseDefaultRefactor := "重构这段代码，遵循PEP8/行业规范，简化冗余逻辑，添加中文注释，保持功能不变"
            ChineseDefaultOptimize := "分析这段代码的性能瓶颈（时间/空间复杂度），给出优化方案+对比说明，保留原逻辑可读性"
            
            if (Prompt_Explain = "" || Prompt_Explain = ChineseDefaultExplain) {
                Prompt_Explain := (Language = "zh") ? ChineseDefaultExplain : GetText("default_prompt_explain")
            }
            if (Prompt_Refactor = "" || Prompt_Refactor = ChineseDefaultRefactor) {
                Prompt_Refactor := (Language = "zh") ? ChineseDefaultRefactor : GetText("default_prompt_refactor")
            }
            if (Prompt_Optimize = "" || Prompt_Optimize = ChineseDefaultOptimize) {
                Prompt_Optimize := (Language = "zh") ? ChineseDefaultOptimize : GetText("default_prompt_optimize")
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
            SearchEngine := IniRead(ConfigFile, "Settings", "SearchEngine", "deepseek")
            AutoLoadSelectedText := (IniRead(ConfigFile, "Settings", "AutoLoadSelectedText", "0") = "1")
            AutoUpdateVoiceInput := (IniRead(ConfigFile, "Settings", "AutoUpdateVoiceInput", "1") = "1")
            
            ; 加载主题模式（暗色或亮色）
            global ThemeMode
            ThemeMode := IniRead(ConfigFile, "Settings", "ThemeMode", "dark")
            ApplyTheme(ThemeMode)
            
            ; 加载语音搜索选中的搜索引擎（保存上次的选择）
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
            } else {
                VoiceSearchSelectedEngines := ["deepseek"]
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
                if (ButtonType != "" && ButtonHotkey != "") {
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
            
            ; 加载剪贴板历史记录（Ctrl+C）
            global ClipboardHistory_CtrlC
            ClipboardHistory_CtrlC := []
            CtrlCCount := Integer(IniRead(ConfigFile, "Clipboard", "CtrlCCount", "0"))
            if (CtrlCCount > 0 && CtrlCCount <= 100) {
                Loop CtrlCCount {
                    Index := A_Index
                    EncodedContent := IniRead(ConfigFile, "Clipboard", "CtrlC_" . Index, "")
                    if (EncodedContent != "") {
                        ; 还原换行符
                        Content := StrReplace(EncodedContent, "{{CRLF}}", "`r`n")
                        Content := StrReplace(Content, "{{LF}}", "`n")
                        Content := StrReplace(Content, "{{CR}}", "`r")
                        ClipboardHistory_CtrlC.Push(Content)
                    }
                }
            }
            
            ; 加载剪贴板历史记录（CapsLock+C）
            global ClipboardHistory_CapsLockC
            ClipboardHistory_CapsLockC := []
            CapsLockCCount := Integer(IniRead(ConfigFile, "Clipboard", "CapsLockCCount", "0"))
            if (CapsLockCCount > 0 && CapsLockCCount <= 100) {
                Loop CapsLockCCount {
                    Index := A_Index
                    EncodedContent := IniRead(ConfigFile, "Clipboard", "CapsLockC_" . Index, "")
                    if (EncodedContent != "") {
                        ; 还原换行符
                        Content := StrReplace(EncodedContent, "{{CRLF}}", "`r`n")
                        Content := StrReplace(Content, "{{LF}}", "`n")
                        Content := StrReplace(Content, "{{CR}}", "`r")
                        ClipboardHistory_CapsLockC.Push(Content)
                    }
                }
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

InitConfig() ; 启动初始化

; ===================== 剪贴板变化监听 =====================
; 注意：OnClipboardChange 必须在脚本启动时注册，确保在 InitConfig 之后定义
; 监听 Ctrl+C 复制操作，自动记录到 Ctrl+C 历史记录
global LastClipboardContent := ""  ; 记录上次剪贴板内容，避免重复记录
global CapsLockCopyInProgress := false  ; 标记 CapsLock+C 是否正在进行中
global CapsLockCopyEndTime := 0  ; CapsLock+C 结束时间，用于延迟检测

; 【关键修复】在 AHK v2 中，调用 OnClipboardChange 注册监听函数
OnClipboardChange(HandleClipboardChange)

HandleClipboardChange(Type) {
    ; 只在剪贴板内容变化时触发（不是由 CapsLock+C 触发的）
    global ClipboardHistory_CtrlC, LastClipboardContent, CapsLockCopyInProgress, CapsLockCopyEndTime
    
    ; 如果 CapsLock+C 正在进行中，不记录（避免重复记录）
    if (CapsLockCopyInProgress) {
        return
    }
    
    ; 如果 CapsLock+C 刚结束（或处于保护期），也不记录（避免重复记录）
    CurrentTime := A_TickCount
    if (CapsLockCopyEndTime > 0 && (CurrentTime < CapsLockCopyEndTime + 2000)) {
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
        ; 如果内容为空，不记录
        if (CurrentContent = "") {
            return
        }
        
        ; 【增强排重】检查是否已经在历史记录中（避免连续复制相同内容）
        ; 检查最近的 3 条记录，如果完全相同则不记录
        IsDuplicate := false
        Loop Min(ClipboardHistory_CtrlC.Length, 3) {
            if (ClipboardHistory_CtrlC[ClipboardHistory_CtrlC.Length - A_Index + 1] = CurrentContent) {
                IsDuplicate := true
                break
            }
        }
        if (IsDuplicate) {
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
            
            ; 暂停百度输入法语音转换（F1）
            if (VoiceInputMethod = "baidu") {
                Send("{F1}")
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
                
                ; 恢复百度输入法语音转换（F2）
                if (VoiceInputMethod = "baidu") {
                    Send("{F2}")
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
    
    ; 如果面板还在显示，隐藏它
    if (PanelVisible) {
        HideCursorPanel()
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

; ===================== 显示面板函数 =====================
ShowCursorPanel() {
    global PanelVisible, GuiID_CursorPanel, SplitHotkey, BatchHotkey, CapsLock2
    global CursorPanelScreenIndex, FunctionPanelPos, QuickActionButtons
    global UI_Colors, ThemeMode
    
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
    PanelHeight := BaseHeight + (ButtonCount * ButtonSpacing)
    
    ; 面板尺寸（Cursor 风格，更紧凑现代）
    PanelWidth := 420
    
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
    ; 标题区域
    TitleBg := GuiID_CursorPanel.Add("Text", "x0 y0 w420 h50 Background" . UI_Colors.Background, "")
    TitleText := GuiID_CursorPanel.Add("Text", "x20 y12 w380 h26 Center c" . UI_Colors.Text, GetText("panel_title"))
    TitleText.SetFont("s13 Bold", "Segoe UI")
    
    ; 分隔线
    GuiID_CursorPanel.Add("Text", "x0 y50 w420 h1 Background" . UI_Colors.Border, "")
    
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
        }
        
        ; 替换快捷键（将默认快捷键替换为配置的快捷键）
        ; 例如："解释代码 (E)" -> "解释代码 (e)"（如果配置的是e）
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
    GuiID_CursorPanel.Add("Text", "x0 y" . (PanelHeight - 10) . " w420 h10 Background" . UI_Colors.Background, "")
    
    ; 获取屏幕信息并计算位置
    ScreenInfo := GetScreenInfo(CursorPanelScreenIndex)
    Pos := GetPanelPosition(ScreenInfo, PanelWidth, PanelHeight, FunctionPanelPos)
    
    ; 显示面板
    GuiID_CursorPanel.Show("w" . PanelWidth . " h" . PanelHeight . " x" . Pos.X . " y" . Pos.Y . " NoActivate")
    
    ; 确保窗口在最上层
    WinSetAlwaysOnTop(1, GuiID_CursorPanel.Hwnd)
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
    global PanelVisible, GuiID_CursorPanel
    
    if (!PanelVisible) {
        return
    }
    
    PanelVisible := false
    
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

; ===================== 执行提示词函数 =====================
ExecutePrompt(Type) {
    global Prompt_Explain, Prompt_Refactor, Prompt_Optimize, CursorPath, AISleepTime, IsCommandMode, CapsLock2, ClipboardHistory
    
    ; 清除标记，表示使用了功能
    CapsLock2 := false
    ; 标记命令模式结束，避免 CapsLock 释放后再次隐藏面板
    IsCommandMode := false
    
    HideCursorPanel()
    
    ; 根据类型选择提示词
    Prompt := ""
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
global PanelScreenRadio := []
; 已移除动画定时器，改用图片显示

; ===================== 标签切换函数 =====================
SwitchTab(TabName) {
    global ConfigTabs, CurrentTab
    global GeneralTabControls, AppearanceTabControls, PromptsTabControls, HotkeysTabControls, AdvancedTabControls
    
    ; 重置所有标签样式（使用主题颜色）
    global UI_Colors
    for Key, TabBtn in ConfigTabs {
        if (TabBtn) {
            try {
                TabBtn.BackColor := UI_Colors.Sidebar  ; 未选中状态
                TabBtn.SetFont("s11 c" . UI_Colors.Text, "Segoe UI")
            }
        }
    }
    
    ; 设置当前标签样式（选中状态）
    if (ConfigTabs.Has(TabName) && ConfigTabs[TabName]) {
        try {
            ConfigTabs[TabName].BackColor := UI_Colors.Background  ; 选中状态
            ConfigTabs[TabName].SetFont("s11 c" . UI_Colors.Text, "Segoe UI")
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
            ShowControls(PromptsTabControls)
        case "hotkeys":
            ShowControls(HotkeysTabControls)
            ; 显示第一个子标签页（如果存在）
            global HotkeySubTabs
            if (HotkeySubTabControls && HotkeySubTabs) {
                ; 找到第一个子标签页
                FirstKey := ""
                for Key, TabBtn in HotkeySubTabs {
                    FirstKey := Key
                    break
                }
                if (FirstKey != "") {
                    SwitchHotkeyTab(FirstKey)
                }
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
    
    ; 语言设置
    YPos += 50
    Label2 := ConfigGUI.Add("Text", "x" . (X + 30) . " y" . YPos . " w200 h25 c" . UI_Colors.Text, GetText("language_setting"))
    Label2.SetFont("s11", "Segoe UI")
    GeneralTabControls.Push(Label2)
    
    YPos += 30
    LangChinese := ConfigGUI.Add("Radio", "x" . (X + 30) . " y" . YPos . " w100 h30 vLangChinese c" . UI_Colors.Text, GetText("language_chinese"))
    LangChinese.SetFont("s11", "Segoe UI")
    LangChinese.BackColor := UI_Colors.Background
    GeneralTabControls.Push(LangChinese)
    
    LangEnglish := ConfigGUI.Add("Radio", "x" . (X + 140) . " y" . YPos . " w100 h30 vLangEnglish c" . UI_Colors.Text, GetText("language_english"))
    LangEnglish.SetFont("s11", "Segoe UI")
    LangEnglish.BackColor := UI_Colors.Background
    GeneralTabControls.Push(LangEnglish)
    
    ; 设置当前语言
    if (Language = "zh") {
        LangChinese.Value := 1
    } else {
        LangEnglish.Value := 1
    }
    
    ; CapsLock长按时间设置
    YPos += 60
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
    TabBarY := YPos + 50
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
        ; 【关键修复】使用Text控件模拟按钮，确保BackColor在暗色主题中正确生效
        ; 使用0x200样式（SS_CENTER）使文字居中，配合Background属性设置背景色
        BtnX := TabX
        BtnY := TabBarY + 5
        BtnW := TabWidth - 2
        BtnH := TabBarHeight - 10
        
        ; 【关键修复】为按钮添加边框，使两个按钮在暗色和亮色模式下都能清晰区分
        ; 上边框
        TopBorder := ConfigGUI.Add("Text", "x" . BtnX . " y" . BtnY . " w" . BtnW . " h1 Background" . UI_Colors.Border, "")
        GeneralTabControls.Push(TopBorder)
        ; 下边框
        BottomBorder := ConfigGUI.Add("Text", "x" . BtnX . " y" . (BtnY + BtnH - 1) . " w" . BtnW . " h1 Background" . UI_Colors.Border, "")
        GeneralTabControls.Push(BottomBorder)
        ; 左边框
        LeftBorder := ConfigGUI.Add("Text", "x" . BtnX . " y" . BtnY . " w1 h" . BtnH . " Background" . UI_Colors.Border, "")
        GeneralTabControls.Push(LeftBorder)
        ; 右边框
        RightBorder := ConfigGUI.Add("Text", "x" . (BtnX + BtnW - 1) . " y" . BtnY . " w1 h" . BtnH . " Background" . UI_Colors.Border, "")
        GeneralTabControls.Push(RightBorder)
        
        ; 按钮主体（内缩1px以显示边框）
        TabBtn := ConfigGUI.Add("Text", "x" . (BtnX + 1) . " y" . (BtnY + 1) . " w" . (BtnW - 2) . " h" . (BtnH - 2) . " Center 0x200 c" . UI_Colors.TextDim . " Background" . UI_Colors.Sidebar . " vGeneralSubTab" . Item.Key, Item.Name)
        TabBtn.SetFont("s10", "Segoe UI")
        TabBtn.OnEvent("Click", CreateGeneralSubTabClickHandler(Item.Key))
        ; 【关键修复】悬停效果使用主题颜色
        HoverBtn(TabBtn, UI_Colors.Sidebar, UI_Colors.BtnHover)
        GeneralTabControls.Push(TabBtn)
        GeneralSubTabs[Item.Key] := TabBtn
        TabX += TabWidth
    }
    
    global GeneralSubTabs := GeneralSubTabs
    
    ; 内容区域（显示当前选中的子标签页配置）
    ContentAreaY := TabBarY + TabBarHeight + 20
    ContentAreaHeight := H - (ContentAreaY - Y) - 20
    
    ; 为每个子标签创建内容面板
    for Index, Item in GeneralSubTabList {
        CreateGeneralSubTab(ConfigGUI, X + 30, ContentAreaY, W - 60, ContentAreaHeight + 500, Item)
    }
    
    ; 默认显示第一个子标签页
    if (GeneralSubTabList.Length > 0) {
        SwitchGeneralSubTab(GeneralSubTabList[1].Key)
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
            ; 快捷操作按钮配置
            YPos := Y + 20
            QuickActionDesc := ConfigGUI.Add("Text", "x" . X . " y" . YPos . " w" . W . " h20 c" . UI_Colors.TextDim, GetText("quick_action_config_desc"))
            QuickActionDesc.SetFont("s9", "Segoe UI")
            GeneralSubTabControls[Item.Key].Push(QuickActionDesc)
            
            YPos += 30
            global QuickActionConfigControls := []
            CreateQuickActionConfigUI(ConfigGUI, X, YPos, W, GeneralSubTabControls[Item.Key])
            
        case "searchcategory":
            ; 搜索标签配置
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
                TabBtn.BackColor := UI_Colors.Sidebar
                TabBtn.SetFont("s10 c" . UI_Colors.TextDim, "Segoe UI")
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
            ; 【关键修复】使用Text控件的Background属性设置选中状态的背景色
            GeneralSubTabs[SubTabKey].BackColor := UI_Colors.TabActive
            GeneralSubTabs[SubTabKey].SetFont("s10 c" . UI_Colors.Text, "Segoe UI")
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

; ===================== 创建快捷操作按钮配置UI =====================
CreateQuickActionConfigUI(ConfigGUI, X, Y, W, ParentControls) {
    global QuickActionButtons, QuickActionConfigControls, UI_Colors
    
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
        {Type: "Batch", Name: GetText("quick_action_type_batch"), Hotkey: "b", Desc: GetText("hotkey_b_desc")}
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
        RadioSpacing := 100  ; 单选按钮之间的间距（缩小以适应更多选项）
        
        ; 说明文字（去掉快捷键输入框，直接显示说明）
        DescX := RadioX
        DescY := RadioY + 60  ; 调整位置，确保在单选按钮下方
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
        
        DescText := ConfigGUI.Add("Text", "x" . DescX . " y" . DescY . " w" . DescW . " h" . DescH . " vQuickActionDesc" . Index . " c" . UI_Colors.TextDim . " Background" . UI_Colors.Background . " +0x200", CurrentDesc)  ; +0x200 = SS_LEFTNOWORDWRAP，确保文字正确显示，避免乱码
        DescText.SetFont("s9", "Segoe UI")
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
        
        ; 单选按钮分两行显示（每行5个）
        RadioControls := []  ; 存储所有单选按钮，用于设置选中状态
        for TypeIndex, ActionType in ActionTypes {
            ; 计算行和列
            Row := Floor((TypeIndex - 1) / 5)
            Col := Mod((TypeIndex - 1), 5)
            RadioXPos := RadioX + Col * RadioSpacing
            RadioYPos := RadioY + Row * 30  ; 行间距30px
            
            ; 保存当前ActionType的值到局部变量，确保闭包中能正确访问
            CurrentActionTypeDesc := ActionType.Desc
            CurrentTypeIndex := TypeIndex
            
            ; 由于单选按钮在循环中创建且位置不连续，无法使用自动互斥功能
            ; 改为手动管理互斥：每个按钮使用唯一的变量名，在点击事件中手动取消其他按钮的选中状态
            RadioCtrlName := RadioGroupName . "_" . TypeIndex
            RadioCtrl := ConfigGUI.Add("Radio", "x" . RadioXPos . " y" . RadioYPos . " w95 h28 v" . RadioCtrlName . " c" . UI_Colors.Text . " Background" . UI_Colors.Background, ActionType.Name)
            RadioCtrl.SetFont("s9", "Segoe UI")
            
            ; 添加事件处理：当单选按钮改变时，更新说明文字并手动管理互斥
            ; 为每个单选按钮创建独立的事件处理器，确保点击时能正确更新说明和互斥状态
            ; 使用局部变量确保闭包中能正确访问值
            RadioCtrl.OnEvent("Click", CreateRadioClickHandler(Index, CurrentActionTypeDesc, CurrentTypeIndex, RadioControls))
            
            RadioControls.Push(RadioCtrl)
            QuickActionConfigControls.Push(RadioCtrl)
        }
        
        ; 设置选中状态（通过设置对应索引的单选按钮的Value为1）
        if (SelectedTypeIndex >= 1 && SelectedTypeIndex <= RadioControls.Length) {
            RadioControls[SelectedTypeIndex].Value := 1
        }
        
        ; 说明文字已在创建DescText时设置，无需重复初始化
        
        ; 底部边框线（Cursor风格：分隔每个按钮项，使用更柔和的颜色）
        if (Index < 5) {
            BottomBorder := ConfigGUI.Add("Text", "x" . X . " y" . (ButtonY + 105) . " w" . W . " h1 Background" . UI_Colors.Border, "")
            QuickActionConfigControls.Push(BottomBorder)
        }
        
        ButtonY += 110  ; 增加高度以适应两行单选按钮和说明文字
    }
    
    ; 将控件添加到父控件列表
    for Index, Ctrl in QuickActionConfigControls {
        ParentControls.Push(Ctrl)
    }
    
    ; 返回最后的Y位置，供后续配置使用
    return ButtonY
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
    
    ; 创建复选框（每行2个）
    CheckboxY := Y
    CheckboxWidth := (W - 30) / 2  ; 两个复选框，中间间距30
    CheckboxHeight := 30
    CheckboxSpacing := 10
    
    for Index, Category in AllCategories {
        ; 计算位置
        Row := Floor((Index - 1) / 2)
        Col := Mod((Index - 1), 2)
        CheckboxX := X + Col * (CheckboxWidth + 30)
        CurrentY := CheckboxY + Row * (CheckboxHeight + CheckboxSpacing)
        
        ; 检查是否启用
        IsEnabled := (ArrayContainsValue(VoiceSearchEnabledCategories, Category.Key) > 0)
        
        ; 创建复选框
        Checkbox := ConfigGUI.Add("Checkbox", "x" . CheckboxX . " y" . CurrentY . " w" . CheckboxWidth . " h" . CheckboxHeight . " vSearchCategoryCheckbox" . Category.Key . " c" . UI_Colors.Text, Category.Text)
        Checkbox.SetFont("s10", "Segoe UI")
        Checkbox.Value := IsEnabled ? 1 : 0
        Checkbox.BackColor := UI_Colors.Background
        Checkbox.OnEvent("Click", CreateSearchCategoryCheckboxHandler(Category.Key))
        SearchCategoryConfigControls.Push(Checkbox)
        ParentControls.Push(Checkbox)  ; 【关键修复】将复选框添加到父控件列表，确保在标签页切换时正确显示/隐藏
    }
}

; ===================== 搜索标签复选框点击处理 =====================
CreateSearchCategoryCheckboxHandler(CategoryKey) {
    return (*) => ToggleSearchCategory(CategoryKey)
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
            IsEnabled := (Checkbox.Value = 1)
            
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
                Checkbox.Value := 1
            }
        }
    } catch {
        ; 忽略错误
    }
}

; ===================== 快捷操作类型改变处理 =====================
CreateQuickActionTypeChangeHandler(Index, Desc, TypeIndex) {
    return (*) => UpdateQuickActionDesc(Index, Desc, TypeIndex)
}

; ===================== 创建单选按钮点击处理器 =====================
CreateRadioClickHandler(Index, Desc, TypeIndex, RadioControls) {
    ; 返回一个函数，该函数会手动管理互斥并更新说明文字
    ActionFunc(*) {
        ; 手动管理互斥：取消其他按钮的选中状态
        for RadioIndex, RadioCtrl in RadioControls {
            if (RadioIndex != TypeIndex) {
                RadioCtrl.Value := 0
            } else {
                RadioCtrl.Value := 1
            }
        }
        ; 更新说明文字
        UpdateQuickActionDesc(Index, Desc, TypeIndex)
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
                    {Type: "Batch", Name: GetText("quick_action_type_batch"), Hotkey: "b", Desc: GetText("hotkey_b_desc")}
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
    global GuiID_ConfigGUI, GeneralSubTabControls, QuickActionButtons, UI_Colors
    
    if (GuiID_ConfigGUI = 0) {
        return
    }
    
    try {
        ConfigGUI := GuiFromHwnd(GuiID_ConfigGUI)
        if (!ConfigGUI) {
            return
        }
        
        ; 获取通用子标签页的位置和尺寸
        ; 查找快捷操作子标签页的面板
        QuickActionPanel := ConfigGUI["GeneralSubTabquickactionPanel"]
        if (!QuickActionPanel) {
            return
        }
        
        ; 获取面板位置和尺寸
        QuickActionPanel.GetPos(&TabX, &TabY, &TabW, &TabH)
        
        ; 重新创建快捷操作配置UI
        ; 先销毁旧的控件
        global QuickActionConfigControls
        if (IsSet(QuickActionConfigControls)) {
            for Index, Ctrl in QuickActionConfigControls {
                try {
                    Ctrl.Destroy()
                } catch {
                    ; 忽略已销毁的控件
                }
            }
        }
        
        ; 从GeneralSubTabControls中移除快捷操作相关的控件
        if (GeneralSubTabControls.Has("quickaction")) {
            NewQuickActionControls := []
            for Index, Ctrl in GeneralSubTabControls["quickaction"] {
                IsQuickActionCtrl := false
                if (IsSet(QuickActionConfigControls)) {
                    for J, QACtrl in QuickActionConfigControls {
                        if (Ctrl = QACtrl) {
                            IsQuickActionCtrl := true
                            break
                        }
                    }
                }
                if (!IsQuickActionCtrl) {
                    NewQuickActionControls.Push(Ctrl)
                }
            }
            GeneralSubTabControls["quickaction"] := NewQuickActionControls
        }
        
        ; 重新创建快捷操作配置UI
        ; Y位置从面板顶部开始，加上描述文字的高度
        YPos := TabY + 50
        QuickActionConfigControls := []
        CreateQuickActionConfigUI(ConfigGUI, TabX, YPos, TabW, GeneralSubTabControls["quickaction"])
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
    for Index, ScreenName in ScreenList {
        XPos := StartX + (Index - 1) * (RadioWidth + Spacing)
        RadioBtn := ConfigGUI.Add("Radio", "x" . XPos . " y" . YPos . " w" . RadioWidth . " h" . RadioHeight . " vPanelScreenRadio" . Index . " c" . UI_Colors.Text, ScreenName)
        RadioBtn.SetFont("s11", "Segoe UI")
        RadioBtn.BackColor := UI_Colors.Background
        if (Index = PanelScreenIndex) {
            RadioBtn.Value := 1
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
    ThemeLightRadio := ConfigGUI.Add("Radio", "x" . (X + 30) . " y" . YPos . " w100 h30 vThemeLightRadio c" . UI_Colors.Text, GetText("theme_light"))
    ThemeLightRadio.SetFont("s11", "Segoe UI")
    ThemeLightRadio.BackColor := UI_Colors.Background
    AppearanceTabControls.Push(ThemeLightRadio)
    
    ThemeDarkRadio := ConfigGUI.Add("Radio", "x" . (X + 140) . " y" . YPos . " w100 h30 vThemeDarkRadio c" . UI_Colors.Text, GetText("theme_dark"))
    ThemeDarkRadio.SetFont("s11", "Segoe UI")
    ThemeDarkRadio.BackColor := UI_Colors.Background
    AppearanceTabControls.Push(ThemeDarkRadio)
    
    ; 设置当前主题
    if (ThemeMode = "light") {
        ThemeLightRadio.Value := 1
    } else {
        ThemeDarkRadio.Value := 1
    }
}

; ===================== 创建提示词标签页 =====================
CreatePromptsTab(ConfigGUI, X, Y, W, H) {
    global Prompt_Explain, Prompt_Refactor, Prompt_Optimize, PromptsTabPanel, PromptExplainEdit, PromptRefactorEdit, PromptOptimizeEdit, PromptsTabControls
    global UI_Colors
    
    ; 创建标签页面板（默认隐藏）
    PromptsTabPanel := ConfigGUI.Add("Text", "x" . X . " y" . Y . " w" . W . " h" . H . " Background" . UI_Colors.Background . " vPromptsTabPanel", "")
    PromptsTabPanel.Visible := false
    PromptsTabControls.Push(PromptsTabPanel)
    
    ; 标题
    Title := ConfigGUI.Add("Text", "x" . (X + 30) . " y" . (Y + 20) . " w" . (W - 60) . " h30 c" . UI_Colors.Text, GetText("prompt_settings"))
    Title.SetFont("s16 Bold", "Segoe UI")
    PromptsTabControls.Push(Title)
    
    ; 解释代码提示词
    YPos := Y + 70
    Label1 := ConfigGUI.Add("Text", "x" . (X + 30) . " y" . YPos . " w" . (W - 60) . " h25 c" . UI_Colors.Text, GetText("explain_prompt"))
    Label1.SetFont("s11", "Segoe UI")
    PromptsTabControls.Push(Label1)
    
    ; 【关键修复】确保提示词文本根据当前语言显示正确的默认值
    global Language
    ChineseDefaultExplain := "解释这段代码的核心逻辑、输入输出、关键函数作用，用新手能懂的语言，标注易错点"
    ChineseDefaultRefactor := "重构这段代码，遵循PEP8/行业规范，简化冗余逻辑，添加中文注释，保持功能不变"
    ChineseDefaultOptimize := "分析这段代码的性能瓶颈（时间/空间复杂度），给出优化方案+对比说明，保留原逻辑可读性"
    
    ; 如果提示词为空或是中文默认值，根据当前语言设置正确的默认值
    if (Prompt_Explain = "" || Prompt_Explain = ChineseDefaultExplain) {
        Prompt_Explain := (Language = "zh") ? ChineseDefaultExplain : GetText("default_prompt_explain")
    }
    if (Prompt_Refactor = "" || Prompt_Refactor = ChineseDefaultRefactor) {
        Prompt_Refactor := (Language = "zh") ? ChineseDefaultRefactor : GetText("default_prompt_refactor")
    }
    if (Prompt_Optimize = "" || Prompt_Optimize = ChineseDefaultOptimize) {
        Prompt_Optimize := (Language = "zh") ? ChineseDefaultOptimize : GetText("default_prompt_optimize")
    }
    
    YPos += 30
    PromptExplainEdit := ConfigGUI.Add("Edit", "x" . (X + 30) . " y" . YPos . " w" . (W - 60) . " h80 vPromptExplainEdit Background" . UI_Colors.InputBg . " c" . UI_Colors.Text . " Multi", Prompt_Explain)
    PromptExplainEdit.SetFont("s10", "Consolas")
    PromptsTabControls.Push(PromptExplainEdit)
    
    ; 重构代码提示词
    YPos += 100
    Label2 := ConfigGUI.Add("Text", "x" . (X + 30) . " y" . YPos . " w" . (W - 60) . " h25 c" . UI_Colors.Text, GetText("refactor_prompt"))
    Label2.SetFont("s11", "Segoe UI")
    PromptsTabControls.Push(Label2)
    
    YPos += 30
    PromptRefactorEdit := ConfigGUI.Add("Edit", "x" . (X + 30) . " y" . YPos . " w" . (W - 60) . " h80 vPromptRefactorEdit Background" . UI_Colors.InputBg . " c" . UI_Colors.Text . " Multi", Prompt_Refactor)
    PromptRefactorEdit.SetFont("s10", "Consolas")
    PromptsTabControls.Push(PromptRefactorEdit)
    
    ; 优化代码提示词
    YPos += 100
    Label3 := ConfigGUI.Add("Text", "x" . (X + 30) . " y" . YPos . " w" . (W - 60) . " h25 c" . UI_Colors.Text, GetText("optimize_prompt"))
    Label3.SetFont("s11", "Segoe UI")
    PromptsTabControls.Push(Label3)
    
    YPos += 30
    PromptOptimizeEdit := ConfigGUI.Add("Edit", "x" . (X + 30) . " y" . YPos . " w" . (W - 60) . " h80 vPromptOptimizeEdit Background" . UI_Colors.InputBg . " c" . UI_Colors.Text . " Multi", Prompt_Optimize)
    PromptOptimizeEdit.SetFont("s10", "Consolas")
    PromptsTabControls.Push(PromptOptimizeEdit)
}

; ===================== 创建快捷键标签页 =====================
CreateHotkeysTab(ConfigGUI, X, Y, W, H) {
    global SplitHotkey, BatchHotkey, HotkeysTabPanel, SplitHotkeyEdit, BatchHotkeyEdit, HotkeysTabControls
    global HotkeyESC, HotkeyC, HotkeyV, HotkeyX, HotkeyE, HotkeyR, HotkeyO, HotkeyQ, HotkeyZ
    global HotkeyESCEdit, HotkeyCEdit, HotkeyVEdit, HotkeyXEdit, HotkeyEEdit, HotkeyREdit, HotkeyOEdit, HotkeyQEdit, HotkeyZEdit
    global HotkeySubTabs, HotkeySubTabControls, UI_Colors
    
    ; 创建标签页面板（默认隐藏）
    HotkeysTabPanel := ConfigGUI.Add("Text", "x" . X . " y" . Y . " w" . W . " h" . H . " Background" . UI_Colors.Background . " vHotkeysTabPanel", "")
    HotkeysTabPanel.Visible := false
    HotkeysTabControls.Push(HotkeysTabPanel)
    
    ; 标题
    Title := ConfigGUI.Add("Text", "x" . (X + 30) . " y" . (Y + 20) . " w" . (W - 60) . " h30 c" . UI_Colors.Text, GetText("hotkey_settings"))
    Title.SetFont("s16 Bold", "Segoe UI")
    HotkeysTabControls.Push(Title)
    
    ; ========== 横向标签页区域 ==========
    TabBarY := Y + 70
    TabBarHeight := 40
    TabBarBg := ConfigGUI.Add("Text", "x" . (X + 30) . " y" . TabBarY . " w" . (W - 60) . " h" . TabBarHeight . " Background" . UI_Colors.Sidebar, "")  ; 使用主题颜色
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
        {Key: "B", Name: GetText("hotkey_b"), Default: BatchHotkey, Edit: "BatchHotkeyEdit", Desc: "hotkey_b_desc", Hint: "hotkey_single_char_hint", DefaultVal: "b"}
    ]
    
    ; 创建横向标签按钮
    TabWidth := (W - 60) / HotkeyList.Length
    TabX := X + 30
    HotkeySubTabs := Map()
    global HotkeySubTabControls := Map()  ; 确保是全局变量
    
    ; 创建横向标签点击处理函数（避免闭包问题）
    CreateHotkeyTabClickHandler(Key) {
        return (*) => SwitchHotkeyTab(Key)
    }
    
    for Index, Item in HotkeyList {
        ; 创建横向标签按钮，确保可以点击
        ; 使用Button控件而不是Text控件，确保点击事件正常工作
        TabBtn := ConfigGUI.Add("Button", "x" . TabX . " y" . (TabBarY + 5) . " w" . (TabWidth - 2) . " h" . (TabBarHeight - 10) . " vHotkeyTab" . Item.Key, Item.Name)
        TabBtn.SetFont("s9", "Segoe UI")
        ; 使用主题颜色：未选中状态
        TabBtn.BackColor := UI_Colors.Sidebar  ; 使用主题侧边栏颜色
        TabBtn.SetFont("s9 c" . UI_Colors.TextDim, "Segoe UI")  ; 使用主题文字颜色
        ; 绑定点击事件，使用辅助函数确保每个按钮绑定到正确的键
        TabBtn.OnEvent("Click", CreateHotkeyTabClickHandler(Item.Key))
        ; 悬停效果使用主题颜色
        HoverBtn(TabBtn, UI_Colors.Sidebar, UI_Colors.BtnHover)  ; 使用主题悬停颜色
        HotkeysTabControls.Push(TabBtn)
        HotkeySubTabs[Item.Key] := TabBtn
        TabX += TabWidth
    }
    
    global HotkeySubTabs := HotkeySubTabs
    
    ; 内容区域（显示当前选中的快捷键配置）
    ; 创建一个可滚动的容器来包裹所有内容
    ContentAreaY := TabBarY + TabBarHeight + 20
    ContentAreaHeight := H - (ContentAreaY - Y) - 20
    
    ; 为每个快捷键创建内容面板
    ; 注意：内容可以超出 ContentAreaHeight，通过滚动查看
    for Index, Item in HotkeyList {
        ; 传入更大的高度值，允许内容超出可视区域
        CreateHotkeySubTab(ConfigGUI, X + 30, ContentAreaY, W - 60, ContentAreaHeight + 500, Item)
    }
    
    ; 默认显示第一个标签页
    if (HotkeyList.Length > 0) {
        SwitchHotkeyTab(HotkeyList[1].Key)
    }
}

; ===================== 创建快捷键子标签页 =====================
CreateHotkeySubTab(ConfigGUI, X, Y, W, H, Item) {
    global HotkeysTabControls, HotkeySubTabControls, UI_Colors
    global HotkeyESC, HotkeyC, HotkeyV, HotkeyX, HotkeyE, HotkeyR, HotkeyO, HotkeyQ, HotkeyZ
    global SplitHotkey, BatchHotkey
    global HotkeyESCEdit, HotkeyCEdit, HotkeyVEdit, HotkeyXEdit, HotkeyEEdit, HotkeyREdit, HotkeyOEdit, HotkeyQEdit, HotkeyZEdit
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
                TabBtn.BackColor := UI_Colors.Sidebar  ; 使用主题侧边栏颜色
                TabBtn.SetFont("s9 c" . UI_Colors.TextDim, "Segoe UI")  ; 使用主题文字颜色
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
    
    ; 设置当前子标签样式（使用 Cursor 暗色系）
    if (HotkeySubTabs.Has(HotkeyKey) && HotkeySubTabs[HotkeyKey]) {
        try {
            HotkeySubTabs[HotkeyKey].BackColor := UI_Colors.TabActive  ; 使用主题选中背景
            HotkeySubTabs[HotkeyKey].SetFont("s9 c" . UI_Colors.Text, "Segoe UI")  ; 使用主题文字颜色
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

; ===================== 创建高级标签页 =====================
CreateAdvancedTab(ConfigGUI, X, Y, W, H) {
    global AISleepTime, AdvancedTabPanel, AISleepTimeEdit, AdvancedTabControls
    global ConfigPanelScreenIndex, MsgBoxScreenIndex, VoiceInputScreenIndex, CursorPanelScreenIndex
    global ConfigPanelScreenRadio, MsgBoxScreenRadio, VoiceInputScreenRadio, CursorPanelScreenRadio
    global UI_Colors
    
    ; 创建标签页面板（默认隐藏）
    AdvancedTabPanel := ConfigGUI.Add("Text", "x" . X . " y" . Y . " w" . W . " h" . H . " Background" . UI_Colors.Background . " vAdvancedTabPanel", "")
    AdvancedTabPanel.Visible := false
    AdvancedTabControls.Push(AdvancedTabPanel)
    
    ; 标题
    Title := ConfigGUI.Add("Text", "x" . (X + 30) . " y" . (Y + 20) . " w" . (W - 60) . " h30 c" . UI_Colors.Text, GetText("advanced_settings"))
    Title.SetFont("s16 Bold", "Segoe UI")
    AdvancedTabControls.Push(Title)
    
    ; AI 响应等待时间
    YPos := Y + 70
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
    
    ; 配置面板显示器选择
    YPos += 50
    LabelConfigPanel := ConfigGUI.Add("Text", "x" . (X + 30) . " y" . YPos . " w200 h25 c" . UI_Colors.Text, GetText("config_panel_screen"))
    LabelConfigPanel.SetFont("s11", "Segoe UI")
    AdvancedTabControls.Push(LabelConfigPanel)
    
    YPos += 30
    ConfigPanelScreenRadio := []
    StartX := X + 30
    RadioWidth := 100
    RadioHeight := 30
    Spacing := 10
    for Index, ScreenName in ScreenList {
        XPos := StartX + (Index - 1) * (RadioWidth + Spacing)
        RadioBtn := ConfigGUI.Add("Radio", "x" . XPos . " y" . YPos . " w" . RadioWidth . " h" . RadioHeight . " vConfigPanelScreenRadio" . Index . " c" . UI_Colors.Text, ScreenName)
        RadioBtn.SetFont("s11", "Segoe UI")
        RadioBtn.BackColor := UI_Colors.Background
        if (Index = ConfigPanelScreenIndex) {
            RadioBtn.Value := 1
        }
        ConfigPanelScreenRadio.Push(RadioBtn)
        AdvancedTabControls.Push(RadioBtn)
    }
    
    ; 弹窗显示器选择
    YPos += 50
    LabelMsgBox := ConfigGUI.Add("Text", "x" . (X + 30) . " y" . YPos . " w200 h25 c" . UI_Colors.Text, GetText("msgbox_screen"))
    LabelMsgBox.SetFont("s11", "Segoe UI")
    AdvancedTabControls.Push(LabelMsgBox)
    
    YPos += 30
    MsgBoxScreenRadio := []
    for Index, ScreenName in ScreenList {
        XPos := StartX + (Index - 1) * (RadioWidth + Spacing)
        RadioBtn := ConfigGUI.Add("Radio", "x" . XPos . " y" . YPos . " w" . RadioWidth . " h" . RadioHeight . " vMsgBoxScreenRadio" . Index . " c" . UI_Colors.Text, ScreenName)
        RadioBtn.SetFont("s11", "Segoe UI")
        RadioBtn.BackColor := UI_Colors.Background
        if (Index = MsgBoxScreenIndex) {
            RadioBtn.Value := 1
        }
        MsgBoxScreenRadio.Push(RadioBtn)
        AdvancedTabControls.Push(RadioBtn)
    }
    
    ; 语音输入法提示显示器选择
    YPos += 50
    LabelVoiceInput := ConfigGUI.Add("Text", "x" . (X + 30) . " y" . YPos . " w200 h25 c" . UI_Colors.Text, GetText("voice_input_screen"))
    LabelVoiceInput.SetFont("s11", "Segoe UI")
    AdvancedTabControls.Push(LabelVoiceInput)
    
    YPos += 30
    VoiceInputScreenRadio := []
    for Index, ScreenName in ScreenList {
        XPos := StartX + (Index - 1) * (RadioWidth + Spacing)
        RadioBtn := ConfigGUI.Add("Radio", "x" . XPos . " y" . YPos . " w" . RadioWidth . " h" . RadioHeight . " vVoiceInputScreenRadio" . Index . " c" . UI_Colors.Text, ScreenName)
        RadioBtn.SetFont("s11", "Segoe UI")
        RadioBtn.BackColor := UI_Colors.Background
        if (Index = VoiceInputScreenIndex) {
            RadioBtn.Value := 1
        }
        VoiceInputScreenRadio.Push(RadioBtn)
        AdvancedTabControls.Push(RadioBtn)
    }
    
    ; Cursor快捷弹出面板显示器选择
    YPos += 50
    LabelCursorPanel := ConfigGUI.Add("Text", "x" . (X + 30) . " y" . YPos . " w200 h25 c" . UI_Colors.Text, GetText("cursor_panel_screen"))
    LabelCursorPanel.SetFont("s11", "Segoe UI")
    AdvancedTabControls.Push(LabelCursorPanel)
    
    YPos += 30
    CursorPanelScreenRadio := []
    for Index, ScreenName in ScreenList {
        XPos := StartX + (Index - 1) * (RadioWidth + Spacing)
        RadioBtn := ConfigGUI.Add("Radio", "x" . XPos . " y" . YPos . " w" . RadioWidth . " h" . RadioHeight . " vCursorPanelScreenRadio" . Index . " c" . UI_Colors.Text, ScreenName)
        RadioBtn.SetFont("s11", "Segoe UI")
        RadioBtn.BackColor := UI_Colors.Background
        if (Index = CursorPanelScreenIndex) {
            RadioBtn.Value := 1
        }
        CursorPanelScreenRadio.Push(RadioBtn)
        AdvancedTabControls.Push(RadioBtn)
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
        
        ; 重置屏幕选择
        if (IsSet(PanelScreenRadio) && PanelScreenRadio && PanelScreenRadio.Length > 0) {
            for Index, RadioBtn in PanelScreenRadio {
                RadioBtn.Value := 0
            }
            if (DefaultPanelScreenIndex >= 1 && DefaultPanelScreenIndex <= PanelScreenRadio.Length) {
                PanelScreenRadio[DefaultPanelScreenIndex].Value := 1
            } else if (PanelScreenRadio.Length > 0) {
                PanelScreenRadio[1].Value := 1
            }
        }
    } catch {
        ; 忽略控件失效错误
    }
    
    MsgBox(GetText("reset_default_success"), GetText("tip"), "Iconi")
}

; ===================== UI 常量定义 =====================
; UI颜色已在脚本开头初始化（第104-165行），这里不再重复定义

; 窗口拖动事件
WM_LBUTTONDOWN(*) {
    PostMessage(0xA1, 2)
}

; 自定义按钮悬停效果
HoverBtn(Ctrl, NormalColor, HoverColor) {
    Ctrl.NormalColor := NormalColor
    Ctrl.HoverColor := HoverColor
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

; 监听鼠标移动消息实现 Hover
OnMessage(0x0200, WM_MOUSEMOVE)

WM_MOUSEMOVE(wParam, lParam, Msg, Hwnd) {
    global LastHoverCtrl
    
    try {
        ; 获取鼠标下的控件
        MouseCtrl := GuiCtrlFromHwnd(Hwnd)
        
        ; 如果是新控件且具有 Hover 属性
        if (MouseCtrl && MouseCtrl.HasProp("HoverColor")) {
            if (LastHoverCtrl != MouseCtrl) {
                ; 恢复上一个控件颜色
                if (LastHoverCtrl && LastHoverCtrl.HasProp("NormalColor")) {
                    try LastHoverCtrl.BackColor := LastHoverCtrl.NormalColor
                }
                
                ; 设置新控件颜色
                try MouseCtrl.BackColor := MouseCtrl.HoverColor
                LastHoverCtrl := MouseCtrl
                
                ; 启动定时器检测鼠标离开
                SetTimer CheckMouseLeave, 50
            }
        }
    }
}

CheckMouseLeave() {
    global LastHoverCtrl
    
    if (!LastHoverCtrl) {
        SetTimer , 0
        return
    }
    
    try {
        MouseGetPos ,,, &MouseHwnd, 2
        
        ; 如果鼠标不在当前控件上
        if (MouseHwnd != LastHoverCtrl.Hwnd) {
            if (LastHoverCtrl.HasProp("NormalColor")) {
                try LastHoverCtrl.BackColor := LastHoverCtrl.NormalColor
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
    
    ; 创建配置 GUI（无边框窗口，支持滚动）
    ConfigGUI := Gui("+Resize -MaximizeBox -Caption +Border", GetText("config_title"))
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
    HoverBtn(CloseBtnTopLeft, UI_Colors.TitleBar, "e81123") ; 红色关闭 hover
    
    ; 窗口标题（调整位置，避免被左上角关闭按钮遮挡）
    WinTitle := ConfigGUI.Add("Text", "x40 y8 w" . (ConfigWidth - 80) . " h20 Background" . UI_Colors.TitleBar . " c" . UI_Colors.Text . " vWinTitle", GetText("config_title"))
    WinTitle.SetFont("s10 Bold", "Segoe UI")
    WinTitle.OnEvent("Click", (*) => PostMessage(0xA1, 2))
    
    ; 右上角关闭按钮
    CloseBtnTopRight := ConfigGUI.Add("Text", "x" . (ConfigWidth - 40) . " y0 w40 h35 Center 0x200 Background" . UI_Colors.TitleBar . " c" . UI_Colors.Text . " vCloseBtnTopRight", "✕")
    CloseBtnTopRight.SetFont("s10", "Segoe UI")
    CloseBtnTopRight.OnEvent("Click", (*) => CloseConfigGUI())
    HoverBtn(CloseBtnTopRight, UI_Colors.TitleBar, "e81123") ; 红色关闭 hover
    
    ; 左下角关闭按钮
    CloseBtnBottomLeft := ConfigGUI.Add("Text", "x0 y" . (ConfigHeight - 40) . " w40 h40 Center 0x200 Background" . UI_Colors.Background . " c" . UI_Colors.Text . " vCloseBtnBottomLeft", "✕")
    CloseBtnBottomLeft.SetFont("s10", "Segoe UI")
    CloseBtnBottomLeft.OnEvent("Click", (*) => CloseConfigGUI())
    HoverBtn(CloseBtnBottomLeft, UI_Colors.Background, "e81123") ; 红色关闭 hover
    
    ; 右下角关闭按钮
    CloseBtnBottomRight := ConfigGUI.Add("Text", "x" . (ConfigWidth - 40) . " y" . (ConfigHeight - 40) . " w40 h40 Center 0x200 Background" . UI_Colors.Background . " c" . UI_Colors.Text . " vCloseBtnBottomRight", "✕")
    CloseBtnBottomRight.SetFont("s10", "Segoe UI")
    CloseBtnBottomRight.OnEvent("Click", (*) => CloseConfigGUI())
    HoverBtn(CloseBtnBottomRight, UI_Colors.Background, "e81123") ; 红色关闭 hover
    
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
    
    ; 创建侧边栏标签按钮的辅助函数
    CreateSidebarTab(Label, Name, YPos) {
        Btn := ConfigGUI.Add("Text", "x0 y" . YPos . " w" . SidebarWidth . " h" . TabHeight . " Center 0x200 c" . UI_Colors.Text . " Background" . UI_Colors.Sidebar . " vTab" . Name, Label)
        Btn.SetFont("s10", "Segoe UI")
        Btn.OnEvent("Click", (*) => SwitchTab(Name))
        HoverBtn(Btn, UI_Colors.Sidebar, UI_Colors.TabActive)
        return Btn
    }
    
    TabGeneral := CreateSidebarTab(GetText("tab_general"), "general", TabY)
    TabAppearance := CreateSidebarTab(GetText("tab_appearance"), "appearance", TabY + (TabHeight + TabSpacing))
    TabPrompts := CreateSidebarTab(GetText("tab_prompts"), "prompts", TabY + (TabHeight + TabSpacing) * 2)
    TabHotkeys := CreateSidebarTab(GetText("tab_hotkeys"), "hotkeys", TabY + (TabHeight + TabSpacing) * 3)
    TabAdvanced := CreateSidebarTab(GetText("tab_advanced"), "advanced", TabY + (TabHeight + TabSpacing) * 4)
    
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
    ButtonAreaY := ConfigHeight - 70  ; 增加高度以容纳按钮说明文字
    ; 移除底部按钮区域的背景色块，只保留按钮本身
    ; ButtonAreaBg := ConfigGUI.Add("Text", "x" . ContentX . " y" . ButtonAreaY . " w" . ContentWidth . " h50 Background" . UI_Colors.Background . " vButtonAreaBg", "") ; 遮挡背景
    
    ; 底部按钮辅助函数（带说明文字）
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
        HoverBtn(Btn, BgColor, HoverColor)
        
        ; 添加按钮功能说明
        if (Desc != "") {
            DescText := ConfigGUI.Add("Text", "x" . XPos . " y" . (ButtonAreaY + 42) . " w80 h15 Center c" . UI_Colors.TextDim, Desc)
            DescText.SetFont("s7", "Segoe UI")
        }
        
        return Btn
    }

    ; 计算按钮位置 (右对齐，确保不重叠)
    BtnWidth := 80
    BtnSpacing := 10
    BtnStartX := ConfigWidth - (BtnWidth * 5 + BtnSpacing * 4) - 20  ; 5个按钮，4个间距，右边距20
    
    CreateBottomBtn(GetText("export_config"), BtnStartX, ExportConfig, false, "ExportBtn", GetText("export_config_desc"))
    CreateBottomBtn(GetText("import_config"), BtnStartX + BtnWidth + BtnSpacing, ImportConfig, false, "ImportBtn", GetText("import_config_desc"))
    CreateBottomBtn(GetText("reset_default"), BtnStartX + (BtnWidth + BtnSpacing) * 2, ResetToDefaults, false, "ResetBtn", GetText("reset_default_desc"))
    CreateBottomBtn(GetText("save_config"), BtnStartX + (BtnWidth + BtnSpacing) * 3, SaveConfigAndClose, true, "SaveBtn", GetText("save_config_desc")) ; Primary
    CreateBottomBtn(GetText("cancel"), BtnStartX + (BtnWidth + BtnSpacing) * 4, (*) => CloseConfigGUI(), false, "CancelBtn", GetText("cancel_desc"))
    
    ; 默认显示通用标签
    SwitchTab("general")
    
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
    
    ; 设置窗口最小尺寸限制（使用 DllCall 调用 Windows API）
    SetWindowMinSizeLimit(ConfigGUI.Hwnd, 800, 600)
    
    ; 添加滚动条样式（WS_VSCROLL | WS_HSCROLL）
    ; GWL_STYLE = -16
    ; 【关键修复】在AutoHotkey v2中，使用GetWindowLong和SetWindowLong（自动处理32/64位）
    ; 注意：在64位系统上，GetWindowLong会自动处理为GetWindowLongPtr
    CurrentStyle := DllCall("user32.dll\GetWindowLong", "Ptr", ConfigGUI.Hwnd, "Int", -16, "Int")
    NewStyle := CurrentStyle | 0x00200000 | 0x00100000  ; WS_VSCROLL | WS_HSCROLL
    DllCall("user32.dll\SetWindowLong", "Ptr", ConfigGUI.Hwnd, "Int", -16, "Int", NewStyle, "Int")
    DllCall("user32.dll\SetWindowPos", "Ptr", ConfigGUI.Hwnd, "Ptr", 0, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x0027, "Int")  ; SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_FRAMECHANGED
    
    ; 设置窗口滚动区域（启用滚动条）
    ; 计算内容区域的最大高度（假设内容可能超出可视区域）
    MaxContentHeight := ContentHeight * 3  ; 内容可能超出3倍高度
    SetWindowScrollInfo(ConfigGUI.Hwnd, ContentWidth, MaxContentHeight, ContentWidth, ContentHeight)
    
    ; 添加滚动消息处理（使用全局 OnMessage 函数）
    OnMessage(0x115, ConfigGUI_OnScroll)  ; WM_VSCROLL
    OnMessage(0x114, ConfigGUI_OnScroll)  ; WM_HSCROLL
    
    ; 确保窗口在最上层并激活
    WinSetAlwaysOnTop(1, ConfigGUI.Hwnd)
    WinActivate(ConfigGUI.Hwnd)
    
    ; 启用配置面板的滚轮热键
    EnableConfigScroll()
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
        BtnWidth := 80
        BtnSpacing := 10
        BtnStartX := Width - (BtnWidth * 5 + BtnSpacing * 4) - 20  ; 5个按钮，4个间距，右边距20
        
        ; 更新所有底部按钮的位置
        ExportBtn := GuiObj["ExportBtn"]
        if (ExportBtn) {
            ExportBtn.Move(BtnStartX, ButtonAreaY + 10)
        }
        ImportBtn := GuiObj["ImportBtn"]
        if (ImportBtn) {
            ImportBtn.Move(BtnStartX + BtnWidth + BtnSpacing, ButtonAreaY + 10)
        }
        ResetBtn := GuiObj["ResetBtn"]
        if (ResetBtn) {
            ResetBtn.Move(BtnStartX + (BtnWidth + BtnSpacing) * 2, ButtonAreaY + 10)
        }
        SaveBtn := GuiObj["SaveBtn"]
        if (SaveBtn) {
            SaveBtn.Move(BtnStartX + (BtnWidth + BtnSpacing) * 3, ButtonAreaY + 10)
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
    global GuiID_ConfigGUI
    ; 禁用滚动热键
    DisableConfigScroll()
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
            if (RadioBtn.Value = 1) {
                NewScreenIndex := Index
                break
            }
        }
    }
    if (NewScreenIndex < 1) {
        NewScreenIndex := 1
    }
    
    ; 获取语言设置
    NewLanguage := (LangChinese && LangChinese.Value) ? "zh" : "en"
    
    ; 解析高级设置中的屏幕索引
    NewConfigPanelScreenIndex := 1
    if (ConfigPanelScreenRadio && ConfigPanelScreenRadio.Length > 0) {
        for Index, RadioBtn in ConfigPanelScreenRadio {
            if (RadioBtn.Value = 1) {
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
            if (RadioBtn.Value = 1) {
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
            if (RadioBtn.Value = 1) {
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
            if (RadioBtn.Value = 1) {
                NewCursorPanelScreenIndex := Index
                break
            }
        }
    }
    if (NewCursorPanelScreenIndex < 1) {
        NewCursorPanelScreenIndex := 1
    }
    
    ; 读取搜索标签配置（从复选框读取）
    global VoiceSearchEnabledCategories
    if (GuiID_ConfigGUI) {
        try {
            ConfigGUI := GuiFromHwnd(GuiID_ConfigGUI)
            if (ConfigGUI) {
                AllCategoryKeys := ["ai", "academic", "baidu", "image", "audio", "video", "book", "price", "medical", "cloud"]
                VoiceSearchEnabledCategories := []
                for Index, CategoryKey in AllCategoryKeys {
                    try {
                        Checkbox := ConfigGUI["SearchCategoryCheckbox" . CategoryKey]
                        if (Checkbox && IsObject(Checkbox) && Checkbox.Value = 1) {
                            VoiceSearchEnabledCategories.Push(CategoryKey)
                        }
                    } catch {
                        ; 忽略错误
                    }
                }
                ; 确保至少有一个标签启用
                if (VoiceSearchEnabledCategories.Length = 0) {
                    VoiceSearchEnabledCategories := ["ai"]
                }
            }
        } catch {
            ; 如果读取失败，使用默认值
            if (!IsSet(VoiceSearchEnabledCategories) || !IsObject(VoiceSearchEnabledCategories)) {
                VoiceSearchEnabledCategories := ["ai", "academic", "baidu", "image", "audio", "video", "book", "price", "medical", "cloud"]
            }
        }
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
                ; 遍历所有可能的单选按钮，找到值为1的那个
                RadioGroupName := "QuickActionType" . Index
                for TypeIndex, ActionType in ActionTypes {
                    RadioCtrlName := RadioGroupName . "_" . TypeIndex
                    RadioCtrl := ConfigGUI[RadioCtrlName]
                    if (RadioCtrl && RadioCtrl.Value = 1) {
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
    if (IsSet(ThemeLightRadio) && ThemeLightRadio && IsObject(ThemeLightRadio) && ThemeLightRadio.Value = 1) {
        NewThemeMode := "light"
    } else if (IsSet(ThemeDarkRadio) && ThemeDarkRadio && IsObject(ThemeDarkRadio) && ThemeDarkRadio.Value = 1) {
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
    global CapsLockHoldTimeSeconds := (CapsLockHoldTimeEdit && CapsLockHoldTimeEdit.Value != "") ? Float(CapsLockHoldTimeEdit.Value) : 0.5
    global Prompt_Explain := PromptExplainEdit ? PromptExplainEdit.Value : ""
    global Prompt_Refactor := PromptRefactorEdit ? PromptRefactorEdit.Value : ""
    global Prompt_Optimize := PromptOptimizeEdit ? PromptOptimizeEdit.Value : ""
    global PanelScreenIndex := NewScreenIndex
    global Language := NewLanguage
    global ConfigPanelScreenIndex := NewConfigPanelScreenIndex
    global MsgBoxScreenIndex := NewMsgBoxScreenIndex
    global VoiceInputScreenIndex := NewVoiceInputScreenIndex
    global CursorPanelScreenIndex := NewCursorPanelScreenIndex
    
    ; 保存到配置文件
    IniWrite(CursorPath, ConfigFile, "Settings", "CursorPath")
    IniWrite(AISleepTime, ConfigFile, "Settings", "AISleepTime")
    IniWrite(CapsLockHoldTimeSeconds, ConfigFile, "Settings", "CapsLockHoldTimeSeconds")
    IniWrite(Prompt_Explain, ConfigFile, "Settings", "Prompt_Explain")
    IniWrite(Prompt_Refactor, ConfigFile, "Settings", "Prompt_Refactor")
    IniWrite(Prompt_Optimize, ConfigFile, "Settings", "Prompt_Optimize")
    IniWrite(PanelScreenIndex, ConfigFile, "Panel", "ScreenIndex")
    IniWrite(Language, ConfigFile, "Settings", "Language")
    IniWrite(ThemeMode, ConfigFile, "Settings", "ThemeMode")
    
    ; 主题已更改，需要重新创建所有面板以应用新主题
    ; 注意：这里不立即重新创建，因为用户可能还在查看配置面板
    ; 主题会在下次打开面板时自动应用
    
    global AutoLoadSelectedText
    IniWrite(AutoLoadSelectedText ? "1" : "0", ConfigFile, "Settings", "AutoLoadSelectedText")
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
    
    ; 保存启用的搜索标签配置
    global VoiceSearchEnabledCategories
    if (IsSet(VoiceSearchEnabledCategories) && IsObject(VoiceSearchEnabledCategories) && VoiceSearchEnabledCategories.Length > 0) {
        EnabledCategoriesStr := ""
        for Index, Category in VoiceSearchEnabledCategories {
            if (Index > 1) {
                EnabledCategoriesStr .= ","
            }
            EnabledCategoriesStr .= Category
        }
        IniWrite(EnabledCategoriesStr, ConfigFile, "Settings", "VoiceSearchEnabledCategories")
    } else {
        ; 如果没有启用任何标签，使用默认值
        DefaultEnabledCategories := "ai,academic,baidu,image,audio,video,book,price,medical,cloud"
        IniWrite(DefaultEnabledCategories, ConfigFile, "Settings", "VoiceSearchEnabledCategories")
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

; 显示保存成功提示（辅助函数）
ShowSaveSuccessTip(*) {
    ; 创建临时GUI确保消息框置顶
    TempGui := Gui("+AlwaysOnTop -Caption +ToolWindow")
    TempGui.Show("Hide")
    MsgBox(GetText("config_saved"), GetText("tip"), "Iconi T1")
    try TempGui.Destroy()
}

; 显示导入成功提示（辅助函数）
ShowImportSuccessTip(*) {
    ; 创建临时GUI确保消息框置顶
    TempGui := Gui("+AlwaysOnTop -Caption +ToolWindow")
    TempGui.Show("Hide")
    MsgBox(GetText("import_success"), GetText("tip"), "Iconi")
    try TempGui.Destroy()
}

; 保存配置并关闭
SaveConfigAndClose(*) {
    global GuiID_ConfigGUI
    
    if (SaveConfig()) {
        ; 先关闭配置面板
        CloseConfigGUI()
        
        ; 显示成功提示（确保在最前方）
        ; 使用 SetTimer 确保消息框在窗口关闭后显示
        SetTimer(ShowSaveSuccessTip, -100)
    }
}

; ===================== 清理函数 =====================
CleanUp() {
    global GuiID_CursorPanel
    
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
    
    ; 【关键修复】检查是否在保护期内（标签切换期间）
    ; 如果 CapsLockCopyEndTime 被设置为未来时间，说明是在标签切换的保护期内，不执行复制
    ; 这是最优先的检查，确保在标签切换期间不会触发复制
    if (CapsLockCopyEndTime > A_TickCount) {
        ; 在保护期内，直接返回，不执行任何复制操作
        return
    }
    
    ; 【关键修复】如果 CapsLockCopyInProgress 为 true 且 CapsLock 为 false，说明是在标签切换期间，不执行复制
    ; 这样可以防止点击 CapsLock+C 标签时触发复制操作
    if (CapsLockCopyInProgress && !CapsLock) {
        ; 在标签切换期间，直接返回，不执行任何复制操作
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
            
            ; 【环节6】如果剪贴板面板正在显示，刷新列表
            ; 使用延迟刷新，确保数据已完全更新
            global GuiID_ClipboardManager
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
    global CapsLockCopyInProgress, OldCapsLockCopyInProgress, CapsLockCopyEndTime
    if (IsSet(OldCapsLockCopyInProgress)) {
        CapsLockCopyInProgress := OldCapsLockCopyInProgress
    } else {
        CapsLockCopyInProgress := false
    }
    ; 【关键修复】必须重置 CapsLockCopyEndTime，否则会一直阻止 CapsLock+C
    CapsLockCopyEndTime := 0
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
    
    ; 分隔线
    GuiID_ClipboardManager.Add("Text", "x0 y40 w600 h1 Background" . UI_Colors.Border, "")
    
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
    global ClipboardClearAllBtn
    ClipboardClearAllBtn := CreateFlatBtn(GuiID_ClipboardManager, GetText("clear_all"), 320, 48, 100, 30, ClearAllClipboard)
    
    ; 统计信息
    CountText := GuiID_ClipboardManager.Add("Text", "x430 y53 w150 h22 Background" . UI_Colors.Sidebar . " c" . UI_Colors.TextDim . " vClipboardCountText", FormatText("total_items", "0"))
    CountText.SetFont("s10", "Segoe UI")
    
    ; ========== 列表区域 ==========
    ; 创建两个独立的ListBox容器
    ; Ctrl+C 列表容器
    ListBoxCtrlC := GuiID_ClipboardManager.Add("ListBox", "x20 y100 w560 h320 vClipboardListBoxCtrlC Background" . UI_Colors.InputBg . " c" . UI_Colors.Text . " -E0x200")
    ListBoxCtrlC.SetFont("s10", "Consolas")
    ListBoxCtrlC.OnEvent("Change", OnClipboardListBoxChange)
    ListBoxCtrlC.OnEvent("DoubleClick", CopySelectedItem)
    
    ; CapsLock+C 列表容器
    ListBoxCapsLockC := GuiID_ClipboardManager.Add("ListBox", "x20 y100 w560 h320 vClipboardListBoxCapsLockC Background" . UI_Colors.InputBg . " c" . UI_Colors.Text . " -E0x200")
    ListBoxCapsLockC.SetFont("s10", "Consolas")
    ListBoxCapsLockC.OnEvent("Change", OnClipboardListBoxChange)
    ListBoxCapsLockC.OnEvent("DoubleClick", CopySelectedItem)
    
    ; 根据当前Tab决定显示哪个ListBox
    if (ClipboardCurrentTab = "CtrlC") {
        ListBoxCtrlC.Visible := true
        ListBoxCapsLockC.Visible := false
    } else {
        ListBoxCtrlC.Visible := false
        ListBoxCapsLockC.Visible := true
    }
    
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
    global ClipboardListBox, ClipboardListBoxCtrlC, ClipboardListBoxCapsLockC, ClipboardCountText, ClipboardCtrlCTab, ClipboardCapsLockCTab
    ClipboardListBoxCtrlC := ListBoxCtrlC
    ClipboardListBoxCapsLockC := ListBoxCapsLockC
    ; 设置当前激活的ListBox（兼容旧代码）
    ClipboardListBox := (ClipboardCurrentTab = "CtrlC") ? ListBoxCtrlC : ListBoxCapsLockC
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

; CapsLock+C 标签点击处理函数
SwitchClipboardTabCapsLockC(*) {
    ; 直接调用切换函数
    SwitchClipboardTab("CapsLockC")
}

; 切换剪贴板 Tab
SwitchClipboardTab(TabName) {
    global ClipboardCurrentTab, ClipboardCtrlCTab, ClipboardCapsLockCTab, UI_Colors
    global ClipboardListBox, ClipboardListBoxCtrlC, ClipboardListBoxCapsLockC, ClipboardCountText, GuiID_ClipboardManager
    
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
            if (!ClipboardListBoxCtrlC || !IsObject(ClipboardListBoxCtrlC)) {
                try {
                    ClipboardListBoxCtrlC := ClipboardGUI["ClipboardListBoxCtrlC"]
                } catch {
                    ; 忽略错误
                }
            }
            if (!ClipboardListBoxCapsLockC || !IsObject(ClipboardListBoxCapsLockC)) {
                try {
                    ClipboardListBoxCapsLockC := ClipboardGUI["ClipboardListBoxCapsLockC"]
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
    
    ; 切换ListBox的显示/隐藏
    try {
        if (ClipboardListBoxCtrlC && IsObject(ClipboardListBoxCtrlC) && ClipboardListBoxCapsLockC && IsObject(ClipboardListBoxCapsLockC)) {
            if (TabName = "CtrlC") {
                ClipboardListBoxCtrlC.Visible := true
                ClipboardListBoxCapsLockC.Visible := false
                ; 更新当前激活的ListBox引用（兼容旧代码）
                ClipboardListBox := ClipboardListBoxCtrlC
            } else {
                ClipboardListBoxCtrlC.Visible := false
                ClipboardListBoxCapsLockC.Visible := true
                ; 更新当前激活的ListBox引用（兼容旧代码）
                ClipboardListBox := ClipboardListBoxCapsLockC
            }
        }
    } catch {
        ; 忽略错误，继续执行
    }
    
    ; 更新 Tab 样式
    try {
        ; 如果控件引用丢失，尝试从GUI重新获取
        if ((!ClipboardCtrlCTab || !IsObject(ClipboardCtrlCTab) || !ClipboardCapsLockCTab || !IsObject(ClipboardCapsLockCTab)) && ClipboardGUI) {
            try {
                if (!ClipboardCtrlCTab || !IsObject(ClipboardCtrlCTab)) {
                    TempCtrlCTab := ClipboardGUI["CtrlCTab"]
                    if (TempCtrlCTab && IsObject(TempCtrlCTab)) {
                        ClipboardCtrlCTab := TempCtrlCTab
                    }
                }
                
                if (!ClipboardCapsLockCTab || !IsObject(ClipboardCapsLockCTab)) {
                    TempCapsLockCTab := ClipboardGUI["CapsLockCTab"]
                    if (TempCapsLockCTab && IsObject(TempCapsLockCTab)) {
                        ClipboardCapsLockCTab := TempCapsLockCTab
                    }
                }
            } catch {
                ; 忽略错误，继续执行
            }
        }
        
        ; 更新两个Tab的背景色（确保两个都更新）
        if (ClipboardCtrlCTab && IsObject(ClipboardCtrlCTab)) {
            ActiveTabColor := (TabName = "CtrlC") ? UI_Colors.TabActive : UI_Colors.Sidebar
            ClipboardCtrlCTab.BackColor := ActiveTabColor
            ; 【关键修复】同时更新NormalColor，确保悬停逻辑 CheckMouseLeave 恢复时使用正确的背景色
            ClipboardCtrlCTab.NormalColor := ActiveTabColor
        }
        
        if (ClipboardCapsLockCTab && IsObject(ClipboardCapsLockCTab)) {
            ActiveTabColor := (TabName = "CapsLockC") ? UI_Colors.TabActive : UI_Colors.Sidebar
            ClipboardCapsLockCTab.BackColor := ActiveTabColor
            ; 【关键修复】同时更新NormalColor，确保悬停逻辑 CheckMouseLeave 恢复时使用正确的背景色
            ClipboardCapsLockCTab.NormalColor := ActiveTabColor
        }
        
        ; 强制刷新UI，确保背景色变化立即显示
        if (GuiID_ClipboardManager && IsObject(GuiID_ClipboardManager)) {
            WinRedraw(GuiID_ClipboardManager.Hwnd)
        }
    } catch {
        ; 忽略样式更新错误，继续执行
    }
    
    ; 刷新列表（无论样式更新是否成功，都要刷新列表）
    RefreshClipboardList()
    
    ; 设置焦点到当前激活的ListBox，确保焦点即时切换
    try {
        if (GuiID_ClipboardManager && IsObject(GuiID_ClipboardManager) && GuiID_ClipboardManager.HasProp("Hwnd")) {
            ; 使用SetTimer延迟设置焦点，确保UI更新完成后再设置
            SetTimer(SetClipboardListBoxFocus, -50)
        }
    } catch {
        ; 忽略错误
    }
}

; 设置剪贴板ListBox焦点的辅助函数
SetClipboardListBoxFocus(*) {
    global GuiID_ClipboardManager, ClipboardCurrentTab, ClipboardListBoxCtrlC, ClipboardListBoxCapsLockC
    
    try {
        if (!GuiID_ClipboardManager || !IsObject(GuiID_ClipboardManager)) {
            return
        }
        
        CurrentListBox := ""
        if (ClipboardCurrentTab = "CtrlC") {
            CurrentListBox := ClipboardListBoxCtrlC
        } else {
            CurrentListBox := ClipboardListBoxCapsLockC
        }
        
        if (CurrentListBox && IsObject(CurrentListBox) && CurrentListBox.HasProp("Hwnd")) {
            ; 使用ControlFocus确保焦点真正切换
            try {
                ControlFocus(CurrentListBox.Hwnd, "ahk_id " . GuiID_ClipboardManager.Hwnd)
            } catch {
                ; 如果ControlFocus失败，尝试使用Focus方法
                try {
                    CurrentListBox.Focus()
                } catch {
                    ; 忽略焦点设置失败
                }
            }
        }
    } catch {
        ; 忽略错误
    }
}

; 延迟刷新剪贴板列表（用于 OnClipboardChange 等场景）
RefreshClipboardListDelayed(*) {
    RefreshClipboardList()
}

; 刷新剪贴板列表
RefreshClipboardList() {
    global ClipboardHistory_CtrlC, ClipboardHistory_CapsLockC, ClipboardCurrentTab
    global ClipboardListBox, ClipboardListBoxCtrlC, ClipboardListBoxCapsLockC, ClipboardCountText, GuiID_ClipboardManager
    global LastSelectedIndexCtrlC, LastSelectedIndexCapsLockC
    
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
    
    ; 根据当前Tab选择正确的ListBox
    CurrentListBox := ""
    if (ClipboardCurrentTab = "CtrlC") {
        CurrentListBox := ClipboardListBoxCtrlC
    } else {
        CurrentListBox := ClipboardListBoxCapsLockC
    }
    
    ; 如果控件引用丢失，尝试获取GUI对象并重新获取控件
    if (!CurrentListBox || !IsObject(CurrentListBox) || !ClipboardCountText || !IsObject(ClipboardCountText)) {
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
                if (!ClipboardListBoxCtrlC || !IsObject(ClipboardListBoxCtrlC)) {
                    try {
                        ClipboardListBoxCtrlC := ClipboardGUI["ClipboardListBoxCtrlC"]
                    } catch {
                        ; 忽略错误
                    }
                }
                if (!ClipboardListBoxCapsLockC || !IsObject(ClipboardListBoxCapsLockC)) {
                    try {
                        ClipboardListBoxCapsLockC := ClipboardGUI["ClipboardListBoxCapsLockC"]
                    } catch {
                        ; 忽略错误
                    }
                }
                ; 重新选择当前ListBox
                if (ClipboardCurrentTab = "CtrlC") {
                    CurrentListBox := ClipboardListBoxCtrlC
                } else {
                    CurrentListBox := ClipboardListBoxCapsLockC
                }
                ; 更新兼容引用
                ClipboardListBox := CurrentListBox
                
                if (!ClipboardCountText || !IsObject(ClipboardCountText)) {
                    try {
                        ClipboardCountText := ClipboardGUI["ClipboardCountText"]
                    } catch {
                        ; 如果无法获取，返回
                        return
                    }
                }
            } else {
                ; 如果无法获取GUI对象，返回
                return
            }
        } catch {
            ; 如果出错，返回
            return
        }
    }
    
    ; 检查控件是否存在
    if (!CurrentListBox || !IsObject(CurrentListBox) || !ClipboardCountText) {
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
        
        ; 【关键修复】确保 ClipboardCurrentTab 有默认值，但不覆盖已设置的值
        ; 只在未设置或为空时才设置默认值，避免覆盖正确的标签值
        if (!IsSet(ClipboardCurrentTab) || ClipboardCurrentTab = "") {
            ClipboardCurrentTab := "CtrlC"
        }
        
        ; 【关键修复】使用局部变量保存当前标签值，避免在函数执行过程中被修改
        CurrentTabName := ClipboardCurrentTab
        
        ; 根据当前 Tab 选择对应的历史记录（直接使用全局变量，确保引用正确）
        ; 【关键修复】直接使用全局变量引用，不要创建局部副本
        CurrentHistory := []
        HistoryLength := 0
        
        ; 【关键修复】使用保存的 CurrentTabName，确保使用正确的标签值
        if (CurrentTabName = "CtrlC") {
            ; 直接使用全局变量 ClipboardHistory_CtrlC
            if (IsSet(ClipboardHistory_CtrlC) && IsObject(ClipboardHistory_CtrlC)) {
                ; 【关键】直接使用全局数组，不创建副本
                CurrentHistory := ClipboardHistory_CtrlC
                HistoryLength := ClipboardHistory_CtrlC.Length
            } else {
                CurrentHistory := []
                HistoryLength := 0
            }
        } else if (CurrentTabName = "CapsLockC") {
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
                    CurrentList := CurrentListBox.List
                    if (!CurrentList || CurrentList.Length = 0) {
                        break
                    }
                    ; 从后往前删除，避免索引变化
                    CurrentListBox.Delete(CurrentList.Length)
                } catch {
                    ; 如果删除失败，尝试其他方法
                    break
                }
            }
            
            ; 方法2：确保列表已完全清空（双重检查）
            Loop 100 {  ; 最多尝试100次，防止无限循环
                try {
                    CurrentList := CurrentListBox.List
                    if (!CurrentList || CurrentList.Length = 0) {
                        break
                    }
                    ; 删除第一项
                    CurrentListBox.Delete(1)
                } catch {
                    break
                }
            }
            
            ; 方法3：最终检查，确保列表为空
            try {
                FinalList := CurrentListBox.List
                if (FinalList && FinalList.Length > 0) {
                    ; 如果还有项，强制清空（使用循环删除）
                    Loop FinalList.Length {
                        try {
                            CurrentListBox.Delete(1)
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
        
        ; 保存刷新前的选中索引（根据当前Tab选择对应的索引）
        PreviousSelectedIndex := 0
        if (ClipboardCurrentTab = "CtrlC") {
            if (IsSet(LastSelectedIndexCtrlC) && LastSelectedIndexCtrlC > 0) {
                PreviousSelectedIndex := LastSelectedIndexCtrlC
            }
        } else {
            if (IsSet(LastSelectedIndexCapsLockC) && LastSelectedIndexCapsLockC > 0) {
                PreviousSelectedIndex := LastSelectedIndexCapsLockC
            }
        }
        
        ; 批量添加项目
        if (Items.Length > 0) {
            try {
                CurrentListBox.Add(Items)
            } catch {
                ; 如果批量添加失败，尝试逐个添加
                for Index, Item in Items {
                    try {
                        CurrentListBox.Add(Item)
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
                CurrentListBox.Value := PreviousSelectedIndex
                ; 根据当前Tab保存选中索引
                if (ClipboardCurrentTab = "CtrlC") {
                    LastSelectedIndexCtrlC := PreviousSelectedIndex
                } else {
                    LastSelectedIndexCapsLockC := PreviousSelectedIndex
                }
            } catch {
                ; 如果恢复失败，清除保存的索引
                if (ClipboardCurrentTab = "CtrlC") {
                    LastSelectedIndexCtrlC := 0
                } else {
                    LastSelectedIndexCapsLockC := 0
                }
            }
        } else {
            ; 如果没有有效的选中项，清除保存的索引
            if (ClipboardCurrentTab = "CtrlC") {
                LastSelectedIndexCtrlC := 0
            } else {
                LastSelectedIndexCapsLockC := 0
            }
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
    global ClipboardListBox, ClipboardCountText, ClipboardClearAllBtn, UI_Colors, GuiID_ClipboardManager
    
    ; 添加点击时的视觉反馈
    OriginalColor := ""
    if (ClipboardClearAllBtn && IsObject(ClipboardClearAllBtn)) {
        try {
            ; 保存原始颜色
            OriginalColor := ClipboardClearAllBtn.HasProp("NormalColor") ? ClipboardClearAllBtn.NormalColor : UI_Colors.BtnBg
            ; 临时改变背景色为点击状态（稍微暗一点）
            ClickColor := "444444"  ; 点击时的深色
            ClipboardClearAllBtn.BackColor := ClickColor
            ; 强制刷新UI
            try {
                if (GuiID_ClipboardManager && IsObject(GuiID_ClipboardManager) && GuiID_ClipboardManager.HasProp("Hwnd")) {
                    WinRedraw(GuiID_ClipboardManager.Hwnd)
                }
            } catch {
                ; 忽略刷新错误
            }
        } catch {
            ; 忽略视觉反馈错误，继续执行功能
        }
    }
    
    ; 确认对话框
    ; 【置顶修复】设置 +OwnDialogs 确保对话框在剪贴板管理器最前方且模态
    if (GuiID_ClipboardManager && IsObject(GuiID_ClipboardManager)) {
        GuiID_ClipboardManager.Opt("+OwnDialogs")
    }
    Result := MsgBox(GetText("confirm_clear"), GetText("confirm"), "YesNo Icon?")
    
    ; 恢复按钮颜色（在确认对话框关闭后）
    if (ClipboardClearAllBtn && IsObject(ClipboardClearAllBtn)) {
        try {
            ; 恢复到 NormalColor 属性记录的颜色
            RestoreColor := ClipboardClearAllBtn.HasProp("NormalColor") ? ClipboardClearAllBtn.NormalColor : UI_Colors.BtnBg
            ClipboardClearAllBtn.BackColor := RestoreColor
            if (GuiID_ClipboardManager && IsObject(GuiID_ClipboardManager)) {
                WinRedraw(GuiID_ClipboardManager.Hwnd)
            }
        } catch {
            ; 忽略恢复颜色错误
        }
    }
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
    global ClipboardListBox, ClipboardCurrentTab, LastSelectedIndexCtrlC, LastSelectedIndexCapsLockC
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
            ; 根据当前Tab保存最后选中的索引，用于刷新后恢复
            if (SelectedIndex > 0) {
                if (ClipboardCurrentTab = "CtrlC") {
                    LastSelectedIndexCtrlC := SelectedIndex
                } else {
                    LastSelectedIndexCapsLockC := SelectedIndex
                }
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
        
        ; 如果Value为0，尝试使用最后保存的选中索引（根据当前Tab选择对应的索引）
        if (SelectedIndex <= 0) {
            global ClipboardCurrentTab, LastSelectedIndexCtrlC, LastSelectedIndexCapsLockC
            LastSelectedIndex := 0
            if (ClipboardCurrentTab = "CtrlC") {
                if (IsSet(LastSelectedIndexCtrlC) && LastSelectedIndexCtrlC > 0) {
                    LastSelectedIndex := LastSelectedIndexCtrlC
                }
            } else {
                if (IsSet(LastSelectedIndexCapsLockC) && LastSelectedIndexCapsLockC > 0) {
                    LastSelectedIndex := LastSelectedIndexCapsLockC
                }
            }
            if (LastSelectedIndex > 0) {
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
    global ClipboardListBox, ClipboardListBoxCtrlC, ClipboardListBoxCapsLockC, GuiID_ClipboardManager
    
    if (!GuiID_ClipboardManager) {
        return
    }
    
    ; 根据当前Tab选择正确的ListBox
    CurrentListBox := ""
    if (ClipboardCurrentTab = "CtrlC") {
        CurrentListBox := ClipboardListBoxCtrlC
    } else {
        CurrentListBox := ClipboardListBoxCapsLockC
    }
    
    ; 如果控件引用丢失，尝试重新获取
    if (!CurrentListBox || !IsObject(CurrentListBox)) {
        try {
            ClipboardGUI := GuiFromHwnd(GuiID_ClipboardManager)
            if (ClipboardGUI) {
                if (ClipboardCurrentTab = "CtrlC") {
                    CurrentListBox := ClipboardGUI["ClipboardListBoxCtrlC"]
                    ClipboardListBoxCtrlC := CurrentListBox
                } else {
                    CurrentListBox := ClipboardGUI["ClipboardListBoxCapsLockC"]
                    ClipboardListBoxCapsLockC := CurrentListBox
                }
                ; 更新兼容引用
                ClipboardListBox := CurrentListBox
            }
        } catch {
            return
        }
    }
    
    if (!CurrentListBox || !IsObject(CurrentListBox)) {
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
        SelectedIndex := GetSelectedIndex(CurrentListBox)
        
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
    global ClipboardListBox, ClipboardListBoxCtrlC, ClipboardListBoxCapsLockC, GuiID_ClipboardManager
    global LastSelectedIndexCtrlC, LastSelectedIndexCapsLockC
    
    if (!GuiID_ClipboardManager) {
        return
    }
    
    ; 确保全局变量已初始化
    if (!IsSet(ClipboardCurrentTab) || ClipboardCurrentTab = "") {
        global ClipboardCurrentTab := "CtrlC"
    }
    
    try {
        ; 确保历史记录数组已初始化
        if (!IsSet(ClipboardHistory_CtrlC) || !IsObject(ClipboardHistory_CtrlC)) {
            global ClipboardHistory_CtrlC := []
        }
        if (!IsSet(ClipboardHistory_CapsLockC) || !IsObject(ClipboardHistory_CapsLockC)) {
            global ClipboardHistory_CapsLockC := []
        }
        
        ; 根据当前Tab选择正确的ListBox
        CurrentListBox := ""
        if (ClipboardCurrentTab = "CtrlC") {
            if (ClipboardListBoxCtrlC && IsObject(ClipboardListBoxCtrlC)) {
                CurrentListBox := ClipboardListBoxCtrlC
            } else {
                try {
                    ClipboardGUI := GuiFromHwnd(GuiID_ClipboardManager)
                    if (ClipboardGUI) {
                        CurrentListBox := ClipboardGUI["ClipboardListBoxCtrlC"]
                        ClipboardListBoxCtrlC := CurrentListBox
                    }
                } catch {
                    CurrentListBox := ClipboardListBox
                }
            }
        } else {
            if (ClipboardListBoxCapsLockC && IsObject(ClipboardListBoxCapsLockC)) {
                CurrentListBox := ClipboardListBoxCapsLockC
            } else {
                try {
                    ClipboardGUI := GuiFromHwnd(GuiID_ClipboardManager)
                    if (ClipboardGUI) {
                        CurrentListBox := ClipboardGUI["ClipboardListBoxCapsLockC"]
                        ClipboardListBoxCapsLockC := CurrentListBox
                    }
                } catch {
                    CurrentListBox := ClipboardListBox
                }
            }
        }
        
        ; 如果无法获取，使用兼容引用
        if (!CurrentListBox || !IsObject(CurrentListBox)) {
            CurrentListBox := ClipboardListBox
        }
        
        ; 获取选中项的索引
        SelectedIndex := GetSelectedIndex(CurrentListBox)
        
        if (SelectedIndex > 0) {
            if (ClipboardCurrentTab = "CtrlC") {
                if (IsSet(ClipboardHistory_CtrlC) && IsObject(ClipboardHistory_CtrlC) && SelectedIndex <= ClipboardHistory_CtrlC.Length) {
                    ; 直接操作全局数组
                    ClipboardHistory_CtrlC.RemoveAt(SelectedIndex)
                    ; 清除保存的选中索引，防止刷新后选中错误的项
                    LastSelectedIndexCtrlC := 0
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
                    ; 清除保存的选中索引，防止刷新后选中错误的项
                    LastSelectedIndexCapsLockC := 0
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
    global ClipboardListBox, ClipboardListBoxCtrlC, ClipboardListBoxCapsLockC, CursorPath, AISleepTime, GuiID_ClipboardManager
    
    if (!GuiID_ClipboardManager) {
        return
    }
    
    ; 根据当前Tab选择正确的ListBox
    CurrentListBox := ""
    if (ClipboardCurrentTab = "CtrlC") {
        CurrentListBox := ClipboardListBoxCtrlC
    } else {
        CurrentListBox := ClipboardListBoxCapsLockC
    }
    
    ; 如果控件引用丢失，尝试重新获取
    if (!CurrentListBox || !IsObject(CurrentListBox)) {
        try {
            ClipboardGUI := GuiFromHwnd(GuiID_ClipboardManager)
            if (ClipboardGUI) {
                if (ClipboardCurrentTab = "CtrlC") {
                    CurrentListBox := ClipboardGUI["ClipboardListBoxCtrlC"]
                    ClipboardListBoxCtrlC := CurrentListBox
                } else {
                    CurrentListBox := ClipboardGUI["ClipboardListBoxCapsLockC"]
                    ClipboardListBoxCapsLockC := CurrentListBox
                }
                ; 更新兼容引用
                ClipboardListBox := CurrentListBox
            }
        } catch {
            return
        }
    }
    
    if (!CurrentListBox || !IsObject(CurrentListBox)) {
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
        SelectedIndex := GetSelectedIndex(CurrentListBox)
        
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
    global HotkeyESC, HotkeyC, HotkeyV, HotkeyX, HotkeyE, HotkeyR, HotkeyO, HotkeyQ, HotkeyZ, HotkeyF
    global CapsLock2, PanelVisible, VoiceInputActive, CapsLock, VoiceSearchActive
    global QuickActionButtons
    
    ; 将按键转换为小写进行比较（ESC特殊处理）
    KeyLower := StrLower(PressedKey)
    ConfigKey := ""
    
    ; 首先检查是否匹配快捷操作按钮配置的快捷键
    if (PanelVisible && QuickActionButtons.Length > 0) {
        for Index, Button in QuickActionButtons {
            if (StrLower(Button.Hotkey) = KeyLower) {
                ; 匹配到快捷操作按钮
                CapsLock2 := false
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
    }
    
    ; 如果按键匹配配置的快捷键，执行操作
    if (KeyLower = ConfigKey || (ActionType = "ESC" && (PressedKey = "Esc" || KeyLower = "esc"))) {
        ; 立即隐藏面板（所有快捷键操作都应该隐藏面板）
        if (PanelVisible) {
            HideCursorPanel()
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
                    if (CapsLock) {
                        CapsLock := false
                    }
                    StopVoiceInput()
                } else {
                    StartVoiceInput()
                }
            case "F":
                CapsLock2 := false
                global VoiceSearchPanelVisible, VoiceSearchActive
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
                    StartVoiceSearch()
                }
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

#HotIf

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
    global VoiceInputActive, VoiceInputContent, CursorPath, AISleepTime, VoiceInputMethod, PanelVisible
    
    if (VoiceInputActive) {
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
        
        ; 清空输入框，避免复制到旧内容
        Send("^a")
        Sleep(100)
        Send("{Delete}")
        Sleep(100)
        
        ; 自动检测输入法类型
        VoiceInputMethod := DetectInputMethod()
        
        ; 根据输入法类型使用不同的快捷键（不显示弹窗，动画界面会提供反馈）
        if (VoiceInputMethod = "baidu") {
            ; 百度输入法：Alt+Y 激活，F2 开始
            Send("!y")
            Sleep(500)
            Send("{F2}")
            Sleep(200)
        } else if (VoiceInputMethod = "xunfei") {
            ; 讯飞输入法：直接按 F6 开始语音输入（F6 也是结束键）
            ; 注意：讯飞输入法不需要先激活，直接按 F6 即可
            Send("{F6}")
            Sleep(800)  ; 给讯飞输入法更多时间启动语音识别
        } else {
            ; 默认尝试百度方案
            Send("!y")
            Sleep(500)
            Send("{F2}")
            Sleep(200)
        }
        
        VoiceInputActive := true
        VoiceInputContent := ""
        ShowVoiceInputAnimation()
        ; 不显示弹窗，动画界面已提供视觉反馈
    } catch as e {
        TrayTip(GetText("voice_input_failed") . ": " . e.Message, GetText("error"), "Iconx 2")
    }
}

; 结束语音输入
StopVoiceInput() {
    global VoiceInputActive, VoiceInputContent, VoiceInputMethod, CapsLock
    
    if (!VoiceInputActive) {
        return
    }
    
    try {
        ; 先确保CapsLock状态被重置，避免影响后续操作
        ; 如果CapsLock被按下，先释放它
        if (CapsLock) {
            CapsLock := false
        }
        
        ; 根据输入法类型使用不同的结束快捷键
        if (VoiceInputMethod = "baidu") {
            ; 百度输入法：F1 结束语音录入
            Send("{F1}")
            Sleep(800)  ; 增加等待时间，确保语音识别完成
            
            ; 获取语音输入内容
            OldClipboard := A_Clipboard
            ; 先选中输入框中的所有内容
            Send("^a")
            Sleep(200)  ; 增加等待时间，确保选中完成
            A_Clipboard := ""
            Send("^c")
            if ClipWait(1.5) {
                VoiceInputContent := A_Clipboard
            }
            A_Clipboard := OldClipboard
            
            ; 如果内容为空或太短，再尝试一次
            if (VoiceInputContent = "" || StrLen(VoiceInputContent) < 2) {
                Sleep(300)  ; 再等待一下
                Send("^a")
                Sleep(200)
                A_Clipboard := ""
                Send("^c")
                if ClipWait(1.5) {
                    VoiceInputContent := A_Clipboard
                }
                A_Clipboard := OldClipboard
            }
            
            ; 退出百度输入法语音模式（Alt+Y 关闭语音窗口）
            Send("!y")
            Sleep(300)
        } else if (VoiceInputMethod = "xunfei") {
            ; 讯飞输入法：F6 结束（与开始相同，按 F6 切换开始/结束）
            Send("{F6}")
            Sleep(1000)  ; 给讯飞输入法更多时间处理结束操作和识别结果
            
            ; 获取语音输入内容
            OldClipboard := A_Clipboard
            ; 先选中输入框中的所有内容
            Send("^a")
            Sleep(200)  ; 增加等待时间，确保选中完成
            A_Clipboard := ""
            Send("^c")
            if ClipWait(1.5) {
                VoiceInputContent := A_Clipboard
            }
            A_Clipboard := OldClipboard
            
            ; 如果内容为空或太短，再尝试一次
            if (VoiceInputContent = "" || StrLen(VoiceInputContent) < 2) {
                Sleep(300)  ; 再等待一下
                Send("^a")
                Sleep(200)
                A_Clipboard := ""
                Send("^c")
                if ClipWait(1.5) {
                    VoiceInputContent := A_Clipboard
                }
                A_Clipboard := OldClipboard
            }
        } else {
            ; 默认尝试百度方案
            Send("{F1}")
            Sleep(800)  ; 增加等待时间，确保语音识别完成
            
            ; 获取语音输入内容
            OldClipboard := A_Clipboard
            ; 先选中输入框中的所有内容
            Send("^a")
            Sleep(200)  ; 增加等待时间，确保选中完成
            A_Clipboard := ""
            Send("^c")
            if ClipWait(1.5) {
                VoiceInputContent := A_Clipboard
            }
            A_Clipboard := OldClipboard
            
            ; 如果内容为空或太短，再尝试一次
            if (VoiceInputContent = "" || StrLen(VoiceInputContent) < 2) {
                Sleep(300)  ; 再等待一下
                Send("^a")
                Sleep(200)
                A_Clipboard := ""
                Send("^c")
                if ClipWait(1.5) {
                    VoiceInputContent := A_Clipboard
                }
                A_Clipboard := OldClipboard
            }
            
            ; 退出百度输入法语音模式（Alt+Y 关闭语音窗口）
            Send("!y")
            Sleep(300)
        }
        
        VoiceInputActive := false
        HideVoiceInputAnimation()
        
        if (VoiceInputContent != "" && StrLen(VoiceInputContent) > 0) {
            ; 显示选择界面：发送到Cursor或搜索
            ShowVoiceInputActionSelection(VoiceInputContent)
        } else {
            ; 只在没有内容时显示提示
            TrayTip(GetText("voice_input_no_content"), GetText("tip"), "Iconi 2")
        }
        ; 不显示"正在结束"的提示，动画界面已关闭
    } catch as e {
        VoiceInputActive := false
        HideVoiceInputAnimation()
        TrayTip(GetText("voice_input_failed") . ": " . e.Message, GetText("error"), "Iconx 2")
    }
}

; 显示语音输入动画
ShowVoiceInputAnimation() {
    global GuiID_VoiceInput, VoiceInputActive, VoiceInputScreenIndex, UI_Colors
    
    if (GuiID_VoiceInput != 0) {
        try {
            GuiID_VoiceInput.Destroy()
        }
    }
    
    GuiID_VoiceInput := Gui("+AlwaysOnTop +ToolWindow -Caption -DPIScale")
    GuiID_VoiceInput.BackColor := UI_Colors.Background
    GuiID_VoiceInput.SetFont("s12 c" . UI_Colors.Text . " Bold", "Segoe UI")
    
    PanelWidth := 400
    PanelHeight := 150
    
    TitleText := GuiID_VoiceInput.Add("Text", "x0 y20 w400 h30 Center cFFFFFF", GetText("voice_input_active"))
    TitleText.SetFont("s16 Bold", "Segoe UI")
    global VoiceTitleText := TitleText
    
    HintText := GuiID_VoiceInput.Add("Text", "x0 y60 w400 h25 Center cCCCCCC", GetText("voice_input_hint"))
    HintText.SetFont("s11", "Segoe UI")
    global VoiceHintText := HintText
    
    AnimationText := GuiID_VoiceInput.Add("Text", "x0 y95 w400 h30 Center c00FF00", "● ● ●")
    AnimationText.SetFont("s14", "Segoe UI")
    global VoiceAnimationText := AnimationText
    
    SetTimer(UpdateVoiceAnimation, 500)
    
    ScreenInfo := GetScreenInfo(VoiceInputScreenIndex)
    Pos := GetPanelPosition(ScreenInfo, PanelWidth, PanelHeight, "center")
    
    GuiID_VoiceInput.Show("w" . PanelWidth . " h" . PanelHeight . " x" . Pos.X . " y" . Pos.Y . " NoActivate")
    WinSetAlwaysOnTop(1, GuiID_VoiceInput.Hwnd)
}

; 更新语音输入暂停状态
UpdateVoiceInputPausedState(IsPaused) {
    global VoiceTitleText, VoiceHintText, VoiceAnimationText, GuiID_VoiceInput
    
    try {
        if (!GuiID_VoiceInput || GuiID_VoiceInput = 0) {
            return
        }
        
        if (IsPaused) {
            ; 暂停状态：显示黄色和暂停提示
            if (VoiceTitleText) {
                VoiceTitleText.Text := "⏸️ 语音输入已暂停"
                VoiceTitleText.SetFont("s16 Bold cFFFF00", "Segoe UI")
            }
            if (VoiceHintText) {
                VoiceHintText.Text := "已暂停语音录入，释放 CapsLock 恢复"
                VoiceHintText.SetFont("s11 cFFFF00", "Segoe UI")
            }
            if (VoiceAnimationText) {
                VoiceAnimationText.Text := "⏸ ⏸ ⏸"
                VoiceAnimationText.SetFont("s14 cFFFF00", "Segoe UI")
            }
        } else {
            ; 正常状态：恢复绿色和正常提示
            if (VoiceTitleText) {
                VoiceTitleText.Text := GetText("voice_input_active")
                VoiceTitleText.SetFont("s16 Bold cFFFFFF", "Segoe UI")
            }
            if (VoiceHintText) {
                VoiceHintText.Text := GetText("voice_input_hint")
                VoiceHintText.SetFont("s11 cCCCCCC", "Segoe UI")
            }
            if (VoiceAnimationText) {
                VoiceAnimationText.Text := "● ● ●"
                VoiceAnimationText.SetFont("s14 c00FF00", "Segoe UI")
            }
        }
    } catch {
        ; 忽略错误
    }
}

; 更新语音输入动画
UpdateVoiceAnimation(*) {
    global VoiceInputActive, VoiceAnimationText, VoiceInputPaused
    
    if (!VoiceInputActive || !VoiceAnimationText || VoiceInputPaused) {
        ; 如果暂停，不更新动画
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
    } catch {
        SetTimer(, 0)
    }
}

; 隐藏语音输入动画
HideVoiceInputAnimation() {
    global GuiID_VoiceInput, VoiceAnimationText, VoiceTitleText, VoiceHintText, VoiceInputPaused
    
    ; 重置暂停状态
    VoiceInputPaused := false
    
    SetTimer(UpdateVoiceAnimation, 0)
    
    if (GuiID_VoiceInput != 0) {
        try {
            GuiID_VoiceInput.Destroy()
        }
        GuiID_VoiceInput := 0
    }
    VoiceAnimationText := 0
    VoiceTitleText := 0
    VoiceHintText := 0
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

; ===================== 语音搜索功能 =====================
; 辅助函数：检查数组是否包含某个值
ArrayContainsValue(Arr, Value) {
    for Index, Item in Arr {
        if (Item = Value) {
            return Index
        }
    }
    return 0
}

; 开始语音搜索（显示输入框界面）
StartVoiceSearch() {
    global VoiceSearchActive, VoiceSearchPanelVisible, PanelVisible
    
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
        if (Engine.Category = Category) {
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
                    TabObj.Btn.BackColor := TabBg
                    TabObj.Btn.Text := GetText("search_category_" . TabObj.Key)
                } catch {
                    ; 忽略更新样式时的错误
                }
            }
        }
        
        ; 【关键修复】立即刷新GUI，确保标签背景色更新立即显示
        try {
            if (GuiID_VoiceInput && IsObject(GuiID_VoiceInput) && GuiID_VoiceInput.HasProp("Hwnd")) {
                WinRedraw(GuiID_VoiceInput.Hwnd)
            }
        } catch {
            ; 忽略刷新错误
        }
        
        ; 设置焦点到第一个可见的搜索引擎按钮或输入框，确保焦点即时切换
        try {
            if (GuiID_VoiceInput && IsObject(GuiID_VoiceInput) && GuiID_VoiceInput.HasProp("Hwnd")) {
                ; 使用SetTimer延迟设置焦点，确保UI更新完成后再设置
                ; 注意：这里需要在创建新按钮之后调用，所以会在函数末尾再次调用
            }
        } catch {
            ; 忽略错误
        }
        
        ; 【关键修复】隐藏旧的搜索引擎按钮，而不是尝试销毁它们（AHK v2 不支持直接销毁控件）
        if (IsSet(VoiceSearchEngineButtons) && VoiceSearchEngineButtons.Length > 0) {
            for Index, BtnObj in VoiceSearchEngineButtons {
                if (IsObject(BtnObj)) {
                    ; 隐藏所有控件并移出可见区域，防止重叠和干扰
                    try {
                        if (BtnObj.Bg) {
                            BtnObj.Bg.Visible := false
                            BtnObj.Bg.Move(-1000, -1000)
                        }
                    } catch {
                    }
                    try {
                        if (BtnObj.Icon && IsObject(BtnObj.Icon)) {
                            BtnObj.Icon.Visible := false
                            BtnObj.Icon.Move(-1000, -1000)
                        }
                    } catch {
                    }
                    try {
                        if (BtnObj.Text) {
                            BtnObj.Text.Visible := false
                            BtnObj.Text.Move(-1000, -1000)
                        }
                    } catch {
                    }
                }
            }
        }
        VoiceSearchEngineButtons := []
        
        ; 第三步：立即刷新GUI，确保所有旧按钮从界面上完全消失
        try {
            WinRedraw(GuiID_VoiceInput.Hwnd)
        } catch {
        }
        
        ; 【关键】确保在创建新按钮之前，所有旧按钮都已完全清除
        ; 清空按钮数组，确保不会引用到旧按钮
        VoiceSearchEngineButtons := []
        
        ; 获取新分类的搜索引擎（只显示对应标签下的搜索引擎）
        try {
            SearchEngines := GetSortedSearchEngines(CategoryKey)
        } catch as e {
            ; 如果获取失败，显示错误并返回
            TrayTip("获取搜索引擎失败: " . e.Message, "错误", "Iconx 1")
            return
        }
        
        ; 如果没有搜索引擎，显示提示并返回（不创建任何按钮）
        if (!SearchEngines || SearchEngines.Length = 0) {
            ; 创建提示文本
            try {
                NoEngineText := GuiID_VoiceInput["NoEngineText"]
                if (NoEngineText) {
                    NoEngineText.Destroy()
                }
            } catch {
            }
            NoEngineText := GuiID_VoiceInput.Add("Text", "x20 y" . (VoiceSearchLabelEngineY + 30) . " w560 h30 Center c" . UI_Colors.TextDim . " vNoEngineText", "该分类暂无搜索引擎")
            NoEngineText.SetFont("s11", "Segoe UI")
            ; 刷新GUI，确保提示文本显示
            try {
                WinRedraw(GuiID_VoiceInput.Hwnd)
            } catch {
            }
            return
        } else {
            ; 如果有搜索引擎，移除提示文本（确保只显示搜索引擎按钮）
            try {
                NoEngineText := GuiID_VoiceInput["NoEngineText"]
                if (NoEngineText) {
                    NoEngineText.Destroy()
                }
            } catch {
            }
        }
        
        ; 【关键】重新创建搜索引擎按钮（只显示当前标签对应的搜索引擎，完全覆盖原先的列表）
        ; 计算按钮位置（从引擎标签下方开始）
        global VoiceSearchLabelEngineY
        LabelEngineY := 0
        ; 优先使用全局变量
        if (IsSet(VoiceSearchLabelEngineY) && VoiceSearchLabelEngineY > 0) {
            LabelEngineY := VoiceSearchLabelEngineY
        } else {
            ; 如果全局变量未设置，尝试从控件获取
            try {
                LabelEngineCtrl := GuiID_VoiceInput["LabelEngine"]
                if (LabelEngineCtrl) {
                    LabelEngineCtrl.GetPos(, &LabelEngineY)
                    if (LabelEngineY > 0) {
                        VoiceSearchLabelEngineY := LabelEngineY
                    }
                }
            } catch {
            }
            
            ; 如果还是获取不到，使用默认值（根据标签栏计算）
            if (LabelEngineY = 0) {
                ; 标签栏位置：自动更新开关(35) + 间距(35) + 分类标签(30) + 标签高度(28) + 间距(15) = 143
                ; 加上输入框等基础高度：55 + 25 + 150 + 45 + 35 = 310
                ; 总计：310 + 143 = 453，但实际应该更高，使用710作为默认值
                LabelEngineY := 710
                VoiceSearchLabelEngineY := LabelEngineY
            }
        }
        
        YPos := LabelEngineY + 30
        ButtonWidth := 130
        ButtonHeight := 35
        ButtonSpacing := 10
        StartX := 20
        ButtonsPerRow := 4
        IconSizeInButton := 20
        
        ; 【关键】只创建当前标签对应的搜索引擎按钮（完全覆盖原先的列表）
        for Index, Engine in SearchEngines {
            Row := Floor((Index - 1) / ButtonsPerRow)
            Col := Mod((Index - 1), ButtonsPerRow)
            BtnX := StartX + Col * (ButtonWidth + ButtonSpacing)
            BtnY := YPos + Row * (ButtonHeight + ButtonSpacing)
            
            ; 检查是否选中
            IsSelected := (ArrayContainsValue(VoiceSearchSelectedEngines, Engine.Value) > 0)
            BtnBgColor := IsSelected ? UI_Colors.BtnHover : UI_Colors.BtnBg
            BtnText := IsSelected ? "✓ " . Engine.Name : Engine.Name
            EngineBtnTextColor := (ThemeMode = "light") ? UI_Colors.Text : "FFFFFF"
            
            ; 获取图标路径
            IconPath := GetSearchEngineIcon(Engine.Value)
            IconCtrl := 0
            
            try {
                ; 创建按钮背景（不再使用 v 变量，以避免在同一个 GUI 实例中发生命名冲突）
                Btn := GuiID_VoiceInput.Add("Text", "x" . BtnX . " y" . BtnY . " w" . ButtonWidth . " h" . ButtonHeight . " Center 0x200 c" . EngineBtnTextColor . " Background" . BtnBgColor, "")
                if (IsObject(Btn)) {
                    Btn.SetFont("s10", "Segoe UI")
                    Btn.OnEvent("Click", CreateToggleSearchEngineHandler(Engine.Value, Index))
                    HoverBtn(Btn, BtnBgColor, UI_Colors.BtnHover)
                } else {
                    ; 如果创建失败，跳过这个按钮
                    continue
                }
            } catch as e {
                ; 如果创建失败，跳过这个按钮
                continue
            }
            
            ; 如果图标存在，在按钮左侧添加小图标
            if (IconPath != "" && FileExist(IconPath)) {
                try {
                    ; 计算图标位置（按钮左侧，垂直居中）
                    IconX := BtnX + 8
                    IconY := BtnY + (ButtonHeight - IconSizeInButton) // 2
                    ImageSize := GetImageSize(IconPath)
                    DisplaySize := CalculateImageDisplaySize(ImageSize.Width, ImageSize.Height, IconSizeInButton, IconSizeInButton)
                    DisplayX := IconX
                    DisplayY := IconY + (IconSizeInButton - DisplaySize.Height) // 2
                    IconCtrl := GuiID_VoiceInput.Add("Picture", "x" . DisplayX . " y" . DisplayY . " w" . DisplaySize.Width . " h" . DisplaySize.Height . " 0x200", IconPath)
                    if (IsObject(IconCtrl)) {
                        IconCtrl.OnEvent("Click", CreateToggleSearchEngineHandler(Engine.Value, Index))
                    } else {
                        IconCtrl := 0
                    }
                    TextX := IconX + IconSizeInButton + 5
                    TextWidth := ButtonWidth - (TextX - BtnX) - 8
                } catch {
                    IconCtrl := 0
                    TextX := BtnX + 8
                    TextWidth := ButtonWidth - 16
                }
            } else {
                IconCtrl := 0
                TextX := BtnX + 8
                TextWidth := ButtonWidth - 16
            }
            
            try {
                TextCtrl := GuiID_VoiceInput.Add("Text", "x" . TextX . " y" . BtnY . " w" . TextWidth . " h" . ButtonHeight . " Left 0x200 c" . EngineBtnTextColor . " BackgroundTrans", BtnText)
                if (IsObject(TextCtrl)) {
                    TextCtrl.SetFont("s10", "Segoe UI")
                    TextCtrl.OnEvent("Click", CreateToggleSearchEngineHandler(Engine.Value, Index))
                } else {
                    TextCtrl := 0
                }
            } catch {
                TextCtrl := 0
            }
            
            ; 保存按钮引用（只保存当前标签的按钮）
            VoiceSearchEngineButtons.Push({Bg: Btn, Icon: IconCtrl, Text: TextCtrl, Index: Index})
        }
        
        ; 【关键】立即刷新GUI，确保新标签的搜索引擎列表完全覆盖原先的列表
        try {
            ; 先显示GUI（如果隐藏了）
            if (!GuiID_VoiceInput.Visible) {
                GuiID_VoiceInput.Show()
            }
            ; 立即强制重绘窗口，确保新按钮显示，旧按钮消失（完全覆盖原先的列表）
            WinRedraw(GuiID_VoiceInput.Hwnd)
        } catch {
            ; 忽略错误
        }
        
        ; 设置焦点到第一个可见的搜索引擎按钮或输入框，确保焦点即时切换
        try {
            if (GuiID_VoiceInput && IsObject(GuiID_VoiceInput) && GuiID_VoiceInput.HasProp("Hwnd")) {
                ; 使用SetTimer延迟设置焦点，确保新按钮创建完成后再设置
                SetTimer(SetVoiceSearchFocus, -100)
            }
        } catch {
            ; 忽略错误
        }
    }
    return CategoryTabHandler
}

; 设置语音搜索面板焦点的辅助函数
SetVoiceSearchFocus(*) {
    global GuiID_VoiceInput, VoiceSearchEngineButtons, VoiceSearchInputEdit
    
    try {
        if (!GuiID_VoiceInput || !IsObject(GuiID_VoiceInput)) {
            return
        }
        
        ; 优先设置焦点到第一个可见的搜索引擎按钮
        if (IsSet(VoiceSearchEngineButtons) && VoiceSearchEngineButtons.Length > 0) {
            for Index, BtnObj in VoiceSearchEngineButtons {
                if (IsObject(BtnObj)) {
                    try {
                        ; 尝试设置焦点到按钮的文本控件
                        if (BtnObj.Text && IsObject(BtnObj.Text) && BtnObj.Text.Visible && BtnObj.Text.HasProp("Hwnd")) {
                            try {
                                ControlFocus(BtnObj.Text.Hwnd, "ahk_id " . GuiID_VoiceInput.Hwnd)
                                return  ; 成功设置焦点后返回
                            } catch {
                                ; 继续尝试下一个
                            }
                        }
                        ; 尝试设置焦点到按钮的背景控件
                        if (BtnObj.Bg && IsObject(BtnObj.Bg) && BtnObj.Bg.Visible && BtnObj.Bg.HasProp("Hwnd")) {
                            try {
                                ControlFocus(BtnObj.Bg.Hwnd, "ahk_id " . GuiID_VoiceInput.Hwnd)
                                return  ; 成功设置焦点后返回
                            } catch {
                                ; 继续尝试下一个
                            }
                        }
                    } catch {
                        ; 忽略错误，继续尝试下一个
                        continue
                    }
                }
            }
        }
        
        ; 如果无法设置焦点到按钮，设置到输入框
        if (VoiceSearchInputEdit && IsObject(VoiceSearchInputEdit) && VoiceSearchInputEdit.HasProp("Hwnd")) {
            try {
                ControlFocus(VoiceSearchInputEdit.Hwnd, "ahk_id " . GuiID_VoiceInput.Hwnd)
            } catch {
                ; 如果ControlFocus失败，尝试使用Focus方法
                try {
                    VoiceSearchInputEdit.Focus()
                } catch {
                    ; 忽略焦点设置失败
                }
            }
        }
    } catch {
        ; 忽略所有错误
    }
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
    ; 使用 +Resize 允许调整大小（虽然我们动态计算尺寸，但保留这个选项）
    GuiID_VoiceInput := Gui("+AlwaysOnTop -DPIScale")
    GuiID_VoiceInput.BackColor := UI_Colors.Background
    GuiID_VoiceInput.SetFont("s12 c" . UI_Colors.Text . " Bold", "Segoe UI")
    GuiID_VoiceInput.Title := GetText("voice_search_title")
    
    ; 【关键修复】动态计算宽度，确保所有按钮可见
    ; 先获取搜索引擎列表以计算所需宽度
    InputBoxHeight := 150
    global VoiceSearchCurrentCategory, VoiceSearchEnabledCategories
    ; 【关键修复】确保VoiceSearchCurrentCategory已初始化
    if (!IsSet(VoiceSearchCurrentCategory) || VoiceSearchCurrentCategory = "") {
        VoiceSearchCurrentCategory := "ai"
    }
    ; 【关键修复】确保VoiceSearchEnabledCategories已初始化
    if (!IsSet(VoiceSearchEnabledCategories) || !IsObject(VoiceSearchEnabledCategories)) {
        VoiceSearchEnabledCategories := ["ai", "academic", "baidu", "image", "audio", "video", "book", "price", "medical", "cloud"]
    }
    SearchEngines := GetSortedSearchEngines(VoiceSearchCurrentCategory)  ; 先获取当前分类的搜索引擎列表
    TotalEngines := SearchEngines.Length
    ButtonWidth := 130
    ButtonHeight := 35
    ButtonSpacing := 10
    ButtonsPerRow := 4  ; 每行4个按钮
    ButtonsRows := Ceil(TotalEngines / ButtonsPerRow)  ; 计算需要的行数
    ButtonsAreaHeight := ButtonsRows * (ButtonHeight + ButtonSpacing)  ; 每行高度（按钮+间距）
    
    ; 计算所需宽度：左边距(20) + 按钮区域宽度 + 右边距(20)
    ; 按钮区域宽度 = 按钮数量 * 按钮宽度 + (按钮数量-1) * 间距
    ; 但需要考虑输入框和右侧按钮，所以取最大值
    InputBoxWidth := 520  ; 输入框宽度
    RightButtonsWidth := 40 + 20  ; 右侧按钮宽度 + 间距
    ButtonsAreaWidth := ButtonsPerRow * ButtonWidth + (ButtonsPerRow - 1) * ButtonSpacing
    MinWidth := InputBoxWidth + RightButtonsWidth + 40  ; 输入框 + 右侧按钮 + 左右边距
    PanelWidth := Max(MinWidth, ButtonsAreaWidth + 40)  ; 取较大值，确保所有内容可见
    
    ; 计算分类标签区域宽度（先定义变量，后面会使用）
    TabWidth := 50
    TabSpacing := 5
    TabsPerRow := 10  ; 默认每行10个标签
    TabAreaWidth := TabsPerRow * TabWidth + (TabsPerRow - 1) * TabSpacing
    ; 标签区域宽度需要考虑清空选择按钮的位置
    MinTabAreaWidth := TabAreaWidth + 150  ; 标签区域 + 清空按钮宽度 + 间距
    PanelWidth := Max(PanelWidth, MinTabAreaWidth)  ; 确保标签区域也可见
    
    CategoryTabHeight := 28 + 15  ; 标签高度 + 间距（如果有多行，需要额外计算）
    ; 【关键修复】只显示启用的标签
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
    global VoiceSearchEnabledCategories
    if (!IsSet(VoiceSearchEnabledCategories) || !IsObject(VoiceSearchEnabledCategories)) {
        VoiceSearchEnabledCategories := ["ai", "academic", "baidu", "image", "audio", "video", "book", "price", "medical", "cloud"]
    }
    
    ; 只保留启用的标签
    Categories := []
    for Index, Category in AllCategories {
        if (ArrayContainsValue(VoiceSearchEnabledCategories, Category.Key) > 0) {
            Categories.Push(Category)
        }
    }
    
    ; 如果没有启用的标签，默认启用AI标签
    if (Categories.Length = 0) {
        Categories.Push({Key: "ai", Text: GetText("search_category_ai")})
        global VoiceSearchCurrentCategory
        VoiceSearchCurrentCategory := "ai"
    }
    
    ; 如果当前选中的标签不在启用列表中，切换到第一个启用的标签
    global VoiceSearchCurrentCategory
    if (ArrayContainsValue(VoiceSearchEnabledCategories, VoiceSearchCurrentCategory) = 0) {
        if (Categories.Length > 0) {
            VoiceSearchCurrentCategory := Categories[1].Key
        } else {
            VoiceSearchCurrentCategory := "ai"
        }
    }
    
    TabRows := Ceil(Categories.Length / TabsPerRow)
    CategoryTabHeight := TabRows * (28 + TabSpacing) + 15  ; 多行标签高度
    
    ; 【关键修复】动态计算高度，确保所有内容可见
    ; 标题栏高度(约30) + 标题区域(15) + 输入框标签(25) + 输入框(150) + 自动加载开关(35) + 自动更新开关(35) + 分类标签栏 + 引擎标签(30) + 按钮区域 + 底部边距(20)
    PanelHeight := 30 + 15 + 25 + InputBoxHeight + 35 + 35 + CategoryTabHeight + 30 + ButtonsAreaHeight + 20
    
    ; 【关键修复】标题栏已由GUI的Title属性提供，不再需要单独的标题文本
    ; 右上角关闭按钮（使用系统关闭按钮，或自定义）
    ; 由于现在有标题栏，可以使用系统关闭按钮，但为了保持一致性，我们仍然使用自定义按钮
    CloseBtnX := PanelWidth - 40  ; 距离右边20px，按钮宽度30px
    CloseBtnY := 5  ; 距离顶部5px（标题栏内）
    CloseBtn := GuiID_VoiceInput.Add("Text", "x" . CloseBtnX . " y" . CloseBtnY . " w30 h30 Center 0x200 c" . UI_Colors.Text . " Background" . UI_Colors.BtnBg . " vCloseBtn", "×")
    CloseBtn.SetFont("s18 Bold", "Segoe UI")
    CloseBtn.OnEvent("Click", HideVoiceSearchInputPanel)
    HoverBtn(CloseBtn, UI_Colors.BtnBg, "FF4444")  ; 悬停时显示红色
    
    ; 输入框标签
    YPos := 50  ; 标题栏后开始
    LabelText := GuiID_VoiceInput.Add("Text", "x20 y" . YPos . " w" . (PanelWidth - 80) . " h20 c" . UI_Colors.TextDim, GetText("voice_search_input_label"))
    LabelText.SetFont("s10", "Segoe UI")
    
    ; 输入框（可编辑，用于显示和编辑语音输入内容）
    YPos += 25
    InputBoxActualWidth := PanelWidth - 80  ; 左边距20 + 右边距20 + 右侧按钮区域40
    VoiceSearchInputEdit := GuiID_VoiceInput.Add("Edit", "x20 y" . YPos . " w" . InputBoxActualWidth . " h150 vVoiceSearchInputEdit Background" . UI_Colors.InputBg . " c" . UI_Colors.Text . " Multi", "")
    VoiceSearchInputEdit.SetFont("s12", "Segoe UI")
    ; 添加焦点事件，自动切换到中文输入法
    VoiceSearchInputEdit.OnEvent("Focus", SwitchToChineseIME)
    ; 添加内容变化事件，记录最后编辑时间（用于检测用户是否正在输入）
    VoiceSearchInputEdit.OnEvent("Change", UpdateVoiceSearchInputEditTime)
    
    ; 清空按钮和搜索按钮（并排显示）
    ; 按钮文字颜色：根据主题调整
    global ThemeMode
    ClearBtnTextColor := (ThemeMode = "light") ? UI_Colors.Text : "FFFFFF"
    RightBtnX := PanelWidth - 60  ; 距离右边20px，按钮宽度40px
    ClearBtn := GuiID_VoiceInput.Add("Text", "x" . RightBtnX . " y" . YPos . " w40 h40 Center 0x200 c" . ClearBtnTextColor . " Background" . UI_Colors.BtnBg . " vClearBtn", GetText("clear"))
    ClearBtn.SetFont("s10", "Segoe UI")
    ClearBtn.OnEvent("Click", ClearVoiceSearchInput)
    HoverBtn(ClearBtn, UI_Colors.BtnBg, UI_Colors.BtnHover)
    
    ; 搜索按钮（在清空按钮下方，输入框高度为150，所以按钮位置需要调整）
    SearchBtnTextColor := (ThemeMode = "light") ? UI_Colors.Text : "FFFFFF"
    SearchBtn := GuiID_VoiceInput.Add("Text", "x" . RightBtnX . " y" . (YPos + 110) . " w40 h40 Center 0x200 c" . SearchBtnTextColor . " Background" . UI_Colors.BtnPrimary . " vSearchBtn", GetText("voice_search_button"))
    SearchBtn.SetFont("s11 Bold", "Segoe UI")
    SearchBtn.OnEvent("Click", ExecuteVoiceSearch)
    HoverBtn(SearchBtn, UI_Colors.BtnPrimary, UI_Colors.BtnPrimaryHover)
    
    ; 自动加载选中文本开关
    YPos += 160  ; 输入框高度150 + 间距10
    global AutoLoadSelectedText, VoiceSearchAutoLoadSwitch
    AutoLoadLabel := GuiID_VoiceInput.Add("Text", "x20 y" . YPos . " w200 h25 c" . UI_Colors.TextDim, GetText("auto_load_selected_text"))
    AutoLoadLabel.SetFont("s10", "Segoe UI")
    ; 创建开关按钮（使用文本按钮模拟开关）
    SwitchText := AutoLoadSelectedText ? GetText("switch_on") : GetText("switch_off")
    SwitchBg := AutoLoadSelectedText ? UI_Colors.BtnHover : UI_Colors.BtnBg
    ; 按钮文字颜色：根据主题调整
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
    ; 创建开关按钮（使用文本按钮模拟开关）
    UpdateSwitchText := AutoUpdateVoiceInput ? GetText("switch_on") : GetText("switch_off")
    UpdateSwitchBg := AutoUpdateVoiceInput ? UI_Colors.BtnHover : UI_Colors.BtnBg
    ; 按钮文字颜色：根据主题调整
    UpdateSwitchTextColor := (ThemeMode = "light") ? UI_Colors.Text : "FFFFFF"
    VoiceSearchAutoUpdateSwitch := GuiID_VoiceInput.Add("Text", "x220 y" . YPos . " w120 h25 Center 0x200 c" . UpdateSwitchTextColor . " Background" . UpdateSwitchBg . " vAutoUpdateSwitch", UpdateSwitchText)
    VoiceSearchAutoUpdateSwitch.SetFont("s10", "Segoe UI")
    VoiceSearchAutoUpdateSwitch.OnEvent("Click", ToggleAutoUpdateVoiceInput)
    HoverBtn(VoiceSearchAutoUpdateSwitch, UpdateSwitchBg, UI_Colors.BtnHover)
    
    ; 分类标签栏
    YPos += 35
    LabelCategoryWidth := PanelWidth - 280  ; 左边距20 + 清空按钮130 + 间距10 + 右边距20
    LabelCategory := GuiID_VoiceInput.Add("Text", "x20 y" . YPos . " w" . LabelCategoryWidth . " h20 c" . UI_Colors.TextDim, GetText("select_search_engine"))
    LabelCategory.SetFont("s10", "Segoe UI")
    
    ; 清空选择按钮（在标签旁边）
    ClearSelectionBtnTextColor := (ThemeMode = "light") ? UI_Colors.Text : "FFFFFF"
    ClearSelectionBtnX := PanelWidth - 150  ; 距离右边20px，按钮宽度130px
    ClearSelectionBtn := GuiID_VoiceInput.Add("Text", "x" . ClearSelectionBtnX . " y" . YPos . " w130 h25 Center 0x200 c" . ClearSelectionBtnTextColor . " Background" . UI_Colors.BtnBg . " vClearSelectionBtn", GetText("clear_selection"))
    ClearSelectionBtn.SetFont("s10", "Segoe UI")
    ClearSelectionBtn.OnEvent("Click", ClearAllSearchEngineSelection)
    HoverBtn(ClearSelectionBtn, UI_Colors.BtnBg, UI_Colors.BtnHover)
    
    ; 创建分类标签按钮
    YPos += 30
    global VoiceSearchCurrentCategory, VoiceSearchCategoryTabs, VoiceSearchEnabledCategories
    
    ; 【关键修复】Categories 已经在上面计算过了，这里直接使用
    ; 如果 Categories 未定义，重新计算（防止出错）
    if (!IsSet(Categories) || !IsObject(Categories) || Categories.Length = 0) {
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
            VoiceSearchEnabledCategories := ["ai", "academic", "baidu", "image", "audio", "video", "book", "price", "medical", "cloud"]
        }
        
        ; 只保留启用的标签
        Categories := []
        for Index, Category in AllCategories {
            if (ArrayContainsValue(VoiceSearchEnabledCategories, Category.Key) > 0) {
                Categories.Push(Category)
            }
        }
        
        ; 如果没有启用的标签，默认启用AI标签
        if (Categories.Length = 0) {
            Categories.Push({Key: "ai", Text: GetText("search_category_ai")})
            VoiceSearchCurrentCategory := "ai"
        }
    }
    
    VoiceSearchCategoryTabs := []
    TabWidth := 50
    TabHeight := 28
    TabSpacing := 5
    TabStartX := 20
    TabY := YPos
    TabsPerRow := 10  ; 每行显示10个标签
    
    ; 第一行标签
    for Index, Category in Categories {
        if (Index > TabsPerRow) {
            break
        }
        TabX := TabStartX + (Index - 1) * (TabWidth + TabSpacing)
        IsActive := (VoiceSearchCurrentCategory = Category.Key)
        TabBg := IsActive ? UI_Colors.BtnPrimary : UI_Colors.BtnBg
        TabTextColor := IsActive ? "FFFFFF" : ((ThemeMode = "light") ? UI_Colors.Text : "FFFFFF")
        
        TabBtn := GuiID_VoiceInput.Add("Text", "x" . TabX . " y" . TabY . " w" . TabWidth . " h" . TabHeight . " Center 0x200 c" . TabTextColor . " Background" . TabBg . " vCategoryTab" . Category.Key, Category.Text)
        TabBtn.SetFont("s9", "Segoe UI")
        ; 创建事件处理函数并绑定
        TabHandler := CreateCategoryTabHandler(Category.Key)
        TabBtn.OnEvent("Click", TabHandler)
        HoverBtn(TabBtn, TabBg, UI_Colors.BtnHover)
        VoiceSearchCategoryTabs.Push({Btn: TabBtn, Key: Category.Key, Handler: TabHandler})
    }
    
    ; 如果标签超过10个，创建第二行
    if (Categories.Length > TabsPerRow) {
        TabY += TabHeight + TabSpacing
        for Index, Category in Categories {
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
            ; 创建事件处理函数并绑定
            TabHandler := CreateCategoryTabHandler(Category.Key)
            TabBtn.OnEvent("Click", TabHandler)
            HoverBtn(TabBtn, TabBg, UI_Colors.BtnHover)
            VoiceSearchCategoryTabs.Push({Btn: TabBtn, Key: Category.Key, Handler: TabHandler})
        }
    }
    
    ; 搜索引擎标签
    YPos := TabY + TabHeight + 15
    LabelEngineWidth := PanelWidth - 40  ; 左右边距各20px
    LabelEngine := GuiID_VoiceInput.Add("Text", "x20 y" . YPos . " w" . LabelEngineWidth . " h20 c" . UI_Colors.TextDim . " vLabelEngine", GetText("select_search_engine"))
    LabelEngine.SetFont("s10", "Segoe UI")
    
    ; 保存LabelEngine的Y位置到全局变量，供切换标签时使用
    global VoiceSearchLabelEngineY := YPos
    
    ; 搜索引擎按钮（文字+图标）
    YPos += 30
    ; SearchEngines已经在上面计算面板高度时获取过了，这里直接使用
    
    VoiceSearchEngineButtons := []
    ButtonWidth := 130
    ButtonHeight := 35
    ButtonSpacing := 10
    StartX := 20
    ButtonsPerRow := 4
    IconSizeInButton := 20  ; 按钮内图标大小
    
    ; 【关键修复】动态调整每行按钮数量，确保所有按钮可见
    ; 计算可用宽度：总宽度 - 左右边距
    AvailableWidth := PanelWidth - 40  ; 左右边距各20px
    MaxButtonsPerRow := Floor((AvailableWidth + ButtonSpacing) / (ButtonWidth + ButtonSpacing))
    if (MaxButtonsPerRow < 1) {
        MaxButtonsPerRow := 1  ; 至少1个按钮
    }
    ButtonsPerRow := Min(ButtonsPerRow, MaxButtonsPerRow)  ; 使用较小的值，确保按钮可见
    ButtonsRows := Ceil(TotalEngines / ButtonsPerRow)  ; 重新计算行数
    ButtonsAreaHeight := ButtonsRows * (ButtonHeight + ButtonSpacing)  ; 重新计算按钮区域高度
    
    ; 重新计算面板高度，因为按钮行数可能已改变
    PanelHeight := 30 + 15 + 25 + InputBoxHeight + 35 + 35 + CategoryTabHeight + 30 + ButtonsAreaHeight + 20
    
    for Index, Engine in SearchEngines {
        Row := Floor((Index - 1) / ButtonsPerRow)
        Col := Mod((Index - 1), ButtonsPerRow)
        BtnX := StartX + Col * (ButtonWidth + ButtonSpacing)
        BtnY := YPos + Row * (ButtonHeight + ButtonSpacing)
        
        ; 检查是否选中
        IsSelected := (ArrayContainsValue(VoiceSearchSelectedEngines, Engine.Value) > 0)
        BtnBgColor := IsSelected ? UI_Colors.BtnHover : UI_Colors.BtnBg
        BtnText := IsSelected ? "✓ " . Engine.Name : Engine.Name
        ; 按钮文字颜色：根据主题调整
        EngineBtnTextColor := (ThemeMode = "light") ? UI_Colors.Text : "FFFFFF"
        
        ; 获取图标路径
        IconPath := GetSearchEngineIcon(Engine.Value)
        IconCtrl := 0  ; 初始化图标控件变量
        
        ; 创建按钮背景
        Btn := GuiID_VoiceInput.Add("Text", "x" . BtnX . " y" . BtnY . " w" . ButtonWidth . " h" . ButtonHeight . " Center 0x200 c" . EngineBtnTextColor . " Background" . BtnBgColor, "")
        Btn.SetFont("s10", "Segoe UI")
        Btn.OnEvent("Click", CreateToggleSearchEngineHandler(Engine.Value, Index))
        HoverBtn(Btn, BtnBgColor, UI_Colors.BtnHover)
        
        ; 如果图标存在，在按钮左侧添加小图标
        if (IconPath != "" && FileExist(IconPath)) {
            try {
                ; 计算图标位置（按钮左侧，垂直居中）
                IconX := BtnX + 8  ; 左边距8px
                IconY := BtnY + (ButtonHeight - IconSizeInButton) // 2  ; 垂直居中
                
                ; 获取图标实际尺寸
                ImageSize := GetImageSize(IconPath)
                
                ; 计算保持比例的显示尺寸
                DisplaySize := CalculateImageDisplaySize(ImageSize.Width, ImageSize.Height, IconSizeInButton, IconSizeInButton)
                
                ; 计算垂直居中位置
                DisplayX := IconX
                DisplayY := IconY + (IconSizeInButton - DisplaySize.Height) // 2
                
                ; 创建图标控件（不再使用 v 变量）
                IconCtrl := GuiID_VoiceInput.Add("Picture", "x" . DisplayX . " y" . DisplayY . " w" . DisplaySize.Width . " h" . DisplaySize.Height . " 0x200", IconPath)
                IconCtrl.OnEvent("Click", CreateToggleSearchEngineHandler(Engine.Value, Index))
                
                ; 计算文字位置（图标右侧）
                TextX := IconX + IconSizeInButton + 5  ; 图标右侧5px间距
                TextWidth := ButtonWidth - (TextX - BtnX) - 8  ; 右边距8px
            } catch {
                ; 如果图标加载失败，文字从左边开始
                IconCtrl := 0
                TextX := BtnX + 8
                TextWidth := ButtonWidth - 16
            }
        } else {
            ; 如果图标不存在，文字从左边开始
            TextX := BtnX + 8
            TextWidth := ButtonWidth - 16
        }
        
        ; 创建文字标签
        ; 创建文字标签（不再使用 v 变量）
        TextCtrl := GuiID_VoiceInput.Add("Text", "x" . TextX . " y" . BtnY . " w" . TextWidth . " h" . ButtonHeight . " Left 0x200 c" . EngineBtnTextColor . " BackgroundTrans", BtnText)
        TextCtrl.SetFont("s10", "Segoe UI")
        TextCtrl.OnEvent("Click", CreateToggleSearchEngineHandler(Engine.Value, Index))
        
        ; 保存按钮引用（包含背景、图标和文字）
        VoiceSearchEngineButtons.Push({Bg: Btn, Icon: IconCtrl, Text: TextCtrl, Index: Index})
    }
    
    ScreenInfo := GetScreenInfo(VoiceInputScreenIndex)
    Pos := GetPanelPosition(ScreenInfo, PanelWidth, PanelHeight, "center")
    ; 移除 NoActivate，让窗口可以激活，这样才能接收输入法输入
    GuiID_VoiceInput.Show("w" . PanelWidth . " h" . PanelHeight . " x" . Pos.X . " y" . Pos.Y)
    WinSetAlwaysOnTop(1, GuiID_VoiceInput.Hwnd)
    
    ; 确保输入框为空
    VoiceSearchInputEdit.Value := ""
    ; 重置最后编辑时间
    global VoiceSearchInputLastEditTime := 0
    
    ; 首先明确停止监听（无论之前状态如何）
    SetTimer(MonitorSelectedText, 0)
    
    ; 激活窗口并设置输入框真正的输入焦点，这样才能接收输入法输入
    WinActivate("ahk_id " . GuiID_VoiceInput.Hwnd)
    Sleep(200)  ; 增加等待时间，确保窗口完全激活
    
    ; 确保窗口真正激活
    if (!WinActive("ahk_id " . GuiID_VoiceInput.Hwnd)) {
        WinActivate("ahk_id " . GuiID_VoiceInput.Hwnd)
        Sleep(200)
    }
    
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
    
    ; 再次确保输入框有焦点（双重保险）
    ; 注意：AutoHotkey v2 中 Edit 控件没有 HasFocus() 方法，直接使用 Focus() 确保焦点
    try {
        ControlFocus(InputEditHwnd, "ahk_id " . GuiID_VoiceInput.Hwnd)
        Sleep(50)
    } catch {
        VoiceSearchInputEdit.Focus()
        Sleep(50)
    }
    
    ; 如果自动加载开关已开启，启动监听；否则确保监听已停止
    if (AutoLoadSelectedText) {
        SetTimer(MonitorSelectedText, 200)  ; 每200ms检查一次
    } else {
        ; 明确停止监听，确保不会自动加载
        SetTimer(MonitorSelectedText, 0)
    }
    
    ; 不自动激活语音输入，由用户通过开关控制
    ; StartVoiceInputInSearch()
}

; 切换焦点到输入框并清空
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
        ; 同时停止更新输入框的定时器
        SetTimer(UpdateVoiceSearchInputInPanel, 0)
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
    
    ; 根据"自动更新语音输入"或"自动加载选中文本"开关状态立即启动或停止定时器（无论是否正在语音输入）
    ; 先停止定时器，确保状态正确
    SetTimer(UpdateVoiceSearchInputInPanel, 0)
    global AutoLoadSelectedText
    if ((AutoUpdateVoiceInput || AutoLoadSelectedText) && VoiceSearchActive) {
        ; 如果"自动更新语音输入"或"自动加载选中文本"任一开启，且正在语音输入，启动定时器
        SetTimer(UpdateVoiceSearchInputInPanel, 300)  ; 每300ms更新一次
    } else {
        ; 明确停止定时器，确保不会自动更新
        SetTimer(UpdateVoiceSearchInputInPanel, 0)
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
            ; 有选中文本，加载到输入框（只在输入框为空时加载）
            SelectedText := A_Clipboard
            if (SelectedText != "" && StrLen(SelectedText) > 0) {
                ; 尝试获取输入框控件并更新（只在输入框为空时更新）
                try {
                    InputEdit := GuiID_VoiceInput["VoiceSearchInputEdit"]
                    if (InputEdit && InputEdit.Value = "") {
                        InputEdit.Value := SelectedText
                        ; 更新编辑时间，避免立即被再次覆盖
                        VoiceSearchInputLastEditTime := A_TickCount
                    }
                } catch {
                    ; 如果通过GUI对象获取失败，尝试使用全局变量（备用方案）
                    try {
                        if (VoiceSearchInputEdit && VoiceSearchInputEdit.Value = "") {
                            VoiceSearchInputEdit.Value := SelectedText
                            ; 更新编辑时间，避免立即被再次覆盖
                            VoiceSearchInputLastEditTime := A_TickCount
                        }
                    } catch {
                        ; 忽略错误
                    }
                }
            }
        }
        
        ; 恢复剪贴板
        A_Clipboard := OldClipboard
    } catch {
        ; 忽略错误
    }
}

; 创建切换搜索引擎选择处理函数（支持多选）
CreateToggleSearchEngineHandler(Engine, BtnIndex) {
    ToggleSearchEngineHandler(*) {
        global VoiceSearchSelectedEngines, VoiceSearchEngineButtons, UI_Colors
        global SearchEngines
        
        ; 切换选择状态
        FoundIndex := ArrayContainsValue(VoiceSearchSelectedEngines, Engine)
        if (FoundIndex > 0) {
            ; 取消选择
            VoiceSearchSelectedEngines.RemoveAt(FoundIndex)
        } else {
            ; 添加选择
            VoiceSearchSelectedEngines.Push(Engine)
        }
        
        ; 保存到配置文件（保存上次的选择）
        try {
            global ConfigFile
            EnginesStr := ""
            for Index, Eng in VoiceSearchSelectedEngines {
                if (Index > 1) {
                    EnginesStr .= ","
                }
                EnginesStr .= Eng
            }
            ; 确保至少有一个默认值
            if (EnginesStr = "") {
                EnginesStr := "deepseek"
            }
            IniWrite(EnginesStr, ConfigFile, "Settings", "VoiceSearchSelectedEngines")
        } catch as e {
            ; 输出错误信息以便调试
            TrayTip("保存搜索引擎选择失败: " . e.Message, "错误", "Iconx 1")
        }
        
        ; 更新按钮样式（文字+图标按钮）
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
                    ; 获取搜索引擎名称（从所有搜索引擎中查找，因为可能切换了分类）
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
        
        ; 【关键修复】立即刷新GUI，确保按钮背景色更新立即显示
        try {
            global GuiID_VoiceInput
            if (GuiID_VoiceInput && IsObject(GuiID_VoiceInput) && GuiID_VoiceInput.HasProp("Hwnd")) {
                WinRedraw(GuiID_VoiceInput.Hwnd)
            }
        } catch {
            ; 忽略刷新错误
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
        ; 忽略保存错误
    }
    
    ; 更新所有按钮的样式（移除选中状态）
    if (IsSet(VoiceSearchEngineButtons) && VoiceSearchEngineButtons.Length > 0) {
        ; 获取当前分类的搜索引擎列表
        try {
            CurrentEngines := GetSortedSearchEngines(VoiceSearchCurrentCategory)
        } catch {
            CurrentEngines := []
        }
        
        for Index, BtnObj in VoiceSearchEngineButtons {
            if (BtnObj && IsObject(BtnObj)) {
                ; 更新背景颜色（取消选中）
                try {
                    if (BtnObj.Bg && IsObject(BtnObj.Bg)) {
                        BtnObj.Bg.BackColor := UI_Colors.BtnBg
                    }
                } catch {
                    ; 忽略更新错误
                }
                
                ; 更新文字（移除 ✓ 标记）
                try {
                    if (BtnObj.Text && IsObject(BtnObj.Text) && BtnObj.Index > 0 && BtnObj.Index <= CurrentEngines.Length) {
                        EngineName := CurrentEngines[BtnObj.Index].Name
                        if (EngineName != "") {
                            ; 移除 ✓ 标记（如果存在）
                            CurrentText := BtnObj.Text.Text
                            if (SubStr(CurrentText, 1, 2) = "✓ ") {
                                BtnObj.Text.Text := EngineName
                            } else {
                                BtnObj.Text.Text := EngineName
                            }
                        }
                    }
                } catch {
                    ; 忽略更新错误
                }
            }
        }
    }
    
    ; 立即刷新GUI，确保所有按钮样式更新立即显示
    try {
        if (GuiID_VoiceInput && IsObject(GuiID_VoiceInput) && GuiID_VoiceInput.HasProp("Hwnd")) {
            WinRedraw(GuiID_VoiceInput.Hwnd)
        }
    } catch {
        ; 忽略刷新错误
    }
    
    ; 显示提示
    TrayTip(GetText("cleared"), GetText("tip"), "Iconi 1")
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
            for Index, Engine in VoiceSearchSelectedEngines {
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
            Sleep(200)  ; 增加等待时间，确保窗口完全激活
            
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
            
            ; 再次确保焦点（双重保险）
            ; 注意：AutoHotkey v2 中 Edit 控件没有 HasFocus() 方法，直接使用 Focus() 确保焦点
            try {
                ControlFocus(InputEditHwnd, "ahk_id " . GuiID_VoiceInput.Hwnd)
                Sleep(50)
            } catch {
                VoiceSearchInputEdit.Focus()
                Sleep(50)
            }
            
            ; 最后再次确认窗口激活和输入框焦点
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
        
        ; 自动检测输入法类型
        VoiceInputMethod := DetectInputMethod()
        
        ; 根据输入法类型使用不同的快捷键
        if (VoiceInputMethod = "baidu") {
            ; 百度输入法：Alt+Y 激活，F2 开始
            ; 确保输入框有焦点并切换到中文输入法
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
            
            ; 再次确保输入框有焦点
            if (VoiceSearchInputEdit) {
                try {
                    ControlFocus(InputEditHwnd, "ahk_id " . GuiID_VoiceInput.Hwnd)
                    Sleep(100)
                } catch {
                    VoiceSearchInputEdit.Focus()
                    Sleep(100)
                }
            }
            
            ; 发送 Alt+Y 激活百度输入法
            Send("!y")
            Sleep(800)  ; 增加等待时间，确保输入法已激活
            
            ; 再次确保输入框有焦点（输入法激活后可能失去焦点）
            if (VoiceSearchInputEdit) {
                try {
                    ControlFocus(InputEditHwnd, "ahk_id " . GuiID_VoiceInput.Hwnd)
                    Sleep(200)
                } catch {
                    VoiceSearchInputEdit.Focus()
                    Sleep(200)
                }
            }
            
            ; 发送 F2 开始语音输入
            Send("{F2}")
            Sleep(300)  ; 增加等待时间，确保语音输入已启动
            
            ; 注意：启动语音输入后，百度输入法会弹出"正在识别中..."窗口
            ; 这个窗口会抢夺焦点，这是正常的，不要立即恢复焦点
            ; 让输入法窗口保持焦点，但定时器会使用ControlFocus确保输入框有输入焦点
            ; 定时器 UpdateVoiceSearchInputInPanel 会处理内容更新和焦点管理
        } else if (VoiceInputMethod = "xunfei") {
            ; 讯飞输入法：直接按 F6 开始语音输入
            Send("{F6}")
            Sleep(800)
            ; 讯飞输入法通常不会弹出模态窗口，可以确保输入框有焦点
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
                ; 切换到中文输入法
                SwitchToChineseIME()
                Sleep(200)
            }
            
            ; 再次确保输入框有焦点
            if (VoiceSearchInputEdit) {
                try {
                    ControlFocus(InputEditHwnd, "ahk_id " . GuiID_VoiceInput.Hwnd)
                    Sleep(100)
                } catch {
                    VoiceSearchInputEdit.Focus()
                    Sleep(100)
                }
            }
            
            ; 发送 Alt+Y 激活百度输入法
            Send("!y")
            Sleep(800)  ; 增加等待时间，确保输入法已激活
            
            ; 再次确保输入框有焦点
            if (VoiceSearchInputEdit) {
                try {
                    ControlFocus(InputEditHwnd, "ahk_id " . GuiID_VoiceInput.Hwnd)
                    Sleep(200)
                } catch {
                    VoiceSearchInputEdit.Focus()
                    Sleep(200)
                }
            }
            
            ; 发送 F2 开始语音输入
            Send("{F2}")
            Sleep(300)  ; 增加等待时间，确保语音输入已启动
            
            ; 注意：启动语音输入后，百度输入法会弹出"正在识别中..."窗口
            ; 这个窗口会抢夺焦点，这是正常的，不要立即恢复焦点
        }
        
        VoiceSearchActive := true
        VoiceSearchContent := ""
        
        
        ; 等待一下，确保语音输入已启动，再开始更新输入框内容
        Sleep(500)
        ; 根据"自动更新语音输入"或"自动加载选中文本"开关状态决定是否开始更新输入框内容
        global AutoLoadSelectedText, AutoUpdateVoiceInput
        ; 先停止定时器，确保状态正确
        SetTimer(UpdateVoiceSearchInputInPanel, 0)
        if (AutoUpdateVoiceInput || AutoLoadSelectedText) {
            ; 如果"自动更新语音输入"或"自动加载选中文本"任一开启，启动定时器
            SetTimer(UpdateVoiceSearchInputInPanel, 300)  ; 每300ms更新一次
        } else {
            ; 明确停止定时器，确保不会自动更新
            SetTimer(UpdateVoiceSearchInputInPanel, 0)
        }
    } catch as e {
        TrayTip(GetText("voice_search_failed") . ": " . e.Message, GetText("error"), "Iconx 2")
    }
}

; 检测百度输入法语音识别窗口是否存在
IsBaiduVoiceWindowActive() {
    ; 检测百度输入法的语音识别窗口（常见的窗口标题和类名）
    ; 百度输入法的语音识别窗口可能有这些特征：
    ; - 窗口标题包含"正在识别"、"语音"、"说完了"等关键词
    ; - 窗口类名可能是 #32770（对话框）、BaiduIME、BaiduPinyin 等
    
    ; 方法1：通过窗口标题检测（最可靠）
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
    
    ; 方法2：通过窗口类名检测百度输入法相关窗口
    BaiduClasses := ["BaiduIME", "BaiduPinyin", "BaiduInput", "#32770"]
    for Index, ClassName in BaiduClasses {
        if (WinExist("ahk_class " . ClassName)) {
            try {
                WinTitle := WinGetTitle("ahk_class " . ClassName)
                ; 检查窗口标题是否包含语音识别相关关键词
                if (InStr(WinTitle, "识别") || InStr(WinTitle, "语音") || InStr(WinTitle, "说完了")) {
                    IsVisible := WinGetMinMax("ahk_class " . ClassName)
                    if (IsVisible != -1) {
                        return true
                    }
                }
            } catch {
                ; 忽略错误
            }
        }
    }
    
    return false
}

; 更新语音搜索输入框内容（在面板中）
; 功能说明：
; - 当"自动更新语音输入"开关开启时，定时器会自动将语音输入的内容更新到输入框
; - 当"自动加载选中文本"开关开启时，也会触发此定时器（用于加载选中的文本）
; - 两个开关任一开启都会启动定时器，但只有"自动加载选中文本"开启时才会加载选中文本
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
        ; 检测百度输入法语音识别窗口是否存在（竞态条件处理）
        BaiduVoiceWindowActive := false
        if (VoiceInputMethod = "baidu") {
            BaiduVoiceWindowActive := IsBaiduVoiceWindowActive()
        }
        
        ; 获取输入框的控件句柄，用于ControlFocus
        InputEditHwnd := VoiceSearchInputEdit.Hwnd
        
        ; 如果百度输入法的语音识别窗口存在，不要强制激活主窗口
        ; 但需要确保输入框有真正的输入焦点（使用ControlFocus，不激活窗口）
        if (BaiduVoiceWindowActive) {
            ; 输入法窗口存在时，使用ControlFocus确保输入框有输入焦点
            ; 这样不会激活主窗口，不会抢夺输入法窗口的焦点
            ; 但输入框仍然可以接收输入法的输入
            if (GuiID_VoiceInput) {
                ; 确保主窗口存在且可见（但不激活，避免抢夺焦点）
                if (WinExist("ahk_id " . GuiID_VoiceInput.Hwnd)) {
                    ; 使用ControlFocus直接设置输入框焦点，不激活窗口
                    try {
                        ControlFocus(InputEditHwnd, "ahk_id " . GuiID_VoiceInput.Hwnd)
                        Sleep(20)  ; 短暂等待，让焦点设置生效
                    } catch {
                        ; 如果ControlFocus失败，尝试使用Focus方法
                        try {
                            VoiceSearchInputEdit.Focus()
                            Sleep(20)
                        } catch {
                            ; 忽略错误
                        }
                    }
                }
            }
        } else {
            ; 输入法窗口不存在时，正常激活主窗口并设置焦点
            if (GuiID_VoiceInput) {
                ; 确保窗口激活
                if (!WinActive("ahk_id " . GuiID_VoiceInput.Hwnd)) {
                    WinActivate("ahk_id " . GuiID_VoiceInput.Hwnd)
                    Sleep(100)  ; 增加等待时间，确保窗口完全激活
                }
                
                ; 确保输入框有焦点（使用ControlFocus确保真正的输入焦点）
                ; 注意：AutoHotkey v2 中 Edit 控件没有 HasFocus() 方法，直接使用 Focus() 确保焦点
                try {
                    ControlFocus(InputEditHwnd, "ahk_id " . GuiID_VoiceInput.Hwnd)
                    Sleep(50)
                } catch {
                    ; 如果ControlFocus失败，使用Focus方法
                    VoiceSearchInputEdit.Focus()
                    Sleep(50)
                }
            }
        }
        
        ; 方法：尝试直接读取输入框内容，如果失败则通过剪贴板
        ; 保存当前剪贴板
        OldClipboard := A_Clipboard
        CurrentContent := ""
        CurrentInputValue := ""
        
        ; 先尝试直接读取输入框内容（更可靠，不会触发焦点变化）
        try {
            CurrentInputValue := VoiceSearchInputEdit.Value
            CurrentContent := CurrentInputValue
        } catch {
            ; 如果直接读取失败，使用剪贴板方式
            ; 只有在输入法窗口不存在时才使用剪贴板方式（避免干扰输入法）
            if (!BaiduVoiceWindowActive && GuiID_VoiceInput) {
                ; 确保窗口激活和输入框有焦点
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
                
                ; 如果复制成功，获取内容
                if (ClipWait(0.15)) {
                    CurrentContent := A_Clipboard
                }
            }
        }
        
        ; 处理读取到的内容
        if (CurrentContent != "" && StrLen(CurrentContent) > 0) {
            ; 检查内容是否看起来像语音输入的内容（不是文件路径或快捷方式）
            if (CurrentInputValue = "" && (InStr(CurrentContent, "\") || InStr(CurrentContent, ".lnk") || InStr(CurrentContent, "快捷方式"))) {
                ; 忽略看起来像文件路径或快捷方式的内容
                A_Clipboard := OldClipboard
                return
            }
            
            ; 如果内容有变化且新内容更长，更新输入框（说明有新输入）
            ; 注意：如果通过直接读取获取的内容，CurrentInputValue 已经是最新的了
            ; 只有在通过剪贴板方式获取内容时才需要更新
            if (CurrentContent != CurrentInputValue && StrLen(CurrentContent) >= StrLen(CurrentInputValue)) {
                try {
                    ; 在输入法窗口存在时，不更新输入框内容（避免干扰输入法）
                    ; 输入法会自动将内容输入到输入框
                    if (!BaiduVoiceWindowActive) {
                        VoiceSearchInputEdit.Value := CurrentContent
                        ; 将光标移到末尾
                        try {
                            ControlFocus(InputEditHwnd, "ahk_id " . GuiID_VoiceInput.Hwnd)
                            Sleep(20)
                            Send("^{End}")
                        } catch {
                            ; 忽略错误
                        }
                    }
                } catch {
                    ; 如果更新失败，可能是输入框被锁定或输入法窗口正在使用
                    ; 忽略错误，下次再尝试
                }
            }
        }
        
        ; 恢复剪贴板
        A_Clipboard := OldClipboard
    } catch {
        ; 忽略错误
    }
}

; 结束语音输入（在语音搜索界面中）
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
                VoiceSearchContent := A_Clipboard
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
                VoiceSearchContent := A_Clipboard
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
                VoiceSearchContent := A_Clipboard
            }
            A_Clipboard := OldClipboard
            
            ; 退出百度输入法语音模式
            Send("!y")
            Sleep(300)
        }
        
        VoiceSearchActive := false
        SetTimer(UpdateVoiceSearchInputInPanel, 0)  ; 停止更新输入框
        
        ; 更新开关按钮显示（安全访问）
        try {
        } catch {
            ; 忽略更新按钮时的错误
        }
        
        ; 将内容填入输入框
        if (VoiceSearchContent != "" && StrLen(VoiceSearchContent) > 0 && VoiceSearchInputEdit) {
            VoiceSearchInputEdit.Value := VoiceSearchContent
            VoiceSearchInputEdit.Focus()
        }
    } catch as e {
        VoiceSearchActive := false
        SetTimer(UpdateVoiceSearchInputInPanel, 0)
        ; 更新开关按钮显示（安全访问，避免变量未初始化错误）
        try {
        } catch {
            ; 忽略更新按钮时的错误
        }
        TrayTip(GetText("voice_search_failed") . ": " . e.Message, GetText("error"), "Iconx 2")
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
    ContentEdit := GuiID_VoiceInput.Add("Edit", "x20 y" . YPos . " w460 h60 vSearchContentEdit Background" . UI_Colors.InputBg . " c" . UI_Colors.Text . " ReadOnly Multi", Content)
    ContentEdit.SetFont("s11", "Segoe UI")
    
    ; 搜索引擎按钮
    YPos += 80
    LabelEngine := GuiID_VoiceInput.Add("Text", "x20 y" . YPos . " w460 h20 c" . UI_Colors.TextDim, GetText("select_search_engine"))
    LabelEngine.SetFont("s10", "Segoe UI")
    
    YPos += 30
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
        Row := Floor((Index - 1) / ButtonsPerRow)
        Col := Mod((Index - 1), ButtonsPerRow)
        BtnX := StartX + Col * (ButtonWidth + ButtonSpacing)
        BtnY := YPos + Row * (ButtonHeight + ButtonSpacing)
        
        ; 创建按钮
        ; 按钮文字颜色：根据主题调整
        global ThemeMode
        EngineBtnTextColor := (ThemeMode = "light") ? UI_Colors.Text : "FFFFFF"
        Btn := GuiID_VoiceInput.Add("Text", "x" . BtnX . " y" . BtnY . " w" . ButtonWidth . " h" . ButtonHeight . " Center 0x200 c" . EngineBtnTextColor . " Background" . UI_Colors.BtnBg . " vSearchEngineBtn" . Index, Engine.Name)
        Btn.SetFont("s10", "Segoe UI")
        Btn.OnEvent("Click", CreateSearchEngineClickHandler(Content, Engine.Value))
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
                ; 元宝AI：使用根路径，添加q参数（intent查询）
                ; 注意：使用yuanbao.tencent.com而不是www.yuanbao.com
                ; 格式：https://yuanbao.tencent.com/?q=搜索关键词
                SearchURL := "https://yuanbao.tencent.com/?q=" . EncodedContent
            case "doubao":
                ; 豆包AI：使用chat路径，添加q参数（intent查询）
                ; q参数用于预填充查询内容
                SearchURL := "https://www.doubao.com/chat/?q=" . EncodedContent
            case "zhipu":
                SearchURL := "https://chatglm.cn/main/search?query=" . EncodedContent
            case "mita":
                ; 秘塔AI搜索：使用q参数（intent查询）
                ; q参数用于指定搜索关键词
                SearchURL := "https://metaso.cn/?q=" . EncodedContent
            case "wenxin":
                SearchURL := "https://yiyan.baidu.com/search?query=" . EncodedContent
            case "qianwen":
                ; 通义千问：使用qianwen/chat路径，添加intent和query参数
                ; intent参数指定为chat，query参数传递搜索内容
                SearchURL := "https://tongyi.aliyun.com/qianwen/chat?intent=chat&query=" . EncodedContent
            case "kimi":
                ; Kimi：使用_prefill_chat路径，添加intent相关参数
                ; force_search=true：强制进行搜索
                ; send_immediately=true：立即发送预填充的内容
                ; prefill_prompt：设置预填充的聊天内容（intent语句）
                SearchURL := "https://kimi.moonshot.cn/_prefill_chat?force_search=true&send_immediately=true&prefill_prompt=" . EncodedContent
            case "perplexity":
                ; Perplexity AI：使用intent参数进行搜索
                ; intent=qa：指定为问答意图，q参数传递搜索内容
                SearchURL := "https://www.perplexity.ai/search?intent=qa&q=" . EncodedContent
            case "copilot":
                ; Microsoft Copilot：使用chat路径，添加q参数（intent查询）
                SearchURL := "https://copilot.microsoft.com/chat?q=" . EncodedContent
            case "chatgpt":
                ; ChatGPT：使用根路径，添加q参数（intent查询）
                SearchURL := "https://chat.openai.com/?q=" . EncodedContent
            case "grok":
                ; Grok：使用grok.com路径，添加q参数（intent查询）
                SearchURL := "https://grok.com/?q=" . EncodedContent
            case "you":
                ; You.com：使用search路径，添加q参数（intent查询）
                SearchURL := "https://you.com/search?q=" . EncodedContent
            case "claude":
                ; Claude：使用new路径，添加q参数（intent查询）
                SearchURL := "https://claude.ai/new?q=" . EncodedContent
            case "monica":
                ; Monica：使用answers路径，添加q参数（intent查询）
                SearchURL := "https://monica.so/answers/?q=" . EncodedContent
            case "webpilot":
                ; WebPilot：使用search路径，添加q参数（intent查询）
                SearchURL := "https://webpilot.ai/search?q=" . EncodedContent
            ; 学术类
            case "zhihu":
                SearchURL := "https://www.zhihu.com/search?q=" . EncodedContent
            case "wechat_article":
                SearchURL := "https://weixin.sogou.com/weixin?query=" . EncodedContent
            case "cainiao":
                SearchURL := "https://www.cainiao.com/search?q=" . EncodedContent
            case "gitee":
                SearchURL := "https://gitee.com/search?q=" . EncodedContent
            case "pubscholar":
                SearchURL := "https://pubscholar.cn/search?q=" . EncodedContent
            case "semantic":
                SearchURL := "https://www.semanticscholar.org/search?q=" . EncodedContent
            case "baidu_academic":
                SearchURL := "https://xueshu.baidu.com/s?wd=" . EncodedContent
            case "bing_academic":
                SearchURL := "https://www.bing.com/academic/search?q=" . EncodedContent
            case "csdn":
                SearchURL := "https://so.csdn.net/so/search?q=" . EncodedContent
            case "national_library":
                SearchURL := "https://www.nlc.cn/dsb_search/search?q=" . EncodedContent
            case "chaoxing":
                SearchURL := "https://www.chaoxing.com/search?q=" . EncodedContent
            case "cnki":
                SearchURL := "https://kns.cnki.net/kns8/AdvSearch?q=" . EncodedContent
            case "wechat_reading":
                SearchURL := "https://weread.qq.com/web/search/books?q=" . EncodedContent
            case "dada":
                SearchURL := "https://www.dadawenku.com/search?q=" . EncodedContent
            case "patent":
                SearchURL := "https://www.patenthub.cn/search?q=" . EncodedContent
            case "ip_office":
                SearchURL := "https://www.cnipa.gov.cn/col/col49/index.html?q=" . EncodedContent
            case "dedao":
                SearchURL := "https://www.dedao.cn/search?q=" . EncodedContent
            case "pkmer":
                SearchURL := "https://pkmer.cn/search?q=" . EncodedContent
            ; 百度类
            case "baidu":
                SearchURL := "https://www.baidu.com/s?wd=" . EncodedContent
            case "baidu_title":
                SearchURL := "https://www.baidu.com/s?wd=intitle:" . EncodedContent
            case "baidu_hanyu":
                SearchURL := "https://hanyu.baidu.com/s?wd=" . EncodedContent
            case "baidu_wenku":
                SearchURL := "https://wenku.baidu.com/search?word=" . EncodedContent
            case "baidu_map":
                SearchURL := "https://map.baidu.com/search/" . EncodedContent
            case "baidu_pdf":
                SearchURL := "https://www.baidu.com/s?wd=" . EncodedContent . " filetype:pdf"
            case "baidu_doc":
                SearchURL := "https://www.baidu.com/s?wd=" . EncodedContent . " filetype:doc"
            case "baidu_ppt":
                SearchURL := "https://www.baidu.com/s?wd=" . EncodedContent . " filetype:ppt"
            case "baidu_xls":
                SearchURL := "https://www.baidu.com/s?wd=" . EncodedContent . " filetype:xls"
            ; 图片类
            case "image_aggregate":
                SearchURL := "https://www.tineye.com/search?q=" . EncodedContent
            case "iconfont":
                SearchURL := "https://www.iconfont.cn/search/index?q=" . EncodedContent
            case "wenxin_image":
                SearchURL := "https://yiyan.baidu.com/image?query=" . EncodedContent
            case "tiangong_image":
                SearchURL := "https://tiangong.kuaishou.com/image?q=" . EncodedContent
            case "yuanbao_image":
                SearchURL := "https://yuanbao.tencent.com/image?q=" . EncodedContent
            case "tongyi_image":
                SearchURL := "https://tongyi.aliyun.com/wanxiang/image?q=" . EncodedContent
            case "zhipu_image":
                SearchURL := "https://chatglm.cn/image?q=" . EncodedContent
            case "miaohua":
                SearchURL := "https://miaohua.sensetime.com/?q=" . EncodedContent
            case "keling":
                SearchURL := "https://kling.kuaishou.com/?q=" . EncodedContent
            case "jimmeng":
                SearchURL := "https://jimmeng.douyin.com/?q=" . EncodedContent
            case "baidu_image":
                SearchURL := "https://image.baidu.com/search/index?tn=baiduimage&word=" . EncodedContent
            case "shetu":
                SearchURL := "https://699pic.com/search.html?kw=" . EncodedContent
            case "huaban":
                SearchURL := "https://huaban.com/search/?q=" . EncodedContent
            case "zcool":
                SearchURL := "https://www.zcool.com.cn/search/content?&word=" . EncodedContent
            case "uisdc":
                SearchURL := "https://www.uisdc.com/search?q=" . EncodedContent
            case "nipic":
                SearchURL := "https://www.nipic.com/search.html?k=" . EncodedContent
            case "bing_image":
                SearchURL := "https://www.bing.com/images/search?q=" . EncodedContent
            case "google_image":
                SearchURL := "https://www.google.com/search?tbm=isch&q=" . EncodedContent
            case "weibo_image":
                SearchURL := "https://s.weibo.com/image?q=" . EncodedContent
            case "sogou_image":
                SearchURL := "https://pic.sogou.com/pics?query=" . EncodedContent
            case "haosou_image":
                SearchURL := "https://image.so.com/i?q=" . EncodedContent
            ; 音频类
            case "netease_music":
                SearchURL := "https://music.163.com/#/search/m/?s=" . EncodedContent
            case "tiangong_music":
                SearchURL := "https://tiangong.kuaishou.com/music?q=" . EncodedContent
            case "qq_music":
                SearchURL := "https://y.qq.com/n/ryqq/search?w=" . EncodedContent
            case "kuwo":
                SearchURL := "https://www.kuwo.cn/search/list?key=" . EncodedContent
            case "kugou":
                SearchURL := "https://www.kugou.com/yy/html/search.html#searchType=song&searchKeyWord=" . EncodedContent
            case "qianqian":
                SearchURL := "https://music.taihe.com/search?word=" . EncodedContent
            case "ximalaya":
                SearchURL := "https://www.ximalaya.com/search/" . EncodedContent
            case "5sing":
                SearchURL := "https://5sing.kugou.com/search.html?q=" . EncodedContent
            ; 视频类
            case "douyin":
                SearchURL := "https://www.douyin.com/search/" . EncodedContent
            case "youtube":
                SearchURL := "https://www.youtube.com/results?search_query=" . EncodedContent
            case "youku":
                SearchURL := "https://so.youku.com/search_video/q_" . EncodedContent
            case "tencent_video":
                SearchURL := "https://v.qq.com/x/search/?q=" . EncodedContent
            case "iqiyi":
                SearchURL := "https://so.iqiyi.com/so/q_" . EncodedContent
            case "pexels":
                SearchURL := "https://www.pexels.com/search/" . EncodedContent
            case "yandex":
                SearchURL := "https://yandex.com/video/search?text=" . EncodedContent
            ; 图书类
            case "duokan":
                SearchURL := "https://www.duokan.com/search/" . EncodedContent
            case "turing":
                SearchURL := "https://www.ituring.com.cn/search?q=" . EncodedContent
            case "panda_book":
                SearchURL := "https://www.xpanda.cc/search?q=" . EncodedContent
            case "douban_book":
                SearchURL := "https://book.douban.com/subject_search?search_text=" . EncodedContent
            case "jiumo":
                SearchURL := "https://www.jiumodiary.com/search?q=" . EncodedContent
            case "weibo_book":
                SearchURL := "https://s.weibo.com/weibo/" . EncodedContent
            ; 比价类
            case "jd":
                SearchURL := "https://search.jd.com/Search?keyword=" . EncodedContent
            case "taobao":
                SearchURL := "https://s.taobao.com/search?q=" . EncodedContent
            case "tmall":
                SearchURL := "https://list.tmall.com/search_product.htm?q=" . EncodedContent
            case "pinduoduo":
                SearchURL := "https://mobile.yangkeduo.com/search_result.html?search_key=" . EncodedContent
            case "xianyu":
                SearchURL := "https://s.2.taobao.com/list/list.htm?q=" . EncodedContent
            case "smzdm":
                SearchURL := "https://search.smzdm.com/?c=faxian&s=" . EncodedContent
            case "dangdang":
                SearchURL := "https://search.dangdang.com/?key=" . EncodedContent
            case "1688":
                SearchURL := "https://s.1688.com/selloffer/offer_search.htm?keywords=" . EncodedContent
            case "amazon":
                SearchURL := "https://www.amazon.com/s?k=" . EncodedContent
            case "ebay":
                SearchURL := "https://www.ebay.com/sch/i.html?_nkw=" . EncodedContent
            ; 医疗类
            case "dxy":
                SearchURL := "https://www.dxy.cn/bbs/newweb/pc/search?q=" . EncodedContent
            case "merck":
                SearchURL := "https://www.msdmanuals.com/zh/search?q=" . EncodedContent
            case "aplus_medical":
                SearchURL := "https://www.a-hospital.com/w/" . EncodedContent
            case "medical_baike":
                SearchURL := "https://www.yixue.com/index.php?q=" . EncodedContent
            case "weiyi":
                SearchURL := "https://www.guahao.com/search?q=" . EncodedContent
            case "medlive":
                SearchURL := "https://www.medlive.cn/search?q=" . EncodedContent
            case "xywy":
                SearchURL := "https://www.xywy.com/search?q=" . EncodedContent
            ; 网盘类
            case "pansoso":
                ; 盘搜搜：直接打开主页（不支持参数传递）
                SearchURL := "https://www.pansoso.com/zh/"
            case "panso":
                ; 盘搜Pro：使用search路径，添加q参数
                SearchURL := "https://panso.pro/search?q=" . EncodedContent
            case "xiaomapan":
                ; 小码盘：使用search路径，添加keyword参数
                SearchURL := "https://www.xiaomapan.com/#/main/search?keyword=" . EncodedContent
            case "dashengpan":
                ; 大圣盘：使用search路径，添加keyword参数
                SearchURL := "https://www.dashengpan.com/#/main/search?keyword=" . EncodedContent
            case "miaosou":
                ; 秒搜：使用info路径，添加searchKey参数
                SearchURL := "https://miaosou.fun/info?searchKey=" . EncodedContent
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
        ; 对于语音搜索输入框，使用输入框所在的窗口句柄
        global GuiID_VoiceInput, VoiceSearchInputEdit
        if (GuiID_VoiceInput && VoiceSearchInputEdit) {
            ; 确保窗口激活
            WinActivate("ahk_id " . GuiID_VoiceInput.Hwnd)
            Sleep(50)
            ; 确保输入框有焦点
            VoiceSearchInputEdit.Focus()
            Sleep(50)
            ActiveHwnd := GuiID_VoiceInput.Hwnd
        } else {
            ; 获取当前活动窗口的句柄
            ActiveHwnd := WinGetID("A")
        }
        
        if (!ActiveHwnd) {
            return
        }
        
        ; 方法1：使用 Windows IME API 切换到中文输入法
        ; 加载 imm32.dll
        hIMC := DllCall("imm32\ImmGetContext", "Ptr", ActiveHwnd, "Ptr")
        if (hIMC) {
            ; 获取当前输入法状态
            DllCall("imm32\ImmGetConversionStatus", "Ptr", hIMC, "UInt*", &ConversionMode := 0, "UInt*", &SentenceMode := 0)
            
            ; 设置输入法为中文模式（IME_CMODE_NATIVE = 1）
            ; IME_CMODE_NATIVE 表示使用本地语言（中文）输入模式
            ConversionMode := ConversionMode | 0x0001  ; IME_CMODE_NATIVE
            
            ; 应用新的输入法状态
            DllCall("imm32\ImmSetConversionStatus", "Ptr", hIMC, "UInt", ConversionMode, "UInt", SentenceMode)
            
            ; 释放输入法上下文
            DllCall("imm32\ImmReleaseContext", "Ptr", ActiveHwnd, "Ptr", hIMC)
        }
        
        ; 方法2：尝试切换到中文键盘布局（备用方案）
        ; 中文简体键盘布局代码：0x0804 (2052)
        ; 使用 PostMessage 发送输入法切换请求
        try {
            ; WM_INPUTLANGCHANGEREQUEST = 0x0050
            ; 参数：wParam = INPUTLANGCHANGE_SYSCHARSET (0x0001), lParam = 键盘布局句柄
            ; 获取中文键盘布局句柄
            hKL := DllCall("user32\LoadKeyboardLayout", "Str", "00000804", "UInt", 0x00000001, "Ptr")  ; KLF_ACTIVATE = 1
            if (hKL) {
                ; 发送输入法切换消息
                PostMessage(0x0050, 0x0001, hKL, , , "ahk_id " . ActiveHwnd)
            }
        } catch {
            ; 如果失败，静默处理
        }
        
    } catch {
        ; 如果切换失败，静默处理（不显示错误提示）
    }
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

