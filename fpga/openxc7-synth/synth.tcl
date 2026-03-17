# Yosys synthesis script for HSLM Full Top (Artix-7 XC7A100T)
# Trinity FPGA pipeline — ternary transformer inference

read_verilog hslm_full_top.v
hierarchy -top hslm_full_top
proc; opt; memory; opt
techmap; opt
synth_xilinx -top hslm_full_top -flatten
write_json hslm_full_top.json
stat
