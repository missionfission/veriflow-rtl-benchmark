# Cache specification

## Ports
`cache` has inputs `clk`, `rst`, `req`, `write`, `addr[7:0]`, and
`wdata[15:0]`; outputs are registered `valid`, `hit`, and `rdata[15:0]`.
Addresses select words, not bytes. Inputs are supplied before a rising clock
edge and outputs are sampled one time unit afterward.

## State
Four direct-mapped lines each hold a valid bit, six-bit tag, and 16-bit data.
The index is `addr[1:0]` and tag is `addr[7:2]`. Internal backing storage
contains 256 16-bit words. Storage uses synthesizable register arrays.

## Cycle behavior
Synchronous active-high reset has priority over requests. Every reset edge
invalidates all four lines, initializes backing word `a` to `a * 257`, and
sets all outputs to zero. Cached tags/data are also cleared for determinism.

Without reset, every `req=1` edge sets `valid=1`. `hit` reports whether the
selected line was valid and its tag matched before the edge. A read returns
the cache data on a hit, otherwise backing data. A write updates both backing
and cache and returns `wdata`. Every request installs its tag and returned
data in the selected line and marks it valid. There are no stalls or memory
bus transactions; consecutive requests produce consecutive responses.

On `req=0`, `valid` becomes zero while `hit` and `rdata` retain the previous
response. No storage changes occur.

## Edge cases
Conflicting addresses replace the same line, but retain independent backing
values. Writes allocate on a miss and still report the pre-edge lookup result.
Reset erases prior writes, including when a write request is simultaneously
asserted. Repeated reset edges repeat initialization. Addresses 0 and 255 and
all 16-bit write values are supported. Before the first reset, state is
unspecified.
