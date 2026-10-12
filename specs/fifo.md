# FIFO: frozen contract v1

Original open spec; MIT license. Implement module `fifo`:

```verilog
module fifo(input clk,rst,push,pop,input [7:0] din,output [7:0] dout,output empty,full,output [2:0] count);
```

All inputs apply before the rising edge. Outputs are sampled one time unit after
that edge. Synchronous active-high rst has priority; it empties the queue.
Depth 4, width 8. dout is the front byte, or zero when empty. empty/full/count
reflect post-edge occupancy. Push/pop eligibility both use PRE-edge occupancy:
push iff not full; pop iff not empty. Simultaneous push/pop on full only pops;
on empty only pushes; otherwise both happen. Ignore din unless push is accepted.
