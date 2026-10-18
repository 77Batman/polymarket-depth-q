/ tests/run.q — red-first test runner for polymarket-depth-q.  Run:  q tests/run.q
/ Every test is trapped: an unimplemented function ('nyi) or any error shows as FAIL with the message.
/ Exit code 1 if anything fails. Tests 1-2 only check the provided helpers and should be green from the start.
\l q/depth.q
\l q/cadence.q

TOL:1e-9
RES:()                                             / list of (name; status; msg)
rec:{[n;s;m] RES,:enlist (n;s;m); -1 (string s)," ",n,$[s=`FAIL;": ",m;""];}
t:{[name;f] r:@[{(`PASS;"")}f@;`;{(`FAIL;x)}]; rec[name;r 0;r 1]}   / run f with no args; trap errors
assert:{[c;m] if[not c;'m]}

/ compare two keyed tables (same key columns) on `cols with tolerance; nulls equal only to nulls. returns (nCompared;nMismatch;maxAbsDiff)
cmp:{[a;b;cols]
  k:keys a; bb:(k,`$string[cols],\:"_b") xcol (k,cols)#0!b;
  j:(0!a) ij k xkey bb;
  if[0=count j;'"no overlapping keys"];
  one:{[j;c] x:j c; y:j`$string[c],"_b"; both:not null[x] or null y; mis:(null[x]<>null y) or both & abs[x-y]>TOL; (count x;sum mis;$[any both;max abs[x-y] where both;0f])};
  d:one[j;] each cols; (sum d[;0];sum d[;1];max d[;2])}

/ ---------------------------------------------------------------- provided helpers (should be green)
t["util: iso parses with fraction and tz";        {assert[2026.08.05D02:33:43.118000000=.pdq.iso "2026-08-05T02:33:43.118000+00:00";"iso frac"]}]
t["util: iso parses without fraction";            {assert[2026.08.31D23:21:35.000000000=.pdq.iso "2026-08-31T23:21:35+00:00";"iso nofrac"]}]

/ ---------------------------------------------------------------- 1. loaders (fixtures)
t["load: loadObs returns 32 typed rows";          {o:.pdq.loadObs "tests/fixtures/obs_small.csv"; assert[32=count o;"count"]; assert[`token`field`time`ktime`value~cols o;"cols"]; assert[12h=type o`time;"time type"]}]
t["load: scalars has one row per snapshot";       {s:.pdq.scalars .pdq.loadObs "tests/fixtures/obs_small.csv"; assert[3=count s;"3 snapshots"]; assert[0.475=first exec mid from s where token=`A,time=2026.08.10D00:00:30;"mid A"]; assert[null first exec mid from s where token=`A,time=2026.08.10D00:15:30;"mid one-sided is null"]}]
t["load: book unpivots l1..l10";                  {b:.pdq.book .pdq.loadObs "tests/fixtures/obs_small.csv"; assert[6=count b;"3 bid + 2 ask + 1 bid rows"]; assert[`time`token`side`level~keys b;"key"]; assert[0.40=first exec price from b where token=`A,side=`bid,level=2;"bid l2 price"]}]
t["load: loadSnapshots parses 3 raw books";       {s:.pdq.loadSnapshots "tests/fixtures/snaps_small.jsonl"; assert[3=count s;"3"]; assert[99h=type first s`raw;"raw is dict"]; assert[3=count first exec raw[;`bids] from s where token=`A;"3 bids"]}]
t["load: loadHeartbeats parses failed_tokens";    {h:.pdq.loadHeartbeats "tests/fixtures/hb_small.csv"; assert[3=count h;"3"]; assert[(`A`B)~h[2;`failed_tokens];"failed list"]; assert[not h[2;`ok];"ok false"]}]

/ ---------------------------------------------------------------- 2. ladder + reconciliation (acceptance #2)
t["ladder: sorted bids desc / asks asc, 1-based levels"; {l:.pdq.ladder .pdq.loadSnapshots "tests/fixtures/snaps_small.jsonl"; assert[6=count l;"6 levels"]; assert[0.45 0.40 0.30~exec price from l where token=`A,side=`bid,time=2026.08.10D00:00:30;"bid order"]; assert[1 2~exec level from l where token=`A,side=`ask,time=2026.08.10D00:00:30;"ask levels"]}]
t["ladder: ladderTop10 equals stored book on fixtures"; {o:.pdq.loadObs "tests/fixtures/obs_small.csv"; l:.pdq.ladder .pdq.loadSnapshots "tests/fixtures/snaps_small.jsonl"; r:.pdq.recon[.pdq.book o;.pdq.ladderTop10 l;`price`size]; assert[0=r`nMismatch;"mismatch ",string r`nMismatch]; assert[6=r`nCompared;"compared"]}]
t["ladder: recomputeScalars equals stored scalars";     {o:.pdq.loadObs "tests/fixtures/obs_small.csv"; l:.pdq.ladder .pdq.loadSnapshots "tests/fixtures/snaps_small.jsonl"; c:`n_bid_levels`n_ask_levels`two_sided`best_bid`best_ask`bid_size_at_touch`ask_size_at_touch`mid`spread; r:.pdq.recon[.pdq.scalars o;.pdq.recomputeScalars l;c]; assert[0=r`nMismatch;"mismatch ",string r`nMismatch]; assert[TOL>=r`maxAbsDiff;"maxAbsDiff"]}]
t["recon: detects a doctored stored value";             {o:.pdq.loadObs "tests/fixtures/obs_small.csv"; o:update value:0.46 from o where token=`A,field=`best_bid,time=2026.08.10D00:00:30; l:.pdq.ladder .pdq.loadSnapshots "tests/fixtures/snaps_small.jsonl"; r:.pdq.recon[.pdq.scalars o;.pdq.recomputeScalars l;`best_bid`best_ask]; assert[1=r`nMismatch;"should find exactly 1"]; assert[abs[0.01-r`maxAbsDiff]<TOL;"diff 0.01"]}]

/ ---------------------------------------------------------------- 3. depth (acceptance #3) on fixtures
t["depth: fixture values";                        {d:.pdq.depth .pdq.ladder .pdq.loadSnapshots "tests/fixtures/snaps_small.jsonl"; a:d[(`A;2026.08.10D00:00:30)]; assert[5f=a`cum_bid_size_1;"cum_bid_size_1"]; assert[35f=a`cum_bid_size_5;"cum_bid_size_5"]; assert[abs[12.25-a`cum_bid_notional_all]<TOL;"notional all"]; assert[null a`bid_levels_to_T;"T not reached"]; assert[abs[(5-3)%8-a`imb_L1]<TOL;"imb_L1"]; assert[null d[(`A;2026.08.10D00:15:30)]`imb_L1;"one-sided imb null"]}]

/ ---------------------------------------------------------------- 4. cadence (acceptance #5) on fixtures
t["cadence: slots on the 900 s grid";             {s:.pdq.slots[2026.08.10D00:00:05;2026.08.10D00:45:05]; assert[4=count s;"4 slots"]; assert[2026.08.10D00:15:00=s 1;"second slot"]}]
t["cadence: five classes on fixtures";            {h:.pdq.loadHeartbeats "tests/fixtures/hb_small.csv"; s:.pdq.loadSnapshots "tests/fixtures/snaps_small.jsonl";
   c:.pdq.cadence[h;s;`A`B;2026.08.10D00:00;2026.08.10D00:45]; r:.pdq.cadenceReport c;
   assert[8=count c;"4 slots x 2 tokens"]; assert[1=r[`captured]`n;"captured"]; assert[1=r[`one_sided]`n;"one_sided"]; assert[1=r[`empty]`n;"empty"];
   assert[3=r[`attempted_failed]`n;"attempted_failed"]; assert[2=r[`not_attempted]`n;"not_attempted"]; assert[0=0^r[`ambiguous]`n;"ambiguous 0"]}]
t["cadence: pre-HB0 slots are ambiguous, never imputed"; {c:.pdq.cadence[0#.pdq.loadHeartbeats "tests/fixtures/hb_small.csv";0#.pdq.loadSnapshots "tests/fixtures/snaps_small.jsonl";`A`B;2026.08.04D16:00;2026.08.04D17:00];
   r:.pdq.cadenceReport c; assert[8=r[`ambiguous]`n;"8 ambiguous"]; assert[2=r[`not_attempted]`n;"2 not_attempted after HB0"]}]

/ ---------------------------------------------------------------- 5. the real sample (only if data/ exists) — acceptance #2 and #3 at full sample size
if[count key `:data/obs.csv;
  t["SAMPLE recon: stored l1-l10 vs raw-JSON ladder (acceptance #2)"; {o:.pdq.loadObs "data/obs.csv"; l:.pdq.ladder .pdq.loadSnapshots "data/snapshots.jsonl"; r:.pdq.recon[.pdq.book o;.pdq.ladderTop10 l;`price`size];
      -1 "  book  nCompared=",string[r`nCompared]," nMismatch=",string[r`nMismatch]," maxAbsDiff=",string r`maxAbsDiff; assert[0=r`nMismatch;"MISMATCH — this is a data incident (DATA-INFRA-005 §3)"]}];
  t["SAMPLE recon: stored scalars vs recomputed (acceptance #2)";   {o:.pdq.loadObs "data/obs.csv"; l:.pdq.ladder .pdq.loadSnapshots "data/snapshots.jsonl"; c:`n_bid_levels`n_ask_levels`two_sided`best_bid`best_ask`bid_size_at_touch`ask_size_at_touch`mid`spread; r:.pdq.recon[.pdq.scalars o;.pdq.recomputeScalars l;c];
      -1 "  scalars nCompared=",string[r`nCompared]," nMismatch=",string[r`nMismatch]," maxAbsDiff=",string r`maxAbsDiff; assert[0=r`nMismatch;"MISMATCH — data incident"]}];
  t["SAMPLE depth: q vs pandas reference (acceptance #3)";          {d:.pdq.depth .pdq.ladder .pdq.loadSnapshots "data/snapshots.jsonl";
      e:("S*",24#"F";enlist csv) 0: `:reference/expected_depth.csv; e:`token`time xcol update .pdq.isos event_time from e; e:`token`time xkey e;
      c:cols[0!d] except `token`time; r:cmp[d;e;c]; -1 "  depth nCompared=",string[r 0]," nMismatch=",string[r 1]," maxAbsDiff=",string r 2; assert[0=r 1;"mismatch vs pandas"]}];
  ];

/ ---------------------------------------------------------------- summary
nf:sum `FAIL=RES[;1]; -1 "\n",string[count RES]," tests, ",string[nf]," failed";
exit $[nf>0;1;0]
