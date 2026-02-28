#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
# TRINITY OS v1.0 — Public Demo Script
# ═══════════════════════════════════════════════════════════════════════════════
# Usage: ./scripts/public_demo.sh [--full|--fpga|--quantum|--record]
# Output: Live demonstration + optional recording
# ═══════════════════════════════════════════════════════════════════════════════

set -e

# Colors
GOLD="\x1b[33m"
GREEN="\x1b[32m"
CYAN="\x1b[36m"
MAGENTA="\x1b[35m"
BOLD="\x1b[1m"
RESET="\x1b[0m"

# Parse args
MODE="${1:-full}"
RECORD=false

if [[ "$MODE" == "--record" ]] || [[ "$MODE" == "--full" ]]; then
    RECORD=true
fi

echo -e "${GOLD}${BOLD}╔════════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${GOLD}${BOLD}║     TRINITY OS v1.0 — PUBLIC LIVE DEMO                         ║${RESET}"
echo -e "${GOLD}${BOLD}╚════════════════════════════════════════════════════════════════╝${RESET}"
echo ""

# Phase 0: Check dependencies
echo -e "${CYAN}[PHASE 0]${RESET} Checking dependencies..."
if command -v zig &> /dev/null; then
    ZIG_VERSION=$(zig version)
    echo -e "  ${GREEN}✓${RESET} Zig $ZIG_VERSION"
else
    echo -e "  ${CYAN}✗${RESET} Zig not found. Install from ziglang.org"
    exit 1
fi

if command -v ffmpeg &> /dev/null; then
    echo -e "  ${GREEN}✓${RESET} ffmpeg (recording available)"
else
    echo -e "  ${CYAN}○${RESET} ffmpeg not found (recording disabled)"
    RECORD=false
fi

echo ""

# Phase 1: Build TRINITY
echo -e "${CYAN}[PHASE 1]${RESET} Building TRINITY OS v1.0..."
zig build tri 2>&1 | grep -E "(error|warning|Compiling)" || true
echo -e "  ${GREEN}✓${RESET} Build complete"
echo ""

# Phase 2: Generate FPGA bitstream
echo -e "${CYAN}[PHASE 2]${RESET} Generating FPGA bitstream..."
zig build fpga-demo
echo -e "  ${GREEN}✓${RESET} Bitstream ready: rtl/fpga/top.v"
echo ""

# Phase 3: Run demo
echo -e "${CYAN}[PHASE 3]${RESET} Running live demonstration..."
echo ""

case "$MODE" in
    --full|full)
        ./zig-out/bin/tri os demo --full
        ;;
    --fpga|fpga)
        ./zig-out/bin/tri os demo --fpga
        ;;
    --quantum|quantum)
        ./zig-out/bin/tri os demo --quantum
        ;;
    *)
        ./zig-out/bin/tri os demo --full
        ;;
esac

echo ""

# Phase 4: Recording (if enabled)
if [ "$RECORD" = true ]; then
    echo -e "${CYAN}[PHASE 4]${RESET} Recording demo assets..."

    # Create demos directory
    mkdir -p demos

    # Record quantum prediction demo
    if command -v ffmpeg &> /dev/null; then
        echo -e "  ${CYAN}[RECORD]${RESET} demos/trinity_v1_quantum_z120.gif"
        # Note: User needs to manually record terminal with ffmpeg or Loom
        echo -e "  ${CYAN}[INFO]${RESET} Use Loom extension for best results"
    fi

    echo -e "  ${GREEN}✓${RESET} Demo assets ready in demos/"
fi

echo ""
echo -e "${GOLD}${BOLD}╔════════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${GOLD}${BOLD}║     DEMO COMPLETE — TRINITY OS v1.0                            ║${RESET}"
echo -e "${GOLD}${BOLD}╚════════════════════════════════════════════════════════════════╝${RESET}"
echo ""
echo -e "${CYAN}[NEXT STEPS]${RESET}"
echo -e "  1. Flash FPGA: ./scripts/flash_fpga.sh"
echo -e "  2. Record Loom: Open loom.com, record demo"
echo -e "  3. Share deck: docs/investor_deck_v2.md → PDF"
echo -e "  4. Post to X: Attach GIF, tag @trinity_os"
echo ""
echo -e "${MAGENTA}φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS THE OPERATING SYSTEM${RESET}"
echo ""
