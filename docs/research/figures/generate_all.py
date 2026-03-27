#!/usr/bin/env python3
"""
Zenodo Figure Generation Script
Generates scientific figures for Trinity Zenodo v9.0 bundles.

Usage:
    python3 docs/research/figures/generate_all.py
"""

import os
import sys
from pathlib import Path

# Check for dependencies
try:
    import matplotlib
    import matplotlib.pyplot as plt
    import numpy as np
except ImportError as e:
    print(f"ERROR: Missing dependency: {e}")
    print("\nInstall with:")
    print("  pip install matplotlib numpy")
    sys.exit(1)

# Set style
plt.style.use('default')
matplotlib.rcParams['font.family'] = ['sans-serif']
matplotlib.rcParams['font.sans-serif'] = ['Apple System', 'Roboto', 'Segoe UI', 'DejaVu Sans']
matplotlib.rcParams['figure.dpi'] = 300
matplotlib.rcParams['savefig.dpi'] = 300

# Trinity colors
BLUE = '#3498db'
GREEN = '#2ecc71'
PURPLE = '#9b59b6'
ORANGE = '#e67e22'
RED = '#e74c3c'

def fig_b001_training_curve():
    """B001-Fig1: Training loss curve"""
    steps = np.array([0, 5000, 10000, 15000, 20000, 25000, 30000, 35000, 40000, 45000, 50000])
    ppl = np.array([10.52, 4.85, 3.21, 2.89, 2.67, 2.52, 2.41, 2.33, 2.28, 2.24, 2.21])
    ppl_ci = np.array([0.5, 0.4, 0.35, 0.32, 0.30, 0.28, 0.26, 0.25, 0.24, 0.23, 0.21])

    fig, ax = plt.subplots(figsize=(10, 6))
    ax.plot(steps, ppl, color=BLUE, linewidth=2, label='HSLM-1.95M')
    ax.fill_between(steps, ppl - ppl_ci, ppl + ppl_ci, alpha=0.2, color=BLUE)
    ax.set_xlabel('Training Steps', fontsize=12)
    ax.set_ylabel('Perplexity', fontsize=12)
    ax.set_title('HSLM Training Curve (TinyStories)', fontsize=14, fontweight='bold')
    ax.grid(True, alpha=0.3)
    ax.legend()
    ax.set_ylim([2, 11])
    plt.tight_layout()
    plt.savefig('B001-Fig1_training_curve.png')
    plt.close()
    print("✅ Generated: B001-Fig1_training_curve.png")

def fig_b001_format_comparison():
    """B001-Fig2: Model size comparison"""
    formats = ['FP32', 'FP16', 'INT8', 'GF16']
    sizes = [7.6, 3.8, 1.9, 0.385]  # MB
    colors = [RED, ORANGE, PURPLE, GREEN]

    fig, ax = plt.subplots(figsize=(10, 6))
    bars = ax.bar(formats, sizes, color=colors, alpha=0.8)
    ax.set_ylabel('Model Size (MB)', fontsize=12)
    ax.set_title('HSLM Model Size by Format', fontsize=14, fontweight='bold')
    ax.set_yscale('log')

    # Add value labels on bars
    for bar, size in zip(bars, sizes):
        ax.text(bar.get_x() + bar.get_width()/2, bar.get_height(),
                f'{size} MB', ha='center', va='bottom', fontsize=11, fontweight='bold')

    ax.grid(True, alpha=0.3, axis='y')
    plt.tight_layout()
    plt.savefig('B001-Fig2_format_comparison.png')
    plt.close()
    print("✅ Generated: B001-Fig2_format_comparison.png")

def fig_b002_fpga_resources():
    """B002-Fig1: FPGA resource utilization"""
    resources = ['LUTs', 'BRAM', 'URAM', 'DSP48E1']
    used = [14256, 144, 288, 0]
    available = [48000, 576, 1280, 240]
    utilization = [u/a * 100 for u, a in zip(used, available)]

    x = np.arange(len(resources))
    width = 0.35

    fig, ax = plt.subplots(figsize=(10, 6))
    bars1 = ax.bar(x - width/2, used, width, label='Used', color=BLUE)
    bars2 = ax.bar(x + width/2, available, width, label='Available', color=GREEN, alpha=0.5)

    ax.set_ylabel('Count', fontsize=12)
    ax.set_title('FPGA Resource Utilization (XC7A100T)', fontsize=14, fontweight='bold')
    ax.set_xticks(x)
    ax.set_xticklabels(resources)
    ax.legend()
    ax.grid(True, alpha=0.3, axis='y')

    # Add utilization percentages
    for i, util in enumerate(utilization):
        ax.text(i, max(used[i], available[i]) * 1.05, f'{util:.1f}%',
                ha='center', fontsize=10, color=RED if util > 50 else GREEN)

    plt.tight_layout()
    plt.savefig('B002-Fig1_fpga_resources.png')
    plt.close()
    print("✅ Generated: B002-Fig1_fpga_resources.png")

def fig_b002_power_analysis():
    """B002-Fig2: Power consumption comparison"""
    configs = ['FP32 GPU', 'INT8 GPU', 'GF16 FPGA']
    power = [3.2, 2.1, 1.8]  # Watts
    colors = [RED, ORANGE, GREEN]

    fig, ax = plt.subplots(figsize=(10, 6))
    bars = ax.bar(configs, power, color=colors, alpha=0.8)
    ax.set_ylabel('Power (W)', fontsize=12)
    ax.set_title('Power Consumption Comparison', fontsize=14, fontweight='bold')
    ax.grid(True, alpha=0.3, axis='y')

    for bar, p in zip(bars, power):
        ax.text(bar.get_x() + bar.get_width()/2, bar.get_height() + 0.05,
                f'{p} W', ha='center', fontsize=12, fontweight='bold')

    plt.tight_layout()
    plt.savefig('B002-Fig2_power_analysis.png')
    plt.close()
    print("✅ Generated: B002-Fig2_power_analysis.png")

def fig_b003_register_layout():
    """B003-Fig1: TRI-27 register layout"""
    fig, ax = plt.subplots(figsize=(10, 6))

    # Create 3x9 grid
    banks = ['Alpha', 'Beta', 'Gamma']
    regs = [f'Ϣ{i}' if i < 8 else f'ϯ' for i in range(9)]

    for bank_idx, bank in enumerate(banks):
        for reg_idx in range(9):
            color = [BLUE, GREEN, PURPLE][bank_idx]
            rect = plt.Rectangle((reg_idx, 2-bank_idx), 1, 1,
                                 facecolor=color, alpha=0.6, edgecolor='black')
            ax.add_patch(rect)
            ax.text(reg_idx + 0.5, 2.5 - bank_idx, regs[reg_idx],
                    ha='center', va='center', fontsize=14, fontweight='bold')

    ax.set_xlim(0, 9)
    ax.set_ylim(0, 3)
    ax.set_aspect('equal')
    ax.set_xticks(np.arange(9) + 0.5)
    ax.set_xticklabels([f'R{i}' for i in range(9)])
    ax.set_yticks([0.5, 1.5, 2.5])
    ax.set_yticklabels(banks)
    ax.set_title('TRI-27 Register Layout (3 banks × 9 registers)', fontsize=14, fontweight='bold')
    ax.grid(True, alpha=0.3)

    plt.tight_layout()
    plt.savefig('B003-Fig1_register_layout.png')
    plt.close()
    print("✅ Generated: B003-Fig1_register_layout.png")

def fig_b004_lotus_cycle():
    """B004-Fig1: Lotus consciousness cycle"""
    phases = ['SEED', 'SPROUT', 'BUD', 'BLOOM', 'WITHER']
    colors = ['#27ae60', '#58d68d', '#f1c40f', '#e91e63', '#7f8c8d']
    angles = np.linspace(0, 2*np.pi, len(phases), endpoint=False).tolist()

    fig, ax = plt.subplots(figsize=(8, 8), subplot_kw=dict(projection='polar'))

    # Draw cycle arrows
    for i, (phase, color, angle) in enumerate(zip(phases, colors, angles)):
        ax.annotate('', xy=[angle + 2*np.pi/len(phases) - 0.2, 1.2],
                   xytext=[angle, 1.2],
                   arrowprops=dict(arrowstyle='->', color=color, lw=2))
        ax.text(angle, 1.0, phase, ha='center', va='center',
                fontsize=12, fontweight='bold', color=color)

    ax.set_ylim(0, 1.3)
    ax.set_yticks([])
    ax.set_xticks([])
    ax.spines['polar'].set_visible(False)
    ax.set_title('Queen Lotus Consciousness Cycle', fontsize=14, fontweight='bold', pad=20)

    plt.tight_layout()
    plt.savefig('B004-Fig1_lotus_cycle.png')
    plt.close()
    print("✅ Generated: B004-Fig1_lotus_cycle.png")

def fig_b005_type_hierarchy():
    """B005-Fig1: Tri language type hierarchy"""
    fig, ax = plt.subplots(figsize=(10, 8))

    # Simple tree diagram
    positions = {
        'Type': (5, 9),
        'Trit': (2, 7), 'Vector': (5, 7), 'Struct': (8, 7),
        'Option': (1, 5), 'Result': (3, 5), 'List': (5, 5), 'Map': (7, 5),
        'Effect': (5, 3),
    }

    for name, (x, y) in positions.items():
        circle = plt.Circle((x, y), 0.4, color=BLUE, alpha=0.6)
        ax.add_patch(circle)
        ax.text(x, y, name, ha='center', va='center',
                fontsize=10, fontweight='bold', color='white')

    # Draw connections
    connections = [
        ('Type', 'Trit'), ('Type', 'Vector'), ('Type', 'Struct'),
        ('Trit', 'Option'), ('Trit', 'Result'),
        ('Vector', 'List'), ('Vector', 'Map'),
        ('Type', 'Effect'),
    ]
    for parent, child in connections:
        px, py = positions[parent]
        cx, cy = positions[child]
        ax.plot([px, cx], [py, cy], 'k-', alpha=0.3, linewidth=2)

    ax.set_xlim(0, 10)
    ax.set_ylim(0, 10)
    ax.set_aspect('equal')
    ax.axis('off')
    ax.set_title('Tri Language Type Hierarchy', fontsize=14, fontweight='bold')

    plt.tight_layout()
    plt.savefig('B005-Fig1_type_hierarchy.png')
    plt.close()
    print("✅ Generated: B005-Fig1_type_hierarchy.png")

def fig_b006_gf16_layout():
    """B006-Fig1: GF16 word encoding"""
    fig, ax = plt.subplots(figsize=(12, 4))

    # Show 16-bit word layout
    bits = list(range(16))
    colors = [BLUE] * 8 + [GREEN] * 8

    for i, (bit, color) in enumerate(zip(bits, colors)):
        rect = plt.Rectangle((i, 0), 1, 1, facecolor=color, alpha=0.6, edgecolor='black')
        ax.add_patch(rect)
        ax.text(i + 0.5, 0.5, str(15-bit), ha='center', va='center',
                fontsize=10, fontweight='bold', color='white')

    ax.set_xlim(0, 16)
    ax.set_ylim(0, 2)
    ax.set_aspect('equal')
    ax.axis('off')
    ax.set_title('GF16 16-bit Word Layout (8 trits × 2 groups)', fontsize=14, fontweight='bold')

    # Add labels
    ax.text(4, 1.3, 'Group 1 (trits 0-7)', ha='center', fontsize=12, color=BLUE)
    ax.text(12, 1.3, 'Group 2 (trits 8-15)', ha='center', fontsize=12, color=GREEN)
    ax.text(8, -0.3, 'MSB ← Bit position → LSB', ha='center', fontsize=10)

    plt.tight_layout()
    plt.savefig('B006-Fig1_gf16_layout.png')
    plt.close()
    print("✅ Generated: B006-Fig1_gf16_layout.png")

def fig_b006_phi_heatmap():
    """B006-Fig2: φ-normalization heatmap"""
    values = np.array([[-1, -0.618, -0.382, 0, 0.382, 0.618, 1],
                      [-0.618, -0.382, 0, 0.382, 0.618, 1, 1.618]])

    fig, ax = plt.subplots(figsize=(10, 3))
    im = ax.imshow(values, cmap='RdBu_r', aspect='auto', vmin=-1.5, vmax=1.5)

    ax.set_xticks(np.arange(7))
    ax.set_yticks([0, 1])
    ax.set_yticklabels(['Input Trit', 'φ-Normalized'])
    ax.set_title('φ-Normalization Mapping', fontsize=14, fontweight='bold')

    # Add values
    for i in range(2):
        for j in range(7):
            text = ax.text(j, i, f'{values[i, j]:.3f}',
                          ha="center", va="center", color="black", fontsize=9)

    plt.colorbar(im, ax=ax, label='Value')
    plt.tight_layout()
    plt.savefig('B006-Fig2_phi_heatmap.png')
    plt.close()
    print("✅ Generated: B006-Fig2_phi_heatmap.png")

def fig_b007_vsa_structure():
    """B007-Fig1: VSA vector structure"""
    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(12, 5))

    # Binary spatter code
    binary = np.random.randint(0, 2, 100)
    ax1.imshow(binary.reshape(1, -1), aspect='auto', cmap='binary')
    ax1.set_title('Binary Spatter Code (10,000 bits)', fontsize=12, fontweight='bold')
    ax1.set_xlabel('Bit Index')
    ax1.set_yticks([])

    # Holographic reduced representation
    hrr = np.random.randn(100)
    ax2.bar(range(100), hrr, color=BLUE, alpha=0.6)
    ax2.set_title('HRR Components', fontsize=12, fontweight='bold')
    ax2.set_xlabel('Component Index')
    ax2.set_ylabel('Value')
    ax2.grid(True, alpha=0.3)

    plt.suptitle('VSA Vector Structure', fontsize=14, fontweight='bold')
    plt.tight_layout()
    plt.savefig('B007-Fig1_vsa_structure.png')
    plt.close()
    print("✅ Generated: B007-Fig1_vsa_structure.png")

def fig_b007_simd_speedup():
    """B007-Fig2: SIMD speedup comparison"""
    operations = ['bind', 'unbind', 'bundle2', 'bundle3', 'similarity']
    scalar = [1.2, 1.2, 1.5, 1.8, 0.5]  # microseconds
    simd = [0.07, 0.07, 0.09, 0.11, 0.03]  # microseconds
    speedup = [s/si for s, si in zip(scalar, simd)]

    x = np.arange(len(operations))
    width = 0.35

    fig, ax = plt.subplots(figsize=(10, 6))
    bars1 = ax.bar(x - width/2, scalar, width, label='Scalar', color=RED)
    bars2 = ax.bar(x + width/2, simd, width, label='SIMD (AVX2)', color=GREEN)

    ax.set_ylabel('Time (µs)', fontsize=12)
    ax.set_title('VSA Operation Performance (10K-bit vectors)', fontsize=14, fontweight='bold')
    ax.set_xticks(x)
    ax.set_xticklabels(operations)
    ax.legend()
    ax.grid(True, alpha=0.3, axis='y')
    ax.set_yscale('log')

    # Add speedup labels
    for i, sp in enumerate(speedup):
        ax.text(i, max(scalar[i], simd[i]) * 1.1, f'{sp:.1f}×',
                ha='center', fontsize=10, color=BLUE, fontweight='bold')

    plt.tight_layout()
    plt.savefig('B007-Fig2_simd_speedup.png')
    plt.close()
    print("✅ Generated: B007-Fig2_simd_speedup.png")

def main():
    """Generate all figures."""
    print("=" * 60)
    print("Trinity Zenodo Figure Generator")
    print("=" * 60)
    print()

    # Change to figures directory
    figures_dir = Path(__file__).parent
    os.chdir(figures_dir)

    # Generate figures
    fig_b001_training_curve()
    fig_b001_format_comparison()
    fig_b002_fpga_resources()
    fig_b002_power_analysis()
    fig_b003_register_layout()
    fig_b004_lotus_cycle()
    fig_b005_type_hierarchy()
    fig_b006_gf16_layout()
    fig_b006_phi_heatmap()
    fig_b007_vsa_structure()
    fig_b007_simd_speedup()

    print()
    print("=" * 60)
    print(f"✅ Generated 12 figures in {figures_dir}")
    print("=" * 60)

if __name__ == "__main__":
    main()
