`timescale 1ns/1ps
module tb;
    reg clk = 0;
    reg rst = 0;
    reg valid_in = 0;
    reg [15:0] x_in = 0, y_in = 0, z_in = 0;
    wire valid_out;
    wire [15:0] x_out, y_out, z_out;
    reg [15:0] expected_x = 0, expected_y = 0, expected_z = 0;
    reg expected_valid = 0;
    integer cycles = 0;
    integer accepted = 0;
    integer seed = 32'h13579bdf;
    integer a, b, c, n, rx, ry, rz;
    integer corners [0:8];

    cordic dut(.clk(clk), .rst(rst), .valid_in(valid_in),
        .x_in(x_in), .y_in(y_in), .z_in(z_in),
        .valid_out(valid_out), .x_out(x_out), .y_out(y_out), .z_out(z_out));
    always #5 clk = ~clk;

    function integer wrap16;
        input integer value;
        integer bits;
        begin
            bits = value & 65535;
            wrap16 = (bits >= 32768) ? bits - 65536 : bits;
        end
    endfunction

    // Use division and remainder to model floor rounding independently of >>>.
    function integer floor_shift;
        input integer value;
        input integer index;
        integer divisor;
        begin
            divisor = 1 << index;
            floor_shift = value / divisor;
            if ((value < 0) && ((value % divisor) != 0))
                floor_shift = floor_shift - 1;
        end
    endfunction

    task reference;
        input [15:0] ix, iy, iz;
        integer x, y, z, old_x, old_y, angle, j;
        begin
            x = wrap16(ix);
            y = wrap16(iy);
            z = wrap16(iz);
            for (j = 0; j < 4; j = j + 1) begin
                case (j)
                    0: angle = 8192;
                    1: angle = 4836;
                    2: angle = 2555;
                    3: angle = 1297;
                endcase
                old_x = x;
                old_y = y;
                if (z >= 0) begin
                    x = wrap16(old_x - floor_shift(old_y, j));
                    y = wrap16(old_y + floor_shift(old_x, j));
                    z = wrap16(z - angle);
                end else begin
                    x = wrap16(old_x + floor_shift(old_y, j));
                    y = wrap16(old_y - floor_shift(old_x, j));
                    z = wrap16(z + angle);
                end
            end
            expected_x = x;
            expected_y = y;
            expected_z = z;
        end
    endtask

    task cycle;
        input reset_value, valid_value;
        input [15:0] ix, iy, iz;
        reg [48:0] previous_outputs;
        begin
            @(negedge clk);
            previous_outputs = {valid_out, x_out, y_out, z_out};
            rst = reset_value;
            valid_in = valid_value;
            x_in = ix;
            y_in = iy;
            z_in = iz;
            #1;
            if (cycles != 0 &&
                {valid_out, x_out, y_out, z_out} !== previous_outputs) begin
                $display("FAIL: outputs changed before rising edge");
                $fatal(1);
            end
            if (reset_value) begin
                expected_valid = 0;
                expected_x = 0;
                expected_y = 0;
                expected_z = 0;
            end else begin
                expected_valid = valid_value;
                if (valid_value) begin
                    reference(ix, iy, iz);
                    accepted = accepted + 1;
                end
            end
            @(posedge clk);
            #1;
            cycles = cycles + 1;
            if ({valid_out, x_out, y_out, z_out} !==
                {expected_valid, expected_x, expected_y, expected_z}) begin
                $display("FAIL cycle=%0d rst=%b valid=%b input=%h,%h,%h",
                    cycles, reset_value, valid_value, ix, iy, iz);
                $display("got=%b,%h,%h,%h expected=%b,%h,%h,%h",
                    valid_out, x_out, y_out, z_out,
                    expected_valid, expected_x, expected_y, expected_z);
                $fatal(1);
            end
        end
    endtask

    initial begin
        corners[0] = -32768; corners[1] = -32767;
        corners[2] = -8192; corners[3] = -1;
        corners[4] = 0; corners[5] = 1;
        corners[6] = 8192; corners[7] = 32766; corners[8] = 32767;
        cycle(1, 1, 16'hffff, 16'h8000, 16'h7fff);
        cycle(0, 0, 123, 456, 789);
        for (a = 0; a < 9; a = a + 1)
            for (b = 0; b < 9; b = b + 1)
                for (c = 0; c < 9; c = c + 1)
                    cycle(0, 1, corners[a], corners[b], corners[c]);
        // Sweep every angle pattern with odd signed coordinates.
        for (n = 0; n < 65536; n = n + 1)
            cycle(0, 1, -999, 777, n);
        for (n = 0; n < 10000; n = n + 1) begin
            rx = $random(seed);
            ry = $random(seed);
            rz = $random(seed);
            cycle((n % 137) == 0, (n % 5) != 0, rx, ry, rz);
        end
        for (n = 0; n < 2000; n = n + 1) begin
            rx = ($random(seed) % 1001);
            ry = ($random(seed) % 1001);
            rz = ($random(seed) % 8193);
            cycle(0, 1, rx, ry, rz);
        end
        cycle(0, 0, 16'h8000, 16'hffff, 0);
        cycle(0, 0, 0, 0, 0);
        cycle(1, 0, 1, 2, 3);
        cycle(1, 1, 4, 5, 6);
        cycle(0, 0, 7, 8, 9);
        $display("PASS: %0d cycles, %0d accepted vectors", cycles, accepted);
        $finish;
    end
endmodule
