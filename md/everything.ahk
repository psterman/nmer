#Requires AutoHotkey v2.0
#SingleInstance Force

; ================= 诊断脚本 =================
Global evDll := "lib\everything64.dll" ; 请确保这里路径正确！

if !FileExist(evDll) {
    MsgBox "错误：找不到 " evDll
    ExitApp
}

; 1. 加载 DLL
hModule := DllCall("LoadLibrary", "Str", evDll, "Ptr")
if !hModule {
    MsgBox "致命错误：DLL 加载失败！"
    ExitApp
}

; 2. 检查版本和 IPC 状态
ver := DllCall(evDll "\Everything_GetMajorVersion", "UInt")
if (ver == 0) {
    err := DllCall(evDll "\Everything_GetLastError", "UInt")
    MsgBox "连接失败！Everything 可能未运行。错误码: " err "`n(2=IPC错误, 说明无法通信)"
    ExitApp
}
MsgBox "连接成功！Detected Everything Version: " ver

; 3. 检查数据库是否加载完毕
isLoaded := DllCall(evDll "\Everything_IsDBLoaded", "Int")
if (!isLoaded) {
    MsgBox "警告：Everything 数据库正在构建中，无法搜索。"
    ExitApp
}

; 4. 执行一次标准搜索
Keyword := "windows" ; 搜一个肯定有的词
DllCall(evDll "\Everything_CleanUp")
DllCall(evDll "\Everything_SetSearchW", "WStr", Keyword)
DllCall(evDll "\Everything_SetRequestFlags", "UInt", 0x00000004) ; FULL_PATH_AND_FILE_NAME
DllCall(evDll "\Everything_SetMax", "UInt", 10)

; 执行查询
success := DllCall(evDll "\Everything_QueryW", "Int", 1) ; 1 = 等待
if (!success) {
    MsgBox "查询指令发送失败！"
    ExitApp
}

; 5. 获取结果
count := DllCall(evDll "\Everything_GetNumResults", "UInt")
if (count == 0) {
    MsgBox "查询成功，但结果数为 0。`n请检查 Everything 客户端里搜 '" Keyword "' 是否有结果。"
} else {
    buf := Buffer(1024)
    DllCall(evDll "\Everything_GetResultFullPathNameW", "UInt", 0, "Ptr", buf.Ptr, "UInt", 512)
    FirstPath := StrGet(buf.Ptr, "UTF-16")
    MsgBox "诊断通过！成功获取数据！`n`n搜到了 " count " 条。`n第一条路径: " FirstPath
}