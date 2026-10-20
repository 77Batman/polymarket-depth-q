# polymarket-depth-q

Order-book depth analytics in **q / KDB-X**, reconciled against an independent record.

Since August 2026 a small capture job has been snapshotting Polymarket CLOB order books every 15 minutes
(20 outcome tokens, 10 markets) into a point-in-time SQLite store — the only depth history those markets
have, because resting orders never touch the chain. That store keeps two things per snapshot: a set of
**scalar fields** parsed at capture time (best bid/ask, spread, mid, levels 1–10) and the **raw, untruncated
JSON** of the book. This repo re-derives the scalars from the raw JSON in q and checks them against what was
stored, then computes depth metrics from the full ladder and checks those against an independent pandas
reference. The point is not the metrics — it is whether two implementations agree, and by how much.

**Status:** complete for the committed sample. Every number below is printed by `q tests/run.q` / `q q/report.q`; none is typed by hand.

## What is here

| Path | What |
|---|---|
| `extract/extract.py` | Read-only extract from the capture store (`mode=ro`) → `data/` + `MANIFEST.json` (SQL, window, counts, sha256). |
| `data/` | A committed sample: ≤ 5 days × ≤ 4 tokens from August 2026. The full store is not in this repo. |
| `q/load.q` | Loads the extract; **unpivots** the long-form (entity–attribute–value) scalar store into a keyed `book` table `(time;token;side;level)`. |
| `q/ladder.q` | Builds the full-depth ladder from the raw JSON and reconciles it with the stored scalars. |
| `q/depth.q` | Descriptive depth metrics: cumulative size/notional at 1/5/10/all levels, levels and price to a $1,000 notional, L1 and L1–5 imbalance. |
| `q/cadence.q` | Data-quality layer: classifies every 900 s slot × token as captured / captured-unchanged / one-sided / empty / attempted-failed / not-attempted, with the pre-heartbeat window marked *ambiguous*. |
| `reference/pandas_ref.py` | Independent pandas implementation of the same metric contract. |
| `q/report.q` | Prints the reconciliation and cadence numbers below. `q q/report.q` |
| `tests/run.q` | Red-first tests: fixtures first, then the real sample. `q tests/run.q` |

## Results on the committed sample

Sample: 2026-08-10 → 2026-08-13 (exclusive), 4 outcome tokens (two yes/no pairs), **1,350 snapshots**, 67,500 scalar
rows, 394 capture heartbeats. `data/MANIFEST.json` carries the SQL, the window, the row counts and a sha256 per file;
re-running the extract with those parameters reproduces the hashes.

| Check | Compared | Mismatches | max \|diff\| |
|---|---:|---:|---:|
| Stored levels 1–10 (price, size) vs ladder rebuilt from raw JSON in q | 27,000 rows | 0 | 0 |
| Stored scalars (best bid/ask, mid, spread, sizes at touch, level counts, two-sided flag) vs recomputed in q | 1,350 snapshots | 0 | 0 |
| Depth metrics, q vs independent pandas reference | 32,400 values | 0 | 0 |

Exactly zero, not 1e-12: both sides sort the same way and do the same arithmetic in the same order, so the IEEE
results are bit-identical. The tolerance in the tests is 1e-9; it was never needed.

**Depth.** Books in this sample go to **84 levels** on both sides; the stored scalars stop at 10. Every snapshot in
the window reaches $1,000 of notional within the top 10 levels on both sides, so for *this* window the truncation
costs nothing for that metric — a fact about the sample, not a property of the data.

**Cadence** (288 fifteen-minute slots × 4 tokens = 1,152 slot-tokens):

| class | n |
|---|---:|
| captured (two-sided snapshot in slot) | 1,132 |
| captured_unchanged (heartbeat says the token was captured; no new snapshot because the book had not changed) | 8 |
| not_attempted (no heartbeat in the slot) | 12 |
| attempted_failed (heartbeat reports the round or the token failed) | 0 |
| one_sided / empty | 0 |
| ambiguous (slot before the first heartbeat, 2026-08-04 16:53 UTC) | 0 — the window starts after it |

The classes are kept apart because they mean different things: *not_attempted* is the capture job not running;
*attempted_failed* is a round or token the capture recorded as failed (the heartbeat says that it failed, not why); *captured_unchanged* is neither — the store deduplicates snapshots on
the venue's own book timestamp, so a book that has not moved since the previous poll writes no new document. The first
version of this classifier labelled those 8 as failures. Reading the heartbeats (all 394 report ok, 20 of 20 captured,
0 failed) against the capture code showed the real cause, and the class was added. Slots before the first heartbeat
can't be told apart and are labelled ambiguous rather than guessed.

**Two capture hosts.** The store merges heartbeats and snapshots from two capture hosts (a VPS and a laptop), and the
sample carries no host field, so the table above is their combined wall-clock grid, not a measure of either host's
health. Both pollers cycle slightly slower than 900 s (median heartbeat gaps of 902.7 s and 920.0 s in this window), so
a few *not_attempted* slots are grid drift — a 900 s bucket that neither poller's cycle happened to land in — rather
than outages. A per-host cadence needs a host field written at capture; the capture gained one after this sample was
taken, so it is out of scope here.

## What was NOT verified

- The stored scalar fields stop at **10 levels**; anything derived from them is labelled truncated. Only the
  notional-threshold metrics use the full ladder.
- The store has **no trade prints** — only `last_trade_price` per snapshot. Nothing here joins trades.
- No statistic in this repo relates a book feature to a later outcome. That is deliberate: such a number would be
  an unregistered backtest, and the research process this data belongs to registers hypotheses before computing them.
- KDB-X 5.0 Community Edition was used. From the KX Community Edition License Agreement as read on 2026-10-18: "Subject to and provided you comply with the terms of the Agreement, we hereby grant to you a limited, non-transferable, non-exclusive license, without right of sublicense, for the applicable License Period to install and execute the Software in executable code form for use by you solely for the Permitted Use and subject to the [Usage Restrictions](https://docs.kx.com/product/licensing/usage-restrictions.htm)." This repo contains no KX software — only q source and data — and was built for personal learning.
- No performance claims. At this data size SQLite + pandas is perfectly adequate; q was chosen to learn q.
- Per-host cadence. Heartbeats from two capture hosts are merged in the store and the sample has no host field, so
  cadence is reported for the combined stream only.
- Only the committed window was checked. The full store (≈3.8 M scalar rows, 91 k snapshots as of 2026-10-18, before a merge) was not.

## Reproduce

```
python3 extract/extract.py --db /path/to/pit.db --out data --start 2026-08-10 --end 2026-08-13 --tokens …   # tokens in MANIFEST.json
python3 reference/pandas_ref.py
q tests/run.q
q q/report.q
```
The capture code that produced the store is public: `harness/castellan/loaders.py` and
`harness/scripts/capture_polymarket_book.py` in [77Batman/castellan](https://github.com/77Batman/castellan).
