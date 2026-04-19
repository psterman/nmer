#Requires AutoHotkey v2.0

Everything_GetScriptRoot() {
    return (IsSet(MainScriptDir) && MainScriptDir != "") ? MainScriptDir : A_ScriptDir
}

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
    root := Everything_GetScriptRoot()
    candidates := []
    candidates.Push(root "\Everything64.exe")
    candidates.Push(root "\Everything.exe")
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
    evDll := Everything_GetScriptRoot() "\lib\everything64.dll"
    static isInitialized := false

    ; 1. 基础防护
    if (!FileExist(evDll)) {
        OutputDebug("AHK_DEBUG: 致命错误 - 找不到 everything64.dll")
        EverythingUserTipOnce("未找到 lib\everything64.dll。请从 Everything SDK 复制 Everything64.dll 到脚本 lib 目录并重命名为 everything64.dll。")
        return []
    }

    ; 2. 首次调用时，确保DLL已加载并检查Everything是否可用
    if (!isInitialized) {
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

    DllCall(evDll "\Everything_CleanUp")

    DllCall(evDll "\Everything_SetSearchW", "WStr", keyword)
    DllCall(evDll "\Everything_SetMax", "UInt", maxResults)

    requestFlags := 0x00000004 | 0x00000020 | 0x00000080 | 0x00000200
    DllCall(evDll "\Everything_SetRequestFlags", "UInt", requestFlags)

    isSuccess := DllCall(evDll "\Everything_QueryW", "Int", 1)

    if (!isSuccess) {
        errCode := DllCall(evDll "\Everything_GetLastError", "UInt")
        OutputDebug("AHK_DEBUG: Everything 查询指令发送失败，错误码: " . errCode)
        EverythingUserTipOnce("Everything 查询失败，错误码: " . errCode . "（2 多为 IPC/未运行）。")
        return []
    }

    count := DllCall(evDll "\Everything_GetNumResults", "UInt")
    OutputDebug("AHK_DEBUG: Everything DLL 返回数量: " . count . " (关键词: " . keyword . ")")

    if (count = 0) {
        errCode := DllCall(evDll "\Everything_GetLastError", "UInt")
        if (errCode != 0) {
            OutputDebug("AHK_DEBUG: Everything 查询后错误码: " . errCode)
        }
    }

    results := []
    Loop Min(count, maxResults) {
        index := A_Index - 1

        attributes := DllCall(evDll "\Everything_GetResultAttributes", "UInt", index, "UInt")
        isDirectory := (attributes & 0x10) != 0

        if (!includeFolders && isDirectory) {
            continue
        }

        buf := Buffer(4096, 0)
        DllCall(evDll "\Everything_GetResultFullPathNameW", "UInt", index, "Ptr", buf.Ptr, "UInt", 2048)
        fullPath := StrGet(buf.Ptr, "UTF-16")

        if (fullPath = "") {
            continue
        }

        fileSize := DllCall(evDll "\Everything_GetResultSize", "UInt", index, "Int64")
        fileTime := DllCall(evDll "\Everything_GetResultDateModified", "UInt", index, "Int64")

        result := Map()
        result["Path"] := fullPath
        result["IsDirectory"] := isDirectory
        result["Type"] := isDirectory ? "folder" : "file"
        result["Size"] := fileSize
        result["DateModified"] := fileTime
        result["Attributes"] := attributes

        results.Push(result)
    }

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

        root := Everything_GetScriptRoot()
        evDll := root "\lib\everything64.dll"
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
    evDll := Everything_GetScriptRoot() "\lib\everything64.dll"
    static isInitialized := false

    if (!FileExist(evDll)) {
        OutputDebug("AHK_DEBUG: Everything_Init - 找不到 everything64.dll")
        return false
    }

    if (!isInitialized) {
        hModule := DllCall("LoadLibrary", "Str", evDll, "Ptr")
        if (!hModule) {
            OutputDebug("AHK_DEBUG: Everything_Init - 无法加载 everything64.dll")
            return false
        }
        isInitialized := true
        OutputDebug("AHK_DEBUG: Everything_Init - DLL 加载成功")
    }

    majorVer := DllCall(evDll "\Everything_GetMajorVersion", "UInt")
    if (majorVer = 0) {
        errCode := DllCall(evDll "\Everything_GetLastError", "UInt")
        OutputDebug("AHK_DEBUG: Everything_Init - IPC 连接失败，错误码: " . errCode)
        runningName := ""
        require64 := (A_PtrSize = 8)
        if (!GetEverythingPID(&runningName, require64)) {
            InitEverythingService()
            Sleep(1000)
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
