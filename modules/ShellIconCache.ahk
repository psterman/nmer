; ===================== Shell 图标缓存（搜索 ListView）=====================
; AHK v2：SHGetFileInfo(SYSICONINDEX) + SHGetImageList(SHIL_SMALL) + IImageList::GetIcon，
; 与资源管理器「详细信息」列表一致（系统小图标）；回退 SHGFI_ICON|SHGFI_SMALLICON。
; ImageList 尺寸使用 SM_CXSMICON/SM_CYSMICON（按 DPI），避免 48px 塞进 Small 列表导致发糊、显大。

; 按上下文分离（cfg=配置页全域搜索 ListView，sc=搜索中心窗口 ListView），避免共用 ImageList / 队列互相覆盖
global gShellIcon_Ctx := Map()
global gShellIcon_Queue := []
global gShellIcon_SeqByCtx := Map()
global gShellIcon_Batch := 3
global gShellIcon_DiskDir := ""
global gShellIcon_DiskEnabled := false
; 进程名 → 已解析的 .exe 完整路径（空字符串表示已尝试但失败）
global AppPathCache := Map()

ShellIcon_GetCtx(ctxName := "cfg") {
    global gShellIcon_Ctx
    if !gShellIcon_Ctx.Has(ctxName) {
        gShellIcon_Ctx[ctxName] := {
            hIL: 0,
            lvHwnd: 0,
            cachePath: Map(),
            cacheExt: Map(),
            cacheExe: Map(),
            phFile: 1,
            phFolder: 1,
            phGeneric: 1
        }
    }
    return gShellIcon_Ctx[ctxName]
}

; --- 常量（与 Windows SDK 一致）---
global SHGFI_ICON := 0x000000100
global SHGFI_SMALLICON := 0x000000001
global SHGFI_LARGEICON := 0x000000000
global SHGFI_SYSICONINDEX := 0x00004000
global SHGFI_USEFILEATTRIBUTES := 0x000000010
global SHGFI_PIDL := 0x000000008
global FILE_ATTRIBUTE_DIRECTORY := 0x10
global SHIL_SMALL := 0
global SHIL_LARGE := 1
global SHIL_EXTRALARGE := 2
global ILD_NORMAL := 0

; IImageList::GetIcon 在 vtable 中的索引（IUnknown 后第 8 个方法 → 槽位 3+7=10）
global IImageList_GetIconSlot := 10

ShellIcon_InitDiskDir() {
    global gShellIcon_DiskDir, MainScriptDir
    base := EnvGet("LOCALAPPDATA")
    if (base = "")
        base := A_AppData
    dir := base "\CursorHelper\iconcache"
    try DirCreate(dir)
    gShellIcon_DiskDir := dir
}

ShellIcon_NormalizePath(p) {
    if (p = "" || p = 0)
        return ""
    s := StrReplace(p, "/", "\")
    while InStr(s, "\\")
        s := StrReplace(s, "\\", "\")
    return s
}

ShellIcon_IsClsidOrSpecial(p) {
    return InStr(p, "::") || SubStr(p, 1, 2) = "\\"
}

; 从搜索项解析用于取图标的“路径”字符串（与 SortSearchResultsByFzy 一致）
ShellIcon_ResolvePathFromSearchItem(Item) {
    if (!IsObject(Item))
        return ""
    try {
        if (Item.HasProp("Metadata") && IsObject(Item.Metadata) && Item.Metadata.Has("FilePath")) {
            fp := Item.Metadata["FilePath"]
            if (fp != "")
                return ShellIcon_NormalizePath(String(fp))
        }
    } catch {
    }
    ; 剪贴板：SourcePath 为可执行文件，或从 SourceApp 解析真实 .exe 路径
    try {
        if (Item.HasProp("OriginalDataType") && Item.OriginalDataType = "clipboard") {
            if (Item.HasProp("Metadata") && IsObject(Item.Metadata)) {
                if (Item.Metadata.Has("SourcePath") && Item.Metadata["SourcePath"] != "") {
                    sp := ShellIcon_NormalizePath(String(Item.Metadata["SourcePath"]))
                    if (sp != "" && ShellIcon_IsExecutablePathLike(sp))
                        return sp
                }
                if (Item.Metadata.Has("SourceApp") && Item.Metadata["SourceApp"] != "") {
                    sa := String(Item.Metadata["SourceApp"])
                    if (ShellIcon_IsExecutablePathLike(sa))
                        return ShellIcon_NormalizePath(sa)
                    rp := ResolveAppExecutablePath(sa)
                    if (rp != "" && FileExist(rp))
                        return rp
                }
            }
        }
    } catch {
    }
    ; 搜索中心扁平化结果无 Metadata，文件路径在 Content
    try {
        if (Item.HasProp("OriginalDataType") && (Item.OriginalDataType = "file" || Item.OriginalDataType = "folder")) {
            c := Item.HasProp("Content") ? Item.Content : ""
            if (c != "")
                return ShellIcon_NormalizePath(String(c))
        }
    } catch {
    }
    cand := ""
    try {
        if (Item.HasProp("Preview") && Item.Preview != "")
            cand := Item.Preview
        else if (Item.HasProp("Content") && Item.Content != "")
            cand := Item.Content
    } catch {
    }
    if (cand = "")
        return ""
    cand := ShellIcon_NormalizePath(String(cand))
    if ShellIcon_ItemIsFileLike(Item) {
        if (ShellIcon_IsClsidOrSpecial(cand) || FileExist(cand) || DirExist(cand))
            return cand
        if RegExMatch(cand, "^[A-Za-z]:\\") || InStr(cand, "\")
            return cand
    }
    return ""
}

ShellIcon_ItemIsFileLike(Item) {
    try {
        if (Item.HasProp("OriginalDataType")) {
            o := Item.OriginalDataType
            if (o = "file" || o = "folder")
                return true
        }
        if (Item.HasProp("DataType")) {
            dt := Item.DataType
            if (dt = "file" || dt = "folder" || dt = "File" || dt = "Folder")
                return true
        }
        if (Item.HasProp("Source")) {
            s := Item.Source
            if (s = "文件" || s = "文件夹" || s = "文件路径")
                return true
        }
    } catch {
    }
    return false
}

ShellIcon_GetExtensionLower(path) {
    if (path = "")
        return ""
    SplitPath(path, , , &ext)
    return StrLower(ext)
}

ShellIcon_HashKeyShort(s) {
    ; 短指纹，避免 Map 键过长（非密码学）
    h := 0
    Loop StrLen(s) {
        h := ((h << 5) - h) + Ord(SubStr(s, A_Index, 1))
        h := h & 0xFFFFFFFF
    }
    return Format("{:08x}", h)
}

; --- SHFILEINFO（Unicode）---
ShellIcon_SHGetFileInfoPath(path, flags, dwFileAttributes := 0) {
    cb := A_PtrSize = 8 ? 696 : 688
    sfi := Buffer(cb, 0)
    psz := path = "" ? 0 : StrPtr(path)
    rc := DllCall("shell32\SHGetFileInfoW", "Ptr", psz, "UInt", dwFileAttributes, "Ptr", sfi.Ptr, "UInt", cb, "UInt", flags, "UPtr")
    return Map("ok", rc != 0, "sfi", sfi, "cb", cb)
}

ShellIcon_ReadSysIconIndex(sfiBuf) {
    return NumGet(sfiBuf, A_PtrSize, "Int")
}

ShellIcon_ReadHIcon(sfiBuf) {
    return NumGet(sfiBuf, 0, "Ptr")
}

; IID_IImageList = {46EBBE6B-4B77-4A37-9AA5-1A5DAE7E1881}（静态缓冲，供 SHGetImageList 使用）
; 与 ListView Report 首列一致：系统小图标像素（随 DPI）
ShellIcon_GetSmIconSizeForHwnd(hwnd) {
    cx := 16
    cy := 16
    try {
        dpi := DllCall("user32\GetDpiForWindow", "Ptr", hwnd, "UInt")
        cx := DllCall("user32\GetSystemMetricsForDpi", "Int", 49, "UInt", dpi, "Int")
        cy := DllCall("user32\GetSystemMetricsForDpi", "Int", 50, "UInt", dpi, "Int")
    } catch {
        try {
            cx := DllCall("user32\GetSystemMetrics", "Int", 49, "Int")
            cy := DllCall("user32\GetSystemMetrics", "Int", 50, "Int")
        } catch {
        }
    }
    if (cx < 16)
        cx := 16
    if (cy < 16)
        cy := 16
    return { cx: cx, cy: cy }
}

ShellIcon_IID_IImageListPtr() {
    static buf := 0
    if !buf {
        buf := Buffer(16)
        NumPut("UInt", 0x46EBBE6B, buf, 0)
        NumPut("UShort", 0x4B77, buf, 4)
        NumPut("UShort", 0x4A37, buf, 6)
        NumPut("UChar", 0x9A, buf, 8)
        NumPut("UChar", 0xA5, buf, 9)
        NumPut("UChar", 0x1A, buf, 10)
        NumPut("UChar", 0x5D, buf, 11)
        NumPut("UChar", 0xAE, buf, 12)
        NumPut("UChar", 0x7E, buf, 13)
        NumPut("UChar", 0x18, buf, 14)
        NumPut("UChar", 0x81, buf, 15)
    }
    return buf.Ptr
}

; 优先：SYSICONINDEX + SHGetImageList(SHIL_SMALL) + IImageList::GetIcon（系统 Shell 小图标列表）
ShellIcon_ExtractHIcon(path, useShilSmall := true) {
    path := ShellIcon_NormalizePath(path)
    if (path = "")
        return 0

    usePidl := false
    pidlBuf := 0
    flagsBase := SHGFI_SYSICONINDEX
    attr := 0

    if DirExist(path) {
        flagsBase |= SHGFI_USEFILEATTRIBUTES
        attr := FILE_ATTRIBUTE_DIRECTORY
    } else if !FileExist(path) && !ShellIcon_IsClsidOrSpecial(path) {
        ; 不存在：用扩展名 + USEFILEATTRIBUTES 取类型图标
        flagsBase |= SHGFI_USEFILEATTRIBUTES
        attr := 0x80  ; FILE_ATTRIBUTE_NORMAL
    }

    r := ShellIcon_SHGetFileInfoPath(path, flagsBase, attr)
    if !r["ok"] {
        if ShellIcon_TryGetPidl(path, &pidlBuf) {
            r := ShellIcon_SHGetFileInfoPidl(pidlBuf, SHGFI_SYSICONINDEX)
            usePidl := true
        }
    }
    if !r["ok"] {
        if pidlBuf
            DllCall("ole32\ILFree", "Ptr", pidlBuf)
        return ShellIcon_ExtractHIconSfiFallback(path)
    }

    sfi := r["sfi"]
    iIcon := ShellIcon_ReadSysIconIndex(sfi)
    hIcon := 0

    shil := useShilSmall ? SHIL_SMALL : SHIL_LARGE
    pList := 0
    hr := DllCall("shell32\SHGetImageList", "Int", shil, "Ptr", ShellIcon_IID_IImageListPtr(), "Ptr*", &pList := 0, "Int")
    if (hr = 0 && pList) {
        pVtbl := NumGet(pList, 0, "Ptr")
        pGetIcon := NumGet(pVtbl + IImageList_GetIconSlot * A_PtrSize, 0, "Ptr")
        if (pGetIcon) {
            hr2 := DllCall(pGetIcon, "Ptr", pList, "Int", iIcon, "UInt", ILD_NORMAL, "Ptr*", &hIcon := 0, "Int")
            if (hr2 != 0 || !hIcon)
                hIcon := 0
        }
    }

    if usePidl && pidlBuf {
        DllCall("ole32\ILFree", "Ptr", pidlBuf)
        pidlBuf := 0
    }

    if hIcon
        return hIcon

    return ShellIcon_ExtractHIconSfiFallback(path)
}

ShellIcon_TryGetPidl(path, &outPidl) {
    outPidl := 0
    if (path = "" || !InStr(path, "::"))
        return false
    hr := DllCall("shell32\SHParseDisplayName", "WStr", path, "Ptr", 0, "Ptr*", &pidl := 0, "UInt", 0, "Ptr", 0, "Int")
    if (hr != 0 || !pidl)
        return false
    outPidl := pidl
    return true
}

ShellIcon_SHGetFileInfoPidl(pidl, flags) {
    cb := A_PtrSize = 8 ? 696 : 688
    sfi := Buffer(cb, 0)
    rc := DllCall("shell32\SHGetFileInfoW", "Ptr", pidl, "UInt", 0, "Ptr", sfi.Ptr, "UInt", cb, "UInt", flags | SHGFI_PIDL, "UPtr")
    return Map("ok", rc != 0, "sfi", sfi, "cb", cb)
}

; 回退：SHGetFileInfo 直接取 HICON（小图标，与 SHGFI_SMALLICON 一致）
ShellIcon_ExtractHIconSfiFallback(path) {
    path := ShellIcon_NormalizePath(path)
    flags := SHGFI_ICON | SHGFI_SMALLICON
    attr := 0
    if DirExist(path) {
        flags |= SHGFI_USEFILEATTRIBUTES
        attr := FILE_ATTRIBUTE_DIRECTORY
    } else if !FileExist(path) && !ShellIcon_IsClsidOrSpecial(path) {
        flags |= SHGFI_USEFILEATTRIBUTES
        attr := 0x80
    }
    r := ShellIcon_SHGetFileInfoPath(path, flags, attr)
    if !r["ok"] {
        pidl := 0
        if ShellIcon_TryGetPidl(path, &pidl) {
            cb := A_PtrSize = 8 ? 696 : 688
            sfi := Buffer(cb, 0)
            rc := DllCall("shell32\SHGetFileInfoW", "Ptr", pidl, "UInt", 0, "Ptr", sfi.Ptr, "UInt", cb, "UInt", flags | SHGFI_PIDL, "UPtr")
            DllCall("ole32\ILFree", "Ptr", pidl)
            if !rc
                return 0
            h := ShellIcon_ReadHIcon(sfi)
            return h
        }
        return 0
    }
    h := ShellIcon_ReadHIcon(r["sfi"])
    return h
}

ShellIcon_ImageListAddHIcon(hIL, hIcon) {
    if !hIcon
        return 0
    idx := DllCall("comctl32.dll\ImageList_ReplaceIcon", "Ptr", hIL, "Int", -1, "Ptr", hIcon, "Int")
    DllCall("user32\DestroyIcon", "Ptr", hIcon)
    return idx >= 0 ? idx + 1 : 0
}

ShellIcon_EnsureImageList(LvCtrl, ctxName := "cfg") {
    ctx := ShellIcon_GetCtx(ctxName)
    try {
        lvHwnd := LvCtrl.Hwnd
    } catch {
        return false
    }
    if (ctx.hIL && ctx.lvHwnd = lvHwnd)
        return true
    if (ctx.hIL && ctx.lvHwnd != lvHwnd) {
        try DllCall("comctl32\ImageList_Destroy", "Ptr", ctx.hIL)
        ctx.hIL := 0
        ctx.lvHwnd := 0
        ctx.cachePath := Map()
        ctx.cacheExt := Map()
        ctx.cacheExe := Map()
    }
    sz := ShellIcon_GetSmIconSizeForHwnd(lvHwnd)
    cx := sz.cx
    cy := sz.cy
    hIL := DllCall("comctl32.dll\ImageList_Create", "Int", cx, "Int", cy, "UInt", 0x20, "Int", 8, "Int", 8, "Ptr")
    if !hIL
        return false
    ctx.hIL := hIL
    ctx.lvHwnd := lvHwnd
    try LvCtrl.SetImageList(hIL, 1)
    catch {
        SendMessage(0x1003, 1, hIL, lvHwnd)
    }

    phF := ShellIcon_ExtractHIcon("C:\", true)
    if !phF
        phF := ShellIcon_ExtractHIconSfiFallback("C:\")
    ctx.phFolder := ShellIcon_ImageListAddHIcon(hIL, phF)
    if !ctx.phFolder
        ctx.phFolder := 1

    phFi := ShellIcon_ExtractHIcon("C:\Windows\System32\shell32.dll", true)
    if !phFi
        phFi := ShellIcon_ExtractHIconSfiFallback(A_WinDir "\explorer.exe")
    ctx.phFile := ShellIcon_ImageListAddHIcon(hIL, phFi)
    if !ctx.phFile
        ctx.phFile := ctx.phFolder

    ctx.phGeneric := ctx.phFile
    return true
}

; 对外：取 ImageList 索引（1-based，与 IL_Add 一致）
GetIconIndex(path, ctxName := "cfg") {
    ctx := ShellIcon_GetCtx(ctxName)
    hIL := ctx.hIL
    if !hIL
        return ctx.phGeneric

    path := ShellIcon_NormalizePath(path)
    if (path = "")
        return ctx.phGeneric

    keyFull := "p:" path
    if ctx.cachePath.Has(keyFull)
        return ctx.cachePath[keyFull]

    isDir := DirExist(path)
    ext := ShellIcon_GetExtensionLower(path)
    isExe := !isDir && (ext = "exe")

    if isExe {
        ek := "exe:" ShellIcon_HashKeyShort(StrLower(path))
        if ctx.cacheExe.Has(ek) {
            idx := ctx.cacheExe[ek]
            ctx.cachePath[keyFull] := idx
            return idx
        }
    } else if !isDir && (ext != "") && !ShellIcon_IsClsidOrSpecial(path) {
        ek2 := "ext:" ext
        if ctx.cacheExt.Has(ek2) {
            idx := ctx.cacheExt[ek2]
            ctx.cachePath[keyFull] := idx
            return idx
        }
    }

    hIcon := ShellIcon_ExtractHIcon(path, true)
    if !hIcon {
        idx := isDir ? ctx.phFolder : ctx.phGeneric
        ctx.cachePath[keyFull] := idx
        return idx
    }
    idx := ShellIcon_ImageListAddHIcon(hIL, hIcon)
    if !idx
        idx := ctx.phGeneric

    ctx.cachePath[keyFull] := idx
    if isExe
        ctx.cacheExe["exe:" ShellIcon_HashKeyShort(StrLower(path))] := idx
    else if !isDir && ext != "" && ext != "exe"
        ctx.cacheExt["ext:" ext] := idx
    return idx
}

; 异步队列：Results 与 ListView 行顺序一致；ListViewCtrl 为要改图标的控件；maxRows 为最多排队行数（搜索中心可较大）
UpdateIcons(ResultsArray, RowCount := unset, ListViewCtrl := unset, ctxName := "cfg", maxRows := 200) {
    global gShellIcon_Queue, gShellIcon_SeqByCtx, gShellIcon_Batch
    if !IsSet(RowCount)
        RowCount := ResultsArray.Length
    n := Min(RowCount, ResultsArray.Length, maxRows)
    if !IsSet(ListViewCtrl) {
        global SearchResultsListView
        ListViewCtrl := SearchResultsListView
    }
    if !gShellIcon_SeqByCtx.Has(ctxName)
        gShellIcon_SeqByCtx[ctxName] := 0
    gShellIcon_SeqByCtx[ctxName] += 1
    seq := gShellIcon_SeqByCtx[ctxName]
    ; 仅移除本上下文旧任务，避免与另一 ListView 的队列互相冲掉
    newQ := []
    for j in gShellIcon_Queue {
        if (j.ctxName != ctxName)
            newQ.Push(j)
    }
    gShellIcon_Queue := newQ
    Loop n {
        p := ShellIcon_ResolvePathFromSearchItem(ResultsArray[A_Index])
        gShellIcon_Queue.Push({ seq: seq, row: A_Index, path: p, lv: ListViewCtrl, ctxName: ctxName })
    }
    SetTimer(ShellIcon_ProcessQueueTick, -10)
}

ShellIcon_ProcessQueueTick(*) {
    global gShellIcon_Queue, gShellIcon_SeqByCtx, gShellIcon_Batch
    if !gShellIcon_Queue.Length
        return
    processed := 0
    while gShellIcon_Queue.Length && processed < gShellIcon_Batch {
        job := gShellIcon_Queue.RemoveAt(1)
        if !gShellIcon_SeqByCtx.Has(job.ctxName) || job.seq != gShellIcon_SeqByCtx[job.ctxName]
            continue
        try {
            _ := job.lv.Hwnd
        } catch {
            continue
        }
        if !ShellIcon_EnsureImageList(job.lv, job.ctxName)
            continue
        idx := GetIconIndex(job.path, job.ctxName)
        try {
            job.lv.Modify(job.row, "Icon" . idx)
        } catch {
        }
        processed += 1
    }
    if gShellIcon_Queue.Length
        SetTimer(ShellIcon_ProcessQueueTick, -15)
}

ShellIcon_GetPlaceholderIndex(ctxName := "cfg") {
    return ShellIcon_GetCtx(ctxName).phGeneric
}

; --- 按进程名解析磁盘上的 .exe 路径（注册表 App Paths → 运行中窗口 → WMI）---
ShellIcon_NormalizeProcessName(procName) {
    if (procName = "")
        return ""
    s := Trim(String(procName))
    if (s = "" || s = "Unknown")
        return ""
    SplitPath(s, &name, &dir, &ext, &nameNoExt)
    if (dir != "" && name != "")
        s := name
    else if (name != "")
        s := name
    s := StrLower(s)
    if !InStr(s, ".exe")
        s .= ".exe"
    return s
}

ShellIcon_IsExecutablePathLike(p) {
    p := ShellIcon_NormalizePath(String(p))
    if (p = "" || p = "Unknown")
        return false
    if DirExist(p)
        return false
    if !FileExist(p)
        return false
    SplitPath(p, , , &ext)
    ext := StrLower(ext)
    return ext = "exe" || ext = "lnk" || ext = "com"
}

ShellIcon_ParseAppPathsRegValue(v) {
    v := Trim(String(v))
    if (v = "")
        return ""
    if (SubStr(v, 1, 1) = '"') {
        p2 := InStr(v, '"', , 2)
        if (p2 > 2)
            v := SubStr(v, 2, p2 - 2)
    } else if InStr(v, " ") && InStr(v, ".exe") {
        pos := InStr(v, ".exe", , 0)
        if (pos)
            v := SubStr(v, 1, pos + 3)
    }
    return ShellIcon_NormalizePath(v)
}

ShellIcon_TryRegAppPaths(exeName) {
    keys := [
        "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\" . exeName,
        "HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\App Paths\" . exeName,
        "HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\" . exeName
    ]
    for k in keys {
        try {
            raw := RegRead(k)
            cand := ShellIcon_ParseAppPathsRegValue(raw)
            if (cand != "" && ShellIcon_IsExecutablePathLike(cand))
                return cand
        } catch {
        }
    }
    return ""
}

ShellIcon_QueryWmiExecutablePath(normExe) {
    try {
        wsvc := ComObjGet("winmgmts:\\.\\root\\cimv2")
        q := "SELECT ExecutablePath FROM Win32_Process WHERE Name='" . StrReplace(normExe, "'", "''") . "'"
        col := wsvc.ExecQuery(q)
        if !IsObject(col)
            return ""
        for obj in col {
            try {
                ep := obj.ExecutablePath
                if (ep = "")
                    continue
                ep := ShellIcon_NormalizePath(String(ep))
                if (ep != "" && ShellIcon_IsExecutablePathLike(ep))
                    return ep
            } catch {
            }
        }
    } catch {
    }
    return ""
}

ShellIcon_AppPathCachePut(key, path) {
    global AppPathCache
    AppPathCache[key] := path
    return path
}

; 对外：由进程名（如 chrome.exe）解析本机可执行文件路径；结果写入 AppPathCache
ResolveAppExecutablePath(procName) {
    global AppPathCache
    norm := ShellIcon_NormalizeProcessName(procName)
    if (norm = "")
        return ""
    ck := "app:" norm
    if AppPathCache.Has(ck)
        return AppPathCache[ck]

    p := ShellIcon_TryRegAppPaths(norm)
    if (p != "")
        return ShellIcon_AppPathCachePut(ck, p)

    try {
        lst := WinGetList("ahk_exe " norm)
        Loop lst.Length {
            hwnd := lst[A_Index]
            path := WinGetProcessPath(hwnd)
            path := ShellIcon_NormalizePath(String(path))
            if (path != "" && ShellIcon_IsExecutablePathLike(path))
                return ShellIcon_AppPathCachePut(ck, path)
        }
    } catch {
    }

    p := ShellIcon_QueryWmiExecutablePath(norm)
    if (p != "")
        return ShellIcon_AppPathCachePut(ck, p)

    return ShellIcon_AppPathCachePut(ck, "")
}

; 对外：提取进程对应图标 HICON（调用方负责不泄漏；通常经 GetIconIndex 路径更省事）
GetHIconByProcessName(procName) {
    p := ResolveAppExecutablePath(procName)
    if (p = "" || !FileExist(p))
        return 0
    return ShellIcon_ExtractHIcon(p, true)
}

; 供 UI 显示：由进程名生成简短友好名（如 Chrome）
ShellIcon_FriendlyNameFromExe(procName) {
    n := ShellIcon_NormalizeProcessName(procName)
    if (n = "")
        return ""
    base := n
    if (StrLen(n) > 4 && SubStr(n, -4) = ".exe")
        base := SubStr(n, 1, StrLen(n) - 4)
    if (base = "")
        return ""
    return StrUpper(SubStr(base, 1, 1)) . StrLower(SubStr(base, 2))
}

ShellIcon_Init() {
    ShellIcon_InitDiskDir()
}

ShellIcon_Init()
