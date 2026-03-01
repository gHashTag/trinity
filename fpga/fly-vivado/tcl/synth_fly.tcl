# Trinity FPGA Synthesis Script for Vivado (fly.io)
# Target: Digilent Arty A7 35T (xc7a35tcsg324-1)

set top_module trinity_top
set part_name xc7a35tcsg324-1
set output_dir /workspace/output

# Create project
create_project trinity_proj $output_dir/vivado_proj -part $part_name -force

# Add source files
add_files -norecurse /workspace/verilog/trinity_simple.v

# Add constraints
add_files -fileset constrs_1 -norecurse /workspace/constraints/arty_a7.xdc

# Set top module
set_property top $top_module [current_fileset]
update_compile_order -fileset sources_1

# Synthesize
puts "INFO: Starting synthesis..."
synth_design -top $top_module -part $part_name

# Optimize
opt_design

# Place
puts "INFO: Starting placement..."
place_design

# Route
puts "INFO: Starting routing..."
route_design

# Generate bitstream
puts "INFO: Generating bitstream..."
write_bitstream -force $output_dir/trinity.bit

# Reports
report_utilization -file $output_dir/utilization.txt
report_timing_summary -file $output_dir/timing.txt

puts "SUCCESS: trinity.bit generated at $output_dir/trinity.bit"

close_project
exit
