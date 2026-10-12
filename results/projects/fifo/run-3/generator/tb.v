`timescale 1ns/1ps
module tb;
    reg clk = 1'b0;
    reg rst = 1'b0;
    reg push = 1'b0;
    reg pop = 1'b0;
    reg [7:0] din = 8'd0;
    wire [7:0] dout;
    wire empty, full;
    wire [2:0] count;
    reg [7:0] model [0:3];
    integer model_count = 0;
    integer cycles = 0;
    integer coverage [0:4][0:3];
    integer sequence_id, action_bits, n, k, c, a;
    integer seed = 32'h12345678;
    reg [31:0] random_bits;

    fifo dut(.clk(clk), .rst(rst), .push(push), .pop(pop),
             .din(din), .dout(dout), .empty(empty), .full(full), .count(count));
    always #5 clk = ~clk;

    // Independent shift-register queue model: decisions use old occupancy.
    task step;
        input reset_in, push_in, pop_in;
        input [7:0] data_in;
        integer j;
        reg take_push, take_pop;
        reg [7:0] expected_front;
        begin
            @(negedge clk);
            rst = reset_in;
            push = push_in;
            pop = pop_in;
            din = data_in;
            take_push = push_in && (model_count < 4);
            take_pop = pop_in && (model_count > 0);
            if (!reset_in)
                coverage[model_count][{push_in, pop_in}] =
                    coverage[model_count][{push_in, pop_in}] + 1;
            @(posedge clk);
            if (reset_in) begin
                model_count = 0;
            end else begin
                if (take_pop) begin
                    for (j = 0; j < 3; j = j + 1)
                        model[j] = model[j+1];
                    model_count = model_count - 1;
                end
                if (take_push) begin
                    model[model_count] = data_in;
                    model_count = model_count + 1;
                end
            end
            #1;
            cycles = cycles + 1;
            expected_front = (model_count == 0) ? 8'd0 : model[0];
            if ((count !== model_count[2:0]) ||
                (empty !== (model_count == 0)) ||
                (full !== (model_count == 4)) ||
                (dout !== expected_front)) begin
                $display("FAIL cycle=%0d rst=%b push=%b pop=%b din=%h count=%0d expected_count=%0d dout=%h expected_dout=%h empty=%b full=%b",
                         cycles, rst, push, pop, din, count, model_count,
                         dout, expected_front, empty, full);
                $fatal(1, "FIFO scoreboard mismatch");
            end
        end
    endtask

    initial begin
        for (c = 0; c <= 4; c = c + 1)
            for (a = 0; a < 4; a = a + 1)
                coverage[c][a] = 0;
        step(1, 1, 1, 8'hff);

        // All six-cycle sequences of the four request combinations.
        for (sequence_id = 0; sequence_id < 4096; sequence_id = sequence_id + 1) begin
            step(1, 0, 0, 0);
            action_bits = sequence_id;
            for (n = 0; n < 6; n = n + 1) begin
                step(0, (action_bits & 2) != 0, (action_bits & 1) != 0,
                     sequence_id + n * 37);
                action_bits = action_bits >> 2;
            end
        end

        // Reset priority from every occupancy with every request combination.
        for (c = 0; c <= 4; c = c + 1) begin
            for (a = 0; a < 4; a = a + 1) begin
                step(1, 0, 0, 0);
                for (k = 0; k < c; k = k + 1)
                    step(0, 1, 0, k + 8'h80);
                step(1, (a & 2) != 0, (a & 1) != 0, 8'hff);
                step(0, 0, 0, 8'h55);
            end
        end

        // Sustained simultaneous transfers exercise repeated pointer wrap.
        for (k = 0; k < 3; k = k + 1)
            step(0, 1, 0, k);
        for (k = 0; k < 256; k = k + 1)
            step(0, 1, 1, k);
        for (k = 0; k < 5; k = k + 1)
            step(0, 0, 1, 8'hff);

        // Reproducible random traffic, data, and occasional reset.
        for (k = 0; k < 4000; k = k + 1) begin
            random_bits = $random(seed);
            step(random_bits[7:2] == 0, random_bits[0], random_bits[1],
                 random_bits[23:16]);
        end
        for (k = 0; k < 5; k = k + 1)
            step(0, 0, 1, 0);

        for (c = 0; c <= 4; c = c + 1)
            for (a = 0; a < 4; a = a + 1)
                if (coverage[c][a] == 0)
                    $fatal(1, "Missing coverage: occupancy=%0d action=%0d", c, a);
        $display("PASS: %0d cycles; all 20 occupancy/request combinations covered", cycles);
        $finish;
    end
endmodule
