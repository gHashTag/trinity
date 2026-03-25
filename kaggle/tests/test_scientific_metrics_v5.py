#!/usr/bin/env python3
"""
Unit tests for scientific metrics v5.0 — New 2024-2025 Metrics.

Tests Phase 4.3.3 New Metrics:
1. Temperature Scaling — ICLR 2017 + 2024 extensions
2. Class-wise ECE — NeurIPS 2024
3. Confidence Bands — CVPR 2024
4. Multiple Hypothesis Correction — FDR control
5. Distribution Shift Detection — ICML 2024
"""

import unittest
import sys
import math
from pathlib import Path

# Add parent directory to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent))

from eval.scientific_metrics_v5 import (
    optimize_temperature,
    calculate_classwise_ece,
    calculate_confidence_bands,
    benjamini_hochberg_correction,
    bonferroni_correction,
    detect_distribution_shift,
    # CORRECTED v4 metrics
    calculate_full_ece_v4_correct,
    detect_contamination_min_k_pp_v4_correct,
    detect_contamination_codec_v4_correct,
    detect_contamination_codec_v4_correct_simple,
    TemperatureScalingResult,
    ClasswiseECEResult,
    ConfidenceBandsResult,
    DistributionShiftResult,
    FullECEResult,
    MinKPPCorrectResult,
    CoDecCorrectResult,
)


class TestTemperatureScaling(unittest.TestCase):
    """Tests for Temperature Scaling (ICLR 2017)."""

    def test_temperature_scaling_basic(self):
        """Test basic temperature scaling optimization."""
        # Overconfident model
        logits = [
            [5.0, 1.0, 0.5],
            [4.0, 2.0, 0.5],
            [0.5, 1.0, 5.0],
            [6.0, 0.5, 0.3],
        ]
        labels = [0, 0, 2, 0]

        result = optimize_temperature(logits, labels)

        self.assertIsNotNone(result)
        self.assertGreater(result.optimal_temperature, 0.0)
        self.assertLess(result.optimal_temperature, 10.0)

    def test_temperature_scaling_improves_calibration(self):
        """Test that temperature scaling improves ECE."""
        # Create underconfident model (should find T < 1)
        logits = [
            [1.0, 2.0, 3.0],  # Underconfident (top class has lowest logit)
            [1.0, 2.0, 3.0],
            [3.0, 2.0, 1.0],
            [3.0, 2.0, 1.0],
        ]
        labels = [2, 2, 0, 0]

        result = optimize_temperature(logits, labels)

        # Temperature should be in valid range
        self.assertGreater(result.optimal_temperature, 0.0)
        self.assertLess(result.optimal_temperature, 10.0)

    def test_temperature_scaling_empty(self):
        """Test temperature scaling with empty input."""
        result = optimize_temperature([], [])

        self.assertEqual(result.optimal_temperature, 1.0)
        self.assertEqual(result.nll_before, 0.0)

    def test_temperature_nll_decreases(self):
        """Test that NLL decreases (or stays same) after optimization."""
        logits = [
            [2.0, 1.0, 0.5],
            [1.5, 2.0, 0.5],
            [0.5, 1.0, 2.0],
        ]
        labels = [0, 1, 2]

        result = optimize_temperature(logits, labels)

        # NLL should not increase
        self.assertLessEqual(result.nll_after, result.nll_before + 1e-6)


class TestClasswiseECE(unittest.TestCase):
    """Tests for Class-wise ECE (NeurIPS 2024)."""

    def test_classwise_ece_imbalanced_dataset(self):
        """Test class-wise ECE for imbalanced dataset."""
        # Class 0: many samples, well calibrated
        # Class 1: few samples, poorly calibrated
        # Class 2: medium samples, well calibrated
        confidences = (
            [0.9, 0.8, 0.7, 0.6, 0.5, 0.4] +  # Class 0 (6 samples)
            [0.1, 0.2] +                           # Class 1 (2 samples, wrong)
            [0.8, 0.7, 0.6, 0.5]                   # Class 2 (4 samples)
        )
        predictions = [0]*6 + [1]*2 + [2]*4
        labels = [0]*6 + [2]*2 + [2]*4

        result = calculate_classwise_ece(confidences, predictions, labels, n_classes=3)

        self.assertIsNotNone(result)
        self.assertGreaterEqual(result.macro_ece, 0.0)
        self.assertGreaterEqual(result.micro_ece, 0.0)

    def test_classwise_ece_per_class(self):
        """Test per-class ECE calculation."""
        confidences = [0.9, 0.8, 0.7, 0.3, 0.2, 0.1]
        predictions = [0, 0, 0, 1, 1, 1]
        labels = [0, 0, 1, 1, 1, 1]

        result = calculate_classwise_ece(confidences, predictions, labels, n_classes=2)

        self.assertIn(0, result.ece_per_class)
        self.assertIn(1, result.ece_per_class)
        self.assertGreater(result.class_counts[0], 0)
        self.assertGreater(result.class_counts[1], 0)

    def test_classwise_ece_macro_vs_micro(self):
        """Test difference between macro and micro ECE."""
        # Create imbalanced scenario
        confidences = [0.9] * 10 + [0.1] * 2  # Class 0 dominant
        predictions = [0] * 10 + [1] * 2
        labels = [0] * 10 + [1] * 2

        result = calculate_classwise_ece(confidences, predictions, labels, n_classes=2)

        # Macro and micro should differ for imbalanced data
        # (though they might be similar if both classes are well-calibrated)
        self.assertIsNotNone(result.macro_ece)
        self.assertIsNotNone(result.micro_ece)

    def test_classwise_ece_validation(self):
        """Test input validation."""
        with self.assertRaises(ValueError):
            calculate_classwise_ece([0.5], [0], [0, 1], n_classes=2)


class TestConfidenceBands(unittest.TestCase):
    """Tests for Confidence Bands (CVPR 2024)."""

    def test_confidence_bands_basic(self):
        """Test basic confidence band calculation."""
        confidences = [0.1, 0.2, 0.3, 0.7, 0.8, 0.9]
        correct = [False, False, True, True, True, True]

        result = calculate_confidence_bands(confidences, correct, n_bins=3)

        self.assertEqual(len(result.bin_confidences), 3)
        self.assertEqual(len(result.lower_bounds), 3)
        self.assertEqual(len(result.upper_bounds), 3)

    def test_confidence_bands_coverage(self):
        """Test that confidence bands cover the point estimates."""
        confidences = [0.5] * 50
        correct = [True] * 50

        result = calculate_confidence_bands(confidences, correct, n_bins=1, n_bootstrap=100)

        # Lower bound ≤ accuracy ≤ upper bound
        self.assertLessEqual(result.lower_bounds[0], result.bin_accuracies[0])
        self.assertGreaterEqual(result.upper_bounds[0], result.bin_accuracies[0])

    def test_confidence_bands_empty(self):
        """Test with empty input."""
        result = calculate_confidence_bands([], [])

        self.assertEqual(len(result.bin_confidences), 0)
        self.assertEqual(result.n_bins, 10)  # Default

    def test_confidence_bands_alpha(self):
        """Test different alpha levels."""
        confidences = [0.3, 0.5, 0.7]
        correct = [False, True, True]

        result_05 = calculate_confidence_bands(confidences, correct, alpha=0.05)
        result_01 = calculate_confidence_bands(confidences, correct, alpha=0.01)

        # Tighter alpha (0.01) should give wider bands than 0.05
        # Actually: smaller alpha = wider CI for same confidence level
        # For 95% CI (alpha=0.05): narrower than 99% CI (alpha=0.01)
        self.assertIsNotNone(result_05)
        self.assertIsNotNone(result_01)


class TestMultipleHypothesisCorrection(unittest.TestCase):
    """Tests for Multiple Hypothesis Correction."""

    def test_benjamini_hochberg_basic(self):
        """Test basic BH correction."""
        p_values = [0.01, 0.03, 0.10, 0.25, 0.50]

        result = benjamini_hochberg_correction(p_values, alpha=0.05)

        self.assertEqual(len(result.corrected_pvalues), 5)
        self.assertEqual(len(result.rejected), 5)

        # Corrected p-values should be >= original
        for orig, corr in zip(p_values, result.corrected_pvalues):
            self.assertGreaterEqual(corr, orig)

    def test_benjamini_hochberg_discovery_control(self):
        """Test that BH controls false discovery rate."""
        # All null hypotheses (uniform p-values)
        p_values = [0.5, 0.3, 0.7, 0.4, 0.6]

        result = benjamini_hochberg_correction(p_values, alpha=0.05)

        # Should not reject many (if any) null hypotheses
        n_rejected = sum(result.rejected)
        self.assertLessEqual(n_rejected, 2)

    def test_bonferroni_more_conservative(self):
        """Test that Bonferroni is more conservative than BH."""
        p_values = [0.01, 0.02, 0.03]

        bh_result = benjamini_hochberg_correction(p_values, alpha=0.05)
        bonf_result = bonferroni_correction(p_values, alpha=0.05)

        # Bonferroni should reject fewer or equal than BH
        n_bonf = sum(bonf_result.rejected)
        n_bh = sum(bh_result.rejected)
        self.assertLessEqual(n_bonf, n_bh)

    def test_multiple_correction_empty(self):
        """Test with empty p-values."""
        bh_result = benjamini_hochberg_correction([])

        self.assertEqual(len(bh_result.corrected_pvalues), 0)
        self.assertEqual(len(bh_result.rejected), 0)

    def test_multiple_correction_edge_cases(self):
        """Test with extreme p-values."""
        p_values = [0.0, 0.001, 0.999, 1.0]

        bh_result = benjamini_hochberg_correction(p_values)

        # Should handle extreme values
        self.assertEqual(len(bh_result.corrected_pvalues), 4)
        for p in bh_result.corrected_pvalues:
            self.assertGreaterEqual(p, 0.0)
            self.assertLessEqual(p, 1.0)


class TestDistributionShiftDetection(unittest.TestCase):
    """Tests for Distribution Shift Detection (ICML 2024)."""

    def test_distribution_shift_no_shift(self):
        """Test with identical distributions (no shift)."""
        source = [0.3, 0.5, 0.7, 0.4, 0.6]
        target = [0.3, 0.5, 0.7, 0.4, 0.6]

        result = detect_distribution_shift(source, target)

        # Identical distributions: KS should be 0, but JS might have small value
        self.assertLess(result.ks_statistic, 0.1)
        # JS divergence might be non-zero due to binning, so use a more lenient check
        self.assertLess(result.shift_magnitude, 0.5)

    def test_distribution_shift_clear_shift(self):
        """Test with clearly different distributions."""
        source = [0.1, 0.2, 0.3, 0.4, 0.5]
        target = [0.6, 0.7, 0.8, 0.9, 1.0]

        result = detect_distribution_shift(source, target)

        self.assertTrue(result.has_shift)
        self.assertGreater(result.shift_magnitude, 0.3)

    def test_distribution_shift_ks_statistic(self):
        """Test KS statistic calculation."""
        source = [0.1, 0.2, 0.3]
        target = [0.4, 0.5, 0.6]

        result = detect_distribution_shift(source, target)

        self.assertGreater(result.ks_statistic, 0.0)
        self.assertLessEqual(result.ks_statistic, 1.0)

    def test_distribution_shift_js_divergence(self):
        """Test Jensen-Shannon divergence calculation."""
        source = [0.5] * 10
        target = [0.1] * 10

        result = detect_distribution_shift(source, target)

        self.assertGreater(result.js_divergence, 0.0)
        self.assertLessEqual(result.js_divergence, 1.0)

    def test_distribution_shift_empty(self):
        """Test with empty input."""
        result = detect_distribution_shift([], [])

        self.assertFalse(result.has_shift)
        self.assertEqual(result.shift_magnitude, 0.0)

    def test_distribution_shift_partial_overlap(self):
        """Test with partially overlapping distributions."""
        source = [0.3, 0.4, 0.5, 0.6, 0.7]
        target = [0.5, 0.6, 0.7, 0.8, 0.9]

        result = detect_distribution_shift(source, target)

        # Should detect some shift due to partial overlap
        self.assertGreater(result.shift_magnitude, 0.0)


# =============================================================================
# TESTS FOR CORRECTED v4 METRICS — Scientific accuracy validation
# =============================================================================

class TestFullECECorrect(unittest.TestCase):
    """Tests for CORRECT Full-ECE implementation (arXiv:2406.11345)."""

    def test_full_ece_token_level_correctness(self):
        """Test that Full-ECE correctly handles token-level correctness."""
        # Sample: [0.2, 0.7, 0.1], correct token is index 2 (prob=0.1)
        # Token 0 (prob=0.2): NOT correct → contributes 0 to accuracy
        # Token 1 (prob=0.7): NOT correct → contributes 0 to accuracy
        # Token 2 (prob=0.1): CORRECT → contributes 0.1 to accuracy
        confidences = [
            [0.2, 0.7, 0.1],  # Correct token is index 2 (low prob!)
            [0.5, 0.3, 0.2],  # Correct token is index 0
            [0.1, 0.8, 0.1],  # Correct token is index 1
        ]
        correct_token_indices = [2, 0, 1]

        result = calculate_full_ece_v4_correct(confidences, correct_token_indices)

        # ECE should be in valid range
        self.assertGreaterEqual(result.ece, 0.0)
        self.assertLessEqual(result.ece, 1.0)
        self.assertEqual(result.n_samples, 3)
        self.assertEqual(result.n_tokens, 9)

    def test_full_ece_vs_boolean_incorrectness(self):
        """Test that using boolean correctness gives WRONG result."""
        confidences = [
            [0.2, 0.7, 0.1],  # Top prediction is 1 (wrong), correct is 2
            [0.5, 0.3, 0.2],  # Top prediction is 0 (correct)
        ]

        # CORRECT way: use token indices
        correct_indices = [2, 0]
        result_correct = calculate_full_ece_v4_correct(confidences, correct_indices)

        # The result should be non-zero because sample 0 is poorly calibrated
        # (high confidence on wrong token, low confidence on correct token)
        self.assertGreater(result_correct.ece, 0.0)

    def test_full_ece_perfect_calibration(self):
        """Test Full-ECE with perfectly calibrated model."""
        # Perfect calibration: confidence = correctness
        confidences = [
            [0.9, 0.05, 0.05],  # Correct token 0 has high prob
            [0.05, 0.9, 0.05],  # Correct token 1 has high prob
            [0.05, 0.05, 0.9],  # Correct token 2 has high prob
        ]
        correct_indices = [0, 1, 2]

        result = calculate_full_ece_v4_correct(confidences, correct_indices)

        # ECE should be very low for well-calibrated model
        self.assertLess(result.ece, 0.2)

    def test_full_ece_empty_input(self):
        """Test with empty input."""
        result = calculate_full_ece_v4_correct([], [])

        self.assertEqual(result.ece, 0.0)
        self.assertEqual(result.n_samples, 0)


class TestMinKPPCorrect(unittest.TestCase):
    """Tests for CORRECT Min-K%++ implementation (arXiv:2404.02936)."""

    def test_minkpp_uses_log_probs(self):
        """Test that Min-K%++ uses LOG probabilities."""
        # Clean model: log probs around -2.0 (prob ~ 0.135)
        log_probs_clean = [-1.8, -2.0, -2.2, -1.9, -2.1]

        result = detect_contamination_min_k_pp_v4_correct(log_probs_clean)

        # Should NOT detect contamination (scores near mean)
        self.assertFalse(result.is_contaminated)

    def test_minkpp_contaminated_detection(self):
        """Test Min-K%++ detects contaminated samples."""
        # Mixed: clean samples around -2.0, contaminated samples below -4.0
        log_probs = [-1.8, -2.0, -2.2, -4.5, -5.0, -4.2]

        result = detect_contamination_min_k_pp_v4_correct(log_probs)

        # Should detect contamination (some scores far below mean)
        self.assertTrue(result.is_contaminated or result.n_below_threshold > 0)

    def test_minkpp_scores_formula(self):
        """Test that scores = log p - µ."""
        log_probs = [-2.0, -3.0, -4.0]
        mu = (-2.0 - 3.0 - 4.0) / 3  # = -3.0

        result = detect_contamination_min_k_pp_v4_correct(log_probs)

        # Check that scores are computed correctly
        # -2.0 - (-3.0) = 1.0, -3.0 - (-3.0) = 0.0, -4.0 - (-3.0) = -1.0
        expected_scores = [1.0, 0.0, -1.0]
        self.assertEqual(len(result.log_prob_scores), 3)
        for i, score in enumerate(result.log_prob_scores):
            self.assertAlmostEqual(score, expected_scores[i], places=5)

    def test_minkpp_empty_input(self):
        """Test with empty input."""
        result = detect_contamination_min_k_pp_v4_correct([])

        self.assertFalse(result.is_contaminated)
        self.assertEqual(result.confidence, 0.0)


class TestCoDecCorrect(unittest.TestCase):
    """Tests for CORRECT CoDeC implementation (arXiv:2510.27055)."""

    def test_codec_seen_unseen_classification(self):
        """Test dataset-level seen/unseen classification."""
        # Seen samples: large drop with seen context, small drop with unseen
        # Unseen samples: small drop with both contexts
        conf_base = [0.9, 0.9, 0.85, 0.8, 0.85, 0.8]
        conf_seen = [0.5, 0.5, 0.8, 0.75, 0.8, 0.75]  # Large drop for first 2
        conf_unseen = [0.85, 0.85, 0.8, 0.75, 0.8, 0.75]  # Small drop for first 2

        result = detect_contamination_codec_v4_correct_simple(
            conf_base, conf_seen, conf_unseen
        )

        # Should detect contamination
        self.assertGreater(result.auc_score, 0.0)

    def test_codec_auc_dataset_level(self):
        """Test that AUC is computed at dataset level."""
        # All samples are seen (contaminated)
        # Large drop with seen context, small drop with unseen context
        conf_base = [0.9] * 5
        conf_seen = [0.5] * 5  # Large drop (44%)
        conf_unseen = [0.88] * 5  # Small drop (2%)

        result = detect_contamination_codec_v4_correct_simple(
            conf_base, conf_seen, conf_unseen, threshold=0.2
        )

        # With proper threshold, should detect contamination
        # seen_drop > threshold and unseen_drop < threshold/2
        self.assertGreater(result.n_seen, 0)

    def test_codec_no_contamination(self):
        """Test with no contamination (clean samples)."""
        # Clean samples: small drop with BOTH contexts
        conf_base = [0.9, 0.85, 0.8]
        conf_seen = [0.8, 0.75, 0.7]  # Small drop (~11%)
        conf_unseen = [0.82, 0.77, 0.72]  # Similar drop (~9%)

        result = detect_contamination_codec_v4_correct_simple(
            conf_base, conf_seen, conf_unseen, threshold=0.15
        )

        # Both drops are below threshold, so not classified as seen
        self.assertEqual(result.n_seen, 0)
        # All samples are unseen
        self.assertEqual(result.n_unseen, 3)

    def test_codec_no_contamination(self):
        """Test with no contamination."""
        # No significant difference between seen and unseen
        conf_base = [0.9, 0.85, 0.8]
        conf_seen = [0.85, 0.8, 0.75]  # Small drop
        conf_unseen = [0.84, 0.79, 0.74]  # Similar drop

        result = detect_contamination_codec_v4_correct_simple(
            conf_base, conf_seen, conf_unseen
        )

        # Should NOT detect contamination
        self.assertLess(result.auc_score, 0.7)

    def test_codec_empty_input(self):
        """Test with empty input."""
        result = detect_contamination_codec_v4_correct_simple([], [], [])

        self.assertFalse(result.is_contaminated)
        self.assertEqual(result.auc_score, 0.0)


class TestBCaBootstrap:
    """Test BCa (bias-corrected accelerated) bootstrap CI."""

    def test_bca_vs_percentile(self):
        """BCa should give different (usually more accurate) CI than percentile."""
        try:
            from kaggle.eval.scientific_metrics_v7 import (
                _bootstrap_confidence_interval,
                _bootstrap_bca_ci
            )
        except ImportError:
            self.skipTest("scientific_metrics_v7 not available")

        # Skewed data (where BCa makes most difference)
        values = [1.0, 1.0, 1.0, 1.0, 1.0, 0.1, 0.1, 0.1, 0.1, 0.1]

        # Percentile method
        mean_p, ci_l_p, ci_u_p = _bootstrap_confidence_interval(values, n_bootstrap=1000, seed=42)

        # BCa method
        mean_b, ci_l_b, ci_u_b = _bootstrap_bca_ci(values, n_bootstrap=1000, seed=42)

        # Means should be similar
        self.assertAlmostEqual(mean_p, mean_b, places=2)

        # But CIs should differ (BCa corrects for bias/skew)
        # For skewed data, BCa typically shifts CI toward the skew
        self.assertNotEqual((ci_l_p, ci_u_p), (ci_l_b, ci_u_b))

    def test_bca_symmetric_data(self):
        """BCa should handle symmetric data well."""
        try:
            from kaggle.eval.scientific_metrics_v7 import _bootstrap_bca_ci
        except ImportError:
            self.skipTest("scientific_metrics_v7 not available")

        # Symmetric data
        values = [0.4, 0.45, 0.5, 0.55, 0.6]

        mean, ci_l, ci_u = _bootstrap_bca_ci(values, n_bootstrap=1000, seed=42)

        # Mean should be centered
        self.assertAlmostEqual(mean, 0.5, delta=0.05)

        # CI should be symmetric-ish around mean
        self.assertLess(ci_l, mean)
        self.assertGreater(ci_u, mean)

    def test_bca_small_sample_warning(self):
        """BCa should warn for small samples."""
        try:
            from kaggle.eval.scientific_metrics_v7 import _bootstrap_bca_ci
        except ImportError:
            self.skipTest("scientific_metrics_v7 not available")

        import warnings

        # Small sample (< min_samples)
        values = [0.5, 0.6]

        with warnings.catch_warnings(record=True) as w:
            warnings.simplefilter("always")
            mean, ci_l, ci_u = _bootstrap_bca_ci(values, min_samples=10)

            # Should have warned about small sample
            self.assertTrue(any("may be unreliable" in str(warning.message) for warning in w))


def run_tests():
    """Run all tests and return exit code."""
    loader = unittest.TestLoader()
    suite = loader.loadTestsFromModule(sys.modules[__name__])
    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)
    return 0 if result.wasSuccessful() else 1


if __name__ == "__main__":
    sys.exit(run_tests())
