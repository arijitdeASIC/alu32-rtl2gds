#==============================================================================
# dc.tcl  -  Design Compiler synthesis   [SAED32]
#     dc_shell -f syn/scripts/dc.tcl | tee syn/reports/dc_run.log
#==============================================================================

#----- 1. Library setup (SAED32, ss slow corner = worst-case setup) -----
set LIB_ROOT "/home/tools/libraries/lib"

# CCS timing models (db_ccs) - higher accuracy than NLDM, same DC flow.
# Multi-Vt: RVT primary + HVT/LVT so DC can trade speed vs leakage.
# >>> If HVT/LVT dir names differ, paste ls output in chat to confirm. <<<
set target_library [list \
    $LIB_ROOT/stdcell_rvt/db_ccs/saed32rvt_dlvl_ss0p75v125c_i0p95v.db \
    $LIB_ROOT/stdcell_hvt/db_ccs/saed32hvt_dlvl_ss0p75v125c_i0p95v.db \
    $LIB_ROOT/stdcell_lvt/db_ccs/saed32lvt_dlvl_ss0p75v125c_i0p95v.db ]
set link_library   "* $target_library"
set search_path    [list . ./rtl ./constraints]

define_design_lib WORK -path ./syn/work

#----- 2. Read & elaborate -----
analyze -format verilog ./rtl/alu32.v
elaborate alu32
current_design alu32
link
check_design > ./syn/reports/check_design.rpt

#----- 3. Constraints -----
source ./constraints/alu32.sdc

#----- 4. Compile -----
compile_ultra -no_autoungroup

#----- 5. Reports (your resume metrics) -----
report_timing -max_paths 10 -nworst 2 > ./syn/reports/timing.rpt
report_area   -hierarchy              > ./syn/reports/area.rpt
report_power                          > ./syn/reports/power.rpt
report_qor                            > ./syn/reports/qor.rpt
report_constraint -all_violators      > ./syn/reports/violators.rpt

#----- 6. Outputs for PnR -----
change_names -rules verilog -hierarchy
write -format verilog -hierarchy -output ./syn/netlist/alu32_netlist.v
write_sdc                               ./syn/netlist/alu32.sdc
write -format ddc -hierarchy -output  ./syn/work/alu32.ddc

puts "==== SYNTHESIS DONE - check syn/reports/qor.rpt for slack ===="
exit
