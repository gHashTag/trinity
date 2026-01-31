---
sidebar_position: 10
---

# Benchmarks

Performance measurements on 256-dimensional balanced ternary vectors.

## Operation Performance

| Operation | Time | Throughput |
|-----------|------|------------|
| **Dot Product** | 28 ns/op | **8.9 B trits/sec** |
| Bundle3 | 75 ns/op | 3.4 B trits/sec |
| Cosine Similarity | 127 ns/op | 2.0 B trits/sec |
| Permute | 509 ns/op | 502 M trits/sec |
| Bind | 602 ns/op | 425 M trits/sec |

## Memory Efficiency

Trinity uses hybrid storage for optimal memory/speed trade-off:

| Storage Mode | Memory per Vector | Speed |
|--------------|-------------------|-------|
| Unpacked | 256 bytes | Fastest |
| Packed | 52 bytes | 4.9x smaller |
| **Hybrid** | 52 bytes (storage) | Same as unpacked |

**Hybrid storage** automatically:
- Stores in packed format (5 trits per byte)
- Unpacks lazily for computation
- Re-packs after operations

## Comparison with Competitors

| Metric | Trinity | trit-vsa (Rust) | Speedup |
|--------|---------|-----------------|---------|
| Dot product | 8.9 B/s | 50 M/s | **178x** |
| Bundle | 3.4 B/s | 30 M/s | **113x** |
| Bind | 425 M/s | 40 M/s | **10x** |
| Memory | 256x savings | bitsliced | Similar |
| GPU | No | CubeCL | trit-vsa |

## Running Benchmarks

```bash
# Build and run benchmarks
zig build bench

# Or run directly
zig build-exe src/vsa.zig -O ReleaseFast && ./vsa
```

## Test Environment

- CPU: (varies by system)
- Zig: 0.11.0+
- Optimization: ReleaseFast

## Scaling

Performance scales linearly with vector dimension:

| Dimension | Dot Product |
|-----------|-------------|
| 256 | 28 ns |
| 512 | ~56 ns |
| 1024 | ~112 ns |
| 4096 | ~448 ns |
