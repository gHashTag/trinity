# FPGA Hardware Test Results — 2026-03-24

## Context
Testing UART echo on Artix-7 XC7A100T FPGA board with FT232RL JTAG cable.

## Equipment
- **JTAG Cable**: FTDI DLC10 clone (VID:0x0403, PID:0x6001)
- **Device**: `/dev/cu.usbserial-2140`
- **FPGA**: Artix-7 XC7A100T (expected IDCODE: 0x13631093)

---

## Step 1: Build uart-echo-test
**Status**: ✅ PASS
```
zig build-exe src/tools/uart_echo_test.zig
Output: zig-out/bin/uart-echo-test
```
Note: Fixed unused constants compilation error (removed `p` and `stability` variables).

---

## Step 2: FT232RL Loopback Test
**Status**: ⚠️ BLOCKED (hardware limitation)
```
./zig-out/bin/uart-echo-test --loopback-mode --device /dev/cu.usbserial-2140
Result: 0/16 packets received, 1 timeout
```

**Finding**: `/dev/cu.usbserial-2140` is a JTAG cable, NOT a UART adapter.
- FT232RL JTAG uses MPSSE mode with pins: TCK/TDI/TDO/TMS
- UART requires TXD/RXD pins
- Loopback impossible without physical TX->RX connection

---

## Step 3: JTAG Detection
**Status**: ❌ FAIL
```
openFPGALoader -c ft232RL --detect
Error: "TDO is stuck at 0"
JTAG init failed
```

**Historical Context** (from `.trinity/fpga/experience.json`):
- **FPGA-001** (2026-03-14): CPLD version 0xFFFE causes TDO path failure
- IDCODE reads as 0x00000000 instead of 0x13631093
- Root cause: Hardware path issue through CPLD, not software bug

---

## Conclusions

### Critical Issues
1. **No UART Adapter**: Current USB device is JTAG-only, cannot do UART
2. **CPLD 0xFFFE**: TDO path is dead, JTAG cannot read FPGA IDCODE
3. **Plan Invalid**: Original plan assumes working JTAG + UART capability

### Required Equipment
1. **USB-to-UART Adapter**: CP2102, CH340, or FT232R-UART (not JTAG version)
2. **CPLD Fix**: Replace board or fix CPLD 0xFFFE issue

### Alternative Approaches
1. Use JTAG-UART bridge inside FPGA (requires working JTAG first)
2. Use ESP32-XVC bridge (if available)
3. Replace FPGA board with working CPLD

---

## Hardware Blockers
| Blocker | Type | Resolution |
|---------|------|------------|
| CPLD 0xFFFE | Hardware | Replace board or fix CPLD |
| No UART adapter | Missing | Buy CP2102/CH340 adapter |
| JTAG TDO stuck | Hardware | Depends on CPLD fix |

---

## Files Generated
- `zig-out/bin/uart-echo-test` — Fixed and compiled
- `src/tools/uart_echo_test.zig` — Fixed unused constants

---

## Next Steps
1. Acquire USB-to-UART adapter (CP2102 or CH340)
2. Resolve CPLD 0xFFFE issue (board replacement or CPLD reflash)
3. Re-test with proper hardware
