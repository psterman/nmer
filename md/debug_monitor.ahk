#Requires AutoHotkey v2.0
try {
    FileDelete("monitor_debug.txt")
}

Count := MonitorGetCount()
FileAppend("MonitorGetCount: " . Count . "`n", "monitor_debug.txt")

Loop Count {
    try {
        MonitorGet(A_Index, &L, &T, &R, &B)
        FileAppend("Monitor " . A_Index . ": L" . L . " T" . T . " R" . R . " B" . B . "`n", "monitor_debug.txt")
    } catch as e {
        FileAppend("Monitor " . A_Index . " error: " . e.Message . "`n", "monitor_debug.txt")
    }
}

try {
    CountSys := SysGet(80) 
    FileAppend("SysGet(80): " . CountSys . "`n", "monitor_debug.txt")
} catch as e {
    FileAppend("SysGet error: " . e.Message . "`n", "monitor_debug.txt")
}

FileAppend("A_ScreenDPI: " . A_ScreenDPI . "`n", "monitor_debug.txt")
ExitApp
