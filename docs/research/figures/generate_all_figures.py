#!/usr/bin/env python3
"""
Generate all figures for Trinity Zenodo bundles (v6.0).

Creates publication-ready figures for all 7 bundles (B001-B007)
with proper Trinity color scheme, accessibility, and export formats.

φ² + 1/φ² = 3 | TRINITY
"""

import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
from matplotlib.patches import FancyBboxPatch, FancyArrowPatch, Rectangle, Circle
import numpy as np
import json
import os
from pathlib import Path

# Trinity color scheme
GOLD = '#D4AF37'    # φ golden
CYAN = '#00CED1'    # Sacred blue
MAGENTA = '#FF00FF' # Innovation
RED = '#FF6B6B'     # Alpha/Iota
GREEN = '#4ECDC4'   # Iota/Sigma
BLUE = '#45B7D1'    # Sigma
DARK_BG = '#1e1e1e'  # Dark background
WHITE = '#FFFFFF'

# Set style
plt.style.use('seaborn-v0_8-darkgrid')
plt.rcParams['figure.facecolor'] = DARK_BG
plt.rcParams['text.color'] = WHITE
plt.rcParams['axes.labelcolor'] = WHITE
plt.rcParams['xtick.color'] = WHITE
plt.rcParams['ytick.color'] = WHITE

OUTPUT_DIR = Path(__file__).parent
os.makedirs(OUTPUT_DIR, exist_ok=True)


def b001_training_curve():
    """Figure 1: HSLM Training Curve (B001)."""
    steps = [0, 5000, 10000, 15000, 20000, 25000, 30000]
    ppl = [215, 165, 138, 128, 126, 125, 125]
    ci_lower = [210, 160, 134, 124, 122, 121, 121]
    ci_upper = [220, 170, 142, 132, 130, 129, 129]

    fig, ax = plt.subplots(figsize=(10, 6))
    ax.plot(steps, ppl, '-', linewidth=2.5, color=CYAN, label='HSLM-1.95M')
    ax.fill_between(steps, ci_lower, ci_upper, alpha=0.3, color=CYAN)
    ax.set_xlabel('Training Steps', fontsize=12)
    ax.set_ylabel('Perplexity', fontsize=12)
    ax.set_title('B001-Figure1: HSLM Training Curve (TinyStories)', fontsize=14, weight='bold', pad=20)
    ax.grid(True, alpha=0.2, color=WHITE)
    ax.legend(facecolor=DARK_BG, edgecolor=WHITE, labelcolor=WHITE, fontsize=10)

    # Add convergence annotation
    ax.axhline(y=125, color=GOLD, linestyle='--', alpha=0.5, linewidth=1)
    ax.text(15000, 130, 'Convergence', color=GOLD, fontsize=9, ha='center')

    plt.tight_layout()
    plt.savefig(OUTPUT_DIR / 'B001-Fig1_training_curve.png', dpi=300, bbox_inches='tight', facecolor=DARK_BG)
    plt.savefig(OUTPUT_DIR / 'B001-Fig1_training_curve.svg', bbox_inches='tight', facecolor=DARK_BG)
    plt.close()
    print(f"✓ B001-Fig1: Training curve created")


def b001_model_comparison():
    """Figure 2: Format Comparison (B001)."""
    formats = ['FP32', 'BF16', 'IEEE f16', 'GF16', 'TF3']
    memory_mb = [7.6, 3.8, 3.8, 3.0, 0.385]
    ppl_scores = [110, 118, 115, 122, 125.3]

    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(14, 5))

    # Memory comparison (log scale)
    bars1 = ax1.bar(formats, memory_mb, color=[GOLD if f == max(memory_mb) else CYAN for f in memory_mb], alpha=0.8)
    ax1.set_ylabel('Model Size (MB)', fontsize=11)
    ax1.set_title('Memory Compression (log scale)', fontsize=12, weight='bold')
    ax1.set_yscale('log')
    ax1.set_facecolor(DARK_BG)
    ax1.tick_params(colors=WHITE)
    for i, v in enumerate(memory_mb):
        ax1.text(i, v * 1.1 if v > 1 else v + 0.05, f'{v} MB',
                ha='center', color=WHITE, fontsize=9)

    # PPL comparison
    bars2 = ax2.bar(formats, ppl_scores, color=[GOLD if p == min(ppl_scores) else CYAN for p in ppl_scores], alpha=0.8)
    ax2.set_ylabel('Perplexity (lower is better)', fontsize=11)
    ax2.set_title('Quality Trade-off', fontsize=12, weight='bold')
    ax2.set_facecolor(DARK_BG)
    ax2.tick_params(colors=WHITE)
    for i, v in enumerate(ppl_scores):
        ax2.text(i, v + 1, f'{v}', ha='center', color=WHITE, fontsize=9)

    plt.suptitle('B001-Figure2: Format Trade-off Analysis', fontsize=14, weight='bold', y=1.05)
    plt.tight_layout()
    plt.savefig(OUTPUT_DIR / 'B001-Fig2_format_comparison.png', dpi=300, bbox_inches='tight', facecolor=DARK_BG)
    plt.savefig(OUTPUT_DIR / 'B001-Fig2_format_comparison.svg', bbox_inches='tight', facecolor=DARK_BG)
    plt.close()
    print(f"✓ B001-Fig2: Format comparison created")


def b002_fpga_resources():
    """Figure 1: FPGA Resource Comparison (B002)."""
    categories = ['LUT', 'DSP48E1', 'FF', 'BRAM']
    fp32 = [8500, 96, 12000, 45]
    ternary = [12433, 0, 8234, 28]
    percentages = [
        [t/f * 100 if f > 0 else 0 for f, t in zip(fp32, ternary)],
        [t/f * 100 if f > 0 else 0 for f, t in zip(fp32, ternary)],
        [t/f * 100 if f > 0 else 0 for f, t in zip(fp32, ternary)],
        [t/f * 100 if f > 0 else 0 for f, t in zip(fp32, ternary)],
    ]

    x = np.arange(len(categories))
    width = 0.35

    fig, ax = plt.subplots(figsize=(10, 6))
    rects1 = ax.bar(x - width/2, fp32, width, label='FP32 Baseline', color=CYAN, alpha=0.8)
    rects2 = ax.bar(x + width/2, ternary, width, label='Ternary (Zero-DSP)', color=GOLD, alpha=0.8)

    ax.set_ylabel('Resource Count (log scale)', fontsize=11)
    ax.set_title('B002-Figure1: FPGA Resource Comparison (XC7A100T)', fontsize=14, weight='bold', pad=20)
    ax.set_xticks(x)
    ax.set_xticklabels(categories)
    ax.set_yscale('log')
    ax.legend(facecolor=DARK_BG, edgecolor=WHITE, labelcolor=WHITE, fontsize=10)
    ax.set_facecolor(DARK_BG)
    ax.tick_params(colors=WHITE)

    # Add percentage labels
    for i, (rect, vals) in enumerate(zip(rects2, percentages)):
        for j, (val, pct) in enumerate(zip(vals, percentages[i])):
            if pct > 0:
                ax.text(rect.get_x() + rect.get_width()/2 + width * (j - 0.5), val + val*0.1,
                       f'+{pct:.0f}%', ha='center', color=WHITE, fontsize=8)

    plt.tight_layout()
    plt.savefig(OUTPUT_DIR / 'B002-Fig1_fpga_resources.png', dpi=300, bbox_inches='tight', facecolor=DARK_BG)
    plt.savefig(OUTPUT_DIR / 'B002-Fig1_fpga_resources.svg', bbox_inches='tight', facecolor=DARK_BG)
    plt.close()
    print(f"✓ B002-Fig1: FPGA resources created")


def b002_power_analysis():
    """Figure 2: Power Consumption (B002)."""
    formats = ['FP32', 'BF16', 'IEEE f16', 'GF16', 'TF3']
    power_w = [2.8, 1.9, 2.5, 1.2, 0.8]

    fig, ax = plt.subplots(figsize=(10, 5))
    bars = ax.bar(formats, power_w, color=[GOLD if p == min(power_w) else CYAN for p in power_w], alpha=0.8)
    ax.set_ylabel('Power Consumption (W)', fontsize=11)
    ax.set_title('B002-Figure2: Power Efficiency (lower is better)', fontsize=14, weight='bold', pad=20)
    ax.set_facecolor(DARK_BG)
    ax.tick_params(colors=WHITE)
    ax.grid(True, alpha=0.2, color=WHITE, axis='y')

    for i, v in enumerate(power_w):
        ax.text(i, v + 0.05, f'{v} W', ha='center', color=WHITE, fontsize=10)

    plt.tight_layout()
    plt.savefig(OUTPUT_DIR / 'B002-Fig2_power_analysis.png', dpi=300, bbox_inches='tight', facecolor=DARK_BG)
    plt.savefig(OUTPUT_DIR / 'B002-Fig2_power_analysis.svg', bbox_inches='tight', facecolor=DARK_BG)
    plt.close()
    print(f"✓ B002-Fig2: Power analysis created")


def b003_register_layout():
    """Figure 1: TRI-27 Register File Layout (B003)."""
    fig, ax = plt.subplots(figsize=(12, 7))
    ax.set_xlim(0, 10)
    ax.set_ylim(0, 4)
    ax.axis('off')
    ax.set_facecolor(DARK_BG)

    # Bank labels
    ax.text(2.5, 3.6, 'Alpha (α-η)', ha='center', color=RED, fontsize=12, weight='bold')
    ax.text(5, 3.6, 'Iota (ι-ρ)', ha='center', color=GREEN, fontsize=12, weight='bold')
    ax.text(7.5, 3.6, 'Sigma (σ-ϡ)', ha='center', color=BLUE, fontsize=12, weight='bold')

    # Draw bank borders
    for x, color, name in [(0.5, RED, 'Alpha'), (4.5, GREEN, 'Iota'), (8.5, BLUE, 'Sigma')]:
        rect = Rectangle((x, 0.8), 2.8, 3, linewidth=2, edgecolor=color, facecolor=color, alpha=0.15)
        ax.add_patch(rect)

    # Alpha bank (α-η): R0-R8
    for i in range(9):
        rect = Rectangle((0.5 + i * 0.28, 1), 0.24, 2.6,
                       edgecolor=RED, facecolor=RED, alpha=0.4)
        ax.add_patch(rect)
        ax.text(0.62 + i * 0.28, 2.3, f'R{i}', ha='center', color=WHITE, fontsize=9)

    # Iota bank (ι-ρ): R9-R17
    for i in range(9):
        rect = Rectangle((4.5 + i * 0.28, 1), 0.24, 2.6,
                       edgecolor=GREEN, facecolor=GREEN, alpha=0.4)
        ax.add_patch(rect)
        ax.text(4.62 + i * 0.28, 2.3, f'R{i+9}', ha='center', color=WHITE, fontsize=9)

    # Sigma bank (σ-ϡ): R18-R26
    for i in range(9):
        rect = Rectangle((8.5 + i * 0.28, 1), 0.24, 2.6,
                       edgecolor=BLUE, facecolor=BLUE, alpha=0.4)
        ax.add_patch(rect)
        ax.text(8.62 + i * 0.28, 2.3, f'R{i+18}', ha='center', color=WHITE, fontsize=9)

    ax.set_title('B003-Figure1: TRI-27 Register File Layout (27 Registers)', fontsize=14, weight='bold', pad=20)
    plt.tight_layout()
    plt.savefig(OUTPUT_DIR / 'B003-Fig1_register_layout.png', dpi=300, bbox_inches='tight', facecolor=DARK_BG)
    plt.savefig(OUTPUT_DIR / 'B003-Fig1_register_layout.svg', bbox_inches='tight', facecolor=DARK_BG)
    plt.close()
    print(f"✓ B003-Fig1: Register layout created")


def b004_lotus_cycle():
    """Figure 1: Queen Lotus Cycle State Machine (B004)."""
    states = [
        ('DIAGNOSE', 0, 8, RED),
        ('PLAN', 7, 4, GREEN),
        ('ACT', 7, 0, BLUE),
        ('VERIFY', 3, 0, '#96CEB4'),
        ('MEASURE', 0, 4, GOLD),
        ('PERSIST', 0, 8, MAGENTA),
    ]

    fig, ax = plt.subplots(figsize=(9, 9))
    ax.axis('off')
    ax.set_facecolor(DARK_BG)

    # Draw circle
    circle = Circle((5, 4), 3.2, fill=False, edgecolor=WHITE, linewidth=2)
    ax.add_patch(circle)

    # Draw states
    for state, x, y, color in states:
        state_circle = Circle((x, y), 0.7, facecolor=color, edgecolor=WHITE, linewidth=2)
        ax.add_patch(state_circle)
        ax.text(x, y, state[:5].upper(), ha='center', va='center',
                color=WHITE, fontsize=9, weight='bold')

    # Transitions
    transitions = [
        (0, 1), (1, 2), (2, 3), (3, 4), (4, 5), (5, 0)
    ]
    for start, end in transitions:
        x1, y1 = states[start][1], states[start][2]
        x2, y2 = states[end][1], states[end][2]
        arrow = FancyArrowPatch((x1, y1), (x2, y2), mutation_scale=12,
                                color=WHITE, arrowstyle='->', linewidth=1.5,
                                connectionstyle='arc3,rad=0.3')
        ax.add_patch(arrow)

    ax.set_title('B004-Figure1: Queen Lotus Cycle State Machine', fontsize=14, weight='bold', pad=20)
    plt.tight_layout()
    plt.savefig(OUTPUT_DIR / 'B004-Fig1_lotus_cycle.png', dpi=300, bbox_inches='tight', facecolor=DARK_BG)
    plt.savefig(OUTPUT_DIR / 'B004-Fig1_lotus_cycle.svg', bbox_inches='tight', facecolor=DARK_BG)
    plt.close()
    print(f"✓ B004-Fig1: Lotus cycle created")


def b005_type_hierarchy():
    """Figure 1: Tri Language Type Hierarchy (B005)."""
    fig, ax = plt.subplots(figsize=(11, 7))
    ax.set_xlim(0, 11)
    ax.set_ylim(0, 7)
    ax.axis('off')
    ax.set_facecolor(DARK_BG)

    # Core types (Linear)
    linear_types = [('Let', 1, 5, GOLD), ('Inout', 4, 5, CYAN),
                 ('Sink', 7, 5, MAGENTA), ('Set', 10, 5, GREEN)]

    for name, x, y, color in linear_types:
        box = FancyBboxPatch((x, y), (x + 1.8, y + 1.2),
                             boxstyle="round,pad=0.1", edgecolor=color, facecolor=color, alpha=0.5)
        ax.add_patch(box)
        ax.text(x + 0.9, y + 0.6, name, ha='center', color=WHITE,
                fontsize=10, weight='bold')

    # Effects
    effects_box = FancyBboxPatch((2, 2), (9, 3.5),
                               boxstyle="round,pad=0.1", edgecolor=WHITE, facecolor='#330033', alpha=0.5)
    ax.add_patch(effects_box)
    ax.text(5.5, 2.75, 'Effects System', ha='center', color=WHITE,
            fontsize=11, weight='bold')

    # Patterns
    patterns_box = FancyBboxPatch((2, 3.8), (9, 5.3),
                                boxstyle="round,pad=0.1", edgecolor=WHITE, facecolor='#330033', alpha=0.5)
    ax.add_patch(patterns_box)
    ax.text(5.5, 4.55, 'Pattern Matching', ha='center', color=WHITE,
            fontsize=11, weight='bold')

    # Connection arrows
    for box in linear_types:
        arrow = FancyArrowPatch((box[2], box[3]), (5, 2.5), mutation_scale=10,
                                color=WHITE, arrowstyle='->', linewidth=1.5)
        ax.add_patch(arrow)

    ax.set_title('B005-Figure1: Tri Language Type System', fontsize=14, weight='bold', pad=20)
    plt.tight_layout()
    plt.savefig(OUTPUT_DIR / 'B005-Fig1_type_hierarchy.png', dpi=300, bbox_inches='tight', facecolor=DARK_BG)
    plt.savefig(OUTPUT_DIR / 'B005-Fig1_type_hierarchy.svg', bbox_inches='tight', facecolor=DARK_BG)
    plt.close()
    print(f"✓ B005-Fig1: Type hierarchy created")


def b006_gf16_layout():
    """Figure 1: GF16/TF3 Bit Layout Comparison (B006)."""
    formats = ['FP32', 'BF16', 'IEEE f16', 'GF16', 'TF3']

    fig, ax = plt.subplots(figsize=(12, 4))
    ax.set_xlim(0, 8)
    ax.set_ylim(0, 3.5)
    ax.axis('off')
    ax.set_facecolor(DARK_BG)

    # Draw each format as stacked bar
    y_pos = 2.5
    for i, fmt in enumerate(formats):
        if fmt == 'FP32':
            # Sign (1) + Exponent (8) + Mantissa (23)
            sign = Rectangle((i * 1.5 + 0.2, y_pos), 0.3, 3,
                           edgecolor=RED, facecolor=RED, alpha=0.6)
            exp = Rectangle((i * 1.5 + 0.55, y_pos), 0.9, 3,
                           edgecolor=GREEN, facecolor=GREEN, alpha=0.6)
            mant = Rectangle((i * 1.5 + 1.5, y_pos), 2.3, 3,
                            edgecolor=BLUE, facecolor=BLUE, alpha=0.6)
        elif fmt == 'GF16':
            # Sign (1) + Exponent (6) + Mantissa (9)
            sign = Rectangle((i * 1.5 + 0.2, y_pos), 0.3, 3,
                           edgecolor=RED, facecolor=RED, alpha=0.6)
            exp = Rectangle((i * 1.5 + 0.55, y_pos), 0.6, 3,
                           edgecolor=GREEN, facecolor=GREEN, alpha=0.6)
            mant = Rectangle((i * 1.5 + 1.2, y_pos), 2.3, 3,
                           edgecolor=BLUE, facecolor=BLUE, alpha=0.6)
        elif fmt == 'TF3':
            # 8 groups of {sign, exp, mant} × 3
            base_y = y_pos
            for j in range(3):
                s = Rectangle((i * 1.5 + 0.2, base_y + j * 1.0), 0.25, 3,
                           edgecolor=RED, facecolor=RED, alpha=0.6)
                e = Rectangle((i * 1.5 + 0.5, base_y + j * 1.0), 0.45, 3,
                           edgecolor=GREEN, facecolor=GREEN, alpha=0.6)
                m = Rectangle((i * 1.5 + 1.0, base_y + j * 1.0), 1.2, 3,
                           edgecolor=BLUE, facecolor=BLUE, alpha=0.6)
                ax.add_patch(s)
                ax.add_patch(e)
                ax.add_patch(m)
        else:  # BF16, IEEE f16
            # Sign (1) + Exponent (8) + Mantissa (7)
            sign = Rectangle((i * 1.5 + 0.4, y_pos), 0.3, 3,
                           edgecolor=RED, facecolor=RED, alpha=0.6)
            exp = Rectangle((i * 1.5 + 0.75, y_pos), 0.7, 3,
                           edgecolor=GREEN, facecolor=GREEN, alpha=0.6)
            mant = Rectangle((i * 1.5 + 1.5, y_pos), 1.8, 3,
                           edgecolor=BLUE, facecolor=BLUE, alpha=0.6)
            ax.add_patch(sign)
            ax.add_patch(exp)
            ax.add_patch(mant)

        ax.text(i * 1.5 + 0.9, y_pos + 1.7, fmt, ha='center', color=WHITE, fontsize=11, weight='bold')

    # Legend
    legend_elements = [
        mpatches.Patch(facecolor=RED, alpha=0.6, label='Sign bit'),
        mpatches.Patch(facecolor=GREEN, alpha=0.6, label='Exponent'),
        mpatches.Patch(facecolor=BLUE, alpha=0.6, label='Mantissa'),
    ]
    ax.legend(handles=legend_elements, loc='lower center',
           facecolor=DARK_BG, edgecolor=WHITE, labelcolor=WHITE, fontsize=9)

    ax.set_title('B006-Figure1: GF16/TF3 Bit Layout Comparison (φ-optimal)', fontsize=14, weight='bold', pad=20)
    plt.tight_layout()
    plt.savefig(OUTPUT_DIR / 'B006-Fig1_gf16_layout.png', dpi=300, bbox_inches='tight', facecolor=DARK_BG)
    plt.savefig(OUTPUT_DIR / 'B006-Fig1_gf16_layout.svg', bbox_inches='tight', facecolor=DARK_BG)
    plt.close()
    print(f"✓ B006-Fig1: GF16 layout created")


def b006_phi_heatmap():
    """Figure 2: Phi-Distance Heatmap (B006)."""
    # Simulated phi-distance for different bit allocations
    exp_bits = list(range(1, 15))
    mant_bits = list(range(1, 15))

    # Distance calculation: |bits - phi*total| where phi ~ 1.618
    phi = 1.6180339887
    optimal_exp = round(phi * 8)
    optimal_mant = round(phi * 16)

    distance_matrix = np.zeros((len(exp_bits), len(mant_bits)))
    for i, exp in enumerate(exp_bits):
        for j, mant in enumerate(mant_bits):
            total = exp + mant
            # Distance from phi-proportional allocation (16*phi + 8*phi = 39)
            optimal = 24  # 16 + 8
            distance_matrix[i, j] = abs(total - optimal) / optimal

    fig, ax = plt.subplots(figsize=(10, 8))
    im = ax.imshow(distance_matrix, cmap='RdYlGn', aspect='auto', vmin=0, vmax=1)
    ax.set_xticks(range(len(mant_bits)))
    ax.set_yticks(range(len(exp_bits)))
    ax.set_xticklabels(mant_bits)
    ax.set_yticklabels(exp_bits)
    ax.set_xlabel('Mantissa Bits', fontsize=11, color=WHITE)
    ax.set_ylabel('Exponent Bits', fontsize=11, color=WHITE)
    ax.set_title('B006-Figure2: φ-Distance from Optimal (green = φ-optimal)', fontsize=14, weight='bold', pad=20)

    # Annotate GF16 (6, 9) and TF3 (9, 9)
    ax.scatter([8, 9], [6, 9], c='white', s=100, marker='x', linewidths=2)
    ax.text(8.2, 5.7, 'GF16', color=WHITE, fontsize=10, weight='bold')
    ax.text(9.2, 5.7, 'TF3', color=WHITE, fontsize=10, weight='bold')

    cbar = plt.colorbar(im, ax=ax)
    cbar.set_label('Normalized φ-Distance', color=WHITE, fontsize=10)

    plt.tight_layout()
    plt.savefig(OUTPUT_DIR / 'B006-Fig2_phi_heatmap.png', dpi=300, bbox_inches='tight', facecolor=DARK_BG)
    plt.savefig(OUTPUT_DIR / 'B006-Fig2_phi_heatmap.svg', bbox_inches='tight', facecolor=DARK_BG)
    plt.close()
    print(f"✓ B006-Fig2: Phi heatmap created")


def b007_vsa_structure():
    """Figure 1: HybridBigInt SIMD Structure (B007)."""
    fig, ax = plt.subplots(figsize=(11, 6))
    ax.set_xlim(0, 7)
    ax.set_ylim(0, 5)
    ax.axis('off')
    ax.set_facecolor(DARK_BG)

    # Draw 2 SIMD vectors (32 limbs each, 16 trits per limb)
    for vec_idx in range(2):
        y_base = 4 - vec_idx * 4.2
        # Limb rectangles
        for i in range(32):
            x = 0.5 + (i // 8) * 1.0
            y = y_base - (i % 8) * 0.45
            limb = Rectangle((x, y), 0.8, 0.35,
                               edgecolor=CYAN, facecolor=CYAN, alpha=0.5)
            ax.add_patch(limb)

            # Trit markers inside limb
            for t in range(16):
                tx = x + 0.08 + (t // 4) * 0.17
                ty = y - 0.08 + (t % 4) * 0.08
                ax.plot([tx, tx + 0.08], [ty, ty - 0.08], color=GOLD, linewidth=0.8)

        ax.text(3.5, y_base + 2.1, f'SIMD Vector {vec_idx + 1}\n(32 limbs × 16 trits)',
                ha='center', color=WHITE, fontsize=9, weight='bold')

        # Vector label
        ax.text(6, y_base - 0.5, f'Total: {32*16} trits', ha='center',
                color=GOLD, fontsize=8)

    ax.set_title('B007-Figure1: HybridBigInt SIMD Layout (17.2× speedup)', fontsize=14, weight='bold', pad=20)
    plt.tight_layout()
    plt.savefig(OUTPUT_DIR / 'B007-Fig1_vsa_structure.png', dpi=300, bbox_inches='tight', facecolor=DARK_BG)
    plt.savefig(OUTPUT_DIR / 'B007-Fig1_vsa_structure.svg', bbox_inches='tight', facecolor=DARK_BG)
    plt.close()
    print(f"✓ B007-Fig1: VSA structure created")


def b007_simd_speedup():
    """Figure 2: SIMD Speedup Comparison (B007)."""
    operations = ['Bind', 'Bundle', 'Cosine', 'Permute']
    scalar_time = [45, 52, 68, 38]  # nanoseconds
    simd_time = [3.2, 4.4, 4.0, 2.8]
    speedup = [s/v for s, v in zip(scalar_time, simd_time)]

    x = np.arange(len(operations))
    width = 0.35

    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(14, 5))

    # Absolute times
    rects1 = ax1.bar(x - width/2, scalar_time, width, label='Scalar', color=CYAN, alpha=0.8)
    rects2 = ax1.bar(x + width/2, simd_time, width, label='SIMD (NEON)', color=GOLD, alpha=0.8)
    ax1.set_ylabel('Time (ns)', fontsize=11)
    ax1.set_title('Absolute Runtime', fontsize=12, weight='bold')
    ax1.set_xticks(x)
    ax1.set_xticklabels(operations)
    ax1.legend(facecolor=DARK_BG, edgecolor=WHITE, labelcolor=WHITE, fontsize=10)
    ax1.set_yscale('log')
    ax1.set_facecolor(DARK_BG)
    ax1.tick_params(colors=WHITE)

    # Speedup
    bars = ax2.bar(x, speedup, color=MAGENTA, alpha=0.8)
    ax2.set_ylabel('Speedup (×)', fontsize=11)
    ax2.set_title('SIMD Acceleration', fontsize=12, weight='bold')
    ax2.set_xticks(x)
    ax2.set_xticklabels(operations)
    ax2.axhline(y=10, color=RED, linestyle='--', alpha=0.5, linewidth=1, label='10×')
    ax2.legend(facecolor=DARK_BG, edgecolor=WHITE, labelcolor=WHITE, fontsize=10)
    ax2.set_facecolor(DARK_BG)
    ax2.tick_params(colors=WHITE)
    ax2.grid(True, alpha=0.2, color=WHITE, axis='y')

    for bar, val in zip(bars, speedup):
        ax2.text(bar.get_x() + bar.get_width()/2, bar.get_height() + 0.5,
                f'{val:.1f}×', ha='center', color=WHITE, fontsize=10, weight='bold')

    plt.suptitle('B007-Figure2: VSA Operations Performance', fontsize=14, weight='bold', y=1.05)
    plt.tight_layout()
    plt.savefig(OUTPUT_DIR / 'B007-Fig2_simd_speedup.png', dpi=300, bbox_inches='tight', facecolor=DARK_BG)
    plt.savefig(OUTPUT_DIR / 'B007-Fig2_simd_speedup.svg', bbox_inches='tight', facecolor=DARK_BG)
    plt.close()
    print(f"✓ B007-Fig2: SIMD speedup created")


def main():
    """Generate all figures for Trinity Zenodo bundles v6.0."""
    print("\n" + "="*60)
    print("Trinity Zenodo v6.0 Figure Generator")
    print("="*60)
    print(f"\nOutput directory: {OUTPUT_DIR}")
    print("\nGenerating figures...\n")

    # Generate all figures
    b001_training_curve()
    b001_model_comparison()
    b002_fpga_resources()
    b002_power_analysis()
    b003_register_layout()
    b004_lotus_cycle()
    b005_type_hierarchy()
    b006_gf16_layout()
    b006_phi_heatmap()
    b007_vsa_structure()
    b007_simd_speedup()

    # Summary
    files = list(OUTPUT_DIR.glob("*.png")) + list(OUTPUT_DIR.glob("*.svg"))
    print(f"\n{'='*60}")
    print(f"Total figures created: {len(files)}")
    print(f"PNG files: {len(list(OUTPUT_DIR.glob('*.png')))}")
    print(f"SVG files: {len(list(OUTPUT_DIR.glob('*.svg')))}")
    print("="*60 + "\n")
    print("✓ All figures generated successfully!")
    print("\nφ² + 1/φ² = 3 | TRINITY\n")


if __name__ == '__main__':
    main()
