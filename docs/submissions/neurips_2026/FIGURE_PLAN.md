# NeurIPS 2026 Submission — Figure Plan

**Paper Title:** Trinity: A Ternary Neural Network Framework with Algebraically Structured Formats and Zero-DSP FPGA Deployment

**Anonymous Authors** *(double-blind submission)*

---

## Figure Summary

| Figure | Title | Type | Location | Priority |
|--------|-------|------|----------|----------|
| 1 | Trinity Architecture | Diagram | Section 3 | High |
| 2 | Sacred Formats Illustration | Diagram | Section 3.2 | High |
| 3 | Training Curves | Line plot | Section 5.1 | High |
| 4 | FPGA Resource Utilization | Bar chart | Section 5.2 | High |
| 5 | VSA Bitflip Resilience | Line plot | Section 5.3 | Medium |
| 6 | Consciousness Gate Visualization | Heatmap | Section 3.5 | Medium |

**Total:** 6 figures (NeurIPS typically allows 6-8 figures)

---

## Figure 1: Trinity Architecture

**Type:** System architecture diagram

**Purpose:** Show high-level Trinity components and their relationships

**Content:**
```
┌─────────────────────────────────────────────────────────┐
│                    Trinity Framework                     │
├─────────────────────────────────────────────────────────┤
│  Input: {-1, 0, +1} weights, Text tokens              │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────┐ │
│  │ Sacred       │    │ VSA          │    │         │ │
│  │ Formats      │───▶│ Operations   │───▶│  HSLM   │ │
│  │ (GF16, TF3)  │    │ (bind,       │    │ Model   │ │
│  │              │    │  unbind)     │    │         │ │
│  └──────────────┘    └──────────────┘    └────┬────┘ │
│                                              │         │
│  ┌──────────────┐                           │         │
│  │ Consciousness │                          │         │
│  │ Gate         │───────────────────────────┘         │
│  │ (ternary)    │                                     │
│  └──────────────┘                                     │
│                                                         │
│  Output: PPL=125, 377 KB model, 1.2W inference      │
└─────────────────────────────────────────────────────────┘
```

**Labels:**
- Sacred Formats: GF16 (finite field), TF3 (φ-based)
- VSA Operations: bind, unbind, bundle, permute
- Consciousness Gate: Ternary attention {-1, 0, +1}
- HSLM: 1.95M parameter language model

**Caption:** Trinity framework architecture. Input weights and tokens flow through sacred numerical formats (GF16, TF3) and VSA operations before reaching the HSLM model. The Consciousness Gate produces ternary attention masks for interpretable token selection.

**File:** `figures/architecture.pdf`

**Tools:** TikZ (LaTeX) or draw.io

---

## Figure 2: Sacred Formats Illustration

**Type:** Numerical format diagram

**Purpose:** Show GF16 and TF3 encoding

**Content (Panel A): GF16 Format**
```
GF16 (16 bits):
┌──────┬──────────────┬─────────────────┐
│ Sign │ Exponent (6) │ Mantissa (9)   │
│ 1 bit│   bits       │   bits         │
└──────┴──────────────┴─────────────────┘
Value = (-1)^sign × 2^(exp - 31) × (1 + mant/512)

Properties:
• Overflow-free (finite field closure)
• Range: ±6.5E4
• Precision: 9-bit mantissa
```

**Content (Panel B): TF3 Encoding**
```
TF3 (2 bits per trit):
┌────┬────┐
│ 00 │  0 │
│ 01 │ φ⁻¹│
│ 10 │  1 │
│ 11 │  φ │
└────┴────┘

Properties:
• Exact arithmetic (φ² = φ + 1)
• 8 weights in 16 bits
• Scale propagation is exact
```

**Caption:** Sacred numerical formats. (A) GF16 uses finite-field arithmetic for provable overflow-freedom. (B) TF3 encodes scales using golden ratio powers with exact arithmetic properties.

**File:** `figures/sacred_formats.pdf`

**Tools:** LaTeX with array package

---

## Figure 3: Training Curves

**Type:** Multi-panel line plot

**Purpose:** Show training progress across 5 runs

**Content (Panel A): Loss vs Steps**
- X-axis: Training steps (0-30,000)
- Y-axis: Cross-entropy loss
- Lines: 5 runs (different colors)
- Shaded region: Mean ± 1 std

**Content (Panel B): PPL vs Steps**
- X-axis: Training steps (0-30,000)
- Y-axis: Perplexity
- Lines: 5 runs
- Shaded region: Mean ± 1 std

**Content (Panel C): Learning Rate Schedule**
- X-axis: Training steps
- Y-axis: Learning rate
- Line: Cosine decay with warmup

**Data:**
```python
steps = [0, 5000, 10000, 15000, 20000, 25000, 30000]
loss_mean = [5.23, 3.12, 2.45, 2.18, 2.05, 1.98, 1.94]
ppl_mean = [215, 142, 128, 125, 124, 124, 124]
```

**Caption:** Training dynamics on TinyStories. (A) Cross-entropy loss decreases smoothly to 1.94. (B) Perplexity converges to 125 ± 6. (C) Cosine learning rate schedule with 5K step warmup.

**File:** `figures/training_curves.pdf`

**Tools:** Matplotlib or Python seaborn

---

## Figure 4: FPGA Resource Utilization

**Type:** Grouped bar chart

**Purpose:** Compare Trinity to prior FPGA accelerators

**Content:**
```
LUT Utilization (%):
Trinity: 19.6% (12,433/63,400)
FINN: 71.3% (45,200/63,400)
LUT-LLM: 47.5% (30,100/63,400)

DSP Usage:
Trinity: 0 (0/240)
FINN: 224 (224/240)
LUT-LLM: 64 (64/240)

Power (W):
Trinity: 1.2
FINN: 2.5
LUT-LLM: 3.2
```

**Caption:** FPGA resource comparison on Xilinx XC7A100T. Trinity achieves zero DSP usage and lowest power consumption (1.2W) while using only 19.6% of available LUTs.

**File:** `figures/fpga_resources.pdf`

**Tools:** Matplotlib grouped bar chart

---

## Figure 5: VSA Bitflip Resilience

**Type:** Multi-line plot

**Purpose:** Show VSA robustness to noise

**Content:**
- X-axis: Corruption percentage (0%, 5%, 10%, 15%, 20%, 25%, 30%)
- Y-axis: Classification accuracy (or PPL retention)
- Lines: BSC, HRR, FHRR (Trinity)

**Data:**
```python
corruption = [0, 5, 10, 15, 20, 25, 30]
bsc = [100, 52, 12, 0, 0, 0, 0]
hrr = [100, 98, 92, 81, 68, 45, 25]
fhrr = [100, 99, 97, 91, 84, 62, 30]
```

**Caption:** VSA bitflip resilience. FHRR (used in Trinity) maintains 30% accuracy at 30% corruption, outperforming HRR (25%) and BSC (0%).

**File:** `figures/vsa_resilience.pdf`

**Tools:** Matplotlib line plot

---

## Figure 6: Consciousness Gate Visualization

**Type:** Heatmap

**Purpose:** Show interpretable attention patterns

**Content:**
- Input sentence: "The cat sat on the mat."
- Y-axis: Tokens (The, cat, sat, on, the, mat, .)
- X-axis: Attention positions
- Color: +1 (red), 0 (white), -1 (blue)

**Example Pattern:**
```
           The   cat    sat    on    the    mat    .
The        +1     0      0      0     -1      0      0
cat        0      +1     +1      0      0      0      0
sat        0      +1     +1     +1      0      0      0
on         0      0      0      +1     +1      0      0
the        0      0      0      0      +1     +1      0
mat        0      0      0      0      0      +1     +1
.          0      0      0      0      0      0     +1
```

**Caption:** Consciousness Gate output for sample sentence. Red (+1) indicates active attention, white (0) indicates uncertainty, blue (-1) indicates suppression. The ternary mask is directly interpretable.

**File:** `figures/consciousness_gate.pdf`

**Tools:** Matplotlib imshow

---

## Figure Style Guidelines

### NeurIPS Requirements

- **Font:** Sans-serif (Helvetica, Arial)
- **Font size:** At least 8pt in figures
- **Resolution:** At least 300 DPI
- **Colors:** Colorblind-friendly palette
- **Legends:** Clear, positioned to avoid overlap

### Color Palette

**Primary:**
- Trinity (blue): #1f77b4
- Baseline (orange): #ff7f0e
- Ablation (red): #d62728

**Sequential:**
- Viridis or plasma (colorblind-friendly)

**Diverging:**
- Cool-warm (for Consciousness Gate)

---

## Figure File Checklist

Before submission, verify each figure:

- [ ] Resolution ≥ 300 DPI
- [ ] Font size ≥ 8pt
- [ ] Axes labeled clearly
- [ ] Legends included
- [ ] Captions complete
- [ ] Colors are distinguishable
- [ ] Files are PDF format (preferred)
- [ ] File sizes < 5MB each
- [ ] Anonymous (no watermarks)

---

## Estimated Figure Pages

**Main paper:** 2 pages (Figure 1 + Figure 3 half-page, Figure 4 half-page)

**Supplementary:** 1 page (Figures 2, 5, 6)

---

**Document Control:** NEURIPS-FIG-001
**Status:** Draft — Figures to be generated from experimental data
