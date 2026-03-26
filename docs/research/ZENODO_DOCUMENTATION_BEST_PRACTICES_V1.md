# Zenodo Scientific Documentation Best Practices v1.0

**Date:** 2026-03-26
**Issue:** #415
**Purpose:** Template for creating publication-ready Zenodo bundle descriptions

---

## Executive Summary

This document provides best practices for Zenodo bundle documentation based on analysis of top ML conference papers (NeurIPS, ICLR, MLSys) and existing Trinity v5.2 enhanced descriptions.

---

## Part I: Document Structure

### I.1 Required Sections

Every Zenodo bundle description MUST include:

1. **Header Metadata** (YAML front matter)
```yaml
Title: [Bundle Name] v[Version]
Authors: [Author Name(s)]
DOI: [Zenodo DOI]
License: CC-BY-4.0 (recommended for open science)
Publication Date: YYYY-MM-DD
Version: [Version Number] ([Enhancement Description])
```

2. **Abstract** (200-500 words)
   - Problem statement (1 sentence)
   - Current limitations (1-2 sentences)
   - Our approach (2-3 sentences with specific numbers)
   - Key results (2-3 sentences with quantitative metrics)
   - Broader impact (1 sentence)

3. **Architecture Overview** (with diagrams)
   - System architecture diagram
   - Key components and their relationships
   - Data flow visualization

4. **Technical Specifications**
   - Bit layouts (for numerical formats)
   - Algorithm pseudocode
   - API signatures

5. **Experimental Results**
   - Benchmark tables
   - Performance metrics
   - Comparisons with baselines

6. **Formal Proofs** (if applicable)
   - Theorems
   - Proofs
   - Lemmas supporting theorems

7. **Reproducibility**
   - Dataset information
   - Hyperparameters
   - Random seeds
   - Environment details

---

## Part II: Abstract Writing Template

### II.1 Abstract Formula

**[Component Name]** for [Application Domain]

**Opening:** We present [Component Name], a [key characteristic] system for [primary goal]. [Current approaches/Standard methods] [limitation description], which [consequence].

**Our Approach:** Our design uses (1) **[Feature 1]** — [benefit with number], (2) **[Feature 2]** — [benefit with number], and (3) **[Feature 3]** — [benefit with number]. Implemented in [implementation language] with [hardware/software verification], our system achieves [key metric 1], [key metric 2], and [key metric 3].

**Results:** We provide [theoretical validation: proof/formal analysis] (Theorem N), demonstrate [experimental result: X% improvement], and show [reproducibility: open data/code].

### II.2 Example (from B006)

> We present Sacred GF16/TF3, a family of φ-based numerical formats designed for efficient ternary neural network computation. Standard floating-point formats use powers of 2 for exponent bias and mantissa precision, which are suboptimal for ternary computing. Our designs use (1) **GF16** — 6-bit exponent, 9-bit mantissa with exp=6,mant=9 achieving 37.8% LUT reduction vs FP32, (2) **TF3** — ternary floating-point packing 8 weights in 16 bits (vs 16 bits for 1 FP32 weight), and (3) **φ-Distance Metric** — $|a - b| / \\phi$ for similarity computation. Implementation in pure Zig with hardware verification on XC7A100T FPGA shows 19.6% LUT utilization for GF16 arithmetic units and 1.2W power consumption at 100MHz. We provide formal proof that TF3 encoding preserves 98.4% information compared to FP32 (Theorem 1), demonstrate 8× memory bandwidth reduction (16 bits → 2 bits per weight fetch), and achieve 1200 tokens/second inference throughput on CPU.

---

## Part III: ASCII Diagram Guidelines

### III.1 Box Drawing Characters

Use the following box drawing characters for consistent diagrams:

```
┌─────────────┐
│   Header    │
├─────────────┤
│   Content   │
└─────────────┘
```

**Unicode chart:**
- `┌ ┐ └ ┘` — Corners
- `├ ┤ ┬ ┴` — T-junctions
- `│ ─` — Lines
- `═ ║ ╬ ╩` — Double lines (for emphasis)

### III.2 Architecture Diagram Template

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         [SYSTEM NAME]                                     │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  Input: [Input Specification]                                                │
│         ┌────────────┐                                                      │
│         │  Input_A   │                                                      │
│         └─────┬──────┘                                                      │
│               │                                                             │
│         ┌─────┴──────┐                                                      │
│         │  Input_B   │                                                      │
│         └─────┬──────┘                                                      │
│               │                                                             │
│               ▼                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │  [PROCESSING UNIT NAME]                                             │    │
│  │  ┌─────────────────────────────────────────────────────────────────┐  │    │
│  │  │  [Operation 1]                                                 │  │    │
│  │  │  [Operation 2]                                                 │  │    │
│  │  └─────────────────────────────────────────────────────────────────┘  │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│               │                                                             │
│               ▼                                                             │
│  Output: [Output Specification]                                               │
│                                                                             │
│  [Performance Metrics]:                                                     │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │  [Metric 1]: [Value 1]                                             │    │
│  │  [Metric 2]: [Value 2]                                             │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### III.3 Bit Layout Diagram Template

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         [FORMAT NAME] BIT LAYOUT                             │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  [Total Bits] bits:                                                          │
│  ┌──────┬─────────────────────────────────────┬──────┐                    │
│  │ Sign │        [Field 2 Name]               │ [Field 3] │                 │
│  │ 1 bit│        [bits]                        │ [bits]    │                 │
│  └──────┴─────────────────────────────────────┴──────┘                    │
│                                                                             │
│  Encoding:                                                                   │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │  [Value 1]: [Binary encoding] → [Decimal value]                    │    │
│  │  [Value 2]: [Binary encoding] → [Decimal value]                    │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
│                                                                             │
│  Range:                                                                      │
│  - Minimum: [Value]                                                         │
│  - Maximum: [Value]                                                         │
│  - Precision: [Value]                                                       │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Part IV: Quantitative Claims

### IV.1 Claim Statement Template

Every quantitative claim MUST follow this format:

```
[Component] achieves [metric] of [value] on [benchmark],
which represents [X]% improvement/[Y]× speedup over [baseline].
```

### IV.2 Claim Examples (Good vs Bad)

**Good Claim:**
> HSLM achieves perplexity of 130.2 on TinyStories validation set,
> which represents 2.3× faster convergence than standard scaling (185K vs 121K steps).

**Bad Claim:**
> HSLM trains faster than baselines. (No numbers!)

### IV.3 Required Metrics for Different Components

| Component | Required Metrics | Optional Metrics |
|-----------|------------------|-------------------|
| Model | PPL, params, tokens/sec | Loss curves, training time |
| Numerical Format | Bits, range, precision | Comparison with FP32/BF16 |
| FPGA | LUT%, DSP%, Power | Frequency, throughput |
| VSA | Ops/sec, accuracy, noise resilience | Dimension, binding time |

---

## Part V: Algorithm/Proof Box Template

### V.1 Algorithm Box

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  Algorithm 1: [Algorithm Name]                                              │
├─────────────────────────────────────────────────────────────────────────────┤
│  Input: [Input parameters]                                                  │
│  Output: [Output value]                                                     │
│                                                                             │
│  1: [Step 1 description]                                                   │
│  2: [Step 2 description]                                                   │
│  3: [Step 3 description]                                                   │
│  ...                                                                       │
│  N: [Step N description]                                                   │
│                                                                             │
│  Complexity: O([big-O notation])                                            │
│  Memory: O([memory usage])                                                 │
└─────────────────────────────────────────────────────────────────────────────┘
```

### V.2 Theorem/Proof Box

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  Theorem 1: [Theorem Name]                                                 │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  Let [definitions]. Then [statement to prove].                              │
│                                                                             │
│  Proof:                                                                    │
│  [Proof steps, referencing lemmas as needed]                                │
│                                                                             │
│  ∎                                                                         │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Part VI: Figure Guidelines

### VI.1 Figure Naming Convention

- Use descriptive names: `B00X-FigN_[short_description].png`
- X = bundle number (001-007)
- N = figure number (1, 2, 3...)
- Short description: 3-5 words, snake_case

**Examples:**
- `B005-Fig1_type_hierarchy.png`
- `B006-Fig2_phi_heatmap.png`
- `B004-Fig3_hslm_block_architecture.png`

### VI.2 Figure Reference Format

In markdown:
```markdown
**Figure 1: [Figure Title]**

![B00X-Fig1_filename](figures/B00X-Fig1_filename.png)

**Key Observations:**
- [Observation 1]
- [Observation 2]
- [Observation 3]
```

### VI.3 Required Figures by Bundle Type

| Bundle Type | Required Figures | Recommended Tools |
|-------------|-----------------|-------------------|
| Model | Architecture, Training Curve | TikZ, draw.io |
| Numerical | Bit Layout, Comparison Table | TikZ, Excel |
| FPGA | Resource Utilization, Floorplan | Vivado reports, custom |
| Compiler | Pipeline Diagram, AST | GraphViz, custom |
| VSA | Operation Visualization, Noise Resilience | Matplotlib, Python |

---

## Part VII: Reproducibility Checklist

### VII.1 Code Availability

- [ ] Code repository URL (GitHub/GitLab)
- [ ] Commit hash/tag for exact version
- [ ] License information (SPDX identifier)
- [ ] README with build instructions

### VII.2 Data Availability

- [ ] Dataset name and source
- [ ] Preprocessing steps documented
- [ ] Train/validation/test split
- [ ] Checksums for data files

### VII.3 Experimental Setup

- [ ] Hardware/Software environment
  - [ ] CPU/GPU model
  - [ ] OS version
  - [ ] Compiler version
  - [ ] Key library versions
- [ ] Hyperparameters (table format)
- [ ] Random seeds (for all experiments)
- [ ] Training time (wall-clock)
- [ ] Number of runs (for error bars)

### VII.4 Results Reporting

- [ ] Mean ± standard deviation (or confidence intervals)
- [ ] Number of experimental runs
- [ ] Statistical significance tests (where applicable)
- [ ] Comparison with baselines (fair comparison ensured)

---

## Part VIII: LaTeX Mathematical Notation

### VIII.1 Common Mathematical Notation

| Concept | Notation | Example |
|---------|----------|---------|
| Sets | $\mathcal{X}$ | $\mathcal{X} = \mathbb{R}^d$ |
| Sequences | $x_{1:T}$ | $x_{1:T} = (x_1, \dots, x_T)$ |
| Vectors | $\mathbf{x}$ | $\mathbf{x} \in \mathbb{R}^d$ |
| Matrices | $\mathbf{W}$ | $\mathbf{W} \in \mathbb{R}^{d \times k}$ |
| Functions | $f: \mathcal{X} \to \mathcal{Y}$ | Neural network mapping |
| Gradients | $\nabla_{\theta} \mathcal{L}$ | Gradient w.r.t. parameters |

### VIII.2 Trinity-Specific Notation

| Concept | Notation | Description |
|---------|----------|-------------|
| Golden ratio | $\phi = (1+\sqrt{5})/2$ | Fundamental constant |
| Sacred gamma | $\gamma = \phi^{-3}$ | Scaling exponent |
| Sacred threshold | $\tau = \phi^{-1}$ | Consciousness gate |
| Trinity identity | $\phi^2 + \phi^{-2} = 3$ | Core identity |
| VSA vectors | $\mathbf{v} \in \{-1,0,1\}^d$ | Ternary vectors |

---

## Part IX: Common Pitfalls to Avoid

### IX.1 Writing Issues

❌ **Vague claims:** "Our system is fast."
✅ **Specific claims:** "Our system achieves 1200 tokens/sec on CPU."

❌ **Missing numbers:** "Significant improvement."
✅ **Quantified:** "2.3× faster convergence (185K → 121K steps)."

❌ **Undefined terms:** "The sacred constant provides optimal scaling."
✅ **Defined:** "Sacred gamma γ = φ⁻³ ≈ 0.236 provides gradient amplification of 3.21×."

### IX.2 Documentation Issues

❌ **Missing figures:** "See code for architecture."
✅ **Architecture diagram:** ASCII art or PNG included.

❌ **Unreproducible:** "Trained on TinyStories."
✅ **Complete setup:** "TinyStories subset (10M tokens), train/val split 90/10, seed=42."

❌ **No comparison:** "Better than BitNet."
✅ **Fair comparison:** "1.58-bit weights vs BitNet's 1.58-bit, same model size (117M params)."

---

## Part X: Quality Checklist

Before publishing a Zenodo bundle, verify:

- [ ] Abstract is 200-500 words with quantitative claims
- [ ] At least 3 figures with descriptive captions
- [ ] All algorithms in boxed format
- [ ] All theorems with complete proofs
- [ ] Tables with proper formatting
- [ ] Code repository linked with commit hash
- [ ] License specified (preferably CC-BY-4.0)
- [ ] DOI registered and linked
- [ ] Version number and change log included

---

## Part XI: Example Complete Document Structure

```markdown
# [Bundle Name] v[X.X]

**Authors:** [Name]
**DOI:** 10.5281/zenodo.XXXXXX
**License:** CC-BY-4.0
**Publication Date:** YYYY-MM-DD
**Version:** X.X ([Description])

---

## Abstract

[3-5 paragraph abstract following template in Part II]

---

## 1. Architecture

### 1.1 [Component 1]

[Description + ASCII diagram]

**Key Observations:**
- [Observation 1]
- [Observation 2]

### 1.2 [Component 2]

[Description + ASCII diagram]

---

## 2. Technical Specifications

### 2.1 [Specification 1]

[Detailed technical content]

### 2.2 [Specification 2]

[Detailed technical content]

---

## 3. Experimental Results

### 3.1 [Experiment 1]

| Metric | Value | Baseline | Improvement |
|--------|-------|----------|-------------|
| [Name] | [Value] | [Value] | [X%] |

### 3.2 [Experiment 2]

[Results with figures]

---

## 4. Formal Proofs

### 4.1 Theorem 1

[Statement + Proof]

### 4.2 Lemma 1

[Supporting lemma + proof]

---

## 5. Reproducibility

### 5.1 Code Availability

[Repository links]

### 5.2 Experimental Setup

[Hardware, software, hyperparameters]

---

## Appendix A: [Additional Content]

[Supplementary material]

---

**φ² + 1/φ² = 3 | TRINITY**
```

---

## Part XII: Publication-Ready Examples

The following bundles demonstrate these best practices:
- **B005** (Tri Language): Linear types, effects, codegen
- **B006** (Sacred GF16/TF3): Numerical formats, bit layouts
- **B007** (VIBEE Compiler): Pipeline diagrams, algorithm boxes

Use these as templates for new bundle descriptions.

---

**Document Control:** ZENODO-TEMPLATE-001
**Status:** Complete — v1.0
**φ² + 1/φ² = 3 | TRINITY**
