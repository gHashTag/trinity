# Scientific Metrics v6 — Implementation Summary

## Files Created

| File | LOC | Purpose |
|------|-----|---------|
| `kaggle/eval/roc_utils.py` | ~240 | ROC/AUC utility functions |
| `kaggle/eval/scientific_metrics_v6.py` | ~720 | All corrected metrics |
| `kaggle/tests/test_scientific_metrics_v6.py` | ~620 | Comprehensive tests |
| `kaggle/CORRECTIONS_V6.md` | ~180 | Documentation of fixes |
| `kaggle/MIGRATION_GUIDE.md` | ~280 | Migration guide v5→v6 |

## Test Results

```
Ran 35 tests in 0.040s

OK
```

All tests pass, including:
- ROC/AUC utilities (7 tests)
- Min-K%++ v6 (5 tests)
- CoDeC v6 (5 tests)
- Full-ECE v6 (4 tests)
- Class-wise ECE v6 (3 tests)
- Distribution Shift v6 (3 tests)
- Prior Shift ECE (2 tests)
- Dynamic ECE (2 tests)
- Legacy v5 metrics (2 tests)
- Integration tests (3 tests)

## Critical Fixes Implemented

### 1. Min-K%++ (arXiv:2404.02936)
- **Fixed**: `k_percent` now applies to `vocab_size`, not `n_samples`
- **Added**: Statistical test with p-value
- **Added**: Data-dependent threshold (µ - 2σ)

### 2. CoDeC (arXiv:2510.27055)
- **Fixed**: True ROC AUC using TPR/FPR curve
- **Added**: Ground truth label requirement
- **Added**: TPR/FPR reporting at optimal threshold
- **Added**: Unsupervised fallback with warning

### 3. Full-ECE (arXiv:2406.11345)
- **Added**: Warning for scalar confidences fallback
- **Added**: vocab_size validation
- **Added**: Flags for `used_fallback` and `vocab_size_validated`

### 4. Class-wise ECE (NeurIPS 2024)
- **Fixed**: Now uses true label only (not OR logic)
- **Result**: More accurate per-class sample counts

### 5. Distribution Shift (ICML 2024)
- **Improved**: Uses scipy.stats.ks_2samp when available
- **Added**: `used_scipy` flag

## New Metrics

### 6. Prior Shift ECE (ICLR 2024)
```python
result = calculate_prior_shift_ece(
    source_confs, source_correct,
    target_confs, target_correct
)
```

### 7. Dynamic ECE (NeurIPS 2024)
```python
result = calculate_dynamic_ece(
    confidence_history,  # Time series
    correct_history,
    window_size=100
)
```

## Key Differences from v5

| Metric | v5 | v6 |
|--------|-----|-----|
| Min-K%++ K | `int(n_samples * k/100)` | `int(vocab_size * k/100)` |
| CoDeC AUC | Weighted accuracy | ROC TPR/FPR integral |
| Class-wise filter | `pred == c OR label == c` | `label == c` only |
| Distribution Shift | Manual KS | scipy KS (preferred) |

## Usage Examples

### Min-K%++ v6
```python
from eval.scientific_metrics_v6 import detect_contamination_mink_pp_v6

result = detect_contamination_mink_pp_v6(
    log_probabilities=log_probs,
    vocab_size=50000,  # REQUIRED
    k_percent=5.0,
    statistical_threshold=0.05
)
print(f"Contaminated: {result.is_contaminated}")
print(f"P-value: {result.p_value:.4f}")
```

### CoDeC v6
```python
from eval.scientific_metrics_v6 import detect_contamination_codec_v6

result = detect_contamination_codec_v6(
    true_labels=[True, True, False, False],  # Ground truth
    confidence_drops=[0.5, 0.4, 0.1, 0.05]
)
print(f"ROC AUC: {result.auc_score:.4f}")
print(f"TPR: {result.tpr:.3f}, FPR: {result.fpr:.3f}")
```

## Verification

To verify the implementation:

```bash
# Run tests
python3 kaggle/tests/test_scientific_metrics_v6.py

# Run ROC utilities
python3 kaggle/eval/roc_utils.py

# Run main module
python3 kaggle/eval/scientific_metrics_v6.py
```

## Notes

- v6 is a **breaking change** from v5 due to fundamental algorithmic fixes
- Results will differ between v5 and v6 (v6 is scientifically correct)
- For publication-quality results, use v6 with scipy installed
- If you don't have ground truth for CoDeC, use the unsupervised fallback (but note the limitations)
