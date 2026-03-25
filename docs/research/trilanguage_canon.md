# Tri Language Canon — 13 Keywords, 7 Types, 10 Operators. Compiles to silicon.

> **φ² + 1/φ² = 3 = TRINITY = Brain + φ + Process = DNA**

> **Canon Law**: This document defines the sacred surface and semantic core of Tri — the micro-execution substrate of Trinity S³AI. All .tri code must conform to these laws.

---

## Trinity S³AI Context

Trinity S³AI — Neuroanatomical Architecture & φ-Structured Brain Map.

- **Sacred** — Superhuman Specialized AI
- **S³AI** — Brain-Mapped Module & Process System
- **φ-Structure** — Mathematical foundation: φ² + 1/φ² = 3

### Tri in the Stack

| Layer | Component | Role |
|-------|-----------|------|
| **Language** | Tri | Pure ternary programming (micro-execution substrate) |
| **ISA** | TRI-27 | Ternary RISC Architecture for Sacred ALU & TMU |
| **Hardware** | Sacred ALU (GF16/TF3) | Physical φ-structured math on FPGA/ASIC |

**Contract**: Every Tri construct compiles to silicon:
- CPU backend → Zig/LLVM
- FPGA backend → Verilog/TRI-27 → sacredalu.v

"Compiles to silicon" is not a slogan — it's a binding contract.

---

## Core Surface: 13 Keywords, 7 Types, 10 Operators

### Keywords: 13 Sacred Words

```tri
fn      // function definition
const   // compile-time constant
let     // immutable binding
match   // exhaustive pattern matching
loop    // bounded iteration
return  // early exit
pub     // public visibility
type    // type alias
struct  // product type
cpu     // CPU execution target
fpga    // FPGA execution target
any     // generic type parameter
effect  // effect handler
```

**Law**: No other keywords exist in Tri. Extensions require Canon amendment.

### Types: 7 Sacred Kinds

```tri
trit      // .neg, .zero, .pos (balanced ternary)
tryte     // 9 trits (14.22 bits)
tword     // 27 trits (42.7 bits)
t81       // 81 trits (128 bits)
gf16      // Golden Float 16 (exp6/mant9, φ-structured)
tf3       // Ternary Float 9 (3+5 trits, 1/φ ratio)
void      // no value
```

**Type Hierarchy**:
```
void
  └─ trit
       └─ tryte (9 trits)
            └─ tword (27 trits)
                 └─ t81 (81 trits)
gf16      // parallel branch (φ-math)
tf3       // parallel branch (ternary float)
```

### Operators: 10 Primitives

```tri
+  -  *  /     // arithmetic (maps to Sacred ALU)
⊛            // dot product (maps to DSP48E1 / TMU)
=            // bind (immutable by default)
->           // function arrow
|            // pipe operator
::           // type annotation
```

**Operator Binding**:
- `⊛` — sacred dot product: always compiles to hardware TMU instruction
- `|` — pipe: chains functions without intermediate allocation
- `::` — type annotation: required at all function boundaries

---

## Hard Law: No OOP

### Forbidden in .tri

```tri
// ❌ FORBIDDEN
class          // no classes
object         // no objects
this           // no receiver
super          // no inheritance
interface      // no interfaces (use type classes instead)
throw          // no exceptions
try/catch      // no exception handlers
finally        // no cleanup handlers
```

### Forbidden Patterns

```tri
// ❌ FORBIDDEN: Methods attached to types
type Foo = struct
  bar fn()      // illegal: no methods

// ❌ FORBIDDEN: Inheritance
type Child = Parent  // illegal: no inheritance

// ❌ FORBIDDEN: Runtime RTTI
fn reflect(x: any) type  // illegal: no reflection

// ❌ FORBIDDEN: Global mutable state
let global: mut T  // illegal: no implicit globals
```

### Allowed Patterns

```tri
// ✅ ALLOWED: Top-level functions only
fn bar(x: Foo): Bar  // top-level function

// ✅ ALLOWED: Struct as product type
type Foo = struct { x: trit, y: tryte }

// ✅ ALLOWED: Enum as ADT sum type
type Option = enum
  Some(value: tword)
  None

// ✅ ALLOWED: Match is only branching by variants
fn match_option(opt: Option): tword
  match opt
    Some(v) -> v
    None -> 0

// ✅ ALLOWED: Explicit local mutation
fn increment(x: trit): trit
  let mut local = x
  local = local + 1
  local
```

**Principle**: Immutable by default; explicit, local mutation only where needed.

---

## Semantic Core: Result, Linear, Effects

### Result Type (No Exceptions)

```tri
type Result<T, E> = enum
  Ok(value: T)
  Err(error: E)

// Canonical error propagation
fn divide(a: tword, b: tword): Result<tword, Error>
  if b == 0
    Err(Error.DivideByZero)
  else
    Ok(a / b)
```

**Law**: All fallible operations return `Result<T, E>`. No exceptions exist.

### Linear Types (Ownership)

```tri
// Linear value: must be consumed exactly once
type Buffer = linear(tword)

fn consume(buf: Buffer): void
  // buf is consumed here — compiler enforces use-once

// ❌ ERROR: using buf again would be compile-time violation
```

**Law**: Linear types enforce resource safety. Compiler tracks lifetime.

### Effects (Waves)

```tri
effect Async
  async fn<T>(fn() -> T): T

effect State
  get fn<T>(): T
  set fn<T>(value: T): void

// Effect handlers at call site
fn with_state<T>(body: fn() -> T): T
  handle State with
    get() -> /* read from state */
    set(v) -> /* write to state */
  in body()
```

**Law**: Effects are explicit, type-checked, and handled at boundaries.

---

## Layer Binding: Tri ↔ TRI-27 ↔ Trinity S³AI

### Upper Layer: Brain Map (Trinity S³AI)

Neuroanatomical modules mapped to letter zones:
- `intraparietal_sulcus` → I-zone (numerical cognition)
- `angulargyrus` → A-zone (language, semantics)
- `fusiformgyrus` → F-zone (visual patterns)
- `basal_ganglia` → B-zone (action selection)
- `hippocampus` → H-zone (episodic memory)
- `reticular_formation` → R-zone (arousal, vigilance)

### Middle Layer: Language & VM

```
Tri (.tri files)
  ↓ emit_t27.zig
TRI-27 (.tbin binaries)
  ↓ tri-emu (CPU) or tri-hw (FPGA)
```

Each module compiles: Tri → TRI-27 .tbin → execution

### Lower Layer: Hardware

- **Sacred ALU** — GF16/TF3 arithmetic
- **TMU** — Ternary Multiplication Unit (`⊛` operator)
- **Register Banks** — 3 banks × 9 registers = 27 Coptic registers

### φ-Structure Formula

```
φ² + 1/φ² = 3

3 → 3 register banks
9 → 9 registers per bank (Coptic alphabet)
27 → 27 total registers (TRI-27 ISA)
81 → 81 trits (t81 type, 128 bits)
```

---

## Process Law: Every Mutation Through tri

### State Machine

```
IDLE → WORKING → TESTING → COMMITTING → SHIPPED
  ↑         ↓        ↑         ↓
  ←───────── RESET ────────────────
                       ↓
                    BLOCKED
```

### Mandatory Entry Points

```bash
# Start work (mandatory)
tri dev start --issue <N>

# Run tests (mandatory before commit)
tri dev test

# Commit (enforces TESTED state)
tri dev commit "message"

# Ship (marks as delivered)
tri dev ship
```

### Laws

1. **No code without Issue**: `tri dev start --issue N` is mandatory
2. **No commit without tests**: State machine enforces TESTED before COMMITTED
3. **No action outside tri**: All operations go through tri CLI
4. **No lost experience**: Every task produces an Episode
5. **No uncontrolled agents**: Agents obey same state machine + Alphabet Canon 27

### Episode Format

```json
{
  "episode_id": "ep_<timestamp>",
  "issue": "418",
  "task": "NA-R11 Alphabet Canon 27",
  "verdict": "SUCCESS",
  "duration_sec": 300,
  "mistakes": [],
  "learnings": [
    "TTT Seal requires token file",
    "Pre-commit hook integration needed"
  ]
}
```

---

## Tri Zones & Agents — Language Canon × Alphabet Canon 27

### Zone Ownership Table

| Zone | Owns | Files | TTT? |
|------|------|-------|-----|
| **T** | Core types, sacred math, Coptic naming | `src/temple/*.zig`, `src/tri27/coptic.zig`, `specs/tri/types.tri` | YES |
| **J** | JIT, compilation, VM execution | `src/tri-lang/pipeline.zig`, `emit_t27.zig`, `src/tri27/emu/`, `specs/tri/grammar.ebnf` | No |
| **V** | VSA, embeddings | `src/vsa.zig` | No |
| **F** | LLM engine integration | `src/firebird/*.zig` | No |
| **Q** | Coordination, governance | `src/tri/queen_*.zig`, `.trinity/` | No |
| **X** | Thalamus bus, distribution | `.trinity/thalamus/` | No |
| **E** | Type checking, verification, quality gates | `src/tri-lang/checker.zig` | No |

### Agent Responsibilities

| Agent | Tri Component | Lock Path |
|-------|---------------|-----------|
| **T-agent** | Sacred types, Result, Linear, Effects, Coptic registers | `src/temple/`, `src/tri27/coptic.zig`, `specs/tri/types.tri` |
| **J-agent** | emit_t27, pipeline, HM inference, VM execution | `src/tri-lang/`, `src/tri27/emu/`, `specs/tri/grammar.ebnf` |
| **V-agent** | VSA ops, bind/unbind/bundle | `src/vsa.zig` |
| **F-agent** | Firebird LLM, token streams | `src/firebird/` |
| **Q-agent** | Queen policy, meta-control, canonmap | `src/tri/queen_*.zig`, `.trinity/canonmap.json` |
| **E-agent** | Type checker, verify, quality gates | `src/tri-lang/checker.zig` |

### Cross-Zone Compilation Pipeline

```
T-zone (types) → J-zone (compile) → X-zone (distribute) → All zones (consume)
     ↓              ↓                  ↓                  ↓
  sacred math    emit_t27           thalamus           compiled modules
  Result/Eff     HM inference       distribution       (.tbin)
  Linear         VM execution
```

1. **T-zone**: Defines sacred types (trit, tryte, tword, Result, Linear, Effects)
2. **J-zone**: Compiles .tri → TRI-27 .tbin (emit_t27.zig, HM inference, VM)
3. **X-zone**: Distributes .tbin to target zones (CPU/FPGA)
4. **E-zone**: Verifies type correctness, quality gates before distribution
5. **All zones**: Import and use sacred types, compiled modules

### File Ownership by Zone

```
src/temple/                    → T-agent (SEALED)
src/tri27/coptic.zig           → T-agent (sacred naming)
src/tri27/emu/                 → J-agent (VM execution)
src/tri-lang/                  → J-agent (compiler, pipeline)
src/tri-lang/checker.zig       → E-agent (verification)
src/vsa.zig                    → V-agent
src/firebird/                  → F-agent
src/tri/queen_*.zig            → Q-agent
.trinity/canonmap.json         → Q-agent (governance)
.trinity/thalamus/             → X-agent (distribution)
specs/tri/types.tri            → T-agent (type definitions)
specs/tri/grammar.ebnf         → J-agent (parsing)
```

### Lock Rules for Language Evolution

1. **One zone per component**: Agent locks only their zone's files
2. **Cross-zone changes**: Require Queen-issued bridge-task
3. **TTT Seal**: T-zone changes require unseal token (`TEMPLE_RITUAL=1`)
4. **Version sync**: `.trinity/canonmap.json` contains `temple_version`. On `tri swarm alpha`, Queen verifies all zones reference same temple_version
5. **Grammar-Types split**: `grammar.ebnf` (J-zone) parses, `types.tri` (T-zone) defines — changes coordinated via bridge-task
6. **Quality gates**: E-agent must sign off on all .tbin before X-zone distribution

### Zone Coordination Protocol

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   T-zone    │────▶│   J-zone    │────▶│   E-zone    │
│  (types)    │     │  (compile)  │     │  (verify)   │
└─────────────┘     └─────────────┘     └─────────────┘
                           │                    │
                           ▼                    ▼
                    ┌─────────────┐     ┌─────────────┐
                    │   X-zone    │────▶│  All zones  │
                    │(distribute) │     │  (consume)  │
                    └─────────────┘     └─────────────┘
```

**Bridge-task format** (Q-agent issued):
```json
{
  "bridge_id": "BRIDGE_<timestamp>",
  "from_zone": "T",
  "to_zone": "J",
  "change": "Added Linear type to Result",
  "temple_version": "1.0.1",
  "approved_by": "Q-agent"
}
```

---

## TRI-27 Binding: Registers, Banks, Coptic

### Coptic Register Mapping

| Bank | Range | Coptic | Role |
|------|-------|--------|------|
| 0 (ALU) | t0-t8 | alpha-eta | Fast computation |
| 1 (Sacred) | t9-t17 | iota-rho | T-zone, Queen, OFC |
| 2 (Const) | t18-t26 | sigma-shmima | Constants, config |

### Opcode Format

```
|--------6--------|-------5-------|-------5-------|-------11------|
     opcode         dest (tN)      src1 (tN)       src2 (tN) / imm
```

### Sacred Opcodes

```
MOV   rd, rs    // Move register
ADD   rd, rs1, rs2  // Ternary add
DOT   rd, rs1, rs2  // ⊛ dot product (TMU)
JGT   rt, offset    // Jump if greater than
JLT   rt, offset    // Jump if less than
JUMP  offset        // Unconditional jump
```

---

## Appendix: Canon Amendments

This document is living canon. Amendments require:
1. Issue labeled `CANON_AMENDMENT`
2. Review by T-agent (Temple)
3. Approval via TEMPLE_RITUAL
4. Update of this document with changelog

### Version History

| Version | Date | Change | Agent |
|---------|------|--------|-------|
| 1.0.0 | 2026-03-25 | Initial canon — 13/7/10 surface, No OOP law | T-agent |
| 1.0.1 | 2026-03-25 | Added Layer Binding section | T-agent |
| 1.1.0 | 2026-03-25 | Added Tri Zones & Agents section (7 zones, ownership tables, lock rules) | T-agent |

---

## References

- `specs/tri/` — .tri language specifications (source of truth)
- `src/tri-lang/` — Type system, compiler (HM, emit_t27), checker (E-zone)
- `src/tri27/` — VM emulator (J-zone), Coptic registers (T-zone)
- `docs/research/ALPHABET_CANON_27.md` — 27-zone repository zoning
- `docs/research/neuroanatomical_architecture.md` — NA-R1 through NA-R11
- `.trinity/canonmap.json` — Official canon with alphabet_zones

---

**φ² + 1/φ² = 3**

*This canon is sealed by TTT. Modifications require TEMPLE_RITUAL.*
