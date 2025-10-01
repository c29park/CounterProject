import cocotb
from cocotb.triggers import Timer

CLK_PERIOD_NS = 20  # 50 MHz

async def tick(dut, label="", n=1):
    for i in range(n):
        dut.clk.value = 0
        await Timer(CLK_PERIOD_NS // 2, units="ns")
        dut.clk.value = 1
        await Timer(CLK_PERIOD_NS // 2, units="ns")
        cocotb.log.info(
            f"{label} cycle {i+1}: rst_n={int(dut.rst_n.value)} ena={int(dut.ena.value)} "
            f"ui_in=0x{int(dut.ui_in.value):02X} uio_in=0b{int(dut.uio_in.value):08b} "
            f"uo_out=0x{int(dut.uo_out.value):02X} uio_out=0x{int(dut.uio_out.value):02X} "
            f"uio_oe=0x{int(dut.uio_oe.value):02X}"
        )

async def reset_and_enable(dut):
    # Safe defaults first, then assert reset for 2 full cycles
    dut.ena.value    = 1
    dut.ui_in.value  = 0
    dut.uio_in.value = 0
    dut.clk.value    = 0
    dut.rst_n.value  = 0
    await tick(dut, "RESET", 2)

    # Release reset and wait 2 more cycles before sampling
    dut.rst_n.value  = 1
    await tick(dut, "POST-RESET", 2)

@cocotb.test()
async def test_counter_core_behaviors(dut):
    cocotb.log.info("=== BEGIN TEST ===")
    await reset_and_enable(dut)

    # After reset (ena=1), outputs should be zeroed and tri-stated
    assert int(dut.uo_out.value) == 0, "uo_out should be 0 after reset"
    assert int(dut.uio_oe.value) == 0, "uio_oe should be 0 (tri-stated) after reset"
    assert int(dut.uio_out.value) == 0, "uio_out forced to 0 when not enabled"

    # ---------- Synchronous LOAD ----------
    load_val = 0x5A
    dut.ui_in.value  = load_val
    dut.uio_in.value = 0b001  # LOAD=1 (uio_in[0])
    cocotb.log.info("Applying LOAD=1 with ui_in=0x5A")
    await tick(dut, "LOAD", 1)  # capture on rising edge
    dut.uio_in.value = 0
    await tick(dut, "LOAD-DEASSERT", 1)
    assert int(dut.uo_out.value) == load_val, "LOAD should copy ui_in into counter"

    # ---------- Counting ----------
    dut.uio_in.value = 0b010  # CNT_EN=1 (uio_in[1])
    cocotb.log.info("Applying CNT_EN=1 for 7 cycles")
    await tick(dut, "COUNT", 7)
    dut.uio_in.value = 0
    expected = (load_val + 7) & 0xFF
    cocotb.log.info(f"Expecting uo_out == 0x{expected:02X}")
    assert int(dut.uo_out.value) == expected, "Counter should increment while CNT_EN=1"

    # ---------- Tri-state bus ----------
    cocotb.log.info("Checking tri-state bus with OE=0")
    assert int(dut.uio_oe.value) == 0,  "uio_oe must be 0 when OE=0"
    assert int(dut.uio_out.value) == 0, "uio_out forced 0 when OE=0"

    dut.uio_in.value = 0b100  # OE=1
    cocotb.log.info("Enabling OE=1 to mirror on uio_out")
    await tick(dut, "OE-ON", 1)
    assert int(dut.uio_oe.value) == 0xFF, "uio_oe should enable all bits when OE=1"
    assert int(dut.uio_out.value) == expected, "uio_out should mirror counter when OE=1"

    # ---------- Disable fabric (ena=0): hold & tri-state ----------
    dut.ena.value = 0
    prev = int(dut.uo_out.value)
    dut.uio_in.value = 0b010
    cocotb.log.info("Disabling ena=0; trying to count for 3 cycles (should hold)")
    await tick(dut, "ENA=0", 3)
    assert int(dut.uo_out.value) == prev, "Counter must hold when ena=0"
    assert int(dut.uio_oe.value) == 0, "uio_oe must be 0 when ena=0"
    assert int(dut.uio_out.value) == 0, "uio_out forced 0 when ena=0"

    # Re-enable and ensure counting resumes
    dut.ena.value = 1
    dut.uio_in.value = 0b010
    cocotb.log.info("Re-enabling ena=1; count 2 more")
    await tick(dut, "RESUME", 2)
    dut.uio_in.value = 0
    assert int(dut.uo_out.value) == ((prev + 2) & 0xFF), "Counting should resume when ena=1"

    cocotb.log.info("=== END TEST (PASS) ===")
