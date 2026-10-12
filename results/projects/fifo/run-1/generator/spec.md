# FIFO specification

Module `fifo` uses the exact ports in `requirement.md`: inputs `clk`, `rst`,
`push`, `pop`, and `din[7:0]`; outputs `dout[7:0]`, `empty`, `full`, and
`count[2:0]`. All ports are unsigned. Depth is four bytes.

State consists of four byte storage locations, two 2-bit circular pointers
(read/front and next write), and a 3-bit occupancy counter (0 through 4).
Initialization requires a rising edge with `rst=1`.

At each rising edge, synchronous active-high reset takes priority, clears both
pointers and occupancy, and discards any push/pop. Storage need not be reset.
Otherwise, acceptance is computed from pre-edge occupancy:

| Request | Acceptance | State update |
| --- | --- | --- |
| push | `push && count < 4` | Store `din` at write pointer; advance write pointer |
| pop | `pop && count > 0` | Advance read pointer |

Pointers wrap modulo four. Occupancy increases by one for push only, decreases
by one for pop only, and stays unchanged if both or neither are accepted.
`din` has no effect for an unaccepted push. FIFO order is preserved.

Outputs continuously reflect current state: `empty=(count==0)`,
`full=(count==4)`, and `dout` is the front stored byte when nonempty, otherwise
zero. Post-edge outputs must be valid one time unit after the rising edge.

At empty, simultaneous push/pop accepts only push; its byte becomes the front.
At full, simultaneous push/pop accepts only pop and discards `din`. At
occupancies 1 through 3, simultaneous push/pop accepts both, preserving count;
at occupancy 1 the pushed byte becomes the new front. Empty pops and full
pushes are ignored. Reset also forces `dout=0`, `empty=1`, and `full=0`.
