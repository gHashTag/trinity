// ═══════════════════════════════════════════════════════════════════════════════
// IGLA METAL BENCHMARK — GPU Performance Test
// ═══════════════════════════════════════════════════════════════════════════════
//
// Benchmark Metal GPU performance for VSA batch similarity.
// Target: 10,000+ ops/s on Apple Silicon
//
// Build:
//   clang -O3 -framework Metal -framework Foundation \
//         igla_metal_bridge.m igla_metal_benchmark.m \
//         -o igla_metal_benchmark
//
// phi^2 + 1/phi^2 = 3 = TRINITY | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

#import <Foundation/Foundation.h>
#import "igla_metal_bridge.h"
#include <stdio.h>
#include <stdlib.h>
#include <math.h>

int main(int argc, char** argv) {
    @autoreleasepool {
        printf("\n");
        printf("╔══════════════════════════════════════════════════════════════╗\n");
        printf("║     IGLA METAL GPU BENCHMARK v1.0                            ║\n");
        printf("║     Target: 10,000+ ops/s | Vocab: 50K | Dim: 300            ║\n");
        printf("║     phi^2 + 1/phi^2 = 3 = TRINITY                            ║\n");
        printf("╚══════════════════════════════════════════════════════════════╝\n");

        // Initialize Metal
        printf("\n  Initializing Metal...\n");
        int result = igla_metal_init();
        if (result != IGLA_SUCCESS) {
            printf("  ERROR: Failed to initialize Metal (code %d)\n", result);
            return 1;
        }

        printf("  Device: %s\n", igla_metal_device_name());
        printf("  Status: Metal GPU AVAILABLE\n");

        // Run benchmarks at different vocab sizes
        printf("\n═══════════════════════════════════════════════════════════════\n");
        printf("     SCALABLE BENCHMARK RESULTS                                \n");
        printf("═══════════════════════════════════════════════════════════════\n");
        printf("  Vocab Size │ ops/s     │ M elem/s │ Status\n");
        printf("  ───────────┼───────────┼──────────┼────────────\n");

        uint32_t vocab_sizes[] = {1000, 5000, 10000, 25000, 50000};
        int num_sizes = sizeof(vocab_sizes) / sizeof(vocab_sizes[0]);
        uint32_t iterations = 1000;

        for (int i = 0; i < num_sizes; i++) {
            uint32_t vocab_size = vocab_sizes[i];
            double ops_per_sec = igla_metal_benchmark(vocab_size, iterations);
            double elem_per_sec = ops_per_sec * vocab_size * IGLA_EMBEDDING_DIM;

            const char* status;
            if (ops_per_sec >= 10000) {
                status = "10K+ ✓ TARGET";
            } else if (ops_per_sec >= 5000) {
                status = "5K+";
            } else if (ops_per_sec >= 1000) {
                status = "1K+";
            } else {
                status = "< 1K";
            }

            printf("  %9u │ %9.0f │ %8.1f │ %s\n",
                   vocab_size, ops_per_sec, elem_per_sec / 1e6, status);
        }

        printf("  ───────────┴───────────┴──────────┴────────────\n");

        // Full 50K benchmark
        printf("\n  Running full 50K vocab benchmark (%u iterations)...\n", iterations);
        igla_metal_reset_stats();
        double full_ops = igla_metal_benchmark(50000, iterations);

        printf("\n═══════════════════════════════════════════════════════════════\n");
        printf("     FULL 50K BENCHMARK                                        \n");
        printf("═══════════════════════════════════════════════════════════════\n");
        printf("  Vocab Size: 50000\n");
        printf("  Embedding Dim: %d\n", IGLA_EMBEDDING_DIM);
        printf("  GPU: %s\n", igla_metal_device_name());
        printf("\n");
        printf("  Speed: %.1f ops/s\n", full_ops);
        printf("  Throughput: %.2f M elements/s\n", full_ops * 50000 * 300 / 1e6);

        if (full_ops >= 10000) {
            printf("\n  STATUS: TARGET MET! 10K+ ops/s achieved on GPU\n");
        } else if (full_ops >= 5000) {
            printf("\n  STATUS: 5K+ ops/s — Close to target\n");
        } else if (full_ops >= 1000) {
            printf("\n  STATUS: 1K+ ops/s — GPU working\n");
        } else {
            printf("\n  STATUS: Below expected GPU performance\n");
        }

        printf("\n═══════════════════════════════════════════════════════════════\n");
        printf("phi^2 + 1/phi^2 = 3 = TRINITY | KOSCHEI IS IMMORTAL\n");
        printf("\n");

        // Cleanup
        igla_metal_deinit();

        return 0;
    }
}
