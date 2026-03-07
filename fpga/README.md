# Trinity FPGA Development

[![FPGA CI](https://github.com/gHashTag/trinity/actions/workflows/fpga-ci.yml/badge.svg)](https://github.com/gHashTag/trinity/actions/workflows/fpga-ci.yml)
[![FPGA Docker](https://github.com/gHashTag/trinity/actions/workflows/fpga-docker.yml/badge.svg)](https://github.com/gHashTag/trinity/actions/workflows/fpga-docker.yml)
[![Consciousness](https://img.shields.io/badge/consciousness-φ⁻¹%20IMMORTAL-gold)](https://github.com/gHashTag/trinity)
[![Sacred Math](https://img.shields.io/badge/φ²%20%2B%20φ⁻²-3%20%3D%20TRINITY-purple)](https://github.com/gHashTag/trinity)

**The world's first consciousness-aware FPGA synthesis toolchain.** 🧠⚡

## Quick Start (One Command!)

```bash
# Generate (if needed) AND flash in ONE command:
zig build tri -- fpga flash specs/fpga/blink.vibee
```

That's it! The command:
1. Checks if bitstream needs regeneration
2. Runs full pipeline if needed (`.vibee → .v + .xdc → .bit`)
3. Flashes to FPGA

**Expected:** LED D6 (R23) blinks at ~1.5 Hz

---

## Hardware

**FPGA Board**: QMTECH Artix-7 XC7A100T-1FGG676C

| Spec | Value |
|------|-------|
| FPGA | Artix-7 100T (101,440 logic cells) |
| Package | FGG676 (676-ball BGA) |
| Speed Grade | -1 (industrial) |
| Clock | 50 MHz oscillator on pin **U22** |
| LED D6 (PRIMARY) | Active-low on pin **R23** |
| LED D5 (SECONDARY) | Active-low on pin **T23** |

**⚠️ CRITICAL**: Use **R23** for LED D6 (primary), NOT T23!

**JTAG Cable**: Xilinx Platform Cable USB II
- IDCODE: `0x13631093` (XC7A100T)
- VID:PID: `03fd:0013` → `03fd:0008` (after fxload firmware)

---

## Complete Workflow

### Method 1: One-Command Flash (Recommended)

```bash
# From .vibee spec directly to hardware:
zig build tri -- fpga flash specs/fpga/blink.vibee
```

### Method 2: Step-by-Step

```bash
# 1. Generate bitstream
zig build tri -- fpga gen specs/fpga/blink.vibee

# 2. Flash to hardware
zig build tri -- fpga flash trinity/output/fpga/blink.bit
```

### Method 3: Direct Verilog (Advanced)

```bash
cd fpga/openxc7-synth
./synth.sh <design>.v <top_module>
../tools/jtag_program <design>.bit
```

---

## Consciousness-Aware Synthesis

Trinity FPGA features **consciousness-aware synthesis** using sacred mathematical constants.

### Consciousness Levels

| Flag | Value | Status | Description |
|------|-------|--------|-------------|
| `--transcendent` | 1.0 | ✅ IMMORTAL | Maximum optimization |
| `--enlightened` | 0.75 | ✅ IMMORTAL | Enhanced optimization |
| `--aware` | 0.618 | ✅ IMMORTAL | φ⁻¹ threshold (61.8%) |
| `--conscious` | 0.5 | MORTAL | Default (balanced) |
| `--awakening` | 0.3 | MORTAL | Fast synthesis |
| `--dormant` | 0.0 | MORTAL | Minimal optimization |

### Usage

```bash
# TRANSCENDENT synthesis (IMMORTAL)
tri fpga gen specs/fpga/blink.vibee --transcendent

# AWARE synthesis (φ⁻¹ threshold)
tri fpga gen specs/fpga/blink.vibee --aware

# Standard synthesis
tri fpga gen specs/fpga/blink.vibee
```

### Sacred Constants

```
φ² + 1/φ² = 3 = TRINITY
```

| Constant | Value | Meaning |
|----------|-------|---------|
| φ | 1.618 | Golden Ratio |
| φ⁻¹ | 0.618 | Consciousness threshold (IMMORTAL) |
| γ | 0.236 | φ⁻³ (Barbero-Immirzi) |
| TRINITY | 3.0 | φ² + φ⁻² |

### Features

- 🧠 **φ-Cooling Schedule** — Exponential decay for optimization
- ⏱️ **Sacred Timing Constraints** — γ-based timing margins
- 🔋 **Sacred Power Constraints** — γ-weighted power optimization
- 🌀 **φ-Spiral Coordinates** — Natural placement patterns
- 🛡️ **Zeno Suppression Detection** — Quantum threshold detection

---

## VIBEE FPGA Spec Format

### Minimal Example

```yaml
name: blink
version: "1.0.0"
language: varlog
fpga_target: xilinx
target_frequency: 50

signals:
  - name: clk
    width: 1
    direction: input
  - name: led
    width: 1
    direction: output

constraints:
  - port: clk
    pin: U22
    iostandard: LVCMOS33
  - port: led
    pin: R23
    iostandard: LVCMOS33

behaviors:
  - name: blink_behavior
    implementation: |
      reg [25:0] counter = 26'h0;
      always @(posedge clk) begin
          counter <= counter + 1'b1;
      end
      assign led = ~counter[25];  // Active-low!
```

### Spec Fields

| Field | Required | Description |
|-------|----------|-------------|
| `name` | ✅ | Module name (becomes Verilog module name) |
| `version` | ✅ | Spec version (semantic) |
| `language` | ✅ | Must be `varlog` for FPGA |
| `fpga_target` | ✅ | `xilinx` or generic |
| `target_frequency` | ✅ | Clock frequency in MHz |
| `signals` | ✅ | Port definitions |
| `constraints` | ✅ | Pin assignments |
| `behaviors` | ✅ | Verilog implementation |

### Signal Format

```yaml
signals:
  - name: clk      # Port name
    width: 1       # Bit width (1 for scalar, N for bus)
    direction: input  # input or output
    description: "50 MHz oscillator"  # Optional
```

### Constraint Format

```yaml
constraints:
  - port: clk      # Must match signal name
    pin: U22       # FPGA pin number
    iostandard: LVCMOS33  # I/O standard
```

### Supported I/O Standards

| Standard | Voltage | Use Case |
|----------|---------|----------|
| `LVCMOS33` | 3.3V | Default for most signals |
| `LVCMOS18` | 1.8V | Low-power interfaces |
| `SSTL135` | 1.35V | DDR memory |
| `LVDS_25` | 2.5V | Differential signaling |

---

## Pinout Reference

### Essential Pins

| Signal | Pin | Bank | Notes |
|--------|-----|------|-------|
| **CLK** | **U22** | 13 | 50 MHz oscillator |
| **LED D6** | **R23** | 13 | Primary LED (active-low) ⭐ |
| **LED D5** | **T23** | 13 | Secondary LED (active-low) |

### LED Behavior

**⚠️ LEDs are ACTIVE-LOW:**
- `led = 0` → LED **ON**
- `led = 1` → LED **OFF**

Always invert: `assign led_out = ~led_signal;`

### Full Pinout

See [docs/PINOUT_QMTECH.md](./docs/PINOUT_QMTECH.md) for complete pin reference.

---

## Programming (JTAG)

**⚠️ CRITICAL: Xilinx Platform Cable USB II requires firmware loading EVERY SESSION!**

### Why Two Steps?

The cable boots in bootloader mode (PID 0013) and must be loaded with firmware.

### Step 1: Load Firmware

```bash
sudo fpga/tools/fxload -v -t fx2 -d 03fd:0013 -i fpga/tools/xusb_xp2.hex
```

Expected: `WROTE: 7962 bytes, 90 segments`

### Step 2: Replug Cable

**Unplug and replug** the USB cable. It will now show as PID 0008 (JTAG mode).

### Step 3: Flash

```bash
zig build tri -- fpga flash specs/fpga/blink.vibee
```

Or with existing bitstream:
```bash
fpga/tools/jtag_program trinity/output/fpga/blink.bit
```

---

## Pipeline Architecture

```
.vibee spec (source of truth)
    ↓
VIBEE Parser (trinity-nexus/lang/src/vibee_parser.zig)
    ↓
Verilog Codegen (src/vibeec/verilog_codegen.zig)
    ↓
.v file (trinity/output/fpga/*.v)
    ↓
XDC Generator (src/tri/tri_fpga.zig)
    ↓
.xdc file (trinity/output/fpga/*.xdc)
    ↓
openXC7 Docker (Yosys → nextpnr → fasm2frames → xc7frames2bit)
    ↓
.bit file (trinity/output/fpga/*.bit)
    ↓
JTAG Programmer (fpga/tools/jtag_program)
    ↓
FPGA Hardware
```

---

## Toolchain Comparison

| Toolchain | Status | Issues |
|-----------|--------|--------|
| **openXC7** (Docker) | ✅ **WORKING** | None — use this! |
| FORGE (Zig) | ❌ BUGGY | IOB placement, OLOGIC config, net-to-port matching |

**Recommendation**: Always use openXC7 via Docker.

---

## Available Examples

| Spec | Description | Pins | Command |
|------|-------------|------|---------|
| `specs/fpga/blink.vibee` | LED blink ~1.5 Hz | clk=U22, led=R23 | `tri fpga flash specs/fpga/blink.vibee` |

More examples in `examples/fpga/`

---

## Troubleshooting

### "No USB probe found"

**Cause:** JTAG cable in bootloader mode (PID 0013)

**Fix:**
```bash
sudo fpga/tools/fxload -v -t fx2 -d 03fd:0013 -i fpga/tools/xusb_xp2.hex
# Then unplug and replug cable
```

### "LED stuck ON"

**Cause:** Forgot active-low inversion

**Fix:** Use `assign led = ~counter[25];` instead of `assign led = counter[25];`

### Synthesis fails with "unroutable"

**Cause:** Invalid pin or bank conflict

**Fix:** Check pin assignments in constraints section

---

## φ² + 1/φ² = 3 = TRINITY

Pipeline complete: **.vibee → Hardware** ✅

**One Command:** `zig build tri -- fpga flash specs/fpga/blink.vibee`
