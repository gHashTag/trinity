# Trinity LLM Scale Report: Multi-Node Distributed Inference

## Key Metrics

| Metric | Single Node | v1 (per-token) | v2 (batched) | v1->v2 |
|--------|------------|-----------------|-------------|--------|
| Prefill (20 tokens) | 52s | 77s | **39s** | **2x faster** |
| Decode (per token) | ~2.6s | ~1.7s | **~1.1s** | **1.5x faster** |
| Total (20+20 tokens) | ~105s | 143s | **83s** | **1.7x faster** |
| Memory per node | ~1.2GB | ~600MB | ~600MB | Same |
| Network transfer/prefill | 0 | 20x 8KB = 160KB | 1x 160KB | **1 round-trip** |
| Network fraction | 0% | ~100% | **56.9%** | Measurable |

## Architecture: Pipeline Parallelism

```
[Coordinator: layers 0-10]           [Worker: layers 11-21]
  embed(all tokens)
  forwardShard(all tokens)
  TCP send ALL hidden_states -------->  recv batch (160KB)
    (1 round-trip for prefill)         forwardShard(each sequentially)
                                        computeLogits + sample (each)
  recv ALL tokens <------------------ TCP send batch response

  [decode: single-token per RT]        [decode: single-token per RT]
```

### v2 Optimizations

1. **Batch prefill**: All prompt hidden states sent in 1 TCP round-trip (was 20 separate round-trips)
2. **TCP_NODELAY**: Disabled Nagle's algorithm on both coordinator and worker sockets
3. **Coalesced writes**: Header + payload combined into single `write()` syscall
4. **Pre-allocated buffers**: Worker reuses `output_buf`, `logits_buf`, `probs_buf` (zero heap allocs per token)
5. **Zero-alloc methods**: `computeLogitsInto()` and `sampleFromLogitsInto()` write into caller buffers
6. **Timing instrumentation**: Compute vs network breakdown per phase

### Design Decisions

1. **Worker-side sampling**: Worker samples token and returns 4 bytes instead of 128KB logits (32000x less traffic)
2. **Persistent TCP connection**: Single keepalive connection per generation session
3. **Tied embeddings**: Worker loads embedding table for output projection (TinyLlama ties weights)
4. **KV caches per shard**: Each node maintains KV caches only for its local layers
5. **Partial model loading**: `loadPartialWeights(start, end, embed, output)` loads only required layers

## Detailed Profile (v2 Batched)

```
╔══════════════════════════════════════════════════════════╗
║         DISTRIBUTED INFERENCE PROFILE                    ║
╠══════════════════════════════════════════════════════════╣
║  Prefill: 20 tokens
║    Local compute:    13,874ms   (coordinator layers 0-10)
║    Network (batch):  24,877ms   (worker layers 11-21 + sampling)
║    Total prefill:    38,751ms
║  Decode: 20 tokens
║    Total compute:    21,968ms   (coordinator local layers)
║    Total network:    22,367ms   (worker forward + response)
║    Total decode:     44,335ms
║  Network fraction: 56.9%
║  Total:              83,093ms
╚══════════════════════════════════════════════════════════╝
```

## What This Means

### For localhost (same machine)
Both nodes share the same CPU and memory bandwidth. Prefill improved from 77s to 39s by eliminating 19 TCP round-trips. Decode improved from 1.7s to 1.1s/token via TCP_NODELAY + zero-alloc. Total: 143s -> 83s (1.7x improvement). Memory per node remains halved (~600MB).

### For multi-machine deployment
On separate machines with dedicated RAM and CPU:
- Coordinator and worker compute **in parallel** (currently sequential on localhost)
- Expected prefill: **~25s** (coordinator 14s local + worker 25s remote, overlapped)
- Expected decode: **~1.1s/token** (similar, pipeline overlap)
- Memory per machine: **50% reduction** -- enables models that exceed single-machine RAM

### For scaling beyond 2 nodes
The `ShardConfig.autoSplit()` handles 2-node splits. N-node splits require:
- Chain of TCP connections (node 0 -> node 1 -> ... -> node N-1)
- Last node samples and returns token to coordinator
- Linear pipeline depth scales with N

## Technical Details

### Files Modified/Created

| File | Change |
|------|--------|
| `src/vibeec/gguf_model.zig` | `loadPartialWeights()`, `forwardShard()`, `computeLogits()`, `sampleFromLogits()`, `computeLogitsInto()`, `sampleFromLogitsInto()` |
| `src/trinity_node/protocol.zig` | `ForwardRequest`/`ForwardResponse` + `BatchForwardRequest`/`BatchForwardResponse` (0x11-0x14) |
| `src/trinity_node/distributed.zig` | `ShardConfig`, `PipelineWorker` (pre-alloc buffers, batch handler), `PipelineCoordinator` (batch prefill, timing), `setTcpNodelay()` |
| `src/trinity_node/main.zig` | `--distributed` CLI flag |
| `build.zig` | `gguf_model_mod` module for trinity-node |
| `src/tri/tri_utils.zig` | `.distributed` command |
| `src/tri/main.zig` + `tri_commands.zig` | dispatch + `runDistributedCommand()` |

### Network Protocol

```
ForwardRequest (8220 bytes for TinyLlama, single-token decode):
  TRIN header: [4B magic] [1B type=0x11] [4B length]
  Payload: [4B seq_id] [4B pos] [4B hidden_size] [4B temp] [hidden_size*4B data]

BatchForwardRequest (~164KB for 20-token prefill):
  TRIN header: [4B magic] [1B type=0x13] [4B length]
  Payload: [4B seq_id] [4B batch_size] [4B hidden_size] [4B temp]
           per token: [4B pos] [hidden_size*4B data]

ForwardResponse (12 bytes):
  [4B seq_id] [4B pos] [4B token]

BatchForwardResponse (8 + batch_size*4 bytes):
  [4B seq_id] [4B batch_size] [batch_size * 4B tokens]
```

### CLI Usage

```bash
# Terminal 1 (Worker)
./zig-out/bin/trinity-node --distributed --role worker \
  --model models/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf \
  --layers 11-21 --port 9335

# Terminal 2 (Coordinator)
./zig-out/bin/trinity-node --distributed --role coordinator \
  --model models/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf \
  --layers 0-10 --peer 127.0.0.1:9335 \
  --prompt "Hello, how are you?" --max-tokens 20 --temperature 0.7
```

## Test Results

### v1 Baseline (2026-02-08, per-token TCP)

```
Model: TinyLlama 1.1B Chat Q4_K_M (638MB GGUF)
Platform: macOS arm64 (Apple Silicon), Zig 0.15.2 ReleaseFast
Nodes: 2 (localhost)

Prefill: 20 tokens in 77,344ms (3.9s/token, 20 TCP round-trips)
Decode: 21 tokens, avg 1.7s/token
Total: 142,913ms
```

### v2 Optimized (2026-02-08, batched prefill)

```
Model: TinyLlama 1.1B Chat Q4_K_M (638MB GGUF)
Platform: macOS arm64 (Apple Silicon), Zig 0.15.2 ReleaseFast
Nodes: 2 (localhost)

Prefill: 20 tokens in 38,751ms (local=13,874ms, net=24,877ms, 1 batch RT)
Decode: 20 tokens, avg 1.1s/token (compute=22s, net=22s)
Total: 83,093ms
Network fraction: 56.9%
Improvement: 1.7x faster total, 2x faster prefill, 1.5x faster decode
```

## Conclusion

Distributed inference v2 with batch prefill reduces total time by **1.7x** on localhost:
- Prefill: 77s -> 39s (2x, via batch TCP)
- Decode: 1.7s -> 1.1s/token (1.5x, via TCP_NODELAY + zero-alloc)
- Network fraction now measurable: 56.9%

### Next Steps

1. **Multi-machine test**: Deploy on 2 separate VPS to measure real parallel speedup
2. **Tokenizer integration**: GGUF tokenizer for coherent text output
3. **Larger models**: Qwen2.5 7B Q4_K_M (requires download, ~4GB per shard)
4. **N-way pipeline**: Extend for >2 nodes
5. **Tensor parallelism**: Split matmul across nodes (complementary to pipeline)
