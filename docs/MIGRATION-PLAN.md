# TRIOS Migration Plan: Monolith → Crates

**Date:** 2026-04-19
**Goal:** Extract and link all modules from `/Users/playra/trinity/src/` to `/Users/playra/trios/crates/`

---

## Current State

### TRIOS Crates (19)
```
✅ trios-core           — Base types, SSOT schema (△)
✅ trios-git            — Git worktree automation (⑂)
✅ trios-gb             — Global build / workspace utils (📦)
✅ trios-server         — API / MCP server (⬡)
✅ trios-kg             — Knowledge graph (◉)
✅ trios-agents         — Agent orchestration (⚡)
✅ trios-training       — JEPA trainer loop (⊕)
✅ trios-training-ffi   — FFI bridge for training (↯)
✅ trios-llm            — LLM inference path (∞)
✅ trios-crypto         — Blake3 / Merkle integrity (🔒)
✅ trios-golden-float   — GF16 kernel (φ)
✅ trios-hdc            — HDC/VSA (⬛)
✅ trios-physics        — Physics constants (Ψ)
✅ trios-sacred         — Sacred geometry (✦)
✅ trios-ternary       — Ternary BitLinear + QAT (∓)
✅ precision-router    — GF16↔Ternary policy (⇌) [needs rename → trios-route]
✅ trinity-brain       — SSOT brain / `.trinity` processor (🧠)
✅ zig-agents          — Zig-based agent kernels (⚙)
✅ zig-knowledge-graph — Zig KG engine (◉⚙)
```

### Monolith Modules to Migrate

| Module | Path | Target Crate | Priority |
|--------|------|---------------|----------|
| vm.zig | src/vm.zig, src/vm/ | **trios-vm** (NEW) | P1 |
| sdk.zig | src/sdk.zig | **trios-sdk** (NEW) | P1 |
| vsa_core/ | src/vsa_core/ | **trios-vsa** (NEW) | P1 |
| vsa_hybrid/ | src/vsa_hybrid/ | **trios-hybrid** (NEW) | P1 |
| vibeec/ | src/vibeec/ | **trios-vibeec** (NEW) | P2 |
| firebird/ | src/firebird/ | **trios-firebird** (NEW) | P2 |
| tvc/ | src/tvc/ | **trios-tvc** (NEW) | P2 |
| tri/ | src/tri/ | STAY (core) | — |
| tri27/ | src/tri27/ | **trios-tri27** (NEW) | P2 |
| sacred/ | src/sacred/ | trios-sacred | P1 |
| sacred_constants.zig | src/sacred_constants.zig | trios-sacred | P1 |
| phi-engine/ | src/phi-engine/ | trios-sacred | P1 |
| ternary/ | src/ternary/ | trios-ternary | P1 |
| crypto/ | src/crypto/ | trios-crypto | P1 |
| needle/ | src/needle/ | trios-vsa | P2 |
| common/ | src/common/ | trios-core | P1 |
| brain/ | src/brain/ | trinity-brain | P1 |

---

## Phase 1: Core Primitives (P1)

### 1.1 Create `trios-vsa`
**Source:** `src/vsa_core/`
**Target:** `crates/trios-vsa/`

**Files to move:**
```
src/vsa_core/
├── common.zig          → trios-vsa/src/common.zig
├── ops.zig             → trios-vsa/src/ops.zig
├── sparse.zig          → trios-vsa/src/sparse.zig
├── encoding.zig        → trios-vsa/src/encoding.zig
└── vsa.zig             → trios-vsa/src/lib.rs (FFI)
```

### 1.2 Create `trios-hybrid`
**Source:** `src/vsa_hybrid/`
**Target:** `crates/trios-hybrid/`

**Files to move:**
```
src/vsa_hybrid/
├── bigint.zig          → trios-hybrid/src/bigint.zig
├── packed_trit.zig     → trios-hybrid/src/packed_trit.zig
├── hybrid_impl.zig     → trios-hybrid/src/hybrid_impl.zig
└── hybrid.zig          → trios-hybrid/src/lib.rs (FFI)
```

### 1.3 Update `trios-sacred`
**Source:** `src/sacred/`, `src/sacred_constants.zig`, `src/phi-engine/`
**Target:** `crates/trios-sacred/`

**Files to move:**
```
src/sacred/                    → trios-sacred/src/sacred/
src/sacred_constants.zig        → trios-sacred/src/constants.zig
src/phi-engine/                → trios-sacred/src/phi-engine/
```

### 1.4 Update `trios-ternary`
**Source:** `src/ternary/`
**Target:** `crates/trios-ternary/`

**Files to move:**
```
src/ternary/   → trios-ternary/src/ternary/
```

### 1.5 Update `trios-crypto`
**Source:** `src/crypto/`, `src/depin/`
**Target:** `crates/trios-crypto/`

**Files to move:**
```
src/crypto/    → trios-crypto/src/crypto/
src/depin/     → trios-crypto/src/depin/
```

### 1.6 Update `trios-core`
**Source:** `src/common/`, `src/core-lib/`
**Target:** `crates/trios-core/`

**Files to move:**
```
src/common/    → trios-core/src/common/
src/core-lib/  → trios-core/src/core-lib/
```

---

## Phase 2: VM Layer (P1-P2)

### 2.1 Create `trios-vm`
**Source:** `src/vm.zig`, `src/vm/`
**Target:** `crates/trios-vm/`

**Dependencies:** trios-vsa, trios-hybrid

**Files to move:**
```
src/vm.zig              → trios-vm/src/vm.zig
src/vm/
├── opcodes.zig         → trios-vm/src/opcodes.zig
├── jit.zig             → trios-vm/src/jit.zig
├── sacred.zig          → trios-vm/src/sacred.zig
└── interpreter.zig     → trios-vm/src/interpreter.zig
```

**Cargo.toml:**
```toml
[dependencies]
trios-vsa = { path = "../trios-vsa" }
trios-hybrid = { path = "../trios-hybrid" }
```

---

## Phase 3: SDK & High-Level API (P2)

### 3.1 Create `trios-sdk`
**Source:** `src/sdk.zig`
**Target:** `crates/trios-sdk/`

**Dependencies:** trios-vm, trios-vsa

**Files to move:**
```
src/sdk.zig  → trios-sdk/src/sdk.zig
```

---

## Phase 4: Compiler & ML (P2-P3)

### 4.1 Create `trios-vibeec`
**Source:** `src/vibeec/`
**Target:** `crates/trios-vibeec/`

**Dependencies:** trios-vm, trios-tri27

### 4.2 Create `trios-firebird`
**Source:** `src/firebird/`
**Target:** `crates/trios-firebird/`

**Dependencies:** trios-vm, trios-vsa

### 4.3 Create `trios-tvc`
**Source:** `src/tvc/`
**Target:** `crates/trios-tvc/`

**Dependencies:** trios-vm, trios-vsa

### 4.4 Create `trios-tri27`
**Source:** `src/tri27/`
**Target:** `crates/trios-tri27/`

**Dependencies:** trios-core

---

## Phase 5: Brain Integration (P1)

### 5.1 Update `trinity-brain`
**Source:** `src/brain/`
**Target:** `crates/trinity-brain/`

**Files to move:**
```
src/brain/  → trinity-brain/src/brain/
```

**Dependencies:** trios-vsa, trios-vm

---

## Dependency Graph (After Migration)

```
┌─────────────────────────────────────────────────────────────────────┐
│                        TRIOS Crate Dependencies                      │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌─────────────┐       ┌──────────────┐       ┌─────────────────┐ │
│  │ trios-core  │───────│ trios-vsa    │───────│   trios-vm     │ │
│  │     △       │       │               │       │                 │ │
│  └──────┬──────┘       └──────┬───────┘       └────────┬────────┘ │
│         │                     │                        │           │
│         │                     │                        ▼           │
│         │                     │                 ┌───────────┐  │
│         │                     │                 │ trios-sdk │  │
│         │                     │                 └───────────┘  │
│         │                     │                        │           │
│         │                     ▼                        ▼           │
│         │              ┌──────────────┐         ┌─────────────┐ │
│         │              │trios-hybrid │         │trios-vibeec│ │
│         │              │               │         └─────────────┘ │
│         │              └──────────────┘                        │
│         │                     │                                    │
│         │                     ▼                                    │
│         │              ┌──────────────┐                            │
│         │              │ trios-sacred │──→ trios-phi-attn          │
│         │              │     ✦        │                            │
│         │              └──────┬───────┘                            │
│         │                     │                                    │
│         ▼                     ▼                                    │
│  ┌─────────────┐       ┌──────────────┐                            │
│  │trios-ternary│       │ trios-firebird│                            │
│  │     ∓       │       │               │                            │
│  └─────────────┘       └──────────────┘                            │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Acceptance Criteria

- [ ] All monolith modules listed above are moved to TRIOS crates
- [ ] `trios-workspace` builds successfully with all new crates
- [ ] Dependencies are correctly configured in Cargo.toml
- [ ] No circular dependencies exist
- [ ] Brand Kit symbols (△, φ, ∓, ✦, etc.) are applied to all crates
- [ ] Documentation (README.md) is updated for each crate

---

## Next Steps

1. **Phase 1:** Migrate core primitives (vsa, hybrid, sacred, ternary, crypto, common)
2. **Phase 2:** Create trios-vm with dependencies
3. **Phase 3:** Create trios-sdk
4. **Phase 4:** Migrate compiler and ML modules
5. **Phase 5:** Integrate brain modules
