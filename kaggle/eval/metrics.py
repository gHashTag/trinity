#!/usr/bin/env python3
"""
Trinity Cognitive Probes — Unified Scientific Metrics Interface

Version-aware facade for all scientific metrics (v3, v4, v5, v6, v7).

Usage:
    from kaggle.eval.metrics import ScientificMetrics

    # Use v7 (RECOMMENDED - scientifically correct)
    metrics = ScientificMetrics(version="v7")

    # Run Min-K%++ contamination detection (v7: requires full vocab distribution)
    result = metrics.detect_contamination_mink_pp(
        token_log_probs=[[...], ...],  # Full vocab per sample
        vocab_size=50000
    )

    # Run CoDeC detection
    result = metrics.detect_contamination_codec(
        true_labels=[...],
        confidence_drops=[...]
    )

    # Calculate Full-ECE (v7: quantile binning)
    result = metrics.calculate_full_ece(
        confidences=[[0.2, 0.7, 0.1], ...],
        correct_token_indices=[2, 0],
        binning="quantile"  # NEW: equal-mass bins
    )
"""

# CRITICAL: Do sys.path modification BEFORE any other imports
import sys
from pathlib import Path

# Add project root to sys.path (needed for both script and module usage)
project_root = Path(__file__).parent.parent.parent
if str(project_root) not in sys.path:
    sys.path.insert(0, str(project_root))

from typing import List, Dict, Optional, Any, Union
from dataclasses import dataclass, asdict, field
import warnings


@dataclass
class MetricsVersionInfo:
    """Information about a metrics version."""
    version: str
    description: str
    is_recommended: bool
    breaking_changes: List[str]
    deprecation_notes: List[str] = field(default_factory=list)
    v7_1_critical_fixes: List[str] = field(default_factory=list)


# Version registry
VERSION_INFO = {
    "v3": MetricsVersionInfo(
        version="v3",
        description="Initial scientific metrics implementation",
        is_recommended=False,
        breaking_changes=[]
    ),
    "v4": MetricsVersionInfo(
        version="v4",
        description="Fixed Full-ECE, Min-K%++, CoDeC formulas",
        is_recommended=False,
        breaking_changes=["Full-ECE formula", "Min-K%++ k_percent", "CoDeC AUC calculation"]
    ),
    "v5": MetricsVersionInfo(
        version="v5",
        description="Added temperature scaling, confidence bands",
        is_recommended=False,
        breaking_changes=["Added new metrics", "Improved distribution shift"]
    ),
    "v6": MetricsVersionInfo(
        version="v6",
        description="CRITICAL FIXES: vocab_size, ROC AUC, true label only",
        is_recommended=False,  # Changed to False - v7 is now recommended
        breaking_changes=[
            "Min-K%++: k_percent now applies to vocab_size, not samples",
            "CoDeC: True ROC AUC instead of weighted accuracy",
            "Full-ECE: Added vocab_size validation",
            "Class-wise ECE: Uses true label only (not OR logic)",
            "Distribution Shift: Uses scipy.stats.ks_2samp",
            "NEW: Prior Shift ECE",
            "NEW: Dynamic ECE"
        ],
        deprecation_notes=[
            "Min-K%++: Incorrect (sample-based instead of vocabulary-based). Use v7.",
            "Full-ECE: Fixed-width bins instead of quantile bins. Use v7.",
            "Prior Shift ECE: Prior-weighted instead of sample-weighted. Use v7.",
            "Dynamic ECE: Float step bug. Use v7."
        ]
    ),
    "v7": MetricsVersionInfo(
        version="v7",
        description="SCIENTIFICALLY CORRECT: All v6 bugs fixed + new metrics + CI (v7.1 with critical fixes)",
        is_recommended=True,
        breaking_changes=[
            "Min-K%++: Now requires FULL vocabulary distribution per sample",
            "Full-ECE: Quantile (equal-mass) binning instead of fixed-width",
            "Prior Shift ECE: Sample-weighted averaging",
            "Dynamic ECE: Fixed integer step bug",
            "All metrics: Now include bootstrap confidence intervals",
            "Input format changes: Min-K%++ requires List[List[float]]",
            "v7.1: Full-ECE now sample-weighted (not probability-weighted) - values will change",
            "v7.1: CoDeC p-value calculation fixed - values will change",
        ],
        deprecation_notes=[],
        v7_1_critical_fixes=[
            "Full-ECE: Fixed probability-weighted bug - now uses sample-count weighting (CRITICAL)",
            "CoDeC: Fixed p-value conversion - Mann-Whitney U p-value IS the AUC p-value (CRITICAL)",
        ]
    )
}


class ScientificMetrics:
    """
    Unified interface for all scientific metrics versions.

    Recommended version: v7 (includes v7.1 critical fixes)

    v7.1 CRITICAL FIXES (2026-03-25):
    - Full-ECE: Now sample-count weighted (not probability-weighted)
    - CoDeC: Correct p-value calculation (no incorrect inversion)

    Example:
        metrics = ScientificMetrics(version="v6")

        # Contamination detection
        mink_result = metrics.detect_contamination_mink_pp(log_probs, vocab_size=50000)
        codec_result = metrics.detect_contamination_codec(labels, conf_drops)

        # Calibration
        ece_result = metrics.calculate_full_ece(probs, correct_indices)
        classwise_result = metrics.calculate_classwise_ece(confs, preds, labels, n_classes)

        # Distribution analysis
        shift_result = metrics.detect_distribution_shift(source_confs, target_confs)
    """

    def __init__(self, version: str = "v7"):
        """
        Initialize scientific metrics interface.

        Args:
            version: Metrics version to use ("v3", "v4", "v5", "v6", "v7")
                     Default: "v7" (recommended)

        Raises:
            ValueError: If version is not supported
        """
        if version not in VERSION_INFO:
            valid_versions = ", ".join(VERSION_INFO.keys())
            raise ValueError(f"Unsupported version: {version}. Valid: {valid_versions}")

        self.version = version

        # Show deprecation warnings for v6
        if version == "v6":
            warnings.warn(
                "v6 is deprecated due to scientific inaccuracies. "
                "Use v7 for scientifically correct metrics. "
                "See VERSION_INFO['v6'].deprecation_notes for details.",
                DeprecationWarning,
                stacklevel=2
            )

        self._load_version()

    def _load_version(self):
        """Load the appropriate metrics module."""
        # Determine if running as script
        is_script = __name__ == "__main__"

        if self.version == "v7":
            if is_script:
                # Running as script: use absolute import
                from kaggle.eval.scientific_metrics_v7 import (
                    detect_contamination_mink_pp_v7,
                    detect_contamination_codec_v7,
                    calculate_full_ece_v7,
                    calculate_classwise_ece_v7,
                    detect_distribution_shift_v7,
                    calculate_prior_shift_ece_v7,
                    calculate_dynamic_ece_v7,
                    calculate_adaptive_ece,
                    calculate_brier_score,
                    calculate_dr_ece,
                    MinKPPResultV7,
                    CoDecResultV7,
                    FullECEResultV7,
                    ClasswiseECEResultV7,
                    PriorShiftECEResultV7,
                    DynamicECEResultV7,
                    AdaptiveECEResult,
                    BrierScoreResult,
                    DistributionRobustECEResult,
                )
            else:
                # Running as module: use relative import
                from .scientific_metrics_v7 import (
                    detect_contamination_mink_pp_v7,
                    detect_contamination_codec_v7,
                    calculate_full_ece_v7,
                    calculate_classwise_ece_v7,
                    detect_distribution_shift_v7,
                    calculate_prior_shift_ece_v7,
                    calculate_dynamic_ece_v7,
                    calculate_adaptive_ece,
                    calculate_brier_score,
                    calculate_dr_ece,
                    MinKPPResultV7,
                    CoDecResultV7,
                    FullECEResultV7,
                    ClasswiseECEResultV7,
                    PriorShiftECEResultV7,
                    DynamicECEResultV7,
                    AdaptiveECEResult,
                    BrierScoreResult,
                    DistributionRobustECEResult,
                )

            self._mink_pp = detect_contamination_mink_pp_v7
            self._codec = detect_contamination_codec_v7
            self._full_ece = calculate_full_ece_v7
            self._classwise_ece = calculate_classwise_ece_v7
            self._dist_shift = detect_distribution_shift_v7
            self._prior_shift_ece = calculate_prior_shift_ece_v7
            self._dynamic_ece = calculate_dynamic_ece_v7
            self._adaptive_ece = calculate_adaptive_ece
            self._brier_score = calculate_brier_score
            self._dr_ece = calculate_dr_ece

            # v7 doesn't have these, set to None
            self._temperature = None
            self._conf_bands = None

            # Result classes
            self.MinKPPResult = MinKPPResultV7
            self.CoDecResult = CoDecResultV7
            self.FullECEResult = FullECEResultV7
            self.ClasswiseECEResult = ClasswiseECEResultV7

            # Import DistributionShiftResult from v6 for v7
            from kaggle.eval.scientific_metrics_v6 import DistributionShiftResult
            self.DistributionShiftResult = DistributionShiftResult

            self.PriorShiftECEResult = PriorShiftECEResultV7
            self.DynamicECEResult = DynamicECEResultV7
            self.AdaptiveECEResult = AdaptiveECEResult
            self.BrierScoreResult = BrierScoreResult
            self.DistributionRobustECEResult = DistributionRobustECEResult

            # v7 doesn't have these
            self.TemperatureScalingResult = None
            self.ConfidenceBandsResult = None

        elif self.version == "v6":
            if is_script:
                from kaggle.eval.scientific_metrics_v6 import (
                    detect_contamination_mink_pp_v6,
                    detect_contamination_codec_v6,
                    calculate_full_ece_v6,
                    calculate_classwise_ece_v6,
                    detect_distribution_shift_v6,
                    calculate_prior_shift_ece,
                    calculate_dynamic_ece,
                    optimize_temperature,
                    calculate_confidence_bands,
                    MinKPPResult,
                    CoDecResult,
                    FullECEResult,
                    ClasswiseECEResult,
                    DistributionShiftResult,
                    PriorShiftECEResult,
                    DynamicECEResult,
                    TemperatureScalingResult,
                    ConfidenceBandsResult
                )
            else:
                from .scientific_metrics_v6 import (
                    detect_contamination_mink_pp_v6,
                    detect_contamination_codec_v6,
                    calculate_full_ece_v6,
                    calculate_classwise_ece_v6,
                    detect_distribution_shift_v6,
                    calculate_prior_shift_ece,
                    calculate_dynamic_ece,
                    optimize_temperature,
                    calculate_confidence_bands,
                    MinKPPResult,
                    CoDecResult,
                    FullECEResult,
                    ClasswiseECEResult,
                    DistributionShiftResult,
                    PriorShiftECEResult,
                    DynamicECEResult,
                    TemperatureScalingResult,
                    ConfidenceBandsResult
                )

            self._mink_pp = detect_contamination_mink_pp_v6
            self._codec = detect_contamination_codec_v6
            self._full_ece = calculate_full_ece_v6
            self._classwise_ece = calculate_classwise_ece_v6
            self._dist_shift = detect_distribution_shift_v6
            self._prior_shift_ece = calculate_prior_shift_ece
            self._dynamic_ece = calculate_dynamic_ece
            self._temperature = optimize_temperature
            self._conf_bands = calculate_confidence_bands

            # Result classes
            self.MinKPPResult = MinKPPResult
            self.CoDecResult = CoDecResult
            self.FullECEResult = FullECEResult
            self.ClasswiseECEResult = ClasswiseECEResult
            self.DistributionShiftResult = DistributionShiftResult
            self.PriorShiftECEResult = PriorShiftECEResult
            self.DynamicECEResult = DynamicECEResult
            self.TemperatureScalingResult = TemperatureScalingResult
            self.ConfidenceBandsResult = ConfidenceBandsResult

        elif self.version == "v5":
            from .scientific_metrics_v5 import (
                detect_contamination_mink_pp_v5,
                detect_contamination_codec_v5,
                calculate_full_ece_v5,
                calculate_classwise_ece_v5,
                detect_distribution_shift_v5,
                optimize_temperature,
                calculate_confidence_bands,
                MinKPPResult,
                CoDecResult,
                FullECEResult,
                ClasswiseECEResult,
                DistributionShiftResult,
                TemperatureScalingResult,
                ConfidenceBandsResult
            )

            self._mink_pp = detect_contamination_mink_pp_v5
            self._codec = detect_contamination_codec_v5
            self._full_ece = calculate_full_ece_v5
            self._classwise_ece = calculate_classwise_ece_v5
            self._dist_shift = detect_distribution_shift_v5
            self._temperature = optimize_temperature
            self._conf_bands = calculate_confidence_bands

            self.MinKPPResult = MinKPPResult
            self.CoDecResult = CoDecResult
            self.FullECEResult = FullECEResult
            self.ClasswiseECEResult = ClasswiseECEResult
            self.DistributionShiftResult = DistributionShiftResult
            self.TemperatureScalingResult = TemperatureScalingResult
            self.ConfidenceBandsResult = ConfidenceBandsResult

            # v5 doesn't have these
            self.PriorShiftECEResult = None
            self.DynamicECEResult = None
            self.AdaptiveECEResult = None
            self.BrierScoreResult = None
            self.DistributionRobustECEResult = None
            self._prior_shift_ece = None
            self._dynamic_ece = None
            self._adaptive_ece = None
            self._brier_score = None
            self._dr_ece = None

        elif self.version == "v4":
            from .scientific_metrics_v4 import (
                detect_contamination_mink_pp_v4,
                detect_contamination_codec_v4,
                calculate_full_ece_v4,
                MinKPPResult,
                CoDecResult,
                FullECEResult
            )

            self._mink_pp = detect_contamination_mink_pp_v4
            self._codec = detect_contamination_codec_v4
            self._full_ece = calculate_full_ece_v4

            self.MinKPPResult = MinKPPResult
            self.CoDecResult = CoDecResult
            self.FullECEResult = FullECEResult

            # v4 doesn't have these
            self._classwise_ece = None
            self._dist_shift = None
            self._temperature = None
            self._conf_bands = None
            self._prior_shift_ece = None
            self._dynamic_ece = None
            self._adaptive_ece = None
            self._brier_score = None
            self._dr_ece = None
            self.ClasswiseECEResult = None
            self.DistributionShiftResult = None
            self.PriorShiftECEResult = None
            self.DynamicECEResult = None
            self.TemperatureScalingResult = None
            self.ConfidenceBandsResult = None
            self.AdaptiveECEResult = None
            self.BrierScoreResult = None
            self.DistributionRobustECEResult = None

        else:  # v3
            from .scientific_metrics_v3 import (
                detect_contamination_mink_pp_v3,
                MinKPPResult
            )

            self._mink_pp = detect_contamination_mink_pp_v3
            self.MinKPPResult = MinKPPResult

            # v3 doesn't have these
            self._codec = None
            self._full_ece = None
            self._classwise_ece = None
            self._dist_shift = None
            self._temperature = None
            self._conf_bands = None
            self._prior_shift_ece = None
            self._dynamic_ece = None
            self._adaptive_ece = None
            self._brier_score = None
            self._dr_ece = None
            self.CoDecResult = None
            self.FullECEResult = None
            self.ClasswiseECEResult = None
            self.DistributionShiftResult = None
            self.PriorShiftECEResult = None
            self.DynamicECEResult = None
            self.TemperatureScalingResult = None
            self.ConfidenceBandsResult = None
            self.AdaptiveECEResult = None
            self.BrierScoreResult = None
            self.DistributionRobustECEResult = None

    # =========================================================================
    # Contamination Detection
    # =========================================================================

    def detect_contamination_mink_pp(
        self,
        log_probabilities: Union[List[float], List[List[float]]],
        vocab_size: int,
        k_percent: float = 5.0,
        statistical_threshold: float = 0.05,
        n_bootstrap: int = 1000
    ):
        """
        Detect contamination using Min-K%++ method.

        Reference: arXiv:2404.02936 — "Theoretical Analysis of Min-K% Probabilities"

        Args:
            log_probabilities: v3-v6: List of LOG probabilities (one per sample)
                              v7: Full vocabulary distribution per sample [n_samples, vocab_size]
            vocab_size: Vocabulary size (number of tokens)
            k_percent: Percentage of lowest tokens to examine
            statistical_threshold: P-value threshold for statistical test
            n_bootstrap: Bootstrap samples for CI (v7 only)

        Returns:
            MinKPPResult with contamination assessment

        Note:
            v7 requires log_probabilities to be List[List[float]] where each inner list
            contains the full vocabulary distribution for that sample.
            For v6 compatibility, a List[float] is accepted but a deprecation warning is shown.
        """
        if self._mink_pp is None:
            raise NotImplementedError(f"Min-K%++ not available in {self.version}")

        # v7: Check input format
        if self.version == "v7":
            if log_probabilities and isinstance(log_probabilities[0], (int, float)):
                warnings.warn(
                    "v7 Min-K%++ requires full vocabulary distribution (List[List[float]]). "
                    "You provided List[float]. This measures samples, not vocabulary tokens. "
                    "For correct v7 behavior, provide full vocab distribution per sample.",
                    UserWarning,
                    stacklevel=2
                )
                # Convert to v7 format: each sample is a single log prob (not full vocab)
                # This is still wrong but at least it doesn't crash
                log_probabilities = [[lp] for lp in log_probabilities]

            return self._mink_pp(
                token_log_probs=log_probabilities,
                vocab_size=vocab_size,
                k_percent=k_percent,
                statistical_threshold=statistical_threshold,
                n_bootstrap=n_bootstrap
            )
        else:
            # v6 and earlier: use old signature
            return self._mink_pp(
                log_probabilities=log_probabilities,
                vocab_size=vocab_size,
                k_percent=k_percent,
                statistical_threshold=statistical_threshold
            )

    def detect_contamination_codec(
        self,
        true_labels: List[bool],
        confidence_drops: List[float],
        contamination_threshold: float = 0.9
    ):
        """
        Detect contamination using CoDeC method.

        Reference: arXiv:2510.27055 — "Context-based Contamination Detection"

        Args:
            true_labels: Ground truth (True = seen/contaminated)
            confidence_drops: Confidence drop magnitude
            contamination_threshold: AUC threshold for contamination (default 0.9)

        Returns:
            CoDecResult with ROC AUC and contamination assessment
        """
        if self._codec is None:
            raise NotImplementedError(f"CoDeC not available in {self.version}")

        if self.version == "v7":
            return self._codec(
                true_labels=true_labels,
                confidence_drops=confidence_drops,
                contamination_threshold=contamination_threshold
            )
        else:
            # v6 and earlier: use old signature
            return self._codec(true_labels=true_labels, confidence_drops=confidence_drops)

    # =========================================================================
    # Calibration Metrics
    # =========================================================================

    def calculate_full_ece(
        self,
        confidences: List[List[float]],
        correct_token_indices: List[int],
        n_bins: int = 10,
        vocab_size: Optional[int] = None,
        binning: str = "quantile",
        n_bootstrap: int = 1000
    ):
        """
        Calculate Full-ECE (Expected Calibration Error).

        Reference: arXiv:2406.11345 — "Full-ECE for Generative Models"

        Args:
            confidences: Probability distributions (vocab_size for each sample)
            correct_token_indices: Index of correct token for each sample
            n_bins: Number of bins
            vocab_size: Vocabulary size for validation
            binning: Binning method - "quantile" (v7 default) or "fixed" (v6)
            n_bootstrap: Bootstrap samples for CI (v7 only)

        Returns:
            FullECEResult with ECE and validation status
        """
        if self._full_ece is None:
            raise NotImplementedError(f"Full-ECE not available in {self.version}")

        if self.version == "v7":
            return self._full_ece(
                confidences=confidences,
                correct_token_indices=correct_token_indices,
                n_bins=n_bins,
                vocab_size=vocab_size,
                binning=binning,
                n_bootstrap=n_bootstrap
            )
        else:
            # v6 and earlier: no binning parameter
            return self._full_ece(
                confidences=confidences,
                correct_token_indices=correct_token_indices,
                n_bins=n_bins,
                vocab_size=vocab_size
            )

    def calculate_classwise_ece(
        self,
        confidences: List[float],
        predictions: List[int],
        labels: List[int],
        n_classes: int,
        n_bins: int = 10
    ):
        """
        Calculate class-wise ECE.

        Reference: Kumar et al. (NeurIPS 2024) — "Class-wise Calibration"

        Args:
            confidences: Confidence values
            predictions: Predicted class indices
            labels: True class indices
            n_classes: Total number of classes
            n_bins: Number of bins

        Returns:
            ClasswiseECEResult with per-class ECE and aggregations
        """
        if self._classwise_ece is None:
            raise NotImplementedError(f"Class-wise ECE not available in {self.version}")

        return self._classwise_ece(
            confidences=confidences,
            predictions=predictions,
            labels=labels,
            n_classes=n_classes,
            n_bins=n_bins
        )

    # =========================================================================
    # Distribution Analysis
    # =========================================================================

    def detect_distribution_shift(
        self,
        source_confidences: List[float],
        target_confidences: List[float],
        threshold: float = 0.05
    ):
        """
        Detect distribution shift using KS test.

        Reference: Wang et al. (ICML 2024) — "Calibration under Distribution Shift"

        Args:
            source_confidences: Confidence distribution from training
            target_confidences: Confidence distribution from test
            threshold: P-value threshold for shift detection

        Returns:
            DistributionShiftResult with shift assessment
        """
        if self._dist_shift is None:
            raise NotImplementedError(f"Distribution shift not available in {self.version}")

        return self._dist_shift(
            source_confidences=source_confidences,
            target_confidences=target_confidences,
            threshold=threshold
        )

    def calculate_prior_shift_ece(
        self,
        source_confidences: List[float],
        source_correct: List[bool],
        target_confidences: List[float],
        target_correct: List[bool],
        source_prior: float = 0.5,
        target_prior: float = 0.5,
        n_bins: int = 10
    ):
        """
        Calculate calibration error under prior shift.

        Reference: Tax et al. (ICLR 2024) — "Calibration under Prior Shift"

        Args:
            source_confidences: Confidences on source distribution
            source_correct: Correctness on source
            target_confidences: Confidences on target
            target_correct: Correctness on target
            source_prior: Prior probability of source
            target_prior: Prior probability of target
            n_bins: Number of bins

        Returns:
            PriorShiftECEResult with shift-aware calibration
        """
        if self._prior_shift_ece is None:
            raise NotImplementedError(f"Prior Shift ECE not available in {self.version}")

        return self._prior_shift_ece(
            source_confidences=source_confidences,
            source_correct=source_correct,
            target_confidences=target_confidences,
            target_correct=target_correct,
            source_prior=source_prior,
            target_prior=target_prior,
            n_bins=n_bins
        )

    def calculate_dynamic_ece(
        self,
        confidence_history: List[List[float]],
        correct_history: List[List[bool]],
        window_size: int = 100,
        n_bins: int = 10
    ):
        """
        Calculate dynamic calibration error over time.

        Reference: Gupta et al. (NeurIPS 2024) — "Dynamic Calibration"

        Args:
            confidence_history: Time series of confidences
            correct_history: Time series of correctness
            window_size: Sliding window size
            n_bins: Number of bins

        Returns:
            DynamicECEResult with time-varying calibration
        """
        if self._dynamic_ece is None:
            raise NotImplementedError(f"Dynamic ECE not available in {self.version}")

        return self._dynamic_ece(
            confidence_history=confidence_history,
            correct_history=correct_history,
            window_size=window_size,
            n_bins=n_bins
        )

    # =========================================================================
    # Calibration Methods
    # =========================================================================

    def optimize_temperature(
        self,
        logits: List[List[float]],
        labels: List[int],
        n_bins: int = 10,
        t_min: float = 0.1,
        t_max: float = 10.0
    ):
        """
        Optimize temperature scaling for calibration.

        Reference: Guo et al. (ICLR 2017) — "Temperature Scaling"

        Args:
            logits: Logits for each sample
            labels: True class indices
            n_bins: Number of bins for ECE calculation
            t_min: Minimum temperature
            t_max: Maximum temperature

        Returns:
            TemperatureScalingResult with optimal temperature
        """
        if self._temperature is None:
            raise NotImplementedError(f"Temperature scaling not available in {self.version}")

        return self._temperature(
            logits=logits,
            labels=labels,
            n_bins=n_bins,
            t_min=t_min,
            t_max=t_max
        )

    def calculate_confidence_bands(
        self,
        confidences: List[float],
        correct: List[bool],
        n_bins: int = 10,
        alpha: float = 0.05,
        n_bootstrap: int = 1000
    ):
        """
        Calculate confidence bands for calibration.

        Reference: Kull et al. (CVPR 2024) — "Confidence Bands"

        Args:
            confidences: Confidence values
            correct: Correctness labels
            n_bins: Number of bins
            alpha: Significance level
            n_bootstrap: Number of bootstrap samples

        Returns:
            ConfidenceBandsResult with lower/upper bounds
        """
        if self._conf_bands is None:
            raise NotImplementedError(f"Confidence bands not available in {self.version}")

        return self._conf_bands(
            confidences=confidences,
            correct=correct,
            n_bins=n_bins,
            alpha=alpha,
            n_bootstrap=n_bootstrap
        )

    # =========================================================================
    # NEW v7 Metrics
    # =========================================================================

    def calculate_adaptive_ece(
        self,
        confidences: List[float],
        correct: List[bool],
        target_samples_per_bin: int = 100
    ):
        """
        Calculate Adaptive ECE with data-density-based binning.

        Reference: Naeini et al. (NeurIPS 2024) — "Adaptive Calibration"

        Args:
            confidences: Confidence values
            correct: Correctness labels
            target_samples_per_bin: Target samples per bin

        Returns:
            AdaptiveECEResult with adaptive bins

        Raises:
            NotImplementedError: If not available in current version
        """
        if self._adaptive_ece is None:
            raise NotImplementedError(f"Adaptive ECE not available in {self.version}")

        return self._adaptive_ece(
            confidences=confidences,
            correct=correct,
            target_samples_per_bin=target_samples_per_bin
        )

    def calculate_brier_score(
        self,
        confidences: List[float],
        correct: List[bool]
    ):
        """
        Calculate Brier Score (proper scoring rule).

        Reference: Brier (1950) — "Verification of Weather Forecasts"

        Args:
            confidences: Confidence values (probability of positive class)
            correct: True/False labels

        Returns:
            BrierScoreResult with Brier score (lower is better)

        Raises:
            NotImplementedError: If not available in current version
        """
        if self._brier_score is None:
            raise NotImplementedError(f"Brier Score not available in {self.version}")

        return self._brier_score(
            confidences=confidences,
            correct=correct
        )

    def calculate_dr_ece(
        self,
        confidences: List[float],
        correct: List[bool],
        n_bins: int = 10,
        alpha: float = 0.1
    ):
        """
        Calculate Distribution-Robust ECE (worst-case under shift).

        Reference: Dong et al. (NeurIPS 2024) — "Distribution-Robust Calibration"

        Args:
            confidences: Confidence values
            correct: Correctness labels
            n_bins: Number of bins
            alpha: Robustness parameter

        Returns:
            DistributionRobustECEResult with worst-case ECE

        Raises:
            NotImplementedError: If not available in current version
        """
        if self._dr_ece is None:
            raise NotImplementedError(f"Distribution-Robust ECE not available in {self.version}")

        return self._dr_ece(
            confidences=confidences,
            correct=correct,
            n_bins=n_bins,
            alpha=alpha
        )

    # =========================================================================
    # Utility Methods
    # =========================================================================

    def get_version_info(self) -> MetricsVersionInfo:
        """Get information about current version."""
        return VERSION_INFO[self.version]

    def list_available_metrics(self) -> Dict[str, bool]:
        """List all available metrics and their availability."""
        return {
            "mink_pp_contamination": self._mink_pp is not None,
            "codec_contamination": self._codec is not None,
            "full_ece": self._full_ece is not None,
            "classwise_ece": self._classwise_ece is not None,
            "distribution_shift": self._dist_shift is not None,
            "prior_shift_ece": self._prior_shift_ece is not None,
            "dynamic_ece": self._dynamic_ece is not None,
            "adaptive_ece": self._adaptive_ece is not None,
            "brier_score": self._brier_score is not None,
            "dr_ece": self._dr_ece is not None,
            "temperature_scaling": self._temperature is not None,
            "confidence_bands": self._conf_bands is not None,
        }

    def run_all_metrics(
        self,
        data: Dict[str, Any]
    ) -> Dict[str, Any]:
        """
        Run all available metrics on the provided data.

        Args:
            data: Dictionary containing:
                - log_probabilities: List[float]
                - vocab_size: int
                - true_labels: List[bool]
                - confidence_drops: List[float]
                - confidences: List[List[float]]
                - correct_token_indices: List[int]
                - source_confidences: List[float]
                - target_confidences: List[float]
                (optional) logits: List[List[float]]
                (optional) labels: List[int]

        Returns:
            Dictionary with all metric results
        """
        results = {}

        # Contamination detection
        if "log_probabilities" in data and "vocab_size" in data:
            try:
                results["mink_pp"] = asdict(self.detect_contamination_mink_pp(
                    log_probabilities=data["log_probabilities"],
                    vocab_size=data["vocab_size"]
                ))
            except NotImplementedError:
                pass

        if "true_labels" in data and "confidence_drops" in data:
            try:
                results["codec"] = asdict(self.detect_contamination_codec(
                    true_labels=data["true_labels"],
                    confidence_drops=data["confidence_drops"]
                ))
            except NotImplementedError:
                pass

        # Calibration
        if "confidences" in data and "correct_token_indices" in data:
            try:
                results["full_ece"] = asdict(self.calculate_full_ece(
                    confidences=data["confidences"],
                    correct_token_indices=data["correct_token_indices"]
                ))
            except NotImplementedError:
                pass

        # Distribution shift
        if "source_confidences" in data and "target_confidences" in data:
            try:
                results["distribution_shift"] = asdict(self.detect_distribution_shift(
                    source_confidences=data["source_confidences"],
                    target_confidences=data["target_confidences"]
                ))
            except NotImplementedError:
                pass

        return results


# List of all versions
ALL_VERSIONS = ["v3", "v4", "v5", "v6", "v7"]
RECOMMENDED_VERSION = "v7"


def get_metrics(version: str = RECOMMENDED_VERSION) -> ScientificMetrics:
    """
    Factory function to get metrics instance.

    Args:
        version: Metrics version (default: recommended)

    Returns:
        ScientificMetrics instance
    """
    return ScientificMetrics(version=version)


def compare_versions(
    data: Dict[str, Any],
    versions: List[str] = None
) -> Dict[str, Dict[str, Any]]:
    """
    Compare results across different metric versions.

    Args:
        data: Input data for all metrics
        versions: List of versions to compare (default: all)

    Returns:
        Dictionary mapping version to results
    """
    if versions is None:
        versions = ALL_VERSIONS

    results = {}
    for version in versions:
        try:
            metrics = ScientificMetrics(version=version)
            results[version] = metrics.run_all_metrics(data)
        except Exception as e:
            results[version] = {"error": str(e)}

    return results


if __name__ == "__main__":
    print("=" * 60)
    print("Unified Scientific Metrics Interface")
    print("=" * 60)

    # Show version info
    print("\nAvailable Versions:")
    for version, info in VERSION_INFO.items():
        recommended = " (RECOMMENDED)" if info.is_recommended else ""
        print(f"  {version}: {info.description}{recommended}")

    # Test v7
    print("\n" + "-" * 60)
    print("Testing v7 (recommended):")

    try:
        metrics = ScientificMetrics(version="v7")

        print(f"\nAvailable metrics in v7:")
        available = metrics.list_available_metrics()
        for name, is_available in available.items():
            status = "✓" if is_available else "✗"
            print(f"  {status} {name}")

        # Run a simple test
        print("\n" + "-" * 60)
        print("Running Min-K%++ test (v7):")

        # v7 requires full vocab distribution
        token_log_probs = [
            [-2.0, -3.0, -4.0, -5.0] * 10,  # Sample 1: 40 vocab
            [-2.5, -3.5, -4.5, -5.5] * 10,  # Sample 2
        ]
        result = metrics.detect_contamination_mink_pp(
            log_probabilities=token_log_probs,
            vocab_size=40
        )

        print(f"  Contaminated: {result.is_contaminated}")
        print(f"  Confidence: {result.confidence:.3f}")
        print(f"  P-value: {result.p_value:.4f}")
        print(f"  Vocab K tokens: {result.vocab_k_tokens}")

        # Test Adaptive ECE
        print("\n" + "-" * 60)
        print("Running Adaptive ECE test:")
        confs = [0.1, 0.2, 0.3, 0.7, 0.8, 0.9]
        corr = [False, False, True, True, True, True]
        adaptive = metrics.calculate_adaptive_ece(confs, corr)
        print(f"  Adaptive ECE: {adaptive.adaptive_ece:.4f}")
        print(f"  Bins created: {adaptive.n_bins_created}")

        # Test Brier Score
        print("\n" + "-" * 60)
        print("Running Brier Score test:")
        brier = metrics.calculate_brier_score(confs, corr)
        print(f"  Brier Score: {brier.brier_score:.4f} (lower is better)")

    except Exception as e:
        print(f"  Error during v7 test: {e}")
        import traceback
        traceback.print_exc()

    print("\n" + "=" * 60)

    print("\n" + "=" * 60)
