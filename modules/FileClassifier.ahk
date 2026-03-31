; FileClassifier — 身份感知、语义加权、标题精简、类别色与 ExtensionCache（后缀 Assoc 缓存）
; Template 需求映射：ASSOCSTR_COMMAND/EXECUTABLE 作打开方式线索，非注册表 Template 键。

class FileClassifier {
    static ExtensionCache := Map()
    static cacheExeDesc := Map()
    static cacheLnk := Map()
    static cacheProjectDir := Map()

    static ASSOCF_INIT_DEFAULTTOSTAR := 0x4
    static ASSOCSTR_COMMAND := 1
    static ASSOCSTR_EXECUTABLE := 2
    static ASSOCSTR_FRIENDLYDOCNAME := 3
    static ASSOCSTR_PERCEIVEDTYPE := 18

    static SCRIPT_EXTS := Map(
        ".ahk", true, ".ps1", true, ".psm1", true, ".bat", true, ".cmd", true,
        ".vbs", true, ".wsf", true, ".js", true, ".jse", true, ".py", true, ".rb", true
    )

    static CONFIG_EXTS := Map(
        ".json", true, ".ini", true, ".yaml", true, ".yml", true, ".toml", true
    )

    static ARCHIVE_EXTS := Map(
        ".zip", true, ".rar", true, ".7z", true, ".tar", true, ".gz", true, ".tgz", true,
        ".bz2", true, ".xz", true, ".cab", true, ".iso", true
    )

    static MEDIA_EXT := Map(
        ".mp4", true, ".mkv", true, ".avi", true, ".mov", true, ".wmv", true, ".webm", true, ".m4v", true,
        ".mp3", true, ".wav", true, ".flac", true, ".aac", true, ".ogg", true, ".m4a", true,
        ".png", true, ".jpg", true, ".jpeg", true, ".gif", true, ".webp", true, ".bmp", true, ".ico", true
    )

    static BONUS_APP := 100.0
    static BONUS_PROJECT := 25.0
    static BONUS_CONFIG := 15.0
    static PENALTY_ARCHIVE := -5.0
    static PENALTY_SYSTEMTEMP := -50.0
    static PENALTY_FOLDER := -60.0
    static PENALTY_FOLDER_SHALLOW := -10.0
    static PENALTY_JUNK_PATH := -100.0
    static PENALTY_SUB_USER_OR_DEV := -20.0
    static PENALTY_PARENT_OVERFLOW := -150.0

    static _polishQueue := []
    static _polishTimer := 0

    static NormalizePath(p) {
        if (p = "")
            return ""
        s := StrReplace(p, "/", "\")
        while InStr(s, "\\")
            s := StrReplace(s, "\\", "\")
        return s
    }

    static LastPathSegment(path) {
        seg := path
        Loop {
            p := InStr(seg, "\")
            if (!p)
                break
            seg := SubStr(seg, p + 1)
        }
        return seg
    }

    static ParentFolderName(path) {
        path := FileClassifier.NormalizePath(path)
        if (path = "")
            return ""
        path := RTrim(path, "\")
        p := InStr(path, "\", , -1)
        if (!p)
            return ""
        parent := SubStr(path, 1, p - 1)
        return FileClassifier.LastPathSegment(parent)
    }

    static FullWordMatchLastSegment(path, Keyword) {
        if (StrLen(Keyword) < 1)
            return false
        return StrLower(FileClassifier.LastPathSegment(path)) = StrLower(Keyword)
    }

    static CountBackslashes(path) {
        if (path = "")
            return 0
        n := 0
        Loop StrLen(path) {
            if (SubStr(path, A_Index, 1) = "\")
                n++
        }
        return n
    }

    ; 路径极浅：反斜杠数量 <=2（如 X:\chrome、X:\Program Files\chrome），用于 Folder 轻罚例外
    static IsVeryShallowPath(path) {
        return FileClassifier.CountBackslashes(path) <= 2
    }

    ; 垃圾/噪声路径（除非用户显式搜这些词）
    static IsJunkPath(path) {
        pl := StrLower(FileClassifier.NormalizePath(path))
        if (pl = "")
            return false
        junk := [
            "\appdata\", "\application data\", "\cache\", "\caches\", "\temp\", "\tmp\",
            "\node_modules\", "\.git\objects\", "\winsxs\", "\inetcache\", "\cookies\",
            "\crashpad\", "\crash_report\", "\indexeddb\", "\leveldb\", "\gpu_cache\",
            "\code cache\", "\service worker\", "\pwa_launcher\", "\appcrash",
            "\wer\", "\programdata\microsoft\windows\wer\", "\microsoft\windows\inetcache\",
            "\roaming\mozilla\", "\local\google\chrome\user data\", "\local\microsoft\edge\user data\"
        ]
        for m in junk {
            if (InStr(pl, m))
                return true
        }
        if (RegExMatch(pl, "i)appcrash[_\\]"))
            return true
        return false
    }

    ; 用户关键词显式指向 AppData/cache/temp 等时，不叠加垃圾分
    static IsJunkPathKeyword(Keyword) {
        if (StrLen(Trim(Keyword)) < 1)
            return false
        k := StrLower(Trim(Keyword))
        for w in ["appdata", "cache", "temp", "tmp", "node_modules", "winsxs", "inetcache", "user data", "crash", "indexeddb", "leveldb", "gpu_cache", "programdata", "wer"] {
            if (k = w)
                return true
        }
        return false
    }

    ; User Data / DevResource 额外罚分豁免：显式路径/依赖关键词（避免短串误伤，如 digital 含 git）
    static IsSubCategoryExemptKeyword(Keyword) {
        if (FileClassifier.IsJunkPathKeyword(Keyword))
            return true
        if (StrLen(Trim(Keyword)) < 1)
            return false
        k := StrLower(Trim(Keyword))
        for w in ["node_modules", "vendor", "appdata", "gradle", "cargo", "nuget", "packages", "modules", "venv", "system32", "winsxs", "programdata", "roaming", "mozilla", "firefox", "user data", "application data"] {
            if (StrLen(w) >= 5 && InStr(k, w))
                return true
        }
        for w in ["git", "pkg", "m2", "nuget"] {
            if (k = w)
                return true
        }
        return false
    }

    static ParentDirKey(path) {
        path := FileClassifier.NormalizePath(path)
        path := RTrim(path, "\")
        p := InStr(path, "\", , -1)
        if (!p)
            return ""
        return StrLower(SubStr(path, 1, p - 1))
    }

    static InferSubCategory(path) {
        pl := StrLower(FileClassifier.NormalizePath(path))
        if (pl = "")
            return ""
        if (InStr(pl, "\node_modules\") || InStr(pl, "\vendor\") || InStr(pl, "\.git\")
            || InStr(pl, "\packages\") || InStr(pl, "\venv\") || InStr(pl, "\.venv\")
            || InStr(pl, "\dist\") || InStr(pl, "\build\") || InStr(pl, "\.cargo\")
            || InStr(pl, "\go\pkg\") || InStr(pl, "\.gradle\") || InStr(pl, "\.m2\"))
            return "DevResource"
        if (InStr(pl, "\appdata\") || InStr(pl, "\application data\") || InStr(pl, "\user data\")
            || RegExMatch(pl, "i)\\users\\[^\\]+\\appdata\\"))
            return "User Data"
        if (InStr(pl, "\windows\") || InStr(pl, "\program files\windows\")
            || InStr(pl, "\windows\system32\") || InStr(pl, "\windows\syswow64\")
            || InStr(pl, "\windows\winsxs\") || InStr(pl, "\programdata\microsoft\windows\"))
            return "System"
        return ""
    }

    static FolderIconEmoji(isDir, category, subCat) {
        if (!isDir)
            return ""
        if (subCat = "User Data")
            return "👤"
        if (subCat = "DevResource")
            return "📦"
        if (subCat = "System")
            return "⚙️"
        if (category = "Project")
            return "📂"
        if (category = "SystemTemp")
            return "⚙️"
        return "📁"
    }

    static BuildDisplaySubtitle(parentName) {
        if (parentName != "")
            return parentName . " ›"
        return ""
    }

    static IsSystemOrTempPath(path) {
        pl := StrLower(FileClassifier.NormalizePath(path))
        if (pl = "")
            return false
        if (InStr(pl, "\appdata\local\temp\") || InStr(pl, "\appdata\local\microsoft\windows\inetcache")
            || InStr(pl, "\windows\temp\") || InStr(pl, "\$recycle.bin\") || InStr(pl, "\windows\winsxs\")
            || InStr(pl, "\windows\system32\") || InStr(pl, "\windows\syswow64\")
            || InStr(pl, "\windows\installer\") || InStr(pl, "\windows\prefetch\")
            || InStr(pl, "\appdata\local\packages\") && InStr(pl, "\tempstate\"))
            return true
        return false
    }

    static IsProjectFolder(path, lastSegLower) {
        norm := StrLower(FileClassifier.NormalizePath(path))
        if FileClassifier.cacheProjectDir.Has(norm)
            return FileClassifier.cacheProjectDir[norm]

        isProj := false
        if (lastSegLower = ".git" || lastSegLower = ".project")
            isProj := true
        else if (DirExist(path . "\.git") || FileExist(path . "\.git")
            || DirExist(path . "\.project") || FileExist(path . "\.project"))
            isProj := true

        FileClassifier.cacheProjectDir[norm] := isProj
        return isProj
    }

    static AssocQueryOne(assocStr, pszAssoc) {
        pcch := 0
        hr := DllCall("shlwapi\AssocQueryStringW", "UInt", FileClassifier.ASSOCF_INIT_DEFAULTTOSTAR,
            "UInt", assocStr, "WStr", pszAssoc, "Ptr", 0, "Ptr", 0, "UInt*", &pcch, "Int")
        if (hr != 0 || pcch < 1)
            return ""
        buf := Buffer(pcch * 2)
        hr := DllCall("shlwapi\AssocQueryStringW", "UInt", FileClassifier.ASSOCF_INIT_DEFAULTTOSTAR,
            "UInt", assocStr, "WStr", pszAssoc, "Ptr", 0, "Ptr", buf.Ptr, "UInt*", &pcch, "Int")
        if (hr != 0)
            return ""
        return StrGet(buf.Ptr, pcch, "UTF-16")
    }

    static GetAssocBundleForExt(extWithDot) {
        key := StrLower(extWithDot)
        if (key = "")
            key := "."
        if FileClassifier.ExtensionCache.Has(key)
            return FileClassifier.ExtensionCache[key]

        psz := (SubStr(key, 1, 1) = ".") ? key : ("." . key)
        if (psz = ".")
            psz := "."

        bundle := Map(
            "FriendlyDocName", "",
            "PerceivedType", "",
            "OpenCommand", "",
            "Executable", ""
        )
        try {
            bundle["FriendlyDocName"] := FileClassifier.AssocQueryOne(FileClassifier.ASSOCSTR_FRIENDLYDOCNAME, psz)
            bundle["PerceivedType"] := StrLower(Trim(FileClassifier.AssocQueryOne(FileClassifier.ASSOCSTR_PERCEIVEDTYPE, psz)))
            bundle["OpenCommand"] := FileClassifier.AssocQueryOne(FileClassifier.ASSOCSTR_COMMAND, psz)
            bundle["Executable"] := FileClassifier.AssocQueryOne(FileClassifier.ASSOCSTR_EXECUTABLE, psz)
        } catch {
        }
        FileClassifier.ExtensionCache[key] := bundle
        return bundle
    }

    static GetFileDescriptionFromPath(filePath) {
        if (filePath = "" || !FileExist(filePath))
            return ""
        norm := StrLower(FileClassifier.NormalizePath(filePath))
        if FileClassifier.cacheExeDesc.Has(norm)
            return FileClassifier.cacheExeDesc[norm]

        desc := ""
        size := DllCall("version\GetFileVersionInfoSizeW", "WStr", filePath, "Ptr", 0, "UInt")
        if (!size) {
            FileClassifier.cacheExeDesc[norm] := ""
            return ""
        }
        data := Buffer(size)
        if (!DllCall("version\GetFileVersionInfoW", "WStr", filePath, "UInt", 0, "UInt", size, "Ptr", data.Ptr)) {
            FileClassifier.cacheExeDesc[norm] := ""
            return ""
        }

        pTrans := 0
        lenTrans := 0
        if (DllCall("version\VerQueryValueW", "Ptr", data.Ptr, "WStr", "\VarFileInfo\Translation", "Ptr*", &pTrans, "UInt*", &lenTrans)
            && lenTrans >= 4 && pTrans) {
            lang := Format("{:04X}{:04X}", NumGet(pTrans, 0, "UShort"), NumGet(pTrans, 2, "UShort"))
            subBlock := "\StringFileInfo\" . lang . "\FileDescription"
            strBuf := 0
            strLen := 0
            if (DllCall("version\VerQueryValueW", "Ptr", data.Ptr, "WStr", subBlock, "Ptr*", &strBuf, "UInt*", &strLen) && strBuf && strLen > 0)
                desc := StrGet(strBuf, -1, "UTF-16")
        }
        if (desc = "")
            desc := FileClassifier.TryFirstFileDescription(data)
        FileClassifier.cacheExeDesc[norm] := desc
        return desc
    }

    static TryFirstFileDescription(data) {
        for lang in ["040904B0", "040904E4", "000004B0", "080404B0"] {
            subBlock := "\StringFileInfo\" . lang . "\FileDescription"
            strBuf := 0
            strLen := 0
            if (DllCall("version\VerQueryValueW", "Ptr", data.Ptr, "WStr", subBlock, "Ptr*", &strBuf, "UInt*", &strLen) && strBuf && strLen > 0) {
                s := StrGet(strBuf, -1, "UTF-16")
                if (s != "")
                    return s
            }
        }
        return ""
    }

    static GetLnkResolvedDisplay(lnkPath) {
        norm := StrLower(FileClassifier.NormalizePath(lnkPath))
        if FileClassifier.cacheLnk.Has(norm)
            return FileClassifier.cacheLnk[norm]

        info := { displayTitle: "", targetPath: "" }
        try {
            shell := ComObject("WScript.Shell")
            sc := shell.CreateShortcut(lnkPath)
            tgt := sc.TargetPath ? String(sc.TargetPath) : ""
            info.targetPath := tgt
            if (tgt != "" && FileExist(tgt)) {
                SplitPath(tgt, , , &tExt)
                tExt := StrLower(tExt)
                if (tExt = "exe") {
                    d := FileClassifier.GetFileDescriptionFromPath(tgt)
                    if (d != "")
                        info.displayTitle := d
                }
            }
        } catch {
        }
        FileClassifier.cacheLnk[norm] := info
        return info
    }

    static IsScriptLike(extLower, bundle, friendlyLower) {
        if FileClassifier.SCRIPT_EXTS.Has(extLower)
            return true
        if (InStr(friendlyLower, "script") || InStr(friendlyLower, "脚本"))
            return true
        oc := bundle.Has("OpenCommand") ? bundle["OpenCommand"] : ""
        ex := bundle.Has("Executable") ? bundle["Executable"] : ""
        ocL := StrLower(oc), exL := StrLower(ex)
        if (InStr(exL, "autohotkey") || InStr(ocL, "autohotkey"))
            return true
        if (InStr(exL, "powershell") || InStr(ocL, "powershell"))
            return true
        if (InStr(exL, "cmd.exe") || InStr(exL, "cscript") || InStr(exL, "wscript"))
            return true
        return false
    }

    static IsMediaExt(extLower, perceived) {
        if FileClassifier.MEDIA_EXT.Has(extLower)
            return true
        if (perceived = "video" || perceived = "audio" || perceived = "image")
            return true
        return false
    }

    static GetCategoryColor(Category) {
        static colors := Map(
            "App", "2ECC71",
            "Project", "9B59B6",
            "Config", "F39C12",
            "Archive", "95A5A6",
            "SystemTemp", "7F8C8D",
            "Script", "1ABC9C",
            "Media", "3498DB",
            "Document", "BDC3C7",
            "Folder", "E67E22",
            "Hidden", "34495E"
        )
        return colors.Has(Category) ? colors[Category] : "BDC3C7"
    }

    static GetCategoryDisplayName(Category) {
        static names := Map(
            "App", "应用程序",
            "Project", "项目",
            "Config", "配置文件",
            "Archive", "压缩包",
            "SystemTemp", "系统/临时",
            "Script", "脚本",
            "Media", "媒体",
            "Document", "文档",
            "Folder", "文件夹",
            "Hidden", "折叠"
        )
        return names.Has(Category) ? names[Category] : Category
    }

    static BuildTitleMarkers(attrStr) {
        if (attrStr = "")
            return ""
        prefix := ""
        if (InStr(attrStr, "R") && !InStr(attrStr, "D"))
            prefix .= "‹ "
        if (InStr(attrStr, "S") || InStr(attrStr, "H"))
            prefix .= "· "
        return prefix
    }

    static BuildDisplayPath(parentName, fileName) {
        if (parentName != "")
            return parentName . " › " . fileName
        return fileName
    }

    static ResolveItemPath(Item) {
        path := ""
        try {
            if (Item.HasProp("Preview") && Item.Preview != "")
                path := Item.Preview
            else if (Item.HasProp("Content") && Item.Content != "")
                path := Item.Content
            else if (Item.HasProp("Metadata") && IsObject(Item.Metadata) && Item.Metadata.Has("FilePath"))
                path := Item.Metadata["FilePath"]
        } catch {
        }
        return FileClassifier.NormalizePath(path)
    }

    static ComputeTotalPathBonus(category, path, Keyword, subCategory) {
        fullMatch := FileClassifier.FullWordMatchLastSegment(path, Keyword)
        bonus := 0.0
        switch category {
            case "App":
                bonus += FileClassifier.BONUS_APP
            case "Project":
                bonus += FileClassifier.BONUS_PROJECT
            case "Config":
                bonus += FileClassifier.BONUS_CONFIG
            case "Archive":
                bonus += FileClassifier.PENALTY_ARCHIVE
            case "SystemTemp":
                bonus += fullMatch ? 0.0 : FileClassifier.PENALTY_SYSTEMTEMP
            case "Folder":
                if (fullMatch && FileClassifier.IsVeryShallowPath(path))
                    bonus += FileClassifier.PENALTY_FOLDER_SHALLOW
                else
                    bonus += FileClassifier.PENALTY_FOLDER
            default:
        }
        slashCount := FileClassifier.CountBackslashes(path)
        if (slashCount > 3)
            bonus -= (slashCount - 3) * 5.0
        junkOn := FileClassifier.IsJunkPath(path) && !FileClassifier.IsJunkPathKeyword(Keyword)
        if (junkOn)
            bonus += FileClassifier.PENALTY_JUNK_PATH
        if (junkOn && (subCategory = "User Data" || subCategory = "DevResource") && !FileClassifier.IsSubCategoryExemptKeyword(Keyword))
            bonus += FileClassifier.PENALTY_SUB_USER_OR_DEV
        return bonus
    }

    static ClassifyOne(path, bundle, extLower, fileName, nameNoExt, isDir, Keyword) {
        subCat := FileClassifier.InferSubCategory(path)
        friendly := bundle.Has("FriendlyDocName") ? bundle["FriendlyDocName"] : ""
        friendlyL := StrLower(friendly)
        perc := bundle.Has("PerceivedType") ? bundle["PerceivedType"] : ""

        category := "Document"
        displayTitle := ""
        typeHint := ""
        displayPath := ""
        titleMarker := ""

        baseName := fileName != "" ? fileName : (nameNoExt != "" ? nameNoExt : FileClassifier.LastPathSegment(path))
        parentName := FileClassifier.ParentFolderName(path)
        displaySubtitle := FileClassifier.BuildDisplaySubtitle(parentName)
        lastSeg := StrLower(FileClassifier.LastPathSegment(path))

        if FileClassifier.IsSystemOrTempPath(path) {
            category := "SystemTemp"
            typeHint := "系统或临时路径"
            displayPath := FileClassifier.BuildDisplayPath(parentName, baseName)
            if (isDir)
                displayTitle := FileClassifier.FolderIconEmoji(true, "SystemTemp", subCat) . baseName
            else
                displayTitle := baseName
        } else if (isDir) {
            if FileClassifier.IsProjectFolder(path, lastSeg) {
                category := "Project"
                typeHint := "项目/仓库"
                displayTitle := FileClassifier.FolderIconEmoji(true, "Project", subCat) . baseName
                displayPath := displayTitle
            } else {
                category := "Folder"
                typeHint := "文件夹"
                displayTitle := FileClassifier.FolderIconEmoji(true, "Folder", subCat) . baseName
                displayPath := displayTitle
            }
        } else if FileClassifier.CONFIG_EXTS.Has(extLower) {
            category := "Config"
            typeHint := friendly != "" ? friendly : "配置"
            displayPath := FileClassifier.BuildDisplayPath(parentName, baseName)
            displayTitle := baseName
        } else if FileClassifier.ARCHIVE_EXTS.Has(extLower) {
            category := "Archive"
            typeHint := friendly != "" ? friendly : "压缩包"
            displayPath := FileClassifier.BuildDisplayPath(parentName, baseName)
            displayTitle := baseName
        } else if (extLower = ".exe" || extLower = ".msi" || extLower = ".com" || extLower = ".scr") {
            category := "App"
            displayTitle := FileClassifier.GetFileDescriptionFromPath(path)
            if (displayTitle = "")
                displayTitle := nameNoExt != "" ? nameNoExt : baseName
            typeHint := friendly != "" ? friendly : "应用程序"
            displayPath := ""
        } else if (extLower = ".lnk") {
            lnk := FileClassifier.GetLnkResolvedDisplay(path)
            if (lnk.displayTitle != "") {
                category := "App"
                displayTitle := lnk.displayTitle
            } else {
                displayTitle := nameNoExt != "" ? nameNoExt : baseName
                category := "Document"
            }
            typeHint := friendly != "" ? friendly : "快捷方式"
            displayPath := ""
        } else if FileClassifier.IsScriptLike(extLower, bundle, friendlyL) {
            category := "Script"
            typeHint := friendly != "" ? friendly : "脚本"
            displayPath := FileClassifier.BuildDisplayPath(parentName, baseName)
            displayTitle := baseName
        } else if FileClassifier.IsMediaExt(extLower, perc) {
            category := "Media"
            typeHint := friendly != "" ? (friendly . (perc != "" ? " (" . perc . ")" : "")) : perc
            displayPath := FileClassifier.BuildDisplayPath(parentName, baseName)
            displayTitle := baseName
        } else if (perc = "application" && (extLower = ".dll" || extLower = ".cpl")) {
            category := "App"
            displayTitle := friendly != "" ? friendly : (nameNoExt != "" ? nameNoExt : baseName)
            typeHint := friendly
            displayPath := ""
        } else {
            displayTitle := baseName
            typeHint := friendly != "" ? (friendly . (perc != "" ? " (" . perc . ")" : "")) : perc
            displayPath := FileClassifier.BuildDisplayPath(parentName, baseName)
        }

        if (typeHint = "" && friendly != "")
            typeHint := friendly
        if (typeHint = "" && perc != "")
            typeHint := perc

        if (category = "Folder" || category = "Project" || (category = "SystemTemp" && isDir)) {
            if (titleMarker != "")
                displayTitle := titleMarker . displayTitle
        } else if (category = "App") {
            displayTitle := titleMarker . displayTitle
        } else {
            displayTitle := titleMarker . displayTitle
        }

        bonus := FileClassifier.ComputeTotalPathBonus(category, path, Keyword, subCat)

        return {
            Category: category,
            SubCategory: subCat,
            DisplayTitle: displayTitle,
            DisplaySubtitle: displaySubtitle,
            DisplayPath: displayPath,
            TypeHint: typeHint,
            TitleMarker: titleMarker,
            FzyCategoryBonus: bonus,
            CategoryColor: FileClassifier.GetCategoryColor(category)
        }
    }

    static ApplyParentDirectoryCollapse(&ResultsArray) {
        buckets := Map()
        for Item in ResultsArray {
            if (!IsObject(Item))
                continue
            path := FileClassifier.ResolveItemPath(Item)
            pk := FileClassifier.ParentDirKey(path)
            if (pk = "")
                continue
            if !buckets.Has(pk)
                buckets[pk] := []
            buckets[pk].Push(Item)
        }
        for pk, items in buckets {
            if (items.Length <= 5)
                continue
            Loop items.Length {
                if (A_Index > 5) {
                    it := items[A_Index]
                    try {
                        it.Category := "Hidden"
                        ex := 0.0
                        if (it.HasProp("FzyCategoryBonus"))
                            ex := it.FzyCategoryBonus
                        it.FzyCategoryBonus := ex + FileClassifier.PENALTY_PARENT_OVERFLOW
                        it.CategoryColor := FileClassifier.GetCategoryColor("Hidden")
                        if (it.HasProp("Metadata") && IsObject(it.Metadata))
                            it.Metadata["Category"] := "Hidden"
                    } catch {
                    }
                }
            }
        }
    }

    static ProcessResults(&ResultsArray, Keyword) {
        if (ResultsArray.Length = 0)
            return
        kw := Trim(Keyword)
        FileClassifier._polishQueue := []
        for Item in ResultsArray {
            if (!IsObject(Item))
                continue
            path := FileClassifier.ResolveItemPath(Item)
            if (path = "")
                continue

            isDir := false
            ext := ""
            nameNoExt := ""
            fileName := ""
            try {
                if (Item.HasProp("Metadata") && IsObject(Item.Metadata)) {
                    if (Item.Metadata.Has("IsDirectory"))
                        isDir := Item.Metadata["IsDirectory"] ? true : false
                    if (Item.Metadata.Has("Ext"))
                        ext := Item.Metadata["Ext"]
                }
            } catch {
            }
            SplitPath(path, &fileName, , &ExtFromPath, &nameNoExt)
            if (ext = "")
                ext := ExtFromPath
            extLower := StrLower((SubStr(ext, 1, 1) = ".") ? ext : ("." . ext))
            if (extLower = ".")
                extLower := ""

            if (!isDir)
                isDir := DirExist(path) ? true : false

            bundle := FileClassifier.GetAssocBundleForExt(extLower != "" ? extLower : ".")
            tag := FileClassifier.ClassifyOne(path, bundle, extLower, fileName, nameNoExt, isDir, kw)

            Item.DisplayTitle := tag.DisplayTitle
            Item.DisplaySubtitle := tag.DisplaySubtitle
            Item.DisplayPath := tag.DisplayPath
            Item.Category := tag.Category
            Item.SubCategory := tag.SubCategory
            Item.TypeHint := tag.TypeHint
            Item.TitleMarker := tag.TitleMarker
            Item.FzyCategoryBonus := tag.FzyCategoryBonus
            Item.CategoryColor := tag.CategoryColor

            try {
                if (Item.HasProp("Metadata") && IsObject(Item.Metadata)) {
                    Item.Metadata["Category"] := tag.Category
                    Item.Metadata["SubCategory"] := tag.SubCategory
                    Item.Metadata["TypeHint"] := tag.TypeHint
                    Item.Metadata["DisplayPath"] := tag.DisplayPath
                    Item.Metadata["DisplaySubtitle"] := tag.DisplaySubtitle
                    Item.Metadata["CategoryColor"] := tag.CategoryColor
                }
            } catch {
            }

            if (!isDir && FileExist(path))
                FileClassifier._polishQueue.Push(Item)
        }

        ; 父目录折叠在「最终排序之后」由调用方调用 ApplyParentDirectoryCollapse，避免顺序与 Hidden 不一致
        FileClassifier._ScheduleAttribPolish()
    }

    static _ScheduleAttribPolish() {
        if (FileClassifier._polishQueue.Length = 0)
            return
        if (FileClassifier._polishTimer)
            SetTimer(FileClassifier._polishTimer, 0)
        FileClassifier._polishTimer := (*) => FileClassifier._RunAttribPolishTick()
        SetTimer(FileClassifier._polishTimer, -15)
    }

    static _RunAttribPolishTick() {
        batch := 24
        Loop Min(batch, FileClassifier._polishQueue.Length) {
            Item := FileClassifier._polishQueue.RemoveAt(1)
            if (!IsObject(Item))
                continue
            path := FileClassifier.ResolveItemPath(Item)
            if (path = "" || !FileExist(path))
                continue
            try {
                attr := FileGetAttrib(path)
                marker := FileClassifier.BuildTitleMarkers(attr)
                if (marker = "")
                    continue
                Item.TitleMarker := marker
                if (Item.HasProp("Category") && Item.Category != "App") {
                    core := Item.HasProp("DisplayTitle") ? Item.DisplayTitle : ""
                    if (core != "" && (marker = "" || InStr(core, marker) != 1))
                        Item.DisplayTitle := marker . core
                } else if (Item.HasProp("Category") && Item.Category = "App") {
                    core := Item.DisplayTitle
                    if (marker != "" && InStr(core, marker) != 1)
                        Item.DisplayTitle := marker . core
                }
            } catch {
            }
        }
        if (FileClassifier._polishQueue.Length > 0)
            SetTimer(FileClassifier._polishTimer, -15)
        else {
            FileClassifier._polishTimer := 0
            try RefreshSearchCenterResults()
        }
    }

    static FlushAttribPolish() {
        Loop FileClassifier._polishQueue.Length
            FileClassifier._RunAttribPolishTick()
    }
}
