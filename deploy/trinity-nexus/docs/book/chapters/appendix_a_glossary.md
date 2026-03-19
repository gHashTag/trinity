# Appendix A: Glossary of the Thrice-Nine Kingdom

---

## Fairy Tale Images → Technical Terms

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                                                                             │
│  DICTIONARY OF THE THRICE-NINE KINGDOM                                     │
│                                                                             │
│  Fairy tale image           Technical term                                 │
│  ─────────────────────────────────────────────────────────────────────────│
│  Thrice-nine kingdom        Threshold 27 = 3³ for the base case           │
│  Three roads                3-way partition (less/equal/greater)          │
│  Three bogatyrs             Three system components (Hash, BTree, Graph)  │
│  Three attempts             Three states (WHITE/GRAY/BLACK in DFS)        │
│  Three sons                 Balanced ternary {-1, 0, +1}                  │
│  Tower of 999 windows       Compiler with 3×333 optimizations             │
│  Stone at the crossroads    Pivot in quicksort                            │
│  Magic compass              Golden ratio φ for pivot selection            │
│  Enchanted forest           NP-complete problem                           │
│  Magic sword                Optimal algorithm                             │
│  Living water               Parallelism (revives performance)             │
│  Dead water                 Sequential code (glues parts together)        │
│  Baba Yaga                  Compiler (scary, but helpful)                 │
│  Koschei the Immortal       Legacy code (hard to kill)                    │
│  Firebird                   Optimal solution (rare, valuable)             │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Technical Terms

### A

**3-adic numbers**
: Number system with metric |n|₃ = 3^(-v₃(n)), where v₃(n) is the maximum power of 3 dividing n. In this metric, 27 is closer to 0 than 1.

**AVX (Advanced Vector Extensions)**
: Intel/AMD SIMD instruction set for parallel processing of 256 bits of data (8 × 32-bit int).

### B

**Balanced ternary**
: Numeral system with digits {-1, 0, +1}. Used in the "Setun" computer. Negating a number = inverting all digits.

**Branching factor**
: Number of children at a tree node. Optimal value = e ≈ 2.718, nearest integer = 3.

**Brusentsov, Nikolay Petrovich (1925-2014)**
: Creator of the ternary computer "Setun" (1958). Prophet of ternarity.

### C

**Cuckoo hashing**
: Hashing algorithm with multiple hash functions. With 3 functions achieves 91% fill rate (vs 50% with 2 functions).

### D

**Dutch National Flag**
: 3-way partition algorithm proposed by Dijkstra. Divides array into three parts: <, =, >.

### E

**Edge of chaos**
: Critical state of a neural network at σ² = 1, when the network is capable of learning.

### G

**Golden ratio**
: φ = (1 + √5) / 2 ≈ 1.618. The most irrational number. Used for pivot selection in Trinity Sort.

### N

**NP-completeness**
: Class of problems for which no known polynomial algorithm exists. Many problems become NP-complete when transitioning from k=2 to k=3.

### P

**Partition**
: Operation of dividing an array into parts relative to a pivot.
- 2-way: two parts (< and ≥)
- 3-way: three parts (<, =, >)

### Q

**Qutrit**
: Quantum system with three states |0⟩, |1⟩, |2⟩. Stores log₂(3) ≈ 1.585 bits of information.

### R

**Radix economy**
: Measure of base b efficiency: E(b) = b/ln(b). Minimum at b = e ≈ 2.718, nearest integer = 3.

### S

**SIMD (Single Instruction, Multiple Data)**
: Parallel processing of multiple data elements with a single instruction.

**"Setun"**
: Ternary computer created at Moscow State University in 1958. Used balanced ternary.

### T

**Ternary Search Tree (TST)**
: Search tree where each node has three children: <, =, >. Efficient for prefix search.

**Ternary Weight Network (TWN)**
: Neural network with weights ∈ {-1, 0, +1}. Saves 16x memory, multiplication replaced by addition.

**Three-way decision**
: Classification with three outcomes: Accept, Reject, Defer.

**Threshold 27**
: Optimal threshold for switching to insertion sort in Trinity Sort. 27 = 3³ = Thrice-Nine!

**Tribool (Ternary logic)**
: Logic with three values: True, False, Unknown.

**Thrice-nine kingdom**
: 3 × 9 = 27 = 3³. Magical place in Russian fairy tales. Optimal threshold in algorithms.

**Trinity Sort**
: Sorting algorithm with 3-way partition and golden ratio pivot. Up to 291x faster than standard quicksort on data with duplicates.

### V

**Vibee**
: Programming language built on ternary philosophy. Trinity Sort is the standard sorting algorithm.

---

## Numeric Constants

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                                                                             │
│  SACRED NUMBERS OF THE THRICE-NINE KINGDOM                                 │
│                                                                             │
│  3       Minimum complexity for structure                                  │
│  9       3² — amplified three                                              │
│  27      3³ — Thrice-Nine! Optimal threshold                               │
│  81      3⁴ — medium case boundary                                         │
│  243     3⁵ — large case boundary                                          │
│  729     3⁶ — transition to parallelism                                    │
│  999     3 × 333 — number of windows in the compiler tower                 │
│                                                                             │
│  φ       1.618... — golden ratio, pivot selection                          │
│  φ-1     0.618... — inverse golden ratio                                   │
│  e       2.718... — optimal base, ≈ 3                                      │
│  π       3.141... — periodicity, ≈ 3                                       │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Formulas

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                                                                             │
│  FORMULAS OF THE THRICE-NINE KINGDOM                                       │
│                                                                             │
│  Optimal base:                                                             │
│  min(b/ln(b)) at b = e ≈ 2.718 ≈ 3                                        │
│                                                                             │
│  Mass ratio:                                                               │
│  m_p/m_e = 6π⁵ = 2 × 3 × π⁵ (accuracy 0.002%)                             │
│                                                                             │
│  3-adic norm:                                                              │
│  |n|₃ = 3^(-v₃(n))                                                         │
│                                                                             │
│  Information in a trit:                                                    │
│  log₂(3) ≈ 1.585 bits                                                     │
│                                                                             │
│  Cuckoo load factor:                                                       │
│  d=2: 50%, d=3: 91%, d=4: 97%                                             │
│                                                                             │
│  Karatsuba:                                                                │
│  O(n^log₂(3)) = O(n^1.585)                                                │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

*"He who owns the dictionary, owns the kingdom."*
