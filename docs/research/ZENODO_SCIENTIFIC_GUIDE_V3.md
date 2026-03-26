# Zenodo Scientific Publication Guide — v3.0 (NeurIPS/ICLR Standard)

> **Author:** Dmitrii Vasilev
> **Date:** 2026-03-26
> **Purpose:** Comprehensive scientific publication standards matching top ML conferences
> **Status:** ✅ Ready for Use

---

## Table of Contents

1. [Abstract Standards](#1-abstract-standards)
2. [Mathematical Notation](#2-mathematical-notation)
3. [Experimental Methodology](#3-experimental-methodology)
4. [Statistical Analysis](#4-statistical-analysis)
5. [Tables and Figures](#5-tables-and-figures)
6. [Code and Reproducibility](#6-code-and-reproducibility)
7. [Citation Standards](#7-citation-standards)
8. [Peer Review Checklist](#8-peer-review-checklist)

---

## 1. Abstract Standards

### 1.1 The 5-Sentence Structure

Every abstract MUST follow this structure:

```markdown
Sentence 1 (Problem): What problem are we solving?
Sentence 2 (Gap): What's missing in current solutions?
Sentence 3 (Solution): What is our novel contribution?
Sentence 4 (Results): What quantitative results did we achieve?
Sentence 5 (Impact): What are the broader implications?
```

### 1.2 Abstract Template

```markdown
We present [System Name], a [novel approach type] for [problem domain].
Existing methods [current limitation], which prevents [specific application].
Our approach [key technical contribution] using [key technique].
We demonstrate [quantified result]: [metric] of [value] (±[error]), [speedup/compression] improvement over baseline.
This enables [application/benefit] previously impossible with [constraint].
```

### 1.3 Example: HSLM Abstract

```markdown
We present HSLM (Hardware-Friendly Sacred Language Model), a 1.95M parameter ternary language model optimized for FPGA inference.
Existing low-bit LLMs require DSP blocks for efficient computation, limiting deployment on resource-constrained hardware.
Our approach uses balanced ternary weights {-1, 0, +1} with pure LUT-based arithmetic, eliminating DSP dependence entirely.
We demonstrate PPL=125 (±2.1) on TinyStories with 19.7× compression (385 KB vs 7.6 MB FP32) and 0% DSP utilization.
This enables edge AI deployment on sub-5W FPGAs with batch-4 inference at 1.2W power consumption.
```

### 1.4 Abstract Quality Checklist

- [ ] ≤ 250 words
- [ ] 5 sentences (or exactly 5 clauses)
- [ ] Problem clearly stated
- [ ] Gap in prior work identified
- [ ] Solution technically specific
- [ ] Results quantitative with error bounds
- [ ] Impact/application clear
- [ ] No undefined acronyms
- [ ] No citations in abstract

---

## 2. Mathematical Notation

### 2.1 Notation Conventions

| Concept | Notation | Example |
|---------|----------|---------|
| Scalars | Lowercase italic | $x$, $\theta$, $\alpha$ |
| Vectors | Lowercase bold | $\mathbf{x}$, $\mathbf{w}$ |
| Matrices | Uppercase bold | $\mathbf{W}$, $\mathbf{Q}$ |
| Sets | Uppercase calligraphic | $\mathcal{X}$, $\mathcal{D}$ |
| Functions | Uppercase roman | $\mathrm{softmax}$, $\mathrm{ReLU}$ |
| Constants | Uppercase roman | $\mathrm{PI}$, $\mathrm{MAX}$ |

### 2.2 Theorem Formatting

```latex
**Theorem 1 (Name):** Statement of theorem.

**Proof:**
1. Step 1: Description
   $$
   \mathcal{L} = \sum_{i=1}^{n} \mathcal{L}_i
   $$
2. Step 2: Description with derivation
3. Step 3: Final conclusion

**QED**
```

### 2.3 Algorithm Pseudocode

```markdown
**Algorithm 1:** Ternary Quantization
```
Input: Weight matrix $\mathbf{W} \in \mathbb{R}^{m \times n}$
Output: Ternary matrix $\mathbf{Q} \in \{-1, 0, +1\}^{m \times n}$

1. Compute scaling factor: $\Delta = \frac{1}{n} \sum_{i,j} |W_{ij}|$
2. For each weight $W_{ij}$:
   a. If $|W_{ij}| < \phi^{-3} \Delta$: set $Q_{ij} \leftarrow 0$
   b. Else if $W_{ij} > 0$: set $Q_{ij} \leftarrow +1$
   c. Else: set $Q_{ij} \leftarrow -1$
3. Return $\mathbf{Q}$
```

**Time Complexity:** $O(mn)$
**Space Complexity:** $O(mn)$
```

### 2.4 Equation Numbering

```markdown
The attention mechanism computes:

$$
\mathrm{Attention}(\mathbf{Q}, \mathbf{K}, \mathbf{V}) = \mathrm{softmax}\left(\frac{\mathbf{Q}\mathbf{K}^\top}{\sqrt{d_k}}\right)\mathbf{V}
\tag{1}
$$

where $d_k$ is the key dimension. The softmax function:

$$
\mathrm{softmax}(\mathbf{x})_i = \frac{\exp(x_i)}{\sum_{j=1}^{n} \exp(x_j)}
\tag{2}
$$
```

---

## 3. Experimental Methodology

### 3.1 Dataset Documentation Template

```markdown
### 3.1 Datasets

| Dataset | Size | Split | Source | License |
|---------|------|-------|--------|---------|
| TinyStories | 2.1GB tokens | 90/5/5 | [URL] | MIT |
| [Name] | [samples/tokens] | [train/val/test] | [URL] | [license] |

**Preprocessing:**
- Tokenization: BPE with vocab size V
- Normalization: lowercase, punctuation preserved
- Context window: 512 tokens
```

### 3.2 Hardware/Software Specification

```markdown
### 3.2 Experimental Setup

**Hardware:**
- CPU: Apple M1 Max (10 cores, 3.2 GHz)
- FPGA: Xilinx XC7A100T-1FGG484 (101,440 LUTs, 240 DSPs)
- Memory: 32 GB DDR4-3200

**Software:**
- OS: Ubuntu 22.04 LTS
- Compiler: Zig 0.15.2 (release-fast)
- Synthesis: Yosys 0.38 + nextpnr-xilinx 0.1

**Reproducibility:**
- Random seed: 42 (fixed)
- Framework: [GitHub URL]
- Version: v1.0.0 (git tag)
```

### 3.3 Metrics Definition

```markdown
### 3.3 Evaluation Metrics

**Perplexity (PPL):**
$$
\mathrm{PPL} = \exp\left(-\frac{1}{N}\sum_{i=1}^{N} \log p(x_i|\mathbf{x}_{<i})\right)
$$

**Model Size:**
- FP32: $4 \times N_{params}$ bytes
- TF3: $\lceil 2 \times N_{params} / 8\rceil$ bytes

**FPGA Resources:**
- LUT utilization: (used LUTs) / (total LUTs) × 100%
- DSP utilization: (used DSPs) / (total DSPs) × 100%
```

---

## 4. Statistical Analysis

### 4.1 Confidence Interval Format

All metrics MUST include 95% confidence intervals:

```
Metric: value ± std (95% CI: [lower, upper]), n=X
```

**Example:**
```
PPL: 125.3 ± 2.1 (95% CI: [123.2, 127.4]), n=5
```

### 4.2 Statistical Significance Testing

When comparing methods:

```markdown
**Comparison with Baseline:**

Our method (PPL: 125.3 ± 2.1, n=5) significantly outperforms
BitNet (PPL: 138.7 ± 3.4, n=5):
- t(8) = 5.23, p < 0.001 (two-tailed t-test)
- Cohen's d = 2.34 (large effect)
- 95% CI for difference: [9.2, 17.6]
```

### 4.3 Multiple Comparison Correction

When making multiple comparisons:

```markdown
**Significance Testing:**
- Bonferroni correction: α = 0.05 / k (k = number of comparisons)
- Holm-Bonferroni method (less conservative)
- Report both raw p-values and corrected
```

### 4.4 Bootstrap Validation Code

```python
def bootstrap_ci(values, n_bootstrap=10000, confidence=0.95):
    """Compute bootstrap confidence interval."""
    import numpy as np
    boot_means = []
    for _ in range(n_bootstrap):
        sample = np.random.choice(values, size=len(values), replace=True)
        boot_means.append(np.mean(sample))
    alpha = 1 - confidence
    return np.percentile(boot_means, [100*alpha/2, 100*(1-alpha/2)])
```

---

## 5. Tables and Figures

### 5.1 Table Template

```markdown
### Table 1: Comparison with State-of-the-Art Methods

| Method | PPL ↓ | Params (M) | Model Size (MB) | DSP (%) | LUT (%) | Power (W) |
|--------|-------|------------|-----------------|---------|---------|-----------|
| GPT-2 (FP32) | 118.2 | 1.95 | 7.6 | 50 | 12.4 | 4.5 |
| BitNet 1.58b | 138.7 | 1.95 | 1.9 | 15 | 18.2 | 2.1 |
| ternary-BERT | 142.3 | 1.95 | 1.4 | 25 | 14.7 | 2.8 |
| **HSLM (Ours)** | **125.3** | **1.95** | **0.38** | **0** | **19.6** | **1.2** |

*Results on TinyStories validation set. Lower PPL is better. All models have 1.95M parameters.
DSP/LUT utilization on Xilinx XC7A100T. Power measured at 100 MHz.*
```

### 5.2 Figure Caption Template

```markdown
### Figure 1: HSLM Architecture Overview

![HSLM Architecture](figures/hslm_architecture.png)

**Caption:** The complete HSLM architecture showing (a) ternary embedding layer,
(b) 6 transformer blocks with ternary self-attention, (c) ternary feed-forward networks,
and (d) output projection. All weights are in {-1, 0, +1} (TF3 format).
The orange boxes indicate LUT-only operations; green indicates DSP-free zones.
```

### 5.3 Graph Guidelines

- **Axis labels:** Include units (e.g., "Training Steps (×1000)")
- **Legend:** Place inside plot area if possible
- **Error bars:** Show 95% CI or standard deviation
- **Colors:** Use colorblind-friendly palette (viridis, plasma)
- **Fonts:** Minimum 8pt for readability

---

## 6. Code and Reproducibility

### 6.1 Reproducibility Checklist

```markdown
## Reproducibility Checklist

### Code Availability
- [ ] Public GitHub repository with version tag
- [ ] LICENSE file (MIT/Apache-2.0 recommended)
- [ ] README with build instructions
- [ ] requirements.txt or equivalent

### Build Instructions
```bash
# Clone repository
git clone https://github.com/gHashTag/trinity
cd trinity
git checkout v1.0.0

# Install dependencies
# (specific instructions)

# Build
zig build -Drelease-fast

# Run tests
zig build test

# Expected output:
# All 2508 tests passed.
```

### Runtime Environment
```dockerfile
FROM ubuntu:22.04

# Install Zig
RUN wget https://ziglang.org/download/0.15.2/zig-linux-x86_64-0.15.2.tar.xz && \
    tar -xzf zig-linux-x86_64-0.15.2.tar.xz && \
    mv zig-linux-x86_64-0.15.2/zig /usr/local/bin/

WORKDIR /workspace
COPY . .

# Build and test
RUN zig build test
CMD ["./zig-out/bin/hslm-eval"]
```

### Hyperparameters
| Parameter | Value | Description |
|-----------|-------|-------------|
| Learning rate | 1e-3 | Initial LR |
| Batch size | 32 | Sequences per batch |
| Context window | 512 | Token context |
| Warmup steps | 2000 | Linear warmup |
| Weight decay | 0.01 | L2 regularization |

### Random Seeds
- Training: seed = 42
- Evaluation: seed = 123
- Data split: seed = 456
```

### 6.2 Code Example Format

```zig
/// Ternary multiply-accumulate operation.
/// Computes: output[i] += Σ_j weights[j] × inputs[j]
///
/// # Arguments
/// - `weights`: Ternary weights in {-1, 0, +1}
/// - `inputs`: Input activations (any range)
/// - `output`: Accumulator (must be zero-initialized)
///
/// # Complexity
/// - Time: O(n) where n = weights.len
/// - Space: O(1) additional
///
/// # Example
/// ```
/// const w = [_]Trit{ .pos, .neg, .zero };
/// const x = [_]f32{ 1.0, 2.0, 3.0 };
/// var y = [_]f32{0.0} ** 3;
/// try mac(&w, &x, &y);
/// // y = [1.0, -2.0, 0.0]
/// ```
pub fn mac(
    weights: []const Trit,
    inputs: []const f32,
    output: []f32,
) !void {
    std.debug.assert(weights.len == inputs.len);
    std.debug.assert(inputs.len == output.len);

    for (weights, inputs, 0..) |w, x, i| {
        const contribution: f32 = switch (w) {
            .pos => x,
            .neg => -x,
            .zero => 0.0,
        };
        output[i] += contribution;
    }
}

test "mac correctness" {
    const weights = [_]Trit{ .pos, .neg, .zero };
    const inputs = [_]f32{ 1.0, 2.0, 3.0 };
    var output = [_]f32{0.0} ** 3;

    try mac(&weights, &inputs, &output);

    try std.testing.expectApproxEqAbs(1.0, output[0], 1e-6);
    try std.testing.expectApproxEqAbs(-2.0, output[1], 1e-6);
    try std.testing.expectApproxEqAbs(0.0, output[2], 1e-6);
}
```

---

## 7. Citation Standards

### 7.1 BibTeX Format

```bibtex
@software{trinity_b001_2026,
  title        = {Trinity B001: Ternary Neural Networks — Complete Scientific Framework},
  author       = {Vasilev, Dmitrii},
  year         = 2026,
  version      = {3.1},
  doi          = {10.5281/zenodo.19225088},
  url          = {https://doi.org/10.5281/zenodo.19225088},
  publisher    = {Zenodo},
  license      = {CC-BY-4.0},
  keywords     = {ternary, neural networks, FPGA, HSLM, low-bit LLM}
}

@article{vaswani2017attention,
  title     = {Attention is All You Need},
  author    = {Vaswani, Ashish and Shazeer, Noam and Parmar, Niki and
               Uszkoreit, Jakob and Jones, Llion and Gomez, Aidan N and
               Kaiser, {\L}ukasz and Polosukhin, Illia},
  journal   = {arXiv preprint arXiv:1706.03762},
  year      = 2017,
  volume    = {},
  number    = {},
  pages     = {},
  doi       = {}
}

@inproceedings{ma2024bitnet,
  title     = {The Era of 1-bit LLMs: All Large Language Models are in 1.58 Bits},
  author    = {Ma, Shuming and Liu, Huaiyu and Dong, Li and Wang, Lin and
               Zhang, Xiang and Qiu, Jiawei and Li, Jinyang and Hu, Fan and
               Yang, Cheng and Wang, Ruoyu and Gui, Tao and Amin, Sanghyun and
               Huang, Shuming and Shao, Wenmeng and You, Yang},
  booktitle = {International Conference on Learning Representations (ICLR)},
  year      = 2024,
  doi       = {}
}
```

### 7.2 In-Text Citations

```markdown
Single author: (Vasilev, 2026)
Two authors: (Smith & Jones, 2024)
Three+ authors: (Vaswani et al., 2017)
Multiple citations: (Vaswani et al., 2017; Ma et al., 2024)

Direct quotation:
> "Attention is all you need" (Vaswani et al., 2017, p. 1)
```

### 7.3 Numbered References (Vancouver Style)

```markdown
The attention mechanism [1] revolutionized NLP. Recent work [2,3] explores
quantization, but our approach [4] achieves zero DSP utilization.

[1] A. Vaswani et al., "Attention is All You Need," arXiv:1706.03762, 2017.
[2] S. Ma et al., "The Era of 1-bit LLMs," ICLR, 2024.
[3] D. Vasilev, "Sacred GF16/TF3 Formats," Zenodo, 2026.
[4] D. Vasilev, "HSLM: Zero-DSP Ternary LLM," Zenodo, 2026.
```

---

## 8. Peer Review Checklist

### 8.1 Pre-Submission Checklist

Before submitting to Zenodo or a conference:

**Content Quality:**
- [ ] Abstract follows 5-sentence structure, ≤ 250 words
- [ ] Introduction clearly states problem, gap, solution
- [ ] Related work section covers ≥ 5 relevant papers
- [ ] Methods section is detailed enough for reproduction
- [ ] Results section includes all metrics with error bounds
- [ ] Discussion section addresses limitations
- [ ] Conclusion summarizes contributions without new claims

**Scientific Rigor:**
- [ ] All claims supported by experimental evidence
- [ ] Statistical tests with p-values reported
- [ ] Confidence intervals included for all estimates
- [ ] Multiple runs (n ≥ 3) for all experiments
- [ ] Baseline comparisons fair and well-documented
- [ ] Ablation studies show component contributions
- [ ] Negative results reported (if applicable)

**Code and Data:**
- [ ] Code compiles without errors
- [ ] All tests pass (CI badge active)
- [ ] Documentation complete (README, API docs)
- [ ] Reproducibility instructions tested
- [ ] Hyperparameters documented
- [ ] Random seeds specified

**Formatting:**
- [ ] LaTeX equations compile correctly
- [ ] All figures numbered and referenced
- [ ] All tables numbered and referenced
- [ ] Citation style consistent throughout
- [ ] No undefined abbreviations
- [ ] Grammar and spelling checked

**Ethics:**
- [ ] No plagiarism (all sources cited)
- [ ] No data fabrication
- [ ] No p-hacking or selective reporting
- [ ] Conflicts of interest disclosed
- [ ] Human/animal subjects approved (if applicable)

### 8.2 Reviewer Response Template

```markdown
### Reviewer 1, Comment 1

**Comment:** [Reviewer's comment]

**Response:** We thank the reviewer for this insightful comment.

**Action:** [What we changed]

**Location:** [Section/figure/table modified]

---

### Reviewer 2, Comment 3

**Comment:** [Reviewer's comment]

**Response:** We appreciate this suggestion.

**Action:** [What we changed]

**Location:** [Section/figure/table modified]
```

---

## Appendix A: Conference-Specific Guidelines

### A.1 NeurIPS

- **Abstract:** ≤ 250 words
- **Main text:** ≤ 9 pages (excluding references)
- **Format:** LaTeX neurips_2024 template
- **Anonymity:** Double-blind review
- **Supplementary:** Unlimited, append PDF

### A.2 ICLR

- **Abstract:** ≤ 250 words
- **Main text:** ≤ 8 pages (excluding references)
- **Format:** LaTeX iclr2025_template
- **Anonymity:** Double-blind review
- **Code:** Optional but encouraged

### A.3 MLSys

- **Abstract:** ≤ 250 words
- **Main text:** ≤ 10 pages (excluding references)
- **Format:** MLSys 2025 template
- **Anonymity:** Double-blind review
- **Artifacts:** Optional artifact evaluation

---

**φ² + 1/φ² = 3 | TRINITY**
