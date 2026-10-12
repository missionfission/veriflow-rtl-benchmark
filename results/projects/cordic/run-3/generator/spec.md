# CORDIC specification

Module: `cordic`, synthesizable Verilog-2005.

| Port | Direction | Width | Meaning |
| --- | --- | --- | --- |
| clk | input | 1 | Rising-edge clock |
| rst | input | 1 | Synchronous active-high reset |
| valid_in | input | 1 | Accept inputs at the rising edge |
| x_in, y_in, z_in | input | 16 each | Signed two's-complement input bit patterns |
| valid_out | output | 1 | Registered acceptance indicator |
| x_out, y_out, z_out | output | 16 each | Registered signed result bit patterns |

State consists of the three output registers and valid_out. There is no busy
state or pipeline: each asserted valid_in computes all four iterations and
registers the final result at that acceptance edge. Inputs must be stable before
the rising edge; outputs are sampled one time unit afterward.

For iterations i=0,1,2,3, use angles 8192,4836,2555,1297 respectively. One turn
is 65536 angle units. Each iteration uses signed 16-bit old x,y,z. For z>=0,
compute x'=x-(y>>>i), y'=y+(x>>>i), z'=z-angle[i]. For z<0, compute
x'=x+(y>>>i), y'=y-(x>>>i), z'=z+angle[i]. Both coordinate updates use the same
old x and y. Arithmetic right shifts round toward negative infinity. Wrap all
three updated values to signed 16 bits after every iteration.

On each rising edge, rst takes priority over valid_in, clearing all four output
registers. Otherwise valid_out becomes valid_in. When valid_in is zero, the
three data outputs hold their preceding values. Consecutive valid inputs are
accepted on consecutive edges. Reset is synchronous and has no effect between
edges. State before the first reset or accepted input is unspecified.

Every 16-bit input pattern is defined, including overflow, -32768, zero, and
negative values with discarded shift bits. z=0 selects the nonnegative branch.
There is no gain correction, range reduction, or saturation. Ordinary tests
concentrate on x,y in [-1000,1000] and z in [-8192,8192], while boundary and
full-range tests verify wrapping and signed behavior.
