## How it works

This project is a simplified pixel-drawing engine for an internal 8x8 pixel grid. It stores pixel states in a small frame buffer. By sending commands and coordinates through the input pins, you instruct the engine to set specific pixels “on” in the grid.

**Example:**
- You send a command indicating: "Draw pixel at (x=3, y=5)."
- Internally, the project updates the frame buffer, marking the pixel at that position as on.
- The project then continuously outputs the pixel data in a serialized form, along with a `frame_sync` signal. Using `frame_sync`, you know when the data stream has restarted from the top-left pixel of the 8x8 image.
- By capturing and interpreting this output data, you can reconstruct the entire 8x8 image and confirm that the requested pixel is indeed lit.

## How to test

**Simulation (No External Hardware):**
1. Use a Verilog simulator (like Icarus Verilog or Verilator) and the provided testbench.
2. Apply a "draw pixel" command at various coordinates as test inputs.
3. Check the output waveforms. Observe when `frame_sync` triggers and verify that the correct pixel bit is set in the serialized output data at the expected time.

**On Real Hardware (Logic Analyzer):**
1. Power the chip, provide a clock signal if required.
2. Apply a “draw pixel” command through the input pins.
3. Connect a logic analyzer to the `pixel_data` and `frame_sync` outputs.
4. After issuing the command, monitor the data. Once `frame_sync` goes high, the following bits of `pixel_data` will represent the frame’s pixels starting from the top-left corner.
5. Confirm that the pixel at (3,5) is represented by a “1” at the appropriate time in the sequence.

**Reconstructing the Frame:**
- By capturing 64 bits of pixel data between two `frame_sync` pulses, you can map each bit back to its (x,y) coordinate and verify the image in memory.

## External hardware

- **Optional**: No dedicated external hardware is strictly necessary if you use simulation or a logic analyzer. The outputs can be interpreted directly to verify functionality.
- **Microcontroller or FPGA Board (for a Visual Display)**:  
  Connect `pixel_data` and `frame_sync` lines to a small microcontroller or FPGA. Write code to:
  1. Sample `pixel_data` each cycle.
  2. Use `frame_sync` to know when the frame restarts.
  3. Rebuild the 8x8 image in RAM.
  4. Drive an external 8x8 LED matrix or a small LCD based on the reconstructed image.  
   
**Example Setup:**
- Attach a microcontroller (e.g., Arduino) to the outputs.
- Write firmware to read the serialized `pixel_data` after `frame_sync`.
- Light up corresponding LEDs on an 8x8 LED array to show which pixels are on.
- Issue different "draw pixel" commands and watch the LED array update, confirming the TinyGPU’s correct operation.
