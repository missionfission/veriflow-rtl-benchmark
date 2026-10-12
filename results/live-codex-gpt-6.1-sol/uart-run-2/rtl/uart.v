module uart(input clk,rst,send,input [7:0] data,output reg tx,busy);
    reg [7:0] captured;
    reg [5:0] elapsed;

    always @(posedge clk) begin
        if (rst) begin
            tx <= 1'b1;
            busy <= 1'b0;
            captured <= 8'b0;
            elapsed <= 6'b0;
        end else if (busy) begin
            if (elapsed == 6'd39) begin
                tx <= 1'b1;
                busy <= 1'b0;
                elapsed <= 6'b0;
            end else begin
                elapsed <= elapsed + 6'd1;
                case (elapsed)
                    6'd3:  tx <= captured[0];
                    6'd7:  tx <= captured[1];
                    6'd11: tx <= captured[2];
                    6'd15: tx <= captured[3];
                    6'd19: tx <= captured[4];
                    6'd23: tx <= captured[5];
                    6'd27: tx <= captured[6];
                    6'd31: tx <= captured[7];
                    6'd35: tx <= 1'b1;
                    default: begin end
                endcase
            end
        end else begin
            tx <= 1'b1;
            if (send) begin
                captured <= data;
                elapsed <= 6'b0;
                tx <= 1'b0;
                busy <= 1'b1;
            end
        end
    end
endmodule
