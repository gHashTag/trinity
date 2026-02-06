// ═══════════════════════════════════════════════════════════════════════════════
// IGLA METAL v2.0 MULTI-QUERY — Single Kernel for N Queries
// ═══════════════════════════════════════════════════════════════════════════════
//
// Key optimization: Process MULTIPLE queries in SINGLE kernel dispatch
// Instead of: 1 kernel per query (high overhead)
// Now: 1 kernel for N queries (amortized overhead)
//
// Grid: [vocab_size × num_queries] threads
// Each threadgroup computes similarity for ONE (word, query) pair
//
// phi^2 + 1/phi^2 = 3 = TRINITY | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#include <mach/mach_time.h>
#include <stdio.h>
#include <stdlib.h>

#define EMBEDDING_DIM 300
#define MAX_VOCAB 100000
#define THREADS_PER_GROUP 256
#define QUERIES_PER_BATCH 128   // Process 128 queries per dispatch

static id<MTLDevice> g_device = nil;
static id<MTLCommandQueue> g_queue = nil;
static id<MTLComputePipelineState> g_multiPipeline = nil;
static id<MTLBuffer> g_vocabBuffer = nil;
static id<MTLBuffer> g_normsBuffer = nil;
static id<MTLBuffer> g_queriesBuffer = nil;
static id<MTLBuffer> g_queryNormsBuffer = nil;
static id<MTLBuffer> g_resultsBuffer = nil;
static uint32_t g_vocabSize = 0;

static mach_timebase_info_data_t g_tb;
static inline uint64_t get_ns(void) {
    if (g_tb.denom == 0) mach_timebase_info(&g_tb);
    return mach_absolute_time() * g_tb.numer / g_tb.denom;
}

static int init_multi(void) {
    @autoreleasepool {
        NSArray<id<MTLDevice>>* devices = MTLCopyAllDevices();
        g_device = (devices && [devices count] > 0) ? devices[0] : MTLCreateSystemDefaultDevice();
        if (!g_device) return -1;

        g_queue = [g_device newCommandQueue];

        // Multi-query kernel: Process (word_idx, query_idx) pairs
        // Use thread_position_in_grid to get 2D position
        NSString* shader = @""
        "#include <metal_stdlib>\n"
        "using namespace metal;\n"
        "\n"
        "// Multi-query batch similarity kernel\n"
        "// Grid: [vocab_size × num_queries] total threads\n"
        "// Each thread handles ONE (word, query) pair\n"
        "kernel void multi_query_similarity(\n"
        "    device const char*  queries      [[buffer(0)]],\n"
        "    device const float* query_norms  [[buffer(1)]],\n"
        "    device const char*  vocab        [[buffer(2)]],\n"
        "    device const float* vocab_norms  [[buffer(3)]],\n"
        "    device       float* results      [[buffer(4)]],\n"
        "    constant  uint32_t& dim          [[buffer(5)]],\n"
        "    constant  uint32_t& vocab_size   [[buffer(6)]],\n"
        "    constant  uint32_t& num_queries  [[buffer(7)]],\n"
        "    uint gid [[thread_position_in_grid]]\n"
        ") {\n"
        "    // Decode 1D thread position to (word, query) pair\n"
        "    uint word_idx = gid % vocab_size;\n"
        "    uint query_idx = gid / vocab_size;\n"
        "    if (query_idx >= num_queries) return;\n"
        "\n"
        "    device const char* word = vocab + word_idx * dim;\n"
        "    device const char* query = queries + query_idx * dim;\n"
        "\n"
        "    // Direct dot product (no reduction needed, single thread per pair)\n"
        "    int sum = 0;\n"
        "    for (uint i = 0; i < dim; i++) {\n"
        "        sum += (int)query[i] * (int)word[i];\n"
        "    }\n"
        "\n"
        "    float d = query_norms[query_idx] * vocab_norms[word_idx];\n"
        "    results[query_idx * vocab_size + word_idx] = (d > 0.0001f) ? ((float)sum / d) : 0.0f;\n"
        "}\n";

        NSError* err = nil;
        MTLCompileOptions* opts = [[MTLCompileOptions alloc] init];
        opts.fastMathEnabled = YES;

        id<MTLLibrary> lib = [g_device newLibraryWithSource:shader options:opts error:&err];
        if (!lib) {
            fprintf(stderr, "Shader error: %s\n", [[err description] UTF8String]);
            return -2;
        }

        id<MTLFunction> func = [lib newFunctionWithName:@"multi_query_similarity"];
        g_multiPipeline = [g_device newComputePipelineStateWithFunction:func error:&err];
        if (!g_multiPipeline) return -3;

        // Pre-allocate buffers
        g_queriesBuffer = [g_device newBufferWithLength:QUERIES_PER_BATCH * EMBEDDING_DIM options:MTLResourceStorageModeShared];
        g_queryNormsBuffer = [g_device newBufferWithLength:QUERIES_PER_BATCH * sizeof(float) options:MTLResourceStorageModeShared];
        g_resultsBuffer = [g_device newBufferWithLength:QUERIES_PER_BATCH * MAX_VOCAB * sizeof(float) options:MTLResourceStorageModeShared];

        printf("  Device: %s\n", [[g_device name] UTF8String]);
        return 0;
    }
}

static void upload_vocab(const int8_t* matrix, const float* norms, uint32_t size) {
    @autoreleasepool {
        g_vocabBuffer = [g_device newBufferWithBytes:matrix length:(size_t)size * EMBEDDING_DIM options:MTLResourceStorageModeShared];
        g_normsBuffer = [g_device newBufferWithBytes:norms length:(size_t)size * sizeof(float) options:MTLResourceStorageModeShared];
        g_vocabSize = size;
    }
}

// Run multi-query batch
static double run_multi_benchmark(uint32_t vocab_size, uint32_t total_queries) {
    @autoreleasepool {
        // Create vocab
        size_t matrix_size = (size_t)vocab_size * EMBEDDING_DIM;
        int8_t* vocab = (int8_t*)malloc(matrix_size);
        float* norms = (float*)malloc(vocab_size * sizeof(float));

        srand(12345);
        for (size_t i = 0; i < matrix_size; i++) vocab[i] = (rand() % 3) - 1;
        for (uint32_t w = 0; w < vocab_size; w++) {
            int sum_sq = 0;
            for (uint32_t d = 0; d < EMBEDDING_DIM; d++) {
                int v = vocab[w * EMBEDDING_DIM + d];
                sum_sq += v * v;
            }
            norms[w] = sqrtf((float)sum_sq);
        }
        upload_vocab(vocab, norms, vocab_size);

        // Create queries
        int8_t* queries = (int8_t*)malloc(QUERIES_PER_BATCH * EMBEDDING_DIM);
        float* query_norms = (float*)malloc(QUERIES_PER_BATCH * sizeof(float));
        for (int q = 0; q < QUERIES_PER_BATCH; q++) {
            float ns = 0;
            for (int d = 0; d < EMBEDDING_DIM; d++) {
                queries[q * EMBEDDING_DIM + d] = (rand() % 3) - 1;
                ns += queries[q * EMBEDDING_DIM + d] * queries[q * EMBEDDING_DIM + d];
            }
            query_norms[q] = sqrtf(ns);
        }

        // Upload queries to GPU
        memcpy([g_queriesBuffer contents], queries, QUERIES_PER_BATCH * EMBEDDING_DIM);
        memcpy([g_queryNormsBuffer contents], query_norms, QUERIES_PER_BATCH * sizeof(float));

        // Get optimal threadgroup size
        NSUInteger maxThreads = g_multiPipeline.maxTotalThreadsPerThreadgroup;
        NSUInteger tgSize = MIN(maxThreads, 256);

        // Warmup
        for (int i = 0; i < 5; i++) {
            id<MTLCommandBuffer> cmd = [g_queue commandBuffer];
            id<MTLComputeCommandEncoder> enc = [cmd computeCommandEncoder];
            [enc setComputePipelineState:g_multiPipeline];
            [enc setBuffer:g_queriesBuffer offset:0 atIndex:0];
            [enc setBuffer:g_queryNormsBuffer offset:0 atIndex:1];
            [enc setBuffer:g_vocabBuffer offset:0 atIndex:2];
            [enc setBuffer:g_normsBuffer offset:0 atIndex:3];
            [enc setBuffer:g_resultsBuffer offset:0 atIndex:4];
            [enc setBytes:&(uint32_t){EMBEDDING_DIM} length:4 atIndex:5];
            [enc setBytes:&vocab_size length:4 atIndex:6];
            [enc setBytes:&(uint32_t){QUERIES_PER_BATCH} length:4 atIndex:7];

            // Total threads = vocab_size × num_queries
            NSUInteger totalThreads = (NSUInteger)vocab_size * QUERIES_PER_BATCH;
            MTLSize grid = MTLSizeMake(totalThreads, 1, 1);
            MTLSize tg = MTLSizeMake(tgSize, 1, 1);
            [enc dispatchThreads:grid threadsPerThreadgroup:tg];
            [enc endEncoding];
            [cmd commit];
            [cmd waitUntilCompleted];
        }

        // Benchmark
        uint32_t num_batches = (total_queries + QUERIES_PER_BATCH - 1) / QUERIES_PER_BATCH;
        uint64_t start = get_ns();

        for (uint32_t b = 0; b < num_batches; b++) {
            uint32_t batch_queries = (b == num_batches - 1) ?
                                     (total_queries - b * QUERIES_PER_BATCH) : QUERIES_PER_BATCH;

            id<MTLCommandBuffer> cmd = [g_queue commandBuffer];
            id<MTLComputeCommandEncoder> enc = [cmd computeCommandEncoder];
            [enc setComputePipelineState:g_multiPipeline];
            [enc setBuffer:g_queriesBuffer offset:0 atIndex:0];
            [enc setBuffer:g_queryNormsBuffer offset:0 atIndex:1];
            [enc setBuffer:g_vocabBuffer offset:0 atIndex:2];
            [enc setBuffer:g_normsBuffer offset:0 atIndex:3];
            [enc setBuffer:g_resultsBuffer offset:0 atIndex:4];
            [enc setBytes:&(uint32_t){EMBEDDING_DIM} length:4 atIndex:5];
            [enc setBytes:&vocab_size length:4 atIndex:6];
            [enc setBytes:&batch_queries length:4 atIndex:7];

            NSUInteger totalThreads = (NSUInteger)vocab_size * batch_queries;
            MTLSize grid = MTLSizeMake(totalThreads, 1, 1);
            MTLSize tg = MTLSizeMake(tgSize, 1, 1);
            [enc dispatchThreads:grid threadsPerThreadgroup:tg];
            [enc endEncoding];
            [cmd commit];
            [cmd waitUntilCompleted];
        }

        uint64_t elapsed = get_ns() - start;
        double ops = (double)total_queries * 1e9 / (double)elapsed;

        free(vocab);
        free(norms);
        free(queries);
        free(query_norms);

        return ops;
    }
}

int main(int argc, char** argv) {
    @autoreleasepool {
        printf("\n");
        printf("╔══════════════════════════════════════════════════════════════╗\n");
        printf("║     IGLA METAL v2.0 MULTI-QUERY KERNEL                       ║\n");
        printf("║     Single dispatch for %d queries                          ║\n", QUERIES_PER_BATCH);
        printf("║     phi^2 + 1/phi^2 = 3 = TRINITY                            ║\n");
        printf("╚══════════════════════════════════════════════════════════════╝\n");

        printf("\n  Initializing...\n");
        if (init_multi() != 0) {
            printf("  ERROR: Init failed\n");
            return 1;
        }

        uint32_t iterations = 1024;  // Multiple of 128 for clean batching

        printf("\n═══════════════════════════════════════════════════════════════\n");
        printf("     MULTI-QUERY BENCHMARK (%d queries/dispatch)              \n", QUERIES_PER_BATCH);
        printf("═══════════════════════════════════════════════════════════════\n");
        printf("  Vocab Size │ ops/s     │ Throughput      │ Status\n");
        printf("  ───────────┼───────────┼─────────────────┼────────────\n");

        uint32_t sizes[] = {5000, 10000, 25000, 50000, 100000};
        for (int i = 0; i < 5; i++) {
            double ops = run_multi_benchmark(sizes[i], iterations);
            double throughput = ops * sizes[i] * EMBEDDING_DIM / 1e9;
            const char* status = (ops >= 10000) ? "10K+ ✓ TARGET" :
                                 (ops >= 5000) ? "5K+" :
                                 (ops >= 1000) ? "1K+" : "< 1K";
            printf("  %9u │ %9.0f │ %.1f G elem/s │ %s\n", sizes[i], ops, throughput, status);
        }

        printf("\n═══════════════════════════════════════════════════════════════\n");
        printf("     100K VOCAB DETAIL                                         \n");
        printf("═══════════════════════════════════════════════════════════════\n");

        double ops_100k = run_multi_benchmark(100000, iterations);
        printf("  Vocab: 100,000\n");
        printf("  Queries per dispatch: %d\n", QUERIES_PER_BATCH);
        printf("  Speed: %.0f ops/s\n", ops_100k);
        printf("  Throughput: %.1f G elem/s\n", ops_100k * 100000 * 300 / 1e9);

        if (ops_100k >= 10000) {
            printf("\n  STATUS: TARGET MET! 10K+ ops/s at 100K vocab\n");
        } else if (ops_100k >= 5000) {
            printf("\n  STATUS: 5K+ ops/s — close to target\n");
        } else {
            printf("\n  STATUS: %.0f ops/s (need optimization)\n", ops_100k);
        }

        printf("\n═══════════════════════════════════════════════════════════════\n");
        printf("phi^2 + 1/phi^2 = 3 = TRINITY | KOSCHEI IS IMMORTAL\n\n");

        return 0;
    }
}
