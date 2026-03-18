#!/bin/bash
# Trinity FPGA Flash via XVC + Vivado (Fly.io)
# Platform Cable USB II → xvcd (local) → ngrok → Vivado (Fly.io) → FPGA
#
# Usage: sudo bash fpga/xvc_flash.sh
#
# Prerequisites:
#   - Platform Cable USB II connected (PID 0x0008, firmware loaded)
#   - ngrok installed and configured (ngrok config add-authtoken ...)
#   - Fly.io app vivado-synth running with Vivado installed
#   - Bitstream at fpga/fly-vivado/output/trinity_qmtech.bit

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
XVCD="$SCRIPT_DIR/tools/xvcd"
FXLOAD="$SCRIPT_DIR/tools/fxload"
FIRMWARE="$SCRIPT_DIR/tools/xusb_xp2.hex"

echo "═══════════════════════════════════════════════"
echo " TRINITY FPGA FLASH (XVC + Vivado)"
echo " Target:    QMTECH XC7A100T Core Board"
echo " Cable:     Platform Cable USB II → xvcd → ngrok → Vivado"
echo "═══════════════════════════════════════════════"
echo ""

# Check sudo
if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: Requires sudo for USB access."
    echo "Run: sudo bash $0"
    exit 1
fi

# Step 0: Load firmware if needed
if system_profiler SPUSBDataType 2>/dev/null | grep -q "Product ID: 0x0013"; then
    echo "[0] Loading Platform Cable firmware..."
    "$FXLOAD" -v -t fx2 -d 03fd:0013 -i "$FIRMWARE" 2>&1
    echo "  Waiting for re-enumeration..."
    for i in $(seq 1 10); do
        sleep 1
        if system_profiler SPUSBDataType 2>/dev/null | grep -q "Product ID: 0x0008"; then
            echo "  Cable ready (PID=0x0008) after ${i}s"
            break
        fi
        [ "$i" = "10" ] && echo "  WARNING: Cable not detected after 10s"
    done
elif system_profiler SPUSBDataType 2>/dev/null | grep -q "Product ID: 0x0008"; then
    echo "[0] Platform Cable ready (PID=0x0008)"
else
    echo "ERROR: Platform Cable USB II not detected!"
    exit 1
fi

# Step 1: Start XVC server
echo ""
echo "[1/3] Starting XVC server on port 2542..."
pkill -f xvcd 2>/dev/null || true
sleep 1

"$XVCD" &
XVCD_PID=$!
sleep 2

if ! kill -0 $XVCD_PID 2>/dev/null; then
    echo "ERROR: xvcd failed to start"
    exit 1
fi
echo "  XVC server running (PID=$XVCD_PID)"

# Step 2: Start ngrok tunnel
echo ""
echo "[2/3] Starting ngrok tunnel..."
pkill -f "ngrok tcp" 2>/dev/null || true
sleep 1

ngrok tcp 2542 --log=stdout --log-format=json > /tmp/ngrok_xvc.log 2>&1 &
NGROK_PID=$!
sleep 3

# Get ngrok public URL
NGROK_URL=""
for i in $(seq 1 10); do
    NGROK_URL=$(curl -s http://localhost:4040/api/tunnels 2>/dev/null | python3 -c "import sys,json; t=json.load(sys.stdin)['tunnels']; print(t[0]['public_url'].replace('tcp://',''))" 2>/dev/null)
    if [ -n "$NGROK_URL" ]; then
        break
    fi
    sleep 1
done

if [ -z "$NGROK_URL" ]; then
    echo "ERROR: Could not get ngrok URL"
    echo "Check: ngrok config add-authtoken <your-token>"
    kill $XVCD_PID 2>/dev/null
    kill $NGROK_PID 2>/dev/null
    exit 1
fi

echo "  ngrok tunnel: $NGROK_URL → localhost:2542"

# Step 3: Upload bitstream to Fly.io and program via Vivado
echo ""
echo "[3/3] Programming FPGA via Vivado on Fly.io..."
echo "  XVC URL: $NGROK_URL"

# Create Vivado TCL script for XVC programming
FLASH_TCL="
puts \"INFO: Connecting to XVC server at ${NGROK_URL}...\"
open_hw_manager
connect_hw_server
open_hw_target -xvc_url ${NGROK_URL}

set devices [get_hw_devices]
puts \"INFO: Found devices: \$devices\"

if {[llength \$devices] == 0} {
    puts \"ERROR: No devices found on XVC target\"
    exit 1
}

set device [lindex \$devices 0]
puts \"INFO: Programming device: \$device\"

set_property PROGRAM.FILE {/workspace/output/trinity_qmtech.bit} \$device
program_hw_devices \$device

puts \"\"
puts \"SUCCESS: FPGA programmed via XVC!\"
puts \"TRINITY LIVES IN SILICON. phi^2 + 1/phi^2 = 3\"

close_hw_target
disconnect_hw_server
close_hw_manager
exit
"

# Upload TCL to Fly.io and run
flyctl ssh console -a vivado-synth -C "bash -c 'cat > /tmp/flash_xvc.tcl << \"TCEOF\"
${FLASH_TCL}
TCEOF
source /vivado/Vivado/2025.2/2025.2/Vivado/settings64.sh && vivado -mode batch -source /tmp/flash_xvc.tcl 2>&1'" 2>&1

RESULT=$?

# Cleanup
echo ""
echo "Cleaning up..."
kill $NGROK_PID 2>/dev/null || true
kill $XVCD_PID 2>/dev/null || true

if [ $RESULT -eq 0 ]; then
    echo ""
    echo "═══════════════════════════════════════════════"
    echo " FLASH COMPLETE — TRINITY LIVES IN SILICON"
    echo " φ² + 1/φ² = 3"
    echo "═══════════════════════════════════════════════"
else
    echo ""
    echo "═══════════════════════════════════════════════"
    echo " FLASH FAILED"
    echo " Check ngrok tunnel and try again"
    echo "═══════════════════════════════════════════════"
    exit 1
fi
