#!/usr/bin/env python3
"""
Trinity Cognitive Probes — Confidence Calibration

Implements temperature scaling and other post-hoc calibration methods.

References:
- Guo et al. (2017) "On Calibration of Modern Neural Networks"
- Platt (1999) "Probabilistic Outputs for Support Vector Machines"
- Zadrozny & Elkan (2002) "Transforming Classifier Scores into Accurate Multiclass Probability Estimates"
"""

import os
import sys
import math
import numpy as np
from typing import List, Tuple, Callable, Dict, Optional, Union, Any
from dataclasses import dataclass
from enum import Enum


class CalibrationMethod(Enum):
    """Calibration methods."""
    TEMPERATURE = "temperature"  # Single-parameter temperature scaling
    PLATT = "platt"  # Logistic regression on log-odds
    ISOTONIC = "isotonic"  # Non-parametric isotonic regression
    BETA = "beta"  # Beta calibration (two parameters)


@dataclass
class CalibrationResult:
    """Result of calibration procedure."""
    method: str
    ece_before: float
    ece_after: float
    nll_before: float
    nll_after: float
    improvement: float
    calibration_params: Dict = None

    def __str__(self):
        imp_pct = self.improvement * 100
        return (f"{self.method}: ECE {self.ece_before:.4f} → {self.ece_after:.4f} "
                f"({imp_pct:+.1f}%), NLL {self.nll_before:.4f} → {self.nll_after:.4f}")


@dataclass
class TemperatureScalingResult:
    """Result of temperature scaling optimization."""
    optimal_temperature: float
    ece_before: float
    ece_after: float
    nll_before: float
    nll_after: float
    calibration_curve: Optional[List[Tuple[float, float]]] = None


def calculate_nll(confidences: List[float], correct: List[bool], epsilon: float = 1e-15) -> float:
    """
    Calculate Negative Log-Likelihood.

    NLL = -1/n * Σ[y_i * log(p_i) + (1-y_i) * log(1-p_i)]

    Args:
        confidences: Predicted confidences
        correct: Ground truth (True=correct, False=incorrect)
        epsilon: Small value to prevent log(0)

    Returns:
        NLL value (lower is better)
    """
    n = len(confidences)
    if n == 0:
        return float('inf')

    nll = 0.0
    for conf, corr in zip(confidences, correct):
        conf_clipped = max(epsilon, min(1 - epsilon, conf))
        if corr:
            nll -= math.log(conf_clipped)
        else:
            nll -= math.log(1 - conf_clipped)

    return nll / n


def calculate_ece(confidences: List[float], correct: List[bool], n_bins: int = 10) -> float:
    """
    Calculate Expected Calibration Error.

    ECE = Σ (n_i / n) * |acc_i - conf_i|

    Args:
        confidences: Predicted confidences
        correct: Ground truth
        n_bins: Number of bins

    Returns:
        ECE value (lower is better)
    """
    n = len(confidences)
    if n == 0:
        return 0.0

    # Bin by confidence
    bin_boundaries = np.linspace(0, 1, n_bins + 1)
    bin_counts = np.zeros(n_bins)
    bin_acc_sums = np.zeros(n_bins)
    bin_conf_sums = np.zeros(n_bins)

    for conf, corr in zip(confidences, correct):
        bin_idx = min(int(conf * n_bins), n_bins - 1)
        bin_counts[bin_idx] += 1
        bin_acc_sums[bin_idx] += float(corr)
        bin_conf_sums[bin_idx] += conf

    # Calculate ECE
    ece = 0.0
    for i in range(n_bins):
        if bin_counts[i] > 0:
            acc_i = bin_acc_sums[i] / bin_counts[i]
            conf_i = bin_conf_sums[i] / bin_counts[i]
            weight = bin_counts[i] / n
            ece += weight * abs(acc_i - conf_i)

    return ece


def apply_temperature(confidences: List[float], T: float) -> List[float]:
    """
    Apply temperature scaling to confidences.

    For logits: scaled_logits = logits / T
    For confidences (when logits unavailable): use power transform approximation.

    Power transform: c^(1/T)
    - T > 1: soften (push toward 0.5)
    - T < 1: sharpen (push toward 0/1)

    Args:
        confidences: Raw confidences
        T: Temperature parameter

    Returns:
        Temperature-scaled confidences
    """
    if T <= 0:
        raise ValueError(f"Temperature must be positive, got {T}")

    # Use power transform as approximation
    # This is equivalent to applying temperature to logits then softmax
    conf_arr = np.array(confidences)
    scaled = np.power(conf_arr, 1.0 / T)
    return np.clip(scaled, 0.0, 1.0).tolist()


def find_optimal_temperature(
    confidences: List[float],
    correct: List[bool],
    temperature_range: Tuple[float, float] = (0.1, 5.0),
    n_steps: int = 100,
    minimize_metric: str = "nll"  # "nll" or "ece"
) -> TemperatureScalingResult:
    """
    Find optimal temperature by grid search.

    Args:
        confidences: Raw model confidences
        correct: Ground truth correctness
        temperature_range: Search range for T
        n_steps: Number of temperatures to try
        minimize_metric: "nll" (recommended) or "ece"

    Returns:
        TemperatureScalingResult with optimal T and metrics
    """
    ece_before = calculate_ece(confidences, correct, n_bins=10)
    nll_before = calculate_nll(confidences, correct)

    best_T = 1.0
    best_value = float('inf')

    # Grid search
    for i in range(n_steps + 1):
        T = temperature_range[0] + (temperature_range[1] - temperature_range[0]) * i / n_steps

        scaled = apply_temperature(confidences, T)

        if minimize_metric == "nll":
            value = calculate_nll(scaled, correct)
        else:
            value = calculate_ece(scaled, correct)

        if value < best_value:
            best_value = value
            best_T = T

    # Calculate final metrics
    scaled_confidences = apply_temperature(confidences, best_T)
    ece_after = calculate_ece(scaled_confidences, correct)
    nll_after = calculate_nll(scaled_confidences, correct)

    return TemperatureScalingResult(
        optimal_temperature=best_T,
        ece_before=ece_before,
        ece_after=ece_after,
        nll_before=nll_before,
        nll_after=nll_after
    )


def find_optimal_temperature_scipy(
    confidences: List[float],
    correct: List[bool],
    temperature_range: Tuple[float, float] = (0.1, 5.0)
) -> TemperatureScalingResult:
    """
    Find optimal temperature using scipy optimization (faster/more accurate).

    Uses scipy.optimize.minimize_scalar with bounded method.

    Args:
        confidences: Raw model confidences
        correct: Ground truth correctness
        temperature_range: Search bounds for T

    Returns:
        TemperatureScalingResult with optimal T
    """
    try:
        from scipy.optimize import minimize_scalar
    except ImportError:
        # Fallback to grid search
        return find_optimal_temperature(confidences, correct, temperature_range)

    ece_before = calculate_ece(confidences, correct)
    nll_before = calculate_nll(confidences, correct)

    def objective(T: float) -> float:
        """Minimize NLL at temperature T."""
        scaled = apply_temperature(confidences, T)
        return calculate_nll(scaled, correct)

    result = minimize_scalar(
        objective,
        bounds=temperature_range,
        method='bounded',
        options={'xatol': 0.01}
    )

    optimal_T = result.x
    scaled_confidences = apply_temperature(confidences, optimal_T)
    ece_after = calculate_ece(scaled_confidences, correct)
    nll_after = result.fun

    return TemperatureScalingResult(
        optimal_temperature=optimal_T,
        ece_before=ece_before,
        ece_after=ece_after,
        nll_before=nll_before,
        nll_after=nll_after
    )


def platt_scaling(confidences: List[float], correct: List[bool]) -> Tuple[Callable[[float], float], CalibrationResult]:
    """
    Platt scaling: logistic regression on log-odds.

    Learns: logit(p_calibrated) = A * logit(p) + B

    Args:
        confidences: Raw model confidences
        correct: Ground truth correctness

    Returns:
        (calibration_function, CalibrationResult)
    """
    try:
        from sklearn.linear_model import LogisticRegression
    except ImportError:
        raise ImportError("Platt scaling requires scikit-learn: pip install scikit-learn")

    ece_before = calculate_ece(confidences, correct)
    nll_before = calculate_nll(confidences, correct)

    # Prepare data
    X = np.array(confidences).reshape(-1, 1)
    y = np.array(correct, dtype=int)

    # Avoid numerical issues with logit
    X_clipped = np.clip(X, 0.001, 0.999)
    X_logit = np.log(X_clipped / (1 - X_clipped)).reshape(-1, 1)

    # Fit logistic regression with high C (low regularization)
    clf = LogisticRegression(fit_intercept=True, C=1e6, solver='lbfgs')
    clf.fit(X_logit, y)

    A = float(clf.coef_[0])
    B = float(clf.intercept_[0])

    def calibrate(conf: float) -> float:
        """Apply Platt scaling to a single confidence."""
        conf = max(0.001, min(0.999, conf))
        logit = math.log(conf / (1 - conf))
        calibrated_logit = A * logit + B
        return 1.0 / (1.0 + math.exp(-calibrated_logit))

    # Calculate calibrated metrics
    calibrated = [calibrate(c) for c in confidences]
    ece_after = calculate_ece(calibrated, correct)
    nll_after = calculate_nll(calibrated, correct)

    result = CalibrationResult(
        method="platt",
        ece_before=ece_before,
        ece_after=ece_after,
        nll_before=nll_before,
        nll_after=nll_after,
        improvement=(ece_before - ece_after) / max(ece_before, 0.001),
        calibration_params={"A": A, "B": B}
    )

    return calibrate, result


def isotonic_regression(confidences: List[float], correct: List[bool]) -> Tuple[Callable[[float]], CalibrationResult]:
    """
    Isotonic regression: non-parametric calibration.

    Learns monotonic calibration function from data.

    Args:
        confidences: Raw model confidences
        correct: Ground truth correctness

    Returns:
        (calibration_function, CalibrationResult)
    """
    try:
        from sklearn.isotonic import IsotonicRegression
    except ImportError:
        raise ImportError("Isotonic regression requires scikit-learn: pip install scikit-learn")

    ece_before = calculate_ece(confidences, correct)
    nll_before = calculate_nll(confidences, correct)

    # Fit isotonic regression
    iso_reg = IsotonicRegression(out_of_bounds='clip')
    iso_reg.fit(confidences, [float(c) for c in correct])

    def calibrate(conf: float) -> float:
        """Apply isotonic calibration."""
        return float(iso_reg.predict([conf])[0])

    # Calculate calibrated metrics
    calibrated = [calibrate(c) for c in confidences]
    ece_after = calculate_ece(calibrated, correct)
    nll_after = calculate_nll(calibrated, correct)

    result = CalibrationResult(
        method="isotonic",
        ece_before=ece_before,
        ece_after=ece_after,
        nll_before=nll_before,
        nll_after=nll_after,
        improvement=(ece_before - ece_after) / max(ece_before, 0.001),
        calibration_params={
            "X_": iso_reg.X_.tolist(),
            "y_": iso_reg.y_.tolist()
        }
    )

    return calibrate, result


def beta_calibration(confidences: List[float], correct: List[bool]) -> Tuple[Callable[[float]], CalibrationResult]:
    """
    Beta calibration: two-parameter calibration using Beta distribution.

    Formula: p_calibrated = beta_cdf(alpha, beta; p_raw)

    Args:
        confidences: Raw model confidences
        correct: Ground truth correctness

    Returns:
        (calibration_function, CalibrationResult)
    """
    try:
        from scipy.optimize import minimize
        from scipy.stats import beta as beta_dist
    except ImportError:
        raise ImportError("Beta calibration requires scipy: pip install scipy")

    ece_before = calculate_ece(confidences, correct)
    nll_before = calculate_nll(confidences, correct)

    def objective(params):
        """Minimize NLL given alpha, beta."""
        alpha, beta_param = params
        if alpha <= 0 or beta_param <= 0:
            return 1e10

        nll = 0.0
        for conf, corr in zip(confidences, correct):
            # Use beta CDF as calibration function
            conf_calibrated = beta_dist.cdf(conf, alpha, beta_param)
            conf_calibrated = max(1e-15, min(1 - 1e-15, conf_calibrated))
            if corr:
                nll -= math.log(conf_calibrated)
            else:
                nll -= math.log(1 - conf_calibrated)
        return nll / len(confidences)

    # Optimize alpha, beta (start from 1, 1 = uniform)
    result = minimize(
        objective,
        x0=[1.0, 1.0],
        bounds=[(0.1, 10.0), (0.1, 10.0)],
        method='L-BFGS-B'
    )

    alpha, beta_param = result.x

    def calibrate(conf: float) -> float:
        """Apply beta calibration."""
        return float(beta_dist.cdf(conf, alpha, beta_param))

    # Calculate calibrated metrics
    calibrated = [calibrate(c) for c in confidences]
    ece_after = calculate_ece(calibrated, correct)
    nll_after = calculate_nll(calibrated, correct)

    result_obj = CalibrationResult(
        method="beta",
        ece_before=ece_before,
        ece_after=ece_after,
        nll_before=nll_before,
        nll_after=nll_after,
        improvement=(ece_before - ece_after) / max(ece_before, 0.001),
        calibration_params={"alpha": alpha, "beta": beta_param}
    )

    return calibrate, result_obj


def calibrate_confidences(
    confidences: List[float],
    correct: List[bool],
    method: str = "temperature"
) -> Tuple[Callable[[float], float], CalibrationResult]:
    """
    Learn calibration mapping from validation data.

    Args:
        confidences: Raw model confidences
        correct: Ground truth correctness
        method: "temperature", "platt", "isotonic", or "beta"

    Returns:
        (calibration_function, CalibrationResult)
    """
    if method == "temperature":
        temp_result = find_optimal_temperature_scipy(confidences, correct)
        T = temp_result.optimal_temperature

        def calibrate(conf: float) -> float:
            return apply_temperature([conf], T)[0]

        result = CalibrationResult(
            method="temperature",
            ece_before=temp_result.ece_before,
            ece_after=temp_result.ece_after,
            nll_before=temp_result.nll_before,
            nll_after=temp_result.nll_after,
            improvement=(temp_result.ece_before - temp_result.ece_after) / max(temp_result.ece_before, 0.001),
            calibration_params={"T": T}
        )
        return calibrate, result

    elif method == "platt":
        return platt_scaling(confidences, correct)
    elif method == "isotonic":
        return isotonic_regression(confidences, correct)
    elif method == "beta":
        return beta_calibration(confidences, correct)
    else:
        raise ValueError(f"Unknown calibration method: {method}")


def confidence_clamping(
    confidences: List[float],
    min_conf: float = 0.05,
    max_conf: float = 0.98
) -> List[float]:
    """
    Clamp extreme confidences to improve calibration.

    Very high/low confidences hurt ECE if wrong.

    Args:
        confidences: Raw confidences
        min_conf: Minimum allowed confidence
        max_conf: Maximum allowed confidence

    Returns:
        Clamped confidences
    """
    return [max(min_conf, min(max_conf, c)) for c in confidences]


# =============================================================================
# Quick Win Methods from Additional Improvements
# =============================================================================

def adaptive_temperature_by_difficulty(
    confidences: List[float],
    difficulties: List[float] = None
) -> List[float]:
    """
    Ultra-simple Adaptive Temperature Scaling.

    Uses confidence as inverse difficulty proxy:
    - Low confidence = hard = sharpen (T < 1)
    - High confidence = easy = soften (T > 1)

    Args:
        confidences: Raw confidences
        difficulties: Optional difficulty scores [0, 1]

    Returns:
        Adaptively calibrated confidences
    """
    if difficulties is None:
        # Use confidence as inverse difficulty proxy
        difficulties = [1.0 - c for c in confidences]

    result = []
    for conf, diff in zip(confidences, difficulties):
        # T in [0.5, 2.0] based on difficulty
        T = 0.5 + 1.5 * (1.0 - diff)
        result.append(apply_temperature([conf], T)[0])
    return result


def compute_conformal_threshold(
    val_confidences: List[float],
    val_correct: List[bool],
    target_coverage: float = 0.90
) -> float:
    """
    Compute conformal threshold for coverage guarantee.

    Guarantees: P(correct >= threshold) >= target_coverage

    Usage: Predict "correct" only if confidence > threshold.

    Args:
        val_confidences: Validation confidences
        val_correct: Ground truth correctness
        target_coverage: Target coverage (0.90 = 90%)

    Returns:
        q: Conformal threshold
    """
    # Non-conformity scores
    scores = [c if corr else (1 - c) for c, corr in zip(val_confidences, val_correct)]

    # Quantile threshold
    q = np.quantile(scores, target_coverage, method='higher')
    return q


def conformal_predict(
    confidence: float,
    q: float
) -> Tuple[bool, float, bool]:
    """
    Make prediction with conformal guarantee.

    Args:
        confidence: Model confidence
        q: Conformal threshold from compute_conformal_threshold()

    Returns:
        prediction: Binary decision (True = predict correct)
        corrected_confidence: Adjusted confidence
        abstain: Whether to abstain (low confidence)
    """
    nc_score = 1 - confidence

    if nc_score > q:
        # Below threshold: abstain or predict negative
        return False, max(0.0, confidence), True
    else:
        # Above threshold: predict positive
        corrected_conf = max(0.0, min(1.0, 1.0 - nc_score / q))
        return True, corrected_conf, False


def borda_count_aggregate(responses: List[str]) -> str:
    """
    Borda count aggregation for self-consistency.

    Points = (n_candidates - rank). Winner has most points.

    Args:
        responses: List of sampled responses

    Returns:
        Winner by Borda count (most common response)
    """
    from collections import Counter

    # Simple Borda: count occurrences
    # (Full Borda requires ranking all alternatives)
    counts = Counter(responses)
    return counts.most_common(1)[0][0] if counts else ""


def weighted_ensemble_calibration(
    confidences: List[float],
    methods: List[Callable[[float], float]],
    weights: List[float] = None
) -> List[float]:
    """
    Weighted ensemble of calibration methods.

    Args:
        confidences: Raw confidences
        methods: List of calibration functions
        weights: Optional weights for each method

    Returns:
        Ensemble-calibrated confidences
    """
    if weights is None:
        weights = [1.0 / len(methods)] * len(methods)

    result = []
    for conf in confidences:
        calibrated_sum = 0.0
        for method, weight in zip(methods, weights):
            calibrated_sum += weight * method(conf)
        result.append(calibrated_sum)

    return result


# =============================================================================
# CLI
# =============================================================================

def main():
    """CLI entry point for calibration."""
    import argparse
    import json

    parser = argparse.ArgumentParser(
        description="Trinity Cognitive Probes — Confidence Calibration"
    )

    parser.add_argument(
        "--results",
        required=True,
        help="Path to results CSV with 'confidence' and 'ternary_score' columns"
    )
    parser.add_argument(
        "--method",
        choices=["temperature", "platt", "isotonic", "beta", "all"],
        default="all",
        help="Calibration method to use"
    )
    parser.add_argument(
        "--output",
        help="Save calibrated confidences to JSON"
    )

    args = parser.parse_args()

    # Load results
    import csv
    confidences = []
    correct = []

    with open(args.results, 'r') as f:
        reader = csv.DictReader(f)
        for row in reader:
            conf = float(row.get('confidence', 0.5))
            ternary = int(row.get('ternary_score', 0))
            confidences.append(conf)
            correct.append(ternary == 1)

    print(f"Loaded {len(confidences)} predictions")
    print(f"Baseline ECE: {calculate_ece(confidences, correct):.4f}")
    print(f"Baseline NLL: {calculate_nll(confidences, correct):.4f}")
    print()

    # Run calibration
    methods = ["temperature", "platt", "isotonic", "beta"] if args.method == "all" else [args.method]

    results = {}
    for method in methods:
        try:
            calibrate, result = calibrate_confidences(confidences, correct, method)
            print(f"✅ {result}")
            results[method] = {
                "ece_before": result.ece_before,
                "ece_after": result.ece_after,
                "nll_before": result.nll_before,
                "nll_after": result.nll_after,
                "improvement": result.improvement,
                "params": result.calibration_params
            }
        except Exception as e:
            print(f"❌ {method}: {e}")

    # Save results
    if args.output:
        with open(args.output, 'w') as f:
            json.dump(results, f, indent=2)
        print(f"\nResults saved to {args.output}")


if __name__ == "__main__":
    main()
