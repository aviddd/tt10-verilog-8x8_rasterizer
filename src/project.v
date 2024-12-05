/*
 * TinyGPU Top Module
 * Author: Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_tinygpu (
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
