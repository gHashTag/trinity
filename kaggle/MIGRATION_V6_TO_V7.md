# Migration Guide: v6 → v7 Scientific Metrics

## Overview

v7 contains scientifically correct implementations of all metrics from v6, with several breaking changes to fix fundamental mathematical errors.

---

## Quick Start

```python
# Old (v6) — Deprecated
from kaggle.eval.metrics import ScientificMetrics
metrics = ScientificMetrics(version="v6")

# New (v7) — Recommended
metrics = ScientificMetrics(version="v7")
```

---

## Breaking Changes

### 1. Min-K%++ — Input Format Change

**v6 (WRONG)**:
```python
# Single log probability per sample
log_probs = [-2.0, -2.5, -3.0, -4.5, -5.0]
result = metrics_v6.detect_contamination_mink_pp(
    log_probabilities=log_probs,
    vocab_size=50000
)
```

**v7 (CORRECT)**:
```python
# Full vocabulary distribution per sample
token_log_probs = [
    [-2.0, -3.0, -4.0, ...],  # All 50K vocab tokens for sample 1
    [-2.5, -3.5, -4.5, ...],  # All 50K vocab tokens for sample 2
]
result = metrics_v7.detect_contamination_mink_pp(
    log_probabilities=token_log_probs,  # Note: parameter name same
    vocab_size=50000
)
```

**Why**: v6 incorrectly applied k_percent to samples instead of vocabulary tokens. v7 requires the full distribution to correctly score all vocabulary tokens.

---

### 2. Full-ECE — Binning Method Change

**v6 (FIXED-WIDTH)**:
```python
result = metrics_v6.calculate_full_ece(
    confidences=confidences,
    correct_token_indices=correct_indices,
    n_bins=10
)
# Uses fixed-width bins: [0, 0.1), [0.1, 0.2), ...
```

**v7 (QUANTILE)**:
```python
result = metrics_v7.calculate_full_ece(
    confidences=confidences,
    correct_token_indices=correct_indices,
    n_bins=10,
    binning="quantile"  # NEW: equal-mass bins from paper
)
# Uses quantile bins: each bin has ~equal samples
```

**Why**: Paper (arXiv:2406.11345) explicitly uses quantile binning for statistical validity.

---

### 3. Prior Shift ECE — Weighting Fix

**v6 (PRIOR-WEIGHTED — BUG)**:
```python
result = metrics_v6.calculate_prior_shift_ece(
    source_confs, source_correct,
    target_confs, target_correct,
    source_prior=0.5,
    target_prior=0.5
)
# weighted_ece = 0.5 * source_ece + 0.5 * target_ece
```

**v7 (SAMPLE-WEIGHTED — FIXED)**:
```python
result = metrics_v7.calculate_prior_shift_ece(
    source_confs, source_correct,
    target_confs, target_correct
)
# weighted_ece = (n_source * source_ece + n_target * target_ece) / (n_source + n_target)
```

**Why**: Sample-weighted averaging is the correct formula from the paper (ICLR 2024).

---

### 4. Dynamic ECE — Integer Bug Fix

**v6 (BUG)**:
```python
# Bug: window_size / 2 creates float indices
for i in range(0, len(...) - window_size + 1, window_size / 2):
    ...
```

**v7 (FIXED)**:
```python
# Fixed: window_size // 2 is integer
step_size = window_size // 2
for i in range(0, len(...) - window_size + 1, step_size):
    ...
```

**Why**: Range requires integer step size. v6 would crash or produce incorrect results.

---

## New Features

### Confidence Intervals

All v7 metrics include bootstrap confidence intervals:

```python
result = metrics_v7.calculate_full_ece(...)
print(f"ECE: {result.ece:.4f}")
print(f"95% CI: [{result.ece_ci_lower:.4f}, {result.ece_ci_upper:.4f}]")
```

### Adaptive ECE

```python
result = metrics_v7.calculate_adaptive_ece(
    confidences=confs,
    correct=corr,
    target_samples_per_bin=100
)
```

### Brier Score

```python
result = metrics_v7.calculate_brier_score(
    confidences=confs,
    correct=corr
)
# Lower is better, 0 = perfect
```

### Distribution-Robust ECE

```python
result = metrics_v7.calculate_dr_ece(
    confidences=confs,
    correct=corr,
    alpha=0.1  # Robustness parameter
)
# Worst-case ECE under distribution shift
```

---

## Deprecation Warnings

v6 now shows deprecation warnings:

```python
>>> metrics = ScientificMetrics(version="v6")
DeprecationWarning: v6 is deprecated due to scientific inaccuracies.
Use v7 for scientifically correct metrics.
See VERSION_INFO['v6'].deprecation_notes for details.
```

---

## Auto-Migration Helper

```python
from kaggle.eval.metrics import migrate_v6_to_v7

# Convert v6 data format to v7
v7_data = migrate_v6_to_v7(v6_log_probs, vocab_size=50000)

result = metrics_v7.detect_contamination_mink_pp(
    log_probabilities=v7_data,
    vocab_size=50000
)
```

---

## Testing Your Migration

```bash
# Run v7 tests
python -m pytest kaggle/tests/test_scientific_metrics_v7.py -v

# Compare results
python -c "
from kaggle.eval.metrics import compare_versions
data = {
    'log_probabilities': [...],
    'vocab_size': 50000,
    'true_labels': [...],
    'confidence_drops': [...],
    'confidences': [[...]],
    'correct_token_indices': [...]
}
results = compare_versions(data, versions=['v6', 'v7'])
for version, result in results.items():
    print(f'{version}: {result}')
"
```

---

## Summary Table

| Feature | v6 | v7 |
|---------|----|----|
| Min-K%++ | ❌ Sample-based | ✅ Vocabulary-based |
| Full-ECE binning | ❌ Fixed-width | ✅ Quantile |
| Prior Shift ECE | ❌ Prior-weighted | ✅ Sample-weighted |
| Dynamic ECE | ❌ Float bug | ✅ Fixed |
| Confidence Intervals | ❌ No | ✅ Bootstrap CI |
| Adaptive ECE | ❌ No | ✅ Yes |
| Brier Score | ❌ No | ✅ Yes |
| Distribution-Robust ECE | ❌ No | ✅ Yes |

---

## Need Help?

- See `CORRECTIONS_V7.md` for detailed scientific corrections
- See test file `kaggle/tests/test_scientific_metrics_v7.py` for examples
- Run `python -m kaggle.eval.scientific_metrics_v7` for demo
