# BitNet Forward Pass Debug Report

**Date:** February 4, 2026
**Status:** BUGS FIXED - Ready for RunPod Testing

---

## Executive Summary

Identified and fixed **5 critical bugs** in `src/vibeec/bitnet_full_model.zig` that were causing incoherent (garbage) text output. The root cause was premature activation quantization before F32 matrix operations, plus an incorrect SwiGLU formula.

---

## Bug Analysis

### Previous Symptom

```
Prompt: "Write a Python function to calculate fibonacci:"
Output: "O super, c fatal fan, brut fem p..." (GARBAGE)

Prompt: "1 + 1 ="
Output: "brut. brut. brut. brut. brut" (GARBAGE)
```

### Root Cause

The forward pass was calling `quantizeActivationsInPlace()` **BEFORE** F32 linear projections. Since the model weights are stored as F32 (not ternary), this quantization:

1. Clips activations to 8-bit range [-127, 127]
2. Scales them to fit that range
3. Destroys the full-precision information needed for accurate F32 matmul

---

## Bugs Fixed

### Bug #1: Quantization Before Q/K/V Projections (Line 667)

**Before:**
```zig
_ = quantizeActivationsInPlace(normed);
f32MatVec(layer.q_proj, normed, q, hidden, hidden);  // Q projection
```

**After:**
```zig
// NOTE: Activation quantization REMOVED - was destroying information
// F32 weights need F32 activations for accurate inference
f32MatVec(layer.q_proj, normed, q, hidden, hidden);  // Q projection
```

### Bug #2: Quantization Before O Projection (Line 762)

**Before:**
```zig
_ = quantizeActivationsInPlace(self.attn_output);
f32MatVec(layer.o_proj, self.attn_output, o_out, hidden, hidden);
```

**After:**
```zig
// NOTE: Activation quantization REMOVED before O projection
f32MatVec(layer.o_proj, self.attn_output, o_out, hidden, hidden);
```

### Bug #3: Quantization Before Gate/Up Projections (Line 780)

**Before:**
```zig
_ = quantizeActivationsInPlace(normed);
f32MatVec(layer.gate_proj, normed, self.ffn_intermediate, inter, hidden);
```

**After:**
```zig
// NOTE: Activation quantization REMOVED before gate/up projections
f32MatVec(layer.gate_proj, normed, self.ffn_intermediate, inter, hidden);
```

### Bug #4: Incorrect SwiGLU Formula (Line 792-794)

**Before:**
```zig
// SwiGLU: gate * silu(up)  <-- WRONG!
for (self.ffn_intermediate, up_out) |*g, u| {
    g.* = g.* * silu(u);
}
```

**After:**
```zig
// SwiGLU: silu(gate) * up (standard formula)
// silu(x) = x * sigmoid(x)
for (self.ffn_intermediate, up_out) |*g, u| {
    g.* = silu(g.*) * u;
}
```

**Explanation:** Standard SwiGLU applies SiLU to the gate output, not the up output.

### Bug #5: Quantization Before Down Projection (Line 800)

**Before:**
```zig
_ = quantizeActivationsInPlace(self.ffn_intermediate);
f32MatVec(layer.down_proj, self.ffn_intermediate, down_out, hidden, inter);
```

**After:**
```zig
// NOTE: Activation quantization REMOVED before down projection
f32MatVec(layer.down_proj, self.ffn_intermediate, down_out, hidden, inter);
```

---

## Technical Explanation

### Why Quantization Was Wrong

The original BitNet b1.58 paper describes:
- **Ternary weights** {-1, 0, +1} with scale factors
- **8-bit activation quantization** AFTER projections for efficient ternary matmul

Our implementation has:
- **F32 weights** loaded from safetensors (not ternary)
- **F32 matrix multiplication** via `f32MatVec()`

Applying 8-bit quantization to activations BEFORE F32 matmul:
1. Destroys precision unnecessarily
2. Introduces quantization error that accumulates through layers
3. Results in garbage output after 24 transformer layers

### Correct Approach

For true BitNet b1.58 inference:
1. Load weights as ternary (or quantize to ternary on the fly)
2. Use ternary matmul (add-only, no multiply)
3. Quantize activations AFTER projections for next layer

For F32 fallback inference (our current approach):
1. Keep weights as F32
2. Use F32 matmul
3. **No intermediate activation quantization**

---

## Diff Summary

```diff
-_ = quantizeActivationsInPlace(normed);      // Before Q/K/V
+// Removed: quantization was destroying information

-_ = quantizeActivationsInPlace(self.attn_output);  // Before O
+// Removed: F32 weights need F32 activations

-_ = quantizeActivationsInPlace(normed);      // Before gate/up
+// Removed: premature quantization

-g.* = g.* * silu(u);   // WRONG SwiGLU
+g.* = silu(g.*) * u;   // Correct SwiGLU

-_ = quantizeActivationsInPlace(self.ffn_intermediate);  // Before down
+// Removed: F32 inference pipeline
```

---

## Comparison with Reference Implementations

### llama.cpp Forward Pass

```cpp
// No activation quantization for F32 weights
ggml_mul_mat(ctx0, model.layers[il].wq, cur);  // Q = x @ W_q
ggml_mul_mat(ctx0, model.layers[il].wk, cur);  // K = x @ W_k
ggml_mul_mat(ctx0, model.layers[il].wv, cur);  // V = x @ W_v

// SwiGLU: silu(gate) * up
ggml_silu(ctx0, cur);  // Apply silu to gate
ggml_mul(ctx0, cur, cur_up);  // Multiply by up
```

### HuggingFace Transformers

```python
# No activation quantization for F32
hidden_states = self.q_proj(hidden_states)  # F32 linear

# SwiGLU
gate = self.gate_proj(hidden_states)
up = self.up_proj(hidden_states)
hidden_states = F.silu(gate) * up  # silu(gate) * up
```

Our fixed implementation now matches these reference implementations.

---

## Next Steps

1. **Test on RunPod RTX 4090:**
   - Build with Zig 0.13.0
   - Load BitNet model
   - Generate text with 10+ prompts, 200-500 tokens each
   - Verify coherent output

2. **Expected Results:**
   - Coherent English text (not garbage)
   - Reasonable token generation speed (10-50 tok/s)
   - No NaN/Inf in logits

3. **If Still Incoherent:**
   - Check weight loading (F16 -> F32 conversion)
   - Verify RoPE frequency implementation
   - Compare intermediate activations with reference

---

## Files Modified

| File | Change |
|------|--------|
| `src/vibeec/bitnet_full_model.zig` | Removed 4 quantization calls, fixed SwiGLU |

---

## Success Criteria

- [ ] Zig build succeeds on RunPod
- [ ] Model loads all 24 layers
- [ ] Generate 10+ prompts with coherent output
- [ ] Tokens/sec >= 10
- [ ] No "brut" garbage in output

---

**KOSCHEI IS IMMORTAL | FORWARD PASS FIXED | READY FOR TESTING | phi^2 + 1/phi^2 = 3**
