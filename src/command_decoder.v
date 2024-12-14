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
               LOAD_PARAM2 = 3'd3,
               LOAD_PARAM3 = 3'd4,
               EXECUTE = 3'd5;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            command <= 2'b00;
            command_valid <= 1'b0;
            x1 <= 3'd0;
            y1 <= 3'd0;
            x2 <= 3'd0;
            y2 <= 3'd0;
            rect_width <= 3'd0;
            rect_height <= 3'd0;
        end else begin
            case (state)
                IDLE: begin
                    command_valid <= 1'b0;
                    if (ui_in[7]) begin  // Command start bit
                        command <= ui_in[6:5];
                        state <= DECODE_CMD;
                    end
                end
                DECODE_CMD: begin
                    case (command)
                        2'b00: state <= IDLE; // NOOP
                        2'b01: begin // DRAW_PIXEL or CLEAR
                            x1 <= ui_in[4:2];
                            if (ui_in[4:2] == 3'b111) begin // CLEAR
                                state <= EXECUTE;
                            end else begin
                                state <= LOAD_PARAM1;
                            end
                        end
                        2'b10: begin // DRAW_LINE
                            x1 <= ui_in[4:2];
                            state <= LOAD_PARAM1;
                        end
                        2'b11: begin // FILL_RECT
                            x1 <= ui_in[4:2];
                            state <= LOAD_PARAM1;
                        end
                    endcase
                end
                LOAD_PARAM1: begin
                    y1 <= ui_in[4:2];
                    if (command == 2'b01) begin // DRAW_PIXEL
                        state <= EXECUTE;
                    end else begin
                        state <= LOAD_PARAM2;
                    end
                end
                LOAD_PARAM2: begin
                    case (command)
                        2'b10: x2 <= ui_in[4:2];  // DRAW_LINE
                        2'b11: rect_width <= ui_in[4:2]; // FILL_RECT
                    endcase
                    state <= LOAD_PARAM3;
                end
                LOAD_PARAM3: begin
                    case (command)
                        2'b10: y2 <= ui_in[4:2];  // DRAW_LINE
                        2'b11: rect_height <= ui_in[4:2]; // FILL_RECT
                    endcase
                    state <= EXECUTE;
                end
                EXECUTE: begin
                    command_valid <= 1'b1;
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule
