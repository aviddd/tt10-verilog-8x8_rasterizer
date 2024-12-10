# test_command_processor.py

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, RisingEdge


@cocotb.test()
async def test_command_processor(dut):
    """
    Test the DRAW_PIXEL command by setting pixel at (1,1).
    """
    # Start a 100 MHz clock on clk
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())

    # Initialize signals
    dut.ena.value = 1
    dut.rst_n.value = 0
    dut.ui_in.value = 0
    dut.uio_in.value = 0  # Assuming uio_in is not used in this test
    dut._log.info("Applying reset")
    
    # Hold reset for 2 clock cycles
    await ClockCycles(dut.clk, 2)
    dut.rst_n.value = 1
    dut._log.info("De-asserted reset")

    # Wait for a few cycles to allow design to settle
    await ClockCycles(dut.clk, 5)
    dut._log.info("Starting DRAW_PIXEL test at (1,1)")

    # Define a helper function to set ui_in with logging
    def set_ui_in(en, cmd, param):
        """
        Set the ui_in signal.
        en: Enable signal (1 bit)
        cmd: Command bits [6:5] (2 bits)
        param: Parameter bits [4:0] (5 bits)
        """
        value = ((en & 0x1) << 7) | ((cmd & 0x3) << 5) | (param & 0x1F)
        dut.ui_in.value = value
        dut._log.info(f"Setting ui_in to EN={en} CMD={cmd:02b} PARAM={param:05b} (0x{value:02X})")
        return value

    # Define a helper function to wait for frame_sync
    async def wait_for_frame_sync(timeout=200):
        """
        Wait until frame_sync is high or timeout is reached.
        """
        for cycle in range(timeout):
            await RisingEdge(dut.clk)
            uo_out = int(dut.uo_out.value)
            frame_sync = (uo_out >> 4) & 0x1
            if frame_sync:
                dut._log.info(f"Frame sync detected at cycle {cycle}")
                return
        dut._log.error("Frame sync not detected within timeout")
        assert False, "Frame sync not asserted in time"

    # Define a helper function to get pixel data
    def get_pixel_data():
        """
        Retrieve the pixel data from uo_out[3:0].
        """
        uo_out = int(dut.uo_out.value)
        pixel = uo_out & 0xF
        return pixel

    # Define a helper function to calculate pixel index
    def pixel_index(x, y):
        """
        Calculate pixel index based on (x, y) coordinates.
        """
        return y * 8 + x

    # Coordinates for DRAW_PIXEL
    x1, y1 = 1, 1
    expected_pixel = pixel_index(x1, y1)

    # Step 1: Send DRAW_PIXEL command with x1=1
    dut._log.info(f"Cycle 1: Sending DRAW_PIXEL command with x1={x1}")
    set_ui_in(en=1, cmd=0b01, param=x1)
    await ClockCycles(dut.clk, 1)

    # Step 2: Send y1=1 as parameter using NO_OP
    dut._log.info(f"Cycle 2: Sending y1={y1} as parameter using NO_OP")
    set_ui_in(en=1, cmd=0b00, param=y1)
    await ClockCycles(dut.clk, 2)  # Hold parameter for 2 cycles to ensure latching

    # Step 3: Clear ui_in
    dut._log.info("Cycle 4: Clearing ui_in")
    dut.ui_in.value = 0
    await ClockCycles(dut.clk, 1)

    # Step 4: Wait for frame_sync
    dut._log.info("Waiting for frame_sync signal")
    await wait_for_frame_sync()

    # Step 5: Read and log 64 pixels
    dut._log.info("Starting to read pixel data")
    pixel_values = []
    for i in range(64):
        await RisingEdge(dut.clk)
        pixel = get_pixel_data()
        pixel_values.append(pixel)
        dut._log.info(f"Pixel index {i}: {pixel}")

    # Step 6: Verify that only the expected pixel is set
    dut._log.info(f"Verifying that only pixel index {expected_pixel} is set")
    for i, val in enumerate(pixel_values):
        if i == expected_pixel:
            if val != 1:
                dut._log.error(f"DRAW_PIXEL failed: Pixel index {i} expected 1, got {val}")
            assert val == 1, f"DRAW_PIXEL failed: Pixel index {i} expected 1, got {val}"
        else:
            if val != 0:
                dut._log.error(f"DRAW_PIXEL failed: Pixel index {i} expected 0, got {val}")
            assert val == 0, f"DRAW_PIXEL failed: Pixel index {i} expected 0, got {val}"

    dut._log.info("DRAW_PIXEL test passed successfully.")
