module uart(input clk,rst,send,input [7:0] data,output tx,output busy);
reg [9:0] frame; reg [3:0] remaining; reg [1:0] tick;
assign busy=remaining!=0; assign tx=busy?frame[0]:1'b1;
always @(posedge clk) begin
 if(rst) begin frame<=1023;remaining<=0;tick<=0; end
 else if(busy) begin
  if(tick==3) begin frame<={1'b1,frame[9:1]};remaining<=remaining-1;tick<=0;end
  else tick<=tick+1;
 end else if(send) begin frame<={1'b1,data,1'b0};remaining<=10;tick<=0;end
end
endmodule
