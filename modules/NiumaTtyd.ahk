; Niuma Chat 本机 ttyd 终端：端口检测、重试、WebView 回传
; 依赖主脚本中的 WebView_QueuePayload、A_ScriptDir

global NiumaTtyd_Port := 7681
global NiumaTtyd__BootI := 0

/**
 * 返回 ttyd.exe 的完整路径（与主程序同目录）。
 * @returns {String}
 */
NiumaTtyd_ExePath() {
    return A_ScriptDir . "\ttyd.exe"
}

/**
 * 检测本机端口是否已处于 LISTEN 状态（与语言区域无关的 netstat+findstr 组合）。
 * @returns {Boolean}
 */
NiumaTtyd_IsPortListening() {
    p := NiumaTtyd_Port
    checkCode := RunWait(
        A_ComSpec . ' /c "netstat -an | findstr :' . p . ' | findstr LISTENING >nul 2>&1"',
        , "Hide")
    return (checkCode = 0)
}

/**
 * 在尚未监听时启动 ttyd 进程；已监听则 no-op。
 * @returns {Boolean} 是否已尝试启动或已在监听
 */
; ttyd 启动后附加的可执行（默认 cmd.exe），可在 CursorShortcut.ini [NiumaTtyd] Shell= 覆写
NiumaTtyd_GetShell() {
    s := "cmd.exe"
    try {
        cf := A_ScriptDir . "\CursorShortcut.ini"
        r := IniRead(cf, "NiumaTtyd", "Shell", "cmd.exe")
        r := Trim(String(r))
        if (r != "")
            s := r
    } catch {
    }
    if (StrLen(s) > 800)
        s := "cmd.exe"
    return s
}

NiumaTtyd_SaveShellIni(shell) {
    sh := Trim(String(shell))
    if (sh = "")
        sh := "cmd.exe"
    if (StrLen(sh) > 800)
        sh := "cmd.exe"
    try {
        cf := A_ScriptDir . "\CursorShortcut.ini"
        IniWrite(sh, cf, "NiumaTtyd", "Shell")
    } catch {
    }
}

NiumaTtyd_StartProcess() {
    ttydExe := NiumaTtyd_ExePath()
    p := NiumaTtyd_Port
    if !FileExist(ttydExe)
        return false
    if (NiumaTtyd_IsPortListening())
        return true
    shell := NiumaTtyd_GetShell()
    ; 可执行与参数原样作为 ttyd 的 command 尾段（与官方 ttyd 命令行一致）
    cmdLine := '"' . ttydExe . '" -W -i 127.0.0.1 -p ' . p . ' -w "' . A_ScriptDir . '" ' . shell
    try {
        Run(cmdLine, A_ScriptDir, "Hide")
    } catch as e {
        ; 常见：杀软拦截、工作目录无权限、Shell 路径无效
        try {
            FileAppend(
                (FormatTime(, "yyyy-MM-dd HH:mm:ss")) . " ttyd Run failed: " . e.Message . "`n",
                A_ScriptDir . "\NiumaTtyd_debug.log", "UTF-8")
        } catch {
        }
        return false
    }
    return true
}

/**
 * 确保 ttyd 已监听，带超时与轮询（换机/杀软/慢速磁盘时更稳）。
 * @param {Number} timeoutMs 最长等待毫秒，默认 20000
 * @returns {Boolean} 成功则 true
 */
NiumaTtyd_EnsureReady(timeoutMs := 20000) {
    if !FileExist(NiumaTtyd_ExePath())
        return false
    if (NiumaTtyd_IsPortListening())
        return true
    if !NiumaTtyd_StartProcess()
        return false
    deadline := A_TickCount + Integer(timeoutMs)
    while (A_TickCount < deadline) {
        if (NiumaTtyd_IsPortListening())
            return true
        Sleep(150)
    }
    return NiumaTtyd_IsPortListening()
}

/**
 * 结束本机 ttyd 进程后重新拉起并等待端口就绪（「重启」按钮用）。
 * @param {Number} waitMs
 * @returns {Boolean}
 */
NiumaTtyd_Restart(waitMs := 20000) {
    try {
        RunWait(A_ComSpec . ' /c "taskkill /F /IM ttyd.exe 2>nul"', , "Hide")
    } catch {
    }
    Sleep(500)
    return NiumaTtyd_EnsureReady(waitMs)
}

/**
 * 向 WebView2 回传终端就绪/失败，供 HTML 在就绪后再设 iframe，避免 127.0.0.1 拒绝。
 * @param wv2 WebView2 实例，可为 0
 * @param {Boolean} ok
 * @param {String} errMsg 失败时短文案
 * @param {String} baseUrl 成功时页地址
 */
NiumaTtyd_NotifyWeb(wv2, ok, errMsg, baseUrl) {
    if !wv2
        return
    try {
        if (ok) {
            WebView_QueuePayload(wv2, Map("type", "ttyd_ready", "baseUrl", String(baseUrl)))
        } else {
            WebView_QueuePayload(
                wv2, Map("type", "ttyd_error", "message", errMsg = "" ? "终端未就绪" : errMsg)
            )
        }
    } catch {
    }
}

NiumaTtyd_BaseUrl() {
    return "http://127.0.0.1:" . NiumaTtyd_Port . "/"
}

; WebMessage 里同步长逻辑会卡 UI：延期到独立定时器
NiumaTtyd_DeferredOpenJob(*) {
    global g_FTB_WV2
    wv2 := g_FTB_WV2
    if !FileExist(NiumaTtyd_ExePath()) {
        NiumaTtyd_NotifyWeb(wv2, false, "同目录下未找到 ttyd.exe，请与主程序一起复制。", "")
        return
    }
    ok := NiumaTtyd_EnsureReady(20000)
    if (ok) {
        NiumaTtyd_NotifyWeb(wv2, true, "", NiumaTtyd_BaseUrl())
    } else {
        NiumaTtyd_NotifyWeb(
            wv2, false,
            "20 秒内未监听到 " . NiumaTtyd_Port . " 端口，可点「重试/重启」或检查防火墙/端口占用。",
            ""
        )
    }
}

NiumaTtyd_DeferredRestartJob(*) {
    global g_FTB_WV2
    wv2 := g_FTB_WV2
    if !FileExist(NiumaTtyd_ExePath()) {
        NiumaTtyd_NotifyWeb(wv2, false, "同目录下未找到 ttyd.exe。", "")
        return
    }
    ok := NiumaTtyd_Restart(25000)
    if (ok) {
        NiumaTtyd_NotifyWeb(wv2, true, "", NiumaTtyd_BaseUrl())
    } else {
        NiumaTtyd_NotifyWeb(
            wv2, false, "重启后仍未就绪，请检查是否被安全软件拦截 ttyd.exe。", ""
        )
    }
}

/**
 * 主程序启动时热启动 ttyd，并多轮短重试，避免比 WebView/iframe 晚就绪。
 * @param {Object} * 定时器用
 */
AutoStartTtydForNiumaChat(*) {
    global NiumaTtyd__BootI
    NiumaTtyd__BootI := 0
    NiumaTtyd_StartProcess()
    SetTimer(NiumaTtyd_BootstrapRetryStep, -600)
}

NiumaTtyd_BootstrapRetryStep(*) {
    global NiumaTtyd__BootI
    NiumaTtyd__BootI++
    if (NiumaTtyd_IsPortListening() || NiumaTtyd__BootI > 20) {
        NiumaTtyd__BootI := 0
        return
    }
    NiumaTtyd_StartProcess()
    SetTimer(NiumaTtyd_BootstrapRetryStep, -500)
}
