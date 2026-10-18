/ cadence.q — data-quality layer (acceptance #5): classify every 900 s slot x token.
/ Classes: `captured `attempted_failed `not_attempted `one_sided `empty, plus `ambiguous for slots before HB0 (I-048).
\l q/load.q
\d .pdq

GRID:0D00:15:00                          / 900 s
HB0:2026.08.04D16:53:16.779495000        / first heartbeat ever written (I-048). Slots before this with no heartbeat are AMBIGUOUS, never imputed.

/ 11. slots[t0;t1] -> timestamps from GRID xbar t0 to GRID xbar t1 inclusive, step GRID
slots:{[t0;t1] '`nyi}

/ 12. cadence[hb;snaps;tokens;t0;t1]   slots = .pdq.slots[t0;t1]
/   hb from loadHeartbeats, snaps from loadSnapshots (needs n_bid_levels/n_ask_levels per snapshot — derive from count raw`bids / raw`asks), tokens: sym list
/   -> table: slot(timestamp) token(sym) class(sym)
/   Rules, evaluated per (slot;token) in this order:
/     a. snapshot for token whose time falls in [slot, slot+GRID) and both sides non-empty           -> `captured
/     b. snapshot in slot, exactly one side non-empty                                                 -> `one_sided
/     c. snapshot in slot, both sides empty                                                           -> `empty
/     d. no snapshot; a heartbeat in slot exists and (not ok, or token in failed_tokens)              -> `attempted_failed
/     e. no snapshot; no heartbeat in slot; slot < HB0                                                -> `ambiguous
/     f. no snapshot; no heartbeat in slot; slot >= HB0                                               -> `not_attempted
/     g. no snapshot; heartbeat ok and token not in failed_tokens (should not happen; label it)        -> `attempted_failed
/   Hint: aj heartbeats and snapshots onto the slot grid (`slot`token keys), then a vector cond ?[;;] cascade.
cadence:{[hb;snaps;tokens;t0;t1] '`nyi}

/ 13. cadenceReport[c] -> keyed table class -> n, with `ambiguous reported as its own row (acceptance #5)
cadenceReport:{[c] '`nyi}

\d .
