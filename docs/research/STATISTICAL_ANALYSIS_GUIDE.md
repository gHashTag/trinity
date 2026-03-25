# Statistical Analysis Guide for Trinity Publications

> **Version:** 1.0.0
> **Date:** 2026-03-26
> **Purpose:** Rigorous statistical methods for experimental validation

---

## Table of Contents

1. [Sample Size Determination](#1-sample-size-determination)
2. [Confidence Intervals](#2-confidence-intervals)
3. [Hypothesis Testing](#3-hypothesis-testing)
4. [Effect Size](#4-effect-size)
5. [Multiple Comparisons](#5-multiple-comparisons)
6. [Bayesian Methods](#6-bayesian-methods)
7. [Reporting Standards](#7-reporting-standards)

---

## 1. Sample Size Determination

### 1.1 Power Analysis

For comparing two methods (e.g., HSLM vs BitNet):

$$
n = \frac{2(z_{1-\alpha/2} + z_{1-\beta})^2 \sigma^2}{\Delta^2}
$$

Where:
- $n$ = samples per group
- $\alpha$ = Type I error rate (typically 0.05)
- $\beta$ = Type II error rate (power = $1-\beta$, typically 0.80)
- $\sigma$ = standard deviation (pilot estimate)
- $\Delta$ = minimum detectable effect

**Example:**

For PPL comparison with $\sigma = 5$, $\Delta = 10$:
$$
n = \frac{2(1.96 + 0.84)^2 \times 5^2}{10^2} = \frac{2 \times 7.84 \times 25}{100} = 3.92 \approx 4
$$

**Recommendation:** Minimum $n = 5$ runs per configuration.

### 1.2 Bootstrap Sample Size

For bootstrap confidence intervals:
$$
n_{boot} \geq \frac{1}{\alpha \cdot \epsilon}
$$

Where $\epsilon$ is desired precision.

For 95% CI ($\alpha = 0.05$) with $\epsilon = 0.01$:
$$
n_{boot} \geq \frac{1}{0.05 \times 0.01} = 2000
$$

**Recommendation:** Use $n_{boot} = 10000$ for stable CIs.

---

## 2. Confidence Intervals

### 2.1 Student's t-Interval (n < 30)

$$
\bar{x} \pm t_{n-1, 1-\alpha/2} \cdot \frac{s}{\sqrt{n}}
$$

**Implementation:**

```python
import numpy as np
from scipy import stats

def ci_t(values, confidence=0.95):
    """Compute t-confidence interval."""
    n = len(values)
    mean = np.mean(values)
    std = np.std(values, ddof=1)
    t_val = stats.t.ppf((1 + confidence) / 2, n - 1)
    margin = t_val * std / np.sqrt(n)
    return mean, mean - margin, mean + margin
```

### 2.2 Bootstrap Percentile Interval

```python
def ci_bootstrap(values, n_boot=10000, confidence=0.95, seed=42):
    """Compute bootstrap confidence interval."""
    rng = np.random.default_rng(seed)
    boot_means = []
    for _ in range(n_boot):
        sample = rng.choice(values, size=len(values), replace=True)
        boot_means.append(np.mean(sample))
    alpha = 1 - confidence
    return np.percentile(boot_means, [100*alpha/2, 100*(1-alpha/2)])
```

### 2.3 Reporting Format

**Correct:**
```
PPL: 125.3 ± 2.1 (95% CI: [123.2, 127.4]), n = 5
```

**Incorrect:**
```
PPL: 125.3 (no uncertainty reported)
```

---

## 3. Hypothesis Testing

### 3.1 Two-Sample t-Test

**Null hypothesis:** $H_0: \mu_1 = \mu_2$

**Test statistic:**
$$
t = \frac{\bar{x}_1 - \bar{x}_2}{s_p \sqrt{1/n_1 + 1/n_2}}
$$

where $s_p$ is pooled standard deviation.

**Implementation:**

```python
def two_sample_t_test(group1, group2):
    """Two-sample t-test with equal variance assumption."""
    n1, n2 = len(group1), len(group2)
    mean1, mean2 = np.mean(group1), np.mean(group2)
    var1, var2 = np.var(group1, ddof=1), np.var(group2, ddof=1)

    # Pooled variance
    sp = np.sqrt(((n1-1)*var1 + (n2-1)*var2) / (n1 + n2 - 2))
    se = sp * np.sqrt(1/n1 + 1/n2)

    t_stat = (mean1 - mean2) / se
    df = n1 + n2 - 2
    p_two_tailed = 2 * (1 - stats.t.cdf(abs(t_stat), df))

    return t_stat, df, p_two_tailed
```

**Example output:**
```
HSLM vs BitNet: t(8) = 5.23, p < 0.001 (two-tailed)
```

### 3.2 Paired t-Test

For comparing methods on same test set:

```python
def paired_t_test(group1, group2):
    """Paired t-test for matched samples."""
    differences = np.array(group1) - np.array(group2)
    n = len(differences)
    mean_diff = np.mean(differences)
    std_diff = np.std(differences, ddof=1)
    se = std_diff / np.sqrt(n)
    t_stat = mean_diff / se
    p_two_tailed = 2 * (1 - stats.t.cdf(abs(t_stat), n-1))
    return t_stat, n-1, p_two_tailed
```

### 3.3 Wilcoxon Rank-Sum (Non-parametric)

When normality assumption violated:

```python
def wilcoxon_test(group1, group2):
    """Wilcoxon rank-sum test (Mann-Whitney U)."""
    from scipy.stats import mannwhitneyu
    stat, p = mannwhitneyu(group1, group2, alternative='two-sided')
    return stat, p
```

---

## 4. Effect Size

### 4.1 Cohen's d

$$
d = \frac{\bar{x}_1 - \bar{x}_2}{s_{pooled}}
$$

**Interpretation:**
- $|d| < 0.2$: Small effect
- $0.2 \leq |d| < 0.8$: Medium effect
- $|d| \geq 0.8$: Large effect

```python
def cohens_d(group1, group2):
    """Compute Cohen's d effect size."""
    n1, n2 = len(group1), len(group2)
    var1, var2 = np.var(group1, ddof=1), np.var(group2, ddof=1)
    sp = np.sqrt(((n1-1)*var1 + (n2-1)*var2) / (n1 + n2 - 2))
    return (np.mean(group1) - np.mean(group2)) / sp
```

### 4.2 Pearson Correlation

$$
\rho = \frac{\sum(x_i - \bar{x})(y_i - \bar{y})}{\sqrt{\sum(x_i - \bar{x})^2 \sum(y_i - \bar{y})^2}}
$$

**Significance test:**
$$
t = \frac{r\sqrt{n-2}}{\sqrt{1-r^2}}
$$

```python
def pearson_correlation(x, y):
    """Pearson correlation with p-value."""
    r, p = stats.pearsonr(x, y)
    return r, p
```

**Reporting:**
```
Correlation between float and ternary attention: ρ = 0.983, p < 0.001
```

---

## 5. Multiple Comparisons

### 5.1 Bonferroni Correction

When testing $k$ hypotheses:
$$
\alpha_{corrected} = \frac{\alpha}{k}
$$

**Example:** For 5 ablation studies with $\alpha = 0.05$:
$$
\alpha_{corrected} = 0.05 / 5 = 0.01
$$

### 5.2 Holm-Bonferroni (Less Conservative)

1. Sort p-values: $p_1 \leq p_2 \leq ... \leq p_k$
2. For each $i$:
   - Reject if $p_i < \alpha / (k - i + 1)$
   - Stop at first non-rejection

```python
def holm_bonferroni(p_values, alpha=0.05):
    """Holm-Bonferroni correction for multiple comparisons."""
    k = len(p_values)
    sorted_idx = np.argsort(p_values)
    sorted_p = p_values[sorted_idx]

    reject = np.zeros(k, dtype=bool)
    for i, idx in enumerate(sorted_idx):
        threshold = alpha / (k - i)
        if sorted_p[i] < threshold:
            reject[idx] = True
        else:
            break

    return reject
```

---

## 6. Bayesian Methods

### 6.1 Bayesian t-Test

Using Bayes factor for model comparison:

$$
BF_{10} = \frac{P(\text{data} | H_1)}{P(\text{data} | H_0)}
$$

**Interpretation:**
- $BF_{10} > 10$: Strong evidence for $H_1$
- $1 < BF_{10} < 3$: Weak evidence for $H_1$
- $BF_{10} < 1$: Evidence for $H_0$

### 6.2 Credible Intervals

Bayesian alternative to confidence intervals:

```python
def bayesian_ci(values, confidence=0.95):
    """Compute Bayesian credible interval using percentiles."""
    alpha = 1 - confidence
    return np.percentile(values, [100*alpha/2, 100*(1-alpha/2)])
```

---

## 7. Reporting Standards

### 7.1 Results Table Template

```markdown
| Method | Mean | SD | 95% CI | n | vs Baseline |
|--------|------|-------|--------|---|-------------|
| Baseline | 120.0 | 5.2 | [115.2, 124.8] | 5 | — |
| Method A | 125.3 | 2.1 | [123.2, 127.4] | 5 | t(8) = 5.23, p < 0.001, d = 2.34 |
| Method B | 138.7 | 3.4 | [135.2, 142.2] | 5 | t(8) = 3.45, p = 0.008, d = 1.54 |
```

### 7.2 Text Reporting Template

```markdown
Our method (PPL: 125.3 ± 2.1, 95% CI: [123.2, 127.4], n = 5) significantly
outperformed the baseline (PPL: 138.7 ± 3.4, 95% CI: [135.2, 142.2], n = 5):
t(8) = 5.23, p < 0.001 (two-tailed), Cohen's d = 2.34 (large effect).
```

### 7.3 Figure Guidelines

**Error bars:** Must represent 95% CI or standard error

```python
import matplotlib.pyplot as plt
import numpy as np

methods = ['Baseline', 'Method A', 'Method B']
means = [120.0, 125.3, 138.7]
stds = [5.2, 2.1, 3.4]
n = 5

# 95% CI
ci = 1.96 * np.array(stds) / np.sqrt(n)

plt.bar(methods, means, yerr=ci, capsize=5, alpha=0.7)
plt.ylabel('Perplexity')
plt.title('Method Comparison with 95% Confidence Intervals')
plt.show()
```

---

## Appendix: Quick Reference

### Common Statistical Tests

| Test | Use Case | Assumptions |
|------|----------|-------------|
| One-sample t | Compare to known value | Normality |
| Two-sample t | Compare two groups | Normality, equal variance |
| Paired t | Same subjects, two conditions | Normality of differences |
| Wilcoxon rank-sum | Compare two groups (non-parametric) | None |
| ANOVA | Compare 3+ groups | Normality, equal variance |
| Kruskal-Wallis | Compare 3+ groups (non-parametric) | None |

### Effect Size Interpretation

| Metric | Small | Medium | Large |
|--------|-------|--------|-------|
| Cohen's d | 0.2 | 0.5 | 0.8 |
| Pearson r | 0.1 | 0.3 | 0.5 |
| R² | 0.01 | 0.09 | 0.25 |

### p-value Thresholds

| p-value | Interpretation |
|---------|----------------|
| p < 0.001 | Very strong evidence |
| p < 0.01 | Strong evidence |
| p < 0.05 | Moderate evidence |
| p ≥ 0.05 | Insufficient evidence |

---

**φ² + 1/φ² = 3 | TRINITY**
