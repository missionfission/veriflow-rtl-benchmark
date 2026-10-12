`timescale 1ns/1ps
module tb;
    reg clk = 0;
    reg rst = 0;
    reg send = 0;
    reg [7:0] data = 0;
    wire tx, busy;
    uart dut(.clk(clk), .rst(rst), .send(send), .data(data),
             .tx(tx), .busy(busy));
    always #5 clk = ~clk;

    integer cycle = 0;
    integer accepted = 0;
    integer age;
    integer checks = 0;
    integer frames = 0;
    reg model_busy = 0;
    reg model_tx = 1;
    reg [7:0] model_data = 0;
    integer i, j;
    integer seed = 32'h12345678;
    reg [31:0] random_value;

    task step;
        input reset_value;
        input send_value;
        input [7:0] data_value;
        begin
            @(negedge clk);
            rst = reset_value;
            send = send_value;
            data = data_value;
            @(posedge clk);
            cycle = cycle + 1;
            if (rst) begin
                model_busy = 0;
                model_tx = 1;
            end else if (model_busy) begin
                age = cycle - accepted;
                if (age == 40) begin
                    model_busy = 0;
                    model_tx = 1;
                end else if (age < 4) model_tx = 0;
                else if (age < 36) model_tx = model_data[(age-4)/4];
                else model_tx = 1;
            end else if (send) begin
                model_data = data;
                accepted = cycle;
                model_busy = 1;
                model_tx = 0;
                frames = frames + 1;
            end else model_tx = 1;
            #1;
            checks = checks + 1;
            if (tx !== model_tx || busy !== model_busy) begin
                $display("FAIL cycle=%0d tx=%b expected=%b busy=%b expected=%b",
                         cycle, tx, model_tx, busy, model_busy);
                $fatal(1);
            end
        end
    endtask

    initial begin
        step(1, 1, 8'hff);
        repeat (4) step(0, 0, 0);
        // Exhaustive bytes, continuously asserted send, and changing input data.
        // The send at the completion edge must be ignored.
        for (i = 0; i < 256; i = i + 1) begin
            step(0, 1, i);
            for (j = 1; j <= 40; j = j + 1)
                step(0, 1, i ^ j);
        end
        step(0, 0, 0);
        // Abort at every position, including acceptance and completion edges.
        for (i = 0; i <= 40; i = i + 1) begin
            step(1, 0, 0);
            step(0, 1, 8'ha5);
            for (j = 0; j < i; j = j + 1) step(0, 0, 8'h5a);
            step(1, 1, 8'hff);
            step(0, 0, 0);
            step(0, 1, 8'h3c);
            repeat (40) step(0, 0, 0);
        end
        for (i = 0; i < 3000; i = i + 1) begin
            random_value = $random(seed);
            step(random_value[7:0] == 0, random_value[8], random_value[23:16]);
        end
        repeat (41) step(0, 0, 0);
        $display("PASS: %0d cycle checks, %0d accepted frames", checks, frames);
        $finish;
    end
endmodule
