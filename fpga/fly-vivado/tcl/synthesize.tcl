# ═══════════════════════════════════════════════════════════════════════════════
# TRINITY FPGA CORE — Vivado Synthesis Script
# Target: Digilent Arty A7 (Artix-7)
# ═══════════════════════════════════════════════════════════════════════════════

# Project settings
set project_name "trinity_fpga_core"
set top_module "TrinityControl_top"
set device xc7a35tcpg236-1

# Create project
create_project $project_name ./vivado_build -part $device -force

# Add source files
add_files -norecurse {
    ../../trinity/output/fpga/trinity_fpga_core.v
}

# Add constraints (will be created separately)
# add_files -fileset constrs_1 -norecurse constraints/arty_a7.xdc

# Set top module
set_property top $top_module [current_fileset]

# ═══════════════════════════════════════════════════════════════════════════════
# SYNTHESIS
# ═══════════════════════════════════════════════════════════════════════════════

launch_runs synth_1 -jobs 4
wait_on_run synth_1

# ═══════════════════════════════════════════════════════════════════════════════
# IMPLEMENTATION
# ═══════════════════════════════════════════════════════════════════════════════

launch_runs impl_1 -jobs 4
wait_on_run impl_1

# ═══════════════════════════════════════════════════════════════════════════════
# BITSTREAM GENERATION
# ═══════════════════════════════════════════════════════════════════════════════

launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1

# ═══════════════════════════════════════════════════════════════════════════════
# EXPORT BITSTREAM
# ═══════════════════════════════════════════════════════════════════════════════

set bitstream_path ./vivado_build/$project_name.bit
file copy -force ./vivado_build/$top_module.runs/impl_1/$top_module.bit $bitstream_path

puts "╔════════════════════════════════════════════════════════════════╗"
puts "║  TRINITY FPGA BITSTREAM GENERATED                               ║"
puts "╠════════════════════════════════════════════════════════════════╣"
puts "║  Bitstream: $bitstream_path                                    ║"
puts "║  Target:    Digilent Arty A7                                   ║"
puts "║  FPGA:      Artix-7 XC7A35T                                    ║"
puts "╚════════════════════════════════════════════════════════════════╝"

# Close project
close_project
