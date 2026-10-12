# CORDIC specification

Module `cordic` has inputs `clk`, `rst`, `valid_in`, and 16-bit `x_in`,
`y_in`, `z_in`; outputs are `valid_out` and 16-bit `x_out`, `y_out`, `z_out`.
All coordinate and angle bit patterns represent signed two's-complement values.
One turn is 65536 angle units.

State consists of the three output registers and `valid_out`. At each rising
clock edge:

- Synchronous active-high `rst` takes priority and sets all four outputs to zero.
- Otherwise `valid_out` becomes `valid_in`. If `valid_in` is zero, the coordinate
  and angle outputs hold their previous values.
- If `valid_in` is one, perform four rotation iterations combinationally and
  register the final values at that same edge. Outputs are observable one time
  unit after the edge; back-to-back inputs are accepted every cycle.

Iteration indices are 0, 1, 2, 3 with angles 8192, 4836, 2555, 1297.
For signed old `z >= 0`, compute `x' = x - (y >>> i)`,
`y' = y + (x >>> i)`, `z' = z - angle[i]`. Otherwise compute
`x' = x + (y >>> i)`, `y' = y - (x >>> i)`, `z' = z + angle[i]`.
Both coordinate calculations use the same old x/y pair. Arithmetic shifts
round toward negative infinity. Each of x, y, and z wraps to signed 16 bits
after each iteration, before the next sign decision or shift.

Zero angle takes the nonnegative branch. Negative odd coordinates require
floor rounding. Overflow, including angle overflow, wraps at every iteration;
all 16-bit input patterns are defined. There is no gain correction, range
reduction, saturation, busy state, or pipeline latency. Reset may coincide with
a valid input and discards that input. Initial state before the first clocked
reset is unspecified.
