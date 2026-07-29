#==============================================================================
# icc2.tcl  -  IC Compiler II: netlist -> GDSII   [SAED32 / ORCA library]
#
#     icc2_shell -f pnr/scripts/icc2.tcl | tee pnr/reports/icc2_run.log
#
# Run stage-by-stage the first time - paste each numbered block into an
# interactive icc2_shell and read the report before moving on. The power
# section (#2) is the one to watch.
#==============================================================================

##############################################################################
# 0. LIBRARY + DESIGN SETUP   (SAED32 reference NDMs - same as ORCA_TOP)
##############################################################################
set REF_LIBS [list \
  /home/vlsiguru/ORCA_TOP/ref/CLIBs/saed32_1p9m_tech.ndm \
  /home/vlsiguru/ORCA_TOP/ref/CLIBs/saed32_rvt.ndm \
  /home/vlsiguru/ORCA_TOP/ref/CLIBs/saed32_hvt.ndm \
  /home/vlsiguru/ORCA_TOP/ref/CLIBs/saed32_lvt.ndm \
  /home/vlsiguru/ORCA_TOP/ref/CLIBs/saed32_sram_lp.ndm ]

set TOP     "alu32"
set NETLIST "./syn/netlist/alu32_netlist.v"

# Tech is carried by saed32_1p9m_tech.ndm, so NO -technology argument here.
create_lib ${TOP}.nlib -ref_libs $REF_LIBS
read_verilog -top $TOP $NETLIST
link_block

read_sdc ./syn/netlist/alu32.sdc

# --- Parasitic (RC) setup ---
# SAED32 ships TLU+ files; lift the exact paths from ORCA's flow and set them
# here. Until then the flow runs with coarse RC (fine for a learning project).
# read_parasitic_tech -tlup <saed32_max.tluplus> -layermap <saed32.map> -name maxTLU
# set_parasitic_parameters -late_spec maxTLU -early_spec maxTLU

##############################################################################
# 1. FLOORPLAN
##############################################################################
initialize_floorplan -core_utilization 0.70 -core_offset 5 -shape R
connect_pg_net -automatic
place_pins -self
save_block -as ${TOP}_floorplan

##############################################################################
# 2. POWER PLANNING   <-- ORCA's recipe, adapted for a single-voltage,
#                         no-macro standard-cell block.
#
# Geometry (mesh widths / pitches / via rule) is lifted VERBATIM from ORCA's
# prj1_FP.power.tcl, so it's already DRC-clean on SAED32. What was REMOVED
# because the ALU doesn't have it:
#   * VDDH net + PD_RISC_CORE voltage area  (ORCA is multi-voltage; ALU isn't)
#   * $all_macros keepouts / blockages      (ALU has no hard macros)
#   * M4 channel straps                      (those go between macros)
#
# Power path:  M8/M7 top mesh --(via)--> M2 straps --(via)--> M1 std-cell rails
##############################################################################
connect_pg_net

# Via array used where mesh layers cross (ORCA's exact rule)
set_pg_via_master_rule pgvia_8x10 -via_array_dimension {8 10}

#--- Patterns (ORCA's exact geometry) ---
# Top mesh: M7 horizontal + M8 vertical
create_pg_mesh_pattern P_top_two -layers { \
    { {horizontal_layer: M7} {width: 1.104} {spacing: interleaving} {pitch: 13.376} {offset: 0.856} {trim : true} } \
    { {vertical_layer:   M8} {width: 4.64 } {spacing: interleaving} {pitch: 19.456} {offset: 6.08 } {trim : true} } } \
    -via_rule { {intersection: adjacent} {via_master : pgvia_8x10} }

# Low mesh: M2 vertical (3-wire group) to feed the std-cell rails
create_pg_mesh_pattern P_m2_triple -layers { \
    { {vertical_layer: M2} {track_alignment : track} {width: 0.44 0.192 0.192} {spacing: 2.724 3.456} {pitch: 9.728} {offset: 1.216} {trim : true} } }

#--- Strategies (VDD/VSS only) ---
set_pg_strategy S_top_vddvss -core \
    -pattern { {name: P_top_two} {nets: {VSS VDD}} {offset_start: {0 0}} } \
    -extension { {{stop: keep_floating_wire_piecies}} }

set_pg_strategy S_m2_vddvss -core \
    -pattern { {name: P_m2_triple} {nets: {VDD VSS VSS}} {offset_start: {0 0}} } \
    -extension { {{direction: BT} {stop: keep_floating_wire_piecies}} }

# Via rule tying the M2 straps up to the M7 top mesh
set_pg_strategy_via_rule S_via_m2_m7 -via_rule { \
    { {{strategies: {S_m2_vddvss}} {layers: {M2}} {nets: {VDD}}} {{strategies: {S_top_vddvss}} {layers: {M7}}} {via_master: {default}} } \
    { {{strategies: {S_m2_vddvss}} {layers: {M2}} {nets: {VSS}}} {{strategies: {S_top_vddvss}} {layers: {M7}}} {via_master: {default}} } }

compile_pg -strategies {S_top_vddvss S_m2_vddvss} -via_rule {S_via_m2_m7}

#--- Standard-cell rails (M1) ---
create_pg_std_cell_conn_pattern P_std_cell_rail
set_pg_strategy S_std_cell_rail_VSS_VDD -core \
    -pattern   {{pattern: P_std_cell_rail} {nets: {VSS VDD}}} \
    -extension {{stop: outermost_ring} {direction: L B R T}}
set_pg_strategy_via_rule S_via_stdcellrail \
    -via_rule {{intersection: adjacent} {via_master: default}}
compile_pg -strategies {S_std_cell_rail_VSS_VDD} -via_rule {S_via_stdcellrail}

#--- Verify (ORCA's checks; ALL must be clean before placement) ---
check_pg_missing_vias                              > ./pnr/reports/pg_vias.rpt
check_pg_drc -ignore_std_cells                     > ./pnr/reports/pg_drc.rpt
check_pg_connectivity -check_std_cell_pins none    > ./pnr/reports/pg_conn.rpt
save_block -as ${TOP}_powerplan

##############################################################################
# 3. PLACEMENT
##############################################################################
place_opt
legalize_placement
report_placement           > ./pnr/reports/placement.rpt
report_timing -max_paths 5 > ./pnr/reports/timing_postplace.rpt
report_congestion          > ./pnr/reports/congestion.rpt
save_block -as ${TOP}_placed

##############################################################################
# 4. CLOCK TREE SYNTHESIS
##############################################################################
set_propagated_clock [all_clocks]
clock_opt
report_clock_qor -type latency > ./pnr/reports/cts_latency.rpt
report_clock_qor -type skew    > ./pnr/reports/cts_skew.rpt
report_timing -max_paths 5     > ./pnr/reports/timing_postcts.rpt
save_block -as ${TOP}_cts

##############################################################################
# 5. ROUTING
##############################################################################
route_auto
route_opt
report_timing -delay_type max -max_paths 10 > ./pnr/reports/timing_setup.rpt
report_timing -delay_type min -max_paths 10 > ./pnr/reports/timing_hold.rpt
check_routes                                > ./pnr/reports/route_check.rpt
save_block -as ${TOP}_routed

##############################################################################
# 6. CHIP FINISHING        (SAED32 fillers, RVT)
##############################################################################
create_stdcell_fillers \
    -lib_cells {SHFILL128_RVT SHFILL64_RVT SHFILL3_RVT SHFILL2_RVT SHFILL1_RVT}
connect_pg_net
check_lvs                > ./pnr/reports/lvs_precheck.rpt
report_design_violations > ./pnr/reports/drc_violations.rpt

##############################################################################
# 7. SIGNOFF EXPORTS  (hand-off to PrimeTime + GDS)
##############################################################################
report_qor           > ./pnr/reports/final_qor.rpt
report_global_timing > ./pnr/reports/global_timing.rpt
write_verilog                         ./pnr/output/alu32_routed.v
write_parasitics -format spef -output ./pnr/output/alu32.spef
write_sdf                             ./pnr/output/alu32.sdf
write_gds                             ./pnr/output/alu32.gds
save_block
save_lib
puts "==== PnR COMPLETE - GDS at pnr/output/alu32.gds ===="
exit
