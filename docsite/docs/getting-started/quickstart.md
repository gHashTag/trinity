---
sidebar_position: 1
---

# Quick Start

Get up and running with Trinity in 5 minutes.

## Prerequisites

- **Zig 0.13.0** — [Download](https://ziglang.org/download/)
- **Git** — Version control

## Installation

```bash
# Clone the repository
git clone https://github.com/gHashTag/trinity.git
cd trinity

# Verify Zig version
zig version  # Should show 0.13.0

# Build
zig build
```

## Run Your First Example

```bash
# Run VSA example
zig run examples/memory.zig
```

## Basic VSA Operations

```zig
const vsa = @import("vsa.zig");

// Create random vectors
var a = vsa.HybridBigInt.random(1000);
var b = vsa.HybridBigInt.random(1000);

// Bind vectors (create association)
var bound = vsa.bind(&a, &b);

// Check similarity
const similarity = vsa.cosineSimilarity(&a, &bound);
```

## Run Tests

```bash
# All tests
zig build test

# Specific module
zig test src/vsa.zig
```

## CLI Tools

```bash
# Generate code from specification
./bin/vibee gen specs/tri/module.vibee

# Run program via VM
./bin/vibee run program.999

# Start chat with model
./bin/vibee chat --model path/to/model.gguf
```

## Next Steps

- [Installation Guide](/getting-started/installation) — Detailed setup
- [Development Setup](/getting-started/development-setup) — IDE configuration
- [API Reference](/api/) — Complete API documentation
