---
sidebar_position: 4
---

# Hybrid API

HybridBigInt — Optimal Memory/Speed Trade-off.

**Module:** `src/hybrid.zig`

## Storage Modes

| Mode | Storage | Speed | Use Case |
|------|---------|-------|----------|
| Packed | 1.58 bits/trit | Slower | Storage |
| Unpacked | 8 bits/trit | Fast | Computation |

## Core Functions

### zero() → HybridBigInt

```zig
var v = HybridBigInt.zero();
```

### random(len) → HybridBigInt

```zig
var v = HybridBigInt.random(1000);
```

### pack() / ensureUnpacked()

```zig
vector.pack();           // Memory efficient
vector.ensureUnpacked(); // Compute efficient
```

## Constants

| Constant | Value | Description |
|----------|-------|-------------|
| `MAX_TRITS` | 59049 | Maximum dimension |
| `SIMD_WIDTH` | 32 | Parallel trits |
