# Yosys synthesis script for HSLM Full Top (Artix-7 XC7A100T)
# Trinity FPGA pipeline — ternary transformer inference

read_verilog tmu.v
read_verilog tmu_top.v
read_verilog ternary_activation.v
read_verilog ternary_rmsnorm.v
read_verilog embedding_lookup.v
read_verilog trinity_block.v
read_verilog argmax_unit.v
read_verilog hslm_full_top.v
hierarchy -top hslm_full_top
proc; opt; memory; opt
techmap; opt
synth_xilinx -top hslm_full_top -flatten
write_json hslm_full_top.json
stat
