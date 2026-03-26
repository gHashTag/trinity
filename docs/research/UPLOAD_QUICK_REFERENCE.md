# Zenodo Upload Quick Reference — Trinity S³AI v2.8

**Last Updated:** 2026-03-26
**Purpose:** Step-by-step guide for uploading all 7 bundles + parent collection

---

## Upload Order (IMPORTANT!)

**Upload in this order:**
1. Parent collection (draft only, don't publish)
2. Bundles B001-B007 (publish each)
3. Parent collection (publish with links)

---

## Step 1: Parent Collection (DRAFT)

### 1.1 Navigate
```
https://zenodo.org/deposit
```

### 1.2 Upload Files

Drag and drop these files:
```
ZENODO_README.md
ZENODO_MASTER_INDEX.md
EXPERIMENTAL_RESULTS.md
UNIFIED_BIBLIOGRAPHY.md
MATHEMATICAL_APPENDIX.md
ZENODO_SCIENTIFIC_GUIDE_V2.md
ZENODO_UPLOAD_GUIDE.md
ALGORITHM_PSEUDOCODE.md
SIMD_OPTIMIZATION.md
ROPE_ANALYSIS.md
TRAINING_DYNAMICS.md
SOTA_COMPARISON.md
PUBLICATION_CHECKLIST.md
SACRED_CONSTANTS.md
CITATION.cff
```

### 1.3 Enter Metadata

```
Title: Trinity S³AI Framework — Complete Scientific Collection
Authors: Dmitrii Vasilev
Description: [Copy from ZENODO_README.md]
Publication date: 2026-03-26
Version: 2.8
License: CC-BY-4.0
Keywords: ternary computing, neural networks, FPGA, VSA, TRI-27, Queen Lotus, Tri Language, sacred attention, golden ratio, vector symbolic architecture
Communities: zenodo, computer-vision, machine-learning, programming-languages
```

### 1.4 SAVE AS DRAFT
**DO NOT PUBLISH YET!**

---

## Step 2: Bundle B001 (PUBLISH)

### 2.1 Create New Upload
```
https://zenodo.org/deposit
```

### 2.2 Upload Files
```
zenodo_B001_full_description.md
CITATION_B001.cff
```

### 2.3 Enter Metadata
```
Title: Trinity B001: Ternary Neural Networks — Complete Scientific Framework
DOI: 10.5281/zenodo.19225088 (already reserved)
Description: [Copy Abstract from zenodo_B001_full_description.md]
Keywords: HSLM, ternary neural networks, sacred attention, consciousness gate, phi scaling, T-JEPA
Related: Is part of 10.5281/zenodo.19225187 (parent)
```

### 2.4 PUBLISH

---

## Step 3: Bundle B002 (PUBLISH)

Repeat Step 2 with:
```
Files: zenodo_B002_full_description.md, CITATION_B002.cff
Title: Trinity B002: Zero-DSP FPGA Architecture for Ternary Inference
DOI: 10.5281/zenodo.19225102
```

---

## Step 4: Bundle B003 (PUBLISH)

Repeat Step 2 with:
```
Files: zenodo_B003_full_description.md, CITATION_B003.cff
Title: Trinity B003: TRI-27 — Ternary ISA with Coptic Alphabet Encoding
DOI: 10.5281/zenodo.19225117
```

---

## Step 5: Bundle B004 (PUBLISH)

Repeat Step 2 with:
```
Files: zenodo_B004_full_description.md, CITATION_B004.cff
Title: Trinity B004: Queen Lotus Cycle — Autonomous Orchestration
DOI: 10.5281/zenodo.19225118
```

---

## Step 6: Bundle B005 (PUBLISH)

Repeat Step 2 with:
```
Files: zenodo_B005_full_description.md, CITATION_B005.cff
Title: Trinity B005: Tri Language — Linear Types, Effects, Dual-Target
DOI: 10.5281/zenodo.19225121
```

---

## Step 7: Bundle B006 (PUBLISH)

Repeat Step 2 with:
```
Files: zenodo_B006_full_description.md, CITATION_B006.cff
Title: Trinity B006: Sacred GF16/TF3 — Phi-Based Arithmetic
DOI: 10.5281/zenodo.19225122
```

---

## Step 8: Bundle B007 (PUBLISH)

Repeat Step 2 with:
```
Files: zenodo_B007_full_description.md, CITATION_B007.cff
Title: Trinity B007: VSA Operations for Ternary Computing
DOI: 10.5281/zenodo.19225124
```

---

## Step 9: Parent Collection (PUBLISH)

### 9.1 Open Parent Draft
```
https://zenodo.org/deposit
```
Find your parent collection draft.

### 9.2 Add Related Identifiers

For each bundle, add:
```
Relation: Has part
Identifier: 10.5281/zenodo.19225088 (B001)
Relation: Has part
Identifier: 10.5281/zenodo.19225102 (B002)
...
(All 7 bundles)
```

### 9.3 PUBLISH

---

## Step 10: Verification

### 10.1 Check All DOIs

Visit each DOI to verify:
```
https://doi.org/10.5281/zenodo.19225088 (B001)
https://doi.org/10.5281/zenodo.19225102 (B002)
https://doi.org/10.5281/zenodo.19225117 (B003)
https://doi.org/10.5281/zenodo.19225118 (B004)
https://doi.org/10.5281/zenodo.19225121 (B005)
https://doi.org/10.5281/zenodo.19225122 (B006)
https://doi.org/10.5281/zenodo.19225124 (B007)
https://doi.org/10.5281/zenodo.19225187 (Parent)
```

### 10.2 Verify Links

- Parent links to all 7 bundles
- Each bundle links to parent
- All files downloadable

---

## Quick Copy-Paste Metadata

### Parent Collection Description
```markdown
The Trinity S³AI Framework is a pure Zig autonomous AI agent swarm featuring ternary neural networks, FPGA inference, vector symbolic architectures, and a domain-specific language. This collection contains 7 publication bundles covering all major innovations.

Key innovations:
- HSLM: 1.95M parameter ternary LLM (377 KB, 20× compression)
- Zero-DSP FPGA: 0% DSP usage, 1.2W power (37.5× energy efficiency)
- TRI-27: 27-register ISA with Coptic alphabet encoding
- Queen Lotus: 6-phase autonomous orchestration
- Tri Language: Linear types, effects, dual-target compilation
- Sacred GF16/TF3: φ-based arithmetic formats
- VSA Operations: FHRR with 30% bitflip resilience

Mathematical foundation: φ² + φ⁻² = 3 where φ = 1.618...

Repository: https://github.com/gHashTag/trinity
```

### Keywords (comma-separated)
```
ternary computing, neural networks, FPGA, VSA, TRI-27, Queen Lotus, Tri Language, sacred attention, golden ratio, vector symbolic architecture, balanced ternary, zero-dsp, domain-specific language, hyperparameter optimization, symbolic AI
```

---

## Troubleshooting

### Issue: DOI Already Reserved
**Solution:** The DOI is already reserved. Just enter it in the metadata.

### Issue: File Size Limit
**Solution:** Zenodo free tier has 50GB limit. Our total is ~150 KB — well within limits.

### Issue: Community Approval Pending
**Solution:** Some communities require curator approval. Submit and wait.

---

## Post-Upload Checklist

- [ ] All 8 DOIs are resolvable
- [ ] Parent collection links to all bundles
- [ ] Each bundle links to parent
- [ ] All files are downloadable
- [ ] Citations are correct
- [ ] License is CC-BY-4.0

---

## Next Steps

1. Create GitHub release `v2.8-zenodo`
2. Add DOI badges to README.md
3. Announce on social media
4. Submit to conferences

---

**φ² + 1/φ² = 3 | TRINITY**
