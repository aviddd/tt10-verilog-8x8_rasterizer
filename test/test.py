import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge
from cocotb.result import TestFailure

@cocotb.test()
async def test_command_processor(dut):
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut.rst_n.value = 0
    dut.ui_in.value = 0
    await ClockCycles(dut.clk, 5)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 5)

    # Helper functions
    def set_ui_in(en, cmd, param):
        # en is 0 or 1, cmd is 2 bits, param is 5 bits
        return ((en & 0x1) << 7) | ((cmd & 0x3) << 5) | (param & 0x1F)

    async def wait_for_frame_sync(timeout=20):
        for _ in range(timeout):
            await RisingEdge(dut.clk)
            if dut.frame_sync.value == 1:
                return
        raise TestFailure("Frame sync not asserted in time")

    def pixel_index(x, y):
        return y * 8 + x

    ################################################################
    # Test DRAW_PIXEL command
    # Command: 01
    # Sequence:
    # 1) en=1, cmd=01, param = x1 in param[2:0]
    # 2) en=1, cmd=00 (NO_OP), param = y1 in param[2:0]
    # After execution, frame_sync is asserted and pixel_data can be read.

    x1, y1 = 1, 1
    # First cycle for DRAW_PIXEL (x1)
    dut.ui_in.value = set_ui_in(en=1, cmd=0b01, param=(x1 & 0x07))
    await ClockCycles(dut.clk, 1)
    # Second cycle for DRAW_PIXEL (y1)
    dut.ui_in.value = set_ui_in(en=1, cmd=0b00, param=(y1 & 0x07))
    await ClockCycles(dut.clk, 1)
    dut.ui_in.value = 0

    # Wait for frame_sync
    await wait_for_frame_sync()

    # Read out pixels
    pixel_values = []
    for i in range(64):
        await RisingEdge(dut.clk)
        pixel_values.append(dut.pixel_data.value.integer)

    # Check pixel at (1,1) is set (expected=1)
    expected_idx = pixel_index(x1, y1)
    for i, val in enumerate(pixel_values):
        if i == expected_idx:
            if val != 1:
                raise TestFailure(f"DRAW_PIXEL failed: Pixel ({x1},{y1}) expected 1, got {val}")
        else:
            if val != 0:
                raise TestFailure(f"DRAW_PIXEL failed: Pixel {i} expected 0, got {val}")

    dut._log.info("DRAW_PIXEL test passed")

    ################################################################
    # Test FILL_RECT command
    # Command: 11
    # Sequence:
    # 1) en=1, cmd=11, param = x1 in param[2:0]
    # 2) en=1, cmd=00, param = y1 in param[2:0]
    # 3) en=1, cmd=00, param = width in param[2:0]
    # 4) en=1, cmd=00, param = height in param[2:0]

    x1, y1 = 2, 2
    width, height = 3, 3
    # First cycle: (x1)
    dut.ui_in.value = set_ui_in(en=1, cmd=0b11, param=(x1 & 0x07))
    await ClockCycles(dut.clk, 1)
    # Second cycle: y1
    dut.ui_in.value = set_ui_in(en=1, cmd=0b00, param=(y1 & 0x07))
    await ClockCycles(dut.clk, 1)
    # Third cycle: width
    dut.ui_in.value = set_ui_in(en=1, cmd=0b00, param=(width & 0x07))
    await ClockCycles(dut.clk, 1)
    # Fourth cycle: height
    dut.ui_in.value = set_ui_in(en=1, cmd=0b00, param=(height & 0x07))
    await ClockCycles(dut.clk, 1)
    dut.ui_in.value = 0

    # Wait for frame_sync
    await wait_for_frame_sync()

    # Read pixel data
    pixel_values = []
    for i in range(64):
        await RisingEdge(dut.clk)
        pixel_values.append(dut.pixel_data.value.integer)

    # Check the filled rectangle
    for Y in range(8):
        for X in range(8):
            idx = pixel_index(X, Y)
            expected = 1 if (X >= x1 and X < x1 + width and Y >= y1 and Y < y1 + height) else 0
            if pixel_values[idx] != expected:
                raise TestFailure(
                    f"FILL_RECT failed: Pixel ({X},{Y}) expected {expected}, got {pixel_values[idx]}"
                )

    dut._log.info("FILL_RECT test passed")

    ################################################################
    # Additional tests like DRAW_LINE or CLEAR can be added similarly.
    # For CLEAR: (cmd=01 with param=11111) would just execute without needing parameters.

    dut._log.info("All tests passed")
