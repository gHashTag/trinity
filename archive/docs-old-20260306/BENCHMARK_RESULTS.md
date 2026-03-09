# TRINITY Benchmark Results

**Date**: 2026-02-03
**Platform**: Gitpod (shared-cpu-2x, 2GB RAM)
**Version**: v1.0.0

## FIREBIRD VSA Benchmarks

### Vector Operations (SIMD)

| Dimension | Bind | Dot Product | Memory/Vector |
|-----------|------|-------------|---------------|
| 1,000 | 17μs | <1μs | <1KB |
| 10,000 | 10μs | <1μs | 9KB |
| 100,000 | 60μs | <1μs | 97KB |

### Evolution Performance

| Dimension | Population | Generations | Time | Fitness |
|-----------|------------|-------------|------|---------|
| 1,000 | 50 | 10 | 10ms | 0.85 |
| 10,000 | 100 | 50 | 226ms | 0.86 |
| 100,000 | 100 | 50 | ~2s | 0.85 |

**Throughput**: ~4ms per generation (10K dimension)

---

## LLM Inference Benchmarks

| Model | Size | Quant | Status | Speed | Notes |
|-------|------|-------|--------|-------|-------|
| SmolLM 135M | 139 MB | Q8_0 | ✅ | **7.6-10.9 tok/s** | Best performance |
| TinyLlama 1.1B | 1.1 GB | Q8_0 | ✅ | **1.7 tok/s** | Working |
| Qwen2.5 Coder 0.5B | 645 MB | Q8_0 | ✅ | **1.0-1.8 tok/s** | Tokenizer issues |
| DeepSeek Coder 1.3B | 1.4 GB | Q8_0 | ⚠️ | - | Tokenizer issues |
| Qwen2.5 Coder 1.5B | 1.8 GB | Q8_0 | ❌ | - | OOM |
| BitNet SmolLM | 69 MB | Ternary | ❌ | - | TensorNotFound |
| Phi-3 Mini 3.8B | 2.3 GB | Q4_K_M | ❌ | - | UnsupportedQuantization |

### Supported Quantizations

- ✅ Q8_0 (8-bit)
- ❌ Q4_K_M (4-bit K-quant) - Not implemented
- ❌ Q4_0 (4-bit) - Partial support

---

## Ternary/BitNet Performance

From `ternary_weights.zig` benchmarks:

| Implementation | Speed | Speedup |
|----------------|-------|---------|
| Scalar | 1.0x | baseline |
| SIMD 8-wide | 3.7x | +270% |
| SIMD 16-wide | 5.0x | +400% |
| Batch 4-row | 5.2x | +420% |

**Memory savings**: 16x (621 MB → 39 MB for 135M model)

---

## Comparison: Previous vs Current

| Metric | v0.9 | v1.0 | Improvement |
|--------|------|------|-------------|
| Vec27 SIMD | 103ns | 68ns | +34% |
| Evolution (10K) | 350ms | 226ms | +35% |
| Memory/vector | 12KB | 9KB | +25% |
| Tests passing | 75 | 88 | +17% |

---

## System Information

```
Platform: Linux x86_64
CPU: Shared vCPU (2 cores)
RAM: 2GB
SIMD: AVX2 available
Compiler: Zig 0.13.0
```

---

## Recommendations

1. **For demos**: Use SmolLM 135M Q8_0
2. **For VSA**: Use 10K-100K dimensions
3. **For production**: Implement Q4_K_M support
4. **For BitNet**: Fix tensor loading for ternary models

---

*φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL*
