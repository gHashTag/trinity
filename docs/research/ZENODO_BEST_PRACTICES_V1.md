# Zenodo Best Practices — Scientific Publication Standards

**Version:** 1.0.0
**Date:** 2026-03-26
**Author:** Dmitrii Vasilev
**Purpose:** Comprehensive guide for Zenodo publication following FAIR principles
**Related:** docs/research/ZENODO_ABSTRACT_TEMPLATES_V1.md, docs/research/FORMAL_PROOFS_TRINITY_V1.md

---

## Abstract

This document provides best practices for Zenodo scientific publication, covering metadata structure, abstract formatting, reproducibility artifacts, statistical validation, and community standards. All recommendations are aligned with FAIR principles (Findable, Accessible, Interoperable, Reusable) and MLSys reproducibility guidelines.

---

## Part I: Metadata Structure

### 1. Title Format

**Formula:** `[Bundle ID]: [Component Name] — [Key Innovation] [Technical Spec]`

**Examples:**
- B001: Ternary Neural Networks — HSLM-1.95M Scientific Framework
- B002: Sacred Attention Mechanism — φ-Based Scaling Implementation
- B003: T-JEPA Architecture — Ternary JEPA with Consciousness Gate

**Rules:**
- Length: 50-150 characters
- Include version number in technical spec (e.g., 1.95M parameters)
- Use em-dash (—) not hyphen (-)
- No abbreviations except well-known (HSLM, JEPA, FPGA)

### 2. Authors and Affiliations

**JSON Structure:**
```json
"creators": [
  {
    "name": "Last, First",
    "orcid": "0000-0000-0000-0000",
    "affiliation": "Institution Name",
    "type": "Person"
  }
]
```

**Best Practices:**
- Include ORCID for author identification (FAIR principle)
- Use institutional affiliation not personal
- Order: primary contributor first

### 3. Keywords Structure

**Hierarchy:**
1. **General Categories** (Zenodo standard): Artificial Intelligence, Computer Simulation
2. **Specific Terms**: ternary computing, balanced ternary, HSLM
3. **Metrics**: 1.58-bit LLM, perplexity, memory compression
4. **Algorithms**: sacred attention, T-JEPA, cosine learning rate
5. **Implementation**: Zig, pure Zig, zero dependencies
6. **ACM Categories**: Computing methodologies--Neural networks
7. **ArXiv Categories**: cs.AI, cs.LG, cs.AR

**Minimum:** 10 keywords
**Maximum:** 25 keywords
**Balance:** 30% general, 40% specific, 30% technical

---

## Part II: Abstract Format

### 5-Sentence Formula

**Sentence 1:** Problem statement (what gap exists)
**Sentence 2:** Proposed solution (what we built)
**Sentence 3:** Technical innovation (key algorithm/technique)
**Sentence 4:** Results (quantitative metrics with confidence intervals)
**Sentence 5:** Impact (why this matters)

**Example (B001):**
1. Ternary neural networks can achieve 20× memory compression but sacrifice accuracy.
2. HSLM-1.95M is a 1.95M parameter ternary language model using balanced ternary weights {-1, 0, +1}.
3. Key innovations include Sacred Attention with φ-based scaling (scale = d_k^(-φ^-3) ≈ 0.236), T-JEPA with consciousness gate, and TF3 packing (8 weights in 16 bits).
4. Results: PPL 125.3 ± 2.1 [95% CI: 123.2, 127.4] on TinyStories, 385 KB model size, 1200 tokens/sec inference.
5. Pure Zig 0.15.x implementation with zero external dependencies enables edge AI deployment with minimal hardware.

### Algorithm Box Format

```
**Algorithm: [Name]**

Input: [formal specification]
Output: [formal specification]

1:  [First step with mathematical notation]
2:  [Second step]
...
N:  [Final step]
return [output]
```

**Requirements:**
- Use formal mathematical notation (∈, R, ⊂, ∀, ∃)
- Specify data structures and types
- Include loop bounds and termination conditions
- Use 1-based line numbers

### Statistical Analysis Format

```
**Statistical Analysis:**
- Hypothesis: [null and alternative]
- Test: [t-test / Wilcoxon / bootstrap]
- Result: [statistic, p-value, effect size]
- 95% CI: [lower, upper]
- Power: [1 - β, if applicable]
```

**Best Practices:**
- Always report confidence intervals
- Include effect size (Cohen's d for t-tests)
- Report p-values with threshold (p < 0.05)
- For multiple comparisons, apply Bonferroni correction

---

## Part III: Related Identifiers

### Required Relations

| Relation | Usage | Example |
|----------|-------|---------|
| `isPartOf` | Link to parent collection | Parent DOI |
| `isSupplementedBy` | GitHub repository | Source code |
| `isReferencedBy` | ArXiv paper | Preprint |
| `usesData` | Dataset citation | HuggingFace |
| `cites` | Academic references | ArXiv/DOI |

### JSON Template

```json
"related_identifiers": [
  {
    "relation": "isPartOf",
    "identifier": "10.5281/zenodo.PARENT_DOI",
    "resource_type": "software"
  },
  {
    "relation": "isSupplementedBy",
    "identifier": "https://github.com/gHashTag/trinity",
    "resource_type": "software"
  },
  {
    "relation": "cites",
    "scheme": "doi",
    "identifier": "10.48550/arXiv.XXXXX.XXXXX",
    "resource_type": "publication-article"
  }
]
```

---

## Part IV: Reproducibility Artifacts

### Required Files

```
bundle/
├── README.md                    # Overview and quick start
├── CITATION.cff                 # Machine-readable citation
├── LICENSE                      # MIT/Apache-2.0
├── Dockerfile                   # Container environment
├── figures/                     # All figures (PNG + SVG)
│   ├── architecture.png
│   └── architecture.svg
├── data/                        # Experimental data (CSV)
│   └── results.csv
├── notebooks/                   # Jupyter analysis
│   └── analysis.ipynb
└── REPRODUCIBILITY.md           # Step-by-step reproduction
```

### README.md Structure

```markdown
# [Component Name]

## Quick Start
```bash
git clone [repo]
cd [directory]
zig build
./zig-out/bin/[binary]
```

## Results
- Metric 1: value ± CI
- Metric 2: value ± CI

## Citation
```bibtex
@software{name_version,
  author = {Author},
  title = {Title},
  year = 2026
}
```
```

### REPRODUCIBILITY.md Checklist

- [ ] Hardware requirements (CPU, RAM, GPU)
- [ ] Software requirements (OS, compiler versions)
- [ ] Data sources (download links, checksums)
- [ ] Step-by-step reproduction commands
- [ ] Expected outputs (sample logs)
- [ ] Troubleshooting section

---

## Part V: Statistical Validation

### Required Tests

| Test | When to Use | What to Report |
|------|-------------|----------------|
| t-test | Two groups, normal | t-statistic, p-value, Cohen's d, CI |
| Wilcoxon | Two groups, non-normal | W-statistic, p-value, CI |
| Bootstrap | Any distribution | Mean, 95% CI, n_samples |
| ANOVA | >2 groups | F-statistic, p-value, η² |

### Power Analysis

**Sample Size Formula:**
```
n = 2 × (Z_α/2 + Z_β)² × σ² / Δ²
```

Where:
- Z_α/2 = 1.96 (for α = 0.05)
- Z_β = 0.84 (for 80% power)
- σ² = variance
- Δ = effect size

**Minimum Power:** 0.80 (80%)
**Minimum Effect Size:** 0.5 (medium)

### Confidence Intervals

**95% CI for Mean:**
```
CI = x̄ ± t_(α/2, n-1) × (s / √n)
```

**Bootstrap CI:**
```python
n_samples = 10000
bootstrap_means = [mean(sample(data)) for _ in range(n_samples)]
CI = [percentile(bootstrap_means, 2.5), percentile(bootstrap_means, 97.5)]
```

---

## Part VI: Broader Impact Statement

### Required Sections

**Positive Impacts:**
- Environmental (energy efficiency)
- Societal (accessibility, education)
- Scientific (reproducibility, open science)

**Negative Impacts:**
- Potential misuse (surveillance, manipulation)
- Limitations (accuracy, generalization)
- Mitigation strategies (what we're doing)

**Example:**
```
**Broader Impact:**
- Positive: 20× memory compression enables edge AI deployment on low-power devices
- Negative: Ternary quantization may reduce model capacity on complex tasks
- Mitigation: We provide full FP32 baseline for comparison and recommend ternary for edge-only scenarios
```

---

## Part VII: Community Standards

### Trinity Community

**Identifier:** `trinity-s3ai`
**Title:** Trinity S³AI — Sacred Science AI

### Zenodo Communities

| Community | Focus | When to Use |
|-----------|-------|-------------|
| zenodo | General | Always |
| mlrepro | ML reproducibility | ML papers |
| ecs | E-Science | Scientific computing |

### ACM Classification

**Primary:** cs.AI (Artificial Intelligence)
**Secondary:** cs.LG (Machine Learning), cs.AR (Hardware), cs.PL (Programming Languages)

---

## Part VIII: FAIR Compliance

### Findable
- [ ] Rich metadata (description, keywords)
- [ ] Persistent identifier (DOI)
- [ ] Indexed in searchable systems

### Accessible
- [ ] Open license (MIT/Apache-2.0/CC-BY)
- [ ] No access restrictions
- [ ] Multiple download formats

### Interoperable
- [ ] Standard metadata schema (JSON-LD)
- [ ] Vocabulary from ontologies (ACM, MeSH)
- [ ] Cross-references to other resources

### Reusable
- [ ] Clear license
- [ ] Detailed provenance
- [ ] Community standards (FAIR, MLSys)

---

## Part IX: Common Mistakes to Avoid

1. **Vague titles:** "Trinity Code" → ❌
   **Better:** "Trinity B001: Ternary Neural Networks — HSLM-1.95M" → ✅

2. **Missing CI:** "PPL 125.3" → ❌
   **Better:** "PPL 125.3 ± 2.1 [95% CI: 123.2, 127.4]" → ✅

3. **No algorithm:** "We used sacred attention" → ❌
   **Better:** Include algorithm box with pseudocode → ✅

4. **Incomplete metadata:** Missing keywords, references → ❌
   **Better:** 10-25 keywords, 5+ references → ✅

5. **No reproducibility:** "See code" → ❌
   **Better:** Dockerfile + step-by-step REPRODUCIBILITY.md → ✅

---

## Part X: Validation Checklist

### Pre-Upload Checklist

- [ ] Title follows format: [ID]: [Name] — [Spec]
- [ ] Abstract has 5+ sentences with formula
- [ ] Keywords: 10-25, hierarchical
- [ ] Algorithm box with formal notation
- [ ] Statistical analysis with CI
- [ ] Broader impact statement
- [ ] 5+ references with DOIs
- [ ] Related identifiers (isPartOf, cites)
- [ ] README.md with quick start
- [ ] REPRODUCIBILITY.md with steps
- [ ] Dockerfile with environment
- [ ] LICENSE file
- [ ] CITATION.cff
- [ ] Figures (PNG + SVG)
- [ ] Data (CSV format)

### Post-Upload Checklist

- [ ] DOI resolves correctly
- [ ] All files accessible
- [ ] Community assigned
- [ ] License displayed
- [ ] References linked
- [ ] Version number correct

---

## Part XI: Template Reference

### Complete B001 Template

See `docs/research/.zenodo.B001_v6.0.json` for complete JSON structure.

### Abstract Generator

Use `scripts/validate_zenodo.py` to validate:
```bash
python3 scripts/validate_zenodo.py
```

---

## References

1. FAIR Principles: Wilkinson et al., 2016
2. MLSys Reproducibility: Pmlr-v119-ardila20a
3. Zenodo Documentation: https://help.zenodo.org

---

**Document Control:** ZENODO-PRACTICES-001
**Status:** Active — Best practices for Zenodo publication
**Related:** #415, docs/research/ZENODO_ABSTRACT_TEMPLATES_V1.md
**φ² + 1/φ² = 3 | TRINITY**
