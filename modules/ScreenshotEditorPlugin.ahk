; ScreenshotEditorPlugin.ahk 鈥?鎴浘鍔╂墜锛堢被灏佽锛岀敱涓昏剼鏈?#Include锛?
; 鐘舵€佷负 ScreenshotEditorPlugin 鐨?static 瀛楁锛汬ub 鍚屾灏戦噺鍏ㄥ眬渚?LegacyConfigGui銆?

class ScreenshotEditorPlugin {

    static g_ShowScreenshotEditorInFlight := false
    static GuiID_ScreenshotEditor := 0
    static GuiID_ScreenshotToolbar := 0
    static ScreenshotToolbarWV2Ctrl := 0
    static ScreenshotToolbarWV2 := 0
    static ScreenshotToolbarWV2Ready := false
    static ScreenshotToolbarWV2PaintOk := false
    static ScreenshotToolbarNativeFallback := false
    static ScreenshotToolbarCreateCheckPass := 0
    static ScreenshotToolbarCurrentWidth := 520
    static ScreenshotToolbarCurrentHeight := 56
    static ScreenshotOCRHubPendingText := ""
    static ScreenshotOCRHubPushAttempts := 0
    static ScreenshotOCRHubPushInFlight := false
    static ScreenshotEditorBitmap := 0
    static ScreenshotEditorGraphics := 0
    static ScreenshotEditorImagePath := ""
    static ScreenshotEditorTitleBarHeight := 30
    static ScreenshotEditorZoomScale := 1.0
    static ScreenshotEditorZoomMin := 0.2
    static ScreenshotEditorZoomMax := 4.0
    static ScreenshotEditorBaseWidth := 0
    static ScreenshotEditorBaseHeight := 0
    static GuiID_ScreenshotZoomTip := 0
    static ScreenshotZoomTipTextCtrl := 0
    static ScreenshotEditorAlwaysOnTop := true
    static ScreenshotEditorTitleBar := 0
    static ScreenshotEditorCloseBtn := 0
    static ScreenshotEditorToolbarVisible := true
    static ScreenshotEditorIsDraggingWindow := false
    static ScreenshotToolbarHoverItems := []
    static ScreenshotToolbarHoverTipLastKey := ""
    static GuiID_ScreenshotToolbarTip := 0
    static ScreenshotToolbarTipTextCtrl := 0
    static ScreenshotOCRTextLayoutMode := "auto"
    static ScreenshotOCRPunctuationMode := "keep"
    static ScreenshotOCRDirectCopyEnabled := false
    static ScreenshotColorPickerActive := false
    static GuiID_ScreenshotColorPicker := 0
    static ScreenshotColorPickerMagnifierPic := 0
    static ScreenshotColorPickerCurrentText := 0
    static ScreenshotColorPickerCompareText := 0
    static ScreenshotColorPickerHistoryEdit := 0
    static ScreenshotColorPickerCurrent := Map()
    static ScreenshotColorPickerAnchor := Map()
    static ScreenshotColorPickerHistory := []
    static ScreenshotColorPickerTickBusy := false
    static ScreenshotEditorPreviewBitmap := 0
    static ScreenshotEditorPreviewWidth := 0
    static ScreenshotEditorPreviewHeight := 0
    static ScreenshotEditorImgWidth := 0
    static ScreenshotEditorImgHeight := 0
    static ScreenshotEditorPreviewPic := 0
    static ScreenshotEditorMode := ""

    static IsScreenshotEditorActive() {
    try {
        if !(IsObject(this.GuiID_ScreenshotEditor) && this.GuiID_ScreenshotEditor != 0)
            return false
        hwnd := this.GuiID_ScreenshotEditor.Hwnd
        if !hwnd
            return false
        return !!WinExist("ahk_id " . hwnd)
    } catch {
        return false
    }
}

    static IsScreenshotEditorZoomHotkeyActive() {
    if !this.IsScreenshotEditorActive()
        return false
    try {
        MouseGetPos(, , &hoverHwnd)
        if !hoverHwnd
            return false
        ; 榧犳爣浣嶄簬鎴浘鍔╂墜绐楀彛鎴栧叾瀛愭帶浠朵笂鍧囧厑璁哥缉鏀?
        return (hoverHwnd = this.GuiID_ScreenshotEditor.Hwnd) || DllCall("user32\IsChild", "ptr", this.GuiID_ScreenshotEditor.Hwnd, "ptr", hoverHwnd, "int")
    }
    catch {
        return false
    }
}

    static HandleScreenshotEditorHotkey(ActionType) {
    if !this.IsScreenshotEditorActive()
        return false
    switch ActionType {
        case "Q":
            this.ToggleScreenshotEditorAlwaysOnTop()
            return true
        case "E":
            this.ExecuteScreenshotOCR()
            return true
        case "C":
            this.PasteScreenshotAsText()
            return true
        case "R":
            this.SaveScreenshotToFile()
            return true
        case "Z":
            this.ScreenshotEditorSendToAI()
            return true
        case "F":
            this.ScreenshotEditorSearchText()
            return true
        case "X":
            this.ScreenshotEditorToggleColorPicker()
            return true
        case "ESC":
            this.CloseScreenshotEditor()
            return true
    }
    return false
}

; ===================== 鎴浘鍔╂墜棰勮绐?=====================

    static SafeGdipDisposeImage(pBitmap) {
    if (!pBitmap || pBitmap = 0)
        return
    try Gdip_DisposeImage(pBitmap)
    catch {
    }
}

    static SafeGdipDeleteGraphics(pGraphics) {
    if (!pGraphics || pGraphics = 0)
        return
    try Gdip_DeleteGraphics(pGraphics)
    catch {
    }
}

; 妫€鏌ュ彲鑳芥湁骞叉壈鐨勫壀璐存澘宸ュ叿
    static CheckInterferingClipboardTools() {
    ; 甯歌鐨勫壀璐存澘澧炲己宸ュ叿
    clipboardTools := ["ClipX.exe", "Ditto.exe", "PowerClipboard.exe", "ARClipboard.exe", "Clipboardic.exe"]
    
    for tool in clipboardTools {
        if (ProcessExist(tool)) {
            OutputDebug("[Screenshot] 妫€娴嬪埌鍙兘骞叉壈鐨勫壀璐存澘宸ュ叿: " . tool)
            ; 璁板綍鍒版棩蹇?
            try {
                FileAppend("[" . A_Now . "] 妫€娴嬪埌鍓创鏉垮伐鍏? " . tool . "`n", A_ScriptDir . "\cache\screenshot_interference.log")
            } catch {
            }
        }
    }
}

; 鍏抽棴鍙兘娈嬬暀鐨勬埅鍥剧獥鍙ｏ紙鍖呭惈鏈剼鏈笌绯荤粺鎴浘宸ュ叿锛?
    static CloseAllScreenshotWindows() {
    global GuiID_ScreenshotButton, ScreenshotButtonVisible

    ; 鍏堝叧闂垜浠嚜宸辩殑鎴浘鐩稿叧绐楀彛锛堜粎褰撳叏灞€涓虹湡瀹?Gui 瀵硅薄鏃讹紝閬垮厤璇妸鏁存暟褰撶獥鍙ｅ叧闂級
    try {
        if (IsObject(this.GuiID_ScreenshotEditor)) {
            this.CloseScreenshotEditor()
        }
    } catch as e {
    }

    try {
        if (ScreenshotButtonVisible) {
            HideScreenshotButton()
        } else if (GuiID_ScreenshotButton != 0) {
            if (IsObject(GuiID_ScreenshotButton)) {
                GuiID_ScreenshotButton.Destroy()
            } else if (GuiID_ScreenshotButton.HasProp("Hwnd") && GuiID_ScreenshotButton.Hwnd) {
                WinClose("ahk_id " . GuiID_ScreenshotButton.Hwnd)
            }
            GuiID_ScreenshotButton := 0
        }
    } catch as e {
    }

    ; 灏濊瘯鍏抽棴甯歌鐨勭郴缁熸埅鍥惧伐鍏风獥鍙?
    winTargets := [
        "ahk_exe SnippingTool.exe",
        "ahk_exe ScreenClippingHost.exe",
        "ahk_exe SnipAndSketch.exe",
        "ahk_exe ScreenSketch.exe",
        "ahk_class ScreenClippingHostWindow",
        "ahk_class SnippingTool"
    ]

    for _, target in winTargets {
        try {
            if (WinExist(target)) {
                WinClose(target)
            }
        } catch as e {
        }
    }
}

; 鏄剧ず鎴浘鍔╂墜棰勮绐?
    static ShowScreenshotEditor(DebugGui := 0) {
    global ScreenshotClipboard, UI_Colors, ThemeMode
    try FloatingToolbar_PageDockEnter("screenshot")
    
    ; 鍒濆鍖栧眬閮ㄥ彉閲?
    pToken := 0
    hBitmap := 0
    pBitmap := 0
    ImgWidth := 0
    ImgHeight := 0
    pPreviewBitmap := 0
    pGraphics := 0
    
    prevCrit := Critical("On")
    if (this.g_ShowScreenshotEditorInFlight) {
        Critical(prevCrit)
        return
    }
    this.g_ShowScreenshotEditorInFlight := true
    Critical(prevCrit)
    try {
        if (DebugGui) {
            UpdateDebugStep(DebugGui, 14, "ShowScreenshotEditor: 寮€濮嬫墽琛?..", false)
        }
        
        ; 濡傛灉棰勮绐楀凡瀛樺湪锛屽厛鍏抽棴骞舵竻鐞嗘棫璧勬簮锛岀‘淇濇瘡娆￠兘鏄柊鎴浘
        if (DebugGui) {
            UpdateDebugStep(DebugGui, 15, "妫€鏌ラ瑙堢獥鏄惁宸插瓨鍦?..", false)
        }
        if (IsObject(this.GuiID_ScreenshotEditor)) {
            if (DebugGui) {
                UpdateDebugStep(DebugGui, 15, "鍙戠幇鏃х殑棰勮绐楋紝姝ｅ湪鍏抽棴骞舵竻鐞嗚祫婧?..", false)
            }
            ; 鍏抽棴鏃х獥鍙ｅ苟娓呯悊鎵€鏈夎祫婧愶紝纭繚姣忔閮芥槸鏂版埅鍥?
            this.CloseScreenshotEditor()
            if (DebugGui) {
                UpdateDebugStep(DebugGui, 15, "旧预览窗口已关闭，资源已清理", true)
            }
        } else {
            if (DebugGui) {
                UpdateDebugStep(DebugGui, 15, "预览窗口不存在，继续", true)
            }
        }
        
        ; 鍒濆鍖朑DI+
        if (DebugGui) {
            UpdateDebugStep(DebugGui, 16, "鍒濆鍖?GDI+...", false)
        }
        try {
            pToken := Gdip_Startup()
            if (!pToken) {
                if (DebugGui) {
                    UpdateDebugStep(DebugGui, 16, "GDI+ 鍒濆鍖栧け璐? pToken 涓虹┖", false)
                }
                TrayTip("閿欒", "鏃犳硶鍒濆鍖朑DI+", "Iconx 2")
                return
            }
            if (DebugGui) {
                UpdateDebugStep(DebugGui, 16, "GDI+ 鍒濆鍖栨垚鍔燂紝pToken: " . pToken, true)
            }
        } catch as e {
            if (DebugGui) {
                UpdateDebugStep(DebugGui, 16, "GDI+ 鍒濆鍖栧紓甯? " . e.Message, false)
            }
            TrayTip("閿欒", "鍒濆鍖朑DI+澶辫触: " . e.Message, "Iconx 2")
            return
        }
        
        ; 濡傛灉ScreenshotClipboard瀛樺湪锛屽厛鎭㈠瀹冨埌鍓创鏉?
        if (DebugGui) {
            UpdateDebugStep(DebugGui, 17, "妫€鏌?ScreenshotClipboard...", false)
        }
        if (ScreenshotClipboard) {
            if (DebugGui) {
                UpdateDebugStep(DebugGui, 17, "ScreenshotClipboard 瀛樺湪锛屾仮澶嶅埌鍓创鏉?..", false)
            }
            try {
                A_Clipboard := ScreenshotClipboard
                Sleep(300)
                if (DebugGui) {
                    UpdateDebugStep(DebugGui, 17, "鍓创鏉垮凡鎭㈠", true)
                }
            } catch as e {
                if (DebugGui) {
                    UpdateDebugStep(DebugGui, 17, "鎭㈠澶辫触: " . e.Message, false)
                }
                TrayTip("閿欒", "鎭㈠鎴浘鍒板壀璐存澘澶辫触: " . e.Message, "Iconx 2")
                try {
                    Gdip_Shutdown(pToken)
                } catch as e2 {
                }
                return
            }
        } else {
            if (DebugGui) {
                UpdateDebugStep(DebugGui, 17, "ScreenshotClipboard 为空，跳过", true)
            }
        }
        
        ; 鐩存帴浣跨敤 Gdip 浠庡壀璐存澘鍒涘缓浣嶅浘锛屽け璐ユ椂鍥為€€鍒?ImagePut
        if (DebugGui) {
            UpdateDebugStep(DebugGui, 18, "浣跨敤 Gdip_CreateBitmapFromClipboard()...", false)
        }
        try {
            pBitmap := Gdip_CreateBitmapFromClipboard()
            if (!pBitmap || pBitmap = 0) {
                pBitmap := ImagePutBitmap(A_Clipboard)
                if (DebugGui) {
                    UpdateDebugStep(DebugGui, 18, "Gdip 杩斿洖绌猴紝宸插洖閫€鍒?ImagePutBitmap()", !!pBitmap)
                }
            }
            if (DebugGui) {
                UpdateDebugStep(DebugGui, 18, "成功，pBitmap: " . (pBitmap ? pBitmap : "空"), true)
            }
        } catch as e {
            if (DebugGui) {
                UpdateDebugStep(DebugGui, 18, "Gdip 澶辫触锛屽皾璇?ImagePutBitmap(): " . e.Message, false)
            }
            try {
                pBitmap := ImagePutBitmap(A_Clipboard)
                if (DebugGui) {
                    UpdateDebugStep(DebugGui, 18, "ImagePutBitmap() 缁撴灉: " . (pBitmap ? "鎴愬姛" : "澶辫触"), !!pBitmap)
                }
            } catch as e2 {
                if (DebugGui) {
                    UpdateDebugStep(DebugGui, 18, "ImagePutBitmap() 澶辫触: " . e2.Message, false)
                }
            }
            if (!pBitmap || pBitmap = 0) {
                TrayTip("閿欒", "浠庡壀璐存澘鍒涘缓浣嶅浘澶辫触: " . e.Message, "Iconx 2")
                try {
                    Gdip_Shutdown(pToken)
                } catch as e3 {
                }
                return
            }
        }
        
        ; 楠岃瘉pBitmap鏄惁鏈夋晥
        if (DebugGui) {
            UpdateDebugStep(DebugGui, 19, "楠岃瘉 pBitmap 鏈夋晥鎬?..", false)
        }
        if (!pBitmap || pBitmap = 0) {
            if (DebugGui) {
                UpdateDebugStep(DebugGui, 19, "pBitmap 鏃犳晥", false)
            }
            TrayTip("错误", "无法从剪贴板获取图片，请确认截图成功。", "Iconx 2")
            try {
                Gdip_Shutdown(pToken)
            } catch as e {
            }
            return
        }
        if (DebugGui) {
            UpdateDebugStep(DebugGui, 19, "pBitmap 楠岃瘉閫氳繃: " . pBitmap, true)
        }
        
        ; 鑾峰彇浣嶅浘灏哄锛堝厛鐢?Gdip_All 灏佽锛屽け璐ュ啀 DllCall 鍏滃簳锛?
        if (DebugGui) {
            UpdateDebugStep(DebugGui, 22, "鑾峰彇浣嶅浘灏哄...", false)
        }
        ImgWidth := 0
        ImgHeight := 0
        SizeGetOk := false
        ; 鏌愪簺绯荤粺涓嬫埅鍥惧啓鍏ュ壀璐存澘瀛樺湪鐭殏寤惰繜锛岀粰涓€娆￠噸璇曠獥鍙ｆ彁鍗囩ǔ瀹氭€?
        Loop 2 {
            try {
                ImgWidth := Gdip_GetImageWidth(pBitmap)
                ImgHeight := Gdip_GetImageHeight(pBitmap)
                SizeGetOk := (ImgWidth > 0 && ImgHeight > 0)
            } catch as e {
                SizeGetOk := false
            }

            if (!SizeGetOk) {
                try {
                    resultW := DllCall("gdiplus\GdipGetImageWidth", "Ptr", pBitmap, "UInt*", &ImgWidth)
                    resultH := DllCall("gdiplus\GdipGetImageHeight", "Ptr", pBitmap, "UInt*", &ImgHeight)
                    SizeGetOk := (resultW = 0 && resultH = 0 && ImgWidth > 0 && ImgHeight > 0)
                } catch as e {
                    SizeGetOk := false
                }
            }

            if (SizeGetOk)
                break
            Sleep(80)
        }

        if (!SizeGetOk) {
            TrayTip("閿欒", "鏃犳硶鑾峰彇浣嶅浘灏哄锛堟埅鍥炬暟鎹彲鑳芥棤鏁堬級", "Iconx 2")
            this.SafeGdipDisposeImage(pBitmap)
            try {
                Gdip_Shutdown(pToken)
            } catch as e {
                ; 蹇界暐鍏抽棴閿欒
            }
            return
        }
        
        ; 璁＄畻棰勮绐楀彛灏哄锛堟渶澶?00x600锛屼繚鎸佸楂樻瘮锛?
        MaxWidth := 800
        MaxHeight := 600
        ScaleX := MaxWidth / ImgWidth
        ScaleY := MaxHeight / ImgHeight
        Scale := ScaleX < ScaleY ? ScaleX : ScaleY
        PreviewWidth := Round(ImgWidth * Scale)
        PreviewHeight := Round(ImgHeight * Scale)
        
        ; 楠岃瘉璁＄畻鍑虹殑灏哄鏈夋晥
        if (PreviewWidth <= 0 || PreviewHeight <= 0) {
            TrayTip("閿欒", "棰勮灏哄璁＄畻澶辫触", "Iconx 2")
            this.SafeGdipDisposeImage(pBitmap)
            try {
                Gdip_Shutdown(pToken)
            } catch as e {
                ; 蹇界暐鍏抽棴閿欒
            }
            return
        }
        
        ; 鍒涘缓棰勮浣嶅浘
        result := DllCall("gdiplus\GdipCreateBitmapFromScan0", "Int", PreviewWidth, "Int", PreviewHeight, "Int", 0, "UInt", 0x26200A, "Ptr", 0, "Ptr*", &pPreviewBitmap := 0)
        if (result != 0 || !pPreviewBitmap || pPreviewBitmap = 0) {
            TrayTip("閿欒", "鏃犳硶鍒涘缓棰勮浣嶅浘", "Iconx 2")
            this.SafeGdipDisposeImage(pBitmap)
            try {
                Gdip_Shutdown(pToken)
            } catch as e {
                ; 蹇界暐鍏抽棴閿欒
            }
            return
        }
        
        ; 鑾峰彇鍥惧舰涓婁笅鏂?
        result := DllCall("gdiplus\GdipGetImageGraphicsContext", "Ptr", pPreviewBitmap, "Ptr*", &pGraphics := 0)
        if (result != 0 || !pGraphics || pGraphics = 0) {
            TrayTip("错误", "无法获取图形上下文", "Iconx 2")
            this.SafeGdipDisposeImage(pPreviewBitmap)
            this.SafeGdipDisposeImage(pBitmap)
            try {
                Gdip_Shutdown(pToken)
            } catch as e {
                ; 蹇界暐鍏抽棴閿欒
            }
            return
        }
        
        ; 璁剧疆楂樿川閲忔彃鍊兼ā寮忓苟缁樺埗鍥惧儚
        DllCall("gdiplus\GdipSetInterpolationMode", "Ptr", pGraphics, "Int", 7)  ; HighQualityBicubic
        result := DllCall("gdiplus\GdipDrawImageRect", "Ptr", pGraphics, "Ptr", pBitmap, "Float", 0, "Float", 0, "Float", PreviewWidth, "Float", PreviewHeight)
        if (result != 0) {
            TrayTip("閿欒", "鏃犳硶缁樺埗棰勮鍥惧儚", "Iconx 2")
            this.SafeGdipDeleteGraphics(pGraphics)
            this.SafeGdipDisposeImage(pPreviewBitmap)
            this.SafeGdipDisposeImage(pBitmap)
            try {
                Gdip_Shutdown(pToken)
            } catch as e {
                ; 蹇界暐鍏抽棴閿欒
            }
            return
        }
        
        ; 淇濆瓨浣嶅浘鍜屽浘褰㈠彞鏌?
        this.ScreenshotEditorBitmap := pBitmap
        this.ScreenshotEditorGraphics := pGraphics
        this.ScreenshotEditorPreviewBitmap := pPreviewBitmap
        this.ScreenshotEditorPreviewWidth := PreviewWidth
        this.ScreenshotEditorPreviewHeight := PreviewHeight
        this.ScreenshotEditorBaseWidth := PreviewWidth
        this.ScreenshotEditorBaseHeight := PreviewHeight
        this.ScreenshotEditorZoomScale := 1.0
        this.ScreenshotEditorImgWidth := ImgWidth
        this.ScreenshotEditorImgHeight := ImgHeight
        
        ; 鍒涘缓GUI锛堝彲鎷栧姩绐楀彛锛?
        ; 浣跨敤灞€閮?EditorGui 鏋勫缓锛屾渶鍚庡啀璧嬬粰鍏ㄥ眬 this.GuiID_ScreenshotEditor锛岄伩鍏嶆瀯寤鸿繃绋嬩腑
        ; 鍏ㄥ眬琚叾瀹冮€昏緫娓呯┖鎴栨湭缁戝畾瀵艰嚧 .Show 瀵规暣鏁?0 璋冪敤銆?
        EditorGui := Gui("+AlwaysOnTop +ToolWindow -Caption -DPIScale")
        EditorGui.BackColor := UI_Colors.Background
        EditorGui.SetFont("s10 c" . UI_Colors.Text, "Segoe UI")
        
        ; 绐楀彛灏哄锛堜粎棰勮鍖哄煙锛屽伐鍏锋爮鐙珛鎮诞锛?
        ; 娑堥櫎榛戣竟锛氱獥鍙ｅ搴︾瓑浜庡浘鐗囧搴︼紝楂樺害绛変簬鏍囬鏍?鍥剧墖楂樺害
        TitleBarHeight := 30
        this.ScreenshotEditorTitleBarHeight := TitleBarHeight
        WindowWidth := PreviewWidth
        WindowHeight := TitleBarHeight + PreviewHeight
        
        ; 鏍囬鏍忥紙鍙嫋鍔級
        this.ScreenshotEditorTitleBar := EditorGui.Add("Text", "x0 y0 w" . (WindowWidth - 40) . " h" . TitleBarHeight . " Center Background" . UI_Colors.TitleBar . " c" . UI_Colors.Text, "📷 截图助手")
        this.ScreenshotEditorTitleBar.SetFont("s11 Bold", "Segoe UI")
        ; 娣诲姞鎷栧姩鍔熻兘锛圱ext鎺т欢鍙敮鎸丆lick浜嬩欢锛?
        this.ScreenshotEditorTitleBar.OnEvent("Click", ObjBindMethod(ScreenshotEditorPlugin, "ScreenshotEditorDragWindow"))
        
        ; [鍏抽棴] 鎸夐挳锛堝湪鏍囬鏍忓彸渚э紝鏈€鍚庡垱寤轰互纭繚鍦ㄦ渶涓婂眰锛?
        ; 娉ㄦ剰锛氬叧闂寜閽渶瑕佸湪鎵€鏈夊叾浠栨帶浠朵箣鍚庡垱寤猴紝浠ョ‘淇濆畠鍦ㄦ渶涓婂眰
        this.ScreenshotEditorCloseBtn := 0
        
        ; 棰勮鍖哄煙锛堜娇鐢≒icture鎺т欢鏄剧ず锛岀揣璐寸獥鍙ｈ竟缂橈紝鏃犻粦杈癸級
        PreviewY := TitleBarHeight
        ; 灏嗕綅鍥句繚瀛樹负涓存椂鏂囦欢鐢ㄤ簬鏄剧ず
        TempImagePath := A_Temp "\ScreenshotEditor_" . A_TickCount . ".png"
        try {
            result := Gdip_SaveBitmapToFile(pPreviewBitmap, TempImagePath)
            if (result != 0) {
                throw Error("淇濆瓨棰勮鍥剧墖澶辫触锛岄敊璇唬鐮? " . result)
            }
        } catch as e {
            TrayTip("閿欒", "淇濆瓨棰勮鍥剧墖澶辫触: " . e.Message, "Iconx 2")
            this.SafeGdipDeleteGraphics(pGraphics)
            this.SafeGdipDisposeImage(pPreviewBitmap)
            this.SafeGdipDisposeImage(pBitmap)
            try {
                Gdip_Shutdown(pToken)
            } catch as e {
                ; 蹇界暐鍏抽棴閿欒
            }
            return
        }
        PreviewPic := EditorGui.Add("Picture", "x0 y" . PreviewY . " w" . PreviewWidth . " h" . PreviewHeight, TempImagePath)
        
        ; 涓哄浘鐗囨帶浠舵坊鍔犳嫋鍔ㄥ姛鑳斤紙Picture鎺т欢鏀寔Click浜嬩欢锛?
        PreviewPic.OnEvent("Click", (*) => this.ScreenshotEditorDragWindow())
        PreviewPic.OnEvent("ContextMenu", ObjBindMethod(ScreenshotEditorPlugin, "OnScreenshotEditorContextMenu"))
        this.ScreenshotEditorPreviewPic := PreviewPic
        
        ; 鍒涘缓鐙珛鐨勬偓娴伐鍏锋爮绐楀彛锛圵ebView2 鎵胯浇鐙珛 HTML锛?
        this.GuiID_ScreenshotToolbar := Gui("+AlwaysOnTop +ToolWindow -Caption -DPIScale")
        ; 涓嶅啀浣跨敤 TransColor 鑹查敭閫忔槑锛氬湪閮ㄥ垎鏈哄櫒/WebView2 缁勫悎涓嬩細鍑虹幇鐐瑰嚮绌块€忥紝瀵艰嚧鎸夐挳鏃犳硶鐢熸晥
        this.GuiID_ScreenshotToolbar.BackColor := this.ScreenshotToolbarThemeHex("toolbarBg")
        ToolbarWidth := this.ScreenshotToolbarCurrentWidth
        ToolbarHeight := this.ScreenshotToolbarCurrentHeight
        this.ScreenshotToolbarWV2Ctrl := 0
        this.ScreenshotToolbarWV2 := 0
        this.ScreenshotToolbarWV2Ready := false
        this.ScreenshotToolbarWV2PaintOk := false
        this.ScreenshotToolbarNativeFallback := false
        this.ScreenshotToolbarCreateCheckPass := 0
        this.GuiID_ScreenshotToolbar.OnEvent("Size", ObjBindMethod(ScreenshotEditorPlugin, "ScreenshotToolbar_OnSize"))
        try WebView2.create(this.GuiID_ScreenshotToolbar.Hwnd, ObjBindMethod(ScreenshotEditorPlugin, "ScreenshotToolbar_OnCreated"), WebView2_EnsureSharedEnvBlocking())
        
        ; [鍏抽棴] 鎸夐挳锛堝湪鏍囬鏍忓彸渚э紝鏈€鍚庡垱寤轰互纭繚鍦ㄦ渶涓婂眰锛?
        if (!this.ScreenshotEditorCloseBtn || this.ScreenshotEditorCloseBtn = 0) {
            this.ScreenshotEditorCloseBtn := EditorGui.Add("Text", "x" . (WindowWidth - 40) . " y0 w40 h" . TitleBarHeight . " Center 0x200 cFFFFFF Background" . UI_Colors.BtnDanger, "×")
            this.ScreenshotEditorCloseBtn.SetFont("s12", "Segoe UI")
            this.ScreenshotEditorCloseBtn.OnEvent("Click", (*) => this.CloseScreenshotEditor())
            HoverBtnWithAnimation(this.ScreenshotEditorCloseBtn, UI_Colors.BtnDanger, UI_Colors.BtnDangerHover)
        }
        
        ; 娣诲姞閿洏浜嬩欢
        EditorGui.OnEvent("Escape", (*) => this.CloseScreenshotEditor())
        
        ; 涓庡叏灞€鍚屾锛氭鍚?CloseScreenshotEditor / 鍚屾宸ュ叿鏍忕瓑渚濊禆 this.GuiID_ScreenshotEditor
        this.GuiID_ScreenshotEditor := EditorGui
        ScreenshotEditorPlugin._SyncHub()
        
        ; 璁＄畻绐楀彛浣嶇疆锛堝睆骞曞眳涓級
        ScreenInfo := GetScreenInfo(1)
        if (!IsObject(ScreenInfo) || !ScreenInfo.HasProp("Width") || !ScreenInfo.HasProp("Height")) {
            throw Error("鏃犳硶鑾峰彇灞忓箷淇℃伅")
        }
        WindowX := (ScreenInfo.Width - WindowWidth) // 2
        WindowY := (ScreenInfo.Height - WindowHeight) // 2
        
        ; 纭繚鎵€鏈夊彉閲忛兘鏄暟瀛楃被鍨?
        WindowX := Integer(WindowX)
        WindowY := Integer(WindowY)
        WindowWidth := Integer(WindowWidth)
        WindowHeight := Integer(WindowHeight)
        
        ; 娉ㄦ剰锛氫笉鍙湪姝ゅ璋冪敤 this.CloseAllScreenshotWindows() 鈥斺€?璇ュ嚱鏁颁細 this.CloseScreenshotEditor()锛?
        ; 鍒氬垱寤虹殑 this.GuiID_ScreenshotEditor 浼氳閿€姣侊紝闅忓悗 .Show() 浼氬鏁存暟 0 璋冪敤鑰屾姤閿欍€?
        ; 鏃ч瑙堢獥宸插湪鍑芥暟寮€澶村叧闂紱绯荤粺鎴浘宸ュ叿鐢辫皟鐢ㄦ柟鍦?ShowScreenshotEditor 涔嬪墠宸插鐞嗐€?
        
        ; 寮哄埗婵€娲绘闈紝纭繚鎴戜滑鐨勭獥鍙ｈ兘鏄剧ず鍦ㄦ渶鍓嶉潰
        try {
            WinActivate("Program Manager")
            Sleep(50)
        }
        
        ; 鏄剧ず涓荤獥鍙?
        if (DebugGui) {
            UpdateDebugStep(DebugGui, 23, "鏄剧ず鎴浘鍔╂墜绐楀彛...", false)
        }
        ; 浣跨敤灞€閮?EditorGui 璋冪敤 Show锛岄伩鍏嶅叏灞€鍙橀噺鍦ㄦ瀬灏戞暟鎯呭喌涓嬮潪瀵硅薄鏃跺穿婧?
        EditorGui.Show("w" . WindowWidth . " h" . WindowHeight . " x" . WindowX . " y" . WindowY)
        
        ; 婵€娲荤獥鍙ｅ苟纭繚鍦ㄦ渶鍓嶉潰
        try {
            WinActivate("ahk_id " . EditorGui.Hwnd)
            Sleep(50)
            ; 纭繚绐楀彛鑾峰緱鐒︾偣
            WinSetAlwaysOnTop("On", "ahk_id " . EditorGui.Hwnd)
            WinSetAlwaysOnTop("Off", "ahk_id " . EditorGui.Hwnd)
        } catch as e {
        }
        
        if (DebugGui) {
            UpdateDebugStep(DebugGui, 23, "鎴浘鍔╂墜绐楀彛宸叉樉绀猴紒", true)
        }
        
        ; 璁＄畻宸ュ叿鏍忎綅缃紙鏀惧湪涓荤獥鍙ｄ笅鏂癸級
        ToolbarX := WindowX
        ToolbarY := WindowY + WindowHeight + 10
        
        ; 鏄剧ず鎮诞宸ュ叿鏍?
        this.GuiID_ScreenshotToolbar.Show("w" . ToolbarWidth . " h" . ToolbarHeight . " x" . ToolbarX . " y" . ToolbarY)
        this.ScreenshotToolbar_NotifyHostMemory(true)
        this.ScreenshotToolbar_ApplyWindowRegion()
        this.ScreenshotToolbar_ApplyBounds()
        SetTimer(ObjBindMethod(ScreenshotEditorPlugin, "ScreenshotToolbar_RefreshComposition"), -40)
        SetTimer(ObjBindMethod(ScreenshotEditorPlugin, "ScreenshotToolbar_EnsureCreated"), -900)
        SetTimer(ObjBindMethod(ScreenshotEditorPlugin, "ScreenshotToolbar_EnsureUsable"), -1200)
        
        ; 婵€娲诲伐鍏锋爮绐楀彛
        try {
            WinActivate("ahk_id " . this.GuiID_ScreenshotToolbar.Hwnd)
        } catch as e {
        }
        
        ; 鍐嶆婵€娲讳富绐楀彛纭繚瀹冨湪鏈€鍓嶉潰
        Sleep(50)
        try {
            WinActivate("ahk_id " . EditorGui.Hwnd)
        } catch as e {
        }
        
        ; 浣跨敤鍘熺敓 Windows API 纭繚绐楀彛缃《骞舵縺娲?
        try {
            hwnd := EditorGui.Hwnd
            ; 浠呯疆椤讹紝涓嶇Щ鍔ㄥ綋鍓嶄綅缃紙淇濈暀鍓嶉潰宸茶绠楀ソ鐨勫眳涓潗鏍囷級
            DllCall("SetWindowPos", "Ptr", hwnd, "Ptr", -1, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x0001 | 0x0002 | 0x0004)
            DllCall("SetForegroundWindow", "Ptr", hwnd)
            Sleep(50)
            ; 鍐嶆纭繚缃《
            DllCall("SetWindowPos", "Ptr", hwnd, "Ptr", -1, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x0001 | 0x0002 | 0x0004)
        } catch as e {
        }
        
        ; 鍚屾椂涔熸縺娲诲伐鍏锋爮绐楀彛
        try {
            toolbarHwnd := this.GuiID_ScreenshotToolbar.Hwnd
            ; 宸ュ叿鏍忓悓鏍峰彧缃《锛屼笉閲嶇疆鍒板乏涓婅
            DllCall("SetWindowPos", "Ptr", toolbarHwnd, "Ptr", -1, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x0001 | 0x0002 | 0x0004)
        } catch as e {
        }
        
        ; 鍒濆鍖栫紪杈戠姸鎬?
        
        ; 淇濆瓨涓存椂鍥剧墖璺緞
        this.ScreenshotEditorImagePath := TempImagePath
        
    } catch as e {
        ; 鏄剧ず璇︾粏鐨勯敊璇瘖鏂俊鎭?
        this.ShowScreenshotErrorDiagnostics(e)
        this.CloseScreenshotEditor()
    } finally {
        this.g_ShowScreenshotEditorInFlight := false
    }
}

; 鏄剧ず鎴浘鍔╂墜閿欒璇婃柇淇℃伅
    static ShowScreenshotErrorDiagnostics(e) {
    global ScreenshotClipboard
    
    ; 鏀堕泦璇婃柇淇℃伅
    ErrorInfo := "銆愰敊璇瘖鏂姤鍛娿€慲n`n"
    ErrorInfo .= "鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺恅n"
    ErrorInfo .= "閿欒娑堟伅: " . e.Message . "`n"
    ErrorInfo .= "閿欒鏂囦欢: " . (e.File ? e.File : "鏈煡") . "`n"
    ErrorInfo .= "閿欒琛屽彿: " . (e.Line ? e.Line : "鏈煡") . "`n"
    ErrorInfo .= "鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺愨晲鈺恅n`n"
    
    ; 妫€鏌ュ叧閿彉閲忕姸鎬?
    ErrorInfo .= "銆愬叧閿彉閲忕姸鎬併€慲n"
    ErrorInfo .= "鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€`n"
    ErrorInfo .= "ScreenshotClipboard: " . (ScreenshotClipboard ? "已设置(长度: " . (IsObject(ScreenshotClipboard) ? "对象" : StrLen(String(ScreenshotClipboard))) . ")" : "未设置") . "`n"
    ; 淇锛歵his.GuiID_ScreenshotEditor 鏄疓ui瀵硅薄锛屼笉鑳界洿鎺ョ敤浜庡瓧绗︿覆杩炴帴
    if (this.GuiID_ScreenshotEditor && IsObject(this.GuiID_ScreenshotEditor)) {
        ErrorInfo .= "this.GuiID_ScreenshotEditor: 宸插垱寤?(Hwnd: " . (this.GuiID_ScreenshotEditor.Hwnd ? this.GuiID_ScreenshotEditor.Hwnd : "鏈煡") . ")`n"
    } else {
        ErrorInfo .= "this.GuiID_ScreenshotEditor: " . (this.GuiID_ScreenshotEditor ? String(this.GuiID_ScreenshotEditor) : "0 (鏈垱寤?") . "`n"
    }
    ErrorInfo .= "this.ScreenshotEditorBitmap: " . (this.ScreenshotEditorBitmap ? this.ScreenshotEditorBitmap : "0 (鏈垱寤?") . "`n"
    ErrorInfo .= "this.ScreenshotEditorGraphics: " . (this.ScreenshotEditorGraphics ? this.ScreenshotEditorGraphics : "0 (鏈垱寤?") . "`n"
    ErrorInfo .= "鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€`n`n"
    
    ; 鍙兘鐨勫師鍥犲垎鏋?
    ErrorInfo .= "銆愬彲鑳界殑鍘熷洜鍒嗘瀽銆慲n"
    ErrorInfo .= "鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€`n"
    
    ; 妫€鏌ユ槸鍚︽槸 GDI+ 鐩稿叧閿欒
    if (InStr(e.Message, "GDI") || InStr(e.Message, "Gdip") || InStr(e.Message, "gdiplus")) {
        ErrorInfo .= "鉂?GDI+ 搴撶浉鍏抽敊璇痐n"
        ErrorInfo .= "   - 鍙兘鍘熷洜: Gdip_Startup() 澶辫触鎴栧簱鏈纭姞杞絗n"
        ErrorInfo .= "   - 妫€鏌ョ偣: 纭 gdiplus.dll 鏄惁鍙敤`n"
        ErrorInfo .= "   - 寤鸿: 閲嶅惎鑴氭湰鎴栨鏌ョ郴缁?GDI+ 鏀寔`n`n"
    }
    
    ; 妫€鏌ユ槸鍚︽槸鍓创鏉跨浉鍏抽敊璇?
    if (InStr(e.Message, "clipboard") || InStr(e.Message, "剪贴板") || !ScreenshotClipboard) {
        ErrorInfo .= "鉂?鍓创鏉挎暟鎹敊璇痐n"
        ErrorInfo .= "   - 鍙兘鍘熷洜: 鎴浘鏁版嵁鏈纭繚瀛樺埌鍓创鏉縛n"
        ErrorInfo .= "   - 妫€鏌ョ偣: ScreenshotClipboard 鍙橀噺鐘舵€乣n"
        ErrorInfo .= "   - 寤鸿: 閲嶆柊鎴浘鎴栨鏌ユ埅鍥惧伐鍏锋槸鍚︽甯稿伐浣渀n`n"
    }
    
    ; 妫€鏌ユ槸鍚︽槸浣嶅浘鐩稿叧閿欒
    if (InStr(e.Message, "bitmap") || InStr(e.Message, "浣嶅浘") || InStr(e.Message, "Bitmap")) {
        ErrorInfo .= "鉂?浣嶅浘澶勭悊閿欒`n"
        ErrorInfo .= "   - 鍙兘鍘熷洜: 浣嶅浘鍒涘缓鎴栬浆鎹㈠け璐n"
        ErrorInfo .= "   - 妫€鏌ョ偣: hBitmap 鎴?pBitmap 鏄惁鏈夋晥`n"
        ErrorInfo .= "   - 寤鸿: 妫€鏌?WinClip.GetBitmap() 杩斿洖鍊糮n`n"
    }
    
    ; 妫€鏌ユ槸鍚︽槸鏂囦欢鎿嶄綔閿欒
    if (InStr(e.Message, "file") || InStr(e.Message, "鏂囦欢") || InStr(e.Message, "File")) {
        ErrorInfo .= "鉂?鏂囦欢鎿嶄綔閿欒`n"
        ErrorInfo .= "   - 鍙兘鍘熷洜: 涓存椂鏂囦欢鍒涘缓鎴栦繚瀛樺け璐n"
        ErrorInfo .= "   - 妫€鏌ョ偣: A_Temp 鐩綍鏉冮檺鍜岀鐩樼┖闂碻n"
        ErrorInfo .= "   - 寤鸿: 妫€鏌ヤ复鏃剁洰褰曟槸鍚﹀彲鍐檂n`n"
    }
    
    ; 妫€鏌ユ槸鍚︽槸 GUI 鐩稿叧閿欒
    if (InStr(e.Message, "GUI") || InStr(e.Message, "Gui") || InStr(e.Message, "绐楀彛")) {
        ErrorInfo .= "鉂?GUI 鍒涘缓閿欒`n"
        ErrorInfo .= "   - 鍙兘鍘熷洜: 绐楀彛鍒涘缓鎴栨帶浠舵坊鍔犲け璐n"
        ErrorInfo .= "   - 妫€鏌ョ偣: UI_Colors 鍙橀噺鏄惁宸插垵濮嬪寲`n"
        ErrorInfo .= "   - 寤鸿: 妫€鏌?GUI 鐩稿叧鍙橀噺鍜岃祫婧恅n`n"
    }
    
    ; 閫氱敤閿欒鎻愮ず
    if (!InStr(ErrorInfo, "❂")) {
        ErrorInfo .= "鈿狅笍 鏈瘑鍒殑閿欒绫诲瀷`n"
        ErrorInfo .= "   - 閿欒娑堟伅: " . e.Message . "`n"
        ErrorInfo .= "   - 寤鸿: 鏌ョ湅閿欒琛屽彿鍜屾枃浠跺畾浣嶉棶棰榒n`n"
    }
    
    ErrorInfo .= "鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€`n`n"
    
    ; 璋冭瘯寤鸿
    ErrorInfo .= "銆愯皟璇曞缓璁€慲n"
    ErrorInfo .= "鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€`n"
    ErrorInfo .= "1. 妫€鏌ラ敊璇彂鐢熺殑鍏蜂綋琛屽彿: " . (e.Line ? e.Line : "鏈煡") . "`n"
    ErrorInfo .= "2. 妫€鏌ラ敊璇枃浠? " . (e.File ? e.File : "鏈煡") . "`n"
    ErrorInfo .= "3. 纭鎴浘鏄惁鎴愬姛瀹屾垚`n"
    ErrorInfo .= "4. 妫€鏌ョ郴缁熷壀璐存澘鏄惁鍖呭惈鍥剧墖鏁版嵁`n"
    ErrorInfo .= "5. 灏濊瘯閲嶆柊杩愯鑴氭湰`n"
    ErrorInfo .= "鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€鈹€`n"
    
    ; 鏄剧ず閿欒璇婃柇绐楀彛
    ErrorGui := Gui("+AlwaysOnTop +ToolWindow -MaximizeBox -MinimizeBox", "鎴浘鍔╂墜閿欒璇婃柇")
    ErrorGui.BackColor := "0x1E1E1E"
    ErrorGui.SetFont("s10", "Consolas")
    
    ; 閿欒淇℃伅鏄剧ず鍖哄煙
    ErrorText := ErrorGui.Add("Edit", "x10 y10 w800 h500 ReadOnly Multi Background 0x2D2D2D c0xCCCCCC", ErrorInfo)
    ErrorText.SetFont("s9", "Consolas")
    
    ; 鍏抽棴鎸夐挳
    CloseBtn := ErrorGui.Add("Button", "x350 y520 w120 h35 Default", "鍏抽棴")
    CloseBtn.OnEvent("Click", (*) => ErrorGui.Destroy())
    
    ; 澶嶅埗閿欒淇℃伅鎸夐挳
    CopyBtn := ErrorGui.Add("Button", "x480 y520 w120 h35", "澶嶅埗淇℃伅")
    CopyBtn.OnEvent("Click", (*) => this.CopyErrorInfoToClipboard(ErrorInfo))
    
    ; 鏄剧ず绐楀彛
    ErrorGui.Show("w820 h570")
    
    ; 鍚屾椂鏄剧ず绯荤粺鎻愮ず
    TrayTip("閿欒", "鏄剧ず鎴浘鍔╂墜澶辫触锛屽凡寮瑰嚭璇︾粏璇婃柇绐楀彛", "Iconx 2")
}

; 澶嶅埗閿欒淇℃伅鍒板壀璐存澘鐨勮緟鍔╁嚱鏁?
    static CopyErrorInfoToClipboard(ErrorInfo) {
    A_Clipboard := ErrorInfo
    TrayTip("提示", "错误信息已复制到剪贴板", "Iconi 1")
}

; 鎴浘鍔╂墜绐楀彛鎷栧姩鍑芥暟
    static ScreenshotEditorDragWindow(*) {
    
    try {
        if (this.GuiID_ScreenshotEditor && this.GuiID_ScreenshotEditor != 0) {
            ; 鍙戦€佹嫋鍔ㄦ秷鎭紙WM_NCLBUTTONDOWN with HTCAPTION = 2锛?
            ; 浣跨敤 PostMessage锛屽弬鏁版牸寮忥細PostMessage(Msg, wParam, lParam, Control, WinTitle)
            PostMessage(0xA1, 2, 0, , "ahk_id " . this.GuiID_ScreenshotEditor.Hwnd)
        }
    } catch as e {
        ; 濡傛灉澶辫触锛屽皾璇曠洿鎺ヤ娇鐢ㄧ獥鍙ｅ彞鏌?
        try {
            if (this.GuiID_ScreenshotEditor && this.GuiID_ScreenshotEditor.Hwnd) {
                PostMessage(0xA1, 2, 0, 0, this.GuiID_ScreenshotEditor.Hwnd)
            }
        } catch {
            ; 蹇界暐閿欒
        }
    }
}

; 宸ュ叿鏍忔嫋鍔ㄧ獥鍙ｅ嚱鏁?
    static ScreenshotToolbarDragWindow(*) {
    
    try {
        if (this.GuiID_ScreenshotToolbar && this.GuiID_ScreenshotToolbar != 0) {
            ; 鍙戦€佹嫋鍔ㄦ秷鎭紙WM_NCLBUTTONDOWN with HTCAPTION = 2锛?
            PostMessage(0xA1, 2, 0, , "ahk_id " . this.GuiID_ScreenshotToolbar.Hwnd)
        }
    } catch as e {
        ; 濡傛灉澶辫触锛屽皾璇曠洿鎺ヤ娇鐢ㄧ獥鍙ｅ彞鏌?
        try {
            if (this.GuiID_ScreenshotToolbar && this.GuiID_ScreenshotToolbar.Hwnd) {
                PostMessage(0xA1, 2, 0, 0, this.GuiID_ScreenshotToolbar.Hwnd)
            }
        } catch {
            ; 蹇界暐閿欒
        }
    }
}

    static ScreenshotToolbarNormalizeTheme(raw, fallback := "dark") {
    s := StrLower(Trim(String(raw)))
    if (s = "light" || s = "lite" || s = "娴呰壊")
        return "light"
    if (s = "dark" || s = "娣辫壊")
        return "dark"
    return (fallback = "light") ? "light" : "dark"
}

    static ScreenshotToolbarGetThemeMode() {
    try {
        global ConfigFile
        if (IsSet(ConfigFile) && ConfigFile != "") {
            raw := IniRead(ConfigFile, "Settings", "ThemeMode", "")
            if (Trim(String(raw)) = "")
                raw := IniRead(ConfigFile, "Appearance", "ThemeMode", "")
            if (Trim(String(raw)) != "")
                return this.ScreenshotToolbarNormalizeTheme(raw, "dark")
        }
    } catch {
    }
    try {
        fn := Func("ReadPersistedThemeMode")
        if IsObject(fn)
            return this.ScreenshotToolbarNormalizeTheme(fn.Call(), "dark")
    } catch {
    }
    try {
        global ThemeMode
        return this.ScreenshotToolbarNormalizeTheme(ThemeMode, "dark")
    } catch {
    }
    return "dark"
}

    static ScreenshotToolbarThemeHex(key) {
    tm := this.ScreenshotToolbarGetThemeMode()
    if (tm = "light") {
        mp := Map(
            "toolbarBg", "f7f7f7",
            "panelBg", "ffffff",
            "panelBorder", "e5e5e5",
            "btnBg", "ffffff",
            "btnBorder", "e5e5e5",
            "btnFg", "e67e22",
            "dangerBg", "fff5f5",
            "dangerBorder", "e6b0aa",
            "dangerFg", "c0392b",
            "sep", "e5e5e5"
        )
    } else {
        mp := Map(
            "toolbarBg", "0f1114",
            "panelBg", "14171b",
            "panelBorder", "663c1f",
            "btnBg", "14171b",
            "btnBorder", "663c1f",
            "btnFg", "ff9d3a",
            "dangerBg", "251417",
            "dangerBorder", "73414a",
            "dangerFg", "ff8a95",
            "sep", "5a3a20"
        )
    }
    return mp.Has(key) ? mp[key] : ((tm = "light") ? "f7f7f7" : "0f1114")
}

    static ScreenshotToolbarThemeArgb() {
    tm := this.ScreenshotToolbarGetThemeMode()
    return (tm = "light") ? 0xFFF7F7F7 : 0xFF0A0A0A
}

    static ScreenshotToolbar_OnCreated(ctrl) {
    this.ScreenshotToolbarWV2Ctrl := ctrl
    this.ScreenshotToolbarWV2 := ctrl.CoreWebView2
    this.ScreenshotToolbarWV2Ready := false
    this.ScreenshotToolbarWV2PaintOk := false
    this.ScreenshotToolbarCreateCheckPass := 0
    try this.ScreenshotToolbarWV2Ctrl.DefaultBackgroundColor := this.ScreenshotToolbarThemeArgb()
    try {
        s := this.ScreenshotToolbarWV2.Settings
        s.AreDefaultContextMenusEnabled := false
        s.AreDevToolsEnabled := true
    }
    ApplyWebView2PerformanceSettings(this.ScreenshotToolbarWV2)
    WebView2_RegisterHostBridge(this.ScreenshotToolbarWV2)
    try this.ScreenshotToolbarWV2Ctrl.IsVisible := true
    try this.ScreenshotToolbarWV2.add_WebMessageReceived(ObjBindMethod(ScreenshotEditorPlugin, "ScreenshotToolbar_OnMessage"))
    try this.ScreenshotToolbarWV2.add_NavigationCompleted(ObjBindMethod(ScreenshotEditorPlugin, "ScreenshotToolbar_OnNavigationCompleted"))
    htmlPath := A_ScriptDir "\ScreenshotToolbarWebView.html"
    try {
        if FileExist(htmlPath) {
            tm := this.ScreenshotToolbarGetThemeMode()
            html := FileRead(htmlPath, "UTF-8")
            bodyTag := Format('<body data-theme="{1}" class="theme-ready">', tm)
            html := StrReplace(html, "<body>", bodyTag, , , 1)
            this.ScreenshotToolbarWV2.NavigateToString(html)
        } else {
            try ApplyUnifiedWebViewAssets(this.ScreenshotToolbarWV2)
            this.ScreenshotToolbarWV2.Navigate(BuildAppLocalUrl("ScreenshotToolbarWebView.html"))
        }
    } catch as e {
        try this.ScreenshotToolbarWV2.NavigateToString("<!doctype html><html><body style='margin:0;background:#0a0a0a;color:#ff9d3a;font:12px Segoe UI;padding:10px'>鎴浘宸ュ叿鏍忓姞杞藉け璐? " . e.Message . "</body></html>")
    }
    this.ScreenshotToolbar_ApplyBounds()
}

    static ScreenshotToolbar_EnsureCreated(*) {
    if this.ScreenshotToolbarWV2Ctrl {
        this.ScreenshotToolbarCreateCheckPass := 0
        return
    }
    this.ScreenshotToolbarCreateCheckPass += 1
    if (this.ScreenshotToolbarCreateCheckPass < 6) {
        SetTimer(ObjBindMethod(ScreenshotEditorPlugin, "ScreenshotToolbar_EnsureCreated"), -800)
        return
    }
    ; Prefer WebView lucide toolbar; avoid dropping to legacy text/icon fallback.
    try {
        if (IsObject(this.GuiID_ScreenshotToolbar) && this.GuiID_ScreenshotToolbar != 0)
            WebView2.create(this.GuiID_ScreenshotToolbar.Hwnd, ObjBindMethod(ScreenshotEditorPlugin, "ScreenshotToolbar_OnCreated"), WebView2_EnsureSharedEnvBlocking())
    } catch {
    }
}

    static ScreenshotToolbar_OnNavigationCompleted(sender, args) {
    try ok := args.IsSuccess
    catch
        ok := true
    if ok
        return
    try sender.NavigateToString("<!doctype html><html><body style='margin:0;background:#0a0a0a;color:#ff9d3a;font:12px Segoe UI;padding:10px'>鎴浘宸ュ叿鏍忛〉闈㈠姞杞藉け璐?/body></html>")
}

    static ScreenshotToolbar_OnSize(*) {
    this.ScreenshotToolbar_ApplyBounds()
}

    static ScreenshotToolbar_ApplyBounds() {
    if !(IsObject(this.GuiID_ScreenshotToolbar) && this.GuiID_ScreenshotToolbar != 0)
        return
    if !this.ScreenshotToolbarWV2Ctrl
        return
    WinGetClientPos(, , &cw, &ch, this.GuiID_ScreenshotToolbar.Hwnd)
    rc := WebView2.RECT()
    rc.left := 0
    rc.top := 0
    rc.right := cw
    rc.bottom := ch
    this.ScreenshotToolbarWV2Ctrl.Bounds := rc
}

    static ScreenshotToolbar_NotifyHostMemory(shown) {
    if shown
        WebView2_NotifyShown(this.ScreenshotToolbarWV2)
    else
        WebView2_NotifyHidden(this.ScreenshotToolbarWV2)
}

    static ScreenshotToolbar_RefreshComposition(*) {
    if !this.ScreenshotToolbarWV2Ctrl
        return
    try {
        this.ScreenshotToolbar_ApplyBounds()
        this.ScreenshotToolbarWV2Ctrl.NotifyParentWindowPositionChanged()
    }
}

    static ScreenshotToolbar_OnMessage(sender, args) {
    jsonStr := args.WebMessageAsJson
    try msg := Jxon_Load(jsonStr)
    catch
        return
    if !(msg is Map)
        return
    action := msg.Has("action") ? msg["action"] : (msg.Has("type") ? msg["type"] : "")
    switch action {
        case "ready":
            this.ScreenshotToolbarWV2Ready := true
            this.ScreenshotToolbar_SendState()
            this.ScreenshotToolbar_SendDockConfig()
        case "nmDockReady":
            this.ScreenshotToolbar_SendDockConfig()
        case "nmDockLeave":
            ; lifecycle handled by ShowScreenshotEditor/CloseScreenshotEditor
        case "nmDockCmd":
            this.ScreenshotToolbar_ExecuteDockCmd(msg)
        case "paint_ok":
            this.ScreenshotToolbarWV2PaintOk := true
        case "layout":
            this.ScreenshotToolbar_ApplyLayout(msg.Get("width", 0), msg.Get("height", 0))
        case "dragWindow":
            this.ScreenshotToolbarDragWindow()
        case "invoke":
            cmd := msg.Get("cmd", "")
            this.ScreenshotToolbar_InvokeCommand(cmd)
    }
}

    static ScreenshotToolbar_SendDockConfig() {
    arr := []
    try {
        if IsSet(_LoadCommands)
            _LoadCommands()
        global g_Commands
        if (g_Commands is Map && g_Commands.Has("SceneToolbarLayout") && g_Commands["SceneToolbarLayout"] is Array) {
            for row in g_Commands["SceneToolbarLayout"] {
                if !(row is Map) || !row.Has("sceneId")
                    continue
                sid := Trim(String(row["sceneId"]))
                if (sid = "")
                    continue
                arr.Push(Map(
                    "sceneId", sid,
                    "visible_in_bar", row.Has("visible_in_bar") ? (row["visible_in_bar"] ? true : false) : true,
                    "order_bar", row.Has("order_bar") ? Integer(row["order_bar"]) : -1
                ))
            }
        }
    } catch {
    }
    try this.ScreenshotToolbarWV2.PostWebMessageAsJson(WebView_DumpJson(Map("type", "nmDockConfig", "sceneToolbarLayout", arr)))
}

    static ScreenshotToolbar_ExecuteDockCmd(msg) {
    cmdId0 := msg.Has("cmdId") ? String(msg["cmdId"]) : ""
    if (cmdId0 = "")
        return
    if (cmdId0 = "open_cloudplayer") {
        try ShowCloudPlayer()
        return
    }
    m0 := Map(
        "Title", "dock",
        "Content", "",
        "DataType", "text",
        "OriginalDataType", "text",
        "Source", "dock",
        "ClipboardId", 0,
        "PromptMergedIndex", 0,
        "HubSegIndex", -1
    )
    try SC_ExecuteContextCommand(cmdId0, 0, m0)
    catch as err {
        OutputDebug("[ScreenshotToolbar] nmDockCmd: " . err.Message)
    }
}

    static ScreenshotToolbar_InvokeCommand(cmd) {
    switch cmd {
        case "pin":
            this.ToggleScreenshotEditorAlwaysOnTop()
        case "ocr":
            this.ExecuteScreenshotOCR()
        case "ocr_edit":
            this.ScreenshotEditorEditOCRInHubCapsule()
        case "text":
            this.PasteScreenshotAsText()
        case "save":
            this.SaveScreenshotToFile()
        case "ai":
            this.ScreenshotEditorSendToAI()
        case "search":
            this.ScreenshotEditorSearchText()
        case "color":
            this.ScreenshotEditorToggleColorPicker()
        case "close":
            this.CloseScreenshotEditor()
    }
}

    static ScreenshotToolbar_SendState() {
    if !this.ScreenshotToolbarWV2 || !this.ScreenshotToolbarWV2Ready
        return
    try this.ScreenshotToolbarWV2.PostWebMessageAsJson(
        WebView_DumpJson(Map(
            "type", "state",
            "toolbarVisible", this.ScreenshotEditorToolbarVisible,
            "themeMode", this.ScreenshotToolbarGetThemeMode()
        ))
    )
}

    static ScreenshotToolbar_ApplyLayout(width, height) {

    try {
        w := Integer(Round(Float(width)))
        h := Integer(Round(Float(height)))
    } catch {
        return
    }

    if (w <= 0 || h <= 0)
        return

    w := Max(240, Min(960, w))
    h := Max(40, Min(120, h))
    this.ScreenshotToolbarCurrentWidth := w
    this.ScreenshotToolbarCurrentHeight := h

    if !(IsObject(this.GuiID_ScreenshotToolbar) && this.GuiID_ScreenshotToolbar != 0)
        return

    tx := 0
    ty := 0
    if (IsObject(this.GuiID_ScreenshotEditor) && this.GuiID_ScreenshotEditor != 0) {
        try {
            WinGetPos(&ex, &ey, , &eh, "ahk_id " . this.GuiID_ScreenshotEditor.Hwnd)
            tx := ex
            ty := ey + eh + 10
        } catch {
            WinGetPos(&tx, &ty, , , "ahk_id " . this.GuiID_ScreenshotToolbar.Hwnd)
        }
    } else {
        WinGetPos(&tx, &ty, , , "ahk_id " . this.GuiID_ScreenshotToolbar.Hwnd)
    }

    try this.GuiID_ScreenshotToolbar.Show("x" . tx . " y" . ty . " w" . w . " h" . h)
    this.ScreenshotToolbar_NotifyHostMemory(true)
    this.ScreenshotToolbar_ApplyWindowRegion()
    this.ScreenshotToolbar_ApplyBounds()
    SetTimer(ObjBindMethod(ScreenshotEditorPlugin, "ScreenshotToolbar_RefreshComposition"), -30)
}

    static ScreenshotToolbar_ApplyWindowRegion() {
    if !(IsObject(this.GuiID_ScreenshotToolbar) && this.GuiID_ScreenshotToolbar != 0)
        return
    hwnd := this.GuiID_ScreenshotToolbar.Hwnd
    if !hwnd
        return
    try WinGetPos(, , &w, &h, "ahk_id " . hwnd)
    catch
        return
    if (w < 20 || h < 20)
        return
    ; 涓?HTML 鍗＄墖鍦嗚涓€鑷达紙radius鈮?2px -> ellipse 24x24锛?
    rgn := DllCall("gdi32\CreateRoundRectRgn", "Int", 0, "Int", 0, "Int", w + 1, "Int", h + 1, "Int", 24, "Int", 24, "Ptr")
    if !rgn
        return
    ; SetWindowRgn 鎴愬姛鍚庣郴缁熸帴绠?rgn 鍙ユ焺
    DllCall("user32\SetWindowRgn", "Ptr", hwnd, "Ptr", rgn, "Int", 1)
}

    static ScreenshotToolbar_EnsureUsable(*) {
    if !this.ScreenshotToolbarWV2 {
        ; Keep retrying WebView path so toolbar stays lucide-style.
        SetTimer(ObjBindMethod(ScreenshotEditorPlugin, "ScreenshotToolbar_EnsureCreated"), -300)
        return
    }
    ; 鑻ラ甯т粛鏈畬鎴愶紝鍒囨崲鍒版瀬绠€瀹夊叏鐗?HTML锛屼繚璇佹寜閽彲瑙?
    if (!this.ScreenshotToolbarWV2PaintOk) {
        try {
            safeHtml := this.ScreenshotToolbar_BuildSafeInlineHtml()
            safeHtml := StrReplace(safeHtml, "applyTheme('dark');", "applyTheme('" . this.ScreenshotToolbarGetThemeMode() . "');", , , 1)
            this.ScreenshotToolbarWV2.NavigateToString(safeHtml)
        }
        SetTimer(ObjBindMethod(ScreenshotEditorPlugin, "ScreenshotToolbar_RefreshComposition"), -60)
        SetTimer(ObjBindMethod(ScreenshotEditorPlugin, "ScreenshotToolbar_EnsureUsableSecondPass"), -700)
    }
}

    static ScreenshotToolbar_EnsureUsableSecondPass(*) {
    if !this.ScreenshotToolbarWV2PaintOk {
        ; 淇濇寔 WebView 瀹夊叏椤碉紝涓嶅啀闄嶇骇鍒版枃瀛楁寜閽吋瀹规爮
        try this.ScreenshotToolbarWV2PaintOk := true
        try this.ScreenshotToolbarWV2Ready := true
        try this.ScreenshotToolbar_SendState()
        TrayTip("截图工具栏", "已使用安全图示渲染模式", "Iconi 1")
    }
}

    static ScreenshotToolbar_BuildSafeInlineHtml() {
    return "
(
<!doctype html>
<html><head><meta charset='utf-8'><meta name='viewport' content='width=device-width,initial-scale=1'>
<style>
:root{--bg:#0a0a0a;--panel:#14171b;--panel-bd:#663c1f;--fg:#ff9d3a;--fg-soft:rgba(255,157,58,.14);--fg-bd:rgba(255,157,58,.42);--danger:#ff8a95;--danger-soft:rgba(255,138,149,.18);--danger-bd:#73414a;--sep:#5a3a20}
body[data-theme='light']{--bg:#f7f7f7;--panel:#ffffff;--panel-bd:#e5e5e5;--fg:#e67e22;--fg-soft:#fff3e8;--fg-bd:#d35400;--danger:#c0392b;--danger-soft:#fdecea;--danger-bd:#e6b0aa;--sep:#e5e5e5}
*{box-sizing:border-box}
html,body{margin:0;padding:0;width:100%;height:100%;background:var(--bg);color:var(--fg);font:12px Segoe UI,Microsoft YaHei UI,sans-serif;overflow:hidden}
#bar{height:100%;display:flex;align-items:center;gap:4px;padding:6px}
.b{width:34px;height:34px;display:inline-flex;align-items:center;justify-content:center;border:1px solid var(--panel-bd);border-radius:8px;background:var(--panel);color:var(--fg);cursor:pointer;outline:none}
.b:hover{background:var(--fg-soft);border-color:var(--fg-bd)}
.d{color:var(--danger);border-color:var(--danger-bd)}
.d:hover{background:var(--danger-soft)}
.s{width:1px;height:18px;background:var(--sep);margin:0 2px}
.i{width:18px;height:18px;stroke:currentColor;fill:none;stroke-width:2;stroke-linecap:round;stroke-linejoin:round;pointer-events:none}
</style></head>
<body><div id='bar'>
<button class='b' data-cmd='pin' title='置顶'><svg class='i' viewBox='0 0 24 24'><path d='M12 17v5'/><path d='M9 3h6l1 6 2 2-6 4-6-4 2-2z'/></svg></button>
<button class='b' data-cmd='ocr' title='识别文本'><svg class='i' viewBox='0 0 24 24'><path d='M4 4h16v16H4z'/><path d='M8 8h8M8 12h6M8 16h4'/></svg></button>
<button class='b' data-cmd='ocr_edit' title='编辑OCR到草稿本'><svg class='i' viewBox='0 0 24 24'><path d='M3 21h6'/><path d='m14.5 4.5 5 5'/><path d='M7 17l2.5-.5L19 7a1.8 1.8 0 0 0-2.5-2.5L7 14z'/></svg></button>
<button class='b' data-cmd='text' title='复制文本'><svg class='i' viewBox='0 0 24 24'><rect x='9' y='9' width='11' height='11' rx='2'/><rect x='4' y='4' width='11' height='11' rx='2'/></svg></button>
<button class='b' data-cmd='save' title='保存图片'><svg class='i' viewBox='0 0 24 24'><path d='M5 4h12l2 2v14H5z'/><path d='M8 4v6h8V4'/><path d='M9 16h6'/></svg></button>
<div class='s'></div>
<button class='b' data-cmd='ai' title='发送到AI'><svg class='i' viewBox='0 0 24 24'><path d='M12 3l1.8 4.7L18.5 9 14.8 12l1.3 4.9L12 14l-4.1 2.9L9.2 12 5.5 9l4.7-1.3z'/></svg></button>
<button class='b' data-cmd='search' title='搜索文本'><svg class='i' viewBox='0 0 24 24'><circle cx='11' cy='11' r='7'/><path d='m20 20-3.5-3.5'/></svg></button>
<button class='b' data-cmd='color' title='取色器'><svg class='i' viewBox='0 0 24 24'><path d='m14.5 4.5 5 5'/><path d='M7 17 4 20h6l9.5-9.5a1.8 1.8 0 0 0-2.5-2.5z'/></svg></button>
<div class='s'></div>
<button class='b d' data-cmd='close' title='关闭'><svg class='i' viewBox='0 0 24 24'><path d='M18 6 6 18M6 6l12 12'/></svg></button>
</div>
<script>
(function(){
  function post(o){try{if(window.chrome&&window.chrome.webview){window.chrome.webview.postMessage(o);}}catch(e){}}
  function applyTheme(mode){document.body.setAttribute('data-theme', String(mode||'').toLowerCase()==='light'?'light':'dark');}
  var bar=document.getElementById('bar');
  bar.addEventListener('click',function(ev){
    var t=ev.target;
    while(t&&t!==bar&&!t.getAttribute('data-cmd')) t=t.parentNode;
    if(!t||t===bar) return;
    post({action:'invoke',cmd:t.getAttribute('data-cmd')});
  });
  bar.addEventListener('mousedown',function(ev){
    if(ev.button!==0) return;
    var t=ev.target;
    while(t&&t!==bar&&!t.getAttribute('data-cmd')) t=t.parentNode;
    if(!t||t===bar) post({action:'dragWindow'});
  });
  if(window.chrome&&window.chrome.webview){
    window.chrome.webview.addEventListener('message',function(ev){
      var d=ev.data||{};
      if(typeof d==='string'){try{d=JSON.parse(d);}catch(e){return;}}
      if(d&&d.type==='state') applyTheme(d.themeMode||d.theme||'dark');
    });
  }
  applyTheme('dark');
  post({action:'ready'}); post({action:'paint_ok'});
})();
</script></body></html>
)"
}

    static ScreenshotToolbar_EnableNativeFallback(reason := "") {
    if !(IsObject(this.GuiID_ScreenshotToolbar) && this.GuiID_ScreenshotToolbar != 0)
        return
    if this.ScreenshotToolbarNativeFallback
        return
    this.ScreenshotToolbarNativeFallback := true
    this.ScreenshotToolbarWV2Ready := false
    this.ScreenshotToolbarWV2PaintOk := false
    try {
        if (this.ScreenshotToolbarWV2Ctrl)
            this.ScreenshotToolbarWV2Ctrl.IsVisible := false
    }
    this.GuiID_ScreenshotToolbar.BackColor := this.ScreenshotToolbarThemeHex("toolbarBg")
    x := 8
    y := 10
    btnW := 32
    btnH := 32
    gap := 6
    sepGap := 5

    AddBtn(iconPath, cmd, isDanger := false) {
        bg := isDanger ? this.ScreenshotToolbarThemeHex("dangerBg") : this.ScreenshotToolbarThemeHex("btnBg")
        bd := isDanger ? this.ScreenshotToolbarThemeHex("dangerBorder") : this.ScreenshotToolbarThemeHex("btnBorder")
        tc := isDanger ? this.ScreenshotToolbarThemeHex("dangerFg") : this.ScreenshotToolbarThemeHex("btnFg")
        c := this.GuiID_ScreenshotToolbar.Add("Text", "x" . x . " y" . y . " w" . btnW . " h" . btnH . " Center 0x200 Border c" . bd . " Background" . bg, "")
        c.OnEvent("Click", (*) => this.ScreenshotToolbar_InvokeCommand(cmd))
        if (iconPath != "" && FileExist(iconPath)) {
            p := this.GuiID_ScreenshotToolbar.Add("Picture", "x" . (x + 7) . " y" . (y + 7) . " w18 h18 BackgroundTrans", iconPath)
            p.OnEvent("Click", (*) => this.ScreenshotToolbar_InvokeCommand(cmd))
        } else {
            g := this.GuiID_ScreenshotToolbar.Add("Text", "x" . x . " y" . y . " w" . btnW . " h" . btnH . " Center 0x200 c" . tc . " BackgroundTrans", "*")
            g.SetFont("s10 Bold", "Segoe UI")
            g.OnEvent("Click", (*) => this.ScreenshotToolbar_InvokeCommand(cmd))
        }
        x += btnW + gap
    }
    AddSep() {
        x += sepGap
        sp := this.ScreenshotToolbarThemeHex("sep")
        this.GuiID_ScreenshotToolbar.Add("Text", "x" . x . " y" . (y + 7) . " w1 h18 Background" . sp . " c" . sp, "")
        x += 1 + sepGap
    }
    menuDir := A_ScriptDir "\assets\images\screenshot-menu"
    imgDir := A_ScriptDir "\images"
    AddBtn(menuDir "\toolbar-show.png", "pin")
    AddBtn(menuDir "\copy.png", "ocr")
    AddBtn(menuDir "\process.png", "ocr_edit")
    AddBtn(menuDir "\copy.png", "text")
    AddBtn(menuDir "\save.png", "save")
    AddSep()
    AddBtn(imgDir "\toolbar_ai.png", "ai")
    AddBtn(imgDir "\toolbar_search.png", "search")
    AddBtn(menuDir "\process.png", "color")
    AddSep()
    AddBtn(menuDir "\close.png", "close", true)

    this.ScreenshotToolbarCurrentWidth := Max(320, x + 8)
    this.ScreenshotToolbarCurrentHeight := 52
    dragTop := this.GuiID_ScreenshotToolbar.Add("Text", "x0 y0 w" . this.ScreenshotToolbarCurrentWidth . " h8 BackgroundTrans", "")
    dragBottom := this.GuiID_ScreenshotToolbar.Add("Text", "x0 y" . (this.ScreenshotToolbarCurrentHeight - 8) . " w" . this.ScreenshotToolbarCurrentWidth . " h8 BackgroundTrans", "")
    dragTop.OnEvent("Click", ObjBindMethod(ScreenshotEditorPlugin, "ScreenshotToolbarDragWindow"))
    dragBottom.OnEvent("Click", ObjBindMethod(ScreenshotEditorPlugin, "ScreenshotToolbarDragWindow"))
    try this.GuiID_ScreenshotToolbar.Show("NA w" . this.ScreenshotToolbarCurrentWidth . " h" . this.ScreenshotToolbarCurrentHeight)
    this.ScreenshotToolbar_NotifyHostMemory(true)
    this.ScreenshotToolbar_ApplyWindowRegion()
    if (reason != "")
        OutputDebug("[ScreenshotToolbar] native fallback: " . reason)
}

; 鍚屾宸ュ叿鏍忎綅缃紙璺熼殢涓荤獥鍙ｇЩ鍔級
    static SyncScreenshotToolbarPosition() {
    
    try {
        if (!this.GuiID_ScreenshotEditor || this.GuiID_ScreenshotEditor = 0) {
            SetTimer(ObjBindMethod(ScreenshotEditorPlugin, "SyncScreenshotToolbarPosition"), 0)  ; 鍋滄瀹氭椂鍣?
            return
        }
        
        if (!this.GuiID_ScreenshotToolbar || this.GuiID_ScreenshotToolbar = 0) {
            SetTimer(ObjBindMethod(ScreenshotEditorPlugin, "SyncScreenshotToolbarPosition"), 0)  ; 鍋滄瀹氭椂鍣?
            return
        }
        
        ; 鑾峰彇涓荤獥鍙ｄ綅缃拰灏哄
        WinGetPos(&EditorX, &EditorY, &EditorW, &EditorH, "ahk_id " . this.GuiID_ScreenshotEditor.Hwnd)
        
        if (!EditorX || !EditorY || !EditorW || !EditorH) {
            return  ; 濡傛灉鑾峰彇浣嶇疆澶辫触锛岃烦杩囨湰娆″悓姝?
        }
        
        ; 璁＄畻宸ュ叿鏍忎綅缃紙鏀惧湪涓荤獥鍙ｄ笅鏂癸紝闂磋窛10鍍忕礌锛?
        ToolbarX := EditorX
        ToolbarY := EditorY + EditorH + 10
        
        ; 鑾峰彇宸ュ叿鏍忓綋鍓嶅昂瀵?
        WinGetPos(, , &ToolbarW, &ToolbarH, "ahk_id " . this.GuiID_ScreenshotToolbar.Hwnd)
        
        ; 绉诲姩宸ュ叿鏍忓埌鏂颁綅缃?
        if (ToolbarW && ToolbarH) {
            this.GuiID_ScreenshotToolbar.Show("x" . ToolbarX . " y" . ToolbarY)
            this.ScreenshotToolbar_ApplyWindowRegion()
            this.ScreenshotToolbar_ApplyBounds()
        }
        if (this.ScreenshotColorPickerActive) {
            this.ScreenshotColorPickerSyncPosition()
        }
    } catch as e {
        ; 濡傛灉鍑洪敊锛屽仠姝㈠畾鏃跺櫒
        SetTimer(ObjBindMethod(ScreenshotEditorPlugin, "SyncScreenshotToolbarPosition"), 0)
    }
}

; 鍒囨崲鎴浘鍔╂墜缃《鐘舵€侊紙闅愯棌/鏄剧ず宸ュ叿鏍忓拰鏍囬鏍忥級
    static ToggleScreenshotEditorAlwaysOnTop() {
    
    try {
        this.ScreenshotEditorToolbarVisible := !this.ScreenshotEditorToolbarVisible
        
        if (!this.ScreenshotEditorToolbarVisible) {
            ; 闅愯棌宸ュ叿鏍忓拰鏍囬鏍?
            if (this.ScreenshotEditorTitleBar) {
                this.ScreenshotEditorTitleBar.Visible := false
            }
            if (this.ScreenshotEditorCloseBtn) {
                this.ScreenshotEditorCloseBtn.Visible := false
            }
            if (this.GuiID_ScreenshotToolbar != 0) {
                this.ScreenshotToolbar_NotifyHostMemory(false)
                this.GuiID_ScreenshotToolbar.Hide()
            }
            this.ScreenshotEditorApplyZoom(this.ScreenshotEditorZoomScale, true)
            this.ScreenshotToolbar_SendState()
            TrayTip("提示", "已进入置顶缩放模式：滚轮可缩放", "Iconi 1")
        } else {
            ; 鏄剧ず宸ュ叿鏍忓拰鏍囬鏍?
            this.ShowScreenshotEditorToolbar()
            this.ScreenshotToolbar_SendState()
            TrayTip("鎻愮ず", "宸叉樉绀哄伐鍏锋爮鍜屾爣棰樻爮", "Iconi 1")
        }
    } catch as e {
        TrayTip("閿欒", "鍒囨崲鏄剧ず鐘舵€佸け璐? " . e.Message, "Iconx 2")
    }
}

; 鏄剧ず鎴浘鍔╂墜宸ュ叿鏍忓拰鏍囬鏍?
    static ShowScreenshotEditorToolbar() {
    
    try {
        this.ScreenshotEditorToolbarVisible := true
        
        ; 鏄剧ず鏍囬鏍忓拰鍏抽棴鎸夐挳
        if (this.ScreenshotEditorTitleBar) {
            this.ScreenshotEditorTitleBar.Visible := true
        }
        if (this.ScreenshotEditorCloseBtn) {
            this.ScreenshotEditorCloseBtn.Visible := true
        }

        ; 鎸夊綋鍓嶇缉鏀炬瘮渚嬫仮澶嶅竷灞€
        this.ScreenshotEditorApplyZoom(this.ScreenshotEditorZoomScale, false)
        this.ScreenshotToolbar_SendState()
    } catch as e {
        TrayTip("閿欒", "鏄剧ず宸ュ叿鏍忓け璐? " . e.Message, "Iconx 2")
    }
}

    static ScreenshotEditorZoomBy(step) {
    newScale := this.ScreenshotEditorZoomScale + step
    this.ScreenshotEditorApplyZoom(newScale, true)
}

; 鎸囨暟缂╂斁锛氬弬鑰?d3/openSeadragon 鐨勬粴杞缉鏀炬€濊矾锛屼娇鐢?2^delta 璁╀笉鍚屽€嶇巼涓嬫墜鎰熶竴鑷?
    static ScreenshotEditorZoomWithWheel(direction) {
    try {
        d := (direction > 0) ? 1 : -1
        wheelDelta := 0.12 * d
        factor := Exp(wheelDelta * Ln(2.0))
        newScale := this.ScreenshotEditorZoomScale * factor
        this.ScreenshotEditorApplyZoom(newScale, true)
    } catch {
        this.ScreenshotEditorZoomBy(0.1 * ((direction > 0) ? 1 : -1))
    }
}

    static ScreenshotEditorApplyZoom(newScale, showTip := true) {

    try {
        if !(IsObject(this.GuiID_ScreenshotEditor) && this.GuiID_ScreenshotEditor != 0)
            return
        if (!this.ScreenshotEditorPreviewPic)
            return

        if (!this.ScreenshotEditorBaseWidth || !this.ScreenshotEditorBaseHeight) {
            this.ScreenshotEditorBaseWidth := this.ScreenshotEditorPreviewWidth
            this.ScreenshotEditorBaseHeight := this.ScreenshotEditorPreviewHeight
        }
        if (!this.ScreenshotEditorBaseWidth || !this.ScreenshotEditorBaseHeight)
            return

        if (newScale < this.ScreenshotEditorZoomMin)
            newScale := this.ScreenshotEditorZoomMin

        ; 灞忓箷鍙鑼冨洿鍔ㄦ€侀檺骞咃紝閬垮厤鏀惧ぇ鍚庡嚭鐜扳€滄埅鏂劅鈥?
        titleH := this.ScreenshotEditorToolbarVisible ? this.ScreenshotEditorTitleBarHeight : 0
        vW := SysGet(78), vH := SysGet(79)
        maxScaleW := (vW - 20) / this.ScreenshotEditorBaseWidth
        maxScaleH := (vH - 20 - titleH) / this.ScreenshotEditorBaseHeight
        screenMaxScale := Min(maxScaleW, maxScaleH)
        if (screenMaxScale < this.ScreenshotEditorZoomMin)
            screenMaxScale := this.ScreenshotEditorZoomMin
        effectiveMaxScale := Min(this.ScreenshotEditorZoomMax, screenMaxScale)
        if (newScale > effectiveMaxScale)
            newScale := effectiveMaxScale
        this.ScreenshotEditorZoomScale := newScale

        drawW := Max(120, Round(this.ScreenshotEditorBaseWidth * this.ScreenshotEditorZoomScale))
        drawH := Max(80, Round(this.ScreenshotEditorBaseHeight * this.ScreenshotEditorZoomScale))

        previewY := titleH
        winW := drawW
        winH := drawH + titleH

        WinGetPos(&oldX, &oldY, &oldW, &oldH, "ahk_id " . this.GuiID_ScreenshotEditor.Hwnd)
        if (!oldW || !oldH) {
            oldW := winW
            oldH := winH
        }

        ; 浠ュ綋鍓嶇獥鍙ｄ腑蹇冧负鍩哄噯缂╂斁锛岄伩鍏嶅悜鍙充笅鎵╁睍閫犳垚鈥滄埅鏂劅鈥?
        centerX := oldX + (oldW // 2)
        centerY := oldY + (oldH // 2)
        winX := centerX - (winW // 2)
        winY := centerY - (winH // 2)

        ; 闄愬埗鍦ㄨ櫄鎷熷睆骞曡寖鍥村唴锛岄伩鍏嶆斁澶у悗璺戝嚭杈圭晫
        vL := SysGet(76), vT := SysGet(77), vW := SysGet(78), vH := SysGet(79)
        vR := vL + vW, vB := vT + vH
        if (winX < vL)
            winX := vL
        if (winY < vT)
            winY := vT
        if (winX + winW > vR)
            winX := vR - winW
        if (winY + winH > vB)
            winY := vB - winH
        if (winX < vL)
            winX := vL
        if (winY < vT)
            winY := vT

        ; 鍏抽敭淇锛氫粠鍘熷浘閲嶉噰鏍峰綋鍓嶅昂瀵革紝閬垮厤浠呮媺浼告帶浠跺鑷寸殑鈥滄埅鏂?澶辩湡鎰熲€?
        this.ScreenshotEditorRefreshScaledPreview(drawW, drawH)
        this.ScreenshotEditorPreviewPic.Move(0, previewY, drawW, drawH)
        this.GuiID_ScreenshotEditor.Show("w" . winW . " h" . winH . " x" . winX . " y" . winY)

        if (this.ScreenshotEditorToolbarVisible && this.GuiID_ScreenshotToolbar != 0) {
            toolbarX := winX
            toolbarY := winY + winH + 10
            this.GuiID_ScreenshotToolbar.Show("x" . toolbarX . " y" . toolbarY)
            this.ScreenshotToolbar_NotifyHostMemory(true)
            this.ScreenshotToolbar_ApplyBounds()
            SetTimer(ObjBindMethod(ScreenshotEditorPlugin, "ScreenshotToolbar_RefreshComposition"), -30)
        }

        if (showTip)
            this.ScreenshotEditorShowZoomTip(this.ScreenshotEditorZoomScale, drawW, drawH)
    } catch as e {
        TrayTip("缂╂斁", "缂╂斁澶辫触: " . e.Message, "Iconx 1")
    }
}

    static ScreenshotEditorRefreshScaledPreview(drawW, drawH) {
    if (!this.ScreenshotEditorBitmap || !this.ScreenshotEditorPreviewPic)
        return
    pScaled := 0
    pG := 0
    try {
        result := DllCall("gdiplus\GdipCreateBitmapFromScan0"
            , "Int", drawW
            , "Int", drawH
            , "Int", 0
            , "UInt", 0x26200A
            , "Ptr", 0
            , "Ptr*", &pScaled := 0)
        if (result != 0 || !pScaled)
            return

        result := DllCall("gdiplus\GdipGetImageGraphicsContext", "Ptr", pScaled, "Ptr*", &pG := 0)
        if (result != 0 || !pG)
            return

        DllCall("gdiplus\GdipSetInterpolationMode", "Ptr", pG, "Int", 7) ; HighQualityBicubic
        DllCall("gdiplus\GdipDrawImageRect", "Ptr", pG, "Ptr", this.ScreenshotEditorBitmap
            , "Float", 0, "Float", 0, "Float", drawW, "Float", drawH)

        newPath := A_Temp "\ScreenshotEditor_zoom_" . A_TickCount . ".png"
        saveRet := Gdip_SaveBitmapToFile(pScaled, newPath)
        if (saveRet != 0)
            return

        ; 鍏堝垏鍥撅紝鍐嶅垹鏃у浘锛岄伩鍏嶆帶浠跺紩鐢ㄥけ鏁?
        this.ScreenshotEditorPreviewPic.Value := newPath
        oldPath := this.ScreenshotEditorImagePath
        this.ScreenshotEditorImagePath := newPath
        if (oldPath != "" && oldPath != newPath && FileExist(oldPath)) {
            try FileDelete(oldPath)
        }
    } catch {
    } finally {
        if (pG)
            try Gdip_DeleteGraphics(pG)
        if (pScaled)
            try Gdip_DisposeImage(pScaled)
    }
}

    static ScreenshotEditorShowZoomTip(scale, width, height) {

    try {
        if !(IsObject(this.GuiID_ScreenshotZoomTip) && this.GuiID_ScreenshotZoomTip != 0) {
            this.GuiID_ScreenshotZoomTip := Gui("+AlwaysOnTop -Caption +ToolWindow -DPIScale")
            this.GuiID_ScreenshotZoomTip.BackColor := "0b0b0b"
            this.GuiID_ScreenshotZoomTip.MarginX := 10
            this.GuiID_ScreenshotZoomTip.MarginY := 6
            this.ScreenshotZoomTipTextCtrl := this.GuiID_ScreenshotZoomTip.Add("Text", "cFF8A00", "")
            this.ScreenshotZoomTipTextCtrl.SetFont("s10 Bold", "Segoe UI")
        }

        txt := "缂╂斁 " . Round(scale * 100) . "%  |  灏哄 " . width . " x " . height
        this.ScreenshotZoomTipTextCtrl.Value := txt
        this.GuiID_ScreenshotZoomTip.Show("NA AutoSize")

        WinGetPos(&ex, &ey, &ew, , "ahk_id " . this.GuiID_ScreenshotEditor.Hwnd)
        WinGetPos(, , &tw, &th, "ahk_id " . this.GuiID_ScreenshotZoomTip.Hwnd)
        tx := ex + ew - tw - 12
        ty := ey + (this.ScreenshotEditorToolbarVisible ? this.ScreenshotEditorTitleBarHeight + 8 : 8)
        this.GuiID_ScreenshotZoomTip.Show("NA x" . tx . " y" . ty)

        SetTimer(ObjBindMethod(ScreenshotEditorPlugin, "ScreenshotEditorHideZoomTip"), -1200)
    } catch {
    }
}

    static ScreenshotEditorHideZoomTip(*) {
    try {
        if (IsObject(this.GuiID_ScreenshotZoomTip) && this.GuiID_ScreenshotZoomTip != 0)
            this.GuiID_ScreenshotZoomTip.Hide()
    } catch {
    }
}

    static ScreenshotEditorShowCurrentZoomTip() {
    if (!this.ScreenshotEditorBaseWidth || !this.ScreenshotEditorBaseHeight)
        return
    drawW := Max(120, Round(this.ScreenshotEditorBaseWidth * this.ScreenshotEditorZoomScale))
    drawH := Max(80, Round(this.ScreenshotEditorBaseHeight * this.ScreenshotEditorZoomScale))
    this.ScreenshotEditorShowZoomTip(this.ScreenshotEditorZoomScale, drawW, drawH)
}

; 鎴浘鍔╂墜鍥剧墖鎺т欢鐐瑰嚮浜嬩欢锛堢敤浜庢嫋鍔ㄧ獥鍙ｏ級
    static OnScreenshotEditorPicClick(Ctrl, Info) {
    
    try {
        ; 妫€鏌ユ槸鍚﹂暱鎸夊乏閿紙绛夊緟200ms鍒ゆ柇锛?
        Sleep(200)
        if (GetKeyState("LButton", "P")) {
            ; 闀挎寜宸﹂敭锛屽紑濮嬫嫋鍔ㄧ獥鍙?
            this.ScreenshotEditorIsDraggingWindow := true
            
            ; 鍙戦€佹嫋鍔ㄦ秷鎭紙纭繚绐楀彛鍙ユ焺鏈夋晥锛?
            if (this.GuiID_ScreenshotEditor && this.GuiID_ScreenshotEditor != 0) {
                PostMessage(0xA1, 2, 0, 0, this.GuiID_ScreenshotEditor.Hwnd)
            }
            
            ; 鐩戝惉榧犳爣閲婃斁
            SetTimer(() => this.CheckScreenshotEditorWindowDragUp(), 10)
        }
    } catch as e {
        ; 蹇界暐閿欒
    }
}

; 妫€鏌ョ獥鍙ｆ嫋鍔ㄦ槸鍚︾粨鏉?
    static CheckScreenshotEditorWindowDragUp() {
    
    if (!this.ScreenshotEditorIsDraggingWindow) {
        SetTimer(() => this.CheckScreenshotEditorWindowDragUp(), 0)
        return
    }
    
    if (!GetKeyState("LButton", "P")) {
        this.ScreenshotEditorIsDraggingWindow := false
        SetTimer(() => this.CheckScreenshotEditorWindowDragUp(), 0)
    }
}

; 鍏抽棴鎴浘鍔╂墜棰勮绐?
    static CloseScreenshotEditor() {
    try FloatingToolbar_PageDockLeave("screenshot")
    
    try {
        this.ScreenshotEditorStopColorPicker()

        ; 鍏抽棴宸ュ叿鏍忕獥鍙?
        if (this.GuiID_ScreenshotToolbar && (this.GuiID_ScreenshotToolbar != 0)) {
            try {
                if (IsObject(this.GuiID_ScreenshotToolbar)) {
                    this.GuiID_ScreenshotToolbar.Destroy()
                }
            } catch as e {
                ; 蹇界暐閿€姣侀敊璇?
            }
            this.GuiID_ScreenshotToolbar := 0
        }
        this.ScreenshotToolbarWV2Ctrl := 0
        this.ScreenshotToolbarWV2 := 0
        this.ScreenshotToolbarWV2Ready := false
        this.ScreenshotToolbarWV2PaintOk := false
        this.ScreenshotToolbarNativeFallback := false

        if (this.GuiID_ScreenshotToolbarTip && (this.GuiID_ScreenshotToolbarTip != 0)) {
            try {
                if (IsObject(this.GuiID_ScreenshotToolbarTip))
                    this.GuiID_ScreenshotToolbarTip.Destroy()
            } catch {
            }
            this.GuiID_ScreenshotToolbarTip := 0
            this.ScreenshotToolbarTipTextCtrl := 0
        }

        if (this.GuiID_ScreenshotZoomTip && (this.GuiID_ScreenshotZoomTip != 0)) {
            try {
                if (IsObject(this.GuiID_ScreenshotZoomTip)) {
                    this.GuiID_ScreenshotZoomTip.Destroy()
                }
            } catch {
            }
            this.GuiID_ScreenshotZoomTip := 0
            this.ScreenshotZoomTipTextCtrl := 0
        }
        
        ; 閲嶇疆鐘舵€?
        
        ; 閲婃斁Gdip璧勬簮
        if (this.ScreenshotEditorBitmap) {
            try {
                Gdip_DisposeImage(this.ScreenshotEditorBitmap)
            } catch as e {
                ; 蹇界暐閲婃斁閿欒
            }
            this.ScreenshotEditorBitmap := 0
        }
        if (this.ScreenshotEditorGraphics) {
            try {
                Gdip_DeleteGraphics(this.ScreenshotEditorGraphics)
            } catch as e {
                ; 蹇界暐閲婃斁閿欒
            }
            this.ScreenshotEditorGraphics := 0
        }
        if (this.ScreenshotEditorPreviewBitmap) {
            try {
                Gdip_DisposeImage(this.ScreenshotEditorPreviewBitmap)
            } catch as e {
                ; 蹇界暐閲婃斁閿欒
            }
            this.ScreenshotEditorPreviewBitmap := 0
        }
        
        ; 鍒犻櫎涓存椂鏂囦欢
        if (this.ScreenshotEditorImagePath && FileExist(this.ScreenshotEditorImagePath)) {
            try {
                FileDelete(this.ScreenshotEditorImagePath)
            } catch as err {
            }
            this.ScreenshotEditorImagePath := ""
        }
        
        ; 閿€姣丟UI锛堝畨鍏ㄥ鐞咷ui瀵硅薄锛?
        if (IsObject(this.GuiID_ScreenshotEditor)) {
            try {
                this.GuiID_ScreenshotEditor.Destroy()
            } catch as e {
                ; 蹇界暐閿€姣侀敊璇?
            }
            this.GuiID_ScreenshotEditor := 0
        }
        this.ScreenshotEditorPreviewPic := 0

        this.ScreenshotEditorZoomScale := 1.0
        this.ScreenshotEditorBaseWidth := 0
        this.ScreenshotEditorBaseHeight := 0
        ScreenshotEditorPlugin._SyncHub()
    } catch as err {
    }
}


; 鏇存柊鎴浘鍔╂墜棰勮锛堜粠鍘熷浣嶅浘閲嶆柊缁樺埗鍒伴瑙堜綅鍥撅級
    static UpdateScreenshotEditorPreview() {
    
    if (!this.ScreenshotEditorBitmap || !this.ScreenshotEditorGraphics || !this.ScreenshotEditorPreviewBitmap) {
        return
    }
    
    try {
        ; 閲嶆柊缁樺埗棰勮锛堜粠鍘熷浣嶅浘閲嶆柊缁樺埗锛屽寘鍚墍鏈夊凡缁樺埗鐨勬爣娉級
        ; 鍏堟竻闄ゅ浘褰?
        DllCall("gdiplus\GdipGraphicsClear", "Ptr", this.ScreenshotEditorGraphics, "UInt", 0xFF000000)
        
        ; 閲嶆柊缁樺埗鍘熷鍥惧儚锛堝寘鍚墍鏈夋爣娉級
        DllCall("gdiplus\GdipSetInterpolationMode", "Ptr", this.ScreenshotEditorGraphics, "Int", 7)  ; HighQualityBicubic
        DllCall("gdiplus\GdipDrawImageRect", "Ptr", this.ScreenshotEditorGraphics, "Ptr", this.ScreenshotEditorBitmap, "Float", 0, "Float", 0, "Float", this.ScreenshotEditorPreviewWidth, "Float", this.ScreenshotEditorPreviewHeight)
        
        ; 淇濆瓨鏇存柊鍚庣殑棰勮浣嶅浘鍒颁复鏃舵枃浠?
        Gdip_SaveBitmapToFile(this.ScreenshotEditorPreviewBitmap, this.ScreenshotEditorImagePath)
        
        ; 鏇存柊Picture鎺т欢鏄剧ず
        if (this.ScreenshotEditorPreviewPic) {
            this.ScreenshotEditorPreviewPic.Value := this.ScreenshotEditorImagePath
        }
        
    } catch as e {
        ; 蹇界暐閿欒
    }
}

    static ScreenshotEditorToolbarIconPath(iconKey) {
    baseDir := A_ScriptDir "\assets\images"
    menuDir := baseDir "\screenshot-menu"
    iconMap := Map(
        "pin", menuDir "\toolbar-show.png",
        "ocr", menuDir "\process.png",
        "text", menuDir "\copy.png",
        "save", menuDir "\save.png",
        "ai", baseDir "\toolbar_ai.png",
        "search", baseDir "\toolbar_search.png",
        "color", menuDir "\flip-h.png",
        "close", menuDir "\close.png"
    )
    return iconMap.Has(iconKey) ? iconMap[iconKey] : ""
}

    static ScreenshotToolbarEnsureTipGui() {
    if (this.GuiID_ScreenshotToolbarTip && this.GuiID_ScreenshotToolbarTip != 0)
        return
    this.GuiID_ScreenshotToolbarTip := Gui("+AlwaysOnTop -Caption +ToolWindow +Border +E0x20")
    this.GuiID_ScreenshotToolbarTip.BackColor := "0f1114"
    this.ScreenshotToolbarTipTextCtrl := this.GuiID_ScreenshotToolbarTip.Add("Text", "x8 y4 cffb062 BackgroundTrans", "")
    this.ScreenshotToolbarTipTextCtrl.SetFont("s9", "Segoe UI")
}

    static ScreenshotToolbarShowHoverTip(tipText, anchorX, anchorY) {
    this.ScreenshotToolbarEnsureTipGui()
    if (!(this.GuiID_ScreenshotToolbarTip && this.ScreenshotToolbarTipTextCtrl))
        return
    try {
        this.ScreenshotToolbarTipTextCtrl.Value := tipText
        this.GuiID_ScreenshotToolbarTip.Show("NA AutoSize x-32000 y-32000")
        this.GuiID_ScreenshotToolbarTip.GetPos(, , &tw, &th)
        ScreenVirtual_GetBounds(&vl, &vt, &vw, &vh)
        tx := anchorX - (tw // 2)
        ty := anchorY - th - 14
        if (tx < vl)
            tx := vl + 2
        if (tx + tw > vl + vw)
            tx := vl + vw - tw - 2
        if (ty < vt)
            ty := anchorY + 14
        this.GuiID_ScreenshotToolbarTip.Show("NA x" . tx . " y" . ty)
    } catch {
    }
}

    static ScreenshotToolbarHideHoverTip() {
    this.ScreenshotToolbarHoverTipLastKey := ""
    try {
        if (this.GuiID_ScreenshotToolbarTip && this.GuiID_ScreenshotToolbarTip != 0)
            this.GuiID_ScreenshotToolbarTip.Hide()
    } catch {
    }
}

    static ScreenshotToolbarHoverTick(*) {
    if !(this.GuiID_ScreenshotToolbar && IsObject(this.GuiID_ScreenshotToolbar) && this.GuiID_ScreenshotToolbar != 0) {
        this.ScreenshotToolbarHideHoverTip()
        SetTimer(ObjBindMethod(ScreenshotEditorPlugin, "ScreenshotToolbarHoverTick"), 0)
        return
    }
    try WinGetPos(&wx, &wy, &ww, &wh, "ahk_id " . this.GuiID_ScreenshotToolbar.Hwnd)
    catch {
        this.ScreenshotToolbarHideHoverTip()
        return
    }

    MouseGetPos(&mx, &my, &hoverWin)
    if (hoverWin != this.GuiID_ScreenshotToolbar.Hwnd) {
        this.ScreenshotToolbarHideHoverTip()
        return
    }

    lx := mx - wx
    ly := my - wy
    hitKey := ""
    hitTip := ""
    for _, item in this.ScreenshotToolbarHoverItems {
        if (lx >= item["x"] && lx <= item["x"] + item["w"] && ly >= item["y"] && ly <= item["y"] + item["h"]) {
            hitKey := item["key"]
            hitTip := item["tip"]
            break
        }
    }
    if (hitKey = "") {
        this.ScreenshotToolbarHideHoverTip()
        return
    }
    if (hitKey != this.ScreenshotToolbarHoverTipLastKey) {
        this.ScreenshotToolbarHoverTipLastKey := hitKey
        this.ScreenshotToolbarShowHoverTip(hitTip, mx, my)
    }
}

    static ScreenshotEditorMenuSvgIconPath(iconKey) {
    ; 缁熶竴缁存姢鎴浘鍙抽敭鑿滃崟鍥炬爣鏄犲皠锛圫VG 璧勬簮璺緞锛?
    baseDir := A_ScriptDir "\assets\images\screenshot-menu"
    iconMap := Map(
        "copy", baseDir "\copy.svg",
        "save", baseDir "\save.svg",
        "folder", baseDir "\folder.svg",
        "toolbar_show", baseDir "\toolbar-show.svg",
        "toolbar_hide", baseDir "\toolbar-hide.svg",
        "process", baseDir "\process.svg",
        "rotate_left", baseDir "\rotate-left.svg",
        "rotate_right", baseDir "\rotate-right.svg",
        "flip_h", baseDir "\flip-h.svg",
        "flip_v", baseDir "\flip-v.svg",
        "delete", baseDir "\delete.svg",
        "close", baseDir "\close.svg"
    )
    return iconMap.Has(iconKey) ? iconMap[iconKey] : ""
}

; 鎴浘鍔╂墜鍙抽敭鑿滃崟锛堥粦姗欓鏍硷級
    static OnScreenshotEditorContextMenu(Ctrl, Info := 0, *) {

    try {
        if !this.IsScreenshotEditorActive()
            return
        CloseDarkStylePopupMenu()
        MouseGetPos(&MouseX, &MouseY)

        MenuItems := []
        MenuItems.Push({Text: "复制", Icon: "⧉", SvgIcon: this.ScreenshotEditorMenuSvgIconPath("copy"), Action: (*) => this.ScreenshotEditorCopyKeepMode()})
        MenuItems.Push({Text: "保存图片", Icon: "💾", SvgIcon: this.ScreenshotEditorMenuSvgIconPath("save"), Action: (*) => this.ScreenshotEditorSaveKeepMode()})
        MenuItems.Push({Text: "在文件夹中查看", Icon: "▣", SvgIcon: this.ScreenshotEditorMenuSvgIconPath("folder"), Action: (*) => this.ScreenshotEditorRevealInFolder()})
        MenuItems.Push({Text: "处理图片", Icon: "⚙", SvgIcon: this.ScreenshotEditorMenuSvgIconPath("process"), Action: (*) => this.ScreenshotEditorShowImageProcessMenu()})
        MenuItems.Push({Text: "弹出工具栏", Icon: "▣", SvgIcon: this.ScreenshotEditorMenuSvgIconPath("toolbar_show"), Action: (*) => this.ScreenshotEditorShowToolbarFromMenu()})
        if (this.ScreenshotEditorToolbarVisible) {
            MenuItems.Push({Text: "关闭工具栏", Icon: "◩", SvgIcon: this.ScreenshotEditorMenuSvgIconPath("toolbar_hide"), Action: (*) => this.ScreenshotEditorHideToolbarFromMenu()})
        } else {
            MenuItems.Push({Text: "关闭工具栏", Icon: "◩", SvgIcon: this.ScreenshotEditorMenuSvgIconPath("toolbar_hide"), Action: (*) => this.ScreenshotEditorHideToolbarFromMenu()})
        }
        MenuItems.Push({Text: "彻底删除", Icon: "🗑", SvgIcon: this.ScreenshotEditorMenuSvgIconPath("delete"), Action: (*) => this.ScreenshotEditorDeletePermanently()})
        MenuItems.Push({Text: "关闭", Icon: "×", SvgIcon: this.ScreenshotEditorMenuSvgIconPath("close"), Action: (*) => this.CloseScreenshotEditor()})
        ShowDarkStylePopupMenuAt(MenuItems, MouseX + 2, MouseY + 2)
    } catch {
    }
}

    static ScreenshotEditorShowFallbackContextMenu() {
    m := Menu()
    processMenu := Menu()
    processMenu.Add("鍚戝乏鏃嬭浆", (*) => this.ScreenshotEditorTransformImage("rotate_left"))
    processMenu.Add("鍚戝彸鏃嬭浆", (*) => this.ScreenshotEditorTransformImage("rotate_right"))
    processMenu.Add("姘村钩缈昏浆", (*) => this.ScreenshotEditorTransformImage("flip_h"))
    processMenu.Add("鍨傜洿缈昏浆", (*) => this.ScreenshotEditorTransformImage("flip_v"))
    m.Add("澶嶅埗", (*) => this.ScreenshotEditorCopyKeepMode())
    m.Add("淇濆瓨鍥剧墖", (*) => this.ScreenshotEditorSaveKeepMode())
    m.Add("在文件夹中查看", (*) => this.ScreenshotEditorRevealInFolder())
    m.Add("澶勭悊鍥剧墖", processMenu)
    m.Add()
    m.Add("弹出工具栏", (*) => this.ScreenshotEditorShowToolbarFromMenu())
    m.Add("关闭工具栏", (*) => this.ScreenshotEditorHideToolbarFromMenu())
    m.Add("褰诲簳鍒犻櫎", (*) => this.ScreenshotEditorDeletePermanently())
    m.Add("鍏抽棴", (*) => this.CloseScreenshotEditor())
    MouseGetPos(&x, &y)
    m.Show(x, y)
}

    static ScreenshotEditorShowToolbarFromMenu() {
    try {
        this.ScreenshotEditorToolbarVisible := true
        this.ShowScreenshotEditorToolbar()
        SetTimer(ObjBindMethod(ScreenshotEditorPlugin, "ScreenshotEditorEnsureToolbarVisible"), -40)
        SetTimer(ObjBindMethod(ScreenshotEditorPlugin, "ScreenshotEditorEnsureToolbarVisible"), -140)
    } catch as e {
        TrayTip("工具栏", "弹出工具栏失败: " . e.Message, "Iconx 1")
    }
}

    static ScreenshotEditorEnsureToolbarVisible(*) {
    if (!this.ScreenshotEditorToolbarVisible)
        return
    try {
        if !(IsObject(this.GuiID_ScreenshotEditor) && this.GuiID_ScreenshotEditor != 0)
            return
        if !(IsObject(this.GuiID_ScreenshotToolbar) && this.GuiID_ScreenshotToolbar != 0)
            return
        WinGetPos(&winX, &winY, &winW, &winH, "ahk_id " . this.GuiID_ScreenshotEditor.Hwnd)
        this.GuiID_ScreenshotToolbar.Show("x" . winX . " y" . (winY + winH + 10))
        this.ScreenshotToolbar_NotifyHostMemory(true)
        this.ScreenshotToolbar_ApplyBounds()
        SetTimer(ObjBindMethod(ScreenshotEditorPlugin, "ScreenshotToolbar_RefreshComposition"), -30)
        WinSetAlwaysOnTop("On", "ahk_id " . this.GuiID_ScreenshotToolbar.Hwnd)
    } catch {
    }
}

    static ScreenshotEditorHideToolbarFromMenu() {
    try {
        this.ScreenshotEditorToolbarVisible := false
        if (this.ScreenshotEditorTitleBar)
            this.ScreenshotEditorTitleBar.Visible := false
        if (this.ScreenshotEditorCloseBtn)
            this.ScreenshotEditorCloseBtn.Visible := false
        if (this.GuiID_ScreenshotToolbar && this.GuiID_ScreenshotToolbar != 0) {
            this.ScreenshotToolbar_NotifyHostMemory(false)
            this.GuiID_ScreenshotToolbar.Hide()
        }
        this.ScreenshotEditorApplyZoom(this.ScreenshotEditorZoomScale, false)
        this.ScreenshotToolbar_SendState()
    } catch as e {
        TrayTip("工具栏", "关闭工具栏失败: " . e.Message, "Iconx 1")
    }
}

    static ScreenshotEditorCopyKeepMode() {
    this.CopyScreenshotToClipboard(false)
}

    static ScreenshotEditorSaveKeepMode() {
    this.SaveScreenshotToFile(false)
}

    static ScreenshotEditorRevealInFolder() {
    try {
        if (this.ScreenshotEditorImagePath != "" && FileExist(this.ScreenshotEditorImagePath)) {
            Run('explorer.exe /select,"' . this.ScreenshotEditorImagePath . '"')
            return
        }
        TrayTip("鏂囦欢", "褰撳墠鎴浘灏氭湭鐢熸垚鍙畾浣嶇殑鏂囦欢", "Iconi 1")
    } catch as e {
        TrayTip("鏂囦欢", "鎵撳紑鏂囦欢澶瑰け璐? " . e.Message, "Iconx 1")
    }
}

    static ScreenshotEditorShowImageProcessMenu() {
    try {
        MouseGetPos(&mx, &my)
        MenuItems := []
        MenuItems.Push({Text: "向左旋转", Icon: "↺", SvgIcon: this.ScreenshotEditorMenuSvgIconPath("rotate_left"), Action: (*) => this.ScreenshotEditorTransformImage("rotate_left")})
        MenuItems.Push({Text: "向右旋转", Icon: "↻", SvgIcon: this.ScreenshotEditorMenuSvgIconPath("rotate_right"), Action: (*) => this.ScreenshotEditorTransformImage("rotate_right")})
        MenuItems.Push({Text: "水平翻转", Icon: "⇋", SvgIcon: this.ScreenshotEditorMenuSvgIconPath("flip_h"), Action: (*) => this.ScreenshotEditorTransformImage("flip_h")})
        MenuItems.Push({Text: "垂直翻转", Icon: "⇵", SvgIcon: this.ScreenshotEditorMenuSvgIconPath("flip_v"), Action: (*) => this.ScreenshotEditorTransformImage("flip_v")})
        ShowDarkStylePopupMenuAt(MenuItems, mx + 140, my + 2)
    } catch {
    }
}

    static ScreenshotEditorTransformImage(actionType) {
    if (!this.ScreenshotEditorBitmap) {
        TrayTip("鍥惧儚澶勭悊", "褰撳墠鏃犲彲澶勭悊鍥剧墖", "Iconx 1")
        return
    }

    rotateFlipType := 0
    switch actionType {
        case "rotate_left":
            rotateFlipType := 3
        case "rotate_right":
            rotateFlipType := 1
        case "flip_h":
            rotateFlipType := 4
        case "flip_v":
            rotateFlipType := 6
        default:
            return
    }

    try {
        st := DllCall("gdiplus\GdipImageRotateFlip", "Ptr", this.ScreenshotEditorBitmap, "Int", rotateFlipType, "Int")
        if (st != 0) {
            TrayTip("鍥惧儚澶勭悊", "鍥惧儚鍙樻崲澶辫触锛岀姸鎬佺爜: " . st, "Iconx 1")
            return
        }

        newW := Gdip_GetImageWidth(this.ScreenshotEditorBitmap)
        newH := Gdip_GetImageHeight(this.ScreenshotEditorBitmap)
        if (!newW || !newH)
            return

        if (this.ScreenshotEditorGraphics) {
            try Gdip_DeleteGraphics(this.ScreenshotEditorGraphics)
            this.ScreenshotEditorGraphics := 0
        }
        if (this.ScreenshotEditorPreviewBitmap) {
            try Gdip_DisposeImage(this.ScreenshotEditorPreviewBitmap)
            this.ScreenshotEditorPreviewBitmap := 0
        }

        pPreview := 0
        pGraphics := 0
        ret := DllCall("gdiplus\GdipCreateBitmapFromScan0"
            , "Int", newW
            , "Int", newH
            , "Int", 0
            , "UInt", 0x26200A
            , "Ptr", 0
            , "Ptr*", &pPreview := 0)
        if (ret = 0 && pPreview) {
            ret2 := DllCall("gdiplus\GdipGetImageGraphicsContext", "Ptr", pPreview, "Ptr*", &pGraphics := 0)
            if (ret2 = 0 && pGraphics) {
                DllCall("gdiplus\GdipSetInterpolationMode", "Ptr", pGraphics, "Int", 7)
                DllCall("gdiplus\GdipDrawImageRect", "Ptr", pGraphics, "Ptr", this.ScreenshotEditorBitmap
                    , "Float", 0, "Float", 0, "Float", newW, "Float", newH)
                this.ScreenshotEditorPreviewBitmap := pPreview
                this.ScreenshotEditorGraphics := pGraphics
            } else {
                if (pPreview)
                    try Gdip_DisposeImage(pPreview)
            }
        }

        this.ScreenshotEditorPreviewWidth := newW
        this.ScreenshotEditorPreviewHeight := newH
        this.ScreenshotEditorBaseWidth := newW
        this.ScreenshotEditorBaseHeight := newH

        this.ScreenshotEditorApplyZoom(this.ScreenshotEditorZoomScale, false)
        this.ScreenshotEditorShowCurrentZoomTip()
    } catch as e {
        TrayTip("鍥惧儚澶勭悊", "鍥惧儚澶勭悊澶辫触: " . e.Message, "Iconx 1")
    }
}

    static ScreenshotEditorDeletePermanently() {
    try {
        answer := MsgBox("确定要彻底删除当前截图吗？此操作不可恢复。", "彻底删除", "YesNo Iconx")
        if (answer != "Yes")
            return
        targetPath := this.ScreenshotEditorImagePath
        this.CloseScreenshotEditor()
        if (targetPath != "" && FileExist(targetPath)) {
            try FileDelete(targetPath)
        }
        TrayTip("删除", "截图已彻底删除", "Iconi 1")
    } catch as e {
        TrayTip("鍒犻櫎", "鍒犻櫎澶辫触: " . e.Message, "Iconx 1")
    }
}

    static ScreenshotEditorToggleColorPicker() {
    if (this.ScreenshotColorPickerActive) {
        this.ScreenshotEditorStopColorPicker()
        TrayTip("取色器", "已退出取色模式", "Iconi 1")
    } else {
        this.ScreenshotEditorStartColorPicker()
    }
}

    static ScreenshotEditorStartColorPicker() {
    if !(IsObject(this.GuiID_ScreenshotEditor) && this.GuiID_ScreenshotEditor != 0)
        return
    this.ScreenshotColorPickerEnsureGui()
    this.ScreenshotColorPickerActive := true
    this.ScreenshotColorPickerTick()
    SetTimer(ObjBindMethod(ScreenshotEditorPlugin, "ScreenshotColorPickerTick"), 40)
    TrayTip("取色器", "移动鼠标查看放大镜；左键记录历史，Caps+X 退出", "Iconi 1")
}

    static ScreenshotEditorStopColorPicker() {

    SetTimer(ObjBindMethod(ScreenshotEditorPlugin, "ScreenshotColorPickerTick"), 0)
    this.ScreenshotColorPickerTickBusy := false
    this.ScreenshotColorPickerActive := false
    if (IsObject(this.GuiID_ScreenshotColorPicker) && this.GuiID_ScreenshotColorPicker != 0) {
        try this.GuiID_ScreenshotColorPicker.Destroy()
    }
    this.GuiID_ScreenshotColorPicker := 0
    this.ScreenshotColorPickerMagnifierPic := 0
    this.ScreenshotColorPickerCurrentText := 0
    this.ScreenshotColorPickerCompareText := 0
    this.ScreenshotColorPickerHistoryEdit := 0
}

    static ScreenshotColorPickerEnsureGui() {

    if (IsObject(this.GuiID_ScreenshotColorPicker) && this.GuiID_ScreenshotColorPicker != 0) {
        try this.GuiID_ScreenshotColorPicker.Show("NA")
        return
    }

    panel := Gui("+AlwaysOnTop +ToolWindow -Caption -DPIScale")
    panel.BackColor := "121820"
    panel.SetFont("s9 cE8EDF2", "Segoe UI")

    panel.Add("Text", "x12 y8 w220 h20 cFF9D3A", "屏幕取色器")
    this.ScreenshotColorPickerMagnifierPic := panel.Add("Picture", "x12 y30 w180 h180 0xE Border")
    this.ScreenshotColorPickerCurrentText := panel.Add("Text", "x200 y32 w220 h78 cE8EDF2", "褰撳墠棰滆壊")
    this.ScreenshotColorPickerCurrentText.SetFont("s9", "Consolas")
    this.ScreenshotColorPickerCompareText := panel.Add("Text", "x200 y114 w220 h46 cAAB7C4", "对比: 未设置")

    btnCopyHex := panel.Add("Button", "x12 y220 w84 h26", "澶嶅埗HEX")
    btnCopyRgb := panel.Add("Button", "x104 y220 w84 h26", "澶嶅埗RGB")
    btnAnchor := panel.Add("Button", "x200 y220 w84 h26", "璁句负瀵规瘮")
    btnHistory := panel.Add("Button", "x292 y220 w84 h26", "鍔犲叆鍘嗗彶")
    btnClose := panel.Add("Button", "x384 y220 w36 h26", "×")

    panel.Add("Text", "x12 y254 w170 h18 c9DB0C2", "鍘嗗彶棰滆壊锛堟渶鏂板湪鍓嶏級")
    this.ScreenshotColorPickerHistoryEdit := panel.Add("Edit", "x12 y274 w408 h166 ReadOnly -Wrap -VScroll cDCE9F7 Background101820", "")
    this.ScreenshotColorPickerHistoryEdit.SetFont("s10", "Consolas")

    btnCopyHex.OnEvent("Click", (*) => this.ScreenshotColorPickerCopyCurrent("hex"))
    btnCopyRgb.OnEvent("Click", (*) => this.ScreenshotColorPickerCopyCurrent("rgb"))
    btnAnchor.OnEvent("Click", (*) => this.ScreenshotColorPickerSetAnchor())
    btnHistory.OnEvent("Click", (*) => this.ScreenshotColorPickerPushCurrentToHistory())
    btnClose.OnEvent("Click", (*) => this.ScreenshotEditorStopColorPicker())

    this.GuiID_ScreenshotColorPicker := panel
    this.ScreenshotColorPickerSyncPosition()
    panel.Show("NA w432 h452")
}

    static ScreenshotColorPickerSyncPosition() {
    if !(IsObject(this.GuiID_ScreenshotEditor) && this.GuiID_ScreenshotEditor != 0)
        return
    if !(IsObject(this.GuiID_ScreenshotColorPicker) && this.GuiID_ScreenshotColorPicker != 0)
        return
    try {
        WinGetPos(&ex, &ey, &ew, &eh, "ahk_id " . this.GuiID_ScreenshotEditor.Hwnd)
        px := ex + ew + 12
        py := ey
        vL := SysGet(76), vT := SysGet(77), vW := SysGet(78), vH := SysGet(79)
        vR := vL + vW, vB := vT + vH
        panelW := 432, panelH := 452
        if (px + panelW > vR)
            px := Max(vL, ex - panelW - 12)
        if (py + panelH > vB)
            py := Max(vT, vB - panelH - 8)
        this.GuiID_ScreenshotColorPicker.Show("NA x" . px . " y" . py . " w" . panelW . " h" . panelH)
    } catch {
    }
}

    static ScreenshotColorPickerCaptureAtCursor() {
    if (!this.ScreenshotColorPickerActive)
        return
    try {
        MouseGetPos(&mx, &my, &hoverHwnd)
        if (IsObject(this.GuiID_ScreenshotColorPicker) && this.GuiID_ScreenshotColorPicker != 0) {
            if (hoverHwnd = this.GuiID_ScreenshotColorPicker.Hwnd
                || DllCall("user32\IsChild", "ptr", this.GuiID_ScreenshotColorPicker.Hwnd, "ptr", hoverHwnd, "int")) {
                return
            }
        }
        colorInfo := this.ScreenshotColorPickerGetColorInfo(mx, my)
        this.ScreenshotColorPickerAddHistory(colorInfo)
        this.ScreenshotColorPickerRefreshHistoryText()
        TrayTip("鍙栬壊", "宸茶褰?" . colorInfo["hex"], "Iconi 1")
    } catch {
    }
}

    static ScreenshotColorPickerTick(*) {

    if (!this.ScreenshotColorPickerActive)
        return
    if (this.ScreenshotColorPickerTickBusy)
        return
    this.ScreenshotColorPickerTickBusy := true
    try {
        if !(IsObject(this.GuiID_ScreenshotEditor) && this.GuiID_ScreenshotEditor != 0) {
            this.ScreenshotEditorStopColorPicker()
            return
        }
        if !(IsObject(this.GuiID_ScreenshotColorPicker) && this.GuiID_ScreenshotColorPicker != 0) {
            this.ScreenshotColorPickerEnsureGui()
        }
        MouseGetPos(&mx, &my)
        colorInfo := this.ScreenshotColorPickerGetColorInfo(mx, my)
        this.ScreenshotColorPickerCurrent := colorInfo
        if (this.ScreenshotColorPickerCurrentText) {
            this.ScreenshotColorPickerCurrentText.Value :=
                "灞忓箷: (" . mx . ", " . my . ")`n"
                . "HEX: " . colorInfo["hex"] . "`n"
                . "hex: " . colorInfo["hex_lower"] . "`n"
                . "RGB: " . colorInfo["rgb"]
        }
        if (this.ScreenshotColorPickerCompareText) {
            this.ScreenshotColorPickerCompareText.Value := this.ScreenshotColorPickerBuildCompareText(colorInfo, this.ScreenshotColorPickerAnchor)
        }
        this.ScreenshotColorPickerRenderMagnifier(mx, my)
    } catch {
    } finally {
        this.ScreenshotColorPickerTickBusy := false
    }
}

    static ScreenshotColorPickerGetColorInfo(x, y) {
    color := PixelGetColor(x, y, "RGB")
    r := (color >> 16) & 0xFF
    g := (color >> 8) & 0xFF
    b := color & 0xFF
    info := Map()
    info["value"] := color
    info["r"] := r
    info["g"] := g
    info["b"] := b
    info["hex"] := Format("#{1:06X}", color)
    info["hex_lower"] := StrLower(info["hex"])
    info["rgb"] := "rgb(" . r . ", " . g . ", " . b . ")"
    return info
}

    static ScreenshotColorPickerBuildCompareText(current, anchor) {
    if !(anchor is Map) || anchor.Count = 0
        return "瀵规瘮: 鏈缃紙鐐瑰嚮鈥滆涓哄姣斺€濓級"
    dr := current["r"] - anchor["r"]
    dg := current["g"] - anchor["g"]
    db := current["b"] - anchor["b"]
    distance := Round(Sqrt(dr * dr + dg * dg + db * db), 2)
    return "瀵规瘮鍩哄噯: " . anchor["hex"] . "`n"
        . "螖RGB: (" . dr . ", " . dg . ", " . db . ")  |  璺濈: " . distance
}

    static ScreenshotColorPickerCaptureScreenBitmapNative(x, y, w, h) {
    if (w <= 0 || h <= 0)
        return 0
    hdcScreen := 0, hdcMem := 0, hbm := 0, obm := 0, pBitmap := 0
    try {
        hdcScreen := DllCall("user32\GetDC", "ptr", 0, "ptr")
        if (!hdcScreen)
            return 0
        hdcMem := DllCall("gdi32\CreateCompatibleDC", "ptr", hdcScreen, "ptr")
        if (!hdcMem)
            return 0
        hbm := DllCall("gdi32\CreateCompatibleBitmap", "ptr", hdcScreen, "int", w, "int", h, "ptr")
        if (!hbm)
            return 0
        obm := DllCall("gdi32\SelectObject", "ptr", hdcMem, "ptr", hbm, "ptr")
        ; SRCCOPY | CAPTUREBLT锛屼紭鍏堟姄鍙栧悎鎴愬悗鐨勫睆骞曞唴瀹?
        DllCall("gdi32\BitBlt"
            , "ptr", hdcMem, "int", 0, "int", 0, "int", w, "int", h
            , "ptr", hdcScreen, "int", x, "int", y, "uint", 0x00CC0020 | 0x40000000)
        pBitmap := Gdip_CreateBitmapFromHBITMAP(hbm)
    } catch {
        pBitmap := 0
    } finally {
        if (obm && hdcMem)
            try DllCall("gdi32\SelectObject", "ptr", hdcMem, "ptr", obm, "ptr")
        if (hbm)
            try DeleteObject(hbm)
        if (hdcMem)
            try DllCall("gdi32\DeleteDC", "ptr", hdcMem)
        if (hdcScreen)
            try DllCall("user32\ReleaseDC", "ptr", 0, "ptr", hdcScreen)
    }
    return pBitmap
}

    static ScreenshotColorPickerRenderMagnifier(mouseX, mouseY) {
    if (!this.ScreenshotColorPickerMagnifierPic)
        return
    sampleSize := 15
    zoom := 12
    drawSize := sampleSize * zoom
    startX := mouseX - (sampleSize // 2)
    startY := mouseY - (sampleSize // 2)

    pSrc := 0, pDst := 0, pG := 0, hBitmap := 0, pPen := 0
    try {
        pSrc := this.ScreenshotColorPickerCaptureScreenBitmapNative(startX, startY, sampleSize, sampleSize)
        if (!pSrc)
            return
        pDst := Gdip_CreateBitmap(drawSize, drawSize)
        if (!pDst)
            return
        pG := Gdip_GraphicsFromImage(pDst)
        if (!pG)
            return

        Gdip_SetInterpolationMode(pG, 5)  ; NearestNeighbor
        Gdip_DrawImage(pG, pSrc, 0, 0, drawSize, drawSize, 0, 0, sampleSize, sampleSize)

        centerCell := (sampleSize // 2) * zoom
        pPen := Gdip_CreatePen(0xFFFF8A00, 2)
        if (pPen) {
            Gdip_DrawRectangle(pG, pPen, centerCell, centerCell, zoom, zoom)
        }

        hBitmap := Gdip_CreateHBITMAPFromBitmap(pDst)
        if (hBitmap) {
            SetImage(this.ScreenshotColorPickerMagnifierPic.Hwnd, hBitmap)
            hBitmap := 0
        }
    } catch {
    } finally {
        if (pPen)
            try Gdip_DeletePen(pPen)
        if (pG)
            try Gdip_DeleteGraphics(pG)
        if (pDst)
            try Gdip_DisposeImage(pDst)
        if (pSrc)
            try Gdip_DisposeImage(pSrc)
    }
}

    static ScreenshotColorPickerCopyCurrent(copyType) {
    if !(this.ScreenshotColorPickerCurrent is Map) || this.ScreenshotColorPickerCurrent.Count = 0
        return
    if (copyType = "rgb") {
        A_Clipboard := this.ScreenshotColorPickerCurrent["rgb"]
        TrayTip("取色器", "RGB 已复制", "Iconi 1")
    } else {
        A_Clipboard := this.ScreenshotColorPickerCurrent["hex"]
        TrayTip("取色器", "HEX 已复制", "Iconi 1")
    }
}

    static ScreenshotColorPickerSetAnchor() {
    if !(this.ScreenshotColorPickerCurrent is Map) || this.ScreenshotColorPickerCurrent.Count = 0
        return
    anchor := Map()
    for k, v in this.ScreenshotColorPickerCurrent
        anchor[k] := v
    this.ScreenshotColorPickerAnchor := anchor
    if (this.ScreenshotColorPickerCompareText)
        this.ScreenshotColorPickerCompareText.Value := this.ScreenshotColorPickerBuildCompareText(this.ScreenshotColorPickerCurrent, this.ScreenshotColorPickerAnchor)
    TrayTip("取色器", "已设置对比基准: " . anchor["hex"], "Iconi 1")
}

    static ScreenshotColorPickerPushCurrentToHistory() {
    if !(this.ScreenshotColorPickerCurrent is Map) || this.ScreenshotColorPickerCurrent.Count = 0
        return
    this.ScreenshotColorPickerAddHistory(this.ScreenshotColorPickerCurrent)
    this.ScreenshotColorPickerRefreshHistoryText()
}

    static ScreenshotColorPickerAddHistory(colorInfo) {
    if !(this.ScreenshotColorPickerHistory is Array)
        this.ScreenshotColorPickerHistory := []
    item := Map()
    for k, v in colorInfo
        item[k] := v
    item["time"] := FormatTime(A_Now, "HH:mm:ss")
    this.ScreenshotColorPickerHistory.InsertAt(1, item)
    while (this.ScreenshotColorPickerHistory.Length > 12) {
        this.ScreenshotColorPickerHistory.Pop()
    }
}

    static ScreenshotColorPickerRefreshHistoryText() {
    if (!this.ScreenshotColorPickerHistoryEdit)
        return
    if !(this.ScreenshotColorPickerHistory is Array) || this.ScreenshotColorPickerHistory.Length = 0 {
        this.ScreenshotColorPickerHistoryEdit.Value := "序号  时间       HEX      hex      RGB`r`n---------------------------------------------`r`n暂无历史颜色（点击“加入历史”或左键取样）"
        return
    }
    txt := "搴忓彿  鏃堕棿       HEX       hex       RGB`r`n"
    txt .= "---------------------------------------------------------------`r`n"
    for idx, item in this.ScreenshotColorPickerHistory {
        seq := Format("{1:02}", idx)
        hexUpper := item["hex"]
        hexLower := item.Has("hex_lower") ? item["hex_lower"] : StrLower(hexUpper)
        txt .= seq . "    " . item["time"] . "   " . hexUpper . "  " . hexLower . "  " . item["rgb"] . "`r`n"
    }
    this.ScreenshotColorPickerHistoryEdit.Value := RTrim(txt, "`r`n")
}

; 绮樿创OCR鏂囨湰鍒癈ursor
    static PasteOCRTextToCursor(Text, OCRResultGui) {
    try {
        ; 鍏抽棴OCR缁撴灉绐楀彛
        if (OCRResultGui) {
            OCRResultGui.Destroy()
        }
        
        ; 灏嗘枃鏈鍒跺埌鍓创鏉?
        A_Clipboard := Text
        Sleep(200)
        
        ; 婵€娲籆ursor绐楀彛
        try {
            WinActivate("ahk_exe Cursor.exe")
            Sleep(300)
        } catch as e {
            ; 濡傛灉Cursor鏈繍琛岋紝鏄剧ず鎻愮ず
            TrayTip("鎻愮ず", "璇峰厛鎵撳紑Cursor绐楀彛", "Iconi 1")
            return
        }
        
        ; 鎸塃SC鍏抽棴鍙兘宸叉墦寮€鐨勮緭鍏ユ
        Send("{Escape}")
        Sleep(100)
        
        ; 鎸塁trl+L鎵撳紑AI鑱婂ぉ闈㈡澘
        Send("^l")
        Sleep(300)
        
        ; 绮樿创鏂囨湰
        Send("^v")
        Sleep(200)
        
        TrayTip("鎴愬姛", "宸茬矘璐碠CR鏂囨湰鍒癈ursor", "Iconi 1")
    } catch as e {
        TrayTip("閿欒", "绮樿创澶辫触: " . e.Message, "Iconx 2")
    }
}

; 鎵цOCR璇嗗埆
; 涓轰唬鐮丱CR棰勫鐞嗕綅鍥撅紙鏀惧ぇ銆佽鍓€佸寮哄姣斿害锛?
    static PrepareBitmapForCodeOCR(pBitmap) {
    if (!pBitmap || pBitmap <= 0) {
        return 0
    }
    
    G := 0
    pNew := 0
    pAttr := 0
    
    try {
        ; 鑾峰彇鍘熷灏哄
        Width := Gdip_GetImageWidth(pBitmap)
        Height := Gdip_GetImageHeight(pBitmap)
        
        if (Width <= 0 || Height <= 0) {
            return 0
        }
        
        ; 1. 姣斾緥缂╂斁锛氬鏋滈珮搴﹀皬浜?00px锛屾斁澶?鍊?
        scale := (Height < 500) ? 2 : 1
        margin := 8  ; 鍥涘懆鍐呯缉8鍍忕礌
        
        ; 纭繚瑁佸壀鍚庡昂瀵告湁鏁?
        if (Width <= margin * 2 || Height <= margin * 2) {
            ; 濡傛灉鍥剧墖澶皬锛屼笉杩涜瑁佸壀锛屽彧杩涜缂╂斁
            margin := 0
        }
        
        ; 璁＄畻瑁佸壀鍚庣殑婧愬昂瀵?
        srcW := Width - (margin * 2)
        srcH := Height - (margin * 2)
        
        if (srcW <= 0 || srcH <= 0) {
            ; 濡傛灉瑁佸壀鍚庢棤鏁堬紝浣跨敤鍘熷灏哄
            srcW := Width
            srcH := Height
            margin := 0
        }
        
        ; 璁＄畻鏂板昂瀵革紙瑁佸壀鍚庢斁澶э級
        newW := Floor(srcW * scale)
        newH := Floor(srcH * scale)
        
        if (newW <= 0 || newH <= 0) {
            return 0
        }
        
        ; 鍒涘缓鏂颁綅鍥?
        pNew := Gdip_CreateBitmap(newW, newH)
        if (!pNew || pNew <= 0) {
            return 0
        }
        
        ; 鑾峰彇鍥惧舰涓婁笅鏂?
        G := Gdip_GraphicsFromImage(pNew)
        if (!G || G <= 0) {
            Gdip_DisposeImage(pNew)
            return 0
        }
        
        ; 璁剧疆楂樿川閲忔彃鍊兼ā寮?
        Gdip_SetInterpolationMode(G, 7)  ; HighQualityBicubic
        
        ; 2. 搴旂敤鏋佽嚧瀵规瘮搴﹂鑹茬煩闃?
        ; 鐭╅樀鏍煎紡锛?.5|0|0|0|0|0|2.5|0|0|0|0|0|2.5|0|0|0|0|0|1|0|-1|-1|-1|0|1
        Matrix := "2.5|0|0|0|0|0|2.5|0|0|0|0|0|2.5|0|0|0|0|0|1|0|-1|-1|-1|0|1"
        pAttr := Gdip_SetImageAttributesColorMatrix(Matrix)
        
        ; 3. 缁樺埗鏃惰繘琛屽亸绉伙紙瀹炵幇瑁佸壀杈圭紭锛?
        ; 浠庢簮浣嶅浘鐨?margin, margin)浣嶇疆寮€濮嬶紝灏哄涓?srcW, srcH)
        ; 缁樺埗鍒版柊浣嶅浘鐨?0, 0)浣嶇疆锛屽昂瀵镐负(newW, newH)锛堝凡鏀惧ぇ锛?
        srcX := margin
        srcY := margin
        
        ; 缁樺埗鍥惧儚锛堝簲鐢ㄩ鑹茬煩闃靛拰瑁佸壀锛屽悓鏃舵斁澶э級
        ; Gdip_DrawImage(pGraphics, pBitmap, dx, dy, dw, dh, sx, sy, sw, sh, Matrix)
        result := Gdip_DrawImage(G, pBitmap, 0, 0, newW, newH, srcX, srcY, srcW, srcH, pAttr)
        
        ; 妫€鏌ョ粯鍒舵槸鍚︽垚鍔?
        if (result != 0) {
            ; 缁樺埗澶辫触锛岄噴鏀捐祫婧愬苟杩斿洖0
            if (pAttr) {
                Gdip_DisposeImageAttributes(pAttr)
            }
            Gdip_DeleteGraphics(G)
            Gdip_DisposeImage(pNew)
            return 0
        }
        
        ; 閲婃斁璧勬簮
        if (pAttr) {
            Gdip_DisposeImageAttributes(pAttr)
            pAttr := 0
        }
        Gdip_DeleteGraphics(G)
        G := 0
        
        return pNew
    } catch as e {
        ; 濡傛灉鍑洪敊锛岄噴鏀惧凡鍒涘缓鐨勮祫婧?
        if (G && G > 0) {
            try Gdip_DeleteGraphics(G)
        }
        if (pNew && pNew > 0) {
            try Gdip_DisposeImage(pNew)
        }
        if (pAttr && pAttr > 0) {
            try Gdip_DisposeImageAttributes(pAttr)
        }
        return 0
    }
}

; 娓呮礂浠ｇ爜OCR缁撴灉鏂囨湰
    static CleanCodeOCRText(ResultObj) {
    ; 棣栧厛灏濊瘯鐩存帴杩斿洖 Text 灞炴€?
    try {
        if (ResultObj.HasProp("Text") && ResultObj.Text != "") {
            return ResultObj.Text
        }
    } catch {
    }

    ; 濡傛灉娌℃湁 Text 灞炴€ф垨涓虹┖锛屽皾璇曚粠 Words 鏋勫缓
    try {
        if (!ResultObj.HasProp("Words")) {
            return ""
        }

        Words := ResultObj.Words
        if (!Words || Words.Length = 0) {
            return ""
        }

        ; 璁＄畻鎵€鏈夊瓧绗︾殑骞冲潎楂樺害
        sumH := 0
        wordCount := 0
        for w in Words {
            try {
                if (w.HasProp("h") && w.h > 0) {
                    sumH += w.h
                    wordCount++
                }
            } catch {
                continue
            }
        }

        if (wordCount = 0) {
            ; 濡傛灉鏃犳硶鑾峰彇楂樺害淇℃伅锛岀洿鎺ユ嫾鎺ユ墍鏈夊崟璇?
            simpleText := ""
            for w in Words {
                try {
                    if (w.HasProp("Text")) {
                        simpleText .= w.Text . " "
                    }
                } catch {
                }
            }
            return Trim(simpleText)
        }

        avgH := sumH / wordCount

        ; 鎸夎缁勭粐鍗曡瘝锛堟牴鎹畒鍧愭爣锛?
        lines := Map()
        for w in Words {
            try {
                ; 杩囨护鎺夊紓甯搁珮搴︾殑瀛楃锛堝櫔鐐规垨杈规锛?
                if (!w.HasProp("h") || w.h <= 0) {
                    continue
                }
                if (w.h < avgH * 0.4 || w.h > avgH * 2.0) {
                    continue
                }

                ; 绠€鍗曠殑琛屽悎骞堕€昏緫锛堟牴鎹畒鍧愭爣锛屾瘡10鍍忕礌涓轰竴缁勶級
                yKey := Round(w.y / 10) * 10
                if (!lines.Has(yKey)) {
                    lines[yKey] := []
                }
                lines[yKey].Push(w)
            } catch {
                continue
            }
        }

        ; 鎸墆鍧愭爣鎺掑簭
        sortedYKeys := []
        for yKey in lines {
            sortedYKeys.Push(yKey)
        }
        sortedYKeys.Sort()

        ; 鏋勫缓鏈€缁堟枃鏈?
        finalText := ""
        for yKey in sortedYKeys {
            words := lines[yKey]

            ; 鎸墄鍧愭爣鎺掑簭鍗曡瘝
            wordsArray := []
            for w in words {
                wordsArray.Push(w)
            }
            ; 鎸墄鍧愭爣鎺掑簭锛堜娇鐢⊿ort鏂规硶锛?
            wordsArray.Sort((a, b) => a.x - b.x)

            ; 鏋勫缓琛屾枃鏈?
            lineStr := ""
            for w in wordsArray {
                try {
                    ; 璁块棶Word瀵硅薄鐨凾ext灞炴€?
                    if (w.HasProp("Text")) {
                        lineStr .= w.Text . " "
                    }
                } catch {
                    ; 濡傛灉璁块棶澶辫触锛岃烦杩囪鍗曡瘝
                }
            }
            
            ; 姝ｅ垯娓呯悊琛岄琛屽熬骞叉壈绗?
            lineStr := RegExReplace(lineStr, "^[|!_I:.\-]\s*", "")
            lineStr := RegExReplace(lineStr, "\s*[|!_I:.\-]$", "")
            
            ; 淇浠ｇ爜甯歌绗﹀彿锛氬崟鐙嚭鐜扮殑 | 鍦ㄨ棣栨垨琛屽熬鏃剁Щ闄?
            lineStr := RegExReplace(lineStr, "^\s*\|\s+", "")
            lineStr := RegExReplace(lineStr, "\s+\|\s*$", "")
            
            ; 绉婚櫎澶氫綑绌烘牸
            lineStr := RegExReplace(lineStr, "\s+", " ")
            lineStr := Trim(lineStr)
            
            if (lineStr != "") {
                finalText .= lineStr . "`n"
            }
        }
        
        return Trim(finalText, "`n")
    } catch as e {
        ; 濡傛灉娓呮礂澶辫触锛岃繑鍥炲師濮嬫枃鏈?
        try {
            return ResultObj.Text
        } catch {
            return ""
        }
    }
}

    static ScreenshotOCRLoadPrefs() {
    global ConfigFile
    static loaded := false
    if (loaded)
        return
    loaded := true
    try {
        mode := IniRead(ConfigFile, "Settings", "ScreenshotOCRTextLayoutMode", this.ScreenshotOCRTextLayoutMode)
        punct := IniRead(ConfigFile, "Settings", "ScreenshotOCRPunctuationMode", this.ScreenshotOCRPunctuationMode)
        directCopy := IniRead(ConfigFile, "Settings", "ScreenshotOCRDirectCopyEnabled", this.ScreenshotOCRDirectCopyEnabled ? "1" : "0")

        if (mode != "auto" && mode != "single_line" && mode != "multi_line")
            mode := "auto"
        if (punct != "keep" && punct != "halfwidth" && punct != "strip")
            punct := "keep"
        this.ScreenshotOCRTextLayoutMode := mode
        this.ScreenshotOCRPunctuationMode := punct
        this.ScreenshotOCRDirectCopyEnabled := (String(directCopy) = "1")
    } catch {
    }
}

    static ScreenshotOCRSavePrefs() {
    global ConfigFile
    try IniWrite(this.ScreenshotOCRTextLayoutMode, ConfigFile, "Settings", "ScreenshotOCRTextLayoutMode")
    try IniWrite(this.ScreenshotOCRPunctuationMode, ConfigFile, "Settings", "ScreenshotOCRPunctuationMode")
    try IniWrite(this.ScreenshotOCRDirectCopyEnabled ? "1" : "0", ConfigFile, "Settings", "ScreenshotOCRDirectCopyEnabled")
}

    static ScreenshotOCRNormalizePunctuationHalfwidth(Text) {
    charMap := Map(
        "，", ",", "。", ".", "：", ":", "；", ";", "！", "!", "？", "?",
        "（", "(", "）", ")", "【", "[", "】", "]", "《", "<", "》", ">",
        "“", Chr(34), "”", Chr(34), "‘", "'", "’", "'",
        "、", ",", "—", "-", "…", "..."
    )
    out := Text
    for k, v in charMap
        out := StrReplace(out, k, v)
    return out
}

    static ScreenshotOCRStripPunctuation(Text) {
    ; Remove most punctuation/symbols while keeping letters/digits/chinese/newlines/spaces.
    return RegExReplace(Text, "[^\p{L}\p{N}\x{4E00}-\x{9FFF}\s`r`n]+", "")
}

    static ScreenshotOCRApplyTextFormattingByMode(Text, layoutMode, punctMode) {
    out := String(Text)
    if (layoutMode = "multi_line") {
        out := ProcessOCRTextPreserveLayout(out)
    } else if (layoutMode = "single_line") {
        out := ProcessOCRTextAutoFlow(out)
    } else {
        ; auto: choose by structure (many short lines -> multiline, else single line)
        lineCount := 0
        shortLineCount := 0
        lines := StrSplit(StrReplace(out, "`r", ""), "`n")
        for _, line in lines {
            t := Trim(line)
            if (t = "")
                continue
            lineCount += 1
            if (StrLen(t) <= 18)
                shortLineCount += 1
        }
        if (lineCount >= 3 && shortLineCount * 1.0 / lineCount >= 0.55) {
            out := ProcessOCRTextPreserveLayout(out)
        } else {
            out := ProcessOCRTextAutoFlow(out)
        }
    }

    if (punctMode = "halfwidth") {
        out := this.ScreenshotOCRNormalizePunctuationHalfwidth(out)
    } else if (punctMode = "strip") {
        out := this.ScreenshotOCRStripPunctuation(out)
        out := RegExReplace(out, "[ \t]{2,}", " ")
        out := RegExReplace(out, "(`r?`n){3,}", "`n`n")
    }
    return Trim(out)
}

    static ScreenshotOCRApplyTextFormatting(Text) {
    this.ScreenshotOCRLoadPrefs()
    return this.ScreenshotOCRApplyTextFormattingByMode(Text, this.ScreenshotOCRTextLayoutMode, this.ScreenshotOCRPunctuationMode)
}

    static ScreenshotOCRLayoutModeLabel(layoutMode) {
    if (layoutMode = "single_line")
        return "绉婚櫎鎹㈣"
    if (layoutMode = "multi_line")
        return "澶氳"
    return "鑷姩"
}

    static ScreenshotOCRPunctuationModeLabel(punctMode) {
    if (punctMode = "halfwidth")
        return "鍗婅"
    if (punctMode = "strip")
        return "去标点"
    return "淇濈暀"
}

; 鎵ц鎴浘OCR璇嗗埆锛堜紭鍖栫増锛屼笓涓轰唬鐮佹埅鍥捐璁★級
    static ExecuteScreenshotOCR() {
    
    ToolTip("姝ｅ湪浼樺寲浠ｇ爜鏍煎紡骞惰瘑鍒?..")
    
    try {
        ; 浣跨敤鎴浘缂栬緫鍣ㄤ腑鐨勪綅鍥?
        if (!this.ScreenshotEditorBitmap || this.ScreenshotEditorBitmap <= 0) {
            TrayTip("错误", "截图位图不存在", "Iconx 2")
            ToolTip()
            return
        }
        
        ; 楠岃瘉浣嶅浘鏈夋晥鎬?
        try {
            testWidth := Gdip_GetImageWidth(this.ScreenshotEditorBitmap)
            testHeight := Gdip_GetImageHeight(this.ScreenshotEditorBitmap)
            if (testWidth <= 0 || testHeight <= 0) {
                throw Error("浣嶅浘灏哄鏃犳晥: " . testWidth . "x" . testHeight)
            }
        } catch as e {
            TrayTip("閿欒", "浣嶅浘鏃犳晥: " . e.Message, "Iconx 2")
            ToolTip()
            return
        }
        
        ; 涓嶄娇鐢ㄩ澶勭悊锛岀洿鎺ヤ繚瀛樹负涓存椂鏂囦欢杩涜 OCR
        ; 鍥犱负 OCR.FromBitmap 鍙兘涓嶇ǔ瀹氾紝鏀圭敤 OCR.FromFile
        TempPath := A_Temp "\OCR_Screenshot_" . A_TickCount . ".png"
        result := Gdip_SaveBitmapToFile(this.ScreenshotEditorBitmap, TempPath)
        if (result != 0) {
            TrayTip("閿欒", "淇濆瓨涓存椂鍥剧墖澶辫触", "Iconx 2")
            ToolTip()
            return
        }

        ; 璋冪敤OCR璇嗗埆锛堟寚瀹氫腑鏂囪瑷€锛?
        ToolTip("姝ｅ湪璇嗗埆鏂囧瓧...")
        Result := OCR.FromFile(TempPath, "zh-CN")

        ; 鍒犻櫎涓存椂鏂囦欢
        try {
            FileDelete(TempPath)
        } catch {
        }

        if (!Result) {
            TrayTip("鎻愮ず", "OCR璇嗗埆澶辫触锛岃閲嶈瘯", "Iconi 1")
            ToolTip()
            return
        }
        
        ; 鑾峰彇璇嗗埆鏂囨湰
        cleanedText := ""
        try {
            ; 浼樺厛浣跨敤 Text 灞炴€?
            if (Result.HasProp("Text") && Result.Text != "") {
                cleanedText := Result.Text
            }
        } catch {
        }

        ; 濡傛灉 Text 涓虹┖锛屽皾璇曟竻娲楀鐞?
        if (cleanedText = "") {
            try {
                cleanedText := this.CleanCodeOCRText(Result)
            } catch as e {
                TrayTip("閿欒", "澶勭悊OCR缁撴灉澶辫触: " . e.Message, "Iconx 2")
                ToolTip()
                return
            }
        }

        if (cleanedText = "") {
            TrayTip("提示", "未识别到文字，请确保截图包含清晰文字内容", "Iconi 1")
            ToolTip()
            return
        }
        
        this.ScreenshotOCRLoadPrefs()

        if (this.ScreenshotOCRDirectCopyEnabled) {
            directText := this.ScreenshotOCRApplyTextFormatting(cleanedText)
            A_Clipboard := directText
            TrayTip("识别完成", "已直接复制文本（" . this.ScreenshotOCRLayoutModeLabel(this.ScreenshotOCRTextLayoutMode) . "）", "Iconi 1")
            ToolTip()
            return
        }

        ; 鏄剧ずOCR缁撴灉锛堟敮鎸佸鍒舵帓鐗堬級
        OCRResultGui := Gui("+AlwaysOnTop -Caption")
        OCRResultGui.BackColor := UI_Colors.Background
        OCRResultGui.SetFont("s10 c" . UI_Colors.Text, "Segoe UI")
        OCRResultGui.OnEvent("Escape", (*) => OCRResultGui.Destroy())

        rawText := cleanedText
        layoutMode := this.ScreenshotOCRTextLayoutMode
        punctuationMode := this.ScreenshotOCRPunctuationMode
        previewText := this.ScreenshotOCRApplyTextFormattingByMode(rawText, layoutMode, punctuationMode)

        ResultText := OCRResultGui.Add("Edit", "x10 y10 w560 h310 ReadOnly Multi Background" . UI_Colors.InputBg . " c" . UI_Colors.Text, previewText)
        ResultText.SetFont("s11", "Consolas")

        CloseBtn := OCRResultGui.Add("Text", "x550 y2 w20 h20 Center 0x200 c" . UI_Colors.Text . " Background" . UI_Colors.Background, "×")
        CloseBtn.SetFont("s10", "Segoe UI")
        CloseBtn.OnEvent("Click", (*) => OCRResultGui.Destroy())
        HoverBtnWithAnimation(CloseBtn, UI_Colors.Background, UI_Colors.BtnDanger)

        DirectCopyCheck := OCRResultGui.Add("CheckBox", "x10 y330 w180 h24 c" . UI_Colors.Text, "涓嬫鐩存帴澶嶅埗鏂囨湰")
        DirectCopyCheck.Value := this.ScreenshotOCRDirectCopyEnabled ? 1 : 0

        LayoutBtn := OCRResultGui.Add("Text", "x340 y328 w90 h30 Center 0x200 cFFFFFF Background" . UI_Colors.BtnBg, "鎺掔増")
        LayoutBtn.SetFont("s10", "Segoe UI")
        HoverBtnWithAnimation(LayoutBtn, UI_Colors.BtnBg, UI_Colors.BtnHover)

        CopyBtn := OCRResultGui.Add("Text", "x438 y328 w64 h30 Center 0x200 cFFFFFF Background" . UI_Colors.BtnPrimary, "澶嶅埗")
        CopyBtn.SetFont("s10", "Segoe UI")
        HoverBtnWithAnimation(CopyBtn, UI_Colors.BtnPrimary, UI_Colors.BtnPrimaryHover)

        PasteBtn := OCRResultGui.Add("Text", "x506 y328 w64 h30 Center 0x200 cFFFFFF Background" . UI_Colors.BtnPrimary, "绮樿创")
        PasteBtn.SetFont("s10", "Segoe UI")
        HoverBtnWithAnimation(PasteBtn, UI_Colors.BtnPrimary, UI_Colors.BtnPrimaryHover)

        RefreshPreviewText() {
            formatted := this.ScreenshotOCRApplyTextFormattingByMode(rawText, layoutMode, punctuationMode)
            ResultText.Value := formatted
            LayoutBtn.Value := "鎺掔増 " . this.ScreenshotOCRLayoutModeLabel(layoutMode)
        }

        SaveModeToGlobal() {
            this.ScreenshotOCRTextLayoutMode := layoutMode
            this.ScreenshotOCRPunctuationMode := punctuationMode
            this.ScreenshotOCRSavePrefs()
        }

        CopyCurrentText(*) {
            txt := ResultText.Value
            if (txt = "") {
                TrayTip("澶嶅埗", "娌℃湁鍙鍒剁殑鏂囨湰", "Iconx 1")
                return
            }
            A_Clipboard := txt
            TrayTip("复制", "文本已复制到剪贴板", "Iconi 1")
        }

        PasteCurrentText(*) {
            txt := ResultText.Value
            if (txt = "") {
                TrayTip("绮樿创", "娌℃湁鍙矘璐寸殑鏂囨湰", "Iconx 1")
                return
            }
            this.PasteOCRTextToCursor(txt, OCRResultGui)
        }

        ShowLayoutMenu(*) {
            punctMenu := Menu()
            punctMenu.Add((punctuationMode = "keep" ? "鉁?" : "") . "淇濈暀鏍囩偣", (*) => (punctuationMode := "keep", SaveModeToGlobal(), RefreshPreviewText()))
            punctMenu.Add((punctuationMode = "halfwidth" ? "✓" : "") . "转半角标点", (*) => (punctuationMode := "halfwidth", SaveModeToGlobal(), RefreshPreviewText()))
            punctMenu.Add((punctuationMode = "strip" ? "鉁?" : "") . "绉婚櫎鏍囩偣", (*) => (punctuationMode := "strip", SaveModeToGlobal(), RefreshPreviewText()))

            layoutMenu := Menu()
            layoutMenu.Add((layoutMode = "auto" ? "鉁?" : "") . "鑷姩", (*) => (layoutMode := "auto", SaveModeToGlobal(), RefreshPreviewText()))
            layoutMenu.Add((layoutMode = "single_line" ? "✓" : "") . "移除换行符", (*) => (layoutMode := "single_line", SaveModeToGlobal(), RefreshPreviewText()))
            layoutMenu.Add((layoutMode = "multi_line" ? "鉁?" : "") . "澶氳", (*) => (layoutMode := "multi_line", SaveModeToGlobal(), RefreshPreviewText()))
            layoutMenu.Add()
            layoutMenu.Add("鏍囩偣", punctMenu)

            MouseGetPos(&mx, &my)
            layoutMenu.Show(mx, my)
        }

        DirectCopyCheck.OnEvent("Click", (*) => (
            this.ScreenshotOCRDirectCopyEnabled := (DirectCopyCheck.Value = 1),
            this.ScreenshotOCRSavePrefs()
        ))
        LayoutBtn.OnEvent("Click", ShowLayoutMenu)
        CopyBtn.OnEvent("Click", CopyCurrentText)
        PasteBtn.OnEvent("Click", PasteCurrentText)
        OCRResultGui.Show("w580 h366")
        RefreshPreviewText()
        ToolTip()
    } catch as e {
        ToolTip()
        TrayTip("閿欒", "OCR璇嗗埆澶辫触: " . e.Message, "Iconx 2")
    }
}

    static ScreenshotEditorExtractText(showProgressTip := true) {

    try {
        if (!this.ScreenshotEditorBitmap || this.ScreenshotEditorBitmap <= 0) {
            TrayTip("错误", "没有可用的截图", "Iconx 2")
            return ""
        }

        if (showProgressTip) {
            TrayTip("识别中", "正在识别截图文本...", "Iconi 1")
        }

        tempPath := A_Temp "\OCR_SS_Action_" . A_TickCount . ".png"
        result := Gdip_SaveBitmapToFile(this.ScreenshotEditorBitmap, tempPath)
        if (result != 0) {
            TrayTip("閿欒", "淇濆瓨涓存椂鍥剧墖澶辫触", "Iconx 2")
            return ""
        }

        ocrResult := OCR.FromFile(tempPath, "zh-CN")
        try FileDelete(tempPath)

        if (!ocrResult) {
            TrayTip("閿欒", "OCR璇嗗埆澶辫触", "Iconx 2")
            return ""
        }

        recognizedText := ""
        try {
            if (ocrResult.HasProp("Text")) {
                recognizedText := Trim(String(ocrResult.Text))
            }
        } catch {
            recognizedText := ""
        }

        if (recognizedText = "") {
            TrayTip("鎻愮ず", "鏈瘑鍒埌鍙敤鏂囨湰", "Iconi 1")
            return ""
        }
        return recognizedText
    } catch as e {
        TrayTip("閿欒", "OCR璇嗗埆澶辫触: " . e.Message, "Iconx 2")
        return ""
    }
}

    static ScreenshotEditorSendToAI() {
    text := this.ScreenshotEditorExtractText(true)
    if (text = "")
        return
    try {
        ok := FloatingToolbar_SendTextToNiumaChat(text, true, true, true)
        if (ok) {
            TrayTip("AI", "鎴浘鏂囨湰宸插彂閫佸埌 AI", "Iconi 1")
        } else {
            TrayTip("AI", "发送失败，请重试", "Iconx 1")
        }
    } catch as e {
        TrayTip("AI", "鍙戦€佸け璐? " . e.Message, "Iconx 1")
    }
}

    static ScreenshotEditorSearchText() {
    text := this.ScreenshotEditorExtractText(true)
    if (text = "")
        return
    try {
        SearchCenter_RunQueryWithKeyword(text)
    } catch as e {
        TrayTip("鎼滅储", "鎵撳紑鎼滅储澶辫触: " . e.Message, "Iconx 1")
    }
}

    static ScreenshotEditorEditOCRInHubCapsule() {
    text := this.ScreenshotEditorExtractText(true)
    if (text = "")
        return
    formatted := this.ScreenshotOCRApplyTextFormatting(text)
    if (formatted = "")
        return
    ; 鍘绘帀鎴浘宸ュ叿鏍忚嚜寤虹殑 HubCapsule 鑱斿姩杞鏈哄埗锛屾敼涓哄鐢ㄦ偓娴伐鍏锋爮/SelectionSense 鐨勬爣鍑嗘墦寮€涓庨瑙堝～鍏呴摼璺細
    ; SelectionSense_OpenHubCapsuleFromToolbar 浼氳缃?pendingText 骞跺湪 WebView ready 鍚庤嚜鍔ㄦ帹閫佸埌棰勮鍖恒€?
    try {
        global g_SelSense_MenuActivateOnShow
        g_SelSense_MenuActivateOnShow := true
    } catch {
    }

    ; 鐩存帴璋冪敤 HubCapsule 鍘熺敓鎺ュ彛锛圫electionSenseCore锛夛紝骞剁敤鈥淐apsLock+C 鍚屾閲嶆帹鈥濅繚璇侀瑙堝尯涓€瀹氭敹鍒版枃鏈?
    try {
        try g_SelSense_PendingText := formatted
        SelectionSense_OpenHubCapsuleFromToolbar(false, formatted)
        ; HubCapsule/WebView2 鍐峰惎鍔ㄦ椂 selection_menu_ready 鍙兘婊炲悗锛屽欢杩熼噸鎺ㄤ袱娆?+ 杞鍏滃簳
        SetTimer(this.ScreenshotEditor_ResyncHubPreviewAfterOcrBind(formatted), -250)
        SetTimer(this.ScreenshotEditor_ResyncHubPreviewAfterOcrBind(formatted), -850)
        TrayTip("草稿本", "已打开 HubCapsule 并填入 OCR 文本", "Iconi 1")
        return
    } catch as e1 {
        ; 鍙兘鏄ā鍧楁湭鍒濆鍖?鐑噸杞介『搴忛棶棰橈細灏濊瘯鍏?Init 鍐嶈皟鐢ㄤ竴娆?
        try {
            if FuncExists("SelectionSense_Init")
                SelectionSense_Init()
        } catch {
        }
        try {
            SelectionSense_OpenHubCapsuleFromToolbar(false, formatted)
            SetTimer(this.ScreenshotEditor_ResyncHubPreviewAfterOcrBind(formatted), -250)
            SetTimer(this.ScreenshotEditor_ResyncHubPreviewAfterOcrBind(formatted), -850)
            TrayTip("草稿本", "已打开 HubCapsule 并填入 OCR 文本", "Iconi 1")
            return
        } catch as e2 {
            ; 鍘熺敓鍏滃簳锛氳蛋鍛戒护绯荤粺瑙﹀彂 hub_capsule锛堜笌鎮诞宸ュ叿鏍?铏氭嫙閿洏鍚屾簮锛?
            try {
                if FuncExists("_ExecuteCommand") {
                    _ExecuteCommand("hub_capsule")
                    ; 鎶婃枃鏈寕鍒?SelectionSense pending锛岀瓑 ready 鍚庣敱鍏舵帹閫?
                    try g_SelSense_PendingText := formatted
                    SetTimer(this.ScreenshotEditor_ResyncHubPreviewAfterOcrBind(formatted), -250)
                    SetTimer(this.ScreenshotEditor_ResyncHubPreviewAfterOcrBind(formatted), -850)
                    TrayTip("草稿本", "已触发 hub_capsule 打开，请稍候...", "Iconi 1")
                    return
                }
            } catch {
            }
            ; 鏈€鍚庡厹搴曪細鏃犳硶鎵撳紑鍒欏鍒跺埌鍓创鏉?
            try A_Clipboard := formatted
            TrayTip("草稿本", "HubCapsule 入口不可用，已复制 OCR 文本到剪贴板", "Iconi 1")
            return
        }
    }
}

; OCR -> HubCapsule锛氭寜 CapsLock+C 鐨勯€昏緫閲嶆帹涓€娆￠瑙堟枃鏈紝瑕嗙洊 WebView2 鍐峰惎鍔?鍔ㄧ敾鏈熶涪娑堟伅
    static ScreenshotEditor_ResyncHubPreviewAfterOcrBind(text) {
    ; Bind helper锛氳繑鍥為棴鍖咃紝閬垮厤 AHK v2 SetTimer 鐩存帴浼犲弬鐨勫吋瀹归棶棰?
    return (*) => this.ScreenshotEditor_ResyncHubPreviewAfterOcrTick(text)
}

    static ScreenshotEditor_ResyncHubPreviewAfterOcrTick(text) {
    static attempt := 0
    global g_SelSense_MenuReady, g_SelSense_PendingText
    t := Trim(String(text), " `t`r`n")
    if (t = "")
        return
    attempt += 1
    ; 鏈€澶氱害 3 绉掞細15 * 200ms
    if (attempt > 15) {
        attempt := 0
        return
    }
    try g_SelSense_PendingText := t
    try {
        if (IsSet(g_SelSense_MenuReady) && g_SelSense_MenuReady && FuncExists("SelectionSense_PushMenuText")) {
            SelectionSense_PushMenuText(t)
            attempt := 0
            return
        }
    } catch {
    }
    SetTimer(this.ScreenshotEditor_ResyncHubPreviewAfterOcrBind(t), -200)
}

    static ScreenshotEditorPushOCRToHubCapsuleTick(*) {
    ; 鍏煎鏃х増鏈細璇ュ嚱鏁板凡搴熷純锛堟埅鍥惧伐鍏锋爮 OCR->HubCapsule 鏀逛负澶嶇敤 SelectionSense_OpenHubCapsuleFromToolbar锛?
    return
}

    static ScreenshotEditorEnsureHubCapsuleOpen(pendingText := "") {
    global g_SelSense_MenuActivateOnShow, g_SelSense_MenuGui, g_SelSense_MenuVisible, g_SelSense_MenuShowingHub
    opened := false
    t := Trim(String(pendingText), " `t`r`n")
    try {
        if FuncExists("SelectionSense_HubCapsuleHostIsOpen") && SelectionSense_HubCapsuleHostIsOpen()
            opened := true
    } catch {
    }

    ; 鎴浘 OCR 鍏ュ彛鐨勬湡鏈涙槸锛氫竴瀹氳鈥滄墦寮€骞舵縺娲?HubCapsule鈥?
    ; 浼樺厛璧?SelectionSenseCore 鐨勬爣鍑嗗叆鍙ｏ紙瀹冧細 Navigate HubCapsule.html 骞跺鐞嗘縺娲?鐒︾偣锛?
    if (!opened) {
        try {
            g_SelSense_MenuActivateOnShow := true
            if FuncExists("SelectionSense_OpenHubCapsuleFromToolbar") {
                SelectionSense_OpenHubCapsuleFromToolbar(false, t)
                opened := true
            }
        } catch {
        }
    }

    ; 鍏滃簳锛氬鐢ㄢ€滄偓娴伐鍏锋爮 NewPrompt 鎸夐挳鈥濈殑鍚屾簮鎵撳紑璺緞
    if (!opened) {
        try {
            g_SelSense_MenuActivateOnShow := true
            if FuncExists("FloatingToolbarExecuteButtonAction") {
                FloatingToolbarExecuteButtonAction("NewPrompt", 0)
                opened := true
            }
        } catch {
        }
    }

    if (!opened) {
        try {
            if FuncExists("FloatingToolbar_DeferredToolbarCmd") {
                FloatingToolbar_DeferredToolbarCmd("hub_capsule")
                opened := true
            }
        } catch {
        }
    }

    try {
        ; 寮哄埗鏈灞曠ず鎶㈢劍鐐癸細鎴浘宸ュ叿鏍忓叆鍙ｉ渶瑕佲€滄縺娲昏崏绋挎湰寮圭獥鈥?
        g_SelSense_MenuActivateOnShow := true
        if FuncExists("SelectionSense_ShowMenuNearCursor")
            SelectionSense_ShowMenuNearCursor()
    } catch {
    }

    ; 鑻ュ涓诲凡瀛樺湪涓斿彲瑙佷絾鏈湪鍓嶅彴锛屽啀鍏滃簳婵€娲讳竴娆★紙WebView2 鍐呯劍鐐规湁鏃朵細琚叾浠栫獥鍙ｆ姠璧帮級
    try {
        if (IsSet(g_SelSense_MenuGui) && g_SelSense_MenuGui && IsSet(g_SelSense_MenuVisible) && g_SelSense_MenuVisible
            && IsSet(g_SelSense_MenuShowingHub) && g_SelSense_MenuShowingHub) {
            WinActivate("ahk_id " . g_SelSense_MenuGui.Hwnd)
        }
    } catch {
    }
    return opened
}

; 澶嶅埗鎴浘鍒板壀璐存澘
    static CopyScreenshotToClipboard(closeAfter := true) {
    global ScreenshotClipboard

    try {
        ; 濡傛灉浣嶅浘宸蹭慨鏀癸紝闇€瑕佷繚瀛樺苟閲嶆柊璁剧疆鍒板壀璐存澘
        if (this.ScreenshotEditorBitmap) {
            ; 鐩存帴浣跨敤Gdip_SetBitmapToClipboard璁剧疆鍒板壀璐存澘
            Gdip_SetBitmapToClipboard(this.ScreenshotEditorBitmap)
            TrayTip("成功", "截图已复制到剪贴板", "Iconi 1")
        } else if (ScreenshotClipboard) {
            ; 濡傛灉娌℃湁缂栬緫锛岀洿鎺ヤ娇鐢ㄥ師濮嬫埅鍥?
            A_Clipboard := ScreenshotClipboard
            TrayTip("成功", "截图已复制到剪贴板", "Iconi 1")
        }

        ; 鎸夐渶鍏抽棴棰勮绐?
        if (closeAfter)
            this.CloseScreenshotEditor()
    } catch as e {
        TrayTip("閿欒", "澶嶅埗澶辫触: " . e.Message, "Iconx 2")
    }
}

; 绮樿创鎴浘涓虹函鏂囨湰锛圤CR璇嗗埆鍚庣矘璐达級
    static PasteScreenshotAsText() {

    try {
        ; 鍏堟墽琛孫CR璇嗗埆
        if (!this.ScreenshotEditorBitmap) {
            TrayTip("错误", "没有可用的截图", "Iconx 2")
            return
        }

        ; 淇濆瓨涓存椂鍥剧墖鐢ㄤ簬OCR
        TempPath := A_Temp "\OCR_Temp_" . A_TickCount . ".png"
        result := Gdip_SaveBitmapToFile(this.ScreenshotEditorBitmap, TempPath)
        if (result != 0) {
            TrayTip("閿欒", "淇濆瓨涓存椂鍥剧墖澶辫触", "Iconx 2")
            return
        }

        ; 鎵цOCR璇嗗埆
        TrayTip("识别中", "正在识别图片中的文字...", "Iconi 1")
        ocrResult := OCR.FromFile(TempPath, "zh-CN")

        ; 鍒犻櫎涓存椂鏂囦欢
        try {
            FileDelete(TempPath)
        } catch {
        }

        if (!ocrResult) {
            TrayTip("閿欒", "OCR璇嗗埆澶辫触", "Iconx 2")
            return
        }

        ; 鑾峰彇璇嗗埆鏂囨湰
        recognizedText := ""
        try {
            if (ocrResult.HasProp("Text")) {
                recognizedText := ocrResult.Text
            }
        } catch {
        }

        if (recognizedText = "") {
            TrayTip("閿欒", "鏈瘑鍒埌鏂囧瓧", "Iconx 2")
            return
        }

        ; 鎸?OCR 鎺掔増璁剧疆澶勭悊鍚庡鍒跺埌鍓创鏉?
        formattedText := this.ScreenshotOCRApplyTextFormatting(recognizedText)
        A_Clipboard := formattedText
        TrayTip("成功", "文字已复制到剪贴板（" . this.ScreenshotOCRLayoutModeLabel(this.ScreenshotOCRTextLayoutMode) . "）", "Iconi 1")

        ; 鍏抽棴棰勮绐?
        this.CloseScreenshotEditor()

        ; 绛夊緟涓€涓嬶紝鐒跺悗鑷姩绮樿创
        Sleep(200)
        Send("^v")
    } catch as e {
        TrayTip("閿欒", "OCR璇嗗埆澶辫触: " . e.Message, "Iconx 2")
    }
}

; 淇濆瓨鎴浘鍒版枃浠?
    static SaveScreenshotToFile(closeAfter := true) {
    global ClipboardDB
    
    try {
        ; 寮瑰嚭淇濆瓨瀵硅瘽妗?
        FilePath := FileSelect("S16", A_Desktop, "淇濆瓨鎴浘", "鍥剧墖鏂囦欢 (*.png; *.jpg; *.bmp)")
        if (!FilePath) {
            return
        }
        
        ; 纭畾鏂囦欢鏍煎紡
        Ext := StrLower(SubStr(FilePath, InStr(FilePath, ".", , -1) + 1))
        if (Ext != "png" && Ext != "jpg" && Ext != "jpeg" && Ext != "bmp") {
            Ext := "png"
            FilePath .= ".png"
        }
        
        ; 淇濆瓨浣嶅浘
        if (this.ScreenshotEditorBitmap) {
            ; 鑾峰彇缂栫爜鍣–LSID
            if (Ext = "png") {
                EncoderCLSID := "{557CF406-1A04-11D3-9A73-0000F81EF32E}"
            } else if (Ext = "jpg" || Ext = "jpeg") {
                EncoderCLSID := "{557CF401-1A04-11D3-9A73-0000F81EF32E}"
            } else {
                EncoderCLSID := "{557CF400-1A04-11D3-9A73-0000F81EF32E}"  ; BMP
            }
            
            ; 淇濆瓨鏂囦欢锛圙dip_SaveBitmapToFile绗笁涓弬鏁版槸Quality锛屼笉鏄疎ncoderCLSID锛?
            ; 闇€瑕佹牴鎹墿灞曞悕浣跨敤涓嶅悓鐨勪繚瀛樻柟寮?
            if (Ext = "png") {
                Gdip_SaveBitmapToFile(this.ScreenshotEditorBitmap, FilePath)
            } else if (Ext = "jpg" || Ext = "jpeg") {
                Gdip_SaveBitmapToFile(this.ScreenshotEditorBitmap, FilePath, 90)  ; Quality = 90
            } else {
                Gdip_SaveBitmapToFile(this.ScreenshotEditorBitmap, FilePath)
            }
            
            ; 淇濆瓨鍒扮紦瀛樼洰褰?
            CacheDir := A_ScriptDir "\Cache"
            if (!DirExist(CacheDir)) {
                DirCreate(CacheDir)
            }
            CachePath := CacheDir "\Screenshot_" . A_Now . "." . Ext
            FileCopy(FilePath, CachePath, 1)
            
            ; 淇濆瓨鍒版暟鎹簱
            if (ClipboardDB && ClipboardDB != 0) {
                try {
                    ; 杞箟璺緞涓殑鍗曞紩鍙?
                    EscapedPath := StrReplace(CachePath, "'", "''")
                    SQL := "INSERT INTO ClipboardHistory (Content, SourceApp, DataType, CharCount, WordCount, Timestamp) VALUES ('" . EscapedPath . "', 'ScreenshotEditor', 'Image', " . StrLen(CachePath) . ", 1, datetime('now', 'localtime'))"
                    ClipboardDB.Exec(SQL)
                } catch as err {
                    ; 蹇界暐鏁版嵁搴撻敊璇?
                }
            }
            
            TrayTip("鎴愬姛", "鎴浘宸蹭繚瀛? " . FilePath, "Iconi 1")
        } else {
            TrayTip("閿欒", "娌℃湁鍙繚瀛樼殑鍥剧墖", "Iconx 2")
        }
        
        ; 鎸夐渶鍏抽棴棰勮绐?
        if (closeAfter)
            this.CloseScreenshotEditor()
    } catch as e {
        TrayTip("閿欒", "淇濆瓨澶辫触: " . e.Message, "Iconx 2")
    }
}

    static _SyncHub() {
        global GuiID_ScreenshotEditor, GuiID_ScreenshotToolbar, ScreenshotEditorPreviewPic, ScreenshotColorPickerActive
        GuiID_ScreenshotEditor := ScreenshotEditorPlugin.GuiID_ScreenshotEditor
        GuiID_ScreenshotToolbar := ScreenshotEditorPlugin.GuiID_ScreenshotToolbar
        ScreenshotEditorPreviewPic := ScreenshotEditorPlugin.ScreenshotEditorPreviewPic
        ScreenshotColorPickerActive := ScreenshotEditorPlugin.ScreenshotColorPickerActive
    }

}

; 婊氳疆缂╂斁锛堥』鍦ㄧ被瀹氫箟涔嬪悗锛?HotIf 涓嶈兘鏀惧湪 class 浣撳唴锛?
#HotIf ScreenshotEditorPlugin_IsZoomHotkeyActive()
WheelUp:: {
    ScreenshotEditorPlugin.ScreenshotEditorZoomWithWheel(1)
}
WheelDown:: {
    ScreenshotEditorPlugin.ScreenshotEditorZoomWithWheel(-1)
}
#HotIf

#HotIf ScreenshotEditorPlugin_IsColorPickerHotkeyActive()
~LButton:: {
    ScreenshotEditorPlugin.ScreenshotColorPickerCaptureAtCursor()
}
#HotIf

ScreenshotEditorPlugin_IsZoomHotkeyActive() {
    return ScreenshotEditorPlugin.IsScreenshotEditorZoomHotkeyActive()
}

ScreenshotEditorPlugin_IsColorPickerHotkeyActive() {
    global ScreenshotColorPickerActive
    return IsSet(ScreenshotColorPickerActive) && ScreenshotColorPickerActive
}
