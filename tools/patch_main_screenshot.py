# -*- coding: utf-8 -*-
"""Remove screenshot monolith from main; insert #Include + shims."""
from pathlib import Path

ROOT = Path(r"c:\Users\Administrator\Desktop\小c")
MAIN = ROOT / "CursorHelper (1).ahk"

# 1-based inclusive line numbers (current file before edit)
HOT_START, HOT_END = 9072, 9150
CHUNK_START, CHUNK_END = 19338, 22549

SHIM = r'''
; ===================== 截图助手（ScreenshotEditorPlugin 类模块）=====================
#Include modules\ScreenshotEditorPlugin.ahk

ShowScreenshotEditor(DebugGui := 0) {
    ScreenshotEditorPlugin.ShowScreenshotEditor(DebugGui)
}
CloseScreenshotEditor(*) {
    ScreenshotEditorPlugin.CloseScreenshotEditor()
}
CloseAllScreenshotWindows(*) {
    ScreenshotEditorPlugin.CloseAllScreenshotWindows()
}
IsScreenshotEditorActive() {
    return ScreenshotEditorPlugin.IsScreenshotEditorActive()
}
HandleScreenshotEditorHotkey(ActionType) {
    return ScreenshotEditorPlugin.HandleScreenshotEditorHotkey(ActionType)
}
IsScreenshotEditorZoomHotkeyActive() {
    return ScreenshotEditorPlugin_IsZoomHotkeyActive()
}
ToggleScreenshotEditorAlwaysOnTop(*) {
    ScreenshotEditorPlugin.ToggleScreenshotEditorAlwaysOnTop()
}
ScreenshotEditorSendToAI(*) {
    ScreenshotEditorPlugin.ScreenshotEditorSendToAI()
}
ScreenshotEditorSearchText(*) {
    ScreenshotEditorPlugin.ScreenshotEditorSearchText()
}
ExecuteScreenshotOCR(*) {
    ScreenshotEditorPlugin.ExecuteScreenshotOCR()
}
PasteScreenshotAsText(*) {
    ScreenshotEditorPlugin.PasteScreenshotAsText()
}
SaveScreenshotToFile(closeAfter := true) {
    ScreenshotEditorPlugin.SaveScreenshotToFile(closeAfter)
}
CopyScreenshotToClipboard(closeAfter := true) {
    ScreenshotEditorPlugin.CopyScreenshotToClipboard(closeAfter)
}
UpdateScreenshotEditorPreview(*) {
    ScreenshotEditorPlugin.UpdateScreenshotEditorPreview()
}
SyncScreenshotToolbarPosition(*) {
    ScreenshotEditorPlugin.SyncScreenshotToolbarPosition()
}
OnScreenshotEditorContextMenu(Ctrl, Info := 0, *) {
    ScreenshotEditorPlugin.OnScreenshotEditorContextMenu(Ctrl, Info)
}

'''


def main() -> None:
    lines = MAIN.read_text(encoding="utf-8").splitlines(keepends=True)
    drop = set()
    for i in range(HOT_START - 1, HOT_END):
        drop.add(i)
    for i in range(CHUNK_START - 1, CHUNK_END):
        drop.add(i)
    removed_before_chunk = sum(1 for i in drop if i < CHUNK_START - 1)
    insert_at = (CHUNK_START - 1) - removed_before_chunk
    new_lines = [ln for i, ln in enumerate(lines) if i not in drop]
    new_lines.insert(insert_at, SHIM)
    MAIN.write_text("".join(new_lines), encoding="utf-8")
    print("Patched: removed hotkeys", HOT_START, "-", HOT_END, "chunk", CHUNK_START, "-", CHUNK_END, "; insert at", insert_at + 1)


if __name__ == "__main__":
    main()
