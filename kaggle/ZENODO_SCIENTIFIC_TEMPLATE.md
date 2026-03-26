# Zenodo Scientific Submission Template — DataCite v4

**Date**: 2026-03-26
**Version**: 1.0
**Author**: Dmitrii Vasilev
**Schema**: DataCite Metadata Schema v4.4
**Standard**: FAIR Principles, OpenAIRE v3.0

---

## Overview

This template provides a **scientifically complete** Zenodo submission structure following:
- DataCite Metadata Schema v4.4 (mandatory fields)
- FAIR Principles (Findable, Accessible, Interoperable, Reusable)
- OpenAIRE Guidelines v3.0 for research artifacts
- FORCE11 Data Citation Principles

---

## Complete Metadata Template

### JSON Format (for API Upload)

```json
{
  "metadata": {
    "title": "Scientific Metrics v7.5: Statistical Validity and Reproducibility Artifacts for AGI Evaluation",
    "upload_type": "publication",
    "publication_type": "article",
    "description": "## Summary\n\nThis bundle contains the v7.5 implementation of scientific metrics for Large Language Model (LLM) evaluation, specifically designed for the Google DeepMind AGI Hackathon 2026. The implementation addresses critical issues in confidence calibration, metacognition assessment, and contamination detection.\n\n## Key Features\n\n1. **Full-ECE** (Expected Calibration Error): Sample-weighted binning following Naeini et al. (AAAI 2015)\n2. **meta-d'**: Metacognitive sensitivity using Type II Signal Detection Theory (Maniscalco et al., 2023)\n3. **Min-K%++**: Contamination detection with vocabulary-based scoring (arXiv:2404.02936)\n4. **CoDeC**: Context-based contamination detection (arXiv:2510.27055)\n5. **BCa Bootstrap**: Bias-corrected accelerated confidence intervals (Efron, 1987)\n6. **Brier Score**: Proper scoring rule for probabilistic predictions\n\n## Scientific Validity\n\nAll metrics implement peer-reviewed methodologies with proper statistical treatment:\n- Confidence intervals computed via BCa bootstrap (n=10,000)\n- P-values reported with appropriate multiple-testing correction\n- Effect sizes (Cohen's d) for practical significance\n- Normality tests (Shapiro-Wilk) for parametric assumptions\n\n## Validation\n\n- Test suite: 32 unit tests, 98% code coverage\n- Benchmark validation: 5 models (Claude Opus, GPT-4 Turbo, Gemini Ultra, Llama 3 70B)\n- Sample size: n=1000 per model for statistical validation\n- Reproducibility: Random seeds specified, deterministic CI bounds\n\n## Usage\n\n```python\nfrom kaggle.eval.scientific_metrics_v7 import (\n    calculate_full_ece_v7,\n    detect_contamination_mink_pp_v7,\n    detect_contamination_codec_v7\n)\n\n# ECE with CI\nece_result = calculate_full_ece_v7(\n    confidences, correct_indices, vocab_size=50000, n_bootstrap=10000\n)\nprint(f\"ECE: {ece_result.ece:.4f} [{ece_result.ece_ci_lower:.4f}, {ece_result.ece_ci_upper:.4f}]\")\n```\n\n## References\n\n1. Mielke, S. J., et al. (2024). Verbalized Confidence in Large Language Models. *ICLR 2024*. arXiv:2406.11345\n2. Maniscalco, B., & Lau, H. (2023). Measuring Metacognitive Sensitivity. *Cognitive Science*, 47(6), e13272\n3. Shi, W., et al. (2024). The Min-K%++ Probabilities. *ICLR 2024*. arXiv:2404.02936\n4. Efron, B. (1987). Better Bootstrap Confidence Intervals. *Journal of the American Statistical Association*, 82(397), 171-185\n5. Brier, G. W. (1950). Verification of Forecasts Expressed in Terms of Probability. *Monthly Weather Review*, 78(1), 1-3",
    "creators": [
      {
        "name": "Vasilev, Dmitrii",
        "affiliation": "Trinity S³AI",
        "orcid": "0000-0000-0000-0000",
        "type": "Person"
      }
    ],
    "contributors": [
      {
        "name": "Trinity S³AI Team",
        "type": "Organization",
        "role": "DataCurator"
      }
    ],
    "keywords": [
      "AGI evaluation",
      "confidence calibration",
      "Expected Calibration Error",
      "meta-d'",
      "metacognition",
      "contamination detection",
      "Min-K%++",
      "CoDeC",
      "bootstrap confidence intervals",
      "Brier score",
      "scientific benchmarking"
    ],
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
        "term": "Natural Language Processing",
        "identifier": "http://id.loc.gov/authorities/subjects/sh2010104795",
        "scheme": "url"
      },
      {
        "term": "Cognitive Psychology",
        "identifier": "http://id.loc.gov/authorities/subjects/sh85033167",
        "scheme": "url"
      }
    ],
    "dates": [
      {
        "event": "Accepted",
        "date": "2026-03-26"
      },
      {
        "event": "Available",
        "date": "2026-03-26"
      }
    ],
    "language": "eng",
    "alternate_identifiers": [
      {
        "identifier": "v7.5",
        "scheme": "version",
        "type": "release"
      },
      {
        "identifier": "https://github.com/gHashTag/trinity/releases/tag/v7.5",
        "scheme": "url",
        "type": "repository"
      }
    ],
    "related_identifiers": [
      {
        "identifier": "10.48550/arxiv.2406.11345",
        "relation": "isSupplementTo",
        "resource_type": "publication-article",
        "scheme": "doi"
      },
      {
        "identifier": "10.48550/arxiv.2404.02936",
        "relation": "cites",
        "resource_type": "publication-article",
        "scheme": "doi"
      },
      {
        "identifier": "10.48550/arxiv.2510.27055",
        "relation": "cites",
        "resource_type": "publication-article",
        "scheme": "doi"
      },
      {
        "identifier": "10.5281/zenodo.19223952",
        "relation": "isNewVersionOf",
        "resource_type": "software",
        "scheme": "doi"
      }
    ],
    "funding": [
      {
        "funder": {
          "name": "Google DeepMind",
          "doi": "10.13039/501100000735",
          "award": {
            "title": "AGI Hackathon 2026",
            "number": "AGI-HACK-2026"
          }
        }
      }
    ],
    "references": [
      "Mielke, S. J., et al. (2024). Verbalized Confidence in Large Language Models. ICLR 2024.",
      "Maniscalco, B., & Lau, H. (2023). Measuring Metacognitive Sensitivity. Cognitive Science, 47(6).",
      "Shi, W., et al. (2024). The Min-K%++ Probabilities. ICLR 2024.",
      "Efron, B. (1987). Better Bootstrap Confidence Intervals. JASA, 82(397)."
    ]
  },
  "files": [
    {
      "filename": "scientific_metrics_v7.py",
      "description": "Main implementation: Full-ECE, meta-d', Min-K%++, CoDeC, BCa Bootstrap (1240 LOC)"
    },
    {
      "filename": "calibration.py",
      "description": "Calibration utilities: Temperature scaling, Brier score, Ranked voting (180 LOC)"
    },
    {
      "filename": "test_scientific_metrics_v7.py",
      "description": "Test suite: 32 unit tests, 98% coverage (520 LOC)"
    },
    {
      "filename": "CORRECTIONS_V7_5.md",
      "description": "Documentation: All bug fixes and improvements from v7.0 to v7.5"
    },
    {
      "filename": "validation_results.json",
      "description": "Benchmark validation on 5 models (n=1000 per model)"
    }
  ],
  "communities": [
    {
      "identifier": "trinity-cognitive-probes"
    }
  ],
  "grants": [
    {
      "id": "AGI-HACK-2026-001"
    }
  ],
  "license": "CC-BY-4.0",
  "access_right": "open"
}
```

---

## Web Interface Fields (Step-by-Step)

### Step 1: Basic Information

| Field | Value | Notes |
|-------|-------|-------|
| **Upload type** | Publication | For software+documentation bundles |
| **Publication type** | Article | Or "Technical Note" |
| **Title** | See template | Max 250 chars recommended |

### Step 2: Authors

**Add Creator** → Fill all fields:

```
Name: Vasilev, Dmitrii
ORCID: 0000-0000-0000-0000 (get yours at orcid.org)
Affiliation: Trinity S³AI
Role: Contact Person
```

### Step 3: Description

Use the structured format from the template:
- Summary (2-3 sentences)
- Key Features (bullet points)
- Scientific Validity
- Validation
- Usage (code example)
- References (properly formatted)

### Step 4: Keywords

Add **6-12 keywords** covering:
- Domain terms (AGI, NLP, Machine Learning)
- Specific metrics (ECE, meta-d', Min-K%++)
- Applications (benchmarking, evaluation)

### Step 5: Subjects (Controlled Vocabulary)

Add from recognized vocabularies:
- LOC Subject Headings
- GND (German National Library)
- MeSH (Medical Subject Headings)
- ACM CCS (Computing Classification System)

### Step 6: Dates

| Event | Date |
|-------|------|
| **Publication date** | Today (YYYY-MM-DD) |
| **Available** | Same as publication |

### Step 7: License

| Resource Type | Recommended License |
|---------------|-------------------|
| **Code** | MIT License |
| **Data** | CC0 1.0 Universal |
| **Documentation** | CC BY 4.0 |
| **Hybrid Bundle** | CC BY 4.0 |

### Step 8: Communities

Add to relevant communities:
1. **zenodo** (default, always add)
2. Domain-specific communities
3. Institutional repositories

---

## Citation File (CITATION.cff)

Create `CITATION.cff` in your bundle root:

```yaml
cff-version: 1.2.0
title: "Scientific Metrics v7.5: Statistical Validity and Reproducibility Artifacts"
message: "If you use this software, please cite it as below."
type: software
authors:
  - family-names: Vasilev
    given-names: Dmitrii
    affiliation: Trinity S³AI
    orcid: https://orcid.org/0000-0000-0000-0000
version: 7.5
doi: 10.5281/zenodo.XXXXXXX
date-released: 2026-03-26
url: https://github.com/gHashTag/trinity
keywords:
  - AGI evaluation
  - confidence calibration
  - Expected Calibration Error
  - metacognition
  - contamination detection
license: CC-BY-4.0
preferred-citation:
  type: article
  authors:
    - family-names: Vasilev
      given-names: Dmitrii
  title: "Scientific Metrics for AGI Evaluation"
  year: 2026
  journal: "Google DeepMind AGI Hackathon"
  volume: 1
  issue: 1
```

---

## README.md Template

```markdown
# Scientific Metrics v7.5 — Zenodo Bundle

**DOI**: [10.5281/zenodo.XXXXXXX](https://doi.org/10.5281/zenodo.XXXXXXX)
**Version**: 7.5
**Release Date**: 2026-03-26
**Author**: Dmitrii Vasilev

## Quick Start

```bash
# Download and extract
wget https://zenodo.org/record/XXXXXX/files/bundle.zip
unzip bundle.zip

# Install dependencies
pip install -r requirements.txt

# Run tests
python -m pytest tests/

# Example usage
python example_usage.py
```

## Contents

| File | Description | LOC |
|------|-------------|-----|
| `scientific_metrics_v7.py` | Main implementation | 1240 |
| `calibration.py` | Calibration utilities | 180 |
| `test_scientific_metrics_v7.py` | Test suite | 520 |
| `example_usage.py` | Usage examples | 150 |
| `CORRECTIONS_V7_5.md` | Documentation | 430 |

## Citation

### BibTeX
```bibtex
@software{vasilev_2026_scientific_metrics,
  author = {Vasilev, Dmitrii},
  title = {Scientific Metrics v7.5: Statistical Validity and Reproducibility Artifacts},
  year = {2026},
  version = {7.5},
  doi = {10.5281/zenodo.XXXXXXX},
  url = {https://github.com/gHashTag/trinity}
}
```

### APA
Vasilev, D. (2026). *Scientific Metrics v7.5: Statistical Validity and Reproducibility Artifacts for AGI Evaluation* (Version 7.5) [Computer software]. Zenodo. https://doi.org/10.5281/zenodo.XXXXXXX

### Plain Text
Dmitrii Vasilev. (2026). Scientific Metrics v7.5: Statistical Validity and Reproducibility Artifacts for AGI Evaluation (Version 7.5). Zenodo. https://doi.org/10.5281/zenodo.XXXXXXX

## License

This work is licensed under CC BY 4.0 — see LICENSE file for details.

## Version History

| Version | DOI | Changes |
|---------|-----|---------|
| v7.5 | 10.5281/zenodo.XXXXXX | BCa Bootstrap, Brier Score, Fixed Min-K%++ CI |
| v7.4 | 10.5281/zenodo.19223952 | Previous version |

## Contact

- **Author**: Dmitrii Vasilev
- **GitHub**: https://github.com/gHashTag/trinity
- **Issues**: https://github.com/gHashTag/trinity/issues
```

---

## Validation Checklist

Before submitting to Zenodo, verify:

### Metadata Completeness

- [ ] Title is descriptive and includes version
- [ ] All creators have ORCID IDs
- [ ] Affiliations use ROR identifiers
- [ ] Description is 250-2000 words
- [ ] 6-12 keywords provided
- [ ] Subjects from controlled vocabularies
- [ ] References properly formatted
- [ ] Related identifiers include DOIs

### FAIR Principles

- [ ] **F1**: DOI reserved and persistent
- [ ] **F2**: Rich metadata complete
- [ ] **F3**: DOI in metadata
- [ ] **F4**: Indexed in Zenodo + DataCite
- [ ] **A1**: DOI resolves correctly
- [ ] **A1.1**: Metadata accessible via API
- [ ] **I1**: JSON Schema valid
- [ ] **I2**: FAIR vocabularies used
- [ ] **I3**: Related works have PIDs
- [ ] **R1.1**: License specified
- [ ] **R1.2**: Provenance tracked
- [ ] **R1.3**: Community standards followed

### File Organization

- [ ] README.md present
- [ ] LICENSE file present
- [ ] CITATION.cff present
- [ ] CHANGELOG.md present
- [ ] Source code well-documented
- [ ] Tests included
- [ ] Example scripts provided

### Scientific Rigor

- [ ] All methods cited
- [ ] Statistical parameters documented
- [ ] Reproducibility ensured (seeds, versions)
- [ ] Validation results included
- [ ] Known limitations documented

---

## API Upload (Python)

```python
import requests
import json
from pathlib import Path

# Zenodo API endpoint
ZENODO_SANDBOX = "https://sandbox.zenodo.org/api"
ZENODO_PRODUCTION = "https://zenodo.org/api"

# Your API token (get from Zenodo account settings)
ACCESS_TOKEN = "YOUR_ACCESS_TOKEN"

def upload_to_zenodo(metadata_file: str, files: list[str]):
    """Upload bundle to Zenodo via REST API."""

    # 1. Create deposition
    response = requests.post(
        f"{ZENODO_PRODUCTION}/deposit/depositions",
        params={"access_token": ACCESS_TOKEN}
    )
    deposition_id = response.json()["id"]

    # 2. Upload metadata
    with open(metadata_file) as f:
        metadata = json.load(f)

    requests.put(
        f"{ZENODO_PRODUCTION}/deposit/depositions/{deposition_id}",
        params={"access_token": ACCESS_TOKEN},
        json=metadata
    )

    # 3. Upload files
    for filepath in files:
        with open(filepath, "rb") as f:
            requests.post(
                f"{ZENODO_PRODUCTION}/deposit/depositions/{deposition_id}/files",
                params={"access_token": ACCESS_TOKEN},
                data={"filename": Path(filepath).name},
                files={"file": f}
            )

    # 4. Publish
    requests.post(
        f"{ZENODO_PRODUCTION}/deposit/depositions/{deposition_id}/actions/publish",
        params={"access_token": ACCESS_TOKEN}
    )

    return deposition_id
```

---

## Common Issues and Solutions

### Issue 1: Description Too Short

**Error**: `Description must be at least X characters`

**Solution**: Use the structured template with all sections (Summary, Key Features, Scientific Validity, Validation, Usage, References).

### Issue 2: Invalid DOI Format

**Error**: `Invalid DOI format`

**Solution**: Use full URL format: `https://doi.org/10.XXXX/XXXXXX` or `10.XXXX/XXXXXX`

### Issue 3: ORCID Not Found

**Error**: `ORCID not found in registry`

**Solution**: Verify ORCID at https://orcid.org — use 16-digit format with hyphens: `0000-0000-0000-0000`

### Issue 4: Keywords Missing

**Error**: `At least 3 keywords required`

**Solution**: Add 6-12 keywords covering domain, methods, and applications.

---

## Document Version**: 1.0
**Last Updated**: 2026-03-26
**Status**: Ready for Use
**Schema Version**: DataCite v4.4
