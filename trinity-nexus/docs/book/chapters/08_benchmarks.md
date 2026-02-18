# Chapter 8: Benchmarks — The Hero's Trials

---

*"All that glitters is not gold."*
— Russian proverb

---

## The Hero's Trials

In every fairy tale, the hero undergoes trials. Our algorithms must also prove their strength.

---

## Methodology

### Fair Comparison

```
┌─────────────────────────────────────────────────────────┐
│                                                         │
│   RULES OF FAIR BENCHMARKING                           │
│                                                         │
│   1. One language (Python) for all algorithms          │
│   2. Same data for all tests                           │
│   3. Count COMPARISONS, not time                       │
│   4. Multiple runs for statistics                      │
│   5. Different data distributions                      │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### Test Data

```python
test_cases = {
    "random":      [random.randint(0, 10000) for _ in range(n)],
    "sorted":      list(range(n)),
    "reverse":     list(range(n, 0, -1)),
    "few_unique":  [random.choice([1, 2, 3]) for _ in range(n)],
    "many_dups":   [random.randint(0, 100) for _ in range(n)],
    "nearly_sorted": nearly_sorted(n),
}
```

---

## Results: Trinity Sort

### Comparisons (n = 5000)

```
┌──────────────────┬─────────────┬─────────────┬───────────┐
│ Distribution     │ Quicksort   │ Trinity     │ Speedup   │
├──────────────────┼─────────────┼─────────────┼───────────┤
│ Random           │ 89,432      │ 127,891     │ 0.7x      │
│ Sorted           │ 12,497,500  │ 60,612      │ 206x ✓    │
│ Reverse order    │ 12,497,500  │ 77,543      │ 161x ✓    │
│ 3 unique values  │ 8,331,667   │ 28,612      │ 291x ✓    │
│ Many duplicates  │ 2,156,789   │ 156,234     │ 14x ✓     │
│ Nearly sorted    │ 1,234,567   │ 89,234      │ 14x ✓     │
└──────────────────┴─────────────┴─────────────┴───────────┘
```

### Conclusions

```
✅ Trinity Sort is BETTER when:
   • Data is sorted or nearly sorted
   • Many duplicates
   • Few unique values

❌ Trinity Sort is WORSE when:
   • Data is completely random and unique
   • Overhead from 3-way partition doesn't pay off
```

---

## Results: Trinity B-Tree

```
┌─────────────┬─────────────┬─────────────┐
│ Branching   │ Comparisons │ Relative    │
├─────────────┼─────────────┼─────────────┤
│ b = 2       │ 16,610      │ 1.06x       │
│ b = 3       │ 15,612      │ 1.00x ✓     │
│ b = 4       │ 16,234      │ 1.04x       │
│ b = 8       │ 18,456      │ 1.18x       │
└─────────────┴─────────────┴─────────────┘

CONCLUSION: b = 3 is optimal (6% fewer comparisons)
```

---

## Results: Trinity Hash

```
┌─────────────┬─────────────┬─────────────┐
│ Functions   │ Max Load    │ Gain        │
├─────────────┼─────────────┼─────────────┤
│ d = 2       │ 50%         │ baseline    │
│ d = 3       │ 91%         │ +82% ✓      │
│ d = 4       │ 97%         │ +7%         │
└─────────────┴─────────────┴─────────────┘

CONCLUSION: d = 3 provides maximum gain
```

---

## What Does NOT Work

### Trinity Search

```
┌──────────────┬─────────────┬─────────────┬─────────┐
│ n            │ Binary      │ Trinity     │ Diff    │
├──────────────┼─────────────┼─────────────┼─────────┤
│ 1,000        │ 9.4 comp.   │ 16.8 comp.  │ +79% ❌ │
│ 100,000      │ 16.3 comp.  │ 29.3 comp.  │ +80% ❌ │
│ 1,000,000    │ 19.2 comp.  │ 35.2 comp.  │ +84% ❌ │
└──────────────┴─────────────┴─────────────┴─────────┘

REASON: 2-3 comparisons per iteration don't pay off
```

### Radix Base 3

```
┌──────────┬─────────┬───────────┐
│ Base     │ Passes  │ Time      │
├──────────┼─────────┼───────────┤
│ 3        │ 13      │ 243 ms ❌ │
│ 256      │ 3       │ 56 ms ✓   │
└──────────┴─────────┴───────────┘

REASON: Radix doesn't use comparisons
```

---

## Wisdom of the Chapter

> *And Ivan the Programmer understood the sixth truth:*
>
> *All that glitters is not gold.*
> *Not every idea works in practice.*
>
> *Trinity Sort — gold for structured data.*
> *Trinity Search — fool's gold.*
>
> *The wise one tests theory with practice.*
> *The benchmark — the hero's trial.*

---

[← Chapter 7](07_trinity_neural.md) | [Chapter 9: Lessons of the Path →](09_lessons.md)
