# Migration Guide: v5 → v6

This guide helps you migrate from Scientific Metrics v5 to v6.

## Quick Summary

| Change | Impact | Action Required |
|--------|--------|-----------------|
| Min-K%++ k_percent | High | Update function calls with `vocab_size` |
| CoDeC AUC | High | Provide ground truth labels |
| Full-ECE | Low | Handle new warnings |
| Class-wise ECE | Medium | Expect different per-class counts |
| Distribution Shift | Low | Install scipy for accuracy |

---

## Step-by-Step Migration

### 1. Update Imports

```python
# OLD (v5):
from eval.scientific_metrics_v5 import (
    detect_contamination_min_k_pp_v4_correct,
    detect_contamination_codec_v4_correct,
    calculate_full_ece_v4_correct,
    calculate_classwise_ece,
)

# NEW (v6):
from eval.scientific_metrics_v6 import (
    detect_contamination_mink_pp_v6,  # Note: name changed
    detect_contamination_codec_v6,
    calculate_full_ece_v6,
    calculate_classwise_ece_v6,
)
```

### 2. Min-K%++ Migration

**Critical Change:** `vocab_size` parameter is now **required**.

```python
# OLD (v5):
result = detect_contamination_min_k_pp_v4_correct(
    log_probabilities=log_probs,
    k_percent=5.0,
    threshold=0.0
)

# NEW (v6):
result = detect_contamination_mink_pp_v6(
    log_probabilities=log_probs,
    vocab_size=50000,  # REQUIRED: vocabulary size
    k_percent=5.0,
    statistical_threshold=0.05  # Renamed from threshold
)
```

**Key differences:**
- `vocab_size` is **required** (was implicit before)
- `threshold` → `statistical_threshold` (now a p-value threshold)
- Returns `p_value` and `z_statistic` for significance testing
- Data-dependent threshold: `µ - 2σ` instead of fixed 0.0

### 3. CoDeC Migration

**Critical Change:** Ground truth labels are **required** for proper AUC.

```python
# OLD (v5):
result = detect_contamination_codec_v4_correct_simple(
    confidences_without_context=base_confs,
    confidences_with_seen_context=seen_confs,
    confidences_with_unseen_context=unseen_confs,
    threshold=0.1
)
# Note: v5 self-assigned labels (inflated metrics!)

# NEW (v6) - SUPERVISED (recommended):
result = detect_contamination_codec_v6(
    true_labels=[True, True, False, False, ...],  # Ground truth!
    confidence_drops=[0.5, 0.4, 0.1, 0.05, ...]
)
# Returns TRUE ROC AUC with TPR/FPR

# NEW (v6) - UNSUPERVISED (fallback):
result = detect_contamination_codec_v6_unsupervised(
    confidences_without_context=base_confs,
    confidences_with_seen_context=seen_confs,
    confidences_with_unseen_context=unseen_confs,
    threshold=0.1
)
# Warning: Self-labeling inflates metrics!
```

**Key differences:**
- **Supervised version** requires ground truth labels
- Returns `tpr` and `fpr` at optimal threshold
- `auc_score` is TRUE ROC AUC (not weighted accuracy)
- Unsupervised fallback available (with warning)

### 4. Full-ECE Migration

**Minor Change:** New warnings and validation.

```python
# OLD (v5):
result = calculate_full_ece_v4_correct(
    confidences=probs,  # List[List[float]]
    correct_token_indices=indices,
    n_bins=10
)

# NEW (v6):
result = calculate_full_ece_v6(
    confidences=probs,
    correct_token_indices=indices,
    n_bins=10,
    vocab_size=50000  # Optional: for validation
)
```

**Key differences:**
- Warns if scalar confidences provided (fallback to standard ECE)
- Validates `correct_token_indices < vocab_size`
- Returns `used_fallback` and `vocab_size_validated` flags

### 5. Class-wise ECE Migration

**Medium Change:** Different per-class sample counts.

```python
# OLD (v5):
result = calculate_classwise_ece(
    confidences=confs,
    predictions=preds,
    labels=labels,
    n_classes=3
)
# v5: Used OR logic (pred == class OR label == class)

# NEW (v6):
result = calculate_classwise_ece_v6(
    confidences=confs,
    predictions=preds,
    labels=labels,
    n_classes=3
)
# v6: Uses true label only (label == class)
```

**Key differences:**
- Per-class counts may be **lower** (true label only, not OR)
- More aligned with Kumar et al. paper
- Macro ECE calculation unchanged

### 6. Distribution Shift Migration

**Minor Change:** scipy recommendation.

```python
# OLD (v5):
result = detect_distribution_shift(source_confs, target_confs)

# NEW (v6):
result = detect_distribution_shift_v6(source_confs, target_confs)
# Returns used_scipy flag
```

**Recommendation:** Install scipy for accurate KS test:

```bash
pip install scipy
```

---

## New Metrics (No Migration Needed)

### Prior Shift ECE

```python
from eval.scientific_metrics_v6 import calculate_prior_shift_ece

result = calculate_prior_shift_ece(
    source_confidences=train_confs,
    source_correct=train_correct,
    target_confidences=test_confs,
    target_correct=test_correct,
    source_prior=0.7,
    target_prior=0.3
)
```

### Dynamic ECE

```python
from eval.scientific_metrics_v6 import calculate_dynamic_ece

result = calculate_dynamic_ece(
    confidence_history=[[0.9, 0.8], [0.7, 0.6], ...],
    correct_history=[[True, True], [False, False], ...],
    window_size=100
)
```

---

## Breaking Changes Summary

### Must Update

1. **Min-K%++**: Add `vocab_size` parameter
2. **CoDeC**: Provide ground truth labels for proper AUC

### Should Update

3. **Class-wise ECE**: Expect different per-class counts
4. **Distribution Shift**: Install scipy

### Optional

5. **Full-ECE**: Handle new warnings
6. **New metrics**: Try Prior Shift ECE and Dynamic ECE

---

## Common Migration Patterns

### Pattern 1: Unknown vocab_size

If you don't know your vocabulary size:

```python
# Estimate from probability distribution shape
if isinstance(probs[0], list):
    vocab_size = len(probs[0])
else:
    vocab_size = 50000  # Common default for LLMs

result = detect_contamination_mink_pp_v6(log_probs, vocab_size)
```

### Pattern 2: No ground truth for CoDeC

If you don't have ground truth labels:

```python
# Use unsupervised fallback
result = detect_contamination_codec_v6_unsupervised(
    confidences_without_context=base,
    confidences_with_seen_context=seen,
    confidences_with_unseen_context=unseen
)
# Note: AUC may be inflated due to self-labeling
```

### Pattern 3: Backward Compatibility

For gradual migration:

```python
try:
    from eval.scientific_metrics_v6 import detect_contamination_mink_pp_v6
    # Use v6 with vocab_size
    result = detect_contamination_mink_pp_v6(log_probs, vocab_size=50000)
except ImportError:
    from eval.scientific_metrics_v5 import detect_contamination_min_k_pp_v4_correct
    # Fallback to v5
    result = detect_contamination_min_k_pp_v4_correct(log_probs)
```

---

## Testing Your Migration

Run the v6 test suite:

```bash
cd /path/to/trinity-w1
python -m pytest kaggle/tests/test_scientific_metrics_v6.py -v
```

Compare v5 vs v6 results:

```python
from eval.scientific_metrics_v5 import detect_contamination_min_k_pp_v4_correct
from eval.scientific_metrics_v6 import detect_contamination_mink_pp_v6

log_probs = [-2.0, -2.5, -3.0, -4.5, -5.0]

# v5
result_v5 = detect_contamination_min_k_pp_v4_correct(log_probs)
print(f"v5: contaminated={result_v5.is_contaminated}")

# v6
result_v6 = detect_contamination_mink_pp_v6(log_probs, vocab_size=50000)
print(f"v6: contaminated={result_v6.is_contaminated}, p_value={result_v6.p_value:.4f}")
```

---

## FAQ

**Q: Why is CoDeC v6 requiring ground truth labels?**

A: The paper (arXiv:2510.27055) uses ROC AUC which requires ground truth. The v5 self-labeling approach inflated metrics. If you don't have labels, use the unsupervised fallback (but results may be inflated).

**Q: What vocab_size should I use for Min-K%++?**

A: Use your model's vocabulary size:
- GPT-2: 50,257
- LLaMA: 32,000
- BERT: 30,000
- Custom: check `len(tokenizer.vocab)`

**Q: Will v5 results match v6 results?**

A: Not exactly. v6 fixes fundamental errors, so results will differ:
- Min-K%++: Different K calculation
- CoDeC: True ROC AUC vs weighted accuracy
- Class-wise ECE: Different sample selection

**Q: Can I keep using v5?**

A: v5 has known scientific inaccuracies. For publication-quality results, use v6.

---

## Checklist

- [ ] Update imports to use v6
- [ ] Add `vocab_size` to Min-K%++ calls
- [ ] Provide ground truth labels for CoDeC (or use unsupervised fallback)
- [ ] Install scipy: `pip install scipy`
- [ ] Run test suite: `pytest kaggle/tests/test_scientific_metrics_v6.py`
- [ ] Compare v5 vs v6 results on your data
- [ ] Update documentation/comments referencing old behavior
