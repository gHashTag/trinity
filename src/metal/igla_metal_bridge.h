// ═══════════════════════════════════════════════════════════════════════════════
// IGLA METAL BRIDGE — C Interface for Zig Integration
// ═══════════════════════════════════════════════════════════════════════════════
//
// Provides C-compatible interface to Metal GPU compute for Vector Symbolic Architecture.
// Target: 10,000+ ops/s on Apple Silicon (M1/M2/M3 Pro/Max)
//
// Usage from Zig:
//   extern fn igla_metal_init() c_int;
//   extern fn igla_metal_batch_similarity(...) c_int;
//   extern fn igla_metal_deinit() void;
//
// phi^2 + 1/phi^2 = 3 = TRINITY | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

#ifndef IGLA_METAL_BRIDGE_H
#define IGLA_METAL_BRIDGE_H

#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

// ═══════════════════════════════════════════════════════════════════════════════
// CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

#define IGLA_EMBEDDING_DIM 300
#define IGLA_MAX_VOCAB 50000
#define IGLA_THREADS_PER_GROUP 256

// ═══════════════════════════════════════════════════════════════════════════════
// ERROR CODES
// ═══════════════════════════════════════════════════════════════════════════════

typedef enum {
    IGLA_SUCCESS = 0,
    IGLA_ERROR_NO_DEVICE = -1,
    IGLA_ERROR_NO_LIBRARY = -2,
    IGLA_ERROR_NO_FUNCTION = -3,
    IGLA_ERROR_NO_PIPELINE = -4,
    IGLA_ERROR_BUFFER_CREATE = -5,
    IGLA_ERROR_COMMAND_BUFFER = -6,
    IGLA_ERROR_NOT_INITIALIZED = -7,
} IglaMetalError;

// ═══════════════════════════════════════════════════════════════════════════════
// STATISTICS
// ═══════════════════════════════════════════════════════════════════════════════

typedef struct {
    uint64_t total_ops;
    uint64_t total_time_ns;
    double ops_per_sec;
    double elements_per_sec;
    uint32_t vocab_size;
    uint32_t embedding_dim;
    bool gpu_available;
    const char* device_name;
} IglaMetalStats;

// ═══════════════════════════════════════════════════════════════════════════════
// INITIALIZATION / CLEANUP
// ═══════════════════════════════════════════════════════════════════════════════

/// Initialize Metal device, load shaders, create pipelines
/// Returns: IGLA_SUCCESS (0) on success, negative error code on failure
int igla_metal_init(void);

/// Check if Metal is available and initialized
bool igla_metal_is_available(void);

/// Get device name (e.g., "Apple M1 Pro")
const char* igla_metal_device_name(void);

/// Cleanup and release all resources
void igla_metal_deinit(void);

// ═══════════════════════════════════════════════════════════════════════════════
// BUFFER MANAGEMENT
// ═══════════════════════════════════════════════════════════════════════════════

/// Upload vocabulary matrix to GPU
/// vocab_matrix: [vocab_size * dim] int8 array (row-major)
/// vocab_norms: [vocab_size] float array
/// Returns: IGLA_SUCCESS on success
int igla_metal_upload_vocab(
    const int8_t* vocab_matrix,
    const float* vocab_norms,
    uint32_t vocab_size,
    uint32_t dim
);

// ═══════════════════════════════════════════════════════════════════════════════
// CORE VSA OPERATIONS
// ═══════════════════════════════════════════════════════════════════════════════

/// Compute cosine similarity of query against entire vocabulary
/// query: [dim] int8 array
/// query_norm: L2 norm of query
/// similarities: [vocab_size] float output array (must be pre-allocated)
/// Returns: IGLA_SUCCESS on success
int igla_metal_batch_similarity(
    const int8_t* query,
    float query_norm,
    float* similarities
);

/// Bind two vectors (element-wise multiply)
/// a, b: [dim] int8 input arrays
/// result: [dim] int8 output array
int igla_metal_bind(
    const int8_t* a,
    const int8_t* b,
    int8_t* result,
    uint32_t dim
);

/// Bundle two vectors (majority vote)
int igla_metal_bundle2(
    const int8_t* a,
    const int8_t* b,
    int8_t* result,
    uint32_t dim
);

/// Compute analogy vector: b - a + c
int igla_metal_analogy(
    const int8_t* a,
    const int8_t* b,
    const int8_t* c,
    int8_t* result,
    uint32_t dim
);

// ═══════════════════════════════════════════════════════════════════════════════
// PERFORMANCE STATISTICS
// ═══════════════════════════════════════════════════════════════════════════════

/// Get performance statistics
IglaMetalStats igla_metal_get_stats(void);

/// Reset performance counters
void igla_metal_reset_stats(void);

// ═══════════════════════════════════════════════════════════════════════════════
// BENCHMARK
// ═══════════════════════════════════════════════════════════════════════════════

/// Run benchmark with specified parameters
/// Returns ops/s achieved
double igla_metal_benchmark(
    uint32_t vocab_size,
    uint32_t iterations
);

#ifdef __cplusplus
}
#endif

#endif // IGLA_METAL_BRIDGE_H
