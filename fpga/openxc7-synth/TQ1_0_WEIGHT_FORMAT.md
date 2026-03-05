# TQ1_0 Weight Storage Format for FPGA
# Day 5: Design for future real BitNet inference

## Overview

TQ1_0 (Ternary Quantization 1.0) stores weights in {-1, 0, +1} format.
For FPGA implementation, we need efficient storage and access patterns.

## Trit Encoding (2 bits per trit)

| Value | Binary | Hex | Description |
|-------|--------|-----|-------------|
| 0     | 00     | 0x0 | Zero (pruned) |
| +1    | 01     | 0x1 | Positive |
| -1    | 10     | 0x2 | Negative |
| N/A   | 11     | 0x3 | Reserved |

## Weight Storage Layout

### Tiny BitNet 0.1B (TQ1_0) Spec
- Layers: ~12
- Hidden dim: 64
- Vocab size: 256
- Total params: ~10K (after ternarization)

### BRAM Storage Strategy

Each Artix-7 BRAM (36Kb) can store:
- 32 bits × 1024 = 32K bits = 4096 bytes
- With 2-bit trits: 4096 × 4 = 16384 trits per BRAM

For a 64-dim layer:
- Weight matrix: 64 × 64 = 4096 weights
- With 2-bit trits: 4096 × 2 = 8192 bits = 1KB
- Can fit 4+ such layers in one BRAM

### Addressing Scheme

```
// Layer N weight at row r, col c:
addr = layer_base[N] + (r * 64 + c) / 16
trit_offset = (r * 64 + c) % 16
```

Each 32-bit BRAM word holds 16 trits:
```
[31:30] [29:28] ... [3:2] [1:0]
 trit15   trit14  ...  trit1  trit0
```

## Inference Pipeline (Future Day 6+)

### Stage 1: Fetch
```
state = FETCH;
bram_addr = compute_addr(layer, row, col);
trit_word = bram_data[bram_addr];
trit = (trit_word >> (2 * col_offset)) & 0x3;
```

### Stage 2: Activate
```
// Trit to value
activation = (trit == 2'b01) ? +1 :
             (trit == 2'b10) ? -1 : 0;
```

### Stage 3: MAC (Multiply-Accumulate)
```
accum <= accum + (activation * input[row]);
```

### Stage 4: Output
After 64 cycles, output[row] = accum >> 6; // scale factor

## Token Format

Prompt ID → Token mapping (Day 5 stub):
| Prompt ID | Token | ASCII | Description |
|-----------|-------|-------|-------------|
| 0-9       | 48-57 | 0-9   | Digits |
| 10-35     | 97-122| a-z   | Letters |
| 42        | 33    | !     | "The Answer" |
| 255       | 63    | ?     | Unknown |

Future: Full softmax over vocabulary (256 tokens)

## BRAM Usage Estimate (TQ1_0)

| Component | Size | BRAMs |
|-----------|------|-------|
| Embedding | 256×64 trits | 1 |
| Layer 1-12 weights | 12×64×64 trits | 3 |
| Output head | 256×64 trits | 1 |
| **Total** | ~55K trits | **5 BRAMs** |

Artix-7 XC7A100T has 269 BRAMs → plenty of room!

## Next Steps (Day 6)

1. Implement actual TQ1_0 weights in BRAM init
2. Replace stub inference with real MAC pipeline
3. Add softmax for token sampling
4. Multi-token generation support

## Day 5 Status

✅ **STUB COMPLETE** - Command 0x05 works, returns fixed tokens
⏳ **REAL INFERENCE** - Pending Day 6 implementation

---
φ² + 1/φ² = 3 = TRINITY
