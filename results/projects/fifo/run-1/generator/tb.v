`timescale 1ns/1ps
module tb;
    reg clk = 0;
    reg rst = 0;
    reg push = 0;
    reg pop = 0;
    reg [7:0] din = 0;
    wire [7:0] dout;
    wire empty, full;
    wire [2:0] count;
    reg [7:0] model [0:3];
    integer size = 0;
    integer cycles = 0;
    integer errors = 0;
    integer i, level, request, repetition;
    integer seed = 12345;
    reg [31:0] random_bits;

    fifo dut(.clk(clk), .rst(rst), .push(push), .pop(pop),
             .din(din), .dout(dout), .empty(empty), .full(full), .count(count));
    always #5 clk = ~clk;

    task step;
        input reset_request, push_request, pop_request;
        input [7:0] data;
        reg do_push, do_pop;
        reg [7:0] expected_front;
        integer j;
        begin
            @(negedge clk);
            rst = reset_request;
            push = push_request;
            pop = pop_request;
            din = data;
            do_push = push_request && (size < 4);
            do_pop = pop_request && (size > 0);
            @(posedge clk);
            if (reset_request) begin
                size = 0;
            end else begin
                // Independent shifting queue model; acceptance uses old size.
                if (do_pop) begin
                    for (j = 0; j < size - 1; j = j + 1)
                        model[j] = model[j + 1];
                    size = size - 1;
                end
                if (do_push) begin
                    model[size] = data;
                    size = size + 1;
                end
            end
            expected_front = (size == 0) ? 8'd0 : model[0];
            #1;
            cycles = cycles + 1;
            if (count !== size || empty !== (size == 0) ||
                full !== (size == 4) || dout !== expected_front) begin
                $display("FAIL cycle=%0d rst/push/pop=%b%b%b count=%0d expected=%0d dout=%h expected=%h empty/full=%b%b",
                         cycles, rst, push, pop, count, size, dout,
                         expected_front, empty, full);
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        step(1, 1, 1, 8'hff);
        // Every control combination at every occupancy, repeated for wraparound.
        for (repetition = 0; repetition < 8; repetition = repetition + 1)
            for (level = 0; level <= 4; level = level + 1)
                for (request = 0; request < 4; request = request + 1) begin
                    step(1, 0, 0, 0);
                    for (i = 0; i < level; i = i + 1)
                        step(0, 1, 0, repetition * 16 + i);
                    step(0, request[1], request[0], 8'ha5);
                    for (i = 0; i < 5; i = i + 1)
                        step(0, 0, 1, 8'hff);
                end
        // Sustained circular operation, including occupancy-one replacement.
        step(0, 1, 0, 8'h00);
        for (i = 0; i < 40; i = i + 1)
            step(0, 1, 1, i);
        step(0, 1, 0, 8'h80);
        step(0, 1, 0, 8'hff);
        for (i = 0; i < 40; i = i + 1)
            step(0, 1, 1, i + 64);
        // Reset priority for all controls and occupancies.
        for (level = 0; level <= 4; level = level + 1)
            for (request = 0; request < 4; request = request + 1) begin
                step(1, 0, 0, 0);
                for (i = 0; i < level; i = i + 1)
                    step(0, 1, 0, i);
                step(1, request[1], request[0], 8'hff);
                step(0, 0, 0, 0);
            end
        for (i = 0; i < 3000; i = i + 1) begin
            random_bits = $random(seed);
            step(random_bits[8:4] == 0, random_bits[0],
                 random_bits[1], random_bits[23:16]);
        end
        for (i = 0; i < 5; i = i + 1)
            step(0, 0, 1, 0);
        if (errors == 0)
            $display("PASS: %0d cycles", cycles);
        else
            $fatal(1, "FAIL: %0d mismatches", errors);
        $finish;
    end
endmodule
