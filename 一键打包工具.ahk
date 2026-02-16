#Requires AutoHotkey v2.0
#SingleInstance Force

; ================== 配置区域 ==================
SourceFile := "CursorHelper (1).ahk"   ; 你的主脚本文件名
TargetName := "CursorHelper.exe"       ; 生成的程序名
IconFile := "favicon.ico"              ; 图标文件名
BuildDir := A_ScriptDir "\CursorHelper_发布版"
Ahk2ExePath := "C:\Program Files\AutoHotkey\Compiler\Ahk2Exe.exe" ; 编译器默认路径
; =============================================

if !FileExist(SourceFile) {
    MsgBox "找不到源文件: " SourceFile, "错误", "Iconx"
    ExitApp
}

; 1. 创建发布文件夹
if DirExist(BuildDir)
    DirDelete(BuildDir, 1)
DirCreate(BuildDir)

; 2. 编译 EXE
MsgBox "正在编译，请稍候...", "打包中", "Iconi T2"
RunWait(Format('"{1}" /in "{2}\{3}" /out "{4}\{5}" /icon "{2}\{6}"', Ahk2ExePath, A_ScriptDir, SourceFile, BuildDir, TargetName, IconFile))

; 3. 复制必需的依赖项
if DirExist("lib") {
    DirCreate(BuildDir "\lib")
    DirCopy("lib", BuildDir "\lib", 1)
}

if FileExist(IconFile)
    FileCopy(IconFile, BuildDir "\" IconFile, 1)

; 4. 完成提示
MsgBox "打包完成！`n`n请将文件夹：`n[" BuildDir "]`n压缩后发送给用户即可。`n用户解压后运行 " TargetName " 即可使用。", "成功", "Iconi"
Run("explore " BuildDir)