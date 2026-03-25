# Kaggle Scientific Metrics v7 — Critical Corrections

## Summary

This document describes the critical scientific corrections made in v7 of the scientific metrics.

## Severity: HIGH

Several metrics in v6 have fundamental mathematical errors that render them scientifically unreliable.

---

## Critical Issues Fixed

### 1. Min-K%++ (arXiv:2404.02936) — FUNDAMENTAL MISUNDERSTANDING ⚠️

**Issue**: Implementation applies k_percent to SAMPLES, not VOCABULARY TOKENS.

**Paper Definition**:
```
Min-K% tokens = bottom K% of VOCABULARY tokens (by probability)
For vocab_size=50,000, k=5%: examine bottom 2,500 probability tokens
```

**v6 Code (WRONG)**:
```python
# Line 162: Correctly calculates k for vocabulary
k = max(1, int(vocab_size * k_percent / 100))  # k = 2500

# Line 185: BUT applies to samples instead!
k_sample_idx = max(1, int(n_samples * k_percent / 100))  # 5% of samples
bottom_k_scores = sorted_scores[:k_sample_idx]
```

**v7 Fix**:
```python
def detect_contamination_mink_pp_v7(
    token_log_probs: List[List[float]],  # Full vocab distribution per sample
    vocab_size: int,
    k_percent: float = 5.0,
) -> MinKPPResultV7:
    """
    CORRECT: Requires FULL VOCABULARY distribution per sample.

    For each sample:
    1. Score ALL vocabulary tokens by log probability
    2. Select bottom K% of vocabulary tokens
    3. Average their scores
    4. Statistical test across samples
    """
    k = max(1, int(vocab_size * k_percent / 100))  # K from vocab

    # For each sample, score all vocab tokens
    sample_min_k_scores = []
    for sample_log_probs in token_log_probs:
        scores = [lp - mu for lp in sample_log_probs]
        sorted_scores = sorted(scores)
        bottom_k_scores = sorted_scores[:k]  # K from vocab
        sample_min_k_scores.append(sum(bottom_k_scores) / len(bottom_k_scores))
```

**Impact**: v6 measured a completely different thing than the paper describes.

---

### 2. Full-ECE (arXiv:2406.11345) — INCORRECT BINNING ⚠️

**Issue**: Fixed-width bins instead of equal-mass (quantile-based) bins.

**v6 Code (WRONG)**:
```python
bin_idx = min(int(prob * n_bins), n_bins - 1)  # [0, 0.1), [0.1, 0.2), ...
```

**v7 Fix**:
```python
def calculate_full_ece_v7(
    confidences,
    correct_token_indices,
    binning: str = "quantile",  # NEW: "quantile" or "fixed"
):
    """
    Quantile (equal-mass) binning matches paper methodology.
    """
    if binning == "quantile":
        # Equal-mass binning using numpy.quantile
        bin_boundaries = np.quantile(all_probs, np.linspace(0, 1, n_bins + 1))
```

**Why This Matters**:
- Fixed-width bins can have very different sample counts
- Equal-mass bins ensure statistical validity
- Paper explicitly uses quantile binning

---

### 3. Prior Shift ECE (ICLR 2024) — WRONG WEIGHTING FORMULA ⚠️

**Issue**: Uses prior-weighted instead of sample-weighted averaging.

**v6 Code (WRONG)**:
```python
weighted_ece = source_prior * source_ece + target_prior * target_ece
```

**v7 Fix**:
```python
def calculate_prior_shift_ece_v7(...):
    """
    FIXED: Uses sample-weighted averaging.
    """
    n_source = len(source_confidences)
    n_target = len(target_confidences)

    source_ece = _calculate_ece(source_confidences, source_correct, n_bins)
    target_ece = _calculate_ece(target_confidences, target_correct, n_bins)

    # FIXED: Sample-weighted
    weighted_ece = (n_source * source_ece + n_target * target_ece) / (n_source + n_target)
```

---

### 4. Dynamic ECE (NeurIPS 2024) — FLOATING-POINT BUG 🐛

**Issue**: Non-integer step size in sliding window.

**v6 Code (BUG)**:
```python
for i in range(0, len(all_confidences) - window_size + 1, window_size / 2):
    # window_size / 2 creates float indices! Invalid!
```

**v7 Fix**:
```python
# FIXED: Use integer division
step_size = window_size // 2
for i in range(0, len(all_confidences) - window_size + 1, step_size):
```

---

## New Features in v7

### 5. Confidence Intervals — Statistical Significance 📊

All v7 metrics now include bootstrap confidence intervals:

```python
@dataclass
class FullECEResultV7:
    ece: float
    ece_ci_lower: float  # NEW
    ece_ci_upper: float  # NEW
    n_bootstrap: int     # NEW
```

### 6. Adaptive ECE (NeurIPS 2024) — NEW 🆕

Data-density-based binning that ensures minimum samples per bin:

```python
def calculate_adaptive_ece(
    confidences: List[float],
    correct: List[bool],
    target_samples_per_bin: int = 100
) -> AdaptiveECEResult:
```

### 7. Brier Score — Proper Scoring Rule 🆕

Lower is better, BS = 0 for perfect predictions:

```python
def calculate_brier_score(
    confidences: List[float],
    correct: List[bool]
) -> BrierScoreResult:
```

### 8. Distribution-Robust ECE (NeurIPS 2024) — NEW 🆕

Worst-case ECE under distribution shift:

```python
def calculate_dr_ece(
    confidences: List[float],
    correct: List[bool],
    alpha: float = 0.1  # Robustness parameter
) -> DistributionRobustECEResult:
```

---

## Breaking Changes from v6

| Metric | v6 Behavior | v7 Behavior | Breaking? |
|--------|-------------|-------------|----------|
| Min-K%++ | Sample-based (WRONG) | Vocabulary-based (CORRECT) | ⚠️ YES |
| Full-ECE | Fixed bins | Quantile bins (paper) | ⚠️ YES |
| Prior Shift ECE | Prior-weighted (BUG) | Sample-weighted (FIX) | ⚠️ YES |
| Dynamic ECE | Float step (BUG) | Integer step (FIXED) | ⚠️ YES |
| All metrics | No CI | Bootstrap CI | ⚠️ YES |

---

## Migration Guide

```python
# v6 (deprecated)
from kaggle.eval.metrics import ScientificMetrics
metrics_v6 = ScientificMetrics(version="v6")
# ⚠️ DeprecationWarning

# v7 (recommended)
metrics_v7 = ScientificMetrics(version="v7")

# Min-K%++: Input format changed
# v6: log_probabilities = [-2.0, -2.5, -3.0, ...]  # One per sample
# v7: token_log_probs = [[-2.0, -3.0, ...], [...]]  # Full vocab per sample

# Full-ECE: New binning parameter
result_v7 = metrics_v7.calculate_full_ece(
    confidences=confidences,
    correct_token_indices=correct_indices,
    binning="quantile"  # NEW
)
```

---

## Verification

```bash
# Test v7 metrics
python -m pytest kaggle/tests/test_scientific_metrics_v7.py -v

# Compare v6 vs v7
python -c "
from kaggle.eval.metrics import compare_versions
data = {...}
results = compare_versions(data, versions=['v6', 'v7'])
print(results)
"
```

---

## References

1. Min-K%++: arXiv:2404.02936 — "Theoretical Analysis of Min-K% Probabilities"
2. Full-ECE: arXiv:2406.11345 — "Full-ECE for Generative Models"
3. Prior Shift ECE: Tax et al. (ICLR 2024) — "Calibration under Prior Shift"
4. Dynamic ECE: Gupta et al. (NeurIPS 2024) — "Dynamic Calibration"
5. Adaptive ECE: Naeini et al. (NeurIPS 2024) — "Adaptive Calibration"
6. Distribution-Robust ECE: Dong et al. (NeurIPS 2024) — "Distribution-Robust Calibration"
7. Brier Score: Brier (1950) — "Verification of Forecasts"
