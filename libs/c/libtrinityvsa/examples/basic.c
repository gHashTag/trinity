/**
 * @file basic.c
 * @brief Basic example of libtrinity-vsa usage (Zig-backed C API)
 *
 * Build:
 *   zig build libvsa
 *   cc -I zig-out/include -L zig-out/lib -ltrinity-vsa basic.c -o basic
 *   ./basic
 */

#include <stdio.h>
#include "trinity_vsa.h"

int main(void) {
    printf("=== Trinity VSA C Library Demo ===\n");
    printf("Version: %s\n", trinity_vsa_version());
    printf("Max dimension: %zu\n\n", trinity_vsa_max_dim());

    const size_t dim = 10000;

    /* Create random hypervectors */
    printf("Creating hypervectors (dim=%zu)...\n", dim);
    trinity_vsa_vector_t apple = trinity_vsa_vector_random(dim, 42);
    trinity_vsa_vector_t red   = trinity_vsa_vector_random(dim, 123);
    trinity_vsa_vector_t fruit = trinity_vsa_vector_random(dim, 456);

    if (!apple || !red || !fruit) {
        fprintf(stderr, "Failed to create vectors\n");
        return 1;
    }

    printf("  apple dim: %zu\n", trinity_vsa_get_dim(apple));
    printf("  apple[0] = %d, apple[1] = %d, apple[2] = %d\n\n",
           trinity_vsa_get_trit(apple, 0),
           trinity_vsa_get_trit(apple, 1),
           trinity_vsa_get_trit(apple, 2));

    /* Bind: create association (apple * red) */
    printf("Binding apple + red...\n");
    trinity_vsa_vector_t red_apple = trinity_vsa_bind(apple, red);

    printf("  sim(red_apple, apple) = %.4f\n",
           trinity_vsa_cosine_similarity(red_apple, apple));
    printf("  sim(red_apple, red)   = %.4f\n",
           trinity_vsa_cosine_similarity(red_apple, red));
    printf("  sim(red_apple, fruit) = %.4f (unrelated)\n\n",
           trinity_vsa_cosine_similarity(red_apple, fruit));

    /* Unbind: recover original */
    printf("Unbinding to recover apple...\n");
    trinity_vsa_vector_t recovered = trinity_vsa_unbind(red_apple, red);
    printf("  sim(recovered, apple) = %.4f (should be ~1.0)\n\n",
           trinity_vsa_cosine_similarity(recovered, apple));

    /* Bundle: superposition */
    printf("Bundling apple + fruit...\n");
    trinity_vsa_vector_t bundle = trinity_vsa_bundle2(apple, fruit);
    printf("  sim(bundle, apple) = %.4f\n",
           trinity_vsa_cosine_similarity(bundle, apple));
    printf("  sim(bundle, fruit) = %.4f\n",
           trinity_vsa_cosine_similarity(bundle, fruit));
    printf("  sim(bundle, red)   = %.4f (unrelated)\n\n",
           trinity_vsa_cosine_similarity(bundle, red));

    /* Permute: sequence encoding */
    printf("Permutation test...\n");
    trinity_vsa_vector_t permuted = trinity_vsa_permute(apple, 5);
    printf("  sim(permuted, apple) = %.4f (should be ~0)\n\n",
           trinity_vsa_cosine_similarity(permuted, apple));

    /* Hamming distance */
    printf("Distance metrics:\n");
    trinity_vsa_vector_t apple_clone = trinity_vsa_vector_clone(apple);
    printf("  hamming(apple, apple_clone) = %zu (should be 0)\n",
           trinity_vsa_hamming_distance(apple, apple_clone));
    printf("  hamming(apple, red)         = %zu\n",
           trinity_vsa_hamming_distance(apple, red));
    printf("  dot(apple, red)             = %ld\n\n",
           (long)trinity_vsa_dot_product(apple, red));

    /* Cleanup */
    printf("Cleaning up...\n");
    trinity_vsa_vector_free(apple);
    trinity_vsa_vector_free(red);
    trinity_vsa_vector_free(fruit);
    trinity_vsa_vector_free(red_apple);
    trinity_vsa_vector_free(recovered);
    trinity_vsa_vector_free(bundle);
    trinity_vsa_vector_free(permuted);
    trinity_vsa_vector_free(apple_clone);

    printf("\n=== Demo complete ===\n");
    return 0;
}
