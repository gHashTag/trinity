# Scientific Code Review Checklist for AGI Evaluation Metrics

**Date**: 2026-03-26
**Version**: 1.0
**Author**: Dmitrii Vasilev

---

## Purpose

This checklist provides **scientifically rigorous** review criteria for AGI evaluation metric implementations, ensuring statistical validity and reproducibility.

---

## Part 1: Statistical Validity

### 1.1 Confidence Intervals

- [ ] **CI Method Specified**: Bootstrap (percentile, BCa), Wald, or DeLong?
- [ ] **CI Level**: 95% default, is alpha specified?
- [ ] **Bootstrap Size**: n ≥ 1000 for stable results
- [ ] **Random Seed**: Set for reproducibility?
- [ ] **CI Coverage**: Validated (coverage ≈ nominal level)?
- [ ] **CI Interpretation**: Correct interpretation (not misuse)?

**Red Flags**:
- ❌ Point estimates without CI
- ❌ CI without method specification
- ❌ Arbitrary CI transformations
- ❌ No random seed set

---

### 1.2 Hypothesis Tests

- [ ] **Test Justification**: Why this test (parametric vs non-parametric)?
- [ ] **Assumptions Checked**: Normality, equal variance, independence?
- [ ] **Test Direction**: One-tailed vs two-tailed justified?
- [ ] **P-value Format**: Exact value reported (not just p < 0.05)?
- [ ] **Multiple Testing**: Correction applied (Bonferroni, BH, Storey)?
- [ ] **Effect Size**: Cohen's d, Cliff's Delta, or similar?

**Red Flags**:
- ❌ "p < 0.05" without exact p-value
- ❌ No effect size reported
- ❌ Multiple comparisons without correction
- ❌ Parametric test on non-normal data (without justification)

---

### 1.3 Sample Size

- [ ] **Sample Size Justified**: Power analysis or heuristic?
- [ ] **Minimum Sample**: n ≥ 30 for CLT, n ≥ 100 for stable CI
- [ ] **Subgroup Analysis**: Sufficient sample per subgroup?
- [ ] **Missing Data**: How handled (complete case, imputation)?

**Red Flags**:
- ❌ n < 20 for complex statistics
- ❌ Subgroup analysis with n < 10
- ❌ No mention of missing data

---

## Part 2: Metric Implementation

### 2.1 Expected Calibration Error (ECE)

- [ ] **Binning Method**: Equal-width, equal-mass, or adaptive?
- [ ] **Weighting**: Sample-count weighted (not probability-weighted)?
- [ ] **Bin Count**: n_bins justified (usually 10)?
- [ ] **Empty Bins**: Properly handled (skipped or pseudocount)?
- [ ] **CI Method**: Bootstrap CI on ECE itself?
- [ ] **Per-Token vs Per-Sample**: Which is used and why?

**Critical Check**:
```python
# CORRECT: Sample-count weighted
bin_weight = count / n_total
ece += bin_weight * abs(avg_conf - avg_acc)

# WRONG: Probability-weighted
bin_weight = weight / total_weight  # Biased toward high-conf
```

---

### 2.2 Min-K%++ Contamination

- [ ] **Vocabulary-Based**: Scoring applied to vocabulary tokens, not samples?
- [ ] **K Percent**: k_percent × vocab_size (not n_samples)?
- [ ] **Statistical Test**: Proper test against null distribution?
- [ ] **CI Interpretation**: CI for the actual metric (not transformed)?
- [ ] **Log Probabilities**: Raw log probs (no mean normalization)?

**Critical Check**:
```python
# CORRECT: Vocabulary-based
k = int(vocab_size * k_percent / 100)
bottom_k_scores = sorted(all_vocab_scores)[:k]

# WRONG: Sample-based
k_sample = int(n_samples * k_percent / 100)
```

---

### 2.3 DeLong AUC CI

- [ ] **Placement Values**: φ₁ and φ₀ computed correctly?
- [ ] **Variance Components**: Var(φ₁) and Var(φ₀) computed?
- [ ] **Correlation**: Accounts for correlated ROC curves?
- [ ] **Formula**: Full DeLong (not binomial approximation)?

**Critical Check**:
```python
# CORRECT: Full DeLong
phi_1 = [sum(y_scores[j] < y_scores[i] for j in neg_idx) / n_neg for i in pos_idx]
phi_0 = [sum(y_scores[j] > y_scores[i] for j in pos_idx) / n_pos for i in neg_idx]
var_auc = (var(phi_1) / n_pos + var(phi_0) / n_neg) / (n_pos * n_neg)

# WRONG: Binomial approximation
se = sqrt(auc * (1 - auc) * (1/n_pos + 1/n_neg) / 4)
```

---

## Part 3: Numerical Stability

### 3.1 Log Probabilities

- [ ] **Log-Sum-Exp**: Used for numerical stability?
- [ ] **Clipping**: Values clipped before log/exp?
- [ ] **Epsilon**: Small value added to avoid log(0)?

**Example**:
```python
# CORRECT: Log-sum-exp trick
log_sum_exp = max_val + log(sum(exp(x - max_val) for x in values))

# WRONG: Direct computation (can overflow)
log_sum = log(sum(exp(x) for x in values))
```

---

### 3.2 Division

- [ ] **Denominator Check**: Division by zero protected?
- [ ] **Epsilon**: Small value added if needed?

**Example**:
```python
# CORRECT: Protected division
result = numerator / (denominator + epsilon)

# WRONG: Unprotected
result = numerator / denominator  # Can raise ZeroDivisionError
```

---

### 3.3 Bootstrap Indices

- [ ] **Index Bounds**: Floor/ceil for percentile indices?
- [ ] **Edge Cases**: n_bootstrap < n_bins handled?

**Example**:
```python
# CORRECT: Floor/ceil
lower_idx = int(math.floor(alpha/2 * n_bootstrap))
upper_idx = int(math.ceil((1 - alpha/2) * n_bootstrap))

# WRONG: Int truncation
lower_idx = int(alpha/2 * n_bootstrap)  # Biased
```

---

## Part 4: Code Quality

### 4.1 Documentation

- [ ] **Docstrings**: All functions documented?
- [ ] **Parameters**: Types and descriptions?
- [ ] **Returns**: Type and description?
- [ ] **References**: Paper citations for methods?
- [ ] **Examples**: Usage examples provided?

---

### 4.2 Testing

- [ ] **Unit Tests**: All functions tested?
- [ ] **Edge Cases**: Empty input, single value, extreme values?
- [ ] **Statistical Tests**: Test statistical properties (CI coverage, test size)?
- [ ] **Reproducibility**: Tests pass with fixed seed?
- [ ] **Code Coverage**: >80% target?

---

### 4.3 Style

- [ ] **Naming**: Descriptive variable names?
- [ ] **Formatting**: Consistent formatting (black, autopep8)?
- [ ] **Imports**: Organized and no unused imports?
- [ ] **Type Hints**: Function signatures annotated?
- [ ] **Constants**: Named, not magic numbers?

---

## Part 5: Reproducibility

### 5.1 Environment

- [ ] **Requirements**: All dependencies listed?
- [ ] **Versions**: Package versions specified?
- [ ] **Python Version**: Specified (3.9+, 3.10+)?
- [ ] **Random Seeds**: All stochastic processes seeded?

---

### 5.2 Data

- [ ] **Data Sources**: Clearly documented?
- [ ] **Data Version**: Which data version used?
- [ ] **Data License**: License specified?
- [ ] **Data Provenance**: How was data generated/collected?

---

### 5.3 Results

- [ ] **Exact Values**: All reported numbers reproducible?
- [ ] **Figures/Tables**: Generated from code (not manual)?
- [ ] **Scripts**: Scripts to regenerate all results?
- [ ] **Checkpoint**: Model/data checksums provided?

---

## Part 6: Scientific Reporting

### 6.1 Figures

- [ ] **Error Bars**: 95% CI or standard error?
- [ ] **Sample Size**: Indicated in caption or legend?
- [ ] **Axis Labels**: Clear and with units?
- [ ] **Resolution**: High enough for publication?
- [ ] **Colorblind-Friendly**: Distinguishable without color?

---

### 6.2 Tables

- [ ] **Precision**: Consistent decimal places?
- [ ] **Alignment**: Numbers aligned on decimal point?
- [ ] **Units**: Indicated in column headers?
- [ ] **Significance**: Asterisks for significance levels?
- [ ] **Full Results**: Not cherry-picked?

---

### 6.3 Text

- [ ] **Claims**: Supported by results?
- [ ] **Citations**: All claims cited?
- [ ] **Limitations**: Discussed honestly?
- [ ] **Speculation**: Clearly labeled as such?
- [ ] **Language**: Clear and precise?

---

## Quick Reference: Common Issues

| Issue | Severity | Fix |
|-------|----------|-----|
| Probability-weighted ECE | CRITICAL | Use sample-count weighting |
| Arbitrary CI transformation | HIGH | Report actual metric CI |
| Missing effect size | MEDIUM | Add Cohen's d or Cliff's Delta |
| No multiple testing correction | HIGH | Add Benjamini-Hochberg |
| Missing random seed | LOW | Set `np.random.seed(42)` |
| Log(0) without protection | CRITICAL | Add epsilon or use log-sum-exp |
| Division by zero | HIGH | Add epsilon to denominator |
| Int index for CI percentile | LOW | Use floor/ceil |
| Missing p-value exact | MEDIUM | Report exact p-value |
| Missing CI | HIGH | Add bootstrap CI |

---

## Pre-Merge Checklist

Before merging metric implementation code:

### Code Review
- [ ] All functions have docstrings
- [ ] All parameters type-hinted
- [ ] References to papers included
- [ ] Edge cases handled
- [ ] No hardcoded constants

### Statistical Review
- [ ] CI method specified and justified
- [ ] Effect sizes computed
- [ ] Normality/assumptions checked
- [ ] Multiple testing correction applied
- [ ] Sample size justified

### Testing Review
- [ ] Unit tests pass
- [ ] Edge cases tested
- [ ] Statistical properties tested
- [ ] Code coverage >80%
- [ ] Reproducible with fixed seed

### Documentation Review
- [ ] README updated
- [ ] Usage examples provided
- [ ] Known limitations listed
- [ ] Contact information included

---

## Reviewer Responsibilities

1. **Verify**: Check each item on the list
2. **Document**: Record findings in review comments
3. **Classify**: Issue severity (CRITICAL, HIGH, MEDIUM, LOW)
4. **Follow-up**: Verify fixes before approval

---

## Author Responsibilities

1. **Self-Review**: Complete checklist before submission
2. **Address Issues**: Respond to all review comments
3. **Document Changes**: Explain all non-trivial changes
4. **Update Tests**: Add tests for bug fixes

---

**Document Version**: 1.0
**Last Updated**: 2026-03-26
**Status**: Ready for Use
