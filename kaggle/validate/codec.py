#!/usr/bin/env python3
"""
Trinity Cognitive Probes — Contamination Detection v4.3

Phase 4.3 Critical Fixes (2026-03-25):

CRITICAL FIXES v4.3:
1. ✅ Min-K%++ mode detection: Fixed OR→AND logic, added proper density normalization
2. ✅ Mode threshold increased to 0.2 to reduce false positives

METRICS (2024-2025):
- CoDeC: Context-based contamination detection (99.9% AUC)
- Min-K%++: Mode-based detection (6-10% AUROC improvement)
- RLHF Concealment: GRPO hides contamination evidence

References:
- CoDeC: arXiv 2510.27055 — "Context-based Contamination Detection"
- Min-K%++: arXiv 2404.02936 — "Theoretical Analysis of Min-K%"
- RLHF Concealment: arXiv 2510.02386 — "GRPO hides contamination"
"""

import math
import random
from typing import List, Dict, Optional, Tuple, Callable, Any
from dataclasses import dataclass
from collections import defaultdict


# =============================================================================
# CODEC (CONTEXT-BASED CONTAMINATION DETECTION) — arXiv 2510.27055
# =============================================================================

@dataclass
class CoDecResult:
    """Result of CoDeC contamination detection."""
    is_contaminated: bool
    confidence: float  # 0-1
    auc_score: float  # Estimated AUC
    mean_confidence_drop: float
    n_samples_tested: int
    threshold: float = 0.3  # Default threshold for classification


def detect_contamination_codec(
    model_get_confidence: Callable[[str], float],
    test_samples: List[str],
    context_samples: List[str],
    threshold: float = 0.3,
    n_bootstrap: int = 1000
) -> CoDecResult:
    """
    Detect contamination using CoDeC (Context-based Detection).

    CRITICAL NEW METRIC v4.2: CoDeC achieves 99.9% AUC at dataset level
    by measuring confidence drop when adding training context.

    Key insight:
    - Training samples show significant confidence drop with context
    - Clean samples show minimal confidence change
    - Model-agnostic: only requires gray-box confidence access

    Reference: arXiv 2510.27055 — "Context-based Contamination Detection"

    Args:
        model_get_confidence: Function that returns confidence for a text
        test_samples: Samples to test for contamination
        context_samples: Training context to add
        threshold: Confidence drop threshold for classification
        n_bootstrap: Bootstrap iterations for CI estimation

    Returns:
        CoDecResult with contamination assessment
    """
    if not test_samples or not context_samples:
        return CoDecResult(
            is_contaminated=False,
            confidence=0.0,
            auc_score=0.0,
            mean_confidence_drop=0.0,
            n_samples_tested=0
        )

    # Combine context samples
    context = " ".join(context_samples)

    confidence_drops = []

    for sample in test_samples:
        # Confidence WITHOUT context
        conf_without = model_get_confidence(sample)

        # Confidence WITH context
        sample_with_context = f"{context} {sample}"
        conf_with = model_get_confidence(sample_with_context)

        # Calculate relative drop
        if conf_without > 0:
            drop = (conf_without - conf_with) / conf_without
        else:
            drop = 0.0

        confidence_drops.append(drop)

    # Calculate statistics
    mean_drop = sum(confidence_drops) / len(confidence_drops)

    # CRITICAL v4.3 FIX: Improved AUC estimation using proper statistical model
    # instead of simple linear heuristic
    #
    # The CoDeC paper shows that confidence drops follow a distribution where:
    # - Contaminated samples: high drops (mean > 0.3)
    # - Clean samples: low drops (mean ≈ 0)
    #
    # We estimate AUC by modeling the separation between distributions
    # Using the relationship: AUC ≈ Φ(d/√2) where d is Cohen's d
    # and Φ is the standard normal CDF
    try:
        from eval.utils import norm_cdf
    except ImportError:
        try:
            from .eval.utils import norm_cdf
        except ImportError:
            # Fallback for direct execution
            import sys
            from pathlib import Path
            sys.path.insert(0, str(Path(__file__).parent.parent))
            from eval.utils import norm_cdf

    # Calculate effect size (Cohen's d-like measure)
    # Assume clean samples have mean drop ≈ 0 with some variance
    # Contaminated samples have mean drop = observed_mean_drop
    if len(confidence_drops) > 1:
        var_drop = sum((d - mean_drop) ** 2 for d in confidence_drops) / len(confidence_drops)
        std_drop = var_drop ** 0.5
    else:
        std_drop = 0.1  # Default assumption

    # Effect size: separation between contaminated and clean distributions
    # d = mean_drop / pooled_std
    # Assuming clean samples have std ≈ 0.1 (based on CoDeC paper)
    std_clean = 0.1
    pooled_std = ((std_drop ** 2 + std_clean ** 2) / 2) ** 0.5

    if pooled_std > 0:
        effect_size = mean_drop / pooled_std
        # AUC from effect size: AUC = Φ(d/√2)
        # This is the relationship between Cohen's d and AUC
        z_score = effect_size / (2 ** 0.5)
        estimated_auc = norm_cdf(z_score)
    else:
        estimated_auc = 0.5

    # Clamp to valid range [0, 1]
    estimated_auc = max(0.5, min(0.999, estimated_auc))

    # Bootstrap for confidence estimation
    boot_means = []
    n = len(confidence_drops)
    for _ in range(n_bootstrap):
        sample = [confidence_drops[random.randint(0, n - 1)] for _ in range(n)]
        boot_means.append(sum(sample) / n)

    boot_means.sort()
    ci_lower = boot_means[int(0.025 * n_bootstrap)]
    ci_upper = boot_means[int(0.975 * n_bootstrap)]

    # Classification
    is_contaminated = mean_drop > threshold
    confidence_score = min(1.0, mean_drop / threshold) if is_contaminated else min(1.0, threshold / (mean_drop + 1e-6))

    return CoDecResult(
        is_contaminated=is_contaminated,
        confidence=confidence_score,
        auc_score=estimated_auc,
        mean_confidence_drop=mean_drop,
        n_samples_tested=len(test_samples),
        threshold=threshold
    )


def detect_contamination_codec_simple(
    confidences_without_context: List[float],
    confidences_with_context: List[float],
    threshold: float = 0.3
) -> CoDecResult:
    """
    Simplified CoDeC detection with pre-computed confidences.

    Args:
        confidences_without_context: Confidence values for samples without context
        confidences_with_context: Confidence values for samples with context added
        threshold: Confidence drop threshold

    Returns:
        CoDecResult with contamination assessment
    """
    if len(confidences_without_context) != len(confidences_with_context):
        raise ValueError("Confidence lists must have same length")

    if not confidences_without_context:
        return CoDecResult(
            is_contaminated=False,
            confidence=0.0,
            auc_score=0.0,
            mean_confidence_drop=0.0,
            n_samples_tested=0
        )

    confidence_drops = []
    for conf_wo, conf_w in zip(confidences_without_context, confidences_with_context):
        if conf_wo > 0:
            drop = (conf_wo - conf_w) / conf_wo
        else:
            drop = 0.0
        confidence_drops.append(drop)

    mean_drop = sum(confidence_drops) / len(confidence_drops)

    # CRITICAL v4.3 FIX: Same improved AUC estimation as main function
    try:
        from eval.utils import norm_cdf
    except ImportError:
        try:
            from .eval.utils import norm_cdf
        except ImportError:
            # Fallback for direct execution
            import sys
            from pathlib import Path
            sys.path.insert(0, str(Path(__file__).parent.parent))
            from eval.utils import norm_cdf

    if len(confidence_drops) > 1:
        var_drop = sum((d - mean_drop) ** 2 for d in confidence_drops) / len(confidence_drops)
        std_drop = var_drop ** 0.5
    else:
        std_drop = 0.1

    std_clean = 0.1
    pooled_std = ((std_drop ** 2 + std_clean ** 2) / 2) ** 0.5

    if pooled_std > 0:
        effect_size = mean_drop / pooled_std
        z_score = effect_size / (2 ** 0.5)
        estimated_auc = norm_cdf(z_score)
    else:
        estimated_auc = 0.5

    estimated_auc = max(0.5, min(0.999, estimated_auc))

    is_contaminated = mean_drop > threshold
    confidence_score = min(1.0, mean_drop / threshold) if is_contaminated else min(1.0, threshold / (mean_drop + 1e-6))

    return CoDecResult(
        is_contaminated=is_contaminated,
        confidence=confidence_score,
        auc_score=estimated_auc,
        mean_confidence_drop=mean_drop,
        n_samples_tested=len(confidences_without_context),
        threshold=threshold
    )


# =============================================================================
# MIN-K%++ (MODE-BASED DETECTION) — arXiv 2404.02936
# =============================================================================

@dataclass
class MinKPPResult:
    """Result of Min-K%++ contamination detection."""
    is_contaminated: bool
    confidence: float
    min_k_score: float  # Mean confidence of bottom-K%
    mode_score: float  # Mode clustering strength
    n_below_threshold: int
    k_percent: float
    threshold_used: float


def detect_contamination_min_k_pp(
    confidences: List[float],
    k_percent: float = 5.0,
    threshold: float = 0.5,
    mode_window: float = 0.1
) -> MinKPPResult:
    """
    Detect contamination using Min-K%++ (Mode-based Detection).

    CRITICAL NEW METRIC v4.2: Min-K%++ provides 6.2-10.5% AUROC improvement
    over baseline by detecting MODE formation in low-confidence regions.

    Key insight:
    - Training samples form local maxima (MODES) in low-confidence regions
    - This clustering structure is detectable via density estimation
    - More robust than simple Min-K% thresholding

    Reference: arXiv 2404.02936 — "Theoretical Analysis of Min-K%"

    Args:
        confidences: List of confidence values
        k_percent: Percentage of lowest confidence to examine (default 5%)
        threshold: Threshold for mean confidence of bottom-K%
        mode_window: Window size for mode detection (0-1)

    Returns:
        MinKPPResult with contamination assessment
    """
    if not confidences:
        return MinKPPResult(
            is_contaminated=False,
            confidence=0.0,
            min_k_score=0.0,
            mode_score=0.0,
            n_below_threshold=0,
            k_percent=k_percent,
            threshold_used=threshold
        )

    n = len(confidences)
    k = max(1, int(n * k_percent / 100))

    # Sort confidences
    sorted_conf = sorted(confidences)

    # Bottom-K% confidences
    bottom_k = sorted_conf[:k]
    min_k_score = sum(bottom_k) / len(bottom_k)

    # Mode detection: check if bottom-K% forms a cluster
    # A mode is a region with high density
    # CRITICAL v4.3 FIX: Improved mode detection using Kernel Density Estimation approach
    if k >= 3:
        # Calculate spread of bottom-K%
        spread = max(bottom_k) - min(bottom_k)

        # Count samples in mode window
        mode_center = sum(bottom_k) / len(bottom_k)
        mode_half_window = mode_window / 2

        in_mode = sum(1 for c in confidences if mode_center - mode_half_window <= c <= mode_center + mode_half_window)
        mode_density = in_mode / n

        # Mode score: high if bottom-K% is tightly clustered
        # Also normalize by expected density for fair comparison
        expected_density = mode_window  # Expected density for uniform distribution
        mode_score = (mode_density / expected_density - 1.0) if spread < mode_window else 0.0
        mode_score = max(0.0, mode_score)  # Ensure non-negative
    else:
        mode_score = 0.0

    # CRITICAL v4.3 FIX: Use AND instead of OR for proper contamination detection
    # OR logic caused false positives when mode_score > 0.1 regardless of min-k
    # Now require BOTH conditions: low min-k score AND significant mode clustering
    # Mode threshold should be higher (0.2 instead of 0.1) to reduce false positives
    is_contaminated = (min_k_score < threshold) and (mode_score > 0.2)

    # Confidence based on how far below threshold
    if is_contaminated:
        confidence_score = min(1.0, (threshold - min_k_score) / threshold + mode_score)
    else:
        confidence_score = max(0.0, 1.0 - min_k_score / threshold)

    return MinKPPResult(
        is_contaminated=is_contaminated,
        confidence=confidence_score,
        min_k_score=min_k_score,
        mode_score=mode_score,
        n_below_threshold=sum(1 for c in confidences if c < threshold),
        k_percent=k_percent,
        threshold_used=threshold
    )


def detect_contamination_min_k_pp_curve(
    confidences: List[float],
    k_values: List[float] = None
) -> List[Tuple[float, float, float, float]]:
    """
    Run Min-K%++ across multiple K values for analysis.

    Args:
        confidences: List of confidence values
        k_values: List of K percentages to test

    Returns:
        List of (k_percent, min_k_score, mode_score, is_contaminated)
    """
    if k_values is None:
        k_values = [1.0, 2.0, 5.0, 10.0, 15.0, 20.0]

    results = []
    for k in k_values:
        result = detect_contamination_min_k_pp(confidences, k_percent=k)
        results.append((
            k,
            result.min_k_score,
            result.mode_score,
            1.0 if result.is_contaminated else 0.0
        ))

    return results


# =============================================================================
# RLHF CONCEALMENT DETECTION — arXiv 2510.02386
# =============================================================================

@dataclass
class RLHFConcealmentResult:
    """Result of RLHF concealment detection."""
    is_concealed: bool
    concealment_score: float  # 0-1
    confidence_variance: float
    response_pattern_score: float
    n_samples: int


def detect_rlhf_concealment(
    confidences: List[float],
    responses: List[str],
    threshold: float = 0.15
) -> RLHFConcealmentResult:
    """
    Detect RLHF concealment of contamination.

    CRITICAL NEW v4.2: RLHF (particularly GRPO) can hide contamination
    evidence by reducing confidence gaps between train and test.

    Detection strategy:
    - Low variance in confidence across samples
    - Verbal hedging patterns in responses
    - Uniform confidence distribution

    Reference: arXiv 2510.02386 — "RLHF Concealment of Data Contamination"

    Args:
        confidences: List of confidence values
        responses: List of model responses
        threshold: Variance threshold for concealment detection

    Returns:
        RLHFConcealmentResult with assessment
    """
    if not confidences:
        return RLHFConcealmentResult(
            is_concealed=False,
            concealment_score=0.0,
            confidence_variance=0.0,
            response_pattern_score=0.0,
            n_samples=0
        )

    n = len(confidences)

    # Calculate variance (low variance suggests concealment)
    mean_conf = sum(confidences) / n
    variance = sum((c - mean_conf) ** 2 for c in confidences) / n

    # Analyze response patterns for hedging
    hedge_count = 0
    for response in responses:
        response_lower = response.lower()
        # Common hedging phrases
        if any(phrase in response_lower for phrase in [
            "might be", "could be", "possibly", "probably",
            "i think", "uncertain", "not sure", "maybe"
        ]):
            hedge_count += 1

    hedge_ratio = hedge_count / n

    # Concealment score combines low variance and high hedging
    concealment_score = 0.0
    if variance < threshold:
        concealment_score += 0.5  # Low variance contributes
    if hedge_ratio > 0.3:
        concealment_score += 0.5 * (hedge_ratio / 0.3)  # Hedging contributes

    concealment_score = min(1.0, concealment_score)

    return RLHFConcealmentResult(
        is_concealed=concealment_score > 0.5,
        concealment_score=concealment_score,
        confidence_variance=variance,
        response_pattern_score=hedge_ratio,
        n_samples=n
    )


# =============================================================================
# MAIN / TEST
# =============================================================================

if __name__ == "__main__":
    print("="*60)
    print("Contamination Detection v4.2 — Test Suite")
    print("="*60)

    # Mock model function
    def mock_model_confidence(text: str) -> float:
        """Mock confidence function for testing."""
        # Training samples have high confidence without context
        # but drop significantly with context
        if "training" in text.lower() and "context" not in text.lower():
            return 0.95
        elif "context" in text.lower():
            return 0.60  # Significant drop
        # Clean samples maintain confidence
        elif "clean" in text.lower():
            return 0.85
        else:
            return 0.70

    print("\n1. CoDeC Detection:")
    test_samples = [
        "training data sample 1",
        "training data sample 2",
        "clean data sample"
    ]
    context_samples = [
        "This is training context from the dataset"
    ]

    codec_result = detect_contamination_codec(
        mock_model_confidence,
        test_samples,
        context_samples
    )

    print(f"   Is contaminated: {codec_result.is_contaminated}")
    print(f"   Confidence: {codec_result.confidence:.3f}")
    print(f"   Mean confidence drop: {codec_result.mean_confidence_drop:.3f}")
    print(f"   Estimated AUC: {codec_result.auc_score:.3f}")

    print("\n2. CoDeC Simple (pre-computed confidences):")
    conf_wo = [0.95, 0.95, 0.85]
    conf_w = [0.60, 0.60, 0.82]
    codec_simple = detect_contamination_codec_simple(conf_wo, conf_w)
    print(f"   Is contaminated: {codec_simple.is_contaminated}")
    print(f"   Mean confidence drop: {codec_simple.mean_confidence_drop:.3f}")

    print("\n3. Min-K%++ Detection:")
    test_confidences = [0.3, 0.4, 0.5, 0.7, 0.8, 0.9]  # Some low conf
    mink_result = detect_contamination_min_k_pp(test_confidences)
    print(f"   Is contaminated: {mink_result.is_contaminated}")
    print(f"   Min-K% score: {mink_result.min_k_score:.3f}")
    print(f"   Mode score: {mink_result.mode_score:.3f}")

    print("\n4. Min-K%++ Curve:")
    mink_curve = detect_contamination_min_k_pp_curve(test_confidences)
    for k, score, mode_score, is_cont in mink_curve:
        print(f"   K={k:4.1f}%: score={score:.3f}, mode={mode_score:.3f}, cont={bool(is_cont)}")

    print("\n5. RLHF Concealment Detection:")
    test_conf_rlhf = [0.72, 0.73, 0.71, 0.72, 0.74]  # Very low variance
    test_responses = [
        "I think this might be the answer",
        "This could possibly be correct",
        "I'm not entirely sure but this is probably it"
    ]
    rlhf_result = detect_rlhf_concealment(test_conf_rlhf, test_responses)
    print(f"   Is concealed: {rlhf_result.is_concealed}")
    print(f"   Concealment score: {rlhf_result.concealment_score:.3f}")
    print(f"   Confidence variance: {rlhf_result.confidence_variance:.4f}")
    print(f"   Hedge ratio: {rlhf_result.response_pattern_score:.3f}")

    print("\n" + "="*60)
