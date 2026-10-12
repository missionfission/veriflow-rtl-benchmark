# cordic specification

## Ports and state
`cordic` has one-bit inputs `clk`, `rst`, `valid_in`; 16-bit inputs
`x_in`, `y_in`, `z_in`; one-bit output `valid_out`; and 16-bit outputs
`x_out`, `y_out`, `z_out`. All coordinates and angles represent signed
16-bit two's-complement values. State consists of the three output registers
and the validity register. No initialization before a reset edge is specified.

## Cycle behavior
At every rising clock edge, synchronous active-high `rst` takes priority and
sets all four outputs to zero. Otherwise `valid_out` becomes `valid_in`.
When `valid_in` is high, apply four rotation iterations to that edge's inputs
and register the final result at the same edge. Outputs are sampled one time
unit after the edge. When `valid_in` is low, the coordinate/angle outputs hold.
There is no busy state or additional pipeline latency; consecutive inputs are
accepted on consecutive edges.

For iteration i = 0, 1, 2, 3, the angles are respectively 8192, 4836, 2555,
1297 (65536 angle units per turn). Using the old x, y, z of that iteration:

- If signed z >= 0: x' = x - (y >>> i), y' = y + (x >>> i), z' = z - angle[i].
- Otherwise: x' = x + (y >>> i), y' = y - (x >>> i), z' = z + angle[i].

Both coordinate updates use the same old pair. Arithmetic right shifts round
toward negative infinity. Each result wraps to signed 16 bits after every
iteration, before the next direction decision and shift.

## Edge cases
All input bit patterns are defined, including -32768 and 32767. Zero angle
selects the nonnegative branch. Overflow wraps rather than saturating. Reset
also clears outputs during valid input and bubbles. Reset is synchronous;
changes between rising edges do not clear state. There is no gain correction,
range reduction, saturation, or restriction to the ordinary test ranges.
