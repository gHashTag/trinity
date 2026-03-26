# Trinity Experimental Protocol Template 2026

**Author:** Dmitrii Vasilev
**Date:** 2026-03-26
**Version:** 1.0
**Purpose:** Standardized experimental protocol for all Trinity S³AI research
**Status:** Ready for use

---

## Template Structure

This template ensures all Trinity experiments follow rigorous scientific standards for reproducibility and conference submission.

### Required Sections

1. **Objective** — Clear research question
2. **Hypotheses** — Testable predictions with effect sizes
3. **Methods** — Complete reproducibility information
4. **Metrics** — Primary and secondary measures
5. **Analysis Plan** — Statistical tests, corrections
6. **Results** — Findings with uncertainty quantification
7. **Discussion** — Interpretation, limitations, future work

---

## Part I: Header Information

```markdown
# [Experiment Name]

**Authors:** [Name, Email]
**Date:** [YYYY-MM-DD]
**Version:** [X.Y]
**Status:** [Planning/Running/Complete]
**Issue:** #[GitHub issue number]
**Related Bundles:** [B001-B007, PARENT]

---

## Abstract

[One-paragraph summary: objective, methods, key results, conclusion]

**Keywords:** [3-5 keywords for indexing]
```

---

## Part II: Objective

### Research Question

```
Primary Question:
[What are we trying to answer?]

Secondary Questions:
1. [Related question 1]
2. [Related question 2]

Motivation:
[Why is this important? What gap does it fill?]
```

---

## Part III: Hypotheses

### Primary Hypothesis (H1)

```
H1: [Clear, falsifiable statement]

Prediction:
[Specific measurable outcome]

Effect Size Expectation:
[Expected magnitude: tiny/small/medium/large/huge]
```

---

## Part IV: Methods

### Sample Size Justification

```
Power Analysis (G*Power 3.1):

For H1 ([primary test]):
- Effect size: d = [expected Cohen's d]
- α (significance): 0.05
- Power (1-β): [0.80/0.90/0.95]
- Test: [t-test/ANOVA/correlation/chi-square]
- Required n: [calculated sample size]

Actual n: [chosen sample size]
Rationale: [why actual n differs from required n]
```

---

## Part V: Metrics

### Primary Metrics

```
Metric 1: [Name]
- Formula: [mathematical definition]
- Unit: [measurement unit]
- Direction: [higher is better [ ] / lower is better [ ]]
- Interpretation: [what values mean]
```

---

## Part VI: Analysis Plan

### Statistical Tests

```
For H1 ([primary hypothesis]):
- Test: [t-test/ANOVA/Mann-Whitney/etc.]
- Effect Size: [Cohen's d / Cliff's Delta / eta-squared / etc.]
- Confidence Interval: 95%
- Significance: α = 0.05
- Assumptions: [normality/homogeneity of variance/etc.]
```

---

## Part VII: Reproducibility Checklist

### Code Availability

```
- [ ] Code repository URL: [GitHub link]
- [ ] License: [MIT/Apache/etc.]
- [ ] Commit hash: [specific version]
- [ ] Dependencies: [zig 0.15.x, exact versions]
- [ ] Build instructions: [link to docs]
- [ ] Run command: [exact command to reproduce]
```

---

**Document Version:** 1.0
**Last Updated:** 2026-03-26
**Status:** Ready for use
**Next Steps:** Apply template to all Trinity experiments
