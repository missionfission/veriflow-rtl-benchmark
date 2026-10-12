# UART transmitter: frozen contract v1

Original open spec; MIT license. Implement module `uart`:

```verilog
module uart(input clk,rst,send,input [7:0] data,output tx,busy);
```

Inputs apply before rising edge, outputs sampled one unit after. Synchronous
active-high rst has priority and sets tx=1, busy=0. Transmit only, 8N1, LSB first,
four clock cycles per bit. If pre-edge busy=0 and send=1, capture data and drive
start bit tx=0, busy=1 immediately after this edge. Hold each bit for four cycles
INCLUDING acceptance cycle, followed by eight data bits then one stop bit.
Clear busy on edge acceptance+40 (40 total busy cycles). Ignore send while
pre-edge busy=1 including the final stop-bit edge. Idle tx=1. No variable baud,
receiver, parity, or external configuration.
