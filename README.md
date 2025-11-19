![](../../workflows/gds/badge.svg) ![](../../workflows/docs/badge.svg) ![](../../workflows/test/badge.svg) ![](../../workflows/fpga/badge.svg)

# VGA Tesseract Demo

This project repurposes the Tiny Tapeout template into a 25&nbsp;MHz VGA demo that
projects a spinning 4D hypercube (tesseract). The design synthesizes a full VGA
sync generator, projects all 16 vertices of the tesseract every pixel, and draws
cyan edges with lime 4D struts plus white corner dots.

- `uo_out[7:0]` expose `{hsync,B0,G0,R0,vsync,B1,G1,R1}` for a standard VGA PMOD
  style 2:2:2 RGB interface.
- `ui_in[7:0]`, `uio_in[7:0]`, and the enable pin are unused; they are tied off
  internally so the ASIC happily renders whenever `clk` is running.

## How it works

1. A 640×480@60&nbsp;Hz timing generator produces hsync/vsync pulses and pixel
   coordinates from a 25&nbsp;MHz clock.
2. A frame counter advances once per vsync rising edge and feeds six independent
   sine/cosine lookup tables so each 4D rotation plane can spin at its own speed
   and phase.
3. Every pixel evaluates the projected position of all 16 vertices, performs a
   pair of perspective divides, and checks whether the active pixel lies on any
   of the hypercube edges or vertices.
4. During active video the RGB outputs update with the color-coding rules
   (vertices → white, w-edges → lime, other edges → cyan); blanking intervals
   force the outputs to black.

## Simulating

The included cocotb testbench drives the design with a 25&nbsp;MHz clock and
asserts reset before letting the VGA pipeline run. To reproduce the automated
checks locally:

```bash
cd test
make
```

The test ensures that hsync pulses appear, vsync stays high during the first
frame, and the bidirectional IOs remain tri-stated.

## Hardware setup

To view the animation, connect the outputs to a 640×480-compatible VGA DAC or a
VGA PMOD (e.g. Digilent) and supply a clean 25&nbsp;MHz clock. Only the `uo_out`
pins are required; all other Tiny Tapeout pins can be left unconnected.

For more Tiny Tapeout documentation visit https://tinytapeout.com.
