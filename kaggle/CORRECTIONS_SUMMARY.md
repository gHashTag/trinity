# Kaggle Scientific Metrics — v4 Corrections Summary

## Status: ✅ COMPLETE

After reading the actual scientific papers (arXiv:2406.11345, arXiv:2404.02936, arXiv:2510.27055),
**critical scientific errors** were found in v3.3 implementations. All have been corrected.

---

## Corrections Made

### 1. Full-ECE (arXiv:2406.11345)

| Aspect | v3.3 (WRONG) | v4 (CORRECT) |
|--------|--------------|---------------|
| API | `correct: List[bool]` | `correct_token_indices: List[int]` |
| Token correctness | Boolean for entire sample | Index of correct token |
| Accuracy contribution | `prob if is_correct else 0` | `prob if token_idx == correct_idx else 0` |

**File:** `eval/scientific_metrics_v5.py`
**Function:** `calculate_full_ece_v4_correct()`

---

### 2. Min-K%++ (arXiv:2404.02936)

| Aspect | v3.3 (WRONG) | v4 (CORRECT) |
|--------|--------------|---------------|
| Input | Probabilities | **LOG probabilities** |
| Formula | "spread window" heuristic | `log p - µ` (Equation 3) |
| Score | density-based | deviation from mean |

**File:** `eval/scientific_metrics_v5.py`
**Function:** `detect_contamination_min_k_pp_v4_correct()`

---

### 3. CoDeC (arXiv:2510.27055)

| Aspect | v3.3 (WRONG) | v4 (CORRECT) |
|--------|--------------|---------------|
| Context | Single context | **BOTH seen + unseen** |
| AUC formula | `Φ(d/√2)` (invented!) | Dataset-level classification |
| 99.9% AUC | Per-sample estimate | Dataset-level seen/unseen |

**File:** `eval/scientific_metrics_v5.py`
**Functions:** `detect_contamination_codec_v4_correct()`, `detect_contamination_codec_v4_correct_simple()`

---

## Test Results

```
✅ tests/test_scientific_metrics_v4.py: 48 tests OK
✅ tests/test_scientific_metrics_v5.py: 35 tests OK
✅ tests/test_comparison_v3_vs_v4.py: 7 tests OK

Total: 90 tests passing
```

---

## Files Modified

| File | Change |
|------|--------|
| `eval/scientific_metrics_v5.py` | Added 3 corrected metric functions |
| `tests/test_scientific_metrics_v5.py` | Added 12 tests for corrected metrics |
| `tests/test_comparison_v3_vs_v4.py` | NEW: Comparison tests |
| `CORRECTIONS_V4.md` | NEW: Documentation of corrections |

---

## Migration Guide

### Full-ECE

```python
# Before (v3.3)
from eval.scientific_metrics_v4 import calculate_full_ece
ece = calculate_full_ece(prob_distributions, [True, False, True])

# After (v4)
from eval.scientific_metrics_v5 import calculate_full_ece_v4_correct
result = calculate_full_ece_v4_correct(prob_distributions, [0, 2, 1])
```

### Min-K%++

```python
# Before (v3.3)
from validate.codec import detect_contamination_min_k_pp
result = detect_contamination_min_k_pp(confidences)

# After (v4)
from eval.scientific_metrics_v5 import detect_contamination_min_k_pp_v4_correct
result = detect_contamination_min_k_pp_v4_correct(log_probabilities)
```

### CoDeC

```python
# Before (v3.3)
from validate.codec import detect_contamination_codec
result = detect_contamination_codec(model, test_samples, context_samples)

# After (v4)
from eval.scientific_metrics_v5 import detect_contamination_codec_v4_correct
result = detect_contamination_codec_v4_correct(
    model, test_samples,
    seen_context_samples,
    unseen_context_samples
)
```

---

## Key Insights

1. **Full-ECE**: Boolean correctness loses information. Must specify WHICH token is correct.

2. **Min-K%++**: Paper specifies log probabilities, not probabilities. The formula `log p - µ` is from Equation 3.

3. **CoDeC**: 99.9% AUC claim is for dataset-level classification, NOT per-sample formula.

---

## References

- arXiv:2406.11345 — "Full-ECE for Generative Models"
- arXiv:2404.02936 — "Theoretical Analysis of Min-K% Probabilities"
- arXiv:2510.27055 — "Context-based Contamination Detection"
