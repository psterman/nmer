# Warning: This local variable appears to never be a
_Exported on 01/05/2026 at 08:10:55 GMT+8 from Cursor via WayLog_


**User**

Warning: This local variable appears to never be assigned a value.

Specifically: SetAutoStart

	2433: VoiceSearchEnabledCategories := ["ai", "academic", "baidu", "image", "audio", "video", "book", "price", "medical", "cloud"]
	2434: }
▶	2437: SetAutoStart(AutoStart)Warning: This local variable appears to never be assigned a value.

Specifically: GlobalSearchEngine

	3729: global_ST := 0
	3730: }
▶	3733: GlobalSearchEngine.ReleaseOldStatement()Warning: This local variable appears to never be assigned a value.

Specifically: StopDynamicHotkeys

	4358: PanelVisible := 0
	4361: LastCursorPanelButton := 0
▶	4364: StopDynamicHotkeys()Warning: This local variable appears to never be assigned a value.

Specifically: ExportConfig

	11171: ExportBtn := ConfigGUI.Add("Text", "x" . BtnStartX . " y" . YPos . " w" . BtnWidth . " h" . BtnHeight . " Center 0x200 c" . TextColor . " Background" . UI_Colors.BtnBg . " vAdvancedExportBtn", GetText("export_config"))
	11172: ExportBtn.SetFont("s10", "Segoe UI")
▶	11173: ExportBtn.OnEvent("Click", ExportConfig)Warning: This local variable appears to never be assigned a value.

Specifically: ImportConfig

	11178: ImportBtn := ConfigGUI.Add("Text", "x" . (BtnStartX + BtnWidth + BtnSpacing) . " y" . YPos . " w" . BtnWidth . " h" . BtnHeight . " Center 0x200 c" . TextColor . " Background" . UI_Colors.BtnBg . " vAdvancedImportBtn", GetText("import_config"))
	11179: ImportBtn.SetFont("s10", "Segoe UI")
▶	11180: ImportBtn.OnEvent("Click", ImportConfig)Warning: This global variable appears to never be assigned a value.

Specifically: OnClipboardListViewWMNotify

	13066: OnMessage(0x0134, WM_CTLCOLORLISTBOX)
	13068: OnMessage(0x0133, WM_CTLCOLOREDIT)
▶	13070: OnMessage(0x004E, OnClipboardListViewWMNotify)Warning: This global variable appears to never be assigned a value.

Specifically: ClipboardListBoxHwnd

	13079: Try
	13079: {
▶	13081: If (ClipboardListBoxHwnd != 0 && lParam = ClipboardListBoxHwnd && ClipboardListBoxBrush != 0)
Warning: This global variable appears to never be assigned a value.

Specifically: ClipboardListBoxBrush

	13079: Try
	13079: {
▶	13081: If (ClipboardListBoxHwnd != 0 && lParam = ClipboardListBoxHwnd && ClipboardListBoxBrush != 0)
	Warning: This local variable appears to never be assigned a value.

Specifically: SetAutoStart

	15082: IniWrite("ai,academic,baidu,image,audio,video,book,price,medical,cloud", ConfigFile, "Settings", "VoiceSearchEnabledCategories")
	15083: }
▶	15086: SetAutoStart(AutoStart)

---


**Cursor**

检查代码以确认这些变量/函数是否缺失定义。先查看主 AutoHotkey 文件：

---
