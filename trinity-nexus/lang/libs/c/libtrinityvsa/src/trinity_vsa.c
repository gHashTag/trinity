/**
 * @file trinity_vsa.c
 * @brief Trinity VSA implementation
 */

#include "trinity_vsa.h"
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <time.h>

#define TRINITY_VERSION "0.1.0"

/* ============================================================================
 * Internal helpers
 * ============================================================================ */

static uint64_t xorshift64(uint64_t* state) {
    uint64_t x = *state;
    x ^= x << 13;
    x ^= x >> 7;
    x ^= x << 17;
    *state = x;
    return x;
}

/* ============================================================================
 * Vector Creation/Destruction
 * ============================================================================ */

trit_vector_t* trit_vector_zeros(size_t dim) {
    trit_vector_t* v = malloc(sizeof(trit_vector_t));
    if (!v) return NULL;
    
    v->data = calloc(dim, sizeof(int8_t));
    if (!v->data) {
        free(v);
        return NULL;
    }
    
    v->dim = dim;
    v->owned = true;
    return v;
}

trit_vector_t* trit_vector_random(size_t dim, uint64_t seed) {
    trit_vector_t* v = malloc(sizeof(trit_vector_t));
    if (!v) return NULL;
    
    v->data = malloc(dim * sizeof(int8_t));
    if (!v->data) {
        free(v);
        return NULL;
    }
    
    uint64_t state = seed ? seed : (uint64_t)time(NULL);
    
    for (size_t i = 0; i < dim; i++) {
        uint64_t r = xorshift64(&state);
        int val = (int)(r % 3) - 1;  /* -1, 0, or 1 */
        v->data[i] = (int8_t)val;
    }
    
    v->dim = dim;
    v->owned = true;
    return v;
}

trit_vector_t* trit_vector_from_array(const int8_t* data, size_t dim) {
    trit_vector_t* v = malloc(sizeof(trit_vector_t));
    if (!v) return NULL;
    
    v->data = malloc(dim * sizeof(int8_t));
    if (!v->data) {
        free(v);
        return NULL;
    }
    
    /* Copy and clamp to {-1, 0, 1} */
    for (size_t i = 0; i < dim; i++) {
        int8_t val = data[i];
        if (val > 0) v->data[i] = 1;
        else if (val < 0) v->data[i] = -1;
        else v->data[i] = 0;
    }
    
    v->dim = dim;
    v->owned = true;
    return v;
}

trit_vector_t* trit_vector_wrap(int8_t* data, size_t dim) {
    trit_vector_t* v = malloc(sizeof(trit_vector_t));
    if (!v) return NULL;
    
    v->data = data;
    v->dim = dim;
    v->owned = false;
    return v;
}

void trit_vector_free(trit_vector_t* v) {
    if (!v) return;
    if (v->owned && v->data) {
        free(v->data);
    }
    free(v);
}

trit_vector_t* trit_vector_clone(const trit_vector_t* v) {
    if (!v) return NULL;
    return trit_vector_from_array(v->data, v->dim);
}

/* ============================================================================
 * VSA Operations
 * ============================================================================ */

trit_vector_t* trit_bind(const trit_vector_t* a, const trit_vector_t* b) {
    if (!a || !b || a->dim != b->dim) return NULL;
    
    trit_vector_t* result = trit_vector_zeros(a->dim);
    if (!result) return NULL;
    
    for (size_t i = 0; i < a->dim; i++) {
        result->data[i] = a->data[i] * b->data[i];
    }
    
    return result;
}

void trit_bind_inplace(trit_vector_t* result, const trit_vector_t* a, const trit_vector_t* b) {
    if (!result || !a || !b) return;
    if (result->dim != a->dim || a->dim != b->dim) return;
    
    for (size_t i = 0; i < a->dim; i++) {
        result->data[i] = a->data[i] * b->data[i];
    }
}

trit_vector_t* trit_bundle(const trit_vector_t** vectors, size_t count) {
    if (!vectors || count == 0) return NULL;
    
    size_t dim = vectors[0]->dim;
    
    /* Allocate sum array */
    int32_t* sums = calloc(dim, sizeof(int32_t));
    if (!sums) return NULL;
    
    /* Sum all vectors */
    for (size_t v = 0; v < count; v++) {
        if (vectors[v]->dim != dim) {
            free(sums);
            return NULL;
        }
        for (size_t i = 0; i < dim; i++) {
            sums[i] += vectors[v]->data[i];
        }
    }
    
    /* Threshold */
    trit_vector_t* result = trit_vector_zeros(dim);
    if (!result) {
        free(sums);
        return NULL;
    }
    
    for (size_t i = 0; i < dim; i++) {
        if (sums[i] > 0) result->data[i] = 1;
        else if (sums[i] < 0) result->data[i] = -1;
        else result->data[i] = 0;
    }
    
    free(sums);
    return result;
}

trit_vector_t* trit_permute(const trit_vector_t* v, int32_t shift) {
    if (!v) return NULL;
    
    trit_vector_t* result = trit_vector_zeros(v->dim);
    if (!result) return NULL;
    
    size_t dim = v->dim;
    int32_t s = ((shift % (int32_t)dim) + (int32_t)dim) % (int32_t)dim;
    
    for (size_t i = 0; i < dim; i++) {
        size_t new_idx = (i + s) % dim;
        result->data[new_idx] = v->data[i];
    }
    
    return result;
}

double trit_similarity(const trit_vector_t* a, const trit_vector_t* b) {
    if (!a || !b || a->dim != b->dim) return 0.0;
    
    int64_t dot = 0;
    double norm_a = 0.0, norm_b = 0.0;
    
    for (size_t i = 0; i < a->dim; i++) {
        dot += (int64_t)a->data[i] * (int64_t)b->data[i];
        norm_a += (double)a->data[i] * (double)a->data[i];
        norm_b += (double)b->data[i] * (double)b->data[i];
    }
    
    norm_a = sqrt(norm_a);
    norm_b = sqrt(norm_b);
    
    if (norm_a == 0.0 || norm_b == 0.0) return 0.0;
    
    return (double)dot / (norm_a * norm_b);
}

int64_t trit_dot(const trit_vector_t* a, const trit_vector_t* b) {
    if (!a || !b || a->dim != b->dim) return 0;
    
    int64_t sum = 0;
    for (size_t i = 0; i < a->dim; i++) {
        sum += (int64_t)a->data[i] * (int64_t)b->data[i];
    }
    return sum;
}

size_t trit_hamming_distance(const trit_vector_t* a, const trit_vector_t* b) {
    if (!a || !b || a->dim != b->dim) return 0;
    
    size_t dist = 0;
    for (size_t i = 0; i < a->dim; i++) {
        if (a->data[i] != b->data[i]) dist++;
    }
    return dist;
}

/* ============================================================================
 * Packed Operations
 * ============================================================================ */

packed_trit_vec_t* packed_from_trit_vector(const trit_vector_t* v) {
    if (!v) return NULL;
    
    packed_trit_vec_t* p = malloc(sizeof(packed_trit_vec_t));
    if (!p) return NULL;
    
    p->dim = v->dim;
    p->num_words = (v->dim + 63) / 64;
    
    p->pos = calloc(p->num_words, sizeof(uint64_t));
    p->neg = calloc(p->num_words, sizeof(uint64_t));
    
    if (!p->pos || !p->neg) {
        free(p->pos);
        free(p->neg);
        free(p);
        return NULL;
    }
    
    for (size_t i = 0; i < v->dim; i++) {
        size_t word_idx = i / 64;
        size_t bit_idx = i % 64;
        uint64_t mask = 1ULL << bit_idx;
        
        if (v->data[i] == 1) {
            p->pos[word_idx] |= mask;
        } else if (v->data[i] == -1) {
            p->neg[word_idx] |= mask;
        }
    }
    
    return p;
}

trit_vector_t* packed_to_trit_vector(const packed_trit_vec_t* p) {
    if (!p) return NULL;
    
    trit_vector_t* v = trit_vector_zeros(p->dim);
    if (!v) return NULL;
    
    for (size_t i = 0; i < p->dim; i++) {
        size_t word_idx = i / 64;
        size_t bit_idx = i % 64;
        uint64_t mask = 1ULL << bit_idx;
        
        if (p->pos[word_idx] & mask) {
            v->data[i] = 1;
        } else if (p->neg[word_idx] & mask) {
            v->data[i] = -1;
        }
    }
    
    return v;
}

void packed_free(packed_trit_vec_t* p) {
    if (!p) return;
    free(p->pos);
    free(p->neg);
    free(p);
}

packed_trit_vec_t* packed_bind(const packed_trit_vec_t* a, const packed_trit_vec_t* b) {
    if (!a || !b || a->dim != b->dim) return NULL;
    
    packed_trit_vec_t* result = malloc(sizeof(packed_trit_vec_t));
    if (!result) return NULL;
    
    result->dim = a->dim;
    result->num_words = a->num_words;
    result->pos = malloc(a->num_words * sizeof(uint64_t));
    result->neg = malloc(a->num_words * sizeof(uint64_t));
    
    if (!result->pos || !result->neg) {
        free(result->pos);
        free(result->neg);
        free(result);
        return NULL;
    }
    
    for (size_t i = 0; i < a->num_words; i++) {
        /* +1 when: (a=+1 AND b=+1) OR (a=-1 AND b=-1) */
        result->pos[i] = (a->pos[i] & b->pos[i]) | (a->neg[i] & b->neg[i]);
        /* -1 when: (a=+1 AND b=-1) OR (a=-1 AND b=+1) */
        result->neg[i] = (a->pos[i] & b->neg[i]) | (a->neg[i] & b->pos[i]);
    }
    
    return result;
}

static int popcount64(uint64_t x) {
#ifdef __GNUC__
    return __builtin_popcountll(x);
#else
    int count = 0;
    while (x) {
        count += x & 1;
        x >>= 1;
    }
    return count;
#endif
}

int64_t packed_dot(const packed_trit_vec_t* a, const packed_trit_vec_t* b) {
    if (!a || !b || a->dim != b->dim) return 0;
    
    int64_t sum = 0;
    
    for (size_t i = 0; i < a->num_words; i++) {
        /* +1 contributions */
        sum += popcount64(a->pos[i] & b->pos[i]);
        sum += popcount64(a->neg[i] & b->neg[i]);
        /* -1 contributions */
        sum -= popcount64(a->pos[i] & b->neg[i]);
        sum -= popcount64(a->neg[i] & b->pos[i]);
    }
    
    return sum;
}

/* ============================================================================
 * Utility Functions
 * ============================================================================ */

size_t trit_vector_nnz(const trit_vector_t* v) {
    if (!v) return 0;
    
    size_t count = 0;
    for (size_t i = 0; i < v->dim; i++) {
        if (v->data[i] != 0) count++;
    }
    return count;
}

double trit_vector_sparsity(const trit_vector_t* v) {
    if (!v || v->dim == 0) return 0.0;
    return 1.0 - ((double)trit_vector_nnz(v) / (double)v->dim);
}

void trit_vector_negate(trit_vector_t* v) {
    if (!v) return;
    for (size_t i = 0; i < v->dim; i++) {
        v->data[i] = -v->data[i];
    }
}

bool trinity_has_avx2(void) {
#if defined(__AVX2__)
    return true;
#else
    return false;
#endif
}

bool trinity_has_avx512(void) {
#if defined(__AVX512F__)
    return true;
#else
    return false;
#endif
}

const char* trinity_version(void) {
    return TRINITY_VERSION;
}
