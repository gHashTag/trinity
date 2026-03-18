# Chapter 3: Constants π, φ, e — The Language of the Universe

---

*"Mathematics is the language in which the book of nature is written."*
— Galileo Galilei

---

## Three Constants of Optimization

The Universe speaks in the language of three constants:

```
┌─────────────────────────────────────────────────────────┐
│                                                         │
│   THREE CONSTANTS OF THE UNIVERSE                       │
│                                                         │
│   π = 3.14159...    Periodicity, rotation               │
│   φ = 1.61803...    Optimal distribution                │
│   e = 2.71828...    Growth, optimal base                │
│                                                         │
│   And all three are connected to the number 3!          │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---

## π: The Constant of Periodicity

### Where π Appears

```
GEOMETRY:
  Circumference: C = 2πr
  Circle area: A = πr²
  Sphere: V = (4/3)πr³

PHYSICS:
  Waves: sin(2πft)
  Quantum mechanics: ℏ = h/2π
  Gravity: orbital period contains π

ALGORITHMS:
  FFT: ω_n = e^(2πi/n)
  Stirling: n! ≈ √(2πn)(n/e)^n
  Normal distribution: (1/√2π)e^(-x²/2)
```

### π in Sorting

```
Lower bound of sorting:
  log₂(n!) ≈ n log₂(n) - n/ln(2)

Using Stirling:
  n! ≈ √(2πn)(n/e)^n

  log₂(n!) ≈ log₂(√(2πn)) + n log₂(n/e)
           ≈ (1/2)log₂(2πn) + n log₂(n) - n log₂(e)

π appears in the LOWER BOUND of sorting!
```

---

## φ: The Golden Ratio

### Definition

```
φ = (1 + √5) / 2 = 1.6180339887...

Properties:
  φ² = φ + 1
  1/φ = φ - 1
  φ = 1 + 1/φ

Continued fraction:
  φ = 1 + 1/(1 + 1/(1 + 1/(1 + ...)))
    = [1; 1, 1, 1, 1, ...]

φ — THE MOST IRRATIONAL NUMBER!
```

### Why is φ Optimal?

```
┌─────────────────────────────────────────────────────────┐
│                                                         │
│   φ = ANTI-RESONANCE                                    │
│                                                         │
│   Rational numbers create resonances:                   │
│   1/2 → every second                                    │
│   1/3 → every third                                     │
│   2/3 → pattern repeats                                 │
│                                                         │
│   φ — the furthest from all rationals!                  │
│   Its approximations converge SLOWEST OF ALL.           │
│                                                         │
│   CONSEQUENCE:                                          │
│   φ gives the most uniform distribution                 │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### φ in Algorithms

```
FIBONACCI HEAP:
  Node degree ≤ log_φ(n)
  Amortized complexity O(1) for decrease-key

GOLDEN SECTION SEARCH:
  Divide segment in ratio φ
  Optimal for unimodal functions

HASHING:
  h(k) = floor(n × (k × φ mod 1))
  Gives uniform distribution

TRINITY SORT:
  pivot_idx = lo + (hi - lo) × (φ - 1)
            = lo + (hi - lo) × 0.618
  Avoids worst-case on structured data
```

---

## e: The Base of Natural Logarithm

### Definition

```
e = lim(n→∞) (1 + 1/n)^n = 2.7182818284...

Properties:
  d/dx e^x = e^x
  ∫ e^x dx = e^x
  ln(e) = 1
```

### e and the Optimal Base

```
┌─────────────────────────────────────────────────────────┐
│                                                         │
│   OPTIMAL BASE FOR NUMBER REPRESENTATION                │
│                                                         │
│   Cost of representing N in base b:                     │
│   E(b) = b × log_b(N) = b × ln(N) / ln(b)              │
│                                                         │
│   Minimize b / ln(b):                                   │
│   d/db [b / ln(b)] = 0                                  │
│   ln(b) = 1                                             │
│   b = e ≈ 2.718                                         │
│                                                         │
│   OPTIMAL BASE = e                                      │
│   NEAREST INTEGER = 3                                   │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### e in Algorithms

```
ALGORITHM COMPLEXITY:
  O(n log n) = O(n × ln(n) / ln(2))
  Natural logarithm — the natural measure

PROBABILITY:
  Poisson distribution: e^(-λ)λ^k/k!
  Random permutations: ~1/e have no fixed points

OPTIMIZATION:
  Gradient descent: e^(-αt)
  Simulated annealing: e^(-ΔE/kT)
```

---

## Connection Between Constants

### Euler's Formula

```
e^(iπ) + 1 = 0

Connects:
  e — base of natural logarithm
  i — imaginary unit
  π — ratio of circumference to diameter
  1 — unity
  0 — zero

The most beautiful formula in mathematics!
```

### Connection with the Number 3

```
e ≈ 3 (nearest integer)
π ≈ 3 (rough approximation)
φ + 1/φ = √5 ≈ 2.236, but φ² = φ + 1 ≈ 2.618 ≈ 3

All three constants "revolve" around 3!
```

### Mass Formulas

```
m_p/m_e = 6π⁵ = 2 × 3 × π⁵

The coefficient 6 = 2 × 3 contains three!

Hypothesis: 3 — structural constant,
π — periodicity constant,
their combination determines particle masses.
```

---

## Practical Application

### Golden Ratio in Trinity Sort

```python
def trinity_sort(arr):
    PHI = 0.6180339887  # φ - 1 = 1/φ

    def partition3(a, lo, hi):
        # Choose pivot at position φ from start
        pivot_idx = lo + int((hi - lo) * PHI)
        pivot = a[pivot_idx]
        # ... 3-way partition
```

### e in Hashing

```python
def golden_hash(key, table_size):
    """Hashing with golden ratio"""
    PHI = 1.6180339887
    # Use fractional part of key × φ
    return int(table_size * ((key * PHI) % 1))
```

### π in FFT

```python
def fft(x):
    """Fast Fourier Transform"""
    import cmath
    n = len(x)
    # Twiddle factor uses π
    omega = cmath.exp(-2j * cmath.pi / n)
    # ...
```

---

## The Unified Picture

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│   THREE CONSTANTS — ONE LANGUAGE                                │
│                                                                 │
│   ┌─────────┐     ┌─────────┐     ┌─────────┐                  │
│   │    π    │     │    φ    │     │    e    │                  │
│   ├─────────┤     ├─────────┤     ├─────────┤                  │
│   │Periodici│     │Distribut│     │  Growth │                  │
│   │Rotation │     │Antireso.│     │Optim.bas│                  │
│   │  Waves  │     │ Balance │     │Complexit│                  │
│   └────┬────┘     └────┬────┘     └────┬────┘                  │
│        │              │              │                         │
│        └──────────────┼──────────────┘                         │
│                       │                                        │
│                       ▼                                        │
│              ┌─────────────────┐                               │
│              │   NUMBER 3      │                               │
│              │                 │                               │
│              │ e ≈ 3           │                               │
│              │ π ≈ 3           │                               │
│              │ φ² ≈ 3          │                               │
│              │                 │                               │
│              │ Everything      │                               │
│              │ revolves        │                               │
│              │ around three!   │                               │
│              └─────────────────┘                               │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Wisdom of the Chapter

> *And Ivan the programmer understood the third truth:*
>
> *The Universe speaks in the language of three constants:*
> *π — the language of periodicity and waves,*
> *φ — the language of optimal distribution,*
> *e — the language of growth and complexity.*
>
> *And all three are connected to the number 3:*
> *e ≈ 3, π ≈ 3, φ² ≈ 3.*
>
> *Euler's formula e^(iπ) + 1 = 0*
> *binds them into a unified whole.*
>
> *When I use φ to choose a pivot,*
> *I speak the language of the Universe.*
>
> *The ancients knew this language intuitively.*
> *I am learning to speak it consciously.*

---

[← Chapter 2](02_physics_algorithms.md) | [Chapter 4: Trinity Sort →](04_trinity_sort.md)
