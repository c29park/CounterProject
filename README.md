![](../../workflows/gds/badge.svg) ![](../../workflows/docs/badge.svg) ![](../../workflows/test/badge.svg) ![](../../workflows/fpga/badge.svg)

# tt_um_vga_example — VGA Black Hole Demo

This Tiny Tapeout project renders a stylized black-hole scene to a VGA display. The `tt_um_vga_example` top module generates 640x480@60Hz sync pulses, shades an animated halo and accretion belt, and drops a simple "UW" text sprite across the frame. All color bits and syncs are packed onto the `uo` bus for a TinyVGA PMOD connection.

- **Top module:** `tt_um_vga_example`
- **Clock:** 25 MHz pixel clock on `clk`
- **Reset:** Active-low `rst_n`
- **Outputs (uo):** `{hsync, B0, G0, R0, vsync, B1, G1, R1}` (2 bits per color channel)

## How it works

See [docs/info.md](docs/info.md) for the animated scene overview and hardware hookup notes.

## How to test

- Run the simulation testbench: `make -C test`. The cocotb test steps through HSYNC/VSYNC porch timing and frame wrap logic.
- Map `uo` to a TinyVGA PMOD or resistor ladder DAC to view the animation on a VGA display. Unused `ui`/`uio` pins can be left floating.

## Resources

- [Tiny Tapeout documentation](https://tinytapeout.com)
- [Local hardening guide](https://www.tinytapeout.com/guides/local-hardening/)
