# Chapter 7: Trinity Neural — Three Decisions of the Mind

---

*"Three times the old man cast his net into the sea:*
*the first time — empty, the second time — seaweed,*
*the third time — a golden fish."*
— Alexander Pushkin, "The Tale of the Fisherman and the Fish"

---

## Three Attempts of the Neural Network

Just as the old man cast his net three times, so does a neural network make decisions in three stages:

```
┌─────────────────────────────────────────────────────────┐
│                                                         │
│   THREE DECISIONS OF THE NEURAL NETWORK                │
│                                                         │
│   FIRST CAST       SECOND CAST       THIRD CAST        │
│   ──────────       ───────────       ──────────        │
│   REJECT           DEFER             ACCEPT            │
│   (Decline)        (Postpone)        (Accept)          │
│                                                         │
│   Confident: NO    Uncertain         Confident: YES    │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---

## Three-Way Decision: Three Decisions

### The Problem of Binary Classification

```
Standard classification:
  if P(A|x) > 0.5:
      return "YES"
  else:
      return "NO"

Problem: what if P(A|x) = 0.51?
  We say "YES" with 51% confidence!
  This is almost random guessing.
```

### Solution: Three Zones

```
┌─────────────────────────────────────────────────────────┐
│                                                         │
│   THREE-WAY DECISION (Yao, 2010)                       │
│                                                         │
│   0.0 ──────── β ──────── α ──────── 1.0               │
│        REJECT     DEFER      ACCEPT                    │
│                                                         │
│   P(A|x) ≤ β  →  REJECT  (confident: NO)              │
│   P(A|x) ≥ α  →  ACCEPT  (confident: YES)             │
│   β < P(A|x) < α  →  DEFER  (uncertain)               │
│                                                         │
│   Typical values: α = 0.7, β = 0.3                     │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### Code

```python
def three_way_classify(probability, alpha=0.7, beta=0.3):
    """
    Three-way classification decisions

    Like three casts of the net:
    - First (REJECT): empty, confident it's no
    - Second (DEFER): seaweed, uncertain
    - Third (ACCEPT): golden fish!
    """
    if probability >= alpha:
        return "ACCEPT"   # Third cast — success!
    elif probability <= beta:
        return "REJECT"   # First cast — empty
    else:
        return "DEFER"    # Second cast — need another try
```

### Applications

```
┌─────────────────────────────────────────────────────────┐
│                                                         │
│   APPLICATION EXAMPLES                                 │
│                                                         │
│   MEDICINE:                                            │
│   • ACCEPT: Diagnosis confirmed, proceed with treatment│
│   • REJECT: Diagnosis excluded, patient is healthy    │
│   • DEFER: Additional tests required                  │
│                                                         │
│   CONTENT MODERATION:                                  │
│   • ACCEPT: Content is safe, publish                  │
│   • REJECT: Content is dangerous, remove              │
│   • DEFER: Send for manual review                     │
│                                                         │
│   CREDIT SCORING:                                      │
│   • ACCEPT: Approve the loan                          │
│   • REJECT: Decline                                   │
│   • DEFER: Request additional documents               │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---

## Ternary Weight Networks: Three Weights

### The Idea

Instead of 32-bit float weights, we use only **three values**: {-1, 0, +1}

```
┌─────────────────────────────────────────────────────────┐
│                                                         │
│   TERNARY WEIGHTS: THREE BOGATYRS OF WEIGHTS          │
│                                                         │
│   -1              0               +1                    │
│   ──              ─               ──                    │
│   Negative        Neutral         Positive             │
│   contribution    (disabled)      contribution         │
│                                                         │
│   ADVANTAGES:                                          │
│   • 2 bits instead of 32 → 16x less memory            │
│   • Multiplication → addition/subtraction             │
│   • Faster on specialized hardware                    │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### Quantization

```python
def ternarize_weights(weights):
    """
    Convert float weights to ternary {-1, 0, +1}

    Like the miller's three sons:
    - Eldest (+1): large positive weights
    - Middle (0): small weights (disabled)
    - Youngest (-1): large negative weights
    """
    # Threshold = 0.7 × mean absolute value
    mean_abs = sum(abs(w) for w in weights) / len(weights)
    threshold = 0.7 * mean_abs

    ternary = []
    for w in weights:
        if w > threshold:
            ternary.append(1)    # Eldest son
        elif w < -threshold:
            ternary.append(-1)   # Youngest son
        else:
            ternary.append(0)    # Middle son

    # Scaling coefficient
    non_zero = [abs(w) for w, t in zip(weights, ternary) if t != 0]
    scale = sum(non_zero) / len(non_zero) if non_zero else 1.0

    return ternary, scale
```

### Results

```
┌─────────────────────────────────────────────────────────┐
│                                                         │
│   COMPARISON: FLOAT vs TERNARY                         │
│                                                         │
│   Metric          Float32     Ternary     Difference   │
│   ─────────────────────────────────────────────────    │
│   Memory          32 bits     2 bits      16x ↓        │
│   Multiplication  FP MUL      ADD/SUB     10x ↓        │
│   Accuracy        100%        ~95%        5% ↓         │
│   Energy          100%        ~10%        10x ↓        │
│                                                         │
│   CONCLUSION: 5% accuracy loss for 16x memory savings  │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### Ternary Matrix Multiplication

```python
def ternary_matmul(weights, x, scale):
    """
    Matrix multiplication with ternary weights

    Instead of: result[i] = sum(w[i][j] * x[j])
    We do:      result[i] = sum(x[j] if w=+1 else -x[j] if w=-1 else 0)

    No multiplications! Only additions and subtractions.
    """
    result = []
    for row in weights:
        total = 0.0
        for w, xi in zip(row, x):
            if w == 1:
                total += xi      # Eldest son adds
            elif w == -1:
                total -= xi      # Youngest son subtracts
            # w == 0: middle son stays silent
        result.append(total * scale)
    return result
```

---

## Ternary Activation: Three States of the Neuron

### Standard Activations

```
ReLU:    max(0, x)           — 2 states (0 or +)
Sigmoid: 1/(1+e^-x)          — continuous [0, 1]
Tanh:    (e^x-e^-x)/(e^x+e^-x) — continuous [-1, 1]
```

### Ternary Activation

```python
def hard_ternary(x, threshold=0.5):
    """
    Hard ternary activation: {-1, 0, +1}

    Like three roads:
    - x > threshold  → +1 (go right)
    - x < -threshold → -1 (go left)
    - otherwise      → 0  (straight/stop)
    """
    if x > threshold:
        return 1
    elif x < -threshold:
        return -1
    return 0

def soft_ternary(x, k=5.0):
    """
    Soft ternary activation (differentiable)

    Approximation of hard_ternary for training
    """
    import math
    return math.tanh(k * (x - 0.5)) / 2 + math.tanh(k * (x + 0.5)) / 2

def leaky_ternary(x, alpha=0.1):
    """
    Leaky ternary: 3 linear regions

    Like three kingdoms:
    - x > 1:  1 + α(x-1)   (beyond the border)
    - x < -1: -1 + α(x+1)  (beyond the border)
    - otherwise: x         (within the kingdom)
    """
    if x > 1:
        return 1 + alpha * (x - 1)
    elif x < -1:
        return -1 + alpha * (x + 1)
    return x
```

### Comparison

```
┌─────────┬─────────┬─────────────┬─────────────┬─────────────┐
│ x       │ ReLU    │ Hard Tern   │ Soft Tern   │ Leaky Tern  │
├─────────┼─────────┼─────────────┼─────────────┼─────────────┤
│ -2.0    │ 0.00    │ -1          │ -1.000      │ -1.100      │
│ -1.0    │ 0.00    │ -1          │ -0.993      │ -1.000      │
│ -0.5    │ 0.00    │ 0           │ -0.500      │ -0.500      │
│ 0.0     │ 0.00    │ 0           │ 0.000       │ 0.000       │
│ 0.5     │ 0.50    │ 0           │ 0.500       │ 0.500       │
│ 1.0     │ 1.00    │ 1           │ 0.993       │ 1.000       │
│ 2.0     │ 2.00    │ 1           │ 1.000       │ 1.100       │
└─────────┴─────────┴─────────────┴─────────────┴─────────────┘
```

---

## Edge of Chaos: Critical Initialization

### Three States of the Network

```
┌─────────────────────────────────────────────────────────┐
│                                                         │
│   THREE STATES OF THE NEURAL NETWORK                   │
│                                                         │
│   DECAY              CRITICALITY        EXPLOSION      │
│   ─────              ───────────        ─────────      │
│   σ² < 1             σ² = 1             σ² > 1         │
│                                                         │
│   Signal             Signal             Signal         │
│   vanishes           is preserved       explodes       │
│                                                         │
│   Does not learn     LEARNS!            Does not learn │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### Criticality Condition

```
σ_w² × σ_b² = 1

Where:
  σ_w² = variance of weights
  σ_b² = variance of activations (≈1 for tanh)

For tanh: σ_w² = 1/n_in  (Xavier initialization)
For ReLU: σ_w² = 2/n_in  (He initialization)
```

### Experiment

```python
def simulate_signal(n_layers, width, sigma_w):
    """Simulate signal propagation"""
    import random
    import math

    # Initial signal
    signal = [random.gauss(0, 1) for _ in range(width)]

    for _ in range(n_layers):
        new_signal = []
        for _ in range(width):
            z = sum(random.gauss(0, sigma_w) * s for s in signal) / math.sqrt(width)
            new_signal.append(math.tanh(z))
        signal = new_signal

    # Signal norm
    return math.sqrt(sum(s**2 for s in signal) / width)

# Results (10 layers, width 100)
# σ_w = 0.5: norm → 0.0007 (DECAY)
# σ_w = 0.8: norm → 0.0408 (DECAY)
# σ_w = 1.0: norm → 0.2424 (CRITICALITY) ✓
# σ_w = 1.2: norm → 0.4568 (CRITICALITY) ✓
# σ_w = 1.5: norm → 0.5912 (CRITICALITY) ✓
```

---

## Trinity Perceptron: Three Outputs

### The Idea

```
┌─────────────────────────────────────────────────────────┐
│                                                         │
│   STANDARD PERCEPTRON                                  │
│   y = sign(w·x + b) → {-1, +1}                         │
│                                                         │
│   TRINITY PERCEPTRON                                   │
│   y = ternary(w·x + b) → {-1, 0, +1}                   │
│                                                         │
│   Third output (0) = "don't know" / "neutral"          │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### Code

```python
class TrinityPerceptron:
    """
    Perceptron with three outputs

    Like three roads:
    - +1: confident in positive class
    - -1: confident in negative class
    - 0:  uncertain / neutral
    """

    def __init__(self, n_features, threshold=0.5):
        import random
        self.weights = [random.gauss(0, 0.1) for _ in range(n_features)]
        self.bias = 0.0
        self.threshold = threshold

    def predict(self, x):
        z = sum(w * xi for w, xi in zip(self.weights, x)) + self.bias

        if z > self.threshold:
            return 1    # Right — positive
        elif z < -self.threshold:
            return -1   # Left — negative
        return 0        # Straight — neutral

    def train(self, X, y, epochs=100, lr=0.1):
        for _ in range(epochs):
            for xi, yi in zip(X, y):
                pred = self.predict(xi)
                error = yi - pred

                for j in range(len(self.weights)):
                    self.weights[j] += lr * error * xi[j]
                self.bias += lr * error
```

---

## Summary: The Number 3 in Neural Networks

```
┌─────────────────────────────────────────────────────────┐
│                                                         │
│   THE NUMBER 3 IN NEURAL NETWORKS                      │
│                                                         │
│   CONCEPT            APPLICATION                       │
│   ─────────────────────────────────────────────────    │
│   3-way decision     Accept / Reject / Defer          │
│   Ternary weights    {-1, 0, +1} → 16x less memory    │
│   Ternary activation 3 activation regions             │
│   Edge of chaos      3 states: decay/crit./explosion  │
│   Trinity perceptron 3 outputs: +1, 0, -1             │
│                                                         │
│   PRACTICE:                                            │
│   • Mobile/edge deployment (TWN)                       │
│   • Uncertainty quantification (3-way)                 │
│   • Efficient inference (ternary ops)                  │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---

## Wisdom of the Chapter

> *And Ivan the Programmer understood the fifth truth:*
>
> *Three casts of the net — three decisions of the neural network:*
> *the first — empty (REJECT),*
> *the second — seaweed (DEFER),*
> *the third — golden fish (ACCEPT).*
>
> *Three weights of the neuron — the miller's three sons:*
> *the eldest (+1) adds,*
> *the youngest (-1) subtracts,*
> *the middle (0) stays silent.*
>
> *Three states of the network — three realms:*
> *decay (Nav'),*
> *criticality (Yav'),*
> *explosion (Prav').*
>
> *Only at the edge of chaos and order*
> *does the network learn.*
>
> *Like the hero of a fairy tale at a crossroads —*
> *the neural network chooses from three roads.*
>
> *The ancients knew.*

---

[<- Chapter 6](06_trinity_compression.md) | [Chapter 8: Benchmarks ->](08_benchmarks.md)
