# NeurIPS 2026 Submission — Limitations

**Paper Title:** Trinity: A Ternary Neural Network Framework with Algebraically Structured Formats and Zero-DSP FPGA Deployment

**Anonymous Authors** *(double-blind submission)*

---

## 1. Scope Limitations

### Model Scale

**Limitation:** Trinity is validated on models up to 1.95M parameters (HSLM). Scaling to larger models (7B+, 100B+) has not been demonstrated.

**Impact:** Results may not generalize to state-of-the-art production models where ternary quantization may have different accuracy characteristics.

**Mitigation:** We focus on edge deployment scenarios where 1-2M parameter models are practical. Scaling to larger models is left as future work.

### Dataset Scope

**Limitation:** All experiments use TinyStories dataset for language modeling. Results on vision, speech, or multimodal tasks are not provided.

**Impact:** The benefits of sacred numerical formats and VSA operations may differ for other modalities.

**Mitigation:** TinyStories is a standard benchmark for small language models. Extension to other tasks is left for future work.

### FPGA Platform

**Limitation:** FPGA implementation is validated only on Xilinx XC7A100T. Results on other FPGA families (Intel, Lattice, Efinix) or ASIC implementations are not provided.

**Impact:** Resource utilization and timing results are platform-specific.

**Mitigation:** XC7A100T is a representative mid-range FPGA. The design uses standard Verilog constructs that should synthesize on other platforms with Yosys support.

---

## 2. Accuracy Limitations

### Ternary Accuracy Degradation

**Limitation:** TF3 quantization incurs +5.9% PPL degradation compared to FP32 baseline (125.1 vs 118.0 PPL).

**Impact:** Trinity trades accuracy for efficiency. Applications requiring maximum accuracy may find this unacceptable.

**Root Cause:** Information-theoretic limit of 1.585 bits/trit vs 32 bits for FP32. Some precision loss is unavoidable.

**Mitigation:** GF16 provides intermediate accuracy (122.3 PPL) for applications less sensitive to resource constraints.

### Zero-DSP Accuracy

**Limitation:** Zero-DSP design uses only LUTs for accumulation, which may have different numerical properties than DSP-based accumulation.

**Impact:** Accumulation error may differ from standard FPGA designs, potentially affecting accuracy.

**Mitigation:** We measure <0.5% MSE difference between zero-DSP and DSP-based implementations.

---

## 3. Formal Verification Limitations

### Proof Scope

**Limitation:** Formal proofs cover core algebraic properties but do not verify end-to-end correctness of trained models.

**Impact:** Verified properties (overflow-freedom, scale exactness) do not guarantee model correctness or robustness.

**Example:** We prove GF16 addition is overflow-free, but we do not prove that a trained GF16 model generalizes to unseen data.

**Mitigation:** We clearly distinguish between (a) format-level verification and (b) model-level verification. The latter requires different techniques (SMT solvers, abstract interpretation) and is left as future work.

### Proof Assistant Coverage

**Limitation:** Not all claimed properties are mechanically verified. Some proofs exist only as mathematical derivations.

**Impact:** Human error in proof construction is possible.

**Mitigation:** We provide Coq/Lean4 scripts for critical theorems and clearly mark which proofs are mechanically verified vs manually derived.

---

## 4. FPGA Implementation Limitations

### Clock Frequency

**Limitation:** Zero-DSP design achieves 55 MHz critical path, significantly lower than DSP-based designs (200+ MHz).

**Impact:** Throughput may be limited for applications requiring high-speed inference.

**Mitigation:** We compensate through parallelism (8 tokens per cycle) and energy efficiency (1.2W power consumption).

### Resource Trade-offs

**Limitation:** Zero-DSP design uses 3× more LUTs than an equivalent DSP-based ternary MAC would use DSP blocks.

**Impact:** On FPGA-constrained designs, zero-DSP may not be optimal if DSPs are abundant.

**Mitigation:** Zero-DSP enables deployment on DSP-constrained FPGAs (low-cost Artix-7 vs expensive Kintex UltraScale+).

---

## 5. VSA Operation Limitations

### Dimensionality Curse

**Limitation:** VSA operations require high-dimensional vectors (10K dimensions) for effective binding/unbinding. This increases memory and computation.

**Impact:** VSA layer adds overhead compared to standard attention, particularly for smaller models.

**Mitigation:** We use FHRR (Fourier domain) for O(d log d) operations vs O(d²) for spatial-domain VSA.

### Noise Resilience Bound

**Limitation:** FHRR achieves 30% bitflip resilience at 30% corruption, but performance degrades rapidly beyond this threshold.

**Impact:** VSA operations are not suitable for extremely noisy environments or adversarial settings.

**Mitigation:** We recommend error-correcting codes for deployment in high-noise environments.

---

## 6. Training Limitations

### Straight-Through Estimator Bias

**Limitation:** STE approximates gradients for discrete operations, introducing bias in gradient estimates.

**Impact:** Training may be less stable or converge to suboptimal solutions compared to continuous models.

**Mitigation:** We use standard STE with clipping bounds, consistent with prior ternary network work.

### Hyperparameter Sensitivity

**Limitation:** Trinity requires careful tuning of quantization thresholds (τ) and learning rate schedules.

**Impact:** Results may not be robust to hyperparameter changes, requiring extensive search for new tasks.

**Mitigation:** We provide Queen Lotus Cycle for automated hyperparameter optimization, but this adds computational overhead.

---

## 7. Reproducibility Limitations

### Hardware Dependencies

**Limitation:** FPGA results require specific hardware (XC7A100T) that may not be accessible to all researchers.

**Impact:** Reproducing FPGA results requires hardware procurement or cloud FPGA services.

**Mitigation:** We provide pre-synthesized bitstreams and simulation results for researchers without FPGA access.

### Toolchain Versions

**Limitation:** Results depend on specific versions of Zig (0.15.x), Yosys (0.38+), and nextpnr-xilinx.

**Impact:** Different toolchain versions may produce different resource utilization or timing results.

**Mitigation:** We provide Docker images with exact toolchain versions for reproducibility.

---

## 8. Comparison Limitations

### Baseline Selection

**Limitation:** We compare primarily against BitNet and other ternary networks. Comparisons to other efficiency techniques (pruning, distillation, NAS) are limited.

**Impact:** The relative benefits of Trinity vs other efficiency approaches are not fully characterized.

**Mitigation:** We focus on the most directly comparable work (ternary quantization). Broader comparison is left for extended version.

### Energy Measurement

**Limitation:** Power measurements (1.2W) are based on FPGA power estimates, not direct measurement with power analyzer.

**Impact:** Actual power consumption may vary depending on usage patterns and environmental factors.

**Mitigation:** We plan to validate with physical power measurements in future work.

---

## 9. Generalization Limitations

### Task Generalization

**Limitation:** All experiments use language modeling. Applicability to computer vision, speech recognition, or reinforcement learning is not demonstrated.

**Impact:** The benefits of sacred formats and VSA operations may be task-specific.

**Mitigation:** We focus on language modeling as a representative task. Extension to other domains is left as future work.

### Dataset Generalization

**Limitation:** TinyStories uses simple vocabulary and sentence structure. Results may not generalize to more complex datasets (Wikipedia, C4, etc.).

**Impact:** Compression and accuracy benefits may differ for larger, more diverse corpora.

**Mitigation:** We use TinyStories as a standard benchmark. Scaling to larger datasets is left for future work.

---

## 10. Open Questions

We identify several open questions that this work does not address:

1. **Scaling Laws:** How does ternary quantization accuracy scale with model size? Does the accuracy penalty decrease or increase for 7B+ models?

2. **Task Transfer:** Do sacred numerical formats (GF16, TF3) provide benefits for computer vision or speech tasks?

3. **ASIC Implementation:** What are the area, power, and timing benefits of Trinity on an ASIC vs FPGA?

4. **Formal Verification of Trained Models:** Can SMT solvers verify properties of trained Trinity models (robustness, fairness)?

5. **VSA for Long-Range Dependencies:** Can VSA operations effectively replace attention for long sequences (10K+ tokens)?

6. **Multi-Modal VSA:** Can VSA operations bind representations across modalities (text + image, audio + video)?

---

## Conclusion

Trinity makes significant contributions in ternary neural networks, formal verification, and zero-DSP FPGA inference, but has important limitations:

**Strengths:**
- 20× memory compression vs FP32
- Zero-DSP FPGA implementation
- Formal proofs for core operations
- VSA compositional reasoning

**Limitations:**
- Validated only on small models (1.95M params)
- Single task (language modeling)
- Single platform (XC7A100T)
- Accuracy degradation vs FP32

We believe these limitations do not diminish the core contributions but provide clear boundaries for the applicability of Trinity. Future work can address these limitations through scaling to larger models, extension to other tasks, and broader formal verification.

---

**Document Control:** NEURIPS-LIM-001
**Status:** Draft — To be refined based on reviewer feedback
