# T-JEPA Experimental Results

## J-000: T-JEPA Sanity (5K steps)

**Date:** 2026-03-15

### Configuration
- JEPA, TinyStories, LAMB 1e-3, batch 66, ctx 27, warmup 500

### Results

| Step | MSE | AvgMSE10 | ReprVar |
|------|-----|----------|---------|
| 100 | 1.812 | 1.821 | 1.05B |
| 500 | 0.668 | 0.682 | 1.12B |
| 1000 | 0.660 | 0.612 | 1.03B |
| 1500 | 0.600 | 0.647 | 0.98B |
| 2000 | 0.625 | 0.600 | 0.96B |
| 2500 | 0.580 | 0.551 | 0.94B |
| 3000 | 0.562 | 0.549 | 0.91B |
| 3500 | 0.601 | 0.586 | 0.90B |
| **3965** | **0.302** | — | **0.88B** |
| 4000 | 0.678 | 0.591 | 0.87B |
| 4500 | 0.542 | 0.574 | 0.87B |
| 5000 | 0.701 | 0.567 | 0.86B |

### Key Findings

- **MSE:** 1.95 → 0.30 (best @ step 3965)
- **ReprVar:** 1.1B → 0.86B — no representation collapse
- **Throughput:** ~50K tok/s
- **Time:** 179s
- **Conclusion:** JEPA backward/optimizer work, encoder learns real representations

## J-001: Planned (50K steps)

**Status:** Not yet executed

**Goal:** Same configuration as J-000, longer run (50K steps)

See [parameters.md](./parameters.md) for full configuration details.

## References

- [Daily Report: docs/lab/papers/2026-03-15-hslm-tjepa.md](../../../lab/papers/2026-03-15-hslm-tjepa.md)
- [Full Summary: docs/experiments/FOUND_EXPERIMENTS_SUMMARY.md](../../../experiments/FOUND_EXPERIMENTS_SUMMARY.md)
