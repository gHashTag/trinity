# Statistical Methods Quick Reference — AGI Evaluation 2026

**Author:** Dmitrii Vasilev
**Date:** 2026-03-26
**Version:** 1.0
**Purpose:** Quick reference for common statistical methods

---

## Calibration Metrics

### Expected Calibration Error (ECE)

```python
def ece(confidences, correct, n_bins=10):
    """
    ECE = Σ (n_i / n) * |acc_i - conf_i|

    Reference: Naeini et al. (2015), AAAI
    """
    bin_boundaries = np.linspace(0, 1, n_bins + 1)
    bin_accs = []
    bin_confs = []
    bin_counts = []

    for i in range(n_bins):
        mask = (confidences > bin_boundaries[i]) & (confidences <= bin_boundaries[i + 1])
        if mask.sum() > 0:
            bin_accs.append(correct[mask].mean())
            bin_confs.append(confidences[mask].mean())
            bin_counts.append(mask.sum())

    # Sample-weighted (CORRECT)
    weights = np.array(bin_counts) / sum(bin_counts)
    return np.sum(weights * np.abs(np.array(bin_accs) - np.array(bin_confs)))
```

### Brier Score

```python
def brier_score(confidences, correct):
    """
    BS = (1/N) * Σ(f_i - y_i)²

    Reference: Brier (1950), Monthly Weather Review
    """
    return np.mean((confidences - correct) ** 2)
```

---

## Confidence Intervals

### Bootstrap CI (Percentile)

```python
def bootstrap_ci(data, stat_fn, n_boot=10000, ci=0.95):
    """Simple percentile bootstrap."""
    boot_stats = [stat_fn(np.random.choice(data, len(data), replace=True))
                  for _ in range(n_boot)]
    alpha = (1 - ci) / 2
    return np.percentile(boot_stats, [100*alpha, 100*(1-alpha)])
```

### BCa Bootstrap (Recommended)

```python
def bca_ci(data, stat_fn, n_boot=10000, ci=0.95):
    """
    Bias-corrected accelerated bootstrap.

    Reference: Efron (1987), JASA 82(397)
    """
    # Use implementation from STATISTICAL_COMPUTING_PATTERNS_2026.md
    ...
```

### DeLong AUC CI

```python
def delong_auc_ci(y_true, y_score, alpha=0.05):
    """
    DeLong confidence interval for AUC.

    Reference: DeLong et al. (1988), Biometrics 44(3)
    """
    # Use implementation from STATISTICAL_COMPUTING_PATTERNS_2026.md
    ...
```

---

## Multiple Testing Correction

### Bonferroni (Conservative)

```python
def bonferroni(p_values, alpha=0.05):
    """
    Controls FWER (family-wise error rate).

    Reference: Bonferroni (1936)
    """
    corrected_alpha = alpha / len(p_values)
    return [p < corrected_alpha for p in p_values]
```

### Benjamini-Hochberg FDR (Recommended)

```python
def benjamini_hochberg(p_values, alpha=0.05):
    """
    Controls FDR (less conservative than Bonferroni).

    Reference: Benjamini & Hochberg (1995), JRSS 57(1)
    """
    n = len(p_values)
    sorted_idx = np.argsort(p_values)
    sorted_p = np.array(p_values)[sorted_idx]

    # Find largest k where p_k <= k*alpha/n
    thresholds = (np.arange(n) + 1) * alpha / n
    significant = sorted_p <= thresholds
    if significant.any():
        max_k = np.where(significant)[0].max()
        threshold_p = sorted_p[max_k]
        return np.array(p_values) <= threshold_p
    return np.zeros(len(p_values), dtype=bool)
```

---

## Effect Sizes

### Cohen's d

```python
def cohens_d(sample1, sample2):
    """
    d = (m1 - m2) / SD_pooled

    Interpretation:
    - Small: 0.2
    - Medium: 0.5
    - Large: 0.8

    Reference: Cohen (1988)
    """
    n1, n2 = len(sample1), len(sample2)
    m1, m2 = np.mean(sample1), np.mean(sample2)
    var1, var2 = np.var(sample1, ddof=1), np.var(sample2, ddof=1)

    pooled_var = ((n1 - 1) * var1 + (n2 - 1) * var2) / (n1 + n2 - 2)
    return (m1 - m2) / np.sqrt(pooled_var)
```

### Cliff's Delta (Non-parametric)

```python
def cliffs_delta(sample1, sample2):
    """
    Ordinal effect size (robust to outliers).

    Reference: Cliff (1993), Psychol Bull 114(3)
    """
    n1, n2 = len(sample1), len(sample2)
    greater = sum(x > y for x in sample1 for y in sample2)
    less = sum(x < y for x in sample1 for y in sample2)
    return (greater - less) / (n1 * n2)
```

---

## Normality Tests

### Shapiro-Wilk

```python
from scipy.stats import shapiro

def test_normality(data, alpha=0.05):
    """
    H0: Data is normally distributed

    Reference: Shapiro & Wilk (1965), Biometrika 52(3-4)
    """
    stat, p_value = shapiro(data)
    return p_value > alpha, p_value  # (is_normal, p_value)
```

---

## Sample Size & Power

### t-test Sample Size

```python
def sample_size_t_test(effect_size, alpha=0.05, power=0.8):
    """
    Required sample size for two-sample t-test.

    Reference: Cohen (1988)
    """
    from scipy.stats import norm
    z_alpha = norm.ppf(1 - alpha / 2)
    z_beta = norm.ppf(power)
    n_per_group = 2 * ((z_alpha + z_beta) / effect_size) ** 2
    return int(np.ceil(n_per_group * 2))  # Total sample size
```

---

## Common Pitfalls

### ❌ Wrong: Probability-weighted ECE

```python
# WRONG: Weight by probability mass
bin_weight = bin_prob_sum / total_prob_sum
```

### ✅ Correct: Sample-weighted ECE

```python
# CORRECT: Weight by sample count
bin_weight = bin_count / total_samples
```

### ❌ Wrong: Arbitrary CI conversion

```python
# WRONG: Arbitrary factor 0.1
ci_lower = score - abs(ci_upper - mean) * 0.1
```

### ✅ Correct: Report actual CI

```python
# CORRECT: Use bootstrap CI directly
mean, ci_lower, ci_upper = bootstrap_ci(data, stat_fn)
```

---

## Quick Decision Tree

```
Need CI for mean?
├─ Small sample (n < 30): Use t-distribution CI
└─ Large sample (n >= 30): Use bootstrap CI (preferably BCa)

Need CI for AUC?
└─ Use DeLong CI

Comparing multiple metrics?
├─ Few tests (< 5): Use Bonferroni
├─ Many tests (>= 5): Use Benjamini-Hochberg FDR
└─ Tests correlated: Use Benjamini-Yekutieli

Testing normality?
├─ n < 5000: Use Shapiro-Wilk
└─ n >= 5000: Use Anderson-Darling

Effect size?
├─ Normal data: Use Cohen's d
└─ Non-normal/outliers: Use Cliff's Delta
```

---

## Reference Summary

| Method | Reference | Year | Journal |
|--------|-----------|------|---------|
| ECE | Naeini et al. | 2015 | AAAI |
| Brier Score | Brier | 1950 | Mon. Weather Rev. |
| BCa Bootstrap | Efron | 1987 | JASA 82(397) |
| DeLong CI | DeLong et al. | 1988 | Biometrics 44(3) |
| Bonferroni | Bonferroni | 1936 | - |
| BH-FDR | Benjamini & Hochberg | 1995 | JRSS 57(1) |
| Cohen's d | Cohen | 1988 | Erlbaum |
| Cliff's Delta | Cliff | 1993 | Psychol Bull 114(3) |
| Shapiro-Wilk | Shapiro & Wilk | 1965 | Biometrika 52(3-4) |

---

**φ² + 1/φ² = 3 | TRINITY**
