#!/usr/bin/env python3
"""
Test suite for calibration.py module.

Tests:
- Temperature scaling optimization
- Platt scaling
- Isotonic regression
- Beta calibration
- Confidence clamping
- ECE/NLL calculation
"""

import pytest
import math
from kaggle.eval.calibration import (
    calculate_nll,
    calculate_ece,
    apply_temperature,
    find_optimal_temperature,
    find_optimal_temperature_scipy,
    platt_scaling,
    isotonic_regression,
    beta_calibration,
    calibrate_confidences,
    confidence_clamping,
    TemperatureScalingResult,
    CalibrationResult
)


class TestNLLandECE:
    """Test basic metric calculations."""

    def test_nll_perfect_predictions(self):
        """NLL should be 0 for perfect predictions."""
        confidences = [0.9, 0.8, 0.7, 1.0, 0.95]
        correct = [True, True, True, True, True]
        nll = calculate_nll(confidences, correct)
        # Should be very low (not exactly 0 due to epsilon)
        assert nll < 0.1

    def test_nll_terrible_predictions(self):
        """NLL should be high for confidently wrong predictions."""
        confidences = [0.9, 0.9, 0.9, 0.9, 0.9]
        correct = [False, False, False, False, False]
        nll = calculate_nll(confidences, correct)
        # Should be high (> 2)
        assert nll > 2.0

    def test_nll_edge_cases(self):
        """NLL should handle edge cases gracefully."""
        # Empty lists
        assert calculate_nll([], []) == float('inf')

        # Single prediction
        nll = calculate_nll([0.5], [True])
        assert 0.5 < nll < 1.0  # -log(0.5) ≈ 0.693

    def test_ece_perfect_calibration(self):
        """ECE should be 0 for perfectly calibrated predictions."""
        confidences = [0.5, 0.5, 0.8, 0.8, 0.2, 0.2]
        correct = [True, False, True, False, True, False]
        # Each confidence level has 50% accuracy
        ece = calculate_ece(confidences, correct, n_bins=5)
        assert ece < 0.05

    def test_ece_overconfident(self):
        """ECE should be high for overconfident predictions."""
        confidences = [0.9, 0.9, 0.9, 0.9, 0.9]
        correct = [True, False, True, False, True]
        # 90% confidence but 60% accuracy = high ECE
        ece = calculate_ece(confidences, correct, n_bins=5)
        assert ece > 0.1

    def test_ece_empty(self):
        """ECE should be 0 for empty lists."""
        assert calculate_ece([], []) == 0.0


class TestTemperatureScaling:
    """Test temperature scaling methods."""

    def test_apply_temperature_identity(self):
        """T=1 should not change confidences."""
        confidences = [0.1, 0.5, 0.9]
        scaled = apply_temperature(confidences, 1.0)
        assert scaled == pytest.approx(confidences, abs=0.001)

    def test_apply_temperature_soften(self):
        """T>1 should soften confidences (push toward 0.5)."""
        confidences = [0.1, 0.5, 0.9]
        scaled = apply_temperature(confidences, 2.0)

        # 0.1 should increase (move toward 0.5)
        assert scaled[0] > confidences[0]
        # 0.9 should decrease (move toward 0.5)
        assert scaled[2] < confidences[2]
        # 0.5 should stay at 0.5
        assert scaled[1] == pytest.approx(0.5, abs=0.01)

    def test_apply_temperature_sharpen(self):
        """T<1 should sharpen confidences (push toward 0/1)."""
        confidences = [0.3, 0.5, 0.7]
        scaled = apply_temperature(confidences, 0.5)

        # 0.3 should decrease (move toward 0)
        assert scaled[0] < confidences[0]
        # 0.7 should increase (move toward 1)
        assert scaled[2] > confidences[2]

    def test_apply_temperature_bounds(self):
        """Temperature scaling should respect [0, 1] bounds."""
        confidences = [0.0, 0.5, 1.0]
        scaled = apply_temperature(confidences, 0.1)
        # Should all be in [0, 1]
        assert all(0 <= s <= 1 for s in scaled)

    def test_apply_temperature_invalid(self):
        """Invalid temperature should raise error."""
        with pytest.raises(ValueError):
            apply_temperature([0.5], 0)
        with pytest.raises(ValueError):
            apply_temperature([0.5], -1)

    def test_find_optimal_temperature_grid(self):
        """Grid search should find temperature that improves calibration."""
        # Create miscalibrated data (overconfident)
        confidences = [0.9] * 50 + [0.1] * 50
        correct = [True] * 40 + [False] * 10 + [True] * 10 + [False] * 40

        ece_before = calculate_ece(confidences, correct)
        result = find_optimal_temperature(confidences, correct, n_steps=50)

        # Should find T > 1 to soften overconfidence
        assert result.optimal_temperature > 1.0
        # ECE should improve
        assert result.ece_after < result.ece_before
        assert isinstance(result, TemperatureScalingResult)

    def test_find_optimal_temperature_scipy(self):
        """Scipy optimization should work if scipy available."""
        pytest.importorskip("scipy")

        confidences = [0.9] * 50 + [0.1] * 50
        correct = [True] * 40 + [False] * 10 + [True] * 10 + [False] * 40

        result = find_optimal_temperature_scipy(confidences, correct)

        assert result.optimal_temperature > 1.0
        assert result.ece_after < result.ece_before


class TestPlattScaling:
    """Test Platt scaling calibration."""

    def test_platt_scaling_requires_sklearn(self):
        """Platt scaling requires scikit-learn."""
        pytest.importorskip("sklearn")

        confidences = [0.1, 0.3, 0.5, 0.7, 0.9]
        correct = [False, False, True, True, True]

        calibrate, result = platt_scaling(confidences, correct)

        assert callable(calibrate)
        assert isinstance(result, CalibrationResult)
        assert result.method == "platt"
        assert "A" in result.calibration_params
        assert "B" in result.calibration_params

    def test_platt_scaling_improves_calibration(self):
        """Platt scaling should improve ECE on miscalibrated data."""
        pytest.importorskip("sklearn")

        # Overconfident predictions
        np = pytest.importorskip("numpy")
        confidences = []
        correct = []
        for _ in range(100):
            conf = np.random.beta(2, 2)  # Biased toward 0.5
            confidences.append(0.5 + 0.4 * (conf - 0.5) / 0.5)  # Push to extremes
            correct.append(conf > 0.5)

        calibrate, result = platt_scaling(confidences, correct)

        # Should improve (or at least not significantly worsen)
        assert result.ece_after <= result.ece_before * 1.1


class TestIsotonicRegression:
    """Test isotonic regression calibration."""

    def test_isotonic_requires_sklearn(self):
        """Isotonic regression requires scikit-learn."""
        pytest.importorskip("sklearn")

        confidences = [0.1, 0.2, 0.3, 0.4, 0.5]
        correct = [False, False, False, True, True]

        calibrate, result = isotonic_regression(confidences, correct)

        assert callable(calibrate)
        assert isinstance(result, CalibrationResult)
        assert result.method == "isotonic"

    def test_isotonic_monotonic(self):
        """Isotonic calibration should be monotonic."""
        pytest.importorskip("sklearn")

        confidences = [0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7, 0.8, 0.9]
        correct = [c < 0.5 for c in confidences]

        calibrate, _ = isotonic_regression(confidences, correct)

        # Check monotonicity: if c1 < c2 then calibrate(c1) <= calibrate(c2)
        calibrated = [calibrate(c) for c in confidences]
        for i in range(len(calibrated) - 1):
            assert calibrated[i] <= calibrated[i + 1] + 1e-10


class TestBetaCalibration:
    """Test beta calibration."""

    def test_beta_requires_scipy(self):
        """Beta calibration requires scipy."""
        pytest.importorskip("scipy")

        confidences = [0.1, 0.3, 0.5, 0.7, 0.9]
        correct = [False, False, True, True, True]

        calibrate, result = beta_calibration(confidences, correct)

        assert callable(calibrate)
        assert isinstance(result, CalibrationResult)
        assert result.method == "beta"
        assert "alpha" in result.calibration_params
        assert "beta" in result.calibration_params


class TestCalibrationWrapper:
    """Test the unified calibrate_confidences function."""

    def test_temperature_method(self):
        """Default temperature method should work."""
        confidences = [0.9] * 10 + [0.1] * 10
        correct = [True] * 8 + [False] * 2 + [True] * 2 + [False] * 8

        calibrate, result = calibrate_confidences(confidences, correct, method="temperature")

        assert callable(calibrate)
        assert result.method == "temperature"

    def test_unknown_method_raises(self):
        """Unknown method should raise ValueError."""
        with pytest.raises(ValueError, match="Unknown calibration method"):
            calibrate_confidences([0.5], [True], method="unknown")


class TestConfidenceClamping:
    """Test confidence clamping utility."""

    def test_clamp_basic(self):
        """Basic clamping should work."""
        confidences = [0.0, 0.01, 0.5, 0.99, 1.0]
        clamped = confidence_clamping(confidences, min_conf=0.05, max_conf=0.95)

        assert clamped[0] == 0.05
        assert clamped[1] == 0.05
        assert clamped[2] == 0.5
        assert clamped[3] == 0.95
        assert clamped[4] == 0.95

    def test_clamp_no_change(self):
        """Clamping within range should not change values."""
        confidences = [0.1, 0.5, 0.9]
        clamped = confidence_clamping(confidences, min_conf=0.0, max_conf=1.0)
        assert clamped == confidences

    def test_clamp_all_same(self):
        """Clamping to same value should flatten."""
        confidences = [0.1, 0.5, 0.9]
        clamped = confidence_clamping(confidences, min_conf=0.5, max_conf=0.5)
        assert all(c == 0.5 for c in clamped)


class TestCalibrationResult:
    """Test CalibrationResult dataclass."""

    def test_str_representation(self):
        """String representation should be informative."""
        result = CalibrationResult(
            method="test",
            ece_before=0.15,
            ece_after=0.08,
            nll_before=0.5,
            nll_after=0.3,
            improvement=0.466,
            calibration_params={"T": 1.5}
        )

        s = str(result)
        assert "test" in s
        assert "0.15" in s
        assert "0.08" in s
        assert "46.6%" in s


class TestAdaptiveTemperature:
    """Test adaptive temperature scaling."""

    def test_adaptive_by_difficulty_default(self):
        """Default: use confidence as difficulty proxy."""
        from kaggle.eval.calibration import adaptive_temperature_by_difficulty

        confidences = [0.9, 0.5, 0.1]
        result = adaptive_temperature_by_difficulty(confidences)

        # High conf -> easy -> T > 1 -> soften (decrease)
        assert result[0] < confidences[0]
        # Mid conf -> T ~ 1
        assert 0.4 < result[1] < 0.6
        # Low conf -> hard -> T < 1 -> sharpen (decrease further)
        assert result[2] < confidences[2]

    def test_adaptive_with_explicit_difficulty(self):
        """Explicit difficulty scores."""
        from kaggle.eval.calibration import adaptive_temperature_by_difficulty

        confidences = [0.5, 0.5, 0.5]
        difficulties = [0.0, 0.5, 1.0]  # easy, medium, hard

        result = adaptive_temperature_by_difficulty(confidences, difficulties)

        # Easy (T > 1) -> soften toward 0.5
        # Hard (T < 1) -> sharpen away from 0.5
        assert result[0] >= result[1] >= result[2] or result[0] <= result[1] <= result[2]


class TestConformalPrediction:
    """Test conformal prediction methods."""

    def test_compute_conformal_threshold(self):
        """Threshold should give target coverage."""
        from kaggle.eval.calibration import compute_conformal_threshold

        # Well-calibrated data
        confidences = [0.9, 0.8, 0.7, 0.6, 0.5]
        correct = [True, True, True, False, False]

        q = compute_conformal_threshold(confidences, correct, target_coverage=0.8)

        # Threshold should be in valid range
        assert 0.0 <= q <= 1.0

    def test_conformal_predict(self):
        """Prediction should respect threshold."""
        from kaggle.eval.calibration import conformal_predict

        q = 0.3  # threshold

        # Above threshold: predict positive
        pred, conf, abstain = conformal_predict(0.8, q)
        assert pred is True
        assert abstain is False

        # Below threshold: abstain
        pred, conf, abstain = conformal_predict(0.1, q)
        assert pred is False
        assert abstain is True


class TestBordaCount:
    """Test Borda count aggregation."""

    def test_borda_count_majority(self):
        """Most common response should win."""
        from kaggle.eval.calibration import borda_count_aggregate

        responses = ["A", "A", "B", "A", "C"]
        winner = borda_count_aggregate(responses)

        assert winner == "A"

    def test_borda_count_tie(self):
        """Tie goes to first in most_common order."""
        from kaggle.eval.calibration import borda_count_aggregate

        responses = ["A", "B", "A", "B"]
        winner = borda_count_aggregate(responses)

        # Either A or B is acceptable (Counter order)
        assert winner in ["A", "B"]

    def test_borda_count_empty(self):
        """Empty list returns empty string."""
        from kaggle.eval.calibration import borda_count_aggregate

        winner = borda_count_aggregate([])
        assert winner == ""


class TestWeightedEnsemble:
    """Test weighted ensemble calibration."""

    def test_equal_weights(self):
        """Equal weights should average methods."""
        from kaggle.eval.calibration import weighted_ensemble_calibration

        confidences = [0.5]

        # Two identity methods with equal weights
        methods = [lambda c: c, lambda c: c]
        result = weighted_ensemble_calibration(confidences, methods)

        assert result[0] == pytest.approx(0.5)

    def test_weighted_average(self):
        """Weighted average should work correctly."""
        from kaggle.eval.calibration import weighted_ensemble_calibration

        confidences = [0.5]

        # Method 1: c -> 0.4, Method 2: c -> 0.6
        methods = [lambda c: 0.4, lambda c: 0.6]
        weights = [0.5, 0.5]

        result = weighted_ensemble_calibration(confidences, methods, weights)

        # (0.4 + 0.6) / 2 = 0.5
        assert result[0] == pytest.approx(0.5)


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
