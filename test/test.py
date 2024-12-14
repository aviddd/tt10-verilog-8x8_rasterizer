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
    dut._log.info("Design has been reset")

    # Wait extra cycles for design to settle
    await ClockCycles(dut.clk, 10)
    dut._log.info("Starting DRAW_PIXEL test at (1,1)")

    def set_ui_in(en, cmd, param):
        val = ((en & 1) << 7) | ((cmd & 0b11) << 5) | (param & 0x1F)
        dut._log.info(f"Setting ui_in to EN={en} CMD={cmd:02b} PARAM={param:05b} (0x{val:02X})")
        return val

    async def wait_for_frame_sync(timeout=200):
        # Wait until frame_sync is high
        for i in range(timeout):
            await RisingEdge(dut.clk)
            val_bin = dut.uo_out.value.binstr.replace('x', '0').replace('X', '0')
            val_int = int(val_bin, 2)
            if (val_int & (1 << 4)) != 0:
                dut._log.info(f"Frame sync detected at cycle {i}")
                return
        raise AssertionError("Frame sync not asserted in time")

    def get_pixel_data():
        val_bin = dut.uo_out.value.binstr.replace('x', '0').replace('X', '0')
        val_int = int(val_bin, 2)
        return val_int & 0xF  # pixel_data is uo_out[3:0]

    def pixel_index(x, y):
        return y * 8 + x 

    x1, y1 = 1, 1

    # Send x1
    dut.ui_in.value = set_ui_in(en=1, cmd=0b01, param=(x1 & 0x07))
    await ClockCycles(dut.clk, 2)  # Increased cycle count for stability
    dut._log.info(f"Encoded x1 command sent: {dut.ui_in.value}")

    # Send y1 via NO_OP
    dut.ui_in.value = set_ui_in(en=1, cmd=0b00, param=(y1 & 0x07))
    await ClockCycles(dut.clk, 2)  # Increased cycle count for stability
    dut._log.info(f"Encoded y1 command sent: {dut.ui_in.value}")

    # Clear input
    dut.ui_in.value = 0
    dut._log.info("Commands sent, now waiting for frame_sync")

    # Wait for frame_sync
    await wait_for_frame_sync()

    # One more cycle after frame_sync before reading pixels
    await RisingEdge(dut.clk)

    # Read all pixel values
    pixel_values = []
    for i in range(64):
        await RisingEdge(dut.clk)
        p = get_pixel_data()
        pixel_values.append(p)
        dut._log.info(f"Pixel index {i}: {p}")

    # Check that only pixel (1,1) is set
    expected_idx = pixel_index(x1, y1)
    for i, val in enumerate(pixel_values):
        if i == expected_idx:
            assert val == 1, f"DRAW_PIXEL failed: Pixel ({x1},{y1}) expected 1, got {val}"
        else:
            assert val == 0, f"DRAW_PIXEL failed: Pixel index {i} expected 0, got {val}"

    dut._log.info("DRAW_PIXEL test passed successfully.")
