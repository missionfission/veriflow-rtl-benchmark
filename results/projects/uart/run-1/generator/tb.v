`timescale 1ns/1ps
module tb;
    reg clk = 0;
    reg rst = 1;
    reg send = 0;
    reg [7:0] data = 0;
    wire tx, busy;
    integer edges = 0;
    integer accepted_at = 0;
    integer elapsed;
    integer errors = 0;
    integer accepts = 0;
    integer completions = 0;
    integer i, j;
    reg expected_busy = 0;
    reg expected_tx = 1;
    reg [7:0] captured = 0;
    reg [31:0] random_state = 32'h183da921;

    uart dut(.clk(clk), .rst(rst), .send(send), .data(data),
             .tx(tx), .busy(busy));
    always #5 clk = ~clk;

    // Independent model uses elapsed edge numbers rather than RTL counters.
    always @(posedge clk) begin
        edges = edges + 1;
        if (rst) begin
            expected_busy = 0;
            expected_tx = 1;
        end else if (expected_busy) begin
            elapsed = edges - accepted_at;
            if (elapsed == 40) begin
                expected_busy = 0;
                expected_tx = 1;
                completions = completions + 1;
            end else if (elapsed < 4)
                expected_tx = 0;
            else if (elapsed < 36)
                expected_tx = captured[(elapsed / 4) - 1];
            else
                expected_tx = 1;
        end else if (send) begin
            captured = data;
            accepted_at = edges;
            expected_busy = 1;
            expected_tx = 0;
            accepts = accepts + 1;
        end else begin
            expected_tx = 1;
        end
        #1;
        if (tx !== expected_tx || busy !== expected_busy) begin
            $display("FAIL edge=%0d rst=%b send=%b data=%h tx=%b/%b busy=%b/%b",
                     edges, rst, send, data, tx, expected_tx, busy, expected_busy);
            errors = errors + 1;
        end
    end

    task step;
        input reset_value;
        input send_value;
        input [7:0] byte_value;
        begin
            @(negedge clk);
            rst = reset_value;
            send = send_value;
            data = byte_value;
            @(posedge clk);
            #2;
        end
    endtask

    initial begin
        step(1, 1, 8'hff);
        step(0, 0, 0);
        // Every byte, with data changes and sends throughout the busy window.
        for (i = 0; i < 256; i = i + 1) begin
            step(0, 1, i);
            for (j = 1; j <= 40; j = j + 1)
                step(0, 1, ~i);
            if (busy !== 0) begin
                $display("FAIL completion boundary");
                errors = errors + 1;
            end
        end
        step(0, 0, 0);
        // Reset every phase, including acceptance and the completion edge.
        for (i = 0; i <= 40; i = i + 1) begin
            step(1, 1, 8'h55);
            step(0, 1, 8'ha6);
            for (j = 0; j < i; j = j + 1)
                step(0, 0, 8'hff);
            step(1, 1, 8'hff);
            step(0, 0, 0);
        end
        // Deterministic random sends, data changes, and reset interruptions.
        for (i = 0; i < 4000; i = i + 1) begin
            random_state = random_state ^ (random_state << 13);
            random_state = random_state ^ (random_state >> 17);
            random_state = random_state ^ (random_state << 5);
            step(random_state[7:0] == 0, random_state[8], random_state[23:16]);
        end
        for (i = 0; i < 45; i = i + 1)
            step(0, 0, 0);
        if (errors == 0 && accepts >= 256 && completions >= 256)
            $display("PASS: %0d edges, %0d accepted frames, %0d completed frames",
                     edges, accepts, completions);
        else begin
            $display("FAIL: %0d errors", errors);
            $fatal(1);
        end
        $finish;
    end
endmodule
