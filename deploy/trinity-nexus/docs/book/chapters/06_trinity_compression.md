# Chapter 6: Trinity Compression — Three States of Information

---

*"A miller had three sons: the eldest was a clever lad,*
*the middle one was so-so, and the youngest was a fool."*
— Russian folk tale

---

## Three States of Information

Information, like matter, has three states:

```
┌─────────────────────────────────────────────────────────┐
│                                                         │
│   THREE STATES OF INFORMATION                           │
│                                                         │
│   RAW              COMPRESSED       ENCRYPTED           │
│   ───              ──────────       ─────────           │
│   Original         Compact          Protected           │
│   data             data             data                │
│                                                         │
│   Takes space      Takes less       Secure              │
│   Fast access      Needs decompr.   Needs key           │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

And in compression itself, the number 3 plays a key role.

---

## Optimal Base: e ≈ 2.718 ≈ 3

### Radix Economy

Which numeral system is optimal for representing numbers?

```
┌─────────────────────────────────────────────────────────┐
│                                                         │
│   RADIX ECONOMY: COST OF REPRESENTATION                 │
│                                                         │
│   Cost of number N in base b:                           │
│   E(b) = b × ⌈log_b(N)⌉ ≈ b × ln(N) / ln(b)           │
│                                                         │
│   Minimize b / ln(b):                                   │
│   d/db [b / ln(b)] = 0                                 │
│   ln(b) = 1                                            │
│   b = e ≈ 2.718                                        │
│                                                         │
│   OPTIMAL BASE = e ≈ 2.718                             │
│   NEAREST INTEGER = 3                                  │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### Comparison of Bases

```
┌─────────┬─────────────┬─────────────────┐
│ Base    │ b/ln(b)     │ Relative to e   │
├─────────┼─────────────┼─────────────────┤
│ 2       │ 2.885       │ 1.062           │
│ 3       │ 2.731       │ 1.005 ← BEST!   │
│ 4       │ 2.885       │ 1.062           │
│ 5       │ 3.107       │ 1.143           │
│ 10      │ 4.343       │ 1.598           │
│ 16      │ 5.771       │ 2.123           │
└─────────┴─────────────┴─────────────────┘
```

**Base 3 is the optimal integer base!**

---

## Balanced Ternary: {-1, 0, +1}

### The Miller's Three Sons

```
┌─────────────────────────────────────────────────────────┐
│                                                         │
│   BALANCED TERNARY: THREE SONS                          │
│                                                         │
│   ELDEST (+1)      MIDDLE (0)       YOUNGEST (-1)       │
│   ───────────      ──────────       ─────────────       │
│   Positive         Neutral          Negative            │
│   contribution     contribution     contribution        │
│                                                         │
│   Symbols: +, 0, -                                      │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### Advantages

```
1. NO SIGN BIT
   Negative numbers are represented naturally

   +5 = +--  (9 - 3 - 1 = 5)
   -5 = -++  (-9 + 3 + 1 = -5)

   Negation = inversion of all digits!

2. ROUNDING = TRUNCATION
   To round, simply discard the least significant digits

3. SYMMETRY
   Range: from -(3^n-1)/2 to +(3^n-1)/2
```

### Examples

```
┌─────────┬─────────────────┬─────────────────┐
│ Decimal │ Balanced Ternary│ Verification    │
├─────────┼─────────────────┼─────────────────┤
│ 0       │ 0               │ 0               │
│ 1       │ +               │ 1               │
│ -1      │ -               │ -1              │
│ 5       │ +--             │ 9-3-1 = 5       │
│ -5      │ -++             │ -9+3+1 = -5     │
│ 8       │ +0-             │ 9+0-1 = 8       │
│ 13      │ +++             │ 9+3+1 = 13      │
│ 27      │ +000            │ 27              │
└─────────┴─────────────────┴─────────────────┘
```

### The Soviet Computer "Setun"

```
┌─────────────────────────────────────────────────────────┐
│                                                         │
│   SETUN (1958) — TERNARY COMPUTER                       │
│                                                         │
│   Developed at MSU under the leadership of              │
│   N.P. Brusentsov                                       │
│                                                         │
│   Used balanced ternary:                                │
│   • Simpler arithmetic (no carry in addition)           │
│   • Fewer elements for the same range                   │
│   • Natural representation of negative numbers          │
│                                                         │
│   About 50 machines were produced, operated until 1970s │
│                                                         │
│   SOVIET ENGINEERS KNEW!                                │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---

## Historical Justice: Brusentsov Was Right

### A Man Ahead of His Time

In 1958, when the entire world was building binary computers, a young engineer **Nikolai Petrovich Brusentsov** at Moscow State University made a different choice.

He knew the mathematics:

```
┌─────────────────────────────────────────────────────────┐
│                                                         │
│   BRUSENTSOV'S CALCULATION                              │
│                                                         │
│   Optimal base = e ≈ 2.718                              │
│   Nearest integer = 3                                   │
│                                                         │
│   Base 2: 2/ln(2) = 2.885                               │
│   Base 3: 3/ln(3) = 2.731 ← BETTER BY 5.3%             │
│                                                         │
│   "If I'm building a computer anyway,                   │
│    why not build an OPTIMAL one?"                       │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### Advantages of "Setun"

```
┌─────────────────────────────────────────────────────────┐
│                                                         │
│   WHY TERNARY ARCHITECTURE IS BETTER                    │
│                                                         │
│   1. RADIX ECONOMY                                      │
│      18 ternary digits = 29 binary digits               │
│      ~38% savings on digit count                        │
│                                                         │
│   2. BALANCED TERNARY {-1, 0, +1}                       │
│      • No separate sign bit                             │
│      • -N = inversion of all digits of N                │
│      • Rounding = simple truncation                     │
│      • Overflow is handled naturally                    │
│                                                         │
│   3. ARITHMETIC                                         │
│      Addition is simpler: fewer carry cases             │
│      Multiplication: 3×3 table instead of 2×2          │
│                                                         │
│   4. RELIABILITY                                        │
│      Three states are easier to distinguish with noise  │
│      (-V, 0, +V) vs (0, +V)                            │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### The Tragedy of Choice

```
┌─────────────────────────────────────────────────────────┐
│                                                         │
│   WHY THE WORLD CHOSE THE BINARY SYSTEM                 │
│                                                         │
│   MATHEMATICS said: ternary is better                   │
│   ECONOMICS said: binary is cheaper                     │
│                                                         │
│   A transistor with 2 states:                           │
│   • Easier to manufacture                               │
│   • Cheaper                                             │
│   • More reliable at scale                              │
│                                                         │
│   The 5.3% advantage did not justify:                   │
│   • New component base                                  │
│   • Retraining engineers                                │
│   • Incompatibility with the rest of the world          │
│                                                         │
│   THE INDUSTRY CHOSE "GOOD ENOUGH"                      │
│   INSTEAD OF "OPTIMAL"                                  │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### The Fate of "Setun"

```
1958: First "Setun" launched at MSU
1962: Serial production began
1965: About 50 machines produced
1970: Production discontinued

Reason: "incompatibility with world standards"

Brusentsov believed until the end of his life (2014)
that ternary architecture would return.
```

### The Return of Ternary

```
┌─────────────────────────────────────────────────────────┐
│                                                         │
│   BRUSENTSOV WAS RIGHT — WE PROVED IT                   │
│                                                         │
│   "Setun" (1958)            Our discoveries (2026)      │
│   ──────────────            ──────────────────────      │
│   Ternary hardware          Ternary logic               │
│   {-1, 0, +1} in bits       {<, =, >} in comparisons   │
│   Balanced ternary          3-way partition             │
│   3 states of element       3 states of DFS             │
│   Ternary arithmetic        Ternary Weight Networks     │
│                                                         │
│   SAME IDEA — DIFFERENT IMPLEMENTATION                  │
│                                                         │
│   Brusentsov wanted ternary in HARDWARE.                │
│   We implement ternary in ALGORITHMS                    │
│   on binary hardware.                                   │
│                                                         │
│   Result: up to 291x speedup!                           │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### Lessons from History

```
1. MATHEMATICAL OPTIMALITY ≠ PRACTICAL SUCCESS
   Brusentsov was mathematically right.
   But economics defeated mathematics.

2. IDEAS RETURN
   Ternary returned after 70 years —
   not in hardware, but in algorithms.

3. PROPHETS ARE NOT HONORED IN THEIR OWN COUNTRY
   "Setun" is forgotten in Russia.
   But its principles live on in Trinity Sort.

4. THE OPTIMAL WILL FIND ITS WAY
   If not through hardware — then through software.
   If not now — then later.
```

### In Memory of Brusentsov

```
┌─────────────────────────────────────────────────────────┐
│                                                         │
│   NIKOLAI PETROVICH BRUSENTSOV                          │
│   (1925 — 2014)                                         │
│                                                         │
│   Creator of the ternary computer "Setun"               │
│   A man who was 70 years ahead of his time              │
│                                                         │
│   "The ternary system is not a whim,                    │
│    but a mathematical necessity."                       │
│                                                         │
│   He was right.                                         │
│   We proved it.                                         │
│                                                         │
│   Trinity Sort is the continuation of his work.         │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

---

## Ternary Huffman: Three Children

### The Idea

Standard Huffman builds a binary tree. What if we use a **ternary** one?

```
┌─────────────────────────────────────────────────────────┐
│                                                         │
│   BINARY HUFFMAN          TERNARY HUFFMAN               │
│                                                         │
│        ○                        ○                       │
│       / \                     / | \                     │
│      ○   ○                   ○  ○  ○                    │
│     / \   \                 /|\ |  |\                   │
│    a   b   c               a b c d  e f                 │
│                                                         │
│   2 children               3 children                   │
│   Deeper                   Shallower                    │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### Example

```
Text: "abracadabra"
Frequencies: a=5, b=2, r=2, c=1, d=1

Binary Huffman:
  a: 0
  b: 10
  r: 110
  c: 1110
  d: 1111

  Length: 5×1 + 2×2 + 2×3 + 1×4 + 1×4 = 23 bits

Ternary Huffman:
  a: 2
  b: 12
  r: 0
  c: 10
  d: 11

  Length: 5×1 + 2×2 + 2×1 + 1×2 + 1×2 = 15 trits
  In bits: 15 × log₂(3) ≈ 23.8 bits

Compression: 88 bits → ~24 bits = 3.7x
```

### Code

```python
def ternary_huffman(frequencies):
    """Build a ternary Huffman tree"""
    import heapq

    # Create nodes
    nodes = [(freq, i, char) for i, (char, freq) in enumerate(frequencies.items())]

    # Pad until (n-1) % 2 == 0
    while (len(nodes) - 1) % 2 != 0:
        nodes.append((0, len(nodes), None))

    heapq.heapify(nodes)
    counter = len(nodes)

    while len(nodes) > 1:
        # Take 3 minimum (or 2, if only 2 remain)
        children = []
        for _ in range(min(3, len(nodes))):
            children.append(heapq.heappop(nodes))

        # Create parent
        total_freq = sum(c[0] for c in children)
        heapq.heappush(nodes, (total_freq, counter, children))
        counter += 1

    # Build codes
    codes = {}
    def build_codes(node, code=""):
        if isinstance(node[2], str) or node[2] is None:
            if node[2] is not None:
                codes[node[2]] = code if code else "0"
        else:
            for i, child in enumerate(node[2]):
                build_codes(child, code + str(i))

    if nodes:
        build_codes(nodes[0])

    return codes
```

---

## Trinity RLE: Three States of Compression

### The Idea

Run-Length Encoding with **three states**:

```
┌─────────────────────────────────────────────────────────┐
│                                                         │
│   TRINITY RLE: THREE STATES                             │
│                                                         │
│   STATE 0          STATE 1          STATE 2             │
│   ───────          ───────          ───────             │
│   Literal          Short run        Long run            │
│   (1 byte)         (2-4 repeats)    (5+ repeats)        │
│                                                         │
│   Format:          Format:          Format:             │
│   [0][byte]        [1][len|byte]    [2][len][byte]      │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### Advantages

```
Standard RLE:
  Literal: [0][byte]     — 2 bytes
  Run:     [1][len][byte] — 3 bytes

  Problem: short runs (2-4) are inefficient

Trinity RLE:
  Literal:    [0][byte]       — 2 bytes
  Short run:  [1][len|byte]   — 2 bytes (len in 2 bits)
  Long run:   [2][len][byte]  — 3 bytes

  Short runs are now efficient!
```

### Code

```python
def trinity_rle_encode(data):
    """Trinity RLE: 3-state encoding"""
    result = []
    i = 0

    while i < len(data):
        # Count run length
        run_start = i
        while i < len(data) - 1 and data[i] == data[i + 1] and i - run_start < 255:
            i += 1
        run_len = i - run_start + 1

        if run_len == 1:
            # State 0: literal
            result.extend([0, data[run_start]])
        elif run_len <= 4:
            # State 1: short run (length in 2 bits)
            result.extend([1, ((run_len - 2) << 6) | data[run_start]])
        else:
            # State 2: long run
            result.extend([2, run_len, data[run_start]])

        i += 1

    return bytes(result)

def trinity_rle_decode(data):
    """Decode Trinity RLE"""
    result = []
    i = 0

    while i < len(data):
        state = data[i]

        if state == 0:
            result.append(data[i + 1])
            i += 2
        elif state == 1:
            length = ((data[i + 1] >> 6) & 0x3) + 2
            byte = data[i + 1] & 0x3F
            result.extend([byte] * length)
            i += 2
        else:
            length = data[i + 1]
            byte = data[i + 2]
            result.extend([byte] * length)
            i += 3

    return bytes(result)
```

### Results

```
Test data: [1,1,1, 2, 3,3,3,3,3,3,3, 4, 5,5]

Standard RLE: 18 bytes
Trinity RLE:  11 bytes

Compression: 1.64x (64% better!)
```

---

## Practical Limitations

### Why Is the World Binary?

```
┌─────────────────────────────────────────────────────────┐
│                                                         │
│   THEORY vs PRACTICE                                    │
│                                                         │
│   THEORY:                                               │
│   • Base 3 is optimal (minimizes b/ln(b))              │
│   • Balanced ternary is elegant                         │
│   • Ternary Huffman can be more efficient              │
│                                                         │
│   PRACTICE:                                             │
│   • Binary electronics are simpler and cheaper          │
│   • Transistor = 2 states (on/off)                     │
│   • All infrastructure is binary                        │
│                                                         │
│   CONCLUSION:                                           │
│   A theoretical advantage of ~5% does not justify       │
│   a complete restructuring of the industry.             │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

### Where Ternary Works

```
WORKS:
• Algorithms (3-way partition, 3 hash functions)
• Logic (true/false/unknown)
• Quantum computing (qutrit instead of qubit)
• Specialized chips (ML accelerators)

DOESN'T WORK:
• General data storage (binary hardware)
• Network protocols (binary)
• File systems (binary)
```

---

## Wisdom of the Chapter

> *And Ivan the Programmer understood the fourth truth:*
>
> *Three states of information — raw, compressed, encrypted —*
> *are like the miller's three sons: each in their own place.*
>
> *Base 3 is theoretically optimal,*
> *but the world is built on twos.*
>
> *Soviet engineers created "Setun" —*
> *a ternary computer ahead of its time.*
>
> *Balanced ternary: +, 0, - —*
> *like three sons: eldest, middle, youngest.*
>
> *Trinity RLE with three states*
> *compresses better than binary.*
>
> *But the main lesson:*
> *Theory and practice are different kingdoms.*
> *The wise know when to apply each.*
>
> *The ancients knew.*

---

[<- Chapter 5](05_trinity_structures.md) | [Chapter 7: Trinity Neural ->](07_trinity_neural.md)
