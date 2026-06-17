#include <stdarg.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>

/**
 * Tekum buffer size (27 trits for large numbers)
 */
#define TEKUM_SIZE 27

/**
 * Trit value: -1, 0, or +1
 */
typedef int8_t Trit;

/**
 * Dense ternary vector
 */
typedef struct TernaryVector {
  Trit *data;
  uintptr_t len;
} TernaryVector;

#define TRIT_NEGATIVE -1

#define TRIT_ZERO 0

#define TRIT_POSITIVE 1

/**
 * Ternary AND: min(a, b)
 */
Trit trios_ternary_and(Trit a, Trit b);

/**
 * Ternary OR: max(a, b)
 */
Trit trios_ternary_or(Trit a, Trit b);

/**
 * Ternary NOT: negation
 */
Trit trios_ternary_not(Trit a);

/**
 * Ternary implication: OR(NOT(a), b)
 */
Trit trios_ternary_implies(Trit a, Trit b);

/**
 * Ternary consensus: a if a == b, else 0
 */
Trit trios_ternary_consensus(Trit a, Trit b);

/**
 * Ternary majority vote of three trits
 */
Trit trios_ternary_majority(Trit a, Trit b, Trit c);

/**
 * Convert trit to confidence [0.0, 1.0]
 */
float trios_ternary_to_confidence(Trit t);

/**
 * Convert confidence to trit
 */
Trit trios_ternary_from_confidence(float c);

/**
 * Tekum: Convert integer to balanced ternary
 */
void trios_ternary_tekum_from_int(int n, Trit *buf);

/**
 * Tekum: Convert balanced ternary to integer
 */
int trios_ternary_tekum_to_int(const Trit *buf);

/**
 * Quantize float to trit using threshold
 */
Trit trios_ternary_quantize(float x, float threshold);

/**
 * Dequantize trit to float with scale
 */
float trios_ternary_dequantize(Trit t, float scale);

/**
 * Quantize weights for BitLinear layer
 */
void trios_ternary_quantize_weights(const float *weights,
                                    uintptr_t count,
                                    float threshold,
                                    Trit *out);

/**
 * BitLinear forward pass: y = sign(W) * scale * x
 */
void trios_ternary_bitlinear_forward(const Trit *weights,
                                     const float *scales,
                                     const float *input,
                                     float *output,
                                     uintptr_t n);

/**
 * Create ternary vector
 */
struct TernaryVector *trios_ternary_vector_new(uintptr_t len);

/**
 * Free ternary vector
 */
void trios_ternary_vector_free(struct TernaryVector *vec);

/**
 * Get version
 */
const char *trios_ternary_version(void);
