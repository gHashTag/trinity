# Zenodo Figures & Diagrams Guide — Trinity v5.2

**Date:** 2026-03-26
**Purpose:** Guide for creating publication-ready figures for Zenodo bundles

---

## 1. Figure Specifications

### 1.1 Format Requirements

| Property | Requirement |
|----------|-------------|
| Format | PNG or PDF (vector preferred) |
| Resolution | 300 DPI minimum |
| Color | RGB (CMYK for print) |
| Width | 800-3200 pixels (for web) |
| Font | Sans-serif (Arial, Helvetica, or similar) |
| File size | < 5 MB per figure |

### 1.2 Figure Templates

```python
import matplotlib.pyplot as plt
import numpy as np

# Trinity color scheme
GOLD = '#D4AF37'    # φ golden
CYAN = '#00CED1'    # Sacred blue
MAGENTA = '#FF00FF' # Innovation
BLACK = '#000000'
WHITE = '#FFFFFF'

plt.style.use('seaborn-v0_8-darkgrid')
plt.rcParams['figure.facecolor'] = '#1e1e1e'
plt.rcParams['text.color'] = WHITE
```

---

## 2. Required Figures by Bundle

### B001: Ternary Neural Networks

**Figure 1: HSLM Architecture**
```
Content: Layer stack diagram with data flow
Size: 1200×800
Elements: Embedding, 9 Transformer blocks, Output layer
Labels: Layer names, dimensions, data types
```

**Figure 2: Ternary vs Binary Comparison**
```
Content: Bar chart comparing metrics
Metrics: Memory, PPL, Inference speed
X-axis: FP32, BF16, IEEE f16, GF16, TF3
Y-axis: Normalized value (log scale where appropriate)
```

**Figure 3: Training Curves**
```
Content: Loss and PPL vs training steps
X-axis: Training steps (0-50K)
Y-axis: Loss (left), PPL (right)
```

### B002: Zero-DSP FPGA

**Figure 1: FPGA Floorplan**
```
Content: XC7A100T die utilization
Elements: LUT regions, BRAM blocks, I/O ports
Colors: Used (blue), Available (gray)
```

**Figure 2: DSP Comparison**
```
Content: Bar chart of resource usage
Metrics: DSP48E1, LUT, BRAM, Power
X-axis: FP32, BF16, GF16, TF3
Y-axis: Resource count (log scale)
```

**Figure 3: Synthesis Flow**
```
Content: Pipeline diagram
Steps: Zig → Verilog → Yosys → nextpnr → Bitstream
```

### B003: TRI-27 ISA

**Figure 1: Register File Layout**
```
Content: 3-bank register organization
Banks: Alpha (α-η), Iota (ι-ρ), Sigma (σ-ϡ)
Registers: 9 per bank, color-coded by bank
```

**Figure 2: Instruction Encoding**
```
Content: 48-bit instruction format breakdown
Fields: Opcode (8), operands (24), flags (8), reserved (8)
```

**Figure 3: Assembly Example**
```
Content: Source assembly → Binary encoding
Example: sum 1 to 10 program
```

### B004: Queen Lotus Cycle

**Figure 1: 6-Phase State Machine**
```
Content: Circular state diagram
Phases: DIAGNOSE → PLAN → ACT → VERIFY → MEASURE → PERSIST
Edges: Labeled with conditions
```

**Figure 2: Episode Memory Structure**
```
Content: Episode buffer layout
Fields: ID, timestamp, state, action, reward, quality
Size: 847 episodes visualization
```

**Figure 3: Retrieval Accuracy vs Threshold**
```
Content: Line plot of F1, Precision, Recall vs Jaccard threshold
X-axis: Threshold (0.0-1.0)
Y-axis: Metric value (0-1)
```

### B005: Tri Language

**Figure 1: Type System Hierarchy**
```
Content: Class diagram of core types
Types: Linear (Let, Inout, Sink, Set), Effects, Patterns
```

**Figure 2: Compilation Pipeline**
```
Content: .tri → Zig → Binary / .tri → Verilog → Bitstream
```

**Figure 3: Code Generation Example**
```
Content: Side-by-side comparison
Left: Tri source code
Right: Generated Zig/Verilog
```

### B006: Sacred GF16/TF3

**Figure 1: Bit Layout Comparison**
```
Content: Visual comparison of bit layouts
Formats: FP32, BF16, GF16, TF3
Colors: Sign (red), Exponent (green), Mantissa (blue)
```

**Figure 2: Phi-Distance Heatmap**
```
Content: Heatmap of φ-distance vs bit distributions
X-axis: Exponent bits (1-14)
Y-axis: Mantissa bits (1-14)
Color: Distance (green=low, red=high)
```

**Figure 3: Round-Trip Error Distribution**
```
Content: Histogram of quantization errors
X-axis: Error magnitude
Y-axis: Frequency
```

### B007: VSA Operations

**Figure 1: HybridBigInt Structure**
```
Content: SIMD vector layout
Elements: 32 limbs, 16 trits per limb
```

**Figure 2: VSA Operation Truth Tables**
```
Content: 3 tables (Bind, Bundle, Permute)
Format: Grid with trit values {-1,0,+1}
```

**Figure 3: SIMD Speedup Comparison**
```
Content: Bar chart of speedup factors
Operations: Bind, Bundle, Cosine, Permute
X-axis: Scalar vs SIMD
Y-axis: Speedup (×)
```

---

## 3. Python Figure Generation Code

### B001: HSLM Architecture Diagram

```python
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
from matplotlib.patches import FancyBboxPatch, FancyArrowPatch

fig, ax = plt.subplots(figsize=(12, 8))

# Colors
GOLD = '#D4AF37'
CYAN = '#00CED1'
MAGENTA = '#FF00FF'
BLACK = '#000000'
WHITE = '#FFFFFF'

ax.set_facecolor('#1e1e1e')
ax.set_xlim(0, 10)
ax.set_ylim(0, 10)
ax.axis('off')

# Title
ax.text(5, 9.5, 'HSLM-1.95M Architecture',
        fontsize=16, ha='center', color=WHITE, weight='bold')

# Input
input_box = FancyBboxPatch((0.5, 8), (2, 9.5), boxstyle="round,pad=0.1",
                           edgecolor=CYAN, facecolor='#003333')
ax.add_patch(input_box)
ax.text(1.25, 8.75, 'Input\n"TinyStories"',
        ha='center', va='center', color=WHITE, fontsize=10)

# Embedding
embed_box = FancyBboxPatch((2.5, 8), (4, 9.5), boxstyle="round,pad=0.1",
                             edgecolor=GOLD, facecolor='#332800')
ax.add_patch(embed_box)
ax.text(3.25, 8.75, 'Embedding\n2048→192\n78 KB',
        ha='center', va='center', color=WHITE, fontsize=9)

# Arrow 1
arrow1 = FancyArrowPatch((4, 8.75), (4.5, 8.75), mutation_scale=20,
                         color=WHITE, arrowstyle='->', linewidth=2)
ax.add_patch(arrow1)

# Transformer Blocks
for i in range(9):
    x_start = 4.5 + i * 0.5
    box = FancyBboxPatch((x_start, 6.5), (x_start + 0.4, 8),
                         boxstyle="round,pad=0.02", edgecolor=MAGENTA, facecolor='#330033')
    ax.add_patch(box)
    ax.text(x_start + 0.2, 7.25, f'T{i+1}', ha='center', va='center',
            color=WHITE, fontsize=8)

# Output
output_box = FancyBboxPatch((9, 8), (10, 9.5), boxstyle="round,pad=0.1",
                              edgecolor=CYAN, facecolor='#003333')
ax.add_patch(output_box)
ax.text(9.5, 8.75, 'Output\n2048 logits',
        ha='center', va='center', color=WHITE, fontsize=10)

# Legend
legend_elements = [
    mpatches.Patch(color=GOLD, label='Memory (385 KB)'),
    mpatches.Patch(color=CYAN, label='I/O'),
    mpatches.Patch(color=MAGENTA, label='Compute (0 DSP)'),
]
ax.legend(handles=legend_elements, loc='lower center',
           facecolor='#1e1e1e', labelcolor=WHITE, fontsize=9)

plt.tight_layout()
plt.savefig('figures/B001_hslm_architecture.png', dpi=300, bbox_inches='tight',
            facecolor='#1e1e1e')
plt.close()
```

### B002: Resource Comparison

```python
import matplotlib.pyplot as plt
import numpy as np

fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(14, 6))

# Data
formats = ['FP32', 'BF16', 'IEEE f16', 'GF16', 'TF3']
lut = [31.4, 19.6, 22.1, 19.6, 15.2]
dsp = [100, 50, 100, 0, 0]
power = [2.8, 1.9, 2.5, 1.2, 0.8]

# LUT comparison
bars1 = ax1.bar(formats, lut, color=[('#ff6b6b' if x == max(lut) else '#4ecdc4' for x in lut])
ax1.set_ylabel('LUT Utilization (%)', color=WHITE)
ax1.set_title('FPGA Resource Comparison', color=WHITE, weight='bold')
ax1.set_facecolor('#1e1e1e')
ax1.tick_params(colors=WHITE)
for i, v in enumerate(lut):
    ax1.text(i, v + 0.5, f'{v}%', ha='center', color=WHITE, fontsize=10)

# DSP comparison
bars2 = ax2.bar(formats, dsp, color=[('#ff6b6b' if x == max(dsp) else '#4ecdc4' for x in dsp])
ax2.set_ylabel('DSP48E1 Usage (%)', color=WHITE)
ax2.set_facecolor('#1e1e1e')
ax2.tick_params(colors=WHITE)
for i, v in enumerate(dsp):
    ax2.text(i, v + 2, f'{v}%' if v > 0 else '0%', ha='center', color=WHITE, fontsize=10)

plt.tight_layout()
plt.savefig('figures/B002_resource_comparison.png', dpi=300, bbox_inches='tight',
            facecolor='#1e1e1e')
plt.close()
```

### B003: Register File Layout

```python
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
from matplotlib.patches import Rectangle

fig, ax = plt.subplots(figsize=(12, 8))

# Bank colors
alpha_color = '#FF6B6B'  # Red
iota_color = '#4ECDC4'   # Green
sigma_color = '#45B7D1'   # Blue

ax.set_xlim(0, 10)
ax.set_ylim(0, 4)
ax.axis('off')
ax.set_facecolor('#1e1e1e')

# Title
ax.text(5, 3.5, 'TRI-27 Register File: 3-Bank Organization',
        ha='center', color=WHITE, fontsize=14, weight='bold')

# Alpha bank (α-η)
for i in range(9):
    rect = Rectangle((0.5 + i * 0.9, 2.5), 0.8, 0.4,
                       edgecolor=alpha_color, facecolor=alpha_color, alpha=0.3)
    ax.add_patch(rect)
    ax.text(0.9 + i * 0.9, 2.7, f'R{i}', ha='center', color=WHITE, fontsize=8)

# Iota bank (ι-ρ)
for i in range(9):
    rect = Rectangle((0.5 + i * 0.9, 1.7), 0.8, 0.4,
                       edgecolor=iota_color, facecolor=iota_color, alpha=0.3)
    ax.add_patch(rect)
    ax.text(0.9 + i * 0.9, 1.9, f'R{i+9}', ha='center', color=WHITE, fontsize=8)

# Sigma bank (σ-ϡ)
for i in range(9):
    rect = Rectangle((0.5 + i * 0.9, 0.9), 0.8, 0.4,
                       edgecolor=sigma_color, facecolor=sigma_color, alpha=0.3)
    ax.add_patch(rect)
    ax.text(0.9 + i * 0.9, 1.1, f'R{i+18}', ha='center', color=WHITE, fontsize=8)

# Bank labels
ax.text(2.5, 3.3, 'Alpha (α-η)', ha='center', color=alpha_color, fontsize=11, weight='bold')
ax.text(5, 3.3, 'Iota (ι-ρ)', ha='center', color=iota_color, fontsize=11, weight='bold')
ax.text(7.5, 3.3, 'Sigma (σ-ϡ)', ha='center', color=sigma_color, fontsize=11, weight='bold')

# Legend
legend_elements = [
    mpatches.Patch(facecolor=alpha_color, alpha=0.5, label='Alpha (α-η): R0-R8'),
    mpatches.Patch(facecolor=iota_color, alpha=0.5, label='Iota (ι-ρ): R9-R17'),
    mpatches.Patch(facecolor=sigma_color, alpha=0.5, label='Sigma (σ-ϡ): R18-R26'),
]
ax.legend(handles=legend_elements, loc='upper right',
           facecolor='#1e1e1e', labelcolor=WHITE, fontsize=10)

plt.tight_layout()
plt.savefig('figures/B003_register_layout.png', dpi=300, bbox_inches='tight',
            facecolor='#1e1e1e')
plt.close()
```

### B004: Lotus Cycle State Machine

```python
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
from matplotlib.patches import FancyArrowPatch, Circle

fig, ax = plt.subplots(figsize=(10, 10))

# State positions in circle
states = [
    ('DIAGNOSE', 0, 8, '#FF6B6B'),
    ('PLAN', 7, 4, '#4ECDC4'),
    ('ACT', 7, 0, '#45B7D1'),
    ('VERIFY', 3, 0, '#96CEB4'),
    ('MEASURE', 0, 4, '#D4AF37'),
    ('PERSIST', 0, 8, '#FF9F80'),
]

# Draw circle
circle = Circle((5, 4), 3.5, fill=False, edgecolor=WHITE, linewidth=2)
ax.add_patch(circle)

# Draw states and edges
for state, x, y, color in states:
    # State circle
    state_circle = Circle((x, y), 0.8, facecolor=color, edgecolor=WHITE, linewidth=2)
    ax.add_patch(state_circle)
    ax.text(x, y, state[:4].upper(), ha='center', va='center',
            color=WHITE, fontsize=9, weight='bold')

# Add transitions (arrows)
transitions = [
    (0, 1),  # DIAGNOSE → PLAN
    (1, 2),  # PLAN → ACT
    (2, 3),  # ACT → VERIFY
    (3, 4),  # VERIFY → MEASURE
    (4, 5),  # MEASURE → PERSIST
    (5, 0),  # PERSIST → DIAGNOSE
]

for start, end in transitions:
    x1, y1 = states[start][1], states[start][2]
    x2, y2 = states[end][1], states[end][2]
    arrow = FancyArrowPatch((x1, y1), (x2, y2), mutation_scale=15,
                            color=WHITE, arrowstyle='->', linewidth=1.5, connectionstyle='arc3,rad=0.3')
    ax.add_patch(arrow)

ax.set_xlim(-1, 11)
ax.set_ylim(-1, 11)
ax.axis('off')
ax.set_facecolor('#1e1e1e')
ax.set_title('Queen Lotus Cycle: 6-Phase State Machine',
        color=WHITE, fontsize=14, weight='bold', pad=20)

plt.tight_layout()
plt.savefig('figures/B004_lotus_cycle.png', dpi=300, bbox_inches='tight',
            facecolor='#1e1e1e')
plt.close()
```

---

## 4. Video Demonstration Guide

### 4.1 Recommended Videos

| Bundle | Video Title | Duration | Content |
|--------|------------|----------|---------|
| B001 | HSLM Inference Demo | 2-3 min | Live text generation |
| B002 | FPGA Synthesis Demo | 3-5 min | Yosys→nextpnr→Bitstream |
| B003 | TRI-27 Assembly Demo | 2-3 min | Assembly→execution |
| B004 | Queen Learning Demo | 3-4 min | Episode retrieval visualization |
| B005 | Tri Codegen Demo | 2-3 min | .tri→Zig/Verilog |
| B006 | GF16 Round-Trip Demo | 1-2 min | Conversion visualization |
| B007 | VSA Operations Demo | 2-3 min | SIMD speedup visualization |

### 4.2 Video Recording Tips

**Tools:**
- OBS Studio (cross-platform)
- QuickTime (macOS)
- Windows Game Bar (Windows)

**Settings:**
- Resolution: 1920×1080 minimum
- Frame rate: 30 FPS
- Audio: Clear voiceover (optional)
- Cursor: Visible when clicking

**Editing:**
- Add intro/outro slides with Trinity branding
- Include command-line terminal for technical demos
- Add timestamps for key sections
- Export as MP4 (H.264 codec)

### 4.3 Video Script Template

```
[INTRO - 5 seconds]
Title: Trinity B001: Ternary Neural Networks
Subtitle: HSLM-1.95M Inference Demonstration
Trinity S³AI Framework v5.2

[DEMO - 2-3 minutes]
Show terminal with:
./zig-out/bin/hslm-inference --checkpoint model_50000.bin

[EXPLANATION - 30 seconds]
Voiceover explaining:
- 1.95M parameters
- 385 KB model size
- 1200 tokens/second
- Zero DSP blocks required

[OUTRO - 5 seconds]
- DOI: 10.5281/zenodo.19227733
- GitHub: https://github.com/gHashTag/trinity
- φ² + 1/φ² = 3
```

---

## 5. Automated Figure Generation

### 5.1 Setup

```bash
cd /path/to/trinity
mkdir -p figures
python3 -m venv .venv
source .venv/bin/activate
pip install matplotlib seaborn numpy
```

### 5.2 Generate All Figures

```bash
python3 scripts/generate_zenodo_figures.py
# Creates all figures in figures/ directory
```

### 5.3 Upload to Zenodo

```bash
# Via Zenodo web UI:
1. Go to https://zenodo.org/deposit
2. Upload figure files
3. Add to each bundle record
```

---

**φ² + 1/φ² = 3 | TRINITY**
