---
sidebar_position: 1
slug: /
---

# Trinity Documentation

Welcome to **Trinity** — a Ternary Computing Framework with VSA, BitNet LLM inference, and VIBEE compiler.

## What is Trinity?

Trinity is a high-performance computing framework built on **balanced ternary arithmetic** `{-1, 0, +1}`. It provides:

- **Vector Symbolic Architecture (VSA)** — Hyperdimensional computing operations
- **BitNet Integration** — Efficient LLM inference with ternary weights
- **VIBEE Compiler** — Specification-driven code generation
- **Ternary Virtual Machine** — Stack-based bytecode execution

## Why Ternary?

```
φ = (1 + √5) / 2 ≈ 1.618      (Golden Ratio)
φ² + 1/φ² = 3 = TRINITY       (Trinity Identity)
```

Ternary `{-1, 0, +1}` is mathematically optimal:
- **Information density:** 1.58 bits/trit (vs 1 bit/binary)
- **Memory savings:** 20x vs float32
- **Compute:** Add-only operations (no multiply)

## Verified Achievements

| Achievement | Result | Details |
|-------------|--------|---------|
| BitNet coherent text generation | Confirmed | bitnet.cpp on RunPod RTX 4090, 3/3 prompts coherent |
| GPU inference throughput (bitnet.cpp) | 298K tok/s | RTX 3090, BitNet b1.58-2B-4T evaluation mode |
| JIT compilation speedup | 15-260x | ARM64 and x86-64 backends for VSA operations |
| HDC continual learning | 3% avg forgetting | 20 classes across 10 phases (vs 50-90% for neural nets) |
| Memory compression | 20x | Ternary packed vs float32 |
| SIMD ternary matmul | 7.65 GFLOPS | 2.28x speedup over baseline SIMD-16 |
| Model load optimization | 43x faster | Memory-mapped loading (208s to 4.8s) |
| Unit tests | 143 passing | Across all subsystems |

## Quick Start

```bash
# Clone repository
git clone https://github.com/gHashTag/trinity.git
cd trinity

# Build
zig build

# Run tests
zig build test
```

## Core Modules

| Module | Description |
|--------|-------------|
| [VSA](/docs/api/vsa) | Vector Symbolic Architecture |
| [VM](/docs/api/vm) | Ternary Virtual Machine |
| [Hybrid](/docs/api/hybrid) | HybridBigInt storage |
| [Firebird](/docs/api/firebird) | LLM inference engine |
| [VIBEE](/docs/api/vibee) | Specification compiler |
| [Plugin](/docs/api/plugin) | Extension system |

## Getting Started

1. [Installation](/docs/getting-started/installation)
2. [Quick Start](/docs/getting-started/quickstart)
3. [Development Setup](/docs/getting-started/development-setup)

## Community

- [GitHub Repository](https://github.com/gHashTag/trinity)
- [Report Issues](https://github.com/gHashTag/trinity/issues)
- [Contributing Guide](/docs/contributing)
