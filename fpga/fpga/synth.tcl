# Yosys synthesis script for Artix-7
read_verilog sim/trinity_simple.v
hierarchy -check
proc; opt; memory; opt; techmap; opt
# Write BLIF for further processing
write_blif build/trinity.blif
# Write JSON for nextpnr (if needed)
write_json build/trinity.json
# Statistics
stat
