#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════════════════
# TRINITY FPGA Flash Script v1.0 — Lattice iCE40 Hardware Deployment
# ═══════════════════════════════════════════════════════════════════════════════
# Usage: ./scripts/flash_fpga.sh [--target=ice40-hx8k|fomu] [--verify]
# Output: TRINITY OS v1.0 on hardware with LED feedback
# ═══════════════════════════════════════════════════════════════════════════════

set -e

# Colors
GOLD="\x1b[33m"
GREEN="\x1b[32m"
CYAN="\x1b[36m"
MAGENTA="\x1b[35m"
BOLD="\x1b[1m"
RESET="\x1b[0m"

# Defaults
TARGET="${TARGET:-ice40-hx8k}"
BITSTREAM="${BITSTREAM:-build/trinity_os_v1_0.ice}"
VERIFY="${VERIFY:-true}"

# Parse args
for arg in "$@"; do
    case "$arg" in
        --target=*) TARGET="${arg#*=}" ;;
        --bitstream=*) BITSTREAM="${arg#*=}" ;;
        --no-verify) VERIFY=false ;;
        --help) cat <<'EOF'
TRINITY FPGA Flash Script v1.0

Usage: ./scripts/flash_fpga.sh [OPTIONS]

Options:
  --target=ice40-hx8k|fomu   FPGA board (default: ice40-hx8k)
  --bitstream=PATH          Bitstream file (default: build/trinity_os_v1_0.ice)
  --no-verify               Skip CRC verification
  --help                    Show this help

Hardware:
  Lattice iCE40-HX8K: $12 development board
  Lattice iCE40-UP5K: $15 (Fomu VTAB)
  Fomu: $25 USB-C FPGA

Tools Required:
  iceprog  - for iCE40 boards
  dfu-util - for Fomu boards

Output:
  LED blinks φ pattern (1.618 Hz) on success
  UART terminal shows TRINITY OS v1.0 boot banner
EOF
exit 0 ;;
    esac
done

echo -e "${GOLD}${BOLD}╔════════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${GOLD}${BOLD}║     TRINITY FPGA FLASH v1.0 — Hardware Deployment            ║${RESET}"
echo -e "${GOLD}${BOLD}╚════════════════════════════════════════════════════════════════╝${RESET}"
echo ""

# Check bitstream exists
if [ ! -f "$BITSTREAM" ]; then
    echo -e "${CYAN}[ERROR]${RESET} Bitstream not found: $BITSTREAM"
    echo -e "${CYAN}[INFO]${RESET} Run 'zig build fpga-demo' first"
    exit 1
fi

# Show bitstream info
FILE_SIZE=$(stat -f%z "$BITSTREAM" 2>/dev/null || stat -c%s "$BITSTREAM" 2>/dev/null)
FILE_SIZE_KB=$((FILE_SIZE / 1024))
echo -e "${CYAN}[BITSTREAM]${RESET} $BITSTREAM"
echo -e "  Size: ${FILE_SIZE_KB} KB"
echo ""

# Detect programmer
if [ "$TARGET" = "fomu" ]; then
    PROGRAMMER="dfu-util"
    DEVICE_ID="1d50:613d"

    # Check dfu-util
    if ! command -v dfu-util &> /dev/null; then
        echo -e "${CYAN}[ERROR]${RESET} dfu-util not found"
        echo -e "${CYAN}[INSTALL]${RESET} brew install dfu-util"
        exit 1
    fi

    echo -e "${GREEN}[STEP 1]${RESET} Flashing to Fomu (USB-C FPGA)..."
    dfu-util -d "$DEVICE_ID" -D "$BITSTREAM"

    if [ "$VERIFY" = true ]; then
        echo -e "${GREEN}[STEP 2]${RESET} Verifying via USB CDC..."
        # Fomu shows up as CDC-ACM device
        sleep 2
        if ls /dev/cu.usbmodem* &> /dev/null; then
            echo -e "${GREEN}[OK]${RESET} Fomu USB CDC detected"
        else
            echo -e "${CYAN}[WARN]${RESET} USB CDC not detected (may need reset)"
        fi
    fi

else
    PROGRAMMER="iceprog"

    # Check iceprog
    if ! command -v iceprog &> /dev/null; then
        echo -e "${CYAN}[ERROR]${RESET} iceprog not found"
        echo -e "${CYAN}[INSTALL]${RESET} brew install icestorm"
        exit 1
    fi

    echo -e "${GREEN}[STEP 1]${RESET} Flashing to iCE40-$TARGET..."
    iceprog -w "$BITSTREAM"

    if [ "$VERIFY" = true ]; then
        echo -e "${GREEN}[STEP 2]${RESET} Verifying CRC..."
        iceprog -c "$BITSTREAM" && echo -e "${GREEN}[OK]${RESET} CRC verified" || echo -e "${CYAN}[WARN]${RESET} CRC check failed"
    fi
fi

echo ""
echo -e "${GOLD}${BOLD}╔════════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${GOLD}${BOLD}║     FLASH COMPLETE                                             ║${RESET}"
echo -e "${GOLD}${BOLD}╚════════════════════════════════════════════════════════════════╝${RESET}"
echo ""
echo -e "${CYAN}[DEMO]${RESET} Look for LED feedback:"
echo -e "  → ${GREEN}φ pattern${RESET} (1.618 Hz blink) = TRINITY OS booted"
echo -e "  → ${GREEN}TRI pattern${RESET} (3 LED sequence) = Sacred opcodes active"
echo -e "  → ${GREEN}Heartbeat${RESET} (0.5 Hz pulse) = KOSCHEI omniscience"
echo ""
echo -e "${CYAN}[TERMINAL]${RESET} Connect UART for live shell:"
echo -e "  screen /dev/cu.usbserial* 115200"
echo -e "  or: picocom -b 115200 /dev/cu.usbserial*"
echo ""
echo -e "${MAGENTA}φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS THE OPERATING SYSTEM${RESET}"
echo ""
