# Kaggle Scientific Metrics — v4 Corrections

## Overview

After reading the actual scientific papers, **critical errors** were found in the v3.3 implementations. This document describes the CORRECT versions.

---

## 1. Full-ECE (arXiv:2406.11345)

### ❌ v3.3 Implementation (WRONG)

```python
def calculate_full_ece(confidences: List[List[float]], correct: List[bool]):
    for probs, is_correct in zip(confidences, correct):
        for token_idx, prob in enumerate(probs):
            bin_acc_weighted_sum[bin_idx] += prob if is_correct else 0.0
```

**Problem:** `is_correct` applies to the **entire sample**, not individual tokens!

### ✅ v4 Correct Implementation

```python
def calculate_full_ece_v4_correct(
    confidences: List[List[float]],
    correct_token_indices: List[int],  # NOTE: indices, NOT booleans!
):
    for probs, correct_idx in zip(confidences, correct_token_indices):
        for token_idx, prob in enumerate(probs):
            is_token_correct = (token_idx == correct_idx)
            bin_acc_weighted_sum[bin_idx] += prob if is_token_correct else 0.0
```

**Key Difference:** Must pass **token indices** instead of boolean correctness.

### Example

```python
# Sample: [0.2, 0.7, 0.1], correct token is index 2 (prob=0.1)
# Token 0 (prob=0.2): NOT correct → contributes 0 to accuracy
# Token 1 (prob=0.7): NOT correct → contributes 0 to accuracy
# Token 2 (prob=0.1): CORRECT → contributes 0.1 to accuracy

confidences = [[0.2, 0.7, 0.1]]
correct_token_indices = [2]  # NOT [False]!
```

---

## 2. Min-K%++ (arXiv:2404.02936, Equation 3)

### ❌ v3.3 Implementation (WRONG)

```python
def detect_contamination_min_k_pp(confidences: List[float]):
    # Used probabilities and "spread window" heuristic
    sorted_conf = sorted(confidences)
    bottom_k = sorted_conf[:k]
    spread = max(bottom_k) - min(bottom_k)
    mode_score = (density / expected_density - 1.0) if spread < mode_window else 0.0
```

**Problem:** Does NOT follow paper's Equation 3 formula!

### ✅ v4 Correct Implementation

```python
def detect_contamination_min_k_pp_v4_correct(
    log_probabilities: List[float],  # CRITICAL: LOG probabilities!
):
    # Equation 3: score = log p - µ
    mu = sum(log_probabilities) / n
    scores = [lp - mu for lp in log_probabilities]

    # Negative scores = below average = contamination
    bottom_k_scores = sorted(scores)[:k]
    mean_min_k_score = sum(bottom_k_scores) / k
```

**Key Differences:**
1. Uses **LOG probabilities**, not probabilities
2. Formula: `score = log p - µ` (deviation from mean)
3. Negative score = below average = contamination

### Example

```python
# Clean model: log probs around -2.0 (prob ~ 0.135)
log_probs_clean = [-1.8, -2.0, -2.2, -1.9, -2.1]
# Result: scores near 0, no contamination

# Contaminated model: some samples < -4.0
log_probs_contam = [-1.8, -2.0, -2.2, -4.5, -5.0, -4.2]
# Result: negative scores for last 3, contamination detected
```

---

## 3. CoDeC (arXiv:2510.27055)

### ❌ v3.3 Implementation (WRONG)

```python
# AUC estimation formula was MY INVENTION, not from paper!
effect_size = mean_drop / pooled_std
z_score = effect_size / (2 ** 0.5)
estimated_auc = norm_cdf(z_score)  # This is NOT from the paper!
```

**Problem:** The AUC formula `AUC = Φ(d/√2)` is **my invention**, not from the paper!

### ✅ v4 Correct Implementation

```python
def detect_contamination_codec_v4_correct(
    model_get_confidence,
    test_samples,
    seen_context_samples,      # Training data
    unseen_context_samples,    # Control data
):
    # Paper specifies dataset-level seen/unseen classification
    # Calculate confidence drops for both contexts
    for sample in test_samples:
        seen_drop = (conf_base - conf_with_seen) / conf_base
        unseen_drop = (conf_base - conf_with_unseen) / conf_base

        # Classify as seen if: large drop with seen, small drop with unseen
        is_predicted_seen = (seen_drop > threshold) and (unseen_drop < threshold * 0.5)

    # AUC = classification accuracy at dataset level
    auc_score = (seen_accuracy * n_seen + unseen_accuracy * n_unseen) / (n_seen + n_unseen)
```

**Key Differences:**
1. Requires **BOTH seen and unseen context** (not just seen)
2. AUC computed via **dataset-level classification**, not per-sample formula
3. 99.9% AUC claim is for dataset classification, not individual samples

---

## Migration Guide

### Full-ECE

```python
# OLD (v3.3) - WRONG
from eval.scientific_metrics_v4 import calculate_full_ece
ece = calculate_full_ece(prob_distributions, [True, False, True])

# NEW (v4) - CORRECT
from eval.scientific_metrics_v5 import calculate_full_ece_v4_correct
result = calculate_full_ece_v4_correct(prob_distributions, [0, 2, 1])
```

### Min-K%++

```python
# OLD (v3.3) - WRONG
from validate.codec import detect_contamination_min_k_pp
result = detect_contamination_min_k_pp(confidences)  # probabilities

# NEW (v4) - CORRECT
from eval.scientific_metrics_v5 import detect_contamination_min_k_pp_v4_correct
result = detect_contamination_min_k_pp_v4_correct(log_probabilities)  # LOG probs
```

### CoDeC

```python
# OLD (v3.3) - WRONG
from validate.codec import detect_contamination_codec
result = detect_contamination_codec(model, test_samples, context_samples)

# NEW (v4) - CORRECT
from eval.scientific_metrics_v5 import detect_contamination_codec_v4_correct
result = detect_contamination_codec_v4_correct(
    model, test_samples,
    seen_context_samples,      # REQUIRED
    unseen_context_samples      # REQUIRED
)
```

---

## Test Results

```
tests/test_scientific_metrics_v4.py: 48 tests OK
tests/test_scientific_metrics_v5.py: 35 tests OK (including v4 corrections)
```

---

## References

- **Full-ECE**: arXiv:2406.11345 — "Full-ECE for Generative Models"
- **Min-K%++**: arXiv:2404.02936 — "Theoretical Analysis of Min-K% Probabilities"
- **CoDeC**: arXiv:2510.27055 — "Context-based Contamination Detection"
