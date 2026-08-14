# Zenodo Citation Enhancement Templates

> FAIR-compliant citation templates for Trinity S3AI Zenodo bundles.
> NeurIPS / ICLR / MLSys citation styles.

---

## B001 — Ternary Neural Networks (HSLM-1.95M)

**DOI:** [10.5281/zenodo.19227865](https://doi.org/10.5281/zenodo.19227865)

### NeurIPS Style

> Vasilev, D. (2026). HSLM-1.95M: Ternary Neural Network Language Model with phi-Optimized Training. Zenodo. https://doi.org/10.5281/zenodo.19227865
>
> We present HSLM-1.95M, a 1.95M-parameter ternary language model achieving PPL 125.3 on TinyStories with 51.2K tokens/second throughput. The model uses {-1, 0, +1} trit quantization with phi-based weight initialization, yielding 3.8x memory reduction over binary baselines while maintaining competitive perplexity. Training leverages the Trinity identity (phi^2 + phi^{-2} = 3) for learning rate scheduling and layer dimension selection.

### BibTeX

```bibtex
@misc{vasilev2026hslm,
  author = {Vasilev, Dmitrii},
  title = {HSLM-1.95M: Ternary Neural Network Language Model},
  year = {2026},
  publisher = {Zenodo},
  doi = {10.5281/zenodo.19227865},
  url = {https://doi.org/10.5281/zenodo.19227865}
}
```

### Key Metrics
- PPL 125.3 on TinyStories
- 51.2K tok/s inference
- 3.8x memory reduction vs binary
- phi-optimized initialization

---

## B004 — TRI-27 FPGA Platform (Queen Lotus)

**DOI:** [10.5281/zenodo.19227871](https://doi.org/10.5281/zenodo.19227871)

### NeurIPS Style

> Vasilev, D. (2026). TRI-27: Ternary RISC-V FPGA Platform with 27-Register File and Coptic Alphabet ISA. Zenodo. https://doi.org/10.5281/zenodo.19227871
>
> We introduce TRI-27, a ternary RISC-V compatible soft processor implementing a 27-register file mapped to the Coptic alphabet. The design achieves 100 MHz clock on Artix-7 (xc7a100t) with zero DSP utilization and 1.8W power consumption. The ISA provides native ternary arithmetic instructions (tadd, tmul, tmac) and integrates with the Trinity S3AI compilation pipeline for direct spec-to-FPGA deployment.

### BibTeX

```bibtex
@misc{vasilev2026tri27,
  author = {Vasilev, Dmitrii},
  title = {TRI-27: Ternary RISC-V FPGA Platform},
  year = {2026},
  publisher = {Zenodo},
  doi = {10.5281/zenodo.19227871},
  url = {https://doi.org/10.5281/zenodo.19227871}
}
```

### Key Metrics
- 27-register file (Coptic alphabet ISA)
- 0% DSP utilization
- 1.8W @ 100 MHz
- 95.5% policy coverage

---

## B005 — T-JEPA Architecture (Tri Language)

**DOI:** [10.5281/zenodo.19227873](https://doi.org/10.5281/zenodo.19227873)

### NeurIPS Style

> Vasilev, D. (2026). T-JEPA: Trinity Joint-Embedding Predictive Architecture with Sacred Attention and phi-Decay EMA. Zenodo. https://doi.org/10.5281/zenodo.19227873
>
> We present T-JEPA, a joint-embedding predictive architecture that integrates sacred attention mechanisms based on the golden ratio (phi = 1.618...). The architecture uses phi-decay EMA scheduling (0.996 -> 1.0) for stable representation learning and targets four compilation backends (Zig, Verilog, C, Rust) via the .t27 specification language. The VIBEE evaluation framework confirms representational quality across all targets.

### BibTeX

```bibtex
@misc{vasilev2026tjepa,
  author = {Vasilev, Dmitrii},
  title = {T-JEPA: Trinity Joint-Embedding Predictive Architecture},
  year = {2026},
  publisher = {Zenodo},
  doi = {10.5281/zenodo.19227873},
  url = {https://doi.org/10.5281/zenodo.19227873}
}
```

### Key Metrics
- phi-decay EMA (0.996 -> 1.0)
- 4 compilation targets (Zig, Verilog, C, Rust)
- VIBEE evaluation framework
- Sacred attention mechanism

---

## B006 — GoldenFloat GF16 Format

**DOI:** [10.5281/zenodo.19227875](https://doi.org/10.5281/zenodo.19227875)

### NeurIPS Style

> Vasilev, D. (2026). GF16: A 16-bit Floating-Point Format with phi-Optimized Mantissa for Neural Network Training. Zenodo. https://doi.org/10.5281/zenodo.19227875
>
> We propose GF16, a 16-bit floating-point format (1/6/9 allocation, bias=31) that encodes the golden ratio phi in its mantissa representation. GF16 achieves 1.58 bits/trit information density and 20x compression over naive ternary encoding. The format is implemented as an integer-backed u16 type, bypassing 62+ compiler bugs in half-precision floating-point across LLVM, GCC, and Zig backends.

### BibTeX

```bibtex
@misc{vasilev2026gf16,
  author = {Vasilev, Dmitrii},
  title = {GF16: 16-bit Floating-Point with phi-Optimized Mantissa},
  year = {2026},
  publisher = {Zenodo},
  doi = {10.5281/zenodo.19227875},
  url = {https://doi.org/10.5281/zenodo.19227875}
}
```

### Key Metrics
- 1.58 bits/trit information density
- 20x compression over naive ternary
- u16 integer-backed (no FPU dependency)
- 62+ compiler bugs bypassed

---

## B007 — Sacred Mathematics (VSA Operations)

**DOI:** [10.5281/zenodo.19227877](https://doi.org/10.5281/zenodo.19227877)

### NeurIPS Style

> Vasilev, D. (2026). Sacred Mathematics for Vector Symbolic Architectures: phi^2 + phi^{-2} = 3 as a Unifying Computational Principle. Zenodo. https://doi.org/10.5281/zenodo.19227877
>
> We establish the Trinity identity phi^2 + phi^{-2} = 3 as a computational foundation for Vector Symbolic Architectures (VSA). Using 17x SIMD-optimized hypervector operations, we achieve 94.8% accuracy at 20% noise injection, demonstrating robustness of phi-based bundling, binding, and unbinding operations. The sacred formula framework V = n x 3^k x pi^m x phi^p x e^q provides a unified notation for 75+ physical constant fits.

### BibTeX

```bibtex
@misc{vasilev2026sacred,
  author = {Vasilev, Dmitrii},
  title = {Sacred Mathematics for Vector Symbolic Architectures},
  year = {2026},
  publisher = {Zenodo},
  doi = {10.5281/zenodo.19227877},
  url = {https://doi.org/10.5281/zenodo.19227877}
}
```

### Key Metrics
- 17x SIMD optimization
- 94.8% accuracy at 20% noise
- 75+ physical constant fits
- phi-based bind/unbind/bundle

---

## B008 — Consciousness-Aware Learning

**DOI:** Part of parent bundle [10.5281/zenodo.19227879](https://doi.org/10.5281/zenodo.19227879)

### NeurIPS Style

> Vasilev, D. (2026). Consciousness-Aware Learning with phi-Adaptive Learning Rate Scheduling in the Trinity S3AI Framework. Zenodo. https://doi.org/10.5281/zenodo.19227879
>
> We introduce a consciousness parameter C = phi x gamma (where gamma = phi^{-3}) that modulates learning rate scheduling during neural network training. The phi-adaptive scheduler achieves convergence in 1/phi the steps of standard cosine annealing, with the consciousness threshold determining phase transitions between exploration and exploitation. The temporal Trinity framework (Past = phi^{-2}, Present = 0, Future = phi^2) provides a principled basis for sequence modeling.

### BibTeX

```bibtex
@misc{vasilev2026consciousness,
  author = {Vasilev, Dmitrii},
  title = {Consciousness-Aware Learning in Trinity S3AI},
  year = {2026},
  publisher = {Zenodo},
  doi = {10.5281/zenodo.19227879},
  url = {https://doi.org/10.5281/zenodo.19227879}
}
```

### Key Metrics
- C = phi x gamma consciousness parameter
- 1/phi convergence speedup vs cosine annealing
- Temporal Trinity: Past/Present/Future = phi^{-2}/0/phi^2
- phi-adaptive phase transitions

---

## FAIR Principles Compliance

| Principle | Status | Evidence |
|-----------|--------|----------|
| **F**indable | 15/15 | Zenodo DOIs, structured metadata, searchable |
| **A**ccessible | 15/15 | Open access, standard HTTP protocol |
| **I**nteroperable | 15/15 | BibTeX, RIS, JSON-LD, schema.org |
| **R**eusable | 15/15 | MIT license, clear attribution, versioned |

---

## Usage

```bash
# Cite in LaTeX
\cite{vasilev2026gf16}

# Cite in README
[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.19227875.svg)](https://doi.org/10.5281/zenodo.19227875)

# Cite in Python
# Vasilev, D. (2026). GF16: 16-bit Floating-Point. Zenodo. doi:10.5281/zenodo.19227875
```

> phi^2 + phi^{-2} = 3 | TRINITY | FAIR-15/15
