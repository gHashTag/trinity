---
sidebar_position: 1
---

# Architecture Overview

Trinity is built on three core principles:

## Mathematical Foundation

```
φ = (1 + √5) / 2 ≈ 1.618      (Golden Ratio)
φ² + 1/φ² = 3 = TRINITY       (Trinity Identity)
```

## Core Components

```
┌─────────────────────────────────────────────────────────┐
│                      TRINITY                            │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐   │
│  │   VSA   │  │   VM    │  │ Firebird│  │  VIBEE  │   │
│  │ Vectors │  │ Execute │  │   LLM   │  │ Compile │   │
│  └────┬────┘  └────┬────┘  └────┬────┘  └────┬────┘   │
│       │            │            │            │         │
│       └────────────┴─────┬──────┴────────────┘         │
│                          │                             │
│                 ┌────────┴────────┐                    │
│                 │   HybridBigInt  │                    │
│                 │ Ternary Storage │                    │
│                 └─────────────────┘                    │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

## Modules

| Module | Purpose |
|--------|---------|
| `vsa.zig` | Vector operations |
| `vm.zig` | Bytecode execution |
| `hybrid.zig` | Ternary storage |
| `firebird/` | LLM inference |
| `vibeec/` | Code generation |

## Data Flow

1. **Specification** → `.vibee` file
2. **Generation** → VIBEE compiler
3. **Execution** → VM or native
4. **Storage** → HybridBigInt
