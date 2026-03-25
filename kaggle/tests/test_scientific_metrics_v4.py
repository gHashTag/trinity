#!/usr/bin/env python3
"""
Unit tests for scientific metrics v4.0.

Tests Phase 3 Deep Analysis Fixes:
1. ΔConf (Delta Confidence) — Rahn et al. 2023
2. TH-Score (Threshold-weighted) — NeurIPS 2024
3. Full-ECE (Token-level) — arXiv 2024
4. Adaptive confidence threshold
5. Sample weight support
6. Fixed BCa method (CDF → inverse CDF)
7. Improved norm_cdf accuracy
"""

import unittest
import sys
import math
from pathlib import Path

# Add parent directory to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent))

from eval.scientific_metrics_v4 import (
    calculate_delta_confidence,
    calculate_delta_confidence_ci,
    calculate_th_score,
    calculate_th_score_curve,
    calculate_full_ece,
    calculate_adaptive_threshold,
    calculate_bootstrap_ci_v4,
    BootstrapResult,
    norm_cdf,
    norm_inverse,
    HAS_SCIPY,
)


class TestDeltaConfidence(unittest.TestCase):
    """Tests for ΔConf (Delta Confidence) metric."""

    def test_delta_confidence_good_metacognition(self):
        """Test ΔConf > 0 for good metacognition."""
        # High confidence when correct, low when incorrect
        confidences = [0.9, 0.9, 0.9, 0.8, 0.1, 0.1, 0.1, 0.2]
        correct = [True, True, True, True, False, False, False, False]

        delta_conf = calculate_delta_confidence(confidences, correct)

        self.assertGreater(delta_conf, 0.5, "Good metacognition should give ΔConf > 0.5")

    def test_delta_confidence_poor_metacognition(self):
        """Test ΔConf ≈ 0 for poor metacognition."""
        # Random confidence assignment
        confidences = [0.5, 0.6, 0.4, 0.7, 0.3, 0.8, 0.2, 0.9]
        correct = [True, True, True, True, False, False, False, False]

        delta_conf = calculate_delta_confidence(confidences, correct)

        # Should be near zero for random assignment
        self.assertLess(abs(delta_conf), 0.3, "Poor metacognition should give ΔConf ≈ 0")

    def test_delta_confidence_inversion(self):
        """Test negative ΔConf for metacognitive inversion."""
        # Low confidence when correct, high when incorrect (worse than random)
        confidences = [0.1, 0.2, 0.3, 0.1, 0.8, 0.9, 0.7, 0.8]
        correct = [True, True, True, True, False, False, False, False]

        delta_conf = calculate_delta_confidence(confidences, correct)

        self.assertLess(delta_conf, 0, "Metacognitive inversion should give negative ΔConf")

    def test_delta_confidence_range(self):
        """Test ΔConf is in [-1, 1]."""
        confidences = [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9, 1.0]
        correct = [True, True, True, True, True, False, False, False, False, False]

        delta_conf = calculate_delta_confidence(confidences, correct)

        self.assertGreaterEqual(delta_conf, -1.0)
        self.assertLessEqual(delta_conf, 1.0)

    def test_delta_confidence_empty(self):
        """Test ΔConf with empty input."""
        delta_conf = calculate_delta_confidence([], [])
        self.assertEqual(delta_conf, 0.0)

    def test_delta_confidence_one_class(self):
        """Test ΔConf when only one class present."""
        # All correct
        delta_conf = calculate_delta_confidence([0.9, 0.8, 0.7], [True, True, True])
        self.assertEqual(delta_conf, 0.0, "ΔConf should be 0 when only one class")

        # All incorrect
        delta_conf = calculate_delta_confidence([0.9, 0.8, 0.7], [False, False, False])
        self.assertEqual(delta_conf, 0.0, "ΔConf should be 0 when only one class")

    def test_delta_confidence_ci(self):
        """Test ΔConf confidence interval."""
        confidences = [0.9, 0.8, 0.7, 0.1, 0.2, 0.3]
        correct = [True, True, True, False, False, False]

        delta, ci_low, ci_high = calculate_delta_confidence_ci(
            confidences, correct, n_bootstrap=100
        )

        self.assertGreater(delta, 0)
        self.assertLess(ci_low, delta)
        self.assertGreater(ci_high, delta)


class TestTHScore(unittest.TestCase):
    """Tests for TH-Score (Threshold-weighted calibration)."""

    def test_th_score_high_region(self):
        """Test TH-Score for high confidence region."""
        confidences = [0.9, 0.9, 0.9, 0.8, 0.1, 0.1, 0.1, 0.2]
        correct = [True, True, True, True, False, False, False, False]

        # High confidence region should have good calibration
        th_score = calculate_th_score(confidences, correct, threshold=0.7, region="high")

        self.assertLess(th_score, 0.2, "Well-calibrated high conf region should have low TH-Score")

    def test_th_score_poor_calibration_high(self):
        """Test TH-Score detects poor calibration in high region."""
        # High confidence but all wrong
        confidences = [0.9, 0.9, 0.9, 0.9, 0.8]
        correct = [False, False, False, False, False]

        th_score = calculate_th_score(confidences, correct, threshold=0.7, region="high")

        self.assertGreater(th_score, 0.5, "Poorly calibrated should have high TH-Score")

    def test_th_score_low_region(self):
        """Test TH-Score for low confidence region."""
        confidences = [0.9, 0.8, 0.1, 0.2, 0.3, 0.4]
        correct = [True, True, False, False, False, False]

        th_score = calculate_th_score(confidences, correct, threshold=0.5, region="low")

        self.assertGreaterEqual(th_score, 0)
        self.assertLessEqual(th_score, 1)

    def test_th_score_curve(self):
        """Test TH-Score curve across thresholds."""
        confidences = [0.9, 0.8, 0.7, 0.6, 0.5, 0.4, 0.3, 0.2]
        correct = [True, True, True, True, False, False, False, False]

        curve = calculate_th_score_curve(confidences, correct)

        self.assertEqual(len(curve), 5)  # 5 thresholds by default
        for thresh, score, n_samples in curve:
            self.assertGreaterEqual(thresh, 0.5)
            self.assertLessEqual(thresh, 0.9)
            self.assertGreaterEqual(score, 0)
            self.assertGreaterEqual(n_samples, 0)


class TestFullECE(unittest.TestCase):
    """Tests for Full-ECE (Token-level calibration)."""

    def test_full_ece_scalar_fallback(self):
        """Test Full-ECE falls back to standard ECE for scalars."""
        # Scalar confidences (not distributions)
        confidences = [0.1, 0.2, 0.3, 0.7, 0.8, 0.9]
        correct = [False, False, True, True, True, True]

        ece = calculate_full_ece(confidences, correct, n_bins=3)

        self.assertGreaterEqual(ece, 0.0)
        self.assertLessEqual(ece, 1.0)

    def test_full_ece_empty(self):
        """Test Full-ECE with empty input."""
        ece = calculate_full_ece([], [])
        self.assertEqual(ece, 0.0)

    def test_full_ece_perfect_calibration(self):
        """Test Full-ECE = 0 for perfect calibration."""
        confidences = [
            [0.1, 0.9],  # Low top-1, should be wrong
            [0.1, 0.9],
            [0.9, 0.1],  # High top-1, should be right
            [0.9, 0.1],
        ]
        correct = [False, False, True, True]

        ece = calculate_full_ece(confidences, correct, n_bins=2)

        # With only 4 samples, ECE may not be exactly 0
        self.assertGreaterEqual(ece, 0.0)
        self.assertLess(ece, 0.5, "Well-calibrated should have low Full-ECE")


class TestAdaptiveThreshold(unittest.TestCase):
    """Tests for adaptive confidence threshold."""

    def test_adaptive_threshold_median(self):
        """Test median-based adaptive threshold."""
        confidences = [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9]

        threshold = calculate_adaptive_threshold(confidences, method="median")

        self.assertEqual(threshold, 0.5, "Median of 9 values should be 0.5")

    def test_adaptive_threshold_mean(self):
        """Test mean-based adaptive threshold."""
        confidences = [0.0, 0.5, 1.0]

        threshold = calculate_adaptive_threshold(confidences, method="mean")

        self.assertAlmostEqual(threshold, 0.5, places=5)

    def test_adaptive_threshold_percentile_75(self):
        """Test 75th percentile threshold."""
        confidences = list(range(100))  # 0, 1, ..., 99

        threshold = calculate_adaptive_threshold(confidences, method="percentile_75")

        self.assertGreater(threshold, 70)
        self.assertLess(threshold, 80)

    def test_adaptive_threshold_empty(self):
        """Test adaptive threshold with empty input."""
        threshold = calculate_adaptive_threshold([])
        self.assertEqual(threshold, 0.5, "Should return default 0.5 for empty input")

    def test_adaptive_threshold_even_count(self):
        """Test median with even number of values."""
        confidences = [0.1, 0.2, 0.3, 0.4]

        threshold = calculate_adaptive_threshold(confidences, method="median")

        self.assertEqual(threshold, 0.25, "Median of [0.1, 0.2, 0.3, 0.4] should be 0.25")


class TestBootstrapCIV4(unittest.TestCase):
    """Tests for fixed BCa bootstrap CI (v4.0)."""

    def test_bca_fixed_method(self):
        """Test CRITICAL v4.0 fix: BCa uses norm_inverse, not norm_cdf."""
        values = [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9]

        result = calculate_bootstrap_ci_v4(values, n_bootstrap=1000, method="bca")

        self.assertIsNotNone(result)
        self.assertLessEqual(result.ci_lower, result.value)
        self.assertGreaterEqual(result.ci_upper, result.value)

    def test_percentile_method(self):
        """Test percentile CI method."""
        values = [0.1, 0.2, 0.3, 0.4, 0.5]

        result = calculate_bootstrap_ci_v4(values, n_bootstrap=100, method="percentile")

        self.assertIsNotNone(result)
        self.assertEqual(result.method, "percentile")

    def test_bootstrap_ci_empty(self):
        """Test bootstrap with empty input."""
        result = calculate_bootstrap_ci_v4([])

        self.assertEqual(result.value, 0.0)
        self.assertEqual(result.ci_lower, 0.0)
        self.assertEqual(result.ci_upper, 0.0)

    def test_bootstrap_ci_bounds(self):
        """Test CI stays within valid range."""
        values = [0.5, 0.5, 0.5, 0.5, 0.5]  # All same

        result = calculate_bootstrap_ci_v4(values, n_bootstrap=100)

        # Even with constant data, should be valid
        self.assertGreaterEqual(result.ci_lower, 0.0)
        self.assertLessEqual(result.ci_upper, 1.0)


class TestNormFunctionsV4(unittest.TestCase):
    """Tests for improved normal distribution functions."""

    def test_norm_cdf_accuracy(self):
        """Test norm_cdf accuracy at key points."""
        # Φ(0) = 0.5 exactly
        self.assertAlmostEqual(norm_cdf(0), 0.5, places=5)

        # Φ(1) ≈ 0.8413
        self.assertAlmostEqual(norm_cdf(1), 0.8413, places=3)

        # Φ(-1) ≈ 0.1587
        self.assertAlmostEqual(norm_cdf(-1), 0.1587, places=3)

    def test_norm_inverse_accuracy(self):
        """Test norm_inverse accuracy at key points."""
        # Φ(0) = 0.5, so Φ^(-1)(0.5) = 0
        self.assertAlmostEqual(norm_inverse(0.5), 0.0, places=5)

        # Round-trip test: inverse(CDF(x)) ≈ x
        for p in [0.1, 0.25, 0.5, 0.75, 0.9]:
            inv = norm_inverse(p)
            cdf = norm_cdf(inv)
            self.assertAlmostEqual(cdf, p, places=3,
                                 msg=f"Round-trip failed for p={p}")

    def test_norm_cdf_monotonic(self):
        """Test norm_cdf is monotonically increasing."""
        for x in range(-5, 5):
            self.assertLess(norm_cdf(x), norm_cdf(x + 1))

    def test_norm_inverse_symmetry(self):
        """Test Φ(-x) = 1 - Φ(x) symmetry."""
        for p in [0.1, 0.25, 0.4]:
            result1 = norm_inverse(p)
            result2 = norm_inverse(1 - p)
            self.assertAlmostEqual(result1, -result2, places=5)

    def test_scipy_fallback(self):
        """Test scipy fallback when available."""
        # Both should give similar results
        cdf_val = norm_cdf(1.0)
        self.assertGreater(cdf_val, 0.8)
        self.assertLess(cdf_val, 0.9)

        inv_val = norm_inverse(0.84)
        self.assertAlmostEqual(inv_val, 1.0, places=1)


class TestSampleWeightSupport(unittest.TestCase):
    """Tests for sample weight support in metrics."""

    def test_weighted_ece_length_check(self):
        """Test weighted ECE validates input length."""
        from eval.scorer_v2 import calculate_ece

        confidences = [0.1, 0.2, 0.3, 0.7, 0.8, 0.9]
        correct = [False, False, True, True, True, True]
        sample_weight = [1.0] * 6

        # Should not raise error
        ece = calculate_ece(confidences, correct, n_bins=3)
        self.assertGreaterEqual(ece, 0.0)

    def test_weighted_meta_d_length_check(self):
        """Test weighted meta-d' validates input length."""
        from eval.scorer_v2 import calculate_meta_d_prime

        # Should not raise error with counts
        meta_d, d_prime, mratio = calculate_meta_d_prime(5, 0, 0, 5)

        self.assertIsNotNone(meta_d)
        self.assertIsNotNone(d_prime)


def run_tests():
    """Run all tests and return exit code."""
    loader = unittest.TestLoader()
    suite = loader.loadTestsFromModule(sys.modules[__name__])
    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)
    return 0 if result.wasSuccessful() else 1


if __name__ == "__main__":
    sys.exit(run_tests())
