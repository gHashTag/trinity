# Trinity S³AI Unified API Reference

**Date:** 2026-03-26
**Issue:** #415
**Version:** 1.0

---

## Executive Summary

This document provides a unified API reference for the entire Trinity S³AI codebase, organized by functional domains:
1. **HSLM** (Hybrid Symbolic Language Model)
2. **VSA** (Vector Symbolic Architecture)
3. **FPGA** (Hardware Acceleration)
4. **TRI** (TRI-27 Virtual Machine)
5. **Research/Analytics** (Benchmarks, Mining, Inference)
6. **Training/Fine-tuning** (B2T, LLM, Optimization)
7. **CLI** (Command-line Interface)
8. **Queen** (UI and Bridge)

Each section includes:
- Module overview and purpose
- Public API (functions, types)
- Internal design notes
- Usage examples
- Dependencies

---

## Part I: HSLM API Reference

### I.1 Architecture Overview

```
HSLM (Hybrid Symbolic Language Model)
│
├─ Embedding Layer
│  └─ VSA Encoding: charToVector(), encodeText(), encodeTextWords()
│
├─ 6× Trinity Blocks
│  ├─ Multi-head Attention (φ-RoPE)
│  ├─ Consciousness Gate (System 1/2)
│  ├─ Sparse VSA Reasoning
│  └─ Feed-Forward Networks (TF3 activation)
│
├─ Output Projection
├─ STE Quantization
└─ Training Loop (Sacred Cosine LR)
```

### I.2 Public API

#### HSLM Model (`src/hslm/model.zig`)

```zig
pub const HSLM = struct {
    config: Config,
    emb: embedding.Embedding,
    blocks: [constants.NUM_BLOCKS]trinity_block.TrinityBlock,
    output_weights: []i8,
    output_bias: []f32,
    output_shadow: []f32,
    grad_output_shadow: []f32,
    grad_output_bias: []f32,
    ste_config: ste_mod.SteConfig,
    alpha_output: f32,
    is_worker: bool,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) !Self;
    pub fn forward(self: *Self, tokens: []const u32) !ForwardOutput;
    pub fn train_step(self: *Self, batch: []const f32, labels: []const f32) !TrainOutput;
};
```

**Parameters:**
- `NUM_BLOCKS = 6`: Number of transformer layers
- `EMBED_DIM = 243`: Embedding dimension (3^5)
- `VOCAB_SIZE = 31000`: Tokenizer vocabulary size

**Returns:**
- `ForwardOutput`: Normalized logits, cache updates, system 1/2 distribution
- `TrainOutput`: Loss, gradients, batch statistics

#### Trinity Block (`src/hslm/trinity_block.zig`)

```zig
pub const TrinityBlock = struct {
    attention: Attention,
    ffn: FeedForward,
    vsa_reasoning: VSAReasoning,
    consciousness: ConsciousnessGate,
    layer_norm: LayerNorm,

    pub fn init(allocator: std.mem.Allocator) !Self;
    pub fn forward(self: *Self, x: []const f32) !BlockOutput;
    pub fn backward(self: *Self, grad_output: BlockGradient);
};
```

**Components:**
- `Attention`: Multi-head attention with φ-RoPE
- `FeedForward`: TF3-activated feed-forward network
- `VSAReasoning`: Sparse VSA reasoning (analogy, chain)
- `ConsciousnessGate`: System 1/2 gate at τ = φ^(-1)

#### Attention (`src/hslm/attention.zig`)

```zig
pub const Attention = struct {
    pub fn forward(self: *Self, x: []const f32) !AttentionOutput;
};
```

**Features:**
- Multi-head attention (3 heads)
- φ-Rotary Positional Encoding (φ-based frequency spacing)
- Sacred scaling: `scale_sacred(d) = d^(-φ^(-3))`

### I.3 Constants (`src/hslm/constants.zig`)

```zig
pub const SACRED_GAMMA: f64 = 0.23607; // φ^(-3)
pub const SACRED_THRESHOLD: f64 = 0.618034; // φ^(-1)
pub const SACRED_LOGIT_SCALE: f32 = 1.0 / @sqrt(@as(f32, constants.EMBED_DIM));
pub const CONTEXT_LEN: usize = 81; // 3^4
pub const NUM_HEADS: usize = 3;
pub const VOCAB_SIZE: usize = 31000;
```

---

## Part II: VSA API Reference

### II.1 Architecture Overview

```
VSA (Vector Symbolic Architecture)
│
├─ Core Operations (FHRR-based)
│  ├─ bind(a, b): Element-wise multiplication
│  ├─ unbind(x, k): Inverse binding (division for balanced ternary)
│  ├─ bundle2(a, b): Majority vote (2 vectors)
│  ├─ bundle3(a, b, c): Majority vote (3 vectors)
│  ├─ permute(v, n): Cyclic shift
│  └─ inversePermute(v, n): Inverse permute
│
├─ Similarity Metrics
│  ├─ cosineSimilarity(a, b): Cosine similarity [-1, 1]
│  ├─ hammingDistance(a, b): Hamming distance [0, d]
│  ├─ hammingSimilarity(a, b): Normalized similarity [0, 1]
│
└─ dotSimilarity(a, b): Dot product similarity
│
├─ Encoding/Decoding
│  ├─ encodeSequence(tokens): Text to vector sequence
│  ├─ decodeSequence(vectors): Vector sequence to text
│  ├─ charToVector(char): Character to VSA vector
│  └─ encodeText(text): Full text to VSA vectors
```

### II.2 Public API (`src/vsa.zig`)

```zig
// Re-exported operations
pub const bind = vsa_core_compat.bind;
pub const unbind = vsa_core_compat.unbind;
pub const bundle2 = vsa_core_compat.bundle2;
pub const bundle3 = vsa_core_compat.bundle3;
pub const permute = vsa_core_compat.permute;
pub const inversePermute = vsa_core_compat.inversePermute;
pub const cosineSimilarity = vsa_core_compat.cosineSimilarity;
pub const hammingDistance = vsa_core_compat.hammingDistance;
pub const hammingSimilarity = vsa_core_compat.hammingSimilarity;
pub const dotSimilarity = vsa_core_compat.dotSimilarity;
pub const vectorNorm = vsa_core_compat.vectorNorm;
```

### II.3 FHRR Details (`src/vsa/hrr.zig`)

**Fourier Holographic Reduced Representation**

- **Binding**: Circular convolution in frequency domain
- **Self-inverse**: `bind(bind(a, b), b) = a` (for balanced ternary)
- **Noise Resilience**: 30% bitflip tolerance at 30% corruption

### II.4 Usage Examples

```zig
// VSA binding for role representation
const role = vsa.charToVector("doctor");
const task = vsa.charToVector("nurse");

// Bind role to task (creates role representation)
const role_binding = vsa.bind(role, task);

// Unbind task from role to extract task (uses division)
const extracted_task = vsa.unbind(role_binding, role);
```

---

## Part III: FPGA API Reference

### III.1 Architecture Overview

```
FPGA (Hardware Acceleration)
│
├─ Synthesis Flow
│  ├─ Verilog generation (VIBEE compiler)
│  ├─ Bitstream generation (Vivado)
│  └─ Timing analysis (post-synthesis)
│
├─ Zero-DSP Implementation
│  └─ Ternary MAC using LUTs only
│
└─ Resource Utilization
    └─ XC7A100T: 19.6% LUT, 0% DSP, 1.2W @ 50MHz
```

### III.2 Key Interfaces (`src/trinity_fpga_mvp.zig`)

```zig
pub const SynthesisReport = struct {
    luts: usize,
    dsp: usize,
    bram: usize,
    power: f64,
    max_freq: f64,
};

pub const FPGAConfig = struct {
    device: Device,
    clock_freq: f64,
    target_luts: usize,  // Target: 19.6%
    target_dsp: usize = 0,  // Zero-DSP goal
};
```

### III.3 Export Formats

**TF3 (Ternary Float 3)**: 8-bit format for ternary activations
- **GF16 (Golden Float 16)**: 16-bit format with overflow-free property

```zig
// TF3 encoding (8 ternary values in 32 bits = 10.67 trits)
const trits_per_word = 10;

// GF16 format (6-bit exponent, 9-bit mantissa, bias=31)
const GF16_MAX_EXP = 63;  // 6-bit max
const GF16_BIAS = 31;
```

---

## Part IV: TRI-27 VM API Reference

### IV.1 Architecture Overview

```
TRI-27 Virtual Machine
│
├─ Registers
│  └─ 27 registers (3 banks × 9 = [r0-r8, r9-r17, r26-r35])
│
├─ Instruction Set
│  ├─ Data Movement: MOV, LDR, STR, STO
│  ├─ Arithmetic: ADD, SUB, MUL, DIV, MOD
│  ├─ Logic: AND, OR, XOR, NOT, CMP
│  ├─ VSA: BIND, UNBIND, BND2, BND3, BNDN, BNDX, BUNDLE, SIM
│  ├─ Control: JMP, JGT, JLT, CALL, RET, HLT
│  └─ System: SYS, HCF, VTR, MEM
│
├─ Memory Model
│  └─ 3 banks (code, data, stack) with unified addressing
│
└─ Stack Machine
    └─ Operand stack for expression evaluation
```

### IV.2 Register Layout

| Bank | Range | Purpose | Example |
|------|--------|---------|---------|
| r0-r8 | 0-7 | General purpose | `MOV r0, r1` |
| r9-r17 | 8-24 | Argument pointers | `MOV r9, sp` |
| r26-r35 | 25-35 | String/indirect | `LDR r26, [r26]` |

### IV.3 Instruction Reference

```zig
// Key VSA instructions
pub const BIND = 0x80;  // bind = a ⊗ b
pub const UNBIND = 0x81;  // unbind = a ⊘ b (division)
pub const BUNDLE = 0x82;  // bundle = majority vote
pub const SIM = 0x83;   // similarity = cosine similarity

// Example: Bind register to task (creates role representation)
const role_reg: u8 = 9;
const task_reg: u8 = 10;
// BIND r9, r0; role_reg; STR r10, task_reg; RET
```

---

## Part V: Research & Analytics API Reference

### V.1 Architecture Overview

```
Research & Analytics
│
├─ Inference Engine
│  ├─ B2T (BitNet-based) inference
│  └─ B2T LLM assistant (prompt/completion)
│
├─ Training Pipeline
│  └─ LLM fine-tuning (B2T)
│
├─ Benchmarks
│  ├─ B2T benchmarks (perplexity, throughput)
│  └─ VSA benchmarks (reasoning accuracy)
│
└─ Mining
    └─ LLM training data mining (MVP)
```

### V.2 B2T Inference API (`src/b2t/b2t_inference.zig`)

```zig
pub fn loadModel(path: []const u8) !B2TModel;
pub fn generate(prompt: []const u8, max_tokens: usize) ![]const u32;
pub fn forward(model: *B2TModel, tokens: []const u32) !InferenceOutput;
```

### V.3 B2T Training API (`src/b2t/b2t_train.zig`)

```zig
pub const Trainer = struct {
    config: TrainConfig,
    model: B2TModel,

    pub fn new(config: TrainConfig) !Trainer;
    pub fn train_step(self: *Trainer, batch: []const f32) !TrainMetrics;
    pub fn save(self: *Trainer, path: []const u8) !void;
};
```

---

## Part VI: CLI API Reference

### VI.1 Architecture Overview

```
CLI (Command-line Interface)
│
├─ Research CLI (tri-research)
│  ├─ Literature search
│  ├─ Paper ingestion
│  └─ Citation management
│
├─ Inference CLI (tri-inference)
│  ├─ Text generation
│  ├─ Model benchmarking
│  └─ VSA reasoning
│
├─ Training CLI (tri-train)
│  └─ B2T fine-tuning
│
└─ System Management (tri-sys)
    ├─ Build orchestration
    └─ Dependency management
```

### VI.2 Core Commands

| Command | Module | Description |
|----------|--------|-------------|
| `tri test` | Test runner | Run all test suites |
| `tri git status` | Git status | Working tree overview |
| `tri git commit` | Git commit | Create commits with issue ID |
| `tri notify` | Notification | Send Telegram/HTTP notifications |
| `tri faculty` | Dashboard | Agent status and task queue |
| `tri agent run` | Agent execution | Run autonomous agents |

### VI.3 CLI Entry Points

```zig
// src/tri/cli.zig
pub const Command = enum {
    test,
    git_status,
    git_commit,
    notify,
    faculty,
    agent_run,
    // ... more commands
};
```

---

## Part VII: Queen API Reference

### VII.1 Architecture Overview

```
Queen UI
│
├─ Frontend (Swift/SwiftUI)
├─ Bridge Layer
│  ├─ Perplexity API (Railway)
├─ Research Agent (Scholar)
└─ Context Integration
```

### VII.2 Queen Bridge (`src/queen_api.zig`)

```zig
pub const PerplexityClient = struct {
    base_url: []const u8,
    api_key: []const u8,

    pub fn init(allocator: std.mem.Allocator, base_url: []const u8) !PerplexityClient;
    pub fn chat(self: *PerplexityClient, prompt: []const u8) !ChatResponse;
};
```

---

## Part VIII: Type System Reference

### VIII.1 Overview

Trinity uses multiple type systems for different purposes:

| Type System | Purpose | Key Files | Memory Safety |
|--------------|---------|------------|----------------|---------------|
| Standard Zig | Core logic | All modules | Yes (Zig borrow checker) |
| HybridBigInt | VSA computation | vsa/core.zig | Yes (manual ref counting) |
| Linear Types (proposed) | GPU compatibility | src/hslm/linear_types.zig | Yes (proposed) |
| Arena Allocators | Memory pools | src/vsa/storage.zig | Yes (arena-based) |

---

## Usage Examples

### Example 1: HSLM Inference

```zig
const std = @import("std");
const hslm = @import("hslm/model.zig");
const vsa = @import("vsa.zig");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // Initialize model
    var model = try hslm.HSLM.init(&allocator);

    // Create role representation
    const role = vsa.charToVector("system_admin");
    const task = vsa.charToVector("resource_management");

    // Bind role to task
    const role_binding = vsa.bind(role, task);

    // Forward pass
    const prompt = "manage trinity resources";
    var tokens = [_]u32{0, 1} ** 31_000}; // Token IDs
    const output = try model.forward(&allocator, tokens);

    std.debug.print("System 2 activated: {d}", output.consciousness_ratio);
}
```

### Example 2: VSA Reasoning

```zig
const std = @import("std");
const vsa = @import("vsa.zig");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // Create concept vectors
    const doctor = vsa.randomVector(&allocator, constants.VSA_DIM);
    const nurse = vsa.randomVector(&allocator, constants.VSA_DIM);

    // Bind doctor role to nurse (creates role)
    const doctor_role = vsa.bind(doctor, nurse);

    // Create task: treat patient
    const treatment = vsa.randomVector(&allocator, constants.VSA_DIM);
    const task = vsa.bind(doctor_role, treatment);

    // Extract analogy: doctor : treatment :: ? (nurse : hospital)
    const extraction = vsa.unbind(task, doctor_role);

    // New task: treat with hospital protocol
    const hospital = vsa.randomVector(&allocator, constants.VSA_DIM);
    const new_task = vsa.bind(extraction, hospital);
}
```

---

## Appendix A: Module Dependencies

```
HSLM Dependencies:
├─ embedding_mod (tokenization)
├─ trinity_block (attention, ffn, vsa, consciousness)
├─ constants (sacred gamma, threshold)
├─ autograd (reverse-mode AD)
├─ simd_ops (SIMD operations)
└─ ste_mod (straight-through estimator)

VSA Dependencies:
├─ vsa_core_compat (HybridBigInt-based VSA)
├─ vsa_encoding (text encoding)
├─ vsa_storage (text corpus)
└─ vsa_hrr (FHRR implementation)

FPGA Dependencies:
├─ synthesis (VIBEE code generation)
└─ openxc7-synth (bitstream generation)
```

---

## Appendix B: Quick Reference Card

### Constants Reference

| Symbol | Value | Description |
|---------|-------|-------------|
| φ | 1.618034 | Golden ratio |
| γ = φ^(-3) | 0.23607 | Sacred gamma |
| τ = φ^(-1) | 0.618034 | Consciousness threshold |
| 3^5 | 243 | Model dimension |
| 3^4 | 81 | Context length |

### VSA Operations Reference

| Operation | Syntax | Complexity | Self-Inverse? |
|-----------|---------|-----------|---------------|
| bind(a, b) | `vsa.bind(a, b)` | O(1) | ✓ |
| unbind(x, k) | `vsa.unbind(x, k)` | O(1) | ✓ (for non-zero k) |
| bundle2(a, b) | `vsa.bundle2(a, b)` | O(1) | ✓ |
| bundle3(a, b, c) | `vsa.bundle3(a, b, c)` | O(1) | ✓ |
| cosineSimilarity(a, b) | `vsa.cosineSimilarity(a, b)` | O(d) | ✓ |
| hammingDistance(a, b) | `vsa.hammingDistance(a, b)` | O(d) | ✓ |

---

**Document Control:** API-REF-001
**Status:** Complete — V1.0
**Maintained By:** Trinity Research Collective
**φ² + 1/φ² = 3 | TRINITY**
