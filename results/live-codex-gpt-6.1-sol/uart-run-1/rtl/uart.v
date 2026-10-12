module uart(input clk, rst, send, input [7:0] data, output reg tx, busy);
    reg [9:0] frame;
    reg [3:0] bit_index;
    reg [1:0] cycle_count;

    always @(posedge clk) begin
        if (rst) begin
            tx <= 1'b1;
            busy <= 1'b0;
            frame <= 10'b1111111111;
            bit_index <= 4'd0;
            cycle_count <= 2'd0;
        end else if (!busy) begin
            tx <= 1'b1;
            if (send) begin
                frame <= {1'b1, data, 1'b0};
                bit_index <= 4'd0;
                cycle_count <= 2'd0;
                tx <= 1'b0;
                busy <= 1'b1;
            end
        end else if (cycle_count == 2'd3) begin
            cycle_count <= 2'd0;
            if (bit_index == 4'd9) begin
                tx <= 1'b1;
                busy <= 1'b0;
            end else begin
                frame <= {1'b1, frame[9:1]};
                bit_index <= bit_index + 4'd1;
                tx <= frame[1];
            end
        end else begin
            cycle_count <= cycle_count + 2'd1;
        end
    end
endmodule
