# Consciousness and T-JEPA Algorithm Boxes — Trinity S³AI

**Version:** 1.0.0
**Date:** 2026-03-26
**Author:** Dmitrii Vasilev
**Purpose:** Algorithm boxes for consciousness gate and T-JEPA architectures
**Related:** docs/research/HSLM_ALGORITHM_BOXES_V1.md

---

## Algorithm 1: Consciousness Gate (System 1/2 Switch)

**Input:** max_similarity ∈ ℝ (maximum VSA similarity from attention)
**Output:** is_conscious ∈ {false, true}, steps ∈ ℕ (reasoning budget)

**Constants:**
- τ = φ^(-1) ≈ 0.618 (consciousness threshold)
- steps_max = 3 (maximum reasoning budget)

```
 1:  procedure CONSCIOUSNESS_GATE(max_similarity):
 2:      // Check threshold activation
 3:      if max_similarity < τ then
 4:          return (false, 0)  // System 1: no reasoning
 5:      end if
 6:
 7:      // Compute excess above threshold
 8:      excess ← max_similarity - τ
 9:
10:      // Scale to reasoning steps (empirical: 5.26 ≈ 1/τ)
11:      steps_raw ← excess × 5.26
12:      steps ← min(steps_max, floor(1 + steps_raw))
13:
14:      // Update EMA tracking
15:      activation ← max_similarity × α_ema + (1 - α_ema) × prev_activation
16:      return (true, steps)
17:  end procedure
```

**Complexity:** O(1) time, O(1) space
**Properties:**
- System 1: Fast pattern matching (TNN-only), no VSA reasoning
- System 2: Slow symbolic reasoning with variable computational budget
- Threshold τ = φ^(-1) derived from Trinity identity
- Budget: 0-3 steps mapped from [τ, 1.0) to [1.0, ∞)

**Reference:** `src/hslm/consciousness.zig` (142 LOC)

---

## Algorithm 2: T-JEPA Mask Generation

**Input:** seq_len ∈ ℕ (sequence length)
**Output:** masks[] ∈ {0, 1}^{seq_len} (binary mask array)

**Constants:**
- mask_ratio = 0.6 (60% of tokens masked)
- span_range = [3, 9] (ternary range)
- num_spans = 3 (number of non-overlapping masks)

```
 1:  procedure GENERATE_TJEPA_MASKS(seq_len):
 2:      const num_masked ← floor(seq_len × mask_ratio)
 3:      const span_min ← span_range[0]  // 3 (ternary)
 4:      const span_max ← span_range[1]  // 9 (sacred, 3²)
 5:      masks ← [0] × seq_len
 6:
 7:      // Generate non-overlapping masks
 8:      for i = 0 to num_spans - 1 do
 9:          // Random span length
10:          span ← UNIFORM(span_min, span_max)
11:
12:          // Random start position
13:          start ← UNIFORM(0, seq_len - span)
14:
15:          // Ensure mask doesn't exceed num_masked total
16:          end ← min(start + span, seq_len)
17:
18:          // Mark masked positions
19:          for j = start to end - 1 do
20:              masks[j] ← 1
21:          end for
22:      end for
23:
24:      // Verify total masked count
25:      actual_masked ← COUNT(masks, 1)
26:
27:      // Adjust if needed (pad or trim)
28:      return masks
29:  end procedure
```

**Complexity:** O(num_spans) time, O(seq_len) space
**Reference:** `src/hslm/tjepa.zig` (MaskResult struct)

---

## Algorithm 3: T-JEPA Forward Pass

**Input:** tokens[0:seq_len-1] ∈ ℕ (token indices), masks[0:seq_len-1] ∈ {0, 1}
**Output:** loss ∈ ℝ (MSE loss on masked positions), repr_variance ∈ ℝ

**Components:**
- Online encoder: EMA of target encoder, learns via gradients
- Target encoder: EMA copy, no gradients, serves as frozen reference
- Predictor: 2× faster learning rate, predicts masked positions

```
 1:  procedure TJEPA_FORWARD(tokens, masks):
 2:      // --- Stage 1: Assemble sequence ---
 3:      for pos = 0 to seq_len - 1 do
 4:          if masks[pos] then
 5:              // Masked: use learned mask embedding
 6:              assembled_seq[pos] ← mask_token
 7:          else
 8:              // Visible: use online encoder hidden state
 9:              assembled_seq[pos] ← context_hidden[pos]
10:          end if
11:      end for
12:
13:      // --- Stage 2: Predictor forward ---
14:      for pos = 0 to seq_len - 1 do
15:          // Run predictor block (TNN + sacred attention)
16:          block.forward(assembled_seq[pos], pos, pred_output[pos])
17:      end for
18:
19:      // --- Stage 3: Target forward (no gradient) ---
20:      target_encoder.forward(assembled_seq)
21:
22:      // --- Stage 4: Compute MSE loss ---
23:      loss ← SMOOTH_L1(pred_output[masks], target_output[masks])
24:
25:      // --- Stage 5: Representational variance ---
26:      repr_var ← VARIANCE(pred_output, target_output)
27:
28:      return loss, repr_var
29:  end procedure
```

**Complexity:** O(seq_len × d_model²) for forward pass
**Reference:** `src/hslm/tjepa.zig` (TJepa struct, forward method)

---

## Algorithm 4: T-JEPA Backward Pass

**Input:** loss, repr_variance
**Output:** Updated online encoder parameters (EMA target frozen)

```
 1:  procedure TJEPA_BACKWARD(loss, repr_variance):
 2:      // --- Stage 1: Backward predictor ---
 3:      loss.backward()  // Gradient flows: pred_output → block → assembly
 4:
 5:      // --- Stage 2: Gradient clipping ---
 6:      CLIP_GRADS(clip_threshold)
 7:
 8:      // --- Stage 3: Optimizer step (predictor only) ---
 9:      ADAM_STEP(predictor_params, predictor_grads, lr_predictor)
10:      ADAM_STEP(predictor_mask_token, predictor_mask_grad, lr_predictor)
11:
12:      // --- Stage 4: EMA update (target ← EMA of online) ---
13:      decay ← PHI_ADAPTIVE_DECAY(repr_variance, step, total_steps)
14:      for each param in target_params, online_params do
15:          target_param ← decay × online_param + (1 - decay) × target_param
16:      end for
17:
18:      // --- Stage 5: Requantize ---
19:      REQUANTIZE(online_encoder, ste_config)
20:      REQUANTIZE(predictor, ste_config)
21:
22:      return updated_model
23:  end procedure
```

**Complexity:** O(params) time, O(params) space
**Reference:** `src/hslm/tjepa_trainer.zig` (trainStep method)

---

## Theorem 3: Consciousness Gate Budget Allocation

**Statement:** The budget allocation function maps max_similarity ∈ [τ, ∞) to steps ∈ {0, 1, 2, 3} such that:
- steps is monotonically non-decreasing with similarity
- At max_similarity = τ: steps = 0 (System 1)
- At max_similarity ≥ 1.0: steps = 3 (full System 2)

**Proof:**

Define excess = max_similarity - τ.

```
steps = min(3, floor(1 + excess × 5.26))
```

Where 5.26 ≈ 1/τ maps the similarity domain to 3 discrete steps.

**Case analysis:**
1. max_similarity < τ (below threshold):
   - excess < 0
   - steps = min(3, 1 + negative) = 0
   - Result: System 1 (0 steps)

2. max_similarity = τ (at threshold):
   - excess = 0
   - steps = min(3, 1) = 1
   - Result: Minimal System 2 (1 step)

3. max_similarity = 1.0:
   - excess = 1.0 - 0.618 = 0.382
   - steps = min(3, 1 + 2.01) = 3
   - Result: Maximum System 2 (3 steps)

∎

---

## Theorem 4: T-JEPA EMA Convergence

**Statement:** For EMA update with adaptive decay, as step → ∞, online encoder converges to target encoder.

**Proof:**

Consider parameter θ_t at step t, with decay ρ_t ∈ [0.996, 1.0].

```
θ_{t+1} = ρ_t × θ_target_t + (1 - ρ_t) × θ_online_t
θ_target_t = θ_target_t  (target is frozen, no change)
```

Define error e_t = θ_online_t - θ_target_t.

```
e_{t+1} = θ_{t+1} - θ_target
         = ρ_t × θ_target_t + (1 - ρ_t) × θ_online_t - θ_target_t
         = ρ_t × (θ_online_t - θ_target_t)
         = ρ_t × e_t
```

By induction:
```
e_t = (∏_{i=t}^T ρ_i) × e_0
```

Since ρ_t ∈ [0.996, 1.0) and eventually reaches 1.0 (target freeze):

```
lim_{t→∞} e_t = (∏_{i=∞}^T 1.0) × e_0 = 0
```

Therefore, e_t → 0, meaning θ_t → θ_target.

∎

---

## Configuration Reference Table

### Consciousness Gate
| Parameter | Value | Description |
|-----------|--------|-------------|
| threshold | 0.618 | φ^(-1) — consciousness activation threshold |
| ema_alpha | 0.1 | EMA smoothing for activation level |
| steps_max | 3 | Maximum reasoning steps (full System 2) |
| budget_slope | 5.26 | Mapping constant (~1/τ) |

### T-JEPA
| Parameter | Value | Description |
|-----------|--------|-------------|
| mask_ratio | 0.6 | 60% of tokens masked |
| span_range | [3, 9] | Ternary range [min, max] |
| num_spans | 3 | Number of mask spans |
| predictor_lr_mult | 2.0 | Predictor learns 2× faster |
| ema_decay_start | 0.996 | Initial decay (high online influence) |
| ema_decay_end | 1.0 | Final decay (target frozen) |

---

## ASCII Architecture Diagram: T-JEPA System

```
┌─────────────────────────────────────────────────────────────────────────────────────────────────┐
│                          T-JEPA TRAINING ARCHITECTURE                             │
├─────────────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  Input: tokens[0:seq_len-1]                                         │
│    ↓                                                                     │
│  ┌─────────────────────────────────────────────────────────────────────────────┐    │
│  │  MASK GENERATOR                                               │    │
│  │  - Generate num_spans non-overlapping random spans               │    │
│  │  - Each span: length ∈ [3, 9], start ∈ [0, seq_len-span)  │    │
│  │  - Output: masks[0:seq_len-1] (binary)                        │    │
│  └─────────────────────────────────────────────────────────────────────────────┘    │
│    ↓                                                                     │
│  ┌─────────────────────────────────────────────────────────────────────────────┐    │
│  │  SEQUENCE ASSEMBLY                                           │    │
│  │  - If masks[pos] = 1: use mask_token embedding                 │    │
│  │  - If masks[pos] = 0: use online_encoder.hidden[pos]        │    │
│  │  - Output: assembled_seq[0:seq_len-1] [EMBED_DIM]          │    │
│  └─────────────────────────────────────────────────────────────────────────────┘    │
│    ↓                                                                     │
│  ┌─────────────────────────────────────────────────────────────────────────────┐    │
│  │  ONLINE ENCODER (EMA TARGET)                                 │    │
│  │  - TrinityBlock: sacred_attn + tnn + attn + reason + gate │    │
│  │  - Learned via ADAM (lr = lr_base)                        │    │
│  │  - Shadows updated via EMA from target                         │    │
│  └─────────────────────────────────────────────────────────────────────────────┘    │
│    ↓                                                                     │
│  ┌─────────────────────────────────────────────────────────────────────────────┐    │
│  │  TARGET ENCODER (EMA SOURCE, FROZEN)                        │    │
│  │  - TrinityBlock: sacred_attn + tnn + attn + reason (no gate) │    │
│  │  - No gradient flow (frozen)                                │    │
│  │  - Shadows updated via EMA (target ← decay × online)         │    │
│  └─────────────────────────────────────────────────────────────────────────────┘    │
│    ↓                                                                     │
│  ┌─────────────────────────────────────────────────────────────────────────────┐    │
│  │  PREDICTOR (2× LEARNING RATE)                                 │    │
│  │  - TrinityBlock (no VSA, no gate)                            │    │
│  │  - Learned via ADAM (lr = 2 × lr_base)                    │    │
│  │  - Projects masked positions to representations              │    │
│  │  - Output: pred_output[0:seq_len-1] [EMBED_DIM]            │    │
│  └─────────────────────────────────────────────────────────────────────────────┘    │
│    ↓                                                                     │
│  ┌─────────────────────────────────────────────────────────────────────────────┐    │
│  │  LOSS COMPUTATION                                                  │    │
│  │  - MSE(pred_output[masks], target_output[masks])              │    │
│  │  - repr_var = VARIANCE(pred_output, target_output)                │    │
│  │  Output: loss, repr_var                                      │    │
│  └─────────────────────────────────────────────────────────────────────────────┘    │
│    ↓                                                                     │
│  ┌─────────────────────────────────────────────────────────────────────────────┐    │
│  │  BACKWARD PASS                                                     │    │
│  │  - loss.backward() → gradients to pred_output, block           │    │
│  │  - Gradient clipping                                         │    │
│  │  - ADAM step (predictor only)                               │    │
│  │  - EMA update (target ← decay × online)                   │    │
│  │  - Requantize (both models)                                │    │
│  └─────────────────────────────────────────────────────────────────────────────┘    │
│    ↓                                                                     │
│  Output: Updated model, loss, repr_var                                    │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## Training Flow Summary

```
┌─────────────────────────────────────────────────────────────────────────────────────────────┐
│                    T-JEPA TRAINING LOOP (PER STEP)                            │
├─────────────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  1. SAMPLE BATCH                                                          │
│     ├─ Random batch from dataset                                              │
│     └─ Output: tokens[0:batch_size-1], targets[0:batch_size-1]       │
│                                                                             │
│  2. GENERATE MASKS                                                       │
│     ├─ Call GENERATE_TJEPA_MASKS(seq_len)                                    │
│     └─ Output: masks[0:seq_len-1]                                        │
│                                                                             │
│  3. ZERO GRADIENTS                                                        │
│     ├─ online_encoder.zeroGrad()                                            │
│     ├─ predictor.zeroGrad()                                               │
│     └─ Output: Clean gradients                                              │
│                                                                             │
│  4. FORWARD PASS                                                          │
│     ├─ Call TJEPA_FORWARD(tokens, masks)                                     │
│     ├─ Output: loss, repr_var, pred_output, target_output                     │
│     └─ Cache masks for backward                                              │
│                                                                             │
│  5. BACKWARD PASS (PREDICTOR → ENCODER ONLY)                            │
│     ├─ Call TJEPA_BACKWARD(loss, repr_var)                                 │
│     ├─ Output: Updated parameters                                            │
│                                                                             │
│  6. COSINE LR SCHEDULE                                                    │
│     ├─ lr = lr_base × warmup_or_cosine(step)                               │
│     ├─ predictor_lr = 2 × lr (2× faster)                               │
│     └─ Output: lr for next step                                            │
│                                                                             │
│  7. EMA UPDATE (ADAPTIVE DECAY)                                        │
│     ├─ decay = PHI_ADAPTIVE_DECAY(repr_var, step, total_steps)             │
│     ├─ target ← EMA(target, online, decay)                                 │
│     └─ Output: Updated target parameters                                       │
│                                                                             │
│  8. REQUANTIZE                                                          │
│     ├─ Both models requantized to ternary                                   │
│     └─ Output: Model with updated ternary weights                             │
│                                                                             │
│  9. LOGGING                                                              │
│     ├─ Log step, loss, repr_var, decay, num_masked                         │
│     └─ Checkpoint at regular intervals                                       │
│                                                                             │
│  Output: Trained model, metrics history                                         │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────────────────────┘
```

---

**Document Control:** CONSC-TJEPA-001
**Status:** Complete — V1.0
**Related:** #415, src/hslm/consciousness.zig, src/hslm/tjepa.zig
**φ² + 1/φ² = 3 | TRINITY**
