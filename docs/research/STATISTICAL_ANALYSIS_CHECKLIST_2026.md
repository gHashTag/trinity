# Statistical Analysis Checklist for Trinity Research 2026

**Author:** Dmitrii Vasilev
**Date:** 2026-03-26
**Version:** 1.0
**Purpose:** Comprehensive checklist for statistical analysis in Trinity papers
**Status:** Ready for use

---

## Overview

This checklist ensures all Trinity research papers follow rigorous statistical standards required by top-tier AI/ML conferences (NeurIPS, ICLR, MLSys).

---

## Part I: Pre-Analysis Checklist

### Research Design

- [ ] **Research question clearly stated**
  - [ ] Specific hypothesis (not exploratory)
  - [ ] Expected direction of effect
  - [ ] Practical significance threshold defined

- [ ] **Sample size justified**
  - [ ] Power analysis conducted
  - [ ] Effect size assumption documented
  - [ ] Minimum detectable effect stated

- [ ] **Experimental design appropriate**
  - [ ] Between/within/mixed design justified
  - [ ] Control variables identified
  - [ ] Confounding factors addressed

### Data Collection Plan

- [ ] **Data provenance documented**
  - [ ] Source of data (dataset/simulation/physical)
  - [ ] Collection dates/times
  - [ ] Any exclusions documented with rationale

- [ ] **Randomization**
  - [ ] Random seed(s) recorded
  - [ ] Randomization method described
  - [ ] Assignment concealment if applicable

- [ ] **Blinding**
  - [ ] Single/double-blind if applicable
  - [ ] Method of blinding described

---

## Part II: Data Preparation Checklist

### Data Cleaning

- [ ] **Missing data handled**
  - [ ] Missingness mechanism assessed (MCAR/MAR/MNAR)
  - [ ] Imputation method if used
  - [ ] Complete case analysis justification if used

- [ ] **Outliers examined**
  - [ ] Outlier detection method defined
  - [ ] Outliers investigated (not just removed)
  - [ ] Sensitivity analysis with/without outliers

- [ ] **Data transformations**
  - [ ] Transformation justified
  - [ ] Back-transformation for reporting if needed
  - [ ] Impact on interpretability considered

### Variable Coding

- [ ] **Categorical variables**
  - [ ] Reference level specified
  - [ ] Dummy coding vs effect coding justified
  - [ ] Ordinal vs nominal distinction made

- [ ] **Continuous variables**
  - [ ] Centering/scaling if needed
  - [ ] Nonlinearity assessed
  - [ ] Interactions considered

---

## Part III: Assumption Checking

### Normality

- [ ] **Shapiro-Wilk test** (or similar) reported
- [ ] **Q-Q plots** examined and reported
- [ ] **Skewness/kurtosis** within acceptable limits
- [ ] **If violated:**
  - [ ] Non-parametric alternative used
  - [ ] OR transformation applied and justified
  - [ ] OR bootstrap confidence intervals

### Homogeneity of Variance

- [ ] **Levene's test** (or similar) reported
- [ ] **Box's M test** (for MANOVA) if applicable
- [ ] **Visual inspection** of residual plots
- [ ] **If violated:**
  - [ ] Welch's correction used
  - [ ] OR non-parametric alternative
  - [ ] OR robust standard errors

### Independence

- [ ] **Autocorrelation assessed** (for time series)
- [ ] **Durbin-Watson test** reported if applicable
- [ ] **Clustered data** addressed with mixed models

### Linearity

- [ ] **Scatterplots** examined
- [ ] **Residual plots** show no patterns
- [ ] **If violated:**
  - [ ] Polynomial terms added
  - [ ] OR splines used
  - [ ] OR transformation applied

---

## Part IV: Analysis Execution Checklist

### Primary Analysis

- [ ] **Pre-registered primary analysis**
  - [ ] Hypothesis test matches registration
  - [ ] No p-hacking (data-driven decisions)
  - [ ] Stopping rule followed

- [ ] **Effect size reported**
  - [ ] Point estimate
  - [ ] 95% confidence interval
  - [ ] Magnitude interpretation (tiny/small/medium/large/huge)
  - [ ] Practical significance discussed

- [ ] **Statistical test appropriate**
  - [ ] Test matches data type
  - [ ] Test matches design
  - [ ] Assumptions met or alternative used

### Secondary Analyses

- [ ] **Clearly labeled as exploratory** if not pre-registered
- [ ] **Multiple testing correction** applied
  - [ ] Method specified (Bonferroni/Holm/BH-FDR/BY-FDR/Hommel)
  - [ ] Justification for method choice
  - [ ] Corrected p-values reported

- [ ] **Effect sizes** for all comparisons
- [ ] **Confidence intervals** for all estimates

### Sensitivity Analyses

- [ ] **Different assumptions** tested
  - [ ] Outlier inclusion/exclusion
  - [ ] Different statistical methods
  - [ ] Subgroup analyses

- [ ] **Results consistent** across specifications
- [ ] **Inconsistencies explained**

---

## Part V: Reporting Checklist

### Results Section

- [ ] **Descriptive statistics table**
  - [ ] N, mean, SD (or median, IQR)
  - [ ] Min, max for context
  - [ ] Missing data counts

- [ ] **Test statistics fully reported**
  - [ ] Test name
  - [ ] Test statistic value (t, F, χ², etc.)
  - [ ] Degrees of freedom
  - [ ] Exact p-value (not p < 0.05)
  - [ ] Effect size with CI

- [ ] **Figures publication-ready**
  - [ ] 300 DPI minimum
  - [ ] Error bars labeled (CI vs SEM vs SD)
  - [ ] Sample sizes in captions
  - [ ] Statistical annotations (*p*, **p**, ***p***)

### Language Guidelines

- [ ] **Avoid "significant" when p > 0.05**
- [ ] **Use "statistically significant"** not just "significant"**
- [ ] **Don't say "trend toward significance"**
- [ ] **Don't say "highly significant"**
- [ ] **Report exact p-values**: p = 0.051 (not p = 0.05(ns))

### Effect Size Interpretation

| Effect Size | Threshold | Interpretation |
|-------------|-----------|----------------|
| **Cohen's d** | < 0.2 | TINY |
| | 0.2 - 0.5 | SMALL |
| | 0.5 - 0.8 | MEDIUM |
| | > 0.8 | LARGE |
| **Cliff's Delta** | < 0.147 | NEGLIGIBLE |
| | 0.147 - 0.33 | SMALL |
| | 0.33 - 0.474 | MEDIUM |
| | > 0.474 | LARGE |
| **Pearson's r** | < 0.1 | TINY |
| | 0.1 - 0.3 | SMALL |
| | 0.3 - 0.5 | MEDIUM |
| | > 0.5 | LARGE |
| **R²** | < 0.01 | TINY |
| | 0.01 - 0.09 | SMALL |
| | 0.09 - 0.25 | MEDIUM |
| | > 0.25 | LARGE |

---

## Part VI: Common Mistakes to Avoid

### Statistical Mistakes

❌ **DON'T:** Report p-value without effect size
✅ **DO:** "d = 0.45, 95% CI [0.12, 0.78], p = 0.008"

❌ **DON'T:** Say "non-significant" means "no effect"
✅ **DO:** "Failed to detect effect (95% CI includes null)"

❌ **DON'T:** Collect data until p < 0.05
✅ **DO:** Pre-register sample size and stopping rule

❌ **DON'T:** Exclude data without justification
✅ **DO:** Document all exclusions with rationale

❌ **DON'T:** Use one-tailed test without strong prior
✅ **DO:** Use two-tailed unless direction is pre-specified

### Reporting Mistakes

❌ **DON'T:** p < 0.05 (report exact value)
✅ **DO:** p = 0.032

❌ **DON'T:** "marginally significant" for p = 0.051
✅ **DO:** p = 0.051, interpret with caution

❌ **DON'T:** "approached significance"
✅ **DO:** Report exact p-value, discuss limitations

---

## Part VII: Trinity-Specific Requirements

### HSLM Training Experiments

- [ ] **Report all 5 random seeds**
  - [ ] Individual seed results
  - [ ] Mean ± SD across seeds
  - [ ] Hierarchical model if appropriate

- [ ] **Convergence metrics**
  - [ ] Loss curve with confidence bands
  - [ ] Training stability assessment
  - [ ] Final step vs best step (avoid cherry-picking)

- [ ] **Resource usage**
  - [ ] Training time per seed
  - [ ] Peak memory
  - [ ] Energy consumption (if measured)

### FPGA Experiments

- [ ] **Synthesis results**
  - [ ] LUT/FF/DSP/BRAM usage with percentages
  - [ ] Timing (max frequency)
  - [ ] Power consumption

- [ ] **Comparison to baseline**
  - [ ] Speedup factor with CI
  - [ ] Energy reduction with CI
  - [ ] Accuracy comparison

### VSA Experiments

- [ ] **Dimensionality effects**
  - [ ] Test multiple dimensions (1K, 5K, 10K, 20K)
  - [ ] Report scaling behavior

- [ ] **Operation benchmarks**
  - [ ] Bind/unbind/bundle timing
  - [ ] Similarity search timing
  - [ ] SIMD speedup factor

---

## Part VIII: Pre-Submission Final Check

### For NeurIPS 2026

- [ ] Broader impact statement included
- [ ] Computational complexity analysis (Big-O tables)
- [ ] Experimental protocol detailed
- [ ] Algorithm pseudocode with complexity column
- [ ] Limitations section (not just "future work")
- [ ] Reproducibility checklist complete
- [ ] Ethics statement (especially for bias assessment)

### For ICLR 2027

- [ ] Ethics statement included
- [ ] Bias analysis conducted (if applicable)
- [ ] Subgroup performance reported (if applicable)
- [ ] Mitigation strategies discussed
- [ ] Broader impact statement
- [ ] Data statement (provenance, licensing)

### For MLSys 2026

- [ ] Code availability (GitHub + permissive license)
- [ ] Data availability (HuggingFace or similar)
- [ ] Artifact appendix (688 LOC template)
- [ ] Reproducibility verified
- [ ] Results verified (5/5 claims)
- [ ] Troubleshooting guide

---

## Part IX: Quick Reference Tables

### Statistical Test Selection Guide

| Data Type | Groups | Comparison | Normal? | Test | Effect Size |
|-----------|-------|------------|---------|------|-------------|
| Continuous | 2 | Independent | Yes | Independent t | Cohen's d |
| Continuous | 2 | Independent | No | Mann-Whitney U | Cliff's Delta |
| Continuous | 2 | Paired | Yes | Paired t | Cohen's d |
| Continuous | 2 | Paired | No | Wilcoxon signed-rank | Cliff's Delta |
| Continuous | 3+ | Independent | Yes | One-way ANOVA | η² |
| Continuous | 3+ | Independent | No | Kruskal-Wallis | η² |
| Categorical | 2 | - | - | Chi-square | Φ / OR |
| Correlation | 2 | - | Yes | Pearson's r | r |
| Correlation | 2 | - | No | Spearman's ρ | ρ |

### Multiple Testing Correction Guide

| Tests | Goal | Method | FWER/FDR |
|-------|------|--------|----------|
| ≤ 5 | Strong control | Bonferroni | FWER |
| 5-20 | Strong control | Holm-Bonferroni | FWER |
| 20+ | Exploratory | BH-FDR | FDR |
| Any | Dependent | BY-FDR | FDR |
| Any | Many tests | Hommel | FWER |

---

## Part X: Code Review Checklist

### Before Submitting Code

- [ ] **Reproducibility**
  - [ ] Random seeds fixed
  - [ ] No nondeterministic ordering (dicts, sets)
  - [ ] Version pinned (Zig 0.15.x)
  - [ ] Platform-independent (no hard-coded paths)

- [ ] **Statistical code**
  - [ ] Effect size calculations verified
  - [ ] CI calculations verified
  - [ ] Correction methods verified
  - [ ] Test assumptions checked

- [ ] **Documentation**
  - [ ] Function docstrings complete
  - [ ] Parameter assumptions documented
  - [ ] Return value format documented
  - [ ] Examples provided

---

**Document Version:** 1.0
**Last Updated:** 2026-03-26
**Status:** Ready for use
**Next Steps:** Apply checklist to all Trinity papers before submission
