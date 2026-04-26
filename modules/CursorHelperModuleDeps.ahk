; =============================================================================
; CursorHelper 拆分模块 — 全局 / #Include 顺序依赖（仅供维护参考，可不 Include）
; =============================================================================
; 加载顺序要点（主脚本 CursorHelper (1).ahk）：
; 1. Gdip / TrayMenu 之前：ScreenshotColorPickerActive, AppearanceActivationMode,
;    FloatingToolbarIsVisible, FloatingBubbleIsVisible, Language（须早于 GetText）
; 2. MainScriptDir := A_ScriptDir 之后：EverythingClient（DLL 路径）、ClipboardFTS5
; 3. ConfigManager #Include 之后：InitConfig、剪贴板 DB、InitEverythingService
; 4. CursorPanelController.ahk / PromptExecution.ahk：主脚本在剪贴板管道之后、LegacyConfigGui 之前
;    #Include；依赖 GetText、Floating*、NormalizeAppearanceActivationMode、ShowClipboardManager（运行时）
; 5. EverythingClient.ahk：须在 MainScriptDir 定义之后；lib\everything64.dll
; 6. GlobalSearchEngine.ahk：ClipboardDB / global_ST / GlobalSearchStatement
; 7. SearchCenterUrlHelpers.ahk：依赖 GlobalSearchEngine
; 8. SearchCenterLegacyGui.ahk：Legacy ListView；依赖 SearchCenter_ShouldUseWebView（WebViewCore）、
;    GetSortedSearchEngines（VoiceInputModule，运行时调用）、UI_Colors、大量 SearchCenter_* 全局
; 9. CapsLockDynamicHotkey.ahk：紧接 ScreenshotWorkflow 之后、#HotIf 热键块之前；
;    依赖 HandleScreenshotEditorHotkey 包装函数与 ExecuteScreenshotWithMenu
; =============================================================================
; 主要全局契约（节选，完整列表见主脚本 global 块）：
; - 面板：PanelVisible, GuiID_CursorPanel, QuickActionButtons, CapsLock2, Hotkey*
; - 搜索中心：GuiID_SearchCenter, SearchCenterSearchEdit, SearchCenterResultLV, ...
; - 剪贴板链：CapsLockCopyInProgress, LastClipboardContent, ClipboardFTS5DB
; =============================================================================
