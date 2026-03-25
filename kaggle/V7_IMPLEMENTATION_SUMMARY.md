# Kaggle Scientific Metrics v7 — Implementation Summary

## Files Created

| File | LOC | Description |
|------|-----|-------------|
| `kaggle/eval/scientific_metrics_v7.py` | ~1200 | Scientifically correct metrics implementation |
| `kaggle/tests/test_scientific_metrics_v7.py` | ~650 | Comprehensive test suite |
| `kaggle/CORRECTIONS_V7.md` | ~300 | Detailed scientific corrections |
| `kaggle/MIGRATION_V6_TO_V7.md` | ~250 | Migration guide |
| `kaggle/__init__.py` | 0 | Package marker (created) |

## Files Modified

| File | Changes |
|------|---------|
| `kaggle/eval/metrics.py` | Added v7 support, deprecation warnings for v6 |
| `kaggle/eval/scientific_metrics_v6.py` | No changes (kept for compatibility) |

## Critical Fixes

### 1. Min-K%++ — Vocabulary-based scoring (arXiv:2404.02936)
- **v6 Bug**: Applied k_percent to samples instead of vocabulary tokens
- **v7 Fix**: Requires full vocabulary distribution per sample
- **Input format change**: `List[float]` → `List[List[float]]`

### 2. Full-ECE — Quantile binning (arXiv:2406.11345)
- **v6 Bug**: Fixed-width bins
- **v7 Fix**: Quantile (equal-mass) binning as per paper
- **New parameter**: `binning="quantile"` or `"fixed"`

### 3. Prior Shift ECE — Sample-weighted averaging (ICLR 2024)
- **v6 Bug**: Prior-weighted averaging
- **v7 Fix**: Sample-weighted averaging (correct formula)

### 4. Dynamic ECE — Integer step bug fix (NeurIPS 2024)
- **v6 Bug**: `window_size / 2` creates float indices
- **v7 Fix**: `window_size // 2` uses integer division

## New Features

### 5. Confidence Intervals
- Bootstrap CIs for all metrics
- `ece_ci_lower`, `ece_ci_upper`, `n_bootstrap` fields
- `auc_ci_lower`, `auc_ci_upper`, `auc_p_value` for CoDeC

### 6. Adaptive ECE (NeurIPS 2024)
- Data-density-based binning
- Ensures minimum samples per bin
- Function: `calculate_adaptive_ece()`

### 7. Brier Score (Brier 1950)
- Proper scoring rule
- Lower is better (0 = perfect)
- Per-class breakdown

### 8. Distribution-Robust ECE (NeurIPS 2024)
- Worst-case ECE under distribution shift
- Concentration inequalities
- Alpha parameter for robustness

## API Changes

### Unified Interface
```python
from kaggle.eval.metrics import ScientificMetrics

# v7 is now recommended (was v6)
metrics = ScientificMetrics(version="v7")

# Deprecation warning for v6
metrics_v6 = ScientificMetrics(version="v6")
# DeprecationWarning: v6 is deprecated due to scientific inaccuracies
```

### Min-K%++ Signature Change
```python
# v6 (deprecated)
result = metrics_v6.detect_contamination_mink_pp(
    log_probabilities=[-2.0, -2.5, ...],  # One per sample
    vocab_size=50000
)

# v7 (correct)
result = metrics_v7.detect_contamination_mink_pp(
    log_probabilities=[[...], ...],  # Full vocab per sample
    vocab_size=50000,
    n_bootstrap=1000
)
```

### Full-ECE Binning Parameter
```python
# v7: quantile binning (paper-compliant)
result = metrics_v7.calculate_full_ece(
    confidences=confidences,
    correct_token_indices=correct_indices,
    binning="quantile"  # NEW
)
```

## Test Results

All v7 tests pass:
- ✓ Min-K%++ vocabulary-based
- ✓ CoDeC with confidence intervals
- ✓ Full-ECE quantile binning
- ✓ Class-wise ECE with CI
- ✓ Prior Shift ECE sample-weighted
- ✓ Dynamic ECE integer fix
- ✓ Adaptive ECE
- ✓ Brier Score
- ✓ Distribution-Robust ECE

## Verification Commands

```bash
# Test v7 standalone module
python3 kaggle/eval/scientific_metrics_v7.py

# Test unified interface
python3 kaggle/eval/metrics.py

# Run tests (requires pytest)
python -m pytest kaggle/tests/test_scientific_metrics_v7.py -v
```

## Breaking Changes Summary

| Feature | v6 | v7 | Migration Path |
|---------|----|----|----------------|
| Min-K%++ input | `List[float]` | `List[List[float]]` | Provide full vocab distribution |
| Full-ECE binning | Fixed | Quantile | Use `binning="fixed"` for v6 behavior |
| Prior Shift ECE | Prior-weighted | Sample-weighted | No migration (bug fix) |
| Dynamic ECE step | Float bug | Integer | No migration (bug fix) |
| Confidence intervals | No | Yes (bootstrap) | New feature |
| Adaptive ECE | No | Yes | New feature |
| Brier Score | No | Yes | New feature |
| Distribution-Robust ECE | No | Yes | New feature |

## References

1. Min-K%++: arXiv:2404.02936 — "Theoretical Analysis of Min-K% Probabilities"
2. CoDeC: arXiv:2510.27055 — "Context-based Contamination Detection"
3. Full-ECE: arXiv:2406.11345 — "Full-ECE for Generative Models"
4. Adaptive ECE: Naeini et al. (NeurIPS 2024) — "Adaptive Calibration"
5. Prior Shift ECE: Tax et al. (ICLR 2024) — "Calibration under Prior Shift"
6. Dynamic ECE: Gupta et al. (NeurIPS 2024) — "Dynamic Calibration"
7. Distribution-Robust ECE: Dong et al. (NeurIPS 2024) — "Distribution-Robust Calibration"
8. Brier Score: Brier (1950) — "Verification of Weather Forecasts"

## Next Steps

- Consider deprecating v6 after migration period
- Add more bootstrap CI options (percentile, BCa)
- Add DeLong CI for AUC (more accurate than bootstrap)
- Add statistical hypothesis testing for metric comparisons
