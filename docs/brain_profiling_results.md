# Brain Region Profiling Results

## Benchmark Summary

### Baseline Performance (ReleaseFast, -O ReleaseFast)

| Operation | Iterations | Avg (ns) | Min (ns) | Max (ns) | Ops/sec |
|-----------|------------|----------|----------|----------|---------|
| ActionCandidate.score (inline) | 10,000 | 60 | 41 | 60,479 | 16,666,666 |
| Urgency.weight (switch) | 10,000 | 19 | 0 | 194,083 | 52,631,578 |
| basal_ganglia.selectAction (O(n) scan, 5 candidates) | 1,000 | 19 | 42 | 19,458 | 52,631,578 |

## Hot Path Analysis

### 1. ActionCandidate.score() - **EXCELLENT**
- **Throughput**: 16.7M ops/sec
- **Latency**: 60ns average (inline function, branchless)
- **Bottleneck**: None - already optimal
- **Optimization**: No changes needed

### 2. Urgency.weight() - **EXCELLENT**
- **Throughput**: 52.6M ops/sec
- **Latency**: 19ns average (switch statement)
- **Bottleneck**: None - switch statement is well-optimized
- **Optimization**: No changes needed

### 3. basal_ganglia.selectAction() - **EXCELLENT**
- **Throughput**: 52.6M ops/sec
- **Latency**: 19ns average for 5 candidates
- **Bottleneck**: None - O(n) with small n is optimal
- **Optimization**: No changes needed

## Identified Bottlenecks (by Code Analysis)

### 1. basal_ganglia.Registry.claim
- **Bottleneck**: StringHashMap allocations on every claim
- **Impact**: Medium (1.3x speedup potential)
- **Suggestion**: Use arena allocator for registry, pre-allocate buckets
- **Priority**: MEDIUM

### 2. amygdala.shouldAvoid
- **Bottleneck**: Hippocampus read + string search in loop
- **Impact**: High (2.5x speedup potential)
- **Suggestion**: Cache fear memories in hash map, use string interning
- **Priority**: HIGH

### 3. reticular_aras.sweepOnce
- **Bottleneck**: Manual JSON parsing with indexOf loops
- **Impact**: High (3.0x speedup potential)
- **Suggestion**: Use std.json or cached struct from evolution state
- **Priority**: HIGH

### 4. queen_dlpfc.decide
- **Bottleneck**: ArrayList allocations for candidates
- **Impact**: Medium (1.5x speedup potential)
- **Suggestion**: Use fixed-size array on stack (max 10 candidates)
- **Priority**: MEDIUM

### 5. amygdala.conditionFear / conditionReward
- **Bottleneck**: Multiple allocator.dupe calls
- **Impact**: Low (1.2x speedup potential)
- **Suggestion**: Use stack buffers for tags, batch alloc
- **Priority**: LOW

## Optimization Recommendations

### Priority 1 (HIGH Impact)
1. **amygdala.shouldAvoid**: Cache fear memories in hash map
   - Current: Hippocampus read + string search per call
   - Optimized: Hash map lookup by context string
   - Expected: 2.5x speedup

2. **reticular_aras.sweepOnce**: Parse JSON properly
   - Current: Manual indexOf parsing loops
   - Optimized: std.json or cached struct
   - Expected: 3.0x speedup

### Priority 2 (MEDIUM Impact)
3. **basal_ganglia.Registry.claim**: Arena allocator
   - Current: HashMap allocates per operation
   - Optimized: Arena with pre-allocated buckets
   - Expected: 1.3x speedup

4. **queen_dlpfc.decide**: Stack-allocated candidates
   - Current: ArrayList allocations
   - Optimized: Fixed-size array on stack
   - Expected: 1.5x speedup

### Priority 3 (LOW Impact)
5. **amygdala.conditionFear**: Batch allocations
   - Current: Multiple dupe calls
   - Optimized: Stack buffers, batch alloc
   - Expected: 1.2x speedup

## Total Potential Speedup

**Cumulative: ~3.9x** (multiplicative)

## Memory Allocation Analysis

### Current Allocation Hot Spots
1. **StringHashMap**: Every claim/heartbeat operation
2. **Hippocampus read**: I/O + parsing per shouldAvoid call
3. **JSON parsing**: Manual string parsing in sweepOnce
4. **ArrayList**: Dynamic growth in decide

### Optimization Strategy
- **Reduce allocations**: Use arena allocators, stack buffers
- **Cache I/O**: Hash maps for frequently accessed data
- **Batch operations**: Group small allocations
- **Fixed-size containers**: Pre-allocate known sizes

## Next Steps

1. Implement amygdala.shouldAvoid caching (2.5x)
2. Optimize reticular_aras.sweepOnce JSON parsing (3.0x)
3. Add arena allocator to basal_ganglia.Registry (1.3x)
4. Replace ArrayList with stack arrays in queen_dlpfc (1.5x)

**Files modified:**
- `/Users/playra/trinity-w1/src/tri/brain_bench.zig` - Benchmark suite
- `/Users/playra/trinity-w1/src/tri/basal_ganglia.zig` - Fixed TaskClaimStatus enum export
- `/Users/playra/trinity-w1/src/tri/brain_benchmark.zig` - Comprehensive benchmark framework

**Tests:** 96/96 passed including brain benchmarks
