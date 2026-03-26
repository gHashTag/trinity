# Statistical Analysis Guide for AGI Evaluation Metrics

**Date**: 2026-03-26
**Version**: 1.0
**Author**: Dmitrii Vasilev

---

## Overview

This guide provides **scientifically rigorous** statistical analysis methods for evaluating AGI systems, covering:

1. **Confidence Intervals** — BCa Bootstrap, DeLong, Wald
2. **Hypothesis Testing** — Parametric, Non-parametric, Permutation
3. **Effect Sizes** — Cohen's d, Cliff's Delta, Rank-Biserial
4. **Multiple Testing** — Bonferroni, Benjamini-Hochberg, Storey's q
5. **Power Analysis** — Sample size determination
6. **Bayesian Methods** — Credible intervals, Bayes factors

---

## 1. Confidence Intervals

### 1.1 BCa Bootstrap (Recommended)

**Reference**: Efron (1987), "Better Bootstrap Confidence Intervals"

**When to use**:
- Non-normal distributions
- Small sample sizes (n < 30)
- Unknown sampling distribution

**Implementation**:
```python
import numpy as np
from scipy.stats import norm
from typing import List, Tuple

def bca_ci(
    values: List[float],
    alpha: float = 0.05,
    n_bootstrap: int = 10000,
    seed: int = 42
) -> Tuple[float, float, float]:
    """
    Bias-Corrected and Accelerated bootstrap CI.

    Returns: (point_estimate, ci_lower, ci_upper)
    """
    rng = np.random.default_rng(seed)
    values = np.array(values)
    n = len(values)

    # Point estimate
    theta_hat = np.mean(values)

    # Bootstrap distribution
    boot_means = np.zeros(n_bootstrap)
    for i in range(n_bootstrap):
        sample = rng.choice(values, size=n, replace=True)
        boot_means[i] = np.mean(sample)

    # Bias correction (z0)
    z0 = norm.ppf(np.mean(boot_means < theta_hat))

    # Acceleration factor (a) using jackknife
    theta_jack = np.zeros(n)
    for i in range(n):
        theta_jack[i] = np.mean(np.delete(values, i))

    theta_dot = np.mean(theta_jack)
    num = np.sum((theta_dot - theta_jack) ** 3)
    den = 6 * np.sum((theta_dot - theta_jack) ** 2) + 1e-10
    a = num / den

    # Adjusted percentiles
    def adjust(z):
        return norm.cdf(z0 + (z0 + z) / (1 - a * (z0 + z)))

    z_alpha = norm.ppf(alpha / 2)
    z_1alpha = norm.ppf(1 - alpha / 2)

    alpha1 = adjust(z_alpha)
    alpha2 = adjust(z_1alpha)

    # CI bounds
    boot_means.sort()
    k1 = int(np.floor(alpha1 * n_bootstrap))
    k2 = int(np.ceil(alpha2 * n_bootstrap))

    ci_lower = boot_means[max(0, k1)]
    ci_upper = boot_means[min(n_bootstrap - 1, k2)]

    return float(theta_hat), float(ci_lower), float(ci_upper)
```

**Coverage**: ~95% (by design, asymptotically exact)

---

### 1.2 DeLong CI for AUC

**Reference**: DeLong et al. (1988), "Comparing the Areas under Two or More ROC Curves"

**When to use**:
- AUC comparison between models
- Correlated ROC curves

**Implementation**:
```python
from scipy.stats import norm
import numpy as np
from typing import List, Tuple

def delong_auc_ci(
    y_true: List[bool],
    y_scores: List[float],
    alpha: float = 0.05
) -> Tuple[float, float, float]:
    """
    DeLong confidence interval for AUC.

    Returns: (auc, ci_lower, ci_upper)
    """
    n = len(y_true)
    pos_idx = [i for i, y in enumerate(y_true) if y]
    neg_idx = [i for i, y in enumerate(y_true) if not y]

    n_pos = len(pos_idx)
    n_neg = len(n_idx)

    # Placement values
    phi_pos = np.zeros(n_pos)
    for i, idx in enumerate(pos_idx):
        phi_pos[i] = np.sum([y_scores[j] < y_scores[idx] for j in neg_idx]) / n_neg

    phi_neg = np.zeros(n_neg)
    for i, idx in enumerate(n_idx):
        phi_neg[i] = np.sum([y_scores[j] > y_scores[idx] for j in pos_idx]) / n_pos

    # AUC
    auc = np.mean(phi_pos)

    # Variance components
    S_pos = np.var(phi_pos, ddof=1)
    S_neg = np.var(phi_neg, ddof=1)

    # Standard error
    se = np.sqrt((S_pos / n_pos + S_neg / n_neg) / (n_pos * n_neg))

    # CI
    z = norm.ppf(1 - alpha / 2)
    ci_lower = max(0.0, auc - z * se)
    ci_upper = min(1.0, auc + z * se)

    return float(auc), float(ci_lower), float(ci_upper)
```

---

### 1.3 Wald CI (Large Sample)

**When to use**:
- Large samples (n > 100)
- Approximately normal distribution

```python
def wald_ci(
    values: List[float],
    alpha: float = 0.05
) -> Tuple[float, float, float]:
    """Wald confidence interval (asymptotic)."""
    import numpy as np
    from scipy.stats import norm

    values = np.array(values)
    n = len(values)

    point_est = np.mean(values)
    se = np.std(values, ddof=1) / np.sqrt(n)

    z = norm.ppf(1 - alpha / 2)
    ci_lower = point_est - z * se
    ci_upper = point_est + z * se

    return float(point_est), float(ci_lower), float(ci_upper)
```

---

## 2. Hypothesis Testing

### 2.1 Normality Tests

**Shapiro-Wilk** (recommended for n < 5000):
```python
from scipy.stats import shapiro

def test_normality(values: List[float], alpha: float = 0.05) -> dict:
    """
    Test for normality using Shapiro-Wilk.

    Returns: {'is_normal': bool, 'p_value': float, 'statistic': float}
    """
    if 3 <= len(values) <= 5000:
        stat, p_value = shapiro(values)
        return {
            'is_normal': p_value > alpha,
            'p_value': float(p_value),
            'statistic': float(stat)
        }
    else:
        # Sample too large for Shapiro-Wilk
        return {'is_normal': None, 'reason': 'sample out of range'}
```

**Kolmogorov-Smirnov** (for n > 5000):
```python
from scipy.stats import kstest

def test_normality_ks(values: List[float], alpha: float = 0.05) -> dict:
    """Test for normality using KS test."""
    import numpy as np
    from scipy.stats import norm

    values = np.array(values)
    standardized = (values - np.mean(values)) / np.std(values)

    stat, p_value = kstest(standardized, norm.cdf)
    return {
        'is_normal': p_value > alpha,
        'p_value': float(p_value),
        'statistic': float(stat)
    }
```

---

### 2.2 Two-Sample Tests

**Mann-Whitney U** (non-parametric):
```python
from scipy.stats import mannwhitneyu

def test_difference(
    values_a: List[float],
    values_b: List[float],
    alpha: float = 0.05
) -> dict:
    """
    Test if two samples differ (Mann-Whitney U).

    Returns: {'significant': bool, 'p_value': float, 'statistic': float}
    """
    stat, p_value = mannwhitneyu(values_a, values_b, alternative='two-sided')

    return {
        'significant': p_value < alpha,
        'p_value': float(p_value),
        'statistic': float(stat),
        'test': 'Mann-Whitney U'
    }
```

**Paired t-test** (for related samples):
```python
from scipy.stats import ttest_rel

def test_paired_difference(
    before: List[float],
    after: List[float],
    alpha: float = 0.05
) -> dict:
    """
    Test if paired samples differ.

    Returns: {'significant': bool, 'p_value': float, 'statistic': float}
    """
    stat, p_value = ttest_rel(before, after)

    return {
        'significant': p_value < alpha,
        'p_value': float(p_value),
        'statistic': float(stat),
        'test': 'Paired t-test'
    }
```

---

### 2.3 Permutation Tests

**For arbitrary statistics**:
```python
def permutation_test(
    values_a: List[float],
    values_b: List[float],
    n_permutations: int = 10000,
    seed: int = 42,
    alpha: float = 0.05
) -> dict:
    """
    Permutation test for difference in means.

    Distribution-free, exact test.
    """
    import numpy as np

    rng = np.random.default_rng(seed)
    values_a = np.array(values_a)
    values_b = np.array(values_b)

    # Observed difference
    obs_diff = np.mean(values_a) - np.mean(values_b)

    # Combined sample
    combined = np.concatenate([values_a, values_b])
    n_a = len(values_a)

    # Permutation distribution
    perm_diffs = np.zeros(n_permutations)
    for i in range(n_permutations):
        perm = rng.permutation(combined)
        perm_a = perm[:n_a]
        perm_b = perm[n_a:]
        perm_diffs[i] = np.mean(perm_a) - np.mean(perm_b)

    # Two-tailed p-value
    p_value = np.mean(np.abs(perm_diffs) >= np.abs(obs_diff))

    return {
        'significant': p_value < alpha,
        'p_value': float(p_value),
        'observed_difference': float(obs_diff),
        'test': 'Permutation test'
    }
```

---

## 3. Effect Sizes

### 3.1 Cohen's d (Standardized Mean Difference)

**Reference**: Cohen (1988), "Statistical Power Analysis for the Behavioral Sciences"

```python
def cohens_d(
    values_a: List[float],
    values_b: List[float]
) -> float:
    """
    Cohen's d effect size.

    Interpretation:
    - Small: 0.2
    - Medium: 0.5
    - Large: 0.8
    """
    import numpy as np

    values_a = np.array(values_a)
    values_b = np.array(values_b)

    n_a, n_b = len(values_a), len(values_b)
    mean_diff = np.mean(values_a) - np.mean(values_b)

    # Pooled standard deviation
    var_a = np.var(values_a, ddof=1)
    var_b = np.var(values_b, ddof=1)
    pooled_sd = np.sqrt(((n_a - 1) * var_a + (n_b - 1) * var_b) / (n_a + n_b - 2))

    return float(mean_diff / pooled_sd)

def interpret_d(d: float) -> str:
    """Interpret Cohen's d."""
    abs_d = abs(d)
    if abs_d < 0.2:
        return "negligible"
    elif abs_d < 0.5:
        return "small"
    elif abs_d < 0.8:
        return "medium"
    else:
        return "large"
```

---

### 3.2 Cliff's Delta (Non-parametric)

**Reference**: Cliff (1993), "Dominance Statistics"

```python
def cliffs_delta(
    values_a: List[float],
    values_b: List[float]
) -> float:
    """
    Cliff's Delta effect size (non-parametric).

    Range: [-1, 1]
    - 0: no effect
    - |d| > 0.147: small
    - |d| > 0.33: medium
    - |d| > 0.474: large
    """
    import numpy as np

    values_a = np.array(values_a)
    values_b = np.array(values_b)

    n_a, n_b = len(values_a), len(values_b)

    # Count dominance
    greater = 0
    less = 0

    for a in values_a:
        for b in values_b:
            if a > b:
                greater += 1
            elif a < b:
                less += 1

    # Cliff's Delta
    total = n_a * n_b
    delta = (greater - less) / total

    return float(delta)
```

---

## 4. Multiple Testing Correction

### 4.1 Bonferroni (Conservative)

```python
def bonferroni_correction(
    p_values: List[float],
    alpha: float = 0.05
) -> List[bool]:
    """
    Bonferroni correction for multiple testing.

    Controls Family-Wise Error Rate (FWER).
    """
    n = len(p_values)
    adjusted_alpha = alpha / n

    return [p < adjusted_alpha for p in p_values]
```

---

### 4.2 Benjamini-Hochberg (FDR)

**Reference**: Benjamini & Hochberg (1995)

```python
def benjamini_hochberg(
    p_values: List[float],
    q_level: float = 0.05
) -> List[bool]:
    """
    Benjamini-Hochberg FDR correction.

    Controls False Discovery Rate.
    """
    import numpy as np

    n = len(p_values)
    sorted_idx = sorted(range(n), key=lambda i: p_values[i])
    sorted_p = [p_values[i] for i in sorted_idx]

    # Find largest k where p_k <= (k/n) * q
    k = 0
    for i, p in enumerate(sorted_p):
        if p <= (i + 1) / n * q_level:
            k = i + 1

    # Mark rejected
    rejected = [False] * n
    for i in sorted_idx[:k]:
        rejected[i] = True

    return rejected
```

---

### 4.3 Storey's q-value

**Reference**: Storey (2003), "The positive false discovery rate"

```python
def storey_q_values(
    p_values: List[float],
    pi0_est: float = None,
    lambda_: float = 0.5
) -> List[float]:
    """
    Compute q-values (FDR-adjusted p-values).

    Returns: List of q-values (same order as input)
    """
    import numpy as np

    p_values = np.array(p_values)
    n = len(p_values)

    # Estimate pi0 (proportion of true nulls)
    if pi0_est is None:
        pi0_est = min(1.0, np.sum(p_values > lambda_) / (n * (1 - lambda_)))

    # Sort p-values
    sorted_idx = np.argsort(p_values)
    sorted_p = p_values[sorted_idx]

    # Compute q-values
    q_values = np.zeros(n)
    q_values[-1] = sorted_p[-1] * pi0_est

    for i in range(n - 2, -1, -1):
        q_values[i] = min(
            sorted_p[i] * pi0_est * n / (i + 1),
            q_values[i + 1]
        )

    # Unsort
    unsorted_q = np.zeros(n)
    for i, idx in enumerate(sorted_idx):
        unsorted_q[idx] = q_values[i]

    return unsorted_q.tolist()
```

---

## 5. Power Analysis

### 5.1 Sample Size for t-test

```python
def sample_size_t_test(
    effect_size: float,
    alpha: float = 0.05,
    power: float = 0.80,
    ratio: float = 1.0
) -> int:
    """
    Required sample size for two-sample t-test.

    Uses Cohen's d effect size.
    """
    from scipy.stats import norm
    import numpy as np

    z_alpha = norm.ppf(1 - alpha / 2)
    z_beta = norm.ppf(power)

    # Sample size formula
    n_per_group = 2 * ((z_alpha + z_beta) / effect_size) ** 2

    # Adjust for unequal groups
    n_total = int(np.ceil(n_per_group * (1 + ratio) ** 2 / (4 * ratio)))

    return n_total
```

---

### 5.2 Power for AUC comparison

```python
def power_auc_comparison(
    auc_a: float,
    auc_b: float,
    n_pos: int,
    n_neg: int,
    alpha: float = 0.05
) -> float:
    """
    Statistical power for comparing two AUCs.

    Returns: Power (1 - beta)
    """
    from scipy.stats import norm

    # Effect size (difference in AUCs)
    delta = abs(auc_a - auc_b)

    # Variance under H1 (simplified)
    var_a = auc_a * (1 - auc_a)
    var_b = auc_b * (1 - auc_b)
    pooled_var = (var_a + var_b) / 2

    se = np.sqrt(pooled_var * (1/n_pos + 1/n_neg))

    # Z-score
    z = delta / se - norm.ppf(1 - alpha / 2)

    # Power
    power = norm.cdf(z)

    return float(power)
```

---

## 6. Bayesian Methods

### 6.1 Bayesian Credible Interval

```python
def bayesian_ci(
    values: List[float],
    alpha: float = 0.05,
    prior_mean: float = 0.0,
    prior_var: float = 1.0
) -> Tuple[float, float, float]:
    """
    Bayesian credible interval with conjugate prior.

    Assumes normal likelihood with known variance.
    """
    import numpy as np
    from scipy.stats import norm

    values = np.array(values)
    n = len(values)

    # Posterior parameters (conjugate normal-normal)
    sample_mean = np.mean(values)
    sample_var = np.var(values, ddof=1)

    posterior_var = 1 / (1/prior_var + n/sample_var)
    posterior_mean = posterior_var * (prior_mean/prior_var + n * sample_mean / sample_var)

    # Credible interval
    posterior_sd = np.sqrt(posterior_var)
    z = norm.ppf(1 - alpha / 2)

    ci_lower = posterior_mean - z * posterior_sd
    ci_upper = posterior_mean + z * posterior_sd

    return float(posterior_mean), float(ci_lower), float(ci_upper)
```

---

### 6.2 Bayes Factor

```python
def bayes_factor_t_test(
    values_a: List[float],
    values_b: List[float],
    prior_scale: float = 0.707  # Cauchy prior scale
) -> float:
    """
    Bayes factor for two-sample t-test.

    BF > 1: Evidence for H1 (difference exists)
    BF < 1: Evidence for H0 (no difference)

    Interpretation (Kass & Raftery, 1995):
    - BF > 100: Decisive evidence for H1
    - 30-100: Very strong evidence
    - 10-30: Strong evidence
    - 3-10: Moderate evidence
    - 1-3: Weak evidence
    - BF < 1: Evidence for H0
    """
    import numpy as np
    from scipy.stats import t

    values_a = np.array(values_a)
    values_b = np.array(values_b)

    n_a, n_b = len(values_a), len(values_b)
    pooled_var = ((n_a - 1) * np.var(values_a, ddof=1) +
                   (n_b - 1) * np.var(values_b, ddof=1)) / (n_a + n_b - 2)

    # t-statistic
    t_stat = (np.mean(values_a) - np.mean(values_b)) / np.sqrt(pooled_var * (1/n_a + 1/n_b))

    # Degrees of freedom
    df = n_a + n_b - 2

    # Bayes factor (approximation using BIC)
    n = n_a + n_b
    bf_01 = np.sqrt(1 + t_stat**2 / df) * np.exp(-t_stat**2 / (2 * df))

    return float(1 / bf_01)  # BF_10
```

---

## 7. Complete Analysis Pipeline

```python
from dataclasses import dataclass
from typing import List, Dict, Any, Optional

@dataclass
class StatisticalReport:
    """Complete statistical analysis report."""

    # Point estimates
    mean: float
    median: float
    std: float

    # Confidence interval
    ci_lower: float
    ci_upper: float
    ci_method: str

    # Hypothesis test
    p_value: Optional[float] = None
    significant: Optional[bool] = None

    # Effect size
    effect_size: Optional[float] = None
    effect_interpretation: Optional[str] = None

    # Normality
    is_normal: Optional[bool] = None

    # Sample size
    n: int = 0

    # Power (if applicable)
    power: Optional[float] = None

    def to_dict(self) -> Dict[str, Any]:
        """Convert to dictionary."""
        return {
            'mean': self.mean,
            'median': self.median,
            'std': self.std,
            'ci': [self.ci_lower, self.ci_upper],
            'ci_method': self.ci_method,
            'p_value': self.p_value,
            'significant': self.significant,
            'effect_size': self.effect_size,
            'effect_interpretation': self.effect_interpretation,
            'is_normal': self.is_normal,
            'n': self.n,
            'power': self.power
        }

def complete_statistical_analysis(
    values: List[float],
    reference: Optional[List[float]] = None,
    alpha: float = 0.05
) -> StatisticalReport:
    """
    Complete statistical analysis of a sample.

    Args:
        values: Sample to analyze
        reference: Optional reference sample for comparison
        alpha: Significance level

    Returns:
        StatisticalReport with all analyses
    """
    import numpy as np
    from .bootstrap import bca_ci
    from .normality import test_normality
    from .effect_size import cohens_d, interpret_d

    values = np.array(values)
    n = len(values)

    # Descriptive statistics
    mean = float(np.mean(values))
    median = float(np.median(values))
    std = float(np.std(values, ddof=1))

    # Confidence interval (BCa bootstrap)
    _, ci_lower, ci_upper = bca_ci(values.tolist(), alpha=alpha)

    # Normality test
    normality_result = test_normality(values.tolist(), alpha=alpha)
    is_normal = normality_result.get('is_normal')

    # Comparison if reference provided
    p_value = None
    significant = None
    effect_size = None
    effect_interpretation = None

    if reference is not None:
        # Two-sample test
        if is_normal and len(reference) > 30:
            from scipy.stats import ttest_ind
            stat, p_value = ttest_ind(values, reference)
        else:
            from scipy.stats import mannwhitneyu
            stat, p_value = mannwhitneyu(values, reference)

        significant = p_value < alpha

        # Effect size
        d = cohens_d(values.tolist(), reference)
        effect_size = d
        effect_interpretation = interpret_d(d)

    return StatisticalReport(
        mean=mean,
        median=median,
        std=std,
        ci_lower=ci_lower,
        ci_upper=ci_upper,
        ci_method="BCa bootstrap",
        p_value=float(p_value) if p_value is not None else None,
        significant=significant,
        effect_size=effect_size,
        effect_interpretation=effect_interpretation,
        is_normal=is_normal,
        n=n
    )
```

---

## References

1. **Efron, B.** (1987). Better Bootstrap Confidence Intervals. *JASA*, 82(397), 171-185.
2. **DeLong, V. R., et al.** (1988). Comparing the Areas under Two or More ROC Curves. *Biometrics*, 44(3), 837-845.
3. **Cohen, J.** (1988). *Statistical Power Analysis for the Behavioral Sciences* (2nd ed.). Lawrence Erlbaum.
4. **Benjamini, Y., & Hochberg, Y.** (1995). Controlling the False Discovery Rate. *JRSS-B*, 57(1), 289-300.
5. **Storey, J. D.** (2003). The Positive False Discovery Rate. *JASA*, 98(461), 1048-1061.
6. **Kass, R. E., & Raftery, A. E.** (1995). Bayes Factors. *JASA*, 90(430), 773-795.
7. **Cliff, N.** (1993). *Dominance Statistics: Ordinal Analyses to Answer Ordinal Questions*. Sage.

---

**Document Version**: 1.0
**Last Updated**: 2026-03-26
**Status**: Ready for Use
