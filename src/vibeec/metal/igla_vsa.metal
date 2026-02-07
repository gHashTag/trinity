// ═══════════════════════════════════════════════════════════════════════════════
// IGLA VSA METAL COMPUTE SHADERS v1.0
// ═══════════════════════════════════════════════════════════════════════════════
//
// High-performance Metal compute kernels for Vector Symbolic Architecture.
// Target: 10,000+ ops/s on M1 Pro GPU (16 cores, 2.6 TFLOPS)
//
// Operations:
// - bind: Element-wise multiply (association)
// - bundle: Majority voting (superposition)
// - dot_product: Parallel reduction
// - batch_similarity: All 50K vectors in parallel
//
// Memory: Ternary vectors {-1, 0, +1} stored as int8 (char)
//
// phi^2 + 1/phi^2 = 3 = TRINITY | KOSCHEI IS IMMORTAL
// ═══════════════════════════════════════════════════════════════════════════════

#include <metal_stdlib>
using namespace metal;

// ═══════════════════════════════════════════════════════════════════════════════
// CONSTANTS
// ═══════════════════════════════════════════════════════════════════════════════

#define SIMD_WIDTH 32          // M1 Pro SIMD group size
#define EMBEDDING_DIM 300      // GloVe/VSA dimension
#define MAX_VOCAB 50000        // Maximum vocabulary size
#define THREADS_PER_GROUP 256  // Optimal for M1 Pro

// ═══════════════════════════════════════════════════════════════════════════════
// BIND KERNEL - Element-wise Ternary Multiplication
// ═══════════════════════════════════════════════════════════════════════════════
//
// bind(a, b)[i] = a[i] * b[i]
// Used for: Association, unbinding, relation encoding
//
// Dispatch: (EMBEDDING_DIM / THREADS_PER_GROUP) threadgroups x 1 x 1

kernel void kernel_vsa_bind(
    device const char* a      [[buffer(0)]],  // Input vector A [DIM]
    device const char* b      [[buffer(1)]],  // Input vector B [DIM]
    device       char* result [[buffer(2)]],  // Output [DIM]
    constant  uint32_t& dim   [[buffer(3)]],  // Dimension
    uint tid [[thread_position_in_grid]]
) {
    if (tid < dim) {
        result[tid] = a[tid] * b[tid];
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// BUNDLE KERNEL - Majority Voting (2 vectors)
// ═══════════════════════════════════════════════════════════════════════════════
//
// bundle(a, b)[i] = sign(a[i] + b[i]) with 0 → 0
// Used for: Superposition, memory formation

kernel void kernel_vsa_bundle2(
    device const char* a      [[buffer(0)]],
    device const char* b      [[buffer(1)]],
    device       char* result [[buffer(2)]],
    constant  uint32_t& dim   [[buffer(3)]],
    uint tid [[thread_position_in_grid]]
) {
    if (tid < dim) {
        int sum = (int)a[tid] + (int)b[tid];
        result[tid] = (sum > 0) ? 1 : ((sum < 0) ? -1 : 0);
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// BUNDLE3 KERNEL - Majority Voting (3 vectors)
// ═══════════════════════════════════════════════════════════════════════════════

kernel void kernel_vsa_bundle3(
    device const char* a      [[buffer(0)]],
    device const char* b      [[buffer(1)]],
    device const char* c      [[buffer(2)]],
    device       char* result [[buffer(3)]],
    constant  uint32_t& dim   [[buffer(4)]],
    uint tid [[thread_position_in_grid]]
) {
    if (tid < dim) {
        int sum = (int)a[tid] + (int)b[tid] + (int)c[tid];
        result[tid] = (sum > 0) ? 1 : ((sum < 0) ? -1 : 0);
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// DOT PRODUCT KERNEL - Parallel Reduction
// ═══════════════════════════════════════════════════════════════════════════════
//
// dot(a, b) = sum(a[i] * b[i])
// Uses SIMD reduction for efficiency
//
// Dispatch: 1 threadgroup with THREADS_PER_GROUP threads

kernel void kernel_vsa_dot(
    device const char* a       [[buffer(0)]],
    device const char* b       [[buffer(1)]],
    device       int*  result  [[buffer(2)]],  // Single output
    constant  uint32_t& dim    [[buffer(3)]],
    uint tid  [[thread_position_in_threadgroup]],
    uint tgid [[threadgroup_position_in_grid]],
    uint tg_size [[threads_per_threadgroup]]
) {
    threadgroup int partial_sums[THREADS_PER_GROUP];

    int sum = 0;
    // Each thread processes multiple elements
    for (uint i = tid; i < dim; i += tg_size) {
        sum += (int)a[i] * (int)b[i];
    }
    partial_sums[tid] = sum;

    threadgroup_barrier(mem_flags::mem_threadgroup);

    // Parallel reduction in threadgroup
    for (uint stride = tg_size / 2; stride > 0; stride /= 2) {
        if (tid < stride) {
            partial_sums[tid] += partial_sums[tid + stride];
        }
        threadgroup_barrier(mem_flags::mem_threadgroup);
    }

    if (tid == 0) {
        result[tgid] = partial_sums[0];
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// BATCH DOT PRODUCT - Query against entire vocabulary
// ═══════════════════════════════════════════════════════════════════════════════
//
// For each word w in vocabulary:
//   dots[w] = dot(query, vocab[w])
//
// This is THE critical kernel for 10K+ ops/s
// Dispatch: (vocab_size) threadgroups x 1 x 1, each with DIM/SIMD_WIDTH threads

kernel void kernel_vsa_batch_dot(
    device const char*  query       [[buffer(0)]],  // Query vector [DIM]
    device const char*  vocab_matrix[[buffer(1)]],  // Vocab [VOCAB_SIZE x DIM]
    device       int*   dot_results [[buffer(2)]],  // Output [VOCAB_SIZE]
    constant  uint32_t& dim         [[buffer(3)]],
    constant  uint32_t& vocab_size  [[buffer(4)]],
    uint word_idx [[threadgroup_position_in_grid]],
    uint tid      [[thread_position_in_threadgroup]],
    uint tg_size  [[threads_per_threadgroup]]
) {
    if (word_idx >= vocab_size) return;

    threadgroup int partial_sums[THREADS_PER_GROUP];

    // Pointer to this word's vector
    device const char* word_vec = vocab_matrix + word_idx * dim;

    int sum = 0;
    // Each thread handles multiple dimensions
    for (uint i = tid; i < dim; i += tg_size) {
        sum += (int)query[i] * (int)word_vec[i];
    }
    partial_sums[tid] = sum;

    threadgroup_barrier(mem_flags::mem_threadgroup);

    // Parallel reduction
    for (uint stride = tg_size / 2; stride > 0; stride /= 2) {
        if (tid < stride) {
            partial_sums[tid] += partial_sums[tid + stride];
        }
        threadgroup_barrier(mem_flags::mem_threadgroup);
    }

    if (tid == 0) {
        dot_results[word_idx] = partial_sums[0];
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// BATCH SIMILARITY - Compute cosine similarity for all vocabulary
// ═══════════════════════════════════════════════════════════════════════════════
//
// sim[w] = dot(query, vocab[w]) / (query_norm * vocab_norm[w])
//
// Dispatch: (vocab_size) threadgroups

kernel void kernel_vsa_batch_similarity(
    device const char*  query       [[buffer(0)]],  // Query vector [DIM]
    device const char*  vocab_matrix[[buffer(1)]],  // Vocab [VOCAB_SIZE x DIM]
    device const float* vocab_norms [[buffer(2)]],  // Precomputed norms [VOCAB_SIZE]
    device       float* similarities[[buffer(3)]],  // Output [VOCAB_SIZE]
    constant  uint32_t& dim         [[buffer(4)]],
    constant  uint32_t& vocab_size  [[buffer(5)]],
    constant    float& query_norm   [[buffer(6)]],
    uint word_idx [[threadgroup_position_in_grid]],
    uint tid      [[thread_position_in_threadgroup]],
    uint tg_size  [[threads_per_threadgroup]]
) {
    if (word_idx >= vocab_size) return;

    threadgroup int partial_sums[THREADS_PER_GROUP];

    device const char* word_vec = vocab_matrix + word_idx * dim;

    int sum = 0;
    for (uint i = tid; i < dim; i += tg_size) {
        sum += (int)query[i] * (int)word_vec[i];
    }
    partial_sums[tid] = sum;

    threadgroup_barrier(mem_flags::mem_threadgroup);

    for (uint stride = tg_size / 2; stride > 0; stride /= 2) {
        if (tid < stride) {
            partial_sums[tid] += partial_sums[tid + stride];
        }
        threadgroup_barrier(mem_flags::mem_threadgroup);
    }

    if (tid == 0) {
        float dot = (float)partial_sums[0];
        float denom = query_norm * vocab_norms[word_idx];
        similarities[word_idx] = (denom > 0.0001f) ? (dot / denom) : 0.0f;
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ANALOGY KERNEL - Compute b - a + c in parallel
// ═══════════════════════════════════════════════════════════════════════════════
//
// result[i] = sign(b[i] - a[i] + c[i])
// For "a is to b as c is to ?"

kernel void kernel_vsa_analogy(
    device const char* a      [[buffer(0)]],  // Source concept
    device const char* b      [[buffer(1)]],  // Target concept
    device const char* c      [[buffer(2)]],  // Query concept
    device       char* result [[buffer(3)]],  // Analogy vector
    constant  uint32_t& dim   [[buffer(4)]],
    uint tid [[thread_position_in_grid]]
) {
    if (tid < dim) {
        int sum = (int)b[tid] - (int)a[tid] + (int)c[tid];
        result[tid] = (sum > 0) ? 1 : ((sum < 0) ? -1 : 0);
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// TOP-K REDUCTION - Find top K similarities (parallel partial sort)
// ═══════════════════════════════════════════════════════════════════════════════
//
// Each threadgroup finds its local top-K, then merge on CPU
// This avoids atomic contention

struct IndexedSimilarity {
    uint32_t index;
    float similarity;
};

kernel void kernel_vsa_topk_partial(
    device const float* similarities [[buffer(0)]],  // All similarities [VOCAB_SIZE]
    device IndexedSimilarity* partial_topk [[buffer(1)]],  // [NUM_GROUPS x K]
    constant  uint32_t& vocab_size   [[buffer(2)]],
    constant  uint32_t& k            [[buffer(3)]],  // Top K
    uint tgid    [[threadgroup_position_in_grid]],
    uint tid     [[thread_position_in_threadgroup]],
    uint tg_size [[threads_per_threadgroup]],
    uint num_tgs [[threadgroups_per_grid]]
) {
    // Each threadgroup processes vocab_size/num_tgs elements
    uint chunk_size = (vocab_size + num_tgs - 1) / num_tgs;
    uint start = tgid * chunk_size;
    uint end = min(start + chunk_size, vocab_size);

    // Thread-local top-K (simple insertion sort for small K)
    threadgroup IndexedSimilarity local_topk[32];  // Assuming K <= 32
    threadgroup uint local_count;

    if (tid == 0) {
        local_count = 0;
        for (uint i = 0; i < k; i++) {
            local_topk[i].index = 0;
            local_topk[i].similarity = -1e9f;
        }
    }
    threadgroup_barrier(mem_flags::mem_threadgroup);

    // Each thread scans portion
    for (uint i = start + tid; i < end; i += tg_size) {
        float sim = similarities[i];

        // Check if this could be in top-K (compare with minimum in heap)
        if (sim > local_topk[0].similarity) {
            // Atomic insert into sorted array (simplified)
            // In practice, use atomic_compare_exchange
            for (uint j = 0; j < k; j++) {
                if (sim > local_topk[j].similarity) {
                    // Shift down
                    for (uint m = 0; m < j; m++) {
                        local_topk[m] = local_topk[m + 1];
                    }
                    local_topk[j].index = i;
                    local_topk[j].similarity = sim;
                    break;
                }
            }
        }
    }

    threadgroup_barrier(mem_flags::mem_threadgroup);

    // Thread 0 writes results
    if (tid == 0) {
        for (uint i = 0; i < k; i++) {
            partial_topk[tgid * k + i] = local_topk[i];
        }
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// PERMUTE KERNEL - Cyclic shift for sequence encoding
// ═══════════════════════════════════════════════════════════════════════════════

kernel void kernel_vsa_permute(
    device const char* input  [[buffer(0)]],
    device       char* output [[buffer(1)]],
    constant  uint32_t& dim   [[buffer(2)]],
    constant  uint32_t& shift [[buffer(3)]],  // Shift amount
    uint tid [[thread_position_in_grid]]
) {
    if (tid < dim) {
        uint src_idx = (tid + dim - (shift % dim)) % dim;
        output[tid] = input[src_idx];
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// NORM KERNEL - Compute L2 norm of vector
// ═══════════════════════════════════════════════════════════════════════════════

kernel void kernel_vsa_norm(
    device const char* vec    [[buffer(0)]],
    device      float* result [[buffer(1)]],  // Single float output
    constant uint32_t& dim    [[buffer(2)]],
    uint tid      [[thread_position_in_threadgroup]],
    uint tg_size  [[threads_per_threadgroup]]
) {
    threadgroup int partial_sums[THREADS_PER_GROUP];

    int sum = 0;
    for (uint i = tid; i < dim; i += tg_size) {
        int v = (int)vec[i];
        sum += v * v;  // For ternary: v*v is 0 or 1
    }
    partial_sums[tid] = sum;

    threadgroup_barrier(mem_flags::mem_threadgroup);

    for (uint stride = tg_size / 2; stride > 0; stride /= 2) {
        if (tid < stride) {
            partial_sums[tid] += partial_sums[tid + stride];
        }
        threadgroup_barrier(mem_flags::mem_threadgroup);
    }

    if (tid == 0) {
        result[0] = sqrt((float)partial_sums[0]);
    }
}

// ═══════════════════════════════════════════════════════════════════════════════
// BATCH NORMS - Compute norms for entire vocabulary at once
// ═══════════════════════════════════════════════════════════════════════════════

kernel void kernel_vsa_batch_norms(
    device const char*  vocab_matrix [[buffer(0)]],
    device      float*  norms        [[buffer(1)]],
    constant uint32_t&  dim          [[buffer(2)]],
    constant uint32_t&  vocab_size   [[buffer(3)]],
    uint word_idx [[threadgroup_position_in_grid]],
    uint tid      [[thread_position_in_threadgroup]],
    uint tg_size  [[threads_per_threadgroup]]
) {
    if (word_idx >= vocab_size) return;

    threadgroup int partial_sums[THREADS_PER_GROUP];

    device const char* word_vec = vocab_matrix + word_idx * dim;

    int sum = 0;
    for (uint i = tid; i < dim; i += tg_size) {
        int v = (int)word_vec[i];
        sum += v * v;
    }
    partial_sums[tid] = sum;

    threadgroup_barrier(mem_flags::mem_threadgroup);

    for (uint stride = tg_size / 2; stride > 0; stride /= 2) {
        if (tid < stride) {
            partial_sums[tid] += partial_sums[tid + stride];
        }
        threadgroup_barrier(mem_flags::mem_threadgroup);
    }

    if (tid == 0) {
        norms[word_idx] = sqrt((float)partial_sums[0]);
    }
}
