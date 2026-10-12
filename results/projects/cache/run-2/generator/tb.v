`timescale 1ns/1ps
module tb;
    reg clk = 0;
    reg rst, req, write;
    reg [7:0] addr;
    reg [15:0] wdata;
    wire valid, hit;
    wire [15:0] rdata;
    reg [15:0] memory [0:255];
    reg occupied [0:3];
    reg [5:0] tags [0:3];
    reg expected_valid, expected_hit;
    reg [15:0] expected_data;
    integer cycles = 0;
    integer j, k, seed;
    reg [31:0] random_bits;

    cache dut (.clk(clk), .rst(rst), .req(req), .write(write),
               .addr(addr), .wdata(wdata), .valid(valid), .hit(hit), .rdata(rdata));
    always #5 clk = ~clk;

    task step;
        input reset_in, request_in, write_in;
        input [7:0] address_in;
        input [15:0] data_in;
        integer a, idx;
        begin
            @(negedge clk);
            rst = reset_in;
            req = request_in;
            write = write_in;
            addr = address_in;
            wdata = data_in;
            @(posedge clk);
            if (reset_in) begin
                expected_valid = 0;
                expected_hit = 0;
                expected_data = 0;
                for (a = 0; a < 256; a = a + 1) memory[a] = a * 257;
                for (a = 0; a < 4; a = a + 1) begin
                    occupied[a] = 0;
                    tags[a] = 0;
                end
            end else begin
                expected_valid = request_in;
                if (request_in) begin
                    idx = address_in % 4;
                    expected_hit = occupied[idx] && tags[idx] == address_in / 4;
                    if (write_in) memory[address_in] = data_in;
                    expected_data = memory[address_in];
                    occupied[idx] = 1;
                    tags[idx] = address_in / 4;
                end
            end
            #1;
            cycles = cycles + 1;
            if ({valid, hit, rdata} !== {expected_valid, expected_hit, expected_data}) begin
                $display("FAIL cycle=%0d rst=%b req=%b write=%b addr=%h got=%b/%b/%h expected=%b/%b/%h",
                         cycles, rst, req, write, addr, valid, hit, rdata,
                         expected_valid, expected_hit, expected_data);
                $fatal(1, "Response mismatch");
            end
        end
    endtask

    initial begin
        rst = 0; req = 0; write = 0; addr = 0; wdata = 0;
        seed = 32'h12345678;
        step(1, 1, 1, 255, 16'hdead);
        step(1, 0, 0, 0, 0);
        step(0, 1, 0, 0, 0);
        step(0, 1, 0, 0, 0);
        step(0, 0, 1, 0, 16'hffff);
        step(0, 1, 1, 0, 16'hbeef);
        step(0, 1, 0, 4, 0);
        step(0, 1, 0, 0, 0);
        step(0, 1, 1, 255, 16'h1234);
        step(0, 1, 0, 255, 0);
        step(0, 0, 0, 1, 0);
        step(0, 0, 1, 255, 16'hffff);
        for (j = 0; j < 256; j = j + 1) begin
            step(0, 1, 0, j, 0);
            step(0, 1, 0, j, 0);
            step(0, 1, 1, j, 16'hffff ^ j);
            step(0, 1, 0, j, 0);
        end
        step(1, 1, 1, 0, 16'hffff);
        for (j = 0; j < 256; j = j + 1) step(0, 1, 0, j, 0);
        for (k = 0; k < 3000; k = k + 1) begin
            random_bits = $random(seed);
            step(k % 317 == 0, random_bits[0] | random_bits[1],
                 random_bits[2], random_bits[10:3], random_bits[31:16]);
        end
        $display("PASS: %0d checked cycles", cycles);
        $finish;
    end
endmodule
