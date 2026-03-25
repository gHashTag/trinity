# Trinity Cognitive Probes — Scoring Documentation

## Overview

Trinity Cognitive Probes uses a novel **ternary scoring system** combined with **φ-scaling difficulty weights** to evaluate model performance across cognitive tasks.

## Ternary Scoring

### The Three Outcomes

| Score | Meaning | When It Applies |
|-------|---------|-----------------|
| **+1** | Correct | Answer matches ground truth with appropriate confidence |
| **0** | Partial | Partially correct, or appropriate uncertainty expressed |
| **-1** | Incorrect | Wrong answer, or overconfident wrong answer |

### Why Ternary?

Traditional binary scoring (correct/incorrect) fails to capture:
- **Appropriate uncertainty**: "I don't know" can be the right answer
- **Partial credit**: Responses that contain relevant information
- **Overconfidence penalty**: High confidence on wrong answers should be penalized more than low confidence

### Scoring Rules

```python
def score_response(response, ground_truth, confidence, gt_confidence):
    # Exact match
    if response == ground_truth:
        raw_score = 1.0

    # Contains match (partial)
    elif ground_truth in response:
        raw_score = 0.5

    # No match
    else:
        raw_score = 0.0

    # Confidence calibration adjustment
    calibration_error = abs(confidence - gt_confidence)

    # Overconfident wrong answer penalty
    if raw_score == 0.0 and confidence > 0.7:
        raw_score = -0.5

    # Poorly calibrated correct answer
    elif raw_score == 1.0 and calibration_error > 0.2:
        raw_score = 0.5

    return raw_score
```

## φ-Scaling Difficulty

### The Golden Ratio Connection

Trinity uses φ (phi) scaling based on the golden ratio:

```
φ = (1 + √5) / 2 ≈ 1.618
```

### Fibonacci Difficulty Levels

Items are assigned difficulty levels based on Fibonacci numbers:

| Level | Fibonacci | Base Difficulty | φ-Scaled |
|-------|-----------|-----------------|----------|
| 0 | 3 | 3.0 | 3.0 × φ^0 = 3.0 |
| 1 | 5 | 5.0 | 5.0 × φ^0.2 ≈ 5.6 |
| 2 | 8 | 8.0 | 8.0 × φ^0.4 ≈ 10.5 |
| 3 | 13 | 13.0 | 13.0 × φ^0.6 ≈ 19.7 |
| 4 | 21 | 21.0 | 21.0 × φ^0.8 ≈ 34.0 |

### φ-Weighted Score

Higher difficulty items contribute more to the final score:

```python
phi_weight = 1.0 + (φ - 1.0) * (difficulty / max_difficulty)
weighted_score = raw_score * phi_weight
```

**Rationale**: Getting hard questions right should count more than getting easy questions right.

## Final Score Calculation

### Per-Item Score

```
item_score = raw_score × phi_weight
```

Where:
- `raw_score` ∈ {-0.5, 0, 0.5, 1.0} (after calibration)
- `phi_weight` ∈ [1.0, φ] ≈ [1.0, 1.618]

### Aggregate Score

```
final_score = mean(item_scores for all items)
```

**Range**: Approximately [-0.8, 1.6] theoretically, but typically [-0.5, 1.0] in practice.

### Ternary Accuracy

For interpretability, we also compute ternary accuracy:

```
ternary_accuracy = (count(+1) - count(-1)) / total_items
```

**Range**: [-1, 1]
- **1.0**: All correct
- **0.0**: Random performance
- **-1.0**: All incorrect

## Confidence Calibration

### Calibration Error

For each item, compute:

```
calibration_error = |model_confidence - ground_truth_confidence|
```

### Mean Calibration Error

```
mean_calibration_error = mean(calibration_error for all items)
```

**Interpretation**:
- **< 0.1**: Well calibrated
- **0.1 - 0.3**: Acceptably calibrated
- **> 0.3**: Poorly calibrated

## Examples

### Example 1: Perfect Answer

```python
response = "Tashkent"
ground_truth = "Tashkent"
confidence = 0.95
gt_confidence = 0.95

# Result:
# raw_score = 1.0 (exact match)
# calibration_error = 0.0 (perfectly calibrated)
# ternary_score = +1
```

### Example 2: Wrong but Uncertain

```python
response = "I think it might be Moscow, but I'm not sure"
ground_truth = "Tashkent"
confidence = 0.4
gt_confidence = 0.95

# Result:
# raw_score = 0.0 (no match)
# calibration_error = 0.55 (poorly calibrated)
# ternary_score = -1
# But: Low confidence reduces penalty in some contexts
```

### Example 3: Correct but Overconfident

```python
response = "42"
ground_truth = "42"
confidence = 1.0
gt_confidence = 0.5

# Result:
# raw_score = 1.0 (correct)
# calibration_error = 0.5 (overconfident)
# ternary_score = +1
# But: May be reduced in aggregate due to calibration
```

### Example 4: Partial Credit

```python
response = "The capital is Tashkent, located in Uzbekistan"
ground_truth = "Tashkent"
confidence = 0.9
gt_confidence = 0.95

# Result:
# raw_score = 1.0 (contains match)
# ternary_score = +1
```

## Implementation

### Python Implementation

```python
from kaggle.eval import TernaryScorer

scorer = TernaryScorer()

result = scorer.score_item(
    item_id="test_001",
    response="Tashkent",
    ground_truth="Tashkent",
    confidence=0.95,
    ground_truth_confidence=0.95,
    difficulty=3.0
)

print(f"Ternary score: {result.ternary_score}")  # +1
print(f"Raw score: {result.raw_score}")        # 1.0
print(f"φ-weighted: {result.phi_weighted_score}")  # ~1.0
```

### Running Benchmarks

```python
from kaggle.eval import BenchmarkRunner

runner = BenchmarkRunner()
results = runner.run_all()

# Get summary
summary = runner.generate_summary(results)
runner.print_summary(summary)
```

## Validation

The scoring system has been validated to ensure:

1. **Range constraints**: All scores fall within expected ranges
2. **Monotonicity**: Better responses get higher scores
3. **Calibration sensitivity**: Confidence affects scoring appropriately
4. **Difficulty scaling**: Hard items contribute more to final score

## References

- Ternary logic: https://en.wikipedia.org/wiki/Ternary_computer
- Golden ratio: https://en.wikipedia.org/wiki/Golden_ratio
- Fibonacci sequence: https://en.wikipedia.org/wiki/Fibonacci_sequence
- Confidence calibration: https://arxiv.org/abs/1707.00691

## Questions?

For scoring questions or issues, please open a GitHub issue:
https://github.com/gHashTag/trinity/issues
