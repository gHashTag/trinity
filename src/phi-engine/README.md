# VIBEE Phi-Engine

## Overview

**VIBEE Phi-Engine** is a set of Zig libraries for high-performance computing using "Sacred Constants" such as the Golden Ratio (φ), π, and e (base of natural logarithm).

**Philosophy**: *"We don't just compute. We resonate with the golden proportion."*

---

## Solution Status Matrix

| # | Name | Status | Tests | Notes |
|---|---|---|---|---|
| **0** | **MVP Core** (Quantum Trit-Code Engine) | ✅ **Done** | **15/15** | Tritizer, Qutritizer, Quantum Agent (100% complete) |
| **3** | **Fibonacci Hash** | ✅ **Done** | **11/11** | Optimal hash function (Knuth) |
| **4** | **SIMD Ternary** | ✅ **Done** | **11/11** | 32× trit parallelism (Setun) |
| **7** | **Phi Spiral** | ✅ **Done** | **5/5** | Optimal 2D filling (Pohl) |
| **2** | **Lucas Numbers** | ✅ **Done** | **11/11** | Lucas numbers (related to φ) |
| **8** | **Inline Cost** | ✅ **Done** | **10/10** | Inlining cost (Amdahl) |
| **9** | **IR Types** | ✅ **Done** | **13/13** | Intermediate representation (SSA) |
| **10** | **CHSH Quantum** | ✅ **Done** | **10/10** | Bell inequality violation (Bell) |
| **11** | **Qutrit State** | ✅ **Done** | **9/9** | Qutrit state (α, β, γ) |
| **1** | **AMR Resize** | ⚠️ **WIP** | **-/-** | Adaptive mesh (Zig 0.15 API issues) |
| **6** | **Phi Lerp** | ⏭ **Unknown** | **-/-** | Linear interpolation (no explicit errors) |

---

## Build

**Requirements**:
- **Zig**: 0.15.2 (or newer)
- **Operating System**: macOS / Linux / Windows (WSL)

**Instructions**:

```bash
# 1. Navigate to Phi-Engine directory
cd phi-engine

# 2. Compile all solutions (for full build)
zig build

# 3. Run tests for specific solution
zig test src/runtime/golden_wrap.zig      # Golden Wrap
zig test src/hashmap/phi_hash.zig         # Fibonacci Hash
zig test src/runtime/simd_ternary.zig     # SIMD Ternary
zig test src/scheduler/phi_spiral.zig     # Phi Spiral
zig test src/core/compute/lucas.zig       # Lucas Numbers
zig test src/core/inline_cost.zig         # Inline Cost
zig test src/core/ir_types.zig            # IR Types
zig test src/runtime/chsh_quantum.zig     # CHSH Quantum
zig test src/runtime/qutrit_state.zig     # Qutrit State

# 4. Run MVP tests (Quantum Trit-Code Engine)
zig test src/quantum/tritizer.zig         # Tritizer
zig test src/quantum/qutritizer.zig       # Qutritizer
zig test src/quantum/quantum_agent.zig    # Quantum Agent
```

---

## MVP: Quantum Trit-Code Engine

**Goal**: Demonstrate complete cycle `Code -> Trits -> Quantum Amplitudes -> Measurement`.

**Philosophy**: *"Code is not just strings. It's an array of trits awaiting collapse into a solution."*

**Modules (100% Complete)**:

1. **Tritizer** (`src/quantum/tritizer.zig`)
   - `stringToTrits`: ASCII -> Trits (O(1) per character).
   - `tritsToString`: Trits -> Visualization (`['N', '0', 'P']`).

2. **Qutritizer** (`src/quantum/qutritizer.zig`)
   - `tritsToQutrit`: Trits -> Amplitudes (`α`, `β`, `γ`).
   - "Code Biasing" logic: Amplify amplitude of most frequent trit.

3. **Quantum Agent** (`src/quantum/quantum_agent.zig`)
   - `search`: Grover-like algorithm simulation.
   - Complexity: O(√N) iterations vs O(N) classical search.

**Connection to VIBEE Phi-Engine**:
- **3 = φ² + 1/φ²** — "Trinity" of amplitudes.
- **Qutrit** (3 states) — Connection to Sacred Trinity.

---

## Project Structure

```
phi-engine/
├── src/
│   ├── quantum/          # MVP: Quantum Trit-Code Engine
│   │   ├── tritizer.zig    # (Done) Code -> Trits
│   │   ├── qutritizer.zig  # (Done) Trits -> Amplitudes
│   │   └── quantum_agent.zig # (Done) Amplitudes -> Search
│   ├── runtime/           # Runtime libraries
│   │   ├── golden_wrap.zig   # (Done) Golden Wrap (Solution #4)
│   │   ├── chsh_quantum.zig   # (Done) Bell Test (Solution #10)
│   │   ├── qutrit_state.zig   # (Done) Qutrit State (Solution #11)
│   │   └── simd_ternary.zig    # (Done) SIMD Ternary (Solution #5)
│   ├── hashmap/           # Hash tables
│   │   └── phi_hash.zig      # (Done) Fibonacci Hash (Solution #3)
│   ├── scheduler/          # Schedulers
│   │   └── phi_spiral.zig    # (Done) Phi Spiral (Solution #7)
│   ├── core/               # Core algorithms
│   │   ├── compute/          # Computations
│   │   │   └── lucas.zig     # (Done) Lucas Numbers (Solution #2)
│   │   ├── inline_cost.zig   # (Done) Inline Cost (Solution #8)
│   │   └── ir_types.zig     # (Done) IR Types (Solution #9)
│   ├── cache/              # Caches (Solution #6: Phi Lerp)
│   │   └── phi_lerp.zig      # (WIP)
│   └── cli/                # CLI utilities
│       └── vibee_quantum.zig # (Done) MVP CLI
├── docs/                 # Documentation
│   ├── MVP_QUANTUM_TRIT_CODE_ENGINE_TZ.md # (Done) MVP Spec
│   └── FINAL_MASTER_REPORT_2025.md      # (Done) Global Report
└── vibee-quantum      # (Done) MVP CLI Executable
```

---

## Sacred Geometry Connections

1. **3 = φ² + 1/φ²**: Trinity of amplitudes (`α`, `β`, `γ`) in qutrit.
2. **L(n) ≈ φⁿ**: Lucas numbers grow at golden ratio rate.
3. **φ = 1.618...**: Used in Phi Lerp, Phi Spiral.
4. **Golden Wrap (Solution #4)**: Modular arithmetic operation for trits.
5. **Qutrit (3 states)**: Connection to Sacred Trinity.

---

## Notes

- **Solution #1 (AMR Resize)** and **Solution #6 (Phi Lerp)** — have technical issues with Zig 0.15 API (LSP Warnings).
- **Solution #4 (SIMD Ternary)** — Implemented as wrapper over `[32]i8` (real SIMD requires external dependencies).
- **MVP CLI** — Works (demonstration). Import path fixes in development.

---

## Contributing

**Goal**: Accelerate Phi-Engine to 1000×.

**How to help**:
1. **Fix Solution #1 and #6**: Resolve Zig 0.15 API issues.
2. **Implement real SIMD operations**: Use `std.simd` for `Vec32i8`.
3. **Add new solutions**: Braid interleaving, Delaunay triangulation (with φ-coefficients).
4. **Improve tests**: Add performance benchmarks.

**Contact**: `https://github.com/gHashTag/trinity/issues`
