import cocotb
from cocotb.triggers import Timer

CLK_PERIOD_NS = 20  # 50 MHz

async def clock_ticks(dut, n=1):
    for _ in range(n):
        dut.clk.value = 0
        await Timer(CLK_PERIOD_NS // 2, units="ns")
        dut.clk.value = 1
        await Timer(CLK_PERIOD_NS // 2, units="ns")

async def reset_and_enable(dut):
    # Drive safe defaults first
    dut.ena.value    = 1
    dut.ui_in.value  = 0
    dut.uio_in.value = 0
    dut.clk.value    = 0

    # Assert async reset for *two full cycles*
    dut.rst_n.value  = 0
    await clock_ticks(dut, 2)

    # Release reset, then wait two more cycles before sampling
    dut.rst_n.value  = 1
    await clock_ticks(dut, 2)

@cocotb.test()
async def test_counter_core_behaviors(dut):
    await reset_and_enable(dut)

    # After reset (ena=1), outputs should be zeroed and tri-stated
    assert int(dut.uo_out.value) == 0, "uo_out should be 0 after reset"
    assert int(dut.uio_oe.value) == 0, "uio_oe should be 0 (tri-stated) after reset"
    assert int(dut.uio_out.value) == 0, "uio_out forced to 0 when not enabled"

    # ---------- Synchronous LOAD ----------
    load_val = 0x5A
    dut.ui_in.value  = load_val
    dut.uio_in.value = 0b001  # LOAD=1 (uio_in[0])
    await clock_ticks(dut, 1) # capture on rising edge
    dut.uio_in.value = 0
    assert int(dut.uo_out.value) == load_val, "LOAD should copy ui_in into counter"

    # ---------- Counting ----------
    dut.uio_in.value = 0b010  # CNT_EN=1 (uio_in[1])
    await clock_ticks(dut, 7)
    dut.uio_in.value = 0
    expected = (load_val + 7) & 0xFF
    assert int(dut.uo_out.value) == expected, "Counter should increment while CNT_EN=1"

    # ---------- Tri-state bus ----------
    assert int(dut.uio_oe.value) == 0,  "uio_oe must be 0 when OE=0"
    assert int(dut.uio_out.value) == 0, "uio_out forced 0 when OE=0"

    dut.uio_in.value = 0b100  # OE=1 (uio_in[2])
    await clock_ticks(dut, 1)
    assert int(dut.uio_oe.value) == 0xFF, "uio_oe should enable all bits when OE=1"
    assert int(dut.uio_out.value) == expected, "uio_out should mirror counter when OE=1"

    # ---------- Disable fabric (ena=0): hold & tri-state ----------
    dut.ena.value    = 0
    prev = int(dut.uo_out.value)
    dut.uio_in.value = 0b010  # try to count; should not change
    await clock_ticks(dut, 3)
    assert int(dut.uo_out.value) == prev, "Counter must hold when ena=0"
    assert int(dut.uio_oe.value) == 0, "uio_oe must be 0 when ena=0"
    assert int(dut.uio_out.value) == 0, "uio_out forced 0 when ena=0"

    # Re-enable and ensure counting resumes
    dut.ena.value    = 1
    dut.uio_in.value = 0b010  # CNT_EN=1
    await clock_ticks(dut, 2)
    dut.uio_in.value = 0
    assert int(dut.uo_out.value) == ((prev + 2) & 0xFF), "Counting should resume when ena=1"
