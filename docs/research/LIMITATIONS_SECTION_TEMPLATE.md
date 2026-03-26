# Limitations Section Template

**For Trinity B001-B007 Scientific Publications**

**Date:** 2026-03-26
**Version:** 1.0.0
**Purpose:** Honest, comprehensive limitations following NeurIPS/ICLR/MLSys standards

---

## Why Limitations Matter

A good limitations section:
1. **Builds trust** — Reviewers appreciate honesty
2. **Guides future work** — Shows what's needed
3. **Prevents criticism** — Acknowledging issues pre-empts reviewer complaints
4. **Demonstrates understanding** — Shows you know your system's boundaries

---

## Template Structure

```markdown
## Limitations

### 1. [Limitation Category]

**Description:** [What is the limitation?]

**Impact:** [How does this affect results/applicability?]

**Current Mitigation:** [What are we doing about it?]

**Future Work:** [What needs to be done?]

### 2. [Limitation Category]
[Repeat for each limitation]

### Discussion

[Summary of how limitations interact and overall assessment]
```

---

## B001: HSLM Limitations

### 1. Scale

**Description:** 1.95M parameters is small by 2026 standards. State-of-the-art LLMs use 1B-100B parameters.

**Impact:**
- Performance saturates on complex tasks
- Cannot compare directly with large models
- Limited representational capacity

**Current Mitigation:**
- Focus on edge deployment (where small models are needed)
- Demonstrate competitive PPL on TinyStories
- Open-source for community scaling efforts

**Future Work:**
- Scaling to 10M, 100M parameters
- Investigating sacred scaling at scale
- Distributed training infrastructure

---

### 2. Training Data

**Description:** Single dataset (SlimPajama) used for all experiments. No multi-dataset training.

**Impact:**
- Unknown cross-domain performance
- Potential dataset-specific biases
- Limited generalization claims

**Current Mitigation:**
- Explicitly state single-dataset limitation
- Use large, diverse dataset (300B tokens)
- Ablation studies on data subsets

**Future Work:**
- Multi-dataset training (C4, Wikipedia, code)
- Domain adaptation studies
- Cross-domain evaluation

---

### 3. Evaluation Benchmarks

**Description:** Only CodeArena benchmark used for evaluation. Limited assessment of capabilities.

**Impact:**
- Unknown performance on other tasks
- Cannot claim general superiority
- Potential benchmark overfitting

**Current Mitigation:**
- CodeArena is diverse (multiple languages)
- Report statistical significance
- Ablation studies show component contributions

**Future Work:**
- Multi-benchmark evaluation (MMLU, BIG-Bench)
- Task-specific fine-tuning
- Human evaluation

---

### 4. Hardware: CPU Training Only

**Description:** All training done on CPU (Apple M1 Max). No GPU acceleration.

**Impact:**
- Slower training (~2 weeks for 30K steps)
- Cannot scale to larger models efficiently
- Limited compute for hyperparameter search

**Current Mitigation:**
- CPU path is more accessible (no GPU needed)
- Documented training protocol
- Efficient implementation (850 tok/s inference)

**Future Work:**
- GPU kernel implementation
- Multi-GPU distributed training
- Comparison with GPU training speed

---

### 5. Theoretical Understanding

**Description:** Sacred scaling (φ⁻³ exponent) is partially empirical. Why it works is not fully understood.

**Impact:**
- Risk of being seen as numerology
- Limited generalizability to other architectures
- Potential overfitting to specific model

**Current Mitigation:**
- Statistical validation (p < 0.0001)
- Ablation studies show significance
- Mathematical analysis provided

**Future Work:**
- Theoretical analysis of attention scaling
- Generalization to other architectures
- Optimization of scaling exponent

---

### 6. Ternary Accuracy Loss

**Description:** Ternary quantization introduces accuracy loss vs FP32 (+1.8% PPL in ablation).

**Impact:**
- Not suitable for all applications
- May require hybrid precision
- Accuracy-efficiency tradeoff

**Current Mitigation:**
- Quantize-aware training (STE)
- Hybrid precision option (critical path FP32)
- Report degradation honestly

**Future Work:**
- Adaptive precision (layer-specific)
- Improved quantization methods
- Theoretical accuracy bounds

---

### 7. Consciousness Gate Heuristic

**Description:** Consciousness gate threshold (φ⁻¹ ≈ 0.618) is heuristic. No rigorous derivation.

**Impact:**
- May not be optimal for all tasks
- Limited theoretical grounding
- Risk of being seen as arbitrary

**Current Mitigation:**
- Ablation shows 19.6% improvement
- Threshold based on φ (mathematically motivated)
- Statistical validation provided

**Future Work:**
- Optimal threshold search
- Task-specific adaptation
- Theoretical analysis

---

### Discussion

**Overall Assessment:**
- HSLM demonstrates ternary neural networks are viable
- Limitations are honest and addressable
- Open-source release enables community progress

**Priority for Future Work:**
1. Scale to 10M+ parameters
2. Multi-dataset training
3. GPU acceleration
4. Theoretical analysis

---

## B002: FPGA Limitations

### 1. Single FPGA Platform

**Description:** Only tested on XC7A100T. Unknown performance on other FPGAs.

**Impact:**
- Limited generalizability
- Vendor lock-in (Xilinx)
- Unknown results on Intel/Altera

**Current Mitigation:**
- Use standard Verilog (portable)
- Open-source toolchain (Yosys)
- Document platform requirements

**Future Work:**
- Multi-FPGA testing
- Intel/Altera support
- Automated porting

---

### 2. Clock Frequency

**Description:** 100 MHz is modest. State-of-the-art FPGA accelerators run at 200-400 MHz.

**Impact:**
- Lower throughput vs optimized designs
- Not competitive for high-performance applications
- Limited by timing closure

**Current Mitigation:**
- Focus on efficiency (tok/W)
- Zero-DSP design prioritizes area
- 100 MHz sufficient for edge AI

**Future Work:**
- Timing optimization
- Pipelining for higher frequency
- Comparison at multiple frequencies

---

### 3. No Quantized Training

**Description:** FPGA only supports inference. No on-chip training.

**Impact:**
- Cannot do edge learning
- Requires separate training pipeline
- Limited adaptability

**Current Mitigation:**
- Training is one-time cost
- Focus on inference efficiency
- Checkpoint loading supported

**Future Work:**
- On-chip fine-tuning
- Incremental learning
- Federated learning support

---

### 4. Toolchain Limitations

**Description:** Yosys + nextpnr is less mature than vendor tools.

**Impact:**
- Longer synthesis time
- Suboptimal place-and-route
- Limited optimization

**Current Mitigation:**
- Open-source (accessible)
- Vendor tools supported
- Results still competitive

**Future Work:**
- Vendor toolchain support
- Custom optimization passes
- Synthesis benchmarking

---

## B003: TRI-27 Limitations

### 1. No Hardware Implementation

**Description:** TRI-27 is software-only (VM). No physical hardware.

**Impact:**
- Cannot measure real performance
- Unknown practical feasibility
- Limited to simulation

**Current Mitigation:**
- Complete VM implementation
- Comprehensive testing
- FPGA implementation planned

**Future Work:**
- FPGA soft-core
- ASIC implementation
- Performance benchmarking

---

### 2. Coptic Encoding Niche

**Description:** Coptic alphabet is unfamiliar to most developers.

**Impact:**
- Steep learning curve
- Limited adoption
- Documentation complexity

**Current Mitigation:**
- Complete mapping tables
- Assembly macros
- Interactive tutorials

**Future Work:**
- Alternative encodings
- Tool support (syntax highlighting)
- Educational materials

---

### 3. Limited Ecosystem

**Description:** No compilers, debuggers, or IDEs for TRI-27.

**Impact:**
- Difficult development
- Limited tooling
- Slower iteration

**Current Mitigation:**
- Basic assembler/disassembler
- Zig-based toolchain
- Documentation

**Future Work:**
- High-level language
- Debugger support
- IDE integration

---

## B004: Queen Limitations

### 1. Hyperparameter Search Space

**Description:** Limited to predefined search space. May miss optimal configurations.

**Impact:**
- Suboptimal performance
- Limited exploration
- Risk of local optima

**Current Mitigation:**
- SEVO with geometric pruning
- φ-based heuristics
- Episode retrieval

**Future Work:**
- Bayesian optimization
- Continuous space search
- Multi-objective optimization

---

### 2. Episode Quality

**Description:** Episode retrieval depends on Jaccard similarity. May retrieve irrelevant episodes.

**Impact:**
- Suboptimal policy transfer
- Negative transfer
- Slower convergence

**Current Mitigation:**
- Quality classification (4-state)
- Threshold filtering
- Ablation shows 2.36× improvement

**Future Work:**
- Learned similarity metrics
- Negative transfer detection
- Hierarchical episodes

---

### 3. Human-in-the-Loop Required

**Description:** Queen requires human approval for actions. Not fully autonomous.

**Impact:**
- Slower iteration
- Human bottleneck
- Limited scalability

**Current Mitigation:**
- Automated testing
- Policy validation
- Safe deployment

**Future Work:**
- Autonomous mode (sandboxed)
- Multi-agent approval
- Risk quantification

---

## B005: Tri Language Limitations

### 1. Language Maturity

**Description:** Tri is a research language. Not production-ready.

**Impact:**
- Limited ecosystem
- Potential bugs
- Steep learning curve

**Current Mitigation:**
- Comprehensive testing
- Documentation
- Zig fallback (can generate Zig)

**Future Work:**
- Stability improvements
- Standard library
- IDE support

---

### 2. Performance Overhead

**Description:** Generated code may be slower than hand-written Zig.

**Impact:**
- Suboptimal performance
- Larger binary size
- Memory overhead

**Current Mitigation:**
- Benchmarking (6.1× expansion)
- Optimization passes
- Direct Zig option

**Future Work:**
- Optimization improvements
- Profile-guided optimization
- Hand-optimized kernels

---

### 3. Limited Type System

**Description:** Type system is simpler than production languages (no generics, limited modules).

**Impact:**
- Code duplication
- Limited abstraction
- Verbosity

**Current Mitigation:**
- Macro system
- Zig interop
- Clear design goals

**Future Work:**
- Generics
- Modules
- Type inference

---

## B006: Sacred GF16/TF3 Limitations

### 1. Accuracy Tradeoff

**Description:** GF16/TF3 introduce accuracy loss vs FP32.

**Impact:**
- Not suitable for all applications
- May require hybrid precision
- Limited to inference

**Current Mitigation:**
- Quantize-aware training
- Hybrid precision option
- Report degradation honestly

**Future Work:**
- Adaptive precision
- Improved quantization
- Theoretical bounds

---

### 2. φ-Distance Justification

**Description:** φ-distance metric is heuristic. No rigorous proof of optimality.

**Impact:**
- May not be optimal
- Alternative metrics may be better
- Risk of being seen as arbitrary

**Current Mitigation:**
- Empirical validation (2.4× improvement)
- Statistical significance
- Comparison with IEEE 754

**Future Work:**
- Theoretical analysis
- Alternative metrics
- Optimization

---

## B007: VSA Limitations

### 1. Dimensionality

**Description:** VSA requires high-dimensional vectors (1024+). Memory intensive.

**Impact:**
- Larger memory footprint
- Slower operations
- Limited scalability

**Current Mitigation:**
- SIMD acceleration (17.2×)
- Efficient storage
- Dimensionality studies

**Future Work:**
- Adaptive dimensionality
- Sparse representations
- Compression

---

### 2. Approximate Operations

**Description:** VSA operations are approximate (probabilistic). Not exact.

**Impact:**
- Errors accumulate
- Limited precision
- Not suitable for all applications

**Current Mitigation:**
- Error analysis
- Robust algorithms
- Hybrid exact/approximate

**Future Work:**
- Error bounds
- Exact VSA variants
- Precision control

---

## Cross-Cutting Limitations

### 1. Mathematical Foundation

**Description:** Trinity identity (φ² + φ⁻² = 3) is empirically validated but not fully understood theoretically.

**Impact:**
- Risk of being dismissed as numerology
- Limited generalizability
- Potential overfitting

**Current Mitigation:**
- Statistical validation
- Ablation studies
- Open-source release

**Future Work:**
- Theoretical analysis
- Generalization studies
- Alternative foundations

---

### 2. Evaluation Scope

**Description:** Limited evaluation on benchmarks. Unknown real-world performance.

**Impact:**
- Limited claims
- Potential overfitting
- Unknown applicability

**Current Mitigation:**
- Statistical significance
- Multiple baselines
- Honest reporting

**Future Work:**
- Real-world deployment
- User studies
- Production evaluation

---

### 3. Reproducibility Resources

**Description:** Full training requires significant compute (2 weeks on M1 Max).

**Impact:**
- Limited reproducibility
- Barrier to entry
- Verification difficulty

**Current Mitigation:**
- Checkpoints released
- Inference-only path
- CPU training documented

**Future Work:**
- Cloud-based reproduction
- Reduced training protocols
- Community benchmarks

---

## Writing Guidelines

### DO's

✅ Be specific and concrete
✅ Quantify impacts when possible
✅ Provide current mitigations
✅ Suggest concrete future work
✅ Acknowledge limitations early (don't hide them)
✅ Use "we" language (take responsibility)

### DON'Ts

❌ Be defensive ("this is not a problem because...")
❌ Minimize limitations ("this is minor...")
❌ Blame others ("prior work has this issue too...")
❌ Ignore reviewer-likely limitations
❌ Use vague language ("some limitations exist...")

---

## Template for Copy-Paste

```markdown
## Limitations

Our work has several limitations that future work should address.

**Scale.** Our 1.95M parameter model is small by current standards. While
sufficient for our target applications (edge deployment), it limits our
ability to compare with state-of-the-art 1B+ parameter models. Future work
should explore sacred scaling at larger scales.

**Evaluation Scope.** We evaluate on a single benchmark (CodeArena). While
our ablation studies show statistical significance (p < 0.0001), broader
evaluation across multiple benchmarks would strengthen our claims. We are
actively working on MMLU and BIG-Bench evaluation.

**Training Data.** All training uses SlimPajama, a single dataset. This
limits our claims about cross-domain performance. Future work should explore
multi-dataset training and domain adaptation.

**Hardware.** All training was performed on CPU (Apple M1 Max). While this
improves accessibility, GPU acceleration would significantly reduce training
time. We are working on GPU kernels for future releases.

**Theoretical Understanding.** The choice of φ⁻³ for attention scaling is
partially empirical. While statistically validated, a rigorous theoretical
explanation remains open work. We encourage the community to explore the
mathematical foundations of sacred scaling.

Despite these limitations, our work demonstrates that ternary neural networks
are a viable path toward efficient edge AI. All code, checkpoints, and
documentation are released under open licenses to enable community progress.
```

---

## Summary Checklist

Before submitting:

- [ ] 5-7 limitations acknowledged
- [ ] Each limitation has: description, impact, mitigation, future work
- [ ] Cross-cutting limitations included
- [ ] No defensive language
- [ ] Specific and concrete
- [ ] Quantified when possible
- [ ] Honest assessment
- [ ] Future work is actionable

---

**φ² + 1/φ² = 3 | TRINITY**
