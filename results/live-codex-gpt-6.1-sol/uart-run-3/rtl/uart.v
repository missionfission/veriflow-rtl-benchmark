module uart(input clk, rst, send, input [7:0] data, output reg tx, busy);
    reg [7:0] shift_data;
    reg [5:0] cycle_count;

    always @(posedge clk) begin
        if (rst) begin
            tx <= 1'b1;
            busy <= 1'b0;
            shift_data <= 8'b0;
            cycle_count <= 6'b0;
        end else if (!busy) begin
            tx <= 1'b1;
            if (send) begin
                shift_data <= data;
                cycle_count <= 6'b0;
                tx <= 1'b0;
                busy <= 1'b1;
            end
        end else if (cycle_count == 6'd39) begin
            tx <= 1'b1;
            busy <= 1'b0;
            cycle_count <= 6'b0;
        end else begin
            cycle_count <= cycle_count + 6'd1;
            if (cycle_count[1:0] == 2'b11) begin
                if (cycle_count < 6'd35) begin
                    tx <= shift_data[0];
                    shift_data <= {1'b0, shift_data[7:1]};
                end else begin
                    tx <= 1'b1;
                end
            end
        end
    end
endmodule
