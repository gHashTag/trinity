# OPENXC7 SYNTHESIS SUCCESS REPORT
## Temporal Trinity Heartbeat v1.0 — First Working Bitstream

**Date:** 2026-03-03
**Target:** QMTECH Artix-7 XC7A100T-1FGG676C
**Result:** ✅ CONFIRMED WORKING — LED D6 blinking with phi-second pattern

---

## EXECUTIVE SUMMARY

After 24+ hours of failed attempts with the FORGE (Zig) toolchain (23 versions, all non-functional), the openXC7 Docker toolchain succeeded on the **first try**.

**Key finding:** The open-source Yosys+nextpnr-xilinx toolchain generates CORRECT bitstreams for Xilinx 7-series FPGAs, while FORGE has fundamental bugs in LUT INIT, FFMUX strategy, and routing.

---

## THE WORKING TOOLCHAIN

### Docker Image: `regymm/openxc7:latest` (5.72GB)

```bash
docker run --rm --platform linux/amd64 \
  -v /Users/playra/trinity-w1/fpga/openxc7-synth:/work -w /work \
  regymm/openxc7 <command>
```

**Components:**
| Tool | Version | Purpose |
|------|---------|---------|
| yosys | latest | Verilog synthesis (synth_xilinx) |
| nextpnr-xilinx | latest | Place & Route, FASM generation |
| fasm2frames | prjxray | FASM → frame conversion |
| xc7frames2bit | prjxray | Frames → .bit bitstream |
| prjxray-db | artix7 | Device database |

---

## COMPLETE SYNTHESIS FLOW

### Step 1: Yosys Synthesis (Verilog → JSON)

```bash
docker run --rm --platform linux/amd64 \
  -v /Users/playra/trinity-w1/fpga/openxc7-synth:/work -w /work \
  regymm/openxc7 \
  yosys -p "synth_xilinx -flatten -abc9 -nobram -arch xc7 -top temporal_heartbeat_top; write_json temporal_heartbeat.json" \
  temporal_heartbeat.v
```

**What happens:**
1. Parses Verilog HDL
2. Elaborates design hierarchy
3. Runs Xilinx-specific optimizations (`synth_xilinx`)
4. Performs technology mapping to Xilinx primitives (LUT6, CARRY4, FF)
5. Flattens hierarchy
6. Generates JSON netlist

**Output:** `temporal_heartbeat.json` (65 KB)

---

### Step 2: nextpnr-xilinx (JSON → FASM)

```bash
docker run --rm --platform linux/amd64 \
  -v /Users/playra/trinity-w1/fpga/openxc7-synth:/work -w /work \
  regymm/openxc7 \
  nextpnr-xilinx \
    --chipdb /work/chipdb/xc7a100tfgg676.bin \
    --xdc /work/trinity.xdc \
    --json /work/temporal_heartbeat.json \
    --write /work/temporal_heartbeat_routed.json \
    --fasm /work/temporal_heartbeat.fasm \
    --freq 50 --seed 1
```

**What happens:**
1. Loads chip database (tile types, site types, PIPs)
2. Parses XDC constraints (pin locations, IOSTANDARD)
3. **Placement:** Assigns logic cells to physical sites
   - Counter logic → CLBLL_L tiles X2Y54-X2Y69
   - Clock buffer → HCLK tile
   - IO buffers → LIOB33 tiles
4. **Routing:** Connects signals through PIPs (Programmable Interconnect Points)
   - Local routing within CLBs
   - Vertical/horizontal routing through INT tiles
   - Clock routing through global clock network
5. Generates FASM (FPGA Assembly) representation

**Output:** `temporal_heartbeat.fasm` (1707 lines)

**Results:**
```
Max frequency: 165.15 MHz (target: 50 MHz) ✅
Routing overuse: 0 ✅
Total CLBs: ~30 slices
Total CARRY4: 64 instances (for arithmetic)
```

---

### Step 3: FASM → Frames → Bitstream

```bash
docker run --rm --platform linux/amd64 \
  -v /Users/playra/trinity-w1/fpga/openxc7-synth:/work -w /work \
  regymm/openxc7 \
  bash -c "\
    fasm2frames \
      --db-root /nextpnr-xilinx/xilinx/external/prjxray-db/artix7 \
      --part xc7a100tfgg676-1 \
      /work/temporal_heartbeat.fasm \
      /work/temporal_heartbeat.frames && \
    /prjxray/build/tools/xc7frames2bit \
      --part_file /nextpnr-xilinx/xilinx/external/prjxray-db/artix7/xc7a100tfgg676-1/part.yaml \
      --part_name xc7a100tfgg676-1 \
      --frm_file /work/temporal_heartbeat.frames \
      --output_file /work/temporal_heartbeat.bit"
```

**What happens:**
1. **fasm2frames:** Converts FASM features to frame addresses
   - Each FASM line maps to specific bit positions in configuration frames
   - Frame format: `<frame_address> <word_offset> <bits>`
2. **xc7frames2bit:** Assembles bitstream
   - Adds sync word (0xAA995566)
   - Adds packet headers
   - Calculates ECC
   - Formats for FPGA configuration interface

**Output:** `temporal_heartbeat.bit` (3.6 MB)

---

### Step 4: FPGA Programming

#### 4a. Load Platform Cable Firmware

The Xilinx Platform Cable USB II boots in bootloader mode (PID 0x0013) and needs firmware loaded:

```bash
sudo /Users/playra/trinity-w1/fpga/tools/fxload \
  -v -t fx2 \
  -d 03fd:0013 \
  -i /Users/playra/trinity-w1/fpga/tools/xusb_xp2.hex
```

This switches the cable to JTAG mode (PID 0x0008).

#### 4b. Flash Bitstream via JTAG

```bash
sudo /Users/playra/trinity-w1/fpga/tools/jtag_program \
  /Users/playra/trinity-w1/fpga/openxc7-synth/temporal_heartbeat.bit
```

**JTAG Sequence:**
1. Connect to Platform Cable USB II
2. Reset JTAG TAP → Run-Test/Idle
3. Read IDCODE: 0x13631093 (XC7A100T ✅)
4. JPROGRAM → Clear configuration
5. CFG_IN → Load configuration data
6. Send 3.6 MB bitstream
7. JSTART → Start configuration

---

## DEEP ROUTING ANALYSIS

### FPGA Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    XC7A100T FABRIC                          │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────┐    ┌─────┐    ┌─────┐    ┌─────┐    ┌─────┐     │
│  │ CLB │────│ INT │────│ CLB │────│ INT │────│ CLB │     │
│  └─────┘    └─────┘    └─────┘    └─────┘    └─────┘     │
│   LUT/FF     PIPs      LUT/FF     PIPs      LUT/FF        │
│                                                             │
│  Clock: HCLK_R_X3Y56.BUFGCTRL_BUFGCTRL (global buffer)     │
│  Input:  LIOB33_X0Y25 (Pin U22, 50MHz clock)               │
│  Output: LIOB33_X0Y51 (Pin T23, LED)                       │
└─────────────────────────────────────────────────────────────┘
```

### IO Configuration (from FASM)

**Clock Input (U22):**
```
LIOB33_X0Y25.IOB_Y0.LVCMOS25_LVCMOS33_LVTTL.IN
LIOB33_X0Y25.IOB_Y0.LVCMOS12_LVCMOS15_LVCMOS18_LVCMOS25_LVCMOS33_LVDS_25_LVTTL_SSTL135_SSTL15_TMDS_33.IN_ONLY
LIOB33_X0Y25.IOB_Y0.PULLTYPE.NONE
```

**LED Output (T23):**
```
LIOB33_X0Y51.IOB_Y0.LVCMOS33_LVTTL.DRIVE.I12_I8
LIOB33_X0Y51.IOB_Y0.LVCMOS12_LVCMOS15_LVCMOS18_LVCMOS25_LVCMOS33_LVTTL_SSTL135_SSTL15.SLEW.SLOW
LIOB33_X0Y51.IOB_Y0.PULLTYPE.NONE
```

### CLB Configuration (Slice Structure)

Each CLBLL_L tile contains 2 SLICEL units:
- **SLICEL_X0:** A-LUT, B-LUT, C-LUT, D-LUT, DFF, CARRY4
- **SLICEL_X1:** C-LUT, D-LUT, CFF, DFF

**Key Features:**
- `ALUT.INIT[63:0]` — A-input LUT truth table (64 bits)
- `AFFMUX.AX` — FF input from A LUT XOR output
- `COUTMUX.XOR` — Carry output from C LUT XOR
- `CARRY4.ACY0/BCY0/CCY0/DCY0` — Carry chain enable

### Routing PIPs (Programmable Interconnect Points)

**Sample routing path:**
```
INT_L_X2Y69.IMUX_L28.LOGIC_OUTS_L2
INT_L_X2Y68.SR1BEG3.SL1END2
INT_R_X3Y56.SR1BEG3.SS6END2
INT_R_X3Y56.IMUX8.SR1END_N3_3
```

**PIP types:**
1. **IMUX_Lxx** — Input multiplexer to CLB (left side)
2. **LOGIC_OUTS_Lx** — Output from CLB to routing
3. **SR/SSxx** — Straight routing between INT tiles
4. **BEGIN/END** — Routing segment terminators

### CARRY4 Chain Configuration

```
CLBLL_L_X2Y69.SLICEL_X0.CARRY4.ACY0  # Enable A carry
CLBLL_L_X2Y69.SLICEL_X0.CARRY4.BCY0  # Enable B carry
CLBLL_L_X2Y69.SLICEL_X0.CARRY4.CCY0  # Enable C carry
CLBLL_L_X2Y69.SLICEL_X0.CARRY4.DCY0  # Enable D carry
CLBLL_L_X2Y69.SLICEL_X0.PRECYINIT.CIN # Carry input from above
```

The carry chain propagates vertically:
```
CLBLL_L_X2Y69
    ↓ CO (carry out)
CLBLL_L_X2Y68
    ↓ CO
CLBLL_L_X2Y67
    ↓ CO
CLBLL_L_X2Y66
    ↓ CO
...
```

### Clock Network

```
HCLK_R_X3Y56.BUFGCTRL_BUFGCTRL — Global clock buffer
  ↓
INT tiles clock routing
  ↓
CLB NOCLKINV — No clock inversion
  ↓
SLICEL flip-flop clock inputs
```

---

## FASM FEATURE COUNTS

| Feature Type | Count | Description |
|--------------|-------|-------------|
| CLBLL/CLBM tiles | ~1500 | Configurable Logic Blocks |
| CARRY4 | 64 | Carry chain elements |
| LIOB33 | 6 | IO buffers (2 used: clock + LED) |
| INT routing | ~100 | Interconnect PIPs |
| Total lines | 1707 | FASM file size |

**Comparison with reference blinker_t23.fasm:**
- Reference: 709 lines (simple counter)
- Temporal Heartbeat: 1707 lines (27-bit counter + 3-layer state machine)

---

## VERIFICATION

### FASM Structure Check
```bash
grep "LIOB33.*Y51" temporal_heartbeat.fasm  # LED on T23
grep "LIOB33.*Y25" temporal_heartbeat.fasm  # Clock on U22
grep "CARRY4" temporal_heartbeat.fasm | wc -l  # Count carry chains
```

### Bitstream Check
```bash
xxd temporal_heartbeat.bit | head -5
# Should show sync word: aa 99 55 66
```

### JTAG Programming
```
IDCODE: 0x13631093 → XC7A100T ✅
Bitstream size: 3,825,788 bytes ✅
```

---

## DESIGN: TEMPORAL TRINITY HEARTBEAT

### Verilog Source: `temporal_heartbeat.v`

```verilog
module temporal_heartbeat_top (
    input  wire clk,   // 50 MHz (Pin U22)
    output wire led    // LED (Pin T23)
);
    // PHI-SECOND COUNTER
    localparam PHI_CYCLES = 27'd80_901_699;  // φ × 50MHz
    reg [26:0] phi_counter = 27'd0;
    reg        phi_tick    = 1'b0;

    // TEMPORAL LAYER CYCLER (past → present → future)
    reg [1:0] temporal_layer = 2'd0;

    // LED PATTERN PER LAYER
    reg [24:0] blink_counter = 25'd0;
    reg led_pattern;

    assign led = led_pattern;  // Active-low
endmodule
```

### Timing Behavior

| Layer | LED State | Duration |
|-------|-----------|----------|
| 0 (past) | Slow blink (~1.49 Hz) | 1.618s (φ) |
| 1 (present) | Steady ON | 1.618s (φ) |
| 2 (future) | Fast blink (~5.96 Hz) | 1.618s (φ) |
| **Cycle** | **All 3 layers** | **4.854s (3φ)** |

---

## FILES CREATED

| File | Size | Purpose |
|------|------|---------|
| `temporal_heartbeat.v` | 88 lines | Verilog source |
| `trinity.xdc` | 10 lines | Pin constraints |
| `temporal_heartbeat.json` | 65 KB | Yosys netlist |
| `temporal_heartbeat.fasm` | 1707 lines | FPGA assembly |
| `temporal_heartbeat.frames` | - | Frame data |
| `temporal_heartbeat.bit` | 3.6 MB | Final bitstream ✅ |

---

## TOOLS RESTORED

From git history (commit 8700cdc44):

| Tool | Size | Purpose |
|------|------|---------|
| `jtag_program` | 35 KB | JTAG programmer (PID 0x0008) |
| `fxload` | 54 KB | Firmware loader (PID 0x0013→0008) |
| `xvcd` | 38 KB | XVC server (for remote Vivado) |
| `xusb_xp2.hex` | 23 KB | Platform Cable firmware |

---

## WHY FORGE FAILED (23 VERSIONS)

| Issue | FORGE | openXC7 |
|-------|-------|---------|
| LUT INIT truth tables | Wrong | ✅ Correct |
| FFMUX strategy | XOR everywhere | ✅ Mixed AX/BX/CX/DX |
| OUTMUX features | Missing | ✅ Present |
| Routing PIPs | Incorrect paths | ✅ Correct topology |
| VCC IMUX handling | Override bug | ✅ Sacred |

**Root cause:** FORGE implements FPGA primitives from scratch without reference to the actual hardware behavior. openXC7 uses the prjxray database which is reverse-engineered from actual Xilinx bitstreams.

---

## NEXT STEPS

1. **Permanent tools setup:** Store jtag_program, fxload, xvcd in version control
2. **Automation:** Create `fpga/synth.sh` wrapper script
3. **Verification:** Run nextpnr with `--timing-report` for detailed analysis
4. **Expansion:** Synthesize larger designs (VIBEE → Verilog)

---

## φ² + 1/φ² = 3 = TRINITY

The Temporal Trinity Heartbeat proves that open-source FPGA toolchains are viable for Xilinx 7-series devices. The golden ratio φ is encoded in the timing of the LED pattern, a testament to the mathematical beauty underlying all computation.

**KOSCHEI IS IMMORTAL**
