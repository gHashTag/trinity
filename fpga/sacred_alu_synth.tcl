#!/usr/bin/tcl
# ═════════════════════════════════════════════════════════════════════════════
# SACRED ALU SYNTHESIS SCRIPT for Vivado
# ═════════════════════════════════════════════════════════════════════════════
#
# Target: sacred_alu.v (GF16/TF3-9 Arithmetic Unit)
# Device: Artix-7 XC7A100T (28nm TSMC)
#
# Usage: vivado -mode batch -source sacred_alu_synth.tcl
#         vivado -mode batch -source sacred_alu_synth.tcl -tclargs "set_property top sacred_alu"
#
# φ² + 1/φ² = 3 | TRINITY
# ═══════════════════════════════════════════════════════════════════════════════

# ============================================================================
# PROJECT CONFIGURATION
# ============================================================================
set project_name "Sacred_ALU"
set top_module "sacred_alu"
set device_part "xc7a100t"
set fpga_arch "artix7"

# ============================================================================
# DESIGN FILES
# ============================================================================
set rtl_dir "../fpga/openxc7-synth"
set verilog_files [list $rtl_dir/sacred_alu.v \
                  $rtl_dir/gf16_alu.v \
                  $rtl_dir/tf3_add.v \
                  $rtl_dir/tf3_dot.v]

puts "Info: Using RTL files:"
foreach f $verilog_files {
    puts "  - $f"
}

# ============================================================================
# SYNTHESIS SETTINGS
# ============================================================================
set synthesis_strategy "Vivado Synthesis Defaults"

# ============================================================================
# READ DESIGN
# ============================================================================
puts "Info: Reading design files..."
read_verilog $verilog_files

# ============================================================================
# SYNTHESIZE
# ============================================================================
puts "Info: Running synthesis..."
synth_design -top $top_module -part $device_part

# ============================================================================
# REPORT UTILIZATION
# ============================================================================
puts "Info: Generating utilization report..."
report_utilization -file utilization_sacred.txt

puts "Info: Utilization report saved to: utilization_sacred.txt"

# Print summary
puts "\n========================================"
puts "   SYNTHESIS COMPLETE"
puts "========================================"
puts "Module: $top_module"
puts "Part:   $device_part"
puts "\nReports:"
puts "  - utilization_sacred.txt"
puts "\n========================================"
