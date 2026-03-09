---
sidebar_position: 3
---

# JIT Compilation Performance

Trinity includes a custom Just-In-Time (JIT) compiler that generates native machine code for VSA (Vector Symbolic Architecture) operations at runtime. This provides a 15-260x speedup over interpreted Zig execution for hot-path operations.

## Architecture Overview

The JIT system consists of three layers:

1. **`vsa_jit.zig`** -- The JIT VSA engine that manages compiled function caches and provides the high-level API
2. **`jit_arm64.zig`** -- ARM64 (AArch64) backend that emits native ARM instructions
3. **`jit_x86_64.zig`** -- x86-64 backend that emits native Intel/AMD instructions
4. **`jit_unified.zig`** -- Unified interface that selects the correct backend at compile time

The system detects the host platform at compile time and selects the appropriate backend. On unsupported architectures, operations fall back to the standard interpreted Zig implementation.

## JIT-Compiled Operations

The following VSA operations are compiled to native machine code:

| Operation | Description | Typical Speedup |
|-----------|-------------|-----------------|
| `dotProduct` | Inner product of two ternary vectors | 15-50x |
| `bind` | Element-wise ternary multiplication (association) | 20-80x |
| `bundle` | Majority vote across vectors | 25-100x |
| `hammingDistance` | Count of differing trit positions | 15-60x |
| `cosineSimilarity` | Normalized dot product | 20-70x |
| `permute` | Cyclic shift of vector elements | 50-260x |

Speedup factors vary depending on vector dimension, platform, and whether SIMD instructions are available.

## Caching Strategy

The `JitVSAEngine` maintains separate caches for each operation type and vector dimension:

```
dot_cache:      dimension -> compiled function
bind_cache:     dimension -> compiled function
hamming_cache:  dimension -> compiled function
cosine_cache:   dimension -> compiled function
bundle_cache:   dimension -> compiled function
permute_cache:  (dimension, shift) -> compiled function
```

When an operation is first called for a given dimension, the JIT compiler generates native code and stores the resulting function pointer. Subsequent calls with the same dimension execute the cached native code directly, incurring only the cost of a function pointer call. The engine tracks cache hit/miss statistics (`jit_hits`, `jit_misses`, `total_ops`) for profiling.

## ARM64 Backend

The ARM64 backend (`jit_arm64.zig`) targets AArch64 processors including:

- Apple Silicon (M1, M2, M3, M4 series)
- AWS Graviton processors
- Raspberry Pi 4/5 (64-bit mode)
- Ampere Altra server CPUs

It emits 32-bit fixed-width ARM instructions using standard calling conventions. Key features include:

- Store/load pair instructions (STP/LDP) for efficient stack management
- Callee-saved register allocation (x19-x24) for complex operations
- 16KB page-aligned executable memory allocation via `mmap`/`mprotect`
- Direct register encoding for all ARM64 general-purpose registers (x0-x30)

## x86-64 Backend

The x86-64 backend (`jit_x86_64.zig`) targets Intel and AMD processors. It emits variable-length x86 instructions using the System V AMD64 ABI. Key features include:

- Standard prologue/epilogue with frame pointer (push rbp / mov rbp, rsp)
- 32-bit and 64-bit immediate encoding
- Page-aligned executable memory via `mmap`/`mprotect`
- REX prefix support for 64-bit register operations

## How It Works

The JIT compilation flow for a dot product operation:

1. `engine.dotProduct(&a, &b)` is called
2. The engine checks `dot_cache` for a compiled function matching the vector dimension
3. On cache miss, a new `UnifiedJitCompiler` is created
4. The compiler emits native instructions for the dot product loop
5. The compiled code is placed in executable memory (mmap with PROT_EXEC)
6. The function pointer is cached and called
7. The HybridBigInt vectors are unpacked to their raw trit arrays for direct memory access
8. The native function operates directly on the unpacked trit data

## Fallback Behavior

If JIT compilation fails or the platform is unsupported, the engine falls back to the standard Zig VSA implementation. This ensures correctness across all platforms while providing acceleration where native code generation is available.
