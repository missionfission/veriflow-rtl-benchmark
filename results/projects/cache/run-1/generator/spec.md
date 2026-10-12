# Cache specification

Module: `cache`, synthesizable Verilog-2005.

| Port | Direction | Width | Meaning |
|---|---|---|---|
| clk | input | 1 | Rising-edge clock |
| rst | input | 1 | Synchronous active-high reset, highest priority |
| req | input | 1 | Perform one request on this edge |
| write | input | 1 | Write if asserted; otherwise read |
| addr | input | 8 | Word address, 0..255 |
| wdata | input | 16 | Write value |
| valid | output | 1 | This edge produced a response |
| hit | output | 1 | Requested line was valid with matching tag before this edge |
| rdata | output | 16 | Read value or echoed write value |

State consists of 256 backing words of 16 bits, four cache words of 16 bits,
four tags of 6 bits, four line-valid bits, and registered response outputs.
Index is `addr[1:0]`; tag is `addr[7:2]`. No external memory bus or stalls.

Inputs are established before a rising edge; outputs are sampled one time unit
after it. On reset, invalidate every line, initialize backing word `a` to
`a * 257`, and clear valid, hit, and rdata. Cache data and tags may be cleared
as well. Reset erases all writes, including when req and write are asserted.

On each non-reset edge with req asserted, set valid to one and calculate hit
from the pre-edge line-valid and tag state. A read returns the cache word on a
hit and the backing word on a miss. A write updates both backing and cache,
and returns wdata regardless of hit. Every read or write allocates/replaces
the indexed line with the requested tag and returned value.

On a non-reset edge with req deasserted, clear only response valid. Retain hit,
rdata, and all memory/cache state; write, addr, and wdata are ignored.

Consecutive requests each receive a response. The first request after reset
misses; repeated addresses hit. Different tags sharing an index evict one
another without losing backing writes. Writes on a miss allocate, writes on
a hit still report the pre-edge hit, zero data is ordinary valid data, and
addresses 0 and 255 obey the same behavior. State before the first reset is
unspecified.
