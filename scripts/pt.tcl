#==============================================================================
# pt.tcl  -  PrimeTime signoff STA: the numbers that go on your resume
#
#     pt_shell -f sta/scripts/pt.tcl | tee sta/reports/pt_run.log
#
# This reads the ROUTED netlist + extracted SPEF (real parasitics), so the
# WNS / TNS / skew here are signoff-quality - far more credible than the
# pre-route estimates from DC or mid-flow ICC2.
#==============================================================================

#----- 1. Library -----
set LIB_ROOT "/home/tools/libraries/lib"
set link_path "* \
    $LIB_ROOT/stdcell_rvt/db_ccs/saed32rvt_dlvl_ss0p75v125c_i0p95v.db \
    $LIB_ROOT/stdcell_hvt/db_ccs/saed32hvt_dlvl_ss0p75v125c_i0p95v.db \
    $LIB_ROOT/stdcell_lvt/db_ccs/saed32lvt_dlvl_ss0p75v125c_i0p95v.db"

#----- 2. Design + parasitics -----
read_verilog ./pnr/output/alu32_routed.v
current_design alu32
link_design

read_sdc        ./syn/netlist/alu32.sdc
read_parasitics ./pnr/output/alu32.spef

#----- 3. Analysis setup -----
set_propagated_clock [all_clocks]
update_timing -full

#----- 4. Setup / hold reports -----
report_timing -delay_type max -max_paths 20 -nworst 5 \
    > ./sta/reports/setup_paths.rpt
report_timing -delay_type min -max_paths 20 -nworst 5 \
    > ./sta/reports/hold_paths.rpt

#----- 5. The headline metrics (capture these) -----
report_global_timing            > ./sta/reports/global_timing.rpt
report_qor                      > ./sta/reports/qor.rpt
report_clock_timing -type skew  > ./sta/reports/skew.rpt
report_constraint -all_violators -max_delay -min_delay \
    > ./sta/reports/violators.rpt

#----- 6. Print WNS / TNS to the console so you see them immediately -----
set wns [get_attribute [get_timing_paths -delay_type max] slack]
puts "------------------------------------------------------------"
puts "  SETUP WNS (worst slack) : $wns ns"
puts "  Full breakdown in sta/reports/global_timing.rpt and qor.rpt"
puts "  (TNS and endpoint counts are in qor.rpt / global_timing.rpt)"
puts "------------------------------------------------------------"

exit
