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
2. [Quick Start](/getting-started/quickstart)
3. [Development Setup](/getting-started/development-setup)

## Community

- [GitHub Repository](https://github.com/gHashTag/trinity)
- [Report Issues](https://github.com/gHashTag/trinity/issues)
- [Contributing Guide](/contributing)
