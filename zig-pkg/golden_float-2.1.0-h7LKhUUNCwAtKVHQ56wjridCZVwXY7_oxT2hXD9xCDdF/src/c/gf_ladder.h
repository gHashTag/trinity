/**
 * GoldenFloat — Binary GF ladder C-ABI Header
 *
 * The φ²-sized binary rungs from the gf_binary.zig factory, exported from
 * libgoldenfloat.{so,dylib,dll}. Each rung sizes its exponent by the rule
 *   e = round((N-1) / φ²),  m = N-1-e,  bias = 2^(e-1)-1,  exp_max = 2^e-1
 * so the exp:mantissa split tracks 1/φ at every width.
 *
 *   Rung   Layout      bias   ~normal range
 *   GF8    [1:3:4]     3      ~[0.25, 15.5]
 *   GF12   [1:4:7]     7      ~[0.016, 256]
 *   GF20   [1:7:12]    63     ~[2^-62, 2^63]
 *   GF24   [1:9:14]    255    ~[2^-254, 2^255]
 *   GF32   [1:12:19]   2047   ~[2^-2046, 2^2047]
 *
 * GF16 [1:6:9] b31 is the rich API in gf16.h (identical layout). GF4 [1:1:2] is
 * omitted: a 1-bit exponent leaves no normal values (only zero / Inf / NaN).
 *
 * The packed N-bit value rides in the low bits of the next byte-sized carrier.
 * Semantics: round-to-nearest, saturate to Inf, flush subnormals to zero.
 *
 * phi^2 + 1/phi^2 = 3 | TRINITY
 * MIT License — Copyright (c) 2026 Trinity Project
 */

#ifndef GOLDENFLOAT_GF_LADDER_H
#define GOLDENFLOAT_GF_LADDER_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Each macro declares the 9-function API for one rung over carrier type T. */
#define GOLDENFLOAT_GF_RUNG(PFX, T)          \
    T       PFX##_from_f32(float x);         \
    float   PFX##_to_f32(T g);               \
    T       PFX##_add(T a, T b);             \
    T       PFX##_sub(T a, T b);             \
    T       PFX##_mul(T a, T b);             \
    T       PFX##_div(T a, T b);             \
    T       PFX##_neg(T g);                  \
    T       PFX##_abs(T g);                  \
    uint8_t PFX##_is_finite(T g);

GOLDENFLOAT_GF_RUNG(gf8, uint8_t)   /* [1:3:4]  b3   */
GOLDENFLOAT_GF_RUNG(gf12, uint16_t) /* [1:4:7]  b7   */
GOLDENFLOAT_GF_RUNG(gf20, uint32_t) /* [1:7:12] b63  */
GOLDENFLOAT_GF_RUNG(gf24, uint32_t) /* [1:9:14] b255 */
GOLDENFLOAT_GF_RUNG(gf32, uint32_t) /* [1:12:19] b2047 */

#undef GOLDENFLOAT_GF_RUNG

#ifdef __cplusplus
}
#endif

#endif /* GOLDENFLOAT_GF_LADDER_H */
