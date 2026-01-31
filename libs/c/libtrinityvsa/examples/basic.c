/**
 * Basic example of libtrinityvsa usage
 */

#include <stdio.h>
#include <stdlib.h>
#include "trinity_vsa.h"

int main(void) {
    printf("=== Trinity VSA C Library Demo ===\n\n");
    
    // Check SIMD support
    printf("AVX2 support: %s\n", trinity_has_avx2() ? "yes" : "no");
    printf("AVX-512 support: %s\n\n", trinity_has_avx512() ? "yes" : "no");
    
    const size_t dim = 10000;
    
    // Create random hypervectors
    printf("Creating hypervectors (dim=%zu)...\n", dim);
    trit_vector_t* apple = trit_vector_random(dim, 42);
    trit_vector_t* red = trit_vector_random(dim, 123);
    trit_vector_t* fruit = trit_vector_random(dim, 456);
    
    if (!apple || !red || !fruit) {
        fprintf(stderr, "Failed to create vectors\n");
        return 1;
    }
    
    // Check sparsity
    printf("Apple sparsity: %.2f%%\n", trit_vector_sparsity(apple) * 100);
    printf("Apple non-zeros: %zu\n\n", trit_vector_nnz(apple));
    
    // Bind: create association
    printf("Binding apple + red...\n");
    trit_vector_t* red_apple = trit_bind(apple, red);
    
    // Similarity tests
    printf("\nSimilarity tests:\n");
    printf("  sim(red_apple, apple) = %.4f\n", trit_similarity(red_apple, apple));
    printf("  sim(red_apple, red)   = %.4f\n", trit_similarity(red_apple, red));
    printf("  sim(red_apple, fruit) = %.4f (unrelated)\n", trit_similarity(red_apple, fruit));
    
    // Unbind: recover original
    printf("\nUnbinding to recover apple...\n");
    trit_vector_t* recovered = trit_unbind(red_apple, red);
    printf("  sim(recovered, apple) = %.4f (should be ~1.0)\n", trit_similarity(recovered, apple));
    
    // Bundle: superposition
    printf("\nBundling apple + red + fruit...\n");
    const trit_vector_t* vectors[3] = {apple, red, fruit};
    trit_vector_t* bundle = trit_bundle(vectors, 3);
    
    printf("  sim(bundle, apple) = %.4f\n", trit_similarity(bundle, apple));
    printf("  sim(bundle, red)   = %.4f\n", trit_similarity(bundle, red));
    printf("  sim(bundle, fruit) = %.4f\n", trit_similarity(bundle, fruit));
    
    // Permute: sequence encoding
    printf("\nPermutation test...\n");
    trit_vector_t* permuted = trit_permute(apple, 1);
    printf("  sim(permuted, apple) = %.4f (should be ~0)\n", trit_similarity(permuted, apple));
    
    // Inverse permute
    trit_vector_t* unpermuted = trit_permute(permuted, -1);
    printf("  sim(unpermuted, apple) = %.4f (should be ~1.0)\n", trit_similarity(unpermuted, apple));
    
    // Packed operations demo
    printf("\nPacked (bitsliced) operations...\n");
    packed_trit_vec_t* packed_a = packed_from_trit_vector(apple);
    packed_trit_vec_t* packed_r = packed_from_trit_vector(red);
    
    if (packed_a && packed_r) {
        int64_t dot = packed_dot(packed_a, packed_r);
        printf("  packed_dot(apple, red) = %ld\n", dot);
        
        packed_trit_vec_t* packed_bound = packed_bind(packed_a, packed_r);
        if (packed_bound) {
            printf("  packed_bind successful\n");
            packed_free(packed_bound);
        }
        
        packed_free(packed_a);
        packed_free(packed_r);
    }
    
    // Cleanup
    printf("\nCleaning up...\n");
    trit_vector_free(apple);
    trit_vector_free(red);
    trit_vector_free(fruit);
    trit_vector_free(red_apple);
    trit_vector_free(recovered);
    trit_vector_free(bundle);
    trit_vector_free(permuted);
    trit_vector_free(unpermuted);
    
    printf("\n=== Demo complete ===\n");
    return 0;
}
