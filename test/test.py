# test_tinygpu.py

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge, FallingEdge, Timer
from cocotb.result import TestFailure

@cocotb.test()
async def test_tinygpu(dut):
    dut._log.info("Start TinyGPU Test")

    # Set up the clock with a period of 10 ns (100 MHz)
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset the design
    dut._log.info("Applying reset")
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 5)
    dut.rst_n.value = 1

    # Wait for a few clock cycles after reset
    await ClockCycles(dut.clk, 5)

    dut._log.info("Testing DRAW_PIXEL command")

    # Define command encoding (assumed for this test)
    # Let's assume the ui_in[7:6] are the command bits
    # Commands:
    #  2'b01: DRAW_PIXEL
    #  2'b10: DRAW_LINE
    #  2'b11: FILL_RECT
    # Coordinates and dimensions are packed into ui_in[5:0]

    # For the purpose of this test, let's define:
    # For DRAW_PIXEL, ui_in[5:3] = x1, ui_in[2:0] = y1

    # Apply DRAW_PIXEL command to draw a pixel at (1, 1)
    cmd_draw_pixel = 0b01 << 6  # Command bits in ui_in[7:6]
    x1 = 1
    y1 = 1
    ui_in_value = cmd_draw_pixel | (x1 << 3) | y1
    dut.ui_in.value = ui_in_value

    # Wait for the command to be processed
    await ClockCycles(dut.clk, 1)
    dut.ui_in.value = 0  # Clear ui_in after command

    # Wait for the module to enter R_OUTPUT state and assert frame_sync
    # Monitor frame_sync signal
    frame_sync_asserted = False
    for _ in range(10):
        await RisingEdge(dut.clk)
        if dut.uo_out[4].value == 1:
            frame_sync_asserted = True
            dut._log.info("Frame sync asserted")
            break
    if not frame_sync_asserted:
        raise TestFailure("Frame sync not asserted")

    # Read the serialized pixel data
    pixel_values = []
    for i in range(64):
        await RisingEdge(dut.clk)
        pixel_data = dut.uo_out[3:0].value.integer
        pixel_values.append(pixel_data)
        dut._log.info(f"Pixel {i}: Data = {pixel_data}")

    # Check that the pixel at position (1,1) is set
    # The rasterizer outputs pixels in row-major order
    # Calculate the index of pixel (x, y)
    def pixel_index(x, y):
        return y * 8 + x

    expected_index = pixel_index(1, 1)
    for i, value in enumerate(pixel_values):
        if i == expected_index:
            if value != 1:
                raise TestFailure(f"Pixel at ({x1},{y1}) not set correctly. Expected 1, got {value}")
        else:
            if value != 0:
                raise TestFailure(f"Unexpected pixel set at index {i}. Expected 0, got {value}")

    dut._log.info("DRAW_PIXEL command test passed")

    # Now test FILL_RECT command
    dut._log.info("Testing FILL_RECT command")

    # Apply FILL_RECT command to fill a rectangle starting at (2,2) with width=3, height=3
    # For FILL_RECT, let's assume ui_in[7:6]=2'b11 (command)
    # ui_in[5:3]=x1, ui_in[2:0]=y1 in the first cycle
    # Then we send width and height in subsequent cycles

    cmd_fill_rect = 0b11 << 6
    x1 = 2
    y1 = 2
    width = 3
    height = 3

    # Send first part of command with x1 and y1
    ui_in_value = cmd_fill_rect | (x1 << 3) | y1
    dut.ui_in.value = ui_in_value
    await ClockCycles(dut.clk, 1)

    # Send width
    dut.ui_in.value = width
    await ClockCycles(dut.clk, 1)

    # Send height
    dut.ui_in.value = height
    await ClockCycles(dut.clk, 1)

    dut.ui_in.value = 0  # Clear ui_in after command

    # Wait for frame_sync
    frame_sync_asserted = False
    for _ in range(10):
        await RisingEdge(dut.clk)
        if dut.uo_out[4].value == 1:
            frame_sync_asserted = True
            dut._log.info("Frame sync asserted for FILL_RECT")
            break
    if not frame_sync_asserted:
        raise TestFailure("Frame sync not asserted for FILL_RECT command")

    # Read the serialized pixel data
    pixel_values = []
    for i in range(64):
        await RisingEdge(dut.clk)
        pixel_data = dut.uo_out[3:0].value.integer
        pixel_values.append(pixel_data)
        dut._log.info(f"Pixel {i}: Data = {pixel_data}")

    # Check that the rectangle pixels are set correctly
    for y in range(8):
        for x in range(8):
            i = pixel_index(x, y)
            expected_value = 1 if (x >= x1 and x < x1 + width and y >= y1 and y < y1 + height) else 0
            if pixel_values[i] != expected_value:
                raise TestFailure(f"Pixel at ({x},{y}) incorrect. Expected {expected_value}, got {pixel_values[i]}")

    dut._log.info("FILL_RECT command test passed")

    # Additional tests can be added similarly

    dut._log.info("All tests passed")

