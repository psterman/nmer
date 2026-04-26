# -*- coding: utf-8 -*-
"""Generate modules/ScreenshotEditorPlugin.ahk — static class + file-level #HotIf."""
import re
from pathlib import Path

ROOT = Path(r"c:\Users\Administrator\Desktop\小c")
MAIN = ROOT / "CursorHelper (1).ahk"
OUT = ROOT / "modules" / "ScreenshotEditorPlugin.ahk"

BASE_FIELDS = """
    static g_ShowScreenshotEditorInFlight := false
    static GuiID_ScreenshotEditor := 0
    static GuiID_ScreenshotToolbar := 0
    static ScreenshotToolbarWV2Ctrl := 0
    static ScreenshotToolbarWV2 := 0
    static ScreenshotToolbarWV2Ready := false
    static ScreenshotToolbarWV2PaintOk := false
    static ScreenshotToolbarNativeFallback := false
    static ScreenshotToolbarCurrentWidth := 520
    static ScreenshotToolbarCurrentHeight := 56
    static ScreenshotOCRHubPendingText := ""
    static ScreenshotOCRHubPushAttempts := 0
    static ScreenshotOCRHubPushInFlight := false
    static ScreenshotEditorBitmap := 0
    static ScreenshotEditorGraphics := 0
    static ScreenshotEditorImagePath := ""
    static ScreenshotEditorTitleBarHeight := 30
    static ScreenshotEditorZoomScale := 1.0
    static ScreenshotEditorZoomMin := 0.2
    static ScreenshotEditorZoomMax := 4.0
    static ScreenshotEditorBaseWidth := 0
    static ScreenshotEditorBaseHeight := 0
    static GuiID_ScreenshotZoomTip := 0
    static ScreenshotZoomTipTextCtrl := 0
    static ScreenshotEditorAlwaysOnTop := true
    static ScreenshotEditorTitleBar := 0
    static ScreenshotEditorCloseBtn := 0
    static ScreenshotEditorToolbarVisible := true
    static ScreenshotEditorIsDraggingWindow := false
    static ScreenshotToolbarHoverItems := []
    static ScreenshotToolbarHoverTipLastKey := ""
    static GuiID_ScreenshotToolbarTip := 0
    static ScreenshotToolbarTipTextCtrl := 0
    static ScreenshotOCRTextLayoutMode := "auto"
    static ScreenshotOCRPunctuationMode := "keep"
    static ScreenshotOCRDirectCopyEnabled := false
    static ScreenshotColorPickerActive := false
    static GuiID_ScreenshotColorPicker := 0
    static ScreenshotColorPickerMagnifierPic := 0
    static ScreenshotColorPickerCurrentText := 0
    static ScreenshotColorPickerCompareText := 0
    static ScreenshotColorPickerHistoryEdit := 0
    static ScreenshotColorPickerCurrent := Map()
    static ScreenshotColorPickerAnchor := Map()
    static ScreenshotColorPickerHistory := []
    static ScreenshotColorPickerTickBusy := false
    static ScreenshotEditorPreviewBitmap := 0
    static ScreenshotEditorPreviewWidth := 0
    static ScreenshotEditorPreviewHeight := 0
    static ScreenshotEditorImgWidth := 0
    static ScreenshotEditorImgHeight := 0
    static ScreenshotEditorPreviewPic := 0
    static ScreenshotEditorMode := ""
"""


def collect_method_names(lines: list[str]) -> list[str]:
    names = []
    for ln in lines:
        m = re.match(r"^([A-Za-z_][A-Za-z0-9_]*)\(.*\) \{\s*$", ln)
        if m:
            names.append(m.group(1))
    return names


def strip_global_this_vars(body: str, this_names: set[str]) -> str:
    out = []
    for ln in body.splitlines(keepends=True):
        raw = ln.rstrip("\r\n")
        m = re.match(r"^(\s*)global (.+)$", raw)
        if not m:
            out.append(ln)
            continue
        indent, rest = m.group(1), m.group(2)
        rest0 = rest.split(";")[0]
        parts = [p.strip() for p in rest0.split(",")]
        kept = []
        for p in parts:
            if not p:
                continue
            name = re.sub(r"\s*:=.*$", "", p).strip()
            if name in this_names:
                continue
            kept.append(p)
        if kept:
            out.append(f"{indent}global {', '.join(kept)}\n")
    return "".join(out)


def replace_this_identifiers(body: str, this_names: set[str]) -> str:
    for n in sorted(this_names, key=len, reverse=True):
        body = re.sub(r"\b" + re.escape(n) + r"\b", "this." + n, body)
    return body


def fix_double_this(body: str) -> str:
    return re.sub(r"\bthis\.this\.", "this.", body)


def add_static_to_methods(text: str) -> str:
    lines = text.splitlines(keepends=True)
    out = []
    for ln in lines:
        raw = ln.rstrip("\r\n")
        m = re.match(r"^([A-Za-z_][A-Za-z0-9_]*)(\(.*\) \{\s*)$", raw)
        if m and not raw.startswith(" ") and not raw.startswith("\t"):
            out.append("    static " + m.group(1) + m.group(2) + "\n")
        else:
            out.append(ln)
    return "".join(out)


def is_method_definition_line(line: str, methods: set[str]) -> bool:
    s = line.strip()
    if not s.endswith("{"):
        return False
    for name in methods:
        if re.match(rf"^static\s+{re.escape(name)}\(", s):
            return True
        if re.match(rf"^{re.escape(name)}\(", s):
            return True
    return False


def prefix_internal_calls_line(ln: str, methods: set[str]) -> str:
    if is_method_definition_line(ln, methods):
        return ln
    s = ln
    for name in sorted(methods, key=len, reverse=True):
        if name in ("if", "return", "throw", "try", "catch", "and", "or"):
            continue
        s = re.sub(r"\b" + re.escape(name) + r"\(", "this." + name + "(", s)
    return s


def prefix_internal_calls(text: str, methods: set[str]) -> str:
    return "".join(prefix_internal_calls_line(ln, methods) for ln in text.splitlines(keepends=True))


def patch_webview_and_timers(text: str) -> str:
    text = text.replace(
        'OnEvent("Size", ScreenshotToolbar_OnSize)',
        'OnEvent("Size", ObjBindMethod(ScreenshotEditorPlugin, "ScreenshotToolbar_OnSize"))',
    )
    text = text.replace(
        "WebView2.create(GuiID_ScreenshotToolbar.Hwnd, ScreenshotToolbar_OnCreated,",
        "WebView2.create(GuiID_ScreenshotToolbar.Hwnd, ObjBindMethod(ScreenshotEditorPlugin, \"ScreenshotToolbar_OnCreated\"),",
    )
    text = text.replace(
        "add_WebMessageReceived(ScreenshotToolbar_OnMessage)",
        "add_WebMessageReceived(ObjBindMethod(ScreenshotEditorPlugin, \"ScreenshotToolbar_OnMessage\"))",
    )
    text = text.replace(
        "add_NavigationCompleted(ScreenshotToolbar_OnNavigationCompleted)",
        "add_NavigationCompleted(ObjBindMethod(ScreenshotEditorPlugin, \"ScreenshotToolbar_OnNavigationCompleted\"))",
    )

    def timer_repl(m):
        name, rest = m.group(1), m.group(2)
        return f"SetTimer(ObjBindMethod(ScreenshotEditorPlugin, \"{name}\"), {rest}"

    text = re.sub(
        r"SetTimer\(([A-Za-z_][A-Za-z0-9_]*),\s*([^)]+)\)",
        timer_repl,
        text,
    )
    return text


def inject_sync_calls(text: str) -> str:
    text = text.replace(
        "GuiID_ScreenshotEditor := EditorGui\n        \n        ; 计算窗口位置",
        "GuiID_ScreenshotEditor := EditorGui\n        ScreenshotEditorPlugin._SyncHub()\n        \n        ; 计算窗口位置",
    )
    text = text.replace(
        "        this.ScreenshotEditorBaseHeight := 0\n    } catch as err {\n    }\n}\n\n\n; 更新截图助手预览",
        "        this.ScreenshotEditorBaseHeight := 0\n        ScreenshotEditorPlugin._SyncHub()\n    } catch as err {\n    }\n}\n\n\n; 更新截图助手预览",
    )
    return text


def build_hotif_block() -> str:
    return """
; 滚轮缩放（须在类定义之后；#HotIf 不能放在 class 体内）
#HotIf ScreenshotEditorPlugin_IsZoomHotkeyActive()
WheelUp:: {
    ScreenshotEditorPlugin.ScreenshotEditorZoomWithWheel(1)
}
WheelDown:: {
    ScreenshotEditorPlugin.ScreenshotEditorZoomWithWheel(-1)
}
#HotIf

#HotIf ScreenshotColorPickerActive
~LButton:: {
    ScreenshotEditorPlugin.ScreenshotColorPickerCaptureAtCursor()
}
#HotIf

ScreenshotEditorPlugin_IsZoomHotkeyActive() {
    return ScreenshotEditorPlugin.IsScreenshotEditorZoomHotkeyActive()
}
"""


def main() -> None:
    lines = MAIN.read_text(encoding="utf-8").splitlines(keepends=True)
    hot_funcs = lines[9071:9136]
    chunk = lines[19337:22549]

    this_names = set()
    for ln in BASE_FIELDS.splitlines():
        m = re.search(r"static (\w+)", ln)
        if m:
            this_names.add(m.group(1))

    methods = set(collect_method_names(chunk))
    methods |= set(collect_method_names(hot_funcs))
    methods |= {
        "IsScreenshotEditorActive",
        "IsScreenshotEditorZoomHotkeyActive",
        "HandleScreenshotEditorHotkey",
    }

    raw = "".join(hot_funcs) + "".join(chunk)
    raw = strip_global_this_vars(raw, this_names)
    raw = replace_this_identifiers(raw, this_names)
    raw = fix_double_this(raw)
    raw = add_static_to_methods(raw)
    raw = patch_webview_and_timers(raw)
    raw = prefix_internal_calls(raw, methods)
    raw = inject_sync_calls(raw)

    sync_fn = """
    static _SyncHub() {
        global GuiID_ScreenshotEditor, GuiID_ScreenshotToolbar, ScreenshotEditorPreviewPic, ScreenshotColorPickerActive
        GuiID_ScreenshotEditor := ScreenshotEditorPlugin.GuiID_ScreenshotEditor
        GuiID_ScreenshotToolbar := ScreenshotEditorPlugin.GuiID_ScreenshotToolbar
        ScreenshotEditorPreviewPic := ScreenshotEditorPlugin.ScreenshotEditorPreviewPic
        ScreenshotColorPickerActive := ScreenshotEditorPlugin.ScreenshotColorPickerActive
    }
"""

    header = (
        "; ScreenshotEditorPlugin.ahk — 截图助手（类封装，由主脚本 #Include）\n"
        "; 状态为 ScreenshotEditorPlugin 的 static 字段；Hub 同步少量全局供 LegacyConfigGui。\n\n"
        "class ScreenshotEditorPlugin {\n"
    )
    fields = BASE_FIELDS + "\n"
    body = raw
    footer = sync_fn + "\n}\n"

    full = header + fields + body + footer + build_hotif_block()

    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(full, encoding="utf-8")
    print("Wrote", OUT)


if __name__ == "__main__":
    main()
