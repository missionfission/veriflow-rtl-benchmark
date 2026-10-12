`timescale 1ns/1ps
module tb;
    reg clk = 0;
    always #5 clk = ~clk;
    reg rst, awvalid, wvalid, bready, arvalid, rready;
    reg [3:0] awaddr, wstrb, araddr;
    reg [31:0] wdata;
    wire awready, wready, bvalid, arready, rvalid;
    wire [1:0] bresp, rresp;
    wire [31:0] rdata;

    axi_lite dut(clk, rst, awvalid, awaddr, wvalid, wdata, wstrb,
                 bready, arvalid, araddr, rready, awready, wready,
                 bvalid, bresp, arready, rvalid, rdata, rresp);

    reg [31:0] memory [0:3];
    reg ma, mw, mb, mr;
    reg [3:0] buffered_address, buffered_strobes;
    reg [31:0] buffered_data, expected_read;
    reg take_aw, take_w, take_read, commit;
    integer cycles = 0;
    integer commits = 0;
    integer reads = 0;
    integer collisions = 0;
    integer b_stalls = 0;
    integer r_stalls = 0;
    integer seed = 32'h51a17e23;
    integer i, j, k, mode;
    reg [31:0] random_bits, random_data;

    task check;
        begin
            if ({awready, wready, bvalid, arready, rvalid, bresp, rresp}
                !== {!ma && !mb, !mw && !mb, mb, !mr, mr, 2'b00, 2'b00}
                || rdata !== expected_read) begin
                $display("FAIL cycle %0d: ready/valid actual %b%b%b%b%b expected %b%b%b%b%b, read %h expected %h",
                         cycles, awready, wready, bvalid, arready, rvalid,
                         !ma && !mb, !mw && !mb, mb, !mr, mr,
                         rdata, expected_read);
                $fatal(1);
            end
        end
    endtask

    // Reference model uses pre-edge acceptance and reads before writes.
    task step;
        input reset_value;
        input av;
        input [3:0] aa;
        input wv;
        input [31:0] wd;
        input [3:0] ws;
        input br;
        input arv;
        input [3:0] ara;
        input rr;
        integer byte_index, reg_index;
        begin
            @(negedge clk);
            rst = reset_value;
            awvalid = av; awaddr = aa;
            wvalid = wv; wdata = wd; wstrb = ws;
            bready = br; arvalid = arv; araddr = ara; rready = rr;
            @(posedge clk);
            if (rst) begin
                for (reg_index = 0; reg_index < 4; reg_index = reg_index + 1)
                    memory[reg_index] = 0;
                ma = 0; mw = 0; mb = 0; mr = 0;
                buffered_address = 0; buffered_data = 0;
                buffered_strobes = 0; expected_read = 0;
            end else begin
                take_aw = awvalid && !ma && !mb;
                take_w = wvalid && !mw && !mb;
                take_read = arvalid && !mr;
                commit = ma && mw && !mb;
                if (mb && !bready) b_stalls = b_stalls + 1;
                if (mr && !rready) r_stalls = r_stalls + 1;
                if (take_read) begin
                    expected_read = memory[araddr / 4];
                    mr = 1;
                    reads = reads + 1;
                    if (commit && araddr / 4 == buffered_address / 4)
                        collisions = collisions + 1;
                end else if (mr && rready) mr = 0;
                if (commit) begin
                    for (byte_index = 0; byte_index < 4; byte_index = byte_index + 1)
                        if (buffered_strobes[byte_index])
                            memory[buffered_address / 4][8*byte_index +: 8]
                                = buffered_data[8*byte_index +: 8];
                    ma = 0; mw = 0; mb = 1;
                    commits = commits + 1;
                end else if (mb && bready) mb = 0;
                if (take_aw) begin ma = 1; buffered_address = awaddr; end
                if (take_w) begin
                    mw = 1; buffered_data = wdata; buffered_strobes = wstrb;
                end
            end
            cycles = cycles + 1;
            #1;
            check;
        end
    endtask

    task idle;
        begin step(0, 0, 0, 0, 0, 0, 1, 0, 0, 1); end
    endtask

    task read_register;
        input [3:0] address;
        begin
            step(0, 0, 0, 0, 0, 0, 1, 1, address, 1);
            idle;
        end
    endtask

    initial begin
        rst = 1; awvalid = 0; awaddr = 0; wvalid = 0;
        wdata = 0; wstrb = 0; bready = 0; arvalid = 0;
        araddr = 0; rready = 0;
        step(1, 1, 15, 1, 32'hffffffff, 15, 1, 1, 15, 1);
        step(1, 0, 0, 0, 0, 0, 0, 0, 0, 0);
        for (i = 0; i < 16; i = i + 1) read_register(i);

        // Every register and strobe, rotating simultaneous/AW-first/W-first.
        for (i = 0; i < 4; i = i + 1) begin
            for (j = 0; j < 16; j = j + 1) begin
                mode = j % 3;
                random_data = $random(seed);
                if (mode == 0)
                    step(0, 1, i*4 + j%4, 1, random_data, j, 1, 0, 0, 1);
                else if (mode == 1) begin
                    step(0, 1, i*4 + j%4, 0, 0, 0, 1, 0, 0, 1);
                    idle;
                    step(0, 1, 15-i*4, 1, random_data, j, 1, 0, 0, 1);
                end else begin
                    step(0, 0, 0, 1, random_data, j, 1, 0, 0, 1);
                    idle;
                    step(0, 1, i*4 + j%4, 1, ~random_data, 15, 1, 0, 0, 1);
                end
                // Read on commit must see old value, even with rready high.
                step(0, 1, 15, 1, 32'hbadbad00, 15, 1, 1, i*4, 1);
                // Hold responses while attempted new requests change values.
                repeat (3)
                    step(0, 1, 15, 1, 32'hdeadbeef, 15, 0, 1, 15, 0);
                // Clearing responses cannot also accept pending requests.
                step(0, 1, 15, 1, 32'hdeadbeef, 15, 1, 1, 15, 1);
                for (k = 0; k < 4; k = k + 1) read_register(i*4+k);
            end
        end

        // Reset discards AW-only, W-only, both buffers and pending responses.
        step(0, 1, 4, 0, 0, 0, 0, 0, 0, 0);
        step(1, 0, 0, 1, 32'hffffffff, 15, 0, 1, 4, 0);
        step(0, 0, 0, 1, 32'hffffffff, 15, 0, 0, 0, 0);
        step(1, 1, 4, 0, 0, 0, 0, 0, 0, 0);
        step(0, 1, 8, 1, 32'hffffffff, 15, 0, 0, 0, 0);
        step(1, 0, 0, 0, 0, 0, 0, 0, 0, 0);
        step(0, 1, 12, 1, 32'hffffffff, 15, 0, 0, 0, 0);
        step(0, 0, 0, 0, 0, 0, 0, 1, 12, 0);
        step(1, 1, 0, 1, 32'h12345678, 15, 1, 1, 12, 1);
        for (i = 0; i < 16; i = i + 1) read_register(i);

        // Deterministic randomized channel traffic, stalls, aliases, and resets.
        for (i = 0; i < 4000; i = i + 1) begin
            random_bits = $random(seed);
            random_data = $random(seed);
            step(random_bits[31:25] == 0,
                 random_bits[0], random_bits[4:1], random_bits[5],
                 random_data, random_bits[9:6], random_bits[10],
                 random_bits[11], random_bits[15:12], random_bits[16]);
        end
        // Drain any partial transaction, then inspect all locations and aliases.
        step(0, 1, 0, 1, 32'h10203040, 15, 1, 0, 0, 1);
        repeat (5) idle;
        for (i = 0; i < 16; i = i + 1) read_register(i);
        if (commits < 64 || collisions < 64 || reads < 256 ||
            b_stalls < 192 || r_stalls < 192) begin
            $display("FAIL insufficient coverage");
            $fatal(1);
        end
        $display("PASS: %0d cycles, %0d commits, %0d reads, %0d read/write collisions, %0d B stalls, %0d R stalls",
                 cycles, commits, reads, collisions, b_stalls, r_stalls);
        $finish;
    end
endmodule
