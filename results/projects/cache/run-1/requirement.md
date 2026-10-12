# Direct-mapped word cache: frozen contract v1

Original open spec; MIT license. Implement module `cache`:

```verilog
module cache(input clk,rst,req,write,input [7:0] addr,input [15:0] wdata,output valid,hit,output [15:0] rdata);
```

Inputs before rising edge, outputs sampled one unit after. Synchronous active-high
rst has priority. Four lines; write-through, write-allocate; internal 256-word
16-bit backing memory. addr is a WORD address; index=addr[1:0], tag=addr[7:2].
Reset invalidates all lines, initializes backing[a]=a*257 for a=0..255, and
zeroes valid/hit/rdata. Reset erases previous writes.
Each req=1 edge returns valid=1 and hit according to PRE-edge valid tag match.
Read returns latest backing value (cache value on hit). Write updates backing
and cache and returns wdata; hit still describes the pre-edge lookup.
Every request allocates/replaces its line. One response per request edge;
no stalls or external memory bus. With req=0, valid=0 and hit/rdata hold the last
response. Internal storage and reset behavior must be synthesizable.
