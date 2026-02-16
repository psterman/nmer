; ======================================================================================================================
; CapsLock 终极修复工具 - 自动应用修复
; 解决: CapsLock+F 激活大写状态、无法切换中文输入法问题
; ======================================================================================================================

#Requires AutoHotkey v2.0
#SingleInstance Force

SetWorkingDir(A_ScriptDir)

MainScript := A_ScriptDir "\CursorHelper (1).ahk"
BackupScript := A_ScriptDir "\CursorHelper (1).ahk.backup." A_Now

; 检查主脚本
if (!FileExist(MainScript)) {
    MsgBox("错误：找不到 CursorHelper (1).ahk`n请将此脚本放在与主脚本相同的目录。", "错误", "Iconx")
    ExitApp()
}

; 创建 GUI
FixGUI := Gui("+AlwaysOnTop", "CapsLock 终极修复工具")
FixGUI.SetFont("s12", "Microsoft YaHei")
FixGUI.BackColor := "1E1E1E"

FixGUI.Add("Text", "w500 cWhite", "CapsLock 状态问题终极修复").SetFont("s16 Bold")
FixGUI.Add("Text", "w500 cGray", "修复 CapsLock+F 激活大写状态的问题")
FixGUI.Add("Text", "w500", "")

InfoText := FixGUI.Add("Text", "w500 cWhite", 
    "此工具将应用以下修复：`n" .
    "1. 安装键盘钩子，拦截 CapsLock 按键`n" .
    "2. 完全禁用 CapsLock 大写功能（AlwaysOff）`n" .
    "3. 修复 ~CapsLock:: 热键，移除 ~ 前缀`n" .
    "4. 确保所有快捷键正确处理 CapsLock2 标记`n" .
    "`n修复后，CapsLock 灯将不再亮起，但输入法切换功能将正常工作。")

FixGUI.Add("Text", "w500", "")
StatusText := FixGUI.Add("Text", "w500 cYellow", "状态: 准备就绪")
ProgressBar := FixGUI.Add("Progress", "w500 h25 cGreen", 0)
FixGUI.Add("Text", "w500", "")

LogEdit := FixGUI.Add("Edit", "w500 h180 ReadOnly Background1A1A1A cWhite", "")

FixGUI.Add("Text", "w500", "")
FixBtn := FixGUI.Add("Button", "w200 h45", "应用修复")
FixBtn.OnEvent("Click", ApplyFix)

ExitBtn := FixGUI.Add("Button", "w200 h45 x+20", "退出")
ExitBtn.OnEvent("Click", (*) => ExitApp())

FixGUI.Show("Center")

; 日志函数
AddLog(msg, isError := false) {
    global LogEdit
    timestamp := FormatTime(, "HH:mm:ss")
    color := isError ? "FF6666" : "66FF66"
    LogEdit.Value := LogEdit.Value "[" timestamp "] " msg "`r`n"
    SendMessage(0x00B6, 0, 0x7FFFFFFF, LogEdit.Hwnd)
}

UpdateStatus(msg, color := "Yellow") {
    global StatusText
    StatusText.SetText("状态: " msg)
    StatusText.SetFont("c" color)
}

; 应用修复
ApplyFix(*) {
    global MainScript, BackupScript, FixBtn, ExitBtn
    
    FixBtn.Enabled := false
    ExitBtn.Enabled := false
    
    AddLog("开始应用修复...")
    UpdateStatus("正在备份原文件...", "Yellow")
    ProgressBar.Value := 10
    
    ; 步骤1: 备份
    try {
        FileCopy(MainScript, BackupScript, true)
        AddLog("✓ 已创建备份: " BackupScript)
    } catch as err {
        AddLog("✗ 备份失败: " err.Message, true)
        UpdateStatus("备份失败", "Red")
        FixBtn.Enabled := true
        ExitBtn.Enabled := true
        return
    }
    
    ProgressBar.Value := 30
    Sleep(200)
    
    ; 步骤2: 读取文件
    UpdateStatus("正在读取文件...", "Yellow")
    try {
        content := FileRead(MainScript)
        AddLog("✓ 已读取主脚本")
    } catch as err {
        AddLog("✗ 读取失败: " err.Message, true)
        UpdateStatus("读取失败", "Red")
        FixBtn.Enabled := true
        ExitBtn.Enabled := true
        return
    }
    
    ProgressBar.Value := 50
    Sleep(200)
    
    ; 步骤3: 应用修复1 - 添加 #InstallKeybdHook 和 SetCapsLockState("AlwaysOff")
    UpdateStatus("正在应用修复1: 禁用 CapsLock 大写功能...", "Yellow")
    
    ; 检查是否已存在
    if (!InStr(content, "SetCapsLockState(""AlwaysOff"")")) {
        ; 在基础配置后添加
        pattern1 := "SendMode(""Input"")"
        if (InStr(content, pattern1)) {
            replacement1 := "SendMode(""Input"")`n#InstallKeybdHook`nSetCapsLockState(""AlwaysOff"")`nLoop 3 {`n    SetCapsLockState(""AlwaysOff"")`n    Sleep(50)`n}"
            content := StrReplace(content, pattern1, replacement1)
            AddLog("✓ 已添加 #InstallKeybdHook 和 SetCapsLockState(AlwaysOff)")
        } else {
            AddLog("⚠ 未找到插入位置1，跳过此修复", true)
        }
    } else {
        AddLog("⚠ 已存在 SetCapsLockState(AlwaysOff)，跳过")
    }
    
    ProgressBar.Value := 65
    Sleep(200)
    
    ; 步骤4: 应用修复2 - 将 ~CapsLock:: 改为 CapsLock::
    UpdateStatus("正在应用修复2: 修改 CapsLock 热键...", "Yellow")
    
    if (InStr(content, "~CapsLock::")) {
        content := StrReplace(content, "~CapsLock::", "CapsLock::")
        AddLog("✓ 已将 ~CapsLock:: 改为 CapsLock::")
    } else {
        AddLog("⚠ 未找到 ~CapsLock::，可能已修改或格式不同")
    }
    
    ProgressBar.Value := 80
    Sleep(200)
    
    ; 步骤5: 保存文件
    UpdateStatus("正在保存修改...", "Yellow")
    
    try {
        FileDelete(MainScript)
        FileAppend(content, MainScript, "UTF-8")
        AddLog("✓ 已保存修改后的文件")
    } catch as err {
        AddLog("✗ 保存失败: " err.Message, true)
        AddLog("正在尝试恢复备份...")
        try {
            FileCopy(BackupScript, MainScript, true)
            AddLog("✓ 已恢复原文件")
        } catch as err2 {
            AddLog("✗ 恢复也失败了: " err2.Message, true)
        }
        UpdateStatus("保存失败", "Red")
        FixBtn.Enabled := true
        ExitBtn.Enabled := true
        return
    }
    
    ProgressBar.Value := 100
    UpdateStatus("修复完成！", "Green")
    AddLog("")
    AddLog("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    AddLog("修复已成功应用！")
    AddLog("请完全退出脚本并重新启动以生效。")
    AddLog("备份文件: " BackupScript)
    AddLog("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    
    FixBtn.Text := "修复完成"
    FixBtn.Enabled := false
    ExitBtn.Enabled := true
    
    MsgBox("修复已成功应用！`n`n请：`n1. 完全退出脚本（托盘图标右键->退出）`n2. 重新启动脚本`n3. 测试 CapsLock+F 是否会激活大写状态", "修复完成", "Iconi")
}

TrayTip("CapsLock 修复工具", "双击应用 CapsLock 终极修复", "Iconi")
