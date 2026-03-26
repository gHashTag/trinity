# Trinity Zenodo v6.0 Figures

Generated 22 publication-ready figures for Trinity S³AI Framework Zenodo bundles.

## Figure Inventory

### B001: HSLM Training & Formats (2 figures)
- **B001-Fig1_training_curve**: Training curve with 95% CI (30K steps, PPL 125.3)
- **B001-Fig2_format_comparison**: Memory vs quality trade-off (FP32/BF16/GF16/TF3)

### B002: FPGA Zero-DSP Implementation (2 figures)
- **B002-Fig1_fpga_resources**: Resource comparison (LUT/DSP/FF/BRAM) - 0 DSP
- **B002-Fig2_power_analysis**: Power efficiency (0.8W vs 2.8W FP32)

### B003: TRI-27 Register File (1 figure)
- **B003-Fig1_register_layout**: 3-bank layout (Alpha/Iota/Sigma, 27 registers)

### B004: Queen Lotus Cycle (1 figure)
- **B004-Fig1_lotus_cycle**: 6-phase state machine (DIAGNOSE → PLAN → ACT → VERIFY → MEASURE → PERSIST)

### B005: Tri Language Type System (1 figure)
- **B005-Fig1_type_hierarchy**: Linear types + Effects + Pattern Matching

### B006: GF16/TF3 φ-Optimal Formats (2 figures)
- **B006-Fig1_gf16_layout**: Bit layout comparison (Sign/Exponent/Mantissa)
- **B006-Fig2_phi_heatmap**: φ-distance heatmap (GF16/TF3 marked as optimal)

### B007: VSA SIMD Architecture (2 figures)
- **B007-Fig1_vsa_structure**: HybridBigInt SIMD layout (32 limbs × 16 trits)
- **B007-Fig2_simd_speedup**: Performance comparison (17.2× average speedup)

## Specifications

- **Format**: PNG (300 DPI) + SVG (vector)
- **Color Scheme**: Trinity Gold (#D4AF37), Cyan, Magenta, etc.
- **Style**: Seaborn darkgrid, accessible
- **Dimensions**: 10-14" × 5-7" (variable)

## Generation

```bash
cd docs/research/figures
python3 generate_all_figures.py
```

φ² + 1/φ² = 3 | TRINITY
