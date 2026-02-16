; ======================================================================================================================
; SearchCenter 性能优化补丁
; 版本: 1.0.0
; 功能:
;   - 窗口缓存机制（隐藏/显示替代销毁/重建）
;   - 配置文件缓存
;   - 延迟加载搜索引擎图标
;   - 异步输入法切换
; ======================================================================================================================

; ===================== 全局缓存变量 =====================
global SearchCenterConfigCache := Map()      ; 配置文件缓存
global SearchCenterConfigCacheTime := 0      ; 缓存时间戳
global SearchCenterConfigCacheTTL := 30000   ; 缓存有效期（30秒）
global SearchCenterEngineIconsLoaded := false ; 搜索引擎图标是否已加载
global SearchCenterLastCategory := -1        ; 上次显示的分类
global SearchCenterIsFirstShow := true       ; 是否是首次显示

; ===================== 优化的 ShowSearchCenter 函数 =====================
; 【性能优化版】显示搜索中心窗口（使用缓存机制）
ShowSearchCenter_Optimized() {
    global GuiID_SearchCenter, UI_Colors, ThemeMode
    global SearchCenterActiveArea, SearchCenterCurrentCategory
    global SearchCenterSearchEdit, SearchCenterResultLV, SearchCenterCategoryButtons
    global VoiceSearchEnabledCategories, SearchCenterAreaIndicator
    global SearchCenterEngineIconsLoaded, SearchCenterLastCategory, SearchCenterIsFirstShow
    
    ; 【优化1】如果窗口已存在且未销毁，直接显示（不重建）
    if (GuiID_SearchCenter != 0 && IsObject(GuiID_SearchCenter)) {
        try {
            ; 检查窗口是否仍然存在
            if (WinExist("ahk_id " . GuiID_SearchCenter.Hwnd)) {
                ; 清空搜索框并重置状态
                SearchCenterSearchEdit.Value := ""
                SearchCenterActiveArea := "input"
                SearchCenterCurrentCategory := 0
                SearchCenterLastCategory := -1  ; 强制刷新分类
                SearchCenterEngineIconsLoaded := false  ; 重置图标加载状态
                
                ; 激活并显示窗口
                WinActivate("ahk_id " . GuiID_SearchCenter.Hwnd)
                GuiID_SearchCenter.Show("Center")
                
                ; 聚焦到输入框
                try {
                    SearchCenterSearchEdit.Focus()
                    ; 【优化】异步切换输入法，不阻塞主线程
                    SetTimer(SwitchToChineseIMEForSearchCenter_Async, -10)
                } catch as err {
                }
                
                return  ; 直接返回，避免重建窗口
            }
        } catch as err {
            ; 窗口可能已损坏，继续重建
        }
    }
    
    ; 【优化2】首次显示或窗口不存在时，创建窗口
    if (SearchCenterIsFirstShow || GuiID_SearchCenter = 0) {
        SearchCenterIsFirstShow := false
        ShowSearchCenter_Create()  ; 使用原始创建函数
        return
    }
    
    ; 如果窗口已销毁，重新创建
    ShowSearchCenter_Create()
}

; ===================== 异步输入法切换 =====================
SwitchToChineseIMEForSearchCenter_Async() {
    try {
        global GuiID_SearchCenter, SearchCenterSearchEdit
        if (!GuiID_SearchCenter || !SearchCenterSearchEdit) {
            return
        }
        
        ; 确保窗口仍然活跃
        if (!WinExist("ahk_id " . GuiID_SearchCenter.Hwnd)) {
            return
        }
        
        ; 执行输入法切换（简化版，减少API调用）
        ActiveHwnd := GuiID_SearchCenter.Hwnd
        
        ; 只尝试一次 IME 切换
        hIMC := DllCall("imm32\ImmGetContext", "Ptr", ActiveHwnd, "Ptr")
        if (hIMC) {
            DllCall("imm32\ImmGetConversionStatus", "Ptr", hIMC, "UInt*", &ConversionMode := 0, "UInt*", &SentenceMode := 0)
            ConversionMode := ConversionMode | 0x0001
            DllCall("imm32\ImmSetConversionStatus", "Ptr", hIMC, "UInt", ConversionMode, "UInt", SentenceMode)
            DllCall("imm32\ImmReleaseContext", "Ptr", ActiveHwnd, "Ptr", hIMC)
        }
    } catch as err {
        ; 忽略错误
    }
}

; ===================== 优化的配置文件读取（带缓存）=====================
; 【优化】从缓存或配置文件加载搜索引擎选择状态
LoadSearchCenterSelectedEngines_Cached() {
    global SearchCenterSelectedEnginesByCategory, ConfigFile
    global SearchCenterConfigCache, SearchCenterConfigCacheTime, SearchCenterConfigCacheTTL
    
    ; 初始化
    if (!IsSet(SearchCenterSelectedEnginesByCategory) || !IsObject(SearchCenterSelectedEnginesByCategory)) {
        SearchCenterSelectedEnginesByCategory := Map()
    }
    
    ; 检查缓存是否有效
    CurrentTime := A_TickCount
    if (SearchCenterConfigCacheTime > 0 && (CurrentTime - SearchCenterConfigCacheTime) < SearchCenterConfigCacheTTL) {
        ; 使用缓存数据
        if (SearchCenterConfigCache.Has("SelectedEnginesByCategory")) {
            SearchCenterSelectedEnginesByCategory := SearchCenterConfigCache["SelectedEnginesByCategory"]
            return
        }
    }
    
    ; 缓存无效或不存在，从配置文件加载
    try {
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
        
        ; 更新缓存
        SearchCenterConfigCache["SelectedEnginesByCategory"] := SearchCenterSelectedEnginesByCategory
        SearchCenterConfigCacheTime := CurrentTime
    } catch as err {
        ; 忽略加载错误
    }
}

; ===================== 优化的关闭处理（隐藏而非销毁）=====================
SearchCenterCloseHandler_Optimized(*) {
    global GuiID_SearchCenter, SearchCenterSearchResults, SearchDebounceTimer
    global SearchCenterEngineIcons, SearchCenterFilterButtons
    global IsCountdownActive, CountdownTimer, CountdownRemaining
    
    ; 如果倒计时正在进行，取消倒计时
    if (IsCountdownActive) {
        CancelCountdown()
        return
    }
    
    ; 取消搜索防抖定时器
    if (SearchDebounceTimer != 0) {
        SetTimer(SearchDebounceTimer, 0)
        SearchDebounceTimer := 0
    }
    
    ; 【优化】隐藏窗口而不是销毁，提高下次打开速度
    if (GuiID_SearchCenter != 0) {
        try {
            ; 保存当前窗口位置（可选）
            ; GuiID_SearchCenter.GetPos(&WinX, &WinY)
            ; IniWrite(WinX, ConfigFile, "SearchCenter", "WindowX")
            ; IniWrite(WinY, ConfigFile, "SearchCenter", "WindowY")
            
            ; 隐藏窗口
            GuiID_SearchCenter.Hide()
        } catch as err {
            ; 如果隐藏失败，尝试销毁
            try {
                GuiID_SearchCenter.Destroy()
            } catch as err2 {
            }
            GuiID_SearchCenter := 0
        }
    }
    
    ; 清除搜索结果引用（释放内存）
    SearchCenterSearchResults := []
}

; ===================== 延迟加载搜索引擎图标 =====================
; 【优化】延迟加载搜索引擎图标（在窗口显示后再加载）
RefreshSearchCenterEngineIcons_Lazy() {
    global SearchCenterEngineIconsLoaded
    
    ; 如果已经加载过，不再重复加载
    if (SearchCenterEngineIconsLoaded) {
        return
    }
    
    ; 使用 SetTimer 延迟加载，让窗口先显示出来
    SetTimer(DoRefreshSearchCenterEngineIcons, -50)
}

DoRefreshSearchCenterEngineIcons() {
    global SearchCenterEngineIconsLoaded
    RefreshSearchCenterEngineIcons()
    SearchCenterEngineIconsLoaded := true
}

; ===================== 清除配置文件缓存 =====================
; 在保存配置后调用此函数清除缓存，确保下次读取最新配置
ClearSearchCenterConfigCache() {
    global SearchCenterConfigCache, SearchCenterConfigCacheTime
    SearchCenterConfigCache := Map()
    SearchCenterConfigCacheTime := 0
}

; ===================== 应用优化补丁 =====================
ApplySearchCenterOptimizations() {
    global ShowSearchCenter_Original
    
    ; 保存原始函数引用（如果需要回退）
    ShowSearchCenter_Original := ShowSearchCenter
    
    ; 【注意】这里只是定义优化函数，实际替换需要修改主文件
    ; 使用以下代码替换主文件中的 ShowSearchCenter 调用：
    ; ShowSearchCenter := ShowSearchCenter_Optimized
}

; ======================================================================================================================
; 使用说明：
; 
; 1. 将此文件包含到主脚本中（在 CursorHelper (1).ahk 中添加 #Include）：
;    #Include SearchCenter_Performance_Optimization.ahk
;
; 2. 修改主文件中的 ShowSearchCenter 函数调用，改为：
;    ShowSearchCenter_Optimized()
;
; 3. 或者完全替换 ShowSearchCenter 函数内容（推荐）
;
; 4. 修改 SearchCenterCloseHandler 为 SearchCenterCloseHandler_Optimized
;
; 5. 在保存配置的函数中添加 ClearSearchCenterConfigCache() 调用
; ======================================================================================================================
