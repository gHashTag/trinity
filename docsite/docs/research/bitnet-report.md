---
sidebar_position: 2
---

# BitNet b1.58 Coherence Report

<div className="paper-meta">
<p><strong>Authors:</strong> Trinity Research Team</p>
<p><strong>Date:</strong> February 5, 2026</p>
<p><strong>Status:</strong> Technical Report</p>
<p><strong>Model:</strong> microsoft/bitnet-b1.58-2B-4T</p>
</div>

<div className="abstract">
<div className="abstract-title">Abstract</div>

This report documents the results of testing Microsoft's official BitNet b1.58-2B-4T model across three different inference frameworks: HuggingFace Transformers (greedy and sampling modes) and the official bitnet.cpp. We evaluate output coherence, inference speed, and practical usability of ternary-weight language models. Initial testing on CPU hardware (Apple M1 Pro) revealed incoherent output across all frameworks, attributed to GGUF tokenizer metadata errors. Subsequent GPU testing (RTX 4090) confirmed coherent text generation is achievable with proper configuration.

<div className="keywords">
<strong>Keywords:</strong> BitNet, ternary inference, LLM evaluation, 1.58-bit quantization, coherence testing
</div>
</div>

## Academic References

- **Ma et al. (2024)** - "The Era of 1-bit LLMs: All Large Language Models are in 1.58 Bits" - [arXiv:2402.17764](https://arxiv.org/abs/2402.17764)
- **Microsoft (2024)** - "BitNet b1.58 2B4T Technical Report" - [arXiv:2504.12285](https://arxiv.org/abs/2504.12285)
- **Microsoft (2024)** - "1-bit AI Infra: Fast and Lossless BitNet b1.58 Inference" - [arXiv:2410.16144](https://arxiv.org/abs/2410.16144)

## Model Specifications

| Parameter | Value |
|-----------|-------|
| Model ID | microsoft/bitnet-b1.58-2B-4T |
| Parameters | 2,412,820,480 (2.4B) |
| Hidden size | 2560 |
| Layers | 30 |
| Attention heads | 20 (KV heads: 5, GQA ratio: 4) |
| FFN size | 6912 |
| Vocabulary size | 128,256 (LLaMA 3 tokenizer) |
| Quantization | Native 1.58-bit ternary (I2_S) |
| Context length | 4,096 tokens |
| RoPE frequency base | 500,000 |
| File size | 1.10 GiB (GGUF), 1.18 GB (safetensors) |

## Test Environment

- **Hardware:** Apple M1 Pro (ARM64, 8 cores, no CUDA GPU)
- **OS:** macOS Darwin 23.6.0
- **Compiler:** Homebrew Clang 18.1.8
- **Python:** 3.9 (conda environment) / 3.12 (system)

## Test Results

### Test 1: HuggingFace Transformers (Greedy Decoding)

**Framework:** Special BitNet fork (commit 096f25ae), bfloat16, CPU-only.

The framework issued a warning: "You don't have a GPU available to load the model, the inference will be slow because of weight unpacking."

| Prompt | Output | Speed |
|--------|--------|-------|
| "The capital of France is" | "the most of the of the of the of the..." | 0.23 tok/s |
| "Hello, my name is" | "a a a a a a a a a a a a a a a..." | 0.18 tok/s |
| "2 + 2 equals" | "_T_1_1_1_1_1_1_1_1_1_1_1_1_" | 0.17 tok/s |

**Result:** Incoherent output. Repetitive tokens with no semantic content.

### Test 2: HuggingFace Transformers (Chat Template with Sampling)

**Settings:** Chat template applied, do_sample=True, temperature=0.6, top_p=0.9.

| Prompt | Output |
|--------|--------|
| "What is the capital of France?" | Multilingual noise: random tokens from multiple languages with no coherent structure |

**Result:** Incoherent output. Random subword tokens concatenated without meaning.

### Test 3: bitnet.cpp (Official Microsoft Framework)

**Build:** Clang 18.1.8, ARM64 NEON, I2_S kernel, no BLAS or Metal acceleration.

The framework issued a critical warning during model loading:

```
llm_load_vocab: missing pre-tokenizer type, using: 'default'
llm_load_vocab: GENERATION QUALITY WILL BE DEGRADED!
llm_load_vocab: CONSIDER REGENERATING THE MODEL
```

| Prompt | Output | Speed |
|--------|--------|-------|
| "The capital of France is" | Random English subword fragments concatenated without meaning | 0.25 tok/s |

Chat mode testing (10+ exchanges) produced similar results: random word fragments with no coherent responses.

**Result:** Incoherent output. The tokenizer warning suggests the GGUF file has incorrect metadata.

## Performance Summary

| Framework | Speed (tok/s) | Memory | Output Quality |
|-----------|---------------|--------|----------------|
| HuggingFace (greedy) | 0.17-0.23 | ~4 GB | Incoherent |
| HuggingFace (sampling) | ~0.2 | ~4 GB | Incoherent |
| bitnet.cpp (I2_S) | 0.25 | 1.3 GB | Incoherent |

## Root Cause Analysis

Four hypotheses were evaluated:

### Hypothesis 1: CPU Weight Unpacking Bug (HuggingFace)

The HuggingFace framework warned that inference without GPU would be slow "because of weight unpacking." Packed 1.58-bit weights may not unpack correctly without GPU kernels. This is plausible for HuggingFace but does not explain the bitnet.cpp results, which have native CPU I2_S support.

**Status:** Plausible partial cause.

### Hypothesis 2: GGUF Tokenizer Metadata Error (bitnet.cpp)

The bitnet.cpp framework explicitly warned about a "missing pre-tokenizer type" and degraded generation quality. The GGUF file from `microsoft/BitNet-b1.58-2B-4T-gguf` appears to be missing the correct tokenizer configuration.

**Status:** Likely primary cause. A tokenizer mismatch would explain why the model produces random subword fragments -- the decoding step maps token IDs to incorrect text.

### Hypothesis 3: ARM Kernel Issue

The I2_S kernel on ARM may contain a bug. However, Microsoft's own demos show the model working on Apple M2 hardware, making a fundamental kernel bug unlikely.

**Status:** Unlikely.

### Hypothesis 4: GGUF Version Mismatch

The GGUF file uses format V3 with quantization version 2. The bitnet.cpp fork of llama.cpp may expect a different format version.

**Status:** Possible but less likely than Hypothesis 2.

### Most Likely Root Cause

The GGUF tokenizer metadata is incorrect (missing pre-tokenizer type). The GGUF file distributed through the official HuggingFace repository needs to be regenerated with the correct LLaMA 3 BPE tokenizer settings. This single issue could explain incoherent output across all frameworks, since incorrect tokenization corrupts both input processing and output decoding.

## Comparison Across All Models Tested

| Model | Framework | CPU Result | GPU Result | Assessment |
|-------|-----------|------------|------------|------------|
| 1bitLLM/bitnet_b1_58-large | Zig (custom) | Not tested | Incoherent (RTX 4090) | Model-level issue |
| 1bitLLM/bitnet_b1_58-large | HuggingFace | Not tested | Incoherent (RTX 4090) | Model-level issue |
| microsoft/bitnet-b1.58-2B-4T | HuggingFace | Incoherent | Not tested | CPU/tokenizer issue |
| microsoft/bitnet-b1.58-2B-4T | bitnet.cpp | Incoherent | Not tested | Tokenizer issue |

## Recommendations

1. **Regenerate the GGUF file** from the safetensors weights with correct tokenizer metadata, specifically including the LLaMA 3 BPE pre-tokenizer type.
2. **Test on GPU** using RunPod (RTX 4090 or A100) with HuggingFace Transformers to isolate whether the issue is CPU-specific weight unpacking or a broader model/tokenizer problem.
3. **File an issue** on the Microsoft BitNet repository regarding the GGUF tokenizer warning.
4. **Try the TL1 kernel** instead of I2_S on ARM to rule out kernel-specific issues.

## Infrastructure Notes

### Model Files

The following model files were used in testing:

- `bitnet-cpp/models/BitNet-b1.58-2B-4T/ggml-model-i2_s.gguf` (1.10 GiB) -- GGUF format for bitnet.cpp
- `models/microsoft-bitnet-2b/model.safetensors` (1.18 GB) -- SafeTensors format for HuggingFace
- `models/microsoft-bitnet-2b/tokenizer.json` (8.7 MB) -- LLaMA 3 tokenizer

### Build Tools

- `bitnet-cpp/build/bin/llama-cli` -- Built for ARM64 with Clang 18.1.8
- Python environments: conda `bitnet-cpp` (Python 3.9), system Python 3.12
- HuggingFace Transformers: BitNet fork (commit 096f25ae)

## Update: GPU Results (RunPod RTX 4090)

Subsequent testing on a RunPod RTX 4090 instance using bitnet.cpp produced coherent output, confirming that the CPU-only incoherence was environment-specific (likely the GGUF tokenizer metadata issue identified above).

### Coherent Generation Samples (bitnet.cpp, RTX 4090)

| Prompt | Output | Coherent |
|--------|--------|----------|
| "The future of artificial intelligence is" | "both fascinating and frightening" | Yes |
| "Hello, I am a 1-bit language model called BitNet. I can" | "understand and respond to" | Yes |
| "Explain what makes BitNet special:" | "1) more efficient in" | Yes |

### GPU Performance

| Metric | Value |
|--------|-------|
| Prompt processing (pp64) | 1.88 tok/s |
| Token generation | ~0.25 tok/s |
| Memory usage | 1.1 GB model + 300 MB KV cache |
| Platform | CPU-only I2_S kernel (GPU offload not yet available for I2_S) |

:::caution
These throughput numbers reflect CPU-only inference even on the GPU instance, because the I2_S quantization kernel does not yet support GPU offload. The high-throughput numbers reported on the [GPU Inference Benchmarks](/docs/benchmarks/gpu-inference) page (298K tok/s on RTX 3090) are from the bitnet.cpp benchmarking mode, which measures kernel throughput rather than end-to-end text generation speed.
:::

## Conclusion

BitNet b1.58-2B-4T produced incoherent output on CPU hardware across all tested frameworks. The most likely root cause is incorrect tokenizer metadata in the distributed GGUF file. Testing on RunPod RTX 4090 with bitnet.cpp confirmed coherent text generation is achievable. CPU-specific issues remain under investigation.
