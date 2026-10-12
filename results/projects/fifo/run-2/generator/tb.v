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
    reg [7:0] reference [0:3];
    integer reference_count = 0;
    integer cycles = 0;
    integer old_count;
    integer j;
    integer n;
    integer occupancy;
    integer operation;
    integer reset_operation;
    reg [7:0] expected_front;
    reg [31:0] prng = 32'h13579bdf;

    fifo dut(.clk(clk), .rst(rst), .push(push), .pop(pop),
             .din(din), .dout(dout), .empty(empty), .full(full), .count(count));
    always #5 clk = ~clk;

    task step;
        input reset_value;
        input push_value;
        input pop_value;
        input [7:0] data_value;
        begin
            @(negedge clk);
            rst = reset_value;
            push = push_value;
            pop = pop_value;
            din = data_value;
            old_count = reference_count;
            @(posedge clk);
            if (reset_value) begin
                reference_count = 0;
            end else begin
                // Both decisions use the original count, before either update.
                if (pop_value && old_count > 0) begin
                    for (j = 0; j < 3; j = j + 1)
                        reference[j] = reference[j + 1];
                    reference_count = reference_count - 1;
                end
                if (push_value && old_count < 4) begin
                    reference[reference_count] = data_value;
                    reference_count = reference_count + 1;
                end
            end
            #1;
            cycles = cycles + 1;
            expected_front = (reference_count == 0) ? 8'd0 : reference[0];
            if (count !== reference_count ||
                empty !== (reference_count == 0) ||
                full !== (reference_count == 4) ||
                dout !== expected_front) begin
                $display("FAIL cycle=%0d rst=%b push=%b pop=%b old_count=%0d count=%0d expected_count=%0d dout=%h expected_front=%h empty=%b full=%b",
                         cycles, rst, push, pop, old_count, count,
                         reference_count, dout, expected_front, empty, full);
                $fatal(1, "FIFO mismatch");
            end
        end
    endtask

    initial begin
        step(1, 0, 0, 0);
        // Every request pair at every occupancy, including ignored operations.
        for (occupancy = 0; occupancy <= 4; occupancy = occupancy + 1) begin
            for (operation = 0; operation < 4; operation = operation + 1) begin
                step(1, 0, 0, 0);
                for (n = 0; n < occupancy; n = n + 1)
                    step(0, 1, 0, 8'h40 + n);
                step(0, operation[1], operation[0], 8'ha5);
                repeat (5) step(0, 0, 1, 8'hff);
            end
            // Reset priority for every request pair and starting occupancy.
            for (reset_operation = 0; reset_operation < 4; reset_operation = reset_operation + 1) begin
                step(1, 0, 0, 0);
                for (n = 0; n < occupancy; n = n + 1)
                    step(0, 1, 0, 8'h80 + n);
                step(1, reset_operation[1], reset_operation[0], 8'hff);
                step(0, 0, 0, 0);
            end
        end
        // Exercise all byte values and repeated pointer wrap at occupancy 3.
        step(1, 0, 0, 0);
        repeat (3) step(0, 1, 0, 8'h55);
        for (n = 0; n < 256; n = n + 1)
            step(0, 1, 1, n[7:0]);
        repeat (4) step(0, 0, 1, 0);
        // Deterministic random requests, bytes, and occasional synchronous resets.
        for (n = 0; n < 4096; n = n + 1) begin
            prng = {prng[30:0], prng[31] ^ prng[21] ^ prng[1] ^ prng[0]};
            step(prng[15:8] == 8'h00, prng[0], prng[1], prng[31:24]);
        end
        repeat (5) step(0, 0, 1, 0);
        $display("PASS: %0d self-checking cycles", cycles);
        $finish;
    end

    initial begin
        #100000;
        $fatal(1, "Testbench timeout");
    end
endmodule
