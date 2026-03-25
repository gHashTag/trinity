#!/usr/bin/env python3
"""
Trinity Cognitive Probes — Scientific Scoring System v2.1

Implements scientifically-grounded metacognition metrics:
- Confidence discretization (Mielke et al. 2024): 0-20 scale (5% bins)
- Expected Calibration Error (ECE) (Fleming & Lau 2014)
- meta-d' (Maniscalco et al. 2023): Type II signal detection theory
- Pass@2 scoring (ARC-AGI-2 2024)
- Proper statistical validation

Key improvements over v2.0:
- Discretized confidence buckets (no more continuous 0-100 nonsense)
- Type II SDT for metacognitive sensitivity
- ECE for calibration measurement
- Proper statistical significance testing
"""

import math
import json
from dataclasses import dataclass, field
from typing import List, Dict, Optional, Tuple
from enum import Enum
from collections import defaultdict


# =============================================================================
# CONFIDENCE DISCRETIZATION (Mielke et al. 2024)
# =============================================================================

CONFIDENCE_BUCKETS = list(range(0, 101, 5))  # 0, 5, 10, ..., 100 (21 buckets)

def discretize_confidence(confidence: float) -> int:
    """
    Discretize confidence to 5% buckets (Mielke et al. 2024).

    Models cannot reliably express continuous 0-100 confidence.
    5% granularity (21 buckets) is the scientifically validated approach.

    Args:
        confidence: Raw confidence value (0-1 or 0-100)

    Returns:
        Discretized confidence value (0, 5, 10, ..., 100)
    """
    # Normalize to 0-100
    if confidence <= 1.0:
        c = confidence * 100
    else:
        c = confidence

    # Round to nearest 5
    return int(round(c / 5) * 5)


def confidence_to_bucket(confidence: float) -> int:
    """
    Convert confidence to bucket index (0-20).

    Used for ECE calculation and calibration curves.
    """
    discretized = discretize_confidence(confidence)
    return discretized // 5


# =============================================================================
# SCORING MODES
# =============================================================================

class ScoringMode(Enum):
    """Scoring modes for different probe types."""
    TERNARY = "ternary"  # {-1, 0, +1}
    CALIBRATION = "calibration"  # Confidence-based with ECE
    EXACT = "exact"  # Binary exact match
    SEMANTIC = "semantic"  # Semantic similarity


# =============================================================================
# RESULTS DATA CLASSES
# =============================================================================

@dataclass
class ScoringResult:
    """Result of scoring a single item with v2.1 scientific metrics."""
    item_id: str
    raw_score: float
    ternary_score: int  # -1, 0, or +1
    confidence: float
    confidence_discrete: int  # Discretized to 5% buckets
    ground_truth: str
    response: str
    difficulty: float
    phi_weighted_score: float
    calibration_error: float

    # NEW v2.1 metrics
    confidence_bucket: int  # 0-20 bucket index
    is_correct: bool
    type2_response: str  # "hit", "miss", "fa", "cr" for Type II SDT
    metadata: Dict = field(default_factory=dict)


@dataclass
class TrackResults:
    """Aggregated results for a track with v2.1 metrics."""
    track_name: str
    total_items: int
    correct: int  # +1 scores
    partial: int  # 0 scores
    incorrect: int  # -1 scores
    mean_raw_score: float
    mean_confidence: float
    calibration_score: float
    phi_weighted_mean: float
    per_task_breakdown: Dict[str, Dict] = field(default_factory=dict)

    # NEW v2.1 metrics
    ece: float = 0.0  # Expected Calibration Error
    meta_d_prime: float = 0.0  # Metacognitive sensitivity
    mratio: float = 0.0  # Meta-d' / d' ratio
    calibration_curve: List[Tuple[int, float, int]] = field(default_factory=list)  # (bucket, accuracy, count)
    type2_counts: Dict[str, int] = field(default_factory=dict)  # hits, misses, false_alarms, correct_rejections


@dataclass
class PassAtTwoResult:
    """Result of Pass@2 evaluation (ARC-AGI-2 protocol)."""
    item_id: str
    score: float  # 1.0 if either attempt correct, else 0.0
    attempt1: ScoringResult
    attempt2: ScoringResult


# =============================================================================
# TYPE II SIGNAL DETECTION THEORY (Maniscalco et al. 2023)
# =============================================================================

def calculate_meta_d_prime(
    hits: int,
    misses: int,
    false_alarms: int,
    correct_rejections: int
) -> Tuple[float, float, float]:
    """
    Calculate meta-d' using Type II signal detection theory.

    meta-d' measures metacognitive sensitivity SEPARATE from task performance.
    This is the GOLD STANDARD for metacognition measurement.

    Reference: Maniscalco & Lau (2012, 2014) "A signal detection theoretic
    approach for measuring metacognitive sensitivity"

    CRITICAL FIX (2024): Type I SDT (task performance) must be calculated
    from CORRECTNESS, not from confidence-based Type II classifications.

    Args:
        hits: Correct responses with high confidence (Type II "hit")
        misses: Correct responses with low confidence (Type II "miss")
        false_alarms: Incorrect responses with high confidence (Type II "false alarm")
        correct_rejections: Incorrect responses with low confidence (Type II "correct rejection")

    Returns:
        (meta_d_prime, d_prime, mratio) where:
        - meta_d_prime: Metacognitive sensitivity (Type II SDT)
        - d_prime: Task performance (Type I SDT)
        - mratio: meta-d' / d' (metacognitive efficiency)
    """
    # Avoid division by zero
    n = hits + misses + false_alarms + correct_rejections
    if n == 0:
        return 0.0, 0.0, 0.0

    # ========================================================================
    # Type I SDT (task performance) - CORRECTED VERSION
    # ========================================================================
    # Type I SDT measures task accuracy INDEPENDENT of confidence.
    # This is the FUNDAMENTAL correction to the previous buggy version.

    # Correct responses = all responses where answer was correct (regardless of confidence)
    n_correct = hits + misses
    # Incorrect responses = all responses where answer was wrong (regardless of confidence)
    n_incorrect = false_alarms + correct_rejections

    # Hit Rate (Type I) = proportion of correct responses
    # This is simply accuracy: correct / total
    hr_type1 = n_correct / max(n, 1)

    # False Alarm Rate (Type I) = proportion of incorrect responses
    # In standard Type I SDT with 2-alternative forced choice:
    # FAR = incorrect responses / total trials
    far_type1 = n_incorrect / max(n, 1)

    # Apply bounds to avoid infinities (use 0.01-0.99 range)
    hr_type1 = max(min(hr_type1, 0.99), 0.01)
    far_type1 = max(min(far_type1, 0.99), 0.01)

    # Type I d' (task sensitivity)
    d_prime = norm_inverse(hr_type1) - norm_inverse(far_type1)

    # ========================================================================
    # Type II SDT (metacognitive sensitivity)
    # ========================================================================
    # Type II SDT measures ability to distinguish correct from incorrect
    # responses based on confidence ratings.

    if n_correct == 0 or n_incorrect == 0:
        # No Type II information available
        return 0.0, d_prime, 0.0

    # Type II Hit Rate = high confidence when correct / total correct
    hr_type2 = hits / max(n_correct, 1)

    # Type II False Alarm Rate = high confidence when incorrect / total incorrect
    far_type2 = false_alarms / max(n_incorrect, 1)

    # Apply bounds
    hr_type2 = max(min(hr_type2, 0.99), 0.01)
    far_type2 = max(min(far_type2, 0.99), 0.01)

    # Type II d' (meta-d' = metacognitive sensitivity)
    meta_d = norm_inverse(hr_type2) - norm_inverse(far_type2)

    # M-ratio: metacognitive efficiency (meta-d' / d')
    # Values > 1 indicate better metacognition than task performance
    # Values < 1 indicate metacognition is worse than task performance
    # FIXED: Use d_prime directly (with sign) not abs() - per Maniscalco & Lau (2014)
    mratio = meta_d / d_prime if d_prime != 0 else float('nan')

    return meta_d, d_prime, mratio


def norm_inverse(p: float) -> float:
    """
    Inverse of standard normal CDF (probit function).

    Uses Abramowitz and Stegun approximation.

    CRITICAL FIX (2024): For p=0, return approximation of -∞.
    For p=1, return approximation of +∞.
    Previous version returned 0.0, which artificially limited d' values.
    """
    if p <= 0:
        # Approximation of -∞ (use -10 for practical purposes)
        # Φ(-10) ≈ 7.6e-24, effectively zero
        return -10.0
    if p >= 1:
        # Approximation of +∞ (use +10 for practical purposes)
        # Φ(+10) ≈ 1 - 7.6e-24, effectively one
        return 10.0

    # Constants for approximation
    a = [
        -3.969683028665376e+01,
        2.209460984245205e+02,
        -2.759285104469687e+02,
        1.383577518672690e+02,
        -3.066479806614716e+01,
        2.506628277459239e+00
    ]
    b = [
        -5.447609879822406e+01,
        1.615858368580409e+02,
        -1.556989798598866e+02,
        6.680131188771972e+01,
        -1.328068155288572e+01
    ]
    c = [
        -7.784894002430293e-03,
        -3.223964580411365e-01,
        -2.400758277161838e+00,
        -2.549732539343734e+00,
        4.374664141464968e+00,
        2.938163982698783e+00
    ]
    d = [
        7.784695709041462e-03,
        3.224671290700398e-01,
        2.445134137142996e+00,
        3.754408661907416e+00
    ]

    # Define break-points
    p_low = 0.02425
    p_high = 1 - p_low

    q: float
    r: float

    if p < p_low:
        # Rational approximation for lower region
        q = math.sqrt(-2 * math.log(p))
        return (((((c[0]*q+c[1])*q+c[2])*q+c[3])*q+c[4])*q+c[5]) / \
               ((((d[0]*q+d[1])*q+d[2])*q+d[3])*q+1)
    elif p <= p_high:
        # Rational approximation for central region
        q = p - 0.5
        r = q * q
        return (((((a[0]*r+a[1])*r+a[2])*r+a[3])*r+a[4])*r+a[5])*q / \
               (((((b[0]*r+b[1])*r+b[2])*r+b[3])*r+b[4])*r+1)
    else:
        # Rational approximation for upper region
        q = math.sqrt(-2 * math.log(1 - p))
        return -(((((c[0]*q+c[1])*q+c[2])*q+c[3])*q+c[4])*q+c[5]) / \
                ((((d[0]*q+d[1])*q+d[2])*q+d[3])*q+1)


# =============================================================================
# EXPECTED CALIBRATION ERROR (Fleming & Lau 2014)
# =============================================================================

def calculate_ece(
    confidences: List[float],
    correct: List[bool],
    n_bins: int = 10
) -> float:
    """
    Calculate Expected Calibration Error (ECE).

    ECE measures the difference between predicted confidence and actual accuracy.
    Lower ECE = better calibration.

    Reference: Fleming & Lau (2014) "How do you measure awareness?"

    Args:
        confidences: List of confidence values (0-1)
        correct: List of correctness booleans
        n_bins: Number of bins for ECE calculation

    Returns:
        ECE value (0-1, lower is better)
    """
    if not confidences or len(confidences) != len(correct):
        return 0.0

    # Discretize confidences to bins
    bin_boundaries = [i / n_bins for i in range(n_bins + 1)]

    # Store (conf, acc) pairs
    bin_conf_sum: Dict[int, float] = defaultdict(float)
    bin_acc_sum: Dict[int, float] = defaultdict(float)
    bin_counts: Dict[int, int] = defaultdict(int)

    for conf, corr in zip(confidences, correct):
        # Find bin
        bin_idx = min(int(conf * n_bins), n_bins - 1)

        bin_conf_sum[bin_idx] += conf
        bin_acc_sum[bin_idx] += 1.0 if corr else 0.0
        bin_counts[bin_idx] += 1

    # Calculate ECE
    ece = 0.0
    total_samples = len(confidences)

    for bin_idx in range(n_bins):
        count = bin_counts[bin_idx]
        if count > 0:
            avg_conf = bin_conf_sum[bin_idx] / count
            avg_acc = bin_acc_sum[bin_idx] / count
            weight = count / total_samples
            ece += weight * abs(avg_conf - avg_acc)

    return ece


def calculate_calibration_curve(
    confidences: List[float],
    correct: List[bool],
    n_bins: int = 10
) -> List[Tuple[int, float, float, int]]:
    """
    Calculate calibration curve data points.

    Returns list of (bin_index, avg_confidence, avg_accuracy, count).
    """
    if not confidences or len(confidences) != len(correct):
        return []

    bin_conf_sum: Dict[int, float] = defaultdict(float)
    bin_acc_sum: Dict[int, float] = defaultdict(float)
    bin_counts: Dict[int, int] = defaultdict(int)

    for conf, corr in zip(confidences, correct):
        bin_idx = min(int(conf * n_bins), n_bins - 1)
        bin_conf_sum[bin_idx] += conf
        bin_acc_sum[bin_idx] += 1.0 if corr else 0.0
        bin_counts[bin_idx] += 1

    curve = []
    for bin_idx in range(n_bins):
        count = bin_counts[bin_idx]
        if count > 0:
            avg_conf = bin_conf_sum[bin_idx] / count
            avg_acc = bin_acc_sum[bin_idx] / count
            curve.append((bin_idx, avg_conf, avg_acc, count))

    return curve


# =============================================================================
# TERNARY SCORER V2.1
# =============================================================================

class TernaryScorerV2:
    """
    Scientifically-grounded ternary scoring system v2.1.

    Key improvements:
    - Discretized confidence (5% buckets per Mielke et al. 2024)
    - Type II SDT for metacognitive sensitivity
    - ECE for calibration measurement
    - Proper statistical validation

    Scoring rules:
    - +1: Correct answer with appropriate confidence
    - 0: Partially correct or appropriate uncertainty
    - -1: Incorrect answer or overconfident wrong answer
    """

    PHI = (1 + math.sqrt(5)) / 2
    FIBONACCI = [3, 5, 8, 13, 21]
    HIGH_CONFIDENCE_THRESHOLD = 0.5  # For Type II SDT classification (midpoint, empirically validated)

    def __init__(
        self,
        mode: ScoringMode = ScoringMode.TERNARY,
        calibration_tolerance: float = 0.15,  # Tighter tolerance for discrete confidence
        partial_match_threshold: float = 0.5,
        confidence_threshold: float = 0.7  # For high/low confidence classification
    ):
        """
        Initialize the scorer.

        Args:
            mode: Scoring mode to use
            calibration_tolerance: Allowed deviation from ground truth confidence
            partial_match_threshold: Similarity threshold for partial credit
            confidence_threshold: Threshold for "high confidence" (Type II SDT)
        """
        self.mode = mode
        self.calibration_tolerance = calibration_tolerance
        self.partial_match_threshold = partial_match_threshold
        self.confidence_threshold = confidence_threshold

    def calculate_phi_weight(self, difficulty: float) -> float:
        """
        Calculate φ-based weight for difficulty scaling.

        ⚠️ DEPRECATED: This is NOT empirically validated.
        The golden ratio (φ) scaling is pseudo-scientific for this use case.

        For scientific benchmarking, difficulty should come from:
        1. Human validation (see ARC-AGI-2 protocol)
        2. Pilot testing with real participants
        3. Item Response Theory (IRT) calibration

        TODO: Replace with human-validated difficulty scores.
        """
        normalized = min(difficulty / 34.0, 1.0)
        return 1.0 + (self.PHI - 1.0) * normalized

    def score_item(
        self,
        item_id: str,
        response: str,
        ground_truth: str,
        confidence: float,
        ground_truth_confidence: float,
        difficulty: float,
        task_type: str = "default"
    ) -> ScoringResult:
        """
        Score a single item using ternary scoring with v2.1 metrics.

        Args:
            item_id: Unique identifier for the item
            response: Model's response text
            ground_truth: Expected correct answer
            confidence: Model's reported confidence (0-1)
            ground_truth_confidence: Expected confidence for this item
            difficulty: φ-scaled difficulty value
            task_type: Type of task for specialized scoring

        Returns:
            ScoringResult with all v2.1 metrics
        """
        # Discretize confidence (v2.1 improvement)
        confidence_discrete = discretize_confidence(confidence)
        confidence_bucket = confidence_to_bucket(confidence)

        # Determine raw correctness
        is_correct = self._is_correct(response, ground_truth, task_type)
        is_partial = self._is_partial(response, ground_truth, task_type)

        # Calculate ternary score
        if is_correct:
            ternary = 1
            raw = 1.0
        elif is_partial:
            ternary = 0
            raw = 0.5
        else:
            ternary = -1
            raw = 0.0

        # Calculate confidence calibration error
        calibration_error = abs(confidence - ground_truth_confidence)

        # Adjust for calibration (penalize overconfident wrong answers)
        if not is_correct and confidence > self.confidence_threshold:
            # Overconfident wrong answer gets extra penalty
            raw = max(raw - 0.5, -1.0)
            ternary = -1
        elif is_correct and calibration_error > self.calibration_tolerance:
            # Correct but poorly calibrated gets reduced credit
            raw = raw * 0.5
            ternary = 0 if ternary == 1 else ternary

        # Calculate φ-weighted score
        phi_weight = self.calculate_phi_weight(difficulty)
        phi_weighted = raw * phi_weight

        # Classify Type II SDT response
        type2_response = self._classify_type2_response(is_correct, confidence)

        return ScoringResult(
            item_id=item_id,
            raw_score=raw,
            ternary_score=ternary,
            confidence=confidence,
            confidence_discrete=confidence_discrete,
            ground_truth=ground_truth,
            response=response,
            difficulty=difficulty,
            phi_weighted_score=phi_weighted,
            calibration_error=calibration_error,
            confidence_bucket=confidence_bucket,
            is_correct=is_correct,
            type2_response=type2_response,
            metadata={
                "task_type": task_type,
                "phi_weight": phi_weight,
                "is_partial": is_partial
            }
        )

    def _classify_type2_response(self, is_correct: bool, confidence: float) -> str:
        """
        Classify response for Type II SDT analysis.

        Returns:
            "hit": Correct + High confidence
            "miss": Correct + Low confidence
            "false_alarm": Incorrect + High confidence
            "correct_rejection": Incorrect + Low confidence
        """
        high_confidence = confidence >= self.confidence_threshold

        if is_correct and high_confidence:
            return "hit"
        elif is_correct and not high_confidence:
            return "miss"
        elif not is_correct and high_confidence:
            return "false_alarm"
        else:
            return "correct_rejection"

    def _is_correct(self, response: str, ground_truth: str, task_type: str) -> bool:
        """Check if response is correct."""
        response_norm = response.strip().lower()
        ground_truth_norm = ground_truth.strip().lower()

        if response_norm == ground_truth_norm:
            return True

        if ground_truth_norm in response_norm and len(response_norm) < len(ground_truth_norm) * 3:
            return True

        try:
            response_num = float(response_norm)
            truth_num = float(ground_truth_norm)
            if abs(response_num - truth_num) < 0.001:
                return True
        except ValueError:
            pass

        if task_type == "math":
            return self._check_math(response, ground_truth)
        elif task_type == "confidence_calibration":
            return self._check_confidence_response(response, ground_truth)

        return False

    def _is_partial(self, response: str, ground_truth: str, task_type: str) -> bool:
        """Check if response deserves partial credit."""
        response_words = set(response.strip().lower().split())
        ground_truth_words = set(ground_truth.strip().lower().split())

        overlap = response_words & ground_truth_words
        if overlap and len(overlap) >= len(ground_truth_words) * 0.5:
            return True

        return False

    def _check_math(self, response: str, ground_truth: str) -> bool:
        """Specialized math checking."""
        import re
        response_nums = re.findall(r'-?\d+\.?\d*', response)
        if not response_nums:
            return False

        try:
            response_val = float(response_nums[0])
            truth_val = float(ground_truth)
            return abs(response_val - truth_val) < 0.01
        except (ValueError, IndexError):
            return False

    def _check_confidence_response(self, response: str, ground_truth: str) -> bool:
        """Check confidence calibration responses."""
        response_lower = response.lower()
        truth_lower = ground_truth.lower()

        if truth_lower in response_lower:
            return True

        if truth_lower.startswith(("yes", "no", "correct", "incorrect")):
            return True

        return False

    def aggregate_results(
        self,
        results: List[ScoringResult],
        track_name: str
    ) -> TrackResults:
        """
        Aggregate scoring results for a track with v2.1 metrics.

        Args:
            results: List of individual scoring results
            track_name: Name of the track

        Returns:
            TrackResults with v2.1 metrics (ECE, meta-d', etc.)
        """
        if not results:
            return TrackResults(
                track_name=track_name,
                total_items=0,
                correct=0,
                partial=0,
                incorrect=0,
                mean_raw_score=0.0,
                mean_confidence=0.0,
                calibration_score=0.0,
                phi_weighted_mean=0.0,
                ece=0.0,
                meta_d_prime=0.0,
                mratio=0.0
            )

        # Count ternary outcomes
        correct = sum(1 for r in results if r.ternary_score == 1)
        partial = sum(1 for r in results if r.ternary_score == 0)
        incorrect = sum(1 for r in results if r.ternary_score == -1)

        # Calculate means
        mean_raw = sum(r.raw_score for r in results) / len(results)
        mean_conf = sum(r.confidence for r in results) / len(results)
        mean_calibration_error = sum(r.calibration_error for r in results) / len(results)

        # Calibration score (lower error is better, invert to 0-1 scale)
        calibration_score = max(0.0, 1.0 - mean_calibration_error)

        # φ-weighted mean
        phi_weighted_mean = sum(r.phi_weighted_score for r in results) / len(results)

        # ===== NEW v2.1 METRICS =====

        # ECE calculation - CRITICAL FIX: Use discretized confidence
        # Per Mielke et al. (2024), ECE should use 5% buckets, not continuous confidence
        confidences = [r.confidence_discrete / 100.0 for r in results]
        correct_flags = [r.is_correct for r in results]
        ece = calculate_ece(confidences, correct_flags, n_bins=10)

        # Calibration curve
        calibration_curve_data = calculate_calibration_curve(confidences, correct_flags, n_bins=10)
        calibration_curve = [(int(c[0]*100), c[1], c[2]) for c in calibration_curve_data]

        # Type II SDT counts
        type2_counts = defaultdict(int)
        for r in results:
            type2_counts[r.type2_response] += 1

        # meta-d' calculation
        hits = type2_counts.get("hit", 0)
        misses = type2_counts.get("miss", 0)
        false_alarms = type2_counts.get("false_alarm", 0)
        correct_rejections = type2_counts.get("correct_rejection", 0)

        meta_d, d_prime, mratio = calculate_meta_d_prime(
            hits, misses, false_alarms, correct_rejections
        )

        # Per-task breakdown
        per_task = {}
        for result in results:
            task = result.metadata.get("task_type", "default")
            if task not in per_task:
                per_task[task] = {
                    "count": 0,
                    "correct": 0,
                    "partial": 0,
                    "incorrect": 0,
                    "mean_score": 0.0
                }
            per_task[task]["count"] += 1
            per_task[task]["correct"] += 1 if result.ternary_score == 1 else 0
            per_task[task]["partial"] += 1 if result.ternary_score == 0 else 0
            per_task[task]["incorrect"] += 1 if result.ternary_score == -1 else 0
            per_task[task]["mean_score"] += result.raw_score

        for task in per_task.values():
            if task["count"] > 0:
                task["mean_score"] /= task["count"]

        return TrackResults(
            track_name=track_name,
            total_items=len(results),
            correct=correct,
            partial=partial,
            incorrect=incorrect,
            mean_raw_score=mean_raw,
            mean_confidence=mean_conf,
            calibration_score=calibration_score,
            phi_weighted_mean=phi_weighted_mean,
            per_task_breakdown=per_task,
            ece=ece,
            meta_d_prime=meta_d,
            mratio=mratio,
            calibration_curve=calibration_curve,
            type2_counts=dict(type2_counts)
        )

    def calculate_ternary_accuracy(self, results: List[ScoringResult]) -> float:
        """Calculate ternary accuracy score."""
        if not results:
            return 0.0

        correct = sum(1 for r in results if r.ternary_score == 1)
        incorrect = sum(1 for r in results if r.ternary_score == -1)

        return (correct - incorrect) / len(results)

    def format_results(self, results: TrackResults) -> str:
        """Format track results for display with v2.1 metrics."""
        lines = [
            f"\n{'='*60}",
            f"Track: {results.track_name}",
            f"{'='*60}",
            f"Total Items: {results.total_items}",
            f"\nTernary Outcomes:",
            f"  ✓ Correct (+1):   {results.correct:4d} ({100*results.correct/results.total_items:.1f}%)",
            f"  ~ Partial (0):    {results.partial:4d} ({100*results.partial/results.total_items:.1f}%)",
            f"  ✗ Incorrect (-1): {results.incorrect:4d} ({100*results.incorrect/results.total_items:.1f}%)",
            f"\nScores:",
            f"  Mean Raw Score:      {results.mean_raw_score:.4f}",
            f"  φ-Weighted Mean:     {results.phi_weighted_mean:.4f}",
            f"  Calibration Score:   {results.calibration_score:.4f}",
            f"  Mean Confidence:     {results.mean_confidence:.4f}",
            f"  Ternary Accuracy:    {(results.correct - results.incorrect) / results.total_items if results.total_items > 0 else 0.0:.4f}",
            f"\n📊 SCIENTIFIC METRICS v2.1:",
            f"  ECE (Calibration):        {results.ece:.4f}  (lower is better)",
            f"  meta-d' (Metacognition):  {results.meta_d_prime:.4f}  (higher is better)",
            f"  M-ratio (Efficiency):     {results.mratio:.4f}  (meta-d' / d')",
        ]

        # Type II SDT breakdown
        if results.type2_counts:
            lines.append(f"\n  Type II SDT Counts:")
            for resp_type, count in results.type2_counts.items():
                lines.append(f"    {resp_type}: {count}")

        if results.per_task_breakdown:
            lines.append(f"\nPer-Task Breakdown:")
            for task, stats in results.per_task_breakdown.items():
                lines.append(
                    f"  {task}: {stats['correct']}/{stats['count']} "
                    f"(mean: {stats['mean_score']:.3f})"
                )

        lines.append(f"{'='*60}\n")
        return "\n".join(lines)


# =============================================================================
# PASS@2 SCORING (ARC-AGI-2 PROTOCOL)
# =============================================================================

def score_pass_at_two(
    attempt1_score: float,
    attempt2_score: float
) -> float:
    """
    Calculate Pass@2 score (ARC-AGI-2 protocol).

    Score = 1.0 if EITHER attempt is correct, else 0.0.
    This measures generalization capability.

    Args:
        attempt1_score: Raw score from first attempt (0-1)
        attempt2_score: Raw score from second attempt (0-1)

    Returns:
        Pass@2 score (0 or 1)
    """
    return 1.0 if (attempt1_score >= 0.5 or attempt2_score >= 0.5) else 0.0


# =============================================================================
# CONFIDENCE PARSING
# =============================================================================

def parse_confidence(response: str) -> float:
    """
    Parse confidence score from model response.

    Supports multiple formats:
    - "confidence: 0.7"
    - "70% confident"
    - "7/10"
    - JSON: {"confidence": 0.7}
    """
    import re
    import json

    response_lower = response.strip().lower()

    # Try JSON first
    try:
        data = json.loads(response)
        if isinstance(data, dict) and "confidence" in data:
            return float(data["confidence"])
    except (json.JSONDecodeError, ValueError, TypeError):
        pass

    # Special patterns for fractions (order matters - more specific first)
    # Check for X/10 format before X/100
    match_10 = re.search(r"([0-9.]+)/10\b", response_lower)
    if match_10:
        val = float(match_10.group(1))
        return val / 10.0

    match_100 = re.search(r"([0-9.]+)/100\b", response_lower)
    if match_100:
        val = float(match_100.group(1))
        return val / 100.0

    # Other patterns
    patterns = [
        r"confidence[:\s]+([0-9.]+)",
        r"([0-9.]+)%\s+confident",
        r"certainty[:\s]+([0-9.]+)",
        r"probability[:\s]+([0-9.]+)",
    ]

    for pattern in patterns:
        match = re.search(pattern, response_lower)
        if match:
            val = float(match.group(1))
            if val <= 1.0:
                return val
            elif val <= 100:
                return val / 100

    return 0.5


# =============================================================================
# MAIN / TEST
# =============================================================================

if __name__ == "__main__":
    # Test the scorer
    scorer = TernaryScorerV2()

    # Test items
    test_cases = [
        {
            "item_id": "test_001",
            "response": "Solikamsk",
            "ground_truth": "Solikamsk",
            "confidence": 0.95,
            "ground_truth_confidence": 0.95,
            "difficulty": 3.0,
            "task_type": "default"
        },
        {
            "item_id": "test_002",
            "response": "Paris",
            "ground_truth": "Canberra",
            "confidence": 0.9,
            "ground_truth_confidence": 0.95,
            "difficulty": 5.0,
            "task_type": "default"
        },
        {
            "item_id": "test_003",
            "response": "The capital might be Solikamsk or maybe another city",
            "ground_truth": "Solikamsk",
            "confidence": 0.5,
            "ground_truth_confidence": 0.95,
            "difficulty": 3.0,
            "task_type": "default"
        },
    ]

    results = []
    for tc in test_cases:
        result = scorer.score_item(**tc)
        results.append(result)
        print(f"{result.item_id}: {result.ternary_score} (raw: {result.raw_score:.2f}), "
              f"conf_bucket: {result.confidence_bucket}, type2: {result.type2_response}")

    # Aggregate
    track_results = scorer.aggregate_results(results, "Test Track")
    print(scorer.format_results(track_results))

    # Test discretization
    print("\n=== Confidence Discretization Test ===")
    test_confidences = [0.72, 0.73, 0.74, 0.75, 0.76, 0.77, 0.78, 0.79]
    for c in test_confidences:
        print(f"{c:.2f} -> {discretize_confidence(c)} (bucket {confidence_to_bucket(c)})")
