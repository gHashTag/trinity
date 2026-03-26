# Figure Generation Guide — Zenodo v6.1

**Date:** 2026-03-26
**Purpose:** Manual figure generation for bundles B001-B007

φ² + 1/φ² = 3 | TRINITY

---

## Tools Required

### Option A: Python + Matplotlib (Recommended)
```bash
# Install dependencies
pip3 install matplotlib seaborn numpy pandas

# Generate all figures
cd docs/research/figures
python3 generate_all_figures.py
```

### Option B: Gnuplot (Pure Terminal)
```bash
# Install on macOS
brew install gnuplot

# Example plot script
set term pngcairo size 1000,600 enhanced font "Helvetica,12"
set output 'B001_training_curve.png'
set grid
set ylabel 'Perplexity'
set xlabel 'Training Steps'
plot 'B001_training.csv' using 1:2 with linespoints lw 2 lc rgb(0,128,128), \
     '' using 1:3:2:4 with filledcurves fc rgb(0,128,128) fs 0.3, \
     '' using 1:3:2:5 with filledcurves fc rgb(0,128,128) fs 0.3
```

### Option C: Excel/Numbers (GUI)
1. Open CSV file in Excel or Numbers
2. Select data range
3. Insert → Chart
4. Customize colors (Trinity Gold: #D4AF37, Teal: #008080)
5. Export as PNG

---

## Figure Specifications

### B001-Fig1_training_curve.png
**Type:** Line plot with 95% CI
**Data:** `data/B001_training.csv`
**Size:** 1000×600 px, 300 DPI
**Colors:**
- Line: Teal (#008080)
- CI: Teal with 30% opacity
- Background: White
**Labels:**
- X-axis: "Training Steps"
- Y-axis: "Perplexity"
- Title: "B001: HSLM Training Curve (TinyStories)"

**Data points:**
| Step | PPL | CI Lower | CI Upper |
|-------|------|-----------|-----------|
| 0 | 215 | 210 | 220 |
| 5000 | 165 | 160 | 170 |
| 10000 | 138 | 134 | 142 |
| 15000 | 128 | 124 | 132 |
| 20000 | 126 | 122 | 130 |
| 25000 | 125 | 121 | 129 |
| 30000 | 125 | 121 | 129 |

### B001-Fig2_format_comparison.png
**Type:** Bar chart (dual)
**Size:** 1400×500 px, 300 DPI
**Colors:** FP32: Teal, Ternary: Gold (#D4AF37)
**Categories:**
- FP32, FP16, INT8, Ternary (1.58b)
- Metrics: Bits per parameter, Model size (MB)

### B002-Fig1_fpga_resources.png
**Type:** Grouped bar chart (log scale)
**Size:** 1000×600 px, 300 DPI
**Categories:** DSP, LUT, FF, BRAM
**Series:** FP32 Baseline (Teal), Ternary Zero-DSP (Gold)

**Data:**
| Resource | FP32 | Ternary |
|----------|-------|----------|
| DSP | 96 | 0 |
| LUT | 8,500 | 12,433 |
| FF | 12,000 | 8,234 |
| BRAM | 45 | 28 |

### B002-Fig2_power_analysis.png
**Type:** Grouped bar chart
**Size:** 1000×600 px, 300 DPI
**Categories:** Dynamic, Static, Total
**Units:** Watts

**Data:**
| Component | FP32 (W) | Ternary (W) |
|-----------|------------|---------------|
| Dynamic | 0.95 | 0.68 |
| Static | 0.45 | 0.32 |
| Total | 1.40 | 1.00 |

### B003-Fig1_register_layout.png
**Type:** Architecture diagram (27 registers in 3 banks)
**Layout:** 3×9 grid with Coptic alphabet labels
**Colors:**
- Bank A (Ω): Teal
- Bank B (Γ): Gold
- Bank C (Σ): Purple (#6B4C9A)

**Coptic Labels:**
```
Bank A: ω, α, β, γ, δ, ε, ϝ, ζ, η, θ
Bank B: ι, κ, λ, μ, ν, ξ, π, ρ, σ, τ
Bank C: υ, φ, χ, ψ, ω, ⲁ, Ⲃ
```

### B004-Fig1_lotus_cycle.png
**Type:** Cycle diagram (5 phases)
**Layout:** Circular or sequential flow
**Phases:**
1. Perception (Lotus opens)
2. Encoding (Sacred layer)
3. Storage (Memory write)
4. Retrieval (Lotus closes)
5. Integration (Episode merge)

**Colors:** Phase 1-2: Teal, Phase 3-4: Gold, Phase 5: Purple

### B005-Fig1_type_hierarchy.png
**Type:** Tree diagram
**Root:** Type (top level)
**Branches:**
- Linear (ownership tracking)
- Effects (contextual operations)
- Result (error handling)
- Pattern Matching (ADT enums)

### B006-Fig1_gf16_layout.png
**Type:** Binary diagram (16-bit format)
**Layout:** 4×4 grid showing trit packing
**Legend:**
- 00 = -1, 01 = 0, 10 = +1
- 11 = unused
- 8 weights encoded in 16 bits

### B006-Fig2_phi_heatmap.png
**Type:** Heatmap or contour plot
**X-axis:** Number format (TF2, TF3, TF4, GF8, GF16, FP8, FP16, FP32)
**Y-axis:** Metric (Accuracy, Compression, Energy)
**Colormap:** Gold-to-purple gradient

### B007-Fig1_vsa_structure.png
**Type:** ASCII-to-image diagram
**Content:** VSA operations flow
**Elements:**
- Bind (⊗) → Unbind (÷) → Bundle (⊕)
- HybridBigInt 1024-bit vectors
- SIMD acceleration block (NEON)

### B007-Fig2_simd_speedup.png
**Type:** Dual panel (absolute + speedup)
**Left Panel:** Log-scale bar chart (ns per operation)
**Right Panel:** Linear scale (speedup ×)
**Threshold:** 10× line (purple dashed)

**Operations:** Bind, Unbind, Bundle2, Bundle3, Cosine, Permute
**Colors:** Scalar: Teal, SIMD: Gold

### B007-Fig3_noise_resilience.png
**Type:** Dual line plot with CI bands
**X-axis:** Noise percentage (0-50%)
**Y-axis Left:** Accuracy (%)
**Y-axis Right:** Retrieval (%)

### B007-Fig4_similarity_distribution.png
**Type:** Histogram
**X-axis:** Cosine Similarity [-1, 1]
**Y-axis:** Frequency
**Reference Line:** 0 (orthogonal)
**Bins:** 50
**Color:** Teal bars, purple dashed line

---

## Export Formats

### Recommended: PNG + SVG
- **PNG:** For paper figures (300 DPI)
- **SVG:** For web/responsive figures

### Format Options

| Tool | Command |
|-------|----------|
| Python/Matplotlib | `plt.savefig('output.png', dpi=300)` |
| Gnuplot | `set term pngcairo size 1000,600 enhanced` |
| Inkscape | `inkscape input.svg --export-png=output.png --export-dpi=300` |

---

## Color Palette (Trinity)

| Name | Hex | RGB | Usage |
|-------|-------|------|
| Trinity Gold | #D4AF37 | 212, 175, 55 | Ternary, highlights, results |
| Trinity Teal | #008080 | 0, 128, 128 | FP32 baseline, standard elements |
| Trinity Purple | #6B4C9A | 107, 76, 154 | Special values, CI bounds |
| Dark Gray | #333333 | 51, 51, 51 | Labels, annotations |

---

## Quick Generation Commands

```bash
# Generate single figure with Python
cd docs/research/figures
python3 -c "
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd

# Load data
df = pd.read_csv('../data/B001_training.csv')

# Create plot
fig, ax = plt.subplots(figsize=(10,6))
ax.plot(df['step'], df['perplexity'], color='#008080', lw=2.5)
ax.fill_between(df['step'], df['ci_lower'], df['ci_upper'], alpha=0.3, color='#008080')
ax.set_xlabel('Training Steps')
ax.set_ylabel('Perplexity')
ax.set_title('B001: HSLM Training Curve')
ax.grid(True, alpha=0.3)
plt.savefig('B001-Fig1_training_curve.png', dpi=300, bbox_inches='tight')
print('Figure saved: B001-Fig1_training_curve.png')
"

# Convert SVG to PNG if needed
# inkscape B001-Fig1_training_curve.svg --export-png=B001-Fig1_training_curve.png --export-dpi=300
```

---

## Quality Checklist

For each figure:
- [ ] Resolution ≥ 300 DPI
- [ ] Minimum size 800×600 px
- [ ] Readable fonts (≥10 pt)
- [ ] Axes labeled with units
- [ ] Legend where applicable
- [ ] Colorblind-safe palette
- [ ] Both PNG and SVG formats
- [ ] Filename matches BXXX-FigN_name pattern

---

**φ² + 1/φ² = 3 | TRINITY**
