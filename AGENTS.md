# AGENTS.md - AI Agent Guidelines for Trinity

**Author**: Dmitrii Vasilev

## Overview

Guidelines for AI agents working on the Trinity VSA library.

## Core Principles

1. **Performance First** - Trinity targets 8.9 B trits/sec throughput
2. **Pure Zig** - No external dependencies
3. **SIMD Optimization** - Use AVX-512 for vector operations
4. **Memory Efficiency** - Hybrid storage for 256x savings

## File Organization

```
src/
├── trinity.zig          # Main entry point
├── vsa.zig              # Vector Symbolic Architecture
├── vm.zig               # Virtual Machine (20+ instructions)
├── jit.zig              # JIT compiler
├── knowledge_graph.zig  # VSA-based Knowledge Graph
├── kg_server.zig        # HTTP API server
├── kg_cli.zig           # CLI interface
├── packed_trit.zig      # Packed ternary storage
├── packed_vsa.zig       # Packed VSA operations
├── sparse.zig           # Sparse vector support
├── parallel.zig         # Multi-threaded operations
├── simd_avx512.zig      # AVX-512 optimizations
└── tvc/                 # Ternary Vector Computing
    ├── tvc_vm.zig       # TVC Virtual Machine
    ├── tvc_vsa.zig      # TVC VSA operations
    ├── tvc_bigint.zig   # BigInt for ternary
    ├── tvc_jit.zig      # TVC JIT compiler
    └── tvc_hybrid.zig   # Hybrid storage
```

## Allowed to Edit

| Path | Description |
|------|-------------|
| `src/*.zig` | Core library code |
| `src/tvc/*.zig` | TVC module |
| `kg-visualizer/src/*` | Vite UI code |
| `docs/*.md` | Documentation |
| `examples/*.zig` | Example code |
| `benchmarks/*.zig` | Benchmark code |

## Commands Reference

```bash
# Build library
zig build

# Run all tests
zig build test

# Run benchmarks
zig build bench

# Build specific module
zig build-exe src/kg_server.zig -O ReleaseFast

# Knowledge Graph Server
./kg_server 8080

# Visualizer
cd kg-visualizer && npm run dev
```

## Testing

```bash
# Run all tests
zig build test

# Test specific file
zig test src/vsa.zig

# Test with verbose output
zig test src/vsa.zig --verbose
```

## Benchmarking

```bash
# Run all benchmarks
zig build bench

# Run specific benchmark
zig build-exe src/bench.zig -O ReleaseFast && ./bench
```

## Knowledge Graph API

### Add Triple
```bash
curl -X POST http://localhost:8080/api/add \
  -H "Content-Type: application/json" \
  -d '{"subject":"Socrates","predicate":"is_a","object":"human"}'
```

### Query
```bash
curl "http://localhost:8080/api/query?subject=Socrates&predicate=is_a"
```

### Multi-hop Reasoning
```bash
curl "http://localhost:8080/api/reason?from=Socrates&to=true"
```

## Visualizer (Vite)

```bash
cd kg-visualizer
npm install
npm run dev
```

Open: http://localhost:5173

## Git Commit Format

```
<type>: <description>

Co-authored-by: Ona <no-reply@ona.com>
```

Types: `feat`, `fix`, `perf`, `docs`, `test`, `refactor`

## Performance Targets

| Metric | Target | Current |
|--------|--------|---------|
| Dot product | 10 B/s | 8.9 B/s |
| Bundle | 5 B/s | 3.4 B/s |
| Memory | 256x | 256x |
| Latency | <1ms | <1ms |

---

**TRINITY IS IMMORTAL | φ² + 1/φ² = 3**
