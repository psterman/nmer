; ======================================================================================================================
; WebView2SharedEnv.ahk — 全局共享 WebView2 Environment、内存挂起辅助、统一性能相关 Settings
; 依赖：lib\WebView2.ahk（须先 #Include）、全局 WebView2DefaultOptions（可选）
; ======================================================================================================================

#Requires AutoHotkey v2.0

global g_WV2SharedEnv := 0
global g_WV2EnvCreatePromise := 0

WebView2_GetSharedUserDataPath() {
    return A_AppData "\CursorHelper\Wv2Data"
}

WebView2_GetOrCreateSharedEnvPromise() {
    global g_WV2EnvCreatePromise, WebView2DefaultOptions
    if !g_WV2EnvCreatePromise {
        dataDir := WebView2_GetSharedUserDataPath()
        if !DirExist(dataDir)
            DirCreate(dataDir)
        opts := 0
        try {
            if IsSet(WebView2DefaultOptions) && WebView2DefaultOptions
                opts := WebView2DefaultOptions
        }
        g_WV2EnvCreatePromise := WebView2.CreateEnvironmentAsync(opts, dataDir)
    }
    return g_WV2EnvCreatePromise
}

WebView2_EnsureSharedEnvBlocking() {
    global g_WV2SharedEnv
    if g_WV2SharedEnv
        return g_WV2SharedEnv
    g_WV2SharedEnv := WebView2_GetOrCreateSharedEnvPromise().await()
    return g_WV2SharedEnv
}

; .then 回调不能使用 env => { ... }：`{` 会被解析为对象字面量而非代码块（AHK v2）。
global g_WV2_OnSharedEnvReadyCallback := 0

_WV2_OnSharedEnvPromiseResolved(env) {
    global g_WV2SharedEnv, g_WV2_OnSharedEnvReadyCallback
    g_WV2SharedEnv := env
    cb := g_WV2_OnSharedEnvReadyCallback
    g_WV2_OnSharedEnvReadyCallback := 0
    if cb
        cb.Call()
}

WebView2_InitSharedEnvAsync(onReady?) {
    global g_WV2SharedEnv, g_WV2_OnSharedEnvReadyCallback
    if g_WV2SharedEnv {
        if onReady
            onReady.Call()
        return
    }
    g_WV2_OnSharedEnvReadyCallback := onReady
    WebView2_GetOrCreateSharedEnvPromise().then(_WV2_OnSharedEnvPromiseResolved)
}

ApplyWebView2PerformanceSettings(wv2) {
    if !wv2
        return
    try {
        s := wv2.Settings
        s.IsStatusBarEnabled := false
        s.IsPasswordAutosaveEnabled := false
        s.IsGeneralAutofillEnabled := false
    } catch as e {
        try OutputDebug("[WV2] ApplyWebView2PerformanceSettings: " . e.Message)
    }
}

WebView2_NotifyHidden(wv2) {
    if !wv2
        return
    try wv2.PostWebMessageAsJson('{"type":"RESET_STATE"}')
    catch as e {
        try OutputDebug("[WV2] NotifyHidden PostWebMessage: " . e.Message)
    }
    try wv2.MemoryUsageTargetLevel := 1
    catch as e {
        try OutputDebug("[WV2] NotifyHidden MemoryUsageTargetLevel: " . e.Message)
    }
}

WebView2_NotifyShown(wv2) {
    if !wv2
        return
    try wv2.MemoryUsageTargetLevel := 0
    catch as e {
        try OutputDebug("[WV2] NotifyShown MemoryUsageTargetLevel: " . e.Message)
    }
}
