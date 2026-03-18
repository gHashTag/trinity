# TRINITY V1 — Week 2 Roadmap (After UART Cable Arrives)

## φ² + 1/φ² = 3 = TRINITY

**Target: 10K-dimensional VSA + Tiny Quant Neural Network (TQNN) + Integration with Trinity Core**

---

## Week 2 Goals

| Goal | Description | Success Criteria |
|------|-------------|-------------------|
| 1 | Expand VSA to 10K dimensions | 40× increase from 256-dim |
| 2 | Implement TQNN inference | Real neural network on FPGA |
| 3 | Trinity Core integration | CLI can query FPGA |
| 4 | Multi-token generation | Generate sequences |
| 5 | Performance benchmarking | Measure vs CPU |

---

## Day-by-Day Plan

### Day 1: 10K VSA Architecture

**Objective**: Design scalable VSA engine for 10K-dimensional vectors

**Tasks**:
- [ ] Design 10K-dim VSA block diagram
- [ ] Implement 10K-dim vector storage (BRAM or distributed)
- [ ] Update bind/bundle/similarity for 10K vectors
- [ ] Add vector packing/unpacking for UART transfer

**Implementation Strategy**:
```
10K trits = 10,000 × 2 bits = 20,000 bits = 2,500 bytes = ~2.5KB

Storage options:
A. BRAM: 10K trits → ~1 BRAM (32Kb)
B. Distributed: Split across multiple BRAMs
C. Compressed: Sparse vector encoding

Day 1 choice: BRAM storage (fast, simple)
```

**Deliverables**:
- `vsa_10k.v` — 10K VSA core module
- Updated UART protocol (chunked transfer)
- Test bench with random 10K vectors

---

### Day 2: Tiny Quant Neural Network (TQNN)

**Objective**: Implement real inference with TQ1_0 weights

**TQNN Architecture**:
```
Input (prompt_id) → Embedding (256×64) → Layer 1 (64×64) →
Layer 2 (64×64) → ... → Output (256 vocab)

Quantization: Ternary weights {-1, 0, +1}
Activation: INT8
```

**Tasks**:
- [ ] Load TQ1_0 weights into BRAM (5 BRAMs)
- [ ] Implement matmul engine (ternary × INT8)
- [ ] Add softmax (approximate with table lookup)
- [ ] Token sampling (argmax or temperature)

**Weight Storage**:
```
Each layer: 64×64 = 4096 weights × 2 bits = 8192 bits = 1KB

Total for 12 layers: 12 × 1KB = 12KB ≈ 4 BRAMs
+ Embedding: 256 × 64 = 16K trits = 4KB ≈ 1 BRAM
Total: ~5 BRAMs (0.04 BRAM per 1K params)
```

**Deliverables**:
- `tqnn.v` — TQNN inference engine
- `tqnn_weights.mem` — Weight initialization file
- Test with known prompts

---

### Day 3: Trinity Core Integration

**Objective**: Connect FPGA to Trinity CLI

**Tasks**:
- [ ] Extend UART protocol for streaming
- [ ] Implement "query" command: prompt → tokens
- [ ] Add "config" command: set temp, top_k
- [ ] Error handling and recovery

**Protocol Extensions**:
```
New commands:
0x10 QUERY    → Send prompt (streaming), receive tokens
0x11 CONFIG   → Set generation params (temp, top_k, max_tokens)
0x12 RESET    → Reset inference state
0x13 STATUS   → Get FPGA status (busy, ready, error)
```

**Deliverables**:
- `trinity_cli_bridge.zig` — Zig module for FPGA communication
- Updated `uart_host_v7.zig`
- CLI integration test

---

### Day 4: Multi-Token Generation

**Objective**: Generate token sequences, not just single tokens

**Tasks**:
- [ ] Implement KV cache (key-value for attention)
- [ ] Streaming output (token by token)
- [ ] Stop conditions (EOS, max_tokens)
- [ ] Beam search (optional, beam width 2)

**KV Cache Storage**:
```
For each layer: 64 × 128 (max seq) = 8K entries

Option A: BRAM storage (~2 BRAMs per layer)
Option B: External DDR (future)
Option C: Limited context (no cache)

Day 4 choice: BRAM KV cache, context = 32 tokens
```

**Deliverables**:
- `kv_cache.v` — KV cache module
- Streaming UART output
- Test with multi-token prompts

---

### Day 5: Performance Optimization

**Objective**: Measure and optimize inference speed

**Tasks**:
- [ ] Benchmark VSA operations (10K vectors)
- [ ] Benchmark TQNN per-token latency
- [ ] Pipeline optimizations
- [ ] Resource usage analysis

**Target Metrics**:
```
VSA bind (10K):     < 1ms  (vs ~100μs for 256-dim)
VSA similarity (10K): < 5ms
TQNN per-token:     < 10ms (100 tokens/sec)
Throughput:         > 50 tokens/sec sustained
```

**Optimization Techniques**:
- [ ] Pipeline VSA operations
- [ ] Parallel matmul (multiple DSP blocks)
- [ ] Precompute CRC tables
- [ ] Batch processing

**Deliverables**:
- `bench_v2.sh` — Performance benchmark
- Optimization report
- Comparison vs CPU (Trinity Core software)

---

### Day 6: Integration & Testing

**Objective**: Full system test with real prompts

**Tasks**:
- [ ] End-to-end test: prompt → response
- [ ] Edge cases: empty prompt, long prompt
- [ ] Stress test: 1000 queries
- [ ] Power consumption measurement

**Test Plan**:
```
1. Unit tests: VSA, TQNN, UART
2. Integration tests: VSA + TQNN
3. System tests: Full pipeline
4. Performance tests: Benchmarking
5. Stress tests: Long-running
```

**Deliverables**:
- `trinity_v2.bit` — Week 2 bitstream
- Test report
- Demo with real prompts

---

### Day 7: Documentation & Release

**Objective**: Complete Week 2, prepare for Week 3

**Tasks**:
- [ ] Update README with 10K VSA + TQNN
- [ ] Write API documentation
- [ ] Create examples
- [ ] Plan Week 3 (MMIO, DDR, etc.)

**Deliverables**:
- `TRINITY_V2_README.md`
- `TRINITY_V2_API.md`
- Example scripts
- Week 3 roadmap

---

## Resource Estimates (Week 2)

| Module | LUT | FF | BRAM | DSP |
|--------|-----|----|----|-----|
| VSA 10K | ~500 | ~200 | 1 | 0 |
| TQNN (12 layers) | ~2000 | ~1000 | 5 | 0 |
| KV Cache | ~300 | ~150 | 2 | 0 |
| Control | ~200 | ~100 | 0 | 0 |
| **Total** | **~3000** | **~1450** | **8** | **0** |
| **% of XC7A100T** | **~5%** | **~1%** | **~3%** | **0%** |

**Result**: Still plenty of room (95% available)!

---

## Risk Assessment

| Risk | Impact | Mitigation |
|------|--------|------------|
| BRAM shortage | High | Use sparse encoding |
| Timing failure | Medium | Add pipeline stages |
| UART bottleneck | Low | Implement compression |
| Power consumption | Low | Measure, optimize later |

---

## Success Metrics

Week 2 is successful when:
- [ ] 10K VSA operations work correctly
- [ ] TQNN generates coherent tokens
- [ ] CLI can query FPGA
- [ ] Performance targets met
- [ ] Full demo with real prompts

---

**φ² + 1/φ² = 3 = TRINITY**

**Created**: 2026-02-28
**Target Start**: Day cable arrives
**Duration**: 7 days
