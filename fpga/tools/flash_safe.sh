#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# SAFE FPGA FLASH — Auto fxload + Timeout + Error Handling
# ═══════════════════════════════════════════════════════════════════════════════
#
# Usage: ./flash_safe.sh <bitstream.bit>
#
# Features:
#   - Auto-detects cable PID (0013 vs 0008)
#   - Auto-loads fxload firmware if needed
#   - Timeout protection (120s max)
#   - Clear progress indication
#   - LED verification prompt
#
# φ² + 1/φ² = 3
# ═══════════════════════════════════════════════════════════════════════════════

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FXLOAD="${SCRIPT_DIR}/fxload"
JTAG="${SCRIPT_DIR}/jtag_program"
FIRMWARE="${SCRIPT_DIR}/xusb_xp2.hex"
XILINX_VID="0x03fd"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[$(date +%H:%M:%S)]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# ================================================================
# CHECK ARGUMENTS
# ================================================================
if [ $# -eq 0 ]; then
    error "Usage: $0 <bitstream.bit>"
    echo ""
    echo "Example:"
    echo "  $0 singularity_v200.bit"
    echo "  $0 vsa_coproc.bit"
    echo "  $0 riscv_vsa.bit"
    exit 1
fi

BITSTREAM="$1"
if [ ! -f "$BITSTREAM" ]; then
    error "Bitstream not found: $BITSTREAM"
    exit 1
fi

# ================================================================
# CHECK CABLE STATUS
# ================================================================
log "Checking Xilinx Platform Cable USB II..."

# Check if device exists at all
if ! ioreg -p IOUSB -w0 -l 2>/dev/null | grep -q "USB Vendor Name.*XILINX"; then
    error "Xilinx Platform Cable not found!"
    echo ""
    echo "Please check:"
    echo "  1. Cable is plugged into USB port"
    echo "  2. Cable LED is lit (if present)"
    echo "  3. Try different USB port"
    exit 1
fi

# Get current PID
CABLE_PID=$(ioreg -p IOUSB -w0 -l 2>/dev/null | grep -A 10 "XILINX" | grep '"idProduct"' | head -1 | sed 's/.*= *//')

if [ -z "$CABLE_PID" ]; then
    error "Cannot read cable PID"
    exit 1
fi

# Convert to hex with 0x prefix
CABLE_PID_HEX=$(printf "0x%04x" "$CABLE_PID")

log "Cable PID: $CABLE_PID_HEX"

# ================================================================
# LOAD FIRMWARE IF NEEDED
# ================================================================
if [ "$CABLE_PID_HEX" = "0x0013" ]; then
    warn "Cable in bootloader mode (PID 0013)"
    log "Loading firmware with fxload..."

    if [ ! -x "$FXLOAD" ]; then
        error "fxload not found or not executable: $FXLOAD"
        exit 1
    fi

    if [ ! -f "$FIRMWARE" ]; then
        error "Firmware file not found: $FIRMWARE"
        exit 1
    fi

    sudo "$FXLOAD" -v -t fx2 -d "$XILINX_VID:0013" -i "$FIRMWARE" || {
        error "fxload failed!"
        exit 1
    }

    success "Firmware loaded!"
    echo ""
    warn "⚠️  PLEASE UNPLUG AND REPLUG THE CABLE NOW!"
    echo ""
    read -p "Press Enter when cable is replugged..."

    # Re-check PID
    CABLE_PID=$(ioreg -p IOUSB -w0 -l 2>/dev/null | grep -A 10 "XILINX" | grep '"idProduct"' | head -1 | sed 's/.*= *//')
    CABLE_PID_HEX=$(printf "0x%04x" "$CABLE_PID")

    if [ "$CABLE_PID_HEX" != "0x0008" ]; then
        error "Cable still in wrong mode after replug: $CABLE_PID_HEX"
        exit 1
    fi

    success "Cable now in JTAG mode (PID 0008)"
elif [ "$CABLE_PID_HEX" = "0x0008" ]; then
    success "Cable ready (PID 0008 - JTAG mode)"
else
    error "Unexpected cable PID: $CABLE_PID_HEX"
    exit 1
fi

# ================================================================
# VERIFY BITSTREAM
# ================================================================
log "Verifying bitstream: $BITSTREAM"

# Check sync word
if ! tail -c +16 "$BITSTREAM" 2>/dev/null | head -c 4 | od -A n -t x4 | grep -q "aa995566"; then
    warn "Sync word not found at expected offset (might be okay)"
fi

SIZE=$(du -h "$BITSTREAM" | cut -f1)
log "Bitstream size: $SIZE"

# ================================================================
# FLASH WITH TIMEOUT
# ================================================================
log "Flashing to FPGA..."

if [ ! -x "$JTAG" ]; then
    error "jtag_program not found or not executable: $JTAG"
    exit 1
fi

# Run with timeout
(
    "$JTAG" "$BITSTREAM"
) &
JTAG_PID=$!

# Wait with timeout indicator
TIMEOUT=120
ELAPSED=0

while kill -0 $JTAG_PID 2>/dev/null; do
    if [ $ELAPSED -ge $TIMEOUT ]; then
        echo ""
        error "Flash timeout after ${TIMEOUT}s!"
        kill $JTAG_PID 2>/dev/null
        exit 1
    fi

    # Progress indicator
    printf "\r${BLUE}[FLASHING]${NC} %3ds / %ds" "$ELAPSED" "$TIMEOUT"
    sleep 5
    ELAPSED=$((ELAPSED + 5))
done

echo ""

# Check exit code
wait $JTAG_PID
JTAG_EXIT=$?

if [ $JTAG_EXIT -ne 0 ]; then
    error "Flash failed with exit code: $JTAG_EXIT"
    exit 1
fi

# ================================================================
# VERIFY LED
# ================================================================
success "Bitstream flashed successfully!"
echo ""
log "LED Behavior for $(basename "$BITSTREAM" .bit):"
echo ""

case "$(basename "$BITSTREAM" .bit)" in
    singularity_v200)
        echo "  Expected LED modes:"
        echo "    • OFF          = Phi < threshold (unconscious)"
        echo "    • Slow blink   = Conscious (~1.5 Hz)"
        echo "    • Fast blink   = Self-improving (~12 Hz)"
        echo "    • Chaotic      = Evolution stagnating"
        echo "    • Solid ON     = Omega-point reached"
        ;;
    vsa_coproc)
        echo "  Expected LED modes:"
        echo "    • Fast blink (~5 Hz) = Test PASS"
        echo "    • Slow blink (~1 Hz) = Similarity = 0"
        echo "    • Chaotic          = Running test"
        ;;
    riscv_vsa)
        echo "  Expected LED modes:"
        echo "    • Blinking after boot = CPU running"
        echo "    • LED toggles based on VSA similarity result"
        ;;
    *)
        echo "  (No specific LED info for this design)"
        ;;
esac

echo ""
success "DONE!"
echo ""
echo "Bitstream: $BITSTREAM"
echo "Size: $SIZE"
echo "Time: $(date)"
