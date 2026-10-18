/ util.q — small helpers. Provided (lookup-grade, not the learning content).
\d .pdq

/ ISO-8601 string -> q timestamp (UTC). Handles "…+00:00" suffix and optional fractional seconds.
iso:{[s] "P"$ssr[first "+" vs s;"T";"D"]}

/ ISO strings in bulk
isos:{[S] iso each S}

/ absolute max over a list, ignoring nulls
amax:{[x] $[0=count x;0n;max abs x where not null x]}

/ assert helper used by tests: returns `pass/`fail with a message
chk:{[name;cond] $[cond;`pass;`fail],enlist name}

\d .
