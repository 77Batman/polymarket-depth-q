/ depth.q — descriptive depth metrics from the FULL ladder (acceptance #3; contract shared with reference/pandas_ref.py).
/ Descriptive only. Nothing here relates a book feature to a LATER outcome (acceptance #8).
\l q/ladder.q
\d .pdq

T:1000f           / notional threshold (USD) — same constant as pandas_ref.NOTIONAL_T

/ per-side aggregates for every snapshot that has levels on that side
sideAgg:{[lad;sd]
  t:select n:count i,
      cs1:sum size where level<=1,  cn1:sum (price*size) where level<=1,
      cs5:sum size where level<=5,  cn5:sum (price*size) where level<=5,
      cs10:sum size where level<=10, cn10:sum (price*size) where level<=10,
      csa:sum size, cna:sum price*size,
      lvT:first level where .pdq.T<=sums price*size,     / first level at which running notional reaches T (0N if never)
      pT:first price where .pdq.T<=sums price*size
    by token,time from `level xasc select from lad where side=sd;
  p:string sd;
  nm:`$("n_",p,"_levels";"cum_",p,"_size_1";"cum_",p,"_notional_1";"cum_",p,"_size_5";"cum_",p,"_notional_5";
        "cum_",p,"_size_10";"cum_",p,"_notional_10";"cum_",p,"_size_all";"cum_",p,"_notional_all";p,"_levels_to_T";p,"_price_at_T");
  `token`time xkey (`token`time,nm) xcol `token`time`n`cs1`cn1`cs5`cn5`cs10`cn10`csa`cna`lvT`pT xcols 0!t}

ORD:`token`time`n_bid_levels`n_ask_levels,
    `cum_bid_size_1`cum_bid_notional_1`cum_ask_size_1`cum_ask_notional_1,
    `cum_bid_size_5`cum_bid_notional_5`cum_ask_size_5`cum_ask_notional_5,
    `cum_bid_size_10`cum_bid_notional_10`cum_ask_size_10`cum_ask_notional_10,
    `cum_bid_size_all`cum_bid_notional_all`cum_ask_size_all`cum_ask_notional_all,
    `bid_levels_to_T`bid_price_at_T`ask_levels_to_T`ask_price_at_T`imb_L1`imb_L5
ZERO:ORD except `token`time`bid_levels_to_T`bid_price_at_T`ask_levels_to_T`ask_price_at_T`imb_L1`imb_L5   / sums/counts: 0 when a side is empty

/ depth[snaps] -> keyed (token;time) with the ORD columns. One row per snapshot, including empty books.
depth:{[snaps]
  lad:ladder snaps;
  k:select token,time from snaps;
  r:(k lj .pdq.sideAgg[lad;`bid]) lj .pdq.sideAgg[lad;`ask];
  r:@[r;.pdq.ZERO;0^];
  two:exec (n_bid_levels>0)&n_ask_levels>0 from r;
  r:update imb_L1:(cum_bid_size_1-cum_ask_size_1)%cum_bid_size_1+cum_ask_size_1,
           imb_L5:(cum_bid_size_5-cum_ask_size_5)%cum_bid_size_5+cum_ask_size_5 from r where two;
  `token`time xkey .pdq.ORD xcols r}

\d .
