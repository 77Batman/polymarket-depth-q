/ depth.q — descriptive depth metrics from the FULL ladder (acceptance #3; contract shared with reference/pandas_ref.py).
/ Descriptive only. Nothing here may relate a book feature to a LATER outcome (acceptance #8).
\l q/ladder.q
\d .pdq

T:1000f           / notional threshold (USD) for levels_to_T / price_at_T — same constant as pandas_ref.NOTIONAL_T
NS:1 5 10         / cumulative-depth level counts

/ 10. depth[lad] -> keyed (token;time) with EXACTLY these columns, in this order (the test compares against reference/expected_depth.csv):
/   n_bid_levels n_ask_levels
/   cum_bid_size_1 cum_bid_notional_1 cum_ask_size_1 cum_ask_notional_1
/   cum_bid_size_5 cum_bid_notional_5 cum_ask_size_5 cum_ask_notional_5
/   cum_bid_size_10 cum_bid_notional_10 cum_ask_size_10 cum_ask_notional_10
/   cum_bid_size_all cum_bid_notional_all cum_ask_size_all cum_ask_notional_all
/   bid_levels_to_T bid_price_at_T ask_levels_to_T ask_price_at_T
/   imb_L1 imb_L5
/ Definitions: cum_*_N = sums over the top N levels (level<=N); notional = price*size;
/   levels_to_T = first level where running notional (sums price*size) >= T, else 0n; price_at_T = price at that level, else 0n;
/   imb_L1 = (bid1-ask1)%(bid1+ask1) sizes at level 1, 0n if either side empty; imb_L5 same with level<=5 sums.
/ Hint: sums, first where, and a by-clause over (token;time;side) then a pivot of side -> columns.
depth:{[lad] '`nyi}

\d .
