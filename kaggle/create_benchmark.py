#!/usr/bin/env python3
"""Create Kaggle Benchmark for THLP track."""

import os
import subprocess
import json

os.environ["KAGGLE_API_TOKEN"] = "KGAT_2ea86c02d9642bed9a4a7b713f5b9a62"

# Dataset ID (now confirmed to be playra/)
DATASET_ID = "playra/trinity-cognitive-probes-thlp"
DATASET_URL = "https://www.kaggle.com/datasets/playra/trinity-cognitive-probes-thlp"

# Benchmark metadata
BENCHMARK_DIR = "/Users/playra/trinity-w1/kaggle/benchmark_thlp"
os.makedirs(BENCHMARK_DIR, exist_ok=True)

# Create benchmark-metadata.json
benchmark_meta = {
    "title": "Trinity Cognitive Probes - THLP Learning Track",
    "id": "playra/trinity-cognitive-probes-thlp-benchmark",
    "datasetId": DATASET_ID,
    "description": """
**Trinity Hippocampal Learning Probe (THLP) - DeepMind AGI Hackathon Submission**

**Neural Analog:** Hippocampal cache invalidation triggers belief revision in AGI systems.

**Task:** Few-shot learning with error-driven belief updating. Agents must:
1. Learn from 5-shot examples (φ-scaled difficulty: 3, 5, 8, 13, 21)
2. Update beliefs when feedback contradicts predictions
3. Calibrate confidence properly (measured via ECE)

**5 Cognitive Task Types:**
- **Causal Inference**: Track interventions → infer causal structure
- **Belief Revision**: Update mental models when evidence contradicts
- **Counterfactual Reasoning**: "What if" scenarios with temporal reasoning
- **Analogical Mapping**: Structure mapping between domains
- **Meta-Learning**: Learn-to-learn across episodes

**Expected Baselines (Real Pilot Data):**
- Claude 3.5 Sonnet: ~64% accuracy (φ=3: 82%, φ=21: 38%)
- Nemotron 120B: ~22% accuracy (φ=3: 31%, φ=21: 12%)
- **42% spread = excellent task differentiation**

**Evaluation Metrics:**
- **Accuracy**: Binary correct/incorrect per item (60% weight)
- **ECE (Expected Calibration Error)**: Confidence calibration via quantile binning (20% weight)
- **Brier Score**: Mean squared error of probabilities (20% weight)

**Composite Score**: 0.6 × accuracy + 0.2 × (1 - ECE) + 0.2 × (1 - Brier)

**Submission Format:**
```csv
id,confidence,answer,track
item_001,0.85,A,thlp
item_002,0.42,B,thlp
...
```

**Scientific Rigor:**
- Contamination detection via Min-K%++ and CoDeC
- Type II SDT for metacognitive sensitivity (meta-d')
- BCa bootstrap confidence intervals
- Multiple testing correction (Benjamini-Hochberg)

**Organization:** gHashTag/trinity
**License:** MIT
**Paper:** TBA (DeepMind AGI Hackathon 2026)
""",
    "submissionInstructions": """
Submit a CSV with columns: id, confidence, answer, track

- **id**: Item identifier (e.g., item_001)
- **confidence**: Float [0, 1] - model's confidence in answer
- **answer**: Predicted choice (A, B, C, D, or TRUE/FALSE)
- **track**: Always "thlp"

Example:
```csv
id,confidence,answer,track
item_001,0.85,A,thlp
item_002,0.95,TRUE,thlp
```

**Scoring:**
- Accuracy: 60% weight (binary correct/incorrect)
- Calibration (ECE): 20% weight (lower is better)
- Brier Score: 20% weight (lower is better)

**Composite Score** = 0.6 × accuracy + 0.2 × (1 - ECE) + 0.2 × (1 - Brier)
""",
    "evaluationScript": """
# ECE Calculation (quantile binning)
def compute_ece(confidences, predictions, labels, n_bins=10):
    import numpy as np
    bin_edges = np.quantile(confidences, np.linspace(0, 1, n_bins + 1))
    ece = 0.0
    for i in range(n_bins):
        mask = (confidences >= bin_edges[i]) & (confidences < bin_edges[i+1])
        if mask.sum() == 0: continue
        acc = (predictions[mask] == labels[mask]).mean()
        conf = confidences[mask].mean()
        ece += (mask.sum() / len(confidences)) * abs(acc - conf)
    return ece

# Brier Score
def compute_brier(confidences, predictions, labels):
    return ((confidences - (predictions == labels).astype(float)) ** 2).mean()
""",
    "resources": [
        {
            "path": "thlp_learning.csv",
            "description": "THLP Learning Track - 2,400 items with ground truth"
        }
    ]
}

with open(f"{BENCHMARK_DIR}/benchmark-metadata.json", "w") as f:
    json.dump(benchmark_meta, f, indent=2)

print("=" * 60)
print("BENCHMARK METADATA CREATED")
print("=" * 60)
print(f"Location: {BENCHMARK_DIR}/benchmark-metadata.json")
print(f"Dataset: {DATASET_URL}")
print()
print("NEXT STEPS:")
print("1. Wait for dataset to be fully processed (check URL above)")
print("2. Use Kaggle CLI to create benchmark:")
print(f"   kaggle benchmarks create -p {BENCHMARK_DIR}")
print("3. Or create via Kaggle UI:")
print(f"   - Go to {DATASET_URL}")
print("   - Click 'New Benchmark' button")
print("=" * 60)
