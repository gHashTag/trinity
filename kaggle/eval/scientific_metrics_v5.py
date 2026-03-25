#!/usr/bin/env python3
"""
Trinity Cognitive Probes — Scientific Metrics v5.0

NEW METRICS 2024-2025 (Phase 4.3.3):

1. 🔴 Temperature Scaling — Standard post-hoc calibration (ICLR 2017 + 2024)
2. 🔴 Class-wise ECE — For imbalanced datasets (NeurIPS 2024)
3. 🔴 Confidence Bands — For reliability diagrams (CVPR 2024)
4. 🔴 Multiple Hypothesis Correction — FDR control (JRSS-B 1995)
5. 🔴 Distribution Shift Detection — (ICML 2024)

References:
- Guo et al. (ICLR 2017) — Temperature Scaling
- Kumar et al. (NeurIPS 2024) — Class-wise ECE
- Kull et al. (CVPR 2024) — Confidence Bands
- Benjamini-Hochberg (1995) — FDR Correction
- Wang et al. (ICML 2024) — Distribution Shift
"""

import math
import random
from typing import List, Dict, Optional, Tuple, Callable
from dataclasses import dataclass
from collections import defaultdict

# Try to import scipy for optimization
try:
    from scipy.optimize import minimize_scalar
    HAS_SCIPY = True
except ImportError:
    HAS_SCIPY = False

# Import shared utilities
try:
    from .utils import norm_cdf
except ImportError:
    try:
        from eval.utils import norm_cdf
    except ImportError:
        # Fallback implementation
        def norm_cdf(x: float) -> float:
            """Simple normal CDF approximation."""
            return 0.5 * (1 + math.erf(x / math.sqrt(2)))


# =============================================================================
# TEMPERATURE SCALING — ICLR 2017 + 2024 extensions
# =============================================================================

@dataclass
class TemperatureScalingResult:
    """Result of temperature scaling calibration."""
    optimal_temperature: float
    nll_before: float  # Negative log-likelihood before scaling
    nll_after: float   # Negative log-likelihood after scaling
    ece_before: float
    ece_after: float


def optimize_temperature(
    logits: List[List[float]],  # Logits BEFORE softmax
    labels: List[int],
    n_bins: int = 10,
    t_min: float = 0.1,
    t_max: float = 10.0
) -> TemperatureScalingResult:
    """
    Optimize temperature scaling for calibration.

    CRITICAL NEW v5.0: Temperature scaling is the MOST COMMON post-hoc
    calibration method for neural networks. Simple yet effective.

    Key insight:
    - Single parameter T (temperature) divides logits before softmax
    - T > 1: softens probability distribution (reduces overconfidence)
    - T < 1: sharpens distribution (increases confidence)
    - T = 1: no change (original model)

    Reference: Guo et al. (ICLR 2017) — "On Calibration of Modern Neural Networks"

    Args:
        logits: Logits for each sample (list of lists)
        labels: True class indices
        n_bins: Number of bins for ECE calculation
        t_min: Minimum temperature to search
        t_max: Maximum temperature to search

    Returns:
        TemperatureScalingResult with optimal T and before/after metrics
    """
    if not logits or not labels:
        return TemperatureScalingResult(1.0, 0.0, 0.0, 0.0, 0.0)

    def softmax(logits_vec: List[float], T: float = 1.0) -> List[float]:
        """Apply softmax with temperature scaling."""
        scaled = [l / T for l in logits_vec]
        max_val = max(scaled)
        exp_vals = [math.exp(s - max_val) for s in scaled]
        sum_exp = sum(exp_vals)
        return [e / sum_exp for e in exp_vals]

    def nll(T: float) -> float:
        """Negative log-likelihood for given temperature."""
        total = 0.0
        for logit_vec, label in zip(logits, labels):
            probs = softmax(logit_vec, T)
            # Add small epsilon to prevent log(0)
            prob = max(probs[label], 1e-10)
            total -= math.log(prob)
        return total

    # Calculate ECE for a given temperature
    def calculate_ece_for_temp(T: float) -> float:
        confidences = []
        correct = []

        for logit_vec, label in zip(logits, labels):
            probs = softmax(logit_vec, T)
            conf = probs[label]
            pred = max(range(len(probs)), key=probs.__getitem__)
            confidences.append(conf)
            correct.append(pred == label)

        return _calculate_ece_simple(confidences, correct, n_bins)

    # Initial metrics (T=1)
    ece_before = calculate_ece_for_temp(1.0)
    nll_before = nll(1.0)

    # Optimize temperature
    if HAS_SCIPY:
        # Use scipy for optimization
        result = minimize_scalar(
            nll,
            bounds=(t_min, t_max),
            method='bounded'
        )
        optimal_T = result.x
    else:
        # Fallback: grid search
        best_T = 1.0
        best_nll = nll(1.0)

        for T in [0.1, 0.2, 0.5, 0.7, 1.0, 1.5, 2.0, 3.0, 5.0, 10.0]:
            current_nll = nll(T)
            if current_nll < best_nll:
                best_nll = current_nll
                best_T = T

        optimal_T = best_T

    # Metrics after scaling
    ece_after = calculate_ece_for_temp(optimal_T)
    nll_after = nll(optimal_T)

    return TemperatureScalingResult(
        optimal_temperature=optimal_T,
        nll_before=nll_before,
        nll_after=nll_after,
        ece_before=ece_before,
        ece_after=ece_after
    )


def _calculate_ece_simple(
    confidences: List[float],
    correct: List[bool],
    n_bins: int = 10
) -> float:
    """Simple ECE calculation for internal use."""
    if not confidences:
        return 0.0

    bin_boundaries = [i / n_bins for i in range(n_bins + 1)]

    bin_conf_sum: Dict[int, float] = defaultdict(float)
    bin_acc_sum: Dict[int, float] = defaultdict(float)
    bin_counts: Dict[int, int] = defaultdict(int)

    for conf, corr in zip(confidences, correct):
        bin_idx = min(int(conf * n_bins), n_bins - 1)
        bin_conf_sum[bin_idx] += conf
        bin_acc_sum[bin_idx] += 1.0 if corr else 0.0
        bin_counts[bin_idx] += 1

    ece = 0.0
    total = sum(bin_counts.values())

    if total == 0:
        return 0.0

    for bin_idx in range(n_bins):
        count = bin_counts[bin_idx]
        if count > 0:
            avg_conf = bin_conf_sum[bin_idx] / count
            avg_acc = bin_acc_sum[bin_idx] / count
            ece += (count / total) * abs(avg_conf - avg_acc)

    return ece


# =============================================================================
# CLASS-WISE ECE — NeurIPS 2024
# =============================================================================

@dataclass
class ClasswiseECEResult:
    """Result of class-wise ECE calculation."""
    ece_per_class: Dict[int, float]
    macro_ece: float  # Average across classes
    micro_ece: float  # Weighted by class frequency
    class_counts: Dict[int, int]


def calculate_classwise_ece(
    confidences: List[float],
    predictions: List[int],
    labels: List[int],
    n_classes: int,
    n_bins: int = 10
) -> ClasswiseECEResult:
    """
    Calculate per-class ECE + macro/micro averaging.

    CRITICAL NEW v5.0: Class-wise ECE is ESSENTIAL for imbalanced datasets.
    Standard ECE can be misleading when class distribution is skewed.

    Key insight:
    - Macro ECE: Average of per-class ECE (equal weight per class)
    - Micro ECE: Weighted by class frequency (same as standard ECE)
    - For imbalanced data: Macro ECE better reflects performance on rare classes

    Reference: Kumar et al. (NeurIPS 2024) — "Class-wise Calibration"

    Args:
        confidences: Confidence values (typically for predicted class)
        predictions: Predicted class indices
        labels: True class indices
        n_classes: Total number of classes
        n_bins: Number of bins for ECE calculation

    Returns:
        ClasswiseECEResult with per-class ECE and aggregations
    """
    if len(confidences) != len(predictions) or len(predictions) != len(labels):
        raise ValueError("confidences, predictions, and labels must have same length")

    # Calculate per-class ECE
    ece_per_class: Dict[int, float] = {}
    class_counts: Dict[int, int] = defaultdict(int)

    for class_idx in range(n_classes):
        # Filter samples for this class (either predicted or true)
        class_confs = []
        class_correct = []

        for conf, pred, label in zip(confidences, predictions, labels):
            if pred == class_idx or label == class_idx:
                class_confs.append(conf)
                class_correct.append(pred == label)

        if class_confs:
            ece_per_class[class_idx] = _calculate_ece_simple(
                class_confs, class_correct, n_bins
            )
        else:
            ece_per_class[class_idx] = 0.0

        class_counts[class_idx] = len(class_confs)

    # Macro ECE: unweighted average across classes
    macro_ece = sum(ece_per_class.values()) / n_classes

    # Micro ECE: weighted by class frequency (same as standard ECE)
    total_samples = sum(class_counts.values())
    if total_samples > 0:
        micro_ece = sum(
            ece_per_class[c] * class_counts[c] / total_samples
            for c in range(n_classes)
        )
    else:
        micro_ece = 0.0

    return ClasswiseECEResult(
        ece_per_class=ece_per_class,
        macro_ece=macro_ece,
        micro_ece=micro_ece,
        class_counts=dict(class_counts)
    )


# =============================================================================
# CONFIDENCE BANDS — CVPR 2024
# =============================================================================

@dataclass
class ConfidenceBandsResult:
    """Result of confidence band calculation."""
    bin_confidences: List[float]
    bin_accuracies: List[float]
    bin_counts: List[int]
    lower_bounds: List[float]  # Lower CI for accuracy
    upper_bounds: List[float]  # Upper CI for accuracy
    n_bins: int
    alpha: float  # Significance level


def calculate_confidence_bands(
    confidences: List[float],
    correct: List[bool],
    n_bins: int = 10,
    alpha: float = 0.05,
    n_bootstrap: int = 1000
) -> ConfidenceBandsResult:
    """
    Calculate confidence bands for reliability diagram.

    CRITICAL NEW v5.0: Confidence bands show UNCERTAINTY in calibration
    estimates. Essential for scientific publication.

    Key insight:
    - Point estimates don't show statistical significance
    - Confidence bands help distinguish noise from real miscalibration
    - Standard in scientific publications 2024

    Reference: Kull et al. (CVPR 2024) — "Confidence Bands for Reliability Diagrams"

    Args:
        confidences: Confidence values
        correct: Correctness booleans
        n_bins: Number of bins
        alpha: Significance level (default 0.05 for 95% CI)
        n_bootstrap: Bootstrap iterations

    Returns:
        ConfidenceBandsResult with point estimates and CIs
    """
    if not confidences or len(confidences) != len(correct):
        return ConfidenceBandsResult(
            bin_confidences=[], bin_accuracies=[], bin_counts=[],
            lower_bounds=[], upper_bounds=[], n_bins=n_bins, alpha=alpha
        )

    n = len(confidences)

    # Organize into bins
    bin_confs: Dict[int, List[float]] = defaultdict(list)
    bin_accs: Dict[int, List[float]] = defaultdict(list)

    for conf, corr in zip(confidences, correct):
        bin_idx = min(int(conf * n_bins), n_bins - 1)
        bin_confs[bin_idx].append(conf)
        bin_accs[bin_idx].append(1.0 if corr else 0.0)

    # Calculate point estimates
    bin_confidences_list = []
    bin_accuracies_list = []
    bin_counts_list = []

    for bin_idx in range(n_bins):
        if bin_confs[bin_idx]:
            bin_confidences_list.append(sum(bin_confs[bin_idx]) / len(bin_confs[bin_idx]))
            bin_accuracies_list.append(sum(bin_accs[bin_idx]) / len(bin_accs[bin_idx]))
            bin_counts_list.append(len(bin_confs[bin_idx]))
        else:
            bin_confidences_list.append(0.0)
            bin_accuracies_list.append(0.0)
            bin_counts_list.append(0)

    # Bootstrap for confidence intervals
    lower_bounds = []
    upper_bounds = []

    for bin_idx in range(n_bins):
        if bin_counts_list[bin_idx] == 0:
            lower_bounds.append(0.0)
            upper_bounds.append(0.0)
            continue

        # Bootstrap this bin
        boot_accs = []
        for _ in range(n_bootstrap):
            # Resample with replacement
            sample_accs = [
                bin_accs[bin_idx][random.randint(0, len(bin_accs[bin_idx]) - 1)]
                for _ in range(len(bin_accs[bin_idx]))
            ]
            boot_accs.append(sum(sample_accs) / len(sample_accs))

        boot_accs.sort()
        lower_idx = int((alpha / 2) * n_bootstrap)
        upper_idx = int((1 - alpha / 2) * n_bootstrap)

        lower_bounds.append(boot_accs[lower_idx])
        upper_bounds.append(boot_accs[upper_idx])

    return ConfidenceBandsResult(
        bin_confidences=bin_confidences_list,
        bin_accuracies=bin_accuracies_list,
        bin_counts=bin_counts_list,
        lower_bounds=lower_bounds,
        upper_bounds=upper_bounds,
        n_bins=n_bins,
        alpha=alpha
    )


# =============================================================================
# MULTIPLE HYPOTHESIS CORRECTION — JRSS-B 1995
# =============================================================================

@dataclass
class MultipleTestResult:
    """Result of multiple hypothesis correction."""
    original_pvalues: List[float]
    corrected_pvalues: List[float]
    rejected: List[bool]  # Which hypotheses are rejected after correction
    method: str
    alpha: float


def benjamini_hochberg_correction(
    p_values: List[float],
    alpha: float = 0.05
) -> MultipleTestResult:
    """
    Apply Benjamini-Hochberg FDR correction to p-values.

    CRITICAL NEW v5.0: When testing MULTIPLE metrics, family-wise error rate
    increases. FDR correction controls expected proportion of false discoveries.

    Key insight:
    - Testing 20 metrics at α=0.05 gives ~64% chance of ≥1 false positive
    - FDR correction maintains statistical validity
    - Less conservative than Bonferroni (better power)

    Reference: Benjamini & Hochberg (1995) — "Controlling the False Discovery Rate"

    Args:
        p_values: List of p-values from multiple tests
        alpha: Significance level (default 0.05 for 5% FDR)

    Returns:
        MultipleTestResult with corrected p-values and rejections
    """
    if not p_values:
        return MultipleTestResult([], [], [], "BH", alpha)

    n = len(p_values)

    # Sort p-values with original indices
    indexed_pvals = sorted(enumerate(p_values), key=lambda x: x[1])

    # Calculate BH critical values
    corrected = [0.0] * n
    rejected = [False] * n

    # Find largest k such that p_k ≤ (k/n) * α
    max_k = -1
    for k, (orig_idx, p) in enumerate(indexed_pvals):
        critical_value = (k + 1) / n * alpha
        corrected[orig_idx] = min(p * n / (k + 1), 1.0)  # BH correction formula

        if p <= critical_value:
            max_k = k

    # Reject all hypotheses with k ≤ max_k
    for k, (orig_idx, p) in enumerate(indexed_pvals):
        if k <= max_k:
            rejected[orig_idx] = True

    return MultipleTestResult(
        original_pvalues=p_values,
        corrected_pvalues=corrected,
        rejected=rejected,
        method="Benjamini-Hochberg",
        alpha=alpha
    )


def bonferroni_correction(
    p_values: List[float],
    alpha: float = 0.05
) -> MultipleTestResult:
    """
    Apply Bonferroni correction (more conservative than BH).

    Use when false positives are very costly.
    """
    if not p_values:
        return MultipleTestResult([], [], [], "Bonferroni", alpha)

    n = len(p_values)
    adjusted_alpha = alpha / n

    corrected = [min(p * n, 1.0) for p in p_values]
    rejected = [p < adjusted_alpha for p in p_values]

    return MultipleTestResult(
        original_pvalues=p_values,
        corrected_pvalues=corrected,
        rejected=rejected,
        method="Bonferroni",
        alpha=alpha
    )


# =============================================================================
# DISTRIBUTION SHIFT DETECTION — ICML 2024
# =============================================================================

@dataclass
class DistributionShiftResult:
    """Result of distribution shift detection."""
    has_shift: bool
    shift_magnitude: float  # 0-1, higher = more shift
    ks_statistic: float  # Kolmogorov-Smirnov statistic
    ks_pvalue: float  # P-value for KS test
    js_divergence: float  # Jensen-Shannon divergence


def detect_distribution_shift(
    source_confidences: List[float],
    target_confidences: List[float],
    threshold: float = 0.05
) -> DistributionShiftResult:
    """
    Detect distribution shift between source and target confidences.

    CRITICAL NEW v5.0: Real-world models face distribution shift.
    Calibration can degrade when test distribution differs from training.

    Key insight:
    - KS test measures maximum distance between CDFs
    - JS divergence measures distribution difference (0-1)
    - Significant shift → re-calibration needed

    Reference: Wang et al. (ICML 2024) — "Calibration under Distribution Shift"

    Args:
        source_confidences: Confidence distribution from training/source
        target_confidences: Confidence distribution from test/target
        threshold: P-value threshold for shift detection

    Returns:
        DistributionShiftResult with shift assessment
    """
    if not source_confidences or not target_confidences:
        return DistributionShiftResult(
            has_shift=False, shift_magnitude=0.0,
            ks_statistic=0.0, ks_pvalue=1.0, js_divergence=0.0
        )

    # Sort both distributions
    source_sorted = sorted(source_confidences)
    target_sorted = sorted(target_confidences)

    n1, n2 = len(source_sorted), len(target_sorted)

    # Kolmogorov-Smirnov statistic
    # Maximum distance between empirical CDFs
    # CRITICAL FIX v5.0: Proper KS calculation
    # Need to evaluate CDFs at all points in both distributions
    ks_stat = 0.0

    # Evaluate at all source points
    for i in range(n1):
        # CDF of source at this point
        cdf1 = (i + 1) / n1

        # CDF of target at this point (count values <= source_sorted[i])
        cdf2 = sum(1 for t in target_sorted if t <= source_sorted[i]) / n2

        diff = abs(cdf1 - cdf2)
        ks_stat = max(ks_stat, diff)

    # Evaluate at all target points
    for j in range(n2):
        # CDF of target at this point
        cdf2 = (j + 1) / n2

        # CDF of source at this point
        cdf1 = sum(1 for s in source_sorted if s <= target_sorted[j]) / n1

        diff = abs(cdf1 - cdf2)
        ks_stat = max(ks_stat, diff)

    # Approximate p-value (for large samples)
    # Using Smirnov's approximation
    if n1 > 0 and n2 > 0:
        effective_n = (n1 * n2) / (n1 + n2)
        if ks_stat > 0:
            # Approximate p-value
            lambda_ks = math.sqrt(effective_n) * ks_stat
            # Using Kolmogorov distribution approximation
            ks_pvalue = 2 * sum(
                (-1) ** (k - 1) * math.exp(-2 * k ** 2 * lambda_ks ** 2)
                for k in range(1, 100)
            )
            ks_pvalue = max(0.0, min(1.0, ks_pvalue))
        else:
            ks_pvalue = 1.0
    else:
        ks_pvalue = 1.0

    # Jensen-Shannon divergence
    # First, create histograms
    n_bins = 20
    source_hist = [0] * n_bins
    target_hist = [0] * n_bins

    for c in source_confidences:
        bin_idx = min(int(c * n_bins), n_bins - 1)
        source_hist[bin_idx] += 1

    for c in target_confidences:
        bin_idx = min(int(c * n_bins), n_bins - 1)
        target_hist[bin_idx] += 1

    # Normalize to probabilities
    total_source = sum(source_hist) or 1
    total_target = sum(target_hist) or 1

    p = [h / total_source for h in source_hist]
    q = [h / total_target for h in target_hist]

    # Add small epsilon to prevent log(0)
    eps = 1e-10
    p = [max(x, eps) for x in p]
    q = [max(x, eps) for x in q]

    # Normalize so sum = 1
    p_sum = sum(p)
    q_sum = sum(q)
    p = [x / p_sum for x in p]
    q = [x / q_sum for x in q]

    # JS divergence
    m = [(px + qx) / 2 for px, qx in zip(p, q)]

    kl_pm = sum(px * math.log(px / mx) for px, mx in zip(p, m))
    kl_qm = sum(qx * math.log(qx / mx) for qx, mx in zip(q, m))

    js_div = (kl_pm + kl_qm) / 2

    # Normalize JS divergence to [0, 1] using log(n_bins)
    max_js = math.log(n_bins) if n_bins > 1 else 1
    js_div_norm = js_div / max_js

    # Determine if shift exists
    has_shift = ks_pvalue < threshold or js_div_norm > 0.2

    # Shift magnitude: combine KS and JS
    shift_magnitude = min(1.0, ks_stat + js_div_norm)

    return DistributionShiftResult(
        has_shift=has_shift,
        shift_magnitude=shift_magnitude,
        ks_statistic=ks_stat,
        ks_pvalue=ks_pvalue,
        js_divergence=js_div_norm
    )


# =============================================================================
# MAIN / TEST
# =============================================================================

if __name__ == "__main__":
    print("="*60)
    print("Scientific Metrics v5.0 — New 2024-2025 Metrics")
    print("="*60)

    # Test data
    logits = [
        [2.0, 1.0, 0.5],  # Correct class 0
        [1.5, 2.0, 0.5],  # Correct class 1
        [0.5, 1.0, 2.0],  # Correct class 2
        [2.5, 0.5, 0.3],  # Correct class 0 (overconfident)
    ]
    labels = [0, 1, 2, 0]

    print("\n1. Temperature Scaling:")
    temp_result = optimize_temperature(logits, labels)
    print(f"   Optimal T: {temp_result.optimal_temperature:.3f}")
    print(f"   ECE before: {temp_result.ece_before:.4f}")
    print(f"   ECE after:  {temp_result.ece_after:.4f}")

    print("\n2. Class-wise ECE:")
    confidences = [0.9, 0.8, 0.7, 0.6, 0.5, 0.4, 0.3, 0.2]
    predictions = [0, 0, 1, 1, 1, 2, 2, 2]
    labels_cw = [0, 1, 1, 1, 1, 2, 2, 2]

    cw_result = calculate_classwise_ece(confidences, predictions, labels_cw, n_classes=3)
    print(f"   Macro ECE: {cw_result.macro_ece:.4f}")
    print(f"   Micro ECE: {cw_result.micro_ece:.4f}")
    print(f"   ECE per class: {cw_result.ece_per_class}")

    print("\n3. Confidence Bands:")
    bands_result = calculate_confidence_bands(confidences,
        [True, True, True, True, False, False, False, False])
    print(f"   Bin 0: acc={bands_result.bin_accuracies[0]:.2f} "
          f"CI=[{bands_result.lower_bounds[0]:.2f}, {bands_result.upper_bounds[0]:.2f}]")

    print("\n4. Multiple Hypothesis Correction:")
    p_values = [0.01, 0.03, 0.10, 0.25, 0.50]
    bh_result = benjamini_hochberg_correction(p_values)
    print(f"   Original: {p_values}")
    print(f"   Corrected (BH): {[f'{p:.3f}' for p in bh_result.corrected_pvalues]}")
    print(f"   Rejected: {bh_result.rejected}")

    print("\n5. Distribution Shift Detection:")
    source_confs = [0.5, 0.6, 0.7, 0.8, 0.9]  # Training distribution
    target_confs = [0.1, 0.2, 0.3, 0.4, 0.5]  # Test distribution (shifted)

    shift_result = detect_distribution_shift(source_confs, target_confs)
    print(f"   Has shift: {shift_result.has_shift}")
    print(f"   Shift magnitude: {shift_result.shift_magnitude:.3f}")
    print(f"   KS statistic: {shift_result.ks_statistic:.3f}")
    print(f"   JS divergence: {shift_result.js_divergence:.3f}")

    print("\n" + "="*60)
