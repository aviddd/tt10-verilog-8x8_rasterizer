`default_nettype none
`timescale 1ns / 1ps

/* This testbench instantiates the module and provides a minimal setup.
   For detailed testing, cocotb is used.
*/
module tb ();

  // Dump the signals to a VCD file for viewing with waveform tools.
  initial begin
    $dumpfile("tb.vcd");
    $dumpvars(0, tb);
    #1;
  end

  // Wire up the inputs and outputs:
  reg clk;
  reg rst_n;
  reg ena;
  reg [7:0] ui_in;
  reg [7:0] uio_in;
  wire [7:0] uo_out;
  wire [7:0] uio_out;
  wire [7:0] uio_oe;

`ifdef GL_TEST
  wire VPWR = 1'b1;
  wire VGND = 1'b0;
`endif

  // Instantiate your module:
  tt_um_david_tinygpu user_project (
      // Include power ports for the Gate Level test:
`ifdef GL_TEST
      .VPWR(VPWR),
      .VGND(VGND),
`endif

      .ui_in  (ui_in),    // Dedicated inputs
      .uo_out (uo_out),   // Dedicated outputs
      .uio_in (uio_in),   // IOs: Input path
      .uio_out(uio_out),  // IOs: Output path
      .uio_oe (uio_oe),   // IOs: Enable path (active high: 0=input, 1=output)
      .ena    (ena),      // enable - goes high when design is selected
      .clk    (clk),      // clock
      .rst_n  (rst_n)     // active low reset
  );

  // Clock generation
  initial clk = 0;
  always #5 clk = ~clk;  // 100 MHz clock (period = 10 ns)

  // Reset and enable signals
  initial begin
    ena = 1;
    rst_n = 0;
    ui_in = 8'b0;
    uio_in = 8'b0;
    // Wait for a few clock cycles before releasing reset
    @(posedge clk);
    @(posedge clk);
    rst_n = 1;
  end

endmodule

