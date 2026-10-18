/ ladder.q — full-depth ladders from the raw JSON, and the RECONCILIATION against the firm's stored scalars.
/ This is acceptance #2: the firm treats any mismatch as a data incident.
\l q/load.q
\d .pdq

/ 6. ladder[snaps]  snaps from loadSnapshots
/    -> table (NOT keyed): time token side level price size — EVERY level, no truncation.
/    Ordering contract (must match parse_polymarket_book): bids by price DESC, asks by price ASC, level = 1-based rank after sorting.
/    price/size arrive as strings in the JSON: "F"$.
ladder:{[snaps] '`nyi}

/ 7. ladderTop10[lad]  -> keyed (time;token;side;level) price size, levels <= 10 only. Same shape as .pdq.book so the two can be compared row-for-row.
ladderTop10:{[lad] '`nyi}

/ 8. recomputeScalars[lad] -> keyed (time;token) with the SAME columns as .pdq.scalars, computed from the ladder:
/    n_bid_levels n_ask_levels two_sided best_bid best_ask bid_size_at_touch ask_size_at_touch mid spread
/    (last_trade_price is not in the ladder — fill 0n; the test excludes it.)
/    two_sided = 1f if both sides non-empty else 0f.  mid/spread only when two-sided, else 0n.
recomputeScalars:{[lad] '`nyi}

/ 9. recon[stored;recomputed;cols]  both keyed on the same key; cols = symbols to compare
/    -> dict: `nCompared`nMismatch`maxAbsDiff`worst   where mismatch means abs diff > 1e-9 (nulls equal only to nulls),
/       worst = the single row (key + stored + recomputed) with the largest abs diff, or () if none.
/    The number maxAbsDiff goes in the README verbatim.
recon:{[stored;recomputed;cols] '`nyi}

\d .
