#Requires AutoHotkey v2.0

; Windows SAPI.SpVoice：异步朗读、purge 打断、停止
global g_SC_SAPI_Voice := unset

; SpeechVoiceSpeakFlags：SVSFlagsAsync=1，SVSFPurgeBeforeSpeak=2
global SC_SAPI_SVF_ASYNC := 1
global SC_SAPI_SVF_PURGE := 2
global SC_SAPI_SVF_SPEAK := 3  ; 异步 + 朗读前清空队列
global SC_SAPI_MAX_CHARS := 12000

SC_SAPI_EnsureVoice() {
    global g_SC_SAPI_Voice
    if IsSet(g_SC_SAPI_Voice) && IsObject(g_SC_SAPI_Voice)
        return g_SC_SAPI_Voice
    try {
        g_SC_SAPI_Voice := ComObject("SAPI.SpVoice")
        return g_SC_SAPI_Voice
    } catch as err {
        g_SC_SAPI_Voice := unset
        return 0
    }
}

; 从搜索中心 / 剪贴板 / Hub / PQP 统一项取出可朗读纯文本
SC_SAPI_TextFromContextItem(Item) {
    if !IsObject(Item)
        return ""
    Content := ""
    Title := ""
    if Item is Map {
        Content := Item.Has("Content") ? String(Item["Content"]) : ""
        Title := Item.Has("Title") ? String(Item["Title"]) : ""
    } else {
        try Content := Item.HasProp("Content") ? String(Item.Content) : ""
        catch {
            Content := ""
        }
        try Title := Item.HasProp("Title") ? String(Item.Title) : ""
        catch {
            Title := ""
        }
    }
    t := Trim(Content)
    if (t = "")
        t := Trim(Title)
    return SC_SAPI_NormalizeSpeechText(t)
}

SC_SAPI_NormalizeSpeechText(s) {
    s := String(s)
    if (s = "")
        return ""
    if InStr(s, "`0")
        s := StrReplace(s, "`0", "")
    s := StrReplace(s, "`r`n", "`n")
    s := StrReplace(s, "`r", "`n")
    s := RegExReplace(s, "[`t`f`v]+", " ")
    s := RegExReplace(s, " +", " ")
    s := RegExReplace(s, "(`n)+", "`n")
    s := Trim(s)
    global SC_SAPI_MAX_CHARS
    if (StrLen(s) > SC_SAPI_MAX_CHARS) {
        s := SubStr(s, 1, SC_SAPI_MAX_CHARS) . "…"
        try TrayTip("语音朗读", "内容过长，已截断至 " . SC_SAPI_MAX_CHARS . " 字", "Iconi 1")
        catch as _t1 {
        }
    }
    return s
}

SC_SAPI_SpeakFromContextItem(Item) {
    t := SC_SAPI_TextFromContextItem(Item)
    if (t = "") {
        try TrayTip("语音朗读", "当前项没有可朗读的文本", "Iconi 2")
        catch as _t2 {
        }
        return false
    }
    v := SC_SAPI_EnsureVoice()
    if !v {
        try TrayTip("语音朗读", "无法创建语音引擎（SAPI）", "Iconx 2")
        catch as _t3 {
        }
        return false
    }
    global SC_SAPI_SVF_SPEAK
    try v.Speak(t, SC_SAPI_SVF_SPEAK)
    catch as err {
        try TrayTip("语音朗读", err.Message, "Iconx 2")
        catch as _t4 {
        }
        return false
    }
    return true
}

SC_SAPI_Stop() {
    global g_SC_SAPI_Voice, SC_SAPI_SVF_PURGE
    if !(IsSet(g_SC_SAPI_Voice) && IsObject(g_SC_SAPI_Voice))
        return
    try g_SC_SAPI_Voice.Speak("", SC_SAPI_SVF_PURGE)
    catch as _t5 {
    }
}
