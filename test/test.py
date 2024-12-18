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

    def set_ui_in(en, cmd, param):
        val = ((en & 1) << 7) | ((cmd & 0b11) << 5) | (param & 0x1F)
        return val

    x1, y1 = 1, 1

    # Send x1
    dut.ui_in.value = set_ui_in(en=1, cmd=0b01, param=(x1 & 0x07))
    await ClockCycles(dut.clk, 4)
    dut._log.info(f"Testbench sent ui_in={dut.ui_in.value.binstr} (x1={x1})")

    # Send y1
    dut.ui_in.value = set_ui_in(en=1, cmd=0b00, param=(y1 & 0x07))
    await ClockCycles(dut.clk, 4)
    dut._log.info(f"Testbench sent ui_in={dut.ui_in.value.binstr} (y1={y1})")

    # Wait for frame_sync
    await ClockCycles(dut.clk, 20)

    pixel_values = []
    for i in range(64):
        await RisingEdge(dut.clk)
        pixel_values.append(int(dut.uo_out.value.integer) & 0xF)
        dut._log.info(f"Pixel index {i}: Pixel data={pixel_values[-1]}")

    # Assert pixel at (1,1) is set
    assert pixel_values[9] == 1, f"Pixel (1,1) not set correctly. Got {pixel_values[9]}"
    dut._log.info("Test passed.")
