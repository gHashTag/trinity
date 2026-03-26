# Advanced Zenodo Publishing Patterns — 2026 Best Practices

**Author:** Dmitrii Vasilev
**Date:** 2026-03-26
**Version:** 1.0
**License:** CC-BY-4.0

---

## Executive Summary

This guide presents **state-of-the-art** Zenodo publishing patterns for 2026, incorporating:
- DataCite Metadata Schema v4.4 (latest)
- FAIR Principles 2.0 (2025 update)
- OpenAIRE Guidelines v4.0
- FORCE11 Data Citation Principles (2025 revision)
- NSF-recommended reproducibility standards
- EU Open Science Policy (2025)

---

## Part 1: Metadata Excellence

### 1.1 Title Optimization (2026 Standards)

**Scientific Title Formula:**
```
[Framework Name]: [Key Innovation] — [Artifact Type] v[X.X]
```

**Examples:**
- ✅ "Trinity S³AI: Ternary Neural Networks with Zero-DSP FPGA Inference v2.0"
- ✅ "Scientific Metrics v7.5: Statistical Validity and Reproducibility Artifacts for AGI Evaluation"
- ❌ "Trinity Framework" (too vague)
- ❌ "metrics.py" (not descriptive)

**Title Requirements (2026):**
- Max 250 characters (Zenodo limit)
- Include version number
- Include key innovation
- Include artifact type
- Use sentence case (not title case)
- Avoid abbreviations (except widely known: AI, FPGA, LLM)

### 1.2 Author Metadata (Complete)

```yaml
creators:
  - family-names: Vasilev
    given-names: Dmitrii
    affiliation: Trinity S³AI
    orcid: "https://orcid.org/0000-0000-0000-0000"
    type: Person
    role: ContactPerson

  # For multiple authors, maintain order:
  - family-names: Second
    given-names: Jane
    affiliation: University of Example
    orcid: "https://orcid.org/0000-0001-2345-6789"
    type: Person
```

**Affiliation Best Practices:**
- Use ROR IDs where possible: `https://ror.org/xxxxx`
- Include full department: "Department of Computer Science, University of Example"
- For independent: "Independent Researcher" or organization name

### 1.3 Description Structure (2026 Template)

```markdown
## Summary (2-3 sentences, < 150 words)

[Brief description of what the artifact does and why it matters]

## Key Features (5-7 bullet points)

- **Feature 1**: Description with paper citation
- **Feature 2**: Description with paper citation
- ...

## Scientific Validity (2-3 paragraphs)

[Explain how methods follow peer-reviewed research]
[Include statistical validation details]
[Mention reproducibility measures]

## Validation (1-2 paragraphs)

[Describe testing methodology]
[Include sample sizes, benchmarks, comparison studies]

## Usage (code example)

```python
[Short, copy-pasteable example]
```

## References (numbered, APA format)

1. Author, A. (Year). Title. *Journal*, *Volume*(Issue), pages. DOI
2. ...
```

**Word Count Guidelines:**
- Minimum: 500 words (Zenodo recommended)
- Optimal: 800-1200 words
- Maximum: 2000 words (readability drops after)

### 1.4 Keywords (Controlled Vocabulary)

**2026 Best Practice:** Use a mix of:
1. **Domain terms** (3-4): AGI, machine learning, neural networks
2. **Method terms** (3-4): calibration, quantization, FPGA synthesis
3. **Application terms** (2-3): benchmarking, evaluation, inference

**Keyword Sources (Priority Order):**
1. **MeSH** (Medical Subject Headings): https://meshb.nlm.nih.gov/
2. **ACM CCS** (Computing Classification System): https://dl.acm.org/ccs
3. **GND** (German National Library): https://d-nb.info/gnd
4. **LOC** (Library of Congress): https://id.loc.gov/

**Example (12 keywords):**
```
AGI evaluation, confidence calibration, Expected Calibration Error,
metacognition, contamination detection, Min-K%++, CoDeC,
bootstrap confidence intervals, Brier score, ternary neural networks,
FPGA inference, scientific benchmarking
```

### 1.5 Subjects (Formal Classification)

**Required for 2026:** At least 3 subjects from controlled vocabularies.

```json
"subjects": [
  {
    "term": "Artificial Intelligence",
    "identifier": "http://id.loc.gov/authorities/subjects/sh85009003",
    "scheme": "url"
  },
  {
    "term": "Machine Learning",
    "identifier": "http://id.loc.gov/authorities/subjects/sh2010101052",
    "scheme": "url"
  },
  {
    "term": "Computer arithmetic",
    "identifier": "https://www.wikidata.org/entity/Q170458",
    "scheme": "url"
  }
]
```

---

## Part 2: FAIR Principles 2.0 Compliance (2025 Update)

### F1: Findable

- [ ] **DOI reserved** before publication
- [ ] **DOI in metadata** (self-referencing)
- [ ] **Rich metadata** (all required fields complete)
- [ ] **Indexed** in Zenodo + DataCite + Google Scholar

### F2: Accessible

- [ ] **Open license** (CC-BY-4.0 recommended for code+docs)
- [ ] **DOI resolves** to landing page
- [ ] **Metadata accessible** via OAI-PMH
- [ ] **No authentication** required for access

### F3: Interoperable

- [ ] **JSON Schema** valid for metadata
- [ ] **FAIR vocabularies** used (MeSH, ACM CCS, etc.)
- [ ] **Related identifiers** include DOIs
- [ ] **Formal language** for metadata (JSON-LD recommended)

### F4: Reusable

- [ ] **License specified** (CC-BY-4.0 for bundles)
- [ ] **Provenance tracked** (git tags, version history)
- [ ] **Community standards** followed (Citation File Format)
- [ ] **Clear usage** documentation

### I1: Interoperable - Metadata Standards

- [ ] **DataCite v4.4** schema compliance
- [ ] **JSON-LD** context for linked data
- [ ] **Schema.org** markup for SEO

### I2: Interoperable - Vocabularies

- [ ] **MeSH** for biomedical terms
- [ ] **ACM CCS** for computing topics
- [ ] **GND** for general subjects
- [ ] **ROR** for institutions

### I3: Interoperable - References

- [ ] **All cited works** have PIDs (DOIs, arXiv IDs)
- [ ] **Related identifiers** properly linked
- [ ] **Citation format** consistent (APA 7th)

### R1.1: Reusable - License

- [ ] **Appropriate license** selected:
  - Code only: MIT or Apache-2.0
  - Data only: CC0 1.0
  - Documentation: CC-BY-4.0
  - Mixed bundle: CC-BY-4.0 (recommended)

### R1.2: Reusable - Provenance

- [ ] **Git tag** linked to DOI
- [ ] **Version history** documented
- [ ] **Contributors** acknowledged
- [ ] **Funding** sources declared

### R1.3: Reusable - Community Standards

- [ ] **CITATION.cff** included
- [ ] **README.md** comprehensive
- [ ] **CHANGELOG.md** maintained
- [ ] **CONTRIBUTING.md** for collaboration

---

## Part 3: File Organization (2026 Standard)

### 3.1 Required Files

```
bundle_name/
├── README.md                    # Landing page description
├── CITATION.cff                 # Machine-readable citation
├── LICENSE                      # Legal terms
├── AUTHORS.md                   # Contributor list (optional)
├── CHANGELOG.md                 # Version history
├── .zenodo.json                 # Metadata template (NEW)
├── docs/
│   ├── methods.md               # Detailed methodology
│   ├── results.md               # Tables, figures, benchmarks
│   ├── reproducibility.md       # How to reproduce
│   └── figures/
│       ├── architecture.png
│       └── results.pdf
├── code/
│   ├── src/                     # Source code
│   ├── tests/                   # Test suite
│   └── requirements.txt         # Dependencies
└── data/
    ├── README.md                # Data description
    └── [datasets]               # If applicable
```

### 3.2 The .zenodo.json File (2026 Standard)

**New in 2026:** Zenodo supports `.zenodo.json` for metadata pre-configuration.

```json
{
  "title": "Trinity S³AI: Ternary Neural Networks with Zero-DSP FPGA Inference v2.0",
  "upload_type": "publication",
  "publication_type": "article",
  "description": "See README.md for full description",
  "creators": [
    {
      "name": "Vasilev, Dmitrii",
      "affiliation": "Trinity S³AI",
      "orcid": "0000-0000-0000-0000"
    }
  ],
  "keywords": ["ternary neural networks", "FPGA", "zero-DSP", "inference", "quantization"],
  "license": "CC-BY-4.0",
  "communities": [
    {"identifier": "trinity-s3ai"}
  ],
  "grants": [
    {
      "id": "AGI-HACK-2026-001"
    }
  ]
}
```

---

## Part 4: Citation File Format (CITATION.cff v1.2.0)

**2026 Standard:** Use CFF v1.2.0 with all required fields.

```yaml
cff-version: 1.2.0
message: "If you use this software, please cite it as below."
title: "Trinity S³AI: Ternary Neural Networks with Zero-DSP FPGA Inference"
abstract: "Complete framework for ternary neural network inference on FPGA without DSP resources."

authors:
  - family-names: Vasilev
    given-names: Dmitrii
    affiliation: Trinity S³AI
    orcid: "https://orcid.org/0000-0000-0000-0000"

version: 2.0.0
doi: 10.5281/zenodo.XXXXXX
date-released: 2026-03-26

url: https://github.com/gHashTag/trinity
repository-code: https://github.com/gHashTag/trinity
repository-artifact: https://zenodo.org/record/XXXXXX

keywords:
  - ternary neural networks
  - FPGA
  - zero-DSP
  - inference
  - quantization
  - phi-based optimization

license: CC-BY-4.0

preferred-citation:
  type: article
  authors:
    - family-names: Vasilev
      given-names: Dmitrii
  title: "Trinity S³AI: Zero-DSP Ternary Inference on FPGA"
  year: 2026
  journal: "Google DeepMind AGI Hackathon"
  volume: 1
  issue: 1
  doi: 10.5281/zenodo.XXXXXX

references:
  - type: article
    authors:
      - family-names: Vaswani
        given-names: Ashish
    title: "Attention is all you need"
    year: 2017
    journal: "NeurIPS"
    volume: 30
    doi: 10.5555/3295222.3295349

contact:
  - family-names: Vasilev
    given-names: Dmitrii
    email: dmitrii@trinity-s3.ai
    orcid: "https://orcid.org/0000-0000-0000-0000"
```

---

## Part 5: README.md Template (2026 Enhanced)

```markdown
# [Project Name] — Zenodo Bundle

[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.XXXXXX.svg)](https://doi.org/10.5281/zenodo.XXXXXX)
[![License](https://img.shields.io/badge/license-CC--BY--4.0-blue.svg)](LICENSE)
[![Python](https://img.shields.io/badge/python-3.10+-blue.svg)](https://python.org)

**Version:** X.X | **Release Date:** 2026-03-26 | **Author:** Dmitrii Vasilev

## Quick Start

```bash
# Clone repository
git clone https://github.com/gHashTag/trinity.git
cd trinity

# Install dependencies
pip install -r requirements.txt

# Run tests
pytest tests/ -v

# Example usage
python examples/basic_usage.py
```

## Overview

[Brief 2-3 sentence overview of the project]

## Key Features

| Feature | Description | Reference |
|---------|-------------|-----------|
| Feature 1 | Description | [Citation] |
| Feature 2 | Description | [Citation] |

## Citation

### BibTeX
```bibtex
@software{vasilev_2026_trinity,
  author = {Vasilev, Dmitrii},
  title = {Trinity S³AI: Ternary Neural Networks with Zero-DSP FPGA Inference},
  year = {2026},
  version = {2.0},
  doi = {10.5281/zenodo.XXXXXX},
  url = {https://github.com/gHashTag/trinity}
}
```

### APA
Vasilev, D. (2026). *Trinity S³AI: Ternary Neural Networks with Zero-DSP FPGA Inference* (Version 2.0) [Computer software]. Zenodo. https://doi.org/10.5281/zenodo.XXXXXX

## Contents

| File | Description | LOC |
|------|-------------|-----|
| `src/main.py` | Main implementation | 500 |
| `tests/test_main.py` | Test suite | 300 |

## License

This work is licensed under [CC-BY-4.0](LICENSE).

## Acknowledgments

- Google DeepMind AGI Hackathon 2026
- Trinity S³AI open source community

## Contact

- **Author:** Dmitrii Vasilev
- **GitHub:** https://github.com/gHashTag/trinity
- **Issues:** https://github.com/gHashTag/trinity/issues
```

---

## Part 6: Advanced Metadata Patterns

### 6.1 Related Identifiers (Complete)

```json
"related_identifiers": [
  {
    "identifier": "10.48550/arxiv.2406.11345",
    "relation": "cites",
    "resource_type": "publication-article",
    "scheme": "doi"
  },
  {
    "identifier": "10.5281/zenodo.19223952",
    "relation": "isNewVersionOf",
    "resource_type": "software",
    "scheme": "doi"
  },
  {
    "identifier": "https://github.com/gHashTag/trinity/tree/v2.0",
    "relation": "isSupplementedBy",
    "resource_type": "software",
    "scheme": "url"
  }
]
```

**Relation Types (DataCite v4.4):**
- `isCitedBy`, `cites` — Citation relationships
- `isSupplementTo`, `isSupplementedBy` — Supplementary materials
- `isNewVersionOf`, `isPreviousVersionOf` — Versioning
- `isPartOf`, `hasPart` — Containment
- `isReferencedBy`, `references` — Reference relationships

### 6.2 Funding (OpenAIRE Format)

```json
"funding": [
  {
    "funder": {
      "name": "European Commission",
      "doi": "10.13039/501100000780",
      "award": [
        {
          "title": "Open Science Cloud",
          "number": "101017721"
        }
      ]
    }
  },
  {
    "funder": {
      "name": "Google DeepMind",
      "doi": "10.13039/501100000735",
      "award": [
        {
          "title": "AGI Hackathon 2026",
          "number": "AGI-HACK-2026"
        }
      ]
    }
  }
]
```

### 6.3 Communities (Strategic Selection)

**Recommended Communities for 2026:**

| Community | Focus | When to Use |
|-----------|-------|-------------|
| `zenodo` | General | Always add |
| `eosc` | European Open Science | EU projects |
| `research-research-data` | Research data | Datasets included |
| `open-source` | Open source software | Software bundles |

---

## Part 7: Validation Checklist (Pre-Publication)

### Metadata Completeness

- [ ] Title follows 2026 formula (Framework: Innovation — Type vX.X)
- [ ] All creators have ORCID IDs
- [ ] Affiliations use ROR identifiers
- [ ] Description is 800-1200 words (optimal range)
- [ ] 6-12 keywords provided (mix of domain/method/application)
- [ ] 3+ subjects from controlled vocabularies
- [ ] All references formatted consistently (APA 7th)
- [ ] Related identifiers include DOIs for cited works

### FAIR 2.0 Compliance

- [ ] **F1**: DOI reserved and in metadata
- [ ] **F2**: Rich metadata complete (all required fields)
- [ ] **F3**: DOI self-referenced in metadata
- [ ] **F4**: Will be indexed (Zenodo + DataCite + Google Scholar)
- [ ] **A1**: DOI will resolve to landing page
- [ ] **A1.1**: Metadata accessible via API
- [ ] **I1**: JSON Schema valid
- [ ] **I2**: FAIR vocabularies used (MeSH, ACM CCS, GND)
- [ ] **I3**: Related works have PIDs
- [ ] **R1.1**: License specified (CC-BY-4.0 recommended)
- [ ] **R1.2**: Provenance tracked (git tag linked)
- [ ] **R1.3**: Community standards followed (CFF, README)

### File Organization

- [ ] README.md present and comprehensive
- [ ] LICENSE file present (CC-BY-4.0 recommended)
- [ ] CITATION.cff present (v1.2.0 format)
- [ ] CHANGELOG.md present
- [ ] .zenodo.json present (2026 standard)
- [ ] Source code well-documented
- [ ] Tests included with >80% coverage
- [ ] Example scripts provided

### Scientific Rigor

- [ ] All methods cited with DOIs/arXiv IDs
- [ ] Statistical parameters documented
- [ ] Reproducibility ensured (random seeds, versions)
- [ ] Validation results included
- [ ] Known limitations documented
- [ ] Comparison to state-of-the-art provided

---

## Part 8: Common Pitfalls (2026)

### Pitfall 1: Insufficient Description

**Error:** Description < 500 words

**Fix:** Use structured template with all sections (Summary, Key Features, Scientific Validity, Validation, Usage, References)

### Pitfall 2: Missing ORCID

**Error:** Creators without ORCID IDs

**Fix:** Get ORCID at https://orcid.org (free, takes 2 minutes)

### Pitfall 3: Wrong License

**Error:** Using "All rights reserved" for research software

**Fix:** Use CC-BY-4.0 for bundles, MIT/Apache-2.0 for code-only

### Pitfall 4: Incomplete References

**Error:** Citations without DOIs

**Fix:** Always include DOI or arXiv ID for cited works

### Pitfall 5: No Version Control

**Error:** DOI not linked to git tag

**Fix:** Create git tag before Zenodo upload, link in metadata

### Pitfall 6: Poor Keywords

**Error:** Using generic keywords like "software", "data"

**Fix:** Use specific domain+method+application keywords

### Pitfall 7: Missing Communities

**Error:** Not adding to any Zenodo community

**Fix:** At minimum add to "zenodo" community

---

## Part 9: API Upload (Python Script)

```python
#!/usr/bin/env python3
"""
Zenodo Upload Script — 2026 Edition
Supports .zenodo.json metadata pre-configuration
"""

import json
import requests
from pathlib import Path

# Configuration
ZENODO_API = "https://zenodo.org/api"  # Use sandbox.zenodo.org for testing
ACCESS_TOKEN = "YOUR_ACCESS_TOKEN"  # Get from Zenodo account settings

def create_deposition(metadata_file: str = ".zenodo.json"):
    """Create a new Zenodo deposition with metadata."""
    headers = {"Content-Type": "application/json"}

    # Load metadata from .zenodo.json if exists
    metadata_path = Path(metadata_file)
    if metadata_path.exists():
        with open(metadata_path) as f:
            metadata = json.load(f)
    else:
        metadata = {}

    # Create deposition
    response = requests.post(
        f"{ZENODO_API}/deposit/depositions",
        params={"access_token": ACCESS_TOKEN},
        json=metadata,
        headers=headers
    )
    response.raise_for_status()
    return response.json()

def upload_files(deposition_id: str, files: list[Path]):
    """Upload files to deposition."""
    for filepath in files:
        with open(filepath, "rb") as f:
            response = requests.post(
                f"{ZENODO_API}/deposit/depositions/{deposition_id}/files",
                params={"access_token": ACCESS_TOKEN},
                data={"filename": filepath.name},
                files={"file": f}
            )
            response.raise_for_status()
            print(f"Uploaded: {filepath.name}")

def publish_deposition(deposition_id: str):
    """Publish the deposition (creates DOI)."""
    response = requests.post(
        f"{ZENODO_API}/deposit/depositions/{deposition_id}/actions/publish",
        params={"access_token": ACCESS_TOKEN}
    )
    response.raise_for_status()
    return response.json()

def main():
    # Step 1: Create deposition
    print("Creating deposition...")
    deposition = create_deposition()
    deposition_id = deposition["id"]
    print(f"Created deposition: {deposition_id}")

    # Step 2: Upload files
    print("Uploading files...")
    files_to_upload = [
        Path("README.md"),
        Path("CITATION.cff"),
        Path("LICENSE"),
        Path("src/"),
    ]
    upload_files(deposition_id, files_to_upload)

    # Step 3: Publish
    print("Publishing deposition...")
    result = publish_deposition(deposition_id)
    doi = result["doi"]
    print(f"Published! DOI: {doi}")

    return doi

if __name__ == "__main__":
    main()
```

---

## Part 10: Post-Publication Checklist

### Immediately After Publication

- [ ] Verify DOI resolves: https://doi.org/10.XXXX/XXXXXX
- [ ] Check metadata displays correctly on Zenodo
- [ ] Confirm all files are accessible
- [ ] Test download links
- [ ] Verify citation formats are correct

### Within 1 Week

- [ ] Add DOI to GitHub repository (README, releases)
- [ ] Update CITATION.cff with DOI
- [ ] Submit to relevant indexing services:
  - Google Scholar (auto-indexed from Zenodo)
  - ADS (for astrophysics)
  - PMC (for biomedical)
- [ ] Share on academic social networks:
  - ORCID profile
  - Google Scholar profile
  - ResearchGate
  - Twitter/X with hashtags (#OpenScience, #Zenodo)

### Ongoing Maintenance

- [ ] Track citations using Zenodo statistics
- [ ] Respond to comments/questions
- [ ] Create new version for significant updates
- [ ] Update CHANGELOG.md with version history

---

## Document Version: 1.0
**Last Updated:** 2026-03-26
**Status:** Ready for Use
**Standards:** DataCite v4.4, FAIR 2.0, OpenAIRE v4.0

**φ² + 1/φ² = 3 | TRINITY**
