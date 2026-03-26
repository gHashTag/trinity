# Zenodo v5.2 Upload Guide

**Date:** 2026-03-26
**Version:** 5.2
**Total Bundles:** 8 (B001-B007, PARENT)

---

## Prerequisites

1. **Zenodo Account:** https://zenodo.org/signup
2. **Personal Access Token:** Settings → Applications → Personal access token → New token
3. **Environment Setup:** `export ZENODO_TOKEN=your_token_here`

---

## v5.2 Enhancement Summary

All 8 bundles have been enhanced with:

### Scientific Rigor Improvements

| Component | v5.0 | v5.2 |
|-----------|------|------|
| Algorithm Boxes | ❌ | ✅ Pseudocode for all key algorithms |
| Architecture Diagrams | ❌ | ✅ ASCII art with detailed labels |
| Experimental Protocols | ❌ | ✅ Step-by-step reproduction |
| Statistical Analysis | ❌ | ✅ Hypothesis testing, p-values, CI |
| Limitations Sections | ❌ | ✅ Known failure modes |
| MLSys Reproducibility Card | ❌ | ✅ Complete checklist |

### Documentation Growth

| Bundle | v5.0 LOC | v5.2 LOC | Growth |
|--------|----------|----------|--------|
| B001 | 1,150 | 1,800 | +650 (+56%) |
| B002 | 745 | 1,295 | +550 (+74%) |
| B003 | 601 | 1,051 | +450 (+75%) |
| B004 | 688 | 1,188 | +500 (+73%) |
| B005 | 156 | 606 | +450 (+288%) |
| B006 | 184 | 484 | +300 (+163%) |
| B007 | 284 | 684 | +400 (+141%) |
| PARENT | 425 | 1,025 | +600 (+141%) |
| **Total** | **4,233** | **8,079** | **+3,846 (+91%)** |

---

## Upload Procedure

### Option A: Automated (via tri CLI)

```bash
# Build the project
zig build

# Upload all v5.2 bundles
./zig-out/bin/tri zenodo bundle-v5.2

# Upload single bundle
./zig-out/bin/tri zenodo bundle-v5.2 B001
```

### Option B: Manual (via Zenodo Web UI)

For each bundle (B001-B007, PARENT):

1. **Login to Zenodo:** https://zenodo.org/deposit
2. **Create New Upload:** "New upload" button
3. **Upload Files:** Drag and drop the markdown file
4. **Fill Metadata:**
   - **Title:** From `title` field in bundle record
   - **Upload Type:** Software
   - **Publication Date:** 2026-03-26
   - **Description:** Copy entire markdown file content
   - **Authors:** Dmitrii Vasilev
   - **License:** CC-BY-4.0
   - **Keywords:** From `keywords` field (comma-separated)
   - **Version:** 5.2
5. **Publish:** Click "Publish" button

---

## Bundle Metadata

### B001: Ternary Neural Networks

```
Title: Trinity B001: Ternary Neural Networks — Complete Scientific Framework v5.2
File: docs/research/zenodo_B001_enhanced_v5.2.md
Keywords: ternary,neural-network,HSLM,LLM,PPL,TinyStories,1.95M,compression,
  checkpoint,phi-based,sacred,T-JEPA,consciousness-gate,cosine-lr,Docker,
  reproducibility,ethics,broader-impact,algorithm-boxes,architecture-diagrams,
  statistical-analysis,hypothesis-testing,limitations,MLSys-reproducibility-card
CPC: G06N3/00,G06N3/0455,G06F7/52,G06F17/16
```

### B002: Zero-DSP FPGA

```
Title: Trinity B002: Zero-DSP FPGA Architecture for Ternary Inference v5.2
File: docs/research/zenodo_B002_enhanced_v5.2.md
Keywords: zero-DSP,FPGA,LUT,inference,ternary,CORDIC,argmax,BRAM,Yosys,
  nextpnr,XC7A100T,synthesis,JTAG,ESP32,UART,Docker,reproducibility,ethics,
  broader-impact,algorithm-boxes,architecture-diagrams,statistical-analysis,
  experimental-protocol,limitations
CPC: G06F7/52,G06F7/72,G06F17/00,H03K19/20
```

### B003: TRI-27 ISA

```
Title: Trinity B003: TRI-27 ISA — Ternary Instruction Set with Coptic Alphabet Encoding v5.2
File: docs/research/zenodo_B003_enhanced_v5.2.md
Keywords: TRI-27,ISA,ternary,Coptic,alphabet,encoding,3-bank,registers,opcodes,
  episode,binary,27-registers,Docker,reproducibility,ethics,cultural-heritage,
  algorithm-boxes,opcode-tables,assembly-examples,code-density,statistical-analysis,
  limitations
CPC: G06F9/30,G06F9/34,G06F15/16
```

### B004: Queen Lotus Cycle

```
Title: Trinity B004: Queen Lotus Cycle — Autonomous Orchestration for Self-Evolving AI v5.2
File: docs/research/zenodo_B004_enhanced_v5.2.md
Keywords: Queen,self-learning,orchestration,Lotus,Cycle,episode,Jaccard,similarity,
  SEVO,hyperopt,ASHA,PBT,Railway,autonomous,AI,ethics,broader-impact,reproducibility,
  algorithm-boxes,architecture-diagrams,statistical-analysis,experimental-protocol,
  limitations,retrieval-accuracy,sample-efficiency
CPC: G06N20/00,G06F3/00,G06N5/00
```

### B005: Tri Language

```
Title: Trinity B005: Tri Language — Linear Types, Effects, Dual-Target Compilation v5.2
File: docs/research/zenodo_B005_enhanced_v5.2.md
Keywords: Tri,language,DSL,codegen,Zig,Verilog,linear-types,ownership,effects,handlers,
  pattern-matching,bit,trit,ADT,pipe,compiler,Docker,reproducibility,ethics,
  algorithm-boxes,type-system-diagrams,code-examples,statistical-analysis,limitations,
  code-generation-quality
CPC: G06F8/30,G06F8/34,G06F8/65
```

### B006: Sacred GF16/TF3

```
Title: Trinity B006: Sacred GF16/TF3 — Phi-Based Arithmetic for Ternary Computing v5.2
File: docs/research/zenodo_B006_enhanced_v5.2.md
Keywords: sacred,GF16,TF3,floating-point,ternary,phi-based,arithmetic,compression,
  phi-distance,exponent,mantissa,FPGA,Docker,reproducibility,ethics,algorithm-boxes,
  format-specifications,statistical-analysis,limitations,information-retention,
  hardware-utilization
CPC: G06F7/52,G06F7/54,G06F5/01
```

### B007: VSA Operations

```
Title: Trinity B007: VSA Operations for Ternary Computing v5.2
File: docs/research/zenodo_B007_enhanced_v5.2.md
Keywords: VSA,vector-symbolic,architecture,bind,unbind,bundle,ternary,dot-product,
  permutation,FHRR,BSD,HybridBigInt,SIMD,cosine-similarity,Docker,reproducibility,
  ethics,algorithm-boxes,architecture-diagrams,statistical-analysis,SIMD-speedup,
  noise-resilience,limitations,truth-tables
CPC: G06F7/72,G06F17/16,G06N3/00
```

### PARENT: Trinity S³AI Framework

```
Title: Trinity S³AI Framework — Complete Research Collection v5.2
File: docs/research/zenodo_parent_collection_v5.2.md
Keywords: Trinity,S3AI,ternary,computing,framework,HSLM,FPGA,TRI-27,Queen,Tri-language,
  GF16,TF3,VSA,phi-based,sacred,neural,network,instruction,set,orchestration,linear,
  types,effects,handlers,pattern,matching,ethics,broader-impact,reproducibility,
  algorithm-boxes,architecture-diagrams,statistical-analysis,experimental-protocols,
  limitations,MLSys-reproducibility-cards
CPC: G06N3/00,G06N20/00,G06F7/52,G06F9/30,G06F8/30,G06F7/72,G06F17/16
```

---

## Verification Checklist

After upload, verify each bundle:

- [ ] DOI assigned (format: 10.5281/zenod.XXXXXXX)
- [ ] Description displays correctly (markdown rendered)
- [ ] All keywords indexed
- [ ] License shows as CC-BY-4.0
- [ ] Version shows as 5.2
- [ ] Author shows as "Vasilev, Dmitrii"
- [ ] Publication date: 2026-03-26
- [ ] Concept DOI matches parent collection

---

## Post-Upload Actions

1. **Update CITATION.cff** with new DOIs (if different from v5.0)
2. **Update README.md** with new version badges
3. **Create GitHub Release** tagged as `v5.2.0`
4. **Announce on:**
   - GitHub Discussions
   - Twitter/X (@trinity_s3ai)
   - Relevant academic forums

---

## Troubleshooting

### Error: "Invalid JSON in metadata"

**Cause:** Special characters in description not escaped
**Fix:** Use automated CLI which handles escaping

### Error: "File too large"

**Cause:** Zenodo limit is 100GB per dataset
**Fix:** Split large files or use Zenodo Sandbox for testing

### Error: "Duplicate DOI"

**Cause:** Version already exists
**Fix:** Create new version instead of new deposit

---

## Scientific Compliance

All v5.2 bundles comply with:

### NeurIPS 2025 Standards
- ✅ Broader Impact statement
- ✅ 5-sentence abstract structure
- ✅ Computational complexity analysis
- ✅ Experimental protocol documentation
- ✅ Algorithm pseudocode

### ICLR 2025 Standards
- ✅ Ethical considerations
- ✅ Reproducibility checklist
- ✅ Code availability with verified tests
- ✅ Docker environment specification
- ✅ Limitations section

### MLSys 2025 Standards
- ✅ System description with architecture diagrams
- ✅ Performance metrics with confidence intervals
- ✅ Hardware specifications
- ✅ Build and deployment instructions
- ✅ Reproducibility card format

---

**φ² + 1/φ² = 3 | TRINITY**
