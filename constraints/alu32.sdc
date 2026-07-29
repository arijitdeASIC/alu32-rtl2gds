#==============================================================================
# alu32.sdc  -  timing constraints (shared by DC synthesis and ICC2 PnR)
#
# Start with period = 2.0 ns (500 MHz). A 32-bit ALU in Nangate 45nm will
# usually close well below this; once you see large positive slack, tighten
# the period (1.5, then 1.2, then 1.0 ...) until WNS approaches ~0. The tighter
# you can close it, the stronger the number on your resume.
#==============================================================================

set CLK_PERIOD 2.0

create_clock -name clk -period $CLK_PERIOD [get_ports clk]

# Model real clock-source behaviour
set_clock_uncertainty -setup 0.10 [get_clocks clk]
set_clock_uncertainty -hold  0.05 [get_clocks clk]
set_clock_transition        0.10 [get_clocks clk]
set_clock_latency -source   0.30 [get_clocks clk]   ;# pre-CTS source latency

# I/O timing budget (40% of period each side is a sane starting point)
set in_out_ports  [remove_from_collection [all_inputs] [get_ports clk]]
set_input_delay  -clock clk [expr {0.20 * $CLK_PERIOD}] $in_out_ports
set_output_delay -clock clk [expr {0.20 * $CLK_PERIOD}] [all_outputs]

# Drive / load realism
set_driving_cell -lib_cell BUF_X1 -pin Z $in_out_ports
set_load [load_of NangateOpenCellLibrary_typical/BUF_X4/A] [all_outputs]

# Design rules
set_max_fanout    20  [current_design]
set_max_transition 0.30 [current_design]

# Reset is asynchronous - don't time it as a data path
set_false_path -from [get_ports rst_n]
