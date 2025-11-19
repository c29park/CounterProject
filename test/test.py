import cocotb
from cocotb.triggers import Timer

CLK_PERIOD_NS = 40  # 25 MHz pixel clock


async def tick(dut, n=1):
    for _ in range(n):
        dut.clk.value = 0
        await Timer(CLK_PERIOD_NS // 2, unit="ns")
        dut.clk.value = 1
        await Timer(CLK_PERIOD_NS // 2, unit="ns")


async def reset_and_enable(dut):
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.clk.value = 0

    dut.rst_n.value = 0
    await tick(dut, 4)
    dut.rst_n.value = 1
    await tick(dut, 4)


@cocotb.test()
async def test_vga_ios_and_sync_startup(dut):
    await reset_and_enable(dut)

    seen_hsync_low = False
    for _ in range(1200):
        await tick(dut)
        uo_val = int(dut.uo_out.value)
        hsync_high = (uo_val >> 7) & 1
        vsync_high = (uo_val >> 3) & 1

        assert int(dut.uio_out.value) == 0, "uio_out should stay 0"
        assert int(dut.uio_oe.value) == 0, "uio_oe should stay 0"
        assert vsync_high == 1, "vsync should remain high during the first line"

        if hsync_high == 0:
            seen_hsync_low = True
            break

    assert seen_hsync_low, "hsync must go low at least once per line"


@cocotb.test()
async def test_hsync_pulse_width(dut):
    await reset_and_enable(dut)

    # wait for the start of a low HSYNC pulse
    while int(dut.uo_out.value) & (1 << 7):
        await tick(dut)

    low_cycles = 0
    while not (int(dut.uo_out.value) & (1 << 7)):
        low_cycles += 1
        await tick(dut)

    assert 90 <= low_cycles <= 102, f"hsync low time unexpected: {low_cycles} cycles"
