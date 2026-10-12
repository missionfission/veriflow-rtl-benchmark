# FIFO specification

Module `fifo` is Verilog-2005, depth 4 and byte width 8.

Ports: inputs `clk`, `rst`, `push`, `pop`, and `din[7:0]`; outputs
`dout[7:0]`, `empty`, `full`, and `count[2:0]`.

State consists of four byte storage entries, two 2-bit circular pointers
(read/front and write/next-free), and a 3-bit occupancy counter (0 through 4).

At each rising edge, synchronous active-high `rst` takes priority and resets
both pointers and occupancy to zero. Storage contents need not reset because
unoccupied entries are never exposed. Otherwise, acceptance is determined
from occupancy before the edge: accept push when `push && count < 4`; accept
pop when `pop && count > 0`. An accepted push writes `din` and advances the
write pointer modulo 4. An accepted pop advances the read pointer modulo 4.
Increment occupancy for push alone, decrement for pop alone, and retain it
when both or neither are accepted. Retained entries preserve insertion order.

Outputs reflect current state, including the updated state one time unit after
each rising edge: `empty = (count == 0)`, `full = (count == 4)`, and `dout` is
the front stored byte when nonempty, otherwise zero.

Edge cases:

- Empty: pop is ignored; simultaneous push/pop accepts only push.
- Full: push is ignored; simultaneous push/pop accepts only pop.
- Occupancy 1 through 3: simultaneous push/pop accepts both, keeping count.
- Neither operation: all state holds. Rejected pushes ignore `din`.
- Reset with any operation combination empties the queue without accepting either.
- No asynchronous reset, fall-through bypass, or full-queue replacement occurs.
- State is unspecified until a rising edge with `rst` asserted.
