# Ternary Quantum Neural Network (TQNN) — Design Document

## Overview

**TQNN** = Ternary + Quantum + Neural Network

A hybrid architecture combining:
- **Ternary weights** {-1, 0, +1} for 2× memory efficiency
- **Quantum-inspired activations** (CGLMP violation detection)
- **Neural network inference** on FPGA

---

## Architecture

### Network Topology

```
Input (prompt_id: 1 byte)
    ↓
Embedding Layer (256 × 64 trits)
    ↓
Hidden Layer 1 (64 × 64 trits, ReLU)
    ↓
Hidden Layer 2 (64 × 64 trits, ReLU)
    ↓
...
    ↓
Hidden Layer N (64 × 64 trits, ReLU)
    ↓
Output Layer (64 × 256 trits, Softmax)
    ↓
Token (1 byte, ASCII)
```

**Typical Configuration**:
- Embedding: 256 vocab × 64 dim = 16,384 trits
- Hidden layers: 12 layers × 4,096 trits = 49,152 trits
- Output: 64 × 256 = 16,384 trits
- **Total**: ~82K trits = 164K bits = 20.5 KB ≈ 6-7 BRAMs

---

## Weight Encoding

### Ternary Representation

Each weight is stored as 2 bits:
```
00 → Zero weight (pruned)
01 → +1 weight
10 → -1 weight
11 → Reserved (future: -2, +2 scaling)
```

**Memory Savings**:
- Float32: 4 bytes per weight
- Ternary: 0.25 bytes per weight
- **Savings**: 16× reduction!

---

### BRAM Storage Strategy

```verilog
// Layer weights stored in BRAM
// Example: 64×64 layer = 4096 weights = 8192 bits = 1 KB

module tqnn_layer_weights (
    input wire clk,
    input wire [5:0] row,      // 64 rows
    input wire [5:0] col,      // 64 cols
    output reg [1:0] weight    // 2-bit ternary weight
);
    // 4096 weights = 2048 words of 16 bits
    reg [15:0] memory [0:2047];

    always @(posedge clk) begin
        weight <= memory[{row, col[5:4]}][col[3:0]*2 +: 2];
    end
endmodule
```

**BRAM Usage**:
- 1 layer (64×64) ≈ 1 BRAM
- 12 layers ≈ 12 BRAMs
- With packing: ~6 BRAMs

---

## Inference Engine

### Matrix Multiplication (Ternary × Int8)

```verilog
// Ternary matrix multiply: W × X
// W: {-1, 0, +1}, X: INT8

module tqnn_matmul (
    input wire clk,
    input wire [5:0] row,      // 64 output rows
    input wire [5:0] col,      // 64 input cols
    input wire [7:0] x [0:63], // Input vector (INT8)
    input wire [1:0] w [0:63], // Weight row (ternary)
    output reg signed [15:0] y // Output (INT16)
);
    integer i;
    reg signed [15:0] acc;

    always @(*) begin
        acc = 0;
        for (i = 0; i < 64; i = i + 1) begin
            case (w[i])
                2'b01: acc = acc + {{8{x[7]}}, x[i]};  // +1 × x[i]
                2'b10: acc = acc - {{8{x[7]}}, x[i]};  // -1 × x[i]
                2'b00: ;                                // 0 × x[i] = 0 (pruned)
            endcase
        end
        y = acc;
    end
endmodule
```

**Optimization**: No multiplication needed! Just addition/subtraction.

---

### Activation Function (Quantum ReLU)

```verilog
// ReLU with quantum-inspired threshold
// Regular ReLU: max(0, x)
// Quantum ReLU: max(φ⁻¹, x) for violation detection

module tqnn_activation (
    input wire signed [15:0] x,
    output reg signed [7:0] y
);
    // φ⁻¹ ≈ 0.618, scaled to INT8: 0.618 × 128 = 79
    localparam PHI_INVERSE = 8'd79;

    always @(*) begin
        if (x < 0)
            y = 8'd0;
        else if (x < 16'd79)
            y = 8'd79;  // Minimum activation (quantum floor)
        else if (x > 16'd32767)
            y = 8'd127; // Clamp to INT8 max
        else
            y = x[7:0]; // Truncate to INT8
    end
endmodule
```

---

## Pipeline Architecture

### 4-Stage Pipeline

```
Stage 1: Fetch Weights   (BRAM read)
    ↓
Stage 2: MatMul          (Accumulate)
    ↓
Stage 3: Activation      (ReLU)
    ↓
Stage 4: Write Back      (BRAM write / Output)
```

**Timing**:
- Each stage: 4 cycles @ 50MHz = 80ns
- Per-layer latency: 4 cycles
- 12 layers: 48 cycles = 0.96μs
- **Throughput**: ~1M tokens/second (theoretical)

---

## Integration with Trinity V1

### UART Command Extension

```
Existing: 0x05 BITNET (stub)
New:       0x15 TQNN_INFERENCE

Protocol:
[0xAA][0x15][00h][01h][PROMPT_ID][CRC_L][CRC_H]

Response:
[0x00][TOKEN][CRC_L][CRC_H]  # Single token
```

### Multi-Token Generation (Future)

```
Command: 0x16 TQNN_STREAM

Response: Streaming tokens
[0x00][TOKEN1][CRC_L][CRC_H]
[0x00][TOKEN2][CRC_L][CRC_H]
...
[0xFF][00h][CRC_L][CRC_H]  # EOS
```

---

## Resource Estimates

| Module | LUT | FF | BRAM | DSP | Notes |
|--------|-----|----|----|-----|-------|
| Weight Storage (12L) | ~500 | ~200 | 6 | 0 | Ternary packed |
| MatMul Engine | ~1000 | ~500 | 0 | 0 | Add/sub only |
| Activation | ~200 | ~100 | 0 | 0 | Quantum ReLU |
| Pipeline Control | ~300 | ~200 | 0 | 0 | 4 stages |
| KV Cache (optional) | ~400 | ~200 | 2 | 0 | 32-token context |
| **Total** | **~2400** | **~1200** | **8** | **0** |
| **% of XC7A100T** | **~4%** | **~1%** | **~3%** | **0%** |

---

## Training Strategy (Software)

### Ternarization Process

```python
# PyTorch → Ternary conversion
import torch

def ternarize(weight):
    """Convert float32 weights to ternary {-1, 0, +1}"""
    threshold = weight.abs().mean() * 0.7  # Empirical
    result = weight.clone()

    # Positive → +1, Negative → -1, Near-zero → 0
    result[weight > threshold] = 1
    result[weight < -threshold] = -1
    result[weight.abs() <= threshold] = 0

    return result

# Export to Verilog
def export_verilog(weights, layer_name):
    with open(f"{layer_name}.mem", "w") as f:
        for w in weights.flatten():
            if w > 0:
                f.write("01\n")
            elif w < 0:
                f.write("10\n")
            else:
                f.write("00\n")
```

---

## Next Steps

1. **Day 8**: Implement `tqnn_layer.v` (single layer inference)
2. **Day 9**: Implement `tqnn_12layer.v` (full network)
3. **Day 10**: Load real TQ1_0 weights from software
4. **Day 11**: Integrate with Trinity V1 UART
5. **Day 12**: Multi-token streaming
6. **Day 13**: Benchmarking vs CPU
7. **Day 14**: Documentation and demo

---

## Success Criteria

- [ ] TQNN generates coherent tokens
- [ ] Inference < 10ms per token
- [ ] Resource usage < 5% of FPGA
- [ ] UART integration works
- [ ] Can run 1000+ queries without error

---

**φ² + 1/φ² = 3 = TRINITY**

**Cycle #125 — Week 2 Day 2 — TQNN Design**
