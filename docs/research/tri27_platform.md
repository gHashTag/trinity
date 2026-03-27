# TRI-27 Platform — Ternary Computing Research Infrastructure

## Overview

TRI-27 is a microsubstrate for ternary computing research: a RISC processor with 27 ternary registers and 36 opcodes. Full development stack: from ISA specification to FPGA bitstream.

**Mathematical Foundation**: φ² + 1/φ² = 3 = TRINITY

---

## Architecture

### Word Layout (32-bit instruction)

| Bits | Field | Description |
|------|-------|-------------|
| [31:26] | opcode | 6-bit operation code (36 opcodes) |
| [25:20] | dst | Destination register (t0-t26) |
| [19:14] | src1 | Source register 1 |
| [13:8]  | src2 | Source register 2 (or shift amount) |
| [7:0]   | imm8 | 8-bit immediate (or unused) |

### Registers

| Register | Size | Purpose |
|----------|------|---------|
| t0-t26 | 27×32-bit | Ternary registers (t0 = accumulator) |
| pc | 32-bit | Program Counter |
| flags | {Z, N, C, H, O} | Status flags |

### ISA — 36 Opcodes

#### Arithmetic (6)
| Opcode | Mnemonic | Description |
|--------|----------|-------------|
| 0x60 | ADD | dst = src1 + src2 |
| 0x61 | SUB | dst = src1 - src2 |
| 0x62 | MUL | dst = src1 × src2 |
| 0x63 | DIV | dst = src1 ÷ src2 |
| 0x64 | INC | dst++ |
| 0x65 | DEC | dst-- |

#### Logic (6)
| Opcode | Mnemonic | Description |
|--------|----------|-------------|
| 0x18 | AND | dst = src1 & src2 |
| 0x19 | OR | dst = src1 \| src2 |
| 0x1A | XOR | dst = src1 ^ src2 |
| 0x1B | NOT | dst = ~dst |
| 0x1C | SHL | dst = src1 << shift |
| 0x1D | SHR | dst = src1 >> shift |

#### Ternary/VSA (4)
| Opcode | Mnemonic | Description |
|--------|----------|-------------|
| 0x60 | DOT | ternary dot product |
| 0x6A | BIND | VSA bind operation |
| 0x6B | BUNDLE2 | majority vote (2 inputs) |
| 0x6C | BUNDLE3 | majority vote (3 inputs) |

#### Sacred (4)
| Opcode | Mnemonic | Description |
|--------|----------|-------------|
| 0x80 | PHI_CONST | dst = φ (1.618...) |
| 0x81 | PI_CONST | dst = π (3.141...) |
| 0x82 | E_CONST | dst = e (2.718...) |
| 0x92 | SACR | sacred arithmetic (op, dst, src) |

#### Memory (8)
| Opcode | Mnemonic | Description |
|--------|----------|-------------|
| 0x01 | LDI | load immediate |
| 0x02 | LD | load from [src1] |
| 0x03 | ST | store to [dst] |
| 0x04 | LDR | load register indirect |
| 0x05 | MOV | move register |
| 0x06 | LDTI | load with type |
| 0x07 | STO | store with offset |
| 0x08 | SAI | store aligned immediate |

#### Control Flow (8)
| Opcode | Mnemonic | Description |
|--------|----------|-------------|
| 0x10 | JUMP | PC ← PC + offset |
| 0x11 | JZ | jump if dst == 0 |
| 0x12 | JNZ | jump if dst != 0 |
| 0x13 | CALL | push PC, PC ← addr |
| 0x14 | RET | pop PC |
| 0x15 | PUSH | push to stack |
| 0x16 | POP | pop from stack |
| 0x17 | HALT | stop execution |

---

## Backends

### Zig Backend (CPU Emulator)

**Files**:
- `src/tri27/emu/cpu_state.zig` — CPU state, registers, memory
- `src/tri27/emu/decoder.zig` — instruction decoder
- `src/tri27/emu/executor.zig` — execution engine
- `src/tri27/emu/asm_parser.zig` — .tri assembler
- `src/tri27/tri27_cli.zig` — CLI entrypoint

**Features**:
- 36 opcodes, complete ISA
- 27×32-bit registers t0-t26
- 64KB memory (align(8) u8)
- Flags: Z, N, C, H, O
- Cycle counter for profiling

### Verilog Backend (FPGA)

**Files**:
- `fpga/openxc7-synth/hslm_ternary_mac.v` — ternary ALU core
- `src/tri27/verilog_backend.zig` — Zig → Verilog generator

**Features**:
- 0 DSP inference (pure LUT)
- Pipeline: IF → ID → EX → MEM → WB
- BRAM36 for instruction memory
- Ternary arithmetic in LUT

---

## Queen Integration — Lotus Cycle

### Phase 0: Experience Recall
**File**: `src/tri27/tri27_experience.zig`

Reads `.trinity/queen/episodes.jsonl` — last N episodes for analysis.

### Phase 1: Observe
**File**: `src/tri/queen/observe.zig`

Reads:
- `policy.json` — kill_threshold, crash_rate_limit, byzantine_rate_limit
- `senses.json` — farm_best_ppl, test_rate, dirty_files, etc.

### Phase 2: Plan
**File**: `src/tri/queen/plan.zig`

Generates `PolicyDelta`:
- `scale_up` — increase threshold (×1.1)
- `scale_down` — decrease threshold (×0.8-0.95)
- `set` — set exact value
- `wait` — do nothing

### Phase 3: Evaluate
**File**: `src/tri/queen/evaluate.zig`

Evaluates episode window:
- `good` — success_rate ≥ 95%
- `unstable` — 70% < success_rate < 95%
- `bad` — success_rate ≤ 70%
- `unknown` — no data

### Phase 4: Act
**File**: `src/tri/queen/act.zig`

Executes Plan:
- `scale_up` — multiply parameter
- `scale_down` — divide parameter
- `trigger` — execute command
- `wait` — observe

### Phase 5: Self-Learning
**File**: `src/tri/queen/self_learning.zig`

**Closed loop**:
```
tri tri27 run test.tbin
    → Episode → episodes.jsonl
    → loadRecentEpisodes(20)
    → evaluateWindow() → WindowEvaluation
    → generatePlan() → PolicyDelta[]
    → applyPolicyDelta() → Tri27Config
    → saveConfig() → tri27_config.json
    → Episode о self_learning_cycle
```

**Tri27Config**:
```zig
pub const Tri27Config = struct {
    kill_threshold: f64 = 5.0,        // PPL threshold
    crash_rate_limit: f64 = 0.1,      // Max crash rate
    byzantine_rate_limit: f64 = 0.1,  // Max byzantine ratio
    env_status: EnvStatus = .active,   // Environment status
    max_retries: u32 = 3,             // Max retries
    auto_adapt: bool = true,           // Enable self-learning
};
```

---

## CLI

```bash
# Compilation
tri tri27 assemble <input.tri> -o <output.tbin>

# Disassembly
tri tri27 disassemble <input.tbin>

# Execution
tri tri27 run <program.tbin>

# Validation
tri tri27 validate <source.tri>

# Experience tracking
tri tri27 experience init
tri tri27 experience log <file> [ASM|DISASM|RUN|VAL]
tri tri27 experience status
tri tri27 experience record <issue>

# ISA reference
tri tri27 isa
```

---

## Tests

| Test | File | Status | Description |
|------|------|--------|-------------|
| Golden | `test_golden.zig` | ✅ 15/15 | full cycle asm→tbin→emu |
| Comprehensive | `test_comprehensive.zig` | ✅ 36/36 | all opcodes |
| Experience | `tri27_experience.zig` | ✅ — | Jaccard similarity, recall |
| Queen Self-Learning | `self_learning.zig` | ✅ 4/4 | feedback loop |

**Run**:
```bash
zig build test-tri27-golden        # Golden tests
zig build test-tri27-comprehensive # Comprehensive tests
zig build test-tri27-experience    # Experience tests
zig build test-queen-self-learning # Self-learning tests
```

---

## Experimental Classes

### Energy/Latency of Dot-Product
**Hypothesis H1**: TRI-27 VM (CPU) is 10-100× slower than Sacred ALU (FPGA) in latency, but competitive in energy/op.

**Pipeline**:
```bash
# CPU baseline
tri tri27 run dot_product.tri --benchmark

# FPGA synthesis
tri fpga synth dot_product.tri --target xc7a100t

# Compare
tri bench compare cpu.json fpga.json
```

**Metrics**:
- latency (ns/op)
- throughput (ops/s)
- energy (J/op)

### Ternary vs Binary ISA
**Hypothesis H2**: Ternary operations {-1, 0, +1} reduce instruction count vs binary {0, 1}.

**Pipeline**:
```bash
# Compile same algorithm to TRI-27 and x86_64
tri tri27 assemble algo.tri -o algo_ternary.tbin
clang algo.c -o algo_binary -march=x86-64

# Compare instruction count
tri tri27 disassemble algo_ternary.tbin | wc -l
objdump -d algo_binary | wc -l
```

**Metrics**:
- instructions_per_algorithm
- bytes_per_instruction
- cyclomatic_complexity

### Code Density
**Hypothesis H3**: TRI-27 code is 2-3× more compact than binary RISC.

**Benchmark suite**:
- Fibonacci (recursive)
- Matrix multiplication (3×3)
- Dot product (vector length 64)
- QuickSort (10 elements)

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
├── tri27_experience_jsonl.zig  # JSONL integration
└── verilog_backend.zig     # Zig → Verilog generator

src/tri/queen/
├── observe.zig             # Phase 1: read policy/senses
├── plan.zig                # Phase 2: generate PolicyDelta
├── evaluate.zig            # Phase 3: evaluate window
├── act.zig                 # Phase 4: execute action
└── self_learning.zig       # Phase 5: closed-loop learning
```

---

## Status

✅ ISA — 36 opcodes
✅ Zig Backend — CPU emulator
✅ Verilog Backend — FPGA synthesis
✅ CLI — assemble/disassemble/run/validate
✅ Queen Integration — Phases 0-5
✅ Self-Learning — closed feedback loop
✅ Tests — 68/68 passing

---

## Integration with Other Components

| Component | File | Interface |
|-----------|------|-----------|
| Sacred ALU | `fpga/openxc7-synth/sacred_alu.v` | Dot-product opcode |
| Queen | `src/tri/queen/self_learning.zig` | Episode logging |
| HSLM | `src/hslm/tjepa.zig` | (planned) TRI-27 accelerator |

---

**φ² + 1/φ² = 3 | TRINITY**
