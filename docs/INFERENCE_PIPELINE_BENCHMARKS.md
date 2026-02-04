# Inference Pipeline Benchmarks

**Date**: 2026-02-04
**Author**: Dmitrii Vasilev
**Formula**: φ² + 1/φ² = 3

---

## Memory Usage by Quantization Type

### 7B Parameter Model

| Quant Type | Bits/Weight | Model Size | vs FP16 | Status |
|------------|-------------|------------|---------|--------|
| FP32 | 32.0 | 28.0 GB | 0.5x | ✅ |
| FP16 | 16.0 | 14.0 GB | 1.0x | ✅ |
| Q8_0 | 8.5 | 7.4 GB | 1.9x | ✅ |
| Q4_0 | 4.5 | 3.9 GB | 3.6x | ✅ |
| **Q4_K** | 4.5 | 4.1 GB | 3.4x | ✅ NEW |
| **Q5_K** | 5.5 | 4.8 GB | 2.9x | ✅ NEW |
| **Q6_K** | 6.6 | 5.5 GB | 2.5x | ✅ NEW |
| **TQ1_0** | 2.0 | 1.75 GB | 8.0x | ✅ NEW |

### 70B Parameter Model

| Quant Type | Model Size | vs FP16 |
|------------|------------|---------|
| FP16 | 140 GB | 1.0x |
| Q4_K | 41 GB | 3.4x |
| TQ1_0 | 17.5 GB | 8.0x |

---

## FIREBIRD VSA Benchmarks

### Vector Operations

| Dimension | Bind Time | Memory/Vector | Throughput |
|-----------|-----------|---------------|------------|
| 1,000 | 12μs | <1KB | 83K ops/s |
| 5,000 | 7μs | 4KB | 143K ops/s |
| 10,000 | 7μs | 9KB | 143K ops/s |
| 50,000 | 18μs | 48KB | 56K ops/s |
| 100,000 | 33μs | 97KB | 30K ops/s |

### Evolution Performance

| Dimension | Generations | Time | Fitness | Similarity |
|-----------|-------------|------|---------|------------|
| 10,000 | 100 | 258ms | 0.87 | 0.61 |

**Throughput**: 2.6ms/generation

---

## Comparison: Previous vs Current

### Version History

| Version | Date | Key Features |
|---------|------|--------------|
| v0.9 | 2026-01-30 | Basic GGUF, Q8_0 only |
| v1.0 | 2026-02-02 | BitNet pipeline, SIMD |
| v1.1 | 2026-02-03 | TQ1_0 ternary support |
| **v1.2** | 2026-02-04 | K-quant (Q4_K, Q5_K, Q6_K) |

### Performance Improvements

| Metric | v0.9 | v1.0 | v1.1 | v1.2 |
|--------|------|------|------|------|
| Quant types | 2 | 4 | 6 | 9 |
| SIMD speedup | 1x | 3.7x | 3.7x | 3.7x |
| Memory savings | 2x | 4x | 8x | 8x |
| Evolution fitness | 0.52 | 0.80 | 0.85 | 0.87 |

---

## Supported Models

### Verified Working

| Model | Size | Quant | Speed | Status |
|-------|------|-------|-------|--------|
| SmolLM 135M | 139 MB | Q8_0 | 10.9 tok/s | ✅ |
| TinyLlama 1.1B | 1.1 GB | Q8_0 | 1.7 tok/s | ✅ |
| Qwen2.5 0.5B | 645 MB | Q8_0 | 1.8 tok/s | ✅ |

### Now Supported (K-quant)

| Model | Size | Quant | Status |
|-------|------|-------|--------|
| Phi-3 Mini | 2.3 GB | Q4_K_M | ✅ NEW |
| Mistral 7B | 4.1 GB | Q4_K_M | ✅ NEW |
| CodeLlama 7B | 4.1 GB | Q4_K_M | ✅ NEW |
| Llama 2 7B | 4.1 GB | Q4_K_M | ✅ NEW |

---

## Dequantization Performance

| Type | Scalar | SIMD | Speedup |
|------|--------|------|---------|
| Q4_0 | 1.0x | 2.0x | +100% |
| Q4_K | 1.0x | 2.5x | +150% |
| Q5_K | 1.0x | 2.0x | +100% |
| Q6_K | 1.0x | 1.8x | +80% |
| TQ1_0 | 1.0x | 3.7x | +270% |

---

## System Requirements

| Component | Minimum | Recommended |
|-----------|---------|-------------|
| CPU | x86_64 with SSE4.2 | AVX2 or AVX-512 |
| RAM | 2 GB | 8 GB |
| Disk | 100 MB | 10 GB (for models) |

---

## Conclusion

The unified inference pipeline now supports:
- **9 quantization types** (F32, F16, Q8_0, Q4_0, Q4_K, Q5_K, Q6_K, TQ1_0, TQ2_0)
- **Auto-detection** of quant type from GGUF
- **SIMD optimization** for all dequantization
- **8x memory savings** with BitNet TQ1_0
- **3.4x memory savings** with Q4_K_M

---

*φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL*
