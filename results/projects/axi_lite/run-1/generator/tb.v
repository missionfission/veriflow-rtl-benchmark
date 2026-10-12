`timescale 1ns/1ps
module tb;
    reg clk = 0;
    always #5 clk = !clk;
    reg rst, awvalid, wvalid, bready, arvalid, rready;
    reg [3:0] awaddr, wstrb, araddr;
    reg [31:0] wdata;
    wire awready, wready, bvalid, arready, rvalid;
    wire [1:0] bresp, rresp;
    wire [31:0] rdata;
    axi_lite dut(
        .clk(clk), .rst(rst), .awvalid(awvalid), .awaddr(awaddr),
        .wvalid(wvalid), .wdata(wdata), .wstrb(wstrb), .bready(bready),
        .arvalid(arvalid), .araddr(araddr), .rready(rready),
        .awready(awready), .wready(wready), .bvalid(bvalid), .bresp(bresp),
        .arready(arready), .rvalid(rvalid), .rdata(rdata), .rresp(rresp)
    );

    reg [31:0] mem [0:3];
    reg ma, mw, mb, mr;
    reg [3:0] addr_buf, strb_buf;
    reg [31:0] data_buf, read_buf;
    reg pre_awready, pre_wready, pre_arready, commit;
    integer cycles = 0;
    integer commits = 0, reads = 0, collisions = 0;
    integer aw_first = 0, w_first = 0, write_stalls = 0, read_stalls = 0;
    reg [15:0] seen_strobes = 0;
    reg [3:0] seen_write_addresses = 0, seen_read_addresses = 0;
    integer byte_index, reg_index, n, a, s, seed;
    reg [31:0] random_bits, random_data;

    task check_outputs;
        begin
            if (awready !== (!ma && !mb) ||
                wready !== (!mw && !mb) || arready !== !mr ||
                bvalid !== mb || rvalid !== mr || rdata !== read_buf ||
                bresp !== 2'b00 || rresp !== 2'b00) begin
                $display("FAIL cycle %0d: ready AW/W/AR=%b%b%b expected=%b%b%b B/R=%b%b expected=%b%b data=%h expected=%h",
                         cycles, awready, wready, arready,
                         (!ma && !mb), (!mw && !mb), !mr,
                         bvalid, rvalid, mb, mr, rdata, read_buf);
                $fatal(1);
            end
        end
    endtask

    task step;
        input reset_in, av;
        input [3:0] aa;
        input wv;
        input [31:0] wd;
        input [3:0] ws;
        input br, rv;
        input [3:0] ra;
        input rr;
        begin
            @(negedge clk);
            rst = reset_in; awvalid = av; awaddr = aa;
            wvalid = wv; wdata = wd; wstrb = ws;
            bready = br; arvalid = rv; araddr = ra; rready = rr;
            if (cycles != 0) check_outputs;
            @(posedge clk);
            cycles = cycles + 1;
            if (rst) begin
                for (reg_index = 0; reg_index < 4; reg_index = reg_index + 1)
                    mem[reg_index] = 0;
                ma = 0; mw = 0; mb = 0; mr = 0;
                addr_buf = 0; strb_buf = 0; data_buf = 0; read_buf = 0;
            end else begin
                pre_awready = !ma && !mb;
                pre_wready = !mw && !mb;
                pre_arready = !mr;
                commit = ma && mw && !mb;
                if (mb && !bready) write_stalls = write_stalls + 1;
                if (mr && !rready) read_stalls = read_stalls + 1;
                // Read first so a simultaneous commit returns the old word.
                if (arvalid && pre_arready) begin
                    read_buf = mem[araddr >> 2];
                    mr = 1;
                    reads = reads + 1;
                    seen_read_addresses[araddr >> 2] = 1;
                    if (commit) collisions = collisions + 1;
                end else if (mr && rready) mr = 0;
                if (commit) begin
                    for (byte_index = 0; byte_index < 4; byte_index = byte_index + 1)
                        if ((strb_buf >> byte_index) & 1)
                            mem[addr_buf >> 2] =
                                (mem[addr_buf >> 2] & ~(32'hff << (8*byte_index))) |
                                (data_buf & (32'hff << (8*byte_index)));
                    seen_strobes[strb_buf] = 1;
                    seen_write_addresses[addr_buf >> 2] = 1;
                    commits = commits + 1;
                    ma = 0; mw = 0; mb = 1;
                end else if (mb && bready) mb = 0;
                if (awvalid && pre_awready) begin
                    if (!wvalid && !mw) aw_first = aw_first + 1;
                    ma = 1; addr_buf = awaddr;
                end
                if (wvalid && pre_wready) begin
                    if (!awvalid && !ma) w_first = w_first + 1;
                    mw = 1; data_buf = wdata; strb_buf = wstrb;
                end
            end
            #1;
            check_outputs;
        end
    endtask

    initial begin
        rst = 0; awvalid = 0; awaddr = 0; wvalid = 0; wdata = 0;
        wstrb = 0; bready = 0; arvalid = 0; araddr = 0; rready = 0;
        seed = 32'h12345678;
        step(1, 1, 15, 1, 32'hffffffff, 15, 1, 1, 15, 1);
        // Exhaust all strobes and register indexes, using nonzero low address bits.
        for (a = 0; a < 4; a = a + 1) begin
            for (s = 0; s < 16; s = s + 1) begin
                step(0, 1, a*4+(s%4), 1, 32'h89abcdef ^ (s*32'h01010101), s, 1, 0, 0, 1);
                step(0, 0, 0, 0, 0, 0, 1, 1, a*4+3, 1);
                // Backpressure with all request valids high; no replacements.
                step(0, 1, 0, 1, 32'hdeadbeef, 15, 0, 1, 0, 0);
                step(0, 1, 0, 1, 32'hdeadbeef, 15, 1, 1, 0, 1);
                step(0, 0, 0, 0, 0, 0, 0, 1, a*4+1, 0);
                step(0, 0, 0, 0, 0, 0, 0, 1, 0, 1);
            end
        end
        // Address then data, and data then address with idle gaps.
        step(0, 1, 5, 0, 0, 0, 0, 0, 0, 0);
        step(0, 0, 0, 0, 0, 0, 0, 0, 0, 0);
        step(0, 0, 0, 1, 32'h11223344, 15, 0, 0, 0, 0);
        step(0, 0, 0, 0, 0, 0, 0, 1, 4, 0);
        step(0, 1, 0, 1, 0, 15, 1, 0, 0, 1);
        step(0, 0, 0, 1, 32'haabbccdd, 5, 0, 0, 0, 0);
        step(0, 0, 0, 0, 0, 0, 0, 0, 0, 0);
        step(0, 1, 11, 0, 0, 0, 0, 0, 0, 0);
        step(0, 0, 0, 0, 0, 0, 0, 1, 8, 0);
        // Reset discards stalled responses, then partial AW and W buffers.
        step(1, 1, 0, 1, 0, 15, 1, 1, 0, 1);
        step(0, 1, 0, 0, 0, 0, 0, 0, 0, 0);
        step(1, 0, 0, 0, 0, 0, 0, 0, 0, 0);
        step(0, 0, 0, 1, 32'hffffffff, 15, 0, 0, 0, 0);
        step(1, 0, 0, 0, 0, 0, 0, 0, 0, 0);
        // Deterministic randomized channel interleavings and periodic resets.
        for (n = 0; n < 3000; n = n + 1) begin
            random_bits = $random(seed);
            random_data = $random(seed);
            step((n%113)==112, random_bits[0], random_bits[7:4],
                 random_bits[1], random_data, random_bits[11:8],
                 random_bits[2], random_bits[3], random_bits[15:12], random_bits[16]);
        end
        // Drain pending work and inspect every register after traffic.
        for (n = 0; n < 8; n = n + 1)
            step(0, 0, 0, 0, 0, 0, 1, 0, 0, 1);
        for (a = 0; a < 4; a = a + 1) begin
            step(0, 0, 0, 0, 0, 0, 1, 1, a*4, 1);
            step(0, 0, 0, 0, 0, 0, 1, 0, 0, 1);
        end
        if (seen_strobes !== 16'hffff || seen_write_addresses !== 4'hf ||
            seen_read_addresses !== 4'hf || collisions == 0 ||
            aw_first == 0 || w_first == 0 || write_stalls == 0 || read_stalls == 0)
            $fatal(1, "Required coverage missing");
        $display("PASS: %0d cycles, %0d commits, %0d reads, %0d read/write collisions; all strobes and addresses covered",
                 cycles, commits, reads, collisions);
        $finish;
    end
endmodule
