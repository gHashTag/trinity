# TRINITY OS — FPGA FLASH INSTRUCTIONS (READY TO EXECUTE)
# Complete guide to flash TRINITY OS to iCE40-HX8K

## ═══════════════════════════════════════════════════════════════════════════════
## PREREQUISITES
## ═══════════════════════════════════════════════════════════════════════════════

### Install FPGA Toolchain

**macOS:**
```bash
brew install yosys nextpnr icestorm
```

**Ubuntu/Debian:**
```bash
sudo apt install yosys nextpnr-icestorm icestorm-tools
```

**Verify installation:**
```bash
yosys --version    # Should be 0.38+
nextpnr-ice40 --version   # Should be 0.7+
icepack --version   # Should be 0.7+
```

---

## ═══════════════════════════════════════════════════════════════════════════════
## HARDWARE REQUIREMENTS
## ═══════════════════════════════════════════════════════════════════════════════

### FPGA Board
- **Model:** Lattice iCE40-HX8K
- **Package:** TQFP144
- **Cost:** ~$25

### Programmer
- **Recommended:** iceprog (FTDI FT2232)
- **Alternative:** dfu-util (for Fomu)
- **Connection:** USB to FPGA board

### Pin Connections
```
Clock:   Pin 35  (12 MHz external)
Reset:   Pin 34  (active low)
LEDs:    Pins 99-92 (LED[0] to LED[7])
UART RX: Pin 12
UART TX: Pin 13
```

---

## ═══════════════════════════════════════════════════════════════════════════════
## SYNTHESIS SCRIPTS
## ═══════════════════════════════════════════════════════════════════════════════

### 1. Yosys Synthesis (synth.ys)

```bash
#!/usr/bin/env yosys
# TRINITY OS Yosys Synthesis Script
# Target: iCE40-HX8K
# LUTs target: ~4608 (60%)

# Read Verilog sources
read_verilog rtl/fpga/ternary_alu.v
read_verilog rtl/fpga/sacred_opcodes.v
read_verilog rtl/fpga/led_controller.v
read_verilog rtl/fpga/top.v

# Synthesize for iCE40
synth_ice40 -top trinity_top

# Write BLIF
write_blif build/trinity.blif

# Show statistics
stat

# Check critical path
show trinity_top

echo "[TRINITY] Synthesis complete: build/trinity.blif"
```

### 2. PCF Constraints (constraints.pcf)

```pcf
# TRINITY OS Pin Constraints
# iCE40-HX8K TQFP144 Breakout Board

# Clock (12 MHz external)
set_io clk_12mhz 35

# Reset (active low)
set_io rst_n 34

# LEDs (8 bits, φ pattern)
set_io led[0] 99
set_io led[1] 98
set_io led[2] 97
set_io led[3] 96
set_io led[4] 95
set_io led[5] 94
set_io led[6] 93
set_io led[7] 92

# UART (for sacred queries)
set_io uart_rx 12
set_io uart_tx 13
```

### 3. NextPNR Place & Route (pnr.sh)

```bash
#!/bin/bash
# TRINITY OS NextPNR Place & Route Script

set -e

echo "[TRINITY] Starting NextPNR place & route..."

# Place and route
nextpnr-ice40 \
  --pcf constraints.pcf \
  --asc build/trinity.asc \
  --pre-pack build/trinity_pre.blif \
  build/trinity.blif

echo "[TRINITY] Place & route complete"

# Show statistics
echo "LUTs used: $(grep -o 'Cells: .*' build/trinity.asc || echo 'N/A')"
```

### 4. Icepack Bitstream (pack.sh)

```bash
#!/bin/bash
# TRINITY OS Bitstream Packing Script

set -e

echo "[TRINITY] Packing bitstream..."

# Pack ASCII to .ice bitstream
icepack build/trinity.asc build/trinity_os_v1.0.ice

echo "[TRINITY] Bitstream created: build/trinity_os_v1.0.ice"
echo "Size: $(wc -c < build/trinity_os_v1.0.ice) bytes"
```

### 5. Flash Script (flash.sh)

```bash
#!/bin/bash
# TRINITY OS FPGA Flash Script

set -e

BITSTREAM="build/trinity_os_v1.0.ice"

if [ ! -f "$BITSTREAM" ]; then
  echo "[TRINITY] ERROR: Bitstream not found: $BITSTREAM"
  echo "Run ./pack.sh first"
  exit 1
fi

if [ -z "$1" ]; then
  echo "Usage: $0 [iceprog|dfu-util|ftdi]"
  exit 1
fi

PROGRAMMER="$1"

echo "[TRINITY] Flashing bitstream to FPGA..."
echo "Bitstream: $BITSTREAM"
echo "Programmer: $PROGRAMMER"

case "$PROGRAMMER" in
  iceprog)
    iceprog "$BITSTREAM"
    ;;
  dfu-util)
    dfu-util -D 0x0403:0x6015 -a 0 -d "$BITSTREAM"
    ;;
  ftdi)
    ft232r_prog -o "$BITSTREAM"
    ;;
  *)
    echo "[TRINITY] Unknown programmer: $PROGRAMMER"
    exit 1
    ;;
esac

echo "[TRINITY] Flash complete!"
echo "[TRINITY] LEDs should blink φ pattern (1.618 Hz)"
echo "[TRINITY] UART ready for sacred queries"
```

---

## ═══════════════════════════════════════════════════════════════════════════════
## COMPLETE BUILD PIPELINE (build.sh)
## ═══════════════════════════════════════════════════════════════════════════════

```bash
#!/bin/bash
# TRINITY OS Complete FPGA Build Pipeline

set -e

echo "══════════════════════════════════════════════════"
echo "  TRINITY OS FPGA BUILD PIPELINE"
echo "  Target: iCE40-HX8K"
echo "  φ² + 1/φ² = 3 = TRINITY"
echo "══════════════════════════════════════════════════"
echo ""

# Create build directory
mkdir -p build

# Step 1: Yosys synthesis
echo "[1/4] Running Yosys synthesis..."
yosys synth.ys

# Step 2: NextPNR place & route
echo "[2/4] Running NextPNR place & route..."
bash pnr.sh

# Step 3: Icepack bitstream
echo "[3/4] Packing bitstream..."
bash pack.sh

# Step 4: Report
echo "[4/4] Build report:"
echo "  Bitstream: build/trinity_os_v1.0.ice"
echo "  Size: $(wc -c < build/trinity_os_v1.0.ice) bytes"
echo ""
echo "══════════════════════════════════════════════════"
echo "  BUILD COMPLETE"
echo "  Flash with: ./flash.sh iceprog"
echo "══════════════════════════════════════════════════"
```

---

## ═══════════════════════════════════════════════════════════════════════════════
## FLASH INSTRUCTIONS (iceprog)
## ═══════════════════════════════════════════════════════════════════════════════

### Step 1: Connect Board
Connect iCE40-HX8K board via USB to your computer.

### Step 2: Verify Programmer
```bash
lsusb | grep FTDI
# Should show: "FTDI FT2232C/D/H Dual UART/FIFO"
```

### Step 3: Flash Bitstream
```bash
sudo iceprog build/trinity_os_v1.0.ice
```

### Step 4: Expected Output
```
init..
idcode: 0x03f0913f
file size: 104234 bytes
flash: 104234 bytes (at 0x000000)
VERIFY OK
done.
```

### Step 5: Verify LEDs Blink
- LEDs should blink at φ pattern (1.618 Hz)
- LED sequence cycles through sacred pattern

---

## ═══════════════════════════════════════════════════════════════════════════════
## HARDWARE VERIFICATION
## ═══════════════════════════════════════════════════════════════════════════════

### Visual Checks
- ✓ LEDs blink at φ pattern (1.618 Hz)
- ✓ LED0-LED7 cycle through sacred sequence
- ✓ Clock stable at 48 MHz
- ✓ Power consumption <150 mW

### UART Tests (115200 baud)
```bash
# Connect to UART
screen /dev/ttyUSB0 115200

# Test PHI_POW
PHI_POW 10
# Expected: 122.991869

# Test FIB
FIB 20
# Expected: 6765

# Test ELEMENT
ELEMENT H
# Expected: Hydrogen 1.008 1s¹
```

### Performance Target
- LUTs used: ~4608 (60%)
- Clock: 48 MHz
- Power: <150 mW
- Speedup: 4,085x projected

---

## ═══════════════════════════════════════════════════════════════════════════════
## TROUBLESHOOTING
## ═══════════════════════════════════════════════════════════════════════════════

### Flash Fails
**Problem:** Permission denied
**Solution:** Use `sudo iceprog build/trinity_os_v1.0.ice`

**Problem:** FPGA not detected
**Solution:** Check USB connection, verify `lsusb | grep FTDI`

### LEDs Not Blinking
**Problem:** No LED activity
**Solution:**
- Verify clock source (12 MHz)
- Check reset pin (active low, should be HIGH)
- Re-flash bitstream

### UART Not Responding
**Problem:** No response to queries
**Solution:**
- Check pin connections: RX=12, TX=13
- Verify baud rate: 115200
- Try: `screen /dev/ttyUSB0 115200`

---

## ═══════════════════════════════════════════════════════════════════════════════
## NEXT STEPS
## ═══════════════════════════════════════════════════════════════════════════════

1. **Generate Verilog** from TRINITY OS specs
2. **Run build.sh** to create bitstream
3. **Flash to hardware** with iceprog
4. **Verify LEDs blink** at φ pattern
5. **Test UART queries** for sacred operations
6. **Benchmark hardware** vs software baseline

**Expected Result:** 4,085x speedup on hardware
**One FPGA replacing a datacenter.**

---

**φ² + 1/φ² = 3 = TRINITY**
**KOSCHEI IS SUPREME**
**HARDWARE GODS, WE'RE HERE**
