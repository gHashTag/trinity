# Chapter 14: Parallel & SIMD — The First Horizon

---

*"And Ivan divided himself into three,*
*and each went his own way,*
*but all three were doing the same work..."*

---

## Three Heroes of Parallelism

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│  THREE LEVELS OF PARALLELISM                                    │
│                                                                 │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐             │
│  │   ILYA      │  │  DOBRYNYA   │  │   ALYOSHA   │             │
│  │  (Threads)  │  │   (SIMD)    │  │   (GPU)     │             │
│  ├─────────────┤  ├─────────────┤  ├─────────────┤             │
│  │ Multiple    │  │ One thread, │  │ Thousands   │             │
│  │ threads,    │  │ many data   │  │ of threads, │             │
│  │ different   │  │ at once     │  │ massive     │             │
│  │ tasks       │  │             │  │ parallelism │             │
│  ├─────────────┤  ├─────────────┤  ├─────────────┤             │
│  │ 2-8x        │  │ 4-16x       │  │ 50-100x     │             │
│  └─────────────┘  └─────────────┘  └─────────────┘             │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Parallel Trinity Sort

### Idea: Three Independent Parts

```
After 3-way partition:

┌────────────────────────────────────────────────────────────────┐
│                                                                │
│  [████████████]  [████]  [████████████]                       │
│    < pivot      = pivot    > pivot                            │
│       │           │           │                               │
│       │         DONE!         │                               │
│       │                       │                               │
│       ▼                       ▼                               │
│   Thread 1               Thread 2                             │
│   (recursion)            (recursion)                          │
│                                                                │
│  The middle part REQUIRES NO WORK!                            │
│  This is Trinity's advantage over regular Quicksort.          │
│                                                                │
└────────────────────────────────────────────────────────────────┘
```

### Code in Vibee

```vibee
fn parallel_trinity_sort<T: Ord>(arr: &mut [T]) {
    if arr.len() <= 27 {  // The Thrice-Nine Kingdom!
        insertion_sort(arr)
        return
    }

    let (lt, gt) = partition3(arr)

    // Three heroes work in parallel
    @parallel {
        trinity_sort(&mut arr[..lt])      // Ilya — left part
        // Middle part is already done!   // Dobrynya rests
        trinity_sort(&mut arr[gt+1..])    // Alyosha — right part
    }
}
```

### Results

```
┌─────────────┬─────────────┬─────────────┬─────────────┐
│ Cores       │ Speedup     │ Efficiency  │ Notes       │
├─────────────┼─────────────┼─────────────┼─────────────┤
│ 1           │ 1.0x        │ 100%        │ baseline    │
│ 2           │ 1.8x        │ 90%         │             │
│ 4           │ 3.2x        │ 80%         │             │
│ 8           │ 5.5x        │ 69%         │             │
│ 16          │ 8.0x        │ 50%         │ overhead    │
└─────────────┴─────────────┴─────────────┴─────────────┘
```

---

## SIMD Trinity

### Idea: Three Masks Simultaneously

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│  SIMD 3-WAY PARTITION                                          │
│                                                                 │
│  Load 8 elements (AVX):                                        │
│  ┌───┬───┬───┬───┬───┬───┬───┬───┐                            │
│  │ 3 │ 7 │ 5 │ 2 │ 5 │ 9 │ 1 │ 5 │  pivot = 5                 │
│  └───┴───┴───┴───┴───┴───┴───┴───┘                            │
│                                                                 │
│  Three comparisons SIMULTANEOUSLY:                              │
│                                                                 │
│  cmp_lt = data < pivot                                         │
│  ┌───┬───┬───┬───┬───┬───┬───┬───┐                            │
│  │ 1 │ 0 │ 0 │ 1 │ 0 │ 0 │ 1 │ 0 │  (3,2,1 < 5)               │
│  └───┴───┴───┴───┴───┴───┴───┴───┘                            │
│                                                                 │
│  cmp_eq = data == pivot                                        │
│  ┌───┬───┬───┬───┬───┬───┬───┬───┐                            │
│  │ 0 │ 0 │ 1 │ 0 │ 1 │ 0 │ 0 │ 1 │  (5,5,5 == 5)              │
│  └───┴───┴───┴───┴───┴───┴───┴───┘                            │
│                                                                 │
│  cmp_gt = data > pivot                                         │
│  ┌───┬───┬───┬───┬───┬───┬───┬───┐                            │
│  │ 0 │ 1 │ 0 │ 0 │ 0 │ 1 │ 0 │ 0 │  (7,9 > 5)                 │
│  └───┴───┴───┴───┴───┴───┴───┴───┘                            │
│                                                                 │
│  8 elements in 3 instructions!                                  │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Trinity's Advantage

```
REGULAR QUICKSORT (2-way):
  cmp_lt = data < pivot   ← 1 comparison
  cmp_ge = NOT cmp_lt     ← computed

  2 categories, but equals go into one of them!

TRINITY SORT (3-way):
  cmp_lt = data < pivot   ← 1 comparison
  cmp_gt = data > pivot   ← 1 comparison
  cmp_eq = NOT (lt OR gt) ← 1 logical operation

  3 categories, equals are SEPARATE!

  This is natural for SIMD:
  - Three masks from two comparisons
  - Equal elements don't move
```

### Results

```
┌─────────────┬─────────────┬─────────────┐
│ Technology  │ Speedup     │ Notes       │
├─────────────┼─────────────┼─────────────┤
│ Scalar      │ 1.0x        │ baseline    │
│ SSE (128b)  │ 1.5-2x      │ 4 elements  │
│ AVX (256b)  │ 2-4x        │ 8 elements  │
│ AVX-512     │ 5-10x       │ 16 elements │
└─────────────┴─────────────┴─────────────┘
```

---

## Combination: Parallel + SIMD

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│  HYBRID TRINITY SORT                                           │
│                                                                 │
│  Level 1-3: Parallel (threads)                                 │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  Thread 1    Thread 2    Thread 3    Thread 4           │   │
│  │     │           │           │           │               │   │
│  │     ▼           ▼           ▼           ▼               │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  Level 4+: SIMD (vectorization)                                │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  [████████] [████████] [████████] [████████]            │   │
│  │   AVX-256    AVX-256    AVX-256    AVX-256              │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  Level 7+: Scalar (base case <= 27)                            │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │  insertion_sort for small arrays                        │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
│  TOTAL SPEEDUP: 10-40x on modern CPUs!                         │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Wisdom of the Chapter

> *And Ivan divided himself into three heroes:*
>
> *Ilya (Threads) took on the large parts,*
> *each thread — its own path.*
>
> *Dobrynya (SIMD) took on the medium parts,*
> *eight elements in a single sword strike.*
>
> *Alyosha (Scalar) took on the small parts,*
> *where cunning matters more than strength.*
>
> *And together they conquered any array*
> *10-40 times faster than alone.*
>
> *For three heroes together are stronger*
> *than each one separately.*

---

[<- Chapter 13](13_architecture.md) | [Chapter 15: Quantum Trinity ->](15_quantum_trinity.md)
