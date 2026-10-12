module cache(
    input clk,
    input rst,
    input req,
    input write,
    input [7:0] addr,
    input [15:0] wdata,
    output reg valid,
    output reg hit,
    output reg [15:0] rdata
);
    reg [3:0] line_valid;
    reg [5:0] line_tag [0:3];
    reg [15:0] line_data [0:3];
    reg [15:0] backing [0:255];
    integer i;

    wire [1:0] index;
    wire [5:0] tag;
    wire lookup_hit;
    wire [15:0] response_data;
    assign index = addr[1:0];
    assign tag = addr[7:2];
    assign lookup_hit = line_valid[index] && (line_tag[index] == tag);
    assign response_data = write ? wdata :
                           (lookup_hit ? line_data[index] : backing[addr]);

    always @(posedge clk) begin
        if (rst) begin
            line_valid <= 4'b0000;
            for (i = 0; i < 4; i = i + 1) begin
                line_tag[i] <= 6'b0;
                line_data[i] <= 16'b0;
            end
            for (i = 0; i < 256; i = i + 1)
                backing[i] <= i * 257;
            valid <= 1'b0;
            hit <= 1'b0;
            rdata <= 16'b0;
        end else begin
            valid <= req;
            if (req) begin
                hit <= lookup_hit;
                rdata <= response_data;
                line_valid[index] <= 1'b1;
                line_tag[index] <= tag;
                line_data[index] <= response_data;
                if (write)
                    backing[addr] <= wdata;
            end
        end
    end
endmodule
