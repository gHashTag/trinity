# Trinity Architecture Map

**Last updated**: 2026-04-19
**Status**: Phase A migration in progress

---

## TRIOS Workspace Architecture

| # | Модуль              | Тип        | FFI | test | Статус | Dependencies          | Data Flow              | Priority |
|---|---------------------|-----------|------|-----|---------|---------------------|------------------------|-----------|
| 1 | trios-core           | lib       | ✅   | N/A | ✅   | core-platform             | → agents, server, kg   | P1 ✅     |
| 2 | trios-git            | lib       | ✅   | N/A | ✅   | core                    | VCS operations          | P1 ✅     |
| 3 | trios-gitbutler       | lib       | ✅   | N/A | ✅   | git                     | git automation           | P1 ✅     |
| 4 | trios-server         | bin(MCP)  | ✅   | N/A | ✅   | core, agents             | MCP/REST API           | P1 ✅     |
| 5 | trios-kg             | lib(KG)   | ✅   | N/A | ✅   | core                    | Knowledge graph         | P1 ✅     |
| 6 | trios-agents          | lib       | ✅   | N/A | ✅   | core, kg                | Agent execution        | P1 ✅     |
| 7 | trios-training        | lib       | ✅   | N/A | ✅   | core, agents            | Training orchestration  | P1 ✅     |
| 8 | trios-crypto          | FFI       | ✅   | ✅   | 🔴   | core, golden-float       | Cryptographic ops       | P1 🔴     |
| 9 | trios-golden-float   | FFI       | ✅   | ❌   | 🔴   | core                    | Numerical kernels       | P1 🔴     |
| 10 | trios-hdc            | FFI       | ✅   | ❌   | 🔴   | core, golden-float       | Hyperdimensional compute | P1 🔴     |
| 11 | trios-physics         | FFI       | ✅   | ❌   | 🔴   | core, sacred             | Physical constants     | P1 🔴     |
| 12 | trios-sacred          | FFI       | ✅   | ❌   | 🔴   | core, sacred-geometry     | Golden sequence math    | P1 🔴     |
| 13 | trios-zig-agents      | FFI       | ✅   | ✅   | ✅   | core, zig-agents        | Zig agent runtime       | P1 ✅     |
| 14 | trios-clara (planned) | lib       | 📋   | —   | —    | —                       | MCP bridge CLARA/ParamGolf | P2        |
| 15 | trios-hdc-bridge (planned) | lib  | 📋   | —   | —    | —                       | HDC→CLARA bridge      | P3 D2–3   |
| 16 | trios-phi-quant (planned) | lib   | 📋   | —   | —    | —                       | φ‑quantization          | P3 D4–5   |
| 17 | trios-fibonacci-attn (planned) | lib | 📋   | —   | —    | —                       | Fibonacci attention    | P3 D6–7   |
| 18 | trios-ensemble (planned) | lib    | 📋   | —   | —    | —                       | Ensemble orchestrator | P3 D8–9   |
| 19 | trios-agi-bench (planned) | lib   | 📋   | —   | —    | —                       | 5 AGI tracks wrapper  | P3 parallel |

---

## Visual Data Flow

```
┌────────────────────────────────────────────────────────────────────────────────────────────┐
│                        trios-core (P1 ✅)                               │
│                   ┌───────┴───────┐                                      │
│                   │               │                                      │
│       ┌───────────┴───┐   ┌───────┴───────────┐                       │
│       │               │   │                   │                              │
│   trios-git      trios-kg   trios-server        trios-agents                 │
│   (P1✅)         (P1✅)     (P1✅)            (P1✅)                      │
│       │               │           │                   │                              │
│       ▼               ▼           ▼                   ▼                              │
│   trios-gitbutler  ▼   MCP/REST          trios-training                       │
│   (P1✅)           │           API               (P1✅)                             │
│                   │           │                   │                              │
│                   └─────┬─────┴───────────────────┘                              │
│                         │                                                       │
│                         ▼                                                       │
│              ┌──────────────────────┐                                     │
│              │   FFI Layer (RED)   │                                     │
│   ┌──────────┴────┬──────┬──────┴───────────┐                               │
│   │             │      │      │                │                                  │
│   ▼             ▼      ▼      ▼                ▼                                  │
│ trios-      trios-  trios-  trios-      zig-hdc    zig-physics               │
│ crypto(P1🔴)  golden  hdc(P1🔴) physics(P1🔴)  (🔴)        (🔴)                         │
│   │          │float    │      │                │                                  │
│   └──────────┴──────┴──────┴────────────────┘                                  │
│        (vendor submodules missing or symbols mismatch)                             │
└────────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## Component Dependencies

### Core Platform (tri-core)
- Provides: cell, memory, API foundations
- Consumers: All trios-* modules
- Status: ✅ GREEN

### Compute Layer (FFI)
```
trios-crypto ──┬─> zig-golden-float (sha256 kernels)
                │
trios-golden-float ──> zig-golden-float (numerical ops)
                │
trios-hdc ──┬─> zig-hdc (HDC operations)
           └─> zig-golden-float (hyperdimensional ops)
                │
trios-physics ──┬─> zig-physics (physical constants)
                └─> zig-sacred (golden sequence math)
                │
trios-sacred ──┬─> zig-sacred-geometry (sacred sequences)
                └─> zig-golden-float (golden ops)
```

### Orchestration Layer
```
trios-agents ──> trios-training ──> Model orchestration
     │
trios-server ──> MCP API ──> External agents
```

---

## Module Roles

| Модуль | Responsibility | Exports | Notes |
|--------|----------------|----------|--------|
| trios-core | Platform API, cell runtime, memory management | Cell, API, IO | Foundation for all TRIOS |
| trios-git | Secure Git operations (commit, branch, push) | GitCmd, GitSafe | Crypto-backed VCS |
| trios-gitbutler | Git automation, PR management | ButlerOps | Event-driven git worklow |
| trios-server | MCP/REST API server | MCP Server, REST | Main API entrypoint |
| trios-kg | Knowledge graph operations | GraphDB, VectorDB | Semantic indexing |
| trios-agents | Agent execution runtime | Agent, Sandbox | Multi-agent orchestration |
| trios-training | Training pipeline orchestration | Trainer, Checkpoint | Model training coordination |
| trios-crypto | Cryptographic primitives (hash, sign, verify) | Hash, Sig, KDF | Security primitives |
| trios-golden-float | Numerical kernel wrappers | GF16, compress, quantize | Golden float ops |
| trios-hdc | Hyperdimensional computing | HDC, Map, Bind | HDC vector operations |
| trios-physics | Physical constant bindings | Constants, Gamma | Physics constraints |
| trios-sacred | Sacred geometry operations | Sequence, Golden | Golden sequence math |
| trios-zig-agents | Zig agent runtime wrapper | ZigAgent, ZigSandbox | Zig code execution |

---

## Legend

| Статус | Значение |
|---------|-----------|
| ✅ GREEN | Module functional, all tests passing |
| 🟡 YELLOW | In development, partial implementation |
| 🔴 RED | Blocked by critical issues |
| 📋 PLANNED | Specified but not started |
| — N/A | Not applicable |

| Тип | Значение |
|-----|-----------|
| lib | Library crate |
| bin | Binary / executable |
| FFI | Foreign Function Interface wrapper |
| MCP | Model Context Protocol server |

---

## Related Documents

- **TECH_DEBT.md**: Outstanding technical debt
- **OPERATIONAL_PLAN.md**: Active tasks and timelines
- **RED_LIST.md**: Current blockers tracking
- **ARCHITECTURE-MULTIREPO.md**: Multi-repo architecture overview
