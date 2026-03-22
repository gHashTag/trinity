# ═══════════════════════════════════════════════════════════════════════════════
# Tri Types — Type System Specification v0.2
# ═══════════════════════════════════════════════════════════════════════════════
#
# Pure ternary programming language
# 7 primitive types (vs Zig ~30, VIBEC ~37)
#
# φ² + 1/φ² = 3 | TRINITY
#
# ═══════════════════════════════════════════════════════════════════════════════

## PRIMITIVE TYPES (7)

### 1. trit — Atomic ternary unit
```
trit → {N, O, P}
```
- **N** (Negative): -1
- **O** (Zero): 0
- **P** (Positive): +1
- Size: 1.58 bits (log₂(3))
- Purpose: Atomic logic unit, three-valued logic

### 2. t3 — Tryte (3 trits)
```
t3 → [3]trit
```
- Range: [-13, +13] (3³ - 1) / 2
- Size: 4.75 bits (3 × 1.58)
- Purpose: Small integers, local variables
- Example: `t3 x = 0tPN0;` // +6

### 3. t9 — 9-trit type
```
t9 → [9]trit
```
- Range: [-9,841, +9,841] (3⁹ - 1) / 2
- Size: 14.22 bits (9 × 1.58)
- Purpose: Medium integers, loop counters
- Example: `t9 counter = 0tPNZONZOP;`

### 4. t27 — Tword (27 trits)
```
t27 → [27]trit
```
- Range: [-3.8 trillion, +3.8 trillion]
- Size: 42.7 bits (27 × 1.58)
- Purpose: Large integers, accumulator
- Example: `t27 accumulator = 0tPNO...;`

### 5. gf16 — Golden Float 16
```
gf16 → 16-bit floating point
```
- Format: 6-bit exponent, 9-bit mantissa, 1-bit sign
- Range: ~[-65504, +65504]
- Purpose: Weights, biases in neural networks
- Example: `gf16 weight = 0t1.234;`

### 6. tf3 — Ternary Float 9
```
tf3 → 9-bit floating point
```
- Format: 3-bit exponent, 5-bit mantissa, 1-bit sign
- Range: ~[-128, +127]
- Purpose: Compact weights for quantized models
- Example: `tf3 weight = 0t0.567;`

### 7. void — No return value
```
void → nothing
```
- Purpose: Functions without return value
- Example: `fn say_hello() void { ... }`

## COMPOSITE TYPES

### Array type
```
[N]Type
```
- Fixed-size array of N elements
- Example: `[243]trit` — array of 243 trits (for weights)

### Struct type
```
struct { field1: Type1, field2: Type2, ... }
```
- Composite data structure
- Example: `struct { weights: [243]gf16, bias: trit }`

## TYPE ALIAS

```
type WeightMatrix = [243]gf16;
type LayerInput = [243]trit;
```

## DEFAULT VALUES

| Type  | Default |
|-------|---------|
| trit  | O (zero) |
| t3    | 0t000 |
| t9    | 0t000000000 |
| t27   | 0t000...000 (27 zeros) |
| gf16  | 0.0 |
| tf3   | 0.0 |

## TYPE COERCION

- **trit → t3**: Automatic sign-extension
- **t3 → t9 → t27**: Automatic sign-extension
- **gf16 → tf3**: Truncation (loss of precision)
- **Integer → trit**: Modulo 3 (N/O/P mapping)

## MEMORY LAYOUT

| Type  | Bits | Bytes (approx) |
|-------|------|-----------------|
| trit  | 1.58 | 1 (packed) |
| t3    | 4.75 | 1 (packed) |
| t9    | 14.22| 2 (packed) |
| t27   | 42.7 | 6 (packed) |
| gf16  | 16   | 2 |
| tf3   | 9    | 2 (packed) |

## TYPE INFERENCE

```
let x: t3 = 0tPN;    // x has type t3
const y = x + x;     // y has type t3 (inferred)
let z = [243]trit;   // z has type [243]trit
```

# ═══════════════════════════════════════════════════════════════════════════════
# END OF TYPES
# ═══════════════════════════════════════════════════════════════════════════════
