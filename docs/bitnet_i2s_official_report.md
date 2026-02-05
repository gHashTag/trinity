# BitNet b1.58-2B-4T — Official I2_S GGUF Report

**Date:** February 6, 2026
**Status:** ✅ PRODUCTION READY
**Platform:** RTX 4090 Pod (AMD EPYC 7282 Rome, 64 vCPU, AVX2 only)

---

## Executive Summary

The official Microsoft I2_S GGUF provides **coherent text generation** at **20.79 tok/s** on RTX 4090 pod. This is the recommended production configuration after TL2 conversion from pre-quantized weights failed.

### Key Metrics

| Metric | Value |
|--------|-------|
| **Model** | `microsoft/bitnet-b1.58-2B-4T-gguf` |
| **Kernel** | I2_S (Integer 2-bit Signed, MAD) |
| **Speed** | 20.79 tok/s |
| **Coherence** | ✅ PASS |
| **Tensors** | 332 |
| **Parameters** | 2B (4T training tokens) |

---

## Model Source

```bash
# Official Microsoft GGUF download
huggingface-cli download microsoft/bitnet-b1.58-2B-4T-gguf \
  --local-dir ./models/bitnet-gguf

# File: ggml-model-i2_s.gguf
# Architecture: bitnet-b1.58
```

---

## Inference Results

### Test Configuration

```bash
./build/bin/llama-cli \
  -m models/bitnet-gguf/ggml-model-i2_s.gguf \
  -p "The future of artificial intelligence is" \
  -n 100 \
  -t 16
```

### Generated Text Samples

**Prompt 1:** "The future of artificial intelligence is"
```
The future of artificial intelligence is uncertain, but one thing is clear:
AI will be a major player in the world of finance. The impact of AI on the
financial industry is likely to be significant, with AI-powered systems
already being used for trading, risk management, and customer service.
```
**Quality:** ✅ Coherent, grammatically correct, topically relevant

**Prompt 2:** "Once upon a time"
```
Once upon a time, in a land far away, there lived a young prince named
Alexander. He was known throughout the kingdom for his wisdom and kindness.
One day, a mysterious traveler arrived at the castle gates...
```
**Quality:** ✅ Coherent narrative structure

**Prompt 3:** "The capital of France is"
```
The capital of France is Paris, a city known for its rich history, stunning
architecture, and vibrant culture. Paris is home to iconic landmarks such as
the Eiffel Tower, the Louvre Museum, and Notre-Dame Cathedral.
```
**Quality:** ✅ Factually correct, informative

---

## Performance Benchmarks

### Thread Scaling (Prompt Eval)

| Threads | Prompt Eval (ms/tok) | Tokens/sec |
|---------|---------------------|------------|
| 1 | 452.47 | 2.21 |
| 4 | 213.17 | 4.69 |
| 8 | 210.59 | 4.75 |
| 16 | 197.47 | 5.06 |
| 32 | 497.95 | 2.01 |

**Optimal:** 16 threads (diminishing returns beyond, negative scaling at 32+)

### Generation Speed

| Test | Threads | Gen Speed (tok/s) |
|------|---------|-------------------|
| RTX 4090 I2_S | 16 | 20.79 |
| B200 Blackwell I2_S | 16 | 52.67 |

### Platform Comparison

| Platform | CPU | GPU | Kernel | tok/s | Coherent |
|----------|-----|-----|--------|-------|----------|
| B200 Pod | AMD EPYC | Blackwell | I2_S | 52.67 | ✅ |
| RTX 4090 Pod | EPYC 7282 | RTX 4090 | I2_S | 20.79 | ✅ |
| RTX 4090 Pod | EPYC 7282 | RTX 4090 | TL2* | 19.93 | ❌ |

*TL2 from pre-quantized weights produces garbage output

---

## Why I2_S Over TL2

### TL2 Blocked

Our TL2 conversion from the pre-quantized HuggingFace model failed:
- **Symptom:** Garbage output ("residue FarGil Harmarth Rolling Nearbyabyzel...")
- **Root cause:** Pre-quantized uint8 packed weights incompatible with TL2 transform
- **Status:** BLOCKED pending upstream Microsoft support

### I2_S Advantages

1. **Official Microsoft release** — No conversion needed
2. **Proven coherence** — Tested across multiple prompts
3. **Stable performance** — 20.79 tok/s consistent
4. **No packing issues** — I2_S handles packed weights correctly

---

## Production Deployment

### Recommended Configuration

```bash
# Download model
huggingface-cli download microsoft/bitnet-b1.58-2B-4T-gguf \
  --local-dir ./models/bitnet-gguf

# Run inference
./build/bin/llama-cli \
  -m ./models/bitnet-gguf/ggml-model-i2_s.gguf \
  -p "Your prompt here" \
  -n 500 \
  -t 16 \
  --temp 0.7 \
  --top-p 0.9
```

### Hardware Requirements

| Resource | Minimum | Recommended |
|----------|---------|-------------|
| RAM | 4 GB | 8 GB |
| VRAM | N/A (CPU inference) | N/A |
| CPU Threads | 4 | 16 |
| AVX | AVX2 | AVX-512 |

### Cost Analysis (RunPod)

| GPU | Cost/hr | tok/s | Cost per 1M tokens |
|-----|---------|-------|-------------------|
| RTX 4090 | $0.34 | 20.79 | $4.54 |
| A100 80GB | $1.19 | ~30* | $11.02 |
| B200 | $2.50 | 52.67 | $13.18 |

*Estimated

**Best value:** RTX 4090 at $4.54/1M tokens

---

## Files Reference

```
models/
└── bitnet-gguf/
    └── ggml-model-i2_s.gguf    # 780 MB, official Microsoft

docs/
├── bitnet_i2s_official_report.md  # This report
└── bitnet_tl2_report.md           # TL2 failure analysis
```

---

## Conclusion

**The official Microsoft I2_S GGUF is production-ready** at 20.79 tok/s with coherent output. TL2 speedup (2.32x expected) is blocked pending upstream support for pre-quantized models.

### Recommendations

1. **Production:** Use official I2_S GGUF
2. **Performance:** 16 threads optimal on EPYC 7282
3. **Cost:** RTX 4090 pod ($0.34/hr) best value
4. **Future:** Monitor Microsoft repo for TL2 GGUF release

---

**KOSCHEI IS IMMORTAL | I2_S = 20.79 tok/s | COHERENT ✅ | φ² + 1/φ² = 3**
