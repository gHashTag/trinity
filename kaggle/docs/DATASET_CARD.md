# Trinity Cognitive Probes Dataset

## Overview

**Trinity Cognitive Probes** is a comprehensive AGI benchmark dataset mapping cognitive tasks to implemented brain zones in the Trinity S³AI architecture. Created for the Google DeepMind AGI Hackathon 2026.

### Key Features

- **5 Cognitive Tracks**: Learning, Metacognition, Attention, Executive Functions, Social Cognition
- **25 Benchmark Tasks**: 5 tasks per track
- **12,000+ Test Items**: Comprehensive coverage across difficulty levels
- **Ternary Scoring**: {-1, 0, +1} outcomes capturing correctness and uncertainty
- **φ-Scaling**: Fibonacci-based difficulty gradient (3, 5, 8, 13, 21)
- **Neuroanatomical Mapping**: Each task links to actual Trinity brain zone implementations

## Dataset Structure

```
kaggle/
├── data/                           # Generated CSV files
│   ├── thlp_learning.csv           # Track 1: 2,400 items
│   ├── tmp_metacognition.csv       # Track 2: 2,200 items
│   ├── tagp_attention.csv          # Track 3: 2,200 items
│   ├── tefb_executive.csv          # Track 4: 2,400 items
│   └── tscp_social.csv             # Track 5: 2,200 items
├── questions/                      # Question template banks
│   ├── learning.json               # 100+ learning question templates
│   └── metacognition.json          # 100+ metacognition question templates
└── writeups/                       # Scientific documentation
    ├── track1_learning.md
    ├── track2_metacognition.md
    ├── track3_attention.md
    ├── track4_executive.md
    └── track5_social.md
```

## Tracks

### 1. Hippocampal Learning Probe (THLP)
**Brain Zones**: Hippocampus, Amygdala, ACCumbens

**Tasks**:
- Few-Shot Rule Induction
- Belief Update Under Correction
- Error-Driven Learning
- Reward-Signal Learning
- Long-Context Retention

### 2. Trinity Metacognition Probe (TMP)
**Brain Zones**: ACC, OFC, HABENULA, INSULA

**Tasks**:
- Confidence Calibration
- Error Self-Detection
- Strategic Adaptation
- Knowledge Boundary
- Monitoring Under Load

### 3. Attentional Gateway Probe (TAGP)
**Brain Zones**: Thalamus, Colliculus, COERULEUS, RETICULAR

**Tasks**:
- Selective Filtering
- Sustained Attention
- Attention Shifting
- Adversarial Needle
- Divided Attention

### 4. Executive Function Battery (TEFB)
**Brain Zones**: CORTEX, DLPFC, PALLIDUS, STRIATUM, NIGRA

**Tasks**:
- Multi-Step Planning
- Stroop-like Inhibition
- Wisconsin Card Sort
- Working Memory Span
- Conflicting Instructions

### 5. Social Cognition Probe (TSCP)
**Brain Zones**: INSULA, OFC, HABENULA, THEORYOFMIND

**Tasks**:
- Theory of Mind (False Belief)
- Pragmatic Inference
- Audience Adaptation
- Negotiation
- Social Norms

## Scoring

### Ternary Scoring System

The dataset uses a ternary scoring system:

```
+1: Correct answer with appropriate confidence
 0: Partially correct or appropriate uncertainty
-1: Incorrect answer or overconfident wrong answer
```

### φ-Scaling

Difficulty follows Fibonacci-based φ-scaling:

```python
PHI = (1 + sqrt(5)) / 2 ≈ 1.618
FIBONACCI = [3, 5, 8, 13, 21]

difficulty = FIBONACCI[level] * PHI^(level/5)
```

### Final Score

Final score for leaderboard = φ-weighted mean score across all items.

## Usage

### Evaluation

```python
from kaggle.eval import BenchmarkRunner

# Run all benchmarks
runner = BenchmarkRunner()
results = runner.run_all()

# Save submission
runner.save_submission(results, "submission.csv")
```

### Generating New Items

```python
from kaggle.generators import gen_tmp

# Generate metacognition probe items
items = gen_tmp.generate_items(target_count=2200)
gen_tmp.write_csv(items, "data/tmp_metacognition.csv")
```

## Citation

```bibtex
@dataset{trinity_cognitive_probes_2026,
  title={Trinity Cognitive Probes: A Neuroanatomically-Grounded AGI Benchmark},
  author={Trinity S³AI Team},
  year={2026},
  publisher={Kaggle},
  url={https://www.kaggle.com/datasets/playra/trinity-cognitive-probes}
}
```

## License

MIT License - See LICENSE file for details.

## Contact

For questions about the dataset, please open an issue on GitHub:
https://github.com/gHashTag/trinity

## Acknowledgments

Created for the Google DeepMind AGI Hackathon 2026.

Built on Trinity S³AI - Pure Zig autonomous AI agent swarm.
https://github.com/gHashTag/trinity
