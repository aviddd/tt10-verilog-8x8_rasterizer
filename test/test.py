import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge

@cocotb.test()
async def test_command_processor(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset and enable
    dut.ena.value = 1
    dut.rst_n.value = 0
    dut.ui_in.value = 0
    await ClockCycles(dut.clk, 5)
    dut.rst_n.value = 1
    await ClockCycles(dut.clk, 10)  # Wait extra for stable signals

    def set_ui_in(en, cmd, param):
        return ((en & 1) << 7) | ((cmd & 0b11) << 5) | (param & 0x1F)

    async def wait_for_frame_sync(timeout=100):
        for _ in range(timeout):
            await RisingEdge(dut.clk)
            val = dut.uo_out.value
            # Resolve 'x' by replacing them with '0'
            val_bin = val.binstr.replace('x', '0').replace('X', '0')
            val_int = int(val_bin, 2)
            # frame_sync is at bit 4 of uo_out
            if (val_int & (1 << 4)) != 0:
                return
        assert False, "Frame sync not asserted in time"

    def get_pixel_data():
        val = dut.uo_out.value
        val_bin = val.binstr.replace('x', '0').replace('X', '0')
        val_int = int(val_bin, 2)
        return val_int & 0xF  # pixel_data in uo_out[3:0]

    def pixel_index(x, y):
        return y * 8 + x

    # CLEAR the framebuffer first
    # CLEAR command: cmd=01 and param=5'b11111 (param=31 decimal)
    dut.ui_in.value = set_ui_in(en=1, cmd=0b01, param=0b11111)
    await ClockCycles(dut.clk, 1)
    dut.ui_in.value = 0
    await wait_for_frame_sync()

    # Read pixels after CLEAR to ensure all are zero
    pixel_values = []
    for i in range(64):
        await RisingEdge(dut.clk)
        pixel_values.append(get_pixel_data())

    for i, val in enumerate(pixel_values):
        assert val == 0, f"After CLEAR, pixel {i} is not zero."

    # Now test DRAW_PIXEL at (1,1)
    x1, y1 = 1, 1
    # Send x1: cmd=01, param = x1 in param[2:0]
    dut.ui_in.value = set_ui_in(en=1, cmd=0b01, param=(x1 & 0x07))
    await ClockCycles(dut.clk, 1)

    # Send y1 via NO_OP: cmd=00
    dut.ui_in.value = set_ui_in(en=1, cmd=0b00, param=(y1 & 0x07))
    await ClockCycles(dut.clk, 1)
    dut.ui_in.value = 0

    await wait_for_frame_sync()

    # Read pixels and check only (1,1) is set
    pixel_values = []
    for i in range(64):
        await RisingEdge(dut.clk)
        pixel_values.append(get_pixel_data())

    expected_idx = pixel_index(x1, y1)
    for i, val in enumerate(pixel_values):
        if i == expected_idx:
            assert val == 1, f"DRAW_PIXEL failed: Pixel ({x1},{y1}) expected 1, got {val}"
        else:
            assert val == 0, f"DRAW_PIXEL failed: Pixel index {i} expected 0, got {val}"

    dut._log.info("DRAW_PIXEL test passed with CLEAR initialization")
