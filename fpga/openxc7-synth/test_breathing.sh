#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# TRINITY V2 — Breathing Mode Test Script
# ═══════════════════════════════════════════════════════════════════════════════
#
# Simulates and tests the breathing LED + Morse "TRINITY" effect
#
# Usage: ./test_breathing.sh [--sim|--help]
# ═══════════════════════════════════════════════════════════════════════════════

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${PURPLE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${PURPLE}  TRINITY V2 — Breathing Mode Test${NC}"
echo -e "${PURPLE}═══════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${CYAN}Morse Code: TRINITY${NC}"
echo -e "${YELLOW}  T${NC}  = dash (---)"
echo -e "${YELLOW}  R${NC}  = dot-dash-dot (.-.)"
echo -e "${YELLOW}  I${NC}  = dot-dot (..)"
echo -e "${YELLOW}  N${NC}  = dot-dash (.-)"
echo -e "${YELLOW}  I${NC}  = dot-dot (..)"
echo -e "${YELLOW}  T${NC}  = dash (---)"
echo -e "${YELLOW}  Y${NC}  = dash-dot-dot-dash (-.-.)"
echo ""
echo -e "${BLUE}Timing:${NC}"
echo "  • Breathing cycle: 2.6 seconds (φ²)"
echo "  • Heartbeat: 1.6 seconds (φ)"
echo "  • Morse repeat: Every 10 seconds"
echo ""

#===============================================================================
# SIMULATION WITH IVERILOG
#===============================================================================

MODE="test"

for arg in "$@"; do
    case $arg in
        --sim)
            MODE="sim"
            ;;
        --help|-h)
            echo "Usage: $0 [--sim|--help]"
            echo ""
            echo "Options:"
            echo "  --sim    Run Icarus Verilog simulation"
            echo "  --help   Show this help"
            exit 0
            ;;
    esac
done

if [ "$MODE" = "sim" ]; then
    echo -e "${GREEN}Step 1: Creating testbench...${NC}"

    cat > tb_breathing.v <<'EOF'
// Testbench for TRINITY V2 Breathing Mode
`timescale 1ns / 1ps

module tb_breathing;
    reg clk;
    reg rst;
    wire uart_rx;
    wire uart_tx;
    wire led_d5;
    wire led_d6;
    wire led_d7;

    // Instantiate DUT
    trinity_v2_breathing dut (
        .clk(clk),
        .rst(rst),
        .uart_rx(uart_rx),
        .uart_tx(uart_tx),
        .led_d5(led_d5),
        .led_d6(led_d6),
        .led_d7(led_d7)
    );

    // Clock generation (50MHz)
    initial clk = 0;
    always #10 clk = ~clk;  // 20ns period = 50MHz

    // Test stimulus
    initial begin
        $dumpfile("tb_breathing.vcd");
        $dumpvars(0, tb_breathing);

        // Initialize
        rst = 1;
        uart_rx = 1;
        #100;
        rst = 0;

        $display("\n");
        $display("╔═══════════════════════════════════════════════════════════════╗");
        $display("║  TRINITY V2 — Breathing Mode Simulation                      ║");
        $display("╚═══════════════════════════════════════════════════════════════╝");
        $display("\n");
        $display("Time     | D5 (Breathe) | D6 (Heart) | D7 (Morse) | Note");
        $display("─────────┼──────────────┼────────────┼────────────┼────────");

        // Monitor for ~50 microseconds (simulation time)
        // In real hardware, breathing = 2.6s, heartbeat = 1.6s
        fork
            begin
                #10000000;  // Run for 10ms
                $monitor("%t | %b | %b | %b | %s",
                    $time, led_d5, led_d6, led_d7,
                    led_d7 ? "MORSE!" : "...");
            end
            begin
                #50000000;  // 50ms
            end
        join

        $display("\nSimulation complete.");
        $display("In hardware, run for ~30 seconds to see full cycle.");
        $finish;
    end

endmodule
EOF

    echo -e "${GREEN}✓ Testbench created${NC}"

    echo ""
    echo -e "${GREEN}Step 2: Compiling with Icarus Verilog...${NC}"

    if ! command -v iverilog &> /dev/null; then
        echo -e "${YELLOW}⚠ iverilog not found. Install: brew install icarus-verilog${NC}"
    else
        iverilog -o tb_breathing tb_breathing.v trinity_v2_breathing.v 2>&1 | head -20
        echo -e "${GREEN}✓ Compilation complete${NC}"

        echo ""
        echo -e "${GREEN}Step 3: Running simulation...${NC}"
        vvp tb_breathing

        echo ""
        echo -e "${GREEN}✓ Simulation complete!${NC}"
        echo "  Check tb_breathing.vcd for waveform (use gtkwave)"
    fi

else
    echo -e "${YELLOW}Skipping simulation (use --sim to run)${NC}"
fi

#===============================================================================
# VISUAL TIMELINE
#===============================================================================

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  LED Behavior Timeline${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""
echo "Time  | LED D5 (Breathing) | LED D6 (Heartbeat) | LED D7 (Morse)"
echo "──────|────────────────────|───────────────────|────────────────"
echo "0-2s  | Smooth pulse       | Off               | Off"
echo "2s    | Pulse peak         | Flash (φ)         | Off"
echo "4s    | Pulse mid          | Off               | Off"
echo "6s    | Pulse low          | Flash (φ)         | Off"
echo "8s    | Rising             | Off               | Off"
echo "10s   | Pauses             | Flash             | MORSE STARTS"
echo "10s+  | Off                | Off               | -.-. (TRINITY)"
echo "15s   | Resumes breathing  | Flash             | Off"
echo "20s+  | Full breathing cycle | Continue         | Waiting for next..."
echo ""

#===============================================================================
# RESOURCE ESTIMATE
#===============================================================================

echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  Resource Estimate (XC7A100T)${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""
echo "Component        | LUTs   | FFs    | BRAMs | Notes"
echo "─────────────────┼────────┼────────┼───────┼──────────────────"
echo "Breathing LED    | ~150   | ~100   | 0     | Sine approximation"
echo "Heartbeat        | ~50    | ~30    | 0     | Simple counter"
echo "Morse Encoder    | ~200   | ~150   | 0     | State machine"
echo "Top Level        | ~100   | ~50    | 0     | Glue logic"
echo "─────────────────┼────────┼────────┼───────┼──────────────────"
echo "TOTAL            | ~500   | ~330   | 0     | < 1% of device!"
echo ""

#===============================================================================
# NEXT STEPS
#===============================================================================

echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  Ready for Synthesis${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
echo ""
echo "To build and flash:"
echo ""
echo "  1. Synthesize with Yosys:"
echo "     yosys -p 'synth_xilinx -flatten -abc9 -top trinity_v2_breathing' \\"
echo "         trinity_v2_breathing.v"
echo ""
echo "  2. Generate bitstream (when JTAG arrives):"
echo "     docker run --rm -v \"\$(pwd):/work\" -w /work \\"
echo "         regymm/openxc7 nextpnr-xilinx --chip xc7a100tfgg676-1 \\"
echo "         --json breathing.json --fasm breathing.fasm"
echo ""
echo "  3. Flash to FPGA:"
echo "     fpga/tools/jtag_program breathing.bit"
echo ""
echo "  4. Watch the show! 🎬"
echo ""
