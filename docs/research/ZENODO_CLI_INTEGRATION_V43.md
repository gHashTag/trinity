# Zenodo CLI Integration — V43 Report

**Date:** 2026-03-27
**Issue:** #415
**Status:** ✅ Complete

## Summary

Integrated the `zenodo_templates` library with the existing `tri_zenodo.zig` CLI, adding three new commands for generating scientific publication metadata.

## Changes Made

### 1. File Migration
- Moved `src/research/zenodo_templates.zig` → `src/tri/zenodo_templates.zig`
- Reason: Direct import access from tri_zenodo module

### 2. New CLI Commands

#### `tri zenodo template <bundle>`
Generates JSON metadata for Zenodo upload.

**Example:**
```bash
tri zenodo template B001
```

**Output:**
```json
{
  "title": "HSLM-1.95M: Ternary Neural Network for Edge Deployment",
  "creators": [{"name": "Dmitrii Vasilev"}],
  "description": "HSLM-1.95M is a 1.95M-parameter ternary language model...",
  "keywords": ["ternary neural network", "edge AI", ...],
  "license": "MIT",
  "publication_date": "2026-03-27",
  "version": "5.0.0",
  "related_identifiers": [
    {"relation": "isPartOf", "identifier": "10.5281/zenodo.19227879"}
  ],
  "upload_type": "publication"
}
```

#### `tri zenodo cff <bundle>`
Generates CITATION.cff file for academic citation.

**Example:**
```bash
tri zenodo cff B001
```

**Output file:** `CITATION_B001_Ternary_NN.cff`
```cff
cff-version: 1.2.0
message: "If you use this software, please cite it as below."

authors:
  - family-names: "Dmitrii Vasilev"
title: "HSLM-1.95M: Ternary Neural Network for Edge Deployment"
version: 5.0.0
doi: 10.5281/zenodo.19227865
url: https://doi.org/10.5281/zenodo.19227865
license: MIT
```

#### `tri zenodo readme <bundle>`
Generates README.md for Zenodo deposit with formatted tables.

**Example:**
```bash
tri zenodo readme B001
```

**Output file:** `README_B001_Ternary_NN.md`

### 3. Bundle Support

All 7 bundle types supported:
| ID | Name | DOI |
|----|------|-----|
| B001 | Ternary Neural Network (HSLM) | 10.5281/zenodo.19227865 |
| B002 | Zero-DSP FPGA Inference | 10.5281/zenodo.19227867 |
| B003 | TRI-27 ISA | 10.5281/zenodo.19227869 |
| B004 | Queen Orchestration | 10.5281/zenodo.19227871 |
| B005 | Tri Language | 10.5281/zenodo.19227873 |
| B006 | VSA Ternary | 10.5281/zenodo.19227875 |
| PARENT | Trinity S³AI Framework | 10.5281/zenodo.19227879 |

### 4. Module Structure

```
src/tri/
├── tri_zenodo.zig          # CLI commands (enhanced)
└── zenodo_templates.zig    # Template library
    ├── BundleType enum
    ├── ZenodoMetadata struct
    ├── TrainingResult struct
    ├── FPGAResources struct
    ├── CitationConverter
    └── 10 tests
```

## Test Results

```
✅ zenodo_templates: 10/10 tests passing
✅ tri_zenodo: 4/4 tests passing
```

## Usage

```bash
# Generate JSON template
tri zenodo template B001

# Generate CITATION.cff
tri zenodo cff B002

# Generate README for Zenodo
tri zenodo readme PARENT

# Show all commands
tri zenodo
```

## Technical Notes

1. **Memory Management**: Fixed bug where static string literals were being freed. The `createDefaultMetadata()` returns static slices, not allocated memory.

2. **Module Path**: Moved `zenodo_templates.zig` from `src/research/` to `src/tri/` to avoid Zig 0.15's "import outside module path" restriction.

3. **Bundle Aliases**: Short aliases supported (A-G) for convenience:
   - `tri zenodo template A` → B001
   - `tri zenodo template B` → B002
   - etc.

## Next Steps

1. Add automatic DOI validation
2. Integrate with HSLM training results
3. Add LaTeX table generation for papers
4. Support multiple authors with affiliations
5. Add funding reference support

## References

- Zenodo API v2025: https://zenodo.org/api
- CFF specification: https://citation-file-format.github.io/
- NeurIPS 2026 template guidelines
