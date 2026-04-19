# -*- coding: utf-8 -*-
"""Split native PQP GUI from AIListPanel.ahk into LegacyPromptQuickPadGui.ahk"""
from pathlib import Path

ROOT = Path(r"c:\Users\Administrator\Desktop\小c")
PANEL = ROOT / "modules" / "AIListPanel.ahk"
LEGACY = ROOT / "modules" / "LegacyPromptQuickPadGui.ahk"


def main() -> None:
    orig = PANEL.read_text(encoding="utf-8").splitlines(keepends=True)

    show_native = "".join(orig[2379:2489])
    hide_native = "".join(orig[2522:2549])
    create_inner = "".join(orig[2589:2733])

    header = (
        "; LegacyPromptQuickPadGui.ahk — Prompt Quick-Pad 原生 ListView 窗体\n"
        "; 由 AIListPanel.ahk 拆分，在文件末尾由 AIListPanel 包含。\n\n"
    )
    LEGACY.write_text(
        header
        + "LegacyPromptQuickPad_ShowNative(openForCapture := false, forceCenterMaximize := false) {\n"
        + show_native
        + "}\n\n"
        + "LegacyPromptQuickPad_HideNative() {\n"
        + hide_native
        + "}\n\n"
        + "LegacyPromptQuickPad_CreateGUI() {\n"
        + create_inner,
        encoding="utf-8",
    )

    stub = (
        '\n#Include "modules\\LegacyPromptQuickPadGui.ahk"\n\n'
        "CreateAIListPanelGUI() {\n"
        "    if PromptQuickPad_ShouldUseWebView()\n"
        "        return\n"
        "    LegacyPromptQuickPad_CreateGUI()\n"
        "}\n"
    )

    out = []
    out += orig[0:2379]
    out += ["    LegacyPromptQuickPad_ShowNative(openForCapture, forceCenterMaximize)\n"]
    out += orig[2489:2491]
    out += orig[2491:2522]
    out += ["    LegacyPromptQuickPad_HideNative()\n"]
    out += orig[2549:2550]
    out += orig[2550:2585]
    out += [stub]
    out += orig[2733:]

    PANEL.write_text("".join(out), encoding="utf-8")
    print("OK", LEGACY)


if __name__ == "__main__":
    main()
