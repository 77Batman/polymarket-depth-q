# polymarket-depth-q

Order-book depth analytics in **q / KDB-X**, reconciled against an independent record.

Since August 2026 a small capture job has been snapshotting Polymarket CLOB order books every 15 minutes
(20 outcome tokens, 10 markets) into a point-in-time SQLite store — the only depth history those markets
have, because resting orders never touch the chain. That store keeps two things per snapshot: a set of
**scalar fields** parsed at capture time (best bid/ask, spread, mid, levels 1–10) and the **raw, untruncated
JSON** of the book. This repo re-derives the scalars from the raw JSON in q and checks them against what was
stored, then computes depth metrics from the full ladder and checks those against an independent pandas
reference. The point is not the metrics — it is whether two implementations agree, and by how much.

**Status:** _build in progress — numbers below are filled in from the test output, not typed by hand._

## What is here

| Path | What |
|---|---|
| `extract/extract.py` | Read-only extract from the capture store (`mode=ro`) → `data/` + `MANIFEST.json` (SQL, window, counts, sha256). |
| `data/` | A committed sample: ≤ 5 days × ≤ 4 tokens from August 2026. The full store is not in this repo. |
| `q/load.q` | Loads the extract; **unpivots** the long-form (entity–attribute–value) scalar store into a keyed `book` table `(time;token;side;level)`. |
| `q/ladder.q` | Builds the full-depth ladder from the raw JSON and reconciles it with the stored scalars. |
| `q/depth.q` | Descriptive depth metrics: cumulative size/notional at 1/5/10/all levels, levels and price to a $1,000 notional, L1 and L1–5 imbalance. |
| `q/cadence.q` | Data-quality layer: classifies every 900 s slot × token as captured / one-sided / empty / attempted-failed / not-attempted, with the pre-heartbeat window marked *ambiguous*. |
| `reference/pandas_ref.py` | Independent pandas implementation of the same metric contract. |
| `tests/run.q` | Red-first tests: fixtures first, then the real sample. `q tests/run.q` |

## Results on the committed sample

_(to be filled from `q tests/run.q` output)_

- Reconciliation, stored levels 1–10 vs raw-JSON ladder: **n compared = …, mismatches = …, max |diff| = …**
- Reconciliation, stored scalars vs recomputed: **max |diff| = …**
- Depth metrics, q vs pandas: **n compared = …, mismatches = …, max |diff| = …**
- Cadence over the sample window: captured …, one-sided …, empty …, attempted-failed …, not-attempted …, ambiguous …

## What was NOT verified

- The stored scalar fields stop at **10 levels**; anything derived from them is labelled truncated. Only the
  notional-threshold metrics use the full ladder.
- The store has **no trade prints** — only `last_trade_price` per snapshot. Nothing here joins trades.
- No statistic in this repo relates a book feature to a later outcome. That is deliberate: such a number would be
  an unregistered backtest, and the research process this data belongs to registers hypotheses before computing them.
- KDB-X Community Edition licence terms: _(state only what you have read in `~/.kx/kc.lic` / the licence text)_.
- No performance claims. At this data size SQLite + pandas is perfectly adequate; q was chosen to learn q.

## Reproduce

```
python3 extract/extract.py --db /path/to/pit.db --out data --start 2026-08-10 --end 2026-08-13 --tokens …   # see MANIFEST.json
python3 reference/pandas_ref.py
q tests/run.q
```
The capture code that produced the store is public: `harness/castellan/loaders.py` and
`harness/scripts/capture_polymarket_book.py` in [77Batman/castellan](https://github.com/77Batman/castellan).
