# -*- coding: utf-8 -*-
from pathlib import Path

ROOT = Path(r"c:\Users\Administrator\Desktop\小c")
MAIN = ROOT / "CursorHelper (1).ahk"
OUT = ROOT / "modules" / "ConfigWebViewModule.ahk"

# 1-based inclusive: ConfigWebView_CreateHost .. SaveConfigGUIPosition
START, END = 6282, 7219

CLOSE_FN = """
; WebView 设置页关闭（由 CloseConfigGUI 在 ConfigWebViewMode 下调用）
ConfigWebView_Close() {
    global GuiID_ConfigGUI, ConfigWV2Ctrl, ConfigWV2
    try {
        WMActivateChain_Unregister(ConfigWebView_WM_ACTIVATE)
        try WebView2_NotifyHidden(ConfigWV2)
        GuiID_ConfigGUI.Hide()
    } catch {
    }
}
"""

HEADER = """; ConfigWebViewModule.ahk — 设置中心 WebView 宿主与消息桥（由主脚本 #Include）
; 依赖：WebView2、WMActivateChain、Jxon、主脚本全局与 BuildAppLocalUrl / WebView_DumpJson 等。

"""


def main() -> None:
    lines = MAIN.read_text(encoding="utf-8").splitlines(keepends=True)
    chunk = lines[START - 1 : END]
    OUT.write_text(HEADER + "".join(chunk) + CLOSE_FN, encoding="utf-8")

    drop = set(range(START - 1, END))
    new_lines = [ln for i, ln in enumerate(lines) if i not in drop]

    # Insert include after LegacyClipboardListView
    inc_line = '#Include "modules\\LegacyClipboardListView.ahk"\n'
    insert_idx = None
    for i, ln in enumerate(new_lines):
        if ln.strip() == inc_line.strip():
            insert_idx = i + 1
            break
    if insert_idx is None:
        raise SystemExit("LegacyClipboardListView include not found")
    if not any("ConfigWebViewModule.ahk" in ln for ln in new_lines):
        new_lines.insert(insert_idx, '#Include "modules\\ConfigWebViewModule.ahk"\n')

    text = "".join(new_lines)
    old_close = """    ; WebView 设置页关闭路径（首期改造）
    if (ConfigWebViewMode) {
        try {
            WMActivateChain_Unregister(ConfigWebView_WM_ACTIVATE)
            try WebView2_NotifyHidden(ConfigWV2)
            GuiID_ConfigGUI.Hide()
        } catch {
        }
        return
    }"""
    new_close = """    ; WebView 设置页关闭路径（首期改造）
    if (ConfigWebViewMode) {
        ConfigWebView_Close()
        return
    }"""
    if old_close not in text:
        raise SystemExit("CloseConfigGUI WebView branch pattern not found")
    text = text.replace(old_close, new_close, 1)

    MAIN.write_text(text, encoding="utf-8")
    print("Wrote", OUT)


if __name__ == "__main__":
    main()
