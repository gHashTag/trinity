# Kaggle Scientific Metrics — v7.5 Corrections

**Date**: 2026-03-26
**Version**: v7.5
**Author**: Dmitrii Vasilev

---

## Overview

This document details the corrections made in **v7.5** of the scientific metrics implementation.

---

## Summary

v7.5 focuses on **fixing misleading confidence interval calculations** in the Min-K%++ contamination detection method.

### Key Fix

| Issue | Severity | Status |
|-------|----------|--------|
| Arbitrary CI conversion in Min-K%++ | MEDIUM | ✅ FIXED |

---

## Fix #1: Remove Arbitrary CI Conversion in Min-K%++

### Location
`kaggle/eval/scientific_metrics_v7.py` lines 800-812

### Problem

**Old code (v7.4 and earlier)**:
```python
# Convert score CI to confidence CI
ci_lower = max(0.0, min(1.0, confidence_score - abs(ci_upper - mean_min_k_score) * 0.1))
ci_upper = min(1.0, max(0.0, confidence_score + abs(ci_upper - mean_min_k_score) * 0.1))
```

**Issues**:
1. **Arbitrary factor 0.1** with no statistical justification
2. **Wrong target**: CI was reported for `confidence_score` instead of `mean_min_k_score`
3. **Misleading**: CI bounds didn't represent actual metric uncertainty

### Solution

**New code (v7.5)**:
```python
# v7.5: Report CI for the actual metric (mean_min_k_score)
_, score_ci_lower, score_ci_upper = _bootstrap_confidence_interval(
    sample_min_k_scores, n_bootstrap=n_bootstrap
)
# Store the actual score CI directly
ci_lower = score_ci_lower  # CI for mean_min_k_score
ci_upper = score_ci_upper  # CI for mean_min_k_score
```

**Benefits**:
1. **Statistically sound**: CI directly represents metric uncertainty
2. **Transparent**: No arbitrary transformations
3. **Correct**: Users see actual confidence bounds for the reported metric

---

## Previously Fixed Issues (Already in v7.x)

### ✅ Full-ECE Sample-Weighted (v7.1)
- **Location**: `scientific_metrics_v7.py` lines 995-997
- **Fix**: Uses `count / n_total` instead of probability weighting
- **Impact**: HIGH — Fixed systematic bias toward high-confidence predictions

### ✅ CoDeC P-value Direct (v7.1)
- **Location**: `scientific_metrics_v7.py` line 774
- **Fix**: Directly uses `p_value` from Mann-Whitney U
- **Impact**: HIGH — Fixed incorrect statistical significance reporting

### ✅ Full-ECE Include All Probabilities (v7.2)
- **Location**: `scientific_metrics_v7.py` lines 903-911
- **Fix**: Only skips NaN/negative, includes valid low probabilities
- **Impact**: MEDIUM — Fixed exclusion of valid predictions

### ✅ True DeLong CI (v7.3)
- **Location**: `scientific_metrics_v7.py` lines 446-491
- **Fix**: Full placement value calculation with φ₁ and φ₀
- **Impact**: MEDIUM — More accurate confidence intervals for AUC

### ✅ Min-K%++ Raw Log Probs (v7.2)
- **Location**: `scientific_metrics_v7.py` line 716-717
- **Fix**: No mean normalization, uses raw log probabilities
- **Impact**: LOW — Matches paper specification exactly

### ✅ CI Index Calculation (v7.2)
- **Location**: `scientific_metrics_v7.py` line 316
- **Fix**: Uses `math.floor/math.ceil` for accurate percentile indices
- **Impact**: LOW — Minor bias correction for small bootstrap sizes

---

## New Features in v7.5

### BCa Bootstrap CI
Added `_bootstrap_bca_ci()` function implementing Efron (1987) bias-corrected accelerated bootstrap:

```python
def _bootstrap_bca_ci(
    values: List[float],
    alpha: float = 0.05,
    n_bootstrap: int = 10000,
    seed: Optional[int] = None,
    min_samples: int = 10
) -> Tuple[float, float, float]:
```

**Benefits**:
- Corrects for bias in bootstrap distribution
- Adjusts for skewness (acceleration factor)
- More accurate CIs than simple percentile method

### Brier Score
Added `simple_brier_score()` function:

```python
def simple_brier_score(
    confidences: List[float],
    correct: List[bool]
) -> float:
    """
    Brier Score: (1/N) * Σ(f_i - y_i)²
    Lower is better (0 = perfect, 0.25 = random, 1 = worst)
    """
```

### Ranked Voting SC
Added `ranked_voting_sc()` function with multiple methods:

```python
def ranked_voting_sc(
    confidence_lists: List[List[float]],
    correct: List[bool],
    method: str = "borda"  # "borda", "plurality", "median"
) -> float:
```

---

## Migration from v7.4 to v7.5

### Breaking Changes
**None** — v7.5 is backward compatible with v7.4

### Behavioral Changes

1. **Min-K%++ CI**: Now reports CI for `mean_min_k_score` instead of transformed `confidence_score`
   - Old: CI was arbitrarily scaled by factor 0.1
   - New: CI directly represents metric uncertainty

### Recommended Actions

1. Review any code that relied on the old CI transformation
2. Update documentation to reflect new CI interpretation
3. Consider using BCa bootstrap for more accurate CIs (new function available)

---

## Verification

```python
# Test Min-K%++ CI fix
from kaggle.eval.scientific_metrics_v7 import detect_contamination_mink_pp_v7

# Sample data
token_log_probs = [
    [-0.1, -0.2, -0.3, -8.0, -9.0],  # Low contamination
    [-0.1, -0.2, -0.3, -4.0, -5.0],  # Higher contamination
]
vocab_size = 50000

result = detect_contamination_mink_pp_v7(token_log_probs, vocab_size)
print(f"Mean Min-K Score: {result.mean_min_k_score:.3f}")
print(f"CI: [{result.ci_lower:.3f}, {result.ci_upper:.3f}]")
# CI now directly represents the metric uncertainty
```

---

## References

1. **BCa Bootstrap**: Efron (1987), "Better Bootstrap Confidence Intervals"
2. **Brier Score**: Brier (1950), "Verification of Weather Forecasts"
3. **Min-K%++**: arXiv:2404.02936 — "Theoretical Analysis of Min-K% Probabilities"

---

## Changelog

### v7.5 (2026-03-26)
- **FIXED**: Arbitrary CI conversion in Min-K%++ (now reports actual metric CI)
- **ADDED**: BCa bootstrap CI function
- **ADDED**: Brier score function
- **ADDED**: Ranked voting self-consistency function

### Previous Versions
- **v7.4**: Fixed CI index calculation with floor/ceil
- **v7.3**: Added True DeLong CI with placement values
- **v7.2**: Fixed Full-ECE to include all probabilities, removed Min-K%++ mean normalization
- **v7.1**: Fixed Full-ECE probability-weighted bug, fixed CoDeC p-value conversion

---

**Document Version**: 1.0
**Last Updated**: 2026-03-26
**Author**: Dmitrii Vasilev
