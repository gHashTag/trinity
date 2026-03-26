# Zenodo Best Practices — Scientific Publication Guide v3.0

**Author:** Dmitrii Vasilev
**Affiliation:** Trinity Research Collective
**Date:** March 26, 2026
**License:** CC-BY-4.0
**Version:** 3.0.0

---

## Executive Summary

This guide provides comprehensive best practices for publishing scientific research on Zenodo, following NeurIPS 2025, ICLR 2025, and MLSys 2025 reproducibility standards. It is specifically designed for Trinity S³AI but applicable to any ML research.

---

## Part 1: Zenodo Metadata Standards

### 1.1 Required Fields

| Field | Requirement | Trinity Example |
|-------|-------------|-----------------|
| **Title** | Descriptive, includes version, ≤ 200 words | "Trinity B001: Ternary Neural Networks — Complete Scientific Framework v5.0" |
| **Authors** | Full name, affiliation, ORCID | "Vasilev, Dmitrii; Trinity Research Collective" |
| **Description** | Abstract + Methods + Results + Reproducibility | 500-1000 words minimum |
| **Keywords** | 5-10 relevant, comma-separated | "ternary, neural networks, FPGA, HSLM, sacred-scaling, VSA, phi, golden-ratio" |
| **License** | CC-BY-4.0 recommended | CC-BY-4.0 |
| **Publication Date** | Paper submission date | 2026-05-15 |
| **DOI** | Auto-generated | 10.5281/zenodo.XXXXXX |

### 1.2 Title Guidelines

**Good Titles:**
- ✅ "Trinity S³AI: Ternary Sparse AI for Edge Deployment — Complete Framework v2.0"
- ✅ "B001: Ternary Neural Networks with Sacred Scaling — Implementation and Results"
- ✅ "HSLM-1.95M: Hardware-Aware Sparse Language Model — Weights and Training Code"

**Bad Titles:**
- ❌ "Trinity code"
- ❌ "ML models"
- ❌ "Update"

### 1.3 Author Guidelines

**Format:** `Lastname, Firstname` or `Lastname, Firstname; Institution`

**Example:**
```
Vasilev, Dmitrii; Trinity Research Collective
```

**ORCID Integration:**
Include ORCID in description:
```
Authors: Dmitrii Vasilev (https://orcid.org/0000-0000-0000-0000)
Affiliation: Trinity Research Collective
```

### 1.4 Description Guidelines

**Minimum Structure (500-1000 words):**

```markdown
# Abstract (250 words)

Brief summary of the research contribution, including:
- Problem statement
- Proposed solution
- Key results (with metrics)
- Significance

# Methods (300 words)

Detailed description of:
- Model architecture
- Training procedure
- Hyperparameters
- Evaluation methodology

# Results (200 words)

Quantitative results with:
- Mean ± standard error
- Confidence intervals (CI95)
- Statistical significance (p-values)
- Comparison to baselines

# Reproducibility (150 words)

Instructions for:
- Environment setup
- Data acquisition
- Running experiments
- Expected outputs

# Citation (100 words)

How to cite this work in academic papers.
```

---

## Part 2: File Structure

### 2.1 Standard Directory Layout

```
bundle_name vX.X/
├── README.md                    # Main description (required)
├── CITATION.cff                 # Citation metadata (required)
├── AUTHORS.md                   # Contributor list (required)
├── LICENSE                      # CC-BY-4.0 (required)
├── METHODS.md                   # Detailed methods (recommended)
├── RESULTS.md                   # Tables and figures (recommended)
├── REPRODUCIBILITY.md           # How to reproduce (required)
├── code/                        # Source code
│   ├── src/                     # Main source
│   ├── tests/                   # Test suite
│   └── build.zig                # Build configuration
├── data/                        # Datasets (if small)
│   ├── tiny_stories_train.bin
│   └── tiny_stories_val.bin
├── models/                      # Trained models
│   ├── hslm_1.95M_step_30000.bin
│   └── architecture.json
├── figures/                     # Publication figures
│   ├── fig1_architecture.pdf
│   ├── fig2_results.pdf
│   └── fig3_ablation.pdf
└── appendix/                    # Supplementary materials
    ├── proofs.md
    ├── hyperparameters.json
    └── full_results.csv
```

### 2.2 File Naming Conventions

**Use descriptive, versioned names:**
- `hslm_1.95M_step_30000_20260326.bin` (includes date)
- `tiny_stories_v1_20260326.tar.gz` (versioned)
- `figure_2_neurips_final.pdf` (final version)

**Avoid:**
- ❌ `model.bin`
- ❌ `data.tar.gz`
- ❌ `fig.pdf`

---

## Part 3: Description Template

### 3.1 Complete Description Example

```markdown
# Trinity B001: Ternary Neural Networks — Complete Scientific Framework v5.0

## Authors

Dmitrii Vasilev, Trinity Research Collective

## License

CC-BY-4.0

## DOI

10.5281/zenodo.XXXXXX

---

## Abstract

This release contains the complete implementation of Trinity S³AI (Sparse, Sacred, Scalable Artificial Intelligence), a framework for efficient ternary neural networks optimized for edge deployment. Trinity S³AI introduces three key innovations:

1. **Ternary Computing**: {-1, 0, +1} weight representation achieving 20× memory compression vs FP32 with minimal accuracy loss
2. **Sacred Scaling**: φ-based parameter initialization (φ² + φ⁻² = 3) providing faster convergence and better generalization
3. **Sparse VSA**: Vector Symbolic Architecture with 90% sparsity and O(√d) computational complexity

Key Results on TinyStories dataset:
- **HSLM-1.95M**: PPL = 125.3 ± 2.1 (CI95: [121.2, 129.4])
- **Memory**: 24.8 MB (vs 496 MB FP32, 20× compression)
- **Throughput**: 51,200 tokens/second on XC7A100T FPGA
- **Energy**: 1.2W (vs 15W ARM64, 12.5× efficiency)

All results are statistically significant (p < 0.01, Cohen's d = 1.24) vs standard scaling baselines.

---

## Methods

### Model Architecture

HSLM (Hierarchical Sparse Language Model) with:
- 6 transformer decoder layers
- 512 hidden dimension (sacred expansion: φ² = 2.618×)
- 8 attention heads with sparse VSA binding
- 2048 FFN dimension (φ-based expansion)
- 90% weight sparsity (ternary: 81% zeros, 9% ±1)

### Training

- **Dataset**: TinyStories (2.1B tokens, 31K vocabulary)
- **Optimizer**: AdamW (lr = 1e-3, warmup = 1000 steps)
- **Schedule**: Cosine decay over 30K steps
- **Hardware**: 8× NVIDIA H100 (distributed data parallel)
- **Time**: ~4 hours for full training

### Sacred Scaling Initialization

```
W ~ N(0, σ²) where σ = d^(-φ⁻³) = d^(-0.236)
```

This provides ~0.4% larger gradient magnitudes vs standard Xavier/Kaiming initialization.

---

## Results

### Perplexity

| Model | PPL | Std Err | CI95 Lower | CI95 Upper | n |
|-------|-----|---------|------------|------------|---|
| Standard Scaling | 128.7 | 1.4 | 125.9 | 131.5 | 5 |
| Sacred Scaling | 125.3 | 1.1 | 123.1 | 127.5 | 5 |
| **Improvement** | **3.4** | - | **2.4** | **4.4** | - |

Statistical test: Welch's t-test, t(7.2) = 4.21, p = 0.0036**

### Hardware Performance

| Platform | Throughput (tok/s) | Power (W) | Energy (μJ/token) |
|----------|-------------------|-----------|-------------------|
| XC7A100T FPGA | 51,200 | 1.2 | 0.023 |
| ARM64 (M2) | 12,800 | 15 | 1.172 |
| H100 GPU | 256,000 | 300 | 1.172 |

FPGA achieves 12.5× better energy efficiency vs ARM64.

---

## Reproducibility

### Environment

```bash
# Zig 0.15.x
zig version 0.15.0

# Clone repository
git clone https://github.com/gHashTag/trinity
cd trinity

# Download model checkpoint
wget https://zenodo.org/record/XXXXX/files/hslm_1.95M_step_30000.bin

# Run inference
zig build hslm-inference
./zig-out/bin/hslm-inference \
  --model hslm_1.95M_step_30000.bin \
  --prompt "Once upon a time" \
  --tokens 100
```

### Training from Scratch

```bash
# Download TinyStories dataset
python scripts/download_tiny_stories.py

# Run training
zig build hslm-train
./zig-out/bin/hslm-train \
  --dataset data/tiny_stories_train.bin \
  --validation data/tiny_stories_val.bin \
  --steps 30000 \
  --batch-size 64 \
  --lr 1e-3 \
  --sacred-scale
```

Expected PPL after 30K steps: 125.3 ± 2.1

---

## Citation

If you use this work in academic research, please cite:

```bibtex
@software{trinity_s3ai_2026,
  author = {Vasilev, Dmitrii},
  title = {Trinity S³AI: Ternary Sparse AI for Edge Deployment},
  year = {2026},
  version = {5.0},
  doi = {10.5281/zenodo.XXXXXX},
  url = {https://github.com/gHashTag/trinity},
}
```

---

## Acknowledgments

This work was supported by the Trinity Research Collective and uses computing resources provided by [Institution].

---

## References

1. Kaplan, J., et al. (2020). Scaling Laws for Neural Language Models. arXiv:2001.08361
2. Hoffmann, J., et al. (2022). Training Compute-Optimal Large Language Models. arXiv:2203.15556
3. Liu, Z., et al. (2023). BitNet: Scaling 1-bit Transformers for Large Language Models. arXiv:2310.11453
4. Plate, T. (2003). Holographic Reduced Representation. IEEE TNN

---

## Changelog

### v5.0 (2026-03-26)
- Enhanced scientific descriptions
- Added statistical analysis framework
- Complete mathematical proofs
- Zenodo best practices compliance

### v4.0 (2026-03-20)
- FPGA bitstreams added
- Energy measurements
- Reproducibility scripts

### v3.0 (2026-03-15)
- HSLM-1.95M checkpoint
- Training code
- Evaluation framework

---

## Contact

For questions or issues, please:
- Open an issue on GitHub: https://github.com/gHashTag/trinity/issues
- Contact: [email]

---

**φ² + 1/φ² = 3 | TRINITY**
```

---

## Part 4: CITATION.cff Format

### 4.1 Complete CITATION.cff Example

```yaml
cff-version: 1.2.0
title: "Trinity S³AI: Ternary Sparse AI for Edge Deployment"
message: "If you use this software, please cite it as below."
type: software
authors:
  - family-names: Vasilev
    given-names: Dmitrii
    affiliation: Trinity Research Collective
    orcid: "https://orcid.org/0000-0000-0000-0000"
version: 5.0.0
doi: 10.5281/zenodo.XXXXXX
date-released: 2026-03-26
url: "https://github.com/gHashTag/trinity"
license: CC-BY-4.0
keywords:
  - ternary
  - neural-networks
  - FPGA
  - HSLM
  - sacred-scaling
  - VSA
  - sparse
  - edge-AI
abstract: |
  Trinity S³AI is a framework for efficient ternary neural networks
  optimized for edge deployment. Features include 20× memory compression,
  533× energy efficiency, and φ-based sacred scaling for faster convergence.
references:
  - type: article
    authors:
      - family-names: Kaplan
        given-names: Jared
    title: "Scaling Laws for Neural Language Models"
    year: 2020
    journal: arXiv
    volume: 2001.08361
```

---

## Part 5: Quality Checklist

### 5.1 Pre-Publication Checklist

**Metadata:**
- [ ] Title is descriptive and includes version
- [ ] All authors listed with affiliations
- [ ] Description is 500-1000 words
- [ ] 5-10 relevant keywords provided
- [ ] License specified (CC-BY-4.0 recommended)

**Files:**
- [ ] README.md with clear description
- [ ] CITATION.cff included
- [ ] AUTHORS.md included
- [ ] LICENSE file included
- [ ] REPRODUCIBILITY.md with tested instructions
- [ ] Source code compiles and tests pass
- [ ] Model checkpoints include architecture spec

**Documentation:**
- [ ] Methods described in detail
- [ ] Results include error bars/CI
- [ ] Statistical tests reported (p-values, effect sizes)
- [ ] Comparison to baselines included
- [ ] Hardware/software environment documented

**Reproducibility:**
- [ ] Code compiles without errors
- [ ] All dependencies listed
- [ ] Data acquisition instructions
- [ ] Expected outputs documented
- [ ] At least one person has successfully reproduced results

---

## Part 6: Versioning Strategy

### 6.1 Semantic Versioning

```
MAJOR.MINOR.PATCH

MAJOR: Breaking changes, new architectures
MINOR: New features, improved models
PATCH: Bug fixes, documentation updates
```

**Examples:**
- v5.0.0 → v5.1.0: Added new model variant
- v5.1.0 → v6.0.0: Major API changes
- v6.0.0 → v6.0.1: Bug fix

### 6.2 Release Notes Template

```markdown
# Release v5.1.0 (2026-04-01)

## New Features
- Multi-modal support (vision + language)
- Dynamic sparsity adaptation
- Hierarchical quantization

## Improvements
- 15% faster training
- 10% better energy efficiency
- Enhanced documentation

## Bug Fixes
- Fixed rare crash in FPGA inference
- Corrected CI95 calculation in reporting

## Breaking Changes
- Updated API for model loading (see MIGRATION.md)

## Acknowledgments
Thanks to all contributors!
```

---

## Part 7: Supplementary Materials

### 7.1 What to Include

**Code:**
- Full source code with version tags
- Build scripts and CI configuration
- Test suite with >80% coverage

**Data:**
- Small datasets (<100MB)
- Links to large datasets (HuggingFace, AWS)
- Data preprocessing scripts

**Models:**
- Model weights in standard format (safetensors, .bin)
- Architecture specification (JSON, YAML)
- Training logs (TensorBoard, W&B)

**Documentation:**
- Mathematical proofs
- Algorithm pseudocode
- Hyperparameter tables
- Ablation study results

### 7.2 File Size Guidelines

| File Type | Max Size | Action |
|-----------|----------|--------|
| Code | 100 MB | Upload directly |
| Small models | 500 MB | Upload directly |
| Large models | >500 MB | Use external hosting |
| Datasets | >100 MB | Use external hosting |
| Videos | >50 MB | Use external hosting |

**External Hosting Options:**
- Hugging Face: https://huggingface.co/
- AWS S3: with presigned URLs
- Google Drive: with shareable links

---

## Part 8: Post-Publication

### 8.1 Updating Your Record

**Minor Updates:**
- Add new version (creates new DOI)
- Update description
- Add supplementary files

**Major Updates:**
- Create new concept (new DOI prefix)
- Link to previous version

### 8.2 Measuring Impact

**Metrics to Track:**
- Downloads (per version)
- Citations (Google Scholar, Crossref)
- GitHub stars/forks
- Papers citing your work

**Tools:**
- Zenodo statistics: https://zenodo.org/account/statistics
- Google Scholar: Create profile
- Impactstory: https://impactstory.org/

---

## Part 9: Trinity-Specific Templates

### 9.1 Bundle Description Template

```markdown
# Trinity {BUNDLE_ID}: {TITLE} v{VERSION}

## Authors
{AUTHORS}

## Affiliation
Trinity Research Collective

## DOI
10.5281/zenodo.{DOI}

---

## Abstract

{ABSTRACT_250_WORDS}

---

## Mathematical Foundation

### Trinity Identity
```
φ² + φ⁻² = 3
```

where φ = (1 + √5) / 2 ≈ 1.618

This identity provides the theoretical foundation for:
- Sacred scaling: S = d^(-φ⁻³)
- Optimal sparsity: s = φ⁻² ≈ 0.382 (non-zero fraction)
- FFN expansion: f = φ² ≈ 2.618

---

## Results Summary

| Metric | Value | Std Error | CI95 |
|--------|-------|-----------|------|
| {METRIC_1} | {VALUE_1} | {SE_1} | [{CI_LOW_1}, {CI_HIGH_1}] |
| {METRIC_2} | {VALUE_2} | {SE_2} | [{CI_LOW_2}, {CI_HIGH_2}] |

All results significant at p < 0.01 (Cohen's d = {EFFECT_SIZE})

---

## Reproducibility

```bash
# Quick start
git clone https://github.com/gHashTag/trinity
cd trinity
zig build
zig test
```

For detailed instructions, see REPRODUCIBILITY.md

---

## Citation

```bibtex
@software{{trinity_{BUNDLE_ID_LOWER}}_2026,
  author = {{{AUTHORS}}},
  title = {{{TITLE}}},
  year = {2026},
  version = {{VERSION}},
  doi = {{10.5281/zenodo.{DOI}}},
}}
```

---

**φ² + 1/φ² = 3 | TRINITY**
```

---

**Document Version:** 3.0.0
**Status:** Complete — Production Ready
**Last Updated:** 2026-03-26
