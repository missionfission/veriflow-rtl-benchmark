# FIFO specification

Module `fifo` uses the exact port interface in `requirement.md`:

| Port | Direction | Width | Meaning |
|---|---|---|---|
| clk | input | 1 | Rising-edge clock |
| rst | input | 1 | Synchronous active-high reset |
| push, pop | input | 1 each | Enqueue/dequeue requests |
| din | input | 8 | Byte to enqueue |
| dout | output | 8 | Front byte; zero when empty |
| empty, full | output | 1 each | Occupancy is zero/four |
| count | output | 3 | Occupancy, from zero through four |

State consists of four 8-bit storage entries, wrapping 2-bit read/write
pointers, and a 3-bit occupancy register. Reset establishes occupancy zero
and both pointers zero; unused storage need not be reset.

At each rising edge, reset takes priority over both requests. Otherwise,
accept push exactly when `push && (pre_count < 4)` and accept pop exactly
when `pop && (pre_count > 0)`. Accepted push writes `din` and advances the
write pointer; accepted pop advances the read pointer. Occupancy increments
for push alone, decrements for pop alone, and stays unchanged for both/neither.
The queue preserves insertion order. Ignore `din` for a rejected push.

Inputs are applied before the edge and outputs checked one time unit after
it. Outputs reflect the resulting state: `empty = (count == 0)`,
`full = (count == 4)`, and `dout` is the resulting front byte or zero.

Boundary cases: simultaneous requests at empty accept only push (count one);
at full accept only pop (count three); at occupancy one through three accept
both (count unchanged). A pop at empty and push at full alone do nothing.
Pointer wraparound must preserve ordering through repeated fill/drain cycles.
State before the first reset is unspecified.
