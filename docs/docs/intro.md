---
sidebar_position: 1
slug: /
description: "Trinity — Ternary Computing Framework with VSA, BitNet LLM inference, and VIBEE compiler"
keywords: [ternary, computing, VSA, BitNet, VIBEE, Zig, FPGA, hyperdimensional]
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
| [VSA](/api/vsa) | Vector Symbolic Architecture |
| [VM](/api/vm) | Ternary Virtual Machine |
| [Hybrid](/api/hybrid) | HybridBigInt storage |
| [Firebird](/api/firebird) | LLM inference engine |
| [VIBEE](/api/vibee) | Specification compiler |
| [Plugin](/api/plugin) | Extension system |

## Getting Started

1. [Installation](/getting-started/installation)
2. [Quick Start](/tutorials/quick-start)
3. [Development Setup](/getting-started/development-setup)

## Choose Your Path

<div className="row">
<div className="col col--4">

### I'm New Here
Start with the basics and build up.
1. [Quick Start](/tutorials/quick-start) — 5 min
2. [First Project](/tutorials/first-project) — 15 min
3. [Sacred Math](/tutorials/sacred-math) — 10 min

</div>
<div className="col col--4">

### I Want to Build
Jump straight into development.
1. [Installation](/getting-started/installation)
2. [VSA Operations](/tutorials/vsa-operations) — 15 min
3. [API Reference](/api/)

</div>
<div className="col col--4">

### I'm a Researcher
Explore the mathematical foundations.
1. [Mathematical Foundations](/math-foundations/)
2. [Benchmarks](/benchmarks/)
3. [Research Archive](/research/)

</div>
</div>

## Community

- [GitHub Repository](https://github.com/gHashTag/trinity)
- [Report Issues](https://github.com/gHashTag/trinity/issues)
- [Contributing Guide](/contributing)
