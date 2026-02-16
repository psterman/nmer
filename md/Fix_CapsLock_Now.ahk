; ======================================================================================================================
; CapsLock 立即修复脚本
; 解决：进入 CapsLock+F 后仍是大写状态
; ======================================================================================================================

#Requires AutoHotkey v2.0
#SingleInstance Force

MainScript := A_ScriptDir "\CursorHelper (1).ahk"
BackupScript := A_ScriptDir "\CursorHelper (1).ahk.backup." A_Now

if (!FileExist(MainScript)) {
    MsgBox("找不到 CursorHelper (1).ahk", "错误", "Iconx")
    ExitApp()
}

; 读取文件
try {
    content := FileRead(MainScript)
} catch as err {
    MsgBox("读取文件失败: " err.Message, "错误", "Iconx")
    ExitApp()
}

; 备份
try {
    FileCopy(MainScript, BackupScript, true)
} catch as err {
    MsgBox("备份失败: " err.Message, "错误", "Iconx")
    ExitApp()
}

; ========== 修复1：在开头添加 SetCapsLockState("AlwaysOff") ==========
if (!InStr(content, "SetCapsLockState(""AlwaysOff"")")) {
    ; 查找插入位置（SendMode("Input") 之后）
    if (InStr(content, "SendMode(""Input"")")) {
        oldText := "SendMode(""Input"")"
        newText := "SendMode(""Input"")`n`n; 【修复】完全禁用 CapsLock 大写功能`n#InstallKeybdHook`nSetCapsLockState(""AlwaysOff"")`nLoop 5 {`n    SetCapsLockState(""AlwaysOff"")`n    Sleep(50)`n}"
        content := StrReplace(content, oldText, newText)
    }
}

; ========== 修复2：将 ~CapsLock:: 改为 CapsLock:: ==========
content := StrReplace(content, "~CapsLock::", "CapsLock::")

; ========== 修复3：在 f:: 热键中添加强制关闭 ==========
; 找到 f:: 热键并修改
oldFKey := "f:: {`n    global IsCountdownActive`n    ; 如果倒计时正在进行"
newFKey := "f:: {`n    global IsCountdownActive`n    ; 【修复】强制关闭 CapsLock`n    SetCapsLockState(""AlwaysOff"")`n    `n    ; 如果倒计时正在进行"
content := StrReplace(content, oldFKey, newFKey)

; 在 f:: 热键结尾添加关闭
oldFEnd := "        ShowSearchCenter()`n    }`n}`n`n; G 键激活语音搜索面板"
newFEnd := "        ShowSearchCenter()`n    }`n    ; 【修复】执行后强制关闭 CapsLock`n    SetCapsLockState(""AlwaysOff"")`n}`n`n; G 键激活语音搜索面板"
content := StrReplace(content, oldFEnd, newFEnd)

; ========== 修复4：在 ShowSearchCenter 开头添加 ==========
oldShowSearch := "ShowSearchCenter() {`n    global GuiID_SearchCenter, UI_Colors, ThemeMode"
newShowSearch := "ShowSearchCenter() {`n    ; 【修复】强制关闭 CapsLock`n    SetCapsLockState(""AlwaysOff"")`n    `n    global GuiID_SearchCenter, UI_Colors, ThemeMode"
content := StrReplace(content, oldShowSearch, newShowSearch)

; 保存文件
try {
    FileDelete(MainScript)
    FileAppend(content, MainScript, "UTF-8")
} catch as err {
    MsgBox("保存失败: " err.Message "`n尝试恢复备份...", "错误", "Iconx")
    FileCopy(BackupScript, MainScript, true)
    ExitApp()
}

MsgBox("修复完成！`n`n请：\n1. 完全退出脚本\n2. 重新启动\n3. 测试 CapsLock+F", "修复完成", "Iconi")
ExitApp()
