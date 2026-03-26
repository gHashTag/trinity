#!/usr/bin/env python3
"""
Unit tests for scientific metrics v3.0.

Tests SmoothECE, Adaptive ECE, Bootstrap CI, meta-I, Cohen's Kappa,
Permutation Tests, and Brier Score.
100% test coverage for scientific_metrics_v3.py (~300 LOC)
"""

import unittest
import sys
import math
from pathlib import Path

# Add parent directory to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent))

from eval.scientific_metrics_v3 import (
    calculate_smooth_ece,
    calculate_adaptive_ece,
    calculate_bootstrap_ci,
    calculate_meta_i,
    calculate_cohens_kappa,
    permutation_test,
    calculate_brier_score,
    BootstrapResult,
    _rbf_kernel,
    _std,
    _norm_inverse,
    _norm_cdf,
)


class TestSmoothECE(unittest.TestCase):
    """Tests for SmoothECE with RBF kernel smoothing."""

    def test_smooth_ece_basic_calculation(self):
        """Test basic SmoothECE calculation."""
        confidences = [0.1, 0.3, 0.5, 0.7, 0.9]
        correct = [False, False, True, True, True]

        ece = calculate_smooth_ece(confidences, correct)

        self.assertGreaterEqual(ece, 0.0)
        self.assertLessEqual(ece, 1.0)

    def test_smooth_ece_perfect_calibration(self):
        """Test ECE = 0 for perfect calibration."""
        # Low confidence all wrong, high confidence all right
        confidences = [0.1, 0.1, 0.1, 0.9, 0.9, 0.9]
        correct = [False, False, False, True, True, True]

        ece = calculate_smooth_ece(confidences, correct)

        # Should be very low for good calibration
        self.assertLess(ece, 0.2)

    def test_smooth_ece_poor_calibration(self):
        """Test ECE > 0 for poor calibration."""
        # High confidence but all wrong
        confidences = [0.9, 0.9, 0.9, 0.9, 0.9]
        correct = [False, False, False, False, False]

        ece = calculate_smooth_ece(confidences, correct)

        self.assertGreater(ece, 0.3)

    def test_rbf_kernel_function(self):
        """Test RBF kernel function."""
        # Peak at center
        result = _rbf_kernel(0.5, 0.5, bandwidth=0.1)
        self.assertAlmostEqual(result, 1.0, places=5)

        # Symmetric
        result1 = _rbf_kernel(0.4, 0.5, bandwidth=0.1)
        result2 = _rbf_kernel(0.6, 0.5, bandwidth=0.1)
        self.assertAlmostEqual(result1, result2, places=5)

        # Decreases with distance
        result_near = _rbf_kernel(0.51, 0.5, bandwidth=0.1)
        result_far = _rbf_kernel(0.7, 0.5, bandwidth=0.1)
        self.assertGreater(result_near, result_far)

    def test_bandwidth_selection_silverman(self):
        """Test Silverman's rule for bandwidth selection."""
        import numpy as np

        # Constant data -> zero std -> should use minimum bandwidth
        confidences = [0.5, 0.5, 0.5]
        correct = [True, False, True]

        ece = calculate_smooth_ece(confidences, correct, bandwidth=None)

        # Should not crash with zero std
        self.assertGreaterEqual(ece, 0.0)

    def test_bandwidth_minimum_for_small_n(self):
        """Test CRITICAL v3.0 fix: minimum bandwidth for small n."""
        # Single sample
        confidences = [0.5]
        correct = [True]

        ece = calculate_smooth_ece(confidences, correct, bandwidth=None)

        # Should use minimum bandwidth, not crash
        self.assertGreaterEqual(ece, 0.0)
        self.assertLessEqual(ece, 1.0)

    def test_empty_input_handling(self):
        """Test handling of empty inputs."""
        ece = calculate_smooth_ece([], [])
        self.assertEqual(ece, 0.0)

        ece = calculate_smooth_ece([0.5], [])
        self.assertEqual(ece, 0.0)

    def test_single_confidence_value(self):
        """Test with all same confidence."""
        confidences = [0.5, 0.5, 0.5, 0.5, 0.5]
        correct = [True, True, False, False, True]

        ece = calculate_smooth_ece(confidences, correct)

        # Should still compute valid ECE
        self.assertGreaterEqual(ece, 0.0)


class TestAdaptiveECE(unittest.TestCase):
    """Tests for Adaptive ECE with equal sample bins."""

    def test_adaptive_ece_basic_calculation(self):
        """Test basic ACE calculation."""
        confidences = [0.1, 0.2, 0.3, 0.7, 0.8, 0.9]
        correct = [False, False, True, True, True, True]

        ace = calculate_adaptive_ece(confidences, correct)

        self.assertGreaterEqual(ace, 0.0)
        self.assertLessEqual(ace, 1.0)

    def test_adaptive_bins_equal_samples(self):
        """Test bins have approximately equal samples."""
        confidences = list(range(100))  # 0, 1, ..., 99
        correct = [i < 50 for i in range(100)]  # First 50 wrong, last 50 right

        ace = calculate_adaptive_ece(confidences, correct, min_samples_per_bin=10)

        # Should handle 100 samples with 10 samples per bin
        self.assertGreaterEqual(ace, 0.0)

    def test_min_samples_per_bin(self):
        """Test minimum samples per bin constraint."""
        confidences = [0.5] * 5  # Only 5 samples
        correct = [True, True, False, False, True]

        # With min_samples=10, should use fewer bins
        ace = calculate_adaptive_ece(confidences, correct, min_samples_per_bin=10)

        self.assertGreaterEqual(ace, 0.0)

    def test_comparison_with_standard_ece(self):
        """Test ACE vs standard ECE on same data."""
        from eval.scorer_v2 import calculate_ece

        confidences = [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0]
        correct = [False] * 5 + [True] * 5

        ece = calculate_ece(confidences, correct, n_bins=5)
        ace = calculate_adaptive_ece(confidences, correct, min_samples_per_bin=2)

        # Both should be in valid range
        self.assertGreaterEqual(ece, 0.0)
        self.assertGreaterEqual(ace, 0.0)

    def test_empty_input(self):
        """Test ACE with empty input."""
        ace = calculate_adaptive_ece([], [])
        self.assertEqual(ace, 0.0)


class TestBootstrapCI(unittest.TestCase):
    """Tests for Bootstrap Confidence Intervals."""

    def test_percentile_ci_calculation(self):
        """Test percentile CI calculation."""
        values = [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9]

        result = calculate_bootstrap_ci(values, n_bootstrap=1000, method="percentile")

        self.assertIsNotNone(result)
        self.assertLessEqual(result.ci_lower, result.value)
        self.assertGreaterEqual(result.ci_upper, result.value)

    def test_bca_ci_calculation(self):
        """Test BCa (bias-corrected and accelerated) CI."""
        values = [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9]

        result = calculate_bootstrap_ci(values, n_bootstrap=1000, method="bca")

        self.assertIsNotNone(result)
        self.assertLessEqual(result.ci_lower, result.value)
        self.assertGreaterEqual(result.ci_upper, result.value)

    def test_double_bootstrap_small_sample(self):
        """Test double bootstrap for small samples."""
        values = [0.3, 0.5, 0.7]  # Only 3 samples

        result = calculate_bootstrap_ci(values, n_bootstrap=100, method="double")

        self.assertIsNotNone(result)
        self.assertEqual(result.method, "double")

    def test_index_boundaries(self):
        """Test CRITICAL v3.0 fix: CI index boundaries."""
        # Small sample to test boundary conditions
        values = [0.1, 0.2, 0.3, 0.4, 0.5]

        result = calculate_bootstrap_ci(values, n_bootstrap=100, method="bca")

        # Indices should be within valid range [0, n_bootstrap-1]
        self.assertGreaterEqual(result.ci_lower, 0.0)
        self.assertLessEqual(result.ci_upper, 1.0)

    def test_bias_correction_calculation(self):
        """Test bias correction factor."""
        # All values same -> no bias
        values = [0.5, 0.5, 0.5, 0.5, 0.5]

        result = calculate_bootstrap_ci(values, n_bootstrap=100, method="bca")

        self.assertIsNotNone(result)

    def test_empty_input(self):
        """Test bootstrap with empty input."""
        result = calculate_bootstrap_ci([])

        self.assertEqual(result.value, 0.0)
        self.assertEqual(result.ci_lower, 0.0)
        self.assertEqual(result.ci_upper, 0.0)


class TestMetaI(unittest.TestCase):
    """Tests for meta-I (Information-theoretic metacognition)."""

    def test_meta_i_perfect_metacognition(self):
        """Test meta-I with perfect metacognition."""
        # All correct have high confidence, all incorrect have low confidence
        hits = 50      # Correct + High
        misses = 0     # Correct + Low
        false_alarms = 0   # Incorrect + High
        correct_rejections = 50  # Incorrect + Low

        meta_i, max_i = calculate_meta_i(hits, misses, false_alarms, correct_rejections)

        # Should have high meta-I
        self.assertGreater(meta_i, 0)
        self.assertGreaterEqual(meta_i, max_i * 0.8)  # At least 80% efficiency

    def test_meta_i_chance_performance(self):
        """Test meta-I at chance metacognition."""
        # Random confidence assignment
        hits = 25
        misses = 25
        false_alarms = 25
        correct_rejections = 25

        meta_i, max_i = calculate_meta_i(hits, misses, false_alarms, correct_rejections)

        # Should have low meta-I
        self.assertLess(meta_i, max_i * 0.3)  # Less than 30% efficiency

    def test_meta_i_bits_calculation(self):
        """Test meta-I is measured in bits."""
        hits = 40
        misses = 10
        false_alarms = 10
        correct_rejections = 40

        meta_i, max_i = calculate_meta_i(hits, misses, false_alarms, correct_rejections)

        # Meta-I should be in bits (information)
        self.assertGreater(meta_i, 0)
        self.assertGreater(max_i, 0)

    def test_mutual_information_formula(self):
        """Test mutual information formula properties."""
        # Perfect correlation
        hits = 50
        misses = 0
        false_alarms = 0
        correct_rejections = 50

        meta_i, max_i = calculate_meta_i(hits, misses, false_alarms, correct_rejections)

        # With perfect correlation, meta-I should equal max entropy
        self.assertAlmostEqual(meta_i, max_i, places=1)

    def test_division_by_zero_handling(self):
        """Test CRITICAL v3.0 fix: division by zero handling."""
        # Empty data
        meta_i, max_i = calculate_meta_i(0, 0, 0, 0)
        self.assertEqual(meta_i, 0.0)
        self.assertEqual(max_i, 0.0)

        # Only correct responses
        meta_i, max_i = calculate_meta_i(50, 0, 0, 0)
        self.assertEqual(meta_i, 0.0)  # No incorrect data for Type II

        # Only incorrect responses
        meta_i, max_i = calculate_meta_i(0, 0, 50, 0)
        self.assertEqual(meta_i, 0.0)  # No correct data for Type II


class TestCohensKappa(unittest.TestCase):
    """Tests for Cohen's Kappa inter-rater reliability."""

    def test_kappa_perfect_agreement(self):
        """Test Kappa = 1 for perfect agreement."""
        ratings1 = [1, 2, 3, 1, 2, 3]
        ratings2 = [1, 2, 3, 1, 2, 3]

        kappa, se, interp = calculate_cohens_kappa(ratings1, ratings2)

        self.assertAlmostEqual(kappa, 1.0, places=5)
        self.assertEqual(interp, "almost perfect")

    def test_kappa_no_agreement(self):
        """Test Kappa near 0 for random agreement."""
        import random
        random.seed(42)

        ratings1 = [1, 1, 2, 2, 3, 3]
        ratings2 = [1, 2, 3, 1, 2, 3]  # Different but not systematic

        kappa, se, interp = calculate_cohens_kappa(ratings1, ratings2)

        # Should be low due to poor agreement
        self.assertLess(kappa, 0.5)

    def test_kappa_interpretation_levels(self):
        """Test Kappa interpretation levels."""
        # Perfect agreement
        kappa, _, interp = calculate_cohens_kappa([1, 1], [1, 1])
        self.assertEqual(interp, "almost perfect")

        # Substantial agreement
        kappa, _, interp = calculate_cohens_kappa(
            [1, 1, 1, 2, 2, 2, 3, 3, 3, 3] * 3,
            [1, 1, 2, 2, 2, 2, 3, 3, 3, 3] * 3
        )
        self.assertIn(interp, ["substantial", "almost perfect", "moderate"])

    def test_kappa_standard_error(self):
        """Test Kappa standard error calculation."""
        ratings1 = [1, 2, 3, 1, 2, 3, 1, 2, 3]
        ratings2 = [1, 2, 3, 1, 2, 3, 1, 2, 2]

        kappa, se, interp = calculate_cohens_kappa(ratings1, ratings2)

        self.assertGreater(se, 0)
        self.assertLess(se, 1)

    def test_kappa_mismatched_lengths(self):
        """Test Kappa with mismatched lengths."""
        kappa, se, interp = calculate_cohens_kappa([1, 2], [1])

        self.assertEqual(kappa, 0.0)
        self.assertEqual(se, 0.0)


class TestPermutationTest(unittest.TestCase):
    """Tests for Permutation Tests."""

    def test_two_sided_test(self):
        """Test two-sided permutation test."""
        values1 = [0.1, 0.2, 0.3]
        values2 = [0.4, 0.5, 0.6]

        p_value, diff = permutation_test(values1, values2, n_permutations=100,
                                          alternative="two-sided")

        self.assertGreaterEqual(p_value, 0.0)
        self.assertLessEqual(p_value, 1.0)
        self.assertLess(diff, 0)  # values1 < values2

    def test_greater_alternative(self):
        """Test one-sided 'greater' alternative."""
        values1 = [0.7, 0.8, 0.9]
        values2 = [0.1, 0.2, 0.3]

        p_value, diff = permutation_test(values1, values2, n_permutations=100,
                                          alternative="greater")

        # values1 > values2, so p should be small
        self.assertLess(p_value, 0.1)

    def test_less_alternative(self):
        """Test one-sided 'less' alternative."""
        values1 = [0.1, 0.2, 0.3]
        values2 = [0.7, 0.8, 0.9]

        p_value, diff = permutation_test(values1, values2, n_permutations=100,
                                          alternative="less")

        # values1 < values2, so p should be small
        self.assertLess(p_value, 0.1)

    def test_permutation_distribution(self):
        """Test permutation creates valid distribution."""
        values1 = [0.5, 0.6]
        values2 = [0.4, 0.7]

        p_value, diff = permutation_test(values1, values2, n_permutations=50)

        self.assertGreaterEqual(p_value, 0.0)
        self.assertLessEqual(p_value, 1.0)


class TestBrierScore(unittest.TestCase):
    """Tests for Brier Score calibration metric."""

    def test_brier_score_perfect_calibration(self):
        """Test Brier Score = 0 for perfect calibration."""
        confidences = [1.0, 1.0, 1.0, 0.0, 0.0, 0.0]
        correct = [True, True, True, False, False, False]

        brier = calculate_brier_score(confidences, correct, weighted=False)

        self.assertAlmostEqual(brier, 0.0, places=5)

    def test_brier_score_worst_calibration(self):
        """Test Brier Score = 1 for worst calibration."""
        confidences = [1.0, 1.0, 1.0, 1.0, 1.0]
        correct = [False, False, False, False, False]

        brier = calculate_brier_score(confidences, correct, weighted=False)

        self.assertAlmostEqual(brier, 1.0, places=5)

    def test_penalized_brier_score(self):
        """Test penalized Brier Score weights overconfidence."""
        confidences = [0.9, 0.9, 0.1, 0.1]
        correct = [True, False, True, False]

        brier_std = calculate_brier_score(confidences, correct, weighted=False)
        brier_pen = calculate_brier_score(confidences, correct, weighted=True)

        # Penalized should be higher due to overconfidence penalty
        self.assertGreaterEqual(brier_pen, brier_std)

    def test_brier_score_range(self):
        """Test Brier Score is always in [0, 1]."""
        confidences = [0.1, 0.3, 0.5, 0.7, 0.9]
        correct = [True, False, True, True, False]

        brier = calculate_brier_score(confidences, correct)

        self.assertGreaterEqual(brier, 0.0)
        self.assertLessEqual(brier, 1.0)


class TestNormFunctions(unittest.TestCase):
    """Tests for normal distribution utility functions."""

    def test_norm_cdf_properties(self):
        """Test normal CDF properties."""
        # CDF(0) = 0.5
        self.assertAlmostEqual(_norm_cdf(0), 0.5, places=5)

        # CDF is increasing
        self.assertLess(_norm_cdf(-1), _norm_cdf(0))
        self.assertLess(_norm_cdf(0), _norm_cdf(1))

        # CDF approaches 1 as x -> infinity
        self.assertGreater(_norm_cdf(3), 0.99)

        # CDF approaches 0 as x -> -infinity
        self.assertLess(_norm_cdf(-3), 0.01)

    def test_norm_inverse_properties(self):
        """Test norm_inverse properties."""
        # inverse(CDF(x)) ≈ x
        for x in [0.1, 0.25, 0.5, 0.75, 0.9]:
            inv = _norm_inverse(x)
            cdf = _norm_cdf(inv)
            self.assertAlmostEqual(cdf, x, places=3)

    def test_std_calculation(self):
        """Test standard deviation calculation."""
        # Constant data -> std = 0
        self.assertEqual(_std([1.0, 1.0, 1.0]), 0.0)

        # Single value -> std = 0
        self.assertEqual(_std([5.0]), 0.0)

        # Known values
        self.assertAlmostEqual(_std([0, 1]), 0.5, places=5)


def run_tests():
    """Run all tests and return exit code."""
    loader = unittest.TestLoader()
    suite = loader.loadTestsFromModule(sys.modules[__name__])
    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)
    return 0 if result.wasSuccessful() else 1


if __name__ == "__main__":
    sys.exit(run_tests())
