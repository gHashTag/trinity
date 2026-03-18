# Trinity Nexus Architecture

> Modular ternary computing framework — Zig 0.15.x
> phi^2 + 1/phi^2 = 3 = TRINITY

---

## Overview

Trinity Nexus is the modular reorganization of the Trinity ternary computing framework. The monolithic `src/` directory has been decomposed into 6 independent modules, each with its own build system, dependency declarations, and test suite.

**Total: 272 files, ~136K lines of Zig across 6 modules.**

---

## Module Map

| Module | Path | Files | Lines | Dependencies | Purpose |
|--------|------|-------|-------|--------------|---------|
| **core** | `trinity-nexus/core/` | 40 | 22,563 | (none) | VSA operations, Ternary VM, HybridBigInt, packed trits, SDK |
| **lang** | `trinity-nexus/lang/` | 39 | 25,647 | core | VIBEE compiler, parser, codegen (Zig/Verilog/Python/Rust/TS) |
| **symb** | `trinity-nexus/symb/` | 30 | 13,719 | core, lang | Symbolic AI, KG pipeline, TVC subsystem, triples extraction |
| **network** | `trinity-nexus/network/` | 62 | 32,414 | core, symb | P2P, DHT, sharding, consensus, erasure coding, crypto, DePIN |
| **canvas** | `trinity-nexus/canvas/` | 27 | 18,127 | core | Photon rendering engine, Trinity Canvas UI, 27-petal animation |
| **tools** | `trinity-nexus/tools/` | 74 | 23,267 | all 5 | CLI, DevTools, benchmarks, Maxwell agent, Phi-engine, utilities |

---

## Dependency Graph

```text
                    ┌──────────┐
                    │   core   │  (foundation — no deps)
                    │ 40 files │
                    └────┬─────┘
                         │
              ┌──────────┼──────────┐
              │          │          │
        ┌─────▼────┐ ┌──▼───┐ ┌───▼────┐
        │   lang   │ │canvas│ │  symb  │
        │ 39 files │ │27 f. │ │30 files│
        └─────┬────┘ └──────┘ └───┬────┘
              │                    │
              │              ┌─────▼─────┐
              │              │  network  │
              │              │ 62 files  │
              │              └───────────┘
              │
        ┌─────▼──────────────────────────┐
        │            tools               │
        │   (depends on ALL 5 modules)   │
        │          74 files              │
        └────────────────────────────────────┘
```

### Dependency Declarations

| Module | Imports via build.zig| Resolves from build.zig.zon |
|--------|-----------------------|-----------------------------|
| core | (none) | (none) |
| lang | `trinity-core` | `trinity_core = { .path = "../core" }` |
| symb | `trinity-core`, `trinity-lang` | `trinity_core`, `trinity_lang` |
| network | `trinity-core`, `trinity-symb` | `trinity_core`, `trinity_symb` |
| canvas | `trinity-core` | `trinity_core` |
| tools | all 5 | all 5 path deps |

---

## Build System

### Master Build (build.zig / build.nexus.zig)

The workspace root `trinity-nexus/build.zig` creates all 6 modules in topological order with proper `.imports` wiring:

```zig
const core_mod = b.createModule(.{ .root_source_file = b.path("core/src/root.zig"), ... });
const lang_mod = b.createModule(.{ ..., .imports = &.{ .{ .name = "trinity-core", .module = core_mod } } });
// ... and so on for symb, network, canvas, tools
```

Each module also has its own `build.zig` for standalone builds using `b.dependency()` from `build.zig.zon`.

### Build Commands

```bash
# From trinity-nexus/
zig build                    # Build all 6 modules
zig build test               # Run all tests
zig build test-core          # Test only core module
zig build test-lang          # Test only lang module
zig build test-symb          # Test only symb module
zig build test-network       # Test only network module
zig build test-canvas        # Test only canvas module
zig build test-tools         # Test only tools module
```

### CI/CD

GitHub Actions workflow at `.github/workflows/nexus-build.yml`:
- Triggers on push to `ralph/*` and `main` branches
- Matrix strategy: builds and tests each module independently
- Final `build-all` job runs full workspace build + test

---

## Module Details

### core (Foundation)

The core module contains the foundational VSA (Vector Symbolic Architecture) operations and ternary computing primitives.

**Key components:**
- `vsa.zig` — bind, unbind, bundle, similarity, permute operations
- `vm.zig` — Stack-based ternary bytecode virtual machine
- `hybrid.zig` — HybridBigInt: packed (1.58 bits/trit) <-> unpacked cache
- `packed_trit.zig` — Bit-packed ternary encoding
- `sdk.zig` — High-level API (Hypervector, Codebook)

**Entry point:** `core/src/root.zig` (37 lines, 26 pub exports)

### lang (VIBEE Compiler)

The lang module contains the VIBEE specification-driven compiler that generates code in multiple target languages.

**Key components:**
- `vibee_parser.zig` — Parse `.vibee` specification files
- `zig_codegen.zig` — Generate Zig code from specs
- `verilog_codegen.zig` — Generate Verilog for FPGA targets
- `lang_generators.zig` — Python, TypeScript, Rust, Go, Java, Swift, Kotlin, C, SQL generators
- `codegen/` — 20-file codegen subsystem (emitter, builder, tests)

**Entry point:** `lang/src/root.zig` (59 lines, 15 pub exports)

### symb (Symbolic AI)

The symb module implements symbolic reasoning, knowledge graph operations, and ternary vector computing.

**Key components:**
- KG pipeline (SYM-001 through SYM-005): triples extraction, DHT sync, rewards
- TVC subsystem: ternary vector corpus search, embeddings
- IGLA: hybrid LLM + symbolic reasoning integration

**Entry point:** `symb/src/root.zig` (62 lines, 15 pub exports)

### network (Distributed Infrastructure)

The network module handles all distributed computing: P2P networking, DHT, consensus, and DePIN economics.

**Key components:**
- Core P2P: network.zig, protocol.zig, discovery.zig, connection_pool.zig
- DHT: Kademlia-based manifest distribution
- Sharding: 6 files (manager, rebalancer, scrubber, auto, VSA encoder, locks)
- Consensus & Reputation: consensus.zig, node_reputation.zig
- Distributed Transactions: cross-shard TX, parallel saga, WAL
- Erasure Coding: Reed-Solomon repair, dynamic erasure, rate limiter
- Crypto & Token Economics: wallet, staking, slashing, proof-of-storage
- Monitoring: Prometheus metrics, bandwidth aggregation

**Entry point:** `network/src/root.zig` (146 lines, 52 pub exports)

### canvas (UI)

The canvas module contains the Photon rendering engine and Trinity Canvas UI system.

**Key components:**
- Photon engine: GPU-accelerated rendering pipeline (6 files)
- Trinity Canvas: 27-petal animation system, mode switching (10 files)
- UI framework: widgets, layout, events (6 files)
- Node GUI: Photon-based node management interface

**Entry point:** `canvas/src/root.zig` (71 lines, 16 pub exports)

### tools (CLI & DevTools)

The tools module aggregates CLI interfaces, development tools, benchmarks, and utility agents.

**Key subdirectories:**
- `cli/` (9 files) — Trinity CLI, REPL, tri_cmd
- `devtools/` (15 files) — Debugger, profiler, LSP, validators, formatters
- `bench/` (13+7 files) — Benchmark suite (SIMD, JIT, compression)
- `gen/` (6 files) — Spec generators, batch generation
- `util/` (11 files) — JSON parser, HTTP, WebSocket, circuit breaker
- `maxwell/` (7 files) — Maxwell autonomous code analysis agent
- `phi/` (5 files) — Quantum-inspired Ouroboros computation engine

**Entry point:** `tools/src/root.zig` (142 lines, 44 pub exports)

---

## Workspace Configuration

### .trinity/workspace.toml

Central workspace configuration defining module membership, dependency graph, agent roles, and CI settings.

```toml
[workspace]
name = "trinity-nexus"
version = "0.9.0"

[workspace.members]
core = "trinity-nexus/core"
lang = "trinity-nexus/lang"
# ... (6 modules)

[dependencies]
core = []
lang = ["core"]
symb = ["core", "lang"]
network = ["core", "symb"]
canvas = ["core"]
tools = ["core", "lang", "symb", "network", "canvas"]

[external.openclaw]
path = "/Users/playra/openclaw"
optional = true

[agents.ralph]
role = "autonomous-developer"
permissions = ["read", "write", "build", "test", "commit"]
```

### .trinity/config.toml

Agent-specific configuration: Ralph (autonomous developer), clawd (code reviewer), openclaw (Telegram reporting).

---

## Mathematical Foundation

Trinity's ternary {-1, 0, +1} system provides:

| Property | Value | Comparison |
|----------|-------|------------|
| Information density | 1.58 bits/trit | vs 1 bit/binary |
| Memory savings | 20x | vs float32 |
| Compute model | Add-only | No multiply needed |
| Trinity Identity | phi^2 + 1/phi^2 = 3 | Where phi = (1+sqrt(5))/2 |

---

## Migration History (NEXUS-001 through NEXUS-010)

| Node | Task | Files | Lines | Commit |
|------|------|-------|-------|--------|
| NEXUS-001 | Repository structure | 21 | — | Initial |
| NEXUS-002 | Core VM migration | 39 | 22,563 | Committed |
| NEXUS-003 | VIBEE compiler migration | 38 | 28,186 | Committed |
| NEXUS-004 | Symbolic AI migration | 29 | 15,650 | Committed |
| NEXUS-005 | Canvas UI migration | 26 | 20,948 | Committed |
| NEXUS-006 | Network migration | 60 | 37,534 | Committed |
| NEXUS-007 | Tools migration | 73 | 26,629 | Committed |
| NEXUS-008 | Workspace wiring | 15 | — | Committed |
| NEXUS-009 | Agent collaboration | 4 | — | Committed |
| NEXUS-010 | Architecture docs | — | — | This commit |

---

## Tech Tree Progress

Nexus branch: **10/10 (100%)** — All migration nodes complete.

Overall: **41/54 (76%)**

---

phi^2 + 1/phi^2 = 3 | TRINITY
