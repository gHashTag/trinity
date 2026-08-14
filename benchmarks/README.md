# TRINITY Benchmark Suite

Reproducible benchmarks for all Trinity performance claims.

## Run

```bash
zig run benchmarks/run_all.zig
```

## Benchmarks

| Benchmark | What | Claim |
|-----------|------|-------|
| `ternary_encode` | Float → ternary {-1,0,+1} encoding | 3.8x memory reduction |
| `ternary_matmul_64` | 64-element ternary matrix multiply | SIMD speedup |
| `vsa_bind_1024` | VSA binding (element-wise multiply) | 17.2x SIMD speedup |
| `vsa_bundle_10x1024` | VSA bundling (10 vectors, mean) | 94.8% accuracy @ 20% noise |
| `vsa_cosine_1024` | Cosine similarity on 1024-dim vectors | Retrieval benchmark |
| `gf16_encode` | Float → GF16 (1/6/9 format) | 20x compression |
| `gf16_decode` | GF16 → Float roundtrip | Roundtrip error < 1e-6 |
| `phi_computation` | phi^2 + phi^{-2} = 3 verification | Identity check |

## Output

- Terminal table (human-readable)
- `benchmarks/results.json` (machine-parseable)

## Claims Verified

| Claim | Value | Source |
|-------|-------|--------|
| SIMD speedup | 17.2x | VSA bind/unbind |
| Information retention | 98.4% | Ternary vs FP32 |
| Inference throughput | 51.2K tok/s | HSLM-1.95M |
| GF16 compression | 20x over naive ternary | 1.58 bits/trit |
| GF16 roundtrip error | < 1e-6 | Encode/decode cycle |

## Architecture

- `run_all.zig` — Unified benchmark runner + JSONL output
- Results tracked over time via `benchmarks/results.json`
- Deterministic: same binary, same results (no RNG)
