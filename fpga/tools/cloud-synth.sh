#!/bin/bash
# cloud-synth.sh — Client for fly.io FPGA synthesis
# Usage: ./cloud-synth.sh <design.v> [top_module]

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FLY_APP="${FLY_APP:-trinity-fpga-synth}"

# Check flyctl
if ! command -v flyctl &> /dev/null; then
    echo "Error: flyctl not found"
    echo "Install: curl -L https://fly.io/install.sh | sh"
    exit 1
fi

# Get app URL
APP_URL=$(flyctl info -a "$FLY_APP" --json 2>/dev/null | grep -o '"Hostname":"[^"]*"' | cut -d'"' -f4 | head -1)

if [ -z "$APP_URL" ]; then
    echo "Error: Cannot get app URL. Is '$FLY_APP' deployed?"
    echo "Deploy first: fly deploy -c fpga/openxc7-synth/fly.toml"
    exit 1
fi

API_URL="https://$APP_URL/synthesize"
echo "Cloud synthesis endpoint: $API_URL"

# Get input
VERILOG="$1"
TOP="${2:-$(basename -s .v "$VERILOG")_top}"
BASE="$(basename -s .v "$VERILOG")"

if [ ! -f "$VERILOG" ]; then
    echo "Error: Verilog file not found: $VERILOG"
    exit 1
fi

# Check for XDC
XDC_FILE="${BASE}.xdc"
XDC=""
if [ -f "$XDC_FILE" ]; then
    XDC=$(cat "$XDC_FILE")
fi

# Read Verilog
VERILOG_CONTENT=$(cat "$VERILOG")

echo "═══════════════════════════════════════════════"
echo " CLOUD FPGA SYNTHESIS"
echo " Design: $VERILOG"
echo " Top:   $TOP"
echo "═══════════════════════════════════════════════"
echo ""

# Send to cloud
echo "Sending to cloud..."
RESPONSE=$(curl -s -X POST "$API_URL" \
  -H "Content-Type: application/json" \
  -d "{\"verilog\":$(echo "$VERILOG_CONTENT" | jq -Rs .),\"top\":\"$TOP\",\"xdc\":$(echo "$XDC" | jq -Rs .)}")

# Check for errors
if echo "$RESPONSE" | jq -e '.error' > /dev/null; then
    echo "❌ Synthesis failed!"
    echo "$RESPONSE" | jq -r '.error'
    echo ""
    echo "Logs:"
    echo "$RESPONSE" | jq -r '.logs'
    exit 1
fi

# Extract bitstream
echo "$RESPONSE" | jq -r '.bitstream' | base64 -d > "${BASE}.bit"

# Get info
SIZE=$(echo "$RESPONSE" | jq -r '.size_bytes')
STEPS=$(echo "$RESPONSE" | jq -r '.steps[]')

echo "✅ Synthesis complete!"
echo "  Bitstream: ${BASE}.bit (${SIZE} bytes)"
echo "  Steps: $STEPS"
echo ""
echo "To flash:"
echo "  sudo ${SCRIPT_DIR}/jtag_program ${BASE}.bit"
echo ""
echo "═══════════════════════════════════════════════"
