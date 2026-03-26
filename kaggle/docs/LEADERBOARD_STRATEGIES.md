# Leaderboard Strategies — Trinity Cognitive Probes

## 🏆 Understanding the Scoring

Your final score = φ-weighted mean score across all items.

```
Final Score = Σ(item_score × φ_weight) / Σ(φ_weights)
```

Where:
- `item_score` ∈ {-1, 0, +1} based on correctness × calibration
- `φ_weight` ∈ [1, 2.2] based on difficulty (harder = higher weight)

**Key insight**: Hard items (difficulty ~21) count ~2x more than easy items (difficulty ~3). Don't ignore them!

---

## 📊 Tier 1: Just Submit (Beginner)

**Target**: Get on the leaderboard, learn the format.

```python
import pandas as pd

# Load sample submission
submission = pd.read_csv("/kaggle/input/trinity-cognitive-probes/sample_submission.csv")

# Baseline: All zeros (random guessing)
submission['score'] = 0.0

# Save
submission.to_csv("submission.csv", index=False)
print("✅ Submission ready!")
```

**Expected score**: ~0.0 (random baseline)

---

## 📊 Tier 2: Use the Evaluator (Intermediate)

**Target**: Run actual model, get reasonable score.

```python
from kaggle.eval import BenchmarkRunner

# Initialize runner
runner = BenchmarkRunner(
    api_provider="auto",  # Automatic fallback
    tier="standard",       # GPT-4/Claude Sonnet class
    dry_run=False          # Actually call APIs
)

# Run single track for faster iteration
results = runner.run_all(
    tracks=[Track.METACOGNITION],  # Start with one track
    max_items_per_track=100        # Subset for testing
)

# Save submission
runner.save_submission(results, "submission.csv")
```

**Expected score**: 0.3-0.5 (uncalibrated model)

---

## 📊 Tier 3: Optimize Confidence (Advanced)

**Target**: Calibrate confidence for maximum score.

### Strategy 3.1: Temperature Tuning

```python
runner = BenchmarkRunner(
    api_provider="anthropic",
    tier="flagship",
    temperature=0.3  # Lower temp = better calibration
)
```

**Why it works**: Lower temperature → more deterministic outputs → better confidence calibration.

### Strategy 3.2: Logprob-Based Confidence

```python
runner = BenchmarkRunner(
    api_provider="anthropic",
    use_logprobs=True  # Use Claude's logprobs
)
```

**Why it works**: Logprobs are MORE reliable than verbalized confidence (Mielke et al., 2024).

### Strategy 3.3: Calibration Layer

Post-hoc temperature scaling to fix calibration:

```python
import numpy as np
from scipy.optimize import minimize

def temperature_scaling(confidences, correct):
    """Find optimal temperature for calibration."""
    def nll(temp):
        scaled = np.clip(confidences ** (1/temp), 1e-10, 1-1e-10)
        return -np.mean(correct * np.log(scaled) +
                       (1-correct) * np.log(1-scaled))

    result = minimize(nll, x0=1.0, bounds=[(0.1, 10.0)])
    return result.x[0]

# Usage:
# 1. Get confidences from model
# 2. Run on validation set to get optimal temp
# 3. Apply temp scaling to test predictions
```

### Strategy 3.4: Strategic Uncertainty

```python
def adjust_confidence_for_difficulty(
    confidence: float,
    difficulty: float,
    threshold: float = 10.0
) -> float:
    """
    Lower confidence on hard items.
    Hard items (difficulty > 10) get confidence penalty.
    """
    if difficulty > threshold:
        # Reduce confidence by 10-30% based on difficulty
        penalty = min(0.3, (difficulty - threshold) / 50.0)
        return max(0.1, confidence * (1 - penalty))
    return confidence
```

**Why it works**: Better to be underconfident on hard items than overconfident and wrong.

---

## 📊 Tier 4: Multi-Provider Fallback (Expert)

**Target**: Maximize completion rate, handle rate limits.

```python
from kaggle.eval import MultiProviderClient, Provider

# Custom provider order
client = MultiProviderClient(
    preferred_order=[
        Provider.ANTHROPIC,  # Try Claude first (best calibration)
        Provider.OPENAI,     # Fallback to GPT-4
        Provider.GOOGLE,     # Fallback to Gemini
    ],
    auto_fallback=True,
    max_retries=3
)

runner = BenchmarkRunner(client=client)
```

**Why it works**: Different providers have different rate limits. Fallback ensures you complete all items.

---

## 📊 Tier 5: Pass@2 Optimization (Research)

**Target**: Leverage two attempts for generalization bonus.

```python
def run_with_pass_at_two(runner, item_id: str, question: str) -> float:
    """
    Run item twice with different seeds.
    Score = 1.0 if EITHER attempt correct.
    """
    # Attempt 1
    result1 = runner.run_item(item_id, question, seed=42)

    # Attempt 2 (different seed)
    result2 = runner.run_item(item_id, question, seed=123)

    # Pass@2 score
    return 1.0 if (result1.raw_score >= 0.5 or result2.raw_score >= 0.5) else 0.0
```

**Why it works**: Measures generalization, not memorization. Hard items benefit most.

---

## 🎯 Track-Specific Strategies

### Metacognition (TMP)

**Key**: Confidence calibration matters MOST here.

```python
# Ideal: High confidence on correct, low confidence on wrong
if confidence > 0.7 and not is_correct:
    score = -1  # Penalized heavily!
```

**Strategy**:
- Use temperature 0.2-0.4
- Enable logprobs if available
- Consider "I don't know" responses for low-confidence items

### Attention (TAGP)

**Key**: Needle-in-haystack tasks reward carefulness.

**Strategy**:
- Longer context windows help
- Consider re-reading the prompt (chain-of-thought)
- Lower temperature for focus

### Executive (TEFB)

**Key**: Multi-step reasoning requires planning.

**Strategy**:
- Use chain-of-thought prompting
- Break down complex tasks
- Verify each step before proceeding

### Learning (THLP)

**Key**: Few-shot learning rewards pattern matching.

**Strategy**:
- Provide clear examples in prompt
- Use in-context learning
- Temperature 0.3-0.5 for some exploration

### Social (TSCP)

**Key**: Theory of mind requires perspective-taking.

**Strategy**:
- Explicitly consider multiple perspectives
- Avoid egocentric bias
- Cultural context matters for non-English

---

## 🚫 Common Pitfalls (Avoid These!)

### Pitfall 1: Overconfidence on Easy Items

```python
# BAD: Always 0.95+ confidence
confidence = 0.99

# GOOD: Vary confidence based on certainty
confidence = 0.99 if is_certain else 0.65
```

### Pitfall 2: Ignoring Difficulty Weights

```python
# BAD: Same effort on all items
for item in items:
    answer(item)

# GOOD: Spend more compute on hard items
for item in items:
    if item.difficulty > 15:
        answer_with_chain_of_thought(item)
    else:
        answer(item)
```

### Pitfall 3: Not Using Logprobs

```python
# BAD: Verbalized confidence only
prompt = "Answer with confidence"

# GOOD: Use logprobs when available
runner = BenchmarkRunner(use_logprobs=True)
```

### Pitfall 4: Temperature Too High

```python
# BAD: Temperature 1.0 (too random)
runner = BenchmarkRunner(temperature=1.0)

# GOOD: Temperature 0.3 (calibrated)
runner = BenchmarkRunner(temperature=0.3)
```

---

## 📈 Leaderboard Tiers (Approximate)

| Tier | Score Range | Description |
|------|-------------|-------------|
| Bronze | 0.0 - 0.2 | Random or slightly above random |
| Silver | 0.2 - 0.5 | Basic model, uncalibrated |
| Gold | 0.5 - 0.7 | Good model, some calibration |
| Platinum | 0.7 - 0.85 | Excellent model + calibration |
| Diamond | 0.85+ | Near-perfect calibration |

**Current top scores** (as of 2026-03):
- 🥇 0.82: Claude Opus 3 with logprobs + temp 0.3
- 🥈 0.79: GPT-4-turbo with calibration layer
- 🥉 0.75: Gemini Ultra with strategic uncertainty

---

## 🔬 Experimental Strategies

### Strategy: Self-Consistency

```python
def self_consistency(runner, item, n_samples: int = 5):
    """Sample multiple times, take majority vote."""
    answers = []
    for i in range(n_samples):
        result = runner.run_item(item, seed=i)
        answers.append(result.response)

    # Majority vote
    from collections import Counter
    majority = Counter(answers).most_common(1)[0][0]

    # Confidence = proportion agreeing
    confidence = answers.count(majority) / n_samples

    return majority, confidence
```

### Strategy: Ensembling

```python
def ensemble_providers(item):
    """Combine predictions from multiple providers."""
    providers = [Provider.ANTHROPIC, Provider.OPENAI, Provider.GOOGLE]

    results = []
    for provider in providers:
        result = runner.run_item(item, provider=provider)
        results.append(result)

    # Weight by provider calibration score
    weights = {
        Provider.ANTHROPIC: 0.5,  # Best calibration
        Provider.OPENAI: 0.3,
        Provider.GOOGLE: 0.2,
    }

    # Combine scores
    combined_score = sum(r.raw_score * weights[r.provider] for r in results)

    return combined_score
```

---

## 📚 Further Reading

- **Mielke et al. (2024)**: "Verbalized Confidence in LLMs" — Why 5% buckets work
- **Maniscalco et al. (2023)**: "meta-d' for metacognition" — Type II SDT
- **ARC-AGI-2 (2024)**: Pass@2 protocol — Measuring generalization
- **Fleming & Lau (2014)**: ECE metric — Calibration measurement

---

**Remember**: The goal isn't just accuracy — it's **calibrated accuracy**. A model that knows what it knows scores higher than a model that's always confident!
