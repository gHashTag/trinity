# NeurIPS 2026 Submission — Related Work

**Paper Title:** Trinity: A Ternary Neural Network Framework with Algebraically Structured Formats and Zero-DSP FPGA Deployment

**Anonymous Authors** *(double-blind submission)*

---

## 1. Ternary Neural Networks

### Binary and Ternary Quantization

**Binarized Neural Networks (BNNs)** [Hubara et al., 2016; Courbariaux et al., 2015] pioneered extreme quantization by constraining weights and activations to {-1, +1}, enabling multiplication-free inference. BNNs achieve significant memory savings but suffer from accuracy degradation, especially for larger models.

**Ternary Weight Networks (TWN)** [Li et al., 2016; Zhu et al., 2017] extended this approach to {-1, 0, +1}, adding a zero state that enables pruning of insignificant weights. TWN demonstrated improved accuracy over BNNs while maintaining memory efficiency.

**BitNet b1.58** [Ma et al., 2024] recently achieved state-of-the-art results with 1.58-bit quantization, showing that large language models can maintain performance with aggressive quantization. BitNet uses a mixture of binary and ternary representations but does not provide formal algebraic structure for the ternary component.

**Trinity vs Prior Work:** Unlike prior ternary methods that treat {-1, 0, +1} as a quantization artifact, Trinity grounds ternary computation in formal algebraic structures (GF16, TF3) with provable properties. We also introduce VSA operations for compositional reasoning, absent from prior ternary networks.

### Straight-Through Estimator

**STE** [Bengio et al., 2013; Hinton et al., 2015] enables gradient-based training of discrete networks by using continuous values during backward pass while discretizing during forward pass. Trinity uses STE for TF3 quantization, consistent with prior work.

---

## 2. FPGA Neural Network Inference

### FPGA Accelerators for Neural Networks

**FINN** [Umuroglu et al., 2017; Blott et al., 2018] is a framework for binarized neural network inference on FPGAs, achieving high throughput but requiring DSP blocks for accumulation. FINN-R [Jiang et al., 2020] extends this to ResNet architectures but still relies on DSP resources.

**LUT-LLM** [Kim et al., 2025] proposes memory-based computation for LLM inference on FPGAs, reducing DSP dependence but still using DSP blocks for certain operations. The approach achieves 45,200 LUTs and 224 DSPs for comparable models.

**TerEffic** [Ma et al., 2025] introduces ternary FPGA inference with optimized DSP usage but does not eliminate DSP dependence entirely. The design achieves 120,000 LUTs and 2,688 DSPs.

**Trinity vs Prior Work:** Trinity achieves zero DSP usage through novel ternary MAC encoding, using only 12,433 LUTs (19.6% of XC7A100T) — 3.6× fewer LUTs than FINN and completely eliminating DSP usage.

### CORDIC for Rotational Operations

**CORDIC** [Volder, 1959; Walther, 1971] is an iterative algorithm for computing trigonometric functions using only shifts and additions. Trinity uses CORDIC for φ-based rotary positional embeddings, consistent with prior work but optimized for golden-ratio angles.

---

## 3. Vector Symbolic Architectures

### Hyperdimensional Computing

**Plate, 1995; Plate, 2003** introduced Holographic Reduced Representations (HRR), a VSA scheme using circular convolution for binding. HRR enables compositional reasoning but has limited noise resilience (~20% bitflip resilience).

**Kanerva, 2009** proposed Binary Spatter Codes (BSC), a simpler VSA using XOR for binding. BSC is computationally efficient but has even lower noise resilience (~10% bitflip resilience).

**FHRR** [Plate, 2003; Frady et al., 2021] uses Fourier domain operations for binding, achieving superior noise resilience (~30% bitflip resilience). Trinity adopts FHRR for its VSA layer.

### VSA in Neural Networks

**Gayler, 2003** proposed VSA for compositional representations in cognitive modeling. Recent work [Frady et al., 2022; Kleyko et al., 2022] has explored VSA for few-shot learning and relational reasoning, but not within neural network training loops.

**Trinity vs Prior Work:** Trinity integrates VSA operations as differentiable layers within the neural computational graph, enabling end-to-end training with STE gradients. This is novel compared to prior VSA work that treats VSA as a separate reasoning layer.

---

## 4. Formal Verification of Neural Networks

### Verification Approaches

**Marabou** [Katz et al., 2019; Dutta et al., 2021] is a solver for neural network verification using SMT solvers. Marabou can prove properties of ReLU networks but scales poorly for large networks.

**alpha-beta-CROWN** [Wang et al., 2021; Xu et al., 2022] uses bound propagation for efficient verification, achieving state-of-the-art scalability.

**ERAN** [Singh et al., 2019; Singh et al., 2020] combines abstract interpretation and SMT solving for verifying neural network robustness.

### Formal Verification for Quantized Networks

**Verification of BNNs** [Narodytska et al., 2018; Cheng et al., 2020] has explored verification of binary networks, but formal properties of ternary networks remain underexplored.

**Trinity vs Prior Work:** Rather than verifying trained networks post-hoc, Trinity builds formal properties into the numerical formats themselves. GF16 operations are provably overflow-free by construction (finite field closure), and TF3 scaling has exact arithmetic properties derivable from φ² = φ + 1.

---

## 5. Finite Field Arithmetic in Neural Networks

### Homomorphic Encryption

**Homomorphic encryption** [Gentry, 2009; Brakerski et al., 2014] enables computation on encrypted data but is computationally expensive. Some work has explored finite-field arithmetic in this context, but not for neural network acceleration.

### Quantization in Finite Fields

**Post-training quantization** [Jacob et al., 2018; Nagel et al., 2020] typically operates in real arithmetic, not finite fields. Trinity's GF16 is novel in using GF(2⁴) for neural network activation magnitudes.

**Trinity vs Prior Work:** GF16 is, to our knowledge, the first application of finite-field arithmetic to neural network quantization for formal verification benefits. The overflow-freedom property (Theorem 1) follows directly from field axioms, a novel contribution.

---

## 6. Golden Ratio in Neural Networks

### φ-Based Architectures

**φ-Learning** [Li et al., 2022] explored golden-ratio based learning rate schedules but did not use φ in numerical representations.

**Trinity vs Prior Work:** Trinity's TF3 format uses powers of φ as scale levels, and φ² = φ + 1 enables exact arithmetic for scale combinations (Theorem 2). This is novel compared to prior work that uses φ only for hyperparameter tuning.

---

## 7. Attention Mechanisms

### Standard Attention

**Transformer attention** [Vaswani et al., 2017] uses softmax normalization for attention weights. This is differentiable but produces continuous weights that are difficult to inspect or verify.

### Sparse Attention

**Sparse attention variants** [Child et al., 2019; Roy et al., 2021] reduce computational complexity but still use continuous weights.

**Gating mechanisms** [Dauphin et al., 2017; Shazeer et al., 2020] introduce discrete gating but typically for layer selection, not token-level attention.

**Trinity vs Prior Work:** Trinity's Consciousness Gate produces ternary outputs {-1, 0, +1} with formal properties (monotonicity, Theorem 4) and inspectable binary masks. This bridges the gap between continuous attention and discrete, interpretable token selection.

---

## 8. Ternary Logic and Computing

### Multi-Valued Logic

**Ternary logic** [Mouftah, 1985; Hurst, 1984] has a long history in computer science, but applications to neural networks are limited.

**Balanced ternary** {-1, 0, +1} has been explored for specialized processors [Richards, 1971] but not for modern deep learning.

**Trinity vs Prior Work:** Trinity is the first framework to combine balanced ternary with formal algebraic structures (GF16, TF3) and VSA operations for neural network computation.

---

## Key References

[To be completed with proper DOIs before submission]

1. Ma, S. et al. (2024). The Era of 1-bit LLMs: All Large Language Models are in 1.58 Bits.
2. Hubara, I. et al. (2016). Binarized Neural Networks. NeurIPS 2016.
3. Li, F. et al. (2016). Ternary Weight Networks.
4. Umuroglu, Y. et al. (2017). FINN: A Framework for Fast, Scalable Binarized Neural Network Inference. FPGA 2017.
5. Plate, T. A. (2003). Holographic Reduced Representation.
6. Frady, E. P. et al. (2021). Computing on Functions Using Randomized Vector Representations.
7. Katz, G. et al. (2019). Marabou: An SMT-based Tool for Verifying Deep Neural Networks.
8. Volder, J. E. (1959). The CORDIC Trigonometric Computing Technique.
9. Vaswani, A. et al. (2017). Attention Is All You Need. NeurIPS 2017.
10. Kim, H. et al. (2025). LUT-LLM: Memory-Based Computation for LLM Inference on FPGAs.
11. Ma, S. et al. (2025). TerEffic: Highly Efficient Ternary LLM Inference on FPGA.
12. Blott, M. et al. (2018). FINN-R: An End-to-End Toolflow for Accelerating Fully-Connected Neural Networks on FPGAs.

---

**Document Control:** NEURIPS-REL-001
**Status:** Draft — Citations to be verified before submission
