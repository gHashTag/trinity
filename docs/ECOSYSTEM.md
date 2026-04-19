# Trinity Ecosystem

> `φ² + 1/φ² = 3 = TRINITY`

Trinity is an orchestrator connecting a family of focused micro-repositories. Each repo has a single responsibility and can be used independently.

## Dependency Graph

```
zig-golden-float          ← числовое ядро (GF16, TF3, JIT, VM)
         ↑
  zig-sacred-geometry     ← φ-геометрия, beal (~58KB)
  zig-physics             ← quantum, QCD, gravity (~36KB)
  zig-hdc                 ← HDC/VSA гиперразмерные вычисления (~352KB)
  zig-knowledge-graph     ← KG сервер + CLI (~100KB)
  trinity-training        ← HSLM, бенчмарки, датасеты (208MB data)
         ↑
  zig-agents              ← агенты, MCP (~519KB)
  zig-crypto-mining       ← BTC mining, DePIN (~60KB)
         ↑
  trinity                 ← оркестратор (build.zig.zon связывает всё)
```

## Repositories

| Repository | Role | Size | Dependencies |
|---|---|---|---|
| [zig-golden-float](https://github.com/gHashTag/zig-golden-float) | Numeric core: GF16, TF3, JIT, VM, math | ~1MB | — |
| [zig-sacred-geometry](https://github.com/gHashTag/zig-sacred-geometry) | φ-geometry, sacred constants, Beal | ~58KB | zig-golden-float |
| [zig-physics](https://github.com/gHashTag/zig-physics) | Quantum physics, QCD, gravity, dark matter | ~36KB | zig-golden-float |
| [zig-hdc](https://github.com/gHashTag/zig-hdc) | Hyperdimensional Computing, VSA, sequence_hdc | ~352KB | zig-golden-float |
| [zig-knowledge-graph](https://github.com/gHashTag/zig-knowledge-graph) | Knowledge Graph server + CLI | ~100KB | — |
| [trinity-training](https://github.com/gHashTag/trinity-training) | HSLM ML training, benchmarks, datasets | 208MB | zig-golden-float |
| [zig-agents](https://github.com/gHashTag/zig-agents) | Agents, MCP, autonomous systems | ~519KB | trinity API |
| [zig-crypto-mining](https://github.com/gHashTag/zig-crypto-mining) | BTC mining MVP, DePIN | ~60KB | — |
| [trinity](https://github.com/gHashTag/trinity) | Orchestrator, API, CLI, VIBEE, FPGA | ~500MB | all above |

## Migration History

The monolith was decomposed in April 2026:

- **~1.5GB → ~500MB** in `trinity/src/`
- **8 independent repositories** created
- **~40KB+ of duplicate code** removed
- All dependencies managed via `build.zig.zon`

## Using a Module Independently

Each micro-repo is a standalone Zig package:

```zig
// build.zig.zon
.dependencies = .{
    .zig_golden_float = .{
        .url = "https://github.com/gHashTag/zig-golden-float/archive/main.tar.gz",
        .hash = "...", // run `zig fetch` to get hash
    },
},
```

```bash
zig fetch --save https://github.com/gHashTag/zig-golden-float/archive/main.tar.gz
```
