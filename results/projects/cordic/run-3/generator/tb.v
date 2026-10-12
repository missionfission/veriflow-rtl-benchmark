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
    integer checks = 0;
    integer seed = 32'h12345678;
    integer a, b, c, n;
    integer boundaries [0:8];

    cordic dut(clk, rst, valid_in, x_in, y_in, z_in,
               valid_out, x_out, y_out, z_out);
    always #5 clk = ~clk;

    // Integer reference: explicit modulo wrapping and division-based floor
    // shifts, independent of the RTL's fixed-width arithmetic shift operators.
    function integer wrap16;
        input integer value;
        integer residue;
        begin
            residue = value % 65536;
            if (residue < 0) residue = residue + 65536;
            if (residue >= 32768) residue = residue - 65536;
            wrap16 = residue;
        end
    endfunction

    function integer floor_shift;
        input integer value;
        input integer amount;
        integer divisor;
        begin
            divisor = 1 << amount;
            if (value < 0)
                floor_shift = -((-value + divisor - 1) / divisor);
            else
                floor_shift = value / divisor;
        end
    endfunction

    task reference;
        input [15:0] bx, by, bz;
        integer rx, ry, rz, nx, ny, k, angle_value;
        begin
            rx = wrap16(bx);
            ry = wrap16(by);
            rz = wrap16(bz);
            for (k = 0; k < 4; k = k + 1) begin
                case (k)
                    0: angle_value = 8192;
                    1: angle_value = 4836;
                    2: angle_value = 2555;
                    3: angle_value = 1297;
                endcase
                if (rz >= 0) begin
                    nx = rx - floor_shift(ry, k);
                    ny = ry + floor_shift(rx, k);
                    rz = wrap16(rz - angle_value);
                end else begin
                    nx = rx + floor_shift(ry, k);
                    ny = ry - floor_shift(rx, k);
                    rz = wrap16(rz + angle_value);
                end
                rx = wrap16(nx);
                ry = wrap16(ny);
            end
            expected_x = rx;
            expected_y = ry;
            expected_z = rz;
        end
    endtask

    task cycle;
        input reset_value, valid_value;
        input [15:0] bx, by, bz;
        begin
            @(negedge clk);
            rst = reset_value;
            valid_in = valid_value;
            x_in = bx;
            y_in = by;
            z_in = bz;
            // Changing reset and inputs between edges must not change outputs.
            #1;
            if (checks > 0 &&
                {valid_out, x_out, y_out, z_out} !==
                {expected_valid, expected_x, expected_y, expected_z}) begin
                $display("FAIL: outputs changed between rising edges");
                $fatal(1);
            end
            if (reset_value) begin
                expected_valid = 0;
                expected_x = 0;
                expected_y = 0;
                expected_z = 0;
            end else begin
                expected_valid = valid_value;
                if (valid_value) reference(bx, by, bz);
            end
            @(posedge clk);
            #1;
            checks = checks + 1;
            if ({valid_out, x_out, y_out, z_out} !==
                {expected_valid, expected_x, expected_y, expected_z}) begin
                $display("FAIL cycle=%0d rst=%b valid=%b input=%h,%h,%h got=%b,%h,%h,%h expected=%b,%h,%h,%h",
                         checks, rst, valid_in, bx, by, bz,
                         valid_out, x_out, y_out, z_out,
                         expected_valid, expected_x, expected_y, expected_z);
                $fatal(1);
            end
        end
    endtask

    initial begin
        boundaries[0] = -32768;
        boundaries[1] = -32767;
        boundaries[2] = -8192;
        boundaries[3] = -1;
        boundaries[4] = 0;
        boundaries[5] = 1;
        boundaries[6] = 8192;
        boundaries[7] = 32766;
        boundaries[8] = 32767;
        cycle(1, 1, 16'h7fff, 16'h8000, 16'hffff);
        cycle(0, 0, 1, 2, 3);
        cycle(0, 1, 1000, 0, 0);
        cycle(0, 0, 16'hffff, 16'hffff, 16'hffff);
        cycle(1, 0, 123, 456, 789);
        for (a = 0; a < 9; a = a + 1)
            for (b = 0; b < 9; b = b + 1)
                for (c = 0; c < 9; c = c + 1)
                    cycle(0, 1, boundaries[a], boundaries[b], boundaries[c]);
        // Sweep all angle patterns with signed odd coordinates and overflow.
        for (n = 0; n < 65536; n = n + 1)
            cycle(0, 1, -32767, 32765, n);
        for (n = 0; n < 3000; n = n + 1) begin
            a = $random(seed);
            b = $random(seed);
            c = $random(seed);
            cycle((n % 257) == 0, (n % 7) != 0,
                  a % 1001, b % 1001, c % 8193);
        end
        for (n = 0; n < 10000; n = n + 1) begin
            a = $random(seed);
            b = $random(seed);
            c = $random(seed);
            cycle((n % 509) == 0, (n % 5) != 0, a, b, c);
        end
        cycle(1, 1, 16'hffff, 16'h8000, 16'h7fff);
        cycle(0, 0, 0, 0, 0);
        $display("PASS: %0d checked cycles", checks);
        $finish;
    end
endmodule
