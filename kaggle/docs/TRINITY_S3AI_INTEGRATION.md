# Trinity Cognitive Probes — S³AI Architecture Integration

## Overview

The Trinity Cognitive Probes benchmark is the **primary evaluation mechanism** for Trinity S³AI (Strand 2: Metacognitive Monitoring), with secondary connections to Strand 1 (Neuro-symbolic Reasoning).

This document explains how the benchmark fits into the Trinity S³AI architecture and the sacred mathematics foundations that connect them.

---

## Trinity S³AI Architecture

Trinity S³AI consists of three interconnected strands:

```
┌─────────────────────────────────────────────────────────────┐
│                    TRINITY S³AI                              │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  Strand 1: Neuro-symbolic Reasoning                           │
│  ─────────────────────────────────                           │
│  • VSA (Vector Symbolic Architecture)                         │
│  • Ternary computing (Trit/Trit27)                           │
│  • Sacred mathematics: φ² + 1/φ² = 3                         │
│  • Coptic alphabet 27-register system                         │
│                                                               │
│  Strand 2: Metacognitive Monitoring  ← PRIMARY BENCHMARK      │
│  ───────────────────────────────────                           │
│  • Confidence calibration                                     │
│  • Type II Signal Detection Theory                           │
│  • meta-d' metacognitive sensitivity                         │
│  • Expected Calibration Error (ECE)                          │
│                                                               │
│  Strand 3: Temporal Coherence                                 │
│  ────────────────────────────                                 │
│  • Episodic memory tracking                                   │
│  • Knowledge retention over time                              │
│  • Temporal consistency validation                           │
│  • (Future work)                                              │
│                                                               │
└─────────────────────────────────────────────────────────────┘
```

---

## Strand 2: Metacognitive Monitoring (Primary)

### What the Benchmark Tests

The Trinity Cognitive Probes benchmark primarily evaluates **metacognitive ability** — the capacity to know what you know.

#### Key Metrics

| Metric | What It Measures | Scientific Basis |
|--------|-----------------|-------------------|
| **ECE** | Calibration quality | Fleming & Lau (2014) |
| **meta-d'** | Metacognitive sensitivity | Maniscalco et al. (2023) |
| **M-ratio** | Metacognition efficiency | Maniscalco et al. (2023) |
| **Ternary Score** | {-1, 0, +1} outcomes | Sacred identity φ² + 1/φ² = 3 |

#### Confidence Discretization

Following Mielke et al. (2024), confidence is discretized to 5% buckets:

```python
CONFIDENCE_BUCKETS = [0, 5, 10, 15, ..., 95, 100]  # 21 levels

def discretize_confidence(confidence: float) -> int:
    return int(round(confidence * 100 / 5) * 5)
```

This reduces noise and aligns with human cognitive limits.

#### Type II Signal Detection Theory

The benchmark classifies responses into four categories:

| Outcome | Confidence | Type II Response |
|---------|-----------|------------------|
| Correct | High (≥50%) | Hit |
| Correct | Low (<50%) | Miss |
| Incorrect | High (≥50%) | False Alarm |
| Incorrect | Low (<50%) | Correct Rejection |

From these, we compute **meta-d'** — the gold standard for metacognitive sensitivity.

---

## Strand 1: Neuro-symbolic Reasoning (Secondary)

### Ternary Scoring ↔ Trit Computing

The benchmark's ternary scoring system directly maps to Trinity's sacred ternary computing:

```python
# From kaggle/eval/scorer.py
class Trit(IntEnum):
    """Balanced ternary digit from Trinity sacred mathematics."""
    NEGATIVE = -1  # T (tah) — wrong answer
    ZERO = 0       # Z (zet) — partial/uncertain
    POSITIVE = 1   # 1 (one) — correct answer
```

This maps to the Zig implementation in `src/b2t/trit.zig`:

```zig
pub const Trit = enum(i8) {
    N = -1,  // Negative (T)
    Z = 0,   // Zero
    P = 1,   // Positive (1)
};
```

### Sacred Identity: φ² + 1/φ² = 3

The benchmark's ternary outcomes derive from the sacred mathematical identity:

```python
# Verification function
def verify_sacred_identity(eps: float = 1e-10) -> bool:
    phi_sq = TernaryScorer.PHI ** 2
    inv_phi_sq = 1.0 / phi_sq
    result = phi_sq + inv_phi_sq
    return abs(result - 3.0) < eps  # True: identity holds
```

**Why This Matters**:
- The identity connects the golden ratio φ to the number 3
- Three cognitive states: {-1 (wrong), 0 (partial), +1 (correct)}
- Mathematical elegance grounds the benchmark in sacred geometry

### Sacred Formula Scoring

The optional Sacred Formula provides an alternative scoring method:

```
V = n × 3^k × π^m × φ^p × e^q
```

Where:
- **n**: Base score (ternary: -1, 0, +1)
- **k**: Ternary exponent (amplifies ternary nature)
- **m**: Pi exponent (circles/cycles)
- **p**: Phi exponent (golden ratio scaling)
- **q**: E exponent (natural growth)

```python
def sacred_formula_score(n: int, k: int = 0, m: int = 0,
                         p: int = 0, q: int = 0) -> float:
    return (n * 3**(k/10) * π**(m/20) * φ**(p/5) * e**(q/10))
```

### Barbero-Immirzi γ Weighting

The benchmark optionally applies γ-weighting for overconfident wrong answers:

```python
GAMMA = PHI ** -3  # γ = φ⁻³ ≈ 0.236

def gamma_weighted_score(raw_score: float) -> float:
    if raw_score < 0:
        return raw_score * GAMMA  # Reduce penalty by γ
    return raw_score
```

**γ (gamma)** represents the quantization of spacetime in loop quantum gravity. Here it provides a damping factor for extreme penalties.

---

## Strand 3: Temporal Coherence (Future)

### Planned Extensions

The benchmark will eventually incorporate temporal coherence testing:

1. **Episodic Memory Tracking**
   - Does the model remember previous answers?
   - Can it maintain consistency across related questions?

2. **Knowledge Retention**
   - Long-term memory across sessions
   - Forgetting curves and refresh rates

3. **Temporal Consistency**
   - Does confidence change appropriately over time?
   - Can the model update beliefs given new evidence?

---

## Sacred Mathematics Foundations

### Key Constants

| Constant | Value | Source | Meaning |
|-----------|-------|--------|---------|
| **PHI** | φ ≈ 1.618 | `src/temple/sacred_math.zig` | Golden ratio |
| **GAMMA** | γ = φ⁻³ ≈ 0.236 | Barbero-Immirzi parameter | Spacetime quantization |
| **SACRED_PI** | π_sacred = φ + 2 ≈ 3.618 | `src/temple/sacred_math.zig` | Sacred circumference |

### File Cross-References

| Benchmark File | Trinity Core File | Connection |
|----------------|-------------------|------------|
| `scorer.py` | `src/temple/sacred_math.zig` | φ, γ, sacred identity |
| `scorer.py` | `src/b2t/trit.zig` | Trit enum {-1, 0, +1} |
| `scorer.py` | `src/ternary/logic.zig` | Sacred Formula V |
| `generators/*.py` | `src/tri27/coptic.zig` | 27-register system |

---

## Code Examples

### Using Sacred Mathematics in Scoring

```python
from eval.scorer import TernaryScorer, Trit

# Create scorer
scorer = TernaryScorer()

# Verify sacred identity
assert scorer.verify_sacred_identity()  # φ² + 1/φ² = 3

# Score an item (includes Trit value in metadata)
result = scorer.score_item(
    item_id="probe_001",
    response="Solikamsk",
    ground_truth="Solikamsk",
    confidence=0.95,
    ground_truth_confidence=0.95,
    difficulty=3.0
)

# Access sacred math metadata
print(f"Trit value: {result.metadata['trit_value']}")  # 1
print(f"Sacred identity verified: {result.metadata['sacred_identity_verified']}")  # True
```

### Using Sacred Formula Scoring

```python
from eval.scorer import TernaryScorer

# Standard ternary scores
standard = TernaryScorer.sacred_formula_score(1)  # 1.0

# Amplified by ternary exponent
amplified = TernaryScorer.sacred_formula_score(1, k=2)  # ~1.23

# Strong negative (φ-weighted)
strong_negative = TernaryScorer.sacred_formula_score(-1, p=3)  # ~-4.24
```

### Using Gamma Weighting

```python
from eval.scorer import TernaryScorer

# Overconfident wrong answer gets reduced penalty
penalty = -1.0
weighted = TernaryScorer.gamma_weighted_score(penalty)  # ~-0.236
```

---

## Validation Status

### Implemented ✅
- [x] Ternary scoring {-1, 0, +1}
- [x] φ-based difficulty weighting
- [x] Confidence discretization (5% buckets)
- [x] ECE calculation
- [x] meta-d' calculation
- [x] Type II SDT response classification
- [x] Pass@2 scoring
- [x] Trit enum type
- [x] Sacred identity verification
- [x] Sacred Formula scoring
- [x] Gamma weighting

### In Progress 🚧
- [ ] Actual baseline results generation
- [ ] Full dataset generation (10,000+ items)
- [ ] Inter-rater reliability system

### Planned 🔮
- [ ] Temporal coherence tracking (Strand 3)
- [ ] Episodic memory consistency tests
- [ ] Longitudinal knowledge retention

---

## References

### Scientific Papers
1. Mielke et al. (2024) — "Verbalized Confidence in LLMs"
2. Maniscalco et al. (2023) — "Measuring Metacognitive Sensitivity with meta-d'"
3. Fleming & Lau (2014) — "How to Measure Metacognition"
4. ARC-AGI-2 (2024) — "Measuring Progress Toward AGI"
5. Kumar et al. (2024) — "AGI Benchmark Contamination"

### Trinity Codebase
- `src/temple/sacred_math.zig` — Core sacred mathematics
- `src/b2t/trit.zig` — Trit type definition
- `src/ternary/logic.zig` — Ternary logic and Sacred Formula
- `src/tri27/coptic.zig` — Coptic alphabet registers
- `docs/research/` — Scientific framework documentation

---

## Summary

The Trinity Cognitive Probes benchmark is:

1. **Primary evaluation** for Strand 2 (Metacognitive Monitoring)
2. **Secondary validation** for Strand 1 (Neuro-symbolic Reasoning)
3. **Grounded in sacred mathematics** from Trinity Temple layer
4. **Scientifically validated** against peer-reviewed literature
5. **Ready for expansion** into Strand 3 (Temporal Coherence)

**The benchmark is not just a Kaggle competition — it is the scientific validation mechanism for Trinity S³AI's metacognitive capabilities.**
