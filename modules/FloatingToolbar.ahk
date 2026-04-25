; ======================================================================================================================
; 閹剚璇炲銉ュ徔閺?- WebView2 閸忋劑鍣洪柌宥嗙€悧?; 閻楀牊婀? 2.0.0
; 閸旂喕鍏?
;   - 閺佸瓨娼銉ュ徔閺嶅繒鏁遍崡鏇氶嚋 WebView2 濞撳弶鐓嬮敍宀€绮烘稉鈧挧娑樺触缂?濮楁瑩鍘ら懝?;   - 瀹革箓鏁幏鏍уЗ閺佸鐛ラ妴浣圭泊鏉烆喚缂夐弨淇扁偓浣稿礁闁款喛褰嶉崡?;   - 7 娑擃亜濮涢懗鑺ュ瘻闁筋噯绱伴幖婊呭偍閵嗕浇顔囪ぐ鏇樷偓浣瑰絹缁€楦跨槤閵嗕焦鏌婇幓鎰仛鐠囧秲鈧焦鍩呴崶淇扁偓浣筋啎缂冾喓鈧線鏁惄?;   - 閹兼粎鍌ㄩ幐澶愭尦閺€顖涘瘮闁灏幇鐔风安閸涚厧鎯涢崝銊ф暰閸滃本瀚嬮弨鐐偝缁?; ======================================================================================================================

#Requires AutoHotkey v2.0

; 婢舵碍妯夌粈鍝勬珤閾忔碍瀚欏宀勬桨閸栧懎娲块惄鎺炵礄SM_XVIRTUALSCREEN 76閳?9閿?
ScreenVirtual_GetBounds(&outL, &outT, &outW, &outH) {
    outL := SysGet(76)
    outT := SysGet(77)
    outW := SysGet(78)
    outH := SysGet(79)
}

; ===================== 閸忋劌鐪崣姗€鍣?=====================
global FloatingToolbarGUI := 0
global FloatingToolbarIsVisible := false
global FloatingToolbarWindowX := 0
global FloatingToolbarWindowY := 0
global FloatingToolbarScale := 1.0
global FloatingToolbarMinScale := 0.7
global FloatingToolbarMaxScale := 1.5
global FloatingToolbarCompactDiameter := 52
global FloatingToolbarDragging := false
global FloatingToolbar_DragOriginScreenX := 0
global FloatingToolbar_DragOriginScreenY := 0
global FloatingToolbar_DragOriginWinX := 0
global FloatingToolbar_DragOriginWinY := 0
global FloatingToolbarIsMinimized := false
global FloatingToolbarChatDrawerOpen := false
global FloatingToolbarChatDrawerWidth := 620
global FloatingToolbarChatDrawerHeight := 720
global FloatingToolbarCmdVisibleCount := 7
global FloatingToolbarLastClosedX := 0
global FloatingToolbarLastClosedY := 0
global g_FTB_BlockedCmdIds := Map("ch_t", true, "pqp_capture", true, "ss_menu", true)
global g_FTB_AllowedCmdIds := Map(
    "sc_activate_search", true,
    "qa_clipboard", true,
    "ch_b", true,
    "ftb_scratchpad", true,
    "ftb_screenshot", true,
    "qa_config", true,
    "sys_show_vk", true,
    "ftb_cursor_menu", true
)

global g_FTB_WV2_Ctrl := 0
global g_FTB_WV2 := 0
global g_FTB_WV2_Ready := false
global g_FTB_WV2_FrameReady := false
global g_FTB_PendingSelection := ""
global g_FTB_PendingNiumaCompose := []
global g_FTB_UI_Ready := false
global g_FTB_WaitingUiFinishedReveal := false
global g_FTB_ScreenshotDeferLastTick := 0  ; 闃叉姈锛歐ebView 鐭椂鍙屽彂 postMessage 浼氭帓闃熶袱娆?Deferred锛岄伩鍏嶇浜屾鍐嶈窇瀹屾暣鎴浘鍔╂墜娴佺▼
global g_FTB_WV2_CreateRetry := 0
global g_FTB_DebugOverlayEnabled := true
global g_FTB_CursorIconDataUrl := ""

FTB_Debug(msg, level := "ok") {
    global g_FTB_DebugOverlayEnabled, g_FTB_WV2
    if !g_FTB_DebugOverlayEnabled
        return
    try OutputDebug("[FTBDBG] " . msg)
    catch {
    }
    if !g_FTB_WV2
        return
    try WebView_QueuePayload(g_FTB_WV2, Map("type", "ftb_debug", "msg", String(msg), "level", level, "tick", A_TickCount))
    catch {
    }
}

; ===================== 閺勫墽銇?闂呮劘妫岄幃顒佽癁缁?=====================
; 棣栨/閲嶅缓 WebView 鍚庯細鍏堝叏閫忔槑鍗犱綅锛岀瓑椤甸潰 post UI_FINISHED 鍐嶄笉閫忔槑鏄剧ず锛岄伩鍏嶆湭娓叉煋瀹屽氨闇插嚭榛戠櫧搴曘€?; 闅愯棌鍚庡啀鎵撳紑涓?WebView 浠嶅湪锛氱洿鎺ユ樉绀猴紝涓嶅啀绛夊緟銆?
FloatingToolbar_FinishReveal() {
    global FloatingToolbarGUI, FloatingToolbarIsVisible, FloatingToolbarWindowX, FloatingToolbarWindowY
    global g_FTB_WaitingUiFinishedReveal, g_FTB_WV2, g_FTB_WV2_Ctrl

    if !FloatingToolbarGUI
        return

    g_FTB_WaitingUiFinishedReveal := false
    SetTimer(FloatingToolbar_ForceRevealIfStuck, 0)

    tw := FloatingToolbarCalculateWidth()
    th := FloatingToolbarCalculateHeight()
    try FloatingToolbarGUI.Move(FloatingToolbarWindowX, FloatingToolbarWindowY, tw, th)
    catch {
    }
    ; 首启阶段在屏幕外完成 WebView2 首帧渲染，这里再移动回真实位置并显示。
    try g_FTB_WV2_Ctrl.IsVisible := true
    catch {
    }
    try WinSetTransparent(255, "ahk_id " . FloatingToolbarGUI.Hwnd)
    catch {
    }
    try FloatingToolbarGUI.Show("x" . FloatingToolbarWindowX . " y" . FloatingToolbarWindowY . " w" . tw . " h" . th . " NoActivate")
    catch {
    }

    FloatingToolbarIsVisible := true
    try WebView2_NotifyShown(g_FTB_WV2)
    FloatingToolbarApplyRoundedCorners()
    FloatingToolbar_ApplyWebViewBounds()
    SetTimer(FloatingToolbarCheckWindowPosition, 100)
}

FloatingToolbar_ForceRevealIfStuck() {
    global g_FTB_WaitingUiFinishedReveal, g_FTB_UI_Ready
    if !g_FTB_WaitingUiFinishedReveal
        return
    if !g_FTB_UI_Ready {
        SetTimer(FloatingToolbar_ForceRevealIfStuck, -600)
        return
    }
    OutputDebug("[FTB] UI_FINISHED timeout: force reveal")
    FloatingToolbar_FinishReveal()
}

ShowFloatingToolbar() {
    global FloatingToolbarGUI, FloatingToolbarIsVisible, FloatingToolbarWindowX, FloatingToolbarWindowY
    global g_FTB_UI_Ready, g_FTB_WaitingUiFinishedReveal, g_FTB_WV2_Ready

    if (FloatingToolbarIsVisible && FloatingToolbarGUI != 0) {
        return
    }
    ; 鑻ヤ笂娆′粛鍦ㄣ€岀瓑 UI_FINISHED銆嶏紝鍏堝彇娑堣秴鏃跺畾鏃跺櫒锛岄伩鍏嶉噸澶?reveal
    if (FloatingToolbarGUI != 0 && g_FTB_WaitingUiFinishedReveal) {
        g_FTB_WaitingUiFinishedReveal := false
        SetTimer(FloatingToolbar_ForceRevealIfStuck, 0)
    }

    FloatingToolbarLoadScale()

    if (FloatingToolbarGUI = 0) {
        CreateFloatingToolbarGUI()
    }

    LoadFloatingToolbarPosition()

    if (FloatingToolbarWindowX = 0 && FloatingToolbarWindowY = 0) {
        ScreenVirtual_GetBounds(&vl, &vt, &vw, &vh)
        ToolbarWidth := FloatingToolbarCalculateWidth()
        ToolbarHeight := FloatingToolbarCalculateHeight()
        FloatingToolbarWindowX := vl + vw - ToolbarWidth
        FloatingToolbarWindowY := vt + vh - ToolbarHeight
    }

    ToolbarWidth := FloatingToolbarCalculateWidth()
    ToolbarHeight := FloatingToolbarCalculateHeight()

    readyToReveal := (g_FTB_WV2_Ready && g_FTB_UI_Ready)

    ; WebView 已就绪（隐藏后再次打开）：直接不透明显示，不再等待
    if readyToReveal {
        try WinSetTransparent(255, "ahk_id " . FloatingToolbarGUI.Hwnd)
        catch {
        }
        FloatingToolbarGUI.Show("x" . FloatingToolbarWindowX . " y" . FloatingToolbarWindowY . " w" . ToolbarWidth . " h" . ToolbarHeight . " NoActivate")
        FloatingToolbar_FinishReveal()
        return
    }

    ; 首次加载或重建：先在真实位置创建但保持隐藏，等 HTML 发 UI_FINISHED 后再显示。
    ; 避免屏幕外坐标污染位置状态，也避免 WebView2 首帧白底露出。
    try WinSetTransparent(0, "ahk_id " . FloatingToolbarGUI.Hwnd)
    catch {
    }
    FloatingToolbarGUI.Show("Hide x" . FloatingToolbarWindowX . " y" . FloatingToolbarWindowY . " w" . ToolbarWidth . " h" . ToolbarHeight . " NoActivate")
    g_FTB_WaitingUiFinishedReveal := true
    FloatingToolbarIsVisible := false
    FloatingToolbarApplyRoundedCorners()
    FloatingToolbar_ApplyWebViewBounds()
    SetTimer(FloatingToolbar_ForceRevealIfStuck, 0)
    SetTimer(FloatingToolbar_ForceRevealIfStuck, -4500)
}

HideFloatingToolbar() {
    global FloatingToolbarGUI, FloatingToolbarIsVisible, g_FTB_WaitingUiFinishedReveal, g_FTB_WV2

    if (FloatingToolbarGUI != 0) {
        SaveFloatingToolbarPosition()
        g_FTB_WaitingUiFinishedReveal := false
        SetTimer(FloatingToolbar_ForceRevealIfStuck, 0)
        try WinSetTransparent(255, "ahk_id " . FloatingToolbarGUI.Hwnd)
        catch {
        }
        try WebView2_NotifyHidden(g_FTB_WV2)
        try FloatingToolbarGUI.Hide()
        FloatingToolbarIsVisible := false
        SetTimer(FloatingToolbarCheckWindowPosition, 0)
    }
}

ToggleFloatingToolbar() {
    global FloatingToolbarIsVisible, AppearanceActivationMode, FloatingBubbleIsVisible

    mode := NormalizeAppearanceActivationMode(AppearanceActivationMode)
    if (mode = "bubble") {
        if (FloatingBubbleIsVisible) {
            HideFloatingBubble()
        } else {
            ShowFloatingBubble()
        }
        return
    }
    if (mode = "tray") {
        return
    }

    if (FloatingToolbarIsVisible) {
        HideFloatingToolbar()
    } else {
        ShowFloatingToolbar()
    }
}

; ===================== 閸掓稑缂揋UI =====================
CreateFloatingToolbarGUI() {
    global FloatingToolbarGUI, g_FTB_WV2_Ctrl, g_FTB_WV2, g_FTB_WV2_Ready, g_FTB_PendingSelection
    global g_FTB_UI_Ready, g_FTB_WaitingUiFinishedReveal, g_FTB_WV2_CreateRetry
    global WebView2
    g_FTB_WV2_CreateRetry := 0

    if (FloatingToolbarGUI != 0) {
        g_FTB_WV2_Ctrl := 0
        g_FTB_WV2 := 0
        g_FTB_WV2_Ready := false
        g_FTB_WV2_FrameReady := false
        g_FTB_PendingSelection := ""
        g_FTB_UI_Ready := false
        g_FTB_WaitingUiFinishedReveal := false
        g_FTB_WV2_CreateRetry := 0
        try FloatingToolbarGUI.Destroy()
        catch as _e {
        }
    }

    FloatingToolbarGUI := Gui("+AlwaysOnTop -Caption +ToolWindow -DPIScale +E0x02080000", "Floating Toolbar")
    ; Boot stays dark until the web UI has painted, avoiding light-theme blank frames.
    FloatingToolbarGUI.BackColor := FloatingToolbar_GetBootBackColorHex()
    ; 创建后立即设为完全透明，避免 WebView2 初始化期间闪现白色矩形
    try WinSetTransparent(0, "ahk_id " . FloatingToolbarGUI.Hwnd)
    FloatingToolbarGUI.OnEvent("Close", OnFloatingToolbarClose)
    FloatingToolbarGUI.OnEvent("ContextMenu", OnFloatingToolbarContextMenu)

    OnMessage(0x020A, FloatingToolbarWM_MOUSEWHEEL)

    try {
        WebView2.create(FloatingToolbarGUI.Hwnd, FloatingToolbar_OnWebViewCreated, WebView2_EnsureSharedEnvBlocking())
    } catch as e {
        OutputDebug("[FTB] WebView2.create failed: " . e.Message)
        try TrayTip("悬浮工具栏", "WebView2 创建失败，请确认已安装 Edge WebView2 运行时。", "Iconx 2")
        catch {
        }
    }
}

FloatingToolbar_FlushPendingSelectionIfReady() {
    global g_FTB_WV2, g_FTB_WV2_Ready, g_FTB_WV2_FrameReady, g_FTB_PendingSelection
    if !(g_FTB_WV2 && g_FTB_WV2_Ready && g_FTB_WV2_FrameReady)
        return
    if (g_FTB_PendingSelection = "")
        return
    pv := SubStr(String(g_FTB_PendingSelection), 1, 220)
    try WebView_QueuePayload(g_FTB_WV2, Map("type", "SELECTION_CHANGE", "preview", pv))
    catch as _e {
        return
    }
    g_FTB_PendingSelection := ""
}

FloatingToolbar_FlushPendingNiumaComposeIfReady() {
    global g_FTB_WV2, g_FTB_WV2_Ready, g_FTB_WV2_FrameReady, g_FTB_PendingNiumaCompose
    if !(g_FTB_WV2 && g_FTB_WV2_Ready && g_FTB_WV2_FrameReady)
        return
    if !(g_FTB_PendingNiumaCompose is Array) || (g_FTB_PendingNiumaCompose.Length = 0)
        return
    try {
        for _, payload in g_FTB_PendingNiumaCompose {
            WebView_QueuePayload(g_FTB_WV2, payload)
        }
        g_FTB_PendingNiumaCompose := []
    } catch as _e {
    }
}

FloatingToolbar_OnNavigationStarting(sender, args) {
    global g_FTB_WV2_FrameReady
    g_FTB_WV2_FrameReady := false
}

FloatingToolbar_OnNavigationCompleted(sender, args) {
    global g_FTB_WV2_FrameReady
    ok := false
    try ok := args.IsSuccess
    catch as _e {
        ok := false
    }
    g_FTB_WV2_FrameReady := !!ok
    FloatingToolbar_FlushPendingSelectionIfReady()
    FloatingToolbar_FlushPendingNiumaComposeIfReady()
}

; ===================== 閸﹀棜顫楁潏瑙勵攱婢跺嫮鎮?=====================
; 涓嶅啀浣跨敤 GDI CreateRoundRectRgn 瑁佸壀瀹夸富绐楀彛锛氭暣鏁板儚绱犲渾瑙掓槗浜х敓閿娇锛?; 鍦嗚涓庢弿杈圭敱 WebView 鍐?SVG/CSS 鎶楅敮榻跨粯鍒讹紱瀹夸富淇濇寔鐭╁舰绐楀彛锛孊ackColor 涓庡伐鍏锋爮搴曞悓鑹插嵆鍙€?
FloatingToolbarApplyRoundedCorners() {
    global FloatingToolbarGUI

    if (FloatingToolbarGUI = 0) {
        return
    }

    try DllCall("SetWindowRgn", "Ptr", FloatingToolbarGUI.Hwnd, "Ptr", 0, "Int", 1)
    catch {
    }
}

; ===================== WebView2 閸ョ偠鐨?=====================
FloatingToolbar_OnWebViewCreated(ctrl) {
    global g_FTB_WV2_Ctrl, g_FTB_WV2, g_FTB_WV2_Ready, g_FTB_WV2_FrameReady, g_FTB_WV2_CreateRetry

    if !IsObject(ctrl) || !ctrl.HasProp("CoreWebView2") {
        OutputDebug("[FTB] WebView2 create failed: invalid controller")
        FloatingToolbar_RetryCreateWebView()
        return
    }
    g_FTB_WV2_CreateRetry := 0
    g_FTB_WV2_Ctrl := ctrl
    g_FTB_WV2 := ctrl.CoreWebView2
    g_FTB_WV2_Ready := false
    g_FTB_WV2_FrameReady := false

    ; Keep WebView2's first compositor frame dark; theme color is applied after UI_FINISHED.
    try ctrl.DefaultBackgroundColor := FloatingToolbar_GetBootBackColorArgb()
    try ctrl.IsVisible := true

    FloatingToolbar_ApplyWebViewBounds()

    s := g_FTB_WV2.Settings
    s.AreDefaultContextMenusEnabled := false
    s.AreDevToolsEnabled := false
    ; 避免 Ctrl+1/2/W 等被浏览器加速键先消费，确保 Niuma Chat 内快捷键优先生效
    try s.AreBrowserAcceleratorKeysEnabled := false
    ApplyWebView2PerformanceSettings(g_FTB_WV2)
    WebView2_RegisterHostBridge(g_FTB_WV2)

    g_FTB_WV2.add_NavigationStarting(FloatingToolbar_OnNavigationStarting)
    g_FTB_WV2.add_NavigationCompleted(FloatingToolbar_OnNavigationCompleted)
    g_FTB_WV2.add_WebMessageReceived(FloatingToolbar_OnWebMessage)
    try ApplyUnifiedWebViewAssets(g_FTB_WV2)
    g_FTB_WV2.Navigate(BuildAppLocalUrl("FloatingToolbarStrip.html"))
}

FloatingToolbar_ApplyWebViewBounds() {
    global FloatingToolbarGUI, g_FTB_WV2_Ctrl

    if !(FloatingToolbarGUI && g_FTB_WV2_Ctrl)
        return

    WinGetClientPos(, , &cw, &ch, FloatingToolbarGUI.Hwnd)
    rc := WebView2.RECT()
    rc.left := 0
    rc.top := 0
    rc.right := cw
    rc.bottom := ch
    try {
        g_FTB_WV2_Ctrl.Bounds := rc
        g_FTB_WV2_Ctrl.NotifyParentWindowPositionChanged()
    } catch {
    }
}

FloatingToolbar_RetryCreateWebView() {
    global FloatingToolbarGUI, g_FTB_WV2_CreateRetry
    if !FloatingToolbarGUI
        return
    if (g_FTB_WV2_CreateRetry >= 3)
        return
    g_FTB_WV2_CreateRetry += 1
    SetTimer((*) => WebView2.create(FloatingToolbarGUI.Hwnd, FloatingToolbar_OnWebViewCreated, WebView2_EnsureSharedEnvBlocking()), -200)
}

FloatingToolbar_GetLogoAppUrl() {
    if !IsSet(BuildAppLocalUrl)
        return ""
    candidates := [
        "牛马.png",
        "logo.png",
        "images\logo.png",
        "images\nimabu.png",
        "favicon.ico"
    ]
    for rel in candidates {
        full := A_ScriptDir . "\" . rel
        if FileExist(full) {
            u := StrReplace(rel, "\", "/")
            try return BuildAppLocalUrl(u)
            catch {
                return ""
            }
        }
    }
    return ""
}

FloatingToolbar_PushLogoToWeb(*) {
    global g_FTB_WV2
    if !g_FTB_WV2
        return
    url := FloatingToolbar_GetLogoAppUrl()
    if (url = "")
        return
    try WebView_QueuePayload(g_FTB_WV2, Map("type", "set_logo", "url", url))
    catch as _e {
    }
}

; override 非空时直接使用该模式（与 ApplyTheme/INI 同步顺序无关，避免读 INI 读到旧值）
FloatingToolbar_PushThemeToWeb(override := "") {
    global g_FTB_WV2
    tm := (Trim(String(override)) != "")
        ? FloatingToolbar_NormalizeThemeToken(override, "dark")
        : FloatingToolbar_GetThemeMode()
    FloatingToolbar_ApplyHostThemeColorsForMode(tm)
    if !g_FTB_WV2
        return
    try WebView_QueuePayload(g_FTB_WV2, Map("type", "set_theme", "themeMode", tm))
    catch as _e {
    }
}

FloatingToolbar_GetBootBackColorHex() {
    return "0a0a0a"
}

FloatingToolbar_GetBootBackColorArgb() {
    return 0xFF0A0A0A
}

FloatingToolbar_GetThemeBackColorHex() {
    tm := FloatingToolbar_GetThemeMode()
    return (tm = "light") ? "f7f7f7" : "0a0a0a"
}

FloatingToolbar_GetThemeBackColorArgb() {
    tm := FloatingToolbar_GetThemeMode()
    return (tm = "light") ? 0xFFF7F7F7 : 0xFF0A0A0A
}

FloatingToolbar_ApplyHostThemeColorsForMode(tm) {
    global FloatingToolbarGUI, g_FTB_WV2_Ctrl
    tm2 := FloatingToolbar_NormalizeThemeToken(tm, "dark")
    hex := (tm2 = "light") ? "f7f7f7" : "0a0a0a"
    argb := (tm2 = "light") ? 0xFFF7F7F7 : 0xFF0A0A0A
    try {
        if IsObject(FloatingToolbarGUI)
            FloatingToolbarGUI.BackColor := hex
    } catch {
    }
    try {
        if IsObject(g_FTB_WV2_Ctrl)
            g_FTB_WV2_Ctrl.DefaultBackgroundColor := argb
    } catch {
    }
}

FloatingToolbar_ApplyHostThemeColors() {
    FloatingToolbar_ApplyHostThemeColorsForMode(FloatingToolbar_GetThemeMode())
}

FloatingToolbar_NormalizeThemeToken(raw, fallback := "dark") {
    s := StrLower(Trim(String(raw)))
    if (s = "light" || s = "lite")
        return "light"
    if (s = "dark")
        return "dark"
    return (fallback = "light") ? "light" : "dark"
}

FloatingToolbar_GetThemeMode() {
    ; Prefer direct INI read so theme stays correct even if global state is stale.
    try {
        global ConfigFile
        if (IsSet(ConfigFile) && ConfigFile != "") {
            raw := IniRead(ConfigFile, "Settings", "ThemeMode", "")
            if (Trim(String(raw)) = "")
                raw := IniRead(ConfigFile, "Appearance", "ThemeMode", "")
            if (Trim(String(raw)) != "")
                return FloatingToolbar_NormalizeThemeToken(raw, "dark")
        }
    } catch {
    }
    try {
        fn := Func("ReadPersistedThemeMode")
        if IsObject(fn)
            return FloatingToolbar_NormalizeThemeToken(fn.Call(), "dark")
    } catch {
    }
    try {
        global ThemeMode
        return FloatingToolbar_NormalizeThemeToken(ThemeMode, "dark")
    } catch {
    }
    return "dark"
}

FloatingToolbar_OnWebMessage(sender, args) {
    global g_FTB_WV2, g_FTB_WV2_Ready, g_FTB_WV2_FrameReady, g_FTB_PendingSelection, FloatingToolbarGUI, FloatingToolbarScale

    msg := FloatingToolbar_ParseWebMessage(args)
    if !(msg is Map)
        return

    typ := msg.Has("type") ? String(msg["type"]) : ""
    if (typ != "")
        FTB_Debug("recv " . typ)

    if (typ = "toolbar_ready") {
        g_FTB_WV2_Ready := true
        FloatingToolbar_ApplyWebViewBounds()
        SetTimer(FloatingToolbar_PushLogoToWeb, -10)
        SetTimer(FloatingToolbar_PushThemeToWeb, -10)
        FloatingToolbarPushScaleStateToWeb(FloatingToolbarScale)
        FloatingToolbarPushButtonConfigToWeb()
        FloatingToolbar_FlushPendingSelectionIfReady()
        FloatingToolbar_FlushPendingNiumaComposeIfReady()
        return
    }

    if (typ = "UI_FINISHED") {
        global FloatingToolbarIsVisible, FloatingToolbarWindowX, FloatingToolbarWindowY
        global g_FTB_UI_Ready, g_FTB_WaitingUiFinishedReveal

        if !FloatingToolbarGUI
            return

        g_FTB_UI_Ready := true

        if !g_FTB_WaitingUiFinishedReveal
            return

        ; 涓嶅啀浣跨敤 AnimateWindow(AW_BLEND)锛岄伩鍏嶉粦鐧芥笎鍙橀棯灞忥紱鐢?FloatingToolbar_FinishReveal 涓€娆℃€т笉閫忔槑鏄剧ず
        FloatingToolbar_FinishReveal()
        FloatingToolbar_FlushPendingNiumaComposeIfReady()
        return
    }

    if (typ = "toolbar_action") {
        action := msg.Has("action") ? String(msg["action"]) : ""
        if (action != "")
            FloatingToolbarExecuteButtonAction(action, 0)
        return
    }

    if (typ = "toolbar_cmd") {
        cid := msg.Has("cmdId") ? Trim(String(msg["cmdId"])) : ""
        if (cid != "")
            SetTimer(FloatingToolbar_DeferredToolbarCmd.Bind(cid), -1)
        return
    }

    if (typ = "toolbar_toggle_action") {
        action := msg.Has("action") ? String(msg["action"]) : ""
        FTB_Debug("toggle " . action)
        if (action != "")
            FloatingToolbarToggleButtonAction(action)
        return
    }

    if (typ = "toolbar_search_click") {
        FloatingToolbar_ActivateSearchCenter()
        return
    }

    if (typ = "drop_search") {
        t := msg.Has("text") ? Trim(String(msg["text"])) : ""
        if (t != "") {
            try SearchCenter_RunQueryWithKeyword(t)
            catch {
            }
        }
        if g_FTB_WV2 {
            try {
                WebView_QueuePayload(g_FTB_WV2, Map("type", "drop_done"))
                WebView_QueuePayload(g_FTB_WV2, Map("type", "SELECTION_CLEAR"))
            } catch {
            }
        }
        return
    }

    if (typ = "drop_action") {
        action := msg.Has("action") ? Trim(String(msg["action"])) : "Search"
        t := msg.Has("text") ? Trim(String(msg["text"])) : ""
        if (t != "") {
            try {
                switch action {
                    case "Search":
                        SearchCenter_RunQueryWithKeyword(t)
                    case "Prompt", "NewPrompt", "Record":
                        PromptQuickPad_OpenCaptureDraft(t, true)
                    default:
                        ; 鏈畾涔夎緭鍏ラ潰鏉跨殑鍥炬爣缁熶竴鍥為€€鍒版悳绱腑蹇?                        SearchCenter_RunQueryWithKeyword(t)
                }
            } catch {
            }
        }
        if g_FTB_WV2 {
            try {
                WebView_QueuePayload(g_FTB_WV2, Map("type", "drop_done"))
                WebView_QueuePayload(g_FTB_WV2, Map("type", "SELECTION_CLEAR"))
            } catch {
            }
        }
        return
    }

    if (typ = "drag_host") {
        global FloatingToolbarGUI, FloatingToolbarDragging
        global FloatingToolbar_DragOriginScreenX, FloatingToolbar_DragOriginScreenY
        global FloatingToolbar_DragOriginWinX, FloatingToolbar_DragOriginWinY
        if !FloatingToolbarGUI || FloatingToolbarDragging
            return
        try FloatingToolbarGUI.GetPos(&FloatingToolbar_DragOriginWinX, &FloatingToolbar_DragOriginWinY)
        catch as _e {
            return
        }
        CoordMode("Mouse", "Screen")
        MouseGetPos(&FloatingToolbar_DragOriginScreenX, &FloatingToolbar_DragOriginScreenY)
        FloatingToolbarDragging := true
        SetTimer(FloatingToolbar_DragRun, -1)
        return
    }

    if (typ = "wheel") {
        delta := msg.Has("delta") ? Integer(msg["delta"]) : 0
        if (delta != 0)
            FloatingToolbarApplyWheelDelta(delta)
        return
    }

    if (typ = "exit_compact") {
        FloatingToolbarExitCompactMode()
        return
    }

    if (typ = "context_menu") {
        x := msg.Has("x") ? Integer(msg["x"]) : 0
        y := msg.Has("y") ? Integer(msg["y"]) : 0
        FTB_Debug("context_menu x=" . x . " y=" . y)
        SetTimer(FloatingToolbar_ShowContextMenuDeferred.Bind(x, y), -1)
        return
    }

    if (typ = "toolbar_cmd_context") {
        cid := msg.Has("cmdId") ? Trim(String(msg["cmdId"])) : ""
        if (cid = "ftb_cursor_menu") {
            try FloatingToolbar_ShowCursorQuickMenu()
            catch {
            }
            return
        }
        x := msg.Has("x") ? Integer(msg["x"]) : 0
        y := msg.Has("y") ? Integer(msg["y"]) : 0
        FTB_Debug("toolbar_cmd_context x=" . x . " y=" . y)
        SetTimer(FloatingToolbar_ShowContextMenuDeferred.Bind(x, y), -1)
        return
    }

    if (typ = "drawer_state") {
        open := msg.Has("open") && !!msg["open"]
        FTB_Debug("drawer_state open=" . open)
        FloatingToolbarSetChatDrawerState(open)
        return
    }

    if (typ = "drawer_resize") {
        w := msg.Has("width") ? Integer(msg["width"]) : 0
        if (w > 0)
            FloatingToolbar_ApplyDrawerClientWidth(w)
        return
    }

    if (typ = "drawer_resize_done") {
        FloatingToolbarSaveDrawerWidth()
        SaveFloatingToolbarPosition()
        return
    }
}

; 鎸?WebView 瀹㈡埛鍖?CSS 鍍忕礌瀹藉害璋冩暣鎶藉眽锛堜繚鎸佺獥鍙ｅ彸缂樹笉鍔級
FloatingToolbar_ApplyDrawerClientWidth(clientW) {
    global FloatingToolbarGUI, FloatingToolbarChatDrawerOpen, FloatingToolbarChatDrawerWidth
    global FloatingToolbarScale, FloatingToolbarWindowX, FloatingToolbarWindowY

    if (!FloatingToolbarGUI || !FloatingToolbarChatDrawerOpen)
        return
    sc := FloatingToolbarScale
    if (sc < 0.01)
        sc := 1.0
    logical := Round(clientW / sc)
    if (logical < 380)
        logical := 380
    if (logical > 1200)
        logical := 1200
    FloatingToolbarChatDrawerWidth := logical
    newW := FloatingToolbarCalculateWidth()
    newH := FloatingToolbarCalculateHeight()
    try FloatingToolbarGUI.GetPos(&gx, &gy, &gw, &gh)
    catch as _e {
        gx := FloatingToolbarWindowX
        gy := FloatingToolbarWindowY
        gw := newW
        gh := newH
    }
    rightEdge := gx + gw
    newX := rightEdge - newW
    ScreenVirtual_GetBounds(&vl, &vt, &vw, &vh)
    vr := vl + vw
    if (newX < vl)
        newX := vl
    if (newX + newW > vr)
        newX := vr - newW
    FloatingToolbarWindowX := newX
    try FloatingToolbarGUI.Move(newX, gy, newW, newH)
    catch as _e2 {
    }
    FloatingToolbarApplyRoundedCorners()
    FloatingToolbar_ApplyWebViewBounds()
}

FloatingToolbarSaveDrawerWidth() {
    global FloatingToolbarChatDrawerWidth, ConfigFile
    try {
        if !IsSet(ConfigFile) || ConfigFile = ""
            ConfigFile := A_ScriptDir . "\CursorShortcut.ini"
        IniWrite(String(FloatingToolbarChatDrawerWidth), ConfigFile, "FloatingToolbar", "ChatDrawerWidth")
    } catch as _e {
    }
}

FloatingToolbarLoadDrawerWidth() {
    global FloatingToolbarChatDrawerWidth, ConfigFile
    try {
        if !IsSet(ConfigFile) || ConfigFile = ""
            ConfigFile := A_ScriptDir . "\CursorShortcut.ini"
        v := IniRead(ConfigFile, "FloatingToolbar", "ChatDrawerWidth", "620")
        iv := Integer(v)
        if (iv >= 380 && iv <= 1200)
            FloatingToolbarChatDrawerWidth := iv
    } catch as _e {
    }
}

FloatingToolbarSetChatDrawerState(open) {
    global FloatingToolbarGUI, FloatingToolbarChatDrawerOpen
    global FloatingToolbarWindowX, FloatingToolbarWindowY, FloatingToolbarIsVisible
    global FloatingToolbarLastClosedX, FloatingToolbarLastClosedY

    open := !!open
    ; Do not gate by FloatingToolbarIsVisible: this state flag can lag behind
    ; WebView UI transitions and would block drawer open/close resize.
    if (!FloatingToolbarGUI)
        return

    try FloatingToolbarGUI.GetPos(&oldX, &oldY, &oldW, &oldH)
    catch {
        oldX := FloatingToolbarWindowX
        oldY := FloatingToolbarWindowY
        oldW := FloatingToolbarCalculateWidth()
        oldH := FloatingToolbarCalculateHeight()
    }

    if (open && !FloatingToolbarChatDrawerOpen) {
        FloatingToolbarLastClosedX := oldX
        FloatingToolbarLastClosedY := oldY
    }

    FloatingToolbarChatDrawerOpen := open
    newW := FloatingToolbarCalculateWidth()
    newH := FloatingToolbarCalculateHeight()

    ScreenVirtual_GetBounds(&vl, &vt, &vw, &vh)
    vr := vl + vw
    vb := vt + vh
    rightEdge := oldX + oldW

    if (open) {
        newX := rightEdge - newW
        newY := vt
    } else {
        if (FloatingToolbarLastClosedX != 0 || FloatingToolbarLastClosedY != 0) {
            newX := FloatingToolbarLastClosedX
            newY := FloatingToolbarLastClosedY
        } else {
            newX := rightEdge - newW
            newY := vb - newH
        }
    }

    if (newX < vl)
        newX := vl
    if (newY < vt)
        newY := vt
    if (newX + newW > vr)
        newX := vr - newW
    if (newY + newH > vb)
        newY := vb - newH

    FloatingToolbarWindowX := newX
    FloatingToolbarWindowY := newY
    FloatingToolbarGUI.Move(newX, newY, newW, newH)
    FloatingToolbarApplyRoundedCorners()
    FloatingToolbar_ApplyWebViewBounds()
    FloatingToolbarPushScaleStateToWeb(FloatingToolbarScale)
    SaveFloatingToolbarPosition()
}

FloatingToolbarCollapseTransientUi(forceResize := true) {
    global g_FTB_WV2, FloatingToolbarGUI, FloatingToolbarChatDrawerOpen

    if (FloatingToolbarChatDrawerOpen) {
        try FloatingToolbarSetChatDrawerState(false)
    } else if (forceResize && IsObject(FloatingToolbarGUI)) {
        try {
            newW := FloatingToolbarCalculateWidth()
            newH := FloatingToolbarCalculateHeight()
            FloatingToolbarGUI.GetPos(&gx, &gy, &gw, &gh)
            FloatingToolbarGUI.Move(gx, gy, newW, newH)
            FloatingToolbarApplyRoundedCorners()
            FloatingToolbar_ApplyWebViewBounds()
        } catch {
        }
    }

    if g_FTB_WV2 {
        try WebView_QueuePayload(g_FTB_WV2, Map("type", "host_force_toolbar_home"))
        catch {
        }
    }
}

; ===================== 閹笛嗩攽閹稿鎸抽崝銊ょ稊 =====================
; WebView2 回调须尽快返回；ExecuteScreenshotWithMenu 含 Sleep/剪贴板轮询。
; 在回调内同步调用会阻塞 WebView 消息泵，导致工具栏卡死且截图助手无法弹出。
FloatingToolbar_DeferredScreenshot(*) {
    global FloatingToolbarIsVisible, FloatingToolbar_ScheduleRestoreAfterScreenshot, g_ExecuteScreenshotWithMenuBusy
    global g_FTB_ScreenshotDeferLastTick

    ; 防抖：同一操作 1500ms 内只接受一次（截图流程耗时长，完成后也需防重复触发）
    if (g_FTB_ScreenshotDeferLastTick && (A_TickCount - g_FTB_ScreenshotDeferLastTick < 1500))
        return
    g_FTB_ScreenshotDeferLastTick := A_TickCount

    prevCrit := Critical("On")
    if (g_ExecuteScreenshotWithMenuBusy) {
        Critical(prevCrit)
        return
    }
    g_ExecuteScreenshotWithMenuBusy := true
    Critical(prevCrit)

    wasVisible := !!FloatingToolbarIsVisible
    FloatingToolbar_ScheduleRestoreAfterScreenshot := wasVisible

    try {
        if (wasVisible) {
            HideFloatingToolbar()
            Sleep(120)
        }
        ExecuteScreenshotWithMenu(true)
        ; 截图流程完成后刷新防抖时间戳，阻止后续 1.5 秒内的重复触发
        g_FTB_ScreenshotDeferLastTick := A_TickCount
    } catch as err {
        ; Hide/Sleep 鍦?ExecuteScreenshotWithMenu 涔嬪墠澶辫触鏃讹紝棰勫崰鐨?busy 涓嶄細鐢卞悗鑰?finally 娓呴櫎
        g_ExecuteScreenshotWithMenuBusy := false
        try OutputDebug("[FloatingToolbar] DeferredScreenshot: " . err.Message)
        catch {
        }
    }
    ; 悬浮条在 ExecuteScreenshotWithMenu 内剪贴板就绪后、ShowScreenshotEditor 前统一恢复，避免 finally 再延迟 Show 造成双重显示与位移
}

FloatingToolbar_EnsureSearchCenterFocused(*) {
    global GuiID_SearchCenter

    try {
        hwnd := 0
        if (IsSet(SCWV_GetGuiHwnd))
            hwnd := SCWV_GetGuiHwnd()
        if (!hwnd && GuiID_SearchCenter && IsObject(GuiID_SearchCenter) && GuiID_SearchCenter.HasProp("Hwnd"))
            hwnd := GuiID_SearchCenter.Hwnd
        if !hwnd
            return
        WinActivate("ahk_id " . hwnd)
    } catch {
    }

    try {
        if (IsSet(SCWV_RequestFocusInput))
            SCWV_RequestFocusInput()
    } catch {
    }
}

FloatingToolbar_ActivateSearchCenter() {
    selectedText := ""
    opened := false
    usedWebView := false

    try usedWebView := SearchCenter_ShouldUseWebView()
    try FloatingToolbarCollapseTransientUi()

    ; 与 CapsLock+F/拖放入口统一：有选中文本时直接带词打开，否则走搜索中心显示链路
    try selectedText := Trim(String(SelectionSense_GetLastSelectedText()))
    catch {
        selectedText := ""
    }

    try {
        if (selectedText != "")
            SearchCenter_RunQueryWithKeyword(selectedText)
        else if (usedWebView) {
            SCWV_Init()
            SCWV_Show()
        } else
            ShowSearchCenter()
        opened := true
    } catch {
    }

    ; 鍏滃簳閲嶅缓锛氶伩鍏?g_SCWV_Visible / 瀹夸富鍙ユ焺娈嬬暀瀵艰嚧鈥滃垽瀹氬凡寮€浣嗛潰鏉挎病鍑烘潵鈥濄€?
    if (!opened && usedWebView) {
        try {
            SCWV_ResetHostState()
            SCWV_Init()
            SCWV_Show()
            opened := true
        } catch {
        }
    }

    if (!opened) {
        try ShowSearchCenter()
        catch {
        }
    }

    ; 涓嶈鍏ュ彛鏉ヨ嚜鍥炬爣杩樻槸鍙抽敭鑿滃崟锛屾渶鍚庨兘鍐嶅己鍒朵竴娆″彲瑙佷笌杈撳叆鐒︾偣銆?
    if (usedWebView) {
        try {
            if (!SCWV_IsVisible())
                SCWV_Show()
        } catch {
            try {
                SCWV_ResetHostState()
                SCWV_Init()
                SCWV_Show()
            } catch {
            }
        }
        try {
            SCWV_RequestFocusInput()
        } catch {
        }
    }

    ; 宸ュ叿鏍忕偣鍑诲悗鍓嶅彴鍙兘浠嶇煭鏆傚仠鍦ㄥ伐鍏锋爮 WebView锛屼笂涓€涓縺娲婚摼浼氬悶鎺夌劍鐐癸紱琛ュ嚑娆＄‘淇濇悳绱腑蹇冪湡姝ｆ嬁鍒拌緭鍏ョ劍鐐广€?
    SetTimer(FloatingToolbar_EnsureSearchCenterFocused, -20)
    SetTimer(FloatingToolbar_EnsureSearchCenterFocused, -120)
    SetTimer(FloatingToolbar_EnsureSearchCenterFocused, -320)
}

FloatingToolbarExecuteButtonAction(action, buttonHwnd) {
    switch action {
        case "Search":
            FloatingToolbar_ActivateSearchCenter()
        case "Record":
            ; 剪贴板：WebView2 + ClipMain/FTS5 等，失败时提示
            try CP_Show()
            catch as err {
                try TrayTip("剪贴板", "无法显示 WebView 剪贴板: " . err.Message, "Iconx 1")
                catch {
                    OutputDebug("[FloatingToolbar] CP_Show failed: " . err.Message)
                }
            }
        case "AIAssistant", "Prompt":
            try ShowPromptQuickPadListOnly()
            catch as err {
                TrayTip("AI 快捷面板: " . err.Message, "错误", "Iconx 2")
            }
        case "PromptNew", "NewPrompt":
            try SelectionSense_OpenHubCapsuleFromToolbar()
            catch as err {
                try TrayTip("Unable to open HubCapsule (SelectionSenseCore.ahk is required): " . err.Message, "Error", "Iconx 2")
                catch {
                }
            }
        case "Screenshot":
            ; 不可在 WebView2 WebMessageReceived 回调里同步执行 ExecuteScreenshotWithMenu
            ; 含长时间 Sleep/剪贴板轮询会阻塞消息泵，导致工具栏卡死且截图窗口无法显示
            SetTimer(FloatingToolbar_DeferredScreenshot, -1)
        case "Settings":
            FloatingToolbarOpenSettings()
        case "VirtualKeyboard":
            FloatingToolbarActivateVirtualKeyboard()
    }
}

; 延后一帧处理搜索切换：让 WM_ACTIVATE / 延迟 Hide 与 postMessage 顺序稳定，避免先关后立又弹回
FloatingToolbar_SearchToggleDeferred(*) {
    global GuiID_SearchCenter
    try {
        h := SCWV_GetGuiHwnd()
        if (h && WinExist("ahk_id " . h) && (WinGetStyle("ahk_id " . h) & 0x10000000)) {
            SCWV_Hide(true)
            return
        }
    } catch {
    }
    try {
        if (SCWV_IsVisible()) {
            SCWV_Hide(true)
            return
        }
    } catch {
    }
    try {
        if (GuiID_SearchCenter != 0 && (!IsSet(SearchCenter_ShouldUseWebView) || !SearchCenter_ShouldUseWebView())) {
            SearchCenterCloseHandler()
            return
        }
    } catch {
    }
    FloatingToolbarExecuteButtonAction("Search", 0)
}

FloatingToolbar_PromptToggleDeferred(*) {
    global g_PQP_Gui
    try {
        if (g_PQP_Gui && WinExist("ahk_id " . g_PQP_Gui.Hwnd) && (WinGetStyle("ahk_id " . g_PQP_Gui.Hwnd) & 0x10000000)) {
            PQP_Hide()
            return
        }
    } catch {
    }
    try {
        if (PQP_IsVisible()) {
            PQP_Hide()
            return
        }
    } catch {
    }
    FloatingToolbarExecuteButtonAction("Prompt", 0)
}

FloatingToolbarToggleButtonAction(action) {
    global GuiID_SearchCenter, GuiID_ConfigGUI, ConfigWebViewMode, GuiID_ScreenshotEditor, g_PQP_Gui
    switch action {
        case "Search":
            SetTimer(FloatingToolbar_ActivateSearchCenter, -1)
            return
        case "Record":
            try {
                if (IsSet(g_CP_Visible) && g_CP_Visible) {
                    CP_Hide()
                    return
                }
            } catch {
            }
            FloatingToolbarExecuteButtonAction(action, 0)
        case "AIAssistant", "Prompt":
            ; 延后一帧：与 WM_ACTIVATE、Hide/postMessage 顺序对齐，减少关不掉或关掉又弹回
            SetTimer(FloatingToolbar_PromptToggleDeferred, -1)
            return
        case "Settings":
            ; WebView 璁剧疆锛氬叧闂椂浠?Hide锛孏uiID_ConfigGUI 浠嶉潪 0锛屽繀椤绘寜銆屾槸鍚﹀彲瑙併€嶅垏鎹紝鍚﹀垯浼氭棤娉曞啀娆℃墦寮€
            try {
                if (GuiID_ConfigGUI != 0) {
                    cfgVisible := false
                    if (ConfigWebViewMode) {
                        try cfgVisible := ConfigWebView_HostWindowVisible()
                        catch {
                            cfgVisible := false
                        }
                    } else {
                        try {
                            cfgVisible := WinExist("ahk_id " . GuiID_ConfigGUI.Hwnd)
                                && (WinGetStyle("ahk_id " . GuiID_ConfigGUI.Hwnd) & 0x10000000)
                        } catch {
                            cfgVisible := false
                        }
                    }
                    if (cfgVisible) {
                        CloseConfigGUI()
                        return
                    }
                }
            } catch {
            }
            FloatingToolbarExecuteButtonAction(action, 0)
        case "NewPrompt":
            try {
                if (IsSet(SelectionSense_HubCapsuleHostIsOpen) && SelectionSense_HubCapsuleHostIsOpen()) {
                    SelectionSense_HideMenu()
                    return
                }
            } catch {
            }
            FloatingToolbarExecuteButtonAction(action, 0)
        case "Screenshot":
            try {
                if (IsObject(GuiID_ScreenshotEditor)) {
                    CloseScreenshotEditor()
                    return
                }
            } catch {
            }
            FloatingToolbarExecuteButtonAction(action, 0)
        case "VirtualKeyboard":
            ; VK_ToggleEmbedded 依赖可见性；失焦自动 Hide 后需与 VK_IsHostVisible 一致，见 VirtualKeyboardCore
            try {
                if (VK_IsHostVisible()) {
                    VK_Hide()
                    return
                }
            } catch {
            }
            try {
                VK_ToggleEmbedded()
            } catch as err {
                try TrayTip("虚拟键盘不可用: " . err.Message, "虚拟键盘", "Iconx 2")
                catch {
                }
            }
        default:
            FloatingToolbarExecuteButtonAction(action, 0)
    }
}

; 前台 HWND 是否为悬浮工具栏或其子窗口（点工具栏内 WebView 时 WinGetID("A") 常不是宿主 Hwnd）
FloatingToolbar_IsForegroundToolbarOrChild() {
    global FloatingToolbarGUI
    if !FloatingToolbarGUI
        return false
    fg := 0
    try fg := WinGetID("A")
    catch {
        return false
    }
    tb := FloatingToolbarGUI.Hwnd
    hw := fg
    Loop 40 {
        if (hw = tb)
            return true
        np := DllCall("user32\GetParent", "Ptr", hw, "Ptr")
        if !np
            break
        hw := np
    }
    return false
}

FloatingToolbarActivateVirtualKeyboard() {
    try VK_ToggleEmbedded()
    catch as err {
        try TrayTip("閾忔碍瀚欓柨顔炬磸娑撳秴褰查悽? " . err.Message, "閾忔碍瀚欓柨顔炬磸", "Iconx 2")
        catch {
        }
    }
}

FloatingToolbarOpenSettings() {
    try {
        if IsSet(ShowConfigWebViewGUI) {
            ShowConfigWebViewGUI()
            return
        }
    } catch {
    }
    try {
        if IsSet(ShowConfigGUI) {
            ShowConfigGUI()
            return
        }
    } catch {
    }
    try {
        SetCapsLockState("AlwaysOff")
        Send("{CapsLock down}")
        Sleep(30)
        Send("q")
        Sleep(30)
        Send("{CapsLock up}")
        SetCapsLockState("Off")
    } catch {
    }
}

; ===================== 濠婃俺鐤嗙紓鈺傛杹婢跺嫮鎮?=====================
FloatingToolbarWM_MOUSEWHEEL(wParam, lParam, msg, hwnd) {
    global FloatingToolbarGUI, FloatingToolbarIsVisible, FloatingToolbarChatDrawerOpen

    if (!FloatingToolbarIsVisible || !IsObject(FloatingToolbarGUI) || !(FloatingToolbarGUI is Gui))
        return
    ; 鎶藉眽灞曞紑鏃剁敱椤甸潰鍐呮粴鍔紝涓嶅湪姝ょ敤婊氳疆缂╂斁鏁寸獥
    if (FloatingToolbarChatDrawerOpen)
        return

    MouseGetPos(&mx, &my)
    try FloatingToolbarGUI.GetPos(&wx, &wy, &ww, &wh)
    catch {
        return
    }
    if (mx < wx || mx > wx + ww || my < wy || my > wy + wh)
        return

    wheelDelta := (wParam >> 16) & 0xFFFF
    if (wheelDelta > 0x7FFF)
        wheelDelta := wheelDelta - 0x10000

    delta := wheelDelta > 0 ? 1 : -1
    FloatingToolbarApplyWheelDelta(delta)

    return 0
}

FloatingToolbarApplyWheelDelta(delta) {
    global FloatingToolbarGUI, FloatingToolbarScale, FloatingToolbarMinScale, FloatingToolbarMaxScale
    global FloatingToolbarWindowX, FloatingToolbarWindowY, g_FTB_WV2

    ; 必须与 CreateFloatingToolbarGUI 创建的 Gui 一致；勿与他处同名全局混用，否则此处可能得到 Integer 而非 Gui
    if !IsObject(FloatingToolbarGUI) || !(FloatingToolbarGUI is Gui)
        return

    scaleStep := 0.15
    newScale := FloatingToolbarScale

    if (delta > 0) {
        newScale := FloatingToolbarScale + scaleStep
        if (newScale > FloatingToolbarMaxScale)
            newScale := FloatingToolbarMaxScale
    } else {
        newScale := FloatingToolbarScale - scaleStep
        if (newScale < FloatingToolbarMinScale)
            newScale := FloatingToolbarMinScale
    }

    if (newScale != FloatingToolbarScale) {
        FloatingToolbarGUI.GetPos(&oldX, &oldY, &oldWidth, &oldHeight)
        MouseGetPos(&mouseScreenX, &mouseScreenY)
        mouseRelX := mouseScreenX - oldX
        mouseRelY := mouseScreenY - oldY
        mouseRatioX := oldWidth > 0 ? mouseRelX / oldWidth : 0.5
        mouseRatioY := oldHeight > 0 ? mouseRelY / oldHeight : 0.5

        FloatingToolbarScale := newScale

        ToolbarWidth := FloatingToolbarCalculateWidth()
        ToolbarHeight := FloatingToolbarCalculateHeight()

        newX := mouseScreenX - Round(mouseRatioX * ToolbarWidth)
        newY := mouseScreenY - Round(mouseRatioY * ToolbarHeight)

        ScreenVirtual_GetBounds(&vl, &vt, &vw, &vh)
        vr := vl + vw
        vb := vt + vh
        if (newX < vl)
            newX := vl
        if (newY < vt)
            newY := vt
        if (newX + ToolbarWidth > vr)
            newX := vr - ToolbarWidth
        if (newY + ToolbarHeight > vb)
            newY := vb - ToolbarHeight

        FloatingToolbarWindowX := newX
        FloatingToolbarWindowY := newY

        FloatingToolbarGUI.Move(newX, newY, ToolbarWidth, ToolbarHeight)
        FloatingToolbarApplyRoundedCorners()
        FloatingToolbar_ApplyWebViewBounds()

        FloatingToolbarPushScaleStateToWeb(newScale)

        FloatingToolbarSaveScale()
        SaveFloatingToolbarPosition()
    }
}

; ===================== 鎷栧姩锛圵ebView2 鍐?PostMessage HTCAPTION 涓嶅彲闈狅紝鐢ㄦ墜鍔?Move锛涘悓姝ュ惊鐜瘮 1ms 瀹氭椂鍣ㄦ洿璺熸墜锛?===================
FloatingToolbar_DragRun(*) {
    global FloatingToolbarGUI, FloatingToolbarDragging, FloatingToolbarWindowX, FloatingToolbarWindowY
    global FloatingToolbar_DragOriginScreenX, FloatingToolbar_DragOriginScreenY
    global FloatingToolbar_DragOriginWinX, FloatingToolbar_DragOriginWinY

    if !(FloatingToolbarGUI && FloatingToolbarDragging)
        return
    try {
        ToolbarWidth := FloatingToolbarCalculateWidth()
        ToolbarHeight := FloatingToolbarCalculateHeight()
        ScreenVirtual_GetBounds(&vl, &vt, &vw, &vh)
        vr := vl + vw
        vb := vt + vh
        lastX := FloatingToolbarWindowX
        lastY := FloatingToolbarWindowY
        while GetKeyState("LButton", "P") {
            CoordMode("Mouse", "Screen")
            MouseGetPos(&mx, &my)
            newX := FloatingToolbar_DragOriginWinX + (mx - FloatingToolbar_DragOriginScreenX)
            newY := FloatingToolbar_DragOriginWinY + (my - FloatingToolbar_DragOriginScreenY)
            if (newX < vl)
                newX := vl
            if (newY < vt)
                newY := vt
            if (newX + ToolbarWidth > vr)
                newX := vr - ToolbarWidth
            if (newY + ToolbarHeight > vb)
                newY := vb - ToolbarHeight
            if (newX != lastX || newY != lastY) {
                try FloatingToolbarGUI.Move(newX, newY)
                lastX := newX
                lastY := newY
                FloatingToolbarWindowX := newX
                FloatingToolbarWindowY := newY
            }
        }
    } catch {
    }
    FloatingToolbarDragging := false
    FloatingToolbarCheckWindowPosition()
    SaveFloatingToolbarPosition()
}

; ===================== 缁愭褰涙担宥囩枂濡偓閺屻儰绗岀壕浣告儧 =====================
FloatingToolbarCheckWindowPosition() {
    global FloatingToolbarGUI, FloatingToolbarWindowX, FloatingToolbarWindowY, FloatingToolbarDragging, FloatingToolbarIsVisible

    if (!FloatingToolbarIsVisible || FloatingToolbarGUI = 0)
        return

    if (FloatingToolbarDragging)
        return

    if (!GetKeyState("LButton", "P")) {
        try {
            FloatingToolbarGUI.GetPos(&newX, &newY)
            FloatingToolbarWindowX := newX
            FloatingToolbarWindowY := newY

            ScreenVirtual_GetBounds(&vl, &vt, &vw, &vh)
            vr := vl + vw
            vb := vt + vh
            adjustedX := newX
            adjustedY := newY

            snapDistance := 30
            windowWidth := FloatingToolbarCalculateWidth()
            windowHeight := FloatingToolbarCalculateHeight()

            if (adjustedX < vl + snapDistance)
                adjustedX := vl
            else if (adjustedX + windowWidth > vr - snapDistance)
                adjustedX := vr - windowWidth

            if (adjustedY < vt + snapDistance)
                adjustedY := vt
            else if (adjustedY + windowHeight > vb - snapDistance)
                adjustedY := vb - windowHeight

            if (adjustedX < vl)
                adjustedX := vl
            if (adjustedY < vt)
                adjustedY := vt
            if (adjustedX + windowWidth > vr)
                adjustedX := vr - windowWidth
            if (adjustedY + windowHeight > vb)
                adjustedY := vb - windowHeight

            if (adjustedX != newX || adjustedY != newY) {
                FloatingToolbarGUI.Move(adjustedX, adjustedY)
                FloatingToolbarWindowX := adjustedX
                FloatingToolbarWindowY := adjustedY
            }

            SaveFloatingToolbarPosition()
            FloatingToolbar_ApplyWebViewBounds()
        } catch {
        }
    }
}

; 閸欐娊鏁懣婊冨礋閻㈠彉瀵岄懘姘拱 ShowFloatingToolbarUnifiedContextMenu 閹绘劒绶甸敍鍫熺箒閼规彃鑴婄粣妤佺壉瀵骏绱氶敍宀勪缉閸忓秳绗?#Include 閸愯尙鐛婇妴?
FloatingToolbarResetScale() {
    global FloatingToolbarScale, FloatingToolbarGUI, FloatingToolbarWindowX, FloatingToolbarWindowY, g_FTB_WV2

    FloatingToolbarScale := 1.0
    ToolbarWidth := FloatingToolbarCalculateWidth()
    ToolbarHeight := FloatingToolbarCalculateHeight()

    FloatingToolbarGUI.Move(FloatingToolbarWindowX, FloatingToolbarWindowY, ToolbarWidth, ToolbarHeight)
    FloatingToolbarApplyRoundedCorners()
    FloatingToolbar_ApplyWebViewBounds()

    FloatingToolbarPushScaleStateToWeb(1.0)

    FloatingToolbarSaveScale()
    SaveFloatingToolbarPosition()
}

OnFloatingToolbarContextMenu(*) {
    CoordMode("Mouse", "Screen")
    MouseGetPos(&mx, &my)
    SetTimer(FloatingToolbar_ShowContextMenuDeferred.Bind(mx, my), -1)
}

FloatingToolbar_ParseWebMessage(args) {
    ; 1) Preferred path for postMessage(string): raw payload without extra JSON wrapper.
    try {
        raw := args.TryGetWebMessageAsString()
        if (raw != "") {
            try {
                m := Jxon_Load(raw)
                if (m is Map)
                    return m
            } catch {
            }
        }
    } catch {
    }

    ; 2) Fallback path for postMessage(object): JSON value from WebMessageAsJson.
    try {
        jsonStr := args.WebMessageAsJson
        m := Jxon_Load(jsonStr)
        if (m is String)
            m := Jxon_Load(m)
        if (m is Map)
            return m
    } catch {
    }

    FTB_Debug("web message parse failed", "err")
    return 0
}

FloatingToolbar_ShowContextMenuDeferred(anchorX := 0, anchorY := 0) {
    if (anchorX <= 0 || anchorY <= 0) {
        CoordMode("Mouse", "Screen")
        MouseGetPos(&anchorX, &anchorY)
    }
    FTB_Debug("show menu @" . anchorX . "," . anchorY)
    try ShowFloatingToolbarUnifiedContextMenu(anchorX, anchorY)
    catch as err {
        FTB_Debug("show menu failed: " . err.Message, "err")
    }
}

; ===================== 缁愭褰涢崗鎶芥４娴滃娆?=====================
OnFloatingToolbarClose(*) {
    HideFloatingToolbar()
}

; ===================== 娴ｅ秶鐤嗘穱婵嗙摠閸滃苯濮炴潪?=====================
SaveFloatingToolbarPosition() {
    global FloatingToolbarGUI, FloatingToolbarWindowX, FloatingToolbarWindowY
    global FloatingToolbarChatDrawerOpen, FloatingToolbarLastClosedX, FloatingToolbarLastClosedY

    if (FloatingToolbarGUI = 0)
        return

    try {
        if (FloatingToolbarChatDrawerOpen && (FloatingToolbarLastClosedX != 0 || FloatingToolbarLastClosedY != 0)) {
            x := FloatingToolbarLastClosedX
            y := FloatingToolbarLastClosedY
        } else {
            FloatingToolbarGUI.GetPos(&x, &y)
        }
        FloatingToolbarWindowX := x
        FloatingToolbarWindowY := y

        ConfigFile := A_ScriptDir . "\CursorShortcut.ini"
        IniWrite(String(x), ConfigFile, "WindowPositions", "FloatingToolbar_X")
        IniWrite(String(y), ConfigFile, "WindowPositions", "FloatingToolbar_Y")
    } catch {
    }
}

LoadFloatingToolbarPosition() {
    global FloatingToolbarWindowX, FloatingToolbarWindowY

    try {
        ConfigFile := A_ScriptDir . "\CursorShortcut.ini"
        savedX := IniRead(ConfigFile, "WindowPositions", "FloatingToolbar_X", "")
        savedY := IniRead(ConfigFile, "WindowPositions", "FloatingToolbar_Y", "")

        if (savedX != "" && savedY != "" && savedX != "ERROR" && savedY != "ERROR") {
            FloatingToolbarWindowX := Integer(savedX)
            FloatingToolbarWindowY := Integer(savedY)

            ScreenVirtual_GetBounds(&vl, &vt, &vw, &vh)
            vr := vl + vw
            vb := vt + vh
            ToolbarWidth := FloatingToolbarCalculateWidth()
            ToolbarHeight := FloatingToolbarCalculateHeight()

            if (FloatingToolbarWindowX < vl || FloatingToolbarWindowX > vr - ToolbarWidth)
                FloatingToolbarWindowX := vr - ToolbarWidth
            if (FloatingToolbarWindowY < vt || FloatingToolbarWindowY > vb - ToolbarHeight)
                FloatingToolbarWindowY := vb - ToolbarHeight
        }
    } catch {
        FloatingToolbarWindowX := 0
        FloatingToolbarWindowY := 0
    }
}

; ===================== 缂傗晜鏂佹穱婵嗙摠閸滃苯濮炴潪?=====================
FloatingToolbarSaveScale() {
    global FloatingToolbarScale
    try {
        ConfigFile := A_ScriptDir . "\CursorShortcut.ini"
        IniWrite(String(FloatingToolbarScale), ConfigFile, "FloatingToolbar", "Scale")
    } catch {
    }
}

FloatingToolbarLoadScale() {
    global FloatingToolbarScale, FloatingToolbarMinScale, FloatingToolbarMaxScale
    try {
        ConfigFile := A_ScriptDir . "\CursorShortcut.ini"
        savedScale := IniRead(ConfigFile, "FloatingToolbar", "Scale", "1.0")
        if (savedScale != "" && savedScale != "ERROR") {
            scaleValue := Float(savedScale)
            if (scaleValue >= FloatingToolbarMinScale && scaleValue <= FloatingToolbarMaxScale)
                FloatingToolbarScale := scaleValue
        }
    } catch {
    }
    FloatingToolbarLoadDrawerWidth()
}

FloatingToolbarIsCompactMode(scaleValue := "") {
    global FloatingToolbarScale, FloatingToolbarMinScale, FloatingToolbarChatDrawerOpen
    sc := (scaleValue = "") ? FloatingToolbarScale : Float(scaleValue)
    if FloatingToolbarChatDrawerOpen
        return false
    return (sc <= (FloatingToolbarMinScale + 0.0001))
}

FloatingToolbarPushScaleStateToWeb(scaleValue := "") {
    global g_FTB_WV2, FloatingToolbarScale
    if !g_FTB_WV2
        return
    sc := (scaleValue = "") ? FloatingToolbarScale : Float(scaleValue)
    compact := FloatingToolbarIsCompactMode(sc)
    try WebView_QueuePayload(g_FTB_WV2, Map("type", "set_scale", "scale", sc, "compact", compact))
    catch as _e {
    }
}

FloatingToolbar_DeferredToolbarCmd(cmdId) {
    c := String(cmdId)
    ; 命令工具栏与面板类入口统一走 toggle，保证同一按钮可显可隐
    if (c = "sc_activate_search") {
        FloatingToolbarToggleButtonAction("Search")
        return
    }
    if (c = "qa_clipboard") {
        FloatingToolbarToggleButtonAction("Record")
        return
    }
    if (c = "ch_b" || c = "qa_batch") {
        FloatingToolbarToggleButtonAction("Prompt")
        return
    }
    if (c = "ftb_scratchpad" || c = "hub_capsule") {
        FloatingToolbarToggleButtonAction("NewPrompt")
        return
    }
    if (c = "ftb_screenshot" || c = "ch_t") {
        FloatingToolbarToggleButtonAction("Screenshot")
        return
    }
    if (c = "qa_config") {
        FloatingToolbarToggleButtonAction("Settings")
        return
    }
    if (c = "sys_show_vk") {
        FloatingToolbarToggleButtonAction("VirtualKeyboard")
        return
    }
    if (c = "ftb_cursor_menu") {
        FloatingToolbar_ShowCursorQuickMenu()
        return
    }
    try {
        _ExecuteCommand(c)
    } catch as e {
        try OutputDebug("[FloatingToolbar] toolbar_cmd: " . e.Message)
        catch {
        }
    }
}

FloatingToolbarPushCmdLayoutToWeb() {
    global g_FTB_WV2, g_Commands, FloatingToolbarCmdVisibleCount, FloatingToolbarChatDrawerOpen, g_FTB_BlockedCmdIds, g_FTB_AllowedCmdIds
    if !g_FTB_WV2
        return
    try {
        if (!IsSet(g_Commands) || !(g_Commands is Map) || !g_Commands.Has("CommandList") || !(g_Commands["CommandList"] is Map)
            || g_Commands["CommandList"].Count = 0)
            _LoadCommands()
    } catch {
    }
    try {
        if (IsSet(_VK_EnsureToolbarLayout) && IsSet(g_Commands) && g_Commands is Map && g_Commands.Has("CommandList"))
            _VK_EnsureToolbarLayout()
    } catch {
    }
    if !(IsSet(g_Commands) && g_Commands is Map && g_Commands.Has("ToolbarLayout") && g_Commands["ToolbarLayout"] is Array
        && g_Commands.Has("CommandList") && g_Commands["CommandList"] is Map)
        return
    cmdList := g_Commands["CommandList"]
    items := []
    rows := []
    for row in g_Commands["ToolbarLayout"]
        rows.Push(row)
    if rows.Length > 1
        rows := _VK_SortRowsByNumericKey(rows, "order_bar")
    for row in rows {
        if !(row is Map) || !row.Has("cmdId")
            continue
        if !row.Has("visible_in_bar") || !row["visible_in_bar"]
            continue
        cid := Trim(String(row["cmdId"]))
        if (cid = "" || !cmdList.Has(cid))
            continue
        if g_FTB_BlockedCmdIds.Has(cid)
            continue
        if !g_FTB_AllowedCmdIds.Has(cid)
            continue
        ent := cmdList[cid]
        nm := ent.Has("name") ? String(ent["name"]) : cid
        ic := "fa-circle"
        if (ent is Map) && ent.Has("iconClass") && ent["iconClass"] != "" {
            ic := Trim(String(ent["iconClass"]))
            if (SubStr(ic, 1, 3) != "fa-")
                ic := "fa-solid " . ic
            else if !InStr(ic, "fa-solid") && !InStr(ic, "fa-brands") && !InStr(ic, "fa-regular")
                ic := "fa-solid " . ic
        }
        rowPayload := Map("cmdId", cid, "name", nm, "iconClass", ic)
        if (cid = "ftb_cursor_menu")
            rowPayload["iconPath"] := FloatingToolbar_GetCursorIconPath()
        if (cid != "ftb_cursor_menu" && (ent is Map) && ent.Has("iconPath") && ent["iconPath"] != "")
            rowPayload["iconPath"] := String(ent["iconPath"])
        items.Push(rowPayload)
    }
    hasCursorMenu := false
    for _, it in items {
        if ((it is Map) && it.Has("cmdId") && String(it["cmdId"]) = "ftb_cursor_menu") {
            hasCursorMenu := true
            break
        }
    }
    if (!hasCursorMenu && g_FTB_AllowedCmdIds.Has("ftb_cursor_menu")) {
        cursorName := "Cursor"
        if (cmdList.Has("ftb_cursor_menu")) {
            cent := cmdList["ftb_cursor_menu"]
            if (cent is Map) && cent.Has("name") && cent["name"] != ""
                cursorName := String(cent["name"])
        }
        cursorIconPath := FloatingToolbar_GetCursorIconPath()
        items.Push(Map(
            "cmdId", "ftb_cursor_menu",
            "name", cursorName,
            "iconClass", "fa-solid fa-compass",
            "iconPath", cursorIconPath
        ))
    }
    FloatingToolbarCmdVisibleCount := items.Length
    try WebView_QueuePayload(g_FTB_WV2, Map("type", "set_toolbar_cmds", "items", items))
    catch as _e {
    }
    if !FloatingToolbarChatDrawerOpen && !FloatingToolbarIsCompactMode()
        FloatingToolbar_ResizeForToolbarCount()
}

FloatingToolbar_GetCursorIconPath() {
    global g_FTB_CursorIconDataUrl
    if (g_FTB_CursorIconDataUrl != "")
        return g_FTB_CursorIconDataUrl
    iconFile := A_ScriptDir "\images\cursor.png"
    if !FileExist(iconFile)
        return iconFile
    try {
        buf := FileRead(iconFile, "RAW")
        b64 := FloatingToolbar_Base64EncodeBuffer(buf)
        if (b64 != "")
            g_FTB_CursorIconDataUrl := "data:image/png;base64," . b64
    } catch {
    }
    return (g_FTB_CursorIconDataUrl != "") ? g_FTB_CursorIconDataUrl : iconFile
}

FloatingToolbar_Base64EncodeBuffer(buf) {
    if !(buf is Buffer) || (buf.Size <= 0)
        return ""
    flags := 0x40000001 ; CRYPT_STRING_BASE64 | CRYPT_STRING_NOCRLF
    chars := 0
    if !DllCall("crypt32\CryptBinaryToStringW", "Ptr", buf.Ptr, "UInt", buf.Size, "UInt", flags, "Ptr", 0, "UInt*", &chars)
        return ""
    out := Buffer(chars * 2, 0)
    if !DllCall("crypt32\CryptBinaryToStringW", "Ptr", buf.Ptr, "UInt", buf.Size, "UInt", flags, "Ptr", out.Ptr, "UInt*", &chars)
        return ""
    return Trim(StrGet(out.Ptr, "UTF-16"), "`r`n`t ")
}

FloatingToolbarReloadFromToolbarLayout() {
    FloatingToolbarPushCmdLayoutToWeb()
}

FloatingToolbarPushButtonConfigToWeb() {
    FloatingToolbarPushCmdLayoutToWeb()
}

FloatingToolbarExitCompactMode() {
    global FloatingToolbarGUI, FloatingToolbarScale, FloatingToolbarMinScale, FloatingToolbarMaxScale
    global FloatingToolbarWindowX, FloatingToolbarWindowY

    if !IsObject(FloatingToolbarGUI) || !(FloatingToolbarGUI is Gui)
        return
    if !FloatingToolbarIsCompactMode()
        return

    targetScale := FloatingToolbarMinScale + 0.15
    if (targetScale > FloatingToolbarMaxScale)
        targetScale := FloatingToolbarMaxScale

    try FloatingToolbarGUI.GetPos(&oldX, &oldY, &oldW, &oldH)
    catch {
        oldX := FloatingToolbarWindowX
        oldY := FloatingToolbarWindowY
        oldW := FloatingToolbarCalculateWidth()
        oldH := FloatingToolbarCalculateHeight()
    }

    centerX := oldX + (oldW / 2.0)
    centerY := oldY + (oldH / 2.0)
    FloatingToolbarScale := targetScale
    newW := FloatingToolbarCalculateWidth()
    newH := FloatingToolbarCalculateHeight()
    newX := Round(centerX - (newW / 2.0))
    newY := Round(centerY - (newH / 2.0))

    ScreenVirtual_GetBounds(&vl, &vt, &vw, &vh)
    vr := vl + vw
    vb := vt + vh
    if (newX < vl)
        newX := vl
    if (newY < vt)
        newY := vt
    if (newX + newW > vr)
        newX := vr - newW
    if (newY + newH > vb)
        newY := vb - newH

    FloatingToolbarWindowX := newX
    FloatingToolbarWindowY := newY
    FloatingToolbarGUI.Move(newX, newY, newW, newH)
    FloatingToolbarApplyRoundedCorners()
    FloatingToolbar_ApplyWebViewBounds()
    FloatingToolbarPushScaleStateToWeb(targetScale)
    FloatingToolbarSaveScale()
    SaveFloatingToolbarPosition()
}

; ===================== 鐠侊紕鐣诲銉ュ徔閺嶅繐顔旀惔锕€鎷版妯哄 =====================
FloatingToolbarCalculateWidth() {
    global FloatingToolbarScale, FloatingToolbarChatDrawerOpen, FloatingToolbarChatDrawerWidth, FloatingToolbarCompactDiameter, FloatingToolbarCmdVisibleCount
    iconCount := (FloatingToolbarCmdVisibleCount > 0) ? FloatingToolbarCmdVisibleCount : 7
    BaseWidth := Max(220, 56 + iconCount * 46)
    if (FloatingToolbarChatDrawerOpen)
        return Round(Max(BaseWidth, FloatingToolbarChatDrawerWidth) * FloatingToolbarScale)
    if FloatingToolbarIsCompactMode()
        return Round(FloatingToolbarCompactDiameter)
    return Round(BaseWidth * FloatingToolbarScale)
}

FloatingToolbar_ShowCursorQuickMenu() {
    menuItems := [
        { Text: "命令面板  (Ctrl+Shift+P)", Icon: "▶", Action: (*) => _ExecuteCommand("qa_command_palette") },
        { Text: "全局搜索  (Ctrl+Shift+F)", Icon: "▶", Action: (*) => _ExecuteCommand("qa_global_search") },
        { Text: "资源管理器  (Ctrl+Shift+E)", Icon: "▶", Action: (*) => _ExecuteCommand("qa_explorer") },
        { Text: "源代码管理  (Ctrl+Shift+G)", Icon: "▶", Action: (*) => _ExecuteCommand("qa_source_control") },
        { Text: "扩展  (Ctrl+Shift+X)", Icon: "▶", Action: (*) => _ExecuteCommand("qa_extensions") },
        { Text: "终端  (Ctrl+Shift+``)", Icon: "▶", Action: (*) => _ExecuteCommand("qa_terminal") },
        { Text: "Cursor 设置  (Ctrl+,)", Icon: "▶", Action: (*) => _ExecuteCommand("qa_cursor_settings") }
    ]
    try {
        MouseGetPos &mx, &my
        ShowDarkStylePopupMenuAt(menuItems, mx + 2, my + 2)
    } catch {
    }
}

FloatingToolbar_ResizeForToolbarCount() {
    global FloatingToolbarGUI, FloatingToolbarWindowX, FloatingToolbarWindowY, FloatingToolbarChatDrawerOpen
    if !IsObject(FloatingToolbarGUI) || FloatingToolbarChatDrawerOpen || FloatingToolbarIsCompactMode()
        return
    newW := FloatingToolbarCalculateWidth()
    newH := FloatingToolbarCalculateHeight()
    try FloatingToolbarGUI.GetPos(&gx, &gy, &gw, &gh)
    catch {
        gx := FloatingToolbarWindowX
        gy := FloatingToolbarWindowY
        gw := newW
    }
    rightEdge := gx + gw
    newX := rightEdge - newW
    ScreenVirtual_GetBounds(&vl, &vt, &vw, &vh)
    vr := vl + vw
    if (newX < vl)
        newX := vl
    if (newX + newW > vr)
        newX := vr - newW
    FloatingToolbarWindowX := newX
    FloatingToolbarWindowY := gy
    try FloatingToolbarGUI.Move(newX, gy, newW, newH)
    catch {
    }
    FloatingToolbar_ApplyWebViewBounds()
}

FloatingToolbarCalculateHeight() {
    global FloatingToolbarScale, FloatingToolbarChatDrawerOpen, FloatingToolbarChatDrawerHeight, FloatingToolbarCompactDiameter
    ; HTML 缂佹挻鐎稉?52px logo + 娑撳﹣绗呴崥?6px padding閿涘苯娲滃銈呯唨閸戝棝鐝惔锕€绻€妞ょ粯妲?64
    BaseHeight := 64
    if FloatingToolbarChatDrawerOpen {
        ScreenVirtual_GetBounds(&vl, &vt, &vw, &vh)
        return vh
    }
    if FloatingToolbarIsCompactMode()
        return Round(FloatingToolbarCompactDiameter)
    return Round(BaseHeight * FloatingToolbarScale)
}

; ===================== 閺堚偓鐏忓繐瀵查崚鏉跨潌楠炴洝绔熺紓?=====================
MinimizeFloatingToolbarToEdge() {
    global FloatingToolbarGUI, FloatingToolbarIsVisible, FloatingToolbarIsMinimized
    global FloatingToolbarWindowX, FloatingToolbarWindowY

    if (!FloatingToolbarIsVisible || FloatingToolbarGUI = 0)
        return

    FloatingToolbarGUI.GetPos(&currentX, &currentY, &currentW, &currentH)

    ScreenVirtual_GetBounds(&vl, &vt, &vw, &vh)
    vr := vl + vw
    vb := vt + vh

    distLeft := currentX - vl
    distRight := vr - (currentX + currentW)
    distTop := currentY - vt
    distBottom := vb - (currentY + currentH)

    minDist := distLeft
    targetX := vl
    targetY := currentY

    if (distRight < minDist) {
        minDist := distRight
        targetX := vr - currentW
        targetY := currentY
    }
    if (distTop < minDist) {
        minDist := distTop
        targetX := currentX
        targetY := vt
    }
    if (distBottom < minDist) {
        minDist := distBottom
        targetX := currentX
        targetY := vb - currentH
    }

    FloatingToolbarGUI.Move(targetX, targetY)
    FloatingToolbarWindowX := targetX
    FloatingToolbarWindowY := targetY
    FloatingToolbarIsMinimized := true

    SaveFloatingToolbarPosition()
}

RestoreFloatingToolbar() {
    global FloatingToolbarIsMinimized
    FloatingToolbarIsMinimized := false
}

; ===================== 闁灏幇鐔风安閼辨柨濮?=====================
FloatingToolbar_NotifySelectionChange(fullText) {
    global g_FTB_WV2, g_FTB_WV2_Ready, g_FTB_WV2_FrameReady, g_FTB_PendingSelection

    if !g_FTB_WV2 {
        g_FTB_PendingSelection := String(fullText)
        return
    }
    if !(g_FTB_WV2_Ready && g_FTB_WV2_FrameReady) {
        g_FTB_PendingSelection := String(fullText)
        return
    }
    pv := SubStr(String(fullText), 1, 220)
    try WebView_QueuePayload(g_FTB_WV2, Map("type", "SELECTION_CHANGE", "preview", pv))
    catch as _e {
        g_FTB_PendingSelection := String(fullText)
        return
    }
}

FloatingToolbar_NotifySelectionClear() {
    global g_FTB_WV2, g_FTB_WV2_Ready, g_FTB_WV2_FrameReady, g_FTB_PendingSelection

    g_FTB_PendingSelection := ""
    if !(g_FTB_WV2 && g_FTB_WV2_Ready && g_FTB_WV2_FrameReady)
        return
    try WebView_QueuePayload(g_FTB_WV2, Map("type", "SELECTION_CLEAR"))
    catch as _e {
    }
}

FloatingToolbar_SendTextToNiumaChat(text, sendNow := true, appendMode := true, openDrawer := true) {
    global g_FTB_WV2, g_FTB_WV2_Ready, g_FTB_WV2_FrameReady, g_FTB_PendingNiumaCompose

    t := Trim(String(text), " `t`r`n")
    if (t = "")
        return false
    if !g_FTB_WV2
        return false

    if openDrawer {
        try FloatingToolbarSetChatDrawerState(true)
    }

    payload := Map(
        "type", "niuma_compose_send",
        "text", t,
        "send", !!sendNow,
        "append", !!appendMode,
        "openDrawer", !!openDrawer
    )
    if !(g_FTB_WV2_Ready && g_FTB_WV2_FrameReady) {
        try {
            if !(g_FTB_PendingNiumaCompose is Array)
                g_FTB_PendingNiumaCompose := []
            g_FTB_PendingNiumaCompose.Push(payload)
            return true
        } catch as _ePending {
            return false
        }
    }
    try {
        WebView_QueuePayload(g_FTB_WV2, payload)
        return true
    } catch as _e {
        return false
    }
}

; ===================== 閸掓繂顫愰崠?=====================
InitFloatingToolbar() {
}

; ===================== 閺嶈宓侀幐澶愭尦action閼惧嘲褰囬幓鎰仛閺傚洤鐡?=====================
GetButtonTip(action) {
    switch action {
        case "Search":
            return "鎼滅储璁板綍 (CapsLock + F)"
        case "Record":
            return "鏂板壀璐存澘 (WebView2 路 FTS5)"
        case "AIAssistant":
            return "AI 鍔╂墜 (Ctrl+Shift+B)"
        case "PromptNew":
            return "Hub 鑽夌 路 杩愯 hub_capsule 路 閲囬泦 CapsLock+C"
        case "Screenshot":
            return "灞忓箷鎴浘 (CapsLock + T)"
        case "Settings":
            return "绯荤粺璁剧疆 (CapsLock + Q)"
        case "VirtualKeyboard":
            return "铏氭嫙閿洏 (Ctrl+Shift+K)"
        default:
            return ""
    }
}
