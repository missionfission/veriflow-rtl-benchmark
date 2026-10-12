module axi_lite(input clk,rst,awvalid,input [3:0] awaddr,input wvalid,input [31:0] wdata,input [3:0] wstrb,input bready,arvalid,input [3:0] araddr,input rready,output awready,wready,bvalid,output [1:0] bresp,output arready,rvalid,output [31:0] rdata,output [1:0] rresp);
    reg [31:0] registers [0:3];
    reg has_aw, has_w;
    reg [3:0] buffered_awaddr;
    reg [31:0] buffered_wdata;
    reg [3:0] buffered_wstrb;
    reg bvalid_reg, rvalid_reg;
    reg [31:0] rdata_reg;
    integer i;

    assign awready = !has_aw && !bvalid_reg;
    assign wready = !has_w && !bvalid_reg;
    assign bvalid = bvalid_reg;
    assign bresp = 2'b00;
    assign arready = !rvalid_reg;
    assign rvalid = rvalid_reg;
    assign rdata = rdata_reg;
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
            bvalid_reg <= 1'b0;
            rvalid_reg <= 1'b0;
            rdata_reg <= 32'b0;
        end else begin
            if (awvalid && awready) begin
                buffered_awaddr <= awaddr;
                has_aw <= 1'b1;
            end
            if (wvalid && wready) begin
                buffered_wdata <= wdata;
                buffered_wstrb <= wstrb;
                has_w <= 1'b1;
            end
            if (has_aw && has_w && !bvalid_reg) begin
                for (i = 0; i < 4; i = i + 1)
                    if (buffered_wstrb[i])
                        registers[buffered_awaddr[3:2]][8*i +: 8]
                            <= buffered_wdata[8*i +: 8];
                has_aw <= 1'b0;
                has_w <= 1'b0;
                bvalid_reg <= 1'b1;
            end else if (bvalid_reg && bready) begin
                bvalid_reg <= 1'b0;
            end
            if (arvalid && arready) begin
                rdata_reg <= registers[araddr[3:2]];
                rvalid_reg <= 1'b1;
            end else if (rvalid_reg && rready) begin
                rvalid_reg <= 1'b0;
            end
        end
    end
endmodule
