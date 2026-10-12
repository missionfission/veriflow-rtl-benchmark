module cache (
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
    reg [15:0] backing [0:255];
    reg [15:0] line_data [0:3];
    reg [5:0] line_tag [0:3];
    reg [3:0] line_valid;
    wire [1:0] index;
    wire [5:0] tag;
    wire lookup_hit;
    wire [15:0] read_value;
    integer a;

    assign index = addr[1:0];
    assign tag = addr[7:2];
    assign lookup_hit = line_valid[index] && (line_tag[index] == tag);
    assign read_value = lookup_hit ? line_data[index] : backing[addr];

    always @(posedge clk) begin
        if (rst) begin
            valid <= 1'b0;
            hit <= 1'b0;
            rdata <= 16'b0;
            line_valid <= 4'b0;
            for (a = 0; a < 256; a = a + 1)
                backing[a] <= a * 257;
            for (a = 0; a < 4; a = a + 1) begin
                line_data[a] <= 16'b0;
                line_tag[a] <= 6'b0;
            end
        end else begin
            valid <= req;
            if (req) begin
                hit <= lookup_hit;
                line_valid[index] <= 1'b1;
                line_tag[index] <= tag;
                if (write) begin
                    backing[addr] <= wdata;
                    line_data[index] <= wdata;
                    rdata <= wdata;
                end else begin
                    line_data[index] <= read_value;
                    rdata <= read_value;
                end
            end
        end
    end
endmodule
