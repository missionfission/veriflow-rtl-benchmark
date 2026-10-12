module axi_lite(input clk,rst,awvalid,input [3:0] awaddr,input wvalid,input [31:0] wdata,input [3:0] wstrb,input bready,arvalid,input [3:0] araddr,input rready,output awready,wready,output reg bvalid,output [1:0] bresp,output arready,output reg rvalid,output reg [31:0] rdata,output [1:0] rresp);
reg [31:0] regs[0:3]; reg has_aw,has_w;reg [1:0] aw;reg [31:0] wd;reg [3:0] ws;integer i;
assign awready=!has_aw&&!bvalid;assign wready=!has_w&&!bvalid;
assign arready=!rvalid;assign bresp=0;assign rresp=0;
always @(posedge clk) begin
 if(rst) begin
  for(i=0;i<4;i=i+1) regs[i]<=0;
  has_aw<=0;has_w<=0;bvalid<=0;rvalid<=0;rdata<=0;aw<=0;wd<=0;ws<=0;
 end else begin
  if(bvalid&&bready)bvalid<=0;
  if(has_aw&&has_w&&!bvalid)begin
   for(i=0;i<4;i=i+1)if(ws[i])regs[aw][i*8+:8]<=wd[i*8+:8];
   has_aw<=0;has_w<=0;bvalid<=1;
  end else begin
   if(awready&&awvalid)begin has_aw<=1;aw<=awaddr[3:2];end
   if(wready&&wvalid)begin has_w<=1;wd<=wdata;ws<=wstrb;end
  end
  if(arready&&arvalid)begin rvalid<=1;rdata<=regs[araddr[3:2]];end
  else if(rvalid&&rready)rvalid<=0;
 end
end
endmodule
