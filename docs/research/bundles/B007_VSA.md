# B007: VSA (Vector Symbolic Architecture)

**DOI:** 10.5281/zenodo.19227877
**Version:** 8.0
**LOC:** 619

## Overview

Hyperdimensional computing implementation using binary spatter codes and HRR (Holographic Reduced Representation). Provides bind, unbind, bundle operations for symbolic AI.

## Key Features

- **Operations:** bind, unbind, bundle2/3, cosineSimilarity
- **Dimensions:** 10,000-bit binary vectors
- **SIMD:** 17× speedup with AVX2
- **JIT:** 22× speedup with runtime compilation

## Core API

```zig
// Associate two vectors
fn bind(a: []const u8, b: []const u8) []u8

// Retrieve from binding
fn unbind(bound: []const u8, key: []const u8) []u8

// Majority vote (2-3 vectors)
fn bundle2(a: []const u8, b: []const u8) []u8
fn bundle3(a: []const u8, b: []const u8, c: []const u8) []u8

// Similarity [-1, 1]
fn cosineSimilarity(a: []const f32, b: []const f32) f32
```

## Files

- Metadata: `docs/research/.zenodo.B007_v8.0.json`
- Core: `src/vsa.zig`
- Tests: `src/vsa_test.zig`

## Citation

```bibtex
@software{trinity_b007,
  title={Trinity B007: VSA — Vector Symbolic Architecture},
  author={Vasilev, Dmitrii},
  year={2026},
  doi={10.5281/zenodo.19227877},
  publisher={Zenodo}
}
```

## Links

- Zenodo: https://zenodo.org/doi/10.5281/zenodo.19227877
- GitHub: https://github.com/gHashTag/trinity
