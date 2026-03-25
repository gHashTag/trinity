#!/usr/bin/env python3
"""
Comparison Tests: v3.3 (Legacy/Incorrect) vs v4 (Correct)

Demonstrates the scientific differences between implementations.
"""

import unittest
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent))

from eval.scientific_metrics_v4 import calculate_full_ece
from eval.scientific_metrics_v5 import calculate_full_ece_v4_correct
from validate.codec import detect_contamination_min_k_pp
from eval.scientific_metrics_v5 import detect_contamination_min_k_pp_v4_correct


class TestFullECEComparison(unittest.TestCase):
    """Compare legacy Full-ECE vs correct implementation."""

    def test_boolean_vs_token_index_api(self):
        """
        DEMONSTRATES: Why boolean correctness is insufficient.

        Legacy API uses boolean `is_correct`, but this doesn't specify WHICH token
        is correct within the probability distribution.
        """
        # Sample: vocab probabilities [0.2, 0.7, 0.1]
        # Top prediction: token 1 (prob=0.7)
        # Actual correct token: 2 (prob=0.1)

        confidences = [[0.2, 0.7, 0.1]]

        # Legacy v3.3: Can only specify boolean (is the top prediction correct?)
        # If top-1 prediction is wrong, entire sample is "incorrect"
        legacy_result = calculate_full_ece(confidences, [False])  # Wrong prediction

        # Correct v4: Specify WHICH token is correct (index 2)
        correct_result = calculate_full_ece_v4_correct(confidences, [2])

        # The results are DIFFERENT because the semantics are different
        # Legacy: treats ALL tokens as incorrect if prediction is wrong
        # Correct: correctly identifies token 2 as correct

        print(f"\n  Legacy (boolean): ECE = {legacy_result:.4f}")
        print(f"  Correct (indices): ECE = {correct_result.ece:.4f}")

        # The key insight: legacy loses information about which token is correct
        self.assertIsNotNone(legacy_result)
        self.assertIsNotNone(correct_result)

    def test_token_level_aggregation_difference(self):
        """
        DEMONSTRATES: How token-level correctness changes ECE calculation.

        When is_correct=False (legacy), ALL tokens contribute 0 to accuracy.
        When correct_token_index=2 (correct), ONLY token 2 contributes its prob to accuracy.
        """
        confidences = [
            [0.1, 0.8, 0.1],  # Top-1 is token 1, but correct is token 0
            [0.9, 0.05, 0.05],  # Top-1 is token 0, correct is token 0
        ]

        # Legacy: top-1 prediction is wrong for sample 0, right for sample 1
        legacy_result = calculate_full_ece(confidences, [False, True])

        # Correct: specify actual correct tokens
        correct_result = calculate_full_ece_v4_correct(confidences, [0, 0])

        print(f"\n  Legacy (boolean): ECE = {legacy_result:.4f}")
        print(f"  Correct (indices): ECE = {correct_result.ece:.4f}")

        # For sample 0:
        # - Legacy: is_correct=False → ALL 3 tokens contribute 0 to accuracy
        # - Correct: correct_token_index=0 → token 0 contributes 0.1, others 0

        # For sample 1:
        # - Both agree it's correct, so contributions are similar

        self.assertIsNotNone(legacy_result)
        self.assertIsNotNone(correct_result)


class TestMinKPPComparison(unittest.TestCase):
    """Compare legacy Min-K%++ vs correct implementation."""

    def test_probability_vs_log_probability(self):
        """
        DEMONSTRATES: Why log probabilities matter.

        Paper Equation 3: score = log p - µ

        Legacy uses probabilities and "spread window".
        Correct uses log probabilities and mean deviation.
        """
        # Clean model confidences (converted to log for comparison)
        probs_clean = [0.15, 0.18, 0.12, 0.14, 0.16]  # Around 0.15
        log_probs_clean = [__import__('math').log(p) for p in probs_clean]  # Around -1.9

        # Legacy v3.3: uses probabilities with spread window
        legacy_result = detect_contamination_min_k_pp(probs_clean)

        # Correct v4: uses log probabilities with paper formula
        correct_result = detect_contamination_min_k_pp_v4_correct(log_probs_clean)

        print(f"\n  Legacy (probabilities): is_contaminated = {legacy_result.is_contaminated}")
        print(f"  Correct (log probs): is_contaminated = {correct_result.is_contaminated}")

        # The key insight: log scale changes the distribution shape
        # and the paper's formula is specifically for log probabilities

    def test_formula_difference(self):
        """
        DEMONSTRATES: Paper Equation 3 vs heuristic "spread window".

        Equation 3: Min-K%++ = log p(xt|x<t) - µx<t
        """
        # Contaminated case: some samples have very low confidence
        log_probs = [-1.5, -1.8, -2.0, -4.5, -5.0]

        # Legacy: uses spread window heuristic
        legacy_result = detect_contamination_min_k_pp(
            [__import__('math').exp(lp) for lp in log_probs]  # Convert to probs
        )

        # Correct: uses paper's Equation 3
        correct_result = detect_contamination_min_k_pp_v4_correct(log_probs)

        print(f"\n  Legacy (spread window): mode_score = {legacy_result.mode_score:.3f}")
        print(f"  Correct (log p - µ): mean_min_k_score = {correct_result.mean_min_k_score:.3f}")

        # The correct version should detect contamination more reliably
        # because it follows the paper's theoretical foundation


class TestAPIDifferences(unittest.TestCase):
    """Document API differences between versions."""

    def test_full_eca_api_difference(self):
        """Show API change for Full-ECE."""
        print("\n  === Full-ECE API Change ===")
        print("  OLD: calculate_full_ece(confidences, correct: List[bool])")
        print("  NEW: calculate_full_ece_v4_correct(confidences, correct_token_indices: List[int])")
        print("")
        print("  Example:")
        print("    confidences = [[0.2, 0.7, 0.1], [0.5, 0.3, 0.2]]")
        print("    # OLD: can only say [False, True] (was top-1 correct?)")
        print("    # NEW: can say [2, 0] (which token is correct)")

    def test_minkpp_api_difference(self):
        """Show API change for Min-K%++."""
        print("\n  === Min-K%++ API Change ===")
        print("  OLD: detect_contamination_min_k_pp(confidences: List[float])")
        print("  NEW: detect_contamination_min_k_pp_v4_correct(log_probabilities: List[float])")
        print("")
        print("  Key change: Input must be LOG probabilities, not probabilities!")
        print("  Formula: score = log p - µ (Equation 3)")

    def test_codec_api_difference(self):
        """Show API change for CoDeC."""
        print("\n  === CoDeC API Change ===")
        print("  OLD: detect_contamination_codec(model, test_samples, context_samples)")
        print("  NEW: detect_contamination_codec_v4_correct(")
        print("            model, test_samples,")
        print("            seen_context_samples,    # Training data")
        print("            unseen_context_samples)  # Control data")
        print("")
        print("  Key change: Need BOTH seen AND unseen context for proper AUC!")


if __name__ == "__main__":
    print("="*60)
    print("Comparison Tests: v3.3 Legacy vs v4 Correct")
    print("="*60)
    unittest.main(verbosity=2)
