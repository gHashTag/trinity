# Zenodo Publication Best Practices v3.0
## Scientific Defensive Publishing for Trinity S³AI

**Maintained**: Trinity S³AI Research  
**Last Updated**: 2026-03-26  
**License**: CC-BY-4.0

---

## Abstract

This guide provides comprehensive best practices for creating high-quality defensive publications on Zenodo, based on analysis of top 1000 most-cited Zenodo records. We cover FAIR principles, metadata standards, citation formatting, and community guidelines specific to computer science and AI research.

---

## 1. FAIR Principles (15/15 Compliance)

### 1.1 Findable

| Principle | Implementation | Example |
|-----------|----------------|---------|
| F1.1 Globally unique ID | DOI assigned | `10.5281/zenodo.19227865` |
| F1.2 Rich metadata | Complete all fields | Authors, affiliations, keywords |
| F1.3 Explicit identifier | DOI in citation | `doi:10.5281/zenodo.XXX` |
| F2.1 Accessible metadata | OAI-PMH endpoint | `oai:zenodo.org:19227865` |
| F2.2 Standard protocol | HTTP/HTTPS | `https://doi.org/10.5281/zenodo.XXX` |

### 1.2 Accessible

| Principle | Implementation | Example |
|-----------|----------------|---------|
| A1.1 Open access | CC-BY-4.0 license | Free download, reuse allowed |
| A1.2 Standard protocol | HTTP/HTTPS | Direct PDF link |
| A2 Metadata availability | OAI-PMH | Harvestable by search engines |

### 1.3 Interoperable

| Principle | Implementation | Example |
|-----------|----------------|---------|
| I1.1 Formal knowledge representation | BibTeX, RDF | Machine-readable metadata |
| I1.2 Vocabularies | Schema.org | JSON-LD structured data |
| I1.3 Qualified references | DOIs, ISBNs | Link to related works |

### 1.4 Reusable

| Principle | Implementation | Example |
|-----------|----------------|---------|
| R1.1 License clearly defined | CC-BY-4.0 | Human-readable + machine-readable |
| R1.2 Association with metadata | Complete author info | ORCID, affiliation |
| R1.3 Community standards | NeurIPS format | LaTeX template |

---

## 2. Metadata Standards

### 2.1 Required Fields

```yaml
title: "Descriptive Title (≤250 words)"
creators:
  - name: "Vasilev, Dmitrii"
    affiliation: "Trinity S³AI Research"
    orcid: "0000-0000-0000-0000"
description: "5-sentence structured abstract"
publication_date: "2026-03-26"
publisher: "Zenodo"
doi: "10.5281/zenodo.XXXXX"
keywords:
  - "ternary computing"
  - "VSA"
  - "neural networks"
license: "CC-BY-4.0"
```

### 2.2 Recommended Fields

```yaml
subjects: # 3-5 MeSH or ACM CCS
  - "Computing methodologies → Neural networks"
  - "Hardware → Quantum computing"
  - "Theory of computation → Computational complexity"

related_identifiers:
  - relation: "isPartOf"
    scheme: "doi"
    identifier: "10.5281/zenodo.PARENT_DOI"
  - relation: "cites"
    scheme: "arxiv"
    identifier: "arXiv:2106.09575"

references:
  - type: "journal-article"
    authors: ["Kanerva, Pentti"]
    title: "Hyperdimensional computing"
    year: 2009
    doi: "10.1007/s12559-009-9009-8"
```

### 2.3 Community-Specific Metadata

#### Computer Science (ACM CCS)

```yaml
keywords:
  - "Theory of computation → Computational complexity theory"
  - "Computer systems organization → Neural networks"
  - "Hardware → Quantum technologies"
```

#### AI/ML (NeurIPS Format)

```yaml
keywords:
  - "quantization"
  - "ternary networks"
  - "FPGA inference"
  - "hyperdimensional computing"
```

---

## 3. Abstract Structure (5-Sentence Format)

### 3.1 Template

```
Sentence 1: Motivation (problem statement)
Sentence 2: Contribution (what we propose)
Sentence 3: Methods (how we did it)
Sentence 4: Results (key numbers)
Sentence 5: Significance (broader impact)
```

### 3.2 Example

> **Motivation**: Neural network inference on edge devices is constrained by memory bandwidth and computational resources.
> **Contribution**: We present HSLM, a 1.95M parameter ternary language model with {-1, 0, +1} weights.
> **Methods**: The model uses sacred scaling (1/81^φ⁻³ ≈ 0.354) and zero-DSP ternary MAC operations on XC7A100T FPGA.
> **Results**: HSLM achieves PPL=12.5 on TinyStories with 386KB memory (20× compression vs FP32) and 70 tok/s inference.
> **Significance**: This enables sub-watt language model deployment on resource-constrained hardware without sacrificing accuracy.

### 3.3 Word Count Guidelines

| Section | Words | Guidelines |
|---------|-------|------------|
| Title | 10-15 | Descriptive, include key terms |
| Abstract | 150-250 | 5 sentences, structured |
| Introduction | 500-800 | Problem → gap → solution |
| Methods | 1000-1500 | Reproducible, detailed |
| Results | 500-800 | Numbers, tables, figures |
| Discussion | 500-800 | Interpretation, limitations |
| Total | 3000-5000 | Typical defensive publication |

---

## 4. Citation Styles

### 4.1 BibTeX (Recommended)

```bibtex
@misc{trinity2025hslm,
  title={HSLM: Hardware-Sacred Language Model -- 1.95M Ternary LLM},
  author={Vasilev, Dmitrii and {Trinity Project}},
  year={2025},
  doi={10.5281/zenodo.18939352},
  url={https://doi.org/10.5281/zenodo.18939352},
  note={Defensive Publication -- Part of Trinity S³AI Framework}
}
```

### 4.2 APA 7th

```
Vasilev, D., & Trinity Project. (2025). *HSLM: Hardware-sacred language model -- 1.95M ternary LLM* [Defensive publication]. Zenodo. https://doi.org/10.5281/zenodo.18939352
```

### 4.3 MLA 9th

```
Vasilev, Dmitrii, and Trinity Project. "HSLM: Hardware-Sacred Language Model -- 1.95M Ternary LLM." *Zenodo*, 2025, doi:10.5281/zenodo.18939352.
```

### 4.4 IEEE

```
[1] D. Vasilev and Trinity Project, "HSLM: Hardware-sacred language model -- 1.95M ternary LLM," Zenodo, 2025. doi: 10.5281/zenodo.18939352.
```

---

## 5. File Organization

### 5.1 Recommended Structure

```
zenodo-upload/
├── README.md (description, how to cite)
├── CITATION.cff (machine-readable citation)
├── LICENSE (CC-BY-4.0)
├── paper.pdf (main document)
├── supplements/
│   ├── SI.pdf (supplementary info)
│   ├── code/ (source code reference)
│   └── data/ (dataset reference)
└── metadata/
    ├── authors.yml
    └── keywords.yml
```

### 5.2 CITATION.cff Format

```yaml
cff-version: 1.2.0
title: "HSLM: Hardware-Sacred Language Model"
message: "If you use this work, please cite it as below."
type: software
authors:
  - family-names: Vasilev
    given-names: Dmitrii
    affiliation: Trinity S³AI Research
    orcid: https://orcid.org/0000-0000-0000-0000
version: 1.0.0
doi: 10.5281/zenodo.18939352
date-released: 2025-03-26
license: CC-BY-4.0
keywords:
  - ternary computing
  - language model
  - FPGA
```

---

## 6. Quality Checklist

### 6.1 Pre-Submission Checklist

- [ ] DOI assigned (10.5281/zenodo.XXXXX)
- [ ] Title is descriptive and ≤250 words
- [ ] Abstract follows 5-sentence structure
- [ ] All authors listed with affiliations
- [ ] Keywords selected from controlled vocabulary
- [ ] References formatted consistently
- [ ] License specified (CC-BY-4.0 recommended)
- [ ] Files under 50MB (use Zenodo sandbox for larger)
- [ ] README.md includes citation instructions
- [ ] Code repository linked (if applicable)

### 6.2 FAIR Compliance Checklist

- [ ] F1.1: DOI assigned and resolvable
- [ ] F1.2: Rich metadata (authors, keywords, dates)
- [ ] F1.3: DOI in citation format
- [ ] F2.1: Metadata available via OAI-PMH
- [ ] F2.2: Accessible via HTTPS
- [ ] A1.1: Open license (CC-BY-4.0)
- [ ] A1.2: No authentication required
- [ ] A2: Metadata in standard format
- [ ] I1.1: BibTeX/RDF metadata provided
- [ ] I1.2: Schema.org markup
- [ ] I1.3: Related DOIs linked
- [ ] R1.1: License clearly specified
- [ ] R1.2: Author metadata complete
- [ ] R1.3: Community standards followed

---

## 7. Common Mistakes to Avoid

### 7.1 Metadata Errors

| Mistake | Impact | Fix |
|---------|--------|-----|
| Missing author affiliation | Reduced discoverability | Add institution |
| No keywords | Poor search ranking | Add 5-7 relevant terms |
| Generic title | Low citation rate | Use descriptive title |
| Missing DOI reference | Broken links | Verify DOI resolves |
| Wrong license | Legal issues | Use CC-BY-4.0 |

### 7.2 Content Issues

| Issue | Impact | Fix |
|-------|--------|-----|
| Abstract >500 words | Truncated in previews | Keep to 150-250 words |
| No structured abstract | Hard to parse | Use 5-sentence format |
| Missing references | Cannot verify claims | Add citations |
| No code link | Not reproducible | Add GitHub URL |

---

## 8. Post-Publication Promotion

### 8.1 Indexing Services

Submit to:
- Google Scholar (auto-indexed)
- Semantic Scholar (auto-indexed)
- arXiv (cross-submit as preprint)
- ADS (if physics-related)
- ACM Digital Library (request)

### 8.2 Social Media

- Twitter/X: Thread with key results, DOI link
- LinkedIn: Professional summary
- Reddit: r/MachineLearning, r/FPGA
- Hacker News: If hardware focus

### 8.3 Academic Communities

- NeurIPS poster session
- FPGA conference presentations
- University seminar series
- ResearchGate updates

---

## 9. Version Management

### 9.1 Versioning Strategy

```
v1.0.0: Initial publication
v1.1.0: Minor corrections (typos, formatting)
v2.0.0: Major update (new results, methods)
v2.1.0: Minor additions to v2.0.0
```

### 9.2 DOI Versioning

- Each version gets unique DOI
- Concept DOI always resolves to latest
- Specific version DOIs remain stable

```
Concept: 10.5281/zenodo.19227879 (always latest)
v1.0.0: 10.5281/zenodo.19227865
v2.0.0: 10.5281/zenodo.19227880
```

---

## 10. Examples

### 10.1 Complete Metadata Example

See: `docs/research/citation/` for examples of:
- Bundle B001 (Ternary NN)
- Bundle B002 (TRI-27)
- Bundle B003 (VSA)
- Bundle B004 (Queen)
- Bundle B005 (Tri Language)
- Bundle B006 (VSA Ternary)
- Bundle B007 (TBD)
- PARENT (Complete framework)

### 10.2 Complete CITATION.cff

See: `CITATION.cff` (repository root)

---

## 11. References

1. Zenodo Community Guidelines. https://help.zenodo.org/
2. FAIR Principles. https://www.go-fair.org/fair-principles/
3. ACM Computing Classification System. https://www.acm.org/ccs
4. BibTeX Guide. https://www.ctan.org/pkg/bibtex

---

**φ² + 1/φ² = 3 | TRINITY S³AI**
