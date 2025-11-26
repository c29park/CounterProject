## How it works

`tt_um_vga_example` drives a TinyVGA PMOD pinout with a 640x480@60Hz timing core and a small pixel shader. An internal `hvsync_generator` builds the horizontal/vertical counters and sync pulses. The main module computes radial metrics around screen center to shade a black-hole-inspired scene: a dark event horizon, a textured accretion belt with animated gaps, and a lensed halo. A 16-bit frame counter advances the textures and also moves a simple "UW" text sprite that pauses and then falls across frames. Color channels are packed into `uo_out` as `{hsync, B0, G0, R0, vsync, B1, G1, R1}` where each color uses 2 bits.

## How to test

1. Run the cocotb testbench to exercise the VGA timing generator and frame counter: `make -C test`. The test checks HSYNC/VSYNC polarity, porch durations, and full-frame counter wrap.
2. To view the animation on hardware, provide a 25 MHz clock on `clk`, hold `rst_n` high, and route `uo_out` to a TinyVGA PMOD or R-2R DAC: `uo[7]=HSYNC`, `uo[3]=VSYNC`, and pairs `R{1,0}`, `G{1,0}`, `B{1,0}` for color depth.

## External hardware

- VGA display connected through a TinyVGA PMOD-style connector or discrete resistor ladder DAC wired to the `uo` pins.
