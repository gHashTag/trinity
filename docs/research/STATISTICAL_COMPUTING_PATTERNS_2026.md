# Advanced Statistical Computing Patterns — 2026 Best Practices

**Author:** Dmitrii Vasilev
**Date:** 2026-03-26
**Version:** 1.0
**License:** CC-BY-4.0

---

## Executive Summary

This guide presents **state-of-the-art** statistical computing patterns for 2026, covering:
- Numerical stability in probability calculations
- Confidence interval methods
- Multiple testing correction strategies
- Effect size computation and interpretation
- Sample size determination
- Statistical power analysis

---

## Part 1: Numerical Stability

### 1.1 Log-Sum-Exp Trick

**Problem:** Computing `log(exp(x) + exp(y))` directly causes overflow.

**Solution:**
```python
def log_sum_exp(log_probs: List[float]) -> float:
    """
    Numerically stable log-sum-exp computation.

    log(sum(exp(x_i))) = max_x + log(sum(exp(x_i - max_x)))

    Reference:
    McElreath, R. (2020). Statistical Rethinking.
    """
    if not log_probs:
        return float('-inf')

    max_log = max(log_probs)
    # Subtract max before exp to prevent overflow
    exp_sum = sum(math.exp(lp - max_log) for lp in log_probs)
    return max_log + math.log(exp_sum)
```

### 1.2 Log Probability Operations

```python
def log_sum_exp_pair(log_a: float, log_b: float) -> float:
    """Numerically stable log(exp(a) + exp(b))."""
    if log_a == float('-inf'):
        return log_b
    if log_b == float('-inf'):
        return log_a
    # Use the larger value as reference
    if log_a > log_b:
        return log_a + math.log1p(math.exp(log_b - log_a))
    else:
        return log_b + math.log1p(math.exp(log_a - log_b))

def log_subtract(log_a: float, log_b: float) -> float:
    """Numerically stable log(exp(a) - exp(b)), assuming a >= b."""
    if log_b == float('-inf'):
        return log_a
    if log_a <= log_b:
        raise ValueError("log_a must be greater than log_b")
    return log_a + math.log1p(-math.exp(log_b - log_a))
```

### 1.3 Softmax with Temperature

```python
def log_softmax(logits: List[float], temperature: float = 1.0) -> List[float]:
    """
    Numerically stable log-softmax with temperature scaling.

    Reference: Guo et al. (2017), "On Calibration of Modern Neural Networks"
    """
    if temperature == 0:
        raise ValueError("Temperature cannot be zero")

    scaled_logits = [l / temperature for l in logits]
    max_logit = max(scaled_logits)
    log_sum = max_logit + math.log(sum(math.exp(l - max_logit) for l in scaled_logits))
    return [l - log_sum for l in scaled_logits]
```

---

## Part 2: Confidence Intervals

### 2.1 Bootstrap CI Methods Comparison

| Method | Bias Correction | Skewness Adjusted | Best For |
|--------|----------------|-------------------|----------|
| Percentile | ❌ | ❌ | Quick estimates |
| BCa | ✅ | ✅ | General use (recommended) |
| ABC | ✅ | ✅ | Large samples |
| Studentized | ✅ | ✅ | When variance estimable |

### 2.2 BCa Bootstrap Implementation

```python
def bca_ci(
    data: List[float],
    statistic: Callable[[List[float]], float],
    alpha: float = 0.05,
    n_bootstrap: int = 10000,
    seed: Optional[int] = None
) -> Tuple[float, float, float]:
    """
    Bias-Corrected and Accelerated bootstrap CI.

    Reference: Efron (1987), "Better Bootstrap Confidence Intervals"
    JASA, 82(397), 171-185.

    Returns:
        (estimate, ci_lower, ci_upper)
    """
    if seed is not None:
        np.random.seed(seed)

    n = len(data)
    theta_hat = statistic(data)

    # Bootstrap samples
    boot_stats = []
    for _ in range(n_bootstrap):
        sample = np.random.choice(data, size=n, replace=True)
        boot_stats.append(statistic(sample))

    # Bias correction z0
    prop_less = np.mean(boot_stats < theta_hat)
    z0 = scipy.stats.norm.ppf(np.clip(prop_less, 1e-6, 1-1e-6))

    # Acceleration factor a (jackknife)
    jackknife = [
        statistic(np.delete(data, i))
        for i in range(n)
    ]
    theta_dot = np.mean(jackknife)

    numerator = np.sum((theta_dot - jackknife) ** 3)
    denominator = np.sum((theta_dot - jackknife) ** 2) ** 1.5
    a = numerator / (6 * denominator) if denominator > 0 else 0

    # Adjusted percentiles
    z_alpha = scipy.stats.norm.ppf(alpha / 2)
    z_1minus_alpha = scipy.stats.norm.ppf(1 - alpha / 2)

    def adjust(z):
        denom = 1 - a * (z0 + z)
        if abs(denom) < 1e-10:
            return 0.5
        z_adj = z0 + (z0 + z) / denom
        return scipy.stats.norm.cdf(z_adj)

    alpha1 = adjust(z_alpha)
    alpha2 = adjust(z_1minus_alpha)

    # Quantiles
    boot_stats_sorted = np.sort(boot_stats)
    ci_lower = np.quantile(boot_stats_sorted, np.clip(alpha1, 0, 1))
    ci_upper = np.quantile(boot_stats_sorted, np.clip(alpha2, 0, 1))

    return theta_hat, ci_lower, ci_upper
```

### 2.3 DeLong AUC CI

```python
def delong_auc_ci(
    y_true: List[bool],
    y_score: List[float],
    alpha: float = 0.05
) -> Tuple[float, float, float]:
    """
    DeLong confidence interval for AUC.

    Reference: DeLong et al. (1988), Biometrics, 44(3), 837-845.

    Returns:
        (auc, ci_lower, ci_upper)
    """
    # Separate scores by class
    pos_scores = [s for s, t in zip(y_score, y_true) if t]
    neg_scores = [s for s, t in zip(y_score, y_true) if not t]

    n_pos = len(pos_scores)
    n_neg = len(neg_scores)

    # Placement values: φ₁(X) = P(Y < X) for positive samples
    # φ₀(Y) = P(X > Y) for negative samples

    # Compute placement values
    phi1 = []
    for x in pos_scores:
        count = sum(1 for y in neg_scores if y < x) + 0.5 * sum(1 for y in neg_scores if y == x)
        phi1.append(count / n_neg)

    phi0 = []
    for y in neg_scores:
        count = sum(1 for x in pos_scores if x > y) + 0.5 * sum(1 for x in pos_scores if x == y)
        phi0.append(count / n_pos)

    # AUC = mean of placement values
    auc = (np.mean(phi1) * n_pos + np.mean(phi0) * n_neg) / (n_pos + n_neg)

    # Variance components
    s1_sq = np.var(phi1, ddof=1)
    s0_sq = np.var(phi0, ddof=1)

    # DeLong variance
    var_auc = (s1_sq / n_pos + s0_sq / n_neg) / (n_pos + n_neg)
    se_auc = math.sqrt(var_auc)

    # CI
    z = scipy.stats.norm.ppf(1 - alpha / 2)
    ci_lower = max(0.0, auc - z * se_auc)
    ci_upper = min(1.0, auc + z * se_auc)

    return auc, ci_lower, ci_upper
```

---

## Part 3: Multiple Testing Correction

### 3.1 Method Selection Guide

| Scenario | Recommended Method | Reason |
|----------|-------------------|---------|
| Few tests (< 10), independent | Bonferroni | Simple, exact FWER control |
| Many tests, independent | Benjamini-Hochberg | More power, FDR control |
| Tests correlated | Benjamini-Yekutieli | FDR under dependency |
| Hierarchical tests | Hierarchical FDR | Respects structure |
| Sequential testing | Alpha-spending | Preserves power |

### 3.2 Benjamini-Yekutieli (Under Dependency)

```python
def benjamini_yekutieli_fdr(
    p_values: List[float],
    alpha: float = 0.05
) -> List[bool]:
    """
    Benjamini-Yekutieli FDR correction.

    Controls FDR under arbitrary dependency.

    Reference: Benjamini & Yekutieli (2001), Ann. Stat., 29(4), 1165-1188.
    """
    if not p_values:
        return []

    n = len(p_values)
    sorted_with_idx = sorted(enumerate(p_values), key=lambda x: x[1])

    # Harmonic number correction
    c_n = sum(1.0 / i for i in range(1, n + 1))

    max_k = -1
    for k, (idx, p) in enumerate(sorted_with_idx):
        threshold = (k + 1) * alpha / (n * c_n)
        if p <= threshold:
            max_k = k

    if max_k >= 0:
        threshold_p = sorted_with_idx[max_k][1]
        return [p <= threshold_p for p in p_values]
    else:
        return [False] * n
```

### 3.3 Storey's q-value

```python
def q_values(p_values: List[float], pi0: Optional[float] = None) -> List[float]:
    """
    Compute q-values (FDR-adjusted p-values).

    Reference: Storey (2003), Ann. Stat., 31(6), 2013-2035.

    Args:
        p_values: List of p-values
        pi0: Estimated proportion of true nulls (None = estimate)

    Returns:
        List of q-values
    """
    if not p_values:
        return []

    m = len(p_values)
    sorted_with_idx = sorted(enumerate(p_values), key=lambda x: x[1])

    # Estimate pi0 if not provided
    if pi0 is None:
        # Use bootstrap method
        lambda_range = np.arange(0.05, 0.96, 0.01)
        pi0_estimates = []
        for lam in lambda_range:
            W_lam = sum(1 for p in p_values if p > lam)
            pi0_est = W_lam / (m * (1 - lam))
            pi0_estimates.append(min(pi0_est, 1.0))
        pi0 = min(pi0_estimates)

    # Compute q-values
    q_values = [1.0] * m
    for k, (idx, p) in enumerate(sorted_with_idx):
        # q-value = min_{j >= k} (pi0 * m * p_j) / (k + 1)
        rank = k + 1
        q = (pi0 * m * p) / rank
        q_values[idx] = min(1.0, q)

    # Monotonicity constraint
    sorted_with_idx = sorted(enumerate(q_values), key=lambda x: x[1])
    for k in range(1, m):
        idx, _ = sorted_with_idx[k]
        prev_idx, prev_q = sorted_with_idx[k - 1]
        q_values[idx] = max(q_values[idx], prev_q)

    return q_values
```

---

## Part 4: Effect Sizes

### 4.1 Cohen's d

```python
def cohens_d(
    sample1: List[float],
    sample2: List[float],
    pooled: bool = True
) -> Tuple[float, str]:
    """
    Cohen's d effect size.

    Interpretation (Cohen, 1988):
    - Small: 0.2
    - Medium: 0.5
    - Large: 0.8

    Returns:
        (d, interpretation)
    """
    n1, n2 = len(sample1), len(sample2)
    m1, m2 = np.mean(sample1), np.mean(sample2)
    var1, var2 = np.var(sample1, ddof=1), np.var(sample2, ddof=1)

    if pooled:
        # Pooled standard deviation
        pooled_var = ((n1 - 1) * var1 + (n2 - 1) * var2) / (n1 + n2 - 2)
        sd = math.sqrt(pooled_var)
    else:
        # Control group SD (Glass's delta)
        sd = math.sqrt(var2)

    if sd == 0:
        return 0.0, "undefined (zero variance)"

    d = (m1 - m2) / sd

    # Interpretation
    abs_d = abs(d)
    if abs_d < 0.2:
        interpretation = "negligible"
    elif abs_d < 0.5:
        interpretation = "small"
    elif abs_d < 0.8:
        interpretation = "medium"
    else:
        interpretation = "large"

    return d, interpretation
```

### 4.2 Cliff's Delta (Non-parametric)

```python
def cliffs_delta(
    sample1: List[float],
    sample2: List[float]
) -> Tuple[float, str]:
    """
    Cliff's Delta effect size (ordinal, non-parametric).

    Reference: Cliff (1993), Psych. Bull., 114(3), 510.

    Interpretation:
    - Negligible: |d| < 0.147
    - Small: 0.147 <= |d| < 0.33
    - Medium: 0.33 <= |d| < 0.474
    - Large: |d| >= 0.474

    Returns:
        (delta, interpretation)
    """
    n1, n2 = len(sample1), len(sample2)

    # Count dominance
    greater = 0
    less = 0

    for x in sample1:
        for y in sample2:
            if x > y:
                greater += 1
            elif x < y:
                less += 1

    # Cliff's delta
    delta = (greater - less) / (n1 * n2)

    # Interpretation
    abs_delta = abs(delta)
    if abs_delta < 0.147:
        interpretation = "negligible"
    elif abs_delta < 0.33:
        interpretation = "small"
    elif abs_delta < 0.474:
        interpretation = "medium"
    else:
        interpretation = "large"

    return delta, interpretation
```

---

## Part 5: Sample Size & Power Analysis

### 5.1 Two-Sample t-test Sample Size

```python
def sample_size_t_test(
    effect_size: float,
    alpha: float = 0.05,
    power: float = 0.80,
    ratio: float = 1.0,
    two_tailed: bool = True
) -> int:
    """
    Required sample size for two-sample t-test.

    Reference: Cohen (1988), Statistical Power Analysis.

    Args:
        effect_size: Cohen's d (0.2=small, 0.5=medium, 0.8=large)
        alpha: Significance level
        power: Desired power (1 - beta)
        ratio: n2/n1 ratio (1.0 = equal sizes)
        two_tailed: Two-tailed test

    Returns:
        Total sample size (n1 + n2)
    """
    from scipy.stats import norm

    z_alpha = norm.ppf(1 - alpha / (2 if two_tailed else 1))
    z_beta = norm.ppf(power)

    # Sample size per group
    n_per_group = 2 * ((z_alpha + z_beta) / effect_size) ** 2

    # Adjust for ratio
    n1 = math.ceil(n_per_group)
    n2 = math.ceil(n_per_group * ratio)

    return n1 + n2
```

### 5.2 Power Analysis for AUC

```python
def power_auc(
    auc0: float,
    auc1: float,
    n_pos: int,
    n_neg: int,
    alpha: float = 0.05
) -> float:
    """
    Statistical power for AUC comparison.

    Reference: Hanley & McNeil (1982), Radiology, 143(1), 97-104.

    Args:
        auc0: Null hypothesis AUC
        auc1: Alternative AUC
        n_pos: Number of positive samples
        n_neg: Number of negative samples
        alpha: Significance level

    Returns:
        Power (1 - beta)
    """
    from scipy.stats import norm

    # Variance components under H1
    Q1 = auc1 / (2 - auc1)
    Q2 = (2 * auc1 ** 2) / (1 + auc1)

    se_auc1 = math.sqrt(
        (Q1 * (1 - auc1) / (n_pos * (1 - auc1) ** 2) +
         (auc1 ** 2) * (1 - Q1) / (n_pos * auc1 ** 2) +
         Q2 * (1 - auc1) / (n_neg * (1 - auc1) ** 2) +
         (auc1 ** 2) * (1 - Q2) / (n_neg * auc1 ** 2))
    ) / 2

    # Z-score for effect
    z = (auc1 - auc0) / se_auc1

    # Critical value
    z_crit = norm.ppf(1 - alpha)

    # Power
    power = 1 - norm.cdf(z_crit - z)

    return power
```

---

## Part 6: Normality Testing

### 6.1 Shapiro-Wilk Test

```python
def shapiro_wilk_test(data: List[float], alpha: float = 0.05) -> Tuple[bool, float]:
    """
    Shapiro-Wilk test for normality.

    Reference: Shapiro & Wilk (1965), Biometrika, 52(3-4), 591-611.

    Returns:
        (is_normal, p_value)
    """
    from scipy.stats import shapiro

    if len(data) < 3:
        return False, 1.0

    if len(data) > 5000:
        warnings.warn("Shapiro-Wilk unreliable for n > 5000")

    statistic, p_value = shapiro(data)
    is_normal = p_value > alpha

    return is_normal, p_value
```

### 6.2 Anderson-Darling Test

```python
def anderson_darling_test(data: List[float]) -> Tuple[bool, float, str]:
    """
    Anderson-Darling test for normality.

    More sensitive to tails than K-S test.

    Returns:
        (is_normal, critical_value, significance_level)
    """
    from scipy.stats import anderson

    result = anderson(data)

    # Check against 5% significance level
    for i, (crit, sig) in enumerate(zip(result.critical_values, result.significance_level)):
        if sig == 5.0:
            is_normal = result.statistic < crit
            return is_normal, crit, f"{sig}%"

    return False, result.critical_values[0], "5%"
```

---

## Part 7: Best Practices Summary

### DO ✅

1. **Always use log-space** for probability calculations
2. **Use BCa bootstrap** for confidence intervals
3. **Correct for multiple testing** when evaluating multiple metrics
4. **Report effect sizes** alongside p-values
5. **Check normality** before using parametric tests
6. **Use exact p-values** (not just < 0.05)
7. **Report CIs** for all key estimates

### DON'T ❌

1. **Don't compute exp(log_prob)** directly without normalization
2. **Don't use simple percentile bootstrap** when BCa is available
3. **Don't ignore multiple testing** in evaluation campaigns
4. **Don't report p-values without effect sizes**
5. **Don't assume normality** without testing
6. **Don't use arbitrary thresholds** without justification
7. **Don't forget to check** numerical stability

---

## Part 8: Common Pitfalls

### Pitfall 1: Probability Overflow

```python
# ❌ WRONG - causes overflow
prob = sum(exp(lp) for lp in log_probs)

# ✅ CORRECT - log-sum-exp trick
log_prob = log_sum_exp(log_probs)
```

### Pitfall 2: Bootstrap CI Bias

```python
# ❌ WRONG - simple percentile is biased
ci_lower = np.percentile(boot_means, 2.5)
ci_upper = np.percentile(boot_means, 97.5)

# ✅ CORRECT - BCa accounts for bias and skewness
ci_lower, ci_upper = bca_ci(data, statistic)
```

### Pitfall 3: Multiple Testing

```python
# ❌ WRONG - no correction
for i, p_value in enumerate(p_values):
    if p_value < 0.05:
        print(f"Test {i} significant")

# ✅ CORRECT - FDR correction
from statsmodels.stats.multitest import multipletests
rejected, q_values, _, _ = multipletests(p_values, method='fdr_bh')
```

---

## References

1. Efron, B. (1987). Better Bootstrap Confidence Intervals. *JASA*, 82(397).
2. DeLong, E. R., et al. (1988). Comparing the AUCs of Correlated ROC Curves. *Biometrics*, 44(3).
3. Benjamini, Y., & Hochberg, Y. (1995). Controlling the FDR. *JRSS*, 57(1).
4. Benjamini, Y., & Yekutieli, D. (2001). FDR under Dependency. *Ann. Stat.*, 29(4).
5. Storey, J. D. (2003). The q-value. *Ann. Stat.*, 31(6).
6. Cohen, J. (1988). *Statistical Power Analysis* (2nd ed.). Lawrence Erlbaum.
7. Cliff, N. (1993). Dominance Statistics. *Psychol. Bull.*, 114(3).
8. Shapiro, S. S., & Wilk, M. B. (1965). An Analysis of Variance Test for Normality. *Biometrika*, 52(3-4).
9. Guo, C., et al. (2017). On Calibration of Modern Neural Networks. *ICML*.

---

**φ² + 1/φ² = 3 | TRINITY**
