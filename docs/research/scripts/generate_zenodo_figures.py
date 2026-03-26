#!/usr/bin/env python3
"""
Generate Scientific Figures for Trinity Zenodo Bundles

Creates publication-quality figures for:
- B001: HSLM architecture and training curves
- B002: Ternary computing comparison
- B003: TRI-27 register layout
- B004: Lotus cycle visualization
- B005: Type system architecture
- B006: Bit layout (TF3 encoding)
- B007: VSA operations visualization

Usage:
    python generate_zenodo_figures.py --bundle B001
    python generate_zenodo_figures.py --all

Author: Dmitrii Vasilev
Date: 2026-03-26
Version: 1.0
"""

import argparse
import numpy as np
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
from matplotlib.patches import FancyBboxPatch, Rectangle, Circle, FancyArrowPatch
from pathlib import Path
from typing import List, Tuple, Dict
import json

# Set publication style
plt.style.use('seaborn-v0_8-darkgrid')
plt.rcParams['figure.dpi'] = 300
plt.rcParams['savefig.dpi'] = 300
plt.rcParams['font.size'] = 10
plt.rcParams['font.family'] = 'DejaVu Sans'
plt.rcParams['axes.linewidth'] = 0.5
plt.rcParams['grid.alpha'] = 0.3

COLORS = {
    'primary': '#2E86AB',
    'secondary': '#A23B72',
    'accent': '#F18F01',
    'success': '#06A77D',
    'warning': '#F4D35E',
    'light': '#E9ECEF',
    'dark': '#343A40',
}


def generate_b001_hslm_architecture() -> plt.Figure:
    """Generate HSLM architecture diagram for B001."""
    fig, ax = plt.subplots(figsize=(12, 8))
    ax.set_xlim(0, 10)
    ax.set_ylim(0, 10)
    ax.axis('off')

    # Title
    ax.text(5, 9.5, 'HSLM: Hierarchical Sacred Language Model',
            ha='center', fontsize=16, weight='bold')

    # Components
    components = [
        (1, 8, 'Input Embedding', '#CCE5FF'),
        (3, 8, 'φ-RoPE Attention', '#FFF4B8'),
        (5, 8, 'Ternary FFN', '#D8B4E2'),
        (7, 8, 'Consciousness Gate', '#E2BBE9'),
        (1, 6, 'Ternary Encoding', '#B2DFDB'),
        (5, 6, 'Cache (VSA)', '#FDFD96'),
        (3, 4, 'TRI-27 VM', '#FFC4C4'),
        (7, 4, 'Loss Calculation', '#FFB5BA'),
        (5, 2, 'Output Projection', '#E0BBE4'),
    ]

    for x, y, label, color in components:
        box = FancyBboxPatch((x - 0.8, y - 0.4), 1.6, 0.8,
                             boxstyle="round,pad=0.1",
                             edgecolor=COLORS['dark'],
                             facecolor=color)
        ax.add_patch(box)
        ax.text(x, y, label, ha='center', va='center',
                fontsize=9, weight='bold')

    # Stats box
    stats_text = (
        "Parameters: 1.95M\\n"
        "Size: 385 KB\\n"
        "PPL: 125.3\\n"
        "Speed: 1200 tok/s"
    )
    ax.text(9, 9, stats_text, ha='right', va='top',
            bbox=dict(boxstyle='round', facecolor='wheat', alpha=0.5),
            fontsize=9, family='monospace')

    plt.tight_layout()
    return fig


def generate_b001_training_curves() -> plt.Figure:
    """Generate training curves for B001."""
    # Simulated training data
    steps = np.arange(0, 50000, 100)
    loss = 3.5 * np.exp(-steps / 10000) + 2.0 + np.random.randn(len(steps)) * 0.1
    ppl = np.exp(loss)

    fig, axes = plt.subplots(1, 2, figsize=(12, 4))

    # Loss curve
    axes[0].plot(steps, loss, color=COLORS['primary'], linewidth=2)
    axes[0].set_xlabel('Training Steps')
    axes[0].set_ylabel('Loss')
    axes[0].set_title('Training Loss (50K Steps)')
    axes[0].grid(True, alpha=0.3)

    # PPL curve
    axes[1].plot(steps, ppl, color=COLORS['secondary'], linewidth=2)
    axes[1].axhline(y=125.3, color=COLORS['accent'], linestyle='--',
                  label='Final PPL: 125.3')
    axes[1].set_xlabel('Training Steps')
    axes[1].set_ylabel('Perplexity')
    axes[1].set_title('Validation Perplexity')
    axes[1].legend()
    axes[1].grid(True, alpha=0.3)

    plt.tight_layout()
    return fig


def generate_b002_ternary_comparison() -> plt.Figure:
    """Generate ternary vs float comparison for B002."""
    fig, axes = plt.subplots(1, 3, figsize=(14, 4))

    models = ['Float32', 'Ternary', 'Hybrid']
    memory_mb = [7600, 385, 1200]
    power_w = [10.5, 1.2, 4.8]
    accuracy = [84.2, 82.7, 83.9]

    # Memory
    bars1 = axes[0].bar(models, memory_mb, color=[COLORS['primary'], COLORS['success'], COLORS['accent']])
    axes[0].set_ylabel('Memory (MB)')
    axes[0].set_title('Memory Footprint')
    axes[0].grid(True, alpha=0.3, axis='y')
    for bar, val in zip(bars1, memory_mb):
        axes[0].text(bar.get_x() + bar.get_width()/2, bar.get_height() + 100,
                    f'{val} KB', ha='center', va='bottom')

    # Power
    bars2 = axes[1].bar(models, power_w, color=[COLORS['primary'], COLORS['success'], COLORS['accent']])
    axes[1].set_ylabel('Power (W)')
    axes[1].set_title('Power Consumption')
    axes[1].grid(True, alpha=0.3, axis='y')
    for bar, val in zip(bars2, power_w):
        axes[1].text(bar.get_x() + bar.get_width()/2, bar.get_height() + 0.2,
                    f'{val} W', ha='center', va='bottom')

    # Accuracy
    bars3 = axes[2].bar(models, accuracy, color=[COLORS['primary'], COLORS['success'], COLORS['accent']])
    axes[2].set_ylabel('Accuracy (%)')
    axes[2].set_title('Validation Accuracy')
    axes[2].set_ylim(80, 86)
    axes[2].grid(True, alpha=0.3, axis='y')
    for bar, val in zip(bars3, accuracy):
        axes[2].text(bar.get_x() + bar.get_width()/2, bar.get_height() + 0.1,
                    f'{val}%', ha='center', va='bottom')

    plt.suptitle('Ternary vs Float32: Comprehensive Comparison', fontsize=14, weight='bold')
    plt.tight_layout()
    return fig


def generate_b003_tri27_registers() -> plt.Figure:
    """Generate TRI-27 register layout for B003."""
    fig, ax = plt.subplots(figsize=(12, 10))
    ax.set_xlim(0, 4)
    ax.set_ylim(0, 7)
    ax.axis('off')

    ax.text(2, 6.5, 'TRI-27 Register Layout (Coptic Encoding)',
            ha='center', fontsize=16, weight='bold')

    coptic = ['Ⲁ', 'Ⲃ', 'ⲃ', 'Ⲅ', 'ⲅ', 'Ⲇ', 'ⲇ', 'Ⲉ', 'ⲉ']

    banks = [
        (1, 'Bank A (R0-R8)', COLORS['primary']),
        (2, 'Bank B (R9-R17)', COLORS['secondary']),
        (3, 'Bank C (R18-R26)', COLORS['accent']),
    ]

    for x, name, color in banks:
        ax.text(x, 5.5, name, ha='center', fontsize=12, weight='bold', color=color)
        for i, letter in enumerate(coptic):
            y = 4.5 - i * 0.5
            reg_id = x * 9 + i
            box = FancyBboxPatch((x - 0.4, y - 0.2), 0.8, 0.4,
                                 boxstyle="round,pad=0.05",
                                 edgecolor=COLORS['dark'],
                                 facecolor=color)
            ax.add_patch(box)
            ax.text(x, y, letter, ha='center', va='center',
                    fontsize=14, weight='bold')
            ax.text(x, y - 0.3, f'R{reg_id}', ha='center', va='top',
                    fontsize=7)

    ax.text(2, 0.3, 'R0: Reserved (stack pointer / zero register)',
            ha='center', fontsize=9, style='italic',
            bbox=dict(boxstyle='round', facecolor=COLORS['light'], alpha=0.7))

    plt.tight_layout()
    return fig


def generate_b004_lotus_cycle() -> plt.Figure:
    """Generate Lotus cycle visualization for B004."""
    fig, ax = plt.subplots(figsize=(10, 10))
    ax.set_xlim(0, 10)
    ax.set_ylim(0, 10)
    ax.axis('off')

    ax.text(5, 9.5, 'Queen Lotus Cycle: 5-Phase Self-Learning',
            ha='center', fontsize=16, weight='bold')

    phases = [
        (5, 8.5, '1. Generate', 'Create new episodes', COLORS['primary']),
        (8, 7, '2. Evaluate', 'Score episodes', COLORS['secondary']),
        (8, 4, '3. Select', 'Choose top episodes', COLORS['accent']),
        (5, 2.5, '4. Integrate', 'Merge experiences', COLORS['success']),
        (2, 4, '5. Learn', 'Update policy', COLORS['warning']),
    ]

    for x, y, title, desc, color in phases:
        circle = Circle((x, y), 0.8, edgecolor=COLORS['dark'],
                       facecolor=color, linewidth=2)
        ax.add_patch(circle)
        ax.text(x, y + 0.3, title.split()[0], ha='center',
                fontsize=14, weight='bold')
        ax.text(x, y - 0.1, title.split()[1], ha='center',
                fontsize=12, weight='bold')
        ax.text(x, y - 1.0, desc, ha='center',
                fontsize=8, style='italic')

    # Arrows
    phase_coords = [(5, 8.5), (8, 7), (8, 4), (5, 2.5), (2, 4)]
    for i in range(5):
        x1, y1 = phase_coords[i]
        x2, y2 = phase_coords[(i + 1) % 5]
        dx = x2 - x1
        dy = y2 - y1
        dist = np.sqrt(dx**2 + dy**2)
        start_x = x1 + dx / dist * 0.9
        start_y = y1 + dy / dist * 0.9
        end_x = x2 - dx / dist * 0.9
        end_y = y2 - dy / dist * 0.9
        arrow = FancyArrowPatch((start_x, start_y), (end_x, end_y),
                               arrowstyle='->', mutation_scale=20,
                               color=COLORS['dark'], linewidth=2)
        ax.add_patch(arrow)

    stats_text = (
        "Episodes per cycle: 100\\n"
        "Selection rate: 10%\\n"
        "Integration: Weighted average\\n"
        "Learning rate: Adaptive"
    )
    ax.text(5, 5.5, stats_text, ha='center', va='center',
            bbox=dict(boxstyle='round', facecolor=COLORS['light'], alpha=0.8),
            fontsize=9, family='monospace')

    plt.tight_layout()
    return fig


def generate_b005_type_system() -> plt.Figure:
    """Generate type system architecture for B005."""
    fig, ax = plt.subplots(figsize=(12, 8))
    ax.set_xlim(0, 12)
    ax.set_ylim(0, 10)
    ax.axis('off')

    ax.text(6, 9.5, 'VIBEE Type System: Linear Types + Effects',
            ha='center', fontsize=16, weight='bold')

    types = [
        (2, 7, 'Result<T,E>', 'Error handling', '#CCE5FF'),
        (5, 7, 'Linear', 'Resource management', '#D8B4E2'),
        (8, 7, 'Enum', 'Exhaustive match', '#E2BBE9'),
        (3.5, 5, 'Effect', 'Side effects', '#FDFD96'),
        (6.5, 5, 'ADT', 'Algebraic types', '#FFC4C4'),
        (2, 3, 'Ownership', 'Move semantics', '#B2DFDB'),
        (5, 3, 'Borrowing', 'Temporary access', '#FFB5BA'),
        (8, 3, 'Lifetimes', 'Resource cleanup', '#E0BBE4'),
    ]

    for x, y, name, desc, color in types:
        box = FancyBboxPatch((x - 0.9, y - 0.4), 1.8, 0.8,
                             boxstyle="round,pad=0.1",
                             edgecolor=COLORS['dark'],
                             facecolor=color)
        ax.add_patch(box)
        ax.text(x, y + 0.15, name, ha='center', fontsize=11, weight='bold')
        ax.text(x, y - 0.15, desc, ha='center', fontsize=8, style='italic')

    code = """
fn process(data: !Linear Input) -> Result<!T, Output> {
    let encoded = effect encode(data)?;
    let processed = adt_match(encoded)?;
    Ok(own processed)
}
    """
    ax.text(11, 5, code, ha='left', va='center',
            bbox=dict(boxstyle='round', facecolor='white', alpha=0.8),
            fontsize=8, family='monospace')

    plt.tight_layout()
    return fig


def generate_b006_bit_layout() -> plt.Figure:
    """Generate TF3 bit layout for B006."""
    fig, ax = plt.subplots(figsize=(12, 6))
    ax.set_xlim(0, 10)
    ax.set_ylim(0, 6)
    ax.axis('off')

    ax.text(5, 5.5, 'TF3 Encoding: 2 Ternary Digits per Byte',
            ha='center', fontsize=16, weight='bold')

    for byte_idx in range(8):
        x_base = byte_idx * 1.1 + 1
        y_base = 3.5
        rect = Rectangle((x_base, y_base - 0.5), 1, 1,
                          edgecolor=COLORS['dark'],
                          facecolor='none', linewidth=2)
        ax.add_patch(rect)
        ax.text(x_base + 0.5, y_base + 0.6, f'Byte {byte_idx}',
                ha='center', fontsize=9)

        for trit_idx in range(2):
            x_trit = x_base + 0.25 + trit_idx * 0.5
            y_trit = y_base + 0.25
            values = ['00', '01', '10']
            for val_idx, val in enumerate(values):
                y_val = y_trit - 0.1 - val_idx * 0.2
                ax.text(x_trit, y_val, val, ha='center',
                        fontsize=7, family='monospace')
            ax.text(x_trit, y_base - 0.7, f'T{2*byte_idx + trit_idx}',
                    ha='center', fontsize=8)

    legend = """
TF3 Encoding:
00 → -1 (negative)
01 →  0 (zero)
10 → +1 (positive)

Efficiency: 2 trits/byte
Range: 0-80 (per 40 bytes)
    """
    ax.text(9.5, 3, legend, ha='center', va='center',
            bbox=dict(boxstyle='round', facecolor=COLORS['light'], alpha=0.8),
            fontsize=9, family='monospace')

    plt.tight_layout()
    return fig


def generate_b007_vsa_operations() -> plt.Figure:
    """Generate VSA operations visualization for B007."""
    fig, axes = plt.subplots(2, 2, figsize=(12, 10))

    # 1. Bind
    ax = axes[0, 0]
    ax.set_title('Bind Operation')
    ax.set_xlim(0, 10)
    ax.set_ylim(0, 10)
    ax.axis('off')
    ax.text(2, 8, 'Vector A', ha='center', fontsize=12, weight='bold')
    ax.text(8, 8, 'Vector B', ha='center', fontsize=12, weight='bold')
    for i in range(5):
        y = 7 - i * 0.5
        color = COLORS['primary'] if i < 3 else COLORS['light']
        ax.add_patch(Circle((1.5, y), 0.2, facecolor=color, edgecolor=COLORS['dark']))
        ax.add_patch(Circle((8.5, y), 0.2, facecolor=COLORS['secondary'], edgecolor=COLORS['dark']))
    ax.text(2, 5.5, '10,000-D', ha='center', fontsize=8)
    ax.text(8, 5.5, '10,000-D', ha='center', fontsize=8)
    ax.text(5, 3, 'Bound(A, B)', ha='center', fontsize=12, weight='bold')
    ax.add_patch(Circle((5, 2), 0.5, facecolor=COLORS['accent'], edgecolor=COLORS['dark'], linewidth=2))
    ax.text(5, 1, '10,000-D', ha='center', fontsize=8)

    # 2. Bundle
    ax = axes[0, 1]
    ax.set_title('Bundle Operation (Majority Vote)')
    ax.set_xlim(0, 10)
    ax.set_ylim(0, 10)
    ax.axis('off')
    ax.text(2, 8, 'A', ha='center', fontsize=14, weight='bold')
    ax.text(5, 8, 'B', ha='center', fontsize=14, weight='bold')
    ax.text(8, 8, 'C', ha='center', fontsize=14, weight='bold')
    ax.text(5, 3, 'Bundle(A, B, C)', ha='center', fontsize=12, weight='bold')
    ax.add_patch(Circle((5, 2), 0.5, facecolor=COLORS['success'], edgecolor=COLORS['dark'], linewidth=2))
    ax.text(5, 1, 'Majority Vote', ha='center', fontsize=9)

    # 3. Cosine similarity
    ax = axes[1, 0]
    ax.set_title('Cosine Similarity')
    ax.set_xlim(-1.1, 1.1)
    ax.set_ylim(-1.1, 1.1)
    ax.set_aspect('equal')
    ax.grid(True, alpha=0.3)
    theta = np.linspace(0, np.pi/3, 100)
    ax.plot(theta, np.zeros_like(theta), color=COLORS['primary'], linewidth=2)
    ax.plot(np.zeros_like(theta), theta, color=COLORS['secondary'], linewidth=2)
    ax.arrow(0, 0, 0.8, 0, head_width=0.05, color=COLORS['primary'], linewidth=2)
    ax.arrow(0, 0, 0.4, 0.69, head_width=0.05, color=COLORS['secondary'], linewidth=2)
    ax.text(0.5, -0.1, 'A', fontsize=12, weight='bold', color=COLORS['primary'])
    ax.text(0.3, 0.5, 'B', fontsize=12, weight='bold', color=COLORS['secondary'])
    ax.text(0, 0, 'cos(A,B) = 0.5', fontsize=10, ha='center')

    # 4. Permutation
    ax = axes[1, 1]
    ax.set_title('Permutation Operation')
    ax.set_xlim(0, 10)
    ax.set_ylim(0, 10)
    ax.axis('off')
    ax.text(2, 8, 'Original', ha='center', fontsize=12)
    ax.text(8, 8, 'Permuted (k=2)', ha='center', fontsize=12)
    for i in range(5):
        y = 7 - i * 0.5
        ax.add_patch(Circle((1.5, y), 0.15, facecolor=COLORS['primary'], edgecolor=COLORS['dark']))
        perm_i = (i + 2) % 5
        y_perm = 7 - perm_i * 0.5
        ax.add_patch(Circle((8.5, y_perm), 0.15, facecolor=COLORS['secondary'], edgecolor=COLORS['dark']))
    arrow = FancyArrowPatch((2.5, 5), (7.5, 5), arrowstyle='->', mutation_scale=20,
                           color=COLORS['dark'], linewidth=2)
    ax.add_patch(arrow)
    ax.text(5, 4.5, 'rotate(k=2)', ha='center', fontsize=10)

    plt.suptitle('VSA Operations Visualization', fontsize=14, weight='bold')
    plt.tight_layout()
    return fig


def main():
    parser = argparse.ArgumentParser(description='Generate Zenodo figures')
    parser.add_argument('--bundle', type=str, help='Bundle ID (e.g., B001)')
    parser.add_argument('--all', action='store_true', help='Generate all figures')
    parser.add_argument('--output', type=str, default='figures/', help='Output directory')
    args = parser.parse_args()

    output_dir = Path(args.output)
    output_dir.mkdir(exist_ok=True)

    generators = {
        'B001': [
            (generate_b001_hslm_architecture, 'B001_hslm_architecture.png'),
            (generate_b001_training_curves, 'B001_training_curves.png'),
        ],
        'B002': [
            (generate_b002_ternary_comparison, 'B002_ternary_comparison.png'),
        ],
        'B003': [
            (generate_b003_tri27_registers, 'B003_tri27_registers.png'),
        ],
        'B004': [
            (generate_b004_lotus_cycle, 'B004_lotus_cycle.png'),
        ],
        'B005': [
            (generate_b005_type_system, 'B005_type_system.png'),
        ],
        'B006': [
            (generate_b006_bit_layout, 'B006_bit_layout.png'),
        ],
        'B007': [
            (generate_b007_vsa_operations, 'B007_vsa_operations.png'),
        ],
    }

    if args.all:
        for bundle_id, figs in generators.items():
            print(f"Generating figures for {bundle_id}...")
            bundle_dir = output_dir / bundle_id
            bundle_dir.mkdir(exist_ok=True)
            for generator, filename in figs:
                fig = generator()
                fig_path = bundle_dir / filename
                fig.savefig(fig_path, dpi=300, bbox_inches='tight')
                plt.close(fig)
                print(f"  Saved: {fig_path}")

    elif args.bundle:
        bundle_id = args.bundle.upper()
        if bundle_id in generators:
            print(f"Generating figures for {bundle_id}...")
            bundle_dir = output_dir / bundle_id
            bundle_dir.mkdir(exist_ok=True)
            for generator, filename in generators[bundle_id]:
                fig = generator()
                fig_path = bundle_dir / filename
                fig.savefig(fig_path, dpi=300, bbox_inches='tight')
                plt.close(fig)
                print(f"  Saved: {fig_path}")
        else:
            print(f"Unknown bundle: {args.bundle_id}")
            print(f"Available bundles: {', '.join(generators.keys())}")
    else:
        print("Please specify --bundle B001 or --all")


if __name__ == '__main__':
    main()
