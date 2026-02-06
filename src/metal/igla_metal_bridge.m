// ═══════════════════════════════════════════════════════════════════════════════
// IGLA METAL BRIDGE — Objective-C Implementation
// ═══════════════════════════════════════════════════════════════════════════════
//
// Metal GPU compute implementation for IGLA Vector Symbolic Architecture.
// Target: 10,000+ ops/s on Apple Silicon
//
// Build: clang -framework Metal -framework Foundation -c igla_metal_bridge.m
//
// phi^2 + 1/phi^2 = 3 = TRINITY | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

#import "igla_metal_bridge.h"

#import <Foundation/Foundation.h>
#import <Metal/Metal.h>
#include <mach/mach_time.h>

// ═══════════════════════════════════════════════════════════════════════════════
// GLOBAL STATE
// ═══════════════════════════════════════════════════════════════════════════════

static struct {
    id<MTLDevice> device;
    id<MTLCommandQueue> commandQueue;
    id<MTLLibrary> library;

    // Compute pipelines
    id<MTLComputePipelineState> batchSimilarityPipeline;
    id<MTLComputePipelineState> bindPipeline;
    id<MTLComputePipelineState> bundle2Pipeline;
    id<MTLComputePipelineState> analogyPipeline;

    // GPU buffers
    id<MTLBuffer> vocabBuffer;
    id<MTLBuffer> normsBuffer;
    id<MTLBuffer> queryBuffer;
    id<MTLBuffer> similaritiesBuffer;

    // State
    bool initialized;
    uint32_t vocabSize;
    uint32_t embeddingDim;
    char deviceName[128];

    // Statistics
    uint64_t totalOps;
    uint64_t totalTimeNs;

} g_metal = {
    .device = nil,
    .commandQueue = nil,
    .library = nil,
    .batchSimilarityPipeline = nil,
    .bindPipeline = nil,
    .bundle2Pipeline = nil,
    .analogyPipeline = nil,
    .vocabBuffer = nil,
    .normsBuffer = nil,
    .queryBuffer = nil,
    .similaritiesBuffer = nil,
    .initialized = false,
    .vocabSize = 0,
    .embeddingDim = IGLA_EMBEDDING_DIM,
    .deviceName = "",
    .totalOps = 0,
    .totalTimeNs = 0,
};

// ═══════════════════════════════════════════════════════════════════════════════
// TIME UTILITIES
// ═══════════════════════════════════════════════════════════════════════════════

static mach_timebase_info_data_t g_timebase;

static inline uint64_t get_time_ns(void) {
    if (g_timebase.denom == 0) {
        mach_timebase_info(&g_timebase);
    }
    return mach_absolute_time() * g_timebase.numer / g_timebase.denom;
}

// ═══════════════════════════════════════════════════════════════════════════════
// INITIALIZATION
// ═══════════════════════════════════════════════════════════════════════════════

int igla_metal_init(void) {
    @autoreleasepool {
        if (g_metal.initialized) {
            return IGLA_SUCCESS;
        }

        // Get default Metal device
        // Try MTLCreateSystemDefaultDevice first
        g_metal.device = MTLCreateSystemDefaultDevice();

        // Fallback: try to get device from all available devices
        if (g_metal.device == nil) {
            NSArray<id<MTLDevice>>* devices = MTLCopyAllDevices();
            if (devices != nil && [devices count] > 0) {
                g_metal.device = devices[0];
            }
        }

        if (g_metal.device == nil) {
            NSLog(@"IGLA Metal: No Metal device found");
            return IGLA_ERROR_NO_DEVICE;
        }

        // Store device name
        strncpy(g_metal.deviceName, [[g_metal.device name] UTF8String], sizeof(g_metal.deviceName) - 1);
        NSLog(@"IGLA Metal: Using device: %s", g_metal.deviceName);

        // Create command queue
        g_metal.commandQueue = [g_metal.device newCommandQueue];
        if (g_metal.commandQueue == nil) {
            return IGLA_ERROR_NO_DEVICE;
        }

        // Load Metal library from source
        NSError* error = nil;
        NSString* shaderPath = [[NSBundle mainBundle] pathForResource:@"igla_vsa" ofType:@"metal"];

        if (shaderPath == nil) {
            // Try loading from file path (development mode)
            shaderPath = @"src/vibeec/metal/igla_vsa.metal";
        }

        NSString* shaderSource = [NSString stringWithContentsOfFile:shaderPath
                                                           encoding:NSUTF8StringEncoding
                                                              error:&error];

        if (shaderSource == nil) {
            // Fallback: use embedded shader source
            shaderSource = @""
            "#include <metal_stdlib>\n"
            "using namespace metal;\n"
            "#define THREADS_PER_GROUP 256\n"
            "\n"
            "kernel void kernel_vsa_batch_similarity(\n"
            "    device const char*  query       [[buffer(0)]],\n"
            "    device const char*  vocab_matrix[[buffer(1)]],\n"
            "    device const float* vocab_norms [[buffer(2)]],\n"
            "    device       float* similarities[[buffer(3)]],\n"
            "    constant  uint32_t& dim         [[buffer(4)]],\n"
            "    constant  uint32_t& vocab_size  [[buffer(5)]],\n"
            "    constant    float& query_norm   [[buffer(6)]],\n"
            "    uint word_idx [[threadgroup_position_in_grid]],\n"
            "    uint tid      [[thread_position_in_threadgroup]],\n"
            "    uint tg_size  [[threads_per_threadgroup]]\n"
            ") {\n"
            "    if (word_idx >= vocab_size) return;\n"
            "    threadgroup int partial_sums[THREADS_PER_GROUP];\n"
            "    device const char* word_vec = vocab_matrix + word_idx * dim;\n"
            "    int sum = 0;\n"
            "    for (uint i = tid; i < dim; i += tg_size) {\n"
            "        sum += (int)query[i] * (int)word_vec[i];\n"
            "    }\n"
            "    partial_sums[tid] = sum;\n"
            "    threadgroup_barrier(mem_flags::mem_threadgroup);\n"
            "    for (uint stride = tg_size / 2; stride > 0; stride /= 2) {\n"
            "        if (tid < stride) partial_sums[tid] += partial_sums[tid + stride];\n"
            "        threadgroup_barrier(mem_flags::mem_threadgroup);\n"
            "    }\n"
            "    if (tid == 0) {\n"
            "        float dot = (float)partial_sums[0];\n"
            "        float denom = query_norm * vocab_norms[word_idx];\n"
            "        similarities[word_idx] = (denom > 0.0001f) ? (dot / denom) : 0.0f;\n"
            "    }\n"
            "}\n"
            "\n"
            "kernel void kernel_vsa_bind(\n"
            "    device const char* a [[buffer(0)]],\n"
            "    device const char* b [[buffer(1)]],\n"
            "    device       char* result [[buffer(2)]],\n"
            "    constant uint32_t& dim [[buffer(3)]],\n"
            "    uint tid [[thread_position_in_grid]]\n"
            ") {\n"
            "    if (tid < dim) result[tid] = a[tid] * b[tid];\n"
            "}\n"
            "\n"
            "kernel void kernel_vsa_bundle2(\n"
            "    device const char* a [[buffer(0)]],\n"
            "    device const char* b [[buffer(1)]],\n"
            "    device       char* result [[buffer(2)]],\n"
            "    constant uint32_t& dim [[buffer(3)]],\n"
            "    uint tid [[thread_position_in_grid]]\n"
            ") {\n"
            "    if (tid < dim) {\n"
            "        int sum = (int)a[tid] + (int)b[tid];\n"
            "        result[tid] = (sum > 0) ? 1 : ((sum < 0) ? -1 : 0);\n"
            "    }\n"
            "}\n"
            "\n"
            "kernel void kernel_vsa_analogy(\n"
            "    device const char* a [[buffer(0)]],\n"
            "    device const char* b [[buffer(1)]],\n"
            "    device const char* c [[buffer(2)]],\n"
            "    device       char* result [[buffer(3)]],\n"
            "    constant uint32_t& dim [[buffer(4)]],\n"
            "    uint tid [[thread_position_in_grid]]\n"
            ") {\n"
            "    if (tid < dim) {\n"
            "        int sum = (int)b[tid] - (int)a[tid] + (int)c[tid];\n"
            "        result[tid] = (sum > 0) ? 1 : ((sum < 0) ? -1 : 0);\n"
            "    }\n"
            "}\n";
        }

        MTLCompileOptions* options = [[MTLCompileOptions alloc] init];
        options.fastMathEnabled = YES;

        g_metal.library = [g_metal.device newLibraryWithSource:shaderSource
                                                       options:options
                                                         error:&error];
        if (g_metal.library == nil) {
            NSLog(@"IGLA Metal: Failed to compile shaders: %@", error);
            return IGLA_ERROR_NO_LIBRARY;
        }

        // Create compute pipelines
        id<MTLFunction> batchSimFunc = [g_metal.library newFunctionWithName:@"kernel_vsa_batch_similarity"];
        id<MTLFunction> bindFunc = [g_metal.library newFunctionWithName:@"kernel_vsa_bind"];
        id<MTLFunction> bundle2Func = [g_metal.library newFunctionWithName:@"kernel_vsa_bundle2"];
        id<MTLFunction> analogyFunc = [g_metal.library newFunctionWithName:@"kernel_vsa_analogy"];

        if (batchSimFunc == nil) {
            NSLog(@"IGLA Metal: kernel_vsa_batch_similarity not found");
            return IGLA_ERROR_NO_FUNCTION;
        }

        g_metal.batchSimilarityPipeline = [g_metal.device newComputePipelineStateWithFunction:batchSimFunc error:&error];
        if (g_metal.batchSimilarityPipeline == nil) {
            NSLog(@"IGLA Metal: Failed to create batch similarity pipeline: %@", error);
            return IGLA_ERROR_NO_PIPELINE;
        }

        if (bindFunc) {
            g_metal.bindPipeline = [g_metal.device newComputePipelineStateWithFunction:bindFunc error:nil];
        }
        if (bundle2Func) {
            g_metal.bundle2Pipeline = [g_metal.device newComputePipelineStateWithFunction:bundle2Func error:nil];
        }
        if (analogyFunc) {
            g_metal.analogyPipeline = [g_metal.device newComputePipelineStateWithFunction:analogyFunc error:nil];
        }

        // Pre-allocate query buffer
        g_metal.queryBuffer = [g_metal.device newBufferWithLength:IGLA_EMBEDDING_DIM * sizeof(int8_t)
                                                          options:MTLResourceStorageModeShared];

        g_metal.initialized = true;
        NSLog(@"IGLA Metal: Initialized successfully on %s", g_metal.deviceName);

        return IGLA_SUCCESS;
    }
}

bool igla_metal_is_available(void) {
    return g_metal.initialized;
}

const char* igla_metal_device_name(void) {
    return g_metal.deviceName;
}

void igla_metal_deinit(void) {
    @autoreleasepool {
        g_metal.batchSimilarityPipeline = nil;
        g_metal.bindPipeline = nil;
        g_metal.bundle2Pipeline = nil;
        g_metal.analogyPipeline = nil;
        g_metal.vocabBuffer = nil;
        g_metal.normsBuffer = nil;
        g_metal.queryBuffer = nil;
        g_metal.similaritiesBuffer = nil;
        g_metal.library = nil;
        g_metal.commandQueue = nil;
        g_metal.device = nil;
        g_metal.initialized = false;
        g_metal.vocabSize = 0;
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// BUFFER MANAGEMENT
// ═══════════════════════════════════════════════════════════════════════════════

int igla_metal_upload_vocab(
    const int8_t* vocab_matrix,
    const float* vocab_norms,
    uint32_t vocab_size,
    uint32_t dim
) {
    @autoreleasepool {
        if (!g_metal.initialized) {
            return IGLA_ERROR_NOT_INITIALIZED;
        }

        size_t matrix_size = (size_t)vocab_size * dim * sizeof(int8_t);
        size_t norms_size = (size_t)vocab_size * sizeof(float);

        // Create/update vocab buffer
        g_metal.vocabBuffer = [g_metal.device newBufferWithBytes:vocab_matrix
                                                          length:matrix_size
                                                         options:MTLResourceStorageModeShared];
        if (g_metal.vocabBuffer == nil) {
            return IGLA_ERROR_BUFFER_CREATE;
        }

        // Create/update norms buffer
        g_metal.normsBuffer = [g_metal.device newBufferWithBytes:vocab_norms
                                                          length:norms_size
                                                         options:MTLResourceStorageModeShared];
        if (g_metal.normsBuffer == nil) {
            return IGLA_ERROR_BUFFER_CREATE;
        }

        // Create similarities output buffer
        g_metal.similaritiesBuffer = [g_metal.device newBufferWithLength:norms_size
                                                                 options:MTLResourceStorageModeShared];
        if (g_metal.similaritiesBuffer == nil) {
            return IGLA_ERROR_BUFFER_CREATE;
        }

        g_metal.vocabSize = vocab_size;
        g_metal.embeddingDim = dim;

        return IGLA_SUCCESS;
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// BATCH SIMILARITY — THE 10K+ OPS/S KERNEL
// ═══════════════════════════════════════════════════════════════════════════════

// Pre-created command buffer for low-latency execution
static id<MTLCommandBuffer> g_commandBuffer = nil;
static id<MTLComputeCommandEncoder> g_encoder = nil;
static bool g_encoderActive = false;

int igla_metal_batch_similarity(
    const int8_t* query,
    float query_norm,
    float* similarities
) {
    @autoreleasepool {
        if (!g_metal.initialized) {
            return IGLA_ERROR_NOT_INITIALIZED;
        }

        uint64_t start_time = get_time_ns();

        // Copy query to GPU buffer (shared memory - no actual copy)
        memcpy([g_metal.queryBuffer contents], query, g_metal.embeddingDim * sizeof(int8_t));

        // Create command buffer (reuse pattern)
        id<MTLCommandBuffer> commandBuffer = [g_metal.commandQueue commandBuffer];
        if (commandBuffer == nil) {
            return IGLA_ERROR_COMMAND_BUFFER;
        }

        // Use blit encoder to ensure data is visible to GPU
        id<MTLBlitCommandEncoder> blit = [commandBuffer blitCommandEncoder];
        [blit synchronizeResource:g_metal.queryBuffer];
        [blit endEncoding];

        // Create compute encoder
        id<MTLComputeCommandEncoder> encoder = [commandBuffer computeCommandEncoder];
        [encoder setComputePipelineState:g_metal.batchSimilarityPipeline];

        // Set buffers
        [encoder setBuffer:g_metal.queryBuffer offset:0 atIndex:0];
        [encoder setBuffer:g_metal.vocabBuffer offset:0 atIndex:1];
        [encoder setBuffer:g_metal.normsBuffer offset:0 atIndex:2];
        [encoder setBuffer:g_metal.similaritiesBuffer offset:0 atIndex:3];
        [encoder setBytes:&g_metal.embeddingDim length:sizeof(uint32_t) atIndex:4];
        [encoder setBytes:&g_metal.vocabSize length:sizeof(uint32_t) atIndex:5];
        [encoder setBytes:&query_norm length:sizeof(float) atIndex:6];

        // Dispatch: one threadgroup per word, THREADS_PER_GROUP threads per group
        MTLSize threadgroupSize = MTLSizeMake(IGLA_THREADS_PER_GROUP, 1, 1);
        MTLSize numThreadgroups = MTLSizeMake(g_metal.vocabSize, 1, 1);

        [encoder dispatchThreadgroups:numThreadgroups threadsPerThreadgroup:threadgroupSize];
        [encoder endEncoding];

        // Execute and wait
        [commandBuffer commit];
        [commandBuffer waitUntilCompleted];

        // Copy results back (shared memory - direct access)
        memcpy(similarities, [g_metal.similaritiesBuffer contents], g_metal.vocabSize * sizeof(float));

        // Update statistics
        uint64_t elapsed = get_time_ns() - start_time;
        g_metal.totalOps++;
        g_metal.totalTimeNs += elapsed;

        return IGLA_SUCCESS;
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// BATCH N QUERIES — Amortize command buffer overhead
// ═══════════════════════════════════════════════════════════════════════════════

int igla_metal_batch_similarity_n(
    const int8_t** queries,      // Array of N query pointers
    const float* query_norms,    // Array of N norms
    float** similarities,        // Array of N output pointers
    uint32_t n                   // Number of queries
) {
    @autoreleasepool {
        if (!g_metal.initialized) {
            return IGLA_ERROR_NOT_INITIALIZED;
        }

        // Create single command buffer for all N queries
        id<MTLCommandBuffer> commandBuffer = [g_metal.commandQueue commandBuffer];
        if (commandBuffer == nil) {
            return IGLA_ERROR_COMMAND_BUFFER;
        }

        // Process each query
        for (uint32_t q = 0; q < n; q++) {
            // Update query buffer
            memcpy([g_metal.queryBuffer contents], queries[q], g_metal.embeddingDim * sizeof(int8_t));

            // Sync query buffer
            id<MTLBlitCommandEncoder> blit = [commandBuffer blitCommandEncoder];
            [blit synchronizeResource:g_metal.queryBuffer];
            [blit endEncoding];

            // Compute
            id<MTLComputeCommandEncoder> encoder = [commandBuffer computeCommandEncoder];
            [encoder setComputePipelineState:g_metal.batchSimilarityPipeline];
            [encoder setBuffer:g_metal.queryBuffer offset:0 atIndex:0];
            [encoder setBuffer:g_metal.vocabBuffer offset:0 atIndex:1];
            [encoder setBuffer:g_metal.normsBuffer offset:0 atIndex:2];
            [encoder setBuffer:g_metal.similaritiesBuffer offset:0 atIndex:3];
            [encoder setBytes:&g_metal.embeddingDim length:sizeof(uint32_t) atIndex:4];
            [encoder setBytes:&g_metal.vocabSize length:sizeof(uint32_t) atIndex:5];
            [encoder setBytes:&query_norms[q] length:sizeof(float) atIndex:6];

            MTLSize threadgroupSize = MTLSizeMake(IGLA_THREADS_PER_GROUP, 1, 1);
            MTLSize numThreadgroups = MTLSizeMake(g_metal.vocabSize, 1, 1);
            [encoder dispatchThreadgroups:numThreadgroups threadsPerThreadgroup:threadgroupSize];
            [encoder endEncoding];
        }

        // Execute all at once
        [commandBuffer commit];
        [commandBuffer waitUntilCompleted];

        // Copy results
        for (uint32_t q = 0; q < n; q++) {
            memcpy(similarities[q], [g_metal.similaritiesBuffer contents], g_metal.vocabSize * sizeof(float));
        }

        g_metal.totalOps += n;

        return IGLA_SUCCESS;
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// BIND OPERATION
// ═══════════════════════════════════════════════════════════════════════════════

int igla_metal_bind(
    const int8_t* a,
    const int8_t* b,
    int8_t* result,
    uint32_t dim
) {
    @autoreleasepool {
        if (!g_metal.initialized || g_metal.bindPipeline == nil) {
            return IGLA_ERROR_NOT_INITIALIZED;
        }

        id<MTLBuffer> bufferA = [g_metal.device newBufferWithBytes:a length:dim options:MTLResourceStorageModeShared];
        id<MTLBuffer> bufferB = [g_metal.device newBufferWithBytes:b length:dim options:MTLResourceStorageModeShared];
        id<MTLBuffer> bufferResult = [g_metal.device newBufferWithLength:dim options:MTLResourceStorageModeShared];

        id<MTLCommandBuffer> commandBuffer = [g_metal.commandQueue commandBuffer];
        id<MTLComputeCommandEncoder> encoder = [commandBuffer computeCommandEncoder];

        [encoder setComputePipelineState:g_metal.bindPipeline];
        [encoder setBuffer:bufferA offset:0 atIndex:0];
        [encoder setBuffer:bufferB offset:0 atIndex:1];
        [encoder setBuffer:bufferResult offset:0 atIndex:2];
        [encoder setBytes:&dim length:sizeof(uint32_t) atIndex:3];

        MTLSize gridSize = MTLSizeMake(dim, 1, 1);
        MTLSize threadgroupSize = MTLSizeMake(MIN(dim, (uint32_t)g_metal.bindPipeline.maxTotalThreadsPerThreadgroup), 1, 1);

        [encoder dispatchThreads:gridSize threadsPerThreadgroup:threadgroupSize];
        [encoder endEncoding];

        [commandBuffer commit];
        [commandBuffer waitUntilCompleted];

        memcpy(result, [bufferResult contents], dim);

        return IGLA_SUCCESS;
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// BUNDLE2 OPERATION
// ═══════════════════════════════════════════════════════════════════════════════

int igla_metal_bundle2(
    const int8_t* a,
    const int8_t* b,
    int8_t* result,
    uint32_t dim
) {
    @autoreleasepool {
        if (!g_metal.initialized || g_metal.bundle2Pipeline == nil) {
            return IGLA_ERROR_NOT_INITIALIZED;
        }

        id<MTLBuffer> bufferA = [g_metal.device newBufferWithBytes:a length:dim options:MTLResourceStorageModeShared];
        id<MTLBuffer> bufferB = [g_metal.device newBufferWithBytes:b length:dim options:MTLResourceStorageModeShared];
        id<MTLBuffer> bufferResult = [g_metal.device newBufferWithLength:dim options:MTLResourceStorageModeShared];

        id<MTLCommandBuffer> commandBuffer = [g_metal.commandQueue commandBuffer];
        id<MTLComputeCommandEncoder> encoder = [commandBuffer computeCommandEncoder];

        [encoder setComputePipelineState:g_metal.bundle2Pipeline];
        [encoder setBuffer:bufferA offset:0 atIndex:0];
        [encoder setBuffer:bufferB offset:0 atIndex:1];
        [encoder setBuffer:bufferResult offset:0 atIndex:2];
        [encoder setBytes:&dim length:sizeof(uint32_t) atIndex:3];

        MTLSize gridSize = MTLSizeMake(dim, 1, 1);
        MTLSize threadgroupSize = MTLSizeMake(MIN(dim, (uint32_t)g_metal.bundle2Pipeline.maxTotalThreadsPerThreadgroup), 1, 1);

        [encoder dispatchThreads:gridSize threadsPerThreadgroup:threadgroupSize];
        [encoder endEncoding];

        [commandBuffer commit];
        [commandBuffer waitUntilCompleted];

        memcpy(result, [bufferResult contents], dim);

        return IGLA_SUCCESS;
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ANALOGY OPERATION
// ═══════════════════════════════════════════════════════════════════════════════

int igla_metal_analogy(
    const int8_t* a,
    const int8_t* b,
    const int8_t* c,
    int8_t* result,
    uint32_t dim
) {
    @autoreleasepool {
        if (!g_metal.initialized || g_metal.analogyPipeline == nil) {
            return IGLA_ERROR_NOT_INITIALIZED;
        }

        id<MTLBuffer> bufferA = [g_metal.device newBufferWithBytes:a length:dim options:MTLResourceStorageModeShared];
        id<MTLBuffer> bufferB = [g_metal.device newBufferWithBytes:b length:dim options:MTLResourceStorageModeShared];
        id<MTLBuffer> bufferC = [g_metal.device newBufferWithBytes:c length:dim options:MTLResourceStorageModeShared];
        id<MTLBuffer> bufferResult = [g_metal.device newBufferWithLength:dim options:MTLResourceStorageModeShared];

        id<MTLCommandBuffer> commandBuffer = [g_metal.commandQueue commandBuffer];
        id<MTLComputeCommandEncoder> encoder = [commandBuffer computeCommandEncoder];

        [encoder setComputePipelineState:g_metal.analogyPipeline];
        [encoder setBuffer:bufferA offset:0 atIndex:0];
        [encoder setBuffer:bufferB offset:0 atIndex:1];
        [encoder setBuffer:bufferC offset:0 atIndex:2];
        [encoder setBuffer:bufferResult offset:0 atIndex:3];
        [encoder setBytes:&dim length:sizeof(uint32_t) atIndex:4];

        MTLSize gridSize = MTLSizeMake(dim, 1, 1);
        MTLSize threadgroupSize = MTLSizeMake(MIN(dim, (uint32_t)g_metal.analogyPipeline.maxTotalThreadsPerThreadgroup), 1, 1);

        [encoder dispatchThreads:gridSize threadsPerThreadgroup:threadgroupSize];
        [encoder endEncoding];

        [commandBuffer commit];
        [commandBuffer waitUntilCompleted];

        memcpy(result, [bufferResult contents], dim);

        return IGLA_SUCCESS;
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// STATISTICS
// ═══════════════════════════════════════════════════════════════════════════════

IglaMetalStats igla_metal_get_stats(void) {
    IglaMetalStats stats = {0};

    stats.total_ops = g_metal.totalOps;
    stats.total_time_ns = g_metal.totalTimeNs;
    stats.vocab_size = g_metal.vocabSize;
    stats.embedding_dim = g_metal.embeddingDim;
    stats.gpu_available = g_metal.initialized;
    stats.device_name = g_metal.deviceName;

    if (g_metal.totalTimeNs > 0) {
        stats.ops_per_sec = (double)g_metal.totalOps * 1e9 / (double)g_metal.totalTimeNs;
        stats.elements_per_sec = stats.ops_per_sec * g_metal.vocabSize * g_metal.embeddingDim;
    }

    return stats;
}

void igla_metal_reset_stats(void) {
    g_metal.totalOps = 0;
    g_metal.totalTimeNs = 0;
}

// ═══════════════════════════════════════════════════════════════════════════════
// BENCHMARK
// ═══════════════════════════════════════════════════════════════════════════════

// Optimized benchmark using batched command buffer execution
double igla_metal_benchmark(uint32_t vocab_size, uint32_t iterations) {
    @autoreleasepool {
        if (!g_metal.initialized) {
            if (igla_metal_init() != IGLA_SUCCESS) {
                return 0.0;
            }
        }

        // Create synthetic vocabulary
        size_t matrix_size = (size_t)vocab_size * IGLA_EMBEDDING_DIM;
        int8_t* vocab_matrix = (int8_t*)malloc(matrix_size);
        float* vocab_norms = (float*)malloc(vocab_size * sizeof(float));
        float* similarities = (float*)malloc(vocab_size * sizeof(float));

        // Initialize with random ternary values
        srand(12345);
        for (size_t i = 0; i < matrix_size; i++) {
            int r = rand() % 3;
            vocab_matrix[i] = (r == 0) ? -1 : ((r == 1) ? 0 : 1);
        }

        // Compute norms
        for (uint32_t w = 0; w < vocab_size; w++) {
            int sum_sq = 0;
            for (uint32_t d = 0; d < IGLA_EMBEDDING_DIM; d++) {
                int v = vocab_matrix[w * IGLA_EMBEDDING_DIM + d];
                sum_sq += v * v;
            }
            vocab_norms[w] = sqrtf((float)sum_sq);
        }

        // Create multiple queries
        int8_t queries[8][IGLA_EMBEDDING_DIM];
        float query_norms[8];
        for (int q = 0; q < 8; q++) {
            float norm_sq = 0;
            for (uint32_t d = 0; d < IGLA_EMBEDDING_DIM; d++) {
                int r = rand() % 3;
                queries[q][d] = (r == 0) ? -1 : ((r == 1) ? 0 : 1);
                norm_sq += queries[q][d] * queries[q][d];
            }
            query_norms[q] = sqrtf(norm_sq);
        }

        // Upload vocabulary
        igla_metal_upload_vocab(vocab_matrix, vocab_norms, vocab_size, IGLA_EMBEDDING_DIM);

        // Warmup - run a few iterations
        for (int i = 0; i < 10; i++) {
            igla_metal_batch_similarity(queries[0], query_norms[0], similarities);
        }

        // OPTIMIZED BENCHMARK: Batch multiple queries in single command buffer
        uint32_t batch_size = 16;  // Queries per command buffer
        uint32_t num_batches = (iterations + batch_size - 1) / batch_size;

        uint64_t start = get_time_ns();

        for (uint32_t b = 0; b < num_batches; b++) {
            // Create single command buffer for batch
            id<MTLCommandBuffer> commandBuffer = [g_metal.commandQueue commandBuffer];

            // Encode all queries in batch
            uint32_t batch_count = MIN(batch_size, iterations - b * batch_size);
            for (uint32_t q = 0; q < batch_count; q++) {
                int query_idx = (b * batch_size + q) % 8;

                // Copy query
                memcpy([g_metal.queryBuffer contents], queries[query_idx], IGLA_EMBEDDING_DIM);

                // Encode compute
                id<MTLComputeCommandEncoder> encoder = [commandBuffer computeCommandEncoder];
                [encoder setComputePipelineState:g_metal.batchSimilarityPipeline];
                [encoder setBuffer:g_metal.queryBuffer offset:0 atIndex:0];
                [encoder setBuffer:g_metal.vocabBuffer offset:0 atIndex:1];
                [encoder setBuffer:g_metal.normsBuffer offset:0 atIndex:2];
                [encoder setBuffer:g_metal.similaritiesBuffer offset:0 atIndex:3];
                [encoder setBytes:&g_metal.embeddingDim length:sizeof(uint32_t) atIndex:4];
                [encoder setBytes:&g_metal.vocabSize length:sizeof(uint32_t) atIndex:5];
                [encoder setBytes:&query_norms[query_idx] length:sizeof(float) atIndex:6];

                MTLSize threadgroupSize = MTLSizeMake(IGLA_THREADS_PER_GROUP, 1, 1);
                MTLSize numThreadgroups = MTLSizeMake(g_metal.vocabSize, 1, 1);
                [encoder dispatchThreadgroups:numThreadgroups threadsPerThreadgroup:threadgroupSize];
                [encoder endEncoding];
            }

            // Execute batch
            [commandBuffer commit];
            [commandBuffer waitUntilCompleted];
        }

        uint64_t elapsed = get_time_ns() - start;
        double ops_per_sec = (double)iterations * 1e9 / (double)elapsed;

        free(vocab_matrix);
        free(vocab_norms);
        free(similarities);

        return ops_per_sec;
    }
}
