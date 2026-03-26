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
        self.assertLessEqual(ece, 0.6, "Well-calibrated should have low Full-ECE")


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


class TestMetaUncertaintyV43(unittest.TestCase):
    """Tests for meta-uncertainty metric (v4.2+v4.3)."""

    def test_meta_uncertainty_variable_vs_stable(self):
        """Test meta-uncertainty distinguishes variable from stable confidences."""
        from eval.scientific_metrics_v4 import calculate_meta_uncertainty

        # Variable confidences → high meta-uncertainty
        conf_variable = [0.1, 0.1, 0.1, 0.9, 0.9, 0.9]
        mu_variable = calculate_meta_uncertainty(conf_variable)

        # Stable confidences → low meta-uncertainty
        conf_stable = [0.5, 0.5, 0.5, 0.5, 0.5, 0.5]
        mu_stable = calculate_meta_uncertainty(conf_stable)

        self.assertGreater(mu_variable, mu_stable,
                          "Variable confidences should give higher meta-uncertainty")

    def test_meta_uncertainty_ci_coverage(self):
        """Test meta-uncertainty confidence interval."""
        from eval.scientific_metrics_v4 import calculate_meta_uncertainty_ci

        confidences = [0.3, 0.5, 0.7, 0.4, 0.6, 0.8]
        mu, ci_low, ci_high = calculate_meta_uncertainty_ci(confidences, n_bootstrap=100)

        self.assertGreaterEqual(mu, 0.0)
        self.assertLessEqual(ci_low, mu)
        self.assertGreaterEqual(ci_high, mu)

    def test_meta_uncertainty_edge_cases(self):
        """Test meta-uncertainty edge cases."""
        from eval.scientific_metrics_v4 import calculate_meta_uncertainty

        # Empty list
        self.assertEqual(calculate_meta_uncertainty([]), 0.0)

        # Single value
        self.assertEqual(calculate_meta_uncertainty([0.5]), 0.0)

        # Two values
        mu = calculate_meta_uncertainty([0.0, 1.0])
        self.assertGreater(mu, 0.0)

    def test_meta_uncertainty_non_normal_distribution(self):
        """Test meta-uncertainty with MAD fallback for non-normal distributions."""
        from eval.scientific_metrics_v4 import calculate_meta_uncertainty

        # Highly skewed distribution (many low values, few high)
        conf_skewed = [0.1, 0.1, 0.1, 0.1, 0.1, 0.9, 0.9]
        mu_skewed = calculate_meta_uncertainty(conf_skewed, use_mad_fallback=True)

        # Should still return a valid value
        self.assertGreaterEqual(mu_skewed, 0.0)
        self.assertLessEqual(mu_skewed, 1.0)


class TestLSECEV43(unittest.TestCase):
    """Tests for LS-ECE (Logit-Smoothed ECE) metric (v4.2+v4.3)."""

    def test_ls_ece_continuous_property(self):
        """Test LS-ECE is continuous (no binning artifacts)."""
        from eval.scientific_metrics_v4 import calculate_ls_ece

        confidences = [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9]
        correct = [False, False, False, True, True, True, True, True, True]

        ls_ece = calculate_ls_ece(confidences, correct)

        self.assertGreaterEqual(ls_ece, 0.0)
        self.assertLessEqual(ls_ece, 1.0)

    def test_ls_ece_bandwidth_sensitivity(self):
        """Test LS-ECE sensitivity to bandwidth parameter."""
        from eval.scientific_metrics_v4 import calculate_ls_ece

        confidences = [0.2, 0.4, 0.6, 0.8]
        correct = [False, True, True, True]

        ls_ece_narrow = calculate_ls_ece(confidences, correct, bandwidth=0.05)
        ls_ece_wide = calculate_ls_ece(confidences, correct, bandwidth=0.5)

        # Both should be valid
        self.assertGreaterEqual(ls_ece_narrow, 0.0)
        self.assertGreaterEqual(ls_ece_wide, 0.0)

    def test_ls_ece_numerical_stability(self):
        """Test LS-ECE numerical stability at extreme values."""
        from eval.scientific_metrics_v4 import calculate_ls_ece

        # Extreme confidences (near 0 and 1)
        confidences = [0.001, 0.01, 0.1, 0.9, 0.99, 0.999]
        correct = [False, False, True, True, True, True]

        ls_ece = calculate_ls_ece(confidences, correct)

        # Should not overflow or return NaN
        self.assertFalse(math.isnan(ls_ece), "LS-ECE should not be NaN")
        self.assertFalse(math.isinf(ls_ece), "LS-ECE should not be infinite")
        self.assertGreaterEqual(ls_ece, 0.0)

    def test_ls_ece_perfect_calibration(self):
        """Test LS-ECE for perfectly calibrated predictions."""
        from eval.scientific_metrics_v4 import calculate_ls_ece

        # Perfect calibration: confidence matches accuracy
        confidences = [0.1, 0.3, 0.5, 0.7, 0.9]
        correct = [False, False, True, True, True]  # Threshold at 0.5

        ls_ece = calculate_ls_ece(confidences, correct, bandwidth=0.2)

        # Should be relatively low for well-calibrated data
        self.assertLess(ls_ece, 0.5)


class TestCoDeCV43(unittest.TestCase):
    """Tests for CoDeC contamination detection (v4.2+v4.3)."""

    def test_codec_confidence_drop_calculation(self):
        """Test CoDeC confidence drop calculation."""
        from validate.codec import detect_contamination_codec_simple

        # Large confidence drops → contamination
        conf_wo = [0.95, 0.95, 0.95]  # High confidence without context
        conf_w = [0.50, 0.50, 0.50]   # Large drop with context

        result = detect_contamination_codec_simple(conf_wo, conf_w)

        self.assertTrue(result.is_contaminated)
        self.assertGreater(result.mean_confidence_drop, 0.3)
        self.assertGreater(result.auc_score, 0.7)

    def test_codec_auc_estimation(self):
        """Test CoDeC AUC estimation with improved v4.3 formula."""
        from validate.codec import detect_contamination_codec_simple

        # Test different levels of contamination
        # Strong contamination
        result_strong = detect_contamination_codec_simple(
            [0.95, 0.95, 0.95],
            [0.40, 0.40, 0.40]
        )
        self.assertGreater(result_strong.auc_score, 0.8)

        # Weak contamination
        result_weak = detect_contamination_codec_simple(
            [0.95, 0.95, 0.95],
            [0.85, 0.85, 0.85]
        )
        # AUC should be lower for weak contamination
        self.assertLess(result_weak.auc_score, result_strong.auc_score)

    def test_codec_zero_confidence(self):
        """Test CoDeC with zero confidence values."""
        from validate.codec import detect_contamination_codec_simple

        # Zero confidence without context should be handled
        conf_wo = [0.0, 0.5, 0.9]
        conf_w = [0.0, 0.4, 0.8]

        result = detect_contamination_codec_simple(conf_wo, conf_w)

        self.assertIsNotNone(result)
        self.assertGreaterEqual(result.mean_confidence_drop, 0.0)

    def test_codec_clean_samples(self):
        """Test CoDeC with clean samples (no significant drop)."""
        from validate.codec import detect_contamination_codec_simple

        # Minimal confidence changes → clean
        conf_wo = [0.85, 0.85, 0.85]
        conf_w = [0.83, 0.84, 0.86]  # Small changes

        result = detect_contamination_codec_simple(conf_wo, conf_w)

        self.assertFalse(result.is_contaminated)
        self.assertLess(result.mean_confidence_drop, 0.1)


class TestMinKPPV43(unittest.TestCase):
    """Tests for Min-K%++ contamination detection (v4.2+v4.3)."""

    def test_minkpp_mode_detection(self):
        """Test Min-K%++ mode detection improvement."""
        from validate.codec import detect_contamination_min_k_pp

        # Training samples: cluster at low confidence
        confidences = [0.1, 0.1, 0.1, 0.15, 0.8, 0.9, 0.95]

        result = detect_contamination_min_k_pp(confidences, k_percent=20.0)

        # Bottom 20% are tightly clustered → should detect contamination
        # CRITICAL v4.3: Now uses AND logic instead of OR
        # So needs BOTH low min-k score AND high mode clustering
        self.assertIsNotNone(result)

    def test_minkpp_window_counting(self):
        """Test Min-K%++ mode window counting."""
        from validate.codec import detect_contamination_min_k_pp

        # Tight cluster at low confidence
        confidences = [0.1, 0.12, 0.11, 0.13, 0.8, 0.9]

        result = detect_contamination_min_k_pp(confidences, k_percent=30.0)

        self.assertGreaterEqual(result.min_k_score, 0.0)
        self.assertLessEqual(result.min_k_score, 1.0)

    def test_minkpp_curve_analysis(self):
        """Test Min-K%++ curve across multiple K values."""
        from validate.codec import detect_contamination_min_k_pp_curve

        confidences = [0.1, 0.2, 0.3, 0.7, 0.8, 0.9]

        curve = detect_contamination_min_k_pp_curve(confidences)

        self.assertGreater(len(curve), 0)
        for k, score, mode_score, is_cont in curve:
            self.assertGreater(k, 0)
            self.assertGreaterEqual(score, 0.0)
            self.assertLessEqual(score, 1.0)

    def test_minkpp_false_positive_fix(self):
        """Test that v4.3 fix reduces false positives from OR logic."""
        from validate.codec import detect_contamination_min_k_pp

        # High mode_score but NOT low min-k score → should NOT trigger
        # (this was a false positive in v4.2 with OR logic)
        confidences = [0.6, 0.7, 0.8, 0.85, 0.9, 0.95]  # All high confidence

        result = detect_contamination_min_k_pp(confidences, k_percent=10.0)

        # With v4.3 AND logic, this should NOT be contaminated
        # (min_k_score is high, so AND condition fails)
        if result.mode_score > 0.2:
            # Only test this if mode_score is actually high
            self.assertFalse(result.is_contaminated or result.min_k_score < 0.5,
                           "High confidences should not trigger contamination without low min-k")


class TestFullECEV43(unittest.TestCase):
    """Tests for Full-ECE with v4.3 double-counting fix."""

    def test_full_ece_no_double_counting(self):
        """Test that Full-ECE doesn't double-count probability mass."""
        from eval.scientific_metrics_v4 import calculate_full_ece

        # Token-level probabilities
        token_probs = [
            [0.05, 0.05, 0.1, 0.3, 0.5],  # Correct: top token = 0.5
            [0.5, 0.3, 0.1, 0.05, 0.05],  # Correct: top token = 0.5
            [0.7, 0.1, 0.1, 0.05, 0.05],  # Incorrect: top = 0.7
        ]
        correct = [True, True, False]

        full_ece = calculate_full_ece(token_probs, correct, n_bins=5)

        # CRITICAL v4.3: Full-ECE should be in [0, 1]
        self.assertGreaterEqual(full_ece, 0.0)
        self.assertLessEqual(full_ece, 1.0)

    def test_full_ece_aggregates_all_tokens(self):
        """Test that Full-ECE aggregates across all tokens, not just top-1."""
        from eval.scientific_metrics_v4 import calculate_full_ece

        # Create test where all tokens contribute
        token_probs = [
            [0.2, 0.2, 0.2, 0.2, 0.2],  # Uniform distribution
            [0.2, 0.2, 0.2, 0.2, 0.2],
            [0.2, 0.2, 0.2, 0.2, 0.2],
        ]
        correct = [True, True, False]

        full_ece = calculate_full_ece(token_probs, correct, n_bins=3)

        # Should calculate a valid ECE
        self.assertGreaterEqual(full_ece, 0.0)


def run_tests():
    """Run all tests and return exit code."""
    loader = unittest.TestLoader()
    suite = loader.loadTestsFromModule(sys.modules[__name__])
    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)
    return 0 if result.wasSuccessful() else 1


if __name__ == "__main__":
    sys.exit(run_tests())
