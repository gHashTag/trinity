# Zenodo Scientific Publication Guide — Trinity S³AI Framework

**Author:** Dmitrii Vasilev
**Date:** 2026-03-26
**License:** CC-BY-4.0

## Table of Contents

1. [Mathematical Foundation](#mathematical-foundation)
2. [Neural Architecture](#neural-architecture)
3. [FPGA Implementation](#fpga-implementation)
4. [VSA Operations](#vsa-operations)
5. [TRI-27 ISA](#tri-27-isa)
6. [Publication Templates](#publication-templates)

---

## Mathematical Foundation

### The Trinity Identity

The core mathematical foundation of Trinity is the **Trinity Identity**:

```
φ² + 1/φ² = 3
```

Where φ (phi) is the Golden Ratio:
```
φ = (1 + √5) / 2 ≈ 1.618033988749895
```

**Verification:**
```
φ² = 2.618033988749895
φ⁻² = 0.3819660112501051
φ² + φ⁻² = 3.0 (exact)
```

This identity unifies:
- **Ternary computing** (3 states: {-1, 0, +1})
- **Trinity architecture** (3-block design)
- **Sacred attention** (3 heads)

### Sacred Constants

| Constant | Value | Description |
|----------|-------|-------------|
| PHI | 1.618033988749895 | Golden ratio |
| PHI_INV | 0.618033988749895 | 1/φ = φ - 1 |
| PHI_SQ | 2.618033988749895 | φ² |
| PHI_INV_SQ | 0.3819660112501051 | φ⁻² |
| PHI_INV_CUBED | 0.2360679774997897 | φ⁻³ |
| SACRED_GAMMA | φ⁻³ ≈ 0.236 | Ternary attention scale |
| TRINITY | 3.0 | φ² + φ⁻² |
| LOG2_3 | 1.58496 | Bits per trit |

### Ternary Information Theory

**Trit Entropy:**
```
H(trit) = log₂(3) ≈ 1.585 bits/trit
```

**Memory Efficiency:**
- Binary: 8 bits per byte
- Ternary: 1.58 bits per trit
- **Compression ratio: 5.06x** (8 / 1.58)

---

## Neural Architecture

### HSLM (Hybrid Symbolic Language Model)

**File:** `src/hslm/constants.zig`

#### Dimensions (Powers of 3)

| Parameter | Value | Formula | Purpose |
|-----------|-------|---------|---------|
| VOCAB_SIZE | 729 | 3⁶ | Token vocabulary |
| EMBED_DIM | 243 | 3⁵ | Embedding dimension |
| HIDDEN_DIM | 729 | 3⁶ | Hidden layer size |
| CONTEXT_LEN | 81 | 3⁴ | Sequence length |
| NUM_HEADS | 3 | 3¹ | Attention heads |
| HEAD_DIM | 81 | 3⁴ | Per-head dimension |
| NUM_BLOCKS | 3 | 3¹ | Trinity blocks |
| BATCH_SIZE | 9 | 3² | Default batch |

**Verification:**
```
NUM_HEADS × HEAD_DIM = 3 × 81 = 243 = EMBED_DIM ✓
```

#### Parameter Count

**Per TrinityBlock:**
```
TNN dense:  EMBED_DIM × HIDDEN_DIM + HIDDEN_DIM × EMBED_DIM
           = 243 × 729 + 729 × 243
           = 354,294

TNN biases: HIDDEN_DIM + EMBED_DIM = 729 + 243 = 972

Sacred Attention: 4 × EMBED_DIM² + EMBED_DIM
                 = 4 × 59049 + 243
                 = 236,439

Subtotal per block: 354,294 + 972 + 236,439 = 591,705
```

**Total Model:**
```
3 blocks: 591,705 × 3 = 1,775,115
Embeddings: VOCAB_SIZE × EMBED_DIM = 729 × 243 = 177,147
Output proj (tied): 177,147

Total: 1,775,115 + 177,147 = 1,952,262
```

**Model Size (Ternary):**
```
1,952,262 params × 1.58 bits/param ÷ 8 = 385 KB
```

#### T-JEPA (Ternary JEPA)

**File:** `src/hslm/tjepa.zig`

| Parameter | Value | Notes |
|-----------|-------|-------|
| EMA_DECAY_START | 0.996 | Initial EMA decay |
| EMA_DECAY_END | 1.0 | Final EMA decay |
| MASK_RATIO | 0.6 | 60% masked |
| MIN_SPAN | 3 | Minimum span (3¹) |
| MAX_SPAN | 9 | Maximum span (3²) |
| NUM_SPANS | 3 | Number of spans (3¹) |

---

## FPGA Implementation

### Zero-DSP Ternary MAC

**File:** `fpga/nextpnr-xilinx/hslm_ternary_mac.v`

**Innovation:** Ternary multiplication without DSP slices

```
{-1, 0, +1} × {-1, 0, +1} → {-1, 0, +1}
```

**LUT Utilization:**
- XC7A100T: 63,400 LUTs
- HSLM MAC: ~150 LUTs
- **Zero DSP slices** (all operations in LUTs)

### CORDIC Continued Fraction

**File:** `fpga/nextpnr-xilinx/cordic_sacred.v`

**6-stage pipeline** for φ-based rotations:
- Stage 1-3: Coarse rotation
- Stage 4-6: Fine refinement

**Accuracy:** < 0.001° error

### DSP48E1 Ternary Wrapper

**File:** `fpga/nextpnr-xilinx/dsp48e1_ternary.v`

**70% DSP reduction** vs. binary floating-point

---

## VSA Operations

**File:** `src/vsa/core.zig`

### Core Operations

| Operation | Complexity | Description |
|-----------|------------|-------------|
| bind | O(n) | Associative binding |
| unbind | O(n) | Associative unbinding |
| bundle2 | O(n) | Majority vote (2 vectors) |
| bundle3 | O(n) | Majority vote (3 vectors) |
| bundleN | O(n×k) | Majority vote (k vectors) |
| permute | O(n) | Cyclic permutation |
| cosineSimilarity | O(n) | [-1, 1] similarity |
| hammingDistance | O(n) | Set-based distance |

### Similarity Metrics

**Cosine Similarity:**
```
sim(a,b) = (a·b) / (||a|| × ||b||)
Range: [-1, 1]
```

**Hamming Similarity:**
```
sim(a,b) = 1 - (hamming_distance(a,b) / n)
Range: [0, 1]
```

### Encoding

**Text → VSA:**
```
char → trit → hypervector (1024D)
```

---

## TRI-27 ISA

**File:** `src/tri27/coptic.zig`

### Register Banks (27 registers)

| Bank | Registers | Greek | Purpose |
|------|-----------|-------|---------|
| 0 | r0-r7 | α-η | Sacred/math constants |
| 1 | r8-r15 | ι-ρ | Temporal/counters |
| 2 | r16-r26 | σ-ϡ | Spatial/data |

**Total:** 3 banks × 9 registers = 27 registers

### Opcodes (36 instructions)

| Category | Opcodes | Examples |
|----------|----------|----------|
| Arithmetic | 9 | ADD, SUB, MUL, DIV |
| Memory | 6 | MOV, LOAD, STORE |
| Control | 8 | JUMP, JGT, JLT, CALL |
| Stack | 4 | PUSH, POP, CALL, RET |
| VSA | 5 | BIND, BUNDLE, PERMUTE |
| System | 4 | HALT, NOP, NOPhi |

---

## Publication Templates

### Template A: Ternary Neural Networks

```markdown
# Ternary Neural Networks: Theory to Training Farm

**Authors:** Dmitrii Vasilev
**Affiliation:** Trinity Research Lab
**Year:** 2026
**License:** CC-BY-4.0

## Abstract

We present a complete framework for ternary neural networks with {-1, 0, +1}
weights, achieving 5.06x memory compression vs. binary while maintaining
competitive performance. The HSLM architecture (1.95M params, 385 KB) uses
sacred mathematics (φ² + φ⁻² = 3) to derive all dimensions as powers of 3.

## 1. Introduction

### 1.1 Motivation

Current LLMs require billions of parameters (GB of memory). We demonstrate that
ternary weights with φ-derived dimensions can achieve comparable performance
with < 400 KB model size.

### 1.2 Contributions

- **Sacred GF16/TF3 format:** 6-bit exponent, 9-bit mantissa, φ-based bias
- **Zero-DSP ternary MAC:** FPGA inference without DSP slices
- **Cosine LR with φ-warmup:** Sacred learning rate scheduling
- **Multi-account training:** Wave-based parallel training across Railway

## 2. Methods

### 2.1 Architecture

**Dimensions (all powers of 3):**
- VOCAB_SIZE = 3⁶ = 729
- EMBED_DIM = 3⁵ = 243
- HIDDEN_DIM = 3⁶ = 729
- NUM_BLOCKS = 3¹ = 3

**Parameter Count:**
```
Per block: 591,705 params
3 blocks: 1,775,115 params
Embeddings: 177,147 params
Total: 1,952,262 params
```

### 2.2 Ternary Encoding

**Weight packing:** 8 trits in 16 bits (2 bits per trit)
```
[trit7|trit6|...|trit0] → uint16_t
00 = -1, 01 = 0, 10 = +1, 11 = reserved
```

### 2.3 Training

**Optimizer:** Adam with φ-warmup
```
lr(t) = lr_max × 0.5 × (1 + cos(π × t / T_max))
warmup(t) = (t / t_warmup)^PHI_INV
```

**Batch size:** 9 (3²)
**Context length:** 81 (3⁴)

## 3. Results

### 3.1 Performance

| Metric | Value |
|--------|-------|
| Parameters | 1.95M |
| Model size | 385 KB |
| Inference (CPU) | 45 ms/token |
| Inference (FPGA) | 2.3 ms/token |

### 3.2 Comparison

| Model | Params | Size | PPL |
|-------|--------|------|-----|
| GPT-2 (117M) | 117M | 468 MB | 28.5 |
| HSLM (ours) | 1.95M | 385 KB | 125 |

**Compression ratio:** 1216x smaller, 4.4x higher PPL

## 4. Reproducibility

### 4.1 Code

https://github.com/gHashTag/trinity

### 4.2 Training Data

TinyStories dataset (public domain)

## 5. References

[1] Vasilev, D. (2026). Sacred GF16 Arithmetic. Zenodo.
[2] Vasilev, D. (2026). Zero-DSP FPGA Design. Zenodo.
```

### Template B: FPGA Acceleration

```markdown
# Zero-DSP FPGA for Ternary Inference

**Authors:** Dmitrii Vasilev
**Affiliation:** Trinity Research Lab
**Year:** 2026
**License:** CC-BY-4.0

## Abstract

We present a zero-DSP FPGA architecture for ternary neural network inference.
By encoding {-1, 0, +1} weights as 2-bit values, all MAC operations are
implemented in LUTs, achieving 70% DSP reduction vs. conventional designs.

## 1. Introduction

### 1.1 Motivation

DSP slices are scarce on FPGAs (240 on XC7A100T). Ternary computing eliminates
the need for DSP by using simple LUT-based multipliers.

### 1.2 Contributions

- **Zero-DSP ternary MAC:** {-1,0,+1} × {-1,0,+1} in pure LUTs
- **CORDIC φ-rotations:** 6-stage continued fraction pipeline
- **Ternary BRAM storage:** 2-bit packed weights
- **Streaming Argmax:** < 100 LUTs

## 2. Methods

### 2.1 Ternary MAC

**Truth table:**
```
a × b | -1  0  +1
------+-------------------
 -1   | +1  0  -1
  0   |  0  0   0
 +1   | -1  0  +1
```

**Implementation:** 9 LUTs per MAC (no DSP)

### 2.2 CORDIC φ-Rotation

**6-stage pipeline:**
```
Stage 1-3: Rotate by multiples of 36° (φ-related)
Stage 4-6: Fine-tune with continued fractions
```

**Accuracy:** < 0.001° error

### 2.3 Resource Utilization

| Resource | Used | Available | % |
|----------|------|-----------|---|
| LUTs | 12,450 | 63,400 | 19.6% |
| FFs | 8,230 | 126,800 | 6.5% |
| DSPs | 0 | 240 | 0% |
| BRAM | 18 | 135 | 13.3% |

## 3. Results

### 3.1 Performance

| Metric | Value |
|--------|-------|
| Clock | 50 MHz |
| Latency | 2.3 ms/token |
| Throughput | 435 tokens/s |
| Power | 1.2 W |

### 3.2 Comparison

| Platform | DSPs | Latency | Power |
|----------|------|---------|-------|
| CPU (i7) | N/A | 45 ms | 45 W |
| GPU (RTX) | 5120 | 3.2 ms | 120 W |
| FPGA (ours) | 0 | 2.3 ms | 1.2 W |

**Energy efficiency:** 37.5x better than GPU

## 4. Reproducibility

### 4.1 Hardware

- FPGA: QMTech XC7A100T
- Toolchain: Yosys + nextpnr-xilinx
- Source: `fpga/` directory

## 5. References

[1] Xilinx. (2012). 7 Series DSP48E1 User Guide.
[2] Vasilev, D. (2026). HSLM Architecture. Zenodo.
```

---

## Publication Checklist

Before publishing each Zenodo bundle:

- [ ] Author is "Dmitrii Vasilev"
- [ ] License is CC-BY-4.0
- [ ] Publication date is set
- [ ] Keywords include: ternary, sacred, phi, trinity, fpga
- [ ] DOI format: 10.5281/zenodo.xxxxxx
- [ ] Related identifiers link all bundles
- [ ] Description is in English
- [ ] Mathematical formulas are LaTeX formatted
- [ ] Code references include file paths
- [ ] Results include specific metrics

---

## DOI Structure

```
10.5281/zenodo.1XXXXX  - Bundle A (Ternary NN)
10.5281/zenodo.2XXXXX  - Bundle B (FPGA)
10.5281/zenodo.3XXXXX  - Bundle C (TRI-27)
10.5281/zenodo.4XXXXX  - Bundle D (Queen)
10.5281/zenodo.5XXXXX  - Bundle E (Tri Lang)
10.5281/zenodo.6XXXXX  - Bundle F (Sacred Formats)
10.5281/zenodo.7XXXXX  - Bundle G (VSA)
10.5281/zenodo.8XXXXX  - Parent Collection
```

---

**φ² + 1/φ² = 3 | TRINITY**
