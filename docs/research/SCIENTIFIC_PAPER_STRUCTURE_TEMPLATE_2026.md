# Scientific Paper Structure Template 2026

**For Trinity Scientific Publications (NeurIPS, ICLR, MLSys, JMLR, Nature/Science)**

**Date:** 2026-03-26
**Version:** 1.0.0
**Purpose:** Standardized structure for ML/CS research papers

---

## Complete Paper Structure (8-12 pages, excluding references)

```
1. Title (1 line)
2. Authors & Affiliations
3. Abstract (≤200 words)
4. Introduction (1 page)
5. Related Work (1 page)
6. Methods (2-4 pages)
7. Experiments (2-3 pages)
8. Results & Discussion (1-2 pages)
9. Limitations (1/2 page)
10. Broader Impact (1/4 page)
11. Ethics Statement (1/4 page)
12. Conclusion (1/4 page)
13. Acknowledgments (1/8 page)
14. References & Appendix
```

---

## Section-by-Section Guide

### 1. Title

**Requirements:**
- Concise, descriptive, ≤15 words
- Avoid: "Novel", "Efficient", "Improved"
- Include: Key technique, domain, contribution

**Good Examples:**
- "Ternary Neural Networks: 20× Compression with φ-Based Quantization"
- "Zero-DSP FPGA Inference for Language Models"
- "Consciousness-Gated Backpropagation in Dual-System Architectures"

**Bad Examples:**
- "A Novel Efficient Method for LLM Compression" ❌ (vague)
- "Very Fast Training" ❌ (subjective)

---

### 2. Authors & Affiliations

**Format:**
```
Author One¹, Author Two²
¹Department of Computer Science, University Name
²Institute for AI Research, Country

email@institution.edu
```

**Trinity Format:**
```
Dmitrii Vasilev
Trinity Research Institute
dmitrii@trinity.ai
```

---

### 3. Abstract (≤200 words)

**Structure (4-5 sentences):**

1. **Problem:** What problem are you solving?
2. **Approach:** What is your key technique?
3. **Results:** What are your main findings (quantitative)?
4. **Implication:** Why does this matter?

**Template:**

```markdown
[Domain] tasks require [challenge]. Current approaches [limitation]. We propose [technique],
which [key innovation]. Our method [mechanism]. Evaluated on [dataset], we achieve [metric]
improvement of [X%] compared to [baseline], with [secondary benefit]. This demonstrates
[implication for field].
```

**Trinity HSLM Example:**

```
Large language models require massive memory and compute, limiting edge deployment.
Current ternary quantization loses >20% accuracy. We propose HSLM (Hybrid Sacred Language Model),
which uses φ-based scaling and sacred initialization for ternary weights. Our method integrates
T-JEPA self-supervised learning with consciousness-gated backpropagation. Evaluated on SlimPajama,
HSLM-125M achieves 124.7 PPL (+8.6% vs GPT-3) with 20× memory compression and 4× power reduction.
This demonstrates that mathematically-inspired ternary computing can achieve floating-point
performance at a fraction of the cost.
```

---

### 4. Introduction (1 page)

**Paragraph Structure:**

**Paragraph 1: Context & Motivation**
- Broad context: Why is this problem important?
- Specific challenge: What is the gap?
- Stakes: What happens if we don't solve it?

**Paragraph 2: Current Approaches & Limitations**
- Brief survey of existing methods
- Key limitations (2-3 specific issues)
- Why current methods fall short

**Paragraph 3: Our Approach**
- High-level description of our technique
- Key innovations (2-3 bullet points)
- Why our approach addresses the limitations

**Paragraph 4: Contributions**
- Numbered list of 3-4 contributions
- Each contribution: What + Why it matters
- "We show" for experimental contributions

**Paragraph 5: Roadmap**
- "The rest of this paper is organized as follows..."
- Brief section preview (1 sentence per section)

---

### 5. Related Work (1 page)

**Organize by Theme:**

```markdown
### 5.1 Quantization Approaches
Post-training quantization [Citation], quantization-aware training [Citation].
Ternary networks [Citation] offer 1.58× density but lose accuracy.

### 5.2 Self-Supervised Learning
Masked language modeling [Citation], contrastive learning [Citation].
JEPA [Citation] uses latent prediction.

### 5.3 Neuromorphic Computing
Spiking neural networks [Citation], analog accelerators [Citation].
FPGA implementations [Citation] face resource constraints.

### 5.4 Mathematical Design
Golden ratio in ML [Citation], sacred constants [Citation].
Connection to information theory [Citation].
```

**Citation Guidelines:**
- Cite the original paper (not secondary sources)
- Cite recent work (last 3 years preferred)
- Cite competing methods
- Cite foundational work

---

### 6. Methods (2-4 pages)

**Structure:**

### 6.1 Preliminaries
- Notation and definitions
- Background concepts
- Problem formulation

### 6.2 Proposed Method
- Overview diagram (Figure 1)
- Algorithm 1: Main procedure
- Algorithm 2: Key subroutine

### 6.3 Theoretical Analysis
- Theorem 1: Main result
- Proof sketch (full proof in appendix)
- Corollary 1: Practical implication

**Writing Guidelines:**
- Use pseudocode or actual code for algorithms
- Define all notation before use
- Include complexity analysis (Big-O)
- State assumptions explicitly

---

### 7. Experiments (2-3 pages)

**Structure:**

### 7.1 Experimental Setup
- Datasets: Name, size, split
- Baselines: Methods compared, why selected
- Metrics: Primary metric, secondary metrics
- Implementation: Hardware, software, hyperparameters

### 7.2 Main Results
- Table 1: Comparison with baselines
- Statistical significance: p-values, confidence intervals
- Effect sizes: Cohen's d or similar

### 7.3 Ablation Studies
- Table 2: Component ablation
- Each ablation: What, Why, Result

### 7.4 Analysis
- Figure 2: Visualization of key phenomenon
- Qualitative examples
- Error analysis (when applicable)

---

### 8. Results & Discussion (1-2 pages)

**Structure:**

**Quantitative Results:**
- Main findings from Table 1
- Statistical significance
- Effect size interpretation

**Qualitative Analysis:**
- What explains the results?
- Connection to theory
- Surprising findings

**Comparison to Related Work:**
- How do we differ from [Citation]?
- Why do we outperform [Citation]?

**Limitations Preview:**
- Brief mention of limitations (full section later)
- Honest discussion of boundary conditions

---

### 9. Limitations (1/2 page)

**Required by NeurIPS, ICLR, MLSys**

**Format:**

```markdown
### 9.1 Dataset Limitations
- SlimPajama inherits internet biases (documented in bias assessment)
- No multilingual evaluation (future work)

### 9.2 Computational Limitations
- Training requires 2 weeks on Apple M1 Max (not GPU-accessible)
- FPGA synthesis requires Xilinx Vivado (not open source)

### 9.3 Scope of Results
- Evaluated on 125M parameter model (scaling unclear)
- Ternary benefits may diminish at larger scales

### 9.4 Assumptions
- Assumes isotropic data distribution
- Assumes stationary data distribution
```

**Honesty Guidelines:**
- Don't hide limitations
- Don't overgeneralize
- Distinguish between "we show" and "we believe"
- Acknowledge when results are preliminary

---

### 10. Broader Impact (1/4 page)

**Required by NeurIPS, ICLR**

**Format:**

```markdown
### Positive Impacts
1. **Edge AI Accessibility:** 20× memory compression enables LLMs on phones
2. **Environmental Sustainability:** 4× power reduction = 75% less carbon
3. **Open Science:** All code/data released under permissive licenses

### Potential Negative Impacts
1. **Lowered Barriers:** Efficient models easier to deploy for spam/misinformation
   - **Mitigation:** Responsible disclosure, watermarking research
2. **Training Centralization:** Training still requires massive compute
   - **Mitigation:** Documenting CPU-only training path
```

**See:** `BROADER_IMPACT_STATEMENT_TEMPLATE.md` for full template

---

### 11. Ethics Statement (1/4 page)

**Required by ICLR**

**Format:**

```markdown
### Data Ethics
- No personal data in training corpus (SlimPajama is public text)
- PII scanning: Presidio + manual review
- Dataset license: ODC-BY (open database)

### Bias & Fairness
- Dataset inherits internet biases (documented)
- Subgroup analysis: Gender, culture, language PPL reported
- Effect sizes: All TINY (d < 0.2), no practically significant bias

### Environmental Impact
- Training: ~100 kWh (~50 kg CO2e, offset via donations)
- Inference: 1.2W @ 100 MHz (4× better than baseline)
```

**See:** `BIAS_ASSESSMENT_FRAMEWORK_2026.md` for full framework

---

### 12. Conclusion (1/4 page)

**Structure:**

```markdown
We presented [method], which [key innovation]. Our results show:
1. [Finding 1]: [Quantitative result]
2. [Finding 2]: [Quantitative result]
3. [Finding 3]: [Qualitative insight]

Future work includes [direction 1], [direction 2], and [direction 3].

This work demonstrates [implication], opening new avenues for [domain].
```

**Guidelines:**
- Restate contributions (don't introduce new ones)
- Summarize key findings (2-3 sentences)
- Discuss future directions (1-2 sentences)
- End with broad impact statement

---

### 13. Acknowledgments (1/8 page)

**Format:**

```markdown
We thank [reviewers] for helpful feedback. This work was supported by
[funding agencies]. Computational resources provided by [institution].
We thank the Zig Software Foundation for the amazing compiler.
```

**Trinity Acknowledgments:**

```markdown
We thank the anonymous reviewers for their constructive feedback.
This work was supported by Trinity Research Institute self-funding.
Computational resources: Apple M1 Max (32GB RAM).
We thank:
- Zig Software Foundation for the amazing compiler
- HuggingFace for model hosting
- Zenodo for permanent archival
- The open-source community for inspiration
```

---

### 14. References & Appendix

**References:**
- Use BibTeX format
- Include DOIs where available
- Alphabetical by first author surname
- 20-40 references for typical paper

**Appendix:**
- A. Full proofs
- B. Additional experimental results
- C. Implementation details
- D. Reproducibility checklist
- E. Broader Impact extended
- F. Ethics statement extended
- G. Data and code availability

---

## Conference-Specific Variations

### NeurIPS 2026

**Page Limit:** 8 pages + unlimited appendices
**Review Format:** Single-blind
**Required:** Broader Impact, Ethics Statement, Reproducibility Checklist
**Optional:** Artifact submission, code review

### ICLR 2027

**Page Limit:** 8 pages + unlimited appendices
**Review Format:** Double-blind (anonymize citations)
**Required:** Ethics Statement, Broader Impact
**Optional:** Artifact evaluation

### MLSys 2026

**Page Limit:** 8 pages + unlimited appendices
**Review Format:** Double-blind
**Required:** Artifact Appendix
**Optional:** Artifact evaluation (badge)

### JMLR

**Page Limit:** No limit (typically 20-40 pages)
**Review Format:** Single-blind
**Required:** Reproducibility statement, code availability

### Nature/Science

**Page Limit:** 2-3 pages (Article) or 6-10 pages (Letter)
**Review Format:** Single-blind
**Required:** Methods section, data availability

---

## Writing Guidelines

### Style Guidelines

1. **Clarity over cleverness**
   - Use simple words when possible
   - Avoid jargon unless defined
   - Explain technical terms

2. **Active voice preferred**
   - "We show" not "It is shown"
   - "Our method achieves" not "It is achieved by our method"

3. **Concrete over abstract**
   - "We improve PPL by 8.6%" not "We significantly improve performance"
   - "Training takes 2 weeks" not "Training is fast"

4. **Honest over hype**
   - "We improve" not "We dramatically improve"
   - "Our method is competitive" not "Our method is state-of-the-art"

### Common Mistakes to Avoid

❌ **Don't say:** "Our method is novel"
✅ **Do say:** "Our method differs from prior work in X"

❌ **Don't say:** "We achieve state-of-the-art results"
✅ **Do say:** "We outperform baseline by X% on Y metric"

❌ **Don't say:** "Our method is efficient"
✅ **Do say:** "Our method reduces memory by 20×"

❌ **Don't say:** "Results are impressive"
✅ **Do say:** "Results show X% improvement (p<0.001, d=0.8)"

---

## LaTeX Template

```latex
\documentclass{article}

% Packages
\usepackage[preprint]{neurips_2026}
\usepackage[utf8]{inputenc}
\usepackage[T1]{fontenc}
\usepackage{hyperref}
\usepackage{url}
\usepackage{booktabs}
\usepackage{amsfonts}
\usepackage{amsmath}
\usepackage{amssymb}
\usepackage{nicefrac}
\usepackage{microtype}
\usepackage{graphicx}

% Title
\title{Your Title Here: Subtitle if Needed}

% Authors
\author{
  Author One \\
  Department \\
  Institution \\
  \texttt{email@institution.edu} \\
  \And
  Author Two \\
  Department \\
  Institution \\
  \texttt{email@institution.edu}
}

% Abstract
\begin{abstract}
Your abstract here (≤200 words).
\end{abstract}

% Document
\begin{document}

\maketitle

\section{Introduction}
...

\section{Related Work}
...

\section{Methods}
...

\section{Experiments}
...

\section{Results}
...

\section{Limitations}
...

\section{Broader Impact}
...

\section{Ethics Statement}
...

\section{Conclusion}
...

\section*{Acknowledgments}
...

\bibliographystyle{plain}
\bibliography{references}

\end{document}
```

---

## Submission Checklist

Before submitting:

- [ ] Title is descriptive and ≤15 words
- [ ] Abstract is ≤200 words, 4-5 sentences
- [ ] Introduction clearly states contributions
- [ ] Related work cites appropriate papers
- [ ] Methods section has algorithms
- [ ] Experiments have statistical tests
- [ ] Results are reproducible (configs provided)
- [ ] Limitations section is honest
- [ ] Broader Impact statement included
- [ ] Ethics statement included
- [ ] All figures are readable (300 DPI)
- [ ] All tables have captions
- [ ] References are complete (DOIs included)
- [ ] Code is publicly available
- [ ] Data is publicly available
- [ ] Supplementary materials uploaded
- [ ] PDF is under page limit
- [ ] Anonymized (for double-blind venues)

---

**φ² + 1/φ² = 3 | TRINITY**

**Generated:** 2026-03-26
**Version:** 1.0.0
**Status:** ✅ Complete Template
