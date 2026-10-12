`timescale 1ns/1ps
module tb;
    reg clk = 0;
    reg rst = 0;
    reg send = 0;
    reg [7:0] data = 0;
    wire tx, busy;
    reg model_busy = 0;
    reg model_tx = 1;
    reg [7:0] captured = 0;
    integer age = 0;
    integer checks = 0;
    integer accepted = 0;
    integer final_ignored = 0;
    integer i, j, k;
    reg [31:0] random_state = 32'h71c3a5e9;

    uart dut(.clk(clk), .rst(rst), .send(send), .data(data),
             .tx(tx), .busy(busy));
    always #5 clk = ~clk;

    task step;
        input reset_in;
        input send_in;
        input [7:0] data_in;
        begin
            @(negedge clk);
            rst = reset_in;
            send = send_in;
            data = data_in;
            @(posedge clk);
            if (reset_in) begin
                model_busy = 0;
                model_tx = 1;
                age = 0;
                captured = 0;
            end else if (model_busy) begin
                age = age + 1;
                if (age == 40) begin
                    if (send_in) final_ignored = final_ignored + 1;
                    model_busy = 0;
                    model_tx = 1;
                end else if (age < 4) model_tx = 0;
                else if (age < 36) model_tx = captured[(age / 4) - 1];
                else model_tx = 1;
            end else if (send_in) begin
                captured = data_in;
                age = 0;
                model_busy = 1;
                model_tx = 0;
                accepted = accepted + 1;
            end else model_tx = 1;
            #1;
            checks = checks + 1;
            if (tx !== model_tx || busy !== model_busy) begin
                $display("FAIL check=%0d age=%0d tx=%b expected=%b busy=%b expected=%b",
                         checks, age, tx, model_tx, busy, model_busy);
                $fatal(1, "UART contract mismatch");
            end
        end
    endtask

    initial begin
        // Establish reset before any comparison; reset wins over send.
        rst = 1;
        step(1, 1, 8'hff);
        repeat (5) step(0, 0, 8'h00);
        // Exhaustive payloads; change data and assert send during every busy edge.
        for (i = 0; i < 256; i = i + 1) begin
            step(0, 1, i[7:0]);
            for (j = 1; j <= 40; j = j + 1)
                step(0, 1, i[7:0] ^ j[7:0]);
            step(0, 0, 8'ha5);
        end
        // Held send across completion must accept only on the next edge.
        for (j = 0; j < 130; j = j + 1) step(0, 1, j[7:0]);
        step(1, 1, 8'h00);
        // Abort/reset at every possible frame age, then restart immediately.
        for (k = 0; k <= 40; k = k + 1) begin
            step(0, 1, 8'h96);
            for (j = 1; j < k; j = j + 1) step(0, 1, 8'h69);
            step(1, 1, 8'hff);
            step(0, 1, 8'h3c);
            repeat (40) step(0, 0, 8'hc3);
        end
        // Deterministic randomized requests, payload changes, and resets.
        for (j = 0; j < 3000; j = j + 1) begin
            random_state = {random_state[30:0],
                random_state[31] ^ random_state[21] ^ random_state[1] ^ random_state[0]};
            step(random_state[7:0] == 8'h00, random_state[8], random_state[23:16]);
        end
        step(1, 0, 8'h00);
        repeat (10) step(0, 0, 8'h00);
        if (accepted < 256 || final_ignored < 256) $fatal(1, "Coverage missing");
        $display("PASS: %0d cycle checks, %0d accepted frames, %0d completion-edge sends ignored",
                 checks, accepted, final_ignored);
        $finish;
    end
    initial begin
        #2000000;
        $fatal(1, "Simulation timeout");
    end
endmodule
