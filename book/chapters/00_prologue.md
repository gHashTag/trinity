# Prologue: A Tale of the Number Three

---

*In a thrice-nine kingdom, in a thrice-ten realm, there lived a programmer. And he had three tasks: to sort data, to find meaning within it, and to store it wisely.*

*Whether long or short his journey was, he came to understand that all three tasks were bound by a single number — the number Three.*

---

## The Mystery of the Thrice-Nine Kingdom

Every Russian child knows these words:

> "In a thrice-nine kingdom, in a thrice-ten realm..."

But have you ever wondered why exactly **thrice-nine**?

```
Thrice-nine = 3 × 9 = 27 = 3³
```

This is no random number. It is the **cube of three** — the maximum "threefoldness" that can be expressed in a single word.

And here's what's remarkable: when I was searching for the optimal threshold for a sorting algorithm, I arrived at... **27**.

The ancients knew.

---

## Three Roads

In every fairy tale, the hero encounters a stone at the crossroads:

> *"Go right — you will lose your horse,*
> *Go left — you will lose yourself,*
> *Go straight — you will find happiness."*

Three roads. Three choices. Three destinies.

In algorithms, this is called **3-way partition**:

```
┌─────────────────────────────────────────────────────────┐
│                                                         │
│   RIGHT (>)         STRAIGHT (=)    LEFT (<)            │
│   ─────────         ────────────    ────────            │
│   Greater than      Equal to        Less than           │
│   pivot             pivot           pivot               │
│                                                         │
│   Continue          STOP!           Continue            │
│   searching         Found it!       searching           │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

The middle road — the road of equality — **shortens the path**. Elements equal to the pivot need not be sorted further. They are already in their place.

This yields speedups of up to **291 times** on data with duplicates.

The ancients knew.

---

## Three Heroes

Ilya Muromets, Dobrynya Nikitich, Alyosha Popovich.

Strength, wisdom, cunning.

Three heroes together are stronger than each one alone. They **complement** each other.

In algorithms, this is called **Cuckoo Hashing with three tables**:

```
┌─────────────────────────────────────────────────────────┐
│                                                         │
│   ILYA (h₁)         DOBRYNYA (h₂)   ALYOSHA (h₃)        │
│   ─────────         ────────────    ───────────         │
│   First             Second          Third               │
│   hash function     hash function   hash function       │
│                                                         │
│   If occupied       If occupied     If occupied         │
│   → to Dobrynya     → to Alyosha    → to Ilya           │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

Two hash functions yield 50% fill rate.
Three hash functions yield **91% fill rate**.

Improvement: **82%**.

The ancients knew.

---

## Three Attempts

In fairy tales, the hero always gets three attempts:

- **First** — failure (learning)
- **Second** — near success (experience)
- **Third** — victory (mastery)

In graph algorithms, these are the **three states of a vertex**:

```
┌─────────────────────────────────────────────────────────┐
│                                                         │
│   WHITE             GRAY            BLACK               │
│   ─────             ────            ─────               │
│   Unvisited         In progress     Completed           │
│                                                         │
│   First             Second          Third               │
│   attempt           attempt         attempt             │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

Two states (visited/unvisited) cannot detect cycles.
Three states — can.

The ancients knew.

---

## Three Sons

In every fairy tale, the tsar has three sons:

- **Eldest** — strong but foolish
- **Middle** — cunning but cowardly
- **Youngest** (Ivan the Fool) — wise of heart

And the **third** always wins.

Why? Because the third is **special**. He does not follow the obvious paths. He finds the **unexpected solution**.

In algorithms, the third state — **equality** — is often ignored:

```
Standard quicksort:
  if a[i] < pivot: go left
  else: go right           ← Equal elements go RIGHT!

Trinity Sort:
  if a[i] < pivot: go left
  if a[i] > pivot: go right
  if a[i] = pivot: STOP!   ← Equal elements STAY!
```

"Ivan the Fool" (equality) turns out to be the key to victory.

The ancients knew.

---

## Three Worlds

In all mythologies, the world is divided into three:

- **Heaven** (Prav) — the world of gods, ideas, theory
- **Earth** (Yav) — the world of humans, practice, algorithms
- **Underworld** (Nav) — the world of ancestors, depths, implementation

This book follows the same structure:

```
┌─────────────────────────────────────────────────────────┐
│                                                         │
│   PART I: HEAVEN (Theory)                               │
│   ───────────────────────                               │
│   Why the number 3? Physics and mathematics.            │
│                                                         │
│   PART II: EARTH (Algorithms)                           │
│   ────────────────────────────                          │
│   Trinity Sort, Hash, Graph, Neural.                    │
│                                                         │
│   PART III: UNDERWORLD (Practice)                       │
│   ────────────────────────────────                      │
│   Benchmarks, code, implementation.                     │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---

## The Great Secret

Why have all cultures of the world independently arrived at the concept of trinity?

- Christianity: The Trinity
- Hinduism: Trimurti
- Buddhism: Three Jewels
- Taoism: Heaven-Human-Earth
- Slavs: Prav-Yav-Nav
- Greeks: Three Moirai
- Scandinavians: Three Norns

**The answer**: Because **3 is the minimum number for complex structure**.

```
2 — too simple (yes/no, 0/1)
3 — STRUCTURE emerges
4+ — redundant
```

Mathematically:

```
Optimal branching factor = e ≈ 2.718

Nearest integer = 3
```

This is not magic. This is **mathematics**.

But the ancients knew this **intuitively**, without formulas or proofs.

---

## An Invitation to the Journey

This book is a journey into the Thrice-Nine Kingdom.

I will walk the three roads of algorithms.
I will meet the three heroes of data structures.
I will receive three attempts to understand the depths.
And I will return with wisdom that the ancients always knew.

> *"A fairy tale is a lie, but within it lies a hint,*
> *a lesson for good young men."*
> — Alexander Pushkin

---

*And so, let us begin!*

*Into the thrice-nine kingdom of algorithms, into the thrice-ten realm of data...*

---

[Next: Chapter 1 — The Number Three →](01_number_three.md)
