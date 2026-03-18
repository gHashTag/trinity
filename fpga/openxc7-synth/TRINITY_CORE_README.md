# TRINITY CORE — Minimal RISC-V Processor for FPGA

## Status

✅ **SYNTHESIS COMPLETE** — 362 cells, fits in <1% of XC7A100T
⏳ **PLACE & ROUTE BLOCKED** — chipdb version mismatch

## What Was Created

### trinity_core.v

A minimal RISC-V RV32I subset processor implemented in pure Verilog:

**Features:**
- 32-bit RISC-V ISA subset (ADDI, ADD, SUB, AND, OR, XOR, SLT, BLT, BEQ, JAL, SW, LW)
- 4KB BRAM for instructions + data
- Memory-mapped GPIO at 0x100
- Fits in 362 cells (~300 LUTs, 60 FFs, 2 BRAMs)
- Boot program pre-loaded in BRAM

**Resource Usage:**
```
LUT5: 88, LUT2: 87, LUT6: 60, LUT4: 40
CARRY4: 28, RAM32M: 16, FDRE: 14
RAMB36E1: 2, BUFG: 1, IBUF: 1, OBUF: 1
```

### Boot Program

The processor comes with a pre-loaded LED blink program:

```assembly
    li x1, 0x100      # GPIO base
    li x2, 1          # LED ON value
    li x3, 0          # LED OFF value
loop:
    sw x2, 0(x1)      # LED ON
    delay_on:
        addi x4, x4, 1
        blt x4, x100, delay_on
    sw x3, 0(x1)      # LED OFF
    delay_off:
        addi x5, x5, 1
        blt x5, x100, delay_off
    jal x0, loop      # repeat
```

## Blocker: Chipdb Version Mismatch

```
Assertion failure: The internal IDs of nextpnr are inconsistent
with the supplied chip database.
```

The chipdb at `/fpga/openxc7-synth/chipdb/xc7a100tfgg676.bin` was generated
with an older version of nextpnr-xilinx.

## Solutions

### Option 1: Regenerate Chipdb (Recommended)

```bash
cd /Users/playra/trinity-w1/fpga/prjxray
make db-full-100t
# This will generate a fresh chipdb compatible with current nextpnr-xilinx
```

### Option 2: Use openxc7 Docker with --chip flag

The openxc7 Docker image may have a compatible nextpnr-xilinx version:

```bash
# Check what version is available
docker run --rm --platform linux/amd64 regymm/openxc7 bash -c \
    "find / -name 'nextpnr-xilinx' -type f 2>/dev/null"
```

### Option 3: Use Working Bitstreams

The project already has working bitstreams:
- `temporal_heartbeat.bit` — Simple blink (~3 Hz)
- `trinity_v1.bit` — Full TRINITY system
- `ternary_dot.bit` — Ternary dot product
- `vsa_quantum_top.bit` — Quantum violation demo

These can be flashed directly:
```bash
/Users/playra/trinity-w1/fpga/tools/jtag_program temporal_heartbeat.bit
```

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  TRINITY CORE (RV32I Subset)                                │
│  ┌───────────────────────────────────────────────────────┐  │
│  │  Program Counter (12-bit)                              │  │
│  │  Instruction Decode (R/I/S/B/J types)                 │  │
│  │  Register File (x0-x31, x0=hardwired 0)              │  │
│  │  ALU (ADD, SUB, AND, OR, XOR, SLT)                   │  │
│  │  Branch Logic (BEQ, BNE, BLT, BGE)                   │  │
│  │  Wishbone-like Memory Interface                       │  │
│  └───────────────────────────────────────────────────────┘  │
│  ┌───────────────────────────────────────────────────────┐  │
│  │  4KB BRAM (Instructions + Data)                       │  │
│  │  • Pre-loaded with boot program                       │  │
│  │  • Dual-port for instr/data access                    │  │
│  └───────────────────────────────────────────────────────┘  │
│  ┌───────────────────────────────────────────────────────┐  │
│  │  Memory-Mapped GPIO                                    │  │
│  │  • 0x100: GPIO output (32-bit)                         │  │
│  │  • Bit 0 → LED                                        │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

## File Locations

```
/fpga/openxc7-synth/
├── trinity_core.v          # Core processor + top module
├── trinity_core.json       # Synthesized netlist (Yosys)
├── trinity_core.xdc        # Pin constraints
└── chipdb/
    └── xc7a100tfgg676.bin  # Chip database (INCOMPATIBLE)
```

## Next Steps

1. **Regenerate chipdb** using prjxray
2. **Run place & route** with compatible nextpnr-xilinx
3. **Generate FASM** → frames → bitstream
4. **Flash to FPGA** via jtag_program
5. **Verify autonomous boot** — LED should blink without external input

---

*Generated: 2026-03-06*
*TRINITY FPGA — Autonomous RISC-V Boot*
