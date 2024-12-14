`default_nettype none

module command_decoder (
    input  wire [7:0] ui_in,
    input  wire clk,
    input  wire rst_n,
    output reg  [1:0] command,
    output reg  [2:0] x1, y1,
    output reg  command_valid
);

    reg [1:0] state;
    localparam IDLE = 2'b00,
               DECODE_X1 = 2'b01,
               DECODE_Y1 = 2'b10,
               EXECUTE = 2'b11;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            command <= 2'b00;
            x1 <= 3'd0;
            y1 <= 3'd0;
            command_valid <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    command_valid <= 1'b0;
                    if (ui_in[7]) begin  // Start bit detected
                        command <= ui_in[6:5];  // Extract command
                        x1 <= ui_in[4:2];       // Extract x1
                        state <= DECODE_X1;
                        $display("IDLE: ui_in=%b, command=%b, x1=%b", ui_in, command, x1);
                    end
                end
                DECODE_X1: begin
                    state <= DECODE_Y1;
                    $display("DECODE_X1: x1=%b", x1);
                end
                DECODE_Y1: begin
                    y1 <= ui_in[4:2];  // Extract y1
                    state <= EXECUTE;
                    $display("DECODE_Y1: y1=%b", y1);
                end
                EXECUTE: begin
                    command_valid <= 1'b1;
                    $display("EXECUTE: command=%b, command_valid=%b, x1=%b, y1=%b", command, command_valid, x1, y1);
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule
