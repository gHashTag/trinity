# Frequently Asked Questions — Trinity Cognitive Probes

## General Questions

### Q: What makes this benchmark different from others?

**A:** Trinity Cognitive Probes measures BOTH correctness AND metacognition. While other benchmarks only track accuracy, we track:
- **Confidence calibration**: Does the model know what it knows?
- **Metacognitive sensitivity** (meta-d'): Type II signal detection theory
- **Appropriate uncertainty**: Rewarding "I don't know" responses

### Q: Why is ternary scoring {-1, 0, +1} instead of binary?

**A:** Real cognition isn't binary. The three outcomes capture:
- **+1**: Correct with appropriate confidence (well-calibrated)
- **0**: Partially correct OR appropriately uncertain (knowing limits)
- **-1**: Wrong OR overconfident (hallucinating)

Models that game the system by always being confident score LOWER.

---

## Scoring Questions

### Q: Why is my score so low?

**A:** Check your confidence calibration! Common issues:

| Problem | Symptom | Fix |
|---------|---------|-----|
| Overconfident wrong answers | Many -1 scores | Lower confidence on uncertain items |
| Underconfident correct answers | Low φ-weighted score | Increase confidence on high-certainty items |
| Poor calibration | High ECE (>0.15) | Use temperature scaling or calibration layer |

### Q: What's the difference between +1, 0, -1 scores?

**A:**
- **+1**: Correct answer AND confidence is well-calibrated
- **0**: Partially correct, OR confidence expresses appropriate uncertainty
- **-1**: Wrong answer, OR overconfident wrong answer (worst outcome)

### Q: How do I interpret the φ-scaled difficulty?

**A:** Items are weighted by difficulty. Hard items (φ≈21) count ~7x more than easy items (φ≈3). This rewards models that can handle difficult reasoning, not just memorize facts.

**Note**: φ-scaling is NOT empirically validated. For scientific benchmarking, use human-validated difficulty (see ARC-AGI-2).

### Q: What is ECE (Expected Calibration Error)?

**A:** ECE measures the difference between predicted confidence and actual accuracy. Lower ECE = better calibration.

- **ECE < 0.05**: Excellent calibration
- **ECE 0.05-0.15**: Good calibration
- **ECE > 0.15**: Poor calibration (model is over/under confident)

### Q: What is meta-d'?

**A:** meta-d' (meta-d-prime) measures **metacognitive sensitivity** — how well the model can distinguish between what it knows and what it doesn't. This is the GOLD STANDARD metric from cognitive science (Maniscalco et al., 2023).

- **meta-d' > 1.0**: Good metacognition
- **meta-d' ≈ 0.5**: Chance-level metacognition
- **meta-d' < 0**: Worse than random

---

## Technical Questions

### Q: Can I use multiple API providers?

**A:** Yes! Use `BenchmarkRunner(api_provider="auto")` for automatic fallback:
- OpenAI (GPT-4, GPT-4-turbo)
- Anthropic (Claude Opus, Claude Sonnet)
- Google (Gemini Pro/Ultra)
- Local models (via LiteLLM)

### Q: How do I use logprob-based confidence?

**A:** Set `use_logprobs=True` when creating the runner:

```python
from kaggle.eval import BenchmarkRunner

runner = BenchmarkRunner(
    api_provider="anthropic",
    use_logprobs=True  # Use Claude's logprobs for better confidence
)
```

Logprob-based confidence is MORE reliable than verbalized confidence (Mielke et al., 2024).

### Q: Why use 0-20 confidence scale instead of 0-100?

**A:** Scientific research (Mielke et al., 2024) shows LLMs can't reliably express 95% vs 90% vs 85% confidence. 5% buckets (21 total) are the sweet spot for calibration.

Your confidence will be automatically discretized:

```python
# Continuous 0-100 (noisy)
confidence = 0.73  # Is this 73%? 75%? 70%?

# Discretized 0-20 (scientific)
confidence_discrete = 75  # Rounded to nearest 5%
confidence_bucket = 15    # Bucket 0-20
```

### Q: What is Pass@2 scoring?

**A:** Pass@2 (from ARC-AGI-2) measures generalization. Each item is attempted twice with different seeds. Score = 1.0 if EITHER attempt is correct.

This rewards models that can generalize, not just memorize.

---

## Strategy Questions

### Q: What's the best strategy for high scores?

**A:** Top performers use:

1. **Logprob-based confidence** when available (Claude, GPT-4)
2. **Temperature 0.2-0.4** for more deterministic confidence
3. **Strategic uncertainty**: Use confidence 0.4-0.6 for hard items
4. **Provider fallback**: Auto-switch on rate limits
5. **Calibration layer**: Post-hoc temperature scaling

### Q: Should I use high or low temperature?

**A:** For metacognition benchmarks:

| Temperature | Effect |
|-------------|--------|
| 0.0-0.2 | Best calibration, but may be underconfident |
| 0.3-0.5 | Sweet spot for most models |
| 0.7-1.0 | More diverse outputs, but calibration suffers |
| >1.0 | Not recommended for calibration |

### Q: How do I handle rate limits?

**A:** The runner has automatic retry with exponential backoff. For large runs, consider:
- Using multiple API keys (rotate them)
- Running overnight when limits reset
- Using batch processing where available

---

## Dataset Questions

### Q: How many items are in each track?

**A:**
| Track | Items | Tasks |
|-------|-------|-------|
| Learning (THLP) | 2,400 | 5 |
| Metacognition (TMP) | 2,200 | 5 |
| Attention (TAGP) | 2,200 | 5 |
| Executive (TEFB) | 2,400 | 5 |
| Social (TSCP) | 2,200 | 5 |
| **TOTAL** | **11,400** | **25** |

### Q: What languages are supported?

**A:** Currently supported:
- **EN** (English): Full coverage
- **ES** (Spanish): Metacognition track
- **ZH** (Chinese): Metacognition track
- **AR** (Arabic): Coming soon
- **RU** (Russian): Coming soon

**Note**: Non-English translations are for cross-lingual transfer testing, not just translation. They measure whether models trained on English can transfer reasoning to other languages.

### Q: Are the questions contaminated from training data?

**A:** We run contamination detection using:
- N-gram overlap detection
- Semantic similarity (embeddings)
- Known benchmark cross-check
- Temporal holdout validation

**Caveat**: Fact-based questions (capitals, presidents, etc.) are DEFINITELY in GPT-4/Claude's training data. These test retrieval, not reasoning.

---

## Evaluation Questions

### Q: How long does a full evaluation take?

**A:** Approximate times (varies by API):

| Track | Items | ~Time (per provider) |
|-------|-------|---------------------|
| Learning | 2,400 | ~30-60 min |
| Metacognition | 2,200 | ~30-60 min |
| Attention | 2,200 | ~30-60 min |
| Executive | 2,400 | ~30-60 min |
| Social | 2,200 | ~30-60 min |
| **Full benchmark** | **11,400** | **~3-5 hours** |

### Q: Can I run just one track?

**A:** Yes! Use the `--track` flag:

```bash
python -m kaggle.eval.runner --track tmp  # Metacognition only
python -m kaggle.eval.runner --track thlp # Learning only
```

### Q: How do I resume from a checkpoint?

**A:** The runner auto-saves checkpoints every 10 items:

```bash
python -m kaggle.eval.runner --resume-from .benchmark_checkpoint.json
```

---

## Common Pitfalls

### Q: Why do I get "confidence not found" warnings?

**A:** The model isn't outputting confidence in the expected format. Ensure prompts include:

```
Answer: [your answer]
Confidence: [0.0 to 1.0]
```

Or use `use_logprobs=True` for providers that support it.

### Q: Why are my scores different each run?

**A:** Several factors:
- **Temperature non-determinism**: Use T=0 for reproducibility
- **API sampling**: Some providers sample even at low T
- **Network latency**: Affects timeout behavior
- **Provider model updates**: Models change over time

For reproducible results, set `seed` and `temperature=0`.

### Q: Can I use this for commercial purposes?

**A:** The dataset is MIT-licensed. However:
- Cite the dataset if you use it
- Results are for research/evaluation, not training data
- See LICENSE file for full terms

---

## Still Have Questions?

- **GitHub Issues**: https://github.com/gHashTag/trinity/issues
- **Documentation**: See `docs/` directory
- **Paper**: Coming soon with full scientific validation
