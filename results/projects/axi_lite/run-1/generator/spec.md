# AXI-lite register slave subset

## Interface

Module `axi_lite` uses the exact port names, directions, and widths from
`requirement.md`. All inputs are sampled on the rising edge of `clk`; outputs
are observed one time unit later. `rst` is synchronous and active high.
`awaddr` and `araddr` are 4 bits; `wdata` and `rdata` are 32 bits;
`wstrb` is 4 bits; `bresp` and `rresp` are 2 bits. Remaining ports are 1 bit.
Both response codes are permanently OKAY (`2'b00`).

## State

- Four zero-reset 32-bit registers, indexed by address bits `[3:2]`.
- Independent single-entry AW and W buffers, with occupancy flags, buffered
  address, data, and byte strobes.
- Write response valid `bvalid`, read response valid `rvalid`, and held `rdata`.
- Reset clears registers, buffer contents and occupancy, both response valids,
  and `rdata`, taking priority over every transaction.

## Cycle behavior

All conditions below use state immediately before the rising edge.

- `awready = !has_aw && !bvalid`; `wready = !has_w && !bvalid`.
  A channel is captured only when its valid and ready are both high.
- A write commits only when both buffers are already full and `bvalid` is low.
  Strobe bit `i` updates byte `[8*i +: 8]` of the selected register. Commit
  empties both buffers and raises `bvalid`. Capturing either buffer cannot
  trigger a commit on the same edge.
- `bvalid` holds until an edge with `bready` high. A response-consumption edge
  cannot accept new write channels because their pre-edge ready is low.
- `arready = !rvalid`. An accepted read captures the selected pre-edge register
  value and raises `rvalid`. Read data and valid hold under backpressure.
- An edge with `rvalid && rready` clears `rvalid` without replacing the response.
  `rdata` holds during idle cycles and after response consumption.

## Edge cases

AW and W can arrive together or in either order, separated by arbitrary delays.
Low address bits are ignored. A zero strobe still completes a write response but
changes no bytes. A read accepted on a write-commit edge returns the old value.
Read and write channels otherwise operate independently. Reset discards partial
writes and pending responses, including under backpressure. Ready outputs are
derived from cleared state after reset; reset does not combinationally mask them.
There are no bursts, error responses, outstanding queues, or external memory.
