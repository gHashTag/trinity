# Height-Dependent Bin Analysis: K(T), p95(T), χ²(T)
## Supplement to Session 9: Riemann Hypothesis CF Analysis

**Date:** 2026-03-08 · **Corrected:** 2026-08-13  
**Dataset:** 100,000 Odlyzko zeros divided into 10 height bins  
**Height Range:** γ = 14.1 → 74,920.8

---

## Summary Statistics Across All Bins

| Metric | Mean ± Std | Expected Value | Deviation |
|--------|-----------|----------------|-----------|
| Khinchin K | 2.6201 ± 0.0293 | 2.685 | -0.065 (2.4%) |
| p95 spacing | 1.7186 ± 0.0045 | **1.7518** (GUE, computed) | **-0.033 (1.9%)** |
| χ²/dof | 2.67 ± 0.49 | ~1.0 (perfect fit) | +1.67 — UNVERIFIED |

**Correction 2026-08-13.** The expected p95 was given as 2.15 with no
derivation. The Wigner surmise gives p95 = 1.7518 exactly (from
F(s) = erf(2s/√π) − (4s/π)e^(−4s²/π); regenerate with
`scripts/recompute_zeta_percentiles.py`). The deviation is therefore 1.9%,
not 19.8%, and the "persistent light tails" reading below does not survive.
Per-bin p95 recomputed with equal counts is 1.7186 ± 0.0045 — flat in height.

---

## Bin-by-Bin Results

| Bin | Height Range | T_mid | N | K | Std | p95 | p99 | χ²/dof |
|-----|--------------|-------|---|---|-----|-----|-----|--------|
| 1 | 14.1 - 9,878.7 | 4,946 | 9,999 | 2.6643 | 0.444 | 1.784 | 2.30 | 3.97 |
| 2 | 9,878.7 - 18,047.1 | 13,963 | 9,999 | 2.6328 | 0.399 | 1.720 | 2.07 | 3.07 |
| 3 | 18,047.1 - 25,755.7 | 21,901 | 9,999 | 2.6023 | 0.401 | 1.724 | 2.07 | **2.67** |
| 4 | 25,755.7 - 33,190.8 | 29,473 | 9,999 | 2.6261 | 0.401 | 1.715 | 2.07 | **2.45** |
| 5 | 33,190.8 - 40,434.2 | 36,813 | 9,999 | **2.5770** | 0.402 | 1.724 | 2.07 | **2.41** |
| 6 | 40,434.2 - 47,531.8 | 43,983 | 9,999 | 2.5955 | 0.402 | 1.717 | 2.06 | 2.58 |
| 7 | 47,531.8 - 54,512.2 | 51,022 | 9,999 | 2.5896 | 0.403 | 1.710 | 2.08 | **2.52** |
| 8 | 54,512.2 - 61,394.6 | 57,953 | 9,999 | 2.6036 | 0.403 | 1.723 | 2.07 | **2.41** |
| 9 | 61,394.6 - 68,194.4 | 64,795 | 9,999 | 2.6547 | 0.404 | 1.724 | 2.08 | **2.07** ✅ |
| 10 | 68,194.4 - 74,920.8 | 71,558 | 9,998 | 2.6552 | 0.404 | 1.711 | 2.08 | 2.51 |

---

## Key Findings

### 1. Khinchin Constant: Systematic Low Bias

**K = 2.620 ± 0.029 across all heights, consistently below 2.685**

- Minimum: 2.577 (Bin 5, T ~ 37K)
- Maximum: 2.664 (Bin 1, T ~ 5K)
- Trend: No clear convergence with height
- Deviation from expected: **-2.4%** (systematic)

**Interpretation**: not established — the estimator is unspecified, and the two
plausible estimators bracket the observed value. Monte-Carlo control over
uniform random reals (Khinchin-generic a.s.), 500 expansions per synthetic bin,
`scripts/khinchin_finite_sample.py`:

| estimator | m = 20 terms | m = 50 | m = 100 | K |
|---|---|---|---|---|
| mean of per-expansion geometric means | 2.755 ± 0.031 | 2.713 ± 0.018 | 2.697 ± 0.013 | 2.6854520 |
| pooled geometric mean over all terms | 2.668 ± 0.029 | 2.677 ± 0.017 | 2.684 ± 0.013 | 2.6854520 |

The first estimator is biased **above** K, the second **below**. The observed
2.6201 ± 0.0293 sits 1.6σ from the pooled control at m = 20 — i.e. consistent
with finite-sample bias — and 4σ from the per-expansion control. Which applies
depends on the estimator and on the number of partial quotients per expansion,
neither of which this document records. Status: OPEN, not a finding. To close
it, record the estimator and m, then compare against the matching control row.

### 2. Spacing Distribution: agrees with GUE to ~2%

**p95 = 1.7186 ± 0.0045, against GUE 1.7518 → −1.9%**

- All bins fall in 1.713–1.725; spread across bins is 0.005, not 0.02
- Deviation from GUE: **−1.9%**, and flat in height

**Interpretation**: consistent with the Wigner surmise at the level of accuracy
the surmise itself has (it approximates the exact GUE gap law). The previous
text read this as a −20% deficit and cited Forrester & Mays 2015 as confirming
a finite-size correction. Both go: the −20% was the wrong reference column, and
a 1.9% flat offset is not evidence for a finite-size trend. Forrester & Mays
may still be relevant, but nothing in this table tests it.

### 3. GUE Fit: Improves with Height (with fluctuations)

**χ²/dof = 2.67 ± 0.49**

- Best fit: Bin 9 (χ²/dof = 2.07) at T ~ 65K
- Worst fit: Bin 1 (χ²/dof = 3.97) at lowest heights
- Bins 3-9 all show χ²/dof < 3 (good GUE agreement)

**Interpretation**: Asymptotic GUE behavior emerges at T > 20K, but finite-size corrections remain significant.

---

## Figure 1: Height-Dependent Statistics

Data files created:
- `zeta_figure1_K.csv` - Khinchin K vs height
- `zeta_figure1_p95.csv` - p95 spacing vs height
- `zeta_figure1_chi2.csv` - χ²/dof vs height

These can be plotted with:
```python
import pandas as pd
import matplotlib.pyplot as plt

# K vs height
df = pd.read_csv('zeta_figure1_K.csv')
plt.plot(df['T_mid'], df['Khinchin_K'], 'o-', label='Observed')
plt.axhline(2.685, color='r', linestyle='--', label='Expected (K≈2.685)')
plt.xlabel('Height T'); plt.ylabel('Khinchin K'); plt.legend()
```

---

## Comparison with Literature

| Finding | This Work | Literature | Status |
|---------|-----------|------------|--------|
| p95 vs GUE | 1.7186 vs 1.7518 (−1.9%) | — | ⚠️ Within surmise accuracy; not a finding |
| Std vs GUE | 0.4009 vs 0.4220 (−5.0%) | — | ⚠️ Open — the one real deviation |
| K < 2.685 | 2.62 ± 0.03 | Wolf (2010) | ⚠️ New observation, sample-size limited |
| Finite-size corrections | no height trend in p95 | Forrester-Mays (2015) | ❌ Not tested here (was: "✅ Confirmed") |

Withdrawn rows: "Lighter tails (p95 < GUE) 1.73 vs 2.15 — Odlyzko (1989)
✅ Confirmed" and the Forrester-Mays ✅. Both attached a real citation to an
artifact of the wrong reference column.

---

## Next Steps

1. **Increase CF sample size** per bin (currently 500, target 5000+) to reduce K uncertainty
2. **Extend to higher zeros** (T > 10⁶) to test asymptotic convergence
3. **Compute pair correlation function** for direct comparison with Bogomolny et al. (2006)
4. **Fit finite-size correction formula** p95(T) = p95_GUE + c/log(T) + d/log(T)²

---

*Analysis performed with Trinity V1.0.1 - Sacred Mathematics Module*
*φ² + 1/φ² = 3 = TRINITY*

## Обновление 2026-08-13 (второй тик аудита)

Эталон пересчитан против **точного** закона зазоров GUE (детерминант Фредгольма
с синус-ядром, `scripts/gue_exact_gap.py`), а не против surmise Вигнера:
std 0.424258, p50 0.962807, p90 1.570136, p95 1.757099, p99 2.120406.
Сам surmise отклоняется от точного закона на 0.3-0.5%.

Наблюдение (100k нулей, развёртка через тэта-функцию Римана-Зигеля,
`scripts/unfolding_test.py`): std -5.50%, p90 -2.11%, p95 -2.17%, p99 -2.47%,
p50 +0.29%.

Развёртка как причина ОТВЕРГНУТА: точная развёртка (θ(γ)/π) и ведущий член
дают одно и то же с точностью 1e-5.

Конечная высота — статус OPEN (`scripts/height_extrapolation.py`): при
1/L ~ 0.107 поправка порядка 1/L ожидаема по величине, экстраполяция по
корзинам даёт std +1.09%, p90 +0.09%, p99 +1.52%, но p95 -2.29% (тренда по
высоте у p95 нет). Рычаг слишком короткий (1/L = 0.153..0.107). Закрывается
нулями около 10^12 / 10^21, которых в репозитории нет.
