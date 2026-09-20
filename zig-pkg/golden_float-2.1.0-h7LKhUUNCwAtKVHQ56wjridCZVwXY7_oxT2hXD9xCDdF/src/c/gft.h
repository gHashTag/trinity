/**
 * GoldenFloat — GF-T16 C-ABI Header
 *
 * Minimal C99 header for GF-T16 (ternary-exponent Golden Float).
 * SPECIFICATION for the gft16_* symbols in libgoldenfloat.{so,dylib,dll}
 * (implemented in src/c_abi.zig over src/formats/gft.zig).
 *
 * **Format:** [sign:1][exp:4 balanced-ternary trits][mant:9] — the exponent is a
 * balanced-ternary number stored as an unsigned OFFSET in [0,80]; the balanced
 * exponent is e = offset - 40; the top offset row (80) is reserved (Inf/NaN).
 * value = (-1)^sign * (1 + M/2^9) * 2^e,  e in [-40,+39]  (~24 decades).
 *
 * The 17-bit packed value is carried in the low bits of a uint32_t (gft16_t).
 *
 * **Usage:**
 * ```c
 * #include <gft.h>
 * gft16_t a = gft16_from_f32(3.14159f);
 * gft16_t b = gft16_from_f32(2.71828f);
 * float p = gft16_to_f32(gft16_mul(a, b));  // ~8.539
 * ```
 *
 * phi^2 + 1/phi^2 = 3 | TRINITY
 */

#ifndef GOLDENFLOAT_GFT_H
#define GOLDENFLOAT_GFT_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/** Raw 17-bit GF-T16 pattern carried in the low bits of a uint32_t. */
typedef uint32_t gft16_t;

/** Encode an IEEE float32 into GF-T16 (round-to-nearest, saturate to Inf). */
gft16_t gft16_from_f32(float x);
/** Decode a GF-T16 value back to float32. */
float gft16_to_f32(gft16_t g);

gft16_t gft16_add(gft16_t a, gft16_t b);
gft16_t gft16_sub(gft16_t a, gft16_t b);
gft16_t gft16_mul(gft16_t a, gft16_t b);
gft16_t gft16_div(gft16_t a, gft16_t b);

gft16_t gft16_neg(gft16_t g);
gft16_t gft16_abs(gft16_t g);

/** 1 if g is finite (not the reserved Inf/NaN row), else 0. */
uint8_t gft16_is_finite(gft16_t g);

/** Balanced zero point: offset that encodes exponent 0 (value in [1,2)). */
#define GFT16_EXP_OFFSET 40
/** Reserved special row (Inf/NaN): offset 3^4 - 1. */
#define GFT16_OFFSET_MAX 80
/** Number of exponent trits. */
#define GFT16_EXP_TRITS  4
/** Number of mantissa bits. */
#define GFT16_MANT_BITS  9

/* ---- The other GF-T rungs (packed value in the low bits of the carrier) ---- */
/** GF-T4  : E=2 trits, M=1 bit  (6-bit value in a uint8).  EXP_OFFSET=4,  max=8.   */
typedef uint8_t  gft4_t;
/** GF-T8  : E=3 trits, M=4 bits (10-bit value in a uint16). EXP_OFFSET=13, max=26. */
typedef uint16_t gft8_t;
/** GF-T32 : E=6 trits, M=25 bits (36-bit value in a uint64). EXP_OFFSET=364, max=728, ~219 decades. */
typedef uint64_t gft32_t;

gft4_t  gft4_from_f32(float x);
float   gft4_to_f32(gft4_t g);
gft4_t  gft4_mul(gft4_t a, gft4_t b);
uint8_t gft4_is_finite(gft4_t g);

gft8_t  gft8_from_f32(float x);
float   gft8_to_f32(gft8_t g);
gft8_t  gft8_add(gft8_t a, gft8_t b);
gft8_t  gft8_sub(gft8_t a, gft8_t b);
gft8_t  gft8_mul(gft8_t a, gft8_t b);
gft8_t  gft8_div(gft8_t a, gft8_t b);
gft8_t  gft8_neg(gft8_t g);
gft8_t  gft8_abs(gft8_t g);
uint8_t gft8_is_finite(gft8_t g);

gft32_t gft32_from_f32(float x);
float   gft32_to_f32(gft32_t g);
gft32_t gft32_add(gft32_t a, gft32_t b);
gft32_t gft32_sub(gft32_t a, gft32_t b);
gft32_t gft32_mul(gft32_t a, gft32_t b);
gft32_t gft32_div(gft32_t a, gft32_t b);
gft32_t gft32_neg(gft32_t g);
gft32_t gft32_abs(gft32_t g);
uint8_t gft32_is_finite(gft32_t g);

#ifdef __cplusplus
}
#endif

#endif /* GOLDENFLOAT_GFT_H */
