`default_nettype none

module tt_um_david_tinygpu (
    input  wire [7:0] ui_in,
    output wire [7:0] uo_out,
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire ena,
    input  wire clk,
    input  wire rst_n
);

    // Internal signals
    wire [1:0] command;
    wire [2:0] x1, y1;
    wire command_valid;
    wire [3:0] pixel_data;
    wire frame_start;

    // Command decoder
    command_decoder cmd_dec (
        .ui_in(ui_in),
        .clk(clk),
        .rst_n(rst_n),
        .command(command),
        .x1(x1),
        .y1(y1),
        .command_valid(command_valid)
    );

    // Graphics processor
    graphics_processor gpu (
        .clk(clk),
        .rst_n(rst_n),
        .command(command),
        .x1(x1),
        .y1(y1),
        .command_valid(command_valid),
        .pixel_data(pixel_data),
        .frame_start(frame_start)
    );

    // Output assignment
    assign uo_out = {3'b000, frame_start, pixel_data};

    // Unused I/Os
    assign uio_out = 8'b00000000;
    assign uio_oe = 8'b00000000;

endmodule
