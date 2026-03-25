#!/usr/bin/env python3
"""
Trinity Statistical Analysis Toolkit
Comprehensive statistical methods for scientific research validation

Version: 1.0.0
Date: 2026-03-26
Purpose: Hypothesis testing, effect size calculation, and confidence intervals
"""

import numpy as np
import scipy.stats as stats
from scipy.special import stdtr
from typing import Tuple, List, Dict, Optional, Union
from dataclasses import dataclass
from enum import Enum


# ═══════════════════════════════════════════════════════════════════════════════
# Data Classes
# ═══════════════════════════════════════════════════════════════════════════════

@dataclass
class TestResult:
    """Results of a statistical test."""
    test_name: str
    statistic: float
    p_value: float
    critical_value: Optional[float] = None
    confidence_interval: Optional[Tuple[float, float]] = None
    effect_size: Optional[float] = None
    interpretation: str = ""
    is_significant: bool = False

    def __str__(self) -> str:
        ci_str = f"CI: [{self.confidence_interval[0]:.4f}, {self.confidence_interval[1]:.4f}]" if self.confidence_interval else "N/A"
        return (f"{self.test_name}: statistic={self.statistic:.4f}, "
                f"p={self.p_value:.4e}, {ci_str}, "
                f"effect={self.effect_size:.3f}, {self.interpretation}")


@dataclass
class Experiment:
    """Experimental data with metadata."""
    name: str
    treatment: np.ndarray
    control: Optional[np.ndarray] = None
    metric: str = "value"
    unit: str = ""
    metadata: Dict = None

    def __post_init__(self):
        if self.metadata is None:
            self.metadata = {}


# ═══════════════════════════════════════════════════════════════════════════════
# Confidence Intervals
# ═══════════════════════════════════════════════════════════════════════════════

def confidence_interval(
    data: np.ndarray,
    confidence: float = 0.95,
    method: str = "t"
) -> Tuple[float, float, float]:
    """
    Calculate confidence interval for mean.

    Args:
        data: Sample data
        confidence: Confidence level (0-1)
        method: "t" (t-distribution) or "normal" (z-distribution)

    Returns:
        (mean, lower, upper)
    """
    n = len(data)
    if n < 2:
        raise ValueError("Need at least 2 samples for CI")

    mean = np.mean(data)
    std = np.std(data, ddof=1)
    se = std / np.sqrt(n)

    alpha = 1 - confidence

    if method == "t":
        t_val = stats.t.ppf(1 - alpha/2, n - 1)
        margin = t_val * se
    elif method == "normal":
        z_val = stats.norm.ppf(1 - alpha/2)
        margin = z_val * se
    else:
        raise ValueError(f"Unknown method: {method}")

    return mean, mean - margin, mean + margin


def bootstrap_ci(
    data: np.ndarray,
    stat_func: callable = np.mean,
    n_bootstrap: int = 10000,
    confidence: float = 0.95,
    seed: int = 42
) -> Tuple[float, float, float]:
    """
    Bootstrap confidence interval.

    Args:
        data: Sample data
        stat_func: Statistic to bootstrap (default: mean)
        n_bootstrap: Number of bootstrap iterations
        confidence: Confidence level
        seed: Random seed

    Returns:
        (statistic, lower, upper)
    """
    rng = np.random.default_rng(seed)
    n = len(data)

    boot_stats = []
    for _ in range(n_bootstrap):
        sample = rng.choice(data, size=n, replace=True)
        boot_stats.append(stat_func(sample))

    boot_stats = np.array(boot_stats)
    alpha = 1 - confidence

    lower = np.percentile(boot_stats, 100 * alpha / 2)
    upper = np.percentile(boot_stats, 100 * (1 - alpha / 2))
    observed = stat_func(data)

    return observed, lower, upper


# ═══════════════════════════════════════════════════════════════════════════════
# Effect Sizes
# ═══════════════════════════════════════════════════════════════════════════════

def cohens_d(
    treatment: np.ndarray,
    control: np.ndarray
) -> Tuple[float, str]:
    """
    Calculate Cohen's d effect size.

    Interpretation:
    - d = 0.2: Small effect
    - d = 0.5: Medium effect
    - d = 0.8: Large effect

    Args:
        treatment: Treatment group data
        control: Control group data

    Returns:
        (effect_size, interpretation)
    """
    n1, n2 = len(treatment), len(control)
    m1, m2 = np.mean(treatment), np.mean(control)
    s1, s2 = np.std(treatment, ddof=1), np.std(control, ddof=1)

    # Pooled standard deviation
    pooled_std = np.sqrt(((n1 - 1) * s1**2 + (n2 - 1) * s2**2) / (n1 + n2 - 2))

    d = (m1 - m2) / pooled_std

    if abs(d) < 0.2:
        interpretation = "negligible"
    elif abs(d) < 0.5:
        interpretation = "small"
    elif abs(d) < 0.8:
        interpretation = "medium"
    else:
        interpretation = "large"

    return d, interpretation


def cliffs_delta(
    treatment: np.ndarray,
    control: np.ndarray
) -> Tuple[float, str]:
    """
    Calculate Cliff's Delta (non-parametric effect size).

    Interpretation:
    - |delta| < 0.147: negligible
    - |delta| < 0.33: small
    - |delta| < 0.474: medium
    - |delta| >= 0.474: large

    Args:
        treatment: Treatment group data
        control: Control group data

    Returns:
        (effect_size, interpretation)
    """
    n1, n2 = len(treatment), len(control)

    # Count all pairwise comparisons
    greater = 0
    less = 0

    for t in treatment:
        for c in control:
            if t > c:
                greater += 1
            elif t < c:
                less += 1

    total = n1 * n2
    delta = (greater - less) / total

    if abs(delta) < 0.147:
        interpretation = "negligible"
    elif abs(delta) < 0.33:
        interpretation = "small"
    elif abs(delta) < 0.474:
        interpretation = "medium"
    else:
        interpretation = "large"

    return delta, interpretation


def glass_delta(
    treatment: np.ndarray,
    control: np.ndarray
) -> Tuple[float, str]:
    """
    Calculate Glass's Delta (uses control SD as standardizer).

    Useful when treatment SD differs significantly from control.

    Args:
        treatment: Treatment group data
        control: Control group data

    Returns:
        (effect_size, interpretation)
    """
    m1, m2 = np.mean(treatment), np.mean(control)
    s_control = np.std(control, ddof=1)

    if s_control == 0:
        return 0.0, "undefined (zero variance)"

    delta = (m1 - m2) / s_control

    if abs(delta) < 0.2:
        interpretation = "small"
    elif abs(delta) < 0.5:
        interpretation = "medium"
    elif abs(delta) < 0.8:
        interpretation = "large"
    else:
        interpretation = "very large"

    return delta, interpretation


# ═══════════════════════════════════════════════════════════════════════════════
# Hypothesis Tests
# ═══════════════════════════════════════════════════════════════════════════════

def one_sample_t_test(
    data: np.ndarray,
    null_value: float = 0,
    alternative: str = "two-sided",
    confidence: float = 0.95
) -> TestResult:
    """
    One-sample t-test.

    H0: mean = null_value
    H1: mean != null_value (two-sided) or mean >/< null_value (one-sided)

    Args:
        data: Sample data
        null_value: Null hypothesis value
        alternative: "two-sided", "greater", or "less"
        confidence: Confidence level for CI

    Returns:
        TestResult object
    """
    n = len(data)
    df = n - 1
    mean = np.mean(data)
    std = np.std(data, ddof=1)
    se = std / np.sqrt(n)

    t_stat = (mean - null_value) / se

    if alternative == "two-sided":
        p_value = 2 * (1 - stats.t.cdf(abs(t_stat), df))
    elif alternative == "greater":
        p_value = 1 - stats.t.cdf(t_stat, df)
    elif alternative == "less":
        p_value = stats.t.cdf(t_stat, df)
    else:
        raise ValueError(f"Unknown alternative: {alternative}")

    # Confidence interval
    ci = confidence_interval(data, confidence, method="t")

    # Effect size (Cohen's d)
    d, interp = cohens_d(data, np.array([null_value]))

    # Interpretation
    alpha = 0.05
    is_sig = p_value < alpha

    if is_sig:
        interpretation = f"Reject H0 (p<{alpha})"
    else:
        interpretation = f"Fail to reject H0 (p>={alpha})"

    return TestResult(
        test_name="One-Sample t-Test",
        statistic=t_stat,
        p_value=p_value,
        confidence_interval=(ci[1], ci[2]),
        effect_size=d,
        interpretation=interpretation,
        is_significant=is_sig
    )


def two_sample_t_test(
    treatment: np.ndarray,
    control: np.ndarray,
    alternative: str = "two-sided",
    equal_var: bool = False,
    confidence: float = 0.95
) -> TestResult:
    """
    Two-sample t-test (independent samples).

    H0: mean_treatment = mean_control
    H1: mean_treatment != mean_control

    Args:
        treatment: Treatment group data
        control: Control group data
        alternative: "two-sided", "greater", or "less"
        equal_var: Assume equal variances (Welch's t-test if False)
        confidence: Confidence level

    Returns:
        TestResult object
    """
    t_stat, p_value = stats.ttest_ind(treatment, control, equal_var=equal_var, alternative=alternative)

    n1, n2 = len(treatment), len(control)
    df = n1 + n2 - 2  # Approximate for Welch's t-test

    # Effect size
    d, interp = cohens_d(treatment, control)

    # Confidence interval for difference
    diff_mean = np.mean(treatment) - np.mean(control)
    diff_std = np.sqrt(np.var(treatment, ddof=1)/n1 + np.var(control, ddof=1)/n2)
    se = diff_std

    alpha = 1 - confidence
    t_crit = stats.t.ppf(1 - alpha/2, df)
    margin = t_crit * se

    ci = (diff_mean - margin, diff_mean + margin)

    # Interpretation
    is_sig = p_value < 0.05
    if is_sig:
        interpretation = f"Significant difference (p={p_value:.4f}, d={d:.3f}, {interp})"
    else:
        interpretation = f"No significant difference (p={p_value:.4f}, d={d:.3f}, {interp})"

    return TestResult(
        test_name="Two-Sample t-Test (Welch)" if not equal_var else "Two-Sample t-Test",
        statistic=t_stat,
        p_value=p_value,
        confidence_interval=ci,
        effect_size=d,
        interpretation=interpretation,
        is_significant=is_sig
    )


def paired_t_test(
    before: np.ndarray,
    after: np.ndarray,
    alternative: str = "two-sided",
    confidence: float = 0.95
) -> TestResult:
    """
    Paired t-test for within-subjects designs.

    H0: mean(before - after) = 0
    H1: mean(before - after) != 0

    Args:
        before: Before measurements
        after: After measurements
        alternative: "two-sided", "greater", or "less"
        confidence: Confidence level

    Returns:
        TestResult object
    """
    assert len(before) == len(after), "Samples must be paired (same length)"

    diff = before - after

    t_stat, p_value = stats.ttest_rel(after, before, alternative=alternative)

    df = len(diff) - 1

    # Effect size (Cohen's d for paired)
    d, interp = cohens_d(np.mean(diff), np.zeros_like(diff))

    # CI
    ci = confidence_interval(diff, confidence, method="t")

    is_sig = p_value < 0.05
    if is_sig:
        interpretation = f"Significant paired difference (p={p_value:.4f}, d={d:.3f}, {interp})"
    else:
        interpretation = f"No significant paired difference (p={p_value:.4f})"

    return TestResult(
        test_name="Paired t-Test",
        statistic=t_stat,
        p_value=p_value,
        confidence_interval=(ci[1], ci[2]),
        effect_size=d,
        interpretation=interpretation,
        is_significant=is_sig
    )


def wilcoxon_test(
    treatment: np.ndarray,
    control: np.ndarray,
    alternative: str = "two-sided"
) -> TestResult:
    """
    Wilcoxon rank-sum test (Mann-Whitney U test).

    Non-parametric alternative to t-test.

    Args:
        treatment: Treatment group data
        control: Control group data
        alternative: "two-sided", "greater", or "less"

    Returns:
        TestResult object
    """
    statistic, p_value = stats.mannwhitneyu(treatment, control, alternative=alternative)

    # Effect size (Cliff's Delta)
    delta, interp = cliffs_delta(treatment, control)

    # Rank-biserial correlation
    n1, n2 = len(treatment), len(control)
    u = statistic
    rbc = 1 - (2 * u) / (n1 * n2)

    is_sig = p_value < 0.05
    if is_sig:
        interpretation = f"Significant rank difference (p={p_value:.4f}, δ={delta:.3f}, {interp})"
    else:
        interpretation = f"No significant rank difference (p={p_value:.4f})"

    return TestResult(
        test_name="Wilcoxon Rank-Sum Test",
        statistic=statistic,
        p_value=p_value,
        effect_size=delta,
        interpretation=interpretation,
        is_significant=is_sig
    )


def chi_square_test(
    observed: np.ndarray,
    expected: Optional[np.ndarray] = None
) -> TestResult:
    """
    Chi-square goodness-of-fit test.

    H0: Observed frequencies match expected frequencies

    Args:
        observed: Observed frequencies
        expected: Expected frequencies (if None, assumes uniform)

    Returns:
        TestResult object
    """
    if expected is None:
        expected = np.ones_like(observed) / len(observed) * np.sum(observed)

    # Ensure expected values are large enough
    if np.any(expected < 5):
        import warnings
        warnings.warn("Some expected values < 5, chi-square may be invalid")

    chi2, p_value = stats.chisquare(f_observed=observed, f_exp=expected)

    df = len(observed) - 1

    # Effect size (Cramér's V)
    n = np.sum(observed)
    k = min(observed.shape)
    phi = np.sqrt(chi2 / n)
    cramers_v = phi / np.sqrt(k - 1)

    is_sig = p_value < 0.05
    if is_sig:
        interpretation = f"Significant deviation from expected (p={p_value:.4f}, V={cramers_v:.3f})"
    else:
        interpretation = f"No significant deviation (p={p_value:.4f})"

    return TestResult(
        test_name="Chi-Square Goodness-of-Fit",
        statistic=chi2,
        p_value=p_value,
        critical_value=stats.chi2.ppf(0.95, df),
        effect_size=cramers_v,
        interpretation=interpretation,
        is_significant=is_sig
    )


def anova(
    *groups: np.ndarray,
    confidence: float = 0.95
) -> TestResult:
    """
    One-way ANOVA (Analysis of Variance).

    H0: All group means are equal
    H1: At least one group mean differs

    Args:
        *groups: Variable number of group arrays

    Returns:
        TestResult object
    """
    f_stat, p_value = stats.f_oneway(*groups)

    k = len(groups)
    n_total = sum(len(g) for g in groups)
    df_between = k - 1
    df_within = n_total - k

    # Effect size (eta-squared)
    grand_mean = np.mean(np.concatenate(groups))
    ss_total = np.sum((x - grand_mean)**2 for g in groups for x in g)
    ss_between = sum(len(g) * (np.mean(g) - grand_mean)**2 for g in groups)
    eta_squared = ss_between / ss_total

    # Interpretation of eta-squared
    if eta_squared < 0.01:
        interp = "small"
    elif eta_squared < 0.06:
        interp = "medium"
    elif eta_squared < 0.14:
        interp = "large"
    else:
        interp = "very large"

    is_sig = p_value < 0.05
    if is_sig:
        interpretation = f"Significant group differences (p={p_value:.4f}, η²={eta_squared:.3f}, {interp})"
    else:
        interpretation = f"No significant group differences (p={p_value:.4f})"

    return TestResult(
        test_name="One-Way ANOVA",
        statistic=f_stat,
        p_value=p_value,
        effect_size=eta_squared,
        interpretation=interpretation,
        is_significant=is_sig
    )


# ═══════════════════════════════════════════════════════════════════════════════
# Power Analysis
# ═══════════════════════════════════════════════════════════════════════════════

def sample_size_t_test(
    effect_size: float,
    alpha: float = 0.05,
    power: float = 0.80,
    ratio: float = 1.0
) -> int:
    """
    Calculate required sample size for two-sample t-test.

    Args:
        effect_size: Cohen's d (0.2=small, 0.5=medium, 0.8=large)
        alpha: Significance level
        power: Desired power (1 - beta)
        ratio: n2/n1 ratio

    Returns:
        Required sample size (per group)
    """
    z_alpha = stats.norm.ppf(1 - alpha / 2)
    z_beta = stats.norm.ppf(power)

    n_per_group = 2 * ((z_alpha + z_beta) / effect_size) ** 2
    n_total = int(np.ceil(n_per_group * (1 + ratio) ** 2 / (4 * ratio)))

    return n_total


def achieved_power(
    effect_size: float,
    n: int,
    alpha: float = 0.05
) -> float:
    """
    Calculate achieved power for a two-sample t-test.

    Args:
        effect_size: Cohen's d
        n: Sample size (per group, assuming equal)
        alpha: Significance level

    Returns:
        Statistical power (0-1)
    """
    from scipy.stats import norm

    n_per_group = n // 2

    # Non-centrality parameter
    ncp = effect_size * np.sqrt(n_per_group / 2)

    # Critical t-value
    t_crit = norm.ppf(1 - alpha / 2)

    # Power = P(T > t_crit | H1)
    power = 1 - stats.nct.cdf(t_crit, df=2*n_per_group - 2, ncparam=ncp)

    return power


# ═══════════════════════════════════════════════════════════════════════════════
# Multiple Testing Correction
# ═══════════════════════════════════════════════════════════════════════════════

def bonferroni_correction(
    p_values: np.ndarray,
    alpha: float = 0.05
) -> Tuple[np.ndarray, np.ndarray]:
    """
    Bonferroni correction for multiple testing.

    Controls family-wise error rate (FWER).

    Args:
        p_values: Array of p-values
        alpha: Original significance level

    Returns:
        (adjusted_p_values, rejected)
    """
    adjusted = np.minimum(p_values * len(p_values), 1.0)
    rejected = adjusted < alpha
    return adjusted, rejected


def benjamini_hochberg(
    p_values: np.ndarray,
    q: float = 0.05
) -> Tuple[np.ndarray, np.ndarray]:
    """
    Benjamini-Hochberg FDR correction.

    Controls false discovery rate (FDR).

    Args:
        p_values: Array of p-values
        q: Target FDR level

    Returns:
        (adjusted_p_values, rejected)
    """
    n = len(p_values)
    ranks = stats.rankdata(p_values)

    # Calculate adjusted p-values
    adjusted = p_values * n / ranks

    # Ensure monotonicity
    for i in range(n - 2, -1, -1):
        adjusted[i] = min(adjusted[i], adjusted[i + 1])

    adjusted = np.minimum(adjusted, 1.0)
    rejected = adjusted < q

    return adjusted, rejected


# ═══════════════════════════════════════════════════════════════════════════════
# Report Generation
# ═══════════════════════════════════════════════════════════════════════════════

def generate_report(
    experiments: List[Experiment],
    tests: List[TestResult],
    output_format: str = "markdown"
) -> str:
    """
    Generate statistical analysis report.

    Args:
        experiments: List of experiments
        tests: List of test results
        output_format: "markdown" or "json"

    Returns:
        Formatted report
    """
    if output_format == "markdown":
        lines = [
            "# Statistical Analysis Report",
            "",
            f"Generated: {np.datetime64('now')}",
            f"Total experiments: {len(experiments)}",
            f"Total tests: {len(tests)}",
            "",
            "## Summary",
            "",
        ]

        # Count significant results
        n_sig = sum(1 for t in tests if t.is_significant)
        lines.append(f"Significant results: {n_sig}/{len(tests)}")
        lines.append("")

        # Tests
        lines.append("## Test Results")
        lines.append("")
        for test in tests:
            sig_marker = "✅" if test.is_significant else "❌"
            lines.append(f"### {sig_marker} {test.test_name}")
            lines.append(f"- Statistic: {test.statistic:.4f}")
            lines.append(f"- P-value: {test.p_value:.4e}")
            if test.confidence_interval:
                lines.append(f"- CI: [{test.confidence_interval[0]:.4f}, {test.confidence_interval[1]:.4f}]")
            if test.effect_size is not None:
                lines.append(f"- Effect size: {test.effect_size:.3f}")
            lines.append(f"- Interpretation: {test.interpretation}")
            lines.append("")

        return "\n".join(lines)

    elif output_format == "json":
        import json
        return json.dumps([
            {
                "test_name": t.test_name,
                "statistic": t.statistic,
                "p_value": t.p_value,
                "is_significant": t.is_significant,
                "effect_size": t.effect_size,
                "interpretation": t.interpretation
            }
            for t in tests
        ], indent=2)


# ═══════════════════════════════════════════════════════════════════════════════
# Main (for testing)
# ═══════════════════════════════════════════════════════════════════════════════

if __name__ == "__main__":
    # Example usage

    # Simulate experimental data
    np.random.seed(42)

    # Treatment group: PPL values with HSLM
    ppl_hslm = np.array([125.3, 124.8, 125.1, 124.9, 125.5])

    # Control group: PPL values with baseline
    ppl_baseline = np.array([135.2, 134.8, 135.5, 134.1, 135.9])

    print("Trinity Statistical Analysis Toolkit")
    print("=" * 60)

    # Two-sample t-test
    test = two_sample_t_test(ppl_hslm, ppl_baseline)
    print(test)
    print()

    # Confidence intervals
    mean, lower, upper = confidence_interval(ppl_hslm)
    print(f"HSLM PPL: {mean:.2f} [{lower:.2f}, {upper:.2f}]")

    print()
    print("φ² + 1/φ² = 3 | TRINITY")
