# FPGA ROUTING DEEP DIVE
## Xilinx Artix-7 XC7A100T — Temporal Trinity Heartbeat

**Author:** Claude Code
**Date:** 2026-03-03
**Tool:** nextpnr-xilinx (via regymm/openxc7 Docker)

---

## TABLE OF CONTENTS

1. [Architecture Overview](#architecture-overview)
2. [Tile Types and Functions](#tile-types-and-functions)
3. [Routing Resources](#routing-resources)
4. [PIP Configuration](#pip-configuration)
5. [Clock Distribution](#clock-distribution)
6. [Signal Path Analysis](#signal-path-analysis)
7. [Comparison: FORGE vs openXC7](#comparison-forge-vs-openxc7)

---

## ARCHITECTURE OVERVIEW

### Xilinx 7-Series Fabric Hierarchy

```
┌────────────────────────────────────────────────────────────────────┐
│                        XC7A100T DIE                                │
├────────────────────────────────────────────────────────────────────┤
│                                                                    │
│  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐              │
│  │  CLBLL  │  │   INT   │  │  CLBLM  │  │   INT   │              │
│  │  X2Y69  │  │  X2Y69  │  │  X3Y69  │  │  X3Y69  │              │
│  │ SLICEL  │──│ Routing │──│ SLICEM  │──│ Routing │              │
│  │ SLICEL  │  │ Network │  │ SLICEM  │  │ Network │              │
│  └─────────┘  └─────────┘  └─────────┘  └─────────┘              │
│       │            │            │            │                     │
│       └────────────┴────────────┴────────────┘                     │
│                    Vertical/Horizontal                             │
│                    Interconnect (PIP)                              │
│                                                                    │
│  ┌─────────────────────────────────────────────────────┐          │
│  │              HCLK_R_X3Y56 (Clock Column)             │          │
│  │  ┌─────────┐  ┌─────────┐  ┌─────────┐              │          │
│  │  │ BUFGCTRL│  │  BUFH   │  │  BUFH   │              │          │
│  │  └─────────┘  └─────────┘  └─────────┘              │          │
│  └─────────────────────────────────────────────────────┘          │
│                                                                    │
│  ┌─────────────────────────────────────────────────────┐          │
│  │           IO Column (Left/Right Edges)               │          │
│  │  ┌─────────┐  ┌─────────┐                           │          │
│  │  │LIOB33   │  │LIOB33   │  ... (IO buffers)          │          │
│  │  │ X0Y25   │  │ X0Y51   │                           │          │
│  │  │ (CLK)   │  │ (LED)   │                           │          │
│  │  └─────────┘  └─────────┘                           │          │
│  └─────────────────────────────────────────────────────┘          │
└────────────────────────────────────────────────────────────────────┘
```

---

## TILE TYPES AND FUNCTIONS

### 1. CLBLL_L (Configurable Logic Block — Logic, Left)

**Location:** X2Y54-X2Y69 (16 tiles used)

**Contents per tile:**
- 2 × SLICEL (Logic-only slices)
  - Each SLICEL contains:
    - 4 × 6-input LUTs (A, B, C, D)
    - 4 × Flip-Flops (AFF, BFF, CFF, DFF)
    - 1 × CARRY4 (arithmetic chain)
    - MUXes: AOUTMUX, BOUTMUX, COUTMUX, DOUTMUX
    - FFMUX: AX, BX, CX, DX, XOR

**SLICEL_X0 Features:**
```
ALUT.INIT[63:0]  — A-LUT truth table
BLUT.INIT[63:0]  — B-LUT truth table
CLUT.INIT[63:0]  — C-LUT truth table
DLUT.INIT[63:0]  — D-LUT truth table
AFFMUX           — Selects FF input source
CARRY4           — Fast carry chain
```

### 2. CLBLM_R (Configurable Logic Block — Logic/Memory, Right)

**Location:** X3Y55-X3Y56

**Difference from CLBLL:**
- SLICEM can be configured as:
  - Distributed RAM (64×1, 32×2, 16×4)
  - Shift register (SRL16, SRL32)
  - Standard logic (like SLICEL)

### 3. INT_R/INT_L (Interconnect Tiles)

**Purpose:** Provide routing between CLBs

**Structure per INT tile:**
- 16 × IMUX_L (left input multiplexers)
- 16 × IMUX_R (right input multiplexers)
- 16 × IMUX_T (top input multiplexers)
- 16 × IMUX_B (bottom input multiplexers)
- LOGIC_OUTS_L (left outputs)
- LOGIC_OUTS_R (right outputs)
- SR/SS routing (straight connections)

### 4. HCLK_R (High-Fanout Clock Column)

**Location:** X3Y56

**Contents:**
- BUFGCTRL — Global clock buffer with select
- BUFH — Horizontal clock buffer
- Clock routing PIPs

### 5. LIOB33 (Input/Output Buffer)

**Locations:**
- X0Y25 — Pin U22 (Clock input)
- X0Y51 — Pin T23 (LED output)

**Configuration:**
```
LVCMOS33_LVTTL.IN        — 3.3V input standard
PULLTYPE.NONE            — No pullup/pulldown
DRIVE.I12_I8             — 8mA drive strength
SLEW.SLOW                — Slow slew rate
```

---

## ROUTING RESOURCES

### Routing Hierarchy

```
1. GLOBAL CLOCK NETWORK
   └── BUFGCTRL → HCLK column → CLB clock pins

2. LONG-LINE ROUTING
   └── Spans multiple tiles (H6, V6 wires)

3. HEX ROUTING
   └── Spans 6 tiles (H6, V6)

4. QUAD ROUTING
   └── Spans 4 tiles (H4, V4)

5. DOUBLE ROUTING
   └── Spans 2 tiles (H2, V2)

6. SINGLE ROUTING
   └── Adjacent tiles (H1, V1)

7. LOCAL ROUTING
   └── Within CLB (direct connections)
```

### Wire Naming Convention

```
<tile>_<direction>_<track>_<type>

Examples:
INT_L_X2Y69.IMUX_L28    — Input MUX 28, Left side
INT_L_X2Y69.LOGIC_OUTS_L2 — Logic Output 2, Left side
INT_R_X3Y56.SR1BEG3     — Straight Route 1, Begin 3
```

---

## PIP CONFIGURATION

### PIP (Programmable Interconnect Point)

A PIP is a configurable connection between two wires:

```
<source_wire>.<destination_wire>

Example: INT_L_X2Y69.IMUX_L28.LOGIC_OUTS_L2
         └────┬────┘ └───────┬─────────┘
              Source            Destination
```

### PIP Types in Temporal Heartbeat

**1. IMUX PIPs (Input to CLB)**
```fasm
INT_L_X2Y69.IMUX_L28.LOGIC_OUTS_L2
INT_L_X2Y68.IMUX_L16.SR1END_N3_3
INT_R_X3Y56.IMUX8.SR1END_N3_3
```

**2. LOGIC_OUTS PIPs (CLB output to routing)**
```fasm
INT_L_X2Y69.SE2BEG2.LOGIC_OUTS_L2
```

**3. SR/SS PIPs (Straight routing)**
```fasm
INT_R_X3Y56.SR1BEG3.SS6END2
INT_R_X3Y62.SS6BEG2.SS6END2
INT_L_X2Y68.SR1BEG3.SL1END2
```

**4. BEGIN/END PIPs (Routing terminators)**
```fasm
INT_R_X3Y56.SR1BEG3.SS6END2      # Begin SR1, End SS6
INT_R_X3Y56.IMUX8.SR1END_N3_3    # Connect SR1END to IMUX8
```

### PIP Directionality

```
BEGIN ──────► [wire] ──────► END
  │                           │
  └── Source                  └── Destination
```

---

## CLOCK DISTRIBUTION

### Clock Path Analysis

```
External Clock (50 MHz, Pin U22)
    │
    ▼
┌─────────────┐
│ LIOB33      │ X0Y25.IOB_Y0.LVCMOS25...IN
│ X0Y25       │
└─────────────┘
    │
    ▼ (PCB trace)
┌─────────────┐
│ HCLK_R      │ X3Y56.BUFGCTRL_BUFGCTRL
│ X3Y56       │ (Global clock buffer)
└─────────────┘
    │
    ▼ (Global clock network)
┌─────────────────────────────────┐
│ CLBLL_L Columns (X2)            │
│ ├─ Y69: NOCLKINV              │
│ ├─ Y68: NOCLKINV              │
│ ├─ Y67: NOCLKINV              │
│ └─ ... (all slices)            │
└─────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────┐
│ SLICEL Flip-Flops              │
│ AFF, BFF, CFF, DFF             │
│ (Clock input from global net)  │
└─────────────────────────────────┘
```

### Clock Configuration Features

```fasm
# No clock inversion
CLBLL_L_X2Y69.SLICEL_X0.NOCLKINV
CLBLL_L_X2Y69.SLICEL_X1.NOCLKINV
# ... (repeated for all slices)
```

---

## SIGNAL PATH ANALYSIS

### Example Signal: Counter Bit 0

**Source:** SLICEL_X0.DFF (D flip-flop) in CLBLL_L_X2Y69

**Path:**
```
1. SLICEL_X0.DFF.Q (Flip-flop output)
   │
2. SLICEL_X0.DOUTMUX.XOR (D LUT XOR → MUX)
   │
3. CLBLL local routing to INT tile
   │
4. INT_L_X2Y69.LOGIC_OUTS_L2
   │
5. INT_L_X2Y69.IMUX_L28.LOGIC_OUTS_L2 (PIP)
   │
6. INT_L_X2Y69.IMUX_L28 → CLB input
   │
7. Destination SLICEL ALUT/DLUT input
```

### Carry Chain Signal Path

```
CLBLL_L_X2Y69.CARRY4.CO (Carry Out)
    │
    ▼ (Vertical COUT/CIN dedicated path)
CLBLL_L_X2Y68.CARRY4.CIN (Carry In)
    │
    ▼
CLBLL_L_X2Y68.CARRY4.CO
    │
    ▼
CLBLL_L_X2Y67.CARRY4.CIN
    │
    ▼
...
```

**Key insight:** Carry chains use **dedicated vertical routing** that doesn't consume general routing resources. This is why the CARRY4.CO → CARRY4.CIN connection has no INT tile PIPs.

### LED Output Signal Path

```
SLICEL_X0 (in CLBLL_L_X2Y56)
    │ DFF.Q
    ▼
DOUTMUX.XOR
    │
    ▼ (Local routing)
INT tile routing (multiple hops)
    │
    ▼
INT_R_X3Y56 → INT_R_X3Y55 → ... → INT_R_X3Y51
    │
    ▼
LIOB33_X0Y51 (IOB_Y0)
    │
    ▼
Pin T23 (LED, active-low)
```

---

## COMPARISON: FORGE vs openXC7

### LUT INIT Truth Tables

| Tool | Strategy | Result |
|------|----------|--------|
| FORGE | Custom calculation | Wrong bits → no function |
| openXC7 | ABC9 optimizer | Correct truth tables ✅ |

### FFMUX Configuration

| Tool | Strategy | Result |
|------|----------|--------|
| FORGE | XOR everywhere | Suboptimal timing |
| openXC7 | Mixed AX/BX/CX/DX | Optimized per signal ✅ |

### OUTMUX Features

| Tool | Status | Impact |
|------|--------|--------|
| FORGE | Missing | Can't route some outputs |
| openXC7 | Present | All outputs routable ✅ |

### Routing PIPs

| Tool | Strategy | Result |
|------|----------|--------|
| FORGE | Custom router | Wrong PIPs, broken connections |
| openXC7 | Heuristic router | Valid PIPs ✅ |

### VCC IMUX Handling

| Tool | Strategy | Result |
|------|----------|--------|
| FORGE | Signal override | VCC tieoffs broken |
| openXC7 | Never route through VCC | Correct ✅ |

---

## CONCLUSION

The openXC7 toolchain (Yosys + nextpnr-xilinx + prjxray) succeeds because:

1. **Yosys ABC9** generates correct LUT truth tables
2. **nextpnr router** uses valid PIPs from chipdb
3. **prjxray database** is reverse-engineered from actual Xilinx bitstreams
4. **Heuristic algorithms** have been validated on thousands of designs

FORGE failed because it reimplemented complex FPGA primitives without reference to actual hardware behavior.

**φ² + 1/φ² = 3 = TRINITY**
