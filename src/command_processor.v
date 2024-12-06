/*
 * TinyGPU Top Module
 * Author: David Sharma
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_david_tinygpu (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path (unused)
    output wire [7:0] uio_out,  // IOs: Output path (unused)
    output wire [7:0] uio_oe,   // IOs: Enable path (unused)
    input  wire       ena,      // always 1 when the design is powered
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - active low reset
);

    // Internal wires
    wire [3:0] pixel_data;
    wire       frame_sync;

    // Assign outputs
    assign uo_out[3:0] = pixel_data;
    assign uo_out[4]   = frame_sync;
    assign uo_out[7:5] = 3'b000;  // Unused outputs

    // Unused IOs
    assign uio_out = 8'b00000000;
    assign uio_oe  = 8'b00000000;

    // Instantiate Command Processor
    command_processor cmd_proc (
        .clk(clk),
        .rst_n(rst_n),
        .ui_in(ui_in),
        .pixel_data(pixel_data),
        .frame_sync(frame_sync)
    );

    // List all unused inputs to prevent warnings
    wire _unused = &{ena, uio_in};

endmodule

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


/*
 * Rasterizer Module
 * Converts commands into pixel data.
 */

`default_nettype none

module rasterizer (
    input  wire       clk,
    input  wire       rst_n,
    input  wire [1:0] cmd,
    input  wire [2:0] x1, y1, x2, y2, width, height,
    output reg  [3:0] pixel_data,
    output reg        frame_sync
);

    integer i, j;

    // 8x8 frame buffer, each element is one row of pixels
    reg [7:0] frame_buffer [7:0];

    // Serializer
    reg [2:0] x_addr, y_addr;
    reg [5:0] output_counter;

    // Rasterization States
    reg [2:0] raster_state;
    localparam R_IDLE     = 3'd0;
    localparam R_DRAW     = 3'd1;
    localparam R_OUTPUT   = 3'd2;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            raster_state <= R_IDLE;
            frame_sync <= 1'b0;
            output_counter <= 6'd0;
            // Clear frame buffer at reset
            for (i = 0; i < 8; i = i + 1) begin
                frame_buffer[i] <= 8'b0;
            end
        end else begin
            case (raster_state)
                R_IDLE: begin
                    frame_sync <= 1'b0;
                    if (cmd != 2'b00) begin  // There is a command to execute
                        case (cmd)
                            2'b01: begin  // DRAW_PIXEL or CLEAR
                                if (x1 == 3'd7 && y1 == 3'd7) begin
                                    // CLEAR command
                                    for (i = 0; i < 8; i = i + 1) begin
                                        frame_buffer[i] <= 8'b0;
                                    end
                                end else begin
                                    // DRAW_PIXEL
                                    frame_buffer[y1][x1] <= 1'b1;
                                end
                                raster_state <= R_OUTPUT;
                            end
                            2'b10: begin  // DRAW_LINE (simple endpoints)
                                frame_buffer[y1][x1] <= 1'b1;
                                frame_buffer[y2][x2] <= 1'b1;
                                raster_state <= R_OUTPUT;
                            end
                            2'b11: begin  // FILL_RECT
                                for (i = y1; i < y1 + height; i = i + 1) begin
                                    for (j = x1; j < x1 + width; j = j + 1) begin
                                        if (i < 8 && j < 8) begin
                                            frame_buffer[i][j] <= 1'b1;
                                        end
                                    end
                                end
                                raster_state <= R_OUTPUT;
                            end
                        endcase
                    end
                end
                R_OUTPUT: begin
                    // Signal that the next cycle will output pixels
                    frame_sync <= 1'b1;
                    output_counter <= 6'd0;
                    raster_state <= R_DRAW;
                end
                R_DRAW: begin
                    frame_sync <= 1'b0;
                    // Serialize the frame buffer
                    x_addr <= output_counter[2:0];
                    y_addr <= output_counter[5:3];
                    pixel_data <= {3'b000, frame_buffer[y_addr][x_addr]};
                    output_counter <= output_counter + 6'd1;
                    if (output_counter == 6'd63) begin
                        raster_state <= R_IDLE;
                    end
                end
            endcase
        end
    end

endmodule
