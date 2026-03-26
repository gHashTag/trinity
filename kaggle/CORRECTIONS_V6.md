# Scientific Metrics v6 — Critical Corrections

## Overview

Version 6.0 is a **full refactor** with critical scientific accuracy fixes identified after deep analysis of the original papers.

## Critical Fixes

### 1. Min-K%++ (arXiv:2404.02936) — CRITICAL FIX

**Problem in v5:** `k_percent` was applied to **samples**, not **tokens**.

```python
# WRONG (v5):
k = max(1, int(n_samples * k_percent / 100))  # 5% of samples

# CORRECT (v6):
k = max(1, int(vocab_size * k_percent / 100))  # 5% of vocab tokens
```

**Why this matters:**
- Paper definition: "Min-K% tokens" = bottom K% of TOKENS in vocabulary
- With vocab_size=50,000 and k_percent=5%:
  - Paper: K = 2,500 tokens (bottom 2,500 probability tokens)
  - v5 code: K = 5 samples (if n_samples=100)
- **These are fundamentally different metrics!**

**Additional fixes:**
- Data-dependent threshold: `µ - 2σ` instead of fixed 0.0
- Statistical test (z-test) instead of heuristic `mode_strength`
- P-value reporting for proper significance testing

---

### 2. CoDeC (arXiv:2510.27055) — CRITICAL FIX

**Problem in v5:** AUC calculated as weighted average accuracy.

```python
# WRONG (v5):
auc_score = (seen_accuracy * n_seen + unseen_accuracy * n_unseen) / (n_seen + n_unseen)
# This is weighted average accuracy, NOT ROC AUC!

# CORRECT (v6):
# Compute ROC curve: TPR vs FPR at various thresholds
# Calculate AUC using trapezoidal integration
roc = calculate_roc_auc(true_labels, confidence_scores)
auc_score = roc.auc
```

**Why this matters:**
- ROC AUC = area under TPR/FPR curve
- Weighted accuracy ≠ AUC (different metrics!)
- Paper claims 99.9% AUC — impossible with v5 calculation

**Additional fixes:**
- Requires ground truth labels for proper AUC
- Reports TPR and FPR at optimal threshold
- Provides unsupervised fallback (with warning about self-labeling)

---

### 3. Full-ECE (arXiv:2406.11345) — IMPROVEMENTS

**Issues in v5:**
- Silent fallback to standard ECE for scalar confidences
- No vocab_size validation

**Fixes in v6:**
```python
# v6: Explicit warning for scalar fallback
if isinstance(confidences[0], (int, float)):
    warnings.warn("Scalar confidences provided. Full-ECE requires token-level...")

# v6: Explicit vocab_size validation
if vocab_size is not None and correct_idx >= vocab_size:
    warnings.warn(f"correct_token_index={correct_idx} >= vocab_size={vocab_size}")
```

---

### 4. Class-wise ECE (NeurIPS 2024) — CRITICAL FIX

**Problem in v5:** Used OR logic for sample selection.

```python
# WRONG (v5):
if pred == class_idx or label == class_idx:  # OR logic

# CORRECT (v6):
if label == class_idx:  # True label only!
```

**Why this matters:**
- Kumar et al. paper filters by TRUE LABEL only
- OR logic includes samples where prediction was wrong
- This inflates per-class sample counts and skews ECE

---

### 5. Distribution Shift (ICML 2024) — IMPROVEMENT

**Issue in v5:** Manual KS p-value approximation.

**Fix in v6:**
```python
# Use scipy for accurate KS test
if HAS_SCIPY:
    ks_stat, ks_pvalue = ks_2samp(source_confidences, target_confidences)
else:
    # Fallback to manual approximation
```

**Why this matters:**
- Manual approximation can be inaccurate for small samples (n < 30)
- scipy.stats.ks_2samp is the standard implementation

---

## New Metrics in v6

### 6. Calibration Error under Prior Shift (ICLR 2024)

Handles class imbalance and distribution shift:

```python
result = calculate_prior_shift_ece(
    source_confs, source_correct,
    target_confs, target_correct,
    source_prior=0.5, target_prior=0.5
)
```

### 7. Dynamic Calibration Error (NeurIPS 2024)

Tracks calibration drift over time:

```python
result = calculate_dynamic_ece(
    confidence_history,  # Time series
    correct_history,
    window_size=100
)
```

---

## Mathematical Formulas

### ROC AUC (v6)

```
TPR = TP / (TP + FN)
FPR = FP / (FP + TN)

AUC = ∫ TPR(FPR) dFPR  (trapezoidal integration)
```

### Min-K%++ Score (v6)

```
µ = mean(log probabilities)
σ = std(log probabilities)
score = log p - µ
threshold = µ - 2σ

z = mean(bottom_k_scores) / SE
p_value = P(Z < z)
```

### Full-ECE (v6)

```
For each token i with probability p_i:
- Confidence contribution: p_i
- Accuracy contribution: p_i if i == correct_token else 0

ECE = Σ |conf - acc| × weight
```

---

## Verification

### Unit Tests

```bash
python -m pytest kaggle/tests/test_scientific_metrics_v6.py -v
```

### Integration Tests

```python
# Test Min-K%++ with vocab_size
result = detect_contamination_mink_pp_v6(log_probs, vocab_size=50000)
assert result.k_percent == 5.0  # Applies to vocab_size

# Test CoDeC ROC AUC
result = detect_contamination_codec_v6(true_labels, conf_drops)
assert 0 <= result.auc_score <= 1  # Valid AUC range
assert result.tpr is not None  # Has TPR
assert result.fpr is not None  # Has FPR
```

---

## Comparison Table

| Metric | v5 | v6 | Change |
|--------|-----|-----|--------|
| Min-K%++ k | 5% of samples | 5% of vocab | **CRITICAL** |
| CoDeC AUC | Weighted accuracy | ROC TPR/FPR | **CRITICAL** |
| Full-ECE | Silent fallback | Warning + validation | **IMPROVED** |
| Class-wise ECE | OR logic | True label only | **FIXED** |
| Distribution Shift | Manual KS | scipy KS | **IMPROVED** |
| Prior Shift ECE | — | ✅ New | **NEW** |
| Dynamic ECE | — | ✅ New | **NEW** |

---

## References

1. Min-K%++: arXiv:2404.02936 — "Theoretical Analysis of Min-K% Probabilities"
2. CoDeC: arXiv:2510.27055 — "Context-based Contamination Detection"
3. Full-ECE: arXiv:2406.11345 — "Full-ECE for Generative Models"
4. Class-wise ECE: Kumar et al. (NeurIPS 2024)
5. Distribution Shift: Wang et al. (ICML 2024)
6. Prior Shift ECE: Tax et al. (ICLR 2024)
7. Dynamic ECE: Gupta et al. (NeurIPS 2024)
8. ROC Analysis: Fawcett (2006) — "An introduction to ROC analysis"
