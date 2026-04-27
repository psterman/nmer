#Requires AutoHotkey v2.0

global g_CloudPlayerGui := 0
global g_CloudPlayerCtrl := 0
global g_CloudPlayerWv2 := 0
global g_CloudPlayerReady := false
global g_CloudPlayerOpenListPid := 0
global g_CloudPlayerApiBase := "http://127.0.0.1:5244"
global g_CloudPlayerImportBusy := false
global g_CloudPlayerAutoPulseEnabled := false

ShowCloudPlayer(*) {
    CloudPlayer_Show()
}

CloudPlayer_Show() {
    global g_CloudPlayerGui, g_CloudPlayerAutoPulseEnabled
    if !CloudPlayer_EnsureOpenListRunning() {
        try TrayTip("CloudPlayer", "OpenList 未启动。请确认 openlist.exe 已放到 tools\\openlist\\。", "Icon! 2")
        catch {
        }
    }

    if !g_CloudPlayerGui
        CloudPlayer_CreateGui()

    w := Round(A_ScreenWidth * 0.78)
    h := Round(A_ScreenHeight * 0.82)
    if (w < 960)
        w := 960
    if (h < 620)
        h := 620
    try g_CloudPlayerGui.Show("w" . w . " h" . h)
    try WinActivate("ahk_id " . g_CloudPlayerGui.Hwnd)
    g_CloudPlayerAutoPulseEnabled := true
    SetTimer(CloudPlayer_AutoConnectPulse, 6000)
    SetTimer(CloudPlayer_AutoConnectPulse, -150)
}

CloudPlayer_CreateGui() {
    global g_CloudPlayerGui, g_CloudPlayerCtrl, g_CloudPlayerWv2, g_CloudPlayerReady
    global g_CloudPlayerOpenListPid
    global g_CloudPlayerImportBusy, g_CloudPlayerAutoPulseEnabled

    if g_CloudPlayerGui {
        try g_CloudPlayerGui.Destroy()
        catch {
        }
    }

    g_CloudPlayerCtrl := 0
    g_CloudPlayerWv2 := 0
    g_CloudPlayerReady := false
    g_CloudPlayerOpenListPid := 0
    g_CloudPlayerImportBusy := false
    g_CloudPlayerAutoPulseEnabled := false

    ownerOpt := ""
    try {
        global FloatingToolbarGUI
        if IsSet(FloatingToolbarGUI) && FloatingToolbarGUI && FloatingToolbarGUI.Hwnd
            ownerOpt := " +Owner" . FloatingToolbarGUI.Hwnd
    } catch {
    }

    g_CloudPlayerGui := Gui("+Resize +MinSize960x620 +DPIScale" . ownerOpt, "牛马云")
    g_CloudPlayerGui.BackColor := "121212"
    g_CloudPlayerGui.OnEvent("Size", CloudPlayer_OnGuiSize)
    g_CloudPlayerGui.OnEvent("Close", CloudPlayer_OnGuiClose)

    try WebView2.create(g_CloudPlayerGui.Hwnd, CloudPlayer_OnWebViewCreated, WebView2_EnsureSharedEnvBlocking())
    catch as e {
        try MsgBox("CloudPlayer WebView2 创建失败：`n" . e.Message)
        catch {
        }
    }
}

CloudPlayer_OnGuiClose(*) {
    global g_CloudPlayerGui, g_CloudPlayerAutoPulseEnabled
    try g_CloudPlayerGui.Hide()
    g_CloudPlayerAutoPulseEnabled := false
}

CloudPlayer_OnGuiSize(guiObj, minMax, width, height) {
    global g_CloudPlayerCtrl
    if !g_CloudPlayerCtrl
        return
    try g_CloudPlayerCtrl.Move(0, 0, width, height)
}

CloudPlayer_OnWebViewCreated(ctrl) {
    global g_CloudPlayerGui, g_CloudPlayerCtrl, g_CloudPlayerWv2, g_CloudPlayerReady
    global g_CloudPlayerAutoPulseEnabled

    if !IsObject(ctrl) || !ctrl.HasProp("CoreWebView2") {
        try MsgBox("CloudPlayer WebView2 初始化失败。")
        catch {
        }
        return
    }

    g_CloudPlayerCtrl := ctrl
    g_CloudPlayerWv2 := ctrl.CoreWebView2
    g_CloudPlayerReady := true

    try ApplyUnifiedWebViewAssets(g_CloudPlayerWv2)
    try WebView2_RegisterHostBridge(g_CloudPlayerWv2)

    try g_CloudPlayerWv2.Settings.IsStatusBarEnabled := false
    try g_CloudPlayerWv2.Settings.AreDefaultContextMenusEnabled := true
    try g_CloudPlayerWv2.Settings.AreDevToolsEnabled := true

    try g_CloudPlayerWv2.add_WebMessageReceived(CloudPlayer_OnWebMessage)
    catch {
        try g_CloudPlayerWv2.WebMessageReceived(CloudPlayer_OnWebMessage)
    }

    cw := 1120, ch := 760
    try g_CloudPlayerGui.GetClientPos(, , &cw, &ch)
    try g_CloudPlayerCtrl.Move(0, 0, cw, ch)
    url := BuildAppLocalUrl("CloudPlayer.html?t=" . A_TickCount)
    try g_CloudPlayerWv2.Navigate(url)

    g_CloudPlayerAutoPulseEnabled := true
    SetTimer(CloudPlayer_AutoConnectPulse, 6000)
    SetTimer(CloudPlayer_AutoConnectPulse, -200)
}

CloudPlayer_AutoConnectPulse() {
    global g_CloudPlayerWv2, g_CloudPlayerAutoPulseEnabled
    if !g_CloudPlayerAutoPulseEnabled
        return
    if !g_CloudPlayerWv2
        return
    if !CloudPlayer_IsOpenListRunning()
        CloudPlayer_StartOpenList()
    CloudPlayer_NotifyWebViewStatus()
}

CloudPlayer_NotifyWebViewStatus() {
    global g_CloudPlayerWv2, g_CloudPlayerApiBase
    if !g_CloudPlayerWv2
        return
    try CloudPlayer_EnsureOpenListRunning()
    try WebView_QueuePayload(g_CloudPlayerWv2, Map(
        "type", "cloudplayer_status",
        "apiBase", g_CloudPlayerApiBase,
        "openListOnline", CloudPlayer_IsOpenListRunning(),
        "openListExe", CloudPlayer_FindOpenListExe()
    ))
}

CloudPlayer_OnWebMessage(sender, args) {
    global g_CloudPlayerWv2, g_CloudPlayerApiBase, g_CloudPlayerImportBusy
    payload := CloudPlayer_ParseWebMessage(args)
    if !(payload is Map) || !payload.Has("type")
        return

    typ := String(payload["type"])

    if (payload.Has("apiBase")) {
        try {
            ab := Trim(String(payload["apiBase"]))
            if (ab != "")
                g_CloudPlayerApiBase := CloudPlayer_NormalizeApiBase(ab)
        } catch {
        }
    }

    if (typ = "cloudplayer_ready") {
        CloudPlayer_NotifyWebViewStatus()
        return
    }

    if (typ = "cloudplayer_ping_openlist") {
        CloudPlayer_NotifyWebViewStatus()
        return
    }

    if (typ = "cloudplayer_set_api_base") {
        CloudPlayer_NotifyWebViewStatus()
        return
    }

    if (typ = "cloudplayer_restart_openlist") {
        ok := CloudPlayer_StartOpenList()
        try WebView_QueuePayload(g_CloudPlayerWv2, Map(
            "type", "cloudplayer_status",
            "apiBase", g_CloudPlayerApiBase,
            "openListOnline", ok,
            "openListExe", CloudPlayer_FindOpenListExe()
        ))
        return
    }

    if (typ = "cloudplayer_open_dashboard") {
        try Run(CloudPlayer_GetOpenListAdminUrl())
        return
    }

    if (typ = "cloudplayer_open_url") {
        url := payload.Has("url") ? Trim(String(payload["url"])) : ""
        if (url != "" && RegExMatch(url, "i)^https?://"))
            CloudPlayer_OpenExternalUrl(url)
        return
    }

    if (typ = "cloudplayer_request_admin_token") {
        errMsg := ""
        tok := CloudPlayer_GetOpenListAdminToken(&errMsg, 12000)
        try WebView_QueuePayload(g_CloudPlayerWv2, Map(
            "type", "cloudplayer_admin_token",
            "ok", tok != "",
            "token", tok,
            "message", tok != "" ? "ok" : (errMsg != "" ? errMsg : "failed")
        ))
        return
    }

    if (typ = "cloudplayer_fs_list") {
        path := payload.Has("path") ? String(payload["path"]) : "/"
        refresh := payload.Has("refresh") ? CloudPlayer_ToBool(payload["refresh"], false) : false
        token := payload.Has("token") ? Trim(String(payload["token"])) : ""
        reqId := payload.Has("reqId") ? String(payload["reqId"]) : ""
        headers := Map("Content-Type", "application/json")
        if (token != "")
            headers["Authorization"] := token
        body := CloudPlayer_JsonForceBoolLiterals(Jxon_Dump(Map(
            "path", path,
            "password", "",
            "page", 1,
            "per_page", 300,
            "refresh", refresh
        )), ["refresh"])
        retFs := CloudPlayer_HttpJson("POST", g_CloudPlayerApiBase . "/api/fs/list", headers, body)
        try WebView_QueuePayload(g_CloudPlayerWv2, Map(
            "type", "cloudplayer_fs_list_result",
            "reqId", reqId,
            "path", path,
            "ok", retFs["ok"],
            "status", retFs["status"],
            "error", retFs["error"],
            "text", retFs["text"]
        ))
        return
    }

    if (typ = "cloudplayer_fs_get") {
        path := payload.Has("path") ? String(payload["path"]) : "/"
        token := payload.Has("token") ? Trim(String(payload["token"])) : ""
        reqId := payload.Has("reqId") ? String(payload["reqId"]) : ""
        headers := Map("Content-Type", "application/json")
        if (token != "")
            headers["Authorization"] := token
        body := Jxon_Dump(Map("path", path, "password", ""))
        retGet := CloudPlayer_HttpJson("POST", g_CloudPlayerApiBase . "/api/fs/get", headers, body)
        try WebView_QueuePayload(g_CloudPlayerWv2, Map(
            "type", "cloudplayer_fs_get_result",
            "reqId", reqId,
            "path", path,
            "ok", retGet["ok"],
            "status", retGet["status"],
            "error", retGet["error"],
            "text", retGet["text"]
        ))
        return
    }

    ; 任意 /api/fs/* JSON POST（复制/粘贴/删除等）；与列表请求一致地使用 g_CloudPlayerApiBase + WinHttp，避免 WebView host bridge HttpRequest 传入非法 URL。
    if (typ = "cloudplayer_api_json") {
        apiPath := payload.Has("apiPath") ? Trim(String(payload["apiPath"])) : ""
        bodyStr := payload.Has("body") ? String(payload["body"]) : ""
        token := payload.Has("token") ? Trim(String(payload["token"])) : ""
        reqId := payload.Has("reqId") ? String(payload["reqId"]) : ""
        if apiPath = "" || !RegExMatch(apiPath, "i)^/api/fs/") {
            try WebView_QueuePayload(g_CloudPlayerWv2, Map(
                "type", "cloudplayer_api_json_result",
                "reqId", reqId,
                "ok", false,
                "status", 0,
                "error", "invalid apiPath",
                "text", ""
            ))
            return
        }
        headers := Map("Content-Type", "application/json", "Accept", "application/json")
        if (token != "")
            headers["Authorization"] := token
        retApi := CloudPlayer_HttpJson("POST", g_CloudPlayerApiBase . apiPath, headers, bodyStr)
        try WebView_QueuePayload(g_CloudPlayerWv2, Map(
            "type", "cloudplayer_api_json_result",
            "reqId", reqId,
            "ok", retApi["ok"],
            "status", retApi["status"],
            "error", retApi["error"],
            "text", retApi["text"]
        ))
        return
    }

    if (typ = "cloudplayer_import_aliyun") {
        if (g_CloudPlayerImportBusy) {
            try WebView_QueuePayload(g_CloudPlayerWv2, Map(
                "type", "cloudplayer_import_result",
                "ok", false,
                "message", "import is already running",
                "mountPath", payload.Has("mountPath") ? String(payload["mountPath"]) : "/aliyun",
                "driver", "AliyundriveOpen"
            ))
            return
        }

        mountPath := payload.Has("mountPath") ? String(payload["mountPath"]) : "/aliyun"
        refreshToken := payload.Has("refreshToken") ? String(payload["refreshToken"]) : ""
        opts := 0
        if (payload.Has("options") && payload["options"] is Map)
            opts := payload["options"]
        g_CloudPlayerImportBusy := true
        CloudPlayer_SendImportProgress("Queued import task...")
        SetTimer(CloudPlayer_RunAliImport.Bind(refreshToken, mountPath, opts), -10)
        return
    }

    if (typ = "cloudplayer_import_storage") {
        if (g_CloudPlayerImportBusy) {
            try WebView_QueuePayload(g_CloudPlayerWv2, Map(
                "type", "cloudplayer_import_result",
                "ok", false,
                "message", "import is already running",
                "provider", payload.Has("provider") ? String(payload["provider"]) : "",
                "mountPath", payload.Has("mountPath") ? String(payload["mountPath"]) : "/",
                "driver", payload.Has("driver") ? String(payload["driver"]) : "Unknown"
            ))
            return
        }
        provider := payload.Has("provider") ? String(payload["provider"]) : ""
        mountPath := payload.Has("mountPath") ? String(payload["mountPath"]) : "/"
        token := payload.Has("token") ? String(payload["token"]) : ""
        driver := payload.Has("driver") ? String(payload["driver"]) : "Unknown"
        opts := 0
        if (payload.Has("options") && payload["options"] is Map)
            opts := payload["options"]
        g_CloudPlayerImportBusy := true
        CloudPlayer_SendImportProgress("Queued import task...")
        SetTimer(CloudPlayer_RunStorageImport.Bind(provider, token, mountPath, driver, opts), -10)
        return
    }
}

CloudPlayer_ParseWebMessage(args) {
    ; Preferred path for postMessage(string).
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

    ; Fallback for postMessage(object) and wrapped JSON-string payloads.
    try {
        jsonStr := args.WebMessageAsJson
        m := Jxon_Load(jsonStr)
        if (m is String)
            m := Jxon_Load(m)
        if (m is Map)
            return m
    } catch {
    }
    return 0
}

CloudPlayer_RunAliImport(refreshToken, mountPath, opts) {
    global g_CloudPlayerWv2, g_CloudPlayerImportBusy
    result := 0
    try {
        result := CloudPlayer_ImportAliyunStorage(refreshToken, mountPath, opts)
    } catch as e {
        result := Map(
            "ok", false,
            "message", "import runtime error: " . e.Message,
            "mountPath", mountPath,
            "driver", "AliyundriveOpen"
        )
    }

    if !(result is Map) {
        result := Map(
            "ok", false,
            "message", "import returned invalid result",
            "mountPath", mountPath,
            "driver", "AliyundriveOpen"
        )
    }
    if !result.Has("mountPath")
        result["mountPath"] := mountPath
    if !result.Has("driver")
        result["driver"] := "AliyundriveOpen"
    if !result.Has("ok")
        result["ok"] := false
    if !result.Has("message")
        result["message"] := result["ok"] ? "import success" : "import failed"

    try WebView_QueuePayload(g_CloudPlayerWv2, Map(
        "type", "cloudplayer_import_result",
        "ok", result["ok"],
        "message", result["message"],
        "provider", "ali",
        "mountPath", result["mountPath"],
        "driver", result["driver"],
        "authToken", result.Has("authToken") ? result["authToken"] : ""
    ))
    g_CloudPlayerImportBusy := false
}

CloudPlayer_RunStorageImport(provider, token, mountPath, driver, opts) {
    global g_CloudPlayerWv2, g_CloudPlayerImportBusy
    result := 0
    try {
        result := CloudPlayer_ImportStorageGeneric(provider, token, mountPath, driver, opts)
    } catch as e {
        result := Map(
            "ok", false,
            "message", "import runtime error: " . e.Message,
            "mountPath", mountPath,
            "driver", driver
        )
    }
    if !(result is Map) {
        result := Map("ok", false, "message", "import returned invalid result", "mountPath", mountPath, "driver", driver)
    }
    if !result.Has("mountPath")
        result["mountPath"] := mountPath
    if !result.Has("driver")
        result["driver"] := driver
    if !result.Has("ok")
        result["ok"] := false
    if !result.Has("message")
        result["message"] := result["ok"] ? "import success" : "import failed"

    try WebView_QueuePayload(g_CloudPlayerWv2, Map(
        "type", "cloudplayer_import_result",
        "ok", result["ok"],
        "message", result["message"],
        "provider", provider,
        "mountPath", result["mountPath"],
        "driver", result["driver"],
        "authToken", result.Has("authToken") ? result["authToken"] : ""
    ))
    g_CloudPlayerImportBusy := false
}

CloudPlayer_EnsureOpenListRunning() {
    if CloudPlayer_IsOpenListRunning()
        return true
    return CloudPlayer_StartOpenList()
}

CloudPlayer_StartOpenList() {
    global g_CloudPlayerOpenListPid
    exe := CloudPlayer_FindOpenListExe()
    if (exe = "")
        return false

    if CloudPlayer_IsOpenListRunning()
        return true

    workdir := CloudPlayer_GetWorkDir(exe)

    ; Prefer `server` subcommand for OpenList/AList.
    try Run('"' . exe . '" server', workdir, "Hide", &pid)
    catch {
        pid := 0
        try Run('"' . exe . '"', workdir, "Hide", &pid)
        catch {
            pid := 0
        }
    }
    g_CloudPlayerOpenListPid := pid

    Loop 18 {
        if CloudPlayer_IsOpenListRunning()
            return true
        Sleep(250)
    }
    return CloudPlayer_IsOpenListRunning()
}

CloudPlayer_FindOpenListExe() {
    candidates := [
        A_ScriptDir "\tools\openlist\openlist.exe",
        A_ScriptDir "\tools\openlist\alist.exe",
        A_ScriptDir "\tools\openlist.exe",
        A_ScriptDir "\tools\alist.exe",
        A_ScriptDir "\openlist.exe",
        A_ScriptDir "\alist.exe"
    ]
    for _, p in candidates {
        if FileExist(p)
            return p
    }
    return ""
}

CloudPlayer_GetWorkDir(exePath) {
    p := StrReplace(String(exePath), "/", "\")
    pos := InStr(p, "\", , -1)
    if (pos <= 0)
        return A_ScriptDir
    return SubStr(p, 1, pos - 1)
}

CloudPlayer_IsOpenListRunning() {
    global g_CloudPlayerApiBase
    apiBase := Trim(String(g_CloudPlayerApiBase))
    if (apiBase = "")
        apiBase := "http://127.0.0.1:5244"
    url := RTrim(apiBase, "/") . "/"

    ; Primary probe: WinHTTP.
    try {
        whr := ComObject("WinHttp.WinHttpRequest.5.1")
        whr.Open("GET", url, false)
        whr.SetTimeouts(3000, 3000, 3000, 3000)
        whr.Send()
        st := Integer(whr.Status)
        if (st >= 200 && st < 600)
            return true
    } catch {
    }

    ; Secondary probe: ServerXMLHTTP (different stack, avoids some WinHTTP env issues).
    try {
        xhr := ComObject("MSXML2.ServerXMLHTTP.6.0")
        xhr.setTimeouts(3000, 3000, 3000, 3000)
        xhr.open("GET", url, false)
        xhr.send()
        st2 := Integer(xhr.status)
        if (st2 >= 200 && st2 < 600)
            return true
    } catch {
    }

    ; Local fallback: if process is running and API is localhost, treat as likely online.
    if (CloudPlayer_IsLocalApiBase(apiBase) && (ProcessExist("openlist.exe") || ProcessExist("alist.exe")))
        return true

    return false
}

CloudPlayer_IsLocalApiBase(apiBase) {
    s := StrLower(Trim(String(apiBase)))
    return InStr(s, "127.0.0.1") || InStr(s, "localhost") || InStr(s, "[::1]")
}

CloudPlayer_GetOpenListAdminUrl() {
    global g_CloudPlayerApiBase
    base := Trim(String(g_CloudPlayerApiBase))
    if (base = "")
        base := "http://127.0.0.1:5244"
    base := RTrim(base, "/")
    return base . "/@manage"
}

CloudPlayer_SendImportProgress(message) {
    global g_CloudPlayerWv2
    msg := Trim(String(message))
    if (msg = "")
        return
    try WebView_QueuePayload(g_CloudPlayerWv2, Map(
        "type", "cloudplayer_import_progress",
        "message", msg
    ))
}

CloudPlayer_ImportAliyunStorage(refreshToken, mountPath := "/aliyun", opts := 0) {
    global g_CloudPlayerApiBase
    out := Map("ok", false, "message", "", "mountPath", "", "driver", "AliyundriveOpen", "authToken", "")
    rt := CloudPlayer_NormalizeProviderToken(refreshToken)
    mp := Trim(String(mountPath))
    if (mp = "")
        mp := "/aliyun"
    if (SubStr(mp, 1, 1) != "/")
        mp := "/" . mp
    out["mountPath"] := mp

    if (rt = "") {
        out["message"] := "refresh token is empty"
        return out
    }
    CloudPlayer_SendImportProgress("Checking OpenList status...")
    if !CloudPlayer_EnsureOpenListRunning() {
        out["message"] := "OpenList is not running"
        return out
    }

    CloudPlayer_SendImportProgress("Getting OpenList admin token...")
    adminTokenErr := ""
    adminToken := CloudPlayer_GetOpenListAdminToken(&adminTokenErr, 12000)
    if (adminToken = "") {
        out["message"] := (adminTokenErr != "") ? adminTokenErr : "failed to get OpenList admin token"
        return out
    }
    out["authToken"] := adminToken

    CloudPlayer_SendImportProgress("Listing existing storages...")
    headers := Map("Authorization", adminToken, "Content-Type", "application/json")
    listRet := CloudPlayer_HttpJson("GET", g_CloudPlayerApiBase . "/api/admin/storage/list", headers)
    if !listRet["ok"] {
        out["message"] := "failed to list storages: " . listRet["error"]
        return out
    }

    targetId := 0
    targetDriver := "AliyundriveOpen"
    if (listRet["json"] is Map && listRet["json"].Has("data")) {
        dataObj := listRet["json"]["data"]
        if (dataObj is Map && dataObj.Has("content") && dataObj["content"] is Array) {
            for _, row in dataObj["content"] {
                try rowPath := String(row.Has("mount_path") ? row["mount_path"] : "")
                catch {
                    rowPath := ""
                }
                if (rowPath = mp) {
                    try targetId := Integer(row.Has("id") ? row["id"] : 0)
                    catch {
                        targetId := 0
                    }
                    try targetDriver := String(row.Has("driver") ? row["driver"] : "AliyundriveOpen")
                    catch {
                        targetDriver := "AliyundriveOpen"
                    }
                    break
                }
            }
        }
    }

    if (targetDriver != "Aliyundrive" && targetDriver != "AliyundriveOpen")
        targetDriver := "AliyundriveOpen"

    rootFolderId := "root"
    driveType := "default"
    useOnlineApi := true
    alipanType := "default"
    apiUrlAddress := "https://api.oplist.org/alicloud/renewapi"
    clientId := ""
    clientSecret := ""

    if (opts is Map) {
        try {
            if (opts.Has("rootFolderId") && Trim(String(opts["rootFolderId"])) != "")
                rootFolderId := Trim(String(opts["rootFolderId"]))
            if (opts.Has("driveType") && Trim(String(opts["driveType"])) != "")
                driveType := Trim(String(opts["driveType"]))
            if (opts.Has("alipanType") && Trim(String(opts["alipanType"])) != "")
                alipanType := Trim(String(opts["alipanType"]))
            if (opts.Has("apiUrlAddress") && Trim(String(opts["apiUrlAddress"])) != "")
                apiUrlAddress := Trim(String(opts["apiUrlAddress"]))
            if (opts.Has("clientId"))
                clientId := Trim(String(opts["clientId"]))
            if (opts.Has("clientSecret"))
                clientSecret := Trim(String(opts["clientSecret"]))
            if (opts.Has("useOnlineApi"))
                useOnlineApi := CloudPlayer_ToBool(opts["useOnlineApi"], true)
        } catch {
        }
    }

    additionObj := (targetDriver = "AliyundriveOpen")
        ? Map(
            "drive_type", driveType,
            "root_folder_id", rootFolderId,
            "refresh_token", rt,
            "order_by", "",
            "order_direction", "",
            "use_online_api", useOnlineApi,
            "alipan_type", alipanType,
            "api_url_address", apiUrlAddress,
            "client_id", clientId,
            "client_secret", clientSecret,
            "remove_way", "",
            "rapid_upload", false,
            "internal_upload", false,
            "livp_download_format", "jpeg"
        )
        : Map(
            "root_folder_id", rootFolderId,
            "refresh_token", rt,
            "order_by", "",
            "order_direction", "",
            "rapid_upload", false,
            "internal_upload", false
        )
    additionJson := Jxon_Dump(additionObj)
    additionJson := CloudPlayer_JsonForceBoolLiterals(additionJson, ["use_online_api", "rapid_upload", "internal_upload"])

    bodyObj := Map(
        "mount_path", mp,
        "order", 0,
        "remark", "",
        "cache_expiration", 30,
        "web_proxy", true,
        "webdav_policy", "302_redirect",
        "down_proxy_url", "",
        "extract_folder", "",
        "enable_sign", false,
        "driver", targetDriver,
        "order_by", "",
        "order_direction", "",
        "status", "work",
        "addition", additionJson
    )
    if (targetId > 0)
        bodyObj["id"] := targetId

    saveUrl := g_CloudPlayerApiBase . ((targetId > 0) ? "/api/admin/storage/update" : "/api/admin/storage/create")
    CloudPlayer_SendImportProgress((targetId > 0)
        ? "Updating Aliyun storage config..."
        : "Creating Aliyun storage config...")
    bodyJson := Jxon_Dump(bodyObj)
    bodyJson := CloudPlayer_JsonForceBoolLiterals(bodyJson, ["web_proxy", "enable_sign"])
    saveRet := CloudPlayer_HttpJson("POST", saveUrl, headers, bodyJson)
    if !saveRet["ok"] {
        out["message"] := "save storage failed: " . saveRet["error"]
        return out
    }

    respMsg := ""
    try respMsg := String(saveRet["json"].Has("message") ? saveRet["json"]["message"] : "")
    catch {
        respMsg := ""
    }
    CloudPlayer_SendImportProgress("Verifying storage status...")
    statusRet := CloudPlayer_HttpJson("GET", g_CloudPlayerApiBase . "/api/admin/storage/list", headers)
    statusHint := ""
    foundAfterSave := false
    if (statusRet["ok"] && statusRet["json"] is Map && statusRet["json"].Has("data")) {
        d2 := statusRet["json"]["data"]
        if (d2 is Map && d2.Has("content") && d2["content"] is Array) {
            for _, row2 in d2["content"] {
                try p2 := String(row2.Has("mount_path") ? row2["mount_path"] : "")
                catch {
                    p2 := ""
                }
                if (p2 = mp) {
                    foundAfterSave := true
                    try s2 := String(row2.Has("status") ? row2["status"] : "")
                    catch {
                        s2 := ""
                    }
                    if (s2 != "" && s2 != "work")
                        statusHint := s2
                    break
                }
            }
        }
    }

    if !foundAfterSave {
        out["message"] := "save returned success but mount path not found after refresh: " . mp
        return out
    }

    ; Verify mount readability. If user selected resource drive and it's empty,
    ; automatically fallback to default drive for AliyundriveOpen.
    verify := CloudPlayer_VerifyMountList(mp, headers)
    if !verify["ok"] {
        out["message"] := "mount check failed: " . verify["message"]
        return out
    }
    if (targetDriver = "AliyundriveOpen" && driveType = "resource" && verify["count"] = 0) {
        CloudPlayer_SendImportProgress("Resource drive is empty, retrying with drive_type=default...")
        additionObj["drive_type"] := "default"
        additionJson2 := Jxon_Dump(additionObj)
        additionJson2 := CloudPlayer_JsonForceBoolLiterals(additionJson2, ["use_online_api", "rapid_upload", "internal_upload"])
        bodyObj["addition"] := additionJson2
        saveRet2 := CloudPlayer_HttpJson("POST", g_CloudPlayerApiBase . "/api/admin/storage/update", headers, CloudPlayer_JsonForceBoolLiterals(Jxon_Dump(bodyObj), ["web_proxy", "enable_sign"]))
        if saveRet2["ok"] {
            driveType := "default"
            verify2 := CloudPlayer_VerifyMountList(mp, headers)
            if !verify2["ok"] {
                out["message"] := "fallback mount check failed: " . verify2["message"]
                return out
            }
            verify := verify2
        }
    }

    out["ok"] := true
    out["driver"] := targetDriver
    out["message"] := (statusHint != "")
        ? "saved, but init status: " . statusHint
        : ((respMsg != "") ? respMsg : "import success")
    if (verify["count"] = 0)
        out["message"] := out["message"] . " (mount is reachable but empty)"
    CloudPlayer_SendImportProgress("Import completed.")
    return out
}

CloudPlayer_ImportStorageGeneric(provider, token, mountPath := "/", driver := "AliyundriveOpen", opts := 0) {
    global g_CloudPlayerApiBase
    providerKey := StrLower(Trim(String(provider)))
    drvInput := Trim(String(driver))
    if (drvInput = "" || drvInput = "Unknown")
        drvInput := CloudPlayer_DefaultDriverByProvider(providerKey)
    if (drvInput = "AliyundriveOpen" || drvInput = "Aliyundrive")
        return CloudPlayer_ImportAliyunStorage(token, mountPath, opts)

    out := Map("ok", false, "message", "", "mountPath", "", "driver", drvInput, "authToken", "")
    tk := CloudPlayer_NormalizeProviderToken(token)
    mp := Trim(String(mountPath))
    if (mp = "")
        mp := "/"
    if (SubStr(mp, 1, 1) != "/")
        mp := "/" . mp
    out["mountPath"] := mp

    if (tk = "") {
        out["message"] := "token is empty"
        return out
    }
    CloudPlayer_SendImportProgress("Checking OpenList status...")
    if !CloudPlayer_EnsureOpenListRunning() {
        out["message"] := "OpenList is not running"
        return out
    }
    CloudPlayer_SendImportProgress("Getting OpenList admin token...")
    adminTokenErr := ""
    adminToken := CloudPlayer_GetOpenListAdminToken(&adminTokenErr, 12000)
    if (adminToken = "") {
        out["message"] := (adminTokenErr != "") ? adminTokenErr : "failed to get OpenList admin token"
        return out
    }
    out["authToken"] := adminToken
    headers := Map("Authorization", adminToken, "Content-Type", "application/json")

    CloudPlayer_SendImportProgress("Listing existing storages...")
    listRet := CloudPlayer_HttpJson("GET", g_CloudPlayerApiBase . "/api/admin/storage/list", headers)
    if !listRet["ok"] {
        out["message"] := "failed to list storages: " . listRet["error"]
        return out
    }
    targetId := 0
    existingDriver := ""
    if (listRet["json"] is Map && listRet["json"].Has("data")) {
        dataObj := listRet["json"]["data"]
        if (dataObj is Map && dataObj.Has("content") && dataObj["content"] is Array) {
            for _, row in dataObj["content"] {
                try rowPath := String(row.Has("mount_path") ? row["mount_path"] : "")
                catch {
                    rowPath := ""
                }
                if (rowPath = mp) {
                    try targetId := Integer(row.Has("id") ? row["id"] : 0)
                    catch {
                        targetId := 0
                    }
                    try existingDriver := String(row.Has("driver") ? row["driver"] : "")
                    catch {
                        existingDriver := ""
                    }
                    break
                }
            }
        }
    }

    migratedLegacyDriver := false
    migratedFromDriver := ""
    migratedToDriver := ""
    if (providerKey = "pan123" && targetId > 0) {
        CloudPlayer_SendImportProgress("Found existing /pan123 storage, recreating to avoid driver-change conflicts...")
        delErrPan := ""
        delRetPan := CloudPlayer_DeleteStorageById(targetId, headers, &delErrPan)
        if !delRetPan["ok"] {
            out["message"] := "failed to replace existing 123Pan mount: " . ((delErrPan != "") ? delErrPan : delRetPan["error"])
            return out
        }
        migratedFromDriver := existingDriver
        migratedToDriver := drvInput
        targetId := 0
        existingDriver := ""
        migratedLegacyDriver := true
    }
    if (providerKey = "quark" && targetId > 0 && existingDriver != "" && StrLower(existingDriver) != StrLower(drvInput)) {
        oldDrv := StrLower(existingDriver)
        newDrv := StrLower(drvInput)
        if (CloudPlayer_IsQuarkDriver(oldDrv) && CloudPlayer_IsQuarkDriver(newDrv)) {
            CloudPlayer_SendImportProgress("Detected mismatched Quark driver (" . existingDriver . " -> " . drvInput . "), replacing mount...")
            delErr := ""
            delRet := CloudPlayer_DeleteStorageById(targetId, headers, &delErr)
            if !delRet["ok"] {
                out["message"] := "failed to auto-replace legacy Quark mount: " . ((delErr != "") ? delErr : delRet["error"])
                return out
            }
            migratedFromDriver := existingDriver
            migratedToDriver := drvInput
            targetId := 0
            existingDriver := ""
            migratedLegacyDriver := true
        } else {
            out["message"] := "existing mount path uses driver=" . existingDriver . ", but current import expects " . drvInput . ". Please delete old mount first or use a new mount path."
            return out
        }
    }
    if (providerKey = "pan123" && targetId > 0 && existingDriver != "" && StrLower(existingDriver) != StrLower(drvInput)) {
        oldDrv2 := StrLower(existingDriver)
        newDrv2 := StrLower(drvInput)
        if (CloudPlayer_IsPan123Driver(oldDrv2) && CloudPlayer_IsPan123Driver(newDrv2)) {
            CloudPlayer_SendImportProgress("Detected mismatched 123Pan driver (" . existingDriver . " -> " . drvInput . "), replacing mount...")
            delErr3 := ""
            delRet3 := CloudPlayer_DeleteStorageById(targetId, headers, &delErr3)
            if !delRet3["ok"] {
                out["message"] := "failed to auto-replace legacy 123Pan mount: " . ((delErr3 != "") ? delErr3 : delRet3["error"])
                return out
            }
            migratedFromDriver := existingDriver
            migratedToDriver := drvInput
            targetId := 0
            existingDriver := ""
            migratedLegacyDriver := true
        } else {
            out["message"] := "existing mount path uses driver=" . existingDriver . ", but current import expects " . drvInput . ". Please delete old mount first or use a new mount path."
            return out
        }
    }

    drvCandidates := []
    ; During Quark driver migration, keep target driver fixed.
    if (migratedLegacyDriver) {
        CloudPlayer_ArrayPushUnique(&drvCandidates, drvInput)
    } else {
        ; OpenList does not allow changing driver on an existing storage record.
        ; If mount path already exists, force update with the existing driver only.
        if (targetId > 0 && existingDriver != "") {
            CloudPlayer_ArrayPushUnique(&drvCandidates, existingDriver)
            ; 123Pan driver naming differs by OpenList build. Keep fallbacks when an old
            ; record locks us to an unavailable alias (e.g. Pan123 missing in some builds).
            if (providerKey = "pan123") {
                for _, c in CloudPlayer_GetDriverCandidates(providerKey, drvInput)
                    CloudPlayer_ArrayPushUnique(&drvCandidates, c)
            }
        } else {
            if (existingDriver != "")
                CloudPlayer_ArrayPushUnique(&drvCandidates, existingDriver)
            for _, c in CloudPlayer_GetDriverCandidates(providerKey, drvInput)
                CloudPlayer_ArrayPushUnique(&drvCandidates, c)
            if (drvCandidates.Length = 0)
                CloudPlayer_ArrayPushUnique(&drvCandidates, drvInput)
        }
    }

    saveRet := 0
    chosenDriver := ""
    lastSaveError := ""
    saveUrl := g_CloudPlayerApiBase . ((targetId > 0) ? "/api/admin/storage/update" : "/api/admin/storage/create")
    for _, drv in drvCandidates {
        additionObj := CloudPlayer_BuildGenericAddition(providerKey, tk, opts, drv)
        additionJson := CloudPlayer_JsonForceBoolLiterals(
            Jxon_Dump(additionObj),
            ["use_online_api", "use_dynamic_upload_api", "low_bandwith_upload_mode", "only_list_video_file", "is_sharepoint", "disable_disk_usage", "enable_direct_upload"]
        )
        bodyObj := Map(
            "mount_path", mp,
            "order", 0,
            "remark", "",
            "cache_expiration", 30,
            "web_proxy", true,
            "webdav_policy", "302_redirect",
            "down_proxy_url", "",
            "extract_folder", "",
            "enable_sign", false,
            "driver", drv,
            "order_by", "",
            "order_direction", "",
            "status", "work",
            "addition", additionJson
        )
        if (targetId > 0)
            bodyObj["id"] := targetId

        CloudPlayer_SendImportProgress((targetId > 0)
            ? "Updating storage config (" . drv . ")..."
            : "Creating storage config (" . drv . ")...")
        bodyJson := CloudPlayer_JsonForceBoolLiterals(Jxon_Dump(bodyObj), ["web_proxy", "enable_sign"])
        saveRet := CloudPlayer_HttpJson("POST", saveUrl, headers, bodyJson)
        if (saveRet["ok"]) {
            chosenDriver := drv
            break
        }
        lowSaveErr := StrLower(String(saveRet["error"]))
        if (providerKey = "pan123"
            && targetId > 0
            && (InStr(lowSaveErr, "no driver named") || InStr(lowSaveErr, "failed get driver new"))) {
            CloudPlayer_SendImportProgress("Detected unavailable stored 123 driver alias, recreating mount...")
            delErr4 := ""
            delRet4 := CloudPlayer_DeleteStorageById(targetId, headers, &delErr4)
            if (delRet4["ok"]) {
                targetId := 0
                saveUrl := g_CloudPlayerApiBase . "/api/admin/storage/create"
                try bodyObj.Delete("id")
                catch {
                }
                bodyJson := CloudPlayer_JsonForceBoolLiterals(Jxon_Dump(bodyObj), ["web_proxy", "enable_sign"])
                ; Re-run current candidate as create, then continue to next fallback if still fails.
                saveRet4 := CloudPlayer_HttpJson("POST", saveUrl, headers, bodyJson)
                if (saveRet4["ok"]) {
                    chosenDriver := drv
                    break
                }
                lowSaveErr := StrLower(String(saveRet4["error"]))
                saveRet := saveRet4
            }
        }
        if (providerKey = "quark"
            && migratedLegacyDriver
            && targetId = 0
            && StrLower(drv) = StrLower(drvInput)
            && InStr(lowSaveErr, "unique constraint failed: x_storages.mount_path")) {
            CloudPlayer_SendImportProgress("Mount path still exists, retrying legacy cleanup...")
            foundId := 0
            foundDriver := ""
            findErr := ""
            if CloudPlayer_FindStorageByMountPath(mp, headers, &foundId, &foundDriver, &findErr) {
                foundDrvLow := StrLower(foundDriver)
                wantDrvLow := StrLower(drvInput)
                if (foundId > 0 && CloudPlayer_IsQuarkDriver(foundDrvLow) && foundDrvLow != wantDrvLow) {
                    delErr2 := ""
                    delRet2 := CloudPlayer_DeleteStorageById(foundId, headers, &delErr2)
                    if (delRet2["ok"]) {
                        saveRet2 := CloudPlayer_HttpJson("POST", g_CloudPlayerApiBase . "/api/admin/storage/create", headers, bodyJson)
                        if (saveRet2["ok"]) {
                            chosenDriver := drv
                            break
                        }
                        lastSaveError := "driver=" . drv . ": " . saveRet2["error"]
                        continue
                    }
                } else if (foundId > 0 && foundDrvLow = wantDrvLow) {
                    bodyObj["id"] := foundId
                    bodyJson2 := CloudPlayer_JsonForceBoolLiterals(Jxon_Dump(bodyObj), ["web_proxy", "enable_sign"])
                    saveRet3 := CloudPlayer_HttpJson("POST", g_CloudPlayerApiBase . "/api/admin/storage/update", headers, bodyJson2)
                    if (saveRet3["ok"]) {
                        chosenDriver := drv
                        break
                    }
                    lastSaveError := "driver=" . drv . ": " . saveRet3["error"]
                    continue
                }
            } else if (findErr != "") {
                lastSaveError := "driver=" . drv . ": " . findErr
                continue
            }
        }
        saveErrText := String(saveRet["error"])
        if (providerKey = "quark" && InStr(StrLower(saveErrText), "require login [guest]")) {
            saveErrText := saveErrText . " (Quark requires valid cookie session; refresh_token-only login may be guest)"
        }
        if (providerKey = "pan123" && InStr(StrLower(saveErrText), "请输入正确的手机号码")) {
            saveErrText := saveErrText . " (current OpenList 123 driver may be phone-login mode; try 123Open with valid client_id/client_secret or use a build that supports refresh_token import)"
        }
        if (providerKey = "pan123" && InStr(StrLower(saveErrText), "no driver named: 123open")) {
            saveErrText := saveErrText . " (current OpenList build does not include 123Open; refresh_token import for 123 is unsupported on this build)"
        }
        if (providerKey = "onedrive" && InStr(StrLower(saveErrText), "unsupported protocol scheme")) {
            saveErrText := saveErrText . " (OneDrive host config missing; try with region=global and redirect_uri=https://api.oplist.org/onedrive/callback)"
        }
        lastSaveError := "driver=" . drv . ": " . saveErrText
    }
    if (chosenDriver = "") {
        out["message"] := "save storage failed: " . (lastSaveError != "" ? lastSaveError : "unknown")
        return out
    }

    CloudPlayer_SendImportProgress("Verifying mount...")
    verify := CloudPlayer_VerifyMountList(mp, headers)
    if !verify["ok"] {
        if (providerKey = "onedrive" && InStr(StrLower(verify["message"]), "segment 'root:'")) {
            CloudPlayer_SendImportProgress("OneDrive root path fallback: retrying with empty root_folder_path...")
            ; Some OpenList builds treat "/" as root: and fail on personal accounts.
            ; Retry once with empty root folder path.
            fixId := targetId
            if (fixId <= 0) {
                findIdTmp := 0
                findDrvTmp := ""
                findErrTmp := ""
                if CloudPlayer_FindStorageByMountPath(mp, headers, &findIdTmp, &findDrvTmp, &findErrTmp)
                    fixId := findIdTmp
            }
            if (fixId <= 0) {
                out["message"] := "mount check failed: " . verify["message"]
                return out
            }
            bodyObj2 := Map(
                "mount_path", mp,
                "order", 0,
                "remark", "",
                "cache_expiration", 30,
                "web_proxy", true,
                "webdav_policy", "302_redirect",
                "down_proxy_url", "",
                "extract_folder", "",
                "enable_sign", false,
                "driver", chosenDriver,
                "order_by", "",
                "order_direction", "",
                "status", "work",
                "id", fixId
            )
            add2 := CloudPlayer_BuildGenericAddition(providerKey, tk, opts, chosenDriver)
            try {
                add2["root_folder_path"] := ""
                add2["RootFolderPath"] := ""
            } catch {
            }
            try add2.Delete("root_folder_id")
            catch {
            }
            addJson2 := CloudPlayer_JsonForceBoolLiterals(
                Jxon_Dump(add2),
                ["use_online_api", "use_dynamic_upload_api", "low_bandwith_upload_mode", "only_list_video_file", "is_sharepoint", "disable_disk_usage", "enable_direct_upload"]
            )
            bodyObj2["addition"] := addJson2
            bodyJsonFallback := CloudPlayer_JsonForceBoolLiterals(Jxon_Dump(bodyObj2), ["web_proxy", "enable_sign"])
            saveRetFallback := CloudPlayer_HttpJson("POST", g_CloudPlayerApiBase . "/api/admin/storage/update", headers, bodyJsonFallback)
            if saveRetFallback["ok"] {
                verify2 := CloudPlayer_VerifyMountList(mp, headers)
                if (verify2["ok"]) {
                    out["ok"] := true
                    out["message"] := "import success (onedrive root path fallback applied)"
                    out["driver"] := chosenDriver
                    if (verify2["count"] = 0)
                        out["message"] := out["message"] . " (mount is reachable but empty)"
                    CloudPlayer_SendImportProgress("Import completed with root path fallback.")
                    return out
                }
            }
        }
        out["message"] := "mount check failed: " . verify["message"]
        return out
    }
    out["ok"] := true
    out["message"] := "import success"
    if (migratedLegacyDriver) {
        migrateName := (providerKey = "quark") ? "Quark" : ((providerKey = "pan123") ? "123Pan" : "legacy")
        out["message"] := out["message"] . " (" . migrateName . " mount auto-migrated: " . migratedFromDriver . " -> " . migratedToDriver . ")"
    }
    out["driver"] := chosenDriver
    if (verify["count"] = 0)
        out["message"] := out["message"] . " (mount is reachable but empty)"
    CloudPlayer_SendImportProgress("Import completed.")
    return out
}

CloudPlayer_ArrayPushUnique(&arr, val) {
    v := Trim(String(val))
    if (v = "")
        return
    for _, x in arr {
        if (StrLower(String(x)) = StrLower(v))
            return
    }
    arr.Push(v)
}

CloudPlayer_IsQuarkDriver(driverName) {
    d := StrLower(Trim(String(driverName)))
    return (d = "quark" || d = "quarkopen")
}

CloudPlayer_IsPan123Driver(driverName) {
    d := StrLower(Trim(String(driverName)))
    return (d = "pan123" || d = "123pan" || d = "123open")
}

CloudPlayer_DeleteStorageById(storageId, headers := 0, &lastErr := "") {
    global g_CloudPlayerApiBase
    ret := Map("ok", false, "error", "invalid storage id")
    sid := 0
    try sid := Integer(storageId)
    catch {
        sid := 0
    }
    if (sid <= 0) {
        lastErr := "invalid storage id"
        return ret
    }

    urlBase := g_CloudPlayerApiBase . "/api/admin/storage/delete"
    sidStr := String(sid)
    attempts := [
        Map("method", "POST", "url", urlBase . "?id=" . sidStr, "body", ""),
        Map("method", "DELETE", "url", urlBase . "?id=" . sidStr, "body", ""),
        Map("method", "POST", "url", urlBase, "body", Jxon_Dump(Map("id", sid))),
        Map("method", "POST", "url", urlBase, "body", Jxon_Dump(Map("id", sidStr))),
        Map("method", "POST", "url", urlBase, "body", Jxon_Dump(Map("ids", [sid]))),
        Map("method", "POST", "url", urlBase, "body", Jxon_Dump(Map("ids", [sidStr])))
    ]

    for _, req in attempts {
        one := CloudPlayer_HttpJson(req["method"], req["url"], headers, req["body"])
        if (one["ok"]) {
            lastErr := ""
            return one
        }
        try lastErr := String(one["error"])
        catch {
            lastErr := ""
        }
    }

    if (lastErr = "")
        lastErr := "delete request failed"
    ret["error"] := lastErr
    return ret
}

CloudPlayer_FindStorageByMountPath(mountPath, headers := 0, &rowId := 0, &rowDriver := "", &err := "") {
    global g_CloudPlayerApiBase
    rowId := 0
    rowDriver := ""
    err := ""
    mp := Trim(String(mountPath))
    listRet := CloudPlayer_HttpJson("GET", g_CloudPlayerApiBase . "/api/admin/storage/list", headers)
    if !listRet["ok"] {
        err := listRet["error"]
        return false
    }
    if (listRet["json"] is Map && listRet["json"].Has("data")) {
        dataObj := listRet["json"]["data"]
        if (dataObj is Map && dataObj.Has("content") && dataObj["content"] is Array) {
            for _, row in dataObj["content"] {
                try rowPath := String(row.Has("mount_path") ? row["mount_path"] : "")
                catch {
                    rowPath := ""
                }
                if (rowPath = mp) {
                    try rowId := Integer(row.Has("id") ? row["id"] : 0)
                    catch {
                        rowId := 0
                    }
                    try rowDriver := String(row.Has("driver") ? row["driver"] : "")
                    catch {
                        rowDriver := ""
                    }
                    break
                }
            }
        }
    }
    return true
}

CloudPlayer_DefaultDriverByProvider(providerKey) {
    p := StrLower(Trim(String(providerKey)))
    if (p = "baidu")
        return "BaiduNetdisk"
    if (p = "quark")
        return "Quark"
    if (p = "pan115")
        return "Pan115"
    if (p = "pan123")
        return "123Open"
    if (p = "onedrive")
        return "Onedrive"
    if (p = "dropbox")
        return "Dropbox"
    if (p = "yandex")
        return "YandexDisk"
    if (p = "gdrive")
        return "GoogleDrive"
    return "AliyundriveOpen"
}

CloudPlayer_GetDriverCandidates(providerKey, preferred) {
    arr := []
    p := StrLower(Trim(String(providerKey)))
    CloudPlayer_ArrayPushUnique(&arr, preferred)
    if (p = "baidu") {
        CloudPlayer_ArrayPushUnique(&arr, "BaiduNetdisk")
        CloudPlayer_ArrayPushUnique(&arr, "Baidu")
    } else if (p = "quark") {
        pref := StrLower(Trim(String(preferred)))
        if (pref = "quarkopen") {
            CloudPlayer_ArrayPushUnique(&arr, "QuarkOpen")
            CloudPlayer_ArrayPushUnique(&arr, "Quark")
        } else {
            ; Scheme B: keep Quark as primary and avoid unexpected fallback to QuarkOpen.
            CloudPlayer_ArrayPushUnique(&arr, "Quark")
        }
    } else if (p = "pan115") {
        CloudPlayer_ArrayPushUnique(&arr, "Pan115")
        CloudPlayer_ArrayPushUnique(&arr, "115Open")
        CloudPlayer_ArrayPushUnique(&arr, "115 Open")
    } else if (p = "pan123") {
        CloudPlayer_ArrayPushUnique(&arr, "123Open")
    } else if (p = "onedrive") {
        CloudPlayer_ArrayPushUnique(&arr, "Onedrive")
        CloudPlayer_ArrayPushUnique(&arr, "OneDrive")
    } else if (p = "dropbox") {
        CloudPlayer_ArrayPushUnique(&arr, "Dropbox")
    } else if (p = "yandex") {
        CloudPlayer_ArrayPushUnique(&arr, "YandexDisk")
        CloudPlayer_ArrayPushUnique(&arr, "Yandex")
    } else if (p = "gdrive") {
        CloudPlayer_ArrayPushUnique(&arr, "GoogleDrive")
        CloudPlayer_ArrayPushUnique(&arr, "Google Drive")
    }
    return arr
}

CloudPlayer_BuildGenericAddition(providerKey, token, opts := 0, driver := "") {
    p := StrLower(Trim(String(providerKey)))
    drv := StrLower(Trim(String(driver)))
    tk := CloudPlayer_NormalizeProviderToken(token)
    refreshToken := tk
    accessToken := tk
    cookieValue := tk
    rootFolderId := "root"
    clientId := ""
    clientSecret := ""
    apiUrlAddress := ""
    useOnlineApi := true
    region := "global"
    isSharepoint := false
    redirectUri := ""
    siteId := ""
    chunkSize := 5
    customHost := ""
    disableDiskUsage := false
    enableDirectUpload := false
    if (opts is Map) {
        try {
            if (opts.Has("rootFolderId") && Trim(String(opts["rootFolderId"])) != "")
                rootFolderId := Trim(String(opts["rootFolderId"]))
            if (opts.Has("clientId"))
                clientId := Trim(String(opts["clientId"]))
            if (opts.Has("clientSecret"))
                clientSecret := Trim(String(opts["clientSecret"]))
            if (opts.Has("apiUrlAddress"))
                apiUrlAddress := Trim(String(opts["apiUrlAddress"]))
            if (opts.Has("useOnlineApi"))
                useOnlineApi := CloudPlayer_ToBool(opts["useOnlineApi"], true)
            if (opts.Has("region") && Trim(String(opts["region"])) != "")
                region := Trim(String(opts["region"]))
            if (opts.Has("isSharepoint"))
                isSharepoint := CloudPlayer_ToBool(opts["isSharepoint"], false)
            if (opts.Has("redirectUri") && Trim(String(opts["redirectUri"])) != "")
                redirectUri := Trim(String(opts["redirectUri"]))
            if (opts.Has("siteId") && Trim(String(opts["siteId"])) != "")
                siteId := Trim(String(opts["siteId"]))
            if (opts.Has("chunkSize")) {
                try chunkSize := Integer(opts["chunkSize"])
                catch {
                    chunkSize := 5
                }
                if (chunkSize <= 0)
                    chunkSize := 5
            }
            if (opts.Has("customHost"))
                customHost := Trim(String(opts["customHost"]))
            if (opts.Has("disableDiskUsage"))
                disableDiskUsage := CloudPlayer_ToBool(opts["disableDiskUsage"], false)
            if (opts.Has("enableDirectUpload"))
                enableDirectUpload := CloudPlayer_ToBool(opts["enableDirectUpload"], false)
        } catch {
        }
    }

    ; CloudPlayer advanced panel defaults to Aliyun endpoint.
    ; Normalize provider-specific online refresh endpoint for generic providers.
    if (p = "baidu") {
        lowApi := StrLower(apiUrlAddress)
        if (apiUrlAddress = "" || InStr(lowApi, "/alicloud/") || InStr(lowApi, "/baidu/renewapi"))
            apiUrlAddress := "https://api.oplist.org/baiduyun/renewapi"
    } else if (p = "quark") {
        if (rootFolderId = "root")
            rootFolderId := "0"
        ; Scheme B still uses online renew endpoint for better token continuity.
        useOnlineApi := true
        lowApi := StrLower(apiUrlAddress)
        if (apiUrlAddress = "" || InStr(lowApi, "/alicloud/") || InStr(lowApi, "/quark/renewapi"))
            apiUrlAddress := "https://api.oplist.org/quarkyun/renewapi"
        if (drv = "quarkopen" && (clientId = "" || clientSecret = "")) {
            ; Only QuarkOpen needs app_id/sign_key bootstrap and x-pan headers.
            rt2 := ""
            at2 := ""
            app2 := ""
            sign2 := ""
            bootErr := ""
            if CloudPlayer_TryBootstrapQuarkOpen(refreshToken, apiUrlAddress, &rt2, &at2, &app2, &sign2, &bootErr) {
                if (rt2 != "")
                    refreshToken := rt2
                if (at2 != "")
                    accessToken := at2
                if (clientId = "" && app2 != "")
                    clientId := app2
                if (clientSecret = "" && sign2 != "")
                    clientSecret := sign2
            }
        } else if (drv = "quark") {
            ; Quark(UC) requires cookie, not raw refresh token.
            parsedCookie := CloudPlayer_ExtractCookieLikeString(tk)
            if (parsedCookie != "") {
                cookieValue := parsedCookie
            } else {
                rt3 := ""
                at3 := ""
                bootErr2 := ""
                if CloudPlayer_TryBootstrapQuarkCookie(refreshToken, apiUrlAddress, &rt3, &at3, &cookieValue, &bootErr2) {
                    if (rt3 != "")
                        refreshToken := rt3
                    if (at3 != "")
                        accessToken := at3
                } else {
                    ; Avoid treating refresh token text as cookie and ending up in guest mode.
                    cookieValue := ""
                }
            }
        }
    } else if (p = "pan115") {
        if (apiUrlAddress = "" || InStr(StrLower(apiUrlAddress), "/alicloud/"))
            apiUrlAddress := "https://api.oplist.org/115/renewapi"
    } else if (p = "pan123") {
        if (apiUrlAddress = "" || InStr(StrLower(apiUrlAddress), "/alicloud/"))
            apiUrlAddress := "https://api.oplist.org/123cloud/renewapi"
    } else if (p = "onedrive") {
        if (apiUrlAddress = "" || InStr(StrLower(apiUrlAddress), "/alicloud/"))
            apiUrlAddress := "https://api.oplist.org/onedrive/renewapi"
        if (region = "")
            region := "global"
        if (redirectUri = "")
            redirectUri := "https://api.oplist.org/onedrive/callback"
        ; OpenList docs use root folder path (default "/") for OneDrive.
        ; Avoid "Resource not found for the segment 'root:'" caused by empty root path.
        if (rootFolderId = "root")
            rootFolderId := ""
    } else if (p = "dropbox") {
        if (apiUrlAddress = "" || InStr(StrLower(apiUrlAddress), "/alicloud/"))
            apiUrlAddress := "https://api.oplist.org/dropbox/renewapi"
    } else if (p = "yandex") {
        if (apiUrlAddress = "" || InStr(StrLower(apiUrlAddress), "/alicloud/"))
            apiUrlAddress := "https://api.oplist.org/yandex/renewapi"
    } else if (p = "gdrive") {
        if (apiUrlAddress = "" || InStr(StrLower(apiUrlAddress), "/alicloud/"))
            apiUrlAddress := "https://api.oplist.org/googledrive/renewapi"
    }

    add := Map(
        "root_folder_id", rootFolderId,
        "order_by", "",
        "order_direction", "",
        "refresh_token", refreshToken,
        "access_token", accessToken,
        "token", tk,
        "cookie", cookieValue,
        "cookies", cookieValue,
        "use_online_api", useOnlineApi,
        "app_id", clientId,
        "sign_key", clientSecret,
        "client_id", clientId,
        "client_secret", clientSecret,
        "api_url_address", apiUrlAddress,
        "region", region,
        "is_sharepoint", isSharepoint,
        "redirect_uri", redirectUri,
        "site_id", siteId,
        "chunk_size", chunkSize,
        "custom_host", customHost,
        "disable_disk_usage", disableDiskUsage,
        "enable_direct_upload", enableDirectUpload
    )
    if (p = "baidu") {
        ; Avoid Baidu API errno:2 on list when root path is empty.
        add["root_folder_path"] := "/"
    } else if (p = "onedrive") {
        ; For OneDrive, prefer root folder path and avoid root_folder_id based "root:" addressing.
        try add.Delete("root_folder_id")
        catch {
        }
        add["root_folder_path"] := "/"
        add["RootFolderPath"] := "/"
        add["tenant"] := "common"
        add["Tenant"] := "common"
    } else if (p = "pan123" && drv = "123open") {
        ; 123Open on different OpenList builds may parse either snake_case or PascalCase keys.
        add["RefreshToken"] := refreshToken
        add["AccessToken"] := accessToken
        add["ClientID"] := clientId
        add["ClientSecret"] := clientSecret
        add["APIAddress"] := apiUrlAddress
        add["ApiAddress"] := apiUrlAddress
        add["apiAddress"] := apiUrlAddress
    } else if (p = "quark" && drv = "quarkopen") {
        ; Compatibility fields for OpenList builds validating x-pan params.
        quarkClientId := (clientId != "") ? clientId : "5325"
        quarkTm := String(DateDiff(A_NowUTC, "19700101000000", "Seconds"))
        add["x_pan_client_id"] := quarkClientId
        add["x_pan_tm"] := quarkTm
        add["x_pan_token"] := tk
        add["x-pan-client-id"] := quarkClientId
        add["x-pan-tm"] := quarkTm
        add["x-pan-token"] := tk
    }
    return add
}

CloudPlayer_ExtractCookieLikeString(raw) {
    s := Trim(String(raw))
    if (s = "")
        return ""
    if (InStr(s, "__puus=") || InStr(s, "__pus=") || (InStr(s, "=") && InStr(s, ";")))
        return s
    if (RegExMatch(s, "i)(?:^|[?&#])cookie=([^&#\s]+)", &m1))
        return CloudPlayer_UrlDecodeToken(m1[1])
    if (RegExMatch(s, "i)(?:^|[?&#])cookies=([^&#\s]+)", &m2))
        return CloudPlayer_UrlDecodeToken(m2[1])
    return ""
}

CloudPlayer_TryBootstrapQuarkCookie(refreshToken, apiUrlAddress, &outRefresh := "", &outAccess := "", &outCookie := "", &err := "") {
    outRefresh := ""
    outAccess := ""
    outCookie := ""
    err := ""
    rt := Trim(String(refreshToken))
    api := Trim(String(apiUrlAddress))
    if (rt = "" || api = "") {
        err := "refresh token or api url is empty"
        return false
    }
    sep := InStr(api, "?") ? "&" : "?"
    ; quarkyun_fn is fnOS OAuth flow; quarkyun is kept for compatibility.
    urls := [
        api . sep . "refresh_ui=" . rt . "&server_use=true&driver_txt=quarkyun_fn",
        api . sep . "refresh_ui=" . rt . "&server_use=true&driver_txt=quarkyun"
    ]
    lastErr := ""
    for _, u in urls {
        ret := CloudPlayer_HttpJson("GET", u)
        if !ret["ok"] {
            lastErr := ret["error"]
            continue
        }
        if !(ret["json"] is Map) {
            lastErr := "renew api returned non-json response"
            continue
        }
        j := ret["json"]
        payload := j
        try {
            if (j.Has("data") && j["data"] is Map)
                payload := j["data"]
        } catch {
            payload := j
        }
        try outRefresh := Trim(String(payload.Has("refresh_token") ? payload["refresh_token"] : ""))
        catch {
            outRefresh := ""
        }
        try outAccess := Trim(String(payload.Has("access_token") ? payload["access_token"] : ""))
        catch {
            outAccess := ""
        }
        if (outAccess != "") {
            outCookie := "x_pan_client_id=5325; x_pan_access_token=" . outAccess
            err := ""
            return true
        }
        try lastErr := Trim(String(j.Has("text") ? j["text"] : ""))
        catch {
            lastErr := ""
        }
    }
    if (lastErr = "")
        lastErr := "failed to exchange refresh token to access token"
    err := lastErr
    return false
}

CloudPlayer_TryBootstrapQuarkOpen(refreshToken, apiUrlAddress, &outRefresh := "", &outAccess := "", &outAppId := "", &outSignKey := "", &err := "") {
    outRefresh := ""
    outAccess := ""
    outAppId := ""
    outSignKey := ""
    err := ""
    rt := Trim(String(refreshToken))
    api := Trim(String(apiUrlAddress))
    if (rt = "" || api = "") {
        err := "refresh token or api url is empty"
        return false
    }
    sep := InStr(api, "?") ? "&" : "?"
    url := api . sep . "refresh_ui=" . rt . "&server_use=true&driver_txt=quarkyun_oa"
    ret := CloudPlayer_HttpJson("GET", url)
    if !ret["ok"] {
        err := ret["error"]
        return false
    }
    if !(ret["json"] is Map) {
        err := "renew api returned non-json response"
        return false
    }
    j := ret["json"]
    payload := j
    try {
        if (j.Has("data") && j["data"] is Map)
            payload := j["data"]
    } catch {
        payload := j
    }
    try outRefresh := Trim(String(payload.Has("refresh_token") ? payload["refresh_token"] : ""))
    catch {
        outRefresh := ""
    }
    try outAccess := Trim(String(payload.Has("access_token") ? payload["access_token"] : ""))
    catch {
        outAccess := ""
    }
    try outAppId := Trim(String(payload.Has("app_id") ? payload["app_id"] : ""))
    catch {
        outAppId := ""
    }
    try outSignKey := Trim(String(payload.Has("sign_key") ? payload["sign_key"] : ""))
    catch {
        outSignKey := ""
    }
    if (outAppId = "" || outSignKey = "") {
        msg := ""
        try msg := Trim(String(j.Has("text") ? j["text"] : ""))
        catch {
            msg := ""
        }
        if (msg = "")
            msg := "renew api did not return app_id/sign_key"
        err := msg
        return false
    }
    return true
}

CloudPlayer_NormalizeProviderToken(raw) {
    s := Trim(String(raw))
    if (s = "")
        return ""

    if ((SubStr(s, 1, 1) = '"' && SubStr(s, -1) = '"') || (SubStr(s, 1, 1) = "'" && SubStr(s, -1) = "'"))
        s := Trim(SubStr(s, 2, StrLen(s) - 2))
    if (s = "")
        return ""

    if (RegExMatch(s, "i)(?:^|[?&#])refresh_token=([^&#\s]+)", &mRt))
        return CloudPlayer_UrlDecodeToken(mRt[1])
    if (RegExMatch(s, "i)(?:^|[?&#])token=([^&#\s]+)", &mTk))
        return CloudPlayer_UrlDecodeToken(mTk[1])
    q := Chr(34)
    patJson := "i)(?:" . q . "|')?refresh_token(?:" . q . "|')?\s*[:=]\s*(?:" . q . "|')?([^" . q . "',\s\}]+)"
    if (RegExMatch(s, patJson, &mJson))
        return Trim(String(mJson[1]))

    if (SubStr(s, 1, 1) = "{" && SubStr(s, -1) = "}") {
        try {
            j := Jxon_Load(s)
            if (j is Map) {
                try {
                    v := j.Has("refresh_token") ? Trim(String(j["refresh_token"])) : ""
                    if (v != "")
                        return v
                } catch {
                }
                try {
                    v2 := j.Has("refreshToken") ? Trim(String(j["refreshToken"])) : ""
                    if (v2 != "")
                        return v2
                } catch {
                }
                try {
                    d := j.Has("data") ? j["data"] : 0
                    if (d is Map) {
                        v3 := d.Has("refresh_token") ? Trim(String(d["refresh_token"])) : ""
                        if (v3 != "")
                            return v3
                        v4 := d.Has("refreshToken") ? Trim(String(d["refreshToken"])) : ""
                        if (v4 != "")
                            return v4
                    }
                } catch {
                }
            }
        } catch {
        }
    }
    return s
}

CloudPlayer_UrlDecodeToken(s) {
    t := String(s)
    t := StrReplace(t, "+", " ")
    out := ""
    i := 1
    n := StrLen(t)
    while (i <= n) {
        ch := SubStr(t, i, 1)
        if (ch = "%" && i + 2 <= n) {
            hx := SubStr(t, i + 1, 2)
            if RegExMatch(hx, "i)^[0-9a-f]{2}$") {
                out .= Chr("0x" . hx)
                i += 3
                continue
            }
        }
        out .= ch
        i += 1
    }
    return out
}

CloudPlayer_ToBool(val, defaultVal := false) {
    try {
        if (Type(val) = "Integer" || Type(val) = "Float")
            return !!val
        s := StrLower(Trim(String(val)))
        if (s = "true" || s = "1" || s = "yes" || s = "on")
            return true
        if (s = "false" || s = "0" || s = "no" || s = "off")
            return false
    } catch {
    }
    return !!defaultVal
}

CloudPlayer_GetOpenListAdminToken(&errMsg := "", timeoutMs := 12000) {
    errMsg := ""
    exe := CloudPlayer_FindOpenListExe()
    if (exe = "") {
        errMsg := "openlist executable not found"
        return ""
    }
    wd := CloudPlayer_GetWorkDir(exe)
    q := Chr(34)

    ; Try both data-dir modes to match different runtime setups.
    cmd1 := A_ComSpec . " /d /c " . q . "cd /d " . q . wd . q . " && " . q . exe . q . " --data data admin token" . q
    cmd2 := A_ComSpec . " /d /c " . q . "cd /d " . q . wd . q . " && " . q . exe . q . " admin token" . q
    attempts := [cmd1, cmd2]

    lastErr := ""
    for _, cmd in attempts {
        cap := CloudPlayer_ExecCapture(cmd, timeoutMs)
        out := ""
        try out := String(cap["stdout"])
        catch {
            out := ""
        }
        err := ""
        try err := String(cap["stderr"])
        catch {
            err := ""
        }
        allText := out . "`n" . err
        if RegExMatch(allText, "i)Admin token:\s*([^\s`r`n]+)", &m)
            return Trim(String(m[1]))

        timedOut := false
        try timedOut := !!cap["timedOut"]
        catch {
            timedOut := false
        }
        if timedOut
            lastErr := "getting OpenList admin token timed out (" . timeoutMs . "ms)"
        else if (Trim(allText) != "")
            lastErr := "cannot parse admin token from output: " . Trim(SubStr(RegExReplace(allText, "\s+", " "), 1, 220))
        else
            lastErr := "cannot parse admin token from empty output"
    }
    errMsg := (lastErr != "") ? lastErr : "failed to get OpenList admin token"
    return ""
}

CloudPlayer_ExecCapture(cmd, timeoutMs := 12000) {
    result := Map("stdout", "", "stderr", "", "timedOut", false, "exitCode", "")
    ex := 0
    try ex := ComObject("WScript.Shell").Exec(String(cmd))
    catch as e {
        result["stderr"] := e.Message
        return result
    }

    t0 := A_TickCount
    outText := ""
    errText := ""
    while true {
        try {
            while !ex.StdOut.AtEndOfStream
                outText .= ex.StdOut.Read(4096)
        } catch {
        }
        try {
            while !ex.StdErr.AtEndOfStream
                errText .= ex.StdErr.Read(2048)
        } catch {
        }
        if (ex.Status != 0)
            break
        if ((A_TickCount - t0) > timeoutMs) {
            result["timedOut"] := true
            try ex.Terminate()
            break
        }
        Sleep(30)
    }

    try {
        while !ex.StdOut.AtEndOfStream
            outText .= ex.StdOut.Read(4096)
    } catch {
    }
    try {
        while !ex.StdErr.AtEndOfStream
            errText .= ex.StdErr.Read(2048)
    } catch {
    }
    try result["exitCode"] := ex.ExitCode
    catch {
    }
    result["stdout"] := outText
    result["stderr"] := errText
    return result
}

CloudPlayer_VerifyMountList(mountPath, headers) {
    global g_CloudPlayerApiBase
    ret := Map("ok", false, "count", 0, "message", "")
    payload := Map("path", String(mountPath), "password", "", "page", 1, "per_page", 100, "refresh", true)
    body := CloudPlayer_JsonForceBoolLiterals(Jxon_Dump(payload), ["refresh"])
    fsRet := CloudPlayer_HttpJson("POST", g_CloudPlayerApiBase . "/api/fs/list", headers, body)
    if !fsRet["ok"] {
        ret["message"] := fsRet["error"]
        return ret
    }
    j := fsRet["json"]
    if !(j is Map) {
        ret["message"] := "invalid fs/list response"
        return ret
    }
    code := ""
    try code := Integer(j.Has("code") ? j["code"] : 0)
    catch {
        code := 0
    }
    if (code != 200) {
        msg := ""
        try msg := String(j.Has("message") ? j["message"] : "")
        catch {
            msg := ""
        }
        ret["message"] := (msg != "") ? msg : ("fs/list code " . code)
        return ret
    }
    cnt := 0
    try {
        d := j["data"]
        if (d is Map && d.Has("content") && d["content"] is Array)
            cnt := d["content"].Length
    } catch {
        cnt := 0
    }
    ret["ok"] := true
    ret["count"] := cnt
    return ret
}

CloudPlayer_JsonForceBoolLiterals(jsonText, keys) {
    out := String(jsonText)
    q := Chr(34)
    for _, key in keys {
        pat0 := q . key . q . ":\s*0(?=\s*[,}])"
        pat1 := q . key . q . ":\s*1(?=\s*[,}])"
        out := RegExReplace(out, pat0, q . key . q . ":false")
        out := RegExReplace(out, pat1, q . key . q . ":true")
    }
    return out
}

CloudPlayer_NormalizeApiBase(apiBase) {
    s := Trim(String(apiBase))
    if (s = "")
        s := "http://127.0.0.1:5244"
    if !RegExMatch(s, "i)^https?://")
        s := "http://" . LTrim(s, "/")
    return RTrim(s, "/")
}

CloudPlayer_HttpJson(method, url, headers := 0, body := "") {
    ret := Map("ok", false, "status", 0, "json", 0, "text", "", "error", "")
    try {
        whr := ComObject("WinHttp.WinHttpRequest.5.1")
        whr.Open(String(method), String(url), false)
        whr.SetTimeouts(5000, 5000, 10000, 15000)
        if (headers is Map) {
            for k, v in headers
                whr.SetRequestHeader(String(k), String(v))
        }
        whr.Send(body != "" ? String(body) : "")
        st := Integer(whr.Status)
        txt := String(whr.ResponseText)
        ret["status"] := st
        ret["text"] := txt
        try ret["json"] := Jxon_Load(txt)
        catch {
            ret["json"] := 0
        }
        ret["ok"] := (st >= 200 && st < 300)

        ; OpenList can return HTTP 200 with business error code in body.
        if (ret["json"] is Map && ret["json"].Has("code")) {
            bizCode := ""
            try bizCode := Integer(ret["json"]["code"])
            catch {
                bizCode := ""
            }
            if (bizCode != "" && bizCode != 200) {
                ret["ok"] := false
                errBiz := ""
                try errBiz := String(ret["json"].Has("message") ? ret["json"]["message"] : ("code " . bizCode))
                catch {
                    errBiz := "code " . bizCode
                }
                ret["error"] := errBiz
            }
        }

        if !ret["ok"] && (ret["error"] = "") {
            errMsg := ""
            if (ret["json"] is Map && ret["json"].Has("message"))
                errMsg := String(ret["json"]["message"])
            ret["error"] := (errMsg != "") ? errMsg : ("http " . st)
        }
    } catch as e {
        ret["error"] := e.Message
    }
    return ret
}

CloudPlayer_OpenExternalUrl(url) {
    u := Trim(String(url))
    if (u = "")
        return false
    if !RegExMatch(u, "i)^https?://")
        return false

    ; Use ShellExecute first to force default browser handling for URLs.
    try {
        r := DllCall("Shell32\ShellExecuteW"
            , "ptr", 0
            , "wstr", "open"
            , "wstr", u
            , "ptr", 0
            , "ptr", 0
            , "int", 1
            , "ptr")
        if (r > 32)
            return true
    } catch {
    }

    ; Fallback to Run if ShellExecute fails for any reason.
    try {
        Run(u)
        return true
    } catch {
    }
    return false
}
