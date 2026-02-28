---
sidebar_position: 3
---

# TVCBigInt API

Balanced Ternary Arbitrary-Precision Arithmetic.

**Module:** `src/bigint.zig`

## Overview

TVCBigInt provides arbitrary-precision arithmetic using balanced ternary representation. Unlike binary systems that use {0, 1}, balanced ternary uses {-1, 0, +1} trits, offering unique advantages:

- **No separate sign bit**: Sign is inherent in the representation
- **Simpler rounding**: Truncation = rounding to nearest
- **Symmetric range**: Even distribution around zero
- **Maximum precision**: Supports numbers up to 3^256 ≈ 10^122

The implementation uses SIMD (AVX2) for parallel processing of 32 trits at a time, with automatic fallback to scalar operations for smaller numbers.

## Core Types

### TVCBigInt

```zig
pub const TVCBigInt = struct {
    trits: [MAX_TRITS]Trit,  // Trit array (least significant first)
    len: usize,               // Number of significant trits
};
```

### Trit Type

```zig
pub const Trit = i8;
pub const NEG: Trit = -1;   // Negative trit
pub const ZERO: Trit = 0;   // Zero trit
pub const POS: Trit = 1;    // Positive trit
```

### Constants

| Constant | Value | Description |
|----------|-------|-------------|
| `MAX_TRITS` | 256 | Maximum trits (supports 3^256) |
| `SIMD_CHUNKS` | 8 | Number of 32-trit chunks (256/32) |
| `Vec32i8` | @Vector(32, i8) | SIMD type for 32 trits |
| `Vec32i16` | @Vector(32, i16) | SIMD type for wide operations |

## Core Operations

### zero() → TVCBigInt

Creates a zero value.

```zig
var z = TVCBigInt.zero();
```

### fromI64(value: i64) → TVCBigInt

Converts a 64-bit integer to balanced ternary.

```zig
const big = TVCBigInt.fromI64(12345);
const neg_big = TVCBigInt.fromI64(-9999);
```

**Algorithm:**
1. Extract remainder in range -1..1
2. Adjust: if remainder is 2, convert to -1
3. Divide value by 3 using floor division
4. Repeat until value is zero

### toI64() → i64

Converts balanced ternary to 64-bit integer. May overflow for large numbers.

```zig
const big = TVCBigInt.fromI64(1000000);
const value = big.toI64();  // 1000000
```

### isZero() → bool

Checks if the value is zero.

```zig
if (big.isZero()) {
    // Handle zero case
}
```

### isNegative() → bool

Checks if the value is negative. In balanced ternary, sign is determined by the most significant trit.

```zig
if (big.isNegative()) {
    // Value is negative
}
```

## Arithmetic Operations

### add(a, b) → TVCBigInt

Adds two BigInts. Automatically chooses between SIMD (≥64 trits) and scalar paths.

```zig
const a = TVCBigInt.fromI64(123);
const b = TVCBigInt.fromI64(456);
const sum = a.add(&b);  // 579
```

**Performance:**
- **Scalar**: O(n) where n = max(len(a), len(b))
- **SIMD**: Processes 32 trits in parallel (AVX2)

**Implementation:**
1. Add corresponding trits with carry
2. Normalize results to balanced ternary range
3. Handle overflow: values > +1 wrap with carry +1, values < -1 wrap with carry -1

### sub(a, b) → TVCBigInt

Subtracts two BigInts using addition: `a - b = a + (-b)`

```zig
const a = TVCBigInt.fromI64(1000);
const b = TVCBigInt.fromI64(300);
const diff = a.sub(&b);  // 700
```

### mul(a, b) → TVCBigInt

Multiplies two BigInts using Karatsuba algorithm for large numbers.

```zig
const a = TVCBigInt.fromI64(12345);
const b = TVCBigInt.fromI64(67890);
const product = a.mul(&b);  // 838102050
```

**Algorithms:**

| Size | Algorithm | Complexity |
|------|-----------|------------|
| ≤32 trits | Grade-school | O(n²) |
| >32 trits | Karatsuba | O(n^1.585) |

**Karatsuba Optimization:**
- Splits numbers at midpoint: `a = a1 * 3^m + a0`
- Uses 3 multiplications instead of 4
- Recursive decomposition with base case at 32 trits

### divRem(a, b) → DivResult

Divides two BigInts with remainder.

```zig
const a = TVCBigInt.fromI64(100);
const b = TVCBigInt.fromI64(7);
const result = a.divRem(&b);

result.q;  // Quotient: 14
result.r;  // Remainder: 2
```

**Result Type:**
```zig
pub const DivResult = struct {
    q: TVCBigInt,  // Quotient
    r: TVCBigInt,  // Remainder
};
```

**Implementation:**
- **Small numbers (≤40 trits)**: Convert to i64, use native division
- **Large numbers**: Long division with balanced ternary logic
  - Try quotient trits +1, 0, -1 at each position
  - Subtract when remainder ≥ divisor
  - Track sign adjustments for negative operands

### div(a, b) → TVCBigInt

Division (quotient only).

```zig
const quotient = a.div(&b);
```

### mod(a, b) → TVCBigInt

Modulo (remainder only).

```zig
const remainder = a.mod(&b);
```

### negate() → TVCBigInt

Negates a BigInt by flipping all trits.

```zig
const a = TVCBigInt.fromI64(123);
const neg_a = a.negate();  // -123
```

### abs() → TVCBigInt

Returns absolute value.

```zig
const a = TVCBigInt.fromI64(-999);
const abs_a = a.abs();  // 999
```

## SIMD Operations

### simdAddTrits

```text
simdAddTrits(a, b) → { sum, overflow }
```

SIMD addition of 32 trits in parallel. Returns sum and overflow vectors.

```zig
const a_vec: Vec32i8 = @splat(0);
const b_vec: Vec32i8 = @splat(1);

const result = simdAddTrits(a_vec, b_vec);
// result.sum = 32-element sum vector
// result.overflow = 32-element carry vector
```

### simdCompareTrits(a, b) → Vec32i8

SIMD comparison of 32 trits. Returns -1, 0, or +1 for each element.

```zig
const cmp = simdCompareTrits(a_vec, b_vec);
// cmp[i] = -1 if a[i] < b[i]
// cmp[i] =  0 if a[i] == b[i]
// cmp[i] = +1 if a[i] > b[i]
```

### simdNormalize

```text
simdNormalize(v) → { normalized, carry }
```

Brings SIMD vector values to -1..+1 range with carry propagation.

```zig
const result = simdNormalize(wide_vec);
// result.normalized = values in [-1, +1]
// result.carry = carries for each position
```

### simdNegate(v) → Vec32i8

Flips signs of all 32 trits in parallel.

```zig
const negated = simdNegate(positive_vec);
```

### simdSum(v) → i32

Horizontal sum of SIMD vector (reduction).

```zig
const sum = simdSum(vec);  // Sum of all 32 elements
```

### simdIsZero(v) → bool

Checks if SIMD vector is all zeros.

```zig
if (simdIsZero(vec)) {
    // All trits are zero
}
```

## Comparison Operations

### compareAbs(a, b) → i8

Compares absolute values. Returns -1 if |a| < |b|, 0 if equal, +1 if |a| > |b|.

```zig
const cmp = a.compareAbs(&b);
if (cmp > 0) {
    // |a| > |b|
}
```

**Implementation:**
- **Small numbers (&lt;64 trits)**: Scalar comparison
- **Large numbers (≥64 trits)**: SIMD chunk comparison from most significant

## Shift Operations

### shiftLeft(n) → TVCBigInt

Multiplies by 3^n (shifts trits left by n positions).

```zig
const a = TVCBigInt.fromI64(10);
const shifted = a.shiftLeft(2);  // 10 * 9 = 90
```

**Use Cases:**
- Fast multiplication by powers of 3
- Position alignment in Karatsuba algorithm
- Building large numbers from components

### shiftRight(n) → TVCBigInt

Divides by 3^n with truncation (shifts trits right by n positions).

```zig
const a = TVCBigInt.fromI64(27);
const shifted = a.shiftRight(1);  // 27 / 3 = 9
```

## Formatting Operations

### format(allocator) → []u8

Formats as balanced ternary string.

```zig
const big = TVCBigInt.fromI64(5);
const ternary = try big.format(allocator);
// Result: "1TT" (1*9 + (-1)*3 + (-1)*1 = 9 - 3 - 1 = 5)
```

**Notation:**
- `T` = -1 (traditional notation)
- `0` = 0
- `1` = +1

### formatDecimal(allocator) → []u8

Formats as decimal string.

```zig
const decimal = try big.formatDecimal(allocator);
// Result: "12345"
```

**Implementation:**
- Small numbers (≤40 trits): Use `toI64()` and native formatting
- Large numbers: Repeated division by 10 (simplified in current version)

## Advanced Operations

### divNewton(a, b) → DivResult

Newton-Raphson division for very large numbers. Computes reciprocal approximation iteratively.

```zig
const a = TVCBigInt.fromI64(1000000);
const b = TVCBigInt.fromI64(1234);
const result = a.divNewton(&b);
```

**Algorithm:**
1. Initial guess: x ≈ 3^(precision - len(b) + 1)
2. Iterate: `x_{n+1} = x_n * (2 - b * x_n / 3^precision)`
3. Max 10 iterations (typically converges in 3-5)
4. Adjust remainder if out of range

**Advantages:**
- Faster than long division for very large numbers
- O(n^2) vs O(n^2 log n) for naive division
- Better numerical properties

### newtonReciprocal(b, precision) → TVCBigInt

Computes approximation of 3^precision / b using Newton-Raphson iteration.

```zig
const recip = TVCBigInt.newtonReciprocal(&b, 100);
```

**Convergence:**
- Quadratic convergence (doubles correct digits per iteration)
- Typical: 5-10 iterations for full precision
- Early exit when change < threshold

## Memory Management

### Storage

TVCBigInt uses fixed-size array storage:
- **Size**: 256 trits × 1 byte = 256 bytes
- **Alignment**: Natural alignment (1 byte)
- **Allocation**: Stack allocation for typical use
- **No heap allocation** for normal operations

### Normalization

```zig
fn normalize(self: *Self) void
```

Removes leading zeros to minimize `len` field. Called automatically after arithmetic operations.

## Performance Characteristics

### Operation Complexity

| Operation | Complexity | Notes |
|-----------|------------|-------|
| Addition | O(n) | SIMD: 32x parallel |
| Subtraction | O(n) | Via negation + addition |
| Multiplication | O(n^1.585) | Karatsuba for n > 32 |
| Division | O(n^2) | Newton-Raphson for large n |
| Comparison | O(n) | Early exit on mismatch |

### SIMD Speedup

From benchmarks (64+ trit numbers):
- **Addition**: 1.5-2x speedup vs scalar
- **Comparison**: 2-3x speedup vs scalar
- **Best case**: Numbers with minimal carry propagation

### Memory Efficiency

| Representation | Bits per Trit | Storage (256 trits) |
|----------------|---------------|---------------------|
| Binary (naive) | 2 bits | 64 bytes |
| **Balanced Ternary** | **1.58 bits (log₂3)** | **~50 bytes** |
| Unpacked (byte) | 8 bits | 256 bytes |

**Current Implementation**: Uses unpacked (8 bits/trit) for speed. Packed storage available in `HybridBigInt`.

## Usage Examples

### Basic Arithmetic

```zig
const std = @import("std");
const bigint = @import("bigint");

pub fn main() !void {
    // Create numbers
    const a = bigint.TVCBigInt.fromI64(12345);
    const b = bigint.TVCBigInt.fromI64(67890);

    // Arithmetic
    const sum = a.add(&b);
    const diff = a.sub(&b);
    const product = a.mul(&b);

    // Division with remainder
    const result = a.divRem(&b);

    std.debug.print("a + b = {}\n", .{sum.toI64()});
    std.debug.print("a - b = {}\n", .{diff.toI64()});
    std.debug.print("a * b = {}\n", .{product.toI64()});
    std.debug.print("a / b = {} rem {}\n", .{
        result.q.toI64(),
        result.r.toI64()
    });
}
```

### Large Number Computation

```zig
// Compute factorial beyond i64 range
fn factorial(n: u64) !bigint.TVCBigInt {
    var result = bigint.TVCBigInt.fromI64(1);
    var i: u64 = 2;

    while (i <= n) : (i += 1) {
        const term = bigint.TVCBigInt.fromI64(@intCast(i));
        result = result.mul(&term);
    }

    return result;
}

// Compute 100! (beyond i64 range)
const fact_100 = try factorial(100);
```

### Balanced Ternary Conversion

```zig
const value = bigint.TVCBigInt.fromI64(100);
const ternary = try value.format(allocator);
std.debug.print("100 in balanced ternary: {s}\n", .{ternary});
// Output: "11T01" (1*81 + 1*27 + (-1)*9 + 0*3 + 1*1 = 81 + 27 - 9 + 0 + 1 = 100)
```

### Iterative Operations

```zig
// Fibonacci sequence using BigInt
fn fibonacci(n: usize) bigint.TVCBigInt {
    if (n == 0) return bigint.TVCBigInt.fromI64(0);
    if (n == 1) return bigint.TVCBigInt.fromI64(1);

    var prev = bigint.TVCBigInt.fromI64(0);
    var curr = bigint.TVCBigInt.fromI64(1);

    var i: usize = 2;
    while (i <= n) : (i += 1) {
        const next = prev.add(&curr);
        prev = curr;
        curr = next;
    }

    return curr;
}

const fib_1000 = fibonacci(1000);  // Far beyond i64 range
```

## When to Use TVCBigInt

### Use Cases

| Scenario | Recommended |
|----------|-------------|
| Numbers beyond i64 range | **TVCBigInt** |
| Cryptographic calculations | **TVCBigInt** |
| Arbitrary-precision math | **TVCBigInt** |
| Small integers (&lt; 2^63) | Native i64 |
| Performance-critical loops | Native i64 + fallback |
| VSA hypervector operations | HybridBigInt (packed) |

### Integration with Other Modules

**With VSA (`vsa.zig`):**
```zig
// VSA uses HybridBigInt internally
// Convert to/from TVCBigInt for large-scale arithmetic
const hv = vsa.Hypervector.random(10000);
const big_value = hv.toBigInt();
```

**With Hybrid BigInt (`hybrid.zig`):**
```zig
// Use HybridBigInt for memory efficiency
// Use TVCBigInt for computation-intensive operations
const packed = HybridBigInt.random(1000);
packed.ensureUnpacked();  // Convert to unpacked form
const result = packed.add(&other);
```

## Mathematical Foundation

### Balanced Ternary Representation

A number N is represented as:
```
N = Σ(trit[i] × 3^i) for i = 0 to n-1
```

**Example:** 100 in balanced ternary
```
100 = 1×81 + 1×27 + (-1)×9 + 0×3 + 1×1
    = 1×3^4 + 1×3^3 + (-1)×3^2 + 0×3^1 + 1×3^0
    = "11T01"
```

### Trinity Identity Connection

The balanced ternary system is deeply connected to the Trinity Identity:
```
φ² + 1/φ² = 3
```

This elegant relationship between φ (golden ratio) and the base 3 underpins the mathematical beauty of balanced ternary arithmetic.

## Performance Tips

1. **Use native i64 when possible**: TVCBigInt has overhead for small numbers
2. **Batch operations**: Minimize conversions between representations
3. **Reuse allocations**: Format operations can allocate; reuse buffers when possible
4. **Let the algorithm choose**: Don't force scalar/SIMS paths; add() decides automatically
5. **Consider packed storage**: For storage, use HybridBigInt with pack()

## Limitations

| Limitation | Value | Notes |
|------------|-------|-------|
| Max trits | 256 | Supports 3^256 ≈ 10^122 |
| i64 overflow | 2^63-1 | Use toI64() carefully for large numbers |
| Division by zero | Returns zeros | No error handling (check with isZero() first) |
| Decimal formatting | Simplified | Full implementation pending |

## Testing

Run BigInt tests:
```bash
zig test src/bigint.zig
```

Run benchmarks:
```bash
zig build bigint-bench
# Or directly:
zig run src/bigint.zig
```

## See Also

- **Hybrid API**: Memory-efficient packed storage
- **VSA API**: Vector Symbolic Architecture operations
- **Concepts**: Balanced Ternary fundamentals
- **Math Foundations**: Proofs and formulas

---

**Next**: Learn about the [Hybrid API](/docs/api/hybrid) for memory-efficient packed trit storage.
