#!/bin/bash
# ============================================================================
# TRINITY FPGA: Flash uart_bridge_fixed.bit + Test UART
# One-command flash + test sequence
# ============================================================================

echo "🔌 STEP 1: Flash bitstream..."
./fpga/tools/flash_no_sudo.sh fpga/openxc7-synth/uart_bridge_fixed.bit 2>&1 | grep -E "Done|FAIL|Error"

echo ""
echo "🔌 STEP 2: Reset JTAG cable..."
sudo ./fpga/tools/fxload -t fx2 -d 03fd:0013 -I ./fpga/tools/xusb_xp2.hex 2>/dev/null
sleep 3

echo ""
echo "📡 STEP 3: UART Test (PING 0x03 → expect PONG 0x83)"
echo "   Wiring: Green→J2-5(D26), White→J2-6(E26), Black→J2-1(GND)"

python3 << 'PYEOF'
import serial, time
try:
    ser = serial.Serial('/dev/cu.usbserial-2140', 115200, timeout=2)
    ser.reset_input_buffer()
    ser.write(b'\x03')
    time.sleep(0.5)
    resp = ser.read(20)
    ser.close()

    print(f"   Sent: 0x03")
    print(f"   Got:  {resp.hex()}")
    print(f"   Expected: 0x83")

    if resp == b'\x83':
        print("   ✅ SUCCESS: UART works!")
        exit(0)
    else:
        print("   ❌ FAIL: Wrong response")
        print("   Check: 1) FT232RL wired to J2 correctly?")
        print("          2) Green→pin5, White→pin6, Black→pin1")
        exit(1)
except Exception as e:
    print(f"   ❌ ERROR: {e}")
    exit(1)
PYEOF

echo ""
echo "φ² + 1/φ² = 3 = TRINITY"
