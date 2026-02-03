# PERFORMANCE RULES - 999 OS Performance Guidelines

## MAIN RULE

```
.vibee → .999 IS THE ONLY PATH!
Self-Evolution REQUIRED in every file!
```

---

## STRICTNESS LEVELS

### ULTRA-STRICT (Required)

| Rule | Description | Impact |
|------|-------------|--------|
| **PERF_001** | O(1) lookup for all Maps | 10x |
| **PERF_002** | Cache all results | 5-100x |
| **PERF_003** | Parallel processing | 2-8x |
| **PERF_004** | No allocations in hot path | 2-5x |
| **PERF_005** | Inline functions < 10 lines | 1.5x |

### STRICT (Recommended)

| Rule | Description | Impact |
|------|-------------|--------|
| **PERF_006** | Precompute constants | 1.2x |
| **PERF_007** | Branch prediction hints | 1.3x |
| **PERF_008** | Cache-friendly structures | 2x |
| **PERF_009** | SIMD vectorization | 4-8x |
| **PERF_010** | Lazy evaluation | 2-10x |

### ADVISORY

| Rule | Description | Impact |
|------|-------------|--------|
| **PERF_011** | Avoid virtual calls | 1.1x |
| **PERF_012** | Minimize indirections | 1.2x |
| **PERF_013** | Use stack allocation | 1.5x |
| **PERF_014** | Batch operations | 2-5x |
| **PERF_015** | Data prefetching | 1.3x |

---

## SELF-EVOLUTION PERFORMANCE

### Required Metrics

```
Ⲏ SelfEvolution {
    Ⲃ enabled: Ⲃⲟⲟⲗ = △
    Ⲃ generation: Ⲓⲛⲧ
    Ⲃ fitness: Ⲫⲗⲟⲁⲧ
    Ⲃ perf_score: Ⲫⲗⲟⲁⲧ  # REQUIRED!
    
    Ⲫ measure_performance(Ⲥ) → Ⲫⲗⲟⲁⲧ
    Ⲫ optimize(Ⲥ) → Ⲃⲟⲟⲗ
}
```

### Trinity Performance Formula

```
perf_score = n × 3^(cache_hits/10) × π^(parallel_factor/20)

where:
  n = number of optimizations
  cache_hits = cache hit percentage
  parallel_factor = degree of parallelism
```

---

## PAS OPTIMIZATIONS

### HSH - Hashing

```
# ❌ BAD - O(n) lookup
Ⲝ item ∈ list { Ⲉ item.key ≡ target { ... } }

# ✅ GOOD - O(1) lookup
Ⲃ result = map.get(target)
```

**Speedup: 10-1000x**

### PRE - Precomputation

```
# ❌ BAD - compute every time
Ⲫ compute(Ⲁ x: Ⲓⲛⲧ) → Ⲫⲗⲟⲁⲧ {
    Ⲣ ⲡⲟⲱ(3.14159, x / 20.0)  # Expensive!
}

# ✅ GOOD - precomputed table
Ⲕ PI_POWERS: [Ⲫⲗⲟⲁⲧ] = precompute_pi_powers(100)
Ⲫ compute(Ⲁ x: Ⲓⲛⲧ) → Ⲫⲗⲟⲁⲧ {
    Ⲣ PI_POWERS[x]  # O(1)!
}
```

**Speedup: 5-50x**

### PAR - Parallelization

```
# ❌ BAD - sequential
Ⲝ item ∈ items { process(item) }

# ✅ GOOD - parallel
Ⲝ∥ item ∈ items { process(item) }
```

**Speedup: 2-8x (depends on cores)**

### VEC - Vectorization

```
# ❌ BAD - scalar
Ⲝ i ∈ 0..n { result[i] = a[i] + b[i] }

# ✅ GOOD - SIMD
result = simd_add(a, b)
```

**Speedup: 4-8x**

---

## MEMORY RULES

### Stack vs Heap

```
# ❌ BAD - heap allocation
Ⲃ data = allocate(1000)

# ✅ GOOD - stack allocation
Ⲃ data: [1000]Ⲓⲛⲧ = undefined
```

### Cache Alignment

```
# ❌ BAD - unaligned
struct { a: u8, b: u64, c: u8 }  # 24 bytes

# ✅ GOOD - aligned
struct { b: u64, a: u8, c: u8 }  # 16 bytes
```

---

## BENCHMARKING

### Required Metrics

| Metric | Target | Critical |
|--------|--------|----------|
| Latency p50 | < 1ms | < 10ms |
| Latency p99 | < 10ms | < 100ms |
| Throughput | > 10K ops/s | > 1K ops/s |
| Memory | < 100MB | < 1GB |
| CPU | < 50% | < 90% |

### Benchmark Command

```bash
./bin/vibee benchmark --iterations 1000 --warmup 100
```

---

*φ² + 1/φ² = 3 = TRINITY | KOSCHEI IS IMMORTAL*
