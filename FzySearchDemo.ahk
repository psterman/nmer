#Requires AutoHotkey v2.0
#SingleInstance Force

#Include modules\FileClassifier.ahk

; 独立演示：150ms 防抖 → Everything 最多 100 条路径 → FileClassifier 打标 → FzyScore+类别加权 → Top 9
; 若 lib\everything64.dll 不可用或 IPC 失败，自动使用内置假路径仍可演示打分与排序。

; --- 与 Cursor Helper 一致的纯脚本打分（无 fuzz DLL）---
FzyScore(query, target) {
    if (StrLen(query) = 0 || StrLen(target) = 0)
        return 0
    qL := StrLower(query)
    tL := StrLower(target)
    lenQ := StrLen(qL)
    lenT := StrLen(tL)
    pos := []
    start := 1
    Loop lenQ {
        ch := SubStr(qL, A_Index, 1)
        found := InStr(tL, ch, false, start)
        if (!found)
            return -100
        pos.Push(found)
        start := found + 1
    }
    slashCount := 0
    Loop lenT {
        if (SubStr(target, A_Index, 1) = "\")
            slashCount += 1
    }
    score := 0.0
    if (pos[1] = 1)
        score += 100
    for k, p in pos {
        curCh := SubStr(target, p, 1)
        if (p > 1) {
            prevCh := SubStr(target, p - 1, 1)
            oPrev := Ord(prevCh)
            if (prevCh = "\" || prevCh = "/" || prevCh = "_" || prevCh = "-" || prevCh = "." || prevCh = " ")
                score += 80
            oCur := Ord(curCh)
            if (oCur >= 65 && oCur <= 90 && oPrev >= 97 && oPrev <= 122)
                score += 60
        }
        if (k > 1) {
            prevP := pos[k - 1]
            gap := p - prevP - 1
            score -= 2 * gap
            if (p = prevP + 1)
                score += 50
        }
    }
    score -= StrLen(target) * 0.02
    score -= slashCount * 1.0
    return score
}

FzyDemoStableCompare(a, b, *) {
    sa := a.HasProp("FzyScore") ? a.FzyScore : -1e30
    sb := b.HasProp("FzyScore") ? b.FzyScore : -1e30
    if (Abs(sa - sb) > 1e-9) {
        diff := sb - sa
        return diff > 0 ? 1 : (diff < 0 ? -1 : 0)
    }
    return a._FzyIdx - b._FzyIdx
}

DemoEverythingPaths(keyword, maxResults := 100) {
    static evDll := A_ScriptDir "\lib\everything64.dll"
    static loaded := false
    if (!FileExist(evDll))
        return []
    if (!loaded) {
        if (!DllCall("LoadLibrary", "Str", evDll, "Ptr"))
            return []
        loaded := true
    }
    if (DllCall(evDll "\Everything_GetMajorVersion", "UInt") = 0)
        return []
    DllCall(evDll "\Everything_CleanUp")
    DllCall(evDll "\Everything_SetSearchW", "WStr", keyword)
    DllCall(evDll "\Everything_SetMax", "UInt", maxResults)
    DllCall(evDll "\Everything_SetRequestFlags", "UInt", 0x00000004 | 0x00000020 | 0x00000080 | 0x00000200)
    if (!DllCall(evDll "\Everything_QueryW", "Int", 1))
        return []
    n := DllCall(evDll "\Everything_GetNumResults", "UInt")
    out := []
    Loop Min(n, maxResults) {
        idx := A_Index - 1
        buf := Buffer(4096, 0)
        DllCall(evDll "\Everything_GetResultFullPathNameW", "UInt", idx, "Ptr", buf.Ptr, "UInt", 2048)
        p := StrGet(buf.Ptr, "UTF-16")
        if (p != "")
            out.Push(p)
    }
    return out
}

DemoFakePaths() {
    bases := ["C:\cursor", "C:\Dev\CursorHelper", "D:\repo\cursor-win", "C:\Users\X\Desktop\小c"]
    out := []
    Loop 100 {
        bi := Mod(A_Index - 1, bases.Length) + 1
        out.Push(bases[bi] "\sub" Mod(A_Index, 5) "\CursorHelper" A_Index ".ahk")
    }
    return out
}

global DemoEdit, DemoLV, DemoDebounce := 0

DemoGui := Gui(, "FzySearchDemo · 防抖150ms · Top9")
DemoGui.SetFont("s10", "Segoe UI")
DemoGui.AddText(, "关键词（子序列模糊）：")
DemoEdit := DemoGui.AddEdit("w520")
DemoGui.AddText(, "Top 9（按 FzyScore 降序）：")
DemoLV := DemoGui.AddListView("w520 r9", ["Score", "Title", "Category", "Path"])
DemoGui.Show()

DemoEdit.OnEvent("Change", DemoOnEditChange)

DemoOnEditChange(*) {
    global DemoDebounce
    if (DemoDebounce != 0)
        SetTimer(DemoDebounce, 0)
    DemoDebounce := DemoRunSearch
    SetTimer(DemoDebounce, -150)
}

DemoRunSearch(*) {
    global DemoEdit, DemoLV, DemoDebounce
    DemoDebounce := 0
    kw := DemoEdit.Value
    DemoLV.Delete()
    if (kw = "")
        return
    paths := DemoEverythingPaths(kw, 100)
    if (paths.Length = 0)
        paths := DemoFakePaths()
    rows := []
    Loop paths.Length {
        p := paths[A_Index]
        rows.Push({ Content: p, Preview: p, Metadata: Map("FilePath", p), _FzyIdx: A_Index })
    }
    try FileClassifier.ProcessResults(&rows, kw)
    Loop rows.Length {
        r := rows[A_Index]
        p := r.Content
        sc := FzyScore(kw, p)
        if (r.HasProp("FzyCategoryBonus"))
            sc += r.FzyCategoryBonus
        r.FzyScore := sc
    }
    rows.Sort(FzyDemoStableCompare)
    try FileClassifier.ApplyParentDirectoryCollapse(&rows)
    Loop rows.Length {
        r := rows[A_Index]
        p := r.Content
        sc := FzyScore(kw, p)
        if (r.HasProp("FzyCategoryBonus"))
            sc += r.FzyCategoryBonus
        r.FzyScore := sc
    }
    rows.Sort(FzyDemoStableCompare)
    limit := Min(9, rows.Length)
    Loop limit {
        r := rows[A_Index]
        disp := r.HasProp("DisplayTitle") && r.DisplayTitle != "" ? r.DisplayTitle : r.Content
        cat := r.HasProp("Category") ? r.Category : ""
        DemoLV.Add("", Format("{:.2f}", r.FzyScore), disp, cat, r.Content)
    }
}
