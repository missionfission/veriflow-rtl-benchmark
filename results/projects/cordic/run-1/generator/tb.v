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
    integer a, b, c, n;
    integer corners [0:11];

    cordic dut(.clk(clk), .rst(rst), .valid_in(valid_in),
        .x_in(x_in), .y_in(y_in), .z_in(z_in), .valid_out(valid_out),
        .x_out(x_out), .y_out(y_out), .z_out(z_out));
    always #5 clk = ~clk;

    function integer signed16;
        input integer value;
        integer masked;
        begin
            masked = value & 65535;
            signed16 = (masked >= 32768) ? masked - 65536 : masked;
        end
    endfunction

    // Reference shifts use division with explicit floor rounding, independently
    // of the DUT's arithmetic shift operators.
    function integer floor_shift;
        input integer value;
        input integer count;
        integer divisor;
        begin
            divisor = 2 ** count;
            if (value < 0)
                floor_shift = -((-value + divisor - 1) / divisor);
            else
                floor_shift = value / divisor;
        end
    endfunction

    task step;
        input reset_value;
        input accept;
        input integer ix, iy, iz;
        integer rx, ry, rz, nx, ny, nz, k, angle;
        begin
            @(negedge clk);
            rst = reset_value;
            valid_in = accept;
            x_in = ix;
            y_in = iy;
            z_in = iz;
            // Every drive must leave registered outputs unchanged until the edge.
            #1;
            if (checks > 0 && {valid_out, x_out, y_out, z_out} !==
                {expected_valid, expected_x, expected_y, expected_z}) begin
                $display("FAIL: outputs changed before a rising edge");
                $fatal(1);
            end
            if (reset_value) begin
                expected_valid = 0;
                expected_x = 0;
                expected_y = 0;
                expected_z = 0;
            end else begin
                expected_valid = accept;
                if (accept) begin
                    rx = signed16(ix);
                    ry = signed16(iy);
                    rz = signed16(iz);
                    for (k = 0; k < 4; k = k + 1) begin
                        case (k)
                            0: angle = 8192;
                            1: angle = 4836;
                            2: angle = 2555;
                            3: angle = 1297;
                        endcase
                        if (rz >= 0) begin
                            nx = rx - floor_shift(ry, k);
                            ny = ry + floor_shift(rx, k);
                            nz = rz - angle;
                        end else begin
                            nx = rx + floor_shift(ry, k);
                            ny = ry - floor_shift(rx, k);
                            nz = rz + angle;
                        end
                        rx = signed16(nx);
                        ry = signed16(ny);
                        rz = signed16(nz);
                    end
                    expected_x = rx;
                    expected_y = ry;
                    expected_z = rz;
                end
            end
            @(posedge clk);
            #1;
            checks = checks + 1;
            if ({valid_out, x_out, y_out, z_out} !==
                {expected_valid, expected_x, expected_y, expected_z}) begin
                $display("FAIL check=%0d rst=%b valid=%b input=%h,%h,%h got=%b:%h,%h,%h expected=%b:%h,%h,%h",
                    checks, rst, valid_in, x_in, y_in, z_in,
                    valid_out, x_out, y_out, z_out,
                    expected_valid, expected_x, expected_y, expected_z);
                $fatal(1);
            end
        end
    endtask

    initial begin
        corners[0] = -32768; corners[1] = -32767;
        corners[2] = -8192; corners[3] = -1000;
        corners[4] = -7; corners[5] = -1;
        corners[6] = 0; corners[7] = 1;
        corners[8] = 7; corners[9] = 1000;
        corners[10] = 8192; corners[11] = 32767;
        step(1, 1, 32767, -32768, -1);
        step(1, 0, 1, 2, 3);
        step(0, 0, 100, 200, 300);
        step(0, 1, 100, -200, 0);
        repeat (5) step(0, 0, -32768, 32767, 32767);
        step(1, 1, 1000, 1000, 8192);
        for (a = 0; a < 12; a = a + 1)
            for (b = 0; b < 12; b = b + 1)
                for (c = 0; c < 12; c = c + 1)
                    step(0, 1, corners[a], corners[b], corners[c]);
        // Exercise every possible angle with varied extreme coordinates.
        for (n = 0; n < 65536; n = n + 1)
            step(0, 1, corners[n % 12], corners[(n / 12) % 12], n);
        for (n = 0; n < 10000; n = n + 1)
            step((n % 101) == 0, (n % 7) != 0, $random, $random, $random);
        for (n = 0; n < 10000; n = n + 1)
            step(0, 1, (($random & 32'h7fffffff) % 2001) - 1000,
                (($random & 32'h7fffffff) % 2001) - 1000,
                (($random & 32'h7fffffff) % 16385) - 8192);
        step(1, 0, 0, 0, 0);
        step(0, 0, 123, 456, 789);
        $display("PASS: %0d self-checking cycles", checks);
        $finish;
    end
endmodule
