#Requires AutoHotkey v2.0

; 一键并发打开搜索引擎
OpenSearchGroupEngines() {
    global SearchCenterCurrentGroup, SearchCenterSearchEdit, GuiID_SearchCenter
    global GlobalSearchStatement, SearchCenterDebounceTimer

    GlobalSearchEngine.ReleaseOldStatement()

    if (SearchCenterDebounceTimer != 0) {
        SetTimer(SearchCenterDebounceTimer, 0)
        SearchCenterDebounceTimer := 0
    }

    SearchGroups := [
        {Name: "AI 智搜", Engines: ["DeepSeek", "Claude"], URLs: Map("DeepSeek", "https://chat.deepseek.com/?q={query}", "Claude", "https://claude.ai/chat?q={query}")},
        {Name: "常用搜索", Engines: ["百度", "谷歌"], URLs: Map("百度", "https://www.baidu.com/s?wd={query}", "谷歌", "https://www.google.com/search?q={query}")},
        {Name: "社交媒体", Engines: ["B站", "小红书"], URLs: Map("B站", "https://search.bilibili.com/all?keyword={query}", "小红书", "https://www.xiaohongshu.com/search_result?keyword={query}")}
    ]

    if (SearchCenterCurrentGroup < 0 || SearchCenterCurrentGroup >= SearchGroups.Length)
        return

    CurrentGroup := SearchGroups[SearchCenterCurrentGroup + 1]
    if (!GuiID_SearchCenter || GuiID_SearchCenter = 0 || !IsObject(SearchCenterSearchEdit)) {
        return
    }
    Query := SearchCenterSearchEdit.Value

    if (Query = "")
        Query := "搜索"

    for EngineName, URLTemplate in CurrentGroup.URLs {
        URL := StrReplace(URLTemplate, "{query}", EncodeURIComponent(Query))
        try {
            Run(URL)
            Sleep(100)
        } catch as e {
            OutputDebug("打开搜索引擎失败: " . EngineName . " - " . e.Message)
        }
    }
}

EncodeURIComponent(Str) {
    try {
        Encoded := ""
        Loop Parse, Str {
            Char := A_LoopField
            if (Ord(Char) < 128 && RegExMatch(Char, "[A-Za-z0-9\-_.!~*'()]")) {
                Encoded .= Char
            } else {
                UTF8Buf := Buffer(StrPut(Char, "UTF-8"))
                StrPut(Char, UTF8Buf, "UTF-8")
                Loop UTF8Buf.Size {
                    Byte := NumGet(UTF8Buf, A_Index - 1, "UChar")
                    Encoded .= "%" . Format("{:02X}", Byte)
                }
            }
        }
        return Encoded
    } catch as err {
        return Str
    }
}
