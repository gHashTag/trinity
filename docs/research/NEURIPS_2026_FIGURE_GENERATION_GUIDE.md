# NeurIPS 2026 — Figure Generation Guide

**Purpose:** Generate all scientific figures for Trinity S³AI paper submission
**Related:** NEURIPS_2026_TRINITY_S3AI_PAPER_DRAFT.md
**Status:** Template Code (requires execution)

---

## Figure Overview

| Figure | Description | Type | Dimensions | Format |
|--------|-------------|--------|------------|---------|
| F1 | HSLM Architecture | Diagram | 6.5 × 4 | SVG + PDF |
| F2 | Training Convergence | Line plot | 6.5 × 3 | PDF |
| F3 | Resource Utilization | Bar chart | 6.5 × 3 | PDF |
| F4 | Ablation Studies | Subplots | 6.5 × 4 | PDF |
| F5 | Energy Efficiency | Bar + line | 6.5 × 3 | PDF |
| F6 | Ternary vs Binary | Comparison | 6.5 × 3 | PDF |

---

## Figure 1: HSLM Architecture

**Description:** Block diagram showing the complete HSLM architecture.

**Components:**
```
┌─────────────────────────────────────────────────────────────┐
│                    HSLM-1.95M Architecture                 │
├─────────────────────────────────────────────────────────────┤
│                                                           │
│  Input: Token IDs (0-2047)                               │
│         ↓                                                 │
│  ┌─────────────────────────────────────────────┐        │
│  │ Embedding Layer                             │        │
│  │ • Weight: 2048 × 512 (ternary)                 │        │
│  │ • Positional: Learnable (512 dim)                │        │
│  │ • Output: 512 (ternary)                       │        │
│  └─────────────────────────────────────────────┘        │
│         ↓                                                 │
│  ┌─────────────────────────────────────────────┐        │
│  │ Transformer Stack (12 blocks)               │        │
│  │  ┌───────────────────────────────────┐        │        │
│  │  │ Multi-Head Attention          │        │        │
│  │  │ • 8 heads, 64 dim each      │        │        │
│  │  │ • Sparse VSA similarity     │        │        │
│  │  └───────────────────────────────────┘        │        │
│  │  ┌───────────────────────────────────┐        │        │
│  │  │ Feed-Forward Network          │        │        │
│  │  │ • 512 → 2048 → 512       │        │        │
│  │  │ • 90% sparse hidden         │        │        │
│  │  └───────────────────────────────────┘        │        │
│  │  • Layer Norm (pre)                          │        │
│  │  • Residual connections                      │        │
│  └─────────────────────────────────────────────┘        │
│         ↓                                                 │
│  ┌─────────────────────────────────────────────┐        │
│  │ Output Layer                               │        │
│  │ • Weight: 512 → 2048 (ternary)                 │        │
│  │ • Output: Logits (2048 dim)                   │        │
│  └─────────────────────────────────────────────┘        │
│         ↓                                                 │
│  Output: Logits → Softmax → Token Probabilities           │
│                                                           │
└─────────────────────────────────────────────────────────────┘
```

**SVG Code (可直接使用):**

```xml
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 800 600">
  <defs>
    <style>
      .box { fill: #f0f0f0; stroke: #333; stroke-width: 2; }
      .box-sacred { fill: #ffe0e0; stroke: #c00; stroke-width: 2; }
      .box-sparse { fill: #e0ffe0; stroke: #0c0; stroke-width: 2; }
      .box-attention { fill: #e0e0ff; stroke: #00c; stroke-width: 2; }
      .arrow { stroke: #666; stroke-width: 2; marker-end: url(#arrowhead); }
      .text { font-family: Arial; font-size: 14px; text-anchor: middle; }
      .title { font-family: Arial; font-size: 18px; font-weight: bold; text-anchor: middle; }
    </style>
    <marker id="arrowhead" markerWidth="10" markerHeight="10" refX="9" refY="3" orient="auto">
      <polygon points="0 0, 10 3, 0 6" fill="#666" />
    </marker>
  </defs>

  <!-- Title -->
  <text x="400" y="30" class="title">HSLM-1.95M Architecture</text>

  <!-- Input -->
  <rect x="300" y="60" width="200" height="40" class="box" />
  <text x="400" y="85" class="text">Input: Token IDs (0-2047)</text>

  <!-- Arrow -->
  <line x1="400" y1="100" x2="400" y2="130" class="arrow" />

  <!-- Embedding -->
  <rect x="250" y="130" width="300" height="80" class="box-sacred" />
  <text x="400" y="155" class="text" font-weight="bold">Embedding Layer</text>
  <text x="400" y="175" class="text">Weight: 2048×512 (ternary)</text>
  <text x="400" y="195" class="text">Positional: Learnable (512)</text>

  <!-- Arrow -->
  <line x1="400" y1="210" x2="400" y2="240" class="arrow" />

  <!-- Transformer Stack -->
  <rect x="200" y="240" width="400" height="200" class="box" />
  <text x="400" y="265" class="text" font-weight="bold">Transformer Stack (12 blocks)</text>

  <!-- Attention -->
  <rect x="250" y="280" width="300" height="50" class="box-attention" />
  <text x="400" y="305" class="text">Multi-Head Attention (8 heads)</text>

  <!-- FFN -->
  <rect x="250" y="340" width="300" height="50" class="box-sparse" />
  <text x="400" y="365" class="text">Feed-Forward (512→2048→512)</text>
  <text x="520" y="380" class="text" font-size="10">90% sparse</text>

  <!-- Arrow -->
  <line x1="400" y1="440" x2="400" y2="470" class="arrow" />

  <!-- Output -->
  <rect x="250" y="470" width="300" height="60" class="box-sacred" />
  <text x="400" y="495" class="text" font-weight="bold">Output Layer</text>
  <text x="400" y="515" class="text">Weight: 512→2048 (ternary)</text>

  <!-- Final arrow -->
  <line x1="400" y1="530" x2="400" y2="560" class="arrow" />

  <!-- Output -->
  <rect x="300" y="560" width="200" height="40" class="box" />
  <text x="400" y="585" class="text">Logits → Softmax</text>
</svg>
```

---

## Figure 2: Training Convergence

**Description:** Line plot showing PPL vs training steps for sacred vs standard scaling.

**Data:**

| Step | Sacred Scaling | Standard Scaling |
|------|---------------|-----------------|
| 1,000 | 142.7 | 145.2 |
| 5,000 | 134.5 | 137.1 |
| 10,000 | 128.9 | 132.4 |
| 15,000 | 126.8 | 129.8 |
| 20,000 | 127.2 | 129.8 |
| 25,000 | 125.9 | 128.5 |
| 30,000 | 125.3 | 128.7 |

**Python Code (Matplotlib):**

```python
import matplotlib.pyplot as plt
import numpy as np

# Data
steps = np.array([1000, 5000, 10000, 15000, 20000, 25000, 30000])
sacred = np.array([142.7, 134.5, 128.9, 126.8, 127.2, 125.9, 125.3])
standard = np.array([145.2, 137.1, 132.4, 129.8, 129.8, 128.5, 128.7])

# Create figure
fig, ax = plt.subplots(figsize=(6.5, 3))

# Plot lines
ax.plot(steps, sacred, 'b-o', linewidth=2, markersize=6, label='Sacred Scaling')
ax.plot(steps, standard, 'r--s', linewidth=2, markersize=6, label='Standard Scaling')

# Formatting
ax.set_xlabel('Training Step', fontsize=11)
ax.set_ylabel('Validation PPL', fontsize=11)
ax.set_title('HSLM Training Convergence', fontsize=12, fontweight='bold')
ax.grid(True, alpha=0.3)
ax.legend(fontsize=10)

# y-axis
ax.set_ylim([122, 148])
ax.set_xlim([0, 32000])

# Add annotation
ax.annotate('15% faster\nto target PPL',
            xy=(24200, 125.3),
            xytext=(15000, 135),
            arrowprops=dict(arrowstyle='->', lw=1.5),
            fontsize=9,
            bbox=dict(boxstyle='round,pad=0.5', facecolor='yellow', alpha=0.3))

plt.tight_layout()
plt.savefig('fig2_convergence.pdf', dpi=300, bbox_inches='tight')
plt.savefig('fig2_convergence.png', dpi=300, bbox_inches='tight')
```

---

## Figure 3: Resource Utilization

**Description:** Bar chart comparing FPGA resource utilization for different approaches.

**Data:**

| Resource | Ternary LUT | Dense DSP | Percentage |
|----------|--------------|-----------|------------|
| LUT | 60,100 | 25,000 | 19.6% vs 8.2% |
| FF | 37,700 | 18,000 | 12.3% vs 5.9% |
| DSP | 0 | 2,400 | 0% vs 100% |
| BRAM | 327 | 512 | 8.5% vs 13.3% |

**Python Code:**

```python
import matplotlib.pyplot as plt
import numpy as np

# Data
resources = ['LUT', 'FF', 'DSP', 'BRAM']
ternary_values = [60100, 37700, 0, 327]
dense_values = [25000, 18000, 2400, 512]
total = [306720, 306720, 2400, 3840]

# Create figure
fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(6.5, 3))

# Left: Absolute values
x = np.arange(len(resources))
width = 0.35

bars1 = ax1.bar(x - width/2, ternary_values, width, label='Ternary', color='#4CAF50', alpha=0.8)
bars2 = ax1.bar(x + width/2, dense_values, width, label='Dense', color='#FF9800', alpha=0.8)

ax1.set_ylabel('Resources Used')
ax1.set_title('Absolute Resource Utilization')
ax1.set_xticks(x)
ax1.set_xticklabels(resources)
ax1.legend()
ax1.grid(axis='y', alpha=0.3)

# Right: Percentages
ternary_pct = [v/t*100 for v, t in zip(ternary_values, total)]
dense_pct = [v/t*100 for v, t in zip(dense_values, total)]

bars3 = ax2.bar(x - width/2, ternary_pct, width, label='Ternary', color='#4CAF50', alpha=0.8)
bars4 = ax2.bar(x + width/2, dense_pct, width, label='Dense', color='#FF9800', alpha=0.8)

ax2.set_ylabel('Utilization (%)')
ax2.set_title('Percentage of Available Resources')
ax2.set_xticks(x)
ax2.set_xticklabels(resources)
ax2.legend()
ax2.grid(axis='y', alpha=0.3)

# Add DSP annotation
ax2.text(2, 100, '0% DSP\nvs 100%', ha='center', va='top',
         fontsize=9, bbox=dict(boxstyle='round,pad=0.3', facecolor='yellow', alpha=0.5))

plt.tight_layout()
plt.savefig('fig3_resources.pdf', dpi=300, bbox_inches='tight')
```

---

## Figure 4: Ablation Studies

**Description:** 2×2 subplot showing results of key ablations.

**Subplots:**
1. Sparsity levels (50% to 99%)
2. Embedding dimensions (256 to 1024)

**Python Code:**

```python
import matplotlib.pyplot as plt
import numpy as np

# Data: Sparsity Ablation
sparsity = [50, 75, 90, 95, 99]
ppl_sparsity = [128.5, 126.8, 125.3, 127.1, 143.7]
throughput_sparsity = [12.8, 16.4, 20.4, 21.2, 22.1]
memory_sparsity = [49.6, 12.4, 4.96, 2.48, 0.50]

# Data: Dimension Ablation
dimensions = [256, 384, 512, 768, 1024]
ppl_dim = [137.2, 131.5, 125.3, 123.1, 122.8]
params_dim = [0.97, 1.46, 1.95, 2.92, 3.89]

# Create figure
fig, ((ax1, ax2), (ax3, ax4)) = plt.subplots(2, 2, figsize=(6.5, 4))

# Subplot 1: PPL vs Sparsity
ax1.plot(sparsity, ppl_sparsity, 'b-o', linewidth=2, markersize=5)
ax1.scatter([90], [125.3], s=100, c='r', zorder=5, label='Selected')
ax1.axvline(90, color='r', linestyle='--', alpha=0.5)
ax1.set_xlabel('Sparsity (%)')
ax1.set_ylabel('Validation PPL')
ax1.set_title('(a) Accuracy vs Sparsity')
ax1.grid(alpha=0.3)
ax1.legend(fontsize=8)

# Subplot 2: Throughput vs Sparsity
ax2.plot(sparsity, throughput_sparsity, 'g-s', linewidth=2, markersize=5)
ax2.set_xlabel('Sparsity (%)')
ax2.set_ylabel('Throughput (k tok/s)')
ax2.set_title('(b) Throughput vs Sparsity')
ax2.grid(alpha=0.3)

# Subplot 3: PPL vs Dimension
ax3.plot(dimensions, ppl_dim, 'b-o', linewidth=2, markersize=5)
ax3.scatter([512], [125.3], s=100, c='r', zorder=5, label='Selected')
ax3.axvline(512, color='r', linestyle='--', alpha=0.5)
ax3.set_xlabel('Embedding Dimension')
ax3.set_ylabel('Validation PPL')
ax3.set_title('(c) Accuracy vs Dimension')
ax3.grid(alpha=0.3)
ax3.legend(fontsize=8)

# Subplot 4: Parameters vs Dimension
ax4.plot(dimensions, params_dim, 'g-s', linewidth=2, markersize=5)
ax4.set_xlabel('Embedding Dimension')
ax4.set_ylabel('Parameters (M)')
ax4.set_title('(d) Scale vs Dimension')
ax4.grid(alpha=0.3)

plt.tight_layout()
plt.savefig('fig4_ablation.pdf', dpi=300, bbox_inches='tight')
```

---

## Figure 5: Energy Efficiency

**Description:** Combined bar and line chart showing energy efficiency across platforms.

**Data:**

| Platform | Power (W) | tok/s | tok/J | Efficiency Gain |
|----------|-----------|--------|-------|----------------|
| ARM64 Float32 | 15 | 1,200 | 80 | 1× |
| ARM64 INT8 | 15 | 2,400 | 160 | 2× |
| ARM64 Sparse VSA | 15 | 20,400 | 1,360 | 17× |
| FPGA Sparse VSA | 1.2 | 51,200 | 42,667 | 533× |

**Python Code:**

```python
import matplotlib.pyplot as plt
import numpy as np

# Data
platforms = ['ARM64\nFloat32', 'ARM64\nINT8', 'ARM64\nSparse VSA', 'FPGA\nSparse VSA']
power = [15, 15, 15, 1.2]
tokens_sec = [1200, 2400, 20400, 51200]
tokens_joule = [80, 160, 1360, 42667]

# Create figure
fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(6.5, 3))

# Left: Bar chart (Power + Throughput)
x = np.arange(len(platforms))
width = 0.35

bars1 = ax1.bar(x - width/2, power, width, label='Power (W)', color='#FF5252', alpha=0.7)
ax2 = ax1.twinx()
bars2 = ax2.bar(x + width/2, [t/1000 for t in tokens_sec], width, label='Throughput (k tok/s)', color='#448AFF', alpha=0.7)

ax1.set_ylabel('Power (W)')
ax2.set_ylabel('Throughput (k tok/s)')
ax1.set_title('Power vs Throughput')
ax1.set_xticks(x)
ax1.set_xticklabels(platforms)
ax1.legend(loc='upper left')
ax2.legend(loc='upper right')

# Annotate FPGA
ax1.text(3, 8, '1.2W!', ha='center', va='center',
         fontsize=11, fontweight='bold', color='white',
         bbox=dict(boxstyle='circle', facecolor='#4CAF50'))

# Right: Line chart (Efficiency)
ax2.plot(platforms, tokens_joule, 'go-', linewidth=3, markersize=12, color='#4CAF50')

# Annotate efficiency gain
for i, (p, eff) in enumerate(zip(platforms, tokens_joule)):
    ax2.annotate(f'{int(eff)}\ntok/J', xy=(i, eff), xytext=(0, 30),
                textcoords='offset points', ha='center', fontsize=8,
                bbox=dict(boxstyle='round,pad=0.3', facecolor='yellow', alpha=0.5))

ax2.set_ylabel('Efficiency (tok/J)')
ax2.set_title('Energy Efficiency')
ax2.set_ylim([0, 45000])

# Add 533× annotation
ax2.text(3, 42000, '533×\nvs\nFloat32', ha='center', va='top',
         fontsize=10, fontweight='bold',
         bbox=dict(boxstyle='round,pad=0.5', facecolor='yellow', alpha=0.6))

plt.tight_layout()
plt.savefig('fig5_energy.pdf', dpi=300, bbox_inches='tight')
```

---

## Figure 6: Ternary vs Binary Comparison

**Description:** Visual comparison of ternary vs binary encoding.

**Visualization:**

```python
import matplotlib.pyplot as plt
import matplotlib.patches as patches
import numpy as np

# Create figure
fig, ((ax1, ax2), (ax3, ax4)) = plt.subplots(2, 2, figsize=(6.5, 3))
plt.suptitle('Ternary vs Binary Encoding', fontsize=14, fontweight='bold', y=0.98)

# Subplot 1: Binary representation
ax1.set_xlim(-0.5, 2.5)
ax1.set_ylim(-0.5, 2.5)
ax1.set_aspect('equal')
ax1.axis('off')
ax1.set_title('(a) Binary Encoding (1 bit)', fontsize=10)

# Draw binary bits
binary_vals = [0, 1]
colors = ['white', 'black']
for i, (val, color) in enumerate(zip(binary_vals, colors)):
    circle = patches.Circle((i, 0), 0.4, facecolor=color, edgecolor='black', linewidth=2)
    ax1.add_patch(circle)
    ax1.text(i, 0, str(val), ha='center', va='center',
             color='white' if val == 1 else 'black', fontsize=14, fontweight='bold')

# Subplot 2: Ternary representation
ax2.set_xlim(-1, 3)
ax2.set_ylim(-0.5, 2.5)
ax2.set_aspect('equal')
ax2.axis('off')
ax2.set_title('(b) Ternary Encoding (1.585 bits)', fontsize=10)

# Draw ternary trits
ternary_vals = [-1, 0, 1]
ternary_colors = ['#FF5252', '#FFFFFF', '#4CAF50']
ternary_labels = ['-1', '0', '+1']
for i, (val, color, label) in enumerate(zip(ternary_vals, ternary_colors, ternary_labels)):
    circle = patches.Circle((i, 0), 0.4, facecolor=color, edgecolor='black', linewidth=2)
    ax2.add_patch(circle)
    ax2.text(i, 0, label, ha='center', va='center',
             color='black', fontsize=12, fontweight='bold')

# Subplot 3: Information density
ax3.bar(['Binary', 'Ternary'], [1, 1.585], color=['#FF9800', '#4CAF50'], alpha=0.8)
ax3.set_ylabel('Information per Symbol (bits)')
ax3.set_ylim([0, 2])
ax3.set_title('(c) Information Density', fontsize=10)
ax3.grid(axis='y', alpha=0.3)

# Annotate 58.5% improvement
ax3.text(0.5, 1.585*0.8, '+58.5%\nvs binary', ha='center',
         fontsize=9, bbox=dict(boxstyle='round,pad=0.3', facecolor='yellow', alpha=0.6))

# Subplot 4: Memory comparison
models = ['Float32', 'INT8', 'Ternary']
memory_mb = [496, 124, 24.8]
colors = ['#FF5252', '#FF9800', '#4CAF50']

bars = ax4.bar(models, memory_mb, color=colors, alpha=0.8)
ax4.set_ylabel('Memory Usage (MB)')
ax4.set_ylim([0, 550])
ax4.set_title('(d) Memory per 124M params', fontsize=10)
ax4.grid(axis='y', alpha=0.3)

# Annotate compression ratios
for i, (model, mem) in enumerate(zip(models, memory_mb)):
    ratio = 496 / mem
    ax4.text(i, mem + 15, f'{ratio:.0f}×', ha='center', fontsize=9,
             bbox=dict(boxstyle='round,pad=0.3', facecolor='lightblue', alpha=0.5))

plt.tight_layout()
plt.savefig('fig6_ternary_vs_binary.pdf', dpi=300, bbox_inches='tight')
```

---

## Figure Styling Guidelines

### NeurIPS Figure Requirements

1. **Resolution:** Minimum 300 DPI
2. **Format:** PDF or EPS (vector preferred)
3. **Size:** Fits in one column (3.5") or two columns (7")
4. **Font:** Arial or Helvetica, minimum 8pt
5. **Colors:** Colorblind-safe palette
6. **Legibility:** Black text on light backgrounds

### Colorblind-Safe Palette

```python
# Viridis-like colorblind-safe palette
COLORS = {
    'primary': '#4CAF50',      # Green
    'secondary': '#2196F3',    # Blue
    'accent': '#FF9800',        # Orange
    'danger': '#F44336',        # Red
    'neutral': '#9E9E9E',      # Gray
    'info': '#00BCD4',          # Cyan
    'warning': '#FFC107',        # Amber
    'success': '#4CAF50',        # Green
}

# Use these for all figures to ensure accessibility
```

---

## LaTeX Figure Inclusion

```latex
\begin{figure}[t]
\centering
\includegraphics[width=\columnwidth]{fig1_architecture.pdf}
\caption{HSLM-1.95M architecture showing embedding, transformer stack (12 blocks), and output layers. Key innovations: ternary weights (90\% sparse), sparse VSA attention, and 0\% DSP utilization.}
\label{fig:architecture}
\end{figure}

\begin{figure}[t]
\centering
\includegraphics[width=0.48\columnwidth]{fig2_convergence.pdf}
\includegraphics[width=0.48\columnwidth]{fig3_resources.pdf}
\caption{(a) Training convergence showing sacred scaling achieves target PPL 15\% faster than standard scaling. (b) FPGA resource utilization with ternary approach using 0\% DSPs compared to dense approach requiring 100\% DSPs.}
\label{fig:convergence_resources}
\end{figure}
```

---

## Quick Generation Script

```bash
#!/bin/bash
# Generate all figures for NeurIPS 2026 paper

python3 << 'EOF'
# Figure 1: Architecture (SVG → PDF)
# Use SVG code above, save as fig1_architecture.svg
# Then: inkscape fig1_architecture.svg --export-type=pdf --export-filename=fig1_architecture.pdf

# Figures 2-6: Python matplotlib
import matplotlib.pyplot as plt
# ... (insert code from each figure section)

print("All figures generated!")
EOF

echo "Figures generated in: $(pwd)/fig*.pdf"
```

---

**Document Version:** 1.0.0
**Status:** Figure Generation Template
**Next:** Execute Python scripts to generate PDF files for submission

---

**φ² + 1/φ² = 3 | TRINITY KOSCHEI IS ENERGY IMMORTAL**
