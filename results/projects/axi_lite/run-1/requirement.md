# AXI-lite register slave subset: frozen contract v1

Original open spec; MIT license. Implement module `axi_lite`:

```verilog
module axi_lite(input clk,rst,awvalid,input [3:0] awaddr,input wvalid,input [31:0] wdata,input [3:0] wstrb,input bready,arvalid,input [3:0] araddr,input rready,output awready,wready,bvalid,output [1:0] bresp,output arready,rvalid,output [31:0] rdata,output [1:0] rresp);
```

Inputs before rising edge, outputs sampled one unit after. Synchronous active-high
rst has priority, clearing all registers, buffers, response valids and rdata.
Four 32-bit registers addressed by bits [3:2]; low bits ignored. Responses always
OKAY (bresp=rresp=0). Separate single-entry AW and W buffers:
awready=!has_aw&&!bvalid, wready=!has_w&&!bvalid. Capture each valid channel when
its PRE-edge ready is high. Commit only if BOTH buffers were populated and
bvalid=0 BEFORE this edge; apply selected wstrb bytes, clear buffers, assert
bvalid. Never commit on an edge that captures a new buffer. Hold bvalid until
bready; clearing bvalid cannot accept new channels on that edge.

Read: arready=!rvalid. Capture address and PRE-edge register value on
arvalid&&arready; assert rvalid. Hold rvalid/rdata under backpressure; clear
rvalid on rvalid&&rready, without simultaneous replacement. rdata holds while
idle. A read on a write-commit edge sees the OLD register value. No bursts,
errors, outstanding queues or external memory; this is an intentionally
restricted AXI-lite subset with explicit cycle timing.
