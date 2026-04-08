; Cursor native-shortcut mapping layer for VK KeyBinder
; Source of truth:
; - config/cursor_command_catalog.json
; - config/user_keymap.json
; Compiled artifact:
; - Data/vk_cursor_keymap_compiled.json

global g_CSM_CatalogPath := A_ScriptDir "\config\cursor_command_catalog.json"
global g_CSM_UserKeymapPath := A_ScriptDir "\config\user_keymap.json"
global g_CSM_CompiledPath := A_ScriptDir "\Data\vk_cursor_keymap_compiled.json"

CursorShortcutMapper_EnsureFiles() {
    global g_CSM_CatalogPath, g_CSM_UserKeymapPath
    if !FileExist(g_CSM_CatalogPath) {
        _CSM_EnsureParentDir(g_CSM_CatalogPath)
        catalog := _CSM_DefaultCatalogJson()
        FileAppend(catalog, g_CSM_CatalogPath, "UTF-8")
    }
    if !FileExist(g_CSM_UserKeymapPath) {
        _CSM_EnsureParentDir(g_CSM_UserKeymapPath)
        userMap := _CSM_DefaultUserKeymapJson()
        FileAppend(userMap, g_CSM_UserKeymapPath, "UTF-8")
    }
}

CursorShortcutMapper_LoadCatalog() {
    global g_CSM_CatalogPath
    CursorShortcutMapper_EnsureFiles()
    data := _CSM_LoadJson(g_CSM_CatalogPath)
    return (data is Array) ? data : []
}

CursorShortcutMapper_LoadUserKeymap() {
    global g_CSM_UserKeymapPath
    CursorShortcutMapper_EnsureFiles()
    data := _CSM_LoadJson(g_CSM_UserKeymapPath)
    return (data is Array) ? data : []
}

CursorShortcutMapper_SaveUserKeymap(entries) {
    global g_CSM_UserKeymapPath
    _CSM_EnsureParentDir(g_CSM_UserKeymapPath)
    json := Jxon_Dump(entries)
    try FileDelete(g_CSM_UserKeymapPath)
    FileAppend(json, g_CSM_UserKeymapPath, "UTF-8")
}

CursorShortcutMapper_SyncUserKeymapToCommands(commandsObj) {
    if !(commandsObj is Map)
        return false
    if !commandsObj.Has("Bindings") || !(commandsObj["Bindings"] is Map)
        commandsObj["Bindings"] := Map()

    catalog := CursorShortcutMapper_LoadCatalog()
    userMap := CursorShortcutMapper_LoadUserKeymap()
    byId := _CSM_IndexUserMapById(userMap)
    changed := false
    overrides := Map()

    for item in catalog {
        if !(item is Map)
            continue
        commandId := item.Has("id") ? item["id"] : ""
        vkCommandId := item.Has("vkCommandId") ? item["vkCommandId"] : ""
        if (commandId = "" || vkCommandId = "")
            continue

        entry := byId.Has(commandId) ? byId[commandId] : 0
        if !(entry is Map) {
            entry := Map(
                "commandId", commandId,
                "userShortcut", "",
                "enabled", false,
                "keepNative", true
            )
            userMap.Push(entry)
            byId[commandId] := entry
            changed := true
        }

        if (_CSM_IsEmptyShortcut(entry.Get("userShortcut", ""))
            && commandsObj["Bindings"].Has(vkCommandId)
            && commandsObj["Bindings"][vkCommandId] != "NONE") {
            entry["userShortcut"] := commandsObj["Bindings"][vkCommandId]
            entry["enabled"] := true
            if !entry.Has("keepNative")
                entry["keepNative"] := true
            changed := true
        }

        if _CSM_IsEnabledEntry(entry) {
            key := Trim(entry.Get("userShortcut", ""))
            if (key != "")
                overrides[vkCommandId] := key
        }
    }

    validation := CursorShortcutMapper_ValidateUserKeymap(catalog, userMap)
    if !validation["ok"] {
        for err in validation["errors"]
            OutputDebug("[CSM] validation error: " . err)
        if changed
            CursorShortcutMapper_SaveUserKeymap(userMap)
        return false
    }

    for vkCommandId, userShortcut in overrides
        commandsObj["Bindings"][vkCommandId] := userShortcut

    if changed
        CursorShortcutMapper_SaveUserKeymap(userMap)

    CursorShortcutMapper_CompileAndPersist()
    return true
}

CursorShortcutMapper_GetNativeShortcutByVkCommand(vkCommandId, fallback := "") {
    if (vkCommandId = "")
        return fallback
    catalog := CursorShortcutMapper_LoadCatalog()
    for item in catalog {
        if !(item is Map)
            continue
        if item.Get("vkCommandId", "") = vkCommandId {
            nativeShortcut := item.Get("nativeShortcut", "")
            return (nativeShortcut != "") ? nativeShortcut : fallback
        }
    }
    return fallback
}

CursorShortcutMapper_IsCursorVkCommand(vkCommandId) {
    if (vkCommandId = "")
        return false
    catalog := CursorShortcutMapper_LoadCatalog()
    for item in catalog {
        if !(item is Map)
            continue
        if (item.Get("vkCommandId", "") = vkCommandId)
            return true
    }
    return false
}

CursorShortcutMapper_UpdateUserByVkCommand(vkCommandId, userShortcut := "", enabled := true, keepNative := true) {
    if (vkCommandId = "")
        return false
    catalog := CursorShortcutMapper_LoadCatalog()
    targetCommandId := ""
    for item in catalog {
        if (item is Map && item.Get("vkCommandId", "") = vkCommandId) {
            targetCommandId := item.Get("id", "")
            break
        }
    }
    if (targetCommandId = "")
        return false

    userMap := CursorShortcutMapper_LoadUserKeymap()
    entry := 0
    for row in userMap {
        if (row is Map && row.Get("commandId", "") = targetCommandId) {
            entry := row
            break
        }
    }
    if !(entry is Map) {
        entry := Map(
            "commandId", targetCommandId,
            "userShortcut", "",
            "enabled", false,
            "keepNative", true
        )
        userMap.Push(entry)
    }

    entry["userShortcut"] := userShortcut
    entry["enabled"] := enabled
    entry["keepNative"] := keepNative
    if !entry.Has("scopeOverride")
        entry["scopeOverride"] := ""

    validation := CursorShortcutMapper_ValidateUserKeymap(catalog, userMap)
    if !validation["ok"] {
        for err in validation["errors"]
            OutputDebug("[CSM] update blocked: " . err)
        return false
    }

    CursorShortcutMapper_SaveUserKeymap(userMap)
    CursorShortcutMapper_CompileAndPersist()
    return true
}

CursorShortcutMapper_ResetAllUserShortcuts() {
    userMap := CursorShortcutMapper_LoadUserKeymap()
    for row in userMap {
        if !(row is Map)
            continue
        row["enabled"] := false
        row["userShortcut"] := ""
        if !row.Has("keepNative")
            row["keepNative"] := true
    }
    CursorShortcutMapper_SaveUserKeymap(userMap)
    CursorShortcutMapper_CompileAndPersist()
}

CursorShortcutMapper_ValidateUserKeymap(catalog, userMap) {
    result := Map("ok", true, "errors", [], "warnings", [])
    if !(catalog is Array)
        catalog := []
    if !(userMap is Array)
        userMap := []

    validCommands := Map()
    for item in catalog {
        if (item is Map) {
            id := item.Get("id", "")
            if (id != "")
                validCommands[id] := true
        }
    }

    usedByShortcut := Map()
    blacklist := _CSM_BlacklistMap()
    for row in userMap {
        if !(row is Map)
            continue
        commandId := row.Get("commandId", "")
        if (commandId = "")
            continue
        if !validCommands.Has(commandId) {
            result["ok"] := false
            result["errors"].Push("Unknown commandId in user_keymap: " . commandId)
            continue
        }
        if !_CSM_IsEnabledEntry(row)
            continue

        raw := Trim(row.Get("userShortcut", ""))
        if (raw = "") {
            result["ok"] := false
            result["errors"].Push("Enabled entry missing userShortcut: " . commandId)
            continue
        }
        normalized := _CSM_NormalizeShortcut(raw)
        if blacklist.Has(normalized) {
            result["ok"] := false
            result["errors"].Push("Shortcut blocked by blacklist: " . raw . " (" . commandId . ")")
            continue
        }
        if usedByShortcut.Has(normalized) {
            result["ok"] := false
            result["errors"].Push("Shortcut conflict: " . raw . " used by " . usedByShortcut[normalized] . " and " . commandId)
            continue
        }
        usedByShortcut[normalized] := commandId
    }
    return result
}

CursorShortcutMapper_CompileAndPersist() {
    global g_CSM_CompiledPath
    catalog := CursorShortcutMapper_LoadCatalog()
    userMap := CursorShortcutMapper_LoadUserKeymap()
    validation := CursorShortcutMapper_ValidateUserKeymap(catalog, userMap)
    if !validation["ok"] {
        for err in validation["errors"]
            OutputDebug("[CSM] compile blocked: " . err)
        return validation
    }

    byId := _CSM_IndexUserMapById(userMap)
    rules := []
    for item in catalog {
        if !(item is Map)
            continue
        cmdId := item.Get("id", "")
        if (cmdId = "" || !byId.Has(cmdId))
            continue
        entry := byId[cmdId]
        if !_CSM_IsEnabledEntry(entry)
            continue
        trigger := Trim(entry.Get("userShortcut", ""))
        if (trigger = "")
            continue

        rule := Map(
            "commandId", cmdId,
            "label", item.Get("label", cmdId),
            "vkCommandId", item.Get("vkCommandId", ""),
            "trigger", trigger,
            "targetNative", item.Get("nativeShortcut", ""),
            "sendSequence", item.Get("sendSequence", Map()),
            "scope", Map("process", "Cursor.exe"),
            "keepNative", entry.Get("keepNative", true)
        )
        rules.Push(rule)
    }

    payload := Map(
        "version", "1.0",
        "generatedAt", A_NowUTC,
        "rules", rules
    )
    _CSM_EnsureParentDir(g_CSM_CompiledPath)
    try FileDelete(g_CSM_CompiledPath)
    FileAppend(Jxon_Dump(payload), g_CSM_CompiledPath, "UTF-8")
    return Map("ok", true, "errors", [], "warnings", [], "ruleCount", rules.Length)
}

_CSM_LoadJson(path) {
    if !FileExist(path)
        return Map()
    raw := ""
    try raw := FileRead(path, "UTF-8")
    if (raw = "")
        return Map()
    try return Jxon_Load(raw)
    return Map()
}

_CSM_EnsureParentDir(path) {
    SplitPath(path, , &dir)
    if (dir != "" && !DirExist(dir))
        DirCreate(dir)
}

_CSM_IndexUserMapById(userMap) {
    byId := Map()
    if !(userMap is Array)
        return byId
    for row in userMap {
        if (row is Map && row.Has("commandId"))
            byId[row["commandId"]] := row
    }
    return byId
}

_CSM_IsEnabledEntry(entry) {
    if !(entry is Map)
        return false
    enabled := entry.Get("enabled", false)
    return !!enabled
}

_CSM_IsEmptyShortcut(hk) {
    return Trim(hk) = ""
}

_CSM_NormalizeShortcut(hk) {
    s := StrLower(Trim(hk))
    s := StrReplace(s, " ", "")
    return s
}

_CSM_BlacklistMap() {
    ; Common system / IME hotkeys that are risky to steal.
    return Map(
        "#l", true,         ; lock workstation
        "#d", true,         ; show desktop
        "!tab", true,       ; app switch
        "^esc", true,       ; start menu
        "^+esc", true,      ; task manager
        "^!delete", true,   ; secure attention sequence
        "^space", true,     ; ime switch (common)
        "!shift", true      ; ime switch (common)
    )
}

_CSM_DefaultCatalogJson() {
    return "
(
[
{"id":"showCommands","label":"Command Palette","vkCommandId":"qa_command_palette","nativeShortcut":"^+p","sendSequence":{"down":["Ctrl","Shift","P"],"up":["P","Shift","Ctrl"]},"scope":"cursor_only"},
{"id":"toggleTerminal","label":"Terminal","vkCommandId":"qa_terminal","nativeShortcut":"^+``","sendSequence":{"down":["Ctrl","Shift","Backquote"],"up":["Backquote","Shift","Ctrl"]},"scope":"cursor_only"},
{"id":"globalSearch","label":"Global Search","vkCommandId":"qa_global_search","nativeShortcut":"^+f","sendSequence":{"down":["Ctrl","Shift","F"],"up":["F","Shift","Ctrl"]},"scope":"cursor_only"},
{"id":"explorer","label":"Explorer","vkCommandId":"qa_explorer","nativeShortcut":"^+e","sendSequence":{"down":["Ctrl","Shift","E"],"up":["E","Shift","Ctrl"]},"scope":"cursor_only"},
{"id":"sourceControl","label":"Source Control","vkCommandId":"qa_source_control","nativeShortcut":"^+g","sendSequence":{"down":["Ctrl","Shift","G"],"up":["G","Shift","Ctrl"]},"scope":"cursor_only"},
{"id":"extensions","label":"Extensions","vkCommandId":"qa_extensions","nativeShortcut":"^+x","sendSequence":{"down":["Ctrl","Shift","X"],"up":["X","Shift","Ctrl"]},"scope":"cursor_only"},
{"id":"simpleBrowser","label":"Browser","vkCommandId":"qa_browser","nativeShortcut":"^+b","sendSequence":{"down":["Ctrl","Shift","B"],"up":["B","Shift","Ctrl"]},"scope":"cursor_only"},
{"id":"vscodeSettings","label":"VS Code Settings","vkCommandId":"qa_settings","nativeShortcut":"^+j","sendSequence":{"down":["Ctrl","Shift","J"],"up":["J","Shift","Ctrl"]},"scope":"cursor_only"},
{"id":"cursorSettings","label":"Cursor Settings","vkCommandId":"qa_cursor_settings","nativeShortcut":"^,","sendSequence":{"down":["Ctrl","Comma"],"up":["Comma","Ctrl"]},"scope":"cursor_only"}
]
)"
}

_CSM_DefaultUserKeymapJson() {
    return "
(
[
{"commandId":"showCommands","userShortcut":"","enabled":false,"keepNative":true,"scopeOverride":""},
{"commandId":"toggleTerminal","userShortcut":"","enabled":false,"keepNative":true,"scopeOverride":""},
{"commandId":"globalSearch","userShortcut":"","enabled":false,"keepNative":true,"scopeOverride":""},
{"commandId":"explorer","userShortcut":"","enabled":false,"keepNative":true,"scopeOverride":""},
{"commandId":"sourceControl","userShortcut":"","enabled":false,"keepNative":true,"scopeOverride":""},
{"commandId":"extensions","userShortcut":"","enabled":false,"keepNative":true,"scopeOverride":""},
{"commandId":"simpleBrowser","userShortcut":"","enabled":false,"keepNative":true,"scopeOverride":""},
{"commandId":"vscodeSettings","userShortcut":"","enabled":false,"keepNative":true,"scopeOverride":""},
{"commandId":"cursorSettings","userShortcut":"","enabled":false,"keepNative":true,"scopeOverride":""}
]
)"
}
