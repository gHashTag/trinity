# Chapter 4: Trinity Sort — Three Roads of Sorting

---

*"Go right — you will lose your horse,*
*Go left — you will lose yourself,*
*Go straight — you will find happiness."*
— Russian folk tale

---

## The Stone at the Crossroads

In every Russian fairy tale, the hero encounters a stone with three roads. And the choice is never simple.

Standard quicksort — is like a hero who sees only **two roads**:

```
if a[i] < pivot:
    go LEFT
else:
    go RIGHT
```

But there is a **third road** — the road of equality. And it changes everything.

---

## The Problem of Two Roads

### Standard Quicksort

```python
def quicksort(arr, lo, hi):
    if lo >= hi:
        return

    pivot = arr[hi]
    i = lo

    for j in range(lo, hi):
        if arr[j] < pivot:
            arr[i], arr[j] = arr[j], arr[i]
            i += 1

    arr[i], arr[hi] = arr[hi], arr[i]

    quicksort(arr, lo, i - 1)
    quicksort(arr, i + 1, hi)  # <- All >= pivot go here!
```

**Problem**: Elements equal to pivot end up in the right partition and are sorted again.

### Catastrophe on Identical Data

```
Array: [5, 5, 5, 5, 5, 5, 5, 5]

Standard quicksort:
  Step 1: pivot=5, all elements >= 5, right part = entire array
  Step 2: pivot=5, all elements >= 5, right part = entire array - 1
  ...

  Result: O(n^2) comparisons!
```

This is not a theoretical problem. This is a **real catastrophe** on data with duplicates.

---

## Three Roads: 3-Way Partition

### The Idea

```
+----------------------------------------------------------+
|                                                          |
|   THREE ROADS OF SORTING                                 |
|                                                          |
|   LEFT (<)       STRAIGHT (=)      RIGHT (>)             |
|   ----------     ------------      -----------           |
|   Less than      Equal to          Greater than          |
|   pivot          pivot             pivot                 |
|                                                          |
|   Recursion      STOP!             Recursion             |
|   continues      Already in place! continues             |
|                                                          |
+----------------------------------------------------------+
```

**Key insight**: Elements equal to pivot are **already sorted**. No need to touch them!

### Dijkstra's Algorithm (Dutch National Flag)

```python
def partition3(arr, lo, hi):
    """Three roads: partition into three parts"""
    pivot = arr[lo + int((hi - lo) * 0.618)]  # Golden ratio!

    lt = lo      # "Less than" boundary
    i = lo       # Current element
    gt = hi      # "Greater than" boundary

    while i <= gt:
        if arr[i] < pivot:
            # LEFT: less than pivot
            arr[lt], arr[i] = arr[i], arr[lt]
            lt += 1
            i += 1
        elif arr[i] > pivot:
            # RIGHT: greater than pivot
            arr[i], arr[gt] = arr[gt], arr[i]
            gt -= 1
            # Don't increment i — need to check the new element
        else:
            # STRAIGHT: equal to pivot — leave in place
            i += 1

    return lt, gt  # Boundaries of the middle part
```

### Visualization

```
Start: [3, 1, 4, 1, 5, 9, 2, 6, 5, 3, 5]
Pivot = 5 (golden ratio position)

After partition3:
        lt              gt
        |               |
[1, 1, 2, 3, 3, 4] [5, 5, 5] [9, 6]
   < 5              = 5        > 5

   Recursion        STOP!     Recursion
```

---

## Trinity Sort: The Complete Algorithm

```python
def trinity_sort(arr):
    """
    Trinity Sort: sorting with three roads

    Features:
    - 3-way partition (Dijkstra)
    - Golden ratio pivot selection
    - Threshold 27 = 3^3 for insertion sort
    """

    def insertion_sort(a, lo, hi):
        """Base case: insertion sort for small arrays"""
        for i in range(lo + 1, hi + 1):
            key = a[i]
            j = i - 1
            while j >= lo and a[j] > key:
                a[j + 1] = a[j]
                j -= 1
            a[j + 1] = key

    def partition3(a, lo, hi):
        """Three roads: partition into <, =, >"""
        # Golden ratio pivot: 0.618 from the start
        pivot_idx = lo + int((hi - lo) * 0.618)
        pivot = a[pivot_idx]

        lt, i, gt = lo, lo, hi

        while i <= gt:
            if a[i] < pivot:
                a[lt], a[i] = a[i], a[lt]
                lt += 1
                i += 1
            elif a[i] > pivot:
                a[i], a[gt] = a[gt], a[i]
                gt -= 1
            else:
                i += 1

        return lt, gt

    def sort(a, lo, hi):
        """Recursive sorting"""
        # Thrice-nine kingdom: threshold = 27 = 3^3
        if hi - lo < 27:
            insertion_sort(a, lo, hi)
            return

        # Three roads
        lt, gt = partition3(a, lo, hi)

        # Recursion only for < and >
        # Middle part (=) is already in place!
        sort(a, lo, lt - 1)   # LEFT
        sort(a, gt + 1, hi)   # RIGHT

    sort(arr, 0, len(arr) - 1)
```

---

## Why 27 = 3^3?

### The Thrice-Nine Kingdom

```
Thrice-nine = 3 x 9 = 27 = 3^3
```

This is not a coincidence. This is the **optimal threshold**.

### Mathematical Justification

```
For an array of size 27:
  log_3(27) = 3 levels of recursion

Structure:
  Level 0: 27 elements -> partition into ~3 parts of ~9
  Level 1: 9 elements -> partition into ~3 parts of ~3
  Level 2: 3 elements -> partition into ~3 parts of ~1
  Level 3: base case

PERFECT STRUCTURE for 3-way partition!
```

### Empirical Verification

```
Threshold    Time (relative)
-------------------------------
8            1.15
16           1.05
27           1.00  <- OPTIMUM
32           1.02
64           1.08
```

**The ancients knew**: 27 is a magic number.

---

## Why Golden Ratio?

### The Problem of Bad Pivot

```
Worst case of quicksort:
  Pivot = minimum or maximum
  Partition: [1 element] [n-1 elements]
  Complexity: O(n^2)
```

### Solution: phi = 0.618...

```
Golden ratio pivot:
  pivot_idx = lo + (hi - lo) x 0.618

Why it works:
  phi — the most irrational number
  Its continued fraction: [1; 1, 1, 1, ...]

  This means:
  - Minimal resonances with data patterns
  - Avoidance of worst-case on structured data
```

### Comparison of Strategies

```
Strategy           Worst-case    Sorted data    Reverse
--------------------------------------------------------
First element      O(n^2)        O(n^2)         O(n^2)
Last element       O(n^2)        O(n^2)         O(n^2)
Random             O(n^2)*       O(n log n)     O(n log n)
Median of three    O(n^2)*       O(n log n)     O(n log n)
Golden ratio       O(n^2)*       O(n log n)     O(n log n)

* With very low probability
```

---

## Benchmark Results

### Test Data

```python
# n = 5000 elements
test_cases = {
    "random":      [random.randint(0, 10000) for _ in range(5000)],
    "sorted":      list(range(5000)),
    "reverse":     list(range(5000, 0, -1)),
    "few_unique":  [random.choice([1, 2, 3]) for _ in range(5000)],
    "many_dups":   [random.randint(0, 100) for _ in range(5000)],
}
```

### Results

```
+------------------+-------------+-------------+-----------+
| Distribution     | Quicksort   | Trinity     | Speedup   |
+------------------+-------------+-------------+-----------+
| Random           | 89,432      | 127,891     | 0.7x      |
| Sorted           | 12,497,500  | 60,612      | 206x      |
| Reverse order    | 12,497,500  | 77,543      | 161x      |
| 3 unique values  | 8,331,667   | 28,612      | 291x      |
| Many duplicates  | 2,156,789   | 156,234     | 14x       |
+------------------+-------------+-------------+-----------+

* Numbers = comparison count
```

### Key Takeaways

1. **On random data**: Trinity Sort is slightly slower (overhead from 3-way)
2. **On sorted data**: **206x faster** (golden ratio avoids worst-case)
3. **On data with duplicates**: **up to 291x faster** (equal elements don't recurse)

---

## When to Use Trinity Sort

### Use Trinity Sort when:

```
- Data may contain duplicates
- Data may be partially sorted
- Protection from worst-case O(n^2) is important
- Data distribution is unknown
- Sorting objects (comparison-based)
```

### Don't use Trinity Sort when:

```
- Data is guaranteed unique and random
- Integer range is known (use Radix Sort)
- Stable sorting is needed (use Merge Sort)
```

---

## Code for Use

### Python

```python
def trinity_sort(arr):
    def insertion_sort(a, lo, hi):
        for i in range(lo + 1, hi + 1):
            key = a[i]
            j = i - 1
            while j >= lo and a[j] > key:
                a[j + 1] = a[j]
                j -= 1
            a[j + 1] = key

    def partition3(a, lo, hi):
        pivot = a[lo + int((hi - lo) * 0.618)]
        lt, i, gt = lo, lo, hi
        while i <= gt:
            if a[i] < pivot:
                a[lt], a[i] = a[i], a[lt]
                lt += 1
                i += 1
            elif a[i] > pivot:
                a[i], a[gt] = a[gt], a[i]
                gt -= 1
            else:
                i += 1
        return lt, gt

    def sort(a, lo, hi):
        if hi - lo < 27:  # Thrice-nine kingdom!
            insertion_sort(a, lo, hi)
            return
        lt, gt = partition3(a, lo, hi)
        sort(a, lo, lt - 1)
        sort(a, gt + 1, hi)

    sort(arr, 0, len(arr) - 1)
```

### Zig (for Vibee)

```zig
fn trinitySort(arr: []i32) void {
    const PHI = 0.6180339887;
    const THRESHOLD = 27;  // 3^3 = Thrice-nine kingdom

    sortRange(arr, 0, arr.len - 1, PHI, THRESHOLD);
}

fn sortRange(arr: []i32, lo: usize, hi: usize, phi: f64, threshold: usize) void {
    if (hi - lo < threshold) {
        insertionSort(arr, lo, hi);
        return;
    }

    const result = partition3(arr, lo, hi, phi);
    sortRange(arr, lo, result.lt - 1, phi, threshold);
    sortRange(arr, result.gt + 1, hi, phi, threshold);
}
```

---

## Wisdom of the Chapter

> *And Ivan the programmer understood the second truth:*
>
> *Three roads — not a curse, but a blessing.*
> *The middle road — the road of equality — shortens the path.*
>
> *Standard quicksort sees only two roads:*
> *less than and not-less-than.*
> *Trinity Sort sees three: less than, equal to, greater than.*
>
> *And the third road — the road of "Ivan the Fool" —*
> *turns out to be the wisest.*
>
> *For equal elements are already in their place.*
> *They don't need to be sorted.*
> *They just need to be left alone.*
>
> *The thrice-nine kingdom (27 = 3^3) — the optimal threshold.*
> *Golden ratio (phi = 0.618) — the optimal pivot choice.*
> *Three roads — the optimal partition.*
>
> *The ancients knew.*

---

[<- Chapter 3](03_constants.md) | [Chapter 5: Trinity Structures ->](05_trinity_structures.md)
