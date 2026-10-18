/ load.q — DATA-INFRA-005 §1.2: load the extract and build the keyed `book` table.
\l q/util.q
\d .pdq

/ scalar (non-level) fields written by parse_polymarket_book
SCAL:`best_bid`best_ask`mid`spread`n_bid_levels`n_ask_levels`two_sided`last_trade_price`bid_size_at_touch`ask_size_at_touch

/ loadObs[path] -> token field time ktime val     (the store is EAV: one row per field per snapshot)
/ `value` is a reserved word in q, hence `val`.
loadObs:{[path]
  t:("SS*FF";enlist csv) 0: hsym `$path;            / ISO time read as string: q's P parser rejects the "T"/"+00:00" form
  t:`token`field`time`ktime`val xcol t;
  update time:.pdq.isos time from t}

/ scalars[obs] -> keyed (time;token) with the SCAL columns; a field the store lacks for a snapshot is 0n
scalars:{[obs]
  exec .pdq.SCAL#field!val by time,token from obs where field in .pdq.SCAL}   / dict pivot: take[] with missing keys yields nulls

/ book[obs] -> keyed (time;token;side;level) price size — the UNPIVOT of bid_price_l3 / ask_size_l7 …
/ Only levels 1..10 exist in the store: anything built on this table is TRUNCATED (acceptance #4).
book:{[obs]
  b:select from obs where field like "*_price_l*", not field like "*_at_touch";
  b,:select from obs where field like "*_size_l*", not field like "*_at_touch";
  p:"_" vs' string b`field;                          / ("bid";"price";"l3")
  b:update side:`$p[;0], kind:`$p[;1], level:"J"$1_'p[;2] from b;
  exec `price`size#kind!val by time,token,side,level from b}

/ loadSnapshots[path] -> token time ref raw      raw = the venue's OrderBookSummary dict; bids/asks are lists of dicts with STRING price/size
loadSnapshots:{[path]
  j:.j.k each read0 hsym `$path;
  ([] token:`$j[;`symbol]; time:isos j[;`event_time]; ref:`$j[;`ref]; raw:j[;`meta][;`raw])}

/ loadHeartbeats[path] -> time ok n_requested n_captured n_failed failed_tokens(sym list) error(string)
loadHeartbeats:{[path]
  h:("J*FBJJJ**";enlist csv) 0: hsym `$path;
  h:update time:.pdq.isos event_time, failed_tokens:{$[0=count x;0#`;`$";" vs x]} each failed_tokens from h;
  `time`ok`n_requested`n_captured`n_failed`failed_tokens`error#h}

\d .
