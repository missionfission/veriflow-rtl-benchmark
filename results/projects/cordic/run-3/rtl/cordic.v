module cordic (
    input clk,
    input rst,
    input valid_in,
    input [15:0] x_in,
    input [15:0] y_in,
    input [15:0] z_in,
    output reg valid_out,
    output reg [15:0] x_out,
    output reg [15:0] y_out,
    output reg [15:0] z_out
);
    reg signed [15:0] x_work, y_work, z_work;
    reg signed [15:0] x_next, y_next;
    reg signed [15:0] angle;
    integer i;

    always @* begin
        x_work = x_in;
        y_work = y_in;
        z_work = z_in;
        x_next = 16'sd0;
        y_next = 16'sd0;
        angle = 16'sd0;
        for (i = 0; i < 4; i = i + 1) begin
            case (i)
                0: angle = 16'sd8192;
                1: angle = 16'sd4836;
                2: angle = 16'sd2555;
                3: angle = 16'sd1297;
                default: angle = 16'sd0;
            endcase
            if (z_work >= 16'sd0) begin
                x_next = x_work - (y_work >>> i);
                y_next = y_work + (x_work >>> i);
                z_work = z_work - angle;
            end else begin
                x_next = x_work + (y_work >>> i);
                y_next = y_work - (x_work >>> i);
                z_work = z_work + angle;
            end
            x_work = x_next;
            y_work = y_next;
        end
    end

    always @(posedge clk) begin
        if (rst) begin
            valid_out <= 1'b0;
            x_out <= 16'd0;
            y_out <= 16'd0;
            z_out <= 16'd0;
        end else begin
            valid_out <= valid_in;
            if (valid_in) begin
                x_out <= x_work;
                y_out <= y_work;
                z_out <= z_work;
            end
        end
    end
endmodule
