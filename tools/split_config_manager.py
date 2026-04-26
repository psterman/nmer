# -*- coding: utf-8 -*-
"""Extract InitConfig + Export/Import to modules/ConfigManager.ahk; patch main."""
from pathlib import Path

ROOT = Path(r"c:\Users\Administrator\Desktop\小c")
MAIN = ROOT / "CursorHelper (1).ahk"
OUT = ROOT / "modules" / "ConfigManager.ahk"

# 1-based inclusive line numbers (current main before edit)
INIT_START, INIT_END = 2704, 3284  # through closing brace of InitConfig
EXP_START, EXP_END = 13197, 13350

HEADER = """; ConfigManager.ahk — 配置初始化、导出/导入（由 CursorHelper 主脚本 #Include）
; 依赖：主脚本已定义的 GetText、ConfigFile、NormalizeWindowsPath、ApplyTheme、UpdateTrayIcon、
; SetAutoStart、FTB_*、NormalizeAppearanceActivationMode、CloseConfigGUI、ShowConfigGUI、
; GetClipboardDataForCurrentTab、RefreshClipboardList、ShowImportSuccessTip 等。

"""

# Replace ImportClipboard DB branch with transactional import
IMPORTCLIP_OLD = """            if (ClipboardDB && ClipboardDB != 0) {
                try {
                    ; 先清空数据库
                    ClipboardDB.Exec("DELETE FROM ClipboardHistory")
                    ; 导入数据
                    for Index, Item in ImportedItems {
                        EscapedContent := StrReplace(Item, "'", "''")
                        SQL := "INSERT INTO ClipboardHistory (Content, SourceApp) VALUES ('" . EscapedContent . "', 'Import')"
                        ClipboardDB.Exec(SQL)
                    }
                } catch as err {
                    ; 如果数据库导入失败，回退到数组
                    global ClipboardHistory_CapsLockC := ImportedItems
                }
            }"""

IMPORTCLIP_NEW = """            if (ClipboardDB && ClipboardDB != 0) {
                try {
                    ClipboardDB.Exec("BEGIN IMMEDIATE")
                    ClipboardDB.Exec("DELETE FROM ClipboardHistory")
                    for Index, Item in ImportedItems {
                        EscapedContent := StrReplace(Item, "'", "''")
                        SQL := "INSERT INTO ClipboardHistory (Content, SourceApp) VALUES ('" . EscapedContent . "', 'Import')"
                        if !ClipboardDB.Exec(SQL) {
                            throw Error(ClipboardDB.ErrorMsg)
                        }
                    }
                    ClipboardDB.Exec("COMMIT")
                } catch as err {
                    try ClipboardDB.Exec("ROLLBACK")
                    catch {
                    }
                    global ClipboardHistory_CapsLockC := ImportedItems
                }
            }"""


def main() -> None:
    lines = MAIN.read_text(encoding="utf-8").splitlines(keepends=True)

    init_body = lines[INIT_START - 1 : INIT_END]
    exp_body = lines[EXP_START - 1 : EXP_END]
    exp_text = "".join(exp_body)
    if IMPORTCLIP_OLD not in exp_text:
        raise SystemExit("ImportClipboard pattern not found — main file changed?")
    exp_text = exp_text.replace(IMPORTCLIP_OLD, IMPORTCLIP_NEW)

    OUT.write_text(HEADER + "".join(init_body) + exp_text, encoding="utf-8")

    drop = set(range(INIT_START - 1, INIT_END)) | set(range(EXP_START - 1, EXP_END))
    # Find line with "InitConfig() ; 启动初始化" after removals
    new_lines = [ln for i, ln in enumerate(lines) if i not in drop]

    marker = "InitConfig() ; 启动初始化"
    idx = next(i for i, ln in enumerate(new_lines) if marker in ln)
    inc = '#Include modules\\ConfigManager.ahk\n'
    if not any("ConfigManager.ahk" in ln for ln in new_lines):
        new_lines.insert(idx, inc)

    MAIN.write_text("".join(new_lines), encoding="utf-8")
    print("Wrote", OUT, "inserted include before", marker)


if __name__ == "__main__":
    main()
