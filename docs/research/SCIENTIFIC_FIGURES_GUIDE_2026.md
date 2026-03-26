# Scientific Figures Guide for Trinity Publications 2026

**Author:** Dmitrii Vasilev
**Date:** 2026-03-26
**Version:** 1.0
**Purpose:** Guidelines for publication-quality figures in Trinity papers
**Status:** Ready for use

---

## Overview

This guide ensures all figures in Trinity publications meet the quality standards required by top-tier venues (NeurIPS, ICLR, MLSys) and are optimized for both readability and scientific communication.

---

## Part I: General Figure Standards

### Resolution and Format

| Requirement | Value |
|-------------|-------|
| **Minimum DPI** | 300 for raster images |
| **Preferred format** | PDF/SVG (vector), PNG (raster) |
| **Color mode** | RGB (for screen), CMYK (for print) |
| **Font size** | 8-12 pt (readable when scaled to column width) |
| **Line width** | 0.5-2 pt (visible when scaled) |

### File Naming

```
figures/
├── fig1_architecture.pdf
├── fig2_results.pdf
├── fig3_ablation.pdf
└── supplementary/
    ├── fig_s1_additional.pdf
    └── fig_s2_extended.pdf
```

---

## Part II: Figure Types and Templates

### Figure 1: Architecture Overview

**Purpose:** Show system architecture at a glance

**Required Elements:**
- Component boxes with clear labels
- Data flow arrows
- Layer/group boundaries
- Scale annotations (if applicable)
- Legend for symbols/colors

**Best Practices:**
- Use consistent color scheme throughout paper
- Avoid clutter: group related components
- Use rounded corners for modern look
- Include scale (parameters, layers, etc.)

```python
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
from matplotlib.patches import FancyBboxPatch, FancyArrowPatch

fig, ax = plt.subplots(figsize=(10, 6))

# Color scheme (Trinity brand)
COLOR_HSLM = '#E74C3C'    # Red
COLOR_VSA = '#3498DB'     # Blue
COLOR_FPGA = '#2ECC71'    # Green
COLOR_TRI27 = '#9B59B6'   # Purple

# Draw components
hslm_box = FancyBboxPatch((0.1, 0.6), 0.25, 0.3, boxstyle="round,pad=0.1", 
                           edgecolor='black', facecolor=COLOR_HSLM, alpha=0.7)
ax.add_patch(hslm_box)
ax.text(0.225, 0.75, 'HSLM\n1.95M params', ha='center', va='center', 
        fontsize=10, weight='bold')

# Add arrows between components
arrow1 = FancyArrowPatch((0.35, 0.75), (0.45, 0.75), 
                          arrowstyle='->', mutation_scale=20, lw=2)
ax.add_patch(arrow1)

ax.set_xlim(0, 1)
ax.set_ylim(0, 1)
ax.axis('off')
plt.tight_layout()
plt.savefig('fig1_architecture.pdf', dpi=300, bbox_inches='tight')
```

### Figure 2: Results Comparison

**Purpose:** Compare Trinity baselines against SOTA

**Required Elements:**
- Bar chart with error bars (95% CI or SEM)
- Grouping by category
- Statistical annotations (*p*, **p**, ***p***)
- Y-axis label with unit
- Legend (if needed)
- Sample size in caption

**Best Practices:**
- Use consistent colors across all result figures
- Sort by performance (or logical grouping)
- Don't use 3D effects
- Include zero baseline if meaningful

```python
import numpy as np
import matplotlib.pyplot as plt

fig, ax = plt.subplots(figsize=(8, 5))

models = ['HSLM', 'GPT-3S', 'LLaMA-7B', 'Phi-3']
ppl = [125.3, 121.3, 118.5, 122.8]
errors = [2.1, 1.8, 1.5, 2.0]

colors = ['#E74C3C' if m == 'HSLM' else '#95A5A6' for m in models]

bars = ax.bar(models, ppl, yerr=errors, capsize=5, color=colors, 
              edgecolor='black', linewidth=1.5, alpha=0.8)

# Statistical annotations
ax.annotate('***', xy=(0, 127.4), xytext=(0, 130),
            arrowprops=dict(arrowstyle='->', color='black'),
            ha='center', fontsize=14, color='black')

ax.set_ylabel('Perplexity (lower is better)', fontsize=12, weight='bold')
ax.set_ylim(115, 135)
ax.grid(axis='y', alpha=0.3, linestyle='--')
ax.spines['top'].set_visible(False)
ax.spines['right'].set_visible(False)

plt.tight_layout()
plt.savefig('fig2_ppl_comparison.pdf', dpi=300)
```

### Figure 3: Training Curves

**Purpose:** Show training dynamics over time

**Required Elements:**
- X-axis: Training steps (log scale if wide range)
- Y-axis: Metric (loss, PPL, accuracy)
- Multiple seeds with confidence bands
- Vertical line for final checkpoint
- Annotation for key events

**Best Practices:**
- Use log scale for x-axis if >10K steps
- Show mean ± SD across seeds
- Don't plot every single step (aggregate)
- Include smoothed line (EMA) and raw data

```python
import numpy as np
import matplotlib.pyplot as plt
from scipy.ndimage import gaussian_filter1d

fig, ax = plt.subplots(figsize=(10, 5))

steps = np.arange(0, 50000, 100)
# Simulated data for 5 seeds
seeds = [np.exp(-(steps/50000)**2) * 5 + np.random.normal(0, 0.2, len(steps)) 
         for _ in range(5)]

mean_ppl = np.mean(seeds, axis=0)
std_ppl = np.std(seeds, axis=0)

# Fill between for 95% CI
ax.fill_between(steps, mean_ppl - 1.96*std_ppl, mean_ppl + 1.96*std_ppl, 
                 alpha=0.3, color='#E74C3C', label='95% CI')
ax.plot(steps, mean_ppl, color='#E74C3C', linewidth=2, label='Mean PPL')

# Annotate final checkpoint
ax.axvline(50000, color='black', linestyle='--', alpha=0.5)
ax.text(50000, ax.get_ylim()[1], '  Final checkpoint', 
        ha='right', va='top', fontsize=10)

ax.set_xscale('log')
ax.set_xlabel('Training Steps', fontsize=12, weight='bold')
ax.set_ylabel('Perplexity', fontsize=12, weight='bold')
ax.legend()
ax.grid(alpha=0.3)
plt.tight_layout()
plt.savefig('fig3_training_curve.pdf', dpi=300)
```

### Figure 4: Ablation Study

**Purpose:** Show contribution of each component

**Required Elements:**
- Horizontal bar chart (easier to read labels)
- Cumulative or individual contributions
- Effect size annotations
- Baseline comparison

```python
fig, ax = plt.subplots(figsize=(8, 5))

components = ['Full Model', 'w/o VSA', 'w/o φ-RoPE', 
              'w/o Consciousness', 'w/o EMA', 'Baseline']
ppl = [125.3, 128.5, 131.2, 133.8, 135.5, 142.1]

colors = ['#E74C3C', '#E67E22', '#F39C12', '#F1C40F', '#BDC3C7', '#95A5A6']

bars = ax.barh(components, ppl, color=colors, edgecolor='black', linewidth=1)

# Add value labels
for bar, val in zip(bars, ppl):
    ax.text(val + 0.5, bar.get_y() + bar.get_height()/2, 
            f'{val:.1f}', va='center', fontsize=10)

ax.set_xlabel('Perplexity (lower is better)', fontsize=12, weight='bold')
ax.set_xlim(120, 145)
ax.invert_yaxis()  # Best model at top
ax.grid(axis='x', alpha=0.3, linestyle='--')
plt.tight_layout()
plt.savefig('fig4_ablation.pdf', dpi=300)
```

### Figure 5: Resource Usage

**Purpose:** Show efficiency metrics

**Required Elements:**
- Dual Y-axis if needed (e.g., accuracy and energy)
- Comparison to baselines
- Log scale if wide range
- Clear units

```python
fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(12, 4))

# Energy comparison
models = ['GPU (A100)', 'CPU (M1)', 'FPGA (Trinity)']
energy = [100, 15, 0.37]  # mJ/token

bars = ax1.bar(models, energy, color=['#95A5A6', '#95A5A6', '#2ECC71'],
               edgecolor='black', linewidth=1.5)
ax1.set_ylabel('Energy (mJ/token)', fontsize=12, weight='bold')
ax1.set_yscale('log')
ax1.set_title('Energy Efficiency', fontsize=12, weight='bold')
ax1.grid(axis='y', alpha=0.3, linestyle='--')

# Parameter count
params = [175, 7.6, 1.95]  # Billion parameters
bars2 = ax2.bar(models, params, color=['#95A5A6', '#95A5A6', '#E74C3C'],
                edgecolor='black', linewidth=1.5)
ax2.set_ylabel('Parameters (B)', fontsize=12, weight='bold')
ax2.set_title('Model Size', fontsize=12, weight='bold')
ax2.grid(axis='y', alpha=0.3, linestyle='--')

plt.tight_layout()
plt.savefig('fig5_resources.pdf', dpi=300)
```

### Figure 6: Confusion Matrix / Heatmap

**Purpose:** Show classification or attention patterns

**Required Elements:**
- Colorbar with label
- Axis labels
- Values in cells (if small matrix)
- Annotated with counts/percentages

```python
import seaborn as sns
import matplotlib.pyplot as plt
import numpy as np

fig, ax = plt.subplots(figsize=(8, 7))

# Confusion matrix data
cm = np.array([[850, 45, 30],
               [38, 920, 52],
               [25, 35, 905]])

# Normalize to percentages
cm_pct = cm / cm.sum(axis=1, keepdims=True) * 100

# Plot heatmap
sns.heatmap(cm, annot=True, fmt='d', cmap='Blues', 
            cbar_kws={'label': 'Count'}, ax=ax)

# Add percentage labels
for i in range(3):
    for j in range(3):
        ax.text(j + 0.5, i + 0.7, f'({cm_pct[i,j]:.1f}%)',
                ha='center', va='center', fontsize=8, color='red')

ax.set_xlabel('Predicted', fontsize=12, weight='bold')
ax.set_ylabel('True', fontsize=12, weight='bold')
ax.set_title('Confusion Matrix', fontsize=14, weight='bold')
plt.tight_layout()
plt.savefig('fig6_confusion_matrix.pdf', dpi=300)
```

### Figure 7: Effect Size Visualization

**Purpose:** Show effect sizes with confidence intervals

**Required Elements:**
- Forest plot format
- Effect size with 95% CI
- Reference line at null effect
- Magnitude interpretation

```python
fig, ax = plt.subplots(figsize=(8, 5))

effects = ['Cohen\'s d', 'Cliff\'s Δ', 'r', 'R²']
values = [0.45, 0.12, 0.35, 0.15]
ci_lower = [0.12, -0.05, 0.15, 0.02]
ci_upper = [0.78, 0.29, 0.52, 0.28]

y_pos = np.arange(len(effects))

# Plot effect sizes
for i, (val, lower, upper) in enumerate(zip(values, ci_lower, ci_upper)):
    ax.plot([lower, upper], [i, i], 'o-', color='black', linewidth=2)
    ax.plot(val, i, 'o', color='#E74C3C', markersize=10)
    # Shade null region
    if lower < 0 < upper:
        ax.axhspan(i-0.4, i+0.4, alpha=0.1, color='gray')

ax.set_yticks(y_pos)
ax.set_yticklabels(effects)
ax.axvline(0, color='black', linestyle='--', alpha=0.5)
ax.set_xlabel('Effect Size', fontsize=12, weight='bold')
ax.set_title('Effect Sizes with 95% Confidence Intervals', fontsize=14, weight='bold')
ax.grid(axis='x', alpha=0.3, linestyle='--')
plt.tight_layout()
plt.savefig('fig7_effect_sizes.pdf', dpi=300)
```

---

## Part III: Color Schemes

### Trinity Brand Colors

```python
TRINITY_COLORS = {
    'primary': '#E74C3C',      # Alizarin Red
    'secondary': '#3498DB',    # Blue
    'tertiary': '#2ECC71',     # Emerald Green
    'quaternary': '#9B59B6',   # Amethyst Purple
    'dark': '#2C3E50',         # Midnight Blue
    'light': '#ECF0F1',        # Clouds
    'accent': '#F39C12',       # Orange
    'highlight': '#E74C3C',    # Same as primary
}

# Sequential (for heatmaps)
SEQUENTIAL = ['#FEF5E7', '#FAD7A0', '#F4D03F', '#B7950B', '#6E2C00']

# Diverging (for centered data)
DIVERGING = ['#CA6F1E', '#F4D03F', '#FCF3CF', '#148FF4', '#1B4F72']
```

### Colorblind-Friendly Palette

```python
CB_FRIENDLY = {
    'blue': '#0072B2',
    'orange': '#D55E00',
    'green': '#009E73',
    'yellow': '#F0E442',
    'dark_blue': '#56B4E9',
    'dark_red': '#E69F00',
    'purple': '#CC79A7',
}
```

---

## Part IV: Font Guidelines

### Font Sizes

| Element | Size | Weight |
|---------|------|--------|
| **Title** | 14-16 pt | Bold |
| **Axis labels** | 10-12 pt | Bold |
| **Tick labels** | 9-10 pt | Normal |
| **Legend** | 9-10 pt | Normal |
| **Annotations** | 8-10 pt | Normal |

### Font Families

```python
# Use these fonts for consistency
plt.rcParams['font.family'] = 'serif'      # For LaTeX-like appearance
plt.rcParams['font.serif'] = ['Times New Roman', 'DejaVu Serif']
plt.rcParams['font.sans-serif'] = ['Arial', 'DejaVu Sans']
plt.rcParams['font.monospace'] = ['Courier New', 'DejaVu Sans Mono']

# Math fonts
plt.rcParams['mathtext.fontset'] = 'dejavuserif'
plt.rcParams['mathtext.default'] = 'it'
```

---

## Part V: Layout Guidelines

### Figure Sizing for Venues

| Venue | Column Width | Figure Width (1-col) | Figure Width (2-col) |
|-------|--------------|---------------------|---------------------|
| **NeurIPS** | 3.25 in | 3.25 in | 6.5 in |
| **ICLR** | 3.3 in | 3.3 in | 6.6 in |
| **MLSys** | 3.3 in | 3.3 in | 6.6 in |

```python
# Single column figure
fig, ax = plt.subplots(figsize=(3.25, 2.5))  # Width in inches

# Double column figure
fig, ax = plt.subplots(figsize=(6.5, 4))
```

### Subplots

```python
# 2x2 grid (square-ish)
fig, axes = plt.subplots(2, 2, figsize=(6, 5))

# 1x3 horizontal (timeline)
fig, axes = plt.subplots(1, 3, figsize=(10, 3))

# Vertical panels
fig, axes = plt.subplots(3, 1, figsize=(4, 10))
```

---

## Part VI: Common Mistakes to Avoid

### Visual Mistakes

❌ **DON'T:** Use 3D bar charts
✅ **DO:** Use 2D with clear labels

❌ **DON'T:** Use rainbow colormaps for sequential data
✅ **DO:** Use perceptually uniform colormaps (viridis, plasma)

❌ **DON'T:** Make figures too small to read
✅ **DO:** Test at actual column width

❌ **DON'T:** Use color as only encoding
✅ **DO:** Add shape/pattern for accessibility

❌ **DON'T:** Clutter with too much information
✅ **DO:** Split into multiple panels or supplementary

---

## Part VII: Accessibility

### Colorblind Accessibility

```python
# Check with colorblindness simulator
# Install: pip install colorvision
from colorvision import sim_colorblind

# Simulate deuteranopia (most common)
sim_colorblind('deuteranopia', 'fig1_architecture.pdf')
```

### Alternative Encodings

```python
# Use both color AND shape/line style
fig, ax = plt.subplots(figsize=(8, 5))

x = np.linspace(0, 10, 100)
ax.plot(x, np.sin(x), color='#E74C3C', linestyle='-', label='Sin', marker='o')
ax.plot(x, np.cos(x), color='#3498DB', linestyle='--', label='Cos', marker='s')
```

---

## Part VIII: Export Checklist

### Before Submitting

- [ ] All figures saved as PDF (vector) or PNG (300 DPI)
- [ ] File names follow convention: fig[N]_[name].pdf
- [ ] All text is readable at column width
- [ ] All axes labeled with units
- [ ] Legends included where needed
- [ ] Captions written separately (in paper)
- [ ] Colorblind-friendly (checked)
- [ ] Consistent style across all figures

### File Organization

```
paper/
├── figures/
│   ├── fig1_architecture.pdf
│   ├── fig2_results.pdf
│   ├── fig3_training.pdf
│   ├── fig4_ablation.pdf
│   ├── fig5_resources.pdf
│   ├── fig6_confusion.pdf
│   └── fig7_effects.pdf
└── supplementary/
    └── figures/
        ├── fig_s1_additional.pdf
        └── fig_s2_extended.pdf
```

---

**Document Version:** 1.0
**Last Updated:** 2026-03-26
**Status:** Ready for use
**Next Steps:** Apply guidelines to all Trinity publication figures
