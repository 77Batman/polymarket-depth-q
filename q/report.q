/ report.q — print the numbers that go in the README and back to the firm (DATA-INFRA-005 §3).  Run:  q q/report.q
\l q/depth.q
\l q/cadence.q

o:.pdq.loadObs "data/obs.csv"
s:.pdq.loadSnapshots "data/snapshots.jsonl"
h:.pdq.loadHeartbeats "data/heartbeats.csv"
m:.j.k raze read0 `:data/MANIFEST.json
toks:`$m[`tokens]

-1 "== DATA-INFRA-005 report ==";
-1 "window ",m[`window;`start_inclusive]," -> ",m[`window;`end_exclusive]," (exclusive) · tokens ",string[count toks]," · snapshots ",string[count s]," · obs rows ",string[count o]," · heartbeats ",string count h;

r1:.pdq.recon[.pdq.book o;.pdq.ladderTop10 .pdq.ladder s;`price`size];
-1 "recon l1-l10 (price,size):  rows=",string[r1`nCompared],"  mismatches=",string[r1`nMismatch],"  maxAbsDiff=",string r1`maxAbsDiff;
c:`n_bid_levels`n_ask_levels`two_sided`best_bid`best_ask`bid_size_at_touch`ask_size_at_touch`mid`spread;
r2:.pdq.recon[.pdq.scalars o;.pdq.recomputeScalars s;c];
-1 "recon scalars:              rows=",string[r2`nCompared],"  mismatches=",string[r2`nMismatch],"  maxAbsDiff=",string r2`maxAbsDiff;

lad:.pdq.ladder s;
-1 "ladder: max levels seen  bid=",string[exec max level from lad where side=`bid],"  ask=",string[exec max level from lad where side=`ask],"  — stored scalars stop at 10";
d:.pdq.depth s;
-1 "depth: snapshots where $",string[.pdq.T]," notional is NOT reached within the book  bid=",string[exec sum null bid_levels_to_T from d],"  ask=",string exec sum null ask_levels_to_T from d;
-1 "depth: snapshots where it IS reached but only beyond level 10 (invisible to the stored scalars)  bid=",string[exec sum bid_levels_to_T>10 from d],"  ask=",string exec sum ask_levels_to_T>10 from d;

t0:.pdq.iso m[`window;`start_inclusive],"T00:00:00+00:00"; t1:(.pdq.iso m[`window;`end_exclusive],"T00:00:00+00:00")-.pdq.GRID;
cad:.pdq.cadence[h;s;toks;t0;t1];
-1 "cadence over ",string[count .pdq.slots[t0;t1]]," slots x ",string[count toks]," tokens:";
show .pdq.cadenceReport cad;
-1 "ambiguous (pre-",string[.pdq.HB0],") slots in window: ",string exec sum class=`ambiguous from cad;
exit 0
