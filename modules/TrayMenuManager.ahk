; TrayMenuManager.ahk — 托盘高分辨率图标、自定义暗色菜单、监听 0x0404（与历史脚本中的 0x404 同值）
; 依赖：主脚本已 #Include lib\Gdip_All.ahk；其余符号（GetText、CleanUp、ExecuteScreenshotWithMenu、ShowSearchCenter、
; FloatingToolbar_*、CP_Show、ShowConfigGUI 等）在运行时至托盘点击时已解析。

global CustomIconPath := ""

; 初始化托盘：清空系统托盘菜单、注册 0x0404、设置图标与提示
TrayMenu_Init() {
    A_TrayMenu.Delete()
    OnMessage(0x0404, TRAY_ICON_MESSAGE)
    TrySetTrayIconHighQuality()
    UpdateTrayMenu()
}

Gdip_CreateTrayHIconFromPngFile(pngPath, size := 256) {
    pBitmap := Gdip_CreateBitmapFromFile(pngPath)
    if !pBitmap
        return 0
    sw := Gdip_GetImageWidth(pBitmap), sh := Gdip_GetImageHeight(pBitmap)
    if (sw < 1 || sh < 1) {
        Gdip_DisposeImage(pBitmap)
        return 0
    }
    pNew := Gdip_CreateBitmap(size, size)
    G := Gdip_GraphicsFromImage(pNew)
    Gdip_SetInterpolationMode(G, 7)
    Gdip_DrawImage(G, pBitmap, 0, 0, size, size, 0, 0, sw, sh)
    Gdip_DeleteGraphics(G)
    Gdip_DisposeImage(pBitmap)
    hIcon := Gdip_CreateHICONFromBitmap(pNew)
    Gdip_DisposeImage(pNew)
    return hIcon
}

TrySetTrayIconHighQuality() {
    global CustomIconPath
    if (IsSet(CustomIconPath) && CustomIconPath != "" && FileExist(CustomIconPath)) {
        if RegExMatch(CustomIconPath, "i)\.png$") {
            try {
                h := Gdip_CreateTrayHIconFromPngFile(CustomIconPath)
                if h {
                    TraySetIcon(h)
                    DllCall("DestroyIcon", "ptr", h)
                    return
                }
            }
        } else {
            try {
                TraySetIcon(CustomIconPath)
                return
            }
        }
    }
    icoNiu := A_ScriptDir "\牛马.ico"
    pngNiu := A_ScriptDir "\牛马.png"
    if FileExist(icoNiu) {
        try {
            TraySetIcon(icoNiu)
            return
        }
    }
    if FileExist(pngNiu) {
        try {
            h := Gdip_CreateTrayHIconFromPngFile(pngNiu)
            if h {
                TraySetIcon(h)
                DllCall("DestroyIcon", "ptr", h)
                return
            }
        }
    }
    chIco := A_ScriptDir "\cursor_helper.ico"
    if FileExist(chIco) {
        try {
            TraySetIcon(chIco)
            return
        }
    }
    if FileExist(A_ScriptDir "\favicon.ico")
        try TraySetIcon(A_ScriptDir "\favicon.ico")
}

ResolveDefaultUiIconPath() {
    global CustomIconPath
    if (IsSet(CustomIconPath) && CustomIconPath != "" && FileExist(CustomIconPath))
        return CustomIconPath
    if FileExist(A_ScriptDir "\牛马.png")
        return A_ScriptDir "\牛马.png"
    return A_ScriptDir "\favicon.ico"
}

UpdateTrayIcon() {
    TrySetTrayIconHighQuality()
}

global TrayMenuGUI := 0
global TrayMenuSelectedItem := 0
global TrayMenuHoverTimer := 0

TRAY_ICON_MESSAGE(wParam, lParam, msg, hwnd) {
    if (lParam = 0x203) {
        CleanUp()
        ExitApp()
        return 0
    }
    if (lParam = 0x205 || lParam = 0x202) {
        ShowCustomTrayMenu()
        return 0
    }
}

UpdateTrayMenu() {
    A_IconTip := GetText("app_tip")
    A_TrayMenu.Delete()
}

TrayMenuCancelHoverAnim() {
    global TrayMenuHoverTimer
    if (TrayMenuHoverTimer) {
        SetTimer(TrayMenuHoverTimer, 0)
        TrayMenuHoverTimer := 0
    }
}

TrayMenuItemHoverPhase2(ItemIndex, *) {
    global TrayMenuGUI, TrayMenuSelectedItem, TrayMenuHoverTimer
    TrayMenuHoverTimer := 0
    if (!TrayMenuGUI || TrayMenuSelectedItem != ItemIndex)
        return
    try {
        TrayMenuGUI["MenuItemBg" . ItemIndex].BackColor := "ff6600"
        TrayMenuGUI["MenuItemText" . ItemIndex].Opt("cFFFFFF")
        if (TrayMenuGUI.HasProp("MenuItemIcon" . ItemIndex))
            TrayMenuGUI["MenuItemIcon" . ItemIndex].Opt("cFFFFFF")
    } catch {
    }
}

TrayMenuItemHover(ItemIndex, *) {
    global TrayMenuGUI, TrayMenuSelectedItem, TrayMenuHoverTimer
    if (TrayMenuSelectedItem = ItemIndex)
        return
    TrayMenuCancelHoverAnim()
    if (TrayMenuSelectedItem > 0) {
        try {
            TrayMenuGUI["MenuItemBg" . TrayMenuSelectedItem].BackColor := "1a1a1a"
            TrayMenuGUI["MenuItemText" . TrayMenuSelectedItem].Opt("cff6600")
            if (TrayMenuGUI.HasProp("MenuItemIcon" . TrayMenuSelectedItem))
                TrayMenuGUI["MenuItemIcon" . TrayMenuSelectedItem].Opt("cff6600")
        } catch {
        }
    }
    TrayMenuSelectedItem := ItemIndex
    try {
        TrayMenuGUI["MenuItemBg" . ItemIndex].BackColor := "2a2622"
        TrayMenuGUI["MenuItemText" . ItemIndex].Opt("cffb366")
        if (TrayMenuGUI.HasProp("MenuItemIcon" . ItemIndex))
            TrayMenuGUI["MenuItemIcon" . ItemIndex].Opt("cffb366")
    } catch {
    }
    fn := TrayMenuItemHoverPhase2.Bind(ItemIndex)
    TrayMenuHoverTimer := fn
    SetTimer(fn, -50)
}

TrayMenuItemLeave(ItemIndex, *) {
    global TrayMenuGUI, TrayMenuSelectedItem
    if (TrayMenuSelectedItem = ItemIndex) {
        try {
            TrayMenuGUI["MenuItemBg" . ItemIndex].BackColor := "1a1a1a"
            TrayMenuGUI["MenuItemText" . ItemIndex].Opt("cff6600")
            if (TrayMenuGUI.HasProp("MenuItemIcon" . ItemIndex)) {
                TrayMenuGUI["MenuItemIcon" . ItemIndex].Opt("cff6600")
            }
            TrayMenuSelectedItem := 0
        }
    }
}

CheckTrayMenuMousePosition(*) {
    global TrayMenuGUI, TrayMenuSelectedItem
    if (!TrayMenuGUI)
        return

    try {
        if (!TrayMenuGUI.HasProp("Hwnd") || !TrayMenuGUI.Hwnd) {
            TrayMenuGUI := 0
            SetTimer(CheckTrayMenuMousePosition, 0)
            return
        }
        if (!WinExist("ahk_id " . TrayMenuGUI.Hwnd)) {
            TrayMenuGUI := 0
            SetTimer(CheckTrayMenuMousePosition, 0)
            return
        }
    } catch {
        TrayMenuGUI := 0
        SetTimer(CheckTrayMenuMousePosition, 0)
        return
    }

    try {
        MouseGetPos(&MX, &MY)
        WinGetPos(&WX, &WY, &WW, &WH, "ahk_id " . TrayMenuGUI.Hwnd)
    } catch {
        TrayMenuGUI := 0
        SetTimer(CheckTrayMenuMousePosition, 0)
        return
    }

    if (MX < WX || MX > WX + WW || MY < WY || MY > WY + WH) {
        TrayMenuCancelHoverAnim()
        if (TrayMenuSelectedItem > 0) {
            try {
                TrayMenuGUI["MenuItemBg" . TrayMenuSelectedItem].BackColor := "1a1a1a"
                TrayMenuGUI["MenuItemText" . TrayMenuSelectedItem].Opt("cff6600")
                if (TrayMenuGUI.HasProp("MenuItemIcon" . TrayMenuSelectedItem)) {
                    TrayMenuGUI["MenuItemIcon" . TrayMenuSelectedItem].Opt("cff6600")
                }
                TrayMenuSelectedItem := 0
            }
        }
        return
    }

    MenuItemHeight := 35
    Padding := 10
    RelY := MY - WY

    if (RelY < Padding) {
        TrayMenuCancelHoverAnim()
        if (TrayMenuSelectedItem > 0) {
            try {
                TrayMenuGUI["MenuItemBg" . TrayMenuSelectedItem].BackColor := "1a1a1a"
                TrayMenuGUI["MenuItemText" . TrayMenuSelectedItem].Opt("cff6600")
                if (TrayMenuGUI.HasProp("MenuItemIcon" . TrayMenuSelectedItem))
                    TrayMenuGUI["MenuItemIcon" . TrayMenuSelectedItem].Opt("cff6600")
                TrayMenuSelectedItem := 0
            }
        }
        return
    }

    ItemIndex := Floor((RelY - Padding) / MenuItemHeight) + 1
    try {
        if !TrayMenuGUI["MenuItemBg" . ItemIndex]
            return
    } catch {
        return
    }
    ItemY := Padding + (ItemIndex - 1) * MenuItemHeight
    if (RelY >= ItemY && RelY < ItemY + MenuItemHeight) {
        TrayMenuItemHover(ItemIndex)
    } else {
        TrayMenuCancelHoverAnim()
        if (TrayMenuSelectedItem > 0) {
            try {
                TrayMenuGUI["MenuItemBg" . TrayMenuSelectedItem].BackColor := "1a1a1a"
                TrayMenuGUI["MenuItemText" . TrayMenuSelectedItem].Opt("cff6600")
                if (TrayMenuGUI.HasProp("MenuItemIcon" . TrayMenuSelectedItem)) {
                    TrayMenuGUI["MenuItemIcon" . TrayMenuSelectedItem].Opt("cff6600")
                }
                TrayMenuSelectedItem := 0
            }
        }
    }
}

CloseTrayMenuIfClickedOutside(*) {
    global TrayMenuGUI
    if (TrayMenuGUI != 0) {
        try {
            if (!TrayMenuGUI.HasProp("Hwnd") || !TrayMenuGUI.Hwnd) {
                TrayMenuGUI := 0
                SetTimer(CloseTrayMenuIfClickedOutside, 0)
                SetTimer(CheckTrayMenuMousePosition, 0)
                return
            }
            MouseGetPos(&MX, &MY)
            WinGetPos(&WX, &WY, &WW, &WH, "ahk_id " . TrayMenuGUI.Hwnd)
            if (MX < WX || MX > WX + WW || MY < WY || MY > WY + WH) {
                if (GetKeyState("LButton", "P")) {
                    try {
                        TrayMenuGUI.Destroy()
                        TrayMenuGUI := 0
                        SetTimer(CloseTrayMenuIfClickedOutside, 0)
                        SetTimer(CheckTrayMenuMousePosition, 0)
                    }
                }
            }
        } catch {
            TrayMenuGUI := 0
            SetTimer(CloseTrayMenuIfClickedOutside, 0)
            SetTimer(CheckTrayMenuMousePosition, 0)
        }
    } else {
        SetTimer(CloseTrayMenuIfClickedOutside, 0)
        SetTimer(CheckTrayMenuMousePosition, 0)
    }
}

ToggleFloatingToolbarFromMenu(*) {
    global TrayMenuGUI
    ToggleFloatingToolbar()
    if (TrayMenuGUI != 0) {
        try {
            TrayMenuGUI.Destroy()
            TrayMenuGUI := 0
            SetTimer(CheckTrayMenuMousePosition, 0)
        }
    }
}

ShowSearchCenterFromMenu(*) {
    global TrayMenuGUI

    if (TrayMenuGUI != 0) {
        try {
            TrayMenuGUI.Destroy()
            TrayMenuGUI := 0
            SetTimer(CheckTrayMenuMousePosition, 0)
        }
    }

    if FuncExists("FloatingToolbar_ActivateSearchCenter")
        FloatingToolbar_ActivateSearchCenter()
    else
        ShowSearchCenter()
}

ShowClipboardFromMenu(*) {
    global TrayMenuGUI

    if (TrayMenuGUI != 0) {
        try {
            TrayMenuGUI.Destroy()
            TrayMenuGUI := 0
            SetTimer(CheckTrayMenuMousePosition, 0)
        }
    }

    CP_Show()
}

; 截图：modules\ScreenshotWorkflow.ahk — ExecuteScreenshotWithMenu
ShowScreenshotFromMenu(*) {
    global TrayMenuGUI

    if (TrayMenuGUI != 0) {
        try {
            TrayMenuGUI.Destroy()
            TrayMenuGUI := 0
            SetTimer(CheckTrayMenuMousePosition, 0)
        }
    }

    ExecuteScreenshotWithMenu()
}

ShowConfigFromMenu(*) {
    global TrayMenuGUI

    if (TrayMenuGUI != 0) {
        try {
            TrayMenuGUI.Destroy()
            TrayMenuGUI := 0
            SetTimer(CheckTrayMenuMousePosition, 0)
        }
    }

    ShowConfigGUI()
}

ExitFromMenu(*) {
    CleanUp()
}

HideFloatingToolbarFromPopupMenu(*) {
    global TrayMenuGUI, AppearanceActivationMode
    if (TrayMenuGUI != 0) {
        try {
            TrayMenuGUI.Destroy()
            TrayMenuGUI := 0
            SetTimer(CheckTrayMenuMousePosition, 0)
            SetTimer(CloseTrayMenuIfClickedOutside, 0)
        }
    }
    amRaw := IsSet(AppearanceActivationMode) ? AppearanceActivationMode : "toolbar"
    if (NormalizeAppearanceActivationMode(amRaw) = "bubble") {
        try HideFloatingBubble()
        catch {
        }
    } else {
        HideFloatingToolbar()
    }
}

ReloadScriptFromPopupMenu(*) {
    global TrayMenuGUI
    if (TrayMenuGUI != 0) {
        try {
            TrayMenuGUI.Destroy()
            TrayMenuGUI := 0
            SetTimer(CheckTrayMenuMousePosition, 0)
            SetTimer(CloseTrayMenuIfClickedOutside, 0)
        }
    }
    try FloatingToolbarSaveScale()
    catch {
    }
    try SaveFloatingToolbarPosition()
    catch {
    }
    Reload
}

ShowDarkStylePopupMenuAt(MenuItems, posX, posY) {
    global TrayMenuGUI, TrayMenuSelectedItem

    if (TrayMenuGUI != 0) {
        try {
            TrayMenuCancelHoverAnim()
            TrayMenuGUI.Destroy()
            SetTimer(CheckTrayMenuMousePosition, 0)
            SetTimer(CloseTrayMenuIfClickedOutside, 0)
        }
    }

    n := MenuItems.Length
    MenuItemHeight := 35
    Padding := 10
    MenuWidth := 200
    MenuHeight := n * MenuItemHeight + Padding * 2
    cellPad := 4
    cellUseW := MenuWidth - Padding * 2 - cellPad

    vL := SysGet(76), vT := SysGet(77), vW := SysGet(78), vH := SysGet(79)
    vR := vL + vW, vB := vT + vH
    if (posX < vL + 10) {
        posX := vL + 10
    } else if (posX + MenuWidth > vR - 10) {
        posX := vR - MenuWidth - 10
    }
    if (posY < vT + 10) {
        posY := vT + 10
    } else if (posY + MenuHeight > vB - 10) {
        posY := vB - MenuHeight - 10
    }

    TrayMenuGUI := Gui("+AlwaysOnTop +ToolWindow -Caption -DPIScale")
    if !(IsObject(TrayMenuGUI) && TrayMenuGUI) {
        TrayMenuGUI := 0
        return
    }
    TrayMenuGUI.BackColor := "1a1a1a"
    TrayMenuGUI.Add("Text", "x0 y0 w" . MenuWidth . " h" . MenuHeight . " Background1a1a1a", "")

    TrayMenuSelectedItem := 0
    IconSize := 18

    ClickHelper(item, *) {
        try {
            keepOpen := (item.HasProp("KeepMenuOpen") && item.KeepMenuOpen)
            if (!keepOpen)
                CloseDarkStylePopupMenu()
            if (item.HasProp("Action") && IsObject(item.Action))
                item.Action()
        } catch {
        }
    }

    Loop n {
        Index := A_Index
        Item := MenuItems[Index]
        baseX := Padding
        ItemY := Padding + (Index - 1) * MenuItemHeight
        IconLeftMargin := baseX + 8
        TextLeftMargin := IconLeftMargin + IconSize + 8
        ItemBg := TrayMenuGUI.Add("Text", "x" . baseX . " y" . ItemY . " w" . cellUseW . " h" . MenuItemHeight . " Background1a1a1a vMenuItemBg" . Index, "")
        ItemBg.OnEvent("Click", ClickHelper.Bind(Item))
        iconFile := ResolveDarkPopupItemIconFile(Item, IconSize)
        if (iconFile != "" && FileExist(iconFile)) {
            IconPic := TrayMenuGUI.Add("Picture", "x" . IconLeftMargin . " y" . (ItemY + ((MenuItemHeight - IconSize) // 2)) . " w" . IconSize . " h" . IconSize . " BackgroundTrans vMenuItemIconPic" . Index, iconFile)
            IconPic.OnEvent("Click", ClickHelper.Bind(Item))
        } else if (Item.HasProp("Icon") && Item.Icon != "") {
            IconText := TrayMenuGUI.Add("Text", "x" . IconLeftMargin . " y" . ItemY . " w" . IconSize . " h" . MenuItemHeight . " Center 0x200 cff6600 BackgroundTrans vMenuItemIcon" . Index, Item.Icon)
            IconText.SetFont("s14", "Segoe UI Symbol")
            IconText.OnEvent("Click", ClickHelper.Bind(Item))
        }
        tw := cellUseW - (TextLeftMargin - baseX) - 6
        if (tw < 24)
            tw := 24
        ItemText := TrayMenuGUI.Add("Text", "x" . TextLeftMargin . " y" . ItemY . " w" . tw . " h" . MenuItemHeight . " Left 0x200 cff6600 BackgroundTrans vMenuItemText" . Index, Item.Text)
        ItemText.SetFont("s11", "Segoe UI")
        ItemText.OnEvent("Click", ClickHelper.Bind(Item))
    }

    TrayMenuGUI.Show("x" . posX . " y" . posY . " w" . MenuWidth . " h" . MenuHeight)
    if (IsObject(TrayMenuGUI) && TrayMenuGUI.HasProp("Hwnd") && TrayMenuGUI.Hwnd)
        WinActivate("ahk_id " . TrayMenuGUI.Hwnd)
    SetTimer(CheckTrayMenuMousePosition, 50)
    SetTimer(CloseTrayMenuIfClickedOutside, 100)
}

ResolveDarkPopupItemIconFile(Item, size := 18) {
    try {
        if (Item.HasProp("SvgIcon") && Item.SvgIcon != "" && FileExist(Item.SvgIcon)) {
            return EnsureSvgIconRasterized(Item.SvgIcon, size)
        }
        if (Item.HasProp("IconFile") && Item.IconFile != "" && FileExist(Item.IconFile))
            return Item.IconFile
    } catch {
    }
    return ""
}

EnsureSvgIconRasterized(svgPath, size := 18) {
    try {
        cacheDir := A_ScriptDir "\cache\menu-icons"
        if !DirExist(cacheDir)
            DirCreate(cacheDir)
        baseName := RegExReplace(svgPath, "^.*\\", "")
        key := RegExReplace(baseName, "\.svg$", "")
        pngPath := cacheDir "\" . key . "_" . size . ".png"

        needRender := !FileExist(pngPath)
        if (!needRender) {
            try {
                svgTime := FileGetTime(svgPath, "M")
                pngTime := FileGetTime(pngPath, "M")
                needRender := (svgTime > pngTime)
            } catch {
                needRender := true
            }
        }

        if (needRender) {
            edge := ResolveHeadlessBrowserForSvg()
            if (edge = "")
                return ""
            url := "file:///" . StrReplace(svgPath, "\", "/")
            cmd := '"' . edge . '" --headless --disable-gpu --hide-scrollbars --default-background-color=1a1a1a --window-size=' . size . ',' . size . ' --screenshot="' . pngPath . '" "' . url . '"'
            RunWait(cmd, , "Hide")
            if (!FileExist(pngPath))
                return ""
        }
        return pngPath
    } catch {
        return ""
    }
}

ResolveHeadlessBrowserForSvg() {
    static cached := ""
    if (cached != "" && FileExist(cached))
        return cached
    candidates := [
        "C:\Program Files\Microsoft\Edge\Application\msedge.exe",
        "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
        "C:\Program Files\Google\Chrome\Application\chrome.exe",
        "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe"
    ]
    for _, p in candidates {
        if FileExist(p) {
            cached := p
            return cached
        }
    }
    return ""
}

CloseDarkStylePopupMenu(*) {
    global TrayMenuGUI, TrayMenuSelectedItem
    TrayMenuCancelHoverAnim()
    try {
        if (TrayMenuGUI != 0) {
            try TrayMenuGUI.Destroy()
            TrayMenuGUI := 0
            TrayMenuSelectedItem := 0
        }
    } catch {
    }
    SetTimer(CheckTrayMenuMousePosition, 0)
    SetTimer(CloseTrayMenuIfClickedOutside, 0)
}

FloatingBubbleShowFromMenu(*) {
    try ShowFloatingBubble()
    catch {
    }
}

FloatingBubbleHideFromMenu(*) {
    try HideFloatingBubble()
    catch {
    }
}

ShowCustomTrayMenu(ItemName := "", ItemPos := "", MyMenu := "") {
    global FloatingToolbarIsVisible, AppearanceActivationMode, FloatingBubbleIsVisible

    MenuWidth := 200
    MenuItemHeight := 35
    Padding := 10
    MenuItems := []

    amRaw := IsSet(AppearanceActivationMode) ? AppearanceActivationMode : "toolbar"
    mode := NormalizeAppearanceActivationMode(amRaw)
    ftVis := IsSet(FloatingToolbarIsVisible) ? FloatingToolbarIsVisible : false
    bubVis := IsSet(FloatingBubbleIsVisible) ? FloatingBubbleIsVisible : false
    if (mode = "tray") {
    } else if (mode = "bubble") {
        if (bubVis) {
            MenuItems.Push({ Text: "隐藏悬浮球", Action: FloatingBubbleHideFromMenu, Icon: "☰" })
        } else {
            MenuItems.Push({ Text: "显示悬浮球", Action: FloatingBubbleShowFromMenu, Icon: "☰" })
        }
    } else {
        if (ftVis) {
            MenuItems.Push({ Text: "隐藏工具栏", Action: ToggleFloatingToolbarFromMenu, Icon: "☰" })
            MenuItems.Push({ Text: "最小化到边缘", Action: MinimizeFloatingToolbarToEdge, Icon: "⊏" })
            MenuItems.Push({ Text: "重置大小", Action: FloatingToolbarResetScale, Icon: "⤢" })
        } else {
            MenuItems.Push({ Text: "显示工具栏", Action: ToggleFloatingToolbarFromMenu, Icon: "☰" })
        }
    }
    MenuItems.Push({ Text: "搜索中心", Action: ShowSearchCenterFromMenu, Icon: "●" })
    MenuItems.Push({ Text: "剪贴板", Action: ShowClipboardFromMenu, Icon: "▤" })
    MenuItems.Push({ Text: "截图", Action: ShowScreenshotFromMenu, Icon: "📷" })
    MenuItems.Push({ Text: GetText("open_config_menu"), Action: ShowConfigFromMenu, Icon: "⚙" })
    if (mode != "tray") {
        MenuItems.Push({ Text: "关闭工具栏", Action: HideFloatingToolbarFromPopupMenu, Icon: "◼" })
    }
    MenuItems.Push({ Text: "重启脚本", Action: ReloadScriptFromPopupMenu, Icon: "↻" })
    MenuItems.Push({ Text: GetText("exit_menu"), Action: ExitFromMenu, Icon: "✕" })

    MenuHeight := MenuItems.Length * MenuItemHeight + Padding * 2
    CoordMode("Mouse", "Screen")
    MouseGetPos(&mX, &mY)
    posX := mX - (MenuWidth // 2)
    posY := mY - MenuHeight - 10

    ScreenWidth := SysGet(78)
    ScreenHeight := SysGet(79)
    if (posX < 10) {
        posX := 10
    } else if (posX + MenuWidth > ScreenWidth - 10) {
        posX := ScreenWidth - MenuWidth - 10
    }
    if (posY < 10) {
        posY := mY + 10
    } else if (posY + MenuHeight > ScreenHeight - 10) {
        posY := ScreenHeight - MenuHeight - 10
    }

    ShowDarkStylePopupMenuAt(MenuItems, posX, posY)
}
