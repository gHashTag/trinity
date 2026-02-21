# BitNet Zig Fix Attempt Report

## Date
2026-02-06

## Status
**UNRESOLVED** - Zig implementation still produces garbage; official bitnet.cpp works.

---

## Executive Summary

Attempted to fix the Zig BitNet inference by studying bitnet.cpp. Identified and removed erroneous `quantizeActivations` calls, but the model still produces repetitive garbage tokens. The root cause remains unidentified.

**Recommendation:** Use official bitnet.cpp (17-27 tok/s coherent) until Zig issues are resolved.

---

## What Was Tried

### 1. Studied bitnet.cpp Forward Pass

Analyzed `/bitnet-cpp/3rdparty/llama.cpp/src/llama.cpp` function `build_bitnet_158()` (lines 15389-15537).

**Key observations:**
- bitnet.cpp does NOT apply activation quantization during inference
- Uses FP32/FP16 for all intermediate activations
- Has `f_clamp_kqv`, `f_residual_scale` options (but set to 0.0 for BitNet)
- Uses LUT-based ternary matmul for efficiency

### 2. Identified Erroneous quantizeActivations

Our Zig implementation had 4 calls to `quantizeActivations()` in the forward pass:
```zig
// Line 403: After input_layernorm
_ = quantizeActivations(normed_slice);

// Line 472: After attn_sub_norm
_ = quantizeActivations(self.attn_output);

// Line 487: After post_attention_layernorm
_ = quantizeActivations(normed_slice);

// Line 502: After ffn_sub_norm
_ = quantizeActivations(self.ffn_gate);
```

**Problem:** These were applying 8-bit quantization (round to int8, dequant back to FP32) at every layer, causing precision loss that accumulated across 30 layers.

### 3. Removed quantizeActivations Calls

Edited `bitnet_full_layers.zig` to remove all 4 calls:
```zig
// Before: Input LayerNorm → activation quant → Q/K/V projections
// After:  Input LayerNorm → Q/K/V projections (NO activation quant)
```

### 4. Regenerated Binary Model

The binary model `models/bitnet-2b.bin` was corrupted (wrong header values). Regenerated using `convert_safetensors.py`:
- Vocab: 128256 (correct)
- Hidden: 2560 (correct)
- All 30 layers loaded with scales

### 5. Tested - Still Broken

After fixes:
```
[Test 1] Prompt: "Hello, my name is"
Generated: "adooadooadoo ).adooadoo ).adooadooadoo..."
Tokens: 78212 78212 78212 7609...
Speed: 0.2-0.3 tok/s
```

**Result:** Still produces the same repetitive garbage tokens.

---

## Remaining Hypotheses

### 1. Ternary Encoding Mismatch
- Our encoding: 00=0, 01=+1, 10=-1
- Microsoft's encoding may differ
- Need to verify against safetensors raw bytes

### 2. Scale Application
- We apply per-tensor scale after matmul
- bitnet.cpp may apply it differently
- I2_S format may have per-block scales

### 3. Numerical Precision
- Our matmul uses FP32 accumulation
- bitnet.cpp uses SIMD-optimized LUT approach
- Different numerical properties

### 4. Missing Normalization
- RMS norm epsilon differences
- SubLN placement differences

### 5. Hidden State Explosion
Previous debug showed:
```
Layer 0:  norm = 16,254
Layer 10: norm = 84,950
Layer 20: norm = 626,538
Layer 29: norm = 1,795,752
```
This 110x growth persists even without quantizeActivations.

---

## Performance Comparison

| Implementation | Speed | Coherent | Status |
|----------------|-------|----------|--------|
| bitnet.cpp (Metal) | 17-27 tok/s | YES | Working |
| Zig (CPU) | 0.2-0.3 tok/s | NO | Broken |

---

## Verified Working: Official bitnet.cpp

12+ prompts tested with coherent output:
- "Hello, my name is" → "[Name] and I am a [Job Title]..."
- "The capital of France is" → "Paris. This is because..."
- "Water boils at" → "100°C..."
- "Once upon a time" → Full creative story about Max

Full results in: `docs/bitnet_official_cpp_report.md`

---

## Next Steps

### Option A: Deep Debug Zig (High Effort)
1. Add layer-by-layer norm tracking
2. Compare intermediate values with bitnet.cpp at each step
3. Verify ternary encoding matches exactly
4. Check for subtle matmul bugs

### Option B: FFI to bitnet.cpp (Medium Effort)
1. Create C wrapper around llama.cpp
2. Call from Zig via @cImport
3. Get working inference immediately

### Option C: Port bitnet.cpp Kernels (High Effort)
1. Study ggml-bitnet-lut.cpp LUT implementation
2. Rewrite in Zig with same numerical properties
3. Add SIMD optimization

**Recommendation:** Option B for fastest working solution.

---

## Toxic Verdict

```
╔══════════════════════════════════════════════════════════════════╗
║                    🔥 TOXIC VERDICT 🔥                           ║
╠══════════════════════════════════════════════════════════════════╣
║ WHAT WAS DONE:                                                   ║
║ - Studied bitnet.cpp forward pass (build_bitnet_158)             ║
║ - Found and removed erroneous quantizeActivations calls          ║
║ - Regenerated corrupted binary model                             ║
║ - Tested with 12 prompts                                         ║
║                                                                  ║
║ WHAT FAILED:                                                     ║
║ - Still produces garbage output                                  ║
║ - Hidden state explosion persists                                ║
║ - Root cause not identified                                      ║
║                                                                  ║
║ METRICS:                                                         ║
║ - bitnet.cpp: 17-27 tok/s, coherent ✅                           ║
║ - Zig: 0.2-0.3 tok/s, garbage ❌                                 ║
║                                                                  ║
║ SELF-CRITICISM:                                                  ║
║ - Should have done byte-level comparison earlier                 ║
║ - Spent too much time on wrong hypothesis (quantizeActivations)  ║
║ - Need more systematic debugging approach                        ║
║ - Should verify ternary encoding matches exactly                 ║
║                                                                  ║
║ SCORE: 4/10 (attempted fix, still broken)                        ║
╚══════════════════════════════════════════════════════════════════╝
```

---

## Files Modified

| File | Change |
|------|--------|
| `src/vibeec/bitnet_full_layers.zig` | Removed 4 quantizeActivations calls |
| `models/bitnet-2b.bin` | Regenerated (was corrupted) |

---

## Tech Tree

### [A] Verify Ternary Encoding
- Complexity: ★★☆☆☆
- Goal: Confirm byte-level encoding matches Microsoft's
- Method: Dump safetensors bytes, compare with our decoder

### [B] Layer-by-Layer Debug vs bitnet.cpp
- Complexity: ★★★★☆
- Goal: Find exact divergence point
- Method: Add debug output to both, compare all 30 layers

### [C] FFI Integration with libllama
- Complexity: ★★★☆☆
- Goal: Get working inference via existing bitnet.cpp
- Method: Create C wrapper, call from Zig

**Recommendation:** [A] first to rule out encoding issues, then [C] for immediate working solution.

---

**φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL**
