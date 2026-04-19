; ===================== msg =====================

global pToken := Gdip_Startup()
if (!pToken) {
    MsgBox "GDI+ 启动失败，请检查 lib\Gdip_All.ahk"
}
; ScreenshotEditorPlugin #HotIf 可能在主脚本后部全局块执行前被求值，须尽早初始化
global ScreenshotColorPickerActive := false
; 托盘菜单可能在 Appearance / 悬浮模块全局块执行前被点击（TrayMenu_Init 很早），须尽早初始化
global AppearanceActivationMode := "toolbar"
global FloatingToolbarIsVisible := false
global FloatingBubbleIsVisible := false
; TrayMenu_Init / UpdateTrayMenu 会立刻 GetText，须早于后部「多语言」全局块
global Language := "zh"
; ===================== 基础配置 =====================
#SingleInstance Force
SetTitleMatchMode(2)
SetControlDelay(-1)
SetKeyDelay(20, 20)
SetMouseDelay(10)
SendMode("Input")
DetectHiddenWindows(true)
; 设置坐标模式（用于拖动窗口等功能）
CoordMode("Mouse", "Screen")
CoordMode("Pixel", "Screen")
CoordMode("ToolTip", "Screen")
; 托盘图标与 0x0404 自定义菜单：在 #Include lib\ImagePut.ahk 之后调用 TrayMenu_Init()（依赖 Gdip_All）

; ===================== 包含 SQLite 数据库类 =====================
; 包含 lib 文件夹中的 Class_SQLiteDB.ahk（AHK v2 版本）
#Include lib\Class_SQLiteDB.ahk
#Include lib\Jxon.ahk
#Include lib\WebView2.ahk
#Include modules\AhkWebViewBridge.ahk
#Include modules\WebView2SharedEnv.ahk

; ===================== 包含 OCR 模块 =====================
; 包含 lib 文件夹中的 OCR.ahk（用于识图取词功能）
#Include lib\OCR.ahk

; ===================== 包含 GDI+ 和 WinClip 库 =====================
; 包含 lib 文件夹中的 Gdip_All.ahk 和 WinClip.ahk（用于截图助手预览窗）
; 注意：WinClip.ahk 依赖于 WinClipAPI.ahk，需要先包含 WinClipAPI.ahk
#Include lib\Gdip_All.ahk
#Include lib\WinClipAPI.ahk
#Include lib\WinClip.ahk

; ===================== 包含 ImagePut 库 =====================
; 包含 lib 文件夹中的 ImagePut.ahk（用于简化图片处理，提高性能和功能）
#Include lib\ImagePut.ahk

#Include modules\TrayMenuManager.ahk
TrayMenu_Init()

; ===================== 定义主脚本目录（供模块使用）=====================
global MainScriptDir := A_ScriptDir

; ===================== WM_ACTIVATE 链（须在任意 OnMessage(0x0006) 模块之前）=====================
#Include modules\WMActivateChain.ahk

; ===================== 包含新的剪贴板管理器模块 =====================
#Include modules\ClipboardFTS5.ahk
#Include modules\SpeechSAPI.ahk
#Include modules\ClipboardHistoryPanel.ahk
#Include modules\ClipboardPanelCore.ahk
#Include modules\ShellIconCache.ahk
#Include modules\FileClassifier.ahk

; ===================== 包含悬浮工具栏模块 =====================
#Include modules\FloatingToolbar.ahk
#Include modules\FloatingBubble.ahk
#Include modules\GravityPump.ahk
#Include modules\AIListPanel.ahk
#Include modules\PromptQuickPadCore.ahk
#Include modules\SearchCenterWebViewCore.ahk
#Include modules\SelectionSenseCore.ahk
#Include modules\PromptSyncService.ahk
#Include modules\PromptQuickPadCapsLockB.ahk

; ===================== Everything API 封装 =====================
; Everything API 封装
; ===================== Everything API 封装 =====================
; 节流用户提示，避免 DLL/IPC 失败时刷屏
EverythingUserTipOnce(Message, CooldownMs := 90000) {
    static LastTick := 0
    if (LastTick != 0 && (A_TickCount - LastTick < CooldownMs))
        return
    LastTick := A_TickCount
    try TrayTip(Message, "CursorHelper · Everything", "Icon! 2")
}

ResolveEverythingExePath() {
    candidates := []
    candidates.Push(A_ScriptDir "\Everything64.exe")
    candidates.Push(A_ScriptDir "\Everything.exe")
    candidates.Push(A_ProgramFiles "\Everything\Everything64.exe")
    candidates.Push(A_ProgramFiles "\Everything\Everything.exe")
    candidates.Push(A_ProgramFiles "\voidtools\Everything\Everything64.exe")
    candidates.Push(A_ProgramFiles "\voidtools\Everything\Everything.exe")

    try {
        pf86 := EnvGet("ProgramFiles(x86)")
        if (pf86 != "") {
            candidates.Push(pf86 "\Everything\Everything64.exe")
            candidates.Push(pf86 "\Everything\Everything.exe")
            candidates.Push(pf86 "\voidtools\Everything\Everything64.exe")
            candidates.Push(pf86 "\voidtools\Everything\Everything.exe")
        }
    }

    for _, p in candidates {
        if (p != "" && FileExist(p))
            return p
    }
    return ""
}

GetEverythingPID(&ProcessName := "", Require64 := false) {
    names := Require64 ? ["Everything64.exe"] : ["Everything64.exe", "Everything.exe"]
    for _, n in names {
        pid := ProcessExist(n)
        if (pid) {
            ProcessName := n
            return pid
        }
    }
    ProcessName := ""
    return 0
}

TryStartEverything(&StartedFrom := "") {
    runningName := ""
    require64 := (A_PtrSize = 8)
    if (GetEverythingPID(&runningName, require64)) {
        StartedFrom := "already-running"
        return true
    }

    exePath := ResolveEverythingExePath()
    if (exePath = "") {
        StartedFrom := "not-found"
        return false
    }

    try {
        Run('"' . exePath . '" -startup', , "Hide")
        Sleep(1800)
    } catch {
        StartedFrom := "launch-failed"
        return false
    }

    if (GetEverythingPID(&runningName, require64)) {
        StartedFrom := exePath
        return true
    }

    StartedFrom := "started-but-not-detected"
    return false
}

GetEverythingResults(keyword, maxResults := 30, includeFolders := true) {
    static evDll := A_ScriptDir "\lib\everything64.dll"
    static isInitialized := false

    ; 1. 基础防护
    if (!FileExist(evDll)) {
        OutputDebug("AHK_DEBUG: 致命错误 - 找不到 everything64.dll")
        EverythingUserTipOnce("未找到 lib\everything64.dll。请从 Everything SDK 复制 Everything64.dll 到脚本 lib 目录并重命名为 everything64.dll。")
        return []
    }

    ; 2. 首次调用时，确保DLL已加载并检查Everything是否可用
    if (!isInitialized) {
        ; 加载DLL到进程空间
        hModule := DllCall("LoadLibrary", "Str", evDll, "Ptr")
        if (!hModule) {
            OutputDebug("AHK_DEBUG: 无法加载 everything64.dll")
            EverythingUserTipOnce("无法加载 lib\everything64.dll（位数或依赖是否与系统一致？）。")
            return []
        }
        isInitialized := true
        OutputDebug("AHK_DEBUG: Everything DLL 加载成功")
    }

    ; 3. 检查 Everything 客户端是否在运行（通过获取版本号判断IPC连接）
    majorVer := DllCall(evDll "\Everything_GetMajorVersion", "UInt")
    if (majorVer = 0) {
        errCode := DllCall(evDll "\Everything_GetLastError", "UInt")
        OutputDebug("AHK_DEBUG: Everything IPC 连接失败，错误码: " . errCode . " (2=未运行)")
        ; 尝试启动 Everything（优先 64 位）
        runningName := ""
        require64 := (A_PtrSize = 8)
        if (!GetEverythingPID(&runningName, require64)) {
            startedFrom := ""
            if (!TryStartEverything(&startedFrom)) {
                OutputDebug("AHK_DEBUG: 无法启动 Everything, 来源: " . startedFrom)
                EverythingUserTipOnce("无法启动 Everything。请确认根目录存在 Everything64.exe（64位）并使用与脚本同等权限运行。")
                return []
            }
            majorVer := DllCall(evDll "\Everything_GetMajorVersion", "UInt")
            if (majorVer = 0) {
                errCode := DllCall(evDll "\Everything_GetLastError", "UInt")
                OutputDebug("AHK_DEBUG: Everything 启动后 IPC 仍失败, 错误码: " . errCode)
                EverythingUserTipOnce("Everything 已启动但 IPC 仍失败。请确认 Everything 与脚本权限一致，且已启用 SDK IPC。")
                return []
            }
        } else {
            ; Everything 进程存在但IPC连接失败，等待重试
            Sleep(1000)
            majorVer := DllCall(evDll "\Everything_GetMajorVersion", "UInt")
            if (majorVer = 0) {
                OutputDebug("AHK_DEBUG: Everything 进程存在但IPC连接失败")
                EverythingUserTipOnce("Everything 进程在运行但 IPC 连接失败。请确保 Everything 与脚本权限一致（都普通或都管理员），并检查是否禁用了 SDK IPC。")
                return []
            }
        }
    }
    OutputDebug("AHK_DEBUG: Everything 版本: " . majorVer)

    ; 4. 【关键】清理上一次的搜索状态，防止过滤器残留
    DllCall(evDll "\Everything_CleanUp")

    ; 5. 设置搜索参数
    DllCall(evDll "\Everything_SetSearchW", "WStr", keyword)
    DllCall(evDll "\Everything_SetMax", "UInt", maxResults)

    ; 6. 【扩展】请求更多信息：完整路径、文件名、大小、修改日期、属性等
    ; 0x00000004 = EVERYTHING_REQUEST_FULL_PATH_AND_FILE_NAME
    ; 0x00000020 = EVERYTHING_REQUEST_SIZE
    ; 0x00000080 = EVERYTHING_REQUEST_DATE_MODIFIED
    ; 0x00000200 = EVERYTHING_REQUEST_ATTRIBUTES
    requestFlags := 0x00000004 | 0x00000020 | 0x00000080 | 0x00000200
    DllCall(evDll "\Everything_SetRequestFlags", "UInt", requestFlags)

    ; 7. 执行查询 (1 = 阻塞等待直到结果准备好)
    isSuccess := DllCall(evDll "\Everything_QueryW", "Int", 1)

    ; 8. 错误诊断
    if (!isSuccess) {
        errCode := DllCall(evDll "\Everything_GetLastError", "UInt")
        OutputDebug("AHK_DEBUG: Everything 查询指令发送失败，错误码: " . errCode)
        ; 错误码说明: 0=OK, 1=内存错误, 2=IPC错误, 3=注册类失败, 4=创建窗口失败, 5=创建线程失败, 6=搜索词无效, 7=取消
        EverythingUserTipOnce("Everything 查询失败，错误码: " . errCode . "（2 多为 IPC/未运行）。")
        return []
    }

    ; 9. 获取结果
    count := DllCall(evDll "\Everything_GetNumResults", "UInt")
    OutputDebug("AHK_DEBUG: Everything DLL 返回数量: " . count . " (关键词: " . keyword . ")")

    ; 如果返回0，检查是否有错误
    if (count = 0) {
        errCode := DllCall(evDll "\Everything_GetLastError", "UInt")
        if (errCode != 0) {
            OutputDebug("AHK_DEBUG: Everything 查询后错误码: " . errCode)
        }
    }

    ; 10. 获取结果（返回Map对象数组，包含路径、类型、大小等信息）
    results := []
    Loop Min(count, maxResults) {
        index := A_Index - 1
        
        ; 获取文件属性以判断是文件还是文件夹
        attributes := DllCall(evDll "\Everything_GetResultAttributes", "UInt", index, "UInt")
        isDirectory := (attributes & 0x10) != 0  ; FILE_ATTRIBUTE_DIRECTORY = 0x10
        
        ; 如果设置了不包含文件夹，则跳过文件夹
        if (!includeFolders && isDirectory) {
            continue
        }
        
        ; 获取完整路径
        buf := Buffer(4096, 0)
        DllCall(evDll "\Everything_GetResultFullPathNameW", "UInt", index, "Ptr", buf.Ptr, "UInt", 2048)
        fullPath := StrGet(buf.Ptr, "UTF-16")
        
        if (fullPath = "") {
            continue
        }
        
        ; 获取文件大小
        fileSize := DllCall(evDll "\Everything_GetResultSize", "UInt", index, "Int64")
        
        ; 获取修改日期
        fileTime := DllCall(evDll "\Everything_GetResultDateModified", "UInt", index, "Int64")
        
        ; 创建结果对象
        result := Map()
        result["Path"] := fullPath
        result["IsDirectory"] := isDirectory
        result["Type"] := isDirectory ? "folder" : "file"
        result["Size"] := fileSize
        result["DateModified"] := fileTime
        result["Attributes"] := attributes
        
        results.Push(result)
    }

    ; 为了向后兼容，如果只需要路径数组，可以返回简化格式
    ; 但这里返回完整信息，调用方可以根据需要提取路径
    return results
}

; 检查并启动 Everything 服务
InitEverythingService() {
    runningName := ""
    require64 := (A_PtrSize = 8)
    EverythingPID := GetEverythingPID(&runningName, require64)
    if (!EverythingPID) {
        startedFrom := ""
        if (TryStartEverything(&startedFrom)) {
            runningName := ""
            EverythingPID := GetEverythingPID(&runningName, require64)
            OutputDebug("AHK_DEBUG: Everything 服务启动成功: " . startedFrom . " (PID: " . EverythingPID . ")")
        } else {
            OutputDebug("AHK_DEBUG: 启动 Everything 服务失败: " . startedFrom)
        }
    } else {
        OutputDebug("AHK_DEBUG: Everything 服务已在运行: " . runningName . " (PID: " . EverythingPID . ")")
        
        ; 验证IPC连接是否正常
        static evDll := A_ScriptDir "\lib\everything64.dll"
        if (FileExist(evDll)) {
            majorVer := DllCall(evDll "\Everything_GetMajorVersion", "UInt")
            if (majorVer = 0) {
                OutputDebug("AHK_DEBUG: Everything 进程存在但IPC连接失败，可能需要重启 Everything")
            } else {
                OutputDebug("AHK_DEBUG: Everything IPC 连接正常，版本: " . majorVer)
            }
        }
    }
}

; Everything API 初始化函数
Everything_Init() {
    static evDll := A_ScriptDir "\lib\everything64.dll"
    static isInitialized := false

    ; 检查 DLL 文件是否存在
    if (!FileExist(evDll)) {
        OutputDebug("AHK_DEBUG: Everything_Init - 找不到 everything64.dll")
        return false
    }

    ; 首次调用时，确保DLL已加载
    if (!isInitialized) {
        hModule := DllCall("LoadLibrary", "Str", evDll, "Ptr")
        if (!hModule) {
            OutputDebug("AHK_DEBUG: Everything_Init - 无法加载 everything64.dll")
            return false
        }
        isInitialized := true
        OutputDebug("AHK_DEBUG: Everything_Init - DLL 加载成功")
    }

    ; 检查 Everything 客户端是否在运行（通过获取版本号判断IPC连接）
    majorVer := DllCall(evDll "\Everything_GetMajorVersion", "UInt")
    if (majorVer = 0) {
        errCode := DllCall(evDll "\Everything_GetLastError", "UInt")
        OutputDebug("AHK_DEBUG: Everything_Init - IPC 连接失败，错误码: " . errCode)
        ; 尝试启动 Everything
        runningName := ""
        require64 := (A_PtrSize = 8)
        if (!GetEverythingPID(&runningName, require64)) {
            InitEverythingService()
            Sleep(1000)  ; 等待启动
            ; 再次检查
            majorVer := DllCall(evDll "\Everything_GetMajorVersion", "UInt")
            if (majorVer = 0) {
                return false
            }
        } else {
            return false
        }
    }

    return true
}

; 已移除强制管理员自提权，避免与 Everything 产生权限不一致导致 IPC 失败。

; 全局变量（v2用Class/全局变量管理）
global CapsLockDownTime := 0
global IsCommandMode := false
global PanelVisible := false
global GuiID_CursorPanel := 0
global CursorPanelDescText := 0  ; 快捷操作面板说明文字控件
global CursorPanelAlwaysOnTop := false  ; 面板是否置顶（默认不置顶）
global CursorPanelAutoHide := false  ; 面板是否启用靠边自动隐藏
global CursorPanelHidden := false  ; 面板是否已隐藏（靠边时）
global CursorPanelWidth := 680  ; 面板宽度（参考 Raycast 和 uTools 的默认宽度）
global CursorPanelHeight := 0  ; 面板高度（动态计算）
global CursorPanelSearchEdit := 0  ; 快捷操作面板搜索输入框
global CursorPanelResultLV := 0  ; 快捷操作面板搜索结果ListView
global CursorPanelSearchResults := []  ; 快捷操作面板搜索结果数组
global CursorPanelShowMoreBtn := 0  ; 快捷操作面板"更多"按钮
global CursorPanelSearchDebounceTimer := 0  ; 快捷操作面板搜索防抖定时器
global ConfigFile := A_ScriptDir "\CursorShortcut.ini"
global TrayIconPath := A_ScriptDir "\cursor_helper.ico"
; CustomIconPath 由 modules\TrayMenuManager.ahk 初始化
; CapsLock+ 方案的核心变量
global CapsLock := false
global GuiID_ConfigGUI := 0  ; 配置面板单例
global UseWebViewSettings := true  ; 首期设置页 WebView 开关（可回退原生 GUI）
global ConfigWebViewMode := false
global ConfigWV2Ctrl := 0
global ConfigWV2 := 0
global ConfigWV2Ready := false
global ConfigWebViewPreloaded := false
global g_ConfigWebView_LastShown := 0  ; ShowConfigWebViewGUI 后时间戳，WM_ACTIVATE 宽限期避免刚显示即被关
global UnifiedAssetsHost := "app.local"
global UnifiedAssetsRoot := A_ScriptDir
global UnifiedAssetsAccessKind := 0  ; COREWEBVIEW2_HOST_RESOURCE_ACCESS_KIND_ALLOW
; Allow WebView2 to open ws:// from https://app.local (OpenClaw Gateway is local ws).
global WebView2DefaultOptions := { AdditionalBrowserArguments: "--allow-running-insecure-content --renderer-process-limit=3" }
global WebViewMsgQueue := []
global WebViewMsgQueueActive := false
global WebViewWarmupQueue := []
global WebViewWarmupIndex := 0
global WebViewWarmupStarted := false
global DefaultStartTabDDL_Hwnd := 0  ; 默认启动页面下拉框句柄
global DefaultStartTabDDL_Hwnd_ForTimer := 0  ; 默认启动页面下拉框句柄（用于定时器）
global DDLBrush := 0  ; 下拉列表背景画刷
global MoveGUIListBoxHwnd := 0  ; 移动分类弹窗ListBox句柄
global MoveGUIListBoxBrush := 0  ; 移动分类弹窗ListBox画刷
global MoveFromTemplateListBoxHwnd := 0  ; 从模板移动弹窗ListBox句柄
global MoveFromTemplateListBoxBrush := 0  ; 从模板移动弹窗ListBox画刷
global CapsLock2 := false  ; 是否使用过 CapsLock+ 功能标记，使用过会清除这个变量
global CapsLockInitialStateForChord := false  ; 记录按下 CapsLock 前状态，供组合键快速恢复
global VKHoldVisible := false  ; 是否由长按 CapsLock 暂时显示 VK
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
global HotkeyT := "t"  ; 区域截图
global HotkeyP := "p"  ; 截图粘贴
global PromptQuickCaptureHotkey := ""  ; Prompt Quick-Pad 选区采集，留空不注册；可在 CursorShortcut.ini [Settings] PromptQuickCaptureHotkey 配置
global CursorShortcut_CommandPalette := "^+p"
global CursorShortcut_Terminal := "^+``"
global CursorShortcut_GlobalSearch := "^+f"
global CursorShortcut_Explorer := "^+e"
global CursorShortcut_SourceControl := "^+g"
global CursorShortcut_Extensions := "^+x"
global CursorShortcut_Browser := "^+b"
global CursorShortcut_Settings := "^+j"
global CursorShortcut_CursorSettings := "^,"
global PromptQuickPad_CapsLockBSilent := false  ; CapsLock+B 静默入库（ini [PromptQuickPad] CapsLockBSilent=1）
global PromptQuickPad_CapsLockBSilentToTemplate := false  ; 静默时写入模板库 PromptTemplates.ini（否则 prompts.json）
global PromptQuickPad_CapsLockBDefaultTitle := "摘录"
global PromptQuickPad_CapsLockBDefaultCategory := ""
global PromptQuickPad_CapsLockBDefaultTags := ""
; 截图等待粘贴相关变量
global ScreenshotWaiting := false  ; 是否正在等待粘贴截图
global ScreenshotImageDetected := false  ; OnClipboardChange 检测到截图图片
global ScreenshotClipboard := ""  ; 保存的截图剪贴板内容
global ScreenshotOldClipboard := ""  ; 截图流程保存的剪贴板快照
global ScreenshotCheckTimer := 0  ; 截图检测定时器
global g_ExecuteScreenshotWithMenuBusy := false  ; 防重复进入截图流程（避免双重助手/工具栏）
global FloatingToolbar_ScheduleRestoreAfterScreenshot := false  ; 从悬浮条发起截图时，在助手显示前恢复工具栏
global GuiID_ScreenshotButton := 0  ; 截图悬浮按钮 GUI ID
global ScreenshotButtonVisible := false  ; 截图按钮是否可见
global ScreenshotPanelX := -1  ; 截图面板 X 坐标（-1 表示使用默认居中位置）
global ScreenshotPanelY := -1  ; 截图面板 Y 坐标（-1 表示使用默认居中位置）
; 剪贴板智能菜单相关变量
global GuiID_ClipboardSmartMenu := 0  ; 剪贴板智能菜单 GUI ID
; 以下由 modules\ScreenshotEditorPlugin 在 Show/Close 时 _SyncHub() 写回，供 LegacyConfigGui / #HotIf 等使用
global GuiID_ScreenshotEditor := 0  ; 截图助手主窗口
global GuiID_ScreenshotToolbar := 0  ; 截图工具栏窗口
global ScreenshotEditorPreviewPic := 0  ; 预览区 Picture（LegacyConfigGui 右键上下文）
global ScreenshotColorPickerActive := false  ; 取色器开启时 #HotIf（与插件内 static 同步）
global ClipboardMenuButtons := []  ; 按钮数组
global ClipboardMenuSelectedIndex := 0  ; 当前选中的按钮索引
global ClipboardMenuOptions := []  ; 选项数组
global ClipboardMenuHotkeysRegistered := false  ; 热键是否已注册
; 配置变量
global CursorPath := ""
global AISleepTime := 15000
global CapsLockHoldTimeSeconds := 0.5  ; 长按达到该秒数后显示 VK KeyBinder，松手隐藏（若本窗口原已打开则松手不隐藏）
global CapsLockHoldVkEnabled := true  ; 是否启用长按 CapsLock 弹出 VK KeyBinder（设置中心 / ini：CapsLockHoldVkEnabled）
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
global ClipboardPanelScreenIndex := 1  ; 剪贴板管理面板屏幕索引
global PanelX := -1  ; 自定义 X 坐标（-1 表示使用默认位置）
global PanelY := -1  ; 自定义 Y 坐标（-1 表示使用默认位置）
; 连续复制功能
global ClipboardHistory := []  ; 存储所有复制的内容（兼容旧版本，保留）
global ClipboardHistory_CtrlC := []  ; 存储 Ctrl+C 复制的内容
global ClipboardHistory_CapsLockC := []  ; 存储 CapsLock+C 复制的内容
global GuiID_ClipboardManager := 0  ; 剪贴板管理面板 GUI ID
global ClipboardManagementResultLimitDropdown := 0  ; 剪贴板管理结果数量限制下拉菜单
global ClipboardManagementEverythingLimit := 50  ; 剪贴板管理 Everything 搜索限制值
; CapsLock+C 叠加复制计数和存储
global CapsLockCCount := 0  ; 当前阶段的复制计数
global CapsLockCCountTooltip := 0  ; 计数提示 Tooltip 句柄
global CapsLockCItems := []  ; 存储当前阶段 CapsLock+C 复制的所有内容
; SQLite 数据库
global ClipboardDB := 0  ; SQLite 数据库对象
global ClipboardDBPath := A_ScriptDir "\Data\CursorData.db"  ; 数据库文件路径（存储在Data目录，使用CursorData.db确保物理保存）
global ClipboardCurrentTab := "CtrlC"  ; 当前显示的版块："CtrlC" 或 "CapsLockC"
global ClipboardCapsLockCTab := 0  ; CapsLock+C Tab 控件引用
global LastSelectedIndex := 0  ; 最后选中的ListBox项索引，用于刷新后恢复
global ClipboardListViewHighlightedRow := 0  ; ListView 高亮的单元格行索引（从1开始，0表示无高亮）
global ClipboardListViewHighlightedCol := 0  ; ListView 高亮的单元格列索引（从1开始，0表示无高亮）
global ClipboardListViewHwnd := 0  ; ListView 控件句柄，用于 WM_NOTIFY 消息识别
global ClipboardManagerHwnd := 0  ; 剪贴板管理窗口句柄，用于 WM_NOTIFY 消息识别
global ClipboardCurrentCategory := ""  ; 当前选中的分类（空字符串表示全部，不添加过滤条件；其他值：Text, Code, Link, Image等）
global ClipboardCategoryButtons := []  ; 分类标签按钮数组
global ClipboardHighlightOverlay := 0  ; 单元格高亮覆盖层GUI对象
global ClipboardHighlightOverlayBrush := 0  ; 覆盖层画刷句柄（用于清理资源）
; 搜索功能相关变量
global ClipboardSearchMatches := []  ; 搜索匹配项列表 [{RowIndex, ColIndex, ID}]
global ClipboardSearchCurrentIndex := 0  ; 当前匹配项索引（从0开始）
global ClipboardSearchKeyword := ""  ; 当前搜索关键词
global ClipboardSearchTimer := 0  ; 搜索防抖定时器（参考 SearchCenter 的实现）
; 语音输入功能
global VoiceInputActive := false  ; 语音输入是否激活
global GuiID_VoiceInput := 0  ; 语音输入动画GUI ID
global GuiID_VoiceInputPanel := 0  ; 语音输入面板GUI ID
global GuiID_SearchCenter := 0  ; 搜索中心窗口GUI ID
; 搜索中心相关变量
global SearchCenterActiveArea := "input"  ; 当前激活区域："category"、"input" 或 "listview"
global SearchCenterCurrentCategory := 0  ; 当前选中的分类索引（0-based）
global SearchCenterCurrentGroup := 0  ; 当前选中的搜索组索引（0-based）
global SearchCenterSearchEdit := 0  ; 搜索输入框控件
global SearchCenterResultLV := 0  ; 搜索结果 ListView 控件
global SearchCenterCategoryButtons := []  ; 分类标签按钮数组
global SearchCenterSearchResults := []  ; 当前搜索结果数据
global SearchCenterVisibleResults := []  ; 当前结果列表中实际可见的数据
global SearchCenterEngineIcons := []  ; 搜索引擎图标控件数组
global SearchCenterCLIOutputEdit := 0
global SearchCenterCLIRunButton := 0
global SearchCenterCLIClearButton := 0
global SearchCenterCLIOpenButton := 0
global CLIAgentPendingPrompts := Map()
global CLIAgentPromptMonitorRunning := false
; Gemini 就绪：由「非登录态 + 窗口文本连续稳定」判定，非固定秒数；可按机器/习惯改下列参数（Monitor 轮询 500ms）
global CLIGeminiReadyMinMs := 2500
global CLIGeminiStablePollsRequired := 4
global CLIGeminiForceSendAfterMs := 55000
; Windows Terminal 等宿主下 WinGetText 常为空，需「无文本」回退；此前达到该时长后才开始计 EmptyPolls
global CLIGeminiNoTextMinMs := 8000
global SearchCenterResultLimitDropdown := 0  ; 结果数量限制下拉菜单
global SearchCenterResultLimitDDL_Hwnd := 0  ; 搜索中心结果过滤下拉框句柄
global SearchCenterResultLimitDDL_ListHwnd := 0  ; 搜索中心结果过滤下拉列表句柄
global SearchCenterResultLimitDDLBrush := 0  ; 搜索中心结果过滤下拉框画刷
global SearchCenterEverythingLimit := 30  ; Everything 搜索的结果数量限制（默认30）
global FileClassifierUserTrustRoots := []  ; 用户自定义高信任路径前缀（可选，供 FileClassifier.GetPathTrustMultiplier 使用）
global SearchCenterCurrentLimit := 30  ; 当前加载的数据量限制
global SearchCenterHasMoreData := false  ; 是否还有更多数据
global SearchCenterSelectedEngines := []  ; 搜索中心选中的搜索引擎（支持多选）
global SearchCenterSelectedEnginesByCategory := Map()  ; 每个分类的搜索引擎选择状态（分类Key -> 引擎数组）
global SearchCenterHintText := 0  ; 搜索中心操作提示文本控件
global SearchCenterAreaIndicator := 0  ; 搜索中心区域指示器控件（动效）
global SearchCenterInputContainer := 0  ; 搜索中心输入框边框容器控件（Material Design风格）
global SearchCenterFilterType := ""  ; 搜索中心当前过滤类型（空字符串表示全部）
global SearchCenterFilterButtons := []  ; 搜索中心过滤标签按钮数组
global SearchCenterFilterButtonMap := Map()  ; 搜索中心过滤标签按钮映射（FilterType -> 控件）
global GlobalSearchStatement := 0  ; 全局搜索 Statement 对象（用于熔断机制）
global global_ST := 0  ; 全局 Statement 句柄（终极闭环管理）
global SearchDebounceTimer := 0  ; 配置面板/快捷面板搜索防抖（与搜索中心分离，避免互相覆盖）
global SearchCenterDebounceTimer := 0  ; 搜索中心 CapsLock+F 专用防抖
global SearchCenterCapsChord_Debug := false  ; 设为 true 时 OutputDebug 搜索中心 CapsLock+和弦（ISA/GCLS/cmdId/SCWV_Ready）
; 圆环倒计时模块
global LaunchDelaySeconds := 3.0  ; 倒计时时长（秒）
global IsCountdownActive := false  ; 倒计时是否激活
global CountdownGui := 0  ; 倒计时 GUI 对象
global CountdownTimer := 0  ; 倒计时定时器
global CountdownStartTime := 0  ; 倒计时开始时间
global CountdownGraphics := 0  ; GDI+ Graphics 对象
global CountdownBitmap := 0  ; GDI+ Bitmap 对象
global CountdownContent := ""  ; 待粘贴的内容
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
; 配置面板搜索功能相关变量
global SearchTabControls := []  ; 搜索标签页控件数组
global SearchHistoryEdit := 0  ; 搜索输入框控件
global SearchResultsListView := 0  ; 搜索结果ListView控件
global SearchResultsData := Map()  ; 搜索结果数据映射（行索引 -> 结果项）
global SearchResultsCache := Map()  ; 搜索结果缓存
global SearchLastKeyword := ""  ; 上次搜索关键词
global SearchCurrentFilterType := ""  ; 当前过滤类型（空字符串表示全部）
global SearchTypeFilterButtons := []  ; 类型过滤按钮数组
; 窗口拖动状态跟踪（用于防止拖动时组件闪烁）
global WindowDragging := false  ; 是否正在拖动窗口
global DraggingTimers := Map()  ; 存储拖动时需要暂停的定时器 {TimerName: TimerID}
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
global FloatingToolbarButtonItems := ["Search", "Record", "Prompt", "NewPrompt", "Screenshot", "Settings", "VirtualKeyboard"]
global FloatingToolbarMenuItems := ["ToggleToolbar", "MinimizeToEdge", "ResetScale", "SearchCenter", "Clipboard", "OpenConfig", "HideToolbar", "ReloadScript", "ExitApp"]
global FloatingToolbarButtonOptions := [
    Map("id", "Search", "name", "搜索"),
    Map("id", "Record", "name", "记录"),
    Map("id", "Prompt", "name", "提示词"),
    Map("id", "NewPrompt", "name", "草稿本"),
    Map("id", "Screenshot", "name", "截图"),
    Map("id", "Settings", "name", "设置"),
    Map("id", "VirtualKeyboard", "name", "虚拟键盘")
]
global FloatingToolbarMenuOptions := [
    Map("id", "ToggleToolbar", "name", "显示/隐藏工具栏"),
    Map("id", "MinimizeToEdge", "name", "最小化到边缘"),
    Map("id", "ResetScale", "name", "重置大小"),
    Map("id", "SearchCenter", "name", "搜索中心"),
    Map("id", "Clipboard", "name", "剪贴板"),
    Map("id", "OpenConfig", "name", "打开设置"),
    Map("id", "HideToolbar", "name", "关闭工具栏"),
    Map("id", "ReloadScript", "name", "重启脚本"),
    Map("id", "ExitApp", "name", "退出程序")
]

; 激活方式：toolbar=悬浮栏 bubble=悬浮球 tray=后台（仅托盘，无悬浮 UI）
global AppearanceActivationMode := "toolbar"

; ===================== UI 颜色初始化（必须在脚本早期初始化）=====================
; 主题模式：dark（暗色，默认）或 light（亮色）
global ThemeMode := "dark"

; 暗色主题颜色
UI_Colors_Dark := {
    Background: "0a0a0a",      ; html.to.design 风格：深黑色背景
    Sidebar: "1a1a1a",         ; html.to.design 风格：侧边栏深灰色
    Border: "333333",          ; html.to.design 风格：边框深灰色
    Text: "f5f5f5",            ; html.to.design 风格：主文本浅灰色
    TextDim: "888888",         ; html.to.design 风格：次要文本中灰色
    InputBg: "1a1a1a",         ; html.to.design 风格：输入框背景
    DDLBg: "1a1a1a",           ; html.to.design 风格：下拉框背景
    DDLBorder: "333333",       ; html.to.design 风格：下拉框边框
    DDLText: "f5f5f5",         ; html.to.design 风格：下拉框文本
    DDLHover: "2a2a2a",        ; html.to.design 风格：下拉框悬停
    BtnBg: "1a1a1a",           ; html.to.design 风格：按钮背景
    BtnHover: "2a2a2a",        ; html.to.design 风格：按钮悬停
    BtnPrimary: "e67e22",      ; html.to.design 风格：主按钮橙色
    BtnPrimaryHover: "d35400", ; html.to.design 风格：主按钮悬停深橙色
    BtnDanger: "e81123",       ; 保持红色危险按钮
    BtnDangerHover: "c50e1f",  ; 保持红色危险按钮悬停
    TabActive: "2a2a2a",       ; html.to.design 风格：激活标签
    TitleBar: "1a1a1a"         ; html.to.design 风格：标题栏
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

    ; 更新下拉菜单画刷（如果下拉菜单已创建）
    UpdateDefaultStartTabDDLBrush()
    UpdateSearchCenterResultLimitDDLBrush()
}

; ===================== 更新默认启动页面下拉菜单画刷 =====================
UpdateDefaultStartTabDDLBrush() {
    global DefaultStartTabDDL_Hwnd, DDLBrush, UI_Colors, ThemeMode

    ; 如果下拉菜单未创建，直接返回
    if (!DefaultStartTabDDL_Hwnd || DefaultStartTabDDL_Hwnd = 0) {
        return
    }

    try {
        ; 根据主题模式设置颜色（使用 html.to.design 风格配色）
        if (ThemeMode = "dark") {
            ColorCode := "0x" . UI_Colors.DDLBg  ; html.to.design 风格背景
        } else {
            ColorCode := "0x" . UI_Colors.DDLBg  ; 亮色模式背景
        }
        RGBColor := Integer(ColorCode)
        ; 交换R和B字节（Windows使用BGR格式）
        R := (RGBColor & 0xFF0000) >> 16
        G := (RGBColor & 0x00FF00) >> 8
        B := RGBColor & 0x0000FF
        BGRColor := (B << 16) | (G << 8) | R

        ; 如果已有画刷，先删除
        if (DDLBrush != 0) {
            try {
                DllCall("gdi32.dll\DeleteObject", "Ptr", DDLBrush)
            } catch as err {
            }
        }
        ; 创建新的实心画刷
        DDLBrush := DllCall("gdi32.dll\CreateSolidBrush", "UInt", BGRColor, "Ptr")

        ; 强制刷新下拉菜单
        try {
            DllCall("user32.dll\InvalidateRect", "Ptr", DefaultStartTabDDL_Hwnd, "Ptr", 0, "Int", 1)
            DllCall("user32.dll\UpdateWindow", "Ptr", DefaultStartTabDDL_Hwnd)
        } catch as err {
        }
    } catch as err {
    }
}

; ===================== 更新搜索中心结果限制下拉菜单画刷 =====================
UpdateSearchCenterResultLimitDDLBrush() {
    global SearchCenterResultLimitDDL_Hwnd, SearchCenterResultLimitDDL_ListHwnd, SearchCenterResultLimitDDLBrush

    ; 如果下拉菜单未创建，直接返回
    if (!SearchCenterResultLimitDDL_Hwnd || SearchCenterResultLimitDDL_Hwnd = 0) {
        return
    }

    try {
        ; 搜索中心下拉框固定使用白底，避免暗色主题下弹层出现黑块
        ColorCode := "0xFFFFFF"
        RGBColor := Integer(ColorCode)
        ; 交换R和B字节（Windows使用BGR格式）
        R := (RGBColor & 0xFF0000) >> 16
        G := (RGBColor & 0x00FF00) >> 8
        B := RGBColor & 0x0000FF
        BGRColor := (B << 16) | (G << 8) | R

        ; 如果已有画刷，先删除
        if (SearchCenterResultLimitDDLBrush != 0) {
            try {
                DllCall("gdi32.dll\DeleteObject", "Ptr", SearchCenterResultLimitDDLBrush)
            } catch as err {
            }
        }
        ; 创建新的实心画刷
        SearchCenterResultLimitDDLBrush := DllCall("gdi32.dll\CreateSolidBrush", "UInt", BGRColor, "Ptr")

        ; 强制刷新下拉菜单
        try {
            DllCall("user32.dll\InvalidateRect", "Ptr", SearchCenterResultLimitDDL_Hwnd, "Ptr", 0, "Int", 1)
            DllCall("user32.dll\UpdateWindow", "Ptr", SearchCenterResultLimitDDL_Hwnd)
        } catch as err {
        }
    } catch as err {
    }
}

CleanupSearchCenterResultLimitDDLBrush() {
    global SearchCenterResultLimitDDLBrush, SearchCenterResultLimitDDL_Hwnd, SearchCenterResultLimitDDL_ListHwnd

    try {
        if (SearchCenterResultLimitDDLBrush != 0) {
            DllCall("gdi32.dll\DeleteObject", "Ptr", SearchCenterResultLimitDDLBrush)
            SearchCenterResultLimitDDLBrush := 0
        }
    } catch as err {
    }

    SearchCenterResultLimitDDL_Hwnd := 0
    SearchCenterResultLimitDDL_ListHwnd := 0
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
            "capslock_hold_time_hint", "长按 CapsLock 达到该时长后显示 VK KeyBinder 快捷键设置界面，松开 CapsLock 后自动隐藏。范围：0.1–5.0 秒，默认 0.5。若已通过托盘打开键盘，松手不会关闭该窗口。",
            "capslock_hold_time_error", "CapsLock 长按时间必须在 0.1 到 5.0 秒之间",
            "ai_wait_time", "AI 响应等待时间 (毫秒):",
            "countdown_delay", "倒计时延迟时间 (秒):",
            "countdown_delay_hint", "设置粘贴操作前的倒计时时长，范围：0.5-10.0 秒，默认：3.0 秒",
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
            "hotkey_t", "区域截图 (T):",
            "hotkey_t_desc", "按此键可启动区域截图功能，选择截图区域后，会自动将截图粘贴到 Cursor 输入框。",
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
            "clipboard_panel_screen", "剪贴板管理面板显示器:",
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
            "search_engine_cli_codex", "Codex",
            "search_engine_cli_gemini", "Gemini",
            "search_engine_cli_openclaw", "OpenClaw",
            "search_engine_cli_qwen", "Qwen",
            "search_category_ai", "AI",
            "search_category_cli", "CLI",
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
            "cursor_rules_import_btn", "导入规则",
            "cursor_rules_imported", "规则已导入！",
            "cursor_rules_import_failed", "导入规则失败",
            "cursor_rules_file_not_found", "未找到 Programming Rules.txt 文件",
            "cursor_rules_export_btn", "导出到文件",
            "cursor_rules_exported", "规则已导出到 .cursorrules 文件！",
            "cursor_rules_export_failed", "导出规则失败",
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
            "countdown_delay", "Countdown Delay (seconds):",
            "countdown_delay_hint", "Set the countdown duration before paste operation, range: 0.5-10.0 seconds, default: 3.0 seconds",
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
            "capslock_hold_time_hint", "Hold CapsLock for this long to show the VK KeyBinder shortcut UI; it hides when you release CapsLock. Range: 0.1–5.0 s, default 0.5. If VK was already opened from the tray, releasing CapsLock will not close it.",
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
            "hotkey_t", "Screenshot (T):",
            "hotkey_t_desc", "Press this key to start area screenshot. After selecting the area, the screenshot will be automatically pasted into Cursor's input box.",
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
            "search_engine_cli_codex", "Codex",
            "search_engine_cli_gemini", "Gemini",
            "search_engine_cli_openclaw", "OpenClaw",
            "search_engine_cli_qwen", "Qwen",
            "search_category_ai", "AI",
            "search_category_cli", "CLI",
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
            "cursor_rules_import_btn", "Import Rules",
            "cursor_rules_imported", "Rules imported!",
            "cursor_rules_import_failed", "Failed to import rules",
            "cursor_rules_file_not_found", "Programming Rules.txt file not found",
            "cursor_rules_export_btn", "Export to File",
            "cursor_rules_exported", "Rules exported to .cursorrules file!",
            "cursor_rules_export_failed", "Failed to export rules",
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
    
    ; 兜底：自动执行尚未跑到后部 global Language 时，避免未赋值/空串
    if !IsSet(Language) || Language = ""
        Language := "zh"
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
        } catch as err {
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
    } catch as err {
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
    
    ; 同步到数据库
    SyncPromptTemplatesToDB()

    try VK_OnPromptTemplatesSaved()
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

; ===================== 初始化剪贴板数据库（Raycast 级架构）=====================
InitClipboardDB() {
    global ClipboardDB, ClipboardDBPath
    
    ; 1. 自动创建目录
    if !DirExist(A_ScriptDir "\Data") {
        DirCreate(A_ScriptDir "\Data")
    }
    
    ; 设置数据库文件路径（使用 CursorData.db 确保物理保存）
    ClipboardDBPath := A_ScriptDir "\Data\CursorData.db"
    
    ; 2. 检查 sqlite3.dll 是否存在
    DllPath := A_ScriptDir "\sqlite3.dll"
    if (!FileExist(DllPath)) {
        MsgBox("sqlite3.dll 未找到。`n请确保 sqlite3.dll 与脚本位于同一目录。", "数据库初始化错误", "IconX")
        ClipboardDB := 0
        return
    }
    
    ; 3. 创建 SQLiteDB 实例并打开数据库
    try {
        ClipboardDB := SQLiteDB()
        if (!ClipboardDB.OpenDB(ClipboardDBPath)) {
            MsgBox("无法打开数据库: " . ClipboardDBPath . "`n错误: " . ClipboardDB.ErrorMsg, "数据库初始化错误", "IconX")
            ClipboardDB := 0
            return
        }
        
        ; 4. 重写建表逻辑：彻底清除旧结构
        SQL := "DROP TABLE IF EXISTS ClipboardHistory;"
        if (!ClipboardDB.Exec(SQL)) {
            MsgBox("删除旧表失败: " . ClipboardDB.ErrorMsg, "数据库初始化错误", "IconX")
            ClipboardDB.CloseDB()
            ClipboardDB := 0
            return
        }
        
        ; 5. 创建全新的 ClipboardHistory 表（11字段架构，废弃 SessionID 和 ItemIndex）
        ; Content: 文本、代码或本地文件路径
        ; DataType: 分类: Text, Code, Link, Image, File, Email
        ; SourceApp: 程序名 (chrome.exe)
        ; SourceTitle: 窗口标题
        ; SourcePath: 程序完整路径 (用于提取图标)
        ; CharCount: 字符数
        ; WordCount: 词数
        ; Timestamp: 时间戳
        ; MetaData: JSON 格式扩展数据
        ; IsPinned: 收藏/置顶
        SQL := "CREATE TABLE ClipboardHistory (" .
               "ID INTEGER PRIMARY KEY AUTOINCREMENT, " .
               "Timestamp DATETIME DEFAULT (datetime('now', 'localtime')), " .
               "Content TEXT, " .
               "DataType TEXT, " .
               "SourceApp TEXT, " .
               "SourceTitle TEXT, " .
               "SourcePath TEXT, " .
               "CharCount INTEGER, " .
               "WordCount INTEGER, " .
               "MetaData TEXT, " .
               "IsPinned INTEGER DEFAULT 0)"
        
        if (!ClipboardDB.Exec(SQL)) {
            MsgBox("创建数据库表失败: " . ClipboardDB.ErrorMsg, "数据库初始化错误", "IconX")
            ClipboardDB.CloseDB()
            ClipboardDB := 0
            return
        }
        
        ; 5.1. 兼容性处理：如果表已存在但包含 SessionID 或 ItemIndex 字段，删除它们
        ; 注意：由于上面已经 DROP TABLE，这个检查主要是为了处理其他可能的场景
        try {
            ResultTable := ""
            if (ClipboardDB.GetTable("PRAGMA table_info(ClipboardHistory)", &ResultTable)) {
                HasSessionID := false
                HasItemIndex := false
                if (ResultTable && ResultTable.HasProp("Rows")) {
                    for Index, Row in ResultTable.Rows {
                        if (Row.Length > 1 && Row[2] = "SessionID") {  ; Row[2] 是字段名
                            HasSessionID := true
                        }
                        if (Row.Length > 1 && Row[2] = "ItemIndex") {
                            HasItemIndex := true
                        }
                    }
                }
                
                ; 如果存在旧字段，删除它们（SQLite 不支持直接删除列，需要重建表）
                if (HasSessionID || HasItemIndex) {
                    ; 由于 SQLite 不支持 ALTER TABLE DROP COLUMN，这里只记录日志
                    ; 实际删除会在下次 DROP TABLE 时完成
                    try {
                        FileAppend("[" . FormatTime(, "yyyy-MM-dd HH:mm:ss") . "] InitClipboardDB: 检测到旧字段 SessionID/ItemIndex，将在下次重建表时移除`n", A_ScriptDir "\clipboard_debug.log")
                    } catch {
                    }
                }
            }
        } catch as err {
            ; 如果字段检查失败，忽略错误（可能表结构已经是新的）
            try {
                FileAppend("[" . FormatTime(, "yyyy-MM-dd HH:mm:ss") . "] InitClipboardDB: 字段检查异常 - " . err.Message . "`n", A_ScriptDir "\clipboard_debug.log")
            } catch {
            }
        }
        
        ; 6. 全局对象规范：验证 ClipboardDB 已正确初始化
        if (!IsObject(ClipboardDB) || ClipboardDB = 0) {
            ErrorMsg := "ClipboardDB 对象未正确创建"
            if (IsObject(ClipboardDB) && ClipboardDB.HasProp("ErrorMsg")) {
                ErrorMsg .= "`n错误: " . ClipboardDB.ErrorMsg
            }
            MsgBox("数据库初始化失败：" . ErrorMsg, "数据库初始化错误", "IconX")
            ClipboardDB := 0
            return
        }
        
        ; 7. 创建索引以提升查询性能
        SQL := "CREATE INDEX IF NOT EXISTS idx_clipboard_timestamp ON ClipboardHistory(Timestamp DESC)"
        if (!ClipboardDB.Exec(SQL)) {
            MsgBox("创建时间戳索引失败: " . ClipboardDB.ErrorMsg, "数据库初始化错误", "IconX")
        }
        
        SQL := "CREATE INDEX IF NOT EXISTS idx_clipboard_content ON ClipboardHistory(Content COLLATE NOCASE)"
        if (!ClipboardDB.Exec(SQL)) {
            MsgBox("创建内容索引失败: " . ClipboardDB.ErrorMsg, "数据库初始化错误", "IconX")
        }
        
        SQL := "CREATE INDEX IF NOT EXISTS idx_clipboard_datatype ON ClipboardHistory(DataType COLLATE NOCASE)"
        if (!ClipboardDB.Exec(SQL)) {
            MsgBox("创建数据类型索引失败: " . ClipboardDB.ErrorMsg, "数据库初始化错误", "IconX")
        }
        
        SQL := "CREATE INDEX IF NOT EXISTS idx_clipboard_sourceapp ON ClipboardHistory(SourceApp COLLATE NOCASE)"
        if (!ClipboardDB.Exec(SQL)) {
            MsgBox("创建来源应用索引失败: " . ClipboardDB.ErrorMsg, "数据库初始化错误", "IconX")
        }
        
        SQL := "CREATE INDEX IF NOT EXISTS idx_clipboard_ispinned ON ClipboardHistory(IsPinned)"
        if (!ClipboardDB.Exec(SQL)) {
            MsgBox("创建置顶索引失败: " . ClipboardDB.ErrorMsg, "数据库初始化错误", "IconX")
        }
        
        ; 7.1. SessionID 模式已废弃，不再需要初始化
        
        ; 8. 创建 Prompts 表（如果不存在）- 用于存储提示词模板
        SQL := "CREATE TABLE IF NOT EXISTS Prompts (ID TEXT PRIMARY KEY, Title TEXT NOT NULL COLLATE NOCASE, Content TEXT NOT NULL, Category TEXT COLLATE NOCASE, Timestamp DATETIME DEFAULT CURRENT_TIMESTAMP)"
        if (!ClipboardDB.Exec(SQL)) {
            MsgBox("创建 Prompts 表失败: " . ClipboardDB.ErrorMsg, "数据库初始化错误", "IconX")
        }
        
        ; 9. 创建统一搜索视图 v_GlobalSearch
        ClipboardDB.Exec("DROP VIEW IF EXISTS v_GlobalSearch")
        SQL := "CREATE VIEW v_GlobalSearch AS " .
               "SELECT " .
               "  Title, " .
               "  Content, " .
               "  'prompt' AS Source, " .
               "  Timestamp, " .
               "  ID AS OriginalID " .
               "FROM Prompts " .
               "UNION ALL " .
               "SELECT " .
               "  SUBSTR(Content, 1, 100) AS Title, " .
               "  Content, " .
               "  'clipboard' AS Source, " .
               "  Timestamp, " .
               "  CAST(ID AS TEXT) AS OriginalID " .
               "FROM ClipboardHistory"
        if (!ClipboardDB.Exec(SQL)) {
            MsgBox("创建搜索视图失败: " . ClipboardDB.ErrorMsg, "数据库初始化错误", "IconX")
        }
        
        ; 为 Prompts 表创建索引
        SQL := "CREATE INDEX IF NOT EXISTS idx_prompts_title ON Prompts(Title COLLATE NOCASE)"
        ClipboardDB.Exec(SQL)
        SQL := "CREATE INDEX IF NOT EXISTS idx_prompts_content ON Prompts(Content COLLATE NOCASE)"
        ClipboardDB.Exec(SQL)
        SQL := "CREATE INDEX IF NOT EXISTS idx_prompts_category ON Prompts(Category COLLATE NOCASE)"
        ClipboardDB.Exec(SQL)
        
    } catch as e {
        ; 检查是否是类不存在的错误
        if (InStr(e.Message, "SQLiteDB") || InStr(e.Message, "does not contain a recognized action")) {
            MsgBox("Class_SQLiteDB.ahk 类文件未找到或无效。`n请从以下地址下载正确的文件：`nhttps://raw.githubusercontent.com/AHK-just-me/Class_SQLiteDB/master/Sources_v1.1/Class_SQLiteDB.ahk`n`n将文件保存为 Class_SQLiteDB.ahk 并放在脚本同目录下。", "数据库初始化错误", "IconX")
        } else {
            MsgBox("初始化数据库时发生异常: " . e.Message, "数据库初始化错误", "IconX")
        }
        ClipboardDB := 0
    }
}

; ===================== 同步提示词模板到数据库 =====================
SyncPromptTemplatesToDB() {
    global ClipboardDB, PromptTemplates, global_ST
    
    if (!ClipboardDB || ClipboardDB = 0) {
        return
    }
    
    if (!IsSet(PromptTemplates) || PromptTemplates.Length = 0) {
        return
    }
    
    ; 【入口强制释放】在调用 DB.Prepare 之前，必须执行强制释放
    if (IsObject(global_ST) && global_ST.HasProp("Free")) {
        try {
            global_ST.Free()
        } catch as err {
        }
        global_ST := 0
    }
    
    ST := ""
    try {
        ; 使用 INSERT OR REPLACE 来同步模板
        SQL := "INSERT OR REPLACE INTO Prompts (ID, Title, Content, Category, Timestamp) VALUES (?, ?, ?, ?, CURRENT_TIMESTAMP)"
        
        if (!ClipboardDB.Prepare(SQL, &ST)) {
            return
        }
        
        ; 更新全局句柄
        global_ST := ST
        
        if (!IsObject(ST) || !ST.HasProp("Bind")) {
            return
        }
        
        for Index, Template in PromptTemplates {
            if (!ST.Bind(1, "Text", Template.ID)) {
                continue
            }
            if (!ST.Bind(2, "Text", Template.Title)) {
                continue
            }
            if (!ST.Bind(3, "Text", Template.Content)) {
                continue
            }
            Category := Template.HasProp("Category") ? Template.Category : ""
            if (!ST.Bind(4, "Text", Category)) {
                continue
            }
            
            ST.Step()
            ST.Reset()
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
}

; ===================== 激活方式规范化 =====================
NormalizeAppearanceActivationMode(v) {
    s := Trim(String(v))
    if (s = "bubble" || s = "tray" || s = "toolbar")
        return s
    return "toolbar"
}


; 根据「外观 · 激活方式」显示悬浮栏 / 悬浮球 / 或仅托盘
ApplyAppearanceActivationMode() {
    global AppearanceActivationMode
    m := NormalizeAppearanceActivationMode(AppearanceActivationMode)
    if (m = "toolbar") {
        try FloatingBubble_DestroyCompletely()
        catch {
        }
        try ShowFloatingToolbar()
        catch {
        }
        return
    }
    if (m = "bubble") {
        try HideFloatingToolbar()
        catch {
        }
        try ShowFloatingBubble()
        catch {
        }
        return
    }
    try HideFloatingToolbar()
    catch {
    }
    try FloatingBubble_DestroyCompletely()
    catch {
    }
}

; 选区/牛马等需要宿主表面已显示时调用：按激活方式打开悬浮栏或悬浮球（后台模式不弹出）
EnsureFloatingSurfaceVisible() {
    global AppearanceActivationMode
    m := NormalizeAppearanceActivationMode(AppearanceActivationMode)
    if (m = "toolbar") {
        try ShowFloatingToolbar()
        catch {
        }
    } else if (m = "bubble") {
        try ShowFloatingBubble()
        catch {
        }
    }
}

; 在InitConfig结束后加载模板
BuildAppLocalUrl(relativePath) {
    global UnifiedAssetsHost
    normalized := StrReplace(relativePath, "\", "/")
    if (SubStr(normalized, 1, 1) = "/")
        normalized := SubStr(normalized, 2)
    return "https://" . UnifiedAssetsHost . "/" . normalized
}

BuildAppAssetUrl(relativePath) {
    normalized := StrReplace(relativePath, "\", "/")
    if (SubStr(normalized, 1, 1) = "/")
        normalized := SubStr(normalized, 2)
    if (SubStr(normalized, 1, 7) = "assets/")
        return BuildAppLocalUrl(normalized)
    return BuildAppLocalUrl("assets/" . normalized)
}

ApplyUnifiedWebViewAssets(wv2) {
    global UnifiedAssetsHost, UnifiedAssetsRoot, UnifiedAssetsAccessKind
    try wv2.SetVirtualHostNameToFolderMapping(UnifiedAssetsHost, UnifiedAssetsRoot, UnifiedAssetsAccessKind)
}

WebView_DumpJson(payload) {
    try return Jxon_Dump(payload)
    catch as err {
        OutputDebug("[WebView] Jxon_Dump failed: " . err.Message)
        return ""
    }
}

WebView_QueueJson(wv2, jsonStr) {
    global WebViewMsgQueue
    if !wv2 || jsonStr = ""
        return
    WebViewMsgQueue.Push(Map("wv2", wv2, "json", jsonStr))
    _WebView_QueueKick()
}

WebView_QueuePayload(wv2, payload) {
    global WebViewMsgQueue
    if !wv2
        return
    WebViewMsgQueue.Push(Map("wv2", wv2, "payload", payload))
    _WebView_QueueKick()
}

FuncExists(fnName) {
    try {
        Func(fnName)
        return true
    } catch as _e {
        return false
    }
}

_WebView_QueueKick() {
    global WebViewMsgQueueActive
    if WebViewMsgQueueActive
        return
    WebViewMsgQueueActive := true
    SetTimer(_WebView_QueueFlush, -10)
}

_WebView_QueueFlush(*) {
    global WebViewMsgQueue, WebViewMsgQueueActive
    if (WebViewMsgQueue.Length = 0) {
        WebViewMsgQueueActive := false
        return
    }
    item := WebViewMsgQueue.RemoveAt(1)
    jsonStr := ""
    if (item.Has("json")) {
        jsonStr := item["json"]
    } else if (item.Has("payload")) {
        jsonStr := WebView_DumpJson(item["payload"])
    }
    if (jsonStr != "") {
        try item["wv2"].PostWebMessageAsJson(jsonStr)
    }
    SetTimer(_WebView_QueueFlush, -10)
}

_WarmupConfigWebView(*) {
    global UseWebViewSettings
    if !UseWebViewSettings
        return
    try ConfigWebView_CreateHost()
}

_RunWebViewWarmupStep(*) {
    global WebViewWarmupQueue, WebViewWarmupIndex
    if (WebViewWarmupIndex >= WebViewWarmupQueue.Length)
        return

    WebViewWarmupIndex += 1
    initFn := WebViewWarmupQueue[WebViewWarmupIndex]
    try initFn.Call()

    if (WebViewWarmupIndex < WebViewWarmupQueue.Length)
        SetTimer(_RunWebViewWarmupStep, -350)
}

_WV2_BeginWarmupAfterEnv(*) {
    global WebViewWarmupQueue, WebViewWarmupIndex
    WebViewWarmupIndex := 0
    WebViewWarmupQueue := [CP_Init, PQP_Init, SCWV_Init, VK_EnsureInit.Bind(true)]
    SetTimer(_RunWebViewWarmupStep, -10)
    SetTimer(_WarmupConfigWebView, -5000)
}

Global_InitAllPanels(*) {
    global WebViewWarmupStarted

    if WebViewWarmupStarted
        return

    WebViewWarmupStarted := true
    WebView2_InitSharedEnvAsync(_WV2_BeginWarmupAfterEnv)
}

StartWebViewWarmup(*) {
    Global_InitAllPanels()
}

#Include modules\ConfigManager.ahk
InitConfig() ; 启动初始化
; 启动时统一归一化 CapsLock 状态，避免继承系统残留 On 状态导致后续组合键流程反复恢复为大写
SetCapsLockState("Off")
PromptQuickPad_ReloadCapsLockBSettings()
; 初始化剪贴板数据库（在配置初始化后）
InitClipboardDB()
; 初始化 Everything 服务（在数据库初始化后）
InitEverythingService()
; 初始化新的剪贴板管理器数据库（FTS5）
InitClipboardFTS5DB()
; 初始化粘贴板历史面板
InitClipboardHistoryPanel()
; 初始化 WebView2 剪贴板面板
SetTimer(Global_InitAllPanels, -1200)
; 初始化悬浮工具栏
InitFloatingToolbar()
InitFloatingBubble()
; 按「激活方式」显示悬浮栏 / 悬浮球 / 或仅托盘
ApplyAppearanceActivationMode()
SetTimer(AutoStartTtydForNiumaChat, -1800)
GravityPump_Register()
SelectionSense_Init()
; 加载提示词模板系统（在配置初始化后）
LoadPromptTemplates()
; 同步提示词模板到数据库
SyncPromptTemplatesToDB()
; Prompt Quick-Pad：选区采集热键（需在 CursorShortcut.ini [Settings] 中设置 PromptQuickCaptureHotkey，如 ^!p）
PromptQuickPad_RegisterCaptureHotkey()

; ===================== 剪贴板变化监听 =====================
; 注意：OnClipboardChange 必须在脚本启动时注册，确保在 InitConfig 之后定义
; 监听 Ctrl+C 复制操作，自动记录到 Ctrl+C 历史记录
global LastClipboardContent := ""  ; 记录上次剪贴板内容，避免重复记录
global CapsLockCopyInProgress := false  ; 标记 CapsLock+C 是否正在进行中
global CapsLockCopyEndTime := 0  ; CapsLock+C 结束时间，用于延迟检测
global ClipboardChangeDebounceTimer := 0  ; 剪贴板变化防抖定时器
global PendingClipboardType := 0  ; 待处理的剪贴板类型
global PendingClipboardContent := ""  ; 待处理的剪贴板内容

; 注册剪贴板变化监听器
OnClipboardChange(OnClipboardChangeHandler, 1)  ; 1 表示添加监听器

; ===================== 图片保存函数 =====================
; 图片持久化管理：使用 Gdip 将剪贴板位图保存，确保 DisposeImage 释放资源
; 路径：A_ScriptDir "\Data\Images\IMG_" A_Now ".png"
; 返回：成功返回完整路径，失败返回空字符串
SaveClipboardImage() {
    ImgDir := A_ScriptDir "\Data\Images"
    if !DirExist(ImgDir)
        DirCreate(ImgDir)
    
    FilePath := ImgDir "\IMG_" A_Now ".png"
    pBitmap := Gdip_CreateBitmapFromClipboard()
    if (pBitmap > 0) {
        Gdip_SaveBitmapToFile(pBitmap, FilePath)
        Gdip_DisposeImage(pBitmap)
        return FilePath
    }
    return ""
}

DeferredScreenshotHistorySave(clipData := "") {
    global ScreenshotClipboard, ClipboardDB, ClipboardFTS5DB
    data := (clipData != "") ? clipData : ScreenshotClipboard
    if (!data)
        return
    OldClip := ClipboardAll()
    try {
        A_Clipboard := data
        Sleep(80)
        imgPath := SaveClipboardImage()
        if (imgPath != "") {
            if (ClipboardDB && ClipboardDB != 0)
                SaveToDB(imgPath, "Image", "CursorHelper", "", "", StrLen(imgPath), 1)
            if (ClipboardFTS5DB && ClipboardFTS5DB != 0)
                CaptureImageFileToFTS5(imgPath, "CursorHelper")
        }
    } catch {
    }
    try {
        A_Clipboard := OldClip
    } catch {
    }
}

; ===================== 规范入库与排重函数 =====================
; ===================== 智能分拣剪贴板内容 =====================
; 对文本进行智能分类和环境捕获
ClassifyClipboardContent(content) {
    ; 初始化返回结果
    result := Map()
    result["DataType"] := "Text"
    result["CharCount"] := 0
    result["WordCount"] := 0
    
    ; 如果内容为空，返回默认值
    if (content = "" || StrLen(content) = 0) {
        return result
    }
    
    ; 计算字符数和词数
    trimmedContent := Trim(content, " `t`r`n")
    result["CharCount"] := StrLen(trimmedContent)
    
    ; 计算词数（去除标点符号后按空格分割）
    words := StrSplit(RegExReplace(trimmedContent, "[^\w\s]+", ""), " ")
    result["WordCount"] := words.Length
    
    ; 智能分类：对选中的文本进行正则判定
    ; 1. 链接检测 (Link)
    if (RegExMatch(trimmedContent, "i)^(https?:\/\/|www\.)[^\s]+$")) {
        result["DataType"] := "Link"
    }
    ; 2. 邮箱检测 (Email)
    else if (RegExMatch(trimmedContent, "i)^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$")) {
        result["DataType"] := "Email"
    }
    ; 3. 代码检测 (Code) - 检测常见的代码特征
    else if (RegExMatch(trimmedContent, "[\{\}\[\]\(\);]|=>|:=|function|const|import|class|def|return|var|let")) {
        result["DataType"] := "Code"
    }
    ; 4. 默认文本 (Text)
    else {
        result["DataType"] := "Text"
    }
    
    return result
}

; ===================== 捕获环境信息 =====================
CaptureEnvironmentInfo() {
    envInfo := Map()
    envInfo["SourceApp"] := "Unknown"
    envInfo["SourceTitle"] := ""
    envInfo["SourcePath"] := ""
    
    try {
        ; 获取当前活动窗口ID
        ActiveID := WinGetID("A")
        
        ; 获取进程名
        try {
            envInfo["SourceApp"] := WinGetProcessName(ActiveID)
        } catch as err {
            envInfo["SourceApp"] := "Unknown"
        }
        
        ; 获取窗口标题
        try {
            envInfo["SourceTitle"] := WinGetTitle(ActiveID)
        } catch as err {
            envInfo["SourceTitle"] := ""
        }
        
        ; 获取进程路径
        try {
            envInfo["SourcePath"] := WinGetProcessPath(ActiveID)
        } catch as err {
            envInfo["SourcePath"] := ""
        }
    } catch as e {
        ; 捕获失败，使用默认值
    }
    
    return envInfo
}

; ===================== 保存剪贴板数据到数据库（11字段架构，废弃 SessionID 模式） =====================
SaveToDB(content, type, app, title, path, cCount, wCount) {
    global ClipboardDB  ; 必须声明全局，否则函数内部找不到数据库句柄
    if (!ClipboardDB || ClipboardDB = 0) {
        InitClipboardDB() ; 如果连接断开，尝试重新初始化
    }

    ; 排重检查：获取最后一条内容
    try {
        recordSet := ClipboardDB.GetTable("SELECT Content FROM ClipboardHistory ORDER BY ID DESC LIMIT 1")
        if (recordSet.HasNames && recordSet.Rows.Length > 0 && recordSet.Rows[1][1] = content)
            return ; 内容重复，直接返回不写入
    }

    ; 构造 SQL：严格按照 11 字段架构，禁止手动插入 ID（由 AUTOINCREMENT 自动处理）
    sql := "INSERT INTO ClipboardHistory " .
           "(Content, DataType, SourceApp, SourceTitle, SourcePath, CharCount, WordCount, Timestamp) " .
           "VALUES (" .
           "'" . StrReplace(content, "'", "''") . "', " .
           "'" . type . "', " .
           "'" . StrReplace(app, "'", "''") . "', " .
           "'" . StrReplace(title, "'", "''") . "', " .
           "'" . StrReplace(path, "'", "''") . "', " .
           cCount . ", " . wCount . ", " .
           "datetime('now', 'localtime'))"

    try {
        ClipboardDB.Exec(sql) ; 执行物理写入
    } catch as err {
        ; 记录错误日志，防止静默失败
        FileAppend(A_Now ": SQL Error " err.Message "`n", "db_error.log")
    }
}

; ===================== 剪贴板变化监听器（带防抖功能）=====================
; 回调函数，用于注册到 OnClipboardChange
; 具备防抖功能：在短时间内多次触发时，只执行最后一次
OnClipboardChangeHandler(Type) {
    global ClipboardDB, ClipboardFTS5DB, CapsLockCopyInProgress
    global ClipboardChangeDebounceTimer, PendingClipboardType, PendingClipboardContent
    global ScreenshotWaiting, ScreenshotImageDetected

    if (CapsLockCopyInProgress) {
        return
    }

    ; 截图等待期间：图片写入剪贴板时立即通知检测循环，跳过常规处理以避免剪贴板竞争
    if (ScreenshotWaiting && Type = 2) {
        ScreenshotImageDetected := true
        return
    }

    if (Type = 0 || A_PtrSize = "")
        return

    ; 防抖处理：清除之前的定时器
    if (ClipboardChangeDebounceTimer != 0) {
        try {
            SetTimer(ClipboardChangeDebounceTimer, 0)  ; 清除定时器
        } catch {
        }
    }

    ; 保存当前剪贴板类型和内容（用于防抖延迟执行）
    PendingClipboardType := Type
    if (Type = 1) { ; 文本类型
        try {
            PendingClipboardContent := A_Clipboard
        } catch {
            PendingClipboardContent := ""
        }
    } else {
        PendingClipboardContent := ""
    }

    ; 设置防抖定时器（300毫秒延迟，避免频繁触发）
    ClipboardChangeDebounceTimer := (*) => ProcessClipboardChange()
    SetTimer(ClipboardChangeDebounceTimer, -300)  ; 300毫秒后执行
}

GetClipboardFileDropList() {
    fileList := ""
    cfHDrop := 15
    if !DllCall("OpenClipboard", "Ptr", 0)
        return ""
    try {
        hDrop := DllCall("GetClipboardData", "UInt", cfHDrop, "Ptr")
        if !hDrop
            return ""
        fileCount := DllCall("Shell32\DragQueryFileW", "Ptr", hDrop, "UInt", 0xFFFFFFFF, "Ptr", 0, "UInt", 0, "UInt")
        if (fileCount < 1)
            return ""
        Loop fileCount {
            pathLen := DllCall("Shell32\DragQueryFileW", "Ptr", hDrop, "UInt", A_Index - 1, "Ptr", 0, "UInt", 0, "UInt")
            if (pathLen < 1)
                continue
            buf := Buffer((pathLen + 1) * 2, 0)
            readLen := DllCall("Shell32\DragQueryFileW", "Ptr", hDrop, "UInt", A_Index - 1, "Ptr", buf.Ptr, "UInt", pathLen + 1, "UInt")
            if (readLen < 1)
                continue
            onePath := StrGet(buf, "UTF-16")
            if (onePath != "")
                fileList .= (fileList = "" ? "" : "`n") . onePath
        }
    } finally {
        DllCall("CloseClipboard")
    }
    return fileList
}

; ===================== 处理剪贴板变化（防抖后的实际处理函数）=====================
ProcessClipboardChange() {
    global ClipboardDB, ClipboardFTS5DB, PendingClipboardType, PendingClipboardContent

    Type := PendingClipboardType
    if (Type = 0 || A_PtrSize = "")
        return

    try {
        ; 1. 捕获环境信息（获取当前活动窗口的进程名）
        SourceApp := "Unknown"
        SourceTitle := ""
        SourcePath := ""
        
        try {
            ActiveID := WinGetID("A")
            SourceApp := WinGetProcessName(ActiveID)
            SourceTitle := WinGetTitle(ActiveID)
            SourcePath := WinGetProcessPath(ActiveID)
        } catch {
            SourceApp := "Unknown"
        }

        dataType := "Text", content := "", charCount := 0, wordCount := 0
        clipImageFiles := GetClipboardFileDropList()  ; 先统一检查 CF_HDROP，避免资源管理器复制图片文件被误判成文本

        if (Type = 1) { ; 文本
            ; 防抖延迟内剪贴板可能被其它程序改写，优先用 OnClipboardChange 瞬间快照
            raw := ""
            if (PendingClipboardContent != "")
                raw := PendingClipboardContent
            else {
                try raw := A_Clipboard
                catch
                    raw := ""
            }
            content := ClipboardFTS5_NormalizeCapturedText(raw)
            ; 其它进程占用剪贴板时 A_Clipboard 可能短暂为空，短重试
            if (content = "") {
                Loop 6 {
                    Sleep(35)
                    try raw := A_Clipboard
                    catch
                        raw := ""
                    content := ClipboardFTS5_NormalizeCapturedText(raw)
                    if (content != "")
                        break
                }
            }
            charCount := StrLen(content)
            wordCount := StrSplit(RegExReplace(content, "[^\w\s]+", ""), " ").Length

            ; 智能分拣
            if RegExMatch(content, "i)^(https?:\/\/|www\.)[^\s]+$")
                dataType := "Link"
            else if RegExMatch(content, "i)^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$")
                dataType := "Email"
            else if RegExMatch(content, "[\{\}\[\]\(\);]|=>|:=|function|const|import")
                dataType := "Code"

            if (clipImageFiles != "") {
                dataType := "File"
                content := clipImageFiles
                charCount := StrLen(content)
                FileLines := StrSplit(content, "`n")
                wordCount := FileLines.Length
            }

        } else if (Type = 2) { ; 图片或文件
            files := clipImageFiles
            if (files = "") {
                try {
                    ClipboardObj := WinClip()
                    files := ClipboardObj.GetFiles()
                } catch {
                    files := ""
                }
            }
            if (files) {
                dataType := "File"
                content := files
                clipImageFiles := files
                charCount := StrLen(content)
                FileLines := StrSplit(files, "`n")
                wordCount := FileLines.Length
            } else {
                dataType := "Image"
                content := SaveClipboardImage() ; 调用下方保存函数
                if (content != "") {
                    charCount := StrLen(content)
                    wordCount := 1  ; 图片计为1个"词"
                }
            }
        }

        if (content != "") {
            ; 保存到旧的数据库系统（用于现有的剪贴板管理器）
            if (ClipboardDB && ClipboardDB != 0) {
                SaveToDB(content, dataType, SourceApp, SourceTitle, SourcePath, charCount, wordCount)
            }
        }

        ; ===== FTS5 新剪贴板面板入库（Raycast 风格：按剪贴板格式独立检测，不依赖 Type） =====
        if (ClipboardFTS5DB && ClipboardFTS5DB != 0) {
            ftsOk := false

            ; 优先级 1：CF_HDROP 文件拖放（资源管理器复制文件）
            if (clipImageFiles != "") {
                ftsOk := ClipboardFTS5_ImportDroppedImageFiles(clipImageFiles, SourceApp)
            }

            ; 优先级 2：内容非空
            ; - Image：优先按本地图片文件入库（兼容 Type=2 时 SaveClipboardImage 返回路径）
            ; - 其它：走文本入库（SaveToClipboardFTS5 内部识别图片 URL/路径）
            if (!ftsOk && content != "") {
                if (dataType = "Image") {
                    localImg := ClipboardFTS5_SingleLocalImagePathFromText(content)
                    if (localImg != "") {
                        ftsOk := CaptureImageFileToFTS5(localImg, SourceApp)
                    }
                } else {
                    localImg := ClipboardFTS5_SingleLocalImagePathFromText(content)
                    if (localImg != "") {
                        ftsOk := CaptureImageFileToFTS5(localImg, SourceApp)
                    } else {
                        ftsOk := SaveToClipboardFTS5(content, SourceApp)
                    }
                }
            }

            ; 优先级 2.5：已判定为图片但仍未入库，直接尝试剪贴板位图采集
            if (!ftsOk && dataType = "Image") {
                sourceUrl := ""
                try sourceUrl := _ClipboardFTS5_GetClipboardHtmlImageRef()
                ftsOk := CaptureClipboardImageToFTS5(SourceApp, sourceUrl)
            }

            ; 优先级 3：文本为空或为刚才后台保存的位图 → 浏览器/应用纯图片复制（CF_DIB=8, CF_BITMAP=2）
            if (!ftsOk) {
                if (DllCall("IsClipboardFormatAvailable", "UInt", 8)
                    || DllCall("IsClipboardFormatAvailable", "UInt", 2)) {
                    
                    ; 尝试获取图片源地址（适用于从浏览器中复制图片）
                    sourceUrl := ""
                    try sourceUrl := _ClipboardFTS5_GetClipboardHtmlImageRef()
                    
                    ftsOk := CaptureClipboardImageToFTS5(SourceApp, sourceUrl)
                }
            }

            if (ftsOk)
                try CP_NotifyClipboardUpdated()

            ; 如果 ClipboardHistoryPanel 已显示，自动刷新数据
            try {
                global HistoryIsVisible
                if (IsSet(HistoryIsVisible) && HistoryIsVisible) {
                    SetTimer(() => RefreshHistoryData(), -300)
                }
            } catch {
            }
        }
    } catch as err {
        ; 静默处理错误，避免影响其他功能
    }
}

; ===================== 切换工具栏和面板显示 =====================
ToggleToolbarAndPanel(*) {
    global FloatingToolbarIsVisible, FloatingToolbarIsMinimized
    global AIListPanelIsVisible, AIListPanelIsMinimized
    global AppearanceActivationMode, FloatingBubbleIsVisible

    mode := NormalizeAppearanceActivationMode(AppearanceActivationMode)
    if (mode = "tray") {
        if (AIListPanelIsMinimized) {
            RestoreAIListPanel()
        } else if (AIListPanelIsVisible) {
            MinimizeAIListPanelToEdge()
        }
        return
    }
    if (mode = "bubble") {
        if (FloatingToolbarIsMinimized || AIListPanelIsMinimized) {
            RestoreFloatingToolbar()
            RestoreAIListPanel()
            if (!FloatingBubbleIsVisible) {
                try ShowFloatingBubble()
                catch {
                }
            }
        } else {
            if (FloatingBubbleIsVisible) {
                try HideFloatingBubble()
                catch {
                }
            }
            if (FloatingToolbarIsVisible) {
                MinimizeFloatingToolbarToEdge()
            }
            if (AIListPanelIsVisible) {
                MinimizeAIListPanelToEdge()
            }
        }
        return
    }

    ; 悬浮栏模式：原逻辑
    if (FloatingToolbarIsMinimized || AIListPanelIsMinimized) {
        RestoreFloatingToolbar()
        RestoreAIListPanel()
        if (!FloatingToolbarIsVisible) {
            ShowFloatingToolbar()
        }
    } else {
        if (FloatingToolbarIsVisible) {
            MinimizeFloatingToolbarToEdge()
        }
        if (AIListPanelIsVisible) {
            MinimizeAIListPanelToEdge()
        }
    }
}

; 悬浮工具栏（空白处/图标）右键：与托盘菜单同款样式，并含「关闭工具栏」「重启脚本」
FTB_ItemsToCsv(items) {
    if !(items is Array)
        return ""
    out := ""
    for item in items {
        v := Trim(String(item))
        if (v = "")
            continue
        if (out != "")
            out .= ","
        out .= v
    }
    return out
}

FTB_SanitizeByAllowed(itemsOrCsv, allowedIds, defaults) {
    src := []
    if (itemsOrCsv is Array) {
        for item in itemsOrCsv
            src.Push(Trim(String(item)))
    } else {
        for item in StrSplit(String(itemsOrCsv), ",")
            src.Push(Trim(String(item)))
    }
    out := []
    seen := Map()
    for id in src {
        if (id = "")
            continue
        if !allowedIds.Has(id)
            continue
        if seen.Has(id)
            continue
        seen[id] := true
        out.Push(id)
    }
    if (out.Length = 0) {
        out := []
        for id in defaults
            out.Push(id)
    }
    return out
}

FTB_SanitizeToolbarButtonItems(itemsOrCsv) {
    allowed := Map("Search",1, "Record",1, "Prompt",1, "NewPrompt",1, "Screenshot",1, "Settings",1, "VirtualKeyboard",1)
    defaults := ["Search", "Record", "Prompt", "NewPrompt", "Screenshot", "Settings", "VirtualKeyboard"]
    return FTB_SanitizeByAllowed(itemsOrCsv, allowed, defaults)
}

FTB_SanitizeToolbarMenuItems(itemsOrCsv) {
    allowed := Map("ToggleToolbar",1, "MinimizeToEdge",1, "ResetScale",1, "SearchCenter",1, "Clipboard",1, "OpenConfig",1, "HideToolbar",1, "ReloadScript",1, "ExitApp",1)
    defaults := ["ToggleToolbar", "MinimizeToEdge", "ResetScale", "SearchCenter", "Clipboard", "OpenConfig", "HideToolbar", "ReloadScript", "ExitApp"]
    return FTB_SanitizeByAllowed(itemsOrCsv, allowed, defaults)
}

; 悬浮条统一右键：多套 cmdId 对应同一入口（工具栏槽位 vs 旧版 ftm_* / hub_*），按语义去重只保留先出现的项
FTB_UnifiedContextMenuDedupeSlotKey(cmdId) {
    c := Trim(String(cmdId))
    if (c = "sc_activate_search" || c = "ftm_search_center")
        return "slot:search_center"
    if (c = "qa_clipboard" || c = "ftm_clipboard")
        return "slot:clipboard"
    if (c = "ftb_scratchpad" || c = "hub_capsule")
        return "slot:scratchpad"
    return "id:" . c
}

ShowFloatingToolbarUnifiedContextMenu(anchorX, anchorY) {
    global g_Commands

    MenuItemHeight := 35
    Padding := 10
    MenuItems := []
    useFloatingSceneMenu := false
    seenMenuSlots := Map()

    try {
        if (IsSet(g_Commands) && g_Commands is Map && g_Commands.Has("CommandList") && g_Commands["CommandList"] is Map) {
            cmdList := g_Commands["CommandList"]
            if (g_Commands.Has("SceneMenus") && g_Commands["SceneMenus"] is Map) {
                sm := g_Commands["SceneMenus"]
                if (sm.Has("floating_bar") && sm["floating_bar"] is Array) {
                    useFloatingSceneMenu := true
                    vm := Map()
                    if g_Commands.Has("SceneMenuVisibility") && g_Commands["SceneMenuVisibility"] is Map {
                        visAll := g_Commands["SceneMenuVisibility"]
                        if visAll.Has("floating_bar") && visAll["floating_bar"] is Map
                            vm := visAll["floating_bar"]
                    }
                    for cid in sm["floating_bar"] {
                        c := Trim(String(cid))
                        if (c = "" || !cmdList.Has(c))
                            continue
                        visOn := vm.Has(c) ? !!vm[c] : true
                        if !visOn
                            continue
                        sk := FTB_UnifiedContextMenuDedupeSlotKey(c)
                        if seenMenuSlots.Has(sk)
                            continue
                        seenMenuSlots[sk] := true
                        nm := cmdList[c]["name"]
                        if (nm = "")
                            nm := c
                        MenuItems.Push({ Text: nm, Icon: "▸", Action: VK_MakeToolbarContextMenuAction(c) })
                    }
                }
            }
            if (!useFloatingSceneMenu && MenuItems.Length = 0 && g_Commands.Has("ToolbarLayout") && g_Commands["ToolbarLayout"] is Array) {
                sorted := g_Commands["ToolbarLayout"]
                if sorted.Length > 1
                    sorted := _VK_SortRowsByNumericKey(sorted, "order_menu")
                for row in sorted {
                    if !(row is Map) || !row.Has("cmdId")
                        continue
                    if !row.Has("visible_in_menu") || !row["visible_in_menu"]
                        continue
                    cid := Trim(String(row["cmdId"]))
                    if (cid = "" || !cmdList.Has(cid))
                        continue
                    sk := FTB_UnifiedContextMenuDedupeSlotKey(cid)
                    if seenMenuSlots.Has(sk)
                        continue
                    seenMenuSlots[sk] := true
                    nm := cmdList[cid]["name"]
                    if (nm = "")
                        nm := cid
                    MenuItems.Push({ Text: nm, Icon: "▸", Action: VK_MakeToolbarContextMenuAction(cid) })
                }
            }
        }
    } catch {
    }

    if (MenuItems.Length = 0)
        MenuItems.Push({ Text: "（右键菜单暂无命令）", Icon: "·", Action: (*) => 0 })

    n := MenuItems.Length
    MenuHeight := n * MenuItemHeight + Padding * 2
    MenuWidth := 280
    posX := anchorX - (MenuWidth // 2)
    posY := anchorY - MenuHeight - 10

    ScreenWidth := SysGet(78)
    ScreenHeight := SysGet(79)
    if (posX < 10) {
        posX := 10
    } else if (posX + MenuWidth > ScreenWidth - 10) {
        posX := ScreenWidth - MenuWidth - 10
    }
    if (posY < 10) {
        posY := anchorY + 10
    } else if (posY + MenuHeight > ScreenHeight - 10) {
        posY := ScreenHeight - MenuHeight - 10
    }

    ShowDarkStylePopupMenuAt(MenuItems, posX, posY)
}

; ===================== CapsLock 状态检查函数 =====================
; 用于 #HotIf GetCapsLockState() 下的 CapsLock+ 第二键热键。
;
; 联动顺序（嵌入 VK 时）：
; 1) 按下 CapsLock：由下方「无 ~ 的 CapsLock::」接管，设 CapsLock:=true 并 KeyWait 到松手；松手后再处理单击切换/组合键恢复。
; 2) 按住期间按第二键：#HotIf 为真（本函数 = true），先走 VirtualKeyboard_HandleKey(键)；
;    仅当 VK 内 _ExecuteCommand 对该绑定返回「已执行」时才 return（吞键），否则继续 HandleDynamicHotkey（CapsLock+C 等宿主逻辑）。
; 3) 录制快捷键时本函数临时为 false，避免 #HotIf 抢走第二键导致录到「… then CapsLock」或大写灯异常。
GetCapsLockState() {
    global CapsLock
    try {
        if VK_IsVkRecordingHotkey()
            return false
    } catch as e {
    }
    ; 变量 true（按下分支已置位）或物理仍按住，均可匹配组合键（与逻辑大写灯是否 On 无关）
    return CapsLock || GetKeyState("CapsLock", "P")
}

; ===================== 面板可见状态检查函数 =====================
; 用于 #HotIf 指令的函数
GetPanelVisibleState() {
    global PanelVisible
    return PanelVisible
}

; ===================== 搜索中心窗口激活状态检查函数 =====================
; 用于 #HotIf 指令的函数
; 【修复】加强检查逻辑，确保窗口确实存在且激活，避免误判
IsSearchCenterActive() {
    global GuiID_SearchCenter
    try {
        if (SearchCenter_ShouldUseWebView()) {
            ; WebView 模式：以 SCWV 可见且宿主窗口仍存在为准（不要求前台，避免句柄瞬时为空误判）
            try {
                if (SCWV_IsVisible()) {
                    g := 0
                    try g := SCWV_GetGui()
                    if (IsObject(g) && g.HasProp("Hwnd")) {
                        h := g.Hwnd
                        if (h && WinExist("ahk_id " . h))
                            return true
                    }
                    hwnd := 0
                    try hwnd := SCWV_GetGuiHwnd()
                    if (hwnd && WinExist("ahk_id " . hwnd))
                        return true
                }
            } catch {
            }
            return false
        }
    } catch {
    }
    if (!GuiID_SearchCenter || GuiID_SearchCenter = 0)
        return false
    ; 【关键修复】使用 .Hwnd 属性获取窗口句柄
    if (IsObject(GuiID_SearchCenter) && GuiID_SearchCenter.HasProp("Hwnd")) {
        Hwnd := GuiID_SearchCenter.Hwnd
        ; 双重检查：窗口存在且激活
        if (WinExist("ahk_id " . Hwnd) && WinActive("ahk_id " . Hwnd)) {
            return true
        }
    }
    return false
}

SearchCenter_HandleCapsChordKey(ch) {
    global SearchCenterCapsChord_Debug, g_SCWV_Ready
    k := StrLower(Trim(String(ch)))
    if (k = "")
        return false
    dbg := false
    try dbg := SearchCenterCapsChord_Debug
    wr := "?"
    try wr := g_SCWV_Ready ? "1" : "0"
    catch {
    }
    if dbg
        OutputDebug("SC_CapsChord key=" . k
            . " ISA=" . (IsSearchCenterActive() ? "1" : "0")
            . " GCLS=" . (GetCapsLockState() ? "1" : "0")
            . " SCWV_Ready=" . wr)
    if !IsSearchCenterActive() {
        if dbg
            OutputDebug("SC_CapsChord abort: !IsSearchCenterActive key=" . k)
        return false
    }

    cmdId := VK_SearchCenterResolveCapsChordCmd(k)
    if (cmdId = "") {
        if dbg
            OutputDebug("SC_CapsChord abort: resolve empty key=" . k)
        return false
    }
    if dbg
        OutputDebug("SC_CapsChord run cmdId=" . cmdId)

    ; 与 CapsLock+F/G 等一致：必须标记组合键已消费并恢复按下前的逻辑大写状态，
    ; 否则 CapsLock 松手时仍走「单击切换大小写」，表现为只亮/灭大写灯而忽略 sc_* 语义。
    global CapsLock2
    CapsLock2 := false
    RestoreCapsLockAfterChord()
    try CapsLock_ScheduleNormalizeAfterChord()
    try SearchCenter_FlashCapsHintKey(k)

    VK_ExecCursorHelperCmd(cmdId)
    return true
}

SearchCenter_SelectCategoryByKey(categoryKey) {
    if (categoryKey = "")
        return false
    try {
        if (SearchCenter_ShouldUseWebView()) {
            SCWV_PostJson('{"type":"setCategory","category":"' . categoryKey . '"}')
            return true
        }
    } catch {
    }

    try {
        categories := GetSearchCenterCategories()
        for idx, cat in categories {
            if (cat.Key = categoryKey) {
                SwitchSearchCenterCategory(idx - 1, true)
                return true
            }
        }
    } catch {
    }
    return false
}

SearchCenter_ToggleEngineByValue(engineValue) {
    if (engineValue = "")
        return false
    try {
        if (SearchCenter_ShouldUseWebView()) {
            SCWV_PostJson('{"type":"toggleEngine","engine":"' . engineValue . '"}')
            return true
        }
    } catch {
    }

    try {
        currentCat := GetSearchCenterCurrentCategoryKey()
        engines := GetSortedSearchEngines(currentCat)
        for idx, eng in engines {
            if (eng.Value = engineValue) {
                ToggleSearchCenterEngine(engineValue, idx)
                return true
            }
        }
    } catch {
    }
    return false
}

SearchCenter_SetFilterByKey(filterType) {
    try {
        if (SearchCenter_ShouldUseWebView()) {
            SCWV_PostJson('{"type":"setFilter","filterType":"' . filterType . '"}')
            return true
        }
    } catch {
    }

    try {
        SearchCenterFilterClickHandler(filterType)
        return true
    } catch {
    }
    return false
}

SearchCenter_SetCapsHintActive(isActive) {
    try {
        if (SearchCenter_ShouldUseWebView() && IsSearchCenterActive()) {
            SCWV_PostJson('{"type":"capsHint","active":' . (isActive ? "true" : "false") . '}')
        }
    } catch {
    }
}

SearchCenter_FlashCapsHintKey(key) {
    k := StrLower(Trim(String(key)))
    if (k = "")
        return
    try {
        if (SearchCenter_ShouldUseWebView() && IsSearchCenterActive()) {
            SCWV_PostJson('{"type":"capsHintPress","key":"' . k . '"}')
        }
    } catch {
    }
}

SearchCenter_CapsHintOnTimer(*) {
    SearchCenter_SetCapsHintActive(true)
}

; ===================== CapsLock核心逻辑 =====================
; 定时器函数定义（需要在 CapsLock 处理函数外部定义）
ClearCapsLock2Timer(*) {
    global CapsLock2 := false
}

; 将“切换态”布尔值统一写成 SetCapsLockState 接受的字面量，避免与 v1/v2 对 0/1 的兼容差异
CapsLock_ApplyLogicalState(isOn) {
    try SetCapsLockState(isOn ? "On" : "Off")
}

RestoreCapsLockAfterChord(*) {
    global CapsLockInitialStateForChord
    CapsLock_ApplyLogicalState(CapsLockInitialStateForChord)
}

; 组合键触发时用户往往仍按住物理 CapsLock：松手瞬间驱动可能再次翻转逻辑大写，WebView/IME 已聚焦会表现为输入框“默认大写”。
; 在打开搜索中心等需要立即输入的场景，延迟多次恢复到按下 CapsLock 前的逻辑状态（与 RestoreCapsLockAfterChord 一致）。
CapsLock_DeferredNormalize_Tick(*) {
    global CapsLockInitialStateForChord
    try CapsLock_ApplyLogicalState(CapsLockInitialStateForChord)
}

CapsLock_ScheduleNormalizeAfterChord() {
    SetTimer(CapsLock_DeferredNormalize_Tick, -40)
    SetTimer(CapsLock_DeferredNormalize_Tick, -120)
    SetTimer(CapsLock_DeferredNormalize_Tick, -350)
    SetTimer(CapsLock_DeferredNormalize_Tick, -800)
}

; 搜索中心 WebView 打开后：在 CapsLock 与焦点稳定后再多次尝试切换中文，减少「有时整句中文、有时英文小写」的竞态
SearchCenter_IMEStabilizeTick(*) {
    try SwitchToChineseIMEForSearchCenter()
}

SearchCenter_ScheduleIMEStabilize() {
    SetTimer(SearchCenter_IMEStabilizeTick, -160)
    SetTimer(SearchCenter_IMEStabilizeTick, -420)
    SetTimer(SearchCenter_IMEStabilizeTick, -950)
}

; 延迟清除 CapsLock 变量的函数
ClearCapsLockTimer(*) {
    global CapsLock := false
}

ShowPanelTimer(*) {
    global CapsLock, CapsLock2, PanelVisible, VoiceInputActive, VoiceSearchActive, VoiceSearchSelecting
    global VKHoldVisible, CapsLockHoldVkEnabled
    local wasVkVisible := false
    if (!CapsLockHoldVkEnabled)
        return
    ; 如果正在语音输入、语音搜索或选择搜索引擎，不显示 VK KeyBinder
    if (VoiceInputActive || VoiceSearchActive || VoiceSearchSelecting) {
        return
    }
    ; 【关键修改】如果CapsLock2被清除，说明用户按了组合键（如CapsLock+C），不要激活面板
    if (!CapsLock2) {
        return
    }
    ; 【修复】检查 CapsLock 是否仍然按下（防止短按后定时器延迟触发）
    if (!GetKeyState("CapsLock", "P")) {
        return
    }
    ; 长按达到阈值：显示 VK KeyBinder（若托盘已打开则不再标记为「长按临时显示」）
    if (!CapsLock || VKHoldVisible)
        return
    try {
        VK_EnsureInit(true)
        wasVkVisible := VK_IsHostVisible()
    } catch as e {
        wasVkVisible := false
    }
    if (wasVkVisible)
        return
    ; 仅长按 CapsLock 调起 VK 时，才允许进入「复制/绑定上一个动作」模式
    try VK_MarkNextShowFromCapsLockHold(true)
    try VK_Show()
    VKHoldVisible := true
}

; 记录 CapsLock 按下时间
global CapsLockPressTime := 0

; ===================== CapsLock+ 与原生单击共存（当前脚本采用的做法，请勿混用其它方案）=====================
; 1) 本热键为「无 ~ 的 CapsLock::」：拦截系统对 CapsLock 的默认处理，由下面 KeyWait 释放分支统一收尾。
; 2) 纯单击：未触发 CapsLock+ 功能（CapsLock2 仍为 true）时，在松手处用 InitialCapsLockState 手动翻转一次，等价于原生单击切换大写。
; 3) 组合键：任一 CapsLock+ 字母会先 Clear CapsLock2，并在 HandleDynamicHotkey / 各字母分支里 RestoreCapsLockAfterChord，
;    松手时若 CapsLock2 为 false 则 SetCapsLockState 回到按下前的逻辑状态，避免组合键误开大写。
; 4) GetCapsLockState() 使用 变量 CapsLock OR 物理按下，是为「按住 CapsLock 再按第二键」仍能匹配 #HotIf；与逻辑大写灯不同步时以 Restore 为准。
; ============================================================================================
CapsLock:: {
    global CapsLock, CapsLock2, IsCommandMode, PanelVisible, VoiceInputActive, VoiceSearchActive, VoiceInputMethod, VoiceInputPaused, CapsLockHoldTimeSeconds
    global CapsLockInitialStateForChord
    global VKHoldVisible, CapsLockHoldVkEnabled
    
    ; 确保全局变量已初始化
    if (!IsSet(PanelVisible)) {
        PanelVisible := false
    }
    if (!IsSet(VoiceInputActive)) {
        VoiceInputActive := false
    }
    if (!IsSet(VoiceSearchActive)) {
        VoiceSearchActive := false
    }
    if (!IsSet(CapsLockHoldTimeSeconds) || CapsLockHoldTimeSeconds = "") {
        CapsLockHoldTimeSeconds := 0.5
    }
    ; 搜索中心热键提示：按住 CapsLock 一段时间后通知 WebView 进入提示高亮态
    SetTimer(SearchCenter_CapsHintOnTimer, 0)
    HintDelayMs := Round(CapsLockHoldTimeSeconds * 1000)
    if (HintDelayMs < 120)
        HintDelayMs := 120
    SetTimer(SearchCenter_CapsHintOnTimer, -HintDelayMs)
    
    ; 【关键修复】记录初始状态，必须在按下时立即记录，用于最后的恢复/切换逻辑
    ; 必须在任何可能改变CAPSLOCK状态的操作之前记录
    local InitialCapsLockState := GetKeyState("CapsLock", "T")
    CapsLockInitialStateForChord := InitialCapsLockState
    
    ; 不在按下时强制改写状态，保留系统原生切换时序
    ; 单击由原生行为 + 释放分支共同保证，组合键分支仍按 CapsLock2 回滚状态
    
    ; 标记 CapsLock 已按下
    CapsLock := true
    CapsLock2 := true  ; 初始化为 true，如果使用了功能会被清除
    IsCommandMode := false
    
    ; 记录按下时间
    CapsLockPressTime := A_TickCount
    ; 双击判定：两次 CapsLock 触发间隔在 300ms 内
    IsCapsDoubleClick := (InStr(A_PriorHotkey, "CapsLock") && A_TimeSincePriorHotkey > 0 && A_TimeSincePriorHotkey <= 300)
    
    ; 如果正在语音输入或语音搜索，处理暂停/恢复逻辑
    global VoiceInputActive, VoiceSearchActive
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
        SetTimer(SearchCenter_CapsHintOnTimer, 0)
        SearchCenter_SetCapsHintActive(false)
        
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
        
        ; 【关键修复】恢复CAPSLOCK状态到按下前的状态，确保输入法可以正常切换
        CapsLock_ApplyLogicalState(InitialCapsLockState)
        CapsLock := false
        CapsLock2 := false
        return
    }
    
    ; 如果未在语音输入，执行正常的 CapsLock+ 逻辑
    ; 【关键修复】不再设置ClearCapsLock2Timer定时器自动清除CapsLock2
    ; 因为如果自动清除，长按CapsLock显示面板时，CapsLock2会被提前清除，导致面板无法显示
    ; CapsLock2只应该在以下情况被清除：
    ; 1. 用户按了组合键（如CapsLock+C），由组合键处理函数清除
    ; 2. CapsLock释放后，由释放逻辑清除
    ; SetTimer(ClearCapsLock2Timer, -300)  ; 已移除

    ; 长按达到 CapsLockHoldTimeSeconds 后由 ShowPanelTimer 显示 VK KeyBinder（可设置中心关闭）
    if (CapsLockHoldVkEnabled) {
        HoldTimeMs := Round(CapsLockHoldTimeSeconds * 1000)
        if (HoldTimeMs < 50)
            HoldTimeMs := 50
        SetTimer(ShowPanelTimer, -HoldTimeMs)
    }

    ; 等待 CapsLock 释放
    KeyWait("CapsLock")
    SetTimer(ShowPanelTimer, 0)  ; 取消未触发的长按检测
    SetTimer(SearchCenter_CapsHintOnTimer, 0)
    SearchCenter_SetCapsHintActive(false)
    if (VKHoldVisible) {
        try VK_Hide()
        VKHoldVisible := false
    }
    
    ; 双击 CapsLock：快捷面板开关（已开则关，已关则开），并撤销第一次单击对大小写状态的切换
    if (CapsLock2 && IsCapsDoubleClick) {
        if (PanelVisible) {
            HideCursorPanel()
        } else {
            ShowCursorPanel()
        }
        ; 双击时保持系统原生 CapsLock 状态流转，不额外改写大小写状态
        ; 延迟清除 CapsLock 变量，给快捷键处理函数足够的时间
        SetTimer(ClearCapsLockTimer, -100)
        CapsLock2 := false
        return
    }
    
    ; 逻辑修复：处理大小写切换误触
    ; 如果 CapsLock2 为 false (说明使用了 CapsLock + [Key] 功能)，则恢复初始状态，防止误切换
    ; 如果 CapsLock2 为 true (说明没有使用任何功能)，则切换大小写状态
    if (!CapsLock2) {
        ; 组合键场景：恢复按下前状态，避免误改写用户原有 CapsLock 状态
        CapsLock_ApplyLogicalState(InitialCapsLockState)
        ; 延迟清除 CapsLock 变量，给快捷键处理函数足够的时间
        SetTimer(ClearCapsLockTimer, -100)
    } else {
        ; 没有使用功能：手动执行一次 CapsLock 单击切换（当前热键已拦截原生行为）
        CapsLock_ApplyLogicalState(!InitialCapsLockState)
        CapsLock := false
    }
    
    ; 清除标记
    CapsLock2 := false
    
    ; 长按期间弹出的 VK KeyBinder 已在松手时隐藏（VKHoldVisible 为真时）
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
        } catch as err {
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
    } catch as err {
        ; 出错时返回主屏幕
        return 1
    }
}

; ===================== 窗口位置和大小记忆功能 =====================
; 保存窗口位置和大小到配置文件
; 待保存的窗口位置信息（用于延迟保存）
global PendingWindowPositions := Map()
global WindowPositionSaveTimer := 0

; 保存窗口位置（立即保存，用于需要立即保存的场景）
SaveWindowPosition(WindowName, X, Y, Width, Height) {
    global ConfigFile
    IniWrite(String(X), ConfigFile, "WindowPositions", WindowName . "_X")
    IniWrite(String(Y), ConfigFile, "WindowPositions", WindowName . "_Y")
    IniWrite(String(Width), ConfigFile, "WindowPositions", WindowName . "_Width")
    IniWrite(String(Height), ConfigFile, "WindowPositions", WindowName . "_Height")
}

; 延迟保存窗口位置（优化性能，避免频繁IO）
QueueWindowPositionSave(WindowName, X, Y, Width, Height) {
    global PendingWindowPositions, WindowPositionSaveTimer
    
    ; 将窗口位置信息存储到Map中（如果已存在则更新）
    PendingWindowPositions[WindowName] := {X: X, Y: Y, Width: Width, Height: Height}
    
    ; 如果定时器已存在，先删除（重置延迟时间）
    if (WindowPositionSaveTimer != 0) {
        try {
            SetTimer(WindowPositionSaveTimer, 0)
        } catch as err {
        }
    }
    
    ; 设置延迟保存定时器（500ms后执行，给用户足够的时间完成窗口调整）
    WindowPositionSaveTimer := (*) => FlushPendingWindowPositions()
    SetTimer(WindowPositionSaveTimer, -500)
}

; 立即保存所有待保存的窗口位置
FlushPendingWindowPositions() {
    global PendingWindowPositions, WindowPositionSaveTimer, ConfigFile
    
    ; 如果Map为空，直接返回
    if (!PendingWindowPositions || PendingWindowPositions.Count = 0) {
        return
    }
    
    ; 批量保存所有待保存的窗口位置
    try {
        for WindowName, Pos in PendingWindowPositions {
            IniWrite(String(Pos.X), ConfigFile, "WindowPositions", WindowName . "_X")
            IniWrite(String(Pos.Y), ConfigFile, "WindowPositions", WindowName . "_Y")
            IniWrite(String(Pos.Width), ConfigFile, "WindowPositions", WindowName . "_Width")
            IniWrite(String(Pos.Height), ConfigFile, "WindowPositions", WindowName . "_Height")
        }
        
        ; 清空待保存列表
        PendingWindowPositions.Clear()
    } catch as err {
        ; 如果保存失败，保留待保存列表，下次再试
    }
    
    ; 清除定时器
    WindowPositionSaveTimer := 0
}

; 从配置文件恢复窗口位置和大小
RestoreWindowPosition(WindowName, DefaultWidth, DefaultHeight, DefaultX := -1, DefaultY := -1) {
    global ConfigFile
    X := Integer(IniRead(ConfigFile, "WindowPositions", WindowName . "_X", String(DefaultX)))
    Y := Integer(IniRead(ConfigFile, "WindowPositions", WindowName . "_Y", String(DefaultY)))
    Width := Integer(IniRead(ConfigFile, "WindowPositions", WindowName . "_Width", String(DefaultWidth)))
    Height := Integer(IniRead(ConfigFile, "WindowPositions", WindowName . "_Height", String(DefaultHeight)))
    
    ; 验证位置和大小是否在屏幕范围内
    ScreenInfo := GetScreenInfo(1)
    if (Width < 300) {
        Width := DefaultWidth
    }
    if (Height < 200) {
        Height := DefaultHeight
    }
    if (X < ScreenInfo.Left || X > ScreenInfo.Right) {
        X := DefaultX
    }
    if (Y < ScreenInfo.Top || Y > ScreenInfo.Bottom) {
        Y := DefaultY
    }
    
    return {X: X, Y: Y, Width: Width, Height: Height}
}

; 窗口大小改变时保存位置和大小
OnWindowSize(GuiObj, MinMax, Width, Height) {
    global WindowDragging
    
    ; 如果窗口正在拖动，跳过保存以避免频繁IO
    if (WindowDragging) {
        return
    }
    
    ; MinMax: -1=最小化, 1=最大化, 0=正常大小
    if (MinMax = 0) {
        try {
            WinGetPos(&X, &Y, &W, &H, GuiObj)
            WindowName := GuiObj.Title
            if (WindowName = "") {
                WindowName := "Window_" . GuiObj.Hwnd
            }
            ; 使用延迟保存，避免频繁IO
            QueueWindowPositionSave(WindowName, X, Y, W, H)
        } catch as err {
            ; 忽略错误
        }
    }
}

; 窗口移动时保存位置
OnWindowMove(GuiObj, X, Y) {
    try {
        WinGetPos(&WinX, &WinY, &WinW, &WinH, GuiObj)
        WindowName := GuiObj.Title
        if (WindowName = "") {
            WindowName := "Window_" . GuiObj.Hwnd
        }
        ; 使用延迟保存，避免频繁IO
        QueueWindowPositionSave(WindowName, WinX, WinY, WinW, WinH)
    } catch as err {
        ; 忽略错误
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
    BaseHeight := 200  ; 标题、输入框、说明文字、底部提示等基础高度
    ; 为ListView预留空间（ListView高度600 + 更多按钮高度35 + 间距30 = 665）
    ListViewReservedHeight := 665
    ; 初始面板高度 = 基础高度 + ListView预留空间 + 按钮区域高度
    global CursorPanelHeight := BaseHeight + ListViewReservedHeight + (ButtonCount * ButtonSpacing)
    
    ; 面板尺寸（参考 Raycast 和 uTools 的默认宽度，约 640-720px）
    global CursorPanelWidth := 680
    
    ; 如果面板已存在，先销毁
    if (GuiID_CursorPanel != 0) {
        try {
            GuiID_CursorPanel.Destroy()
        } catch as err {
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
    BtnStartX := CursorPanelWidth - (BtnSize * 3 + BtnSpacing * 2) - 10
    
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
    
    ; 关闭按钮（使用 html.to.design 风格配色）
    CursorPanelCloseBtn := GuiID_CursorPanel.Add("Text", "x" . (BtnStartX + (BtnSize + BtnSpacing) * 2) . " y" . BtnY . " w" . BtnSize . " h" . BtnSize . " Center 0x200 c" . UI_Colors.Text . " Background" . UI_Colors.BtnBg . " vCursorPanelCloseBtn", "✕")
    CursorPanelCloseBtn.SetFont("s14", "Segoe UI")
    CursorPanelCloseBtn.OnEvent("Click", CloseCursorPanel)
    HoverBtnWithAnimation(CursorPanelCloseBtn, UI_Colors.BtnBg, "e81123")
    
    ; 分隔线（使用层叠投影替代1px边框）
    ; 底层：大范围、低饱和度、模糊阴影（使用 html.to.design 风格配色）
    global ThemeMode
    OuterShadowColor := (ThemeMode = "light") ? "E0E0E0" : UI_Colors.Background
    InnerShadowColor := (ThemeMode = "light") ? "B0B0B0" : UI_Colors.Sidebar
    ; 底层阴影（3层渐变）
    Loop 3 {
        LayerOffset := 4 + (A_Index - 1) * 1
        LayerAlpha := 255 - (A_Index - 1) * 60
        LayerColor := BlendColor(OuterShadowColor, (ThemeMode = "light") ? "FFFFFF" : "000000", LayerAlpha / 255)
        GuiID_CursorPanel.Add("Text", "x0 y" . (50 + LayerOffset) . " w" . CursorPanelWidth . " h1 Background" . LayerColor, "")
    }
    ; 顶层阴影（紧凑、深色）
    GuiID_CursorPanel.Add("Text", "x0 y51 w" . CursorPanelWidth . " h1 Background" . InnerShadowColor, "")
    
    ; ========== 搜索输入框（无边，与面板同宽）==========
    SearchEditY := 60
    SearchEditHeight := 35
    SearchEditX := 0
    SearchEditWidth := CursorPanelWidth
    
    ; 根据主题模式设置输入框颜色（使用 html.to.design 风格配色）
    if (ThemeMode = "dark") {
        InputBgColor := UI_Colors.InputBg  ; html.to.design 风格背景
        InputTextColor := UI_Colors.Text    ; html.to.design 风格文本
    } else {
        InputBgColor := UI_Colors.InputBg
        InputTextColor := UI_Colors.Text
    }
    
    ; 创建无边输入框（使用-Border移除边框）
    global CursorPanelSearchEdit := GuiID_CursorPanel.Add("Edit", "x" . SearchEditX . " y" . SearchEditY . " w" . SearchEditWidth . " h" . SearchEditHeight . " Background" . InputBgColor . " c" . InputTextColor . " -VScroll -HScroll -Border vCursorPanelSearchEdit", "")
    CursorPanelSearchEdit.SetFont("s11", "Segoe UI")
    
    ; 移除Edit控件的默认3D边框
    try {
        EditHwnd := CursorPanelSearchEdit.Hwnd
        if (EditHwnd) {
            CurrentExStyle := DllCall("GetWindowLongPtr", "Ptr", EditHwnd, "Int", -20, "Ptr")
            NewExStyle := CurrentExStyle & ~0x00000200  ; 移除WS_EX_CLIENTEDGE
            DllCall("SetWindowLongPtr", "Ptr", EditHwnd, "Int", -20, "Ptr", NewExStyle, "Ptr")
            DllCall("InvalidateRect", "Ptr", EditHwnd, "Ptr", 0, "Int", 1)
            DllCall("UpdateWindow", "Ptr", EditHwnd)
        }
    } catch as err {
        ; 忽略错误
    }
    
    ; 搜索输入框Change事件（防抖搜索）
    CursorPanelSearchEdit.OnEvent("Change", ExecuteCursorPanelSearch)
    
    ; ========== ListView卡片（与面板同宽，不溢出）==========
    ; 【修复】ListView 宽度调整为面板宽度，避免左边被截断
    ListViewWidth := CursorPanelWidth  ; 与面板同宽
    ListViewHeight := 600
    ListViewX := 0  ; 从左边开始，与面板对齐
    ListViewY := SearchEditY + SearchEditHeight + 10
    
    ; 根据主题模式设置ListView颜色（使用 html.to.design 风格配色）
    ListViewTextColor := (ThemeMode = "dark") ? UI_Colors.Text : UI_Colors.Text
    global CursorPanelResultLV := GuiID_CursorPanel.Add("ListView", "x" . ListViewX . " y" . ListViewY . " w" . ListViewWidth . " h" . ListViewHeight . " Background" . UI_Colors.InputBg . " c" . ListViewTextColor . " -Multi +ReadOnly vCursorPanelResultLV", ["标题", "来源", "时间"])
    CursorPanelResultLV.SetFont("s10 c" . ListViewTextColor, "Segoe UI")
    ; 【修改】ListView 始终显示，用于全局搜索所有内容
    CursorPanelResultLV.Visible := true  ; 始终显示
    CursorPanelResultLV.OnEvent("DoubleClick", OnCursorPanelResultDoubleClick)
    
    ; 【修复】设置ListView列宽，考虑实际可用宽度（减去滚动条宽度约20px）
    AvailableWidth := ListViewWidth - 20  ; 减去滚动条宽度
    CursorPanelResultLV.ModifyCol(1, AvailableWidth * 0.5)   ; 标题列：50%
    CursorPanelResultLV.ModifyCol(2, AvailableWidth * 0.25)  ; 来源列：25%
    CursorPanelResultLV.ModifyCol(3, AvailableWidth * 0.25)  ; 时间列：25%
    
    ; ========== "更多"按钮（初始隐藏，放在ListView下方）==========
    MoreBtnY := ListViewY + ListViewHeight + 10
    MoreBtnWidth := 100
    MoreBtnHeight := 35
    MoreBtnX := (CursorPanelWidth - MoreBtnWidth) / 2  ; 居中
    global CursorPanelShowMoreBtn := GuiID_CursorPanel.Add("Text", "x" . MoreBtnX . " y" . MoreBtnY . " w" . MoreBtnWidth . " h" . MoreBtnHeight . " Center 0x200 c" . ((ThemeMode = "light") ? UI_Colors.Text : UI_Colors.Text) . " Background" . UI_Colors.BtnBg . " vCursorPanelShowMoreBtn", "更多")  ; html.to.design 风格文本
    CursorPanelShowMoreBtn.SetFont("s10", "Segoe UI")
    CursorPanelShowMoreBtn.Visible := false  ; 初始隐藏
    CursorPanelShowMoreBtn.OnEvent("Click", OnCursorPanelShowMore)
    HoverBtnWithAnimation(CursorPanelShowMoreBtn, UI_Colors.BtnBg, UI_Colors.BtnHover)
    
    ; 初始化搜索结果数组
    global CursorPanelSearchResults := []
    
    ; ========== 按钮区域（始终在ListView下方，为ListView预留空间）==========
    ; 按钮区域起始位置：ListView下方（即使ListView初始隐藏，也要预留空间）
    ButtonY := MoreBtnY + MoreBtnHeight + 20
    for Index, Button in QuickActionButtons {
        BtnType := ""
        BtnHotkey := ""
        if (Button is Map) {
            BtnType := Button.Get("Type", "")
            BtnHotkey := Button.Get("Hotkey", "")
        } else if (IsObject(Button)) {
            if Button.HasProp("Type")
                BtnType := Button.Type
            if Button.HasProp("Hotkey")
                BtnHotkey := Button.Hotkey
        }
        ; 获取按钮文本和功能
        ButtonText := ""
        ButtonAction := (*) => {}
        
        ; 获取基础文本（不包含快捷键）
        BaseText := ""
        switch BtnType {
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
                ButtonAction := (*) => ExecuteCursorShortcut(GetCursorActionShortcut("CommandPalette"))
            case "Terminal":
                BaseText := GetText("quick_action_type_terminal")
                ButtonAction := (*) => ExecuteCursorShortcut(GetCursorActionShortcut("Terminal"))
            case "GlobalSearch":
                BaseText := GetText("quick_action_type_global_search")
                ButtonAction := (*) => ExecuteCursorShortcut(GetCursorActionShortcut("GlobalSearch"))
            case "Explorer":
                BaseText := GetText("quick_action_type_explorer")
                ButtonAction := (*) => ExecuteCursorShortcut(GetCursorActionShortcut("Explorer"))
            case "SourceControl":
                BaseText := GetText("quick_action_type_source_control")
                ButtonAction := (*) => ExecuteCursorShortcut(GetCursorActionShortcut("SourceControl"))
            case "Extensions":
                BaseText := GetText("quick_action_type_extensions")
                ButtonAction := (*) => ExecuteCursorShortcut(GetCursorActionShortcut("Extensions"))
            case "Browser":
                BaseText := GetText("quick_action_type_browser")
                ButtonAction := (*) => ExecuteCursorShortcut(GetCursorActionShortcut("Browser"))
            case "Settings":
                BaseText := GetText("quick_action_type_settings")
                ButtonAction := (*) => ExecuteCursorShortcut(GetCursorActionShortcut("Settings"))
            case "CursorSettings":
                BaseText := GetText("quick_action_type_cursor_settings")
                ButtonAction := (*) => ExecuteCursorShortcut(GetCursorActionShortcut("CursorSettings"))
        }
        
        ; 替换快捷键（将默认快捷键替换为配置的快捷键）
        ; 例如："解释代码 (E)" -> "解释代码 (e)"（如果配置的是e）
        ; 如果 Hotkey 为空（新增的 Cursor 快捷键选项），不显示快捷键
        if (BtnHotkey != "") {
            HotkeyUpper := StrUpper(BtnHotkey)
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
        switch BtnType {
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
        ; 按钮宽度 = 面板宽度 - 左右边距（30*2 = 60）
        ButtonWidth := CursorPanelWidth - 60
        Btn := GuiID_CursorPanel.Add("Button", "x30 y" . ButtonY . " w" . ButtonWidth . " h" . ButtonHeight, ButtonText)
        ; 按钮文字颜色：使用 html.to.design 风格配色
        global ThemeMode
        BtnTextColor := (ThemeMode = "light") ? UI_Colors.Text : UI_Colors.Text
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
    DescY := ButtonY + 10
    ; 说明文字宽度 = 面板宽度 - 左右边距（20*2 = 40）
    DescTextWidth := CursorPanelWidth - 40
    global CursorPanelDescText := GuiID_CursorPanel.Add("Text", "x20 y" . DescY . " w" . DescTextWidth . " h40 Center c" . UI_Colors.TextDim . " vCursorPanelDescText", "")
    CursorPanelDescText.SetFont("s9", "Segoe UI")
    
    ; 初始显示第一个按钮的说明（如果有按钮）
    if (QuickActionButtons.Length > 0) {
        FirstButtonDesc := ""
        firstType := ""
        firstBtn := QuickActionButtons[1]
        if (firstBtn is Map)
            firstType := firstBtn.Get("Type", "")
        else if (IsObject(firstBtn) && firstBtn.HasProp("Type"))
            firstType := firstBtn.Type
        switch firstType {
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
    ; 底部提示文字宽度 = 面板宽度 - 左右边距（20*2 = 40）
    FooterTextWidth := CursorPanelWidth - 40
    FooterText := GuiID_CursorPanel.Add("Text", "x20 y" . FooterY . " w" . FooterTextWidth . " h50 Center c" . UI_Colors.TextDim, GetText("footer_hint"))
    FooterText.SetFont("s9", "Segoe UI")
    
    ; 底部边框
    GuiID_CursorPanel.Add("Text", "x0 y" . (CursorPanelHeight - 10) . " w" . CursorPanelWidth . " h10 Background" . UI_Colors.Background, "")
    
    ; 获取屏幕信息并计算位置
    ScreenInfo := GetScreenInfo(CursorPanelScreenIndex)
    Pos := GetPanelPosition(ScreenInfo, CursorPanelWidth, CursorPanelHeight, FunctionPanelPos)
    
    ; ESC 键关闭面板
    GuiID_CursorPanel.OnEvent("Escape", (*) => CloseCursorPanel())
    
    ; 显示面板
    GuiID_CursorPanel.Show("w" . CursorPanelWidth . " h" . CursorPanelHeight . " x" . Pos.X . " y" . Pos.Y . " NoActivate")
    
    ; 【修改】ListView 始终显示，不需要临时显示/隐藏来初始化
    ; ListView 的坐标是相对于主面板的，主面板位置已确定，ListView 会自动正确定位
    
    ; 确保快捷操作面板始终在最上层（无论置顶状态如何，都要确保在其他面板之上）
    WinSetAlwaysOnTop(1, GuiID_CursorPanel.Hwnd)
    ; 根据置顶状态设置窗口（如果未启用置顶，则延迟移除，确保显示优先）
    if (!CursorPanelAlwaysOnTop) {
        ; 延迟移除置顶，给用户足够的时间看到面板
        SetTimer(RemoveCursorPanelAlwaysOnTop, -500)  ; 500ms后移除置顶
    }
    
    ; 启动定时器检测窗口位置（用于自动隐藏功能）
    if (CursorPanelAutoHide) {
        SetTimer(CheckCursorPanelEdge, 500)  ; 每500ms检测一次
    }
    
}

; ===================== 快捷操作面板搜索功能 =====================
; 搜索输入框Change事件（防抖）
ExecuteCursorPanelSearch(*) {
    global CursorPanelSearchDebounceTimer
    
    ; 取消之前的防抖定时器
    if (CursorPanelSearchDebounceTimer != 0) {
        try {
            SetTimer(CursorPanelSearchDebounceTimer, 0)
        } catch as err {
            ; 忽略错误
        }
        CursorPanelSearchDebounceTimer := 0
    }
    
    ; 设置新的防抖定时器（150ms 延迟）
    CursorPanelSearchDebounceTimer := DebouncedCursorPanelSearch
    SetTimer(CursorPanelSearchDebounceTimer, -150)
}

; 防抖后的实际搜索执行
DebouncedCursorPanelSearch(*) {
    global CursorPanelSearchEdit, CursorPanelResultLV, CursorPanelSearchResults
    global CursorPanelSearchDebounceTimer, ClipboardDB, global_ST, CursorPanelShowMoreBtn, GuiID_CursorPanel
    global CursorPanelWidth, CursorPanelHeight, CursorPanelScreenIndex, FunctionPanelPos
    
    ; 清除定时器标记
    CursorPanelSearchDebounceTimer := 0
    
    ; 【入口熔断】在执行搜索前，必须先检查并释放旧句柄
    if (IsObject(global_ST) && global_ST.HasProp("Free")) {
        try {
            global_ST.Free()
        } catch as err {
        }
        global_ST := 0
    }
    
    ; 【入口熔断】使用 GlobalSearchEngine 释放旧句柄（与全域搜索保持一致）
    GlobalSearchEngine.ReleaseOldStatement()
    
    Keyword := CursorPanelSearchEdit.Value
    if (StrLen(Keyword) < 1) {
        ; 【修改】输入框为空时，清空结果但保持 ListView 显示
        try {
            ; 彻底清空 ListView 内容
            CursorPanelResultLV.Opt("-Redraw")
            CursorPanelResultLV.Delete()
            CursorPanelResultLV.Opt("+Redraw")
            
            ; 重置搜索结果数组
            CursorPanelSearchResults := []
            
            ; 隐藏"更多"按钮（不再需要）
            CursorPanelShowMoreBtn.Visible := false
            
            ; 【关键】确保数据库句柄已释放，防止下次搜索时死锁
            if (IsObject(global_ST) && global_ST.HasProp("Free")) {
                try {
                    global_ST.Free()
                } catch as err {
                    ; 忽略错误
                }
                global_ST := 0
            }
        } catch as err {
            ; 控件可能已销毁，忽略错误
        }
        
        ; ListView 始终显示，不需要调整布局
        return
    }
    
    ; 【修改】使用 SearchAllDataSources 搜索所有数据源（包含 prompt、clipboard、config、file、hotkey、function、ui）
    ; SearchAllDataSources 内部已优先使用统一视图搜索（SearchGlobalView），如果没有结果则回退到多数据源搜索
    ; 统一视图和多数据源搜索的结果已经按时间排序（最新的在前），所以直接转换格式即可
    AllDataResults := SearchAllDataSources(Keyword, [], 50, 0)  ; CursorPanel 搜索，offset = 0
    Results := []
    
    ; 将 Map 格式转换为扁平化的数组
    for DataType, TypeData in AllDataResults {
        if (IsObject(TypeData) && TypeData.HasProp("Items")) {
            for Index, Item in TypeData.Items {
                ; 格式化时间显示
                TimeDisplay := ""
                if (Item.HasProp("TimeFormatted")) {
                    TimeDisplay := Item.TimeFormatted
                } else if (Item.HasProp("Timestamp")) {
                    try {
                        TimeDisplay := FormatTime(Item.Timestamp, "yyyy-MM-dd HH:mm:ss")
                    } catch as err {
                        TimeDisplay := Item.Timestamp
                    }
                } else {
                    TimeDisplay := ""
                }
                
                ; 生成标题（如果没有标题，从内容截取）
                TitleText := ""
                if (Item.HasProp("Title") && Item.Title != "") {
                    TitleText := Item.Title
                } else if (Item.HasProp("Content") && Item.Content != "") {
                    TitleText := SubStr(Item.Content, 1, 50)
                    if (StrLen(Item.Content) > 50) {
                        TitleText .= "..."
                    }
                } else {
                    TitleText := ""
                }
                
                ; 获取来源显示名称
                SourceName := TypeData.HasProp("DataTypeName") ? TypeData.DataTypeName : DataType
                
                Results.Push({
                    Title: TitleText,
                    Source: SourceName,
                    Time: TimeDisplay,
                    Content: Item.HasProp("Content") ? Item.Content : (Item.HasProp("Title") ? Item.Title : ""),
                    ID: Item.HasProp("ID") ? Item.ID : "",
                    DataType: DataType,
                    Action: Item.HasProp("Action") ? Item.Action : "",
                    ActionParams: Item.HasProp("ActionParams") ? Item.ActionParams : Map()
                })
            }
        }
    }
    
    ; 保存所有搜索结果
    CursorPanelSearchResults := Results
    
    ; 【修改】显示所有结果（最多 50 个），不再限制为前 5 个
    ; 更新ListView显示
    try {
        CursorPanelResultLV.Opt("-Redraw")
        CursorPanelResultLV.Delete()
        for Index, Item in Results {
            CursorPanelResultLV.Add(, Item.Title, Item.Source, Item.Time)
        }
        CursorPanelResultLV.Opt("+Redraw")
        
        ; ListView 始终显示，隐藏"更多"按钮（因为显示所有结果）
        CursorPanelResultLV.Visible := true
        CursorPanelShowMoreBtn.Visible := false
    } catch as err {
        ; 控件可能已销毁，忽略错误
    }
    
    ; ListView 始终显示，不需要调整布局
}

; 更新快捷操作面板布局（根据ListView是否显示调整高度）
UpdateCursorPanelLayout(ListViewVisible) {
    global GuiID_CursorPanel, CursorPanelWidth, CursorPanelHeight, CursorPanelScreenIndex, FunctionPanelPos
    global QuickActionButtons, ButtonSpacing
    
    if (GuiID_CursorPanel = 0) {
        return
    }
    
    try {
        ; 由于按钮位置已经固定在ListView下方，只需要根据ListView的显示状态调整窗口高度
        ; 实际上，面板高度已经在创建时预留了ListView的空间，所以这里只需要确保窗口大小正确
        ; 如果ListView隐藏，可以稍微减小高度（可选），但为了保持一致性，保持原高度
        
        ; 获取屏幕信息并重新计算位置（保持中心位置）
        ScreenInfo := GetScreenInfo(CursorPanelScreenIndex)
        Pos := GetPanelPosition(ScreenInfo, CursorPanelWidth, CursorPanelHeight, FunctionPanelPos)
        
        ; 调整窗口位置（保持大小不变，因为已经预留了空间）
        WinGetPos(&WinX, &WinY, &WinW, &WinH, GuiID_CursorPanel.Hwnd)
        if (WinX != Pos.X || WinY != Pos.Y) {
            GuiID_CursorPanel.Move(Pos.X, Pos.Y)
        }
        
        ; 重新绘制窗口
        WinRedraw(GuiID_CursorPanel.Hwnd)
    } catch as err {
        ; 忽略错误
    }
}

; 快捷操作面板"更多"按钮点击事件
OnCursorPanelShowMore(*) {
    global CursorPanelResultLV, CursorPanelSearchResults, CursorPanelShowMoreBtn
    
    if (CursorPanelSearchResults.Length <= 5) {
        CursorPanelShowMoreBtn.Visible := false
        return
    }
    
    ; 显示所有结果
    try {
        CursorPanelResultLV.Opt("-Redraw")
        CursorPanelResultLV.Delete()
        for Index, Item in CursorPanelSearchResults {
            ; 格式化时间显示
            TimeDisplay := Item.HasProp("TimeFormatted") ? Item.TimeFormatted : ""
            if (TimeDisplay = "" && Item.HasProp("Timestamp")) {
                try {
                    TimeDisplay := FormatTime(Item.Timestamp, "yyyy-MM-dd HH:mm:ss")
                } catch as err {
                    TimeDisplay := Item.Timestamp
                }
            }
            CursorPanelResultLV.Add(, Item.Title, Item.DataTypeName, TimeDisplay)
        }
        CursorPanelResultLV.Opt("+Redraw")
        
        ; 隐藏更多按钮
        CursorPanelShowMoreBtn.Visible := false
    } catch as err {
        ; 控件可能已销毁，忽略错误
    }
}

; 快捷操作面板搜索结果双击事件
OnCursorPanelResultDoubleClick(LV, Row) {
    global CursorPanelSearchResults
    
    if (Row > 0 && Row <= CursorPanelSearchResults.Length) {
        Item := CursorPanelSearchResults[Row]
        Content := Item.HasProp("Content") ? Item.Content : Item.Title
        
        ; 【修改】支持所有数据类型，根据 Action 执行相应操作
        if (Item.HasProp("Action")) {
            switch Item.Action {
                case "open_prompt":
                    ; 提示词类型：发送到 Cursor
                    TemplateFound := false
                    if (Item.HasProp("ID")) {
                        global TemplateIndexByID
                        if (TemplateIndexByID.Has(Item.ID)) {
                            Template := TemplateIndexByID[Item.ID]
                            SendTemplateToCursor(Template)
                            CloseCursorPanel()
                            TemplateFound := true
                            return  ; 找到模板，直接返回
                        }
                    }
                    ; 如果没有找到模板，使用通用处理（复制到剪贴板并粘贴）
                    ; 继续执行 copy_to_clipboard 的逻辑
                case "copy_to_clipboard":
                    ; 复制到剪贴板并粘贴（通用处理）
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
                        
                        ; 复制内容到剪贴板
                        OldClipboard := A_Clipboard
                        A_Clipboard := Content
                        
                        ; 粘贴
                        Send("^v")
                        Sleep(300)
                        
                        ; 提交
                        Send("{Enter}")
                        
                        ; 恢复剪贴板
                        Sleep(200)
                        A_Clipboard := OldClipboard
                        
                        ; 关闭面板
                        CloseCursorPanel()
                    } catch as e {
                        TrayTip("发送失败: " . e.Message, "错误", "Iconx 2")
                    }
                case "open_file":
                    ; 文件类型：打开文件
                    if (Item.HasProp("ActionParams") && Item.ActionParams.Has("FilePath")) {
                        FilePath := Item.ActionParams["FilePath"]
                        if (FileExist(FilePath)) {
                            Run(FilePath)
                            CloseCursorPanel()
                        } else {
                            TrayTip("文件不存在", "错误", "Iconx 2")
                        }
                    }
                default:
                    ; 默认：复制到剪贴板
                    A_Clipboard := Content
                    TrayTip("已复制到剪贴板", Item.Title, "Iconi 1")
                    CloseCursorPanel()
            }
        } else {
            ; 如果没有 Action，默认复制到剪贴板并粘贴到 Cursor
            global CursorPath, AISleepTime
            try {
                if (!WinExist("ahk_exe Cursor.exe")) {
                    if (CursorPath != "" && FileExist(CursorPath)) {
                        Run(CursorPath)
                        Sleep(AISleepTime)
                    } else {
                        TrayTip("Cursor未运行", "错误", "Iconx 2")
                        return
                    }
                }
                
                WinActivate("ahk_exe Cursor.exe")
                Sleep(200)
                Send("^l")
                Sleep(400)
                
                OldClipboard := A_Clipboard
                A_Clipboard := Content
                Send("^v")
                Sleep(300)
                Send("{Enter}")
                Sleep(200)
                A_Clipboard := OldClipboard
                
                CloseCursorPanel()
            } catch as e {
                TrayTip("发送失败: " . e.Message, "错误", "Iconx 2")
            }
        }
    }
}

; ===================== 移除快捷操作面板置顶（延迟调用）=====================
RemoveCursorPanelAlwaysOnTop(*) {
    global CursorPanelAlwaysOnTop, GuiID_CursorPanel
    if (!CursorPanelAlwaysOnTop && GuiID_CursorPanel != 0) {
        try {
            WinSetAlwaysOnTop(0, GuiID_CursorPanel.Hwnd)
        } catch as err {
        }
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
        } catch as err {
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
        } catch as err {
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
        } catch as err {
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
        } catch as err {
            ; 忽略错误
        }
    }
}

; ===================== 检测面板是否靠边 =====================
CheckCursorPanelEdge(*) {
    global GuiID_CursorPanel, CursorPanelAutoHide, CursorPanelHidden, CursorPanelWidth, CursorPanelHeight, CursorPanelScreenIndex, WindowDragging
    
    ; 如果窗口正在拖动，跳过检测以避免闪烁
    if (WindowDragging) {
        return
    }
    
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
    } catch as err {
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
    } catch as err {
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
    } catch as err {
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

GetCursorActionShortcut(ActionType) {
    global CursorShortcut_CommandPalette, CursorShortcut_Terminal, CursorShortcut_GlobalSearch
    global CursorShortcut_Explorer, CursorShortcut_SourceControl, CursorShortcut_Extensions
    global CursorShortcut_Browser, CursorShortcut_Settings, CursorShortcut_CursorSettings

    _ResolveVkShortcut(cmdId, fallback) {
        try {
            ; Always resolve to Cursor native shortcut target, not user trigger key.
            return CursorShortcutMapper_GetNativeShortcutByVkCommand(cmdId, fallback)
        } catch as e {
        }
        return fallback
    }

    switch ActionType {
        case "CommandPalette":
            return _ResolveVkShortcut("qa_command_palette", CursorShortcut_CommandPalette)
        case "Terminal":
            return _ResolveVkShortcut("qa_terminal", CursorShortcut_Terminal)
        case "GlobalSearch":
            return _ResolveVkShortcut("qa_global_search", CursorShortcut_GlobalSearch)
        case "Explorer":
            return _ResolveVkShortcut("qa_explorer", CursorShortcut_Explorer)
        case "SourceControl":
            return _ResolveVkShortcut("qa_source_control", CursorShortcut_SourceControl)
        case "Extensions":
            return _ResolveVkShortcut("qa_extensions", CursorShortcut_Extensions)
        case "Browser":
            return _ResolveVkShortcut("qa_browser", CursorShortcut_Browser)
        case "Settings":
            return _ResolveVkShortcut("qa_settings", CursorShortcut_Settings)
        case "CursorSettings":
            return _ResolveVkShortcut("qa_cursor_settings", CursorShortcut_CursorSettings)
        default:
            return ""
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

; 虚拟键盘 / 外部 vkExec：按模板 ID 走与 Explain 相同的 Cursor 发送流程
ExecutePromptByTemplateId(TemplateID) {
    if (TemplateID = "") {
        return
    }
    ExecutePrompt("Explain", TemplateID)
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


#Include "modules\LegacyConfigGui.ahk"
#Include "modules\LegacyClipboardListView.ahk"
#Include "modules\ConfigWebViewModule.ahk"

ShowConfigGUI() {
    global UseWebViewSettings
    if (UseWebViewSettings) {
        ShowConfigWebViewGUI()
        return
    }
    LegacyConfigGui_Show()
}



; ===================== 保存剪贴板管理器窗口位置 =====================
SaveClipboardManagerPosition() {
    global GuiID_ClipboardManager
    try {
        ; 检查窗口是否还存在
        if (!GuiID_ClipboardManager || GuiID_ClipboardManager = 0) {
            ; 窗口已关闭，停止定时器并立即保存所有待保存的位置
            SetTimer(() => SaveClipboardManagerPosition(), 0)
            FlushPendingWindowPositions()
            return
        }
        
        ; 获取窗口位置和大小
        WinGetPos(&WinX, &WinY, &WinW, &WinH, GuiID_ClipboardManager.Hwnd)
        WindowName := "📋 " . GetText("clipboard_manager")
        ; 使用延迟保存，统一管理
        QueueWindowPositionSave(WindowName, WinX, WinY, WinW, WinH)
    } catch as err {
        ; 忽略错误（窗口可能已关闭）
    }
}


; 关闭配置面板
CloseConfigGUI() {
    global CloseConfigGUI_IsClosing
    global GuiID_ConfigGUI, CapsLockHoldTimeEdit, CapsLockHoldTimeSeconds, ConfigFile
    global DDLBrush, DefaultStartTabDDL_Hwnd
    global ConfigWebViewMode, ConfigWV2Ctrl, ConfigWV2, ConfigWV2Ready

    ; 如果正在关闭，直接返回
    if (CloseConfigGUI_IsClosing) {
        return
    }
    
    ; 如果窗口已经不存在，直接返回
    if (GuiID_ConfigGUI = 0) {
        return
    }

    ; WebView 设置页关闭路径（首期改造）
    if (ConfigWebViewMode) {
        ConfigWebView_Close()
        return
    }
    
    LegacyConfigGui_CloseNative()
}

; ===================== 图标切换功能 =====================
ChangeCustomIcon(*) {
    global CustomIconPath, GuiID_ConfigGUI, SearchIcon, ConfigFile
    
    ; 打开文件选择对话框，只允许选择图片文件
    SelectedFile := FileSelect("1", A_ScriptDir, "选择图标文件", "图片文件 (*.ico; *.png; *.jpg; *.jpeg; *.bmp)")
    
    if (SelectedFile = "") {
        return  ; 用户取消了选择
    }
    
    ; 验证文件是否存在
    if (!FileExist(SelectedFile)) {
        MsgBox("文件不存在: " . SelectedFile, "错误", "Iconx")
        return
    }
    
    ; 更新全局变量
    CustomIconPath := SelectedFile
    
    ; 更新配置面板中的图标
    if (GuiID_ConfigGUI && SearchIcon) {
        try {
            ; 重新设置图标图片
            SearchIcon.Value := SelectedFile
            SearchIcon.Redraw()
        } catch as e {
            ; 如果更新失败，尝试重新创建图标控件
            try {
                ; 获取图标位置和大小
                IconX := 10
                IconY := 45
                IconSize := 32
                ; 删除旧图标
                SearchIcon.Destroy()
                ; 创建新图标
                global ConfigGUI
                ConfigGUI := GuiFromHwnd(GuiID_ConfigGUI)
                if (ConfigGUI) {
                    SearchIcon := ConfigGUI.Add("Picture", "x" . IconX . " y" . IconY . " w" . IconSize . " h" . IconSize . " 0x200 BackgroundTrans vConfigIcon", SelectedFile)
                    SearchIcon.OnEvent("Click", (*) => ChangeCustomIcon())
                    SearchIcon.Opt("+E0x200")
                }
            } catch as err {
                MsgBox("更新图标失败: " . e.Message, "错误", "Iconx")
            }
        }
    }
    
    ; 更新托盘图标
    UpdateTrayIcon()
    
    ; 保存配置（延迟保存，避免频繁IO）
    SetTimer((*) => SaveIconConfig(), -500)
}

; 保存图标配置
SaveIconConfig() {
    global CustomIconPath, ConfigFile
    if (IsSet(CustomIconPath)) {
        if (CustomIconPath != "" && FileExist(CustomIconPath)) {
            IniWrite(CustomIconPath, ConfigFile, "Settings", "CustomIconPath")
        } else {
            IniWrite("", ConfigFile, "Settings", "CustomIconPath")
        }
    }
}

; 更新托盘图标：见 modules\TrayMenuManager.ahk 中的 UpdateTrayIcon()

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
    
    NewClipboardPanelScreenIndex := 1
    global ClipboardPanelScreenRadio
    if (ClipboardPanelScreenRadio && ClipboardPanelScreenRadio.Length > 0) {
        for Index, RadioBtn in ClipboardPanelScreenRadio {
            if (RadioBtn.HasProp("IsSelected") && RadioBtn.IsSelected) {
                NewClipboardPanelScreenIndex := Index
                break
            }
        }
    }
    if (NewClipboardPanelScreenIndex < 1) {
        NewClipboardPanelScreenIndex := 1
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
    } catch as err {
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
    global CursorPath := NormalizeWindowsPath(CursorPathEdit ? CursorPathEdit.Value : "")
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
    ; 读取倒计时延迟时间
    global LaunchDelaySeconds, LaunchDelaySecondsEdit
    if (LaunchDelaySecondsEdit && LaunchDelaySecondsEdit.Value != "") {
        LaunchDelaySeconds := Float(LaunchDelaySecondsEdit.Value)
        ; 确保值在合理范围内（0.5秒到10秒）
        if (LaunchDelaySeconds < 0.5) {
            LaunchDelaySeconds := 0.5
        } else if (LaunchDelaySeconds > 10.0) {
            LaunchDelaySeconds := 10.0
        }
    } else {
        ; 如果编辑框为空，保持当前全局变量的值
        if (!IsSet(LaunchDelaySeconds) || LaunchDelaySeconds = "") {
            LaunchDelaySeconds := 3.0  ; 只有在完全未设置时才使用默认值
        }
    }
    global PanelScreenIndex := NewScreenIndex
    global Language := NewLanguage
    global ConfigPanelScreenIndex := NewConfigPanelScreenIndex
    global MsgBoxScreenIndex := NewMsgBoxScreenIndex
    global VoiceInputScreenIndex := NewVoiceInputScreenIndex
    global CursorPanelScreenIndex := NewCursorPanelScreenIndex
    global ClipboardPanelScreenIndex := NewClipboardPanelScreenIndex
    
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
    IniWrite(String(LaunchDelaySeconds), ConfigFile, "Settings", "LaunchDelaySeconds")
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
    
    ; 保存 Cursor 规则内容
    try {
        if (GuiID_ConfigGUI) {
            ConfigGUI := GuiFromHwnd(GuiID_ConfigGUI)
            if (ConfigGUI) {
                ; 定义所有规则类别
                RuleCategories := ["general", "web", "miniprogram", "plugin", "android", "ios", "python", "backend"]
                
                for Index, CategoryKey in RuleCategories {
                    try {
                        RulesEdit := ConfigGUI["CursorRulesContent" . CategoryKey]
                        if (RulesEdit) {
                            RulesContent := RulesEdit.Value
                            PlaceholderText := GetText("cursor_rules_content_placeholder")
                            ; 如果内容不是占位符且不为空，保存到配置文件
                            if (RulesContent != "" && RulesContent != PlaceholderText) {
                                ; IniWrite会自动处理换行符，直接保存即可
                                IniWrite(RulesContent, ConfigFile, "CursorRules", CategoryKey)
                            }
                        }
                    } catch as e {
                        ; 忽略单个规则保存失败，继续保存其他规则
                    }
                }
            }
        }
    } catch as e {
        ; 忽略保存规则时的错误，不影响其他配置的保存
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
        IniWrite("ai,cli,academic,baidu,image,audio,video,book,price,medical,cloud", ConfigFile, "Settings", "VoiceSearchEnabledCategories")
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
    IniWrite(ClipboardPanelScreenIndex, ConfigFile, "Advanced", "ClipboardPanelScreenIndex")
    
    ; 保存快捷操作按钮配置
    ButtonCount := QuickActionButtons.Length
    IniWrite(ButtonCount, ConfigFile, "QuickActions", "ButtonCount")
    for Index, Button in QuickActionButtons {
        btnType := "Explain"
        btnHotkey := "e"
        if (Button is Map) {
            btnType := Button.Get("Type", btnType)
            btnHotkey := Button.Get("Hotkey", btnHotkey)
        } else if (IsObject(Button)) {
            if Button.HasProp("Type")
                btnType := Button.Type
            if Button.HasProp("Hotkey")
                btnHotkey := Button.Hotkey
        }
        IniWrite(btnType, ConfigFile, "QuickActions", "Button" . Index . "Type")
        IniWrite(btnHotkey, ConfigFile, "QuickActions", "Button" . Index . "Hotkey")
    }
    
    ; 保存自定义图标路径
    global CustomIconPath
    if (IsSet(CustomIconPath)) {
        if (CustomIconPath != "" && FileExist(CustomIconPath)) {
            IniWrite(CustomIconPath, ConfigFile, "Settings", "CustomIconPath")
        } else {
            IniWrite("", ConfigFile, "Settings", "CustomIconPath")
        }
    }
    
    ; 更新托盘图标（使用自定义图标）
    UpdateTrayIcon()
    
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
                } catch as err {
                    ; 转换失败，保持当前值
                }
            }
        }
        
        ; 保存到配置文件（使用字符串格式确保精度）
        if (IsSet(CapsLockHoldTimeSeconds) && CapsLockHoldTimeSeconds != "") {
            IniWrite(String(CapsLockHoldTimeSeconds), ConfigFile, "Settings", "CapsLockHoldTimeSeconds")
        }
    } catch as err {
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
        ; 【完全隔离】恢复系统剪贴板到原始内容，不改变系统剪贴板
        A_Clipboard := OldClipboard

        TrimmedContent := Trim(NewContent, " `t`r`n")
        ; 无论 Hub 触发模式偏好（Caps / 双击 Ctrl+C），CapsLock+C 成功复制后都应同步草稿本 Hub
        if (TrimmedContent != "") {
            try {
                SelectionSense_SyncHubFromUserCopyChannel(TrimmedContent, true)
            } catch as HubOpenErr {
                TrayTip("HubCapsule 同步失败`n" . HubOpenErr.Message, GetText("tip"), "Iconx 2")
            }
        }
        
        ; 【升级采集与分拣逻辑】调用智能分拣流程
        try {
            ; 【强制引用】明确声明全局数据库对象
            global ClipboardDB
            
            ; 【数据库检查】如果数据库不存在或未初始化，先初始化
            if (!ClipboardDB || ClipboardDB = 0) {
                InitClipboardDB()
                ; 再次检查
                if (!ClipboardDB || ClipboardDB = 0) {
                    TrayTip("【故障】数据库初始化失败`n无法保存数据", GetText("tip"), "Iconx 3")
                    CapsLockCopyEndTime := A_TickCount
                    SetTimer(ClearCapsLockCopyFlag, -1500)
                    return
                }
            }
            
            ; 【环境捕获】获取 SourceApp, SourceTitle, SourcePath
            EnvInfo := CaptureEnvironmentInfo()
            SourceApp := EnvInfo["SourceApp"]
            SourceTitle := EnvInfo["SourceTitle"]
            SourcePath := EnvInfo["SourcePath"]
            
            ; 【智能分类】对选中的文本进行正则判定（Link, Email, Code, Text）
            Classification := ClassifyClipboardContent(NewContent)
            DataType := Classification["DataType"]
            CharCount := Classification["CharCount"]
            WordCount := Classification["WordCount"]
            
            ; 【数据统计】计算 CharCount 和 WordCount（已在 ClassifyClipboardContent 中完成）
            
            ; 【物理入库】调用 SaveToDB 函数，它会自动处理排重检查
            ; SaveToDB 内部会查询末位记录，如果内容重复则跳过
            ; 使用 Trim 处理内容，确保数据一致性
            global ClipboardListView, GuiID_ClipboardManager, CapsLockCCount, CapsLockCItems, ClipboardFTS5DB
            ; 调用 SaveToDB（11字段架构，废弃 SessionID 模式）
            SaveToDB(TrimmedContent, DataType, SourceApp, SourceTitle, SourcePath, CharCount, WordCount)
            
            ; 【同步到 FTS5 数据库】确保 ClipboardHistoryPanel 和剪贴板管理面板都能显示
            ; 参考 ClipboardHistoryPanel.ahk，使用 ClipboardFTS5DB 存储数据
            ; 【关键修改】CapsLock+C 的数据使用 "Stack" 作为 DataType，便于单独归类
            if (ClipboardFTS5DB && ClipboardFTS5DB != 0) {
                try {
                    SaveToClipboardFTS5(TrimmedContent, SourceApp, "Stack")
                } catch as err {
                    ; 忽略错误，不影响主流程
                }
            }
            
            ; 【存储到 CapsLock+C 数组】将内容添加到当前阶段的数组
            CapsLockCItems.Push(TrimmedContent)

            ; 【实时计数】鼠标旁 ToolTip：已复制 N 条（与 HubCapsule 预览并存）
            CapsLockCCount++
            ShowCapsLockCCountTooltip()

            ; 【同步UI刷新】数据存入数据库后，立即刷新列表（如果分类面板打开着）
            ; 确保数据即时出现在"全部"和"代码"标签下
            if (GuiID_ClipboardManager != 0) {
                ; 如果剪贴板管理面板已打开，立即刷新列表
                SetTimer(RefreshClipboardListDelayed, -50)  ; 延迟50ms刷新，确保数据库写入完成
            }
            
            ; 【同步剪贴板历史面板】如果剪贴板历史面板已打开，自动切换到 CapsLock+C 标签
            global HistoryIsVisible, HistorySelectedTag, HistoryTagButtons, HistorySearchEdit
            if (IsSet(HistoryIsVisible) && HistoryIsVisible) {
                ; 自动切换到 CapsLock+C 标签
                HistorySelectedTag := "CapsLockC"
                ; 更新标签按钮样式
                if (IsSet(HistoryTagButtons) && HistoryTagButtons.Has("CapsLockC")) {
                    ; 调用 UpdateHistoryTagButtons 函数（在 ClipboardHistoryPanel.ahk 中定义）
                    try {
                        UpdateHistoryTagButtons()
                    } catch {
                        ; 如果函数不存在，忽略错误
                    }
                }
                ; 刷新数据（只显示 CapsLock+C 的数据）
                keyword := ""
                if (IsSet(HistorySearchEdit) && HistorySearchEdit) {
                    keyword := Trim(HistorySearchEdit.Value)
                }
                HistoryCurrentLimit := 100
                try {
                    RefreshHistoryData(keyword, 0, HistoryCurrentLimit)
                } catch {
                    ; 如果函数不存在，忽略错误
                }
            }
            
            ; CapsLock+C：默认不再强行弹出「剪贴板管理」面板，避免打断 HubCapsule 的选中/堆叠流程
            ; 若用户已经打开剪贴板管理，则仍然刷新/切换到 CapsLockC 标签（保持兼容）
            if (GuiID_ClipboardManager != 0) {
                if (ClipboardCurrentTab != "CapsLockC") {
                    SwitchClipboardTab("CapsLockC")
                } else {
                    SetTimer(RefreshClipboardListDelayed, -100)
                }
            }

        } catch as e {
            ; 故障：处理失败
            A_Clipboard := OldClipboard
            TrayTip("【故障】处理失败`n错误：" . e.Message, GetText("tip"), "Iconx 3")
            CapsLockCopyEndTime := A_TickCount
            SetTimer(ClearCapsLockCopyFlag, -1500)
            return
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

; ===================== CapsLock+C 计数提示 =====================
; 显示 CapsLock+C 复制计数 Tooltip
ShowCapsLockCCountTooltip() {
    global CapsLockCCount, CapsLockCCountTooltip
    
    ; 获取鼠标位置
    MouseGetPos(&MouseX, &MouseY)
    
    ; 如果已有 Tooltip，先隐藏
    if (CapsLockCCountTooltip != 0) {
        ToolTip(, , , CapsLockCCountTooltip)
    }
    
    ; 显示新的 Tooltip
    ; 注意：ToolTip 的第4个参数必须是数字（ToolTip ID），不能是字符串
    TooltipText := "已复制 " . CapsLockCCount . " 条"
    ; 使用固定的 ToolTip ID（1），用于 CapsLock+C 计数提示
    CapsLockCCountTooltip := 1
    ToolTip(TooltipText, MouseX + 20, MouseY + 20, CapsLockCCountTooltip)
    
    ; 3秒后自动隐藏
    SetTimer(() => HideCapsLockCCountTooltip(), -3000)
}

; 隐藏 CapsLock+C 计数 Tooltip
HideCapsLockCCountTooltip() {
    global CapsLockCCountTooltip
    
    if (CapsLockCCountTooltip != 0) {
        ToolTip(, , , CapsLockCCountTooltip)
        CapsLockCCountTooltip := 0
    }
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
; CapsLock+V: 将当前阶段的所有内容合并后粘贴到 Cursor 输入框
CapsLockPaste() {
    try {
        global CapsLock2, g_HubCapsule_SelectedText, CapsLockCCount, CapsLockCItems
        CapsLock2 := false

        t := ""
        try t := Trim(String(g_HubCapsule_SelectedText), " `t`r`n")

        ; 若 HubCapsule 已选中某条卡片：直接粘贴到当前输入焦点（不强制切 Cursor）
        if (t != "") {
            SendText(t)
            ; 粘贴成功后，重置 CapsLock+C 阶段计数与缓存，开始新一轮
            CapsLockCCount := 0
            CapsLockCItems := []
            HideCapsLockCCountTooltip()
            return
        }

        ; 否则：弹出 HubCapsule 让用户点选卡片，再按一次 CapsLock+V 粘贴
        try {
            if FuncExists("SelectionSense_OpenHubCapsuleFromToolbar") {
                SelectionSense_OpenHubCapsuleFromToolbar(false, "")
                TrayTip("在 HubCapsule 点选要粘贴的卡片，再按 CapsLock+V", GetText("tip"), "Iconi 1")
                return
            }
        } catch as _e {
        }

        TrayTip("【警告】HubCapsule 未就绪`n请先用 CapsLock+C 复制内容", GetText("tip"), "Iconi 2")
    } catch as e {
        MsgBox(GetText("paste_failed") . ": " . e.Message)
    }
}


; ===================== 动态快捷键处理函数 =====================
; 检查按键是否匹配配置的快捷键，如果匹配则执行相应操作
HandleDynamicHotkey(PressedKey, ActionType) {
    global HotkeyESC, HotkeyC, HotkeyV, HotkeyX, HotkeyE, HotkeyR, HotkeyO, HotkeyQ, HotkeyZ, HotkeyT, HotkeyF, HotkeyP
    global CapsLock2, PanelVisible, VoiceInputActive, CapsLock, VoiceSearchActive
    global QuickActionButtons
    
    ; 如果使用了组合快捷键，清除显示面板的定时器（防止面板被激活）
    SetTimer(ShowPanelTimer, 0)  ; 停止ShowPanelTimer定时器
    ; 清除CapsLock2标记，防止面板被激活
    CapsLock2 := false
    RestoreCapsLockAfterChord()
    
    ; 将按键转换为小写进行比较（ESC特殊处理）
    KeyLower := StrLower(PressedKey)
    ConfigKey := ""

    ; 截图助手优先：当截图助手打开时，Q/E/C/R/Z/F/X/Esc 统一切到截图工具栏动作
    if (HandleScreenshotEditorHotkey(ActionType)) {
        return true
    }
    
    ; 首先检查是否匹配快捷操作按钮配置的快捷键
    if (PanelVisible && QuickActionButtons.Length > 0) {
        for Index, Button in QuickActionButtons {
            btnType := ""
            btnHotkey := ""
            if (Button is Map) {
                btnType := Button.Get("Type", "")
                btnHotkey := Button.Get("Hotkey", "")
            } else if (IsObject(Button)) {
                if Button.HasProp("Type")
                    btnType := Button.Type
                if Button.HasProp("Hotkey")
                    btnHotkey := Button.Hotkey
            }
            if (StrLower(btnHotkey) = KeyLower) {
                ; 匹配到快捷操作按钮（CapsLock2已在上面清除）
                ; 立即隐藏面板
                if (PanelVisible) {
                    HideCursorPanel()
                }
                switch btnType {
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
                        CP_Show()
                    case "Voice":
                        StartVoiceInput()
                    case "Split":
                        SplitCode()
                    case "Batch":
                        BatchOperation()
                    case "CommandPalette":
                        ExecuteCursorShortcut(GetCursorActionShortcut("CommandPalette"))
                    case "Terminal":
                        ExecuteCursorShortcut(GetCursorActionShortcut("Terminal"))
                    case "GlobalSearch":
                        ExecuteCursorShortcut(GetCursorActionShortcut("GlobalSearch"))
                    case "Explorer":
                        ExecuteCursorShortcut(GetCursorActionShortcut("Explorer"))
                    case "SourceControl":
                        ExecuteCursorShortcut(GetCursorActionShortcut("SourceControl"))
                    case "Extensions":
                        ExecuteCursorShortcut(GetCursorActionShortcut("Extensions"))
                    case "Browser":
                        ExecuteCursorShortcut(GetCursorActionShortcut("Browser"))
                    case "Settings":
                        ExecuteCursorShortcut(GetCursorActionShortcut("Settings"))
                    case "CursorSettings":
                        ExecuteCursorShortcut(GetCursorActionShortcut("CursorSettings"))
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
        case "T": ConfigKey := StrLower(HotkeyT)
        case "P": ConfigKey := StrLower(HotkeyP)
    }
    
    ; 如果按键匹配配置的快捷键，执行操作
    ; 添加调试信息
    if (ActionType = "T") {
        TrayTip("调试", "HandleDynamicHotkey T: KeyLower=" . KeyLower . ", ConfigKey=" . ConfigKey . ", HotkeyT=" . HotkeyT, "Iconi 1")
    }
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
                CP_Show()
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
                ; CapsLock+P：提示词快捷采集（区域截图请用 CapsLock+T 智能截图菜单）
                try PromptQuickPad_OpenCaptureDraft("", true)
                catch as e {
                    TrayTip("无法打开提示词采集：`n" . e.Message, GetText("tip"), "Iconx 2")
                }
            case "T":
                CapsLock2 := false
                ; 执行截图，完成后弹出智能菜单
                TrayTip("调试", "进入 case T，准备调用 ExecuteScreenshotWithMenu()", "Iconi 1")
                try {
                    ExecuteScreenshotWithMenu()
                    TrayTip("调试", "ExecuteScreenshotWithMenu() 调用完成", "Iconi 1")
                } catch as e {
                    TrayTip("错误", "执行截图失败: " . e.Message, "Iconx 2")
                }
        }
        return true  ; 已处理
    }
    return false  ; 未匹配，需要发送原始按键
}

; ===================== 截图助手（ScreenshotEditorPlugin 类模块）=====================
#Include modules\ScreenshotEditorPlugin.ahk

ShowScreenshotEditor(DebugGui := 0) {
    ScreenshotEditorPlugin.ShowScreenshotEditor(DebugGui)
}
CloseScreenshotEditor(*) {
    ScreenshotEditorPlugin.CloseScreenshotEditor()
}
CloseAllScreenshotWindows(*) {
    ScreenshotEditorPlugin.CloseAllScreenshotWindows()
}
IsScreenshotEditorActive() {
    return ScreenshotEditorPlugin.IsScreenshotEditorActive()
}
HandleScreenshotEditorHotkey(ActionType) {
    return ScreenshotEditorPlugin.HandleScreenshotEditorHotkey(ActionType)
}
IsScreenshotEditorZoomHotkeyActive() {
    return ScreenshotEditorPlugin_IsZoomHotkeyActive()
}
ToggleScreenshotEditorAlwaysOnTop(*) {
    ScreenshotEditorPlugin.ToggleScreenshotEditorAlwaysOnTop()
}
ScreenshotEditorSendToAI(*) {
    ScreenshotEditorPlugin.ScreenshotEditorSendToAI()
}
ScreenshotEditorSearchText(*) {
    ScreenshotEditorPlugin.ScreenshotEditorSearchText()
}
ExecuteScreenshotOCR(*) {
    ScreenshotEditorPlugin.ExecuteScreenshotOCR()
}
PasteScreenshotAsText(*) {
    ScreenshotEditorPlugin.PasteScreenshotAsText()
}
SaveScreenshotToFile(closeAfter := true) {
    ScreenshotEditorPlugin.SaveScreenshotToFile(closeAfter)
}
CopyScreenshotToClipboard(closeAfter := true) {
    ScreenshotEditorPlugin.CopyScreenshotToClipboard(closeAfter)
}
UpdateScreenshotEditorPreview(*) {
    ScreenshotEditorPlugin.UpdateScreenshotEditorPreview()
}
SyncScreenshotToolbarPosition(*) {
    ScreenshotEditorPlugin.SyncScreenshotToolbarPosition()
}
OnScreenshotEditorContextMenu(Ctrl, Info := 0, *) {
    ScreenshotEditorPlugin.OnScreenshotEditorContextMenu(Ctrl, Info)
}


; ===================== 截图业务流程（智能菜单 / 区域截图 / 悬浮按钮）=====================
#Include modules\ScreenshotWorkflow.ahk

; ===================== 面板快捷键 =====================
; 当 CapsLock 按下时，响应快捷键（采用 CapsLock+ 方案）
; 注意：在 AutoHotkey v2 中，需要使用函数来检查变量
#HotIf GetCapsLockState()

; ESC 关闭面板
Esc:: {
    if (VirtualKeyboard_HandleKey("Esc"))
        return
    if (!HandleDynamicHotkey("Esc", "ESC")) {
        ; 如果不匹配，发送原始按键
        Send("{Esc}")
    }
}

; C 键连续复制（立即响应，不等待面板）；$ 强制钩子，避免 WebView2 焦点下漏触发
$c:: {
    if (SearchCenter_HandleCapsChordKey("c"))
        return
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
    
    ; 确保 CapsLock 变量被设置（防止在释放时被清除）
    global CapsLock
    if (!CapsLock) {
        CapsLock := true
    }

    if (VirtualKeyboard_HandleKey("c"))
        return
    if (HandleDynamicHotkey("c", "C"))
        VK_NoteLastChFromCapsLockKey("c")
    else
        Send("c")
}

; V 键合并粘贴
$v:: {
    if (SearchCenter_HandleCapsChordKey("v"))
        return
    if (VirtualKeyboard_HandleKey("v"))
        return
    if (HandleDynamicHotkey("v", "V"))
        VK_NoteLastChFromCapsLockKey("v")
    else
        Send("v")
}

; X 键打开剪贴板管理面板（新的 FTS5 剪贴板管理器）
$x:: {
    if (SearchCenter_HandleCapsChordKey("x"))
        return
    if (VirtualKeyboard_HandleKey("x"))
        return
    if (HandleDynamicHotkey("x", "X"))
        VK_NoteLastChFromCapsLockKey("x")
    else
        Send("x")
}

; E 键执行解释
$e:: {
    if (SearchCenter_HandleCapsChordKey("e"))
        return
    if (VirtualKeyboard_HandleKey("e"))
        return
    if (HandleDynamicHotkey("e", "E"))
        VK_NoteLastChFromCapsLockKey("e")
    else
        Send("e")
}

; R 键执行重构
$r:: {
    if (SearchCenter_HandleCapsChordKey("r"))
        return
    if (VirtualKeyboard_HandleKey("r"))
        return
    if (HandleDynamicHotkey("r", "R"))
        VK_NoteLastChFromCapsLockKey("r")
    else
        Send("r")
}

; O 键执行优化
o:: {
    if (VirtualKeyboard_HandleKey("o"))
        return
    if (HandleDynamicHotkey("o", "O"))
        VK_NoteLastChFromCapsLockKey("o")
    else
        Send("o")
}

; Q 键打开配置面板
$q:: {
    if (SearchCenter_HandleCapsChordKey("q"))
        return
    if (VirtualKeyboard_HandleKey("q"))
        return
    if (HandleDynamicHotkey("q", "Q"))
        VK_NoteLastChFromCapsLockKey("q")
    else
        Send("q")
}

; Z 键语音输入（切换模式）
$z:: {
    if (SearchCenter_HandleCapsChordKey("z"))
        return
    if (VirtualKeyboard_HandleKey("z"))
        return
    if (HandleDynamicHotkey("z", "Z"))
        VK_NoteLastChFromCapsLockKey("z")
    else
        Send("z")
}

; T 键执行截图并弹出智能菜单
t:: {
    if (VirtualKeyboard_HandleKey("t"))
        return
    ; 添加调试信息
    TrayTip("调试", "CapsLock+T 被触发", "Iconi 1")
    if (HandleDynamicHotkey("t", "T")) {
        TrayTip("调试", "HandleDynamicHotkey 返回 true，已处理", "Iconi 1")
        VK_NoteLastChFromCapsLockKey("t")
    } else {
        TrayTip("调试", "HandleDynamicHotkey 返回 false，发送原始按键", "Iconi 1")
        Send("t")
    }
}

; F 键：激活搜索中心或执行区域内操作
f:: {
    global IsCountdownActive, CapsLock2
    if (VirtualKeyboard_HandleKey("f"))
        return
    ; 标记已使用组合键，避免 CapsLock 释放时走“单击切换大小写”分支
    CapsLock2 := false
    RestoreCapsLockAfterChord()
    ; 如果倒计时正在进行，按下 F 立即加速执行（发射内容）
    if (IsCountdownActive) {
        ExecuteCountdownAction()
        VK_NoteLastChFromCapsLockKey("f")
        return
    }
    
    ; 如果 SearchCenter 窗口已激活，执行区域内操作逻辑
    if (IsSearchCenterActive()) {
        HandleSearchCenterF()
        VK_NoteLastChFromCapsLockKey("f")
    } else {
        ; 否则激活搜索中心窗口
        ShowSearchCenter()
        VK_NoteLastChFromCapsLockKey("f")
    }
}

; G 键激活语音搜索面板
g:: {
    global CapsLock2
    if (VirtualKeyboard_HandleKey("g"))
        return
    ; 与 CapsLock+F 一致：明确标记组合键已消费，避免释放时误切换大小写状态
    CapsLock2 := false
    RestoreCapsLockAfterChord()
    ; CapsLock+G 激活原来的语音搜索面板
    StartVoiceSearch()
    VK_NoteLastChFromCapsLockKey("g")
}

; B 键：面板显示且批量键为 B 时走 BatchOperation；面板显示且非批量键则透传 b；面板未显示时打开 Prompt 采集窗
b:: {
    global BatchHotkey, CapsLock2
    if (VirtualKeyboard_HandleKey("b"))
        return
    RestoreCapsLockAfterChord()
    if GetPanelVisibleState() {
        CapsLock2 := false
        RestoreCapsLockAfterChord()
        if StrLower(BatchHotkey) = "b" {
            BatchOperation()
            VK_NoteLastChFromCapsLockKey("b")
            return
        }
        Send("b")
        return
    }
    PromptQuickPad_HandleCapsLockB()
    VK_NoteLastChFromCapsLockKey("b")
}

#HotIf  ; 结束 GetCapsLockState() 作用域，为 SearchCenter 专用热键让路

; ===================== SearchCenter 窗口热键（优先级最高）=====================
; 【重要】必须在全局 CapsLock 热键之前定义，确保优先级
; 【作用域】仅在 SearchCenter 窗口激活时生效

#HotIf IsSearchCenterActive()

; ESC 键：关闭搜索中心窗口或取消倒计时
Esc:: {
    global IsCountdownActive
    if (IsCountdownActive) {
        CancelCountdown()
    } else {
        SearchCenterCloseHandler()
    }
}

    ; Enter 键：根据焦点区域执行不同操作，或加速倒计时
Enter:: {
    global IsCountdownActive
    global GuiID_SearchCenter, SearchCenterSearchEdit
    if (IsCountdownActive) {
        ExecuteCountdownAction()
        return
    }
    global SearchCenterActiveArea, SearchCenterResultLV, SearchCenterSearchResults, SearchCenterSearchEdit
    
    ; CLI：焦点在顶部输入框时一律发送（避免 ActiveArea 仍为 listview 等导致 Enter 未触发 CLI）
    if (SearchCenterIsCLICategory() && SearchCenterSearchEdit != 0 && GuiID_SearchCenter != 0) {
        try {
            Fh := ControlGetFocus("ahk_id " . GuiID_SearchCenter.Hwnd)
            if (Fh && Fh = SearchCenterSearchEdit.Hwnd) {
                ExecuteSearchCenterCLICommand()
                return
            }
        } catch {
        }
    }
    
    if (SearchCenterIsCLICategory() && (SearchCenterActiveArea = "input" || SearchCenterActiveArea = "category")) {
        ExecuteSearchCenterCLICommand()
        return
    }
    
    if (SearchCenterActiveArea = "listview") {
        ; 焦点在ListView：启动倒计时
        if (!SearchCenterResultLV || SearchCenterResultLV = 0) {
            return
        }
        
        SelectedRow := SearchCenterResultLV.GetNext()
        if (SelectedRow = 0) {
            ; 如果没有选中项，选中第一项
            if (SearchCenterResultLV.GetCount() > 0) {
                SearchCenterResultLV.Modify(1, "Select Focus")
                SelectedRow := 1
            } else {
                return
            }
        }
        
        ; 获取选中项的内容并启动倒计时
        if (SelectedRow > 0 && SelectedRow <= SearchCenterSearchResults.Length) {
            Item := GetSearchCenterResultItemByRow(SelectedRow)
            if (!IsObject(Item)) {
                return
            }
            Content := Item.HasProp("Content") ? Item.Content : Item.Title
            
            ; 启动倒计时前的准备（不显示提示，直接进入倒计时准备粘贴）
            SearchCenterListViewLaunchHandler(Content, Item.Title)
        }
    } else {
        ; 【关键修复】焦点在输入框或分类栏：如果输入框有内容，执行批量搜索跳转到已勾选的搜索引擎；否则执行批量搜索
        if (SearchCenterActiveArea = "input" && IsSet(SearchCenterSearchEdit) && SearchCenterSearchEdit && SearchCenterSearchEdit.Value != "") {
            ; 输入框有内容，执行批量搜索跳转到已勾选的搜索引擎
            ExecuteSearchCenterBatchSearch()
        } else {
            ; 焦点在分类栏或输入框为空：执行批量搜索
            ExecuteSearchCenterBatchSearch()
        }
    }
}

; 方向键映射（在 searchcenter 中遵守三个区域的操作规范）
; 【三个区域】category（分类栏）、input（输入框）、listview（结果列表）
; 【行为规范】详见 HandleSearchCenterUp/Down/Left/Right 函数的注释
$Up::HandleSearchCenterUp()      ; ↑ 键：根据当前区域执行相应操作
$Down::HandleSearchCenterDown()  ; ↓ 键：根据当前区域执行相应操作
$Left::HandleSearchCenterLeft()   ; ← 键：根据当前区域执行相应操作
$Right::HandleSearchCenterRight() ; → 键：根据当前区域执行相应操作

; CapsLock + WASD 映射（完全复刻方向键功能）
; 【优先级】更具体的作用域（IsSearchCenterActive() && GetCapsLockState()）优先于全局作用域（GetCapsLockState()）
; 【功能】在 searchcenter 中，capslock+wsad 与方向键行为完全一致，遵守三个区域的操作规范
; 【三个区域】category（分类栏）、input（输入框）、listview（结果列表）
#HotIf IsSearchCenterActive() && GetCapsLockState()
$q::SearchCenter_HandleCapsChordKey("q")
$w::SearchCenter_HandleCapsChordKey("w")
$e::SearchCenter_HandleCapsChordKey("e")
$r::SearchCenter_HandleCapsChordKey("r")
$a::SearchCenter_HandleCapsChordKey("a")
$s::SearchCenter_HandleCapsChordKey("s")
$d::SearchCenter_HandleCapsChordKey("d")
$z::SearchCenter_HandleCapsChordKey("z")
$x::SearchCenter_HandleCapsChordKey("x")
$c::SearchCenter_HandleCapsChordKey("c")
$v::SearchCenter_HandleCapsChordKey("v")

; F 键：在倒计时期间加速执行
$f:: {
    global IsCountdownActive, CapsLock2
    CapsLock2 := false
    if (IsCountdownActive) {
        ExecuteCountdownAction()
    } else {
        HandleSearchCenterF()
    }
}

#HotIf  ; 结束 SearchCenter 作用域

; ===================== 倒计时期间全局热键 =====================
; 【作用域】倒计时激活时全局生效（优先级最高）
#HotIf IsCountdownActive

; F 键：加速执行
f:: {
    ExecuteCountdownAction()
}

; Enter 键：加速执行
Enter:: {
    ExecuteCountdownAction()
}

; ESC 键：取消倒计时
Esc:: {
    CancelCountdown()
}

#HotIf  ; 结束倒计时作用域

; ===================== 全局 CapsLock 热键（优先级较低）=====================
; 【作用域】CapsLock 按下时全局生效（SearchCenter 除外，因为上面已经定义了更具体的热键）
#HotIf GetCapsLockState()

; W 键映射为 Up（上方向键）- 全局生效（SearchCenter 中会被上面的专用热键覆盖）
$w:: {
    if (SearchCenter_HandleCapsChordKey("w"))
        return
    global CapsLock2
    if (VirtualKeyboard_HandleKey("w"))
        return
    CapsLock2 := false
    RestoreCapsLockAfterChord()
    Send("{Up}")
    VK_NoteLastChFromCapsLockKey("w")
}

; S 键映射为 Down（下方向键）- 全局生效（SearchCenter 中会被上面的专用热键覆盖）
$s:: {
    if (SearchCenter_HandleCapsChordKey("s"))
        return
    global CapsLock2
    if (VirtualKeyboard_HandleKey("s"))
        return
    CapsLock2 := false
    RestoreCapsLockAfterChord()
    Send("{Down}")
    VK_NoteLastChFromCapsLockKey("s")
}

; A 键映射为 Left（左方向键）- 全局生效（SearchCenter 中会被上面的专用热键覆盖）
$a:: {
    if (SearchCenter_HandleCapsChordKey("a"))
        return
    global CapsLock2
    if (VirtualKeyboard_HandleKey("a"))
        return
    CapsLock2 := false
    RestoreCapsLockAfterChord()
    Send("{Left}")
    VK_NoteLastChFromCapsLockKey("a")
}

; D 键映射为 Right（右方向键）- 全局生效（SearchCenter 中会被上面的专用热键覆盖）
$d:: {
    if (SearchCenter_HandleCapsChordKey("d"))
        return
    global CapsLock2
    if (VirtualKeyboard_HandleKey("d"))
        return
    CapsLock2 := false
    RestoreCapsLockAfterChord()
    Send("{Right}")
    VK_NoteLastChFromCapsLockKey("d")
}

; P 键区域截图
p:: {
    if (VirtualKeyboard_HandleKey("p"))
        return
    if (HandleDynamicHotkey("p", "P"))
        VK_NoteLastChFromCapsLockKey("p")
    else
        Send("p")
}

; 1-5 键激活对应顺序的快捷操作按钮
1:: {
    if (VirtualKeyboard_HandleKey("1"))
        return
    ActivateQuickActionButton(1)
}

2:: {
    if (VirtualKeyboard_HandleKey("2"))
        return
    ActivateQuickActionButton(2)
}

3:: {
    if (VirtualKeyboard_HandleKey("3"))
        return
    ActivateQuickActionButton(3)
}

4:: {
    if (VirtualKeyboard_HandleKey("4"))
        return
    ActivateQuickActionButton(4)
}

5:: {
    if (VirtualKeyboard_HandleKey("5"))
        return
    ActivateQuickActionButton(5)
}

#HotIf

; ===================== SearchCenter 其他功能键 =====================

#HotIf  ; 结束 IsSearchCenterActive() && GetCapsLockState() 作用域

; ===================== 快捷操作（设置「快捷按钮」同款，可从任意上下文调用）=====================
ExecuteQuickActionByType(Type) {
    global CapsLock2, PanelVisible

    CapsLock2 := false
    if (PanelVisible) {
        HideCursorPanel()
    }

    switch Type {
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
            CP_Show()
        case "Voice":
            StartVoiceInput()
        case "Split":
            SplitCode()
        case "Batch":
            BatchOperation()
        case "CommandPalette":
            ExecuteCursorShortcut(GetCursorActionShortcut("CommandPalette"))
        case "Terminal":
            ExecuteCursorShortcut(GetCursorActionShortcut("Terminal"))
        case "GlobalSearch":
            ExecuteCursorShortcut(GetCursorActionShortcut("GlobalSearch"))
        case "Explorer":
            ExecuteCursorShortcut(GetCursorActionShortcut("Explorer"))
        case "SourceControl":
            ExecuteCursorShortcut(GetCursorActionShortcut("SourceControl"))
        case "Extensions":
            ExecuteCursorShortcut(GetCursorActionShortcut("Extensions"))
        case "Browser":
            ExecuteCursorShortcut(GetCursorActionShortcut("Browser"))
        case "Settings":
            ExecuteCursorShortcut(GetCursorActionShortcut("Settings"))
        case "CursorSettings":
            ExecuteCursorShortcut(GetCursorActionShortcut("CursorSettings"))
    }
}

; 按槽位执行当前 ini 配置的快捷按钮（虚拟键盘 ch_1–ch_5 等，无需先打开面板）
ExecuteQuickActionSlot(Index) {
    global QuickActionButtons

    if (Index < 1 || Index > QuickActionButtons.Length) {
        return
    }
    Button := QuickActionButtons[Index]
    btnType := ""
    if (Button is Map)
        btnType := Button.Get("Type", "")
    else if (IsObject(Button) && Button.HasProp("Type"))
        btnType := Button.Type
    if (btnType = "")
        return
    ExecuteQuickActionByType(btnType)
    VK_NoteLastExecutedId("ch_" . Index)
}

; ===================== 激活快捷操作按钮（仅面板显示时 CapsLock+1–5）=====================
ActivateQuickActionButton(Index) {
    global QuickActionButtons, PanelVisible

    if (!PanelVisible) {
        return
    }
    if (Index < 1 || Index > QuickActionButtons.Length) {
        return
    }
    Button := QuickActionButtons[Index]
    btnType := ""
    if (Button is Map)
        btnType := Button.Get("Type", "")
    else if (IsObject(Button) && Button.HasProp("Type"))
        btnType := Button.Type
    if (btnType = "")
        return
    ExecuteQuickActionByType(btnType)
    VK_NoteLastExecutedId("ch_" . Index)
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
; 注：CapsLock+B 批量逻辑已合并到上方 #HotIf GetCapsLockState() 的 b:: 中

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
            } catch as err {
                ; 如果注册表项不存在，忽略错误
            }
        }
    } catch as e {
        ; 如果操作失败，显示错误提示（可选）
        ; TrayTip("设置自启动失败: " . e.Message, "错误", "Iconx 2")
    }
}

; ===================== 全局搜索引擎类 =====================
/**
 * 全局搜索引擎类
 * 彻底解决句柄泄露和 Database Locked 问题
 * 引入熔断机制、Try-Finally 保护、并发同步
 */
class GlobalSearchEngine {
    /**
     * 熔断机制：在执行 Prepare 之前强制释放旧的 Statement 句柄
     */
    static ReleaseOldStatement() {
        global GlobalSearchStatement
        try {
            if (IsObject(GlobalSearchStatement) && GlobalSearchStatement != 0) {
                GlobalSearchStatement.Free()
                GlobalSearchStatement := 0
            }
        } catch as e {
            OutputDebug("释放旧 Statement 失败: " . e.Message)
            GlobalSearchStatement := 0
        }
    }
    
    static PerformSearch(Keyword, MaxResults := 100) {
        global ClipboardDB, GlobalSearchStatement, global_ST
        Results := []
        ST := 0  ; 局部 Statement 句柄
        
        ; 检查数据库是否已初始化
        if (!IsObject(ClipboardDB) || ClipboardDB = 0) {
            return Results
        }
        
        ; 【入口熔断】在执行任何 Prepare 之前，必须先检查并释放旧句柄
        if (IsObject(global_ST) && global_ST.HasProp("Free")) {
            try {
                global_ST.Free()
            } catch as err {
            }
            global_ST := 0
        }
        
        ; 【熔断机制】在执行任何 Prepare 之前，强制释放旧的 Statement
        GlobalSearchEngine.ReleaseOldStatement()
        
        ; 构建模糊匹配模式
        SearchPattern := "%" . Keyword . "%"
        
        try {
            ; 使用 UNION ALL 一次性查询提示词和剪贴板
            SQL := "
            (
                SELECT Name AS Title, Content, '提示词' AS Source, CreateTime, rowid AS ID 
                FROM Prompts 
                WHERE Name LIKE ? OR Content LIKE ?
                UNION ALL
                SELECT SUBSTR(Content, 1, 50) AS Title, Content, '剪贴板' AS Source, CreateTime, rowid AS ID 
                FROM ClipboardHistory 
                WHERE Content LIKE ?
                ORDER BY CreateTime DESC 
                LIMIT " . MaxResults . "
            )"
            
            ; 准备语句
            if !ClipboardDB.Prepare(SQL, &ST) {
                return Results
            }
            
            ; 更新全局 Statement（用于熔断机制）
            GlobalSearchStatement := ST
            global_ST := ST  ; 同时更新 global_ST

            ; 绑定参数（防止 SQL 注入并提高性能）
            ST.Bind(1, SearchPattern)
            ST.Bind(2, SearchPattern)
            ST.Bind(3, SearchPattern)

            ; 【Try-Finally 保护】将 Step() 循环包裹在 try-finally 中
            try {
                ; 迭代结果集
                while (ST.Step() = 100) { ; 100 代表 SQLITE_ROW
                    Results.Push({
                        Title: ST.ColumnText(0),
                        Content: ST.ColumnText(1),
                        Source: ST.ColumnText(2),
                        Time: ST.ColumnText(3),
                        ID: ST.ColumnInt(4)
                    })
                }
            } catch as e {
                OutputDebug("搜索 Step() 循环出错: " . e.Message)
            } finally {
                ; 【过程保底】无论查询成功还是报错，都在 finally 块中释放句柄
                try {
                    if (IsObject(global_ST) && global_ST.HasProp("Free")) {
                        global_ST.Free()
                    }
                    global_ST := 0
                } catch as err {
                }
                ; 清空全局 Statement
                if (GlobalSearchStatement = ST) {
                    GlobalSearchStatement := 0
                }
            }
        } catch as e {
            OutputDebug("搜索出错: " . e.Message)
            ; 【过程保底】确保异常时也释放句柄
            try {
                if (IsObject(global_ST) && global_ST.HasProp("Free")) {
                    global_ST.Free()
                }
                global_ST := 0
            } catch as err {
            }
            ; 注意：global_ST 已在上面释放，这里只清理 GlobalSearchStatement
            if (GlobalSearchStatement = ST) {
                GlobalSearchStatement := 0
            }
        }
        
        return Results
    }
}

; ===================== 搜索中心导航处理函数 =====================
; 处理搜索中心的上方向导航 (Up / W)
; 处理搜索中心的上方向导航 (Up / W)
; 【功能】完全复刻方向键行为，遵守三个区域的操作规范
; 【区域1：category（分类栏）】↑/W：向上切换分类
; 【区域2：input（输入框）】↑/W：切换到分类栏
; 【区域3：listview（列表区域）】↑/W：如果在第一行 → 切换到输入框；否则 → 向上移动
HandleSearchCenterUp() {
    global SearchCenterActiveArea, SearchCenterResultLV, SearchCenterSearchEdit, GuiID_SearchCenter, CapsLock2
    CapsLock2 := false
    
    if (SearchCenterActiveArea = "category") {
        ; category (分类栏) -> ↑/W：向上切换分类
        SwitchSearchCenterCategory(-1)
    } else if (SearchCenterActiveArea = "input") {
        ; input (输入框) -> ↑/W：切换到分类栏
        SearchCenterActiveArea := "category"
        UpdateSearchCenterHighlight()
    } else if (SearchCenterActiveArea = "listview") {
        ; listview (列表区域) -> ↑/W：如果在第一行 → 切换到输入框；否则 → 向上移动
        if (SearchCenterResultLV != 0) {
            try {
                SelectedRow := SearchCenterResultLV.GetNext()
                if (SelectedRow <= 1) {
                    SearchCenterActiveArea := "input"
                    UpdateSearchCenterHighlight()
                    if (SearchCenterSearchEdit != 0) {
                        try {
                            SearchCenterSearchEdit.Focus()
                        } catch as err {
                            ; 忽略焦点错误
                        }
                    }
                } else {
                    ; 使用 $ 前缀防止循环触发热键，这里可以直接 send
                    Send("{Up}")
                }
            } catch as e {
                SearchCenterActiveArea := "input"
                UpdateSearchCenterHighlight()
            }
        }
    }
}

; 处理搜索中心的下方向导航 (Down / S)
; 【功能】完全复刻方向键行为，遵守三个区域的操作规范
; 【区域1：category（分类栏）】↓/S：切换到输入框
; 【区域2：input（输入框）】↓/S：切换到列表区域
; 【区域3：listview（列表区域）】↓/S：向下移动
HandleSearchCenterDown() {
    global SearchCenterActiveArea, SearchCenterResultLV, SearchCenterSearchEdit, GuiID_SearchCenter, CapsLock2
    CapsLock2 := false
    
    if (SearchCenterActiveArea = "category") {
        ; category (分类栏) -> ↓/S：切换到输入框
        SearchCenterActiveArea := "input"
        UpdateSearchCenterHighlight()
        if (SearchCenterSearchEdit != 0) {
            try {
                SearchCenterSearchEdit.Focus()
            } catch as err {
                ; 忽略焦点错误
            }
        }
    } else if (SearchCenterActiveArea = "input") {
        ; input (输入框) -> ↓/S：切换到列表区域
        SearchCenterActiveArea := "listview"
        UpdateSearchCenterHighlight()
        if (SearchCenterResultLV != 0) {
            try {
                if (GuiID_SearchCenter != 0 && !WinActive("ahk_id " . GuiID_SearchCenter.Hwnd)) {
                    WinActivate("ahk_id " . GuiID_SearchCenter.Hwnd)
                }
                ; 【优化】自动选中第一行，以便用户直接按 F 键"开火"
                if (SearchCenterResultLV.GetCount() > 0) {
                    SearchCenterResultLV.Modify(1, "Select Focus")
                    ; 确保第一行被选中并聚焦
                    Sleep(50)  ; 短暂延迟确保选中生效
                }
                ControlFocus(SearchCenterResultLV)
            } catch as e {
                ; 忽略焦点错误
            }
        }
    } else if (SearchCenterActiveArea = "listview") {
        ; listview (列表区域) -> ↓/S：向下移动
        Send("{Down}")
    }
}

; 处理搜索中心的左方向导航 (Left / A)
; 【功能】完全复刻方向键行为，遵守三个区域的操作规范
; 【区域1：category（分类栏）】←/A：向左切换分类
; 【区域2：input（输入框）】←/A：光标左移
; 【区域3：listview（列表区域）】←/A：向上翻页（PageUp）
HandleSearchCenterLeft() {
    global SearchCenterActiveArea, CapsLock2
    CapsLock2 := false
    if (SearchCenterActiveArea = "category") {
        ; category (分类栏) -> ←/A：向左切换分类
        SwitchSearchCenterCategory(-1)
    } else if (SearchCenterActiveArea = "input") {
        ; input (输入框) -> ←/A：光标左移
        Send("{Left}")
    } else if (SearchCenterActiveArea = "listview") {
        ; listview (列表区域) -> ←/A：向上翻页（PageUp）
        Send("{PgUp}")
    }
}

; 处理搜索中心的右方向导航 (Right / D)
; 【功能】完全复刻方向键行为，遵守三个区域的操作规范
; 【区域1：category（分类栏）】→/D：向右切换分类
; 【区域2：input（输入框）】→/D：光标右移
; 【区域3：listview（列表区域）】→/D：向下翻页（PageDown）
HandleSearchCenterRight() {
    global SearchCenterActiveArea, CapsLock2
    CapsLock2 := false
    if (SearchCenterActiveArea = "category") {
        ; category (分类栏) -> →/D：向右切换分类
        SwitchSearchCenterCategory(1)
    } else if (SearchCenterActiveArea = "input") {
        ; input (输入框) -> →/D：光标右移
        Send("{Right}")
    } else if (SearchCenterActiveArea = "listview") {
        ; listview (列表区域) -> →/D：向下翻页（PageDown）
        Send("{PgDn}")
    }
}

; 处理搜索中心 F 键导航 (F)
HandleSearchCenterF() {
    global SearchCenterActiveArea, SearchCenterResultLV, SearchCenterSearchResults
    global SearchCenterSearchEdit, CursorPath, CapsLock2
    
    ; 标记已处理按键，防止 CapsLock 切换状态
    CapsLock2 := false
    
    if (SearchCenterIsCLICategory() && (SearchCenterActiveArea = "input" || SearchCenterActiveArea = "category")) {
        ExecuteSearchCenterCLICommand()
        return
    }
    
    if (SearchCenterActiveArea = "category" || SearchCenterActiveArea = "input") {
        ; 搜索引擎/输入框区域：执行搜索操作
        ExecuteSearchCenterBatchSearch()
    } else if (SearchCenterActiveArea = "listview") {
        ; ListView 区域：如果已选中数据，立即启动倒计时准备粘贴
        if (!SearchCenterResultLV || SearchCenterResultLV = 0) {
            return
        }
        
        SelectedRow := SearchCenterResultLV.GetNext()
        if (SelectedRow <= 0) {
            ; 如果没有选中项，选中第一项
            if (SearchCenterResultLV.GetCount() > 0) {
                SearchCenterResultLV.Modify(1, "Select Focus")
                SelectedRow := 1
            } else {
                TrayTip("没有可用的搜索结果", "提示", "Icon! 2")
                return
            }
        }
        
        ; 获取选中内容并立即启动倒计时
        if (SelectedRow > 0 && SelectedRow <= SearchCenterSearchResults.Length) {
            Item := GetSearchCenterResultItemByRow(SelectedRow)
            if (!IsObject(Item)) {
                return
            }
            Content := Item.HasProp("Content") ? Item.Content : Item.Title
            
            ; 调用启动处理函数（封装了隐藏窗口和启动倒计时的逻辑）
            SearchCenterListViewLaunchHandler(Content, Item.Title)
        }
    }
}

; 搜索中心内容发射处理程序（封装逻辑，供 Enter 和 F 键共用）
SearchCenterListViewLaunchHandler(Content, Title) {
    global GuiID_SearchCenter, global_ST
    
    ; 1. 彻底销毁搜索中心窗口，确保 CapsLock + F 逻辑完美重置
    try {
        if (GuiID_SearchCenter != 0 && IsObject(GuiID_SearchCenter)) {
            CleanupSearchCenterResultLimitDDLBrush()
            GuiID_SearchCenter.Destroy()
        }
        ; 2. 释放数据库资源，防止占用
        if (IsSet(global_ST) && IsObject(global_ST) && global_ST.HasProp("Free")) {
            try {
                global_ST.Free()
            } catch as err {
            }
            global_ST := 0
        }
    } catch as err {
    }
    GuiID_SearchCenter := 0
    SearchCenterInvalidateGuiControlRefs()
    
    ; 3. 启动倒计时功能
    StartActionCountdown(Content, Title)
}

; ===================== 圆环倒计时模块 =====================
; 启动倒计时
StartActionCountdown(Content, Title := "") {
    global LaunchDelaySeconds, IsCountdownActive, CountdownGui, CountdownTimer
    global CountdownStartTime, CountdownContent, GuiID_SearchCenter
    
    ; 如果倒计时已激活，再次按 F 或 Enter 则加速执行
    if (IsCountdownActive) {
        ExecuteCountdownAction()
        return
    }
    
    ; 保存内容
    CountdownContent := Content
    
    ; 创建倒计时 GUI
    CreateCountdownGui()
    
    ; 启动倒计时
    IsCountdownActive := true
    CountdownStartTime := A_TickCount
    CountdownTimer := SetTimer(UpdateCountdown, 30)  ; 每 30ms 刷新一次
}

; 创建倒计时 GUI
CreateCountdownGui() {
    global CountdownGui, CountdownGraphics, CountdownBitmap
    global LaunchDelaySeconds
    
    ; 如果 GUI 已存在，先销毁
    if (CountdownGui != 0) {
        try {
            CleanupCountdownGui()
        } catch as err {
        }
    }
    
    ; 初始化 GDI+
    InitGDI()
    
    ; 1. 创建透明分层窗口
    ; WS_EX_LAYERED (0x80000) + WS_EX_TRANSPARENT (0x20) + WS_EX_TOPMOST (0x8)
    CountdownGui := Gui("+AlwaysOnTop +Disabled -Caption +E0x80028", "ActionCountdown")
    
    ; 设置窗口大小
    WindowSize := 100
    
    ; 2. 计算位置（在当前鼠标所在的显示器居中）
    ; 获取鼠标位置
    CoordMode("Mouse", "Screen")
    MouseGetPos(&mX, &mY)
    
    ; 获取显示器信息
    TargetMonitor := 1
    MonitorCount := MonitorGetCount()
    loop MonitorCount {
        MonitorGet(A_Index, &mLeft, &mTop, &mRight, &mBottom)
        if (mX >= mLeft && mX <= mRight && mY >= mTop && mY <= mBottom) {
            TargetMonitor := A_Index
            break
        }
    }
    
    MonitorGet(TargetMonitor, &Left, &Top, &Right, &Bottom)
    CountdownX := Left + (Right - Left - WindowSize) / 2
    CountdownY := Top + (Bottom - Top - WindowSize) / 2
    
    ; 3. 显示窗口（指定精确位置和分层属性）
    CountdownGui.Show("x" . CountdownX . " y" . CountdownY . " w" . WindowSize . " h" . WindowSize . " NA")
}

; 更新倒计时显示
UpdateCountdown(*) {
    global LaunchDelaySeconds, IsCountdownActive, CountdownStartTime
    global CountdownGui, CountdownGraphics, CountdownBitmap
    global CountdownContent
    
    if (!IsCountdownActive || CountdownGui = 0) {
        return
    }
    
    ; 计算剩余时间
    Elapsed := (A_TickCount - CountdownStartTime) / 1000.0
    Remaining := LaunchDelaySeconds - Elapsed
    
    ; 如果倒计时结束，执行操作
    if (Remaining <= 0) {
        ExecuteCountdownAction()
        return
    }
    
    ; 绘制圆环
    DrawCountdownRing(Remaining)
}

; 绘制倒计时圆环
DrawCountdownRing(Remaining) {
    global CountdownGui, LaunchDelaySeconds
    
    if (CountdownGui = 0) {
        return
    }
    
    WindowSize := 100
    CenterX := WindowSize / 2
    CenterY := WindowSize / 2
    Radius := 35  ; 稍微增大圆环
    StrokeWidth := 5  ; 减细一些，更精致
    
    ; 创建内存 DC 和位图用于绘制
    hdc := DllCall("GetDC", "Ptr", CountdownGui.Hwnd, "Ptr")
    hdcMem := DllCall("CreateCompatibleDC", "Ptr", hdc, "Ptr")
    hbm := DllCall("CreateCompatibleBitmap", "Ptr", hdc, "Int", WindowSize, "Int", WindowSize, "Ptr")
    hbmOld := DllCall("SelectObject", "Ptr", hdcMem, "Ptr", hbm)
    
    ; 初始化 GDI+ Graphics
    pGraphics := 0
    DllCall("gdiplus.dll\GdipCreateFromHDC", "Ptr", hdcMem, "Ptr*", &pGraphics)
    
    if (!pGraphics) {
        DllCall("SelectObject", "Ptr", hdcMem, "Ptr", hbmOld)
        DllCall("DeleteObject", "Ptr", hbm)
        DllCall("DeleteDC", "Ptr", hdcMem)
        DllCall("ReleaseDC", "Ptr", CountdownGui.Hwnd, "Ptr", hdc)
        return
    }
    
    try {
        ; 设置高质量渲染
        DllCall("gdiplus.dll\GdipSetSmoothingMode", "Ptr", pGraphics, "Int", 2)  ; SmoothingModeAntiAlias
        DllCall("gdiplus.dll\GdipSetTextRenderingHint", "Ptr", pGraphics, "Int", 4)  ; TextRenderingHintAntiAlias
        
        ; 清除背景（完全透明）
        DllCall("gdiplus.dll\GdipGraphicsClear", "Ptr", pGraphics, "UInt", 0x00000000)
        
        ; 计算进度（从 1.0 递减至 0.0）
        Progress := Remaining / LaunchDelaySeconds
        StartAngle := 270.0  ; 从顶部开始
        SweepAngle := 360.0 * Progress
        
        ; 绘制背景圆环（深色底环，作为辅助参照）
        DllCall("gdiplus.dll\GdipCreatePen1", "UInt", 0x20007AFF, "Float", StrokeWidth, "Int", 0, "Ptr*", &pPenBg := 0)
        DllCall("gdiplus.dll\GdipDrawArc", "Ptr", pGraphics, "Ptr", pPenBg, "Float", CenterX - Radius, "Float", CenterY - Radius, "Float", Radius * 2, "Float", Radius * 2, "Float", 0, "Float", 360)
        DllCall("gdiplus.dll\GdipDeletePen", "Ptr", pPenBg)
        
        ; 绘制进度圆弧（鲜艳的蓝色）
        ; 采用 iOS 风格的蓝色 #007AFF
        DllCall("gdiplus.dll\GdipCreatePen1", "UInt", 0xFF007AFF, "Float", StrokeWidth, "Int", 0, "Ptr*", &pPenProgress := 0)
        DllCall("gdiplus.dll\GdipSetPenStartCap", "Ptr", pPenProgress, "Int", 2)  ; LineCapRound
        DllCall("gdiplus.dll\GdipSetPenEndCap", "Ptr", pPenProgress, "Int", 2)  ; LineCapRound
        DllCall("gdiplus.dll\GdipDrawArc", "Ptr", pGraphics, "Ptr", pPenProgress, "Float", CenterX - Radius, "Float", CenterY - Radius, "Float", Radius * 2, "Float", Radius * 2, "Float", StartAngle, "Float", SweepAngle)
        DllCall("gdiplus.dll\GdipDeletePen", "Ptr", pPenProgress)
        
        ; 绘制中心文本 "Esc取消"
        ; 第一行 Esc，第二行 取消，增加识别度
        Text := "Esc`n取消"
        DllCall("gdiplus.dll\GdipCreateFontFamilyFromName", "WStr", "Microsoft YaHei", "Ptr", 0, "Ptr*", &pFontFamily := 0)
        DllCall("gdiplus.dll\GdipCreateFont", "Ptr", pFontFamily, "Float", 11, "Int", 1, "Int", 0, "Ptr*", &pFont := 0) ; Bold
        
        DllCall("gdiplus.dll\GdipCreateStringFormat", "Int", 0, "UShort", 0, "Ptr*", &pStringFormat := 0)
        DllCall("gdiplus.dll\GdipSetStringFormatAlign", "Ptr", pStringFormat, "Int", 1) ; Center
        DllCall("gdiplus.dll\GdipSetStringFormatLineAlign", "Ptr", pStringFormat, "Int", 1) ; Middle
        
        DllCall("gdiplus.dll\GdipCreateSolidFill", "UInt", 0xFFFFFFFF, "Ptr*", &pBrush := 0)
        
        Rect := Buffer(16, 0)
        NumPut("Float", 0, Rect, 0)
        NumPut("Float", 0, Rect, 4)
        NumPut("Float", WindowSize, Rect, 8)
        NumPut("Float", WindowSize, Rect, 12)
        
        DllCall("gdiplus.dll\GdipDrawString", "Ptr", pGraphics, "WStr", Text, "Int", -1, "Ptr", pFont, "Ptr", Rect, "Ptr", pStringFormat, "Ptr", pBrush)
        
        ; 清理 GDI+ 资源
        DllCall("gdiplus.dll\GdipDeleteBrush", "Ptr", pBrush)
        DllCall("gdiplus.dll\GdipDeleteStringFormat", "Ptr", pStringFormat)
        DllCall("gdiplus.dll\GdipDeleteFont", "Ptr", pFont)
        DllCall("gdiplus.dll\GdipDeleteFontFamily", "Ptr", pFontFamily)
        DllCall("gdiplus.dll\GdipDeleteGraphics", "Ptr", pGraphics)
        
        ; 更新分层窗口
        ; 获取窗口位置
        WinGetPos(&WinX, &WinY, , , "ahk_id " . CountdownGui.Hwnd)
        
        ; BLENDFUNCTION 结构体（4字节）
        BlendFunc := Buffer(4, 0)
        NumPut("UChar", 1, BlendFunc, 0)  ; BlendOp: AC_SRC_OVER
        NumPut("UChar", 0, BlendFunc, 1)  ; BlendFlags
        NumPut("UChar", 255, BlendFunc, 2)  ; SourceConstantAlpha (0-255)
        NumPut("UChar", 1, BlendFunc, 3)  ; AlphaFormat: AC_SRC_ALPHA
        
        ; 目标位置（POINT 结构，8字节）
        DstPoint := Buffer(8, 0)
        NumPut("Int", WinX, DstPoint, 0)  ; xDst
        NumPut("Int", WinY, DstPoint, 4)  ; yDst
        
        ; 大小（SIZE 结构，8字节）
        Size := Buffer(8, 0)
        NumPut("Int", WindowSize, Size, 0)  ; cx
        NumPut("Int", WindowSize, Size, 4)  ; cy
        
        ; 源位置（POINT 结构，8字节）
        SrcPoint := Buffer(8, 0)
        NumPut("Int", 0, SrcPoint, 0)  ; xSrc
        NumPut("Int", 0, SrcPoint, 4)  ; ySrc
        
        ; 调用 UpdateLayeredWindow
        ; UpdateLayeredWindow(hwnd, hdcDst, pptDst, psize, hdcSrc, pptSrc, crKey, pblend, dwFlags)
        DllCall("UpdateLayeredWindow", "Ptr", CountdownGui.Hwnd, "Ptr", 0, "Ptr", DstPoint, "Ptr", Size, "Ptr", hdcMem, "Ptr", SrcPoint, "UInt", 0, "Ptr", BlendFunc, "UInt", 2)
    } catch as e {
        OutputDebug("绘制圆环失败: " . e.Message)
        ; 确保清理资源
        DllCall("gdiplus.dll\GdipDeleteGraphics", "Ptr", pGraphics)
    }
    
    ; 清理资源
    DllCall("SelectObject", "Ptr", hdcMem, "Ptr", hbmOld)
    DllCall("DeleteObject", "Ptr", hbm)
    DllCall("DeleteDC", "Ptr", hdcMem)
    DllCall("ReleaseDC", "Ptr", CountdownGui.Hwnd, "Ptr", hdc)
}

; 执行倒计时操作
ExecuteCountdownAction() {
    global IsCountdownActive, CountdownContent, CountdownTimer
    global global_ST
    
    ; 停止倒计时
    if (CountdownTimer != 0) {
        try {
            CountdownTimer.Delete()
        } catch as err {
        }
        CountdownTimer := 0
    }
    IsCountdownActive := false
    
    ; 清理 GUI
    CleanupCountdownGui()
    
    ; 执行粘贴操作
    try {
        ; 复制到剪贴板
        A_Clipboard := CountdownContent
        Sleep(150)  ; 等待剪贴板写入完成
        
        ; 查找并激活 Cursor 窗口
        if (WinExist("ahk_exe Cursor.exe")) {
            WinActivate("ahk_exe Cursor.exe")
            WinWaitActive("ahk_exe Cursor.exe", , 1)
            Sleep(150)  ; 【健壮性要求】防止粘贴指令发送过快
        } else {
            global CursorPath
            if (IsSet(CursorPath) && CursorPath != "" && FileExist(CursorPath)) {
                Run(CursorPath)
                WinWaitActive("ahk_exe Cursor.exe", , 5)
                Sleep(150)
            }
        }
        
        ; 发送粘贴命令
        Send("^v")
        TrayTip("已粘贴到 Cursor", "", "Iconi 1")
    } catch as e {
        TrayTip("粘贴失败: " . e.Message, "错误", "Iconx 2")
    }
    
    ; 清空内容
    CountdownContent := ""
}

; 取消倒计时
CancelCountdown() {
    global IsCountdownActive, CountdownTimer, CountdownContent
    
    ; 停止倒计时
    if (CountdownTimer != 0) {
        try {
            CountdownTimer.Delete()
        } catch as err {
        }
        CountdownTimer := 0
    }
    IsCountdownActive := false
    
    ; 清理 GUI
    CleanupCountdownGui()
    
    ; 清空内容
    CountdownContent := ""
    
    ; 显示提示
    ToolTip("已取消")
    SetTimer(() => ToolTip(), -2000)  ; 2秒后清除提示
}

; 清理倒计时 GUI
CleanupCountdownGui() {
    global CountdownGui, CountdownGraphics, CountdownBitmap
    
    ; 销毁 GUI
    if (CountdownGui != 0) {
        try {
            CountdownGui.Destroy()
        } catch as err {
        }
        CountdownGui := 0
    }
    
    ; 清理变量
    CountdownGraphics := 0
    CountdownBitmap := 0
}

; 初始化 GDI+
; 初始化 GDI+
InitGDI() {
    static GdiplusToken := 0
    if (GdiplusToken = 0) {
        ; 确保 gdiplus.dll 已加载
        if (!DllCall("GetModuleHandle", "Str", "gdiplus", "Ptr")) {
            DllCall("LoadLibrary", "Str", "gdiplus")
        }
        
        ; GdiplusStartupInput 结构体
        ; 32位: 4字节 (UInt GdiplusVersion) + 4字节 (Void* DebugEventCallback) + 4字节 (Bool SuppressBackgroundThread) + 4字节 (Bool SuppressExternalCodecs) = 16字节
        ; 64位: 4字节 (UInt GdiplusVersion) + 8字节 (Void* DebugEventCallback) + 4字节 (Bool SuppressBackgroundThread) + 4字节 (Bool SuppressExternalCodecs) = 20字节（对齐到24字节）
        Input := Buffer(A_PtrSize = 8 ? 24 : 16, 0)
        NumPut("UInt", 1, Input, 0)  ; GdiplusVersion = 1
        ; 其他字段默认为 0
        
        ; 调用 GdipStartup（与代码库中其他 GDI+ 函数保持一致，使用 Gdip* 前缀）
        ; GdipStartup(token, input, output)
        ; token: ULONG_PTR* (输出参数)
        ; input: GdiplusStartupInput* (输入结构)
        ; output: GdiplusStartupOutput* (输出结构，可以为 NULL)
        ; 返回值：Status (UInt)，0 表示成功
        ; 注意：参考第9474行的调用方式，使用 "gdiplus.dll\GdipStartup"
        try {
            Status := DllCall("gdiplus.dll\GdipStartup", "Ptr*", &GdiplusToken := 0, "Ptr", Input, "Ptr", 0, "Int")
            if (Status != 0) {
                OutputDebug("GDI+ 初始化失败，状态码: " . Status)
                GdiplusToken := 0
            }
        } catch as e {
            OutputDebug("GDI+ 初始化失败: " . e.Message)
            GdiplusToken := 0
        }
    }
}

; ===================== 搜索中心窗口 =====================
; 显示搜索中心窗口（无边框，带分类标签栏）
ShowSearchCenter() {
    if (SearchCenter_ShouldUseWebView()) {
        SCWV_Show()
        return
    }
    global GuiID_SearchCenter, UI_Colors, ThemeMode
    global SearchCenterActiveArea, SearchCenterCurrentCategory
    global SearchCenterSearchEdit, SearchCenterResultLV, SearchCenterCategoryButtons
    global VoiceSearchEnabledCategories, SearchCenterAreaIndicator
    global SearchCenterFilterButtons, SearchCenterFilterType, SearchCenterFilterButtonMap
    global SearchCenterCLIOutputEdit
    global SearchCenterCLIRunButton, SearchCenterCLIClearButton, SearchCenterCLIOpenButton
    global SearchCenterResultLimitDDL_Hwnd, SearchCenterResultLimitDDL_ListHwnd
    
    ; 如果窗口已存在，先销毁
    if (GuiID_SearchCenter != 0) {
        try {
            CleanupSearchCenterResultLimitDDLBrush()
            GuiID_SearchCenter.Destroy()
        } catch as err {
        }
        GuiID_SearchCenter := 0
        SearchCenterInvalidateGuiControlRefs()
    }
    
    ; 初始化状态
    SearchCenterActiveArea := "input"  ; 默认焦点在输入框
    SearchCenterCurrentCategory := 0
    SearchCenterCategoryButtons := []
    ; 初始化搜索引擎图标数组
    if (!IsSet(SearchCenterEngineIcons) || !IsObject(SearchCenterEngineIcons)) {
        SearchCenterEngineIcons := []
    }
    
    ; 初始化搜索引擎选择状态
    if (!IsSet(SearchCenterSelectedEngines) || !IsObject(SearchCenterSelectedEngines)) {
        SearchCenterSelectedEngines := []
    }
    if (!IsSet(SearchCenterSelectedEnginesByCategory) || !IsObject(SearchCenterSelectedEnginesByCategory)) {
        SearchCenterSelectedEnginesByCategory := Map()
        ; 【关键修复】参考CAPSLOCK+F的实现：从配置文件加载所有分类的选择状态
        try {
            global ConfigFile
            AllCategories := GetSearchCenterCategories()
            for Index, Category in AllCategories {
                CategoryKey := Category.Key
                CategoryEnginesStr := IniRead(ConfigFile, "Settings", "SearchCenterSelectedEngines_" . CategoryKey, "")
                if (CategoryEnginesStr != "") {
                    ; 解析格式：分类:引擎1,引擎2
                    if (InStr(CategoryEnginesStr, ":") > 0) {
                        EnginesStr := SubStr(CategoryEnginesStr, InStr(CategoryEnginesStr, ":") + 1)
                    } else {
                        EnginesStr := CategoryEnginesStr
                    }
                    if (EnginesStr != "") {
                        EnginesArray := StrSplit(EnginesStr, ",")
                        CurrentEngines := []
                        for Index2, Engine in EnginesArray {
                            Engine := Trim(Engine)
                            if (Engine != "") {
                                CurrentEngines.Push(Engine)
                            }
                        }
                        if (CurrentEngines.Length > 0) {
                            SearchCenterSelectedEnginesByCategory[CategoryKey] := CurrentEngines
                        }
                    }
                }
            }
        } catch as err {
            ; 忽略加载错误
        }
    }
    
    ; 窗口尺寸（增加高度以容纳过滤标签按钮）
    WindowWidth := 900
    WindowHeight := 650  ; 从600增加到650，为过滤标签按钮留出空间
    Padding := 20
    
    ; 创建窗口（使用原生标题栏）
    GuiID_SearchCenter := Gui("+AlwaysOnTop -DPIScale +Resize", "搜索中心")
    GuiID_SearchCenter.BackColor := UI_Colors.Background
    GuiID_SearchCenter.SetFont("s11 c" . UI_Colors.Text, "Segoe UI")
    
    ; ========== 顶部分类标签栏（CategoryBar）==========
    CategoryBarHeight := 50
    CategoryBarY := Padding  ; 使用原生标题栏，从Padding开始
    
    ; 获取分类列表（从语音搜索面板提取）
    AllCategories := GetSearchCenterCategories()
    
    if (AllCategories.Length = 0) {
        ; 如果没有分类，使用默认分类
        AllCategories := [{Key: "ai", Text: GetText("search_category_ai")}]
    }
    
    ; 创建分类标签按钮（横向排列）
    CategoryButtonHeight := 35
    CategoryButtonSpacing := 10
    CategoryStartX := Padding
    CategoryButtonY := CategoryBarY + (CategoryBarHeight - CategoryButtonHeight) / 2
    CurrentCategoryX := CategoryStartX  ; 当前X坐标
    
    for Index, Category in AllCategories {
        ; 计算按钮宽度（根据文本长度动态调整）
        CategoryText := Category.Text
        
        ; 【关键修复】显示已选中的搜索引擎数量
        CategoryKey := Category.Key
        SelectedCount := 0
        if (IsSet(SearchCenterSelectedEnginesByCategory) && IsObject(SearchCenterSelectedEnginesByCategory) && SearchCenterSelectedEnginesByCategory.Has(CategoryKey)) {
            SelectedCount := SearchCenterSelectedEnginesByCategory[CategoryKey].Length
        } else {
            ; 尝试从配置文件加载
            try {
                global ConfigFile
                CategoryEnginesStr := IniRead(ConfigFile, "Settings", "SearchCenterSelectedEngines_" . CategoryKey, "")
                if (CategoryEnginesStr != "") {
                    if (InStr(CategoryEnginesStr, ":") > 0) {
                        EnginesStr := SubStr(CategoryEnginesStr, InStr(CategoryEnginesStr, ":") + 1)
                    } else {
                        EnginesStr := CategoryEnginesStr
                    }
                    if (EnginesStr != "") {
                        EnginesArray := StrSplit(EnginesStr, ",")
                        SelectedCount := EnginesArray.Length
                    }
                }
            } catch as err {
            }
        }
        
        ; 如果有选中的搜索引擎，在标签文本后显示数量
        if (SelectedCount > 0) {
            CategoryText .= " (" . SelectedCount . ")"
        }
        
        TextWidth := StrLen(CategoryText) * 10 + 20  ; 估算宽度
        CategoryButtonWidth := Max(60, TextWidth)  ; 最小宽度60
        
        ; 根据是否选中设置背景色
        IsSelected := (Index - 1 = SearchCenterCurrentCategory)
        BgColor := IsSelected ? UI_Colors.BtnPrimary : UI_Colors.Sidebar
        TextColor := IsSelected ? "FFFFFF" : UI_Colors.Text
        
        CategoryBtn := GuiID_SearchCenter.Add("Text", "x" . CurrentCategoryX . " y" . CategoryButtonY . " w" . CategoryButtonWidth . " h" . CategoryButtonHeight . " Center 0x200 c" . TextColor . " Background" . BgColor . " vSearchCategoryBtn" . Index, CategoryText)
        CategoryBtn.SetFont("s10 Bold", "Segoe UI")
        CategoryBtn.OnEvent("Click", CreateSearchCategoryClickHandler(Index - 1))
        HoverBtnWithAnimation(CategoryBtn, BgColor, UI_Colors.BtnHover)
        SearchCenterCategoryButtons.Push(CategoryBtn)
        
        ; 更新下一个按钮的X坐标
        CurrentCategoryX += CategoryButtonWidth + CategoryButtonSpacing
    }
    
    ; ========== 搜索引擎图标行 ==========
    EngineIconRowY := CategoryBarY + CategoryBarHeight + 5
    EngineIconRowHeight := 70  ; 图标行高度（50图标 + 2间距 + 16名称 = 68，留2像素余量）
    
    ; ========== 中部输入区（放在图标行下方）==========
    InputAreaY := EngineIconRowY + EngineIconRowHeight + Padding
    InputAreaHeight := 70
    
    ; 根据主题模式设置输入框颜色（Material Design风格，完全移除边框和底边）
    if (ThemeMode = "dark") {
        InputBgColor := UI_Colors.InputBg  ; html.to.design 风格背景
        InputTextColor := UI_Colors.Text   ; html.to.design 风格文本
    } else {
        InputBgColor := UI_Colors.InputBg
        InputTextColor := UI_Colors.Text
    }
    
    ; ========== 结果数量限制下拉菜单（搜索框左侧）==========
    DropdownX := Padding
    DropdownY := InputAreaY + (InputAreaHeight - 50) / 2
    DropdownWidth := 120
    DropdownHeight := 50
    
    ; 创建来源过滤下拉菜单
    ; R7 表示显示 7 行，确保所有选项可见
    DropdownOptions := ["10", "20", "50", "100", "200"]
    DropdownDefaultIndex := GetSearchCenterLimitDropdownIndex(SearchCenterCurrentLimit)

    SearchCenterResultLimitDropdown := GuiID_SearchCenter.Add("DropDownList",
        "x" . DropdownX . " y" . DropdownY .
        " w" . DropdownWidth . " h" . DropdownHeight .
        " R6" .
        " BackgroundFFFFFF" .
        " c000000" .
        " Choose" . DropdownDefaultIndex .
        " vSearchCenterResultLimitDropdown",
        DropdownOptions)
    SearchCenterResultLimitDropdown.SetFont("s14", "Segoe UI")
    SearchCenterResultLimitDropdown.OnEvent("Change", OnSearchCenterResultLimitChange)
    try {
        SearchCenterResultLimitDDL_Hwnd := SearchCenterResultLimitDropdown.Hwnd
        ComboBoxInfoSize := (A_PtrSize = 8) ? 64 : 52
        ComboBoxInfo := Buffer(ComboBoxInfoSize, 0)
        NumPut("UInt", ComboBoxInfoSize, ComboBoxInfo, 0)
        if (DllCall("user32.dll\GetComboBoxInfo", "Ptr", SearchCenterResultLimitDDL_Hwnd, "Ptr", ComboBoxInfo, "Int")) {
            ListHwndOffset := 40 + A_PtrSize * 2
            SearchCenterResultLimitDDL_ListHwnd := NumGet(ComboBoxInfo, ListHwndOffset, "Ptr")
        }
        SetTimer(UpdateSearchCenterResultLimitDDLBrush, -100)
    } catch as err {
    }
    
    ; ========== 搜索输入框（下拉菜单右侧）==========
    SearchEditX := DropdownX + DropdownWidth + 10  ; 下拉菜单右侧，间距10
    SearchEditY := DropdownY
    SearchEditWidth := WindowWidth - Padding * 2 - DropdownWidth - 10  ; 总宽度减去下拉菜单宽度和间距
    SearchEditHeight := 50
    
    ; 【Material Design风格】完全移除边框容器，避免任何底边显示
    ; 使用 -Border 选项移除默认边框，避免黑边问题
    ; 使用 -VScroll -HScroll 禁用滚动条，-Border 移除默认边框
    ; 【关键修复】Edit 控件默认是单行的，不支持换行，回车键已在顶部热键中处理为触发搜索
    SearchCenterSearchEdit := GuiID_SearchCenter.Add("Edit", "x" . SearchEditX . " y" . SearchEditY . " w" . SearchEditWidth . " h" . SearchEditHeight . " Background" . InputBgColor . " c" . InputTextColor . " -VScroll -HScroll -Border vSearchCenterEdit", "")
    SearchCenterSearchEdit.SetFont("s16", "Segoe UI")
    
    ; 初始化 Everything 搜索限制值
    SearchCenterEverythingLimit := SearchCenterCurrentLimit
    
    ; 完全移除边框容器，不再使用
    SearchCenterInputContainer := 0
    
    ; 【Material Design风格】完全移除Edit控件的边框（包括底部黑边）
    ; 通过移除WS_EX_CLIENTEDGE和WS_BORDER样式来完全消除边框效果
    try {
        EditHwnd := SearchCenterSearchEdit.Hwnd
        if (EditHwnd) {
            ; GWL_EXSTYLE = -20, WS_EX_CLIENTEDGE = 0x00000200
            ; 获取当前扩展样式
            CurrentExStyle := DllCall("GetWindowLongPtr", "Ptr", EditHwnd, "Int", -20, "Ptr")
            ; 移除WS_EX_CLIENTEDGE（3D边框效果），保留其他样式
            NewExStyle := CurrentExStyle & ~0x00000200
            ; 应用新扩展样式
            DllCall("SetWindowLongPtr", "Ptr", EditHwnd, "Int", -20, "Ptr", NewExStyle, "Ptr")
            
            ; GWL_STYLE = -16, WS_BORDER = 0x00800000
            ; 获取当前窗口样式
            CurrentStyle := DllCall("GetWindowLongPtr", "Ptr", EditHwnd, "Int", -16, "Ptr")
            ; 移除WS_BORDER（边框样式），保留其他样式
            NewStyle := CurrentStyle & ~0x00800000
            ; 应用新窗口样式
            DllCall("SetWindowLongPtr", "Ptr", EditHwnd, "Int", -16, "Ptr", NewStyle, "Ptr")
            
            ; 强制重绘窗口以应用样式更改
            DllCall("InvalidateRect", "Ptr", EditHwnd, "Ptr", 0, "Int", 1)
            DllCall("UpdateWindow", "Ptr", EditHwnd)
            ; 延迟再次刷新，确保样式完全应用（使用命名函数避免箭头函数语法问题）
            SetTimer(RefreshSearchCenterEditBorder.Bind(EditHwnd), -100)
        }
    } catch as err {
        ; 如果API调用失败，至少确保基本功能正常
    }
    SearchCenterSearchEdit.OnEvent("Change", ExecuteSearchCenterSearch)
    ; 【关键修复】添加Focus事件处理：设置焦点区域为input，并切换到中文输入法
    SearchCenterSearchEdit.OnEvent("Focus", (*) => (
        SearchCenterActiveArea := "input",
        UpdateSearchCenterHighlight(),
        SwitchToChineseIMEForSearchCenter()
    ))
    ; 注意：AutoHotkey v2 的 Edit 控件不支持 "Enter" 事件，改用窗口级别的快捷键绑定
    ; ESC键关闭窗口（使用统一的关闭处理函数）
    GuiID_SearchCenter.OnEvent("Escape", SearchCenterCloseHandler)
    
    ; ========== 区域名称动画展示（输入框下方）==========
    AreaIndicatorY := SearchEditY + SearchEditHeight + 8
    AreaIndicatorHeight := 25
    ; 创建区域名称动画展示控件（显示当前区域名称：分类搜索/输入框/本地搜索）
    SearchCenterAreaIndicator := GuiID_SearchCenter.Add("Text", "x" . Padding . " y" . AreaIndicatorY . " w" . SearchEditWidth . " h" . AreaIndicatorHeight . " c" . UI_Colors.BtnPrimary . " BackgroundTrans vSearchCenterAreaIndicator", "")
    SearchCenterAreaIndicator.SetFont("s11 Bold", "Segoe UI")
    SearchCenterAreaIndicator.Visible := true
    
    ; ========== 操作提示文本（区域名称下方）==========
    HintTextY := AreaIndicatorY + AreaIndicatorHeight + 5
    HintTextHeight := 40
    ; 创建操作提示文本控件（显示详细的操作提示）
    SearchCenterHintText := GuiID_SearchCenter.Add("Text", "x" . Padding . " y" . HintTextY . " w" . SearchEditWidth . " h" . HintTextHeight . " c" . UI_Colors.TextDim . " BackgroundTrans vSearchCenterHintText", "")
    SearchCenterHintText.SetFont("s9", "Segoe UI")
    SearchCenterHintText.Visible := true
    
    ; ========== 过滤标签按钮区域（橙色标签）==========
    FilterBarHeight := 40
    PreviewHeight := 120
    PreviewGap := 12
    ButtonHeight := 34
    ButtonReservedHeight := SearchCenterIsCLICategory() ? (ButtonHeight + PreviewGap) : 0
    ; 过滤标签栏固定放在搜索结果框上方，而不是绝对贴底
    FilterBarY := HintTextY + HintTextHeight + 10
    FilterButtonHeight := 30
    FilterButtonSpacing := 8
    FilterStartX := Padding
    FilterButtonY := FilterBarY + (FilterBarHeight - FilterButtonHeight) / 2
    
    ; 初始化过滤标签按钮数组
    SearchCenterFilterButtons := []
    SearchCenterFilterButtonMap := Map()
    SearchCenterFilterType := ""  ; 默认显示全部
    
    ; 过滤标签配置：全部、文件、剪贴板、提示词、配置、快捷键、功能
    FilterConfigs := [
        Map("Type", "", "Text", "全部"),
        Map("Type", "File", "Text", "文件"),
        Map("Type", "clipboard", "Text", "剪贴板"),
        Map("Type", "template", "Text", "提示词"),
        Map("Type", "config", "Text", "配置"),
        Map("Type", "hotkey", "Text", "快捷键"),
        Map("Type", "function", "Text", "功能")
    ]
    
    CurrentFilterX := FilterStartX
    for Index, FilterConfig in FilterConfigs {
        FilterType := FilterConfig["Type"]
        FilterText := FilterConfig["Text"]
        
        ; 计算按钮宽度（根据文本长度动态调整）
        TextWidth := StrLen(FilterText) * 10 + 20  ; 估算宽度
        FilterButtonWidth := Max(50, TextWidth)  ; 最小宽度50
        
            ; 参考记录面板：统一标签激活与未激活配色
            IsSelected := (SearchCenterFilterType = FilterType)
            TagBg := UI_Colors.Sidebar
            TagBgActive := "e67e22"
            TagText := UI_Colors.TextDim
            TagTextActive := "ffffff"
            BgColor := IsSelected ? TagBgActive : TagBg
            TextColor := IsSelected ? TagTextActive : TagText

            ; 【关键修复】在按钮对象上存储 FilterType，方便后续获取
            FilterBtn := GuiID_SearchCenter.Add("Text", "x" . CurrentFilterX . " y" . FilterButtonY . " w" . FilterButtonWidth . " h" . FilterButtonHeight . " Center 0x200 +0x100 c" . TextColor . " Background" . BgColor . " vSearchCenterFilterBtn" . Index, FilterText)
            FilterBtn.SetFont("s10 Bold", "Segoe UI")
            FilterBtn.OnEvent("Click", CreateSearchCenterFilterClickHandler(FilterType))
            FilterBtn.Visible := true
            ; 【关键修复】在按钮上存储 FilterType 属性，方便后续获取
            FilterBtn.FilterType := FilterType
            HoverBtnWithAnimation(FilterBtn, BgColor, TagBgActive)
        SearchCenterFilterButtons.Push(FilterBtn)
        SearchCenterFilterButtonMap[FilterType] := FilterBtn
        
        ; 更新下一个按钮的X坐标
        CurrentFilterX += FilterButtonWidth + FilterButtonSpacing
    }
    
    ; ========== 底部结果区 ==========
    ResultAreaY := FilterBarY + FilterBarHeight + 8
    ResultAreaHeight := Max(120, WindowHeight - Padding - PreviewHeight - ButtonReservedHeight - PreviewGap - ResultAreaY)
    
    ; 结果 ListView
    ResultLVX := Padding
    ResultLVY := ResultAreaY
    ResultLVWidth := WindowWidth - Padding * 2
    ResultLVHeight := ResultAreaHeight
    
    SearchCenterResultLV := GuiID_SearchCenter.Add("ListView", "x" . ResultLVX . " y" . ResultLVY . " w" . ResultLVWidth . " h" . ResultLVHeight . " Background" . UI_Colors.InputBg . " c" . UI_Colors.Text . " -Multi +ReadOnly vSearchResultLV", ["", "标题", "路径", "类型", "时间"])
    SearchCenterResultLV.SetFont("s10", "Segoe UI")
    SearchCenterResultLV.OnEvent("DoubleClick", OnSearchCenterResultDoubleClick)
    SearchCenterResultLV.OnEvent("ItemSelect", OnSearchCenterResultItemSelect)
    ; 【关键修复】添加Focus事件处理：设置焦点区域为listview
    SearchCenterResultLV.OnEvent("Focus", (*) => (
        SearchCenterActiveArea := "listview",
        UpdateSearchCenterHighlight()
    ))
    
    ; 5 列：图标列固定宽度，其余按剩余宽度比例
    SearchCenterResultLV.ModifyCol(1, 36)
    restW := ResultLVWidth - 36
    SearchCenterResultLV.ModifyCol(2, restW * 0.4)
    SearchCenterResultLV.ModifyCol(3, restW * 0.2)
    SearchCenterResultLV.ModifyCol(4, restW * 0.15)
    SearchCenterResultLV.ModifyCol(5, restW * 0.25)
    
    ; ========== CLI 页面控件（仅在 cli 分类显示）==========
    SearchCenterCLIRunButton := GuiID_SearchCenter.Add("Button", "x0 y0 w100 h32", "发送到 AI")
    SearchCenterCLIRunButton.OnEvent("Click", ExecuteSearchCenterCLICommand)
    
    SearchCenterCLIClearButton := GuiID_SearchCenter.Add("Button", "x0 y0 w100 h32", "清空输入")
    SearchCenterCLIClearButton.OnEvent("Click", ClearSearchCenterCLIOutput)
    
    SearchCenterCLIOpenButton := GuiID_SearchCenter.Add("Button", "x0 y0 w140 h32", "打开所选终端")
    SearchCenterCLIOpenButton.OnEvent("Click", OpenSelectedCLIAgents)
    
    SearchCenterCLIOutputEdit := GuiID_SearchCenter.Add("Edit", "x0 y0 w100 h120 Background" . UI_Colors.InputBg . " c" . UI_Colors.Text . " +Multi -Wrap ReadOnly")
    SearchCenterCLIOutputEdit.SetFont("s12", "Segoe UI")
    SearchCenterCLIOutputEdit.OnEvent("Focus", (*) => (
        SearchCenterActiveArea := "listview",
        UpdateSearchCenterHighlight()
    ))
    
    UpdateSearchCenterCLILayout(WindowWidth, WindowHeight)
    
    
    ; 窗口关闭事件（ESC键关闭）
    GuiID_SearchCenter.OnEvent("Close", SearchCenterCloseHandler)
    
    ; 窗口大小改变事件（更新按钮位置）
    GuiID_SearchCenter.OnEvent("Size", OnSearchCenterSize)
    
    ; 显示窗口（居中显示）
    GuiID_SearchCenter.Show("w" . WindowWidth . " h" . WindowHeight . " Center")
    BringSearchCenterFilterButtonsToFront()
    
    ; 【关键修复】激活窗口并聚焦到输入框（参考CAPSLOCK+F的实现）
    WinActivate("ahk_id " . GuiID_SearchCenter.Hwnd)
    Sleep(100)
    try {
        if (SearchCenterIsCLICategory()) {
            FocusSearchCenterCLIInput()
        } else {
            SearchCenterSearchEdit.Focus()
            Sleep(100)
            ; 切换到中文输入法
            SwitchToChineseIMEForSearchCenter()
        }
    } catch as err {
        ; 忽略错误
    }
    try CapsLock_ScheduleNormalizeAfterChord()
    try SearchCenter_ScheduleIMEStabilize()
    
    ; 注意：Enter和ESC键热键已在文件顶部使用#HotIf IsSearchCenterActive()定义，无需在此注册
    
    ; 更新高亮显示
    UpdateSearchCenterCategoryMode()
    UpdateSearchCenterHighlight()
    
    ; 刷新搜索引擎图标显示
    RefreshSearchCenterEngineIcons()
    
    ; 【关键修复】确保标签按钮的初始状态正确显示（默认"全部"标签应为橙色）
    UpdateSearchCenterFilterButtons()
}

; 获取搜索中心分类列表（从语音搜索面板提取）
GetSearchCenterCategories() {
    global VoiceSearchEnabledCategories
    
    ; 所有可用的分类
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
        VoiceSearchEnabledCategories := ["ai", "cli", "academic", "baidu", "image", "audio", "video", "book", "price", "medical", "cloud"]
    }
    
    ; 过滤出启用的分类
    EnabledCategories := []
    for Index, Category in AllCategories {
        if (ArrayContainsValue(VoiceSearchEnabledCategories, Category.Key) > 0) {
            EnabledCategories.Push(Category)
        }
    }
    
    ; 如果没有启用的分类，返回默认分类
    if (EnabledCategories.Length = 0) {
        EnabledCategories.Push({Key: "ai", Text: GetText("search_category_ai")})
    }
    
    return EnabledCategories
}

GetSearchCenterCurrentCategoryKey() {
    global SearchCenterCurrentCategory
    Categories := GetSearchCenterCategories()
    if (Categories.Length = 0 || SearchCenterCurrentCategory < 0 || SearchCenterCurrentCategory >= Categories.Length) {
        return "ai"
    }
    return Categories[SearchCenterCurrentCategory + 1].Key
}

SearchCenterIsCLICategory() {
    return (GetSearchCenterCurrentCategoryKey() = "cli")
}

SetSearchCenterControlVisible(Ctrl, IsVisible) {
    if (!Ctrl || Ctrl = 0) {
        return
    }
    try {
        Ctrl.Visible := IsVisible
    } catch {
    }
}

SetSearchCenterEngineIconsVisible(IsVisible) {
    global SearchCenterEngineIcons
    if (!IsSet(SearchCenterEngineIcons) || !IsObject(SearchCenterEngineIcons)) {
        return
    }
    for _, IconObj in SearchCenterEngineIcons {
        if (!IsObject(IconObj)) {
            continue
        }
        try {
            if (IconObj.HasProp("Bg") && IconObj.Bg != 0) {
                IconObj.Bg.Visible := IsVisible
            }
            if (IconObj.HasProp("Icon") && IconObj.Icon != 0) {
                IconObj.Icon.Visible := IsVisible
            }
            if (IconObj.HasProp("NameLabel") && IconObj.NameLabel != 0) {
                IconObj.NameLabel.Visible := IsVisible
            }
            if (IconObj.HasProp("Check") && IconObj.Check != 0) {
                IconObj.Check.Visible := IsVisible
            }
        } catch {
        }
    }
}

GetSearchCenterCLIPrompt() {
    return ""
}

GetSearchCenterCLIWelcomeText() {
    return ""
}

EnsureSearchCenterCLISession() {
    global SearchCenterCLIOutputEdit
    if (!SearchCenterCLIOutputEdit || SearchCenterCLIOutputEdit = 0) {
        return
    }
    try {
        ; CLI 页使用普通多行输入框，无需初始化终端欢迎文本
    } catch {
    }
}

FocusSearchCenterCLIInput() {
    global SearchCenterSearchEdit
    if (!SearchCenterSearchEdit || SearchCenterSearchEdit = 0) {
        return
    }
    try {
        SearchCenterSearchEdit.Focus()
        ControlSend("{End}", , SearchCenterSearchEdit)
    } catch {
    }
}

GetSearchCenterCurrentCLICommand() {
    global SearchCenterSearchEdit
    if (!SearchCenterSearchEdit || SearchCenterSearchEdit = 0) {
        return ""
    }
    return Trim(SearchCenterSearchEdit.Value, " `t`r`n")
}

UpdateSearchCenterCLILayout(WindowWidth := 0, WindowHeight := 0, KeepFilterTop := true) {
    global GuiID_SearchCenter, SearchCenterCLIOutputEdit, SearchCenterResultLV, SearchCenterFilterButtons
    global SearchCenterCLIRunButton, SearchCenterCLIClearButton, SearchCenterCLIOpenButton
    global SearchCenterHintText
    
    if (!GuiID_SearchCenter || GuiID_SearchCenter = 0) {
        return
    }
    if (WindowWidth <= 0 || WindowHeight <= 0) {
        try {
            GuiID_SearchCenter.GetClientPos(, , &WindowWidth, &WindowHeight)
        } catch {
            WindowWidth := 900
            WindowHeight := 650
        }
    }
    
    Padding := 20
    ContentTop := 325
    if (SearchCenterHintText != 0) {
        try {
            ControlGetPos(&HintX, &HintY, &HintW, &HintH, SearchCenterHintText)
            ContentTop := HintY + HintH + 12
        } catch {
            ContentTop := 325
        }
    }
    IsCLI := SearchCenterIsCLICategory()
    ContentWidth := WindowWidth - Padding * 2
    ButtonWidth := 120
    ButtonHeight := 34
    ButtonGap := 12
    FilterBarHeight := 40
    OutputHeight := 120
    PreviewGap := 12
    if (IsCLI) {
        ButtonY := WindowHeight - Padding - ButtonHeight
        OutputY := ButtonY - OutputHeight - PreviewGap
    } else {
        ButtonY := WindowHeight - Padding - ButtonHeight
        OutputY := WindowHeight - Padding - OutputHeight
    }
    ; 过滤标签栏始终在列表上方，必须预留 FilterBarHeight；否则 ListView 上移会遮挡「全部/文件/…」标签（且 ListView 后创建会盖住 z-order）
    FilterBarY := ContentTop
    ResultY := FilterBarY + FilterBarHeight + 8
    AvailableSpace := OutputY - ResultY - PreviewGap
    if (AvailableSpace < 0) {
        AvailableSpace := 0
    }
    ; 不可用 Max(120, 可用高度)：当可用不足 120 时强行 120 会侵入预览区
    ResultHeight := AvailableSpace
    
    try SearchCenterCLIOutputEdit.Move(Padding, OutputY, ContentWidth, OutputHeight)
    try SearchCenterResultLV.Move(Padding, ResultY, ContentWidth, ResultHeight)
    MoveSearchCenterFilterButtons(FilterBarY, Padding, KeepFilterTop)
    BringSearchCenterFilterButtonsToFront()
    if (IsCLI) {
        try SearchCenterCLIRunButton.Move(Padding, ButtonY, ButtonWidth, ButtonHeight)
        try SearchCenterCLIClearButton.Move(Padding + ButtonWidth + ButtonGap, ButtonY, ButtonWidth, ButtonHeight)
        try SearchCenterCLIOpenButton.Move(Padding + (ButtonWidth + ButtonGap) * 2, ButtonY, 170, ButtonHeight)
    }
}

BringSearchCenterFilterButtonsToFront() {
    global SearchCenterFilterButtons

    if (!IsSet(SearchCenterFilterButtons) || !IsObject(SearchCenterFilterButtons)) {
        return
    }

    for _, FilterBtn in SearchCenterFilterButtons {
        if (!FilterBtn || FilterBtn = 0) {
            continue
        }
        try {
            DllCall("SetWindowPos"
                , "ptr", FilterBtn.Hwnd
                , "ptr", 0
                , "int", 0
                , "int", 0
                , "int", 0
                , "int", 0
                , "uint", 0x0013)
            FilterBtn.Visible := true
            FilterBtn.Redraw()
        } catch {
        }
    }
}

MoveSearchCenterFilterButtons(FilterBarY, Padding := 20, KeepTop := true) {
    global SearchCenterFilterButtons

    if (!IsSet(SearchCenterFilterButtons) || !IsObject(SearchCenterFilterButtons)) {
        return
    }

    FilterButtonHeight := 30
    FilterButtonSpacing := 8
    FilterButtonY := FilterBarY + 5
    CurrentFilterX := Padding

    for _, FilterBtn in SearchCenterFilterButtons {
        if (!FilterBtn || FilterBtn = 0) {
            continue
        }
        try {
            FilterBtn.Visible := true
            FilterText := FilterBtn.Text
            FilterButtonWidth := Max(50, StrLen(FilterText) * 10 + 20)
            FilterBtn.Move(CurrentFilterX, FilterButtonY, FilterButtonWidth, FilterButtonHeight)
            CurrentFilterX += FilterButtonWidth + FilterButtonSpacing
        } catch {
        }
    }

    if (KeepTop) {
        BringSearchCenterFilterButtonsToFront()
    }
}

GetSearchCenterFilterDropdownLabel(FilterType := "") {
    switch FilterType {
        case "File":
            return "文件"
        case "clipboard":
            return "剪贴板"
        case "template":
            return "模板"
        case "config":
            return "配置"
        case "hotkey":
            return "快捷键"
        case "function":
            return "功能"
        default:
            return "全部"
    }
}

GetSearchCenterFilterDropdownIndex(FilterType := "") {
    switch FilterType {
        case "File":
            return 2
        case "clipboard":
            return 3
        case "template":
            return 4
        case "config":
            return 5
        case "hotkey":
            return 6
        case "function":
            return 7
        default:
            return 1
    }
}

GetSearchCenterFilterTypeFromDropdownLabel(FilterLabel := "") {
    switch Trim(FilterLabel) {
        case "文件":
            return "File"
        case "剪贴板":
            return "clipboard"
        case "模板":
            return "template"
        case "配置":
            return "config"
        case "快捷键":
            return "hotkey"
        case "功能":
            return "function"
        default:
            return ""
    }
}

GetSearchCenterFilterTypeFromDropdownIndex(FilterIndex := 1) {
    switch Integer(FilterIndex) {
        case 2:
            return "File"
        case 3:
            return "clipboard"
        case 4:
            return "template"
        case 5:
            return "config"
        case 6:
            return "hotkey"
        case 7:
            return "function"
        default:
            return ""
    }
}

GetSearchCenterDataTypesForFilter(FilterType := "") {
    switch FilterType {
        case "File":
            return ["file"]
        case "clipboard":
            return ["clipboard"]
        case "template":
            return ["template"]
        case "config":
            return ["config"]
        case "hotkey":
            return ["hotkey"]
        case "function":
            return ["function"]
        default:
            return []
    }
}

GetSearchCenterLimitFromDropdownText(LimitText := "") {
    Text := Trim(LimitText)
    Value := Integer(Text)
    if (Value <= 0) {
        return 50
    }
    return Value
}

GetSearchCenterLimitDropdownIndex(LimitValue := 50) {
    Value := Integer(LimitValue)
    switch Value {
        case 10:
            return 1
        case 20:
            return 2
        case 50:
            return 3
        case 100:
            return 4
        case 200:
            return 5
        default:
            return 3
    }
}

UpdateSearchCenterFilterDropdown() {
    global SearchCenterResultLimitDropdown, SearchCenterCurrentLimit

    if (!IsSet(SearchCenterResultLimitDropdown) || !SearchCenterResultLimitDropdown) {
        return
    }

    try SearchCenterResultLimitDropdown.Choose(GetSearchCenterLimitDropdownIndex(SearchCenterCurrentLimit))
}

SyncSearchCenterFilterTypeFromDropdown() {
    global SearchCenterFilterType
    return SearchCenterFilterType
}

UpdateSearchCenterCategoryMode() {
    global SearchCenterResultLimitDropdown, SearchCenterSearchEdit, SearchCenterAreaIndicator
    global SearchCenterHintText, SearchCenterResultLV, SearchCenterFilterButtons, SearchCenterActiveArea
    global SearchCenterCLIOutputEdit
    global SearchCenterCLIRunButton, SearchCenterCLIClearButton, SearchCenterCLIOpenButton

    IsCLI := SearchCenterIsCLICategory()
    
    SetSearchCenterControlVisible(SearchCenterResultLimitDropdown, true)
    SetSearchCenterControlVisible(SearchCenterSearchEdit, true)
    SetSearchCenterControlVisible(SearchCenterResultLV, true)
    SetSearchCenterControlVisible(SearchCenterAreaIndicator, true)
    SetSearchCenterControlVisible(SearchCenterHintText, true)
    for _, FilterBtn in SearchCenterFilterButtons {
        ; CLI 页同样需要本地结果分类筛选，与 AI 页一致显示过滤标签
        SetSearchCenterControlVisible(FilterBtn, true)
    }
    SetSearchCenterEngineIconsVisible(true)
    
    SetSearchCenterControlVisible(SearchCenterCLIOutputEdit, true)
    SetSearchCenterControlVisible(SearchCenterCLIRunButton, IsCLI)
    SetSearchCenterControlVisible(SearchCenterCLIClearButton, IsCLI)
    SetSearchCenterControlVisible(SearchCenterCLIOpenButton, IsCLI)
    
    if (IsCLI && SearchCenterActiveArea != "category" && SearchCenterActiveArea != "input" && SearchCenterActiveArea != "listview") {
        SearchCenterActiveArea := "input"
    }
    if (IsCLI) {
        UpdateSearchCenterCLIPreview()
        FocusSearchCenterCLIInput()
    }
    UpdateSearchCenterFilterDropdown()
    BringSearchCenterFilterButtonsToFront()
}

GetSearchCenterResultItemByRow(Row) {
    global SearchCenterVisibleResults, SearchCenterSearchResults

    if (IsSet(SearchCenterVisibleResults) && IsObject(SearchCenterVisibleResults) && Row > 0 && Row <= SearchCenterVisibleResults.Length) {
        return SearchCenterVisibleResults[Row]
    }
    if (Row > 0 && Row <= SearchCenterSearchResults.Length) {
        return SearchCenterSearchResults[Row]
    }
    return 0
}

BuildSearchCenterPreviewText(Item) {
    if (!IsObject(Item)) {
        return "当前未选中本地结果。`r`n`r`n在上方输入内容可实时过滤数据，选中列表项后会在这里显示详情预览。"
    }

    Title := Item.HasProp("Title") ? Item.Title : ""
    Source := Item.HasProp("Source") ? Item.Source : ""
    Content := Item.HasProp("Content") ? Item.Content : Title
    DataType := ""
    if (Item.HasProp("DataType") && Item.DataType != "") {
        DataType := Item.DataType
    } else if (Item.HasProp("OriginalDataType") && Item.OriginalDataType != "") {
        DataType := Item.OriginalDataType
    }
    TimeText := Item.HasProp("Time") ? Item.Time : ""

    PreviewText := "标题： " . Title
    if (Source != "") {
        PreviewText .= "`r`n来源： " . Source
    }
    if (DataType != "") {
        PreviewText .= "`r`n类型： " . DataType
    }
    if (TimeText != "") {
        PreviewText .= "`r`n时间： " . TimeText
    }
    PreviewText .= "`r`n`r`n内容预览：`r`n"
    PreviewText .= Content
    return PreviewText
}

UpdateSearchCenterCLIPreview(Row := 0) {
    global SearchCenterCLIOutputEdit, SearchCenterResultLV

    if (!SearchCenterCLIOutputEdit || SearchCenterCLIOutputEdit = 0) {
        return
    }

    if (Row <= 0 && SearchCenterResultLV && SearchCenterResultLV != 0) {
        try Row := SearchCenterResultLV.GetNext()
    }

    Item := GetSearchCenterResultItemByRow(Row)
    PreviewText := BuildSearchCenterPreviewText(Item)
    try SearchCenterCLIOutputEdit.Value := PreviewText
}

OnSearchCenterResultItemSelect(LV, Item, Selected) {
    if (Selected) {
        UpdateSearchCenterCLIPreview(Item)
    }
}

AppendSearchCenterCLIOutput(Text, AddBlankLine := true) {
    global SearchCenterCLIOutputEdit
    if (!SearchCenterCLIOutputEdit || SearchCenterCLIOutputEdit = 0) {
        return
    }
    ExistingText := ""
    try ExistingText := SearchCenterCLIOutputEdit.Value
    if (ExistingText != "") {
        ExistingText .= "`r`n"
    }
    ExistingText .= Text
    if (AddBlankLine) {
        ExistingText .= "`r`n"
    }
    try {
        SearchCenterCLIOutputEdit.Value := ExistingText
    } catch {
    }
}

RunEmbeddedPowerShellCommand(CommandText) {
    PowerShellPath := A_WinDir . "\System32\WindowsPowerShell\v1.0\powershell.exe"
    if (!FileExist(PowerShellPath)) {
        throw Error("找不到 Windows PowerShell")
    }
    Shell := ComObject("WScript.Shell")
    ExecObj := Shell.Exec('"' . PowerShellPath . '" -NoLogo -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command -')
    ExecObj.StdIn.WriteLine(CommandText)
    ExecObj.StdIn.Close()
    while (ExecObj.Status = 0) {
        Sleep(50)
    }
    StdOut := ExecObj.StdOut.ReadAll()
    StdErr := ExecObj.StdErr.ReadAll()
    ResultText := StdOut
    if (StdErr != "") {
        if (ResultText != "") {
            ResultText .= "`r`n"
        }
        ResultText .= StdErr
    }
    return Trim(ResultText, "`r`n")
}

GetGeminiAPIKey() {
    Key := ""
    try Key := Trim(EnvGet("GEMINI_API_KEY"))
    if (Key != "") {
        return Key
    }

    Key := ""
    try Key := Trim(EnvGet("GOOGLE_API_KEY"))
    if (Key != "") {
        return Key
    }

    try {
        global ConfigFile
        if (IsSet(ConfigFile) && ConfigFile != "" && FileExist(ConfigFile)) {
            Key := Trim(IniRead(ConfigFile, "API", "GeminiApiKey", ""))
            if (Key != "") {
                return Key
            }
        }
    } catch {
    }

    return ""
}

ExtractGeminiResponseText(ResponseObj) {
    try {
        if (ResponseObj is Map && ResponseObj.Has("candidates")) {
            Candidates := ResponseObj["candidates"]
            if (Candidates is Array && Candidates.Length > 0) {
                Candidate := Candidates[1]
                if (Candidate is Map && Candidate.Has("content")) {
                    Content := Candidate["content"]
                    if (Content is Map && Content.Has("parts")) {
                        Parts := Content["parts"]
                        if (Parts is Array) {
                            TextParts := []
                            for _, Part in Parts {
                                if (Part is Map && Part.Has("text")) {
                                    TextParts.Push(String(Part["text"]))
                                }
                            }
                            if (TextParts.Length > 0) {
                                Combined := ""
                                for Index, TextPart in TextParts {
                                    if (Index > 1) {
                                        Combined .= "`r`n"
                                    }
                                    Combined .= TextPart
                                }
                                return Combined
                            }
                        }
                    }
                }
            }
        }
    } catch {
    }
    return ""
}

SaveHeadlessAIResponseToDB(ResponseText, Engine, PromptText := "", ModelName := "") {
    global ClipboardDB

    if (ResponseText = "") {
        return false
    }
    if (!ClipboardDB || ClipboardDB = 0) {
        InitClipboardDB()
    }
    if (!ClipboardDB || ClipboardDB = 0) {
        return false
    }

    Meta := Map(
        "mode", "headless_api",
        "engine", Engine,
        "model", ModelName,
        "prompt", PromptText
    )
    MetaJson := StrReplace(Jxon_Dump(Meta), "'", "''")
    EscapedResponse := StrReplace(ResponseText, "'", "''")
    EscapedEngine := StrReplace(Engine, "'", "''")
    EscapedModel := StrReplace(ModelName, "'", "''")

    CharCount := StrLen(ResponseText)
    CleanedText := Trim(RegExReplace(ResponseText, "\s+", " "))
    WordCount := (CleanedText = "") ? 0 : StrSplit(CleanedText, A_Space).Length
    SQL := "INSERT INTO ClipboardHistory " .
           "(Content, DataType, SourceApp, SourceTitle, SourcePath, CharCount, WordCount, MetaData, Timestamp) VALUES (" .
           "'" . EscapedResponse . "', " .
           "'Text', " .
           "'GeminiAPI', " .
           "'Gemini Headless Response', " .
           "'" . EscapedEngine . ":" . EscapedModel . "', " .
           CharCount . ", " . WordCount . ", " .
           "'" . MetaJson . "', " .
           "datetime('now', 'localtime'))"
    try {
        return ClipboardDB.Exec(SQL)
    } catch {
        return false
    }
}

TryGeminiHeadlessRequest(PromptText, &ResponseText := "", &ErrorText := "") {
    ApiKey := GetGeminiAPIKey()
    if (ApiKey = "") {
        ErrorText := "未找到 GEMINI_API_KEY 或 GOOGLE_API_KEY"
        return false
    }

    ModelName := "gemini-2.5-flash"
    Url := "https://generativelanguage.googleapis.com/v1beta/models/" . ModelName . ":generateContent"
    RequestBody := Map(
        "contents", [
            Map("role", "user", "parts", [Map("text", PromptText)])
        ]
    )
    BodyText := Jxon_Dump(RequestBody)

    try {
        Http := ComObject("WinHttp.WinHttpRequest.5.1")
        Http.Open("POST", Url, false)
        Http.SetTimeouts(5000, 5000, 15000, 30000)
        Http.SetRequestHeader("x-goog-api-key", ApiKey)
        Http.SetRequestHeader("Content-Type", "application/json; charset=utf-8")
        Http.Send(BodyText)

        Status := Http.Status
        RawResponse := Http.ResponseText
        if (Status < 200 || Status >= 300) {
            ErrorText := "Gemini API HTTP " . Status . ": " . RawResponse
            return false
        }

        Parsed := Jxon_Load(RawResponse)
        ResponseText := ExtractGeminiResponseText(Parsed)
        if (ResponseText = "") {
            ErrorText := "Gemini API 返回为空或无法解析"
            return false
        }

        SaveHeadlessAIResponseToDB(ResponseText, "gemini_cli", PromptText, ModelName)
        return true
    } catch as err {
        ErrorText := err.Message
        return false
    }
}

TryGeminiHeadlessDispatch(PromptText, AppendToPanel := true) {
    ResponseText := ""
    ErrorText := ""
    if (!TryGeminiHeadlessRequest(PromptText, &ResponseText, &ErrorText)) {
        return false
    }

    if (AppendToPanel) {
        try {
            AppendSearchCenterCLIOutput("Gemini > " . PromptText, true)
            AppendSearchCenterCLIOutput(ResponseText, true)
        } catch {
        }
    }

    TrayTip("Gemini 已通过 Headless API 返回结果", "提示", "Iconi 1")
    return true
}

ExecuteSearchCenterCLICommand(*) {
    PromptText := GetSearchCenterCurrentCLICommand()
    if (PromptText = "") {
        TrayTip("请输入要发送给 AI 的内容", "提示", "Icon! 2")
        return
    }
    
    LaunchSelectedCLIAgents(PromptText)
    FocusSearchCenterCLIInput()
}

ClearSearchCenterCLIOutput(*) {
    global SearchCenterCLIOutputEdit, SearchCenterSearchEdit
    if (SearchCenterCLIOutputEdit && SearchCenterCLIOutputEdit != 0) {
        try SearchCenterCLIOutputEdit.Value := ""
    }
    if (SearchCenterSearchEdit && SearchCenterSearchEdit != 0) {
        try SearchCenterSearchEdit.Value := ""
    }
    UpdateSearchCenterCLIPreview(0)
    FocusSearchCenterCLIInput()
}

; 创建分类点击处理器
CreateSearchCategoryClickHandler(CategoryIndex) {
    return SearchCategoryClickHandler.Bind(CategoryIndex)
}

; 创建搜索中心过滤标签点击处理器
CreateSearchCenterFilterClickHandler(FilterType) {
    return SearchCenterFilterClickHandler.Bind(FilterType)
}

; ===================== 更新搜索中心过滤标签按钮样式 =====================
; 【参考 ClipboardHistoryPanel 的实现】
UpdateSearchCenterFilterButtons() {
    global SearchCenterFilterButtons, SearchCenterFilterButtonMap, SearchCenterFilterType, UI_Colors, GuiID_SearchCenter
    
    if (!IsSet(SearchCenterFilterButtons) || !IsObject(SearchCenterFilterButtons)) {
        return
    }
    
    OutputDebug("AHK_DEBUG: UpdateSearchCenterFilterButtons - SearchCenterFilterType: " . SearchCenterFilterType)
    
    ; 优先使用映射表（与记录面板同思路：类型驱动样式）
    if (IsSet(SearchCenterFilterButtonMap) && IsObject(SearchCenterFilterButtonMap) && SearchCenterFilterButtonMap.Count > 0) {
        for BtnType, FilterBtn in SearchCenterFilterButtonMap {
            try {
                IsSelected := (SearchCenterFilterType = BtnType)
                TagBg := UI_Colors.Sidebar
                TagBgActive := "e67e22"
                TagText := UI_Colors.TextDim
                TagTextActive := "ffffff"
                BgColor := IsSelected ? TagBgActive : TagBg
                TextColor := IsSelected ? TagTextActive : TagText

                FilterBtn.Opt("+Background" . BgColor)
                FilterBtn.SetFont("s10 c" . TextColor . " Bold", "Segoe UI")
                try {
                    hoverFunc := HoverBtnWithAnimation
                    if (IsSet(hoverFunc)) {
                        HoverBtnWithAnimation(FilterBtn, BgColor, TagBgActive)
                    }
                } catch {
                }
                try FilterBtn.Redraw()
            } catch as err {
                OutputDebug("AHK_DEBUG: UpdateSearchCenterFilterButtons(map) - Error: " . err.Message)
            }
        }
        return
    }

    ; 回退：遍历数组
    for Index, FilterBtn in SearchCenterFilterButtons {
        try {
            ; 从按钮对象上获取 FilterType
            BtnType := ""
            if (FilterBtn.HasProp("FilterType")) {
                BtnType := FilterBtn.FilterType
            } else {
                ; 向后兼容：通过索引推断（如果 FilterType 属性不存在）
                if (Index = 1) {
                    BtnType := ""  ; 全部
                } else if (Index = 2) {
                    BtnType := "File"
                } else if (Index = 3) {
                    BtnType := "clipboard"
                } else if (Index = 4) {
                    BtnType := "template"
                } else if (Index = 5) {
                    BtnType := "config"
                } else if (Index = 6) {
                    BtnType := "hotkey"
                } else if (Index = 7) {
                    BtnType := "function"
                }
            }
            
            IsSelected := (SearchCenterFilterType = BtnType)
            OutputDebug("AHK_DEBUG: UpdateSearchCenterFilterButtons - Index: " . Index . ", BtnType: " . BtnType . ", IsSelected: " . IsSelected)
            
            TagBg := UI_Colors.Sidebar
            TagBgActive := "e67e22"
            TagText := UI_Colors.TextDim
            TagTextActive := "ffffff"
            BgColor := IsSelected ? TagBgActive : TagBg
            TextColor := IsSelected ? TagTextActive : TagText

            ; 更新按钮样式（参考 ClipboardHistoryPanel 的实现方式）
            FilterBtn.Opt("+Background" . BgColor)
            FilterBtn.SetFont("s10 c" . TextColor . " Bold", "Segoe UI")
            try {
                hoverFunc := HoverBtnWithAnimation
                if (IsSet(hoverFunc)) {
                    HoverBtnWithAnimation(FilterBtn, BgColor, TagBgActive)
                }
            } catch {
            }
        } catch as err {
            OutputDebug("AHK_DEBUG: UpdateSearchCenterFilterButtons - Error: " . err.Message)
        }
    }
}

; 搜索中心过滤标签点击处理函数
SearchCenterFilterClickHandler(FilterType, *) {
    global SearchCenterFilterType, SearchCenterSearchResults, SearchCenterResultLV, UI_Colors, GuiID_SearchCenter
    global SearchCenterSearchEdit, SearchCenterEverythingLimit, SearchCenterCurrentLimit

    ; 兼容“全部”标签空字符串绑定场景：若首参是控件对象，则从控件属性读取 FilterType
    if (IsObject(FilterType)) {
        try {
            if (FilterType.HasProp("FilterType")) {
                FilterType := FilterType.FilterType
            } else {
                FilterType := ""
            }
        } catch {
            FilterType := ""
        }
    }
    if (!IsSet(FilterType))
        FilterType := ""

    OutputDebug("AHK_DEBUG: SearchCenterFilterClickHandler - FilterType: " . FilterType . ", Old SearchCenterFilterType: " . SearchCenterFilterType)
    
    ; 如果点击的是已选中的标签，则取消选中（显示全部）
    if (SearchCenterFilterType = FilterType) {
        SearchCenterFilterType := ""
    } else {
        ; 更新过滤类型
        SearchCenterFilterType := FilterType
    }
    
    OutputDebug("AHK_DEBUG: SearchCenterFilterClickHandler - New SearchCenterFilterType: " . SearchCenterFilterType)
    
    ; 【关键修复】使用统一的更新函数更新按钮样式
    UpdateSearchCenterFilterButtons()
    BringSearchCenterFilterButtonsToFront()
    try {
        if (GuiID_SearchCenter && IsObject(GuiID_SearchCenter) && GuiID_SearchCenter.HasProp("Hwnd")) {
            WinRedraw(GuiID_SearchCenter.Hwnd)
        }
    } catch {
    }
    
    ; 刷新搜索结果列表（根据过滤类型过滤）
    RefreshSearchCenterResults()
}

; 分类点击处理函数
SearchCategoryClickHandler(CategoryIndex, *) {
    ; 切换分类并聚焦到分类区域
    global SearchCenterActiveArea, SearchCenterCurrentCategory
    SearchCenterCurrentCategory := CategoryIndex
    SwitchSearchCenterCategory(CategoryIndex, true)
    SearchCenterActiveArea := "category"
    UpdateSearchCenterHighlight()
    ; 【关键修复】立即刷新标签样式，确保点击后立即变橙色
    try {
        if (GuiID_SearchCenter && IsObject(GuiID_SearchCenter) && GuiID_SearchCenter.HasProp("Hwnd")) {
            WinRedraw(GuiID_SearchCenter.Hwnd)
        }
    } catch as err {
        ; 忽略刷新错误
    }
}

; 切换搜索中心分类
SwitchSearchCenterCategory(Direction, DirectIndex := false) {
    global SearchCenterCurrentCategory, SearchCenterCategoryButtons, UI_Colors, SearchCenterActiveArea
    global SearchCenterSelectedEngines, SearchCenterSelectedEnginesByCategory
    
    ; 获取分类列表
    Categories := GetSearchCenterCategories()
    
    if (Categories.Length = 0) {
        return
    }
    
    ; 【关键修复】保存当前分类的搜索引擎选择状态（切换分类前保存）
    if (Categories.Length > 0 && SearchCenterCurrentCategory >= 0 && SearchCenterCurrentCategory < Categories.Length) {
        OldCategory := Categories[SearchCenterCurrentCategory + 1]
        if (IsSet(SearchCenterSelectedEngines) && IsObject(SearchCenterSelectedEngines)) {
            CurrentEngines := []
            for Index, Engine in SearchCenterSelectedEngines {
                CurrentEngines.Push(Engine)
            }
            if (!IsSet(SearchCenterSelectedEnginesByCategory) || !IsObject(SearchCenterSelectedEnginesByCategory)) {
                SearchCenterSelectedEnginesByCategory := Map()
            }
            SearchCenterSelectedEnginesByCategory[OldCategory.Key] := CurrentEngines
            
            ; 【关键修复】参考CAPSLOCK+F的实现：保存到配置文件
            try {
                global ConfigFile
                EnginesStr := ""
                for Index, Eng in SearchCenterSelectedEngines {
                    if (Index > 1) {
                        EnginesStr .= ","
                    }
                    EnginesStr .= Eng
                }
                ; 保存格式：分类:引擎1,引擎2
                CategoryEnginesStr := OldCategory.Key . ":" . EnginesStr
                IniWrite(CategoryEnginesStr, ConfigFile, "Settings", "SearchCenterSelectedEngines_" . OldCategory.Key)
            } catch as err {
                ; 忽略保存错误
            }
        }
    }
    
    if (DirectIndex) {
        ; 直接设置索引
        NewIndex := Direction
    } else {
        ; 根据方向切换
        NewIndex := SearchCenterCurrentCategory + Direction
        if (NewIndex < 0)
            NewIndex := Categories.Length - 1
        else if (NewIndex >= Categories.Length)
            NewIndex := 0
    }
    
    SearchCenterCurrentCategory := NewIndex
    
    ; 更新按钮样式
    UpdateSearchCenterHighlight()
    UpdateSearchCenterCategoryMode()
    UpdateSearchCenterCLILayout()
    
    ; 【关键修复】先刷新标签背景色，确保立即显示
    try {
        if (GuiID_SearchCenter && IsObject(GuiID_SearchCenter) && GuiID_SearchCenter.HasProp("Hwnd")) {
            WinRedraw(GuiID_SearchCenter.Hwnd)
        }
    } catch as err {
        ; 忽略刷新错误
    }
    BringSearchCenterFilterButtonsToFront()
    
    ; 刷新搜索引擎图标显示
    RefreshSearchCenterEngineIcons()

    if (SearchCenterIsCLICategory()) {
        try ExecuteSearchCenterSearch()
    }
    
    ; 确保激活状态在分类栏
    SearchCenterActiveArea := "category"
}

; 刷新搜索中心输入框边框（用于 SetTimer 回调，确保边框完全移除）
RefreshSearchCenterEditBorder(EditHwnd) {
    try {
        if (EditHwnd) {
            DllCall("InvalidateRect", "Ptr", EditHwnd, "Ptr", 0, "Int", 1)
            DllCall("UpdateWindow", "Ptr", EditHwnd)
        }
    } catch {
        ; 忽略错误
    }
}

; 恢复搜索中心区域指示器字体（用于 SetTimer 回调）
RestoreSearchCenterAreaIndicatorFont() {
    global SearchCenterAreaIndicator, UI_Colors
    ; 【修复】检查控件是否存在，避免控件已销毁错误
    if (SearchCenterAreaIndicator != 0) {
        try {
            SearchCenterAreaIndicator.SetFont("s11 Bold c" . UI_Colors.BtnPrimary, "Segoe UI")
        } catch as err {
            ; 忽略控件已销毁的错误
        }
    }
}

; 更新搜索中心高亮显示
UpdateSearchCenterHighlight() {
    global SearchCenterActiveArea, SearchCenterCurrentCategory, SearchCenterCategoryButtons, SearchCenterSearchEdit, SearchCenterResultLV, UI_Colors, ThemeMode
    global SearchCenterSelectedEnginesByCategory, ConfigFile, SearchCenterHintText, GuiID_SearchCenter, SearchCenterAreaIndicator
    global SearchCenterCLIOutputEdit
    
    ; 更新分类标签高亮
    Categories := GetSearchCenterCategories()
    for Index, Btn in SearchCenterCategoryButtons {
        IsSelected := (Index - 1 = SearchCenterCurrentCategory)
        IsActive := (SearchCenterActiveArea = "category" && IsSelected)
        
        ; 获取当前分类的选中搜索引擎数量
        if (Index <= Categories.Length) {
            CategoryKey := Categories[Index].Key
            SelectedCount := 0
            if (IsSet(SearchCenterSelectedEnginesByCategory) && IsObject(SearchCenterSelectedEnginesByCategory) && SearchCenterSelectedEnginesByCategory.Has(CategoryKey)) {
                SelectedCount := SearchCenterSelectedEnginesByCategory[CategoryKey].Length
            } else {
                ; 尝试从配置文件加载
                try {
                    CategoryEnginesStr := IniRead(ConfigFile, "Settings", "SearchCenterSelectedEngines_" . CategoryKey, "")
                    if (CategoryEnginesStr != "") {
                        if (InStr(CategoryEnginesStr, ":") > 0) {
                            EnginesStr := SubStr(CategoryEnginesStr, InStr(CategoryEnginesStr, ":") + 1)
                        } else {
                            EnginesStr := CategoryEnginesStr
                        }
                        if (EnginesStr != "") {
                            EnginesArray := StrSplit(EnginesStr, ",")
                            SelectedCount := EnginesArray.Length
                        }
                    }
                } catch as err {
                }
            }
            
            ; 更新标签文本，显示选中数量
            CategoryText := Categories[Index].Text
            if (SelectedCount > 0) {
                CategoryText := Categories[Index].Text . " (" . SelectedCount . ")"
            }
            
            try {
                Btn.Text := CategoryText
            } catch as err {
            }
        }
        
        if (IsActive) {
            ; 激活状态：高亮背景色（更亮的颜色）
            BgColor := UI_Colors.BtnPrimary
            TextColor := "FFFFFF"
        } else if (IsSelected) {
            ; 选中但未激活
            BgColor := UI_Colors.BtnPrimary
            TextColor := "FFFFFF"
        } else {
            ; 未选中
            BgColor := UI_Colors.Sidebar
            TextColor := UI_Colors.Text
        }
        
        try {
            Btn.Opt("+Background" . BgColor)
            Btn.SetFont("s10 Bold c" . TextColor, "Segoe UI")
        } catch as err {
            ; 忽略错误
        }
    }
    
    ; 更新输入框高亮（Material Design风格：聚焦时背景色变化，无边框）
    if (SearchCenterSearchEdit != 0) {
        try {
            ; 根据主题模式设置背景色（完全移除边框，只改变背景色）
            if (SearchCenterActiveArea = "input") {
                ; 激活输入框时，使用更亮的背景色
                if (ThemeMode = "dark") {
                    SearchCenterSearchEdit.Opt("+Background" . "3d3d40")  ; 稍亮的背景
                } else {
                    SearchCenterSearchEdit.Opt("+Background" . UI_Colors.InputBg)
                }
            } else {
                ; 未激活时，恢复默认背景色
                if (ThemeMode = "dark") {
                    SearchCenterSearchEdit.Opt("+Background" . UI_Colors.InputBg)  ; html.to.design 风格背景
                } else {
                    SearchCenterSearchEdit.Opt("+Background" . UI_Colors.InputBg)
                }
            }
        } catch as err {
            ; 忽略错误
        }
    }
    
    if (SearchCenterCLIOutputEdit != 0) {
        try {
            SearchCenterCLIOutputEdit.Opt("+Background" . UI_Colors.InputBg)
        } catch {
        }
    }
    
    ; 更新ListView高亮（通过选中状态）
    if (SearchCenterResultLV != 0) {
        try {
            if (SearchCenterActiveArea = "listview") {
                ; 激活ListView时，确保有选中项
                if (SearchCenterResultLV.GetCount() > 0 && SearchCenterResultLV.GetNext() = 0) {
                    ; 如果没有选中项，选中第一项
                    SearchCenterResultLV.Modify(1, "Select Focus")
                }
            }
        } catch as err {
            ; 忽略错误
        }
    }
    
    ; 更新区域名称动画展示
    if (SearchCenterAreaIndicator != 0) {
        try {
            ; 根据当前区域生成区域名称
            AreaName := ""
            if (SearchCenterIsCLICategory()) {
                switch SearchCenterActiveArea {
                    case "category":
                        AreaName := "CLI 分类"
                    case "input":
                        AreaName := "AI 对话"
                    case "listview":
                        AreaName := "本地结果"
                }
            } else {
                switch SearchCenterActiveArea {
                    case "category":
                        AreaName := "📍 分类搜索"  ; 当前区域名称
                    case "input":
                        AreaName := "✏️ 输入框"  ; 当前区域名称
                    case "listview":
                        AreaName := "🔍 本地搜索"  ; 当前区域名称（搜索结果列表）
                }
            }
            
            ; 更新区域名称文本（带动效：先放大高亮，然后恢复）
            SearchCenterAreaIndicator.Text := AreaName
            
            ; 区域切换动效：文本颜色和大小动画
            try {
                ; 【修复】检查控件是否存在，避免访问已销毁的控件
                if (SearchCenterAreaIndicator != 0) {
                    ; 先设置为高亮颜色和更大字体（动效提示）
                    HighlightColor := UI_Colors.BtnPrimary
                    SearchCenterAreaIndicator.SetFont("s13 Bold c" . HighlightColor, "Segoe UI")
                    ; 300ms后恢复为普通大小和颜色
                    SetTimer(RestoreSearchCenterAreaIndicatorFont, -300)
                }
            } catch as err {
                ; 忽略动效错误
            }
        } catch as err {
            ; 忽略更新错误
        }
    }
    
    ; 更新操作提示文本
    if (SearchCenterHintText != 0) {
        try {
            ; 根据当前区域生成详细的操作提示文本
            AreaHint := ""
            
            if (SearchCenterIsCLICategory()) {
                switch SearchCenterActiveArea {
                    case "category":
                        AreaHint := "当前是 CLI 页面。选择上方 AI，向下进入输入框，继续向下可查看本地结果和筛选标签。"
                    case "input":
                        AreaHint := "顶部输入框会实时过滤本地数据；Enter 发送给所选 AI，向下可浏览全部、文件、剪贴板等结果，底部区域显示选中项详情。"
                    case "listview":
                        AreaHint := "这里与 AI 页一致，显示本地检索结果。可用筛选标签切换全部、文件、剪贴板等数据，底部区域会预览当前选中项的详细内容。"
                }
            } else {
                switch SearchCenterActiveArea {
                    case "category":
                        AreaHint := "您可以使用方向键或 CapsLock+WSAD 切换操作。向上可以切换分类，向下进入输入框，Enter 执行搜索"
                    case "input":
                        AreaHint := "您可以使用方向键或 CapsLock+WSAD 切换操作。向上进入分类栏，向下查看本地搜索结果，Enter 执行搜索。向上实现向多个AI提问或者网络搜索，向下可以查看搜索本地提示词和剪贴板"
                    case "listview":
                        AreaHint := "您可以使用方向键或 CapsLock+WSAD 切换操作。向上返回输入框，向下浏览结果，Enter 粘贴选中项。这里显示本地搜索的提示词和剪贴板历史"
                }
            }
            
            ; 更新提示文本
            SearchCenterHintText.Text := AreaHint
            
            ; 区域切换动效：文本颜色闪烁提示
            try {
                ; 先设置为高亮颜色（动效提示）
                HighlightColor := UI_Colors.BtnPrimary
                SearchCenterHintText.SetFont("s9 Bold c" . HighlightColor, "Segoe UI")
                ; 200ms后恢复为普通颜色
                SetTimer(() => (
                    SearchCenterHintText.SetFont("s9 c" . UI_Colors.TextDim, "Segoe UI")
                ), -200)
            } catch as err {
                ; 忽略动效错误
            }
        } catch as err {
            ; 忽略更新错误
        }
    }
    
    ; 区域边框高亮动效（通过改变输入框和ListView的边框颜色）
    try {
        ; 输入框边框动效
        if (SearchCenterSearchEdit != 0) {
            if (SearchCenterActiveArea = "input") {
                ; 激活时：添加边框高亮效果（通过改变背景色实现）
                if (ThemeMode = "dark") {
                    ; 暗色模式：使用更亮的背景色作为边框效果
                    SearchCenterSearchEdit.Opt("+Background" . "3d3d40")
                } else {
                    ; 亮色模式：使用稍亮的背景色
                    SearchCenterSearchEdit.Opt("+Background" . UI_Colors.InputBg)
                }
            }
        }
        
        ; ListView边框动效（通过背景色变化实现）
        if (SearchCenterResultLV != 0) {
            if (SearchCenterActiveArea = "listview") {
                ; 激活时：使用稍亮的背景色
                if (ThemeMode = "dark") {
                    SearchCenterResultLV.Opt("+Background" . "3d3d40")
                } else {
                    SearchCenterResultLV.Opt("+Background" . UI_Colors.InputBg)
                }
            } else {
                ; 未激活时：恢复默认背景色
                SearchCenterResultLV.Opt("+Background" . UI_Colors.InputBg)
            }
        }
    } catch as err {
        ; 忽略动效错误
    }
}

; ===================== 结果数量限制下拉菜单变化事件 =====================
OnSearchCenterResultLimitChange(*) {
    global SearchCenterResultLimitDropdown, SearchCenterSearchEdit
    global SearchCenterCurrentLimit, SearchCenterEverythingLimit
    
    if (!IsSet(SearchCenterResultLimitDropdown) || !SearchCenterResultLimitDropdown) {
        return
    }
    
    try {
        selectedText := SearchCenterResultLimitDropdown.Text
        newLimit := GetSearchCenterLimitFromDropdownText(selectedText)
    } catch {
        newLimit := 50
    }

    if (newLimit <= 0)
        newLimit := 50

    SearchCenterCurrentLimit := newLimit
    SearchCenterEverythingLimit := newLimit
    
    UpdateSearchCenterFilterDropdown()
    if (IsSet(SearchCenterSearchEdit) && SearchCenterSearchEdit && Trim(SearchCenterSearchEdit.Value) != "") {
        ExecuteSearchCenterSearch()
        return
    }
    RefreshSearchCenterResults()
}

; 执行搜索中心搜索（带防抖）
ExecuteSearchCenterSearch(*) {
    global SearchCenterSearchEdit, SearchCenterResultLV, SearchCenterSearchResults
    global SearchCenterDebounceTimer
    
    ; 取消之前的防抖定时器（专用定时器，避免与配置面板 SearchDebounceTimer 互相覆盖）
    if (SearchCenterDebounceTimer != 0) {
        SetTimer(SearchCenterDebounceTimer, 0)
        SearchCenterDebounceTimer := 0
    }
    
    ; 设置新的防抖定时器（150ms 延迟）
    SearchCenterDebounceTimer := (*) => DebouncedSearchCenter(0)  ; 新搜索，offset = 0
    SetTimer(SearchCenterDebounceTimer, -150)
}

; 防抖后的实际搜索执行
; 加载默认模板到搜索中心
LoadDefaultTemplates() {
    global SearchCenterSearchResults, SearchCenterResultLV, SearchCenterVisibleResults
    
    ; 加载提示词模板作为默认内容
    global PromptTemplates
    if (!PromptTemplates) {
        LoadPromptTemplates()
    }
    
    ; 将模板添加到搜索结果
    for template in PromptTemplates {
        SearchCenterSearchResults.Push({
            Title: template.Title,
            Content: template.Content,
            Source: "模板",
            DataType: "template",
            Time: ""
        })
    }
    
    RefreshSearchCenterResults()
    
    ; 【关键修复】确保标签按钮状态正确显示
    UpdateSearchCenterFilterButtons()
    
    OutputDebug("AHK_DEBUG: 默认模板加载完成，数量: " . SearchCenterSearchResults.Length)
}

; 防抖后的实际搜索执行
DebouncedSearchCenter(offset := 0) {
    global SearchCenterSearchResults, SearchCenterResultLV, SearchCenterSearchEdit
    global SearchCenterCurrentLimit, SearchCenterHasMoreData, SearchCenterFilterType
    
    ; 下拉仅控制结果数量，不覆盖过滤标签状态
    Keyword := Trim(SearchCenterSearchEdit.Value)
    
    ; 如果是新搜索（offset = 0），重置数据
    if (offset = 0) {
        SearchCenterSearchResults := []
        SearchCenterResultLV.Delete()
    }
    
    if (Keyword == "") {
        if (offset = 0) {
            LoadDefaultTemplates()
        }
        return
    }

    OutputDebug("AHK_DEBUG: 开始搜索流程... (offset: " . offset . ", limit: " . SearchCenterCurrentLimit . ")")
    OutputDebug("AHK_DEBUG: 当前来源过滤: " . SearchCenterFilterType)

    ; 2. 使用 SearchAllDataSources 搜索所有数据源（支持分页）
    ; 临时存储新加载的数据
    NewResults := []
    try {
        FilterDataTypes := GetSearchCenterDataTypesForFilter(SearchCenterFilterType)
        ; 非「全部」且当前不是仅「文件」过滤时，顺带检索磁盘（Everything），与剪贴板/模板等混排
        if (FilterDataTypes.Length > 0) {
            hasFileType := false
            for _, dt in FilterDataTypes {
                if (dt = "file") {
                    hasFileType := true
                    break
                }
            }
            if (!hasFileType)
                FilterDataTypes.Push("file")
        }
        AllDataResults := SearchAllDataSources(Keyword, FilterDataTypes, SearchCenterCurrentLimit, offset)
        
        ; 检查是否有更多数据
        SearchCenterHasMoreData := false
        for DataType, TypeData in AllDataResults {
            if (IsObject(TypeData) && TypeData.HasProp("HasMore") && TypeData.HasMore) {
                SearchCenterHasMoreData := true
                break
            }
        }
        
        ; 将 Map 格式转换为扁平化的数组
        for DataType, TypeData in AllDataResults {
            if (IsObject(TypeData) && TypeData.HasProp("Items")) {
                for Index, Item in TypeData.Items {
                    ; 格式化时间显示
                    TimeDisplay := ""
                    if (Item.HasProp("TimeFormatted")) {
                        TimeDisplay := Item.TimeFormatted
                    } else if (Item.HasProp("Timestamp")) {
                        try {
                            TimeDisplay := FormatTime(Item.Timestamp, "yyyy-MM-dd HH:mm:ss")
                        } catch as err {
                            TimeDisplay := Item.Timestamp
                        }
                    } else {
                        TimeDisplay := ""
                    }
                    
                    ; 生成标题（文件类优先友好 DisplayTitle）
                    TitleText := ""
                    if (Item.HasProp("DisplayTitle") && Item.DisplayTitle != "") {
                        TitleText := Item.DisplayTitle
                    } else if (Item.HasProp("Title") && Item.Title != "") {
                        TitleText := Item.Title
                    } else if (Item.HasProp("Content") && Item.Content != "") {
                        TitleText := SubStr(Item.Content, 1, 50)
                        if (StrLen(Item.Content) > 50) {
                            TitleText .= "..."
                        }
                    } else {
                        TitleText := ""
                    }
                    
                    ; 提取数据类型（优先从Metadata.DataType中获取，然后从Item.DataType，最后从DataType推断）
                    ItemDataType := ""
                    ; 1. 优先从Metadata中获取（剪贴板历史使用这种方式）
                    if (Item.HasProp("Metadata") && IsObject(Item.Metadata) && Item.Metadata.Has("DataType") && Item.Metadata["DataType"] != "") {
                        ItemDataType := Item.Metadata["DataType"]
                    } 
                    ; 2. 从Item.DataType获取（其他数据源可能直接有这个字段，但要排除数据源类型）
                    else if (Item.HasProp("DataType") && Item.DataType != "") {
                        ; 排除数据源类型（clipboard/template/config/file/hotkey/function/ui），这些不是内容类型
                        if (Item.DataType != "clipboard" && Item.DataType != "template" && Item.DataType != "config" && Item.DataType != "file" && Item.DataType != "hotkey" && Item.DataType != "function" && Item.DataType != "ui") {
                            ItemDataType := Item.DataType
                        }
                    }
                    
                    ; 3. 如果是剪贴板数据，但没有找到具体类型，从DataTypeName反向映射
                    if (ItemDataType = "" && DataType = "clipboard") {
                        if (Item.HasProp("DataTypeName") && Item.DataTypeName != "") {
                            DataTypeName := Item.DataTypeName
                            if (DataTypeName = "代码片段" || DataTypeName = "代码") {
                                ItemDataType := "Code"
                            } else if (DataTypeName = "链接") {
                                ItemDataType := "Link"
                            } else if (DataTypeName = "邮箱" || DataTypeName = "邮件") {
                                ItemDataType := "Email"
                            } else if (DataTypeName = "图片") {
                                ItemDataType := "Image"
                            } else if (DataTypeName = "颜色") {
                                ItemDataType := "Color"
                            } else if (DataTypeName = "文本" || DataTypeName = "剪贴板历史") {
                                ItemDataType := "Text"
                            }
                        }
                    }
                    
                    ; 4. 对于非剪贴板数据源，使用数据源类型作为显示类型（template/config/file等）
                    if (ItemDataType = "" && DataType != "clipboard") {
                        ; 使用数据源类型作为标签
                        if (DataType = "template") {
                            ItemDataType := "Template"
                        } else if (DataType = "config") {
                            ItemDataType := "Config"
                        } else if (DataType = "file") {
                            ItemDataType := "File"
                        } else if (DataType = "hotkey") {
                            ItemDataType := "Hotkey"
                        } else if (DataType = "function") {
                            ItemDataType := "Function"
                        } else if (DataType = "ui") {
                            ItemDataType := "UI"
                        }
                    }
                    
                    ; 5. 如果没有找到类型，使用默认值（对于剪贴板默认为Text，其他为数据源类型）
                    if (ItemDataType = "") {
                        ItemDataType := DataType = "clipboard" ? "Text" : DataType
                    }
                    
                    ResultItem := {
                        Title: TitleText,
                        Source: TypeData.HasProp("DataTypeName") ? TypeData.DataTypeName : DataType,
                        DataType: ItemDataType,
                        Time: TimeDisplay,
                        Content: Item.HasProp("Content") ? Item.Content : TitleText,
                        ID: Item.HasProp("ID") ? Item.ID : "",
                        OriginalDataType: DataType
                    }
                    if (Item.HasProp("Metadata") && IsObject(Item.Metadata))
                        ResultItem.Metadata := Item.Metadata
                    if (Item.HasProp("DisplayTitle") && Item.DisplayTitle != "")
                        ResultItem.DisplayTitle := Item.DisplayTitle
                    if (Item.HasProp("Category") && Item.Category != "")
                        ResultItem.Category := Item.Category
                    if (Item.HasProp("TypeHint") && Item.TypeHint != "")
                        ResultItem.TypeHint := Item.TypeHint
                    if (Item.HasProp("FzyCategoryBonus"))
                        ResultItem.FzyCategoryBonus := Item.FzyCategoryBonus
                    if (Item.HasProp("DisplayPath") && Item.DisplayPath != "")
                        ResultItem.DisplayPath := Item.DisplayPath
                    if (Item.HasProp("DisplaySubtitle") && Item.DisplaySubtitle != "")
                        ResultItem.DisplaySubtitle := Item.DisplaySubtitle
                    if (Item.HasProp("SubCategory") && Item.SubCategory != "")
                        ResultItem.SubCategory := Item.SubCategory
                    if (Item.HasProp("CategoryColor") && Item.CategoryColor != "")
                        ResultItem.CategoryColor := Item.CategoryColor
                    if (Item.HasProp("PathTrust"))
                        ResultItem.PathTrust := Item.PathTrust
                    if (Item.HasProp("BonusTotal"))
                        ResultItem.BonusTotal := Item.BonusTotal
                    if (Item.HasProp("PenaltyTotal"))
                        ResultItem.PenaltyTotal := Item.PenaltyTotal
                    if (Item.HasProp("FzyBase"))
                        ResultItem.FzyBase := Item.FzyBase
                    if (Item.HasProp("FinalScore"))
                        ResultItem.FinalScore := Item.FinalScore
                    if (Item.HasProp("QuotaCategory"))
                        ResultItem.QuotaCategory := Item.QuotaCategory
                    
                    ; 如果是新搜索，追加到总结果；如果是加载更多，只追加到新结果
                    if (offset = 0) {
                        SearchCenterSearchResults.Push(ResultItem)
                    } else {
                        NewResults.Push(ResultItem)
                    }
                }
            }
        }
    } catch as err {
        OutputDebug("AHK_DEBUG: SearchAllDataSources 报错: " . err.Message)
    }

    ; 身份化：标题前缀与副标题（排序前）
    if (offset = 0 && SearchCenterSearchResults.Length > 0 && StrLen(Keyword) > 0) {
        try {
            Loop SearchCenterSearchResults.Length {
                scItem := SearchCenterSearchResults[A_Index]
                SyncIdentityToResultItem(&scItem, Keyword)
            }
        } catch as errId {
            OutputDebug("AHK_DEBUG: SyncIdentityToResultItem: " . errId.Message)
        }
    }

    ; 文件（Everything）置顶 + Fzy 精准加权；其余来源排在后面
    if (offset = 0 && SearchCenterSearchResults.Length > 0) {
        try SortSearchCenterMergedResults(&SearchCenterSearchResults, Keyword)
    }

    ; 3. 【关键修复】统一渲染到界面（使用中文类型名称）
    ; 刷新结果显示（应用过滤）
    RefreshSearchCenterResults()
    
    OutputDebug("AHK_DEBUG: 搜索中心刷新完成，总结果: " . SearchCenterSearchResults.Length . ", 还有更多: " . (SearchCenterHasMoreData ? "是" : "否"))
}

; Destroy 之后必须清空控件引用，否则异步 RefreshSearchCenterResults 仍持有旧 Gui.Control 会报 “control is destroyed”
SearchCenterInvalidateGuiControlRefs() {
    global SearchCenterSearchEdit, SearchCenterResultLV, SearchCenterCLIOutputEdit
    global SearchCenterAreaIndicator, SearchCenterHintText, SearchCenterResultLimitDropdown
    SearchCenterSearchEdit := 0
    SearchCenterResultLV := 0
    SearchCenterCLIOutputEdit := 0
    SearchCenterAreaIndicator := 0
    SearchCenterHintText := 0
    SearchCenterResultLimitDropdown := 0
}

; 刷新搜索中心结果显示（应用过滤类型）
RefreshSearchCenterResults() {
    global SearchCenterSearchResults, SearchCenterResultLV, SearchCenterFilterType, SearchCenterVisibleResults
    global GuiID_SearchCenter
    
    if (!GuiID_SearchCenter || GuiID_SearchCenter = 0) {
        return
    }
    try {
        if (!GuiID_SearchCenter.HasProp("Hwnd") || !WinExist("ahk_id " . GuiID_SearchCenter.Hwnd)) {
            return
        }
    } catch {
        return
    }
    if (!SearchCenterResultLV || SearchCenterResultLV = 0) {
        return
    }

    ; 下拉仅控制结果数量，不覆盖过滤标签状态
    try {
    ; 清空ListView
    SearchCenterResultLV.Opt("-Redraw")
    SearchCenterResultLV.Delete()
    
    ; 根据过滤类型过滤结果
    FilteredResults := []
    for index, res in SearchCenterSearchResults {
        ; 检查是否匹配过滤类型
        ShouldInclude := false
        
        if (SearchCenterFilterType = "") {
            ; 全部：显示所有结果
            ShouldInclude := true
        } else if (SearchCenterFilterType = "clipboard") {
            ; 严格过滤：仅显示剪贴板来源
            ShouldInclude := (res.HasProp("OriginalDataType") && res.OriginalDataType = "clipboard") || (res.HasProp("Source") && InStr(res.Source, "剪贴板") > 0)
        } else if (SearchCenterFilterType = "template") {
            ; 严格过滤：仅显示模板/提示词来源
            ShouldInclude := (res.HasProp("OriginalDataType") && res.OriginalDataType = "template") || (res.HasProp("Source") && (InStr(res.Source, "模板") > 0 || InStr(res.Source, "提示词") > 0))
        } else if (SearchCenterFilterType = "config") {
            ; 严格过滤：仅显示配置来源
            ShouldInclude := (res.HasProp("OriginalDataType") && res.OriginalDataType = "config") || (res.HasProp("Source") && InStr(res.Source, "配置") > 0)
        } else if (SearchCenterFilterType = "hotkey") {
            ; 严格过滤：仅显示快捷键来源
            ShouldInclude := (res.HasProp("OriginalDataType") && res.OriginalDataType = "hotkey") || (res.HasProp("Source") && InStr(res.Source, "快捷键") > 0)
        } else if (SearchCenterFilterType = "function") {
            ; 严格过滤：仅显示功能来源
            ShouldInclude := (res.HasProp("OriginalDataType") && res.OriginalDataType = "function") || (res.HasProp("Source") && InStr(res.Source, "功能") > 0)
        } else if (SearchCenterFilterType = "File") {
            ; 文件：检查OriginalDataType是否为file，或DataType为File，或Source包含"文件"
            ShouldInclude := (res.HasProp("OriginalDataType") && res.OriginalDataType = "file") || (res.HasProp("DataType") && res.DataType = "File") || (res.HasProp("Source") && InStr(res.Source, "文件") > 0)
        }
        
        if (ShouldInclude) {
            FilteredResults.Push(res)
        }
    }
    
    ; 添加过滤后的结果到ListView（第 1 列图标，第 2 列起为标题/来源/类型/时间）
    for index, res in FilteredResults {
        ContentType := res.HasProp("DataType") ? res.DataType : "Text"
        TypeDisplayName := GetContentTypeDisplayName(ContentType)
        if (res.HasProp("OriginalDataType") && res.OriginalDataType = "file" && res.HasProp("Category") && res.Category != "")
            try TypeDisplayName := FileClassifier.GetCategoryDisplayName(res.Category)
        iconOpt := ""
        try {
            if (ShellIcon_EnsureImageList(SearchCenterResultLV, "sc"))
                iconOpt := "Icon" . ShellIcon_GetPlaceholderIndex("sc")
        } catch {
        }
        rowTitle := (res.HasProp("DisplayTitle") && res.DisplayTitle != "") ? res.DisplayTitle : res.Title
        rowSubtitle := (res.HasProp("DisplaySubtitle") && res.DisplaySubtitle != "") ? res.DisplaySubtitle : res.Source
        if (iconOpt != "")
            SearchCenterResultLV.Add(iconOpt, "", rowTitle, rowSubtitle, TypeDisplayName, res.Time)
        else
            SearchCenterResultLV.Add("", "", rowTitle, rowSubtitle, TypeDisplayName, res.Time)
    }
    
    SearchCenterVisibleResults := FilteredResults
    SearchCenterResultLV.ModifyCol(1, 36)
    SearchCenterResultLV.ModifyCol(2, "AutoHdr")
    SearchCenterResultLV.ModifyCol(3, "AutoHdr")
    SearchCenterResultLV.ModifyCol(4, "AutoHdr")
    SearchCenterResultLV.ModifyCol(5, "AutoHdr")
    try UpdateIcons(SearchCenterVisibleResults, SearchCenterVisibleResults.Length, SearchCenterResultLV, "sc")
    SearchCenterResultLV.Opt("+Redraw")
    if (SearchCenterResultLV.GetCount() > 0) {
        SearchCenterResultLV.Modify(1, "Select Focus Vis")
        UpdateSearchCenterCLIPreview(1)
    } else {
        UpdateSearchCenterCLIPreview(0)
    }
    
    ; 【关键修复】刷新结果显示后，更新标签按钮样式以保持选中状态
    UpdateSearchCenterFilterButtons()
    } catch as err {
        OutputDebug("AHK_DEBUG: RefreshSearchCenterResults: " . err.Message)
    }
}


; 搜索中心搜索结果双击事件
OnSearchCenterResultDoubleClick(LV, Row) {
    global SearchCenterVisibleResults

    if (Row > 0 && Row <= SearchCenterVisibleResults.Length) {
        Item := GetSearchCenterResultItemByRow(Row)
        if (!IsObject(Item)) {
            return
        }
        Content := Item.HasProp("Content") ? Item.Content : Item.Title
        
        ; 检查数据类型（优先检查 DataType 字段，然后检查 Metadata）
        DataType := ""
        if (Item.HasProp("DataType") && Item.DataType != "") {
            DataType := Item.DataType
        } else if (Item.HasProp("Metadata") && IsObject(Item.Metadata) && Item.Metadata.Has("DataType")) {
            DataType := Item.Metadata["DataType"]
        }
        
        ; 根据类型执行不同操作（搜索中心扁平化后 DataType 可能为 File/Folder 或 OriginalDataType=file）
        origDt := Item.HasProp("OriginalDataType") ? Item.OriginalDataType : ""
        isFileLike := (DataType = "file" || DataType = "File" || DataType = "Folder" || origDt = "file")
        if (isFileLike) {
            ; 文件类型：打开文件或文件夹
            FilePath := Content
            try {
                if (FileExist(FilePath) || DirExist(FilePath)) {
                    Run(FilePath)
                    TrayTip("已打开", Item.Title, "Iconi 1")
                } else {
                    TrayTip("路径不存在", FilePath, "Iconx 2")
                }
            } catch as err {
                TrayTip("打开失败", err.Message, "Iconx 2")
            }
        } else if (DataType = "Link") {
            ; 链接类型：直接打开浏览器
            try {
                Run(Content)
                TrayTip("已打开链接", Content, "Iconi 1")
            } catch as err {
                TrayTip("打开链接失败", err.Message, "Iconx 2")
            }
        } else if (DataType = "Image") {
            ; 图片类型：使用系统查看器打开
            try {
                if (FileExist(Content)) {
                    Run(Content)
                    TrayTip("已打开图片", Content, "Iconi 1")
                } else {
                    TrayTip("图片文件不存在", Content, "Iconx 2")
                }
            } catch as err {
                TrayTip("打开图片失败", err.Message, "Iconx 2")
            }
        } else {
            ; 其他类型：复制内容到剪贴板并粘贴
            A_Clipboard := Content
            Sleep(50)
            Send("^v")  ; Ctrl+V 粘贴
            TrayTip("已粘贴", Item.Title, "Iconi 1")
        }
    }
}

; ===================== SearchCenter 窗口大小改变事件 =====================
OnSearchCenterSize(GuiObj, MinMax, Width, Height) {
    global GuiID_SearchCenter, SearchCenterResultLV, SearchCenterSearchEdit
    global SearchCenterAreaIndicator, SearchCenterHintText, SearchCenterResultLimitDropdown
    global SearchCenterFilterButtons
    global SearchCenterCLIOutputEdit
    global SearchCenterCLIRunButton, SearchCenterCLIClearButton, SearchCenterCLIOpenButton

    if (GuiID_SearchCenter = 0 || GuiObj.Hwnd != GuiID_SearchCenter.Hwnd) {
        return
    }
    
    ; 如果窗口正在最小化，不进行调整
    if (MinMax = -1) {
        return
    }
    
    ; 常量定义（与 ShowSearchCenter 中保持一致）
    Padding := 20
    DropdownWidth := 120
    AreaIndicatorHeight := 25
    HintTextHeight := 40
    SearchEditHeight := 50
    FilterBarHeight := 40  ; 【新增】过滤标签按钮区域高度
    
    ; 计算搜索输入框的新宽度
    SearchEditWidth := Width - Padding * 2 - DropdownWidth - 10
    
    ; 调整搜索输入框宽度（保持 X 坐标和 Y 坐标不变，只改变宽度）
    if (SearchCenterSearchEdit != 0) {
        try {
            ControlGetPos(&CurrentX, &CurrentY, &CurrentW, &CurrentH, SearchCenterSearchEdit)
            SearchCenterSearchEdit.Move(CurrentX, CurrentY, SearchEditWidth, SearchEditHeight)
        } catch as err {
            ; 忽略错误
        }
    }
    
    ; 调整区域指示器宽度（保持 X 坐标和 Y 坐标不变，只改变宽度）
    if (SearchCenterAreaIndicator != 0) {
        try {
            ControlGetPos(&CurrentX, &CurrentY, &CurrentW, &CurrentH, SearchCenterAreaIndicator)
            SearchCenterAreaIndicator.Move(CurrentX, CurrentY, SearchEditWidth, CurrentH)
        } catch as err {
            ; 忽略错误
        }
    }
    
    ; 调整提示文本宽度（保持 X 坐标和 Y 坐标不变，只改变宽度）
    if (SearchCenterHintText != 0) {
        try {
            ControlGetPos(&CurrentX, &CurrentY, &CurrentW, &CurrentH, SearchCenterHintText)
            SearchCenterHintText.Move(CurrentX, CurrentY, SearchEditWidth, CurrentH)
        } catch as err {
            ; 忽略错误
        }
    }
    
    static InLayout := false
    if (InLayout) {
        return
    }
    InLayout := true
    
    try {
        if (SearchCenterResultLV != 0) {
            SearchCenterResultLV.Opt("-Redraw")
        }
        
        ; 缩放过程只做必要重排，避免每帧置顶导致抖动
        UpdateSearchCenterCLILayout(Width, Height, false)
    if (SearchCenterResultLV != 0) {
        try {
            innerW := Width - Padding * 2
            SearchCenterResultLV.ModifyCol(1, 36)
            restW := innerW - 36
            SearchCenterResultLV.ModifyCol(2, restW * 0.4)
            SearchCenterResultLV.ModifyCol(3, restW * 0.2)
            SearchCenterResultLV.ModifyCol(4, restW * 0.15)
            SearchCenterResultLV.ModifyCol(5, restW * 0.25)
        } catch as err {
        }
    }
    } finally {
        if (SearchCenterResultLV != 0) {
            try SearchCenterResultLV.Opt("+Redraw")
        }
        InLayout := false
    }
}

; 搜索中心 Enter 键处理函数（检查窗口是否激活）
; 搜索中心窗口关闭处理函数
SearchCenterCloseHandler(*) {
    global GuiID_SearchCenter, SearchCenterSelectedEngines, SearchCenterSelectedEnginesByCategory, SearchCenterCurrentCategory
    ; 【关键修复】在关闭窗口前保存当前分类的选择状态
    try {
        Categories := GetSearchCenterCategories()
        if (Categories.Length > 0 && SearchCenterCurrentCategory >= 0 && SearchCenterCurrentCategory < Categories.Length) {
            CurrentCategory := Categories[SearchCenterCurrentCategory + 1]
            CategoryKey := CurrentCategory.Key
            if (IsSet(SearchCenterSelectedEngines) && IsObject(SearchCenterSelectedEngines)) {
                ; 保存到内存Map
                if (!IsSet(SearchCenterSelectedEnginesByCategory) || !IsObject(SearchCenterSelectedEnginesByCategory)) {
                    SearchCenterSelectedEnginesByCategory := Map()
                }
                CurrentEngines := []
                for Index, Engine in SearchCenterSelectedEngines {
                    CurrentEngines.Push(Engine)
                }
                SearchCenterSelectedEnginesByCategory[CategoryKey] := CurrentEngines
                
                ; 保存到配置文件
                global ConfigFile
                EnginesStr := ""
                for Index, Eng in SearchCenterSelectedEngines {
                    if (Index > 1) {
                        EnginesStr .= ","
                    }
                    EnginesStr .= Eng
                }
                ; 保存格式：分类:引擎1,引擎2
                CategoryEnginesStr := CategoryKey . ":" . EnginesStr
                IniWrite(CategoryEnginesStr, ConfigFile, "Settings", "SearchCenterSelectedEngines_" . CategoryKey)
            }
        }
    } catch as err {
        ; 忽略保存错误，不影响关闭窗口
    }
    
    ; 注意：Enter和ESC键热键使用#HotIf自动管理，无需手动取消注册
    ; 销毁窗口
    if (GuiID_SearchCenter) {
        try {
            CleanupSearchCenterResultLimitDDLBrush()
            GuiID_SearchCenter.Destroy()
        } catch as err {
            ; 忽略错误
        }
        GuiID_SearchCenter := 0
        SearchCenterInvalidateGuiControlRefs()
    }
}

; 执行搜索中心批量搜索（按Enter键时）
ExecuteSearchCenterBatchSearch(*) {
    global SearchCenterSearchEdit, SearchCenterSelectedEngines, GuiID_SearchCenter
    global GlobalSearchStatement, SearchCenterDebounceTimer
    
    if (SearchCenterIsCLICategory()) {
        ExecuteSearchCenterCLICommand()
        return
    }
    
    ; 【并发同步】第一行代码：强制释放 Statement 句柄
    GlobalSearchEngine.ReleaseOldStatement()
    
    ; 取消搜索中心防抖定时器
    if (SearchCenterDebounceTimer != 0) {
        SetTimer(SearchCenterDebounceTimer, 0)
        SearchCenterDebounceTimer := 0
    }
    
    ; 窗口已销毁或 Invalidate 后引用为 0 时，热键/定时器仍可能晚到，避免对 Integer 取 .Value
    if (!GuiID_SearchCenter || GuiID_SearchCenter = 0 || !IsObject(SearchCenterSearchEdit)) {
        return
    }
    
    ; 获取搜索关键词
    Keyword := SearchCenterSearchEdit.Value
    if (StrLen(Keyword) < 1) {
        TrayTip("请输入搜索关键词", "提示", "Icon! 2")
        return
    }
    
    ; 检查是否有选中的搜索引擎
    if (!IsSet(SearchCenterSelectedEngines) || !IsObject(SearchCenterSelectedEngines) || SearchCenterSelectedEngines.Length = 0) {
        TrayTip("请至少选择一个搜索引擎", "提示", "Icon! 2")
        return
    }
    
    ; 打开所有选中的搜索引擎
    for Index, Engine in SearchCenterSelectedEngines {
        if (!IsSet(Engine) || Engine = "") {
            continue  ; 跳过无效的引擎
        }
        SendVoiceSearchToBrowser(Keyword, Engine)
        ; 每个搜索引擎之间稍作延迟，避免同时打开太多窗口
        if (Index < SearchCenterSelectedEngines.Length) {
            Sleep(300)
        }
    }
    
    TrayTip("已打开 " . SearchCenterSelectedEngines.Length . " 个搜索引擎", "提示", "Iconi 1")
    
    ; 可选：关闭搜索中心窗口
    ; if (GuiID_SearchCenter != 0) {
    ;     try {
    ;         GuiID_SearchCenter.Destroy()
    ;     } catch as err {
    ;     }
    ; }
}

; 刷新搜索中心搜索引擎图标显示
RefreshSearchCenterEngineIcons() {
    global GuiID_SearchCenter, SearchCenterCurrentCategory, SearchCenterEngineIcons, UI_Colors
    global SearchCenterSelectedEngines, SearchCenterSelectedEnginesByCategory
    
    ; 如果窗口不存在，直接返回
    if (!GuiID_SearchCenter || GuiID_SearchCenter = 0) {
        return
    }
    
    ; 【关键修复】参考capslock+f的实现：先隐藏旧图标，创建新图标后再销毁旧图标，避免闪烁
    if (IsSet(SearchCenterEngineIcons) && IsObject(SearchCenterEngineIcons)) {
        ; 先隐藏所有旧图标控件（不立即销毁，保持界面流畅）
        for Index, IconObj in SearchCenterEngineIcons {
            if (IsObject(IconObj)) {
                try {
                    if (IconObj.HasProp("Icon") && IconObj.Icon != 0) {
                        IconObj.Icon.Visible := false
                    }
                    if (IconObj.HasProp("NameLabel") && IconObj.NameLabel != 0) {
                        IconObj.NameLabel.Visible := false
                    }
                    if (IconObj.HasProp("Bg") && IconObj.Bg != 0) {
                        IconObj.Bg.Visible := false
                    }
                    if (IconObj.HasProp("Check") && IconObj.Check != 0) {
                        IconObj.Check.Visible := false
                    }
                } catch as err {
                    ; 忽略隐藏错误
                }
            }
        }
    }
    
    ; 保存旧图标数组用于后续销毁
    OldIcons := SearchCenterEngineIcons
    ; 清空图标数组，准备创建新图标
    SearchCenterEngineIcons := []
    
    ; 获取当前分类
    Categories := GetSearchCenterCategories()
    if (Categories.Length = 0 || SearchCenterCurrentCategory < 0 || SearchCenterCurrentCategory >= Categories.Length) {
        return
    }
    
    CurrentCategory := Categories[SearchCenterCurrentCategory + 1]
    CategoryKey := CurrentCategory.Key
    
    ; 【关键修复】恢复当前分类的搜索引擎选择状态（参考CAPSLOCK+F的实现）
    if (!IsSet(SearchCenterSelectedEnginesByCategory) || !IsObject(SearchCenterSelectedEnginesByCategory)) {
        SearchCenterSelectedEnginesByCategory := Map()
    }
    
    if (SearchCenterSelectedEnginesByCategory.Has(CategoryKey)) {
        SearchCenterSelectedEngines := []
        for Index, Engine in SearchCenterSelectedEnginesByCategory[CategoryKey] {
            SearchCenterSelectedEngines.Push(Engine)
        }
    } else {
        ; 如果内存中没有，尝试从配置文件加载
        try {
            global ConfigFile
            CategoryEnginesStr := IniRead(ConfigFile, "Settings", "SearchCenterSelectedEngines_" . CategoryKey, "")
            if (CategoryEnginesStr != "") {
                ; 解析格式：分类:引擎1,引擎2
                if (InStr(CategoryEnginesStr, ":") > 0) {
                    EnginesStr := SubStr(CategoryEnginesStr, InStr(CategoryEnginesStr, ":") + 1)
                } else {
                    EnginesStr := CategoryEnginesStr
                }
                if (EnginesStr != "") {
                    SearchCenterSelectedEngines := []
                    EnginesArray := StrSplit(EnginesStr, ",")
                    for Index, Engine in EnginesArray {
                        Engine := Trim(Engine)
                        if (Engine != "") {
                            SearchCenterSelectedEngines.Push(Engine)
                        }
                    }
                    ; 保存到内存Map中
                    CurrentEngines := []
                    for Index, Engine in SearchCenterSelectedEngines {
                        CurrentEngines.Push(Engine)
                    }
                    SearchCenterSelectedEnginesByCategory[CategoryKey] := CurrentEngines
                } else {
                    SearchCenterSelectedEngines := []
                }
            } else {
                ; 如果该分类没有保存的选择状态，初始化为空数组，让用户自己选择（支持多选）
                SearchCenterSelectedEngines := (CategoryKey = "cli") ? ["codex_cli"] : []
            }
        } catch as err {
            ; 如果加载失败，初始化为空数组
            SearchCenterSelectedEngines := (CategoryKey = "cli") ? ["codex_cli"] : []
        }
    }
    
    ; 获取当前分类的搜索引擎列表
    SearchEngines := GetSortedSearchEngines(CategoryKey)
    if (!IsObject(SearchEngines) || SearchEngines.Length = 0) {
        return
    }
    
    ; 计算图标位置参数（与 ShowSearchCenter 中的布局保持一致）
    Padding := 20
    CategoryBarY := Padding
    CategoryBarHeight := 50
    EngineIconRowY := CategoryBarY + CategoryBarHeight + 5
    EngineIconRowHeight := 70  ; 增加高度以容纳图标下方的名称标签（50图标 + 2间距 + 16名称 = 68，留2像素余量）
    EngineIconSize := 40
    EngineIconSpacing := 15
    EngineIconStartX := Padding
    IconButtonSize := 50  ; 图标按钮的总大小（包括边框）
    
    ; 创建搜索引擎图标
    CurrentX := EngineIconStartX
    for Index, Engine in SearchEngines {
        if (!IsObject(Engine) || !Engine.HasProp("Value")) {
            continue
        }
        
        ; 检查是否选中
        IsSelected := (ArrayContainsValue(SearchCenterSelectedEngines, Engine.Value) > 0)
        
        ; 获取图标路径
        IconPath := GetSearchEngineIcon(Engine.Value)
        
        ; 计算图标按钮位置
        IconButtonX := CurrentX
        IconButtonY := EngineIconRowY + (EngineIconRowHeight - IconButtonSize) // 2
        
        ; 创建背景按钮（用于点击区域和选中状态显示）
        BgColor := IsSelected ? UI_Colors.BtnHover : UI_Colors.BtnBg
        BgBtn := GuiID_SearchCenter.Add("Text", "x" . IconButtonX . " y" . IconButtonY . " w" . IconButtonSize . " h" . IconButtonSize . " Center 0x200 Background" . BgColor, "")
        BgBtn.OnEvent("Click", CreateSearchCenterEngineClickHandler(Engine.Value, Index))
        HoverBtn(BgBtn, BgColor, UI_Colors.BtnHover)
        
        IconCtrl := 0
        CheckMark := 0
        NameLabel := 0
        
        if (IconPath != "" && FileExist(IconPath)) {
            try {
                ; 计算图标显示尺寸
                ImageSize := GetImageSize(IconPath)
                DisplaySize := CalculateImageDisplaySize(ImageSize.Width, ImageSize.Height, EngineIconSize, EngineIconSize)
                
                ; 计算图标位置（在按钮中居中）
                IconX := IconButtonX + (IconButtonSize - DisplaySize.Width) // 2
                IconY := IconButtonY + (IconButtonSize - DisplaySize.Height) // 2
                
                ; 创建图标控件
                IconCtrl := GuiID_SearchCenter.Add("Picture", "x" . IconX . " y" . IconY . " w" . DisplaySize.Width . " h" . DisplaySize.Height . " 0x200", IconPath)
                IconCtrl.OnEvent("Click", CreateSearchCenterEngineClickHandler(Engine.Value, Index))
                
                ; 如果选中，显示选中标记
                if (IsSelected) {
                    CheckX := IconButtonX + IconButtonSize - 18
                    CheckY := IconButtonY + 2
                    CheckMark := GuiID_SearchCenter.Add("Text", "x" . CheckX . " y" . CheckY . " w16 h16 Center 0x200 cFFFFFF Background" . UI_Colors.BtnPrimary, "✓")
                    CheckMark.SetFont("s12 Bold", "Segoe UI")
                    CheckMark.OnEvent("Click", CreateSearchCenterEngineClickHandler(Engine.Value, Index))
                }
            } catch as e {
                OutputDebug("创建搜索引擎图标失败: " . Engine.Value . " - " . e.Message)
                ; 如果图标创建失败，使用文字显示
                IconPath := ""
            }
        }
        
        ; 如果图标不存在，显示搜索引擎名称（在图标下方）
        if (IconPath = "" || !FileExist(IconPath)) {
            try {
                ; 获取搜索引擎名称
                EngineName := Engine.HasProp("Name") ? Engine.Name : Engine.Value
                
                ; 创建文字标签（显示在图标按钮下方，而不是中间）
                NameLabelY := IconButtonY + IconButtonSize + 2  ; 图标下方2像素
                NameLabelHeight := 16  ; 名称标签高度
                NameLabel := GuiID_SearchCenter.Add("Text", "x" . IconButtonX . " y" . NameLabelY . " w" . IconButtonSize . " h" . NameLabelHeight . " Center 0x200 c" . UI_Colors.Text . " BackgroundTrans", EngineName)
                NameLabel.SetFont("s8", "Segoe UI")
                NameLabel.OnEvent("Click", CreateSearchCenterEngineClickHandler(Engine.Value, Index))
                
                ; 如果选中，显示选中标记
                if (IsSelected) {
                    CheckX := IconButtonX + IconButtonSize - 18
                    CheckY := IconButtonY + 2
                    CheckMark := GuiID_SearchCenter.Add("Text", "x" . CheckX . " y" . CheckY . " w16 h16 Center 0x200 cFFFFFF Background" . UI_Colors.BtnPrimary, "✓")
                    CheckMark.SetFont("s12 Bold", "Segoe UI")
                    CheckMark.OnEvent("Click", CreateSearchCenterEngineClickHandler(Engine.Value, Index))
                }
            } catch as e {
                OutputDebug("创建搜索引擎名称标签失败: " . Engine.Value . " - " . e.Message)
            }
        } else {
            ; 即使有图标，也在图标下方显示名称
            try {
                ; 获取搜索引擎名称
                EngineName := Engine.HasProp("Name") ? Engine.Name : Engine.Value
                
                ; 创建文字标签（显示在图标按钮下方）
                NameLabelY := IconButtonY + IconButtonSize + 2  ; 图标下方2像素
                NameLabelHeight := 16  ; 名称标签高度
                NameLabel := GuiID_SearchCenter.Add("Text", "x" . IconButtonX . " y" . NameLabelY . " w" . IconButtonSize . " h" . NameLabelHeight . " Center 0x200 c" . UI_Colors.Text . " BackgroundTrans", EngineName)
                NameLabel.SetFont("s8", "Segoe UI")
                NameLabel.OnEvent("Click", CreateSearchCenterEngineClickHandler(Engine.Value, Index))
            } catch as e {
                OutputDebug("创建搜索引擎名称标签失败: " . Engine.Value . " - " . e.Message)
            }
        }
        
        ; 保存图标对象（包括名称标签）
        SearchCenterEngineIcons.Push({Bg: BgBtn, Icon: IconCtrl, NameLabel: NameLabel, Check: CheckMark, Engine: Engine.Value, Index: Index})
        
        ; 更新下一个图标的位置
        CurrentX += IconButtonSize + EngineIconSpacing
    }
    
    ; 【关键修复】刷新GUI显示，确保新图标立即显示
    try {
        if (GuiID_SearchCenter && IsObject(GuiID_SearchCenter) && GuiID_SearchCenter.HasProp("Hwnd")) {
            WinRedraw(GuiID_SearchCenter.Hwnd)
        }
    } catch as err {
        ; 忽略刷新错误
    }
    
    ; 【关键修复】延迟销毁旧图标，确保新图标已显示后再清理，提升流畅度并避免名称叠加
    SetTimer(() => DestroyOldSearchCenterIcons(OldIcons), -100)
}

; 销毁旧的搜索中心图标（延迟执行，提升流畅度）
DestroyOldSearchCenterIcons(OldIcons) {
    if (!IsSet(OldIcons) || !IsObject(OldIcons)) {
        return
    }
    
    for Index, IconObj in OldIcons {
        if (IsObject(IconObj)) {
            try {
                if (IconObj.HasProp("Icon") && IconObj.Icon != 0) {
                    IconObj.Icon.Destroy()
                }
                if (IconObj.HasProp("NameLabel") && IconObj.NameLabel != 0) {
                    IconObj.NameLabel.Destroy()
                }
                if (IconObj.HasProp("Bg") && IconObj.Bg != 0) {
                    IconObj.Bg.Destroy()
                }
                if (IconObj.HasProp("Check") && IconObj.Check != 0) {
                    IconObj.Check.Destroy()
                }
            } catch as err {
                ; 忽略销毁错误
            }
        }
    }
}

; 创建搜索中心搜索引擎点击处理函数
CreateSearchCenterEngineClickHandler(EngineValue, Index) {
    return (*) => ToggleSearchCenterEngine(EngineValue, Index)
}

; 切换搜索中心搜索引擎选择状态
ToggleSearchCenterEngine(EngineValue, Index) {
    global SearchCenterSelectedEngines, SearchCenterSelectedEnginesByCategory, SearchCenterCurrentCategory
    global SearchCenterEngineIcons, UI_Colors, GuiID_SearchCenter
    
    ; 确保数组已初始化
    if (!IsSet(SearchCenterSelectedEngines) || !IsObject(SearchCenterSelectedEngines)) {
        SearchCenterSelectedEngines := []
    }
    
    ; 确保Map已初始化
    if (!IsSet(SearchCenterSelectedEnginesByCategory) || !IsObject(SearchCenterSelectedEnginesByCategory)) {
        SearchCenterSelectedEnginesByCategory := Map()
    }
    
    ; 获取当前分类
    Categories := GetSearchCenterCategories()
    if (Categories.Length = 0 || SearchCenterCurrentCategory < 0 || SearchCenterCurrentCategory >= Categories.Length) {
        return
    }
    CurrentCategory := Categories[SearchCenterCurrentCategory + 1]
    CategoryKey := CurrentCategory.Key
    
    ; 切换选中状态
    FoundIndex := ArrayContainsValue(SearchCenterSelectedEngines, EngineValue)
    IsSelected := (FoundIndex = 0)  ; 如果没找到，说明要选中
    
    if (CategoryKey = "cli") {
        ; CLI 终端只能发往一个：多选会导致 codex 在 Native 队列里先于 qwen 打开，用户只选 Qwen 时仍会激活 Codex
        if (FoundIndex > 0) {
            SearchCenterSelectedEngines.RemoveAt(FoundIndex)
        } else {
            SearchCenterSelectedEngines := [EngineValue]
        }
    } else if (FoundIndex > 0) {
        ; 取消选中
        SearchCenterSelectedEngines.RemoveAt(FoundIndex)
    } else {
        ; 选中（支持多选）
        SearchCenterSelectedEngines.Push(EngineValue)
    }
    
    ; 保存到分类Map
    CurrentEngines := []
    for Index, Eng in SearchCenterSelectedEngines {
        CurrentEngines.Push(Eng)
    }
    SearchCenterSelectedEnginesByCategory[CategoryKey] := CurrentEngines
    
    ; 【关键修复】参考CAPSLOCK+F的实现：保存到配置文件（持久化记忆用户选择）
    try {
        global ConfigFile
        EnginesStr := ""
        for Index, Eng in SearchCenterSelectedEngines {
            if (Index > 1) {
                EnginesStr .= ","
            }
            EnginesStr .= Eng
        }
        ; 保存格式：分类:引擎1,引擎2
        CategoryEnginesStr := CategoryKey . ":" . EnginesStr
        IniWrite(CategoryEnginesStr, ConfigFile, "Settings", "SearchCenterSelectedEngines_" . CategoryKey)
    } catch as e {
        ; 忽略保存错误，不影响功能
    }
    
    ; CLI 单选后必须重绘全部图标，否则其它 CLI 的勾号仍会残留
    if (CategoryKey = "cli") {
        RefreshSearchCenterEngineIcons()
        return
    }
    
    ; 【优化】只更新当前图标的选中状态，避免重新创建所有图标导致闪烁
    if (IsSet(SearchCenterEngineIcons) && IsObject(SearchCenterEngineIcons)) {
        ; 找到对应的图标对象
        for IconIndex, IconObj in SearchCenterEngineIcons {
            if (IsObject(IconObj) && IconObj.HasProp("Engine") && IconObj.Engine = EngineValue) {
                ; 更新背景按钮颜色
                if (IconObj.HasProp("Bg") && IconObj.Bg != 0) {
                    try {
                        NewBgColor := IsSelected ? UI_Colors.BtnHover : UI_Colors.BtnBg
                        IconObj.Bg.Opt("+Background" . NewBgColor)
                        IconObj.Bg.Redraw()
                    } catch as err {
                        ; 如果更新失败，使用完整刷新
                        RefreshSearchCenterEngineIcons()
                        return
                    }
                }
                
                ; 更新选中标记
                if (IsSelected) {
                    ; 需要显示选中标记
                    if (!IconObj.HasProp("Check") || IconObj.Check = 0) {
                        ; 创建选中标记
                        try {
                            IconButtonX := 0
                            IconButtonY := 0
                            IconButtonSize := 50
                            ; 从背景按钮获取位置
                            if (IconObj.HasProp("Bg") && IconObj.Bg != 0) {
                                IconObj.Bg.GetPos(&IconButtonX, &IconButtonY, &IconButtonSize, &IconButtonSize)
                            }
                            CheckX := IconButtonX + IconButtonSize - 18
                            CheckY := IconButtonY + 2
                            CheckMark := GuiID_SearchCenter.Add("Text", "x" . CheckX . " y" . CheckY . " w16 h16 Center 0x200 cFFFFFF Background" . UI_Colors.BtnPrimary, "✓")
                            CheckMark.SetFont("s12 Bold", "Segoe UI")
                            CheckMark.OnEvent("Click", CreateSearchCenterEngineClickHandler(EngineValue, Index))
                            IconObj.Check := CheckMark
                        } catch as err {
                            ; 如果创建失败，使用完整刷新
                            RefreshSearchCenterEngineIcons()
                            return
                        }
                    }
                } else {
                    ; 需要隐藏选中标记
                    if (IconObj.HasProp("Check") && IconObj.Check != 0) {
                        try {
                            IconObj.Check.Destroy()
                            IconObj.Check := 0
                        } catch as err {
                            ; 如果销毁失败，使用完整刷新
                            RefreshSearchCenterEngineIcons()
                            return
                        }
                    }
                }
                ; 找到并更新后退出循环
                break
            }
        }
    } else {
        ; 如果图标数组不存在，使用完整刷新
        RefreshSearchCenterEngineIcons()
    }
}

; 一键并发打开搜索引擎
OpenSearchGroupEngines() {
    global SearchCenterCurrentGroup, SearchCenterSearchEdit, GuiID_SearchCenter
    global GlobalSearchStatement, SearchCenterDebounceTimer
    
    ; 【并发同步】第一行代码：强制释放 Statement 句柄并关闭窗口
    ; 确保浏览器弹出的瞬间，SQLite 数据库连接已安全归还
    GlobalSearchEngine.ReleaseOldStatement()
    
    ; 取消搜索中心防抖定时器
    if (SearchCenterDebounceTimer != 0) {
        SetTimer(SearchCenterDebounceTimer, 0)
        SearchCenterDebounceTimer := 0
    }
    
    ; 关闭搜索中心窗口（可选，根据需求决定是否关闭）
    ; if (GuiID_SearchCenter != 0) {
    ;     try {
    ;         GuiID_SearchCenter.Destroy()
    ;     } catch as err {
    ;     }
    ; }
    
    ; 搜索组定义
    SearchGroups := [
        {Name: "AI 智搜", Engines: ["DeepSeek", "Claude"], URLs: Map("DeepSeek", "https://chat.deepseek.com/?q={query}", "Claude", "https://claude.ai/chat?q={query}")},
        {Name: "常用搜索", Engines: ["百度", "谷歌"], URLs: Map("百度", "https://www.baidu.com/s?wd={query}", "谷歌", "https://www.google.com/search?q={query}")},
        {Name: "社交媒体", Engines: ["B站", "小红书"], URLs: Map("B站", "https://search.bilibili.com/all?keyword={query}", "小红书", "https://www.xiaohongshu.com/search_result?keyword={query}")}
    ]
    
    ; 获取当前组
    if (SearchCenterCurrentGroup < 0 || SearchCenterCurrentGroup >= SearchGroups.Length)
        return
    
    CurrentGroup := SearchGroups[SearchCenterCurrentGroup + 1]
    if (!GuiID_SearchCenter || GuiID_SearchCenter = 0 || !IsObject(SearchCenterSearchEdit)) {
        return
    }
    Query := SearchCenterSearchEdit.Value
    
    ; 如果查询为空，使用默认查询
    if (Query = "")
        Query := "搜索"
    
    ; 并发打开所有搜索引擎
    for EngineName, URLTemplate in CurrentGroup.URLs {
        ; 替换 URL 中的 {query} 占位符
        URL := StrReplace(URLTemplate, "{query}", EncodeURIComponent(Query))
        try {
            Run(URL)
            Sleep(100)  ; 稍微延迟，避免同时打开太多窗口
        } catch as e {
            OutputDebug("打开搜索引擎失败: " . EngineName . " - " . e.Message)
        }
    }
}

; URL 编码辅助函数
EncodeURIComponent(Str) {
    ; 使用 COM 对象进行 URL 编码（更可靠）
    try {
        ; 创建 ScriptControl 对象进行编码
        Encoded := ""
        Loop Parse, Str {
            Char := A_LoopField
            ; ASCII 字符直接使用
            if (Ord(Char) < 128 && RegExMatch(Char, "[A-Za-z0-9\-_.!~*'()]")) {
                Encoded .= Char
            } else {
                ; 非 ASCII 字符进行 URL 编码
                ; 使用 StrPut 获取 UTF-8 字节
                UTF8Buf := Buffer(StrPut(Char, "UTF-8"))
                StrPut(Char, UTF8Buf, "UTF-8")
                Loop UTF8Buf.Size {
                    Byte := NumGet(UTF8Buf, A_Index - 1, "UChar")
                    Encoded .= "%" . Format("{:02X}", Byte)
                }
            }
        }
        return Encoded
    } catch as err {
        ; 如果编码失败，返回原始字符串（浏览器通常能处理）
        return Str
    }
}



; ===================== 语音模块（中枢 #Include VoiceInputModule）=====================
#Include modules\VoiceInputModule.ahk

; 软件启动后自动拉起 ttyd，确保 Niuma Chat CLI 无需手动执行 1.bat
AutoStartTtydForNiumaChat(*) {
    ttydExe := A_ScriptDir . "\ttyd.exe"
    if !FileExist(ttydExe)
        return

    ; 端口 7681 已监听则不重复拉起
    cmdCheck := 'netstat -ano | findstr /R /C:"":7681 .*LISTENING"" >nul'
    checkCode := RunWait(A_ComSpec . ' /c ' . cmdCheck, , "Hide")
    if (checkCode = 0)
        return

    cmdLine := '"' . ttydExe . '" -W -i 127.0.0.1 -p 7681 cmd.exe'
    try Run(cmdLine, A_ScriptDir, "Hide")
    catch {
    }
}


; 对指定窗口尝试 IMM 中文模式 + 简体键盘布局（WebView 焦点常在子 HWND 上，需多候选）
ApplyChineseIMEConversionToHwnd(RootHwnd) {
    if (!RootHwnd)
        return
    fg := DllCall("user32\GetForegroundWindow", "Ptr")
    candidates := [RootHwnd]
    if (fg && fg != RootHwnd)
        candidates.Push(fg)
    hIMC := 0
    releaseHwnd := RootHwnd
    for _, hwndTry in candidates {
        hIMC := DllCall("imm32\ImmGetContext", "Ptr", hwndTry, "Ptr")
        if (hIMC) {
            releaseHwnd := hwndTry
            break
        }
    }
    if (hIMC) {
        DllCall("imm32\ImmGetConversionStatus", "Ptr", hIMC, "UInt*", &ConversionMode := 0, "UInt*", &SentenceMode := 0)
        ; IME_CMODE_NATIVE：中文输入；并清除 CHARCODE(0x20)，减少符号/编码类异常态
        ConversionMode := (ConversionMode | 0x0001) & ~0x0020
        DllCall("imm32\ImmSetConversionStatus", "Ptr", hIMC, "UInt", ConversionMode, "UInt", SentenceMode)
        DllCall("imm32\ImmReleaseContext", "Ptr", releaseHwnd, "Ptr", hIMC)
    }
    try {
        hKL := DllCall("user32\LoadKeyboardLayout", "Str", "00000804", "UInt", 0x00000001, "Ptr")
        if (hKL)
            PostMessage(0x0050, 0x0001, hKL, , , "ahk_id " . RootHwnd)
    } catch as err {
    }
}

; 切换到中文输入法（用于搜索中心窗口）
SwitchToChineseIMEForSearchCenter(*) {
    try {
        global GuiID_SearchCenter, SearchCenterSearchEdit
        ActiveHwnd := 0
        if (SearchCenter_ShouldUseWebView()) {
            try SCWV_FocusForIME()
            Sleep(100)
            if (IsObject(GuiID_SearchCenter) && GuiID_SearchCenter.HasProp("Hwnd"))
                ActiveHwnd := GuiID_SearchCenter.Hwnd
            if (!ActiveHwnd)
                ActiveHwnd := WinGetID("A")
        } else if (GuiID_SearchCenter && SearchCenterSearchEdit) {
            WinActivate("ahk_id " . GuiID_SearchCenter.Hwnd)
            Sleep(50)
            SearchCenterSearchEdit.Focus()
            Sleep(50)
            ActiveHwnd := GuiID_SearchCenter.Hwnd
        } else {
            ActiveHwnd := WinGetID("A")
        }
        if (!ActiveHwnd)
            return
        ApplyChineseIMEConversionToHwnd(ActiveHwnd)
    } catch as err {
    }
}



; ===================== 脚本退出处理 =====================
; 在脚本退出前关闭数据库连接，确保数据完全写入
ExitFunc(ExitReason, ExitCode) {
    global ClipboardDB
    if (ClipboardDB && ClipboardDB != 0) {
        try {
            ClipboardDB.CloseDB()
        } catch as err {
            ; 忽略关闭错误
        }
    }
    try VK_OnHostExit()
}

; ========== VirtualKeyboard：同进程 Core + 对外 WM_COPYDATA（独立 VK 进程）==========
#Include modules\VirtualKeyboardExecCmd.ahk
#Include modules\VirtualKeyboardCore.ahk
#Include modules\VirtualKeyboardInterop.ahk

; Cursor + CapsLock：动态右键菜单（须在 VirtualKeyboardCore 之后注册）
#HotIf WinActive("ahk_exe Cursor.exe") && GetCapsLockState() && VK_ToolbarLayoutHasContextMenuItems()
RButton:: {
    VK_ShowToolbarLayoutContextMenu()
}
#HotIf

OnExit(ExitFunc)

