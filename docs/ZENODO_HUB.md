# Trinity Zenodo Hub — Complete Reference

> **φ² + 1/φ² = 3 | TRINITY**
> **Single source of truth for ALL Zenodo operations**

---

## Quick Start (5 steps)

```bash
# 1. Create Zenodo account: https://zenodo.org/signup
# 2. Generate API token: https://zenodo.org/account/settings/applications/tokens/new
# 3. Set environment
export ZENODO_TOKEN=$(grep ZENODO_TOKEN .env | cut -d= -f2)

# 4. Test dry-run
python3 tools/zenodo_upload_v8.py --dry-run --all

# 5. Publish
python3 tools/zenodo_upload_v8.py --all
```

---

## Bundle Overview (8 bundles)

| Bundle | Title | DOI | LOC | Focus |
|--------|-------|-----|-----|-------|
| **B001** | HSLM-1.95M Ternary Neural Networks | 10.5281/zenodo.19227865 | 605 | Core model architecture |
| **B002** | Zero-DSP FPGA Accelerator | 10.5281/zenodo.19227867 | 679 | FPGA LUT-only arithmetic |
| **B003** | TRI-27 ISA | 10.5281/zenodo.19227869 | 511 | 27-register ternary processor |
| **B004** | Queen Lotus Consciousness Cycle | 10.5281/zenodo.19227871 | 522 | Phenomenological framework |
| **B005** | Tri Language Specification | 10.5281/zenodo.19227873 | 560 | Compiler & language design |
| **B006** | GF16 Ternary Format | 10.5281/zenodo.19227875 | 540 | Data serialization |
| **B007** | VSA (Vector Symbolic Architecture) | 10.5281/zenodo.19227877 | 619 | Hyperdimensional computing |
| **PARENT** | Trinity S³AI Framework | 10.5281/zenodo.19227879 | 504 | Unified research framework |

---

## File Map

### Metadata JSON (docs/research/)
```
.zenodo.B001_v8.0.json   # B001 metadata (605 lines)
.zenodo.B002_v8.0.json   # B002 metadata (679 lines)
.zenodo.B003_v8.0.json   # B003 metadata (511 lines)
.zenodo.B004_v8.0.json   # B004 metadata (522 lines)
.zenodo.B005_v8.0.json   # B005 metadata (560 lines)
.zenodo.B006_v8.0.json   # B006 metadata (540 lines)
.zenodo.B007_v8.0.json   # B007 metadata (619 lines)
.zenodo.PARENT_v8.0.json # PARENT metadata (504 lines)
```

### CLI Commands (src/tri/tri_zenodo.zig)
```bash
tri zenodo publish <version>  # Create version, upload, publish
tri zenodo status              # Show current record info
tri zenodo draft <version>     # Create draft without publishing
tri zenodo bundle <A-G>       # Publish individual bundle
tri zenodo validate <bundle>  # Validate metadata quality
tri zenodo generate <bundle>  # Generate full JSON metadata
```

**Bundle aliases:** A=B001, B=B002, C=B003, D=B004, E=B005, F=B006, G=B007

### Upload Script (tools/zenodo_upload_v8.py)
```bash
# Upload all bundles
python3 tools/zenodo_upload_v8.py --all

# Upload specific bundle
python3 tools/zenodo_upload_v8.py --bundle B001

# Dry-run (validate only)
python3 tools/zenodo_upload_v8.py --dry-run --all

# Production mode
python3 tools/zenodo_upload_v8.py --all --prod
```

### Validation Tools
```bash
# Fix B002 references format
python3 tools/fix_b002_references.py

# Validate all bundles
python3 tools/validate_zenodo_bundles.py

# Validate JSON syntax
for f in docs/research/.zenodo.*_v8.0.json; do
    python3 -m json.tool "$f" > /dev/null && echo "✅ $f" || echo "❌ $f"
done
```

---

## Zenodo Metadata Schema

### Required Fields
```json
{
  "title": "string",
  "creators": [{"name": "string", "orcid": "0009-0000-0000-0000"}],
  "description": "string (markdown supported)",
  "keywords": ["string"],
  "publication_date": "YYYY-MM-DD",
  "version": "string",
  "license": "CC-BY-4.0",
  "access_right": "open",
  "resource_type": {"type": "software", "title": "string"}
}
```

### Optional Fields
```json
{
  "doi": "10.5281/zenodo.xxxxxxx",
  "related_identifiers": [
    {"scheme": "doi", "identifier": "...", "relation": "references"}
  ],
  "references": ["string", ...],  // BibTeX-style strings only
  "communities": [{"identifier": "..."}]
}
```

### References Format (IMPORTANT!)
```json
"references": [
  "Vasilev, D. (2026). Trinity B001: HSLM-1.95M. Zenodo. https://doi.org/10.5281/zenodo.19227865",
  "@article{key, title={...}, author={...}, year={...}}"
]
```

**❌ WRONG:** Nested objects in `references` array
**✅ RIGHT:** Plain BibTeX-style strings

---

## V16 Scientific Framework

### Statistical Rigor Features
- **Confidence Intervals:** 95%/99% CI with bootstrap (10K resamples)
- **Effect Sizes:** Cohen's d, Hedges' g, Cliff's delta
- **P-values:** *, **, *** notation (0.05, 0.01, 0.001 thresholds)
- **Tests:** t-test, Wilcoxon, Mann-Whitney, ANOVA, Chi-square

### Structure (src/tri/doctor/zenodo_v16.zig)
```zig
pub const StatisticalSignificance = enum {
    ns,      // p ≥ 0.05
    one,     // *  p < 0.05
    two,     // ** p < 0.01
    three,   // *** p < 0.001
};

pub const ConfidenceInterval = struct {
    lower: f64,
    upper: f64,
    level: f64,  // 0.95 or 0.99
    method: Method,
};
```

---

## Citation Formats

### BibTeX
```bibtex
@software{trinity_b001,
  title={Trinity B001: HSLM-1.95M Ternary Neural Networks},
  author={Vasilev, Dmitrii},
  year={2026},
  doi={10.5281/zenodo.19227865},
  publisher={Zenodo}
}
```

### APA
```text
Vasilev, D. (2026). Trinity B001: HSLM-1.95M ternary neural networks. Zenodo. https://doi.org/10.5281/zenodo.19227865
```

### IEEE
```text
D. Vasilev, "Trinity B001: HSLM-1.95M Ternary Neural Networks," Zenodo, 2026. doi: 10.5281/zenodo.19227865.
```

---

## Troubleshooting

### JSON Validation Errors
```bash
# Check syntax
python3 -m json.tool docs/research/.zenodo.BXXX_v8.0.json

# Fix B002 references
python3 tools/fix_b002_references.py

# Validate all
python3 tools/validate_zenodo_bundles.py
```

### Upload Failures
```bash
# Check token
curl -H "Authorization: Bearer $ZENODO_TOKEN" https://zenodo.org/api/deposit/depositions

# Dry-run first
python3 tools/zenodo_upload_v8.py --dry-run --all
```

### Common Issues
| Issue | Fix |
|-------|-----|
| `JSON decode error` | Check for missing commas in references |
| `Invalid DOI` | Must start with `10.5281/zenodo.` |
| `Missing required field` | Add title, creators, description, license |
| `References format error` | Use plain strings, not objects |

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     ZENODO_HUB.md                          │
│                    (this document)                         │
└─────────────────────────────────────────────────────────────┘
                              │
        ┌─────────────────────┼─────────────────────┐
        │                     │                     │
        ▼                     ▼                     ▼
┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│  Metadata    │    │     CLI      │    │   Upload     │
│  (8 JSON)    │    │  (tri_zenodo)│    │   Script     │
└──────────────┘    └──────────────┘    └──────────────┘
        │                     │                     │
        └─────────────────────┼─────────────────────┘
                              ▼
                    ┌──────────────────┐
                    │   Zenodo API     │
                    │  (REST/Deposit)  │
                    └──────────────────┘
```

---

## Changelog

### v8.0 (2026-03-27)
- ✅ Fixed B002.json references format
- ✅ Fixed B003.json missing comma
- ✅ All 8 bundles validated
- ✅ Created ZENODO_HUB.md (single source of truth)
- ✅ Added validation tools (fix_b002_references.py, validate_zenodo_bundles.py)

### v5.0 (2026-03-27)
- ✅ ORCID integration (0009-0008-4294-6159)
- ✅ Enhanced descriptions with NeurIPS/ICLR/MLSys standards
- ✅ LaTeX tables for conference submissions
- ✅ Peer review templates

---

## Further Reading

- **Research Framework:** `docs/research/TRINITY_S3AI_UNIFIED_FRAMEWORK.md`
- **V16 Scientific Rigor:** `src/tri/doctor/zenodo_v16.zig`
- **CLI Implementation:** `src/tri/tri_zenodo.zig`
- **Upload Script:** `tools/zenodo_upload_v8.py`

---

**φ² + 1/φ² = 3 | TRINITY**
