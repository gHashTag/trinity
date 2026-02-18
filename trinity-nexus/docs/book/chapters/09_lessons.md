# Chapter 9: Lessons of the Path — What Works, What Doesn't

---

*"A wise man learns from others' mistakes,*
*a fool — from his own."*
— Russian proverb

---

## Lessons of the Path

We have traveled a long way. It's time to summarize.

---

## ✅ What Works

### Principle: 3-Way Partition

```
WORKS because:
  • Excludes equal elements from recursion
  • Reduces recursion depth
  • Protects from worst-case

APPLICATIONS:
  • Trinity Sort: up to 291x faster
  • Dutch National Flag: classic algorithm
  • Quickselect: finding the k-th element
```

### Principle: Branching Factor = 3

```
WORKS because:
  • Minimizes b/log(b)
  • Optimum at b = e ≈ 2.718 ≈ 3

APPLICATIONS:
  • Trinity B-Tree: 6% fewer comparisons
  • Ternary Search Tree: efficient prefix search
```

### Principle: 3 Hash Functions

```
WORKS because:
  • Maximum load factor increase
  • d=2→d=3: +82%
  • d=3→d=4: +7%

APPLICATIONS:
  • Cuckoo Hashing: 91% fill rate
  • Bloom Filter: optimal k ≈ 3
```

### Principle: 3 States

```
WORKS because:
  • Allows distinguishing "in progress" from "completed"
  • Necessary for cycle detection

APPLICATIONS:
  • DFS: WHITE/GRAY/BLACK
  • Topological sort
  • Strongly connected components
```

---

## ❌ What Does NOT Work

### Trinity Search

```
DOES NOT WORK because:
  • 2-3 comparisons per iteration
  • log₃(n) × 2 > log₂(n) × 1
  • No "equal elements" to exclude

LESSON:
  3-way helps when there's something to EXCLUDE
  In search, there's nothing to exclude
```

### Radix Base 3

```
DOES NOT WORK because:
  • Radix doesn't use comparisons
  • Larger base = fewer passes
  • Base 256 = 3 passes, Base 3 = 13 passes

LESSON:
  The number 3 helps in COMPARISON-BASED algorithms
  Radix is not comparison-based
```

### Ternary Hardware

```
DOES NOT WORK (in practice) because:
  • All infrastructure is binary
  • Theoretical advantage ~5%
  • Doesn't justify rebuilding the industry

LESSON:
  Theory and practice are different realms
```

---

## Key Insight

```
┌─────────────────────────────────────────────────────────┐
│                                                         │
│   THE NUMBER 3 HELPS WHEN:                              │
│                                                         │
│   1. There are COMPARISONS (comparison-based)           │
│   2. There's something to EXCLUDE (equal elements)      │
│   3. BALANCE is needed (branching factor)               │
│   4. STATES are needed (process vs result)              │
│                                                         │
│   THE NUMBER 3 DOES NOT HELP WHEN:                      │
│                                                         │
│   1. No comparisons (radix sort)                        │
│   2. Nothing to exclude (binary search)                 │
│   3. Hardware is needed (ternary computers)             │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---

## Recommendations

### When to Use Trinity

```
✅ USE Trinity Sort when:
   • Data may contain duplicates
   • Data may be partially sorted
   • Data distribution is unknown

✅ USE Trinity B-Tree when:
   • In-memory tree is needed
   • Cache locality matters

✅ USE Trinity Hash when:
   • High table load is needed
   • 3 checks per lookup are acceptable

✅ USE 3-state DFS when:
   • Cycle detection is needed
   • Topological sort is needed
```

### When NOT to Use Trinity

```
❌ DO NOT USE Trinity Search:
   Binary search is always better

❌ DO NOT USE Radix base 3:
   Base 256 is always better

❌ DO NOT USE ternary hardware:
   Binary hardware dominates
```

---

## Wisdom of the Chapter

> *And Ivan the Programmer understood the seventh truth:*
>
> *Wisdom is knowing when to apply knowledge.*
>
> *The number 3 is not a universal key.*
> *It works where there are comparisons and exclusions.*
>
> *Trinity Sort — for data with repeats.*
> *Binary Search — for unique data.*
>
> *A wise man learns from others' mistakes.*
> *We showed where the mistakes are, so you don't repeat them.*

---

[← Chapter 8](08_benchmarks.md) | [Chapter 10: Vibee Language →](10_vibee.md)
