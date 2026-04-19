# -*- coding: utf-8 -*-
"""Extract LegacyClipboardListView.ahk from CursorHelper (1).ahk"""
from pathlib import Path

ROOT = Path(r"c:\Users\Administrator\Desktop\小c")
MAIN = ROOT / "CursorHelper (1).ahk"
LEGACY = ROOT / "modules" / "LegacyClipboardListView.ahk"

# 1-based inclusive line numbers (current file)
START_LINE = 8833
END_LINE = 14553


def main() -> None:
    lines = MAIN.read_text(encoding="utf-8").splitlines(keepends=True)
    a, b = START_LINE - 1, END_LINE  # 0-based slice [a:b) -> end exclusive
    chunk = "".join(lines[a:b])

    header = (
        "; LegacyClipboardListView.ahk — 原生 ListView 剪贴板管理器 GUI\n"
        "; 由 CursorHelper 主脚本拆分；依赖主脚本全局变量与 OnWindowSize 等共用函数。\n\n"
    )
    LEGACY.write_text(header + chunk, encoding="utf-8")

    new_lines = lines[:a] + lines[b:]
    text = "".join(new_lines)

    needle = '#Include "modules\\LegacyConfigGui.ahk"'
    if needle not in text:
        raise SystemExit("LegacyConfigGui include not found")
    insert = needle + "\n#Include \"modules\\LegacyClipboardListView.ahk\""
    text = text.replace(needle, insert, 1)

    MAIN.write_text(text, encoding="utf-8")
    print("OK:", LEGACY)


if __name__ == "__main__":
    main()
