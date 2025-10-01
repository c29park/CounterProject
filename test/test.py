import cocotb
from cocotb.triggers import RisingEdge, Timer

CLK_PERIOD_NS = 20  # 50 MHz equivalent

async def reset(dut):
    dut.rst_n.value = 0
    dut.ena.value   = 1
    dut.clk.value   = 0
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    await Timer(CLK_PERIOD_NS//2, units="ns")
    dut.rst_n.value = 1
    # give a couple cycles to settle
    for _ in range(2):
        await RisingEdge(dut.clk)

async def tick(dut, n=1):
    for _ in range(n):
        dut.clk.value = 0
        await Timer(CLK_PERIOD_NS//2, units="ns")
        dut.clk.value = 1
        await Timer(CLK_PERIOD_NS//2, units="ns")

@cocotb.test()
async def test_counter_load_count_and_tristate(dut):
    """Verify async reset, synchronous load, counting, and tri-state outputs."""
    await reset(dut)

    # After reset, counter should be 0; outputs masked when ena=1
    assert int(dut.uo_out.value) == 0, "After reset, uo_out must be 0"
    assert int(dut.uio_oe.value) == 0, "After reset, uio_oe should be 0 (tri-stated)"
    assert int(dut.uio_out.value) == 0, "After reset, uio_out forced 0 when tri-stated"

    # ---- Synchronous LOAD ----
    load_val = 0xA5
    dut.ui_in.value = load_val
    # uio_in bits: [2]=OE, [1]=CNT_EN, [0]=LOAD
    dut.uio_in.value = 0b001  # LOAD=1
    await tick(dut, 1)        # capture on rising edge
    dut.uio_in.value = 0      # deassert load
    assert int(dut.uo_out.value) == load_val, "Counter must load ui_in on LOAD"

    # ---- Counting ----
    dut.uio_in.value = 0b010  # CNT_EN=1
    await tick(dut, 5)        # count 5 cycles
    dut.uio_in.value = 0
    expected = (load_val + 5) & 0xFF
    assert int(dut.uo_out.value) == expected, "Counter must increment when CNT_EN=1"

    # ---- Tri-state behavior on uio_* ----
    # With OE=0 -> uio_oe must be 0; bus tri-stated. (Value is don't-care but forced 0 in sim)
    assert int(dut.uio_oe.value) == 0, "uio_oe must be 0 when OE=0"
    assert int(dut.uio_out.value) == 0, "uio_out is forced 0 when not enabled"

    # Enable OE and check that uio_out mirrors counter and OE is driven
    dut.uio_in.value = 0b100  # OE=1
    await tick(dut, 1)
    assert int(dut.uio_oe.value) == 0xFF, "uio_oe must enable all bits when OE=1 and ena=1"
    assert int(dut.uio_out.value) == expected, "uio_out must mirror counter when OE=1"

    # ---- Verify hold when ena=0 ----
    dut.ena.value = 0
    prev = int(dut.uo_out.value)
    dut.uio_in.value = 0b010  # try to count, but ena=0 => should hold
    await tick(dut, 3)
    assert int(dut.uo_out.value) == prev, "Counter must hold when ena=0"
    assert int(dut.uio_oe.value) == 0, "uio_oe must be 0 when ena=0"
    assert int(dut.uio_out.value) == 0, "uio_out forced 0 when ena=0"

    # Re-enable and ensure counting resumes
    dut.ena.value = 1
    dut.uio_in.value = 0b010  # CNT_EN=1
    await tick(dut, 2)
    final = (prev + 2) & 0xFF
    assert int(dut.uo_out.value) == final, "Counting should resume when ena=1"
