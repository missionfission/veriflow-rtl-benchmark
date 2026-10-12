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
    axi_lite dut(clk,rst,awvalid,awaddr,wvalid,wdata,wstrb,bready,
                 arvalid,araddr,rready,awready,wready,bvalid,bresp,
                 arready,rvalid,rdata,rresp);

    reg [31:0] memory [0:3];
    reg address_pending = 0, data_pending = 0;
    reg write_response = 0, read_response = 0;
    reg [31:0] read_value = 0, saved_data;
    reg [3:0] saved_address, saved_mask;
    reg accept_address, accept_data, accept_read, commit_write;
    integer cycle = 0, writes = 0, reads = 0, collisions = 0;
    integer b_stalls = 0, r_stalls = 0, resets = 0;
    integer j, k, n, seed = 32'h31415926;
    reg [31:0] random_bits;

    // Reference model: decide all events first, sample reads before updating
    // memory, then apply each event and compare externally visible state.
    always @(posedge clk) begin
        cycle = cycle + 1;
        accept_address = awvalid && !address_pending && !write_response;
        accept_data = wvalid && !data_pending && !write_response;
        accept_read = arvalid && !read_response;
        commit_write = address_pending && data_pending && !write_response;
        if (rst) begin
            for (j = 0; j < 4; j = j + 1) memory[j] = 0;
            address_pending = 0;
            data_pending = 0;
            write_response = 0;
            read_response = 0;
            read_value = 0;
            saved_address = 0;
            saved_data = 0;
            saved_mask = 0;
            resets = resets + 1;
        end else begin
            if (write_response && !bready) b_stalls = b_stalls + 1;
            if (read_response && !rready) r_stalls = r_stalls + 1;
            if (accept_read) begin
                read_value = memory[araddr >> 2];
                read_response = 1;
                reads = reads + 1;
            end else if (read_response && rready) read_response = 0;
            if (commit_write) begin
                for (j = 0; j < 4; j = j + 1)
                    if ((saved_mask >> j) & 1)
                        memory[saved_address >> 2] =
                            (memory[saved_address >> 2] & ~(32'hff << (j*8))) |
                            (saved_data & (32'hff << (j*8)));
                address_pending = 0;
                data_pending = 0;
                write_response = 1;
                writes = writes + 1;
                if (accept_read && ((araddr >> 2) == (saved_address >> 2)))
                    collisions = collisions + 1;
            end else if (write_response && bready) write_response = 0;
            if (accept_address) begin
                address_pending = 1;
                saved_address = awaddr;
            end
            if (accept_data) begin
                data_pending = 1;
                saved_data = wdata;
                saved_mask = wstrb;
            end
        end
        #1;
        if ({awready,wready,bvalid,arready,rvalid,rdata,bresp,rresp} !==
            {!address_pending && !write_response,
             !data_pending && !write_response,write_response,
             !read_response,read_response,read_value,2'b00,2'b00}) begin
            $display("FAIL cycle %0d: ready AW/W/AR=%b%b%b B/R=%b%b data=%h",
                     cycle,awready,wready,arready,bvalid,rvalid,rdata);
            $display("Expected ready AW/W/AR=%b%b%b B/R=%b%b data=%h",
                     !address_pending && !write_response,
                     !data_pending && !write_response,!read_response,
                     write_response,read_response,read_value);
            $fatal(1, "Reference-model mismatch");
        end
    end

    task step;
        input reset_in, av;
        input [3:0] aa;
        input wv;
        input [31:0] wd;
        input [3:0] ws;
        input br, arv;
        input [3:0] ra;
        input rr;
        begin
            @(negedge clk);
            rst = reset_in; awvalid = av; awaddr = aa;
            wvalid = wv; wdata = wd; wstrb = ws;
            bready = br; arvalid = arv; araddr = ra; rready = rr;
            @(posedge clk);
            #2;
        end
    endtask

    task expect_data;
        input [31:0] expected;
        begin
            if (!rvalid || rdata !== expected)
                $fatal(1, "Directed read check: expected %h, got %h valid=%b",
                       expected,rdata,rvalid);
        end
    endtask

    initial begin
        rst = 1; awvalid = 0; awaddr = 0; wvalid = 0; wdata = 0;
        wstrb = 0; bready = 0; arvalid = 0; araddr = 0; rready = 0;
        step(1,1,15,1,32'hffffffff,15,1,1,15,1);
        // Simultaneous capture must not commit until the next edge.
        step(0,1,3,1,32'h11223344,15,0,0,0,0);
        if (bvalid) $fatal(1, "Early write commit");
        step(0,0,0,0,0,0,0,1,1,0);
        if (!bvalid) $fatal(1, "Missing write commit");
        expect_data(0); // Old value on commit edge, low bits ignored.
        // Both responses stall while attempted replacements are ignored.
        repeat (3) step(0,1,4,1,32'hdeadbeef,15,0,1,0,0);
        step(0,1,4,1,32'hdeadbeef,15,1,1,0,1);
        if (bvalid || rvalid || !awready || !wready || !arready)
            $fatal(1, "Response clear edge did not create the required gap");
        step(0,0,0,0,0,0,0,1,2,0);
        expect_data(32'h11223344);
        step(0,0,0,0,0,0,1,0,0,1);
        // Exercise all strobe masks, all registers and all address aliases.
        // Alternate AW-first, W-first, and simultaneous arrivals.
        for (k = 0; k < 16; k = k + 1) begin
            case (k % 3)
                0: begin
                    step(0,1,k,0,0,0,0,0,0,0);
                    repeat (2) step(0,0,0,0,0,0,0,0,0,0);
                    step(0,0,0,1,32'ha5c39e71 ^ k,k,0,0,0,0);
                end
                1: begin
                    step(0,0,0,1,32'ha5c39e71 ^ k,k,0,0,0,0);
                    repeat (2) step(0,0,0,0,0,0,0,0,0,0);
                    step(0,1,k,0,0,0,0,0,0,0);
                end
                2: step(0,1,k,1,32'ha5c39e71 ^ k,k,0,0,0,0);
            endcase
            step(0,0,0,0,0,0,1,1,k ^ 3,0);
            step(0,0,0,0,0,0,1,0,0,1);
            step(0,0,0,0,0,0,1,1,k,0);
            expect_data(memory[k >> 2]);
            step(0,0,0,0,0,0,1,0,0,1);
        end
        // Reset discards partial buffers and stalled responses/data.
        step(0,1,12,0,0,0,0,0,0,0);
        step(1,1,4,1,32'hffffffff,15,1,1,4,1);
        step(0,0,0,1,32'hffffffff,15,0,0,0,0);
        step(1,0,0,0,0,0,0,0,0,0);
        step(0,1,8,1,32'hffffffff,15,0,0,0,0);
        step(0,0,0,0,0,0,0,1,0,0);
        step(1,1,0,1,0,15,1,1,0,1);
        // Deterministic random traffic includes valid held during backpressure.
        for (n = 0; n < 2000; n = n + 1) begin
            random_bits = $random(seed);
            step((n % 137) == 136,
                 random_bits[0],random_bits[7:4],
                 random_bits[1],$random(seed),random_bits[11:8],
                 random_bits[2],random_bits[3],random_bits[15:12],
                 random_bits[16]);
        end
        // Drain writes and read every register to expose latent memory errors.
        repeat (5) step(0,0,0,0,0,0,1,0,0,1);
        for (k = 0; k < 4; k = k + 1) begin
            step(0,0,0,0,0,0,1,1,k*4,1);
            expect_data(memory[k]);
            step(0,0,0,0,0,0,1,0,0,1);
        end
        if (writes < 100 || reads < 100 || collisions < 16 ||
            b_stalls < 10 || r_stalls < 10 || resets < 4)
            $fatal(1, "Insufficient test coverage");
        $display("PASS: %0d cycles, %0d writes, %0d reads, %0d same-register collisions, %0d/%0d B/R stall cycles, %0d resets",
                 cycle,writes,reads,collisions,b_stalls,r_stalls,resets);
        $finish;
    end
    initial begin
        #100000;
        $fatal(1, "Test timeout");
    end
endmodule
