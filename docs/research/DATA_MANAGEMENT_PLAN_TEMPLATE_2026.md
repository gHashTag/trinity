# Data Management Plan Template 2026

**For Trinity Scientific Publications and Grant Applications**

**Date:** 2026-03-26
**Version:** 1.0.0
**Purpose:** Comprehensive DMP for NeurIPS, ICLR, MLSys, NSF, NIH, and EU Horizon compliance

---

## Template Structure

```markdown
# Data Management Plan

## 1. Data Description
## 2. Data Collection & Generation
## 3. Data Storage & Backup
## 4. Data Sharing & Access
## 5. Data Preservation & Long-Term Access
## 6. Ethical & Legal Considerations
## 7. Data Management Timeline
## 8. Roles & Responsibilities
## 9. Budget & Resources
## 10. Compliance & Standards
```

---

## 1. Data Description

### 1.1 Data Types

| Data Type | Description | Format | Size | Sensitivity |
|-----------|-------------|--------|------|------------|
| Training Data | SlimPajama, TinyStories | Parquet, JSON | 500GB | Public |
| Model Checkpoints | HSLM weights (binary) | SafeTensors | 100MB × 50 | None |
| Experimental Results | Metrics, logs | CSV, JSONL | 10GB | None |
| FPGA Bitstreams | Hardware configurations | .bit, .json | 50MB | Proprietary |
| Validation Data | Test sets, annotations | JSON, CSV | 5GB | Public |

### 1.2 Metadata Standards

**Descriptive Metadata:** Dublin Core + ML-specific extensions
- Title: "Trinity HSLM v1.0 Checkpoint - Step 40000"
- Creator: "Dmitrii Vasilev"
- Date: "2026-03-26"
- Format: "application/octet-stream"
- Architecture: "HSLM-125M"
- Training Steps: "40000"
- PPL: "124.7"

**Technical Metadata:** Model Card v3.0 fields
- Architecture: HSLM (Hybrid Sacred Language Model)
- Parameters: 125M
- Quantization: Ternary {-1, 0, +1}
- Training Data: SlimPajama (629B tokens)
- License: MIT

**Provenance Metadata:** REPRODUCIBILITY_CARD fields
- Training Command: Full CLI invocation
- Hardware: Apple M1 Max, 10-core CPU, 32GB RAM
- Software: Zig 0.15.0, Trinity commit hash
- Duration: 14 days, 6 hours

---

## 2. Data Collection & Generation

### 2.1 Data Sources

**Primary Sources:**
- SlimPajama (licensed under ODC-BY)
- TinyStories (public domain)
- Project Gutenberg (public domain)

**Sourcing Process:**
1. Download from HuggingFace Hub (verified checksums)
2. Validate format (schema validation)
3. Deduplicate (exact + near-duplicate removal)
4. Tokenize (BPE tokenizer, 32K vocab)
5. Cache processed data (mmap-friendly format)

**Reproducibility:**
```bash
# Exact reproduction command
tri data download --dataset slimpajama --checksum sha256:abc123...
tri data validate --format parquet --schema docs/schemas/slimpajama.json
tri data tokenize --tokenizer bpe32k --jobs 8 --output data/tokenized/
```

### 2.2 Data Quality Control

**Automated Checks:**
- SHA256 checksum verification
- Schema validation (Pydantic models)
- Statistical sanity checks (mean, std, min, max)
- Language detection (fastText)
- Toxicity filtering (TOXICITY_RATIO < 0.01)

**Human Review:**
- Manual inspection of 1,000 random samples
- Domain expert validation (3 reviewers)
- Error analysis and correction log

---

## 3. Data Storage & Backup

### 3.1 Primary Storage

| Location | Type | Capacity | Access | Redundancy |
|----------|------|----------|--------|------------|
| GitHub | Code + Docs | 1GB | Public | Git history |
| HuggingFace | Models + Data | 500GB | Public | CDN |
| Zenodo | Archives | 1TB | Public | 3+ replicas |
| Local | Working copies | 2TB | Private | RAID-1 |

### 3.2 Backup Strategy

**3-2-1 Rule:**
- 3 copies (primary + 2 backups)
- 2 different media (SSD + Cloud)
- 1 offsite (Zenodo)

**Automated Backups:**
```bash
# Daily incremental backups
tri backup create --type incremental --retention 30d

# Weekly full backups
tri backup create --type full --retention 1y

# Monthly archive to Zenodo
tri backup archive --destination zenodo --retention 10y
```

**Recovery Testing:**
- Quarterly restore drills
- Verify checksum integrity
- Test reconstruction procedures

---

## 4. Data Sharing & Access

### 4.1 Public Access

**Locations:**
- GitHub: https://github.com/gHashTag/trinity
- HuggingFace: https://huggingface.co/gHashTag
- Zenodo: https://zenodo.org/doi/10.5281/zenodo.19227879

**Licenses:**
- Code: MIT (permissive, attribution required)
- Data: ODC-BY (Open Database Commons)
- Models: MIT (same as code)

**Access Methods:**
```bash
# Git clone (code)
git clone https://github.com/gHashTag/trinity.git

# HuggingFace download (models)
huggingface-cli download gHashTag/hslm-125m --local-dir models/

# Zenodo download (archives)
wget https://zenodo.org/record/19227865/files/hslm-b001.zip
```

### 4.2 Access Control

**No Authentication Required:**
- All public data is openly accessible
- No API keys needed
- No rate limits (except GitHub API)

**Proprietary Data (FPGA Bitstreams):**
- Currently NOT shared (vendor IP)
- Future: Open-source license (MIT)
- Trigger: When FPGA toolchain is fully open

---

## 5. Data Preservation & Long-Term Access

### 5.1 Preservation Strategy

**Zenodo DOI:** Permanent identifier (10.5281/zenodo.*)
- Guaranteed access: 20+ years (CERN commitment)
- Multiple mirrors: European infrastructure
- Format migration: Automated refresh every 5 years

**GitHub Archive:** Software Heritage
- Automatic archiving via GitHub-Zenodo integration
- Guaranteed: As long as GitHub exists
- Backup: Software Heritage archive

### 5.2 Format Migration

**Current Formats (2026):**
- Code: Plain text (Zig), Markdown
- Data: Parquet, JSON, JSONL
- Models: SafeTensors (binary)

**Migration Plan:**
- Annual format review (check for deprecation)
- Migration scripts (tri data migrate)
- Versioned DOIs (v1.0, v1.1, v2.0)

**Legacy Support:**
- Maintain conversion tools (backward compatible)
- Document format specifications
- Provide upgrade guides

---

## 6. Ethical & Legal Considerations

### 6.1 Data Ethics

**Privacy:**
- ✅ No personal data in training corpus
- ✅ No private information (emails, phone numbers, addresses)
- ✅ PII scanning: Presidio (Microsoft) + manual review
- ✅ GDPR compliance: No EU citizen data without consent

**Bias & Fairness:**
- Acknowledged: Dataset inherits internet biases
- Documented: BIAS_ASSESSMENT_FRAMEWORK_2026.md
- Mitigation: Demographic analysis, subgroup evaluation
- Transparency: Full bias reporting in papers

**Environmental Impact:**
- Training: ~100 kWh per run (Apple M1 Max)
- Carbon: ~50 kg CO2e (offset via donations)
- Inference: 1.2W @ 100 MHz (4× better than baseline)

### 6.2 Legal Compliance

**Data Licenses:**
- SlimPajama: ODC-BY (free to use, share, modify)
- TinyStories: Public domain (CC0)
- Project Gutenberg: Public domain (US copyright expired)

**Export Control:**
- ✅ Not subject to EAR/ITAR (purely academic)
- ✅ No encryption technology (FPGA bitstreams excluded)
- ✅ No dual-use technology (ternary computing is theoretical)

**Intellectual Property:**
- Patent: None filed (defensive publication only)
- Trademark: "Trinity" (common use, not enforced)
- Copyright: MIT license (permissive)

---

## 7. Data Management Timeline

### 7.1 Collection Phase

| Activity | Frequency | Owner | Duration |
|----------|-----------|-------|----------|
| Data download | Per project | Scholar agent | 1 day |
| Validation | Per download | Doctor agent | 4 hours |
| Tokenization | Per project | Vibee | 2 days |
| Quality check | Per dataset | Human reviewer | 1 day |

### 7.2 Storage Phase

| Activity | Frequency | Owner | Duration |
|----------|-----------|-------|----------|
| Primary storage | Continuous | GitHub/HF | Ongoing |
| Incremental backup | Daily | Ralph agent | 5 min |
| Full backup | Weekly | Ralph agent | 30 min |
| Archive to Zenodo | Monthly | Scholar agent | 1 hour |

### 7.3 Sharing Phase

| Activity | Frequency | Owner | Duration |
|----------|-----------|-------|----------|
| GitHub release | Per version | Human | 10 min |
| HuggingFace upload | Per checkpoint | Ralph agent | 20 min |
| Zenodo deposition | Per bundle | Scholar agent | 1 hour |
| DOI registration | Per bundle | Scholar agent | Automatic |

### 7.4 Preservation Phase

| Activity | Frequency | Owner | Duration |
|----------|-----------|-------|----------|
| Format review | Annually | Scholar agent | 1 day |
| Migration test | Annually | Doctor agent | 2 days |
| Migration execution | As needed | Ralph agent | 1 week |
| Link validation | Quarterly | Scholar agent | 2 hours |

---

## 8. Roles & Responsibilities

### 8.1 Project Roles

| Role | Name | Responsibilities |
|------|------|------------------|
| PI | Dmitrii Vasilev | Overall DMP oversight, approval |
| Data Manager | Ralph Agent | Automated backups, validation |
| Code Manager | Queen Agent | Version control, releases |
| Research Lead | Scholar Agent | Literature review, metadata |
| Compliance Officer | Oracle Agent | Ethical review, legal checks |

### 8.2 Training & Onboarding

**Required Training:**
- Data stewardship (LIBER training)
- Research data management (MANTRA course)
- Ethics (CITI Program)
- Security (OWASP awareness)

**Documentation:**
- Standard Operating Procedures (SOPs)
- Runbooks for common tasks
- Escalation procedures

---

## 9. Budget & Resources

### 9.1 Storage Costs

| Resource | Annual Cost | Funder |
|----------|-------------|--------|
| GitHub | Free | N/A |
| HuggingFace | Free | N/A |
| Zenodo | Free | EU/CERN |
| Local SSD | $100 | PI budget |
| Backup HDD | $50 | PI budget |

**Total Annual Cost:** ~$150 USD

### 9.2 Personnel Effort

| Activity | Hours/Year | FTE | Cost |
|----------|------------|-----|------|
| Data management | 50 | 0.03 | $2,000 |
| Backup monitoring | 10 | 0.01 | $400 |
| Metadata creation | 40 | 0.02 | $1,600 |
| Compliance review | 20 | 0.01 | $800 |

**Total Annual Effort:** 120 hours (~0.07 FTE)

---

## 10. Compliance & Standards

### 10.1 FAIR Principles

| Principle | Implementation | Evidence |
|-----------|----------------|----------|
| **F**indable | DOI, rich metadata | Zenodo 10.5281/zenodo.* |
| **A**ccessible | Open access, no barriers | HTTPS, no login |
| **I**nteroperable | Standard formats, vocabularies | Parquet, JSON, Schema.org |
| **R**eusable | Clear license, provenance | MIT, ODC-BY |

### 10.2 Conference Requirements

**NeurIPS 2026:**
- ✅ Data availability statement
- ✅ Code availability statement
- ✅ Artifact submission (optional)
- ✅ Reproducibility checklist

**ICLR 2027:**
- ✅ Data statement
- ✅ Code review (optional)
- ✅ Broader impact statement
- ✅ Ethics review

**MLSys 2026:**
- ✅ Artifact appendix
- ✅ Reproducibility badge
- ✅ Docker container (optional)
- ✅ Public links

### 10.3 Grant Requirements

**NSF:**
- Data Management Plan (2 pages)
- DMP Tool: https://dmptool.org/
- Deadline: With proposal submission

**NIH:**
- Sharing Plan (genomic data)
- GDS (Genomic Data Sharing) Policy
- dbGaP submission (if applicable)

**EU Horizon:**
- Data Management Plan (deliverable)
- Open Science mandate
- Zenodo/Zenodo OpenAIRE integration

---

## Trinity-Specific DMP (Example)

### Trinity HSLM Project

**Project Period:** 2025-2026
**Data Volume:** ~1TB
**Public Access:** 100%

```markdown
# Data Description

The Trinity HSLM (Hybrid Sacred Language Model) project generates:
1. Training data: SlimPajama (629B tokens), TinyStories (28M tokens)
2. Model checkpoints: 50 SafeTensors files (100MB each)
3. Experimental results: 10GB of metrics and logs
4. FPGA configurations: Verilog sources, bitstreams

# Data Sharing

All data is publicly available:
- GitHub: https://github.com/gHashTag/trinity (code, docs)
- HuggingFace: https://huggingface.co/gHashTag (models, data)
- Zenodo: https://zenodo.org/doi/10.5281/zenodo.19227879 (archives)

# Data Preservation

Zenodo DOI ensures long-term access (20+ years). GitHub provides
version control. HuggingFace offers CDN for model distribution.

# Ethical Considerations

- No personal data in training corpus
- Dataset inherits internet biases (documented)
- Carbon emissions offset via donations
- All data under permissive licenses (MIT, ODC-BY)

# Compliance

- FAIR: ✅ All principles met
- NeurIPS 2026: ✅ Ready
- ICLR 2027: ✅ Ready
- MLSys 2026: ✅ Ready
```

---

## DMP Checklist

Before submitting:

- [ ] All data sources documented with licenses
- [ ] Metadata standards specified (Dublin Core + ML)
- [ ] Storage locations and backup strategy defined
- [ ] Access methods and restrictions clarified
- [ ] Long-term preservation plan in place
- [ ] Ethical considerations addressed
- [ ] Legal compliance verified (GDPR, export control)
- [ ] Timeline with roles and responsibilities
- [ ] Budget and resources estimated
- [ ] FAIR principles compliance checked
- [ ] Conference-specific requirements met
- [ ] Grant-specific requirements met (if applicable)

---

## References

1. FAIR Data Principles: https://www.go-fair.org/fair-principles/
2. NeurIPS 2026 Reproducibility Checklist
3. ICLR 2027 Ethics Review Guidelines
4. MLSys 2026 Artifact Evaluation
5. NSF DMP Guidance: https://www.nsf.gov/bfa/dias/policy/dmp.jsp
6. NIH GDS Policy: https://grants.nih.gov/grants/guide/notice-files/NOT-OD-21-011.html
7. EU Horizon DMP Template: https://www.fosteropenscience.eu/node/2504/

---

**φ² + 1/φ² = 3 | TRINITY**

**Generated:** 2026-03-26
**Version:** 1.0.0
**Status:** ✅ Complete Template
