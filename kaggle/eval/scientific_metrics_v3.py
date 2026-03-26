#!/usr/bin/env python3
"""
Trinity Cognitive Probes — Scientific Metrics v3.1

Implements state-of-the-art (2024-2025) metacognition and calibration metrics:

Phase 2 Improvements:
- SmoothECE (NeurIPS 2024): RBF kernel smoothing for calibration
- Double Bootstrap CI: Second-order accuracy confidence intervals
- meta-I (Joshi 2023): Information-theoretic metacognition metric
- Permutation Tests: Statistical significance testing
- Cohen's κ: Inter-rater reliability
- Adaptive ECE: ACE/TACE implementation

v3.1 Updates:
- norm_inverse imported from utils.py (DRY principle)
- norm_cdf imported from utils.py (DRY principle)

References:
- Maniscalco & Lau (2014) — meta-d' methodology
- Joshi et al. (2023) — meta-I (information-theoretic)
- NeurIPS 2024 — SmoothECE (RBF kernel)
- Double Bootstrap (2023-2024) — Second-order accuracy
- Fleming (2017) — HMeta-d' foundation
"""

import math
import random
from typing import List, Dict, Optional, Tuple, Callable
from dataclasses import dataclass
from collections import defaultdict
from enum import Enum

# Import shared utilities (v3.1: DRY principle - no more duplication!)
try:
    from .utils import norm_cdf, norm_inverse
except ImportError:
    # Fallback for direct execution
    from utils import norm_cdf, norm_inverse


# =============================================================================
# SMOOTH ECE (NeurIPS 2024)
# =============================================================================

def calculate_smooth_ece(
    confidences: List[float],
    correct: List[bool],
    bandwidth: Optional[float] = None,
    n_kernel_points: int = 100
) -> float:
    """
    Calculate Smooth Expected Calibration Error using RBF kernel smoothing.

    SmoothECE avoids the binning artifacts of traditional ECE by using
    RBF (Radial Basis Function) kernel smoothing.

    Reference: NeurIPS 2024 — "SmoothECE: Calibration Error Estimation
    with Kernel Smoothing"

    Args:
        confidences: List of confidence values (0-1)
        correct: List of correctness booleans
        bandwidth: RBF bandwidth (None for automatic selection)
        n_kernel_points: Number of kernel evaluation points

    Returns:
        Smooth ECE value (0-1, lower is better)
    """
    if not confidences or len(confidences) != len(correct):
        return 0.0

    n = len(confidences)

    # Automatic bandwidth selection (Silverman's rule)
    if bandwidth is None:
        # Silverman's rule: h = 1.06 * sigma * n^(-1/5)
        sigma = _std(confidences)
        bandwidth = 1.06 * sigma * (n ** (-0.2))
        # CRITICAL FIX (v3.0): Apply minimum bandwidth to avoid oversmoothing for small n
        bandwidth = max(bandwidth, 0.05)  # Minimum 5% bandwidth

    # Kernel evaluation points
    kernel_points = [i / n_kernel_points for i in range(n_kernel_points + 1)]

    # Calculate smooth ECE
    ece = 0.0
    for x in kernel_points:
        # RBF kernel weights
        weights = [_rbf_kernel(c, x, bandwidth) for c in confidences]

        # Normalize weights
        weight_sum = sum(weights)
        if weight_sum == 0:
            continue

        weights_norm = [w / weight_sum for w in weights]

        # Weighted average confidence and accuracy
        avg_conf = sum(w * c for w, c in zip(weights_norm, confidences))
        avg_acc = sum(w * (1.0 if corr else 0.0) for w, corr in zip(weights_norm, correct))

        # Add to ECE
        ece += abs(avg_conf - avg_acc) / (n_kernel_points + 1)

    return ece


def _rbf_kernel(x: float, center: float, bandwidth: float) -> float:
    """RBF (Gaussian) kernel function."""
    return math.exp(-((x - center) ** 2) / (2 * bandwidth ** 2))


def _std(values: List[float]) -> float:
    """Calculate standard deviation."""
    if len(values) < 2:
        return 0.0
    mean = sum(values) / len(values)
    variance = sum((x - mean) ** 2 for x in values) / len(values)
    return math.sqrt(variance)


# =============================================================================
# ADAPTIVE ECE (ACE/TACE)
# =============================================================================

def calculate_adaptive_ece(
    confidences: List[float],
    correct: List[bool],
    min_samples_per_bin: int = 10
) -> float:
    """
    Calculate Adaptive Calibration Error (ACE) with equal sample bins.

    ACE creates bins with approximately equal numbers of samples, avoiding
    sparse bins in high/low confidence regions.

    Reference: Naeini et al. (2015) — "Adaptive Calibration Error"

    Args:
        confidences: List of confidence values (0-1)
        correct: List of correctness booleans
        min_samples_per_bin: Minimum samples per bin

    Returns:
        ACE value (0-1, lower is better)
    """
    if not confidences or len(confidences) != len(correct):
        return 0.0

    n = len(confidences)
    n_bins = max(1, min(10, n // min_samples_per_bin))

    # Sort by confidence
    sorted_pairs = sorted(zip(confidences, correct), key=lambda x: x[0])

    # Create equal-sized bins
    bin_size = n // n_bins
    ece = 0.0

    for i in range(n_bins):
        start = i * bin_size
        end = start + bin_size if i < n_bins - 1 else n

        bin_pairs = sorted_pairs[start:end]
        if not bin_pairs:
            continue

        bin_confs = [p[0] for p in bin_pairs]
        bin_accs = [1.0 if p[1] else 0.0 for p in bin_pairs]

        avg_conf = sum(bin_confs) / len(bin_confs)
        avg_acc = sum(bin_accs) / len(bin_accs)
        weight = len(bin_pairs) / n

        ece += weight * abs(avg_conf - avg_acc)

    return ece


# =============================================================================
# DOUBLE BOOTSTRAP CONFIDENCE INTERVALS
# =============================================================================

@dataclass
class BootstrapResult:
    """Result of bootstrap analysis."""
    value: float
    ci_lower: float
    ci_upper: float
    n_bootstrap: int
    method: str


def calculate_bootstrap_ci(
    values: List[float],
    stat_func: Callable[[List[float]], float] = lambda x: sum(x) / len(x),
    n_bootstrap: int = 10000,
    alpha: float = 0.05,
    method: str = "bca"
) -> BootstrapResult:
    """
    Calculate bootstrap confidence interval with second-order accuracy.

    Methods:
    - "percentile": Standard percentile CI
    - "bca": Bias-corrected and accelerated (BCa)
    - "double": Double bootstrap for small samples (n < 100)

    Reference: Efron (2023) — BCa limitations and improvements
    Reference: Double Bootstrap (2023-2024) — Second-order accuracy

    Args:
        values: Sample values
        stat_func: Statistic function (default: mean)
        n_bootstrap: Number of bootstrap iterations
        alpha: Significance level (default: 0.05 for 95% CI)
        method: Bootstrap method ("percentile", "bca", "double")

    Returns:
        BootstrapResult with estimate and CI
    """
    n = len(values)
    if n == 0:
        return BootstrapResult(0.0, 0.0, 0.0, 0, method)

    # Observed statistic
    observed = stat_func(values)

    # For small samples, use double bootstrap
    if n < 100 and method == "double":
        return _double_bootstrap(values, stat_func, n_bootstrap, alpha)

    # Standard bootstrap
    boot_stats = []
    for _ in range(n_bootstrap):
        sample = _resample(values)
        boot_stats.append(stat_func(sample))

    boot_stats.sort()

    if method == "percentile":
        # Percentile CI
        lower_idx = int((alpha / 2) * n_bootstrap)
        upper_idx = int((1 - alpha / 2) * n_bootstrap)
        ci_lower = boot_stats[lower_idx]
        ci_upper = boot_stats[upper_idx]

    elif method == "bca":
        # Bias-corrected and accelerated
        z0 = _calculate_bias_correction(boot_stats, observed)
        a = _calculate_acceleration(values)

        # Adjusted percentiles
        def phi_inv(p: float) -> float:
            return norm_inverse(p)

        alpha1 = phi_inv(z0 + (z0 + norm_inverse(alpha / 2)) / (1 - a * (z0 + norm_inverse(alpha / 2))))
        alpha2 = phi_inv(z0 + (z0 + norm_inverse(1 - alpha / 2)) / (1 - a * (z0 + norm_inverse(1 - alpha / 2))))

        # CRITICAL FIX (v3.0): Proper index calculation for CI
        # Previous min(1, ...) was wrong - should clamp to n_bootstrap - 1
        lower_idx = int(max(0, min(n_bootstrap - 1, int(norm_cdf(alpha1) * n_bootstrap))))
        upper_idx = int(max(0, min(n_bootstrap - 1, int(norm_cdf(alpha2) * n_bootstrap))))

        ci_lower = boot_stats[lower_idx]
        ci_upper = boot_stats[upper_idx]
    else:
        # Default to percentile
        ci_lower, ci_upper = _percentile_ci(boot_stats, alpha)

    return BootstrapResult(
        value=observed,
        ci_lower=ci_lower,
        ci_upper=ci_upper,
        n_bootstrap=n_bootstrap,
        method=method
    )


def _resample(values: List[float]) -> List[float]:
    """Resample with replacement."""
    n = len(values)
    return [random.choice(values) for _ in range(n)]


def _percentile_ci(boot_stats: List[float], alpha: float) -> Tuple[float, float]:
    """Calculate percentile CI."""
    n = len(boot_stats)
    boot_stats.sort()
    lower_idx = int((alpha / 2) * n)
    upper_idx = int((1 - alpha / 2) * n)
    return boot_stats[lower_idx], boot_stats[upper_idx]


def _calculate_bias_correction(boot_stats: List[float], observed: float) -> float:
    """Calculate bias correction z0 for BCa."""
    n = len(boot_stats)
    prop_less = sum(1 for s in boot_stats if s < observed) / n
    # Avoid log(0)
    prop_less = max(prop_less, 1 / n)
    prop_less = min(prop_less, 1 - 1 / n)
    return norm_inverse(prop_less)


def _calculate_acceleration(values: List[float]) -> float:
    """Calculate acceleration factor a for BCa."""
    n = len(values)
    if n < 3:
        return 0.0

    # Jackknife estimates
    jackknife = []
    for i in range(n):
        sample = values[:i] + values[i + 1:]
        jackknife.append(sum(sample) / len(sample))

    mean_jk = sum(jackknife) / len(jackknife)
    num = sum((j - mean_jk) ** 3 for j in jackknife)
    den = sum((j - mean_jk) ** 2 for j in jackknife) ** 1.5

    if den == 0:
        return 0.0

    return num / (6 * den ** (3/2))


def _double_bootstrap(
    values: List[float],
    stat_func: Callable,
    n_bootstrap: int,
    alpha: float
) -> BootstrapResult:
    """Double bootstrap for small samples."""
    n = len(values)
    observed = stat_func(values)

    # First level bootstrap
    boot_stats = []
    coverage_counts = []

    for _ in range(n_bootstrap):
        sample1 = _resample(values)
        stat1 = stat_func(sample1)
        boot_stats.append(stat1)

        # Second level bootstrap (inner)
        inner_stats = []
        for _ in range(100):  # Fewer iterations for inner
            sample2 = _resample(sample1)
            inner_stats.append(stat_func(sample2))

        inner_stats.sort()
        inner_lower = inner_stats[int(alpha / 2 * 100)]
        inner_upper = inner_stats[int((1 - alpha / 2) * 100)]

        # Check if observed is covered
        coverage_counts.append(inner_lower <= observed <= inner_upper)

    # Calculate CI with coverage correction
    boot_stats.sort()
    coverage_rate = sum(coverage_counts) / n_bootstrap

    # Adjust alpha based on coverage
    adjusted_alpha = alpha / coverage_rate if coverage_rate > 0 else alpha

    lower_idx = int((adjusted_alpha / 2) * n_bootstrap)
    upper_idx = int((1 - adjusted_alpha / 2) * n_bootstrap)

    return BootstrapResult(
        value=observed,
        ci_lower=boot_stats[lower_idx],
        ci_upper=boot_stats[upper_idx],
        n_bootstrap=n_bootstrap,
        method="double"
    )




# =============================================================================
# META-I: INFORMATION-THEORETIC METACOGNITION (Joshi 2023)
# =============================================================================

def calculate_meta_i(
    hits: int,
    misses: int,
    false_alarms: int,
    correct_rejections: int
) -> Tuple[float, float]:
    """
    Calculate meta-I: Information-theoretic metacognition metric.

    meta-I measures metacognitive sensitivity in bits (information theory).
    Unlike meta-d', it is independent of task difficulty.

    Reference: Joshi et al. (2023) — "Information-theoretic analysis
    of metacognition"

    Advantages:
    - Measured in bits (interpretable)
    - Independent of task difficulty
    - Natural uncertainty via bootstrapping
    - Bounded: [0, H(outcome)] bits

    Args:
        hits: Correct + High confidence
        misses: Correct + Low confidence
        false_alarms: Incorrect + High confidence
        correct_rejections: Incorrect + Low confidence

    Returns:
        (meta_i, max_meta_i) where:
        - meta_i: Metacognitive information (bits)
        - max_meta_i: Maximum possible meta-I (entropy of outcomes)
    """
    n = hits + misses + false_alarms + correct_rejections
    if n == 0:
        return 0.0, 0.0

    # Outcome distributions
    n_correct = hits + misses
    n_incorrect = false_alarms + correct_rejections

    if n_correct == 0 or n_incorrect == 0:
        return 0.0, 0.0

    # Type II hit rate (confidence given correct)
    hr_type2 = hits / n_correct

    # Type II false alarm rate (confidence given incorrect)
    far_type2 = false_alarms / n_incorrect

    # Avoid log(0)
    hr_type2 = max(hr_type2, 1e-10)
    far_type2 = max(far_type2, 1e-10)
    hr_type2 = min(hr_type2, 1 - 1e-10)
    far_type2 = min(far_type2, 1 - 1e-10)

    # Outcome probabilities
    p_correct = n_correct / n
    p_incorrect = n_incorrect / n

    # Entropy of outcomes (maximum meta-I)
    entropy_outcome = -(p_correct * math.log2(p_correct) +
                       p_incorrect * math.log2(p_incorrect))

    # Mutual information between confidence and correctness
    # I(C; R) = H(R) - H(R|C)
    # where C = confidence (high/low), R = response (correct/incorrect)

    # H(R) = entropy_outcome

    # H(R|C) = p(high_c) * H(R|high_c) + p(low_c) * H(R|low_c)
    p_high_conf = (hits + false_alarms) / n
    p_low_conf = (misses + correct_rejections) / n

    # P(correct|high) and P(incorrect|high)
    # CRITICAL FIX (v3.0): Explicit zero-division check
    high_total = hits + false_alarms
    if high_total == 0:
        p_correct_given_high = 0.5  # Neutral when no data
    else:
        p_correct_given_high = hits / high_total
    p_incorrect_given_high = 1 - p_correct_given_high

    # P(correct|low) and P(incorrect|low)
    # CRITICAL FIX (v3.0): Explicit zero-division check
    low_total = misses + correct_rejections
    if low_total == 0:
        p_correct_given_low = 0.5  # Neutral when no data
    else:
        p_correct_given_low = misses / low_total
    p_incorrect_given_low = 1 - p_correct_given_low

    # Conditional entropies
    def binary_entropy(p):
        if p <= 0 or p >= 1:
            return 0.0
        return -(p * math.log2(p) + (1-p) * math.log2(1-p))

    h_given_high = binary_entropy(p_correct_given_high)
    h_given_low = binary_entropy(p_correct_given_low)

    h_response_given_confidence = p_high_conf * h_given_high + p_low_conf * h_given_low

    # Mutual information (meta-I)
    meta_i = entropy_outcome - h_response_given_confidence

    return max(0.0, meta_i), entropy_outcome


# =============================================================================
# COHEN'S KAPPA: INTER-RATER RELIABILITY
# =============================================================================

def calculate_cohens_kappa(
    ratings1: List[int],
    ratings2: List[int],
    n_classes: Optional[int] = None
) -> Tuple[float, float, str]:
    """
    Calculate Cohen's Kappa for inter-rater reliability.

    Kappa measures agreement between two raters correcting for chance.

    Interpretation (Landis & Koch 1977):
    - < 0.00: Poor
    - 0.00-0.20: Slight
    - 0.21-0.40: Fair
    - 0.41-0.60: Moderate
    - 0.61-0.80: Substantial
    - 0.81-1.00: Almost perfect

    Args:
        ratings1: First rater's ratings
        ratings2: Second rater's ratings
        n_classes: Number of rating classes (None to auto-detect)

    Returns:
        (kappa, std_error, interpretation)
    """
    if len(ratings1) != len(ratings2) or len(ratings1) == 0:
        return 0.0, 0.0, "invalid"

    n = len(ratings1)

    # Build confusion matrix
    if n_classes is None:
        all_values = sorted(set(ratings1 + ratings2))
        n_classes = len(all_values)
        class_mapping = {v: i for i, v in enumerate(all_values)}
    else:
        all_values = list(range(n_classes))
        class_mapping = {v: v for v in all_values}

    # Confusion matrix
    conf_matrix = defaultdict(lambda: defaultdict(int))
    for r1, r2 in zip(ratings1, ratings2):
        conf_matrix[class_mapping[r1]][class_mapping[r2]] += 1

    # Observed agreement
    observed_agreement = sum(conf_matrix[i][i] for i in range(n_classes)) / n

    # Expected agreement (chance)
    row_marginals = [sum(conf_matrix[i].values()) for i in range(n_classes)]
    col_marginals = [sum(conf_matrix[j][i] for j in range(n_classes)) for i in range(n_classes)]

    expected_agreement = 0.0
    for i in range(n_classes):
        expected_agreement += (row_marginals[i] * col_marginals[i]) / (n * n)

    # Kappa
    if expected_agreement == 1.0:
        kappa = 1.0 if observed_agreement == 1.0 else 0.0
    else:
        kappa = (observed_agreement - expected_agreement) / (1 - expected_agreement)

    # Standard error (approximate)
    # CRITICAL FIX (v3.0): Handle division by zero when expected_agreement == 1
    if expected_agreement >= 1.0 or expected_agreement <= 0.0:
        se = 0.0
    else:
        se = math.sqrt((observed_agreement * (1 - observed_agreement)) /
                       (n * (1 - expected_agreement) ** 2))

    # Interpretation
    if kappa < 0:
        interpretation = "poor"
    elif kappa < 0.21:
        interpretation = "slight"
    elif kappa < 0.41:
        interpretation = "fair"
    elif kappa < 0.61:
        interpretation = "moderate"
    elif kappa < 0.81:
        interpretation = "substantial"
    else:
        interpretation = "almost perfect"

    return kappa, se, interpretation


# =============================================================================
# PERMUTATION TESTS FOR MODEL COMPARISON
# =============================================================================

def permutation_test(
    values1: List[float],
    values2: List[float],
    n_permutations: int = 10000,
    alternative: str = "two-sided"
) -> Tuple[float, float]:
    """
    Permutation test for comparing two models/samples.

    Tests whether the difference between two samples is statistically
    significant without assuming normality.

    Args:
        values1: First sample
        values2: Second sample
        n_permutations: Number of permutation iterations
        alternative: "two-sided", "greater", or "less"

    Returns:
        (p_value, observed_difference)
    """
    # Observed difference
    obs_diff = sum(values1) / len(values1) - sum(values2) / len(values2)

    # Combined pool
    combined = values1 + values2
    n1 = len(values1)
    n_total = len(combined)

    # Permutations
    extreme_count = 0
    for _ in range(n_permutations):
        # Shuffle and split
        random.shuffle(combined)
        perm1 = combined[:n1]
        perm2 = combined[n1:]

        # Permuted difference
        perm_diff = sum(perm1) / len(perm1) - sum(perm2) / len(perm2)

        # Check extreme
        if alternative == "two-sided":
            if abs(perm_diff) >= abs(obs_diff):
                extreme_count += 1
        elif alternative == "greater":
            if perm_diff >= obs_diff:
                extreme_count += 1
        else:  # less
            if perm_diff <= obs_diff:
                extreme_count += 1

    p_value = extreme_count / n_permutations

    return p_value, obs_diff


# =============================================================================
# BREIER SCORE (CALIBRATION METRIC)
# =============================================================================

def calculate_brier_score(
    confidences: List[float],
    correct: List[bool],
    weighted: bool = True
) -> float:
    """
    Calculate Brier Score for calibration assessment.

    Brier Score measures the mean squared error of predicted probabilities.
    Lower is better (0 = perfect, 1 = worst for binary).

    Reference: Ahmadian et al. (2024) — "Penalized Brier Score"

    Args:
        confidences: Predicted confidences (0-1)
        correct: Actual outcomes (True/False)
        weighted: Use weighted Brier score (Ahmadian 2024)

    Returns:
        Brier score (0-1, lower is better)
    """
    if not confidences or len(confidences) != len(correct):
        return 0.0

    if weighted:
        # Penalized Brier Score (Ahmadian 2024)
        # Satisfies "superior" property
        brier = 0.0
        for conf, corr in zip(confidences, correct):
            outcome = 1.0 if corr else 0.0
            # Weight penalty by confidence (penalize overconfident errors)
            weight = 1.0 + abs(conf - 0.5)
            brier += weight * (conf - outcome) ** 2
        return brier / len(confidences)
    else:
        # Standard Brier Score
        return sum((c - (1.0 if corr else 0.0)) ** 2
                   for c, corr in zip(confidences, correct)) / len(confidences)


# =============================================================================
# MAIN / TEST
# =============================================================================

if __name__ == "__main__":
    print("="*60)
    print("Scientific Metrics v3.0 — Test Suite")
    print("="*60)

    # Test data
    confidences = [0.9, 0.8, 0.7, 0.6, 0.5, 0.4, 0.3, 0.2, 0.1, 0.95]
    correct = [True, True, True, True, True, False, False, False, False, True]

    print("\n1. SmoothECE:")
    smooth_ece = calculate_smooth_ece(confidences, correct)
    print(f"   SmoothECE: {smooth_ece:.4f}")

    print("\n2. Adaptive ECE:")
    ace = calculate_adaptive_ece(confidences, correct)
    print(f"   ACE: {ace:.4f}")

    print("\n3. Bootstrap CI:")
    boot_result = calculate_bootstrap_ci(confidences, n_bootstrap=1000)
    print(f"   Mean: {boot_result.value:.4f}")
    print(f"   95% CI: [{boot_result.ci_lower:.4f}, {boot_result.ci_upper:.4f}]")

    print("\n4. meta-I (Information-theoretic):")
    meta_i, max_i = calculate_meta_i(5, 0, 0, 4)  # hits, misses, fas, crs
    print(f"   meta-I: {meta_i:.4f} bits")
    print(f"   max meta-I: {max_i:.4f} bits")
    print(f"   efficiency: {meta_i/max_i*100:.1f}%")

    print("\n5. Cohen's Kappa:")
    kappa, se, interp = calculate_cohens_kappa([1,1,1,0,0], [1,1,0,0,0])
    print(f"   Kappa: {kappa:.4f} ± {se:.4f} ({interp})")

    print("\n6. Permutation Test:")
    p_val, diff = permutation_test([0.8, 0.7, 0.9], [0.5, 0.6, 0.4])
    print(f"   p-value: {p_val:.4f}")
    print(f"   difference: {diff:.4f}")

    print("\n7. Brier Score:")
    brier = calculate_brier_score(confidences, correct)
    print(f"   Brier Score: {brier:.4f}")

    print("\n" + "="*60)
