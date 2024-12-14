module graphics_processor (
    input  wire clk,
    input  wire rst_n,
    input  wire [1:0] command,
    input  wire [2:0] x1, y1, x2, y2, rect_width, rect_height,
    input  wire command_valid,
    output reg  [3:0] pixel_data,
    output reg  frame_start
);

    reg [7:0] frame_buffer [0:7];
    reg [5:0] pixel_count;
    reg [1:0] latched_command; // Added latched command
    reg [2:0] latched_x1, latched_y1, latched_x2, latched_y2, latched_rect_width, latched_rect_height; // Added latched parameters


    // State machine for graphics processing
    localparam IDLE = 2'd0,
               DRAW = 2'd1,
               OUTPUT = 2'd2;

    reg [1:0] state;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            pixel_data <= 4'b0000;
            frame_start <= 1'b0;
            pixel_count <= 6'd0;
            // Initialize frame buffer (clear screen)
            for (int i = 0; i < 8; i++) begin
                frame_buffer[i] <= 8'b00000000;
            end
        end else begin
            case (state)
                IDLE: begin
                    frame_start <= 1'b0;
                    if (command_valid) begin
                        // Latch the command and parameters
                        latched_command <= command;
                        latched_x1 <= x1;
                        latched_y1 <= y1;
                        latched_x2 <= x2;
                        latched_y2 <= y2;
                        latched_rect_width <= rect_width;
                        latched_rect_height <= rect_height;
                        state <= DRAW;
                    end
                end
                DRAW: begin
                    case (latched_command) // Use latched command
                        2'b01: begin // DRAW_PIXEL or CLEAR
                            if (latched_x1 == 3'b111) begin // CLEAR
                                for (int i = 0; i < 8; i++) begin
                                    frame_buffer[i] <= 8'b00000000;
                                end
                            end else begin
                                frame_buffer[latched_y1][latched_x1] <= 1'b1;
                            end
                        end
                        2'b10: begin // DRAW_LINE
                            // TODO: Implement Bresenham's line algorithm
                            frame_buffer[latched_y1][latched_x1] <= 1'b1;
                            frame_buffer[latched_y2][latched_x2] <= 1'b1;
                        end
                        2'b11: begin // FILL_RECT
                            // TODO: Implement rectangle fill algorithm
                            for (int i = latched_y1; i <= latched_y1 + latched_rect_height; i++) begin
                                for (int j = latched_x1; j <= latched_x1 + latched_rect_width; j++) begin
                                    if (i < 8 && j < 8) begin
                                        frame_buffer[i][j] <= 1'b1;
                                    end
                                end
                            end
                        end
                    endcase
                    frame_start <= 1'b1;
                    state <= OUTPUT;
                    pixel_count <= 6'd0; 
                end
                OUTPUT: begin
                    frame_start <= 1'b0;
                    pixel_data <= frame_buffer[pixel_count[5:3]][pixel_count[2:0]];
                    pixel_count <= pixel_count + 1'b1;
                    if (pixel_count == 6'd63) begin
                        state <= IDLE;
                    end
                end
            endcase
        end
    end

endmodule
