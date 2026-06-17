#include <stdarg.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>

/**
 * Maximum trits for BigInt (supports numbers up to 3^256 ≈ 10^122)
 */
#define MAX_TRITS 256

/**
 * SIMD width for trit operations
 */
#define SIMD_WIDTH 32

/**
 * Storage mode for HybridBigInt
 */
typedef enum HybridStorageMode {
  /**
   * Dense storage (one trit per byte)
   */
  Dense = 0,
  /**
   * Packed storage (2 trits per byte)
   */
  Packed = 1,
  /**
   * Hybrid storage (chunks of packed + dense)
   */
  Hybrid = 2,
} HybridStorageMode;

/**
 * Trit value: -1, 0, or +1
 */
typedef int8_t Trit;

/**
 * HybridBigInt — arbitrary precision balanced ternary number
 */
typedef struct HybridBigInt {
  /**
   * Trit data
   */
  Trit *data;
  /**
   * Number of trits
   */
  uintptr_t len;
  /**
   * Capacity
   */
  uintptr_t capacity;
  /**
   * Storage mode
   */
  enum HybridStorageMode mode;
  /**
   * Sign (-1, 0, +1)
   */
  int8_t sign;
} HybridBigInt;

/**
 * BigInt operation result
 */
typedef struct BigIntResult {
  /**
   * Result value
   */
  struct HybridBigInt value;
  /**
   * Overflow flag
   */
  bool overflow;
  /**
   * Success flag
   */
  bool success;
} BigIntResult;

/**
 * Packed trit buffer (2 trits per byte)
 */
typedef struct PackedTritBuffer {
  /**
   * Packed data (each byte = 2 trits)
   */
  uint8_t *data;
  /**
   * Number of bytes
   */
  uintptr_t len;
  /**
   * Number of trits (may be odd)
   */
  uintptr_t trit_count;
} PackedTritBuffer;

/**
 * Trit values
 */
#define TRIT_NEGATIVE -1

#define TRIT_ZERO 0

#define TRIT_POSITIVE 1

/**
 * Create a new HybridBigInt
 */
struct HybridBigInt *trios_hybrid_bigint_new(uintptr_t capacity);

/**
 * Create a HybridBigInt from i64
 */
struct HybridBigInt *trios_hybrid_bigint_from_i64(long long value);

/**
 * Convert HybridBigInt to i64
 */
long long trios_hybrid_bigint_to_i64(const struct HybridBigInt *bigint);

/**
 * Free a HybridBigInt
 */
void trios_hybrid_bigint_free(struct HybridBigInt *bigint);

/**
 * Clone a HybridBigInt
 */
struct HybridBigInt *trios_hybrid_bigint_clone(const struct HybridBigInt *bigint);

/**
 * Get number of trits
 */
uintptr_t trios_hybrid_bigint_len(const struct HybridBigInt *bigint);

/**
 * Get storage mode
 */
enum HybridStorageMode trios_hybrid_bigint_mode(const struct HybridBigInt *bigint);

/**
 * Add two BigInts
 */
int trios_hybrid_bigint_add(const struct HybridBigInt *a,
                            const struct HybridBigInt *b,
                            struct BigIntResult *result);

/**
 * Subtract two BigInts (a - b)
 */
int trios_hybrid_bigint_sub(const struct HybridBigInt *a,
                            const struct HybridBigInt *b,
                            struct BigIntResult *result);

/**
 * Multiply two BigInts
 */
int trios_hybrid_bigint_mul(const struct HybridBigInt *a,
                            const struct HybridBigInt *b,
                            struct BigIntResult *result);

/**
 * Divide two BigInts (a / b)
 */
int trios_hybrid_bigint_div(const struct HybridBigInt *a,
                            const struct HybridBigInt *b,
                            struct BigIntResult *quotient,
                            struct BigIntResult *remainder);

/**
 * Compare two BigInts
 *
 * Returns: -1 if a < b, 0 if a == b, 1 if a > b
 */
int trios_hybrid_bigint_cmp(const struct HybridBigInt *a, const struct HybridBigInt *b);

/**
 * Check if BigInt is zero
 */
bool trios_hybrid_bigint_is_zero(const struct HybridBigInt *bigint);

/**
 * Check if BigInt is negative
 */
bool trios_hybrid_bigint_is_negative(const struct HybridBigInt *bigint);

/**
 * Negate a BigInt
 */
int trios_hybrid_bigint_neg(const struct HybridBigInt *bigint, struct BigIntResult *result);

/**
 * Absolute value of BigInt
 */
int trios_hybrid_bigint_abs(const struct HybridBigInt *bigint, struct BigIntResult *result);

/**
 * Left shift (multiply by 3^n)
 */
int trios_hybrid_bigint_shl(const struct HybridBigInt *bigint,
                            uintptr_t _n,
                            struct BigIntResult *result);

/**
 * Right shift (divide by 3^n)
 */
int trios_hybrid_bigint_shr(const struct HybridBigInt *bigint,
                            uintptr_t _n,
                            struct BigIntResult *result);

/**
 * Create a packed trit buffer
 */
struct PackedTritBuffer *trios_hybrid_packed_new(uintptr_t _trit_count);

/**
 * Free a packed trit buffer
 */
void trios_hybrid_packed_free(struct PackedTritBuffer *buffer);

/**
 * Encode dense trits to packed format
 */
int trios_hybrid_encode_pack(const Trit *trits,
                             uintptr_t trit_count,
                             struct PackedTritBuffer *packed);

/**
 * Decode packed trits to dense format
 */
int trios_hybrid_decode_pack(const struct PackedTritBuffer *packed,
                             Trit *trits,
                             uintptr_t trit_count);

/**
 * Get packed buffer trit count
 */
uintptr_t trios_hybrid_packed_trit_count(const struct PackedTritBuffer *buffer);

/**
 * Get packed buffer byte count
 */
uintptr_t trios_hybrid_packed_byte_count(const struct PackedTritBuffer *buffer);

/**
 * Convert BigInt to packed format
 */
int trios_hybrid_bigint_to_packed(const struct HybridBigInt *bigint,
                                  struct PackedTritBuffer *packed);

/**
 * Convert packed format to BigInt
 */
struct HybridBigInt *trios_hybrid_bigint_from_packed(const struct PackedTritBuffer *packed);

/**
 * Set storage mode
 */
int trios_hybrid_bigint_set_mode(struct HybridBigInt *bigint, enum HybridStorageMode mode);

/**
 * Get last error message
 */
const char *trios_hybrid_last_error(void);

/**
 * Get version
 */
const char *trios_hybrid_version(void);

/**
 * Get build info
 */
const char *trios_hybrid_build_info(void);
