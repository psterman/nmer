#!/usr/bin/env python3
import argparse
import csv
import gzip
import re
import sqlite3
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_DB = ROOT / "Data" / "CursorData.db"
DEFAULT_ECDICT = ROOT / "cache" / "dictsrc" / "ECDICT" / "ecdict.csv"
DEFAULT_CEDICT_GZ = ROOT / "cache" / "dictsrc" / "cedict_ts.u8"
DEFAULT_SEED = ROOT / "assets" / "dict" / "hubcapsule_base_dict.tsv"

RE_CJK = re.compile(r"[\u4e00-\u9fff]")
RE_CEDICT = re.compile(r"^(\S+)\s+(\S+)\s+\[(.*?)\]\s+/(.+)/$")
RE_POS_PREFIX = re.compile(r"^(adj|adv|art|aux|conj|det|int|n|num|phr|prep|pron|v|vi|vt)\.\s*", re.I)
RE_BAD_EN_DEF = re.compile(
    r"\b(variant of|old variant of|used in|surname|abbr\.? for|classifier for|see also|same as)\b",
    re.I,
)
RE_KEEP_EN = re.compile(r"[^A-Za-z0-9 _'/-]+")


def clean_en(text: str) -> str:
    t = (text or "").strip()
    t = t.replace("\\n", " ").replace("\n", " ")
    t = re.sub(r"\s+", " ", t)
    t = re.sub(r"\([^)]*\)", "", t)
    t = re.sub(r"\[[^\]]*\]", "", t)
    t = t.replace("CL:", " ").replace("also written", " ").replace("also called", " ")
    t = RE_CJK.sub(" ", t)
    t = t.split(";")[0].split(",")[0].split("|")[0]
    t = RE_POS_PREFIX.sub("", t).strip(" ./;,-")
    t = RE_KEEP_EN.sub(" ", t)
    t = re.sub(r"\s+", " ", t).strip(" ./;,-")
    return t


def clean_zh(text: str) -> str:
    t = (text or "").strip()
    t = t.replace("\\n", " ").replace("\n", " ")
    t = re.sub(r"\s+", " ", t)
    t = re.sub(r"\[[^\]]*\]", "", t)
    t = t.split(";")[0].split("；")[0].split(",")[0].split("，")[0]
    t = RE_POS_PREFIX.sub("", t).strip(" ./;,-")
    return t


def score_cedict_english(defn: str) -> int:
    s = clean_en(defn)
    if not s:
        return -1000
    low = s.lower()
    score = 0
    if RE_BAD_EN_DEF.search(low):
        score -= 60
    if low.startswith("to "):
        score += 8
    n_words = len(s.split())
    if 1 <= n_words <= 5:
        score += 6
    if len(s) <= 36:
        score += 4
    if re.search(r"[A-Za-z]", s):
        score += 4
    return score


def ensure_schema(conn: sqlite3.Connection) -> None:
    conn.execute(
        "CREATE TABLE IF NOT EXISTS HubLocalDict (Dir TEXT NOT NULL, K TEXT NOT NULL COLLATE NOCASE, V TEXT NOT NULL, PRIMARY KEY (Dir, K))"
    )
    conn.execute("CREATE INDEX IF NOT EXISTS idx_HubLocalDict_DirK ON HubLocalDict (Dir, K)")


def bulk_insert(conn: sqlite3.Connection, rows):
    conn.executemany("INSERT OR REPLACE INTO HubLocalDict (Dir, K, V) VALUES (?, ?, ?)", rows)


def import_seed_tsv(conn: sqlite3.Connection, path: Path) -> int:
    if not path.exists():
        return 0
    rows = []
    with path.open("r", encoding="utf-8", errors="ignore") as f:
        for raw in f:
            line = raw.strip()
            if not line or line.startswith("#"):
                continue
            parts = line.split("\t")
            if len(parts) < 2:
                continue
            src = parts[0].strip()
            dst = parts[1].strip()
            if not src or not dst:
                continue
            if RE_CJK.search(src):
                v = clean_en(dst)
                if v:
                    rows.append(("zh2en", src, v))
            elif RE_CJK.search(dst):
                v = clean_zh(dst)
                if v:
                    rows.append(("en2zh", src.lower(), v))
    bulk_insert(conn, rows)
    return len(rows)


def import_ecdict(conn: sqlite3.Connection, path: Path, max_rows: int = 0) -> int:
    if not path.exists():
        return 0
    inserted = 0
    batch = []
    with path.open("r", encoding="utf-8-sig", errors="ignore", newline="") as f:
        rd = csv.DictReader(f)
        for row in rd:
            word = (row.get("word") or "").strip().lower()
            if not word:
                continue
            trans = (row.get("translation") or row.get("definition") or "").strip()
            zh = clean_zh(trans)
            if not zh or not RE_CJK.search(zh):
                continue
            batch.append(("en2zh", word, zh))
            inserted += 1
            if len(batch) >= 5000:
                bulk_insert(conn, batch)
                batch.clear()
            if max_rows > 0 and inserted >= max_rows:
                break
    if batch:
        bulk_insert(conn, batch)
    return inserted


def import_cedict(conn: sqlite3.Connection, path: Path, max_rows: int = 0) -> int:
    if not path.exists():
        return 0
    inserted = 0
    batch = []
    opener = gzip.open if str(path).lower().endswith(".gz") else open
    with opener(path, "rt", encoding="utf-8", errors="ignore") as f:
        for raw in f:
            line = raw.strip()
            if not line or line.startswith("#"):
                continue
            m = RE_CEDICT.match(line)
            if not m:
                continue
            simp = m.group(2).strip()
            defs = [d.strip() for d in m.group(4).split("/") if d.strip()]
            eng = ""
            best_score = -10**9
            for d in defs:
                d2 = clean_en(d)
                sc = score_cedict_english(d)
                if d2 and re.search(r"[A-Za-z]", d2) and sc > best_score:
                    best_score = sc
                    eng = d2
            if not simp or not eng or best_score < 0:
                continue
            batch.append(("zh2en", simp, eng))
            inserted += 1
            if len(batch) >= 5000:
                bulk_insert(conn, batch)
                batch.clear()
            if max_rows > 0 and inserted >= max_rows:
                break
    if batch:
        bulk_insert(conn, batch)
    return inserted


def main():
    ap = argparse.ArgumentParser(description="Import ECDICT + CC-CEDICT into HubLocalDict")
    ap.add_argument("--db", default=str(DEFAULT_DB))
    ap.add_argument("--ecdict", default=str(DEFAULT_ECDICT))
    ap.add_argument("--cedict-gz", default=str(DEFAULT_CEDICT_GZ))
    ap.add_argument("--seed", default=str(DEFAULT_SEED))
    ap.add_argument("--rebuild", action="store_true")
    ap.add_argument("--ecdict-max", type=int, default=0, help="Limit imported ECDICT rows, 0=all")
    ap.add_argument("--cedict-max", type=int, default=0, help="Limit imported CEDICT rows, 0=all")
    args = ap.parse_args()

    db_path = Path(args.db)
    if not db_path.exists():
        raise SystemExit(f"DB not found: {db_path}")

    conn = sqlite3.connect(str(db_path))
    conn.execute("PRAGMA journal_mode=WAL")
    conn.execute("PRAGMA synchronous=OFF")
    conn.execute("PRAGMA temp_store=MEMORY")
    conn.execute("PRAGMA cache_size=-200000")

    ensure_schema(conn)
    if args.rebuild:
        conn.execute("DELETE FROM HubLocalDict")
        conn.commit()

    seed_n = import_seed_tsv(conn, Path(args.seed))
    conn.commit()
    ecdict_n = import_ecdict(conn, Path(args.ecdict), max_rows=args.ecdict_max)
    conn.commit()
    cedict_n = import_cedict(conn, Path(args.cedict_gz), max_rows=args.cedict_max)
    conn.commit()

    total = conn.execute("SELECT COUNT(*) FROM HubLocalDict").fetchone()[0]
    en2zh = conn.execute("SELECT COUNT(*) FROM HubLocalDict WHERE Dir='en2zh'").fetchone()[0]
    zh2en = conn.execute("SELECT COUNT(*) FROM HubLocalDict WHERE Dir='zh2en'").fetchone()[0]
    conn.close()

    print(f"seed imported:   {seed_n}")
    print(f"ecdict imported: {ecdict_n}")
    print(f"cedict imported: {cedict_n}")
    print(f"HubLocalDict total: {total} (en2zh={en2zh}, zh2en={zh2en})")


if __name__ == "__main__":
    main()
