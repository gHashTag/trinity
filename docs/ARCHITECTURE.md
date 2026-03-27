# Trinity S³AI DNA Architecture

<<<<<<< Updated upstream
> **Trinity Identity**: `φ² + 1/φ² = 3` — a single equation links mathematics, brain architecture, and the Trinity language.

## Overview

Trinity S³AI (Science-Structure-System AI) is built on **three intertwined Strands** — each is critical to the system, but cannot exist without the other two.
=======
> **Trinity Identity**: `φ² + 1/φ² = 3` — one equation binds mathematics, brain architecture, and the Trinity language.

## Overview

Trinity S³AI (Science-Structure-System AI) is built on **three intertwined Strands** — each is critical to the system but cannot exist without the other two.

| Strand | Role | Code | Connections |
|--------|------|------|-------------|
| **I: Mathematical Foundation** | `src/tri/math/` | Sacred constants, formulas, VSA |
| **II: Cognitive Architecture** | `src/brain/` | Neuroanatomical map, executive functions |
| **III: Language & Hardware Bridge** | `src/tri/` + `fpga/` | TRI-27 language, FPGA backends |
>>>>>>> Stashed changes

| Strand | Role | Code | Relationships |
|--------|------|--------|
| **I: Mathematical Foundation** | `src/tri/math/` | Sacred constants, formulas, VSA |
| **II: Cognitive Architecture** | `src/brain/` | Neuroanatomical map, executive functions |
| **III: Language & Hardware Bridge** | `src/tri/` + `fpga/` | TRI-27 language, FPGA backends |
```
Strand I (Math)
    ↓
Strand II (Brain)
    ↓
Strand III (Language + Hardware)
```

## Trinity Identity

```
φ² + 1/φ² = 3 = TRINITY
```

<<<<<<< Updated upstream
This formula is an **architectural invariant** of Trinity:
- Mathematics: `V = n × 3^k × π^m × φ^p × e^q` in `src/tri/math/formula.zig`
- Constants: 75+ sacred values ​​in `src/tri/math/constants.zig`
- Governance: 8 principles in `src/sacred/CHARTER.md`
=======
This formula is the **architectural invariant** of Trinity:
- Mathematics: `V = n × 3^k × π^m × φ^p × e^q` in `src/tri/math/formula.zig`
- Constants: 75+ sacred values in `src/tri/math/constants.zig`
- Governance: 8 principles in `src/sacred/CHARTER.md`

>>>>>>> Stashed changes
---

## TRI-27 Kernel — Central Execution Engine

<<<<<<< Updated upstream
**TRI-27 is a ternary computing core** that executes all Trinity workloads:

| Component | Value |
|-----------|---------|
| **Registers** | 27 x 32-bit (t0-t26) = 3 banks x 9 (Coptic alphabet) |
=======
**TRI-27 is the ternary computing core** that executes all Trinity workloads:

| Component | Value |
|-----------|-------|
| **Registers** | 27×32-bit (t0-t26) = 3 banks × 9 (Coptic alphabet) |
>>>>>>> Stashed changes
| **Opcodes** | 36 — arithmetic, logic, control, ternary, sacred |
| **Memory** | 64KB byte-addressable |
| **Targets** | Zig CPU emulator + Verilog FPGA |

```
φ² + 1/φ² = 3 → 3^27 = 7.6 trillion states (ternary completeness)
```

[Full TRI-27 documentation](docs/tri27/README.md)

---

## Strand I — Mathematical Foundation

### Role

<<<<<<< Updated upstream
The sacred mathematical framework that defines the **numerical geometry** of the Trinity.
=======
The sacred mathematical framework that defines the **numerical geometry** of Trinity.
>>>>>>> Stashed changes

### Components

| Module | Purpose | Key Elements |
<<<<<<< Updated upstream
|--------|----------|-----------------|
| `src/tri/math/formula.zig` | The sacred formula | V = n × 3^k × π^m × φ^p × e^q |
| `src/tri/math/constants.zig` | Sacred Constants | φ, π, e, γ, χ, σ, ε (75+) |
| `src/tri/math/identities.zig` | Identities | φ-distance, ternary resonance |
| `src/tri/math/transcendental.zig` | Transcendental Functions | π, e, ln, exp |
| `src/sacred/CHARTER.md` | Governance | 8 Principles |
| `src/vsa.zig` | VSA Operations | bind, unbind, bundle, similarity |
=======
|--------|---------|--------------|
| `src/tri/math/formula.zig` | Sacred formula | V = n × 3^k × π^m × φ^p × e^q |
| `src/tri/math/constants.zig` | Sacred constants | φ, π, e, γ, χ, σ, ε (75+) |
| `src/tri/math/identities.zig` | Identities | φ-distance, ternary resonance |
| `src/tri/math/transcendental.zig` | Transcendental functions | π, e, ln, exp |
| `src/sacred/CHARTER.md` | Governance | 8 principles |
| `src/vsa.zig` | VSA operations | bind, unbind, bundle, similarity |
>>>>>>> Stashed changes

### Connections

- **→ Strand II**: Brain modules use `src/tri/math/` for sacred operations
- **→ Strand III**: TRI-27 compiler uses sacred constants

---

## Strand II — Cognitive Architecture

### Role

<<<<<<< Updated upstream
Neuroanatomically inspired architecture of the Trinity **virtual brain**.
=======
Neuroanatomically-inspired architecture of Trinity's **virtual brain**.
>>>>>>> Stashed changes

### Components

| Region | File | Purpose | LOC |
<<<<<<< Updated upstream
|--------|----------|---------|
| Prefrontal Cortex | `prefrontal_cortex.zig` | Executive Functions | 717 |
| Basal Ganglia | `basal_ganglia.zig` | Task Registry | 889 |
| Reticular Formation | `reticular_formation.zig` | Event Bus (10K) | 746 |
| Locus Coeruleus | `locus_coeruleus.zig` | Arousal Regulation | 253 |
| Amygdala | `amygdala.zig` | Emotional Valence | 578 |
| Persistence | `persistence.zig` | JSONL Logging | 804 |
| Health History | `health_history.zig` | Health Snapshots | 305 |
| Cerebellum | `cerebellum.zig` | Motor Learning | 1601 |
| Thalamus | `thalamus_logs.zig` | Relay | 435 |
| Telemetry | `telemetry.zig` | Time Series | 412 |
| Corpus Callosum | `federation.zig` | Aggregation, CRDT | 2166 |
| Microglia | `microglia.zig` | Immune Monitoring | 512 |
| Alerts | `alerts.zig` | Critical Notifications | 1241 |
| Metrics Dashboard | `metrics_dashboard.zig` | Metrics Management | 1884 |
| Visual Cortex | `visualization.zig` | ASCII Maps | 1302 |
| Admin | `admin.zig` | Administrative Control | 1374 |
| State Recovery | `state_recovery.zig` | Recovery | 2037 |
| Evolution Simulation | `evolution_simulation.zig` | Agent Evolution | 1500+ |
| SEBO | `sebo.zig` | Sacred Bayesian Optimization | 800+ |
| Integration Test | `integration_test.zig` | Cross-Module Benchmarks | 600+ |
| Performance Benchmarks | `benchmarks.zig`, `perf_*.zig` | Performance | 1000+ |

### Links

- **← Strand I**: Uses sacred math from `src/tri/math/`
=======
|--------|------|---------|-----|
| Prefrontal Cortex | `prefrontal_cortex.zig` | Executive functions | 717 |
| Basal Ganglia | `basal_ganglia.zig` | Task registry | 889 |
| Reticular Formation | `reticular_formation.zig` | Event bus (10K) | 746 |
| Locus Coeruleus | `locus_coeruleus.zig` | Arousal regulation | 253 |
| Amygdala | `amygdala.zig` | Emotional salience | 578 |
| Persistence | `persistence.zig` | JSONL journaling | 804 |
| Health History | `health_history.zig` | Health snapshots | 305 |
| Cerebellum | `cerebellum.zig` | Motor learning | 1601 |
| Thalamus | `thalamus_logs.zig` | Relay | 435 |
| Telemetry | `telemetry.zig` | Time series | 412 |
| Corpus Callosum | `federation.zig` | Aggregation, CRDT | 2166 |
| Microglia | `microglia.zig` | Immune monitoring | 512 |
| Alerts | `alerts.zig` | Critical notifications | 1241 |
| Metrics Dashboard | `metrics_dashboard.zig` | Metrics management | 1884 |
| Visual Cortex | `visualization.zig` | ASCII maps | 1302 |
| Admin | `admin.zig` | Administrative control | 1374 |
| State Recovery | `state_recovery.zig` | Recovery | 2037 |
| Evolution Simulation | `evolution_simulation.zig` | Agent evolution | 1500+ |
| SEBO | `sebo.zig` | Sacred Bayesian Optimization | 800+ |
| Integration Test | `integration_test.zig` | Cross-module tests | 600+ |
| Performance Benchmarks | `benchmarks.zig`, `perf_*.zig` | Performance | 1000+ |

### Connections

- **← Strand I**: Uses sacred mathematics from `src/tri/math/`
>>>>>>> Stashed changes
- **→ Strand III**: Executes TRI-27 bytecode compiled to Zig

---

## Strand III — Language & Hardware Bridge (TRI-27)

### Role

<<<<<<< Updated upstream
Links the **TRI-27** high-level language to two execution worlds: CPU (Zig) and FPGA (Verilog). TRI-27 is the only high-level language; Zig/Verilog are the backends.
=======
Binds the high-level **TRI-27** language to two execution worlds: CPU (Zig) and FPGA (Verilog). TRI-27 is the only high-level language; Zig/Verilog are backends.
>>>>>>> Stashed changes

### Components

| Component | File | Purpose |
<<<<<<< Updated upstream
|-----------|----------|----------|
=======
|-----------|------|---------|
>>>>>>> Stashed changes
| TRI-27 Lexer | `src/tri/lexer.zig` | Tokenization |
| TRI-27 Parser | `src/tri/parser.zig` | AST |
| TRI-27 AST | `src/tri/ast.zig` | Nodes |
| Zig Backend | `src/tri/emit_zig.zig` | CPU target |
| Verilog Backend | `src/tri/emit_verilog.zig` | FPGA target |
| VSA Operations | `src/vsa.zig` | bind, unbind, bundle, similarity |
| Sacred ALU | `fpga/openxc7-synth/sacred_alu.v` | φ-mathematics |
| TMU | `fpga/openxc7-synth/hslm_ternary_mac.v` | Ternary matrix |

### Compilation Chain

```
.tri spec (Single Source of Truth)
↓
TRI-27 language (Ternary types, AST)
↓ ↓
Zig Backend Verilog Backend
(emit) (emit)
```

<<<<<<< Updated upstream
**Important**: Zig and Verilog are **targets**, not sources of truth. TRI-27 = source of truth.

### Links

- **← Strand II**: Compiled to Zig for running brain modules
- **← Strand I**: Uses sacred constants in the FPGA Sacred ALU
=======
**Important**: Zig and Verilog are **targets**, not source of truth. TRI-27 = source of truth.

### Connections

- **← Strand II**: Compiles to Zig for brain module execution
- **← Strand I**: Uses sacred constants in FPGA Sacred ALU
>>>>>>> Stashed changes

---

## Rigid Process Framework

**Location**: `src/tri/dev/`

**State Machine**: `IDLE → ACTIVE → DIRTY → TESTED → COMMITTED → SHIPPED`

<<<<<<< Updated upstream
All code changes go through this pipeline, rather than manual editing.
=======
All code changes go through this pipeline, not manual editing.
>>>>>>> Stashed changes

---

## Tri Skill & Tri Cell

<<<<<<< Updated upstream
**Skill** is a unit of capability defined in `.claude/skills/*/SKILL.md`.

**Tri Cell** is a self-healing Phoenix System cell, defined in `cell.tri`.

All new capabilities are processed through the Rigid Process and are captured in the Trinity experience.

Principles:

- .tri/TRI-27 specifications are the single source of truth
- Codegen (Zig/Verilog) is only enabled through SKILL cells and tri-CLI, controlled by the state machine
- Phoenix/Tri Cell, one level higher, ensures self-healing and longevity of the SKILL cell colony

---

## Trinity S³AI DNA — merging three Strands

Trinity becomes complete when the three Strands are synchronized:

- Strand I defines the numerical geometry (φ, 3, 27, ternary).
- Strand II places this geometry in the virtual brain.
- Strand III provides execution and materialization — from TRI-27 to CPU/FPGA.

Any new knowledge, module, or SKILL appears only when:

1. Their location is described in ARCHITECTURE (one of the Strands).
2. There is a `.tri`/TRI-27 specification.
3. They are implemented through the Rigid Process and captured in the Trinity experience.

---

## Annotation Patterns (for insertion into code)
=======
**Skill** — a unit of capability defined via `.claude/skills/*/SKILL.md`.

**Tri Cell** — a self-healing Phoenix System cell defined in `cell.tri`.

All new capabilities go through the **Rigid Process** and are recorded in Trinity experience.

Principles:

- `.tri`/TRI-27 specifications — **single source of truth**
- Codegen (Zig/Verilog) allowed only through SKILL-cells and tri-CLI, under state-machine control
- Phoenix / Tri Cell at higher level provides self-healing and colony longevity of SKILL-cells

---

## Trinity S³AI DNA — Unification of Three Strands

Trinity becomes whole when the three Strands are synchronized:

- Strand I defines the **numerical geometry** (φ, 3, 27, ternary).
- Strand II places this geometry in a **virtual brain**.
- Strand III provides **execution and materialization** — from TRI-27 to CPU/FPGA.

All new knowledge, module, or SKILL appear only when:

1. Their place is described in ARCHITECTURE (one of the Strands).
2. There is a `.tri`/TRI-27 specification.
3. They go through Rigid Process and are recorded in Trinity experience.

---

## Annotation Patterns (for code insertion)
>>>>>>> Stashed changes

**Strand I (Math)** — for all files in `src/tri/math/*.zig`:
```zig
//! [Module Name] — [Brief Description]
//! Strand I: Mathematical Foundation
//!
```

**Strand II (Brain)** — for all files in `src/brain/*.zig`:
```zig
//! [Module Name] — [Neuroanatomical Function]
//! Strand II: Cognitive Architecture
//!
```

<<<<<<< Updated upstream
**Strand III (Language + Hardware)** - for:
=======
**Strand III (Language + Hardware)** — for:
>>>>>>> Stashed changes
- `src/tri/token.zig`, `src/tri/lexer.zig`, `src/tri/ast.zig`, `src/tri/parser.zig`, `src/tri/emit_zig.zig`, `src/tri/emit_verilog.zig`, `src/vsa.zig`
- `fpga/openxc7-synth/*.v`

```zig
//! [Module Name] - [TRI-27/FPGA component]
//! Strand III: Language & Hardware Bridge
//!
```

---

## Queen Trinity Protocol

**Location**: `src/tri/queen_trinity.zig`

<<<<<<< Updated upstream
**Role**: Lotus Cycle Protocol for clearing impure events from all three Strands.
=======
**Role**: Lotus Cycle Protocol for purifying impure events from all three Strands.
>>>>>>> Stashed changes

**Lotus Cycle (φ² + 1/φ² = 3)**:
```
QUEUED → DIAGNOSING → REFINE → VERIFY → PURIFIED
↑ ↓ ↑ ↑
←────────────────── RESET ────────────────
```

**Maximum 3 attempts** (Trinity architectural limit).

**Impure events** are generated by all Strands:
<<<<<<< Updated upstream
- **Strand I (Math)**: `src/tri/math/` — sacred calculations, formulas
- **Strand II (Brain)**: `src/brain/` — training, telemetry, checkpoint
=======
- **Strand I (Math)**: `src/tri/math/` — sacred computations, formulas
- **Strand II (Brain)**: `src/brain/` — learning, telemetry, checkpoint
>>>>>>> Stashed changes
- **Strand III (Lang)**: `src/tri27/`, `fpga/` — compilation, synthesis, verification

**Event Types**:
| Type | Code | Description |
<<<<<<< Updated upstream
|-----|-------|----------|
| BUILD_FAIL | `zig build` failed |
| TEST_FAIL | `zig build test` failed |
| SPEC_MISMATCH | `.tri` spec does not match code |
| GEN_FAIL | GEN phase failed |
| VERIFY_FAIL | VERIFY phase failed |
| DEPLOY_FAIL | deployment failed |
| CHECKPOINT_FAIL | checkpoint not created |

**Repository**: `.trinity/impure/*.json`

**CLI commands**:
```bash
tri queen status # Show impure event queue
tri queen purify # Run Lotus Cycle on the first event in the queue
tri queen purify --all # Clear all queued events
tri queen blocked # Show events where Queen failed
```

**Integration**:
- Hook events are written to `.trinity/impure/` automatically
- Queen CLI reads the queue and executes Lotus Cycle
- Each cycle phase (DIAGNOSING → VERIFY → PURIFY) records progress in an event
=======
|-----|------|-------------|
| BUILD_FAIL | `zig build` failed |
| TEST_FAIL | `zig build test` did not pass |
| SPEC_MISMATCH | `.tri` spec does not match code |
| GEN_FAIL | GEN phase failed |
| VERIFY_FAIL | VERIFY phase did not pass |
| DEPLOY_FAIL | deployment failed |
| CHECKPOINT_FAIL | checkpoint not created |

**Storage**: `.trinity/impure/*.json`

**CLI Commands**:
```bash
tri queen status      # Show impure event queue
tri queen purify     # Run Lotus Cycle on first in queue
tri queen purify --all # Purify all queued
tri queen blocked     # Show events where Queen failed
```

**Integration**:
- Hook events write to `.trinity/impure/` automatically
- Queen CLI reads queue and executes Lotus Cycle
- Each cycle phase (DIAGNOSING → VERIFY → PURIFY) writes progress to event
>>>>>>> Stashed changes
