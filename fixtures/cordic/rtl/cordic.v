module cordic(input clk,rst,valid_in,input signed [15:0] x_in,y_in,z_in,output reg valid_out,output reg [15:0] x_out,y_out,z_out);
reg signed [15:0] x,y,z,nx,ny;reg signed [15:0] angle;integer i;
always @* begin
 x=x_in;y=y_in;z=z_in;nx=0;ny=0;angle=0;
 for(i=0;i<4;i=i+1)begin
  case(i)0:angle=8192;1:angle=4836;2:angle=2555;default:angle=1297;endcase
  if(z>=0)begin nx=x-(y>>>i);ny=y+(x>>>i);z=z-angle;end
  else begin nx=x+(y>>>i);ny=y-(x>>>i);z=z+angle;end
  x=nx;y=ny;
 end
end
always @(posedge clk)begin
 if(rst)begin valid_out<=0;x_out<=0;y_out<=0;z_out<=0;end
 else begin valid_out<=valid_in;if(valid_in)begin x_out<=x;y_out<=y;z_out<=z;end end
end
endmodule
