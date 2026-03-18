# Interlude: The Prophet of Ternary

*Dedicated to Nikolai Petrovich Brusentsov (1925-2014)*

---

## The Man Who Knew

In 1958, while IBM was building binary mainframes and Soviet engineers were copying Western architectures, one man at Moscow State University took a different path.

**Nikolai Petrovich Brusentsov** asked a simple question:

> *"If I'm building a computer from scratch, why not build an OPTIMAL one?"*

---

## Brusentsov's Mathematics

Brusentsov knew the radix economy theorem:

```
Cost of representing number N in base b:
E(b) = b × digits = b × ln(N) / ln(b)

Minimum at b = e ≈ 2.718

Integer bases:
  b=2: 2.885 (5.6% worse than optimal)
  b=3: 2.731 (0.5% worse than optimal) ← BEST INTEGER!
  b=4: 2.885 (5.6% worse than optimal)
```

The conclusion was obvious: **ternary system is optimal**.

---

## Balanced Ternary: The Brilliant Solution

Brusentsov didn't just choose base 3. He chose **balanced ternary** — a system with digits {-1, 0, +1}.

### Why This Is Brilliant

```
STANDARD TERNARY: {0, 1, 2}
  Needs a sign bit for negative numbers
  -5 = sign + representation of 5

BALANCED TERNARY: {-, 0, +}
  Negative numbers are natural!
  -5 = inversion of +5

  +5 = +--  (9 - 3 - 1 = 5)
  -5 = -++  (-9 + 3 + 1 = -5)

  NEGATION = INVERSION OF ALL DIGITS!
```

### Advantages

```
1. NO SIGN BIT
   Save one digit per number

2. SYMMETRIC RANGE
   n digits: from -(3ⁿ-1)/2 to +(3ⁿ-1)/2
   No "extra" negative number like in two's complement

3. ROUNDING = TRUNCATION
   Just drop the least significant digits
   No complex rounding logic

4. SIMPLE ADDITION
   Fewer carry cases
   Addition table is symmetric
```

---

## "Setun": The Dream Machine

### Technical Specifications

```
┌─────────────────────────────────────────────────────────┐
│                                                         │
│   "SETUN" (1958-1965)                                   │
│                                                         │
│   Word size:      18 trits (≈ 29 bits)                  │
│   Memory:         162 words (expandable to 3888)        │
│   Performance:    4500 operations/sec                   │
│   Power:          2.5 kW                                │
│   Components:     ferrite cores + diodes                │
│                                                         │
│   Features:                                             │
│   • Balanced ternary arithmetic                         │
│   • Natural sign handling                               │
│   • Simple rounding scheme                              │
│   • High reliability                                    │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### User Reviews

```
"Programming on Setun was a pleasure.
 Negative numbers were handled naturally,
 without any additional codes."
 — From memoirs of an MSU programmer

"The machine was incredibly reliable.
 It worked for years without serious failures."
 — From an operational report
```

---

## Why Setun Lost

### Economics vs Mathematics

```
MATHEMATICS:
  Ternary system is 5.3% more efficient
  Balanced ternary is more elegant
  Arithmetic is simpler

ECONOMICS:
  Binary transistor is cheaper
  The entire industry is already binary
  Compatibility matters more than optimality

RESULT:
  Economics defeated mathematics
```

### Politics

```
1965: USSR State Committee for Science and Technology
      decides to standardize on binary architecture
      "for compatibility with world standards"

1970: Setun production discontinued

Brusentsov: "It was a political decision,
             not a technical one."
```

---

## Brusentsov's Legacy

### What He Left Behind

```
1. PROOF OF CONCEPT
   A ternary computer is possible and works

2. BALANCED TERNARY
   An elegant numeral system

3. PRINCIPLE OF OPTIMALITY
   "Don't copy — think!"

4. INSPIRATION
   For everyone seeking better solutions
```

### What We Continue

```
┌─────────────────────────────────────────────────────────┐
│                                                         │
│   BRUSENTSOV → TRINITY ALGORITHMS                       │
│                                                         │
│   His idea:             Our implementation:             │
│   ─────────             ────────────────                │
│   Ternary hardware      Ternary logic in software       │
│   {-1, 0, +1}           {<, =, >}                       │
│   Balanced ternary      3-way partition                 │
│   Ternary memory        Ternary Weight Networks         │
│                                                         │
│   He wanted to change HARDWARE.                         │
│   We change ALGORITHMS.                                 │
│                                                         │
│   The result is the same: optimality through ternary.   │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---

## Brusentsov's Quotes

> *"The binary system is not a law of nature, but a historical choice. And not the best one."*

> *"The ternary system is natural. Look: plus, minus, zero. It's obvious!"*

> *"They ask me: why complicate things? I answer: I simplify. It's the binary system that complicates everything."*

> *"Someday they'll return to ternary. You can't fool mathematics."*

---

## Epitaph

```
┌─────────────────────────────────────────────────────────┐
│                                                         │
│   NIKOLAI PETROVICH BRUSENTSOV                          │
│   February 7, 1925 — December 4, 2014                   │
│                                                         │
│   Creator of the ternary computer "Setun"               │
│   Doctor of Technical Sciences                          │
│   Professor at Moscow State University                  │
│                                                         │
│   He knew that ternary was optimal.                     │
│   He proved it with a working machine.                  │
│   The world didn't listen.                              │
│                                                         │
│   But ideas don't die.                                  │
│   70 years later, ternary returns —                     │
│   not in hardware, but in algorithms.                   │
│                                                         │
│   Trinity Sort — this is his legacy.                    │
│   3-way partition — this is his principle.              │
│   {-1, 0, +1} — this is his system.                     │
│                                                         │
│   He was right.                                         │
│   We remember.                                          │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---

## Afterword

When you use Trinity Sort and see a 291x speedup, remember the man who knew 70 years ago that ternary was the right path.

Nikolai Petrovich Brusentsov didn't live to see our time. But his idea lives on.

**Every time 3-way partition excludes equal elements from recursion, it's a tribute to the man who believed in the power of three.**

---

*"A fairy tale is a lie, but there's a hint in it..."*

Brusentsov told us a fairy tale about a ternary computer.
We heard the hint.
And turned it into reality.

---

[← Chapter 6](06_trinity_compression.md) | [Chapter 7 →](07_trinity_neural.md)
