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

    // Declare integers at the module level so they're visible and legal everywhere needed
    integer i, j;

    // Frame Buffer Instance
    reg [7:0] frame_buffer [7:0];  // 8x8 frame buffer

    // Control signals
    reg [2:0] x_addr, y_addr;
    reg       write_en;
    reg       pixel_in;

    // State Machine for Rasterization
    reg [2:0] raster_state;
    localparam R_IDLE     = 3'd0;
    localparam R_DRAW     = 3'd1;
    localparam R_OUTPUT   = 3'd2;

    // Output Serializer
    reg [5:0] output_counter;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            raster_state <= R_IDLE;
            frame_sync <= 1'b0;
            output_counter <= 6'd0;
            // Clear frame buffer
            for (i = 0; i < 8; i = i + 1) begin
                frame_buffer[i] <= 8'b0;
            end
        end else begin
            case (raster_state)
                R_IDLE: begin
                    frame_sync <= 1'b0;
                    if (cmd != 2'b00) begin  // If there is a command to execute
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
                            2'b10: begin  // DRAW_LINE
                                // Simplified line drawing (set start and end points)
                                frame_buffer[y1][x1] <= 1'b1;
                                frame_buffer[y2][x2] <= 1'b1;
                                raster_state <= R_OUTPUT;
                            end
                            2'b11: begin  // FILL_RECT
                                // Simplified rectangle filling
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
                    // Start frame synchronization and output serialized data
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
