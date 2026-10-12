# UART transmitter specification

Module: `uart(input clk, rst, send, input [7:0] data, output tx, busy)`.
All state changes occur on the rising clock edge; inputs are supplied before
the edge and outputs are observed one time unit afterward.

* `rst`: synchronous active-high reset, with priority over every other action.
  It sets `tx=1`, `busy=0` and clears internal frame state.
* `send`: accepted only when pre-edge `busy=0`. Acceptance captures all eight
  data bits and immediately sets `tx=0`, `busy=1`.
* `data`: captured only on acceptance; changes during transmission have no effect.
* `tx`: serial output, idle high, 8N1, least significant data bit first.
* `busy`: high for exactly 40 cycles per accepted frame.

State consists of registered outputs, a captured eight-bit shift register, and
a six-bit frame-cycle counter. The acceptance edge initializes the counter to
zero. For acceptance edge A, the values after each edge are:

| Edges | tx | busy |
| --- | --- | --- |
| A through A+3 | 0 (start) | 1 |
| A+4+4k through A+7+4k, k=0..7 | captured data[k] | 1 |
| A+36 through A+39 | 1 (stop) | 1 |
| A+40 | 1 (idle) | 0 |

Thus each bit occupies four cycles, including the acceptance cycle for the
start bit. Sends while pre-edge busy is high are ignored, including A+40;
a continuously asserted send can first start another frame at A+41. Reset
at any edge aborts the current frame, including at acceptance or completion.
No requests are queued. With no accepted request, idle remains high. Operation
requires a reset before relying on initialized state. There is no receiver,
parity, variable baud rate, or external configuration.
