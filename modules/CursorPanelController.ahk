#Requires AutoHotkey v2.0

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
