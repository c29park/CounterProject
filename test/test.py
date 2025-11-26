import cocotb
from cocotb.triggers import Timer

CLK_PERIOD_NS = 40  # 25 MHz pixel clock
H_TOTAL = 800
V_TOTAL = 525
V_DISPLAY = 480
H_DISPLAY = 640
H_FRONT_PORCH = 16
H_SYNC = 96
H_BACK_PORCH = 48
V_FRONT_PORCH = 10
V_SYNC = 2


async def tick(dut, n=1, *, log=False, label=""):
    for i in range(n):
        dut.clk.value = 0
        await Timer(CLK_PERIOD_NS // 2, unit="ns")
        dut.clk.value = 1
        await Timer(CLK_PERIOD_NS // 2, unit="ns")
        if log:
            cocotb.log.info(
                f"{label} cycle {i+1}: rst_n={int(dut.rst_n.value)} clk={int(dut.clk.value)} "
                f"hsync={int(dut.uo_out.value[7])} vsync={int(dut.uo_out.value[3])} "
                f"hpos={int(dut.user_project.hvsync_gen.hpos.value)} vpos={int(dut.user_project.hvsync_gen.vpos.value)}"
            )


clock_ticks = tick


async def reset_and_enable(dut):
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.clk.value = 0
    dut.rst_n.value = 0
    await tick(dut, 2)
    dut.rst_n.value = 1
    await tick(dut, 2)


@cocotb.test()
async def test_vga_timing(dut):
    cocotb.log.info("=== BEGIN VGA TIMING TEST ===")
    await reset_and_enable(dut)

    hpos = dut.user_project.hvsync_gen.hpos
    vpos = dut.user_project.hvsync_gen.vpos
    display_on = dut.user_project.hvsync_gen.display_on

    assert int(hpos.value) == 0, "hpos should start at 0 after reset"
    assert int(vpos.value) == 0, "vpos should start at 0 after reset"
    assert int(display_on.value) == 1, "Display should be active at (0,0)"
    assert int(dut.uio_out.value) == 0, "uio_out should stay 0"
    assert int(dut.uio_oe.value) == 0, "uio_oe should stay 0"

    await tick(dut, H_DISPLAY)
    assert int(display_on.value) == 0, "Display should go inactive during front porch"
    await tick(dut, H_FRONT_PORCH)
    assert int(dut.user_project.hsync.value) == 0, "HSYNC should assert low during sync pulse"
    await tick(dut, H_SYNC)
    assert int(dut.user_project.hsync.value) == 1, "HSYNC should deassert after sync pulse"
    await tick(dut, H_BACK_PORCH)
    assert int(hpos.value) == 0 and int(vpos.value) == 1, "New line should increment vpos and reset hpos"

    # Advance to the start of VSYNC (line 490)
    lines_to_vsync = (V_DISPLAY + V_FRONT_PORCH) - int(vpos.value)
    await tick(dut, lines_to_vsync * H_TOTAL)
    assert int(vpos.value) == V_DISPLAY + V_FRONT_PORCH, "vpos should reach the VSYNC line"
    assert int(dut.user_project.vsync.value) == 0, "VSYNC should assert low during vertical sync"

    await tick(dut, V_SYNC * H_TOTAL)
    assert int(dut.user_project.vsync.value) == 1, "VSYNC should deassert after pulse"
    assert int(vpos.value) == V_DISPLAY + V_FRONT_PORCH + V_SYNC, "vpos should advance past VSYNC window"

    # Complete the frame and ensure counters wrap
    remaining_lines = V_TOTAL - int(vpos.value)
    await tick(dut, remaining_lines * H_TOTAL)
    assert int(hpos.value) == 0 and int(vpos.value) == 0, "Positions should wrap at end of frame"

    cocotb.log.info("=== END VGA TIMING TEST (PASS) ===")
