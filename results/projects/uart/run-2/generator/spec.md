# UART transmitter specification

Module: `uart(input clk,rst,send,input [7:0] data,output tx,busy)`.
All inputs are sampled on rising `clk`; outputs take effect after that edge.
`rst` is synchronous, active high, and takes priority over transmission and
acceptance. Reset drives `tx=1`, `busy=0`, and discards any active frame.

When pre-edge `busy=0` and `send=1`, capture all eight data bits and begin
an 8N1 frame. Number the acceptance edge A. Outputs are:

| Edges | tx | busy |
| --- | --- | --- |
| A through A+3 | 0 (start) | 1 |
| A+4+4*i through A+7+4*i, i=0..7 | captured data[i] | 1 |
| A+36 through A+39 | 1 (stop) | 1 |
| A+40 | 1 (idle) | 0 |

Internal state consists of the captured byte, a six-bit elapsed-cycle counter,
and registered `tx` and `busy`. Acceptance initializes the counter to zero;
active edges advance it through 39, then clear busy. Data transitions occur
every four cycles. Idle holds `tx=1` and `busy=0`.

Changes to data after acceptance have no effect. Send while pre-edge busy is
high is ignored, including A+40. A continuously asserted send can next be
accepted at A+41. Reset during any bit aborts immediately; send on a reset edge
is ignored. There is no receiver, parity, baud selection, or configuration.
