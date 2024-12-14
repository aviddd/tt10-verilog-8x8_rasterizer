`default_nettype none

module command_processor (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [7:0] ui_in,
    output reg  [1:0] out_cmd,
    output reg  [2:0] out_x1, out_y1, out_x2, out_y2, out_width, out_height,
    output reg        cmd_ready
);

    // Input decoding
    wire        en;
    wire [1:0] cmd;
    wire [4:0] param;

    assign en   = ui_in[7];
    assign cmd   = ui_in[6:5];
    assign param = ui_in[4:0];

    // State Machine States
    localparam IDLE        = 3'd0;
    localparam LOAD_PARAM = 3'd1;
    localparam EXECUTE    = 3'd2;
    localparam WAIT        = 3'd3; 

    reg [2:0] state;
    reg [1:0] current_cmd;
    reg [2:0] x1, y1, x2, y2, width, height;
    reg [2:0] param_count;

    // Dedicated signal for CLEAR command
    wire clear_cmd = (en && cmd == 2'b01 && param == 5'b11111); 

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            current_cmd <= 2'b00;
            param_count <= 3'd0;
            x1 <= 3'd0; y1 <= 3'd0;
            x2 <= 3'd0; y2 <= 3'd0;
            width <= 3'd0; height <= 3'd0;
            out_cmd <= 2'b00;
            out_x1 <= 3'd0; out_y1 <= 3'd0; out_x2 <= 3'd0; out_y2 <= 3'd0; 
            out_width <= 3'd0; out_height <= 3'd0;
            cmd_ready <= 1'b0;
        end else begin
            cmd_ready <= 1'b0; 

            case (state)
                IDLE: begin
                    if (en) begin
                        current_cmd <= cmd;
                        param_count <= 3'd0;
                        case (cmd)
                            2'b01: begin // DRAW_PIXEL or CLEAR
                                if (clear_cmd) begin
                                    state <= EXECUTE; // Directly execute CLEAR
                                end else begin
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
                                current_cmd <= 2'b00;
                            end
                        endcase
                    end else begin
                        current_cmd <= 2'b00;
                    end
                end

                LOAD_PARAM: begin
                    if (en && cmd == 2'b00) begin 
                        case (current_cmd)
                            2'b01: begin
                                if (param_count == 3'd0) begin
                                    y1 <= param[2:0];
                                    state <= EXECUTE;
                                end
                                param_count <= param_count + 3'd1; 
                            end
                            2'b10: begin 
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
                        state <= IDLE; 
                        current_cmd <= 2'b00;
                    end
                end

                EXECUTE: begin
                    out_cmd <= current_cmd;
                    // For CLEAR command, x1 and y1 are already 3'd7
                    out_x1 <= x1; out_y1 <= y1; 
                    out_x2 <= x2; out_y2 <= y2; 
                    out_width <= width; out_height <= height;
                    state <= WAIT;
                end

                WAIT: begin
                    cmd_ready <= 1'b1;
                    state <= IDLE;
                    current_cmd <= 2'b00; 
                end
            endcase
        end
    end

endmodule
