# Kaggle Scientific Metrics — Zenodo Publishing Best Practices

**Date**: 2026-03-26
**Version**: 1.0
**Status**: Active

---

## Overview

This document provides scientifically rigorous guidelines for publishing Trinity Cognitive Probes research bundles on Zenodo, following FAIR principles and DataCite Metadata Schema v4.

---

## Table of Contents

1. [FAIR Principles Compliance](#fair-principles-compliance)
2. [Required Metadata Fields](#required-metadata-fields)
3. [Recommended Metadata Fields](#recommended-metadata-fields)
4. [File Organization](#file-organization)
5. [Version Management](#version-management)
6. [Community Integration](#community-integration)
7. [Quality Assurance Checklist](#quality-assurance-checklist)
8. [Citation Best Practices](#citation-best-practices)

---

## FAIR Principles Compliance

### Findable

| Principle | Implementation |
|-----------|----------------|
| **F1**: Globally unique persistent identifier | Each bundle receives DOI: `10.5281/zenodo.XXXXXXX` |
| **F2**: Rich metadata | Complete DataCite Schema v4 compliance |
| **F3**: Identifier in metadata | DOI included as top-level mandatory field |
| **F4**: Searchable indexing | Indexed in Zenodo + DataCite + OpenAIRE |

### Accessible

| Principle | Implementation |
|-----------|----------------|
| **A1**: Retrieve by identifier | DOI resolves to `https://zenodo.org/record/XXXXXXX` |
| **A1.1**: Metadata accessible | Standard protocols: OAI-PMH, JSON, XML |
| **A1.2**: Authentication | Open access (no authentication required) |

### Interoperable

| Principle | Implementation |
|-----------|----------------|
| **I1**: Formal language | JSON Schema internal + DataCite XML export |
| **I2**: FAIR vocabularies | Open Definition (licenses), FundRef (funders), ROR (organizations) |
| **I3**: Qualified references | All related works include resolvable PIDs |

### Reusable

| Principle | Implementation |
|-----------|----------------|
| **R1.1**: Descriptive metadata | Rich license, usage clarity |
| **R1.2**: Provenance | Traceable to registered Zenodo user + ORCID |
| **R1.3**: Community standards | DataCite Metadata Schema v4 + OpenAIRE v3.0 |

---

## Required Metadata Fields

### 1. Title

**Pattern**: `[Component Name]: [Description] — [Context]`

**Examples**:
```
✅ Good: "Scientific Metrics v7.4: Statistical Validity and Reproducibility Artifacts"
✅ Good: "Min-K%++ & CoDeC: Contamination Detection Benchmarks"
❌ Bad: "metrics.py" (too vague)
❌ Bad: "Data from Kaggle" (non-specific)
```

**Requirements**:
- Short, declarative sentence
- Differs from associated publication
- Maximum 250 characters recommended
- Include version number for software

### 2. Resource Type

**DataCite Types**:
- `Dataset` — CSV, JSON, HDF5 data files
- `Software` — Python code, models, pipelines
- `Other` — Documentation, hybrid bundles

**Our Usage**:
```yaml
upload_type: publication
publication_type: technicalnote
```

### 3. Creators

**Format**: `FamilyName, GivenName` (searchable in Zenodo)

**Example**:
```json
{
  "creators": [
    {
      "name": "Vasilev, Dmitrii",
      "affiliation": "Trinity S³AI",
      "orcid": "0000-0000-0000-0000"
    }
  ]
}
```

**Best Practices**:
- Include ORCID for all individual creators
- Use ROR for institutional affiliations
- Specify roles: `ContactPerson`, `DataCurator`, `SoftwareDeveloper`

### 4. Description

**Structure** (250-2000 words recommended):

```markdown
## Summary
[2-3 sentence overview of the bundle's purpose]

## Contents
[List of files with brief descriptions]

## Methods
[Scientific methodology used]

## Usage
[How to use the data/software]

## Validation
[How results were validated]

## References
[Citations to related papers]
```

**Example**:
```markdown
## Summary
This bundle contains the v7.4 implementation of scientific metrics for LLM confidence
calibration and contamination detection, validated against arXiv:2404.02936 and
arXiv:2510.27055.

## Contents
- scientific_metrics_v7.py — Main implementation (1,240 LOC)
- test_scientific_metrics_v7.py — Test suite (32 tests, 98% coverage)
- validation_data.json — Benchmark results on 5 models
- CORRECTIONS_V7_4.md — Documentation of fixes

## Methods
ECE computed using 10-bin uniform binning (Naeini et al., AAAI 2015).
Min-K%++ follows the algorithm in arXiv:2404.02936 with vocabulary-based scoring.

## Usage
```python
from scientific_metrics_v7 import calculate_full_ece_v7
ece = calculate_full_ece_v7(confidences, correct_labels)
```

## Validation
All metrics tested on held-out set (n=1000). Bootstrap CI (n=1000) for all estimates.

## References
- Mielke et al. (2024). Verbalized Confidence in LLMs.
- arXiv:2404.02936 — Min-K%++ Probabilities
- arXiv:2510.27055 — CoDeC Contamination
```

### 5. Publication Date

**Rule**: Use the date the record is **published**, not drafted.

**Format**: `YYYY-MM-DD`

### 6. Access Rights

**Recommended Licenses**:

| Use Case | License | SPDX ID |
|----------|---------|---------|
| Code | MIT License | `MIT` |
| Data | CC0 1.0 Universal | `CC0-1.0` |
| Data (attribution) | CC BY 4.0 | `CC-BY-4.0` |
| Data (share-alike) | CC BY-SA 4.0 | `CC-BY-SA-4.0` |
| Documentation | CC BY 4.0 | `CC-BY-4.0` |

**Our Usage**:
```yaml
license: CC-BY-4.0  # For hybrid bundles
access_right: open  # Open access
```

### 7. Keywords

**Requirements**:
- Minimum 3 keywords recommended
- Maximum 20 keywords (practical limit)
- Include controlled vocabulary terms

**Best Practices**:
```json
{
  "keywords": [
    "LLM confidence calibration",
    "Expected Calibration Error",
    "meta-d'",
    "contamination detection",
    "Min-K%++",
    "CoDeC",
    "scientific benchmarking",
    "AGI evaluation"
  ],
  "subjects": [
    {
      "term": "Artificial Intelligence",
      "identifier": "https://id.loc.gov/authorities/subjects/sh85009003",
      "scheme": "url"
    },
    {
      "term": "Machine Learning",
      "identifier": "https://vocabularies.coar-repositories.org/documentation/access_modes/",
      "scheme": "url"
    }
  ]
}
```

---

## Recommended Metadata Fields

### 1. Related Identifiers

**DataCite Relation Types**:
- `isCitedBy` — Bundle is cited by a paper
- `cites` — Bundle cites another work
- `isSupplementTo` — Bundle supplements a paper
- `isSupplementedBy` — Paper supplements the bundle
- `isNewVersionOf` — New version of previous bundle
- `isPreviousVersionOf` — Previous version of this bundle

**Example**:
```json
{
  "related_identifiers": [
    {
      "identifier": "10.5281/zenodo.19223952",
      "relation": "isNewVersionOf",
      "resource_type": "software"
    },
    {
      "identifier": "10.48550/arxiv.2404.02936",
      "relation": "isSupplementTo",
      "resource_type": "publication-article"
    },
    {
      "identifier": "10.48550/arxiv.2510.27055",
      "relation": "cites",
      "resource_type": "publication-article"
    }
  ]
}
```

### 2. Funding

**Format** (OpenAIRE compliant):
```json
{
  "funding": [
    {
      "funder": {
        "name": "Google DeepMind",
        "doi": "10.13039/501100000735"
      },
      "award": {
        "title": "AGI Hackathon 2026",
        "number": "AGI-HACK-2026-001"
      }
    }
  ]
}
```

### 3. Communities

**Recommended Communities**:
1. **Trinity Cognitive Probes** — Custom community for this project
2. **zenodo** — General Zenodo community
3. **OpenAIRE** — European open science infrastructure

**Benefits**:
- Higher search result priority
- Community curation and quality assurance
- Automated metadata harvesting

### 4. References

**Include**:
- All papers cited in methodology
- Related software packages
- Competing implementations (for comparison)

**Format**:
```markdown
## References

1. Mielke, S. J., et al. (2024). Verbalized Confidence in Large Language Models.
   *arXiv preprint* arXiv:2406.11345.

2. Maniscalco, B., et al. (2023). Measuring Metacognitive Sensitivity.
   *Cognitive Science*, 47(6), e13272.

3. ARC Team (2024). Measuring Progress Toward AGI.
   *ARC-AGI-2 Technical Report*.
```

---

## File Organization

### Directory Structure

```
bundle_name/
├── README.md                    # Required: Overview
├── LICENSE                      # Required: License file
├── CITATION.cff                 # Recommended: Citation metadata
├── CHANGELOG.md                 # Recommended: Version history
├── src/                         # Source code
├── data/                        # Data files
├── tests/                       # Test suite
├── docs/                        # Documentation
└── metadata/                    # Additional metadata
    ├── validation_report.json   # Validation results
    ├── provenance.json          # Data lineage
    └── schema.json              # Data schema
```

### File Naming Conventions

| Type | Pattern | Example |
|------|---------|---------|
| Code | `{name}_v{version}.py` | `scientific_metrics_v7_4.py` |
| Data | `{dataset}_{version}.csv` | `benchmark_results_v7_4.csv` |
| Tests | `test_{name}.py` | `test_scientific_metrics_v7.py` |
| Docs | `{topic}.md` | `IMPLEMENTATION_SUMMARY.md` |

### README Template

```markdown
# {Bundle Name}

**Version**: {X.Y.Z}
**DOI**: [10.5281/zenodo.XXXXXXX](https://doi.org/10.5281/zenodo.XXXXXXX)
**License**: {License Name}

## Quick Start

```bash
# Installation
pip install -r requirements.txt

# Usage
python -m {module} --help
```

## Contents

| File | Description |
|------|-------------|
| `{main_file}` | Main implementation |
| `{test_file}` | Test suite ({n}% coverage) |
| `{data_file}` | Validation data |

## Citation

```bibtex
@software{bundle_id,
  author       = {Author Name},
  title        = {Bundle Title},
  year         = {2026},
  publisher    = {Zenodo},
  version      = {vX.Y.Z},
  doi          = {10.5281/zenodo.XXXXXXX},
  url          = {https://zenodo.org/record/XXXXXXX}
}
```

## Changelog

### v{X.Y.Z} ({Date})
- Added: {feature}
- Fixed: {bug}
- Changed: {modification}

## Validation

- ✅ Code passes all tests ({n}/{n})
- ✅ Coverage: {percentage}%
- ✅ Lint: No errors
- ✅ Type checking: Passed

## Contact

- Issues: https://github.com/gHashTag/trinity/issues
- Email: contact@example.com
```

### CITATION.cff Format

```yaml
cff-version: 1.2.0
title: "Scientific Metrics v7.4: Statistical Validity and Reproducibility"
message: "If you use this bundle, please cite it as below."
type: software
authors:
  - family-names: "Vasilev"
    given-names: "Dmitrii"
    affiliation: "Trinity S³AI"
    orcid: "https://orcid.org/0000-0000-0000-0000"
version: "7.4"
doi: "10.5281/zenodo.19223952"
url: "https://github.com/gHashTag/trinity"
date-released: "2026-03-25"
license: CC-BY-4.0
keywords:
  - "LLM calibration"
  - "ECE"
  - "meta-d'"
  - "contamination detection"
```

---

## Version Management

### Semantic Versioning

```
MAJOR.MINOR.PATCH

MAJOR — Breaking changes to API or data format
MINOR — New features, backward compatible
PATCH — Bug fixes, documentation updates
```

### Version Policy

| Change Type | Version Increment | Example |
|-------------|-------------------|---------|
| New metric | MINOR | 7.4 → 7.5 |
| Bug fix | PATCH | 7.4.0 → 7.4.1 |
| API change | MAJOR | 7.x → 8.0 |

### DOI Policy

- **New DOI for**: MAJOR and MINOR versions
- **Same DOI for**: PATCH versions (update metadata)
- **Always preserve**: Previous versions remain accessible

---

## Community Integration

### Trinity Cognitive Probes Community

**Purpose**: Curated collection of all Trinity research bundles

**Curation Policy**:
```markdown
# Trinity Cognitive Probes Community Curation Policy

## Scope
This community accepts research outputs related to:
- LLM confidence calibration
- Metacognitive evaluation
- Contamination detection
- AGI benchmarking

## Requirements
1. Complete DataCite metadata
2. Open access license (CC-BY or CC0)
3. Test coverage ≥ 80%
4. Documentation (README + CITATION.cff)
5. Validation results included

## Review Process
- Automated: CI checks, linting, coverage
- Manual: Domain expert review within 7 days
- Decision: Accept, Request Changes, Reject

## Quality Standards
- Code: PEP 8 compliant, type hints
- Data: Schema validation, completeness check
- Docs: Clear usage examples, citations
```

---

## Quality Assurance Checklist

### Pre-Publication Checklist

```markdown
## Metadata
- [ ] Title follows naming pattern
- [ ] Description is 250-2000 words
- [ ] 3+ keywords included
- [ ] All creators have ORCID
- [ ] License specified
- [ ] Related identifiers added
- [ ] Funding information complete

## Files
- [ ] README.md present and complete
- [ ] LICENSE file present
- [ ] CITATION.cff present
- [ ] Code passes all tests
- [ ] Coverage ≥ 80%
- [ ] No hardcoded secrets
- [ ] File naming follows convention

## Documentation
- [ ] Installation instructions
- [ ] Usage examples
- [ ] API reference
- [ ] Changelog maintained
- [ ] Contact information

## Validation
- [ ] Results reproducible
- [ ] Benchmarks included
- [ ] Comparison to baselines
- [ ] Statistical significance reported
```

### Automated Checks

```python
#!/usr/bin/env python3
"""Zenodo pre-publication validation."""

import json
import subprocess
from pathlib import Path

def validate_metadata(metadata_path: Path) -> bool:
    """Validate metadata completeness."""
    required = ["title", "creators", "description", "keywords", "license"]
    with open(metadata_path) as f:
        data = json.load(f)

    for field in required:
        if field not in data:
            print(f"❌ Missing required field: {field}")
            return False
    print("✅ Metadata complete")
    return True

def validate_tests() -> bool:
    """Run test suite."""
    result = subprocess.run(
        ["python", "-m", "pytest", "--cov=kaggle"],
        capture_output=True
    )
    coverage = parse_coverage(result.stdout)
    if coverage < 80:
        print(f"❌ Coverage too low: {coverage}%")
        return False
    print(f"✅ Coverage: {coverage}%")
    return True

def validate_files(directory: Path) -> bool:
    """Validate file presence."""
    required = ["README.md", "LICENSE", "CITATION.cff"]
    for f in required:
        if not (directory / f).exists():
            print(f"❌ Missing required file: {f}")
            return False
    print("✅ Required files present")
    return True

if __name__ == "__main__":
    base = Path(".")
    validate_metadata(base / "zenodo_metadata.json")
    validate_tests()
    validate_files(base)
```

---

## Citation Best Practices

### BibTeX Citation

```bibtex
@software{trinity_scientific_metrics_v7_4,
  author       = {Vasilev, Dmitrii},
  title        = {Scientific Metrics v7.4: Statistical Validity and Reproducibility},
  year         = {2026},
  publisher    = {Zenodo},
  version      = {7.4},
  doi          = {10.5281/zenodo.19223952},
  url          = {https://doi.org/10.5281/zenodo.19223952}
}
```

### APA Citation

```
Vasilev, Dmitrii. (2026). Scientific metrics v7.4: Statistical validity
and reproducibility artifacts (Version 7.4) [Computer software]. Zenodo.
https://doi.org/10.5281/zenodo.19223952
```

### MLA Citation

```
Trinity Cognitive Probes Team. *Scientific Metrics v7.4: Statistical Validity and
Reproducibility Artifacts*. Version 7.4, Zenodo, 2026, doi:10.5281/zenodo.19223952.
```

### In-Text Citation

```
Recent work on LLM calibration (Vasilev, 2026) demonstrates
that temperature scaling can improve ECE by up to 15%.

According to the Scientific Metrics v7.4 bundle (10.5281/zenodo.19223952),
proper calibration requires...
```

---

## Resources

- **Zenodo Documentation**: https://help.zenodo.org/
- **DataCite Schema**: https://schema.datacite.org/
- **FAIR Principles**: https://www.go-fair.org/fair-principles/
- **CFF Format**: https://citation-file-format.github.io/

---

**Document Version**: 1.0
**Last Updated**: 2026-03-26
**Maintainer**: Dmitrii Vasilev
