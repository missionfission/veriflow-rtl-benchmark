module fifo(input clk,rst,push,pop,input [7:0] din,output [7:0] dout,output empty,full,output [2:0] count);
    reg [7:0] storage [0:3];
    reg [1:0] read_ptr;
    reg [1:0] write_ptr;
    reg [2:0] occupancy;
    wire accept_push;
    wire accept_pop;

    assign count = occupancy;
    assign empty = (occupancy == 3'd0);
    assign full = (occupancy == 3'd4);
    assign dout = empty ? 8'd0 : storage[read_ptr];
    assign accept_push = push && !full;
    assign accept_pop = pop && !empty;

    always @(posedge clk) begin
        if (rst) begin
            read_ptr <= 2'd0;
            write_ptr <= 2'd0;
            occupancy <= 3'd0;
        end else begin
            if (accept_push) begin
                storage[write_ptr] <= din;
                write_ptr <= write_ptr + 2'd1;
            end
            if (accept_pop)
                read_ptr <= read_ptr + 2'd1;
            case ({accept_push, accept_pop})
                2'b10: occupancy <= occupancy + 3'd1;
                2'b01: occupancy <= occupancy - 3'd1;
                default: occupancy <= occupancy;
            endcase
        end
    end
endmodule
