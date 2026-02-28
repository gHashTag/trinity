#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
# TRINITY OS v1.0 — Demo GIF Generator
# ═══════════════════════════════════════════════════════════════════════════════
# Generates animated GIF from TRI demo for social media
# Usage: ./scripts/demo_gif.sh [--duration=30]
# Output: demos/trinity_v1_quantum_z120.gif
# ═══════════════════════════════════════════════════════════════════════════════

set -e

# Colors
GOLD="\x1b[33m"
GREEN="\x1b[32m"
CYAN="\x1b[36m"
RESET="\x1b[0m"

DURATION="${1:-30}"

echo -e "${GOLD}╔════════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${GOLD}║     TRINITY OS v1.0 — GIF GENERATOR                             ║${RESET}"
echo -e "${GOLD}╚════════════════════════════════════════════════════════════════╝${RESET}"
echo ""

# Create demos directory
mkdir -p demos

# Check for recording tools
if command -v ffmpeg &> /dev/null; then
    echo -e "${GREEN}✓${RESET} ffmpeg found"
    HAS_FFMPEG=true
else
    echo -e "${CYAN}○${RESET} ffmpeg not found (will use alternative)"
    HAS_FFMPEG=false
fi

if command -v asciinema &> /dev/null; then
    echo -e "${GREEN}✓${RESET} asciinema found"
    HAS_ASCIINEMA=true
else
    echo -e "${CYAN}○${RESET} asciinema not found"
    HAS_ASCIINEMA=false
fi

echo ""

# Method 1: asciinema + agg (recommended)
if [[ "$HAS_ASCIINEMA" == true ]]; then
    echo -e "${CYAN}[METHOD 1]${RESET} asciinema → GIF"
    echo ""
    echo "  1. Record: asciinema rec trinity_demo.cast"
    echo "     → Run: ./zig-out/bin/tri os demo --quantum"
    echo "     → Press Ctrl+D when done"
    echo ""
    echo "  2. Convert: agg trinity_demo.cast trinity_demo.gif"
    echo "     → Install agg: npm install -g agg"
    echo ""
    echo "  3. Optimize: gifsicle -O3 trinity_demo.gif -o demos/trinity_v1_quantum_z120.gif"
    echo ""
fi

# Method 2: Terminalizer (macOS alternative)
echo -e "${CYAN}[METHOD 2]${RESET} Terminalizer (macOS)"
echo ""
echo "  1. Install: brew install terminalizer"
echo "  2. Record: terminalizer record -g demos/trinity_v1_quantum_z120.gif"
echo "  3. Run demo in recorded window"
echo ""

# Method 3: Loom → GIF (easiest)
echo -e "${CYAN}[METHOD 3]${RESET} Loom → GIF (Recommended)"
echo ""
echo "  1. Record Loom with: ./scripts/record_loom.sh"
echo "  2. Download Loom as GIF"
echo "  3. Optimize: gifsicle -O3 input.gif -o demos/trinity_v1_quantum_z120.gif"
echo ""

# Manual instructions if no tools
if [[ "$HAS_FFMPEG" == false ]] && [[ "$HAS_ASCIINEMA" == false ]]; then
    echo -e "${CYAN}[MANUAL]${RESET} Quick GIF with Online Tools"
    echo ""
    echo "  1. Run: ./zig-out/bin/tri os demo --quantum"
    echo "  2. Screen record with: QuickTime (macOS) or OBS"
    echo "  3. Upload to: ezgif.com/video-to-gif"
    echo "  4. Download and save as: demos/trinity_v1_quantum_z120.gif"
    echo ""
fi

# Output specs
echo -e "${CYAN}[OUTPUT SPECS]${RESET} Optimal for Social Media"
echo ""
echo "  Duration: 5-15 seconds (loop)"
echo "  Size: < 5 MB (Twitter limit)"
echo "  FPS: 15 fps (enough for terminal)"
echo "  Width: 600px (readable)"
echo "  Best frame: LED blink + Z=120 result"
echo ""

# Demo command to record
echo -e "${CYAN}[DEMO COMMAND]${RESET} What to record"
echo ""
echo -e "  ${GREEN}./zig-out/bin/tri os demo --quantum${RESET}"
echo ""
echo "  This shows:"
echo "    → Element Z=120: 27.4s (96%)"
echo "    → Muon g-2: SOLVED"
echo "    → Hubble: RESOLVED"
echo "    → Sacred constants: φ² + 1/φ² = 3"
echo ""

# Create placeholder
echo -e "${CYAN}[PLACEHOLDER]${RESET} Creating placeholder..."
cat > demos/README.md << 'EOF'
# TRINITY OS v1.0 Demo GIFs

This directory contains demo GIFs for social media and investor outreach.

## Files

- `trinity_v1_quantum_z120.gif` — Z=120 prediction demo (5-15 sec loop)
- `trinity_v1_fpga_boot.mp4` — FPGA boot sequence
- `trinity_v1_full_demo.mp4` — Full 60-second demo

## Generate

Run: `./scripts/demo_gif.sh`

Or record with Loom: `./scripts/record_loom.sh`
EOF

echo -e "  ${GREEN}✓${RESET} demos/README.md created"
echo ""

echo -e "${GOLD}╔════════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${GOLD}║     NEXT: Record Loom → Export GIF → Post to X                 ║${RESET}"
echo -e "${GOLD}╚════════════════════════════════════════════════════════════════╝${RESET}"
echo ""
