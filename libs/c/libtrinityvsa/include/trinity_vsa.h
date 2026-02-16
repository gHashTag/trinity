/**
 * @file trinity_vsa.h
 * @brief Trinity VSA — Vector Symbolic Architecture with Balanced Ternary
 *
 * High-performance hyperdimensional computing library.
 * Backed by Zig core with SIMD acceleration (ARM NEON / x86 SSE).
 *
 * Vectors are opaque handles. Create with trinity_vsa_vector_*(),
 * free with trinity_vsa_vector_free(). All functions are null-safe.
 *
 * @version 0.2.0
 * @author Dmitrii Vasilev
 * @license MIT
 */

#ifndef TRINITY_VSA_H
#define TRINITY_VSA_H

#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

/* ============================================================================
 * Opaque Vector Handle
 * ============================================================================ */

/**
 * @brief Opaque handle to a ternary hypervector.
 *
 * Internally a heap-allocated HybridBigInt with SIMD-accelerated operations.
 * Each trit is {-1, 0, +1}. Max dimension: 59,049 (3^10).
 */
typedef void* trinity_vsa_vector_t;

/* ============================================================================
 * Library Info
 * ============================================================================ */

/**
 * @brief Get library version string
 * @return Null-terminated version string (e.g. "0.2.0")
 */
const char* trinity_vsa_version(void);

/**
 * @brief Get maximum supported vector dimension
 * @return 59049 (3^10)
 */
size_t trinity_vsa_max_dim(void);

/* ============================================================================
 * Vector Creation / Destruction
 * ============================================================================ */

/**
 * @brief Create zero vector
 * @param dim Vector dimension (max 59049)
 * @return New vector handle, or NULL on failure. Must be freed.
 */
trinity_vsa_vector_t trinity_vsa_vector_zeros(size_t dim);

/**
 * @brief Create random hypervector
 * @param dim Vector dimension (max 59049)
 * @param seed Random seed (deterministic: same seed = same vector)
 * @return New vector handle, or NULL on failure. Must be freed.
 */
trinity_vsa_vector_t trinity_vsa_vector_random(size_t dim, uint64_t seed);

/**
 * @brief Create vector from array of int8 values
 * @param data Array of int8 values (clamped to {-1, 0, +1})
 * @param dim Array length (max 59049)
 * @return New vector handle (copies data), or NULL on failure. Must be freed.
 */
trinity_vsa_vector_t trinity_vsa_from_array(const int8_t* data, size_t dim);

/**
 * @brief Clone a vector (deep copy)
 * @param v Source vector handle (may be NULL)
 * @return New vector handle, or NULL on failure. Must be freed.
 */
trinity_vsa_vector_t trinity_vsa_vector_clone(trinity_vsa_vector_t v);

/**
 * @brief Free a vector handle
 * @param v Vector to free (NULL-safe, no-op on NULL)
 */
void trinity_vsa_vector_free(trinity_vsa_vector_t v);

/* ============================================================================
 * VSA Operations
 * ============================================================================ */

/**
 * @brief Bind two vectors (element-wise multiplication)
 *
 * Creates associations: bind(country, capital) represents "country→capital".
 * Self-inverse: bind(a, a) = all +1 for non-zero trits.
 * Unbind: bind(bind(a,b), b) = a.
 *
 * @param a First vector
 * @param b Second vector
 * @return Bound vector (new handle), or NULL on failure. Must be freed.
 */
trinity_vsa_vector_t trinity_vsa_bind(trinity_vsa_vector_t a, trinity_vsa_vector_t b);

/**
 * @brief Unbind (inverse of bind — same as bind for balanced ternary)
 * @param a Bound vector
 * @param b Key vector
 * @return Unbound vector (new handle), or NULL on failure. Must be freed.
 */
trinity_vsa_vector_t trinity_vsa_unbind(trinity_vsa_vector_t a, trinity_vsa_vector_t b);

/**
 * @brief Bundle 2 vectors (majority voting)
 *
 * Creates superposition: bundle(cat, dog) is similar to both.
 *
 * @param a First vector
 * @param b Second vector
 * @return Bundled vector (new handle), or NULL on failure. Must be freed.
 */
trinity_vsa_vector_t trinity_vsa_bundle2(trinity_vsa_vector_t a, trinity_vsa_vector_t b);

/**
 * @brief Bundle 3 vectors (true majority voting)
 * @param a First vector
 * @param b Second vector
 * @param c Third vector
 * @return Bundled vector (new handle), or NULL on failure. Must be freed.
 */
trinity_vsa_vector_t trinity_vsa_bundle3(trinity_vsa_vector_t a, trinity_vsa_vector_t b, trinity_vsa_vector_t c);

/**
 * @brief Permute vector (cyclic shift)
 *
 * Used for sequence encoding: permute(word_vec, position).
 *
 * @param v Vector to permute
 * @param k Shift amount (positions to shift right)
 * @return Permuted vector (new handle), or NULL on failure. Must be freed.
 */
trinity_vsa_vector_t trinity_vsa_permute(trinity_vsa_vector_t v, size_t k);

/* ============================================================================
 * Similarity Measures
 * ============================================================================ */

/**
 * @brief Cosine similarity between two vectors
 * @param a First vector
 * @param b Second vector
 * @return Similarity in [-1.0, 1.0], or 0.0 on error
 */
double trinity_vsa_cosine_similarity(trinity_vsa_vector_t a, trinity_vsa_vector_t b);

/**
 * @brief Hamming distance (number of differing trits)
 * @param a First vector
 * @param b Second vector
 * @return Number of positions where trits differ, or 0 on error
 */
size_t trinity_vsa_hamming_distance(trinity_vsa_vector_t a, trinity_vsa_vector_t b);

/**
 * @brief Dot product (sum of element-wise products)
 * @param a First vector
 * @param b Second vector
 * @return Scalar dot product, or 0 on error
 */
int64_t trinity_vsa_dot_product(trinity_vsa_vector_t a, trinity_vsa_vector_t b);

/* ============================================================================
 * Text Encoding (Semantic Search)
 * ============================================================================ */

/**
 * @brief Encode text string to hypervector
 *
 * Uses position-based character binding for semantic search.
 * Same text always produces the same vector. Similar texts produce similar vectors.
 *
 * @param text UTF-8 text string (not necessarily null-terminated)
 * @param len Length of text in bytes
 * @return Text vector (new handle), or NULL on failure. Must be freed.
 */
trinity_vsa_vector_t trinity_vsa_encode_text(const char* text, size_t len);

/**
 * @brief Decode hypervector back to text
 *
 * Probes each position against character codebook.
 *
 * @param v Vector to decode
 * @param buf Output buffer for decoded text
 * @param buf_len Maximum bytes to write
 * @return Number of characters actually decoded
 */
size_t trinity_vsa_decode_text(trinity_vsa_vector_t v, char* buf, size_t buf_len);

/**
 * @brief Encode text to hypervector using word-level bag-of-words
 *
 * Splits text into words, encodes each independently, bundles via majority vote.
 * Better for search: texts sharing words have high similarity regardless of order.
 *
 * @param text UTF-8 text string (not necessarily null-terminated)
 * @param len Length of text in bytes
 * @return Text vector (new handle), or NULL on failure. Must be freed.
 */
trinity_vsa_vector_t trinity_vsa_encode_text_words(const char* text, size_t len);

/* ============================================================================
 * Vector Access
 * ============================================================================ */

/**
 * @brief Get vector dimension (number of trits)
 * @param v Vector handle (NULL returns 0)
 * @return Number of trits in vector
 */
size_t trinity_vsa_get_dim(trinity_vsa_vector_t v);

/**
 * @brief Get trit value at index
 * @param v Vector handle
 * @param index Trit position (0-based)
 * @return Trit value: -1, 0, or +1 (0 on out-of-bounds or NULL)
 */
int8_t trinity_vsa_get_trit(trinity_vsa_vector_t v, size_t index);

/**
 * @brief Set trit value at index
 * @param v Vector handle
 * @param index Trit position (0-based)
 * @param value Trit value (clamped to {-1, 0, +1})
 */
void trinity_vsa_set_trit(trinity_vsa_vector_t v, size_t index, int8_t value);

/**
 * @brief Copy trit data to output array
 * @param v Vector handle
 * @param out Output array of int8
 * @param max_len Maximum elements to copy
 * @return Number of trits actually copied
 */
size_t trinity_vsa_to_array(trinity_vsa_vector_t v, int8_t* out, size_t max_len);

#ifdef __cplusplus
}
#endif

#endif /* TRINITY_VSA_H */
