# Zenodo v6.0 — Quickstart Guide

**Version:** 6.0
**Date:** 2026-03-26
**Purpose:** Fast-track Zenodo upload for Trinity S³AI bundles

---

## Quick Start (3 Steps)

### Step 1: Prepare Upload Files

For each bundle (B001-B007), gather:

```
docs/research/
├── zenodo_B*_enhanced_v5.2.md  (Rename to zenodo_B*_v6.0.md)
├── figures/
│   ├── BXXX-Fig1_*.png
│   └── BXXX-Fig2_*.png
└── data/
    └── BXXX_*.csv (supplementary)
```

**File Upload Order:**
1. Main description (`zenodo_B*_v6.0.md`)
2. Figures (PNG + SVG) — use "upload multiple" if available
3. Supplementary data (CSV)
4. Code archive (if publishing new version)

### Step 2: Update Metadata

Edit `.zenodo.B*_v6.0.json`:

```json
{
  "title": "B001: Ternary Neural Networks — Complete Scientific Framework v6.0",
  "creators": [
    {
      "name": "Vasilev, Dmitrii",
      "orcid": "YOUR_ORCID_HERE",  // ← UPDATE THIS
      "affiliation": "Independent Researcher",
      "type": "Person"
    }
  ],
  "keywords": [
    "Artificial Intelligence",
    "Neural Networks",
    "Ternary Computing",
    "HSLM",
    "1.58-bit LLM",
    "Balanced Ternary",
    "Zig Language",
    "Zero Dependencies"
  ],
  "related_identifiers": [
    {
      "scheme": "doi",
      "identifier": "10.5281/zenodo.19227733",
      "relation": "references"
    }
  ]
}
```

### Step 3: Upload to Zenodo

1. Go to https://zenodo.org/deposit/new
2. Select "Software" as resource type
3. Fill in all fields from JSON metadata
4. Upload files in order from Step 1
5. **DO NOT PUBLISH** — save as draft first
6. Preview → Check all links and figures
7. Publish → Get new DOI

---

## Upload Checklist per Bundle

| Field | B001 | B002 | B003 | B004 | B005 | B006 | B007 |
|-------|------|------|------|------|------|------|------|
| Description v6.0 | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Figure 1 (PNG) | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Figure 2 (PNG) | ✅ | ✅ | — | ✅ | ✅ | ✅ | ✅ |
| Supplementary CSV | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Metadata JSON | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| DOI (v5.2) | 19227733 | 19227735 | 19227737 | 19227739 | 19227741 | 19227743 | 19227745 |

**Note:** v6.0 will receive NEW DOIs — do not reuse v5.2 DOIs!

---

## Estimated Time

- Per bundle: 15-20 minutes (including metadata entry)
- Total (7 bundles): 2-3 hours
- Parent collection: 30 minutes (after all bundles)

---

## Troubleshooting

### Issue: Figure Not Displaying

**Check:**
- File path in markdown uses `figures/` subdirectory
- Case-sensitive filenames
- PNG/SVG files are uploaded (not only markdown)

**Fix:**
- Use relative path: `figures/B001-Fig1_training_curve.png`
- Verify files exist in upload list

### Issue: Metadata Validation Failed

**Common errors:**
1. **Missing ORCID** — Add ORCID ID
2. **Keywords < 5** — Add more keywords
3. **Abstract < 100 chars** — This is OK (Zenodo doesn't enforce limit)
4. **Invalid DOI** — Do not include in metadata (Zenodo assigns new DOI)

### Issue: Upload Size Limit

**Zenodo limit:** 50 GB per deposit

**Bundle sizes (estimated):**
- B001: ~5 MB (description + 2 figures + data)
- B002: ~5 MB (description + 2 figures + data)
- B003: ~4 MB (description + 1 figure + data)
- B004: ~4 MB (description + 1 figure + data)
- B005: ~4 MB (description + 1 figure + data)
- B006: ~5 MB (description + 2 figures + data)
- B007: ~5 MB (description + 2 figures + data)

**Total per bundle:** ~4-5 MB — well under limit

---

## Post-Upload Verification

After publishing each bundle, verify:

1. **DOI resolves:** Open `https://doi.org/10.5281/zenodo.XXXXXX`
2. **Files downloadable:** Test download links for all files
3. **Figures render:** View online preview to check figures
4. **Metadata correct:** Title, author, keywords display properly
5. **Links work:** Related identifiers link to correct bundles

---

## Parent Collection (v6.0)

After all 7 bundles are published:

1. Go to parent collection (DOI: 10.5281/zenodo.19225187)
2. Update description to reference all new v6.0 DOIs
3. Update links table with new DOI links
4. Publish parent collection

---

## Contact & Support

- **Zenodo Help:** https://help.zenodo.org/
- **Trinity Issues:** https://github.com/gHashTag/trinity/issues
- **ORCID Lookup:** https://orcid.org/

---

φ² + 1/φ² = 3 | TRINITY
