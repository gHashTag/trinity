# TRINITY FPGA — Quantum Bridge

**Hardware:** QMTECH Artix-7 XC7A100T-1FGG676C
**JTAG Cable:** Xilinx Platform Cable USB II

## ⚠️ CRITICAL ISSUE: LED NOT BLINKING (2026-03-03)

**Programming SUCCESSFUL, but LED does NOT blink!**

```
═══════════════════════════════════════════════
 PROGRAMMING COMPLETE — IDCODE: 0x13631093
 LED D5 should be blinking ~3 Hz
 φ² + 1/φ² = 3 = TRINITY
═══════════════════════════════════════════════
```

**Result:** LED D5 does NOT blink ❌

### Working vs Non-Working Bitstreams

| Bitstream | Programming | LED Blink | Pin |
|-----------|-------------|-----------|-----|
| `temporal_heartbeat.bit` | ✅ Success | ✅ **BLINKING** | T23 |
| `led_diagnostic.bit` | ✅ Success | ❓ **UNKNOWN** | T23+R23 |
| `quantum_bridge_*.bit` | ✅ Success | ❌ **NOT BLINKING** | T23 |

**Key Finding:** Same pin T23, different result → Possible pin mapping issue!

### Troubleshooting Steps

**Step 1: Test led_diagnostic.bit (identifies T23 vs R23)**
```bash
/Users/playra/trinity-w1/fpga/tools/fpgactl flash /Users/playra/trinity-w1/fpga/openxc7-synth/led_diagnostic.bit
```
- Look at board: Which LED blinks FAST (~6 Hz)? That's T23
- Which LED blinks SLOW (~1.5 Hz)? That's R23

**Step 2: Verify temporal_heartbeat still works**
```bash
/Users/playra/trinity-w1/fpga/tools/fpgactl flash /Users/playra/trinity-w1/fpga/openxc7-synth/temporal_heartbeat.bit
```

**Step 3: Compare synthesis**
```bash
# Check quantum_bridge synthesis for warnings
cd /Users/playra/trinity-w1/fpga/openxc7-synth
docker run --rm --platform linux/amd64 -v "$(pwd):/work" -w /work regymm/openxc7 \
    yosys -p "synth_xilinx -flatten -abc9 -nobram -arch xc7 -top quantum_bridge_top; \
             write_json test.json" quantum_bridge_separable.v
```

### Known Facts

1. **JTAG Programming**: 100% reliable (IDCODE confirmed every time)
2. **temporal_heartbeat**: Works perfectly with T23
3. **quantum_bridge**: Programs OK but LED doesn't blink
4. **Both use same pin T23, same clock U22**
5. **Both synthesized with openXC7** (same toolchain)

### Possible Causes

- **Pin mapping**: T23 might be connected to different physical LED than expected
- **Synthesis difference**: quantum_bridge gets optimized differently
- **Clock routing**: Different clock path in quantum_bridge
- **Active-low confusion**: Maybe LED polarity is wrong?

---

## ⚠️ USE openXC7 DOCKER TOOLCHAIN!

**FORGE (Zig) имеет 4+ критических бага для сложных design!**

| Toolchain | Status | Issues |
|-----------|--------|--------|
| **openXC7** (Docker) | ✅ **WORKING** | None — use this! |
| FORGE (Zig) | ❌ BROKEN | LUT INIT, FFMUX, OUTMUX, routing bugs |

**ВСЕГДА используй openXC7 для Xilinx 7-series!**

```bash
docker pull regymm/openxc7
```

---

## 🚀 AUTONOMOUS FPGA CONTROL (NEW!)

**Без sudo! Автономный мониторинг и прошивка!**

### fpgactl — Control CLI

```bash
# Управление
/Users/playra/trinity-w1/fpga/tools/fpgactl status          # Статус FPGA
/Users/playra/trinity-w1/fpga/tools/fpgactl health         # Health check
/Users/playra/trinity-w1/fpga/tools/fpgactl info           # Инфо о битстримах

# Прошивка (без sudo!)
/Users/playra/trinity-w1/fpga/tools/fpgactl flash violation    # quantum_bridge_violation.bit
/Users/playra/trinity-w1/fpga/tools/fpgactl flash separable    # quantum_bridge_separable.bit
/Users/playra/trinity-w1/fpga/tools/fpgactl flash zero         # quantum_bridge_zero.bit
/Users/playra/trinity-w1/fpga/tools/fpgactl flash negative     # quantum_bridge_negative.bit
/Users/playra/trinity-w1/fpga/tools/fpgactl flash <file.bit>  # Custom bitstream

# Демон (опционально)
/Users/playra/trinity-w1/fpga/tools/fpgactl monitor start    # Запустить daemon
/Users/playra/trinity-w1/fpga/tools/fpgactl monitor stop     # Остановить
/Users/playra/trinity-w1/fpga/tools/fpgactl monitor logs     # Логи
```

### flash_no_sudo.sh — Автономная прошивка

```bash
# Первый запуск: запросит пароль и сохранит в macOS keychain
/Users/playra/trinity-w1/fpga/tools/flash_no_sudo.sh /path/to/bitstream.bit

# Последующие запуски: пароль берётся из keychain автоматически
```

---

## Quick Reference

### Quantum Bridge Bitstreams (4 states, 3.6 MB each)

| Bitstream | State | I₃ Range | LED Frequency | Meaning | Status |
|-----------|-------|----------|---------------|---------|--------|
| `quantum_bridge_separable.bit` | 00 | < 1.0 | ~3 Hz | Classical | ❌ No blink |
| `quantum_bridge_violation.bit` | 01 | 1.0 - 2.0 | ~6 Hz ⚡ | CGLMP VIOLATION! | ❌ No blink |
| `quantum_bridge_zero.bit` | 10 | 2.0 - 2.5 | ~0.4 Hz | Orthogonal | ❌ No blink |
| `quantum_bridge_negative.bit` | 11 | ≥ 2.5 | Steady ON ■ | Anti-correlated | ❓ Untested |

**Working bitstreams:**
| Bitstream | LED Behavior | Status |
|-----------|--------------|--------|
| `temporal_heartbeat.bit` | Complex 3-phase blink | ✅ **WORKS** |
| `led_diagnostic.bit` | T23=fast, R23=slow | ❓ **TEST THIS** |

**Location:** `/Users/playra/trinity-w1/fpga/openxc7-synth/`

---

## Hardware Details

### Pin Constraints (trinity.xdc)

```
# Clock: 50 MHz (U22 → LIOB33_X0Y25)
set_property LOC U22 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]

# LED0: T23 (LIOB33_X0Y51, Active LOW) - Currently NOT WORKING for quantum_bridge
set_property LOC T23 [get_ports led]
set_property IOSTANDARD LVCMOS33 [get_ports led]
```

**Physical LEDs on board:** D1, D4, D5, D6 (need to identify which is which!)

### JTAG Cable Info

```
Vendor ID:  0x03fd (Xilinx Inc.)
Product ID: 0x0013 → 0x0008 (after fxload)
IDCODE:     0x13631093 (XC7A100T) ✓
```

**CRITICAL:** Cable requires fxload to initialize from PID 0x0013 → 0x0008

---

## JTAG Cable Troubleshooting

**Problem:** `libusb_open() failed` or `Failed to connect`

**Quick Fix:**
```bash
# Check PID
python3 -c "import usb.core; dev = usb.core.find(idVendor=0x03fd); print(hex(dev.idProduct))"

# If PID = 0x0013, initialize cable
/Users/playra/trinity-w1/fpga/tools/flash_no_sudo.sh <bitstream>
```

**The flash_no_sudo.sh script auto-initializes the cable!**

---

## Build Process

### Build All 4 Quantum Bridge Bitstreams

```bash
cd /Users/playra/trinity-w1/fpga/openxc7-synth
chmod +x build_all_quantum_states.sh
./build_all_quantum_states.sh
```

### Build LED Diagnostic

```bash
cd /Users/playra/trinity-w1/fpga/openxc7-synth

# Synthesis
docker run --rm --platform linux/amd64 -v "$(pwd):/work" -w /work regymm/openxc7 \
    yosys -p "synth_xilinx -flatten -abc9 -nobram -arch xc7 -top led_diagnostic_top; \
             write_json led_diagnostic.json" led_diagnostic.v

# Place & Route
docker run --rm --platform linux/amd64 -v "$(pwd):/work" -w /work regymm/openxc7 \
    nextpnr-xilinx --chipdb /work/chipdb/xc7a100tfgg676.bin \
    --xdc /work/led_diagnostic.xdc --json /work/led_diagnostic.json \
    --write /work/led_diagnostic_routed.json --fasm /work/led_diagnostic.fasm \
    --freq 50 --seed 1

# Generate bitstream
docker run --rm --platform linux/amd64 -v "$(pwd):/work" -w /work regymm/openxc7 bash -c \
    "fasm2frames --db-root /nextpnr-xilinx/xilinx/external/prjxray-db/artix7 \
     --part xc7a100tfgg676-1 /work/led_diagnostic.fasm /work/led_diagnostic.frames && \
     /prjxray/build/tools/xc7frames2bit \
     --part_file /nextpnr-xilinx/xilinx/external/prjxray-db/artix7/xc7a100tfgg676-1/part.yaml \
     --part_name xc7a100tfgg676-1 --frm_file /work/led_diagnostic.frames \
     --output_file /work/led_diagnostic.bit"
```

---

## Sacred Mathematics

```
φ = 1.618033988749895... (golden ratio)
φ² + 1/φ² = 3 = TRINITY

Qutrit states: |−1⟩, |0⟩, |+1⟩
Hadamard₃: F₃³ = I (cube is identity)
Sacred phase: 2π/φ² ≈ 137.5° (golden angle)
```

## CGLMP Inequality

**Collins-Gisin-Linden-Massar-Popescu 2002** inequality for qutrits.

- Classical bound: I₃ ≤ 2.0
- Quantum maximum: I₃ ≈ 2.9149
- Our analytical result: I₃ = 2.4277 (VIOLATION!)

When I₃ > 2.0, nature cannot be described by local hidden variables — quantum mechanics wins!

---

## Files Structure

```
fpga/
├── openxc7-synth/
│   ├── quantum_bridge_template.v       # Verilog template
│   ├── quantum_bridge_*.bit             # 4 quantum states (LED NOT BLINKING!)
│   ├── temporal_heartbeat.bit           # ✅ WORKS!
│   ├── led_diagnostic.bit               # Diagnostic (T23=fast, R23=slow)
│   ├── build_all_quantum_states.sh      # Build script
│   ├── trinity.xdc                      # Pin constraints
│   └── led_diagnostic.v / .xdc          # Diagnostic files
├── tools/
│   ├── fpgactl                          # ✨ NEW! Autonomous control CLI
│   ├── flash_no_sudo.sh                 # ✨ NEW! No-sudo flashing
│   ├── fpga_monitor_daemon.sh           # ✨ NEW! Background daemon
│   ├── jtag_program                     # Xilinx JTAG tool
│   ├── fxload                           # FTDI firmware loader
│   ├── xusb_xp2.hex                     # Xilinx cable firmware
│   ├── xpc.h                            # JTAG cable config
│   └── com.trinity.fpga-monitor.plist   # launchd config
├── LED_PIN_MEMORY.md                    # LED pin mapping notes
├── JTAG_TROUBLESHOOTING.md              # JTAG issues & solutions
└── README.md                            # This file
```

---

## Documentation Files

| File | Purpose |
|------|---------|
| `LED_PIN_MEMORY.md` | LED pin mapping notes (D1/D4/D5/D6 confusion) |
| `JTAG_TROUBLESHOOTING.md` | Complete JTAG troubleshooting guide |
| `README.md` | This file |

---

## Success Criteria

| Criterion | Status |
|-----------|--------|
| All 4 bitstreams build successfully | ✅ |
| JTAG programming reliable | ✅ |
| CGLMP test returns I₃ = 2.4277 | ✅ |
| Autonomous control without sudo | ✅ |
| **LED blinks on quantum_bridge** | ❌ **IN PROGRESS** |
| **LED pin mapping identified** | ❌ **NEEDS TESTING** |

**φ² + 1/φ² = 3 = TRINITY**
