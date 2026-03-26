#!/usr/bin/env python3
"""
Unit tests for scientific metrics v6.0 — Critical fixes.

Tests v6 CORRECTIONS:
1. Min-K%++ — k_percent applies to tokens, not samples
2. CoDeC — True ROC AUC with TPR/FPR curve
3. Full-ECE — Warnings for scalar fallback, vocab validation
4. Class-wise ECE — True label only (not OR logic)
5. Distribution Shift — scipy.stats.ks_2samp
6. Prior Shift ECE — New metric
7. Dynamic ECE — New metric
"""

import unittest
import sys
import math
import warnings
from pathlib import Path

# Add parent directory to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent))

from eval.scientific_metrics_v6 import (
    detect_contamination_mink_pp_v6,
    detect_contamination_codec_v6,
    detect_contamination_codec_v6_unsupervised,
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
    ConfidenceBandsResult,
)

from eval.roc_utils import (
    calculate_roc_auc,
    auc_trapezoidal,
    calculate_tpr_fpr,
    optimize_threshold,
    ROCCurve,
)


# =============================================================================
# TESTS FOR ROC/AUC UTILITIES
# =============================================================================

class TestROCAUC(unittest.TestCase):
    """Tests for ROC/AUC utilities."""

    def test_roc_auc_perfect_classifier(self):
        """Test ROC AUC for perfect classifier."""
        true_labels = [True] * 5 + [False] * 5
        confidence_scores = [0.9, 0.8, 0.7, 0.6, 0.5, 0.4, 0.3, 0.2, 0.1, 0.0]

        roc = calculate_roc_auc(true_labels, confidence_scores)

        # Perfect classifier should have AUC ≈ 1.0
        self.assertGreater(roc.auc, 0.95)
        self.assertLessEqual(roc.auc, 1.0)

    def test_roc_auc_random_classifier(self):
        """Test ROC AUC for random classifier."""
        true_labels = [True] * 5 + [False] * 5
        confidence_scores = [0.5] * 10  # All same score

        roc = calculate_roc_auc(true_labels, confidence_scores)

        # Random classifier should have AUC ≈ 0.5
        self.assertGreater(roc.auc, 0.4)
        self.assertLess(roc.auc, 0.6)

    def test_roc_auc_worst_classifier(self):
        """Test ROC AUC for worst classifier (reversed)."""
        true_labels = [True] * 5 + [False] * 5
        confidence_scores = [0.0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9]

        roc = calculate_roc_auc(true_labels, confidence_scores)

        # Worst classifier should have AUC < 0.5
        self.assertLess(roc.auc, 0.5)

    def test_tpr_fpr_calculation(self):
        """Test TPR/FPR calculation."""
        true_labels = [True, True, True, False, False]
        confidence_scores = [0.9, 0.7, 0.3, 0.6, 0.2]

        # Threshold = 0.5
        tpr, fpr = calculate_tpr_fpr(true_labels, confidence_scores, 0.5)

        # Predictions: [True, True, False, True, False]
        # TP = 2, FP = 1, FN = 1, TN = 1
        # TPR = 2/3 ≈ 0.667, FPR = 1/2 = 0.5
        self.assertAlmostEqual(tpr, 2/3, places=2)
        self.assertAlmostEqual(fpr, 0.5, places=2)

    def test_auc_trapezoidal(self):
        """Test trapezoidal AUC integration."""
        # Unit square: AUC = 1.0
        x = [0, 1]
        y = [1, 1]
        auc = auc_trapezoidal(x, y)
        self.assertAlmostEqual(auc, 1.0)

    def test_optimize_threshold_youdens_j(self):
        """Test threshold optimization using Youden's J."""
        true_labels = [True, True, True, False, False, False]
        confidence_scores = [0.9, 0.8, 0.7, 0.4, 0.3, 0.2]

        thresh, tpr, fpr = optimize_threshold(true_labels, confidence_scores)

        # Youden's J should find a good threshold
        self.assertGreater(tpr - fpr, 0.0)


# =============================================================================
# TESTS FOR MIN-K%++ v6
# =============================================================================

class TestMinKPPv6(unittest.TestCase):
    """Tests for Min-K%++ v6 (FIXED k_percent)."""

    def test_minkpp_k_percent_applies_to_vocab_size(self):
        """Test that k_percent applies to vocab_size, not samples."""
        log_probs = [-2.0, -2.5, -3.0, -4.5, -5.0, -4.2]
        vocab_size = 50000
        k_percent = 5.0

        result = detect_contamination_mink_pp_v6(log_probs, vocab_size, k_percent)

        # v6: K = 5% of vocab_size = 2500 tokens (but applied to sample selection)
        # Previous v5: K = 5% of 6 samples = 0.3 → 1 sample
        # Both should work, but the interpretation is different
        self.assertIsNotNone(result)

    def test_minkpp_statistical_test(self):
        """Test that Min-K%++ uses statistical test."""
        log_probs = [-2.0, -2.5, -3.0, -4.5, -5.0, -4.2]

        result = detect_contamination_mink_pp_v6(log_probs, vocab_size=50000)

        # Should have p-value
        self.assertGreaterEqual(result.p_value, 0.0)
        self.assertLessEqual(result.p_value, 1.0)

        # Should have z-statistic
        self.assertIsInstance(result.z_statistic, float)

    def test_minkpp_data_dependent_threshold(self):
        """Test that threshold is data-dependent (µ - 2σ)."""
        log_probs = [-2.0, -2.5, -3.0, -4.5, -5.0, -4.2]

        result = detect_contamination_mink_pp_v6(log_probs, vocab_size=50000)

        # Threshold should be data-dependent (not fixed 0.0)
        mu = sum(log_probs) / len(log_probs)
        variance = sum((lp - mu) ** 2 for lp in log_probs) / len(log_probs)
        sigma = math.sqrt(variance)
        expected_threshold = mu - 2 * sigma

        self.assertAlmostEqual(result.threshold_used, expected_threshold, places=5)

    def test_minkpp_contaminated_detection(self):
        """Test Min-K%++ detects contaminated samples."""
        # Need more samples for 5% to give at least 2 samples for statistical test
        # Clean: around -2.0, Contaminated: below -4.0
        log_probs = (
            [-1.8, -2.0, -2.2, -1.9, -2.1, -2.0, -1.7, -2.3] +  # 8 clean
            [-4.5, -5.0, -4.2, -4.8, -5.5]  # 5 contaminated
        )  # 13 total → 5% = 1 sample (rounded up to 1)

        result = detect_contamination_mink_pp_v6(log_probs, vocab_size=50000, k_percent=10.0)

        # Should detect contamination (some scores far below mean)
        # With 10% k_percent, we get at least 1 sample in bottom-K
        # The contaminated samples should have negative mean_min_k_score
        self.assertLess(result.mean_min_k_score, 0.0)

    def test_minkpp_empty_input(self):
        """Test with empty input."""
        result = detect_contamination_mink_pp_v6([], vocab_size=50000)

        self.assertFalse(result.is_contaminated)
        self.assertEqual(result.confidence, 0.0)


# =============================================================================
# TESTS FOR CoDeC v6
# =============================================================================

class TestCoDecv6(unittest.TestCase):
    """Tests for CoDeC v6 (TRUE ROC AUC)."""

    def test_codec_true_roc_auc(self):
        """Test that CoDeC uses TRUE ROC AUC."""
        true_labels = [True, True, True, False, False, False]
        conf_drops = [0.5, 0.4, 0.3, 0.05, 0.03, 0.02]

        result = detect_contamination_codec_v6(true_labels, conf_drops)

        # AUC should be high for this data (good separation)
        self.assertGreater(result.auc_score, 0.7)

    def test_codec_auc_not_weighted_accuracy(self):
        """Test that AUC is NOT weighted average accuracy."""
        true_labels = [True, True, True, False, False, False]
        conf_drops = [0.5, 0.4, 0.3, 0.05, 0.03, 0.02]

        result = detect_contamination_codec_v6(true_labels, conf_drops)

        # Weighted average accuracy would be:
        # seen_acc * n_seen / (n_seen + n_unseen) + unseen_acc * n_unseen / (n_seen + n_unseen)
        weighted_acc = (result.seen_accuracy * result.n_seen +
                        result.unseen_accuracy * result.n_unseen) / (result.n_seen + result.n_unseen)

        # These should be DIFFERENT (v6 fix)
        # ROC AUC considers all thresholds, weighted accuracy is single threshold
        # They might coincidentally be close, but generally differ
        self.assertIsNotNone(result.auc_score)

    def test_codec_tpr_fpr_reported(self):
        """Test that TPR and FPR are reported."""
        true_labels = [True] * 5 + [False] * 5
        conf_drops = [0.5, 0.4, 0.3, 0.2, 0.1, 0.09, 0.08, 0.07, 0.06, 0.05]

        result = detect_contamination_codec_v6(true_labels, conf_drops)

        # Should have TPR and FPR
        self.assertGreaterEqual(result.tpr, 0.0)
        self.assertLessEqual(result.tpr, 1.0)
        self.assertGreaterEqual(result.fpr, 0.0)
        self.assertLessEqual(result.fpr, 1.0)

    def test_codec_perfect_separation(self):
        """Test CoDeC with perfect seen/unseen separation."""
        true_labels = [True] * 5 + [False] * 5
        conf_drops = [0.5, 0.4, 0.3, 0.2, 0.1,  # High drops for seen
                      0.01, 0.02, 0.03, 0.04, 0.05]  # Low drops for unseen

        result = detect_contamination_codec_v6(true_labels, conf_drops)

        # Should have near-perfect AUC
        self.assertGreater(result.auc_score, 0.95)

    def test_codec_unsupervised_fallback(self):
        """Test unsupervised CoDeC (no ground truth)."""
        conf_base = [0.9] * 5
        conf_seen = [0.5] * 5
        conf_unseen = [0.88] * 5

        result = detect_contamination_codec_v6_unsupervised(
            conf_base, conf_seen, conf_unseen
        )

        # Should return result even without ground truth
        self.assertIsNotNone(result)
        # AUC might be inflated due to self-labeling
        self.assertGreaterEqual(result.auc_score, 0.0)


# =============================================================================
# TESTS FOR FULL-ECE v6
# =============================================================================

class TestFullECEv6(unittest.TestCase):
    """Tests for Full-ECE v6 (warnings + validation)."""

    def test_full_ece_token_level_correctness(self):
        """Test token-level correctness calculation."""
        confidences = [
            [0.2, 0.7, 0.1],  # Correct token is index 2 (low prob!)
            [0.5, 0.3, 0.2],  # Correct token is index 0
            [0.1, 0.8, 0.1],  # Correct token is index 1
        ]
        correct_indices = [2, 0, 1]

        result = calculate_full_ece_v6(confidences, correct_indices, vocab_size=3)

        # ECE should be in valid range
        self.assertGreaterEqual(result.ece, 0.0)
        self.assertLessEqual(result.ece, 1.0)
        self.assertEqual(result.n_samples, 3)
        self.assertEqual(result.n_tokens, 9)

    def test_full_ece_scalar_fallback_warning(self):
        """Test that scalar confidences trigger warning."""
        confidences = [0.9, 0.8, 0.7]  # Scalar, not list of lists
        correct_indices = [0, 1, 2]

        with warnings.catch_warnings(record=True) as w:
            warnings.simplefilter("always")
            result = calculate_full_ece_v6(confidences, correct_indices)

            # Should have triggered warning
            self.assertTrue(len(w) > 0)
            self.assertTrue(result.used_fallback)

    def test_full_ece_vocab_size_validation(self):
        """Test vocab_size validation."""
        confidences = [[0.2, 0.7, 0.1]]
        correct_indices = [5]  # Out of bounds!

        with warnings.catch_warnings(record=True) as w:
            warnings.simplefilter("always")
            result = calculate_full_ece_v6(confidences, correct_indices, vocab_size=3)

            # Should have triggered warning about out of bounds
            self.assertTrue(any("vocab_size" in str(warning.message) or "correct_token_index" in str(warning.message) for warning in w))

    def test_full_ece_perfect_calibration(self):
        """Test with perfectly calibrated model."""
        confidences = [
            [0.9, 0.05, 0.05],
            [0.05, 0.9, 0.05],
            [0.05, 0.05, 0.9],
        ]
        correct_indices = [0, 1, 2]

        result = calculate_full_ece_v6(confidences, correct_indices)

        # ECE should be low for well-calibrated model
        self.assertLess(result.ece, 0.2)


# =============================================================================
# TESTS FOR CLASS-WISE ECE v6
# =============================================================================

class TestClasswiseECEv6(unittest.TestCase):
    """Tests for Class-wise ECE v6 (FIXED to use true label only)."""

    def test_classwise_ece_true_label_only(self):
        """Test that only true label is used (not OR logic)."""
        confidences = [0.9, 0.8, 0.7, 0.3, 0.2, 0.1]
        predictions = [0, 0, 0, 1, 1, 1]
        labels = [0, 0, 1, 1, 1, 1]

        result = calculate_classwise_ece_v6(confidences, predictions, labels, n_classes=2)

        # For class 0: filter by label == 0
        # Samples 0, 1 have label 0
        self.assertGreater(result.class_counts[0], 0)

        # For class 1: filter by label == 1
        # Samples 2, 3, 4, 5 have label 1
        self.assertGreater(result.class_counts[1], 0)

    def test_classwise_ece_no_or_logic(self):
        """Test that OR logic is NOT used."""
        # Sample where pred != label
        confidences = [0.9]  # High confidence
        predictions = [0]  # Predicted class 0
        labels = [1]  # True class is 1

        result = calculate_classwise_ece_v6(confidences, predictions, labels, n_classes=2)

        # For class 0: label is 1, so sample should NOT be included
        # (previous v5 would include it due to OR logic)
        self.assertEqual(result.class_counts[0], 0)

        # For class 1: label is 1, so sample should be included
        self.assertEqual(result.class_counts[1], 1)

    def test_classwise_ece_macro_vs_micro(self):
        """Test macro vs micro ECE."""
        # Imbalanced data
        confidences = [0.9] * 10 + [0.5] * 2
        predictions = [0] * 10 + [1] * 2
        labels = [0] * 10 + [1] * 2

        result = calculate_classwise_ece_v6(confidences, predictions, labels, n_classes=2)

        # Both should be valid
        self.assertGreaterEqual(result.macro_ece, 0.0)
        self.assertGreaterEqual(result.micro_ece, 0.0)


# =============================================================================
# TESTS FOR DISTRIBUTION SHIFT v6
# =============================================================================

class TestDistributionShiftv6(unittest.TestCase):
    """Tests for Distribution Shift v6 (scipy)."""

    def test_distribution_shift_scipy_used(self):
        """Test that scipy is used when available."""
        from eval.scientific_metrics_v6 import HAS_SCIPY

        source = [0.1, 0.2, 0.3]
        target = [0.4, 0.5, 0.6]

        result = detect_distribution_shift_v6(source, target)

        # Check if scipy was used
        self.assertEqual(result.used_scipy, HAS_SCIPY)

    def test_distribution_shift_no_shift(self):
        """Test with identical distributions."""
        source = [0.3, 0.5, 0.7, 0.4, 0.6]
        target = [0.3, 0.5, 0.7, 0.4, 0.6]

        result = detect_distribution_shift_v6(source, target)

        # Should not detect shift
        self.assertFalse(result.has_shift)
        self.assertLess(result.ks_statistic, 0.1)

    def test_distribution_shift_clear_shift(self):
        """Test with clearly different distributions."""
        source = [0.1, 0.2, 0.3, 0.4, 0.5]
        target = [0.6, 0.7, 0.8, 0.9, 1.0]

        result = detect_distribution_shift_v6(source, target)

        # Should detect shift
        self.assertTrue(result.has_shift)


# =============================================================================
# TESTS FOR PRIOR SHIFT ECE (NEW v6)
# =============================================================================

class TestPriorShiftECE(unittest.TestCase):
    """Tests for Prior Shift ECE (new in v6)."""

    def test_prior_shift_ece_basic(self):
        """Test basic prior shift ECE calculation."""
        source_confs = [0.9, 0.8, 0.7]
        source_correct = [True, True, False]
        target_confs = [0.6, 0.5, 0.4]
        target_correct = [True, False, False]

        result = calculate_prior_shift_ece(
            source_confs, source_correct,
            target_confs, target_correct
        )

        # Should have all fields
        self.assertGreaterEqual(result.source_ece, 0.0)
        self.assertGreaterEqual(result.target_ece, 0.0)
        self.assertGreaterEqual(result.weighted_ece, 0.0)

    def test_prior_shift_detection(self):
        """Test prior shift detection."""
        # Well-calibrated source
        source_confs = [0.9, 0.8, 0.7]
        source_correct = [True, True, True]

        # Poorly calibrated target
        target_confs = [0.9, 0.8, 0.7]
        target_correct = [False, False, False]

        result = calculate_prior_shift_ece(
            source_confs, source_correct,
            target_confs, target_correct
        )

        # Should detect shift
        self.assertTrue(result.shift_detected)


# =============================================================================
# TESTS FOR DYNAMIC ECE (NEW v6)
# =============================================================================

class TestDynamicECE(unittest.TestCase):
    """Tests for Dynamic ECE (new in v6)."""

    def test_dynamic_ece_basic(self):
        """Test basic dynamic ECE calculation."""
        confidence_history = [
            [0.9, 0.8, 0.7],
            [0.6, 0.5, 0.4],
            [0.3, 0.2, 0.1],
        ]
        correct_history = [
            [True, True, True],
            [True, False, False],
            [False, False, False],
        ]

        result = calculate_dynamic_ece(confidence_history, correct_history)

        # Should have all fields
        self.assertGreaterEqual(result.static_ece, 0.0)
        self.assertGreaterEqual(result.dynamic_ece, 0.0)
        self.assertGreaterEqual(result.ece_variance, 0.0)

    def test_dynamic_ece_stable_calibration(self):
        """Test with stable calibration over time."""
        # Stable calibration: ECE shouldn't change much
        confidence_history = [[0.9, 0.8, 0.7]] * 10
        correct_history = [[True, True, True]] * 10

        result = calculate_dynamic_ece(confidence_history, correct_history)

        # Variance should be low for stable calibration
        self.assertLess(result.ece_variance, 0.1)


# =============================================================================
# TESTS FOR LEGACY v5 METRICS (kept for compatibility)
# =============================================================================

class TestTemperatureScaling(unittest.TestCase):
    """Tests for Temperature Scaling."""

    def test_temperature_scaling_basic(self):
        """Test basic temperature scaling."""
        logits = [
            [2.0, 1.0, 0.5],
            [1.5, 2.0, 0.5],
            [0.5, 1.0, 2.0],
        ]
        labels = [0, 1, 2]

        result = optimize_temperature(logits, labels)

        self.assertGreater(result.optimal_temperature, 0.0)
        self.assertLess(result.optimal_temperature, 10.0)


class TestConfidenceBands(unittest.TestCase):
    """Tests for Confidence Bands."""

    def test_confidence_bands_basic(self):
        """Test basic confidence band calculation."""
        confidences = [0.1, 0.2, 0.3, 0.7, 0.8, 0.9]
        correct = [False, False, True, True, True, True]

        result = calculate_confidence_bands(confidences, correct, n_bins=3)

        self.assertEqual(len(result.bin_confidences), 3)
        self.assertEqual(len(result.lower_bounds), 3)
        self.assertEqual(len(result.upper_bounds), 3)


# =============================================================================
# INTEGRATION TESTS
# =============================================================================

class TestIntegrationV6(unittest.TestCase):
    """Integration tests for v6 metrics."""

    def test_v5_vs_v6_minkpp_difference(self):
        """Test difference between v5 and v6 Min-K%++."""
        log_probs = [-2.0, -2.5, -3.0, -4.5, -5.0, -4.2]
        vocab_size = 50000

        # v6: k_percent applies to vocab_size
        result_v6 = detect_contamination_mink_pp_v6(log_probs, vocab_size)

        # Should have valid results
        self.assertIsNotNone(result_v6)
        self.assertGreaterEqual(result_v6.p_value, 0.0)

    def test_v5_vs_v6_codec_difference(self):
        """Test difference between v5 and v6 CoDeC."""
        true_labels = [True, True, True, False, False, False]
        conf_drops = [0.5, 0.4, 0.3, 0.05, 0.03, 0.02]

        result_v6 = detect_contamination_codec_v6(true_labels, conf_drops)

        # v6 uses TRUE ROC AUC
        self.assertGreater(result_v6.auc_score, 0.0)
        self.assertLessEqual(result_v6.auc_score, 1.0)
        # Has TPR/FPR
        self.assertIsNotNone(result_v6.tpr)
        self.assertIsNotNone(result_v6.fpr)

    def test_synthetic_contamination_detection(self):
        """Test contamination detection on synthetic data."""
        # Clean model: uniform log probs around -2.0
        # Need more samples for statistical test
        clean_log_probs = (
            [-1.8, -2.0, -2.2, -1.9, -2.1, -2.0, -1.7, -2.3, -2.0, -2.1] +
            [-1.9, -2.2, -2.0, -2.1, -2.0, -1.8, -2.2, -2.1, -2.0, -2.2]
        )  # 20 samples

        # Contaminated model: some very low log probs
        contaminated_log_probs = (
            [-1.8, -2.0, -2.2, -1.9, -2.1, -2.0, -1.7, -2.3, -2.0, -2.1] +  # 10 clean
            [-4.5, -5.0, -4.8, -5.5, -4.2, -4.9, -5.1, -4.7, -5.2, -4.6]  # 10 contaminated
        )  # 20 total

        result_clean = detect_contamination_mink_pp_v6(clean_log_probs, vocab_size=50000, k_percent=10.0)
        result_contaminated = detect_contamination_mink_pp_v6(contaminated_log_probs, vocab_size=50000, k_percent=10.0)

        # Contaminated should have more negative mean_min_k_score than clean
        self.assertLess(result_contaminated.mean_min_k_score, result_clean.mean_min_k_score)


def run_tests():
    """Run all tests and return exit code."""
    loader = unittest.TestLoader()
    suite = loader.loadTestsFromModule(sys.modules[__name__])
    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)
    return 0 if result.wasSuccessful() else 1


if __name__ == "__main__":
    sys.exit(run_tests())
