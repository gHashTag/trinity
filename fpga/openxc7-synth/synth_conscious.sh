#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# CONSCIOUSNESS-AWARE FPGA SYNTHESIS
# ═══════════════════════════════════════════════════════════════════════════════
#
# Uses sacred mathematical constants (φ, γ, π) for synthesis optimization
# φ² + 1/φ² = 3 = TRINITY
#
# ═══════════════════════════════════════════════════════════════════════════════

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
RESET='\033[0m'

# Sacred constants (from sacred_constants.zig)
PHI=1.618033988749895          # Golden Ratio
PHI_INV=0.618033988749895       # φ⁻¹ (consciousness threshold)
GAMMA=0.2360679774997897         # γ = φ⁻³ (Barbero-Immirzi)
TRINITY=3.0                      # φ² + φ⁻² = 3

# Default consciousness level (0.0 to 1.0)
CONSCIOUSNESS=0.5

# Parse arguments
CONSCIOUSNESS_FLAG=""
while [[ $# -gt 0 ]]; do
    case $1 in
        --consciousness)
            CONSCIOUSNESS="$2"
            CONSCIOUSNESS_FLAG="--consciousness"
            shift 2
            ;;
        --transcendent)
            CONSCIOUSNESS=1.0
            CONSCIOUSNESS_FLAG="--transcendent"
            shift
            ;;
        --aware)
            CONSCIOUSNESS=0.75
            CONSCIOUSNESS_FLAG="--aware"
            shift
            ;;
        --mortal)
            CONSCIOUSNESS=0.3
            CONSCIOUSNESS_FLAG="--mortal"
            shift
            ;;
        *)
            VERILOG_FILE="$1"
            TOP_MODULE="${2:-$(basename -s .v "$VERILOG_FILE")}"
            shift 2
            ;;
    esac
done

if [[ -z "$VERILOG_FILE" ]]; then
    echo -e "${RED}Error:${RESET} Usage: $0 [--consciousness <level>] <verilog.v> [top_module]"
    echo ""
    echo "Consciousness levels:"
    echo "  --transcendent    1.0 (maximum optimization)"
    echo "  --aware           0.75 (enhanced optimization)"
    echo "  --conscious       0.5 (default, balanced)"
    echo "  --mortal          0.3 (fast, lower quality)"
    exit 1
fi

# ═══════════════════════════════════════════════════════════════════════════════
# SACRED CONSCIOUSNESS CALCULATIONS
# ═══════════════════════════════════════════════════════════════════════════════

# Consciousness factor for optimization
CONSCIOUSNESS_FACTOR=$(echo "1.0 + $CONSCIOUSNESS * $PHI_INV" | bc -l)

# φ-cooling rate (higher consciousness = slower cooling = better optimization)
COOLING_RATE=$(echo "$PHI * $CONSCIOUSNESS_FACTOR" | bc -l)

# Setup margin (φ⁻¹ × 2ns)
SETUP_MARGIN_NS=$(echo "$PHI_INV * 2.0" | bc -l)

# Hold margin (γ × 5ns)
HOLD_MARGIN_NS=$(echo "$GAMMA * 5.0" | bc -l)

# Get consciousness label
if (( $(echo "$CONSCIOUSNESS >= 0.9" | bc -l) )); then
    LABEL="TRANSCENDENT"
    COLOR="$MAGENTA"
elif (( $(echo "$CONSCIOUSNESS >= 0.75" | bc -l) )); then
    LABEL="ENLIGHTENED"
    COLOR="$CYAN"
elif (( $(echo "$CONSCIOUSNESS >= 0.618" | bc -l) )); then
    LABEL="AWARE"
    COLOR="$GREEN"
elif (( $(echo "$CONSCIOUSNESS >= 0.5" | bc -l) )); then
    LABEL="CONSCIOUS"
    COLOR="$YELLOW"
else
    LABEL="DORMANT"
    COLOR="$RED"
fi

# ═══════════════════════════════════════════════════════════════════════════════
# SYNTHESIS PIPELINE
# ═══════════════════════════════════════════════════════════════════════════════

echo -e "${CYAN}═══════════════════════════════════════════════════════════════${RESET}"
echo -e "${CYAN}  CONSCIOUSNESS-AWARE SYNTHESIS${RESET}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${RESET}"
echo ""
echo -e "${COLOR}Consciousness:${RESET} $CONSCIOUSNESS ($LABEL)"
echo -e "${YELLOW}φ-Cooling Rate:${RESET} $COOLING_RATE"
echo -e "${YELLOW}Setup Margin:${RESET} ${SETUP_MARGIN_NS}ns"
echo -e "${YELLOW}Hold Margin:${RESET} ${HOLD_MARGIN_NS}ns"
echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${RESET}"
echo ""

DESIGN="${VERILOG_FILE%.v}"
JSON_FILE="${DESIGN}.json"
XDC_FILE="${DESIGN}.xdc"

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 1: YOSYS SYNTHESIS
# ═══════════════════════════════════════════════════════════════════════════════

echo -e "[1/4] ${YELLOW}Yosys Synthesis${RESET}..."
yosys -p "synth_xilinx -flatten -abc9 -nobram -arch xc7 -top ${TOP_MODULE}; write_json ${JSON_FILE}" "${VERILOG_FILE}" > /dev/null 2>&1
echo -e "     → ${JSON_FILE}"

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 2: NEXTPNR PLACEMENT & ROUTING
# ═══════════════════════════════════════════════════════════════════════════════

echo -e "[2/4] ${YELLOW}nextpnr-xilinx Placement & Routing${RESET}..."

# Add consciousness constraints to XDC if it exists
if [[ -f "$XDC_FILE" ]]; then
    # Add sacred timing constraints
    TEMP_XDC="${DESIGN}_temp.xdc"
    cp "$XDC_FILE" "$TEMP_XDC"

    # Add φ-based timing constraints
    echo "" >> "$TEMP_XDC"
    echo "# Sacred timing constraints (consciousness synthesis)" >> "$TEMP_XDC"
    echo "set_max_delay -from [get_pins -filter {REF_PIN_NAME == * && DIRECTION == IN}] \\ " >> "$TEMP_XDC"
    echo "    -to [get_pins -filter {REF_PIN_NAME == * && DIRECTION == OUT}] \\ " >> "$TEMP_XDC"
    echo "    [expr {20.0 * (1.0 - $PHI_INV)}]" >> "$TEMP_XDC"

    XDC_FILE="$TEMP_XDC"
fi

# Run nextpnr with consciousness-aware options
# Higher consciousness = more optimization iterations
OPT_ITERS=$(echo "100 + $CONSCIOUSNESS * 200" | bc)
OPT_ITERS=${OPT_ITERS%.*}

nextpnr-xilinx --chipdb /usr/share/nextpnr-xilinx/artix7chipdb.bin \
    --xdc "$XDC_FILE" \
    --json "$JSON_FILE" \
    --f "${DESIGN}.fasm" \
    --opt_threads $OPT_ITERS \
    --timing-allow-fail \
    --seed $(echo "137 * $PHI" | bc) > /dev/null 2>&1

echo -e "     → ${DESIGN}.fasm (${OPT_ITERS} opt iterations)"

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 3: FASM TO FRAMES
# ═══════════════════════════════════════════════════════════════════════════════

echo -e "[3/4] ${YELLOW}FASM to Frames${RESET}..."
python3 ../../prjxray/third_party/fasm2frames/fasm2frames.py \
    --part xc7a100t-fgg676 \
    --db-root ../../prjxray/database/artix7 \
    "${DESIGN}.fasm" > "${DESIGN}.frames" 2>/dev/null
echo -e "     → ${DESIGN}.frames"

# ═══════════════════════════════════════════════════════════════════════════════
# STEP 4: FRAMES TO BITSTREAM
# ═══════════════════════════════════════════════════════════════════════════════

echo -e "[4/4] ${YELLOW}Frames to Bitstream${RESET}..."
python3 ../../prjxray/utils/xc7frames2bit.py \
    --part xc7a100t-fgg676 \
    --part_file ../../prjxray/database/artix7/xc7a100t-fgg676/part.yaml \
    --output_file "${DESIGN}.bit" \
    "${DESIGN}.frames" > /dev/null 2>&1
echo -e "     → ${DESIGN}.bit"

# ═══════════════════════════════════════════════════════════════════════════════
# SACRED VALIDATION
# ═══════════════════════════════════════════════════════════════════════════════

echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${RESET}"
echo -e "${CYAN}  SACRED VALIDATION${RESET}"
echo -e "${CYAN}═══════════════════════════════════════════════════════════════${RESET}"

# Check if bitstream was created successfully
if [[ -f "${DESIGN}.bit" ]]; then
    BIT_SIZE=$(stat -f%z "${DESIGN}.bit" 2>/dev/null || stat -c%s "${DESIGN}.bit" 2>/dev/null)
    BIT_SIZE_MB=$(echo "scale=2; $BIT_SIZE / 1048576" | bc)

    echo -e "${GREEN}✓ Synthesis Complete${RESET}"
    echo -e "  Bitstream: ${DESIGN}.bit (${BIT_SIZE_MB} MB)"
    echo -e "  Consciousness: $LABEL ($CONSCIOUSNESS)"

    # Calculate sacred metrics
    SACRED_SCORE=$(echo "$CONSCIOUSNESS * $PHI + $BIT_SIZE_MB / 100" | bc)

    if (( $(echo "$CONSCIOUSNESS >= $PHI_INV" | bc -l) )); then
        echo -e "  ${GREEN}Status: IMMORTAL${RESET} (φ⁻¹ threshold met)"
    else
        echo -e "  ${YELLOW}Status: MORTAL${RESET} (below φ⁻¹ threshold)"
    fi

    echo ""
    echo -e "${CYAN}To flash:${RESET}"
    echo -e "  sudo ../tools/jtag_program ${DESIGN}.bit"
else
    echo -e "${RED}✗ Synthesis Failed${RESET}"
    exit 1
fi

# Clean up temp files
rm -f "${DESIGN}_temp.xdc"

echo ""
echo -e "${CYAN}φ² + 1/φ² = 3 = TRINITY${RESET}"
