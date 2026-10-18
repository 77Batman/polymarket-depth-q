/ ladder.q — full-depth ladders from the raw JSON, and the RECONCILIATION against the firm's stored scalars (acceptance #2).
\l q/load.q
\d .pdq

E:([] time:0#0Np; token:0#`; side:0#`; level:0#0; price:0#0f; size:0#0f)   / empty ladder, typed

/ one side of one snapshot -> rows. Ordering contract = parse_polymarket_book: bids by price DESC, asks ASC, level = 1-based rank.
side1:{[t;tok;lv;sd]
  if[0=count lv; :.pdq.E];
  p:"F"$lv[;`price]; s:"F"$lv[;`size];
  o:$[sd=`bid;idesc p;iasc p];
  n:count o;
  ([] time:n#t; token:n#tok; side:n#sd; level:1+til n; price:p o; size:s o)}

/ ladder[snaps] -> time token side level price size — EVERY level, no truncation
ladder:{[snaps]
  f:{[t;tok;raw] .pdq.side1[t;tok;raw`bids;`bid],.pdq.side1[t;tok;raw`asks;`ask]};
  `time`token`side`level xasc raze f'[snaps`time;snaps`token;snaps`raw]}

/ ladderTop10[lad] -> keyed like .pdq.book, levels <= 10, so the two compare row-for-row
ladderTop10:{[lad] `time`token`side`level xkey select time,token,side,level,price,size from lad where level<=10}

/ recomputeScalars[snaps] -> keyed (time;token), same columns as .pdq.scalars, computed from the raw ladder.
/ Takes snaps (not the ladder) so an EMPTY book still gets a row (n_bid_levels 0, n_ask_levels 0, two_sided 0).
recomputeScalars:{[snaps]
  lad:ladder snaps;
  k:select time,token from snaps;                       / unkeyed: a table cannot be keyed on ALL its columns
  b:select n_bid_levels:count i, best_bid:first price, bid_size_at_touch:first size by time,token from `level xasc select from lad where side=`bid;
  a:select n_ask_levels:count i, best_ask:first price, ask_size_at_touch:first size by time,token from `level xasc select from lad where side=`ask;
  r:(k lj b) lj a;
  r:update n_bid_levels:`float$0^n_bid_levels, n_ask_levels:`float$0^n_ask_levels from r;
  r:update two_sided:`float$(n_bid_levels>0)&n_ask_levels>0 from r;
  r:update mid:(best_bid+best_ask)%2, spread:best_ask-best_bid from r where two_sided=1f;
  `time`token xkey update last_trade_price:0n from r}

/ recon[stored;recomputed;cols] -> `nCompared`nMismatch`maxAbsDiff`worst
/ both keyed on the same columns; mismatch = abs diff > 1e-9, or null on exactly one side. worst = the row with the largest diff.
recon:{[stored;recomputed;cs]        / `cols` is a q keyword, so the parameter is `cs`
  k:keys stored;
  s:(k,cs)#0!stored;
  r:(k,`$string[cs],\:"_r") xcol (k,cs)#0!recomputed;
  j:s ij k xkey r;
  if[0=count j;'"no overlapping keys"];
  per:{[j;c] x:j c; y:j`$string[c],"_r"; both:not null[x] or null y; d:0f^abs x-y; mis:(null[x]<>null y) or d>1e-9; (mis;d)};
  res:per[j;] each cs;
  mis:any each flip res[;0]; dd:max each flip res[;1];
  w:where mis;
  `nCompared`nMismatch`maxAbsDiff`worst!(count j; sum mis; $[count dd;max dd;0f]; $[count w; j first w idesc dd w; ()])}

\d .
