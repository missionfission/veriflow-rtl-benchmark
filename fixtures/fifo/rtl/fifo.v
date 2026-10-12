module fifo(input clk,rst,push,pop,input [7:0] din,output [7:0] dout,output empty,full,output reg [2:0] count);
reg [7:0] mem[0:3]; reg [1:0] rd,wr;
assign empty=count==0; assign full=count==4; assign dout=empty?0:mem[rd];
always @(posedge clk) begin
 if(rst) begin rd<=0; wr<=0; count<=0; end
 else begin
  if(push && !full) begin mem[wr]<=din; wr<=wr+1; end
  if(pop && !empty) rd<=rd+1;
  case ({push && !full,pop && !empty})
   2'b10:count<=count+1;
   2'b01:count<=count-1;
   default:count<=count;
  endcase
 end
end
endmodule
