# Trinity Discovery Matrix: Complete Cross-Reference

**All 69 discoveries across 7 bundles with dependencies and relationships**

**Date:** 2026-03-26
**Version:** 1.0.0

---

## Overview

| Bundle | Discoveries | Core Papers | Code Files |
|--------|-------------|-------------|------------|
| **B001** | 14 | 3 | src/hslm/, kaggle/ |
| **B002** | 13 | 2 | fpga/, src/hslm/f16_utils.zig |
| **B003** | 7 | 1 | src/tri27/ |
| **B004** | 10 | 2 | src/tri/queen/, src/farm/ |
| **B005** | 13 | 3 | src/tri-lang/, src/vibeec/ |
| **B006** | 9 | 2 | src/hslm/f16_utils.zig, src/sacred.zig |
| **B007** | 3 | 1 | src/vsa.zig, src/vsa_core/ |

---

## Complete Discovery Inventory

### B001: Ternary Neural Networks (14 discoveries)

| ID | Discovery | Dependencies | Files | Novelty |
|----|-----------|--------------|-------|---------|
| P1 | HSLM-1.95M | P2, P3, P7, P13 | src/hslm/ | 1.95M params, PPL=125 |
| P8 | T-JEPA | P1 | src/hslm/tjepa.zig | Ternary masked prediction |
| P9 | Cosine LR + φ-warmup | P2 | src/hslm/train.zig | Sacred scheduling |
| P10 | Gradient accumulation | P1 | src/hslm/trainer.zig | Ternary gradients |
| P11 | Checkpoint compression | P13 | src/hslm/ | 386KB (20x) |
| P12 | Wave-based training | P4 | src/farm/ | Multi-account |
| P13 | TF3 ternary packing | P14 | src/hslm/tf3.zig | 8 weights in 16 bits |
| P14 | φ-distance metric | P2 | src/hslm/ | \|a-b\|/φ |
| P15 | Saturating arithmetic | P2 | src/hslm/ | FPGA clamp |
| P16 | Sacred constants | P2 | src/sacred.zig | φ,π,e in ternary |
| P55 | Cognitive Probes v7 | P1 | kaggle/eval/ | Min-K%++, Full-ECE |
| P56 | Temperature Scaling v5 | P1 | kaggle/eval/ | Post-hoc calibration |
| P57 | ROC/AUC Analysis | P1 | kaggle/eval/roc_utils.py | Proper scoring |
| P58 | Contamination Detection | P1 | kaggle/validate/ | Leakage detection |

### B002: Zero-DSP FPGA (13 discoveries)

| ID | Discovery | Dependencies | Files | Novelty |
|----|-----------|--------------|-------|---------|
| P3 | Zero-DSP ternary MAC | P13 | fpga/.../hslm_ternary_mac.v | 0 DSP |
| P17 | DSP48E1 ternary wrapper | P3 | fpga/.../dsp48e1_ternary.v | 70% reduction |
| P18 | CORDIC continued fraction | P2 | fpga/.../cordic_sacred.v | 6-stage |
| P19 | Streaming Argmax | P3 | fpga/.../argmax_unit.v | <100 LUT |
| P20 | Ternary BRAM storage | P13 | fpga/.../ | 2-bit packed |
| P21 | Embedding lookup | P3 | fpga/.../embedding_lookup.v | Power-of-2 |
| P22 | Ternary scheduler | P4 | fpga/.../trinity_os/ | φ-weighted |
| P23 | ESP32 Wi-Fi JTAG | P3 | fpga/esp32-xvc/ | Cross-platform |
| P24 | UART echo verification | P3 | fpga/.../uart_echo_top.v | LED feedback |
| P25 | OpenXC7 synthesis | P3 | fpga/.../synth.sh | Docker pipeline |
| P26 | GF16 multiplier | P26 | fpga/.../gf16_multiplier.v | 15-bit format |
| P27 | VecMat DSP accel | P3 | fpga/.../dsp48e1_ternary.v | Ternary matmul |
| P35 | Episode Jaccard similarity | P4 | src/tri27/tri27_experience.zig | Recall |

### B003: TRI-27 ISA (7 discoveries)

| ID | Discovery | Dependencies | Files | Novelty |
|----|-----------|--------------|-------|---------|
| P4 | TRI-27 ISA | P32, P33 | src/tri27/ | 36 opcodes, 27 regs |
| P32 | Coptic alphabet encoding | P4 | src/tri27/coptic.zig | 3-bank |
| P33 | 3-bank validation | P4 | src/tri27/coptic.zig | Cross-bank prevention |
| P34 | T27 binary format | P4 | src/tri27/emu/encoder*.zig | Episode encoding |
| P64 | Reticular Raphe | P4 | src/tri27/reticular_raphe_wrapper.zig | φ-decay rolling |
| P65 | Phoenix Medulla | P4 | src/tri27/phoenix_medulla_wrapper.zig | Resilience |
| P66 | Queen vmPFC | P4 | src/tri27/queen_vmpfc_wrapper.zig | Prefrontal |

### B004: Queen Lotus Cycle (10 discoveries)

| ID | Discovery | Dependencies | Files | Novelty |
|----|-----------|--------------|-------|---------|
| P5 | Queen Lotus Cycle | P35, P36, P37 | src/tri/queen/self_learning.zig | 6-phase |
| P35 | Episode Jaccard similarity | P34 | src/tri27/tri27_experience.zig | Recall |
| P36 | Quality classification | P5 | src/tri/queen/evaluate.zig | 4 states |
| P37 | PolicyDelta actions | P5 | src/tri/queen/plan.zig | scale_* |
| P38 | Tri27Config auto-adapt | P5 | src/tri/queen/ | kill_threshold |
| P39 | Byzantine detection | P4 | src/farm/ | Crash monitoring |
| P40 | Service recycling | P39 | src/farm/evolution.zig | Kill-based |
| P52 | SEVO (Sacred Evolution) | P2 | src/farm/sevo.zig | φ-based hyperopt |
| P53 | ASHA+PBT Hybrid | P52 | src/farm/evolution.zig | Successive halving |
| P54 | Railway Farm Integration | P53 | src/farm/railway_api.zig | Serverless ML |

### B005: Tri Language (13 discoveries)

| ID | Discovery | Dependencies | Files | Novelty |
|----|-----------|--------------|-------|---------|
| P6 | Tri Language | P41, P42, P43 | src/tri-lang/ | DSL→Zig/Verilog |
| P41 | Linear Types + Ownership | P6 | src/tri-lang/linear_types.zig | Let/Inout/Sink/Set |
| P42 | Algebraic Effects + Handlers | P6 | src/tri-lang/effects.zig | Platform-aware |
| P43 | Bit/Trit Pattern Matching | P6 | src/tri-lang/bit_trit_patterns.zig | Hardware-level |
| P44 | Content-Addressed Functions | P6 | src/tri-lang/content_hash.zig | SHA256 AST |
| P45 | Result Type | P6 | src/tri-lang/result_type.zig | Austral-style |
| P46 | Array Combinators | P6 | src/tri-lang/array_combinators.zig | map/filter |
| P47 | Pipe Operator | P6 | src/tri-lang/pipe.zig | Chaining |
| P48 | Ternary JSON Parser | P6 | src/vibeec/simd_json.zig | 3-valued, 100M ops/s |
| P49 | Coptic Code Generation | P4 | src/vibeec/coptic_codegen_real.zig | T27 bytecode |
| P50 | Memory-Tiered Inference | P6 | src/vibeec/igla_long_context.zig | Hippocampus |
| P51 | VIBEE Benchmark Suite | P6 | src/vibeec/vibee_benchmark.zig | Iterative |
| P62 | VIBEE Spec (.tri) | P6 | specs/**/*.tri | DSL spec |
| P63 | HNSW Core | P6 | specs/tri/treesitter/hnsw_core.tri | Graph search |

### B006: Sacred Formats (9 discoveries)

| ID | Discovery | Dependencies | Files | Novelty |
|----|-----------|--------------|-------|---------|
| P2 | Sacred GF16/TF3 | P13, P14 | src/hslm/f16_utils.zig | exp=6,mant=9 |
| P13 | TF3 ternary packing | P2 | src/hslm/ | 8 weights in 16 bits |
| P14 | φ-distance metric | P2 | src/hslm/ | \|a-b\|/φ |
| P15 | Saturating arithmetic | P2 | src/hslm/ | FPGA clamp |
| P16 | Sacred constants | P2 | src/sacred.zig | φ,π,e in ternary |
| P59 | Episode JSONL | P34 | .trinity/experience/episodes/*.json | Experience tracking |
| P60 | Tri27Config JSON | P4 | .trinity/queen/ | Queen config |
| P61 | PolicySnapshot | P5 | src/tri/queen/observe.zig | Senses format |
| P62 | VIBEE Spec (.tri) | P6 | specs/**/*.tri | DSL spec (duplicate with P50) |

### B007: VSA Operations (3 discoveries)

| ID | Discovery | Dependencies | Files | Novelty |
|----|-----------|--------------|-------|---------|
| P7 | VSA bind/unbind/bundle | P28 | src/vsa/core.zig | HybridBigInt SIMD |
| P28 | Ternary dot-product | P7 | src/vsa/ | {-1,0,+1} |
| P29 | Permutation encoding | P7 | src/vsa/ | Cyclic |
| P30 | Cosine similarity | P7 | src/vsa/similarity.zig | Ternary vec |

---

## Dependency Graph

```
                        ┌─────────────────────┐
                        │    P2: Sacred GF16   │
                        │    (φ-based formats)│
                        └──────────┬──────────┘
                                   │
          ┌──────────────────────────┼──────────────────────────┐
          │                          │                          │
    ┌─────▼─────┐            ┌──────▼──────┐          ┌─────▼─────┐
    │ P1: HSLM  │            │ P3: Zero-DSP│          │ P4: TRI-27│
    └─────┬─────┘            └──────┬──────┘          └─────┬─────┘
          │                        │                        │
    ┌─────▼─────────┬────────────▼────────────┬────────▼────────┐
    │               │                         │                 │
┌───▼───┐      ┌───▼───┐              ┌────▼────┐      ┌────▼────┐
│P8-P12 │      │P17-P27│              │P32-P34 │      │P35-P37 │
│       │      │       │              │        │      │        │
└───┬───┘      └───────┘              └───┬────┘      └────┬────┘
    │                                      │                │
    └────────────────┬───────────────────┴────────────────┘
                     │
          ┌──────────▼──────────┐
          │   P5: Queen Lotus  │
          │   (Orchestration)  │
          └──────────┬──────────┘
                     │
    ┌────────────────┼────────────────┐
    │                │                │
┌───▼───┐      ┌───▼───┐      ┌───▼───┐
│P39-P40│      │P52-P54│      │P59-P61│
│       │      │       │      │       │
└───────┘      └───────┘      └───────┘
```

---

## Code File Mapping

### By File Type

| Type | Count | Examples |
|------|-------|----------|
| Zig (.zig) | 150+ | src/hslm/*.zig, src/tri27/*.zig |
| Verilog (.v) | 15+ | fpga/openxc7-synth/*.v |
| Python (.py) | 10+ | kaggle/eval/*.py |
| Tri Spec (.tri) | 20+ | specs/**/*.tri |
| JSON (.json) | 5+ | .trinity/**/*.json |

### By Module

| Module | Files | LOC |
|--------|-------|-----|
| hslm | 15 | 2,500 |
| tri27 | 12 | 1,800 |
| tri-lang | 25 | 3,200 |
| vibeec | 18 | 4,100 |
| farm | 10 | 2,300 |
| queen | 8 | 1,900 |
| vsa | 6 | 850 |
| sacred | 5 | 400 |
| fpga | 20 | 3,500 (Verilog) |

---

## Citation Graph

### Internal Citations

| Discovery | Cited By | Count |
|-----------|----------|-------|
| P1 (HSLM) | P8-P12, P55-P58 | 9 |
| P2 (GF16) | P13-P16, P59-P61 | 8 |
| P3 (Zero-DSP) | P17-P27 | 11 |
| P4 (TRI-27) | P32-P34, P64-P66 | 7 |
| P5 (Queen) | P35-P40, P52-P54 | 10 |
| P6 (Tri Lang) | P41-P51, P62-P63 | 13 |
| P7 (VSA) | P28-P30 | 3 |

### External References

1. Kanerva (2009) — Hyperdimensional Computing
2. Kaplan (2020) — Scaling Laws
3. Kahneman (2011) — Thinking Fast and Slow
4. Ma (2024) — 1-bit LLMs
5. Livio (2008) — Golden Ratio

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2026-03-26 | Initial release, 69 discoveries catalogued |

---

## License

- **Documentation:** CC-BY-4.0
- **Code:** MIT

---

**φ² + 1/φ² = 3 | TRINITY**
