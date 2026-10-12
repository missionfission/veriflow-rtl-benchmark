module cordic(
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
    wire signed [15:0] x_stage [0:4];
    wire signed [15:0] y_stage [0:4];
    wire signed [15:0] z_stage [0:4];

    assign x_stage[0] = x_in;
    assign y_stage[0] = y_in;
    assign z_stage[0] = z_in;

    genvar i;
    generate
        for (i = 0; i < 4; i = i + 1) begin : rotation
            localparam signed [15:0] ANGLE =
                (i == 0) ? 16'sd8192 :
                (i == 1) ? 16'sd4836 :
                (i == 2) ? 16'sd2555 : 16'sd1297;
            wire nonnegative;
            assign nonnegative = (z_stage[i] >= 16'sd0);
            assign x_stage[i+1] = nonnegative ?
                x_stage[i] - (y_stage[i] >>> i) :
                x_stage[i] + (y_stage[i] >>> i);
            assign y_stage[i+1] = nonnegative ?
                y_stage[i] + (x_stage[i] >>> i) :
                y_stage[i] - (x_stage[i] >>> i);
            assign z_stage[i+1] = nonnegative ?
                z_stage[i] - ANGLE : z_stage[i] + ANGLE;
        end
    endgenerate

    always @(posedge clk) begin
        if (rst) begin
            valid_out <= 1'b0;
            x_out <= 16'b0;
            y_out <= 16'b0;
            z_out <= 16'b0;
        end else begin
            valid_out <= valid_in;
            if (valid_in) begin
                x_out <= x_stage[4];
                y_out <= y_stage[4];
                z_out <= z_stage[4];
            end
        end
    end
endmodule
