# UART transmitter specification

Module: `uart(input clk, rst, send, input [7:0] data, output tx, busy)`.
All inputs are sampled on rising `clk`; outputs are observed one time unit later.
`rst` is synchronous, active high, and has highest priority: `tx=1`, `busy=0`,
and any frame is discarded.

When pre-edge `busy=0` and `send=1`, latch `data`, set `busy=1`, and drive
`tx=0` on that edge (acceptance edge A). Transmit 8N1, least significant data
bit first, with exactly four clocks per bit:

| Edges relative to A | tx | busy |
| --- | --- | --- |
| 0–3 | Start: 0 | 1 |
| 4–7 | Captured data[0] | 1 |
| 8–11 | Captured data[1] | 1 |
| 12–15 | Captured data[2] | 1 |
| 16–19 | Captured data[3] | 1 |
| 20–23 | Captured data[4] | 1 |
| 24–27 | Captured data[5] | 1 |
| 28–31 | Captured data[6] | 1 |
| 32–35 | Captured data[7] | 1 |
| 36–39 | Stop: 1 | 1 |
| 40 | Idle: 1 | 0 |

Internal state consists of a ten-bit frame shift register, bit index 0–9,
two-bit cycle counter 0–3, and registered tx/busy. The acceptance cycle is
counter zero. Every fourth subsequent edge advances the bit; after the stop
bit, the next edge clears busy.

Ignore all sends when pre-edge busy is high, including A+40. A held send can
therefore accept its next byte at A+41. Changes to data during transmission
do not affect the captured frame. Idle remains tx=1, busy=0 without send.
Reset suppresses a simultaneous send and may interrupt any frame phase.
There is no receiver, parity, configurable baud rate, or external configuration.
