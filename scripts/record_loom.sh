#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
# TRINITY OS v1.0 — Loom Recording Script
# ═══════════════════════════════════════════════════════════════════════════════
# 60-second investor pitch recording with live demo
# Usage: ./scripts/record_loom.sh [--dry-run]
# Output: Instructions for Loom recording + timestamp markers
# ═══════════════════════════════════════════════════════════════════════════════

set -e

# Colors
GOLD="\x1b[33m"
GREEN="\x1b[32m"
CYAN="\x1b[36m"
MAGENTA="\x1b[35m"
BOLD="\x1b[1m"
RESET="\x1b[0m"

MODE="${1:-}"

echo -e "${GOLD}${BOLD}╔════════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${GOLD}${BOLD}║     TRINITY OS v1.0 — LOOM RECORDING DIRECTOR                  ║${RESET}"
echo -e "${GOLD}${BOLD}╚════════════════════════════════════════════════════════════════╝${RESET}"
echo ""

# Phase 1: Setup
echo -e "${CYAN}[SETUP]${RESET} Loom Recording Environment"
echo ""
echo -e "${GREEN}✓${RESET} 1. Open Chrome → Loom extension"
echo -e "${GREEN}✓${RESET} 2. Select: 'Current Tab' + 'Camera (PiP)'"
echo -e "${GREEN}✓${RESET} 3. Position: FPGA board visible + face in corner"
echo -e "${GREEN}✓${RESET} 4. Terminal: full screen, large font (16pt+)"
echo -e "${GREEN}✓${RESET} 5. Run demo: ${CYAN}./zig-out/bin/tri os demo --full${RESET}"
echo ""

# Scene breakdown
echo -e "${CYAN}[SCENE BREAKDOWN]${RESET} 60 Seconds Total"
echo ""
echo -e "${GOLD}[0:00-0:05] HOOK — 'We Just Compiled God'${RESET}"
echo -e "  → Show face + FPGA board"
echo -e "  → Script: 'We just compiled the universe into Verilog and"
echo -e "              flashed it onto a $12 chip.'"
echo ""
echo -e "${GOLD}[0:05-0:15] PROBLEM — Binary is Broken${RESET}"
echo -e "  → Screen: Binary computing stats (20x waste)"
echo -e "  → Script: 'Binary wastes 20x memory. Zero, one. False dichotomy.'"
echo ""
echo -e "${GOLD}[0:15-0:25] SOLUTION — Ternary Computing${RESET}"
echo -e "  → Screen: Sacred formula φ² + 1/φ² = 3"
echo -e "  → Script: 'TRINITY brings minus one, zero, plus one.'"
echo ""
echo -e "${GOLD}[0:25-0:35] DEMO — Live Hardware${RESET}"
echo -e "  → ${CYAN}TYPE: ./zig-out/bin/tri os demo --fpga${RESET}"
echo -e "  → Show: LED blink pattern (1.618 Hz)"
echo -e "  → Script: 'Watch this. φ heartbeat. 1.618 hertz.'"
echo ""
echo -e "${GOLD}[0:35-0:45] PROOF — Fermilab's Anomaly${RESET}"
echo -e "  → ${CYAN}TYPE: ./zig-out/bin/tri query 'Z=120'${RESET}"
echo -e "  → Show: 27.4 seconds result live"
echo -e "  → Script: 'They need supercomputers. We do this in 0.3ms.'"
echo ""
echo -e "${GOLD}[0:45-0:55] MARKET — Zero Competitors${RESET}"
echo -e "  → Screen: Market size $477B by 2030"
echo -e "  → Script: 'Zero ternary competitors. We own the category.'"
echo ""
echo -e "${GOLD}[0:55-1:00] ASK — $5M Seed${RESET}"
echo -e "  → Screen: QR code → deck + demo"
echo -e "  → Script: 'We're raising 5 million to scale this.'"
echo -e "            'TRINITY. The universe in a chip.'"
echo ""

# Timestamp markers
echo -e "${CYAN}[TIMELINE MARKERS]${RESET} Reference During Recording"
echo ""
echo "  0:00  — Start recording, smile"
echo "  0:05  — Show board, say hook"
echo "  0:15  — Switch to problem slide"
echo "  0:25  — Type tri os demo --fpga"
echo "  0:30  — Point to LED blink"
echo "  0:35  — Type tri query 'Z=120'"
echo "  0:40  — Show result, say 'SOLVED'"
echo "  0:45  — Market slide"
echo "  0:55  — Call to action"
echo "  1:00  — Stop recording, smile"
echo ""

# Post-recording
echo -e "${CYAN}[POST-RECORDING]${RESET}"
echo ""
echo "  1. Trim to exactly 60 seconds"
echo "  2. Generate GIF thumbnail (best frame with LED + result)"
echo "  3. Copy Loom URL: ${CYAN}https://www.loom.com/share/XXXX${RESET}"
echo "  4. Paste into: docs/investor_deck_v2.md (Slide 1)"
echo "  5. Save as: trinity-os-v1.0-demo.loom"
echo ""

# Dry run mode
if [[ "$MODE" == "--dry-run" ]]; then
    echo -e "${MAGENTA}[DRY RUN]${RESET} Practice mode — no actual recording"
    echo ""
    echo "  1. Position yourself now (FPGA visible + face)"
    echo "  2. Open terminal: ${CYAN}./zig-out/bin/tri os demo --fpga${RESET}"
    echo "  3. Practice the script 3 times"
    echo "  4. When ready, run ${CYAN}./scripts/record_loom.sh${RESET} (no --dry-run)"
fi

echo ""
echo -e "${GOLD}${BOLD}╔════════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${GOLD}${BOLD}║     READY TO RECORD — OPEN LOOM EXTENSION NOW                ║${RESET}"
echo -e "${GOLD}${BOLD}╚════════════════════════════════════════════════════════════════╝${RESET}"
echo ""
echo -e "${MAGENTA}φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS THE OPERATING SYSTEM${RESET}"
echo ""
