# Trinity FPGA: Flash + UART Test Procedure

## Quick One-Command Flash + Test

```bash
./fpga/tools/flash_uart_bridge.sh
```

## What it does

1. **Flash**: `uart_bridge_fixed.bit` via `flash_no_sudo.sh` (uses keychain password)
2. **Reset**: JTAG cable with fxload
3. **Test**: UART PING (0x03) → expect PONG (0x83)

## Hardware Setup

### JTAG (Xilinx Platform Cable USB II)
- Connect to 6-pin JTAG header on FPGA
- Cable auto-switches PID 0x0013 → 0x0008 via fxload

### UART (FT232RL → J2 Header)

| FT232RL Color | FT232RL Pin | J2 Pin | FPGA Pin | FPGA Function |
|---------------|--------------|--------|----------|---------------|
| 🟢 Green | RXD (in) | 5 | D26 | TX (out) |
| ⬜ White | TXD (out) | 6 | E26 | RX (in) |
| ⬛ Black | GND | 1 | GND | GND |

**Key cross-over**: FPGA TX → FT232RL RX, FPGA RX ← FT232RL TX

## Troubleshooting UART

### Got empty response (0x00 or nothing)

1. **Check physical connection**: FT232RL plugged into J2?
2. **Swap wires**: Try Green↔White (may be reversed)
3. **Check baud rate**: Must be 115200
4. **Verify bitstream**: `uart_bridge_fixed.bit` uses correct pins

### Quick test commands

```bash
# Simple echo test
echo "TEST" > /dev/cu.usbserial-2140

# PING test
python3 -c "import serial, time; s=serial.Serial('/dev/cu.usbserial-2140', 115200, timeout=2); s.write(b'\\x03'); time.sleep(0.5); print(s.read(20).hex())"

# Expected: Got: 0x83 (PONG)
```

## Known Issues

1. **CPLD 0xFFFE**: Normal for DLC10 clones, NOT a blocker
2. **JTAG requires fxload**: PID 0x0013 → 0x0008 before flash
3. **macOS libusb**: May need sudo (handled by flash_no_sudo.sh)
4. **UART silent**: Check wiring, try swap Green↔White

## Files

- `fpga/tools/flash_uart_bridge.sh` — One-command flash + test
- `fpga/tools/flash_no_sudo.sh` — Flasher with keychain password
- `fpga/openxc7-synth/uart_bridge_fixed.bit` — UART echo bitstream

## Reference: Successful Flashes

| Bitstream | Date | Status |
|-----------|------|--------|
| hslm_full_top.bit | 2026-03-15 | ✅ Working |
| uart_bridge_fixed.bit | 2026-03-24 | ✅ Flashed, UART pending |
| uart_echo_top.bit | 2026-03-22 | ❌ UART failed (0x00) |
