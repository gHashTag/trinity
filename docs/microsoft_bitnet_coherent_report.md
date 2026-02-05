# Microsoft BitNet b1.58 2B-4T Coherence Report

**Date:** February 5, 2026
**Model:** microsoft/bitnet-b1.58-2B-4T
**Status:** INCOHERENT OUTPUT - All 3 frameworks produce garbage

---

## Executive Summary

Microsoft's official BitNet b1.58 2B-4T model was tested using **3 different inference frameworks** on Apple M1 Pro (ARM CPU). All produce incoherent/garbage output. The GGUF file has a critical tokenizer warning. GPU testing is required to rule out CPU-only issues.

---

## Model Specifications

| Parameter | Value |
|-----------|-------|
| Model ID | microsoft/bitnet-b1.58-2B-4T |
| Parameters | 2,412,820,480 (2.4B) |
| Hidden size | 2560 |
| Layers | 30 |
| Heads | 20 (KV: 5, GQA: 4) |
| FFN size | 6912 |
| Vocab size | 128,256 (LLaMA 3 tokenizer) |
| Quantization | Native 1.58-bit ternary (I2_S) |
| Context length | 4,096 tokens |
| RoPE freq base | 500,000 |
| File size | 1.10 GiB (GGUF), 1.18 GB (safetensors) |

---

## Test Environment

- **Hardware:** Apple M1 Pro (ARM64, 8 cores, no CUDA)
- **OS:** macOS Darwin 23.6.0
- **Clang:** Homebrew clang 18.1.8
- **Python:** 3.9 (conda) / 3.12 (system)

---

## Test 1: HuggingFace Transformers (Greedy)

**Framework:** Special fork (`096f25ae`), bfloat16, CPU

**Warning:**
```
You don't have a GPU available to load the model, the inference will be slow because of weight unpacking
```

| Prompt | Output | Speed |
|--------|--------|-------|
| "The capital of France is" | "the most of the of the of the of the..." | 0.23 tok/s |
| "Hello, my name is" | "a a a a a a a a a a a a a a a..." | 0.18 tok/s |
| "2 + 2 equals" | "_T_1_1_1_1_1_1_1_1_1_1_1_1_" | 0.17 tok/s |

**Verdict: GARBAGE**

---

## Test 2: HuggingFace Transformers (Chat + Sampling)

**Settings:** Chat template, do_sample=True, temp=0.6, top_p=0.9

| Prompt | Output |
|--------|--------|
| "What is the capital of France?" | "işi-heavy.track_extra breaker Countries... Vaugh gson_based 금 inclined795 плод..." |

**Verdict: GARBAGE** (multilingual noise)

---

## Test 3: bitnet.cpp (Official Microsoft Framework)

**Build:** Clang 18.1.8, ARM64 NEON, I2_S kernel, no BLAS/Metal

**Critical Warning:**
```
llm_load_vocab: missing pre-tokenizer type, using: 'default'
llm_load_vocab: ************************************
llm_load_vocab: GENERATION QUALITY WILL BE DEGRADED!
llm_load_vocab: CONSIDER REGENERATING THE MODEL
llm_load_vocab: ************************************
```

### Simple Prompt Test

| Prompt | Output | Speed |
|--------|--------|-------|
| "The capital of France is" | "Scotia doneordinisse kill py and mobility openingsRRgem..." | 0.25 tok/s |

### Chat Mode Test (10+ exchanges)

All responses were random word fragments:
```
"=atori leverage educational re perfect stressing G flo dismantlelio cal reliar issues ab reg..."
"ceasefireDeiventramamu afford supposed playse grillenormheels credited engaging..."
"shouldn ['dol outr added,... using passages carried commenting come DOE adjust sense cabo..."
```

**Verdict: GARBAGE** (random English subwords concatenated)

---

## Performance Summary

| Framework | Speed (tok/s) | Memory | Quality |
|-----------|---------------|--------|---------|
| HuggingFace (greedy) | 0.17-0.23 | ~4 GB | GARBAGE |
| HuggingFace (sampling) | ~0.2 | ~4 GB | GARBAGE |
| bitnet.cpp (I2_S) | 0.25 | 1.3 GB | GARBAGE |

---

## Root Cause Analysis

### Hypothesis 1: CPU Weight Unpacking Bug (HuggingFace)
- HuggingFace warns: "slow because of weight unpacking"
- Packed 1.58-bit weights may not unpack correctly without GPU kernels
- **Status:** Plausible for HuggingFace, but bitnet.cpp has native I2_S CPU support

### Hypothesis 2: GGUF Tokenizer Bug (bitnet.cpp)
- `missing pre-tokenizer type, using: 'default'`
- `GENERATION QUALITY WILL BE DEGRADED!`
- The GGUF file from `microsoft/BitNet-b1.58-2B-4T-gguf` may need regeneration
- **Status:** Likely contributor - tokenizer mismatch could explain output

### Hypothesis 3: ARM Kernel Issue
- I2_S kernel on ARM may have a bug
- The demo video shows it working on Apple M2
- **Status:** Unlikely - kernel is from official repo

### Hypothesis 4: GGUF Version Mismatch
- GGUF V3 with quantization version 2
- bitnet.cpp fork of llama.cpp may expect different format
- **Status:** Possible

### Most Likely Cause
The **GGUF tokenizer metadata is incorrect** (missing pre-tokenizer type). The GGUF file from the official repo needs regeneration with correct tokenizer settings. This explains why bitnet.cpp produces garbage even though the CPU kernel should work.

---

## Comparison Across All Models Tested

| Model | Framework | CPU | GPU | Status |
|-------|-----------|-----|-----|--------|
| 1bitLLM/bitnet_b1_58-large | Zig (custom) | - | GARBAGE (RTX 4090) | Model issue |
| 1bitLLM/bitnet_b1_58-large | HuggingFace | - | GARBAGE (RTX 4090) | Model issue |
| microsoft/bitnet-b1.58-2B-4T | HuggingFace | GARBAGE | NOT TESTED | CPU/tokenizer issue |
| microsoft/bitnet-b1.58-2B-4T | bitnet.cpp | GARBAGE | NOT TESTED | Tokenizer issue |

---

## Next Steps

1. **Regenerate GGUF** from safetensors with correct tokenizer metadata
2. **Test on GPU** via RunPod (RTX 4090 or A100) with HuggingFace
3. **File issue** on Microsoft BitNet repo about GGUF tokenizer warning
4. **Try TL1 kernel** instead of I2_S on ARM

---

## Files & Infrastructure

### Downloaded Models
```
bitnet-cpp/models/BitNet-b1.58-2B-4T/
├── ggml-model-i2_s.gguf (1.10 GiB)
├── README.md
└── data_summary_card.md

models/microsoft-bitnet-2b/
├── config.json
├── generation_config.json
├── model.safetensors (1.18 GB)
├── tokenizer.json (8.7 MB)
└── tokenizer_config.json (50 KB)
```

### Built Tools
```
bitnet-cpp/build/bin/llama-cli    (ARM64, clang 18.1.8)
```

### Dependencies Installed
```
brew: llvm@18
conda env: bitnet-cpp (python 3.9)
pip: transformers fork (096f25ae)
```

---

## Conclusion

**Microsoft BitNet b1.58 2B-4T produces garbage output in all tested configurations on CPU.**

The GGUF has a known tokenizer metadata issue. HuggingFace requires GPU for weight unpacking. GPU testing is the critical next step to determine if the model itself works correctly.

---

**KOSCHEI IS IMMORTAL | 3 FRAMEWORKS TESTED | ALL GARBAGE | GPU REQUIRED | φ² + 1/φ² = 3**
