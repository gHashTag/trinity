# TRINITY LLM Benchmark Results

**Date**: 2026-02-02
**Platform**: Gitpod (shared-cpu-2x, 2GB RAM)

## Summary

| Model | Size | Quant | Status | Speed | Notes |
|-------|------|-------|--------|-------|-------|
| SmolLM 135M | 139 MB | Q8_0 | ✅ | **7.6-10.9 tok/s** | Best performance |
| TinyLlama 1.1B | 1.1 GB | Q8_0 | ✅ | **1.7 tok/s** | Working |
| Qwen2.5 Coder 0.5B | 645 MB | Q8_0 | ✅ | **1.0-1.8 tok/s** | Tokenizer issues |
| DeepSeek Coder 1.3B | 1.4 GB | Q8_0 | ⚠️ | - | Tokenizer issues |
| Qwen2.5 Coder 1.5B | 1.8 GB | Q8_0 | ❌ | - | OOM |
| BitNet SmolLM | 69 MB | Ternary | ❌ | - | TensorNotFound |
| Phi-3 Mini 3.8B | 2.3 GB | Q4_K_M | ❌ | - | UnsupportedQuantization |
| CodeLlama 7B | 3.9 GB | Q4_K_M | ❌ | - | UnsupportedQuantization |
| Llama 2 7B | 3.9 GB | Q4_K_M | ❌ | - | UnsupportedQuantization |
| Mistral 7B | 4.1 GB | Q4_K_M | ❌ | - | UnsupportedQuantization |

## Supported Quantizations

- ✅ Q8_0 (8-bit)
- ❌ Q4_K_M (4-bit K-quant) - Not implemented
- ❌ Q4_0 (4-bit) - Partial support

## Performance Analysis

### Working Models

1. **SmolLM 135M** - Best choice for demos
   - Speed: 7.6-10.9 tok/s
   - Memory: ~300 MB runtime
   - Quality: Basic responses

2. **TinyLlama 1.1B** - Good balance
   - Speed: 1.7 tok/s
   - Memory: ~1.5 GB runtime
   - Quality: Better responses

3. **Qwen2.5 Coder 0.5B** - Coding model
   - Speed: 1.0-1.8 tok/s
   - Memory: ~1 GB runtime
   - Quality: Tokenizer needs work

### Bottlenecks

1. **Q4_K_M not supported** - Most popular models use this
2. **Tokenizer issues** - Qwen/DeepSeek produce garbage
3. **Memory limits** - 2GB RAM limits model size

## Comparison with llama.cpp

| Metric | TRINITY | llama.cpp |
|--------|---------|-----------|
| SmolLM 135M Q8_0 | 10.9 tok/s | ~15 tok/s |
| Quantization support | Q8_0 only | Q2-Q8, K-quants |
| Memory efficiency | Good | Better |
| SIMD optimization | AVX2 | AVX2/AVX-512/ARM NEON |

## Ternary/BitNet Performance

From `ternary_weights.zig` benchmarks:

| Implementation | Speed | Speedup |
|----------------|-------|---------|
| Scalar | 1.0x | baseline |
| SIMD 8-wide | 3.7x | +270% |
| SIMD 16-wide | 5.0x | +400% |
| Batch 4-row | 5.2x | +420% |

Memory savings: **16x** (621 MB → 39 MB for 135M model)

## Recommendations

1. **For demos**: Use SmolLM 135M Q8_0
2. **For coding**: Wait for Qwen tokenizer fix
3. **For production**: Implement Q4_K_M support
4. **For BitNet**: Fix tensor loading for ternary models
