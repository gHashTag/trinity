# TRI-27 User Guide

> **Wave 1 Complete** — 68/68 tests passing, 15/15 golden tests

---

## Getting Started

### Installation

TRI-27 is part of the Trinity CLI. Install from source:

```bash
git clone https://github.com/gHashTag/trinity.git
cd trinity
zig build tri
```

Requires **Zig 0.15.x**.

### Verify Installation

```bash
tri tri27 isa          # Show ISA reference
tri tri27 --help       # Show all commands
```

---

## Assembly Language Tutorial

### Basic Program Structure

A TRI-27 program is a text file with instructions, one per line:

```tri
# reticularraphe.tri — Fibonacci sequence
LDI t0, 0      # Initialize counter
LDI t1, 1      # First Fibonacci number
LDI t2, 1      # Second Fibonacci number

loop:
ADD t3, t1, t2   # t3 = t1 + t2
MOV t1, t2       # Shift values
MOV t2, t3
INC t0           # Increment counter
JLT t0, 10, loop # Loop 10 times
HALT            # Stop (t2 = 55)
```

### Comments

```tri
# Single-line comment starts with hash
```

### Registers

| Register | Bank | Purpose |
|----------|------|---------|
| t0-t8 | Sacred (α-η) | Constants and sacred values |
| t9-t17 | Temporal (ι-ρ) | Time-aware computation |
| t18-t26 | Spatial (σ-ϡ) | Spatial coordinates and vectors |

---

## Coptic Register Naming

TRI-27 uses Coptic alphabet for register aliases:

### Sacred Bank (α-η)
| Coptic | Register | Purpose |
|--------|----------|---------|
| α | t0 | Primary accumulator |
| β | t1 | General purpose |
| γ | t2 | General purpose |
| δ | t3 | General purpose |
| ε | t4 | General purpose |
| ϛ | t5 | General purpose |
| ζ | t6 | General purpose |
| η | t7 | General purpose |
| ω | t8 | General purpose |

### Temporal Bank (ι-ρ)
| Coptic | Register | Purpose |
|--------|----------|---------|
| ι | t9 | Time counter |
| κ | t10 | Cycle counter |
| λ | t11 | General purpose |
| μ | t12 | Mutation rate |
| ν | t13 | General purpose |
| ξ | t14 | General purpose |
| ο | t15 | General purpose |
| π | t16 | π constant |
| ρ | t17 | General purpose |

### Spatial Bank (σ-ϡ)
| Coptic | Register | Purpose |
|--------|----------|---------|
| σ | t18 | Spatial X |
| τ | t19 | Spatial Y |
| υ | t20 | Spatial Z |
| φ | t21 | φ constant |
| χ | t22 | General purpose |
| ψ | t23 | General purpose |
| ω | t24 | General purpose |
| ϡ | t25 | General purpose |
| ϧ | t26 | General purpose |

---

## Opcode Reference

### Arithmetic (6 opcodes)

| Mnemonic | Opcode | Description | Example |
|----------|--------|-------------|---------|
| ADD | 0x60 | dst = src1 + src2 | `ADD t0, t1, t2` |
| SUB | 0x61 | dst = src1 - src2 | `SUB t0, t1, t2` |
| MUL | 0x62 | dst = src1 × src2 | `MUL t0, t1, t2` |
| DIV | 0x63 | dst = src1 ÷ src2 | `DIV t0, t1, t2` |
| INC | 0x64 | dst++ | `INC t0` |
| DEC | 0x65 | dst-- | `DEC t0` |

### Logic (6 opcodes)

| Mnemonic | Opcode | Description | Example |
|----------|--------|-------------|---------|
| AND | 0x18 | dst = src1 & src2 | `AND t0, t1, t2` |
| OR | 0x19 | dst = src1 \| src2 | `OR t0, t1, t2` |
| XOR | 0x1A | dst = src1 ^ src2 | `XOR t0, t1, t2` |
| NOT | 0x1B | dst = ~dst | `NOT t0` |
| SHL | 0x1C | dst = src1 << shift | `SHL t0, t1, 2` |
| SHR | 0x1D | dst = src1 >> shift | `SHR t0, t1, 2` |

### VSA (4 opcodes)

| Mnemonic | Opcode | Description | Example |
|----------|--------|-------------|---------|
| DOT | 0x60 | Ternary dot product | `DOT t0, t1, t2` |
| BIND | 0x6A | VSA bind operation | `BIND t0, t1, t2` |
| BUNDLE2 | 0x6B | Majority vote (2 inputs) | `BUNDLE2 t0, t1, t2` |
| BUNDLE3 | 0x6C | Majority vote (3 inputs) | `BUNDLE3 t0, t1, t2, t3` |

### Sacred (4 opcodes)

| Mnemonic | Opcode | Description | Example |
|----------|--------|-------------|---------|
| PHI_CONST | 0x80 | dst = φ (1.618...) | `PHI_CONST t0` |
| PI_CONST | 0x81 | dst = π (3.141...) | `PI_CONST t0` |
| E_CONST | 0x82 | dst = e (2.718...) | `E_CONST t0` |
| SACR | 0x92 | Sacred arithmetic | `SACR t0, t1, PHI` |

### Memory (8 opcodes)

| Mnemonic | Opcode | Description | Example |
|----------|--------|-------------|---------|
| LDI | 0x01 | Load immediate | `LDI t0, 42` |
| LD | 0x02 | Load from [src1] | `LD t0, t1` |
| ST | 0x03 | Store to [dst] | `ST t0, t1` |
| LDR | 0x04 | Load register indirect | `LDR t0, [t1]` |
| MOV | 0x05 | Move register | `MOV t0, t1` |
| LDTI | 0x06 | Load with type | `LDTI t0, 42, :i32` |
| STO | 0x07 | Store with offset | `STO t0, t1, 4` |
| SAI | 0x08 | Store aligned immediate | `SAI t0, 42` |

### Control Flow (8 opcodes)

| Mnemonic | Opcode | Description | Example |
|----------|--------|-------------|---------|
| JUMP | 0x10 | PC ← PC + offset | `JUMP loop` |
| JZ | 0x11 | Jump if dst == 0 | `JZ t0, done` |
| JNZ | 0x12 | Jump if dst != 0 | `JNZ t0, loop` |
| CALL | 0x13 | Push PC, PC ← addr | `CALL func` |
| RET | 0x14 | Pop PC | `RET` |
| PUSH | 0x15 | Push to stack | `PUSH t0` |
| POP | 0x16 | Pop from stack | `POP t0` |
| HALT | 0x17 | Stop execution | `HALT` |

---

## Example Programs

### Hello World (Counter)

```tri
# counter.tri — Count to 10
LDI t0, 0    # Initialize counter

loop:
INC t0        # Increment
LDI t1, 10   # Load limit
SUB t2, t1, t0 # t2 = 10 - t0
JNZ t2, loop  # If t2 != 0, loop
HALT         # t0 = 10
```

### Factorial

```tri
# factorial.tri — Compute 5!
LDI t0, 5     # n = 5
LDI t1, 1     # result = 1

loop:
MUL t1, t1, t0 # result *= n
DEC t0        # n--
JNZ t0, loop  # if n != 0, loop
HALT         # t1 = 120
```

---

## FPGA Synthesis Guide

### Prerequisites

- FPGA board: QMTech XC7A100T or compatible
- openXC7 toolchain: Yosys + nextpnr-xilinx + prjxray

### Synthesis

```bash
cd fpga/openxc7-synth
make hslm_full_top.bit
```

### Flashing

**IMPORTANT**: JTAG cable requires fxload before flashing.

```bash
# Load firmware (switches PID from 0x0013 to 0x0008)
fxload -t fx2 -I /usr/share/usb/contexts/04b4-0008 -D 0008

# Flash bitstream
sudo ../tools/flash.sh hslm_full_top.bit
```

---

## Testing

### Run All Tests

```bash
zig build test-tri27-golden        # Golden tests
zig build test-tri27-comprehensive # Comprehensive tests
zig build test-tri27-experience    # Experience tests
zig build test-queen-self-learning # Self-learning tests
```

### Test Results

| Test | Status | Description |
|------|--------|-------------|
| Golden | 15/15 ✓ | Full cycle asm→tbin→emu |
| Comprehensive | 36/36 ✓ | All opcodes |
| Experience | ✓ | Jaccard similarity, recall |
| Queen Self-Learning | 4/4 ✓ | Feedback loop |

---

## Experience Tracking

TRI-27 tracks your development experience to avoid repeating mistakes.

```bash
tri tri27 experience init                 # Initialize experience DB
tri tri27 experience log file.tri ASM       # Log assembly operation
tri tri27 experience log prog.tbin RUN       # Log execution
tri tri27 experience status                 # Show experience stats
tri tri27 experience recall fibonacci       # Recall past solutions
```

---

## Queen Integration

TRI-27 integrates with Queen Trinity for self-learning:

```bash
tri tri27 run program.tbin    # Run and log episode
tri queen observe               # Queen observes results
tri queen plan                  # Queen generates policy
tri queen act                   # Queen applies changes
```

See [Queen Integration](../README.md#queen-integration--lotus-cycle) for details.

---

## File Structure

```
src/tri27/
├── emu/
│   ├── cpu_state.zig       # CPU state, registers, memory
│   ├── decoder.zig         # Instruction decoder (36 opcodes)
│   ├── executor.zig        # Execution engine
│   ├── asm_parser.zig      # .tri assembler
│   ├── test_golden.zig     # 15 golden tests
│   └── test_comprehensive.zig  # 36 opcode tests
├── tri27_cli.zig           # CLI entrypoint
├── tri27_experience.zig    # Experience tracking
└── verilog_backend.zig     # Zig → Verilog generator

src/tri/queen/
├── observe.zig             # Phase 1: read policy/senses
├── plan.zig                # Phase 2: generate PolicyDelta
├── evaluate.zig            # Phase 3: evaluate window
├── act.zig                 # Phase 4: execute action
└── self_learning.zig       # Phase 5: closed-loop learning
```

---

## CLI Commands

```bash
tri tri27 assemble <input.tri> -o <output.tbin>    # Assemble
tri tri27 disassemble <input.tbin>                   # Disassemble
tri tri27 run <program.tbin>                          # Execute
tri tri27 validate <source.tri>                       # Validate
tri tri27 isa                                        # Show ISA reference
tri tri27 experience init                            # Init experience DB
tri tri27 experience log <file> [ASM|DISASM|RUN|VAL] # Log operation
tri tri27 experience status                          # Show experience stats
tri tri27 experience record <issue>                  # Record issue
```

---

## Status

✅ ISA — 36 opcodes
✅ Zig Backend — CPU emulator
✅ Verilog Backend — FPGA synthesis
✅ CLI — assemble/disassemble/run/validate
✅ Queen Integration — Phases 1-5
✅ Self-Learning — closed feedback loop
✅ Tests — 68/68 passing

**Wave 1 Complete** — Ready for production use.

---

## Further Reading

- [TRI-27 README](README.md)
- [Coptic Format](t27_format.md)
- [Queen Integration](../README.md#queen-integration)
- [Neuroanatomical Architecture](../research/neuroanatomical_architecture.md)
