# Zeta Zero Spacing Analysis Results
## Session 9: Riemann Hypothesis CF Analysis

**Date:** 2026-03-08 · **Corrected:** 2026-08-13  
**Dataset:** 100,000 real zeta zeros from Odlyzko database  
**Height Range:** γ = 14.1 → 74,920.8

---

## Executive Summary

Analysis of 100,000 real Riemann zeta function zeros reveals:

1. ✅ **Local mean spacing** perfectly matches theoretical formula `2π/ln(T)`
2. ✅ **Khinchin's constant K = 2.669** ≈ 2.685 (generic CF behavior)
3. ⚠️ **Std deviation = 0.401** vs GUE 0.4220 = √(3π/8 − 1) → −5.0% (the one surviving deviation)
4. ✅ **95th percentile = 1.719** vs GUE **1.7518** → −1.9% (the former "2.15" reference was wrong)
5. ✅ **Tails agree with the Wigner surmise to ~2%**; the earlier "significantly lighter tails" claim was an artifact of the wrong reference column

---

## Detailed Statistics

### Global Statistics (100K zeros)

Reference column is **computed, not cited**: GUE Wigner surmise
p(s) = (32/π²)s²e^(−4s²/π), CDF F(s) = erf(2s/√π) − (4s/π)e^(−4s²/π).
Regenerate every number below with
`scripts/recompute_zeta_percentiles.py data/zeta/zeros_odlyzko_100k.txt`.

| Metric | Value | GUE (computed) | Deviation | Status |
|--------|-------|----------------|-----------|--------|
| Mean spacing | 1.0000 | 1.0 (exact) | −0.00% | ✅ |
| Std deviation | 0.4009 | 0.4220 | −5.00% | ⚠️ real deviation |
| Median | 0.9655 | 0.9639 | +0.17% | ✅ |
| 95th percentile | 1.7189 | 1.7518 | −1.88% | ✅ |
| 99th percentile | 2.0680 | 2.1107 | −2.02% | ✅ |

**Correction 2026-08-13.** The previous version of this table used a
"GUE Expected" column of 0.91 / 2.15 / 2.75 for median / p95 / p99. None of
those three values is reproducible from the Wigner surmise, from the GOE
surmise (0.939 / 1.953 / 2.422), or from the s³ variant that
`src/sacred/zeta_spacing.zig` implemented before its fix (1.148 / 1.930 / 2.283).
They were a cited reference column with no derivation. Only the std entry
(0.42–0.43) was correct. The observed column was also internally inconsistent —
the summary said p95 = 1.72 while the table said 1.760, and the global std of
0.429 contradicted this document's own bin table, where every bin is 0.39–0.44.
Recomputed observed values are above.

### Continued Fraction Analysis

| Metric | Value | Expected | Interpretation |
|--------|-------|----------|----------------|
| Irrationality μ | 3.78 | ~2.0-2.5 | Elevated (arithmetic structure) |
| Khinchin K | 2.669 | 2.685 | ✅ Generic behavior |
| Entropy | 3.41 bits | ~3-4 bits | ✅ Normal |
| Max partial | 437,000 | ~100-1000 | Extreme outlier |

---

## Height Dependence

| Height Range | N (spacings) | χ²/dof | GUE Fit |
|--------------|--------------|--------|---------|
| 0 - 1K | 648 | 1.93 | ✅ Excellent |
| 1K - 5K | 3,870 | 2.57 | ✅ Good |
| 5K - 10K | 5,621 | 2.89 | ✅ Marginal |
| 10K - 20K | 12,348 | 3.81 | ⚠️ Moderate deviation |
| 20K - 50K | 41,027 | 7.88 | ❌ Strong deviation |
| 50K+ | 36,480 | 6.32 | ❌ Strong deviation |

### Local Mean Spacing Validation

| Height T | Observed | Expected (2π/ln T) | Ratio |
|----------|----------|-------------------|-------|
| 500 | 1.432 | 1.436 | 0.9976 |
| 1,000 | 1.234 | 1.239 | 0.9958 |
| 2,000 | 1.088 | 1.090 | 0.9978 |
| 5,000 | 0.939 | 0.941 | 0.9980 |
| 10,000 | 0.850 | 0.852 | 0.9968 |
| 20,000 | 0.784 | 0.779 | 1.0067 |
| 50,000 | 0.694 | 0.700 | 0.9921 |

**All ratios ≈ 1.00 → Perfect agreement with theory!** ✅

---

## Key Findings

### 1. Montgomery-Odlyzko Law: Confirmed to ~2% at these heights

Against a computed GUE reference, the 100K zeros agree with the Wigner surmise
at the 2% level in median, p95 and p99. The earlier conclusion in this
document — "the law is only an approximation, tails are significantly
lighter" — rested entirely on the wrong reference column and does not survive
its correction. What remains:
- **Variance −5.0%** (0.4009 vs 0.4220): the one deviation larger than the
  surmise-vs-exact-GUE gap, and the only one worth pursuing.
- **p99 is not lighter but slightly heavier than the naive reading suggested**:
  2.068 vs 2.111 is −2%, i.e. within the accuracy of the surmise itself, which
  is an approximation to the exact GUE gap law (Fredholm determinant /
  Painlevé V). Any claim finer than a few percent needs the exact law, not the
  surmise.

### 2. Height Paradox — status: OPEN, and suspect

χ²/dof in the table below grows with height, which contradicts asymptotic
theory. The χ²/dof column was computed against the same reference machinery
that carried the wrong p95, and with unequal-N binning of the kind shown to
inflate agreement in `data/zeta/corrected-2026-08-12/NOTE.md`. Recomputed
per-bin p95 with equal counts is flat: 1.7186 ± 0.0045 across ten bins, i.e.
no height trend at all. Treat the χ² table as unverified until regenerated.

### 3. Arithmetic Structure

Elevated irrationality measure (μ = 3.78) and presence of large partial quotients suggest:
- Zeta zeros may have arithmetic structure not captured by random matrix theory
- Some spacings show "unusually simple" continued fraction expansions

### 4. Khinchin Constant Validation

K = 2.669 ≈ 2.685 confirms **generic CF behavior** for most spacings, despite GUE deviations.

---

## Data Source

- **Database:** Odlyzko Zeta Tables
- **URL:** http://www.dtc.umn.edu/~odlyzko/zeta_tables/
- **File:** zeros1 (100,000 zeros)
- **Precision:** ~9 decimal places

---

## References

1. Montgomery, H. (1973). "The pair correlation of zeros of the zeta function"
2. Odlyzko, A. M. (1989). "The 10^20-th zero of the Riemann zeta function"
   — cited here for the dataset only. This document previously cited it as
   confirming "lighter tails"; that claim was an artifact of the reference
   column and the citation has been withdrawn from it.
3. Mezzadri, F. (2006). "How to generate random matrices from the classical compact groups"
4. Forrester, P. J. (2010). "Log-gases and random matrices"

---

*Analysis performed with Trinity V1.0.1 - Sacred Mathematics Module*
*φ² + 1/φ² = 3 = TRINITY*
