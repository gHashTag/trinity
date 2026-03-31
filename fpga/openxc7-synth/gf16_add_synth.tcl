# GF16 Adder Synthesis — QMTECH XC7A100T-FGG676
# BENCH-005: FPGA Synthesis — LUT/FF/Fmax measurement
#
# Usage:
#   cd fpga/openxc7-synth
#   vivado -mode batch -source gf16_add_synth.tcl

set top_module gf16_add_top
set part_name xc7a100t-fgg676-1
set project_name gf16_add
set output_dir ./gf16_add_output

# ============================================================================
# CREATE PROJECT
# ============================================================================
puts "=========================================="
puts "GF16 Adder Synthesis"
puts "Target: QMTECH XC7A100T-FGG676"
puts "=========================================="

create_project ${project_name}_proj ${output_dir}/vivado_proj -part $part_name -force

# ============================================================================
# ADD SOURCE FILES
# ============================================================================
add_files -norecurse ./gf16_add_top.v

# ============================================================================
# SET TOP MODULE
# ============================================================================
set_property top $top_module [current_fileset]
update_compile_order -fileset sources_1

# ============================================================================
# SYNTHESIS
# ============================================================================
puts "\[1/4\] Running synth_design..."
synth_design -top $top_module -part $part_name

# ============================================================================
# OPTIMIZE
# ============================================================================
puts "\[2/4\] Running opt_design..."
opt_design

# ============================================================================
# REPORTS
# ============================================================================
puts "\[3/4\] Generating reports..."

# Utilization (LUT, FF, DSP, BRAM)
report_utilization -file ${output_dir}/utilization.rpt

# Timing (Fmax, WNS, TNS)
report_timing_summary -file ${output_dir}/timing.rpt
report_power -file ${output_dir}/power.rpt

# Datasheet (detailed timing)
report_timing -sort_by slack -max_paths 10 -file ${output_dir}/timing_detailed.rpt

# ============================================================================
# WRITE CHECKPOINT (optional, for place_route)
# ============================================================================
puts "\[4/4\] Writing checkpoint..."
write_checkpoint -force ${output_dir}/synth.dcp

# ============================================================================
# PRINT SUMMARY
# ============================================================================
puts "\n=========================================="
puts "SYNTHESIS COMPLETE"
puts "=========================================="
puts "Reports:"
puts "  Utilization: ${output_dir}/utilization.rpt"
puts "  Timing:      ${output_dir}/timing.rpt"
puts "  Power:       ${output_dir}/power.rpt"
puts "  Checkpoint:  ${output_dir}/synth.dcp"
puts ""
puts "Next steps:"
puts "  1. Check utilization.rpt for LUT/FF/DSP counts"
puts "  2. Check timing.rpt for Fmax (WNS = 0 means met)"
puts "=========================================="

close_project
exit
