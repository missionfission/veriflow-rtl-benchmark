module axi_lite(input clk,rst,awvalid,input [3:0] awaddr,input wvalid,input [31:0] wdata,input [3:0] wstrb,input bready,arvalid,input [3:0] araddr,input rready,output awready,wready,bvalid,output [1:0] bresp,output arready,rvalid,output [31:0] rdata,output [1:0] rresp);

    reg [31:0] registers [0:3];
    reg has_aw, has_w;
    reg [3:0] saved_awaddr;
    reg [31:0] saved_wdata;
    reg [3:0] saved_wstrb;
    reg write_response_valid, read_response_valid;
    reg [31:0] read_data;
    integer index;
    integer lane;

    assign awready = !has_aw && !write_response_valid;
    assign wready = !has_w && !write_response_valid;
    assign bvalid = write_response_valid;
    assign bresp = 2'b00;
    assign arready = !read_response_valid;
    assign rvalid = read_response_valid;
    assign rdata = read_data;
    assign rresp = 2'b00;

    always @(posedge clk) begin
        if (rst) begin
            for (index = 0; index < 4; index = index + 1)
                registers[index] <= 32'b0;
            has_aw <= 1'b0;
            has_w <= 1'b0;
            saved_awaddr <= 4'b0;
            saved_wdata <= 32'b0;
            saved_wstrb <= 4'b0;
            write_response_valid <= 1'b0;
            read_response_valid <= 1'b0;
            read_data <= 32'b0;
        end else begin
            if (awvalid && awready) begin
                saved_awaddr <= awaddr;
                has_aw <= 1'b1;
            end
            if (wvalid && wready) begin
                saved_wdata <= wdata;
                saved_wstrb <= wstrb;
                has_w <= 1'b1;
            end
            if (has_aw && has_w && !write_response_valid) begin
                for (lane = 0; lane < 4; lane = lane + 1)
                    if (saved_wstrb[lane])
                        registers[saved_awaddr[3:2]][lane*8 +: 8]
                            <= saved_wdata[lane*8 +: 8];
                has_aw <= 1'b0;
                has_w <= 1'b0;
                write_response_valid <= 1'b1;
            end else if (write_response_valid && bready) begin
                write_response_valid <= 1'b0;
            end

            if (arvalid && arready) begin
                read_data <= registers[araddr[3:2]];
                read_response_valid <= 1'b1;
            end else if (read_response_valid && rready) begin
                read_response_valid <= 1'b0;
            end
        end
    end
endmodule
