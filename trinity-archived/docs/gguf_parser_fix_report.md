# GGUF Parser Fix Report

**Date**: February 7, 2026
**Model**: TinyLlama-1.1B-Chat-v1.0 (Q4_K_M quantization)
**Status**: Partial Fix - Transformer Layer Issue Identified

---

## Executive Summary

Investigation of garbled output from Trinity's GGUF inference engine revealed multiple issues in the inference pipeline. Three fixes were applied, but a fundamental issue in the transformer layers persists.

---

## Issues Identified and Fixed

### 1. Embedding Lookup (CRITICAL FIX)

**Problem**: GGUF uses column-major tensor storage. The embedding lookup was using row-major indexing.

**Before** (incorrect):
```zig
for (0..hidden_size) |h| {
    self.buf_hidden[h] = self.token_embedding[h * vocab_size + token];
}
```

**After** (correct):
```zig
const emb_offset = @as(usize, token) * hidden_size;
@memcpy(self.buf_hidden, self.token_embedding[emb_offset..][0..hidden_size]);
```

**Files Modified**:
- `src/vibeec/gguf_model.zig`
- `src/vibeec/gguf_inference.zig`

**Explanation**: GGUF tensor `token_embd.weight` has dims=[2048, 32000] where 2048 (hidden_size) is the innermost dimension with stride 1. Each token's embedding is stored contiguously at offset `token * hidden_size`.

---

### 2. Prefill/Generation Loop (FIX)

**Problem**: The HTTP server was discarding logits from the prefill phase and calling forward() again with the last token at an incorrect position.

**Before** (incorrect):
```zig
for (toks) |tok| {
    _ = model.forward(tok, pos) catch null;
    pos += 1;
}
var last_token = toks[toks.len - 1];
const logits = model.forward(last_token, pos) catch break; // WRONG!
```

**After** (correct):
```zig
var last_logits: ?[]f32 = null;
for (toks) |tok| {
    if (last_logits) |l| self.allocator.free(l);
    last_logits = model.forward(tok, pos) catch null;
    pos += 1;
}
// Use last_logits for first generation step
```

**File Modified**: `src/vibeec/http_server.zig`

---

### 3. Chat Template (FIX)

**Problem**: HTTP server used ChatML format, but TinyLlama expects a different template.

**Before** (ChatML - wrong for TinyLlama):
```
<|im_start|>system
{system_message}<|im_end|>
<|im_start|>user
{user_message}<|im_end|>
<|im_start|>assistant
```

**After** (TinyLlama format):
```
<|system|>
{system_message}</s>
<|user|>
{user_message}</s>
<|assistant|>
```

**File Modified**: `src/vibeec/http_server.zig`

---

## Current State

### Symptoms
- Model loads correctly (7.6s load time)
- Weights have valid statistics (no NaN/Inf)
- Logits from forward pass are finite
- **But**: Output is repetitive garbage (e.g., "üsseldüsseldüsseld..." or "BibliographieBibliographie...")

### Diagnostic Results

**Embedding → Output Projection (bypassing transformer layers)**:
```
Token 1:     top_pred=9069   (different)
Token 2:     top_pred=24465  (different)
Token 100:   top_pred=29313  (different)
Token 1000:  top_pred=26548  (different)
Token 10000: top_pred=28629  (different)
```

**Full Model (with transformer layers)**:
```
Step 0: token=25646 ("üsseld")
Step 1: token=25646 ("üsseld")
Step 2: token=25646 ("üsseld")
... (repeats same token)
```

### Conclusion

The embedding and output projection work correctly. The issue is in the **transformer layers** (attention or FFN).

---

## Sample Output

### Before Fixes
```
Request: "What is 2+2?"
Response: üsseld Einwoüsseld}^{(sliceellerсоadu watersandradkmessaranteüsseld
joueotiumerateсоquelleimoineComponentурнаutatográficaadu}",üsseldinvalidreflect
purcian siguientesfocusурна maximum소 theoretical какaduisches."adu Municipoł
```

### After Fixes
Output still garbled - same pattern of repetitive tokens.

---

## Model Configuration

```
Vocab size:       32000
Hidden size:      2048
Intermediate:     5632
Num layers:       22
Num heads:        32
Num KV heads:     4
Head dim:         64
Context length:   2048
RMS norm eps:     1e-5
RoPE theta:       10000.0
```

---

## Next Steps

1. **Investigate Attention Mechanism**
   - Check Q/K/V projection matrix dimensions and layout
   - Verify GQA (Grouped Query Attention) implementation with 32 heads / 4 KV heads
   - Check attention score computation and softmax

2. **Investigate FFN**
   - Verify SwiGLU activation: `swish(gate) * up`
   - Check weight matrix dimensions and strides

3. **Check RMS Norm**
   - Verify normalization is applied correctly before attention and FFN

4. **Check KV Cache**
   - Verify cache indexing for GQA (4 KV heads shared by 32 heads)

---

## Files Modified

| File | Change |
|------|--------|
| `src/vibeec/gguf_model.zig` | Embedding lookup fix |
| `src/vibeec/gguf_inference.zig` | Embedding lookup fix |
| `src/vibeec/http_server.zig` | Prefill loop fix, chat template fix |

---

## Diagnostic Files Created

| File | Purpose |
|------|---------|
| `diag_gguf.zig` | Check tensor dimensions |
| `diag_inference.zig` | Test forward pass |
| `diag_rope.zig` | Verify RoPE implementation |
| `diag_emb_proj.zig` | Test embedding→output projection |

---

## Appendix: Key Insights

### GGUF Tensor Layout

GGUF stores tensors in **column-major order**. For a tensor with dims=[D0, D1, D2]:
- D0 has stride 1 (innermost)
- D1 has stride D0
- D2 has stride D0*D1

For `token_embd.weight` with dims=[2048, 32000]:
- Each token's embedding is 2048 contiguous floats
- Token N starts at offset N * 2048

### Q4_K Quantization

- Block size: 256 elements (32 sub-blocks of 8)
- Each block has: scales, mins, quantized values
- Dequantization uses block-local scaling

---

*Report generated by Claude Code*
