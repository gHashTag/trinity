# BitNet b1.58-2B-4T — TL2 Kernel Conversion Report

**Date:** February 6, 2026
**Status:** TL2 CONVERSION BLOCKED — I2_S Baseline Confirmed
**Platform:** RTX 4090 Pod (AMD EPYC 7282 Rome, 64 vCPU, AVX2 only)

---

## Executive Summary

TL2 conversion from the pre-quantized HuggingFace model **failed to produce coherent output**. The official Microsoft I2_S GGUF works correctly at **20.79 tok/s** with coherent text generation.

### Key Findings

| Metric | I2_S (Official) | TL2 (Our Conversion) |
|--------|-----------------|---------------------|
| **Coherence** | ✅ PASS | ❌ FAIL (garbage) |
| **Speed** | 20.79 tok/s | 19.93 tok/s |
| **Model loads** | ✅ 332 tensors | ✅ 332 tensors |
| **Source** | Microsoft GGUF | HF → Unpack → TL2 |

### Root Cause

The BitNet b1.58-2B-4T model on HuggingFace is **pre-quantized with packed uint8 weights** (4 ternary values per byte). Our unpacking + TL2 transformation pipeline introduces errors in the weight encoding that break coherent generation.

---

## Work Completed

### 1. Patches Applied (7 total)

| # | File | Issue | Fix |
|---|------|-------|-----|
| 1 | `setup_env.py` | `BITNET_X86_TL2=OFF` hardcoded | Set to `ON` |
| 2 | `convert-hf-to-gguf-bitnet.py` | `BitnetForCausalLM` lowercase | Added `BitNetForCausalLM` |
| 3 | `convert-hf-to-gguf-bitnet.py` | SentencePiece hardcoded | Added BPE fallback |
| 4 | `codegen_tl2.py` | Missing 2B-4T shapes | Added `[[640, 2560], [2560, 2560], [2560, 6912], [6912, 2560]]` |
| 5 | `setup_env.py` | Wrong model name in codegen | Fixed to `BitNet-b1.58-2B-4T` |
| 6 | `convert-hf-to-gguf-bitnet.py` | `weight_scale` tensors not skipped | Added `if name.endswith("weight_scale"): continue` |
| 7 | Block sizes | BK=64 not divisible by 3 | Changed to BK=96 |

### 2. Unpacking Script Created

`/tmp/unpack_bitnet.py` — unpacks uint8 packed weights to float32 ternary:

```python
def unpack_ternary_blocked(packed, packed_shape, factor=4):
    """Unpack uint8 -> ternary float tensor.
    2-bit encoding: 00->-1, 01->0, 10->+1
    """
    M_packed, K = packed_shape
    M_logical = M_packed * factor
    data = packed.numpy().astype(np.uint8)
    result = np.zeros((M_logical, K), dtype=np.float32)

    for i in range(factor):
        bits = (data >> (i * 2)) & 0x03
        mapped = bits.astype(np.float32) - 1.0  # 0->-1, 1->0, 2->+1
        result[i * M_packed:(i + 1) * M_packed] = mapped

    return torch.from_numpy(result)
```

### 3. TL2 GGUF Generated

- **File:** `ggml-model-tl2.gguf`
- **Size:** 1.1 GB
- **Tensors:** 332 (210 TL2 + 121 F32 + 1 F16)
- **Kernel config:** BM=128,256,256,128 BK=96,96,96,96 bm=32,32,32,32

### 4. Inference Test Results

**TL2 (Our Conversion):**
```
The future of artificial intelligence is residue FarGil Harmarth Rolling
Nearbyabyzel connected aster cooler Again developing Damkem locking...
```
Speed: 19.93 tok/s, **OUTPUT: GARBAGE**

**I2_S (Official Microsoft):**
```
The future of artificial intelligence is uncertain, but one thing is clear:
AI will be a major player in the world of finance. The impact of AI on the
financial industry is likely to be significant...
```
Speed: 20.79 tok/s, **OUTPUT: COHERENT** ✅

---

## Technical Analysis

### Why TL2 Produces Garbage

The pre-quantized model has these complexities:

1. **Packed uint8 weights:** 4 ternary values per byte (2 bits each)
2. **Per-layer weight_scale:** 210 scalar scales (one per weight matrix)
3. **Unknown packing layout:** "Blocked" vs "Interleaved" vs "Reversed"
4. **TL2 transform:** Groups 3 ternary values into 5-bit LUT indices

Our unpacking correctly extracts ternary values (-1, 0, +1), but the TL2 `transform_to_tl2()` function may:
- Expect weights in a different layout
- Apply incorrect scale normalization
- Have dimension ordering issues

### Weight Distribution (Verified Correct)
```
2-bit value distribution:
  0 (->-1): 25.2%
  1 (-> 0): 49.6%
  2 (->+1): 25.2%
  3 (unused): 0%
```

### Architecture Mismatch
```
I2_S GGUF:  general.architecture = "bitnet-b1.58"
TL2 GGUF:   general.architecture = "bitnet"
```

---

## Recommendations

### Option A: Use Official I2_S GGUF (Recommended)
- Download: `microsoft/bitnet-b1.58-2B-4T-gguf`
- Speed: 20.79 tok/s on RTX 4090 pod
- Quality: Coherent output
- **No conversion needed**

### Option B: TL2 via Upstream Fix
Wait for Microsoft to:
1. Publish TL2 GGUF for b1.58-2B-4T
2. Fix `convert-hf-to-gguf-bitnet.py` for pre-quantized models
3. Document the weight packing format

### Option C: Debug TL2 Transform (High Effort)
1. Compare I2_S tensor bytes with TL2 tensor bytes
2. Reverse-engineer the correct unpacking order
3. Validate against known working TL2 models (Llama3 variants)

---

## Benchmark Summary

| Test | Platform | Kernel | Threads | tok/s | Coherent |
|------|----------|--------|---------|-------|----------|
| B200 (prev) | Blackwell | I2_S | 16 | 52.67 | ✅ |
| RTX 4090 | EPYC 7282 | I2_S | 16 | 20.79 | ✅ |
| RTX 4090 | EPYC 7282 | TL2 | 4 | 19.93 | ❌ |

**Note:** RTX 4090 pod has AMD EPYC 7282 Rome (AVX2 only, no AVX-512) which limits TL2 performance gains.

---

## Files Modified on Pod

```
/root/BitNet/
├── setup_env.py                   (patched x2)
├── utils/
│   ├── codegen_tl2.py             (patched)
│   └── convert-hf-to-gguf-bitnet.py (patched x3)
├── include/
│   ├── kernel_config.ini          (generated)
│   └── bitnet-lut-kernels.h       (generated)
├── models/
│   ├── BitNet-b1.58-2B-4T/        (HF download)
│   ├── BitNet-b1.58-2B-4T-unpacked/ (8.4 GB float32)
│   └── bitnet-gguf/ggml-model-i2_s.gguf (official)
└── build/bin/llama-cli            (compiled with TL2=ON)
```

---

## Conclusion

**TL2 conversion from pre-quantized HuggingFace weights is not viable without additional reverse-engineering.** The official I2_S GGUF provides reliable inference at 20.79 tok/s.

The 2.32x TL2 speedup would require:
1. Microsoft publishing official TL2 GGUF, or
2. Converting from float16 weights (not the pre-quantized release), or
3. Understanding the exact packing format for proper unpacking

**Recommendation:** Use official I2_S GGUF for production. TL2 effort is blocked pending upstream support.

---

**KOSCHEI IS IMMORTAL | I2_S = 20.79 tok/s | TL2 BLOCKED | φ² + 1/φ² = 3**
