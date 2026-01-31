/**
 * @file trinity_vsa.h
 * @brief Trinity VSA - Vector Symbolic Architecture with Balanced Ternary
 * 
 * High-performance library for hyperdimensional computing.
 * 
 * @author Dmitrii Vasilev
 * @license MIT
 */

#ifndef TRINITY_VSA_H
#define TRINITY_VSA_H

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

/* ============================================================================
 * Types
 * ============================================================================ */

/**
 * @brief Balanced ternary digit
 */
typedef enum {
    TRIT_NEG = -1,
    TRIT_ZERO = 0,
    TRIT_POS = 1
} trit_t;

/**
 * @brief Dense trit vector
 */
typedef struct {
    int8_t* data;
    size_t dim;
    bool owned;  /* Whether data should be freed */
} trit_vector_t;

/**
 * @brief Packed trit vector (2 bits per trit)
 */
typedef struct {
    uint64_t* pos;  /* Positive bits */
    uint64_t* neg;  /* Negative bits */
    size_t dim;
    size_t num_words;
} packed_trit_vec_t;

/* ============================================================================
 * Vector Creation/Destruction
 * ============================================================================ */

/**
 * @brief Create zero vector
 * @param dim Vector dimension
 * @return New vector (must be freed with trit_vector_free)
 */
trit_vector_t* trit_vector_zeros(size_t dim);

/**
 * @brief Create random hypervector
 * @param dim Vector dimension
 * @param seed Random seed (0 for random)
 * @return New vector
 */
trit_vector_t* trit_vector_random(size_t dim, uint64_t seed);

/**
 * @brief Create vector from array
 * @param data Array of int8 values
 * @param dim Array length
 * @return New vector (copies data)
 */
trit_vector_t* trit_vector_from_array(const int8_t* data, size_t dim);

/**
 * @brief Create vector wrapping existing array (no copy)
 * @param data Array of int8 values
 * @param dim Array length
 * @return New vector (does not own data)
 */
trit_vector_t* trit_vector_wrap(int8_t* data, size_t dim);

/**
 * @brief Free vector
 * @param v Vector to free
 */
void trit_vector_free(trit_vector_t* v);

/**
 * @brief Clone vector
 * @param v Vector to clone
 * @return New vector
 */
trit_vector_t* trit_vector_clone(const trit_vector_t* v);

/* ============================================================================
 * VSA Operations
 * ============================================================================ */

/**
 * @brief Bind two vectors (element-wise multiplication)
 * @param a First vector
 * @param b Second vector
 * @return Bound vector (new allocation)
 */
trit_vector_t* trit_bind(const trit_vector_t* a, const trit_vector_t* b);

/**
 * @brief Bind in-place: result = a * b
 * @param result Output vector (must be pre-allocated)
 * @param a First vector
 * @param b Second vector
 */
void trit_bind_inplace(trit_vector_t* result, const trit_vector_t* a, const trit_vector_t* b);

/**
 * @brief Unbind (same as bind for balanced ternary)
 */
#define trit_unbind trit_bind

/**
 * @brief Bundle multiple vectors (majority voting)
 * @param vectors Array of vector pointers
 * @param count Number of vectors
 * @return Bundled vector
 */
trit_vector_t* trit_bundle(const trit_vector_t** vectors, size_t count);

/**
 * @brief Permute vector (circular shift)
 * @param v Vector to permute
 * @param shift Shift amount (positive = right)
 * @return Permuted vector
 */
trit_vector_t* trit_permute(const trit_vector_t* v, int32_t shift);

/**
 * @brief Cosine similarity
 * @param a First vector
 * @param b Second vector
 * @return Similarity in [-1.0, 1.0]
 */
double trit_similarity(const trit_vector_t* a, const trit_vector_t* b);

/**
 * @brief Dot product
 * @param a First vector
 * @param b Second vector
 * @return Sum of element-wise products
 */
int64_t trit_dot(const trit_vector_t* a, const trit_vector_t* b);

/**
 * @brief Hamming distance
 * @param a First vector
 * @param b Second vector
 * @return Number of differing positions
 */
size_t trit_hamming_distance(const trit_vector_t* a, const trit_vector_t* b);

/* ============================================================================
 * Packed Operations (SIMD-optimized)
 * ============================================================================ */

/**
 * @brief Create packed vector from dense
 */
packed_trit_vec_t* packed_from_trit_vector(const trit_vector_t* v);

/**
 * @brief Convert packed to dense
 */
trit_vector_t* packed_to_trit_vector(const packed_trit_vec_t* p);

/**
 * @brief Free packed vector
 */
void packed_free(packed_trit_vec_t* p);

/**
 * @brief Fast packed bind
 */
packed_trit_vec_t* packed_bind(const packed_trit_vec_t* a, const packed_trit_vec_t* b);

/**
 * @brief Fast packed dot product
 */
int64_t packed_dot(const packed_trit_vec_t* a, const packed_trit_vec_t* b);

/* ============================================================================
 * Utility Functions
 * ============================================================================ */

/**
 * @brief Get number of non-zero elements
 */
size_t trit_vector_nnz(const trit_vector_t* v);

/**
 * @brief Get sparsity ratio (fraction of zeros)
 */
double trit_vector_sparsity(const trit_vector_t* v);

/**
 * @brief Negate vector in-place
 */
void trit_vector_negate(trit_vector_t* v);

/**
 * @brief Check if SIMD is available
 */
bool trinity_has_avx2(void);
bool trinity_has_avx512(void);

/**
 * @brief Get library version
 */
const char* trinity_version(void);

#ifdef __cplusplus
}
#endif

#endif /* TRINITY_VSA_H */
