/*
 * Command Processor Module
 * Decodes commands and parameters.
 */

`default_nettype none

module command_processor (
    input  wire       clk,
    input  wire       rst_n,
    input  wire [7:0] ui_in,
    output wire [3:0] pixel_data,
    output wire       frame_sync
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

    // Parameter registers
    reg [2:0] x1, y1, x2, y2, width, height;
    reg [2:0] param_count;

    // Instantiate Rasterizer
    rasterizer raster (
        .clk(clk),
        .rst_n(rst_n),
        .cmd(current_cmd),
        .x1(x1),
        .y1(y1),
        .x2(x2),
        .y2(y2),
        .width(width),
        .height(height),
        .pixel_data(pixel_data),
        .frame_sync(frame_sync)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            current_cmd <= 2'b00;
            param_count <= 3'd0;
            x1 <= 3'd0; y1 <= 3'd0;
            x2 <= 3'd0; y2 <= 3'd0;
            width <= 3'd0; height <= 3'd0;
        end else begin
            case (state)
                IDLE: begin
                    if (en) begin
                        current_cmd <= cmd;
                        param_count <= 3'd0;
                        case (cmd)
                            2'b01: begin  // DRAW_PIXEL or CLEAR
                                if (param == 5'b11111) begin
                                    // CLEAR command
                                    // Set x1 and y1 to 7 so rasterizer recognizes CLEAR
                                    x1 <= 3'd7;
                                    y1 <= 3'd7;
                                    state <= EXECUTE;
                                end else begin
                                    // DRAW_PIXEL
                                    x1 <= param[2:0];
                                    param_count <= 3'd1;
                                    state <= LOAD_PARAM;
                                end
                            end
                            2'b10: begin  // DRAW_LINE
                                x1 <= param[2:0];
                                param_count <= 3'd1;
                                state <= LOAD_PARAM;
                            end
                            2'b11: begin  // FILL_RECT
                                x1 <= param[2:0];
                                param_count <= 3'd1;
                                state <= LOAD_PARAM;
                            end
                            default: begin  // NO_OP or unrecognized
                                state <= IDLE;
                            end
                        endcase
                    end
                end
                LOAD_PARAM: begin
                    if (en && cmd == 2'b00) begin  // NO_OP used for parameter loading
                        param_count <= param_count + 3'd1;
                        case (current_cmd)
                            2'b01: begin  // DRAW_PIXEL
                                if (param_count == 3'd1) begin
                                    y1 <= param[2:0];
                                    state <= EXECUTE;
                                end
                            end
                            2'b10: begin  // DRAW_LINE
                                case (param_count)
                                    3'd1: y1 <= param[2:0];
                                    3'd2: x2 <= param[2:0];
                                    3'd3: begin
                                        y2 <= param[2:0];
                                        state <= EXECUTE;
                                    end
                                endcase
                            end
                            2'b11: begin  // FILL_RECT
                                case (param_count)
                                    3'd1: y1 <= param[2:0];
                                    3'd2: width <= param[2:0];
                                    3'd3: begin
                                        height <= param[2:0];
                                        state <= EXECUTE;
                                    end
                                endcase
                            end
                        endcase
                    end else begin
                        state <= IDLE;  // Error: Expected NO_OP
                    end
                end
                EXECUTE: begin
                    // Signal the rasterizer to execute the command
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule
