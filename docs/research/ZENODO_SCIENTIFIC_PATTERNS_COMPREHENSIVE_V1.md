# Zenodo Scientific Publication Patterns — Comprehensive Guide v1.0

**Version:** 1.0.0
**Date:** 2026-03-26
**Author:** Dmitrii Vasilev
**Purpose:** Complete guide to scientific publication patterns on Zenodo, with real examples from Trinity S³AI Framework
**Related:** docs/research/SCIENTIFIC_PUBLICATION_PATTERNS_ZENODO.md, docs/research/ZENODO_ENHANCEMENT_GUIDE_V3.md

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [The 5-Sentence Abstract Formula](#the-5-sentence-abstract-formula)
3. [Statistical Validation Standards](#statistical-validation-standards)
4. [FAIR Principles Implementation](#fair-principles-implementation)
5. [Metadata Completeness](#metadata-completeness)
6. [Algorithm Box Patterns](#algorithm-box-patterns)
7. [Figure Generation Best Practices](#figure-generation-best-practices)
8. [Common Pitfalls and Solutions](#common-pitfalls-and-solutions)
9. [Quality Checklist](#quality-checklist)

---

## Executive Summary

Scientific publications on Zenodo require the same rigor as peer-reviewed journals. This guide provides patterns for:

1. **Abstract Structure** — 5-sentence formula with problem-gap-solution-results-impact
2. **Statistical Validation** — Confidence intervals, p-values, effect sizes
3. **FAIR Compliance** — Findable, accessible, interoperable, reusable
4. **Complete Metadata** — All required CITATION.cff and Zenodo JSON fields
5. **Reproducibility** — Docker containers, data files, Jupyter notebooks

**Key Metrics:**
- Minimum 10 experimental runs for statistical significance
- 95% confidence intervals required for all quantitative claims
- Cohen's d effect size: 0.2=small, 0.5=medium, 0.8=large
- Figures at 300 DPI (PNG) + SVG for publication

---

## The 5-Sentence Abstract Formula

### Template

```
[Problem] Existing approaches [gap description].
[Gap] Current solutions [specific limitation].
[Solution] We present [novel approach] that [key innovation].
[Results] Our [method] achieves [metric 1] and [metric 2] with [quantitative results].
[Impact] This enables [application/benefit] for [target use case].
```

### Real Example: HSLM (B001)

```
Language models require massive memory and compute resources for edge deployment.
Existing ternary approaches still require DSP blocks and lack statistical validation.
We present HSLM, a zero-DSP ternary LLM with T-JEPA pre-training and phi-based warmup.
Our 1.95M parameter model achieves PPL=125.3±2.1 (95% CI: [123.2, 127.4], n=5)
with 20× memory compression (385 KB vs 7.6 MB FP32).
This enables edge AI deployment on sub-5W FPGAs with 4× larger batch sizes.
```

### Abstract Quality Checklist

- [ ] **Problem** — Clear statement of what problem is being solved
- [ ] **Gap** — Specific limitation of existing approaches
- [ ] **Solution** — Novel approach with key innovation mentioned
- [ ] **Results** — Quantitative metrics with confidence intervals
- [ ] **Impact** — Clear benefit/application
- [ ] **Word count** — 250-500 words (Zenodo limit)
- [ ] **Keywords** — 5-10 relevant terms

---

## Statistical Validation Standards

### Minimum Reporting Requirements

Every quantitative claim MUST include:

1. **Point estimate** — Mean or median value
2. **Uncertainty** — Standard deviation or 95% CI
3. **Sample size** — n value (minimum n=10)
4. **Statistical test** — For comparisons (t-test, Wilcoxon, etc.)
5. **p-value** — For statistical significance claims
6. **Effect size** — Cohen's d or similar

### Format Template

```
Metric: 125.3 ± 2.1 (95% CI: [123.2, 127.4], n=10)
Comparison: t(18) = 5.23, p < 0.001, Cohen's d = 2.34 (large effect)
```

### When to Report Confidence Intervals

- All performance metrics (PPL, accuracy, F1, etc.)
- Timing measurements (training time, inference latency)
- Resource usage (memory, power)
- Improvement percentages

### When to Report p-values

- Comparing against baseline methods
- Validating experimental hypotheses
- Ablation study results
- Significance of improvements

### Statistical Tests Reference

| Test | Use Case | Formula |
|------|----------|---------|
| Independent t-test | Two groups, normal distribution | `t = (m1 - m2) / SE_pooled` |
| Paired t-test | Same subjects, two conditions | `t = mean(d) / SE(d)` |
| Wilcoxon rank-sum | Non-parametric, two groups | `W = sum(R1)` |
| ANOVA | Three+ groups | `F = MS_between / MS_within` |

### Implementation Example (Zig)

```zig
// From src/hslm/statistics.zig
pub fn confidenceInterval95(values: []const f32) struct { lower: f32, upper: f32 } {
    const n = @as(f32, @floatFromInt(values.len));
    const m = mean(values);
    const s = stdDev(values);
    const margin = 1.96 * s / std.math.sqrt(n);
    return .{ .lower = m - margin, .upper = m + margin };
}

pub fn cohensD(group1: []const f32, group2: []const f32) f32 {
    const m1 = mean(group1);
    const m2 = mean(group2);
    const v1 = variance(group1);
    const v2 = variance(group2);
    const sp = std.math.sqrt((v1 + v2) / 2);
    if (sp == 0) return 0;
    return std.math.abs(m1 - m2) / sp;
}
```

---

## FAIR Principles Implementation

### F - Findable

**DOI Assignment:**
- Every bundle MUST have a Zenodo DOI
- DOI must be resolvable (not "TBD")
- Include in CITATION.cff

**Metadata Richness:**
```yaml
identifiers:
  - description: "Zenodo DOI"
    type: doi
    value: "10.5281/zenodo.19227733"
  - description: "GitHub repository"
    type: url
    value: "https://github.com/gHashTag/trinity"
  - description: "Software Heritage identifier"
    type: swh
    value: "swh:1:dir:github-commits-hash"
```

**Indexing:**
- Submit to Google Scholar
- Include SEO-optimized keywords
- Use descriptive titles

### A - Accessible

**Open Access:**
- Use CC-BY-4.0 license (recommended)
- No paywalls or registration
- Permanent hosting (Zenodo)

**Protocol Standards:**
- Standard protocols (HTTP, HTTPS)
- Multiple access methods (Zenodo, GitHub, SWH)

**Metadata Accessibility:**
- Machine-readable format (CITATION.cff)
- JSON-LD structured data

### I - Interoperable

**Vocabulary Standards:**
```yaml
keywords:
  - "ternary neural network"  # Standard term
  - "HSLM"                    # Project-specific
  - "1.58-bit LLM"            # Emerging term
```

**Data Formats:**
- Use open formats (CSV, JSON, YAML)
- Provide schema definitions
- Document non-standard formats

**Cross-References:**
```yaml
related_identifiers:
  - type: documentation
    relation: documents
    title: "HSLM Training Report"
    uri: "https://github.com/..."
```

### R - Reusable

**Clear Licensing:**
```yaml
license: CC-BY-4.0
```

**Detailed Provenance:**
- Document all data sources
- Record software versions
- Track data processing steps

**Community Standards:**
- Follow domain-specific standards
- Use common metadata schemas

---

## Metadata Completeness

### Required CITATION.cff Fields

```yaml
cff-version: 1.2.0
message: "Citation message"
title: "Publication title"
authors:
  - family-names: "Last"
    given-names: "First"
    orcid: "https://orcid.org/..."
    affiliation: "Organization"
type: software
version: "1.0.0"
date-released: YYYY-MM-DD
url: "https://github.com/..."
repository-code: "https://github.com/..."
keywords: [...]
license: CC-BY-4.0
```

### Recommended Additional Fields

```yaml
abstract: "Complete abstract following 5-sentence structure"
doi: "10.5281/zenodo.XXXXXX"
identifiers:
  - type: doi
    value: "10.5281/zenodo.XXXXXX"
  - type: swh
    value: "swh:1:dir:..."
related-resources:
  - type: documentation
    relation: documents
    title: "Related doc"
    uri: "https://..."
references:
  - type: article
    authors: [...]
    title: "Reference title"
    year: YYYY
    journal: "Journal/conference"
    doi: "10...."
```

### Zenodo JSON Metadata Structure

```json
{
  "title": "Bundle Title",
  "creators": [{"name": "Author", "orcid": "0000-0000-0000-0000"}],
  "description": "Full description with algorithm box",
  "keywords": ["Standard", "Specific", "Emerging"],
  "license": {"id": "MIT"},
  "publication_date": "2026-03-26",
  "version": "6.0.0",
  "doi": "10.5281/zenodo.XXXXXX",
  "related_identifiers": [...],
  "references": [...],
  "upload_type": "software",
  "communities": [{"identifier": "community-name"}]
}
```

### Keyword Optimization Strategy

**Primary Keywords (Core Concepts):**
- Standard domain terms
- High search volume
- Specific to innovation

**Secondary Keywords (Implementation):**
- Technology-specific terms
- Framework/library names
- Implementation details

**Long-Tail Keywords (Niche):**
- Combinations of primary + secondary
- Problem-specific phrases
- Use-case specific terms

---

## Algorithm Box Patterns

### Standard Algorithm Format

```
### Algorithm N: Descriptive Title

**Input:** [clear input specification]
**Output:** [clear output specification]

```
 1:  procedure NAME(Input, Parameters)
 2:      // Step 1: Description
 3:      operation
 4:
 5:      // Step 2: Description with formula
 6:      result ← complex_operation(x, y)
 7:
 8:      for i = 1 to n do
 9:          // Loop body
10:          process(i)
11:      end for
12:
13:      return result
14:  end procedure
```

**Complexity:** O(n log n) time, O(n) space
**Correctness:** Theorem N guarantees convergence
```

### Real Example: Ternary SGD

```
### Algorithm 2: Ternary SGD with φ-Warmup

**Input:** Model θ, dataset D, batch_size B, total_steps T, η_max
**Output:** Trained model θ*

```
 1:  procedure TERNARY_SGD_φ_WARMUP(θ, D, B, T, η_max)
 2:      t_w ← 2000                    // Warmup steps
 3:      γ ← φ^(-1) ≈ 0.618            // Warmup exponent
 4:
 5:      for t = 1 to T do
 6:          S ← D.sample(B)           // Sample batch
 7:
 8:          // φ-warmup + cosine schedule
 9:          if t ≤ t_w then
10:              η ← η_max × (t/t_w)^γ
11:          else
12:              η ← η_max × 0.5 × (1 + cos(π × (t - t_w) / (T - t_w)))
13:          end if
14:
15:          ℓ ← L(θ_Q, S)              // Forward pass
16:          g ← ∇_θ ℓ                  // Backward pass
17:
18:          if ||g||_2 > 1.0 then
19:              g ← g / ||g||_2        // Gradient clipping
20:          end if
21:
22:          θ ← θ - η × g              // Weight update
23:          θ_Q ← Q(θ)                 // Ternarization
24:      end for
25:      return θ_Q
26:  end procedure
```

**Complexity:** O(T × B × L) where L is sequence length
**Convergence:** Theorem 2 guarantees almost sure convergence
```

---

## Figure Generation Best Practices

### Figure Specifications

| Property | Value | Notes |
|----------|-------|-------|
| DPI | 300 | Publication quality |
| Formats | PNG + SVG | Raster + vector |
| Colors | Trinity palette | Gold, Teal, PNG |
| Fonts | Sans-serif | Arial, Helvetica |
| Captions | 12pt minimum | Clear and descriptive |

### Trinity Color Palette

```python
GOLD = "#D4AF37"    # φ, sacred constants
TEAL = "#008080"    # Ternary values
PNG = "#FFA500"     # Performance metrics
WHITE = "#FFFFFF"
DARK_BG = "#1a1a2e"
```

### Figure Types by Bundle

| Bundle | Figure Types | Count |
|--------|--------------|-------|
| B001 | Training curve, format comparison | 2 |
| B002 | FPGA resources, power analysis | 2 |
| B003 | Register layout | 1 |
| B004 | Lotus cycle diagram | 1 |
| B005 | Type hierarchy | 1 |
| B006 | GF16 layout, φ heatmap | 2 |
| B007 | VSA structure, SIMD speedup | 2 |

### Matplotlib Template

```python
import matplotlib.pyplot as plt
from pathlib import Path

# Trinity colors
GOLD = "#D4AF37"
TEAL = "#008080"
DARK_BG = "#1a1a2e"

fig, ax = plt.subplots(figsize=(10, 6))
ax.set_facecolor(DARK_BG)

# Plot with error bars
ax.plot(x, y, color=GOLD, linewidth=2, label='HSLM')
ax.fill_between(x, y_lower, y_upper, alpha=0.3, color=GOLD)

# Styling
ax.legend(facecolor=DARK_BG, edgecolor=WHITE, labelcolor=WHITE)
ax.tick_params(colors=WHITE)
ax.spines['bottom'].set_color(WHITE)
ax.spines['top'].set_color(WHITE)
ax.spines['left'].set_color(WHITE)
ax.spines['right'].set_color(WHITE)

# Export
plt.savefig('figure.png', dpi=300, bbox_inches='tight', facecolor=DARK_BG)
plt.savefig('figure.svg', bbox_inches='tight', facecolor=DARK_BG)
```

---

## Common Pitfalls and Solutions

### Pitfall 1: Missing Confidence Intervals

**Problem:**
```
Our model achieves PPL 125 on TinyStories.
```

**Solution:**
```
Our model achieves PPL 125.3 ± 2.1 (95% CI: [123.2, 127.4], n=10).
```

### Pitfall 2: Insufficient Statistical Testing

**Problem:**
```
Our method outperforms the baseline.
```

**Solution:**
```
Our method (PPL: 125.3 ± 2.1, n=10) significantly outperforms
baseline (PPL: 135.7 ± 3.4, n=10): t(18) = 5.23, p < 0.001,
Cohen's d = 2.34 (large effect).
```

### Pitfall 3: Vague Novelty Claims

**Problem:**
```
1. Novel approach for model compression.
2. Better performance than existing methods.
```

**Solution:**
```
1. Checkpoint compression: 20× size reduction (7.6 MB → 385 KB)
   with <1% accuracy loss, verified by synthesis report.

2. Zero-DSP ternary MAC: 3 LUTs/weight, 0% DSP utilization
   on XC7A100T FPGA (resources/timing_report.txt).
```

### Pitfall 4: Missing Reproducibility Information

**Problem:**
```
We trained our model on TinyStories.
```

**Solution:**
```
We trained on TinyStories (Eldan & Li, 2023) with:
- Dataset: https://huggingface.co/datasets/ceibal/TinyStories
- Subset: First 10M tokens
- Hardware: Apple M1 Pro, 16GB RAM
- Software: Zig 0.15.2, HSLM v1.0.0
- Random seed: 42 (fixed)
- Training time: ~2 hours for 30K steps
```

### Pitfall 5: Inconsistent Terminology

**Solution:** Create terminology table:
```
| Term | Definition | First Use |
|------|------------|-----------|
| Trit | Balanced ternary digit {-1, 0, +1} | Section 1 |
| HSLM | Hierarchical Sacred Language Model | Section 2 |
| TF3 | Ternary Folding 3-bit format | Section 3 |
```

---

## Quality Checklist

### Pre-Submission Checklist

**Abstract:**
- [ ] Follows 5-sentence structure
- [ ] Problem clearly stated
- [ ] Gap identified
- [ ] Novel approach described
- [ ] Quantitative results with CIs
- [ ] Impact specified
- [ ] Word count 250-500

**Statistical Rigor:**
- [ ] All metrics include uncertainty
- [ ] Sample sizes reported (n values)
- [ ] Statistical tests for comparisons
- [ ] p-values where appropriate
- [ ] Effect sizes reported

**Reproducibility:**
- [ ] Code repository public
- [ ] Build instructions complete
- [ ] Random seeds documented
- [ ] Hardware specs listed
- [ ] Execution times reported
- [ ] Memory usage documented

**Metadata:**
- [ ] CITATION.cff complete
- [ ] DOI assigned (not TBD)
- [ ] ORCID for authors
- [ ] Keywords optimized
- [ ] License specified
- [ ] References complete

**FAIR Principles:**
- [ ] Findable: DOI assigned
- [ ] Accessible: Open access license
- [ ] Interoperable: Standard formats
- [ ] Reusable: Clear licensing + provenance

**Figures:**
- [ ] 300 DPI PNG format
- [ ] SVG format included
- [ ] Clear captions
- [ ] Color blind accessible
- [ ] Trinity color palette used

### Post-Submission Validation

**Citation Test:**
```bash
# Test CITATION.cff parsing
curl https://citation-file-format.github.io/cff-initializer-javascript/

# Verify DOI resolves
curl -L https://doi.org/10.5281/zenodo.XXXXXX
```

**Metadata Validation:**
```bash
# Validate CITATION.cff
cffconvert --validate CITATION.cff

# Validate Zenodo JSON
python3 -m json.tool .zenodo.B001_v6.0.json
```

---

## Conclusion

Scientific publication patterns for Zenodo require attention to:

1. **Abstract structure** — 5-sentence formula
2. **Statistical rigor** — CIs, p-values, effect sizes
3. **FAIR compliance** — All four principles
4. **Metadata completeness** — All required fields
5. **Reproducibility** — Complete build instructions

By following these patterns, defensive publications achieve both prior art value and scientific credibility.

---

**φ² + 1/φ² = 3 | TRINITY**

**Document Control:** ZENODO-PATTERNS-001
**Status:** Active — Comprehensive scientific publication guide
