---
sidebar_position: 1
---

# Trinity: Ternary Computing Platform

> **Sacred Formula:** φ² + 1/φ² = 3 = TRINITY
>
> Where φ = (1 + √5) / 2 ≈ 1.618 (Golden Ratio)

## What is Trinity?

Trinity is a revolutionary computing platform that leverages **ternary logic** (-1, 0, +1) instead of traditional binary (0, 1) for massive efficiency gains in AI inference and vector operations.

### Key Benefits

| Feature | Binary | Ternary (Trinity) | Improvement |
|---------|--------|-------------------|-------------|
| Information density | 1 bit | 1.58 bits/trit | **+58%** |
| Memory usage | 32-bit floats | 1.58-bit packed | **20x less** |
| Compute | Multiply-Add | Add-only | **Simpler** |
| Energy | High | Low | **10x less** |

## Core Technologies

```
┌─────────────────────────────────────────────────────┐
│                    TRINITY STACK                     │
├─────────────────────────────────────────────────────┤
│  TRI CLI        │  Unified command-line interface   │
│  VIBEE          │  Specification language & compiler │
│  VSA Engine     │  Vector Symbolic Architecture     │
│  Ternary VM     │  Stack-based bytecode executor    │
│  Firebird       │  LLM inference engine             │
│  BitNet         │  1.58-bit neural network support  │
├─────────────────────────────────────────────────────┤
│  φ² + 1/φ² = 3  │  Mathematical foundation          │
└─────────────────────────────────────────────────────┘
```

## Quick Start

```bash
# Build Trinity
zig build

# Run TRI CLI
zig build tri

# Chat (100% local)
tri chat "Hello, how are you?"

# Generate code (multilingual)
tri code "напиши функцию фибоначчи"  # Russian
tri code "写一个斐波那契函数"          # Chinese
tri code "write fibonacci function"   # English
```

## Why Ternary?

Traditional computing uses binary (0, 1). Trinity uses balanced ternary (-1, 0, +1):

### Mathematical Foundation

The **Golden Ratio** φ connects to ternary through the Trinity identity:

$$
\phi^2 + \frac{1}{\phi^2} = 3
$$

This isn't mysticism—it's the mathematical basis for optimal information encoding:

- **Radix economy**: Base 3 is the most efficient integer base
- **Signed representation**: No separate sign bit needed
- **VSA operations**: Bind, bundle, permute work naturally

### Practical Benefits

1. **Memory**: 1.58 bits/trit vs 32 bits/float = 20x savings
2. **Compute**: Add-only operations (no multiply)
3. **Energy**: Lower switching activity

## Architecture

```
User Input
    │
    ▼
┌─────────┐     ┌─────────┐     ┌─────────┐
│ TRI CLI │────▶│  VIBEE  │────▶│   Zig   │
└─────────┘     │ Compiler│     │  Code   │
                └─────────┘     └─────────┘
                                     │
    ┌────────────────────────────────┘
    │
    ▼
┌─────────┐     ┌─────────┐     ┌─────────┐
│   VSA   │◀───▶│ Ternary │◀───▶│ Firebird│
│ Engine  │     │   VM    │     │   LLM   │
└─────────┘     └─────────┘     └─────────┘
```

## Performance

| Benchmark | llama.cpp | Trinity | Speedup |
|-----------|-----------|---------|---------|
| Inference | 100 tok/s | 2500 tok/s | **25x** |
| Memory | 4GB | 200MB | **20x** |
| Energy | 100W | 10W | **10x** |

*Benchmarks on Apple M3, 8GB RAM, SmolLM2-135M model*

## Learn More

- [Getting Started](../getting-started/installation.md)
- [VIBEE Specification Language](../vibee/specification-format.md)
- [Mathematical Foundations](../math-foundations/trinity-identity.md)
- [API Reference](../api/vsa-operations.md)

---

**KOSCHEI IS IMMORTAL | GOLDEN CHAIN ENFORCED | φ² + 1/φ² = 3**
