# Zenodo Upload Guide — Trinity v9.0

## Prerequisites

1. **Zenodo Account:** https://zenodo.org/signup
2. **API Token:** https://zenodo.org/account/settings/applications/tokens/new
   - Create token with `deposit:actions` and `deposit:write` scopes

## Setup

```bash
# Set environment variable
export ZENODO_TOKEN="your_token_here"

# Verify token works
curl -H "Authorization: Bearer $ZENODO_TOKEN" https://zenodo.org/api/deposit/depositions
```

## Upload Options

### Option 1: Python Script (Recommended)

```bash
# Dry-run (validate only)
python3 tools/zenodo_upload_v9.py --dry-run --all

# Upload all bundles
python3 tools/zenodo_upload_v9.py --all

# Upload single bundle
python3 tools/zenodo_upload_v9.py --bundle B001

# Production mode (live upload)
python3 tools/zenodo_upload_v9.py --all --prod
```

### Option 2: Manual Upload via Web UI

1. Go to https://zenodo.org/deposit
2. Select "New Upload"
3. For each bundle (B001-B007 + PARENT):
   - Upload the corresponding JSON metadata file
   - Add files: source code, documentation, tests
   - Upload and publish

## Bundle File Lists

### B001: HSLM-1.95M
```
Required files:
- docs/research/.zenodo.B001_v9.0.json (metadata)
- src/hslm/*.zig (source)
- docs/research/bundles/B001_HSLM.md (documentation)

Optional files:
- var/trinity/models/hslm-1.95m/* (model weights)
- benchmarks/hslm_results.csv (experimental data)
```

### B002: Zero-DSP FPGA
```
Required files:
- docs/research/.zenodo.B002_v9.0.json (metadata)
- fpga/openxc7-synth/*.v (Verilog source)
- fpga/synthesis_reports/*.rpt (Vivado reports)
- docs/research/bundles/B002_FPGA.md (documentation)

Optional files:
- fpga/bitstreams/*.bit (pre-compiled bitstreams)
```

### B003: TRI-27 ISA
```
Required files:
- docs/research/.zenodo.B003_v9.0.json (metadata)
- src/vm.zig (VM implementation)
- src/vm_test.zig (tests)
- specs/tri27/*.tri (ISA specifications)
- docs/research/bundles/B003_TRI27.md (documentation)

Optional files:
- formal_verification/z3_proofs.smt2 (Z3 proofs)
```

### B004: Queen Lotus
```
Required files:
- docs/research/.zenodo.B004_v9.0.json (metadata)
- src/tri/queen/self_learning.zig (core implementation)
- apps/queen/* (SwiftUI UI)
- docs/research/queen_lotus_experiments.md (research notes)
- docs/research/bundles/B004_Lotus.md (documentation)

Optional files:
- experiments/lotus_training_logs.csv (episode data)
```

### B005: Tri Language
```
Required files:
- docs/research/.zenodo.B005_v9.0.json (metadata)
- specs/tri/*.tri (language specifications)
- src/vibeec/*.zig (compiler source)
- docs/research/bundles/B005_TriLang.md (documentation)

Optional files:
- examples/*.tri (example programs)
```

### B006: GF16 Format
```
Required files:
- docs/research/.zenodo.B006_v9.0.json (metadata)
- src/sacred/formats/gf16.zig (format implementation)
- src/sacred/formats/gf16_test.zig (tests)
- docs/research/bundles/B006_GF16.md (documentation)

Optional files:
- benchmarks/gf16_compression.csv (compression data)
```

### B007: VSA Operations
```
Required files:
- docs/research/.zenodo.B007_v9.0.json (metadata)
- src/vsa.zig (VSA operations)
- src/vsa_test.zig (tests)
- docs/research/bundles/B007_VSA.md (documentation)

Optional files:
- benchmarks/vsa_simd.csv (SIMD speedup data)
- experiments/vsa_noise_resilience.csv (noise tests)
```

### PARENT: Trinity S³AI Framework
```
Required files:
- docs/research/.zenodo.PARENT_v9.0.json (metadata)
- README.md (main readme)
- docs/research/bundles/README.md (bundle navigation)
- docs/research/bundles/QUICK_REFERENCE.md (quick reference)
- docs/research/TRINITY_S3AI_UNIFIED_FRAMEWORK.md (framework overview)

Optional files:
- CLAUDE.md (project instructions)
- AGENTS.md (agent documentation)
```

## Upload Checklist

For each bundle:

- [ ] Metadata JSON validates (`python3 -m json.tool`)
- [ ] Description includes v9.0 enhancements
- [ ] All required files listed
- [ ] Cross-references to related bundles
- [ ] Citation format correct (BibTeX, APA, IEEE)
- [ ] License specified (MIT or CC-BY-4.0)
- [ ] Keywords include version-specific terms

## Post-Upload

After successful upload:

1. **Verify DOI:** Check that DOI resolves correctly
2. **Test Download:** Download and verify uploaded files
3. **Update README:** Add DOI badges to main README
4. **Create Release:** Tag release in GitHub with Zenodo link
5. **Notify:** Update issue #435 with upload confirmation

## Troubleshooting

### "Invalid API token"
- Verify token has correct scopes
- Check ZENODO_TOKEN environment variable
- Regenerate token if expired

### "Metadata validation failed"
- Run `python3 -m json.tool metadata.json` to check syntax
- Ensure all required fields present
- Check DOI format (10.5281/zenodo.xxxxx)

### "File upload failed"
- Check file size (< 25GB per file)
- Verify file exists at specified path
- Ensure sufficient Zenodo quota

### "Publication failed"
- Check community guidelines compliance
- Verify license compatibility
- Ensure no embargoed content

## Zenodo Quotas

| Account Type | Storage | Max File Size |
|--------------|---------|---------------|
| Free | 50 GB | 25 GB |
| Premium | 500 GB | 100 GB |

**Current Trinity Usage:**
- B001: ~5 MB (source + docs)
- B002: ~15 MB (Verilog + reports)
- B003: ~2 MB (source + specs)
- B004: ~3 MB (Swift + docs)
- B005: ~4 MB (compiler + specs)
- B006: ~1 MB (source + tests)
- B007: ~2 MB (source + tests)
- PARENT: ~1 MB (docs only)
- **Total:** ~33 MB (well under 50 GB limit)

## Next Steps

1. Generate API token
2. Run dry-run validation
3. Upload all bundles
4. Verify DOIs
5. Update README with badges
6. Publish announcement

---

**φ² + 1/φ² = 3 | TRINITY**
