# axi_lite specification

## Ports

Inputs: `clk`, synchronous active-high `rst`; write address `awvalid`,
`awaddr[3:0]`; write data `wvalid`, `wdata[31:0]`, `wstrb[3:0]`;
write response acceptance `bready`; read address `arvalid`, `araddr[3:0]`;
read response acceptance `rready`.

Outputs: `awready`, `wready`, `bvalid`, `bresp[1:0]`, `arready`,
`rvalid`, `rdata[31:0]`, `rresp[1:0]`. Both response codes are always zero
(OKAY). The module name and port order match requirement.md.

## State

Four 32-bit registers; independent one-entry write address and write data
buffers, with occupied flags, address, data and byte strobes; write response
valid; read response valid and data. Address bits [3:2] select a register;
bits [1:0] are ignored.

## Cycle behavior

All decisions use state immediately before a rising clock edge. Outputs are
observed one time unit after the edge. Reset takes priority and clears all
registers, buffer contents and flags, response valids, and read data.

Combinational ready signals are `awready = !has_aw && !bvalid`,
`wready = !has_w && !bvalid`, and `arready = !rvalid`.
Each write channel captures when its valid and pre-edge ready are high.
When both write buffers are already occupied and pre-edge bvalid is low,
the write commits: each asserted strobe updates its corresponding byte,
both occupied flags clear, and bvalid asserts. An edge capturing a buffer
cannot commit. An asserted bvalid clears on bready, with no write channel
acceptance or commit on that response-clear edge.

A read request captures the pre-edge selected register value when arvalid
and pre-edge arready are high, asserting rvalid. A valid response clears
on rready and cannot be replaced on the same edge. rdata holds during
backpressure and while idle.

## Edge cases

AW and W may arrive together or in either order, with arbitrary gaps.
Partial strobes preserve unselected bytes; zero strobes still produce a
write response. Response backpressure stalls the corresponding requests.
A read concurrent with write commit returns the old register value.
Reset discards partial writes and pending responses. Ready is derived
from cleared state after reset, even if rst remains asserted; reset still
prevents capture. There are no bursts, errors, queues, or external memory.
