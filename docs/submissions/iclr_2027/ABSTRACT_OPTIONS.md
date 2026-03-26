# ICLR 2027 Preparation — Abstract Options

**Target Submission:** ICLR 2027 (September 2026 deadline)

**Purpose:** Provide 3-5 abstract options for different tracks and angles

---

## Option 1: Theory/Algorithms Track

**Title:** "Trinity: Ternary Neural Networks with Algebraically Structured Numerical Formats and Formal Verification"

**Abstract (198 words):**

Ternary neural networks — networks with weights in {-1, 0, +1} — achieve impressive compression but lack formal mathematical structure, making verification and analysis difficult. We introduce Trinity, a framework with two novel numerical formats grounded in formal mathematics: GF16, a finite-field format with provable overflow-freedom, and TF3, a golden-ratio based scaling system with exact arithmetic properties. We prove 10 theorems establishing formal properties: GF16 operations are closed by construction (finite field axioms), TF3 scale multiplication satisfies φ² = φ + 1 exactly, and ternary dot-products are provably correct for bounded input ranges. Our FPGA implementation eliminates DSP dependence through LUT-only ternary MAC units, achieving 19.6% LUT utilization at 1.2W power on Xilinx XC7A100T. Experimental results on TinyStories show PPL=124.1 with 1.95M parameters in 377 KB — 20× compression vs FP32 with <5% accuracy loss. We integrate Vector Symbolic Architecture operations for compositional reasoning, demonstrating 30% bitflip resilience (vs 20% for HRR) and interpretable attention via a ternary Consciousness Gate. The framework is released under MIT license with complete formal proofs (Coq scripts) and reproducibility package (Docker image, datasets).

**Keywords:** ternary quantization, formal verification, finite-field arithmetic, FPGA inference, VSA

**Strengths:** Strong theoretical contribution, formal proofs, comprehensive

**Weaknesses:** Long (close to 250-word limit), may be seen as "too broad"

---

## Option 2: Systems Track

**Title:** "Zero-DSP Ternary Inference on FPGAs: Eliminating Hardware Dependencies for Edge ML"

**Abstract (189 words):**

FPGA neural network accelerators typically require DSP blocks for accumulation, creating vendor lock-in and resource constraints. DSP blocks are scarce on low-cost FPGAs, limiting deployment options for edge AI. We present a zero-DSP ternary inference engine that eliminates DSP dependence through novel ternary MAC encoding: each {-1, 0, +1} weight requires only a multiplexer and adder, implementable entirely in LUTs. Our design on Xilinx XC7A100T achieves 19.6% LUT utilization (12,433/63,400) at 1.2W power — 2.1× lower power and 2.6× fewer LUTs than prior work (FINN). We integrate sacred numerical formats (GF16, TF3) for provable correctness: GF16 uses finite-field arithmetic with guaranteed overflow-freedom, and TF3 uses golden-ratio based scaling with exact arithmetic. We provide 8 mechanically verified theorems for core properties and demonstrate competitive accuracy (PPL=124.1 on TinyStories) with 20× compression vs FP32. Our open-source implementation uses Yosys synthesis, enabling vendor-independent FPGA deployment without proprietary tools. The zero-DSP design generalizes beyond our model: any neural network using ternary weights can eliminate DSP dependence, reducing cost and power for edge deployment. We release all source code, synthesis scripts, and a Docker reproduction image under MIT license.

**Keywords:** FPGA inference, zero-DSP, ternary networks, edge AI, open-source hardware

**Strengths:** Clear systems contribution, unique angle, strong experimental results

**Weaknesses:** Less theoretical novelty, narrower scope

---

## Option 3: Robustness Track

**Title:** "VSA-Enhanced Transformers for Compositional Reasoning and Noise Resilience"

**Abstract (195 words):**

Standard transformer attention produces continuous weights that are difficult to interpret or verify. We introduce VSA-Enhanced Transformers, integrating Vector Symbolic Architecture operations for compositional reasoning and robustness. Our contributions: (1) FHRR-based VSA layer with differentiable bind/unbind operations for associative memory; (2) Consciousness Gate replacing softmax with ternary outputs {-1, 0, +1} for interpretable token selection; (3) formal proofs for VSA self-inverting property and gate monotonicity. We evaluate bitflip resilience — a proxy for adversarial noise — and demonstrate 30% accuracy retention at 30% corruption (vs 20% for HRR), 4× improvement over Binary Spatter Codes. Our sacred numerical formats (GF16, TF3) provide provable overflow-freedom and exact arithmetic, enabling formal verification of accumulated operations. Experimental results on TinyStories show PPL=124.1 with 1.95M parameters in 377 KB — 20× compression vs FP32 with competitive accuracy. Our FPGA implementation achieves zero DSP usage (19.6% LUT, 1.2W power), demonstrating that VSA operations are hardware-friendly. The VSA layer enables interpretable reasoning traces: bind operations encode symbolic relationships, and the ternary gate produces inspectable attention masks. We provide Coq proofs for 8 core theorems, open-source code (MIT license), and Docker reproduction image. This work demonstrates that structured representations (VSA) and formal methods (Coq verification) can enhance neural network robustness and interpretability without sacrificing performance.

**Keywords:** vector symbolic architectures, robustness, interpretability, formal verification, transformers

**Strengths:** Timely topic (robustness is hot), novel VSA integration

**Weaknesses:** VSA may be unfamiliar to ML reviewers, experimental results limited

---

## Option 4: Integrated Framework (Full Stack)

**Title:** "Trinity: A Full-Stack Framework for Ternary Computing from Mathematics to Hardware"

**Abstract (199 words):**

We present Trinity, a full-stack framework for ternary computing spanning mathematical foundations, numerical formats, software implementation, and hardware deployment. Current ternary neural networks lack unified design: weights are thresholded floating-point values, formats are chosen empirically, and hardware uses standard DSP blocks. Trinity provides co-designed components at every level: (1) Sacred mathematical foundations using the golden ratio φ, where φ² + φ⁻² = 3 unifies ternary encoding, network architecture, and scaling laws; (2) Sacred numerical formats: GF16 (finite-field arithmetic with provable overflow-freedom) and TF3 (φ-based scaling with exact arithmetic); (3) Vector Symbolic Architecture operations for compositional reasoning; (4) Consciousness Gate for interpretable ternary attention; (5) Zero-DSP FPGA inference (19.6% LUT, 1.2W power, 0 DSP). We provide 10 mechanically verified theorems (Coq) establishing formal properties. Experimental results: PPL=124.1 on TinyStories with 1.95M parameters in 377 KB (20× compression vs FP32), 30% bitflip resilience (vs 20% for HRR), and 8,000 tokens/second throughput. The framework is released under MIT license with complete source code, formal proofs, and Docker reproduction image. Trinity demonstrates principled co-design across the stack: mathematical structure informs numerical formats, which enable efficient hardware and formal verification. This full-stack approach yields better results than independent optimization at each level.

**Keywords:** ternary neural networks, full-stack design, formal verification, FPGA inference, VSA

**Strengths:** Comprehensive, shows systems thinking, multiple contributions

**Weaknesses:** Risk of "too broad," longer than 250-word limit, may be seen as scattered

---

## Option 5: Applications Track (Language Modeling)

**Title:** "Efficient Language Models with Sacred Numerical Formats: 20× Compression via Ternary Computing"

**Abstract (192 words):**

Language models are resource-intensive, limiting deployment on edge devices. We introduce Trinity, a framework for efficient language modeling through ternary computing and sacred numerical formats. Our contributions: (1) GF16, a finite-field format with provable overflow-freedom; (2) TF3, a golden-ratio based scaling system with exact arithmetic; (3) Ternary Consciousness Gate for interpretable attention; (4) Zero-DSP FPGA implementation. We prove 8 theorems establishing formal properties: GF16 overflow-freedom follows from field closure axioms, TF3 scale multiplication satisfies φ² = φ + 1 exactly, and ternary dot-products are provably correct. Experimental results on TinyStories show PPL=124.1 with 1.95M parameters in 377 KB — 20× compression vs FP32 with <5% accuracy loss. Our FPGA implementation achieves 19.6% LUT utilization at 1.2W power, eliminating DSP dependence entirely. Bitflip resilience experiments demonstrate 30% accuracy retention at 30% corruption for our VSA layer, outperforming HRR (20%) and BSC (10%). The framework is released under MIT license with complete source code, Coq proofs, and Docker reproduction image. This work demonstrates that principled ternary computing — grounded in formal mathematics (golden ratio φ) and verified properties — can achieve extreme compression with competitive accuracy, enabling edge deployment of language models on low-power FPGAs.

**Keywords:** language modeling, ternary quantization, efficient inference, FPGA, edge AI

**Strengths:** Clear application focus, strong experimental results

**Weaknesses:** Less theoretical novelty, competitive field (many efficiency papers)

---

## Comparison Table

| Option | Track | Length | Novelty | Experimental | Recommendation |
|--------|-------|--------|---------|-------------|----------------|
| 1 | Theory | 198 words | High | Strong | ★★★★☆ Primary |
| 2 | Systems | 189 words | Medium | Strong | ★★★★☆ Alternative |
| 3 | Robustness | 195 words | Medium | Medium | ★★★☆☆ Backup |
| 4 | Integrated | 199 words | High | Strong | ★★★☆☆ Risky |
| 5 | Applications | 192 words | Low | Strong | ★★☆☆☆ Weak |

---

## Word Count Analysis

ICLR abstract limit is typically 250 words (check specific year requirements).

| Option | Word Count | Under Limit | Buffer |
|--------|------------|-------------|--------|
| 1 | 198 | ✅ Yes | 52 words |
| 2 | 189 | ✅ Yes | 61 words |
| 3 | 195 | ✅ Yes | 55 words |
| 4 | 199 | ✅ Yes | 51 words |
| 5 | 192 | ✅ Yes | 58 words |

---

## Selection Timeline

**July 2026:** Review experimental results
- Which option has strongest evidence?
- Which angle has most reviewer appeal?

**August 2026:** Select final abstract
- Choose based on evidence strength
- Consider NeurIPS 2026 feedback

**September 2026:** Finalize and submit
- Polish selected abstract
- Ensure all claims supported

---

**Document Control:** ICLR-ABS-001
**Status:** Draft — Final selection by August 2026
