import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge

@cocotb.test()
async def test_command_processor(dut):
    # Set up a 100 MHz clock (10 ns period)
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset and initialize
    dut.ena.value = 1
    dut.rst_n.value = 0
    dut.ui_in.value = 0
    await ClockCycles(dut.clk, 5)
    dut.rst_n.value = 1

    # Wait extra cycles for design to settle
    await ClockCycles(dut.clk, 10)

    def set_ui_in(en, cmd, param):
        # en (bit 7), cmd (bits [6:5]), param (bits [4:0])
        return ((en & 1) << 7) | ((cmd & 0b11) << 5) | (param & 0x1F)

    async def wait_for_frame_sync(timeout=100):
        # Wait until frame_sync is high
        for _ in range(timeout):
            await RisingEdge(dut.clk)
            val_bin = dut.uo_out.value.binstr.replace('x', '0').replace('X', '0')
            val_int = int(val_bin, 2)
            # frame_sync at uo_out[4]
            if (val_int & (1 << 4)) != 0:
                return
        assert False, "Frame sync not asserted in time"

    def get_pixel_data():
        val_bin = dut.uo_out.value.binstr.replace('x', '0').replace('X', '0')
        val_int = int(val_bin, 2)
        return val_int & 0xF  # pixel_data is uo_out[3:0]

    def pixel_index(x, y):
        return y * 8 + x

    # Test DRAW_PIXEL at (1,1)
    # DRAW_PIXEL cmd = 01
    # Cycle 1: en=1, cmd=01, param=x1 in param[2:0]
    # Cycle 2: en=1, cmd=00 (NO_OP), param=y1 in param[2:0]

    x1, y1 = 1, 1

    # Send x1
    dut.ui_in.value = set_ui_in(en=1, cmd=0b01, param=(x1 & 0x07))
    await ClockCycles(dut.clk, 1)

    # Send y1 via NO_OP
    dut.ui_in.value = set_ui_in(en=1, cmd=0b00, param=(y1 & 0x07))
    await ClockCycles(dut.clk, 1)

    # Clear input
    dut.ui_in.value = 0

    # Wait for frame_sync
    await wait_for_frame_sync()

    # Wait one more cycle after frame_sync before reading pixels
    # This ensures the rasterizer has moved to R_DRAW state
    await RisingEdge(dut.clk)

    # Read all 64 pixels
    pixel_values = []
    for i in range(64):
        await RisingEdge(dut.clk)
        pixel_values.append(get_pixel_data())

    # Check that only pixel (1,1) is set
    expected_idx = pixel_index(x1, y1)
    for i, val in enumerate(pixel_values):
        if i == expected_idx:
            assert val == 1, f"DRAW_PIXEL failed: Pixel ({x1},{y1}) expected 1, got {val}"
        else:
            assert val == 0, f"DRAW_PIXEL failed: Pixel index {i} expected 0, got {val}"

    dut._log.info("DRAW_PIXEL test passed")
    dut._log.info("All tests completed successfully")
