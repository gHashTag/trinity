#include <stdarg.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>

/**
 * SIMD width for vector operations
 */
#define SIMD_WIDTH 32

/**
 * Allocator type for VSA operations
 */
typedef enum VSAAllocator {
  /**
   * Default system allocator
   */
  System = 0,
  /**
   * Arena allocator (for batch operations)
   */
  Arena = 1,
  /**
   * Pool allocator (for frequent allocs/frees)
   */
  Pool = 2,
} VSAAllocator;

/**
 * VSA Context (manages allocator and state)
 */
typedef struct VSAContext {
  uint8_t _private[0];
} VSAContext;

/**
 * Trit value: -1, 0, or +1
 */
typedef int8_t Trit;

/**
 * Dense VSA vector
 */
typedef struct VSAVector {
  /**
   * Pointer to trit data
   */
  Trit *data;
  /**
   * Number of trits in the vector
   */
  uintptr_t len;
  /**
   * Capacity (for memory management)
   */
  uintptr_t capacity;
} VSAVector;

/**
 * Search result for similarity queries
 */
typedef struct VSASearchResult {
  /**
   * Index of the best match
   */
  uintptr_t index;
  /**
   * Similarity score (0.0 to 1.0)
   */
  double score;
  /**
   * Whether a good match was found
   */
  bool found;
} VSASearchResult;

/**
 * Sparse VSA vector (for high-dimensional sparse data)
 */
typedef struct VSASparseVector {
  /**
   * Non-zero indices
   */
  uintptr_t *indices;
  /**
   * Trit values at those indices
   */
  Trit *values;
  /**
   * Number of non-zero elements
   */
  uintptr_t nnz;
  /**
   * Total dimension
   */
  uintptr_t dimension;
} VSASparseVector;

/**
 * Trit values
 */
#define TRIT_NEGATIVE -1

#define TRIT_ZERO 0

#define TRIT_POSITIVE 1

/**
 * Create a new VSA context
 *
 * Returns null pointer on allocation failure.
 */
struct VSAContext *trios_vsa_context_new(enum VSAAllocator alloc_type);

/**
 * Destroy a VSA context
 */
void trios_vsa_context_free(struct VSAContext *ctx);

/**
 * Create a new VSA vector
 *
 * # Safety
 * - `ctx` must be a valid VSAContext pointer
 */
struct VSAVector *trios_vsa_vector_new(struct VSAContext *ctx, uintptr_t len);

/**
 * Create a VSA vector from raw data
 *
 * # Safety
 * - `ctx` must be a valid VSAContext pointer
 * - `data` must point to valid trit data of length `len`
 */
struct VSAVector *trios_vsa_vector_from_data(struct VSAContext *ctx,
                                             const Trit *data,
                                             uintptr_t len);

/**
 * Free a VSA vector
 */
void trios_vsa_vector_free(struct VSAVector *vec);

/**
 * Get vector length
 */
uintptr_t trios_vsa_vector_len(const struct VSAVector *vec);

/**
 * Get vector data pointer (read-only)
 */
const Trit *trios_vsa_vector_data(const struct VSAVector *vec);

/**
 * Bind operation: element-wise multiplication
 *
 * Returns null on failure.
 */
struct VSAVector *trios_vsa_bind(struct VSAContext *ctx,
                                 const struct VSAVector *a,
                                 const struct VSAVector *b);

/**
 * Unbind operation: inverse of bind (same as bind for symmetric trits)
 */
struct VSAVector *trios_vsa_unbind(struct VSAContext *ctx,
                                   const struct VSAVector *a,
                                   const struct VSAVector *b);

/**
 * Bundle 2 vectors: addition-like operation
 */
struct VSAVector *trios_vsa_bundle2(struct VSAContext *ctx,
                                    const struct VSAVector *a,
                                    const struct VSAVector *b);

/**
 * Bundle 3 vectors
 */
struct VSAVector *trios_vsa_bundle3(struct VSAContext *ctx,
                                    const struct VSAVector *a,
                                    const struct VSAVector *b,
                                    const struct VSAVector *c);

/**
 * Bundle N vectors
 *
 * # Safety
 * - `vectors` must point to an array of `count` VSAVector pointers
 */
struct VSAVector *trios_vsa_bundle_n(struct VSAContext *ctx,
                                     const struct VSAVector *const *vectors,
                                     uintptr_t count);

/**
 * Permute vector with a permutation pattern
 *
 * # Safety
 * - `perm` must point to valid permutation data of length `vec.len`
 */
struct VSAVector *trios_vsa_permute(struct VSAContext *ctx,
                                    const struct VSAVector *vec,
                                    const uintptr_t *perm);

/**
 * Inverse permute vector
 */
struct VSAVector *trios_vsa_inverse_permute(struct VSAContext *ctx,
                                            const struct VSAVector *vec,
                                            const uintptr_t *perm);

/**
 * Generate a random vector
 */
struct VSAVector *trios_vsa_random_vector(struct VSAContext *ctx, uintptr_t len, uint64_t seed);

/**
 * Cosine similarity between two vectors
 */
double trios_vsa_cosine_similarity(const struct VSAVector *a, const struct VSAVector *b);

/**
 * Hamming distance between two vectors
 */
uintptr_t trios_vsa_hamming_distance(const struct VSAVector *a, const struct VSAVector *b);

/**
 * Hamming similarity (1.0 - distance / len)
 */
double trios_vsa_hamming_similarity(const struct VSAVector *a, const struct VSAVector *b);

/**
 * Dot product similarity
 */
long trios_vsa_dot_similarity(const struct VSAVector *a, const struct VSAVector *b);

/**
 * Vector norm (L2)
 */
double trios_vsa_vector_norm(const struct VSAVector *vec);

/**
 * Count non-zero trits
 */
uintptr_t trios_vsa_count_non_zero(const struct VSAVector *vec);

/**
 * Dot product
 */
long trios_vsa_dot_product(const struct VSAVector *a, const struct VSAVector *b);

/**
 * Encode a sequence into a single vector
 *
 * # Safety
 * - `sequence` must point to an array of `count` VSAVector pointers
 */
struct VSAVector *trios_vsa_encode_sequence(struct VSAContext *ctx,
                                            const struct VSAVector *const *sequence,
                                            uintptr_t count);

/**
 * Probe sequence: find best match in memory
 */
int trios_vsa_probe_sequence(struct VSAContext *ctx,
                             const struct VSAVector *query,
                             const struct VSAVector *const *memory,
                             uintptr_t memory_count,
                             struct VSASearchResult *result);

/**
 * Create a sparse vector from dense
 */
struct VSASparseVector *trios_vsa_sparse_from_dense(struct VSAContext *ctx,
                                                    const struct VSAVector *dense);

/**
 * Free a sparse vector
 */
void trios_vsa_sparse_free(struct VSASparseVector *vec);

/**
 * Get sparse vector non-zero count
 */
uintptr_t trios_vsa_sparse_nnz(const struct VSASparseVector *vec);

/**
 * Get sparse vector dimension
 */
uintptr_t trios_vsa_sparse_dimension(const struct VSASparseVector *vec);

/**
 * Get last error message (null if no error)
 */
const char *trios_vsa_last_error(void);

/**
 * Clear last error
 */
void trios_vsa_clear_error(void);

/**
 * Get VSA version
 */
const char *trios_vsa_version(void);

/**
 * Get VSA build info
 */
const char *trios_vsa_build_info(void);
