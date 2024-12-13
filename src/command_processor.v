`default_nettype none

module command_processor (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [7:0] ui_in,
    output reg  [1:0] out_cmd,
    output reg  [2:0] out_x1, out_y1, out_x2, out_y2, out_width, out_height,
    output reg         cmd_ready 
);

    reg cmd_sent;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            out_cmd <= 2'b00;
            out_x1 <= 3'd0;
            out_y1 <= 3'd0;
            out_x2 <= 3'd0;
            out_y2 <= 3'd0;
            out_width <= 3'd0;
            out_height <= 3'd0;
            cmd_ready <= 1'b0;
            cmd_sent <= 1'b0; 
        end else begin
            if (ui_in[7] && !cmd_sent) begin 
                cmd_sent <= 1'b1;
                out_cmd <= ui_in[6:5];         // Latch command
                out_x1 <= ui_in[2:0];          // Latch x1 simultaneously
                out_y1 <= ui_in[5:3];          // Latch y1
                out_x2 <= {ui_in[1:0], 1'b0}; // Latch x2
                out_y2 <= {ui_in[4:3], 1'b0}; // Latch y2
                out_width <= ui_in[2:0];      // Latch width
                out_height <= ui_in[2:0];     // Latch height
            end else if (cmd_ready) begin 
                cmd_sent <= 1'b0;
            end
            cmd_ready <= cmd_sent; 
        end
    end

endmodule
