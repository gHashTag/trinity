---
sidebar_position: 1
---

# Benchmarks

Trinity is a high-performance ternary computing framework built in Zig, designed for both Vector Symbolic Architecture (VSA) operations and large language model inference using BitNet b1.58 ternary weights. This section provides an overview of Trinity's performance characteristics across several key dimensions.

## Key Performance Metrics

| Metric | Value | Notes |
|--------|-------|-------|
| GPU inference throughput | Up to 298K tokens/sec | RTX 3090, BitNet b1.58 via bitnet.cpp |
| JIT speedup | 15-260x | Over interpreted Zig execution for VSA ops |
| Memory compression | 20x | Ternary packed vs float32 representation |
| Compute model | Add-only | No multiply operations required for ternary weights |

### Additional Results

| Metric | Value | Notes |
|--------|-------|-------|
| SIMD ternary matmul | 7.65 GFLOPS | BatchTiled, 2.28x over SIMD-16 baseline |
| Model load time | 4.8s (NVMe) | 43x improvement over 208s (ephemeral disk) |
| HDC continual learning | 3% avg forgetting | 20 classes, 10 phases (vs 50-90% neural nets) |
| BitNet coherent text | Confirmed | bitnet.cpp on RunPod RTX 4090 |
| Unit tests passing | 143 | Across all subsystems |

## Why Ternary is Fast

Ternary \{-1, 0, +1\} weights eliminate the need for multiplication in matrix-vector products. Instead of `weight * activation`, the operation reduces to addition, subtraction, or skip. This has two major consequences: dramatically lower memory bandwidth requirements (1.58 bits per weight vs 32 bits for float32) and simpler arithmetic that maps efficiently to both CPU SIMD instructions and custom hardware.

## Performance Areas

### GPU Inference

BitNet b1.58 models running on consumer and datacenter GPUs achieve throughput measured in hundreds of thousands of tokens per second for small models. Performance varies by GPU type, model size, and batch configuration. See [GPU Inference Benchmarks](/docs/benchmarks/gpu-inference) for detailed numbers.

### JIT Compilation

Trinity includes a custom JIT compiler with backends for ARM64 (Apple Silicon, Raspberry Pi, etc.) and x86-64 (Intel/AMD). VSA operations such as bind, bundle, dot product, and permute are compiled to native machine code at runtime, with compiled functions cached for reuse. See [JIT Compilation Performance](/docs/benchmarks/jit-performance) for architecture-specific results.

### Memory Efficiency

The framework provides multiple memory representations optimized for different use cases: HybridBigInt with lazy packed/unpacked conversion, bit-packed trit arrays, and sparse COO-format vectors for data with many zeros. A 10,000-dimensional vector that would consume 40KB in float32 fits in roughly 2.5KB using packed ternary encoding. See [Memory Efficiency](/docs/benchmarks/memory-efficiency) for a detailed breakdown.

## Ternary Arithmetic Advantage

The mathematical basis for ternary efficiency comes from information theory. The optimal radix for information density is Euler's number (e ~ 2.718), and 3 is the closest integer. Each trit carries 1.58 bits of information (log2(3)), compared to 1 bit per binary digit. This means ternary representations achieve higher information density per storage unit, which translates directly to reduced memory footprint and bandwidth consumption in real workloads.
