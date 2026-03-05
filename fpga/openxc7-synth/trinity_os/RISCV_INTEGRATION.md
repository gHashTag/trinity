# TRINITY OS RISC-V Integration

## Overview

TRINITY V3 integrates a RISC-V processor (VexRiscv) with the existing VSA/TQNN hardware accelerators and OS scheduler.

### Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│  TRINITY V3 - Macro-Kernel with RISC-V                              │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐        │
│  │   RISC-V     │    │  TRINITY OS  │    │  VSA + TQNN  │        │
│  │  (VexRiscv)  │◄──►│  Scheduler   │◄──►│  Hardware    │        │
│  │              │    │              │    │              │        │
│  │  RV32IMC     │    │  16 tasks    │    │  10K trits   │        │
│  │  Wishbone    │    │  Phi-weighted│    │  16 qutrits  │        │
│  └──────────────┘    └──────────────┘    └──────────────┘        │
│         │                   │                   │                 │
│         └───────────────────┴───────────────────┘                 │
│                             │                                      │
│                    ┌────────┴────────┐                            │
│                    │  Wishbone Bus   │                            │
│                    │  + Interrupts   │                            │
│                    └─────────────────┘                            │
│                             │                                      │
│         ┌───────────────────┴───────────────────┐                 │
│         │             BRAM Memory               │                 │
│         │  4KB Instructions + 4KB Data           │                 │
│         └───────────────────────────────────────┘                 │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

## Files Created

| File | Purpose |
|------|---------|
| `trinity_os/vexriscv_wrapper.v` | RISC-V CPU + Wishbone bus + BRAM |
| `trinity_v3_riscv.v` | Top-level integration module |
| `riscv/test_program.c` | C test program |
| `riscv/test_program.zig` | Zig test program |
| `build_riscv.sh` | Build script |

## Resource Usage (XC7A100T)

| Component | LUTs | FFs | BRAMs | DSPs |
|-----------|------|-----|-------|------|
| RISC-V VexRiscv | ~2,500 | ~1,500 | 2 | 0 |
| VSA + TQNN (V2) | ~4,000 | ~2,500 | 4 | 0 |
| OS Scheduler | ~3,000 | ~2,000 | 4 | 0 |
| Interrupt Ctrl | ~800 | ~400 | 0 | 0 |
| **TOTAL** | **~10,300** | **~6,400** | **10** | **0** |

**~10% of device** - 90% remaining for expansion!

## Interrupt Map

| IRQ | Source | Description |
|-----|--------|-------------|
| 0 | UART_RX | UART receive data available |
| 1 | UART_TX | UART transmit complete |
| 2 | VSA_COMPLETE | VSA operation finished |
| 3 | TQNN_COMPLETE | TQNN layer finished |
| 4 | TIMER_PREEMPT | Task preemption timer |
| 5 | YIELD | Task yield request |
| 6 | FAULT | CPU fault/error |
| 7 | SPARE | Reserved |

## Building

### Prerequisites

```bash
# RISC-V toolchain (for test programs)
brew install riscv-tools

# Yosys (for synthesis)
brew install yosys

# Zig (optional, for Zig programs)
# Already installed if you're working on TRINITY
```

### Build Steps

```bash
cd fpga/openxc7-synth

# 1. Synthesize TRINITY V3
./build_riscv.sh

# 2. Build test program (optional)
./build_riscv.sh --test

# 3. Generate bitstream (when JTAG arrives)
docker run --rm -v "$(pwd):/work" -w /work \
    regymm/openxc7 \
    nextpnr-xilinx --chip xc7a100tfgg676-1 \
    --json build/riscv/trinity_v3.json \
    --fasm build/riscv/trinity_v3.fasm
```

## Test Program

The `test_program.zig` demonstrates:

1. **ALU Operations**: Fibonacci calculation
2. **Memory Access**: Read/write test
3. **Lucas Numbers**: TRINITY sequence (L(2)=3)
4. **LED Pattern**: Sacred blink pattern

### Expected LED Behavior

```
1. Three slow blinks (TRINITY = 3)
2. Five fast blinks (Fibonacci 10 = 55 → 55 % 10 = 5)
3. Four fast blinks (Lucas 10 = 123 → 123 % 7 = 4)
4. Pause
5. Repeat forever
```

## Memory Map

| Address Range | Size | Description |
|---------------|------|-------------|
| 0x0000-0x0FFF | 4KB | Instruction BRAM |
| 0x1000-0x1FFF | 4KB | Data BRAM |
| 0x1000 | 4B | LED Control (memory-mapped I/O) |
| 0x2000 | 4B | UART TX Data |
| 0x2004 | 4B | UART Status |

## VexRiscv Configuration

For production, generate the full VexRiscv core:

```bash
# 1. Clone VexRiscv
git clone https://github.com/SpinalHDL/VexRiscv
cd VexRiscv

# 2. Create custom config (TrinityRiscvConfig.scala)
# See: https://vexriscv.github.io/

# 3. Generate Verilog
sbt "runMain vexriscv.GenCore -rTrinityRiscvConfig"

# 4. Copy generated VexRiscv.v to trinity_os/
cp VexRiscv.v ../trinity-w1/fpga/openxc7-synth/trinity_os/
```

### Current Implementation

The `vexriscv_wrapper.v` contains a **simplified RV32IC** core for development:

- Instructions: ADDI, XORI, ORI, ANDI, ADD, SUB, XOR, OR, AND, SLL, SRL
- Branches: BEQ, BNE, BLT, BGE
- Loads/Stores: LB, LH, LW, SB
- Control: JAL, JALR, LUI, AUIPC

**Not implemented:** M-extension (multiply), C-extension (compressed)

## Next Steps

- [ ] Generate full VexRiscv core (Scala → Verilog)
- [ ] Add M-extension (multiply/divide)
- [ ] Add C-extension (compressed instructions)
- [ ] Implement UART driver in RISC-V code
- [ ] Add VSA/TQNN driver functions
- [ ] Create TRINITY OS syscall interface
- [ ] Test on real hardware (when JTAG arrives)

## Golden Identity

```
φ² + 1/φ² = 3 = TRINITY
```

Verified at compile time in all TRINITY OS modules.

---

*Generated for TRINITY OS v2.0 - Week 3 Day 1*
