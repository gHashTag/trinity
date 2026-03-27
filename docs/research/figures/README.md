# Trinity Zenodo Figures

Figures for Zenodo v9.0 bundle uploads.

## Required Figures (12 total)

### B001: HSLM-1.95M
- `B001-Fig1_training_curve.png` — Training loss curve (PPL vs steps)
- `B001-Fig2_format_comparison.png` — Model size comparison (FP32 vs GF16)

### B002: Zero-DSP FPGA
- `B002-Fig1_fpga_resources.png` — Resource utilization bar chart
- `B002-Fig2_power_analysis.png` — Power consumption comparison

### B003: TRI-27 ISA
- `B003-Fig1_register_layout.png` — Register bank diagram (3×9 layout)

### B004: Queen Lotus
- `B004-Fig1_lotus_cycle.png` — Consciousness cycle state diagram

### B005: Tri Language
- `B005-Fig1_type_hierarchy.png` — ADT type hierarchy visualization

### B006: GF16 Format
- `B006-Fig1_gf16_layout.png` — 16-bit word encoding diagram
- `B006-Fig2_phi_heatmap.png` — φ-normalization heatmap

### B007: VSA Operations
- `B007-Fig1_vsa_structure.png` — Hyperdimensional vector structure
- `B007-Fig2_simd_speedup.png` — SIMD speedup comparison chart

## Generation Script

```bash
# Generate all figures (requires matplotlib, seaborn)
python3 docs/research/figures/generate_all.py
```

## Figure Specifications

- **Format:** PNG (lossless)
- **DPI:** 300 (publication quality)
- **Width:** 800-1200 pixels (responsive)
- **Colors:** Trinity color palette (blue #3498db, green #2ecc71, purple #9b59b6)
- **Fonts:** System sans-serif (Apple System, Roboto, Segoe UI)

---

**φ² + 1/φ² = 3 | TRINITY**
