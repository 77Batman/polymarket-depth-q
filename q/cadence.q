/ cadence.q — data-quality layer (acceptance #5): classify every 900 s slot x token.
/ Classes: captured / one_sided / empty / attempted_failed / not_attempted, plus ambiguous for slots before HB0 (I-048).
\l q/load.q
\d .pdq

GRID:0D00:15:00                          / 900 s
HB0:2026.08.04D16:53:16.779495000        / first heartbeat ever written (I-048): earlier slots with no heartbeat are AMBIGUOUS, never imputed

/ slots[t0;t1] -> grid timestamps from GRID xbar t0 to GRID xbar t1 inclusive
slots:{[t0;t1] s0:GRID xbar t0; s0+GRID*til 1+`long$((GRID xbar t1)-s0)%GRID}

/ cadence[hb;snaps;tokens;t0;t1] -> slot token class
cadence:{[hb;snaps;tokens;t0;t1]
  g:([] slot:slots[t0;t1]) cross ([] token:tokens);
  h:select ok:all ok, nhb:count i by slot from update slot:.pdq.GRID xbar time from hb;                        / one heartbeat row per slot
  f:$[count hb; `slot`token xkey update ftok:1b from ungroup select slot,token:failed_tokens from update slot:.pdq.GRID xbar time from hb where 0<count each failed_tokens;
              ([slot:0#0Np; token:0#`] ftok:0#0b)];
  s:$[count snaps; `slot`token xkey select slot,token,nb,na from update slot:.pdq.GRID xbar time, nb:{count x`bids} each raw, na:{count x`asks} each raw from snaps;
              ([slot:0#0Np; token:0#`] nb:0#0; na:0#0)];
  r:((g lj h) lj f) lj s;
  r:update hasSnap:not null nb, hasHb:not null nhb from r;
  cls:?[r[`hasSnap]&(r[`nb]>0)&r[`na]>0;            `captured;
       ?[r[`hasSnap]&(r[`nb]>0)<>r[`na]>0;          `one_sided;
       ?[r`hasSnap;                                  `empty;
       ?[r[`hasHb]&(not 1b^r`ok) or 0b^r`ftok;       `attempted_failed;
       ?[(not r`hasHb)&r[`slot]<.pdq.HB0;                 `ambiguous;
       ?[not r`hasHb;                                `not_attempted;
                                                     `attempted_failed]]]]]];
  select slot,token,class from update class:cls from r}

/ cadenceReport[c] -> class -> n
cadenceReport:{[c] select n:count i by class from c}

\d .
