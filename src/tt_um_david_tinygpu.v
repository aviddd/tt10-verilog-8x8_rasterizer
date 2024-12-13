`default_nettype none

module tt_um_david_tinygpu (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path (unused)
    output wire [7:0] uio_out,  // IOs: Output path (unused)
    output wire [7:0] uio_oe,   // IOs: Enable path (unused)
    input  wire        ena,     // always 1 when the design is powered
    input  wire        clk,     // clock
    input  wire        rst_n    // reset_n - active low reset
);

    // Signals between command_processor and rasterizer
    wire [1:0] out_cmd;
    wire [2:0] out_x1, out_y1, out_x2, out_y2, out_width, out_height;
    wire        cmd_ready;

    // Rasterizer outputs
    wire [3:0] pixel_data;
    wire        frame_sync;

    // Instantiate the Command Processor
    command_processor cmd_proc (
        .clk(clk),
        .rst_n(rst_n),
        .ui_in(ui_in),
        .out_cmd(out_cmd),
        .out_x1(out_x1),
        .out_y1(out_y1),
        .out_x2(out_x2),
        .out_y2(out_y2),
        .out_width(out_width),
        .out_height(out_height),
        .cmd_ready(cmd_ready)
    );

    // Instantiate the Rasterizer
    rasterizer raster (
        .clk(clk),
        .rst_n(rst_n),
        .out_cmd(out_cmd),
        .out_x1(out_x1),
        .out_y1(out_y1),
        .out_x2(out_x2),
        .out_y2(out_y2),
        .out_width(out_width),
        .out_height(out_height),
        .cmd_ready(cmd_ready),
        .pixel_data(pixel_data),
        .frame_sync(frame_sync)
    );

    // Map rasterizer outputs to top-level outputs
    assign uo_out[3:0] = pixel_data;
    assign uo_out[4]   = frame_sync;
    assign uo_out[7:5] = 3'b000;  // Unused outputs

    // Unused IOs
    assign uio_out = 8'b00000000;
    assign uio_oe  = 8'b00000000;

    // Tie off unused inputs to avoid warnings
    wire _unused = &{ena, uio_in};

endmodule
