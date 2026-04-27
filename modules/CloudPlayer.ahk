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

    try g_CloudPlayerGui.Show("w1120 h760")
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

    g_CloudPlayerGui := Gui("+Resize +MinSize860x560 +DPIScale +ToolWindow" . ownerOpt, "CloudPlayer")
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

    try g_CloudPlayerCtrl.Move(0, 0, 1120, 760)
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
                g_CloudPlayerApiBase := RTrim(ab, "/")
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
    rt := Trim(String(refreshToken))
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
        "web_proxy", false,
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
