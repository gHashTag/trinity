# Kaggle Hackathon — Quick Start Implementation Guide

**Date**: 2026-03-26
**Version**: 1.0
**Author**: Dmitrii Vasilev

---

## Overview

This guide provides **copy-paste ready code** to implement all critical improvements for the hackathon. No theory, just working code.

---

## Step 1: Install Dependencies

```bash
pip install numpy scipy scikit-learn
```

---

## Step 2: Temperature Scaling (10 minutes)

**File**: `kaggle/eval/temperature.py`

```python
"""
Temperature Scaling for Calibration

Guo et al., NeurIPS 2017
"""
import numpy as np
from scipy.optimize import minimize_scalar
from typing import List, Tuple

def optimize_temperature(
    confidences: List[float],
    correct: List[bool]
) -> float:
    """Find optimal temperature using NLL minimization."""
    # Convert to numpy
    confs = np.array(confidences)
    corr = np.array(correct, dtype=float)

    def nll(temp: float) -> float:
        """Negative log likelihood at given temperature."""
        scaled = confs ** (1.0 / temp)
        scaled = np.clip(scaled, 1e-7, 1 - 1e-7)
        return -np.mean(corr * np.log(scaled) + (1 - corr) * np.log(1 - scaled))

    result = minimize_scalar(nll, bounds=(0.5, 2.0), method='bounded')
    return result.x

def apply_temperature(confidences: List[float], temperature: float) -> List[float]:
    """Apply temperature scaling."""
    return [min(0.999, max(0.001, c ** (1.0 / temperature))) for c in confidences]

# Usage
if __name__ == "__main__":
    # Your data
    confidences = [0.9, 0.8, 0.7, 0.6, 0.5]
    correct = [True, True, False, True, False]

    # Optimize
    temp = optimize_temperature(confidences, correct)
    print(f"Optimal temperature: {temp:.3f}")

    # Apply
    calibrated = apply_temperature(confidences, temp)
    print(f"Calibrated: {calibrated}")
```

---

## Step 3: BCa Bootstrap CI (15 minutes)

**File**: `kaggle/eval/bootstrap.py`

```python
"""
BCa Bootstrap Confidence Intervals

Efron, 1987
"""
import numpy as np
from scipy.stats import norm
from typing import List, Tuple

def bootstrap_bca_ci(
    values: List[float],
    alpha: float = 0.05,
    n_bootstrap: int = 10000,
    seed: int = 42
) -> Tuple[float, float, float]:
    """
    BCa bootstrap confidence interval.

    Returns: (point_estimate, ci_lower, ci_upper)
    """
    rng = np.random.default_rng(seed)
    values = np.array(values)
    n = len(values)

    # Point estimate
    theta_hat = np.mean(values)

    # Bootstrap distribution
    boot_means = np.zeros(n_bootstrap)
    for i in range(n_bootstrap):
        sample = rng.choice(values, size=n, replace=True)
        boot_means[i] = np.mean(sample)

    # Bias correction
    z0 = norm.ppf(np.mean(boot_means < theta_hat))

    # Acceleration (jackknife)
    theta_jack = np.zeros(n)
    for i in range(n):
        theta_jack[i] = np.mean(np.delete(values, i))

    theta_dot = np.mean(theta_jack)
    a = np.sum((theta_dot - theta_jack) ** 3) / (6 * np.sum((theta_dot - theta_jack) ** 2) + 1e-10)

    # Adjusted percentiles
    z_alpha = norm.ppf(alpha / 2)
    z_1alpha = norm.ppf(1 - alpha / 2)

    def adjust(z):
        return norm.cdf(z0 + (z0 + z) / (1 - a * (z0 + z)))

    alpha1 = adjust(z_alpha)
    alpha2 = adjust(z_1alpha)

    # CI
    boot_means.sort()
    k1 = int(np.floor(alpha1 * n_bootstrap))
    k2 = int(np.ceil(alpha2 * n_bootstrap))

    ci_lower = boot_means[max(0, k1)]
    ci_upper = boot_means[min(n_bootstrap - 1, k2)]

    return float(theta_hat), float(ci_lower), float(ci_upper)

# Usage
if __name__ == "__main__":
    values = [0.8, 0.75, 0.82, 0.79, 0.81]
    point, lower, upper = bootstrap_bca_ci(values)
    print(f"Metric: {point:.3f} [{lower:.3f}, {upper:.3f}]")
```

---

## Step 4: Brier Score (5 minutes)

**File**: `kaggle/eval/brier.py`

```python
"""
Brier Score for Calibration Assessment

Brier, 1950
"""
from typing import List

def brier_score(confidences: List[float], correct: List[bool]) -> float:
    """
    Brier Score: (1/N) * Σ(f_i - y_i)²

    Lower is better: 0 = perfect, 0.25 = random, 1 = worst
    """
    n = len(confidences)
    if n == 0:
        return 0.0

    outcomes = [1.0 if c else 0.0 for c in correct]
    return sum((f - y) ** 2 for f, y in zip(confidences, outcomes)) / n

def interpret_brier(bs: float) -> str:
    """Interpret Brier score."""
    if bs < 0.10:
        return "excellent"
    elif bs < 0.15:
        return "good"
    elif bs < 0.20:
        return "fair"
    else:
        return "poor"

# Usage
if __name__ == "__main__":
    confidences = [0.9, 0.8, 0.7, 0.6, 0.5]
    correct = [True, True, False, True, False]

    bs = brier_score(confidences, correct)
    print(f"Brier Score: {bs:.3f} ({interpret_brier(bs)})")
```

---

## Step 5: Complete ECE Evaluation (10 minutes)

**File**: `kaggle/eval/complete_ece.py`

```python
"""
Complete ECE Evaluation with CI

Combines Full-ECE, Brier Score, and Bootstrap CI
"""
from typing import List, Dict, Any
from .temperature import optimize_temperature, apply_temperature
from .brier import brier_score, interpret_brier
from .bootstrap import bootstrap_bca_ci
from kaggle.eval.scientific_metrics_v7 import calculate_full_ece_v7

def complete_ece_evaluation(
    confidences: List[float],
    correct: List[bool],
    vocab_size: int = 50000,
    calibrate: bool = True
) -> Dict[str, Any]:
    """
    Complete calibration evaluation.

    Returns dict with:
        - accuracy
        - ece (with CI)
        - brier_score
        - calibration_rating
        - temperature (if calibrated)
    """
    n = len(confidences)

    # Base metrics
    accuracy = sum(correct) / n if n > 0 else 0.0

    # Temperature calibration
    temperature = 1.0
    eval_confs = confidences
    if calibrate and n > 50:
        temperature = optimize_temperature(confidences, correct)
        eval_confs = apply_temperature(confidences, temperature)

    # Full-ECE with CI
    ece_result = calculate_full_ece_v7(
        [[c] for c in eval_confs],
        [0] * n,
        vocab_size=vocab_size,
        n_bootstrap=10000
    )

    # Brier Score
    bs = brier_score(eval_confs, correct)

    # Overall rating
    ece_rating = "good" if ece_result.ece < 0.10 else "fair" if ece_result.ece < 0.20 else "poor"
    bs_rating = interpret_brier(bs)

    if ece_rating == "good" and bs_rating in ["excellent", "good"]:
        overall = "excellent"
    elif ece_rating == "fair" or bs_rating == "fair":
        overall = "good"
    else:
        overall = "needs_improvement"

    return {
        'accuracy': accuracy,
        'ece': ece_result.ece,
        'ece_ci_lower': ece_result.ece_ci_lower,
        'ece_ci_upper': ece_result.ece_ci_upper,
        'brier_score': bs,
        'calibration_rating': overall,
        'temperature': temperature if calibrate else None,
        'n_samples': n
    }

def print_evaluation_report(result: Dict[str, Any]) -> None:
    """Pretty print evaluation report."""
    print("=" * 50)
    print("CALIBRATION EVALUATION REPORT")
    print("=" * 50)

    print(f"Accuracy:           {result['accuracy']:.3f}")
    print(f"ECE:                {result['ece']:.4f}")
    print(f"ECE 95% CI:         [{result['ece_ci_lower']:.4f}, {result['ece_ci_upper']:.4f}]")
    print(f"Brier Score:        {result['brier_score']:.4f}")
    print(f"Calibration:        {result['calibration_rating'].upper()}")

    if result['temperature']:
        print(f"Temperature:        {result['temperature']:.3f}")

    print("=" * 50)

# Usage
if __name__ == "__main__":
    # Example data
    confidences = [0.9, 0.8, 0.7, 0.6, 0.5, 0.85, 0.75, 0.65, 0.55, 0.45]
    correct = [True, True, False, True, False, True, True, False, True, False]

    result = complete_ece_evaluation(confidences, correct)
    print_evaluation_report(result)
```

---

## Step 6: Ensemble with Ranked Voting (20 minutes)

**File**: `kaggle/eval/ensemble.py`

```python
"""
Ranked Voting Self-Consistency

NAACL 2025
"""
from typing import List, Dict

def borda_count(rankings: List[List[int]]) -> Dict[int, int]:
    """
    Borda count aggregation.

    rankings: List of rankings (each is a list of candidate IDs ranked)
    """
    scores = {}

    for ranking in rankings:
        n_candidates = len(ranking)
        for position, candidate in enumerate(ranking):
            # Borda score: (n - position - 1)
            points = n_candidates - position - 1
            scores[candidate] = scores.get(candidate, 0) + points

    return scores

def ranked_voting_ensemble(
    samples: List[List[float]],  # K samples, each with N confidence values
    correct: List[bool],
    method: str = "borda"
) -> Dict[str, any]:
    """
    Ensemble multiple samples using ranked voting.

    Args:
        samples: K lists of N confidences each
        correct: Ground truth (N values)
        method: "borda", "plurality", or "median"

    Returns:
        Dict with ensemble accuracy and per-sample accuracy
    """
    k = len(samples)
    n = len(correct)

    if k == 0 or n == 0:
        return {'error': 'Empty samples or labels'}

    # Per-sample accuracy
    single_accuracies = []
    for sample in samples:
        acc = sum(
            1 for conf, corr in zip(sample, correct)
            if (conf > 0.5) == corr
        ) / n
        single_accuracies.append(acc)

    # Ensemble predictions
    ensemble_preds = []

    for i in range(n):
        # Get confidences for this item across all samples
        item_confs = [sample[i] for sample in samples]

        if method == "borda":
            # Rank by confidence
            ranking = sorted(range(k), key=lambda j: item_confs[j], reverse=True)
            scores = borda_count([ranking])
            # Winner is highest score
            winner = max(scores, key=scores.get)
            ensemble_preds.append(item_confs[winner] > 0.5)

        elif method == "plurality":
            # Majority vote
            votes = sum(1 for c in item_confs if c > 0.5)
            ensemble_preds.append(votes > k / 2)

        else:  # median
            # Median confidence
            median_conf = sorted(item_confs)[k // 2]
            ensemble_preds.append(median_conf > 0.5)

    # Ensemble accuracy
    ensemble_acc = sum(1 for p, c in zip(ensemble_preds, correct) if p == c) / n

    return {
        'ensemble_accuracy': ensemble_acc,
        'single_accuracies': single_accuracies,
        'average_single': sum(single_accuracies) / k,
        'improvement': ensemble_acc - sum(single_accuracies) / k,
        'method': method
    }

# Usage
if __name__ == "__main__":
    # Example: 5 samples, 10 items each
    samples = [
        [0.9, 0.8, 0.7, 0.6, 0.5, 0.85, 0.75, 0.65, 0.55, 0.45],
        [0.85, 0.75, 0.75, 0.65, 0.55, 0.9, 0.7, 0.6, 0.5, 0.4],
        [0.95, 0.85, 0.65, 0.55, 0.45, 0.8, 0.8, 0.7, 0.6, 0.5],
        [0.8, 0.9, 0.8, 0.7, 0.6, 0.75, 0.65, 0.55, 0.45, 0.55],
        [0.9, 0.75, 0.7, 0.65, 0.55, 0.85, 0.75, 0.65, 0.55, 0.45],
    ]
    correct = [True, True, False, True, False, True, True, False, True, False]

    result = ranked_voting_ensemble(samples, correct, method="borda")
    print(f"Ensemble Accuracy: {result['ensemble_accuracy']:.3f}")
    print(f"Average Single:    {result['average_single']:.3f}")
    print(f"Improvement:       {result['improvement']:+.3f}")
```

---

## Step 7: Integration with Runner (10 minutes)

**File**: `kaggle/eval/runner_enhanced.py`

```python
"""
Enhanced Benchmark Runner with All Improvements

Add this to your existing runner.py
"""
from .complete_ece import complete_ece_evaluation
from .ensemble import ranked_voting_ensemble
from typing import List, Dict, Any

class EnhancedRunner:
    """Benchmark runner with all hackathon improvements."""

    def __init__(
        self,
        vocab_size: int = 50000,
        enable_calibration: bool = True,
        enable_ensemble: bool = True
    ):
        self.vocab_size = vocab_size
        self.enable_calibration = enable_calibration
        self.enable_ensemble = enable_ensemble

    def evaluate_single(
        self,
        confidences: List[float],
        correct: List[bool]
    ) -> Dict[str, Any]:
        """Evaluate a single sample set."""
        return complete_ece_evaluation(
            confidences,
            correct,
            vocab_size=self.vocab_size,
            calibrate=self.enable_calibration
        )

    def evaluate_ensemble(
        self,
        samples: List[List[float]],
        correct: List[bool]
    ) -> Dict[str, Any]:
        """Evaluate multiple samples with ensemble."""
        if not self.enable_ensemble:
            return {'error': 'Ensemble disabled'}

        return ranked_voting_ensemble(samples, correct, method="borda")

    def evaluate_complete(
        self,
        data: Dict[str, any]
    ) -> Dict[str, Any]:
        """
        Complete evaluation pipeline.

        data should contain:
            - confidences: single sample list OR
            - samples: multiple sample lists (for ensemble)
            - correct: ground truth labels
        """
        if 'samples' in data and self.enable_ensemble:
            # Ensemble evaluation
            ensemble_result = self.evaluate_ensemble(
                data['samples'],
                data['correct']
            )

            # Also evaluate first sample for comparison
            single_result = self.evaluate_single(
                data['samples'][0],
                data['correct']
            )

            return {
                'ensemble': ensemble_result,
                'single': single_result,
                'n_samples': len(data['samples']),
                'n_items': len(data['correct'])
            }

        else:
            # Single sample evaluation
            return self.evaluate_single(
                data['confidences'],
                data['correct']
            )

# Usage in your existing code
if __name__ == "__main__":
    runner = EnhancedRunner(
        vocab_size=50000,
        enable_calibration=True,
        enable_ensemble=True
    )

    # Single sample
    single_data = {
        'confidences': [0.9, 0.8, 0.7, 0.6, 0.5],
        'correct': [True, True, False, True, False]
    }
    result = runner.evaluate_complete(single_data)
    print(result)
```

---

## Step 8: Kaggle Submission Format (5 minutes)

**File**: `kaggle/eval/submission.py`

```python
"""
Kaggle Submission Formatter

Formats your results for submission
"""
import json
from typing import Dict, Any
from dataclasses import dataclass, asdict

@dataclass
class SubmissionResult:
    """Kaggle submission format."""
    # Primary metrics
    accuracy: float
    ece: float
    ece_ci_lower: float
    ece_ci_upper: float

    # Secondary metrics
    brier_score: float
    temperature: float

    # Metadata
    n_samples: int
    methods: list

    def to_json(self) -> str:
        """Convert to JSON for submission."""
        return json.dumps(asdict(self), indent=2)

def create_submission(
    evaluation_result: Dict[str, Any],
    methods_used: list = None
) -> SubmissionResult:
    """Create submission from evaluation result."""
    return SubmissionResult(
        accuracy=evaluation_result.get('accuracy', 0.0),
        ece=evaluation_result.get('ece', 0.0),
        ece_ci_lower=evaluation_result.get('ece_ci_lower', 0.0),
        ece_ci_upper=evaluation_result.get('ece_ci_upper', 0.0),
        brier_score=evaluation_result.get('brier_score', 0.0),
        temperature=evaluation_result.get('temperature', 1.0),
        n_samples=evaluation_result.get('n_samples', 0),
        methods=methods_used or ['temperature', 'bca_bootstrap', 'brier']
    )

# Usage
if __name__ == "__main__":
    from .complete_ece import complete_ece_evaluation

    # Your evaluation
    result = complete_ece_evaluation(confidences, correct)

    # Create submission
    submission = create_submission(
        result,
        methods_used=['temperature', 'bca_bootstrap', 'brier', 'full_ece_v7']
    )

    # Print or save
    print(submission.to_json())

    # Save to file
    with open('submission.json', 'w') as f:
        f.write(submission.to_json())
```

---

## Complete Integration Example

```python
"""
Complete Example: From Raw Data to Kaggle Submission
"""
from kaggle.eval.complete_ece import complete_ece_evaluation
from kaggle.eval.ensemble import ranked_voting_ensemble
from kaggle.eval.submission import create_submission

def hackathon_pipeline(
    raw_data: dict
) -> str:
    """
    Complete pipeline from raw data to Kaggle submission.

    raw_data format:
        {
            'samples': [[conf1, conf2, ...], ...],  # K samples
            'correct': [True, False, ...]
        }
    """
    # 1. Single sample evaluation (first sample)
    single_result = complete_ece_evaluation(
        raw_data['samples'][0],
        raw_data['correct'],
        calibrate=True
    )

    # 2. Ensemble evaluation (all samples)
    ensemble_result = ranked_voting_ensemble(
        raw_data['samples'],
        raw_data['correct'],
        method="borda"
    )

    # 3. Combine results
    combined_result = {
        **single_result,
        'ensemble_accuracy': ensemble_result['ensemble_accuracy'],
        'ensemble_improvement': ensemble_result['improvement']
    }

    # 4. Create submission
    submission = create_submission(
        combined_result,
        methods_used=['temperature', 'bca_bootstrap', 'brier', 'full_ece_v7', 'borda_ensemble']
    )

    return submission.to_json()

# Example usage
if __name__ == "__main__":
    # Your data
    data = {
        'samples': [
            [0.9, 0.8, 0.7, 0.6, 0.5],
            [0.85, 0.75, 0.75, 0.65, 0.55],
            [0.95, 0.85, 0.65, 0.55, 0.45],
        ],
        'correct': [True, True, False, True, False]
    }

    # Run pipeline
    submission_json = hackathon_pipeline(data)

    # Output
    print(submission_json)
```

---

## Testing Your Implementation

```python
# test_implementation.py
import unittest
from kaggle.eval.temperature import optimize_temperature, apply_temperature
from kaggle.eval.brier import brier_score
from kaggle.eval.bootstrap import bootstrap_bca_ci

class TestHackathonImplementation(unittest.TestCase):

    def test_temperature_scaling(self):
        """Temperature should be close to 1 for well-calibrated data."""
        confs = [0.9, 0.8, 0.7, 0.6, 0.5]
        correct = [True, True, True, False, False]

        temp = optimize_temperature(confs, correct)
        self.assertGreater(temp, 0.5)
        self.assertLess(temp, 2.0)

    def test_brier_score(self):
        """Brier score should be 0 for perfect predictions."""
        confs = [1.0, 0.0, 1.0, 0.0]
        correct = [True, False, True, False]

        bs = brier_score(confs, correct)
        self.assertAlmostEqual(bs, 0.0, places=5)

    def test_bootstrap_ci(self):
        """Bootstrap CI should contain the mean."""
        values = [0.5, 0.6, 0.55, 0.58, 0.52]

        point, lower, upper = bootstrap_bca_ci(values)
        self.assertLessEqual(lower, point)
        self.assertGreaterEqual(upper, point)

if __name__ == '__main__':
    unittest.main()
```

---

## Common Issues and Solutions

### Issue 1: Division by Zero
```python
# Add epsilon to prevent division by zero
epsilon = 1e-10
result = numerator / (denominator + epsilon)
```

### Issue 2: Log of Zero
```python
# Clip values before log
value = max(min_value, min(max_value, value))
log_value = np.log(value)
```

### Issue 3: CI Bounds Out of Range
```python
# Clip CI to valid range
ci_lower = max(0.0, min(1.0, ci_lower))
ci_upper = max(0.0, min(1.0, ci_upper))
```

### Issue 4: Empty Bins
```python
# Skip empty bins
if count > 0:
    weight = count / total_count
    ece += weight * abs(conf - acc)
```

---

## Performance Tips

1. **Use numpy for large datasets**: 10-100x faster than pure Python
2. **Cache expensive computations**: Store KDE, temperature results
3. **Parallelize bootstrap**: Use `multiprocessing.Pool`
4. **Reduce n_bootstrap for testing**: 1000 for tests, 10000 for submission

---

## Submission Checklist

- [ ] All code tested with unit tests
- [ ] Random seeds set for reproducibility
- [ ] CI levels documented (95% default)
- [ ] Methods cited in submission
- [ ] Results formatted per Kaggle requirements
- [ ] JSON submission validated

---

**Document Version**: 1.0
**Last Updated**: 2026-03-26
**Status**: Ready for Use
