# -*- coding: utf-8 -*-
"""One-off: extract LegacyConfigGui.ahk from CursorHelper (1).ahk"""
from pathlib import Path

ROOT = Path(r"c:\Users\Administrator\Desktop\小c")
MAIN = ROOT / "CursorHelper (1).ahk"
LEGACY = ROOT / "modules" / "LegacyConfigGui.ahk"


def main() -> None:
    raw = MAIN.read_bytes()
    nl = "\r\n" if b"\r\n" in raw else "\n"
    text = raw.decode("utf-8")
    lines = text.splitlines(keepends=True)

    def slice_join(a: int, b: int) -> str:
        return "".join(lines[a:b])

    core = slice_join(6888, 17197)
    core = core.replace("ShowConfigGUI()", "LegacyConfigGui_Show()", 1)

    # Remove WebView branch (flexible newline)
    import re

    core = re.sub(
        r"    if \(UseWebViewSettings\) \{\s*"
        r"ShowConfigWebViewGUI\(\)\s*"
        r"return\s*"
        r"\}\s*",
        "",
        core,
        count=1,
        flags=re.MULTILINE,
    )

    open_legacy = slice_join(18049, 18061)
    scroll_block = slice_join(18126, 18488)
    # Native close body: lines 18606–18697 (timer), exclude outer CloseConfigGUI `}`
    close_native_body = slice_join(18605, 18697)
    close_native_body = close_native_body.replace("IsClosing", "CloseConfigGUI_IsClosing")

    legacy_header = (
        "; LegacyConfigGui.ahk — 原生全屏配置窗（UseWebViewSettings = false）\n"
        "; 由 CursorHelper 主脚本拆分；依赖主脚本已加载的工具与全局变量。\n"
        "global CloseConfigGUI_IsClosing := false\n\n"
    )

    legacy_close_fn = (
        "\n; 原生配置窗关闭路径（WebView 分支留在主脚本 CloseConfigGUI）\n"
        "LegacyConfigGui_CloseNative() {\n"
        "    global GuiID_ConfigGUI, CapsLockHoldTimeEdit, CapsLockHoldTimeSeconds, ConfigFile\n"
        "    global DDLBrush, DefaultStartTabDDL_Hwnd\n"
        f"{close_native_body}"
        "}\n"
    )

    LEGACY.parent.mkdir(parents=True, exist_ok=True)
    LEGACY.write_text(
        legacy_header + core + open_legacy + scroll_block + legacy_close_fn,
        encoding="utf-8",
    )

    drop = set(range(6888, 17197)) | set(range(18049, 18061)) | set(range(18126, 18488))
    new_lines = [ln for idx, ln in enumerate(lines) if idx not in drop]

    insert = (
        f'{nl}#Include "modules\\LegacyConfigGui.ahk"{nl}{nl}'
        f"ShowConfigGUI() {{{nl}"
        f"    global UseWebViewSettings{nl}"
        f"    if (UseWebViewSettings) {{{nl}"
        f"        ShowConfigWebViewGUI(){nl}"
        f"        return{nl}"
        f"    }}{nl}"
        f"    LegacyConfigGui_Show(){nl}"
        f"}}{nl}{nl}"
    )
    new_lines.insert(6888, insert)
    new_text = "".join(new_lines)

    new_text = re.sub(
        r"\r?\n[ \t]*static IsClosing := false[^\n]*\r?\n\r?\n",
        nl + nl,
        new_text,
        count=1,
    )
    new_text = new_text.replace("if (IsClosing)", "if (CloseConfigGUI_IsClosing)")

    m = re.search(
        r"(\r?\n[ \t]*; 检查窗口是否仍然有效\r?\n)"
        r"[\s\S]*?"
        r"([ \t]*SetTimer\(\(\) => IsClosing := false, -100\)\r?\n)",
        new_text,
    )
    if not m:
        raise SystemExit("Could not find native CloseConfigGUI body to replace")
    new_text = new_text.replace(m.group(0), nl + "    LegacyConfigGui_CloseNative()" + nl, 1)

    if new_text.count("LegacyConfigGui_CloseNative()") != 1:
        raise SystemExit("Expected exactly one LegacyConfigGui_CloseNative() call in main")

    m2 = re.search(
        r"(CloseConfigGUI\(\) \{\s*\r?\n)([ \t]*global[^\n]*\n)", new_text
    )
    if not m2:
        raise SystemExit("CloseConfigGUI() header not found")
    new_text = new_text.replace(
        m2.group(0),
        m2.group(1) + "    global CloseConfigGUI_IsClosing" + nl + m2.group(2),
        1,
    )

    MAIN.write_text(new_text, encoding="utf-8")
    print("OK:", LEGACY, MAIN)


if __name__ == "__main__":
    main()
