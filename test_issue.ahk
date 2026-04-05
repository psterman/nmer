#Requires AutoHotkey v2.0
#Include "%A_ScriptDir%\lib\Gdip_All.ahk"
#Include "%A_ScriptDir%\lib\ImagePut.ahk"
#Include "%A_ScriptDir%\lib\DBA.ahk"
#Include "%A_ScriptDir%\lib\SQLite.ahk"
#Include "%A_ScriptDir%\modules\ClipboardFTS5.ahk"
#Include "%A_ScriptDir%\modules\AppDetect.ahk"

global ClipboardFTS5DB
dbPath := A_ScriptDir . "\Clipboard.db"
ClipboardFTS5DB := DBA.DataBaseFactory.OpenDataBase("SQLite", dbPath)

ClipboardFTS5_InitializeDB()

testImg := A_ScriptDir . "\banner.jpg"
ftsOk := CaptureImageFileToFTS5(testImg, "TestApp")
FileAppend("CaptureImageFileToFTS5: " . (ftsOk ? "OK" : "FAIL") . "`n", "*")

ftsOk2 := SaveToClipboardFTS5("https://example.com/test.jpg", "TestApp")
FileAppend("SaveToClipboardFTS5 (URL): " . (ftsOk2 ? "OK" : "FAIL") . "`n", "*")
