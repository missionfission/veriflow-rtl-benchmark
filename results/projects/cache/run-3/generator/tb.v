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
    cache dut (.clk(clk), .rst(rst), .req(req), .write(write),
               .addr(addr), .wdata(wdata), .valid(valid), .hit(hit),
               .rdata(rdata));
    always #5 clk = ~clk;

    reg [15:0] model_memory [0:255];
    integer resident [0:3];
    reg expected_valid, expected_hit;
    reg [15:0] expected_data;
    integer cycles = 0;
    integer hit_count = 0;
    integer miss_count = 0;
    integer n;
    reg [31:0] prng = 32'h31415926;

    task step;
        input reset_value, request_value, write_value;
        input [7:0] address_value;
        input [15:0] data_value;
        integer j;
        integer slot;
        begin
            @(negedge clk);
            rst = reset_value;
            req = request_value;
            write = write_value;
            addr = address_value;
            wdata = data_value;
            if (reset_value) begin
                for (j = 0; j < 256; j = j + 1)
                    model_memory[j] = j * 257;
                for (j = 0; j < 4; j = j + 1)
                    resident[j] = -1;
                expected_valid = 0;
                expected_hit = 0;
                expected_data = 0;
            end else begin
                expected_valid = request_value;
                if (request_value) begin
                    slot = address_value % 4;
                    expected_hit = (resident[slot] == address_value);
                    if (expected_hit) hit_count = hit_count + 1;
                    else miss_count = miss_count + 1;
                    if (write_value) model_memory[address_value] = data_value;
                    expected_data = model_memory[address_value];
                    resident[slot] = address_value;
                end
            end
            @(posedge clk);
            #1;
            cycles = cycles + 1;
            if ({valid, hit, rdata} !==
                {expected_valid, expected_hit, expected_data}) begin
                $display("FAIL cycle=%0d rst=%b req=%b write=%b addr=%h data=%h expected=%b/%b/%h actual=%b/%b/%h",
                         cycles, rst, req, write, addr, wdata,
                         expected_valid, expected_hit, expected_data,
                         valid, hit, rdata);
                $fatal(1, "Response mismatch");
            end
        end
    endtask

    initial begin
        step(1, 1, 1, 8'hff, 16'hdead);
        step(0, 0, 1, 8'hff, 16'hbeef);
        step(0, 1, 0, 0, 0);
        step(0, 1, 0, 0, 0);
        step(0, 0, 0, 4, 0);
        step(0, 1, 1, 0, 16'h1234);
        step(0, 1, 1, 4, 16'habcd);
        step(0, 1, 0, 0, 0);
        step(0, 1, 0, 4, 0);
        step(0, 1, 1, 255, 16'hffff);
        step(0, 1, 1, 255, 16'h0000);
        step(0, 0, 1, 255, 16'h9876);
        step(0, 1, 0, 255, 0);
        // Exhaustively exercise reset contents, all indices and all tags.
        step(1, 1, 1, 4, 16'hffff);
        for (n = 0; n < 256; n = n + 1) begin
            step(0, 1, 0, n, 0);
            step(0, 1, 0, n, 0);
        end
        // All backing words must retain writes after repeated eviction.
        for (n = 0; n < 256; n = n + 1)
            step(0, 1, 1, n, (n * 193) ^ 16'h5aa5);
        for (n = 255; n >= 0; n = n - 1)
            step(0, 1, 0, n, 0);
        step(1, 0, 0, 0, 0);
        step(1, 1, 1, 255, 16'h1234);
        for (n = 0; n < 256; n = n + 1)
            step(0, 1, 0, n, 0);
        // Deterministic mixed requests, idle periods, and periodic resets.
        for (n = 0; n < 5000; n = n + 1) begin
            prng = {prng[30:0], prng[31] ^ prng[21] ^ prng[1] ^ prng[0]};
            step((n % 733) == 732, prng[8] | prng[9], prng[10],
                 prng[7:0], prng[31:16]);
            if ((n % 17) == 0) begin
                step(0, 1, 1, prng[7:0], ~prng[31:16]);
                step(0, 1, 0, prng[7:0], 0);
                step(0, 0, 1, prng[7:0], 0);
            end
        end
        $display("PASS cycles=%0d hits=%0d misses=%0d", cycles, hit_count, miss_count);
        $finish;
    end
endmodule
