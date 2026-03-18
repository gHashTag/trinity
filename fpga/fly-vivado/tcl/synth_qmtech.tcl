# Trinity FPGA Synthesis — QMTECH XC7A100T-1FGG676C Core Board
# LED Blink test to verify JTAG programming

set top_module trinity_top
set part_name xc7a100t-1fgg676
set output_dir /workspace/output

# Create project
create_project trinity_qmtech $output_dir/vivado_proj -part $part_name -force

# Add source files
add_files -norecurse /workspace/verilog/trinity_qmtech.v

# Add constraints
add_files -fileset constrs_1 -norecurse /workspace/constraints/qmtech_xc7a100t.xdc

# Set top module
set_property top $top_module [current_fileset]
update_compile_order -fileset sources_1

# Synthesize
puts "INFO: Starting synthesis for QMTECH XC7A100T..."
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
write_bitstream -force $output_dir/trinity_qmtech.bit

# Reports
report_utilization -file $output_dir/utilization.txt
report_timing_summary -file $output_dir/timing.txt

puts "SUCCESS: trinity_qmtech.bit generated"

close_project
exit
