---
sidebar_position: 1
---

# Introduction

**Trinity** is a high-performance library for **Hyperdimensional Computing** (HDC) using balanced ternary representation.

## What is Hyperdimensional Computing?

Hyperdimensional Computing (also known as Vector Symbolic Architecture or VSA) is a computational paradigm that represents information as high-dimensional vectors and manipulates them using simple operations.

Key properties:
- **High dimensionality**: Vectors have thousands of dimensions (Trinity uses 256 trits)
- **Holographic**: Information is distributed across all dimensions
- **Robust**: Tolerant to noise and errors
- **Efficient**: Simple operations (bind, bundle, permute)

## Why Balanced Ternary?

Trinity uses balanced ternary (-1, 0, +1) instead of binary:
- **Natural negation**: Negation is just sign flip
- **Symmetric**: No bias towards positive or negative
- **Efficient**: Better information density than binary

## Features

- **8.9 B trits/sec** dot product throughput
- **256x memory savings** with hybrid storage
- **Full VM** with 20+ VSA instructions
- **Zero dependencies** - pure Zig

## Quick Example

```zig
const trinity = @import("trinity");

// Create concept vectors
var apple = trinity.randomVector(256, 1);
var red = trinity.randomVector(256, 2);

// Bind: create association "red apple"
var red_apple = trinity.bind(&apple, &red);

// Query: "What is red?"
var query = trinity.bind(&memory, &red);
const similarity = trinity.cosineSimilarity(&query, &apple);
```

## Next Steps

- [Installation](installation) - How to add Trinity to your project
- [Quick Start](quick-start) - Build your first VSA application
- [Concepts](concepts/vsa) - Deep dive into VSA operations
