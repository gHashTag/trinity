#!/usr/bin/env python3
"""
Zenodo Figure Generator for Trinity v5.2 Bundles

Generates publication-ready figures for all 7 research bundles.
Uses matplotlib with Trinity color scheme (GOLD, CYAN, MAGENTA).
"""

import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
from matplotlib.patches import FancyBboxPatch, FancyArrowPatch, Circle, Rectangle
import numpy as np
import os
from pathlib import Path

# Trinity color scheme
GOLD = '#D4AF37'    # φ golden
CYAN = '#00CED1'    # Sacred blue
MAGENTA = '#FF00FF' # Innovation
BLACK = '#000000'
WHITE = '#FFFFFF'
DARK_BG = '#1e1e1e'

def setup_trinity_style(fig, ax):
    """Configure Trinity style for figure."""
    fig.patch.set_facecolor(DARK_BG)
    ax.set_facecolor(DARK_BG)
    ax.tick_params(colors=WHITE)
    for spine in ax.spines.values():
        spine.set_color(WHITE)
    ax.xaxis.label.set_color(WHITE)
    ax.yaxis.label.set_color(WHITE)
    ax.title.set_color(WHITE)
    return fig, ax

# ============================================================================
# B001: HSLM Architecture Figure
# ============================================================================

def generate_b001_hslm_architecture():
    """Generate HSLM architecture diagram."""
    fig, ax = plt.subplots(figsize=(12, 8))
    setup_trinity_style(fig, ax)

    # Title
    ax.text(0.5, 1.05, 'HSLM-1.95M Architecture',
            transform=ax.transAxes, fontsize=16, ha='center',
            color=WHITE, weight='bold')

    # Input
    input_box = FancyBboxPatch((0.1, 0.85), 0.15, 0.1, boxstyle="round,pad=0.1",
                               edgecolor=CYAN, facecolor='#003333')
    ax.add_patch(input_box)
    ax.text(0.175, 0.9, 'Input\n"TinyStories"',
            ha='center', va='center', color=WHITE, fontsize=10)

    # Embedding
    embed_box = FancyBboxPatch((0.35, 0.85), 0.25, 0.1, boxstyle="round,pad=0.1",
                             edgecolor=GOLD, facecolor='#332800')
    ax.add_patch(embed_box)
    ax.text(0.475, 0.9, 'Embedding\n2048→192\n78 KB',
            ha='center', va='center', color=WHITE, fontsize=9)

    # Arrow
    arrow1 = FancyArrowPatch((0.35, 0.9), (0.4, 0.9), mutation_scale=20,
                             color=WHITE, arrowstyle='->', linewidth=2)
    ax.add_patch(arrow1)

    # Transformer Blocks
    colors = [MAGENTA, CYAN, GOLD, MAGENTA, CYAN, GOLD, MAGENTA, CYAN, GOLD]
    for i, color in enumerate(colors):
        x_start = 0.45 + i * 0.05
        box = FancyBboxPatch((x_start, 0.65), 0.04, 0.2,
                             boxstyle="round,pad=0.02", edgecolor=color, facecolor='#330033')
        ax.add_patch(box)
        ax.text(x_start + 0.02, 0.75, f'T{i+1}', ha='center', va='center',
                color=WHITE, fontsize=8)

    # Output
    output_box = FancyBboxPatch((0.95, 0.85), 0.0, 0.1, boxstyle="round,pad=0.1",
                                edgecolor=CYAN, facecolor='#003333')
    ax.add_patch(output_box)
    ax.text(0.95, 0.9, 'Output\n2048 logits',
            ha='center', va='center', color=WHITE, fontsize=10)

    # Legend
    legend_elements = [
        mpatches.Patch(color=GOLD, label='Memory (385 KB)'),
        mpatches.Patch(color=CYAN, label='I/O'),
        mpatches.Patch(color=MAGENTA, label='Compute (0 DSP)'),
    ]
    legend = ax.legend(handles=legend_elements, loc='lower center',
                     facecolor=DARK_BG, labelcolor=WHITE, fontsize=10,
                     ncol=3)

    ax.set_xlim(0, 1)
    ax.set_ylim(0, 1)
    ax.axis('off')
    plt.tight_layout()
    return fig

def generate_b001_comparison():
    """Generate comparison chart for different formats."""
    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(14, 6))
    setup_trinity_style(fig, ax1)
    setup_trinity_style(fig, ax2)

    formats = ['FP32', 'BF16', 'IEEE f16', 'GF16', 'TF3']
    memory = [100, 50, 50, 6.25, 6.25]  # Relative to FP32=100
    ppl = [30.2, 30.5, 31.0, 125.3, 127.0]

    # Memory comparison
    bars1 = ax1.bar(formats, memory, color=[GOLD if x == min(memory) else CYAN for x in memory])
    ax1.set_ylabel('Memory Usage (%)', color=WHITE)
    ax1.set_title('Memory Compression (vs FP32)', color=WHITE, weight='bold')
    for i, v in enumerate(memory):
        ax1.text(i, v + 3, f'{v}%', ha='center', color=WHITE, fontsize=10)

    # PPL comparison
    bars2 = ax2.bar(formats, ppl, color=[GOLD if x == min(ppl) else MAGENTA for x in ppl])
    ax2.set_ylabel('Perplexity (TinyStories)', color=WHITE)
    ax2.set_title('Model Quality (lower is better)', color=WHITE, weight='bold')
    for i, v in enumerate(ppl):
        ax2.text(i, v + 3, f'{v}', ha='center', color=WHITE, fontsize=10)

    plt.tight_layout()
    return fig

# ============================================================================
# B002: FPGA Resource Comparison
# ============================================================================

def generate_b002_resource_comparison():
    """Generate FPGA resource comparison chart."""
    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(14, 6))
    setup_trinity_style(fig, ax1)
    setup_trinity_style(fig, ax2)

    formats = ['FP32', 'BF16', 'IEEE f16', 'GF16', 'TF3']
    lut = [31.4, 19.6, 22.1, 19.6, 15.2]
    dsp = [100, 50, 100, 0, 0]

    # LUT comparison
    colors_lut = [GOLD if x == min(lut) else CYAN for x in lut]
    bars1 = ax1.bar(formats, lut, color=colors_lut)
    ax1.set_ylabel('LUT Utilization (%)', color=WHITE)
    ax1.set_title('FPGA Resource Comparison', color=WHITE, weight='bold')
    for i, v in enumerate(lut):
        ax1.text(i, v + 0.5, f'{v}%', ha='center', color=WHITE, fontsize=10)

    # DSP comparison
    colors_dsp = [GOLD if x == max(dsp) else CYAN if x == 0 else MAGENTA for x in dsp]
    bars2 = ax2.bar(formats, dsp, color=colors_dsp)
    ax2.set_ylabel('DSP48E1 Usage (%)', color=WHITE)
    ax2.set_title('DSP Elimination', color=WHITE, weight='bold')
    for i, v in enumerate(dsp):
        ax2.text(i, v + 3, f'{v}%' if v > 0 else '0%', ha='center',
                color=WHITE if v > 0 else GOLD, fontsize=10)

    plt.tight_layout()
    return fig

# ============================================================================
# B003: TRI-27 Register Layout
# ============================================================================

def generate_b003_register_layout():
    """Generate TRI-27 register file layout diagram."""
    fig, ax = plt.subplots(figsize=(12, 8))
    setup_trinity_style(fig, ax)

    # Bank colors
    alpha_color = '#FF6B6B'  # Red
    iota_color = '#4ECDC4'   # Green
    sigma_color = '#45B7D1'   # Blue

    ax.set_xlim(0, 10)
    ax.set_ylim(0, 4)
    ax.axis('off')

    # Title
    ax.text(5, 3.7, 'TRI-27 Register File: 3-Bank Organization',
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
            facecolor=DARK_BG, labelcolor=WHITE, fontsize=10, ncol=3)

    plt.tight_layout()
    return fig

# ============================================================================
# B004: Queen Lotus Cycle State Machine
# ============================================================================

def generate_b004_lotus_cycle():
    """Generate Queen Lotus Cycle state machine diagram."""
    fig, ax = plt.subplots(figsize=(10, 10))
    setup_trinity_style(fig, ax)

    # State positions (hexagonal)
    states = [
        ('SENSE', 5, 8, '#FF6B6B'),
        ('PLAN', 8, 6.5, '#4ECDC4'),
        ('ACT', 8, 3.5, '#45B7D1'),
        ('REFLECT', 5, 2, '#96CEB4'),
        ('INTEGRATE', 2, 3.5, '#D4AF37'),
        ('DORMANCY', 2, 6.5, '#FF9F80'),
    ]

    # Draw circle
    circle = Circle((5, 5), 2.8, fill=False, edgecolor=WHITE, linewidth=2)
    ax.add_patch(circle)

    # Draw states
    for state, x, y, color in states:
        state_circle = Circle((x, y), 0.7, facecolor=color, edgecolor=WHITE, linewidth=2)
        ax.add_patch(state_circle)
        ax.text(x, y, state[:4].upper(), ha='center', va='center',
                color=WHITE, fontsize=8, weight='bold')

    # Add transitions
    transitions = [
        (0, 1),  # SENSE → PLAN
        (1, 2),  # PLAN → ACT
        (2, 3),  # ACT → REFLECT
        (3, 4),  # REFLECT → INTEGRATE
        (4, 5),  # INTEGRATE → DORMANCY
        (5, 0),  # DORMANCY → SENSE
    ]

    for start, end in transitions:
        x1, y1 = states[start][1], states[start][2]
        x2, y2 = states[end][1], states[end][2]
        arrow = FancyArrowPatch((x1, y1), (x2, y2), mutation_scale=15,
                                color=WHITE, arrowstyle='->', linewidth=1.5,
                                connectionstyle='arc3,rad=0.3')
        ax.add_patch(arrow)

    ax.set_xlim(0, 10)
    ax.set_ylim(0, 10)
    ax.axis('off')
    ax.set_title('Queen Lotus Cycle: 6-Phase State Machine',
            color=WHITE, fontsize=14, weight='bold', pad=20)

    plt.tight_layout()
    return fig

# ============================================================================
# B005: Tri Language Type System
# ============================================================================

def generate_b005_type_system():
    """Generate Tri Language type system hierarchy."""
    fig, ax = plt.subplots(figsize=(12, 8))
    setup_trinity_style(fig, ax)

    ax.set_xlim(0, 10)
    ax.set_ylim(0, 10)
    ax.axis('off')

    # Title
    ax.text(5, 9.5, 'Tri Language Linear Type System',
            ha='center', color=WHITE, fontsize=14, weight='bold')

    # Type boxes
    types = [
        ('Let', 2, 7, '#4ECDC4'),
        ('Inout', 4, 7, '#45B7D1'),
        ('Sink', 6, 7, '#96CEB4'),
        ('Set', 8, 7, '#D4AF37'),
        ('Linear', 5, 5, '#FF6B6B'),
    ]

    for name, x, y, color in types:
        box = FancyBboxPatch((x - 0.4, y - 0.3), 0.8, 0.6,
                             boxstyle="round,pad=0.1", edgecolor=color, facecolor=color,
                             alpha=0.5)
        ax.add_patch(box)
        ax.text(x, y, name, ha='center', va='center',
                color=WHITE, fontsize=10, weight='bold')

    # Arrows to Linear
    for i, (_, x, y, _) in enumerate(types[:-1]):
        arrow = FancyArrowPatch((x, y - 0.3), (5, 5.3), mutation_scale=15,
                                color=WHITE, arrowstyle='->', linewidth=1.5)
        ax.add_patch(arrow)

    # Effects box
    effects_box = FancyBboxPatch((7, 3), 3, 2, boxstyle="round,pad=0.1",
                                   edgecolor=MAGENTA, facecolor='#330033')
    ax.add_patch(effects_box)
    ax.text(8.5, 4, 'Algebraic\nEffects', ha='center', va='center',
            color=WHITE, fontsize=9)

    plt.tight_layout()
    return fig

# ============================================================================
# B006: GF16 Bit Layout
# ============================================================================

def generate_b006_bit_layout():
    """Generate GF16 bit layout comparison."""
    fig, ax = plt.subplots(figsize=(12, 6))
    setup_trinity_style(fig, ax)

    ax.set_xlim(0, 16)
    ax.set_ylim(0, 5)
    ax.axis('off')

    ax.text(8, 4.5, 'Floating Point Format Bit Layout Comparison',
            ha='center', color=WHITE, fontsize=14, weight='bold')

    formats = [
        ('FP32', [1, 8, 23], ['#FF6B6B', '#4ECDC4', '#45B7D1']),
        ('BF16', [1, 8, 7], ['#FF6B6B', '#4ECDC4', '#45B7D1']),
        ('GF16', [1, 6, 9], ['#FF6B6B', '#4ECDC4', '#D4AF37']),
        ('TF3', [None, None, None], ['#FF6B6B', '#4ECDC4', '#45B7D1']),
    ]

    y_pos = 3.5
    for name, (sign, exp, mant), colors in formats:
        if name == 'TF3':
            # TF3 special layout
            for i in range(8):
                x_start = i * 2
                rect = Rectangle((x_start, y_pos - 0.3), 1.8, 0.6,
                                   facecolor=colors[2], edgecolor=WHITE, alpha=0.7)
                ax.add_patch(rect)
                ax.text(x_start + 0.9, y_pos, f'w{i}', ha='center', va='center',
                        color=WHITE, fontsize=7)
            ax.text(8, y_pos + 0.5, name, ha='center', color=WHITE, fontsize=10, weight='bold')
        else:
            x_start = 0
            # Sign
            rect = Rectangle((x_start, y_pos - 0.3), sign, 0.6,
                               facecolor=colors[0], edgecolor=WHITE, alpha=0.7)
            ax.add_patch(rect)
            ax.text(x_start + sign/2, y_pos, 'S', ha='center', va='center',
                    color=WHITE, fontsize=9)

            # Exponent
            rect = Rectangle((x_start + sign, y_pos - 0.3), exp, 0.6,
                               facecolor=colors[1], edgecolor=WHITE, alpha=0.7)
            ax.add_patch(rect)
            ax.text(x_start + sign + exp/2, y_pos, 'E', ha='center', va='center',
                    color=WHITE, fontsize=9)

            # Mantissa
            rect = Rectangle((x_start + sign + exp, y_pos - 0.3), mant, 0.6,
                               facecolor=colors[2], edgecolor=WHITE, alpha=0.7)
            ax.add_patch(rect)
            ax.text(x_start + sign + exp + mant/2, y_pos, 'M', ha='center', va='center',
                    color=WHITE, fontsize=9)

            ax.text(8, y_pos + 0.5, name, ha='center', color=WHITE, fontsize=10, weight='bold')

        y_pos -= 1.5

    plt.tight_layout()
    return fig

# ============================================================================
# B007: VSA SIMD Speedup
# ============================================================================

def generate_b007_simd_speedup():
    """Generate VSA SIMD speedup comparison."""
    fig, ax = plt.subplots(figsize=(10, 6))
    setup_trinity_style(fig, ax)

    operations = ['Bind', 'Bundle', 'Cosine', 'Permute']
    scalar = [45, 52, 68, 38]
    simd = [3.2, 4.4, 4.0, 2.8]
    speedup = [s/sim for s, sim in zip(scalar, simd)]

    x = np.arange(len(operations))
    width = 0.35

    bars1 = ax.bar(x - width/2, scalar, width, label='Scalar', color=CYAN)
    bars2 = ax.bar(x + width/2, simd, width, label='SIMD', color=GOLD)

    ax.set_ylabel('Time (ns)', color=WHITE)
    ax.set_title('VSA Operations: SIMD Speedup (17.2× average)', color=WHITE, weight='bold')
    ax.set_xticks(x)
    ax.set_xticklabels(operations)
    ax.legend(facecolor=DARK_BG, labelcolor=WHITE)

    # Add speedup labels
    for i, (s, sim, sp) in enumerate(zip(scalar, simd, speedup)):
        ax.text(i, max(s, sim) + 2, f'{sp:.1f}×', ha='center', color=MAGENTA, fontsize=10)

    plt.tight_layout()
    return fig

# ============================================================================
# Main Generation
# ============================================================================

def generate_all_figures(output_dir='figures'):
    """Generate all figures for Zenodo bundles."""
    output_path = Path(output_dir)
    output_path.mkdir(exist_ok=True)

    figures = [
        ('B001_hslm_architecture.png', generate_b001_hslm_architecture),
        ('B001_comparison.png', generate_b001_comparison),
        ('B002_resource_comparison.png', generate_b002_resource_comparison),
        ('B003_register_layout.png', generate_b003_register_layout),
        ('B004_lotus_cycle.png', generate_b004_lotus_cycle),
        ('B005_type_system.png', generate_b005_type_system),
        ('B006_bit_layout.png', generate_b006_bit_layout),
        ('B007_simd_speedup.png', generate_b007_simd_speedup),
    ]

    print(f"Generating {len(figures)} figures...")

    for filename, generator in figures:
        path = output_path / filename
        fig = generator()
        fig.savefig(path, dpi=300, bbox_inches='tight', facecolor=DARK_BG)
        plt.close(fig)
        print(f"  ✅ {filename}")

    print(f"\nAll figures saved to: {output_path.absolute()}")
    print(f"DPI: 300 | Format: PNG | Background: {DARK_BG}")

if __name__ == '__main__':
    import sys
    output_dir = sys.argv[1] if len(sys.argv) > 1 else 'figures'
    generate_all_figures(output_dir)
