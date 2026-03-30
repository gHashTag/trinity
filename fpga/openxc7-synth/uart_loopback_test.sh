#!/bin/bash
# ═════════════════════════════════════════════════════════════════════════
# UART LOOPBACK TEST — Day 1
#
# Tests UART cable without FPGA!
# Just short TX-RX on the USB-UART adapter.
# ═════════════════════════════════════════════════════════════════════════

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
UART_HOST="$SCRIPT_DIR/uart_host_v2"
UART_DEVICE="/dev/ttyUSB0"
BAUD_RATE=115200

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║     UART LOOPBACK TEST — Day 1                               ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

# Check binary exists
if [ ! -f "$UART_HOST" ]; then
    echo "❌ uart_host_v2 not found. Compiling..."
    cd "$SCRIPT_DIR"
    zig build-exe uart_host_v2.zig -O ReleaseFast
fi

echo "📡 TEST CONFIGURATION:"
echo "   Device:   $UART_DEVICE"
echo "   Baud:     $BAUD_RATE"
echo "   Binary:   $UART_HOST"
echo ""
echo "═══════════════════════════════════════════════════════════════"
echo ""

# Check if device exists
if [ ! -e "$UART_DEVICE" ]; then
    echo "❌ UART device not found: $UART_DEVICE"
    echo ""
    echo "Troubleshooting:"
    echo "  1. Connect USB-UART adapter"
    echo "  2. Check: ls -la /dev/tty.usb*"
    echo "  3. You might need: sudo chmod 666 $UART_DEVICE"
    exit 1
fi

# Set baud rate
echo "⚙️  Configuring baud rate..."
stty -f "$UART_DEVICE" $BAUD_RATE cs8 -cstopb -parenb 2>/dev/null || true

# Get device info
echo "📎 Device info:"
ls -la "$UART_DEVICE" 2>/dev/null || echo "   (permission check skipped)"

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo ""
echo "⚠️  HARDWARE SETUP REQUIRED:"
echo "   Short TX and RX on your USB-UART adapter!"
echo ""
echo "   ┌─────────────────┐"
echo "   │  USB-UART       │"
echo "   │  ┌───┐ ┌───┐    │"
echo "   │  │TX├─┼RX │    │  ← SHORT THESE!"
echo "   │  └───┘ └───┘    │"
echo "   └─────────────────┘"
echo ""
echo "═══════════════════════════════════════════════════════════════"
echo ""

read -p "Press ENTER when TX-RX are shorted..."

echo ""
echo "🚀 RUNNING LOOPBACK TEST..."
echo ""

# Run the test
"$UART_HOST" loopback

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo ""

if [ $? -eq 0 ]; then
    echo "✅ LOOPBACK TEST PASSED!"
    echo ""
    echo "Your UART cable is working correctly."
    echo "Ready for FPGA communication!"
else
    echo "❌ LOOPBACK TEST FAILED!"
    echo ""
    echo "Check:"
    echo "  1. TX-RX are properly shorted"
    echo "  2. Device permissions: ls -la $UART_DEVICE"
    echo "  3. Baud rate matches: $BAUD_RATE"
fi

echo ""
echo "φ² + 1/φ² = 3 = TRINITY"
