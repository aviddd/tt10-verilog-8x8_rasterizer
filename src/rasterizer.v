`default_nettype none

module rasterizer (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [1:0] out_cmd,
    input  wire [2:0] out_x1, out_y1, out_x2, out_y2, out_width, out_height,
    input  wire        cmd_ready,
    output reg  [3:0] pixel_data,
    output reg         frame_sync
);

    integer i, j;
    reg [7:0] frame_buffer [7:0];

    reg [2:0] raster_state;
    localparam R_IDLE  = 3'd0;
    localparam R_WAIT  = 3'd1; // New state to wait after cmd_ready
    localparam R_DRAW  = 3'd2;
    localparam R_OUTPUT = 3'd3;

    reg [1:0] latched_cmd;
    reg [2:0] latched_x1, latched_y1, latched_x2, latched_y2, latched_width, latched_height;
    reg [5:0] output_counter;
    reg [2:0] x_addr, y_addr;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            raster_state <= R_IDLE;
            frame_sync <= 1'b0;
            output_counter <= 6'd0;
            x_addr <= 3'd0;
            y_addr <= 3'd0;
            latched_cmd <= 2'b00;
            latched_x1 <= 3'd0; latched_y1 <= 3'd0; latched_x2 <= 3'd0; latched_y2 <= 3'd0; latched_width <= 3'd0; latched_height <= 3'd0;
            for (i = 0; i < 8; i = i + 1) begin
                frame_buffer[i] = 8'b0;
            end
        end else begin
            case (raster_state)
                R_IDLE: begin
                    frame_sync <= 1'b0;
                    if (cmd_ready) begin
                        raster_state <= R_WAIT; 
                    end
                end

                R_WAIT: begin
                    latched_cmd <= out_cmd;
                    latched_x1 <= out_x1;
                    latched_y1 <= out_y1;
                    latched_x2 <= out_x2;
                    latched_y2 <= out_y2;
                    latched_width <= out_width;
                    latched_height <= out_height;
                    raster_state <= R_DRAW; 
                end

                R_DRAW: begin
                    case (latched_cmd)
                        2'b01: begin
                            if (latched_x1 == 3'd7 && latched_y1 == 3'd7) begin
                                for (i = 0; i < 8; i = i + 1) 
                                    frame_buffer[i] = 8'b0;
                            end else begin
                                frame_buffer[latched_y1][latched_x1] <= 1'b1;
                            end
                        end
                        2'b10: begin
                            frame_buffer[latched_y1][latched_x1] <= 1'b1;
                            frame_buffer[latched_y2][latched_x2] <= 1'b1;
                        end
                        2'b11: begin
                            for (i = latched_y1; i < latched_y1 + latched_height; i = i + 1) begin
                                for (j = latched_x1; j < latched_x1 + latched_width; j = j + 1) begin
                                    if (i < 8 && j < 8) 
                                        frame_buffer[i][j] <= 1'b1;
                                end
                            end
                        end
                        default: ; // NO_OP
                    endcase
                    frame_sync <= 1'b1;
                    output_counter <= 6'd0; 
                    raster_state <= R_OUTPUT; 
                end

                R_OUTPUT: begin
                    frame_sync <= 1'b0;
                    output_counter <= output_counter + 6'd1; // Increment first
                    x_addr <= output_counter[2:0];         // Then assign
                    y_addr <= output_counter[5:3];
                    if (output_counter == 6'd63) begin
                        raster_state <= R_IDLE;           
                    end
                end
            endcase
        end
    end

    always @(*) begin
        pixel_data = {3'b000, frame_buffer[y_addr][x_addr]};
    end

endmodule
