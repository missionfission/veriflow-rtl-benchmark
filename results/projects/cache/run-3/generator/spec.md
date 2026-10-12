# Cache specification

Module `cache` uses Verilog-2005 with inputs `clk`, `rst`, `req`, `write`,
`addr[7:0]`, `wdata[15:0]` and outputs `valid`, `hit`, `rdata[15:0]`.
Addresses select 16-bit words, with index `addr[1:0]` and tag `addr[7:2]`.

State consists of four line-valid bits, four 6-bit tags, four 16-bit cached
words, 256 16-bit backing words, and registered response outputs.

All changes occur on the rising clock edge; inputs are provided before that
edge and outputs are observed one time unit afterward. Synchronous active-high
reset has highest priority: invalidate every line, initialize backing word `a`
to `a * 257`, and clear all response outputs. Reset erases previous writes;
line tags and data may also be cleared for deterministic internal state.

Otherwise, a request produces `valid=1`. `hit` reports the line's valid/tag
match before the edge, including for writes. A read returns cached data on a
hit and backing data on a miss. A write updates backing memory and returns
`wdata`. Every request fills/replaces the indexed line with the requested tag
and returned data; writes therefore implement write-through and write-allocate.
Consecutive requests each produce a response, without stalls.

An idle edge (`req=0`) clears only `valid`; `hit` and `rdata` retain the last
response, and storage is unchanged. `write`, `addr`, and `wdata` are ignored
when idle. Reset also overrides a simultaneous request. Distinct tags at the
same index evict each other without losing writes in backing memory. Addresses
0 and 255, repeated writes, miss writes, and reset after writes follow the
same rules. No initial state is promised before a reset edge.
