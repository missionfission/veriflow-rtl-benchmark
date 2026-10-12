module cache(input clk,rst,req,write,input [7:0] addr,input [15:0] wdata,output reg valid,hit,output reg [15:0] rdata);
reg [15:0] backing[0:255];reg [15:0] line_data[0:3];reg [7:0] tags[0:3];reg [3:0] occupied;integer i;
always @(posedge clk)begin
 if(rst)begin
  valid<=0;hit<=0;rdata<=0;occupied<=0;
  for(i=0;i<256;i=i+1)backing[i]<=i*257;
  for(i=0;i<4;i=i+1)begin tags[i]<=0;line_data[i]<=0;end
 end else begin
  valid<=req;
  if(req)begin
   hit<=occupied[addr[1:0]]&&tags[addr[1:0]]==addr;
   if(write)begin backing[addr]<=wdata;rdata<=wdata;line_data[addr[1:0]]<=wdata;end
   else begin
    rdata<=occupied[addr[1:0]]&&tags[addr[1:0]]==addr?line_data[addr[1:0]]:backing[addr];
    line_data[addr[1:0]]<=backing[addr];
   end
   tags[addr[1:0]]<=addr;occupied[addr[1:0]]<=1;
  end
 end
end
endmodule
