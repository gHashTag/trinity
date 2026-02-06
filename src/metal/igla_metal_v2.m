// ═══════════════════════════════════════════════════════════════════════════════
// IGLA METAL v2.0 — Async Pipelined GPU Compute
// ═══════════════════════════════════════════════════════════════════════════════
//
// Optimized for 10K+ ops/s at 100K vocabulary scale.
// Key optimizations:
// 1. Batch multiple queries per command buffer (amortize overhead)
// 2. Async pipelining with completion handlers
// 3. Double-buffered command submission
// 4. Pre-allocated resource pools
//
// Build:
//   clang -O3 -framework Metal -framework Foundation igla_metal_v2.m -o igla_metal_v2_bench
//
// phi^2 + 1/phi^2 = 3 = TRINITY | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#include <mach/mach_time.h>
#include <stdio.h>
#include <stdlib.h>
#include <dispatch/dispatch.h>

// ═══════════════════════════════════════════════════════════════════════════════
// CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

#define EMBEDDING_DIM 300
#define MAX_VOCAB 100000
#define THREADS_PER_GROUP 256
#define BATCH_SIZE 64           // Queries per command buffer
#define NUM_BUFFERS 2           // Double buffering

// ═══════════════════════════════════════════════════════════════════════════════
// GLOBAL STATE
// ═══════════════════════════════════════════════════════════════════════════════

static struct {
    id<MTLDevice> device;
    id<MTLCommandQueue> commandQueue;
    id<MTLComputePipelineState> pipeline;

    // Vocabulary (persistent on GPU)
    id<MTLBuffer> vocabBuffer;
    id<MTLBuffer> normsBuffer;
    uint32_t vocabSize;

    // Double-buffered query/result pools
    id<MTLBuffer> queryBuffers[NUM_BUFFERS];
    id<MTLBuffer> resultBuffers[NUM_BUFFERS];
    int currentBuffer;

    // Async state
    dispatch_semaphore_t bufferSemaphore;

    // Stats
    uint64_t totalOps;
    uint64_t totalTimeNs;

    bool initialized;
    char deviceName[128];
} g_v2 = {0};

// ═══════════════════════════════════════════════════════════════════════════════
// TIME UTILITIES
// ═══════════════════════════════════════════════════════════════════════════════

static mach_timebase_info_data_t g_timebase;

static inline uint64_t get_time_ns(void) {
    if (g_timebase.denom == 0) mach_timebase_info(&g_timebase);
    return mach_absolute_time() * g_timebase.numer / g_timebase.denom;
}

// ═══════════════════════════════════════════════════════════════════════════════
// INITIALIZATION
// ═══════════════════════════════════════════════════════════════════════════════

static int init_metal_v2(void) {
    @autoreleasepool {
        if (g_v2.initialized) return 0;

        // Get device
        NSArray<id<MTLDevice>>* devices = MTLCopyAllDevices();
        if (devices && [devices count] > 0) {
            g_v2.device = devices[0];
        }
        if (!g_v2.device) {
            g_v2.device = MTLCreateSystemDefaultDevice();
        }
        if (!g_v2.device) {
            fprintf(stderr, "ERROR: No Metal device\n");
            return -1;
        }

        strncpy(g_v2.deviceName, [[g_v2.device name] UTF8String], sizeof(g_v2.deviceName) - 1);
        printf("  Device: %s\n", g_v2.deviceName);

        g_v2.commandQueue = [g_v2.device newCommandQueue];

        // Compile shader
        NSString* shaderSource = @""
        "#include <metal_stdlib>\n"
        "using namespace metal;\n"
        "#define TG_SIZE 256\n"
        "\n"
        "kernel void batch_similarity(\n"
        "    device const char*  query       [[buffer(0)]],\n"
        "    device const char*  vocab       [[buffer(1)]],\n"
        "    device const float* norms       [[buffer(2)]],\n"
        "    device       float* results     [[buffer(3)]],\n"
        "    constant  uint32_t& dim         [[buffer(4)]],\n"
        "    constant  uint32_t& vocab_size  [[buffer(5)]],\n"
        "    constant    float& query_norm   [[buffer(6)]],\n"
        "    uint word_idx [[threadgroup_position_in_grid]],\n"
        "    uint tid      [[thread_position_in_threadgroup]],\n"
        "    uint tg_size  [[threads_per_threadgroup]]\n"
        ") {\n"
        "    if (word_idx >= vocab_size) return;\n"
        "    threadgroup int sums[TG_SIZE];\n"
        "    device const char* word = vocab + word_idx * dim;\n"
        "    int sum = 0;\n"
        "    for (uint i = tid; i < dim; i += tg_size) {\n"
        "        sum += (int)query[i] * (int)word[i];\n"
        "    }\n"
        "    sums[tid] = sum;\n"
        "    threadgroup_barrier(mem_flags::mem_threadgroup);\n"
        "    for (uint s = tg_size/2; s > 0; s /= 2) {\n"
        "        if (tid < s) sums[tid] += sums[tid + s];\n"
        "        threadgroup_barrier(mem_flags::mem_threadgroup);\n"
        "    }\n"
        "    if (tid == 0) {\n"
        "        float d = query_norm * norms[word_idx];\n"
        "        results[word_idx] = (d > 0.0001f) ? ((float)sums[0] / d) : 0.0f;\n"
        "    }\n"
        "}\n";

        NSError* error = nil;
        MTLCompileOptions* options = [[MTLCompileOptions alloc] init];
        options.fastMathEnabled = YES;

        id<MTLLibrary> library = [g_v2.device newLibraryWithSource:shaderSource options:options error:&error];
        if (!library) {
            fprintf(stderr, "ERROR: Shader compile failed: %s\n", [[error description] UTF8String]);
            return -2;
        }

        id<MTLFunction> func = [library newFunctionWithName:@"batch_similarity"];
        g_v2.pipeline = [g_v2.device newComputePipelineStateWithFunction:func error:&error];
        if (!g_v2.pipeline) {
            fprintf(stderr, "ERROR: Pipeline failed\n");
            return -3;
        }

        // Pre-allocate double buffers
        size_t querySize = EMBEDDING_DIM * sizeof(int8_t);
        size_t resultSize = MAX_VOCAB * sizeof(float);

        for (int i = 0; i < NUM_BUFFERS; i++) {
            g_v2.queryBuffers[i] = [g_v2.device newBufferWithLength:querySize options:MTLResourceStorageModeShared];
            g_v2.resultBuffers[i] = [g_v2.device newBufferWithLength:resultSize options:MTLResourceStorageModeShared];
        }

        g_v2.bufferSemaphore = dispatch_semaphore_create(NUM_BUFFERS);
        g_v2.currentBuffer = 0;
        g_v2.initialized = true;

        return 0;
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// UPLOAD VOCABULARY
// ═══════════════════════════════════════════════════════════════════════════════

static int upload_vocab_v2(const int8_t* matrix, const float* norms, uint32_t size) {
    @autoreleasepool {
        size_t matrix_bytes = (size_t)size * EMBEDDING_DIM;
        size_t norms_bytes = (size_t)size * sizeof(float);

        g_v2.vocabBuffer = [g_v2.device newBufferWithBytes:matrix length:matrix_bytes options:MTLResourceStorageModeShared];
        g_v2.normsBuffer = [g_v2.device newBufferWithBytes:norms length:norms_bytes options:MTLResourceStorageModeShared];
        g_v2.vocabSize = size;

        return 0;
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// BATCHED ASYNC EXECUTION — THE 10K+ OPS/S KERNEL
// ═══════════════════════════════════════════════════════════════════════════════

static double run_batched_benchmark(uint32_t vocab_size, uint32_t total_queries) {
    @autoreleasepool {
        // Create vocabulary
        size_t matrix_size = (size_t)vocab_size * EMBEDDING_DIM;
        int8_t* vocab = (int8_t*)malloc(matrix_size);
        float* norms = (float*)malloc(vocab_size * sizeof(float));

        srand(12345);
        for (size_t i = 0; i < matrix_size; i++) {
            int r = rand() % 3;
            vocab[i] = (r == 0) ? -1 : ((r == 1) ? 0 : 1);
        }
        for (uint32_t w = 0; w < vocab_size; w++) {
            int sum_sq = 0;
            for (uint32_t d = 0; d < EMBEDDING_DIM; d++) {
                int v = vocab[w * EMBEDDING_DIM + d];
                sum_sq += v * v;
            }
            norms[w] = sqrtf((float)sum_sq);
        }

        upload_vocab_v2(vocab, norms, vocab_size);

        // Create query batch
        int8_t queries[BATCH_SIZE][EMBEDDING_DIM];
        float query_norms[BATCH_SIZE];
        for (int q = 0; q < BATCH_SIZE; q++) {
            float norm_sq = 0;
            for (int d = 0; d < EMBEDDING_DIM; d++) {
                int r = rand() % 3;
                queries[q][d] = (r == 0) ? -1 : ((r == 1) ? 0 : 1);
                norm_sq += queries[q][d] * queries[q][d];
            }
            query_norms[q] = sqrtf(norm_sq);
        }

        // Warmup
        for (int i = 0; i < 10; i++) {
            int buf = i % NUM_BUFFERS;
            memcpy([g_v2.queryBuffers[buf] contents], queries[0], EMBEDDING_DIM);

            id<MTLCommandBuffer> cmd = [g_v2.commandQueue commandBuffer];
            id<MTLComputeCommandEncoder> enc = [cmd computeCommandEncoder];
            [enc setComputePipelineState:g_v2.pipeline];
            [enc setBuffer:g_v2.queryBuffers[buf] offset:0 atIndex:0];
            [enc setBuffer:g_v2.vocabBuffer offset:0 atIndex:1];
            [enc setBuffer:g_v2.normsBuffer offset:0 atIndex:2];
            [enc setBuffer:g_v2.resultBuffers[buf] offset:0 atIndex:3];
            [enc setBytes:&(uint32_t){EMBEDDING_DIM} length:4 atIndex:4];
            [enc setBytes:&vocab_size length:4 atIndex:5];
            [enc setBytes:&query_norms[0] length:4 atIndex:6];
            [enc dispatchThreadgroups:MTLSizeMake(vocab_size, 1, 1)
                threadsPerThreadgroup:MTLSizeMake(THREADS_PER_GROUP, 1, 1)];
            [enc endEncoding];
            [cmd commit];
            [cmd waitUntilCompleted];
        }

        // ═══════════════════════════════════════════════════════════════
        // BENCHMARK: Batched async execution
        // ═══════════════════════════════════════════════════════════════

        uint32_t num_batches = (total_queries + BATCH_SIZE - 1) / BATCH_SIZE;
        uint64_t start = get_time_ns();

        for (uint32_t b = 0; b < num_batches; b++) {
            // Get buffer (double-buffered)
            int buf = b % NUM_BUFFERS;

            // Wait for previous use of this buffer to complete
            dispatch_semaphore_wait(g_v2.bufferSemaphore, DISPATCH_TIME_FOREVER);

            // Create command buffer with ALL queries in this batch
            id<MTLCommandBuffer> cmd = [g_v2.commandQueue commandBuffer];

            uint32_t batch_count = (b == num_batches - 1) ?
                                   (total_queries - b * BATCH_SIZE) : BATCH_SIZE;

            // Encode all queries in single command buffer
            for (uint32_t q = 0; q < batch_count; q++) {
                int query_idx = q % BATCH_SIZE;

                // Copy query (reuse same buffer for simplicity)
                memcpy([g_v2.queryBuffers[buf] contents], queries[query_idx], EMBEDDING_DIM);

                id<MTLComputeCommandEncoder> enc = [cmd computeCommandEncoder];
                [enc setComputePipelineState:g_v2.pipeline];
                [enc setBuffer:g_v2.queryBuffers[buf] offset:0 atIndex:0];
                [enc setBuffer:g_v2.vocabBuffer offset:0 atIndex:1];
                [enc setBuffer:g_v2.normsBuffer offset:0 atIndex:2];
                [enc setBuffer:g_v2.resultBuffers[buf] offset:0 atIndex:3];
                [enc setBytes:&(uint32_t){EMBEDDING_DIM} length:4 atIndex:4];
                [enc setBytes:&vocab_size length:4 atIndex:5];
                [enc setBytes:&query_norms[query_idx] length:4 atIndex:6];
                [enc dispatchThreadgroups:MTLSizeMake(vocab_size, 1, 1)
                    threadsPerThreadgroup:MTLSizeMake(THREADS_PER_GROUP, 1, 1)];
                [enc endEncoding];
            }

            // Async completion
            [cmd addCompletedHandler:^(id<MTLCommandBuffer> _Nonnull) {
                dispatch_semaphore_signal(g_v2.bufferSemaphore);
            }];

            [cmd commit];
        }

        // Wait for all to complete
        for (int i = 0; i < NUM_BUFFERS; i++) {
            dispatch_semaphore_wait(g_v2.bufferSemaphore, DISPATCH_TIME_FOREVER);
            dispatch_semaphore_signal(g_v2.bufferSemaphore);
        }

        uint64_t elapsed = get_time_ns() - start;
        double ops_per_sec = (double)total_queries * 1e9 / (double)elapsed;

        free(vocab);
        free(norms);

        return ops_per_sec;
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SINGLE-SHOT (V1 STYLE) FOR COMPARISON
// ═══════════════════════════════════════════════════════════════════════════════

static double run_single_benchmark(uint32_t vocab_size, uint32_t iterations) {
    @autoreleasepool {
        size_t matrix_size = (size_t)vocab_size * EMBEDDING_DIM;
        int8_t* vocab = (int8_t*)malloc(matrix_size);
        float* norms = (float*)malloc(vocab_size * sizeof(float));

        srand(12345);
        for (size_t i = 0; i < matrix_size; i++) {
            vocab[i] = (rand() % 3) - 1;
        }
        for (uint32_t w = 0; w < vocab_size; w++) {
            int sum_sq = 0;
            for (uint32_t d = 0; d < EMBEDDING_DIM; d++) {
                int v = vocab[w * EMBEDDING_DIM + d];
                sum_sq += v * v;
            }
            norms[w] = sqrtf((float)sum_sq);
        }

        upload_vocab_v2(vocab, norms, vocab_size);

        int8_t query[EMBEDDING_DIM];
        float query_norm_sq = 0;
        for (int d = 0; d < EMBEDDING_DIM; d++) {
            query[d] = (rand() % 3) - 1;
            query_norm_sq += query[d] * query[d];
        }
        float query_norm = sqrtf(query_norm_sq);

        // Warmup
        for (int i = 0; i < 10; i++) {
            memcpy([g_v2.queryBuffers[0] contents], query, EMBEDDING_DIM);
            id<MTLCommandBuffer> cmd = [g_v2.commandQueue commandBuffer];
            id<MTLComputeCommandEncoder> enc = [cmd computeCommandEncoder];
            [enc setComputePipelineState:g_v2.pipeline];
            [enc setBuffer:g_v2.queryBuffers[0] offset:0 atIndex:0];
            [enc setBuffer:g_v2.vocabBuffer offset:0 atIndex:1];
            [enc setBuffer:g_v2.normsBuffer offset:0 atIndex:2];
            [enc setBuffer:g_v2.resultBuffers[0] offset:0 atIndex:3];
            [enc setBytes:&(uint32_t){EMBEDDING_DIM} length:4 atIndex:4];
            [enc setBytes:&vocab_size length:4 atIndex:5];
            [enc setBytes:&query_norm length:4 atIndex:6];
            [enc dispatchThreadgroups:MTLSizeMake(vocab_size, 1, 1)
                threadsPerThreadgroup:MTLSizeMake(THREADS_PER_GROUP, 1, 1)];
            [enc endEncoding];
            [cmd commit];
            [cmd waitUntilCompleted];
        }

        uint64_t start = get_time_ns();
        for (uint32_t i = 0; i < iterations; i++) {
            memcpy([g_v2.queryBuffers[0] contents], query, EMBEDDING_DIM);
            id<MTLCommandBuffer> cmd = [g_v2.commandQueue commandBuffer];
            id<MTLComputeCommandEncoder> enc = [cmd computeCommandEncoder];
            [enc setComputePipelineState:g_v2.pipeline];
            [enc setBuffer:g_v2.queryBuffers[0] offset:0 atIndex:0];
            [enc setBuffer:g_v2.vocabBuffer offset:0 atIndex:1];
            [enc setBuffer:g_v2.normsBuffer offset:0 atIndex:2];
            [enc setBuffer:g_v2.resultBuffers[0] offset:0 atIndex:3];
            [enc setBytes:&(uint32_t){EMBEDDING_DIM} length:4 atIndex:4];
            [enc setBytes:&vocab_size length:4 atIndex:5];
            [enc setBytes:&query_norm length:4 atIndex:6];
            [enc dispatchThreadgroups:MTLSizeMake(vocab_size, 1, 1)
                threadsPerThreadgroup:MTLSizeMake(THREADS_PER_GROUP, 1, 1)];
            [enc endEncoding];
            [cmd commit];
            [cmd waitUntilCompleted];
        }
        uint64_t elapsed = get_time_ns() - start;

        free(vocab);
        free(norms);

        return (double)iterations * 1e9 / (double)elapsed;
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// MAIN
// ═══════════════════════════════════════════════════════════════════════════════

int main(int argc, char** argv) {
    @autoreleasepool {
        printf("\n");
        printf("╔══════════════════════════════════════════════════════════════╗\n");
        printf("║     IGLA METAL v2.0 — ASYNC PIPELINED GPU                    ║\n");
        printf("║     Target: 10,000+ ops/s | Vocab: 100K | Batch: 64          ║\n");
        printf("║     phi^2 + 1/phi^2 = 3 = TRINITY                            ║\n");
        printf("╚══════════════════════════════════════════════════════════════╝\n");

        printf("\n  Initializing Metal v2.0...\n");
        if (init_metal_v2() != 0) {
            printf("  ERROR: Failed to initialize Metal\n");
            return 1;
        }

        uint32_t iterations = 1000;

        // ═══════════════════════════════════════════════════════════════
        // SINGLE-SHOT MODE (V1 COMPARISON)
        // ═══════════════════════════════════════════════════════════════

        printf("\n═══════════════════════════════════════════════════════════════\n");
        printf("     SINGLE-SHOT MODE (V1 STYLE)                               \n");
        printf("═══════════════════════════════════════════════════════════════\n");
        printf("  Vocab Size │ ops/s     │ Status\n");
        printf("  ───────────┼───────────┼────────────\n");

        uint32_t v1_sizes[] = {10000, 25000, 50000, 100000};
        for (int i = 0; i < 4; i++) {
            double ops = run_single_benchmark(v1_sizes[i], iterations);
            const char* status = (ops >= 10000) ? "10K+ ✓" : (ops >= 1000) ? "1K+" : "< 1K";
            printf("  %9u │ %9.0f │ %s\n", v1_sizes[i], ops, status);
        }

        // ═══════════════════════════════════════════════════════════════
        // BATCHED ASYNC MODE (V2)
        // ═══════════════════════════════════════════════════════════════

        printf("\n═══════════════════════════════════════════════════════════════\n");
        printf("     BATCHED ASYNC MODE (V2 — 64 queries/batch)                \n");
        printf("═══════════════════════════════════════════════════════════════\n");
        printf("  Vocab Size │ ops/s     │ Status\n");
        printf("  ───────────┼───────────┼────────────\n");

        uint32_t v2_sizes[] = {10000, 25000, 50000, 100000};
        for (int i = 0; i < 4; i++) {
            double ops = run_batched_benchmark(v2_sizes[i], iterations);
            const char* status = (ops >= 10000) ? "10K+ ✓ TARGET" :
                                 (ops >= 5000) ? "5K+" :
                                 (ops >= 1000) ? "1K+" : "< 1K";
            printf("  %9u │ %9.0f │ %s\n", v2_sizes[i], ops, status);
        }

        // ═══════════════════════════════════════════════════════════════
        // 100K VOCAB FOCUS
        // ═══════════════════════════════════════════════════════════════

        printf("\n═══════════════════════════════════════════════════════════════\n");
        printf("     100K VOCAB BENCHMARK (TARGET SCALE)                       \n");
        printf("═══════════════════════════════════════════════════════════════\n");

        double single_100k = run_single_benchmark(100000, iterations);
        double batch_100k = run_batched_benchmark(100000, iterations);

        printf("  Single-shot: %.0f ops/s\n", single_100k);
        printf("  Batched v2:  %.0f ops/s\n", batch_100k);
        printf("  Improvement: %.1fx\n", batch_100k / single_100k);

        if (batch_100k >= 10000) {
            printf("\n  STATUS: TARGET MET! 10K+ ops/s at 100K vocab\n");
        } else if (batch_100k >= 5000) {
            printf("\n  STATUS: 5K+ ops/s — Close to target\n");
        } else {
            printf("\n  STATUS: Below target (%.0f ops/s)\n", batch_100k);
        }

        printf("\n═══════════════════════════════════════════════════════════════\n");
        printf("phi^2 + 1/phi^2 = 3 = TRINITY | KOSCHEI IS IMMORTAL\n");
        printf("\n");

        return 0;
    }
}
