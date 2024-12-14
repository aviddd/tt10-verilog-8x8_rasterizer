`default_nettype none

module graphics_processor (
    input  wire clk,
    input  wire rst_n,
    input  wire [1:0] command,
    input  wire [2:0] x1, y1,
    input  wire command_valid,
    output reg  [3:0] pixel_data,
    output reg  frame_start
);

    reg [7:0] frame_buffer [0:7];
    reg [5:0] pixel_count;
    reg [2:0] latched_x1, latched_y1;

    localparam IDLE = 2'd0,
               DRAW = 2'd1,
               OUTPUT = 2'd2;

    reg [1:0] state;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            latched_x1 <= 3'd0;
            latched_y1 <= 3'd0;
            frame_start <= 1'b0;
            pixel_data <= 4'b0;
            for (int i = 0; i < 8; i++) frame_buffer[i] <= 8'b0;
        end else begin
            case (state)
                IDLE: begin
                    if (command_valid) begin
                        latched_x1 <= x1;
                        latched_y1 <= y1;
                        state <= DRAW;
                        $display("IDLE -> DRAW: latched_x1=%d, latched_y1=%d", latched_x1, latched_y1);
                    end
                end
                DRAW: begin
                    frame_buffer[latched_y1][latched_x1] <= 1'b1;
                    frame_start <= 1'b1;
                    $display("DRAW: frame_buffer[%d][%d]=%b", latched_y1, latched_x1, frame_buffer[latched_y1][latched_x1]);
                    state <= OUTPUT;
                end
                OUTPUT: begin
                    frame_start <= 1'b0;
                    pixel_data <= frame_buffer[pixel_count[5:3]][pixel_count[2:0]];
                    pixel_count <= pixel_count + 1'b1;
                    if (pixel_count == 6'd63) state <= IDLE;
                end
            endcase
        end
    end

endmodule
