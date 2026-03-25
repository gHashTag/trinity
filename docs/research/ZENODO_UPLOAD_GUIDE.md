# Zenodo Upload Guide — Trinity S³AI Framework v2.4

**Last Updated:** 2026-03-26
**Version:** 2.4
**Total Bundles:** 7 (B001-B007) + 1 Parent Collection

---

## Pre-Upload Checklist

### 1. Account Setup

- [ ] Create Zenodo account at https://zenodo.org
- [ ] Verify email address
- [ ] Enable ORCID integration (optional but recommended)
- [ ] Configure profile affiliation

### 2. File Preparation

Each bundle requires the following files:

#### Required Files (per bundle)
```
zenodo_BXXX_full_description.md  — Main scientific description
CITATION_BXXX.cff                 — Citation metadata
README_BXXX.md                    — Quick summary (optional)
```

#### Parent Collection Files
```
ZENODO_README.md                 — Parent description
ZENODO_MASTER_INDEX.md           — Navigation hub
EXPERIMENTAL_RESULTS.md          — Supporting data
UNIFIED_BIBLIOGRAPHY.md          — All references
MATHEMATICAL_APPENDIX.md         — Formulas and proofs
ZENODO_SCIENTIFIC_GUIDE_V2.md    — Best practices
CITATION.cff                     — Parent citation
```

---

## Upload Procedure

### Step 1: Create Parent Collection (NEW)

1. Go to https://zenodo.org/deposit
2. Click "New upload"
3. Upload these files to parent collection:
   - `ZENODO_README.md`
   - `ZENODO_MASTER_INDEX.md`
   - `EXPERIMENTAL_RESULTS.md`
   - `UNIFIED_BIBLIOGRAPHY.md`
   - `MATHEMATICAL_APPENDIX.md`
   - `ZENODO_SCIENTIFIC_GUIDE_V2.md`
   - `CITATION.cff`

4. Enter metadata:
   - **Title**: "Trinity S³AI Framework — Complete Scientific Collection"
   - **Authors**: Dmitrii Vasilev
   - **Description**: Copy from `ZENODO_README.md`
   - **Keywords**: ternary computing, neural networks, FPGA, VSA, TRI-27, Queen Lotus, Tri Language
   - **License**: CC-BY-4.0
   - **Publication date**: 2026-03-26

5. **DO NOT PUBLISH YET** — Save as draft

### Step 2: Create Bundle B001 (Ternary Neural Networks)

1. Create new upload
2. Upload files:
   - `zenodo_B001_full_description.md`
   - `CITATION_B001.cff`

3. Enter metadata:
   - **Title**: "Trinity B001: Ternary Neural Networks — Complete Scientific Framework"
   - **DOI**: 10.5281/zenodo.19225088 (already reserved)
   - **Description**: Copy from `zenodo_B001_full_description.md` (Abstract section)
   - **Keywords**: HSLM, ternary neural networks, sacred attention, consciousness gate, phi scaling, T-JEPA
   - **Related identifiers**: Link to parent collection (after it's published)

4. Publish → Generates DOI

### Step 3: Create Bundles B002-B007

Repeat Step 2 for each bundle:

| Bundle | Title | DOI |
|--------|-------|-----|
| B002 | Zero-DSP FPGA Architecture | 10.5281/zenodo.19225102 |
| B003 | TRI-27 ISA | 10.5281/zenodo.19225117 |
| B004 | Queen Lotus Cycle | 10.5281/zenodo.19225118 |
| B005 | Tri Language | 10.5281/zenodo.19225121 |
| B006 | Sacred GF16/TF3 | 10.5281/zenodo.19225122 |
| B007 | VSA Operations | 10.5281/zenodo.19225124 |

### Step 4: Link All Bundles to Parent

1. Go to parent collection draft
2. In "Related identifiers", add:
   - Type: "Is part of"
   - Identifier: DOI of each bundle (B001-B007)
   - Relation: "Has part"

3. Publish parent collection

---

## Metadata Template

### Basic Information

```
Title: Trinity B001: Ternary Neural Networks — Complete Scientific Framework
Upload type: Publication
Publication type: Other
Publication month: March
Publication year: 2026
```

### Authors

```
Name: Vasilev, Dmitrii
ORCID: 0000-0000-0000-0000 (if available)
Affiliation: Independent Researcher
```

### Description

Copy the Abstract section from the full description document.

### Keywords

Use comma-separated keywords from the bundle description.

### License

**Recommended**: CC-BY-4.0 (Creative Commons Attribution 4.0 International)

**Alternative options**:
- CC0-1.0 (Public Domain) — maximum reuse
- MIT License — software-friendly

### Communities

Consider submitting to:
- **zenodo** (General community)
- **computer-vision** — for B001, B002
- **machine-learning** — for B001, B004
- **programming-languages** — for B003, B005

---

## Post-Upload Actions

### 1. Verify DOIs

After publishing, verify all DOIs are resolvable:
- https://doi.org/10.5281/zenodo.19225088 (B001)
- https://doi.org/10.5281/zenodo.19225102 (B002)
- https://doi.org/10.5281/zenodo.19225117 (B003)
- https://doi.org/10.5281/zenodo.19225118 (B004)
- https://doi.org/10.5281/zenodo.19225121 (B005)
- https://doi.org/10.5281/zenodo.19225122 (B006)
- https://doi.org/10.5281/zenodo.19225124 (B007)
- https://doi.org/10.5281/zenodo.19225187 (Parent)

### 2. Update Documentation

Update `ZENODO_MASTER_INDEX.md` with any DOI changes:

```markdown
| Bundle | DOI |
|--------|-----|
| B001 | [10.5281/zenodo.XXXXXXXX](https://doi.org/10.5281/zenodo.XXXXXXXX) |
```

### 3. Create GitHub Release

1. Go to GitHub repository releases
2. Create new release: `v2.4-zenodo`
3. Add Zenodo DOI links to release notes
4. Attach `CITATION.cff` files

### 4. Announce

- **Twitter**: Mention @zenodo_org, use #OpenScience hashtag
- **Blog**: Write summary post with all DOIs
- **Email**: Send to relevant mailing lists

---

## Version Control

### Version Numbering

Zenodo uses semantic versioning:

```
v2.4 → Major.Minor
  └─ Patch (reserved for Zenodo)
```

### Update Procedure

When updating an existing upload:

1. Create **New Version** (not new upload)
2. Zenodo preserves DOI and version history
3. Update version number in documentation
4. Add changelog to description

---

## Troubleshooting

### Issue: DOI Already Exists

**Solution**: The DOI is already reserved. Use "New Version" instead of "New Upload".

### Issue: File Size Limit

**Solution**: Zenodo free tier has 50GB limit. Our total is ~2MB, well within limits.

### Issue: Citation Format

**Solution**: Use the provided `.cff` files. Zenodo auto-generates citations from these.

### Issue: Community Submission

**Solution**: Some communities require curator approval. Submit and wait for review.

---

## Quality Checklist

Before publishing, verify:

- [ ] All DOIs are correct and consistent
- [ ] Author name is consistent across all bundles
- [ ] License is CC-BY-4.0 for all bundles
- [ ] Keywords are relevant and specific
- [ ] Descriptions are complete (abstract + full text)
- [ ] Citations reference other bundles
- [ ] Mathematical formulas are readable
- [ ] Code snippets are formatted
- [ ] Figures/tables have captions
- [ ] References are complete

---

## Citation Examples

### APA Style

```text
Vasilev, D. (2026). Trinity B001: Ternary Neural Networks — Complete Scientific Framework. Zenodo. https://doi.org/10.5281/zenodo.19225088
```

### BibTeX

```bibtex
@software{trinity_b001_v2_2026,
  title={Trinity B001: Ternary Neural Networks — Complete Scientific Framework},
  author={Vasilev, Dmitrii},
  year={2026},
  doi={10.5281/zenodo.19225088},
  publisher={Zenodo}
}
```

### MLA Style

```text
Vasilev, Dmitrii. "Trinity B001: Ternary Neural Networks — Complete Scientific Framework." *Zenodo*, 2026, doi:10.5281/zenodo.19225088.
```

---

## Contact

For questions about Zenodo uploads:
- Zenodo Support: https://zenodo.org/support
- GitHub Issues: https://github.com/gHashTag/trinity/issues

---

**φ² + 1/φ² = 3 | TRINITY**
