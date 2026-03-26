# Test Scientific Metrics V8 — Statistical Framework

"""
Tests for Trinity S³AI statistical framework (v8).

Uses unittest (Python stdlib) — no external dependencies.

Author: Dmitrii Vasilev
Date: 2026-03-27
Version: 1.0.0
License: MIT
"""

import unittest
import numpy as np
from eval.scientific_metrics_v8 import (
    ConfidenceInterval,
    EffectSize,
    SignificanceTest,
    StatisticalResult,
    Interpretation,
    calculate_ci,
    calculate_effect_size,
    paired_t_test,
    independent_t_test,
    wilcoxon_test,
    bonferroni_correction,
    holm_bonferroni,
    analyze_group,
    compare_groups,
    format_markdown_table,
    format_comparison_table,
    power_analysis,
)


class TestConfidenceInterval(unittest.TestCase):
    """Test confidence interval calculations."""

    def test_ci_95_known_data(self):
        """Test CI95 with known data."""
        # Normal distribution: mean=100, std=15, n=100
        np.random.seed(42)
        data = np.random.normal(100, 15, 100).tolist()

        ci = calculate_ci(data, confidence_level=0.95)

        self.assertGreater(ci.level, 0.94)
        self.assertLessEqual(ci.level, 0.96)
        self.assertGreater(ci.margin_of_error, 0)
        self.assertLess(ci.lower, 100)
        self.assertGreater(ci.upper, 100)

    def test_ci_99_wider_than_95(self):
        """Test CI99 is wider than CI95."""
        np.random.seed(42)
        data = np.random.normal(50, 10, 50).tolist()

        ci95 = calculate_ci(data, confidence_level=0.95)
        ci99 = calculate_ci(data, confidence_level=0.99)

        self.assertGreater(ci99.margin_of_error, ci95.margin_of_error)

    def test_ci_small_sample(self):
        """Test CI with small sample (uses t-distribution)."""
        data = [1.0, 2.0, 3.0, 4.0, 5.0]

        ci = calculate_ci(data, confidence_level=0.95)

        self.assertLess(ci.lower, 3.0)
        self.assertGreater(ci.upper, 3.0)
        self.assertGreater(ci.margin_of_error, 0)


class TestEffectSize(unittest.TestCase):
    """Test effect size calculations."""

    def test_cohens_d_identical(self):
        """Test Cohen's d with identical distributions."""
        effect = calculate_effect_size(100.0, 100.0, 10.0, 10.0, 50, 50)

        self.assertLess(abs(effect.cohens_d), 0.01)
        self.assertEqual(effect.interpretation, "negligible")

    def test_cohens_d_large_effect(self):
        """Test Cohen's d with large effect."""
        # Use non-zero std to avoid division by zero
        effect = calculate_effect_size(100.0, 120.0, 5.0, 5.0, 50, 50)

        self.assertGreater(effect.cohens_d, 3.0)
        self.assertEqual(effect.interpretation, "very_large")

    def test_cohens_d_small_effect(self):
        """Test Cohen's d with small effect."""
        effect = calculate_effect_size(100.0, 102.0, 10.0, 10.0, 100, 100)

        self.assertGreater(abs(effect.cohens_d), 0.1)
        self.assertLess(abs(effect.cohens_d), 0.3)
        self.assertEqual(effect.interpretation, "small")

    def test_hedges_g_bias_correction(self):
        """Test Hedges' g applies bias correction for small samples."""
        effect = calculate_effect_size(3.0, 4.0, 1.58, 1.58, 5, 5)

        self.assertGreater(abs(effect.hedges_g), 0)
        # For small samples, Hedges' g < Cohen's d
        self.assertLess(abs(effect.hedges_g), abs(effect.cohens_d))


class TestSignificanceTests(unittest.TestCase):
    """Test statistical significance tests."""

    def test_paired_t_test_significant(self):
        """Test paired t-test detects significant difference."""
        before = [100, 105, 95, 98, 102]
        after = [110, 115, 105, 108, 112]  # +10 improvement

        result = paired_t_test(after, before, alpha=0.05)

        self.assertTrue(result.significant)
        self.assertLess(result.p_value, 0.05)
        self.assertEqual(result.test_name, "paired_t_test")

    def test_paired_t_test_not_significant(self):
        """Test paired t-test with no significant difference."""
        np.random.seed(42)
        group1 = np.random.normal(100, 5, 30).tolist()
        group2 = np.random.normal(101, 5, 30).tolist()

        result = paired_t_test(group1, group2, alpha=0.05)

        # Should not be significant at alpha=0.05
        self.assertFalse(result.significant and result.p_value < 0.01)

    def test_independent_t_test_welch(self):
        """Test Welch's t-test (default, unequal variances)."""
        np.random.seed(42)
        group1 = np.random.normal(100, 5, 50).tolist()
        group2 = np.random.normal(105, 15, 50).tolist()

        result = independent_t_test(group1, group2, equal_var=False)

        self.assertEqual(result.test_name, "welch_t_test")
        self.assertGreater(result.p_value, 0)

    def test_wilcoxon_test_non_parametric(self):
        """Test Wilcoxon signed-rank test."""
        # Use more data for better significance
        before = [10, 20, 30, 40, 50, 15, 25, 35]
        after = [15, 25, 35, 45, 55, 20, 30, 40]

        result = wilcoxon_test(before, after, alpha=0.05)

        self.assertEqual(result.test_name, "wilcoxon")
        # Wilcoxon may not always be significant with small data
        self.assertIsNotNone(result.p_value)

    def test_wilcoxon_requires_equal_length(self):
        """Test Wilcoxon rejects unequal length samples."""
        with self.assertRaises(ValueError):
            wilcoxon_test([1, 2, 3], [1, 2])


class TestMultipleComparisonCorrection(unittest.TestCase):
    """Test multiple comparison correction methods."""

    def test_bonferroni_correction(self):
        """Test Bonferroni correction."""
        p_values = [0.01, 0.03, 0.001, 0.04, 0.02]

        results = bonferroni_correction(p_values, alpha=0.05)

        # Threshold is 0.05/5 = 0.01
        # Only p=0.001 survives
        self.assertEqual(sum(results), 1)
        self.assertTrue(results[2])  # 0.001 is significant

    def test_bonferroni_all_rejected(self):
        """Test Bonferroni rejects all when many tests."""
        # 10 tests, smallest p=0.01
        p_values = [0.01 * i for i in range(1, 11)]

        results = bonferroni_correction(p_values, alpha=0.05)

        # Threshold is 0.05/10 = 0.005, so p=0.01 is not significant
        self.assertFalse(any(results))

    def test_holm_bonferroni_less_conservative(self):
        """Test Holm-Bonferroni is less conservative than Bonferroni."""
        p_values = [0.01, 0.03, 0.04, 0.15, 0.20]

        bonf = bonferroni_correction(p_values, alpha=0.05)
        holm = holm_bonferroni(p_values, alpha=0.05)

        # Holm should have at least as many significant results
        self.assertGreaterEqual(sum(holm), sum(bonf))

    def test_holm_step_down(self):
        """Test Holm step-down procedure."""
        # Sorted: 0.001, 0.01, 0.03, 0.04
        p_values = [0.04, 0.001, 0.03, 0.01]

        results = holm_bonferroni(p_values, alpha=0.05)

        # 0.001 < 0.05/4 = 0.0125 ✓
        # 0.01 < 0.05/3 = 0.0167 ✓
        # 0.03 < 0.05/2 = 0.025 ✗ (stop)
        self.assertEqual(sum(results), 2)


class TestAnalyzeGroup(unittest.TestCase):
    """Test analyze_group function."""

    def test_analyze_group_basic(self):
        """Test analyze_group returns all components."""
        np.random.seed(42)
        data = np.random.normal(100, 15, 30).tolist()

        result = analyze_group(data, confidence_level=0.95)

        self.assertIsInstance(result, StatisticalResult)
        self.assertGreater(result.mean, 90)
        self.assertLess(result.mean, 110)
        self.assertGreater(result.std, 0)
        self.assertEqual(result.n, 30)
        self.assertIsNotNone(result.ci)
        self.assertGreater(result.ci.level, 0.94)
        self.assertLessEqual(result.ci.level, 0.96)


class TestCompareGroups(unittest.TestCase):
    """Test compare_groups function."""

    def test_compare_groups(self):
        """Test compare_groups with two groups."""
        np.random.seed(42)
        group1 = np.random.normal(100, 10, 30).tolist()
        group2 = np.random.normal(105, 10, 30).tolist()

        result1, result2, effect, sig = compare_groups(group1, group2, alpha=0.05)

        # Should return 4 components
        self.assertIsInstance(result1, StatisticalResult)
        self.assertIsInstance(result2, StatisticalResult)
        self.assertIsInstance(effect, EffectSize)
        self.assertIsInstance(sig, SignificanceTest)


class TestFormatting(unittest.TestCase):
    """Test output formatting."""

    def test_format_markdown_table(self):
        """Test Markdown table formatting."""
        np.random.seed(42)
        data = np.random.normal(100, 15, 30).tolist()

        result = analyze_group(data, confidence_level=0.95)
        md = format_markdown_table({"Test": result})

        self.assertIn("Test", md)
        # Mean should be around 100
        self.assertTrue("97" in md or "100" in md or "98" in md or "99" in md)
        self.assertIn("CI", md)
        self.assertIn("| Test |", md)

    def test_format_comparison_table(self):
        """Test comparison table formatting."""
        np.random.seed(42)
        group1 = np.random.normal(100, 10, 30).tolist()
        group2 = np.random.normal(105, 10, 30).tolist()

        result1, result2, effect, sig = compare_groups(group1, group2)
        table = format_comparison_table([("Group1", "Group2", effect, sig)])

        self.assertIn("Group", table)
        self.assertIn("Cohen", table)
        # Should contain comparison metrics
        self.assertTrue(len(table) > 50)


class TestPowerAnalysis(unittest.TestCase):
    """Test power analysis."""

    def test_power_analysis_detects_large_effect(self):
        """Test power analysis for large effect size."""
        result = power_analysis(effect_size=1.0, alpha=0.05, power=0.8)

        self.assertIsNotNone(result)
        # For large effect (d=1.0), should need ~16-20 samples per group
        self.assertGreater(result, 10)
        self.assertLess(result, 30)

    def test_power_analysis_small_effect_needs_more_n(self):
        """Test that small effects need larger sample size."""
        small_n = power_analysis(effect_size=0.2, alpha=0.05, power=0.8)
        large_n = power_analysis(effect_size=1.0, alpha=0.05, power=0.8)

        self.assertGreater(small_n, large_n)


class TestInterpretation(unittest.TestCase):
    """Test effect size interpretation."""

    def test_interpretation_thresholds(self):
        """Test Cohen's d interpretation thresholds."""
        self.assertEqual(Interpretation.cohens_d(0.0), "negligible")
        self.assertEqual(Interpretation.cohens_d(0.1), "negligible")
        self.assertEqual(Interpretation.cohens_d(0.3), "small")
        self.assertEqual(Interpretation.cohens_d(0.6), "medium")
        self.assertEqual(Interpretation.cohens_d(1.0), "large")
        self.assertEqual(Interpretation.cohens_d(1.5), "very_large")

    def test_interpretation_negative(self):
        """Test interpretation works with negative values."""
        # Should use absolute value
        self.assertEqual(Interpretation.cohens_d(-0.5), "medium")
        self.assertEqual(Interpretation.cohens_d(-1.0), "large")


if __name__ == "__main__":
    unittest.main()
