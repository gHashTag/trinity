# T-JEPA Architecture (Ternary Joint Embedding Predictive Architecture)

## Overview

T-JEPA (Ternary JEPA) is a self-supervised learning architecture using ternary weights {-1, 0, +1} for efficiency. It implements joint embedding prediction as part of the HSLM multi-objective training system.

## Components

### 1. Mask Configuration
```zig
pub const MaskConfig = struct {
    mask_ratio: f32 = 0.3,   // 30% masked
    min_span: usize = 3,      // 3^1
    max_span: usize = 9,      // 3^2
    num_spans: usize = 2,     // 2 spans fit in ctx=81
};
```

### 2. EMA Synchronization
```zig
pub const EmaSync = struct {
    decay_start: f32 = 0.996,  // Initial decay (99.6% online)
    decay_end: f32 = 1.0,      // Final decay (target freezes)
};
```

**Decay schedule:**
- Step 0   → decay 0.996 (99.6% online)
- Step 20K → decay 0.998 (99.8% online)
- Step 40K → decay 0.999 (99.9% online)

### 3. Predictor Architecture
- **1 TrinityBlock + Linear projection**
- **Parameters:** ~650K (591K block + 59K projection)
- **Forward:** assemble → block → project masked positions

### 4. MSE Loss (Anti-Collapse)
- **L2-normalized before MSE**
- **Formula:** L = (1/N) Σ ||pred - target||²

## References

- [Source: docs/lab/papers/2026-03-15-hslm-tjepa.md](../../../lab/papers/2026-03-15-hslm-tjepa.md)
- [Source: docs/experiments/FOUND_EXPERIMENTS_SUMMARY.md](../../../experiments/FOUND_EXPERIMENTS_SUMMARY.md)
- [Source: crates/trios-train-cpu/src/tjepa.rs](../../../../../crates/trios-train-cpu/src/tjepa.rs)
