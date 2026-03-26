# Trinity Autocodegeneration Specification (TRI_AUTOCODE)

> **Version**: 1.1
> **Created**: 2026-03-24
> **Updated**: 2026-03-24
> **Status**: Draft — Implementation Plan for Issues #407-#418
>
> **Changes in v1.1**:
> - Replaced `.tri-spec` → unified `.tri` with `@spec` annotations
> - Added Part 4.5: Spec-DSL in .tri (@spec/@require/@ensure/@example/@goal)

---

## Overview

Этот документ объединяет:
1. ✅ **Research Layer** (Issue #406) — научная документация
2. **Coptic Extension** (Issue #407) — регистры и валидация
3. **NA-R11 Law** — защита .t27 файлов
4. **Tri Language DNA** — волны 1-4 фич из functional PLs
5. **Autocodegeneration Architecture** — 8 паттернов LLM→Tri

---

## Part 1: Research Layer Status (Issue #406) ✅

### Completed Files

| Файл | LOC | Purpose |
|------|-----|---------|
| `trinity_s3ai_overview.md` | ~350 | Master doc: S³ axes, 8-level stack |
| `TRINITY_S3AI_UNIFIED_FRAMEWORK.md` | ~450 | Unified framework master |
| `tri27_platform.md` | ~340 | TRI-27 как исследовательская платформа |
| `queen_lotus_experiments.md` | ~420 | Lotus Cycle, Paper 2 (H4-H6) |
| `sacred_formats_fpga.md` | ~310 | GF16/TF3 + FPGA ALU бенчмарки |
| `tri_language_roadmap.md` | ~460 | Tri Language roadmap |
| `t27_format.md` | ~300 | .t27 бинарный формат спецификация |
| `reticular_raphe.t27` | ~180 | Reference implementation example |

**Total**: ~2810 LOC ✅

---

## Part 2: Coptic Alphabet Extension (Issue #407)

### Purpose

Символические имена регистров через 27 коптских глифов. 3-bank архитектура памяти.

### 3-Bank Architecture

| Bank | Глифы | Диапазон | Назначение | Кол-во |
|------|-------|----------|-----------|--------|
| 0 | Ⲁ-Ⲑ | t0-t8 | ALU registers (integer ops) | 9 |
| 1 | Ⲓ-Ⲣ | t9-t17 | Sacred accumulators (FADD/FMUL) | 9 |
| 2 | Ⲥ-Ϥ | t18-t26 | Constants (immutable) | 9 |

### Glyph Mapping

```zig
pub const CopticReg = enum(u5) {
    // Bank 0: ALU registers (Units 1-9)
    alpha = 0,    // Ⲁ  → t0 (accumulator)
    beta = 1,     // Ⲃ  → t1 (base pointer)
    gamma = 2,    // Ⲅ  → t2
    dalda = 3,    // Ⲇ  → t3
    ei = 4,       // Ⲉ  → t4
    sou = 5,       // Ⲋ  → t5
    zeta = 6,      // Ⲍ  → t6
    ita = 7,       // Ⲏ  → t7
    tita = 8,      // Ⲑ  → t8

    // Bank 1: Sacred accumulators (Tens 10-90)
    iota = 9,      // Ⲓ  → t9 (GF16 accumulator)
    kappa = 10,    // Ⲕ  → t10
    laula = 11,    // Ⲗ  → t11
    mi = 12,       // Ⲙ  → t12
    ni = 13,       // Ⲛ  → t13
    ksi = 14,      // Ⲝ  → t14
    o = 15,        // Ⲟ  → t15
    pi = 16,       // Ⲡ  → t16
    ro = 17,       // Ⲣ  → t17

    // Bank 2: Constants (Hundreds 100-900)
    sima = 18,     // Ⲥ  → t18 (constant register)
    tau = 19,      // Ⲧ  → t19
    ypsilon = 20,   // Ⲩ  → t20
    phi = 21,      // Ⲫ  → t21
    chi = 22,      // Ⲭ  → t22
    psi = 23,      // Ⲯ  → t23
    omega = 24,     // Ⲱ  → t24
    shai = 25,     // Ϣ  → t25
    fay = 26,      // Ϥ  → t26

    pub fn bank(self: CopticReg) u2 {
        return @intCast(@intFromEnum(self) / 9);
    }
};

pub const coptic_glyphs = [27][]const u8{
    "Ⲁ", "Ⲃ", "Ⲅ", "Ⲇ", "Ⲉ", "Ⲋ", "Ⲍ", "Ⲏ", "Ⲑ",
    "Ⲓ", "Ⲕ", "Ⲗ", "Ⲙ", "Ⲛ", "Ⲝ", "Ⲟ", "Ⲡ", "Ⲣ",
    "Ⲥ", "Ⲧ", "Ⲩ", "Ⲫ", "Ⲭ", "Ⲯ", "Ⲱ", "Ϣ", "Ϥ",
};
```

### Implementation Files

| File | LOC | Purpose |
|------|-----|---------|
| `src/tri27/coptic.zig` | ~50 | CopticReg enum + glyphs + bank() |
| `src/tri27/emu/asm_parser.zig` | ~20 | Parse Ⲁ-Ϥ as t0-t26 aliases |
| `src/tri27/emu/isa.zig` | ~10 | Bank validation in instruction definitions |

### Validation Rules

```zig
// FADD/FMUL require Bank 1
fn validate_sacred_op(rd: CopticReg, rs1: CopticReg) !void {
    if (rd.bank() != 1 or rs1.bank() != 1) {
        return error.SacredOpRequiresBank1;
    }
}

// ST_F rejects Bank 2 (constants are immutable)
fn validate_store(rd: CopticReg) !void {
    if (rd.bank() == 2) {
        return error.CannotStoreToConstantBank;
    }
}

// ADD/SUB require Bank 0
fn validate_alu_op(rd: CopticReg, rs1: CopticReg, rs2: CopticReg) !void {
    if (rd.bank() != 0 or rs1.bank() != 0 or rs2.bank() != 0) {
        return error.AluOpRequiresBank0;
    }
}
```

### Example .t27 with Coptic

```assembly
; Triangle calculation using Coptic names
LDI Ⲁ, 10           ; Ⲁ = accumulator (Bank 0)
FADD Ⲓ, Ⲕ           ; Ⲓ/Ⲕ = Iota/Kappa (Bank 1)
FMUL Ⲝ, Ⲓ           ; Ⲝ = Ksi (Bank 1)
ST_R Ⲁ, Ⲓ           ; Store result from Bank 1 to Bank 0
```

---

## Part 3: NA-R11 Law — No Hand-Written .t27

### 3-Level Enforcement

#### 1. Signature in every .t27 file

```assembly
; TRI27_SIGNATURE: tri-cli:1711900800:sha256:a3f2...b7c1
; TRI27_PIPELINE: queen-lotus
; TRI27_AUTHOR: tri-cli-v0.9.2
; @module: reticular_raphe
; @neuro: Raphe (PPL Stabilizer)
```

Signature = `SHA256(content_without_signature + secret_from_.trinity/keys/t27.key)`

#### 2. Assembler refuses unsigned files

```zig
pub fn assemble(source: []const u8, allocator: Allocator) !Bytecode {
    // FIRST: verify signature before ANY parsing
    const sig = extractSignature(source) orelse
        return error.T27NotSignedByTriCli;

    if (!verifySignature(source, sig))
        return error.T27SignatureMismatch;

    // Only then proceed with parsing
    return parseInstructions(source, allocator);
}
```

#### 3. Build gate in build.zig

```zig
const verify_t27 = b.addSystemCommand(&.{
    "tri", "t27", "verify", "--strict", "--all"
});
exe.step.dependOn(&verify_t27.step);
```

#### 4. Git pre-commit hook

```bash
#!/bin/bash
# Generated by tri CLI
for f in $(git diff --cached --name-only | grep '\.t27$'); do
    tri t27 verify "$f" || {
        echo "ERROR: $f not signed by tri CLI"
        exit 1
    }
done
```

### New CLI Commands

| Command | Action |
|---------|--------|
| `tri cell create <region>` | Generate .t27 + BDD spec + signature |
| `tri t27 verify <file>` | Verify single file signature |
| `tri t27 verify --all` | Verify all .t27 in src/tri27/ |
| `tri t27 sign <file>` | Re-sign after tri canonize |
| `tri t27 diff <file>` | Show changes vs signed version |

### Files to Modify (Issue #407)

| File | LOC | Purpose |
|------|-----|---------|
| `src/tri/cell.zig` | ~80 | Signature generation |
| `src/tri/t27_cli.zig` | ~50 | tri t27 verify command |
| `src/tri27/emu/asm_parser.zig` | ~20 | Signature verification |
| `.git/hooks/pre-commit` | ~15 | Git hook (generated) |
| `build.zig` | ~5 | Build gate |

---

## Part 4: Tri Language DNA — Wave Implementation

### Wave 1: Syntax + Core Types (Issues #407, #408)

#### 1.1 ADT Enum + Exhaustive Match

**Source**: Rust
**LOC**: ~200
**Purpose**: Data-carrying enums, exhaustive pattern matching

```tri
type Signal {
    Pos(f16),
    Zero,
    Neg(f16),
}

fn process(signal: Signal) -> Result(PPL, Error) {
    match signal {
        Pos(level) => Ok(level * phi),
        Zero => Ok(0.0),
        Neg(level) => Ok(level / phi),
    }
}
```

**Compiler**: `match` requires all variants handled — missing = compile error.

#### 1.2 Pattern Matching in Function Arguments

**Source**: Elixir
**LOC**: ~100
**Purpose**: Multiple definitions of same function by pattern

```tri
fn activate(Signal(.pos, level)) -> Response {
    fire_neuron(level)
}

fn activate(Signal(.neg, _)) -> Response {
    inhibit_neuron()
}

fn activate(Signal(.zero, _)) -> Response {
    hold_state()
}
```

**Dispatch**: Compiler selects definition by runtime pattern.

#### 1.3 Pipe Operator `|>`

**Source**: Elixir
**LOC**: ~150
**Purpose**: Neuroanatomic signal flow as readable pipeline

```tri
input
    |> vlpfc.filter       ; Phase 0.5: attention filter
    |> dlpfc.hold         ; Phase 1: working memory
    |> vmpfc.evaluate     ; Phase 2: value assessment
    |> dmpfc.monitor      ; Phase 3: self-check
    |> ofc.respond        ; Phase 4: form response
```

**Implementation**: `input |> vlpfc.filter` = `vlpfc.filter(input)`

#### 1.4 Named Pipelines

**Source**: Elixir
**LOC**: ~100
**Purpose**: Reusable pipe chains

```tri
pipeline lotus_phase_0 = input
    |> vlpfc.recall
    |> vmpfc.plan;

pipeline lotus_phase_5 = input
    |> self_learning.evaluate
    |> queen_adapt.apply;
```

**Usage**: `episode |> lotus_phase_0`

#### 1.5 Guards with Conditions

**Source**: Haskell
**LOC**: ~80
**Purpose**: Conditional pattern matching

```tri
fn clamp(value: f16, min: f16, max: f16) -> f16 {
    match value {
        v | v < min => min,
        v | v > max => max,
        v => v,
    }
}
```

**Syntax**: `pattern | guard = result`

#### 1.6 Bit/Trit-Level Pattern Matching

**Source**: Erlang
**LOC**: ~120
**Purpose**: Decode TRI-27 instruction patterns

```tri
fn decode(opcode: u8) -> Instruction {
    match opcode {
        0b0000xxxx => LDI,
        0b0001xxxx => ADD,
        0b0010xxxx => FADD,
        0b0011xxxx => FMUL,
        0b0100xxxx => SACR,
        0b0101xxxx => ST_R,
        _ => Unknown,
    }
}
```

**Patterns**: `0b`, `0t` prefixes for binary/ternary.

### Wave 2: Type System + Memory (Issues #409, #410, #411)

#### 2.1 Result Type (No Exceptions)

**Source**: Gleam/Rust
**LOC**: ~200
**Purpose**: Error as value, not exception

```tri
type Result(value, error) {
    Ok(value),
    Err(error),
}

fn load_episode(id: tword) -> Result(Episode, NeuroError) {
    if (id.valid()) {
        Ok(deserialize(id))
    } else {
        Err(InvalidEpisodeId)
    }
}

; Caller MUST handle both:
load_episode(0tPPPOOONNN)
    |> match {
        Ok(ep) => process_episode(ep),
        Err(e) => log_error(e),
    }
```

**No try/catch**: Compiler enforces handling.

#### 2.2 Phantom Types (Bank Safety)

**Source**: Haskell
**LOC**: ~150
**Purpose**: Compile-time bank protection

```tri
type Banked(value, bank) {
    Banked(value),
}

fn sacred_add(a: Banked(f16, 1), b: Banked(f16, 1)) -> Banked(f16, 1) {
    Banked(f16_add(a.value, b.value))
}

; Compile error: bank mismatch
let wrong: Banked(f16, 0) = Banked(1.0, 1);
sacred_add(wrong, Banked(2.0, 1))  ; ERROR: expected Banked(f16, 1), got Banked(f16, 0)
```

**Runtime**: Zero cost — erased after type checking.

#### 2.3 Linear Types (FPGA Safety)

**Source**: Austral
**LOC**: ~200
**Purpose**: Must-consume semantics, no leaks

```tri
linear Resource {
    allocate();
    consume();
}

fn use_bracket(buf: linear Buffer) -> Result(Response, Error) {
    let data = buf.read();
    buf.consume();  ; MUST consume
    Ok(process(data))
}
```

**Violations**: Compile error if linear value not consumed.

#### 2.4 Typed Indexing

**Source**: Dex
**LOC**: ~100
**Purpose**: Size in type prevents OOB

```tri
type Array(value, N: u8) {
    data: [value; N],
}

fn get(a: Array(f16, 10), idx: u8) -> f16 {
    if (idx >= 10) {
        panic("OOB")  ; But type checker: idx is u8 < 256, array is [f16; 10]
    }
    a.data[idx]
}
```

**Alternative**: Prove N >= 256 in type parameter.

### Wave 3: Effects + Arrays (Issues #412, #413, #414)

#### 3.1 Algebraic Effects

**Source**: Koka/Roc
**LOC**: ~300
**Purpose**: IO purity, platform effects

```tri
effect io {
    read(): u8,
    write(value: u8): void,
}

effect cpu {
    compile(): u8,
}

effect fpga {
    synthesize(): Bitstream,
}

fn deploy() -> void ! {io | cpu | fpga} {
    let source = io::read();
    let compiled = cpu::compile(source);
    let bitstream = fpga::synthesize(compiled);
    io::write(bitstream);
}
```

**Handlers**: Effectful functions require explicit handler at call site.

#### 3.2 Array Combinators

**Source**: Futhark
**LOC**: ~200
**Purpose**: Map/reduce/scan for FPGA pipelines

```tri
fn map(arr: [f16; N], f: fn(f16) -> f16) -> [f16; N] {
    for (i in 0..N) arr[i] = f(arr[i])
}

fn reduce(arr: [f16; N], init: f16, op: fn(f16, f16) -> f16) -> f16 {
    var acc = init;
    for (i in 0..N) acc = op(acc, arr[i]);
    acc
}

fn scan(arr: [f16; N], init: f16, op: fn(f16, f16) -> f16) -> [f16; N] {
    var acc = init;
    for (i in 0..N) {
        acc = op(acc, arr[i]);
        result[i] = acc;
    }
    result
}
```

**FPGA**: Map = parallel DSP blocks, Reduce = tree reduction.

### Wave 4: Meta + Concurrency (Issues #415, #416, #417)

#### 4.1 Auto-Parallelism (DAG Extraction)

**Source**: Bend
**LOC**: ~250
**Purpose**: Extract parallel DAG from function dependencies

```tri
fn main() {
    let a = f1(input);
    let b = f2(input);  ; Parallel with f1
    let c = f3(a);
    let d = f4(b);  ; Parallel with f3
    f5(c, d);       ; Wait for both
}
```

**Compiler output**:
```
Thread 1: f1(input) -> a -> f3(a) -> c
Thread 2: f2(input) -> b -> f4(b) -> d
Sync:     c, d -> f5(c, d)
```

#### 4.2 Platform Abstraction

**Source**: Roc
**LOC**: ~200
**Purpose**: Same code, different backends

```tri
effect platform {
    read_reg(reg: u8): f16,
    write_reg(reg: u8, val: f16): void,
}

fn accumulate() -> f16 ! {platform} {
    let a = platform::read_reg(0);
    let b = platform::read_reg(1);
    let result = a + b;
    platform::write_reg(2, result);
}

; CPU runtime:
cpu_handler(accumulate())

; FPGA runtime:
fpga_handler(accumulate())
```

---

## Part 4.5: Spec-DSL in .tri (Annotations)

> **Principle**: .tri files contain code + spec + tests in one place. No separate .tri-spec files.

### Annotation Syntax

Doc comments above entities in .tri files:

```tri
/// @spec stabilize_ppl
/// @desc Clamp PPL using φ-decay within [min,max]
/// @require 0.0 <= ppl <= 100.0
/// @require cfg.min <= cfg.max
/// @ensure  result in [cfg.min, cfg.max]
/// @metric  ppl_delta = result - ppl
/// @goal    abs(ppl_delta) < 5.0
fn stabilize_ppl(ppl: PPL, cfg: PplConfig) -> Result(PPL, Error) ! {Compute} {
    let decayed = phi_decay(ppl, cfg.phi)
    let clamped = clamp(decayed, cfg.min, cfg.max)
    Ok(clamped)
}

/// @example
/// input: ppl=12.0, cfg={min=0.0,max=10.0,phi=0.9}
/// expect: Ok(10.0)
test stabilize_ppl_example_1() {
    assert_eq(stabilize_ppl(12.0, cfg), Ok(10.0))
}
```

### Annotation Keywords

| Keyword | Purpose |
|---------|---------|
| `@spec <name>` | Start spec for function/module |
| `@desc <text>` | Human-readable description |
| `@require <logic>` | Preconditions (logic expr) |
| `@ensure <logic>` | Postconditions |
| `@metric <name> = <expr>` | Define metric |
| `@goal <logic>` | Scientific goal (metric constraint) |
| `@example` | Example block with `input:` / `expect:` |

### Typed Holes for Autogeneration

```tri
fn stabilize_ppl(ppl: PPL, cfg: PplConfig) -> Result(PPL, Error) ! {Compute} {
    let decayed: PPL = ?phi_part(ppl, cfg)
    let clamped: PPL = ?clamp_part(decayed, cfg)
    Ok(clamped)
}
```

- Type checker knows hole types from context
- Agent gets: signature, annotations, hole types
- After generation: `tri spec lint` → `tri test` → `tri compile` → `tri canonize`

### Full Example: Queen Lotus Cycle

```tri
/// @spec lotus_phase_3_evaluate
/// @desc Evaluate episode window for Quality classification
/// @require window.size >= 1
/// @require window.size <= 100
/// @ensure  result.quality in {good, unstable, bad, unknown}
/// @ensure  result.success_rate >= 0.0
/// @ensure  result.success_rate <= 1.0
/// @metric  crash_rate = result.crashed / result.total_episodes
/// @goal    crash_rate < 0.05
fn evaluate_window(episodes: []Episode, window: Window) -> WindowEvaluation {
    // Implementation...
}

/// @example
/// input: episodes=[{ok:true},{ok:false},{ok:true}], window={size:3}
/// expect: {total:3, successful:2, failed:1, crashed:0, quality:unstable}
```

### CLI Commands

| Command | Action |
|---------|--------|
| `tri spec lint` | Parse `@spec/@require/@ensure/@example`, validate |
| `tri test` | Generate tests from `@example`, run checks |
| `tri bdd run <name>` | Map scenario to existing BDD (Queen/HSLM) |

### Implementation Files

| File | Purpose | LOC |
|------|---------|-----|
| `src/tri-lang/annotations.zig` | Parse annotations | ~150 |
| `src/tri/spec_lint.zig` | `tri spec lint` command | ~100 |
| `src/tri/test_gen.zig` | Generate tests from `@example` | ~200 |
| `src/tri/bdd_run.zig` | `tri bdd run` command | ~150 |

### Relationship to Existing Code

- **BDD**: Existing Zig tests stay, `tri bdd run` maps to them
- **NA-R11**: .t27 files auto-generated, signed, separate from .tri spec
- **Queen**: Can use `@spec` for self-learning metrics
- **HSLM**: `@goal` maps to training loss/PPL targets

---

## Part 5: Autocodegeneration Architecture

### 8 Scientific Patterns

| # | Pattern | Scientific Basis | LOC | Benefit |
|---|---------|------------------|-----|---------|
| 1 | Grammar Prompting | NeurIPS 2023 | ~50 | Immediate |
| 2 | SDD Pipeline | arXiv 2025 | ~0 | ✅ Works (NA-R11) |
| 3 | Exemplar Store | AlphaVerus 2025 | ~200 | High |
| 4 | GCD | SynCode 2024 | ~400 | Critical |
| 5 | Multi-Stage | ScienceDirect 2025 | ~300 | High |
| 6 | Type-Constrained Decoding | ACM 2025 | ~500 | Medium |
| 7 | Self-Improving (STOP) | OPT-ML 2023 | ~300 | High |
| 8 | Multi-Agent FPGA | Design-Reuse 2025 | ~600 | Later |

### Pipeline Flow

```
Natural Language Task
         ↓
Stage 1: SPEC → annotated .tri (comments + @spec + tests)
         ↓    [Grammar Prompting]
Stage 2: ARCHITECTURE → Pipeline DAG + types
         ↓    [Multi-Stage]
Stage 3: TRI CODE → .tri file
         ↓    [GCD + Type Constraints + AlphaVerus loop]
         ├─────────┼─────────┐
         ↓         ↓         ↓
      .t27      .zig      .v
      (VM)      (CPU)     (FPGA)
         ↓         ↓         ↓
    BDD verify  zig test  Verilator
         └─────────┼─────────┘
                   ↓
         EXEMPLAR STORE
         [Self-improving loop]
                   ↓
         Next iteration (better prompts)
         [STOP/Golden Chain]
```

### Grammar-Constrained Decoding (GCD)

**Problem**: LLM generates invalid syntax.

**Solution**: DFA from CFG masks invalid tokens.

```tri
; Tri EBNF (inserted into agent prompt)
program    = { declaration } ;
declaration = type_decl | fn_decl | pipeline_decl ;
fn_decl    = "fn" IDENT "(" params ")" "->" type block ;
match_expr = "match" expr "{" { pattern "=>" expr "," } "}" ;
pipe_expr  = expr { "|>" IDENT } ;
```

**Decoder**:
```zig
// DFA state: each step knows valid next tokens
const State = enum { ProgramStart, InTypeDecl, InFnDecl, InMatch, InPipe, ... };

fn step(state: State, token: Token) -> State {
    match (state, token) {
        .ProgramStart, .Keyword("fn") => .InFnDecl,
        .InFnDecl, .Ident(_) => .InParams,
        .InFnDecl, .Arrow => .InReturnType,
        .InMatch, .Pattern(_) => .InMatchBody,
        .InPipe, .Pipe => .ContinuePipe,
        _ => .Error,  ; Reject invalid continuation
    }
}
```

### AlphaVerus: Self-Improving Loop

**Problem**: How to guarantee correctness without unit tests?

**Solution**: Loop: generate → verify → errors refine LLM → success pairs stored.

```tri
loop (iteration = 0; iteration < 10) {
    let code = llm_generate(spec, exemplars);
    let result = tri_compile_verify(code);

    match result {
        Ok(_) => {
            exemplars.push(SuccessPair(spec, code));
            break;
        }
        Err(errors) => {
            llm_refine(errors);  ; Improve based on structured feedback
        }
    }
}
```

### Files for Autocodegeneration

| File | Purpose | LOC |
|------|---------|-----|
| `specs/tri/grammar.ebnf` | Tri grammar for GCD/prompting | ~50 |
| `.trinity/exemplars/` | Successful spec → code pairs | storage |
| `src/tri-lang/gcd_dfa.zig` | DFA generator from EBNF | ~200 |
| `src/tri-lang/constrained_decode.zig` | Type-constrained decoder | ~300 |
| `src/tri/cell.zig` | SDD pipeline (tri cell create) | ~150 |
| `tools/agents/multi_fpga.zig` | Multi-agent RTL generation | ~600 |

---

## Part 6: Issue Specifications (Ready for Creation)

### Issue #407: Coptic Alphabet + 3-Bank + NA-R11

**Title**: Coptic Alphabet for TRI-27 + 3-Bank Memory Model + NA-R11 Law

**Description**:
- 27 Coptic glyphs mapped to TRI-27 registers (t0-t26)
- 3-bank architecture (ALU, Sacred, Constants)
- Bank validation in assembler
- NA-R11: .t27 files must be generated by tri CLI (no hand-editing)
- Signature verification in asm_parser
- Build gate + git pre-commit hook

**Files**:
- `src/tri27/coptic.zig` (~50 LOC)
- `src/tri27/emu/asm_parser.zig` (+20 LOC)
- `src/tri/cell.zig` (+80 LOC)
- `src/tri/t27_cli.zig` (+50 LOC)
- `.git/hooks/pre-commit` (~15 LOC, generated)
- `build.zig` (+5 LOC)

**Acceptance Criteria**:
- [ ] CopticReg enum with 27 variants
- [ ] coptic_glyphs array with UTF-8 strings
- [ ] bank() function returns 0/1/2
- [ ] Assembler parses Ⲁ-Ϥ as t0-t26
- [ ] Assembler validates banks (FADD=Bank1, ADD=Bank0, ST_F≠Bank2)
- [ ] NA-R11: signature in every .t27
- [ ] NA-R11: asm_parser refuses unsigned files
- [ ] NA-R11: build gate in build.zig
- [ ] NA-R11: git pre-commit hook (generated)
- [ ] Zig code uses ASCII only (t0-t26)

**Estimated LOC**: ~240

---

### Issue #408: ADT Enum + Exhaustive Match + Pipe

**Title**: ADT Enum, Exhaustive Match, Pipe Operator, Named Pipelines, Guards

**Description**:
- ADT enum with data carriers (like Rust)
- Exhaustive match: compile error if case missing
- Pattern matching in function arguments (Elixir)
- Pipe operator `|>` (Elixir)
- Named pipelines for reusability
- Guards with boolean conditions (Haskell)

**Files**:
- `src/tri-lang/parser.zig` (~300 LOC) — parser + type checker
- `src/tri-lang/ast.zig` (~200 LOC) — AST with ADT enums
- `src/tri-lang/ir.zig` (~150 LOC) — intermediate representation

**Acceptance Criteria**:
- [ ] ADT enum: `type T { A(x), B, C(y,z) }`
- [ ] Exhaustive match: missing case = compile error
- [ ] Pattern matching in args: multiple `fn f(Pat)` defs
- [ ] Pipe operator `|>`: `x |> f` = `f(x)`
- [ ] Named pipelines: `pipeline foo = x |> f |> g`
- [ ] Guards: `p | cond = expr`

**Estimated LOC**: ~650

---

### Issue #409: Bit/Trit-Level Pattern Matching

**Title**: Bit and Trit Level Pattern Matching for TRI-27 Decode

**Description**:
- Binary patterns: `0b00`, `0b101`
- Ternary patterns: `0tPPN`, `0tONP`
- Wildcard: `_` in matches
- Trie-based pattern compilation for efficiency

**Files**:
- `src/tri-lang/pattern_match.zig` (~150 LOC)
- `src/tri27/decoder.zig` (~100 LOC)

**Acceptance Criteria**:
- [ ] Binary pattern matching: `match bits { 0b00 => ..., 0b11 => ... }`
- [ ] Ternary pattern matching: `match trits { 0tPPN => ... }`
- [ ] Wildcard support: `_` matches anything
- [ ] Trie compilation for O(1) pattern dispatch

**Estimated LOC**: ~250

---

### Issue #410: Guards with Conditions

**Title**: Guards for Pattern Matching (Conditional Patterns)

**Description**:
- Guards: `pattern | condition = result`
- Multiple guards per pattern
- Guard expressions are pure boolean

**Files**:
- `src/tri-lang/guards.zig` (~100 LOC)

**Acceptance Criteria**:
- [ ] Single guard: `x | x > 0 => ...`
- [ ] Multiple guards: `x | x > 0, x < 100 => ...`
- [ ] Guard ordering: first true wins
- [ ] Guard failure = next pattern tried

**Estimated LOC**: ~100

---

### Issue #411: Result Type + No Exceptions

**Title**: Result Type, Error as Value, No Exceptions

**Description**:
- `Result(T, E) = Ok(T) | Err(E)`
- No try/catch
- Error must be handled
- Map/opt chaining on Result

**Files**:
- `src/tri-lang/result.zig` (~150 LOC)
- `src/tri-lang/stdlib.zig` (+50 LOC for Result helpers)

**Acceptance Criteria**:
- [ ] `Result(T, E)` type with Ok/Err variants
- [ ] No try/catch syntax
- [ ] Compile error if Result not handled
- [ ] `map`, `and_then`, `or_else` helpers

**Estimated LOC**: ~200

---

### Issue #412: Phantom Types (Bank Safety)

**Title**: Phantom Types for Bank Protection

**Description**:
- `type Banked(T, Bank)` — bank in type
- Compile-time bank checking
- Zero runtime cost

**Files**:
- `src/tri-lang/types.zig` (~150 LOC)
- `src/tri-lang/type_checker.zig` (~200 LOC)

**Acceptance Criteria**:
- [ ] `Banked(T, B)` type parameter
- [ ] Bank mismatch = compile error
- [ ] Phantom type erased after compilation
- [ ] Zero runtime cost

**Estimated LOC**: ~350

---

### Issue #413: Linear Types (FPGA Safety)

**Title**: Linear Types for Resource Safety

**Description**:
- `linear T` — must-consume semantics
- No implicit copies
- Consumed values cannot be reused

**Files**:
- `src/tri-lang/linear.zig` (~200 LOC)
- `src/tri-lang/linear_checker.zig` (~150 LOC)

**Acceptance Criteria**:
- [ ] `linear` keyword
- [ ] Must-consume: unused linear = compile error
- [ ] No implicit copies
- [ ] Move semantics explicit

**Estimated LOC**: ~350

---

### Issue #414: Algebraic Effects

**Title**: Algebraic Effects for IO Purity

**Description**:
- Effect declarations: `effect io { ... }`
- Effectful functions: `fn ... -> T ! {effect}`
- Handlers at call site: `with io { ... }`

**Files**:
- `src/tri-lang/effects.zig` (~300 LOC)
- `src/tri-lang/effect_handler.zig` (~150 LOC)

**Acceptance Criteria**:
- [ ] Effect declarations
- [ ] Effectful function syntax
- [ ] Handler syntax
- [ ] Effect composition

**Estimated LOC**: ~450

---

### Issue #415: Array Combinators

**Title**: Map, Reduce, Scan for FPGA Pipelines

**Description**:
- `map`: transform each element
- `reduce`: fold to single value
- `scan`: prefix sums

**Files**:
- `src/tri-lang/array.zig` (~200 LOC)
- `src/tri-lang/fpga_emit.zig` (~100 LOC)

**Acceptance Criteria**:
- [ ] `map(arr, f)` function
- [ ] `reduce(arr, init, op)` function
- [ ] `scan(arr, init, op)` function
- [ ] FPGA pipeline emission

**Estimated LOC**: ~300

---

### Issue #416: Auto-Parallelism (DAG)

**Title**: Auto-Parallelism via DAG Extraction

**Description**:
- Extract dependency DAG from function
- Schedule independent ops in parallel
- Join at sync points

**Files**:
- `src/tri-lang/dag.zig` (~200 LOC)
- `src/tri-lang/scheduler.zig` (~150 LOC)

**Acceptance Criteria**:
- [ ] Dependency analysis
- [ ] DAG construction
- [ ] Parallel scheduling
- [ ] Multi-thread emission

**Estimated LOC**: ~350

---

### Issue #417: Platform Abstraction

**Title**: Platform Abstraction (CPU/FPGA/VM)

**Description**:
- Effect-based platform abstraction
- CPU handler: Zig backend
- FPGA handler: Verilog backend
- VM handler: TRI-27 emulator

**Files**:
- `src/tri-lang/platform.zig` (~150 LOC)
- `src/tri-lang/emit_cpu.zig` (~100 LOC)
- `src/tri-lang/emit_fpga.zig` (~100 LOC)

**Acceptance Criteria**:
- [ ] Platform effect
- [ ] CPU handler
- [ ] FPGA handler
- [ ] VM handler

**Estimated LOC**: ~350

---

## Part 7: Implementation Priority Summary

### Wave 1: Foundation (High Priority)

| Issue | Feature | LOC | Blocker |
|-------|---------|-----|---------|
| #407 | Coptic + 3-bank + NA-R11 | ~240 | None |
| #408 | ADT + match + pipe | ~650 | #407 |
| #409 | Bit/trit patterns | ~250 | #407 |
| #410 | Guards | ~100 | #408 |
| #411 | Result type | ~200 | #408 |
| #412 | Phantom types | ~350 | #408 |
| #413 | Linear types | ~350 | #408 |

**Total Wave 1**: ~2140 LOC

### Wave 2: Core (Medium Priority)

| Issue | Feature | LOC | Blocker |
|-------|---------|-----|---------|
| #414 | Algebraic effects | ~450 | Wave 1 |
| #415 | Array combinators | ~300 | Wave 1 |
| #416 | Auto-parallelism | ~350 | Wave 1 |
| #417 | Platform abstraction | ~350 | Wave 1 |

**Total Wave 2**: ~1450 LOC

### Wave 3: Optimization (Low Priority)

| Issue | Feature | LOC | Blocker |
|-------|---------|-----|---------|
| #418 | Staged compilation | ~200 | Wave 2 |
| #419 | Content-addressed | ~200 | Wave 2 |
| #420 | Tensor ops | ~300 | Wave 2 |

**Total Wave 3**: ~700 LOC

---

## Total Implementation Scope

| Wave | LOC | Priority |
|------|-----|----------|
| **Issue #406** (Research) | ~2810 | ✅ Complete |
| **Wave 1** (Foundation) | ~2140 | High |
| **Wave 2** (Core) | ~1450 | Medium |
| **Wave 3** (Optimization) | ~700 | Low |
| **Grand Total** | **~7100** | |

---

## Scientific References

1. **Grammar Prompting for DSLs** — NeurIPS 2023
   https://neurips.cc/virtual/2023/poster/72512

2. **Specification is Program** — arXiv 2025
   https://arxiv.org/abs/2501.03878v1

3. **AlphaVerus: Self-Improving Verified Generation** — CMU 2025
   http://www.contrib.andrew.cmu.edu/~bparno/papers/alpha-verus.pdf

4. **SynCode: Grammar-Constrained Decoding** — UIUC 2024
   https://github.com/structuredllm/syncode

5. **Multi-Stage Guided Generation** — ScienceDirect 2025
   https://www.sciencedirect.com/science/article/abs/pii/S095219762401649X

6. **Type-Constrained Decoding** — ACM 2025
   https://dl.acm.org/doi/10.1145/3729274

7. **Multi-Agent RTL Generation** — Design-Reuse 2025
   https://www.design-reuse.com/blog/56185-accelating-rtl-design-with-agentic-ai

---

## Appendix: Quick Reference

### Coptic to Register Mapping (One-Liner)

```bash
# Bank 0 (ALU): Ⲁ=t0, Ⲃ=t1, Ⲅ=t2, Ⲇ=t3, Ⲉ=t4, Ⲋ=t5, Ⲍ=t6, Ⲏ=t7, Ⲑ=t8
# Bank 1 (Sacred): Ⲓ=t9, Ⲕ=t10, Ⲗ=t11, Ⲙ=t12, Ⲛ=t13, Ⲝ=t14, Ⲟ=t15, Ⲡ=t16, Ⲣ=t17
# Bank 2 (Constants): Ⲥ=t18, Ⲧ=t19, Ⲩ=t20, Ⲫ=t21, Ⲭ=t22, Ⲯ=t23, Ⲱ=t24, Ϣ=t25, Ϥ=t26
```

### NA-R11 Quick Check

```bash
tri t27 verify src/tri27/reticular_raphe.t27
```

### Tri Language Quick Syntax

```tri
; ADT enum
type Option(value) {
    Some(value),
    None,
}

; Match
fn handle(opt: Option(f16)) -> f16 {
    match opt {
        Some(v) => v,
        None => 0.0,
    }
}

; Pipe
result = input |> filter |> map |> reduce

; Guards
fn clamp(v: f16) -> f16 {
    match v {
        x | x < 0 => 0,
        x | x > 100 => 100,
        x => x,
    }
}
```

---

> **EOF**
