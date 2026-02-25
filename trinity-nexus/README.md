# Trinity Nexus

**Modular Ecosystem for Ternary Computing, VSA Operations, and Symbolic AI**

```
phi² + 1/phi² = 3 = TRINITY
```

---

## Overview

Trinity Nexus is a **modular Zig workspace** organized into 6 interdependent modules. Each module has a specific responsibility and can be used independently or as part of the unified ecosystem.

### Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         TRINITY NEXUS WORKSPACE                             │
│                    phi² + 1/phi² = 3 = TRINITY                             │
└─────────────────────────────────────────────────────────────────────────────┘

    ┌──────────────┐     ┌──────────────┐     ┌──────────────┐
    │   trinity-   │────▶│   trinity-   │────▶│   trinity-   │
    │     core     │     │     lang     │     │     symb     │
    │  (foundation)│     │  (compiler)  │     │  (symbolic)  │
    └──────────────┘     └──────────────┘     └──────────────┘
           │                     │                     │
           │                     ▼                     ▼
           │              ┌──────────────┐     ┌──────────────┐
           │              │   trinity-   │     │   trinity-   │
           └─────────────▶│   network    │◀────│    (VSA+KG)  │
                          │   (p2p/dht)  │     └──────────────┘
                          └──────────────┘
                                 │
           ┌─────────────────────┼─────────────────────┐
           ▼                     ▼                     ▼
    ┌──────────────┐     ┌──────────────┐     ┌──────────────┐
    │   trinity-   │     │   trinity-   │◀────│   trinity-   │
    │    canvas    │     │    tools     │──── │   (all)      │
    │   (visual)   │     │  (cli/dev)   │     └──────────────┘
    └──────────────┘     └──────────────┘
```

### Dependency Graph

| Module | Depends On | Responsibility |
|--------|-----------|----------------|
| **core** | none | VSA operations, Ternary VM, JIT |
| **lang** | core | VIBEE compiler, code generation |
| **symb** | core, lang | Knowledge graphs, TVC |
| **network** | core, symb | DHT, P2P, sharding, consensus |
| **canvas** | core | Photon engine, UI framework |
| **tools** | all modules | CLI, benchmarks, utilities |

---

## Quick Start

### Requirements

- **Zig 0.15.x** — [Install Zig](https://ziglang.org/download/)

### Build Commands

```bash
# From repository root
cd trinity-nexus

# Build all modules
zig build

# Build specific module
zig build trinity-core
zig build trinity-lang
zig build trinity-symb
zig build trinity-network
zig build trinity-canvas
zig build trinity-tools

# Run all tests
zig build test

# Run specific module tests
zig build test-core    # Core tests (no deps)
zig build test-lang    # Lang tests (deps: core)
zig build test-symb    # Symb tests (deps: core, lang)
zig build test-network # Network tests (deps: core, symb)
zig build test-canvas  # Canvas tests (deps: core)
zig build test-tools   # Tools tests (deps: all)
```

---

## Module Details

### trinity-core

**Foundation** — VSA operations, Ternary VM, JIT acceleration

```
exports:
  - HybridBigInt    (ternary big integer)
  - Trit            (-1, 0, +1)
  - vsa.*           (bind, unbind, bundle, similarity)
  - vm.*            (stack-based bytecode VM)
  - sdk.*           (high-level API)
  - jit.*           (just-in-time compilation)
```

**Usage:**
```zig
const core = @import("trinity-nexus/core");
const Hypervector = core.sdk.Hypervector;

var hv = try Hypervector.init(allocator, 1024);
defer hv.deinit(allocator);
```

---

### trinity-lang

**VIBEE Compiler** — Specification-driven code generation

```
exports:
  - vibee_parser       (parse .vibee specs)
  - zig_codegen        (generate Zig code)
  - verilog_codegen    (generate Verilog)
  - lang_generators    (42+ language targets)
```

**Usage:**
```bash
# Generate code from .vibee specification
zig build vibee -- gen specs/tri/feature.vibee
```

---

### trinity-symb

**Symbolic AI** — Knowledge graphs, TVC (Ternary Vector Computing)

```
exports:
  - triples_parser     (extract RDF triples)
  - kg_sync            (DHT-based sync)
  - igla_knowledge_graph
  - tvc_*              (TVC subsystem)
```

---

### trinity-network

**P2P Network** — DHT routing, sharding, consensus

```
exports:
  - network            (P2P protocol)
  - manifest_dht       (DHT implementation)
  - shard_manager      (automatic sharding)
  - reputation_consensus
  - cross_shard_tx
  - erasure_repair
  - storage            (remote storage)
```

---

### trinity-canvas

**Visualization** — Photon engine, Trinity Canvas UI

```
exports:
  - photon             (visualization engine)
  - theme              (color system)
  - panel              (UI components)
  - sacred_worlds      (canvas worlds)
```

---

### trinity-tools

**Development Tools** — CLI, benchmarks, utilities

```
exports:
  - maxwell            (AI agent)
  - tri_cmd            (TRI commander)
  - debugger
  - profiler
  - lsp                (language server)
  - bench_*            (benchmarks)
```

---

## Workspace Structure

```
trinity-nexus/
├── build.zig              # Master build (workspace wiring)
├── README.md              # This file
├── core/                  # Module: trinity-core
│   └── src/
│       └── root.zig       # Module exports
├── lang/                  # Module: trinity-lang
│   └── src/
│       └── root.zig
├── symb/                  # Module: trinity-symb
│   └── src/
│       └── root.zig
├── network/               # Module: trinity-network
│   └── src/
│       └── root.zig
├── canvas/                # Module: trinity-canvas
│   └── src/
│       └── root.zig
├── tools/                 # Module: trinity-tools
│   └── src/
│       └── root.zig
└── output/                # Generated code output
```

---

## Development

### Adding a New Module

1. Create module directory: `trinity-nexus/new_module/src/`
2. Create `root.zig` with module exports
3. Add to `build.zig`:
   ```zig
   const new_mod = b.createModule(.{
       .root_source_file = b.path("new_module/src/root.zig"),
       .target = target,
       .optimize = optimize,
       .imports = &.{
           .{ .name = "trinity-core", .module = core_mod },
           // add dependencies
       },
   });
   ```

### Module Imports

Within the workspace, modules import each other using their registered names:

```zig
// In trinity-symb/src/root.zig
const core = @import("trinity-core");  // Works because of workspace wiring
const lang = @import("trinity-lang");
```

---

## Documentation

- [Core Module](./core/README.md) — VSA operations, VM
- [Lang Module](./lang/README.md) — VIBEE compiler
- [Symb Module](./symb/README.md) — Knowledge graphs, TVC
- [Network Module](./network/README.md) — P2P, DHT
- [Canvas Module](./canvas/README.md) — Photon engine
- [Tools Module](./tools/README.md) — CLI, utilities

---

## Sacred Mathematics

Trinity is built on sacred mathematical principles:

```
φ = 1.618033988749895  (Golden Ratio)
φ² = 2.618033988749895
φ⁻² = 0.381966011250105

φ² + 1/φ² = 3  ← TRINITY IDENTITY
```

Ternary computing {-1, 0, +1} provides:
- Information density: 1.58 bits/trit (vs 1 bit/binary)
- Memory savings: 20x vs float32
- Compute: Add-only (no multiply needed)

---

## License

MIT License — See LICENSE file in repository root.

---

**φ² + 1/φ² = 3**
