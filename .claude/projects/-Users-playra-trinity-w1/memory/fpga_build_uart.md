# FPGA UART Bridge (J2) — Canonical Flow

## Quick Commands

```bash
# Build UART bridge for J2 (FT232RL)
tri fpga build-uart

# Flash to FPGA
tri fpga flash-uart

# Test UART
tri fpga uart-test

# Check status
tri fpga status
```

## Hardware Setup

| FT232RL Color | Pin | J2 Pin | FPGA Pin | Function |
|---------------|-----|--------|----------|----------|
| 🟢 Green | RXD | 5 | D26 | TX (out) |
| ⬜ White | TXD | 6 | E26 | RX (in) |
| ⬛ Black | GND | 1 | GND | GND |

⚠️ **LEGACY WARNING** (Iteration 7): K20/L20 were INCORRECT pins (pre-2026-03-24).
Always use D26/E26 for J2 UART per QMTECH schematic U2 (HDR_32x2, Bank 15).

## Implementation Status

### ✅ Complete
- `tri_fpga.zig`: `runFpgaBuildUartCommand()`, `runFpgaFlashUartCommand()`, `runFpgaUartTestCommand()`
- `tri_register.zig`: command registration
- `tri_fpga.tri`: spec with 3 behaviors
- `fpga/README.md`: Agent Playbook
- `fpga/constraints/uart_bridge_j2.xdc`: J2 pin mapping

### 🔧 To Build (first time setup)

```bash
# Build nextpnr-xilinx
cd fpga/nextpnr-xilinx
mkdir -p build
cmake .. -DCHIPDB=../xilinx-chipdb
make -j$(sysctl -n hw.ncpu)

# Build prjxray
cd fpga/prjxray
make -j$(sysctl -n hw.ncpu)
```

## Files

| File | Purpose |
|------|---------|
| `fpga/constraints/uart_bridge_j2.xdc` | J2 pin constraints (D26/E26, Bank 15) |
| `fpga/openxc7-synth/uart_bridge_v2.v` | Verilog source |
| `fpga/openxc7-synth/uart_bridge_j2.bit` | Output bitstream |
