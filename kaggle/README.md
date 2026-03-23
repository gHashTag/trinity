# Trinity Cognitive Probes for DeepMind AGI Hackathon

**Competition**: Google DeepMind AGI Hackathon — Measuring Progress Toward AGI
**Deadline**: April 16, 2026
**Prize**: $200,000 ($10K per track winner, $25K Grand Prize)

---

## Quick Start

```bash
# 1. Install Kaggle Benchmarks SDK
pip install kaggle-benchmarks

# 2. Generate dataset for a track
python kaggle/generators/gen_tmp.py --output data/tmp_metacognition.csv

# 3. Open notebook for the track
jupyter notebook kaggle/notebooks/track2_metacognition/task06_confidence_calib.ipynb

# 4. Run all cells to test

# 5. Uncomment submission cell and run to submit to leaderboard
```

---

## Project Structure

```
kaggle/
├── generators/                    # Python dataset generators (12K+ items)
│   ├── gen_tmp.py            # Track 2: Metacognition ⭐ Start here
│   ├── gen_thlp.py           # Track 1: Learning
│   ├── gen_tagp.py           # Track 3: Attention
│   ├── gen_tefb.py           # Track 4: Executive Functions
│   └── gen_tscp.py           # Track 5: Social Cognition
├── notebooks/                    # Kaggle submission notebooks (25 total)
│   ├── track1_learning/
│   ├── track2_metacognition/    # ⭐ First working example
│   ├── track3_attention/
│   ├── track4_executive/
│   └── track5_social/
└── writeups/                     # Scientific writeups (1500 words each)
    ├── track1_learning.md
    ├── track2_metacognition.md    # ⭐ First ready
    ├── track3_attention.md
    ├── track4_executive.md
    └── track5_social.md
```

---

## 5 Tracks × 5 Tasks = 25 Benchmarks

| Track | Tasks | Brain Zones | Status |
|-------|--------|------------|--------|
| **1. Learning** (THLP) | 5 | Hippocampus + Amygdala + ACCumbens | TODO |
| **2. Metacognition** (TMP) ⭐ | 5 | ACC + OFC + HABENULA + INSULA | ✅ Ready |
| **3. Attention** (TAGP) | 5 | Thalamus + Colliculus + Coeruleus | TODO |
| **4. Executive** (TEFB) | 5 | Cortex + DLPFC + Pallidus + Striatum | TODO |
| **5. Social** (TSCP) | 5 | Insula + OFC + HABENULA + TheoryOfMind | TODO |

---

## Trinity Neuroanatomical Foundation

Each benchmark maps to **implemented Trinity brain zones** (5 years of development):

| Track | Brain Zone | Zig File | Function |
|-------|-----------|----------|----------|
| Learning | Hippocampus | `src/tri/brain/hippocampus_training.zig` | Episodic memory |
| Metacognition | ACC | `src/tri/brain/anterior_cingulate.zig` | Conflict detection |
| Metacognition | OFC | `src/storm/zones/ofc.zig` | 5-dimensional toxic scoring |
| Metacognition | HABENULA | `src/storm/zones/habenula.zig` | Fairness detection |
| Metacognition | INSULA | `src/tri/brain/insula_system.zig` | Interoception |
| Attention | Thalamus | `src/tri/brain/thalamus_logs.zig` | Gating/filtering |
| Executive | DLPFC | `src/brain/prefrontal_cortex.zig` | Working memory |
| Executive | Striatum | Experience Engine | Pattern adaptation |
| Social | TheoryOfMind | `src/consciousness/awareness/self_model.zig` | Perspective taking |

---

## Key Innovations

### 1. Ternary Scoring {-1, 0, +1}

Binary benchmarks miss the middle ground: uncertain responses are forced into "wrong". Trinity adds a third value:

```python
# Trinity unique (not found in other benchmarks)
def ternary_outcome(confidence, ground_truth):
    if abs(confidence - ground_truth) <= 0.2:
        return +1  # Calibrated
    elif 0.2 < confidence < 0.8:
        return 0   # Appropriately uncertain
    else:
        return -1  # Overconfident or wrong
```

### 2. φ-Scaling (Fibonacci Complexity)

Complexity follows sacred mathematics: **φ² + 1/φ² = 3**

```python
PHI = (1 + sqrt(5)) / 2  # ≈ 1.618 (golden ratio)
FIBONACCI = [3, 5, 8, 13, 21]

difficulty = FIBONACCI[level] * PHI ** (level / 5)
```

### 3. Neuroanatomical Tagging

Each test item includes `brain_zone` and `neural_analog` fields linking to Trinity implementation.

---

## Kaggle SDK Patterns

### Task Definition

```python
import kaggle_benchmarks as kbench

@kbench.task(name="trinity_ofc_confidence")
def confidence_calibration(
    llm: kbench.LLM,
    question: str,
    expected_answer: str,
    ground_truth_confidence: float
) -> float:
    # Prompt model with structured output
    response = llm.prompt(
        "Answer and provide your confidence (0.0-1.0).",
        schema=ConfidenceResponse
    )

    # Calculate score using Trinity ternary logic
    score = ternary_outcome(
        response.confidence,
        ground_truth_confidence,
        response.answer == expected_answer
    )

    return score
```

### Evaluation

```python
# Load generated dataset (12K+ items)
df = pd.read_csv('data/tmp_metacognition.csv')

# Evaluate on LLM
results = confidence_calibration.evaluate(
    llm=[kbench.llm],  # Default test LLM
    evaluation_data=df
)

# Results include score, ternary_outcome, calibration_error
print(results.head())
```

### Submission

```python
# Submit to Kaggle leaderboard
kbench.submit(
    task=confidence_calibration,
    results=results,
    message="Trinity OFC Confidence Calibration v1.0"
)
```

---

## Expected Outcomes

| Prize | Requirement | Probability |
|-------|------------|-------------|
| Track winner ($10K) | Top-2 in individual track | **High** |
| Grand Prize ($25K) | Top-2 in ≥ 4 tracks | **Medium** |

**Strategic advantage**: Unified "Cognitive Connectome" across 5 tracks with shared neuroanatomical theory.

---

## Development Status

- ✅ **Track 2 (Metacognition)**: Generator + Notebook + Writeup ready
- ⏳ **Track 1 (Learning)**: Generator pattern defined
- ⏳ **Track 3 (Attention)**: Generator pattern defined
- ⏳ **Track 4 (Executive)**: Generator pattern defined
- ⏳ **Track 5 (Social)**: Generator pattern defined

---

## Links

- [DeepMind Blog](https://blog.google/innovation-and-ai/models-and-research/google-deepmind/measuring-agi-cognitive-framework/)
- [Kaggle Competition](https://www.kaggle.com/competitions)
- [Trinity Repository](https://github.com/gHashTag/trinity)
- [Trinity OFC Implementation](../../src/storm/zones/ofc.zig)
