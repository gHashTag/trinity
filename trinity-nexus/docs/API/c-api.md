---
sidebar_position: 11
sidebar_label: C API (libtrinity-vsa)
---

# C API Reference — libtrinity-vsa

SIMD-accelerated ternary VSA library for C, C++, Python, Swift, Go, and any FFI-capable language.

**Header:** `trinity_vsa.h`
**Library:** `libtrinity-vsa.dylib` (macOS) / `libtrinity-vsa.so` (Linux)
**Source:** `src/c_api.zig`

## Build

```bash
# Build shared + static library
zig build libvsa

# Outputs:
#   zig-out/lib/libtrinity-vsa.dylib   (70 KB)
#   zig-out/lib/libtrinity-vsa-static.a (128 KB)
#   zig-out/include/trinity_vsa.h

# Compile C program against the library
cc -I zig-out/include -L zig-out/lib -ltrinity-vsa my_app.c -o my_app

# Run (macOS needs library path)
DYLD_LIBRARY_PATH=zig-out/lib ./my_app
```

## Design

All vectors are **opaque handles** (`void*`). The library allocates vectors on the heap internally. Every vector returned by a create/operation function must be freed with `trinity_vsa_vector_free()`.

```
NULL-safe: all functions handle NULL gracefully (return 0/NULL, no crash).
Thread-safe: each vector is independent, no global state.
```

## Library Info

### trinity_vsa_version

```c
const char* trinity_vsa_version(void);
```

Returns null-terminated version string (e.g. `"0.2.0"`).

### trinity_vsa_max_dim

```c
size_t trinity_vsa_max_dim(void);
```

Returns maximum supported dimension: `59049` (3^10).

## Vector Lifecycle

### trinity_vsa_vector_zeros

```c
trinity_vsa_vector_t trinity_vsa_vector_zeros(size_t dim);
```

Create a zero vector with given dimension (max 59049). Returns `NULL` on failure.

### trinity_vsa_vector_random

```c
trinity_vsa_vector_t trinity_vsa_vector_random(size_t dim, uint64_t seed);
```

Create a random hypervector. Deterministic: same seed produces the same vector.

```c
trinity_vsa_vector_t apple = trinity_vsa_vector_random(10000, 42);
trinity_vsa_vector_t red   = trinity_vsa_vector_random(10000, 123);
// apple and red are quasi-orthogonal (~0 similarity)
```

### trinity_vsa_from_array

```c
trinity_vsa_vector_t trinity_vsa_from_array(const int8_t* data, size_t dim);
```

Create vector from int8 array. Values are clamped to \{-1, 0, +1\}.

### trinity_vsa_vector_clone

```c
trinity_vsa_vector_t trinity_vsa_vector_clone(trinity_vsa_vector_t v);
```

Deep copy. Returns new handle.

### trinity_vsa_vector_free

```c
void trinity_vsa_vector_free(trinity_vsa_vector_t v);
```

Free a vector. NULL-safe (no-op on NULL). **Must be called for every created vector.**

## VSA Operations

### trinity_vsa_bind

```c
trinity_vsa_vector_t trinity_vsa_bind(trinity_vsa_vector_t a, trinity_vsa_vector_t b);
```

Element-wise multiplication. Creates associations.

**Properties:**
- `bind(a, a)` = all +1 (self-inverse)
- `bind(bind(a, b), b)` = a (unbinding)
- Commutative: `bind(a, b)` = `bind(b, a)`

```c
// Create association: country -> capital
trinity_vsa_vector_t france = trinity_vsa_encode_text_words("france", 6);
trinity_vsa_vector_t paris  = trinity_vsa_encode_text_words("paris", 5);
trinity_vsa_vector_t pair   = trinity_vsa_bind(france, paris);
```

### trinity_vsa_unbind

```c
trinity_vsa_vector_t trinity_vsa_unbind(trinity_vsa_vector_t a, trinity_vsa_vector_t b);
```

Inverse of bind (same operation for balanced ternary). Retrieves one vector from a binding.

```c
// Query: what is the capital of France?
trinity_vsa_vector_t result = trinity_vsa_unbind(pair, france);
// result ~ paris (similarity > 0.8)
```

### trinity_vsa_bundle2

```c
trinity_vsa_vector_t trinity_vsa_bundle2(trinity_vsa_vector_t a, trinity_vsa_vector_t b);
```

Majority voting of 2 vectors. Result is similar to both inputs.

```c
trinity_vsa_vector_t fruits = trinity_vsa_bundle2(apple, orange);
// similarity(fruits, apple)  > 0.5
// similarity(fruits, orange) > 0.5
```

### trinity_vsa_bundle3

```c
trinity_vsa_vector_t trinity_vsa_bundle3(
    trinity_vsa_vector_t a, trinity_vsa_vector_t b, trinity_vsa_vector_t c);
```

True majority voting of 3 vectors.

### trinity_vsa_permute

```c
trinity_vsa_vector_t trinity_vsa_permute(trinity_vsa_vector_t v, size_t k);
```

Cyclic shift by `k` positions. Used for sequence/position encoding.

## Similarity Measures

### trinity_vsa_cosine_similarity

```c
double trinity_vsa_cosine_similarity(trinity_vsa_vector_t a, trinity_vsa_vector_t b);
```

Returns similarity in [-1.0, 1.0]:
- `1.0` — identical
- `0.0` — orthogonal (unrelated)
- `-1.0` — opposite

**Performance:** ~0.05 ms per call (SIMD-accelerated).

### trinity_vsa_hamming_distance

```c
size_t trinity_vsa_hamming_distance(trinity_vsa_vector_t a, trinity_vsa_vector_t b);
```

Number of positions where trits differ.

### trinity_vsa_dot_product

```c
int64_t trinity_vsa_dot_product(trinity_vsa_vector_t a, trinity_vsa_vector_t b);
```

Sum of element-wise products.

## Text Encoding

### trinity_vsa_encode_text

```c
trinity_vsa_vector_t trinity_vsa_encode_text(const char* text, size_t len);
```

Character-level positional encoding. Good for exact/near-exact string matching.

### trinity_vsa_encode_text_words

```c
trinity_vsa_vector_t trinity_vsa_encode_text_words(const char* text, size_t len);
```

**Word-level bag-of-words encoding.** Splits text into words, encodes each independently, bundles via majority vote. Texts sharing words have high similarity regardless of word order.

**This is the recommended function for semantic search.**

```c
trinity_vsa_vector_t q = trinity_vsa_encode_text_words("machine learning", 16);
trinity_vsa_vector_t d = trinity_vsa_encode_text_words(
    "machine learning algorithms for classification", 47);
double sim = trinity_vsa_cosine_similarity(q, d);
// sim = 0.5317 (strong match — shared words)
```

**Performance:** ~1.4 ms per call.

### trinity_vsa_decode_text

```c
size_t trinity_vsa_decode_text(trinity_vsa_vector_t v, char* buf, size_t buf_len);
```

Decode hypervector back to text (character-level). Returns number of decoded characters.

## Vector Access

### trinity_vsa_get_dim

```c
size_t trinity_vsa_get_dim(trinity_vsa_vector_t v);
```

Get vector dimension (number of trits).

### trinity_vsa_get_trit / trinity_vsa_set_trit

```c
int8_t trinity_vsa_get_trit(trinity_vsa_vector_t v, size_t index);
void   trinity_vsa_set_trit(trinity_vsa_vector_t v, size_t index, int8_t value);
```

Read/write individual trit values. Values are clamped to \{-1, 0, +1\}.

### trinity_vsa_to_array

```c
size_t trinity_vsa_to_array(trinity_vsa_vector_t v, int8_t* out, size_t max_len);
```

Export trit data to array. Returns number of trits copied.

## Complete Example

```c
#include <stdio.h>
#include <string.h>
#include "trinity_vsa.h"

int main(void) {
    printf("Trinity VSA v%s\n", trinity_vsa_version());

    // Encode texts
    const char* texts[] = {
        "machine learning algorithms",
        "database query optimization",
        "ternary computing balanced"
    };
    trinity_vsa_vector_t vecs[3];
    for (int i = 0; i < 3; i++) {
        vecs[i] = trinity_vsa_encode_text_words(texts[i], strlen(texts[i]));
    }

    // Search
    const char* query = "machine learning";
    trinity_vsa_vector_t q = trinity_vsa_encode_text_words(query, strlen(query));

    for (int i = 0; i < 3; i++) {
        double sim = trinity_vsa_cosine_similarity(q, vecs[i]);
        printf("  [%.4f] %s\n", sim, texts[i]);
    }

    // Cleanup
    trinity_vsa_vector_free(q);
    for (int i = 0; i < 3; i++) trinity_vsa_vector_free(vecs[i]);

    return 0;
}
```

## Test Coverage

213 tests passing across the C API and underlying VSA core:
- Null safety for all functions
- Bind self-inverse property
- Bind/unbind roundtrip (similarity > 0.7)
- Clone equality (similarity = 1.0)
- From_array / to_array roundtrip
- Text encode similarity (identical = 1.0)
- Bundle2 similarity to both inputs
- Permute dissimilarity
- Hamming distance (identical = 0)
