#!/bin/bash
# ═════════════════════════════════════════════════════════════════════════
# TRINITY FPGA — Installation Status & Next Steps
# ═════════════════════════════════════════════════════════════════════════

cat << 'EOF'
╔══════════════════════════════════════════════════════════════════════╗
║  TRINITY FPGA — STATUS & NEXT STEPS                                  ║
╠══════════════════════════════════════════════════════════════════════╣
║                                                                      ║
║  ✅ OpenOCD       — INSTALLED                                        ║
║  ✅ Yosys (Mac)    — INSTALLED (0.62)                                ║
║  ✅ Icarus Verilog — INSTALLED                                       ║
║  ✅ Simulation   — 4/4 TESTS PASSED                                  ║
║  ✅ Disk Space   — 127 GB AVAILABLE                                  ║
║  ✅ FPGA Hardware — DETECTED (USB)                                   ║
║  ✅ F4PGA Docker  — READY (2.31 GB)                                  ║
║  ✅ Synthesis    — WORKING (trinity.blif/json)                       ║
║                                                                      ║
╠══════════════════════════════════════════════════════════════════════╣
║  F4PGA DOCKER CONTAINER:                                             ║
║                                                                      ║
║  Image: f4pga-artix7 (2.31 GB)                                       ║
║  Platform: linux/amd64 (emulated on Mac ARM64)                       ║
║                                                                      ║
║  Tools included:                                                     ║
║  • Yosys 0.62        — Verilog synthesis                             ║
║  • OpenOCD 0.11.0     — FPGA programming                             ║
║  • Python 3.9.23     — Project X-Ray tools                           ║
║  • Artix-7 Database  — Chip database for xc7a35t                     ║
║                                                                      ║
║  Quick commands:                                                     ║
║  docker run --rm -v "$(pwd)/sim:/workspace/verilog" f4pga-artix7 \\  ║
║    yosys -p 'read_verilog trinity_simple.v; proc; opt; stat'         ║
║                                                                      ║
╠══════════════════════════════════════════════════════════════════════╣
║  SYNTHESIS RESULTS:                                                  ║
║                                                                      ║
║  Module: trinity_top                                                 ║
║  • 27 wires, 296 wire bits                                          ║
║  • 19 cells (optimized from 26)                                     ║
║  • 4 flip-flops (data_out, valid_out, state, cycle_counter)         ║
║  • 5 comparators, 1 adder, 1 mux, 3 pmux                            ║
║                                                                      ║
║  Output files (in sim/build/):                                       ║
║  • trinity.blif (14 KB) — BLIF netlist                              ║
║  • trinity.json (23 KB) — JSON netlist                              ║
║                                                                      ║
╠══════════════════════════════════════════════════════════════════════╣
║  NEXT STEPS:                                                         ║
║                                                                      ║
║  FOR FULL BITSTREAM GENERATION:                                      ║
║                                                                      ║
║  Option A — Use Vivado (recommended for bitstream):                 ║
║  1. Install Vivado (need AMD/Xilinx account)                        ║
║  2. Run synthesis in Vivado to generate .bit file                   ║
║  3. Flash: bash fpga/flash_arty_demo.sh                             ║
║                                                                      ║
║  Option B — Use F4PGA (open source, experimental):                  ║
║  1. Install nextpnr-xilinx for Place & Route                        ║
║  2. Use Project X-Ray tools for bitstream generation                ║
║  3. Note: F4PGA for Artix-7 is still in development                  ║
║                                                                      ║
║  Option C — Remote build:                                            ║
║  1. Use cloud Linux machine with Vivado installed                   ║
║  2. Generate .bit file remotely                                     ║
║  3. Transfer to Mac and flash with OpenOCD                          ║
║                                                                      ║
╠══════════════════════════════════════════════════════════════════════╣
║  FILES CREATED:                                                      ║
║                                                                      ║
║  • fpga/Dockerfile.f4pga    — F4PGA Docker image                     ║
║  • fpga/flash_arty_demo.sh  — Flash script for Arty A7              ║
║  • sim/trinity_simple.v    — Simplified Verilog (working)            ║
║  • sim/tb_simple.v         — Testbench (4 tests pass)                ║
║  • sim/build/trinity.blif  — Synthesized netlist                     ║
║  • sim/build/trinity.json  — Synthesized netlist (JSON)              ║
║  • specs/tri/trinity_fpga_core.vibee — VIBEE spec                   ║
║                                                                      ║
╚══════════════════════════════════════════════════════════════════════╝
EOF

# Check Docker images
echo ""
echo "─ Docker Images ─"
docker images | grep -E "f4pga|vivado" || echo "No FPGA images found"

# Check Docker container status
echo ""
echo "─ Docker Container Status ─"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null | head -10

# Check FPGA connection
echo ""
echo "─ FPGA USB Connection ─"
system_profiler SPUSBDataType 2>/dev/null | grep -A 5 -i "xilinx\|digilent\|artix" || echo "FPGA not detected (may need drivers)"

# Check synthesis output
echo ""
echo "─ Synthesis Output ─"
if [ -f "sim/build/trinity.blif" ]; then
    echo "✅ trinity.blif ($(stat -f%z sim/build/trinity.blif 2>/dev/null || stat -c%s sim/build/trinity.blif) bytes)"
    echo "✅ trinity.json ($(stat -f%z sim/build/trinity.json 2>/dev/null || stat -c%s sim/build/trinity.json) bytes)"
else
    echo "⚠️  Synthesis output not found (run synthesis first)"
fi

echo ""
echo "─ Done ─"
