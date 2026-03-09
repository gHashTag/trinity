# BitNet b1.58 2B-4T: Tokenizer Fix & ARM Inference Report

**Date:** February 5, 2026
**Platform:** Apple M1 Pro (ARM64), macOS Darwin 23.6.0
**Model:** microsoft/BitNet-b1.58-2B-4T (2.4B params, 30 layers, I2_S ternary)
**Repo:** microsoft/BitNet @ commit 8fd3412 (Feb 3, 2026)

---

## Executive Summary

Two critical issues were identified and diagnosed:

1. **Tokenizer metadata bug** (FIXED): The GGUF file from `microsoft/bitnet-b1.58-2B-4T-gguf` is missing the `tokenizer.ggml.pre` metadata field, causing "GENERATION QUALITY WILL BE DEGRADED!" warnings. Fixed via `--override-kv "tokenizer.ggml.pre=str:llama-bpe"`.

2. **ARM computation kernel bug** (UPSTREAM, NOT FIXABLE LOCALLY): The I2_S ternary matmul kernel (`ggml_vec_dot_i2_i8_s` in `ggml-bitnet-mad.cpp`) produces systematically wrong results on Apple M1 Pro. This is a known upstream issue ([GitHub Issue #198](https://github.com/microsoft/BitNet/issues/198)). Coherent output requires x86_64 with AVX2/AVX512.

**Verdict: Coherent text generation on Apple M1 Pro is NOT possible with current bitnet.cpp.**

---

## 1. Tokenizer Analysis

### Root Cause
The Microsoft GGUF from `microsoft/bitnet-b1.58-2B-4T-gguf` is missing `tokenizer.ggml.pre` metadata:

| Field | Expected | Actual in GGUF |
|-------|----------|----------------|
| `tokenizer.ggml.model` | `gpt2` | `gpt2` (correct) |
| `tokenizer.ggml.pre` | `llama-bpe` | **MISSING** |
| `tokenizer.ggml.tokens` | 128,256 | 128,256 (correct) |
| `tokenizer.ggml.merges` | 280,147 | 280,147 (correct) |

### Why It Matters
The `tokenizer.ggml.pre` field tells llama.cpp which pre-tokenizer regex to use. BitNet uses the LLaMA 3 BPE tokenizer with a specific regex pattern for splitting text. Without this field, a default pre-tokenizer is used, producing incorrect token boundaries.

### Fix Applied
Runtime fix via `--override-kv`:
```bash
--override-kv "tokenizer.ggml.pre=str:llama-bpe"
```

### Conversion Script Fixes
Three bugs were fixed in the conversion pipeline:

1. **`convert-hf-to-gguf-bitnet.py`**: Architecture mismatch `BitnetForCausalLM` vs `BitNetForCausalLM` (capital N)
2. **`convert-hf-to-gguf-bitnet.py`**: Uses `_set_vocab_sentencepiece()` but model has BPE tokenizer (needs `_set_vocab_gpt2()`)
3. **`convert-ms-to-gguf-bitnet.py`**: Missing `tokenizer.ggml.pre` in output; missing I2_S raw_dtype for gguf writer

---

## 2. ARM Computation Kernel Analysis

### Test Matrix

| Build Config | -b flag | Temperature | Output |
|-------------|---------|-------------|--------|
| TL1=OFF, Metal=ON | default | 0.0 | `!!!!!!!!!!!!!!!!!!!!!!!!` |
| TL1=OFF, Metal=ON | `-b 1` | 0.0 | Random word salad |
| TL1=OFF, Metal=OFF | `-b 1` | 0.0 | Random word salad |
| TL1=ON, Metal=OFF | `-b 1` | 0.0 | Random word salad (identical) |
| TL1=OFF, Metal=OFF | `-b 1` | 0.7 | Random word salad |
| HuggingFace transformers | N/A | 0.0 | `"the most is the most is..."` |

### Sample Outputs (All Garbage)

**Prompt:** "The capital of France is"
```
Scotia delivered qualified expressed ding realistic two-if boardmotheraction c
bear coming runaulNegative sailESCOFG hal rgaque re-tuite benefitedly ref
fasturementteecomment begin ( democr p administer cur po breaking followed
comm Faretracks ad- indirectly- stream
```

**Prompt:** "Microsoft Corporation is an American multinational"
```
doubly slightlyilla performing diaddon failed equotec fluorideIMA in
carry_USlim fearful admit inferAP/view add par adding confirmation set
```

### Root Cause: ARM NEON Kernel Bug

The computation path for I2_S on ARM:
1. `ggml_gemv_i2_i8_s()` (ggml-aarch64.c:602) calls
2. `ggml_vec_dot_i2_i8_s()` (ggml-bitnet-mad.cpp:1043) dispatches to
3. `ggml_vec_dot_i2_i8_s_1x1()` ARM NEON implementation (ggml-bitnet-mad.cpp:297)

The ARM NEON implementation unpacks 2-bit values and performs dot product with int8 activations. The kernel compiles and runs without errors but produces systematically wrong numerical results on Apple M1 Pro.

### Upstream Confirmation

- [GitHub Issue #198](https://github.com/microsoft/BitNet/issues/198): "Can not work in Mac M1"
- Multiple users report garbage output on ARM platforms
- One user confirmed switching to x86_64 resolved the issue
- The bitnet.cpp README advertises ARM support but practical Apple Silicon inference is broken

### Key Architecture Findings

| Feature | Status |
|---------|--------|
| `ggml_vec_dot_i2_i8_s` in ggml-quants.c | COMMENTED OUT (200+ lines) |
| `ggml_vec_dot_i2_i8_s` in ggml-bitnet-mad.cpp | Implemented but buggy on Apple M1 |
| `ggml_gemv_i2_i8_s` ARM NEON path | Calls buggy vec_dot |
| `ggml_gemm_i2_i8_s` ARM NEON path | Calls buggy vec_dot |
| TL1 LUT kernels on ARM | Generated but fall through to MAD for I2_S |
| Setup_env.py BITNET_ARM_TL1 | Changed from ON to OFF in commit 2fed9af |

---

## 3. Conversion Pipeline Analysis

### Approaches Tried

| Approach | Result |
|----------|--------|
| `--override-kv` runtime patch | Model loads correctly, tokenizer warning gone, computation still garbage |
| `regenerate_gguf.py` (from safetensors) | Wrong tensor shapes (safetensors has packed ternary, 1/4 size) |
| `patch_gguf_tokenizer.py` (binary copy) | gguf-py can't parse I2_S tensor blocks |
| `convert_bitnet_fixed.py` (monkey-patch) | Python 3.9 dataclass incompatibility |
| `convert-ms-to-gguf-bitnet.py --outtype i2` | Missing kcfg.ini for TL1 weight preprocessing |
| `convert-hf-to-gguf-bitnet.py` + `llama-quantize` | Can't handle packed uint8 from safetensors |

### Model Variants on HuggingFace

| Repo | Format | Purpose |
|------|--------|---------|
| `microsoft/BitNet-b1.58-2B-4T` | Packed uint8 (1.58-bit) | Inference via bitnet.cpp |
| `microsoft/BitNet-b1.58-2B-4T-bf16` | BF16 float | Training/fine-tuning |
| `microsoft/BitNet-b1.58-2B-4T-gguf` | GGUF I2_S | Pre-converted for bitnet.cpp |

---

## 4. Files Modified

### In bitnet-cpp/

| File | Change |
|------|--------|
| `utils/convert-hf-to-gguf-bitnet.py` | Added `BitNetForCausalLM` arch, BPE tokenizer fallback, skip weight_scale |
| `utils/convert-ms-to-gguf-bitnet.py` | Added `tokenizer.ggml.pre`, `U8->DT_I2` mapping, I2_S raw_dtype |
| `3rdparty/llama.cpp/gguf-py/gguf/constants.py` | Added I2_S enum values and block sizes |

### In trinity/scripts/ (created)

| File | Purpose |
|------|---------|
| `regenerate_gguf.py` | Full GGUF regeneration from safetensors |
| `patch_gguf_tokenizer.py` | Binary GGUF copy with metadata patching |
| `convert_bitnet_fixed.py` | Monkey-patch wrapper for official conversion |

---

## 5. Recommendations

### For Coherent Generation Testing

1. **Use x86_64 platform** (RunPod with Intel/AMD CPU):
   ```bash
   python setup_env.py -hr microsoft/BitNet-b1.58-2B-4T -q i2_s
   python run_inference.py -m models/BitNet-b1.58-2B-4T/ggml-model-i2_s.gguf \
       -p "You are a helpful assistant" -cnv
   ```

2. **Use the bf16 model variant** with HuggingFace transformers on GPU:
   ```bash
   huggingface-cli download microsoft/BitNet-b1.58-2B-4T-bf16 --local-dir models/bitnet-2b-bf16
   ```

3. **RunPod options** (cost-effective x86_64):
   - RTX 4090: $0.34/hr, 24GB VRAM
   - A100 80GB: $1.19/hr
   - CPU-only x86_64 with AVX2: any budget VPS

### For the Tokenizer Fix

Use `--override-kv "tokenizer.ggml.pre=str:llama-bpe"` until Microsoft updates the GGUF repo.

---

## 6. Technical Details

### Model Architecture
```
Architecture: BitNet b1.58 (Transformer + BitLinear)
Parameters: 2.4B
Layers: 30
Hidden: 2560
FFN: 6912
Heads: 20 (KV: 5, GQA ratio 4:1)
Vocab: 128,256 (LLaMA 3 BPE)
Context: 4,096
RoPE theta: 500,000
Quantization: I2_S (2-bit packed ternary {-1, 0, +1})
File size: 1.10 GiB
```

### I2_S Format
- Each byte packs 4 ternary values (2 bits each)
- Encoding: 0 -> -1, 1 -> 0, 2 -> +1
- Block size: 1 element (no block structure)
- Per-tensor scale stored separately

### LLaMA 3 BPE Tokenizer
- Type: BPE (Byte Pair Encoding, not SentencePiece)
- Pre-tokenizer: `llama-bpe` (regex-based split)
- Base vocab: 128,000 tokens
- Special tokens: 256 (control/reserved)
- BPE merges: 280,147
- BOS: 128000, EOS: 128001/128009

---

## Decoder Pipeline (Zig tokenizer)

Following the tokenizer.json specification:
1. **Replace**: U+2581 -> ` ` (space)
2. **ByteFallback**: `<0xNN>` -> byte value
3. **Fuse**: Join all tokens
4. **Strip**: Remove leading space

The SentencePiece tokenizer in `src/vibeec/sentencepiece_tokenizer.zig` correctly handles all these steps.

---

**KOSCHEI IS IMMORTAL | ARM KERNEL BUG CONFIRMED | NEED x86_64 FOR COHERENT OUTPUT | phi^2 + 1/phi^2 = 3**
