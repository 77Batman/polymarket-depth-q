/ load.q — DATA-INFRA-005 §1.2: load the extract and build the keyed `book` table.
/ YOU WRITE THE BODIES. Each function has a contract the tests enforce (tests/run.q).
/ Delete the 'nyi line as you implement each one.
\l q/util.q
\d .pdq

/ 1. loadObs[path]  path: string, e.g. "data/obs.csv"
/    -> table with columns: token(sym) field(sym) time(timestamp) ktime(float) value(float)
/    Hint: 0: with types "SSS*F" won't parse the ISO time; read event_time as a string ("*") then .pdq.isos it.
loadObs:{[path] '`nyi}

/ 2. scalars[obs]  -> keyed table, key (time;token), one row per snapshot, columns:
/    best_bid best_ask mid spread n_bid_levels n_ask_levels two_sided last_trade_price bid_size_at_touch ask_size_at_touch
/    Missing fields (e.g. mid on a one-sided book) must be 0n, not absent rows.
/    Hint: select by field membership, then a pivot: exec (fields)#field!value by time,token from …
scalars:{[obs] '`nyi}

/ 3. book[obs]  -> keyed table, key (time;token;side;level), columns price(float) size(float)
/    built ONLY from the stored l1..l10 scalars (bid_price_lN / bid_size_lN / ask_…). side is `bid/`ask (sym), level is long 1..10.
/    This is the UNPIVOT of the EAV store. Levels the store does not have for a snapshot are simply absent rows.
/    Label: anything derived from this table is TRUNCATED at 10 levels (acceptance #4).
/    Hint: parse the field name: side = first "_" vs string field; level = "J"$1_last "_" vs string field.
book:{[obs] '`nyi}

/ 4. loadSnapshots[path]  path "data/snapshots.jsonl"
/    -> table: token(sym) time(timestamp) ref(sym) raw(dict)   where raw = the venue's OrderBookSummary (bids/asks are lists of dicts with string price/size)
/    Hint: read0 gives one JSON string per line; .j.k parses it; the ladder is under `meta`raw.
loadSnapshots:{[path] '`nyi}

/ 5. loadHeartbeats[path]  path "data/heartbeats.csv"
/    -> table: time(timestamp) ok(boolean) n_requested n_captured n_failed (long) failed_tokens (list of sym) error (string)
loadHeartbeats:{[path] '`nyi}

\d .
