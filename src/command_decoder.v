`default_nettype none

module command_decoder (
    input  wire [7:0] ui_in,
    input  wire clk,
    input  wire rst_n,
    output reg  [1:0] command,
    output reg  [2:0] x1, y1, x2, y2, rect_width, rect_height,
    output reg  command_valid
);

    reg [2:0] state;
    localparam IDLE = 3'd0,
               DECODE_CMD = 3'd1,
               LOAD_PARAM1 = 3'd2,
               EXECUTE = 3'd3;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            command <= 2'b00;
            command_valid <= 1'b0;
            x1 <= 3'd0;
            y1 <= 3'd0;
        end else begin
            case (state)
                IDLE: begin
                    command_valid <= 1'b0;
                    if (ui_in[7]) begin  // Command start bit
                        command <= ui_in[6:5];
                        x1 <= ui_in[4:2];
                        state <= DECODE_CMD;
                        $display("IDLE: ui_in=%b, command=%b", ui_in, command);
                    end
                end
                DECODE_CMD: begin
                    y1 <= ui_in[4:2];
                    state <= EXECUTE;
                    $display("DECODE_CMD: x1=%b, y1=%b, state=%b", x1, y1, state);
                end
                EXECUTE: begin
                    command_valid <= 1'b1;
                    $display("EXECUTE: command_valid=%b, x1=%b, y1=%b", command_valid, x1, y1);
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule
