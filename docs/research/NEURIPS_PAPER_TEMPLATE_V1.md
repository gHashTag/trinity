# NeurIPS/ICLR Paper Template v1.0
## Trinity S³AI Publication Guide

**Maintained**: Trinity S³AI Research  
**Last Updated**: 2026-03-26  
**Target**: NeurIPS 2026, ICLR 2027  
**License**: CC-BY-4.0

---

## Paper Structure (NeurIPS Format)

### Page Allocation (8 pages + unlimited references)

| Section | Pages | Content |
|---------|-------|---------|
| Title | 0.1 | Title, authors, affiliations |
| Abstract | 0.3 | 150-250 words, structured |
| Introduction | 1.0 | Problem, gap, solution, results |
| Related Work | 1.0 | Literature review, positioning |
| Methods | 2.5 | Approach, algorithms, theory |
| Experiments | 2.0 | Setup, baselines, results |
| Discussion | 0.5 | Interpretation, limitations |
| Conclusion | 0.1 | Summary, future work |
| **Total** | **~7.5** | References unlimited |

---

## 1. Title Page

### 1.1 Title Guidelines

**Good Examples**:
- "Ternary Neural Networks: Efficient Inference via {-1, 0, +1} Quantization"
- "Sacred Scaling: φ-Based Attention for Ternary Language Models"
- "TRI-27: A Ternary Instruction Set for FPGA Inference"

**Bad Examples**:
- "Our New Neural Network" ❌ (too generic)
- "A Study of Ternary Computing" ❌ (vague)
- "Trinity: The Best Model Ever" ❌ (hyperbolic)

### 1.2 Author Block

```
Dmitrii Vasilev¹
¹Trinity S³AI Research
email@example.com

Abstract text...
```

---

## 2. Abstract Structure

### 2.1 5-Sentence Formula

```
Sentence 1: [MOTIVATION] Problem statement + why it matters
Sentence 2: [CONTRIBUTION] What we propose (novel method)
Sentence 3: [METHODS] Key technical approach
Sentence 4: [RESULTS] Quantitative outcomes
Sentence 5: [SIGNIFICANCE] Broader impact
```

### 2.2 Example (HSLM Paper)

> **Motivation**: Neural network inference on edge devices is severely constrained by memory bandwidth and computational resources.
> **Contribution**: We present HSLM, a 1.95M parameter language model with ternary {-1, 0, +1} weights and φ-based attention scaling.
> **Methods**: The model uses sacred scaling (1/81^φ⁻³ ≈ 0.354) and zero-DSP ternary MAC operations optimized for XC7A100T FPGA deployment.
> **Results**: HSLM achieves PPL=12.5 on TinyStories with 386KB memory (20× compression vs FP32) and 70 tokens/sec inference at 0.5W power.
> **Significance**: This enables sub-watt language model deployment on resource-constrained hardware without sacrificing accuracy, opening new applications for edge AI.

### 2.3 Word Count

| Section | Min | Max | Target |
|---------|-----|-----|--------|
| Title | 5 | 15 | 10 |
| Abstract | 150 | 250 | 200 |
| Main body | 3500 | 4500 | 4000 |

---

## 3. Introduction

### 3.1 Structure (4 paragraphs)

**Paragraph 1: Context & Motivation**
- Broad field context
- Specific problem
- Why it matters

**Paragraph 2: Gap & Challenges**
- Current approaches
- Their limitations
- What's missing

**Paragraph 3: Our Approach**
- Brief description of method
- Key insights
- Novel contributions

**Paragraph 4: Results Summary**
- Main findings
- Quantitative improvements
- Broader implications

### 3.2 Example Opening

> "Neural language models have achieved remarkable performance on NLP tasks [Vaswani et al., 2017; Brown et al., 2020], but their deployment on edge devices remains challenging due to memory and compute constraints. Quantization to 8-bit or 4-bit weights [Jacob et al., 2018; Nagel et al., 2020] reduces memory but requires dedicated hardware for efficient inference."

---

## 4. Related Work

### 4.1 Organize by Theme

```
4.1 Quantization Methods
  - Post-training quantization
  - Quantization-aware training
  - Ternary networks

4.2 Efficient Architectures
  - Pruning [Han et al., 2015]
  - Knowledge distillation [Hinton et al., 2015]
  - Neural architecture search [Zoph & Le, 2017]

4.3 Hardware Acceleration
  - FPGA inference [Zhang et al., 2019]
  - ASIC designs [Jouppi et al., 2017]
  - Edge TPUs [Jain et al., 2018]
```

### 4.2 Citation Format

**NeurIPS Style**:
```latex
\cite{kanerva2009hyperdimensional} → [Kanerva, 2009]
```

**Reference Entry**:
```latex
@inproceedings{kanerva2009hyperdimensional,
  title={Hyperdimensional computing},
  author={Kanerva, Pentti},
  booktitle={Cognitive Computation},
  year={2009}
}
```

---

## 5. Methods

### 5.1 Notation Section

Start with clear notation table:

```
Notation:
- d: Model dimension (243)
- h: Number of heads (3)
- n: Context length (81)
- φ: Golden ratio (1.618...)
- γ: Sacred gamma (φ⁻³ ≈ 0.236)
- Q, K, V: Query, Key, Value matrices
```

### 5.2 Algorithm Boxes

Use clear pseudocode:

```
Algorithm 1: Sacred Attention Forward Pass
Input: X ∈ ℝ^{n×d} (input sequence)
Output: O ∈ ℝ^{n×d} (output sequence)

1: Q ← XW_Q, K ← XW_K, V ← XW_V  // Linear projections
2: S ← QK^T / d^γ                 // Sacred scaling
3: A ← softmax(S)                 // Attention weights
4: O ← AV                         // Value aggregation
5: return O + X                   // Residual connection
```

### 5.3 Theorem Statements

**Format**:
```
Theorem 1 (Convergence): Under smoothness assumptions,
gradient descent with sacred scaling converges at rate
O((S_std/S_sacred)^t).

Proof: See Appendix A. ∎
```

---

## 6. Experiments

### 6.1 Setup Section

```
6.1 Datasets
  - TinyStories: 2.1M stories, 7M tokens
  - SNLI: 570K NLI pairs
  - MNIST: 60K training, 10K test

6.2 Baselines
  - GPT-2 Small (FP32)
  - Binary Transformer (2-bit weights)
  - Ternary Transformer (no sacred scaling)

6.3 Metrics
  - Perplexity (PPL)
  - Accuracy (%)
  - Memory (KB)
  - Inference (tokens/sec)
  - Power (W)
```

### 6.2 Result Tables

**Table 1: Main Results**

| Model | PPL ↓ | Mem (KB) | Tok/s/W | Power (W) |
|-------|-------|----------|---------|-----------|
| GPT-2 FP32 | 8.2 | 7600 | 132 | 15W |
| Binary | 14.3 | 1900 | 89 | 8W |
| **HSLM** | **12.5** | **386** | **140** | **0.5W** |

### 6.3 Ablation Studies

| Component | PPL | Δ PPL | Memory |
|-----------|-----|-------|--------|
| Full model | 12.5 | — | 386 KB |
| w/o sacred scale | 14.8 | +2.3 | 386 KB |
| w/o ternary | 11.2 | -1.3 | 7600 KB |
| w/o φ-RoPE | 13.1 | +0.6 | 386 KB |

---

## 7. Discussion

### 7.1 Interpretation

Address the "why" behind results:
- Why does sacred scaling help?
- When does it fail?
- What are the trade-offs?

### 7.2 Limitations

Be honest about weaknesses:
```
Limitations:
1. Results shown on TinyStories only
2. FPGA synthesis not yet verified on hardware
3. Scaling to larger models (>100M params) untested
```

### 7.3 Broader Impact

Consider ethical implications:
```
Broader Impact:
- Enables edge AI deployment (positive)
- Reduces computational cost (positive)
- May enable surveillance applications (concern)
```

---

## 8. Figures & Tables

### 8.1 Figure Guidelines

**Figure 1: Architecture Diagram**
- Show model components
- Use consistent colors
- Label all components

**Figure 2: Training Curves**
- X-axis: Training steps
- Y-axis: PPL, loss, or accuracy
- Include confidence intervals

**Figure 3: Ablation Results**
- Bar chart comparing variants
- Error bars for std dev

### 8.2 Table Guidelines

- Use booktabs (horizontal lines only)
- Align numbers on decimal point
- Include ± for std dev

---

## 9. LaTeX Template

### 9.1 Preamble

```latex
\documentclass{article}

% NeurIPS style
\usepackage[preprint]{neurips_2024}

% Packages
\usepackage[utf8]{inputenc}
\usepackage[T1]{fontenc}
\usepackage{hyperref}
\usepackage{url}
\usepackage{booktabs}
\usepackage{amsfonts}
\usepackage{amsmath}
\usepackage{amssymb}
\usepackage{nicefrac}

% Theorems
\newtheorem{theorem}{Theorem}
\newtheorem{lemma}[theorem]{Lemma}
\newtheorem{corollary}[theorem]{Corollary}
\newtheorem{proposition}[theorem]{Proposition}
\theoremstyle{definition}
\newtheorem{definition}{Definition}

\title{Ternary Neural Networks: Efficient Inference}

\author{
  Dmitrii Vasilev \\
  Trinity S³AI Research \\
  \texttt{email@example.com}
}

\begin{document}

\maketitle

\begin{abstract}
Your abstract here...
\end{abstract}

\section{Introduction}
...

\section{Related Work}
...

\section{Methods}
...

\section{Experiments}
...

\section{Discussion}
...

\bibliographystyle{plain}
\bibliography{references}

\end{document}
```

---

## 10. Submission Checklist

### 10.1 Pre-Submission

- [ ] Abstract follows 5-sentence structure
- [ ] All figures are 300 DPI or higher
- [ ] All tables properly formatted
- [ ] References complete and consistent
- [ ] Page limit respected (8 pages + refs)
- [ ] Supplementary material prepared
- [ ] Code anonymized (for double-blind)
- [ ] PDF under 50MB

### 10.2 Common Mistakes

| Mistake | Impact | Fix |
|---------|--------|-----|
| Abstract > 250 words | Auto-truncated | Edit to 150-250 words |
| No related work section | Desk rejection | Add comprehensive review |
| Missing baselines | Reviewer complaint | Compare to SOTA |
| No ablation studies | Weak contribution | Add component analysis |
| Unclear notation | Confusion | Add notation table |

---

## 11. NeurIPS 2026 Timeline

| Milestone | Date | Action |
|-----------|------|--------|
| May 15, 2026 | Abstract deadline | Submit 250-word abstract |
| May 22, 2026 | Full paper deadline | Submit 8-page paper |
| June 26, 2026 | Reviews released | Read reviewer feedback |
| July 10, 2026 | Rebuttal due | Submit response |
| Sept 6-12, 2026 | Conference | Present (if accepted) |

---

## 12. References

1. NeurIPS 2024. "Format and Submission Guidelines". https://neurips.cc/
2. ICLR 2025. "Paper Submission Instructions". https://iclr.cc/
3. Vaswani et al. (2017). "Attention is All You Need". NeurIPS.

---

**φ² + 1/φ² = 3 | TRINITY S³AI**
