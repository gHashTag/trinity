# CLAUDE.md - Trinity Development Guidelines

**Author**: Dmitrii Vasilev
**Sacred Formula**: `φ² + 1/φ² = 3`

## Overview

Trinity is a high-performance Ternary Vector Symbolic Architecture (VSA) library for hyperdimensional computing.

## Project Structure

```
trinity/
├── src/
│   ├── trinity.zig      # Core VSA operations
│   ├── vsa.zig          # Vector Symbolic Architecture
│   ├── vm.zig           # Virtual Machine
│   ├── jit.zig          # JIT compiler
│   ├── knowledge_graph.zig  # VSA-based Knowledge Graph
│   ├── kg_server.zig    # HTTP API server
│   ├── kg_cli.zig       # CLI for Knowledge Graph
│   └── tvc/             # Ternary Vector Computing
│       ├── tvc_vm.zig       # TVC Virtual Machine
│       ├── tvc_vsa.zig      # TVC VSA operations
│       ├── tvc_bigint.zig   # BigInt for ternary
│       └── tvc_jit.zig      # TVC JIT compiler
├── kg-visualizer/       # Vite + D3.js UI
│   ├── src/
│   │   ├── main.js      # D3.js visualization
│   │   └── style.css    # Dark theme styles
│   ├── index.html
│   └── vite.config.js
├── benchmarks/
├── examples/
└── docs/
```

## Commands

```bash
# Build
zig build

# Run tests
zig build test

# Run benchmarks
zig build bench

# Knowledge Graph Server
zig build-exe src/kg_server.zig -O ReleaseFast
./kg_server 8080

# Visualizer (requires Node.js)
cd kg-visualizer && npm install && npm run dev
```

## API Endpoints (kg_server)

| Method | Path | Description |
|--------|------|-------------|
| GET | / | Interactive visualization |
| GET | /api/graph | D3.js graph format |
| GET | /api/reason | Multi-hop reasoning |
| POST | /api/add | Add triple |
| GET | /api/query | Query graph |
| GET | /api/stats | Statistics |
| POST | /api/clear | Clear graph |

## Core Concepts

### Ternary Values
- `-1` (negative)
- `0` (neutral)
- `+1` (positive)

### VSA Operations
- `bind(A, B)` - Create associations
- `bundle(A, B)` - Combine vectors
- `permute(A, n)` - Encode sequences
- `similarity(A, B)` - Compare vectors

### Knowledge Graph
- Triples: (Subject, Predicate, Object)
- Embeddings: Hash-based for fast similarity
- Reasoning: BFS path finding

## Performance

| Operation | Throughput |
|-----------|------------|
| Dot product | 8.9 B trits/s |
| Bundle | 3.4 B trits/s |
| Bind | 425 M ops/s |
| Similarity | 2.0 B ops/s |

## Development Rules

1. **Pure Zig** - No external dependencies
2. **SIMD First** - Use AVX-512 where available
3. **Memory Efficient** - Hybrid storage (256x savings)
4. **Test Everything** - Unit tests for all modules

## Git Workflow

```bash
git add .
git commit -m "feat: description

Co-authored-by: Ona <no-reply@ona.com>"
git push
```

---

**TRINITY IS IMMORTAL | φ² + 1/φ² = 3**
