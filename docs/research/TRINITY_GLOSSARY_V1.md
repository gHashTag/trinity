# Trinity S³AI Glossary v1.0
## Terminology, Concepts, and Definitions

**Maintained**: Trinity S³AI Research  
**Last Updated**: 2026-03-26  
**License**: CC-BY-4.0

---

## A

### Adaptive Scaling
Dynamic adjustment of attention scale during training, transitioning from sacred scaling (0.354) to standard scaling (0.111) via cosine annealing.

**See**: `docs/research/SACRED_SCALING_MATHEMATICAL_ANALYSIS_V2.md`

### Alpha (α)
Scaling factor in Ternary Weight Networks (TWN), applied after quantization to preserve gradient information.

**Formula**: `output = α · W_ternary · x`

---

## B

### Balanced Ternary
Number system using three symmetric values: {-1, 0, +1}. More efficient than binary for certain computations.

**Information**: log₂(3) ≈ 1.585 bits/trit

### Bind Operation
VSA operation for associating two hypervectors. Implemented as component-wise multiplication.

**Properties**: Associative, commutative, self-inverse (for non-zero values)

**Code**: `src/vsa/core.zig:bind()`

### Bundle Operation
VSA operation for combining multiple hypervectors via majority vote.

**Properties**: Associative, commutative, idempotent

**Code**: `src/vsa/core.zig:bundle2()`, `bundle3()`

---

## C

### Coptic Alphabet
27-letter alphabet used in TRI-27 ISA. Each letter corresponds to a register or operation.

**See**: `docs/research/ALPHABET_CANON_27.md`

### Cosine Similarity
Similarity metric for hypervectors in range [-1, 1].

**Formula**: `sim(a, b) = (a · b) / (||a|| · ||b||)`

### CONTEXT_LEN
Maximum sequence length for HSLM. Set to 81 = 3⁴.

---

## D

### DePIN (Decentralized Physical Infrastructure Network)
Trinity's tokenomics and node architecture for distributed AI computing.

**Code**: `src/trinity_node/`

### Dot Similarity
Raw dot product of two hypervectors, range [-n, n] for n-dimensional vectors.

**Code**: `src/vsa_core/gen_ops.zig:dotSimilarity()`

---

## E

### EMBED_DIM
Embedding dimension for HSLM. Set to 243 = 3⁵.

**Relation**: `NUM_HEADS × HEAD_DIM = 3 × 81 = 243`

### EMA (Exponential Moving Average)
Smoothing technique for tracking statistics in training.

**Formula**: `y_t = α · x_t + (1 - α) · y_{t-1}`

**Code**: `src/hslm/ema.zig`

---

## F

### φ (Phi)
Golden ratio, fundamental constant in Trinity mathematics.

**Value**: φ = (1 + √5) / 2 ≈ 1.618033988749895

**Properties**: φ² = φ + 1, 1/φ = φ - 1

### φ-RoPE (Phi Rotary Position Encoding)
Rotary position encoding using golden-ratio frequencies for positional awareness.

**Code**: `src/hslm/sacred_attention.zig:applyRoPE()`

### FP16 / BF16 / GF16
Floating-point formats:
- **FP16**: 5-bit exp, 10-bit mantissa
- **BF16**: 8-bit exp, 7-bit mantissa
- **GF16**: 6-bit exp, 9-bit mantissa (sacred format)

### Frobenius Endomorphism
Category-theoretic concept related to the Trinity Identity.

**See**: `docs/research/THEORETICAL_FRAMEWORK_V6.md`

---

## G

### GF16 (Golden Format 16)
Custom floating-point format with φ-based distance metric.

**Spec**: 1-bit sign, 6-bit exp, 9-bit mantissa

**Advantage**: 37.8% fewer LUTs on FPGA vs FP16

### GOLDEN_CHAIN
Trinity's code generation pipeline from .tri specs to Zig/Verilog.

**Code**: `src/storm/golden_chain.zig`

---

## H

### Hamming Distance
Number of positions at which corresponding trits differ.

**Range**: [0, n] for n-dimensional vectors

### HEAD_DIM
Per-head attention dimension. Set to 81 = 3⁴.

**Relation**: `EMBED_DIM / NUM_HEADS = 243 / 3 = 81`

### HSLM (Hybrid Symbolic Language Model)
1.95M parameter ternary language model with sacred scaling.

**PPL**: 12.5 on TinyStories
**Memory**: 386 KB (20× compression vs FP32)

### Hypervector
High-dimensional vector (typically 1024+ dimensions) representing symbols in VSA.

**Type**: {-1, 0, +1}^n for ternary VSA

---

## I

### Inverse Permute
VSA operation to reverse a permutation.

**Property**: `inversePermute(permute(v, n), n) = v`

**Code**: `src/vsa_core/gen_ops.zig:inversePermute()`

---

## L

### LOG2_3
Information content of a trit in bits.

**Value**: log₂(3) ≈ 1.5849625

**Use**: Memory efficiency calculations

---

## M

### Majority Vote
Operation combining multiple values by selecting the most common value.

**In VSA**: `bundle2(a, b) = sign(a + b)` (with zero as tiebreaker)

### MONAD
Functional programming pattern used in Tri Language for effect management.

**Code**: `src/tri-lang/effects.zig`

---

## N

### NUM_HEADS
Number of attention heads in HSLM. Set to 3 (Trinity).

### NUM_BLOCKS
Number of transformer blocks. Default is 3, maximum is 9.

**Validation**: `isValidBlockCount()` checks power of 3

---

## O

### One-Hot Encoding
Encoding scheme where only one bit is set. Generalized to "one-cold" for ternary.

---

## P

### Permute Operation
VSA operation for cyclic rotation of hypervectors.

**Implementation**: Rotate by n positions modulo length.

**Code**: `src/vsa_core/gen_ops.zig:permute()`

### PHI_INV (φ⁻¹)
Inverse of golden ratio, equal to φ - 1.

**Value**: φ⁻¹ ≈ 0.618033988749895

### PHI_INV_CUBED (φ⁻³)
Sacred gamma, used as attention scale exponent.

**Value**: φ⁻³ ≈ 0.23606797749979

**Use**: `S = 1/d^φ⁻³` for sacred attention scaling

### PHI_SQ (φ²)
Square of golden ratio, equal to φ + 1.

**Value**: φ² ≈ 2.618033988749895

---

## Q

### Q, K, V (Query, Key, Value)
Standard attention mechanism components.

**In HSLM**: Ternary weights, float32 activations

---

## R

### Random Vector
Hypervector with randomly generated trits, used as symbol representation.

**Generation**: `randomVector(allocator, dimension, seed)`

**Code**: `src/vsa_core/gen_ops.zig:randomVector()`

### RoPE (Rotary Position Encoding)
Position encoding scheme using rotation matrices.

**Variant**: φ-RoPE uses golden-ratio frequencies

---

## S

### SACRED_ATTN_SCALE
Attention scaling factor using sacred gamma.

**Value**: 1/81^φ⁻³ ≈ 0.354

**vs Standard**: 3.18× larger than 1/√81 ≈ 0.111

### SACRED_GAMMA
Alias for PHI_INV_CUBED (φ⁻³ ≈ 0.236).

### Search Result
Data structure returned by VSA similarity search.

**Fields**: `index: usize`, `similarity: f64`

**Code**: `src/vsa_core/common.zig:SearchResult`

### SIMD_WIDTH
Number of elements in SIMD vector operations.

**Value**: 32 (for ARM64 NEON i8 vectors)

---

## T

### TF3 (Ternary Folding Format)
Compact storage format for 8 ternary weights in 32 bits.

**Structure**: 16-bit scale + 16-bit weights (2 bits each)

**Efficiency**: 1.58 bits/weight (vs 32 bits for FP32)

### Ternary
Three-valued system: {-1, 0, +1}.

**Advantages**: Natural sparsity, efficient computation

### Ternary MAC
Multiply-accumulate operation with ternary weights.

**FPGA**: Zero DSP required, 3 LUT per weight

### Trit
Single ternary digit (-1, 0, or +1).

**Storage**: 5 trits per byte (packed encoding)

### TRINITY_CONST
The value 3, representing φ² + 1/φ².

**Significance**: Fundamental identity underlying ternary computing

### TRI-27
Ternary instruction set architecture with 27 registers (3 banks × 9).

**Code**: `src/tri27/emu/`

### Trit27
Extended trit type with 27 values for TRI-27 operations.

**Code**: `src/temple/sacred_math.zig`

---

## V

### VSA (Vector Symbolic Architecture)
Computational paradigm using high-dimensional random vectors for symbolic reasoning.

**Operations**: bind, unbind, bundle, permute, similarity

**Code**: `src/vsa/`, `src/vsa_core/`

### VOCAB_SIZE
Vocabulary size for HSLM tokenization.

**Value**: 729 = 3⁶

---

## Z

### Zero-DSP
FPGA design using no DSP blocks, only LUTs for ternary computation.

**Achievement**: HSLM achieves 70 tok/s @ 0.5W with 0 DSP

---

## Acronyms Summary

| Acronym | Full Name | Context |
|---------|-----------|---------|
| API | Application Programming Interface | General |
| BSDM | Binary Sparsed Distributed Memory | VSA |
| CPU | Central Processing Unit | Hardware |
| DSL | Domain-Specific Language | Tri Language |
| FPGA | Field-Programmable Gate Array | Hardware |
| GF16 | Golden Format 16 | Floating-point |
| GPU | Graphics Processing Unit | Hardware |
| HSLM | Hybrid Symbolic Language Model | Model |
| ISA | Instruction Set Architecture | TRI-27 |
| LUT | Look-Up Table | FPGA resource |
| MAC | Multiply-Accumulate | Operation |
| NEON | ARM SIMD architecture | Hardware |
| PPL | Perplexity | Metric |
| RAM | Random Access Memory | Hardware |
| RMS | Root Mean Square | Normalization |
| RoPE | Rotary Position Encoding | Attention |
| SIMD | Single Instruction Multiple Data | Parallelism |
| STE | Straight-Through Estimator | Training |
| TF3 | Ternary Folding Format (3) | Storage |
| TNN | Ternary Neural Network | Architecture |
| TRIT | Token Ring Interface Trinity | Tokenomics |
| TWN | Ternary Weight Networks | Quantization |
| VSA | Vector Symbolic Architecture | Paradigm |

---

## Mathematical Symbols

| Symbol | Name | Value | Context |
|--------|------|-------|---------|
| φ | Golden ratio | ≈1.618 | Sacred math |
| φ⁻¹ | Inverse golden ratio | ≈0.618 | Sacred math |
| φ² | Phi squared | ≈2.618 | Sacred math |
| φ⁻² | Phi inverse squared | ≈0.382 | Sacred math |
| φ⁻³ | Phi inverse cubed | ≈0.236 | Sacred gamma |
| γ | Sacred gamma | φ⁻³ | Scaling exponent |
| ⊗ | Tensor product / bind | — | Category theory |
| ⊕ | Direct sum / bundle | — | Category theory |

---

## File Locations

| Component | Path | Description |
|-----------|------|-------------|
| VSA Core | `src/vsa_core/` | Core VSA operations |
| VSA Extended | `src/vsa/` | Higher-level VSA |
| HSLM | `src/hslm/` | Language model |
| TRI-27 | `src/tri27/` | ISA emulator |
| Temple | `src/temple/` | Sacred math layer |
| Tri Lang | `src/tri-lang/` | Compiler |
| Research | `docs/research/` | Documentation |

---

**φ² + 1/φ² = 3 | TRINITY**
