; ======================================================================================================================
; CapsLock 中文切换问题自动修复工具
; 功能: 自动修改 CursorHelper (1).ahk 文件，修复 CapsLock 无法切换中文的问题
; 使用方法: 双击运行此脚本，它会自动备份并修改主脚本
; ======================================================================================================================

#Requires AutoHotkey v2.0
#SingleInstance Force

; 设置工作目录为脚本所在目录
SetWorkingDir(A_ScriptDir)

; 主脚本路径
MainScript := A_ScriptDir "\CursorHelper (1).ahk"
BackupScript := A_ScriptDir "\CursorHelper (1).ahk.backup"

; 检查主脚本是否存在
if (!FileExist(MainScript)) {
    MsgBox("错误：找不到主脚本文件 `CursorHelper (1).ahk`"""""`n`n请确保此脚本放在与主脚本相同的目录中。", "修复失败", "Iconx")
    ExitApp()
}

; 创建 GUI
FixGUI := Gui("+AlwaysOnTop", "CapsLock 中文切换修复工具")
FixGUI.SetFont("s11", "Microsoft YaHei")

FixGUI.Add("Text", "w500", "CapsLock 中文切换问题自动修复").SetFont("s14 Bold")
FixGUI.Add("Text", "w500", "")
FixGUI.Add("Text", "w500", "此工具将自动修复以下问题：")
FixGUI.Add("Text", "w500", "  • 启动软件后单击 CapsLock 无法切换到中文").SetFont("s10")
FixGUI.Add("Text", "w500", "  • 必须长按 CapsLock 才能切换输入法").SetFont("s10")
FixGUI.Add("Text", "w500", "  • CapsLock 状态混乱导致输入法切换失效").SetFont("s10")
FixGUI.Add("Text", "w500", "")

StatusText := FixGUI.Add("Text", "w500 cBlue", "状态: 准备就绪")
ProgressBar := FixGUI.Add("Progress", "w500 h20 cBlue vFixProgress", 0)

FixGUI.Add("Text", "w500", "")
LogEdit := FixGUI.Add("Edit", "w500 h150 ReadOnly vLogText", "")

FixGUI.Add("Text", "w500", "")
FixBtn := FixGUI.Add("Button", "w150 h40", "开始修复")
FixBtn.OnEvent("Click", StartFix)

ExitBtn := FixGUI.Add("Button", "w150 h40 x+10", "退出")
ExitBtn.OnEvent("Click", (*) => ExitApp())

FixGUI.Show("Center")

; 日志函数
AddLog(msg) {
    global LogEdit
    timestamp := FormatTime(, "HH:mm:ss")
    LogEdit.Value := LogEdit.Value "[" timestamp "] " msg "`r`n"
    ; 滚动到底部
    SendMessage(0x00B6, 0, 0x7FFFFFFF, LogEdit.Hwnd)  ; WM_VSCROLL, SB_BOTTOM
}

; 更新状态
UpdateStatus(msg, color := "Blue") {
    global StatusText
    StatusText.SetText("状态: " msg)
    StatusText.SetFont("c" color)
}

; 更新进度
UpdateProgress(value) {
    global ProgressBar
    ProgressBar.Value := value
}

; 开始修复
StartFix(*) {
    global MainScript, BackupScript, FixBtn, ExitBtn
    
    FixBtn.Enabled := false
    ExitBtn.Enabled := false
    
    AddLog("开始修复过程...")
    UpdateStatus("正在备份原文件...", "Blue")
    UpdateProgress(10)
    
    ; 步骤1: 备份原文件
    try {
        FileCopy(MainScript, BackupScript, true)
        AddLog("✓ 已创建备份: CursorHelper (1).ahk.backup")
    } catch as err {
        AddLog("✗ 备份失败: " err.Message)
        UpdateStatus("备份失败", "Red")
        FixBtn.Enabled := true
        ExitBtn.Enabled := true
        return
    }
    
    UpdateStatus("正在读取原文件...", "Blue")
    UpdateProgress(20)
    Sleep(200)
    
    ; 步骤2: 读取文件内容
    try {
        fileContent := FileRead(MainScript)
        AddLog("✓ 已读取主脚本文件")
    } catch as err {
        AddLog("✗ 读取文件失败: " err.Message)
        UpdateStatus("读取失败", "Red")
        FixBtn.Enabled := true
        ExitBtn.Enabled := true
        return
    }
    
    UpdateStatus("正在应用修复...", "Blue")
    UpdateProgress(40)
    Sleep(200)
    
    ; 步骤3: 检查是否已经修复过
    if (InStr(fileContent, "【修复】启动时强制重置 CapsLock 状态")) {
        AddLog("⚠ 似乎已经修复过了")
        result := MsgBox("检测到可能已经修复过。`n`n是否重新应用修复？", "确认", "YesNo Icon?")
        if (result = "No") {
            UpdateStatus("已取消", "Gray")
            FixBtn.Enabled := true
            ExitBtn.Enabled := true
            return
        }
    }
    
    ; 步骤4: 应用修复1 - 添加启动时重置代码
    AddLog("应用修复 1: 添加启动时 CapsLock 重置...")
    
    ; 查找插入位置（基础配置之后）
    insertPattern := "TraySetIcon(""favicon.ico"
    if (InStr(fileContent, insertPattern)) {
        insertPos := InStr(fileContent, insertPattern)
        ; 找到这一行的末尾
        lineEnd := InStr(fileContent, "`n", insertPos)
        if (lineEnd > 0) {
            ; 插入重置代码
            resetCode := "`n`n; 【修复】启动时强制重置 CapsLock 状态`nLoop 3 {`n    SetCapsLockState(""Off"")`n    Sleep(50)`n}"
            
            fileContent := SubStr(fileContent, 1, lineEnd) . resetCode . SubStr(fileContent, lineEnd + 1)
            AddLog("✓ 已添加启动重置代码")
        }
    } else {
        AddLog("⚠ 未找到合适的插入位置（修复1），跳过")
    }
    
    UpdateProgress(60)
    Sleep(200)
    
    ; 步骤5: 应用修复2 - 修改 ~CapsLock:: 为 CapsLock::
    AddLog("应用修复 2: 修改 CapsLock 热键...")
    
    if (InStr(fileContent, "~CapsLock::")) {
        fileContent := StrReplace(fileContent, "~CapsLock::", "CapsLock::")
        AddLog("✓ 已移除 ~ 前缀")
    } else {
        AddLog("⚠ 未找到 ~CapsLock::，可能已修复或格式不同")
    }
    
    UpdateProgress(70)
    Sleep(200)
    
    ; 步骤6: 应用修复3 - 修改状态切换逻辑
    AddLog("应用修复 3: 修改状态切换逻辑...")
    
    ; 查找并替换状态切换代码
    oldPattern := "} else {`n    ; 没有使用功能，切换状态（短按 CapsLock 的正常行为）`n    SetCapsLockState(!InitialCapsLockState)`n    CapsLock := false`n}"
    
    newPattern := "} else {`n    ; 【修复】没有使用功能，切换状态`n    SetCapsLockState(""Off"")`n    Sleep(10)`n    if (InitialCapsLockState) {`n        SetCapsLockState(""Off"")`n    } else {`n        SetCapsLockState(""On"")`n    }`n    CapsLock := false`n}"
    
    if (InStr(fileContent, "SetCapsLockState(!InitialCapsLockState)")) {
        fileContent := StrReplace(fileContent, "SetCapsLockState(!InitialCapsLockState)", 
            "SetCapsLockState(\"Off\")`n    Sleep(10)`n    if (InitialCapsLockState) {`n        SetCapsLockState(\"Off\")`n    } else {`n        SetCapsLockState(\"On\")`n    }")
        AddLog("✓ 已修改状态切换逻辑")
    } else {
        AddLog("⚠ 未找到状态切换代码，可能已修复或格式不同")
    }
    
    UpdateProgress(80)
    Sleep(200)
    
    ; 步骤7: 保存修改后的文件
    UpdateStatus("正在保存修改...", "Blue")
    
    try {
        ; 删除原文件
        FileDelete(MainScript)
        ; 写入新内容
        FileAppend(fileContent, MainScript, "UTF-8")
        AddLog("✓ 已保存修改后的文件")
    } catch as err {
        AddLog("✗ 保存文件失败: " err.Message)
        AddLog("正在尝试恢复备份...")
        try {
            FileCopy(BackupScript, MainScript, true)
            AddLog("✓ 已恢复原文件")
        } catch as err2 {
            AddLog("✗ 恢复备份也失败了: " err2.Message)
            AddLog("请手动从 .backup 文件恢复")
        }
        UpdateStatus("保存失败", "Red")
        FixBtn.Enabled := true
        ExitBtn.Enabled := true
        return
    }
    
    UpdateProgress(100)
    UpdateStatus("修复完成！", "Green")
    AddLog("")
    AddLog("========================================")
    AddLog("修复已成功应用！")
    AddLog("请完全退出脚本并重新启动以生效。")
    AddLog("备份文件: CursorHelper (1).ahk.backup")
    AddLog("========================================")
    
    FixBtn.Text := "修复完成"
    ExitBtn.Enabled := true
    
    MsgBox("修复已成功应用！`n`n请：\n1. 完全退出脚本（托盘图标右键->退出）\n2. 重新启动脚本\n3. 测试单击 CapsLock 是否可以切换中文输入法", "修复完成", "Iconi")
}

; 托盘提示
TrayTip("CapsLock 修复工具", "双击开始修复 CapsLock 中文切换问题", "Iconi")
