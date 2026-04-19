# -*- coding: utf-8 -*-
from pathlib import Path

ROOT = Path(r"c:\Users\Administrator\Desktop\小c")
MAIN = ROOT / "CursorHelper (1).ahk"
OUT = ROOT / "modules" / "ScreenshotWorkflow.ahk"

START, END = 12422, 14628  # 1-based inclusive

HEADER = """; ScreenshotWorkflow.ahk — 截图业务流程（智能菜单、区域截图、悬浮按钮等，由主脚本 #Include）
; 依赖：ShowScreenshotEditor、CloseScreenshotEditor、DeferredScreenshotHistorySave、GetScreenInfo、
; UI_Colors、ThemeMode、FloatingToolbar、HideCursorPanel、ImagePut/OCR、GetText 等。

"""

# Remove duplicate globals (kept in hub): GuiID_ClipboardSmartMenu + ScreenshotOldClipboard block after section title
STRIP_PREFIX = """; ===================== 截图后智能处理菜单 =====================
; 全局变量
global GuiID_ClipboardSmartMenu := 0  ; 智能菜单 GUI ID
global ScreenshotOldClipboard := ""  ; 保存截图前的剪贴板内容

"""


def main() -> None:
    lines = MAIN.read_text(encoding="utf-8").splitlines(keepends=True)
    chunk = "".join(lines[START - 1 : END])
    if not chunk.startswith("; ===================== 截图后智能处理菜单"):
        raise SystemExit("Unexpected chunk start")
    chunk = chunk.replace(STRIP_PREFIX, "; ===================== 截图后智能处理菜单 =====================\n", 1)
    OUT.write_text(HEADER + chunk, encoding="utf-8")

    drop = set(range(START - 1, END))
    new_lines = [ln for i, ln in enumerate(lines) if i not in drop]
    text = "".join(new_lines)

    marker = "OnScreenshotEditorContextMenu(Ctrl, Info := 0, *) {"
    idx = text.find(marker)
    if idx < 0:
        raise SystemExit("OnScreenshotEditorContextMenu not found")
    # find closing brace of that function — search for "}\n\n; ===================== 面板快捷键" after shims
    ins = text.find("; ===================== 面板快捷键 =====================")
    if ins < 0:
        raise SystemExit("面板快捷键 marker not found")
    # insert before 面板快捷键 section
    inc = '\n; ===================== 截图业务流程（智能菜单 / 区域截图 / 悬浮按钮）=====================\n#Include modules\\ScreenshotWorkflow.ahk\n\n'
    if "ScreenshotWorkflow.ahk" not in text:
        text = text[:ins] + inc + text[ins:]

    # Add ScreenshotOldClipboard global after ScreenshotClipboard
    old_clip = "global ScreenshotClipboard := \"\"  ; 保存的截图剪贴板内容\n"
    add = old_clip + "global ScreenshotOldClipboard := \"\"  ; 截图流程保存的剪贴板快照\n"
    if old_clip in text and "ScreenshotOldClipboard" not in text[: text.find("global CursorPath")]:
        text = text.replace(old_clip, add, 1)

    MAIN.write_text(text, encoding="utf-8")
    print("Wrote", OUT)


if __name__ == "__main__":
    main()
