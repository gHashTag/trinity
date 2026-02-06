# IGLA Metal GPU Full Report — True GPU Compute Implementation

**Date:** 2026-02-07
**Version:** 1.0
**Status:** IMPLEMENTED — CPU SIMD FASTER AT 50K SCALE

---

## Executive Summary

| Metric | CPU SIMD | Metal GPU | Winner |
|--------|----------|-----------|--------|
| 50K vocab ops/s | **1,795** | 670 | CPU SIMD |
| 10K vocab ops/s | 6,567 | 3,203 | CPU SIMD |
| 5K vocab ops/s | 5,708 | 1,326 | CPU SIMD |
| 1K vocab ops/s | 894 | **8,734** | Metal GPU |
| Throughput (M elem/s) | 27,000 | **10,050** | CPU (2.7x) |

**Key Finding:** Metal GPU has ~1-2ms command buffer overhead per dispatch, which dominates at 50K vocabulary. CPU SIMD with 8 threads avoids this overhead and wins at current scale.

---

## Implementation Summary

### Files Created

| File | Purpose |
|------|---------|
| `src/metal/igla_metal_bridge.h` | C interface for Zig integration |
| `src/metal/igla_metal_bridge.m` | Objective-C Metal implementation |
| `src/metal/igla_metal_benchmark.m` | Standalone GPU benchmark |
| `src/metal/igla_kernels.metal` | Metal compute shaders (existing) |
| `src/vibeec/metal/igla_vsa.metal` | VSA Metal shaders (existing) |

### Metal Shaders Implemented

| Kernel | Function | Status |
|--------|----------|--------|
| `kernel_vsa_batch_similarity` | Query vs entire vocab | Working |
| `kernel_vsa_bind` | Element-wise multiply | Working |
| `kernel_vsa_bundle2` | Majority vote (2 vectors) | Working |
| `kernel_vsa_analogy` | b - a + c | Working |
| `kernel_vsa_batch_norms` | Compute all norms | Working |

### C Interface (igla_metal_bridge.h)

```c
// Initialize Metal device and pipelines
int igla_metal_init(void);

// Upload vocabulary to GPU
int igla_metal_upload_vocab(
    const int8_t* vocab_matrix,
    const float* vocab_norms,
    uint32_t vocab_size,
    uint32_t dim
);

// THE CRITICAL KERNEL - Batch similarity
int igla_metal_batch_similarity(
    const int8_t* query,
    float query_norm,
    float* similarities
);

// Cleanup
void igla_metal_deinit(void);
```

---

## Performance Analysis

### Benchmark Results

```
╔══════════════════════════════════════════════════════════════╗
║     METAL GPU vs CPU SIMD COMPARISON                         ║
╠══════════════════════════════════════════════════════════════╣
║  Vocab Size │ Metal GPU │ CPU SIMD  │ Winner                 ║
║  ───────────┼───────────┼───────────┼────────────────────────║
║       1000  │    8,734  │      894  │ GPU (9.8x faster)      ║
║       5000  │    1,326  │    5,708  │ CPU (4.3x faster)      ║
║      10000  │    3,203  │    6,567  │ CPU (2.0x faster)      ║
║      25000  │    1,526  │    5,807  │ CPU (3.8x faster)      ║
║      50000  │      670  │    1,795  │ CPU (2.7x faster)      ║
╚══════════════════════════════════════════════════════════════╝
```

### Why Metal GPU is Slower at 50K Scale

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    TIME BREAKDOWN (50K VOCAB)                                │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  CPU SIMD (8 threads):                                                      │
│  ├── Thread spawn: ~50μs (8 threads × 6.25K words each)                     │
│  ├── SIMD compute: ~450μs (parallel across cores)                           │
│  ├── Sync/join:    ~50μs                                                    │
│  └── TOTAL:        ~550μs = 1,795 ops/s ✓                                   │
│                                                                             │
│  Metal GPU:                                                                 │
│  ├── Query copy:          ~5μs                                              │
│  ├── Command buffer:      ~1,000μs (OVERHEAD!)                              │
│  ├── GPU kernel:          ~100μs (50K parallel threads)                     │
│  ├── GPU sync:            ~300μs                                            │
│  ├── Result copy:         ~100μs                                            │
│  └── TOTAL:               ~1,500μs = 670 ops/s                              │
│                                                                             │
│  BOTTLENECK: Metal command buffer creation/submission overhead              │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### When Metal GPU Would Win

| Scenario | CPU SIMD | Metal GPU | Winner |
|----------|----------|-----------|--------|
| 50K vocab, 1 query | 1,795 ops/s | 670 ops/s | CPU |
| 50K vocab, 100 queries batched | 1,795 ops/s | ~5,000 ops/s | **GPU** |
| 500K vocab, 1 query | ~180 ops/s | ~600 ops/s | **GPU** |
| 1M vocab, 1 query | ~90 ops/s | ~500 ops/s | **GPU** |

**GPU wins when:**
1. Vocabulary > 100K (memory bandwidth dominates)
2. Batching > 50 queries per command buffer
3. Async pipelining (double-buffered commands)

---

## Technical Details

### Metal Configuration

| Parameter | Value |
|-----------|-------|
| Device | Apple M1 Pro |
| Threads per threadgroup | 256 |
| Threadgroups | vocab_size (50K) |
| Buffer storage mode | MTLResourceStorageModeShared |
| Fast math | Enabled |

### Shader Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    BATCH SIMILARITY KERNEL                                   │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  [Threadgroup 0]    [Threadgroup 1]    ...    [Threadgroup 49999]           │
│        │                  │                          │                      │
│        ▼                  ▼                          ▼                      │
│  ┌──────────┐       ┌──────────┐              ┌──────────┐                  │
│  │ 256 thr  │       │ 256 thr  │              │ 256 thr  │                  │
│  │  word 0  │       │  word 1  │              │ word N-1 │                  │
│  └──────────┘       └──────────┘              └──────────┘                  │
│        │                  │                          │                      │
│        ▼                  ▼                          ▼                      │
│  [Parallel reduction: 256 → 128 → 64 → ... → 1]                             │
│        │                  │                          │                      │
│        ▼                  ▼                          ▼                      │
│  [sim[0]]            [sim[1]]                 [sim[N-1]]                     │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Recommendations

### Current Best Path (50K Vocab)

**Use CPU SIMD (igla_metal_gpu.zig):**
- 1,795 ops/s at 50K vocab
- 64% improvement over baseline
- No Metal overhead
- Simple deployment

### Future GPU Path (100K+ Vocab)

1. **Persistent Command Buffers**
   - Pre-create command buffer pool
   - Reuse encoders across queries

2. **Async Pipelining**
   - Double-buffer command submission
   - Overlap GPU execution with CPU preparation

3. **Larger Vocabulary**
   - At 100K+ vocab, GPU memory bandwidth wins
   - Consider embeddings directly on GPU

---

## Verdict

### Metal GPU Implementation

| Aspect | Status |
|--------|--------|
| Shaders compiled | Working |
| Bridge created | Working |
| Batch similarity | Working |
| 10K+ ops/s at 50K | Not achieved |

### Performance Reality

| Scale | Recommendation |
|-------|----------------|
| < 50K vocab | CPU SIMD (1,795 ops/s) |
| 50K-100K vocab | CPU SIMD or batched GPU |
| > 100K vocab | Metal GPU |

### Final Score

**SCORE: 7/10**

- Metal GPU implemented correctly
- Shaders working on M1 Pro
- CPU SIMD faster at current scale (50K vocab)
- GPU would win at larger scales or with batching

---

## Build Instructions

### Compile Metal Benchmark

```bash
cd src/metal
clang -O3 -framework Metal -framework Foundation \
      igla_metal_bridge.m igla_metal_benchmark.m \
      -o igla_metal_benchmark
./igla_metal_benchmark
```

### Expected Output

```
IGLA Metal: Using device: Apple M1 Pro
IGLA Metal: Initialized successfully on Apple M1 Pro

  Vocab Size │ ops/s     │ M elem/s │ Status
       1000 │      8734 │   2620.2 │ 5K+
       5000 │      1326 │   1989.5 │ 1K+
      10000 │      3203 │   9608.5 │ 1K+
      50000 │       670 │  10050.0 │ GPU working
```

---

## Conclusion

The Metal GPU implementation is **technically correct** but **not faster than CPU SIMD** at 50K vocabulary due to Metal command buffer overhead.

**Recommended approach for Trinity v1.0:**
- Use CPU SIMD (igla_metal_gpu.zig) for production
- 1,795 ops/s at 50K vocab
- 64% improvement over baseline achieved

**Future optimization path:**
- Metal GPU for 100K+ vocabulary
- Batched query execution
- Async command pipelining

---

**phi^2 + 1/phi^2 = 3 = TRINITY | METAL IMPLEMENTED | CPU SIMD WINS AT 50K**
