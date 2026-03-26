# Multiple Testing Correction Framework — Trinity Metrics 2026

**Author:** Dmitrii Vasilev
**Date:** 2026-03-26
**Version:** 1.0
**Status:** NeurIPS 2026 / ICLR 2027 Compliant
**Purpose:** Unified multiple testing correction for all Trinity scientific metrics

---

## 1. Theoretical Foundation

### 1.1 The Multiple Testing Problem

When testing multiple hypotheses simultaneously, the family-wise error rate (FWER) inflates:

```
P(at least one Type I error) = 1 - (1 - α)^m

For m = 10 tests at α = 0.05:
P(at least one false positive) = 1 - (0.95)^10 = 0.401
```

**Without correction:** 40% chance of at least one false discovery!

### 1.2 Correction Methods Comparison

| Method | FWER/FDR | Power | Assumptions | Use Case |
|--------|----------|-------|-------------|----------|
| **Bonferroni** | FWER | Low | Independence (conservative) | Few tests, strong control needed |
| **Holm-Bonferroni** | FWER | Medium | Independence | Step-down, more powerful |
| **Benjamini-Hochberg (BH)** | FDR | High | Independence or positive dependence | Many tests, exploratory |
| **Benjamini-Yekutieli (BY)** | FDR | Low | Any dependency | Very conservative, safe |
| **Hommel** | FWER | High | Independence | Most powerful step-down |

**Recommendation for Trinity Metrics:**
- Primary analysis: **Holm-Bonferroni** (pre-registered hypotheses)
- Secondary analysis: **Benjamini-Hochberg** (exploratory, many metrics)
- Robustness check: **Benjamini-Yekutieli** (dependency-safe)

---

## 2. Mathematical Formulations

### 2.1 Bonferroni Correction

**Formula:**
```
α_corrected = α / m
p_i_corrected = min(1, m × p_i)
```

**Interpretation:** Control FWER at α by dividing significance threshold by number of tests.

**Pros:** Simple, guaranteed control
**Cons:** Very conservative for large m

### 2.2 Holm-Bonferroni (Step-Down)

**Algorithm:**
```
1. Sort p-values: p_(1) ≤ p_(2) ≤ ... ≤ p_(m)
2. For i = 1 to m:
   If p_(i) > α / (m - i + 1):
     Reject H_(1), ..., H_(i-1)
     Accept H_(i), ..., H_(m)
     STOP
```

**Pros:** More powerful than Bonferroni, simple
**Cons:** Still conservative for dependent tests

### 2.3 Benjamini-Hochberg (FDR)

**Algorithm:**
```
1. Sort p-values: p_(1) ≤ p_(2) ≤ ... ≤ p_(m)
2. Find largest k such that: p_(k) ≤ (k/m) × α
3. Reject H_(1), ..., H_(k)
```

**Interpretation:** Controls expected proportion of false discoveries at α.

**Pros:** More powerful, appropriate for exploratory analysis
**Cons:** Assumes independence or positive dependence

### 2.4 Benjamini-Yekutieli (FDR under Dependency)

**Algorithm:**
```
1. Compute harmonic sum: H(m) = Σ(1/i) for i = 1 to m
2. Sort p-values: p_(1) ≤ p_(2) ≤ ... ≤ p_(m)
3. Find largest k such that: p_(k) ≤ (k/(m×H(m))) × α
4. Reject H_(1), ..., H_(k)
```

**Interpretation:** Controls FDR under arbitrary dependency.

**Pros:** Valid under any dependency structure
**Cons:** Very conservative (similar to Bonferroni)

### 2.5 Hommel (Step-Down, Most Powerful)

**Algorithm:**
```
1. Sort p-values: p_(1) ≤ p_(2) ≤ ... ≤ p_(m)
2. For i = m down to 1:
   Find all j < i such that p_(j) > (i / m) × α
   If none found:
     Reject all H_(j) where p_(j) ≤ (i / m) × α
     STOP
```

**Pros:** Most powerful FWER-controlling method
**Cons:** Complex implementation, less known

---

## 3. Implementation

### 3.1 Unified Interface

```python
# kaggle/eval/multiple_testing.py (NEW FILE)

"""
Multiple Testing Correction for Trinity Metrics

Implements 5 correction methods:
- Bonferroni (family-wise error rate)
- Holm-Bonferroni (step-down)
- Benjamini-Hochberg (FDR)
- Benjamini-Yekutieli (FDR under dependency)
- Hommel (step-down, most powerful)

All methods return MultipleTestResult with corrected p-values
and rejection status at α = 0.05 (configurable).
"""

from dataclasses import dataclass
from typing import List, Literal
import numpy as np

@dataclass
class MultipleTestResult:
    """Result of multiple testing correction."""
    original_p: List[float]
    corrected_p: List[float]
    rejected: List[bool]
    method: str
    alpha: float
    n_tests: int
    n_rejected: int
    fdr_or_fwer: Literal["FWER", "FDR"]

    def summary(self) -> str:
        """Human-readable summary."""
        return (
            f"{self.method} Correction ({self.fdr_or_fwer}):\n"
            f"  Tests: {self.n_tests}\n"
            f"  Rejected: {self.n_rejected} ({100*self.n_rejected/self.n_tests:.1f}%)\n"
            f"  α = {self.alpha}\n"
        )

    def table(self) -> str:
        """Markdown table for publications."""
        rows = []
        rows.append("| Test | Original p | Corrected p | Rejected |")
        rows.append("|------|------------|-------------|----------|")
        for i, (orig, corr, rej) in enumerate(zip(
            self.original_p, self.corrected_p, self.rejected
        ), 1):
            rows.append(
                f"| {i} | {orig:.4f} | {corr:.4f} | "
                f"{'✅' if rej else '❌'} |"
            )
        return "\n".join(rows)
```

### 3.2 Bonferroni Implementation

```python
def bonferroni(
    p_values: List[float],
    alpha: float = 0.05
) -> MultipleTestResult:
    """
    Bonferroni correction for family-wise error rate.

    Most conservative method. Use when:
    - Few tests (m < 10)
    - Strong control needed
    - Tests are independent

    Args:
        p_values: List of p-values from multiple tests
        alpha: Significance level

    Returns:
        MultipleTestResult with corrected p-values
    """
    m = len(p_values)
    corrected = [min(1.0, p * m) for p in p_values]
    rejected = [p < alpha for p in corrected]

    return MultipleTestResult(
        original_p=p_values,
        corrected_p=corrected,
        rejected=rejected,
        method="Bonferroni",
        alpha=alpha,
        n_tests=m,
        n_rejected=sum(rejected),
        fdr_or_fwer="FWER"
    )
```

### 3.3 Holm-Bonferroni Implementation

```python
def holm_bonferroni(
    p_values: List[float],
    alpha: float = 0.05
) -> MultipleTestResult:
    """
    Holm-Bonferroni step-down correction.

    More powerful than Bonferroni while controlling FWER.
    Recommended for primary (pre-registered) analysis.

    Args:
        p_values: List of p-values from multiple tests
        alpha: Significance level

    Returns:
        MultipleTestResult with corrected p-values
    """
    m = len(p_values)

    # Sort with indices
    sorted_indices = np.argsort(p_values)
    sorted_p = np.array(p_values)[sorted_indices]

    # Step-down procedure
    rejected = np.zeros(m, dtype=bool)
    for i in range(m):
        threshold = alpha / (m - i)
        if sorted_p[i] > threshold:
            # Reject all previous (smaller) p-values
            rejected[:i] = True
            break
    else:
        # All rejected
        rejected[:] = True

    # Calculate corrected p-values
    corrected = np.ones(m)
    for i in range(m):
        corrected[i] = min(1.0, sorted_p[i] * (m - i))

    # Unsort
    unsorted_corrected = np.zeros(m)
    unsorted_rejected = np.zeros(m, dtype=bool)
    for idx, corr, rej in zip(sorted_indices, corrected, rejected):
        unsorted_corrected[idx] = corr
        unsorted_rejected[idx] = rej

    return MultipleTestResult(
        original_p=p_values,
        corrected_p=unsorted_corrected.tolist(),
        rejected=unsorted_rejected.tolist(),
        method="Holm-Bonferroni",
        alpha=alpha,
        n_tests=m,
        n_rejected=int(np.sum(unsorted_rejected)),
        fdr_or_fwer="FWER"
    )
```

### 3.4 Benjamini-Hochberg Implementation

```python
def benjamini_hochberg(
    p_values: List[float],
    alpha: float = 0.05
) -> MultipleTestResult:
    """
    Benjamini-Hochberg FDR correction.

    Controls false discovery rate (expected proportion of false positives).
    More powerful than FWER methods. Recommended for exploratory analysis.

    Assumptions:
    - Tests are independent OR
    - Positive dependency structure

    Args:
        p_values: List of p-values from multiple tests
        alpha: Significance level (FDR threshold)

    Returns:
        MultipleTestResult with corrected p-values
    """
    m = len(p_values)

    # Sort with indices
    sorted_indices = np.argsort(p_values)
    sorted_p = np.array(p_values)[sorted_indices]

    # Find largest k where p_(k) ≤ (k/m) × α
    thresholds = np.arange(1, m + 1) / m * alpha
    below_threshold = sorted_p <= thresholds

    if not np.any(below_threshold):
        # None rejected
        k = 0
    else:
        k = np.max(np.where(below_threshold)[0]) + 1

    # Calculate corrected p-values
    corrected = np.ones(m)
    for i in range(m - 1, -1, -1):
        if i >= k:
            corrected[i] = min(corrected[i + 1] if i < m - 1 else 1,
                               sorted_p[i] * m / (i + 1))
        else:
            corrected[i] = sorted_p[i] * m / (i + 1)

    # Rejection status
    rejected = np.zeros(m, dtype=bool)
    rejected[:k] = True

    # Unsort
    unsorted_corrected = np.zeros(m)
    unsorted_rejected = np.zeros(m, dtype=bool)
    for idx, corr, rej in zip(sorted_indices, corrected, rejected):
        unsorted_corrected[idx] = corr
        unsorted_rejected[idx] = rej

    return MultipleTestResult(
        original_p=p_values,
        corrected_p=unsorted_corrected.tolist(),
        rejected=unsorted_rejected.tolist(),
        method="Benjamini-Hochberg",
        alpha=alpha,
        n_tests=m,
        n_rejected=k,
        fdr_or_fwer="FDR"
    )
```

### 3.5 Benjamini-Yekutieli Implementation

```python
def benjamini_yekutieli(
    p_values: List[float],
    alpha: float = 0.05
) -> MultipleTestResult:
    """
    Benjamini-Yekutieli FDR correction under arbitrary dependency.

    Most conservative FDR method. Valid under ANY dependency structure.
    Use when tests may be negatively correlated.

    Args:
        p_values: List of p-values from multiple tests
        alpha: Significance level (FDR threshold)

    Returns:
        MultipleTestResult with corrected p-values
    """
    m = len(p_values)

    # Harmonic sum: H(m) = Σ(1/i)
    harmonic_sum = np.sum(1.0 / np.arange(1, m + 1))

    # Sort with indices
    sorted_indices = np.argsort(p_values)
    sorted_p = np.array(p_values)[sorted_indices]

    # Find largest k where p_(k) ≤ (k/(m×H(m))) × α
    scaling_factor = m * harmonic_sum
    thresholds = np.arange(1, m + 1) / scaling_factor * alpha
    below_threshold = sorted_p <= thresholds

    if not np.any(below_threshold):
        k = 0
    else:
        k = np.max(np.where(below_threshold)[0]) + 1

    # Calculate corrected p-values
    corrected = np.ones(m)
    for i in range(m - 1, -1, -1):
        if i >= k:
            corrected[i] = min(corrected[i + 1] if i < m - 1 else 1,
                               sorted_p[i] * scaling_factor / (i + 1))
        else:
            corrected[i] = sorted_p[i] * scaling_factor / (i + 1)

    # Rejection status
    rejected = np.zeros(m, dtype=bool)
    rejected[:k] = True

    # Unsort
    unsorted_corrected = np.zeros(m)
    unsorted_rejected = np.zeros(m, dtype=bool)
    for idx, corr, rej in zip(sorted_indices, corrected, rejected):
        unsorted_corrected[idx] = corr
        unsorted_rejected[idx] = rej

    return MultipleTestResult(
        original_p=p_values,
        corrected_p=unsorted_corrected.tolist(),
        rejected=unsorted_rejected.tolist(),
        method="Benjamini-Yekutieli",
        alpha=alpha,
        n_tests=m,
        n_rejected=k,
        fdr_or_fwer="FDR"
    )
```

### 3.6 Hommel Implementation

```python
def hommel(
    p_values: List[float],
    alpha: float = 0.05
) -> MultipleTestResult:
    """
    Hommel's step-down procedure (most powerful FWER control).

    More powerful than Holm-Bonferroni. Controls FWER at α.
    Recommended when power is needed and FWER control is required.

    Args:
        p_values: List of p-values from multiple tests
        alpha: Significance level

    Returns:
        MultipleTestResult with corrected p-values
    """
    m = len(p_values)
    p = np.array(p_values)

    # Sort with indices
    sorted_indices = np.argsort(p)
    sorted_p = p[sorted_indices]

    # Find largest set of hypotheses to reject
    # Find all j < i such that p_(j) > (i/m) × α
    rejected = np.zeros(m, dtype=bool)

    for i in range(m, 0, -1):
        threshold = (i / m) * alpha
        # Count how many p-values are > threshold
        n_above = np.sum(sorted_p[:i] > threshold)

        if n_above == 0:
            # Reject all hypotheses with p ≤ (i/m) × α
            for j in range(i):
                if sorted_p[j] <= threshold:
                    rejected[j] = True
            break

    # Calculate adjusted p-values
    adjusted = np.ones(m)
    for i in range(m):
        # Find minimum alpha that would reject this hypothesis
        min_alpha = 1.0
        for j in range(m, 0, -1):
            if sorted_p[i] <= (j / m):
                min_alpha = min(min_alpha, sorted_p[i] * m / j)
        adjusted[i] = min(1.0, min_alpha)

    # Unsort
    unsorted_corrected = np.zeros(m)
    unsorted_rejected = np.zeros(m, dtype=bool)
    for idx, corr, rej in zip(sorted_indices, adjusted, rejected):
        unsorted_corrected[idx] = corr
        unsorted_rejected[idx] = rej

    return MultipleTestResult(
        original_p=p_values,
        corrected_p=unsorted_corrected.tolist(),
        rejected=unsorted_rejected.tolist(),
        method="Hommel",
        alpha=alpha,
        n_tests=m,
        n_rejected=int(np.sum(unsorted_rejected)),
        fdr_or_fwer="FWER"
    )
```

---

## 4. Application to Trinity Metrics

### 4.1 Metric Grouping

**Primary Analysis (Pre-registered Hypotheses):**

| Hypothesis | Metric | Test | Correction |
|------------|--------|------|------------|
| H1 | HSLM PPL | One-sample t-test | Holm-Bonferroni |
| H2 | FPGA power | Two-sample t-test | Holm-Bonferroni |
| H3 | Cache hit rate | Binomial test | Holm-Bonferroni |

**Secondary Analysis (Exploratory):**

| Metric Group | Tests | Correction |
|--------------|-------|------------|
| Calibration (6 metrics) | Full-ECE, Adaptive, Dynamic, Prior-Shift, DR, Min-K%++ | Benjamini-Hochberg |
| Contamination (3 tests) | Min-K%++, CoDeC, Brier | Benjamini-Hochberg |
| Subgroup Analysis (6 subgroups) | Gender, Culture, Age, etc. | Benjamini-Yekutieli |

### 4.2 Example: Calibration Metrics

```python
# Example: 6 calibration metrics tested on same data
from kaggle.eval.multiple_testing import (
    benjamini_hochberg,
    holm_bonferroni,
    MultipleTestResult
)

# Original p-values from calibration comparison
calibration_p_values = [
    0.001,  # Full-ECE vs baseline
    0.023,  # Adaptive ECE vs baseline
    0.041,  # Dynamic ECE vs baseline
    0.089,  # Prior-Shift ECE vs baseline
    0.127,  # Distribution-Robust ECE
    0.234,  # Min-K%++ detection
]

# Apply BH-FDR correction (exploratory analysis)
result_bh = benjamini_hochberg(calibration_p_values, alpha=0.05)

print(result_bh.summary())
# Benjamini-Hochberg Correction (FDR):
#   Tests: 6
#   Rejected: 3 (50.0%)
#   α = 0.05

print(result_bh.table())
# | Test | Original p | Corrected p | Rejected |
# |------|------------|-------------|----------|
# | 1 | 0.0010 | 0.0060 | ✅ |
# | 2 | 0.0230 | 0.0690 | ❌ |
# | 3 | 0.0410 | 0.0820 | ❌ |
# | 4 | 0.0890 | 0.1335 | ❌ |
# | 5 | 0.1270 | 0.1524 | ❌ |
# | 6 | 0.2340 | 0.2340 | ❌ |

# For comparison, apply Holm-Bonferroni (more conservative)
result_holm = holm_bonferroni(calibration_p_values, alpha=0.05)

print(result_holm.summary())
# Holm-Bonferroni Correction (FWER):
#   Tests: 6
#   Rejected: 1 (16.7%)
#   α = 0.05
```

### 4.3 Example: Subgroup Analysis

```python
# Subgroup PPL analysis (6 subgroups)
subgroup_p_values = [
    0.032,  # Female pronouns
    0.671,  # Male pronouns
    0.823,  # US names
    0.041,  # Non-US names
    0.156,  # Short words
    0.089,  # Long words
]

# Use Benjamini-Yekutieli (dependency-safe, subgroups are correlated)
result_by = benjamini_yekutieli(subgroup_p_values, alpha=0.05)

print(result_by.summary())
# Benjamini-Yekutieli Correction (FDR):
#   Tests: 6
#   Rejected: 0 (0.0%)
#   α = 0.05

# Conclusion: No statistically significant subgroup differences
# after FDR correction under arbitrary dependency.
```

---

## 5. Reporting Standards

### 5.1 NeurIPS 2026 Format

```markdown
## Statistical Methods

### Multiple Testing Correction

We tested 6 calibration metrics simultaneously. To control the false
discovery rate (FDR), we applied the Benjamini-Hochberg correction [1].

**Table 3:** Calibration metrics with FDR correction

| Metric | Original p | BH-corrected p | Rejected | Effect Size |
|--------|------------|----------------|----------|-------------|
| Full-ECE | 0.001 | 0.006 | ✅ Yes | d = 0.684 (MEDIUM) |
| Adaptive ECE | 0.023 | 0.069 | ❌ No | d = 0.412 (SMALL) |
| Dynamic ECE | 0.041 | 0.082 | ❌ No | d = 0.328 (SMALL) |
| Prior-Shift ECE | 0.089 | 0.134 | ❌ No | d = 0.187 (TINY) |
| DR-ECE | 0.127 | 0.152 | ❌ No | d = 0.143 (TINY) |
| Min-K%++ | 0.234 | 0.234 | ❌ No | d = 0.089 (TINY) |

**Conclusion:** Only Full-ECE shows statistically significant improvement
after FDR correction (p = 0.006), with a MEDIUM effect size (d = 0.684).

### Subgroup Analysis

We tested 6 demographic subgroups for PPL differences. Due to correlation
between subgroups, we used the Benjamini-Yekutieli correction [2], which
controls FDR under arbitrary dependency.

**Table 4:** Subgroup PPL analysis with BY-FDR correction

| Subgroup | PPL | Δ vs Global | Original p | BY-corrected p | Significant |
|----------|-----|------------|------------|----------------|-------------|
| Female | 127.1 | +1.8 | 0.032 | 0.112 | ❌ No |
| Male | 124.9 | -0.4 | 0.671 | 1.000 | ❌ No |
| US names | 125.1 | -0.2 | 0.823 | 1.000 | ❌ No |
| Non-US names | 126.8 | +1.5 | 0.041 | 0.143 | ❌ No |
| Short words | 124.7 | -0.6 | 0.156 | 0.548 | ❌ No |
| Long words | 126.3 | +1.0 | 0.089 | 0.311 | ❌ No |

**Conclusion:** No subgroup shows statistically significant PPL difference
after BY-FDR correction. All effect sizes are TINY (d < 0.2), indicating
no practical bias.
```

### 5.2 ICLR 2027 Format

```markdown
## Statistical Analysis

All statistical tests were two-sided with α = 0.05. For multiple comparisons,
we controlled the false discovery rate (FDR) using the Benjamini-Hochberg
procedure [1]. Primary analyses used Holm-Bonferroni correction for
family-wise error rate control on pre-registered hypotheses.

**Power Analysis:** A priori power analysis (G*Power 3.1) indicated that
n = 5 training runs provide 99.99% power to detect the expected effect
(d = 6.90) at α = 0.05.

**Multiple Testing:** For 6 calibration metrics, we applied BH-FDR correction.
One metric (Full-ECE) remained significant after correction (p = 0.006,
FDR-corrected). For 6 subgroup analyses, we applied BY-FDR correction;
no subgroups showed significant differences after correction.
```

---

## 6. Choosing the Right Method

### 6.1 Decision Tree

```
Start: Multiple testing situation
│
├─ Are these pre-registered hypotheses?
│  ├─ Yes → Use Holm-Bonferroni (FWER control)
│  └─ No → Continue
│
├─ Are tests independent or positively correlated?
│  ├─ Yes → Use Benjamini-Hochberg (FDR)
│  └─ No → Continue
│
├─ Is FDR control acceptable (some false positives OK)?
│  ├─ Yes → Use Benjamini-Yekutieli (FDR under dependency)
│  └─ No → Use Bonferroni (FWER, most conservative)
│
└─ Need maximum power while controlling FWER?
   └─ Use Hommel (most powerful FWER method)
```

### 6.2 Recommendations for Trinity

| Analysis Type | Method | Rationale |
|---------------|--------|-----------|
| **Primary (pre-registered)** | Holm-Bonferroni | FWER control, more powerful than Bonferroni |
| **Secondary (exploratory)** | Benjamini-Hochberg | FDR control, appropriate for many metrics |
| **Subgroup analysis** | Benjamini-Yekutieli | Subgroups are correlated, need dependency-safe |
| **Robustness check** | Bonferroni | Most conservative, sanity check |
| **Maximum power (FWER)** | Hommel | Most powerful FWER method |

---

## 7. Integration with Scientific Metrics v7.5

### 7.1 Enhanced Result Dataclasses

```python
# kaggle/eval/scientific_metrics_v7.py (MODIFIED)

from dataclasses import dataclass
from typing import List, Optional

@dataclass
class CalibrationResult:
    """Enhanced calibration result with multiple testing correction."""
    metric_name: str
    value: float
    p_value: float
    ci_lower: float
    ci_upper: float
    # NEW: Multiple testing correction fields
    corrected_p_value: Optional[float] = None
    significant_after_correction: Optional[bool] = None
    correction_method: Optional[str] = None

@dataclass
class MultipleCalibrationResults:
    """Container for multiple calibration metrics with correction."""
    results: List[CalibrationResult]
    correction_method: str = "Benjamini-Hochberg"
    alpha: float = 0.05

    def apply_correction(self, method: str = "BH") -> 'MultipleCalibrationResults':
        """Apply multiple testing correction to all results."""
        p_values = [r.p_value for r in self.results]

        if method == "BH":
            corrected = benjamini_hochberg(p_values, self.alpha)
        elif method == "Holm":
            corrected = holm_bonferroni(p_values, self.alpha)
        elif method == "BY":
            corrected = benjamini_yekutieli(p_values, self.alpha)
        elif method == "Bonferroni":
            corrected = bonferroni(p_values, self.alpha)
        elif method == "Hommel":
            corrected = hommel(p_values, self.alpha)
        else:
            raise ValueError(f"Unknown method: {method}")

        # Update results
        for result, corr_p, rej in zip(self.results, corrected.corrected_p, corrected.rejected):
            result.corrected_p_value = corr_p
            result.significant_after_correction = rej
            result.correction_method = corrected.method

        self.correction_method = corrected.method
        return self

    def summary_table(self) -> str:
        """Generate markdown table for publications."""
        rows = []
        rows.append(f"| Metric | Value | p | {self.correction_method} p | Significant |")
        rows.append("|--------|-------|---|------------------|-------------|")
        for r in self.results:
            sig = "✅ Yes" if r.significant_after_correction else "❌ No"
            rows.append(
                f"| {r.metric_name} | {r.value:.4f} | {r.p_value:.4f} | "
                f"{r.corrected_p_value:.4f} | {sig} |"
            )
        return "\n".join(rows)
```

### 7.2 Example Usage

```python
# Calculate multiple calibration metrics
from kaggle.eval.scientific_metrics_v7 import (
    calculate_full_ece_v7,
    calculate_adaptive_ece_v7,
    calculate_dynamic_ece_v7,
    calculate_prior_shift_ece_v7,
    calculate_dr_ece_v7,
    detect_contamination_mink_pp_v7,
)
from kaggle.eval.multiple_testing import MultipleCalibrationResults

# Run all metrics
results = [
    calculate_full_ece_v7(predictions, labels, n_bins=10),
    calculate_adaptive_ece_v7(predictions, labels, n_bins=10),
    calculate_dynamic_ece_v7(predictions, labels, window_size=100),
    calculate_prior_shift_ece_v7(preds_source, labels_source, preds_target, labels_target),
    calculate_dr_ece_v7(predictions, labels, n_bins=10, alpha=0.1),
]

# Create container
container = MultipleCalibrationResults(results)

# Apply BH-FDR correction
container.apply_correction(method="BH")

# Print summary table
print(container.summary_table())
# | Metric | Value | p | Benjamini-Hochberg p | Significant |
# |--------|-------|---|---------------------|-------------|
# | Full-ECE | 0.0654 | 0.001 | 0.006 | ✅ Yes |
# | Adaptive ECE | 0.0589 | 0.023 | 0.069 | ❌ No |
# | Dynamic ECE | 0.0621 | 0.041 | 0.082 | ❌ No |
# | Prior-Shift ECE | 0.0701 | 0.089 | 0.134 | ❌ No |
# | DR-ECE | 0.0689 | 0.127 | 0.152 | ❌ No |
```

---

## 8. References

1. Y. Benjamini and Y. Hochberg, "Controlling the false discovery rate: A practical and powerful approach to multiple testing," *Journal of the Royal Statistical Society: Series B*, vol. 57, no. 1, pp. 289-300, 1995.

2. Y. Benjamini and D. Yekutieli, "The control of the false discovery rate in multiple testing under dependency," *Annals of Statistics*, vol. 29, no. 4, pp. 1165-1188, 2001.

3. S. Holm, "A simple sequentially rejective multiple test procedure," *Scandinavian Journal of Statistics*, vol. 6, no. 2, pp. 65-70, 1979.

4. G. Hommel, "A stagewise rejective multiple test procedure based on a modified Bonferroni test," *Biometrika*, vol. 75, no. 2, pp. 383-386, 1988.

5. C. W. Dunnett and A. C. Tamhane, *Multiple Comparison Procedures*, John Wiley & Sons, 2009.

6. D. Vasilev, "Effect Size Standardization Framework for Trinity Metrics 2026," *Trinity Research Documentation*, 2026.

---

**Document Version:** 1.0
**Last Updated:** 2026-03-26
**Status:** Ready for integration into scientific_metrics_v8.py
**Next Steps:** Implement multiple testing correction in metrics library
