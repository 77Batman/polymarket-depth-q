#!/usr/bin/env python3
"""Independent pandas reference for the depth metrics (acceptance #3).

Reads data/snapshots.jsonl (the full raw ladders) and writes reference/expected_depth.csv.
The q implementation must reproduce every value to 1e-9. Definitions (shared contract with q/depth.q):

  bids sorted by price DESC, asks by price ASC (same as castellan.loaders.parse_polymarket_book)
  cum_bid_size_N   = sum(size) over the top N bid levels          N in {1,5,10}; _all = every level
  cum_ask_size_N   = same for asks
  cum_bid_notional_N / cum_ask_notional_N = sum(price*size) over the top N levels
  levels_to_T      = smallest k with cumulative notional (price*size) of the top k levels >= T, else NaN
  price_at_T       = price of that k-th level, else NaN                       (T = NOTIONAL_T, both sides)
  imb_L1           = (bid_size_1 - ask_size_1) / (bid_size_1 + ask_size_1)   NaN if either side empty
  imb_L5           = (sum top-5 bid sizes - sum top-5 ask sizes) / (sum of both)  NaN if either side empty

Descriptive only. Nothing here relates a book feature to a later outcome (acceptance #8).
"""
from __future__ import annotations
import json, math, sys, os
import pandas as pd

NOTIONAL_T = 1000.0
NS = (1, 5, 10)

def ladder(levels: list[dict], desc: bool) -> list[tuple[float, float]]:
    out = [(float(l["price"]), float(l["size"])) for l in (levels or [])]
    return sorted(out, key=lambda p: -p[0] if desc else p[0])

def cum(levels, n=None):
    sub = levels if n is None else levels[:n]
    return sum(s for _, s in sub), sum(p * s for p, s in sub)

def to_threshold(levels, t):
    acc = 0.0
    for k, (p, s) in enumerate(levels, start=1):
        acc += p * s
        if acc >= t:
            return k, p
    return math.nan, math.nan

def row(rec: dict) -> dict:
    raw = rec["meta"]["raw"]
    bids, asks = ladder(raw.get("bids"), True), ladder(raw.get("asks"), False)
    r = {"symbol": rec["symbol"], "event_time": rec["event_time"],
         "n_bid_levels": len(bids), "n_ask_levels": len(asks)}
    for n in NS:
        r[f"cum_bid_size_{n}"], r[f"cum_bid_notional_{n}"] = cum(bids, n)
        r[f"cum_ask_size_{n}"], r[f"cum_ask_notional_{n}"] = cum(asks, n)
    r["cum_bid_size_all"], r["cum_bid_notional_all"] = cum(bids)
    r["cum_ask_size_all"], r["cum_ask_notional_all"] = cum(asks)
    r["bid_levels_to_T"], r["bid_price_at_T"] = to_threshold(bids, NOTIONAL_T)
    r["ask_levels_to_T"], r["ask_price_at_T"] = to_threshold(asks, NOTIONAL_T)
    if bids and asks:
        b1, a1 = bids[0][1], asks[0][1]
        r["imb_L1"] = (b1 - a1) / (b1 + a1) if (b1 + a1) else math.nan
        b5, a5 = cum(bids, 5)[0], cum(asks, 5)[0]
        r["imb_L5"] = (b5 - a5) / (b5 + a5) if (b5 + a5) else math.nan
    else:
        r["imb_L1"] = r["imb_L5"] = math.nan
    return r

def main(src="data/snapshots.jsonl", dst="reference/expected_depth.csv") -> int:
    rows = [row(json.loads(line)) for line in open(src) if line.strip()]
    df = pd.DataFrame(rows).sort_values(["symbol", "event_time"]).reset_index(drop=True)
    df.to_csv(dst, index=False, float_format="%.12g")
    print(f"{len(df)} snapshots -> {dst}; threshold T={NOTIONAL_T}")
    return 0

if __name__ == "__main__":
    sys.exit(main(*sys.argv[1:]))
