#!/usr/bin/env python3
"""Read-only extract of a small Polymarket order-book sample from Castellan's pit.db.

DATA-INFRA-005 §1.1. Opens pit.db with mode=ro (the live capture may be writing).
Writes:
  data/obs.csv          long-form scalar observations (symbol, field, event_time, knowledge_time, value)
  data/snapshots.jsonl  one raw book_snapshot document per line (full ladder, untruncated)
  data/heartbeats.csv   capture poll attempts on the 900 s grid
  data/MANIFEST.json    SQL text, window, tokens, row counts, sha256 per file, pit.db size

Usage:
  python3 extract/extract.py --db /path/to/book/pit.db --out data \
      --start 2026-08-10 --end 2026-08-13 --tokens TOKEN1 TOKEN2 ...
Re-running with the manifest's parameters must reproduce every sha256 (acceptance #1).
"""
from __future__ import annotations
import argparse, csv, hashlib, json, os, sqlite3, sys, time
from datetime import datetime, timezone

SAMPLE_MIN = "2026-08-05"   # acceptance #6: oldest data only
SAMPLE_MAX = "2026-09-01"   # exclusive

SQL_OBS = """
SELECT symbol, field, event_time, knowledge_time, value
FROM observations
WHERE source = 'polymarket-clob'
  AND symbol IN ({ph})
  AND event_time >= ? AND event_time < ?
ORDER BY symbol, event_time, field
"""
SQL_SNAP = """
SELECT doc_id, symbol, event_time, knowledge_time, ref, meta_json
FROM documents
WHERE source = 'polymarket-clob' AND doc_type = 'book_snapshot'
  AND symbol IN ({ph})
  AND event_time >= ? AND event_time < ?
ORDER BY symbol, event_time
"""
SQL_HB = """
SELECT doc_id, event_time, knowledge_time, meta_json
FROM documents
WHERE source = 'polymarket-capture-meta' AND doc_type = 'poll_attempt'
  AND event_time >= ? AND event_time < ?
ORDER BY event_time
"""

def sha256(path: str) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()

def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--db", required=True)
    ap.add_argument("--out", default="data")
    ap.add_argument("--start", required=True, help="inclusive, YYYY-MM-DD (UTC)")
    ap.add_argument("--end", required=True, help="exclusive, YYYY-MM-DD (UTC)")
    ap.add_argument("--tokens", nargs="+", required=True)
    a = ap.parse_args()

    if not (SAMPLE_MIN <= a.start < a.end <= SAMPLE_MAX):
        sys.exit(f"window must lie within [{SAMPLE_MIN}, {SAMPLE_MAX}) — acceptance #6")
    days = (datetime.fromisoformat(a.end) - datetime.fromisoformat(a.start)).days
    if days > 5 or len(a.tokens) > 4:
        sys.exit("sample bound: <= 5 days and <= 4 tokens — acceptance #6")

    os.makedirs(a.out, exist_ok=True)
    db_size = os.path.getsize(a.db)
    con = sqlite3.connect(f"file:{a.db}?mode=ro", uri=True)
    con.row_factory = sqlite3.Row
    ph = ",".join("?" * len(a.tokens))
    counts: dict[str, int] = {}

    p_obs = os.path.join(a.out, "obs.csv")
    with open(p_obs, "w", newline="") as f:
        w = csv.writer(f, lineterminator="\n")
        w.writerow(["symbol", "field", "event_time", "knowledge_time", "value"])
        n = 0
        for r in con.execute(SQL_OBS.format(ph=ph), [*a.tokens, a.start, a.end]):
            w.writerow([r["symbol"], r["field"], r["event_time"], repr(r["knowledge_time"]), repr(r["value"])])
            n += 1
        counts["obs.csv"] = n

    p_snap = os.path.join(a.out, "snapshots.jsonl")
    with open(p_snap, "w") as f:
        n = 0
        for r in con.execute(SQL_SNAP.format(ph=ph), [*a.tokens, a.start, a.end]):
            rec = {"doc_id": r["doc_id"], "symbol": r["symbol"], "event_time": r["event_time"],
                   "knowledge_time": r["knowledge_time"], "ref": r["ref"],
                   "meta": json.loads(r["meta_json"])}
            f.write(json.dumps(rec, separators=(",", ":"), sort_keys=True) + "\n")
            n += 1
        counts["snapshots.jsonl"] = n

    p_hb = os.path.join(a.out, "heartbeats.csv")
    with open(p_hb, "w", newline="") as f:
        w = csv.writer(f, lineterminator="\n")
        w.writerow(["doc_id", "event_time", "knowledge_time", "ok", "n_requested", "n_captured",
                    "n_failed", "failed_tokens", "error"])
        n = 0
        for r in con.execute(SQL_HB, [a.start, a.end]):
            m = json.loads(r["meta_json"])
            w.writerow([r["doc_id"], r["event_time"], repr(r["knowledge_time"]),
                        int(bool(m.get("ok"))), m.get("n_requested"), m.get("n_captured"),
                        m.get("n_failed"), ";".join(m.get("failed_tokens") or []), m.get("error") or ""])
            n += 1
        counts["heartbeats.csv"] = n
    con.close()

    manifest = {
        "spec": "DATA-INFRA-005",
        "extracted_utc": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "pit_db_bytes_at_extract": db_size,
        "window": {"start_inclusive": a.start, "end_exclusive": a.end, "days": days},
        "tokens": a.tokens,
        "sql": {"obs": SQL_OBS.strip(), "snapshots": SQL_SNAP.strip(), "heartbeats": SQL_HB.strip()},
        "row_counts": counts,
        "sha256": {os.path.basename(p): sha256(p) for p in (p_obs, p_snap, p_hb)},
        "notes": [
            "observations are EAV: one row per (symbol, field, event_time); 50 field names; levels 1-10 only",
            "snapshots.jsonl carries the full untruncated ladder under meta.raw.bids / meta.raw.asks (strings)",
            "heartbeats are global per poll round (not per token); grid begins 2026-08-04T16:53:16Z (I-048)",
            "no trade prints exist in the store; only last_trade_price",
        ],
    }
    with open(os.path.join(a.out, "MANIFEST.json"), "w") as f:
        json.dump(manifest, f, indent=2)
    print(json.dumps({"row_counts": counts, "sha256": manifest["sha256"]}, indent=2))
    return 0

if __name__ == "__main__":
    sys.exit(main())
