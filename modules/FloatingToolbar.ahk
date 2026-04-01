; ======================================================================================================================
; 鎮诞宸ュ叿鏍?- 绫讳技杈撳叆娉曠殑鎮诞绐?
; 鐗堟湰: 1.1.0
; 鍔熻兘: 
;   - 绫讳技杈撳叆娉曠殑鎮诞闀挎潯绐楀彛
;   - 宸﹂敭鎷栧姩
;   - 鍙抽敭寮瑰嚭鑿滃崟鍏抽棴
;   - 6涓姛鑳芥寜閽細鎼滅储銆佺瑪璁般€丄I鍔╂墜銆佹埅鍥俱€佽缃紙浣跨敤鍥剧墖鍥炬爣锛?
;   - Cursor鑹茬郴閰嶈壊
; 
; 鍥炬爣鏂囦欢瑕佹眰锛?
;   - 鍥炬爣鏂囦欢搴旀斁鍦?images 鐩綍涓?
;   - 鏂囦欢鍛藉悕锛堟寜椤哄簭锛夛細toolbar_search.png, toolbar_note.png, toolbar_ai.png, toolbar_screenshot.png, toolbar_settings.png, toolbar_virtualkeyboard.png
;   - 鎺ㄨ崘灏哄锛?6x16 鎴?20x20 鍍忕礌锛孭NG鏍煎紡锛屾敮鎸侀€忔槑鑳屾櫙
;   - 濡傛灉鍥炬爣鏂囦欢涓嶅瓨鍦紝灏嗕娇鐢ㄦ枃瀛椾綔涓哄悗澶囨樉绀?
; ======================================================================================================================

#Requires AutoHotkey v2.0

; 娉ㄦ剰锛氭妯″潡闇€瑕佷富鑴氭湰宸插寘鍚?ClipboardHistoryPanel.ahk 妯″潡
; 濡傛灉鍑芥暟涓嶅瓨鍦紝灏嗕娇鐢ㄥ揩鎹烽敭浣滀负鍚庡

; 鍔犺浇 Gdip 搴撶敤浜庡浘鐗囬鑹叉护闀滄晥鏋?
#Include ..\lib\Gdip_All.ahk

; ===================== 鍏ㄥ眬鍙橀噺 =====================
global FloatingToolbarGUI := 0  ; 鎮诞绐桮UI瀵硅薄
global FloatingToolbarIsVisible := false  ; 鏄惁鍙
global FloatingToolbarDragging := false  ; 鏄惁姝ｅ湪鎷栧姩
global FloatingToolbarDragStartX := 0  ; 鎷栧姩璧峰X鍧愭爣
global FloatingToolbarDragStartY := 0  ; 鎷栧姩璧峰Y鍧愭爣
global FloatingToolbarWindowX := 0  ; 绐楀彛X鍧愭爣
global FloatingToolbarWindowY := 0  ; 绐楀彛Y鍧愭爣
global FloatingToolbarButtons := Map()  ; 瀛樺偍鎸夐挳淇℃伅锛堢敤浜庢偓鍋滄娴嬶級
global FloatingToolbarHoveredButton := 0  ; 褰撳墠鎮仠鐨勬寜閽?
global FloatingToolbarClickedButton := 0  ; 褰撳墠鐐瑰嚮鐨勬寜閽?
global FloatingToolbarButtonDownTime := 0  ; 鎸夐挳鎸変笅鏃堕棿锛堢敤浜庡尯鍒嗙偣鍑诲拰鎷栧姩锛?
global FloatingToolbarTooltipText := ""  ; Tooltip鏂囨湰
global FloatingToolbarTooltipTimer := 0  ; Tooltip瀹氭椂鍣?
global FloatingToolbarIsMinimized := false  ; 鏄惁宸叉渶灏忓寲鍒拌竟缂?
global FloatingToolbarSelectedButton := 0  ; 褰撳墠閫変腑鐨勬寜閽紙鏄剧ず姗欒壊鐐癸級
global FloatingToolbarScale := 1.0  ; 宸ュ叿鏍忕缉鏀炬瘮渚嬶紙1.0 = 100%锛?
global FloatingToolbarMinScale := 0.7  ; 鏈€灏忕缉鏀炬瘮渚嬶紙70%锛?
global FloatingToolbarMaxScale := 1.5  ; 鏈€澶х缉鏀炬瘮渚嬶紙150%锛?
global FloatingToolbarPressedButton := 0  ; 褰撳墠鎸変笅鐨勬寜閽紙鐢ㄤ簬涓嬫矇鏁堟灉锛?
global FloatingToolbarGdipToken := 0  ; Gdip token
global FloatingToolbarGdipInitialized := false  ; Gdip鏄惁宸插垵濮嬪寲
global FloatingToolbarInitialMouseX := 0  ; 鐐瑰嚮鏃剁殑鍒濆榧犳爣X鍧愭爣
global FloatingToolbarInitialMouseY := 0  ; 鐐瑰嚮鏃剁殑鍒濆榧犳爣Y鍧愭爣
global FloatingToolbarMouseMoved := false  ; 榧犳爣鏄惁绉诲姩

; Cursor鑹茬郴閰嶈壊
FloatingToolbarColors := {
    Background: "1e1e1e",
    Border: "3c3c3c",
    Text: "cccccc",
    TextHover: "ffffff",
    ButtonBg: "252526",
    ButtonHover: "37373d",
    ButtonActive: "007acc",
    ButtonBorder: "3c3c3c"
}

; ===================== 鏄剧ず/闅愯棌鎮诞绐?=====================
ShowFloatingToolbar() {
    global FloatingToolbarGUI, FloatingToolbarIsVisible, FloatingToolbarWindowX, FloatingToolbarWindowY

    if (FloatingToolbarIsVisible && FloatingToolbarGUI != 0) {
        return
    }

    ; 鍒濆鍖朑dip锛堢敤浜庢寜閽壒鏁堬級
    FloatingToolbarInitializeGdip()

    ; 鍔犺浇缂╂斁姣斾緥
    FloatingToolbarLoadScale()

    ; 鍒涘缓GUI
    CreateFloatingToolbarGUI()

    ; [闇€姹?] 浠庨厤缃枃浠跺姞杞戒繚瀛樼殑浣嶇疆
    LoadFloatingToolbarPosition()

    ; 鏄剧ずGUI锛堥粯璁や綅缃細灞忓箷鍙充笅瑙掞級
    if (FloatingToolbarWindowX = 0 && FloatingToolbarWindowY = 0) {
        ; 鑾峰彇灞忓箷灏哄
        ScreenWidth := SysGet(0)  ; SM_CXSCREEN
        ScreenHeight := SysGet(1)  ; SM_CYSCREEN

        ; 璁＄畻绐楀彛瀹藉害鍜岄珮搴︼紙浣跨敤鍩虹灏哄鍜岀缉鏀炬瘮渚嬶級
        ToolbarWidth := FloatingToolbarCalculateWidth()
        ToolbarHeight := FloatingToolbarCalculateHeight()
        FloatingToolbarWindowX := ScreenWidth - ToolbarWidth
        FloatingToolbarWindowY := ScreenHeight - ToolbarHeight
    }

    ; 璁＄畻绐楀彛瀹藉害鍜岄珮搴?
    ToolbarWidth := FloatingToolbarCalculateWidth()
    ToolbarHeight := FloatingToolbarCalculateHeight()
    FloatingToolbarGUI.Show("x" . FloatingToolbarWindowX . " y" . FloatingToolbarWindowY . " w" . ToolbarWidth . " h" . ToolbarHeight)
    FloatingToolbarIsVisible := true

    ; 搴旂敤鍦嗚杈规锛堢獥鍙ｆ樉绀哄悗锛?
    FloatingToolbarApplyRoundedCorners()

    ; 鍚姩瀹氭椂鍣ㄧ敤浜庢偓鍋滄晥鏋滄娴嬪拰浣嶇疆妫€鏌ワ紙浼樺寲棰戠巼涓?00ms锛?
    SetTimer(FloatingToolbarCheckButtonHover, 100)
    SetTimer(FloatingToolbarCheckWindowPosition, 100)
    SetTimer(FloatingToolbarCheckButtonDrag, 50)
}

HideFloatingToolbar() {
    global FloatingToolbarGUI, FloatingToolbarIsVisible, FloatingToolbarWindowX, FloatingToolbarWindowY

    if (FloatingToolbarGUI != 0) {
        ; [闇€姹?] 淇濆瓨褰撳墠浣嶇疆鍒伴厤缃枃浠?
        SaveFloatingToolbarPosition()

        FloatingToolbarGUI.Hide()
        FloatingToolbarIsVisible := false

        ; 鍋滄瀹氭椂鍣?
        SetTimer(FloatingToolbarCheckButtonHover, 0)
        SetTimer(FloatingToolbarCheckWindowPosition, 0)
        SetTimer(FloatingToolbarCheckButtonDrag, 0)

        ; 娓呯悊Gdip璧勬簮
        FloatingToolbarShutdownGdip()
    }
}

ToggleFloatingToolbar() {
    global FloatingToolbarIsVisible
    
    if (FloatingToolbarIsVisible) {
        HideFloatingToolbar()
    } else {
        ShowFloatingToolbar()
    }
}

; ===================== 鍒涘缓GUI =====================
CreateFloatingToolbarGUI() {
    global FloatingToolbarGUI, FloatingToolbarColors
    
    ; 濡傛灉宸插瓨鍦紝鍏堥攢姣?
    if (FloatingToolbarGUI != 0) {
        try {
            FloatingToolbarGUI.Destroy()
        } catch {
        }
    }
    
    ; 鍒涘缓GUI锛堟棤杈规銆佺疆椤躲€佸彲鎷栧姩锛?
    FloatingToolbarGUI := Gui("+AlwaysOnTop -Caption +ToolWindow", "悬浮工具栏")
    FloatingToolbarGUI.BackColor := FloatingToolbarColors.Background
    FloatingToolbarGUI.SetFont("s10 c" . FloatingToolbarColors.Text, "Segoe UI")
    
    ; 绐楀彛浜嬩欢
    FloatingToolbarGUI.OnEvent("Close", OnFloatingToolbarClose)
    
    ; 鍒涘缓鎸夐挳瀹瑰櫒锛堣儗鏅紝缂╁皬涓€鍊嶏級
    ; 娉ㄦ剰锛氫笉娣诲姞鑳屾櫙鎺т欢锛岃鏁翠釜绐楀彛閮藉彲浠ユ嫋鍔?
    ; ToolbarBg := FloatingToolbarGUI.Add("Text",
    ;     "x0 y0 w160 h25 Background" . FloatingToolbarColors.Background, "")

    ; 鎸夐挳閰嶇疆锛氭悳绱€佺瑪璁般€丄I鍔╂墜銆佹埅鍥俱€佽缃紙浣跨敤鍥剧墖鍥炬爣锛?
    ; 鍥炬爣鏂囦欢璺緞锛堟寜椤哄簭锛氭悳绱€佺瑪璁般€丄I銆佹埅鍥俱€佽缃級
    IconPaths := [
        A_ScriptDir . "\images\toolbar_search.png",
        A_ScriptDir . "\images\toolbar_note.png",
        A_ScriptDir . "\images\toolbar_ai.png",
        A_ScriptDir . "\images\toolbar_screenshot.png",
        A_ScriptDir . "\images\toolbar_settings.png",
        A_ScriptDir . "\images\toolbar_virtualkeyboard.png"
    ]
    
    ButtonConfigs := [
        Map("text", "搜索", "iconPath", IconPaths[1], "action", "Search", "shortcut", "Caps+F"),
        Map("text", "记录", "iconPath", IconPaths[2], "action", "Record", "shortcut", "Caps+X"),
        Map("text", "提示词", "iconPath", IconPaths[3], "action", "AIAssistant", "shortcut", "Ctrl+Shift+B"),
        Map("text", "截图", "iconPath", IconPaths[4], "action", "Screenshot", "shortcut", "Caps+T"),
        Map("text", "设置", "iconPath", IconPaths[5], "action", "Settings", "shortcut", "Caps+Q"),
        Map("text", "键盘", "iconPath", IconPaths[6], "action", "VirtualKeyboard", "shortcut", "Ctrl+Shift+K")
    ]
    
    ; 鎸夐挳灏哄鍜岄棿璺濓紙澧炲ぇ灏哄锛屽簲鐢ㄧ缉鏀炬瘮渚嬶級
    global FloatingToolbarScale
    BaseButtonWidth := 40
    BaseButtonHeight := 40
    BaseButtonSpacing := 5
    BaseIconSize := 28  ; 鍥炬爣澶у皬锛堟寜閽唴閮紝澧炲ぇ浠ユ樉绀烘洿娓呮櫚鐨勫浘鐗囷級
    BaseOuterPadding := 6
    BaseIconGap := 6
    BaseFavIconSize := 28
    BaseStartX := BaseOuterPadding + BaseFavIconSize + BaseIconGap
    BaseStartY := BaseOuterPadding
    
    ButtonWidth := Round(BaseButtonWidth * FloatingToolbarScale)
    ButtonHeight := Round(BaseButtonHeight * FloatingToolbarScale)
    ButtonSpacing := Round(BaseButtonSpacing * FloatingToolbarScale)
    IconSize := Round(BaseIconSize * FloatingToolbarScale)
    StartX := Round(BaseStartX * FloatingToolbarScale)
    StartY := Round(BaseStartY * FloatingToolbarScale)
    
    ; 娓呯┖鎸夐挳淇℃伅
    FloatingToolbarButtons := Map()

    ; 娣诲姞favicon鍥炬爣锛堝乏渚э紝浣跨敤缂╂斁姣斾緥锛?
    ; 灏濊瘯澶氫釜鍙兘鐨勮矾寰?
    FavIconPaths := [
        A_ScriptDir . "\favicon.ico",
        A_WorkingDir . "\favicon.ico",
        A_ScriptDir . "\..\favicon.ico"
    ]
    FavIconPath := ""
    for path in FavIconPaths {
        if (FileExist(path)) {
            FavIconPath := path
            break
        }
    }

    ; favicon 基础尺寸与位置（应用缩放比例）
    BaseFavIconX := BaseOuterPadding
    BaseFavIconY := BaseStartY + Floor((BaseButtonHeight - BaseFavIconSize) / 2)

    FavIconSize := Round(BaseFavIconSize * FloatingToolbarScale)
    FavIconX := Round(BaseFavIconX * FloatingToolbarScale)
    FavIconY := Round(BaseFavIconY * FloatingToolbarScale)

    if (FavIconPath != "") {
        IconPic := FloatingToolbarGUI.Add("Picture",
            "x" . FavIconX . " y" . FavIconY . " w" . FavIconSize . " h" . FavIconSize . " 0x200",
            FavIconPath)
        IconPic.OnEvent("ContextMenu", FloatingToolbarIconContextMenu)
    }

    ; 鍒涘缓鎸夐挳
    Loop ButtonConfigs.Length {
        index := A_Index
        config := ButtonConfigs[index]
        
        x := StartX + (index - 1) * (ButtonWidth + ButtonSpacing)
        
        ; 妫€鏌ュ浘鏍囨枃浠舵槸鍚﹀瓨鍦?
        iconPath := config["iconPath"]
        if (!FileExist(iconPath)) {
            ; 濡傛灉鏂囦欢涓嶅瓨鍦紝灏濊瘯鍏朵粬鍙兘鐨勮矾寰?
            actionLower := StrLower(config["action"])  ; 浣跨敤 StrLower 浠ｆ浛 LCase
            altPaths := [
                A_WorkingDir . "\images\toolbar_" . actionLower . ".png",
                A_ScriptDir . "\..\images\toolbar_" . actionLower . ".png"
            ]
            for altPath in altPaths {
                if (FileExist(altPath)) {
                    iconPath := altPath
                    break
                }
            }
        }
        
        ; 鍥炬爣浣嶇疆锛堝眳涓樉绀猴級
        ; 鎼滅储鎸夐挳浣跨敤鏇村ぇ鐨勫浘鏍囧昂瀵?
        currentIconSize := IconSize
        if (config["action"] = "Search") {
            currentIconSize := Round(IconSize * 1.2)  ; 鎼滅储鎸夐挳鏀惧ぇ20%
        }
        
        iconX := x + (ButtonWidth - currentIconSize) / 2  ; 灞呬腑
        iconY := StartY + (ButtonHeight - currentIconSize) / 2  ; 灞呬腑
        
        ; 鍒涘缓鍥剧墖鎺т欢锛堢洿鎺ヤ綔涓哄彲鐐瑰嚮鍖哄煙锛屼娇鐢?x200鏍峰紡淇濇寔鍥剧墖姣斾緥锛岄伩鍏嶅帇缂╋級
        if (FileExist(iconPath)) {
            iconPic := FloatingToolbarGUI.Add("Picture", 
                "x" . iconX . " y" . iconY . 
                " w" . currentIconSize . " h" . currentIconSize . 
                " BackgroundTrans 0x200 vToolbarIcon_" . config["action"], 
                iconPath)
        } else {
            ; 濡傛灉鍥炬爣鏂囦欢涓嶅瓨鍦紝浣跨敤鏂囧瓧浣滀负鍚庡
            iconPic := FloatingToolbarGUI.Add("Text", 
                "x" . x . " y" . StartY . 
                " w" . ButtonWidth . " h" . ButtonHeight . 
                " Center 0x200 c" . FloatingToolbarColors.Text . 
                " BackgroundTrans vToolbarIcon_" . config["action"], 
                SubStr(config["text"], 1, 1))  ; 鏄剧ず绗竴涓瓧绗?
        }
        
        iconPicHwnd := iconPic.Hwnd
        
        ; 鍒涘缓閫変腑鎸囩ず鍣紙姗欒壊鐐癸級- 鍒濆闅愯棌
        dotSize := 5  ; 鐐圭殑澶у皬锛堢◢寰澶э級
        dotX := x + (ButtonWidth - dotSize) / 2  ; 灞呬腑
        dotY := StartY + ButtonHeight - dotSize - 3  ; 鍥炬爣涓嬫柟
        
        selectedDot := FloatingToolbarGUI.Add("Text", 
            "x" . dotX . " y" . dotY . 
            " w" . dotSize . " h" . dotSize . 
            " BackgroundFF6600 cFF6600" .  ; 姗欒壊
            " vToolbarDot_" . config["action"], 
            "")
        selectedDot.Visible := false  ; 鍒濆闅愯棌
        
        ; [鏍稿績淇] 浣跨敤鍘熺敓 ToolTip 灞炴€?
        ; 鏍煎紡锛氬姛鑳藉悕绉?(蹇嵎閿?
        iconPic.ToolTip := config["text"] . " (" . config["shortcut"] . ")"
        
        ; 缁戝畾榧犳爣鐐瑰嚮浜嬩欢锛堜娇鐢ㄥ浘鐗囨帶浠讹級
        iconPic.OnEvent("Click", OnToolbarButtonClick.Bind(iconPic, config["action"], iconPicHwnd, config["text"]))
        iconPic.OnEvent("ContextMenu", FloatingToolbarIconContextMenu)
        
        ; 瀛樺偍鎸夐挳淇℃伅锛堢敤浜庢偓鍋滄娴嬪拰tooltip锛?
        FloatingToolbarButtons[iconPicHwnd] := {
            iconPic: iconPic,
            selectedDot: selectedDot,
            x: x,
            y: StartY,
            w: ButtonWidth,
            h: ButtonHeight,
            iconX: iconX,
            iconY: iconY,
            iconSize: currentIconSize,  ; 浣跨敤瀹為檯鍥炬爣灏哄锛堟悳绱㈡寜閽洿澶э級
            action: config["action"],
            tooltip: config["text"],
            shortcut: config["shortcut"],
            iconPath: iconPath,
            isHovered: false  ; 鎮仠鐘舵€?
        }
    }
    
    ; 涓烘墍鏈夋寜閽坊鍔犳嫋鍔ㄦ敮鎸侊紙閫氳繃瀹氭椂鍣ㄦ娴嬮暱鎸夛級
    SetTimer(FloatingToolbarCheckButtonDrag, 50)
    
    ; 浣跨敤绐楀彛浜嬩欢澶勭悊鎷栧姩锛堟洿鍙潬锛?
    FloatingToolbarGUI.OnEvent("ContextMenu", OnFloatingToolbarContextMenu)
    
    ; 鐩戝惉 WM_LBUTTONDOWN 娑堟伅锛屽疄鐜版暣涓獥鍙ｆ嫋鍔?
    ; 娉ㄦ剰锛氬繀椤诲湪GUI鍒涘缓鍚庢敞鍐屾秷鎭洃鍚?
    OnMessage(0x0201, FloatingToolbarWM_LBUTTONDOWN)  ; WM_LBUTTONDOWN
    
    ; 鐩戝惉榧犳爣婊氳疆娑堟伅锛屽疄鐜扮缉鏀惧姛鑳?
    OnMessage(0x020A, FloatingToolbarWM_MOUSEWHEEL)  ; WM_MOUSEWHEEL
}

; ===================== 鍦嗚杈规澶勭悊 =====================
; 搴旂敤鍦嗚杈规鍒扮獥鍙?
FloatingToolbarApplyRoundedCorners() {
    global FloatingToolbarGUI, FloatingToolbarScale
    
    if (FloatingToolbarGUI = 0) {
        return
    }
    
    try {
        ; 鑾峰彇绐楀彛灏哄
        FloatingToolbarGUI.GetPos(, , &winWidth, &winHeight)
        
        ; 鍦嗚鍗婂緞锛?px锛屽簲鐢ㄧ缉鏀炬瘮渚嬶級
        radius := Round(8 * FloatingToolbarScale)
        
        ; 浣跨敤 CreateRoundRectRgn 鍒涘缓鍦嗚鍖哄煙
        ; CreateRoundRectRgn(left, top, right, bottom, widthEllipse, heightEllipse)
        hRgn := DllCall("CreateRoundRectRgn"
            , "Int", 0
            , "Int", 0
            , "Int", winWidth
            , "Int", winHeight
            , "Int", radius * 2
            , "Int", radius * 2
            , "Ptr")
        
        if (hRgn) {
            ; 搴旂敤鍦嗚鍖哄煙鍒扮獥鍙?
            DllCall("SetWindowRgn"
                , "Ptr", FloatingToolbarGUI.Hwnd
                , "Ptr", hRgn
                , "Int", 1)  ; 1 = 閲嶇粯绐楀彛
            
            ; 娉ㄦ剰锛歋etWindowRgn 浼氭帴绠?hRgn 鐨勬墍鏈夋潈锛屼笉闇€瑕佹墜鍔ㄥ垹闄?
        }
    } catch {
        ; 濡傛灉璁剧疆鍦嗚澶辫触锛岄潤榛樺鐞?
    }
}

; ===================== WM_LBUTTONDOWN 娑堟伅澶勭悊锛堢畝鍖栫増锛?=====================
FloatingToolbarWM_LBUTTONDOWN(wParam, lParam, msg, hwnd) {
    global FloatingToolbarGUI, FloatingToolbarHoveredButton, FloatingToolbarButtons, FloatingToolbarClickedButton, FloatingToolbarButtonDownTime, FloatingToolbarDragging, FloatingToolbarColors
    
    ; 妫€鏌ユ槸鍚︽槸宸ュ叿鏍忕獥鍙?
    if (!FloatingToolbarGUI || hwnd != FloatingToolbarGUI.Hwnd) {
        return
    }
    
    ; 濡傛灉鐐瑰嚮鐨勬槸鎮诞绐楋紝涓斿綋鍓嶉紶鏍囨病鏈夋偓鍋滃湪浠讳綍鎸夐挳涓婏紙鍗崇偣鍑荤殑鏄┖鐧藉锛?
    if (FloatingToolbarHoveredButton = 0 && !FloatingToolbarDragging) {
        ; 鍙戦€?0xA1 (WM_NCLBUTTONDOWN) 娑堟伅锛屽弬鏁?2 浠ｈ〃鏍囬鏍?
        ; 杩欐牱绯荤粺浼氳嚜鍔ㄦ帴绠℃嫋鍔紝鎿嶄綔璧锋潵闈炲父椤烘粦
        PostMessage(0x00A1, 2, 0, FloatingToolbarGUI.Hwnd)
        return
    }
    
    ; 濡傛灉鐐瑰嚮鍦ㄦ寜閽笂锛岀珛鍗宠繘鍏ユ嫋鍔ㄦā寮忥紙濡傛灉娌℃湁鎶捣榧犳爣锛?
    if (FloatingToolbarHoveredButton != 0 && !FloatingToolbarDragging) {
        ; 璁板綍鎸変笅鐨勬寜閽拰鏃堕棿
        FloatingToolbarClickedButton := FloatingToolbarHoveredButton
        FloatingToolbarButtonDownTime := A_TickCount
        FloatingToolbarPressedButton := FloatingToolbarHoveredButton
        
        ; 璁板綍鍒濆榧犳爣浣嶇疆锛堢敤浜庢娴嬫槸鍚︾Щ鍔級
        MouseGetPos(&initialX, &initialY)
        global FloatingToolbarInitialMouseX := initialX
        global FloatingToolbarInitialMouseY := initialY
        global FloatingToolbarMouseMoved := false
        
        ; 搴旂敤涓嬫矇鏁堟灉锛堝潗鏍囦笅绉?px锛?
        FloatingToolbarApplyPressEffect(FloatingToolbarHoveredButton)
        
        ; 銆愪慨鏀广€戠珛鍗宠繘鍏ユ嫋鍔ㄦā寮忥紝鑰屼笉鏄瓑寰?50ms
        ; 濡傛灉榧犳爣娌℃湁绉诲姩灏辨姮璧凤紝浼氬湪 FloatingToolbarCheckButtonDrag 涓鐞嗙偣鍑?
        ; 濡傛灉榧犳爣绉诲姩浜嗭紝灏辨墽琛屾嫋鍔ㄦ搷浣?
    }
}


; ===================== 鎸夐挳鐐瑰嚮澶勭悊 =====================
OnToolbarButtonClick(iconPic, action, iconPicHwnd, tooltipText, *) {
    global FloatingToolbarDragging, FloatingToolbarSelectedButton, FloatingToolbarButtons, FloatingToolbarPressedButton
    
    ; 濡傛灉姝ｅ湪鎷栧姩锛屼笉澶勭悊鐐瑰嚮
    if (FloatingToolbarDragging) {
        return
    }
    
    ; 鎭㈠涓嬫矇鏁堟灉锛堝潗鏍囨仮澶嶏級
    if (FloatingToolbarPressedButton != 0) {
        FloatingToolbarRemovePressEffect(FloatingToolbarPressedButton)
        FloatingToolbarPressedButton := 0
    }
    
    ; 鏇存柊閫変腑鐘舵€侊紙鏄剧ず姗欒壊鐐癸級
    ; 鍏堥殣钘忔墍鏈夌偣鐨勯€変腑鐘舵€?
    for btnHwnd, btnInfo in FloatingToolbarButtons {
        if (btnInfo.HasProp("selectedDot")) {
            btnInfo.selectedDot.Visible := false
        }
    }
    
    ; 鏄剧ず褰撳墠鎸夐挳鐨勯€変腑鐐?
    if (FloatingToolbarButtons.Has(iconPicHwnd)) {
        if (FloatingToolbarButtons[iconPicHwnd].HasProp("selectedDot")) {
            FloatingToolbarButtons[iconPicHwnd].selectedDot.Visible := true
        }
        FloatingToolbarSelectedButton := iconPicHwnd
    }
    
    ; 鐩存帴鎵ц鍔ㄤ綔
    FloatingToolbarExecuteButtonAction(action, iconPicHwnd)
}

; 鎵ц鎸夐挳鍔ㄤ綔
FloatingToolbarExecuteButtonAction(action, buttonHwnd) {
    global FloatingToolbarDragging
    
    ; 濡傛灉姝ｅ湪鎷栧姩锛屼笉鎵ц鍔ㄤ綔
    if (FloatingToolbarDragging) {
        return
    }
    
    ; 鎵ц瀵瑰簲鐨勫姩浣滐紙鐩存帴璋冪敤绐楀彛鏄剧ず鍑芥暟锛?
    switch action {
        case "Search":
            ; 鐩存帴鏄剧ず鎼滅储涓績绐楀彛
            try {
                ShowSearchCenter()
            } catch as err {
                ; 濡傛灉鍑芥暟涓嶅瓨鍦ㄦ垨璋冪敤澶辫触锛屽彂閫佸揩鎹烽敭浣滀负鍚庡
                SetCapsLockState("AlwaysOff")
                Send("{CapsLock down}")
                Sleep(30)
                Send("f")
                Sleep(30)
                Send("{CapsLock up}")
                SetCapsLockState("Off")
            }
        case "Record":
            ; 鏄剧ず鍓创鏉跨鐞嗗櫒绐楀彛锛坈lipboard.AHK锛?
            ; 鐩存帴璋冪敤 ShowClipboardHistoryPanel 鍑芥暟
            try {
                ShowClipboardHistoryPanel()
            } catch as err {
                ; 濡傛灉鍑芥暟涓嶅瓨鍦ㄦ垨璋冪敤澶辫触锛屼娇鐢ㄥ揩鎹烽敭浣滀负鍚庡
                SetCapsLockState("AlwaysOff")
                Sleep(30)
                Send("{CapsLock down}")
                Sleep(30)
                Send("x")
                Sleep(30)
                Send("{CapsLock up}")
                Sleep(30)
                SetCapsLockState("Off")
            }
        case "AIAssistant":
            ; Prompt Quick-Pad：仅列表/搜索；摘录区仅 CapsLock+B（见 ShowPromptQuickPadListOnly）
            try {
                ShowPromptQuickPadListOnly()
            } catch as err {
                ; 濡傛灉AIListPanel妯″潡鏈姞杞斤紝浣跨敤榛樿琛屼负
                TrayTip("AI閫夋嫨闈㈡澘鍔犺浇澶辫触: " . err.Message, "閿欒", "Iconx 2")
            }
        case "Screenshot":
            ; [闇€姹?] 鎵ц鎴浘骞跺脊鍑烘埅鍥惧姪鎵嬭鐢ㄦ埛閫夋嫨
            try {
                ExecuteScreenshotWithMenu()
            } catch as err {
                ; 濡傛灉鍑芥暟涓嶅瓨鍦ㄦ垨璋冪敤澶辫触锛屽彂閫佸揩鎹烽敭浣滀负鍚庡
                SetCapsLockState("AlwaysOff")
                Send("{CapsLock down}")
                Sleep(30)
                Send("t")
                Sleep(30)
                Send("{CapsLock up}")
                SetCapsLockState("Off")
            }
        case "Settings":
            ; 鏄剧ず閰嶇疆闈㈡澘锛圕apsLock+Q 瀵瑰簲鐨勭獥鍙ｏ級
            try {
                ShowConfigGUI()
            } catch as err {
                ; 濡傛灉鍑芥暟涓嶅瓨鍦ㄦ垨璋冪敤澶辫触锛屽彂閫佸揩鎹烽敭浣滀负鍚庡
                SetCapsLockState("AlwaysOff")
                Send("{CapsLock down}")
                Sleep(30)
                Send("q")
                Sleep(30)
                Send("{CapsLock up}")
                SetCapsLockState("Off")
            }
        case "VirtualKeyboard":
            FloatingToolbarActivateVirtualKeyboard()
    }
}

; 启动或前台显示 VirtualKeyboard.ahk（窗口标题见 VirtualKeyboard.ahk 内 Gui）
FloatingToolbarActivateVirtualKeyboard() {
    vkScript := A_ScriptDir . "\VirtualKeyboard.ahk"
    if (!FileExist(vkScript)) {
        try {
            TrayTip("未找到 VirtualKeyboard.ahk: " . vkScript, "虚拟键盘", "Iconx 2")
        } catch {
        }
        return
    }
    ; 已运行时显示并激活（避免 #SingleInstance 再次 Run 重启脚本）
    vkWin := "VK KeyBinder ahk_class AutoHotkeyGUI"
    if (!WinExist(vkWin))
        vkWin := "VK KeyBinder"
    if (WinExist(vkWin)) {
        try {
            WinShow(vkWin)
            WinActivate(vkWin)
        } catch {
        }
        return
    }
    try {
        Run('"' . A_AhkPath . '" "' . vkScript . '"', A_ScriptDir)
    } catch as err {
        try {
            TrayTip("启动虚拟键盘失败: " . err.Message, "虚拟键盘", "Iconx 2")
        } catch {
        }
    }
}

; 妫€娴嬫寜閽嫋鍔紙鐐瑰嚮鏃跺鏋滄病鏈夋姮璧烽紶鏍囷紝榛樿鏄嫋鍔ㄦ搷浣滐級
FloatingToolbarCheckButtonDrag() {
    global FloatingToolbarGUI, FloatingToolbarButtons, FloatingToolbarDragging, FloatingToolbarButtonDownTime, FloatingToolbarClickedButton, FloatingToolbarIsVisible, FloatingToolbarColors, FloatingToolbarWindowX, FloatingToolbarWindowY
    global FloatingToolbarInitialMouseX, FloatingToolbarInitialMouseY, FloatingToolbarMouseMoved
    
    ; 濡傛灉绐楀彛涓嶅彲瑙侊紝涓嶅鐞?
    if (!FloatingToolbarIsVisible || FloatingToolbarGUI = 0) {
        return
    }
    
    ; 濡傛灉榧犳爣宸﹂敭鎸変笅涓旀寜涓嬩簡鎸夐挳
    if (GetKeyState("LButton", "P") && FloatingToolbarClickedButton != 0) {
        ; 銆愪慨鏀广€戠珛鍗虫娴嬮紶鏍囨槸鍚︾Щ鍔紝涓嶉渶瑕佺瓑寰?50ms
        MouseGetPos(&mx, &my)
        
        ; 妫€鏌ラ紶鏍囨槸鍚︿粠鍒濆浣嶇疆绉诲姩浜嗭紙绉诲姩闃堝€硷細5鍍忕礌锛?
        if (FloatingToolbarInitialMouseX != 0 && FloatingToolbarInitialMouseY != 0) {
            if (Abs(mx - FloatingToolbarInitialMouseX) > 5 || Abs(my - FloatingToolbarInitialMouseY) > 5) {
                ; 榧犳爣绉诲姩浜嗭紝鏍囪涓哄凡绉诲姩
                FloatingToolbarMouseMoved := true
                
                ; 濡傛灉杩樻病鏈夎繘鍏ユ嫋鍔ㄦā寮忥紝绔嬪嵆杩涘叆鎷栧姩妯″紡
                if (!FloatingToolbarDragging) {
                    ; 鎭㈠涓嬫矇鏁堟灉
                    global FloatingToolbarPressedButton
                    if (FloatingToolbarPressedButton != 0) {
                        FloatingToolbarRemovePressEffect(FloatingToolbarPressedButton)
                        FloatingToolbarPressedButton := 0
                    }
                    
                    FloatingToolbarDragging := true
                    FloatingToolbarClickedButton := 0
                    
                    ; 浣跨敤鏍囧噯鐨刉indows鎷栧姩鏂规硶
                    FloatingToolbarGUI.GetPos(&winX, &winY)
                    FloatingToolbarWindowX := winX
                    FloatingToolbarWindowY := winY
                    PostMessage(0x00A1, 2, 0, FloatingToolbarGUI.Hwnd)  ; WM_NCLBUTTONDOWN, HTCAPTION
                    
                    ; 鍚姩瀹氭椂鍣ㄦ潵妫€娴嬫嫋鍔ㄧ粨鏉?
                    SetTimer(FloatingToolbarCheckDragEnd, 50)
                }
            }
        }
    } else {
        ; 榧犳爣閲婃斁锛屾鏌ユ槸鍚︽槸鐐瑰嚮锛堜笉鏄嫋鍔級
        if (FloatingToolbarClickedButton != 0 && !FloatingToolbarDragging) {
            ; 濡傛灉榧犳爣娌℃湁绉诲姩锛屾墽琛岀偣鍑绘搷浣?
            if (!FloatingToolbarMouseMoved) {
                ; 鎭㈠涓嬫矇鏁堟灉
                global FloatingToolbarPressedButton
                if (FloatingToolbarPressedButton != 0) {
                    FloatingToolbarRemovePressEffect(FloatingToolbarPressedButton)
                    FloatingToolbarPressedButton := 0
                }
                
                ; 鑾峰彇鎸夐挳淇℃伅骞舵墽琛屽姩浣?
                if (FloatingToolbarButtons.Has(FloatingToolbarClickedButton)) {
                    buttonInfo := FloatingToolbarButtons[FloatingToolbarClickedButton]
                    action := buttonInfo.action
                    
                    ; 鏇存柊閫変腑鐘舵€侊紙鏄剧ず姗欒壊鐐癸級
                    global FloatingToolbarSelectedButton
                    ; 鍏堥殣钘忔墍鏈夌偣鐨勯€変腑鐘舵€?
                    for btnHwnd, btn in FloatingToolbarButtons {
                        if (btn.HasProp("selectedDot")) {
                            btn.selectedDot.Visible := false
                        }
                    }
                    ; 鏄剧ず褰撳墠鎸夐挳鐨勯€変腑鐐?
                    if (buttonInfo.HasProp("selectedDot")) {
                        buttonInfo.selectedDot.Visible := true
                    }
                    FloatingToolbarSelectedButton := FloatingToolbarClickedButton
                    
                    ; 鎵ц鍔ㄤ綔
                    FloatingToolbarExecuteButtonAction(action, FloatingToolbarClickedButton)
                }
            }
            
            ; 閲嶇疆鐘舵€?
            FloatingToolbarClickedButton := 0
            FloatingToolbarInitialMouseX := 0
            FloatingToolbarInitialMouseY := 0
            FloatingToolbarMouseMoved := false
        }
    }
}

; ===================== 鎸夐挳鎮仠鏁堟灉锛圛D妫€娴嬬増 + 鍙岄噸淇濋櫓锛?=====================
FloatingToolbarCheckButtonHover() {
    global FloatingToolbarGUI, FloatingToolbarButtons, FloatingToolbarHoveredButton, FloatingToolbarColors, FloatingToolbarDragging, FloatingToolbarIsVisible
    
    static LastHovered := 0  ; 璁板綍涓婁竴娆℃偓鍋滅殑鎸夐挳
    
    ; 1. 鍩虹妫€鏌ワ細绐楀彛涓嶅瓨鍦ㄦ垨涓嶅彲瑙佸垯閫€鍑?
    if (!FloatingToolbarIsVisible || FloatingToolbarGUI = 0) {
        return
    }
    
    ; 2. 闃插共鎵帮細姝ｅ湪鎷栧姩鏃讹紝寮哄埗娓呴櫎鎻愮ず骞堕€€鍑?
    if (FloatingToolbarDragging) {
        ToolTip()
        return
    }
    
    try {
        ; [鏂规硶1] 浣跨敤鎺т欢鍙ユ焺妫€娴嬶紙鏈€鍑嗙‘锛?
        MouseGetPos(&mx, &my, &winHwnd, &ctrlHwnd, 2)
        
        ; 3. 妫€鏌ワ細榧犳爣鏄惁杩樺湪鎮诞绐楀唴锛?
        if (winHwnd != FloatingToolbarGUI.Hwnd) {
            ; 榧犳爣璺戝嚭鍘讳簡
            if (LastHovered != 0) {
                FloatingToolbarRestoreButtonColor(LastHovered)
                ToolTip() ; 娓呴櫎鎻愮ず
                LastHovered := 0
                FloatingToolbarHoveredButton := 0
            }
            return
        }
        
        ; 4. 妫€鏌ワ細榧犳爣涓嬬殑鎺т欢锛屾槸涓嶆槸鎴戜滑鐨勬寜閽箣涓€锛?
        currentHover := 0
        currentHoverInfo := 0
        
        ; 棣栧厛灏濊瘯閫氳繃鎺т欢鍙ユ焺妫€娴?
        if (ctrlHwnd && FloatingToolbarButtons.Has(ctrlHwnd)) {
            currentHover := ctrlHwnd
            currentHoverInfo := FloatingToolbarButtons[ctrlHwnd]
        } 
        ; [鍙岄噸淇濋櫓] 濡傛灉鎺т欢鍙ユ焺妫€娴嬪け璐ワ紝浣跨敤鍧愭爣妫€娴嬩綔涓哄閫?
        else {
            FloatingToolbarGUI.GetPos(&wx, &wy)
            relX := mx - wx
            relY := my - wy
            
            for buttonHwnd, btn in FloatingToolbarButtons {
                if (relX >= btn.x && relX <= btn.x + btn.w && relY >= btn.y && relY <= btn.y + btn.h) {
                    currentHover := buttonHwnd
                    currentHoverInfo := btn
                    break
                }
            }
        }
        
        ; 5. 鐘舵€佹満锛氬彧鏈夊綋鐘舵€佸彂鐢熸敼鍙樻椂锛堜粠A绉诲埌B锛屾垨浠庢棤绉诲埌鏈夛級鎵嶆墽琛屾搷浣?
        if (currentHover != LastHovered) {
            
            ; A. 鎶婃棫鐨勶紙涓婁竴涓級鎸夐挳棰滆壊鎭㈠鍘熸牱
            if (LastHovered != 0) {
                FloatingToolbarRestoreButtonColor(LastHovered)
            }
            
            ; B. 澶勭悊鏂扮姸鎬?
            if (currentHover != 0) {
                ; === 榧犳爣绉诲叆浜嗘寜閽?===

                ; 1. 鎮仠鍔ㄦ晥锛堝浘鏍囨斁澶ф晥鏋?+ 浜害澧炲己锛?
                try {
                    if (currentHoverInfo.HasProp("iconPic") && currentHoverInfo.HasProp("iconSize")) {
                        iconPic := currentHoverInfo.iconPic
                        if (Type(iconPic) != "Text") {
                            ; 鍥剧墖鎺т欢锛氭斁澶ф晥鏋滐紙浠?8鏀惧ぇ鍒?2锛?
                            hoverIconSize := currentHoverInfo.iconSize + 4
                            hoverIconX := currentHoverInfo.iconX - 2  ; 灞呬腑璋冩暣
                            hoverIconY := currentHoverInfo.iconY - 2
                            iconPic.Move(hoverIconX, hoverIconY, hoverIconSize, hoverIconSize)
                            currentHoverInfo.isHovered := true

                            ; 搴旂敤浜害澧炲己鐗规晥
                            FloatingToolbarApplyHoverBrightness(iconPic, currentHoverInfo)
                        } else {
                            ; 鏂囧瓧鍚庡锛氭敼鍙樻枃瀛楅鑹?
                            iconPic.Opt("c" . FloatingToolbarColors.TextHover)
                        }
                    }
                } catch as err {
                    ; 璋冭瘯锛氭樉绀烘偓鍋滈敊璇?
                    ToolTip("Hover Effect Error: " . err.Message)
                }

                ; 2. 寮瑰嚭鎻愮ず璇嶏紙灏忕櫧甯姪锛?
                action := currentHoverInfo.action
                tipText := GetButtonTip(action)
                ToolTip(tipText) ; 榛樿鍦ㄩ紶鏍囨梺杈规樉绀猴紝鏈€绗﹀悎鐩磋

            } else {
                ; === 榧犳爣鍦ㄦ偓娴獥涓婏紝浣嗕笉鍦ㄦ寜閽笂锛堟瘮濡傜┖闅欙級 ===
                ToolTip() ; 娓呴櫎鎻愮ず
            }
            
            ; 鏇存柊鐘舵€?
            LastHovered := currentHover
            FloatingToolbarHoveredButton := currentHover
        }
        
    } catch as err {
        ; 瀹归敊澶勭悊锛屾樉绀洪敊璇俊鎭究浜庤皟璇?
        ; ToolTip("Error: " . err.Message)
    }
}

; [鏂板杈呭姪鍑芥暟] 涓撻棬鐢ㄦ潵鎭㈠鎸夐挳棰滆壊鍜屽姩鏁堬紝璁╀富閫昏緫鏇存竻鏅帮紙閫忔槑鑳屾櫙锛屾棤鎸夐挳锛?
FloatingToolbarRestoreButtonColor(btnHwnd) {
    global FloatingToolbarButtons, FloatingToolbarColors
    if (FloatingToolbarButtons.Has(btnHwnd)) {
        try {
            ; 鎭㈠鍥炬爣澶у皬鍜屼綅缃紙鎮仠鍔ㄦ晥杩樺師锛?
            if (FloatingToolbarButtons[btnHwnd].HasProp("iconPic") && FloatingToolbarButtons[btnHwnd].HasProp("isHovered")) {
                if (FloatingToolbarButtons[btnHwnd].isHovered) {
                    iconPic := FloatingToolbarButtons[btnHwnd].iconPic
                    if (Type(iconPic) != "Text") {
                        ; 鎭㈠鍘熷澶у皬鍜屼綅缃?
                        iconPic.Move(
                            FloatingToolbarButtons[btnHwnd].iconX,
                            FloatingToolbarButtons[btnHwnd].iconY,
                            FloatingToolbarButtons[btnHwnd].iconSize,
                            FloatingToolbarButtons[btnHwnd].iconSize
                        )
                        FloatingToolbarButtons[btnHwnd].isHovered := false
                        
                        ; 鎭㈠鍘熷浜害锛堢Щ闄ら鑹叉护闀滐級
                        FloatingToolbarRemoveHoverBrightness(iconPic, FloatingToolbarButtons[btnHwnd])
                    } else {
                        ; 鏂囧瓧鍚庡锛氭仮澶嶆枃瀛楅鑹?
                        iconPic.Opt("c" . FloatingToolbarColors.Text)
                    }
                }
            } else if (FloatingToolbarButtons[btnHwnd].HasProp("iconPic")) {
                ; 濡傛灉娌℃湁isHovered灞炴€э紝妫€鏌ユ槸鍚︽槸鏂囧瓧鍚庡
                iconPic := FloatingToolbarButtons[btnHwnd].iconPic
                if (Type(iconPic) = "Text") {
                    iconPic.Opt("c" . FloatingToolbarColors.Text)
                }
            }
        }
    }
}

; ===================== 鎸夐挳鍔ㄦ晥鍑芥暟 =====================
; 搴旂敤鎸変笅涓嬫矇鏁堟灉
FloatingToolbarApplyPressEffect(btnHwnd) {
    global FloatingToolbarButtons
    if (FloatingToolbarButtons.Has(btnHwnd)) {
        try {
            btnInfo := FloatingToolbarButtons[btnHwnd]
            if (btnInfo.HasProp("iconPic")) {
                iconPic := btnInfo.iconPic
                if (Type(iconPic) != "Text") {
                    ; 涓嬫矇鏁堟灉锛氬潗鏍囦笅绉?px
                    ; 鑾峰彇褰撳墠鍧愭爣锛堣€冭檻鎮仠鐘舵€侊級
                    currentX := btnInfo.iconX
                    currentY := btnInfo.iconY
                    currentSize := btnInfo.iconSize
                    
                    if (btnInfo.isHovered) {
                        ; 濡傛灉姝ｅ湪鎮仠锛屼娇鐢ㄦ偓鍋滃悗鐨勫潗鏍囧拰澶у皬
                        currentX := currentX - 2
                        currentY := currentY - 2
                        currentSize := currentSize + 4
                    }
                    
                    ; 搴旂敤涓嬫矇锛氬潗鏍囦笅绉?px
                    iconPic.Move(currentX + 2, currentY + 2, currentSize, currentSize)
                    
                    ; 搴旂敤鐐瑰嚮鐫€鑹叉晥鏋滐紙姗欒壊璋冿級
                    FloatingToolbarApplyClickColor(iconPic, btnInfo)
                }
            }
        } catch {
        }
    }
}

; 绉婚櫎鎸変笅涓嬫矇鏁堟灉
FloatingToolbarRemovePressEffect(btnHwnd) {
    global FloatingToolbarButtons
    if (FloatingToolbarButtons.Has(btnHwnd)) {
        try {
            btnInfo := FloatingToolbarButtons[btnHwnd]
            if (btnInfo.HasProp("iconPic")) {
                iconPic := btnInfo.iconPic
                if (Type(iconPic) != "Text") {
                    ; 鎭㈠鍧愭爣锛堣€冭檻鎮仠鐘舵€侊級
                    currentX := btnInfo.iconX
                    currentY := btnInfo.iconY
                    currentSize := btnInfo.iconSize
                    
                    if (btnInfo.isHovered) {
                        ; 濡傛灉姝ｅ湪鎮仠锛屼娇鐢ㄦ偓鍋滃悗鐨勫潗鏍囧拰澶у皬
                        currentX := currentX - 2
                        currentY := currentY - 2
                        currentSize := currentSize + 4
                    }
                    
                    ; 鎭㈠鍘熷浣嶇疆
                    iconPic.Move(currentX, currentY, currentSize, currentSize)
                    
                    ; 鎭㈠棰滆壊锛堝鏋滄鍦ㄦ偓鍋滐紝鎭㈠鎮仠浜害锛涘惁鍒欐仮澶嶅師濮嬶級
                    if (btnInfo.isHovered) {
                        FloatingToolbarApplyHoverBrightness(iconPic, btnInfo)
                    } else {
                        FloatingToolbarRemoveHoverBrightness(iconPic, btnInfo)
                    }
                }
            }
        } catch {
        }
    }
}

; ===================== Gdip 鍒濆鍖栧拰娓呯悊 =====================
FloatingToolbarInitializeGdip() {
    global FloatingToolbarGdipToken, FloatingToolbarGdipInitialized

    if (!FloatingToolbarGdipInitialized) {
        FloatingToolbarGdipToken := Gdip_Startup()
        FloatingToolbarGdipInitialized := true
    }
}

FloatingToolbarShutdownGdip() {
    global FloatingToolbarGdipToken, FloatingToolbarGdipInitialized, FloatingToolbarButtons

    if (FloatingToolbarGdipInitialized) {
        ; 娓呯悊鎵€鏈夋寜閽殑Gdip璧勬簮
        for btnHwnd, btnInfo in FloatingToolbarButtons {
            FloatingToolbarCleanupButtonGdip(btnInfo)
        }
        Gdip_Shutdown(FloatingToolbarGdipToken)
        FloatingToolbarGdipToken := 0
        FloatingToolbarGdipInitialized := false
    }
}

FloatingToolbarCleanupButtonGdip(btnInfo) {
    try {
        ; 娓呯悊鎮仠鐘舵€佸浘鐗?
        if (btnInfo.HasProp("hoverBitmap") && btnInfo.hoverBitmap != 0) {
            Gdip_DisposeImage(btnInfo.hoverBitmap)
            btnInfo.hoverBitmap := 0
        }
        ; 娓呯悊鎸変笅鐘舵€佸浘鐗?
        if (btnInfo.HasProp("pressBitmap") && btnInfo.pressBitmap != 0) {
            Gdip_DisposeImage(btnInfo.pressBitmap)
            btnInfo.pressBitmap := 0
        }
        ; 娓呯悊涓存椂鏂囦欢
        if (btnInfo.HasProp("hoverFile") && btnInfo.hoverFile != "" && FileExist(btnInfo.hoverFile)) {
            FileDelete(btnInfo.hoverFile)
            btnInfo.hoverFile := ""
        }
        if (btnInfo.HasProp("pressFile") && btnInfo.pressFile != "" && FileExist(btnInfo.pressFile)) {
            FileDelete(btnInfo.pressFile)
            btnInfo.pressFile := ""
        }
    } catch {
    }
}

; ===================== 鎮仠鍜岀偣鍑荤壒鏁?=====================

; 搴旂敤鎮仠浜害澧炲己鏁堟灉
FloatingToolbarApplyHoverBrightness(iconPic, btnInfo) {
    global FloatingToolbarGdipInitialized

    if (!FloatingToolbarGdipInitialized || Type(iconPic) = "Text") {
        return
    }

    try {
        ; 濡傛灉杩樻病鏈夌敓鎴愭偓鍋滃浘鐗囷紝鐢熸垚骞剁紦瀛?
        if (!btnInfo.HasProp("hoverFile") || btnInfo.hoverFile = "" || !FileExist(btnInfo.hoverFile)) {
            FloatingToolbarCreateHoverImage(btnInfo)
        }

        ; 搴旂敤鎮仠鍥剧墖锛堜娇鐢╓M_SETICON娑堟伅鏇存柊锛?
        if (btnInfo.HasProp("hoverFile") && btnInfo.hoverFile != "" && FileExist(btnInfo.hoverFile)) {
            ; 浣跨敤SendMessage鏇存柊鍥剧墖锛堟洿鍙潬鐨勬柟娉曪級
            iconPic.Opt("+BackgroundTrans")
            SendMessage(0x0172, 0, 0, iconPic.Hwnd)  ; STM_SETIMAGE = 0x0172
            iconPic.Value := btnInfo.hoverFile
        }
    } catch as err {
        ; 璋冭瘯锛氭樉绀洪敊璇俊鎭?
        ; ToolTip("Hover Error: " . err.Message)
    }
}

; 绉婚櫎鎮仠浜害鏁堟灉
FloatingToolbarRemoveHoverBrightness(iconPic, btnInfo) {
    if (Type(iconPic) = "Text") {
        return
    }

    try {
        ; 鎭㈠鍘熷鍥剧墖
        if (btnInfo.HasProp("iconPath") && btnInfo.iconPath != "" && FileExist(btnInfo.iconPath)) {
            iconPic.Value := btnInfo.iconPath
        }
    } catch as err {
        ; ToolTip("Restore Error: " . err.Message)
    }
}

; 搴旂敤鐐瑰嚮鐫€鑹叉晥鏋?
FloatingToolbarApplyClickColor(iconPic, btnInfo) {
    global FloatingToolbarGdipInitialized

    if (!FloatingToolbarGdipInitialized || Type(iconPic) = "Text") {
        return
    }

    try {
        ; 濡傛灉杩樻病鏈夌敓鎴愭寜涓嬪浘鐗囷紝鐢熸垚骞剁紦瀛?
        if (!btnInfo.HasProp("pressFile") || btnInfo.pressFile = "" || !FileExist(btnInfo.pressFile)) {
            FloatingToolbarCreatePressImage(btnInfo)
        }

        ; 搴旂敤鎸変笅鍥剧墖
        if (btnInfo.HasProp("pressFile") && btnInfo.pressFile != "" && FileExist(btnInfo.pressFile)) {
            iconPic.Opt("+BackgroundTrans")
            iconPic.Value := btnInfo.pressFile
        }
    } catch as err {
        ; ToolTip("Press Error: " . err.Message)
    }
}

; 鍒涘缓鎮仠鐘舵€佸浘鐗囷紙浜害澧炲己 - 浣跨敤鍙犲姞鐧借壊鍗婇€忔槑灞傚疄鐜帮級
FloatingToolbarCreateHoverImage(btnInfo) {
    global FloatingToolbarGdipToken

    try {
        if (!FileExist(btnInfo.iconPath)) {
            return
        }

        ; 鍔犺浇鍘熷鍥剧墖
        pBitmap := Gdip_CreateBitmapFromFile(btnInfo.iconPath)
        if (!pBitmap) {
            return
        }

        ; 鑾峰彇鍥剧墖灏哄
        width := Gdip_GetImageWidth(pBitmap)
        height := Gdip_GetImageHeight(pBitmap)

        ; 鍒涘缓鏂扮殑浣嶅浘鐢ㄤ簬澶勭悊
        pProcessedBitmap := Gdip_CloneBitmapArea(pBitmap, 0, 0, width, height)

        ; 鑾峰彇Graphics
        pGraphics := Gdip_GraphicsFromImage(pProcessedBitmap)

        ; 娣诲姞鐧借壊鍗婇€忔槑鍙犲姞灞傦紙妯℃嫙浜害澧炲姞鏁堟灉锛?
        ; 25% 閫忔槑搴︾殑鐧借壊
        pBrush := Gdip_BrushCreateSolid(0x40FFFFFF)
        Gdip_FillRectangle(pGraphics, pBrush, 0, 0, width, height)
        Gdip_DeleteBrush(pBrush)

        ; 娓呯悊璧勬簮
        Gdip_DeleteGraphics(pGraphics)
        Gdip_DisposeImage(pBitmap)

        ; 淇濆瓨鍒颁复鏃舵枃浠?
        tempDir := A_Temp . "\FloatingToolbar"
        if (!DirExist(tempDir)) {
            DirCreate(tempDir)
        }
        hoverFile := tempDir . "\hover_" . btnInfo.action . "_" . A_TickCount . ".png"
        Gdip_SaveBitmapToFile(pProcessedBitmap, hoverFile, 100)
        Gdip_DisposeImage(pProcessedBitmap)

        ; 瀛樺偍鍒版寜閽俊鎭?
        btnInfo.hoverFile := hoverFile
    } catch {
    }
}

; 鍒涘缓鎸変笅鐘舵€佸浘鐗囷紙鍙樻殫 + 姗欒壊鍙犲姞锛?
FloatingToolbarCreatePressImage(btnInfo) {
    global FloatingToolbarGdipToken

    try {
        if (!FileExist(btnInfo.iconPath)) {
            return
        }

        ; 鍔犺浇鍘熷鍥剧墖
        pBitmap := Gdip_CreateBitmapFromFile(btnInfo.iconPath)
        if (!pBitmap) {
            return
        }

        ; 鑾峰彇鍥剧墖灏哄
        width := Gdip_GetImageWidth(pBitmap)
        height := Gdip_GetImageHeight(pBitmap)

        ; 鍒涘缓鏂扮殑浣嶅浘鐢ㄤ簬澶勭悊
        pProcessedBitmap := Gdip_CloneBitmapArea(pBitmap, 0, 0, width, height)

        ; 鑾峰彇Graphics
        pGraphics := Gdip_GraphicsFromImage(pProcessedBitmap)

        ; 鍏堢粯鍒跺師濮嬪浘鐗?
        Gdip_DrawImage(pGraphics, pBitmap, 0, 0, width, height)

        ; 娣诲姞榛戣壊鍗婇€忔槑鍙犲姞灞傦紙鍙樻殫鏁堟灉 - 40%閫忔槑搴︾殑榛戣壊锛?
        pBrushDark := Gdip_BrushCreateSolid(0x66000000)
        Gdip_FillRectangle(pGraphics, pBrushDark, 0, 0, width, height)
        Gdip_DeleteBrush(pBrushDark)

        ; 娣诲姞姗欒壊鍗婇€忔槑鍙犲姞锛堝寮虹偣鍑诲弽棣?- 25%閫忔槑搴︾殑姗欒壊锛?
        pBrushOrange := Gdip_BrushCreateSolid(0x40FF6600)
        Gdip_FillRectangle(pGraphics, pBrushOrange, 0, 0, width, height)
        Gdip_DeleteBrush(pBrushOrange)

        ; 娓呯悊璧勬簮
        Gdip_DeleteGraphics(pGraphics)
        Gdip_DisposeImage(pBitmap)

        ; 淇濆瓨鍒颁复鏃舵枃浠?
        tempDir := A_Temp . "\FloatingToolbar"
        if (!DirExist(tempDir)) {
            DirCreate(tempDir)
        }
        pressFile := tempDir . "\press_" . btnInfo.action . "_" . A_TickCount . ".png"
        Gdip_SaveBitmapToFile(pProcessedBitmap, pressFile, 100)
        Gdip_DisposeImage(pProcessedBitmap)

        ; 瀛樺偍鍒版寜閽俊鎭?
        btnInfo.pressFile := pressFile
    } catch {
    }
}

; ===================== 鑳屾櫙鍖哄煙鎷栧姩澶勭悊 =====================
OnToolbarBgClick(*) {
    global FloatingToolbarGUI, FloatingToolbarDragging, FloatingToolbarDragStartX, FloatingToolbarDragStartY, FloatingToolbarWindowX, FloatingToolbarWindowY
    
    ; 妫€鏌ユ槸鍚﹀湪鎸夐挳鍖哄煙锛堟寜閽尯鍩熶笉鎷栧姩锛?
    MouseGetPos(&mx, &my)
    FloatingToolbarGUI.GetPos(&winX, &winY)
    
    ; 璁＄畻鐩稿浜庣獥鍙ｇ殑鍧愭爣
    wx := mx - winX
    wy := my - winY
    
    ; 妫€鏌ユ槸鍚﹀湪鎸夐挳鍖哄煙鍐咃紙鏇存柊鍧愭爣浠ラ€傚簲鏂板昂瀵革級
    ; 鎸夐挳鍖哄煙锛歋tartX 鍒?StartX + (ButtonWidth * 6) + (ButtonSpacing * 5)
    buttonAreaStartX := 40
    buttonAreaEndX := 40 + (40 * 6) + (5 * 5)
    buttonAreaStartY := 5
    buttonAreaEndY := 5 + 35
    if (wx >= buttonAreaStartX && wx <= buttonAreaEndX && wy >= buttonAreaStartY && wy <= buttonAreaEndY) {
        ; 鍦ㄦ寜閽尯鍩熷唴锛屼笉鎷栧姩锛堟寜閽湁鑷繁鐨勬嫋鍔ㄥ鐞嗭級
        return
    }
    
    ; 妫€鏌ユ槸鍚﹀湪鍥炬爣鍖哄煙鍐咃紙鍥炬爣鍖哄煙锛歺5-33, y5-33锛?
    if (wx >= 5 && wx <= 33 && wy >= 5 && wy <= 33) {
        ; 鍦ㄥ浘鏍囧尯鍩熷唴锛屼笉鎷栧姩
        return
    }
    
    ; 寮€濮嬫嫋鍔?
    FloatingToolbarDragging := true
    FloatingToolbarDragStartX := mx
    FloatingToolbarDragStartY := my
    FloatingToolbarWindowX := winX
    FloatingToolbarWindowY := winY
    
    ; 浣跨敤鏍囧噯鐨刉indows鎷栧姩鏂规硶
    PostMessage(0x00A1, 2, 0, FloatingToolbarGUI.Hwnd)  ; WM_NCLBUTTONDOWN, HTCAPTION
    
    ; 鍚姩瀹氭椂鍣ㄦ潵妫€娴嬫嫋鍔ㄧ粨鏉?
    SetTimer(FloatingToolbarCheckDragEnd, 50)
}

; 妫€娴嬫嫋鍔ㄧ粨鏉?
FloatingToolbarCheckDragEnd() {
    global FloatingToolbarDragging, FloatingToolbarWindowX, FloatingToolbarWindowY
    
    ; 濡傛灉榧犳爣宸﹂敭閲婃斁锛屽仠姝㈡嫋鍔ㄥ苟瑙﹀彂纾佸惛妫€鏌?
    if (!GetKeyState("LButton", "P")) {
        FloatingToolbarDragging := false
        SetTimer(FloatingToolbarCheckDragEnd, 0)
        
        ; 绔嬪嵆瑙﹀彂浣嶇疆妫€鏌ュ拰纾佸惛鏁堟灉
        FloatingToolbarCheckWindowPosition()
    }
}

; 鎷栧姩缁撴潫鍚庣殑杈圭晫妫€鏌ュ拰浣嶇疆鏇存柊锛堜娇鐢ㄥ畾鏃跺櫒锛?
FloatingToolbarCheckWindowPosition() {
    global FloatingToolbarGUI, FloatingToolbarWindowX, FloatingToolbarWindowY, FloatingToolbarDragging, FloatingToolbarIsVisible
    
    ; 濡傛灉绐楀彛涓嶅彲瑙侊紝涓嶅鐞?
    if (!FloatingToolbarIsVisible || FloatingToolbarGUI = 0) {
        return
    }
    
    ; 濡傛灉姝ｅ湪鎷栧姩锛屼笉澶勭悊
    if (FloatingToolbarDragging) {
        return
    }
    
    ; 濡傛灉榧犳爣宸﹂敭閲婃斁锛屾鏌ヨ竟鐣屽苟璋冩暣浣嶇疆
    if (!GetKeyState("LButton", "P")) {
        try {
            FloatingToolbarGUI.GetPos(&newX, &newY)
            FloatingToolbarWindowX := newX
            FloatingToolbarWindowY := newY
            
            ; 鑾峰彇灞忓箷灏哄
            ScreenWidth := SysGet(0)
            ScreenHeight := SysGet(1)
            adjustedX := newX
            adjustedY := newY
            
            ; 纾佸惛璺濈闃堝€硷紙30鍍忕礌锛?
            snapDistance := 30
            windowWidth := FloatingToolbarCalculateWidth()
            windowHeight := FloatingToolbarCalculateHeight()
            
            ; 纾佸惛鍒板乏杈圭紭
            if (adjustedX < snapDistance) {
                adjustedX := 0
            }
            ; 纾佸惛鍒板彸杈圭紭
            else if (adjustedX + windowWidth > ScreenWidth - snapDistance) {
                adjustedX := ScreenWidth - windowWidth
            }
            
            ; 纾佸惛鍒颁笂杈圭紭
            if (adjustedY < snapDistance) {
                adjustedY := 0
            }
            ; 纾佸惛鍒颁笅杈圭紭
            else if (adjustedY + windowHeight > ScreenHeight - snapDistance) {
                adjustedY := ScreenHeight - windowHeight
            }
            
            ; 杈圭晫妫€鏌ワ紙闃叉瓒呭嚭灞忓箷锛?
            if (adjustedX < 0) {
                adjustedX := 0
            }
            if (adjustedY < 0) {
                adjustedY := 0
            }
            if (adjustedX + windowWidth > ScreenWidth) {
                adjustedX := ScreenWidth - windowWidth
            }
            if (adjustedY + windowHeight > ScreenHeight) {
                adjustedY := ScreenHeight - windowHeight
            }
            
            ; 濡傛灉浣嶇疆闇€瑕佽皟鏁达紝鏇存柊绐楀彛浣嶇疆
            if (adjustedX != newX || adjustedY != newY) {
                FloatingToolbarGUI.Move(adjustedX, adjustedY)
                FloatingToolbarWindowX := adjustedX
                FloatingToolbarWindowY := adjustedY
            }
            
            ; [闇€姹?] 浣嶇疆鍙樺寲鏃朵繚瀛樺埌閰嶇疆鏂囦欢
            SaveFloatingToolbarPosition()
        } catch {
        }
    }
}

; 悬浮工具栏右键统一弹出（空白区与图标、favicon 共用）
FloatingToolbarShowUnifiedPopupAtCursor(*) {
    CoordMode("Mouse", "Screen")
    MouseGetPos(&mx, &my)
    ShowFloatingToolbarUnifiedContextMenu(mx, my)
}

OnFloatingToolbarContextMenu(*) {
    FloatingToolbarShowUnifiedPopupAtCursor()
}

FloatingToolbarIconContextMenu(*) {
    FloatingToolbarShowUnifiedPopupAtCursor()
}

; ===================== 绐楀彛鍏抽棴浜嬩欢 =====================
OnFloatingToolbarClose(*) {
    HideFloatingToolbar()
}

; ===================== 浣嶇疆淇濆瓨鍜屽姞杞?=====================
; [闇€姹?] 淇濆瓨鎮诞宸ュ叿鏍忎綅缃埌閰嶇疆鏂囦欢
SaveFloatingToolbarPosition() {
    global FloatingToolbarGUI, FloatingToolbarWindowX, FloatingToolbarWindowY
    
    if (FloatingToolbarGUI = 0) {
        return
    }
    
    try {
        ; 鑾峰彇褰撳墠绐楀彛浣嶇疆
        FloatingToolbarGUI.GetPos(&x, &y)
        FloatingToolbarWindowX := x
        FloatingToolbarWindowY := y
        
        ; 淇濆瓨鍒伴厤缃枃浠讹紙浣跨敤涓昏剼鏈殑閰嶇疆鏂囦欢璺緞锛?
        ConfigFile := A_ScriptDir . "\CursorShortcut.ini"
        IniWrite(String(x), ConfigFile, "WindowPositions", "FloatingToolbar_X")
        IniWrite(String(y), ConfigFile, "WindowPositions", "FloatingToolbar_Y")
    } catch {
        ; 淇濆瓨澶辫触鏃堕潤榛樺鐞?
    }
}

; ===================== 璁＄畻宸ュ叿鏍忓搴﹀拰楂樺害 =====================
FloatingToolbarCalculateWidth() {
    global FloatingToolbarScale
    BaseOuterPadding := 6
    BaseFavIconSize := 28
    BaseIconGap := 6
    BaseStartX := BaseOuterPadding + BaseFavIconSize + BaseIconGap
    BaseButtonWidth := 40
    BaseButtonSpacing := 5
    pad := Round(BaseOuterPadding * FloatingToolbarScale)
    StartX := Round(BaseStartX * FloatingToolbarScale)
    ButtonWidth := Round(BaseButtonWidth * FloatingToolbarScale)
    ButtonSpacing := Round(BaseButtonSpacing * FloatingToolbarScale)
    ; 最后一枚按钮右边缘 + 与左侧对称的外边距（不再使用超大 BaseRightPadding / 屏幕比例最小宽度）
    LastRight := StartX + 6 * ButtonWidth + 5 * ButtonSpacing
    return LastRight + pad
}
FloatingToolbarCalculateHeight() {
    global FloatingToolbarScale
    BaseOuterPadding := 6
    BaseButtonHeight := 40
    padY := Round(BaseOuterPadding * FloatingToolbarScale)
    ButtonHeight := Round(BaseButtonHeight * FloatingToolbarScale)
    return padY * 2 + ButtonHeight
}

; ===================== 榧犳爣婊氳疆缂╂斁澶勭悊 =====================
FloatingToolbarWM_MOUSEWHEEL(wParam, lParam, msg, hwnd) {
    global FloatingToolbarGUI, FloatingToolbarIsVisible, FloatingToolbarScale, FloatingToolbarMinScale, FloatingToolbarMaxScale, FloatingToolbarWindowX, FloatingToolbarWindowY

    if (!FloatingToolbarIsVisible || !FloatingToolbarGUI) {
        return
    }

    ; 只要鼠标位于工具栏矩形内，就允许滚轮调整大小
    MouseGetPos(&mx, &my)
    FloatingToolbarGUI.GetPos(&wx, &wy, &ww, &wh)
    if (mx < wx || mx > wx + ww || my < wy || my > wy + wh) {
        return
    }
    
    ; 鑾峰彇婊氳疆鏂瑰悜锛坵Param鐨勯珮16浣嶅寘鍚粴杞閲忥級
    ; 姝ｆ暟 = 鍚戜笂婊氬姩锛堟斁澶э級锛岃礋鏁?= 鍚戜笅婊氬姩锛堢缉灏忥級
    wheelDelta := (wParam >> 16) & 0xFFFF
    if (wheelDelta > 0x7FFF) {
        wheelDelta := wheelDelta - 0x10000
    }
    
    ; 璁＄畻鏂扮殑缂╂斁姣斾緥锛堟瘡娆℃粴鍔ㄨ皟鏁?5%锛屾彁楂樼缉鏀炬晥鐜囷級
    scaleStep := 0.15
    newScale := FloatingToolbarScale
    
    if (wheelDelta > 0) {
        ; 鍚戜笂婊氬姩锛屾斁澶?
        newScale := FloatingToolbarScale + scaleStep
        if (newScale > FloatingToolbarMaxScale) {
            newScale := FloatingToolbarMaxScale
        }
    } else {
        ; 鍚戜笅婊氬姩锛岀缉灏?
        newScale := FloatingToolbarScale - scaleStep
        if (newScale < FloatingToolbarMinScale) {
            newScale := FloatingToolbarMinScale
        }
    }
    
    ; 濡傛灉缂╂斁姣斾緥鍙戠敓鍙樺寲锛岄噸鏂板垱寤哄伐鍏锋爮
    if (newScale != FloatingToolbarScale) {
        ; 鑾峰彇褰撳墠绐楀彛浣嶇疆鍜屽昂瀵?
        FloatingToolbarGUI.GetPos(&oldX, &oldY, &oldWidth, &oldHeight)
        
        ; 鑾峰彇榧犳爣鍦ㄧ獥鍙ｅ唴鐨勭浉瀵逛綅缃紙鐩稿浜庣獥鍙ｅ乏涓婅锛?
        MouseGetPos(&mouseScreenX, &mouseScreenY)
        mouseRelX := mouseScreenX - oldX
        mouseRelY := mouseScreenY - oldY
        
        ; 璁＄畻榧犳爣浣嶇疆鍦ㄧ獥鍙ｄ腑鐨勬瘮渚嬶紙0.0 鍒?1.0锛?
        mouseRatioX := oldWidth > 0 ? mouseRelX / oldWidth : 0.5
        mouseRatioY := oldHeight > 0 ? mouseRelY / oldHeight : 0.5
        
        ; 鏇存柊缂╂斁姣斾緥
        FloatingToolbarScale := newScale
        
        ; 閲嶆柊鍒涘缓GUI锛堝簲鐢ㄦ柊鐨勭缉鏀炬瘮渚嬶級
        CreateFloatingToolbarGUI()
        
        ; 閲嶆柊璁＄畻绐楀彛灏哄
        ToolbarWidth := FloatingToolbarCalculateWidth()
        ToolbarHeight := FloatingToolbarCalculateHeight()
        
        ; 璁＄畻鏂扮獥鍙ｄ綅缃紝浣垮緱榧犳爣浣嶇疆瀵瑰簲鐨勭偣鍦ㄧ缉鏀惧墠鍚庝繚鎸佷笉鍙?
        ; 鏂扮獥鍙ｇ殑宸︿笂瑙掍綅缃?= 榧犳爣灞忓箷浣嶇疆 - 榧犳爣鍦ㄦ柊绐楀彛涓殑鐩稿浣嶇疆
        newX := mouseScreenX - Round(mouseRatioX * ToolbarWidth)
        newY := mouseScreenY - Round(mouseRatioY * ToolbarHeight)
        
        ; 杈圭晫妫€鏌ワ紙闃叉绐楀彛瓒呭嚭灞忓箷锛?
        ScreenWidth := SysGet(0)
        ScreenHeight := SysGet(1)
        if (newX < 0) {
            newX := 0
        }
        if (newY < 0) {
            newY := 0
        }
        if (newX + ToolbarWidth > ScreenWidth) {
            newX := ScreenWidth - ToolbarWidth
        }
        if (newY + ToolbarHeight > ScreenHeight) {
            newY := ScreenHeight - ToolbarHeight
        }
        
        ; 鏇存柊绐楀彛浣嶇疆
        FloatingToolbarWindowX := newX
        FloatingToolbarWindowY := newY
        
        ; 鏄剧ず绐楀彛锛堜娇鐢ㄦ柊浣嶇疆鍜屾柊灏哄锛?
        FloatingToolbarGUI.Show("x" . newX . " y" . newY . " w" . ToolbarWidth . " h" . ToolbarHeight)
        
        ; 閲嶆柊搴旂敤鍦嗚杈规锛堢獥鍙ｅ昂瀵告敼鍙樺悗锛?
        FloatingToolbarApplyRoundedCorners()
        
        ; 淇濆瓨缂╂斁姣斾緥鍜屼綅缃埌閰嶇疆鏂囦欢
        FloatingToolbarSaveScale()
        SaveFloatingToolbarPosition()
    }
    
    return 0  ; 琛ㄧず宸插鐞嗘秷鎭?
}

; ===================== 淇濆瓨鍜屽姞杞界缉鏀炬瘮渚?=====================
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
            ; 纭繚缂╂斁姣斾緥鍦ㄦ湁鏁堣寖鍥村唴
            if (scaleValue >= FloatingToolbarMinScale && scaleValue <= FloatingToolbarMaxScale) {
                FloatingToolbarScale := scaleValue
            }
        }
    } catch {
    }
}

; [闇€姹?] 浠庨厤缃枃浠跺姞杞芥偓娴伐鍏锋爮浣嶇疆
LoadFloatingToolbarPosition() {
    global FloatingToolbarWindowX, FloatingToolbarWindowY
    
    try {
        ConfigFile := A_ScriptDir . "\CursorShortcut.ini"
        
        ; 璇诲彇淇濆瓨鐨勪綅缃?
        savedX := IniRead(ConfigFile, "WindowPositions", "FloatingToolbar_X", "")
        savedY := IniRead(ConfigFile, "WindowPositions", "FloatingToolbar_Y", "")
        
        ; 濡傛灉璇诲彇鎴愬姛涓斿€兼湁鏁堬紝浣跨敤淇濆瓨鐨勪綅缃?
        if (savedX != "" && savedY != "" && savedX != "ERROR" && savedY != "ERROR") {
            FloatingToolbarWindowX := Integer(savedX)
            FloatingToolbarWindowY := Integer(savedY)
            
            ; 楠岃瘉浣嶇疆鏄惁鍦ㄥ睆骞曡寖鍥村唴
            ScreenWidth := SysGet(0)
            ScreenHeight := SysGet(1)
            
            ; 璁＄畻绐楀彛瀹藉害鍜岄珮搴?
            ToolbarWidth := FloatingToolbarCalculateWidth()
            ToolbarHeight := FloatingToolbarCalculateHeight()
            if (FloatingToolbarWindowX < 0 || FloatingToolbarWindowX > ScreenWidth - ToolbarWidth) {
                FloatingToolbarWindowX := 0
            }
            if (FloatingToolbarWindowY < 0 || FloatingToolbarWindowY > ScreenHeight - ToolbarHeight) {
                FloatingToolbarWindowY := 0
            }
        }
    } catch {
        ; 鍔犺浇澶辫触鏃朵娇鐢ㄩ粯璁や綅缃?
        FloatingToolbarWindowX := 0
        FloatingToolbarWindowY := 0
    }
}

; ===================== 鍒濆鍖?=====================
; ===================== 闅愯棌鍒板睆骞曡竟缂?=====================
MinimizeFloatingToolbarToEdge() {
    global FloatingToolbarGUI, FloatingToolbarIsVisible, FloatingToolbarIsMinimized
    global FloatingToolbarWindowX, FloatingToolbarWindowY
    
    if (!FloatingToolbarIsVisible || FloatingToolbarGUI = 0) {
        return
    }
    
    ; 鑾峰彇褰撳墠绐楀彛浣嶇疆
    FloatingToolbarGUI.GetPos(&currentX, &currentY, &currentW, &currentH)
    
    ; 鑾峰彇灞忓箷灏哄
    ScreenWidth := SysGet(0)
    ScreenHeight := SysGet(1)
    
    ; 璁＄畻鍒板悇杈圭紭鐨勮窛绂伙紝閫夋嫨鏈€杩戠殑杈圭紭
    distLeft := currentX
    distRight := ScreenWidth - (currentX + currentW)
    distTop := currentY
    distBottom := ScreenHeight - (currentY + currentH)
    
    ; 鎵惧埌鏈€灏忚窛绂?
    minDist := distLeft
    targetX := 0
    targetY := currentY
    
    if (distRight < minDist) {
        minDist := distRight
        targetX := ScreenWidth - currentW
        targetY := currentY
    }
    if (distTop < minDist) {
        minDist := distTop
        targetX := currentX
        targetY := 0
    }
    if (distBottom < minDist) {
        minDist := distBottom
        targetX := currentX
        targetY := ScreenHeight - currentH
    }
    
    ; 绉诲姩鍒版渶杩戠殑杈圭紭
    FloatingToolbarGUI.Move(targetX, targetY)
    FloatingToolbarWindowX := targetX
    FloatingToolbarWindowY := targetY
    FloatingToolbarIsMinimized := true
    
    ; 淇濆瓨浣嶇疆
    SaveFloatingToolbarPosition()
}

; ===================== 鎭㈠鎮诞宸ュ叿鏍?=====================
RestoreFloatingToolbar() {
    global FloatingToolbarIsMinimized
    FloatingToolbarIsMinimized := false
    ; 浣嶇疆宸蹭繚瀛橈紝鏄剧ず鏃朵細鑷姩鍔犺浇
}

InitFloatingToolbar() {
    ; 鍒濆鍖栧畬鎴愶紝鍙互璋冪敤 ShowFloatingToolbar() 鏄剧ず鎮诞绐?
}

; ===================== 鏍规嵁鎸夐挳action鑾峰彇鎻愮ず鏂囧瓧 =====================
GetButtonTip(action) {
    ; 鏍规嵁鎸夐挳鐨刟ction绫诲瀷杩斿洖瀵瑰簲鐨勬彁绀烘枃瀛?
    switch action {
        case "Search":
            return "鎼滅储璁板綍 (Caps + F)"
        case "Record":
            return "鍓创鏉垮巻鍙?(Caps + X)"
        case "AIAssistant":
            return "AI鍔╂墜 (Ctrl+Shift+B)"
        case "Screenshot":
            return "灞忓箷鎴浘 (Caps + T)"
        case "Settings":
            return "绯荤粺璁剧疆 (Caps + Q)"
        case "VirtualKeyboard":
            return "虚拟键盘 (Ctrl+Shift+K)"
        default:
            return ""
    }
}
