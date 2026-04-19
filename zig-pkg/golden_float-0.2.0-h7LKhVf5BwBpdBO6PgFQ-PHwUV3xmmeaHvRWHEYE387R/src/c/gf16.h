/**
 * GoldenFloat v1.1.0 — C-ABI Header
 *
 * Minimal C99 header for GF16 (Golden Float16) format.
 * This header is the SPECIFICATION for libgoldenfloat.{so,dylib,dll}
 *
 * **Format Layout:** [sign:1][exp:6][mant:9] (16 bits total)
 * **Exponent Bias:** 31
 * **Special Values:** exp=0x3F (63) = infinity/NaN
 *
 * **Usage:**
 * ```c
 * // Include header
 * #include <gf16.h>
 *
 * // Convert values
 * gf16_t a = gf16_from_f32(3.14f);
 * gf16_t b = gf16_from_f32(2.71f);
 * gf16_t sum = gf16_add(a, b);
 * float result = gf16_to_f32(sum);
 * ```
 *
 * MIT License — Copyright (c) 2026 Trinity Project
 * Repository: https://github.com/gHashTag/zig-golden-float
 */

#ifndef GOLDENFLOAT_GF16_H
#define GOLDENFLOAT_GF16_H

#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

/*======================================================================
 * Type Definition
 *======================================================================*/

/**
 * GF16 value stored as raw 16-bit unsigned integer
 *
 * **Bit Layout:**
 *   [15]     Sign (0 = positive, 1 = negative)
 *   [14:9]   Exponent (bias = 31, range = -31..+32)
 *   [8:0]    Mantissa (9 bits, fractional part)
 *
 * **Value Formula:**
 *   value = (-1)^sign × (0.5 + mant/512) × 2^(exp - 31)
 *
 * **Special Values:**
 *   - exp=0, mant=0: Zero (signed by sign bit)
 *   - exp=0x3F, mant=0: Infinity (signed by sign bit)
 *   - exp=0x3F, mant≠0: NaN (quiet)
 */
typedef uint16_t gf16_t;

/*======================================================================
 * Constants
 *======================================================================*/

/** Zero constant (positive zero) */
#define GF16_ZERO   ((gf16_t)0x0000)

/** One constant (1.0 in GF16) */
#define GF16_ONE    ((gf16_t)0x3C00)

/** Positive infinity */
#define GF16_PINF   ((gf16_t)0x7E00)

/** Negative infinity */
#define GF16_NINF   ((gf16_t)0xFE00)

/** Quiet NaN */
#define GF16_NAN    ((gf16_t)0x7E01)

/** Negative zero */
#define GF16_NZERO  ((gf16_t)0x8000)

/*======================================================================
 * Bit Extraction Macros
 *======================================================================*/

/** Extract sign bit (0 or 1) */
#define GF16_SIGN(g)    (((g) >> 15) & 0x1)

/** Extract exponent field (0..63) */
#define GF16_EXP(g)     (((g) >> 9)  & 0x3F)

/** Extract mantissa field (0..511) */
#define GF16_MANT(g)    ((g)         & 0x1FF)

/** Construct GF16 from components */
#define GF16_MAKE(s, e, m) (((gf16_t)((s) & 1) << 15) | \
                            ((gf16_t)((e) & 0x3F) << 9) | \
                            ((gf16_t)(m) & 0x1FF))

/*======================================================================
 * Conversion Functions
 *======================================================================*/

/**
 * Convert f32 to GF16
 *
 * @param x Input float value
 * @return GF16 representation
 *
 * **Rounding:** Round-to-nearest, ties-to-even
 * **Special Values:** Preserved (inf, NaN, signed zeros)
 */
gf16_t gf16_from_f32(float x);

/**
 * Convert GF16 to f32
 *
 * @param g GF16 value
 * @return Float representation
 *
 * **Precision:** Exact for all GF16 values
 */
float gf16_to_f32(gf16_t g);

/*======================================================================
 * Arithmetic Functions
 *======================================================================*/

/**
 * Add two GF16 values
 *
 * @param a First operand
 * @param b Second operand
 * @return a + b in GF16
 *
 * **Computation:** Performed in f32, rounded to GF16
 */
gf16_t gf16_add(gf16_t a, gf16_t b);

/**
 * Subtract two GF16 values
 *
 * @param a First operand
 * @param b Second operand
 * @return a - b in GF16
 */
gf16_t gf16_sub(gf16_t a, gf16_t b);

/**
 * Multiply two GF16 values
 *
 * @param a First operand
 * @param b Second operand
 * @return a × b in GF16
 */
gf16_t gf16_mul(gf16_t a, gf16_t b);

/**
 * Divide two GF16 values
 *
 * @param a Numerator
 * @param b Denominator
 * @return a / b in GF16
 *
 * **Note:** Division by zero returns infinity (signed)
 */
gf16_t gf16_div(gf16_t a, gf16_t b);

/*======================================================================
 * Unary Functions
 *======================================================================*/

/**
 * Negate GF16 value
 *
 * @param g Input value
 * @return -g
 */
gf16_t gf16_neg(gf16_t g);

/**
 * Absolute value of GF16
 *
 * @param g Input value
 * @return |g|
 */
gf16_t gf16_abs(gf16_t g);

/*======================================================================
 * Comparison Functions
 *======================================================================*/

/**
 * Equality test
 *
 * @param a First operand
 * @param b Second operand
 * @return true if equal, false otherwise
 *
 * **Note:** NaN != NaN (IEEE 754 semantics)
 */
bool gf16_eq(gf16_t a, gf16_t b);

/**
 * Less-than test
 *
 * @param a First operand
 * @param b Second operand
 * @return true if a < b, false otherwise
 *
 * **Note:** NaN comparisons return false
 */
bool gf16_lt(gf16_t a, gf16_t b);

/**
 * Less-than-or-equal test
 *
 * @param a First operand
 * @param b Second operand
 * @return true if a <= b, false otherwise
 */
bool gf16_le(gf16_t a, gf16_t b);

/**
 * Three-way comparison
 *
 * @param a First operand
 * @param b Second operand
 * @return -1 if a < b, 0 if a == b, 1 if a > b
 */
int gf16_cmp(gf16_t a, gf16_t b);

/*======================================================================
 * Predicate Functions
 *======================================================================*/

/**
 * Check if value is NaN
 *
 * @param g GF16 value
 * @return true if NaN, false otherwise
 */
bool gf16_is_nan(gf16_t g);

/**
 * Check if value is infinity (positive or negative)
 *
 * @param g GF16 value
 * @return true if infinity, false otherwise
 */
bool gf16_is_inf(gf16_t g);

/**
 * Check if value is zero (positive or negative)
 *
 * @param g GF16 value
 * @return true if zero, false otherwise
 */
bool gf16_is_zero(gf16_t g);

/**
 * Check if value is subnormal
 *
 * @param g GF16 value
 * @return true if subnormal, false otherwise
 *
 * **Note:** GF16 has no true subnormals (exp=0 is zero)
 */
bool gf16_is_subnormal(gf16_t g);

/**
 * Check if value is negative
 *
 * @param g GF16 value
 * @return true if negative, false otherwise
 */
bool gf16_is_negative(gf16_t g);

/*======================================================================
 * φ-Math Functions (Golden Ratio Optimization)
 *======================================================================*/

/**
 * φ-optimized quantization
 *
 * Quantizes f32 to GF16 using φ-weighted bins.
 * Better distribution for ML weights.
 *
 * @param x Input float value
 * @return φ-quantized GF16 value
 *
 * **Formula:** x × (1/φ²) then quantize
 */
gf16_t gf16_phi_quantize(float x);

/**
 * φ-optimized dequantization
 *
 * Dequantizes GF16 to f32 using φ-weighted bins.
 *
 * @param g GF16 value
 * @return φ-dequantized float value
 *
 * **Formula:** to_f32(g) × φ²
 */
float gf16_phi_dequantize(gf16_t g);

/*======================================================================
 * Utility Functions
 *======================================================================*/

/**
 * Copy sign from source to target
 *
 * @param target Value whose magnitude is used
 * @param source Value whose sign is used
 * @return target with source's sign
 */
gf16_t gf16_copysign(gf16_t target, gf16_t source);

/**
 * Minimum of two values
 *
 * @param a First operand
 * @param b Second operand
 * @return min(a, b)
 */
gf16_t gf16_min(gf16_t a, gf16_t b);

/**
 * Maximum of two values
 *
 * @param a First operand
 * @param b Second operand
 * @return max(a, b)
 */
gf16_t gf16_max(gf16_t a, gf16_t b);

/**
 * Fused multiply-add: a × b + c
 *
 * @param a First operand
 * @param b Second operand
 * @param c Third operand
 * @return a × b + c in GF16
 *
 * **Note:** Computed in f32, rounded to GF16
 */
gf16_t gf16_fma(gf16_t a, gf16_t b, gf16_t c);

/*======================================================================
 * Constants
 *======================================================================*/

/** Golden ratio φ = (1 + √5) / 2 ≈ 1.6180339887498948 */
#define GF16_PHI         1.6180339887498948482f

/** φ² = φ × φ ≈ 2.6180339887498948 */
#define GF16_PHI_SQ      2.6180339887498948482f

/** 1/φ² ≈ 0.3819660112501051 */
#define GF16_PHI_INV_SQ  0.38196601125010515f

/** Trinity Identity: φ² + 1/φ² = 3 */
#define GF16_TRINITY     3.0f

/** Exponent bias for GF16 */
#define GF16_EXP_BIAS    31

/** Maximum exponent value (before special values) */
#define GF16_EXP_MAX     62

/** Number of mantissa bits */
#define GF16_MANT_BITS   9

#ifdef __cplusplus
}
#endif

#endif /* GOLDENFLOAT_GF16_H */
