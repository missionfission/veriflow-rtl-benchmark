module axi_lite(
    input clk, rst,
    input awvalid,
    input [3:0] awaddr,
    input wvalid,
    input [31:0] wdata,
    input [3:0] wstrb,
    input bready, arvalid,
    input [3:0] araddr,
    input rready,
    output awready, wready,
    output reg bvalid,
    output [1:0] bresp,
    output arready,
    output reg rvalid,
    output reg [31:0] rdata,
    output [1:0] rresp
);
    reg [31:0] registers [0:3];
    reg has_aw, has_w;
    reg [3:0] buffered_awaddr;
    reg [31:0] buffered_wdata;
    reg [3:0] buffered_wstrb;
    integer i;

    assign awready = !has_aw && !bvalid;
    assign wready = !has_w && !bvalid;
    assign arready = !rvalid;
    assign bresp = 2'b00;
    assign rresp = 2'b00;

    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < 4; i = i + 1)
                registers[i] <= 32'b0;
            has_aw <= 1'b0;
            has_w <= 1'b0;
            buffered_awaddr <= 4'b0;
            buffered_wdata <= 32'b0;
            buffered_wstrb <= 4'b0;
            bvalid <= 1'b0;
            rvalid <= 1'b0;
            rdata <= 32'b0;
        end else begin
            if (awvalid && awready) begin
                has_aw <= 1'b1;
                buffered_awaddr <= awaddr;
            end
            if (wvalid && wready) begin
                has_w <= 1'b1;
                buffered_wdata <= wdata;
                buffered_wstrb <= wstrb;
            end
            if (has_aw && has_w && !bvalid) begin
                for (i = 0; i < 4; i = i + 1)
                    if (buffered_wstrb[i])
                        registers[buffered_awaddr[3:2]][8*i +: 8]
                            <= buffered_wdata[8*i +: 8];
                has_aw <= 1'b0;
                has_w <= 1'b0;
                bvalid <= 1'b1;
            end else if (bvalid && bready) begin
                bvalid <= 1'b0;
            end

            if (arvalid && arready) begin
                rdata <= registers[araddr[3:2]];
                rvalid <= 1'b1;
            end else if (rvalid && rready) begin
                rvalid <= 1'b0;
            end
        end
    end
endmodule
