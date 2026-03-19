# libtrinityvsa

C library for Vector Symbolic Architecture with balanced ternary arithmetic.

## Building

```bash
# Static library
gcc -c -O3 -mavx2 -I include src/trinity_vsa.c -o trinity_vsa.o
ar rcs libtrinityvsa.a trinity_vsa.o

# Shared library
gcc -shared -fPIC -O3 -mavx2 -I include src/trinity_vsa.c -o libtrinityvsa.so
```

## Usage

```c
#include <stdio.h>
#include "trinity_vsa.h"

int main() {
    // Create random hypervectors
    trit_vector_t* apple = trit_vector_random(10000, 1);
    trit_vector_t* red = trit_vector_random(10000, 2);
    
    // Bind: create association
    trit_vector_t* red_apple = trit_bind(apple, red);
    
    // Similarity
    double sim = trit_similarity(red_apple, apple);
    printf("Similarity: %.3f\n", sim);
    
    // Unbind
    trit_vector_t* recovered = trit_unbind(red_apple, red);
    double recovery = trit_similarity(recovered, apple);
    printf("Recovery: %.3f\n", recovery);
    
    // Cleanup
    trit_vector_free(apple);
    trit_vector_free(red);
    trit_vector_free(red_apple);
    trit_vector_free(recovered);
    
    return 0;
}
```

## API

### Types

```c
typedef enum { TRIT_NEG = -1, TRIT_ZERO = 0, TRIT_POS = 1 } trit_t;

typedef struct {
    int8_t* data;
    size_t dim;
    bool owned;
} trit_vector_t;

typedef struct {
    uint64_t* pos;
    uint64_t* neg;
    size_t dim;
    size_t num_words;
} packed_trit_vec_t;
```

### Functions

| Function | Description |
|----------|-------------|
| `trit_vector_zeros(dim)` | Create zero vector |
| `trit_vector_random(dim, seed)` | Create random vector |
| `trit_vector_free(v)` | Free vector |
| `trit_bind(a, b)` | Bind two vectors |
| `trit_bundle(vectors, count)` | Bundle multiple vectors |
| `trit_permute(v, shift)` | Circular shift |
| `trit_similarity(a, b)` | Cosine similarity |
| `trit_dot(a, b)` | Dot product |
| `trit_hamming_distance(a, b)` | Hamming distance |

### Packed Operations (SIMD)

| Function | Description |
|----------|-------------|
| `packed_from_trit_vector(v)` | Pack dense vector |
| `packed_to_trit_vector(p)` | Unpack to dense |
| `packed_bind(a, b)` | Fast bitwise bind |
| `packed_dot(a, b)` | Fast dot product |

## License

MIT License
