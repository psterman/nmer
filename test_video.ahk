
#Requires AutoHotkey v2.0
#Include lib/WebView2.ahk
global MyGui := Gui("+Resize")
global wv := WebView2.create(MyGui.Hwnd)
wv.SetVirtualHostNameToFolderMapping("c.local", "C:\", 1)
html := "<html><body style=""margin:0;background:#000;""><video controls autoplay width=""100%"" height=""100%""><source src=""https://c.local/Users/Administrator/Desktop/test.mp4""></video></body></html>"
wv.NavigateToString(html)
MyGui.Show("w800 h600")
Sleep(5000)
ExitApp()

