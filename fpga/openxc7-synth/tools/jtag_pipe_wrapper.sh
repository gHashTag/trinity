#!/bin/bash
# ═══════════════════════════════════════════════════════════════════════════════
# TRINITY FPGA — JTAG UART Pipe Wrapper
# ═══════════════════════════════════════════════════════════════════════════════
#
# Creates bidirectional pipe communication with FPGA via JTAG
#
# Usage: ./tools/jtag_pipe_wrapper.sh
# ═══════════════════════════════════════════════════════════════════════════════

set -e

#===============================================================================
# CONFIGURATION
#===============================================================================

PIPE_DIR="/tmp/trinity_jtag"
PIPE_TX="$PIPE_DIR/tx"
PIPE_RX="$PIPE_DIR/rx"
PID_FILE="$PIPE_DIR/openocd.pid"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

#===============================================================================
# CLEANUP FUNCTION
#===============================================================================

cleanup() {
    echo -e "${YELLOW}Shutting down JTAG UART...${NC}"

    # Kill OpenOCD if running
    if [ -f "$PID_FILE" ]; then
        kill $(cat "$PID_FILE") 2>/dev/null || true
        rm -f "$PID_FILE"
    fi

    # Remove pipes
    rm -f "$PIPE_TX" "$PIPE_RX"
    rmdir "$PIPE_DIR" 2>/dev/null || true

    echo -e "${GREEN}JTAG UART stopped.${NC}"
}

trap cleanup EXIT INT TERM

#===============================================================================
# CREATE PIPES
#===============================================================================

echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  TRINITY JTAG UART Pipe Wrapper${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""

# Create pipe directory
mkdir -p "$PIPE_DIR"

# Create named pipes
if [ ! -p "$PIPE_TX" ]; then
    mkfifo "$PIPE_TX"
    echo -e "${GREEN}Created TX pipe: $PIPE_TX${NC}"
fi

if [ ! -p "$PIPE_RX" ]; then
    mkfifo "$PIPE_RX"
    echo -e "${GREEN}Created RX pipe: $PIPE_RX${NC}"
fi

#===============================================================================
# CHECK FOR OPENOCD
#===============================================================================

if ! command -v openocd &> /dev/null; then
    echo -e "${RED}Error: openocd not found!${NC}"
    echo "Install with: brew install openocd"
    exit 1
fi

echo -e "${GREEN}OpenOCD found: $(openocd --version 2>&1 | head -n1)${NC}"

#===============================================================================
# CHECK FOR JTAG CABLE
#===============================================================================

echo ""
echo "Checking for JTAG cable..."

# Try to detect JTAG cable
if openocd -f interface/ftdi.cfg -c "init; scan_chain" -c "shutdown" 2>&1 | grep -q "0x0372"; then
    echo -e "${GREEN}✓ Xilinx Artix-7 detected!${NC}"
elif openocd -f interface/ftdi.cfg -c "init; scan_chain" -c "shutdown" 2>&1 | grep -q "tap"; then
    echo -e "${GREEN}✓ JTAG chain detected!${NC}"
else
    echo -e "${YELLOW}⚠ No JTAG device detected (may be normal if cable not connected)${NC}"
fi

#===============================================================================
# START OPENOCD IN BACKGROUND
#===============================================================================

echo ""
echo "Starting OpenOCD with pipe interface..."

# Start OpenOCD with our config
openocd -f openocd/qmtech_jtag.cfg \
    -c "jtag_uart_init" \
    > "$PIPE_DIR/openocd.log" 2>&1 &

OPENOCD_PID=$!
echo $OPENOCD_PID > "$PID_FILE"

sleep 2

# Check if OpenOCD is still running
if ! kill -0 $OPENOCD_PID 2>/dev/null; then
    echo -e "${RED}Error: OpenOCD failed to start!${NC}"
    echo "Check log: $PIPE_DIR/openocd.log"
    cat "$PIPE_DIR/openocd.log"
    exit 1
fi

echo -e "${GREEN}✓ OpenOCD running (PID: $OPENOCD_PID)${NC}"

#===============================================================================
# PIPE BRIDGE
#===============================================================================

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  JTAG UART Active${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""
echo "Pipes:"
echo "  TX: $PIPE_TX"
echo "  RX: $PIPE_RX"
echo ""
echo "Usage:"
echo "  Send:   echo \"PING\" > $PIPE_TX"
echo "  Receive: cat $PIPE_RX"
echo ""
echo -e "${YELLOW}Press Ctrl+C to stop${NC}"
echo ""

# Simple bridge loop (for testing)
while true; do
    # Check if pipes have data
    if [ -p "$PIPE_TX" ]; then
        # Read from TX pipe and send to OpenOCD
        if read -r -t 0.1 line < "$PIPE_TX"; then
            echo -e "${GREEN}→ TX: $line${NC}"

            # Convert hex/string to bytes and send via OpenOCD
            # For now, just echo the command
            openocd -f openocd/qmtech_jtag.cfg \
                -c "jtag_uart_puts \"$line\"" \
                -c "shutdown" 2>/dev/null || true
        fi
    fi

    sleep 0.1
done
