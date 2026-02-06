// ═══════════════════════════════════════════════════════════════════════════════
// IGLA METAL COMPUTE SHADERS - VSA Operations for Apple Silicon
// ═══════════════════════════════════════════════════════════════════════════════
//
// Optimized for M1/M2/M3 Pro/Max GPU architecture
// Threadgroup size: 256 (optimal for Apple Silicon)
//
// phi^2 + 1/phi^2 = 3 = TRINITY | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

#include <metal_stdlib>
using namespace metal;

// ═══════════════════════════════════════════════════════════════════════════════
// CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

constant uint EMBEDDING_DIM = 300;
constant uint THREADGROUP_SIZE = 256;

// ═══════════════════════════════════════════════════════════════════════════════
// DOT PRODUCT KERNEL - Batch similarity computation
// ═══════════════════════════════════════════════════════════════════════════════
//
// Computes dot product between query and each vocabulary vector
// Each thread handles one vocabulary vector
//
// Input:
//   query: [300] int8 - query ternary vector
//   vocab: [vocab_size][300] int8 - vocabulary ternary vectors
//   norms: [vocab_size] float - precomputed L2 norms
//   query_norm: float - query vector norm
//
// Output:
//   similarities: [vocab_size] float - cosine similarities

kernel void kernel_dot_product_batch(
    device const int8_t* query [[buffer(0)]],
    device const int8_t* vocab [[buffer(1)]],
    device const float* norms [[buffer(2)]],
    device float* similarities [[buffer(3)]],
    constant float& query_norm [[buffer(4)]],
    constant uint& vocab_size [[buffer(5)]],
    uint gid [[thread_position_in_grid]],
    uint tid [[thread_position_in_threadgroup]],
    threadgroup int* shared_query [[threadgroup(0)]]
) {
    // Load query to shared memory (cooperative loading)
    for (uint i = tid; i < EMBEDDING_DIM; i += THREADGROUP_SIZE) {
        shared_query[i] = query[i];
    }
    threadgroup_barrier(mem_flags::mem_threadgroup);

    if (gid >= vocab_size) return;

    // Compute dot product for this vocabulary vector
    int dot = 0;
    device const int8_t* vec = vocab + gid * EMBEDDING_DIM;

    // Unrolled loop for better performance (300 = 75 * 4)
    for (uint i = 0; i < EMBEDDING_DIM; i += 4) {
        dot += shared_query[i] * vec[i];
        dot += shared_query[i+1] * vec[i+1];
        dot += shared_query[i+2] * vec[i+2];
        dot += shared_query[i+3] * vec[i+3];
    }

    // Compute cosine similarity
    float denom = query_norm * norms[gid];
    if (denom < 0.0001f) {
        similarities[gid] = 0.0f;
    } else {
        similarities[gid] = float(dot) / denom;
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// BIND KERNEL - Element-wise multiplication
// ═══════════════════════════════════════════════════════════════════════════════
//
// Computes element-wise product of two ternary vectors
// Result is clamped to [-1, 0, 1]

kernel void kernel_bind(
    device const int8_t* a [[buffer(0)]],
    device const int8_t* b [[buffer(1)]],
    device int8_t* result [[buffer(2)]],
    uint gid [[thread_position_in_grid]]
) {
    if (gid >= EMBEDDING_DIM) return;

    int8_t prod = a[gid] * b[gid];
    // Clamp to ternary (already correct for ternary inputs)
    result[gid] = prod;
}

// ═══════════════════════════════════════════════════════════════════════════════
// BUNDLE KERNEL - Majority vote
// ═══════════════════════════════════════════════════════════════════════════════
//
// Computes element-wise sum and applies sign function
// Handles tie-breaking for zero sums

kernel void kernel_bundle(
    device const int8_t* vectors [[buffer(0)]],
    device int8_t* result [[buffer(1)]],
    constant uint& num_vectors [[buffer(2)]],
    uint gid [[thread_position_in_grid]]
) {
    if (gid >= EMBEDDING_DIM) return;

    int sum = 0;
    for (uint v = 0; v < num_vectors; v++) {
        sum += vectors[v * EMBEDDING_DIM + gid];
    }

    // Majority vote with sign function
    if (sum > 0) {
        result[gid] = 1;
    } else if (sum < 0) {
        result[gid] = -1;
    } else {
        result[gid] = 0;  // Tie goes to zero
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ANALOGY KERNEL - Compute b - a + c query vector
// ═══════════════════════════════════════════════════════════════════════════════
//
// For analogy "a is to b as c is to ?"
// Query = vec(b) - vec(a) + vec(c)

kernel void kernel_analogy_query(
    device const int8_t* vec_a [[buffer(0)]],
    device const int8_t* vec_b [[buffer(1)]],
    device const int8_t* vec_c [[buffer(2)]],
    device int8_t* query [[buffer(3)]],
    uint gid [[thread_position_in_grid]]
) {
    if (gid >= EMBEDDING_DIM) return;

    int sum = int(vec_b[gid]) - int(vec_a[gid]) + int(vec_c[gid]);

    // Clamp to ternary
    if (sum > 0) {
        query[gid] = 1;
    } else if (sum < 0) {
        query[gid] = -1;
    } else {
        query[gid] = 0;
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TOP-K SELECTION KERNEL (Parallel reduction)
// ═══════════════════════════════════════════════════════════════════════════════
//
// Uses parallel reduction to find top-K maximum values
// Each threadgroup finds local maxima, then atomic update global

struct TopKItem {
    uint idx;
    float similarity;
};

kernel void kernel_find_max(
    device const float* similarities [[buffer(0)]],
    device atomic_uint* max_indices [[buffer(1)]],
    device float* max_values [[buffer(2)]],
    constant uint& vocab_size [[buffer(3)]],
    constant uint& k [[buffer(4)]],
    uint gid [[thread_position_in_grid]],
    uint tid [[thread_position_in_threadgroup]],
    uint tg_size [[threads_per_threadgroup]],
    threadgroup float* shared_max [[threadgroup(0)]],
    threadgroup uint* shared_idx [[threadgroup(1)]]
) {
    // Initialize shared memory
    shared_max[tid] = -1.0f;
    shared_idx[tid] = 0;

    // Load local maximum
    if (gid < vocab_size) {
        shared_max[tid] = similarities[gid];
        shared_idx[tid] = gid;
    }

    threadgroup_barrier(mem_flags::mem_threadgroup);

    // Parallel reduction to find maximum in threadgroup
    for (uint stride = tg_size / 2; stride > 0; stride /= 2) {
        if (tid < stride) {
            if (shared_max[tid + stride] > shared_max[tid]) {
                shared_max[tid] = shared_max[tid + stride];
                shared_idx[tid] = shared_idx[tid + stride];
            }
        }
        threadgroup_barrier(mem_flags::mem_threadgroup);
    }

    // Thread 0 writes result
    if (tid == 0 && shared_max[0] > -1.0f) {
        // Atomic update to global top-K (simplified - full implementation needs proper sorting)
        for (uint i = 0; i < k; i++) {
            if (shared_max[0] > max_values[i]) {
                // Shift down and insert
                for (uint j = k - 1; j > i; j--) {
                    max_values[j] = max_values[j-1];
                    atomic_store_explicit(&max_indices[j],
                        atomic_load_explicit(&max_indices[j-1], memory_order_relaxed),
                        memory_order_relaxed);
                }
                max_values[i] = shared_max[0];
                atomic_store_explicit(&max_indices[i], shared_idx[0], memory_order_relaxed);
                break;
            }
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// QUANTIZATION KERNEL - Float to Ternary
// ═══════════════════════════════════════════════════════════════════════════════
//
// Adaptive threshold quantization: mean-based

kernel void kernel_quantize_adaptive(
    device const float* floats [[buffer(0)]],
    device int8_t* trits [[buffer(1)]],
    constant float& threshold [[buffer(2)]],
    uint gid [[thread_position_in_grid]]
) {
    if (gid >= EMBEDDING_DIM) return;

    float val = floats[gid];

    if (val > threshold) {
        trits[gid] = 1;
    } else if (val < -threshold) {
        trits[gid] = -1;
    } else {
        trits[gid] = 0;
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// NORM COMPUTATION KERNEL
// ═══════════════════════════════════════════════════════════════════════════════

kernel void kernel_compute_norm(
    device const int8_t* vec [[buffer(0)]],
    device float* norm [[buffer(1)]],
    uint tid [[thread_position_in_threadgroup]],
    threadgroup int* partial_sums [[threadgroup(0)]]
) {
    // Each thread handles multiple elements
    int local_sum = 0;
    for (uint i = tid; i < EMBEDDING_DIM; i += THREADGROUP_SIZE) {
        int v = vec[i];
        local_sum += v * v;
    }

    partial_sums[tid] = local_sum;
    threadgroup_barrier(mem_flags::mem_threadgroup);

    // Reduction
    for (uint stride = THREADGROUP_SIZE / 2; stride > 0; stride /= 2) {
        if (tid < stride) {
            partial_sums[tid] += partial_sums[tid + stride];
        }
        threadgroup_barrier(mem_flags::mem_threadgroup);
    }

    if (tid == 0) {
        *norm = sqrt(float(partial_sums[0]));
    }
}
