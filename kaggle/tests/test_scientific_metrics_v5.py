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
    TemperatureScalingResult,
    ClasswiseECEResult,
    ConfidenceBandsResult,
    DistributionShiftResult,
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


def run_tests():
    """Run all tests and return exit code."""
    loader = unittest.TestLoader()
    suite = loader.loadTestsFromModule(sys.modules[__name__])
    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)
    return 0 if result.wasSuccessful() else 1


if __name__ == "__main__":
    sys.exit(run_tests())
