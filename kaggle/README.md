# Trinity Cognitive Probes for DeepMind AGI Hackathon

**Competition**: Google DeepMind AGI Hackathon — Measuring Progress Toward AGI
**Deadline**: April 16, 2026
**Prize**: $200,000 ($10K per track winner, $25K Grand Prize)

---

## Quick Start

```bash
# Install Kaggle SDK
pip install kaggle-benchmarks

# Generate dataset (example: Track 2)
python kaggle/generators/gen_tmp.py

# Open notebook
jupyter notebook kaggle/notebooks/track2_metacognition/task06_confidence_calib.ipynb

# Run all cells to test
# Uncomment submission cell to submit
```

---

## Project Structure

```
kaggle/
├── generators/          # Python dataset generators (12K+ items)
│   ├── gen_tmp.py      # Track 2: Metacognition ⭐
│   ├── gen_thlp.py      # Track 1: Learning
│   ├── gen_tagp.py      # Track 3: Attention
│   ├── gen_tefb.py      # Track 4: Executive Functions
│   └── gen_tscp.py      # Track 5: Social Cognition
├── notebooks/            # Kaggle notebooks (25 total)
│   ├── track1_learning/   # 5 notebooks
│   ├── track2_metacognition/ # ⭐ 5 notebooks
│   ├── track3_attention/   # 5 notebooks
│   ├── track4_executive/   # 5 notebooks
│   └── track5_social/      # 5 notebooks
└── writeups/            # Scientific writeups (1500 words each)
    ├── track1_learning.md
    ├── track2_metacognition.md
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

Each benchmark maps to **implemented Trinity brain zones**:

| Track | Brain Zone | Zig File | Function |
|-------|-----------|----------|---------|
| Learning | Hippocampus | `src/tri/brain/hippocampus_training.zig` | Episodic memory |
| Metacognition | ACC | `src/tri/brain/anterior_cingulate.zig` | Conflict detection |
| Metacognition | OFC | `src/storm/zones/ofc.zig` | 5D toxic scoring |
| Attention | Thalamus | `src/tri/brain/thalamus_logs.zig` | Gating/filtering |
| Executive | DLPFC | `src/brain/prefrontal_cortex.zig` | Working memory |
| Social | TheoryOfMind | `src/consciousness/awareness/self_model.zig` | Perspective taking |

---

## Key Innovations

### 1. Ternary Scoring {-1, 0, +1}

```python
def ternary_outcome(confidence, ground_truth):
    if abs(confidence - ground_truth) <= 0.2:
        return +1  # Calibrated
    elif 0.2 < confidence < 0.8:
        return 0   # Appropriately uncertain
    else:
        return -1  # Overconfident or wrong
```

### 2. φ-Scaling (Fibonacci)

```python
PHI = (1 + sqrt(5)) / 2  # ≈ 1.618
FIBONACCI = [3, 5, 8, 13, 21]

def calculate_phi_score(level_idx):
    return FIBONACCI[level_idx] * PHI ** (level_idx / 5)
```

### 3. Neuroanatomical Tagging

Each test item includes `brain_zone` and `neural_analog` fields linking to Trinity implementation.

---

## Expected Outcomes

| Prize | Requirement | Probability |
|-------|------------|-------------|-------------|
| Track winner ($10K) | Top-2 in individual track | High |
| Grand Prize ($25K) | Top-2 in ≥ 4 tracks | Medium |

---

## Development Status

- ✅ **Track 2 (Metacognition)**: All ready
- ⏳ **Tracks 1, 3, 4, 5**: Generator pattern defined, notebooks TODO
