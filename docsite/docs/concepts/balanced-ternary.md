---
sidebar_position: 2
---

# Balanced Ternary Arithmetic

## Trits and Bits

A **trit** (ternary digit) is the fundamental unit of ternary computing. While a binary digit (bit) can represent two states (0 or 1), a trit represents three states. In **balanced ternary**, these states are \{-1, 0, +1\}, often written as \{T, 0, 1\} or \{-, 0, +\} for brevity.

The information content of a single trit is log2(3) = 1.585 bits. This means each trit carries approximately 58.5% more information than a single bit. To represent the same range of N values, you need ceiling(log3(N)) trits versus ceiling(log2(N)) bits -- fewer symbols, each doing more work.

| Unit | States | Information Content |
|------|--------|-------------------|
| Bit  | 2      | 1.000 bits        |
| Trit | 3      | 1.585 bits        |

## Balanced vs. Unbalanced Ternary

Standard (unbalanced) ternary uses the digit set \{0, 1, 2\}, analogous to how binary uses \{0, 1\}. Balanced ternary instead uses \{-1, 0, +1\}, centering the digit values symmetrically around zero. This seemingly small change has profound consequences:

- **Signed numbers need no special encoding.** In binary, representing negative numbers requires conventions like two's complement. In balanced ternary, negative numbers arise naturally -- the number -5 in balanced ternary is simply the negation of +5, obtained by flipping every trit.
- **No wasted representations.** Two's complement binary has an asymmetry: an n-bit number can represent one more negative value than positive. Balanced ternary with n trits represents values symmetrically from -(3^n - 1)/2 to +(3^n - 1)/2.
- **Truncation equals rounding.** Dropping the least significant trits of a balanced ternary number rounds to the nearest representable value, not toward zero as in binary.

## Basic Arithmetic Operations

### Ternary Addition

Addition in balanced ternary follows the same column-by-column logic as binary addition, but with three possible values per position. The addition table:

| +   | -1 |  0 | +1 |
|-----|----|----|-----|
| -1  | -1, carry -1 | -1 |  0 |
|  0  | -1 |  0 | +1 |
| +1  |  0 | +1 | +1, carry +1 |

When the sum of two trits exceeds +1 or falls below -1, a carry propagates to the next position. For example, (+1) + (+1) = -1 with a carry of +1 (since 1 + 1 = 2, and 2 in balanced ternary is "1T", meaning +1 in the next position and -1 in the current position).

### Ternary Multiplication

Multiplication by a single trit is trivial:

| x   | -1 |  0 | +1 |
|-----|----|----|-----|
| -1  | +1 |  0 | -1 |
|  0  |  0 |  0 |  0 |
| +1  | -1 |  0 | +1 |

This is standard integer multiplication restricted to \{-1, 0, +1\}:
- Multiplying by **+1** leaves the value unchanged (identity).
- Multiplying by **-1** negates the value (sign flip).
- Multiplying by **0** produces zero (annihilation).

This property is critical for neural network inference. When model weights are ternary, matrix-vector multiplication reduces to additions and subtractions -- no floating-point multipliers are needed.

### Negation

To negate a balanced ternary number, flip the sign of every trit:

```
  +1  0 -1 +1    (the number +7 in balanced ternary)
  -1  0 +1 -1    (the number -7 -- just flip all signs)
```

This is simpler than binary negation (which requires inverting all bits and adding one) and never produces edge cases or overflow.

## Ternary Encoding in Trinity

Trinity represents trits in memory using a compact **packed encoding** that stores each trit in 2 bits. The mapping is:

| Trit Value | 2-bit Encoding |
|-----------|----------------|
| -1 (T)    | `00`           |
|  0        | `01`           |
| +1        | `10`           |

This encoding uses 2 bits per trit, achieving an effective density of 1.585 / 2 = 79.3% of the theoretical maximum. While not perfectly optimal (the theoretical minimum is log2(3) = 1.585 bits per trit), the 2-bit encoding enables fast bitwise operations and aligns naturally with byte boundaries.

The [HybridBigInt](/docs/api/hybrid) type in Trinity manages this encoding transparently. It maintains two representations: a **packed** form for memory-efficient storage and an **unpacked** form (an array of individual trit values) for fast computation. Conversions between the two are performed lazily -- only when needed -- and are cached to avoid redundant work.

With this encoding, a 256-trit vector (a common dimension in Trinity's VSA operations) occupies just 64 bytes in packed form, compared to 256 bytes if each trit were stored in a full byte, or 1024 bytes if stored as 32-bit floats.

## Comparison with Binary

| Property | Binary | Balanced Ternary |
|----------|--------|-----------------|
| Digit values | \{0, 1\} | \{-1, 0, +1\} |
| Info per digit | 1.000 bits | 1.585 bits |
| Radix economy | 2.885 (94.7%) | 2.731 (100%) |
| Negation | Invert + add 1 | Flip all signs |
| Signed numbers | Two's complement | Native |
| Truncation | Rounds toward zero | Rounds to nearest |
| Multiplication | Full multiply | Add/subtract only (for single trit) |

## Applications in Trinity

The balanced ternary representation is the foundation of every subsystem in Trinity:

- **VSA operations** ([bind, unbind, bundle](/docs/api/vsa)) operate element-wise on ternary vectors. Binding uses trit multiplication; unbinding is identical to binding (the operation is its own inverse for non-zero trits).
- **BitNet inference** ([Firebird](/docs/api/firebird)) quantizes LLM weights to \{-1, 0, +1\}, turning matrix multiplications into accumulations.
- **The Ternary VM** ([VM](/docs/api/vm)) executes bytecode with a ternary instruction set, operating on ternary stack values.

## Further Reading

- [Ternary Computing Concepts](/docs/concepts) -- overview and motivation
- [The Trinity Identity](/docs/concepts/trinity-identity) -- why the golden ratio connects to base-3
- [VSA API Reference](/docs/api/vsa) -- ternary vector operations
- [HybridBigInt API Reference](/docs/api/hybrid) -- packed trit storage
