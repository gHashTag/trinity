# Scientific Metrics V8 — Statistical Framework for Trinity S³AI

"""
Enhanced statistical reporting framework for Trinity S³AI experiments.

Provides:
- Confidence intervals (CI95, CI99)
- Effect sizes (Cohen's d, Hedges' g)
- Statistical significance tests (paired t-test, Wilcoxon)
- Multiple comparison correction (Bonferroni, Holm-Bonferroni)
- Power analysis for sample size determination

Author: Dmitrii Vasilev
Date: 2026-03-26
Version: 8.0.0
License: MIT
"""

from typing import List, Tuple, Dict, Optional, NamedTuple
from dataclasses import dataclass
import math
import numpy as np
from scipy import stats
from scipy.stats import t as t_dist


@dataclass
class ConfidenceInterval:
    """Confidence interval result."""
    lower: float
    upper: float
    level: float  # e.g., 0.95 for CI95
    margin_of_error: float


@dataclass
class EffectSize:
    """Effect size metrics."""
    cohens_d: float
    hedges_g: float
    interpretation: str  # "negligible", "small", "medium", "large", "very_large"


@dataclass
class SignificanceTest:
    """Statistical test result."""
    statistic: float
    p_value: float
    significant: bool
    alpha: float
    test_name: str


@dataclass
class StatisticalResult:
    """Complete statistical analysis result."""
    mean: float
    std: float
    std_error: float
    n: int
    ci: ConfidenceInterval
    effect_size: Optional[EffectSize] = None
    significance: Optional[SignificanceTest] = None


class Interpretation:
    """Effect size interpretation thresholds."""

    # Cohen's d thresholds
    NEGIGIBLE = 0.0
    SMALL = 0.2
    MEDIUM = 0.5
    LARGE = 0.8
    VERY_LARGE = 1.2

    @classmethod
    def cohens_d(cls, d: float) -> str:
        """Interpret Cohen's d effect size."""
        abs_d = abs(d)
        if abs_d < cls.SMALL:
            return "negligible"
        elif abs_d < cls.MEDIUM:
            return "small"
        elif abs_d < cls.LARGE:
            return "medium"
        elif abs_d < cls.VERY_LARGE:
            return "large"
        else:
            return "very_large"


def calculate_ci(
    values: List[float],
    confidence_level: float = 0.95,
) -> ConfidenceInterval:
    """
    Calculate confidence interval for a list of values.

    Args:
        values: List of measurements
        confidence_level: Confidence level (e.g., 0.95 for CI95)

    Returns:
        ConfidenceInterval with lower, upper bounds and margin of error
    """
    n = len(values)
    if n < 2:
        raise ValueError("Need at least 2 values for CI calculation")

    mean = np.mean(values)
    std = np.std(values, ddof=1)  # Sample std dev
    std_error = std / math.sqrt(n)

    # Student's t critical value
    alpha = 1.0 - confidence_level
    df = n - 1
    t_critical = t_dist.ppf(1.0 - alpha / 2.0, df)

    margin_of_error = t_critical * std_error

    return ConfidenceInterval(
        lower=mean - margin_of_error,
        upper=mean + margin_of_error,
        level=confidence_level,
        margin_of_error=margin_of_error,
    )


def calculate_effect_size(
    mean1: float,
    mean2: float,
    std1: float,
    std2: float,
    n1: int,
    n2: int,
) -> EffectSize:
    """
    Calculate Cohen's d and Hedges' g effect sizes.

    Args:
        mean1, mean2: Means of two groups
        std1, std2: Standard deviations of two groups
        n1, n2: Sample sizes of two groups

    Returns:
        EffectSize with Cohen's d, Hedges' g, and interpretation
    """
    # Pooled standard deviation
    pooled_var = ((n1 - 1) * std1**2 + (n2 - 1) * std2**2) / (n1 + n2 - 2)
    pooled_std = math.sqrt(pooled_var)

    # Cohen's d
    cohens_d = (mean2 - mean1) / pooled_std if pooled_std > 0 else 0.0

    # Hedges' g (bias-corrected for small samples)
    correction_factor = 1.0 - (3.0 / (4.0 * (n1 + n2) - 9.0))
    hedges_g = cohens_d * correction_factor

    return EffectSize(
        cohens_d=cohens_d,
        hedges_g=hedges_g,
        interpretation=Interpretation.cohens_d(cohens_d),
    )


def paired_t_test(
    values1: List[float],
    values2: List[float],
    alpha: float = 0.05,
) -> SignificanceTest:
    """
    Perform paired t-test for two related samples.

    Args:
        values1, values2: Paired measurements
        alpha: Significance level

    Returns:
        SignificanceTest with statistic, p-value, and significance flag
    """
    if len(values1) != len(values2):
        raise ValueError("Paired samples must have equal length")

    if len(values1) < 2:
        raise ValueError("Need at least 2 paired observations")

    # Calculate paired differences
    diffs = np.array(values2) - np.array(values1)

    # Paired t-test
    statistic, p_value = stats.ttest_rel(values1, values2)

    return SignificanceTest(
        statistic=statistic,
        p_value=p_value,
        significant=p_value < alpha,
        alpha=alpha,
        test_name="paired_t_test",
    )


def independent_t_test(
    values1: List[float],
    values2: List[float],
    alpha: float = 0.05,
    equal_var: bool = False,  # Welch's t-test by default
) -> SignificanceTest:
    """
    Perform independent t-test (Welch's) for two samples.

    Args:
        values1, values2: Two independent samples
        alpha: Significance level
        equal_var: If True, use standard t-test; otherwise Welch's

    Returns:
        SignificanceTest with statistic, p-value, and significance flag
    """
    statistic, p_value = stats.ttest_ind(values1, values2, equal_var=equal_var)

    return SignificanceTest(
        statistic=statistic,
        p_value=p_value,
        significant=p_value < alpha,
        alpha=alpha,
        test_name="welch_t_test" if not equal_var else "independent_t_test",
    )


def wilcoxon_test(
    values1: List[float],
    values2: List[float],
    alpha: float = 0.05,
) -> SignificanceTest:
    """
    Perform Wilcoxon signed-rank test for non-parametric comparison.

    Args:
        values1, values2: Paired measurements
        alpha: Significance level

    Returns:
        SignificanceTest with statistic, p-value, and significance flag
    """
    if len(values1) != len(values2):
        raise ValueError("Paired samples must have equal length")

    statistic, p_value = stats.wilcoxon(values1, values2)

    return SignificanceTest(
        statistic=statistic,
        p_value=p_value,
        significant=p_value < alpha,
        alpha=alpha,
        test_name="wilcoxon",
    )


def bonferroni_correction(p_values: List[float], alpha: float = 0.05) -> List[bool]:
    """
    Apply Bonferroni correction for multiple comparisons.

    Args:
        p_values: List of p-values from multiple tests
        alpha: Family-wise error rate

    Returns:
        List of booleans indicating which tests are significant after correction
    """
    corrected_alpha = alpha / len(p_values)
    return [p < corrected_alpha for p in p_values]


def holm_bonferroni(p_values: List[float], alpha: float = 0.05) -> List[bool]:
    """
    Apply Holm-Bonferroni correction (less conservative than Bonferroni).

    Args:
        p_values: List of p-values from multiple tests
        alpha: Family-wise error rate

    Returns:
        List of booleans indicating which tests are significant after correction
    """
    # Sort p-values with indices
    sorted_indices = sorted(range(len(p_values)), key=lambda i: p_values[i])
    sorted_p = [p_values[i] for i in sorted_indices]

    # Apply Holm step-down procedure
    results = [False] * len(p_values)
    k = len(p_values)

    for i, idx in enumerate(sorted_indices):
        corrected_alpha = alpha / (k - i)
        if sorted_p[i] < corrected_alpha:
            results[idx] = True
        else:
            # Stop at first non-significant result
            break

    return results


def analyze_group(
    values: List[float],
    confidence_level: float = 0.95,
    group_name: str = "Group",
) -> StatisticalResult:
    """
    Complete statistical analysis for a single group.

    Args:
        values: List of measurements
        confidence_level: Confidence level for CI (e.g., 0.95)
        group_name: Name for the group

    Returns:
        StatisticalResult with mean, std, CI
    """
    n = len(values)
    mean = np.mean(values)
    std = np.std(values, ddof=1)
    std_error = std / math.sqrt(n)
    ci = calculate_ci(values, confidence_level)

    return StatisticalResult(
        mean=mean,
        std=std,
        std_error=std_error,
        n=n,
        ci=ci,
    )


def compare_groups(
    values1: List[float],
    values2: List[float],
    confidence_level: float = 0.95,
    alpha: float = 0.05,
    group1_name: str = "Group 1",
    group2_name: str = "Group 2",
) -> Tuple[StatisticalResult, StatisticalResult, EffectSize, SignificanceTest]:
    """
    Complete statistical comparison between two groups.

    Args:
        values1, values2: Measurements from two groups
        confidence_level: Confidence level for CI
        alpha: Significance level for hypothesis test
        group1_name, group2_name: Names for groups

    Returns:
        Tuple of (result1, result2, effect_size, significance)
    """
    result1 = analyze_group(values1, confidence_level, group1_name)
    result2 = analyze_group(values2, confidence_level, group2_name)

    effect_size = calculate_effect_size(
        result1.mean, result2.mean,
        result1.std, result2.std,
        result1.n, result2.n,
    )

    significance = independent_t_test(values1, values2, alpha)

    return result1, result2, effect_size, significance


def format_markdown_table(
    results: Dict[str, StatisticalResult],
    precision: int = 4,
) -> str:
    """
    Format statistical results as a markdown table.

    Args:
        results: Dictionary mapping group names to StatisticalResult
        precision: Decimal places for values

    Returns:
        Markdown formatted table string
    """
    lines = [
        "| Group | N | Mean | Std | Std Error | CI95 Lower | CI95 Upper |",
        "|-------|---|------|-----|-----------|------------|------------|",
    ]

    for name, result in results.items():
        lines.append(
            f"| {name} | {result.n} | "
            f"{result.mean:.{precision}f} | "
            f"{result.std:.{precision}f} | "
            f"{result.std_error:.{precision}f} | "
            f"{result.ci.lower:.{precision}f} | "
            f"{result.ci.upper:.{precision}f} |"
        )

    return "\n".join(lines)


def format_comparison_table(
    comparisons: List[Tuple[str, str, EffectSize, SignificanceTest]],
    precision: int = 4,
) -> str:
    """
    Format group comparisons as a markdown table.

    Args:
        comparisons: List of (group1, group2, effect_size, significance) tuples
        precision: Decimal places for values

    Returns:
        Markdown formatted comparison table
    """
    lines = [
        "| Comparison | Cohen's d | Hedges' g | Interpretation | p-value | Significant @ α=0.05 |",
        "|------------|-----------|-----------|----------------|---------|---------------------|",
    ]

    for g1, g2, effect, sig in comparisons:
        significance_str = "✓ Yes" if sig.significant else "✗ No"
        lines.append(
            f"| {g1} vs {g2} | "
            f"{effect.cohens_d:.{precision}f} | "
            f"{effect.hedges_g:.{precision}f} | "
            f"{effect.interpretation} | "
            f"{sig.p_value:.{precision}e} | "
            f"{significance_str} |"
        )

    return "\n".join(lines)


def power_analysis(
    effect_size: float,
    alpha: float = 0.05,
    power: float = 0.80,
    ratio: float = 1.0,
) -> int:
    """
    Calculate required sample size for t-test using power analysis.

    Args:
        effect_size: Expected Cohen's d
        alpha: Significance level
        power: Desired statistical power (1 - β)
        ratio: Ratio of sample sizes (n2/n1)

    Returns:
        Required sample size per group
    """
    from scipy.stats import norm

    # Z values for alpha and power
    z_alpha = norm.ppf(1.0 - alpha / 2.0)
    z_beta = norm.ppf(power)

    # Sample size formula for two-sample t-test
    n_per_group = 2 * ((z_alpha + z_beta) / effect_size) ** 2

    # Adjust for unequal sample sizes
    if ratio != 1.0:
        n_per_group = n_per_group * (1 + ratio) / (2 * ratio)

    return math.ceil(n_per_group)


class ScientificMetrics:
    """
    Main class for scientific metrics calculation and reporting.

    Example:
        >>> metrics = ScientificMetrics()
        >>> results = metrics.analyze_experimental_data(
        ...     baseline=[100.5, 102.3, 99.8, 101.2],
        ...     treatment=[95.2, 96.8, 94.5, 97.1]
        ... )
        >>> print(results.to_markdown())
    """

    def __init__(self, confidence_level: float = 0.95, alpha: float = 0.05):
        self.confidence_level = confidence_level
        self.alpha = alpha

    def analyze_single_group(self, values: List[float], name: str) -> StatisticalResult:
        """Analyze a single group with full statistics."""
        return analyze_group(values, self.confidence_level, name)

    def compare_two_groups(
        self,
        values1: List[float],
        values2: List[float],
        name1: str,
        name2: str,
    ) -> Tuple[StatisticalResult, StatisticalResult, EffectSize, SignificanceTest]:
        """Compare two groups with full statistical analysis."""
        return compare_groups(
            values1, values2,
            self.confidence_level,
            self.alpha,
            name1, name2,
        )

    def multiple_comparisons(
        self,
        groups: Dict[str, List[float]],
        method: str = "holm",
    ) -> Dict[Tuple[str, str], Tuple[EffectSize, SignificanceTest]]:
        """
        Perform multiple pairwise comparisons with correction.

        Args:
            groups: Dictionary mapping group names to value lists
            method: Correction method ("bonferroni" or "holm")

        Returns:
            Dictionary mapping (group1, group2) to (effect_size, significance)
        """
        group_names = list(groups.keys())
        comparisons = {}
        p_values = []

        # Collect all p-values
        for i, name1 in enumerate(group_names):
            for name2 in group_names[i + 1:]:
                _, _, effect, sig = compare_groups(
                    groups[name1], groups[name2],
                    self.confidence_level, self.alpha,
                    name1, name2,
                )
                comparisons[(name1, name2)] = (effect, sig)
                p_values.append(sig.p_value)

        # Apply correction
        if method == "bonferroni":
            corrected = bonferroni_correction(p_values, self.alpha)
        elif method == "holm":
            corrected = holm_bonferroni(p_values, self.alpha)
        else:
            raise ValueError(f"Unknown correction method: {method}")

        # Update significance flags
        idx = 0
        for key in comparisons.keys():
            effect, sig = comparisons[key]
            comparisons[key] = (
                effect,
                SignificanceTest(
                    statistic=sig.statistic,
                    p_value=sig.p_value,
                    significant=corrected[idx],
                    alpha=self.alpha / len(p_values) if method == "bonferroni" else self.alpha,
                    test_name=f"{sig.test_name}_{method}",
                ),
            )
            idx += 1

        return comparisons


# Sacred-optimized constants for Trinity S³AI
PHI = 1.618033988749895
PHI_INV = 1.0 / PHI  # 0.618...
PHI_INV_SQ = PHI_INV ** 2  # 0.382...
PHI_INV_CUBED = PHI_INV ** 3  # 0.236...

# Sacred scaling parameters
SACRED_SCALE_EXPONENT = PHI_INV_CUBED  # ~0.236
SACRED_SPARSITY = PHI_INV_SQ  # ~0.382 (non-zero fraction)
SACRED_TARGET_SPARSITY = 1.0 - SACRED_SPARSITY  # ~0.618 (zero fraction)


if __name__ == "__main__":
    # Example: Analyze HSLM experimental results
    sacred = ScientificMetrics()

    # Simulated experimental data (replace with real data)
    baseline_ppl = [128.5, 127.9, 129.1, 128.2, 127.5]
    sacred_ppl = [125.1, 124.8, 125.9, 125.2, 124.5]

    # Single group analysis
    print("=== Baseline Analysis ===")
    baseline_result = sacred.analyze_single_group(baseline_ppl, "Baseline")
    print(f"Mean: {baseline_result.mean:.2f} ± {baseline_result.ci.margin_of_error:.2f}")
    print(f"CI95: [{baseline_result.ci.lower:.2f}, {baseline_result.ci.upper:.2f}]")

    print("\n=== Sacred Scaling Analysis ===")
    sacred_result = sacred.analyze_single_group(sacred_ppl, "Sacred")
    print(f"Mean: {sacred_result.mean:.2f} ± {sacred_result.ci.margin_of_error:.2f}")
    print(f"CI95: [{sacred_result.ci.lower:.2f}, {sacred_result.ci.upper:.2f}]")

    # Comparison
    print("\n=== Comparison ===")
    r1, r2, effect, sig = sacred.compare_two_groups(
        baseline_ppl, sacred_ppl, "Baseline", "Sacred"
    )
    print(f"Cohen's d: {effect.cohens_d:.3f} ({effect.interpretation})")
    print(f"p-value: {sig.p_value:.6f} (significant: {sig.significant})")
