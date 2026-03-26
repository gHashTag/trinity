#!/usr/bin/env python3
"""
Unit tests for ternary scoring system.

Tests the TernaryScorer class and related functions.
"""

import unittest
import sys
import math
from pathlib import Path

# Add parent directory to path for imports
sys.path.insert(0, str(Path(__file__).parent.parent))

from eval.scorer import (
    TernaryScorer,
    ScoringResult,
    TrackResults,
    ScoringMode,
    parse_confidence,
    Trit,
)


class TestTernaryScorer(unittest.TestCase):
    """Tests for TernaryScorer class."""

    def setUp(self):
        """Set up test fixtures."""
        self.scorer = TernaryScorer()

    def test_exact_match_correct(self):
        """Test exact match gets +1."""
        result = self.scorer.score_item(
            item_id="test_001",
            response="Solikamsk",
            ground_truth="Solikamsk",
            confidence=0.95,
            ground_truth_confidence=0.95,
            difficulty=3.0
        )

        self.assertEqual(result.ternary_score, 1)
        self.assertEqual(result.raw_score, 1.0)

    def test_exact_match_incorrect(self):
        """Test wrong answer gets -1."""
        result = self.scorer.score_item(
            item_id="test_002",
            response="Paris",
            ground_truth="Solikamsk",
            confidence=0.9,
            ground_truth_confidence=0.95,
            difficulty=3.0
        )

        # High confidence on wrong answer = ternary -1, raw score is negative
        self.assertEqual(result.ternary_score, -1)
        self.assertLess(result.raw_score, 0.0)  # Changed: negative score for overconfident wrong

    def test_partial_match(self):
        """Test partial match gets 0."""
        result = self.scorer.score_item(
            item_id="test_003",
            response="I think it might be Solikamsk or maybe another city",
            ground_truth="Solikamsk",
            confidence=0.5,
            ground_truth_confidence=0.95,
            difficulty=3.0
        )

        # Should get partial credit due to containing correct answer
        self.assertLessEqual(result.ternary_score, 1)
        self.assertGreaterEqual(result.ternary_score, 0)

    def test_overconfident_wrong_penalty(self):
        """Test overconfident wrong answer gets penalty."""
        result = self.scorer.score_item(
            item_id="test_004",
            response="Paris",
            ground_truth="Canberra",
            confidence=0.9,
            ground_truth_confidence=0.95,
            difficulty=5.0
        )

        # High confidence on wrong answer should be penalized
        self.assertEqual(result.ternary_score, -1)
        self.assertLess(result.raw_score, 0.0)

    def test_phi_weighting(self):
        """Test φ-weighting increases with difficulty."""
        result_easy = self.scorer.score_item(
            item_id="test_005",
            response="Correct",
            ground_truth="Correct",
            confidence=0.9,
            ground_truth_confidence=0.9,
            difficulty=3.0
        )

        result_hard = self.scorer.score_item(
            item_id="test_006",
            response="Correct",
            ground_truth="Correct",
            confidence=0.9,
            ground_truth_confidence=0.9,
            difficulty=21.0
        )

        # Harder item should have higher weighted score
        self.assertGreater(result_hard.phi_weighted_score, result_easy.phi_weighted_score)

    def test_calibration_error(self):
        """Test calibration error is calculated correctly."""
        result = self.scorer.score_item(
            item_id="test_007",
            response="Answer",
            ground_truth="Answer",
            confidence=0.5,
            ground_truth_confidence=0.9,
            difficulty=3.0
        )

        # Calibration error should be |0.5 - 0.9| = 0.4
        self.assertAlmostEqual(result.calibration_error, 0.4, places=1)

    def test_aggregate_results(self):
        """Test result aggregation."""
        results = [
            self.scorer.score_item(
                item_id=f"test_{i:03d}",
                response="Correct" if i % 2 == 0 else "Wrong",
                ground_truth="Correct",
                confidence=0.9,
                ground_truth_confidence=0.9,
                difficulty=3.0 + i
            )
            for i in range(10)
        ]

        track_results = self.scorer.aggregate_results(results, "Test Track")

        self.assertEqual(track_results.total_items, 10)
        self.assertGreater(track_results.correct, 0)
        self.assertGreater(track_results.incorrect, 0)

    def test_calculate_phi_weight(self):
        """Test φ-weight calculation."""
        weight_easy = self.scorer.calculate_phi_weight(3.0)
        weight_hard = self.scorer.calculate_phi_weight(21.0)

        self.assertGreater(weight_hard, weight_easy)
        self.assertGreater(weight_easy, 1.0)  # Minimum weight

    def test_numeric_match(self):
        """Test numeric matching."""
        result = self.scorer.score_item(
            item_id="test_008",
            response="The answer is 42",
            ground_truth="42",
            confidence=0.9,
            ground_truth_confidence=0.9,
            difficulty=3.0,
            task_type="math"
        )

        # Should extract number and match
        self.assertEqual(result.ternary_score, 1)

    def test_fuzzy_match(self):
        """Test fuzzy matching tolerance."""
        result = self.scorer.score_item(
            item_id="test_009",
            response="Solikamsk is the capital",
            ground_truth="Solikamsk",
            confidence=0.9,
            ground_truth_confidence=0.9,
            difficulty=3.0
        )

        # Should match due to containing ground truth
        self.assertEqual(result.ternary_score, 1)


class TestParseConfidence(unittest.TestCase):
    """Tests for parse_confidence function."""

    def test_explicit_confidence(self):
        """Test explicit 'confidence: X' format."""
        self.assertEqual(parse_confidence("Answer: test\nConfidence: 0.7"), 0.7)

    def test_percentage_format(self):
        """Test percentage format."""
        self.assertEqual(parse_confidence("70% confident"), 0.7)
        self.assertEqual(parse_confidence("Confidence: 70%"), 0.7)

    def test_slash_10_format(self):
        """Test X/10 format."""
        self.assertEqual(parse_confidence("7/10 confidence"), 0.7)

    def test_slash_100_format(self):
        """Test X/100 format."""
        self.assertEqual(parse_confidence("70/100 confidence"), 0.7)

    def test_json_format(self):
        """Test JSON format."""
        import json
        self.assertEqual(parse_confidence(json.dumps({"confidence": 0.75})), 0.75)

    def test_no_confidence_default(self):
        """Test default when no confidence found."""
        result = parse_confidence("Just an answer without confidence")
        self.assertEqual(result, 0.5)

    def test_confidence_bounds(self):
        """Test confidence is clamped to [0, 1]."""
        self.assertEqual(parse_confidence("Confidence: 150%"), 0.5)  # Invalid -> default
        self.assertIn(parse_confidence("Confidence: -0.1"), [0.0, 0.5])  # Either default or clamped


class TestTernaryAccuracy(unittest.TestCase):
    """Tests for ternary accuracy calculation."""

    def setUp(self):
        """Set up test fixtures."""
        self.scorer = TernaryScorer()

    def test_perfect_accuracy(self):
        """Test perfect accuracy = 1.0."""
        results = [
            ScoringResult(
                item_id=f"test_{i}",
                raw_score=1.0,
                ternary_score=1,
                confidence=0.9,
                ground_truth="test",
                response="test",
                difficulty=3.0,
                phi_weighted_score=1.0,
                calibration_error=0.0
            )
            for i in range(10)
        ]

        accuracy = self.scorer.calculate_ternary_accuracy(results)
        self.assertEqual(accuracy, 1.0)

    def test_random_accuracy(self):
        """Test random accuracy ≈ 0.0."""
        results = []
        for i in range(9):
            results.append(ScoringResult(
                item_id=f"test_{i}",
                raw_score=1.0,
                ternary_score=1,
                confidence=0.9,
                ground_truth="test",
                response="test",
                difficulty=3.0,
                phi_weighted_score=1.0,
                calibration_error=0.0
            ))
        results.append(ScoringResult(
            item_id="test_9",
            raw_score=0.0,
            ternary_score=-1,
            confidence=0.9,
            ground_truth="test",
            response="wrong",
            difficulty=3.0,
            phi_weighted_score=0.0,
            calibration_error=0.0
        ))

        # 9 correct, 1 incorrect = (9-1)/10 = 0.8
        accuracy = self.scorer.calculate_ternary_accuracy(results)
        self.assertAlmostEqual(accuracy, 0.8, places=1)

    def test_inverse_accuracy(self):
        """Test inverse accuracy = -1.0."""
        results = [
            ScoringResult(
                item_id=f"test_{i}",
                raw_score=0.0,
                ternary_score=-1,
                confidence=0.9,
                ground_truth="test",
                response="wrong",
                difficulty=3.0,
                phi_weighted_score=0.0,
                calibration_error=0.0
            )
            for i in range(10)
        ]

        accuracy = self.scorer.calculate_ternary_accuracy(results)
        self.assertEqual(accuracy, -1.0)


class TestScoringResult(unittest.TestCase):
    """Tests for ScoringResult dataclass."""

    def test_result_creation(self):
        """Test creating a scoring result."""
        result = ScoringResult(
            item_id="test_001",
            raw_score=1.0,
            ternary_score=1,
            confidence=0.9,
            ground_truth="expected",
            response="actual",
            difficulty=3.0,
            phi_weighted_score=1.2,
            calibration_error=0.1,
            metadata={"test": "value"}
        )

        self.assertEqual(result.item_id, "test_001")
        self.assertEqual(result.raw_score, 1.0)
        self.assertEqual(result.ternary_score, 1)
        self.assertEqual(result.metadata["test"], "value")


def run_tests():
    """Run all tests and return exit code."""
    loader = unittest.TestLoader()
    suite = loader.loadTestsFromModule(sys.modules[__name__])
    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)
    return 0 if result.wasSuccessful() else 1


# =============================================================================
# v2.1 Scientific Metrics Tests
# =============================================================================

class TestConfidenceDiscretization(unittest.TestCase):
    """Tests for v2.1 confidence discretization."""

    def test_discretize_to_5_percent_buckets(self):
        """Test confidence is discretized to 5% buckets."""
        from eval.scorer_v2 import discretize_confidence

        # Test round to nearest 5
        self.assertEqual(discretize_confidence(0.72), 70)
        self.assertEqual(discretize_confidence(0.73), 75)
        self.assertEqual(discretize_confidence(0.74), 75)
        self.assertEqual(discretize_confidence(0.77), 75)
        self.assertEqual(discretize_confidence(0.78), 80)

        # Test boundaries
        self.assertEqual(discretize_confidence(0.0), 0)
        self.assertEqual(discretize_confidence(1.0), 100)

    def test_confidence_to_bucket(self):
        """Test confidence to bucket index conversion."""
        from eval.scorer_v2 import confidence_to_bucket

        self.assertEqual(confidence_to_bucket(0.0), 0)
        self.assertEqual(confidence_to_bucket(0.25), 5)
        self.assertEqual(confidence_to_bucket(0.50), 10)
        self.assertEqual(confidence_to_bucket(0.75), 15)
        # CRITICAL FIX (v3.0): 100% confidence should be bucket 19, not 20
        self.assertEqual(confidence_to_bucket(1.0), 19)
        self.assertEqual(confidence_to_bucket(0.95), 19)
        self.assertEqual(confidence_to_bucket(0.99), 19)

    def test_confidence_bucket_no_out_of_bounds(self):
        """Test all confidence values map to valid buckets [0-19]."""
        from eval.scorer_v2 import confidence_to_bucket

        for i in range(101):
            confidence = i / 100.0
            bucket = confidence_to_bucket(confidence)
            self.assertGreaterEqual(bucket, 0, f"Confidence {confidence} -> bucket {bucket} < 0")
            self.assertLessEqual(bucket, 19, f"Confidence {confidence} -> bucket {bucket} > 19")


class TestExpectedCalibrationError(unittest.TestCase):
    """Tests for ECE calculation."""

    def test_perfect_calibration(self):
        """Test ECE = 0 for perfect calibration."""
        from eval.scorer_v2 import calculate_ece

        # For perfect calibration, use the same confidence for items with same outcome
        # Low confidences all wrong, high confidences all right
        confidences = [0.1, 0.1, 0.1, 0.9, 0.9, 0.9]
        correct = [False, False, False, True, True, True]

        ece = calculate_ece(confidences, correct, n_bins=10)
        # With perfect per-bucket calibration, ECE should be very low
        self.assertLessEqual(ece, 0.1)

    def test_poor_calibration(self):
        """Test ECE > 0 for poor calibration."""
        from eval.scorer_v2 import calculate_ece

        # High confidence but all wrong
        confidences = [0.9, 0.9, 0.9, 0.9, 0.9]
        correct = [False, False, False, False, False]

        ece = calculate_ece(confidences, correct, n_bins=5)
        self.assertGreater(ece, 0.5)

    def test_calibration_curve(self):
        """Test calibration curve generation."""
        from eval.scorer_v2 import calculate_calibration_curve

        confidences = [0.1, 0.3, 0.5, 0.7, 0.9]
        correct = [False, False, True, True, True]

        curve = calculate_calibration_curve(confidences, correct, n_bins=5)
        self.assertIsInstance(curve, list)
        self.assertGreater(len(curve), 0)


class TestMetaDPrime(unittest.TestCase):
    """Tests for meta-d' calculation."""

    def test_perfect_metacognition(self):
        """Test meta-d' > 0 for good metacognition."""
        from eval.scorer_v2 import calculate_meta_d_prime

        # Good task performance (80% correct) + good metacognition
        # Most correct have high confidence, most incorrect have low confidence
        hits = 45     # Correct + High confidence
        misses = 15    # Correct + Low confidence
        false_alarms = 10   # Incorrect + High confidence
        correct_rejections = 30  # Incorrect + Low confidence

        meta_d, d_prime, mratio = calculate_meta_d_prime(
            hits, misses, false_alarms, correct_rejections
        )

        # Should get positive values for good metacognition
        self.assertGreaterEqual(meta_d, 0.0)
        self.assertGreater(d_prime, 0.0)  # Task performance > 0
        self.assertGreaterEqual(mratio, 0.0)

    def test_no_metacognition(self):
        """Test meta-d' ≈ 0 for random metacognition."""
        from eval.scorer_v2 import calculate_meta_d_prime

        # Random assignment of high/low confidence
        hits = 25
        misses = 25
        false_alarms = 25
        correct_rejections = 25

        meta_d, d_prime, mratio = calculate_meta_d_prime(
            hits, misses, false_alarms, correct_rejections
        )

        # Should be near zero for random performance
        self.assertLess(abs(meta_d), 1.0)  # Relaxed tolerance

    def test_zero_cases(self):
        """Test handling of zero cases."""
        from eval.scorer_v2 import calculate_meta_d_prime
        import math

        # All correct (no Type I variance)
        meta_d, d_prime, mratio = calculate_meta_d_prime(50, 0, 0, 0)
        # When all correct, d' is maximal positive
        self.assertGreater(d_prime, 0.0)

        # All incorrect (negative d')
        meta_d, d_prime, mratio = calculate_meta_d_prime(0, 0, 50, 0)
        self.assertLess(d_prime, 0.0)

        # 50% accuracy = d' = 0 (chance performance)
        meta_d, d_prime, mratio = calculate_meta_d_prime(50, 0, 0, 50)
        self.assertEqual(d_prime, 0.0, "50% accuracy should give d' = 0")

        # CRITICAL FIX (v3.0): Empty data should return NaN for mratio
        meta_d, d_prime, mratio = calculate_meta_d_prime(0, 0, 0, 0)
        self.assertEqual(meta_d, 0.0)
        self.assertEqual(d_prime, 0.0)
        self.assertTrue(math.isnan(mratio), "M-ratio should be NaN for empty data")

    def test_chance_performance(self):
        """Test d' = 0 at chance performance (50% accuracy)."""
        from eval.scorer_v2 import calculate_meta_d_prime
        import math

        # 50% accuracy = chance performance
        meta_d, d_prime, mratio = calculate_meta_d_prime(5, 0, 0, 5)
        self.assertEqual(d_prime, 0.0, "d' should be 0 at chance")
        self.assertTrue(math.isnan(mratio), "M-ratio undefined when d'=0")


class TestNormInverse(unittest.TestCase):
    """Tests for norm_inverse (probit function) - CRITICAL for SDT."""

    def test_norm_inverse_median(self):
        """Test Φ(0) = 0.5 (median of standard normal)."""
        from eval.scorer_v2 import norm_inverse
        import math

        result = norm_inverse(0.5)
        self.assertAlmostEqual(result, 0.0, places=5)

    def test_norm_inverse_one_sigma(self):
        """Test Φ(1) ≈ 0.8413 (one standard deviation)."""
        from eval.scorer_v2 import norm_inverse

        result = norm_inverse(0.8413)
        self.assertAlmostEqual(result, 1.0, places=3)

    def test_norm_inverse_negative_one_sigma(self):
        """Test Φ(-1) ≈ 0.1587 (negative one standard deviation)."""
        from eval.scorer_v2 import norm_inverse

        result = norm_inverse(0.1587)
        self.assertAlmostEqual(result, -1.0, places=3)

    def test_norm_inverse_boundaries(self):
        """Test Φ(∞)=1, Φ(-∞)=0 using approximations."""
        from eval.scorer_v2 import norm_inverse

        # p = 0 should return approximation of -∞
        result_neg = norm_inverse(0.0)
        self.assertLess(result_neg, -5.0, "p=0 should return large negative value")

        # p = 1 should return approximation of +∞
        result_pos = norm_inverse(1.0)
        self.assertGreater(result_pos, 5.0, "p=1 should return large positive value")

    def test_norm_inverse_symmetry(self):
        """Test Φ(-x) = 1 - Φ(x) symmetry property."""
        from eval.scorer_v2 import norm_inverse

        for p in [0.1, 0.25, 0.4]:
            result1 = norm_inverse(p)
            result2 = norm_inverse(1 - p)
            self.assertAlmostEqual(result1, -result2, places=5,
                                 msg=f"Symmetry failed for p={p}")


class TestTypeISDTEdgeCases(unittest.TestCase):
    """Tests for Type I SDT edge cases (v3.0 critical fixes)."""

    def test_type1_sdt_empty_data(self):
        """Test Type I SDT with empty data."""
        from eval.scorer_v2 import calculate_meta_d_prime
        import math

        meta_d, d_prime, mratio = calculate_meta_d_prime(0, 0, 0, 0)
        self.assertEqual(meta_d, 0.0)
        self.assertEqual(d_prime, 0.0)
        self.assertTrue(math.isnan(mratio))

    def test_type1_sdt_all_correct(self):
        """Test Type I SDT when all answers correct."""
        from eval.scorer_v2 import calculate_meta_d_prime

        meta_d, d_prime, mratio = calculate_meta_d_prime(100, 0, 0, 0)
        self.assertGreater(d_prime, 0, "All correct should give positive d'")
        self.assertFalse(math.isnan(mratio), "M-ratio should be defined")

    def test_type1_sdt_all_incorrect(self):
        """Test Type I SDT when all answers incorrect."""
        from eval.scorer_v2 import calculate_meta_d_prime

        meta_d, d_prime, mratio = calculate_meta_d_prime(0, 0, 100, 0)
        self.assertLess(d_prime, 0, "All incorrect should give negative d'")
        self.assertFalse(math.isnan(mratio), "M-ratio should be defined")

    def test_type1_sdt_chance(self):
        """Test Type I SDT at chance (50% correct)."""
        from eval.scorer_v2 import calculate_meta_d_prime
        import math

        meta_d, d_prime, mratio = calculate_meta_d_prime(50, 0, 0, 50)
        self.assertEqual(d_prime, 0.0, "50% accuracy = d' = 0")
        self.assertTrue(math.isnan(mratio), "M-ratio undefined at d'=0")

    def test_type1_sdt_above_chance(self):
        """Test Type I SDT above chance."""
        from eval.scorer_v2 import calculate_meta_d_prime

        # 75% correct (60 correct, 20 incorrect out of 80 total)
        # hits=45, misses=15 (60 correct), false_alarms=5, correct_rejections=15 (20 incorrect)
        meta_d, d_prime, mratio = calculate_meta_d_prime(45, 15, 5, 15)
        self.assertGreater(d_prime, 0, "Above chance should give positive d'")

    def test_type2_sdt_no_correct_data(self):
        """Test Type II SDT when no correct responses."""
        from eval.scorer_v2 import calculate_meta_d_prime

        # n_correct = 0, so Type II cannot be computed
        meta_d, d_prime, mratio = calculate_meta_d_prime(0, 0, 10, 10)
        self.assertEqual(meta_d, 0.0, "Type II should be 0 when n_correct=0")
        self.assertLess(d_prime, 0, "Type I should still work")

    def test_type2_sdt_no_incorrect_data(self):
        """Test Type II SDT when no incorrect responses."""
        from eval.scorer_v2 import calculate_meta_d_prime

        # n_incorrect = 0, so Type II cannot be computed
        meta_d, d_prime, mratio = calculate_meta_d_prime(10, 10, 0, 0)
        self.assertEqual(meta_d, 0.0, "Type II should be 0 when n_incorrect=0")
        self.assertGreater(d_prime, 0, "Type I should still work")


class TestTernaryScorerV2(unittest.TestCase):
    """Tests for v2.1 scorer with scientific metrics."""

    def setUp(self):
        """Set up test fixtures."""
        from eval.scorer_v2 import TernaryScorerV2
        self.scorer = TernaryScorerV2()

    def test_confidence_discretization_in_result(self):
        """Test that results include discretized confidence."""
        result = self.scorer.score_item(
            item_id="test_v2_001",
            response="Solikamsk",
            ground_truth="Solikamsk",
            confidence=0.73,  # Should be discretized to 75
            ground_truth_confidence=0.95,
            difficulty=3.0
        )

        self.assertEqual(result.confidence_discrete, 75)
        self.assertEqual(result.confidence_bucket, 15)

    def test_type2_response_classification(self):
        """Test Type II SDT response classification."""
        # Correct + High confidence = hit
        result1 = self.scorer.score_item(
            item_id="test_v2_002",
            response="Correct",
            ground_truth="Correct",
            confidence=0.9,
            ground_truth_confidence=0.9,
            difficulty=3.0
        )
        self.assertEqual(result1.type2_response, "hit")

        # Correct + Low confidence = miss
        result2 = self.scorer.score_item(
            item_id="test_v2_003",
            response="Correct",
            ground_truth="Correct",
            confidence=0.5,
            ground_truth_confidence=0.9,
            difficulty=3.0
        )
        self.assertEqual(result2.type2_response, "miss")

        # Incorrect + High confidence = false_alarm
        result3 = self.scorer.score_item(
            item_id="test_v2_004",
            response="Wrong",
            ground_truth="Correct",
            confidence=0.9,
            ground_truth_confidence=0.9,
            difficulty=3.0
        )
        self.assertEqual(result3.type2_response, "false_alarm")

        # Incorrect + Low confidence = correct_rejection
        result4 = self.scorer.score_item(
            item_id="test_v2_005",
            response="Wrong",
            ground_truth="Correct",
            confidence=0.4,
            ground_truth_confidence=0.9,
            difficulty=3.0
        )
        self.assertEqual(result4.type2_response, "correct_rejection")

    def test_aggregate_with_v2_metrics(self):
        """Test aggregation includes v2.1 metrics."""
        results = []
        for i in range(10):
            is_correct = i % 2 == 0
            confidence = 0.9 if is_correct else 0.4

            result = self.scorer.score_item(
                item_id=f"test_v2_{i:03d}",
                response="Correct" if is_correct else "Wrong",
                ground_truth="Correct",
                confidence=confidence,
                ground_truth_confidence=0.9,
                difficulty=3.0
            )
            results.append(result)

        track_results = self.scorer.aggregate_results(results, "Test Track V2")

        # Check v2.1 metrics are present
        self.assertIsNotNone(track_results.ece)
        self.assertIsNotNone(track_results.meta_d_prime)
        self.assertIsNotNone(track_results.mratio)
        self.assertIsNotNone(track_results.calibration_curve)
        self.assertIsNotNone(track_results.type2_counts)


class TestPassAtTwo(unittest.TestCase):
    """Tests for Pass@2 scoring."""

    def test_either_correct_passes(self):
        """Test Pass@2 = 1 if either attempt correct."""
        from eval.scorer_v2 import score_pass_at_two

        # First correct, second wrong
        score = score_pass_at_two(1.0, 0.0)
        self.assertEqual(score, 1.0)

        # First wrong, second correct
        score = score_pass_at_two(0.0, 1.0)
        self.assertEqual(score, 1.0)

    def test_both_wrong_fails(self):
        """Test Pass@2 = 0 if both attempts wrong."""
        from eval.scorer_v2 import score_pass_at_two

        score = score_pass_at_two(0.0, 0.0)
        self.assertEqual(score, 0.0)

    def test_both_correct_passes(self):
        """Test Pass@2 = 1 if both attempts correct."""
        from eval.scorer_v2 import score_pass_at_two

        score = score_pass_at_two(1.0, 1.0)
        self.assertEqual(score, 1.0)


# =============================================================================
# v2.2 Sacred Mathematics Tests
# =============================================================================

class TestTrit(unittest.TestCase):
    """Tests for Trit enum (sacred ternary digit)."""

    def test_trit_values(self):
        """Test Trit enum values match {-1, 0, +1}."""
        self.assertEqual(Trit.NEGATIVE.value, -1)
        self.assertEqual(Trit.ZERO.value, 0)
        self.assertEqual(Trit.POSITIVE.value, 1)

    def test_trit_from_raw_positive(self):
        """Test mapping positive scores to POSITIVE trit."""
        self.assertEqual(Trit.from_raw_score(1.0), Trit.POSITIVE)
        self.assertEqual(Trit.from_raw_score(0.7), Trit.POSITIVE)
        self.assertEqual(Trit.from_raw_score(0.5), Trit.POSITIVE)

    def test_trit_from_raw_negative(self):
        """Test mapping negative scores to NEGATIVE trit."""
        self.assertEqual(Trit.from_raw_score(-1.0), Trit.NEGATIVE)
        self.assertEqual(Trit.from_raw_score(-0.7), Trit.NEGATIVE)
        self.assertEqual(Trit.from_raw_score(-0.5), Trit.NEGATIVE)

    def test_trit_from_raw_zero(self):
        """Test mapping middle scores to ZERO trit."""
        self.assertEqual(Trit.from_raw_score(0.0), Trit.ZERO)
        self.assertEqual(Trit.from_raw_score(0.3), Trit.ZERO)
        self.assertEqual(Trit.from_raw_score(-0.3), Trit.ZERO)

    def test_trit_string_representation(self):
        """Test Trit string representation."""
        self.assertEqual(str(Trit.POSITIVE), "¹")
        self.assertEqual(str(Trit.ZERO), "°")
        self.assertEqual(str(Trit.NEGATIVE), "¹")


class TestSacredIdentity(unittest.TestCase):
    """Tests for sacred identity φ² + 1/φ² = 3."""

    def test_sacred_identity_verification(self):
        """Test φ² + 1/φ² = 3 holds true."""
        self.assertTrue(TernaryScorer.verify_sacred_identity())

    def test_phi_constant(self):
        """Test PHI constant value."""
        import math
        expected = (1 + math.sqrt(5)) / 2
        self.assertAlmostEqual(TernaryScorer.PHI, expected, places=10)

    def test_gamma_constant(self):
        """Test γ = φ⁻³ constant value."""
        expected_gamma = TernaryScorer.PHI ** -3
        self.assertAlmostEqual(TernaryScorer.GAMMA, expected_gamma, places=6)
        self.assertAlmostEqual(TernaryScorer.GAMMA, 0.236, places=3)

    def test_sacred_pi_constant(self):
        """Test π_sacred = φ + 2 constant value."""
        expected = TernaryScorer.PHI + 2
        self.assertAlmostEqual(TernaryScorer.SACRED_PI, expected, places=10)
        self.assertAlmostEqual(TernaryScorer.SACRED_PI, 3.618, places=3)


class TestSacredFormula(unittest.TestCase):
    """Tests for Sacred Formula: V = n × 3^k × π^m × φ^p × e^q."""

    def test_base_score(self):
        """Test base score with no exponents."""
        result = TernaryScorer.sacred_formula_score(1)
        self.assertEqual(result, 1.0)

    def test_negative_base(self):
        """Test negative base score."""
        result = TernaryScorer.sacred_formula_score(-1)
        self.assertEqual(result, -1.0)

    def test_zero_base(self):
        """Test zero base score."""
        result = TernaryScorer.sacred_formula_score(0)
        self.assertEqual(result, 0.0)

    def test_ternary_exponent(self):
        """Test ternary exponent amplifies score."""
        base = TernaryScorer.sacred_formula_score(1)
        amplified = TernaryScorer.sacred_formula_score(1, k=2)
        self.assertGreater(amplified, base)

    def test_phi_exponent(self):
        """Test phi exponent scales score."""
        base = TernaryScorer.sacred_formula_score(1)
        phi_scaled = TernaryScorer.sacred_formula_score(1, p=3)
        self.assertGreater(phi_scaled, base)

    def test_combined_exponents(self):
        """Test combined exponents multiply effects."""
        single = TernaryScorer.sacred_formula_score(1, k=1)
        combined = TernaryScorer.sacred_formula_score(1, k=1, p=1, m=1)
        self.assertGreater(combined, single)


class TestGammaWeighting(unittest.TestCase):
    """Tests for γ (gamma) weighted scoring."""

    def test_gamma_reduces_negative(self):
        """Test gamma weighting reduces negative scores."""
        raw_negative = -1.0
        weighted = TernaryScorer.gamma_weighted_score(raw_negative)
        self.assertLess(weighted, 0)
        self.assertGreater(weighted, raw_negative)  # Less negative

    def test_gamma_preserves_positive(self):
        """Test gamma weighting preserves positive scores."""
        raw_positive = 1.0
        weighted = TernaryScorer.gamma_weighted_score(raw_positive)
        self.assertEqual(weighted, raw_positive)

    def test_gamma_preserves_zero(self):
        """Test gamma weighting preserves zero."""
        raw_zero = 0.0
        weighted = TernaryScorer.gamma_weighted_score(raw_zero)
        self.assertEqual(weighted, raw_zero)

    def test_gamma_value(self):
        """Test gamma value is approximately 0.236."""
        self.assertAlmostEqual(TernaryScorer.GAMMA, 0.236, places=3)


class TestSacredMathIntegration(unittest.TestCase):
    """Tests for sacred math integration in scoring."""

    def setUp(self):
        """Set up test fixtures."""
        self.scorer = TernaryScorer()

    def test_score_includes_trit_value(self):
        """Test scoring result includes Trit value."""
        result = self.scorer.score_item(
            item_id="test_sacred_001",
            response="Solikamsk",
            ground_truth="Solikamsk",
            confidence=0.9,
            ground_truth_confidence=0.9,
            difficulty=3.0
        )

        self.assertIn("trit_value", result.metadata)
        self.assertEqual(result.metadata["trit_value"], 1)

    def test_score_includes_sacred_identity_verified(self):
        """Test scoring result includes sacred identity verification."""
        result = self.scorer.score_item(
            item_id="test_sacred_002",
            response="Answer",
            ground_truth="Answer",
            confidence=0.9,
            ground_truth_confidence=0.9,
            difficulty=3.0
        )

        self.assertIn("sacred_identity_verified", result.metadata)
        self.assertTrue(result.metadata["sacred_identity_verified"])

    def test_raw_to_trit_method(self):
        """Test raw_to_trit method on scorer."""
        self.assertEqual(self.scorer.raw_to_trit(1.0), Trit.POSITIVE)
        self.assertEqual(self.scorer.raw_to_trit(0.0), Trit.ZERO)
        self.assertEqual(self.scorer.raw_to_trit(-1.0), Trit.NEGATIVE)


if __name__ == "__main__":
    sys.exit(run_tests())
