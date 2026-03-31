# tri math transcendental_fn — Transcendental Functions

## Module
tri.math.transcendental_fn

## Description
Computational transcendental functions with guaranteed precision bounds.
Implements exp, log, sin, cos, tan, atan, asin, acos, sinh, cosh, tanh
using polynomial/rational approximations with range reduction.

All functions guarantee:
- Relative error < 1.5 ULP for single-precision (f32)
- Relative error < 0.5 ULP for double-precision (f64) where std math is available
- Edge case stability (inf, nan, overflow, underflow)

## Dependencies
- std
- tri.math.constants (PHI, PI, E, SQRT5)

## Precision Enums
### Precision
- fast — 1e-6 max relative error, suitable for graphics/ML
- single — f32 precision, ~1e-7 max error
- double — f64 precision, ~1e-15 max error (uses std math as fallback)

## Range Reduction Strategy

### exp(x)
For |x| < 1: use Taylor series directly
For |x| >= 1: exp(x) = exp(x - n*ln(2)) * 2^n where n = round(x/ln(2))

### log(x)
For x in [0.5, 2]: use polynomial approximation
Otherwise: log(x) = log(m * 2^e) = log(m) + e*ln(2) where m in [0.5, 2)

### sin/cos(x)
Reduce to [-π, π] using modulo
Then reduce to [-π/4, π/4] using trig identities
Use polynomial approximations on reduced range

### atan(x)
For |x| < 1: use polynomial approximation
For |x| >= 1: atan(x) = π/2 - atan(1/x)

## Functions

### exp(x: f64, prec: Precision) f64
Compute e^x with specified precision.

### exp2(x: f64, prec: Precision) f64
Compute 2^x with specified precision.

### log(x: f64, prec: Precision) f64
Compute natural logarithm ln(x). Requires x > 0.

### log2(x: f64, prec: Precision) f64
Compute base-2 logarithm log2(x). Requires x > 0.

### log10(x: f64, prec: Precision) f64
Compute base-10 logarithm log10(x). Requires x > 0.

### sin(x: f64, prec: Precision) f64
Compute sine. Argument in radians.

### cos(x: f64, prec: Precision) f64
Compute cosine. Argument in radians.

### sincos(x: f64, prec: Precision) struct { s: f64, c: f64 }
Compute sin and cos simultaneously (more efficient than separate calls).

### tan(x: f64, prec: Precision) f64
Compute tangent. Argument in radians.

### asin(x: f64, prec: Precision) f64
Compute arcsine. Domain: [-1, 1].

### acos(x: f64, prec: Precision) f64
Compute arccosine. Domain: [-1, 1].

### atan(x: f64, prec: Precision) f64
Compute arctangent.

### atan2(y: f64, x: f64, prec: Precision) f64
Compute arctangent of y/x with quadrant correction.

### sinh(x: f64, prec: Precision) f64
Compute hyperbolic sine: (e^x - e^-x) / 2

### cosh(x: f64, prec: Precision) f64
Compute hyperbolic cosine: (e^x + e^-x) / 2

### tanh(x: f64, prec: Precision) f64
Compute hyperbolic tangent: sinh(x) / cosh(x)

### asinh(x: f64, prec: Precision) f64
Compute inverse hyperbolic sine: ln(x + sqrt(x^2 + 1))

### acosh(x: f64, prec: Precision) f64
Compute inverse hyperbolic cosine: ln(x + sqrt(x - 1) * sqrt(x + 1)). Domain: x >= 1.

### atanh(x: f64, prec: Precision) f64
Compute inverse hyperbolic tangent: 0.5 * ln((1+x) / (1-x)). Domain: |x| < 1.

## Constants

### LN2
f64 = 0.6931471805599453 — Natural log of 2

### LN10
f64 = 2.302585092994046 — Natural log of 10

### PI
f64 = 3.141592653589793 — Pi

### PI_2
f64 = 1.5707963267948966 — Pi / 2

### PI_4
f64 = 0.7853981633974483 — Pi / 4

### TWO_PI
f64 = 6.283185307179586 — 2 * Pi

### FRAC_1_PI
f64 = 0.3183098861837907 — 1 / Pi

## Structs

### SinCosResult
- s: f64 — sine value
- c: f64 — cosine value

## Tests

### Accuracy Tests
- Compare against std.math for random values in each function's domain
- Verify max error bounds for each precision level
- Test edge cases: 0, inf, -inf, nan, overflow, underflow

### Range Tests
- exp: test large positive (overflow), large negative (underflow), zero
- log: test domain violations (<= 0), subnormal, very large
- sin/cos: test multiples of π/2, very large arguments
- atan: test -inf, -1, 0, 1, +inf
- asin/acos: test boundaries -1, 1, outside domain

### Special Values
- exp(0) = 1
- exp(inf) = inf
- exp(-inf) = 0
- log(1) = 0
- log(0) = -inf
- log(inf) = inf
- sin(0) = 0, cos(0) = 1
- sin(π) = 0, cos(π) = -1
- tan(0) = 0
- sinh(0) = 0, cosh(0) = 1
- tanh(0) = 0, tanh(inf) = 1, tanh(-inf) = -1

## Subcommands
- `tri math transcendental list` — Show all available functions
- `tri math transcendental bench <func>` — Benchmark specific function
- `tri math transcendental test <func>` — Test specific function
- `tri math transcendental verify` — Run all accuracy tests
- `tri math transcendental gen <func>` — Generate .t27 assembly for function
