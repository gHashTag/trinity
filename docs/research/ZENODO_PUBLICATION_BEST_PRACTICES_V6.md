# Zenodo Publication Best Practices — Trinity S³AI Framework

**Version:** 6.0
**Date:** 2026-03-26
**Author:** Dmitrii Vasilev
**Related:** ZENODO_SCIENTIFIC_GUIDE_V3.md, COMPLETE_PUBLICATION_PACKAGE.md

---

## Abstract

This document provides comprehensive guidelines for publishing scientific research on Zenodo following 2025-2026 best practices from NeurIPS, ICLR, MLSys, and Nature/Science journals. The framework ensures FAIR compliance, reproducibility, and maximum citation impact.

---

## Part I: Zenodo Publication Structure

### 1.1 Metadata Schema

**Required Fields:**
```json
{
  "title": "Trinity S³AI: Ternary Symbolic AI Framework",
  "creators": [
    {"name": "Vasilev, Dmitrii", "affiliation": "Trinity Research"},
    {"name": "Contributor, Name", "affiliation": "Institution"}
  ],
  "description": "<5-sentence abstract>",
  "keywords": ["ternary computing", "VSA", "hyperdimensional", "FPGA"],
  "publication_date": "2026-03-26",
  "version": "6.0",
  "doi": "10.5281/zenodo.XXXXXX",
  "related_identifiers": [
    {"relation": "isPartOf", "identifier": "10.5281/zenodo.YYYYYY"}
  ]
}
```

### 1.2 License Selection

**Recommended Licenses:**

| License | Use Case | Commercial | Derivatives |
|---------|----------|------------|-------------|
| **CC-BY-4.0** | General research | ✅ | ✅ |
| **CC-BY-SA-4.0** | Copyleft code | ✅ | ⚠️ Same license |
| **MIT-0** | Software | ✅ | ✅ |
| **Apache-2.0** | Patent-protected | ✅ | ✅ |

**Trinity Recommendation:** CC-BY-4.0 for research data, Apache-2.0 for software.

---

## Part II: Abstract Writing Guidelines

### 2.1 Five-Sentence Structure

**Template:**
```
[S1] Context & Problem: What is the gap?
[S2] Approach: What did you do?
[S3] Results: What are the key findings?
[S4] Implications: Why does it matter?
[S5] Availability: How can others use it?
```

**Example (Trinity B001):**
```
[S1] Large language models require massive memory and energy, limiting deployment on edge devices.
[S2] We present Trinity HSLM, a 1.95M parameter ternary language model using {-1,0,+1} weights.
[S3] HSLM achieves 125.3 perplexity on TinyStories with 20× memory compression (385 KB) and 0% DSP usage on FPGA.
[S4] This enables efficient NLP on resource-constrained hardware without sacrificing quality.
[S5] Code, data, and pretrained models are available at https://github.com/gHashTag/trinity.
```

### 2.2 Scientific Keywords

**Required Categories:**
- **Domain:** e.g., "Machine Learning", "Computer Architecture"
- **Method:** e.g., "Ternary Neural Networks", "Hyperdimensional Computing"
- **Application:** e.g., "Natural Language Processing", "FPGA Acceleration"
- **Metrics:** e.g., "Perplexity", "Energy Efficiency"

---

## Part III: FAIR Principles Compliance

### 3.1 Findable

**Requirements:**
1. **Persistent Identifier** (DOI)
2. **Rich Metadata** (complete schema)
3. **Searchable Index** (Zenodo, Google Scholar)

**Implementation:**
```yaml
metadata:
  doi: "10.5281/zenodo.19227865"
  keywords: ["ternary", "VSA", "hyperdimensional"]
  communities:
    - identifier: "zenodo"
    - identifier: "neurips-2025"
```

### 3.2 Accessible

**Requirements:**
1. **Open Access** (no paywall)
2. **Standard Protocol** (HTTPS, API)
3. **Authentication** (OAuth2 for private data)

**Implementation:**
```bash
# Public download
curl -O https://zenodo.org/record/19227865/files/trinity-b001.zip

# API access
curl https://zenodo.org/api/records/19227865
```

### 3.3 Interoperable

**Requirements:**
1. **Standard Formats** (JSON, CSV, HDF5)
2. **Vocabulary** (Schema.org, OBO)
3. **References** (DOI, ORCID)

**Implementation:**
```json
{
  "@context": "https://schema.org",
  "@type": "SoftwareSourceCode",
  "identifier": "10.5281/zenodo.19227865",
  "author": {
    "@type": "Person",
    "@id": "https://orcid.org/0000-0000-0000-0000"
  }
}
```

### 3.4 Reusable

**Requirements:**
1. **Clear License** (CC-BY-4.0)
2. **Detailed Documentation** (README, API docs)
3. **Provenance** (Git history, CI logs)
4. **Quality Standards** (tests, benchmarks)

**Implementation:**
```
trinity/
├── README.md           # Usage instructions
├── LICENSE             # CC-BY-4.0
├── CITATION.cff        # Citation metadata
├── tests/              # Test suite
├── benchmarks/         # Performance data
└── docs/               # API documentation
```

---

## Part IV: Version Control & Provenance

### 4.1 Git-Zenodo Integration

**Recommended Workflow:**
```bash
# 1. Create GitHub release
git tag -a v6.0 -m "Trinity v6.0 Release"
git push origin v6.0

# 2. Zenodo auto-archives from GitHub release
# DOI automatically assigned

# 3. Update CITATION.cff
cff-version: 1.2.0
message: "If you use this software, please cite it as below."
title: "Trinity S³AI Framework"
version: "6.0"
doi: "10.5281/zenodo.19227865"
```

### 4.2 Citation File Format (CFF)

**Minimal CFF:**
```yaml
cff-version: 1.2.0
title: "Trinity S³AI"
message: "Please cite Trinity as:"
authors:
  - family-names: "Vasilev"
    given-names: "Dmitrii"
    affiliation: "Trinity Research"
    orcid: "https://orcid.org/0000-0000-0000-0000"
version: "6.0.0"
doi: "10.5281/zenodo.19227879"
date-released: 2026-03-26
license: CC-BY-4.0
```

---

## Part V: Supplementary Materials

### 5.1 Required Files

**For Software Releases:**
```
trinity-v6.0.zip
├── README.md              # Getting started
├── LICENSE                # CC-BY-4.0
├── CITATION.cff           # Citation metadata
├── CHANGELOG.md           # Version history
├── requirements.txt       # Dependencies
├── tests/                 # Test suite
├── docs/                  # Documentation
├── figures/               # Paper figures
├── data/                  # Sample data
└── models/                # Pretrained models
```

**For Research Papers:**
```
trinity-paper-v6.0.zip
├── main.pdf               # Paper
├── supplementary.pdf      # Appendix
├── code.zip               # Reproducibility package
├── data/                  # Dataset
├── figures/               # All figures
└── reviews/               # Peer review responses
```

### 5.2 Figure Guidelines

**Resolution:**
- **Raster (PNG, JPEG):** 300 DPI minimum
- **Vector (SVG, PDF):** Preferred for plots

**Accessibility:**
- Colorblind-safe palette (viridis, plasma)
- High contrast (WCAG AA)
- Alt text for all figures

**Example (Trinity Color Palette):**
```python
TRINITY_COLORS = {
    'gold': '#D4AF37',      # φ golden
    'cyan': '#00CED1',      # Sacred blue
    'magenta': '#FF00FF',   # Innovation
    'dark_bg': '#1e1e1e'    # Dark background
}
```

---

## Part VI: Reproducibility Checklist

### 6.1 Code Availability

**Requirements:**
- [x] Public repository (GitHub/GitLab)
- [x] LICENSE file
- [x] README with setup instructions
- [x] Continuous Integration (CI)
- [x] Test coverage > 80%
- [x] Documentation (API + tutorials)

### 6.2 Data Availability

**Requirements:**
- [x] Dataset DOI
- [x] Data dictionary
- [x] Collection methodology
- [x] Preprocessing scripts
- [x] Privacy/ethics statement

### 6.3 Experimental Protocol

**Requirements:**
- [x] Hyperparameters documented
- [x] Random seeds recorded
- [x] Hardware specifications
- [x] Software versions
- [x] Runtime metrics

**Template:**
```yaml
experiment:
  name: "HSLM Training"
  hardware:
    cpu: "ARM64 Neoverse N1"
    ram: "16 GB"
  software:
    os: "Ubuntu 22.04"
    zig: "0.15.2"
  hyperparameters:
    lr: 0.001
    batch_size: 32
    epochs: 30
  results:
    final_loss: 2.34
    perplexity: 125.3
    throughput: "140 tok/s/W"
```

---

## Part VII: Community Integration

### 7.1 Zenodo Communities

**Recommended Communities:**
- **zenodo** (general)
- **neurips-2025** (conference)
- **iclr-2026** (conference)
- **mlsys-2026** (systems)
- **arxiv** (preprint integration)

### 7.2 Cross-Platform Integration

**Workflow:**
```
1. arXiv → Zenodo → GitHub
   └─> Preprint → DOI → Code

2. Peer Review → Revised Version → New DOI
   └─> v1.0 → v1.1 → v2.0

3. Conference Proceedings → Zenodo
   └─> NeurIPS 2025 → Community
```

---

## Part VIII: Citation Optimization

### 8.1 Citation Metrics

**Metrics to Track:**
- **Views** (Zenodo, GitHub)
- **Downloads** (ZIP, PDF)
- **Citations** (Google Scholar, Crossref)
- **Altmetrics** (Twitter, blogs)

**Optimization Strategies:**
1. **Descriptive Title** (keyword-rich)
2. **Clear Abstract** (5 sentences)
3. **Rich Keywords** (domain + method)
4. **README Links** (to Zenodo DOI)
5. **Badges** (DOI badge in README)

### 8.2 Citation Formats

**BibTeX:**
```bibtex
@software{trinity_s3ai_2026,
  author = {Vasilev, Dmitrii},
  title = {Trinity S³AI: Ternary Symbolic AI Framework},
  year = {2026},
  version = {6.0},
  doi = {10.5281/zenodo.19227879},
  url = {https://zenodo.org/records/19227879}
}
```

**APA:**
```
Vasilev, D. (2026). Trinity S³AI: Ternary Symbolic AI Framework (Version 6.0) [Computer software].
Zenodo. https://doi.org/10.5281/zenodo.19227879
```

**IEEE:**
```
[1] D. Vasilev, "Trinity S³AI: Ternary Symbolic AI Framework," Zenodo, 2026. doi: 10.5281/zenodo.19227879.
```

---

## Part IX: Quality Assurance

### 9.1 Pre-Upload Checklist

**Metadata:**
- [ ] Title is descriptive and concise
- [ ] Authors are correctly listed
- [ ] Affiliations are accurate
- [ ] Abstract follows 5-sentence structure
- [ ] Keywords cover domain + method
- [ ] License is appropriate
- [ ] DOI format is correct

**Files:**
- [ ] All files are present
- [ ] File sizes < 25 GB (Zenodo limit)
- [ ] Filenames are descriptive
- [ ] No sensitive data included
- [ ] README is comprehensive
- [ ] LICENSE is included

**Testing:**
- [ ] Code runs from scratch
- [ ] Tests pass
- [ ] Documentation builds
- [ ] Figures render correctly
- [ ] Data files are valid

### 9.2 Post-Upload Actions

1. **Verify DOI** resolves correctly
2. **Test download** works
3. **Check metadata** displays
4. **Share on social media**
5. **Update README** with DOI badge
6. **Notify collaborators**

---

## Part X: Trinity Bundle Structure

### 10.1 Parent Collection

**DOI:** 10.5281/zenodo.19227879

**Contents:**
- B001: HSLM (10.5281/zenodo.19227865)
- B002: FPGA (10.5281/zenodo.19227867)
- B003: TRI-27 (10.5281/zenodo.19227869)
- B004: Queen (10.5281/zenodo.19227871)
- B005: Tri-Language (10.5281/zenodo.19227873)
- B006: GF16 (10.5281/zenodo.19227875)
- B007: VSA (10.5281/zenodo.19227877)

### 10.2 Cross-References

**Hierarchy:**
```
Parent (PARENT) → B001 → Code + Data
Parent (PARENT) → B002 → Bitstreams + Docs
...
Parent (PARENT) → B007 → VSA Library + Tests
```

**Updates:**
- Minor changes: New version (v6.0 → v6.1)
- Major changes: New DOI
- Deprecations: Mark in metadata

---

## Appendix A: Quick Reference

### Zenodo Upload Commands

```bash
# Via web interface
https://zenodo.org/deposit

# Via API (requires token)
curl https://zenodo.org/api/deposit/depositions \
  -H "Authorization: Bearer $ZENODO_TOKEN" \
  -F "metadata=@metadata.json"

# From GitHub release
# (Auto-archived by Zenodo integration)
```

### DOI Badge Markdown

```markdown
[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.19227879.svg)](https://doi.org/10.5281/zenodo.19227879)
```

---

## References

1. Zenodo Community Guidelines. https://zenodo.org/communities
2. FAIR Principles. https://www.go-fair.org/fair-principles
3. Citation File Format. https://citation-file-format.github.io/
4. NeurIPS 2025 Guidelines. https://neurips.cc/author-guide
5. ICLR 2026 Checklist. https://iclr.cc/overview

---

**φ² + 1/φ² = 3 | TRINITY**

**Document Version:** 6.0.0
**Last Updated:** 2026-03-26
**Status:** Production Ready
