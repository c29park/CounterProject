## How it works

The design is a fully self-contained VGA renderer. A 640×480 timing block driven
by a 25&nbsp;MHz clock generates pixel coordinates as well as hsync/vsync pulses.
Each video frame, a 16-bit counter advances and six sine/cosine lookup tables
produce rotation matrices for the six planes of a tesseract (zw, yw, yz, xw, xz,
xy). For every pixel the design projects all 16 vertices through two chained
perspective stages (w and z) and checks whether that pixel falls on an edge or a
vertex. Lime pixels highlight the "w" edges, cyan pixels draw the remaining
edges, and bright white pixels mark every vertex.

## How to test

1. Provide a 25&nbsp;MHz clock on `clk` and hold `rst_n` low for a few cycles.
2. Release `rst_n`. The module continually drives `uo_out[7:0]` with the
   VGA-compatible bus `{hsync,B0,G0,R0,vsync,B1,G1,R1}`. The other pins remain
   tri-stated.
3. Connect the outputs to a VGA DAC/PMOD and view the rotating tesseract on any
   640×480 display.

You can also run `cd test && make` to simulate the design with cocotb.

## External hardware

- VGA DAC or Digilent VGA PMOD (2:2:2 RGB)
- 640×480-capable VGA monitor
