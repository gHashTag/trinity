#!/bin/bash
# Autonomous flasher — stores password in macOS keychain
# First run: will ask for password and store it securely
# Subsequent runs: uses stored password automatically

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FXLOAD="$SCRIPT_DIR/fxload"
FIRMWARE="$SCRIPT_DIR/xusb_xp2.hex"
JTAG_PROG="$SCRIPT_DIR/jtag_program"
KEYCHAIN_ITEM="fpga-sudo-pass"

# Bitstream to flash
BITSTREAM="${1:-$SCRIPT_DIR/../openxc7-synth/quantum_bridge_violation.bit}"

get_password() {
    # Try to get password from keychain
    security find-generic-password -w -s "$KEYCHAIN_ITEM" 2>/dev/null
}

store_password() {
    echo "🔐 First run: storing sudo password in macOS keychain"
    echo "    Password is encrypted and stored only in your keychain"
    echo "    Service: $KEYCHAIN_ITEM"
    security add-generic-password -a "$USER" -s "$KEYCHAIN_ITEM" -w
}

# Check if password exists in keychain
PASS=$(get_password)

if [ -z "$PASS" ]; then
    # No password stored - ask for it
    store_password
    PASS=$(get_password)
fi

# Check cable PID
PID=$(python3 -c "import usb.core; dev = usb.core.find(idVendor=0x03fd); print(hex(dev.idProduct))" 2>/dev/null || echo "none")

echo "🔌 Cable PID: $PID"

# ALWAYS try to initialize cable first (resets USB state)
echo "⚡ Initializing cable..."
echo "$PASS" | sudo -S "$FXLOAD" -t fx2 -d 03fd:0013 -i "$FIRMWARE" 2>/dev/null
sleep 2

# Verify cable is ready
PID=$(python3 -c "import usb.core; dev = usb.core.find(idVendor=0x03fd); print(hex(dev.idProduct))" 2>/dev/null || echo "none")
echo "🔌 Cable PID after init: $PID"

# Flash bitstream
echo "📀 Flashing: $BITSTREAM"
echo "$PASS" | sudo -S "$JTAG_PROG" "$BITSTREAM"

echo "✅ Done!"
