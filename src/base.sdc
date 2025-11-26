# Timing constraints for tt_um_vga_example
# Defines the primary clock on clk and simple IO delays.

set_units -time ns

# Clock definition (25 MHz => 40 ns period). The flow's CLOCK_PERIOD may
# override this value; use the environment variable when available.
set clk_period 40
if {[info exists ::env(CLOCK_PERIOD)]} {
  set clk_period $::env(CLOCK_PERIOD)
}
create_clock -name clk -period $clk_period [get_ports clk]

# Treat the active-low reset as asynchronous to the core clock.
set_false_path -from [get_ports rst_n]

# Basic IO delays referenced to clk. Limit the lists to existing ports to
# avoid empty get_ports expressions during STA.
set in_ports  [list rst_n ena ui_in\[*\] uio_in\[*\]]
set out_ports [list uo_out\[*\] uio_out\[*\] uio_oe\[*\]]

set_input_delay 0 -clock clk $in_ports
set_output_delay 0 -clock clk $out_ports

# Simple drive/load modeling for sanity during synthesis/STA.
set_driving_cell -lib_cell sky130_fd_sc_hd__inv_2 $in_ports
set_load 0.1 [get_ports $out_ports]
