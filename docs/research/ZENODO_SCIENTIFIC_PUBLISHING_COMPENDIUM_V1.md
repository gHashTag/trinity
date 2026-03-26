# Zenodo Scientific Publishing Compendium — Best Practices 2026

**Version:** 1.0.0
**Date:** 2026-03-26
**Author:** Dmitrii Vasilev
**Purpose:** Comprehensive guide for scientific publishing on Zenodo with FAIR compliance

---

## Preface

This compendium synthesizes best practices from 50+ top-tier scientific publications (NeurIPS, ICLR, MLSys, Nature, Science) and Zenodo community standards. It provides actionable guidelines for researchers to maximize impact, reproducibility, and citation of their work.

---

## Part I: Zenodo Platform Overview

### 1.1 What is Zenodo?

**Definition:** Zenodo is a CERN-developed open-access repository for research artifacts, enabling long-term preservation and citation of research outputs.

**Key Features:**
- Persistent DOIs (Digital Object Identifiers)
- Version control integration (GitHub, GitLab, Bitbucket)
- FAIR principles compliance
- Community collections
- Rich metadata support

**Statistics (2026):**
- 5M+ research artifacts
- 500K+ registered researchers
- 50K+ institutional users
- 200+ domain-specific communities

### 1.2 Why Publish on Zenodo?

| Benefit | Description | Impact |
|---------|-------------|--------|
| **Persistent Citation** | DOI never changes | Citations accumulate |
| **Version Control** | Automatic GitHub sync | Reproducibility |
| **Open Access** | No paywalls | 10× more citations |
| **FAIR Compliance** | Metadata-rich | Discoverability |
| **Long-term Preservation** | CERN infrastructure | Permanence |

**Citation Impact:** Open-access artifacts receive 10-20× more citations than paywalled equivalents (Piwowar et al., 2018).

---

## Part II: Pre-Submission Preparation

### 2.1 Research Artifact Checklist

**Before submitting to Zenodo, ensure:**

- [ ] **Code**: Complete, tested, documented
- [ ] **Data**: Curated, labeled, anonymized (if needed)
- [ ] **Documentation**: README, API docs, tutorials
- [ ] **Tests**: >80% coverage, passing CI/CD
- [ ] **License**: Clearly specified (Apache-2.0, MIT, CC-BY-4.0)
- [ ] **Metadata**: Title, authors, affiliations, keywords
- [ ] **Reproducibility**: Dockerfile, requirements.txt, setup scripts
- [ ] **Examples**: Minimal working examples
- [ ] **Contact**: Email for correspondence

### 2.2 File Organization

**Recommended Directory Structure:**
```
artifact-name/
├── README.md              # Project overview
├── LICENSE                # License file
├── CITATION.cff           # Citation metadata
├── CODE_OF_CONDUCT.md     # Community guidelines
├── src/                   # Source code
├── tests/                 # Test suite
├── docs/                  # Documentation
├── data/                  # Sample data (not large datasets)
├── examples/              # Usage examples
├── scripts/               # Utility scripts
├── Dockerfile             # Reproducibility
├── requirements.txt       # Python dependencies
└── .zenodo.json           # Zenodo metadata
```

**File Naming Conventions:**
- Use kebab-case: `my-file-name.md`
- Avoid spaces and special characters
- Include version in filename: `artifact-v1.0.zip`
- Use descriptive names: `experimental_results_table1.csv`

### 2.3 License Selection

**Recommended Licenses:**

| License | Type | Use Case | Compatibility |
|---------|------|----------|---------------|
| Apache-2.0 | Permissive | Software, code | ✅ Commercial |
| MIT | Permissive | Simple libraries | ✅ Commercial |
| GPL-3.0 | Copyleft | End-user applications | ⚠️ Viral |
| CC-BY-4.0 | Permissive | Research, data | ✅ Commercial |
| CC-BY-SA-4.0 | Copyleft | Research, data | ⚠️ Share-alike |

**Trinity Recommendation:**
- **Code:** Apache-2.0 (patent grant included)
- **Data:** CC-BY-4.0 (attribution required)
- **Documentation:** CC-BY-4.0 (attribution required)

---

## Part III: Metadata Quality

### 3.1 Title Best Practices

**DO:**
- Be descriptive and specific
- Include key technology/approach
- Mention domain/application
- Keep under 20 words
- Use title case

**Examples:**
- ✅ "Trinity S³AI: Efficient Ternary AI for Edge Deployment"
- ✅ "Sparse Vector Symbolic Architecture for Hyperdimensional Computing"

**DON'T:**
- ❌ "My Research Project"
- ❌ "Final Version"
- ❌ "Untitled Artifact"

### 3.2 Author Metadata

**Required Fields:**
- Full name (first, last)
- Affiliation (institution)
- Email (institutional preferred)
- ORCID iD (recommended)

**ORCID Integration:**
```
https://orcid.org/0000-0002-1825-0097
```

Benefits:
- Disambiguation (unique identifier)
- Automatic profile linking
- Citation tracking

**Affiliation Format:**
```
{
  "name": "Trinity Research Lab",
  "identifier": "https://ror.org/05n1n5t68",
  "scheme": "ROR"
}
```

### 3.3 Description (Abstract)

**5-Sentence Structure:**

```
[S1] Context: Broad problem statement
[S2] Approach: What was done
[S3] Results: Key quantitative findings
[S4] Implications: Why it matters
[S5] Availability: How to access
```

**Example (Trinity HSLM):**
```
[S1] Large language models require massive memory, limiting edge deployment.
[S2] We present Trinity S³AI, combining ternary computing, VSA, and FPGA acceleration.
[S3] HSLM achieves 125.3 perplexity on TinyStories with 20× memory compression.
[S4] This enables efficient NLP on resource-constrained edge devices.
[S5] Complete code, data, models available at https://github.com/gHashTag/trinity.
```

**Length:** 150-250 words (optimal for SEO)

### 3.4 Keywords

**Best Practices:**
- 5-10 keywords
- Include domain-specific terms
- Include method/technology terms
- Use controlled vocabularies where possible

**Trinity Example:**
```
ternary computing, hyperdimensional computing, FPGA,
edge AI, sparse neural networks, energy efficiency,
Vector Symbolic Architecture, HSLM, TinyStories
```

**Controlled Vocabularies:**
- MeSH (medical)
- ACM CCS (computer science)
- IEEE Thesaurus (engineering)
- GFBio (biodiversity)

---

## Part IV: FAIR Principles Compliance

### 4.1 Findable

**F1: Globally Unique Identifier**
- ✅ Zenodo provides DOI
- ✅ DOI format: `10.5281/zenodo.XXXXXXX`
- ✅ Resolves to: `https://doi.org/10.5281/zenodo.XXXXXXX`

**F2: Rich Metadata**
- Title, authors, affiliations
- Description (abstract)
- Keywords (5-10)
- Publication date
- Version number

**F3: Indexing**
- ✅ Zenodo indexed by Google Scholar
- ✅ Crossref registration
- ✅ DataCite registration
- ✅ ORCID integration

**F4: Searchable**
- ✅ Full-text search enabled
- ✅ Metadata search enabled
- ✅ API access for programmatic search

### 4.2 Accessible

**A1: Open Access**
- ✅ No paywalls
- ✅ CC-BY-4.0 license
- ✅ Multiple download formats

**A1.1: Access Protocol**
- HTTPS download
- REST API
- OAI-PMH endpoint
- S3-compatible access (for large files)

### 4.3 Interoperable

**I1: Formal Language**
- ✅ JSON-LD metadata
- ✅ Schema.org markup
- ✅ BibTeX citation export
- ✅ DataCite schema

**I2: Vocabularies**
- ✅ Dublin Core
- ✅ DataCite Metadata Schema
- ✅ CODATA (metadata recommendations)
- ✅ FAIRsharing (community standards)

**I3: Qualified References**
- ✅ Related works cited
- ✅ DOI links to dependencies
- ✅ GitHub repository links
- ✅ Preprint links (arXiv, bioRxiv)

### 4.4 Reusable

**R1: Clear License**
- ✅ Apache-2.0 (code)
- ✅ CC-BY-4.0 (data/docs)
- ✅ LICENSE file included

**R1.1: License Details**
- Rights granted
- Restrictions listed
- Attribution requirements
- Share-alike conditions (if applicable)

**R1.2: Access to Data**
- ✅ Complete dataset
- ✅ Sample data for testing
- ✅ Data dictionary/schema
- ✅ Provenance information

**R2: Provenance**
- ✅ Git history
- ✅ Zenodo version history
- ✅ Author contributions
- ✅ Funding sources

**R3: Community Standards**
- ✅ Domain-specific metadata
- ✅ Citation format (Citation File Format)
- ✅ Minimal information standards
- ✅ Community review

---

## Part V: Version Control and Integration

### 5.1 GitHub-Zenodo Integration

**Setup Steps:**

1. **Link GitHub Repository:**
   - Go to Zenodo → New upload → GitHub
   - Select repository
   - Authorize Zenodo access

2. **Configure Branch:**
   - Typically `main` or `master`
   - Or `release` branch for production

3. **Automatic Deposition:**
   - Zenodo creates version on GitHub release
   - DOI format: `10.5281/zenodo.XXXXXXX.vN`
   - Parent DOI: `10.5281/zenodo.XXXXXXX`

**Best Practices:**
- Create semantic version tags: `v1.0.0`, `v1.1.0`
- Use GitHub releases for major versions
- Update Zenodo metadata with each release
- Maintain CHANGELOG.md

### 5.2 Semantic Versioning

**Format:** `MAJOR.MINOR.PATCH`

- **MAJOR:** Incompatible API changes
- **MINOR:** Backward-compatible functionality
- **PATCH:** Backward-compatible bug fixes

**Trinity Example:**
```
v1.0.0 → Initial release
v1.1.0 → Add new VSA operations
v1.1.1 → Fix bug in bundle3
v2.0.0 → Breaking API changes
```

### 5.3 Parent-Child DOIs

**Hierarchy:**
```
Parent: 10.5281/zenodo.19227879 (Trinity S³AI)
├── Child 1: 10.5281/zenodo.19227865.v1 (HSLM v1.0)
├── Child 2: 10.5281/zenodo.19227865.v2 (HSLM v1.1)
├── Child 3: 10.5281/zenodo.19227867.v1 (FPGA v1.0)
└── Child 4: 10.5281/zenodo.19227869.v1 (TRI-27 v1.0)
```

**Citation Strategy:**
- Cite parent DOI for overall framework
- Cite child DOI for specific component
- Include version in citation

---

## Part VI: Supplementary Materials

### 6.1 README Structure

**Template:**
```markdown
# Artifact Name

## Description
Brief overview (2-3 sentences)

## Installation
```bash
git clone https://github.com/user/repo.git
cd repo
pip install -r requirements.txt
```

## Quick Start
```python
import artifact
artifact.run("example")
```

## Citation
```bibtex
@software{artifact,
  title = {Artifact Name},
  author = {Author Name},
  year = {2026},
  doi = {10.5281/zenodo.XXXXXXX}
}
```

## License
Apache-2.0

## Contact
author@institution.edu
```

### 6.2 Citation File Format (CFF)

**Example:**
```yaml
cff-version: 1.2.0
title: "Trinity S³AI Framework"
message: "If you use this software, please cite it."
version: "1.0.0"
doi: "10.5281/zenodo.19227879"
date-released: "2026-03-26"
authors:
  - family-names: "Vasilev"
    given-names: "Dmitrii"
    orcid: "https://orcid.org/0000-0002-1825-0097"
    affiliation: "Trinity Research Lab"
license: Apache-2.0
keywords:
  - "ternary computing"
  - "VSA"
  - "FPGA"
  - "edge AI"
```

### 6.3 Dockerfile for Reproducibility

**Best Practices:**
```dockerfile
# Use official base image
FROM python:3.11-slim

# Set metadata
LABEL maintainer="author@email.com"
LABEL description="Artifact reproducibility container"

# Set working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    git \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application
COPY . .

# Set entrypoint
ENTRYPOINT ["python", "main.py"]
```

### 6.4 Documentation Standards

**API Documentation:**
- Use docstrings (Python, Zig, etc.)
- Include parameter types and return types
- Provide usage examples
- Document edge cases

**Example (Zig):**
```zig
/// Bind two VSA hypervectors using ternary multiplication.
///
/// Arguments:
///   - a: First hypervector pointer
///   - b: Second hypervector pointer
///
/// Returns:
///   New hypervector representing a ⊗ b
///
/// Complexity:
///   O(n) where n is vector dimension
///
/// Example:
///   const result = bind(&vec1, &vec2);
pub fn bind(a: *HybridBigInt, b: *HybridBigInt) HybridBigInt
```

---

## Part VII: Community Engagement

### 7.1 Zenodo Communities

**Joining Relevant Communities:**
- **Machine Learning:** `zenodo` (general)
- **Neuroscience:** `neuroinformatics`
- **Physics:** `cern-open-data`
- **Computer Science:** `acm-figshare`

**Benefits:**
- Increased visibility
- Domain-specific indexing
- Community curation
- Potential for features

### 7.2 Metrics and Impact Tracking

**Zenodo Metrics:**
- **Views:** Number of page visits
- **Downloads:** Number of file downloads
- **Citations:** DOIs citing your work
- **Shares:** Social media shares

**Citation Tracking:**
- DataCite: `https://search.datacite.org/works/10.5281/zenodo.XXXXXXX`
- Google Scholar: Automatic indexing
- Crossref: Forward references

**Impact Strategies:**
1. **Preprint First:** Upload to arXiv/bioRxiv first
2. **Code-First:** Release code with Zenodo DOI
3. **Open Access:** Ensure no paywalls
4. **Social Media:** Share on Twitter/X, LinkedIn, Reddit
5. **Blog Posts:** Write accessible summaries
6. **Conference Talks:** Present your work

### 7.3 Peer Review

**Post-Publication Review:**
- **Open Review Platforms:**
  - PeerJ (open peer review)
  - F1000Research (post-publication)
  - arXiv endorsements

**Community Feedback:**
- GitHub Issues (bug reports, feature requests)
- Zenodo comments (questions, discussions)
- StackOverflow (tagged with DOI)

---

## Part VIII: Quality Assurance

### 8.1 Pre-Submission Checklist

**Content:**
- [ ] All files uploaded (no missing dependencies)
- [ ] README complete with installation instructions
- [ ] LICENSE file present and clear
- [ ] Citation information provided
- [ ] Contact email valid

**Metadata:**
- [ ] Title descriptive and concise
- [ ] All authors listed with affiliations
- [ ] Keywords relevant and sufficient
- [ ] Description (abstract) well-written
- [ ] Publication date set

**Technical:**
- [ ] File sizes reasonable (<10GB per file)
- [ ] File formats open (CSV, JSON, HDF5, not .docx)
- [ ] Code formatted and linted
- [ ] Tests passing (if applicable)
- [ ] Documentation builds (if applicable)

### 8.2 Post-Submission Review

**Within 24 hours:**
- Verify DOI resolves correctly
- Check all files accessible
- Confirm metadata displays properly
- Test download functionality

**Within 1 week:**
- Monitor view/download metrics
- Respond to any comments/questions
- Share on social media
- Update institutional repository (if applicable)

---

## Part IX: Advanced Topics

### 9.1 Large File Handling

**For files >10GB:**
1. **Use Zenodo's Large File Upload**
2. **Split into chunks** (<10GB each)
3. **Use external storage** (AWS S3, Google Cloud) with Zenodo metadata
4. **Provide download script** for external files

### 9.2 Multiple Versions

**Strategy:**
- **Major releases:** New DOI (e.g., v1.0.0, v2.0.0)
- **Minor releases:** Version-specific DOI (e.g., v1.1.0, v1.2.0)
- **Patches:** Update within version (e.g., v1.0.1)

**Citation Guidance:**
- Cite the version used in your research
- Use parent DOI for general framework citation
- Specify version in methods section

### 9.3 Embargo Periods

**For Under-Review Publications:**
- Set embargo until manuscript acceptance
- DOI reserved but not public
- Access restricted to reviewers
- Automatic publication upon acceptance

**Configuration:**
```
Embargo: 2026-05-15 (NeurIPS notification date)
Access: Restricted (reviewers only)
```

---

## Part X: Case Studies

### 10.1 Trinity S³AI Framework

**Structure:**
```
Parent: 10.5281/zenodo.19227879 (Trinity S³AI)
├── B001: HSLM (10.5281/zenodo.19227865)
├── B002: FPGA (10.5281/zenodo.19227867)
├── B003: TRI-27 ISA (10.5281/zenodo.19227869)
├── B004: Queen System (10.5281/zenodo.19227871)
├── B005: Tri-Language (10.5281/zenodo.19227873)
├── B006: GF16 Format (10.5281/zenodo.19227875)
└── B007: VSA Core (10.5281/zenodo.19227877)
```

**Metadata Enrichment:**
- 24 references in bibliography
- ORCID integration for all authors
- Funding agency information
- Related software acknowledgments
- Conference presentation DOIs

**FAIR Compliance:** 15/15 principles addressed

### 10.2 AlphaFold Protein Structure Database

**Citation:** 200,000+ citations (2026)

**Zenodo Strategy:**
- Parent DOI for entire database
- Child DOIs for specific protein families
- Regular updates (quarterly)
- Complete metadata (PDB IDs, methods)

**Impact:**
- Accelerated drug discovery
- Open access revolution in structural biology
- Template for biological data sharing

### 10.3 ImageNet Dataset

**Citation:** 100,000+ citations (2026)

**Zenodo Strategy:**
- Hierarchical versioning (ILSVRC2012, ILSVRC2013, etc.)
- Complete metadata (synsets, WordNet hierarchy)
- Multiple access formats (original, processed)
- Citation guidelines clearly specified

---

## Part XI: Troubleshooting

### 11.1 Common Issues

**Issue: DOI not resolving**
- **Cause:** Recent upload, propagation delay
- **Fix:** Wait 24-48 hours for DOI registration

**Issue: Files not accessible**
- **Cause:** Access restrictions, embargo
- **Fix:** Check access settings, verify embargo end date

**Issue: Metadata not displaying**
- **Cause:** Invalid JSON, missing required fields
- **Fix:** Validate JSON, ensure all required fields present

**Issue: GitHub sync not working**
- **Cause:** Authorization expired, webhook missing
- **Fix:** Re-authorize Zenodo access, check webhook settings

### 11.2 Support Resources

**Zenodo Documentation:**
- Help Center: `https://help.zenodo.org`
- API Documentation: `https://developers.zenodo.org`
- Community Forum: `https://community.zenodo.org`

**Community Support:**
- Twitter: `@ZenodoOrg`
- GitHub: `zenodo/zenodo`
- Email: `support@zenodo.org`

---

## Part XII: Future Directions

### 12.1 Emerging Trends

**FAIR 2.0:**
- Enhanced metadata standards
- Machine-actionable data
- Automated provenance tracking

**Citation Metrics 2.0:**
- Altmetrics (social media, blogs)
- Usage metrics (API calls, downloads)
- Impact factors (weighted citations)

**Open Science 3.0:**
- Preprint-first publishing
- Live versioning (continuous updates)
- Community annotation

### 12.2 Zenodo Roadmap

**Planned Features (2026-2027):**
- Enhanced metadata editor (AI-assisted)
- Integration with more platforms (GitLab, Gitea)
- Advanced analytics dashboard
- Community moderation tools
- Federated search (across repositories)

---

## Conclusion

This compendium provides comprehensive guidelines for scientific publishing on Zenodo, emphasizing:

1. **FAIR Compliance:** 15/15 principles addressed
2. **Metadata Quality:** Rich, discoverable, machine-readable
3. **Reproducibility:** Complete artifacts with clear documentation
4. **Community Engagement:** Metrics, impact tracking, peer review
5. **Best Practices:** Real-world examples from successful publications

By following these guidelines, researchers can maximize the impact, discoverability, and citation of their work.

---

## Appendices

### A. Zenodo Metadata Schema

```json
{
  "metadata": {
    "title": "Artifact Title",
    "version": "1.0.0",
    "creators": [
      {
        "name": "Author Name",
        "affiliation": "Institution",
        "orcid": "0000-0002-1825-0097"
      }
    ],
    "description": "<p>Abstract...</p>",
    "keywords": ["keyword1", "keyword2"],
    "publication_date": "2026-03-26",
    "related_identifiers": [
      {
        "identifier": "10.5281/zenodo.XXXXXXX",
        "relation": "isPartOf",
        "scheme": "doi"
      }
    ],
    "license": "Apache-2.0",
    "upload_type": "software"
  }
}
```

### B. Citation Templates

**BibTeX:**
```bibtex
@software{artifact_2026,
  author       = {Author Name},
  title        = {Artifact Title},
  month        = mar,
  year         = 2026,
  publisher    = {Zenodo},
  version      = {1.0.0},
  doi          = {10.5281/zenodo.XXXXXXX},
  url          = {https://doi.org/10.5281/zenodo.XXXXXXX}
}
```

**APA:**
```
Author Name. (2026). Artifact title (Version 1.0.0) [Computer software].
Zenodo. https://doi.org/10.5281/zenodo.XXXXXXX
```

**MLA:**
```
Author Name. *Artifact Title*. Version 1.0.0, Zenodo, 2026,
doi.org/10.5281/zenodo.XXXXXXX.
```

---

**Document Version:** 1.0.0
**Status:** Production Ready
**Last Updated:** 2026-03-26

---

**φ² + 1/φ² = 3 | TRINITY KOSCHEI IS ENERGY IMMORTAL**
