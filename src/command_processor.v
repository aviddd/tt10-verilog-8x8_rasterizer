`default_nettype none

module command_processor (
    input  wire       clk,
    input  wire       rst_n,
    input  wire [7:0] ui_in,
    output reg  [1:0] out_cmd,
    output reg  [2:0] out_x1, out_y1, out_x2, out_y2, out_width, out_height,
    output reg        cmd_ready
);

    // Input decoding
    wire       en;
    wire [1:0] cmd;
    wire [4:0] param;

    assign en    = ui_in[7];
    assign cmd   = ui_in[6:5];
    assign param = ui_in[4:0];

    // State Machine States
    localparam IDLE       = 3'd0;
    localparam LOAD_PARAM = 3'd1;
    localparam EXECUTE    = 3'd2;

    reg [2:0] state;
    reg [1:0] current_cmd;
    reg [2:0] x1, y1, x2, y2, width, height;
    reg [2:0] param_count;

    // Internal signals to hold parameters before announcing readiness
    reg [1:0] latched_cmd;
    reg [2:0] latched_x1, latched_y1, latched_x2, latched_y2, latched_width, latched_height;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            current_cmd <= 2'b00;
            param_count <= 3'd0;
            x1 <= 3'd0; y1 <= 3'd0;
            x2 <= 3'd0; y2 <= 3'd0;
            width <= 3'd0; height <= 3'd0;
            out_cmd <= 2'b00;
            out_x1 <= 3'd0; out_y1 <= 3'd0; out_x2 <= 3'd0; out_y2 <= 3'd0; out_width <= 3'd0; out_height <= 3'd0;
            cmd_ready <= 1'b0;
        end else begin
            // By default, cmd_ready is low unless we specifically set it
            cmd_ready <= 1'b0;

            case (state)
                IDLE: begin
                    if (en) begin
                        current_cmd <= cmd;
                        param_count <= 3'd0;
                        case (cmd)
                            2'b01: begin  // DRAW_PIXEL or CLEAR
                                if (param == 5'b11111) begin
                                    // CLEAR command
                                    x1 <= 3'd7;
                                    y1 <= 3'd7;
                                    state <= EXECUTE;
                                end else begin
                                    // DRAW_PIXEL: first param is x1
                                    x1 <= param[2:0];
                                    state <= LOAD_PARAM;
                                end
                            end
                            2'b10: begin  // DRAW_LINE
                                x1 <= param[2:0];
                                state <= LOAD_PARAM;
                            end
                            2'b11: begin  // FILL_RECT
                                x1 <= param[2:0];
                                state <= LOAD_PARAM;
                            end
                            default: begin
                                // NO_OP or unrecognized
                                current_cmd <= 2'b00;
                            end
                        endcase
                    end else begin
                        current_cmd <= 2'b00;
                    end
                end

                LOAD_PARAM: begin
                    if (en && cmd == 2'b00) begin
                        // Use NO_OP to load next param
                        case (current_cmd)
                            2'b01: begin
                                // Next param is y1 for DRAW_PIXEL
                                if (param_count == 3'd0) begin
                                    y1 <= param[2:0];
                                    state <= EXECUTE;
                                end
                                param_count <= param_count + 3'd1;
                            end
                            2'b10: begin
                                // DRAW_LINE: need y1, x2, y2 in sequence
                                case (param_count)
                                    3'd0: y1 <= param[2:0];
                                    3'd1: x2 <= param[2:0];
                                    3'd2: begin
                                        y2 <= param[2:0];
                                        state <= EXECUTE;
                                    end
                                endcase
                                param_count <= param_count + 3'd1;
                            end
                            2'b11: begin
                                // FILL_RECT: need y1, width, height
                                case (param_count)
                                    3'd0: y1 <= param[2:0];
                                    3'd1: width <= param[2:0];
                                    3'd2: begin
                                        height <= param[2:0];
                                        state <= EXECUTE;
                                    end
                                endcase
                                param_count <= param_count + 3'd1;
                            end
                        endcase
                    end else begin
                        // If we expected NO_OP but didn't get it
                        state <= IDLE;
                        current_cmd <= 2'b00;
                    end
                end

                EXECUTE: begin
                    // All parameters are now stable
                    latched_cmd <= current_cmd;
                    latched_x1 <= x1; latched_y1 <= y1; latched_x2 <= x2; latched_y2 <= y2;
                    latched_width <= width; latched_height <= height;

                    // Signal to rasterizer that command and parameters are ready
                    out_cmd <= current_cmd;
                    out_x1 <= x1; out_y1 <= y1; out_x2 <= x2; out_y2 <= y2; out_width <= width; out_height <= height;

                    cmd_ready <= 1'b1;
                    // Return to IDLE and clear current_cmd
                    state <= IDLE;
                    current_cmd <= 2'b00;
                end
            endcase
        end
    end

endmodule
