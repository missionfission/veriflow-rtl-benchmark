`timescale 1ns/1ps
module tb;
    reg clk = 0;
    reg rst = 0;
    reg req = 0;
    reg write = 0;
    reg [7:0] addr = 0;
    reg [15:0] wdata = 0;
    wire valid, hit;
    wire [15:0] rdata;
    reg [15:0] model_mem [0:255];
    integer resident [0:3];
    reg expected_valid, expected_hit;
    reg [15:0] expected_data;
    integer checks = 0;
    integer i, j, idx;
    reg [31:0] rng = 32'h739bc521;

    cache dut (.clk(clk), .rst(rst), .req(req), .write(write),
               .addr(addr), .wdata(wdata), .valid(valid), .hit(hit),
               .rdata(rdata));
    always #5 clk = ~clk;

    task step;
        input do_reset, do_req, do_write;
        input [7:0] address;
        input [15:0] data;
        begin
            @(negedge clk);
            rst = do_reset;
            req = do_req;
            write = do_write;
            addr = address;
            wdata = data;
            if (do_reset) begin
                for (j = 0; j < 256; j = j + 1)
                    model_mem[j] = j * 257;
                for (j = 0; j < 4; j = j + 1)
                    resident[j] = -1;
                expected_valid = 0;
                expected_hit = 0;
                expected_data = 0;
            end else begin
                expected_valid = do_req;
                if (do_req) begin
                    idx = address % 4;
                    expected_hit = (resident[idx] == address);
                    if (do_write)
                        model_mem[address] = data;
                    expected_data = model_mem[address];
                    resident[idx] = address;
                end
            end
            @(posedge clk);
            #1;
            checks = checks + 1;
            if (valid !== expected_valid || hit !== expected_hit ||
                rdata !== expected_data) begin
                $display("FAIL cycle=%0d rst=%b req=%b write=%b addr=%h data=%h expected=%b/%b/%h actual=%b/%b/%h",
                         checks, rst, req, write, addr, wdata,
                         expected_valid, expected_hit, expected_data,
                         valid, hit, rdata);
                $fatal(1, "Cache response mismatch");
            end
        end
    endtask

    initial begin
        // Reset overrides an active write, then idle retains the reset response.
        step(1, 1, 1, 8'hff, 16'hdead);
        step(0, 0, 1, 8'h00, 16'hbeef);
        // All initial words, repeated hits, and all tags/indices.
        for (i = 0; i < 256; i = i + 1) begin
            step(0, 1, 0, i, 0);
            step(0, 1, 0, i, 0);
        end
        // Explicit collision, write miss/hit, zero, and hold behavior.
        step(0, 1, 1, 8'h00, 16'h1234);
        step(0, 1, 1, 8'h00, 16'h0000);
        step(0, 0, 1, 8'h00, 16'hffff);
        step(0, 0, 0, 8'hff, 16'hffff);
        step(0, 1, 0, 8'h04, 0);
        step(0, 1, 0, 8'h00, 0);
        step(0, 1, 0, 8'h00, 0);
        // Write every backing address and revisit after eviction.
        for (i = 0; i < 256; i = i + 1)
            step(0, 1, 1, i, 16'hffff ^ (i * 113));
        for (i = 255; i >= 0; i = i - 1)
            step(0, 1, 0, i, 0);
        // Repeated resets erase all prior writes.
        step(1, 1, 1, 8'hff, 16'hffff);
        step(1, 0, 0, 8'h00, 0);
        for (i = 0; i < 256; i = i + 1)
            step(0, 1, 0, i, 0);
        // Deterministic random requests, idle edges, and reset interruptions.
        for (i = 0; i < 3000; i = i + 1) begin
            rng = rng ^ (rng << 13);
            rng = rng ^ (rng >> 17);
            rng = rng ^ (rng << 5);
            step((i % 379) == 378, rng[0] | rng[1], rng[2],
                 rng[15:8], rng[31:16]);
        end
        $display("PASS: %0d checked cycles", checks);
        $finish;
    end
endmodule
