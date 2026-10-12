# axi_lite specification

## Ports

The module is `axi_lite`, with the exact Verilog port order and widths in
`requirement.md`. Inputs are `clk`, synchronous active-high `rst`, `awvalid`,
`awaddr[3:0]`, `wvalid`, `wdata[31:0]`, `wstrb[3:0]`, `bready`, `arvalid`,
`araddr[3:0]`, and `rready`. Outputs are `awready`, `wready`, `bvalid`,
`bresp[1:0]`, `arready`, `rvalid`, `rdata[31:0]`, and `rresp[1:0]`.

## State

Four 32-bit registers, one AW buffer (address and occupancy), one W buffer
(data, byte strobes, and occupancy), write-response valid, read-response valid,
and read-response data. Address bits [3:2] select a register; [1:0] are ignored.
All state, including buffer contents, clears on a rising edge with `rst=1`.
Responses are permanently OKAY (`2'b00`).

## Cycle behavior

All decisions use state immediately before the rising edge. Outputs are checked
one time unit after that edge. Ready signals are combinational:
`awready = !has_aw && !bvalid`, `wready = !has_w && !bvalid`, and
`arready = !rvalid`; reset does not independently gate ready signals.

Each write channel captures independently when its valid and pre-edge ready
are high. A write commits only when both buffers are already occupied and
`bvalid` is low before the edge. Commit updates only bytes whose buffered strobe
bits are set, empties both buffers, and asserts `bvalid`. Capturing a new buffer
cannot cause a commit on that edge. `bvalid` holds until an edge with `bready`
high; that clearing edge accepts no new write channels. Acceptance resumes on
the following edge.

An `arvalid && arready` edge samples the selected register into `rdata` and
asserts `rvalid`. A pre-existing `rvalid && rready` clears `rvalid` with no
replacement on that edge. `rdata` holds through stalls and idle cycles.

## Edge cases

Reset overrides captures, commits, and response consumption. AW and W may
arrive together or in either order with arbitrary delay. A zero strobe still
produces a write response without changing register data. Reads and writes are
independent; a read accepted on a write-commit edge returns the old register
value. Holding valid high may cause a later transaction once ready returns,
but cannot bypass the specified response gaps. There are no bursts, errors,
queues beyond the two single-entry write buffers, or external memory.
