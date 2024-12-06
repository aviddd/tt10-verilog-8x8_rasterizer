@cocotb.test()
async def test_tinygpu(dut):
    dut._log.info("Start TinyGPU Test")

    # Set up the clock with a period of 10 ns (100 MHz)
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset the design
    dut._log.info("Applying reset")
    dut.ui_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 5)
    dut.rst_n.value = 1

    # Wait for a few clock cycles after reset
    await ClockCycles(dut.clk, 5)

    dut._log.info("Testing DRAW_PIXEL command")

    # Encode the DRAW_PIXEL command:
    # en=1, cmd=01 (DRAW_PIXEL), param includes x1,y1
    # Assuming param = x1y1 as x1 in ui_in[4:3] and y1 in ui_in[2:0] (as per comments)
    # If that's not strictly correct, adjust accordingly based on actual param packing.
    en_bit = 1 << 7
    cmd_draw_pixel = (0b01 << 5)  # ui_in[6:5] = 01
    x1 = 1
    y1 = 1
    ui_in_value = en_bit | cmd_draw_pixel | (x1 << 3) | y1
    dut.ui_in.value = ui_in_value

    # Wait a clock cycle for the command to be latched
    await ClockCycles(dut.clk, 1)
    dut.ui_in.value = 0  # Clear after issuing command

    # Wait for frame_sync to be asserted
    frame_sync_asserted = False
    for _ in range(10):
        await RisingEdge(dut.clk)
        if dut.frame_sync.value == 1:
            frame_sync_asserted = True
            dut._log.info("Frame sync asserted")
            break

    if not frame_sync_asserted:
        raise TestFailure("Frame sync not asserted")

    # Read the serialized pixel data
    pixel_values = []
    for i in range(64):
        await RisingEdge(dut.clk)
        pixel_data = dut.pixel_data.value.integer
        pixel_values.append(pixel_data)
        dut._log.info(f"Pixel {i}: Data = {pixel_data}")

    # Check that the pixel at position (1,1) is set
    def pixel_index(x, y):
        return y * 8 + x

    expected_index = pixel_index(x1, y1)
    for i, value in enumerate(pixel_values):
        if i == expected_index:
            if value != 1:
                raise TestFailure(f"Pixel at ({x1},{y1}) not set correctly. Expected 1, got {value}")
        else:
            if value != 0:
                raise TestFailure(f"Unexpected pixel set at index {i}. Expected 0, got {value}")

    dut._log.info("DRAW_PIXEL command test passed")

    # Test FILL_RECT command
    dut._log.info("Testing FILL_RECT command")

    # For FILL_RECT: en=1, cmd=11, ui_in[6:5]=11
    # First cycle: x1, y1
    en_bit = 1 << 7
    cmd_fill_rect = (0b11 << 5)  # ui_in[6:5] = 11
    x1 = 2
    y1 = 2
    width = 3
    height = 3

    # Send first cycle with command and (x1,y1)
    ui_in_value = en_bit | cmd_fill_rect | (x1 << 3) | y1
    dut.ui_in.value = ui_in_value
    await ClockCycles(dut.clk, 1)

    # According to the code, subsequent parameters must be sent with NO_OP cmd (ui_in[6:5]=00, en=1)
    # Width parameter
    ui_in_value = en_bit | (width & 0x1F)  # no_op cmd=00, just param
    dut.ui_in.value = ui_in_value
    await ClockCycles(dut.clk, 1)

    # Height parameter
    ui_in_value = en_bit | (height & 0x1F)
    dut.ui_in.value = ui_in_value
    await ClockCycles(dut.clk, 1)

    # Clear input after sending parameters
    dut.ui_in.value = 0

    # Wait for frame_sync
    frame_sync_asserted = False
    for _ in range(10):
        await RisingEdge(dut.clk)
        if dut.frame_sync.value == 1:
            frame_sync_asserted = True
            dut._log.info("Frame sync asserted for FILL_RECT")
            break
    if not frame_sync_asserted:
        raise TestFailure("Frame sync not asserted for FILL_RECT command")

    # Read the serialized pixel data
    pixel_values = []
    for i in range(64):
        await RisingEdge(dut.clk)
        pixel_data = dut.pixel_data.value.integer
        pixel_values.append(pixel_data)
        dut._log.info(f"Pixel {i}: Data = {pixel_data}")

    # Check the filled rectangle
    for Y in range(8):
        for X in range(8):
            i = pixel_index(X, Y)
            expected_value = 1 if (X >= x1 and X < x1 + width and Y >= y1 and Y < y1 + height) else 0
            if pixel_values[i] != expected_value:
                raise TestFailure(f"Pixel at ({X},{Y}) incorrect. Expected {expected_value}, got {pixel_values[i]}")

    dut._log.info("FILL_RECT command test passed")
    dut._log.info("All tests passed")
